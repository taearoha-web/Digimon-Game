extends Node
## The guild war doctrine's second brain (GuildWarDoctrine.smart2: every guild in the
## game's own wars; GuildWarDoctrine.base turns it off for the measurement's baseline,
## tests/tools/guild_war_sim SIM_BASE), headless and seeded:
##   - the deadline: a guild not holding the castle goes all in once the bell is nearer than
##     its capture can still be won (last_call_at), no waiting or besieging past it, the
##     plan adjusted to it (adjust_plan);
##   - the focus: the castle's holder marks the enemy leader near the altar first (and its
##     assassins dive it), anyone leans on the enemy leader in the throne room, whoever
##     strikes our leader taking the altar is peeled off;
##   - the fighters: stuns kept for a priority foe, potions drunk before a fall, a healer
##     healing with nobody to fight;
##   - the trials (GuildWarDoctrine.trial, off in the game): waves, the fallen coming back
##     meeting at a join point to go in together, and those walking up from far behind
##     fighting only what is on them;
##   - the baseline (base) runs none of it.
## godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_smart2_test.tscn
var failures: Array[String] = []
var checks := 0
const D := preload("res://world/guild_war_doctrine.gd")


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
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	Game.new_profile(&"warrior", "GS2")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_pure()
	await _in_war()
	print("GUILD WAR SMART2: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _pure() -> void:
	check(D.adjust_plan("regroup", 150.0, false, true) == "regroup", "150 s left: the old last call (120 s) has not come, the guild may regroup")
	check(D.adjust_plan("regroup", 150.0, false, true, 200.0) == "rush", "with its deadline at 200 s it no longer regroups: all in on the gates")
	check(D.adjust_plan("hold", 150.0, false, false, 200.0) == "storm", "and with the gates down it storms")
	var r := {"balance": 0.4, "foe_spent": 0.1, "alive_share": 1.0, "coming": 0.4, "foe_near": 6, "gathered": 0.3,
		"holding": false, "enemy_capturing": false, "we_capturing": false, "time_left": 150.0}
	check(D.pick_window(false, false, 0.0, 100.0, r)[1], "outweighed with its own on the way, 150 s left: the old brain waits for the wave")
	r["last_at"] = 200.0
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "past its deadline (200 s) it does not wait")
	var siege := {"owner": 1, "holding": false, "gates_up": false, "teams": 2, "time_left": 150.0, "last_at": 200.0}
	check(not D.pick_besiege(false, 0.0, siege, {"loss": 9.0, "kill": 1.0}, false), "nor besiege a holder past it")
	siege["last_at"] = 120.0
	check(D.pick_besiege(false, 0.0, siege, {"loss": 9.0, "kill": 1.0}, false), "(with 150 s left and the old deadline it would)")


func _roster(roll: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	var info := GuildWarSpectate.demo_war(rng, GuildWarData.GUILD_SIDE, ["Alpha", "Neverdie"], [1, 2])
	info["guilds"] = false
	(info.sides[0].lineup as Array).resize(GuildWarData.GUILD_SIDE - 1)
	info["owner"] = -1
	return info


func _in_war() -> void:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(4242, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {})
	Game.guildwar_resuming = true
	GuildWarMatch.next_roster = _roster(4242)
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null, "a war of two")
	if m == null:
		return
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	await _frames(6)
	zone.hero.global_position = GuildWarMatch.hero_camp()
	zone.hero.set_physics_process(false)
	check(m.state == "fight", "the fight begins")
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
	m.set_process(false)
	var d0: GuildWarDoctrine = m.doctrines[0]
	var d1: GuildWarDoctrine = m.doctrines[1]
	var c1: GuildWarCommander = m.commanders[1]
	check(d0.smart2() and d1.smart2() and c1.smart2(), "every guild of the game's own war plays the second brain")
	m._assign_objectives()
	check(m.all_fighters().all(func(f): return f.smart2), "and so do its fighters")
	var lead0 := m.ai_leader(0)
	var lead1 := m.ai_leader(1)
	# The deadline: from its camp the walk and the fight need more than the old 120 s.
	for f in m.all_fighters():
		f.global_position = f.spawn_point
	var at := d1.last_call_at()
	check(at > D.LAST_CALL and at >= GuildWarMatch.CAPTURE_TIME + D.DEADLINE_FIGHT + 150.0 / D.DEADLINE_PACE, "its leader at its camp: the last call comes at %.0f s, not %d" % [at, int(D.LAST_CALL)])
	m.time_left = at - 1.0
	d1.think()
	check(d1.last_call and bool(c1.hints.get("all_in", false)), "past the deadline the guild goes all in (%.0f s left)" % m.time_left)
	m.time_left = GuildWarData.DURATION
	d1.think()
	check(not d1.last_call, "with the war young it does not")
	# The castle held by team 1, every gate down: the holder marks the enemy leader.
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m.castle_owner = 1
	check(is_equal_approx(d1.last_call_at(), D.LAST_CALL), "the holder's last call is the old one")
	var normal0: GuildFighter = null
	for f in m.allies:
		if f != lead0 and not f.is_healer() and not f.sings():
			normal0 = f
			break
	lead0.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 12.0)
	normal0.global_position = SiegeArena.ALTAR + Vector3(3.0, 0.3, 12.0)
	check(d1.focus_extra(lead0) >= D.INTERCEPT_BONUS, "the holder wants the enemy leader near the altar above all (+%.0f)" % d1.focus_extra(lead0))
	check(d1.focus_extra(normal0) < D.INTERCEPT_BONUS, "not its members (+%.0f)" % d1.focus_extra(normal0))
	check(d1.dive_override() == lead0, "the holder's assassins dive the enemy leader by the altar")
	c1.think(GuildWarCommander.THINK_EVERY)
	check(c1.dive == lead0, "and the commander marks it for them")
	d1.base = true
	check(d1.focus_extra(lead0) < D.INTERCEPT_BONUS and d1.dive_override() == null and not c1.smart2(), "the baseline doctrine has none of it")
	d1.base = false
	# Peel: whoever strikes our leader taking the altar.
	m.castle_owner = -1
	lead1.capture_role = true
	normal0.global_position = lead1.global_position + Vector3(2.0, 0, 0)
	normal0._victim = lead1
	check(d1.focus_extra(normal0) >= D.PEEL_BONUS, "the one on our leader at the altar is peeled off it (+%.0f)" % d1.focus_extra(normal0))
	normal0._victim = null
	lead1.capture_role = false
	_fighter_rules(m, lead0, lead1)
	_waves(m, d1, c1, lead1)
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _fighter_rules(m: GuildWarMatch, lead0: GuildFighter, lead1: GuildFighter) -> void:
	var a: GuildFighter = null
	var priest: GuildFighter = null
	for f in m.enemies:
		if f == lead1:
			continue
		if f.is_healer() and priest == null:
			priest = f
		elif a == null and not f.is_healer() and f.fighter_class() != &"assassin":
			a = f
	var e: GuildFighter = null
	for f in m.allies:
		if f != lead0 and f.fighter_class() != &"assassin" and not f.is_healer():
			e = f
			break
	# Everybody else in their camps (nobody chases there).
	for f in m.all_fighters():
		f.global_position = f.spawn_point
	# Stuns: kept for a priority foe within reach.
	a.global_position = Vector3(0, 0.3, 20.0)
	e.global_position = Vector3(3.0, 0.3, 20.0)
	lead0.global_position = Vector3(6.0, 0.3, 22.0)
	check(not a._stun_worth(e), "with the enemy leader near, a stun is not spent on one of its members")
	check(a._stun_worth(lead0), "it goes on the leader")
	lead0.global_position = lead0.spawn_point
	check(a._stun_worth(e), "with no priority foe near anyone is worth it")
	# Potions: every AI player drinks once under half HP, not above it.
	a.hp = int(a.max_hp * 0.6)
	a._potions = 3
	a._potion_cd = 0.0
	a._try_potion()
	check(a._potions == 3, "at 60%% HP no potion yet")
	a.hp = int(a.max_hp * 0.48)
	a._try_potion()
	check(a._potions == 2, "under half HP it drinks")
	a.smart2 = false
	a.hp = int(a.max_hp * 0.48)
	a._potion_cd = 0.0
	a._try_potion()
	check(a._potions == 1, "the baseline drinks under half too")
	a.smart2 = true
	a.hp = a.max_hp
	# A healer heals with nobody to fight.
	if priest != null:
		priest.global_position = Vector3(0, 0.3, 30.0)
		a.global_position = Vector3(2.0, 0.3, 30.0)
		priest._victim = null
		priest.mp = float(priest.rstats.max_mp)
		priest.cooldowns.clear()
		priest._cast_until = 0
		priest._think = 0.0
		a.hp = a.max_hp
		GuildFighter.forget_view()
		check(not priest._support_idle(1.0), "nobody hurt: the healer waits")
		a.hp = int(a.max_hp * 0.3)
		priest._think = 0.0
		GuildFighter.forget_view()
		check(priest._support_idle(1.0), "an ally at 30%% beside it: it heals with nobody to fight")
		a.hp = a.max_hp


func _waves(m: GuildWarMatch, d1: GuildWarDoctrine, c1: GuildWarCommander, lead1: GuildFighter) -> void:
	for f in m.all_fighters():
		f.global_position = f.spawn_point
		f._retreating = false
		f.hp = f.max_hp
	m.capture = {}
	m.castle_owner = -1
	d1.last_call = false
	# The trial rules (off in the game: GuildWarDoctrine.trial).
	D.trial["waves"] = true
	D.trial["walkers"] = true
	c1.tactic = GuildWarCommander.ESCORT
	var front := SiegeArena.ALTAR
	d1.field["front"] = front
	var walkers: Array[GuildFighter] = []
	for f in m.enemies:
		if f != lead1 and walkers.size() < 5:
			walkers.append(f)
	# The other guild's front at the altar (four of its own there).
	var k := 0
	for f in m.allies:
		if k < 4:
			f.global_position = SiegeArena.ALTAR + Vector3(float(k) * 1.5, 0.3, 4.0)
			k += 1
	# Five on their way back, out of the camp, nobody of theirs at the altar: a trickle.
	for i in walkers.size():
		walkers[i].global_position = Vector3(float(i) * 2.0, 0.3, -40.0)
	var side: Array[GuildFighter] = m.side(1)
	d1._waves(side, lead1, front)
	var join := d1.join_at
	check(join.is_finite(), "the other guild holds the altar: the ones coming back meet at a join point (%s)" % str(join.round()))
	check(walkers.all(func(f): return f.goal_point.distance_to(join) < D.JOIN_RADIUS), "every one of them goes to it, not on alone")
	var sent := d1.waves_sent
	for i in D.WAVE_N:
		walkers[i].global_position = join + Vector3(float(i), 0.3, 0)
	d1._waves(side, lead1, front)
	check(d1.waves_sent == sent + 1, "with %d of them there the wave goes in" % D.WAVE_N)
	c1.apply()
	# (The wave's damage dealers; a healer of the wave keeps to its mates behind them, and
	# which roster player stands first depends on the seeded line-up.)
	var dealer: GuildFighter = null
	for i in D.WAVE_N:
		if not walkers[i].is_healer():
			dealer = walkers[i]
			break
	check(dealer != null and dealer.goal_point.distance_to(join) > D.JOIN_RADIUS, "those sent go on to the front (%s)" % (str(dealer.member.get("class")) if dealer else "-"))
	check(walkers[4].goal_point.distance_to(join) < D.JOIN_RADIUS, "the one still on its way waits for the next wave")
	# Walking up from far behind: it fights only what is on it.
	walkers[4].hold_range = 0.0
	walkers[4].keep_back = false
	d1._walkers(side, front)
	check(is_equal_approx(walkers[4].hold_range, D.WALK_HOLD), "one walking up from far behind turns only on what is on it (%.0f m)" % walkers[4].hold_range)
	walkers[0].hold_range = 0.0
	walkers[0].global_position = front + Vector3(4.0, 0.3, 10.0)
	d1._walkers(side, front)
	check(walkers[0].hold_range == 0.0, "at the front it fights as before")
	d1.base = true
	walkers[4].goal_point = Vector3.ZERO
	c1.apply()
	check(walkers[4].goal_point.distance_to(join) > D.JOIN_RADIUS, "the baseline sends everyone on alone")
	d1.base = false
	D.trial.clear()
	walkers[4].goal_point = Vector3.ZERO
	c1.apply()
	check(walkers[4].goal_point.distance_to(join) > D.JOIN_RADIUS, "off in the game: the trial is not played")
