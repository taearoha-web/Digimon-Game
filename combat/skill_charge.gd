class_name SkillCharge
extends Node3D
## A finite charge bound to the actual weapon socket. Cancelling/interrupting
## the animation or deleting its owner also removes the charge, without damage.
## The weapon tip leaves a short ribbon of the skill's colour as it moves and,
## for the last 40% of the wind-up, carries one of the budgeted lights.
const TRAIL_POINTS := 12
const LIGHT_AT := 0.6
var visual_ref: WeakRef
var generation := 0
var elapsed := 0.0
var duration := 0.1
var mat: ShaderMaterial
var seal: MeshInstance3D
var gem: MeshInstance3D
var trail: MeshInstance3D
var trail_mat: ShaderMaterial
var light: OmniLight3D
var primary := Color.WHITE
var _points: PackedVector3Array = []

static func launch(parent: Node3D, visual: HeroVisual, look: Dictionary, seconds: float) -> SkillCharge:
	if not is_instance_valid(visual) or not VfxBudget.can_decorate(2):
		return null
	var charge := SkillCharge.new()
	charge.name = "WeaponCharge"
	charge.visual_ref = weakref(visual)
	charge.generation = visual.skill_generation
	charge.duration = maxf(seconds, 0.025)
	charge.primary = look.primary
	parent.add_child(charge)
	charge.process_priority = 10
	charge.global_position = visual.skill_emission_position()
	charge.mat = SpellSpectacle._material(look, 0.65)
	charge.gem = SpellSpectacle._mesh(charge, SpellSpectacle._crystal_mesh(), charge.mat)
	charge.seal = SpellSpectacle._mesh(charge, SpellSpectacle._halo_mesh(), charge.mat)
	if charge.seal:
		charge.seal.rotation.x = PI * 0.5
	if VfxBudget.can_decorate():
		# One ImmediateMesh rebuilt from the last tip samples: a single draw
		# in world space, so it stays behind the weapon while the body moves.
		charge.trail = MeshInstance3D.new()
		charge.trail.name = "WeaponTrail"
		charge.trail.mesh = ImmediateMesh.new()
		charge.trail_mat = SkillInk.material(SkillInk.RIBBON, look)
		charge.trail_mat.set_shader_parameter("age", 0.3)
		charge.trail.material_override = charge.trail_mat
		charge.trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		charge.trail.top_level = true
		charge.add_child(charge.trail)
		charge.trail.global_transform = Transform3D.IDENTITY
		VfxBudget.track_decoration(charge.trail)
	charge._draw(0.0)
	return charge

func _process(delta: float) -> void:
	var visual := visual_ref.get_ref() as HeroVisual
	if not is_instance_valid(visual) or visual.is_queued_for_deletion() or visual.skill_generation != generation or visual._skill_pose.is_empty():
		queue_free()
		return
	elapsed += delta
	global_position = visual.skill_emission_position()
	_draw(clampf(elapsed / duration, 0.0, 1.0))
	if elapsed >= duration:
		queue_free()

func _draw(t: float) -> void:
	if gem:
		gem.scale = Vector3.ONE * lerpf(0.025, 0.16, t * t)
		gem.rotation.y = t * 2.4
	if seal:
		seal.scale = Vector3.ONE * lerpf(0.55, 0.20, smoothstep(0.0, 1.0, t))
	mat.set_shader_parameter("fade", smoothstep(0.0, 0.15, t))
	if trail:
		_sample_trail()
	if t >= LIGHT_AT and light == null and VfxBudget.can_light():
		light = OmniLight3D.new()
		light.light_color = primary
		light.omni_range = 3.4
		light.light_energy = 0.0
		add_child(light)
		VfxBudget.track_light(light)
	if light:
		light.light_energy = 1.1 * smoothstep(LIGHT_AT, 1.0, t)

## Keep the newest tip positions and rebuild the ribbon as two strips: V 0..1
## across the band, U 0 at the oldest sample (eroded away) to 0.95 at the tip.
func _sample_trail() -> void:
	var tip := global_position
	if _points.is_empty() or _points[_points.size() - 1].distance_squared_to(tip) > 0.0004:
		_points.append(tip)
		if _points.size() > TRAIL_POINTS:
			_points.remove_at(0)
	var mesh := trail.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _points.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else tip + Vector3(0, 5, 5)
	var half := 0.028 + 0.05 * clampf(elapsed / duration, 0.0, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var u := 0.95 * float(i) / float(_points.size() - 1)
		var along := (_points[mini(i + 1, _points.size() - 1)] - _points[maxi(i - 1, 0)])
		var side := along.cross(eye - _points[i])
		side = side.normalized() * half * (0.35 + 0.65 * u) if side.length_squared() > 0.000001 else Vector3.RIGHT * half
		mesh.surface_set_uv(Vector2(u, 0.0))
		mesh.surface_add_vertex(_points[i] - side)
		mesh.surface_set_uv(Vector2(u, 1.0))
		mesh.surface_add_vertex(_points[i] + side)
	mesh.surface_end()
