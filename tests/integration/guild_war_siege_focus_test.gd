extends Node
## A league war of four with a castle holder: every other guild goes for the castle and the
## holder, not for each other (GuildWarMatch.siege_focus, GuildFighter.holder_team):
##   - the attackers rush the gates (no holding back at the bridge foot), the holder guards them;
##   - an attacker picks the holder's fighters, leaves another attacking guild's alone (but
##     for one that goes for it close by), and its area blows pass over them;
##   - its guild's called target and assassins' mark are the holder's;
##   - the holder's guards at the third gate are not sheltered by the keep behind them;
##   - the leader's "wait while two others clash" at the altar is short and bounded;
##   - in the throne room with every gate down the attackers are rivals again;
##   - a seeded AI-only war (the gates standing, the holder in the keep, 4x): the attackers
##     are at the front gates within REACH_BOUND s, most of their blows before the gates fall
##     land on the holder, and the first two tiers open within the run.
## SIM_SEEDS / SIM_SECONDS to measure longer (see guild_war_4way_test for the full numbers).
##   godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_siege_focus_test.tscn
var failures := 0
var checks := 0
const HOLDER := 2
const SPEED := 4.0
const SEED := 77
const RUN_SECONDS := 300.0
const REACH_BOUND := 30.0
const HOLDER_SHARE := 0.7


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
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
	await _rules()
	await _seeded_war()
	print("GUILD WAR SIEGE FOCUS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero() -> void:
	Game.new_profile(&"warrior", "Siege QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.current_zone = &"guildwar"


## A war of four, guild `owner` holding the castle from the keep, the gates standing.
func _start(war_seed: int, owner: int) -> Zone:
	seed(war_seed)
	_hero()
	Game.guildwar_save_checkpoint(war_seed, GuildWarData.DURATION, false, [0, 0, 0, 0], 0, 0, 0, {"gates": [1000, 1000, 1000, 1000, 1000], "owner": owner, "teams": 4})
	Game.guildwar_resuming = true
	var rng := RandomNumberGenerator.new()
	rng.seed = war_seed
	var info := GuildWarSpectate.demo_war(rng, GuildWarData.GUILD_SIDE)
	info["guilds"] = false
	(info.sides[0].lineup as Array).resize(GuildWarData.GUILD_SIDE - 1)
	info["owner"] = owner
	GuildWarMatch.next_roster = info
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	return zone


func _drop(zone: Zone) -> void:
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _fight(m: GuildWarMatch) -> void:
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	while m.state != "fight":
		await get_tree().process_frame
	await get_tree().physics_frame
	m.hero.global_position = GuildWarMatch.hero_camp()
	m.hero.set_physics_process(false)
	for f in m.allies:
		if f.in_hero_party():
			f.party = GuildWarMatch.HERO_PARTY + 1


## Holds `f` still at `at` (no physics, no spawn guard), up and at full HP.
func _pin(f: GuildFighter, at: Vector3) -> void:
	f.set_physics_process(false)
	f.global_position = at
	f._guard_until = 0
	f._victim = null
	f._last_attacker = null
	f._grudge = 0.0
	f._retreating = false


## No orders on `f` (no post, no hold, no called target): its own pick alone.
func _free(f: GuildFighter) -> void:
	f.capture_role = false
	f.keep_back = false
	f.switch_post = false
	f.hold_range = 0.0
	f.objective = null
	f.focus = null
	f.dive = null
	f.guard_node = null


# ---------------------------------------------------------------------------
# The rules, one by one
# ---------------------------------------------------------------------------

func _rules() -> void:
	var zone := _start(SEED, HOLDER)
	var m: GuildWarMatch = zone.gw_match
	await _fight(m)
	check(m.castle_owner == HOLDER and m.siege_focus(), "a holder in the castle: the siege's focus is on")
	for c in m.commanders:
		c.think(GuildWarCommander.THINK_EVERY)
	m._make_plans()
	m._assign_objectives()
	for t in 4:
		if t == HOLDER:
			check(m.plans[t] == "gates", "the holder guards its gates (%s)" % m.plans[t])
			check(m.side(t).all(func(f): return f.holder_team == -1), "the holder's own fighters fight anyone")
		else:
			check(m.plans[t] == "rush", "guild %d rushes the gates, no holding back at the bridge foot (%s)" % [t, m.plans[t]])
			check(m.side(t).all(func(f): return f.holder_team == HOLDER), "guild %d's fighters are set on the holder" % t)
	# Three fighters held still on the bridge: an attacker, another guild's, the holder's.
	var a: GuildFighter = m.side(1)[6]
	var r: GuildFighter = m.side(3)[6]
	var h: GuildFighter = m.side(HOLDER)[6]
	var spot := Vector3(0, 0.3, -9.0)
	_pin(a, spot)
	_pin(r, spot + Vector3(4.0, 0, 0))
	_pin(h, spot + Vector3(-9.0, 0, 0))
	# Everyone else far off (out of every pick's reach).
	for f in m.all_fighters():
		if f != a and f != r and f != h:
			f.set_physics_process(false)
			f.global_position = SiegeArena.camp(f.team) + Vector3(0, 0.3, 0)
	await get_tree().physics_frame
	_free(a)
	GuildFighter.forget_view()
	check(a._nearest_victim() == h, "an attacker picks the holder's fighter over another attacker nearer by")
	h.global_position = spot + Vector3(-40.0, 0, 0)
	GuildFighter.forget_view()
	check(a._nearest_victim() != r, "it leaves another attacking guild's fighter alone")
	r._victim = a
	GuildFighter.forget_view()
	check(a._nearest_victim() == r, "but fights back the one that goes for it close by")
	r.global_position = spot + Vector3(14.0, 0, 0)
	GuildFighter.forget_view()
	check(a._nearest_victim() != r, "and not one that goes for it from afar")
	r.global_position = spot + Vector3(4.0, 0, 0)
	r._victim = null
	h.global_position = spot + Vector3(-5.0, 0, 0)
	a._victim = h
	GuildFighter.forget_view()
	var hit := a._targets()
	check(hit.has(h) and not hit.has(r), "its area blows pass over another attacker round it")
	check(not hit.has(m.hero), "and over the hero's guild, another attacker")
	a._victim = r
	check(a._targets().has(r), "but for the one it fights")
	a._victim = null
	# The guild's called target and the assassins' mark: the holder's.
	var c1: GuildWarCommander = m.commanders[1]
	var mark := c1._pick_focus()
	check(mark == null or m.team_of(mark) == HOLDER, "the guild calls a target of the holder's (%s)" % (m.team_name(m.team_of(mark)) if mark != null else "none"))
	var dive := c1._pick_dive()
	check(dive == null or m.team_of(dive) == HOLDER, "its assassins dive on the holder's")
	# The keep shelters the holder's coming back and its hurt, not its guards at the third gate.
	h.global_position = SiegeArena.KEEP_CAMP + Vector3(0, 0.3, -2.5)
	check(not a._in_own_camp(h), "a holder's guard standing by the keep is fair game while a gate stands")
	h._retreating = true
	check(a._in_own_camp(h), "one falling back hurt into the keep is sheltered")
	h._retreating = false
	h._guard_until = GameClock.msec() + 2000
	check(a._in_own_camp(h), "and one just back from a fall")
	h._guard_until = 0
	# The rally before a gate inside the castle is out of the holder's reach.
	for g in m.gates_of_tier(0):
		g.set_broken_quietly()
	m._update_breakable()
	c1._place()
	check(c1.rally.z > SiegeArena.GATE_Z[1] + GuildWarCommander.SIEGE_RALLY - 1.0, "the rally before the second tier is out in the yard (%.0f)" % c1.rally.z)
	# The leader's wait at the altar while two others clash: at most TIMING_MAX at a time.
	c1.clash = {"0|3": 6.0}
	var s := {"leader_on_altar": false, "rivals": 3, "rival_leaders_down": 0, "altar_foes": 6, "vanguard": 0}
	c1.waiting = false
	c1._wait_since = -1.0e9
	check(c1.leader_timing(s) == "wait", "with two others clashing round the altar the leader may wait")
	c1.waiting = true
	c1._wait_since = c1.clock
	c1.clock += GuildWarCommander.TIMING_MAX + 0.1
	check(c1.leader_timing(s) != "wait", "for at most %d s" % int(GuildWarCommander.TIMING_MAX))
	c1.waiting = false
	c1.clock += 1.0
	check(c1.leader_timing(s) != "wait", "and does not start waiting again at once")
	check(GuildWarCommander.TIMING_MAX + GuildWarCommander.TIMING_REST >= 20.0 and GuildWarCommander.TIMING_MAX <= 20.0, "a wait is bounded (%d s, then %d s without)" % [int(GuildWarCommander.TIMING_MAX), int(GuildWarCommander.TIMING_REST)])
	# Every gate down: in the throne room the attackers are rivals again.
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m._assign_objectives()
	var room := SiegeArena.SWITCH + Vector3(4.0, 0.3, 0)
	a.global_position = room
	r.global_position = room + Vector3(3.0, 0, 0)
	h.global_position = room + Vector3(-30.0, 0, 0)
	_free(a)
	r._victim = null
	a._last_attacker = null
	GuildFighter.forget_view()
	check(a.rivalry_open and a._nearest_victim() == r, "every gate down, in the throne room another attacker is a foe again")
	r.global_position = Vector3(4.0, 0.3, SiegeArena.GATE_Z[1] + 10.0)
	a.global_position = r.global_position + Vector3(3.0, 0, 0)
	GuildFighter.forget_view()
	check(a._nearest_victim() != r, "but not out in the yards on the way in")
	await _drop(zone)


# ---------------------------------------------------------------------------
# A seeded war
# ---------------------------------------------------------------------------

func _seeded_war() -> void:
	var war_seed := int(OS.get_environment("SIM_SEEDS")) if OS.get_environment("SIM_SEEDS") != "" else SEED
	var seconds := float(OS.get_environment("SIM_SECONDS")) if OS.get_environment("SIM_SECONDS") != "" else RUN_SECONDS
	var zone := _start(war_seed, HOLDER)
	var m: GuildWarMatch = zone.gw_match
	await _fight(m)
	m.blows = PackedInt32Array()
	var kills := {"holder": 0, "rival": 0}
	var on_fell := func(victim: GuildFighter, killer: Node) -> void:
		if killer is GuildFighter and m.front_gate() != null and (killer as GuildFighter).team != m.castle_owner and victim.team != (killer as GuildFighter).team:
			kills["holder" if victim.team == m.castle_owner else "rival"] += 1
	for f in m.all_fighters():
		f.fell.connect(on_fell)
	var clock := 0.0
	var reach := -1.0
	var opened: Array[float] = [-1.0, -1.0, -1.0]
	var pre := PackedInt32Array()
	Engine.time_scale = SPEED
	var t0 := Time.get_ticks_msec()
	while clock < seconds and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		m.time_left = GuildWarData.DURATION
		if reach < 0.0:
			for t in 4:
				if t != HOLDER and m.side(t).any(func(f): return not f.is_dead() and f.global_position.z < SiegeArena.GATE_Z[0] + 9.0):
					reach = clock
		for k in 3:
			if opened[k] < 0.0 and m.tier_open(k):
				opened[k] = clock
		if m.front_gate() != null:
			pre = m.blows.duplicate()
		if opened[1] >= 0.0 and clock > opened[1] + 5.0 and OS.get_environment("SIM_SECONDS") == "":
			break
	Engine.time_scale = 1.0
	pre.resize(16)
	var on_holder := 0
	var on_rivals := 0
	for att in 4:
		if att == HOLDER:
			continue
		for v in 4:
			if v == att:
				continue
			if v == HOLDER:
				on_holder += pre[att * 4 + v]
			else:
				on_rivals += pre[att * 4 + v]
	var share := float(on_holder) / float(maxi(1, on_holder + on_rivals))
	print("SIEGE seed %d (%.0f s, wall %.0f s): at the gates %.0f s, tiers open %s, attacker blows on the holder %d / on each other %d (%.0f%%), falls dealt holder %d / each other %d" % [war_seed, clock, (Time.get_ticks_msec() - t0) / 1000.0, reach, opened, on_holder, on_rivals, share * 100.0, kills.holder, kills.rival])
	check(reach >= 0.0 and reach <= REACH_BOUND, "the attackers are at the front gates within %.0f s (%.0f s)" % [REACH_BOUND, reach])
	check(on_holder > 0 and share >= HOLDER_SHARE, "before the gates fall at least %.0f%% of the attackers' blows land on the holder (%.0f%%)" % [HOLDER_SHARE * 100.0, share * 100.0])
	check(int(kills.holder) > 2 * int(kills.rival), "they fell the holder's far more than each other (%d / %d)" % [kills.holder, kills.rival])
	check(opened[0] >= 0.0 and opened[1] >= 0.0, "the first two tiers fall within %.0f s of a seeded war (%s)" % [seconds, opened])
	await _drop(zone)
