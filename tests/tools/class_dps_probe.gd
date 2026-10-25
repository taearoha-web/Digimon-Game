extends Node
## Real-combat damage per second of every class at the end of the game: a Lv.100,
## ★200 hero, every job advancement, the boost tool's best +10 gear, a standard
## build (two thirds of the stat points in the main stat, the rest in VIT; star
## points as balance_probe spends them) and every skill at rank 5, hunting on auto
## in one field for a fixed stretch of game time. Counts the health it takes off
## monsters (its summons included), so attack speed, crits, skills, cooldowns and
## the auto-caster all show.
##   godot --headless --path . res://tests/tools/class_dps_probe.tscn -- [SECONDS] [ZONE] [class,class...]
## Prints one DPS line per class, then each class relative to the median.
const Boost := preload("res://tools/boost_character.gd")

var main: Node
var _last_hp := {}
var _dealt := 0.0


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
	for cls in classes:
		rows.append(await _measure(StringName(cls), zone_id, seconds))
	Engine.time_scale = 1.0
	var values := rows.map(func(r): return float(r.dps))
	values.sort()
	var half := values.size() / 2
	var median: float = float(values[half]) if values.size() % 2 == 1 else (float(values[half - 1]) + float(values[half])) * 0.5
	for r in rows:
		print("DPS %-9s %8.0f /s  x%.2f of median | atk %d crit %.0f%% haste %.0f%% dodge %.0f%% hp %d def %d" % [r.cls, r.dps, float(r.dps) / maxf(median, 1.0),
			r.atk, r.crit * 100.0, r.haste * 100.0, r.dodge * 100.0, r.hp, r.def])
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null:
			continue
		var id := mob.get_instance_id()
		if _last_hp.has(id) and mob.hp < int(_last_hp[id]):
			_dealt += float(int(_last_hp[id]) - mob.hp)
		_last_hp[id] = mob.hp


func _measure(cls: StringName, zone_id: StringName, seconds: float) -> Dictionary:
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
	for skill in ClassData.pool(cls):
		p.skills[String(skill.id)] = SkillRank.MAX
	p.party = []
	p.loadout = ["", "", "", "", "", "", "", ""]
	Game.fill_loadout()
	await main.go(zone_id, true)
	await get_tree().create_timer(0.5).timeout
	var hero: Hero = main.zone.hero
	if not main.zone._camps.is_empty():
		var camp: Dictionary = main.zone._camps[0]
		hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y)
	hero._invulnerable_until = Time.get_ticks_msec() + int(seconds * 1000.0) + 60000
	hero.set_auto(true)
	# Let the first pull happen, then count.
	await get_tree().create_timer(3.0).timeout
	_last_hp.clear()
	_dealt = 0.0
	var stats := HeroStats.compute(Game.profile)
	var t := 0.0
	while t < seconds:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		Game.profile.hp = hero.stats.max_hp
		Game.profile.mp = hero.stats.max_mp
	return {"cls": String(cls), "dps": _dealt / seconds, "atk": int(stats.atk), "crit": float(stats.crit), "haste": float(stats.haste),
		"dodge": float(stats.dodge), "hp": int(stats.max_hp), "def": int(stats.def)}
