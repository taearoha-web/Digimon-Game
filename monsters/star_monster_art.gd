class_name StarMonsterArt
extends RefCounted
## Readable regional silhouettes on newly licensed animated animals/skeletons.
## Finite caches: nine shared meshes and four shared vertex-color materials.
## No lights, particles, per-frame scripts, timers or per-spawn shader resources.
## Adornments follow actual head/torso bones, including hit and death animation.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func attach(root: Node3D, definition: Dictionary) -> void:
	if root == null or not definition.has("decor") or root.has_meta("star_art_attached"):
		return
	root.set_meta("star_art_attached", true)
	var h := float(definition.get("height", 2.0))
	var theme := String(definition.get("region", "dawn_forest"))
	var style := String(definition.decor)
	var skeleton := _find_skeleton(root)
	var head := _anchor(root, skeleton, ["head", "Head"], "StarCrown", Vector3(0, h * 0.72, 0))
	var torso := _anchor(root, skeleton, ["chest", "Torso3", "Torso"], "StarMantle", Vector3(0, h * 0.45, 0))
	var royal := bool(definition.get("boss", false))
	var elite := bool(definition.get("elite", false))
	var unit := h * 0.22
	if theme == "dawn_forest":
		_add(head, "leaves", theme, Vector3(0, unit * 0.38, 0), Vector3.ONE * unit)
		if style in ["flower", "spirit", "forest_king"]:
			_add(head, "flower", theme, Vector3(0, unit * 0.85, 0), Vector3.ONE * unit * 0.65)
		if elite or royal:
			_add(torso, "mantle", theme, Vector3(0, unit * 0.18, 0), Vector3.ONE * unit * 1.8)
		if royal:
			_add(head, "crown", theme, Vector3(0, unit * 0.5, 0), Vector3.ONE * unit * 1.4)
	elif theme == "crystal_valley":
		_add(torso, "crystals", theme, Vector3(0, unit * 0.35, 0), Vector3.ONE * unit * (1.7 if elite or royal else 1.0))
		if style in ["ice_halo", "crystal_crown", "crystal_king"]:
			_add(head, "crown", theme, Vector3(0, unit * 0.48, 0), Vector3.ONE * unit * 0.9)
		if royal:
			_add(torso, "mantle", theme, Vector3(0, unit * 0.2, 0), Vector3.ONE * unit * 2.6)
			_add(head, "crystals", theme, Vector3(0, unit * 0.68, 0), Vector3.ONE * unit * 0.9)
	elif theme == "sky_citadel":
		_add(head, "halo", theme, Vector3(0, unit * 1.35, 0), Vector3.ONE * unit * 0.95)
		if style in ["wings", "storm_wings", "sky_commander", "sky_king"]:
			_add(torso, "wings", theme, Vector3(0, unit * 0.32, unit * 0.15), Vector3.ONE * unit * (2.6 if royal else 1.8))
		if elite or royal:
			_add(head, "crown", theme, Vector3(0, unit * 0.4, 0), Vector3.ONE * unit * 0.85)
		if style == "sky_oracle":
			_add(torso, "mantle", theme, Vector3(0, unit * 0.1, 0), Vector3.ONE * unit * 0.8)
	elif theme == "eclipse_realm":
		_add(head, "crown", theme, Vector3(0, unit * 0.55, 0), Vector3.ONE * unit * (0.9 if elite or royal else 0.5))
		if style != "eclipse_sigil":
			_add(torso, "mantle", theme, Vector3(0, unit * 0.24, 0), Vector3.ONE * unit * (1.55 if elite or royal else 1.0))
		if royal or style == "eclipse_reaper":
			_add(torso, "eclipse", theme, Vector3(0, unit * 0.65, unit * 0.38), Vector3.ONE * unit * (2.5 if royal else 1.3))
		if royal:
			_add(torso, "wings", theme, Vector3(0, unit * 0.22, unit * 0.3), Vector3.ONE * unit * 2.0)
	if skeleton and definition.has("weapon"):
		_weapon(skeleton, String(definition.weapon), "handslot.r")
	if skeleton and definition.has("offhand"):
		_weapon(skeleton, String(definition.offhand), "handslot.l")

static func _weapon(skeleton: Skeleton3D, look: String, bone: String) -> void:
	if skeleton.find_bone(bone) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "StarWeapon_" + bone.replace(".", "_")
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var grip := Node3D.new()
	grip.basis = WeaponGrip.mount(look.get_slice("_", 0))
	attachment.add_child(grip)
	grip.add_child(WeaponKit.build(look))

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

static func _anchor(root: Node3D, skeleton: Skeleton3D, names: Array, label: String, fallback: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	if skeleton:
		for bone_name in names:
			var index := skeleton.find_bone(String(bone_name))
			if index < 0:
				continue
			var bone := BoneAttachment3D.new()
			bone.name = label + "Bone"
			bone.bone_name = String(bone_name)
			skeleton.add_child(bone)
			bone.add_child(pivot)
			# Restore root-oriented axes and world-metres at rest. Authored bone
			# motion subsequently carries the ornaments naturally with the body.
			var to_root := Basis.IDENTITY
			var ancestor: Node = skeleton
			while ancestor != null and ancestor != root:
				if ancestor is Node3D:
					to_root = (ancestor as Node3D).basis * to_root
				ancestor = ancestor.get_parent()
			pivot.basis = (to_root * skeleton.get_bone_global_rest(index).basis).inverse()
			return pivot
	root.add_child(pivot)
	pivot.position = fallback
	return pivot

static func _material(theme: String) -> StandardMaterial3D:
	if _materials.has(theme):
		return _materials[theme] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	mat.metallic = 0.24
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var palette := {"dawn_forest":Color("c5e3a5"), "crystal_valley":Color("a3d9ff"), "sky_citadel":Color("ffedb8"), "eclipse_realm":Color("bba1e0")}
	mat.albedo_color = palette.get(theme, Color.WHITE)
	_materials[theme] = mat
	return mat

static func _add(parent: Node3D, kind: String, theme: String, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Star_" + kind
	mi.mesh = _mesh(kind)
	mi.material_override = _material(theme)
	mi.position = at
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color("fff3d7")
	var shade := Color("718095")
	match kind:
		"leaves":
			for i in 8:
				var a := TAU * float(i) / 8.0
				_gem(st, Vector3(cos(a) * 0.45, 0.03, sin(a) * 0.35), Vector3(0.22, 0.1, 0.34), Color("91cc79"), Vector3(0, -a, 0.3))
		"flower":
			for i in 7:
				var a := TAU * float(i) / 7.0
				_gem(st, Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), Vector3(0.3, 0.12, 0.3), Color("ffe3b7"))
			_gem(st, Vector3(0, 0.13, 0), Vector3(0.3, 0.2, 0.3), Color("ffc76a"))
		"crystals":
			for i in 7:
				var x := (float(i) - 3.0) * 0.18
				_gem(st, Vector3(x, 0.14, 0), Vector3(0.19, 0.4 + 0.08 * float(i % 3), 0.21), white if i % 2 == 0 else Color("abc6f8"), Vector3(0, 0, -x))
		"mantle":
			for sign_value in [-1.0, 1.0]:
				for i in 4:
					_gem(st, Vector3(sign_value * (0.3 + i * 0.13), -i * 0.11, 0.15), Vector3(0.24, 0.36, 0.4), white.lerp(shade, i * 0.12), Vector3(0, 0, sign_value * -0.45))
		"crown":
			_ring(st, 0.45, 0.035, Color("ffd681"))
			for i in 7:
				var a := TAU * float(i) / 7.0
				_gem(st, Vector3(cos(a) * 0.45, 0.24, sin(a) * 0.45), Vector3(0.1, 0.35, 0.1), white)
		"halo":
			_ring(st, 0.52, 0.045, white)
			_ring(st, 0.62, 0.018, Color("ffd681"))
			for i in 4:
				var a := PI * 0.5 * i
				_gem(st, Vector3(cos(a) * 0.62, 0, sin(a) * 0.62), Vector3(0.1, 0.07, 0.1), white)
		"wings":
			for side in [-1.0, 1.0]:
				for i in 7:
					var x := 0.3 + i * 0.16
					_gem(st, Vector3(side * x, 0.2 + sin(i * 0.4) * 0.36, 0.08 + i * 0.08), Vector3(0.18, 0.6 - i * 0.025, 0.07), white.lerp(shade, i * 0.03), Vector3(0.25, 0, side * -0.65))
		"eclipse":
			# Two intersecting opaque rings, never a transparent full-screen plane.
			_ring(st, 0.62, 0.05, Color("ffd58d"), Basis(Vector3.RIGHT, PI * 0.5))
			_ring(st, 0.76, 0.022, Color("b08de0"), Basis(Vector3.RIGHT, PI * 0.5))
			for i in 8:
				var a := TAU * i / 8.0
				_gem(st, Vector3(cos(a) * 0.76, sin(a) * 0.76, 0), Vector3(0.08, 0.08, 0.04), white)
	st.generate_normals()
	var mesh := st.commit()
	_meshes[kind] = mesh
	return mesh

static func _gem(st: SurfaceTool, at: Vector3, size: Vector3, color: Color, angles := Vector3.ZERO) -> void:
	var b := Basis.from_euler(angles)
	var points := [Vector3(0,1,0), Vector3(0,-1,0), Vector3(1,0,0), Vector3(0,0,1), Vector3(-1,0,0), Vector3(0,0,-1)]
	for i in 4:
		var a := 2 + i
		var c := 2 + (i + 1) % 4
		for index in [0,a,c,1,c,a]:
			st.set_color(color)
			st.add_vertex(at + b * (points[index] * size))

static func _ring(st: SurfaceTool, radius: float, thickness: float, color: Color, b := Basis.IDENTITY) -> void:
	for i in 32:
		var a := TAU * i / 32.0
		var z := TAU * (i + 1) / 32.0
		var p := Vector3(cos(a), 0, sin(a))
		var q := Vector3(cos(z), 0, sin(z))
		for vertex in [p*(radius-thickness), p*(radius+thickness), q*(radius+thickness), p*(radius-thickness), q*(radius+thickness), q*(radius-thickness)]:
			st.set_color(color)
			st.add_vertex(b * vertex)
