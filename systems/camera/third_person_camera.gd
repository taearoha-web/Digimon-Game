class_name ThirdPersonCamera
extends Node3D
## Third-person follow camera.
##
## Hierarchy (built in code): self (follows target) -> Yaw -> Pitch ->
## SpringArm3D (collision, avoids clipping into geometry) -> Camera3D.
## Rotated by touch drags (TouchCameraArea), right-mouse drag, Q/E keys and
## zoomed by pinch / mouse wheel. The hero's own skills may move it a little
## (feel_windup / feel_punch / feel_shake: a wind-up zoom, an impact punch and a
## shake along the hit), always capped (FEEL_MAX_*), settling back to rest, and only
## while the "สั่นจอ" setting (GameSettings.screen_shake) is on. Monsters, allies and
## AI casters never move it. Sensitivity comes from Settings.

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

## Overhead pieces (a market booth's awning, a lantern line across a street) that the
## camera can come over, under or behind put themselves in this group. They are low next
## to the camera's height, so one whose ground footprint lies between the camera and the
## hero fills the bottom of the view: it fades out (hidden once faded) while it is there,
## or while the camera is right at it, and comes back when the camera has left it.
const FADE_GROUP := &"camera_fade"
## How close (m, on the ground) the camera may come to a fading piece before it fades.
const FADE_MARGIN := 2.0
## Fade speed (alpha per second).
const FADE_SPEED := 6.0

var yaw := 0.0
var camera: Camera3D
## Fading pieces now in the way: GeometryInstance3D -> true.
var faded: Dictionary = {}
var _fade_tick := 0
## Field combat: gently frame the locked-on monster at the player's chosen
## distance (the player still steers yaw).
var combat_focus: Node3D

var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var _target_distance := 6.0
var _mouse_rotating := false
var _focus_blend := 0.0
## Skill feel: Camera3D field-of-view and h/v offsets only, so the spring arm's own
## placement (and its collision) is untouched. All decays on its own in real time.
const FEEL_MAX_FOV := 6.0
const FEEL_MAX_OFFSET := 0.13
## Wind-up zoom: degrees (negative zooms in), how far along (0..1) and its length.
var _windup_deg := 0.0
var _windup_t := 1.0
var _windup_len := 0.5
var _windup_hold := 0.0
## Impact punch (degrees, decays) and the shake: a direction in screen space, amplitude,
## age and length (seconds of real time), plus a one-off downward kick.
var _punch_deg := 0.0
var _shake_dir := Vector2.ZERO
var _shake_amp := 0.0
var _shake_age := 0.0
var _shake_len := 0.0
var _kick := 0.0
var _feel_on := false


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
	if _feel_on:
		_step_feel(_delta)
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
	_fade_tick += 1
	if _fade_tick % 3 == 0:
		refresh_fades()
	_step_fades(delta)


## Works out which FADE_GROUP pieces are in the way of the camera now. With `instant`
## they jump straight to faded / shown (a test, a teleport).
func refresh_fades(instant := false) -> void:
	if camera == null or target == null or not is_inside_tree():
		return
	var cam := camera.global_position
	var hero := target.global_position
	if not cam.is_finite() or not hero.is_finite():
		return
	var now: Dictionary = {}
	for node in get_tree().get_nodes_in_group(FADE_GROUP):
		var g := node as GeometryInstance3D
		if g == null or not g.is_inside_tree():
			continue
		var box: AABB = g.global_transform * g.get_aabb()
		if footprint_near(box, cam, FADE_MARGIN) or footprint_between(box, cam, hero):
			now[g] = true
	for g in faded:
		if is_instance_valid(g) and not now.has(g):
			g.visible = true
	faded = now
	if instant:
		for node in get_tree().get_nodes_in_group(FADE_GROUP):
			var g := node as GeometryInstance3D
			if g:
				g.transparency = 1.0 if faded.has(g) else 0.0
				g.visible = not faded.has(g)


## True when point `p` (the camera) is over or within `margin` of `box`'s ground
## footprint, and not far above it.
static func footprint_near(box: AABB, p: Vector3, margin: float) -> bool:
	return p.x > box.position.x - margin and p.x < box.end.x + margin and p.z > box.position.z - margin and p.z < box.end.z + margin and p.y < box.end.y + 4.0


## True when `box`'s ground footprint (grown a little) crosses the line on the ground
## from the camera to the hero.
static func footprint_between(box: AABB, cam: Vector3, hero: Vector3, grow := 0.4) -> bool:
	var flat := AABB(Vector3(box.position.x - grow, -1.0, box.position.z - grow), Vector3(box.size.x + grow * 2.0, 2.0, box.size.z + grow * 2.0))
	return flat.intersects_segment(Vector3(cam.x, 0, cam.z), Vector3(hero.x, 0, hero.z)) != null


func _step_fades(delta: float) -> void:
	for node in get_tree().get_nodes_in_group(FADE_GROUP):
		var g := node as GeometryInstance3D
		if g == null:
			continue
		var goal := 1.0 if faded.has(g) else 0.0
		if is_equal_approx(g.transparency, goal):
			continue
		g.transparency = move_toward(g.transparency, goal, FADE_SPEED * delta)
		g.visible = g.transparency < 0.99


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


# ---------------------------------------------------------------------------
# Skill feel (SkillFeel): wind-up zoom, impact punch, directional shake
# ---------------------------------------------------------------------------

static func feel_allowed() -> bool:
	GameSettings.load_settings()
	return GameSettings.screen_shake


## Eases the view in by [param degrees] over [param seconds] of the cast's wind-up.
func feel_windup(degrees: float, seconds: float) -> void:
	if not feel_allowed() or camera == null:
		return
	_windup_deg = -clampf(absf(degrees), 0.0, FEEL_MAX_FOV)
	_windup_len = clampf(seconds, 0.1, 2.5)
	_windup_t = 0.0
	_windup_hold = 0.0
	_wake_feel()


## The impact: the wind-up lets go and the view punches out by [param degrees].
func feel_punch(degrees: float) -> void:
	if not feel_allowed() or camera == null:
		return
	_windup_t = 1.0
	_windup_deg = 0.0
	_punch_deg = clampf(maxf(_punch_deg, absf(degrees)), 0.0, FEEL_MAX_FOV)
	_wake_feel()


## Shakes along the hit: [param world_dir] (flat) mapped onto the screen. A weaker
## shake never cuts a stronger one short; nothing stacks past the caps.
func feel_shake(world_dir: Vector3, amplitude: float, seconds := 0.3, down := 0.0) -> void:
	if not feel_allowed() or camera == null or amplitude <= 0.0:
		return
	var remaining := _shake_amp * (1.0 - clampf(_shake_age / maxf(_shake_len, 0.01), 0.0, 1.0))
	if amplitude > remaining * 0.8:
		var basis := camera.global_transform.basis
		var flat := Vector3(world_dir.x, 0.0, world_dir.z)
		var screen := Vector2(flat.dot(basis.x), -flat.dot(basis.z) * 0.45)
		_shake_dir = screen.normalized() if screen.length() > 0.05 else Vector2(1, 0)
		_shake_amp = clampf(amplitude, 0.0, FEEL_MAX_OFFSET)
		_shake_age = 0.0
		_shake_len = clampf(seconds, 0.08, 0.6)
	_kick = clampf(maxf(_kick, absf(down)), 0.0, FEEL_MAX_OFFSET)
	_wake_feel()


## Everything back at rest at once (zone change, tests, the setting switched off).
func feel_reset() -> void:
	_windup_deg = 0.0
	_windup_t = 1.0
	_punch_deg = 0.0
	_shake_amp = 0.0
	_kick = 0.0
	_feel_on = false
	if camera:
		camera.fov = base_fov
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## How far the camera is off its rest now: [fov degrees, offset metres].
func feel_offset() -> Vector2:
	if camera == null:
		return Vector2.ZERO
	return Vector2(camera.fov - base_fov, Vector2(camera.h_offset, camera.v_offset).length())


func _wake_feel() -> void:
	_feel_on = true


func _step_feel(delta: float) -> void:
	# Unscaled time: a hit-stop or the cut-in's slow motion never stretches the shake.
	var dt := clampf(delta / maxf(Engine.time_scale, 0.01), 0.0, 0.1)
	if not GameSettings.screen_shake:
		feel_reset()
		return
	var fov := 0.0
	if _windup_deg < 0.0:
		_windup_t = minf(1.0, _windup_t + dt / _windup_len)
		fov += _windup_deg * smoothstep(0.0, 1.0, _windup_t)
		if _windup_t >= 1.0:
			# Held at most half a second past the wind-up when no impact comes.
			_windup_hold += dt
			if _windup_hold > 0.5:
				_windup_deg = move_toward(_windup_deg, 0.0, dt * 12.0)
	if _punch_deg > 0.0:
		fov += _punch_deg
		_punch_deg = move_toward(_punch_deg * exp(-7.0 * dt), 0.0, dt * 0.5)
		if _punch_deg < 0.05:
			_punch_deg = 0.0
	var offset := Vector2.ZERO
	if _shake_amp > 0.0:
		_shake_age += dt
		var k := clampf(_shake_age / _shake_len, 0.0, 1.0)
		if k >= 1.0:
			_shake_amp = 0.0
		else:
			var swing := sin(_shake_age * TAU * 22.0) * (1.0 - k) * (1.0 - k)
			offset += _shake_dir * _shake_amp * swing
			# A small cross wobble keeps it from reading as a slide.
			offset += Vector2(-_shake_dir.y, _shake_dir.x) * _shake_amp * 0.25 * sin(_shake_age * TAU * 31.0) * (1.0 - k)
	if _kick > 0.0:
		offset.y -= _kick
		_kick = move_toward(_kick * exp(-14.0 * dt), 0.0, dt * 0.05)
		if _kick < 0.003:
			_kick = 0.0
	offset = offset.limit_length(FEEL_MAX_OFFSET)
	camera.fov = base_fov + clampf(fov, -FEEL_MAX_FOV, FEEL_MAX_FOV)
	camera.h_offset = offset.x
	camera.v_offset = offset.y
	if _windup_deg == 0.0 and _punch_deg <= 0.0 and _shake_amp <= 0.0 and _kick <= 0.0:
		feel_reset()
