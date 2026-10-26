class_name DarkHawk
extends Node3D
## The Dark Lord's hawk. It perches upright on the Lord's raised left forearm,
## wings folded, turning its head to watch the field, and on command (the hawk
## button on the HUD for the hero; always for an AI Lord in a fight) flies off to
## the Lord's target, or the nearest monster, and hunts it on its own: it circles
## on spread wings, banking, then folds its wings into a stoop, throws its talons
## forward and strikes, and climbs away to circle again. With nothing to fight, or
## called back, it flies home and flares its wings to land on the arm.
##
## The owner (Hero or Companion) provides:
##   visual: HeroVisual          (perch_point())
##   hawk_target() -> Mob        the monster to go for, or null
##   hawk_strike(mob)            one strike of the hawk (damage, credit, effects)
## Built from simple shapes in code, one material per colour: a dark brown back,
## a cream breast with brown streaks, amber eyes under a dark brow, a hooked beak,
## yellow feet with black talons, a banded tail and a gold band on one leg.

enum State { PERCH, FLY, RETURN }

const SIZE := 0.56
const SPEED := 13.0
const STRIKE_EVERY := 0.85
const LEASH := 22.0
## The colour of its strikes.
const STRIKE_COLOR := Color("ffb22e")

var owner_ref: WeakRef
var attack := false
var state := State.PERCH
var _target_ref: WeakRef
var _strike_timer := 0.0
var _dive := 0.0
var _orbit := 0.0
var _flap := 0.0
var _clock := 0.0
## Smoothed pose: 0 perched, 1 gliding; wings 0 folded, 1 spread; legs -1 tucked, 1 talons out.
var _pitch := -52.0
var _spread := 0.0
var _legs := 0.0
var _bank := 0.0
var _look := 0.0
var _body: Node3D
var _head: Node3D
var _tail: Node3D
var _wings: Array[Node3D] = []
var _hands: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _tail_feathers: Array[Node3D] = []
var _eyes: StandardMaterial3D


## Gives `owner_node` a hawk (once) and returns it.
static func ensure(owner_node: Node3D) -> DarkHawk:
	for child in owner_node.get_children():
		if child is DarkHawk:
			return child
	var hawk := DarkHawk.new()
	hawk.owner_ref = weakref(owner_node)
	hawk.name = "DarkHawk"
	owner_node.add_child(hawk)
	return hawk


## Takes the hawk away (another class).
static func remove(owner_node: Node3D) -> void:
	for child in owner_node.get_children():
		if child is DarkHawk:
			child.queue_free()


func _ready() -> void:
	top_level = true
	add_to_group("dark_hawks")
	_build()
	var lord := _lord()
	if lord != null:
		global_position = _perch(lord)


func _lord() -> Node3D:
	var lord := owner_ref.get_ref() as Node3D if owner_ref != null else null
	return lord if is_instance_valid(lord) and lord.is_inside_tree() else null


func _perch(lord: Node3D) -> Vector3:
	var visual: Variant = lord.get("visual")
	if visual is HeroVisual and is_instance_valid(visual):
		return (visual as HeroVisual).perch_point()
	return lord.global_position + Vector3(-0.35, 1.2, 0.25)


func _process(delta: float) -> void:
	_clock += delta
	var lord := _lord()
	if lord == null:
		return
	var dead: bool = lord.call("is_dead") if lord.has_method("is_dead") else false
	visible = not dead
	var target := _target_ref.get_ref() as Mob if _target_ref != null else null
	if target != null and (not is_instance_valid(target) or target.is_dead()):
		target = null
	match state:
		State.PERCH:
			global_position = _perch(lord)
			var body: Variant = lord.get("visual")
			var facing: Vector3 = (body as Node3D).global_basis.z if body is Node3D and is_instance_valid(body) else lord.global_basis.z
			look_at(global_position + Vector3(facing.x, 0, facing.z), Vector3.UP, true)
			_animate(delta, "perch")
			if attack and not dead:
				var next := lord.call("hawk_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					state = State.FLY
					_dive = 0.0
		State.FLY:
			if target == null:
				var next := lord.call("hawk_target") as Mob if attack else null
				if next != null:
					_target_ref = weakref(next)
					target = next
			if target == null or not attack or dead or target.global_position.distance_to(lord.global_position) > LEASH:
				state = State.RETURN
				_animate(delta, "flap")
			else:
				_fight(lord, target, delta)
		State.RETURN:
			var home := _perch(lord)
			_fly_to(home, delta, SPEED * 1.2)
			var near := global_position.distance_to(home)
			_animate(delta, "land" if near < 1.2 else "flap")
			if near < 0.25:
				state = State.PERCH


## Circles over the target on spread wings and stoops on it every STRIKE_EVERY seconds.
func _fight(lord: Node3D, target: Mob, delta: float) -> void:
	_strike_timer -= delta
	_orbit += delta * 2.4
	var center := target.global_position + Vector3(0, 1.0, 0)
	var goal := center + Vector3(cos(_orbit) * 1.6, 1.6, sin(_orbit) * 1.6)
	var mode := "glide"
	if _strike_timer <= 0.0:
		# The stoop: wings folded, straight at the target's body, talons out on contact.
		_dive += delta * 4.0
		goal = target.hit_point() if target.has_method("hit_point") else center
		mode = "strike" if global_position.distance_to(goal) < 1.0 else "stoop"
		if global_position.distance_to(goal) < 0.45 or _dive > 1.0:
			lord.call("hawk_strike", target)
			_strike_timer = STRIKE_EVERY
			_dive = 0.0
			VfxKit.sparks(target.get_parent() as Node3D, goal, STRIKE_COLOR, 8, 3.0, 0.4)
	_fly_to(goal, delta, SPEED * (1.5 if _strike_timer <= 0.0 else 0.8))
	_bank = lerpf(_bank, 28.0 if _strike_timer > 0.0 else 0.0, minf(1.0, delta * 4.0))
	_animate(delta, mode)


func _fly_to(goal: Vector3, delta: float, speed: float) -> void:
	var step := goal - global_position
	var move := step.limit_length(speed * delta)
	global_position += move
	if move.length_squared() > 0.000001:
		var flat := Vector3(move.x, move.y * 0.4, move.z)
		if flat.length_squared() > 0.000001 and absf(flat.normalized().dot(Vector3.UP)) < 0.98:
			look_at(global_position + flat, Vector3.UP, true)


## Poses the hawk for a moment of its flight: "perch", "glide", "flap", "stoop",
## "strike" or "land". Every part eases towards its pose, so changes blend.
func _animate(delta: float, mode: String) -> void:
	var blend := minf(1.0, delta * 8.0)
	var pitch := 0.0
	var spread := 1.0
	var legs := -1.0
	var flap_speed := 0.0
	var flap_amp := 0.0
	match mode:
		"perch":
			pitch = -52.0; spread = 0.0; legs = 0.0
		"glide":
			pitch = 4.0; spread = 1.0; legs = -1.0; flap_speed = 3.0; flap_amp = 0.12
		"flap":
			pitch = -6.0; spread = 1.0; legs = -1.0; flap_speed = 13.0; flap_amp = 0.85
		"stoop":
			pitch = 32.0; spread = 0.25; legs = -1.0
		"strike":
			pitch = -24.0; spread = 0.8; legs = 1.0; flap_speed = 16.0; flap_amp = 0.5
		"land":
			pitch = -40.0; spread = 1.0; legs = 1.0; flap_speed = 10.0; flap_amp = 0.6
	if mode != "glide":
		_bank = lerpf(_bank, 0.0, blend)
	_pitch = lerpf(_pitch, pitch, blend)
	_spread = lerpf(_spread, spread, blend)
	_legs = lerpf(_legs, legs, blend)
	_flap += delta * flap_speed
	var flap := sin(_flap) * flap_amp * _spread
	# _pitch is nose-down degrees: perched it sits upright, stooping it points down.
	_body.rotation_degrees = Vector3(_pitch, 0, _bank)
	# The head stays level and, perched, looks about now and then.
	var watch := 0.0
	if mode == "perch":
		watch = clampf(sin(_clock * 0.7) * 1.6 + sin(_clock * 1.9) * 0.6, -1.0, 1.0) * 55.0
	_look = lerpf(_look, watch, minf(1.0, delta * 5.0))
	_head.rotation_degrees = Vector3(-_pitch * 0.9, _look, -_bank * 0.5)
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		# Folded: along the flank, pointing back; spread: out to the side.
		var fold := 1.0 - _spread
		var breathe := sin(_clock * 1.6) * 0.03 * fold
		# Folding rolls the wing upright onto the flank (leading edge up), then swings
		# it back along the body: the flight feathers end at the tail.
		_wings[i].rotation = Vector3(-1.45 * fold, side * 1.38 * fold, side * (flap + 0.18 * _spread + breathe))
		_hands[i].rotation = Vector3(0, side * 0.12 * fold, side * (sin(_flap - 0.7) * flap_amp * 0.6 * _spread))
	for i in _tail_feathers.size():
		_tail_feathers[i].rotation.y = (float(i) - 2.0) * deg_to_rad(5.0 + 9.0 * _spread)
	_tail.rotation_degrees.x = 10.0 * (1.0 - _spread) - 6.0 * _spread
	# Legs hang straight down whatever the body's pitch; tucked back in flight,
	# thrown forward for a strike.
	for foot in _feet:
		foot.rotation_degrees.x = -_pitch + 70.0 * maxf(0.0, -_legs) - 75.0 * maxf(0.0, _legs)
	if _eyes:
		_eyes.emission_energy_multiplier = 1.8 if mode in ["stoop", "strike"] else 0.9


## A hawk of simple shapes, facing +Z, its feet at the origin: body, breast, head
## with beak and brows, two wings (a shoulder pivot and a hand pivot carrying the
## five flight feathers), a five-feather banded tail and two legs with talons.
func _build() -> void:
	var root := Node3D.new()
	root.name = "Hawk"
	root.scale = Vector3.ONE * SIZE
	add_child(root)
	var back := MeshKit.toon(Color("3b2416"))
	var mid := MeshKit.toon(Color("6e4526"))
	var edge := MeshKit.toon(Color("c48c4c"))
	var cream := MeshKit.toon(Color("f1e3c4"))
	var streak := MeshKit.toon(Color("8a5a30"))
	var dark := MeshKit.toon(Color("21160e"))
	var yellow := MeshKit.toon(Color("f2c230"))
	var beak := MeshKit.toon(Color("2e2a2a"))
	var gold := MeshKit.toon(Color("f0c058"), {"emission": 0.15})
	var jess := MeshKit.toon(Color("a01e30"))
	_eyes = (MeshKit.toon(Color("ffae1e"), {"emission": 0.9}) as StandardMaterial3D).duplicate()
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, 0.2, 0)
	root.add_child(_body)
	# Body and breast.
	_piece(_body, MeshKit.sphere_low(), back, Vector3(0, 0.02, 0), Vector3(0.3, 0.27, 0.56))
	_piece(_body, MeshKit.sphere_low(), cream, Vector3(0, -0.04, 0.08), Vector3(0.25, 0.24, 0.42))
	for k in 4:
		var row := float(k)
		for side in [-1.0, 1.0]:
			_piece(_body, MeshKit.sphere_low(), streak, Vector3(side * (0.045 + row * 0.006), -0.12 + row * 0.012, 0.19 - row * 0.07),
				Vector3(0.03, 0.012, 0.05), Vector3(0, side * 15.0, 0))
	# Head on a level-keeping pivot.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.1, 0.27)
	_body.add_child(_head)
	_piece(_head, MeshKit.sphere_low(), back, Vector3(0, 0.03, 0), Vector3(0.22, 0.21, 0.24))
	_piece(_head, MeshKit.sphere_low(), cream, Vector3(0, -0.035, 0.05), Vector3(0.17, 0.12, 0.16))
	# Brows over the eyes: the hawk's fierce look.
	for side in [-1.0, 1.0]:
		_piece(_head, MeshKit.box(), dark, Vector3(side * 0.07, 0.075, 0.07), Vector3(0.07, 0.022, 0.06), Vector3(0, 0, side * -18.0))
		_piece(_head, MeshKit.sphere_low(), _eyes, Vector3(side * 0.078, 0.04, 0.075), Vector3(0.05, 0.05, 0.045))
		_piece(_head, MeshKit.sphere_low(), dark, Vector3(side * 0.088, 0.04, 0.09), Vector3(0.024, 0.024, 0.02))
	# The hooked beak behind a yellow cere.
	_piece(_head, MeshKit.sphere_low(), yellow, Vector3(0, 0.02, 0.115), Vector3(0.07, 0.05, 0.05))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, 0.0, 0.16), Vector3(0.06, 0.1, 0.05), Vector3(110, 0, 0))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, -0.035, 0.195), Vector3(0.025, 0.05, 0.025), Vector3(180, 0, 0))
	# Wings.
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "Wing"
		wing.position = Vector3(side * 0.12, 0.08, 0.08)
		_body.add_child(wing)
		# Coverts over the arm, a light leading edge, secondaries trailing behind.
		_piece(wing, MeshKit.sphere_low(), mid, Vector3(side * 0.2, 0.0, -0.02), Vector3(0.42, 0.05, 0.2))
		_piece(wing, MeshKit.sphere_low(), edge, Vector3(side * 0.2, 0.012, 0.06), Vector3(0.38, 0.03, 0.05))
		for k in 6:
			_piece(wing, MeshKit.sphere_low(), back if k % 2 == 0 else mid, Vector3(side * (0.04 + k * 0.066), -0.008 - k * 0.001, -0.13),
				Vector3(0.12, 0.018, 0.27), Vector3(0, side * -6.0, 0))
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3(side * 0.4, 0, 0)
		wing.add_child(hand)
		_piece(hand, MeshKit.sphere_low(), mid, Vector3(side * 0.04, 0.0, -0.03), Vector3(0.16, 0.026, 0.19))
		# The five flight feathers, spread like fingers, pale at the tips.
		for k in 5:
			var ang: float = side * (-2.0 - k * 12.0)
			var feather := Node3D.new()
			feather.position = Vector3(side * 0.06, -0.004 * k, -0.01 - k * 0.03)
			feather.rotation_degrees = Vector3(0, ang, 0)
			hand.add_child(feather)
			var length := 0.36 - k * 0.035
			_piece(feather, MeshKit.sphere_low(), dark, Vector3(side * length * 0.5, 0, 0), Vector3(length, 0.016, 0.07))
			_piece(feather, MeshKit.sphere_low(), edge, Vector3(side * (length - 0.035), 0.002, 0), Vector3(0.06, 0.016, 0.05))
		_wings.append(wing)
		_hands.append(hand)
	# The tail: five long feathers with two cream bands.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.0, -0.24)
	_body.add_child(_tail)
	for k in 5:
		var feather := Node3D.new()
		_tail.add_child(feather)
		_piece(feather, MeshKit.box(), back, Vector3(0, -0.002 * absf(k - 2.0), -0.17), Vector3(0.07, 0.014, 0.34))
		for band in [-0.15, -0.27]:
			_piece(feather, MeshKit.box(), cream, Vector3(0, 0.001, band), Vector3(0.072, 0.015, 0.03))
		_tail_feathers.append(feather)
	# Legs: feathered thighs, yellow shanks, three toes forward and one back, black talons.
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.name = "Leg"
		foot.position = Vector3(side * 0.07, -0.08, 0.06)
		_body.add_child(foot)
		_piece(foot, MeshKit.sphere_low(), mid, Vector3(0, -0.02, 0), Vector3(0.1, 0.12, 0.1))
		_piece(foot, MeshKit.cylinder(), yellow, Vector3(0, -0.1, 0.0), Vector3(0.035, 0.1, 0.035))
		for k in 3:
			var toe := (float(k) - 1.0) * 25.0
			_piece(foot, MeshKit.box(), yellow, Vector3(sin(deg_to_rad(toe)) * 0.04, -0.15, cos(deg_to_rad(toe)) * 0.04),
				Vector3(0.022, 0.02, 0.08), Vector3(0, toe, 0))
			_piece(foot, MeshKit.cone(), dark, Vector3(sin(deg_to_rad(toe)) * 0.085, -0.16, cos(deg_to_rad(toe)) * 0.085),
				Vector3(0.018, 0.04, 0.018), Vector3(120, toe, 0))
		_piece(foot, MeshKit.box(), yellow, Vector3(0, -0.15, -0.035), Vector3(0.02, 0.02, 0.06))
		if side > 0.0:
			# A gold band and a crimson jess: the Lord's own bird.
			_piece(foot, MeshKit.cylinder(), gold, Vector3(0, -0.075, 0.0), Vector3(0.05, 0.022, 0.05))
			_piece(foot, MeshKit.box(), jess, Vector3(0.0, -0.12, -0.03), Vector3(0.018, 0.09, 0.008), Vector3(14, 0, 0))
		_feet.append(foot)
	_animate(1.0, "perch")


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
