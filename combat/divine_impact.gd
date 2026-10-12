class_name DivineImpact
extends Node3D
## Three shared draw surfaces per impact, no particles, dynamic lights or
## material duplication. Owner lifetime bounds each burst to half a second.
static var _gold: StandardMaterial3D
static var _pearl: StandardMaterial3D
var _age := 0.0
var _column: MeshInstance3D
var _ring: MeshInstance3D
var _petals: MultiMeshInstance3D
var _radius := 2.0

static func emit_at(parent: Node3D, point: Vector3, radius: float) -> void:
	var effect := DivineImpact.new()
	effect.position = point + Vector3(0, 0.07, 0)
	effect._radius = radius
	parent.add_child(effect)

func _ready() -> void:
	if _gold == null:
		_gold = MeshKit.toon(Color("f2c975"), {"unshaded":true})
		_pearl = MeshKit.toon(Color("fff2d9"), {"unshaded":true})
	_column = MeshInstance3D.new()
	_column.mesh = MeshKit.prism()
	_column.material_override = _pearl
	_column.position.y = 2.0
	_column.scale = Vector3(0.16, 4.0, 0.16)
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_column)
	_ring = MeshInstance3D.new()
	_ring.mesh = MeshKit.torus()
	_ring.material_override = _gold
	_ring.scale = Vector3(_radius, 0.045, _radius)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_petals = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = MeshKit.prism()
	multi.instance_count = 6
	_petals.multimesh = multi
	_petals.material_override = _gold
	_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_petals)

func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / 0.55, 0.0, 1.0)
	var taper := 1.0 - t
	_column.scale = Vector3(0.22 * taper, 4.0 * taper, 0.22 * taper)
	_ring.scale = Vector3(_radius * (0.55 + t * 0.5), 0.07 * taper, _radius * (0.55 + t * 0.5))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var at := Vector3(cos(a), 0, sin(a)) * _radius * (0.3 + t * 0.6)
		at.y = sin(t * PI) * 0.7
		var b := Basis(Vector3.UP, -a).scaled(Vector3(0.2 * taper, 0.65 * taper, 0.06 * taper))
		_petals.multimesh.set_instance_transform(i, Transform3D(b, at))
	if t >= 1.0: queue_free()
