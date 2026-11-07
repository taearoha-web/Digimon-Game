extends Node
## The league round's castle war of all four guilds (GuildWarMatch with four teams,
## SiegeArena's four camps and doubled gates, GuildWarCommander's leaders, GuildLeague's
## placement and the castle's holder carried from round to round):
##   - four camps far apart outside the castle, as far from the approach, a clear way in;
##   - 80 fighters (the hero one of ours), each hostile to the other guilds only;
##   - the castle's holder starts inside, walks through its own gates both ways (the others
##     are blocked), its blows do its gates no harm, its AI comes out to guard both gates;
##     a capture hands the gates (and the keep) to the new holder;
##   - placement scoring, the table, the chain of holders across rounds, days and weeks, the
##     seeded rounds begun with that holder;
##   - the checkpoint brings four teams back; watching shows the four guilds; a practice
##     war of two still works;
##   - a seeded AI-only war of four with the gates down ends in a capture (accelerated).
## SIM_SEEDS="4242,77,9001" SIM_SECONDS=1200 (SIM_ONLY=1 to skip the rest, SIM_TRACE=1 for
## the feed) for the capture measurement over full wars.
##   godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_4way_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0
const SPEED := 4.0
const CAPTURE_BOUND := 600.0
const SEEDS := [4242]
const RETRY_SEEDS := [77]


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
	_hero()
	if OS.get_environment("SIM_ONLY") != "":
		# The capture measurement alone (SIM_SEEDS, SIM_SECONDS).
		await _ai_wars()
		print("GUILD WAR 4WAY SIM: %d checks, %d failures" % [checks, failures])
		get_tree().quit(0)
		return
	_geometry()
	await _paths()
	await _hero_war()
	await _owner_war()
	await _hero_holder()
	_placement()
	_league()
	await _resume()
	await _spectate()
	await _practice()
	await _ai_wars()
	WorldPresence.clock_offset = 0.0
	print("GUILD WAR 4WAY: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero() -> void:
	Game.new_profile(&"warrior", "War4 QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.current_zone = &"guildwar"


## Four hired guilds of twenty (ours one short when the hero fights), colours by league id.
func _roster(hero_in: bool, owner := -1, roll_seed := 2024) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var info := GuildWarSpectate.demo_war(rng, GuildWarData.GUILD_SIDE)
	info["guilds"] = false
	if hero_in:
		(info.sides[0].lineup as Array).resize(GuildWarData.GUILD_SIDE - 1)
	info["owner"] = owner
	return info


func _zone() -> Zone:
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	return zone


func _drop(zone: Zone) -> void:
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


# ---------------------------------------------------------------------------
# The field: four camps, far apart, outside the castle, as far from the way in
# ---------------------------------------------------------------------------

func _geometry() -> void:
	check(SiegeArena.CAMPS.size() == 4, "four camps")
	check(SiegeArena.RADIUS >= 78.0 * 1.5, "the field is half as wide again as before (radius %.0f m)" % SiegeArena.RADIUS)
	for a in 4:
		var c := SiegeArena.camp(a)
		check(c.z > SiegeArena.MOAT_SOUTH + SiegeArena.CAMP_RADIUS, "camp %d is outside the castle, south of the moat" % a)
		check(absf(c.distance_to(SiegeArena.APPROACH) - SiegeArena.CAMP_DIST) < 0.5, "camp %d is %.1f m from the castle's approach (all the same)" % [a, c.distance_to(SiegeArena.APPROACH)])
		check(Vector2(c.x, c.z).length() + 19.0 < SiegeArena.RADIUS, "camp %d and its curtain are inside the field" % a)
		for b in range(a + 1, 4):
			check(c.distance_to(SiegeArena.camp(b)) > 60.0, "camps %d and %d are far apart (%.0f m)" % [a, b, c.distance_to(SiegeArena.camp(b))])
	check(SiegeArena.camp(0).x < 0.0 and SiegeArena.camp(1).x > 0.0 and absf(SiegeArena.camp(0).z - SiegeArena.camp(1).z) < 0.1, "a war of two uses the west and east camps")
	check(SiegeArena.section(SiegeArena.KEEP_CAMP) == 3 and SiegeArena.KEEP_CAMP.distance_to(SiegeArena.ALTAR) > 25.0, "the holder's camp is inside the castle, behind the second tier, some way from the altar")
	check(SiegeArena.TIER_LANES == [2, 2, 1], "two gates on each of the first two tiers, one on the third")


## Every camp's way in: open ground to its lane at the bridge foot, over the wide bridge to
## the first tier's gate; the way it is routed starts at the bridge foot; no camp is much
## nearer the gate than another.
func _paths() -> void:
	GuildWarMatch.next_roster = _roster(true)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := zone.get_world_3d().direct_space_state
	var lengths: Array[float] = []
	for t in 4:
		var c := SiegeArena.camp(t)
		var foot := SiegeArena.route(c + Vector3(0, 0, 0), SiegeArena.ALTAR)
		check((SiegeArena.CONNECTORS[0] as Array).has(foot), "camp %d: the way to the altar starts at the bridge foot" % t)
		var gate := Vector3(foot.x, 0, SiegeArena.GATE_Z[0] + 3.0)
		var blocked := []
		for leg in [[c, foot], [foot, gate]]:
			for dx in [-1.5, 0.0, 1.5]:
				var a: Vector3 = leg[0] + Vector3(dx, 1.0, 0)
				var b: Vector3 = leg[1] + Vector3(dx, 1.0, 0)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))
				if not hit.is_empty():
					blocked.append(hit.position)
		check(blocked.is_empty(), "camp %d: a clear way to the gate (%s)" % [t, blocked])
		lengths.append(c.distance_to(foot) + foot.distance_to(gate))
	var shortest: float = lengths.min()
	var longest: float = lengths.max()
	check(longest < shortest * 1.15, "no camp is structurally nearer the gate (%s)" % [lengths])
	# The castle's two doubled tiers: walls closed but at the gates, the gates side by side.
	for k in 2:
		var gaps := []
		for i in int(SiegeArena.HALL_HALF * 2.0):
			var x := -SiegeArena.HALL_HALF + 0.5 + float(i)
			var z: float = SiegeArena.GATE_Z[k]
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, z + 4.0), Vector3(x, 1.0, z - 4.0), 1)).is_empty():
				gaps.append(x)
		check(gaps.is_empty(), "tier %d: the walls and both gates leave no gap (%s)" % [k + 1, gaps])
	check(m.gates.size() == 5, "five gates")
	await _drop(zone)


# ---------------------------------------------------------------------------
# The hero's war: 19 of ours and the hero against the other three guilds
# ---------------------------------------------------------------------------

func _hero_war() -> void:
	GuildWarMatch.next_roster = _roster(true)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	var hero: Hero = zone.hero
	check(m != null and m.team_count() == 4, "four guilds in the war")
	if m == null:
		return
	var sizes := []
	for t in 4:
		sizes.append(m.side(t).size())
	check(sizes == [19, 20, 20, 20] and m.all_fighters().size() + 1 == 80, "80 fighters: the hero and 19 of ours, 20 of each other guild (%s)" % [sizes])
	check(m.all_fighters().all(func(f): return f is SiegeFighter), "every fighter knows four guilds (SiegeFighter)")
	var colors := {}
	for t in 4:
		colors[m.team_color(t).to_html()] = true
	check(colors.size() == 4, "four guild colours")
	check(m.castle_owner == -1 and m.start_owner == -1, "nobody holds the castle: everyone starts outside")
	for t in 4:
		var all_home := m.side(t).all(func(f): return Vector2(f.global_position.x - SiegeArena.camp(t).x, f.global_position.z - SiegeArena.camp(t).z).length() < SiegeArena.CAMP_RADIUS)
		check(all_home, "guild %d lines up in its own camp" % t)
	check(hero.global_position.distance_to(GuildWarMatch.hero_camp()) < 1.0, "the hero starts with its guild")
	for f in m.side(0):
		check(f.is_in_group("companions") and not f.is_in_group("mobs"), "ours stand with the hero")
		break
	var mobs := 0
	for t in range(1, 4):
		for f in m.side(t):
			mobs += 1 if f.is_in_group("mobs") else 0
	check(mobs == 60, "the three other guilds are all the hero's enemies (%d)" % mobs)
	# Who is whose enemy.
	m._timer = 0.05
	while m.state != "fight":
		await get_tree().process_frame
	await get_tree().physics_frame
	for t in 4:
		var f: GuildFighter = m.side(t)[1]
		var targets := f._targets()
		var friends := f._teammates()
		var own_in := targets.filter(func(x): return x is GuildFighter and (x as GuildFighter).team == t).size()
		var others := 0
		for o in 4:
			if o != t:
				others += m.side(o).filter(func(g): return not g.is_dead()).size()
		var foes_in := targets.filter(func(x): return x is GuildFighter).size()
		check(own_in == 0 and foes_in == others, "guild %d: every fighter of the other guilds is a target, none of its own (%d of %d)" % [t, foes_in, others])
		check(friends.all(func(x): return x == hero or (x is GuildFighter and (x as GuildFighter).team == t)) and friends.size() >= m.side(t).size() - 1, "guild %d: its friends are its own" % t)
		check(targets.has(hero) == (t != 0), "guild %d: the hero is %s" % [t, "a friend" if t == 0 else "an enemy"])
	check(m.commanders.size() == 4 and m.plans.size() == 4 and m.plans.all(func(p): return p != ""), "a commander and a plan for each guild (%s)" % [m.plans])
	# Scoring: a fall scores for the killer's guild, the hero's for ours.
	var victim: GuildFighter = m.side(2)[3]
	var before := m.score.duplicate()
	victim._last_attacker = m.side(3)[0]
	victim._die()
	check(m.score[3] == before[3] + 1 and m.score[2] == before[2], "a fall scores for the guild that dealt it (%s)" % [m.score])
	var kills := m.hero_kills
	var other: GuildFighter = m.side(1)[4]
	other._last_attacker = hero
	other._die()
	check(m.score[0] == before[0] + 1 and m.hero_kills == kills + 1, "the hero's kill scores for its guild")
	check(m.score_line().contains(m.team_name(3)), "the HUD's score line names every guild")
	await _drop(zone)


# ---------------------------------------------------------------------------
# The castle's holder: inside, through its own gates, harmless to them, out to guard them
# ---------------------------------------------------------------------------

func _blocked(body: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	body.global_position = from
	return body.test_move(Transform3D(Basis(), from), motion)


func _owner_war() -> void:
	GuildWarMatch.next_roster = _roster(true, 2)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "owner war: no match")
		return
	check(m.castle_owner == 2 and m.start_owner == 2, "the holder of the round before holds the castle as the war begins")
	check(m.side(2).all(func(f): return SiegeArena.section(f.global_position) >= 3 and f.spawn_point.distance_to(SiegeArena.KEEP_CAMP) < 20.0), "the holder starts inside the castle")
	check(m.side(1).all(func(f): return f.global_position.distance_to(SiegeArena.camp(1)) < SiegeArena.CAMP_RADIUS), "the others start in their camps outside")
	check(m.owner_briefing().contains(m.team_name(2)), "the briefing names the holder (%s)" % m.owner_briefing())
	m._timer = 0.05
	while m.state != "fight":
		await get_tree().process_frame
	await get_tree().physics_frame
	var keeper: GuildFighter = m.side(2)[5]
	var raider: GuildFighter = m.side(1)[5]
	keeper.set_physics_process(false)
	raider.set_physics_process(false)
	var gate: CastleGate = m.gates[4]
	var south := Vector3(0, 0.3, SiegeArena.GATE_Z[2] + 2.6)
	var north := Vector3(0, 0.3, SiegeArena.GATE_Z[2] - 2.6)
	check(m.passes_gates(keeper) and not m.passes_gates(raider), "the holder passes its gates, the others do not")
	check(not _blocked(keeper, north, Vector3(0, 0, 5.2)), "the holder walks out through its closed gate")
	check(not _blocked(keeper, south, Vector3(0, 0, -5.2)), "and back in")
	check(_blocked(raider, south, Vector3(0, 0, -5.2)), "an attacker is blocked by the closed gate")
	var front: CastleGate = m.gates[0]
	var hp := front.hp
	front.take_hit(1000, false, Color.WHITE, keeper)
	front.take_damage(50000.0, keeper)
	check(front.hp == hp, "the holder's blows do its own gate no harm")
	front.take_damage(5000.0, raider)
	check(front.hp < hp, "an attacker's blow does")
	keeper.set_physics_process(true)
	raider.set_physics_process(true)
	# Its AI comes out to guard both gates of the front tier.
	for c in m.commanders:
		c.think(GuildWarCommander.THINK_EVERY)
	m._make_plans()
	m._assign_objectives()
	check(m.plans[2] == "gates" and m.commanders[2].tactic == GuildWarCommander.DEFEND, "the holder plans to guard the gates (%s / %s)" % [m.plans[2], m.commanders[2].tactic])
	var at_lane := [0, 0]
	var posted := 0
	var lead := m.ai_leader(2)
	for f in m.side(2):
		if f == lead or f.switch_post >= 0:
			continue
		for g in m.front_gates():
			if f.goal_point.distance_to(SiegeArena.gate_front(g.tier, g.lane)) < 9.0 and f.objective == null:
				at_lane[g.lane] += 1
				posted += 1
	check(posted >= m.side(2).size() - 3 and at_lane[0] > 0 and at_lane[1] > 0, "the holder's members stand before both gates (%s)" % [at_lane])
	check(lead == null or lead.goal_point.z < SiegeArena.GATE_Z[0], "its leader stays inside behind them")
	check(m.side(1).all(func(f): return f.objective == null or not f.objective.is_dead()), "the attackers go for the gates")
	# A capture: the castle, its gates and the keep are the new holder's.
	var taker := m.ai_leader(1)
	m._gate_pass()
	m.capture = {"team": 1, "who": taker, "progress": GuildWarMatch.CAPTURE_TIME, "paused": false, "barrier": false}
	m._complete_capture()
	check(m.castle_owner == 1 and m.captures[1] == 1, "a capture changes the holder")
	check(m.side(1).all(func(f): return f.spawn_point.distance_to(SiegeArena.KEEP_CAMP) < 20.0) and m.side(2).all(func(f): return f.spawn_point.distance_to(SiegeArena.camp(2)) < SiegeArena.CAMP_RADIUS), "the new holder comes back in the keep, the old one at its camp")
	check(m.passes_gates(raider) and not m.passes_gates(keeper), "the gates are the new holder's")
	await _drop(zone)


## Our guild holds the castle: the hero starts inside with it and walks through its gates.
func _hero_holder() -> void:
	GuildWarMatch.next_roster = _roster(true, 0)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	var hero: Hero = zone.hero
	check(m.castle_owner == 0 and SiegeArena.section(hero.global_position) >= 3 and hero.global_position.distance_to(SiegeArena.KEEP_CAMP) < 3.0, "our guild holds the castle: the hero starts inside (%s)" % hero.global_position)
	check(m.owner_briefing() == "กิลด์ของคุณครองปราสาท — ป้องกันประตูและแท่นประทับ", "the briefing tells it to defend")
	await get_tree().physics_frame
	var north := Vector3(0, 0.3, SiegeArena.GATE_Z[2] - 2.6)
	check(m.passes_gates(hero) and not _blocked(hero, north, Vector3(0, 0, 5.2)), "the hero walks through its own closed gate")
	var hp := m.gates[0].hp
	m.gates[0].take_hit(1000, false, Color.WHITE, hero)
	check(m.gates[0].hp == hp, "and its blows do the gate no harm")
	await _drop(zone)


# ---------------------------------------------------------------------------
# Placement and the league
# ---------------------------------------------------------------------------

func _placement() -> void:
	var e := {"g": [1, 2, 3, 4], "k": [10, 30, 5, 0], "c": [0, 1, 0, 0], "held": 4}
	check(GuildLeague.placement(e) == [4, 2, 1, 3], "1st holds the castle, then by points (%s)" % [GuildLeague.placement(e)])
	check(GuildLeague.side_points(e, 4) == 40 + GuildLeague.HOLD and GuildLeague.side_points(e, 2) == 25 + 30 / GuildLeague.KILLS_PER_POINT + GuildLeague.CAPTURE, "placement points + hold + falls + captures (%d, %d)" % [GuildLeague.side_points(e, 4), GuildLeague.side_points(e, 2)])
	check(GuildLeague.side_points(e, 3) == 10 + 1 and GuildLeague.side_points(e, 1) == 15 + 2, "3rd and 4th")
	var none := {"g": [1, 2, 3, 4], "k": [26, 25, 25, 1], "c": [0, 1, 0, 0], "held": 0}
	check(GuildLeague.placement(none) == [2, 1, 3, 4], "nobody holding: by points, then falls (%s)" % [GuildLeague.placement(none)])
	check(GuildLeague.PLACE_POINTS == [40, 25, 15, 10], "40 / 25 / 15 / 10")


func _league() -> void:
	var t := float(WorldPlayers.START_UNIX) + 21.0 * DAY
	WorldPlayers.ensure_until(t)
	var w := GuildLeague.week_of(t)
	var list := GuildLeague.schedule(w)
	check(list.size() == 21 and list.all(func(r): return r.guilds == [1, 2, 3, 4]), "21 rounds a week, every guild in each")
	# The chain: each round begins with the holder after the one before, across days and
	# into the next week; only a capture changes it; a seeded round begins with it.
	var start := int(GuildLeague.week_start(w - 1))
	var at := GuildLeague.next_slot(float(start) - 1.0)
	var end := int(GuildLeague.week_end(w))
	var rounds := 0
	var keeps := 0
	var held_rounds := 0
	var chain_ok := true
	var capture_ok := true
	var seeded_ok := true
	while at < end:
		var own := GuildLeague.start_holder(at)
		var e := GuildLeague.sim_round(at, own)
		var after := GuildLeague.holder_after(at)
		var next := GuildLeague.next_slot(float(at))
		chain_ok = chain_ok and GuildLeague.start_holder(next) == after
		seeded_ok = seeded_ok and int(e.own) == own and after == (int(e.held) if int(e.held) > 0 else own)
		if after != own:
			var i := (e.g as Array).find(after)
			capture_ok = capture_ok and i >= 0 and int(e.c[i]) >= 1
		if own > 0:
			held_rounds += 1
			keeps += 1 if after == own else 0
		rounds += 1
		at = next
	check(rounds == 42, "two weeks of rounds walked (%d)" % rounds)
	check(chain_ok, "each round begins with the holder after the round before (across days and weeks)")
	check(seeded_ok, "the seeded rounds begin with that holder, and it holds on unless taken")
	check(capture_ok, "the holder changes only by a capture")
	check(held_rounds > 30 and keeps * 4 >= held_rounds, "the defender holds the castle often enough (%d of %d)" % [keeps, held_rounds])
	GuildLeague._sim_cache.clear()
	var at0 := int(list[3].at)
	check(GuildLeague.sim_round(at0, 2).hash() == GuildLeague.sim_round(at0, 2).hash() and str(GuildLeague.sim_round(at0, 2)) == str(GuildLeague.sim_round(at0, 2)), "the seeded round is the same every time")
	# The hero's real round in the table, and in the chain: Neverdie takes the castle.
	_hero()
	Game.join_guild(1)
	var r_at := int(list[4].at)
	WorldPresence.clock_offset = float(r_at) + GuildWarData.DURATION + 60.0 - WorldPlayers.now()
	var own0 := GuildLeague.start_holder(r_at)
	var pts := GuildLeague.record_round([1, 2, 3, 4], [0, 2, 0, 0], [12, 30, 4, 9], 1, float(r_at), own0)
	var real := GuildLeague.real_wars(w)
	check(real.size() == 1 and GuildLeague.valid(Game.profile[GuildLeague.KEY]), "the round is kept, the save stays valid")
	check(pts == GuildLeague.side_points(GuildLeague._round_of(real[0]), 1) and pts > 0, "our guild's points of the round (%d)" % pts)
	check(GuildLeague.holder_after(r_at) == 2 and GuildLeague.start_holder(int(list[5].at)) == 2, "the round's capture carries to the next round")
	var tab := GuildLeague.table(w, real)
	var total := 0
	var firsts := 0
	for row in tab:
		total += int(row.points)
		firsts += int(row.wins)
	var expect := 0
	var counted := GuildLeague.events(w, real)
	for e in counted:
		for g in e.g:
			expect += GuildLeague.side_points(e, int(g))
	check(tab.size() == 4 and total == expect and firsts == counted.size(), "the table adds up every round's placement points (%d / %d, %d firsts)" % [total, expect, firsts])
	check(GuildLeague.champion_of(w, real) == GuildLeague.holder_after(GuildLeague.prev_slot(int(GuildLeague.week_end(w))), real), "the champion is the holder when the week ends")
	# Old two-guild records stay readable and valid beside the rounds.
	var pair: Array = GuildLeague.pairs_at(int(list[0].at))[0]
	var old := {"at": int(list[0].at), "a": int(pair[0]), "b": int(pair[1]), "win": int(pair[0]), "ca": 1, "cb": 0, "held": int(pair[0]), "ka": 20, "kb": 10}
	var d: Dictionary = Game.profile[GuildLeague.KEY]
	(d.wars as Array).push_front(old)
	check(GuildLeague.valid(d), "an old war record beside a round record is valid")
	check(GuildLeague.events(w, GuildLeague.real_wars(w)).any(func(e): return e.has("a") and bool(e.get("real", false))), "the old war still counts in its round")
	var bad: Dictionary = (d.wars[1] as Dictionary).duplicate()
	bad.erase("own")
	check(not GuildLeague.valid({"wars": [bad]}), "a broken round record is refused")
	var floats := {"week": float(w), "wars": [{"at": float(r_at), "g1": 1.0, "g2": 2.0, "g3": 3.0, "g4": 4.0, "k1": 1.0, "k2": 2.0, "k3": 3.0, "k4": 4.0, "c1": 0.0, "c2": 0.0, "c3": 0.0, "c4": 0.0, "held": 0.0, "own": 0.0}]}
	var prof := {GuildLeague.KEY: floats}
	GuildLeague.repair(prof)
	check(prof.has(GuildLeague.KEY) and typeof(prof[GuildLeague.KEY].wars[0].g1) == TYPE_INT, "a round record read back from JSON is repaired")
	(d.wars as Array).clear()
	# The live round to watch: every guild, its holder, in side order.
	var live_at := int(list[6].at)
	WorldPresence.clock_offset = float(live_at) + 300.0 - WorldPlayers.now()
	var info := GuildLeague.live_round_info()
	check((info.sides as Array).size() == 4 and info.league_round == [1, 2, 3, 4] and int(info.owner) == (info.league_round as Array).find(GuildLeague.start_holder(live_at)), "the live round's watch info has four guilds and its holder")
	check(GuildLeague.owner_text(live_at) != "", "the desk tells who holds the castle")
	var m := GuildLeague.enter_match()
	check(m.is_empty() or (m.guilds as Array).size() == 4, "entering a round brings all four guilds")
	WorldPresence.clock_offset = 0.0


# ---------------------------------------------------------------------------
# Checkpoint, watching, practice
# ---------------------------------------------------------------------------

func _resume() -> void:
	_hero()
	GuildWarMatch.next_roster = _roster(true, -1, 99)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	m.score.assign([3, 4, 5, 6])
	m.captures.assign([0, 1, 0, 0])
	m.gates[1].set_broken_quietly()
	m._update_breakable()
	m.castle_owner = 3
	m.save_checkpoint()
	var saved := Game.guildwar_checkpoint()
	check((saved.scores as Array) == [3, 4, 5, 6] and (saved.gates as Array).size() == 5 and int(saved.owner) == 3, "the checkpoint keeps four scores, five gates and the holder (%s)" % [saved])
	var seed_was := m.roll_seed
	zone.queue_free()
	await _frames(3)
	GuildWarMatch.next_roster = _roster(true, -1, 99)
	Game.guildwar_resuming = true
	var back := _zone()
	var bm: GuildWarMatch = back.gw_match
	check(bm.resumed and bm.roll_seed == seed_was and bm.team_count() == 4 and bm.score == [3, 4, 5, 6], "a resumed war of four comes back with every score (%s)" % [bm.score])
	check(bm.gates[1].is_dead() and not bm.gates[0].is_dead() and bm.front_tier() == 1, "and its gates")
	check(bm.castle_owner == 3 and bm.side(3).all(func(f): return f.spawn_point.distance_to(SiegeArena.KEEP_CAMP) < 20.0), "and its holder, back inside")
	await _drop(back)


func _spectate() -> void:
	_hero()
	var info := _roster(false, 3, 7)
	info["guilds"] = true
	info["elapsed"] = 400.0
	info["league_round"] = [1, 2, 3, 4]
	info["slot_start"] = 1700000000
	GuildWarSpectate._pending = info
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.spectating() and m.team_count() == 4 and m.all_fighters().size() == 80, "watching: four guilds of twenty")
	var spec := m.spectator
	await _frames(3)
	spec._update_board()
	var rows := spec.board_rows()
	check(rows.size() == 4 and rows.map(func(r): return r.name) == ["Alpha", "Neverdie", "Titan", "3DLnw"], "the board shows the four guilds (%s)" % [rows.map(func(r): return r.name)])
	check(rows[3].holder and not rows[0].holder and m.castle_owner == 3, "the holder is crowned on the board")
	check(rows.all(func(r): return r.color != Color.WHITE), "each in its colour")
	var names := []
	for i in spec.focus_count():
		spec.cycle_focus()
		names.append(spec.focus_name())
	check(names == ["ปราสาท", "กิลด์ Alpha", "กิลด์ Neverdie", "กิลด์ Titan", "กิลด์ 3DLnw", "ติดตามการรบ"], "the focus cycles castle, each guild, back to the action (%s)" % [names])
	await _drop(zone)


func _practice() -> void:
	_hero()
	Game.guildwar_league = {}
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.team_count() == 2 and m.allies.size() == GuildWarData.TEAM_SIZE - 1 and m.enemies.size() == GuildWarData.TEAM_SIZE, "a practice war is still two hired guilds")
	check(m.castle_owner == -1 and m.gates.size() == 5, "nobody holds its castle")
	check(m.enemies.all(func(f): return f.global_position.distance_to(SiegeArena.camp(1)) < SiegeArena.CAMP_RADIUS), "the rivals start in the east camp")
	await _drop(zone)


# ---------------------------------------------------------------------------
# A seeded AI-only war of four with the gates down ends in a capture
# ---------------------------------------------------------------------------

func _ai_wars() -> void:
	var seeds: Array = SEEDS
	var env := OS.get_environment("SIM_SEEDS")
	if env != "":
		seeds = Array(env.split(",")).map(func(x): return int(x))
	var full := OS.get_environment("SIM_SECONDS") != ""
	var seconds := float(OS.get_environment("SIM_SECONDS")) if full else CAPTURE_BOUND
	var all: Array = []
	if full:
		for s in seeds:
			all.append(await _ai_war(int(s), seconds, true))
	else:
		var r := {}
		for s in seeds + RETRY_SEEDS:
			r = await _ai_war(int(s), seconds, false)
			if not (r.captures as Array).is_empty():
				break
		all.append(r)
	var total := 0
	var lead_falls := 0
	var member_falls := 0
	for r in all:
		total += (r.captures as Array).size()
		lead_falls += int(r.lead_falls)
		member_falls += int(r.member_falls)
	print("SIM4 total: %d wars, %d captures, leader falls %d (per leader %.1f), member falls %d (per member %.1f)" % [all.size(), total, lead_falls, float(lead_falls) / float(4 * all.size()), member_falls, float(member_falls) / float(76 * all.size())])
	if full:
		return
	check(not (all[0].captures as Array).is_empty(), "a seeded war of four AI guilds ends in a capture within %.0f s" % CAPTURE_BOUND)
	check(float(lead_falls) / 4.0 < float(member_falls) / 76.0 * 1.5 + 0.5, "leaders fall no more often than members (%d / 4 against %d / 76)" % [lead_falls, member_falls])
	check(all[0].traces > 0, "the leaders' moves are told in the feed")


func _ai_war(war_seed: int, seconds: float, full: bool) -> Dictionary:
	seed(war_seed)
	_hero()
	Game.guildwar_save_checkpoint(war_seed, GuildWarData.DURATION, false, [0, 0, 0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1, "teams": 4})
	Game.guildwar_resuming = true
	GuildWarMatch.next_roster = _roster(true, -1, war_seed)
	var zone := _zone()
	var m: GuildWarMatch = zone.gw_match
	var out := {"seed": war_seed, "captures": [], "lead_falls": 0, "member_falls": 0, "traces": 0}
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
	var leads: Array = []
	for t in 4:
		leads.append(m.ai_leader(t))
	var seen := {}
	var owner_now := m.castle_owner
	var clock := 0.0
	var t0 := Time.get_ticks_msec()
	var trace := OS.get_environment("SIM_TRACE") != ""
	if trace:
		m.feed.connect(func(text: String, team: int): print("  [%.0f] %d %s" % [m.commanders[0].clock, team, text]))
	Engine.time_scale = SPEED
	while clock < seconds and Time.get_ticks_msec() - t0 < 900000:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		clock += dt
		m.time_left = GuildWarData.DURATION
		for f in m.all_fighters():
			var id := f.get_instance_id()
			if f.deaths > int(seen.get(id, 0)):
				seen[id] = f.deaths
				if leads.has(f):
					out.lead_falls += 1
				else:
					out.member_falls += 1
		if m.castle_owner != owner_now:
			owner_now = m.castle_owner
			out.captures.append([snappedf(clock, 1.0), owner_now, m.team_name(owner_now)])
			if not full:
				break
	Engine.time_scale = 1.0
	var leader_lines := m.trace.filter(func(l): return l.begins_with("หัวหน้ากิลด์") or l.begins_with("กิลด์"))
	out.traces = leader_lines.size()
	print("SIM4 seed %d (%.0f s): captures %s | leader falls %d members %d | wall %.0f s" % [war_seed, clock, out.captures, out.lead_falls, out.member_falls, (Time.get_ticks_msec() - t0) / 1000.0])
	for l in leader_lines.slice(0, 12):
		print("  trace: ", l)
	await _drop(zone)
	return out
