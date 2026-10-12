class_name Scenery
extends RefCounted
## Builds the look of a zone: coloured ground, trees, bushes, rocks, grass and
## flowers (Quaternius nature models via [NatureKit]) and the sky.

const PINES := ["PineTree_1", "PineTree_2", "PineTree_4", "PineTree_5"]
const BROADLEAFS := [["MapleTree_4", 5.0], ["NormalTree_5", 4.0], ["MapleTree_1", 1.5], ["BirchTree_4", 1.0]]
## Light models for the dense forest wall outside the play area.
const WALL_TREES := ["PineTree_5", "MapleTree_4", "PineTree_5", "NormalTree_5"]
const BUSHES := ["Bush", "Bush_Large", "Bush_Small", "Bush_Flowers", "Bush_Large_Flowers", "Bush_Small_Flowers"]
const ROCKS := ["Rock_1", "Rock_2", "Rock_3", "Rock_4", "Rock_5"]
const FLOWER_MODELS := ["Plant_Flowers", "Plant_1", "Petals_1", "Plant_2"]

## Per-theme scenery: tree models (weighted), light wall trees, bush / flower /
## rock counts and the bush colours. Themes not listed use "meadow".
const THEME_SETS := {
	&"village": {
		"trees": [["MapleTree_4", 3.0], ["NormalTree_5", 2.0], ["PineTree_2", 2.0], ["PineTree_4", 1.0]],
		"wall": ["PineTree_5", "MapleTree_4", "PineTree_4", "NormalTree_5"],
		"bushes": 70, "flowers": 60, "rocks": 30, "bush_colors": [Color("e8a0c0"), Color("f4d0dc"), Color("eef0df"), Color("c8a0d8")],
	},
	&"digital": {
		"trees": [["NormalTree_5", 4.0], ["MapleTree_4", 3.0], ["BirchTree_4", 2.0], ["PineTree_2", 1.0]],
		"wall": ["NormalTree_5", "MapleTree_4", "BirchTree_4"],
		"bushes": 135, "flowers": 110, "rocks": 65, "bush_colors": [Color("91b7a0"), Color("a1c0a5"), Color("acb3d0"), Color("96a1c0")],
	},
	&"desert": {
		"trees": [["PalmTree_1", 4.0], ["PalmTree_3", 3.0], ["DeadTree_5", 2.0], ["DeadTree_9", 1.5]],
		"wall": ["PalmTree_1", "DeadTree_5", "PalmTree_3", "DeadTree_9"],
		"bushes": 50, "flowers": 20, "rocks": 80, "bush_colors": [Color("c9b060"), Color("a8b04a"), Color("e0c070")],
	},
	&"snow": {
		"trees": [["PineTree_1", 3.0], ["PineTree_2", 3.0], ["PineTree_4", 3.0], ["PineTree_5", 2.0], ["DeadTree_5", 1.0]],
		"wall": ["PineTree_5", "PineTree_4", "PineTree_5", "PineTree_2"],
		"bushes": 60, "flowers": 0, "rocks": 80, "bush_colors": [Color("e8f4ff"), Color("c8e0f0"), Color("ffffff")],
	},
	&"graveyard": {
		"trees": [["DeadTree_5", 3.0], ["DeadTree_9", 3.0]],
		"wall": ["DeadTree_5", "DeadTree_9"],
		"bushes": 20, "flowers": 0, "rocks": 130, "bush_colors": [Color("4a4a5a"), Color("5a6a62"), Color("3a3a48")],
	},
	&"swamp": {
		"trees": [["PalmTree_1", 3.0], ["PalmTree_3", 3.0], ["DeadTree_5", 2.0], ["NormalTree_3", 1.5]],
		"wall": ["PalmTree_1", "DeadTree_9", "PalmTree_3", "DeadTree_5"],
		"bushes": 70, "flowers": 10, "rocks": 50, "bush_colors": [Color("5a8a3a"), Color("7a9a48"), Color("4a6a30")],
	},
	&"storm": {
		"trees": [["PineTree_1", 2.0], ["PineTree_5", 2.0], ["DeadTree_5", 2.0]],
		"wall": ["PineTree_5", "DeadTree_5", "PineTree_4"],
		"bushes": 25, "flowers": 0, "rocks": 170, "bush_colors": [Color("6a7888"), Color("8898a8"), Color("586470")],
	},
	&"sky": {
		"trees": [["BirchTree_4", 3.0], ["MapleTree_1", 2.0], ["NormalTree_5", 1.5]],
		"wall": ["BirchTree_4", "MapleTree_4", "NormalTree_3"],
		"bushes": 40, "flowers": 80, "rocks": 40, "bush_colors": [Color("f0e8b0"), Color("fff6d0"), Color("e8d890")],
	},
	&"void": {
		"trees": [["DeadTree_5", 3.0], ["DeadTree_9", 3.0]],
		"wall": ["DeadTree_9", "DeadTree_5"],
		"bushes": 25, "flowers": 0, "rocks": 160, "bush_colors": [Color("8a3ad0"), Color("c04ae0"), Color("4a2a9a")],
	},
	&"abyss": {
		"trees": [["DeadTree_5", 3.0], ["DeadTree_9", 3.0]],
		"wall": ["DeadTree_9", "DeadTree_5"],
		"bushes": 15, "flowers": 0, "rocks": 140, "bush_colors": [Color("6a1a28"), Color("3a1a22"), Color("8a2a34")],
	},
	&"volcano": {
		"trees": [["DeadTree_5", 3.0], ["DeadTree_9", 3.0]],
		"wall": ["DeadTree_5", "DeadTree_9"],
		"bushes": 30, "flowers": 0, "rocks": 120, "bush_colors": [Color("a04a28"), Color("c05a30"), Color("703020")],
	},
}

static var _tuft: ArrayMesh
static var _terrain_shader: Shader


static func environment(parent: Node3D, sky_color: Color, fog_color: Color, ambient: Color, sun_color := Color(1.0, 0.96, 0.88)) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = sky_color
	sky_material.sky_horizon_color = fog_color
	sky_material.ground_bottom_color = fog_color.darkened(0.2)
	sky_material.ground_horizon_color = fog_color
	sky_material.sun_angle_max = 3.5
	sky_material.sky_curve = 0.34
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# A cool fill preserves detail in shadow; warm direct light gives the
	# characters and soft foliage distinct, readable planes in Compatibility.
	env.ambient_light_color = ambient.lerp(Color("b6c8df"), 0.30)
	env.ambient_light_energy = 0.37
	env.fog_enabled = true
	# Blue-grey distance is an atmospheric layer, rather than a white veil over
	# the foreground. It separates the cool hills from warm meadow highlights.
	env.fog_light_color = fog_color.lerp(sky_color, 0.6).lerp(Color("779ba6"), 0.12)
	env.fog_density = 0.0023
	env.fog_sky_affect = 0.28
	env.glow_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = sun_color
	sun.light_energy = 0.44
	GameSettings.load_settings()
	sun.shadow_enabled = GameSettings.shadow_distance() > 0.0
	sun.directional_shadow_max_distance = maxf(GameSettings.shadow_distance(), 1.0)
	sun.add_to_group("sun")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if GameSettings.quality >= 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.5
	sun.shadow_opacity = 0.68
	sun.shadow_blur = 1.5
	parent.add_child(sun)


## Hand-painted terrain treatment over a genuinely flat physics floor.
## The mesh holds semantic masks; metre-scale brush detail is shaded per pixel.
static func ground(parent: Node3D, half_size: float, color_a: Color, color_b: Color, seed_value := 3,
		path_color := Color("d8c38a"), paths: Array[PackedVector2Array] = [], path_width := 3.0,
		clearings: Array[Vector3] = [], theme: StringName = &"meadow") -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	# The former 4.6 m grid could not resolve a 2.2 m trail. A finer static
	# ground mesh gives soft paths without textures, decals or extra draw calls.
	var cells := 104
	var step := half_size * 2.0 / cells
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for ix in cells:
		for iz in cells:
			var corners := [Vector2(ix, iz), Vector2(ix + 1, iz), Vector2(ix, iz + 1), Vector2(ix + 1, iz), Vector2(ix + 1, iz + 1), Vector2(ix, iz + 1)]
			for c in corners:
				var x: float = -half_size + c.x * step
				var z: float = -half_size + c.y * step
				var clearing_mask := 0.0
				for clearing in clearings:
					var cd := Vector2(x - clearing.x, z - clearing.y).length()
					var edge := clearing.z + noise.get_noise_2d(x * 2.0, z * 2.0) * 1.2
					var blend := 1.0 - smoothstep(edge * 0.56, edge, cd)
					clearing_mask = maxf(clearing_mask, blend)
				var d := _path_distance(Vector2(x, z), paths)
				st.set_uv(Vector2(x, z))
				st.set_uv2(Vector2(d, clearing_mask))
				st.add_vertex(Vector3(x, 0, z))
	# Adjacent cells carry identical corner attributes. Share those vertices
	# without changing any triangles, terrain masks or the painted appearance.
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	# A perfectly flat floor receives shadows but never needs to cast them.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	if _terrain_shader == null:
		_terrain_shader = load("res://shaders/terrain_art.gdshader")
	mat.shader = _terrain_shader
	var shadow_tone := color_a.darkened(0.09)
	var sun_tone := color_b.darkened(0.025)
	if theme == &"meadow":
		shadow_tone = color_a.lerp(Color("567944"), 0.58)
		sun_tone = color_b.lerp(Color("90a85f"), 0.45)
	elif theme == &"village":
		shadow_tone = color_a.lerp(Color("5c794d"), 0.30)
	mat.set_shader_parameter("ground_shadow", shadow_tone)
	mat.set_shader_parameter("ground_sun", sun_tone)
	mat.set_shader_parameter("soil_color", path_color.darkened(0.075))
	mat.set_shader_parameter("path_width", maxf(path_width, 0.1))
	mat.set_shader_parameter("seed_offset", float(seed_value % 997) * 13.7)
	var kinds := {&"desert": 1, &"snow": 2, &"volcano": 3, &"swamp": 4,
		&"graveyard": 5, &"storm": 5, &"void": 6, &"abyss": 6, &"digital": 6}
	mat.set_shader_parameter("surface_kind", int(kinds.get(theme, 0)))
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	parent.add_child(body)


static func _path_distance(p: Vector2, paths: Array[PackedVector2Array]) -> float:
	var best := 9999.0
	for path in paths:
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


## clear: Array of Vector3(x, z, radius) areas to keep free of scenery.
static func populate(parent: Node3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float,
		clear: Array[Vector3], tree_density := 1.0, with_colliders := true) -> void:
	var occupied: Array[Vector3] = clear.duplicate()
	var body := StaticBody3D.new()
	body.name = "Colliders"
	body.collision_layer = 1
	parent.add_child(body)
	# One field is shared by every layer. Trees, shrubs and undergrowth occupy
	# related pockets instead of each layer being scattered independently.
	var habitat := FastNoiseLite.new()
	habitat.seed = int(rng.seed % 2147483647)
	habitat.frequency = 0.072
	habitat.fractal_octaves = 2
	_trees(parent, body, theme, rng, play_radius, occupied, tree_density, with_colliders, habitat)
	_bushes(parent, theme, rng, play_radius, occupied, habitat)
	_rocks(parent, body, theme, rng, play_radius, occupied, with_colliders, habitat)
	_grass(parent, theme, rng, play_radius, occupied, habitat)


static func _free(p: Vector2, radius: float, occupied: Array[Vector3]) -> bool:
	for o in occupied:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + radius:
			return false
	return true


static func _pick(options: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for o in options:
		total += float(o[1])
	var roll := rng.randf() * total
	for o in options:
		roll -= float(o[1])
		if roll <= 0.0:
			return o[0]
	return options[0][0]


static func _trees(parent: Node3D, body: StaticBody3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float,
		occupied: Array[Vector3], density: float, with_colliders: bool, habitat: FastNoiseLite) -> void:
	var groups: Dictionary = {}
	var colors: Dictionary = {}
	var step := 4.6
	var x := -play_radius - 26.0
	while x <= play_radius + 26.0:
		var z := -play_radius - 26.0
		while z <= play_radius + 26.0:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), z + rng.randf_range(-2.0, 2.0))
			z += step
			var r := p.length()
			# Dense forest outside the play area, scattered groves inside it.
			var pocket := clampf(habitat.get_noise_2dv(p) * 1.4 + 0.5, 0.0, 1.0)
			var edge := smoothstep(play_radius * 0.62, play_radius, r)
			var chance := (0.35 + pocket * 0.55) if r > play_radius else (0.01 + edge * 0.13) * (0.35 + pocket * 1.3)
			chance *= density * GameSettings.density_scale()
			if rng.randf() > chance or not _free(p, 1.4, occupied):
				continue
			var s := rng.randf_range(0.78, 1.32)
			if r > play_radius + 8.0:
				s *= rng.randf_range(1.05, 1.35)
			var model: String
			var set: Dictionary = THEME_SETS.get(theme, {})
			if r > play_radius + 3.0:
				var wall: Array = set.get("wall", WALL_TREES)
				model = wall[rng.randi() % wall.size()]
			elif set.has("trees"):
				model = _pick(set.trees, rng)
			else:
				model = PINES[rng.randi() % PINES.size()] if rng.randf() < 0.4 else _pick(BROADLEAFS, rng)
			if not groups.has(model):
				groups[model] = []
				colors[model] = []
			groups[model].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s * 1.15), Vector3(p.x, -0.05, p.y)))
			colors[model].append(Color("e1eacb").lerp(Color("f4efdc"), pocket))
			if with_colliders and r < play_radius + 4.0:
				var shape := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 0.5 * s
				cyl.height = 3.0
				shape.shape = cyl
				shape.position = Vector3(p.x, 1.5, p.y)
				body.add_child(shape)
			occupied.append(Vector3(p.x, p.y, 1.4 * s))
		x += step
	for model in groups:
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[model])
		var tints: Array[Color] = []
		tints.assign(colors[model])
		NatureKit.place(parent, "Trees_" + model, model, theme, transforms, tints, true, 80.0)


static func _bushes(parent: Node3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float, occupied: Array[Vector3], habitat: FastNoiseLite) -> void:
	var groups: Dictionary = {}
	var colors: Dictionary = {}
	var set: Dictionary = THEME_SETS.get(theme, {})
	var palette: Array = set.get("bush_colors", [Color("dfa7bb"), Color("eed8a0"), Color("eef0df"), Color("b7abd5"), Color("dfa38d")])
	var bush_total: int = int(float(set.get("bushes", 120)) * GameSettings.density_scale())
	var placed := 0
	var attempts := 0
	while placed < bush_total and attempts < bush_total * 8:
		attempts += 1
		var p := Vector2(rng.randf_range(-play_radius, play_radius), rng.randf_range(-play_radius, play_radius))
		if p.length() > play_radius or not _free(p, 0.9, occupied):
			continue
		var pocket := habitat.get_noise_2dv(p)
		if rng.randf() > smoothstep(-0.42, 0.4, pocket):
			continue
		var model: String = BUSHES[rng.randi() % BUSHES.size()]
		var s := rng.randf_range(0.65, 1.35)
		if not groups.has(model):
			groups[model] = []
			colors[model] = []
		groups[model].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0.08, p.y)))
		var patch_color := clampi(int((pocket + 0.5) * palette.size()), 0, palette.size() - 1)
		colors[model].append(palette[patch_color])
		occupied.append(Vector3(p.x, p.y, 0.7 * s))
		placed += 1
	for model in groups:
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[model])
		var tints: Array[Color] = []
		tints.assign(colors[model])
		NatureKit.place(parent, "Bushes_" + model, model, theme, transforms, tints, true, 55.0)


static func _rocks(parent: Node3D, body: StaticBody3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float,
		occupied: Array[Vector3], with_colliders: bool, habitat: FastNoiseLite) -> void:
	var groups: Dictionary = {}
	var colors: Dictionary = {}
	var placed := 0
	var attempts := 0
	var rock_total: int = int(float(THEME_SETS.get(theme, {}).get("rocks", 60)) * GameSettings.density_scale())
	while placed < rock_total and attempts < rock_total * 10:
		attempts += 1
		var p := Vector2(rng.randf_range(-play_radius - 8, play_radius + 8), rng.randf_range(-play_radius - 8, play_radius + 8))
		if not _free(p, 1.0, occupied):
			continue
		var pocket := habitat.get_noise_2dv(p + Vector2(30, -20))
		if rng.randf() > smoothstep(-0.5, 0.32, pocket):
			continue
		var big := rng.randf() < 0.28
		var s := rng.randf_range(1.8, 3.2) if big else rng.randf_range(0.6, 1.2)
		if not _free(p, maxf(1.0, s * 0.6), occupied):
			continue
		var model: String = ROCKS[rng.randi() % ROCKS.size()]
		if not groups.has(model):
			groups[model] = []
			colors[model] = []
		groups[model].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.15, s * 0.85, s)), Vector3(p.x, -s * 0.12, p.y)))
		colors[model].append(Color("c2c6bb").lerp(Color("e4dcc9"), rng.randf()))
		if big and with_colliders and p.length() < play_radius + 4.0:
			var shape := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = s * 0.5
			shape.shape = sphere
			shape.position = Vector3(p.x, s * 0.3, p.y)
			body.add_child(shape)
		occupied.append(Vector3(p.x, p.y, s * 0.6))
		placed += 1
	for model in groups:
		var transforms: Array[Transform3D] = []
		transforms.assign(groups[model])
		var tints: Array[Color] = []
		tints.assign(colors[model])
		NatureKit.place(parent, "Rocks_" + model, model, theme, transforms, tints, true, 75.0)


static func _grass(parent: Node3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float, occupied: Array[Vector3], habitat: FastNoiseLite) -> void:
	var colors: Dictionary = NatureKit.THEMES.get(theme, NatureKit.THEMES[&"meadow"])
	var low: Color = colors["Grass"][0]
	var high: Color = colors["Grass"][1]
	var tuft := _tuft_mesh()
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var covers := {&"desert": 0.24, &"snow": 0.20, &"volcano": 0.14, &"graveyard": 0.50,
		&"swamp": 1.25, &"storm": 0.44, &"sky": 0.72, &"abyss": 0.20, &"void": 0.16, &"village": 0.80}
	var coverage := float(covers.get(theme, 1.0))
	# A small set of natural patches, each containing several short bent tufts.
	# This is still one shared mesh/material, split into the existing cull chunks.
	for i in int(620.0 * GameSettings.density_scale() * coverage):
		var centre := Vector2(rng.randf_range(-play_radius, play_radius), rng.randf_range(-play_radius, play_radius))
		var pocket := habitat.get_noise_2dv(centre)
		if centre.length() > play_radius or rng.randf() > smoothstep(-0.6, 0.3, pocket):
			continue
		var patch_tint := low.lerp(high, clampf(pocket * 0.8 + 0.45, 0.0, 1.0))
		for j in rng.randi_range(4, 9):
			var angle := rng.randf() * TAU
			var distance := sqrt(rng.randf()) * 2.4
			var p := centre + Vector2(cos(angle), sin(angle)) * distance
			if p.length() > play_radius or not _free(p, 0.16, occupied):
				continue
			var s := rng.randf_range(0.55, 1.05)
			transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.82, s)), Vector3(p.x, 0.0, p.y)))
			tints.append(patch_tint.lerp(high, rng.randf() * 0.16))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_sway.gdshader")
	mat.set_shader_parameter("tip_color", high)
	var holder := Node3D.new()
	holder.name = "Grass"
	parent.add_child(holder)
	# Chunk the tufts so only nearby patches are drawn.
	var chunks: Dictionary = {}
	for i in transforms.size():
		var cell := Vector2i(floori(transforms[i].origin.x / NatureKit.CHUNK), floori(transforms[i].origin.z / NatureKit.CHUNK))
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(i)
	for cell in chunks:
		var indices: Array = chunks[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tuft
		mm.instance_count = indices.size()
		for j in indices.size():
			mm.set_instance_transform(j, transforms[indices[j]])
			mm.set_instance_color(j, tints[indices[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 48.0 * GameSettings.view_scale()
		var centre := Vector3((cell.x + 0.5) * NatureKit.CHUNK, 1.0, (cell.y + 0.5) * NatureKit.CHUNK)
		mmi.custom_aabb = NatureKit.chunk_bounds(tuft, transforms, indices, centre)
		holder.add_child(mmi)
	# Flowers
	var groups: Dictionary = {}
	var flower_colors: Dictionary = {}
	var palette := [Color("e9a5b5"), Color("e9cc88"), Color("eee8cd"), Color("b8a6d8"), Color("d99880")]
	var flower_total := int(float(THEME_SETS.get(theme, {}).get("flowers", 210)) * GameSettings.density_scale())
	for i in int(ceil(float(flower_total) / 4.0)):
		var centre := Vector2(rng.randf_range(-play_radius, play_radius), rng.randf_range(-play_radius, play_radius))
		var pocket := habitat.get_noise_2dv(centre)
		if centre.length() > play_radius or pocket < -0.18:
			continue
		var patch_color: Color = palette[rng.randi() % palette.size()]
		var model: String = FLOWER_MODELS[rng.randi() % FLOWER_MODELS.size()]
		for j in 4:
			var p := centre + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4))
			if p.length() > play_radius or not _free(p, 0.2, occupied):
				continue
			var s := rng.randf_range(0.5, 0.85)
			if not groups.has(model):
				groups[model] = []
				flower_colors[model] = []
			groups[model].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
			flower_colors[model].append(patch_color)
	for model in groups:
		var ts: Array[Transform3D] = []
		ts.assign(groups[model])
		var cs: Array[Color] = []
		cs.assign(flower_colors[model])
		NatureKit.place(parent, "Flowers_" + model, model, theme, ts, cs, false, 45.0)


static func _tuft_mesh() -> ArrayMesh:
	if _tuft:
		return _tuft
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 5:
		var ang := i * TAU / 5.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x) * 0.052
		var root := dir * 0.04
		var middle := dir * 0.13 + Vector3(0, 0.26 + i * 0.015, 0)
		var tip := dir * 0.28 + Vector3(0, 0.4 + i * 0.02, 0)
		var vertices := [root - side, root + side, middle - side * 0.55,
			root + side, middle + side * 0.55, middle - side * 0.55,
			middle - side * 0.55, middle + side * 0.55, tip]
		for v in vertices:
			st.set_uv(Vector2(0.5, 1.0 - clampf(v.y / maxf(tip.y, 0.01), 0.0, 1.0)))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	_tuft = st.commit()
	return _tuft
