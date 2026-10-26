class_name SkillInk
extends RefCounted
## Crisp authored marks over solid silhouettes. No bloom, screen texture,
## dynamic light or particle emitter is needed. Meshes are immutable and shared.
const SIGIL := preload("res://shaders/skill_sigil.gdshader")
const RIBBON := preload("res://shaders/skill_ribbon.gdshader")
const MOTIFS := {"vagabond": 0.0, "warrior": 1.0, "archer": 2.0, "mage": 3.0, "priest": 4.0, "summoner": 0.0, "lancer": 1.0, "defender": 1.0, "assassin": 1.0, "darklord": 1.0}
static var _meshes: Dictionary = {}

## A gameplay range cue is essential feedback, never a budgeted decoration.
## The outer ring is fixed at the actual radius throughout the wind-up.
static func telegraph(parent: Node3D, skill: Dictionary, at: Vector3, radius: float, duration: float) -> MeshInstance3D:
	var look := SkillShow.profile_for(skill)
	var mat := material(SIGIL, look)
	mat.set_shader_parameter("motif", MOTIFS.get(String(look.family), 3.0))
	mat.set_shader_parameter("opacity", 0.62)
	var node := MeshInstance3D.new()
	node.name = "EssentialSkillRange"
	node.mesh = quad()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = at + Vector3(0, 0.045, 0)
	node.rotation.x = -PI * 0.5
	node.scale = Vector3.ONE * (radius / 0.83)
	var tw := node.create_tween()
	tw.tween_method(func(age: float): mat.set_shader_parameter("age", age), 0.10, 0.75, maxf(duration, 0.03))
	tw.tween_callback(node.queue_free)
	return node

static func warm_geometry() -> void:
	quad()
	for kind in 3:
		ribbon_mesh(kind)

static func material(shader: Shader, look: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", look.primary)
	mat.set_shader_parameter("core", look.accent)
	mat.set_shader_parameter("shade", look.shade)
	return mat

static func mark(parent: Node3D, look: Dictionary, at: Vector3, radius: float, duration: float, mode := 0, vertical := false) -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var mat := material(SIGIL, look)
	mat.set_shader_parameter("motif", MOTIFS.get(String(look.family), 3.0))
	mat.set_shader_parameter("mode", float(mode))
	var node := MeshInstance3D.new()
	node.name = "InkImpact" if mode == 1 else "InkSeal"
	node.mesh = quad()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = at
	node.scale = Vector3.ONE * radius
	if vertical:
		var camera := parent.get_viewport().get_camera_3d()
		if camera and node.global_position.distance_squared_to(camera.global_position) > 0.01:
			node.look_at(camera.global_position, Vector3.UP)
	else:
		node.rotation.x = -PI * 0.5
	VfxBudget.track_decoration(node)
	var final_scale := node.scale
	node.scale *= 0.72 if mode == 0 else 0.4
	node.create_tween().tween_property(node, "scale", final_scale, duration * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tw := node.create_tween()
	tw.tween_method(func(age: float): mat.set_shader_parameter("age", age), 0.0, 1.0, duration)
	tw.tween_callback(node.queue_free)
	return node

static func ribbon(parent: Node3D, look: Dictionary, at: Vector3, radius: float, kind: int, tilt: Vector3, duration := 0.48, delay := 0.0) -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var node := MeshInstance3D.new()
	node.name = "InkBlade"
	node.mesh = ribbon_mesh(kind)
	var mat := material(RIBBON, look)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = at
	node.rotation = tilt
	node.scale = Vector3.ONE * radius
	VfxBudget.track_decoration(node)
	var tw := node.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(age: float): mat.set_shader_parameter("age", age), 0.0, 1.0, duration)
	tw.tween_callback(node.queue_free)
	return node

static func quad() -> QuadMesh:
	if not _meshes.has("quad"):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(2, 2)
		_meshes.quad = mesh
	return _meshes.quad

static func ribbon_mesh(kind: int) -> ArrayMesh:
	var key := "ribbon_%d" % kind
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	var uv: Array[Vector2] = []
	for i in 37:
		var t := float(i) / 36.0
		var a := -2.2 + t * (5.85 if kind == 1 else 3.9)
		var w := pow(maxf(0.0, sin(t * PI)), 0.65) * (0.22 if kind != 2 else 0.09)
		for side in [-1.0, 1.0]:
			var v: Vector3 = Vector3(sin(a), 0, cos(a)) * (1.0 + side * w)
			if kind == 2:
				v = Vector3(side * w, 0, (t - 0.5) * 2.0)
			points.append(v)
			uv.append(Vector2(t, (side + 1.0) * 0.5))
	for i in 36:
		for index in [i * 2, i * 2 + 2, i * 2 + 1, i * 2 + 1, i * 2 + 2, i * 2 + 3]:
			st.set_uv(uv[index])
			st.add_vertex(points[index])
	st.generate_normals()
	_meshes[key] = st.commit()
	return _meshes[key]
