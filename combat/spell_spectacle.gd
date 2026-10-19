class_name SpellSpectacle
extends RefCounted
## Layered, volumetric silhouettes. This module is cosmetic and has no timers
## or callbacks that deal damage. All lifetime tweens are bound to their nodes.
## Silhouettes survive quality reduction; extra geometry and particles do not.

const BODY := preload("res://shaders/spectacle_body.gdshader")
static var _meshes: Dictionary = {}
## Immutable authored tube geometry is shared; per-cast materials and tweens
## stay independent. The ceiling also bounds future dynamic recipe parameters.
const TUBE_CACHE_LIMIT := 128
static var _tube_meshes: Dictionary = {}
## One textured card per particle kind; its colour comes from the emitter's ramp.
static var _particle_cards: Dictionary = {}


static func warm_up(parent: Node3D, at: Vector3) -> void:
	_sphere_mesh()
	_column_mesh()
	_halo_mesh()
	_crystal_mesh()
	_blade_mesh(false)
	_blade_mesh(true)
	_wing_mesh()
	warm_geometry()
	var look := SkillShow.profile_for(ClassData.pool(&"vagabond")[0])
	var mat := _material(look, 0.001)
	SkillInk.mark(parent, look, at + Vector3(0, 0.05, 0), 0.01, 0.4)
	SkillInk.ribbon(parent, look, at + Vector3(0, 0.1, 0), 0.01, 0, Vector3.ZERO, 0.4)
	var sample := _mesh(parent, _crystal_mesh(), mat, at + Vector3(0, 0.1, 0))
	if sample:
		sample.scale = Vector3.ONE * 0.01
		sample.create_tween().tween_interval(0.4).finished.connect(sample.queue_free, CONNECT_ONE_SHOT)


## Build the finite tier recipes during loading, never on a repeated hit.
## Higher quality retains exactly the same vertices, normals and silhouettes.
static func warm_geometry() -> void:
	EliteSkillArt.warm_geometry()
	BuffArt.warm_geometry()
	SkillInk.warm_geometry()
	SkillCraft.warm_geometry()
	SkillTableau.lightning_mesh()
	SkillTableau.shield_mesh()
	for kind in ["cat", "wolf", "frog", "treant", "fire"]:
		SkillTableau.creature_mesh(kind)
	for tier in 1 + [1, 3, 5][VfxBudget.quality()]:
		for stroke in 4:
			_slash_mesh(tier, stroke)
		for recipe in [
			[1.7 + tier * 0.2, 2.0, 1],
			[1.1 + tier * 0.25, 2.4 + tier * 0.3, 2 + tier / 2],
			[1.2 + tier * 0.24, 3.4 + tier * 0.4, 2 + tier / 2],
			[0.85 + tier * 0.14, 2.3 + tier * 0.25, 2],
			[1.2 + tier * 0.15, 2.5, 2],
		]:
			for strand in int(recipe[2]):
				_helix_mesh(float(recipe[0]), float(recipe[1]), int(recipe[2]), strand)
	# Ultimate and roar templates have fixed dimensions at every quality.
	for stroke in 4:
		_slash_mesh(5, stroke)
	for recipe in [[1.5, 6.4, 2], [2.0, 7.2, 2], [2.8, 4.3, 2], [1.8, 1.3, 2]]:
		for strand in int(recipe[2]):
			_helix_mesh(float(recipe[0]), float(recipe[1]), int(recipe[2]), strand)
	_dragon_mesh()
	_phoenix_tail_mesh()


static func anticipate(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, duration: float, aim := Vector3.ZERO) -> void:
	SkillTableau.anticipate(parent, skill, look, origin, duration, aim)


static func cast(parent: Node3D, skill: Dictionary, look: Dictionary, center: Vector3, origin: Vector3, tier: int, crowd := 0) -> void:
	SkillTableau.render(parent, skill, look, center, origin, tier, crowd)


static func impact(parent: Node3D, skill: Dictionary, look: Dictionary, at: Vector3, tier: int) -> void:
	if String(skill.get("id", "")) == "armageddon":
		return
	var root := _root(parent, at, "SpellContact")
	var mat := _material(look)
	_ground_shards(root, mat, 0.75 + tier * 0.15, 3 + tier)
	_particles(root, look, Vector3(0, 0.3, 0), "spark", 10 + tier * 3, 1.8, 0.7)
	_finish(root, mat, 0.6)


static func _root(parent: Node3D, at: Vector3, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.global_position = at
	return node


static func _material(look: Dictionary, opacity := 0.93) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BODY
	mat.set_shader_parameter("color", look.primary)
	mat.set_shader_parameter("core", look.accent)
	mat.set_shader_parameter("shade", look.shade)
	mat.set_shader_parameter("pulse", float(look.phase))
	mat.set_shader_parameter("opacity", opacity)
	# The authored palette picks the surface: flame burns in waves, frost and
	# tide crack, grove and bloom carry leaf veins, grace and gold sparkle.
	var palettes := {"flame": 2.0, "frost": 1.0, "tide": 1.0, "steel": 1.0, "grove": 3.0, "bloom": 3.0, "grace": 4.0, "gold": 4.0, "arcane": 4.0, "storm": 4.0}
	var surfaces := {"ice": 1.0, "fire": 2.0, "leaf": 3.0, "heal": 3.0, "holy": 4.0, "arcane": 4.0, "thunder": 4.0}
	mat.set_shader_parameter("surface_style", palettes.get(String(look.get("palette", "")), surfaces.get(String(look.get("style", "phys")), 0.0)))
	return mat


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, position := Vector3.ZERO) -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.position = position
	VfxBudget.track_decoration(node)
	return node


static func _finish(root: Node3D, mat: ShaderMaterial, duration: float) -> void:
	var target := root.scale
	root.scale *= 0.94
	root.create_tween().tween_property(root, "scale", target, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tw := root.create_tween()
	tw.tween_interval(maxf(0.16, duration * 0.62))
	tw.tween_method(func(value: float): mat.set_shader_parameter("fade", value), 1.0, 0.0, duration * 0.38)
	# Contrasting facial details share the same dissolve as their spirit body.
	var details: Array[ShaderMaterial] = []
	for child in root.find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and child.material_override is ShaderMaterial:
			var detail: ShaderMaterial = child.material_override
			if detail.shader == BODY and detail != mat and not details.has(detail):
				details.append(detail)
	for detail in details:
		var fade := root.create_tween()
		fade.tween_interval(maxf(0.16, duration * 0.62))
		fade.tween_method(func(value: float): detail.set_shader_parameter("fade", value), 1.0, 0.0, duration * 0.38)
	tw.tween_interval(0.08)
	tw.tween_callback(root.queue_free)


static func _particles(parent: Node3D, look: Dictionary, at: Vector3, kind: String, amount: int, spread_size: float, life: float, rising := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.lifetime = life
	p.explosiveness = 0.86 if not rising else 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread_size * 0.3
	p.direction = Vector3.UP
	p.spread = 62.0 if not rising else 20.0
	p.gravity = Vector3(0, -2.0 if not rising else 0.3, 0)
	p.initial_velocity_min = spread_size * 0.9
	p.initial_velocity_max = spread_size * 2.1
	p.scale_amount_min = 0.28 if kind != "smoke" else 0.7
	p.scale_amount_max = 0.72 if kind != "smoke" else 1.6
	p.angular_velocity_min = -65.0
	p.angular_velocity_max = 65.0
	p.mesh = _particle_card(kind)
	parent.add_child(p)
	p.position = at
	if not VfxBudget.track_particles(p, amount):
		p.queue_free()
		return
	# Only a burst that is shown gets its colour ramp.
	var gradient := Gradient.new()
	var bright: Color = look.accent
	var color: Color = look.primary
	if kind == "smoke":
		color = look.shade
		bright = look.shade
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.66, 1.0])
	gradient.colors = PackedColorArray([Color(bright, 0.0), Color(bright, 0.82), Color(color, 0.68), Color(color, 0.0)])
	p.color_ramp = gradient
	p.emitting = true
	p.create_tween().tween_interval(life + 0.15).finished.connect(p.queue_free, CONNECT_ONE_SHOT)


## The card is white with vertex colours, so one mesh and material per kind
## serve every cast; nothing mutates them afterwards.
static func _particle_card(kind: String) -> QuadMesh:
	if _particle_cards.has(kind):
		return _particle_cards[kind]
	var card := QuadMesh.new()
	card.size = Vector2.ONE * (0.62 if kind != "smoke" else 1.2)
	var material := VfxKit._glow(Color.WHITE, 1.0, kind in ["spark", "flare"])
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = SpectacleAssets.tex(kind)
	card.material = material
	_particle_cards[kind] = card
	return card


static func _weapon(root: Node3D, mat: Material, kind: String, length: float, count: int) -> void:
	for i in VfxBudget.count(count, 1):
		var blade := _mesh(root, _blade_mesh(kind == "arrow"), mat, Vector3((i - (count - 1) * 0.5) * 0.8, 1.2, 0.2))
		if blade:
			blade.scale = Vector3(0.4 + length * 0.03, length, 0.4 + length * 0.03)
			blade.rotation.x = PI * 0.5
			blade.rotation.z = float(i - count / 2) * 0.10
			blade.create_tween().tween_property(blade, "position:z", length * 0.28, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _slashes(root: Node3D, mat: Material, recipe: String, tier: int, curve: float, authored_strokes := 0) -> void:
	var count := 1 if recipe == "cut" else mini(2 + tier / 2, 4)
	if authored_strokes > 0:
		count = clampi(authored_strokes, 1, 4)
	for i in VfxBudget.count(count, 1):
		if not VfxBudget.can_decorate():
			break
		var node := _mesh(root, _slash_mesh(tier, i), mat, Vector3(0, 0.85, 0))
		if node:
			node.rotation.z = (-0.65 if i % 2 == 0 else 0.65) + curve * 0.20
			node.rotation.x = float(i) * 0.2
			node.create_tween().tween_property(node, "rotation:y", 1.0 + float(i) * 0.4, 0.42).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


static func _helix(root: Node3D, mat: Material, radius: float, height: float, strands: int, horizontal := false) -> void:
	for k in VfxBudget.count(strands, 1):
		if not VfxBudget.can_decorate():
			break
		var node := _mesh(root, _helix_mesh(radius, height, strands, k), mat)
		if node:
			if horizontal:
				node.rotation.x = PI * 0.5
				node.position.y = 1.2
			node.scale.y = 0.18
			node.create_tween().tween_property(node, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			node.create_tween().tween_property(node, "rotation:y", 1.8, 0.8)


static func _sword_court(root: Node3D, mat: Material, layers: int) -> void:
	# Five real prismatic swords descend in a fan; the centre opens on the hit.
	var count := 5 if layers >= 3 else 3
	for i in count:
		var x := float(i) - float(count - 1) * 0.5
		var landing_height := 4.65 + absf(x) * 0.22
		var sword := _mesh(root, _blade_mesh(false), mat, Vector3(x * 0.85, landing_height, 0.3))
		if sword:
			sword.scale = Vector3(0.8, 4.8, 0.8)
			sword.rotation.z = PI - x * 0.24
			sword.position.y += 3.8
			sword.create_tween().tween_property(sword, "position:y", landing_height, 0.24 + absf(x) * 0.055).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slashes(root, mat, "crosscut", 5, -0.65)
	if layers >= 4:
		_ground_shards(root, mat, 3.2, 7)


static func _phoenix(root: Node3D, mat: Material, span: float, bird: bool) -> void:
	var wings := _mesh(root, _wing_mesh(), mat, Vector3(0, 1.7, 0.15))
	if wings:
		var spread := Vector3(span, span * 0.76, span * 0.68)
		wings.scale = Vector3(spread.x * 0.18, spread.y, spread.z)
		wings.create_tween().tween_property(wings, "scale", spread, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		wings.rotation.x = -0.18
		wings.create_tween().tween_property(wings, "rotation:x", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	if bird:
		var body := _mesh(root, _sphere_mesh(), mat, Vector3(0, 1.8, 0.25))
		if body:
			# A slender forward-leaning breast leaves the wing fan readable.
			body.scale = Vector3(0.11, 0.22, 0.16) * span
			body.rotation.x = PI * 0.28
		_mesh(root, _phoenix_tail_mesh(), mat)


static func _judgement(root: Node3D, mat: Material, layers: int) -> void:
	# A cathedral of six shafts surrounds a clear central column and winged halo.
	var center := _mesh(root, _column_mesh(), mat, Vector3(0, 4.0, 0))
	if center:
		center.scale = Vector3(0.22, 8.0, 0.22)
		# The axis lands in front of the target, leaving its body readable.
		center.position.z = 1.1
	var crown := _mesh(root, _halo_mesh(), mat, Vector3(0, 6.1, 0))
	if crown:
		crown.scale = Vector3.ONE * 2.7
	_phoenix(root, mat, 3.8, false)
	if layers >= 3:
		for i in 6:
			var a := TAU * float(i) / 6.0
			var shaft := _mesh(root, _column_mesh(), mat, Vector3(cos(a) * 3.1, 2.7, sin(a) * 3.1))
			if shaft:
				shaft.scale = Vector3(0.12, 5.4, 0.12)
	if layers >= 4:
		_helix(root, mat, 2.0, 7.2, 2)


static func _dragon(root: Node3D, mat: Material, layers: int) -> void:
	# An emerging spirit serpent: tapered neck/body, two spread wings and a
	# horned head. Combined tube geometry avoids a chain of disconnected balls.
	_mesh(root, _dragon_mesh(), mat)
	var head_at := Vector3(sin(TAU * 1.3) * 0.9, 5.0, cos(TAU * 1.3) * 0.9)
	var head := _mesh(root, _sphere_mesh(), mat, head_at)
	if head:
		head.scale = Vector3(0.62, 0.40, 0.92)
	var snout := _mesh(root, _sphere_mesh(), mat, head_at + Vector3(0, -0.09, 0.62))
	if snout:
		snout.scale = Vector3(0.43, 0.23, 0.63)
	_spirit_eyes(root, mat, head_at + Vector3(0, 0.12, 0.69), 0.34)
	var wings := _mesh(root, _wing_mesh(), mat, Vector3(0, 3.2, 0))
	if wings:
		wings.scale = Vector3(0.9, 3.1, 2.0)
		wings.create_tween().tween_property(wings, "scale:x", 4.5, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for side in [-1.0, 1.0]:
		var horn := _mesh(root, _crystal_mesh(), mat, head_at + Vector3(side * 0.36, 0.45, -0.22))
		if horn:
			horn.scale = Vector3(0.18, 0.9, 0.18)
			horn.rotation.z = -side * 0.45
	if layers >= 4:
		_helix(root, mat, 2.8, 4.3, 2)
	root.position.y -= 1.1
	root.create_tween().tween_property(root, "position:y", root.position.y + 1.1, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _spirit(root: Node3D, mat: Material, kind: String, tier: int) -> void:
	if "dragon" in kind or "drake" in kind:
		_dragon(root, mat, mini(tier, 3))
		return
	var body := _mesh(root, _sphere_mesh(), mat, Vector3(0, 1.6, 0))
	if body:
		body.scale = Vector3(0.65, 0.9, 0.55)
	_spirit_eyes(root, mat, Vector3(0, 1.86, 0.47), 0.25)
	for side in [-1.0, 1.0]:
		var ear := _mesh(root, _crystal_mesh(), mat, Vector3(side * 0.4, 2.35, 0))
		if ear:
			ear.scale = Vector3(0.2, 0.60, 0.2)
			ear.rotation.z = side * -0.25
	_helix(root, mat, 1.2 + tier * 0.15, 2.5, 2)


static func _spirit_eyes(root: Node3D, material: Material, at: Vector3, spacing: float) -> void:
	var mat := material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("color", Color("204555"))
	mat.set_shader_parameter("shade", Color("102b35"))
	mat.set_shader_parameter("core", Color("effff3"))
	for side in [-1.0, 1.0]:
		var eye := _mesh(root, _sphere_mesh(), mat, at + Vector3(side * spacing, 0, 0))
		if eye:
			eye.scale = Vector3(0.10, 0.14, 0.055)


static func _solar(root: Node3D, mat: Material, height: float, tier: int) -> void:
	var orb := _mesh(root, _sphere_mesh(), mat, Vector3(0, height * 0.66, 0))
	if orb:
		orb.scale = Vector3.ONE * (0.40 + tier * 0.08)
	var halo := _mesh(root, _halo_mesh(), mat, Vector3(0, height * 0.66, 0))
	if halo:
		halo.scale = Vector3.ONE * (0.9 + tier * 0.19)
		halo.rotation.x = PI * 0.5
	var column := _mesh(root, _column_mesh(), mat, Vector3(0, height * 0.5, 0))
	if column:
		column.scale = Vector3(0.10 + tier * 0.025, height, 0.10 + tier * 0.025)


static func _ward(root: Node3D, mat: Material, tier: int) -> void:
	var count := 3 + mini(tier, 3)
	for i in VfxBudget.count(count, 2):
		var a := TAU * float(i) / float(count)
		var panel := _mesh(root, _crystal_mesh(), mat, Vector3(sin(a) * 1.3, 1.3, cos(a) * 1.3))
		if panel:
			panel.scale = Vector3(0.62, 1.65, 0.12)
			panel.rotation.y = a
			panel.rotation.z = 0.13


static func _lotus(root: Node3D, mat: Material, tier: int) -> void:
	var count := 5 + mini(tier, 3)
	for i in VfxBudget.count(count, 3):
		var a := TAU * float(i) / float(count)
		var petal := _mesh(root, _crystal_mesh(), mat, Vector3(sin(a) * 0.75, 0.35, cos(a) * 0.75))
		if petal:
			petal.scale = Vector3(0.48, 1.7 + tier * 0.14, 0.25)
			petal.rotation = Vector3(0.7, a, 0)
	var seed := _mesh(root, _sphere_mesh(), mat, Vector3(0, 1.05, 0))
	if seed:
		seed.scale = Vector3.ONE * 0.35
		seed.create_tween().tween_property(seed, "position:y", 2.3, 1.0)


static func _crystal_crown(root: Node3D, mat: Material, tier: int, radius: float) -> void:
	_ground_shards(root, mat, minf(radius * 0.48, 3.1), 3 + tier)
	var star := _mesh(root, _crystal_mesh(), mat, Vector3(0, 2.6 + tier * 0.2, 0))
	if star:
		star.scale = Vector3(0.42, 1.2 + tier * 0.1, 0.42)
		star.create_tween().tween_property(star, "rotation:y", TAU * 0.5, 0.9)


static func _flame_core(root: Node3D, mat: Material, tier: int, travelling: bool) -> void:
	var sphere := _mesh(root, _sphere_mesh(), mat, Vector3(0, 1.4, 0.5 if travelling else 0.0))
	if sphere:
		sphere.scale = Vector3.ONE * (0.5 + tier * 0.10)
	_helix(root, mat, 0.85 + tier * 0.14, 2.3 + tier * 0.25, 2)


static func _sky_lances(root: Node3D, mat: Material, tier: int, travelling: bool) -> void:
	var count := 2 + tier / 2
	for i in VfxBudget.count(count, 1):
		var x := (float(i) - float(count - 1) * 0.5) * 0.7
		var length := 3.0 + tier * 0.40
		var shard := _mesh(root, _blade_mesh(true), mat, Vector3(x, 1.5 if travelling else length + 3.0, 0))
		if shard:
			shard.scale = Vector3(0.45, length, 0.45)
			shard.rotation.x = PI * 0.5 if travelling else PI
			if not travelling:
				shard.create_tween().tween_property(shard, "position:y", length, 0.19 + i * 0.04)


static func _orbit(root: Node3D, mat: Material, tier: int) -> void:
	var core := _mesh(root, _crystal_mesh(), mat, Vector3(0, 1.9, 0))
	if core:
		core.scale = Vector3(0.45, 0.9, 0.45)
		core.create_tween().tween_property(core, "rotation:y", TAU, 1.2)
	for i in VfxBudget.count(2 + tier / 2, 1):
		var halo := _mesh(root, _halo_mesh(), mat, Vector3(0, 1.5, 0))
		if halo:
			halo.scale = Vector3.ONE * (1.1 + i * 0.18)
			halo.rotation = Vector3(0.5 + i * 0.55, i * 0.65, 0.2)
			halo.create_tween().tween_property(halo, "rotation:y", halo.rotation.y + 1.9, 1.0)


static func _ground_shards(root: Node3D, mat: Material, radius: float, count: int) -> void:
	for i in VfxBudget.count(count, 2):
		var a := TAU * float(i) / float(count) + 0.21
		var shard := _mesh(root, _crystal_mesh(), mat, Vector3(sin(a) * radius, 0.04, cos(a) * radius))
		if shard:
			var height := 0.65 + float(i % 3) * 0.4
			shard.scale = Vector3(0.30, 0.01, 0.28)
			shard.rotation = Vector3(0.3, a, 0.3)
			shard.create_tween().tween_property(shard, "scale:y", height, 0.22 + float(i % 3) * 0.045).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _sphere_mesh() -> SphereMesh:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 16
		mesh.rings = 8
		_meshes["sphere"] = mesh
	return _meshes.sphere


static func _column_mesh() -> CylinderMesh:
	if not _meshes.has("column"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.7
		mesh.bottom_radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 12
		_meshes["column"] = mesh
	return _meshes.column


static func _halo_mesh() -> ArrayMesh:
	if not _meshes.has("halo"):
		var path := PackedVector3Array()
		for i in 49:
			var a := float(i) / 48.0 * TAU
			path.append(Vector3(sin(a), 0, cos(a)))
		_meshes["halo"] = _tube_mesh(path, 0.048)
	return _meshes.halo


static func _crystal_mesh() -> ArrayMesh:
	if not _meshes.has("crystal"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 6:
			var a := TAU * float(i) / 6.0
			var b := TAU * float(i + 1) / 6.0
			var p := Vector3(cos(a), 0.25, sin(a))
			var q := Vector3(cos(b), 0.25, sin(b))
			_tri(st, p, Vector3(0, 1, 0), q)
			_tri(st, q, Vector3(0, -0.35, 0), p)
		st.generate_normals()
		_meshes["crystal"] = st.commit()
	return _meshes.crystal


static func _blade_mesh(arrow: bool) -> ArrayMesh:
	var key := "arrow" if arrow else "blade"
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Ridged, tapered blade with a visible three-dimensional central spine.
		var base := 0.48 if arrow else 0.12
		var left := Vector3(-0.5, 0.66, 0)
		var right := Vector3(0.5, 0.66, 0)
		var tip := Vector3(0, 1, 0)
		var foot := Vector3(0, base, 0)
		for z in [-0.16, 0.16]:
			var spine := Vector3(0, 0.68, z)
			_tri(st, tip, left, spine)
			_tri(st, spine, right, tip)
			_tri(st, foot, spine, left)
			_tri(st, foot, right, spine)
		# Shaft and crossguard use intersecting prisms in the same mesh.
		_prism(st, Vector3(-0.045, 0, -0.045), Vector3(0.045, 0.65, 0.045))
		if not arrow:
			_prism(st, Vector3(-0.55, 0.14, -0.08), Vector3(0.55, 0.19, 0.08))
		else:
			_tri(st, Vector3(-0.3, 0.05, 0), Vector3(0, 0.25, 0), Vector3(0.3, 0.05, 0))
		st.generate_normals()
		_meshes[key] = st.commit()
	return _meshes[key]


static func _wing_mesh() -> ArrayMesh:
	if not _meshes.has("wings"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			for i in 7:
				var t := float(i) / 6.0
				var a := Vector3(side * (0.12 + t * 0.6), t * 0.31, 0.0)
				var b := Vector3(side * (0.45 + t * 0.52), 0.78 - t * 0.83, -0.12 - t * 0.15)
				var c := Vector3(side * (0.18 + t * 0.59), t * 0.31 - 0.11, 0.06)
				var ridge := (a + b + c) / 3.0 + Vector3(0, 0, 0.13)
				_tri(st, a, b, ridge)
				_tri(st, b, c, ridge)
				_tri(st, c, a, ridge)
				_tri(st, c, b, a)
		st.generate_normals()
		_meshes["wings"] = st.commit()
	return _meshes.wings


static func _slash_mesh(tier: int, stroke: int) -> ArrayMesh:
	var key := "slash:%d:%d" % [tier, stroke]
	if _tube_meshes.has(key):
		return _tube_meshes[key]
	var path := PackedVector3Array()
	var radius := 1.8 + tier * 0.26
	for j in 25:
		var t := float(j) / 24.0
		var a := -2.3 + t * 3.7 + float(stroke) * 0.4
		path.append(Vector3(sin(a) * radius, 0.3 + cos(a) * 0.22, cos(a) * radius))
	return _remember_tube(key, _tube_mesh(path, 0.10 + tier * 0.018, true))


static func _helix_mesh(radius: float, height: float, strands: int, strand: int) -> ArrayMesh:
	# Serialize the authored dimensions exactly: rounding a key would merge
	# distinct silhouettes. No colours or per-instance animation enter the key.
	var key := "helix:" + var_to_bytes([radius, height, strands, strand]).hex_encode()
	if _tube_meshes.has(key):
		return _tube_meshes[key]
	var points := PackedVector3Array()
	for j in 37:
		var t := float(j) / 36.0
		var a := t * TAU * 1.1 + float(strand) * TAU / float(strands)
		var r := radius * (0.25 + sin(t * PI) * 0.75)
		points.append(Vector3(cos(a) * r, t * height + 0.15, sin(a) * r))
	return _remember_tube(key, _tube_mesh(points, 0.085, true))


static func _dragon_mesh() -> ArrayMesh:
	if _tube_meshes.has("dragon"):
		return _tube_meshes.dragon
	var path := PackedVector3Array()
	for j in 49:
		var t := float(j) / 48.0
		var a := t * TAU * 1.3
		path.append(Vector3(sin(a) * (1.8 - t * 0.9), t * 5.0, cos(a) * (1.8 - t * 0.9)))
	return _remember_tube("dragon", _tube_mesh(path, 0.42, true))


static func _phoenix_tail_mesh() -> ArrayMesh:
	if _tube_meshes.has("phoenix_tail"):
		return _tube_meshes.phoenix_tail
	var path := PackedVector3Array([Vector3(0, 1.6, 0), Vector3(0, 0.8, -1.0), Vector3(0.5, 0.4, -2.4)])
	return _remember_tube("phoenix_tail", _tube_mesh(path, 0.15, true))


static func _remember_tube(key: String, mesh: ArrayMesh) -> ArrayMesh:
	if _tube_meshes.size() >= TUBE_CACHE_LIMIT:
		# Dropping the cache reference never invalidates a currently drawn mesh.
		_tube_meshes.erase(_tube_meshes.keys()[0])
	_tube_meshes[key] = mesh
	return mesh


static func _tube_mesh(points: PackedVector3Array, width: float, taper := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := points.size()
	var sides := 6
	for i in n - 1:
		var forward := (points[i + 1] - points[i]).normalized()
		var cross_axis := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		var side := forward.cross(cross_axis).normalized()
		var up := side.cross(forward).normalized()
		var t0 := float(i) / float(n - 1)
		var t1 := float(i + 1) / float(n - 1)
		var r0 := width * (maxf(0.025, sin(t0 * PI)) if taper else 1.0)
		var r1 := width * (maxf(0.025, sin(t1 * PI)) if taper else 1.0)
		for k in sides:
			var a := TAU * float(k) / sides
			var b := TAU * float(k + 1) / sides
			var va := side * cos(a) + up * sin(a)
			var vb := side * cos(b) + up * sin(b)
			var p0 := points[i] + va * r0
			var p1 := points[i] + vb * r0
			var p2 := points[i + 1] + va * r1
			var p3 := points[i + 1] + vb * r1
			_tri(st, p0, p1, p2)
			_tri(st, p2, p1, p3)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(0, a.y * 0.4))
	st.add_vertex(a)
	st.set_uv(Vector2(0.5, b.y * 0.4))
	st.add_vertex(b)
	st.set_uv(Vector2(1, c.y * 0.4))
	st.add_vertex(c)


static func _prism(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for face in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_tri(st, p[face[0]], p[face[1]], p[face[2]])
		_tri(st, p[face[0]], p[face[2]], p[face[3]])
