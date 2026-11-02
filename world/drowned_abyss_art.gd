class_name DrownedAbyssArt
extends RefCounted
## ห้วงสมุทรอสูร: a drowned temple city on the dark sea floor. Teal sand with
## glowing tide rings, coral reefs in blood red and violet, swaying kelp,
## broken colonnades, giant clam shells, the ribcage of a dead leviathan and a
## sunken ring gate behind the tyrant's court. Like the other star fields the
## playable disc is continuous at y=0 and every repeated prop is batched into
## StarRegionArt's shared MultiMeshes; no lights, no per-frame scripts.
const RADIUS := 55.5
const SAND := Color("1f4a52")
const DEEP := Color("0d2733")
const TIDE := Color("4fd8e0")
const CORAL := Color("ff4f78")
const VIOLET := Color("9a6bff")
const KELP := Color("2f8a6a")
const STONE := Color("5b7a86")
const BONE := Color("d9d2bd")
const POOLS := [Vector2(-38, 8), Vector2(40, -10), Vector2(-4, 6)]


static func layout(_zone_id: StringName = DrownedAbyssData.ID) -> Dictionary:
	return {"spawn": Vector3(-42, 0, 28), "boss_pos": Vector3(16, 0, -28), "exit": Vector3(44, 0, 22),
		"camp_positions": [Vector2(-20, 26), Vector2(12, 32), Vector2(-33, -8), Vector2(31, 8), Vector2(-16, -30), Vector2(10, 12)],
		"paths": [PackedVector2Array([Vector2(-45, 30), Vector2(-24, 20), Vector2(-6, 18), Vector2(10, 4), Vector2(16, -28)]),
			PackedVector2Array([Vector2(-20, 26), Vector2(-6, 18), Vector2(12, 32)]),
			PackedVector2Array([Vector2(-33, -8), Vector2(-14, -2), Vector2(10, 4), Vector2(31, 8)]),
			PackedVector2Array([Vector2(-16, -30), Vector2(-14, -2)])]}


static func build(parent: Node3D, _zone_id: StringName = DrownedAbyssData.ID) -> void:
	var root := Node3D.new()
	root.name = "DrownedAbyssArt"
	parent.add_child(root)
	var c := {"root": root, "batches": {}, "colliders": [], "layout": layout(), "index": 5}
	_floor(root)
	var boss: Vector3 = layout().boss_pos
	# The sunken ring gate stands behind the tyrant's court, with a drowned
	# throne stair and two broken colonnades leading to it.
	_ring_gate(c, Vector3(boss.x, 0, -58))
	for i in 7:
		StarRegionArt._put(c, "box", Vector3(boss.x, 0.12 + i * 0.22, -40 - i * 1.6), Vector3(16 - i * 1.2, 0.24, 1.7), STONE.darkened(0.1 + i * 0.02))
	for side in [-1.0, 1.0]:
		for i in 4:
			_column(c, Vector3(boss.x + side * (13.0 + i * 2.5), 0, -18 - i * 8.0), 7.0 - (i % 2) * 2.6, i == 2)
	# The leviathan's ribcage arches over the western reef.
	_ribcage(c, Vector3(-46, 0, -26), 0.6)
	# Reefs, kelp beds and clams scattered between the camps and paths.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2603191
	for i in 150:
		var a := rng.randf() * TAU
		var radius := 8.0 + sqrt(rng.randf()) * 44.0
		var p := Vector3(cos(a) * radius, 0, sin(a) * radius)
		if not _clear(p, 1.4):
			continue
		match i % 5:
			0, 1: _kelp(c, p, rng.randf_range(2.5, 5.5), rng)
			2: _coral(c, p, rng.randf_range(0.8, 1.7), CORAL.lerp(VIOLET, rng.randf()), rng)
			3: StarRegionArt._put(c, "rock", p, Vector3(1, 0.55, 1) * rng.randf_range(1.0, 2.4), STONE.darkened(0.25), Vector3(0, a, 0))
			4: _clam(c, p, rng.randf_range(0.7, 1.3), a)
	for pool in POOLS:
		StarRegionArt._pool(c, Vector3(pool.x, 0.02, pool.y), Vector2(5.5, 3.8), Color("0f5a6a"), "AbyssVent")
		_coral(c, Vector3(pool.x + 5.5, 0, pool.y + 1.0), 1.6, VIOLET, rng)
	# Tall reef spires and kelp forests ring the field's edge.
	for i in 40:
		var a := TAU * float(i) / 40.0
		var p := Vector3(cos(a) * 58.0, 0, sin(a) * 58.0)
		if i % 2 == 0:
			_spire(c, p, 6.0 + float(i % 5) * 2.0, CORAL.lerp(VIOLET, float(i % 3) * 0.4))
		else:
			_kelp(c, p, 7.0 + float(i % 4), rng)
	for i in 16:
		var a := TAU * float(i) / 16.0 + 0.2
		var p := Vector3(cos(a) * 100, -2, sin(a) * 100)
		StarRegionArt._put(c, "rock", p, Vector3(34, 14 + i % 4 * 6, 26), DEEP.lerp(Color("123d55"), float(i % 3) * 0.35), Vector3(0, a, 0))
	StarRegionArt._flush(c)
	StarRegionArt._add_colliders(c)
	root.set_meta("zone_id", DrownedAbyssData.ID)
	root.set_meta("flat_walkable_radius", RADIUS)
	root.set_meta("no_dynamic_lights", true)
	root.set_meta("art_layout_version", 1)


static func _floor(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var info := layout()
	var boss: Vector3 = info.boss_pos
	for r in 40:
		for s in 112:
			var points: Array[Vector3] = []
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radius := float(r + q.x) / 40.0 * 72.0
				var angle := TAU * float(s + q.y) / 112.0
				points.append(Vector3(cos(angle) * radius, -maxf(radius - RADIUS, 0.0) * 0.14, sin(angle) * radius))
			for corner in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = points[corner]
				var xz := Vector2(p.x, p.z)
				# Rippled sand, a pale worn path and the tyrant's tiled court.
				var col := SAND.lerp(DEEP, 0.35 + sin(p.x * 0.31 + p.z * 0.07) * cos(p.z * 0.23) * 0.25)
				var path := 1.0 - smoothstep(2.4, 3.8, StarRegionArt._path_distance(xz, info.paths))
				col = col.lerp(Color("5f8f8a"), path * 0.55)
				var court := xz.distance_to(Vector2(boss.x, boss.z))
				col = col.lerp(STONE.darkened(0.2), (1.0 - smoothstep(12.0, 14.0, court)) * 0.8)
				# Glowing tide rings: concentric bioluminescent lines on the court
				# and faint ones around the whole floor.
				var ring := 1.0 - smoothstep(0.15, 0.5, minf(absf(court - 6.0), absf(court - 11.0)))
				col = col.lerp(TIDE, ring * 0.7)
				var tide := 1.0 - smoothstep(0.2, 0.6, absf(fmod(xz.length(), 15.0) - 7.5))
				col = col.lerp(TIDE.darkened(0.3), tide * 0.25)
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.set_uv(xz * 0.12)
				st.add_vertex(p)
	var horizon := SurfaceTool.new()
	horizon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [72.0, 84.0, 112.0, 155.0, 210.0]
	for ring in radii.size() - 1:
		for sector in 96:
			var points: Array[Vector3] = []
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radius: float = radii[ring + corner.x]
				var a := TAU * float(sector + corner.y) / 96.0
				var height := -2.2 if ring + corner.x == 0 else -3.0 + sin(a * 4.0 + ring + corner.x) * 2.5
				points.append(Vector3(cos(a) * radius, height, sin(a) * radius))
			var color := DEEP.lerp(Color("0b2f45"), 0.3 + ring * 0.2)
			StarRegionArt._triangle(horizon, points[0], points[2], points[1], color, color, color)
			StarRegionArt._triangle(horizon, points[0], points[3], points[2], color, color, color)
	StarRegionArt._mesh_node(root, horizon, StarRegionArt._material("solid"), "DistantTrench")
	StarRegionArt._mesh_node(root, st, StarRegionArt._material("abyss_ground", 1, 0), "DrownedSeaFloor")
	var body := StaticBody3D.new()
	body.name = "AbyssGroundCollision"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 1.0
	shape.shape = cylinder
	shape.position.y = -0.5
	body.add_child(shape)
	root.add_child(body)


static func _ring_gate(c: Dictionary, p: Vector3) -> void:
	var center := p + Vector3(0, 13, 0)
	StarRegionArt._ring(c, center, 12.0, 0.9, STONE, Vector3(PI * 0.5, 0, 0))
	StarRegionArt._ring(c, center, 10.6, 0.16, TIDE, Vector3(PI * 0.5, 0, 0))
	for i in 12:
		var a := TAU * float(i) / 12.0
		var at := center + Vector3(cos(a) * 12.6, sin(a) * 12.6, 0)
		StarRegionArt._put(c, "crystal", at, Vector3(1.2, 2.6, 1.2), TIDE if i % 2 == 0 else VIOLET, Vector3(0, 0, a - PI * 0.5), "glow")
	StarRegionArt._put(c, "crystal", center, Vector3(2.4, 4.4, 2.0), Color("8ff6ff"), Vector3.ZERO, "glow")
	for side in [-1.0, 1.0]:
		StarRegionArt._put(c, "box", p + Vector3(side * 12.5, 1.6, 0), Vector3(5.0, 3.2, 5.0), STONE.darkened(0.15))
		_spire(c, p + Vector3(side * 22.0, 0, 3.0), 12.0, CORAL if side < 0 else VIOLET)


static func _column(c: Dictionary, p: Vector3, height: float, toppled: bool) -> void:
	StarRegionArt._put(c, "box", p + Vector3(0, 0.3, 0), Vector3(2.2, 0.6, 2.2), STONE.darkened(0.2))
	StarRegionArt._put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(1.1, height, 1.1), STONE)
	StarRegionArt._put(c, "box", p + Vector3(0, height, 0), Vector3(1.8, 0.4, 1.8), STONE.lightened(0.1))
	# Barnacles of glowing coral grow on the shafts.
	StarRegionArt._put(c, "crystal", p + Vector3(0.5, height * 0.35, 0.3), Vector3(0.45, 0.9, 0.45), TIDE, Vector3(0.4, 0, 0.6), "glow")
	if toppled:
		StarRegionArt._put(c, "pillar", p + Vector3(2.6, 0.55, 1.2), Vector3(1.05, 5.0, 1.05), STONE.darkened(0.1), Vector3(0, 0.4, PI * 0.5))
	if Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, 0.7))


static func _ribcage(c: Dictionary, p: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	StarRegionArt._segment(c, p + basis * Vector3(0, 0.6, -10), p + basis * Vector3(0, 0.9, 10), 0.7, BONE)
	for i in 7:
		var z := -8.0 + float(i) * 2.7
		var size := 7.5 - absf(float(i) - 3.0) * 0.9
		for side in [-1.0, 1.0]:
			var last := p + basis * Vector3(0, 0.8, z)
			for k in 6:
				var t := float(k + 1) / 6.0
				var at := p + basis * Vector3(side * sin(t * PI * 0.62) * size * 0.75, 0.8 + sin(t * PI * 0.9) * size, z)
				StarRegionArt._segment(c, last, at, 0.28, BONE.darkened(0.05 * k))
				last = at
	StarRegionArt._put(c, "rock", p + basis * Vector3(0, 1.2, 12.5), Vector3(4.5, 3.0, 5.5), BONE.darkened(0.15), Vector3(0, yaw, 0))


static func _kelp(c: Dictionary, p: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		var h := height * rng.randf_range(0.7, 1.0)
		StarRegionArt._put(c, "willow_frond", p + off + Vector3(0, h * 0.5, 0), Vector3(0.35, h * 0.5, 0.35), KELP.lerp(Color("4fbf8a"), rng.randf() * 0.5),
			Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)), "foliage")


static func _coral(c: Dictionary, p: Vector3, size: float, color: Color, rng: RandomNumberGenerator) -> void:
	StarRegionArt._put(c, "rock", p + Vector3(0, size * 0.15, 0), Vector3(size * 1.6, size * 0.5, size * 1.4), STONE.darkened(0.3))
	for i in 5:
		var a := float(i) * TAU / 5.0 + rng.randf()
		var tip := p + Vector3(cos(a) * size * 0.5, size * rng.randf_range(0.8, 1.6), sin(a) * size * 0.5)
		StarRegionArt._segment(c, p + Vector3(0, size * 0.3, 0), tip, size * 0.11, color.darkened(0.15))
		StarRegionArt._put(c, "crystal", tip, Vector3(0.28, 0.5, 0.28) * size, color.lightened(0.25), Vector3(0, a, 0), "glow")
	if Vector2(p.x, p.z).length() < 54.0 and size > 1.3:
		c.colliders.append(Vector3(p.x, p.z, size * 0.5))


static func _spire(c: Dictionary, p: Vector3, height: float, color: Color) -> void:
	StarRegionArt._put(c, "rock", p + Vector3(0, height * 0.18, 0), Vector3(4.0, height * 0.4, 3.6), STONE.darkened(0.35))
	StarRegionArt._put(c, "crystal", p + Vector3(0, height * 0.55, 0), Vector3(2.0, height, 2.0), color.darkened(0.25))
	StarRegionArt._put(c, "crystal", p + Vector3(1.4, height * 0.4, 0.6), Vector3(0.9, height * 0.55, 0.9), color.lightened(0.1), Vector3(0.3, 0, -0.4), "glow")


static func _clam(c: Dictionary, p: Vector3, size: float, yaw: float) -> void:
	StarRegionArt._put(c, "disc", p + Vector3(0, 0.12, 0), Vector3(1.6, 1, 1.4) * size, Color("c8b7c9"), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "disc", p + Vector3(0, 0.75 * size, -0.45 * size), Vector3(1.6, 1, 1.4) * size, Color("b49fbb"), Vector3(-1.0, yaw, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, 0.35 * size, 0), Vector3(0.4, 0.4, 0.4) * size, Color("f4f8ff"), Vector3.ZERO, "glow")


static func _clear(p: Vector3, radius: float) -> bool:
	var info := layout()
	var xz := Vector2(p.x, p.z)
	if StarRegionArt._path_distance(xz, info.paths) < radius + 3.5:
		return false
	for camp in info.camp_positions:
		if xz.distance_to(camp) < radius + 9.5:
			return false
	for key in ["spawn", "boss_pos"]:
		var q: Vector3 = info[key]
		if xz.distance_to(Vector2(q.x, q.z)) < radius + (15.0 if key == "boss_pos" else 7.0):
			return false
	for pool in POOLS:
		if xz.distance_to(pool) < 7.5:
			return false
	return true
