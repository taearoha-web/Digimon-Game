extends Node
## The guild leaders stay behind their guild in the castle assault (GuildWarCommander:
## the members push in first, take the switches and clear the throne room, the leader
## follows at the back and goes onto the altar only once the barrier is open and the way
## is clear; a leader under attack falls back behind its own; the guild holding the
## castle keeps its leader back by the altar behind its defenders). Headless, seeded: two
## AI-led guilds (ours led by a picked member, the hero held still in its camp) fight for
## the throne room with every gate down; the leader's distance to the altar is sampled
## against its guild's members, leader falls and the capture are counted.
## SIM_SEEDS="4242,77,9001" SIM_SECONDS=420 for a longer measurement (defaults: one seed,
## 90 s of war a setup).
## godot --headless --path . res://tests/integration/guild_leader_rear_test.tscn
var failures: Array[String] = []
var checks := 0

const SEEDS := [4242]
## War seconds (the clock once counted Engine.time_scale twice: its "360" were 90).
const SECONDS := 90.0


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
	var seeds: Array = SEEDS
	var env_seeds := OS.get_environment("SIM_SEEDS")
	if env_seeds != "":
		seeds = Array(env_seeds.split(",")).map(func(x): return int(x))
	var seconds := SECONDS
	if OS.get_environment("SIM_SECONDS") != "":
		seconds = float(OS.get_environment("SIM_SECONDS"))
	var owner_env := OS.get_environment("SIM_OWNER")
	var owners: Array = [-1, 1] if owner_env == "" else [int(owner_env)]
	var all: Array = []
	for s in seeds:
		for owner in owners:
			all.append(await _war(int(s), int(owner), seconds))
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
	var samples := [0, 0]
	var by_phase := {}
	var capture_at := -1.0
	var captured_by := -1
	var seen_deaths := {}
	var clock := 0.0
	var sample_left := 0.0
	var start_owner := m.castle_owner
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
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
		sample_left = 0.5
		if OS.get_environment("SIM_TRACE") != "" and int(clock * 2.0) % 40 == 0:
			var secs := []
			for team in 2:
				var side: Array[GuildFighter] = m.allies if team == 0 else m.enemies
				secs.append(side.map(func(f): return -1 if f.is_dead() else SiegeArena.section(f.global_position)))
			for L in leads:
				if not L.is_dead():
					print("  lead t%d goal %s keep %s cap %s hold %.0f victim %s vel %.1f c.read van %s foes %s esc %s sw %s go %s" % [L.team, L.goal_point.round(), L.keep_back, L.capture_role, L.hold_range, (L._victim.global_position.round() if L._victim != null and is_instance_valid(L._victim) else "-"), L.velocity.length(), m.commanders[L.team].last_read.get("vanguard"), m.commanders[L.team].last_read.get("altar_foes"), m.commanders[L.team].last_read.get("escort"), m.commanders[L.team].last_read.get("switches"), m.commanders[L.team].leader_go])
			print("t %.0f state %s plans %s tactics %s/%s sections %s switches %s capture %s leads %s %s" % [clock, m.state, m.plans, m.commanders[0].tactic, m.commanders[1].tactic, secs, m.switch_owner, m.capture, leads[0].global_position.round() if not leads[0].is_dead() else "dead", leads[1].global_position.round() if not leads[1].is_dead() else "dead"])
		# The attackers' leader, not yet sent onto the altar: farther than most of its guild
		# (the members in the fight round it, not the switch holders) from where the guild
		# pushes: the gate, the switch it clears, the altar.
		for team in 2:
			if m.castle_owner == team:
				continue
			var lead: GuildFighter = leads[team]
			var c: GuildWarCommander = m.commanders[team]
			if lead.is_dead() or lead.capture_role or lead.capturing:
				continue
			var goal := Vector3.INF
			var gate := m.front_gate()
			if gate != null and c.tactic == GuildWarCommander.PUSH:
				goal = SiegeArena.gate_front(gate.tier, gate.lane)
			elif gate == null and c.tactic == GuildWarCommander.SECURE and c.secure_k >= 0:
				goal = SiegeArena.SWITCHES[c.secure_k]
			elif gate == null and c.tactic in [GuildWarCommander.ESCORT, GuildWarCommander.GUARD]:
				goal = SiegeArena.ALTAR
			if not goal.is_finite():
				continue
			var dists: Array[float] = []
			var side: Array[GuildFighter] = m.allies if team == 0 else m.enemies
			for f in side:
				if f == lead or f.is_dead() or f.switch_post >= 0 or _flat(f.global_position, lead.global_position) > 45.0:
					continue
				dists.append(_flat(f.global_position, goal))
			if dists.size() < 2:
				continue
			dists.sort()
			var median := dists[dists.size() / 2]
			samples[team] += 1
			var key := c.tactic
			var row: Array = by_phase.get(key, [0, 0])
			row[1] += 1
			if _flat(lead.global_position, goal) > median:
				behind[team] += 1
				row[0] += 1
			by_phase[key] = row
	Engine.time_scale = 1.0
	out.merge({"clock": clock, "lead_deaths": lead_deaths, "first_lead_death": first_lead_death, "before_lead": before_lead,
		"member_deaths": member_deaths, "behind": behind, "samples": samples, "capture_at": capture_at, "captured_by": captured_by, "by_phase": by_phase})
	print("SIM seed %d owner %d: capture %.0f s by %d | leader falls %s first at %s (members down before it %s, members down %s) | leader behind the median %s of %s samples %s" % [
		seed, owner, capture_at, captured_by, lead_deaths, first_lead_death, before_lead, member_deaths, behind, samples, by_phase])
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	return out


func _judge(all: Array) -> void:
	var behind := 0
	var samples := 0
	var falls := 0
	var member_falls := 0
	var first_sum := 0.0
	var leads := 0
	var captures := []
	var phases := {}
	for r in all:
		for key in r.by_phase:
			var row: Array = phases.get(key, [0, 0])
			row[0] += int(r.by_phase[key][0])
			row[1] += int(r.by_phase[key][1])
			phases[key] = row
		for team in 2:
			behind += int(r.behind[team])
			samples += int(r.samples[team])
			falls += int(r.lead_deaths[team])
			member_falls += int(r.member_deaths[team])
			# A leader that never fell counts the whole war.
			first_sum += float(r.first_lead_death[team]) if float(r.first_lead_death[team]) >= 0.0 else float(r.clock)
			leads += 1
		captures.append(snappedf(float(r.capture_at), 1.0))
	var share := float(behind) / float(maxi(1, samples))
	print("SIM total: leader behind the median member %d of %d samples (%.0f%%) | leader falls %d, member falls %d (leaders %.0f%% of falls) | mean first leader fall %.0f s | captures %s | by phase %s" % [
		behind, samples, share * 100.0, falls, member_falls, 100.0 * float(falls) / float(maxi(1, falls + member_falls)), first_sum / float(maxi(1, leads)), captures, phases])
	# The checks (the run is seeded, but the fight's timing is not exact to the frame, so
	# the bars leave room): the leader behind most of its guild in most of the assault,
	# and falling far less often than its members.
	var escort: Array = phases.get(GuildWarCommander.ESCORT, [0, 0])
	check(samples >= 100, "the leaders were seen in the assault (%d samples)" % samples)
	check(share >= 0.55, "the attacking leader stands behind most of its guild (%.0f%% of the time, before: about 25%%)" % (share * 100.0))
	check(int(escort[1]) >= 50 and float(escort[0]) >= float(escort[1]) * 0.55, "in the assault on the altar the members go in first and the leader follows (%s)" % [escort])
	check(falls * 4 <= member_falls + 2, "the leaders fall far less often than their members (%d against %d)" % [falls, member_falls])
