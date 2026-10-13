class_name ThunderStormArt
extends Node3D
## A single connected smoke-grey cloud mesh. No lights, CPU particles, camera
## effects or full-screen flash. A depth-tested surface keeps lobes seamless.
const CLOUD_HEIGHT := 8.8
const CLOUD_SHADER := preload("res://shaders/thunder_cloud.gdshader")
const SEAL_SHADER := preload("res://shaders/thunder_seal.gdshader")
const IMPACT_SHADER := preload("res://shaders/thunder_impact.gdshader")
const WISP_SHADER := preload("res://shaders/thunder_wisp.gdshader")
static var _cloud_mesh: ArrayMesh
static var _wisp_mesh: ArrayMesh
var radius := 9.0
var cloud: MeshInstance3D
var _mat: ShaderMaterial
var _seal_mat: ShaderMaterial
var _wisp_mat: ShaderMaterial

static func cloud_mesh() -> ArrayMesh:
	if _cloud_mesh:
		return _cloud_mesh
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	# Radial union of overlapping ellipsoids: one watertight cloud surface,
	# with rounded lobes instead of layered transparent sphere intersections.
	var centres: Array[Vector3] = [Vector3.ZERO]
	var sizes: Array[Vector3] = [Vector3(0.79, 0.60, 0.79)]
	for peak in 5:
		var a := TAU * float(peak) / 5.0
		centres.append(Vector3(cos(a) * 0.30, 0.38 + sin(a * 2.0) * 0.11, sin(a) * 0.30))
		sizes.append(Vector3(0.38, 0.73 + cos(a) * 0.12, 0.39))
	for lobe in 13:
		var angle := TAU * float(lobe) / 13.0
		centres.append(Vector3(cos(angle) * 0.67, 0.03 + sin(angle * 3.0) * 0.17, sin(angle) * 0.67))
		var width := 0.29 + 0.06 * sin(angle * 2.0 + 0.5)
		sizes.append(Vector3(width, 0.48 + 0.16 * cos(angle * 3.0), width))
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var direction := vertices[i].normalized()
		var reach := 0.0
		for j in centres.size():
			var ray := direction / sizes[j]
			var offset := -centres[j] / sizes[j]
			var a := ray.dot(ray)
			var b := ray.dot(offset)
			var discriminant := b * b - a * (offset.dot(offset) - 1.0)
			if discriminant >= 0.0:
				var edge := (-b + sqrt(discriminant)) / a
				var blend := maxf(0.0, 0.055 - absf(reach - edge)) / 0.055
				reach = maxf(reach, edge) + blend * blend * 0.055 * 0.25
		vertices[i] = direction * reach
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	_cloud_mesh = st.commit()
	return _cloud_mesh

static func wisp_mesh() -> ArrayMesh:
	if _wisp_mesh:
		return _wisp_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in 2:
		for step in 48:
			for corner in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(0,1), Vector2(1,0), Vector2(1,1)]:
				var t: float = (float(step) + corner.x) / 48.0
				var a := t * TAU * 0.86 + band * PI
				var reach := 0.9 + sin(t * PI) * 0.13
				var y: float = -0.25 + t * 0.7 - band * 0.35 + (corner.y - 0.5) * 0.30
				st.set_uv(Vector2(t, corner.y))
				st.add_vertex(Vector3(cos(a) * reach, y, sin(a) * reach))
	st.generate_normals()
	_wisp_mesh = st.commit()
	return _wisp_mesh

static func warm_up(parent: Node3D, at: Vector3) -> void:
	var sample := ThunderStormArt.new()
	sample.radius = 0.01
	sample.scale = Vector3.ONE * 0.001
	sample.position = at
	parent.add_child(sample)
	sample._impact(Vector3.ZERO)
	sample.create_tween().tween_interval(0.45).finished.connect(sample.queue_free, CONNECT_ONE_SHOT)

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = CLOUD_SHADER
	_mat.set_shader_parameter("fade", 0.0)
	_mat.set_shader_parameter("age", 0.0)
	cloud = MeshInstance3D.new()
	cloud.name = "ThunderStormCloud"
	cloud.mesh = cloud_mesh()
	cloud.material_override = _mat
	cloud.position.y = CLOUD_HEIGHT
	cloud.scale = Vector3(radius, 3.5, radius)
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	if VfxBudget.can_decorate():
		var wisp := MeshInstance3D.new()
		wisp.name = "ThunderStormRollingMist"
		wisp.mesh = wisp_mesh()
		_wisp_mat = ShaderMaterial.new()
		_wisp_mat.shader = WISP_SHADER
		wisp.material_override = _wisp_mat
		wisp.position.y = CLOUD_HEIGHT - 0.8
		wisp.scale = Vector3(radius, 3.0, radius)
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wisp)
		VfxBudget.track_decoration(wisp)
	# A single quad carries the entire engraved seal, including its mist band.
	_seal_mat = ShaderMaterial.new()
	_seal_mat.shader = SEAL_SHADER
	_seal_mat.set_shader_parameter("age", 0.0)
	var seal := MeshInstance3D.new()
	seal.name = "EssentialSkillRange"
	seal.mesh = SkillInk.quad()
	seal.material_override = _seal_mat
	seal.position.y = 0.055
	seal.rotation.x = -PI * 0.5
	seal.scale = Vector3.ONE * (radius / 0.94)
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seal)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, 0.5)
	tw.tween_interval(1.55)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.55)
	# Tween age rather than shader TIME: pause freezes the cloud and engravings.
	create_tween().tween_method(func(v: float):
		_mat.set_shader_parameter("age", v)
		_seal_mat.set_shader_parameter("age", v)
		if _wisp_mat:
			_wisp_mat.set_shader_parameter("age", v)
	, 0.0, 2.6, 2.6)

func _set_fade(value: float) -> void:
	_mat.set_shader_parameter("fade", value)
	_seal_mat.set_shader_parameter("fade", value)
	if _wisp_mat:
		_wisp_mat.set_shader_parameter("fade", value)

func flash() -> void:
	_set_pulse(1.0)
	create_tween().tween_method(_set_pulse, 1.0, 0.0, 0.42)

func _set_pulse(value: float) -> void:
	_mat.set_shader_parameter("pulse", value)
	_seal_mat.set_shader_parameter("pulse", value)
	if _wisp_mat:
		_wisp_mat.set_shader_parameter("pulse", value)

func strike(to: Vector3, seed_value: int) -> void:
	var points := PackedVector3Array()
	var start := Vector3(to.x * 0.86, CLOUD_HEIGHT - 0.8, to.z * 0.86)
	for i in 12:
		var t := float(i) / 11.0
		var p := start.lerp(to, t)
		if i > 0 and i < 11:
			p.x += sin(seed_value * 3.7 + i * 8.1) * 0.65
			p.z += cos(seed_value * 5.3 + i * 6.7) * 0.48
		points.append(p)
	# Essential gold path is always rendered. Halos, forks and impact engraving
	# share the global decoration budget, so overlapping casts remain bounded.
	_bolt_layer(points, 0.20, Color("ffd044"), "ThunderStormStrike", 2, false)
	_bolt_layer(points, 0.58, Color(0.10, 0.48, 1.0, 0.16), "ThunderStormCorona", 0)
	_bolt_layer(points, 0.34, Color(0.18, 0.70, 1.0, 0.60), "ThunderStormBlue", 1)
	_bolt_layer(points, 0.085, Color("fff7ce"), "ThunderStormCore", 3)
	for fork in VfxBudget.count(3, 1):
		var joint := 2 + fork * 2
		var side := -1.0 if (seed_value + fork) % 2 == 0 else 1.0
		var branch := PackedVector3Array([points[joint], points[joint] + Vector3(side * 1.25, -0.45, 0.35), points[joint] + Vector3(side * 0.8, -1.0, 0.6), points[joint] + Vector3(side * 1.8, -1.8, 0.85)])
		_bolt_layer(branch, 0.105, Color(0.24, 0.73, 1.0, 0.8), "ThunderStormFork", 1)
		_bolt_layer(branch, 0.038, Color("ffe597"), "ThunderStormForkCore", 2)
	_impact(to)

func _impact(at: Vector3) -> void:
	if not VfxBudget.can_decorate():
		return
	var node := MeshInstance3D.new()
	node.name = "ThunderStormImpact"
	node.mesh = SkillInk.quad()
	var mat := ShaderMaterial.new()
	mat.shader = IMPACT_SHADER
	node.material_override = mat
	node.position = Vector3(at.x, 0.075, at.z)
	node.rotation.x = -PI * 0.5
	node.scale = Vector3.ONE * 1.9
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	VfxBudget.track_decoration(node)
	var tw := node.create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("age", v), 0.0, 1.0, 0.48)
	tw.tween_callback(node.queue_free)

func _bolt_layer(points: PackedVector3Array, width: float, color: Color, label: String, priority: int, decorative := true) -> void:
	if decorative and not VfxBudget.can_decorate():
		return
	var bolt := MeshInstance3D.new()
	bolt.name = label
	bolt.mesh = SpellSpectacle._tube_mesh(points, width)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	MaterialKeeper.keep(mat)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.render_priority = priority
	bolt.material_override = mat
	add_child(bolt)
	if decorative:
		VfxBudget.track_decoration(bolt)
	var tw := bolt.create_tween()
	tw.tween_interval(0.13)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tw.tween_callback(bolt.queue_free)
