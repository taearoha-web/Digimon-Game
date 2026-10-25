extends Node
## Real-combat damage per second of every class at the end of the game: a Lv.100,
## ★200 hero, every job advancement, the boost tool's best +10 gear, a standard
## build (two thirds of the stat points in the main stat, the rest in VIT; star
## points as balance_probe spends them) and every skill and passive at rank 5, fighting
## on auto. The zone's camps are emptied and the hero fights a training ground of the
## zone's first monster: one (boss-like single target), then a pack of six, each kept
## alive for a fixed stretch of game time, so every class meets the same targets.
## Counts the health it takes off them (summons included), so attack speed, crits,
## skills, cooldowns, area reach and the auto-caster all show.
##   godot --headless --path . res://tests/tools/class_dps_probe.tscn -- [SECONDS] [ZONE] [class,class...]
## A class written as class:skill+skill runs with only those skills on its bar
## (class: alone = basic attacks only), to see what each skill adds.
## Prints single-target and pack DPS per class, each relative to its median.
const Boost := preload("res://tools/boost_character.gd")

var main: Node
var _last_hp := {}
var _dealt := 0.0
var _dummies: Array[Mob] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 60.0
	var zone_id := StringName(args[1]) if args.size() > 1 else &"lotus_sanctum"
	var classes: Array = Array(args[2].split(",")) if args.size() > 2 else ClassData.IDS.map(func(c): return String(c))
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	main.hud.visible = true
	Engine.time_scale = 3.0
	var rows := []
	for entry in classes:
		var parts := String(entry).split(":")
		var bar: Variant = Array(parts[1].split("+", false)) if parts.size() > 1 else null
		rows.append(await _measure(StringName(parts[0]), zone_id, seconds, bar))
	Engine.time_scale = 1.0
	var medians := {}
	for key in ["single", "pack"]:
		var values := rows.map(func(r): return float(r[key]))
		values.sort()
		var half := values.size() / 2
		medians[key] = float(values[half]) if values.size() % 2 == 1 else (float(values[half - 1]) + float(values[half])) * 0.5
	for r in rows:
		print("DPS %-9s single %7.0f /s x%.2f | pack of 6 %7.0f /s x%.2f | atk %d crit %.0f%% haste %.0f%% dodge %.0f%% hp %d def %d" % [r.cls,
			r.single, float(r.single) / maxf(medians.single, 1.0), r.pack, float(r.pack) / maxf(medians.pack, 1.0),
			r.atk, r.crit * 100.0, r.haste * 100.0, r.dodge * 100.0, r.hp, r.def])
		print("BAR %-9s %s" % [r.cls, r.bar])
	get_tree().quit()


## Counts what the dummies lost since the last frame and heals them back to full.
func _physics_process(_delta: float) -> void:
	for mob in _dummies:
		if not is_instance_valid(mob):
			continue
		var id := mob.get_instance_id()
		if _last_hp.has(id) and mob.hp < int(_last_hp[id]):
			_dealt += float(int(_last_hp[id]) - mob.hp)
		if not mob.is_dead():
			mob.hp = mob.max_hp
		_last_hp[id] = mob.hp


## Fills the training ground up to [param count] dummies around the camp centre;
## anything else that walks in (the zone's boss, a wanderer) is removed, so area
## skills only ever see the dummies.
func _fill(zone: Node, hero: Hero, camp: Dictionary, count: int) -> void:
	_dummies = _dummies.filter(func(m): return is_instance_valid(m) and not m.is_dead())
	for node in get_tree().get_nodes_in_group("mobs"):
		if not _dummies.has(node) and not node.is_queued_for_deletion():
			node.remove_from_group("mobs")
			node.queue_free()
	var center := Vector3(camp.pos.x, 0, camp.pos.y)
	var level := int((int(camp.levels[0]) + int(camp.levels[1])) / 2)
	while _dummies.size() < count:
		var angle := TAU * _dummies.size() / float(count)
		var spot := center + (Vector3.ZERO if count == 1 else Vector3(cos(angle), 0, sin(angle)) * 2.2)
		var mob := Mob.new()
		mob.setup(StringName(camp.monsters[0]), level, spot, hero)
		mob.position = spot + Vector3(0, 0.3, 0)
		zone.add_child(mob)
		_dummies.append(mob)


func _run(zone: Node, hero: Hero, camp: Dictionary, count: int, seconds: float) -> float:
	_fill(zone, hero, camp, count)
	await get_tree().create_timer(2.5).timeout
	_last_hp.clear()
	_dealt = 0.0
	var t := 0.0
	while t < seconds:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		_fill(zone, hero, camp, count)
		Game.profile.hp = hero.stats.max_hp
		Game.profile.mp = hero.stats.max_mp
	return _dealt / seconds


## The bar an endgame player runs: the six hardest-hitting unlocked attacks
## (damage per second of cooldown, area skills counted as three targets,
## summons included) and the two self buffs with the most attack.
static func best_bar(cls: StringName) -> Array:
	var tier := Game.class_tier()
	var stars := int(Game.paragon().level)
	var attacks := []
	var buffs := []
	for skill in ClassData.pool(cls):
		if int(skill.level) > int(Game.profile.level) or ClassData.skill_tier(skill) > tier or int(skill.get("star", 0)) > stars:
			continue
		var fx: Dictionary = skill.get("fx", {})
		if float(skill.mult) > 0.0:
			var targets := 3.0 if String(skill.shape) in ["burst", "blast", "fan", "chain"] or skill.has("pierce") else 1.0
			attacks.append([float(skill.mult) * targets / maxf(float(skill.cd), 1.0), String(skill.id)])
		elif fx.has("buff") and float(fx.buff.get("atk", 0.0)) > 0.0:
			buffs.append([float(fx.buff.atk), String(skill.id)])
	attacks.sort_custom(func(a, b): return a[0] > b[0])
	buffs.sort_custom(func(a, b): return a[0] > b[0])
	var bar := attacks.slice(0, 6).map(func(e): return e[1]) + buffs.slice(0, 2).map(func(e): return e[1])
	while bar.size() < ClassData.SLOTS:
		bar.append("")
	return bar


func _measure(cls: StringName, zone_id: StringName, seconds: float, only: Variant = null) -> Dictionary:
	Game.new_profile(cls, "DPS", FaceKit.default_look())
	var bundle := {"slots": {"1": Game.profile.duplicate(true)}, "selectedSlot": 1}
	var result := Boost.boost_bundle(bundle, "DPS", String(cls))
	assert(not result.has("error"), str(result))
	Game.profile = bundle.slots["1"]
	var p := Game.profile
	var main_stat := String(JobData.resolve(cls, int(p.adv)).main)
	var points := int(p.points)
	p.attrs[main_stat] = int(p.attrs.get(main_stat, 0)) + points * 2 / 3
	p.attrs["vit"] = int(p.attrs.get("vit", 0)) + points - points * 2 / 3
	p.points = 0
	var para := Game.paragon()
	var spend := int(para.points)
	for key in ["atk", "hp", "def", "crit"]:
		var put := mini(spend / 2 if key == "atk" else spend, int(Game.PARAGON_STATS[key][2]))
		para.alloc[key] = put
		spend -= put
	para.points = spend
	for skill in ClassData.pool(cls) + ClassData.PASSIVES.get(cls, []):
		p.skills[String(skill.id)] = SkillRank.MAX
	p.party = []
	p.loadout = best_bar(cls)
	if only is Array:
		p.loadout = only + []
		while p.loadout.size() < ClassData.SLOTS:
			p.loadout.append("")
	await main.go(zone_id, true)
	await get_tree().create_timer(0.5).timeout
	var zone: Node = main.zone
	var hero: Hero = zone.hero
	# Empty every camp and stop its respawns: only the dummies stand in the field.
	for camp in zone._camps:
		camp.count = 0
		for mob in camp.mobs:
			if is_instance_valid(mob):
				mob.queue_free()
		camp.mobs = []
	_dummies.clear()
	var ground: Dictionary = zone._camps[0]
	hero.global_position = Vector3(ground.pos.x, 0.2, ground.pos.y - 3.0)
	hero._invulnerable_until = Time.get_ticks_msec() + int(seconds * 2000.0) + 60000
	hero.set_auto(true)
	var stats := HeroStats.compute(Game.profile)
	var single: float = await _run(zone, hero, ground, 1, seconds)
	var pack: float = await _run(zone, hero, ground, 6, seconds)
	return {"cls": String(cls), "bar": ",".join(Game.profile.loadout), "single": single, "pack": pack, "atk": int(stats.atk), "crit": float(stats.crit), "haste": float(stats.haste),
		"dodge": float(stats.dodge), "hp": int(stats.max_hp), "def": int(stats.def)}
