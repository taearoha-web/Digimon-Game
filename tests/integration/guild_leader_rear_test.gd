extends Node
## The guild leaders come with their guild in the castle assault, right behind its front
## (GuildWarCommander: หัวกิลบุกพร้อมทัพ - the damage dealers and tanks push in first and
## clear the throne room, the leader follows right behind them, never waiting at the camp
## while its guild fights, and goes onto the altar once the way is clear; a leader swarmed
## steps back behind its own; the guild holding the castle keeps its leader by the altar
## behind its defenders). Headless, seeded: two AI-led guilds (ours led by a picked
## member, the hero held still in its camp) fight for the throne room with every gate
## down; the leader's distance to the altar is sampled against its guild's members (behind
## its front: at least two of them nearer; within reach of it: at most FRONT_REACH m
## farther than the nearest; not at the camp), leader falls and its going up are counted.
## The war runs at SPEED (SIM_SPEED=1 for real speed). SIM_SEEDS="4242,77,9001" SIM_OWNER=-1 SIM_SECONDS=420
## for a longer measurement (every seed with every owner given; defaults: SETUPS, 90 s of
## war each), SIM_SPEED=4 to run it faster, SIM_TRACE=1 (2: every sample of the assault).
## godot --headless --path . res://tests/integration/guild_leader_rear_test.tscn
var failures: Array[String] = []
var checks := 0

## [seed, castle owner] of each war: nobody holding it twice, the rival holding it once.
const SETUPS := [[4242, -1], [4242, 1], [2024, -1]]
## War seconds (the clock once counted Engine.time_scale twice: its "360" were 90).
const SECONDS := 90.0
## War seconds between two samples.
const SAMPLE_EVERY := 0.25
## Engine.time_scale of the war (SIM_SPEED). The fighters' cast, swing and animation locks
## run on GameClock (game time), so a faster war is the same fight as real speed (on the
## wall clock, at 4x, the leaders looked behind on one machine and not on another);
## measured three at a time, the escort share at 1x 77-84%, at 4x 68-83%.
const SPEED := 2.0
## The leader within reach of its front: at most this many metres farther from where its
## guild pushes than the member nearest it.
const FRONT_REACH := 15.0
## The leader this far from its post is on its way back to it (from its camp after a fall
## or a heal): those samples are counted apart.
const RETURNING := 30.0


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
	Game.new_profile(&"warrior", "GLR")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	var setups: Array = SETUPS
	var env_seeds := OS.get_environment("SIM_SEEDS")
	var owner_env := OS.get_environment("SIM_OWNER")
	if env_seeds != "" or owner_env != "":
		var seeds: Array = Array(env_seeds.split(",")).map(func(x): return int(x)) if env_seeds != "" else [4242]
		var owners: Array = [-1, 1] if owner_env == "" else [int(owner_env)]
		setups = []
		for sd in seeds:
			for owner in owners:
				setups.append([sd, owner])
	var seconds := SECONDS
	if OS.get_environment("SIM_SECONDS") != "":
		seconds = float(OS.get_environment("SIM_SECONDS"))
	var all: Array = []
	for setup in setups:
		all.append(await _war(int(setup[0]), int(setup[1]), seconds))
	_judge(all)
	print("GUILD LEADER REAR: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## One war from `seed` with every gate down and `owner` holding the castle (-1 nobody),
## for `seconds` of war time or until the castle changes hands.
func _war(seed: int, owner: int, seconds: float) -> Dictionary:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(seed, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": owner})
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	var out := {"seed": seed, "owner": owner}
	if m == null:
		check(false, "seed %d: no match" % seed)
		return out
	var hero: Hero = zone.hero
	# Ours led by a member (the toughest), so both guilds run an AI leader.
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	await _frames(6)
	hero.global_position = GuildWarMatch.hero_camp()
	hero.set_physics_process(false)
	# The hero sits this one out: its party fights as the rest of the guild does (not
	# called back to the hero in its camp).
	for f in m.allies:
		if f.in_hero_party():
			f.party = GuildWarMatch.HERO_PARTY + 1
	if owner == GuildFighter.TEAM_ENEMY:
		# Theirs hold the castle round the altar; ours come in from the last yard.
		var k := 0
		for f in m.enemies:
			f.global_position = SiegeArena.ALTAR + Vector3(cos(TAU * k / 8.0) * 7.0, 0.3, sin(TAU * k / 8.0) * 5.0)
			k += 1
		k = 0
		for f in m.allies:
			f.global_position = Vector3(float(k % 4 - 2) * 2.0, 0.3, SiegeArena.GATE_Z[2] + 12.0 + float(k / 4) * 2.0)
			k += 1
	var leads: Array = [m.ally_leader, m.enemy_leader]
	var lead_deaths := [0, 0]
	var first_lead_death := [-1.0, -1.0]
	# Members of the guild fallen before its leader first fell.
	var before_lead := [0, 0]
	var member_deaths := [0, 0]
	var behind := [0, 0]
	var near := [0, 0]
	var at_camp := [0, 0]
	var returning := [0, 0]
	var went_up := [false, false]
	var samples := [0, 0]
	var by_phase := {}
	var capture_at := -1.0
	var captured_by := -1
	var seen_deaths := {}
	var clock := 0.0
	var sample_left := 0.0
	var start_owner := m.castle_owner
	var t0 := Time.get_ticks_msec()
	var speed := SPEED
	if OS.get_environment("SIM_SPEED") != "":
		speed = float(OS.get_environment("SIM_SPEED"))
	Engine.time_scale = speed
	while clock < seconds and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().physics_frame
		# The physics step already counts Engine.time_scale: war seconds.
		var dt := get_physics_process_delta_time()
		clock += dt
		m.time_left = GuildWarData.DURATION
		for team in 2:
			var side: Array[GuildFighter] = m.allies if team == 0 else m.enemies
			for f in side:
				var id := f.get_instance_id()
				if f.deaths > int(seen_deaths.get(id, 0)):
					seen_deaths[id] = f.deaths
					if f == leads[team]:
						lead_deaths[team] += 1
						if first_lead_death[team] < 0.0:
							first_lead_death[team] = clock
					else:
						member_deaths[team] += 1
						if first_lead_death[team] < 0.0:
							before_lead[team] += 1
		if m.castle_owner != start_owner and capture_at < 0.0:
			capture_at = clock
			captured_by = m.castle_owner
			break
		sample_left -= dt
		if sample_left > 0.0:
			continue
		sample_left = SAMPLE_EVERY
		if OS.get_environment("SIM_TRACE") != "" and int(clock * 2.0) % 40 == 0:
			var secs := []
			for team in 2:
				var side: Array[GuildFighter] = m.allies if team == 0 else m.enemies
				secs.append(side.map(func(f): return -1 if f.is_dead() else SiegeArena.section(f.global_position)))
			for L in leads:
				if not L.is_dead():
					print("  lead t%d goal %s keep %s cap %s hold %.0f victim %s vel %.1f c.read van %s foes %s esc %s go %s" % [L.team, L.goal_point.round(), L.keep_back, L.capture_role, L.hold_range, (L._victim.global_position.round() if L._victim != null and is_instance_valid(L._victim) else "-"), L.velocity.length(), m.commanders[L.team].last_read.get("vanguard"), m.commanders[L.team].last_read.get("altar_foes"), m.commanders[L.team].last_read.get("escort"), m.commanders[L.team].leader_go])
			print("t %.0f state %s plans %s tactics %s/%s sections %s capture %s leads %s %s" % [clock, m.state, m.plans, m.commanders[0].tactic, m.commanders[1].tactic, secs, m.capture, leads[0].global_position.round() if not leads[0].is_dead() else "dead", leads[1].global_position.round() if not leads[1].is_dead() else "dead"])
		# The attackers' leader, not yet sent onto the altar, against its guild out there
		# (not falling back) on the way to where it pushes (the gate, the altar).
		for team in 2:
			if m.castle_owner == team:
				continue
			var lead: GuildFighter = leads[team]
			var c: GuildWarCommander = m.commanders[team]
			# Sent up (leader_go): the guild cleared the way and the leader now walks onto
			# the altar on purpose, so it is no longer "not yet sent".
			if lead.capture_role or lead.capturing or c.leader_go:
				went_up[team] = true
			if lead.is_dead() or lead.is_retreating() or lead.capture_role or lead.capturing or c.leader_go:
				continue
			var goal := Vector3.INF
			var gate := m.front_gate()
			if gate != null and c.tactic == GuildWarCommander.PUSH:
				goal = SiegeArena.gate_front(gate.tier, gate.lane)
			elif gate == null and c.tactic in [GuildWarCommander.ESCORT, GuildWarCommander.GUARD, GuildWarCommander.GATHER]:
				goal = SiegeArena.ALTAR
			if not goal.is_finite():
				continue
			var dists: Array[float] = []
			var side: Array[GuildFighter] = m.allies if team == 0 else m.enemies
			for f in side:
				if f == lead or f.is_dead() or f.is_retreating() or c._in_camp(f):
					continue
				dists.append(_flat(f.global_position, goal))
			if dists.size() < 3:
				continue
			dists.sort()
			var lead_d := _flat(lead.global_position, goal)
			var post := c.leader_post
			# Sent to its camp by its commander: idling there (never while its guild is out).
			if c._in_camp(lead) and (not post.is_finite() or _flat(post, SiegeArena.camp(team)) < SiegeArena.CAMP_RADIUS):
				at_camp[team] += 1
			# On its way back to its post from afar (after a fall or a heal at its camp):
			# counted apart.
			if post.is_finite() and _flat(lead.global_position, post) > RETURNING:
				returning[team] += 1
				continue
			samples[team] += 1
			var key := c.tactic
			var row: Array = by_phase.get(key, [0, 0, 0])
			row[2] += 1
			# Behind its front: at least two of its guild as near the goal or nearer (a
			# metre's slack).
			var is_behind := lead_d >= dists[1] - 1.0
			# Within reach of the front: not more than FRONT_REACH farther than its front
			# line (the second of its guild nearest the goal).
			var is_near := lead_d - dists[1] <= FRONT_REACH
			if is_behind:
				behind[team] += 1
				row[0] += 1
			if is_near:
				near[team] += 1
				row[1] += 1
			if OS.get_environment("SIM_TRACE") == "2" and key == GuildWarCommander.ESCORT:
				print("  ESC t%d %s%s lead %.1f post %s cover %s hp %.2f | %s" % [team, "B" if is_behind else "A", "N" if is_near else "F", lead_d, (str(snappedf(_flat(c.leader_post, goal), 0.1)) if c.leader_post.is_finite() else "INF"), c.leader_covering, lead.hp_ratio(), dists.map(func(x): return snappedf(x, 0.1))])
			by_phase[key] = row
	Engine.time_scale = 1.0
	out.merge({"clock": clock, "lead_deaths": lead_deaths, "first_lead_death": first_lead_death, "before_lead": before_lead,
		"member_deaths": member_deaths, "behind": behind, "near": near, "at_camp": at_camp, "returning": returning, "went_up": went_up, "samples": samples, "capture_at": capture_at, "captured_by": captured_by, "by_phase": by_phase})
	print("SIM seed %d owner %d: capture %.0f s by %d | leader falls %s first at %s (members down before it %s, members down %s) | leader behind its front %s, within %.0f m of it %s of %s samples, at the camp %s, on its way back %s, went up %s | by tactic [behind, near, samples] %s" % [
		seed, owner, capture_at, captured_by, lead_deaths, first_lead_death, before_lead, member_deaths, behind, FRONT_REACH, near, samples, at_camp, returning, went_up, by_phase])
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	return out


func _judge(all: Array) -> void:
	var behind := 0
	var near := 0
	var at_camp := 0
	var returning := 0
	var went_up := 0
	var samples := 0
	var falls := 0
	var member_falls := 0
	var first_sum := 0.0
	var leads := 0
	var captures := []
	var phases := {}
	for r in all:
		for key in r.by_phase:
			var row: Array = phases.get(key, [0, 0, 0])
			for i in 3:
				row[i] += int(r.by_phase[key][i])
			phases[key] = row
		for team in 2:
			behind += int(r.behind[team])
			near += int(r.near[team])
			at_camp += int(r.at_camp[team])
			returning += int(r.returning[team])
			went_up += 1 if bool(r.went_up[team]) else 0
			samples += int(r.samples[team])
			falls += int(r.lead_deaths[team])
			member_falls += int(r.member_deaths[team])
			# A leader that never fell counts the whole war.
			first_sum += float(r.first_lead_death[team]) if float(r.first_lead_death[team]) >= 0.0 else float(r.clock)
			leads += 1
		captures.append(snappedf(float(r.capture_at), 1.0))
	var share := float(behind) / float(maxi(1, samples))
	var near_share := float(near) / float(maxi(1, samples))
	print("SIM total: leader behind its front %d, within %.0f m of it %d of %d samples (%.0f%% / %.0f%%), at the camp %d, on its way back %d | leaders went up %d | leader falls %d, member falls %d (leaders %.0f%% of falls) | mean first leader fall %.0f s | captures %s | by tactic [behind, near, samples] %s" % [
		behind, FRONT_REACH, near, samples, share * 100.0, near_share * 100.0, at_camp, returning, went_up, falls, member_falls, 100.0 * float(falls) / float(maxi(1, falls + member_falls)), first_sum / float(maxi(1, leads)), captures, phases])
	# The checks (the run is seeded, but the fight's timing is not exact to the frame, so
	# the bars leave room): the leader behind its front yet close to it, never at the
	# camp while its guild assaults, going up to the altar, falling less often than its
	# members.
	var escort: Array = phases.get(GuildWarCommander.ESCORT, [0, 0, 0])
	check(samples >= 200, "the leaders were seen in the assault (%d samples)" % samples)
	check(share >= 0.6, "the attacking leader comes behind its front, the damage dealers lead (%.0f%% of the time)" % (share * 100.0))
	check(near_share >= 0.7, "the attacking leader is within %.0f m of its front, not left at the back (%.0f%% of the time)" % [FRONT_REACH, near_share * 100.0])
	check(at_camp * 50 <= samples, "the leader is not kept at the camp while its guild assaults (%d samples, against %d)" % [at_camp, samples])
	check(returning * 3 <= samples, "the leader is mostly at its post, not on its way back (%d against %d)" % [returning, samples])
	check(int(escort[2]) >= 50, "the assault on the altar was seen long enough (%d samples)" % int(escort[2]))
	check(float(escort[0]) >= float(escort[2]) * 0.55 and float(escort[1]) >= float(escort[2]) * 0.7, "in the assault on the altar the members go in first and the leader follows right behind (%s)" % [escort])
	check(went_up >= 1, "a leader goes up to the altar once the way is clear (%d)" % went_up)
	check(falls * 3 <= member_falls + 2, "the leaders fall less often than their members (%d against %d)" % [falls, member_falls])
