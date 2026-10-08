class_name HeroPreview
extends SubViewportContainer
## A small turntable 3D view of the hero in the gear currently worn.

var visual: HeroVisual
var _pivot: Node3D
var _spin := true
var _dragging := false
var _idle := 0.0


func _init(p_size := Vector2i(250, 300)) -> void:
	stretch = true
	custom_minimum_size = Vector2(p_size)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = p_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e5ef")
	env.ambient_light_energy = 0.72
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -32, 0)
	light.light_color = Color("fff0dc")
	light.light_energy = 1.3
	viewport.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 145, 0)
	rim.light_color = Color("a9ddd8")
	rim.light_energy = 0.7
	viewport.add_child(rim)
	var cam := Camera3D.new()
	# Far enough back to fit tall crowns and wings above the head.
	cam.position = Vector3(0, 1.7, 8.6)
	cam.rotation_degrees = Vector3(-3, 0, 0)
	cam.fov = 30
	viewport.add_child(cam)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	# A quiet studio pedestal grounds the model without a full second scene.
	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.5
	disc.height = 0.11
	disc.radial_segments = 40
	plinth.mesh = disc
	plinth.position.y = -0.075
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("537a80")
	material.roughness = 0.7
	plinth.material_override = material
	viewport.add_child(plinth)


func show_hero(class_id: StringName, equip: Dictionary, model := "", look := {}) -> void:
	if visual:
		visual.queue_free()
	visual = HeroVisual.new()
	_pivot.add_child(visual)
	visual.setup(class_id, model, true, equip, look)


## Drag with a finger (or the mouse) to turn the hero around.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		_idle = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_pivot.rotation.y += event.relative.x * 0.012
		_idle = 0.0
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_idle = 0.0
	elif event is InputEventMouseMotion and _dragging and event.device != InputEvent.DEVICE_ID_EMULATION:
		_pivot.rotation.y += event.relative.x * 0.012
		_idle = 0.0


func _process(delta: float) -> void:
	_idle += delta
	if _spin and _pivot and not _dragging and _idle > 1.5:
		_pivot.rotation.y += delta * 0.24
