class_name MazeArena
extends RefCounted
## The look of เขาวงกตหนึ่งในใต้หล้า (MazeLayout's maze): a colossal ancient labyrinth on a
## floating isle above a sea of cloud, at the golden hour. Each quadrant is a temple of its
## own (THEMES): the jade ruins overgrown with moss and blossom, the crimson fire temple
## with its embers and braziers, the sapphire halls of frost and crystal, the golden sun
## court with its gold friezes. Pillars with lit finials stand at every corner of the walls,
## runes glow along their feet, the floor's runners carry an inlaid line of light down every
## way (brightest on the ways into a shrine). The four quadrant landmarks and the throne in
## the middle stand tall with beams of light into the sky: beacons from anywhere in the
## maze. The ten shrines (ที่หลบภัย) are lotus sanctuaries ringed by a veil of light.
## Round the isle: cliffs falling into the cloud, falls, floating isles with the quadrants'
## prang towers, two far ranges in the evening haze, sky lanterns and fireflies.
##
## Phones first: no lights, no particles, no per-frame scripts (only shaders move things).
## The maze itself is merged into CHUNKS x CHUNKS meshes culled by distance, each with a
## plain far stand-in (MazeFar*) beyond that range, so the overview still reads; the floor
## is ONE mesh drawn by a shader from the maze's map (maze_floor.gdshader); the landmarks,
## beams, motes, lanterns and the whole world round the isle are a handful of meshes and
## MultiMeshes with cached materials; the walls' colliders are one body per quadrant.

## The maze is drawn in CHUNKS x CHUNKS pieces.
const CHUNKS := 4
## The chunks' draw distance (times GameSettings.view_scale); past it the far stand-ins.
const CHUNK_RANGE := 130.0
## The walls are drawn in panels of about this length (each its own tone and height).
const PANEL := 3.0
const NAME_META := "maze_built"
const FLOOR_SHADER := preload("res://shaders/maze_floor.gdshader")
const FAR_SHADER := preload("res://shaders/maze_far.gdshader")
const FX_SHADER := preload("res://shaders/maze_fx.gdshader")
const SAFE_COLOR := Color("8ff7ff")
const SAFE_GOLD := Color("ffe9a0")
const CROWN_GOLD := Color("f2c84b")
const MARBLE := Color("efe8da")
const GOLD := Color("f0c048")
const CRIMSON := Color("a8262a")
## The isle's rim (a rounded square this far from the centre) and the sea of cloud.
const ISLE := MazeLayout.HALF + 24.0
const CLOUD_Y := -38.0
## Where the light comes from (Scenery's sun, lowered to the golden hour).
const SUN_ROT := Vector3(-34.0, -32.0, 0.0)
## The quadrants' landmarks are built this much larger than drawn in their functions.
const LANDMARK_SCALE := 1.35
const THRONE_SCALE := 1.3

## Per quadrant (MazeLayout.QUADRANTS order): stone, its dark plinths, the pale caps, the
## accent (moss, embers, frost, gold), the glow of its runes, its floor and runner slabs,
## its roof tiles, its blossoms and its metal.
const THEMES: Array[Dictionary] = [
	{"stone": Color("6f9e86"), "dark": Color("35594d"), "trim": Color("e2ecd2"), "accent": Color("4d9a3a"), "glow": Color("64ffb4"),
		"floor": Color("5d7d5b"), "runner": Color("b8c99e"), "roof": Color("2f7a5a"), "deco": Color("ffa6c9"), "metal": Color("d8c070")},
	{"stone": Color("b9553f"), "dark": Color("5a2626"), "trim": Color("f0d2a8"), "accent": Color("ff7a2a"), "glow": Color("ff9a3c"),
		"floor": Color("8a5242"), "runner": Color("d3a487"), "roof": Color("9e2a22"), "deco": Color("ffcf5a"), "metal": Color("e8b04a")},
	{"stone": Color("5a76bb"), "dark": Color("2a3468"), "trim": Color("eef6ff"), "accent": Color("bdf0ff"), "glow": Color("6fe0ff"),
		"floor": Color("506592"), "runner": Color("adc1e4"), "roof": Color("2c4fa0"), "deco": Color("ffffff"), "metal": Color("d6e8f4")},
	{"stone": Color("d4a046"), "dark": Color("7e5a22"), "trim": Color("fff4dc"), "accent": Color("ffd23a"), "glow": Color("ffe27a"),
		"floor": Color("8e6c3a"), "runner": Color("ead2a0"), "roof": Color("c8961e"), "deco": Color("ffffff"), "metal": Color("ffd04a")},
]
## The sky and air (MazeWar.zone carries the same, for the sky tests).
const SKY_PALETTE := [Color("1d4fb4"), Color("7aa2e2"), Color("ffc890")]

static var _gem_arrays: Array = []
static var _lowball: Array = []
static var _flat_arrays: Array = []
static var _floor_mat: ShaderMaterial
static var _far_mats: Dictionary = {}
static var _fx_mats: Dictionary = {}
static var _ball_mesh: ArrayMesh


static func build(zone: Node3D) -> void:
	MazeLayout.ensure()
	var data := MazeWar.zone()
	var world_env := Scenery.environment(zone, data.sky, data.fog, data.ambient, data.sun,
		{"palette": data.sky_palette, "sun_size": float(data.sun_size)})
	_light(zone, world_env)
	var root := Node3D.new()
	root.name = "Maze"
	zone.add_child(root)
	_ground(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = MazeLayout.SEED + 7
	var batches: Array[JapanKit.Batch] = []
	var far: Array[JapanKit.Batch] = []
	for k in CHUNKS * CHUNKS:
		batches.append(JapanKit.Batch.new())
		far.append(JapanKit.Batch.new())
	_walls(batches, far, rng)
	_gates(batches)
	_shrines(batches, root)
	var reach := CHUNK_RANGE * GameSettings.view_scale()
	var size := MazeLayout.HALF * 2.0 / float(CHUNKS)
	for k in batches.size():
		var box := AABB(Vector3(-MazeLayout.HALF + size * float(k % CHUNKS), -1.0, -MazeLayout.HALF + size * float(k / CHUNKS)), Vector3(size, 16.0, size))
		if not batches[k].is_empty():
			var mi := batches[k].commit(root, "MazeChunk%d" % k, GameSettings.world_shadows())
			mi.custom_aabb = box
			mi.visibility_range_end = reach
		if not far[k].is_empty():
			var fm := far[k].commit(root, "MazeFar%d" % k, false)
			fm.custom_aabb = box
			fm.visibility_range_begin = reach
			fm.visibility_range_end = 0.0
	_landmarks(root)
	_light_fx(root, rng)
	_colliders(root)
	_signs(root)
	_isle(root, rng)
	_world(root, rng)
	root.set_meta(NAME_META, true)


## The golden hour: a low warm sun, a cool violet fill, thin rose air, a big glow round
## the sun in the sky.
static func _light(zone: Node3D, world_env: WorldEnvironment) -> void:
	var env := world_env.environment
	env.ambient_light_color = Color("98a2dc")
	env.ambient_light_energy = 0.56
	env.fog_density = 0.0007
	env.fog_light_color = Color("b9c6ec")
	env.fog_sky_affect = 0.12
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	if sky_mat:
		sky_mat.sky_top_color = SKY_PALETTE[0]
		sky_mat.sky_horizon_color = SKY_PALETTE[2]
		sky_mat.ground_horizon_color = SKY_PALETTE[2]
		sky_mat.ground_bottom_color = Color("dfe6fa")
		sky_mat.sun_angle_max = 34.0
		sky_mat.sun_curve = 0.09
	for child in zone.get_children():
		if child is DirectionalLight3D and child.is_in_group("sun"):
			var sun := child as DirectionalLight3D
			sun.rotation_degrees = SUN_ROT
			sun.light_energy = 1.05


# --- The floor ----------------------------------------------------------------------

## One flat mesh over the maze, paved by maze_floor.gdshader from the maze's map (and the
## flat physics floor under everything).
static func _ground(zone: Node3D) -> void:
	var half := MazeLayout.HALF
	var n := MazeLayout.CELLS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for iz in n:
		for ix in n:
			var x0 := -half + MazeLayout.CELL * float(ix)
			var z0 := -half + MazeLayout.CELL * float(iz)
			var x1 := x0 + MazeLayout.CELL
			var z1 := z0 + MazeLayout.CELL
			for p in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
				st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _floor_material()
	zone.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	zone.add_child(body)


## The floor's material, with the maze's map as a tiny texture (built once: the maze is
## the same every time).
static func _floor_material() -> ShaderMaterial:
	if _floor_mat != null:
		SurfaceKit.prepare(_floor_mat)
		return _floor_mat
	var n := MazeLayout.CELLS
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var guide := PackedFloat32Array()
	guide.resize(n * n)
	guide.fill(0.0)
	for k in MazeLayout.safe_count():
		var field := MazeLayout.field_to(MazeLayout.cell_at(MazeLayout.safe_center(k)))
		for c in n * n:
			var steps := field[c]
			if steps >= 0 and steps <= 3:
				guide[c] = maxf(guide[c], [1.0, 0.85, 0.5, 0.22][steps])
	for c in n * n:
		var x := c % n
		var z := c / n
		var east := x < n - 1 and MazeLayout.is_open(c, c + 1)
		var south := z < n - 1 and MazeLayout.is_open(c, c + n)
		var plaza := MazeLayout.plaza_of[c]
		img.set_pixel(x, z, Color(1.0 if east else 0.0, 1.0 if south else 0.0, guide[c], float(plaza + 1) / 8.0 if plaza >= 0 else 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("links", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("half_size", MazeLayout.HALF)
	mat.set_shader_parameter("cell", MazeLayout.CELL)
	mat.set_shader_parameter("cells", float(n))
	mat.set_shader_parameter("wall_face", MazeLayout.CELL * 0.5 - MazeLayout.WALL_T * 0.5)
	for q in 4:
		mat.set_shader_parameter("floor%d" % q, THEMES[q].floor)
		mat.set_shader_parameter("runner%d" % q, THEMES[q].runner)
		mat.set_shader_parameter("glow%d" % q, THEMES[q].glow)
	mat.set_shader_parameter("shrine_glow", Color("9ffcf2"))
	mat.set_shader_parameter("marble", MARBLE)
	mat.set_shader_parameter("gold", GOLD)
	mat.set_shader_parameter("carpet", CRIMSON)
	mat.set_shader_parameter("moss", Color("2c3a3a"))
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		mat.set_shader_parameter("plaza%d" % k, Vector3(at.x, at.z, float(MazeLayout.PLAZAS[k][2]) * MazeLayout.CELL * 0.5))
	_floor_mat = SurfaceKit.prepare(mat)
	return _floor_mat


## The batch of the chunk point p lies in.
static func _chunk(batches: Array[JapanKit.Batch], p: Vector3) -> JapanKit.Batch:
	var size := MazeLayout.HALF * 2.0 / float(CHUNKS)
	var x := clampi(int(floor((p.x + MazeLayout.HALF) / size)), 0, CHUNKS - 1)
	var z := clampi(int(floor((p.z + MazeLayout.HALF) / size)), 0, CHUNKS - 1)
	return batches[z * CHUNKS + x]


static func _theme(p: Vector3) -> Dictionary:
	return THEMES[MazeLayout.quadrant(p)]


# --- Primitives with a surface kind --------------------------------------------------

static func _box(b: JapanKit.Batch, pos: Vector3, size: Vector3, color: Color, kind := SurfaceKit.KIND_NONE, rot := Vector3.ZERO) -> void:
	b.add(JapanKit.arrays("box"), JapanKit.place(pos, size, rot), color, false, Callable(), kind)


static func _cyl(b: JapanKit.Batch, pos: Vector3, radius: float, height: float, color: Color, sides := 8, kind := SurfaceKit.KIND_NONE, rot := Vector3.ZERO) -> void:
	b.add(JapanKit.arrays("cyl%d" % sides), JapanKit.place(pos, Vector3(radius * 2.0, height, radius * 2.0), rot), color, false, Callable(), kind)


static func _cone(b: JapanKit.Batch, pos: Vector3, radius: float, height: float, color: Color, glow := false, rot := Vector3.ZERO) -> void:
	b.add(JapanKit.arrays("cone"), JapanKit.place(pos, Vector3(radius * 2.0, height, radius * 2.0), rot), color, glow)


## A cut gem (an octahedron): orbs, crystals and jewels at a fraction of a sphere's cost.
static func _gem(b: JapanKit.Batch, pos: Vector3, size: Vector3, color: Color, glow := true, rot := Vector3.ZERO) -> void:
	if _gem_arrays.is_empty():
		var p := [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0, -0.5, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]
		var faces := [[2, 4, 0], [2, 0, 5], [2, 5, 1], [2, 1, 4], [3, 0, 4], [3, 5, 0], [3, 1, 5], [3, 4, 1]]
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var idx := PackedInt32Array()
		for f in faces:
			var a: Vector3 = p[f[0]]
			var c: Vector3 = p[f[1]]
			var e: Vector3 = p[f[2]]
			var nrm := (c - a).cross(e - a).normalized()
			if nrm.dot(a + c + e) < 0.0:
				nrm = -nrm
			for v in [a, c, e]:
				verts.append(v)
				normals.append(nrm)
			var base := verts.size() - 3
			idx.append_array([base, base + 2, base + 1] if (c - a).cross(e - a).dot(nrm) > 0.0 else [base, base + 1, base + 2])
		_gem_arrays.resize(Mesh.ARRAY_MAX)
		_gem_arrays[Mesh.ARRAY_VERTEX] = verts
		_gem_arrays[Mesh.ARRAY_NORMAL] = normals
		_gem_arrays[Mesh.ARRAY_INDEX] = idx
	b.add(_gem_arrays, JapanKit.place(pos, size, rot), color, glow)


## A low sphere (8 sides, 4 rings): blossoms, moss, flames, clouds.
static func _orb(b: JapanKit.Batch, pos: Vector3, size: Vector3, color: Color, glow := false) -> void:
	b.add(_lowball_arrays(), JapanKit.place(pos, size, Vector3.ZERO), color, glow)


static func _lowball_arrays() -> Array:
	if _lowball.is_empty():
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 8
		m.rings = 4
		_lowball = m.get_mesh_arrays()
	return _lowball


## A flat glowing card, seen from both sides (a unit quad in its XY plane, turned by
## rot in degrees): rune lines, glyphs, ember cracks. Four triangles where a box is twelve.
static func _flat(b: JapanKit.Batch, pos: Vector3, size: Vector2, color: Color, rot := Vector3.ZERO) -> void:
	if _flat_arrays.is_empty():
		var verts := PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)])
		var v2 := verts.duplicate()
		v2.append_array(verts)
		var normals := PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD])
		_flat_arrays.resize(Mesh.ARRAY_MAX)
		_flat_arrays[Mesh.ARRAY_VERTEX] = v2
		_flat_arrays[Mesh.ARRAY_NORMAL] = normals
		_flat_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7])
	b.add(_flat_arrays, JapanKit.place(pos, Vector3(size.x, size.y, 1.0), rot), color, true)


## A size along a wall: l along it, h up, d across.
static func _along(along_x: bool, l: float, h: float, d: float) -> Vector3:
	return Vector3(l, h, d) if along_x else Vector3(d, h, l)


# --- The walls ----------------------------------------------------------------------

## Every wall run in panels: a dark plinth with a line of rune light along its top, the
## stone (textured masonry in the quadrant's colour), a cornice and a pale capstone, a
## glowing glyph on every other panel, and the quadrant's own dressing (moss, ivy and
## blossom; ember cracks; icicles and crystals; a gold frieze). The outer wall stands
## taller, crenellated. A pillar with the quadrant's lit finial stands at every corner of
## the grid the walls touch. The far stand-ins get one box and its cap a panel.
static func _walls(batches: Array[JapanKit.Batch], far: Array[JapanKit.Batch], rng: RandomNumberGenerator) -> void:
	var t := MazeLayout.WALL_T
	var nodes := {}
	var rich := GameSettings.quality >= 1
	var panel_no := 0
	for s in MazeLayout.segments():
		var a: Vector3 = s[0]
		var e: Vector3 = s[1]
		var q := int(s[2])
		var th: Dictionary = THEMES[q]
		var length := a.distance_to(e)
		var dir := (e - a) / maxf(length, 0.001)
		var along_x := absf(dir.x) > 0.5
		var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
		var outer := (along_x and absf(absf(a.z) - MazeLayout.HALF) < 0.1) or (not along_x and absf(absf(a.x) - MazeLayout.HALF) < 0.1)
		var panels := maxi(1, int(round(length / PANEL)))
		var step := length / float(panels)
		for k in panels:
			panel_no += 1
			var mid := a + dir * (step * (float(k) + 0.5))
			var b := _chunk(batches, mid)
			var h := (MazeLayout.WALL_H + 1.3 if outer else MazeLayout.WALL_H) + rng.randf_range(-0.08, 0.1)
			var stone: Color = (th.stone as Color).darkened(rng.randf() * 0.14).lightened(rng.randf() * 0.05)
			var dark: Color = th.dark
			var trim: Color = th.trim
			var glow: Color = th.glow
			_box(b, mid + Vector3(0, h * 0.5, 0), _along(along_x, step + 0.02, h, t), stone, SurfaceKit.KIND_STONE)
			_box(b, mid + Vector3(0, 0.28, 0), _along(along_x, step + 0.02, 0.56, t + 0.26), dark.lerp(stone, 0.25), SurfaceKit.KIND_MASONRY)
			_box(b, mid + Vector3(0, h - 0.05, 0), _along(along_x, step + 0.02, 0.14, t + 0.14), dark, SurfaceKit.KIND_MASONRY)
			var cap: Color = trim if q == 2 else trim.lerp(stone, 0.38)
			_box(b, mid + Vector3(0, h + 0.13, 0), _along(along_x, step - 0.06, 0.26, t + 0.4), cap.darkened(rng.randf() * 0.08), SurfaceKit.KIND_STONE)
			if outer:
				# Crenels on the outer wall.
				for c in [-0.25, 0.25]:
					_box(b, mid + dir * (step * c) + Vector3(0, h + 0.55, 0), _along(along_x, step * 0.3, 0.6, t + 0.2), cap.darkened(0.06), SurfaceKit.KIND_STONE)
			for side in [-1.0, 1.0]:
				var face: Vector3 = across * side
				# The line of rune light along the plinth.
				_flat(b, mid + face * (t * 0.5 + 0.06) + Vector3(0, 0.57, 0), Vector2(step - 0.34, 0.12), glow.darkened(0.12), Vector3(-90, 0 if along_x else 90, 0))
				if rich and panel_no % 2 == 0:
					_flat(b, mid + face * (t * 0.5 + 0.015) + Vector3(0, h * 0.56, 0), Vector2(0.4, 0.4), glow, Vector3(0, 0 if along_x else 90, 45))
				if q == 3:
					_box(b, mid + face * (t * 0.5 + 0.02) + Vector3(0, h - 0.34, 0), _along(along_x, step + 0.02, 0.16, 0.06), th.metal)
			match q:
				0:
					if rng.randf() < 0.5:
						_cyl(b, mid + dir * rng.randf_range(-0.6, 0.6) + Vector3(0, h + 0.3, 0), rng.randf_range(0.7, 1.15), 0.2, (th.accent as Color).darkened(rng.randf() * 0.2))
					if rng.randf() < 0.35:
						# Vines hanging from the cap.
						var side := 1.0 if rng.randf() < 0.5 else -1.0
						var at := mid + across * side * (t * 0.5 + 0.05) + dir * rng.randf_range(-0.6, 0.6)
						for v in 3:
							var drop := rng.randf_range(0.9, h * 0.8)
							_box(b, at + dir * (float(v) - 1.0) * 0.32 + Vector3(0, h - drop * 0.5, 0), _along(along_x, 0.2, drop, 0.07), (th.accent as Color).darkened(0.15 + rng.randf() * 0.2))
						_orb(b, at + Vector3(0, h - 0.1, 0), _along(along_x, 1.3, 0.5, 0.3), (th.accent as Color).darkened(0.1))
					if rich and rng.randf() < 0.14:
						_orb(b, mid + dir * rng.randf_range(-0.8, 0.8) + Vector3(0, h + 0.42, 0), Vector3(0.7, 0.5, 0.7), (th.deco as Color).lerp(Color.WHITE, rng.randf() * 0.4))
				1:
					if rich and rng.randf() < 0.3:
						var side := 1.0 if rng.randf() < 0.5 else -1.0
						var at := mid + across * side * (t * 0.5 + 0.015) + Vector3(0, rng.randf_range(1.1, 2.0), 0)
						for z in 3:
							var tilt := 35.0 if z % 2 == 0 else -35.0
							_flat(b, at + dir * (float(z) - 1.0) * 0.42 + Vector3(0, float(z % 2) * 0.12, 0), Vector2(0.5, 0.07), th.accent, Vector3(0, 0 if along_x else 90, tilt))
				2:
					if rng.randf() < 0.35:
						var side := 1.0 if rng.randf() < 0.5 else -1.0
						for z in 3:
							_cone(b, mid + dir * (float(z) - 1.0) * rng.randf_range(0.4, 0.7) + across * side * (t * 0.5 + 0.12) + Vector3(0, h - 0.35, 0), 0.09, rng.randf_range(0.35, 0.75), Color("dff3ff"), false, Vector3(180, 0, 0))
					if rich and rng.randf() < 0.14:
						var side := 1.0 if rng.randf() < 0.5 else -1.0
						var foot := mid + across * side * (t * 0.5 + 0.45)
						_cone(b, foot + Vector3(0, 0.45, 0), 0.2, 0.9, th.glow, true, Vector3(14, 0, -10))
						_cone(b, foot + dir * 0.3 + Vector3(0, 0.3, 0), 0.13, 0.6, Color("e6fbff"), true, Vector3(-18, 0, 16))
			# The far stand-in.
			var fb := _chunk(far, mid)
			_box(fb, mid + Vector3(0, h * 0.5, 0), _along(along_x, step + 0.02, h, t), stone, SurfaceKit.KIND_STONE)
			_box(fb, mid + Vector3(0, h + 0.13, 0), _along(along_x, step + 0.02, 0.26, t + 0.4), trim)
		# The grid corners this run touches.
		var count := int(round(length / MazeLayout.CELL))
		for n in count + 1:
			var p := a + dir * (MazeLayout.CELL * float(n))
			var key := Vector2i(int(round(p.x)), int(round(p.z)))
			if not nodes.has(key):
				nodes[key] = [p, q]
	for key in nodes:
		var p: Vector3 = nodes[key][0]
		var q := MazeLayout.quadrant(p + Vector3(0.01, 0, 0.01))
		_pillar(_chunk(batches, p), p, q, rich)
		var th: Dictionary = THEMES[q]
		var fb := _chunk(far, p)
		_box(fb, p + Vector3(0, (MazeLayout.WALL_H + 0.9) * 0.5, 0), Vector3(t + 0.46, MazeLayout.WALL_H + 0.9, t + 0.46), (th.stone as Color).lightened(0.06))


## A pillar at a corner of the walls: plinth, shaft, a band and a capital, and the
## quadrant's finial: a jade orb, a fire bowl, a crystal, a gold stupa spire.
static func _pillar(b: JapanKit.Batch, p: Vector3, q: int, rich: bool) -> void:
	var th: Dictionary = THEMES[q]
	var t := MazeLayout.WALL_T
	var outer := absf(absf(p.x) - MazeLayout.HALF) < 0.1 or absf(absf(p.z) - MazeLayout.HALF) < 0.1
	var top := MazeLayout.WALL_H + (2.4 if outer else 1.0)
	_box(b, p + Vector3(0, 0.36, 0), Vector3(t + 0.9, 0.72, t + 0.9), th.dark, SurfaceKit.KIND_MASONRY)
	_box(b, p + Vector3(0, top * 0.5, 0), Vector3(t + 0.46, top, t + 0.46), (th.stone as Color).lightened(0.07), SurfaceKit.KIND_STONE)
	_box(b, p + Vector3(0, 1.7, 0), Vector3(t + 0.6, 0.2, t + 0.6), th.trim, SurfaceKit.KIND_STONE)
	_box(b, p + Vector3(0, top + 0.16, 0), Vector3(t + 0.86, 0.32, t + 0.86), th.trim, SurfaceKit.KIND_STONE)
	var y := top + 0.32
	match q:
		0:
			_cyl(b, p + Vector3(0, y + 0.1, 0), 0.5, 0.2, th.dark, 6)
			_gem(b, p + Vector3(0, y + 0.55, 0), Vector3(0.62, 0.8, 0.62), th.glow)
			if rich:
				_cyl(b, p + Vector3(0.3, y + 0.24, -0.2), 0.42, 0.14, (th.accent as Color).darkened(0.1), 6)
		1:
			_cyl(b, p + Vector3(0, y + 0.16, 0), 0.55, 0.32, Color("3a2422"), 8)
			_flame(b, p + Vector3(0, y + 0.32, 0), 0.75, th.accent, rich)
		2:
			_cone(b, p + Vector3(0, y + 0.62, 0), 0.26, 1.25, th.glow, true)
			if rich:
				_cone(b, p + Vector3(0.22, y + 0.35, 0.05), 0.13, 0.65, Color("e6fbff"), true, Vector3(0, 0, -24))
				_cone(b, p + Vector3(-0.18, y + 0.32, -0.1), 0.12, 0.55, th.glow, true, Vector3(20, 0, 18))
		3:
			_cyl(b, p + Vector3(0, y + 0.1, 0), 0.5, 0.2, th.trim, 8)
			_orb(b, p + Vector3(0, y + 0.45, 0), Vector3(0.8, 0.62, 0.8), th.metal)
			_cyl(b, p + Vector3(0, y + 0.8, 0), 0.2, 0.16, th.trim, 6)
			_cone(b, p + Vector3(0, y + 1.35, 0), 0.17, 1.0, th.metal)
			_gem(b, p + Vector3(0, y + 1.92, 0), Vector3(0.24, 0.32, 0.24), th.glow)


## A toon flame on a bowl: an orange teardrop with yellow tongues licking out of it.
static func _flame(b: JapanKit.Batch, at: Vector3, size: float, color: Color, rich := true) -> void:
	_orb(b, at + Vector3(0, size * 0.42, 0), Vector3(size, size * 0.8, size), color, true)
	_cone(b, at + Vector3(0, size * 1.15, 0), size * 0.42, size * 1.2, color, true)
	_cone(b, at + Vector3(0, size * 0.95, 0), size * 0.22, size * 1.1, Color("ffe68a"), true)
	if rich:
		for n in 3:
			var ang := TAU * float(n) / 3.0
			var d := Vector3(cos(ang), 0, sin(ang))
			_cone(b, at + d * size * 0.38 + Vector3(0, size * 0.7, 0), size * 0.13, size * 0.6, Color("ffd060"), true, Vector3(sin(ang) * 25.0, 0, -cos(ang) * 25.0))


# --- The gates of the plazas ----------------------------------------------------------

## A grand gate over the middle of each side of every plaza (MazeLayout.build opens the
## middle cell of each side): two pillars on the wall line, a lintel with a glowing
## emblem, a two-tiered roof in the quadrant's tiles with a gold spire, banners.
static func _gates(batches: Array[JapanKit.Batch]) -> void:
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var size := float(MazeLayout.PLAZAS[k][2]) * MazeLayout.CELL
		var half := size * 0.5
		var mid := int(MazeLayout.PLAZAS[k][2]) / 2
		var gate := -MazeLayout.HALF + MazeLayout.CELL * (float(int(MazeLayout.PLAZAS[k][0]) + mid) + 0.5)
		var gate_z := -MazeLayout.HALF + MazeLayout.CELL * (float(int(MazeLayout.PLAZAS[k][1]) + mid) + 0.5)
		for g in [Vector3(gate, 0, at.z - half), Vector3(gate, 0, at.z + half), Vector3(at.x - half, 0, gate_z), Vector3(at.x + half, 0, gate_z)]:
			if not MazeLayout.inside((g as Vector3) * 0.999):
				continue
			_gate(_chunk(batches, g), g, absf((g as Vector3).z - at.z) > 0.1, MazeLayout.quadrant(at + Vector3(0.1, 0, 0.1)), k == 0)


static func _gate(b: JapanKit.Batch, at: Vector3, along_x: bool, q: int, throne: bool) -> void:
	var th: Dictionary = THEMES[q]
	var w := MazeLayout.CELL * 0.5
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var normal := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var stone: Color = MARBLE if throne else (th.stone as Color).lightened(0.1)
	var dark: Color = Color("6a5a48") if throne else th.dark
	var trim: Color = Color("fff8ea") if throne else th.trim
	var roof: Color = CRIMSON if throne else th.roof
	var metal: Color = GOLD if throne else th.metal
	var glow: Color = CROWN_GOLD if throne else th.glow
	for s in [-1.0, 1.0]:
		var p: Vector3 = at + across * (w * s)
		_box(b, p + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 2.4), dark, SurfaceKit.KIND_MASONRY)
		_box(b, p + Vector3(0, 3.9, 0), Vector3(1.6, 5.8, 1.6), stone, SurfaceKit.KIND_STONE)
		_box(b, p + Vector3(0, 2.2, 0), Vector3(1.8, 0.24, 1.8), metal)
		_box(b, p + Vector3(0, 7.0, 0), Vector3(2.1, 0.5, 2.1), trim, SurfaceKit.KIND_STONE)
		for f in [-1.0, 1.0]:
			# A lit lantern bracket on each face of the pillar.
			b.box(p + normal * (f * 0.86) + Vector3(0, 4.6, 0), Vector3(0.36, 0.5, 0.36), glow, Vector3.ZERO, true)
	var span := w * 2.0 + 2.4
	_box(b, at + Vector3(0, 7.8, 0), _along(along_x, span, 1.1, 1.8), stone.darkened(0.12), SurfaceKit.KIND_STONE)
	_box(b, at + Vector3(0, 8.46, 0), _along(along_x, span + 0.3, 0.24, 2.0), metal)
	for f in [-1.0, 1.0]:
		b.box(at + normal * (f * 0.92) + Vector3(0, 7.8, 0), Vector3(0.8, 0.8, 0.06) if along_x else Vector3(0.06, 0.8, 0.8), glow, Vector3(0, 0, 45) if along_x else Vector3(45, 0, 0), true)
		# Banners hanging under the lintel, by the pillars.
		for s in [-1.0, 1.0]:
			var bp: Vector3 = at + across * (s * (w - 2.0)) + normal * (f * 0.95) + Vector3(0, 5.2, 0)
			b.cloth(bp, Vector3(1.2, 4.0, 0.06) if along_x else Vector3(0.06, 4.0, 1.2), roof.lightened(0.08), JapanKit.hanging_weight(7.2, 4.0))
			b.cloth(bp + normal * (f * 0.04) + Vector3(0, -1.7, 0), Vector3(1.2, 0.3, 0.06) if along_x else Vector3(0.06, 0.3, 1.2), metal, JapanKit.hanging_weight(7.2, 4.0))
			b.cloth(bp + normal * (f * 0.05) + Vector3(0, 0.4, 0), Vector3(0.55, 0.55, 0.05) if along_x else Vector3(0.05, 0.55, 0.55), metal, JapanKit.hanging_weight(7.2, 4.0), Vector3(0, 0, 45) if along_x else Vector3(45, 0, 0))
	var yaw := 0.0 if along_x else 90.0
	b.roof(at + Vector3(0, 9.5, 0), span + 1.2, 3.4, 1.5, roof, 0.4, yaw)
	_box(b, at + Vector3(0, 10.35, 0), _along(along_x, span * 0.45, 0.5, 1.4), stone.darkened(0.05), SurfaceKit.KIND_STONE)
	b.roof(at + Vector3(0, 11.2, 0), span * 0.55, 2.4, 1.2, roof.darkened(0.1), 0.3, yaw)
	_cone(b, at + Vector3(0, 12.8, 0), 0.32, 1.8, metal)
	_gem(b, at + Vector3(0, 13.85, 0), Vector3(0.45, 0.6, 0.45), glow)


# --- The landmarks (the beacons) --------------------------------------------------------

## Each plaza's landmark is its own mesh, never culled by distance (the beacons by which
## the maze is found), a beam of light from its crown into the sky (MazeBeams).
static func _landmarks(root: Node3D) -> void:
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var b := JapanKit.Batch.new()
		b.xform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (THRONE_SCALE if k == 0 else LANDMARK_SCALE)), at)
		var q := MazeLayout.quadrant(at + Vector3(0.1, 0, 0.1))
		# The landmark faces the throne (the throne plaza faces south, the way in).
		var face := Vector3(0, 0, 1) if k == 0 else Vector3(-signf(at.x), 0, -signf(at.z)).normalized()
		match k:
			0: _throne(b, root, at)
			1: _guardian(b, face, THEMES[q])
			2: _fire_temple(b, THEMES[q])
			3: _crystal_spire(b, THEMES[q])
			4: _sun_orb(b, THEMES[q])
		var mi := b.commit(root, "MazeLandmark%d" % k, GameSettings.world_shadows())
		mi.visibility_range_end = 0.0


## The heights of the beams' feet (the tops of the landmarks).
static func _beacon_top(k: int) -> float:
	return 13.4 * THRONE_SCALE if k == 0 else [0.0, 9.6, 12.6, 14.6, 12.0][k] * LANDMARK_SCALE


## The throne plaza: a stepped octagonal dais in marble and gold, a great gold throne on
## it with a crimson seat, a gold crown afloat over it (turning), four obelisks with fire
## bowls at the corners and banners of the four quadrants.
static func _throne(b: JapanKit.Batch, root: Node3D, at: Vector3) -> void:
	_cyl(b, Vector3(0, 0.3, 0), 4.4, 0.6, MARBLE.darkened(0.06), 8, SurfaceKit.KIND_STONE)
	_cyl(b, Vector3(0, 0.62, 0), 4.55, 0.1, GOLD, 8)
	_cyl(b, Vector3(0, 0.95, 0), 3.5, 0.7, MARBLE, 8, SurfaceKit.KIND_STONE)
	_cyl(b, Vector3(0, 1.32, 0), 3.62, 0.1, GOLD, 8)
	# The throne (facing south).
	_box(b, Vector3(0, 1.6, 0.1), Vector3(3.4, 0.5, 2.8), GOLD.darkened(0.15))
	_box(b, Vector3(0, 2.1, 0.2), Vector3(3.0, 0.6, 2.3), GOLD)
	_box(b, Vector3(0, 2.5, 0.3), Vector3(2.5, 0.28, 1.9), CRIMSON)
	_box(b, Vector3(0, 4.3, -0.95), Vector3(3.0, 4.2, 0.55), GOLD)
	_box(b, Vector3(0, 4.1, -0.64), Vector3(2.1, 3.2, 0.1), CRIMSON)
	_cone(b, Vector3(0, 7.2, -0.95), 1.0, 1.9, GOLD)
	for s in [-1.0, 1.0]:
		_box(b, Vector3(s * 1.55, 2.85, 0.25), Vector3(0.45, 0.6, 2.2), GOLD.darkened(0.08))
		_gem(b, Vector3(s * 1.55, 3.3, 1.2), Vector3(0.36, 0.44, 0.36), Color("ff4a6a"))
		_cone(b, Vector3(s * 1.4, 6.8, -0.95), 0.35, 1.2, GOLD)
	_gem(b, Vector3(0, 5.9, -0.6), Vector3(0.7, 0.9, 0.3), Color("ff3a5a"))
	_gem(b, Vector3(0, 8.3, -0.95), Vector3(0.5, 0.7, 0.5), Color("fff0a0"))
	# The corner obelisks with their fire bowls, and the banners.
	for n in 4:
		var c := Vector3(12.0 if n % 2 == 0 else -12.0, 0, 12.0 if n < 2 else -12.0) / THRONE_SCALE
		_box(b, c + Vector3(0, 0.6, 0), Vector3(2.6, 1.2, 2.6), Color("6a5a48"), SurfaceKit.KIND_MASONRY)
		_box(b, c + Vector3(0, 5.2, 0), Vector3(1.4, 8.0, 1.4), MARBLE, SurfaceKit.KIND_STONE)
		_box(b, c + Vector3(0, 2.0, 0), Vector3(1.55, 0.3, 1.55), GOLD)
		_box(b, c + Vector3(0, 9.3, 0), Vector3(1.9, 0.3, 1.9), GOLD)
		_cyl(b, c + Vector3(0, 9.8, 0), 1.1, 0.7, Color("3a2a22"), 8)
		_flame(b, c + Vector3(0, 10.15, 0), 1.6, Color("ff8a2a"))
	for n in 4:
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, PI * 0.5 * float(n))
		var c := dir * 12.0 / THRONE_SCALE
		var th: Dictionary = THEMES[[1, 3, 2, 0][n]]
		b.cyl(c + Vector3(0, 4.5, 0), 0.14, 9.0, GOLD.darkened(0.1))
		_gem(b, c + Vector3(0, 9.2, 0), Vector3(0.4, 0.55, 0.4), th.glow)
		var side := dir.rotated(Vector3.UP, PI * 0.5)
		b.box(c + side * 0.7 + Vector3(0, 8.5, 0), side.abs() * 1.6 + Vector3(0, 0.12, 0) + dir.abs() * 0.12, GOLD)
		b.cloth(c + side * 0.9 + Vector3(0, 6.3, 0), side.abs() * 1.4 + Vector3(0, 4.2, 0) + dir.abs() * 0.06, th.roof, JapanKit.hanging_weight(8.4, 4.2))
	# The crown afloat, turning slowly (its own small mesh).
	var cb := JapanKit.Batch.new()
	for n in 16:
		var ang := TAU * float(n) / 16.0
		cb.box(Vector3(cos(ang) * 2.3, 0, sin(ang) * 2.3), Vector3(1.0, 1.0, 0.3), CROWN_GOLD, Vector3(0, -rad_to_deg(ang) + 90.0, 0))
	for n in 8:
		var ang := TAU * float(n) / 8.0
		var p := Vector3(cos(ang) * 2.3, 0.0, sin(ang) * 2.3)
		_cone(cb, p + Vector3(0, 1.15, 0), 0.5, 1.4, CROWN_GOLD)
		_gem(cb, p + Vector3(0, 2.05, 0), Vector3(0.42, 0.52, 0.42), [Color("ff4a6a"), Color("6ad8ff"), Color("6dffb0"), Color("fff07a")][n % 4])
		_gem(cb, p * 1.06 + Vector3(0, 0.05, 0), Vector3(0.36, 0.5, 0.2), [Color("6ad8ff"), Color("ff4a6a")][n % 2], true, Vector3(0, -rad_to_deg(ang) + 90.0, 0))
	_gem(cb, Vector3(0, 0.3, 0), Vector3(1.4, 1.8, 1.4), Color("fff3b0"))
	var crown := cb.commit(root, "MazeCrown", false)
	crown.position = at + Vector3(0, 11.0 * THRONE_SCALE, 0)
	crown.scale = Vector3.ONE * THRONE_SCALE
	crown.visibility_range_end = 0.0
	var spin := crown.create_tween().set_loops()
	spin.tween_property(crown, "rotation:y", TAU, 24.0).from(0.0)


## North-west: a giant moss-grown guardian kneeling over its planted sword, jade eyes and
## a jade pommel, crystals round its plinth.
static func _guardian(b: JapanKit.Batch, face: Vector3, th: Dictionary) -> void:
	var stone: Color = Color("c9cdb4")
	var moss: Color = th.accent
	var yaw := atan2(face.x, face.z)
	b.xform = b.xform * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	_box(b, Vector3(0, 0.45, 0), Vector3(7.2, 0.9, 7.2), th.dark, SurfaceKit.KIND_MASONRY)
	_box(b, Vector3(0, 1.15, 0), Vector3(5.8, 0.5, 5.8), stone.darkened(0.12), SurfaceKit.KIND_STONE)
	# Knees and shins, the body leaning forward, the head under a helmet.
	_box(b, Vector3(-0.95, 2.3, 0.6), Vector3(1.3, 1.8, 2.6), stone, SurfaceKit.KIND_STONE)
	_box(b, Vector3(0.95, 2.0, -0.6), Vector3(1.3, 1.3, 2.4), stone, SurfaceKit.KIND_STONE)
	_box(b, Vector3(0, 4.6, -0.3), Vector3(3.2, 3.6, 2.2), stone, SurfaceKit.KIND_STONE, Vector3(10, 0, 0))
	_box(b, Vector3(0, 4.8, -0.25), Vector3(3.4, 0.4, 2.4), th.metal, SurfaceKit.KIND_NONE, Vector3(10, 0, 0))
	for s in [-1.0, 1.0]:
		_orb(b, Vector3(s * 1.9, 6.0, -0.2), Vector3(1.5, 1.3, 1.5), stone.darkened(0.06))
		_box(b, Vector3(s * 1.2, 5.0, 1.0), Vector3(0.9, 2.6, 0.9), stone.darkened(0.04), SurfaceKit.KIND_STONE, Vector3(-40, 0, s * 12.0))
	_orb(b, Vector3(0, 7.4, 0.1), Vector3(2.0, 2.1, 2.0), stone)
	_cone(b, Vector3(0, 8.9, 0.0), 1.05, 1.5, th.dark)
	_box(b, Vector3(0, 8.25, 0.1), Vector3(2.2, 0.22, 2.2), th.metal)
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * 0.42, 7.5, 1.04), Vector3(0.36, 0.14, 0.08), th.glow, Vector3.ZERO, true)
	# The sword, planted before it.
	_box(b, Vector3(0, 3.6, 2.2), Vector3(0.6, 6.2, 0.18), Color("cfe0e8"))
	b.box(Vector3(0, 3.6, 2.31), Vector3(0.14, 5.4, 0.04), th.glow, Vector3.ZERO, true)
	_box(b, Vector3(0, 6.9, 2.2), Vector3(2.6, 0.4, 0.5), th.metal)
	_box(b, Vector3(0, 7.6, 2.2), Vector3(0.36, 1.1, 0.36), th.dark)
	_gem(b, Vector3(0, 8.5, 2.2), Vector3(0.8, 1.0, 0.8), th.glow)
	# Moss over it all.
	for n in 9:
		var ang := TAU * float(n) / 9.0
		_cyl(b, Vector3(cos(ang) * 1.7, 1.5 + float(n % 3) * 1.9, sin(ang) * 1.2 - 0.2), 0.8, 0.35, moss.darkened(float(n % 2) * 0.18), 6)
	_cyl(b, Vector3(0.3, 8.3, 0.1), 1.0, 0.3, moss, 6)
	# Jade crystals round the plinth.
	for n in 6:
		var ang := TAU * float(n) / 6.0 + 0.3
		var p := Vector3(cos(ang) * 3.4, 1.3, sin(ang) * 3.4)
		_cone(b, p + Vector3(0, 0.9, 0), 0.4, 2.0 - float(n % 2) * 0.6, th.glow, true, Vector3(sin(ang) * 18.0, 0, -cos(ang) * 18.0))
		_orb(b, p + Vector3(0.6, 0.1, 0.3), Vector3(0.9, 0.7, 0.9), (th.deco as Color))


## North-east: a stepped crimson fire temple, ember lines at every tier, a great fire on
## its top and a fire bowl on an obelisk at each corner.
static func _fire_temple(b: JapanKit.Batch, th: Dictionary) -> void:
	var tiers := [7.6, 6.0, 4.5, 3.1]
	var y := 0.0
	for i in tiers.size():
		var w: float = tiers[i]
		_box(b, Vector3(0, y + 0.95, 0), Vector3(w, 1.9, w), (th.stone as Color).darkened(float(i) * 0.04), SurfaceKit.KIND_STONE)
		_box(b, Vector3(0, y + 1.96, 0), Vector3(w + 0.24, 0.16, w + 0.24), th.trim, SurfaceKit.KIND_STONE)
		for n in 4:
			var side := Vector3(1, 0, 0).rotated(Vector3.UP, PI * 0.5 * float(n))
			b.box(side * (w * 0.5 + 0.02) + Vector3(0, y + 0.9, 0), Vector3(0.05, 0.14, w * 0.72) if absf(side.x) > 0.5 else Vector3(w * 0.72, 0.14, 0.05), th.accent, Vector3.ZERO, true)
			# A dark doorway with a lit lintel in the middle of each face of the lowest tier.
			if i == 0:
				_box(b, side * (w * 0.5 + 0.03) + Vector3(0, 0.75, 0), Vector3(0.06, 1.5, 1.1) if absf(side.x) > 0.5 else Vector3(1.1, 1.5, 0.06), Color("2a1414"))
		y += 2.0
	# Stairs up the south face.
	for st in 6:
		var sw := 1.8
		_box(b, Vector3(0, 0.35 + float(st) * 0.7, 3.8 - float(st) * 0.45), Vector3(sw, 0.7, 0.9), (th.trim as Color).darkened(0.1), SurfaceKit.KIND_STONE)
	_cyl(b, Vector3(0, y + 0.35, 0), 1.7, 0.7, Color("3a2422"), 10)
	_cyl(b, Vector3(0, y + 0.74, 0), 1.85, 0.12, th.metal, 10)
	_flame(b, Vector3(0, y + 0.7, 0), 2.8, th.accent)
	for n in 4:
		var c := Vector3(4.8 if n % 2 == 0 else -4.8, 0, 4.8 if n < 2 else -4.8)
		_box(b, c + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 1.4), th.dark, SurfaceKit.KIND_MASONRY)
		_box(b, c + Vector3(0, 2.9, 0), Vector3(0.8, 4.4, 0.8), th.stone, SurfaceKit.KIND_STONE)
		_cone(b, c + Vector3(0, 5.6, 0), 0.6, 1.0, th.dark)
		_cyl(b, c + Vector3(0, 5.25, 0), 0.6, 0.3, th.metal, 8)
		_flame(b, c + Vector3(0, 5.4, 0), 0.9, th.accent)


## South-west: a spire of sapphire crystal over a frosted dais, crystals leaning out round
## it and shards afloat.
static func _crystal_spire(b: JapanKit.Batch, th: Dictionary) -> void:
	_cyl(b, Vector3(0, 0.35, 0), 4.2, 0.7, th.dark, 12, SurfaceKit.KIND_STONE)
	_cyl(b, Vector3(0, 0.78, 0), 3.6, 0.2, th.trim, 12)
	_cone(b, Vector3(0, 6.6, 0), 1.9, 11.6, Color("9fd8ff"))
	_cone(b, Vector3(0, 7.6, 0), 1.05, 13.6, th.glow, true)
	for n in 7:
		var ang := TAU * float(n) / 7.0
		var r := 1.9 + float(n % 2) * 0.5
		var p := Vector3(cos(ang) * r, 0.8, sin(ang) * r)
		var h := 4.6 - float(n % 3) * 1.0
		var tilt := Vector3(sin(ang) * 22.0, 0, -cos(ang) * 22.0)
		if n % 2 == 0:
			_cone(b, p + Vector3(0, h * 0.5, 0), 0.6, h, th.glow, true, tilt)
		else:
			_cone(b, p + Vector3(0, h * 0.5, 0), 0.65, h, Color("c8ecff"), false, tilt)
	for n in 6:
		var ang := TAU * float(n) / 6.0 + 0.4
		_gem(b, Vector3(cos(ang) * 3.4, 6.5 + float(n % 3) * 1.3, sin(ang) * 3.4), Vector3(0.5, 0.9, 0.5), th.glow if n % 2 == 0 else Color("ffffff"))
	for n in 8:
		var ang := TAU * float(n) / 8.0
		_orb(b, Vector3(cos(ang) * 3.9, 0.85, sin(ang) * 3.9), Vector3(1.3, 0.5, 1.3), Color("f2fbff"))


## South-east: a golden sun orb on a tall pedestal, rays all round it, a ring of light,
## four gold obelisks.
static func _sun_orb(b: JapanKit.Batch, th: Dictionary) -> void:
	_box(b, Vector3(0, 0.5, 0), Vector3(6.4, 1.0, 6.4), th.dark, SurfaceKit.KIND_MASONRY)
	_box(b, Vector3(0, 1.3, 0), Vector3(4.8, 0.6, 4.8), MARBLE, SurfaceKit.KIND_STONE)
	_box(b, Vector3(0, 4.4, 0), Vector3(1.5, 5.6, 1.5), MARBLE, SurfaceKit.KIND_STONE)
	_box(b, Vector3(0, 2.0, 0), Vector3(1.8, 0.3, 1.8), th.metal)
	_box(b, Vector3(0, 7.3, 0), Vector3(2.0, 0.4, 2.0), th.metal)
	var c := Vector3(0, 9.6, 0)
	_orb(b, c, Vector3(3.6, 3.6, 3.6), th.metal)
	_gem(b, c, Vector3(2.6, 2.6, 2.6), Color("fff3b0"), true, Vector3(0, 45, 0))
	for n in 12:
		var ang := TAU * float(n) / 12.0
		var d := Vector3(cos(ang), sin(ang), 0)
		_cone(b, c + d * 2.6, 0.38, 1.6 if n % 2 == 0 else 1.1, th.metal, false, Vector3(0, 0, rad_to_deg(ang) - 90.0))
		var e := Vector3(cos(ang), 0, sin(ang))
		if n % 2 == 0:
			_cone(b, c + e * 2.5, 0.3, 1.2, th.metal, false, Vector3(0, -rad_to_deg(ang), -90.0))
	for n in 16:
		var ang := TAU * float(n) / 16.0
		b.box(c + Vector3(cos(ang) * 4.1, sin(ang) * 4.1, 0), Vector3(0.9, 0.16, 0.16), th.glow, Vector3(0, 0, rad_to_deg(ang) + 90.0), true)
	for n in 4:
		var p := Vector3(4.4 if n % 2 == 0 else -4.4, 0, 4.4 if n < 2 else -4.4)
		_box(b, p + Vector3(0, 2.4, 0), Vector3(0.7, 4.8, 0.7), th.metal)
		_cone(b, p + Vector3(0, 5.3, 0), 0.5, 1.0, th.metal)
		_gem(b, p + Vector3(0, 6.1, 0), Vector3(0.4, 0.55, 0.4), th.glow)


# --- The shrines --------------------------------------------------------------------

## Each shrine: a raised marble lotus platform with a gold rim, glowing petals laid round
## it, four slender pavilion posts with lanterns under small roofs, and a lotus altar with
## a floating crystal (low: whoever shelters by it is seen); a veil of light rises round
## the circle (MazeBeams).
static func _shrines(batches: Array[JapanKit.Batch], root: Node3D) -> void:
	for k in MazeLayout.safe_count():
		var at := MazeLayout.safe_center(k)
		var b := _chunk(batches, at)
		var r := MazeLayout.SAFE_RADIUS
		_cyl(b, at + Vector3(0, 0.05, 0), r + 0.55, 0.1, GOLD, 24)
		_cyl(b, at + Vector3(0, 0.08, 0), r + 0.35, 0.12, Color("f6f3ec"), 24, SurfaceKit.KIND_STONE)
		_cyl(b, at + Vector3(0, 0.15, 0), 2.0, 0.04, Color("7ad8d0"), 16)
		for n in 8:
			var ang := TAU * float(n) / 8.0
			var dir := Vector3(cos(ang), 0, sin(ang))
			_gem(b, at + dir * 3.1 + Vector3(0, 0.16, 0), Vector3(1.9, 0.05, 0.85), SAFE_COLOR.lerp(Color.WHITE, 0.25), true, Vector3(0, -rad_to_deg(ang), 0))
			var d2 := dir.rotated(Vector3.UP, TAU / 16.0)
			_gem(b, at + d2 * 2.35 + Vector3(0, 0.15, 0), Vector3(1.2, 0.05, 0.55), SAFE_GOLD, true, Vector3(0, -rad_to_deg(ang + TAU / 16.0), 0))
		for n in 4:
			var ang := TAU * float(n) / 4.0 + PI * 0.25
			var p := at + Vector3(cos(ang), 0, sin(ang)) * (r + 0.05)
			_box(b, p + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.75), Color("e6dfcf"), SurfaceKit.KIND_STONE)
			_box(b, p + Vector3(0, 1.45, 0), Vector3(0.42, 2.4, 0.42), Color("f8f6ef"), SurfaceKit.KIND_STONE)
			_box(b, p + Vector3(0, 2.7, 0), Vector3(0.62, 0.16, 0.62), GOLD)
			b.box(p + Vector3(0, 3.0, 0), Vector3(0.34, 0.42, 0.34), SAFE_COLOR, Vector3.ZERO, true)
			b.roof(p + Vector3(0, 3.42, 0), 1.0, 1.0, 0.55, Color("2a9a96"), 0.2, rad_to_deg(ang))
			_cone(b, p + Vector3(0, 3.95, 0), 0.08, 0.5, GOLD)
		# The lotus altar and its floating crystal.
		_cyl(b, at + Vector3(0, 0.3, 0), 0.8, 0.5, Color("ece6d8"), 8, SurfaceKit.KIND_STONE)
		for n in 6:
			var ang := TAU * float(n) / 6.0
			_gem(b, at + Vector3(cos(ang) * 0.55, 0.78, sin(ang) * 0.55), Vector3(0.4, 0.75, 0.22), Color("ffb8d4"), false, Vector3(0, -rad_to_deg(ang) + 90.0, 0))
		_orb(b, at + Vector3(0, 0.82, 0), Vector3(0.5, 0.42, 0.5), Color("fff2a8"), true)
		_gem(b, at + Vector3(0, 1.75, 0), Vector3(0.5, 0.85, 0.5), Color("c8fff6"))
		var tag := Label3D.new()
		tag.name = "ShrineTag%d" % k
		tag.text = "ที่หลบภัย"
		tag.font_size = 72
		tag.pixel_size = 0.007
		tag.outline_size = 14
		tag.modulate = SAFE_COLOR.lerp(Color.WHITE, 0.4)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = false
		tag.position = at + Vector3(0, 3.6, 0)
		tag.visibility_range_end = 56.0
		root.add_child(tag)


# --- Light: beams, veils, motes, lanterns --------------------------------------------------

static func _fx_material(mode: int) -> ShaderMaterial:
	if not _fx_mats.has(mode):
		var mat := ShaderMaterial.new()
		mat.shader = FX_SHADER
		mat.set_shader_parameter("mode", mode)
		_fx_mats[mode] = mat
	return _fx_mats[mode]


## An open tube of light (UV.y 0 at its foot) into a SurfaceTool.
static func _tube(st: SurfaceTool, foot: Vector3, radius: float, height: float, color: Color, sides: int, top_radius := -1.0) -> void:
	var tr := radius if top_radius < 0.0 else top_radius
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var u0 := float(i) / float(sides)
		var u1 := float(i + 1) / float(sides)
		var quad := [[foot + d0 * radius, d0, Vector2(u0, 0)], [foot + d1 * radius, d1, Vector2(u1, 0)],
			[foot + d1 * tr + Vector3(0, height, 0), d1, Vector2(u1, 1)], [foot + d0 * tr + Vector3(0, height, 0), d0, Vector2(u0, 1)]]
		for corner in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(quad[corner][1])
			st.set_uv(quad[corner][2])
			st.add_vertex(quad[corner][0])


## The beams from the landmarks into the sky and the shrines' veils (one additive mesh),
## the fireflies, embers and sparkles over the floor and the sky lanterns overhead
## (camera-facing MultiMeshes moved by maze_fx.gdshader). Their counts follow the quality
## and the memory pressure (VfxBudget.count).
static func _light_fx(root: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var glow: Color = CROWN_GOLD.lightened(0.2) if k == 0 else (_theme(at + Vector3(0.1, 0, 0.1)).glow as Color)
		var foot := at + Vector3(0, _beacon_top(k) - 1.5, 0)
		_tube(st, foot, 2.2 if k == 0 else 1.5, 95.0, Color(glow, 0.55), 12, 3.4 if k == 0 else 2.4)
		_tube(st, foot, 0.7, 110.0, Color(glow.lerp(Color.WHITE, 0.5), 0.6), 8, 1.0)
	var beams := MeshInstance3D.new()
	beams.name = "MazeBeams"
	beams.mesh = st.commit()
	beams.material_override = _fx_material(0)
	beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beams)
	# The shrines' veils of light (seen from afar too: where to run).
	var vt := SurfaceTool.new()
	vt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in MazeLayout.safe_count():
		_tube(vt, MazeLayout.safe_center(k) + Vector3(0, 0.1, 0), MazeLayout.SAFE_RADIUS + 0.45, 3.2, Color(SAFE_COLOR, 0.85), 28, MazeLayout.SAFE_RADIUS - 0.4)
	var veils := MeshInstance3D.new()
	veils.name = "MazeVeils"
	veils.mesh = vt.commit()
	veils.material_override = _fx_material(3)
	veils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(veils)
	# Motes over the floor: fireflies in the jade ruins, embers rising in the fire temple,
	# sparkles in the frost halls, golden motes in the sun court; thicker by the shrines.
	var motes := VfxBudget.count(230, 40)
	var mt: Array[Transform3D] = []
	var mc: Array[Color] = []
	var mx: Array[Color] = []
	for i in motes:
		var p := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)) * (MazeLayout.HALF - 3.0)
		if i % 4 == 0:
			var s := MazeLayout.safe_center(i / 4 % MazeLayout.safe_count())
			p = s + Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)) * MazeLayout.SAFE_RADIUS
		var q := MazeLayout.quadrant(p)
		var ember := q == 1 and i % 4 != 0
		p.y = rng.randf_range(0.2, 0.8) if ember else rng.randf_range(0.5, 2.6)
		var size := rng.randf_range(0.24, 0.42) if ember else rng.randf_range(0.32, 0.6)
		mt.append(Transform3D(Basis.from_scale(Vector3.ONE * size), p))
		var col: Color = SAFE_COLOR if i % 4 == 0 else (THEMES[q].glow as Color)
		mc.append(Color(col.lerp(Color.WHITE, 0.25), 0.9))
		mx.append(Color(1.0 if ember else 0.0, rng.randf(), 0, 0))
	_fx_multi(root, "MazeMotes", mt, mc, mx, 1, AABB(Vector3(-MazeLayout.HALF - 4.0, -1.0, -MazeLayout.HALF - 4.0), Vector3(MazeLayout.HALF * 2.0 + 8.0, 8.0, MazeLayout.HALF * 2.0 + 8.0)))
	# Sky lanterns (โคมลอย) drifting high over the maze and the isle.
	var lanterns := VfxBudget.count(70, 16)
	var lt: Array[Transform3D] = []
	var lc: Array[Color] = []
	var lx: Array[Color] = []
	for i in lanterns:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (ISLE + 40.0)
		var y := rng.randf_range(16.0, 58.0)
		var size := rng.randf_range(1.8, 2.8) * (1.0 + (y - 16.0) / 60.0)
		lt.append(Transform3D(Basis.from_scale(Vector3(size, size * 1.3, size)), Vector3(cos(a) * r, y, sin(a) * r)))
		lc.append(Color(Color("ffb050").lerp(Color("ffd890"), rng.randf()), 0.95))
		lx.append(Color(0, rng.randf(), 0, 0))
	_fx_multi(root, "MazeSkyLanterns", lt, lc, lx, 2, AABB(Vector3(-ISLE - 50.0, 10.0, -ISLE - 50.0), Vector3(ISLE * 2.0 + 100.0, 56.0, ISLE * 2.0 + 100.0)))


static func _fx_multi(root: Node3D, node_name: String, transforms: Array[Transform3D], colors: Array[Color], custom: Array[Color], mode: int, box: AABB) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = MeshKit.quad()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, custom[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = _fx_material(mode)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = box
	root.add_child(mmi)


# --- Signs, colliders ----------------------------------------------------------------

## The quadrants' and the throne plaza's names over their plazas.
static func _signs(root: Node3D) -> void:
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var q := MazeLayout.quadrant(at + Vector3(0.1, 0, 0.1))
		var tag := Label3D.new()
		tag.name = "PlazaName%d" % k
		tag.text = MazeLayout.CENTER_NAME if k == 0 else String(MazeLayout.QUADRANTS[q].name)
		tag.font_size = 64
		tag.outline_size = 14
		tag.modulate = CROWN_GOLD if k == 0 else (THEMES[q].glow as Color).lerp(Color.WHITE, 0.45)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = at + Vector3(0, _beacon_top(k) + (3.5 if k == 0 else 2.5), 0)
		tag.visibility_range_end = 90.0
		root.add_child(tag)


## The walls' colliders: one static body per quadrant, a box per run.
static func _colliders(root: Node3D) -> void:
	var bodies: Array[StaticBody3D] = []
	for q in 4:
		var body := StaticBody3D.new()
		body.name = "MazeWalls%d" % q
		body.collision_layer = 1
		root.add_child(body)
		bodies.append(body)
	for s in MazeLayout.segments():
		var a: Vector3 = s[0]
		var e: Vector3 = s[1]
		var along_x := absf(e.x - a.x) > absf(e.z - a.z)
		var length := a.distance_to(e) + MazeLayout.WALL_T
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, MazeLayout.WALL_H + 1.0, MazeLayout.WALL_T) if along_x else Vector3(MazeLayout.WALL_T, MazeLayout.WALL_H + 1.0, length)
		shape.shape = box
		shape.position = (a + e) * 0.5 + Vector3(0, (MazeLayout.WALL_H + 1.0) * 0.5, 0)
		bodies[int(s[2])].add_child(shape)


# --- The isle ------------------------------------------------------------------------

## The isle's rim at angle a (a rounded square, a little ragged).
static func _rim(a: float) -> float:
	var n := 6.0
	var c := absf(cos(a))
	var s := absf(sin(a))
	var r := ISLE / pow(pow(c, n) + pow(s, n), 1.0 / n)
	return r + sin(a * 7.0) * 2.2 + sin(a * 13.0 + 1.3) * 1.3


static func _isle_material() -> ShaderMaterial:
	return SurfaceKit.vertex_material(true, true, SurfaceKit.KIND_EARTH)


## The isle: a green terrace round the outer wall with a stone kerb at its rim, then
## cliffs of banded rock falling into the cloud and the isle's underside narrowing to a
## point far below; trees (pines and blossom), stone lanterns, a bastion at each corner of
## the maze and falls spilling off the rim.
static func _isle(root: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 128
	# [radius scale (0 = the maze's edge), y, colour]: the rings from the wall out and down.
	var rings := [[0.0, 0.0, Color("6a9a52")], [-3.0, -0.02, Color("7fb25c")], [-3.0, -0.02, Color("d2bf94")], [0.6, -0.35, Color("bca47a")],
		[1.6, -4.0, Color("d39a68")], [0.4, -9.0, Color("b97858")], [-2.0, -15.0, Color("e0ac78")], [-6.0, -23.0, Color("a86a52")],
		[-14.0, -34.0, Color("c8906a")], [-30.0, -50.0, Color("8a5a5e")], [-60.0, -72.0, Color("6e4a62")], [-100.0, -100.0, Color("5a4060")]]
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var pts0: Array[Vector3] = []
		var pts1: Array[Vector3] = []
		var cols: Array[Color] = []
		for j in rings.size():
			var ring: Array = rings[j]
			for a in [a0, a1]:
				var r: float
				if j == 0:
					var c := absf(cos(a))
					var s := absf(sin(a))
					r = (MazeLayout.HALF - 0.6) / maxf(c, s)
				else:
					r = _rim(a) + float(ring[0]) + (sin(a * 5.0 + float(j)) * float(j) * 0.4 if j >= 4 else 0.0)
				var p := Vector3(cos(a) * r, float(ring[1]), sin(a) * r)
				if a == a0:
					pts0.append(p)
				else:
					pts1.append(p)
			cols.append(ring[2])
		for j in rings.size() - 1:
			var c0: Color = cols[j].darkened(0.04 * sin(a0 * 9.0))
			var c1: Color = cols[j + 1].darkened(0.04 * sin(a0 * 9.0 + 1.0))
			_quad(st, pts0[j], pts1[j], pts1[j + 1], pts0[j + 1], c0, c0, c1, c1)
	st.generate_normals()
	var isle := MeshInstance3D.new()
	isle.name = "MazeIsle"
	isle.mesh = st.commit()
	isle.material_override = _isle_material()
	isle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(isle)
	# Trees on the terrace (a MultiMesh each for trunks, pine crowns, blossom crowns).
	var trunks: Array[Transform3D] = []
	var trunk_c: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_c: Array[Color] = []
	var blooms: Array[Transform3D] = []
	var bloom_c: Array[Color] = []
	var count := VfxBudget.count(120, 50)
	for i in count:
		var a := rng.randf() * TAU
		var inner := (MazeLayout.HALF + 4.0) / maxf(absf(cos(a)), absf(sin(a)))
		var outer := _rim(a) - 4.0
		if outer <= inner + 1.0:
			continue
		var r := rng.randf_range(inner, outer)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var bloom := rng.randf() < 0.45
		var h := rng.randf_range(5.0, 9.0) if not bloom else rng.randf_range(3.6, 5.4)
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.6, h * 0.55, 0.6)), p + Vector3(0, h * 0.27, 0)))
		trunk_c.append(Color("5a3a2c"))
		if bloom:
			for k in 3:
				var s := rng.randf_range(2.6, 3.6)
				blooms.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.75, s)), p + Vector3(rng.randf_range(-0.9, 0.9), h * 0.62 + float(k) * 0.6, rng.randf_range(-0.9, 0.9))))
				bloom_c.append(Color("ff9ec4").lerp(Color("fff0f6"), rng.randf() * 0.6) if MazeLayout.quadrant(p) != 2 else Color("e8f6ff").lerp(Color("b8dcff"), rng.randf()))
		else:
			for k in 3:
				var s := (1.0 - float(k) * 0.26) * rng.randf_range(3.2, 4.4)
				pines.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.85, s)), p + Vector3(0, h * 0.42 + float(k) * h * 0.2, 0)))
				pine_c.append(Color("2c5a44").lerp(Color("4a8a54"), rng.randf()))
	_multi(root, "MazeTrunks", MeshKit.cylinder(), trunks, trunk_c)
	_multi(root, "MazePines", MeshKit.cone(), pines, pine_c)
	_multi(root, "MazeBlossoms", _ball(), blooms, bloom_c)
	# Stone lanterns round the outer wall, the corner bastions.
	var b := JapanKit.Batch.new()
	var n := VfxBudget.count(48, 20)
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		var r := (MazeLayout.HALF + 3.4) / maxf(absf(cos(a)), absf(sin(a)))
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var glow: Color = (THEMES[MazeLayout.quadrant(p)].glow as Color)
		_box(b, p + Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), Color("b8ab92"), SurfaceKit.KIND_STONE)
		b.box(p + Vector3(0, 1.3, 0), Vector3(0.6, 0.6, 0.6), glow.lerp(Color("ffd890"), 0.5), Vector3.ZERO, true)
		b.roof(p + Vector3(0, 1.85, 0), 1.2, 1.2, 0.5, Color("5a5048"), 0.1)
	for c in 4:
		var p := Vector3(MazeLayout.HALF + 2.5 if c % 2 == 1 else -MazeLayout.HALF - 2.5, 0, MazeLayout.HALF + 2.5 if c >= 2 else -MazeLayout.HALF - 2.5)
		_bastion(b, p, THEMES[c])
	var mi := b.commit(root, "MazeTerrace", false)
	mi.visibility_range_end = 0.0
	# Falls spilling off the rim into the cloud.
	var fall := SurfaceTool.new()
	fall.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a := TAU * (float(i) + 0.25) / 8.0 + 0.2
		var r := _rim(a) - 0.5
		_fall(fall, Vector3(cos(a) * r, -0.25, sin(a) * r), Vector3(cos(a), 0, sin(a)), rng.randf_range(4.0, 7.0), 52.0, Color("9fe2f2"))
	_far_mesh(root, fall, 2, "MazeFalls")


## A bastion at a corner of the maze: a stepped tower in the quadrant's stone with tiered
## roofs, a gold spire and a lit lantern.
static func _bastion(b: JapanKit.Batch, p: Vector3, th: Dictionary) -> void:
	_box(b, p + Vector3(0, 0.8, 0), Vector3(8.6, 1.6, 8.6), th.dark, SurfaceKit.KIND_MASONRY)
	_box(b, p + Vector3(0, 5.6, 0), Vector3(7.0, 8.0, 7.0), th.stone, SurfaceKit.KIND_STONE)
	_box(b, p + Vector3(0, 9.75, 0), Vector3(7.8, 0.3, 7.8), th.trim, SurfaceKit.KIND_STONE)
	for s in 4:
		var side := Vector3(1, 0, 0).rotated(Vector3.UP, PI * 0.5 * float(s))
		b.box(p + side * 3.52 + Vector3(0, 6.6, 0), Vector3(0.06, 1.6, 0.9) if absf(side.x) > 0.5 else Vector3(0.9, 1.6, 0.06), th.glow, Vector3.ZERO, true)
	b.roof(p + Vector3(0, 11.0, 0), 9.4, 9.4, 2.2, th.roof, 0.05)
	_box(b, p + Vector3(0, 12.9, 0), Vector3(4.0, 2.0, 4.0), th.stone, SurfaceKit.KIND_STONE)
	b.roof(p + Vector3(0, 14.6, 0), 5.8, 5.8, 1.8, (th.roof as Color).darkened(0.1), 0.05)
	_cone(b, p + Vector3(0, 17.2, 0), 0.6, 3.2, th.metal)
	_gem(b, p + Vector3(0, 19.1, 0), Vector3(0.7, 0.9, 0.7), th.glow)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [d, cd]]:
		st.set_color(v[1])
		st.add_vertex(v[0])


## A sheet of water arcing off a lip and falling `drop` metres (UV.y down its length).
static func _fall(st: SurfaceTool, top: Vector3, out: Vector3, width: float, drop: float, color: Color) -> void:
	var side := Vector3(-out.z, 0, out.x)
	var profile := [[0.0, 0.0], [0.6, -0.15], [1.3, -0.9], [2.0, -2.8], [2.6, -6.5], [3.0, -13.0], [3.3, -24.0], [3.5, -drop]]
	var length := 0.0
	var rows: Array = []
	for i in profile.size():
		var p: Vector3 = top + out * float(profile[i][0]) + Vector3(0, float(profile[i][1]), 0)
		if i > 0:
			length += p.distance_to(rows[i - 1][0])
		var t := float(i) / float(profile.size() - 1)
		rows.append([p, width * (1.0 + 0.6 * t) * 0.5, length / 6.0, color.lerp(Color.WHITE, 0.3 + 0.5 * minf(t * 3.0, 1.0))])
	for i in rows.size() - 1:
		var quad := [[rows[i], -1.0], [rows[i], 1.0], [rows[i + 1], 1.0], [rows[i + 1], -1.0]]
		for corner in [0, 1, 2, 0, 2, 3]:
			var row: Array = quad[corner][0]
			var s: float = quad[corner][1]
			st.set_color(row[3])
			st.set_uv(Vector2(s * 0.5 + 0.5, float(row[2])))
			st.set_normal(-out)
			st.add_vertex((row[0] as Vector3) + side * (float(row[1]) * s))


static func _ball() -> ArrayMesh:
	if _ball_mesh == null:
		_ball_mesh = ArrayMesh.new()
		_ball_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _lowball_arrays())
	return _ball_mesh


static func _multi(root: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = SurfaceKit.vertex_material(true, true)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


# --- The world round the isle --------------------------------------------------------

static func _far_material(mode: int) -> ShaderMaterial:
	if not _far_mats.has(mode):
		var mat := ShaderMaterial.new()
		mat.shader = FAR_SHADER
		mat.set_shader_parameter("mode", mode)
		mat.set_shader_parameter("haze", Color("cdd6f4"))
		mat.set_shader_parameter("haze_max", 0.32)
		mat.set_shader_parameter("keep", 225.0)
		mat.set_shader_parameter("span", 32.0)
		_far_mats[mode] = mat
	return _far_mats[mode]


static func _far_mesh(root: Node3D, st: SurfaceTool, mode: int, node_name: String, normals := false) -> MeshInstance3D:
	if normals:
		st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	mi.material_override = _far_material(mode)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 400.0
	root.add_child(mi)
	return mi


## The sea of cloud (a great disc, gold toward the sun, rose away from it, with banks of
## cloud on it), the two far ranges, the floating isles with their falls and the four
## prang towers of the quadrants on the isles at the corners. All drawn by maze_far.gdshader.
static func _world(root: Node3D, rng: RandomNumberGenerator) -> void:
	var sun_from := -Basis.from_euler(Vector3(deg_to_rad(SUN_ROT.x), deg_to_rad(SUN_ROT.y), 0)).z
	var sun_flat := Vector2(sun_from.x, sun_from.z).normalized()
	# The sea of cloud.
	var sea := SurfaceTool.new()
	sea.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [ISLE * 0.6, ISLE + 30.0, 260.0, 420.0, 650.0, 950.0, 1400.0]
	var near := [Color("fffaf2"), Color("eef0ff"), Color("c9d2f6"), Color("aab6ec"), Color("a4aae0"), Color("e4c2bc"), SKY_PALETTE[2]]
	var segs := 64
	for ring in radii.size() - 1:
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var pts: Array[Vector3] = []
			var cols: Array[Color] = []
			for corner in [[a0, ring], [a1, ring], [a1, ring + 1], [a0, ring + 1]]:
				var a: float = corner[0]
				var rr: int = corner[1]
				var r: float = radii[rr]
				var sunward := maxf(0.0, Vector2(cos(a), sin(a)).dot(sun_flat))
				var col: Color = (near[rr] as Color).lerp(Color("ffcf8a"), sunward * 0.8 * minf(1.0, float(rr) / 2.0))
				pts.append(Vector3(cos(a) * r, CLOUD_Y + sin(a * 6.0 + float(rr)) * 1.5, sin(a) * r))
				cols.append(col)
			for k in [0, 2, 1, 0, 3, 2]:
				sea.set_color(cols[k])
				sea.set_normal(Vector3.UP)
				sea.add_vertex(pts[k])
	_far_mesh(root, sea, 1, "MazeCloudSea")
	# Banks of cloud: on the sea and hugging the isle's cliffs.
	var pt: Array[Transform3D] = []
	var pc: Array[Color] = []
	var banks := VfxBudget.count(50, 20)
	for i in banks:
		var a := rng.randf() * TAU
		var hug := i % 3 == 0
		var r := _rim(a) + rng.randf_range(4.0, 40.0) if hug else rng.randf_range(ISLE + 50.0, 700.0)
		var w := rng.randf_range(16.0, 34.0) if hug else rng.randf_range(30.0, 110.0)
		var y := rng.randf_range(-30.0, -14.0) if hug else CLOUD_Y + rng.randf_range(-2.0, 4.0)
		var sunward := maxf(0.0, Vector2(cos(a), sin(a)).dot(sun_flat))
		var centre := Vector3(cos(a) * r, y, sin(a) * r)
		var across := Vector3(-sin(a), 0, cos(a))
		for k in 5:
			var off := (float(k) - 2.0) * 0.5
			var o := across * off * w * 0.5 + Vector3(0, w * (0.16 - absf(off) * 0.1), 0) + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)) * w
			var s := w * (0.8 - absf(off) * 0.32)
			pt.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.55, 0.75), s * rng.randf_range(0.65, 0.9))), centre + o))
			pc.append(Color("ffffff").lerp(Color("ffe0b0"), sunward * 0.8).lerp(Color("dcdcf6"), (1.0 - sunward) * 0.35))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _ball()
	mm.instance_count = pt.size()
	for i in pt.size():
		mm.set_instance_transform(i, pt[i])
		mm.set_instance_color(i, pc[i])
	var puffs := MultiMeshInstance3D.new()
	puffs.name = "MazeCloudBanks"
	puffs.multimesh = mm
	puffs.material_override = _far_material(1)
	puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puffs.extra_cull_margin = 400.0
	root.add_child(puffs)
	# The far ranges and the floating isles (one lit mesh), their glow and their falls.
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	_range(rock, 520.0, 110.0, 150.0, Color("27306e"), Color("4e5aa6"), 11, 0.0)
	_range(rock, 820.0, 160.0, 230.0, Color("44508e"), Color("6e7cbc"), 23, 0.9)
	var glow := JapanKit.Batch.new()
	var body := JapanKit.Batch.new()
	var falls := SurfaceTool.new()
	falls.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var corner := i < 4
		var a := (TAU * (float(i) + 0.5) / 4.0) if corner else TAU * (float(i - 4) + rng.randf_range(0.2, 0.8)) / 8.0
		var r := rng.randf_range(250.0, 290.0) if corner else rng.randf_range(185.0, 330.0)
		var size := rng.randf_range(26.0, 32.0) if corner else rng.randf_range(9.0, 20.0)
		var y := rng.randf_range(12.0, 26.0) if corner else rng.randf_range(4.0, 52.0)
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		_float_isle(body, falls, p, size, rng)
		if corner:
			var q := MazeLayout.quadrant(p)
			_prang(body, glow, p, THEMES[q], size)
	_far_mesh(root, rock, 0, "MazeFarRock", false)
	var isles := MeshInstance3D.new()
	isles.name = "MazeFarIsles"
	isles.mesh = body.mesh()
	isles.material_override = _far_material(0)
	isles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	isles.extra_cull_margin = 400.0
	root.add_child(isles)
	var glow_mesh := glow.mesh()
	if glow_mesh.get_surface_count() > 0:
		var gi := MeshInstance3D.new()
		gi.name = "MazeFarGlow"
		gi.mesh = glow_mesh
		gi.material_override = _far_material(3)
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.extra_cull_margin = 400.0
		root.add_child(gi)
	_far_mesh(root, falls, 2, "MazeFarFalls")


## A ring of mountains `radius` out: peaks to `height` (up to `peak` for the tallest),
## from the cloud up, `lo` at the foot to `hi` at the crest, snow on the high peaks.
static func _range(st: SurfaceTool, radius: float, height: float, peak: float, lo: Color, hi: Color, seed_value: int, phase: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.9
	var segs := 160
	var rows := 5
	var pts: Array = []
	for j in rows + 1:
		var row: Array = []
		var t := float(j) / float(rows)
		for i in segs + 1:
			var a := TAU * float(i) / float(segs)
			var crest := 0.45 + 0.55 * (noise.get_noise_1d(a * 1.6 + phase) * 0.5 + 0.5)
			crest += pow(absf(sin(a * 7.0 + phase * 3.0)), 6.0) * 0.35 + pow(absf(sin(a * 17.0 + phase)), 12.0) * 0.25
			var tall := lerpf(height, peak, pow(absf(sin(a * 2.0 + phase)), 3.0))
			var h := CLOUD_Y - 8.0 + (tall * crest + 8.0) * pow(t, 0.85)
			var r := radius + 70.0 * t + noise.get_noise_1d(a * 3.0 + 9.0) * 25.0
			row.append(Vector3(cos(a) * r, h, sin(a) * r))
		pts.append(row)
	for j in rows:
		for i in segs:
			var p00: Vector3 = pts[j][i]
			var p01: Vector3 = pts[j][i + 1]
			var p10: Vector3 = pts[j + 1][i]
			var p11: Vector3 = pts[j + 1][i + 1]
			var c0 := lo.lerp(hi, float(j) / float(rows))
			var c1 := lo.lerp(hi, float(j + 1) / float(rows))
			var snow0 := Color("fff4ea") if p00.y > CLOUD_Y + peak * 0.78 else c0
			var snow1 := Color("fff4ea") if p10.y > CLOUD_Y + peak * 0.78 else c1
			_quad(st, p00, p01, p11, p10, snow0 if j > 0 else c0, snow0 if j > 0 else c0, snow1, snow1)
	st.generate_normals()


## A floating isle: a grassy top with a stone rim, its rock hanging below to a point, a
## blossom or two, a fall spilling from its edge.
static func _float_isle(b: JapanKit.Batch, falls: SurfaceTool, p: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	_cyl(b, p + Vector3(0, -0.4, 0), size, 0.8, Color("7ab35e"), 12)
	_cyl(b, p + Vector3(0, -1.6, 0), size * 1.02, 1.8, Color("c9a27a"), 12)
	b.add(JapanKit.arrays("cone"), JapanKit.place(p + Vector3(0, -2.5 - size * 0.9, 0), Vector3(size * 2.0, size * 1.8, size * 2.0), Vector3(180, rng.randf() * 90.0, 0)), Color("9a6a5a"), false)
	b.add(JapanKit.arrays("cone"), JapanKit.place(p + Vector3(size * 0.3, -2.5 - size * 1.4, size * 0.2), Vector3(size * 0.9, size * 2.4, size * 0.9), Vector3(180, 0, 8)), Color("6e4a62"), false)
	for k in 2 + int(size / 12.0):
		var o := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * size
		_orb(b, p + o + Vector3(0, size * 0.18, 0), Vector3(size * 0.3, size * 0.24, size * 0.3), Color("ffa8c8").lerp(Color("8acb6a"), rng.randf() * 0.7))
	var a := rng.randf() * TAU
	var out := Vector3(cos(a), 0, sin(a))
	_fall(falls, p + out * (size * 0.98) + Vector3(0, -0.3, 0), out, size * 0.22, size * 2.6, Color("a8e6f4"))


## A prang tower of the quadrant (a Thai temple spire): a stepped base, the tall body in
## the quadrant's stone banded in gold and white, the spire with its glowing tip.
static func _prang(b: JapanKit.Batch, glow: JapanKit.Batch, p: Vector3, th: Dictionary, size: float) -> void:
	var base := p + Vector3(0, 0, 0)
	_box(b, base + Vector3(0, 1.5, 0), Vector3(size * 0.9, 3.0, size * 0.9), th.trim)
	_box(b, base + Vector3(0, 4.5, 0), Vector3(size * 0.62, 3.0, size * 0.62), th.stone)
	var y := 6.0
	var r := size * 0.26
	for k in 9:
		var h := 4.6 - float(k) * 0.28
		_cyl(b, base + Vector3(0, y + h * 0.5, 0), r, h, (th.stone as Color).lightened(float(k % 2) * 0.12), 8)
		_cyl(b, base + Vector3(0, y + h, 0), r * 1.08, 0.6, th.metal if k % 2 == 0 else th.trim, 8)
		if k % 3 == 1:
			for s in 4:
				var d := Vector3(1, 0, 0).rotated(Vector3.UP, PI * 0.5 * float(s) + PI * 0.125)
				glow.box(base + d * (r * 0.98) + Vector3(0, y + h * 0.5, 0), Vector3(0.8, 1.6, 0.8), th.glow)
		y += h + 0.4
		r *= 0.86
	_cone(b, base + Vector3(0, y + 5.0, 0), r * 0.9, 10.0, th.metal)
	glow.box(base + Vector3(0, y + 10.6, 0), Vector3(1.4, 2.4, 1.4), th.glow)
	glow.box(base + Vector3(0, y + 10.6, 0), Vector3(0.6, 4.0, 0.6), Color.WHITE)
