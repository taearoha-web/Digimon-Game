class_name ThirdPersonCamera
extends Node3D
## Third-person follow camera.
##
## Hierarchy (built in code): self (follows target) -> Yaw -> Pitch ->
## SpringArm3D (collision, avoids clipping into geometry) -> Camera3D.
## Rotated by touch drags (TouchCameraArea), right-mouse drag, Q/E keys and
## zoomed by pinch / mouse wheel. Sensitivity comes from Settings.

@export var target: Node3D
@export var height_offset := 1.15
@export var distance := 6.0
@export var min_distance := 3.0
@export var max_distance := 10.0
@export var pitch_degrees := -24.0
@export var min_pitch := -65.0
@export var max_pitch := 8.0
@export var follow_speed := 9.0
@export var touch_sensitivity := 0.0065
@export var key_rotate_speed := 2.2
@export_flags_3d_physics var collision_mask := 1

var yaw := 0.0
var camera: Camera3D
## Field combat: the locked-on monster. The camera drifts towards it and backs
## off a little so the whole fight stays in frame (the player still steers yaw).
var combat_focus: Node3D

var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _target_distance := 6.0
var _mouse_rotating := false
var _shake_strength := 0.0
var _focus_blend := 0.0


func _ready() -> void:
	_yaw_node = Node3D.new()
	_yaw_node.name = "Yaw"
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	_yaw_node.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.name = "SpringArm3D"
	_arm.collision_mask = collision_mask
	_arm.margin = 0.25
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	_arm.shape = probe
	_pitch_node.add_child(_arm)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 58.0
	camera.far = 260.0
	camera.current = true
	_arm.add_child(camera)
	_target_distance = distance
	_arm.spring_length = distance
	_apply_rotation()
	snap_to_target()


## A quick zoom-in kick for heavy skills.
func punch(fov_add := 5.0) -> void:
	if camera == null:
		return
	var base := 58.0
	var tween := create_tween()
	tween.tween_property(camera, "fov", base - fov_add, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "fov", base, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	shake(0.35)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height_offset


func set_yaw_behind(target_yaw: float) -> void:
	yaw = target_yaw
	_apply_rotation()


## Horizontal forward/right vectors used for camera-relative movement.
func get_move_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func rotate_by_pixels(relative: Vector2) -> void:
	var sensitivity := touch_sensitivity * GameSettings.camera_speed
	yaw -= relative.x * sensitivity
	var invert := -1.0 if false else 1.0
	pitch_degrees = clampf(pitch_degrees - relative.y * sensitivity * 57.3 * 0.6 * invert, min_pitch, max_pitch)
	_apply_rotation()


func zoom(amount: float) -> void:
	_target_distance = clampf(_target_distance - amount, min_distance, max_distance)


func shake(strength := 0.25) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _physics_process(delta: float) -> void:
	var focusing := combat_focus != null and is_instance_valid(combat_focus)
	_focus_blend = lerpf(_focus_blend, 1.0 if focusing else 0.0, 1.0 - exp(-2.5 * delta))
	if target:
		var goal := target.global_position + Vector3.UP * height_offset
		if focusing and _focus_blend > 0.01:
			goal = goal.lerp(combat_focus.global_position + Vector3.UP * height_offset, 0.4 * _focus_blend)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	var key_turn := Input.get_axis("camera_left", "camera_right")
	if absf(key_turn) > 0.01:
		yaw -= key_turn * key_rotate_speed * delta * 1.0
		_apply_rotation()
	if Input.is_action_pressed("camera_zoom_in"):
		zoom(6.0 * delta)
	if Input.is_action_pressed("camera_zoom_out"):
		zoom(-6.0 * delta)
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance + 2.0 * _focus_blend, 1.0 - exp(-8.0 * delta))
	if _shake_strength > 0.001:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake_strength
		camera.v_offset = randf_range(-1.0, 1.0) * _shake_strength
		_shake_strength = lerpf(_shake_strength, 0.0, 1.0 - exp(-10.0 * delta))
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Desktop fallback: right mouse drag rotates, wheel zooms.
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_rotating = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(0.6)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(-0.6)
	elif event is InputEventMouseMotion and _mouse_rotating and event.device != InputEvent.DEVICE_ID_EMULATION:
		rotate_by_pixels(event.relative)


func add_excluded_body(body: CollisionObject3D) -> void:
	if _arm and body:
		_arm.add_excluded_object(body.get_rid())


func _apply_rotation() -> void:
	if _yaw_node:
		_yaw_node.rotation.y = yaw
		_pitch_node.rotation.x = deg_to_rad(pitch_degrees)
