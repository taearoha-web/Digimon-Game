extends Node3D
## Visual check: renders every species placeholder in a grid.
## Run: godot --path . res://tests/tools/preview_digimon.tscn -- <out.png> [anim]


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a3a7a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 1.0)
	e.ambient_light_energy = 0.4
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 5.5, 11.5)
	cam.rotation_degrees = Vector3(-22, 0, 0)
	cam.fov = 45
	add_child(cam)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("4f9e5a"))
	add_child(ground)
	var args := OS.get_cmdline_user_args()
	var anim := StringName(args[1]) if args.size() > 1 else &"idle"
	var all := GameData.get_all_species()
	var cols := 7
	for i in all.size():
		var v := DigimonVisual.new()
		add_child(v)
		v.set_species(all[i])
		@warning_ignore("integer_division")
		var row := i / cols
		v.position = Vector3((i % cols - (cols - 1) * 0.5) * 2.1, 0, -row * 3.0 + 1.5)
		v.rotation_degrees.y = 20
		v.play_animation(anim, 0.0)
		var label := Label3D.new()
		label.text = all[i].display_name
		label.position = v.position + Vector3(0, -0.25, 0.8)
		label.font_size = 48
		label.pixel_size = 0.004
		add_child(label)
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var out := args[0] if args.size() > 0 else "user://preview_digimon.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
