class_name ThirdPersonCamera
extends Node3D
## Third-person follow camera.
##
## Hierarchy (built in code): self (follows target) -> Yaw -> Pitch ->
## SpringArm3D (collision, avoids clipping into geometry) -> Camera3D.
## Rotated by touch drags (TouchCameraArea), right-mouse drag, Q/E keys and
## zoomed only by pinch / mouse wheel. Combat never shakes or zooms the camera.
## Sensitivity comes from Settings.

@export var target: Node3D
@export var height_offset := 1.15
@export var distance := 6.0
@export var min_distance := 3.0
@export var max_distance := 10.0
@export var pitch_degrees := -24.0
@export var min_pitch := -65.0
@export var max_pitch := 8.0
@export var follow_speed := 9.0
@export var base_fov := 58.0
@export var far_plane := 260.0
@export var touch_sensitivity := 0.0065
@export var key_rotate_speed := 2.2
@export_flags_3d_physics var collision_mask := 1

var yaw := 0.0
var camera: Camera3D
## Field combat: gently frame the locked-on monster at the player's chosen
## distance (the player still steers yaw).
var combat_focus: Node3D

var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _target_distance := 6.0
var _mouse_rotating := false
var _focus_blend := 0.0
## A short push of the camera on heavy hits (Camera3D offsets, so the spring
## arm's own placement is untouched); decays on its own.


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
	camera.fov = base_fov
	camera.far = far_plane
	camera.current = true
	_arm.add_child(camera)
	_target_distance = distance
	_arm.spring_length = distance
	_apply_rotation()
	snap_to_target()


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


## Every drawn frame: a camera whose own transform turned non-finite (the spring
## arm's cast, a parent's basis) shows nothing but the fog colour for that frame,
## the "flat screen" a phone flickers to. Put it back before the frame is drawn.
func _process(_delta: float) -> void:
	if camera == null:
		return
	var t := camera.global_transform
	if t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite() and t.basis.z.is_finite() and is_finite(camera.fov):
		return
	if not global_position.is_finite():
		global_position = target.global_position + Vector3.UP * height_offset if target and target.global_position.is_finite() else Vector3.ZERO
	_arm.spring_length = distance
	_target_distance = distance
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.fov = base_fov
	_apply_rotation()
	if not camera.global_transform.origin.is_finite():
		# The arm's collision answer itself is broken: draw from the arm's base.
		camera.top_level = true
		camera.global_transform = Transform3D(_pitch_node.global_basis.orthonormalized(), global_position + _pitch_node.global_basis.z * distance)
		camera.top_level = false


func _physics_process(delta: float) -> void:
	var focusing := combat_focus != null and is_instance_valid(combat_focus)
	_focus_blend = lerpf(_focus_blend, 1.0 if focusing else 0.0, 1.0 - exp(-2.5 * delta))
	if target and target.global_position.is_finite():
		var goal := target.global_position + Vector3.UP * height_offset
		# A broken position on the focused monster must never reach the camera: once the
		# camera's own position is NaN every later lerp stays NaN and the whole world
		# vanishes behind the fog colour (the HUD still drawing on top).
		if focusing and _focus_blend > 0.01 and combat_focus.global_position.is_finite():
			goal = goal.lerp(combat_focus.global_position + Vector3.UP * height_offset, 0.4 * _focus_blend)
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
		if not global_position.is_finite():
			global_position = target.global_position + Vector3.UP * height_offset
	if not is_finite(_focus_blend):
		_focus_blend = 0.0
	var key_turn := Input.get_axis("camera_left", "camera_right")
	if absf(key_turn) > 0.01:
		yaw -= key_turn * key_rotate_speed * delta * 1.0
		_apply_rotation()
	if Input.is_action_pressed("camera_zoom_in"):
		zoom(6.0 * delta)
	if Input.is_action_pressed("camera_zoom_out"):
		zoom(-6.0 * delta)
	if not is_finite(_target_distance):
		_target_distance = distance
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance, 1.0 - exp(-8.0 * delta))
	if not is_finite(_arm.spring_length):
		_arm.spring_length = _target_distance
	if not is_finite(yaw) or not is_finite(pitch_degrees):
		yaw = 0.0 if not is_finite(yaw) else yaw
		pitch_degrees = clampf(pitch_degrees, min_pitch, max_pitch) if is_finite(pitch_degrees) else (min_pitch + max_pitch) * 0.5
		_apply_rotation()


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
