class_name DeepMonsterArt
extends RefCounted
## The bioluminescent dressing of the ห้วงสมุทรอสูร bestiary (DrownedAbyssData):
## a glowing tide ring on the ground, a halo of drifting light pearls and, on
## elites and the tyrant, a crown of glowing coral spikes. The colour is the
## template's "aura". Shared meshes and one material per colour (a finite
## cache); no lights, particles or per-frame scripts.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func attach(visual: Node3D, template: Dictionary) -> void:
	if visual == null or not template.has("aura") or visual.has_meta("deep_aura"):
		return
	visual.set_meta("deep_aura", true)
	var color: Color = template.aura
	var h := float(template.get("height", 2.0))
	var big := bool(template.get("elite", false)) or bool(template.get("boss", false))
	var root := Node3D.new()
	root.name = "DeepAura"
	visual.add_child(root)
	var ring := MeshInstance3D.new()
	ring.mesh = _mesh("ring")
	ring.material_override = _material(color, 0.55)
	ring.scale = Vector3.ONE * clampf(h * 0.42, 0.7, 2.8)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var pearls := 6 if big else 4
	for i in pearls:
		var a := TAU * float(i) / float(pearls)
		var pearl := MeshInstance3D.new()
		pearl.mesh = _mesh("pearl")
		pearl.material_override = _material(color.lightened(0.35), 0.9)
		pearl.scale = Vector3.ONE * clampf(h * 0.06, 0.1, 0.32)
		pearl.position = Vector3(cos(a) * h * 0.42, h * (0.35 + 0.18 * float(i % 3)), sin(a) * h * 0.42)
		pearl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pearl)
	if big:
		for i in 7:
			var a := TAU * float(i) / 7.0
			var spike := MeshInstance3D.new()
			spike.mesh = _mesh("spike")
			spike.material_override = _material(color, 0.8)
			var s := h * (0.09 if i % 2 == 0 else 0.065)
			spike.scale = Vector3(s, s * 2.6, s)
			spike.position = Vector3(cos(a) * h * 0.16, h * 1.02, sin(a) * h * 0.16)
			spike.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
			spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(spike)


static func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.86
			torus.outer_radius = 1.0
			torus.rings = 24
			torus.ring_segments = 4
			mesh = torus
		"pearl":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 8
			sphere.rings = 4
			mesh = sphere
		_:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 5
			cone.rings = 1
			mesh = cone
	_meshes[kind] = mesh
	return mesh


static func _material(color: Color, alpha: float) -> Material:
	var key := "%s|%.2f" % [color.to_html(false), alpha]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(color, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m
	return _materials[key]
