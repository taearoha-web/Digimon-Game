class_name StarRegionArt
extends RefCounted
## Four authored star-region compositions. Repeated shapes are original finite
## cached meshes, grouped into MultiMeshes (not hundreds of MeshInstance nodes).
## The entire playable disk is continuous at y=0. Islands, terraces and deep
## water are scenic silhouettes outside the play boundary. Interior streams
## are shallow fords, and all tall interior props respect paths/encounters.

const SHADER := preload("res://shaders/star_environment.gdshader")
const IDS := [&"dawn_forest", &"crystal_valley", &"sky_citadel", &"eclipse_realm"]
const RADIUS := 55.5
const SEEDS := [4317, 7361, 9773, 12109]
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func layout(zone_id: StringName) -> Dictionary:
	match zone_id:
		&"dawn_forest":
			return {"spawn": Vector3(-43, 0, 24), "boss_pos": Vector3(28, 0, -25), "exit": Vector3(43, 0, -21),
				"camp_positions": [Vector2(-27, 14), Vector2(-12, -14), Vector2(11, 18), Vector2(29, 3)],
				"paths": [PackedVector2Array([Vector2(-46, 24), Vector2(-28, 22), Vector2(-7, 3), Vector2(13, 4), Vector2(28, -14), Vector2(45, -21)]),
					PackedVector2Array([Vector2(-12, -14), Vector2(-7, 3), Vector2(11, 18)]),
					PackedVector2Array([Vector2(13, 4), Vector2(29, 3)])]}
		&"crystal_valley":
			return {"spawn": Vector3(-42, 0, -26), "boss_pos": Vector3(27, 0, 26), "exit": Vector3(42, 0, 24),
				"camp_positions": [Vector2(-24, -18), Vector2(-18, 14), Vector2(10, -14), Vector2(25, 8)],
				"paths": [PackedVector2Array([Vector2(-44, -27), Vector2(-24, -18), Vector2(-8, -2), Vector2(10, 2), Vector2(25, 8), Vector2(42, 24)]),
					PackedVector2Array([Vector2(-18, 14), Vector2(-8, -2), Vector2(10, -14)]),
					PackedVector2Array([Vector2(25, 8), Vector2(27, 26)])]}
		&"sky_citadel":
			return {"spawn": Vector3(0, 0, 43), "boss_pos": Vector3(0, 0, -30), "exit": Vector3(38, 0, -25),
				"camp_positions": [Vector2(-24, 18), Vector2(23, 17), Vector2(-23, -10), Vector2(24, -12)],
				"paths": [PackedVector2Array([Vector2(0, 47), Vector2(0, 23), Vector2(0, 0), Vector2(0, -30)]),
					PackedVector2Array([Vector2(-24, 18), Vector2(0, 23), Vector2(23, 17)]),
					PackedVector2Array([Vector2(-23, -10), Vector2(0, 0), Vector2(24, -12), Vector2(40, -25)])]}
		&"eclipse_realm":
			return {"spawn": Vector3(-42, 0, 30), "boss_pos": Vector3(25, 0, -24), "exit": Vector3(41, 0, -27),
				"camp_positions": [Vector2(-28, 15), Vector2(-21, -12), Vector2(0, 16), Vector2(17, -2)],
				"paths": [PackedVector2Array([Vector2(-44, 31), Vector2(-28, 15), Vector2(-9, 4), Vector2(17, -2), Vector2(25, -24), Vector2(43, -27)]),
					PackedVector2Array([Vector2(-21, -12), Vector2(-9, 4), Vector2(0, 16)])]}
	return {}


static func build(parent: Node3D, zone_id: StringName) -> void:
	var index := IDS.find(zone_id)
	if index < 0:
		return
	var root := Node3D.new()
	root.name = "StarRegionArt"
	root.set_meta("zone_id", zone_id)
	root.set_meta("flat_walkable_radius", RADIUS)
	root.set_meta("art_layout_version", 2)
	parent.add_child(root)
	var info := layout(zone_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEEDS[index]
	var context := {"root": root, "batches": {}, "rng": rng, "index": index, "layout": info, "colliders": []}
	_ground(root, index, info)
	match index:
		0: _dawn(context)
		1: _crystal_valley(context)
		2: _sky_citadel(context)
		3: _eclipse(context)
	_flush(context)
	_add_colliders(context)
	root.set_meta("no_dynamic_lights", true)
	root.set_meta("opaque_water_and_clouds", true)


static func _ground(parent: Node3D, region: int, info: Dictionary) -> void:
	var colors := [
		[Color("527d50"), Color("92ad67"), Color("c1b188")],
		[Color("73999b"), Color("b4cfcc"), Color("c4cbb9")],
		[Color("b5bdaf"), Color("e0dfc6"), Color("e8d5a7")],
		[Color("343d51"), Color("626172"), Color("8c8090")],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = SEEDS[region]
	noise.frequency = 0.065
	# Circular authored platform/landmass, six thousand triangles at most. All
	# vertices carry masks, so paths and gardens need no alpha decals.
	var rings := 35
	var sectors := 96
	for r in rings:
		for s in sectors:
			var points: Array[Vector3] = []
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radial := float(r + corner.x) / rings * RADIUS
				var angle := TAU * float(s + corner.y) / sectors
				points.append(Vector3(cos(angle) * radial, 0, sin(angle) * radial))
			for corner in [0, 2, 1, 0, 3, 2]:
				var p := points[corner]
				var xz := Vector2(p.x, p.z)
				var n := noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
				var col: Color = colors[region][0].lerp(colors[region][1], n)
				var path_mask := 1.0 - smoothstep(2.6, 4.1, _path_distance(xz, info.paths))
				var clearing := 0.0
				for camp in info.camp_positions:
					clearing = maxf(clearing, 1.0 - smoothstep(5.0, 10.0, xz.distance_to(camp)))
				col = col.lerp(colors[region][2], maxf(path_mask * 0.88, clearing * 0.34))
				if region == 1:
					var fault := absf(p.z - p.x * 0.56 - sin(p.x * 0.13) * 4.0)
					col = col.lerp(Color("426b79"), (1.0 - smoothstep(0.2, 1.1, fault)) * 0.48)
				elif region == 2:
					var garden := smoothstep(8.0, 12.0, absf(p.x)) * (1.0 - smoothstep(36.0, 41.0, xz.length()))
					col = col.lerp(Color("769789"), garden * (1.0 - path_mask) * (1.0 - clearing * 0.66))
					var annulus := 1.0 - smoothstep(0.22, 0.68, absf(xz.length() - 45.0))
					col = col.lerp(Color("b99c66"), annulus * 0.7)
				elif region == 3:
					var court := 1.0 - smoothstep(14.0, 20.0, xz.distance_to(Vector2(25, -24)))
					var check := fposmod(floor(p.x / 3.0) + floor(p.z / 3.0), 2.0)
					col = col.lerp(Color("6e637c").lerp(Color("afa0aa"), check * 0.43), court)
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.set_uv(xz * 0.1)
				st.add_vertex(p)
	if region != 2:
		# Connect the playable meadow/canyon/castle estate to a continuous
		# landscape. Only the sky kingdom has a visible island edge.
		var radii := [RADIUS, 65.0, 88.0, 120.0, 170.0]
		for ring in radii.size() - 1:
			for sector in 96:
				var corners: Array[Vector3] = []
				for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var radius: float = radii[ring + corner.x]
					var angle := TAU * float(sector + corner.y) / 96.0
					var xz := Vector2(cos(angle), sin(angle)) * radius
					var rise := maxf(radius - 64.0, 0.0) * 0.07
					var y := (noise.get_noise_2d(xz.x * 0.8, xz.y * 0.8) + 0.2) * rise
					corners.append(Vector3(xz.x, y, xz.y))
				var col: Color = colors[region][0].lerp(colors[region][1], 0.39 + float(ring) * 0.05)
				_triangle(st, corners[0], corners[2], corners[1], col, col, col)
				_triangle(st, corners[0], corners[3], corners[2], col, col, col)
	st.generate_normals()
	st.index()
	var floor := MeshInstance3D.new()
	floor.name = "AuthoredGround"
	floor.mesh = st.commit()
	floor.material_override = _material("terrain_%d" % region, 1, region)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor)
	var body := StaticBody3D.new()
	body.name = "StarGroundCollision"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RADIUS * 2, 1, RADIUS * 2)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	parent.add_child(body)


static func _dawn(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	# The world-tree is deliberately off-axis, forming an arching flowering
	# canopy above the northern horizon instead of a generic forest wall.
	_tree(c, Vector3(9, 0, -57), 27.0, Color("708d58"), Color("735b48"), true, false)
	for i in 9:
		var angle := float(i) * 0.64
		_put(c, "crown", Vector3(9 + cos(angle) * 13, 21 + sin(i * 1.9) * 2.0, -57 + sin(angle) * 10), Vector3(9.0, 5.1, 7.5), Color("f0c6b0").lerp(Color("efadae"), float(i % 3) * 0.19), Vector3(0, angle, 0), "foliage")
	for i in 5:
		var p := Vector3(-41 + i * 5.4, 0, -48 - sin(i * 0.8) * 3.0)
		_put(c, "rock", p + Vector3(0, 6.5, 0), Vector3(11, 15 + i % 2 * 4, 12), Color("69857b"), Vector3(0, i * 0.8, 0))
		_put(c, "crown", p + Vector3(0, 13, 0), Vector3(9, 3.5, 7), Color("8aa264"), Vector3.ZERO, "foliage")
	# Waterfall ribbon has actual vertical stream geometry and a calm pool;
	# opaque shader flow avoids stacked transparent sheets on mobile.
	_ribbon(c, [Vector3(-28, 14, -48), Vector3(-28, 10, -46), Vector3(-27, 5, -44), Vector3(-27, 0.04, -41), Vector3(-23, 0.025, -36), Vector3(-22, 0.025, -27), Vector3(-25, 0.025, -15), Vector3(-16, 0.025, -3), Vector3(-13, 0.025, 9), Vector3(-16, 0.025, 25), Vector3(-7, 0.025, 43), Vector3(0, 0.025, 59), Vector3(14, 0.04, 68)], 3.0, Color("64a9a0"), "RiverOfDawn", "water")
	_pool(c, Vector3(-26, 0.018, -39), Vector2(8.2, 6.0), Color("47928d"), "SpringPool")
	_stepping_stones(c, Vector3(-15.5, 0.026, 10), 4, 1.2, 1.2)
	for i in 30:
		var angle := TAU * float(i) / 30.0
		var p := Vector3(cos(angle) * rng.randf_range(51, 66), 0, sin(angle) * rng.randf_range(51, 66))
		if p.z < -43 or p.x < -46 and p.z < -12:
			continue
		_tree(c, p, rng.randf_range(7.5, 12.0), Color("4b7752").lerp(Color("9dad66"), rng.randf()), Color("705849"), i % 5 == 0, false)
	for i in 34:
		var p := _free_spot(c, 2.3)
		if p == Vector3.INF:
			continue
		if i < 10:
			_tree(c, p, rng.randf_range(4.5, 6.6), Color("8ba95d").lerp(Color("e5b2ab"), 0.75 if i % 3 == 0 else 0.0), Color("795e4b"), i % 3 == 0, true)
		else:
			_fern(c, p, rng.randf_range(0.7, 1.6), Color("5e9160"))
	_flower_meadows(c, Color("f1d6b2"), Color("edb2b5"), 120)
	# Half-buried roots and small mushroom gardens create close foreground
	# detail without cluttering the encounter footprints.
	for i in 15:
		var p := _free_spot(c, 0.6)
		if p != Vector3.INF:
			_put(c, "mushroom", p, Vector3.ONE * rng.randf_range(0.4, 0.7), Color("dca17b"), Vector3(0, rng.randf() * TAU, 0))
	_distant_hills(c, Color("739394"), Color("a6bbad"), 18.0)


static func _crystal_valley(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	# Asymmetric strata create an actual canyon silhouette: long shelves and
	# vertical organ-like formations instead of snowy cones around a field.
	for side in [-1.0, 1.0]:
		for i in 7:
			var z := -49.0 + i * 16.0
			var p := Vector3(side * (58 + sin(i * 0.85) * 8), 0, z)
			for shelf in 3:
				var scale := Vector3(18 - shelf * 3.0, 4.4, 17 - shelf * 2.0)
				_put(c, "rock", p + Vector3(side * shelf * 2, 2 + shelf * 4.0, 0), scale, Color("7897a2").lerp(Color("d0d9d3"), shelf * 0.24), Vector3(0, 0.4 * side, 0))
			_crystal_group(c, p + Vector3(0, 10.5, 0), rng.randf_range(6.0, 11.0), false)
	# Far stone arch frames the blue sky, with an open void below the lintel.
	_arch(c, Vector3(-6, 0, -56), 31.0, 17.5, 5.0, Color("a8babf"), 0.08)
	for i in 8:
		_crystal_group(c, Vector3(-23 + i * 5, 0, -51 + sin(i * 0.7) * 2), rng.randf_range(3.0, 6.0), false)
	_pool(c, Vector3(-1, 0.018, 30), Vector2(14, 8), Color("568f9c"), "GlacialMirror")
	_pool(c, Vector3(30, 0.017, -28), Vector2(11, 8), Color("549eaa"), "JadePool")
	_ribbon(c, [Vector3(-56, 0.012, -2), Vector3(-39, 0.016, 3), Vector3(-27, 0.018, 5), Vector3(-9, 0.015, 18), Vector3(-1, 0.016, 30), Vector3(7, 0.018, 45), Vector3(18, -0.08, 58)], 2.2, Color("73b6bd"), "GlacialRun", "water")
	_stepping_stones(c, Vector3(-13, 0.027, 16), 6, 1.35, -0.7)
	for i in 26:
		var p := _free_spot(c, 2.4)
		if p != Vector3.INF:
			_crystal_group(c, p, rng.randf_range(1.5, 3.6), true)
	for i in 18:
		var p := _free_spot(c, 0.8)
		if p != Vector3.INF:
			_put(c, "rock", p + Vector3(0, 0.2, 0), Vector3(2.2, 0.65, 1.5), Color("b6cec9"), Vector3(0, rng.randf() * TAU, 0))
	_flower_meadows(c, Color("c7e5df"), Color("8dbbc7"), 50)
	_distant_hills(c, Color("6a97af"), Color("bccbd4"), 31.0)


static func _sky_citadel(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var cream := Color("d4d2b8")
	var gold := Color("bfa26e")
	var blue := Color("698f9f")
	# A connected floating garden island: the rock undercut and broken hanging
	# strata make the abyss real while preserving a continuous playable top.
	_island_underside(c, Vector3(0, -8.5, 0), Vector3(113, 17, 113), Color("859797"))
	for i in 18:
		var angle := TAU * float(i) / 18.0
		var height := 17 + i % 4 * 2.0
		var p := Vector3(cos(angle) * 52.0, -height * 0.5 - 0.25, sin(angle) * 52.0)
		_put(c, "crystal", p, Vector3(6.0, height, 6.0), Color("a0b6ac"), Vector3(PI, angle, 0))
	for i in 48:
		var angle := TAU * float(i) / 48.0
		if absf(wrapf(angle - PI * 0.5, -PI, PI)) < 0.14 or absf(wrapf(angle + 0.56, -PI, PI)) < 0.13:
			continue
		var p := Vector3(cos(angle) * 51.5, 0.18, sin(angle) * 51.5)
		_put(c, "box", p, Vector3(5.6, 0.35, 1.25), cream, Vector3(0, -angle + PI * 0.5, 0))
		if i % 2 == 0:
			_column(c, p + Vector3(0, 0, 0), 1.9, 0.38, cream, gold)
	# Roofed palace and colonnade: recognisable architectural masses beyond
	# the boss court, not an assortment of disconnected ruined columns.
	_palace(c, Vector3(0, 0, -59), 1.0, cream, gold, blue)
	for side in [-1.0, 1.0]:
		for i in 5:
			var p := Vector3(side * (13 + i * 6.4), 0, -43 - sin(i * 0.4) * 4)
			_column(c, p, 7.0, 0.8, cream, gold)
			_put(c, "box", p + Vector3(side * 2.8, 7.2, 0), Vector3(6.5, 0.8, 1.5), cream, Vector3(0, side * 0.04, 0))
	# Four parterre pockets each use a different arrangement. No tall hedge
	# blocks the crossroads or the four encounter circles.
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			var center := Vector3(side * 33, 0, depth * 27)
			for i in 7:
				var angle := PI * 0.13 + i * PI / 7.0 + (PI if side < 0 else 0.0)
				_put(c, "crown", center + Vector3(cos(angle) * 7, 0.55, sin(angle) * 6), Vector3(3, 1.2, 2.4), Color("709984"), Vector3(0, angle, 0), "foliage")
			for i in 3:
				var p := center + Vector3(side * (i - 1) * 3.0, 0, depth * 6.5)
				if _is_clear(c, p, 1.3):
					_cypress(c, p, 5.0 + float(i % 2), Color("6b9b8d"), true)
	_pool(c, Vector3(-9.5, 0.018, -22), Vector2(3.3, 7.2), Color("7bb8bf"), "PalaceReflectingPool")
	_pool(c, Vector3(9.5, 0.018, -22), Vector2(3.3, 7.2), Color("7bb8bf"), "PalaceReflectingPoolEast")
	# Standalone astrolabe island, and a suspended waterfall garden opposite.
	_sky_island(c, Vector3(74, -2, 4), Vector3(21, 12, 21), cream)
	_ring(c, Vector3(74, 14, 4), 8.4, 0.5, gold, Vector3(PI * 0.5, 0.1, 0.4))
	_ring(c, Vector3(74, 14, 4), 6.2, 0.4, gold, Vector3(0.4, 0.6, 0.0))
	_put(c, "crystal", Vector3(74, 13, 4), Vector3(3.2, 7, 3.2), Color("b7d8d0"), Vector3.ZERO, "glow")
	_sky_island(c, Vector3(-72, -4, -14), Vector3(25, 16, 26), cream)
	_tree(c, Vector3(-72, -3, -14), 14, Color("e3cab9"), Color("8b8975"), true, false)
	_ribbon(c, [Vector3(-72, -3, -5), Vector3(-72, -9, -2), Vector3(-70, -25, 1), Vector3(-68, -40, 1)], 3.0, Color("afd3d0"), "HangingGardenWaterfall", "water")
	for i in 7:
		var angle := 0.3 + i * TAU / 7.0
		var distance := 94.0 + i % 3 * 15.0
		var p := Vector3(cos(angle) * distance, -10 - i % 2 * 9, sin(angle) * distance)
		_sky_island(c, p, Vector3(13 + i % 3 * 4, 17, 15 + i % 2 * 4), cream)
		_column(c, p + Vector3(0, 1, 0), 8.0, 1.0, cream, gold)
	for i in 16:
		var angle := float(i) * TAU / 16.0
		_put(c, "cloud", Vector3(cos(angle) * rng.randf_range(76, 130), -13 - i % 4 * 3, sin(angle) * rng.randf_range(76, 130)), Vector3(25 + i % 3 * 9, 6.0, 18.0), Color("dbe5dc").lerp(Color("b6cbd2"), float(i % 3) * 0.1))
	_flower_meadows(c, Color("e5ceb7"), Color("d9c9de"), 100)


static func _eclipse(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var stone := Color("686479")
	var edge := Color("a090a2")
	# A wooded approach gradually gives way to a real diagonal castle court.
	# The huge broken gate, layered curtain walls and unequal towers provide
	# silhouettes absent from the original graveyard/dark forest maps.
	for i in 31:
		var angle := 0.35 + float(i) / 30.0 * 4.1
		var p := Vector3(cos(angle) * rng.randf_range(49, 67), 0, sin(angle) * rng.randf_range(49, 67))
		_tree(c, p, rng.randf_range(8, 13), Color("485972").lerp(Color("857493"), rng.randf() * 0.55), Color("4c475b"), false, false, true)
	for i in 13:
		var p := _free_spot(c, 2.0)
		if p != Vector3.INF and p.x + p.z < 3:
			_tree(c, p, rng.randf_range(5.0, 7.5), Color("67748e"), Color("534e61"), false, true, true)
	for i in 5:
		var p := Vector3(5 + i * 12, 0, -56 + i * 2.0)
		_castle_tower(c, p, 11 + i % 3 * 4, 3.4 if i % 2 else 4.3, stone, edge, i == 2)
		if i < 4:
			_put(c, "box", p + Vector3(6, 4.5, 1), Vector3(12, 9, 3.0), stone)
			for j in 4:
				_put(c, "box", p + Vector3(2.0 + j * 2.7, 9.5, 1), Vector3(1.5, 1.2, 3.3), edge)
	_arch(c, Vector3(25, 0, -44), 19.0, 16.0, 3.6, edge, 0)
	for side in [-1.0, 1.0]:
		var p := Vector3(25 + side * 10, 0, -43)
		_castle_tower(c, p, 13.0, 2.5, stone, edge, side < 0)
		_put(c, "crystal", p + Vector3(0, 15, 0), Vector3(3.8, 5.0, 3.8), Color("afa6bb"), Vector3.ZERO)
	# Court border is low and broken at the approach and exit; no walls cover
	# the boss or stop movement across the playable encounter disk.
	for i in 20:
		var angle := float(i) * TAU / 20.0
		if i in [0, 1, 7, 8, 9, 10]:
			continue
		var p := Vector3(25 + cos(angle) * 17, 0.16, -24 + sin(angle) * 15)
		_put(c, "box", p, Vector3(4.3, 0.3, 0.9), edge, Vector3(0, -angle + PI * 0.5, 0))
	_pool(c, Vector3(-5, 0.018, -31), Vector2(10.0, 6.0), Color("414f73"), "MoonMirror")
	for i in 8:
		var angle := TAU * i / 8.0
		_put(c, "crystal", Vector3(-5 + cos(angle) * 8, 0.5, -31 + sin(angle) * 5), Vector3(0.7, 1.4, 0.7), Color("bca4dc"), Vector3(0, angle, 0), "glow")
	# The eclipse is a fixed scenic body beyond the castle, never a screen
	# overlay, light or camera effect. Gold rim and dark center are opaque.
	_put(c, "disc", Vector3(24, 48, -114), Vector3(24, 1, 24), Color("cbb3a4"), Vector3(PI * 0.5, 0, 0), "glow")
	_put(c, "disc", Vector3(25, 48.7, -113.7), Vector3(22.6, 1, 22.6), Color("39364f"), Vector3(PI * 0.5, 0, 0), "unlit")
	for i in 22:
		var p := _free_spot(c, 0.7)
		if p != Vector3.INF:
			if i % 3 == 0:
				_put(c, "rock", p + Vector3(0, 0.3, 0), Vector3(1.7, 1.2, 2.0), Color("68677f"), Vector3(0, rng.randf() * TAU, 0))
			else:
				_fern(c, p, 1.1, Color("7f849d"))
	_flower_meadows(c, Color("b4a9d6"), Color("89bcc0"), 95)
	_distant_hills(c, Color("47526c"), Color("7a7d91"), 25.0)


static func _tree(c: Dictionary, position: Vector3, height: float, leaf: Color, bark: Color,
		flowering := false, collision := false, willow := false) -> void:
	# A clear trunk footprint is insufficient for the field camera: its
	# western viewpoint can project a tall foreground canopy across the hero.
	# Check the complete crown silhouette at both supported pitch extremes,
	# including perimeter trees, before adding any batched parts.
	var original_height := height
	for attempt in 3:
		if _canopy_camera_clear(c, position, height):
			break
		height *= 0.64
	if height < 2.5 or not _canopy_camera_clear(c, position, height):
		return
	if height < original_height:
		c.root.set_meta("camera_trimmed_trees", int(c.root.get_meta("camera_trimmed_trees", 0)) + 1)
	var rng: RandomNumberGenerator = c.rng
	var yaw := rng.randf() * TAU
	_put(c, "trunk", position, Vector3(height * 0.4, height, height * 0.4), bark, Vector3(0, yaw, 0))
	var crown_scale := Vector3(height * 0.98, height * (0.32 if willow else 0.43), height * 0.9)
	_put(c, "crown", position + Vector3(0, height * 0.72, 0), crown_scale, leaf, Vector3(0, yaw, 0), "foliage")
	_put(c, "crown", position + Vector3(height * 0.18, height * 0.58, height * 0.15), crown_scale * 0.58, leaf.darkened(0.08), Vector3(0, yaw + 1.0, 0), "foliage")
	if flowering:
		for i in 5:
			var angle := i * TAU / 5.0 + yaw
			_put(c, "crown", position + Vector3(cos(angle) * height * 0.25, height * 0.87, sin(angle) * height * 0.21), Vector3(height * 0.28, height * 0.14, height * 0.25), leaf.lightened(0.16), Vector3(0, angle, 0), "foliage")
	if willow:
		for i in 6:
			var angle := i * TAU / 6.0 + yaw
			_put(c, "willow_frond", position + Vector3(cos(angle) * height * 0.33, height * 0.49, sin(angle) * height * 0.29), Vector3(height * 0.19, height * 0.42, height * 0.14), leaf.darkened(0.10), Vector3(0.08, angle, 0.14), "foliage")
	if collision:
		c.colliders.append(Vector3(position.x, position.z, height * 0.075))


static func _canopy_camera_clear(c: Dictionary, p: Vector3, height: float) -> bool:
	var info: Dictionary = c.layout
	var footprint := Vector2(p.x, p.z)
	# At entrances the player may immediately rotate the camera. Preserve a
	# full circle for every yaw, not only the default western viewpoint.
	for field in ["spawn", "exit"]:
		var anchor: Vector3 = info[field]
		var circle := height * 1.50 + 3.8
		if footprint.distance_to(Vector2(anchor.x, anchor.z)) < circle:
			return false
	for pitch in [38.0, 47.0, 56.0]:
		var projected := footprint + Vector2(maxf(height * 0.70 - 0.9, 0.0) / tan(deg_to_rad(pitch)), 0)
		# Include the canopy's lateral span and its projected vertical span.
		var silhouette := height * 0.78
		if _path_distance(projected, info.paths) < silhouette + 3.4:
			return false
		for camp in info.camp_positions:
			if projected.distance_to(camp) < silhouette + 9.5:
				return false
		var boss: Vector3 = info.boss_pos
		if projected.distance_to(Vector2(boss.x, boss.z)) < silhouette + 10.0:
			return false
	return true


static func _cypress(c: Dictionary, p: Vector3, height: float, col: Color, collision := false) -> void:
	_put(c, "trunk", p, Vector3(height * 0.15, height * 0.6, height * 0.15), Color("96927b"))
	for i in 3:
		_put(c, "crown", p + Vector3(0, height * (0.4 + i * 0.17), 0), Vector3(height * (0.38 - i * 0.06), height * 0.45, height * (0.36 - i * 0.06)), col.lightened(i * 0.035), Vector3(0, i * 0.7, 0), "foliage")
	if collision:
		c.colliders.append(Vector3(p.x, p.z, 0.35))


static func _fern(c: Dictionary, p: Vector3, size: float, col: Color) -> void:
	_put(c, "fern", p, Vector3.ONE * size, col, Vector3(0, c.rng.randf() * TAU, 0), "foliage")


static func _crystal_group(c: Dictionary, p: Vector3, height: float, collision: bool) -> void:
	var rng: RandomNumberGenerator = c.rng
	for i in 5:
		var angle := i * TAU / 5.0
		var h := height * (1.0 if i == 0 else rng.randf_range(0.38, 0.73))
		var position := p + Vector3(cos(angle) * height * 0.21, h * 0.46, sin(angle) * height * 0.21)
		_put(c, "crystal", position, Vector3(h * 0.36, h, h * 0.36), Color("81bdc9").lerp(Color("cadbd2"), float(i) * 0.14), Vector3(0.10 if i else 0.0, angle, 0.1 if i else 0.0), "mineral")
	if collision:
		c.colliders.append(Vector3(p.x, p.z, height * 0.27))


static func _flower_meadows(c: Dictionary, first: Color, second: Color, maximum: int) -> void:
	var rng: RandomNumberGenerator = c.rng
	var count := int(maximum * (0.6 if GameSettings.quality == 0 else 1.0))
	for i in count:
		var p := _free_spot(c, 0.12, true)
		if p == Vector3.INF:
			continue
		var size := rng.randf_range(0.26, 0.48)
		_put(c, "flower", p, Vector3.ONE * size, first if i % 2 == 0 else second, Vector3(0, rng.randf() * TAU, 0), "foliage")
		if i % 3 == 0:
			_put(c, "fern", p + Vector3(0.4, 0, 0.2), Vector3.ONE * size * 1.3, Color("679080").lerp(Color("858899"), float(c.index) / 4.0), Vector3(0, rng.randf() * TAU, 0), "foliage")


static func _arch(c: Dictionary, p: Vector3, width: float, height: float, depth: float, col: Color, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for i in 12:
		var angle := PI * float(i) / 11.0
		var offset := Vector3(cos(angle) * width * 0.5, height * 0.52 + sin(angle) * height * 0.48, 0)
		_put(c, "box", p + basis * offset, Vector3(width * 0.155, height * 0.16, depth), col.lightened((i % 3) * 0.025), Vector3(0, yaw, angle - PI * 0.5))
	for side in [-1.0, 1.0]:
		_put(c, "box", p + basis * Vector3(side * width * 0.5, height * 0.26, 0), Vector3(width * 0.16, height * 0.53, depth * 1.2), col)


static func _column(c: Dictionary, p: Vector3, height: float, radius: float, col: Color, trim: Color) -> void:
	_put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(radius * 2, height, radius * 2), col)
	_put(c, "box", p + Vector3(0, 0.24, 0), Vector3(radius * 3.5, 0.48, radius * 3.5), col)
	_put(c, "box", p + Vector3(0, height, 0), Vector3(radius * 3.0, 0.5, radius * 3.0), trim)


static func _palace(c: Dictionary, p: Vector3, size: float, col: Color, trim: Color, roof: Color) -> void:
	for side in [-1.0, 0.0, 1.0]:
		var center := p + Vector3(side * 15 * size, 0, absf(side) * 5 * size)
		var height := (15.0 if side == 0 else 10.5) * size
		_put(c, "box", center + Vector3(0, height * 0.5, 0), Vector3(13 * size, height, 12 * size), col)
		_put(c, "roof", center + Vector3(0, height + 3 * size, 0), Vector3(16 * size, 6 * size, 15 * size), roof)
		_put(c, "box", center + Vector3(0, height, 0), Vector3(15 * size, 0.7 * size, 14 * size), trim)
		for x in [-4.3, 0.0, 4.3]:
			_column(c, center + Vector3(x * size, 0, 7 * size), height * 0.84, 0.64 * size, col, trim)
			_put(c, "box", center + Vector3(x * size, height * 0.55, 6.05 * size), Vector3(2.2 * size, height * 0.45, 0.12), Color("7a9f9e"))
		_put(c, "crystal", center + Vector3(0, height + 6 * size, 0), Vector3(1.2, 3.2, 1.2) * size, trim)


static func _castle_tower(c: Dictionary, p: Vector3, height: float, radius: float, col: Color, trim: Color, broken: bool) -> void:
	_put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(radius * 2, height, radius * 2), col)
	_put(c, "pillar", p + Vector3(0, height - 0.7, 0), Vector3(radius * 2.4, 0.6, radius * 2.4), trim)
	for i in 9:
		if broken and i in [2, 3, 4]:
			continue
		var angle := i * TAU / 9.0
		_put(c, "box", p + Vector3(cos(angle) * radius, height + 0.4, sin(angle) * radius), Vector3(radius * 0.62, 1.6, radius * 0.65), trim, Vector3(0, -angle, 0))
	for level in 3:
		_put(c, "box", p + Vector3(0, 3.0 + level * 3.2, radius + 0.03), Vector3(0.7, 1.8, 0.1), Color("363749"))
	if not broken:
		_put(c, "roof", p + Vector3(0, height + 3, 0), Vector3(radius * 2.9, 5, radius * 2.9), Color("575975"))


static func _sky_island(c: Dictionary, p: Vector3, size: Vector3, col: Color) -> void:
	_island_underside(c, p - Vector3(0, size.y * 0.5, 0), size, Color("879aa0"))
	_put(c, "disc", p + Vector3(0, 0.08, 0), Vector3(size.x, 1, size.z), col)


static func _island_underside(c: Dictionary, p: Vector3, size: Vector3, col: Color) -> void:
	_put(c, "island", p, size, col)


static func _distant_hills(c: Dictionary, front: Color, back: Color, height: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEEDS[int(c.index)] + 51
	noise.frequency = 0.027
	for layer in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in 6:
			for sector in 96:
				var corners: Array[Vector3] = []
				var colors: Array[Color] = []
				for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var t := float(ring + corner.x) / 6.0
					var angle := float(sector + corner.y) * TAU / 96.0
					var radius := 66.0 + layer * 38.0 + t * 69.0
					var direction := Vector2(cos(angle), sin(angle))
					var n := noise.get_noise_2d(direction.x * radius, direction.y * radius)
					var groups := 0.48 + pow(maxf(0.0, sin(angle * 3.0 + layer * 1.3)), 1.5) * 0.64
					var profile := pow(sin(t * PI), 1.3)
					var y := profile * height * groups * (0.76 + n * 0.72 + layer * 0.32) - 1.3
					corners.append(Vector3(direction.x * radius, y, direction.y * radius))
					var tint := front if layer == 0 else back
					colors.append(tint.darkened((1.0 - t) * 0.08 + n * 0.10))
				_triangle(st, corners[0], corners[2], corners[1], colors[0], colors[2], colors[1])
				_triangle(st, corners[0], corners[3], corners[2], colors[0], colors[3], colors[2])
		_mesh_node(c.root, st, _material("solid"), "ContinuousRidge_%d" % layer)


static func _stepping_stones(c: Dictionary, p: Vector3, count: int, spacing: float, yaw: float) -> void:
	for i in count:
		var offset := Basis(Vector3.UP, yaw) * Vector3((i - (count - 1) * 0.5) * spacing, 0, sin(i * 2.0) * 0.2)
		_put(c, "rock", p + offset, Vector3(1.3, 0.045, 1.1), Color("b9c4b0"), Vector3(0, yaw + i * 0.2, 0))


static func _pool(c: Dictionary, p: Vector3, size: Vector2, col: Color, label: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a := float(i) * TAU / 48.0
		var b := float(i + 1) * TAU / 48.0
		var pa := p + Vector3(cos(a) * size.x * (1.0 + sin(a * 5) * 0.045), 0, sin(a) * size.y)
		var pb := p + Vector3(cos(b) * size.x * (1.0 + sin(b * 5) * 0.045), 0, sin(b) * size.y)
		_triangle(st, p, pb, pa, col, col.lightened(0.11), col.lightened(0.11))
	_mesh_node(c.root, st, _material("water", 2), label)
	for i in 14:
		var angle := float(i) * TAU / 14.0
		var pos := p + Vector3(cos(angle) * size.x * 1.03, 0, sin(angle) * size.y * 1.05)
		if _is_clear(c, pos, 0.2):
			_put(c, "rock", pos, Vector3(1.8, 0.28, 1.2), Color("93a6a0"), Vector3(0, angle, 0))


static func _ribbon(c: Dictionary, points: Array, width: float, col: Color, label: String, role: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in points.size():
		var previous: Vector3 = points[maxi(0, i - 1)]
		var following: Vector3 = points[mini(points.size() - 1, i + 1)]
		var delta := Vector3(following.x - previous.x, 0, following.z - previous.z).normalized()
		if delta.length_squared() < 0.01:
			delta = Vector3.FORWARD
		var tangent := Vector3(-delta.z, 0, delta.x) * width * 0.5
		left.append(points[i] - tangent)
		right.append(points[i] + tangent)
	for i in points.size() - 1:
		_triangle(st, left[i], right[i + 1], left[i + 1], col.lightened(0.08), col, col)
		_triangle(st, left[i], right[i], right[i + 1], col.lightened(0.08), col.lightened(0.08), col)
	_mesh_node(c.root, st, _material(role, 2), label)


static func _ring(c: Dictionary, p: Vector3, radius: float, thickness: float, color: Color, rotation: Vector3) -> void:
	var basis := Basis.from_euler(rotation)
	for i in 32:
		var a := float(i) * TAU / 32.0
		var b := float(i + 1) * TAU / 32.0
		var from := p + basis * Vector3(cos(a) * radius, 0, sin(a) * radius)
		var to := p + basis * Vector3(cos(b) * radius, 0, sin(b) * radius)
		_segment(c, from, to, thickness, color)


static func _segment(c: Dictionary, a: Vector3, b: Vector3, radius: float, col: Color) -> void:
	var delta := b - a
	var up := delta.normalized()
	var right := up.cross(Vector3.FORWARD).normalized()
	if right.length_squared() < 0.1:
		right = up.cross(Vector3.RIGHT).normalized()
	var basis := Basis(right * radius, up * delta.length(), right.cross(up) * radius)
	_queue(c, "pillar", Transform3D(basis, (a + b) * 0.5), col, "solid")


static func _free_spot(c: Dictionary, radius: float, low := false) -> Vector3:
	var rng: RandomNumberGenerator = c.rng
	for attempt in 20:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * 47.0
		var p := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		if _is_clear(c, p, radius, low):
			return p
	return Vector3.INF


static func _is_clear(c: Dictionary, p: Vector3, radius: float, low := false) -> bool:
	var info: Dictionary = c.layout
	var xz := Vector2(p.x, p.z)
	# Shoreline planting belongs alongside water, never through a ford or a
	# reflecting pool. Keep the cross-map streams open for actors as well.
	if int(c.index) == 0:
		var river := [PackedVector2Array([Vector2(-27, -41), Vector2(-23, -36), Vector2(-22, -27), Vector2(-25, -15), Vector2(-16, -3), Vector2(-13, 9), Vector2(-16, 25), Vector2(-7, 43)])]
		if _path_distance(xz, river) < radius + 2.1:
			return false
	elif int(c.index) == 1:
		if ((xz - Vector2(-1, 30)) / Vector2(15, 9)).length() < 1.0 or ((xz - Vector2(30, -28)) / Vector2(12, 9)).length() < 1.0:
			return false
	elif int(c.index) == 2:
		if absf(absf(p.x) - 9.5) < 4.3 + radius and absf(p.z + 22) < 8.2 + radius:
			return false
	elif ((xz - Vector2(-5, -31)) / Vector2(11, 7)).length() < 1.0:
		return false
	if _path_distance(xz, info.paths) < radius + (1.9 if low else 4.1):
		return false
	for camp in info.camp_positions:
		if xz.distance_to(camp) < radius + (5.7 if low else 11.5):
			return false
	for field in ["spawn", "boss_pos", "exit"]:
		var position: Vector3 = info[field]
		if xz.distance_to(Vector2(position.x, position.z)) < radius + (7.5 if field == "boss_pos" else 6.0):
			return false
	for collision in c.colliders:
		if xz.distance_to(Vector2(collision.x, collision.y)) < radius + collision.z + 2.0:
			return false
	return true


static func _path_distance(p: Vector2, paths: Array) -> float:
	var distance := 1000.0
	for path in paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var delta := b - a
			var t := clampf((p - a).dot(delta) / maxf(delta.length_squared(), 0.001), 0, 1)
			distance = minf(distance, p.distance_to(a + delta * t))
	return distance


static func _put(c: Dictionary, kind: String, p: Vector3, size: Vector3, col: Color,
		rotation := Vector3.ZERO, role := "solid") -> void:
	_queue(c, kind, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), p), col, role)


static func _queue(c: Dictionary, kind: String, transform: Transform3D, col: Color, role: String) -> void:
	var key := kind + ":" + role
	if not c.batches.has(key):
		c.batches[key] = {"kind": kind, "role": role, "transforms": [], "colors": []}
	c.batches[key].transforms.append(transform)
	c.batches[key].colors.append(col)


static func _flush(c: Dictionary) -> void:
	var root: Node3D = c.root
	var instances := 0
	for key in c.batches:
		var batch: Dictionary = c.batches[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = _shape(batch.kind)
		multi.instance_count = batch.transforms.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, batch.transforms[i])
			multi.set_instance_color(i, batch.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = String(key).replace(":", "_")
		node.multimesh = multi
		var role: String = batch.role
		node.material_override = _material(role, 3 if role == "foliage" else 0, 0, 0.22 if role == "glow" else 0.05 if role == "mineral" else 0.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		instances += multi.instance_count
	var draw_surfaces := 0
	for child in root.get_children():
		if child is MultiMeshInstance3D:
			draw_surfaces += child.multimesh.mesh.get_surface_count()
		elif child is MeshInstance3D:
			draw_surfaces += child.mesh.get_surface_count()
	root.set_meta("batched_instances", instances)
	root.set_meta("surface_count", draw_surfaces)
	root.set_meta("collision_count", c.colliders.size())


static func _add_colliders(c: Dictionary) -> void:
	if c.colliders.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "StarSceneryCollision"
	body.collision_layer = 1
	for collider in c.colliders:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = collider.z
		cylinder.height = 2.0
		shape.shape = cylinder
		shape.position = Vector3(collider.x, 1, collider.y)
		body.add_child(shape)
	c.root.add_child(body)


static func _material(key: String, role := 0, region := 0, glow := 0.0) -> Material:
	if not _materials.has(key):
		if key == "unlit":
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.vertex_color_use_as_albedo = true
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = material
		else:
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("surface_role", role)
			material.set_shader_parameter("region", region)
			material.set_shader_parameter("glow", glow)
			_materials[key] = material
	return _materials[key]


static func _mesh_node(parent: Node3D, st: SurfaceTool, material: Material, label: String) -> void:
	st.generate_normals()
	st.index()
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _shape(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	if kind == "box":
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		_meshes[kind] = box
		return box
	if kind == "pillar":
		var cylinder := CylinderMesh.new()
		cylinder.height = 1.0
		cylinder.top_radius = 0.5
		cylinder.bottom_radius = 0.5
		cylinder.radial_segments = 10
		cylinder.rings = 1
		_meshes[kind] = cylinder
		return cylinder
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"rock": _rock_geometry(st)
		"island": _island_geometry(st)
		"crystal": _crystal_geometry(st)
		"trunk": _trunk_geometry(st)
		"crown": _crown_geometry(st)
		"willow_frond": _ellipsoid(st, Vector3.ZERO, Vector3.ONE, Color.WHITE, 7, 4, 0.8)
		"fern": _fern_geometry(st)
		"flower": _flower_geometry(st)
		"mushroom": _mushroom_geometry(st)
		"roof": _roof_geometry(st)
		"cloud": _cloud_geometry(st)
		"disc": _disc_geometry(st)
	st.generate_normals()
	st.index()
	var mesh := st.commit()
	_meshes[kind] = mesh
	return mesh


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		col_a := Color.WHITE, col_b := Color.WHITE, col_c := Color.WHITE) -> void:
	for vertex in [[a, col_a], [b, col_b], [c, col_c]]:
		st.set_color(vertex[1])
		st.set_uv(Vector2(vertex[0].x, vertex[0].z))
		st.add_vertex(vertex[0])


static func _ellipsoid(st: SurfaceTool, center: Vector3, size: Vector3, color: Color,
		segments := 9, rings := 5, phase := 0.0) -> void:
	for row in rings:
		for i in segments:
			var points: Array[Vector3] = []
			for corner in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var v := float(row + corner.y) / rings * PI
				var u := float(i + corner.x) / segments * TAU
				var lobe := 1.0 + sin(u * 3 + phase) * sin(v) * 0.07
				points.append(center + Vector3(cos(u) * sin(v), cos(v), sin(u) * sin(v)) * size * 0.5 * lobe)
			var shade := color.darkened(float(row) / rings * 0.1)
			_triangle(st, points[0], points[1], points[2], shade, shade, shade)
			_triangle(st, points[0], points[2], points[3], shade, shade, shade)


static func _tube(st: SurfaceTool, points: Array[Vector3], radii: Array[float], color: Color, sides := 7) -> void:
	for segment in points.size() - 1:
		var delta := (points[segment + 1] - points[segment]).normalized()
		var right := delta.cross(Vector3.FORWARD).normalized()
		if right.length_squared() < 0.01:
			right = Vector3.RIGHT
		var other := right.cross(delta).normalized()
		for side in sides:
			var a := float(side) / sides * TAU
			var b := float(side + 1) / sides * TAU
			var va := right * cos(a) + other * sin(a)
			var vb := right * cos(b) + other * sin(b)
			var p0 := points[segment] + va * radii[segment]
			var p1 := points[segment] + vb * radii[segment]
			var p2 := points[segment + 1] + vb * radii[segment + 1]
			var p3 := points[segment + 1] + va * radii[segment + 1]
			var shade := color.darkened(float(side % 3) * 0.035)
			_triangle(st, p0, p1, p2, shade, shade, shade)
			_triangle(st, p0, p2, p3, shade, shade, shade)


static func _rock_geometry(st: SurfaceTool) -> void:
	var rings: Array[Array] = []
	for level in 4:
		var points: Array[Vector3] = []
		var radius: float = [0.34, 0.54, 0.43, 0.22][level]
		for i in 9:
			var angle := i * TAU / 9.0
			points.append(Vector3(cos(angle) * radius * (1 + sin(i * 2.7 + level) * 0.13), -0.5 + level / 3.0 + sin(i * 1.8 + level) * 0.06, sin(angle) * radius))
		rings.append(points)
	for level in 3:
		for i in 9:
			var j := (i + 1) % 9
			var shade := Color.WHITE.darkened(0.06 * (i % 3) + 0.055 * (2 - level))
			_triangle(st, rings[level][i], rings[level][j], rings[level + 1][j], shade, shade, shade)
			_triangle(st, rings[level][i], rings[level + 1][j], rings[level + 1][i], shade, shade, shade)
	for i in 9:
		_triangle(st, Vector3(0, 0.53, 0), rings[3][i], rings[3][(i + 1) % 9])


static func _island_geometry(st: SurfaceTool) -> void:
	for i in 48:
		var a := float(i) * TAU / 48.0
		var b := float(i + 1) * TAU / 48.0
		var ra := 0.50 + sin(a * 7) * 0.007
		var rb := 0.50 + sin(b * 7) * 0.007
		var p0 := Vector3(cos(a) * ra, 0.5, sin(a) * ra)
		var p1 := Vector3(cos(b) * rb, 0.5, sin(b) * rb)
		var p2 := Vector3(cos(b) * rb * 0.73, -0.16 + sin(b * 5) * 0.08, sin(b) * rb * 0.73)
		var p3 := Vector3(cos(a) * ra * 0.73, -0.16 + sin(a * 5) * 0.08, sin(a) * ra * 0.73)
		var col := Color.WHITE.darkened(float(i % 4) * 0.032)
		_triangle(st, p0, p1, p2, col, col, col.darkened(0.1))
		_triangle(st, p0, p2, p3, col, col.darkened(0.1), col.darkened(0.1))
		_triangle(st, p3, p2, Vector3(0.04, -0.5, -0.03), col.darkened(0.1), col.darkened(0.1), col.darkened(0.2))


static func _crystal_geometry(st: SurfaceTool) -> void:
	for i in 6:
		var a := i * TAU / 6.0
		var b := (i + 1) * TAU / 6.0
		var p0 := Vector3(cos(a) * 0.5, -0.5, sin(a) * 0.5)
		var p1 := Vector3(cos(b) * 0.5, -0.5, sin(b) * 0.5)
		var p2 := Vector3(cos(b) * 0.44, 0.23, sin(b) * 0.44)
		var p3 := Vector3(cos(a) * 0.44, 0.23, sin(a) * 0.44)
		var col := Color.WHITE.darkened(float(i % 3) * 0.13)
		_triangle(st, p0, p1, p2, col.darkened(0.08), col.darkened(0.08), col)
		_triangle(st, p0, p2, p3, col.darkened(0.08), col, col)
		_triangle(st, p3, p2, Vector3(0.035, 0.5, -0.02), col, col, Color.WHITE)


static func _trunk_geometry(st: SurfaceTool) -> void:
	_tube(st, [Vector3(0, 0, 0), Vector3(-0.055, 0.26, 0), Vector3(0.035, 0.55, -0.02), Vector3(0, 0.8, 0.03)], [0.20, 0.135, 0.10, 0.025], Color.WHITE)
	for i in 5:
		var angle := i * TAU / 5.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		_tube(st, [direction * 0.65 + Vector3(0, 0.02, 0), direction * 0.22 + Vector3(0, 0.1, 0), Vector3(0, 0.27, 0)], [0.025, 0.10, 0.10], Color.WHITE.darkened(0.04))
		_tube(st, [Vector3(0, 0.43, 0), direction * 0.45 + Vector3(0, 0.6, 0), direction * 0.72 + Vector3(0, 0.74, 0)], [0.085, 0.055, 0.013], Color.WHITE)


static func _crown_geometry(st: SurfaceTool) -> void:
	_ellipsoid(st, Vector3(0, 0.05, 0), Vector3(0.71, 0.77, 0.65), Color.WHITE, 8, 4, 0.6)
	for i in 6:
		var angle := i * TAU / 6.0
		var position := Vector3(cos(angle) * 0.24, -0.02 + sin(i * 2.1) * 0.045, sin(angle) * 0.21)
		_ellipsoid(st, position, Vector3(0.56, 0.55 + float(i % 2) * 0.09, 0.49), Color.WHITE.darkened((i % 3) * 0.025), 7, 3, angle)


static func _fern_geometry(st: SurfaceTool) -> void:
	for stem in 7:
		var angle := stem * TAU / 7.0
		var basis := Basis(Vector3.UP, angle)
		for leaf in 5:
			var t := float(leaf + 1) / 6.0
			var center := basis * Vector3(0, sin(t * PI * 0.83) * 0.7, t * 0.8)
			var length := sin(t * PI) * 0.31
			for side in [-1.0, 1.0]:
				var tip := center + basis * Vector3(side * length, 0.06, -0.12)
				_triangle(st, center - basis * Vector3(0, 0, 0.1), tip, center + basis * Vector3(0, 0, 0.11), Color.WHITE.darkened(0.1), Color.WHITE, Color.WHITE)


static func _flower_geometry(st: SurfaceTool) -> void:
	for bloom in 3:
		var center := Vector3((bloom - 1) * 0.45, 0.75 + bloom % 2 * 0.3, sin(bloom * 2.0) * 0.3)
		_tube(st, [Vector3(center.x, 0, center.z), center], [0.025, 0.017], Color("759078"), 4)
		for petal in 5:
			var angle := petal * TAU / 5.0
			var tip := center + Vector3(cos(angle), 0.09, sin(angle)) * 0.34
			var side := Vector3(-sin(angle), 0, cos(angle)) * 0.14
			_triangle(st, center, tip - side, tip + side, Color.WHITE.darkened(0.12), Color.WHITE, Color.WHITE)
		_ellipsoid(st, center + Vector3(0, 0.06, 0), Vector3(0.16, 0.12, 0.16), Color("e4c57f"), 6, 3)


static func _mushroom_geometry(st: SurfaceTool) -> void:
	_tube(st, [Vector3.ZERO, Vector3(0.06, 0.7, 0)], [0.13, 0.08], Color("eee1c2"), 7)
	_ellipsoid(st, Vector3(0.04, 0.73, 0), Vector3(1.0, 0.48, 0.86), Color.WHITE, 10, 5)
	for i in 5:
		var angle := i * TAU / 5.0
		_ellipsoid(st, Vector3(cos(angle) * 0.25, 0.93, sin(angle) * 0.21), Vector3(0.11, 0.025, 0.1), Color("faf0d7"), 5, 2)


static func _roof_geometry(st: SurfaceTool) -> void:
	var a := Vector3(-0.5, -0.5, -0.5)
	var b := Vector3(0.5, -0.5, -0.5)
	var c := Vector3(0.5, -0.5, 0.5)
	var d := Vector3(-0.5, -0.5, 0.5)
	var ridge_a := Vector3(-0.20, 0.5, 0)
	var ridge_b := Vector3(0.20, 0.5, 0)
	_triangle(st, a, b, ridge_b)
	_triangle(st, a, ridge_b, ridge_a)
	_triangle(st, b, c, ridge_b, Color("e1e5e7"), Color("e1e5e7"), Color.WHITE)
	_triangle(st, c, d, ridge_a, Color("e8ebeb"), Color("e8ebeb"), Color.WHITE)
	_triangle(st, c, ridge_a, ridge_b, Color("e8ebeb"), Color.WHITE, Color.WHITE)
	_triangle(st, d, a, ridge_a)


static func _cloud_geometry(st: SurfaceTool) -> void:
	for i in 7:
		var angle := i * TAU / 7.0
		_ellipsoid(st, Vector3(cos(angle) * 0.25, sin(i * 1.4) * 0.045, sin(angle) * 0.19), Vector3(0.65, 0.77, 0.60), Color.WHITE.darkened((i % 2) * 0.025), 9, 5, angle)


static func _disc_geometry(st: SurfaceTool) -> void:
	for i in 48:
		var a := i * TAU / 48.0
		var b := (i + 1) * TAU / 48.0
		_triangle(st, Vector3.ZERO, Vector3(cos(b) * 0.5, 0, sin(b) * 0.5), Vector3(cos(a) * 0.5, 0, sin(a) * 0.5))
