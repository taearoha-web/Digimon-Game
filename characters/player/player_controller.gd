class_name PlayerController
extends CharacterBody3D
## Third-person player movement (camera-relative), for touch and keyboard.
##
## Input sources are merged: the HUD joystick sets [member touch_move]; WASD /
## arrows are read from the input map. Joystick push strength maps to walk vs
## run; the Sprint toggle or Shift forces running.

signal interactable_changed(interactable: Interactable)
signal moved_distance(distance: float)

@export var walk_speed := 3.2
@export var run_speed := 6.4
@export var acceleration := 14.0
@export var deceleration := 16.0
@export var turn_speed := 12.0
@export var run_threshold := 0.82
@export var gravity_multiplier := 1.0

var camera_rig: ThirdPersonCamera
var touch_move := Vector2.ZERO
var sprint_toggled := false
var input_enabled := true
var avatar: ChibiAvatar
var interaction: InteractionDetector

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 18.0)
var _facing_yaw := 0.0
var _last_position := Vector3.ZERO


func _ready() -> void:
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.45
	floor_constant_speed = true
	collision_layer = 1 << 1
	collision_mask = (1 << 0) | (1 << 4)
	avatar = get_node_or_null("Avatar") as ChibiAvatar
	if avatar == null:
		avatar = ChibiAvatar.new()
		avatar.name = "Avatar"
		add_child(avatar)
	interaction = get_node_or_null("InteractionDetector") as InteractionDetector
	if interaction:
		interaction.current_changed.connect(func(i): interactable_changed.emit(i))
	_last_position = global_position


func apply_appearance(appearance: CharacterAppearance) -> void:
	avatar.apply_appearance(appearance)


func set_facing(yaw: float) -> void:
	_facing_yaw = yaw
	avatar.rotation.y = yaw


func get_facing() -> float:
	return _facing_yaw


func face_towards(world_pos: Vector3) -> void:
	var dir := world_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		set_facing(atan2(dir.x, dir.z))


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		touch_move = Vector2.ZERO


func try_interact() -> bool:
	if not input_enabled or interaction == null:
		return false
	var target := interaction.get_current()
	if target == null or not target.can_interact(self):
		return false
	face_towards(target.global_position)
	avatar.play_once(&"interact", &"idle")
	target.interact(self)
	return true


func _physics_process(delta: float) -> void:
	var input_vec := _read_move_input() if input_enabled else Vector2.ZERO
	var strength := clampf(input_vec.length(), 0.0, 1.0)
	var wants_run := strength >= run_threshold or sprint_toggled or Input.is_action_pressed("sprint")
	var target_speed := 0.0
	var direction := Vector3.ZERO
	if strength > 0.01:
		var basis := camera_rig.get_move_basis() if camera_rig else Basis.IDENTITY
		direction = (basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
		target_speed = run_speed if wants_run else lerpf(walk_speed * 0.45, walk_speed, clampf(strength / run_threshold, 0.0, 1.0))

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var desired := direction * target_speed
	var rate := acceleration if target_speed > 0.0 else deceleration
	horizontal = horizontal.move_toward(desired, rate * delta * maxf(target_speed, walk_speed))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * gravity_multiplier * delta
	move_and_slide()

	if direction.length_squared() > 0.0:
		var target_yaw := atan2(direction.x, direction.z)
		_facing_yaw = lerp_angle(_facing_yaw, target_yaw, 1.0 - exp(-turn_speed * delta))
		avatar.rotation.y = _facing_yaw
	_update_animation(Vector2(velocity.x, velocity.z).length())

	var moved := global_position.distance_to(_last_position)
	_last_position = global_position
	if moved > 0.0001:
		moved_distance.emit(moved)
	# Safety net: fell through the world.
	if global_position.y < -40.0:
		velocity = Vector3.ZERO
		global_position = Vector3(global_position.x, 5.0, global_position.z)


func _read_move_input() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length_squared() > keyboard.length_squared():
		return touch_move
	return keyboard


func _update_animation(speed: float) -> void:
	if avatar.current_animation == &"interact":
		return
	if speed > walk_speed + 0.4:
		avatar.play_animation(&"run", 0.15)
	elif speed > 0.3:
		avatar.play_animation(&"walk", 0.15)
	else:
		avatar.play_animation(&"idle", 0.25)
