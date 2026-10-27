class_name ShaderBurst
extends RefCounted
## Particle bursts drawn entirely by shaders/vfx_burst.gdshader: one node, one
## draw call and no per-frame CPU simulation, however many cards it shows.
## A phone's web build updates CPUParticles3D on the CPU every frame, which
## is what made busy fights stutter; this keeps the look without that cost.

const SHADER := preload("res://shaders/vfx_burst.gdshader")
const MODES := {"burst": 0, "rise": 1, "fall": 2}
static var _meshes: Dictionary = {}


## [param kind] picks the card texture (VfxArt.texture: star, leaf, petal,
## snow, diamond, heart, flame, spark...). [param push] throws every card
## along one direction (debris after a blow). Returns nothing; frees itself.
static func emit(parent: Node3D, pos: Vector3, color: Color, kind := "star", count := 20, mode := "burst",
		speed := 4.0, radius := 1.0, lifetime := 0.8, size := 0.4, gravity := 3.0, push := Vector3.ZERO) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or not VfxBudget.can_decorate():
		return
	var n := clampi(VfxBudget.count(count, 4), 4, 48)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("tex", VfxArt.texture(kind))
	mat.set_shader_parameter("mode", int(MODES.get(mode, 0)))
	mat.set_shader_parameter("speed", speed)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("size", size)
	mat.set_shader_parameter("gravity", gravity)
	mat.set_shader_parameter("rise", 0.9 if kind in ["leaf", "petal", "heart", "note"] else 0.45)
	mat.set_shader_parameter("push", push)
	var mi := MeshInstance3D.new()
	mi.name = "ShaderBurst"
	mi.mesh = _mesh(n)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := speed * 1.6 + radius + size + 1.0 + push.length() * 1.6
	mi.custom_aabb = AABB(Vector3(-reach, -reach, -reach), Vector3.ONE * reach * 2.0)
	parent.add_child(mi)
	mi.global_position = pos
	VfxBudget.track_decoration(mi)
	var tween := mi.create_tween()
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, lifetime)
	tween.tween_callback(mi.queue_free)


## N camera-facing cards at the origin; each card's four corners share one
## random seed (COLOR). Shared by every burst of that size.
static func _mesh(n: int) -> ArrayMesh:
	if _meshes.has(n):
		return _meshes[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var seed := Color(rng.randf(), rng.randf(), rng.randf(), rng.randf())
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			st.set_color(seed)
			st.set_uv(corner)
			st.add_vertex(Vector3.ZERO)
	var mesh := st.commit()
	_meshes[n] = mesh
	return mesh
