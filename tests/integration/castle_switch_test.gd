extends Node
## The castle's two switches and the altar's barrier (headless): a guild holds a switch
## while someone of it stands in the circle and nobody of the other guild does; the
## barrier stands for a guild with 0 or 1 switch held (no capture can start), falls with
## both (the count runs), comes back the moment one is lost (the count freezes where it
## was, the progress kept) and falls again when it is retaken (the count goes on from the
## same second); the leader leaving the throne room or falling counts for nothing; the HUD
## shows both switches and the barrier's warning; the hero holds a switch by standing in
## it; the party can be sent to one. Then the AI: attackers post holders on both switches
## (tanks first), take them and capture the castle on their own (a fixed seed); the
## holder of the castle posts damage dealers to contest the switches.
## godot --headless --path . res://tests/integration/castle_switch_test.tscn
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
	Game.new_profile(&"warrior", "GWS")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_pure_rules()
	await _switches_and_barrier()
	await _ai_assault()
	print("CASTLE SWITCH: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _pure_rules() -> void:
	check(GuildWarMatch.switch_holder(1, 0) == GuildFighter.TEAM_ALLY and GuildWarMatch.switch_holder(0, 3) == GuildFighter.TEAM_ENEMY, "one guild alone in the circle holds the switch")
	check(GuildWarMatch.switch_holder(2, 1) == -1 and GuildWarMatch.switch_holder(0, 0) == -1, "contested or empty: nobody holds it")
	check(SiegeArena.SWITCHES.size() == 2 and SiegeArena.SWITCHES[0].x < 0.0 and SiegeArena.SWITCHES[1].x > 0.0, "a switch in the left corner and one in the right")
	for k in 2:
		var p: Vector3 = SiegeArena.SWITCHES[k]
		check(SiegeArena.section(p) == 4 and SiegeArena.hall_rect().has_point(Vector2(p.x, p.z)) and absf(p.x) + SiegeArena.SWITCH_RADIUS < SiegeArena.THRONE_HALF - 1.5 and p.z - SiegeArena.SWITCH_RADIUS > SiegeArena.BACK_Z + 1.5, "switch %d stands inside the throne room, clear of the walls" % k)
		check(Vector2(p.x - SiegeArena.ALTAR.x, p.z - SiegeArena.ALTAR.z).length() > 20.0, "switch %d is far from the altar (the guild must split)" % k)


## A war with the gates down (a fixed seed), the AI held still.
func _open_war() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _away(f: GuildFighter) -> void:
	f.global_position = f.spawn_point + Vector3(0, 0.3, 0)


func _switches_and_barrier() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.front_gate() == null, "the war opens with the gates down")
	if m == null:
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "the fight begins")
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
		f._dodge = 0.0
		_away(f)
	m.set_process(false)
	check(zone.find_child("CastleSwitch0", true, false) != null and zone.find_child("CastleSwitch1", true, false) != null, "both switch pads stand in the castle")
	check(zone.find_child("AltarBarrier", true, false) != null, "the altar has its barrier")
	var lines: Array[String] = []
	m.feed.connect(func(text: String, _t: int): lines.append(text))
	# Nobody on a switch: the barrier stands for both guilds.
	m.read_switches()
	check(m.switch_owner == [-1, -1] and m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY), "no switch held: the barrier stands for both")
	check(m._barrier.visible, "the barrier dome is shown")
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(not m.hero_can_capture() and m.hero_blocked_by_barrier(), "the hero on the altar cannot start behind the barrier")
	m.start_hero_capture()
	check(m.capture.is_empty(), "pressing does nothing behind the barrier")
	check(m.barrier_line() == GuildWarMatch.BARRIER_TEXT, "the HUD warns: %s" % m.barrier_line())
	var toasts: Array[String] = []
	var listen := func(text: String, _kind: StringName): toasts.append(text)
	Game.toast.connect(listen)
	m._altar_hint_tick()
	m._altar_hint_tick()
	check(toasts.filter(func(x: String): return x == GuildWarMatch.BARRIER_TEXT).size() == 1, "the hero is told once why (%s)" % [toasts])
	Game.toast.disconnect(listen)
	# The HUD: two chips and the warning.
	var hud := GuildWarHud.new()
	add_child(hud)
	hud.bind(m)
	hud._update(0.0, false)
	check(hud._switch_row.visible and hud.switch_texts()[0] == "สวิตช์ซ้าย: ว่าง" and hud.switch_texts()[1] == "สวิตช์ขวา: ว่าง", "the HUD shows both switches empty (%s)" % [hud.switch_texts()])
	check(hud.switch_texts()[2] == GuildWarMatch.BARRIER_TEXT, "and the barrier's warning")
	# One switch: still barred.
	var ours: Array[GuildFighter] = []
	for f in m.allies:
		ours.append(f)
	var theirs: Array[GuildFighter] = []
	for f in m.enemies:
		if f != m.enemy_leader:
			theirs.append(f)
	check(ours.size() >= 4 and theirs.size() >= 2, "enough fighters for the test (%d / %d)" % [ours.size(), theirs.size()])
	ours[0].global_position = SiegeArena.SWITCHES[0] + Vector3(0.5, 0.3, 0.5)
	m.read_switches()
	check(m.switch_owner == [GuildFighter.TEAM_ALLY, -1] and m.switches_held(GuildFighter.TEAM_ALLY) == 1, "a fighter of ours in the left circle holds it")
	check(lines.any(func(t: String): return t.contains("ยึดสวิตช์ซ้ายได้")), "the feed tells the switch taken")
	check(m.barrier_up(GuildFighter.TEAM_ALLY) and not m.hero_can_capture(), "one switch: the barrier still stands")
	m.start_hero_capture()
	check(m.capture.is_empty(), "one switch: no capture")
	# The hero holds the right switch by standing in it.
	hero.global_position = SiegeArena.SWITCHES[1] + Vector3(0, 0.3, 0)
	m.read_switches()
	check(m.switch_owner == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ALLY] and not m.barrier_up(GuildFighter.TEAM_ALLY), "the hero standing in the right circle holds it: both held, the barrier falls for us")
	check(m.barrier_up(GuildFighter.TEAM_ENEMY) and not m._barrier.visible, "it stays up for the other guild; the dome is gone")
	check(lines.any(func(t: String): return t.contains("ยึดสวิตช์ครบ")), "the feed tells both are held")
	# The hero leads: a fighter takes the right switch over and the hero goes to the altar.
	ours[1].global_position = SiegeArena.SWITCHES[1] + Vector3(-0.5, 0.3, 0)
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m.read_switches()
	check(m.hero_can_capture() and m.barrier_line() == "", "both held: the hero may take the altar, no warning")
	m.start_hero_capture()
	check(m.capturer() == hero, "the capture starts")
	m._tick_capture(5.0)
	check(is_equal_approx(float(m.capture.progress), 5.0), "the count runs (%.1f)" % float(m.capture.get("progress", 0.0)))
	hud._update(0.0, false)
	check(hud.switch_texts()[0] == "สวิตช์ซ้าย: เรา" and hud.switch_texts()[1] == "สวิตช์ขวา: เรา", "the HUD shows both ours (%s)" % [hud.switch_texts()])
	# An enemy steps into the right circle: contested, the barrier is back, the count freezes.
	theirs[0].global_position = SiegeArena.SWITCHES[1] + Vector3(0.8, 0.3, 0.8)
	m.read_switches()
	check(m.switch_owner[1] == -1 and m.switch_contested[1] and m.barrier_up(GuildFighter.TEAM_ALLY), "one enemy in the circle: contested, not held, the barrier is back")
	m._tick_capture(7.0)
	check(not m.capture.is_empty() and is_equal_approx(float(m.capture.progress), 5.0) and bool(m.capture.barrier) and bool(m.capture.paused), "the count freezes at 5 s, kept (%s)" % m.capture)
	check(m.capture_line().contains("บาเรีย") and m.barrier_line() == GuildWarMatch.BARRIER_TEXT, "the bar says why: %s" % m.capture_line())
	check(m._barrier.visible, "the dome is back")
	hud._update(0.0, false)
	check(hud.switch_texts()[1] == "สวิตช์ขวา: แย่งกัน" and hud.switch_texts()[2] != "", "the HUD shows the right switch contested and the warning (%s)" % [hud.switch_texts()])
	check(lines.any(func(t: String): return t.contains("บาเรียกลับมา")), "the feed tells the barrier came back")
	# The enemy is driven off: the count goes on from 5.
	_away(theirs[0])
	m.read_switches()
	m._tick_capture(3.0)
	check(not m.barrier_up(GuildFighter.TEAM_ALLY) and is_equal_approx(float(m.capture.progress), 8.0) and not bool(m.capture.barrier), "retaken: the count goes on from the same second (%.1f)" % float(m.capture.progress))
	check(lines.any(func(t: String): return t.contains("บาเรียหายไป")), "the feed tells the barrier fell again")
	# The left holder falls: lost, the count waits; another takes its place: it goes on.
	var holder := ours[0]
	var tries := 0
	while not holder.is_dead() and tries < 80:
		BurstGuard.clear()
		holder.take_hit(holder.max_hp, false)
		tries += 1
	m.read_switches()
	check(holder.is_dead() and m.switch_owner[0] == -1 and m.barrier_up(GuildFighter.TEAM_ALLY), "the holder fell: the left switch is lost")
	m._tick_capture(4.0)
	check(is_equal_approx(float(m.capture.progress), 8.0), "lost: no progress (%.1f)" % float(m.capture.progress))
	ours[2].global_position = SiegeArena.SWITCHES[0] + Vector3(0, 0.3, -0.6)
	m.read_switches()
	m._tick_capture(2.0)
	check(is_equal_approx(float(m.capture.progress), 10.0), "another holds it: on from 8 to 10 (%.1f)" % float(m.capture.progress))
	# Off the yellow circle (still in the room): the count waits.
	hero.global_position = SiegeArena.ALTAR + Vector3(8.0, 0.3, 0)
	m._tick_capture(3.0)
	check(not m.capture.is_empty() and is_equal_approx(float(m.capture.progress), 10.0), "off the circle: no progress")
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m._tick_capture(1.0)
	check(is_equal_approx(float(m.capture.progress), 11.0), "back on: on from 10")
	# Leaving the altar room: no progress (the count is lost, as ever).
	hero.global_position = Vector3(0, 0.3, SiegeArena.GATE_Z[2] + 6.0)
	m._tick_capture(5.0)
	check(m.capture.is_empty() and m.castle_owner == -1, "the leader left the throne room: no progress, the count is gone")
	# The leader falls: no progress either.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m.start_hero_capture()
	m._tick_capture(2.0)
	check(m.capturer() == hero and is_equal_approx(float(m.capture.progress), 2.0), "back up: a new count")
	hero._invulnerable_until = 0
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 1
	hero.take_damage(1.0e9)
	m._tick_capture(5.0)
	check(hero.is_dead() and m.capture.is_empty() and m.castle_owner == -1, "the leader fell: no progress, the count is gone")
	m.hero_respawn_left = 0.0
	m._respawn_hero()
	# The party is sent to a switch.
	var mates := m.hero_party_members()
	if not mates.is_empty():
		var said := m.order_party_switch(0)
		check(m.party_switch == 0 and said.contains("สวิตช์ซ้าย"), "the party is sent to the left switch (%s)" % said)
		m.commanders[0].tactic = GuildWarCommander.PUSH
		m._assign_objectives()
		var alive := mates.filter(func(f): return not f.is_dead())
		check(alive.all(func(f): return f.switch_post == 0 and f.goal_point.distance_to(SiegeArena.SWITCHES[0]) < SiegeArena.SWITCH_RADIUS), "every one of the party is posted in the left circle")
		check(m.order_party_switch(0) != "" and m.party_switch == -1, "pressed again: back to the guild's plan")
		m._assign_objectives()
		check(alive.all(func(f): return f.switch_post != 0 or m.commanders[0]._posts.has(f.get_instance_id())), "the party is released")
	# A switch holder stays in its circle and keeps out of Summon's reach.
	var post := ours[3]
	post.switch_post = 1
	check(not ours[1]._recall_targets().has(post) or ours[1].team != post.team, "a holder is never pulled away by Summon")
	post.switch_post = -1
	# The online status carries the switches; a member's war reads them.
	m.read_switches()
	var codes := m.switch_codes()
	check(codes.size() == 2 and int(codes[0]) == GuildFighter.TEAM_ALLY, "the status codes say who holds each (%s)" % [codes])
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [1, 12.0, true, true], "sw": [1, -2], "ot": false})
	check(m.switch_owner == [GuildFighter.TEAM_ENEMY, -1] and m.switch_contested[1] and bool(m.capture.get("barrier", false)), "a member's war takes the switches and the barrier from the leader's status")
	hud.queue_free()
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


## The AI on its own: theirs storm an undefended castle (ours held at their camp): holders
## to both switches, then the leader up, and the castle is theirs. Then, holding it, theirs
## contest the switches.
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
	# Theirs start inside the throne room's door.
	var k := 0
	for f in m.enemies:
		f.global_position = Vector3(float(k % 6 - 3) * 1.6, 0.3, SiegeArena.GATE_Z[2] - 4.0 - float(k / 6) * 1.6)
		k += 1
	var theirs: GuildWarCommander = m.commanders[1]
	var posted_both := false
	var held_both := false
	var tanks_first := true
	var tactics := {}
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	while m.castle_owner < 0 and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.25, true, false, true).timeout
		m.time_left = GuildWarData.DURATION
		tactics[theirs.tactic] = true
		if (theirs.squads[0] as Array).size() > 0 and (theirs.squads[1] as Array).size() > 0:
			if not posted_both:
				# The first one posted on each switch is the sturdiest there was.
				for s in 2:
					var first: GuildFighter = theirs.squads[s][0]
					if first.role in [GuildWarCommander.ROLE_ASSASSIN, GuildWarCommander.ROLE_BARD] and m.enemies.any(func(f): return f.role == GuildWarCommander.ROLE_TANK and not f.is_leader and not f.is_dead()):
						tanks_first = false
			posted_both = true
		if m.switches_held(GuildFighter.TEAM_ENEMY) == 2:
			held_both = true
	Engine.time_scale = 1.0
	check(posted_both, "ai: theirs post holders on both switches")
	check(tanks_first, "ai: sturdy ones go first (a tank before an assassin or a bard)")
	check(tactics.has(GuildWarCommander.SECURE), "ai: theirs secure the switches before the leader goes up (%s)" % [tactics.keys()])
	check(held_both, "ai: theirs hold both switches")
	check(m.castle_owner == GuildFighter.TEAM_ENEMY, "ai: theirs take the castle on their own (owner %d, capture %s, tactic %s)" % [m.castle_owner, m.capture, theirs.tactic])
	check(theirs.said.any(func(t: String): return t.contains("สวิตช์")), "ai: the plan is called in the war chat (%s)" % [theirs.said])
	# Holding the castle, theirs contest the switches with fighters (not healers first).
	m.set_process(false)
	for f in m.all_fighters():
		f.set_physics_process(false)
	for f in m.enemies:
		if f.is_dead():
			f.respawn()
	theirs.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(theirs.contesting and theirs.tactic == GuildWarCommander.DEFEND, "ai: holding the castle theirs defend and contest (%s)" % theirs.tactic)
	var posted := m.enemies.filter(func(f): return f.switch_post >= 0)
	check((theirs.squads[0] as Array).size() >= 1 and (theirs.squads[1] as Array).size() >= 1 and posted.size() >= 2, "ai: a contester on each switch (%d)" % posted.size())
	check(posted.all(func(f): return f.goal_point.distance_to(SiegeArena.SWITCHES[f.switch_post]) < SiegeArena.SWITCH_RADIUS and not f.is_leader), "ai: the contesters go into the circles, never the leader")
	check(posted.all(func(f): return f.role != GuildWarCommander.ROLE_HEALER) or m.enemies.filter(func(f): return f.role != GuildWarCommander.ROLE_HEALER and not f.is_leader).size() < 2, "ai: damage dealers contest, not healers")
	# Ours storm back: one of ours in a circle with theirs: contested.
	var mine: GuildFighter = m.allies[0]
	var at := int((posted[0] as GuildFighter).switch_post)
	mine.global_position = SiegeArena.SWITCHES[at] + Vector3(0.4, 0.3, 0)
	(posted[0] as GuildFighter).global_position = SiegeArena.SWITCHES[at] + Vector3(-0.4, 0.3, 0)
	m.read_switches()
	check(m.switch_contested[at] and m.switch_owner[at] == -1, "ai: a defender in the circle keeps the attacker from holding it")
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
