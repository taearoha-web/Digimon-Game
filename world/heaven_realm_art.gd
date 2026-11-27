class_name HeavenRealmArt
extends RefCounted
## ดินแดนเทวาลัย (HeavenRealmData): a celestial temple floating over a sea of cloud. A round
## terrace of white marble with gold inlay and jade lawns, stepping down at its rim in
## marble terraces whose lips pour streams of light into the clouds; a gold-and-jade gate
## at the arrival, a court of jade pillars before the boss, and beyond it a stair up to the
## Hall of the Gods: a white palace with jade roofs between two golden chedis, a sun-halo
## rising behind it. Floating islets with pavilions, blossom and chedis drift around.
##
## Built from the star fields' kit like the other endgame fields: the playable disc is
## continuous at y=0, every repeated prop is batched into StarRegionArt's shared
## MultiMeshes (with the lotus sanctum's petal and the sky isle's roof, puff, streamer,
## bush, bloom and dragon shapes), and the clouds, falls of light and streamers move in
## the sky isle's one small shader (SkyIsleArt._sp, sky_isle.gdshader). No lights, no
## particles, no per-frame scripts; quality 0 places fewer clouds, plants and islets.
const RADIUS := 55.5
const MARBLE := Color("f4eee2")
const MARBLE_SHADE := Color("ddd3c2")
const MARBLE_WARM := Color("f3e4c6")
const GOLD := Color("f2c34e")
const GOLD_DEEP := Color("c99532")
const JADE := Color("44b98f")
const JADE_PALE := Color("bfe8d6")
const LAWN := Color("72c48e")
const LAWN_SUN := Color("aedb8a")
const ROSE := Color("ffc7d6")
const LAPIS := Color("5f8fd8")
const ROOF := Color("2f9c7a")
const CLOUD := Color("fffaf2")
const CLOUD_WARM := Color("ffe3bd")
const HAZE := Color("fff0dc")
const ROCK := Color("c9bba6")
const ROCK_DEEP := Color("8f8aa6")
## The terraces below the rim: [outer radius, height of the step's top].
const TERRACES := [[59.0, -0.55], [63.5, -1.35], [68.5, -2.35], [74.0, -3.55]]
## Where the falls of light leave the lowest terrace (angles, atan2(z, x)).
const FALLS := [0.35, 1.2, 2.05, 2.95, 3.65, 5.75]
## The Hall of the Gods' axis: north (-z) of the boss court.
const HALL := Vector3(0, 0, -74)


static func layout(_zone_id: StringName = &"heaven_realm") -> Dictionary:
	return {"spawn": Vector3(0, 0, 46), "boss_pos": Vector3(0, 0, -28), "exit": Vector3(0, 0, -48),
		"camp_positions": [Vector2(-24, 30), Vector2(24, 30), Vector2(-41, 4), Vector2(41, 4), Vector2(-27, -21), Vector2(0, 8), Vector2(27, -21)],
		"paths": [PackedVector2Array([Vector2(0, 50), Vector2(0, 30), Vector2(0, 8), Vector2(0, -12), Vector2(0, -28)]),
			PackedVector2Array([Vector2(-24, 30), Vector2(0, 30), Vector2(24, 30)]),
			PackedVector2Array([Vector2(-41, 4), Vector2(-20, 7), Vector2(0, 8), Vector2(20, 7), Vector2(41, 4)]),
			PackedVector2Array([Vector2(-27, -21), Vector2(-12, -14), Vector2(0, -12), Vector2(12, -14), Vector2(27, -21)])]}


## Where the entrance stele stands (Zone hangs the realm's sign over it).
static func sign_spot() -> Vector3:
	return (layout().spawn as Vector3) + Vector3(6.4, 0, -2.6)


## `tree` paces the build over frames (StarRegionArt.build); null builds it in one go.
static func build(parent: Node3D, _zone_id: StringName = &"heaven_realm", tree: SceneTree = null) -> void:
	var root := Node3D.new()
	root.name = "HeavenRealmArt"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 50077
	var c := {"root": root, "batches": {}, "special": {}, "colliders": [], "layout": layout(), "index": 6, "rng": rng}
	SkyIsleArt._register_shapes()
	await _ground(root, tree)
	await FrameSlicer.pace(tree)
	_terraces(c)
	_cloud_sea(c)
	await FrameSlicer.pace(tree)
	_inlay(c)
	_entrance(c)
	_court(c)
	await FrameSlicer.pace(tree)
	_hall(c)
	_camp_dressing(c)
	await FrameSlicer.pace(tree)
	_planting(c)
	_rim(c)
	_islets(c)
	await DivineRegionArt._flush(c, tree)
	SkyIsleArt._flush_special(c)
	StarRegionArt._add_colliders(c)
	root.set_meta("zone_id", &"heaven_realm")
	root.set_meta("flat_walkable_radius", RADIUS)
	root.set_meta("no_dynamic_lights", true)
	root.set_meta("opaque_water_and_clouds", true)
	root.set_meta("art_layout_version", 1)


# ---------------------------------------------------------------------------
# Ground and terraces
# ---------------------------------------------------------------------------

static func _ground_color(xz: Vector2, info: Dictionary) -> Color:
	var r := xz.length()
	var vein := sin(xz.x * 0.37 + sin(xz.y * 0.21) * 2.3) * sin(xz.y * 0.29 - xz.x * 0.07)
	var col := MARBLE.lerp(MARBLE_SHADE, 0.22 + 0.18 * vein)
	col = col.lerp(MARBLE_WARM, 0.25 * (0.5 + 0.5 * sin(xz.x * 0.05 - xz.y * 0.04)))
	# Jade lawns between the ways, the camps' marble rounds and the courts.
	var open := smoothstep(4.0, 6.2, StarRegionArt._path_distance(xz, info.paths))
	for camp in info.camp_positions:
		open *= smoothstep(10.4, 12.6, xz.distance_to(camp))
	var boss: Vector3 = info.boss_pos
	var spawn: Vector3 = info.spawn
	open *= smoothstep(16.0, 18.5, xz.distance_to(Vector2(boss.x, boss.z))) * smoothstep(7.5, 9.5, xz.distance_to(Vector2(spawn.x, spawn.z)))
	open *= 1.0 - smoothstep(48.5, 50.5, r)
	var lawn := LAWN.lerp(LAWN_SUN, 0.5 + 0.5 * sin(xz.x * 0.19 + xz.y * 0.07) * cos(xz.y * 0.15 - xz.x * 0.05))
	lawn = lawn.lerp(ROSE, smoothstep(0.62, 0.98, sin(xz.x * 0.41 + 1.3) * sin(xz.y * 0.37 - 0.4)) * 0.4)
	col = col.lerp(lawn, open)
	# A warm glow of gold toward the hall.
	col = col.lerp(Color("ffe6a8"), (1.0 - smoothstep(10.0, 40.0, xz.distance_to(Vector2(0, -52)))) * 0.18 * (1.0 - open))
	return col


static func _ground(root: Node3D, tree: SceneTree = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var info := layout()
	var rings := 40
	var sectors := 128
	var shade := {}
	for r in rings:
		await FrameSlicer.pace(tree)
		for s in sectors:
			var points: Array[Vector3] = []
			var keys: Array[Vector2i] = []
			for q in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var radius := float(r + q.x) / float(rings) * RADIUS
				var angle := TAU * float(s + q.y) / float(sectors)
				points.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
				keys.append(Vector2i(r + q.x, (s + q.y) % sectors))
			for corner in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = points[corner]
				var key: Vector2i = keys[corner]
				if not shade.has(key):
					shade[key] = _ground_color(Vector2(p.x, p.z), info)
				st.set_color(shade[key])
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p.x, p.z) * 0.12)
				st.add_vertex(p)
	# Marble grain (the shared rock detail) over the painted marble and lawns.
	StarRegionArt._mesh_node(root, st, StarRegionArt._material("terrain_1", 1, 1), "HeavenGround")
	var body := StaticBody3D.new()
	body.name = "HeavenGroundCollision"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS
	cylinder.height = 1.0
	shape.shape = cylinder
	shape.position.y = -0.5
	body.add_child(shape)
	root.add_child(body)


## The marble terraces stepping down from the rim (tops and risers), and the hanging
## mountain under them.
static func _terraces(c: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 128
	var inner := RADIUS
	var top_y := 0.0
	for k in TERRACES.size():
		var outer: float = TERRACES[k][0]
		var y: float = TERRACES[k][1]
		for s in steps:
			var a0 := TAU * float(s) / float(steps)
			var a1 := TAU * float(s + 1) / float(steps)
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			# The riser from the step above down to this step.
			var riser := MARBLE_SHADE.darkened(0.05 + 0.03 * float(s % 2))
			StarRegionArt._triangle(st, d0 * inner + Vector3(0, top_y, 0), d1 * inner + Vector3(0, top_y, 0), d1 * inner + Vector3(0, y, 0), riser, riser, riser.darkened(0.08))
			StarRegionArt._triangle(st, d0 * inner + Vector3(0, top_y, 0), d1 * inner + Vector3(0, y, 0), d0 * inner + Vector3(0, y, 0), riser, riser.darkened(0.08), riser.darkened(0.08))
			# The step's top: lawn on the inner part, marble at the lip.
			var top := (LAWN.lerp(LAWN_SUN, 0.5 + 0.5 * sin(a0 * 7.0 + float(k))) if k % 2 == 0 else MARBLE.lerp(MARBLE_WARM, 0.3))
			var lip := MARBLE.darkened(0.02)
			StarRegionArt._triangle(st, d0 * inner + Vector3(0, y, 0), d1 * outer + Vector3(0, y, 0), d1 * inner + Vector3(0, y, 0), top, lip, top)
			StarRegionArt._triangle(st, d0 * inner + Vector3(0, y, 0), d0 * outer + Vector3(0, y, 0), d1 * outer + Vector3(0, y, 0), top, lip, lip)
		inner = outer
		top_y = y
	# The cliff of the hanging mountain: marble strata fading to lavender rock.
	var profile := [[1.0, -3.55], [1.0, -5.2], [0.92, -9.0], [0.78, -16.0], [0.56, -24.0], [0.32, -32.0], [0.1, -40.0]]
	var bands := [MARBLE_SHADE, Color("e8dcc4"), Color("d2c3b0"), Color("bcaea8"), Color("a69eaa"), ROCK_DEEP, ROCK_DEEP.darkened(0.1)]
	var outer_r: float = TERRACES[-1][0]
	for s in steps:
		var a0 := TAU * float(s) / float(steps)
		var a1 := TAU * float(s + 1) / float(steps)
		for k in profile.size() - 1:
			var quad: Array[Vector3] = []
			for corner in [[a0, k], [a1, k], [a1, k + 1], [a0, k + 1]]:
				var a: float = corner[0]
				var row: Array = profile[int(corner[1])]
				var jag := 1.0 + (0.04 * sin(a * 19.0 + float(corner[1]) * 1.3) if int(corner[1]) > 1 else 0.0)
				var radius := outer_r * float(row[0]) * jag
				quad.append(Vector3(cos(a) * radius, float(row[1]) + (sin(a * 7.0 + float(corner[1])) * 0.9 if int(corner[1]) > 1 else 0.0), sin(a) * radius))
			var t: Color = bands[k].darkened(0.04 * float(s % 3))
			var b: Color = bands[k + 1].darkened(0.04 * float(s % 3))
			StarRegionArt._triangle(st, quad[0], quad[1], quad[2], t, t, b)
			StarRegionArt._triangle(st, quad[0], quad[2], quad[3], t, b, b)
	StarRegionArt._mesh_node(c.root, st, StarRegionArt._material("solid"), "HeavenTerraces")
	# Gold coping along every riser's lip, marble posts on the lowest one.
	for k in TERRACES.size():
		var r: float = RADIUS if k == 0 else float(TERRACES[k - 1][0])
		var y: float = 0.0 if k == 0 else float(TERRACES[k - 1][1])
		var n := int(r * 1.15)
		for i in n:
			var a := TAU * (float(i) + 0.5) / float(n)
			StarRegionArt._put(c, "box", Vector3(cos(a) * r, y + 0.04, sin(a) * r), Vector3(0.36, 0.1, TAU * r / float(n) * 1.03), GOLD if k % 2 == 0 else GOLD_DEEP.lightened(0.2), Vector3(0, -a, 0))
	var last: float = TERRACES[-1][0]
	var last_y: float = TERRACES[-1][1]
	for i in 72:
		var a := TAU * float(i) / 72.0
		var p := Vector3(cos(a) * (last - 0.6), last_y, sin(a) * (last - 0.6))
		StarRegionArt._put(c, "pillar", p + Vector3(0, 0.45, 0), Vector3(0.3, 0.9, 0.3), MARBLE)
		if i % 6 == 0:
			StarRegionArt._put(c, "crystal", p + Vector3(0, 1.15, 0), Vector3(0.26, 0.5, 0.26), Color("fff0b8"), Vector3.ZERO, "glow")
		var b := TAU * float(i + 1) / 72.0
		var q := Vector3(cos(b) * (last - 0.6), last_y, sin(b) * (last - 0.6))
		StarRegionArt._segment(c, p + Vector3(0, 0.8, 0), q + Vector3(0, 0.8, 0), 0.09, GOLD)
	# Hanging spires under the mountain.
	for i in 14:
		var a := TAU * float(i) / 14.0 + 0.2
		var r := last * (0.66 if i % 2 == 0 else 0.42)
		var h := 9.0 + float(i % 4) * 3.0
		StarRegionArt._put(c, "crystal", Vector3(cos(a) * r, -22.0 - h * 0.5 - float(i % 3) * 2.0, sin(a) * r), Vector3(5.0, h, 5.0), ROCK_DEEP.lerp(ROCK, 0.35), Vector3(PI, a, 0))
	# Streams of light pour off the lowest terrace into the clouds.
	for a in FALLS:
		var out := Vector3(cos(a), 0, sin(a))
		SkyIsleArt._fall(c, out * (last - 0.3) + Vector3(0, last_y + 0.05, 0), out, 3.0, 34.0, "Fall_%d" % int(a * 100.0))


## The sky far below and the sea of cloud (SkyIsleArt's shader modes 1 and 3).
static func _cloud_sea(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var hi := GameSettings.quality >= 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.0, 50.0, 100.0, 150.0, 210.0, 320.0]
	var tones := [Color("4b8fe2"), Color("62a2ea"), Color("8dc0f0"), Color("c9e0f2"), Color("f6ecd6"), HAZE]
	for ring in radii.size() - 1:
		for sector in 48:
			var a0 := TAU * float(sector) / 48.0
			var a1 := TAU * float(sector + 1) / 48.0
			var r0: float = radii[ring]
			var r1: float = radii[ring + 1]
			var p0 := Vector3(cos(a0) * r0, -62.0, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r0, -62.0, sin(a1) * r0)
			var p2 := Vector3(cos(a1) * r1, -62.0, sin(a1) * r1)
			var p3 := Vector3(cos(a0) * r1, -62.0, sin(a0) * r1)
			StarRegionArt._triangle(st, p0, p2, p1, tones[ring], tones[ring + 1], tones[ring])
			StarRegionArt._triangle(st, p0, p3, p2, tones[ring], tones[ring + 1], tones[ring + 1])
	SkyIsleArt._special_mesh(c.root, st, 3, "SkyBelow")
	# The cloud deck under the mountain and the banks out to the horizon.
	for i in (46 if hi else 26):
		var a := TAU * float(i) / (46.0 if hi else 26.0) + rng.randf_range(-0.05, 0.05)
		var r := 46.0 + rng.randf() * 46.0
		var size := rng.randf_range(12.0, 22.0)
		SkyIsleArt._sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * rng.randf_range(0.32, 0.48), size * rng.randf_range(0.65, 0.95))),
			Vector3(cos(a) * r, rng.randf_range(-40.0, -28.0), sin(a) * r)), CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.5), 1)
	for i in (56 if hi else 30):
		var a := TAU * float(i) / (56.0 if hi else 30.0) + rng.randf_range(-0.03, 0.03)
		var r := 70.0 + pow(rng.randf(), 0.7) * 150.0
		var size := rng.randf_range(18.0, 36.0)
		SkyIsleArt._sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * rng.randf_range(0.26, 0.4), size * rng.randf_range(0.6, 0.9))),
			Vector3(cos(a) * r, -44.0 + rng.randf_range(0.0, 6.0), sin(a) * r)), CLOUD.lerp(CLOUD_WARM, rng.randf() * 0.7), 1)
	# Wisps at the terraces' feet and towering clouds far out that frame the sky.
	for i in 18:
		var a := TAU * float(i) / 18.0 + rng.randf_range(-0.08, 0.08)
		var size := rng.randf_range(7.0, 12.0)
		var r := 74.0 + rng.randf_range(1.0, 7.0)
		SkyIsleArt._sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.34, size * 0.7)),
			Vector3(cos(a) * r, rng.randf_range(-12.0, -5.0), sin(a) * r)), CLOUD, 1)
	for i in (12 if hi else 7):
		var a := TAU * float(i) / (12.0 if hi else 7.0) + 0.4
		var r := rng.randf_range(150.0, 200.0)
		var size := rng.randf_range(30.0, 48.0)
		SkyIsleArt._sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.55, size * 0.7)),
			Vector3(cos(a) * r, rng.randf_range(4.0, 22.0), sin(a) * r)), CLOUD.lerp(CLOUD_WARM, 0.3 + rng.randf() * 0.4), 1)


# ---------------------------------------------------------------------------
# Inlay, the arrival, the boss court, the Hall of the Gods
# ---------------------------------------------------------------------------

static func _band(c: Dictionary, centre: Vector3, radius: float, width: float, tone: Color) -> void:
	var n := maxi(12, int(radius * 2.4))
	for i in n:
		var a := TAU * float(i) / float(n)
		StarRegionArt._put(c, "box", centre + Vector3(cos(a) * radius, 0.035, sin(a) * radius), Vector3(width, 0.05, TAU * radius / float(n) * 1.04), tone, Vector3(0, -a, 0))


static func _lamp(c: Dictionary, p: Vector3, size: float) -> void:
	StarRegionArt._put(c, "box", p + Vector3(0, 0.15, 0) * size, Vector3(0.7, 0.3, 0.7) * size, MARBLE_SHADE)
	StarRegionArt._put(c, "pillar", p + Vector3(0, 1.0, 0) * size, Vector3(0.22, 1.5, 0.22) * size, MARBLE)
	StarRegionArt._put(c, "box", p + Vector3(0, 1.75, 0) * size, Vector3(0.62, 0.1, 0.62) * size, GOLD)
	StarRegionArt._put(c, "crystal", p + Vector3(0, 2.05, 0) * size, Vector3(0.34, 0.5, 0.34) * size, Color("fff0b8"), Vector3.ZERO, "glow")
	StarRegionArt._put(c, "isle_roof", p + Vector3(0, 2.3, 0) * size, Vector3(0.9, 0.38, 0.9) * size, GOLD)


static func _column(c: Dictionary, p: Vector3, height: float, radius: float, shaft: Color, collide := true) -> void:
	StarRegionArt._put(c, "box", p + Vector3(0, 0.22, 0), Vector3(radius * 3.4, 0.44, radius * 3.4), MARBLE_SHADE)
	StarRegionArt._put(c, "pillar", p + Vector3(0, height * 0.5, 0), Vector3(radius * 2.0, height, radius * 2.0), shaft)
	for y in [0.55, height * 0.8]:
		StarRegionArt._put(c, "pillar", p + Vector3(0, y, 0), Vector3(radius * 2.3, 0.22, radius * 2.3), GOLD)
	StarRegionArt._put(c, "box", p + Vector3(0, height, 0), Vector3(radius * 3.0, 0.32, radius * 3.0), GOLD)
	DivineRegionArt._lotus(c, p + Vector3(0, height + 0.1, 0), radius * 1.4, MARBLE)
	if collide and Vector2(p.x, p.z).length() < 54.0:
		c.colliders.append(Vector3(p.x, p.z, radius + 0.25))


## A roofed gate: white pillars with gold rings, gold lintels, a jade roof, a halo.
static func _gate(c: Dictionary, p: Vector3, yaw: float, width: float, height: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	for side in [-1.0, 1.0]:
		_column(c, p + basis * Vector3(side * width * 0.5, 0, 0), height, 0.42, MARBLE)
	StarRegionArt._put(c, "box", p + Vector3(0, height * 0.84, 0), Vector3(width * 1.2, 0.36, 0.5), GOLD, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", p + Vector3(0, height + 0.25, 0), Vector3(width * 1.45, 0.5, 0.8), MARBLE, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "isle_roof", p + Vector3(0, height + 0.5, 0), Vector3(width * 1.85, 1.6, 2.6), ROOF, Vector3(0, yaw, 0))
	StarRegionArt._ring(c, p + Vector3(0, height + 2.9, 0), 1.0, 0.08, GOLD, Vector3(PI * 0.5, yaw, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, height + 2.9, 0), Vector3(0.45, 0.9, 0.45), Color("fff0b8"), Vector3.ZERO, "glow")
	StarRegionArt._put(c, "box", p + Vector3(0, height * 0.84 - 0.7, 0), Vector3(1.9, 0.8, 0.16), LAPIS, Vector3(0, yaw, 0))
	for side in [-1.0, 1.0]:
		SkyIsleArt._streamer(c, p + basis * Vector3(side * width * 0.62, height * 0.9, 0), 3.2, 0.48, GOLD if side < 0 else MARBLE)


## A golden chedi: a bell on stacked rounds with a spire (Thai temple), `h` metres tall.
static func _chedi(c: Dictionary, p: Vector3, h: float, tone: Color) -> void:
	for i in 3:
		StarRegionArt._put(c, "pillar", p + Vector3(0, h * (0.03 + 0.06 * float(i)), 0), Vector3(h * (0.62 - 0.1 * float(i)), h * 0.06, h * (0.62 - 0.1 * float(i))), MARBLE if i % 2 == 0 else tone)
	StarRegionArt._put(c, "willow_frond", p + Vector3(0, h * 0.36, 0), Vector3(h * 0.42, h * 0.3, h * 0.42), tone)
	StarRegionArt._put(c, "pillar", p + Vector3(0, h * 0.52, 0), Vector3(h * 0.16, h * 0.08, h * 0.16), MARBLE)
	for i in 5:
		StarRegionArt._put(c, "pillar", p + Vector3(0, h * (0.58 + 0.055 * float(i)), 0), Vector3(h * (0.11 - 0.017 * float(i)), h * 0.05, h * (0.11 - 0.017 * float(i))), tone.lightened(0.04 * float(i)))
	StarRegionArt._put(c, "crystal", p + Vector3(0, h * 0.92, 0), Vector3(h * 0.05, h * 0.18, h * 0.05), Color("fff3c4"), Vector3.ZERO, "glow")


## A pavilion (ศาลา): four columns, a jade roof with a gold finial.
static func _sala(c: Dictionary, p: Vector3, size: float, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	StarRegionArt._put(c, "box", p + Vector3(0, 0.15 * size, 0), Vector3(3.4, 0.3, 3.4) * size, MARBLE_SHADE, Vector3(0, yaw, 0))
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		StarRegionArt._put(c, "pillar", p + basis * (corner * 1.3 * size) + Vector3(0, 1.4 * size, 0), Vector3(0.28, 2.6, 0.28) * size, MARBLE)
	StarRegionArt._put(c, "box", p + Vector3(0, 2.75 * size, 0), Vector3(3.2, 0.22, 3.2) * size, GOLD, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "isle_roof", p + Vector3(0, 2.85 * size, 0), Vector3(4.4, 1.7, 4.4) * size, ROOF, Vector3(0, yaw, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, 4.5 * size, 0), Vector3(0.24, 0.6, 0.24) * size, GOLD, Vector3.ZERO, "glow")


static func _inlay(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var info: Dictionary = c.layout
	# Flagstones of cream and gold-veined marble along every way.
	for index in info.paths.size():
		var path: PackedVector2Array = info.paths[index]
		var across := 3 if index == 0 else 2
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var dir := (b - a).normalized()
			var normal := Vector2(-dir.y, dir.x)
			var steps := int((b - a).length() / 1.5)
			for k in steps:
				var along := a + dir * (float(k) + 0.5) * 1.5
				if along.length() > 52.0:
					continue
				for j in across:
					var offset := (float(j) - float(across - 1) * 0.5) * 1.5
					var at := along + normal * offset
					var tone := MARBLE.darkened(rng.randf_range(0.0, 0.08)).lerp(GOLD, 0.35 if (k + j) % 9 == 0 else 0.0)
					StarRegionArt._put(c, "box", Vector3(at.x, 0.025, at.y), Vector3(1.38, 0.05, 1.38), tone, Vector3(0, -atan2(dir.y, dir.x), 0))
			# Gold-capped lamps beside the way.
			var lamps := int((b - a).length() / 8.5)
			for k in lamps:
				var along2 := a + dir * (float(k) + 0.5) * ((b - a).length() / float(lamps))
				var at2 := along2 + normal * (3.4 * (1.0 if (k + i) % 2 == 0 else -1.0))
				if at2.length() < 51.0 and _clear(at2, 0.4, false):
					_lamp(c, Vector3(at2.x, 0, at2.y), 1.0)
	# Each camp stands on a round of marble with a gold band and a jade one.
	for camp in info.camp_positions:
		var p := Vector3(camp.x, 0, camp.y)
		_band(c, p, 9.8, 0.4, GOLD)
		_band(c, p, 10.5, 0.22, JADE)
	# The rim's gold band and a balustrade of marble posts.
	_band(c, Vector3.ZERO, 51.5, 0.5, GOLD)
	for i in 96:
		var a := TAU * float(i) / 96.0
		var p := Vector3(cos(a) * 54.9, 0, sin(a) * 54.9)
		StarRegionArt._put(c, "box", p + Vector3(0, 0.5, 0), Vector3(0.36, 1.0, 0.36), MARBLE, Vector3(0, -a, 0))
		StarRegionArt._put(c, "box", p + Vector3(0, 0.95, 0), Vector3(0.24, 0.14, TAU * 54.9 / 96.0 * 1.02), GOLD, Vector3(0, -a, 0))
		if i % 8 == 0:
			_lamp(c, p * 0.985, 1.15)


static func _entrance(c: Dictionary) -> void:
	var info: Dictionary = c.layout
	var spawn: Vector3 = info.spawn
	for k in 2:
		var r := 2.6 + 2.2 * float(k)
		var n := 8 + 6 * k
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(k)) / float(n)
			StarRegionArt._put(c, "box", spawn + Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(1.9, 0.06, TAU * r / float(n) * 0.93), (MARBLE if (i + k) % 2 == 0 else JADE_PALE), Vector3(0, -a, 0))
	StarRegionArt._put(c, "disc", spawn + Vector3(0, 0.06, 0), Vector3(2.6, 1, 2.6), GOLD)
	StarRegionArt._put(c, "disc", spawn + Vector3(0, 0.075, 0), Vector3(1.9, 1, 1.9), JADE)
	_band(c, spawn, 6.2, 0.3, GOLD)
	_gate(c, spawn + Vector3(0, 0, -8.6), 0.0, 6.6, 6.0)
	for s in [-1.0, 1.0]:
		SkyIsleArt._statue(c, spawn + Vector3(s * 6.8, 0, -6.0), 4.0, PI, GOLD)
	# The stele that names the realm (Zone hangs the words over it).
	var stele := sign_spot()
	StarRegionArt._put(c, "box", stele + Vector3(0, 0.2, 0), Vector3(2.2, 0.4, 1.0), MARBLE_SHADE)
	StarRegionArt._put(c, "box", stele + Vector3(0, 1.55, 0), Vector3(1.6, 2.3, 0.36), LAPIS.darkened(0.15), Vector3.ZERO, "mineral")
	StarRegionArt._put(c, "box", stele + Vector3(0, 1.55, 0.2), Vector3(1.3, 1.9, 0.05), GOLD)
	StarRegionArt._put(c, "isle_roof", stele + Vector3(0, 2.75, 0), Vector3(2.4, 0.7, 1.1), GOLD)
	c.colliders.append(Vector3(stele.x, stele.z, 0.9))


static func _court(c: Dictionary) -> void:
	var info: Dictionary = c.layout
	var boss: Vector3 = info.boss_pos
	# Rings of marble and jade tiles, gold bands, a sun medallion of gold and lapis.
	var rings := [[3.4, 9], [5.8, 16], [8.2, 22], [10.6, 29], [12.9, 36]]
	for k in rings.size():
		var r: float = rings[k][0]
		var n: int = rings[k][1]
		for i in n:
			var a := TAU * (float(i) + 0.5 * float(k % 2)) / float(n)
			var tone := (JADE_PALE if (i + k) % 2 == 0 else MARBLE).darkened(0.03 * float((i * 7 + k) % 3))
			StarRegionArt._put(c, "box", boss + Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(2.1, 0.06, TAU * r / float(n) * 0.94), tone, Vector3(0, -a, 0))
	for r in [4.6, 9.4, 14.1]:
		_band(c, boss, r, 0.32, GOLD)
	StarRegionArt._put(c, "disc", boss + Vector3(0, 0.07, 0), Vector3(4.4, 1, 4.4), GOLD)
	StarRegionArt._put(c, "disc", boss + Vector3(0, 0.085, 0), Vector3(3.4, 1, 3.4), LAPIS)
	for i in 12:
		var a := TAU * float(i) / 12.0
		StarRegionArt._put(c, "box", boss + Vector3(cos(a) * 1.2, 0.1, sin(a) * 1.2), Vector3(1.6, 0.03, 0.22), GOLD.lightened(0.2), Vector3(0, -a, 0))
	# Jade columns with streamers ring the court; the way in (south) and the stair
	# (north) stay open.
	for i in 12:
		var a := TAU * float(i) / 12.0 + PI / 12.0
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.4 or absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.4:
			continue
		var at := boss + Vector3(cos(a) * 16.2, 0, sin(a) * 16.2)
		_column(c, at, 5.0, 0.4, JADE)
		SkyIsleArt._streamer(c, at + Vector3(0, 4.4, 0), 3.4, 0.5, [GOLD, MARBLE, ROSE, JADE_PALE][i % 4])
	# Golden naga guard the foot of the stair.
	for s in [-1.0, 1.0]:
		SkyIsleArt._statue(c, Vector3(s * 7.5, 0, -48.0), 5.2, 0.0, GOLD)


## The Hall of the Gods beyond the court: a stair, a plinth, a white palace with jade
## roofs, two golden chedis and the sun-halo behind.
static func _hall(c: Dictionary) -> void:
	# The stair climbs from the court's north edge out over the terraces.
	for i in 14:
		var z := -51.0 - float(i) * 1.1
		StarRegionArt._put(c, "box", Vector3(0, 0.2 + float(i) * 0.42, z), Vector3(14.0 - float(i) * 0.25, 0.42, 1.2), MARBLE.darkened(0.03 * float(i % 2)))
	for s in [-1.0, 1.0]:
		for i in 7:
			var z := -52.0 - float(i) * 2.2
			StarRegionArt._put(c, "box", Vector3(s * (7.2 - float(i) * 0.25), 0.9 + float(i) * 0.92, z), Vector3(0.5, 1.2, 2.3), GOLD, Vector3(-0.38, 0, 0))
	var base := HALL + Vector3(0, 5.9, 0)
	StarRegionArt._put(c, "box", HALL + Vector3(0, 0.95, 0), Vector3(46.0, 9.9, 22.0), MARBLE_SHADE)
	StarRegionArt._put(c, "box", base + Vector3(0, 0.1, 0), Vector3(47.0, 0.3, 23.0), GOLD)
	for i in 3:
		StarRegionArt._put(c, "box", HALL + Vector3(0, 1.0 + float(i) * 1.8, 11.2), Vector3(46.0, 0.25, 0.3), GOLD.darkened(0.1))
	# The palace: three tiers of white walls under jade roofs, gold columns in front.
	var y := 0.3
	var w := 22.0
	var d := 13.0
	for tier in 3:
		var h := 5.2 - float(tier) * 0.9
		StarRegionArt._put(c, "box", base + Vector3(0, y + h * 0.5, 0), Vector3(w, h, d), MARBLE)
		StarRegionArt._put(c, "box", base + Vector3(0, y + h * 0.15, 0), Vector3(w * 1.01, h * 0.12, d * 1.01), GOLD)
		if tier == 0:
			StarRegionArt._put(c, "box", base + Vector3(0, y + h * 0.42, d * 0.5 + 0.05), Vector3(w * 0.22, h * 0.8, 0.16), GOLD_DEEP)
			for x in [-0.42, -0.26, -0.12, 0.12, 0.26, 0.42]:
				StarRegionArt._put(c, "pillar", base + Vector3(x * w, y + h * 0.5, d * 0.5 + 1.1), Vector3(0.8, h, 0.8), GOLD)
			for x in [-0.34, 0.34]:
				StarRegionArt._put(c, "box", base + Vector3(x * w, y + h * 0.55, d * 0.5 + 0.05), Vector3(2.0, 2.4, 0.12), LAPIS)
		y += h
		StarRegionArt._put(c, "isle_roof", base + Vector3(0, y, 0), Vector3(w * 1.45, 3.6 - float(tier) * 0.5, d * 1.6), ROOF.lerp(JADE, 0.25 * float(tier)))
		StarRegionArt._put(c, "box", base + Vector3(0, y + 0.06, 0), Vector3(w * 1.1, 0.3, d * 1.14), GOLD)
		y += 1.7
		w *= 0.68
		d *= 0.7
	_chedi(c, base + Vector3(0, y - 0.2, 0), 8.0, GOLD)
	for s in [-1.0, 1.0]:
		_chedi(c, base + Vector3(s * 19.5, 0.2, 2.0), 15.0, GOLD)
		_column(c, base + Vector3(s * 13.0, 0.1, 9.5), 7.0, 0.5, JADE, false)
		DivineRegionArt._lotus(c, base + Vector3(s * 8.5, 0.25, 9.8), 1.6, ROSE)
	# The sun-halo behind the hall.
	var gate := HALL + Vector3(0, 24.0, -10.0)
	StarRegionArt._ring(c, gate, 15.0, 0.8, GOLD, Vector3(PI * 0.5, 0, 0))
	StarRegionArt._ring(c, gate, 13.4, 0.26, JADE, Vector3(PI * 0.5, 0, 0))
	StarRegionArt._ring(c, gate, 17.2, 0.18, Color("fff0b8"), Vector3(PI * 0.5, 0, 0))
	for i in 16:
		var a := TAU * float(i) / 16.0
		StarRegionArt._put(c, "crystal", gate + Vector3(cos(a) * 16.2, sin(a) * 16.2, 0), Vector3(1.0, 2.8 if i % 2 == 0 else 1.6, 1.0), GOLD.lightened(0.15), Vector3(0, 0, a - PI * 0.5), "glow")


# ---------------------------------------------------------------------------
# Camps, plants, the rim, the islets
# ---------------------------------------------------------------------------

static func _camp_dressing(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var info: Dictionary = c.layout
	for index in info.camp_positions.size():
		var camp: Vector2 = info.camp_positions[index]
		var centre := Vector3(camp.x, 0, camp.y)
		if index == 5:
			# The gate-guardians' court: a gold mandala of eight petals.
			StarRegionArt._put(c, "disc", centre + Vector3(0, 0.04, 0), Vector3(6.0, 1, 6.0), GOLD.lightened(0.15))
			StarRegionArt._put(c, "disc", centre + Vector3(0, 0.05, 0), Vector3(4.6, 1, 4.6), MARBLE)
			for i in 8:
				var a := TAU * float(i) / 8.0
				DivineRegionArt._petal(c, centre + Vector3(cos(a) * 3.4, 0.09, sin(a) * 3.4), Vector3(1.6, 3.2, 0.2), GOLD, Vector3(PI * 0.5, 0, a - PI * 0.5))
			StarRegionArt._put(c, "disc", centre + Vector3(0, 0.07, 0), Vector3(1.6, 1, 1.6), LAPIS)
			continue
		for i in 8:
			var a := TAU * float(i) / 8.0 + float(index) * 0.7
			var p2 := camp + Vector2(cos(a), sin(a)) * rng.randf_range(11.4, 12.8)
			if not _clear(p2, 1.2, false) or p2.length() > 50.0:
				continue
			var p := Vector3(p2.x, 0, p2.y)
			match index:
				0:
					# Hanging lanterns of the lantern spirits.
					StarRegionArt._put(c, "pillar", p + Vector3(0, 1.7, 0), Vector3(0.14, 3.4, 0.14), GOLD_DEEP)
					StarRegionArt._put(c, "box", p + Vector3(0.45, 3.35, 0), Vector3(1.0, 0.1, 0.1), GOLD_DEEP)
					StarRegionArt._put(c, "willow_frond", p + Vector3(0.85, 2.85, 0), Vector3(0.55, 0.7, 0.55), Color("ffe08a"), Vector3.ZERO, "glow")
					c.colliders.append(Vector3(p.x, p.z, 0.3))
				1:
					# Clouds settled on the hounds' meadow.
					var s := rng.randf_range(2.2, 3.6)
					SkyIsleArt._sp(c, "isle_puff", Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(s, s * 0.32, s * 0.75)), p + Vector3(0, 0.2, 0)), CLOUD, 1)
				2:
					# Lotus on the hamsa's pools.
					DivineRegionArt._lotus(c, p + Vector3(0, 0.05, 0), rng.randf_range(0.6, 1.0), ROSE.lerp(MARBLE, rng.randf() * 0.5))
				3:
					# Jade guardian statues.
					if i % 2 == 0:
						SkyIsleArt._statue(c, p, 3.6, a + PI, JADE)
				4:
					# The hermits' pavilions.
					if i % 3 == 0:
						_sala(c, p, 0.8, a)
						c.colliders.append(Vector3(p.x, p.z, 1.5))
				6:
					# Golden chedis on the naga stair.
					if i % 2 == 1:
						_chedi(c, p, rng.randf_range(4.0, 5.2), GOLD)
						c.colliders.append(Vector3(p.x, p.z, 1.2))
	# The hamsa's pool beside its camp.
	var pool := (info.camp_positions[2] as Vector2) + Vector2(-2.0, -14.5)
	StarRegionArt._pool(c, Vector3(pool.x, 0.02, pool.y), Vector2(4.6, 3.2), Color("8fd0e8"), "HamsaPool")
	for i in 5:
		var a := TAU * float(i) / 5.0
		DivineRegionArt._lotus(c, Vector3(pool.x + cos(a) * 2.4, 0.05, pool.y + sin(a) * 1.6), 0.6, ROSE)


static func _blossom(c: Dictionary, p: Vector3, height: float, leaf: Color) -> void:
	SkyIsleArt._blossom_tree(c, p, height, leaf)


static func _planting(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var lush := 1.0 if GameSettings.quality >= 1 else 0.55
	for i in int(110 * lush):
		var a := rng.randf() * TAU
		var r := 8.0 + sqrt(rng.randf()) * 42.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if not _clear(Vector2(p.x, p.z), 1.6, true):
			continue
		match i % 6:
			0, 1: _blossom(c, p, rng.randf_range(4.4, 6.4), [ROSE, MARBLE.lerp(ROSE, 0.3), Color("ffe08a")][i % 3])
			2:
				for k in 2:
					var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
					var s := rng.randf_range(0.9, 1.5)
					StarRegionArt._put(c, "isle_bush", p + off + Vector3(0, s * 0.3, 0), Vector3(1.5, 0.85, 1.35) * s, LAWN.darkened(0.15 + 0.05 * float(k)), Vector3(0, rng.randf() * TAU, 0), "foliage")
				StarRegionArt._put(c, "isle_bloom", p + Vector3(0, 0.7, 0), Vector3.ONE * 0.6, ROSE.lightened(0.2), Vector3(0, a, 0), "foliage")
			3:
				StarRegionArt._cypress(c, p, rng.randf_range(3.6, 5.2), JADE.darkened(0.1), true)
			4:
				for k in 4:
					var off := Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3))
					StarRegionArt._put(c, "isle_bloom", p + off, Vector3.ONE * rng.randf_range(0.6, 0.9), [ROSE, Color("fff0b0"), MARBLE][k % 3], Vector3(0, rng.randf() * TAU, 0), "foliage")
			5:
				_lamp(c, p, 1.1)
				c.colliders.append(Vector3(p.x, p.z, 0.4))


static func _rim(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	# Blossom along the lower terraces and lotus in their lawns.
	for i in 40:
		var a := TAU * float(i) / 40.0 + rng.randf_range(-0.04, 0.04)
		if absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.32:
			continue
		var k := i % 3
		var r := (RADIUS + float(TERRACES[0][0])) * 0.5 if k == 0 else (float(TERRACES[1][0]) + float(TERRACES[2][0])) * 0.5
		var y: float = TERRACES[0][1] if k == 0 else TERRACES[2][1]
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		if k == 2:
			DivineRegionArt._lotus(c, p, 1.0, ROSE.lerp(MARBLE, 0.3))
		else:
			StarRegionArt._put(c, "isle_bush", p + Vector3(0, 0.5, 0), Vector3(2.4, 1.2, 2.0) * rng.randf_range(0.8, 1.2), [ROSE, LAWN.darkened(0.15), Color("ffe08a")][i % 3], Vector3(0, a, 0), "foliage")
	# Streamer poles on the lowest terrace.
	for i in 16:
		var a := TAU * float(i) / 16.0 + 0.2
		if absf(wrapf(a + PI * 0.5, -PI, PI)) < 0.4:
			continue
		var at := Vector3(cos(a), 0, sin(a)) * (float(TERRACES[3][0]) - 2.4) + Vector3(0, float(TERRACES[3][1]), 0)
		var h := 6.0 + float(i % 3) * 0.8
		StarRegionArt._put(c, "pillar", at + Vector3(0, h * 0.5, 0), Vector3(0.16, h, 0.16), GOLD_DEEP)
		StarRegionArt._put(c, "crystal", at + Vector3(0, h + 0.2, 0), Vector3(0.26, 0.5, 0.26), GOLD, Vector3.ZERO, "glow")
		SkyIsleArt._streamer(c, at + Vector3(0, h - 0.5, 0), rng.randf_range(4.0, 6.0), 0.6, [GOLD, MARBLE, ROSE, JADE_PALE][i % 4])


static func _islet(c: Dictionary, p: Vector3, r: float, depth: float, yaw: float, marble: bool) -> void:
	StarRegionArt._put(c, "island", p - Vector3(0, depth * 0.5, 0), Vector3(r * 2.0, depth, r * 1.8), ROCK.lerp(ROCK_DEEP, 0.3), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "disc", p + Vector3(0, 0.04, 0), Vector3(r * 1.96, 1, r * 1.76), MARBLE if marble else LAWN.lerp(LAWN_SUN, 0.4), Vector3(0, yaw, 0))
	if marble:
		StarRegionArt._ring(c, p + Vector3(0, 0.12, 0), r * 0.95, 0.12, GOLD, Vector3(0, yaw, 0))
	for i in 4:
		var a := TAU * float(i) / 4.0 + yaw
		StarRegionArt._put(c, "crystal", p + Vector3(cos(a) * r * 0.5, -depth * 0.75, sin(a) * r * 0.45), Vector3(r * 0.35, depth * 0.7, r * 0.35), ROCK_DEEP, Vector3(PI, a, 0))


static func _islets(c: Dictionary) -> void:
	var rng: RandomNumberGenerator = c.rng
	var hi := GameSettings.quality >= 1
	# [angle, distance, height, radius, what stands on it]
	var isles := [[0.55, 96.0, 6.0, 9.0, "sala"], [1.25, 118.0, 16.0, 7.0, "chedi"], [2.0, 92.0, -4.0, 11.0, "tree"],
		[2.75, 110.0, 12.0, 8.0, "sala"], [3.45, 88.0, 2.0, 6.5, "chedi"], [5.55, 100.0, 9.0, 10.0, "tree"],
		[0.95, 140.0, 26.0, 6.0, "chedi"], [2.35, 150.0, 30.0, 7.0, "sala"], [5.95, 138.0, 20.0, 6.0, "tree"]]
	if not hi:
		isles = isles.slice(0, 6)
	for isle in isles:
		var a: float = isle[0]
		var p := Vector3(cos(a) * float(isle[1]), float(isle[2]), sin(a) * float(isle[1]))
		var r: float = isle[3]
		var what: String = isle[4]
		_islet(c, p, r, r * 1.5, a, what != "tree")
		match what:
			"sala": _sala(c, p, r * 0.22, a)
			"chedi": _chedi(c, p, r * 1.4, GOLD)
			"tree":
				_blossom(c, p, r * 0.8, ROSE)
				DivineRegionArt._lotus(c, p + Vector3(r * 0.4, 0.05, 0), 1.2, MARBLE)
		if what == "sala":
			var out := Vector3(cos(a + 0.4), 0, sin(a + 0.4))
			SkyIsleArt._fall(c, p + out * r * 0.9 + Vector3(0, 0.05, 0), out, 1.6, 22.0, "Fall_isle_%d" % int(a * 100.0))
	# Small floating rocks with gold rings near the rim.
	for i in (24 if hi else 14):
		var a := TAU * float(i) / (24.0 if hi else 14.0) + rng.randf_range(-0.06, 0.06)
		var s := rng.randf_range(1.4, 3.6)
		var at := Vector3(cos(a), 0, sin(a)) * rng.randf_range(78.0, 88.0) + Vector3(0, rng.randf_range(-6.0, 5.0), 0)
		StarRegionArt._put(c, "island", at, Vector3(s * 1.5, s * 1.3, s * 1.3), ROCK.lerp(ROCK_DEEP, rng.randf() * 0.5), Vector3(0, a, 0))
		StarRegionArt._put(c, "disc", at + Vector3(0, s * 0.66, 0), Vector3(s * 1.46, 1, s * 1.26), LAWN.lerp(LAWN_SUN, rng.randf()), Vector3(0, a, 0))
	# Chains of gold from the terraces to the two nearest islets.
	var last: float = TERRACES[3][0]
	for isle in [isles[0], isles[4]]:
		var a: float = isle[0]
		var to := Vector3(cos(a) * (float(isle[1]) - float(isle[3])), float(isle[2]), sin(a) * (float(isle[1]) - float(isle[3])))
		SkyIsleArt._chain(c, Vector3(cos(a) * last, float(TERRACES[3][1]) + 0.6, sin(a) * last), to, 4.0)


## Whether a prop of `radius` may stand at `xz`: off the ways, the camps, the courts and
## the spawn (`low` props may come closer to the camps).
static func _clear(xz: Vector2, radius: float, solid := true) -> bool:
	var info := layout()
	if StarRegionArt._path_distance(xz, info.paths) < radius + (4.0 if solid else 1.6):
		return false
	for camp in info.camp_positions:
		if xz.distance_to(camp) < radius + (11.0 if solid else 9.5):
			return false
	var boss: Vector3 = info.boss_pos
	var spawn: Vector3 = info.spawn
	if xz.distance_to(Vector2(boss.x, boss.z)) < radius + 18.0 or xz.distance_to(Vector2(spawn.x, spawn.z)) < radius + 9.0:
		return false
	var stele := sign_spot()
	if xz.distance_to(Vector2(stele.x, stele.z)) < radius + 2.0:
		return false
	var pool := (info.camp_positions[2] as Vector2) + Vector2(-2.0, -14.5)
	return xz.distance_to(pool) > radius + 5.5
