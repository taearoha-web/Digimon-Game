extends Node
## How the player's other character fights the guild war as the AI (Game.alt_war_fighter):
## a Six1Nine-like save (muaythai Lv.100 ★300, job adv 5, dragon god fist +13, divine
## Muay Thai armour and crown +10, the 200★ eclipse boots +10, ring and amulet, every piece
## ruby_3 / amethyst_3, STR 484 VIT 574 DEX 143, 60 stars each in atk/crit/def/haste/hp,
## a fire drake, every skill at ★5, no wings) is written to save slot 3 in Alpha; the one
## played is a warrior in Alpha who leaves the field once the war starts (out of it, like a
## spectator), so the war is AI only. Prints the alt's sheet as the war builds it against
## HeroStats.compute of its save and against the hero's own rules for the same save
## (swing interval, skill damage, cooldowns, crit damage), the skills it may cast, then
## PROBE_SECONDS of war time: its damage dealt, falls dealt and taken, every cast by skill,
## how its seconds went (down / falling back / in reach of a foe / chasing / nobody near),
## against the strongest world players' AIs of both guilds.
##   $G --headless --audio-driver Dummy --fixed-fps 15 --path . res://tests/tools/alt_war_probe.tscn
## env: PROBE_LEAD=0|1 (1: the alt picked to lead Alpha), PROBE_FAITHFUL=1|0 (0: it plays as
## an ordinary AI, Rival.faithful_on, the old way), PROBE_SECONDS (default 240),
## PROBE_SEED (default 1), PROBE_SPEED (Engine.time_scale, 4).

const MAIN_SLOT := 2
const ALT_SLOT := 3
const ALT_NAME := "Six1Nine"


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	# PROBE_DAYS: days after the world opened (default: today's world).
	var days := float(_env("PROBE_DAYS", "-1"))
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + days * 86400.0 - WorldPlayers.now() if days >= 0.0 else 0.0
	Rival.faithful_on = _env("PROBE_FAITHFUL", "1") != "0"
	seed(int(_env("PROBE_SEED", "1")))
	make_six1nine(ALT_SLOT, WorldPlayers.ALPHA)
	Game.slot = MAIN_SLOT
	Game.new_profile(&"warrior", "GL")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.join_guild(WorldPlayers.ALPHA)
	Game.save()
	var lead := _env("PROBE_LEAD", "0") == "1"
	if lead:
		Game.set_guild_leader(WorldPlayers.ALPHA, Game.alt_pick(ALT_SLOT))
	else:
		Game.set_guild_leader(WorldPlayers.ALPHA, WorldPlayers.guild_leader(WorldPlayers.ALPHA, WorldPresence.clock()))
	print("PROBE faithful=%s lead=%s" % [Rival.faithful_on, lead])
	await _war(float(_env("PROBE_SECONDS", "240")))
	WorldPresence.clock_offset = 0.0
	get_tree().quit(0)


## The Six1Nine-like save, written to `slot` in guild `g` (the played slot is left as it was).
static func make_six1nine(slot: int, g: int) -> Dictionary:
	var keep := Game.slot
	Game.slot = slot
	Game.new_profile(&"muaythai", ALT_NAME)
	var p: Dictionary = Game.profile
	p.level = 100
	p.adv = 5
	p["paragon"] = {"level": 300, "exp": 0, "points": 0, "spent": 300, "alloc": {"atk": 60, "crit": 60, "def": 60, "haste": 60, "hp": 60}}
	p["attrs"] = {"str": 484, "int": 0, "dex": 143, "vit": 574}
	var rng := RandomNumberGenerator.new()
	rng.seed = 619
	var equip := {}
	equip["weapon"] = DragonGearData.weapon(&"muaythai", rng)
	equip.weapon["plus"] = 13
	for s in ["armor", "helm"]:
		equip[s] = DivineGearData.item(&"muaythai", s, rng)
		equip[s]["plus"] = 10
	for s in ["boots", "ring", "amulet"]:
		equip[s] = StarProgression.item(&"muaythai", 200, s, rng)
		equip[s]["plus"] = 10 if s == "boots" else 0
	for s in equip:
		var item: Dictionary = equip[s]
		item["sockets"] = maxi(3, int(item.get("sockets", 0)))
		var gem := "ruby_3" if s in ["weapon", "ring", "amulet"] else "amethyst_3"
		item["gems"] = [gem, gem, gem]
	p["equip"] = equip
	p["mounts"] = {"fire_drake": 3}
	p["mount"] = "fire_drake"
	var ranks := {}
	for skill in JobData.resolve(&"muaythai", 5).skills:
		ranks[ClassData.rank_id(skill)] = 5
	for passive in ClassData.passives(&"muaythai"):
		ranks[String(passive.id)] = 5
	p["skills"] = ranks
	p.flags[Game.GUILD_FLAG] = g
	p.hp = Game.stats_now().max_hp
	Game.save()
	var out := p.duplicate(true)
	Game.slot = keep
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _war(seconds: float) -> void:
	Game.current_zone = &"guildwar"
	Game.guildwar_resuming = false
	Game.guildwar_league = {"ours": Game.guild(), "theirs": WorldPlayers.NEVERDIE, "at": int(WorldPresence.clock())}
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		print("PROBE no match")
		return
	var alt: GuildFighter = null
	for f in m.all_fighters():
		if f.alt_slot == ALT_SLOT:
			alt = f
	if alt == null:
		print("PROBE the alt is not on the field")
		return
	_sheet(alt)
	m._timer = 0.05
	while m.state != "fight":
		await get_tree().physics_frame
	GuildWarMatch._leave_war(zone.hero)
	Engine.time_scale = float(_env("PROBE_SPEED", "4"))
	var kills := {}
	var falls := {}
	for f in m.all_fighters():
		f.fell.connect(func(victim: GuildFighter, killer: Node) -> void:
			falls[victim] = int(falls.get(victim, 0)) + 1
			if killer is GuildFighter:
				kills[killer] = int(kills.get(killer, 0)) + 1)
	var time := {"down": 0.0, "falling_back": 0.0, "in_reach": 0.0, "chasing": 0.0, "nobody": 0.0, "keep_back": 0.0}
	var clock := 0.0
	var step := 0.0
	var mp_low := 0.0
	while clock < seconds and m.state == "fight":
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		clock += dt
		step += dt
		if step < 0.5:
			continue
		step = 0.0
		if alt.is_dead():
			time.down += 0.5
			continue
		if alt.keep_back:
			time.keep_back += 0.5
		if alt.mp < 130.0:
			mp_low += 0.5
		if alt.is_retreating():
			time.falling_back += 0.5
			continue
		var v: Node3D = alt._victim
		if v == null or not is_instance_valid(v) or (v is GuildFighter and (v as GuildFighter).is_dead()):
			time.nobody += 0.5
		elif _flat(v.global_position, alt.global_position) <= float(alt.class_data.attack.range) + 1.5 + (float(v.call("body_radius")) if v.has_method("body_radius") else 0.0):
			time.in_reach += 0.5
		else:
			time.chasing += 0.5
	Engine.time_scale = 1.0
	var rows: Array = m.all_fighters().duplicate()
	rows.sort_custom(func(a, b): return a.power > b.power)
	print("PROBE %.0f s of war, the alt %s (power %.0f, rank %d of %d by power)" % [clock, alt.shown_name(), alt.power, rows.find(alt) + 1, rows.size()])
	print("PROBE alt: dealt %d (%.0f/s) falls dealt %d taken %d leader %s casts %s" % [alt.dealt, float(alt.dealt) / maxf(clock, 1.0), int(kills.get(alt, 0)), int(falls.get(alt, 0)), alt.is_leader, JSON.stringify(alt.casts)])
	var shares := {}
	for k in time:
		shares[k] = "%d%%" % int(round(100.0 * float(time[k]) / maxf(clock, 1.0)))
	print("PROBE alt time: %s, MP under 130 %d%%" % [JSON.stringify(shares), int(round(100.0 * mp_low / maxf(clock, 1.0)))])
	var by_dealt: Array = m.all_fighters().duplicate()
	by_dealt.sort_custom(func(a, b): return a.dealt > b.dealt)
	print("PROBE rank of the alt by damage dealt: %d of %d" % [by_dealt.find(alt) + 1, by_dealt.size()])
	for i in mini(8, rows.size()):
		var f: GuildFighter = rows[i]
		var n := 0
		for k in f.casts:
			n += int(f.casts[k])
		print("PROBE  top%d t%d %-12s %-22s power %7.0f dealt %8d (%6.0f/s) falls %d/%d casts %d%s" % [i + 1, f.team, String(f.member["class"]), String(f.member.name).left(22), f.power, f.dealt, float(f.dealt) / maxf(clock, 1.0), int(kills.get(f, 0)), int(falls.get(f, 0)), n, " LEADER" if f.is_leader else ""])
	zone.queue_free()
	for i in 3:
		await get_tree().process_frame
	Game.guildwar_clear_checkpoint()


## The alt's sheet in the war against its save's, and against the hero's rules.
func _sheet(alt: GuildFighter) -> void:
	var sheet := HeroStats.compute(alt._profile)
	print("PROBE save sheet: max_hp %d atk %.0f def %.0f crit %.3f crit_dmg %.2f haste %.3f cdr %.2f dodge %.3f power %.0f" % [sheet.max_hp, sheet.atk, sheet.def, sheet.crit, HeroStats.CRIT_DAMAGE + float(sheet.crit_dmg), sheet.haste, sheet.cdr, sheet.dodge, GuildWarData.power_of(sheet)])
	print("PROBE war fighter: max_hp %d atk %.0f def %.0f difficulty %.2f faithful %s dodge %.3f wings %s" % [alt.max_hp, float(alt.rstats.atk), float(alt.stats.def), alt.difficulty, alt.faithful, alt._dodge, alt.has_wings()])
	var attack: Dictionary = alt.class_data.attack
	var ai_interval := float(attack.interval) * ((1.0 - alt.haste()) if alt.faithful else lerpf(1.6, 1.0, alt.difficulty))
	print("PROBE swing interval: hero %.3f s, war fighter %.3f s" % [float(attack.interval) * (1.0 - float(sheet.haste)), ai_interval])
	var known: PackedStringArray = []
	var allowed: PackedStringArray = []
	var tier := 1 + int(alt._profile.adv)
	for skill in alt.class_data.skills:
		if not ClassData.knows(skill, alt.level, tier, alt._stars()):
			continue
		var rank := maxi(1, int(alt._profile.skills.get(ClassData.rank_id(skill), 1)))
		var hero_cd := SkillRank.cooldown(skill, rank) * (1.0 - float(sheet.haste)) * (1.0 - float(sheet.cdr))
		var ok := ClassData.ai_allows(skill, alt._buff_kit) and (alt.has_wings() or not bool(skill.get("requires_wings", false)))
		known.append("%s★%d" % [skill.id, rank])
		if ok:
			allowed.append(String(skill.id))
		print("PROBE  skill %-22s %-6s hero: x%.2f cd %.1f | war: x%.2f cd %.1f %s" % [skill.id, skill.shape, SkillRank.power(rank), hero_cd, SkillRank.power(alt.skill_rank(skill)), alt.skill_cd(skill), "" if ok else "(NOT CAST BY THE AI)"])
	print("PROBE buff kit: %s" % JSON.stringify(alt._buff_kit))
