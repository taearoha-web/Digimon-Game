class_name SkillCharge
extends Node3D
## A finite charge bound to the actual weapon socket. Cancelling/interrupting
## the animation or deleting its owner also removes the charge, without damage.
var visual_ref: WeakRef
var generation := 0
var elapsed := 0.0
var duration := 0.1
var mat: ShaderMaterial
var seal: MeshInstance3D
var gem: MeshInstance3D

static func launch(parent: Node3D, visual: HeroVisual, look: Dictionary, seconds: float) -> SkillCharge:
	if not is_instance_valid(visual) or not VfxBudget.can_decorate(2):
		return null
	var charge := SkillCharge.new()
	charge.name = "WeaponCharge"
	charge.visual_ref = weakref(visual)
	charge.generation = visual.skill_generation
	charge.duration = maxf(seconds, 0.025)
	parent.add_child(charge)
	charge.process_priority = 10
	charge.global_position = visual.skill_emission_position()
	charge.mat = SpellSpectacle._material(look, 0.65)
	charge.gem = SpellSpectacle._mesh(charge, SpellSpectacle._crystal_mesh(), charge.mat)
	charge.seal = SpellSpectacle._mesh(charge, SpellSpectacle._halo_mesh(), charge.mat)
	if charge.seal:
		charge.seal.rotation.x = PI * 0.5
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
