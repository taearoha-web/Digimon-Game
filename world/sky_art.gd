class_name SkyArt
extends RefCounted
## The sky, light and air of every zone, on top of what Scenery.environment builds:
##   - a painted cloud cover on the ProceduralSkyMaterial (one small texture, shared by
##     every zone, so only one sky texture is ever loaded; tinted per zone and, where the
##     zone follows the clock, by DayNight with the hour)
##   - a soft filmic tone curve with a little exposure, so the brightest skill cores and
##     clouds roll off instead of clipping white, and a gentle colour grade per zone
##     (Environment adjustments, only where glow already runs the post pass)
##   - a slightly warmer key light and some soft ambient from the sky itself
##   - cheap atmosphere: additive light shafts (a few camera-facing cards in one
##     MultiMesh) in the divine and star places and under the abyss's water, and drifting
##     cloud shadows (one alpha-blended plane, noise computed in the shader) over the
##     open fields
## The moods (MOODS, by zone id, then theme) only tint and dose these; the zone's own
## palette (ZoneData sky_palette) stays the sky's colours, so DayNight keeps grading it.
##
## Budget: quality 0 (and the safe picture) keeps the plain procedural sky with no cover,
## shafts or cloud shadows; quality 1 adds the cloud cover and the shafts; quality 2 the
## cloud shadows and the colour grade. Memory pressure (MemoryGuard) hides the shafts and
## shadows at level 1 and drops the cloud cover at level 2. No SDFGI, SSAO, SSIL or
## volumetric fog anywhere (the Compatibility renderer has none of them anyway).

const CLOUD_TEXTURE := "res://assets/sky/painted_clouds.png"
const RAYS_SHADER := preload("res://shaders/sky_rays.gdshader")
const SHADOWS_SHADER := preload("res://shaders/cloud_shadows.gdshader")
## The largest sky texture a zone may hold (width x height), for the budget test.
const MAX_SKY_TEXTURE := Vector2i(1024, 512)
const EXTRA_GROUP := &"sky_extra"

## Per zone (or theme) mood. Keys (all optional, DEFAULT fills the rest):
##   clouds    Color: the painted cover's tint, alpha = how much of it shows (0 = none)
##   exposure  tone curve exposure (filmic, white point WHITE)
##   grade     Vector3(brightness, contrast, saturation) at quality 2
##   warm      0..1: how far the key light turns golden
##   sky_light 0..1: how much of the ambient light comes from the sky's own colours
##   rays      Color: light shafts' tint, alpha = strength (0 = none)
##   ray_count shafts at quality 2 (quality 1 draws half)
##   shadows   0..1: drifting cloud shadows' depth (0 = none)
const DEFAULT := {"clouds": Color(1.0, 1.0, 1.0, 0.8), "exposure": 1.0, "grade": Vector3(1.0, 1.07, 1.12), "warm": 0.35,
	"sky_light": 0.2, "rays": Color(0, 0, 0, 0), "ray_count": 6, "shadows": 0.0}
const WHITE := 4.0
const MOODS := {
	# The village and the green fields: bright cumulus, golden key, drifting shade.
	&"town": {"clouds": Color(1.0, 0.98, 0.95, 0.85), "warm": 0.5, "shadows": 0.16, "grade": Vector3(1.0, 1.08, 1.16)},
	&"meadow": {"clouds": Color(1.0, 1.0, 1.0, 0.9), "warm": 0.45, "shadows": 0.18, "grade": Vector3(1.0, 1.12, 1.25)},
	&"arena": {"clouds": Color(1.0, 0.98, 0.94, 0.85), "warm": 0.45, "shadows": 0.14},
	&"guildwar": {"clouds": Color(1.0, 1.0, 1.0, 0.9), "warm": 0.45, "shadows": 0.16, "grade": Vector3(1.0, 1.1, 1.2)},
	&"pvp": {"clouds": Color(1.0, 0.86, 0.8, 0.7), "warm": 0.5, "grade": Vector3(1.0, 1.06, 1.1)},
	&"digital": {"clouds": Color(0.62, 0.55, 0.85, 0.35), "warm": 0.0, "sky_light": 0.4, "grade": Vector3(1.0, 1.05, 1.06)},
	&"desert": {"clouds": Color(1.0, 0.93, 0.82, 0.5), "warm": 0.5, "shadows": 0.14, "exposure": 0.98, "grade": Vector3(1.0, 1.06, 1.06)},
	&"snow": {"clouds": Color(0.95, 0.98, 1.0, 0.8), "warm": 0.15, "exposure": 0.96, "grade": Vector3(1.0, 1.05, 1.06)},
	&"volcano": {"clouds": Color(0.55, 0.3, 0.26, 0.6), "warm": 0.2, "grade": Vector3(1.0, 1.08, 1.08)},
	&"graveyard": {"clouds": Color(0.42, 0.42, 0.6, 0.35), "warm": 0.0, "sky_light": 0.4},
	&"swamp": {"clouds": Color(0.7, 0.8, 0.66, 0.55), "warm": 0.1, "shadows": 0.12},
	&"storm": {"clouds": Color(0.55, 0.6, 0.72, 1.0), "warm": 0.0, "shadows": 0.22, "grade": Vector3(1.0, 1.08, 1.0)},
	&"sky": {"clouds": Color(1.0, 0.95, 0.82, 0.9), "warm": 0.5, "rays": Color(1.0, 0.88, 0.62, 0.22), "ray_count": 5},
	&"abyss": {"clouds": Color(0.6, 0.18, 0.14, 0.4), "warm": 0.1, "grade": Vector3(1.0, 1.08, 1.06)},
	&"void": {"clouds": Color(0.5, 0.38, 0.85, 0.35), "warm": 0.0, "sky_light": 0.4},
	&"tower": {"clouds": Color(0.5, 0.38, 0.85, 0.3), "warm": 0.0, "sky_light": 0.4},
	&"raid": {"clouds": Color(0.55, 0.12, 0.16, 0.35), "warm": 0.0, "grade": Vector3(1.0, 1.08, 1.04)},
	# The star regions: dawn gold, crystal blue, the citadel's sunlit clouds, the eclipse.
	&"dawn_forest": {"clouds": Color(1.0, 0.9, 0.82, 0.85), "warm": 0.55, "rays": Color(1.0, 0.86, 0.6, 0.2), "ray_count": 5, "shadows": 0.14},
	&"crystal_valley": {"clouds": Color(0.9, 0.96, 1.0, 0.8), "warm": 0.2, "rays": Color(0.7, 0.9, 1.0, 0.16), "ray_count": 4, "shadows": 0.12},
	&"sky_citadel": {"clouds": Color(1.0, 0.97, 0.9, 0.95), "warm": 0.45, "rays": Color(1.0, 0.9, 0.68, 0.22), "ray_count": 6},
	&"eclipse_realm": {"clouds": Color(0.72, 0.56, 0.9, 0.45), "warm": 0.0, "rays": Color(0.95, 0.7, 1.0, 0.16), "ray_count": 4, "sky_light": 0.4},
	# The lotus sanctum: a rose-gold heaven with shafts falling on the temple.
	&"lotus_sanctum": {"clouds": Color(1.0, 0.86, 0.9, 0.85), "warm": 0.55, "rays": Color(1.0, 0.85, 0.66, 0.4), "ray_count": 7,
		"exposure": 1.02, "grade": Vector3(1.0, 1.06, 1.12)},
	# The drowned abyss: no clouds, the surface's light falling as teal shafts.
	&"drowned_abyss": {"clouds": Color(0.4, 0.85, 0.9, 0.25), "warm": 0.0, "rays": Color(0.45, 0.95, 1.0, 0.36), "ray_count": 7,
		"sky_light": 0.45, "grade": Vector3(1.0, 1.06, 1.08)},
}


## The mood of a zone (its own entry, else its theme's, over DEFAULT).
static func mood(zone_id: StringName, theme := &"") -> Dictionary:
	var out := DEFAULT.duplicate()
	out.merge(MOODS.get(zone_id, MOODS.get(theme, {})), true)
	return out


## Whether this device and setting may draw the extras (cover, shafts, shadows).
static func extras_level() -> int:
	if GameSettings.safe_picture:
		return 0
	return clampi(GameSettings.quality, 0, 2)


## Dresses a built zone's WorldEnvironment and sun (direct children of `zone`) for its
## mood, and adds the atmosphere. Call once, after the zone is built and before DayNight
## captures its designed look. `radius` is the play radius.
static func dress(zone: Node3D, zone_id: StringName, theme: StringName, radius: float) -> void:
	var world_env: WorldEnvironment = null
	var sun: DirectionalLight3D = null
	for child in zone.get_children():
		if child is WorldEnvironment and world_env == null:
			world_env = child
		elif child is DirectionalLight3D and child.is_in_group("sun") and sun == null:
			sun = child
	if world_env == null or world_env.environment == null:
		return
	var m := mood(zone_id, theme)
	dress_environment(world_env, m)
	if sun:
		var warm := float(m.warm)
		sun.light_color = sun.light_color.lerp(Color("ffd49c"), warm * 0.45)
	var level := extras_level()
	if level >= 1:
		var rays: Color = m.rays
		if rays.a > 0.0:
			_rays(zone, rays, int(m.ray_count) if level >= 2 else maxi(2, int(m.ray_count) / 2), radius, zone_id)
	if level >= 2 and float(m.shadows) > 0.0:
		_cloud_shadows(zone, float(m.shadows), radius)
	apply_pressure(zone.get_tree() if zone.is_inside_tree() else null)


## The tone curve, grade, sky light and painted cloud cover of one environment.
static func dress_environment(world_env: WorldEnvironment, m: Dictionary) -> void:
	var env := world_env.environment
	var level := extras_level()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = WHITE
	env.tonemap_exposure = float(m.exposure)
	var grade: Vector3 = m.grade
	env.adjustment_brightness = grade.x
	env.adjustment_contrast = grade.y
	env.adjustment_saturation = grade.z
	world_env.set_meta("grade", level >= 2)
	env.adjustment_enabled = level >= 2 and MemoryGuard.glow_allowed()
	# Expensive passes stay off everywhere (the Compatibility renderer lacks them; a
	# Forward+ desktop run must not switch them on by default either).
	env.sdfgi_enabled = false
	env.ssil_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.volumetric_fog_enabled = false
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
	if sky_mat == null:
		return
	sky_mat.sky_curve = 0.18
	# A little of the sky's own gradient in the ambient light: tops lit by the zenith,
	# undersides by the horizon (the designed ambient colour still carries most of it).
	var sky_light := float(m.sky_light)
	if sky_light > 0.0:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = sky_light
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64
	var clouds: Color = m.clouds
	if level >= 1 and clouds.a > 0.0:
		var tex := load(CLOUD_TEXTURE) as Texture2D
		if tex:
			sky_mat.sky_cover = tex
			sky_mat.sky_cover_modulate = clouds
	world_env.set_meta("sky_cover", sky_mat.sky_cover)


## Memory pressure: shafts and cloud shadows hide at level 1, the cloud cover goes at
## level 2 (and comes back when the pressure drops). Called by MemoryGuard.apply_render.
static func apply_pressure(tree: SceneTree) -> void:
	if tree == null:
		return
	var p := MemoryGuard.pressure
	for node in tree.get_nodes_in_group(EXTRA_GROUP):
		(node as Node3D).visible = p == 0
	for node in tree.get_nodes_in_group("world_env"):
		var env: Environment = (node as WorldEnvironment).environment if node is WorldEnvironment else null
		if env == null:
			continue
		env.adjustment_enabled = bool(node.get_meta("grade", false)) and MemoryGuard.glow_allowed()
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial if env.sky else null
		if sky_mat == null or not node.has_meta("sky_cover"):
			continue
		var cover: Texture2D = node.get_meta("sky_cover")
		var want: Texture2D = cover if p < 2 else null
		if sky_mat.sky_cover != want:
			sky_mat.sky_cover = want


## Light shafts: tall additive cards that turn about their slanted axis to face the
## camera (sky_rays.gdshader), around the play area and leaning with the sun.
static func _rays(zone: Node3D, tint: Color, count: int, radius: float, zone_id: StringName) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone_id)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshKit.quad()
	mm.instance_count = count
	var reach := clampf(radius * 0.75, 18.0, 60.0)
	for i in count:
		var a := TAU * (float(i) + rng.randf_range(0.1, 0.9)) / float(count)
		var r := rng.randf_range(reach * 0.35, reach)
		var width := rng.randf_range(5.0, 10.0)
		var length := rng.randf_range(30.0, 44.0)
		var centre := Vector3(cos(a) * r, length * 0.42, sin(a) * r)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(width, length, 1.0)), centre))
		mm.set_instance_color(i, Color(tint, tint.a * rng.randf_range(0.7, 1.0)))
	var mat := ShaderMaterial.new()
	mat.shader = RAYS_SHADER
	# The shafts lean away from the sun (Scenery's sun at pitch -42, yaw -32).
	mat.set_shader_parameter("axis", Basis.from_euler(Vector3(deg_to_rad(-62.0), deg_to_rad(-32.0), 0)).z * -1.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "LightShafts"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-reach - 20.0, -10.0, -reach - 20.0), Vector3(reach * 2.0 + 40.0, 70.0, reach * 2.0 + 40.0))
	mmi.set_meta("visual_only", true)
	mmi.add_to_group(EXTRA_GROUP)
	zone.add_child(mmi)


## Drifting cloud shadows: one plane just over the ground, its soft blotches of cool shade
## computed in the shader and scrolling with the wind.
static func _cloud_shadows(zone: Node3D, depth: float, radius: float) -> void:
	var plane := PlaneMesh.new()
	var size := clampf(radius * 2.4, 60.0, 260.0)
	plane.size = Vector2(size, size)
	var mat := ShaderMaterial.new()
	mat.shader = SHADOWS_SHADER
	mat.set_shader_parameter("depth", depth)
	var mi := MeshInstance3D.new()
	mi.name = "CloudShadows"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(0, 0.07, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("visual_only", true)
	mi.add_to_group(EXTRA_GROUP)
	zone.add_child(mi)
