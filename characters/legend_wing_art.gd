class_name LegendWingArt
extends RefCounted
## The look of the Legendary Guild Wings (LegendWings): the week's star wing model
## (assets/models/star_wings, StarWingData.MODEL) with every surface in one shared gold /
## prismatic shader (legend_wing.gdshader; its motion runs on TIME, so a pair adds no
## per-frame work) and a slow drift of gold sparkles behind it. The sparkles follow the
## quality setting and the memory pressure like every decoration (VfxBudget.count) and
## are left out entirely at pressure 2 or on the low quality setting, so the pair still
## reads as legendary on a phone from its shader alone.

const SHADER := preload("res://shaders/legend_wing.gdshader")
const SPARKLE_COLOR := Color(1.0, 0.9, 0.55, 0.9)
const SPARKLES := 14
static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		MaterialKeeper.keep(_material)
	return _material


## The pair as worn: `item` is a LegendWings pair (its "wing" names the model).
static func build(item: Dictionary, light := false) -> Node3D:
	var model := String(item.get("wing", ""))
	if not LegendWings.MODELS.has(model):
		model = LegendWings.MODELS[0]
	var root: Node3D = (load(StarWingData.MODEL % model) as PackedScene).instantiate()
	root.name = "Wings_legend_" + model
	dress(root)
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for clip in ["Idle", "Flap", "Glide"]:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if player.has_animation("Idle"):
			player.play("Idle")
	if sparkles_allowed(light):
		sparkles(root)
	return root


## Every mesh surface in the shared gold shader; no outline (it would swallow the sheen),
## no shadow (a phone's shadow budget is for the body).
static func dress(root: Node3D) -> void:
	var gold := material()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.set_meta("no_outline", true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, gold)


## Sparkles are decoration: never on the low setting or under memory pressure 2
## (VfxBudget-safe), and never for the light dress of a crowd of world players.
static func sparkles_allowed(light := false) -> bool:
	return not light and VfxBudget.quality() > 0 and MemoryGuard.pressure < 2


## A slow drift of gold motes behind the wings.
static func sparkles(root: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "LegendSparkles"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	var mat := StandardMaterial3D.new()
	MaterialKeeper.keep(mat)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	mat.albedo_color = SPARKLE_COLOR
	quad.material = mat
	p.mesh = quad
	p.amount = VfxBudget.count(SPARKLES)
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.2
	p.gravity = Vector3.ZERO
	p.local_coords = false
	p.color_ramp = VfxKit._fade_ramp()
	p.position = Vector3(0, 0.3, -0.35)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	return p
