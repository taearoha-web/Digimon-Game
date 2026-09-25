class_name PartnerFollower
extends CharacterBody3D
## The lead party Digimon following the player around the world.
##
## * Walks to a point slightly behind/beside the player (never onto them).
## * Uses NavigationAgent3D to route around obstacles when a navmesh exists,
##   falling back to direct steering otherwise.
## * Speeds up when far behind, teleports behind the player when stuck or
##   very far away (e.g. after the player crossed a gap).
## * Idles with small fidgets and glances at the player when resting.
## Collides only with the world, not with the player.

signal teleported()

@export var follow_distance := 2.4
@export var stop_distance := 1.6
@export var catch_up_distance := 9.0
@export var teleport_distance := 24.0
@export var side_offset := 0.9
@export var repath_interval := 0.25

var target: Node3D
var visual: DigimonVisual
var agent: NavigationAgent3D
var instance: DigimonInstance

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _repath_timer := 0.0
var _stuck_timer := 0.0
var _last_position := Vector3.ZERO
var _idle_timer := 3.0
var _base_speed := 3.5
var _yaw := 0.0


func _ready() -> void:
	collision_layer = 1 << 2
	collision_mask = 1 << 0
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.0
	shape.shape = capsule
	shape.position = Vector3(0, 0.5, 0)
	add_child(shape)
	visual = DigimonVisual.new()
	visual.name = "Visual"
	add_child(visual)
	agent = NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.8
	agent.radius = 0.4
	agent.height = 1.0
	agent.avoidance_enabled = false
	add_child(agent)
	_last_position = global_position


func setup(p_instance: DigimonInstance, p_target: Node3D) -> void:
	instance = p_instance
	target = p_target
	var species := instance.get_species() if instance else null
	visual.set_species(species)
	_base_speed = species.move_speed if species else 3.5


## Snap next to the target (used on spawn and when stuck).
func teleport_near_target() -> void:
	if target == null:
		return
	var behind := _follow_point()
	global_position = behind + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	_stuck_timer = 0.0
	teleported.emit()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance > teleport_distance or (_stuck_timer > 2.0 and distance > follow_distance * 2.0):
		teleport_near_target()
		return

	var goal := _follow_point()
	var moving := distance > follow_distance or (distance > stop_distance and velocity.length() > 0.5)
	var desired := Vector3.ZERO
	if moving:
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = repath_interval
			agent.target_position = goal
		var next := goal
		if _navigation_ready() and not agent.is_navigation_finished():
			next = agent.get_next_path_position()
		var dir := next - global_position
		dir.y = 0.0
		if dir.length_squared() < 0.01:
			dir = goal - global_position
			dir.y = 0.0
		var speed := _base_speed * 1.25
		if distance > catch_up_distance:
			speed = _base_speed * 2.4
		elif distance > follow_distance * 1.8:
			speed = _base_speed * 1.8
		desired = dir.normalized() * speed

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 20.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	# Facing: movement direction when moving, otherwise glance at the player.
	var face_dir := horizontal if horizontal.length() > 0.4 else to_target
	if face_dir.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(face_dir.x, face_dir.z), 1.0 - exp(-8.0 * delta))
		visual.rotation.y = _yaw

	var planar_speed := horizontal.length()
	if planar_speed > _base_speed * 1.5:
		visual.play_animation(&"run")
	elif planar_speed > 0.3:
		visual.play_animation(&"walk")
	elif visual.current_animation in [&"walk", &"run"]:
		visual.play_animation(&"idle")
	_update_stuck(delta, desired)
	_update_idle(delta, planar_speed)


func _follow_point() -> Vector3:
	var back := Vector3.ZERO
	if target is PlayerController:
		var facing: float = (target as PlayerController).get_facing()
		var forward := Vector3(sin(facing), 0.0, cos(facing))
		var right := Vector3(forward.z, 0.0, -forward.x)
		back = -forward * (follow_distance * 0.8) + right * side_offset
	else:
		back = Vector3(side_offset, 0, follow_distance * 0.8)
	return target.global_position + back


func _navigation_ready() -> bool:
	var map := agent.get_navigation_map()
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0


func _update_stuck(delta: float, desired: Vector3) -> void:
	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	if desired.length() > 0.5 and moved < desired.length() * delta * 0.2:
		_stuck_timer += delta
	else:
		_stuck_timer = maxf(0.0, _stuck_timer - delta)


func _update_idle(delta: float, speed: float) -> void:
	if speed > 0.2:
		_idle_timer = randf_range(4.0, 8.0)
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = randf_range(5.0, 10.0)
		visual.play_once([&"victory", &"skill"].pick_random(), &"idle")
