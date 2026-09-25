class_name Preview3D
extends SubViewportContainer
## Rotatable 3D preview for menus (character creator, starter cards,
## collection, evolution). Uses its own World3D so it never interferes with
## the game world. Drag (mouse or touch) to rotate; idles with a slow spin.

signal subject_changed()

@export var auto_rotate_speed := 0.35
@export var camera_distance := 3.2
@export var camera_height := 0.9
@export var look_height := 0.7
@export var fov := 32.0
@export var drag_sensitivity := 0.012
@export var show_pedestal := true
@export var background: Color = Color(0, 0, 0, 0)

var subject: Node3D
var yaw := 0.3

var _viewport: SubViewport
var _turntable: Node3D
var _camera: Camera3D
var _dragging := false
var _drag_index := -1
var _drag_last := Vector2.ZERO
var _idle_time := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = background.a < 1.0
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR if background.a >= 1.0 else Environment.BG_CLEAR_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 1.0)
	env.ambient_light_energy = 0.42
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 0.72
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.35
	rim.light_color = Color(0.5, 0.85, 1.0)
	_viewport.add_child(rim)

	_camera = Camera3D.new()
	_camera.fov = fov
	_viewport.add_child(_camera)
	_update_camera()

	_turntable = Node3D.new()
	_turntable.name = "Turntable"
	_viewport.add_child(_turntable)
	if show_pedestal:
		_build_pedestal()
	if subject:
		_turntable.add_child(subject)


func set_subject(node: Node3D) -> void:
	if subject and is_instance_valid(subject):
		if subject.get_parent():
			subject.get_parent().remove_child(subject)
		subject.queue_free()
	subject = node
	if _turntable and subject:
		_turntable.add_child(subject)
	subject_changed.emit()


## Adjusts the camera to frame a subject of the given height (metres).
func frame_height(height: float) -> void:
	camera_distance = clampf(height * 2.6 + 0.9, 2.0, 9.0)
	camera_height = height * 0.62
	look_height = height * 0.5
	_update_camera()


func _process(delta: float) -> void:
	if _turntable == null:
		return
	if not _dragging:
		_idle_time += delta
		if _idle_time > 1.5:
			yaw += auto_rotate_speed * delta
	_turntable.rotation.y = yaw


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _drag_index == -1:
			_drag_index = event.index
			_drag_last = event.position
			_dragging = true
			_idle_time = 0.0
		elif not event.pressed and event.index == _drag_index:
			_drag_index = -1
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and event.index == _drag_index:
		# Own delta per finger (event.relative is unreliable with multitouch on Web).
		yaw += clampf(event.position.x - _drag_last.x, -80.0, 80.0) * drag_sensitivity
		_drag_last = event.position
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_idle_time = 0.0
			accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _dragging:
		yaw += event.relative.x * drag_sensitivity
		accept_event()


func _update_camera() -> void:
	if _camera == null:
		return
	_camera.position = Vector3(0, camera_height, camera_distance)
	_camera.look_at(Vector3(0, look_height, 0), Vector3.UP)


func _build_pedestal() -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 1.0
	mesh.height = 0.12
	mesh.radial_segments = 40
	disc.mesh = mesh
	disc.position = Vector3(0, -0.06, 0)
	disc.material_override = MeshKit.toon(Color("1f2d66"))
	_viewport.add_child(disc)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 0.97
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = MeshKit.toon(UIPalette.CYAN, {"unshaded": true})
	ring.position = Vector3(0, 0.005, 0)
	ring.scale = Vector3(1, 0.3, 1)
	_viewport.add_child(ring)
