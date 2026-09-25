class_name MeshKit
extends RefCounted
## Shared primitive meshes and cached toon materials for the ORIGINAL
## placeholder art. Meshes are unit-sized and scaled per node so every
## character reuses the same few mesh resources (low memory, batch friendly).

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}
static var _shadow_texture: Texture2D


static func sphere() -> Mesh:
	if not _meshes.has("sphere"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 20
		m.rings = 10
		_meshes["sphere"] = m
	return _meshes["sphere"]


static func sphere_low() -> Mesh:
	if not _meshes.has("sphere_low"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 10
		m.rings = 6
		_meshes["sphere_low"] = m
	return _meshes["sphere_low"]


static func hemisphere() -> Mesh:
	if not _meshes.has("hemisphere"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 0.5
		m.is_hemisphere = true
		m.radial_segments = 20
		m.rings = 6
		_meshes["hemisphere"] = m
	return _meshes["hemisphere"]


static func capsule() -> Mesh:
	if not _meshes.has("capsule"):
		var m := CapsuleMesh.new()
		m.radius = 0.5
		m.height = 2.0
		m.radial_segments = 14
		m.rings = 4
		_meshes["capsule"] = m
	return _meshes["capsule"]


static func cylinder() -> Mesh:
	if not _meshes.has("cylinder"):
		var m := CylinderMesh.new()
		m.top_radius = 0.5
		m.bottom_radius = 0.5
		m.height = 1.0
		m.radial_segments = 14
		m.rings = 1
		_meshes["cylinder"] = m
	return _meshes["cylinder"]


static func cone() -> Mesh:
	if not _meshes.has("cone"):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.5
		m.height = 1.0
		m.radial_segments = 12
		m.rings = 1
		_meshes["cone"] = m
	return _meshes["cone"]


static func box() -> Mesh:
	if not _meshes.has("box"):
		var m := BoxMesh.new()
		m.size = Vector3.ONE
		_meshes["box"] = m
	return _meshes["box"]


static func torus() -> Mesh:
	if not _meshes.has("torus"):
		var m := TorusMesh.new()
		m.inner_radius = 0.38
		m.outer_radius = 0.5
		m.rings = 16
		m.ring_segments = 8
		_meshes["torus"] = m
	return _meshes["torus"]


static func prism() -> Mesh:
	if not _meshes.has("prism"):
		var m := PrismMesh.new()
		m.size = Vector3.ONE
		_meshes["prism"] = m
	return _meshes["prism"]


static func quad() -> Mesh:
	if not _meshes.has("quad"):
		var m := QuadMesh.new()
		m.size = Vector2.ONE
		_meshes["quad"] = m
	return _meshes["quad"]


## Cached stylised toon material. opts: unshaded, emission (float), alpha, rim.
static func toon(color: Color, opts := {}) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(true), str(opts)]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if opts.get("unshaded", false):
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		# Toon diffuse without specular keeps colours true under the
		# Compatibility renderer; an optional subtle rim adds anime edge light.
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat.roughness = 1.0
		if opts.get("rim", false):
			mat.rim_enabled = true
			mat.rim = 0.12
			mat.rim_tint = 0.8
	var emission: float = opts.get("emission", 0.0)
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if color.a < 1.0 or opts.has("alpha"):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = opts.get("alpha", color.a)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED if opts.get("double_sided", false) else BaseMaterial3D.CULL_BACK
	if opts.get("double_sided", false):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[key] = mat
	return mat


## Adds a mesh part. Small parts skip shadow casting to save draw calls.
static func part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale: Vector3,
		rot_deg := Vector3.ZERO, part_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	if part_name != "":
		mi.name = part_name
	if maxf(scale.x, maxf(scale.y, scale.z)) < 0.14:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pivot_name: String, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	return n


## Soft round "blob" shadow that grounds characters even with shadows off.
static func blob_shadow(parent: Node3D, radius: float, y := 0.02) -> MeshInstance3D:
	if _shadow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0.45))
		gradient.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_shadow_texture = tex
	var key := "blob_shadow"
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _shadow_texture
		mat.albedo_color = Color.WHITE
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = -1
		_materials[key] = mat
	var mi := MeshInstance3D.new()
	mi.name = "BlobShadow"
	mi.mesh = quad()
	mi.material_override = _materials[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.scale = Vector3(radius * 2.0, radius * 2.0, 1.0)
	mi.position = Vector3(0, y, 0)
	parent.add_child(mi)
	return mi


## Collects every MeshInstance3D below [param root].
static func collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect(root, out)
	return out


static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.name != "BlobShadow":
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
