class_name PumpkinHead
extends Node3D
## The Halloween potion's mark: a jack-o'-lantern the size of the head that floats 30 cm
## above it and turns slowly while the potion runs (the hero, a party member or a world
## player who drank one). Lives under a head-bone attachment (HeroVisual.set_pumpkin).

const SPIN_SPEED := 1.4
const BOB_HEIGHT := 0.08
const BOB_SPEED := 2.2
## Built at SIZE, then scaled to the head's width; GAP metres between head and pumpkin.
const SIZE := Vector3(1.25, 1.05, 1.25)
const GAP := 0.26

var _t := 0.0
var _body: Node3D
var _center := 0.0
var _bob := 0.0


## Under the head bone: head_top and head_width in metres (the top of the head above
## the bone, and its width), unit the bone space's metres per unit.
static func make(head_top: float, head_width: float, unit: float) -> PumpkinHead:
	var p := PumpkinHead.new()
	p.name = "PumpkinHead"
	var s := head_width / SIZE.x
	p._center = (head_top + GAP + SIZE.y * s * 0.5) / unit
	p._bob = BOB_HEIGHT / unit
	p._build(s / unit)
	return p


func _build(scale_by: float) -> void:
	_body = Node3D.new()
	_body.position = Vector3(0, _center, 0)
	_body.scale = Vector3.ONE * scale_by
	add_child(_body)
	var orange := Color("ff8a1f")
	# Ribs: overlapping squashed spheres around the centre.
	_part(MeshKit.sphere(), orange, Vector3.ZERO, SIZE)
	for k in 6:
		var a := TAU * float(k) / 6.0
		_part(MeshKit.sphere_low(), orange.darkened(0.08 if k % 2 == 0 else 0.0),
			Vector3(cos(a), 0, sin(a)) * SIZE.x * 0.22, Vector3(SIZE.x * 0.62, SIZE.y * 0.98, SIZE.z * 0.62))
	# Stem.
	_part(MeshKit.cylinder(), Color("4f7a28"), Vector3(0, SIZE.y * 0.52, 0), Vector3(0.14, 0.26, 0.14), Vector3(0, 0, 12))
	# Carved face, lit from inside.
	var glow := Color("ffd23a")
	for side in [-1.0, 1.0]:
		_part(MeshKit.prism(), glow, Vector3(side * 0.26, 0.14, SIZE.z * 0.47), Vector3(0.3, 0.28, 0.1), Vector3(0, 0, 0), 1.6)
	_part(MeshKit.prism(), glow, Vector3(0, -0.04, SIZE.z * 0.5), Vector3(0.14, 0.14, 0.08), Vector3(0, 0, 180), 1.6)
	for k in 5:
		var x := (float(k) - 2.0) * 0.15
		_part(MeshKit.prism(), glow, Vector3(x, -0.26 + (0.05 if k % 2 == 0 else 0.0), SIZE.z * 0.46),
			Vector3(0.16, 0.14, 0.1), Vector3(0, 0, 180.0 if k % 2 == 0 else 0.0), 1.6)


func _part(mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := 0.0) -> void:
	var opts := {}
	if glow > 0.0:
		opts["emission"] = glow
	var mi := MeshKit.part(_body, mesh, MeshKit.toon(color, opts), pos, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_t += delta
	_body.rotation.y = _t * SPIN_SPEED
	_body.position.y = _center + sin(_t * BOB_SPEED) * _bob
