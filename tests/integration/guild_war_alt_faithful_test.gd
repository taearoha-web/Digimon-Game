extends Node
## The player's other character fights the guild war as its save plays (Rival.faithful,
## Game.alt_war_fighter): its sheet is HeroStats.compute of its save, its skills cast at
## their star ranks with its haste (swing, cooldowns), every buff it knows (its star buff
## วงประเจียด too) counts like the hero's, and a skill that needs wings waits for them.
## An ordinary world player's AI is left as it was.
## godot --headless --path . res://tests/integration/guild_war_alt_faithful_test.tscn
const Probe := preload("res://tests/tools/alt_war_probe.gd")
const ALT_SLOT := 3
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _skill(f: Rival, id: String) -> Dictionary:
	for skill in f.class_data.skills:
		if String(skill.id) == id:
			return skill
	return {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	GameSettings.load_settings()
	var saved := Probe.make_six1nine(ALT_SLOT, WorldPlayers.ALPHA)
	Game.slot = 2
	Game.new_profile(&"warrior", "GL")
	Game.profile.level = 100
	var info := Game.alt_war_fighter(ALT_SLOT)
	check(not info.is_empty() and bool(info.get("faithful", false)), "the alt reads as a faithful fighter")
	var sheet := HeroStats.compute(saved)
	var field := Node3D.new()
	add_child(field)
	var f := GuildFighter.new()
	f.setup_fighter(info, GuildFighter.TEAM_ENEMY, null, Vector3.ZERO, "[3DLnw]")
	field.add_child(f)
	check(f.faithful and f.difficulty == 1.0, "plays as the player's character (no AI slips)")
	check(f.max_hp == int(sheet.max_hp) and is_equal_approx(float(f.rstats.atk), float(sheet.atk)) and is_equal_approx(float(f.stats.def), float(sheet.def)), "its sheet is its save's (hp %d/%d atk %.0f/%.0f def %.0f/%.0f)" % [f.max_hp, sheet.max_hp, f.rstats.atk, sheet.atk, f.stats.def, sheet.def])
	check(is_equal_approx(f.power, GuildWarData.power_of(sheet)), "its power is its save's")
	check(f.haste() > 0.2 and is_equal_approx(f.haste(), float(sheet.haste)), "its DEX and haste stars speed it (%.3f)" % f.haste())
	var sun := _skill(f, "sun_fist")
	check(f.skill_rank(sun) == 5 and is_equal_approx(f.skill_cd(sun), SkillRank.cooldown(sun, 5) * (1.0 - float(sheet.haste))), "sun_fist at ★5 with its haste (cd %.2f)" % f.skill_cd(sun))
	check(f.skill_mp(sun) == float(SkillRank.mp(sun, 5)), "MP by its rank")
	for id in ["vow_of_the_ring", "wai_khru", "ring_guard"]:
		check(f._buff_kit.has(id), "brings its own buff %s (kit %s)" % [id, f._buff_kit])
	for id in ["naga_coil_fist", "solar_knee_barrage", "vow_of_the_ring", "three_realms_fist"]:
		var s := _skill(f, id)
		check(not s.is_empty() and f._knows(s), "may cast its star skill %s" % id)
	# Its usable skills as the AI builds them: no wings, so no หนุมานแผลงฤทธิ์.
	f._try_skill(f, 100.0)
	var usable: Array = f._usable.map(func(s): return String(s.id))
	check(not usable.has("heaven_ring_cataclysm") and usable.has("three_realms_fist") and usable.has("vow_of_the_ring"), "no wings: no skill that needs them; its star skills are there (%s)" % [usable])
	# วงประเจียด: ATK +90% and crit +20% (grown by ★5) stacking with its ritual like the hero's.
	f.start_fight()
	f.mp = 9999.0
	var mp0 := f.mp
	f._cast(_skill(f, "vow_of_the_ring"), f)
	check(int(f.casts.get("vow_of_the_ring", 0)) == 1 and is_equal_approx(mp0 - f.mp, float(SkillRank.mp(_skill(f, "vow_of_the_ring"), 5))), "the cast is counted and costs its ranked MP")
	for i in 40:
		await get_tree().physics_frame
	f._restack_buffs()
	check(f._atk_boost > 1.9 and f._buff_crit >= 0.2, "its star buff counts (atk x%.2f, crit +%.2f)" % [f._atk_boost, f._buff_crit])
	# An ordinary world player's AI: as it was.
	var w := GuildFighter.new()
	w.setup_fighter(WorldPlayers.fighter(0, WorldPresence.clock()), GuildFighter.TEAM_ENEMY, null, Vector3.ZERO, "[x]")
	var some: Dictionary = w.class_data.skills[0]
	check(not w.faithful and w.haste() == 0.0 and w.skill_rank(some) == 1 and is_equal_approx(w.skill_cd(some), float(some.cd) * lerpf(1.7, 1.05, w.difficulty)), "a world player's AI is unchanged")
	w.free()
	field.queue_free()
	await get_tree().process_frame
	print("GUILD WAR ALT FAITHFUL: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)
