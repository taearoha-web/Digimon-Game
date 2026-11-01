class_name MountVisual
extends Node3D
## A ridden mount (MountData), modelled from MeshKit primitives in the toon style:
## shared unit meshes and cached materials, no lights or particles (glow is emission
## only). Faces +Z. [member body] carries everything above the legs and bobs; the
## rider's hips go on [member seat]. Idle: slow breathing bob, head and tail sway,
## wings beat softly. Running: the legs gallop, the body rocks, wings flap hard.

const RUN_RATE := 10.5
const FLAME_FLICKER := 17.0

var id := ""
## Everything above the legs (bobs and rocks).
var body: Node3D
## The rider's hip point (child of body).
var seat: Node3D
var head: Node3D
var tail: Node3D
var legs: Array[Node3D] = []
var _leg_phase: Array[float] = []
var _leg_swing: Array[float] = []
## [pivot, side (+1 = +X side), resting raise (rad)]
var _wings: Array = []
var _flames: Array[Node3D] = []
var _flame_scale: Array[Vector3] = []
var _t := 0.0
var _gait := 0.0
var _run := 0.0
var _moving := false
var _speed_scale := 1.0
var _wing_rest := 0.3
var _wing_amp := 0.6


static func _mat(color: Color, glow := 0.0) -> StandardMaterial3D:
	if glow > 0.0:
		return MeshKit.toon(color, {"emission": glow})
	return MeshKit.toon(color, {"rim": true})


static func _shine() -> StandardMaterial3D:
	return MeshKit.toon(Color.WHITE, {"unshaded": true})


func build(p_id: String) -> void:
	id = p_id if MountData.exists(p_id) else "thunder_wolf"
	name = "Mount_" + id
	for child in get_children():
		child.free()
	legs.clear()
	_leg_phase.clear()
	_leg_swing.clear()
	_wings.clear()
	_flames.clear()
	_flame_scale.clear()
	body = MeshKit.pivot(self, "Body")
	match id:
		"glow_stag": _build_stag()
		"griffin": _build_griffin()
		"fire_drake": _build_drake()
		_: _build_wolf()
	var shadow := MeshKit.blob_shadow(self, 0.7)
	shadow.scale = Vector3(1.6, 2.6, 1.0)


## Rider hip height above the ground right now (follows the bob).
func seat_height() -> float:
	return body.position.y + (body.basis * seat.position).y


func set_motion(moving: bool, speed_scale := 1.0) -> void:
	_moving = moving
	_speed_scale = clampf(speed_scale, 0.6, 1.6)


func is_running() -> bool:
	return _run > 0.5


func _process(delta: float) -> void:
	_t += delta
	_run = move_toward(_run, 1.0 if _moving else 0.0, delta * 4.0)
	_gait = fmod(_gait + delta * lerpf(1.2, RUN_RATE * _speed_scale, _run), TAU * 8.0)
	var idle := 1.0 - _run
	body.position.y = idle * sin(_t * 2.2) * 0.03 + _run * absf(sin(_gait)) * 0.1
	body.rotation.x = _run * sin(_gait + 0.8) * 0.06
	for i in legs.size():
		legs[i].rotation.x = sin(_gait + _leg_phase[i]) * _leg_swing[i] * _run
	if head != null:
		head.rotation.x = idle * sin(_t * 1.6) * 0.05 + _run * (sin(_gait * 2.0 + 0.6) * 0.07 - 0.06)
		head.rotation.y = idle * sin(_t * 0.45) * 0.14
	if tail != null:
		tail.rotation.y = idle * sin(_t * 2.3) * 0.28 + _run * sin(_gait) * 0.12
		tail.rotation.x = _run * (0.3 + sin(_gait * 2.0) * 0.12)
	if not _wings.is_empty():
		var beat := sin(_t * lerpf(2.4, 11.0, _run))
		var amp := lerpf(0.12, _wing_amp, _run)
		for w in _wings:
			(w[0] as Node3D).rotation.z = float(w[1]) * (float(w[2]) + amp * beat)
	for i in _flames.size():
		var k := 1.0 + 0.16 * sin(_t * FLAME_FLICKER + i * 1.7) + 0.08 * sin(_t * 31.0 + i)
		_flames[i].scale = Vector3(_flame_scale[i].x * (2.0 - k), _flame_scale[i].y * k, _flame_scale[i].z * (2.0 - k))


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------

## A swinging leg: a pivot at the hip; parts are added by the caller.
func _leg(pos: Vector3, phase: float, swing := 0.75) -> Node3D:
	var pivot := MeshKit.pivot(self, "Leg%d" % legs.size(), pos)
	legs.append(pivot)
	_leg_phase.append(phase)
	_leg_swing.append(swing)
	return pivot


## Big glossy toon eye: dark oval, two white highlights.
func _eye(parent: Node3D, pos: Vector3, size: float, iris := Color("241a33"), side := 1.0) -> void:
	MeshKit.part(parent, MeshKit.sphere(), _mat(Color.WHITE), pos - Vector3(0, 0, size * 0.08), Vector3(size * 1.12, size * 1.28, size * 0.55), Vector3(0, side * 18.0, 0))
	MeshKit.part(parent, MeshKit.sphere(), _mat(iris), pos + Vector3(0, -size * 0.04, size * 0.06), Vector3(size * 0.95, size * 1.12, size * 0.5), Vector3(0, side * 18.0, 0))
	MeshKit.part(parent, MeshKit.sphere_low(), _shine(), pos + Vector3(side * size * 0.18, size * 0.24, size * 0.3), Vector3.ONE * size * 0.36)
	MeshKit.part(parent, MeshKit.sphere_low(), _shine(), pos + Vector3(-side * size * 0.16, -size * 0.2, size * 0.3), Vector3.ONE * size * 0.17)


## Saddle: blanket, seat, gold trim, pommel and cantle; sets [member seat].
func _saddle(pos: Vector3, blanket: Color, leather: Color, trim: Color, width := 0.8) -> void:
	MeshKit.part(body, MeshKit.cylinder(), _mat(blanket), pos + Vector3(0, -0.07, 0), Vector3(width * 1.32, 0.05, width * 1.05))
	MeshKit.part(body, MeshKit.torus(), _mat(trim), pos + Vector3(0, -0.06, 0), Vector3(width * 1.34, 0.5, width * 1.07))
	MeshKit.part(body, MeshKit.cylinder(), _mat(leather), pos, Vector3(width * 0.86, 0.1, width * 0.98))
	MeshKit.part(body, MeshKit.torus(), _mat(trim), pos + Vector3(0, 0.04, 0), Vector3(width * 0.9, 0.6, width * 1.02))
	MeshKit.part(body, MeshKit.sphere(), _mat(leather), pos + Vector3(0, 0.1, width * 0.44), Vector3(width * 0.36, 0.22, 0.16))
	MeshKit.part(body, MeshKit.sphere_low(), _mat(trim), pos + Vector3(0, 0.2, width * 0.47), Vector3.ONE * 0.12)
	MeshKit.part(body, MeshKit.sphere(), _mat(leather), pos + Vector3(0, 0.1, -width * 0.46), Vector3(width * 0.7, 0.24, 0.16))
	# Stirrup straps down both flanks.
	for side in [-1.0, 1.0]:
		MeshKit.part(body, MeshKit.box(), _mat(leather.darkened(0.25)), pos + Vector3(side * width * 0.62, -0.3, 0.02), Vector3(0.05, 0.5, 0.1), Vector3(0, 0, side * 14.0))
		MeshKit.part(body, MeshKit.torus(), _mat(trim), pos + Vector3(side * width * 0.69, -0.58, 0.02), Vector3(0.2, 0.4, 0.2), Vector3(0, 0, 90))
	seat = MeshKit.pivot(body, "Seat", pos + Vector3(0, 0.06, 0))


# ---------------------------------------------------------------------------
# หมาป่าสายฟ้า: fluffy storm-blue wolf with glowing lightning marks
# ---------------------------------------------------------------------------

func _build_wolf() -> void:
	var fur := _mat(Color("5d74c4"))
	var fur_dark := _mat(Color("3f4f93"))
	var cream := _mat(Color("eef2ff"))
	var bolt := _mat(Color("ffe14d"), 1.6)
	var pink := _mat(Color("f4a8c6"))
	var dark := _mat(Color("252038"))
	MeshKit.part(body, MeshKit.sphere(), fur, Vector3(0, 0.95, -0.08), Vector3(0.95, 0.82, 1.55))
	MeshKit.part(body, MeshKit.sphere(), fur_dark, Vector3(0, 1.08, -0.2), Vector3(0.72, 0.6, 1.25))
	MeshKit.part(body, MeshKit.sphere(), cream, Vector3(0, 0.84, 0.5), Vector3(0.78, 0.74, 0.62))
	MeshKit.part(body, MeshKit.sphere(), fur, Vector3(0, 1.16, 0.5), Vector3(0.92, 0.72, 0.62))
	# Ruff tufts round the neck.
	for i in 5:
		var a := deg_to_rad(-70.0 + i * 35.0)
		MeshKit.part(body, MeshKit.cone(), fur, Vector3(sin(a) * 0.42, 1.0 + cos(a) * 0.3, 0.62), Vector3(0.2, 0.32, 0.2), Vector3(70, 0, -rad_to_deg(a)))
	# Lightning zigzags on both flanks and down the back.
	for side in [-1.0, 1.0]:
		var x: float = side * 0.45
		MeshKit.part(body, MeshKit.box(), bolt, Vector3(x, 1.05, -0.05), Vector3(0.05, 0.08, 0.36), Vector3(-30, 0, 0))
		MeshKit.part(body, MeshKit.box(), bolt, Vector3(x * 0.99, 0.95, -0.2), Vector3(0.05, 0.07, 0.28), Vector3(25, 0, 0))
		MeshKit.part(body, MeshKit.box(), bolt, Vector3(x * 0.96, 0.86, -0.35), Vector3(0.05, 0.07, 0.3), Vector3(-30, 0, 0))
	for i in 3:
		MeshKit.part(body, MeshKit.prism(), bolt, Vector3(0, 1.32 - i * 0.05, -0.55 - i * 0.2), Vector3(0.1, 0.2, 0.08), Vector3(-35, 0, 0))
	_saddle(Vector3(0, 1.36, -0.08), Color("2b3a78"), Color("c8423b"), Color("ffd24a"), 0.78)
	# Head.
	head = MeshKit.pivot(body, "Head", Vector3(0, 1.45, 0.86))
	MeshKit.part(head, MeshKit.sphere(), fur, Vector3.ZERO, Vector3(0.8, 0.72, 0.74))
	MeshKit.part(head, MeshKit.sphere(), cream, Vector3(0, -0.15, 0.2), Vector3(0.58, 0.4, 0.44))
	for side in [-1.0, 1.0]:
		MeshKit.part(head, MeshKit.cone(), fur, Vector3(side * 0.38, -0.12, -0.02), Vector3(0.22, 0.3, 0.22), Vector3(0, 0, side * 100.0))
		MeshKit.part(head, MeshKit.cone(), fur, Vector3(side * 0.25, 0.4, -0.06), Vector3(0.28, 0.46, 0.16), Vector3(-8, 0, -side * 16.0))
		MeshKit.part(head, MeshKit.cone(), pink, Vector3(side * 0.245, 0.37, 0.0), Vector3(0.15, 0.3, 0.05), Vector3(-8, 0, -side * 16.0))
		_eye(head, Vector3(side * 0.18, 0.06, 0.3), 0.16, Color("1e2b5c"), side)
	MeshKit.part(head, MeshKit.sphere(), cream, Vector3(0, -0.1, 0.38), Vector3(0.38, 0.28, 0.4))
	MeshKit.part(head, MeshKit.sphere(), dark, Vector3(0, -0.02, 0.57), Vector3(0.15, 0.1, 0.1))
	MeshKit.part(head, MeshKit.sphere_low(), _shine(), Vector3(0.03, 0.01, 0.62), Vector3(0.05, 0.03, 0.03))
	MeshKit.part(head, MeshKit.prism(), bolt, Vector3(0, 0.26, 0.31), Vector3(0.12, 0.16, 0.04), Vector3(-25, 0, 180))
	# Legs: gallop (front pair, then back pair).
	for spec in [[Vector3(0.3, 0.8, 0.52), 0.0], [Vector3(-0.3, 0.8, 0.52), 0.5], [Vector3(0.32, 0.82, -0.58), PI], [Vector3(-0.32, 0.82, -0.58), PI + 0.5]]:
		var leg := _leg(spec[0], spec[1])
		var back: bool = (spec[0] as Vector3).z < 0.0
		if back:
			MeshKit.part(leg, MeshKit.sphere(), fur, Vector3(0, -0.05, 0.0), Vector3(0.36, 0.58, 0.55))
		MeshKit.part(leg, MeshKit.capsule(), fur, Vector3(0, -0.35, 0), Vector3(0.25, 0.3, 0.25))
		MeshKit.part(leg, MeshKit.sphere(), cream, Vector3(0, -0.7, 0.05), Vector3(0.3, 0.2, 0.36))
	# Big fluffy tail with a cream tip.
	tail = MeshKit.pivot(body, "Tail", Vector3(0, 1.15, -0.78))
	MeshKit.part(tail, MeshKit.sphere(), fur, Vector3(0, 0.18, -0.25), Vector3(0.36, 0.36, 0.72), Vector3(-42, 0, 0))
	MeshKit.part(tail, MeshKit.sphere(), fur_dark, Vector3(0, 0.3, -0.38), Vector3(0.3, 0.3, 0.5), Vector3(-50, 0, 0))
	MeshKit.part(tail, MeshKit.sphere(), cream, Vector3(0, 0.48, -0.56), Vector3(0.26, 0.26, 0.34), Vector3(-55, 0, 0))


# ---------------------------------------------------------------------------
# กวางเรืองแสง: pale cream stag with glowing teal antlers and spots
# ---------------------------------------------------------------------------

func _build_stag() -> void:
	# Cream tones, not pure white: toon light clips near-white to a flat shape.
	var coat := _mat(Color("f0e2c4"))
	var shade := _mat(Color("cdb48c"))
	var white := _mat(Color("f8f0de"))
	var glow := _mat(Color("3fd8e6"), 1.1)
	var hoof := _mat(Color("6a5f96"))
	var pink := _mat(Color("f7b8d2"))
	MeshKit.part(body, MeshKit.sphere(), coat, Vector3(0, 1.18, -0.08), Vector3(0.8, 0.76, 1.5))
	MeshKit.part(body, MeshKit.sphere(), shade, Vector3(0, 1.3, -0.25), Vector3(0.62, 0.56, 1.15))
	MeshKit.part(body, MeshKit.sphere(), white, Vector3(0, 1.06, 0.12), Vector3(0.66, 0.56, 1.0))
	MeshKit.part(body, MeshKit.sphere(), coat, Vector3(0, 1.32, 0.52), Vector3(0.72, 0.82, 0.66))
	MeshKit.part(body, MeshKit.sphere(), white, Vector3(0, 1.3, 0.78), Vector3(0.42, 0.55, 0.3))
	MeshKit.part(body, MeshKit.capsule(), coat, Vector3(0, 1.72, 0.74), Vector3(0.36, 0.3, 0.36), Vector3(32, 0, 0))
	# Glowing spots down the back and flanks, and a crystal on the chest.
	for spot in [Vector3(0.3, 1.38, -0.5), Vector3(-0.3, 1.38, -0.5), Vector3(0.36, 1.22, -0.25), Vector3(-0.36, 1.22, -0.25),
			Vector3(0.22, 1.47, -0.75), Vector3(-0.22, 1.47, -0.75), Vector3(0.38, 1.12, -0.62), Vector3(-0.38, 1.12, -0.62)]:
		MeshKit.part(body, MeshKit.sphere_low(), glow, spot, Vector3(0.1, 0.1, 0.1))
	MeshKit.part(body, MeshKit.prism(), glow, Vector3(0, 1.32, 0.92), Vector3(0.14, 0.2, 0.08), Vector3(0, 0, 180))
	_saddle(Vector3(0, 1.58, -0.12), Color("2f8fa6"), Color("eaf6ff"), Color("8fe9ff"), 0.72)
	# Head with big ears and branching antlers.
	head = MeshKit.pivot(body, "Head", Vector3(0, 2.02, 0.92))
	MeshKit.part(head, MeshKit.sphere(), coat, Vector3.ZERO, Vector3(0.6, 0.58, 0.62))
	MeshKit.part(head, MeshKit.sphere(), white, Vector3(0, -0.12, 0.28), Vector3(0.36, 0.3, 0.4))
	MeshKit.part(head, MeshKit.sphere(), _mat(Color("4a3a6a")), Vector3(0, -0.06, 0.47), Vector3(0.13, 0.09, 0.08))
	for side in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.16, 0.06, 0.22), 0.14, Color("3a2a6e"), side)
		MeshKit.part(head, MeshKit.sphere(), coat, Vector3(side * 0.34, 0.1, -0.08), Vector3(0.36, 0.13, 0.19), Vector3(0, side * 10.0, side * 22.0))
		MeshKit.part(head, MeshKit.sphere(), pink, Vector3(side * 0.35, 0.11, -0.05), Vector3(0.26, 0.07, 0.12), Vector3(0, side * 10.0, side * 22.0))
		MeshKit.part(head, MeshKit.sphere_low(), pink, Vector3(side * 0.2, -0.08, 0.25), Vector3(0.1, 0.05, 0.05))
		# Antler: a beam leaning out and back, two tines, glowing tips.
		var antler := MeshKit.pivot(head, "Antler", Vector3(side * 0.14, 0.24, -0.04), Vector3(-18, 0, -side * 24.0))
		MeshKit.part(antler, MeshKit.cylinder(), glow, Vector3(0, 0.25, 0), Vector3(0.07, 0.5, 0.07))
		MeshKit.part(antler, MeshKit.cylinder(), glow, Vector3(side * 0.02, 0.62, -0.08), Vector3(0.06, 0.32, 0.06), Vector3(-25, 0, -side * 22.0))
		MeshKit.part(antler, MeshKit.cylinder(), glow, Vector3(0, 0.36, 0.1), Vector3(0.05, 0.26, 0.05), Vector3(55, 0, 0))
		MeshKit.part(antler, MeshKit.cylinder(), glow, Vector3(side * 0.12, 0.5, 0.0), Vector3(0.05, 0.22, 0.05), Vector3(0, 0, -side * 60.0))
		MeshKit.part(antler, MeshKit.sphere_low(), glow, Vector3(side * 0.08, 0.78, -0.15), Vector3.ONE * 0.09)
		MeshKit.part(antler, MeshKit.sphere_low(), glow, Vector3(0, 0.45, 0.2), Vector3.ONE * 0.08)
		MeshKit.part(antler, MeshKit.sphere_low(), glow, Vector3(side * 0.21, 0.55, 0.0), Vector3.ONE * 0.08)
	# Long slender legs with dark hooves.
	for spec in [[Vector3(0.25, 1.02, 0.5), 0.0], [Vector3(-0.25, 1.02, 0.5), 0.45], [Vector3(0.27, 1.05, -0.6), PI], [Vector3(-0.27, 1.05, -0.6), PI + 0.45]]:
		var leg := _leg(spec[0], spec[1], 0.7)
		if (spec[0] as Vector3).z < 0.0:
			MeshKit.part(leg, MeshKit.sphere(), coat, Vector3(0, -0.05, -0.02), Vector3(0.34, 0.6, 0.52))
		MeshKit.part(leg, MeshKit.capsule(), coat, Vector3(0, -0.32, 0), Vector3(0.2, 0.28, 0.2))
		MeshKit.part(leg, MeshKit.capsule(), white, Vector3(0, -0.72, 0), Vector3(0.14, 0.26, 0.14))
		MeshKit.part(leg, MeshKit.sphere_low(), glow, Vector3(0, -0.84, 0.0), Vector3(0.17, 0.06, 0.17))
		MeshKit.part(leg, MeshKit.cylinder(), hoof, Vector3(0, -0.97, 0.02), Vector3(0.17, 0.12, 0.2))
	tail = MeshKit.pivot(body, "Tail", Vector3(0, 1.36, -0.82))
	MeshKit.part(tail, MeshKit.sphere(), white, Vector3(0, 0.06, -0.1), Vector3(0.24, 0.3, 0.2), Vector3(-30, 0, 0))
	MeshKit.part(tail, MeshKit.sphere_low(), glow, Vector3(0, 0.18, -0.15), Vector3.ONE * 0.09)


# ---------------------------------------------------------------------------
# กริฟฟิน: ivory eagle head and wings on a golden lion body
# ---------------------------------------------------------------------------

func _build_griffin() -> void:
	var lion := _mat(Color("e9b65e"))
	var lion_dark := _mat(Color("c18a3c"))
	# Warm ivory with light-gold shading, not pure white: toon light clips near-white flat.
	var feather := _mat(Color("f2e2bf"))
	var feather_shade := _mat(Color("dcc08a"))
	var blue := _mat(Color("4f8fe0"))
	var gold := _mat(Color("ffd24a"))
	var beak := _mat(Color("ffb53d"))
	var talon := _mat(Color("f2c24f"))
	MeshKit.part(body, MeshKit.sphere(), lion, Vector3(0, 1.0, -0.3), Vector3(0.92, 0.8, 1.25))
	MeshKit.part(body, MeshKit.sphere(), feather, Vector3(0, 1.1, 0.36), Vector3(0.94, 0.92, 0.9))
	# Layered chest feathers.
	for row in 2:
		for i in 3:
			var x := (i - 1) * 0.24
			MeshKit.part(body, MeshKit.sphere(), feather if row == 0 else feather_shade, Vector3(x, 0.92 - row * 0.16, 0.72 - row * 0.06), Vector3(0.26, 0.3, 0.14), Vector3(-20, 0, 0))
	MeshKit.part(body, MeshKit.capsule(), feather_shade, Vector3(0, 1.45, 0.58), Vector3(0.48, 0.3, 0.46), Vector3(30, 0, 0))
	_saddle(Vector3(0, 1.5, -0.18), Color("244c9e"), Color("3f6fd1"), Color("ffd24a"), 0.78)
	# Eagle head: big eyes, hooked beak, blue-gold crest.
	head = MeshKit.pivot(body, "Head", Vector3(0, 1.78, 0.82))
	MeshKit.part(head, MeshKit.sphere(), feather, Vector3.ZERO, Vector3(0.68, 0.66, 0.7))
	MeshKit.part(head, MeshKit.cone(), beak, Vector3(0, -0.06, 0.4), Vector3(0.24, 0.34, 0.2), Vector3(102, 0, 0))
	MeshKit.part(head, MeshKit.sphere(), beak, Vector3(0, 0.0, 0.3), Vector3(0.26, 0.2, 0.22))
	MeshKit.part(head, MeshKit.sphere(), _mat(Color("e08a1e")), Vector3(0, -0.15, 0.33), Vector3(0.16, 0.08, 0.16))
	for side in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.2, 0.08, 0.24), 0.15, Color("2a1f12"), side)
		MeshKit.part(head, MeshKit.box(), gold, Vector3(side * 0.2, 0.22, 0.26), Vector3(0.18, 0.04, 0.06), Vector3(0, 0, side * -14.0))
	for i in 3:
		var tilt := -40.0 - i * 18.0
		MeshKit.part(head, MeshKit.cone(), blue if i != 1 else gold, Vector3((i - 1) * 0.12, 0.3 - i * 0.04, -0.18 - i * 0.05), Vector3(0.12, 0.42 - i * 0.06, 0.08), Vector3(tilt, 0, (i - 1) * -16.0))
	# Wings: ivory coverts, gold band, blue flight feathers.
	for side in [-1.0, 1.0]:
		var wing := MeshKit.pivot(body, "Wing", Vector3(side * 0.42, 1.38, 0.18))
		_wings.append([wing, side, 0.35])
		MeshKit.part(wing, MeshKit.sphere(), feather_shade, Vector3(side * 0.42, 0.04, -0.2), Vector3(0.95, 0.16, 0.6), Vector3(0, side * 18.0, 0))
		MeshKit.part(wing, MeshKit.sphere(), gold, Vector3(side * 0.62, 0.0, -0.36), Vector3(0.7, 0.1, 0.32), Vector3(0, side * 22.0, 0))
		for f in 4:
			var spread := 10.0 + f * 16.0
			var reach := 0.95 - f * 0.1
			var a := deg_to_rad(spread)
			MeshKit.part(wing, MeshKit.sphere(), blue if f % 2 == 0 else feather,
				Vector3(side * (0.3 + cos(a) * reach * 0.7), -0.03 - f * 0.01, -0.35 - sin(a) * reach * 0.55),
				Vector3(0.86, 0.07, 0.2), Vector3(0, side * spread, 0))
	# Front legs: feathered eagle legs with talons.
	for spec in [[Vector3(0.28, 0.88, 0.5), 0.0], [Vector3(-0.28, 0.88, 0.5), 0.5]]:
		var leg := _leg(spec[0], spec[1])
		MeshKit.part(leg, MeshKit.sphere(), feather_shade, Vector3(0, -0.08, 0), Vector3(0.34, 0.45, 0.38))
		MeshKit.part(leg, MeshKit.capsule(), talon, Vector3(0, -0.45, 0), Vector3(0.15, 0.24, 0.15))
		MeshKit.part(leg, MeshKit.sphere(), talon, Vector3(0, -0.76, 0.05), Vector3(0.24, 0.12, 0.26))
		for t in 3:
			MeshKit.part(leg, MeshKit.cone(), _mat(Color("4a3a2a")), Vector3((t - 1) * 0.08, -0.79, 0.2), Vector3(0.06, 0.16, 0.06), Vector3(95, (t - 1) * 18.0, 0))
	# Back legs: lion haunches and paws.
	for spec in [[Vector3(0.32, 0.84, -0.66), PI], [Vector3(-0.32, 0.84, -0.66), PI + 0.5]]:
		var leg := _leg(spec[0], spec[1])
		MeshKit.part(leg, MeshKit.sphere(), lion, Vector3(0, -0.05, 0), Vector3(0.38, 0.6, 0.56))
		MeshKit.part(leg, MeshKit.capsule(), lion, Vector3(0, -0.38, 0), Vector3(0.24, 0.28, 0.24))
		MeshKit.part(leg, MeshKit.sphere(), lion_dark, Vector3(0, -0.72, 0.05), Vector3(0.3, 0.2, 0.36))
	tail = MeshKit.pivot(body, "Tail", Vector3(0, 1.05, -0.95))
	MeshKit.part(tail, MeshKit.capsule(), lion, Vector3(0, 0.2, -0.24), Vector3(0.12, 0.28, 0.12), Vector3(-50, 0, 0))
	MeshKit.part(tail, MeshKit.sphere(), lion_dark, Vector3(0, 0.44, -0.46), Vector3(0.24, 0.3, 0.24))
	MeshKit.part(tail, MeshKit.cone(), blue, Vector3(0, 0.6, -0.56), Vector3(0.1, 0.24, 0.08), Vector3(-40, 0, 0))


# ---------------------------------------------------------------------------
# มังกรน้อยเพลิง: chubby ember dragon with a flaming tail tip
# ---------------------------------------------------------------------------

func _build_drake() -> void:
	var scale_mat := _mat(Color("ff6a3d"))
	var scale_dark := _mat(Color("d8442b"))
	var belly := _mat(Color("ffd99e"))
	var horn := _mat(Color("fff0c6"))
	var spike := _mat(Color("ffcf3a"))
	var membrane := _mat(Color("ffa25a"))
	var flame := _mat(Color("ffb12a"), 2.4)
	var core := _mat(Color("fff3a0"), 2.8)
	MeshKit.part(body, MeshKit.sphere(), scale_mat, Vector3(0, 1.0, -0.08), Vector3(1.02, 0.9, 1.5))
	MeshKit.part(body, MeshKit.sphere(), belly, Vector3(0, 0.88, 0.2), Vector3(0.82, 0.72, 1.06))
	for i in 3:
		MeshKit.part(body, MeshKit.torus(), _mat(Color("f2bf7c")), Vector3(0, 0.68 + i * 0.13, 0.48 + i * 0.07), Vector3(0.5 - i * 0.04, 0.3, 0.22), Vector3(70 - i * 12.0, 0, 0))
	MeshKit.part(body, MeshKit.capsule(), scale_mat, Vector3(0, 1.45, 0.66), Vector3(0.42, 0.32, 0.4), Vector3(38, 0, 0))
	MeshKit.part(body, MeshKit.capsule(), belly, Vector3(0, 1.38, 0.78), Vector3(0.28, 0.24, 0.26), Vector3(38, 0, 0))
	# Spikes down the spine behind the saddle.
	for i in 3:
		MeshKit.part(body, MeshKit.cone(), spike, Vector3(0, 1.38 - i * 0.1, -0.52 - i * 0.24), Vector3(0.16 - i * 0.02, 0.26 - i * 0.03, 0.16), Vector3(-30, 0, 0))
	_saddle(Vector3(0, 1.48, -0.1), Color("7a2a1c"), Color("4b2a20"), Color("ffcf3a"), 0.8)
	# Head: big eyes, round snout, swept-back horns, cheek frills.
	head = MeshKit.pivot(body, "Head", Vector3(0, 1.82, 0.96))
	MeshKit.part(head, MeshKit.sphere(), scale_mat, Vector3.ZERO, Vector3(0.8, 0.7, 0.76))
	MeshKit.part(head, MeshKit.sphere(), scale_mat, Vector3(0, -0.12, 0.36), Vector3(0.54, 0.38, 0.44))
	MeshKit.part(head, MeshKit.sphere(), belly, Vector3(0, -0.22, 0.32), Vector3(0.44, 0.18, 0.4))
	MeshKit.part(head, MeshKit.prism(), spike, Vector3(0, 0.36, -0.04), Vector3(0.1, 0.2, 0.08), Vector3(-25, 0, 0))
	for side in [-1.0, 1.0]:
		_eye(head, Vector3(side * 0.22, 0.08, 0.28), 0.18, Color("3a1406"), side)
		MeshKit.part(head, MeshKit.sphere_low(), _mat(Color("6e1d10")), Vector3(side * 0.1, -0.04, 0.58), Vector3(0.07, 0.05, 0.04))
		MeshKit.part(head, MeshKit.cone(), horn, Vector3(side * 0.22, 0.34, -0.16), Vector3(0.14, 0.42, 0.14), Vector3(-42, 0, -side * 14.0))
		MeshKit.part(head, MeshKit.cone(), spike, Vector3(side * 0.42, 0.02, -0.12), Vector3(0.1, 0.3, 0.06), Vector3(-20, 0, -side * 85.0))
		MeshKit.part(head, MeshKit.cone(), spike, Vector3(side * 0.4, -0.12, -0.08), Vector3(0.08, 0.22, 0.05), Vector3(-10, 0, -side * 110.0))
		MeshKit.part(head, MeshKit.sphere_low(), _mat(Color("ff9aa0")), Vector3(side * 0.28, -0.08, 0.3), Vector3(0.12, 0.06, 0.06))
	# Wings: arm bone, two finger bones, three membrane lobes.
	for side in [-1.0, 1.0]:
		var wing := MeshKit.pivot(body, "Wing", Vector3(side * 0.42, 1.45, 0.12))
		_wings.append([wing, side, 0.45])
		MeshKit.part(wing, MeshKit.capsule(), scale_dark, Vector3(side * 0.42, 0.12, 0), Vector3(0.12, 0.44, 0.12), Vector3(0, 0, -side * 72.0))
		MeshKit.part(wing, MeshKit.cone(), horn, Vector3(side * 0.86, 0.3, 0.02), Vector3(0.08, 0.18, 0.08), Vector3(0, 0, -side * 40.0))
		for f in 3:
			var a := 20.0 + f * 28.0
			var rad := deg_to_rad(a)
			var mid := Vector3(side * (0.45 + cos(rad) * 0.32), 0.12 - f * 0.02, -sin(rad) * 0.42)
			MeshKit.part(wing, MeshKit.sphere(), membrane if f != 1 else scale_mat, mid + Vector3(0, -0.01, 0.04), Vector3(0.78, 0.05, 0.42), Vector3(0, side * a, 0))
			MeshKit.part(wing, MeshKit.capsule(), scale_dark, mid + Vector3(side * 0.06, 0.02, -0.04), Vector3(0.06, 0.4, 0.06), Vector3(0, side * a, side * 90.0))
	# Short chubby legs with cream claws.
	for spec in [[Vector3(0.34, 0.74, 0.5), 0.0], [Vector3(-0.34, 0.74, 0.5), 0.5], [Vector3(0.36, 0.76, -0.56), PI], [Vector3(-0.36, 0.76, -0.56), PI + 0.5]]:
		var leg := _leg(spec[0], spec[1], 0.65)
		if (spec[0] as Vector3).z < 0.0:
			MeshKit.part(leg, MeshKit.sphere(), scale_mat, Vector3(0, -0.04, 0), Vector3(0.42, 0.56, 0.58))
		MeshKit.part(leg, MeshKit.capsule(), scale_mat, Vector3(0, -0.34, 0), Vector3(0.3, 0.26, 0.3))
		MeshKit.part(leg, MeshKit.sphere(), scale_dark, Vector3(0, -0.64, 0.06), Vector3(0.34, 0.2, 0.4))
		for t in 3:
			MeshKit.part(leg, MeshKit.sphere_low(), horn, Vector3((t - 1) * 0.1, -0.66, 0.25), Vector3(0.08, 0.08, 0.1))
	# Tail tapering back and curling up into a flame.
	tail = MeshKit.pivot(body, "Tail", Vector3(0, 0.98, -0.82))
	MeshKit.part(tail, MeshKit.sphere(), scale_mat, Vector3(0, -0.06, -0.22), Vector3(0.44, 0.42, 0.6), Vector3(10, 0, 0))
	MeshKit.part(tail, MeshKit.sphere(), scale_mat, Vector3(0, -0.12, -0.58), Vector3(0.3, 0.3, 0.5))
	MeshKit.part(tail, MeshKit.sphere(), scale_dark, Vector3(0, -0.04, -0.88), Vector3(0.2, 0.22, 0.36), Vector3(-25, 0, 0))
	MeshKit.part(tail, MeshKit.cone(), spike, Vector3(0, 0.1, -0.5), Vector3(0.12, 0.2, 0.12), Vector3(-30, 0, 0))
	var fire := MeshKit.pivot(tail, "Flame", Vector3(0, 0.08, -1.04))
	_flames.append(MeshKit.part(fire, MeshKit.sphere(), flame, Vector3(0, 0.1, 0), Vector3(0.28, 0.42, 0.28)))
	_flames.append(MeshKit.part(fire, MeshKit.cone(), flame, Vector3(0, 0.36, 0), Vector3(0.2, 0.36, 0.2)))
	_flames.append(MeshKit.part(fire, MeshKit.sphere(), core, Vector3(0, 0.12, 0.02), Vector3(0.15, 0.24, 0.15)))
	for f in _flames:
		_flame_scale.append(f.scale)
