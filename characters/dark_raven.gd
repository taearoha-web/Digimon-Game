class_name DarkRaven
extends Node3D
## The Dark Lord's raven. It perches upright on the Lord's raised left forearm,
## wings folded, turning its head to watch the field, and on command (the raven
## button on the HUD for the hero; always for an AI Lord in a fight) flies off and
## hunts on its own: it circles on spread wings, banking, folds them into a stoop,
## throws its talons forward and strikes (LordSkillArt.raven_peck), then climbs
## away to circle again. With nothing to fight, or called back, it flies home and
## flares its wings to land on the arm.
##
## Three ways to hunt (the mode button on the HUD, remembered with the character):
##   SINGLE (เดี่ยว)  the Lord's own target, one hard strike at a time
##   GROUP (หมู่)     the Lord's own target, every strike tearing into all the
##                    monsters around it
##   AUTO (ออโต้)     picks its own prey (the nearest monster) and strikes the
##                    pack when three or more stand together, else one alone
##
## The owner (Hero or Companion) provides:
##   visual: HeroVisual                (perch_point())
##   raven_target() -> Mob             the monster to go for (by mode), or null
##   raven_strike(mob, group)          one strike (damage, credit)
## Built from simple shapes in code, one material per colour: blue-black plumage
## with a violet sheen, glowing red eyes under dark brows, a heavy black beak,
## shaggy throat feathers, a wedge-shaped tail, dark feet with black talons and a
## gold band and crimson jess on one leg.

enum State { PERCH, FLY, RETURN }
enum Mode { SINGLE, GROUP, AUTO }

const MODE_NAMES := ["เดี่ยว", "หมู่", "ออโต้"]
const SIZE := 0.56
const SPEED := 13.0
const STRIKE_EVERY := 0.85
const LEASH := 22.0
## A group strike reaches every monster this close to the one it dives on.
const GROUP_RADIUS := 3.2
const VIOLET := Color("8a4dff")

var owner_ref: WeakRef
var attack := false
var mode := Mode.AUTO
var state := State.PERCH
var _target_ref: WeakRef
var _strike_timer := 0.0
var _retarget := 0.0
var _dive := 0.0
var _orbit := 0.0
var _flap := 0.0
var _clock := 0.0
## Smoothed pose: pitch (nose-down degrees), wings 0 folded..1 spread, legs -1 tucked..1 talons out.
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


## Gives `owner_node` a raven (once) and returns it.
static func ensure(owner_node: Node3D) -> DarkRaven:
	for child in owner_node.get_children():
		if child is DarkRaven:
			return child
	var raven := DarkRaven.new()
	raven.owner_ref = weakref(owner_node)
	raven.name = "DarkRaven"
	owner_node.add_child(raven)
	return raven


## Takes the raven away (another class).
static func remove(owner_node: Node3D) -> void:
	for child in owner_node.get_children():
		if child is DarkRaven:
			child.queue_free()


## Live monsters within [param radius] of [param at] (the pack a group strike reaches).
static func pack(tree: SceneTree, at: Vector3, radius: float) -> Array[Mob]:
	var out: Array[Mob] = []
	for node in tree.get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob and is_instance_valid(mob) and not mob.is_dead() and mob.hostile:
			var d := mob.global_position - at
			if Vector2(d.x, d.z).length() <= radius:
				out.append(mob)
	return out


func _ready() -> void:
	top_level = true
	add_to_group("dark_ravens")
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


## True when this strike should tear into the pack rather than one monster.
func strikes_pack(target: Mob) -> bool:
	match mode:
		Mode.GROUP:
			return true
		Mode.AUTO:
			return is_inside_tree() and DarkRaven.pack(get_tree(), target.global_position, GROUP_RADIUS).size() >= 3
	return false


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
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					state = State.FLY
					_dive = 0.0
		State.FLY:
			# Follow the Lord's choice: a new target (single, group) or new prey (auto).
			_retarget -= delta
			if attack and (target == null or _retarget <= 0.0) and _strike_timer > 0.0:
				_retarget = 0.3
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					target = next
			if target == null and attack:
				var next := lord.call("raven_target") as Mob
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
	var pose := "glide"
	if _strike_timer <= 0.0:
		# The stoop: wings folded, straight at the target's body, talons out on contact.
		_dive += delta * 4.0
		goal = target.hit_point() if target.has_method("hit_point") else center
		pose = "strike" if global_position.distance_to(goal) < 1.0 else "stoop"
		if global_position.distance_to(goal) < 0.45 or _dive > 1.0:
			var group := strikes_pack(target)
			var from := global_position
			lord.call("raven_strike", target, group)
			_strike_timer = STRIKE_EVERY
			_dive = 0.0
			_retarget = 0.0
			LordSkillArt.raven_peck(target.get_parent() as Node3D, goal, from, group)
	_fly_to(goal, delta, SPEED * (1.5 if _strike_timer <= 0.0 else 0.8))
	_bank = lerpf(_bank, 28.0 if _strike_timer > 0.0 else 0.0, minf(1.0, delta * 4.0))
	_animate(delta, pose)


func _fly_to(goal: Vector3, delta: float, speed: float) -> void:
	var step := goal - global_position
	var move := step.limit_length(speed * delta)
	global_position += move
	if move.length_squared() > 0.000001:
		var flat := Vector3(move.x, move.y * 0.4, move.z)
		if flat.length_squared() > 0.000001 and absf(flat.normalized().dot(Vector3.UP)) < 0.98:
			look_at(global_position + flat, Vector3.UP, true)


## Poses the raven for a moment of its flight: "perch", "glide", "flap", "stoop",
## "strike" or "land". Every part eases towards its pose, so changes blend.
func _animate(delta: float, pose: String) -> void:
	var blend := minf(1.0, delta * 8.0)
	var pitch := 0.0
	var spread := 1.0
	var legs := -1.0
	var flap_speed := 0.0
	var flap_amp := 0.0
	match pose:
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
	if pose != "glide":
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
	if pose == "perch":
		watch = clampf(sin(_clock * 0.7) * 1.6 + sin(_clock * 1.9) * 0.6, -1.0, 1.0) * 55.0
	_look = lerpf(_look, watch, minf(1.0, delta * 5.0))
	_head.rotation_degrees = Vector3(-_pitch * 0.9, _look, -_bank * 0.5)
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var fold := 1.0 - _spread
		var breathe := sin(_clock * 1.6) * 0.03 * fold
		# Folding rolls the wing upright onto the flank (leading edge up), then swings
		# it back along the body: the flight feathers end at the tail.
		_wings[i].rotation = Vector3(-1.45 * fold, side * 1.38 * fold, side * (flap + 0.18 * _spread + breathe))
		_hands[i].rotation = Vector3(0, side * 0.12 * fold, side * (sin(_flap - 0.7) * flap_amp * 0.6 * _spread))
	for i in _tail_feathers.size():
		_tail_feathers[i].rotation.y = (float(i) - 2.0) * deg_to_rad(4.0 + 8.0 * _spread)
	_tail.rotation_degrees.x = 10.0 * (1.0 - _spread) - 6.0 * _spread
	# Legs hang straight down whatever the body's pitch; tucked back in flight,
	# thrown forward for a strike.
	for foot in _feet:
		foot.rotation_degrees.x = -_pitch + 70.0 * maxf(0.0, -_legs) - 75.0 * maxf(0.0, _legs)
	if _eyes:
		_eyes.emission_energy_multiplier = 2.6 if pose in ["stoop", "strike"] else 1.3


## A raven of simple shapes, facing +Z, its feet at the origin: body, head with a
## heavy beak, brows and throat hackles, two wings (a shoulder pivot and a hand
## pivot carrying the five fingered flight feathers), a wedge tail and two legs.
func _build() -> void:
	var root := Node3D.new()
	root.name = "Raven"
	root.scale = Vector3.ONE * SIZE
	add_child(root)
	var black := MeshKit.toon(Color("16111c"))
	var sheen := MeshKit.toon(Color("2c2244"))
	var edge := MeshKit.toon(Color("5a43a0"))
	var dark := MeshKit.toon(Color("0b080e"))
	var beak := MeshKit.toon(Color("1f1d24"))
	var feet := MeshKit.toon(Color("2a2630"))
	var gold := MeshKit.toon(Color("f0c058"), {"emission": 0.15})
	var jess := MeshKit.toon(Color("a01e30"))
	var tip := MeshKit.toon(Color("3d2d6e"))
	_eyes = (MeshKit.toon(Color("ff3a3a"), {"emission": 1.3}) as StandardMaterial3D).duplicate()
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0, 0.2, 0)
	root.add_child(_body)
	# Body, a sheen on the back and a deep breast.
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, 0.02, 0), Vector3(0.3, 0.27, 0.56))
	_piece(_body, MeshKit.sphere_low(), sheen, Vector3(0, 0.08, -0.04), Vector3(0.24, 0.16, 0.44))
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, -0.04, 0.09), Vector3(0.25, 0.24, 0.4))
	# Head on a level-keeping pivot.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 0.1, 0.27)
	_body.add_child(_head)
	_piece(_head, MeshKit.sphere_low(), black, Vector3(0, 0.03, 0), Vector3(0.22, 0.21, 0.25))
	_piece(_head, MeshKit.sphere_low(), sheen, Vector3(0, 0.08, -0.02), Vector3(0.15, 0.08, 0.18))
	# Shaggy throat hackles under the beak.
	for k in 3:
		_piece(_head, MeshKit.cone(), black, Vector3((float(k) - 1.0) * 0.04, -0.07, 0.07), Vector3(0.05, 0.08, 0.04), Vector3(160, 0, (float(k) - 1.0) * 12.0))
	# Brows over glowing red eyes.
	for side in [-1.0, 1.0]:
		_piece(_head, MeshKit.box(), dark, Vector3(side * 0.07, 0.075, 0.075), Vector3(0.07, 0.022, 0.06), Vector3(0, 0, side * -18.0))
		_piece(_head, MeshKit.sphere_low(), _eyes, Vector3(side * 0.078, 0.04, 0.08), Vector3(0.045, 0.045, 0.04))
	# The heavy beak: a thick base, a long ridge curving down to the tip, a lower mandible.
	_piece(_head, MeshKit.sphere_low(), beak, Vector3(0, 0.01, 0.12), Vector3(0.085, 0.075, 0.08))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, 0.012, 0.19), Vector3(0.07, 0.15, 0.06), Vector3(96, 0, 0))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, -0.018, 0.17), Vector3(0.05, 0.1, 0.04), Vector3(84, 0, 0))
	_piece(_head, MeshKit.cone(), beak, Vector3(0, -0.006, 0.262), Vector3(0.025, 0.035, 0.02), Vector3(150, 0, 0))
	# Wings.
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "Wing"
		wing.position = Vector3(side * 0.12, 0.08, 0.08)
		_body.add_child(wing)
		# Coverts over the arm, a violet-sheened leading edge, secondaries trailing behind.
		_piece(wing, MeshKit.sphere_low(), sheen, Vector3(side * 0.2, 0.0, -0.02), Vector3(0.42, 0.05, 0.2))
		_piece(wing, MeshKit.sphere_low(), edge, Vector3(side * 0.2, 0.012, 0.06), Vector3(0.38, 0.03, 0.05))
		for k in 6:
			_piece(wing, MeshKit.sphere_low(), black if k % 2 == 0 else sheen, Vector3(side * (0.04 + k * 0.066), -0.008 - k * 0.001, -0.13),
				Vector3(0.12, 0.018, 0.27), Vector3(0, side * -6.0, 0))
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3(side * 0.4, 0, 0)
		wing.add_child(hand)
		_piece(hand, MeshKit.sphere_low(), sheen, Vector3(side * 0.04, 0.0, -0.03), Vector3(0.16, 0.026, 0.19))
		# The five fingered flight feathers, a violet sheen towards the tips.
		for k in 5:
			var ang: float = side * (4.0 - k * 15.0)
			var feather := Node3D.new()
			feather.position = Vector3(side * 0.05, -0.004 * k, -0.01 - k * 0.035)
			feather.rotation_degrees = Vector3(0, ang, 0)
			hand.add_child(feather)
			var length := 0.42 - k * 0.04
			_piece(feather, MeshKit.sphere_low(), dark if k % 2 == 0 else black, Vector3(side * length * 0.5, 0, 0), Vector3(length, 0.016, 0.105))
			_piece(feather, MeshKit.sphere_low(), tip, Vector3(side * (length - 0.07), 0.003, 0), Vector3(0.12, 0.017, 0.08))
		_wings.append(wing)
		_hands.append(hand)
	# The wedge tail: the middle feathers longest.
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, 0.0, -0.24)
	_body.add_child(_tail)
	for k in 5:
		var feather := Node3D.new()
		_tail.add_child(feather)
		var length := 0.36 - absf(float(k) - 2.0) * 0.05
		_piece(feather, MeshKit.sphere_low(), black if k != 2 else sheen, Vector3(0, -0.002 * absf(k - 2.0), -length * 0.5), Vector3(0.08, 0.016, length))
		_piece(feather, MeshKit.sphere_low(), tip, Vector3(0, 0.001, -length + 0.06), Vector3(0.07, 0.017, 0.1))
		_tail_feathers.append(feather)
	# Legs: feathered thighs, dark shanks, three toes forward and one back, black talons.
	for side in [-1.0, 1.0]:
		var foot := Node3D.new()
		foot.name = "Leg"
		foot.position = Vector3(side * 0.07, -0.08, 0.06)
		_body.add_child(foot)
		_piece(foot, MeshKit.sphere_low(), black, Vector3(0, -0.02, 0), Vector3(0.1, 0.12, 0.1))
		_piece(foot, MeshKit.cylinder(), feet, Vector3(0, -0.1, 0.0), Vector3(0.032, 0.1, 0.032))
		for k in 3:
			var toe := (float(k) - 1.0) * 25.0
			_piece(foot, MeshKit.box(), feet, Vector3(sin(deg_to_rad(toe)) * 0.04, -0.15, cos(deg_to_rad(toe)) * 0.04),
				Vector3(0.02, 0.02, 0.08), Vector3(0, toe, 0))
			_piece(foot, MeshKit.cone(), dark, Vector3(sin(deg_to_rad(toe)) * 0.085, -0.16, cos(deg_to_rad(toe)) * 0.085),
				Vector3(0.018, 0.04, 0.018), Vector3(120, toe, 0))
		_piece(foot, MeshKit.box(), feet, Vector3(0, -0.15, -0.035), Vector3(0.02, 0.02, 0.06))
		if side > 0.0:
			# A gold band and a crimson jess: the Lord's own bird.
			_piece(foot, MeshKit.cylinder(), gold, Vector3(0, -0.075, 0.0), Vector3(0.05, 0.022, 0.05))
			_piece(foot, MeshKit.box(), jess, Vector3(0.0, -0.12, -0.03), Vector3(0.018, 0.09, 0.008), Vector3(14, 0, 0))
		_feet.append(foot)
	_animate(1.0, "perch")


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
