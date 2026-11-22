extends Node
## Skills that push or pull move the other guild's PLAYERS too in a guild war (WarPush):
## the hero's kick (Muay Thai) and its Imperial Judgment pull (Dark Lord) move an enemy
## fighter by the right distance, a repel (Mob.shove_out) throws it out to the radius; an
## enemy AI fighter's kick and pull move the hero (and our fighters) the same way; never
## through a wall, a standing gate, into the moat, off the field or below the floor (the
## throne court and its stairs); allies are never moved by their own side; a pushed player
## is immune for WarPush.IMMUNE_MS; the leader counting on the altar pushed off its circle
## pauses its count (banked); outside a war (the duel) nothing changes.
##   godot --headless --path . res://tests/integration/guild_war_push_test.tscn
var failures: Array[String] = []
var checks := 0
const SEED := 515151
const MT := &"muaythai"
## Distances are measured after a slide on the bodies' own physics: within this.
const TOL := 0.4

var m: GuildWarMatch
var hero: Hero


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	InputSetup.ensure_defaults()
	WorldEvents.festival_enabled = false
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(MT, "GW Push")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_limits_math()
	await _war()
	print("GUILD WAR PUSH: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


## The arena's limits on paper (no bodies): walls, gates, moat, the field's edge, the maze.
func _limits_math() -> void:
	var S := WarPush.SIEGE
	# The throne room's side wall: a 4 m push 2.5 m from it stops short of it.
	var d := WarPush.safe_distance(S, Vector3(SiegeArena.THRONE_HALF - 5.0, 0, SiegeArena.ALTAR.z), Vector3(1, 0, 0), 4.0)
	check(d < 3.0 and d > 2.5, "the throne room's wall cuts a 4 m push to %.2f m" % d)
	# The back wall.
	d = WarPush.safe_distance(S, Vector3(0, 0, SiegeArena.BACK_Z + 4.0), Vector3(0, 0, -1), 4.0)
	check(d < 2.0, "the back wall cuts a push to %.2f m" % d)
	# The moat: from the bank, never into it; over the bridge, on.
	d = WarPush.safe_distance(S, Vector3(40, 0, -4.5), Vector3(0, 0, -1), 4.0)
	check(d <= 1.75, "the moat's bank stops a push (%.2f m)" % d)
	d = WarPush.safe_distance(S, Vector3(0, 0, -4.5), Vector3(0, 0, -1), 4.0)
	check(is_equal_approx(d, 4.0), "over the bridge a push goes its whole way (%.2f m)" % d)
	# The field's round edge.
	d = WarPush.safe_distance(S, Vector3(0, 0, SiegeArena.RADIUS - 3.0), Vector3(0, 0, 1), 4.0)
	check(d <= 1.5 + 0.01, "the field's edge cuts a push (%.2f m)" % d)
	# A standing gate (the first tier's, both lanes shut) is not pushed through; broken, it is.
	var saved: Array = SiegeArena.lane_open.duplicate(true)
	SiegeArena.lane_open = [[false, false], [false, false]]
	var at_gate := Vector3(SiegeArena.gate_x(0, 1), 0, SiegeArena.GATE_Z[0] + 1.5)
	d = WarPush.safe_distance(S, at_gate, Vector3(0, 0, -1), 4.0)
	check(d <= 1.5, "a standing gate stops a push (%.2f m)" % d)
	SiegeArena.lane_open = [[true, true], [false, false]]
	d = WarPush.safe_distance(S, at_gate, Vector3(0, 0, -1), 4.0)
	check(is_equal_approx(d, 4.0), "through a broken gate the push goes on (%.2f m)" % d)
	# The yard's side wall next to the gate (not through the wall beside the opening).
	d = WarPush.safe_distance(S, Vector3(SiegeArena.LANE_X + SiegeArena.GATE_HALF + 1.5, 0, SiegeArena.GATE_Z[0] + 1.0), Vector3(0, 0, -1), 4.0)
	check(d <= 1.0, "beside the gate the wall stops a push (%.2f m)" % d)
	SiegeArena.lane_open = saved
	# The maze: never past its edge, never into a shrine.
	d = WarPush.safe_distance(WarPush.MAZE, Vector3(MazeLayout.HALF - 3.0, 0, 0), Vector3(1, 0, 0), 4.0)
	check(d <= 1.5 + 0.01, "the maze's edge cuts a push (%.2f m)" % d)
	# Out of a war nothing moves a player (the duel arena keeps its rules).
	check(not GuildWarMatch.in_war() and WarPush.context(null, null) == WarPush.NONE, "no war: no push context")


func _open_war() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


## Everyone out of the way and still; the match's own clock off (the test ticks the capture).
func _hold_still() -> void:
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
		f.velocity = Vector3.ZERO
		f._stun = 0.0
		f.global_position = f.spawn_point + Vector3(0, 0.3, 0)
	m.set_process(false)


## Puts fighter `f` at `p` (on the floor there) awake, unpushed.
func _place(f: GuildFighter, p: Vector3) -> void:
	f.global_position = SiegeArena.on_floor(p, 0.3)
	f.velocity = Vector3.ZERO
	f._stun = 0.0
	f._guard_until = 0
	f.remove_meta(WarPush.META)
	f.set_physics_process(true)
	f._rest_at = Vector3.INF


func _place_hero(p: Vector3) -> void:
	hero.global_position = SiegeArena.on_floor(p, 0.3)
	hero.velocity = Vector3.ZERO
	hero.remove_meta(WarPush.META)
	hero._cast_until = 0
	for c in hero.get_children():
		if c is WarPush.Slide:
			c.free()


## Waits for fighter `f`'s slide to end (or up to 3 s); its flat position then.
func _settle(f: GuildFighter) -> Vector3:
	await _physics(2)
	for i in 180:
		if Vector2(f.velocity.x, f.velocity.z).length() < 0.05:
			break
		await get_tree().physics_frame
	var p := f.global_position
	f.set_physics_process(false)
	return p


func _settle_hero() -> Vector3:
	await _physics(2)
	for i in 180:
		var sliding := false
		for c in hero.get_children():
			if c is WarPush.Slide and not c.is_queued_for_deletion():
				sliding = true
		if not sliding:
			break
		await get_tree().physics_frame
	await _physics(1)
	return hero.global_position


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _war() -> void:
	var zone := _open_war()
	m = zone.gw_match
	check(m != null and GuildWarMatch.in_war(), "a guild war is on")
	if m == null:
		return
	hero = zone.hero
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	for i in 30:
		await _frames(1)
		if m.state == "fight":
			break
	check(m.state == "fight", "the war has begun")
	_hold_still()
	hero.set_physics_process(false)
	var foe: GuildFighter = m.enemies[1]
	var foe2: GuildFighter = m.enemies[2]
	var foe3: GuildFighter = m.enemies[3]
	var ally: GuildFighter = m.allies[1]
	var court := SiegeArena.ALTAR + Vector3(0, 0, 12.0)
	var kick := ClassData.find_skill(MT, "push_kick")
	var earth := ClassData.find_skill(MT, "earth_kick")
	var judgment := ClassData.find_skill(&"darklord", "imperial_judgment")
	check(float(kick.fx.kick) == 4.0 and float(earth.fx.kick) == 5.0 and judgment.fx.has("pull"), "the skills: a 4 m kick, a 5 m kick, a pull")

	# 1. The hero's kick throws an enemy fighter 4 m on the court, held for the slide.
	_place_hero(court)
	_place(foe, court + Vector3(1.5, 0, 0))
	var before := foe.global_position
	MuayThai.skill_fx(hero, foe, kick.fx)
	check(foe._stun > 0.3, "the kicked fighter is staggered (%.2f s)" % foe._stun)
	var after := await _settle(foe)
	var moved := _flat(after, before)
	check(absf(moved - 4.0) < TOL, "the hero's kick moved an enemy fighter %.2f m (4)" % moved)
	check(after.x > before.x + 3.0, "away from the hero")
	check(after.y >= SiegeArena.floor_y(after) - 0.3, "on the court's floor (y %.2f, floor %.2f)" % [after.y, SiegeArena.floor_y(after)])

	# 2. Immunity: kicked again at once it does not move; after IMMUNE_MS it does.
	foe.set_physics_process(true)
	var refused := WarPush.refused
	before = foe.global_position
	MuayThai.skill_fx(hero, foe, kick.fx)
	await _physics(10)
	check(_flat(foe.global_position, before) < 0.2 and WarPush.refused == refused + 1, "pushed again within 2 s: it holds (%.2f m)" % _flat(foe.global_position, before))
	check(WarPush.immune(foe), "it is immune for now")
	foe.set_meta(WarPush.META, GameClock.msec() - 1)
	foe._stun = 0.0
	before = foe.global_position
	_place_hero(before + Vector3(-1.5, 0, 0))
	MuayThai.skill_fx(hero, foe, kick.fx)
	after = await _settle(foe)
	check(_flat(after, before) > 2.0, "after the immunity a kick moves it again (%.2f m)" % _flat(after, before))

	# 3. Allies are never moved by their own side.
	_place_hero(court)
	_place(ally, court + Vector3(1.5, 0, 0))
	ally.set_physics_process(false)
	var pushes := WarPush.pushes
	MuayThai.skill_fx(hero, ally, kick.fx)
	check(Vector2(ally.velocity.x, ally.velocity.z).length() < 0.01 and not WarPush.immune(ally) and WarPush.pushes == pushes, "the hero's kick leaves our own fighter be")
	_place(foe2, court + Vector3(4, 0, 0))
	foe2.set_physics_process(false)
	check(WarPush.pull(foe, foe2, court, 1.5) == 0.0 and Vector2(foe2.velocity.x, foe2.velocity.z).length() < 0.01, "an enemy's pull leaves its own guild be")
	check(WarPush.pull(ally, m.allies[2], court, 1.5) == 0.0, "an ally's pull leaves ours be")

	# 4. The hero's Imperial Judgment pulls enemy fighters in (to PULL_DISTANCE from it).
	_place_hero(court)
	var spots := [Vector3(6, 0, 0), Vector3(-5, 0, 3), Vector3(0, 0, 7)]
	var pulled := [foe, foe2, foe3]
	for i in 3:
		_place(pulled[i], court + spots[i])
	for f in pulled:
		hero._deal_now(f, 0.001, Color.WHITE, &"thunder", false, judgment)
	for f in pulled:
		after = await _settle(f)
		var gap := _flat(after, hero.global_position)
		check(absf(gap - (Mob.PULL_DISTANCE + f.body_radius())) < TOL, "the pull drew an enemy fighter in to %.2f m (%.2f)" % [gap, Mob.PULL_DISTANCE + f.body_radius()])
	# A repel (Mob.shove_out) throws one out to the radius.
	_place(foe, court + Vector3(1.0, 0, 0))
	foe.shove_out(hero.global_position, Mob.REPEL_DISTANCE)
	after = await _settle(foe)
	check(absf(_flat(after, hero.global_position) - (Mob.REPEL_DISTANCE + foe.body_radius())) < TOL, "a repel throws it out to %.2f m" % _flat(after, hero.global_position))

	# 5. An enemy AI fighter's kick and pull move the hero.
	foe.member["class"] = "muaythai"
	_place(foe, court)
	foe.set_physics_process(false)
	_place_hero(court + Vector3(0, 0, 1.5))
	before = hero.global_position
	foe._hit(hero, 0.0001, Color.WHITE, kick.fx)
	check(hero._cast_until > Time.get_ticks_msec(), "the kicked hero is staggered")
	after = await _settle_hero()
	check(absf(_flat(after, before) - 4.0) < TOL, "an enemy's kick moved the hero %.2f m (4)" % _flat(after, before))
	check(after.y >= SiegeArena.floor_y(after) - 0.3, "the hero stays on the court's floor (y %.2f)" % after.y)
	foe.member["class"] = "darklord"
	_place_hero(court + Vector3(6, 0, 0))
	foe._hit(hero, 0.0001, Color.WHITE, judgment.fx)
	after = await _settle_hero()
	check(absf(_flat(after, foe.global_position) - (Mob.PULL_DISTANCE + 0.4)) < TOL, "an enemy's pull drew the hero in to %.2f m" % _flat(after, foe.global_position))
	# And one of our fighters.
	_place(ally, court + Vector3(-6, 0, 0))
	foe._hit(ally, 0.0001, Color.WHITE, judgment.fx)
	after = await _settle(ally)
	check(absf(_flat(after, foe.global_position) - (Mob.PULL_DISTANCE + ally.body_radius())) < TOL, "an enemy's pull drew our fighter in to %.2f m" % _flat(after, foe.global_position))

	# 6. Walls: a kick at the throne room's side wall and its back wall stops short of them.
	var by_wall := Vector3(SiegeArena.THRONE_HALF - 5.0, 0, SiegeArena.ALTAR.z)
	_place_hero(by_wall - Vector3(1.5, 0, 0))
	_place(foe2, by_wall)
	MuayThai.skill_fx(hero, foe2, earth.fx)
	after = await _settle(foe2)
	check(after.x <= SiegeArena.THRONE_HALF - WarPush.WALL_GAP + 0.05 and after.x > by_wall.x + 2.0, "kicked at the side wall it stops at x %.2f (wall %.1f)" % [after.x, SiegeArena.THRONE_HALF])
	foe.member["class"] = "muaythai"
	var by_back := Vector3(4, 0, SiegeArena.BACK_Z + 4.5)
	_place(foe, by_back + Vector3(0, 0, 1.5))
	foe.set_physics_process(false)
	_place_hero(by_back)
	foe._hit(hero, 0.0001, Color.WHITE, earth.fx)
	after = await _settle_hero()
	check(after.z >= SiegeArena.BACK_Z + WarPush.WALL_GAP - 0.05, "the hero kicked at the back wall stops at z %.2f (wall %.1f)" % [after.z, SiegeArena.BACK_Z])

	# 7. Down the grand staircase: on the steps' floor, never under it.
	var top := Vector3(3, 0, SiegeArena.STAIR_Z1 - 1.0)
	_place_hero(top - Vector3(0, 0, 1.5))
	_place(foe3, top)
	MuayThai.skill_fx(hero, foe3, earth.fx)
	var lowest := 99.0
	for i in 60:
		await get_tree().physics_frame
		lowest = minf(lowest, foe3.global_position.y - SiegeArena.floor_y(foe3.global_position))
	after = await _settle(foe3)
	check(after.z > top.z + 3.0, "kicked down the stairs it went down them (z %.2f from %.2f)" % [after.z, top.z])
	check(lowest >= -0.3, "never below the stairs' floor (%.2f m at worst)" % lowest)
	# The hero kicked down the stairs too.
	_place(foe, top - Vector3(0, 0, 1.5))
	foe.set_physics_process(false)
	_place_hero(top)
	foe._hit(hero, 0.0001, Color.WHITE, earth.fx)
	lowest = 99.0
	for i in 60:
		await get_tree().physics_frame
		lowest = minf(lowest, hero.global_position.y - SiegeArena.floor_y(hero.global_position))
	after = await _settle_hero()
	check(after.z > top.z + 3.0, "the hero kicked down the stairs went down them (z %.2f)" % after.z)
	check(lowest >= -0.3, "the hero never below the stairs' floor (%.2f m at worst)" % lowest)

	# 8. The leader counting on the altar, pushed off: its count pauses, banked.
	var lead: GuildFighter = m.ai_leader(GuildFighter.TEAM_ENEMY)
	check(lead != null, "theirs have a leader")
	if lead != null:
		if not m.capture.is_empty():
			m._cancel_capture()
		_place(lead, SiegeArena.ALTAR + Vector3(0.4, 0, 0.6))
		lead.capture_role = true
		m._start_capture(GuildFighter.TEAM_ENEMY, lead)
		m._tick_capture(5.0)
		var count := float(m.capture.get("progress", 0.0))
		check(count >= 5.0 and not bool(m.capture.get("paused", true)), "their leader counts on the altar (%.1f s)" % count)
		_place_hero(SiegeArena.ALTAR + Vector3(0, 0, 7.5))
		# The pull from beyond the circle drags it off.
		hero._deal_now(lead, 0.001, Color.WHITE, &"thunder", false, judgment)
		after = await _settle(lead)
		check(not SiegeArena.on_altar(after), "the pull dragged their leader off the yellow circle (%.2f m from its middle)" % _flat(after, SiegeArena.ALTAR))
		m._tick_capture(2.0)
		check(bool(m.capture.get("paused", false)) and is_equal_approx(float(m.capture.progress), count), "its count pauses at %.1f s (%s)" % [count, m.capture])
		# Back on: it goes on from there; a kick then puts it off again (clear of the circle).
		lead.remove_meta(WarPush.META)
		_place(lead, SiegeArena.ALTAR + Vector3(-0.5, 0, 0))
		m._tick_capture(1.0)
		check(not bool(m.capture.get("paused", true)) and float(m.capture.progress) > count, "back on the circle it counts on (%.1f s)" % float(m.capture.progress))
		count = float(m.capture.progress)
		_place_hero(SiegeArena.ALTAR + Vector3(1.0, 0, 0))
		MuayThai.skill_fx(hero, lead, kick.fx)
		after = await _settle(lead)
		check(_flat(after, SiegeArena.ALTAR) >= SiegeArena.ALTAR_RADIUS + 0.5, "the kick threw it clear of the circle (%.2f m)" % _flat(after, SiegeArena.ALTAR))
		m._tick_capture(1.0)
		check(bool(m.capture.get("paused", false)) and is_equal_approx(float(m.capture.progress), count), "paused again at %.1f s (banked)" % count)

	# 9. Out of the war nothing moves a player.
	zone.queue_free()
	await _frames(3)
	check(not GuildWarMatch.in_war() and not WarPush.handles(null, hero if is_instance_valid(hero) else null), "after the war no push is made")
	Game.guildwar_resuming = false
	Game.guildwar_clear_checkpoint()
	Game.set_process(true)
