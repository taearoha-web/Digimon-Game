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
		"trees": [["NormalTree_3", 3.0], ["DeadTree_9", 3.0], ["DeadTree_5", 2.0], ["MapleTree_4", 1.0]],
		"wall": ["NormalTree_3", "DeadTree_9", "MapleTree_4", "DeadTree_5"],
		"bushes": 70, "flowers": 10, "rocks": 36, "bush_colors": [Color("5a8a3a"), Color("7a9a48"), Color("4a6a30")],
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

## Per-theme air: fog density and how far the fog colour leans toward the sun
## (warm, 1) or the sky (cool, 0). Bright open zones get thin, warm haze; dark
## zones a thicker cool veil that separates the ridges from the field.
const ATMOSPHERE := {
	&"meadow": [0.0019, 0.35], &"digital": [0.0030, 0.0], &"desert": [0.0014, 0.6], &"snow": [0.0016, 0.0],
	&"volcano": [0.0030, 0.7], &"graveyard": [0.0032, 0.0], &"swamp": [0.0034, 0.2], &"storm": [0.0028, 0.0],
	&"sky": [0.0013, 0.5], &"abyss": [0.0030, 0.6], &"void": [0.0026, 0.0], &"village": [0.0017, 0.4],
}
## The third ground colour per theme: [colour, amount, glow] (see terrain_art.gdshader).
const ACCENTS := {
	&"meadow": [Color("9fb860"), 0.5, 0.0], &"village": [Color("a3bf7a"), 0.4, 0.0], &"digital": [Color("7a6f9c"), 0.45, 0.0],
	&"desert": [Color("c49a6a"), 0.35, 0.0], &"snow": [Color("b8cfea"), 0.5, 0.3], &"volcano": [Color("ff6a1e"), 0.12, 1.0],
	&"graveyard": [Color("4e5566"), 0.4, 0.0], &"swamp": [Color("2f4a46"), 0.6, 0.0], &"storm": [Color("4a5563"), 0.4, 0.0],
	&"sky": [Color("f2d98a"), 0.4, 0.0], &"abyss": [Color("2e1a2c"), 0.55, 0.0], &"void": [Color("8a5cff"), 0.35, 1.0],
}
const MOONS := {&"abyss": Color("ff7a66"), &"graveyard": Color("f6f0dc"), &"void": Color("c8b8ff"), &"digital": Color("ece2ff")}

static var _tuft: ArrayMesh
static var _terrain_shader: Shader
static var _glow_mat: StandardMaterial3D
static var _prop_meshes: Dictionary = {}


## Sky, fog, ambient and the sun. `look` (from ZoneData) may carry "palette"
## [zenith, mid, horizon], "sun_size" (0 hides the sun disc), "moon", "theme"
## (for ATMOSPHERE) and "glow" (default on at quality 2).
static func environment(parent: Node3D, sky_color: Color, fog_color: Color, ambient: Color, sun_color := Color(1.0, 0.96, 0.88),
		look := {}) -> WorldEnvironment:
	var palette: Array = look.get("palette", [sky_color, sky_color.lerp(fog_color, 0.5), fog_color])
	var sun_size := float(look.get("sun_size", 1.0))
	var theme := StringName(look.get("theme", &""))
	var air: Array = ATMOSPHERE.get(theme, [0.0023, 0.3])
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette[0]
	sky_material.sky_horizon_color = palette[2]
	sky_material.ground_bottom_color = (palette[2] as Color).darkened(0.25)
	sky_material.ground_horizon_color = palette[2]
	sky_material.sun_angle_max = 2.0 + 4.0 * sun_size if sun_size > 0.0 else 0.0
	sky_material.sun_curve = 0.3
	sky_material.sky_curve = 0.24
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# A cool fill preserves detail in shadow; warm direct light gives the
	# characters and soft foliage distinct, readable planes in Compatibility.
	env.ambient_light_color = ambient.lerp(Color("b6c8df"), 0.38)
	env.ambient_light_energy = 0.33
	env.fog_enabled = true
	# The distance veil is graded per zone: warm zones fog toward the sun, cool
	# zones toward the mid sky, so hills separate from the field in both.
	var warm := float(air[1])
	env.fog_light_color = fog_color.lerp(palette[1], 0.45).lerp(sun_color, warm * 0.35).lerp(Color("779ba6"), (1.0 - warm) * 0.12)
	env.fog_density = float(air[0])
	env.fog_sky_affect = 0.28 + (1.0 - warm) * 0.14
	GameSettings.load_settings()
	# Soft-light glow on medium and high quality: skill cores, lanterns, lava,
	# crystals and portals bloom while skin and cloth stay under the threshold.
	# Medium keeps one blur level and a gentler intensity for phones.
	# Phones and the web build keep glow for high quality only: its extra render
	# targets and passes cost memory and frame time where both are scarce.
	env.glow_enabled = MemoryGuard.glow_allowed() and bool(look.get("glow", true))
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.96
	env.glow_intensity = 0.55 if GameSettings.quality >= 2 else 0.42
	env.glow_strength = 0.85
	env.glow_bloom = 0.0
	env.set("glow_levels/5", GameSettings.quality >= 2)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group("world_env")
	world_env.set_meta("glow_look", bool(look.get("glow", true)))
	parent.add_child(world_env)
	MemoryGuard.apply_render(null)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = sun_color
	sun.light_energy = 0.6
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
	return world_env


## The sky's furniture: a slowly turning ring of soft cloud puffs, the sun (or
## the moon and stars) and a haze band at the ridge base. Three draw calls,
## no particles. `radius` is the play radius; everything stays within 150 m.
static func sky_dressing(parent: Node3D, theme: StringName, look: Dictionary, radius: float, seed_value := 3) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 131 + 7
	var palette: Array = look.get("palette", [Color("5f9bd9"), Color("a9cfe9"), Color("eef0d8")])
	var sun_size := float(look.get("sun_size", 1.0))
	var night := bool(look.get("moon", false)) or sun_size <= 0.0
	var holder := Node3D.new()
	holder.name = "SkyDressing"
	parent.add_child(holder)
	# Clouds: each cloud is 3-5 overlapping billboard puffs in one MultiMesh.
	var cloud_count: int = [7, 10, 14][clampi(GameSettings.quality, 0, 2)]
	var puffs: Array[Transform3D] = []
	var puff_colors: Array[Color] = []
	# Two tones per cloud: a bluish underside and white tops, so the puffs read
	# against a pale horizon as well as a deep sky.
	var tint: Color = look.get("cloud_color", (palette[1] as Color).lightened(0.1 if night else 0.3))
	var top_tint := tint.lightened(0.35 if night else 0.75)
	var range_r: Vector2 = look.get("cloud_range", Vector2(radius + 12.0, radius + 42.0))
	var range_y: Vector2 = look.get("cloud_height", Vector2(30.0, 46.0))
	for i in cloud_count:
		var angle := TAU * (float(i) + rng.randf() * 0.6) / float(cloud_count)
		var r := rng.randf_range(range_r.x, range_r.y)
		var centre := Vector3(cos(angle) * r, rng.randf_range(range_y.x, range_y.y), sin(angle) * r)
		var width := rng.randf_range(14.0, 26.0)
		var alpha := rng.randf_range(0.6, 0.85) * (0.7 if night else 1.0)
		var across := Vector3(cos(angle + PI * 0.5), 0, sin(angle + PI * 0.5))
		for j in rng.randi_range(3, 5):
			var t := float(j) / 4.0 - 0.5
			var w := width * rng.randf_range(0.45, 0.8)
			var puff := centre + across * t * width * 0.9 + Vector3(0, rng.randf_range(-1.5, 2.5) - absf(t) * 3.0, 0)
			puffs.append(Transform3D(Basis.from_scale(Vector3(w, w * rng.randf_range(0.5, 0.7), 1.0)), puff))
			puff_colors.append(Color(tint, alpha * rng.randf_range(0.8, 1.0)))
			puffs.append(Transform3D(Basis.from_scale(Vector3(w * 0.7, w * 0.5, 1.0)), puff + Vector3(0, w * 0.22, 0)))
			puff_colors.append(Color(top_tint, alpha * 0.9))
	var clouds := _billboards(holder, "Clouds", puffs, puff_colors, false)
	var drift := clouds.create_tween().set_loops()
	drift.tween_property(clouds, "rotation:y", TAU, 900.0).from(0.0)
	# Sun or moon, with a halo, and stars at night.
	var dots: Array[Transform3D] = []
	var dot_colors: Array[Color] = []
	var sun_dir := Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(-32.0), 0)).z
	var sun_pos := sun_dir * (radius + 50.0)
	if sun_size > 0.0:
		var warm: Color = look.get("sun_color", Color("fff1c8"))
		dots.append(Transform3D(Basis.from_scale(Vector3.ONE * 7.0 * sun_size), sun_pos))
		dot_colors.append(Color(warm.lightened(0.3), 1.0))
		dots.append(Transform3D(Basis.from_scale(Vector3.ONE * 26.0 * sun_size), sun_pos))
		dot_colors.append(Color(warm, 0.28))
	if night:
		var moon: Color = MOONS.get(theme, Color("f6f0dc"))
		var moon_pos := Vector3(-sun_pos.x * 0.8, sun_pos.y * 0.9, sun_pos.z * 0.8)
		dots.append(Transform3D(Basis.from_scale(Vector3.ONE * 6.5), moon_pos))
		dot_colors.append(Color(moon, 1.0))
		dots.append(Transform3D(Basis.from_scale(Vector3.ONE * 22.0), moon_pos))
		dot_colors.append(Color(moon, 0.22))
		var star_count: int = [24, 44, 70][clampi(GameSettings.quality, 0, 2)]
		for i in star_count:
			var a := rng.randf() * TAU
			var pitch := rng.randf_range(0.3, 1.3)
			var d := radius + rng.randf_range(20.0, 48.0)
			var star := Vector3(cos(a) * cos(pitch), sin(pitch), sin(a) * cos(pitch)) * d
			dots.append(Transform3D(Basis.from_scale(Vector3.ONE * rng.randf_range(0.5, 1.2)), star))
			dot_colors.append(Color(Color("ffffff").lerp(moon, rng.randf() * 0.5), rng.randf_range(0.5, 1.0)))
	if not dots.is_empty():
		_billboards(holder, "SkyDots", dots, dot_colors, true)
	# Haze: a vertical band at the ridge base, horizon colour fading upward.
	var haze := SurfaceTool.new()
	haze.begin(Mesh.PRIMITIVE_TRIANGLES)
	var haze_r := radius + 30.0
	var haze_color: Color = palette[2]
	var segments := 48
	for i in segments:
		for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var a := TAU * float(i + c.x) / segments
			var y := -1.0 if c.y == 0 else 17.0
			haze.set_color(Color(haze_color, 0.72 if c.y == 0 else 0.0))
			haze.add_vertex(Vector3(cos(a) * haze_r, y, sin(a) * haze_r))
	var band := MeshInstance3D.new()
	band.name = "Haze"
	band.mesh = haze.commit()
	var band_mat := StandardMaterial3D.new()
	band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band_mat.vertex_color_use_as_albedo = true
	band_mat.vertex_color_is_srgb = true
	band_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	band_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	band_mat.no_depth_test = false
	band.material_override = band_mat
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(band)
	holder.set_meta("visual_only", true)
	return holder


static func _billboards(parent: Node3D, node_name: String, transforms: Array[Transform3D], colors: Array[Color], additive: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshKit.quad()
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.albedo_texture = VfxKit.soft_dot()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


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
	# Adjacent cells share their corner attributes, so each grid node is
	# evaluated once and the triangles index into it (same triangles, same
	# terrain masks and painted look as the old per-corner build, ~5x cheaper).
	var nodes := cells + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	verts.resize(nodes * nodes)
	normals.resize(nodes * nodes)
	uvs.resize(nodes * nodes)
	uv2s.resize(nodes * nodes)
	for ix in nodes:
		var x: float = -half_size + ix * step
		for iz in nodes:
			var z: float = -half_size + iz * step
			var clearing_mask := 0.0
			for clearing in clearings:
				var cd := Vector2(x - clearing.x, z - clearing.y).length()
				var edge := clearing.z + noise.get_noise_2d(x * 2.0, z * 2.0) * 1.2
				var blend := 1.0 - smoothstep(edge * 0.56, edge, cd)
				clearing_mask = maxf(clearing_mask, blend)
			var k := ix * nodes + iz
			verts[k] = Vector3(x, 0, z)
			normals[k] = Vector3.UP
			uvs[k] = Vector2(x, z)
			uv2s[k] = Vector2(_path_distance(Vector2(x, z), paths), clearing_mask)
	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var w := 0
	for ix in cells:
		for iz in cells:
			var a := ix * nodes + iz
			var b := a + nodes
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = a + 1
			indices[w + 3] = b
			indices[w + 4] = b + 1
			indices[w + 5] = a + 1
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var ground_mesh := ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = ground_mesh
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
	var accent: Array = ACCENTS.get(theme, ACCENTS[&"meadow"])
	mat.set_shader_parameter("accent_color", accent[0])
	mat.set_shader_parameter("accent_amount", accent[1])
	mat.set_shader_parameter("accent_glow", accent[2])
	mat.set_shader_parameter("soil_color", path_color.darkened(0.075))
	mat.set_shader_parameter("path_width", maxf(path_width, 0.1))
	mat.set_shader_parameter("seed_offset", float(seed_value % 997) * 13.7)
	var kinds := {&"desert": 1, &"snow": 2, &"volcano": 3, &"swamp": 4,
		&"graveyard": 5, &"storm": 5, &"abyss": 5, &"void": 6, &"digital": 6}
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
		clear: Array[Vector3], tree_density := 1.0, with_colliders := true, slicer: SceneTree = null) -> void:
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
	# With a `slicer` (the zone's tree) layers build in time-budgeted slices, so a zone change
	# never freezes the page for one long stretch.
	_trees(parent, body, theme, rng, play_radius, occupied, tree_density, with_colliders, habitat)
	await FrameSlicer.pace(slicer)
	_bushes(parent, theme, rng, play_radius, occupied, habitat)
	await FrameSlicer.pace(slicer)
	_rocks(parent, body, theme, rng, play_radius, occupied, with_colliders, habitat)
	await FrameSlicer.pace(slicer)
	theme_props(parent, theme, rng, play_radius, occupied, habitat)
	await FrameSlicer.pace(slicer)
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
	mat.set_shader_parameter("gust", NatureKit.gust_for(theme))
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


## Props that say which land this is, scattered inside the play radius but
## outside every clear circle (camps, trail, portals): no colliders, one
## MultiMesh per prop kind, counts scaled by the density setting.
static func theme_props(parent: Node3D, theme: StringName, rng: RandomNumberGenerator, play_radius: float,
		occupied: Array[Vector3], habitat: FastNoiseLite) -> void:
	var holder := Node3D.new()
	holder.name = "ThemeProps"
	parent.add_child(holder)
	var p: Array = WorldArt.PALETTES.get(theme, WorldArt.PALETTES[&"meadow"])
	match theme:
		&"volcano":
			_scatter(holder, "BasaltColumns", _prop("basalt"), [Color("3a3034"), Color("4a3c40"), Color("2e2628")], rng, play_radius, occupied, habitat, 14, 1.6, 3, Vector3(0.8, 1.6, 0.8), Vector3(1.3, 3.2, 1.3))
			_scatter(holder, "LavaRocks", _prop("lava_rock"), [Color("ff7a2a"), Color("ffb040"), Color("ff5a1a")], rng, play_radius, occupied, habitat, 30, 0.7, 2, Vector3(0.7, 0.4, 0.7), Vector3(1.4, 0.7, 1.4), true)
		&"graveyard":
			_tomb_rows(holder, rng, play_radius, occupied)
		&"abyss":
			_scatter(holder, "BoneSpikes", _prop("spike"), [Color("e8dcc8"), Color("d8c8b0"), Color("f0e8d8")], rng, play_radius, occupied, habitat, 34, 0.8, 3, Vector3(0.4, 2.4, 0.4), Vector3(0.7, 4.6, 0.7))
			_scatter(holder, "RedCrystals", _prop("crystal"), [Color("ff3a4a"), Color("ff6a6a"), Color("d82a48")], rng, play_radius, occupied, habitat, 24, 0.8, 3, Vector3(0.6, 1.2, 0.6), Vector3(1.0, 2.4, 1.0), true)
		&"void":
			var shards := _scatter(holder, "FloatingShards", _prop("shard"), [Color("b08aff"), Color("8a5cff"), Color("d8c0ff")], rng, play_radius, occupied, habitat, 28, 0.9, 1, Vector3(0.45, 1.4, 0.45), Vector3(0.8, 2.6, 0.8), true, Vector2(1.8, 3.6))
			var bob := shards.create_tween().set_loops()
			bob.tween_property(shards, "position:y", 0.5, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(shards, "position:y", -0.3, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_scatter(holder, "RuneCircles", _prop("rune_ring"), [Color("8a5cff"), Color("c080ff")], rng, play_radius, occupied, habitat, 10, 2.4, 1, Vector3(2.0, 1.0, 2.0), Vector3(3.2, 1.0, 3.2), true)
		&"swamp":
			_scatter(holder, "MossMounds", _prop("mound"), [Color("4f7a3a"), Color("5e8a42"), Color("3f6a34")], rng, play_radius, occupied, habitat, 36, 0.9, 2, Vector3(1.0, 0.45, 0.9), Vector3(2.2, 0.8, 1.9))
			_scatter(holder, "Mushrooms", _prop("mushroom"), [Color("c8664a"), Color("e0b050"), Color("8aa0d8"), Color("d8d0b8")], rng, play_radius, occupied, habitat, 30, 0.5, 3, Vector3(0.5, 0.5, 0.5), Vector3(1.1, 1.2, 1.1))
			_scatter(holder, "LilyPools", _prop("pool"), [Color("2f4a46"), Color("35524a")], rng, play_radius, occupied, habitat, 8, 2.8, 1, Vector3(2.2, 1.0, 1.8), Vector3(3.4, 1.0, 2.8))
		&"desert":
			_scatter(holder, "Cacti", _prop("cactus"), [Color("5f9a4a"), Color("6fa852"), Color("4f8a44")], rng, play_radius, occupied, habitat, 26, 0.7, 2, Vector3(0.8, 0.9, 0.8), Vector3(1.3, 1.8, 1.3))
			_scatter(holder, "Bones", _prop("bones"), [Color("efe6d2"), Color("e0d4bc")], rng, play_radius, occupied, habitat, 10, 1.4, 1, Vector3(1.2, 1.0, 1.2), Vector3(2.0, 1.4, 2.0))
		&"snow":
			_scatter(holder, "IceCrystals", _prop("crystal"), [Color("bfe4ff"), Color("dff2ff"), Color("9fd0f0")], rng, play_radius, occupied, habitat, 22, 0.8, 3, Vector3(0.6, 1.0, 0.6), Vector3(1.1, 2.2, 1.1), true)
		&"storm":
			_scatter(holder, "ChargedCrystals", _prop("crystal"), [Color("f4e27a"), Color("fff2a0"), Color("d8c850")], rng, play_radius, occupied, habitat, 16, 0.8, 3, Vector3(0.5, 0.9, 0.5), Vector3(0.9, 1.8, 0.9), true)
		&"sky":
			_scatter(holder, "BrokenColumns", _prop("column"), [p[1], p[0].lightened(0.1), Color("f4ecd8")], rng, play_radius, occupied, habitat, 14, 1.0, 2, Vector3(0.9, 1.2, 0.9), Vector3(1.3, 3.4, 1.3))
		&"digital":
			_scatter(holder, "GlowShrooms", _prop("mushroom"), [Color("6adfd0"), Color("9ad8ff"), Color("c88aff")], rng, play_radius, occupied, habitat, 32, 0.5, 3, Vector3(0.5, 0.5, 0.5), Vector3(1.0, 1.1, 1.0), true)
			_scatter(holder, "DuskCrystals", _prop("crystal"), [Color("b08aff"), Color("8ad0ff")], rng, play_radius, occupied, habitat, 10, 0.9, 2, Vector3(0.7, 1.4, 0.7), Vector3(1.1, 2.6, 1.1), true)
		&"meadow", &"village":
			_scatter(holder, "Stumps", _prop("stump"), [Color("8c6a4c"), Color("7a5a40")], rng, play_radius, occupied, habitat, 12, 0.8, 1, Vector3(0.9, 0.7, 0.9), Vector3(1.4, 1.2, 1.4))
			_scatter(holder, "Mushrooms", _prop("mushroom"), [Color("e8705a"), Color("f0c060"), Color("f4ecd8")], rng, play_radius, occupied, habitat, 16, 0.4, 3, Vector3(0.35, 0.35, 0.35), Vector3(0.7, 0.8, 0.7))
	if holder.get_child_count() == 0:
		holder.queue_free()


## Places `count` * density clusters of `mesh`; each cluster holds up to
## `per_cluster` instances tinted from `colors`, scaled between `lo` and `hi`.
static func _scatter(parent: Node3D, node_name: String, mesh: Mesh, colors: Array, rng: RandomNumberGenerator, play_radius: float,
		occupied: Array[Vector3], habitat: FastNoiseLite, count: int, footprint: float, per_cluster: int, lo: Vector3, hi: Vector3,
		glow := false, height := Vector2.ZERO) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	var clusters := int(ceil(float(count) * GameSettings.density_scale()))
	var attempts := 0
	while clusters > 0 and attempts < count * 12:
		attempts += 1
		var centre := Vector2(rng.randf_range(-play_radius, play_radius), rng.randf_range(-play_radius, play_radius))
		if centre.length() > play_radius - 2.0 or not _free(centre, footprint, occupied):
			continue
		if rng.randf() > smoothstep(-0.55, 0.35, habitat.get_noise_2dv(centre + Vector2(-40, 25))):
			continue
		clusters -= 1
		var base_tint: Color = colors[rng.randi() % colors.size()]
		for j in rng.randi_range(1, per_cluster):
			var p := centre if j == 0 else centre + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * footprint * 1.4
			if p.length() > play_radius - 1.0 or (j > 0 and not _free(p, footprint * 0.5, occupied)):
				continue
			var s := Vector3(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y), rng.randf_range(lo.z, hi.z))
			var tilt := Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)) if height != Vector2.ZERO else Vector3(0, rng.randf() * TAU, 0)
			var y := rng.randf_range(height.x, height.y) if height != Vector2.ZERO else 0.0
			transforms.append(Transform3D(Basis.from_euler(tilt).scaled(s), Vector3(p.x, y, p.y)))
			tints.append(base_tint.lerp(colors[rng.randi() % colors.size()], rng.randf() * 0.5))
			occupied.append(Vector3(p.x, p.y, footprint * 0.6))
	return _prop_batch(parent, node_name, mesh, transforms, tints, glow)


static func _prop_batch(parent: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], tints: Array[Color], glow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, tints[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = glow_material() if glow else RegionArt._colored_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 70.0 * GameSettings.view_scale()
	parent.add_child(mmi)
	return mmi


## Rows of tombstones with short fence runs between them (graveyard field).
static func _tomb_rows(parent: Node3D, rng: RandomNumberGenerator, play_radius: float, occupied: Array[Vector3]) -> void:
	var tombs: Array[Transform3D] = []
	var tomb_tints: Array[Color] = []
	var fences: Array[Transform3D] = []
	var fence_tints: Array[Color] = []
	var rows := int(ceil(9.0 * GameSettings.density_scale()))
	var attempts := 0
	while rows > 0 and attempts < 80:
		attempts += 1
		var start := Vector2(rng.randf_range(-play_radius, play_radius), rng.randf_range(-play_radius, play_radius))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var length := rng.randi_range(3, 5)
		var fits := true
		for i in length:
			var p := start + dir * i * 1.6
			if p.length() > play_radius - 2.0 or not _free(p, 0.9, occupied):
				fits = false
		if not fits:
			continue
		rows -= 1
		var yaw := -dir.angle() + PI * 0.5
		for i in length:
			var p := start + dir * i * 1.6
			var s := rng.randf_range(0.7, 1.1)
			tombs.append(Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.08, 0.08), yaw + rng.randf_range(-0.2, 0.2), rng.randf_range(-0.1, 0.1))).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
			tomb_tints.append(Color("8c8ea0").lerp(Color("5c6072"), rng.randf()))
			occupied.append(Vector3(p.x, p.y, 0.6))
		var side := dir.orthogonal() * 1.3
		var mid := start + dir * (length - 1) * 0.8
		var f := mid + side
		fences.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(length * 1.6, 1.0, 1.0)), Vector3(f.x, 0, f.y)))
		fence_tints.append(Color("4a4650"))
	_prop_batch(parent, "Tombstones", _prop("tomb"), tombs, tomb_tints, false)
	_prop_batch(parent, "IronFences", _prop("fence"), fences, fence_tints, false)


## Unshaded-looking emissive vertex colours: the instance tint is the glow.
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.vertex_color_use_as_albedo = true
		_glow_mat.vertex_color_is_srgb = true
		_glow_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_glow_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_glow_mat.roughness = 1.0
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color.WHITE
		_glow_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		_glow_mat.emission_energy_multiplier = 1.3
	return _glow_mat


## Small prop meshes built from primitives (JapanKit.Batch), unit sized so the
## instance scale sets their height; colours are pale tones multiplied by the
## instance tint.
static func _prop(kind: String) -> ArrayMesh:
	if _prop_meshes.has(kind):
		return _prop_meshes[kind]
	var b := JapanKit.Batch.new()
	var pale := Color("ffffff")
	var shade := Color("c0c0c0")
	match kind:
		"basalt":
			b.cyl(Vector3(0, 0.5, 0), 0.5, 1.0, pale, Vector3.ZERO, 6)
			b.cyl(Vector3(0, 1.0, 0), 0.52, 0.04, shade, Vector3.ZERO, 6)
		"lava_rock":
			b.ball(Vector3(0, 0.3, 0), Vector3(1.0, 0.8, 1.0), pale)
		"spike":
			b.cone(Vector3(0, 0.5, 0), 0.5, 1.0, pale)
			b.cone(Vector3(0.28, 0.25, 0.1), 0.25, 0.55, shade, Vector3(0, 0, -28))
		"crystal":
			b.cone(Vector3(0, 0.62, 0), 0.42, 0.76, pale)
			b.cone(Vector3(0, 0.12, 0), 0.42, 0.24, pale, Vector3(180, 0, 0))
			b.cone(Vector3(0.36, 0.35, 0.1), 0.22, 0.5, shade, Vector3(0, 0, -32))
		"shard":
			b.cone(Vector3(0, 0.75, 0), 0.5, 0.5, pale)
			b.cone(Vector3(0, 0.25, 0), 0.5, 0.5, shade, Vector3(180, 0, 0))
		"rune_ring":
			for i in 16:
				var a := TAU * i / 16.0
				b.box(Vector3(cos(a) * 0.5, 0.025, sin(a) * 0.5), Vector3(0.2, 0.03, 0.06), pale, Vector3(0, -rad_to_deg(a), 0))
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				b.box(Vector3(cos(a) * 0.3, 0.025, sin(a) * 0.3), Vector3(0.08, 0.03, 0.08), shade, Vector3(0, 45, 0))
		"mound":
			b.ball(Vector3(0, 0.0, 0), Vector3(1.0, 1.0, 1.0), pale)
		"mushroom":
			b.cyl(Vector3(0, 0.3, 0), 0.12, 0.6, Color("f0e6d0"), Vector3.ZERO, 6)
			b.ball(Vector3(0, 0.62, 0), Vector3(0.7, 0.42, 0.7), pale)
			for i in 3:
				var a := TAU * i / 3.0
				b.ball(Vector3(cos(a) * 0.2, 0.78, sin(a) * 0.2), Vector3(0.12, 0.05, 0.12), Color("fff6e8"))
		"pool":
			b.cyl(Vector3(0, 0.015, 0), 0.5, 0.03, pale, Vector3.ZERO, 16)
			for i in 4:
				var a := TAU * i / 4.0 + 0.6
				b.cyl(Vector3(cos(a) * 0.28, 0.035, sin(a) * 0.2), 0.08, 0.02, Color("6fa05a"), Vector3.ZERO, 8)
			b.ball(Vector3(0.1, 0.06, -0.08), Vector3(0.08, 0.06, 0.08), Color("f0a0c0"))
		"cactus":
			b.cyl(Vector3(0, 0.5, 0), 0.16, 1.0, pale, Vector3.ZERO, 8)
			b.ball(Vector3(0, 1.0, 0), Vector3(0.32, 0.2, 0.32), pale)
			b.cyl(Vector3(0.32, 0.5, 0), 0.1, 0.3, shade, Vector3(0, 0, 90), 6)
			b.cyl(Vector3(0.44, 0.68, 0), 0.1, 0.4, shade, Vector3.ZERO, 6)
			b.cyl(Vector3(-0.28, 0.38, 0), 0.09, 0.26, shade, Vector3(0, 0, 90), 6)
			b.cyl(Vector3(-0.38, 0.52, 0), 0.09, 0.32, shade, Vector3.ZERO, 6)
		"bones":
			b.cyl(Vector3(0, 0.1, 0), 0.07, 1.0, pale, Vector3(0, 0, 90), 6)
			for x in [-0.5, 0.5]:
				b.ball(Vector3(x, 0.1, 0), Vector3(0.2, 0.2, 0.2), pale)
			b.ball(Vector3(0.1, 0.22, 0.5), Vector3(0.42, 0.4, 0.46), pale)
			for x in [-0.1, 0.1]:
				b.box(Vector3(0.1 + x, 0.24, 0.72), Vector3(0.08, 0.1, 0.04), Color("3a3030"))
			for i in 3:
				b.cyl(Vector3(-0.3 + i * 0.25, 0.3, -0.5), 0.03, 0.5, shade, Vector3(70, 0, 0), 5)
		"column":
			b.cyl(Vector3(0, 0.45, 0), 0.5, 0.9, pale, Vector3.ZERO, 10)
			b.box(Vector3(0, 0.06, 0), Vector3(1.3, 0.12, 1.3), shade)
			b.box(Vector3(0.1, 0.96, 0.05), Vector3(0.7, 0.14, 0.6), shade, Vector3(4, 20, -6))
		"stump":
			b.cyl(Vector3(0, 0.5, 0), 0.5, 1.0, pale, Vector3.ZERO, 8)
			b.cyl(Vector3(0, 1.0, 0), 0.46, 0.03, Color("e8d8b8"), Vector3.ZERO, 8)
			for i in 3:
				var a := TAU * i / 3.0 + 0.4
				b.box(Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5), Vector3(0.5, 0.24, 0.28), shade, Vector3(0, -rad_to_deg(a), 0))
		"tomb":
			b.box(Vector3(0, 0.9, 0), Vector3(1.2, 1.8, 0.4), pale)
			b.cyl(Vector3(0, 1.8, 0), 0.6, 0.4, pale, Vector3(90, 0, 0), 10)
			b.box(Vector3(0, 1.2, -0.22), Vector3(0.08, 0.7, 0.03), shade)
			b.box(Vector3(0, 1.35, -0.22), Vector3(0.45, 0.08, 0.03), shade)
			b.box(Vector3(0, 0.12, 0), Vector3(1.5, 0.24, 0.8), shade)
		"fence":
			# Unit length along x; two posts with pointed heads and two rails.
			for x in [-0.5, 0.0, 0.5]:
				b.box(Vector3(x, 0.55, 0), Vector3(0.025, 1.1, 0.025), pale)
				b.cone(Vector3(x, 1.18, 0), 0.03, 0.16, pale)
			for y in [0.45, 0.95]:
				b.box(Vector3(0, y, 0), Vector3(1.0, 0.03, 0.02), pale)
			for i in 7:
				b.box(Vector3(-0.42 + i * 0.14, 0.6, 0), Vector3(0.012, 0.9, 0.012), shade)
	var mesh := b.mesh()
	_prop_meshes[kind] = mesh
	return mesh


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
