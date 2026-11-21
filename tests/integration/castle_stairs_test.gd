extends Node
## The guild war's grand staircase and raised throne court (headless). Past the third gate
## a staircase as wide as the court climbs SiegeArena.COURT_H to the court where the two
## switches and the altar stand:
##   - the map: the floor is level in the field and the yards, rises up the stairs and is
##     COURT_H on the court (floor_y); the altar and the switches are on the court; the
##     map points the fighters' brains use (ALTAR, SWITCHES, the routes) stay flat; the
##     stairs are no narrower than the court and far wider than a gate
##   - the hero walking north from the third gate climbs the stairs, crosses the court and
##     stands on the altar at the court's height; so does a guild fighter sent to take the
##     altar (its own way: SiegeArena.route), nobody stuck on the way
##   - a body standing on the court does not fall through; one put under the floor (a
##     skill that moves it to a spot at the field's height) is set back on it (SiegeLift)
##   - an effect drawn for flat ground over the court (a danger circle) is lifted onto its
##     floor; one put at a body's real height is left alone
##   - the altar's crystal, its barrier and the switch pads stand on the court
##   - a guild's fallen come back standing on the floor where their camp is (the castle
##     holder's camp in the second yard included)
## godot --headless --path . res://tests/integration/castle_stairs_test.tscn
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
		await get_tree().physics_frame


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GWStairs")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_map()
	await _walks()
	print("CASTLE STAIRS: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _map() -> void:
	var S := SiegeArena
	check(S.COURT_H >= 4.0 and S.COURT_H <= 6.0, "the court stands 4 to 6 m over the yards (%.1f)" % S.COURT_H)
	check(is_zero_approx(S.floor_y(S.PLAZA)) and is_zero_approx(S.floor_y(S.KEEP_CAMP)) and is_zero_approx(S.floor_y(S.gate_front(2))), "the field, the yards and the third gate's front are level ground")
	check(is_equal_approx(S.floor_y(S.ALTAR), S.COURT_H) and is_equal_approx(S.altar_top().y, S.COURT_H), "the altar stands on the raised court")
	for k in S.SWITCHES.size():
		check(is_equal_approx(S.floor_y(S.SWITCHES[k]), S.COURT_H) and is_equal_approx(S.switch_top(k).y, S.COURT_H), "switch %d stands on the raised court" % k)
		check(S.SWITCHES[k].z + S.SWITCH_RADIUS < S.STAIR_Z1, "switch %d's circle is clear of the stairs" % k)
	check(is_zero_approx(S.ALTAR.y) and is_zero_approx(S.SWITCHES[0].y) and is_zero_approx(S.route(S.gate_front(2), S.ALTAR).y), "the map points and the routes stay flat")
	# The stairs: between the third gate and the switches, rising all the way, walkable.
	check(S.STAIR_Z0 < S.GATE_Z[2] - 2.2 and S.STAIR_Z1 < S.STAIR_Z0, "the stairs start inside the third gatehouse and run north")
	var last := -1.0
	var rising := true
	for i in 17:
		var y := S.floor_y(Vector3(0, 0, lerpf(S.STAIR_Z0 + 0.5, S.STAIR_Z1 - 0.5, float(i) / 16.0)))
		rising = rising and y >= last
		last = y
	check(rising and is_equal_approx(last, S.COURT_H), "the floor rises all the way up the stairs to the court")
	var mid := S.floor_y(Vector3(0, 0, (S.STAIR_Z0 + S.STAIR_Z1) * 0.5))
	check(mid > S.COURT_H * 0.3 and mid < S.COURT_H * 0.7, "halfway up the stairs the floor is about half the court's height (%.2f)" % mid)
	var slope := rad_to_deg(atan2(S.COURT_H, S.STAIR_RUN))
	check(slope < 35.0, "the stairs are a walkable slope (%.1f degrees, a body's floor limit is 45)" % slope)
	check(is_equal_approx(S.floor_y(Vector3(S.THRONE_HALF - 3.0, 0, S.STAIR_Z1 - 1.0)), S.COURT_H) and S.floor_y(Vector3(-S.THRONE_HALF + 3.0, 0, (S.STAIR_Z0 + S.STAIR_Z1) * 0.5)) > 1.0,
		"the stairs and the court run the whole width between the walls (no way in narrower than before)")
	check(S.THRONE_HALF * 2.0 - 3.4 > S.GATE_HALF * 2.0 * 3.0, "the stairs are far wider than the gate before them")
	check(S.hall_rect().has_point(Vector2(S.ALTAR.x, S.ALTAR.z)) and S.on_altar(S.altar_top()) and S.on_altar(S.ALTAR), "standing on the altar counts at the court's height")
	# Where the fallen come back: on the floor of their camp.
	for inside in [false, true]:
		for i in [0, 9, 19]:
			var p := GuildWarMatch.spawn_slot(1, i, 20, inside)
			check(is_equal_approx(p.y, S.floor_y(p) + 0.3), "a fighter comes back standing on its camp's floor (inside %s, %d: %s)" % [inside, i, p])
	check(is_equal_approx(GuildWarMatch.hero_camp().y, 0.3), "the hero comes back on the field")


func _open_war() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _walks() -> void:
	var S := SiegeArena
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.front_gate() == null, "the war opens with the gates down")
	if m == null:
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	for i in 6:
		await get_tree().process_frame
	for f in m.all_fighters():
		f.set_physics_process(false)
		f.global_position = f.spawn_point + Vector3(0, 0.3, 0)
	m.set_process(false)
	m.set_physics_process(false)
	var lift := zone.get_node_or_null("SiegeLift") as SiegeLift
	check(lift != null, "the siege zone has its lift")
	# The altar's crystal, the barrier and the switch pads stand on the court.
	for node_name in ["AltarCrystal", "AltarBarrier", "CastleSwitch", "CastleSwitchRight"]:
		var node := zone.find_child(node_name, true, false) as Node3D
		check(node != null and is_equal_approx(node.global_position.y, S.COURT_H), "%s stands on the raised court" % node_name)
	# The hero walks north from the third gate: up the stairs, over the court, onto the altar.
	zone.camera_rig.set_yaw_behind(0.0)
	hero.global_position = S.gate_front(2) + Vector3(0, 0.3, 0)
	hero.velocity = Vector3.ZERO
	await _frames(20)
	check(absf(hero.global_position.y) < 0.2 and hero.is_on_floor(), "the hero stands on the ground before the third gate (y %.2f)" % hero.global_position.y)
	hero.move_input = Vector2(0, -1)
	var on_stairs := false
	var worst_sink := 0.0
	var ticks := 0
	while ticks < 1500 and not S.on_altar(hero.global_position):
		await get_tree().physics_frame
		ticks += 1
		var p := hero.global_position
		var floor_at := S.floor_y(p)
		worst_sink = maxf(worst_sink, floor_at - p.y)
		if floor_at > 1.0 and floor_at < S.COURT_H - 1.0 and absf(p.y - floor_at) < 0.3:
			on_stairs = true
	hero.move_input = Vector2.ZERO
	await _frames(30)
	check(on_stairs, "the hero climbed the stairs on their slope")
	check(S.on_altar(hero.global_position), "the hero walking north from the third gate reaches the altar (%s after %d ticks)" % [hero.global_position, ticks])
	check(absf(hero.global_position.y - S.COURT_H) < 0.2 and hero.is_on_floor(), "the hero stands on the altar at the court's height (y %.2f)" % hero.global_position.y)
	check(worst_sink < 0.3, "the hero never sank under the floor on the way (%.2f)" % worst_sink)
	# A body on the court does not fall through (two seconds of standing still).
	var stood := hero.global_position.y
	await _frames(120)
	check(absf(hero.global_position.y - stood) < 0.05 and hero.is_on_floor(), "a body standing on the court stays on it (%.2f -> %.2f)" % [stood, hero.global_position.y])
	# Put under the floor (a move to a spot at the field's height): set back on the floor.
	var before := lift.rescued
	hero.global_position = Vector3(6.0, 0.3, S.ALTAR.z + 8.0)
	hero.velocity = Vector3.ZERO
	await _frames(10)
	check(lift.rescued > before and absf(hero.global_position.y - S.COURT_H) < 0.3, "a body put under the court's floor is set on it (y %.2f)" % hero.global_position.y)
	hero.global_position = Vector3(-8.0, 0.2, (S.STAIR_Z0 + S.STAIR_Z1) * 0.5)
	hero.velocity = Vector3.ZERO
	await _frames(20)
	var stair_floor := S.floor_y(hero.global_position)
	check(absf(hero.global_position.y - stair_floor) < 0.3 and hero.is_on_floor(), "a body put inside the stairs is set on them (y %.2f, floor %.2f)" % [hero.global_position.y, stair_floor])
	hero.global_position = GuildWarMatch.hero_camp()
	hero.set_physics_process(false)
	# A guild fighter sent to take the altar finds its own way from the second yard.
	var f: GuildFighter = m.enemies[0]
	f.dismount()
	f.global_position = S.KEEP_CAMP + Vector3(3.0, 0.3, 4.0)
	f.velocity = Vector3.ZERO
	f._frozen = false
	f.capture_role = true
	f.set_physics_process(true)
	ticks = 0
	var still := 0
	var stuck_max := 0
	var was := f.global_position
	var f_stairs := false
	while ticks < 2400 and not S.on_altar(f.global_position):
		await get_tree().physics_frame
		ticks += 1
		var p := f.global_position
		still = still + 1 if _flat(p, was) < 0.01 else 0
		stuck_max = maxi(stuck_max, still)
		was = p
		var floor_at := S.floor_y(p)
		if floor_at > 1.0 and floor_at < S.COURT_H - 1.0 and absf(p.y - floor_at) < 0.35:
			f_stairs = true
	await _frames(30)
	check(S.on_altar(f.global_position), "a fighter sent to the altar reaches it up the stairs (%s after %d ticks)" % [f.global_position, ticks])
	check(f_stairs, "the fighter climbed the stairs on their slope")
	check(absf(f.global_position.y - S.COURT_H) < 0.25, "the fighter stands on the altar at the court's height (y %.2f)" % f.global_position.y)
	check(stuck_max < 45, "the fighter was never stuck on the way (longest stand %d ticks)" % stuck_max)
	f.capture_role = false
	f.set_physics_process(false)
	# Effects: one drawn for flat ground over the court is lifted, one at a real height is not.
	var ground_fx := Node3D.new()
	zone.add_child(ground_fx)
	ground_fx.global_position = Vector3(5.0, 0.06, S.ALTAR.z + 6.0)
	var real_fx := Node3D.new()
	zone.add_child(real_fx)
	real_fx.global_position = Vector3(-5.0, S.COURT_H + 1.2, S.ALTAR.z + 6.0)
	var field_fx := Node3D.new()
	zone.add_child(field_fx)
	field_fx.global_position = Vector3(0.0, 0.06, S.PLAZA.z)
	lift.settle()
	check(is_equal_approx(ground_fx.global_position.y, S.COURT_H + 0.06), "an effect drawn for flat ground is lifted onto the court (y %.2f)" % ground_fx.global_position.y)
	check(is_equal_approx(real_fx.global_position.y, S.COURT_H + 1.2), "an effect at a body's real height stays where it is (y %.2f)" % real_fx.global_position.y)
	check(is_equal_approx(field_fx.global_position.y, 0.06), "an effect on the field is not touched")
	lift.settle()
	check(is_equal_approx(ground_fx.global_position.y, S.COURT_H + 0.06), "a lifted effect is not lifted twice")
	# Moved by its maker (a tween writes flat-ground heights each frame): lifted each time.
	ground_fx.global_position = Vector3(5.0, 0.5, S.ALTAR.z + 6.0)
	lift.settle()
	check(is_equal_approx(ground_fx.global_position.y, S.COURT_H + 0.5), "an effect moved by its maker keeps to the court's floor (y %.2f)" % ground_fx.global_position.y)
	VfxKit.danger_circle(zone, Vector3(8.0, 0.0, S.ALTAR.z + 4.0), 3.0, 0.5)
	lift.settle()
	var raised := 0
	for child in zone.get_children():
		if child is MeshInstance3D and _flat((child as Node3D).global_position, Vector3(8.0, 0, S.ALTAR.z + 4.0)) < 0.01 and (child as Node3D).global_position.y > S.COURT_H:
			raised += 1
	check(raised >= 2, "a skill's danger circle on the court is drawn on its floor (%d pieces)" % raised)
	zone.queue_free()
	for i in 4:
		await get_tree().process_frame
