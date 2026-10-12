class_name DivineRegionArt
extends RefCounted
## Original Lotus Sanctum: a continuous walkable temple garden at y=0.
## All repetition is instanced into finite shared batches. Decorative water is
## opaque; the scene needs no local lights, transparent mist or per-frame script.
const RADIUS := 55.5
const JADE := Color("749e96")
const IVORY := Color("e4ddd0")
const GOLD := Color("c3a369")
const ROSE := Color("c999b2")
const LAVENDER := Color("a7a3bd")
static var _petal_mesh: Mesh

static func layout(_zone_id: StringName = &"lotus_sanctum") -> Dictionary:
	return {"spawn": Vector3(0, 0, 44), "boss_pos": Vector3(0, 0, -26), "exit": Vector3(40, 0, -28),
		"camp_positions": [Vector2(-23, 20), Vector2(24, 18), Vector2(-23, -10), Vector2(25, -9)],
		"paths": [PackedVector2Array([Vector2(0, 49), Vector2(0, 24), Vector2(0, 2), Vector2(0, -26)]),
			PackedVector2Array([Vector2(-23, 20), Vector2(0, 24), Vector2(24, 18)]),
			PackedVector2Array([Vector2(-23, -10), Vector2(0, 2), Vector2(25, -9), Vector2(40, -28)])]}

static func build(parent: Node3D, _zone_id: StringName = &"lotus_sanctum") -> void:
	var root := Node3D.new()
	root.name = "LotusSanctumArt"
	parent.add_child(root)
	var c := {"root": root, "batches": {}, "colliders": [], "layout": layout(), "index": 4}
	_floor(root)
	# Enormous open lotus gate beyond the boss court. A real opening and radial
	# petal architecture distinguish the sanctuary from the sky city's palace.
	_lotus_gate(c)
	for side in [-1.0, 1.0]:
		for i in 5:
			var p := Vector3(side * (53 + sin(i * 1.5) * 8), 0, -34 + i * 19)
			_shrine(c, p, 3.4 + i % 2 * 1.2)
		for i in 3:
			_blossom_tree(c, Vector3(side * (38 + i * 6), 0, -40 + i * 39), 6.5 + i)
	# Sacred mirror pools live in quiet pockets between camps and paths. They
	# are shallow/flat and do not introduce invisible walls across the garden.
	for p in [Vector3(-34, 0, 1), Vector3(35, 0, 3), Vector3(-17, 0, -37), Vector3(18, 0, -37)]:
		_pool(c, p, Vector2(6.0, 4.0))
	# Twin incense pillars frame arrival, then a small entrance canopy behind it.
	for side in [-1.0, 1.0]:
		_column(c, Vector3(side * 9.0, 0, 44), 4.2)
		_shrine(c, Vector3(side * 30.0, 0, 36), 2.3)
		for i in 5:
			var p := Vector3(side * (44 + cos(i) * 2), 0, 29 - i * 13)
			_column(c, p, 2.5)
	# Low perimeter gardens and curved white stone coping read as terraces while
	# leaving the actual playable surface continuous and all telegraphs visible.
	for i in 64:
		var a := TAU * float(i) / 64.0
		var p := Vector3(cos(a) * 54.7, -0.15, sin(a) * 54.7)
		StarRegionArt._put(c, "box", p, Vector3(5.0, 0.30, 1.25), IVORY.darkened(0.05), Vector3(0, -a + PI * 0.5, 0))
		if i % 4 == 0 and p.z > -42:
			_lotus(c, p + Vector3(0, 0.16, 0), 1.1, ROSE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 712034
	for i in 100:
		var a := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * 49.0
		var p := Vector3(cos(a) * radius, 0, sin(a) * radius)
		if _clear(p, 1.2):
			if i % 4 == 0:
				StarRegionArt._put(c, "fern", p, Vector3(1.2, 0.85, 1.2), JADE.darkened(0.12), Vector3(0, a, 0))
			else:
				_lotus(c, p, rng.randf_range(0.35, 0.65), ROSE.lerp(IVORY, rng.randf() * 0.55))
	# Distant mountains are large opaque masses, intentionally subdued.
	for i in 14:
		var a := TAU * float(i) / 14.0
		var p := Vector3(cos(a) * 104, -1, sin(a) * 104)
		StarRegionArt._put(c, "rock", p, Vector3(37, 13 + i % 3 * 5, 27), LAVENDER.lerp(JADE, 0.25), Vector3(0, a, 0))
	_flush(c)
	StarRegionArt._add_colliders(c)
	root.set_meta("zone_id", &"lotus_sanctum")
	root.set_meta("flat_walkable_radius", RADIUS)
	root.set_meta("no_dynamic_lights", true)
	root.set_meta("opaque_water_and_clouds", true)
	root.set_meta("art_layout_version", 1)

static func _floor(root: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var info := layout()
	for r in 40:
		for s in 112:
			var points: Array[Vector3] = []
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radius := float(r + q.x) / 40.0 * 72.0
				var angle := TAU * float(s + q.y) / 112.0
				points.append(Vector3(cos(angle) * radius, -maxf(radius - RADIUS, 0.0) * 0.12, sin(angle) * radius))
			for corner in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = points[corner]
				var xz := Vector2(p.x, p.z)
				var radius := xz.length()
				var angle := atan2(p.z, p.x)
				var col := JADE.lerp(IVORY, 0.18 + sin(p.x * 0.22) * cos(p.z * 0.18) * 0.06)
				var path := 1.0 - smoothstep(2.7, 4.0, StarRegionArt._path_distance(xz, info.paths))
				var arena := 1.0 - smoothstep(12.0, 15.0, xz.distance_to(Vector2(0, -26)))
				col = col.lerp(IVORY.darkened(0.075), maxf(path, arena * 0.9))
				# Low contrast concentric inlaid stone and a lotus medallion.
				var band := 1.0 - smoothstep(0.3, 0.72, minf(absf(radius - 17.0), minf(absf(radius - 34.0), absf(radius - 50.5))))
				col = col.lerp(IVORY, band * 0.65)
				var lotus_radius := 8.0 + cos(angle * 8.0) * 2.0
				var lotus_line := 1.0 - smoothstep(0.3, 0.7, absf(radius - lotus_radius))
				col = col.lerp(GOLD, lotus_line * 0.24)
				st.set_color(col)
				st.set_normal(Vector3.UP)
				st.set_uv(xz * 0.12)
				st.add_vertex(p)
	# A continuous lavender horizon joins the garden to the distant sacred
	# mountains. This closes the landscape instead of leaving isolated rocks
	# suspended against the sky in wider camera views.
	var horizon := SurfaceTool.new()
	horizon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [72.0, 84.0, 112.0, 155.0, 210.0]
	for ring in radii.size() - 1:
		for sector in 96:
			var points: Array[Vector3] = []
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radius: float = radii[ring + corner.x]
				var a := TAU * float(sector + corner.y) / 96.0
				var height := -1.98 if ring + corner.x == 0 else -3.0 + sin(a * 5.0 + ring + corner.x) * 2.0
				points.append(Vector3(cos(a) * radius, height, sin(a) * radius))
			var color := JADE.lerp(LAVENDER, 0.38 + ring * 0.18).darkened(0.05)
			StarRegionArt._triangle(horizon, points[0], points[2], points[1], color, color, color)
			StarRegionArt._triangle(horizon, points[0], points[3], points[2], color, color, color)
	StarRegionArt._mesh_node(root, horizon, StarRegionArt._material("solid"), "DistantGardenLand")
	StarRegionArt._mesh_node(root, st, StarRegionArt._material("divine_ground", 1, 2), "LotusGardenFloor")
	var body := StaticBody3D.new()
	body.name = "DivineGroundCollision"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 1.0
	shape.shape = cylinder
	shape.position.y = -0.5
	body.add_child(shape)
	root.add_child(body)

static func _lotus_gate(c: Dictionary) -> void:
	var p := Vector3(0, 14, -64)
	for radius in [11.3, 12.1]:
		StarRegionArt._ring(c, p, radius, 0.24 if radius < 12 else 0.09, GOLD if radius < 12 else IVORY, Vector3(PI * 0.5, 0, 0))
	for i in 16:
		var a := TAU * float(i) / 16.0
		var r := 14.5 if i % 2 == 0 else 13.5
		var center := p + Vector3(cos(a) * r, sin(a) * r, 0)
		_petal(c, center, Vector3(3.6, 8.8, 1.3), IVORY if i % 2 == 0 else ROSE, Vector3(0, 0, a - PI * 0.5))
		_petal(c, center + Vector3(0, 0, 0.73), Vector3(1.2, 7.4, 0.18), GOLD, Vector3(0, 0, a - PI * 0.5))
	for side in [-1.0, 1.0]:
		_column(c, Vector3(side * 12.4, 0, -59), 12)
		for i in 3:
			StarRegionArt._put(c, "box", Vector3(side * (21 + i * 5.0), 1.3 + i * 0.5, -60), Vector3(4.9, 2.6 + i, 9.0), IVORY.darkened(0.14), Vector3(0, side * 0.08, 0))
	for side in [-1.0, 1.0]:
		for i in 5:
			var x: float = side * (18.0 + i * 4.2)
			_column(c, Vector3(x, 0, -56.5), 5.5 + sin(i * 0.6) * 2.0)
			if i < 4:
				StarRegionArt._put(c, "box", Vector3(x + side * 2.1, 5.55 + sin(i * 0.6) * 2.0, -56.5), Vector3(4.3, 0.28, 0.9), GOLD)
	# A hanging pearl is part of the architecture, not a light source.
	StarRegionArt._put(c, "crystal", p + Vector3(0, 0.4, 0), Vector3(2.1, 4.0, 1.7), Color("cbe5d9"), Vector3.ZERO, "glow")
	StarRegionArt._segment(c, p + Vector3(0, 10.9, 0), p + Vector3(0, 2.5, 0), 0.05, GOLD)
	_lotus(c, Vector3(0, 0.3, -60), 8.0, ROSE)

static func _column(c: Dictionary, p: Vector3, height: float) -> void:
	StarRegionArt._put(c, "pillar", p + Vector3(0, 0.25, 0), Vector3(1.6, 0.5, 1.6), IVORY)
	StarRegionArt._put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(0.65, height, 0.65), JADE)
	for y in [0.55, height - 0.45]:
		StarRegionArt._put(c, "pillar", p + Vector3(0, y, 0), Vector3(0.95, 0.18, 0.95), GOLD)
	_lotus(c, p + Vector3(0, height, 0), 0.7, IVORY)
	StarRegionArt._put(c, "crystal", p + Vector3(0, height + 0.55, 0), Vector3(0.35, 0.7, 0.35), Color("d6e9d4"), Vector3.ZERO, "glow")
	if Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, 0.7))

static func _shrine(c: Dictionary, p: Vector3, size: float) -> void:
	for i in 3:
		StarRegionArt._put(c, "pillar", p + Vector3(0, 0.15 + i * 0.23, 0), Vector3(size * (1.4 - i * 0.2), 0.30, size * (1.4 - i * 0.2)), IVORY.darkened(i * 0.035))
	_lotus(c, p + Vector3(0, 0.85, 0), size * 0.65, ROSE)
	StarRegionArt._put(c, "crystal", p + Vector3(0, size * 0.85, 0), Vector3(size * 0.4, size, size * 0.4), JADE.lightened(0.25))
	StarRegionArt._ring(c, p + Vector3(0, size * 0.85, 0), size * 0.5, 0.055, GOLD, Vector3(PI * 0.5, 0, 0))
	if Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, size * 0.75))

static func _pool(c: Dictionary, p: Vector3, size: Vector2) -> void:
	StarRegionArt._pool(c, p + Vector3(0, 0.018, 0), size, Color("799eaa"), "SacredMirror")
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.5
		_lotus(c, p + Vector3(cos(a) * size.x * 0.57, 0.055, sin(a) * size.y * 0.6), 0.65, ROSE.lerp(IVORY, i * 0.16))
	StarRegionArt._ring(c, p + Vector3(0, 0.026, 0), 1.15, 0.017, Color("c9dcd0"), Vector3.ZERO)

static func _blossom_tree(c: Dictionary, p: Vector3, size: float) -> void:
	StarRegionArt._put(c, "trunk", p, Vector3(size * 0.37, size, size * 0.37), Color("b8aaa4"), Vector3(0, p.x * 0.1, 0))
	for i in 5:
		var a := float(i) * TAU / 5.0
		var tip := p + Vector3(cos(a) * size * 0.28, size * (0.72 + i % 2 * 0.11), sin(a) * size * 0.22)
		StarRegionArt._segment(c, p + Vector3(0, size * 0.5, 0), tip, size * 0.03, Color("ad9d98"))
		StarRegionArt._put(c, "crown", tip, Vector3(size * 0.62, size * 0.33, size * 0.53), ROSE.lerp(LAVENDER, i * 0.13), Vector3(0, a, 0))
	if Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, size * 0.13))

static func _lotus(c: Dictionary, p: Vector3, size: float, color: Color) -> void:
	for layer in 2:
		for i in 7:
			var a := float(i) * TAU / 7.0 + layer * 0.45
			var radius := size * (0.40 if layer == 0 else 0.20)
			var pos := p + Vector3(cos(a) * radius, size * (0.23 + layer * 0.18), sin(a) * radius)
			_petal(c, pos, Vector3(size * 0.47, size * 0.95, size * 0.17), color.lightened(layer * 0.13), Vector3(0.72 if layer == 0 else 0.33, -a + PI * 0.5, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, size * 0.60, 0), Vector3(size * 0.26, size * 0.35, size * 0.26), GOLD)

static func _clear(p: Vector3, radius: float) -> bool:
	var info := layout()
	var xz := Vector2(p.x, p.z)
	if StarRegionArt._path_distance(xz, info.paths) < radius + 4.0:
		return false
	for camp in info.camp_positions:
		if xz.distance_to(camp) < radius + 9.0:
			return false
	for key in ["spawn", "boss_pos", "exit"]:
		var q: Vector3 = info[key]
		if xz.distance_to(Vector2(q.x, q.z)) < radius + (14.0 if key == "boss_pos" else 7.0):
			return false
	for pool in [Vector2(-34, 1), Vector2(35, 3), Vector2(-17, -37), Vector2(18, -37)]:
		if xz.distance_to(pool) < 7.5:
			return false
	return true

static func _petal(c: Dictionary, p: Vector3, size: Vector3, color: Color, rotation: Vector3) -> void:
	StarRegionArt._queue(c, "divine_petal", Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), p), color, "solid")

static func _flush(c: Dictionary) -> void:
	if _petal_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [-1.0, 1.0]:
			for row in 6:
				var pts: Array[Vector3] = []
				for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var t := float(row + q.y) / 6.0
					var width := pow(sin(t * PI), 0.8) * 0.5
					pts.append(Vector3((float(q.x) * 2 - 1) * width, t - 0.5, sin(t * PI) * 0.13 * face))
				StarRegionArt._triangle(st, pts[0], pts[1] if face > 0 else pts[2], pts[2] if face > 0 else pts[1])
				StarRegionArt._triangle(st, pts[0], pts[2] if face > 0 else pts[3], pts[3] if face > 0 else pts[2])
		st.generate_normals()
		st.index()
		_petal_mesh = st.commit()
	# Register only this original finite shape in the shared mesh batch cache.
	StarRegionArt._meshes["divine_petal"] = _petal_mesh
	StarRegionArt._flush(c)
