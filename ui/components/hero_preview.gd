class_name HeroPreview
extends SubViewportContainer
## A small turntable 3D view of the hero in the gear currently worn.

var visual: HeroVisual
var _pivot: Node3D
var _spin := true


func _init(p_size := Vector2i(250, 300)) -> void:
	stretch = true
	custom_minimum_size = Vector2(p_size)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	env.ambient_light_color = Color(0.9, 0.92, 1.0)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 35, 0)
	viewport.add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.1, 6.2)
	cam.rotation_degrees = Vector3(-3, 0, 0)
	cam.fov = 30
	viewport.add_child(cam)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)


func show_hero(class_id: StringName, equip: Dictionary, model := "") -> void:
	if visual:
		visual.queue_free()
	visual = HeroVisual.new()
	_pivot.add_child(visual)
	visual.setup(class_id, model, true, equip)


func _process(delta: float) -> void:
	if _spin and _pivot:
		_pivot.rotation.y += delta * 0.7
