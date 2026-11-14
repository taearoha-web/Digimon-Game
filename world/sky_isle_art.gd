class_name SkyIsleArt
extends RefCounted
## เกาะลอยฟ้าเทพมังกร: the Dragon God's island, afloat in a bright high sky over a golden
## sea of cloud. A lobed isle of sunlit grass whose rim breaks into five sky bays (the
## cloud sea and lower islets show through them), brooks that run from lotus ponds to the
## bays and fall off the edge into nothing, flagstone ways, a jade-tiled court before a
## vermilion and teal shrine on the eastern promontory, coiled dragon statues, the ribs
## and skull of a dead dragon arching over the central camp, floating rocks, chained
## islets and wind streamers.
## Like the other star fields the playable disc is continuous at y=0 (the bays are fenced
## by colliders) and every repeated prop is batched into StarRegionArt's shared
## MultiMeshes; the falls, the clouds and the streamers move in one small shader
## (sky_isle.gdshader). No lights, no particles, no per-frame scripts.
const SHADER := preload("res://shaders/sky_isle.gdshader")
const RADIUS := 55.5
const SKY := Color("5fa3e0")
const HAZE := Color("ffeed6")
const GRASS := Color("69ad5e")
const GRASS_SUN := Color("a3cb60")
const MEADOW := Color("dcc65c")
const EARTH := Color("dccba4")
const ROCK := Color("9a8676")
const ROCK_DEEP := Color("6c6072")
const JADE := Color("46b894")
const JADE_PALE := Color("b4e2d0")
const TEAL := Color("1f8f8a")
const GOLD := Color("f0bf4c")
const IVORY := Color("f6ecd8")
const VERMILION := Color("d4492f")
const BONE := Color("f3e9d0")
const WATER := Color("7fd6e8")
const CLOUD := Color("fff4e2")
const CLOUD_WARM := Color("ffcfa4")
const PEACH := Color("ffb3c4")
const GINKGO := Color("f6c64a")
const PINE := Color("3f9a7c")
## Lotus ponds (the brooks' springs) and the brooks themselves, kept free of props.
const PONDS := [Vector2(-12, 22), Vector2(30, 6), Vector2(-24, -20), Vector2(12, -26)]
## The sky bays: [angle (rad, atan2(z, x)), half width (rad), radius of the bay's head].
const BAYS := [[1.885, 0.17, 46.0], [0.349, 0.17, 45.5], [3.875, 0.17, 46.0], [-1.047, 0.17, 45.5], [3.002, 0.15, 47.5]]
## The shrine's promontory: the rim swells out behind the boss court.
const SHRINE_ANGLE := -0.4366
const WIND := Vector3(0.82, 0.0, 0.57)

static var _materials: Dictionary = {}


static func layout(_zone_id: StringName = &"sky_dragon_isle") -> Dictionary:
	return {"spawn": Vector3(-44, 0, 22), "boss_pos": Vector3(30, 0, -14), "exit": Vector3(42, 0, 28),
		"camp_positions": [Vector2(-24, 30), Vector2(2, 36), Vector2(-36, -8), Vector2(-10, -34), Vector2(22, 22), Vector2(-2, -8)],
		"paths": [PackedVector2Array([Vector2(-47, 23.5), Vector2(-30, 13), Vector2(-12, 10), Vector2(8, 4), Vector2(20, -6), Vector2(30, -14)]),
			PackedVector2Array([Vector2(-30, 13), Vector2(-24, 30)]),
			PackedVector2Array([Vector2(-12, 10), Vector2(-2, 24), Vector2(2, 36)]),
			PackedVector2Array([Vector2(-30, 13), Vector2(-36, -8)]),
			PackedVector2Array([Vector2(8, 4), Vector2(22, 22)]),
			PackedVector2Array([Vector2(-12, 10), Vector2(-2, -8), Vector2(-10, -34)])]}


## The brooks: from each pond to the head of its bay.
static func streams() -> Array:
	return [PackedVector2Array([Vector2(-12.5, 25), Vector2(-14.2, 34), Vector2(-14.3, 43.9)]),
		PackedVector2Array([Vector2(32.5, 7.5), Vector2(38, 11.5), Vector2(42.9, 15.6)]),
		PackedVector2Array([Vector2(-26, -22), Vector2(-30, -26), Vector2(-34.3, -30.8)]),
		PackedVector2Array([Vector2(13.5, -28.5), Vector2(18, -34), Vector2(22.8, -39.5)])]


## The rim's radius at angle `a`: a lobed outline, the shrine's promontory and the bays.
static func edge(a: float) -> float:
	var r := 61.5 + 2.4 * sin(3.0 * a + 0.7) + 1.6 * sin(7.0 * a + 2.1) + 0.9 * sin(13.0 * a + 0.4)
	var d := absf(wrapf(a - SHRINE_ANGLE, -PI, PI)) / 0.34
	if d < 1.0:
		r += 10.0 * (1.0 - d * d) * (1.0 - d * d)
	for bay in BAYS:
		var u := absf(wrapf(a - float(bay[0]), -PI, PI)) / float(bay[1])
		if u < 1.0:
			var s := (1.0 - u * u) * (1.0 - u * u)
			r = lerpf(r, float(bay[2]), s)
	return r


static func _rim(a: float, r_offset := 0.0, y := 0.0) -> Vector3:
	var r := edge(a) + r_offset
	return Vector3(cos(a) * r, y, sin(a) * r)


## `tree` paces the build over frames (StarRegionArt.build); null builds it in one go.
static func build(parent: Node3D, _zone_id: StringName = &"sky_dragon_isle", tree: SceneTree = null) -> void:
	var root := Node3D.new()
	root.name = "SkyIsleArt"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30031
	var c := {"root": root, "batches": {}, "special": {}, "colliders": [], "layout": layout(), "index": 5, "rng": rng}
	_register_shapes()
	await _ground(root, tree)
	await FrameSlicer.pace(tree)
	_underside(c)
	_cloud_sea(c)
	await FrameSlicer.pace(tree)
	_waters(c)
	_paving(c)
	await FrameSlicer.pace(tree)
	_shrine(c)
	_entrance(c)
	_graveyard(c)
	_camp_dressing(c)
	await FrameSlicer.pace(tree)
	_planting(c)
	_undergrowth(c)
	_rim_dressing(c)
	_islets(c)
	_bay_fences(c)
	# Flowers, ferns, fallen leaves and pebbles (visual only, batched).
	PropDressing.isle(c)
	await StarRegionArt._flush(c, tree)
	_flush_special(c)
	StarRegionArt._add_colliders(c)
	root.set_meta("zone_id", SkyIsleData.ID)
	root.set_meta("flat_walkable_radius", RADIUS)
	root.set_meta("no_dynamic_lights", true)
	root.set_meta("opaque_water_and_clouds", true)
	root.set_meta("art_layout_version", 1)


# ---------------------------------------------------------------------------
# Ground, underside, cloud sea
# ---------------------------------------------------------------------------

static func _ground_color(xz: Vector2, t: float, info: Dictionary) -> Color:
	var col := GRASS.lerp(GRASS_SUN, 0.5 + 0.5 * sin(xz.x * 0.21 + xz.y * 0.09) * cos(xz.y * 0.17 - xz.x * 0.05))
	# Patches of golden meadow grass.
	var patch := sin(xz.x * 0.083 + 1.3) * sin(xz.y * 0.097 - 0.6) + 0.35 * sin((xz.x + xz.y) * 0.31)
	col = col.lerp(MEADOW, smoothstep(0.3, 0.85, patch) * 0.55)
	# Deeper clover where the ground dips, a blush of fallen blossom elsewhere.
	var dip := sin(xz.x * 0.131 - 2.0) * sin(xz.y * 0.119 + 1.1)
	col = col.lerp(Color("4f9a62"), smoothstep(0.45, 0.95, dip) * 0.5)
	col = col.lerp(Color("f2c4cc"), smoothstep(0.55, 0.98, -dip * sin(xz.x * 0.4 + xz.y * 0.23)) * 0.35)
	for camp in info.camp_positions:
		col = col.lerp(Color("a9b672"), (1.0 - smoothstep(6.0, 10.5, xz.distance_to(camp))) * 0.4)
	for path in streams():
		col = col.lerp(Color("5f9a58"), (1.0 - smoothstep(1.2, 2.6, StarRegionArt._path_distance(xz, [path]))) * 0.5)
	col = col.lerp(EARTH, (1.0 - smoothstep(2.0, 3.5, StarRegionArt._path_distance(xz, info.paths))) * 0.8)
	var boss: Vector3 = info.boss_pos
	var court := xz.distance_to(Vector2(boss.x, boss.z))
	col = col.lerp(JADE_PALE.lerp(IVORY, 0.35), (1.0 - smoothstep(13.4, 14.8, court)) * 0.92)
	var spawn: Vector3 = info.spawn
	col = col.lerp(IVORY.darkened(0.06), (1.0 - smoothstep(5.2, 6.6, xz.distance_to(Vector2(spawn.x, spawn.z)))) * 0.85)
	# The promontory's processional way to the shrine.
	var along := xz.dot(Vector2(cos(SHRINE_ANGLE), sin(SHRINE_ANGLE)))
	var across := absf(xz.dot(Vector2(-sin(SHRINE_ANGLE), cos(SHRINE_ANGLE))))
	if along > 40.0:
		col = col.lerp(IVORY.darkened(0.04), (1.0 - smoothstep(9.0, 11.0, across)) * 0.9)
	# Bare rock at the rim.
	col = col.lerp(Color("c2ab8a"), smoothstep(0.94, 1.0, t) * 0.85)
	return col


static func _ground(root: Node3D, tree: SceneTree = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var info := layout()
	var rings := 40
	var sectors := 128
	var rim: Array[float] = []
	for s in sectors + 1:
		rim.append(edge(TAU * float(s) / float(sectors)))
	# A grid point's colour depends on its position only: work it out once.
	var shade := {}
	for r in rings:
		await FrameSlicer.pace(tree)
		for s in sectors:
			var points: Array[Vector3] = []
			var keys: Array[Vector2i] = []
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t := float(r + q.x) / float(rings)
				var angle := TAU * float(s + q.y) / float(sectors)
				var radius := t * rim[s + q.y]
				points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
				keys.append(Vector2i(r + q.x, (s + q.y) % sectors))
			for corner in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = points[corner]
				var key: Vector2i = keys[corner]
				if not shade.has(key):
					shade[key] = _ground_color(Vector2(p.x, p.z), float(key.x) / float(rings), info)
				st.set_color(shade[key])
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p.x, p.z) * 0.12)
				st.add_vertex(p)
	StarRegionArt._mesh_node(root, st, StarRegionArt._material("isle_ground", 1, 0), "SkyIsleGround")
	# The cliff under the rim and the hanging mountain below it.
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [[1.0, 0.0, 0.0], [1.0, -0.7, -1.4], [0.95, -1.0, -5.5], [0.84, 0.0, -12.0], [0.62, 0.0, -20.0], [0.36, 0.0, -28.0], [0.12, 0.0, -34.0]]
	var bands := [Color("b99c78"), Color("9a8676"), Color("86756f"), Color("76697a"), Color("6a6078"), Color("5f5a78"), Color("585676")]
	var steps := 192
	for s in steps:
		var a0 := TAU * float(s) / float(steps)
		var a1 := TAU * float(s + 1) / float(steps)
		for k in profile.size() - 1:
			var quad: Array[Vector3] = []
			for corner in [[a0, k], [a1, k], [a1, k + 1], [a0, k + 1]]:
				var a: float = corner[0]
				var row: Array = profile[int(corner[1])]
				var jag := 1.0 + (0.035 * sin(a * 23.0 + float(corner[1]) * 1.7) if int(corner[1]) > 1 else 0.0)
				var radius := (edge(a) * float(row[0]) + float(row[1])) * jag
				quad.append(Vector3(cos(a) * radius, float(row[2]) + (sin(a * 9.0 + float(corner[1])) * 0.8 if int(corner[1]) > 1 else 0.0), sin(a) * radius))
			var top: Color = bands[k].darkened(0.05 * float(s % 3))
			var low: Color = bands[k + 1].darkened(0.05 * float(s % 3))
			StarRegionArt._triangle(cliff, quad[0], quad[1], quad[2], top, top, low)
			StarRegionArt._triangle(cliff, quad[0], quad[2], quad[3], top, low, low)
		var tip_a := Vector3(cos(a0) * 7.0, -34.0, sin(a0) * 7.0)
		var tip_b := Vector3(cos(a1) * 7.0, -34.0, sin(a1) * 7.0)
		StarRegionArt._triangle(cliff, tip_a, tip_b, Vector3(1.5, -41.0, -1.0), bands[6], bands[6], bands[6].darkened(0.15))
	StarRegionArt._mesh_node(root, cliff, StarRegionArt._material("solid"), "SkyIsleCliff")
	var body := StaticBody3D.new()
	body.name = "SkyIsleGroundCollision"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 1.0
	shape.shape = cylinder
	shape.position.y = -0.5
	body.add_child(shape)
	root.add_child(body)


static func _underside(c: Dictionary) -> void:
	# Hanging strata under the isle: inverted spires that show through the bays.
	for i in 16:
		var a := TAU * float(i) / 16.0 + 0.2
		var r := edge(a) * (0.72 if i % 2 == 0 else 0.5)
		var h := 9.0 + float(i % 4) * 3.0
		StarRegionArt._put(c, "crystal", Vector3(cos(a) * r, -13.0 - h * 0.5 - float(i % 3) * 2.0, sin(a) * r), Vector3(5.5, h, 5.5), ROCK_DEEP.lerp(ROCK, 0.3), Vector3(PI, a, 0))


static func _cloud_sea(c: Dictionary) -> void:
	var root: Node3D = c.root
	var rng: RandomNumberGenerator = c.rng
	# Far below the banks of cloud the sky goes on: one disc of deep blue air that hazes
	# out to gold at the horizon, so the gaps between the clouds read as a long way down.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.0, 45.0, 90.0, 140.0, 200.0, 300.0]
	var tones := [Color("2a6cc4"), Color("3a80d4"), Color("5c9fe2"), Color("92c2ec"), Color("d6dde0"), HAZE]
	for ring in radii.size() - 1:
		for sector in 48:
			var a0 := TAU * float(sector) / 48.0
			var a1 := TAU * float(sector + 1) / 48.0
			var r0: float = radii[ring]
			var r1: float = radii[ring + 1]
			var y0 := -52.0 + sin(a0 * 5.0 + float(ring)) * 0.8
			var y1 := -52.0 + sin(a1 * 5.0 + float(ring)) * 0.8
			var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, y1, sin(a1) * r0)
			var p2 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var p3 := Vector3(cos(a0) * r1, y0, sin(a0) * r1)
			var wobble := 0.04 * sin(float(sector) * 1.9 + float(ring) * 2.3)
			var inner: Color = (tones[ring] as Color).darkened(maxf(wobble, 0.0))
			var outer: Color = (tones[ring + 1] as Color).darkened(maxf(-wobble, 0.0))
			StarRegionArt._triangle(st, p0, p2, p1, inner, outer, inner)
			StarRegionArt._triangle(st, p0, p3, p2, inner, outer, outer)
	_special_mesh(root, st, 3, "SkyBelow")
	# The cloud deck right under the isle, which the bays and the rim look down on.
	var deck := 44 if GameSettings.quality >= 1 else 26
	for i in deck:
		var a := TAU * float(i) / float(deck) + rng.randf_range(-0.05, 0.05)
		var r := 40.0 + rng.randf() * 44.0
		var size := rng.randf_range(11.0, 20.0)
		_sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * rng.randf_range(0.34, 0.5), size * rng.randf_range(0.65, 0.95))),
			Vector3(cos(a) * r, rng.randf_range(-36.0, -24.0), sin(a) * r)), CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.55), 1)
	# Banks of cloud on it, and wisps that hang just under the rim.
	var banks := 54 if GameSettings.quality >= 1 else 30
	for i in banks:
		var a := TAU * float(i) / float(banks) + rng.randf_range(-0.03, 0.03)
		var r := 30.0 + pow(rng.randf(), 0.7) * 150.0
		var size := rng.randf_range(16.0, 34.0)
		var tone := CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.7)
		_sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * rng.randf_range(0.28, 0.42), size * rng.randf_range(0.6, 0.9))),
			Vector3(cos(a) * r, -38.5 + rng.randf_range(0.0, 5.0), sin(a) * r)), tone, 1)
	for i in 16:
		var a := TAU * float(i) / 16.0 + rng.randf_range(-0.08, 0.08)
		var size := rng.randf_range(7.0, 13.0)
		_sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.34, size * 0.7)),
			_rim(a, rng.randf_range(2.0, 9.0), rng.randf_range(-17.0, -9.0))), CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.4), 1)


# ---------------------------------------------------------------------------
# Water: ponds, brooks, the falls off the edge
# ---------------------------------------------------------------------------

static func _waters(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var all := streams()
	for i in PONDS.size():
		var pond: Vector2 = PONDS[i]
		StarRegionArt._pool(c, Vector3(pond.x, 0.03, pond.y), Vector2(4.4, 3.4), WATER.darkened(0.12), "LotusPond_%d" % i)
		for k in 6:
			var a := rng.randf() * TAU
			var at := Vector3(pond.x + cos(a) * rng.randf_range(0.6, 3.0), 0.06, pond.y + sin(a) * rng.randf_range(0.5, 2.3))
			StarRegionArt._put(c, "disc", at, Vector3.ONE * rng.randf_range(0.7, 1.1), Color("5fae6a"), Vector3(0, a, 0))
			if k % 2 == 0:
				StarRegionArt._put(c, "isle_bloom", at + Vector3(0, -0.2, 0), Vector3.ONE * 0.5, PEACH.lightened(0.2), Vector3(0, a, 0), "foliage")
		var line: PackedVector2Array = all[i]
		var points: Array = []
		for p in line:
			points.append(Vector3(p.x, 0.035, p.y))
		# The brook runs on over the lip of the bay.
		var last: Vector2 = line[line.size() - 1]
		var out := (last - line[line.size() - 2]).normalized()
		var lip := last + out * maxf(edge(atan2(last.y, last.x)) - last.length() + 0.4, 0.5)
		points.append(Vector3(lip.x, 0.035, lip.y))
		StarRegionArt._ribbon(c, points, 2.4, WATER, "Brook_%d" % i, "water")
		_fall(c, Vector3(lip.x, 0.03, lip.y), Vector3(out.x, 0, out.y), 2.6, 40.0, "BayFall_%d" % i)
		# Stepping stones at the brook's banks.
		for k in 5:
			var t := (float(k) + 0.5) / 5.0
			var at2 := line[0].lerp(last, t) + Vector2(-out.y, out.x) * (1.7 if k % 2 == 0 else -1.7)
			StarRegionArt._put(c, "rock", Vector3(at2.x, 0.1, at2.y), Vector3(1.0, 0.35, 0.8) * rng.randf_range(0.8, 1.3), Color("b9b3a2"), Vector3(0, rng.randf() * TAU, 0))
	# Rim falls: water spilling from the cliff face all round the isle.
	var falls := [0.95, 2.45, 3.45, 4.75, 5.55, 0.0]
	for i in falls.size():
		var a: float = falls[i]
		var top := _rim(a, -0.3, -1.6)
		_fall(c, top, Vector3(cos(a), 0, sin(a)), 3.4, 38.0, "RimFall_%d" % i)
		StarRegionArt._put(c, "rock", top + Vector3(0, 0.3, 0), Vector3(4.6, 1.4, 2.6), ROCK.lightened(0.1), Vector3(0, -a + PI * 0.5, 0))


## A sheet of water that arcs off a lip and falls `drop` metres into the cloud.
static func _fall(c: Dictionary, top: Vector3, out: Vector3, width: float, drop: float, label: String) -> void:
	var side := Vector3(-out.z, 0, out.x)
	var profile := [[0.0, 0.0], [0.5, -0.12], [1.1, -0.8], [1.7, -2.6], [2.2, -6.0], [2.6, -12.0], [2.9, -22.0], [3.1, -drop]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	var rows: Array = []
	for i in profile.size():
		var p: Vector3 = top + out * float(profile[i][0]) + Vector3(0, float(profile[i][1]), 0)
		if i > 0:
			length += p.distance_to(rows[i - 1][0])
		var t := float(i) / float(profile.size() - 1)
		rows.append([p, width * (1.0 + 0.55 * t) * 0.5, length / 5.0, WATER.lerp(Color.WHITE, 0.45 + 0.4 * minf(t * 3.0, 1.0))])
	for i in rows.size() - 1:
		var quad := [[rows[i], -1.0], [rows[i], 1.0], [rows[i + 1], 1.0], [rows[i + 1], -1.0]]
		for corner in [0, 1, 2, 0, 2, 3]:
			var row: Array = quad[corner][0]
			var s: float = quad[corner][1]
			st.set_color(row[3])
			st.set_uv(Vector2(s * 0.5 + 0.5, float(row[2])))
			st.add_vertex((row[0] as Vector3) + side * (float(row[1]) * s))
	_special_mesh(c.root, st, 0, label)
	# Spray where the fall meets the cloud.
	_sp(c, "isle_puff", Transform3D(Basis.from_scale(Vector3(9.0, 3.2, 7.0)), top + out * 3.4 + Vector3(0, -drop + 4.0, 0)), CLOUD, 1)


# ---------------------------------------------------------------------------
# Paving, the shrine and its court, the entrance
# ---------------------------------------------------------------------------

static func _paving(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var info: Dictionary = c.layout
	# Flagstones along every way: three across the main way, two on the branches.
	for index in info.paths.size():
		var path: PackedVector2Array = info.paths[index]
		var across := 3 if index == 0 else 2
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			var steps := int((b - a).length() / 1.45)
			for k in steps:
				var along := a + dir * (float(k) + 0.5) * 1.45
				if along.length() > 53.0:
					continue
				for j in across:
					var offset := (float(j) - float(across - 1) * 0.5) * 1.45 + rng.randf_range(-0.12, 0.12)
					var at := along + normal * offset + dir * rng.randf_range(-0.15, 0.15)
					var tone := IVORY.darkened(rng.randf_range(0.0, 0.14)).lerp(JADE_PALE, 0.25 if (k + j) % 7 == 0 else 0.0)
					StarRegionArt._put(c, "box", Vector3(at.x, 0.025, at.y), Vector3(rng.randf_range(1.05, 1.32), 0.05, rng.randf_range(1.05, 1.32)), tone, Vector3(0, -atan2(dir.y, dir.x) + rng.randf_range(-0.1, 0.1), 0))
			# Stone lanterns beside the way.
			var lamps := int((b - a).length() / 9.0)
			for k in lamps:
				var along2 := a + dir * (float(k) + 0.5) * ((b - a).length() / float(lamps))
				var at2 := along2 + normal * ((2.9 if index > 0 else 3.6) * (1.0 if (k + i) % 2 == 0 else -1.0))
				if at2.length() < 52.0 and _clear_of_features(at2, 0.6):
					_lantern(c, Vector3(at2.x, 0, at2.y), 1.0)


## A flat band of inlay on the ground, `radius` round.
static func _band(c: Dictionary, centre: Vector3, radius: float, width: float, tone: Color) -> void:
	var n := maxi(12, int(radius * 3.2))
	for i in n:
		var a := TAU * float(i) / float(n)
		StarRegionArt._put(c, "box", centre + Vector3(cos(a) * radius, 0.045, sin(a) * radius), Vector3(width, 0.05, TAU * radius / float(n) * 1.04), tone, Vector3(0, -a, 0))


static func _lantern(c: Dictionary, p: Vector3, size: float) -> void:
	StarRegionArt._put(c, "box", p + Vector3(0, 0.14, 0) * size, Vector3(0.8, 0.28, 0.8) * size, IVORY.darkened(0.12))
	StarRegionArt._put(c, "pillar", p + Vector3(0, 0.75, 0) * size, Vector3(0.26, 1.0, 0.26) * size, IVORY.darkened(0.05))
	StarRegionArt._put(c, "box", p + Vector3(0, 1.3, 0) * size, Vector3(0.7, 0.12, 0.7) * size, GOLD)
	StarRegionArt._put(c, "crystal", p + Vector3(0, 1.62, 0) * size, Vector3(0.36, 0.5, 0.36) * size, Color("ffe7a8"), Vector3.ZERO, "glow")
	StarRegionArt._put(c, "isle_roof", p + Vector3(0, 1.86, 0) * size, Vector3(1.0, 0.42, 1.0) * size, TEAL)


static func _pillar(c: Dictionary, p: Vector3, height: float, radius: float, collide := true) -> void:
	StarRegionArt._put(c, "box", p + Vector3(0, 0.22, 0), Vector3(radius * 3.4, 0.44, radius * 3.4), IVORY.darkened(0.08))
	StarRegionArt._put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(radius * 2.0, height, radius * 2.0), VERMILION)
	StarRegionArt._put(c, "pillar", p + Vector3(0, height * 0.82, 0), Vector3(radius * 2.2, 0.22, radius * 2.2), GOLD)
	StarRegionArt._put(c, "box", p + Vector3(0, height, 0), Vector3(radius * 3.0, 0.3, radius * 3.0), GOLD)
	if collide and Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, radius + 0.25))


## A dragon coiled round a pillar on a plinth, `height` metres tall, facing `yaw`.
static func _statue(c: Dictionary, p: Vector3, height: float, yaw: float, tone: Color, collide := true) -> void:
	var plinth := height * 0.16
	StarRegionArt._put(c, "box", p + Vector3(0, plinth * 0.5, 0), Vector3(height * 0.62, plinth, height * 0.62), IVORY.darkened(0.1), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", p + Vector3(0, plinth, 0), Vector3(height * 0.7, plinth * 0.2, height * 0.7), GOLD, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "pillar", p + Vector3(0, plinth + height * 0.36, 0), Vector3(height * 0.2, height * 0.72, height * 0.2), IVORY.darkened(0.16))
	StarRegionArt._put(c, "isle_dragon", p + Vector3(0, plinth, 0), Vector3.ONE * height, tone, Vector3(0, yaw, 0), "mineral")
	# The pearl it guards.
	StarRegionArt._put(c, "willow_frond", p + Vector3(0, plinth + height * 0.8, 0), Vector3.ONE * height * 0.13, Color("fff3c4"), Vector3.ZERO, "glow")
	if collide and Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, height * 0.34))


## A roofed gate across a way: two vermilion pillars, gold lintels, a teal roof.
static func _gate(c: Dictionary, p: Vector3, yaw: float, width: float, height: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for side in [-1.0, 1.0]:
		_pillar(c, p + basis * Vector3(side * width * 0.5, 0, 0), height, 0.42)
	StarRegionArt._put(c, "box", p + Vector3(0, height * 0.86, 0), Vector3(width * 1.25, 0.42, 0.5), GOLD, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", p + Vector3(0, height + 0.2, 0), Vector3(width * 1.5, 0.5, 0.8), VERMILION.darkened(0.12), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "isle_roof", p + Vector3(0, height + 0.45, 0), Vector3(width * 1.9, 1.5, 2.6), TEAL, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, height + 2.1, 0), Vector3(0.4, 0.8, 0.4), GOLD, Vector3.ZERO, "glow")
	# A plaque and silk streamers.
	StarRegionArt._put(c, "box", p + Vector3(0, height * 0.86 - 0.75, 0), Vector3(1.9, 0.9, 0.16), JADE.darkened(0.25), Vector3(0, yaw, 0))
	for side in [-1.0, 1.0]:
		_streamer(c, p + basis * Vector3(side * width * 0.62, height * 0.9, 0), 3.4, 0.5, VERMILION if side < 0 else GOLD)


static func _streamer(c: Dictionary, p: Vector3, length: float, width: float, tone: Color) -> void:
	var side := Vector3(-WIND.z, 0, WIND.x)
	_sp(c, "isle_streamer", Transform3D(Basis(WIND * length, Vector3.UP * width, side), p), tone, 2)


## A tiered hall: vermilion walls, teal roofs with upturned eaves, a gold finial.
static func _pagoda(c: Dictionary, p: Vector3, yaw: float, size: float, tiers: int) -> void:
	var y := 0.0
	var w := 10.0 * size
	var d := 7.4 * size
	StarRegionArt._put(c, "box", p + Vector3(0, 0.4 * size, 0), Vector3(w * 1.25, 0.8 * size, d * 1.3), IVORY, Vector3(0, yaw, 0))
	y += 0.8 * size
	var basis := Basis(Vector3.UP, yaw)
	for tier in tiers:
		var h := (3.6 - float(tier) * 0.5) * size
		StarRegionArt._put(c, "box", p + Vector3(0, y + h * 0.5, 0), Vector3(w, h, d), VERMILION.darkened(0.04 * float(tier)), Vector3(0, yaw, 0))
		StarRegionArt._put(c, "box", p + Vector3(0, y + h * 0.5, 0), Vector3(w * 1.02, h * 0.16, d * 1.02), GOLD, Vector3(0, yaw, 0))
		if tier == 0:
			# The doorway and its columns face the court.
			StarRegionArt._put(c, "box", p + basis * Vector3(0, y + h * 0.42, d * 0.5 + 0.05), Vector3(w * 0.26, h * 0.84, 0.16), Color("5a2a1c"), Vector3(0, yaw, 0))
			for x in [-0.42, -0.2, 0.2, 0.42]:
				StarRegionArt._put(c, "pillar", p + basis * Vector3(x * w, y + h * 0.5, d * 0.5 + 0.7 * size), Vector3(0.5 * size, h, 0.5 * size), VERMILION.lightened(0.06))
		y += h
		StarRegionArt._put(c, "isle_roof", p + Vector3(0, y, 0), Vector3(w * 1.55, 2.4 * size, d * 1.7), TEAL.lerp(JADE, 0.2 * float(tier)), Vector3(0, yaw, 0))
		StarRegionArt._put(c, "box", p + Vector3(0, y + 0.05, 0), Vector3(w * 1.12, 0.22 * size, d * 1.16), GOLD, Vector3(0, yaw, 0))
		y += 1.1 * size
		w *= 0.68
		d *= 0.68
	StarRegionArt._put(c, "crystal", p + Vector3(0, y + 1.9 * size, 0), Vector3(0.7, 2.2, 0.7) * size, GOLD, Vector3.ZERO, "glow")


static func _shrine(c: Dictionary) -> void:
	var info: Dictionary = c.layout
	var boss: Vector3 = info.boss_pos
	var out := Vector3(cos(SHRINE_ANGLE), 0, sin(SHRINE_ANGLE))
	var side := Vector3(-out.z, 0, out.x)
	var yaw := atan2(-out.x, -out.z)
	# The Dragon God's court: rings of jade and ivory tiles, gold bands, a sun medallion.
	var rings := [[3.4, 9], [5.8, 16], [8.2, 22], [10.6, 29], [12.9, 36]]
	for k in rings.size():
		var r: float = rings[k][0]
		var n: int = rings[k][1]
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(k % 2)) / float(n)
			var tone := (JADE_PALE if (i + k) % 2 == 0 else IVORY).darkened(0.03 * float((i * 7 + k) % 3))
			StarRegionArt._put(c, "box", boss + Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(2.1, 0.06, TAU * r / float(n) * 0.94), tone, Vector3(0, -a, 0))
	for r in [4.6, 9.4, 14.1]:
		_band(c, boss, r, 0.3, GOLD)
	StarRegionArt._put(c, "disc", boss + Vector3(0, 0.07, 0), Vector3(4.4, 1, 4.4), GOLD)
	StarRegionArt._put(c, "disc", boss + Vector3(0, 0.085, 0), Vector3(3.4, 1, 3.4), JADE)
	for i in 8:
		var a := TAU * float(i) / 8.0
		StarRegionArt._put(c, "box", boss + Vector3(cos(a) * 1.0, 0.1, sin(a) * 1.0), Vector3(1.5, 0.03, 0.22), GOLD.lightened(0.2), Vector3(0, -a, 0))
	# Eight vermilion pillars with lamps and streamers ring the court (two stand aside
	# for the way in and the way up to the shrine).
	var way_in := atan2(-8.0 - boss.z, 20.0 - boss.x)
	for i in 10:
		var a := TAU * float(i) / 10.0 + 0.31
		if absf(wrapf(a - way_in, -PI, PI)) < 0.34 or absf(wrapf(a - SHRINE_ANGLE, -PI, PI)) < 0.34:
			continue
		var at := boss + Vector3(cos(a) * 15.6, 0, sin(a) * 15.6)
		_pillar(c, at, 4.6, 0.36)
		StarRegionArt._put(c, "crystal", at + Vector3(0, 5.2, 0), Vector3(0.5, 0.9, 0.5), Color("ffe7a8"), Vector3.ZERO, "glow")
		_streamer(c, at + Vector3(0, 4.3, 0), 3.6, 0.5, [VERMILION, GOLD, JADE, IVORY][i % 4])
	# Incense braziers at the court's four corners.
	for i in 4:
		var a := SHRINE_ANGLE + PI * 0.25 + PI * 0.5 * float(i)
		var at := boss + Vector3(cos(a) * 11.6, 0, sin(a) * 11.6)
		StarRegionArt._put(c, "pillar", at + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5), GOLD.darkened(0.25))
		StarRegionArt._put(c, "pillar", at + Vector3(0, 1.0, 0), Vector3(1.3, 0.4, 1.3), GOLD)
		StarRegionArt._put(c, "crystal", at + Vector3(0, 1.5, 0), Vector3(0.5, 0.8, 0.5), Color("ff9a4a"), Vector3.ZERO, "glow")
	# The processional way: a gate, guardian dragons, steps up the promontory.
	_gate(c, out * 50.5, yaw, 7.0, 6.2)
	for s in [-1.0, 1.0]:
		_statue(c, out * 47.0 + side * (s * 8.2), 5.4, yaw, JADE)
		for k in 3:
			_lantern(c, out * (52.5 + 3.0 * float(k)) + side * (s * 5.4), 1.15)
	for i in 6:
		StarRegionArt._put(c, "box", out * (56.4 + float(i) * 1.1) + Vector3(0, 0.14 + float(i) * 0.28, 0), Vector3(15.0 - float(i) * 0.5, 0.3, 1.2), IVORY.darkened(0.03 * float(i % 2)), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", out * 67.0 + Vector3(0, 0.9, 0), Vector3(22.0, 1.8, 11.0), IVORY.darkened(0.06), Vector3(0, yaw, 0))
	_pagoda(c, out * 67.6 + Vector3(0, 1.8, 0), yaw, 1.0, 3)
	for s in [-1.0, 1.0]:
		_statue(c, out * 63.0 + side * (s * 9.4) + Vector3(0, 1.8, 0), 7.5, yaw, GOLD, false)
	# The sun gate of the Dragon God rises behind the hall.
	var gate := out * 72.5 + Vector3(0, 13.5, 0)
	StarRegionArt._ring(c, gate, 9.5, 0.7, GOLD, Vector3(PI * 0.5, yaw, 0))
	StarRegionArt._ring(c, gate, 8.3, 0.2, JADE, Vector3(PI * 0.5, yaw, 0))
	for i in 12:
		var a := TAU * float(i) / 12.0
		var at := gate + Basis(Vector3.UP, yaw) * Vector3(cos(a) * 10.6, sin(a) * 10.6, 0)
		StarRegionArt._put(c, "crystal", at, Vector3(0.9, 2.2 if i % 2 == 0 else 1.4, 0.9), GOLD.lightened(0.15), Basis(Vector3.UP, yaw).get_euler() + Vector3(0, 0, a - PI * 0.5), "glow")


static func _entrance(c: Dictionary) -> void:
	var info: Dictionary = c.layout
	var spawn: Vector3 = info.spawn
	var path: PackedVector2Array = info.paths[0]
	var dir2 := (path[1] - Vector2(spawn.x, spawn.z)).normalized()
	var dir := Vector3(dir2.x, 0, dir2.y)
	var side := Vector3(-dir.z, 0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	# The arrival terrace: a round of tiles, the isle's gate and its two guardians.
	for k in 2:
		var r := 2.6 + 2.2 * float(k)
		var n := 8 + 6 * k
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(k)) / float(n)
			StarRegionArt._put(c, "box", spawn + Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(1.9, 0.06, TAU * r / float(n) * 0.93), (IVORY if (i + k) % 2 == 0 else JADE_PALE).darkened(0.04), Vector3(0, -a, 0))
	StarRegionArt._put(c, "disc", spawn + Vector3(0, 0.06, 0), Vector3(2.6, 1, 2.6), GOLD)
	StarRegionArt._put(c, "disc", spawn + Vector3(0, 0.075, 0), Vector3(1.9, 1, 1.9), JADE)
	_band(c, spawn, 6.0, 0.26, GOLD)
	_gate(c, spawn + dir * 8.6, yaw, 6.4, 5.6)
	for s in [-1.0, 1.0]:
		_statue(c, spawn + dir * 6.4 + side * (s * 6.6), 4.2, yaw + PI, JADE)
	# The stele that tells what the isle holds (Zone hangs the words over it).
	var stele := sign_spot()
	StarRegionArt._put(c, "box", stele + Vector3(0, 0.2, 0), Vector3(2.0, 0.4, 1.0), IVORY.darkened(0.1), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", stele + Vector3(0, 1.5, 0), Vector3(1.5, 2.2, 0.36), JADE.darkened(0.2), Vector3(0, yaw, 0), "mineral")
	StarRegionArt._put(c, "isle_roof", stele + Vector3(0, 2.6, 0), Vector3(2.2, 0.7, 1.1), GOLD, Vector3(0, yaw, 0))
	c.colliders.append(Vector3(stele.x, stele.z, 0.9))


## Where the entrance stele stands (Zone hangs the drop sign over it).
static func sign_spot() -> Vector3:
	return (layout().spawn as Vector3) + Vector3(5.2, 0, 5.4)


# ---------------------------------------------------------------------------
# The dragon graveyard, the camps
# ---------------------------------------------------------------------------

static func _graveyard(c: Dictionary) -> void:
	var info: Dictionary = c.layout
	var camp: Vector2 = info.camp_positions[5]
	var axis2 := (Vector2(-2, -8) - Vector2(-12, 10)).normalized()
	var axis := Vector3(axis2.x, 0, axis2.y)
	var side := Vector3(-axis.z, 0, axis.x)
	var centre := Vector3(camp.x, 0, camp.y)
	# Five pairs of ribs stand round the camp and hook in over it.
	for i in 5:
		var along := -9.0 + float(i) * 4.5
		var span := 10.8 - absf(float(i) - 2.0) * 0.5
		var size := 9.6 - absf(float(i) - 2.0) * 0.9
		for s in [-1.0, 1.0]:
			var base: Vector3 = centre + axis * along + side * (s * span)
			if StarRegionArt._path_distance(Vector2(base.x, base.z), info.paths) < 3.2:
				continue
			var inward: Vector3 = -side * s
			var basis := Basis(inward, Vector3.UP, inward.cross(Vector3.UP)).scaled(Vector3.ONE * size)
			StarRegionArt._queue(c, "isle_rib", Transform3D(basis, base), BONE.darkened(0.04 * float(i % 2)), "solid")
			StarRegionArt._put(c, "rock", base + Vector3(0, 0.2, 0), Vector3(1.5, 0.7, 1.5), BONE.darkened(0.14), Vector3(0, float(i), 0))
			c.colliders.append(Vector3(base.x, base.z, 0.55))
	# The skull rests beside the way out, and the tail's vertebrae trail off behind.
	var skull := centre + axis * 16.0 + side * 7.0
	StarRegionArt._put(c, "isle_skull", skull, Vector3.ONE * 7.2, BONE, Vector3(0, atan2(-axis.x - side.x * 0.5, -axis.z - side.z * 0.5), 0))
	c.colliders.append(Vector3(skull.x, skull.z, 2.4))
	for i in 7:
		var at := centre - axis * (12.5 + float(i) * 1.7) - side * (7.5 + float(i) * 0.9)
		if _clear_of_features(Vector2(at.x, at.z), 0.5):
			StarRegionArt._put(c, "pillar", at + Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 1.3) * (1.0 - float(i) * 0.09), BONE.darkened(0.08), Vector3(PI * 0.5, atan2(axis.x, axis.z) + 0.3, 0))


static func _camp_dressing(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var info: Dictionary = c.layout
	for index in 5:
		var camp: Vector2 = info.camp_positions[index]
		for i in 9:
			var a := TAU * float(i) / 9.0 + float(index) * 0.7
			var p2 := camp + Vector2(cos(a), sin(a)) * rng.randf_range(11.0, 12.6)
			if not _clear_of_features(p2, 1.2) or p2.length() > 52.0:
				continue
			var p := Vector3(p2.x, 0, p2.y)
			match index:
				0:
					# The whelps' nests: a ring of woven rock with pale blue eggs.
					for k in 6:
						var b := TAU * float(k) / 6.0
						StarRegionArt._put(c, "rock", p + Vector3(cos(b) * 0.9, 0.2, sin(b) * 0.9), Vector3(0.9, 0.5, 0.7), Color("b5a58c"), Vector3(0, b, 0))
					for k in 3:
						StarRegionArt._put(c, "willow_frond", p + Vector3(cos(k * 2.1) * 0.35, 0.42, sin(k * 2.1) * 0.35), Vector3(0.42, 0.56, 0.42), Color("d6f2ff"), Vector3(0.2 * k, 0, 0.15), "glow")
				1:
					# Jade outcrops the drakes sharpen their scales on.
					for k in 3:
						StarRegionArt._put(c, "crystal", p + Vector3(cos(k * 2.2) * 0.6, 0.7 + 0.3 * k, sin(k * 2.2) * 0.6), Vector3(0.8, 1.8 + 0.7 * k, 0.8), JADE.lerp(JADE_PALE, 0.25 * k), Vector3(0.25 * (k - 1), a, 0.2 * (1 - k)), "mineral")
					c.colliders.append(Vector3(p.x, p.z, 0.8))
				2:
					# The gold wyrmlings' hoard: coins, ingots and a gem.
					StarRegionArt._put(c, "willow_frond", p + Vector3(0, 0.25, 0), Vector3(1.9, 0.7, 1.7), GOLD.darkened(0.08))
					for k in 5:
						StarRegionArt._put(c, "pillar", p + Vector3(cos(k * 1.3) * 0.8, 0.5 + 0.05 * k, sin(k * 1.3) * 0.8), Vector3(0.34, 0.07, 0.34), GOLD.lightened(0.15), Vector3(0.5 * (k % 2), k, 0.3))
					StarRegionArt._put(c, "crystal", p + Vector3(0, 0.85, 0), Vector3(0.3, 0.5, 0.3), [Color("ff6a7a"), Color("7ad8ff"), JADE][i % 3], Vector3.ZERO, "glow")
				3:
					# Peach trees round the kirin meadow.
					_blossom_tree(c, p, rng.randf_range(4.6, 6.2), PEACH)
				4:
					# Storm-struck crags with violet lightning glass.
					var h := rng.randf_range(2.6, 4.4)
					StarRegionArt._put(c, "crystal", p + Vector3(0, h * 0.5, 0), Vector3(1.5, h, 1.5), Color("7c7488"), Vector3(0.12, a, -0.1))
					StarRegionArt._put(c, "crystal", p + Vector3(0.5, h * 0.55, 0.3), Vector3(0.5, h * 0.6, 0.5), Color("b08cff"), Vector3(0.3, a, 0.35), "glow")
					c.colliders.append(Vector3(p.x, p.z, 0.8))


# ---------------------------------------------------------------------------
# Trees, the rim, the islets
# ---------------------------------------------------------------------------

static func _planting(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	for i in 120:
		var a := rng.randf() * TAU
		var r := 8.0 + sqrt(rng.randf()) * 45.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _clear(p, 1.6):
			continue
		match i % 6:
			0, 1: StarRegionArt._tree(c, p, rng.randf_range(4.6, 7.0), GINKGO.lerp(Color("f39a3c"), rng.randf() * 0.4), Color("7a5f4c"), false, true)
			2: _blossom_tree(c, p, rng.randf_range(4.2, 6.0), PEACH.lerp(Color("ffd9e2"), rng.randf() * 0.5))
			3: StarRegionArt._cypress(c, p, rng.randf_range(3.6, 5.6), PINE, true)
			4:
				var s := rng.randf_range(1.0, 2.2)
				StarRegionArt._put(c, "rock", p + Vector3(0, s * 0.22, 0), Vector3(1.5, 0.75, 1.3) * s, Color("b3a694"), Vector3(0, a, 0))
				StarRegionArt._put(c, "isle_bush", p + Vector3(0.3 * s, s * 0.5, 0), Vector3(0.9, 0.4, 0.8) * s, GRASS_SUN.darkened(0.1), Vector3(0, a, 0), "foliage")
				if s > 1.5:
					c.colliders.append(Vector3(p.x, p.z, s * 0.5))
			5:
				# A wayside spirit house.
				StarRegionArt._put(c, "box", p + Vector3(0, 0.2, 0), Vector3(1.2, 0.4, 1.0), IVORY.darkened(0.1), Vector3(0, a, 0))
				StarRegionArt._put(c, "box", p + Vector3(0, 0.85, 0), Vector3(0.8, 0.9, 0.7), VERMILION, Vector3(0, a, 0))
				StarRegionArt._put(c, "isle_roof", p + Vector3(0, 1.3, 0), Vector3(1.5, 0.6, 1.3), TEAL, Vector3(0, a, 0))
				StarRegionArt._put(c, "crystal", p + Vector3(0, 2.0, 0), Vector3(0.14, 0.3, 0.14), GOLD, Vector3.ZERO, "glow")
				c.colliders.append(Vector3(p.x, p.z, 0.6))


## Low growth that never hides the hero: bush clumps, tall grass, drifts of gold leaves,
## and wisps of cloud that have settled on the isle near its rim and its bays.
static func _undergrowth(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var lush := 1.0 if GameSettings.quality >= 1 else 0.55
	for i in int(150 * lush):
		var a := rng.randf() * TAU
		var r := 6.0 + sqrt(rng.randf()) * 48.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _clear(p, 0.9):
			continue
		match i % 4:
			0, 1:
				var tone: Color = [GRASS.darkened(0.12), PINE.lightened(0.15), GRASS_SUN, GINKGO.lerp(GRASS_SUN, 0.5)][i % 4 + (i / 4) % 2]
				for k in 2:
					var off := Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-1.1, 1.1))
					var s := rng.randf_range(0.9, 1.6)
					StarRegionArt._put(c, "isle_bush", p + off + Vector3(0, s * 0.3, 0), Vector3(1.5, 0.85, 1.35) * s, tone.darkened(0.06 * float(k)), Vector3(0, rng.randf() * TAU, 0), "foliage")
				if i % 8 == 0:
					StarRegionArt._put(c, "isle_bloom", p + Vector3(0, 0.75, 0), Vector3.ONE * 0.55, PEACH.lightened(0.15), Vector3(0, a, 0), "foliage")
			2:
				for k in 4:
					var off := Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3))
					StarRegionArt._put(c, "fern", p + off, Vector3.ONE * rng.randf_range(0.7, 1.15), GRASS_SUN.lerp(GRASS, rng.randf()), Vector3(0, rng.randf() * TAU, 0), "foliage")
			3:
				# A drift of ginkgo leaves the wind has gathered.
				StarRegionArt._put(c, "disc", p + Vector3(0, 0.03, 0), Vector3(2.6, 1, 1.9) * rng.randf_range(0.7, 1.2), GINKGO.lerp(Color("f6dc7a"), rng.randf() * 0.5), Vector3(0, a, 0))
				for k in 6:
					var off := Vector3(rng.randf_range(-1.8, 1.8), 0.045, rng.randf_range(-1.5, 1.5))
					StarRegionArt._put(c, "box", p + off, Vector3(0.3, 0.01, 0.2), Color("f39a3c").lerp(GINKGO, rng.randf()), Vector3(0, rng.randf() * TAU, 0))
	# Settled cloud: low enough to wade through.
	var wisps := 22 if GameSettings.quality >= 1 else 12
	for i in wisps:
		var a := TAU * float(i) / float(wisps) + rng.randf_range(-0.07, 0.07)
		var r := edge(a) - rng.randf_range(0.5, 5.5)
		var size := rng.randf_range(3.2, 6.0)
		var p := Vector3(cos(a) * r, 0.25, sin(a) * r)
		if StarRegionArt._path_distance(Vector2(p.x, p.z), (c.layout as Dictionary).paths) < 4.5:
			continue
		_sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.2, size * 0.7)), p), CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.25), 1)


## A blossoming tree: StarRegionArt's tree (its camera rule included) with light tufts of
## blossom instead of five more crowns.
static func _blossom_tree(c: Dictionary, p: Vector3, height: float, leaf: Color) -> void:
	var before: int = (c.batches.get("trunk:solid", {"transforms": []}).transforms as Array).size()
	StarRegionArt._tree(c, p, height, leaf, Color("8a6a58"), false, true)
	if (c.batches.get("trunk:solid", {"transforms": []}).transforms as Array).size() == before:
		return
	var placed: Transform3D = (c.batches["trunk:solid"].transforms as Array)[-1]
	var h := placed.basis.get_scale().y
	for i in 3:
		var a := TAU * float(i) / 3.0 + p.x
		StarRegionArt._put(c, "isle_bush", p + Vector3(cos(a) * h * 0.27, h * 0.88, sin(a) * h * 0.24), Vector3(h * 0.34, h * 0.2, h * 0.3), leaf.lightened(0.18), Vector3(0, a, 0), "foliage")


static func _in_bay(a: float, margin := 0.0) -> bool:
	for bay in BAYS:
		if absf(wrapf(a - float(bay[0]), -PI, PI)) < float(bay[1]) + margin:
			return true
	return false


static func _rim_dressing(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	# Boulders and tufts along the lip, streamer poles, floating rocks beyond it.
	for i in 96:
		var a := TAU * float(i) / 96.0
		if absf(wrapf(a - SHRINE_ANGLE, -PI, PI)) < 0.22:
			continue
		# The brooks' lips stay open, so the falls show.
		var lip := false
		for k in 4:
			lip = lip or absf(wrapf(a - float(BAYS[k][0]), -PI, PI)) < 0.07
		if lip:
			continue
		var s := rng.randf_range(1.2, 2.6)
		StarRegionArt._put(c, "rock", _rim(a, -0.4, 0.05), Vector3(2.0, 0.7, 1.4) * s, Color("b7a58c").darkened(rng.randf() * 0.15), Vector3(0, -a + rng.randf_range(-0.4, 0.4), 0))
		if i % 2 == 0:
			StarRegionArt._put(c, "isle_bush", _rim(a, -2.0, 0.3), Vector3(2.4, 0.8, 2.0) * rng.randf_range(0.7, 1.2), GRASS.lerp(GRASS_SUN, rng.randf()), Vector3(0, a, 0), "foliage")
	var tones := [VERMILION, GOLD, JADE, IVORY, PEACH]
	for i in 22:
		var a := TAU * float(i) / 22.0 + 0.11
		if _in_bay(a, 0.05) or absf(wrapf(a - SHRINE_ANGLE, -PI, PI)) < 0.3:
			continue
		var at := _rim(a, -3.2)
		var h := 5.4 + float(i % 3) * 0.8
		StarRegionArt._put(c, "pillar", at + Vector3(0, h * 0.5, 0), Vector3(0.16, h, 0.16), Color("7a4a34"))
		StarRegionArt._put(c, "crystal", at + Vector3(0, h + 0.2, 0), Vector3(0.24, 0.5, 0.24), GOLD, Vector3.ZERO, "glow")
		_streamer(c, at + Vector3(0, h - 0.5, 0), rng.randf_range(4.0, 6.0), 0.6, tones[i % tones.size()])
		_streamer(c, at + Vector3(0, h - 1.5, 0), rng.randf_range(2.6, 3.8), 0.42, tones[(i + 2) % tones.size()])
	var rocks := 34 if GameSettings.quality >= 1 else 20
	for i in rocks:
		var a := TAU * float(i) / float(rocks) + rng.randf_range(-0.06, 0.06)
		var s := rng.randf_range(1.6, 4.6)
		var at := _rim(a, rng.randf_range(2.5, 11.0), rng.randf_range(-7.0, 2.5))
		StarRegionArt._put(c, "island", at, Vector3(s * 1.5, s * 1.3, s * 1.3), ROCK.lerp(ROCK_DEEP, rng.randf() * 0.5), Vector3(0, a, 0))
		StarRegionArt._put(c, "disc", at + Vector3(0, s * 0.66, 0), Vector3(s * 1.46, 1, s * 1.26), GRASS.lerp(GRASS_SUN, rng.randf()), Vector3(0, a, 0))
		if i % 3 == 0:
			StarRegionArt._put(c, "isle_bush", at + Vector3(0, s * 0.66 + 0.5, 0), Vector3(1.8, 1.1, 1.6), [GINKGO, PEACH, PINE][i % 3 if i % 9 != 0 else 2], Vector3(0, a, 0), "foliage")


## A floating islet: a rock with a grass top at `p` (the top's centre), `r` metres round.
static func _islet(c: Dictionary, p: Vector3, r: float, depth: float, yaw := 0.0) -> void:
	StarRegionArt._put(c, "island", p - Vector3(0, depth * 0.5, 0), Vector3(r * 2.0, depth, r * 1.8), ROCK.lerp(ROCK_DEEP, 0.25), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "disc", p + Vector3(0, 0.04, 0), Vector3(r * 1.96, 1, r * 1.76), GRASS.lerp(GRASS_SUN, 0.5), Vector3(0, yaw, 0))
	for i in 5:
		var a := TAU * float(i) / 5.0 + yaw
		StarRegionArt._put(c, "crystal", p + Vector3(cos(a) * r * 0.5, -depth * 0.75, sin(a) * r * 0.45), Vector3(r * 0.35, depth * 0.7, r * 0.35), ROCK_DEEP, Vector3(PI, a, 0))


## A chain that sags from `a` to `b`.
static func _chain(c: Dictionary, a: Vector3, b: Vector3, sag: float) -> void:
	var last := a
	for i in 10:
		var t := float(i + 1) / 10.0
		var at := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0)
		StarRegionArt._segment(c, last, at, 0.3 if i % 2 == 0 else 0.22, Color("8a6f3a") if i % 2 == 0 else GOLD.darkened(0.2))
		last = at


static func _islets(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	# One islet drifts low in the mouth of every bay, in sight of the way past it.
	for i in BAYS.size():
		# (to one side of the brook's fall, which drops down the middle).
		var a: float = float(BAYS[i][0]) + float(BAYS[i][1]) * (0.75 if i % 2 == 0 else -0.75)
		var p := Vector3(cos(a), 0, sin(a)) * (float(BAYS[i][2]) + 15.0) + Vector3(0, -7.0 - float(i % 3) * 2.0, 0)
		_islet(c, p, 4.6, 9.0, a)
		# Cloud at three depths under the bay.
		for k in 3:
			var b: float = float(BAYS[i][0]) + rng.randf_range(-0.12, 0.12)
			var size := 9.0 + 4.0 * float(k)
			_sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.4, size * 0.8)),
				Vector3(cos(b), 0, sin(b)) * (float(BAYS[i][2]) + 6.0 + 7.0 * float(k)) + Vector3(0, -14.0 - 9.0 * float(k), 0)), CLOUD.lerp(CLOUD_WARM, 0.2 * float(k)), 1)
		match i % 3:
			0:
				StarRegionArt._put(c, "trunk", p, Vector3(2.6, 6.5, 2.6), Color("7a5f4c"), Vector3(0, a, 0))
				StarRegionArt._put(c, "crown", p + Vector3(0, 4.8, 0), Vector3(7.0, 3.2, 6.4), GINKGO, Vector3(0, a, 0), "foliage")
			1:
				_statue(c, p, 5.0, a + PI, GOLD, false)
			2:
				StarRegionArt._put(c, "box", p + Vector3(0, 1.3, 0), Vector3(3.0, 2.6, 3.0), VERMILION, Vector3(0, a, 0))
				StarRegionArt._put(c, "isle_roof", p + Vector3(0, 2.6, 0), Vector3(5.4, 2.0, 5.4), TEAL, Vector3(0, a, 0))
				StarRegionArt._put(c, "crystal", p + Vector3(0, 5.0, 0), Vector3(0.4, 1.0, 0.4), GOLD, Vector3.ZERO, "glow")
		_chain(c, _rim(float(BAYS[i][0]) + float(BAYS[i][1]) * (1.15 if i % 2 == 0 else -1.15), -1.0, -0.4), p + Vector3(0, -1.0, 0), 3.0)
	# The outer chain of isles: each its own height, with a tree, a tower, a fall or bones.
	var ring := [[0.62, 84.0, -9.0, 13.0], [1.4, 92.0, 3.0, 11.0], [2.2, 86.0, -12.0, 15.0], [2.75, 98.0, -4.0, 10.0], [3.45, 90.0, -15.0, 14.0],
		[4.25, 88.0, -6.0, 12.0], [4.95, 96.0, 2.0, 11.0], [5.75, 104.0, -10.0, 14.0], [0.1, 96.0, -14.0, 12.0]]
	for i in ring.size():
		var a: float = ring[i][0]
		var r: float = ring[i][3]
		var p := Vector3(cos(a) * float(ring[i][1]), float(ring[i][2]), sin(a) * float(ring[i][1]))
		_islet(c, p, r, r * 1.5, a)
		match i % 4:
			0:
				_pagoda(c, p, a + PI * 0.5, 0.62, 2)
			1:
				StarRegionArt._put(c, "trunk", p, Vector3(4.4, 11.0, 4.4), Color("7a5f4c"), Vector3(0, a, 0))
				StarRegionArt._put(c, "crown", p + Vector3(0, 8.2, 0), Vector3(12.0, 5.4, 11.0), PEACH if i % 8 == 1 else GINKGO, Vector3(0, a, 0), "foliage")
				StarRegionArt._put(c, "crown", p + Vector3(2.5, 6.4, 1.5), Vector3(7.0, 3.4, 6.4), (PEACH if i % 8 == 1 else GINKGO).darkened(0.08), Vector3(0, a + 1.0, 0), "foliage")
			2:
				StarRegionArt._put(c, "isle_skull", p + Vector3(0, 0.1, 0), Vector3.ONE * (r * 0.9), BONE, Vector3(0, a + 2.0, 0))
				for k in 4:
					var inward := Vector3(cos(a + 1.2), 0, sin(a + 1.2))
					var base := p + Vector3(cos(a) * (float(k) * 2.0 - 3.0), 0, sin(a) * (float(k) * 2.0 - 3.0)) - inward * 4.5
					StarRegionArt._queue(c, "isle_rib", Transform3D(Basis(inward, Vector3.UP, inward.cross(Vector3.UP)).scaled(Vector3.ONE * 6.0), base), BONE, "solid")
			3:
				StarRegionArt._pool(c, p + Vector3(0, 0.08, 0), Vector2(r * 0.45, r * 0.36), WATER.darkened(0.1), "IslePool_%d" % i)
				_statue(c, p + Vector3(cos(a + 2.0) * r * 0.55, 0, sin(a + 2.0) * r * 0.55), 4.6, a, JADE, false)
		# Every isle spills a fall of its own toward the cloud.
		var out := Vector3(cos(a + 2.4 + float(i)), 0, sin(a + 2.4 + float(i)))
		_fall(c, p + out * (r * 0.86) + Vector3(0, -0.3, 0), out, 2.4, 40.0 + p.y, "IsleFall_%d" % i)
		if i % 2 == 0:
			_chain(c, _rim(a, -0.6, -1.0), p + Vector3(-cos(a) * r * 0.9, -1.5, -sin(a) * r * 0.9), 6.0)
	# Small drifting stones with a tuft of grass, strung between the isles.
	for i in 18:
		var a := rng.randf() * TAU
		var s := rng.randf_range(1.2, 3.0)
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(70.0, 108.0) + Vector3(0, rng.randf_range(-14.0, 6.0), 0)
		StarRegionArt._put(c, "island", at, Vector3(s * 1.4, s * 1.5, s * 1.2), ROCK.lerp(ROCK_DEEP, rng.randf() * 0.6), Vector3(0, a, 0))
		StarRegionArt._put(c, "disc", at + Vector3(0, s * 0.76, 0), Vector3(s * 1.36, 1, s * 1.16), GRASS_SUN, Vector3(0, a, 0))


## Colliders along the lip of every bay, so nobody walks out over the cloud.
static func _bay_fences(c: Dictionary) -> void:
	for bay in BAYS:
		var from: float = float(bay[0]) - float(bay[1]) * 1.02
		var to: float = float(bay[0]) + float(bay[1]) * 1.02
		var last := Vector3.INF
		var a := from
		while a <= to:
			var r := edge(a)
			if r < 57.5:
				var at := Vector3(cos(a) * (r + 2.3), 0, sin(a) * (r + 2.3))
				if last == Vector3.INF or at.distance_to(last) >= 2.6:
					c.colliders.append(Vector3(at.x, at.z, 2.8))
					last = at
			a += 0.004
		# Low marker stones on the lip itself.
		var n := 9
		for i in n:
			var b := lerpf(from, to, (float(i) + 0.5) / float(n))
			if edge(b) < 56.0:
				StarRegionArt._put(c, "rock", _rim(b, -0.5, 0.1), Vector3(1.5, 0.6, 1.1), Color("c9bda4"), Vector3(0, -b, 0))


# ---------------------------------------------------------------------------
# Placement rules
# ---------------------------------------------------------------------------

## Off the ways, the camps, the spawn, the court, the ponds, the brooks and the bays.
static func _clear(p: Vector3, radius: float) -> bool:
	var xz := Vector2(p.x, p.z)
	if not _clear_of_features(xz, radius):
		return false
	for camp in layout().camp_positions:
		if xz.distance_to(camp) < radius + 9.5:
			return false
	return true


## As _clear, but camps may be dressed at their own rim.
static func _clear_of_features(xz: Vector2, radius: float) -> bool:
	var info := layout()
	if StarRegionArt._path_distance(xz, info.paths) < radius + 3.3:
		return false
	if StarRegionArt._path_distance(xz, streams()) < radius + 2.0:
		return false
	for key in ["spawn", "boss_pos"]:
		var q: Vector3 = info[key]
		if xz.distance_to(Vector2(q.x, q.z)) < radius + (16.5 if key == "boss_pos" else 9.5):
			return false
	for pond in PONDS:
		if xz.distance_to(pond) < radius + 5.4:
			return false
	# The promontory's processional way stays open.
	var along := xz.dot(Vector2(cos(SHRINE_ANGLE), sin(SHRINE_ANGLE)))
	if along > 30.0 and absf(xz.dot(Vector2(-sin(SHRINE_ANGLE), cos(SHRINE_ANGLE)))) < radius + 11.0:
		return false
	if xz.length() > edge(atan2(xz.y, xz.x)) - 2.2 - radius:
		return false
	return true


# ---------------------------------------------------------------------------
# The moving batches (falls, clouds, streamers) and the isle's own shapes
# ---------------------------------------------------------------------------

static func _special_material(mode: int) -> ShaderMaterial:
	if not _materials.has(mode):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("mode", mode)
		_materials[mode] = material
	return _materials[mode]


static func _special_mesh(root: Node3D, st: SurfaceTool, mode: int, label: String) -> void:
	StarRegionArt._mesh_node(root, st, _special_material(mode), label)


static func _sp(c: Dictionary, kind: String, transform: Transform3D, col: Color, mode: int) -> void:
	var key := "%s:%d" % [kind, mode]
	if not c.special.has(key):
		c.special[key] = {"kind": kind, "mode": mode, "transforms": [], "colors": []}
	c.special[key].transforms.append(transform)
	c.special[key].colors.append(col)


static func _flush_special(c: Dictionary) -> void:
	var root: Node3D = c.root
	for key in c.special:
		var batch: Dictionary = c.special[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = StarRegionArt._shape(batch.kind)
		multi.instance_count = batch.transforms.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, batch.transforms[i])
			multi.set_instance_color(i, batch.colors[i])
		var node := MultiMeshInstance3D.new()
		node.name = String(key).replace(":", "_")
		node.multimesh = multi
		node.material_override = _special_material(int(batch.mode))
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
		root.set_meta("batched_instances", int(root.get_meta("batched_instances", 0)) + multi.instance_count)
		root.set_meta("surface_count", int(root.get_meta("surface_count", 0)) + 1)


## Registers the isle's meshes in StarRegionArt's shared shape cache (built once).
static func _register_shapes() -> void:
	for kind in ["isle_roof", "isle_dragon", "isle_rib", "isle_skull", "isle_puff", "isle_streamer", "isle_bush", "isle_bloom"]:
		if StarRegionArt._meshes.has(kind):
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			"isle_roof": _roof_geometry(st)
			"isle_dragon": _dragon_geometry(st)
			"isle_rib": _rib_geometry(st)
			"isle_skull": _skull_geometry(st)
			"isle_puff": _puff_geometry(st)
			"isle_streamer": _streamer_geometry(st)
			"isle_bush": _bush_geometry(st)
			"isle_bloom": _bloom_geometry(st)
		st.generate_normals()
		st.index()
		StarRegionArt._meshes[kind] = st.commit()


## A hipped roof with upturned corners, 1 x 1 x 1, its eaves at y = 0.
static func _roof_geometry(st: SurfaceTool) -> void:
	var levels := [[0.5, 0.0], [0.37, 0.2], [0.22, 0.46], [0.09, 0.78]]
	var rings: Array = []
	for k in levels.size():
		var half: float = levels[k][0]
		var y: float = levels[k][1]
		var lift := 0.22 * pow(1.0 - float(k) / 3.0, 2.0)
		var points: Array[Vector3] = []
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var next: Vector2 = Vector2(-corner.y, corner.x)
			var flare := 1.08 if k == 0 else 1.0
			points.append(Vector3(corner.x * half * flare, y + lift, corner.y * half * flare))
			var mid: Vector2 = (corner + next) * 0.5
			points.append(Vector3(mid.x * half, y, mid.y * half))
		rings.append(points)
	for k in levels.size() - 1:
		for i in 8:
			var j := (i + 1) % 8
			var low := Color.WHITE.darkened(0.16 - 0.05 * float(k) + (0.05 if i % 2 == 0 else 0.0))
			var high := Color.WHITE.darkened(0.1 - 0.05 * float(k))
			StarRegionArt._triangle(st, rings[k][i], rings[k + 1][j], rings[k][j], low, high, low)
			StarRegionArt._triangle(st, rings[k][i], rings[k + 1][i], rings[k + 1][j], low, high, high)
	for i in 8:
		StarRegionArt._triangle(st, rings[3][i], Vector3(0, 1.0, 0), rings[3][(i + 1) % 8])
	# The eaves' underside.
	for i in 8:
		StarRegionArt._triangle(st, rings[0][i], rings[0][(i + 1) % 8], Vector3(0, 0.02, 0), Color(0.7, 0.7, 0.7), Color(0.7, 0.7, 0.7), Color(0.6, 0.6, 0.6))


## A dragon coiled two and a half times up a pillar, 1 tall, looking along +Z.
static func _dragon_geometry(st: SurfaceTool) -> void:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 34:
		var t := float(i) / 33.0
		var angle := t * TAU * 2.5 + PI * 0.5
		var radius := 0.30 - 0.13 * t
		points.append(Vector3(cos(angle) * radius, 0.03 + t * 0.62, sin(angle) * radius))
		radii.append(lerpf(0.015, 0.075, minf(t * 3.5, 1.0)) * (1.0 - 0.2 * maxf(t - 0.6, 0.0)))
	for extra in [[Vector3(0.10, 0.74, 0.06), 0.06], [Vector3(0.05, 0.86, 0.14), 0.055], [Vector3(0.0, 0.93, 0.24), 0.055]]:
		points.append(extra[0])
		radii.append(extra[1])
	StarRegionArt._tube(st, points, radii, Color.WHITE, 6)
	# Head, snout, horns, whiskers, a crest down the neck.
	StarRegionArt._ellipsoid(st, Vector3(0, 0.94, 0.33), Vector3(0.17, 0.15, 0.28), Color.WHITE, 7, 4)
	StarRegionArt._ellipsoid(st, Vector3(0, 0.91, 0.47), Vector3(0.115, 0.095, 0.18), Color(0.94, 0.94, 0.94), 6, 3)
	for side in [-1.0, 1.0]:
		StarRegionArt._tube(st, [Vector3(side * 0.05, 0.99, 0.28), Vector3(side * 0.09, 1.07, 0.18), Vector3(side * 0.11, 1.13, 0.06)], [0.022, 0.014, 0.003], Color(1.0, 0.96, 0.8), 5)
		StarRegionArt._tube(st, [Vector3(side * 0.05, 0.9, 0.52), Vector3(side * 0.17, 0.87, 0.46), Vector3(side * 0.24, 0.94, 0.36)], [0.009, 0.007, 0.002], Color(1.0, 0.96, 0.8), 4)
		StarRegionArt._ellipsoid(st, Vector3(side * 0.06, 0.975, 0.38), Vector3(0.035, 0.03, 0.04), Color(0.25, 0.2, 0.2), 5, 3)
	for i in 6:
		var t := 0.45 + float(i) * 0.1
		var at: Vector3 = points[int(t * 33.0)]
		var outward := Vector3(at.x, 0, at.z).normalized()
		StarRegionArt._triangle(st, at + Vector3(0, 0.05, 0), at + outward * 0.09 + Vector3(0, 0.13, 0), at + Vector3(0, 0.11, 0), Color(1.0, 0.95, 0.8), Color.WHITE, Color(1.0, 0.95, 0.8))


## A hooked rib: it rises 0.75 and leans 0.5 along +X.
static func _rib_geometry(st: SurfaceTool) -> void:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 10:
		var t := float(i) / 9.0
		var phi := t * 1.9
		points.append(Vector3((1.0 - cos(phi)) * 0.38, sin(phi) * 0.75, 0))
		radii.append(lerpf(0.05, 0.01, t))
	StarRegionArt._tube(st, points, radii, Color.WHITE, 6)


## A horned dragon skull, 1 long along +Z, resting on y = 0.
static func _skull_geometry(st: SurfaceTool) -> void:
	StarRegionArt._ellipsoid(st, Vector3(0, 0.27, -0.1), Vector3(0.5, 0.42, 0.5), Color.WHITE, 8, 5)
	StarRegionArt._ellipsoid(st, Vector3(0, 0.2, 0.32), Vector3(0.34, 0.26, 0.62), Color(0.96, 0.96, 0.96), 8, 4)
	StarRegionArt._ellipsoid(st, Vector3(0, 0.05, 0.24), Vector3(0.3, 0.1, 0.56), Color(0.85, 0.85, 0.85), 7, 3)
	for side in [-1.0, 1.0]:
		StarRegionArt._tube(st, [Vector3(side * 0.16, 0.42, -0.2), Vector3(side * 0.3, 0.62, -0.5), Vector3(side * 0.26, 0.82, -0.82)], [0.07, 0.045, 0.008], Color(0.95, 0.93, 0.88), 6)
		StarRegionArt._ellipsoid(st, Vector3(side * 0.15, 0.33, 0.08), Vector3(0.14, 0.13, 0.13), Color(0.2, 0.17, 0.2), 6, 3)
		StarRegionArt._ellipsoid(st, Vector3(side * 0.06, 0.26, 0.56), Vector3(0.05, 0.05, 0.07), Color(0.2, 0.17, 0.2), 5, 3)
		for i in 4:
			var z := 0.16 + float(i) * 0.11
			StarRegionArt._tube(st, [Vector3(side * 0.14, 0.12, z), Vector3(side * 0.14, -0.0, z + 0.01)], [0.024, 0.002], Color.WHITE, 4)


## A bank of cloud: four soft lobes, about 1 x 0.6 x 0.8.
static func _puff_geometry(st: SurfaceTool) -> void:
	StarRegionArt._ellipsoid(st, Vector3.ZERO, Vector3(0.62, 0.56, 0.58), Color.WHITE, 7, 3, 0.4)
	for lobe in [[Vector3(0.27, -0.06, 0.08), Vector3(0.48, 0.4, 0.44)], [Vector3(-0.28, -0.05, -0.02), Vector3(0.48, 0.42, 0.44)],
			[Vector3(-0.02, -0.05, 0.24), Vector3(0.46, 0.36, 0.42)]]:
		StarRegionArt._ellipsoid(st, lobe[0], lobe[1], Color(0.97, 0.95, 0.95), 6, 3, 1.3)


## A low bush or a tuft of blossom: three lobes, about 1 x 0.8 x 1, light enough to scatter.
static func _bush_geometry(st: SurfaceTool) -> void:
	StarRegionArt._ellipsoid(st, Vector3(0, 0.05, 0), Vector3(0.7, 0.75, 0.66), Color.WHITE, 6, 3, 0.6)
	StarRegionArt._ellipsoid(st, Vector3(0.26, -0.06, 0.1), Vector3(0.52, 0.52, 0.5), Color(0.95, 0.95, 0.95), 5, 3, 1.9)
	StarRegionArt._ellipsoid(st, Vector3(-0.24, -0.04, -0.12), Vector3(0.54, 0.56, 0.5), Color(0.92, 0.92, 0.92), 5, 3, 3.1)


## Three small flowers on their stems (the star fields' flower, with a third of its faces).
static func _bloom_geometry(st: SurfaceTool) -> void:
	for bloom in 3:
		var center := Vector3((bloom - 1) * 0.45, 0.7 + bloom % 2 * 0.3, sin(bloom * 2.0) * 0.3)
		StarRegionArt._triangle(st, Vector3(center.x - 0.03, 0, center.z), Vector3(center.x + 0.03, 0, center.z), center, Color("759078"), Color("759078"), Color("759078"))
		for petal in 5:
			var angle := petal * TAU / 5.0
			var tip := center + Vector3(cos(angle), 0.09, sin(angle)) * 0.34
			var side := Vector3(-sin(angle), 0, cos(angle)) * 0.14
			StarRegionArt._triangle(st, center, tip - side, tip + side, Color("fff0b0"), Color.WHITE, Color.WHITE)


## A swallow-tailed silk strip along +X (UV.x runs 0 at the pole to 1 at the tail).
static func _streamer_geometry(st: SurfaceTool) -> void:
	var segments := 10
	for i in segments:
		var quad: Array = []
		for corner in [[i, -1.0], [i + 1, -1.0], [i + 1, 1.0], [i, 1.0]]:
			var t := float(corner[0]) / float(segments)
			var half := lerpf(0.5, 0.36, t)
			quad.append([Vector3(t, float(corner[1]) * half, 0), t])
		for corner in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE.darkened(0.08 * float(i % 2)))
			st.set_uv(Vector2(float(quad[corner][1]), 0.0))
			st.add_vertex(quad[corner][0])
