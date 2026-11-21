extends Node
## The castle without switches (headless): the throne room has no switch pads, no barrier
## over the altar and no switch rule (nothing in SiegeArena, GuildWarMatch, the HUD, the
## leader's orders or the online status about them). With the gates down the altar is open
## to every guild: the hero leading ours starts the count by standing on it, an AI leader
## sent up starts it on its own, CAPTURE_TIME s on it takes the castle; stepping off waits
## the count, another guild's leader on the circle takes over a waiting count, falling
## starts it over. An older checkpoint's switch keys are ignored and cleared; an older
## leader's status with "sw" / "swa" and a fourth capture field reads fine. Then the AI on
## its own: attackers storm the throne room (no switch phase), their leader right behind
## the front, and take the castle.
## godot --headless --path . res://tests/integration/castle_altar_test.tscn
var failures: Array[String] = []
var checks := 0
const SEED := 424242


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GWA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_no_switches_in_code()
	await _altar_open()
	await _resume_old_checkpoint()
	await _ai_assault()
	print("CASTLE ALTAR: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


## Nothing of the switches is left in the scripts.
func _no_switches_in_code() -> void:
	var arena: Dictionary = (load("res://world/siege_arena.gd") as Script).get_script_constant_map()
	for key in ["SWITCHES", "SWITCH_RADIUS", "SWITCH_NAMES", "SWITCH_X", "SWITCH_Z"]:
		check(not arena.has(key), "SiegeArena has no %s" % key)
	var match_consts: Dictionary = (load("res://world/guild_war_match.gd") as Script).get_script_constant_map()
	for key in ["SWITCH_EVERY", "SWITCH_TAKE_TIME", "RULE_BOTH", "BARRIER_TEXT", "BARRIER_COLOR"]:
		check(not match_consts.has(key), "GuildWarMatch has no %s" % key)
	var cmd: Dictionary = (load("res://world/guild_war_commander.gd") as Script).get_script_constant_map()
	check(not cmd.has("SECURE") and not cmd.has("ORDER_SWITCH") and not cmd.has("ORDER_SPLIT"), "the commander has no switch tactic nor switch orders")
	check(not GuildWarCommander.ORDERS.has("switch") and not GuildWarCommander.ORDERS.has("switches"), "the leader's orders: no switch order (%s)" % [GuildWarCommander.ORDERS])
	check(not GuildWarDoctrine.PHASES.has("switch") and not GuildWarDoctrine.SQUAD_NAMES.has("switch"), "the doctrine: no switch phase nor switch squad")
	var doc := str(GuildWarMatch.PLAN_NAMES.values())
	check(not doc.contains("สวิตช์"), "no plan names a switch")


func _open_war(siege := {}) -> Zone:
	Game.current_zone = &"guildwar"
	var info := {"gates": [0, 0, 0, 0, 0], "owner": -1}
	info.merge(siege, true)
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, info)
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _away(f: GuildFighter) -> void:
	f.global_position = f.spawn_point + Vector3(0, 0.3, 0)


func _hold_still(m: GuildWarMatch) -> void:
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
		f._dodge = 0.0
		_away(f)
	m.set_process(false)


func _altar_open() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.front_gate() == null, "the war opens with the gates down")
	if m == null:
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "the fight begins")
	_hold_still(m)
	for node_name in ["CastleSwitch", "CastleSwitchRight", "AltarBarrier", "SwitchLabel"]:
		check(zone.find_child(node_name, true, false) == null, "no %s in the castle" % node_name)
	check(zone.find_child("AltarCrystal", true, false) != null, "the altar's crystal stands at the back")
	for method in ["barrier_up", "holds_switch", "switch_text", "barrier_line", "order_party_switch", "read_switches"]:
		check(not m.has_method(method), "GuildWarMatch has no %s()" % method)
	check(not m.siege_status().contains("สวิตช์") and not m.siege_status().contains("บาเรีย"), "the status line names no switch nor barrier (%s)" % m.siege_status())
	# The HUD: no switch row, no barrier warning, no party switch button; the orders panel
	# has no switch order.
	var hud := GuildWarHud.new()
	add_child(hud)
	hud.bind(m)
	hud._update(0.0, false)
	for node_name in ["SwitchRow", "PartySwitch", "BarrierWarning", "SwitchChip", "BarrierChip"]:
		check(hud.find_child(node_name, true, false) == null, "the HUD has no %s" % node_name)
	var labels := hud.order_choices().map(func(c): return String(c[2]))
	check(not labels.any(func(t: String): return t.contains("สวิตช์")), "the orders: no switch order (%s)" % [labels])
	check(labels.has("รวมพลที่ตัวฉัน") and labels.has("ถอยกลับค่าย") and labels.has("บุกแท่น/คุ้มกัน") and labels.has("ตามแผน AI"), "the other orders stay (%s)" % [labels])
	# The hero leads and steps on the altar: the count starts at once, nothing to hold first.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(m.hero_can_capture(), "the hero on the altar may take it straight away")
	m.start_hero_capture()
	check(m.capturer() == hero, "the capture starts")
	m._tick_capture(5.0)
	check(is_equal_approx(float(m.capture.progress), 5.0), "the count runs at full speed (%.1f)" % float(m.capture.get("progress", 0.0)))
	check(m.capture_line().contains("กำลังยึดแท่น") and not m.capture_line().contains("บาเรีย"), "the HUD's line tells the count (%s)" % m.capture_line())
	# Off the circle: the count waits; back on: it goes on.
	hero.global_position = SiegeArena.ALTAR + Vector3(6.0, 0.3, 0)
	m._tick_capture(1.0)
	check(bool(m.capture.paused) and is_equal_approx(float(m.capture.progress), 5.0), "off the circle the count waits")
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m._tick_capture(1.0)
	check(not bool(m.capture.paused) and is_equal_approx(float(m.capture.progress), 6.0), "back on it goes on (%.1f)" % float(m.capture.progress))
	# Their leader on the circle while ours waits off it: it takes over.
	var lead: GuildFighter = m.ai_leader(GuildFighter.TEAM_ENEMY)
	check(lead != null, "theirs have a leader")
	hero.global_position = SiegeArena.ALTAR + Vector3(6.0, 0.3, 0)
	lead.global_position = SiegeArena.ALTAR + Vector3(0.5, 0.3, 0)
	m._tick_capture(0.5)
	check(m.capturer() == lead and int(m.capture.team) == GuildFighter.TEAM_ENEMY, "their leader on the circle takes over our waiting count")
	# Their leader falls: the count is lost.
	m._tick_capture(3.0)
	lead.hp = 0
	lead._die()
	m._tick_capture(0.1)
	check(m.capture.is_empty(), "their leader falls: the count starts over")
	# An AI leader sent up (capture_role) starts its count on the altar by itself and
	# takes the castle after CAPTURE_TIME.
	lead.respawn()
	lead.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	lead.capture_role = true
	m._tick_capture(0.1)
	check(m.capturer() == lead, "an AI leader on the altar starts on its own")
	for i in int(GuildWarMatch.CAPTURE_TIME) + 2:
		if m.castle_owner >= 0:
			break
		m._tick_capture(1.0)
	check(m.castle_owner == GuildFighter.TEAM_ENEMY, "after %d s the castle is theirs" % int(GuildWarMatch.CAPTURE_TIME))
	# An older leader's online status (switch codes, a fourth capture field) reads fine.

	m.mirror_sync("gw", {"st": "fight", "tl": 500.0, "s": [1, 2], "o": -1, "cp": [0, 12.0, false, true], "sw": [0, 3], "swa": [[0, -1], [1, 0]]})
	check(m.capture.has("progress") and is_equal_approx(float(m.capture.progress), 12.0) and not m.capture.has("barrier"), "an older leader's status: the count read, its switch codes and barrier ignored (%s)" % [m.capture])

	hud.queue_free()
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


## An older checkpoint's switch holders are ignored (and cleared with the rest).
func _resume_old_checkpoint() -> void:
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	var flags: Dictionary = Game.profile["flags"]
	check(not flags.has("gw_r_sw") and not flags.has("gw_r_sw1"), "a checkpoint keeps no switch")
	flags["gw_r_sw"] = 2
	flags["gw_r_sw1"] = 1
	var cp := Game.guildwar_checkpoint()
	check(not cp.is_empty() and not cp.has("switch") and not cp.has("switches"), "an older checkpoint's switch keys are ignored (%s)" % [cp.keys()])
	Game.guildwar_clear_checkpoint()
	check(not flags.has("gw_r_sw") and not flags.has("gw_r_sw1"), "clearing the checkpoint drops the old switch keys")


## The AI on its own: theirs storm an undefended castle (ours held at their camp) and take
## it; no switch phase; their leader comes up behind its front (never left at the camp).
func _ai_assault() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "ai: no match")
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "ai: the fight begins")
	for f in m.allies:
		f.set_physics_process(false)
		_away(f)
	hero.global_position = GuildWarMatch.hero_camp()
	hero.set_physics_process(false)
	var theirs: GuildWarCommander = m.commanders[1]
	var lead: GuildFighter = m.ai_leader(GuildFighter.TEAM_ENEMY)
	var phases := {}
	var at_camp := 0
	var samples := 0
	var t0 := Time.get_ticks_msec()
	var war_s := 0.0
	Engine.time_scale = 4.0
	while m.castle_owner < 0 and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.25, true, false, true).timeout
		m.time_left = GuildWarData.DURATION
		war_s += 0.25 * Engine.time_scale
		phases[m.phase_key(GuildFighter.TEAM_ENEMY)] = true
		if war_s > 20.0 and not lead.is_dead() and not lead.is_retreating():
			samples += 1
			if theirs._in_camp(lead):
				at_camp += 1
	Engine.time_scale = 1.0
	print("ai: the castle fell to theirs after about %.0f s of war" % war_s if m.castle_owner == GuildFighter.TEAM_ENEMY else "ai: no capture after %.0f s of war" % war_s)
	check(m.castle_owner == GuildFighter.TEAM_ENEMY, "ai: theirs take the castle on their own (owner %d, capture %s, tactic %s)" % [m.castle_owner, m.capture, theirs.tactic])
	check(not phases.has("switch"), "ai: no switch phase (%s)" % [phases.keys()])
	check(samples > 0 and at_camp * 10 <= samples, "ai: their leader is out with its guild, not at the camp (%d of %d at the camp)" % [at_camp, samples])
	check(not theirs.said.any(func(t: String): return t.contains("สวิตช์") or t.contains("บาเรีย")), "ai: no call names a switch or the barrier (%s)" % [theirs.said])
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
