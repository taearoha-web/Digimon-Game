extends Node
## Guild wars end in captures, not a stalemate: two AI-led guilds (ours led by a picked
## member, the hero held still in its camp) fight for the castle with every gate down,
## headless and seeded, and the castle is taken (and changes hands) within the war.
## Measured per war: the captures and when, the leader falls, and where an assault stalls
## (seconds with both switches held, with the leader sent up, with the leader on the
## altar, capture counts started and lost).
## SIM_SEEDS="4242,77,9001,31337,555" SIM_SECONDS=1200 SIM_OWNER=-1|1 for a full measurement
## (defaults: one seed, both setups, until the first capture or CAPTURE_BOUND s).
## godot --headless --path . res://tests/integration/guild_war_capture_test.tscn
var failures: Array[String] = []
var checks := 0

const SEEDS := [555]
## The first capture must come within this many seconds of war time: the first half of a
## war (GuildWarData.DURATION). The defaults stop at the first capture, so CI stays short
## (about 2 minutes: the sim runs at SPEED).
const CAPTURE_BOUND := 600.0
const SPEED := 4.0


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
	Game.new_profile(&"warrior", "GWC")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	var seeds: Array = SEEDS
	var env_seeds := OS.get_environment("SIM_SEEDS")
	if env_seeds != "":
		seeds = Array(env_seeds.split(",")).map(func(x): return int(x))
	var full := OS.get_environment("SIM_SECONDS") != ""
	var seconds := float(OS.get_environment("SIM_SECONDS")) if full else CAPTURE_BOUND
	var owner_env := OS.get_environment("SIM_OWNER")
	var owners: Array = [-1, 1] if owner_env == "" else [int(owner_env)]
	var all: Array = []
	for s in seeds:
		for owner in owners:
			all.append(await _war(int(s), int(owner), seconds, full))
	_judge(all, full)
	print("GUILD WAR CAPTURE: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


## One war from `war_seed` with every gate down and `owner` holding the castle (-1 nobody),
## for `seconds` of war time (`full`), or until the first capture.
func _war(war_seed: int, owner: int, seconds: float, full: bool) -> Dictionary:
	# The roster comes from the seed; the fighters' own dice (dodges, slips) too.
	seed(war_seed)
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(war_seed, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0], "owner": owner})
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	var out := {"seed": war_seed, "owner": owner, "captures": [], "clock": 0.0}
	if m == null:
		check(false, "seed %d: no match" % war_seed)
		return out
	var hero: Hero = zone.hero
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	await _frames(6)
	hero.global_position = GuildWarMatch.hero_camp()
	hero.set_physics_process(false)
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
	var member_deaths := [0, 0]
	var seen_deaths := {}
	# Where an assault stalls, per team (the guild not holding the castle): seconds with
	# both switches held, with the leader sent up, with the leader on the altar; counts
	# started and the best count reached.
	var both := [0.0, 0.0]
	var sent := [0.0, 0.0]
	var on_altar := [0.0, 0.0]
	var starts := [0, 0]
	var best := [0.0, 0.0]
	var tactics := [{}, {}]
	var was_capture := false
	var clock := 0.0
	if OS.get_environment("SIM_TRACE") != "":
		m.feed.connect(func(text: String, team: int): print("  [%.0f] %d %s" % [m.commanders[0].clock, team, text]))
	var owner_now := m.castle_owner
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = SPEED
	while clock < seconds and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().physics_frame
		# The physics step already counts Engine.time_scale (war seconds).
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
					else:
						member_deaths[team] += 1
			var c: GuildWarCommander = m.commanders[team]
			tactics[team][c.tactic] = float(tactics[team].get(c.tactic, 0.0)) + dt
			if m.castle_owner == team:
				continue
			if m.switches_held(team) >= 2:
				both[team] += dt
			if c.leader_go:
				sent[team] += dt
			var lead: GuildFighter = leads[team]
			if not lead.is_dead() and SiegeArena.on_altar(lead.global_position):
				on_altar[team] += dt
		var now_capture := not m.capture.is_empty()
		if now_capture and not was_capture:
			starts[int(m.capture.team)] += 1
		if now_capture:
			var ct := int(m.capture.team)
			best[ct] = maxf(best[ct], float(m.capture.progress))
		was_capture = now_capture
		if m.castle_owner != owner_now:
			owner_now = m.castle_owner
			out.captures.append([snappedf(clock, 1.0), owner_now])
			if not full:
				break
		if OS.get_environment("SIM_TRACE") != "" and int(clock / dt) % int(20.0 / dt) == 0:
			print("t %.0f (war %.0f) plans %s tactics %s/%s switches %s capture %s go %s/%s" % [clock, m.commanders[0].clock, m.plans, m.commanders[0].tactic, m.commanders[1].tactic, m.switch_owner,
				{} if m.capture.is_empty() else {"team": m.capture.team, "p": snappedf(float(m.capture.progress), 1.0)}, m.commanders[0].leader_go, m.commanders[1].leader_go])
			for team in 2:
				var c: GuildWarCommander = m.commanders[team]
				var lead: GuildFighter = leads[team]
				print("    team %d: since %.0f van %s foes %s escort %s lead %s altar %.0f m posted %s alive %d" % [team, c.since, c.last_read.get("vanguard"), c.last_read.get("altar_foes"), c.last_read.get("escort"),
					"dead" if lead.is_dead() else str(lead.global_position.round()), SiegeArena.ALTAR.distance_to(lead.global_position), [(c.squads[0] as Array).size(), (c.squads[1] as Array).size()],
					(m.allies if team == 0 else m.enemies).filter(func(f): return not f.is_dead()).size()])
	Engine.time_scale = 1.0
	out.merge({"clock": clock, "lead_deaths": lead_deaths, "member_deaths": member_deaths, "both": both, "sent": sent,
		"on_altar": on_altar, "starts": starts, "best": best})
	var tac := []
	for team in 2:
		var row := {}
		for key in tactics[team]:
			row[key] = int(tactics[team][key])
		tac.append(row)
	print("SIM seed %d owner %d (%.0f s): captures %s | leader falls %s members %s | both switches %s s, leader sent %s s, on altar %s s, counts started %s best %s | tactics %s | wall %.0f s" % [
		war_seed, owner, clock, out.captures, lead_deaths, member_deaths, both.map(func(x): return int(x)), sent.map(func(x): return int(x)),
		on_altar.map(func(x): return int(x)), starts, best.map(func(x): return int(x)), tac, (Time.get_ticks_msec() - t0) / 1000.0])
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	return out


func _judge(all: Array, full: bool) -> void:
	var wars := all.size()
	var with_capture := 0
	var total := 0
	var flips := 0
	var firsts: Array[float] = []
	var lead_falls := 0
	var member_falls := 0
	for r in all:
		var caps: Array = r.captures
		total += caps.size()
		if not caps.is_empty():
			with_capture += 1
			firsts.append(float(caps[0][0]))
		# A castle that changed hands (taken from its holder, or taken back).
		for i in caps.size():
			if i > 0 or int(r.owner) >= 0:
				flips += 1
		lead_falls += int(r.lead_deaths[0]) + int(r.lead_deaths[1])
		member_falls += int(r.member_deaths[0]) + int(r.member_deaths[1])
	firsts.sort()
	var median := firsts[firsts.size() / 2] if not firsts.is_empty() else -1.0
	print("SIM total: %d wars, %d with a capture, %d captures (%d changed hands), first capture median %.0f s %s | leader falls %d, member falls %d" % [
		wars, with_capture, total, flips, median, firsts, lead_falls, member_falls])
	if full:
		return
	for r in all:
		var caps: Array = r.captures
		check(not caps.is_empty(), "seed %d owner %d: the castle is taken within %.0f s (took none)" % [int(r.seed), int(r.owner), CAPTURE_BOUND])
		if int(r.owner) >= 0 and not caps.is_empty():
			check(int(caps[0][1]) != int(r.owner), "seed %d: the castle changes hands" % int(r.seed))
	check(lead_falls * 2 <= member_falls + 2, "the leaders still fall less often than their members (%d against %d)" % [lead_falls, member_falls])
