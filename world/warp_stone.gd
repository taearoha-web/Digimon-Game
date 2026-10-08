class_name WarpStone
extends Npc
## A warp crystal on a stone plinth. Talking to it opens the warp list: back to
## the village or straight to any field the hero's level allows.

var _crystal: Node3D
var _rings: Array[MeshInstance3D] = []
var _t := 0.0


func setup(p_role: String, p_name: String, _p_class: StringName, p_title := "", _p_model := "") -> void:
	role = p_role
	display_name = p_name
	var color := Color("61b8ad")
	MeshKit.part(self, MeshKit.cylinder(), MeshKit.toon(Color("8a90a8")), Vector3(0, 0.25, 0), Vector3(2.6, 0.5, 2.6))
	MeshKit.part(self, MeshKit.cylinder(), MeshKit.toon(Color("a8aec8")), Vector3(0, 0.6, 0), Vector3(1.9, 0.25, 1.9))
	var pad := MeshInstance3D.new()
	pad.mesh = MeshKit.cylinder()
	pad.material_override = WorldArt._mat(color.darkened(0.18), 0.06)
	pad.scale = Vector3(1.7, 0.03, 1.7)
	pad.position = Vector3(0, 0.74, 0)
	add_child(pad)
	for i in 4:
		var angle := i * TAU / 4.0 + PI * 0.25
		MeshKit.part(self, MeshKit.box(), MeshKit.toon(Color("6a7090")), Vector3(cos(angle) * 1.05, 1.1, sin(angle) * 1.05),
				Vector3(0.28, 1.4, 0.28), Vector3(0, -rad_to_deg(angle), 0))
		MeshKit.part(self, MeshKit.sphere_low(), MeshKit.toon(color, {"emission": 0.08}), Vector3(cos(angle) * 1.05, 1.9, sin(angle) * 1.05), Vector3.ONE * 0.2)
	_crystal = Node3D.new()
	_crystal.position = Vector3(0, 2.3, 0)
	add_child(_crystal)
	MeshKit.part(_crystal, MeshKit.cone(), WorldArt._mat(color, 0.12), Vector3(0, 0.12, 0), Vector3(0.85, 1.25, 0.85))
	MeshKit.part(_crystal, MeshKit.cone(), WorldArt._mat(color.darkened(0.12), 0.08), Vector3(0, -0.65, 0), Vector3(0.85, 0.3, 0.85), Vector3(180, 0, 0))
	for i in 2:
		var ring := MeshInstance3D.new()
		ring.mesh = MeshKit.torus()
		ring.material_override = WorldArt._mat(color.lightened(0.12), 0.04)
		var s := 1.15 - float(i) * 0.3
		ring.scale = Vector3(s, s, s)
		ring.position = Vector3(0, 2.3 + (i - 0.5) * 0.4, 0)
		ring.rotation_degrees = Vector3(80 + i * 12, 0, 0)
		add_child(ring)
		_rings.append(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.18
	light.omni_range = 3.8
	light.position = Vector3(0, 2.3, 0)
	add_child(light)
	for entry in [[p_name, 4.5, 54, Color("d8f6ff")], [p_title, 3.95, 38, Color("9fd8ff")]]:
		if String(entry[0]) == "":
			continue
		var label := Label3D.new()
		label.text = String(entry[0])
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.0052
		label.font_size = int(entry[2]) - 8
		label.outline_size = 9
		label.modulate = entry[3]
		label.position = Vector3(0, float(entry[1]), 0)
		label.visibility_range_begin = 3.5
		label.visibility_range_end = 22.0
		label.no_depth_test = false
		add_child(label)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 1.6
	shape.shape = cyl
	shape.position = Vector3(0, 0.8, 0)
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta
	if _crystal:
		_crystal.rotation.y += delta * 1.2
		_crystal.position.y = 2.3 + sin(_t * 1.6) * 0.15
	for i in _rings.size():
		_rings[i].rotation.y += delta * (0.9 if i == 0 else -1.3)


func face(_point: Vector3) -> void:
	pass
