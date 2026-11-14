class_name DragonMonsterArt
extends RefCounted
## The celestial dressing of the เกาะลอยฟ้าเทพมังกร bestiary (SkyIsleData): every dragon
## stands on a ring of light in its own colour ("aura") and wears the piece its "decor"
## names: a cushion of cloud (the whelp), horns of light (the drake, the elder), a
## dragon pearl with its orbit (the wyrmling, the shrine dragon), motes of gold (the kirin),
## shards of lightning (the wyvern). Elites add a crown. The Dragon God ("god") wears a
## crown of gold, a jade sun-halo with twelve rays behind its back, the great pearl
## before its chest and a double ring of light on a bank of cloud.
## Shared meshes and one material per colour (a finite cache); no lights, particles or
## per-frame scripts.

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func attach(visual: Node3D, template: Dictionary) -> void:
	if visual == null or not template.has("aura") or visual.has_meta("dragon_aura"):
		return
	visual.set_meta("dragon_aura", true)
	if visual is CelestialDragonVisual:
		_celestial(visual as CelestialDragonVisual, template)
		return
	if visual is KirinVisual:
		_kirin(visual as KirinVisual, template)
		return
	_repaint(visual, template)
	var color: Color = template.aura
	var boss := bool(template.get("boss", false))
	var elite := bool(template.get("elite", false))
	var decor := String(template.get("decor", ""))
	var hover := float(template.get("hover", 0.0))
	# The rig as it stands (its bind pose, scaled): where its feet, crown and chest are.
	var h := float(template.get("height", 2.0))
	var top := hover + h
	var front := h * 0.3
	var back := -h * 0.3
	var model: Node3D = visual.get("model") if "model" in visual else null
	if model != null:
		var box := MonsterVisual._bounds(model)
		var fit := model.scale.y
		if box.size.y * fit > 0.2:
			h = box.size.y * fit
			top = model.position.y + box.end.y * fit
			front = box.end.z * fit
			back = box.position.z * fit
	var foot := top - h
	# The FBX rigs' flying clips carry the body about a third of its height over its feet.
	var lift := h * 0.3 if String(template.get("model", "")).begins_with("dawn/") else 0.0
	var girth := float(template.get("height", 2.0))
	var root := Node3D.new()
	root.name = "DragonAura"
	visual.add_child(root)
	# The ring of light every dragon of the isle stands on.
	_add(root, "ring", _glow(color, 0.5), Vector3(0, 0.05, 0), Vector3.ONE * clampf(girth * 0.4, 0.7, 2.6))
	_add(root, "ring", _glow(color.lightened(0.4), 0.35), Vector3(0, 0.06, 0), Vector3.ONE * clampf(girth * 0.28, 0.5, 1.8))
	if (hover > 0.0 or decor == "cloud") and decor != "god":
		# Whoever flies rides a small bank of cloud.
		for i in 3:
			var a := TAU * float(i) / 3.0 + 0.4
			_add(root, "pearl", _solid(Color("fff6ea").lerp(color, 0.12)), Vector3(cos(a) * h * 0.2, maxf(foot * 0.45, 0.2) + lift, sin(a) * h * 0.2), Vector3(h * 0.42, h * 0.15, h * 0.36))
	match decor:
		"horns":
			_horns(root, color.lightened(0.3), h, top, front, 0.5)
		"pearl":
			_pearl(root, color, Vector3(0, top + h * 0.2, 0), h * 0.13)
		"antlers":
			_horns(root, Color("fff0c8"), h, top, front, 0.36)
			for side in [-1.0, 1.0]:
				_add(root, "spike", _glow(Color("fff0c8"), 0.9), Vector3(side * h * 0.16, top + h * 0.12, front * 0.62), Vector3(h * 0.03, h * 0.16, h * 0.03), Vector3(0.5, 0, -side * 1.1))
		"sparks":
			for i in 5:
				var a := TAU * float(i) / 5.0
				_add(root, "spike", _glow(Color("e9dcff"), 0.9), Vector3(cos(a) * h * 0.7, foot + h * (0.3 + 0.2 * float(i % 3)), sin(a) * h * 0.7),
					Vector3(h * 0.05, h * 0.36, h * 0.05), Vector3(0.9 * sin(a), a, 0.9 * cos(a)))
		"god":
			_god(root, color, template.get("halo", Color("7df0c4")), h, foot + lift, top + lift * 0.4, front, back)
	if elite:
		_crown(root, color, h, top, front, 5, 0.75)
	if boss and decor != "god":
		_crown(root, color, h, top, front, 7, 1.0)


## The eastern dragons (CelestialDragonVisual): horns, crown and mane are part of the
## dragon's own mesh (they move with its head), so the dressing here is what stays put:
## the ring of light, the cloud it rests on, the pearl it chases, the storm round the
## wyvern, the god's sun-halo behind his head and the motes round him.
static func _celestial(visual: CelestialDragonVisual, template: Dictionary) -> void:
	var color: Color = template.aura
	var decor := String(template.get("decor", ""))
	var h := visual.height
	var foot := float(template.get("hover", 0.0))
	var root := Node3D.new()
	root.name = "DragonAura"
	visual.add_child(root)
	var ring := clampf(h * 0.42, 0.8, 3.2)
	_add(root, "ring", _glow(color, 0.5), Vector3(0, 0.05, 0), Vector3.ONE * ring)
	_add(root, "ring", _glow(color.lightened(0.4), 0.35), Vector3(0, 0.06, 0), Vector3.ONE * ring * 0.7)
	# The cloud it coils on (flyers: under the lowest coil).
	var puffs := 5 if decor == "god" else 3
	var cloud := _solid(Color("fff8ee").lerp(color, 0.1))
	for i in puffs:
		var a := TAU * float(i) / float(puffs) + 0.4
		_add(root, "pearl", cloud, Vector3(cos(a) * h * 0.22, foot * 0.5 + h * 0.03, sin(a) * h * 0.2 - h * 0.04), Vector3(h * 0.4, h * 0.12, h * 0.34))
	var nose := visual.point("nose")
	var skull := visual.point("skull")
	match decor:
		"pearl", "cloud":
			# The pearl a dragon chases, held before its nose.
			_pearl(root, color, nose + Vector3(h * 0.24, -h * 0.3, h * 0.02), h * (0.07 if decor == "cloud" else 0.09))
		"sparks":
			for i in 5:
				var a := TAU * float(i) / 5.0
				_add(root, "spike", _glow(Color("fff2a0"), 0.9), Vector3(cos(a) * h * 0.62, foot + h * (0.3 + 0.18 * float(i % 3)), sin(a) * h * 0.62),
					Vector3(h * 0.04, h * 0.3, h * 0.04), Vector3(0.9 * sin(a), a, 0.9 * cos(a)))
		"horns":
			# Jade motes drifting round the old dragon.
			for i in 4:
				var a := TAU * float(i) / 4.0 + 0.5
				_add(root, "pearl", _glow(color.lightened(0.3), 0.8), Vector3(cos(a) * h * 0.55, h * (0.35 + 0.15 * float(i % 2)), sin(a) * h * 0.55), Vector3.ONE * h * 0.05)
		"god":
			_god_celestial(root, color, template.get("halo", Color("7df0c4")), h, skull, nose)


## The kirin (KirinVisual) carries its horn and the clouds under its hooves itself: here
## only its ring of light and a few motes of gold drifting round it.
static func _kirin(visual: KirinVisual, template: Dictionary) -> void:
	var color: Color = template.aura
	var h := visual.height
	var root := Node3D.new()
	root.name = "DragonAura"
	visual.add_child(root)
	var ring := clampf(h * 0.45, 0.8, 3.2)
	_add(root, "ring", _glow(color, 0.45), Vector3(0, 0.05, 0), Vector3.ONE * ring)
	_add(root, "ring", _glow(Color("ffe08a"), 0.35), Vector3(0, 0.06, 0), Vector3.ONE * ring * 0.7)
	var mote := _glow(Color("fff0b0"), 0.85)
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.7
		_add(root, "pearl", mote, Vector3(cos(a) * h * 0.5, h * (0.3 + 0.16 * float(i % 2)), sin(a) * h * 0.5), Vector3.ONE * h * 0.035)


## The Dragon God's sun-halo behind his head, the great pearl before him, motes round him.
static func _god_celestial(root: Node3D, color: Color, halo: Color, h: float, skull: Vector3, nose: Vector3) -> void:
	var gold := _solid(Color("ffd35a"))
	var bright := _glow(Color("fff2b0"), 0.9)
	_add(root, "ring", _glow(halo, 0.4), Vector3(0, 0.07, 0), Vector3.ONE * h * 0.75)
	var centre := Vector3(0, skull.y + h * 0.04, skull.z - h * 0.24)
	var radius := h * 0.3
	_add(root, "ring", gold, centre, Vector3.ONE * radius, Vector3(PI * 0.5, 0, 0))
	_add(root, "ring", _glow(halo, 0.6), centre, Vector3.ONE * radius * 0.84, Vector3(PI * 0.5, 0, 0))
	_add(root, "disc", _glow(halo, 0.08), centre + Vector3(0, 0, -0.02), Vector3.ONE * radius, Vector3(PI * 0.5, 0, 0))
	for i in 12:
		var a := TAU * float(i) / 12.0
		var long := i % 2 == 0
		var reach := radius * (1.0 + (0.34 if long else 0.22))
		_add(root, "spike", gold if long else bright, centre + Vector3(cos(a) * reach, sin(a) * reach, 0),
			Vector3(radius * 0.13, radius * (0.62 if long else 0.38), radius * 0.05), Vector3(0, 0, a - PI * 0.5))
	# The dragon pearl, burning before him in its two orbits.
	var pearl := Vector3(0, nose.y - h * 0.16, nose.z + h * 0.1)
	_pearl(root, color, pearl, h * 0.08)
	_add(root, "ring", _glow(halo, 0.8), pearl, Vector3.ONE * h * 0.14, Vector3(-0.6, 0.4, 0.9))
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		_add(root, "pearl", bright, Vector3(cos(a) * h * 0.62, h * (0.12 + 0.18 * float(i % 4)), sin(a) * h * 0.62), Vector3.ONE * h * 0.035)


## Repaints the rig's flat materials by name (template "paint": {material name: colour}),
## keeping the storybook finish and the ink outline MonsterVisual gave them.
static func _repaint(visual: Node3D, template: Dictionary) -> void:
	var paint: Dictionary = template.get("paint", {})
	if paint.is_empty():
		return
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if source == null or not paint.has(source.resource_name):
				continue
			var worn := mi.get_surface_override_material(i) as StandardMaterial3D
			if worn == null:
				worn = source
			var tone: Color = paint[source.resource_name]
			var key := "p%s|%s|%s|%s" % [String(template.get("model", "")), source.resource_name, tone.to_html(false), String(worn.get_meta("storybook_key", ""))]
			if not _materials.has(key):
				var painted := worn.duplicate() as StandardMaterial3D
				painted.albedo_color = tone
				_materials[key] = painted
			mi.set_surface_override_material(i, _materials[key])


static func _horns(root: Node3D, color: Color, h: float, top: float, front: float, spread: float) -> void:
	for side in [-1.0, 1.0]:
		_add(root, "spike", _glow(color, 0.9), Vector3(side * h * 0.12, top + h * 0.06, front * 0.55), Vector3(h * 0.06, h * 0.28, h * 0.06), Vector3(-0.5, 0, -side * spread))


static func _pearl(root: Node3D, color: Color, at: Vector3, size: float) -> void:
	_add(root, "pearl", _solid(Color("fff8e0")), at, Vector3.ONE * size)
	_add(root, "pearl", _glow(color, 0.55), at, Vector3.ONE * size * 1.7)
	_add(root, "ring", _glow(color.lightened(0.3), 0.8), at, Vector3.ONE * size * 1.5, Vector3(0.5, 0, 0.3))


static func _crown(root: Node3D, color: Color, h: float, top: float, front: float, points: int, size: float) -> void:
	for i in points:
		var a := TAU * float(i) / float(points)
		var s := h * (0.085 if i % 2 == 0 else 0.062) * size
		_add(root, "spike", _glow(color.lightened(0.25), 0.85), Vector3(cos(a) * h * 0.17, top + h * 0.05, front * 0.45 + sin(a) * h * 0.17), Vector3(s, s * 2.6, s),
			Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35))


## The Dragon God's regalia.
static func _god(root: Node3D, color: Color, halo: Color, h: float, foot: float, top: float, front: float, back: float) -> void:
	var gold := _solid(Color("ffd35a"))
	var bright := _glow(Color("fff2b0"), 0.9)
	# A wide outer ring on the ground and a bank of cloud under the hovering god.
	_add(root, "ring", _glow(halo, 0.4), Vector3(0, 0.07, 0), Vector3.ONE * h * 0.8)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_add(root, "pearl", _solid(Color("fff6ea")), Vector3(cos(a) * h * 0.2, foot - h * 0.08, sin(a) * h * 0.2 - h * 0.05), Vector3(h * 0.34, h * 0.11, h * 0.3))
	# The sun-halo stands behind the back: a gold rim, a jade inner ring, twelve rays.
	var centre := Vector3(0, foot + h * 0.66, back * 0.55)
	var radius := h * 0.5
	_add(root, "ring", gold, centre, Vector3.ONE * radius, Vector3(PI * 0.5, 0, 0))
	_add(root, "ring", _glow(halo, 0.6), centre, Vector3.ONE * radius * 0.86, Vector3(PI * 0.5, 0, 0))
	_add(root, "disc", _glow(halo, 0.07), centre + Vector3(0, 0, -0.02), Vector3.ONE * radius, Vector3(PI * 0.5, 0, 0))
	for i in 12:
		var a := TAU * float(i) / 12.0
		var long := i % 2 == 0
		var reach := radius * (1.0 + (0.34 if long else 0.22))
		_add(root, "spike", gold if long else bright, centre + Vector3(cos(a) * reach, sin(a) * reach, 0),
			Vector3(radius * 0.13, radius * (0.66 if long else 0.4), radius * 0.05), Vector3(0, 0, a - PI * 0.5))
	# The crown: five gold points with a jade jewel.
	for i in 5:
		var a := PI * (0.15 + 0.175 * float(i))
		var tall := h * (0.26 if i == 2 else (0.2 if i % 2 == 1 else 0.15))
		_add(root, "spike", gold, Vector3(cos(a) * h * 0.14, top - h * 0.02 + tall * 0.5, front * 0.42), Vector3(h * 0.055, tall, h * 0.055), Vector3(0, 0, (a - PI * 0.5) * 0.5))
	_add(root, "pearl", _glow(halo, 0.95), Vector3(0, top + h * 0.02, front * 0.5), Vector3.ONE * h * 0.06)
	# The dragon pearl burns before the chest, in its two orbits.
	var pearl := Vector3(0, foot + h * 0.42, front + h * 0.16)
	_pearl(root, color, pearl, h * 0.11)
	_add(root, "ring", _glow(halo, 0.8), pearl, Vector3.ONE * h * 0.2, Vector3(-0.6, 0.4, 0.9))
	# Motes of light rise round the god.
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		_add(root, "pearl", bright, Vector3(cos(a) * h * 0.8, foot + h * (0.15 + 0.2 * float(i % 4)), sin(a) * h * 0.8), Vector3.ONE * h * 0.045)


static func _add(root: Node3D, kind: String, material: Material, at: Vector3, size: Vector3, turn := Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _mesh(kind)
	node.material_override = material
	node.position = at
	node.scale = size
	node.rotation = turn
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		"ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.88
			torus.outer_radius = 1.0
			torus.rings = 28
			torus.ring_segments = 5
			mesh = torus
		"pearl":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 10
			sphere.rings = 5
			mesh = sphere
		"disc":
			var disc := CylinderMesh.new()
			disc.top_radius = 1.0
			disc.bottom_radius = 1.0
			disc.height = 0.01
			disc.radial_segments = 24
			disc.rings = 1
			mesh = disc
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


## An additive glow of one colour.
static func _glow(color: Color, alpha: float) -> Material:
	var key := "g%s|%.2f" % [color.to_html(false), alpha]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(color, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = m
	return _materials[key]


## Solid gold, cloud or pearl: opaque, lit a little by itself.
static func _solid(color: Color) -> Material:
	var key := "s" + color.to_html(false)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.55
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.35
		_materials[key] = m
	return _materials[key]
