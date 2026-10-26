class_name DarkRaven
extends Node3D
## The Dark Lord's raven. It perches on the Lord's raised left forearm, wings
## folded, and on command (the raven button on the HUD for the hero; always for an
## AI Lord in a fight) flies off to the Lord's target, or the nearest monster, and
## keeps diving at it on its own: circle, dive, strike, climb. With nothing to
## fight, or called back, it flies home to the arm.
##
## The owner (Hero or Companion) provides:
##   visual: HeroVisual          (perch_point())
##   raven_target() -> Mob       the monster to go for, or null
##   raven_strike(mob)           one strike of the raven (damage, credit, effects)
## Built from simple shapes in code, one material per colour.

enum State { PERCH, FLY, RETURN }

const SIZE := 0.42
const SPEED := 13.0
const STRIKE_EVERY := 0.85
const LEASH := 22.0
const VIOLET := Color("8a4dff")

var owner_ref: WeakRef
var attack := false
var state := State.PERCH
var _target_ref: WeakRef
var _strike_timer := 0.0
var _dive := 0.0
var _orbit := 0.0
var _flap := 0.0
var _body: Node3D
var _wings: Array[Node3D] = []
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
	return lord.global_position + Vector3(-0.35, 1.25, 0.25)


func _process(delta: float) -> void:
	var lord := _lord()
	if lord == null:
		return
	var dead: bool = lord.call("is_dead") if lord.has_method("is_dead") else false
	visible = not dead
	_flap += delta * (14.0 if state != State.PERCH else 2.0)
	_animate_wings()
	var target := _target_ref.get_ref() as Mob if _target_ref != null else null
	if target != null and (not is_instance_valid(target) or target.is_dead()):
		target = null
	match state:
		State.PERCH:
			global_position = _perch(lord)
			var body: Variant = lord.get("visual")
			var facing: Vector3 = (body as Node3D).global_basis.z if body is Node3D and is_instance_valid(body) else lord.global_basis.z
			look_at(global_position + Vector3(facing.x, 0, facing.z), Vector3.UP, true)
			if attack and not dead:
				var next := lord.call("raven_target") as Mob
				if next != null:
					_target_ref = weakref(next)
					state = State.FLY
					_dive = 0.0
		State.FLY:
			if target == null:
				var next := lord.call("raven_target") as Mob if attack else null
				if next != null:
					_target_ref = weakref(next)
					target = next
			if target == null or not attack or dead or target.global_position.distance_to(lord.global_position) > LEASH:
				state = State.RETURN
			else:
				_fight(lord, target, delta)
		State.RETURN:
			var home := _perch(lord)
			_fly_to(home, delta, SPEED * 1.2)
			if global_position.distance_to(home) < 0.25:
				state = State.PERCH


## Circles over the target and dives at it every STRIKE_EVERY seconds.
func _fight(lord: Node3D, target: Mob, delta: float) -> void:
	_strike_timer -= delta
	_orbit += delta * 2.4
	var center := target.global_position + Vector3(0, 1.0, 0)
	var goal := center + Vector3(cos(_orbit) * 1.6, 1.6, sin(_orbit) * 1.6)
	if _strike_timer <= 0.0:
		# The dive: straight at the target's body, strike on contact.
		_dive += delta * 4.0
		goal = target.hit_point() if target.has_method("hit_point") else center
		if global_position.distance_to(goal) < 0.45 or _dive > 1.0:
			lord.call("raven_strike", target)
			_strike_timer = STRIKE_EVERY
			_dive = 0.0
			VfxKit.sparks(target.get_parent() as Node3D, goal, VIOLET, 8, 3.0, 0.4)
	_fly_to(goal, delta, SPEED * (1.4 if _strike_timer <= 0.0 else 0.8))


func _fly_to(goal: Vector3, delta: float, speed: float) -> void:
	var step := goal - global_position
	var move := step.limit_length(speed * delta)
	global_position += move
	if move.length_squared() > 0.000001:
		var flat := Vector3(move.x, move.y * 0.4, move.z)
		if flat.length_squared() > 0.000001 and absf(flat.normalized().dot(Vector3.UP)) < 0.98:
			look_at(global_position + flat, Vector3.UP, true)


func _animate_wings() -> void:
	var open := state != State.PERCH
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var wing := _wings[i]
		if open:
			wing.rotation = Vector3(0, 0, side * (0.15 + sin(_flap) * 0.85))
		else:
			# Folded along the back, with a slow breath.
			wing.rotation = Vector3(0.2, side * 0.2, side * (1.35 + sin(_flap) * 0.04))
	if _body:
		_body.position.y = (sin(_flap * 0.5) * 0.01) if not open else 0.0
	if _eyes:
		_eyes.emission_energy_multiplier = 2.4 if open else 1.2


## A raven of simple shapes, facing +Z: body, head, beak, tail fan and two wings
## (each a pivot at the shoulder), with glowing red eyes.
func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	var black := MeshKit.toon(Color("1c1426"))
	var sheen := MeshKit.toon(Color("3a2a5a"))
	var beak := MeshKit.toon(Color("2a2420"))
	_eyes = (MeshKit.toon(Color("ff3a3a"), {"emission": 1.2}) as StandardMaterial3D).duplicate()
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, 0, 0), Vector3(0.32, 0.3, 0.55))
	_piece(_body, MeshKit.sphere_low(), sheen, Vector3(0, 0.06, -0.05), Vector3(0.26, 0.2, 0.45))
	_piece(_body, MeshKit.sphere_low(), black, Vector3(0, 0.14, 0.27), Vector3(0.22, 0.22, 0.24))
	_piece(_body, MeshKit.cone(), beak, Vector3(0, 0.12, 0.44), Vector3(0.07, 0.18, 0.07), Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		_piece(_body, MeshKit.sphere_low(), _eyes, Vector3(side * 0.08, 0.18, 0.36), Vector3.ONE * 0.045)
	# The tail fan.
	for k in 3:
		_piece(_body, MeshKit.box(), black, Vector3((k - 1) * 0.06, -0.02, -0.38), Vector3(0.06, 0.02, 0.28), Vector3(0, (k - 1) * 14.0, 0))
	# Feet gripping the perch.
	for side in [-1.0, 1.0]:
		_piece(_body, MeshKit.cylinder(), beak, Vector3(side * 0.06, -0.17, 0.02), Vector3(0.025, 0.1, 0.025))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Wing"
		pivot.position = Vector3(side * 0.12, 0.08, 0.04)
		_body.add_child(pivot)
		# Three feathered layers, longest at the back.
		for k in 3:
			var length := 0.5 - k * 0.08
			_piece(pivot, MeshKit.box(), black if k != 1 else sheen, Vector3(side * length * 0.5, 0, -k * 0.09), Vector3(length, 0.02, 0.16), Vector3(0, side * k * 6.0, 0))
		_wings.append(pivot)


func _piece(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshKit.part(parent, mesh, mat, at, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
