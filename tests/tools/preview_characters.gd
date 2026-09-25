extends Node3D
## Visual check: renders several avatar variants and saves a screenshot.
## Run: godot --path . res://tests/tools/preview_characters.tscn -- <out.png>


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a3a7a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 1.0)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 5.2)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 40
	add_child(cam)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("6fbf73"))
	add_child(ground)

	var variants: Array = []
	var a1 := CharacterAppearance.create_default(&"male")
	variants.append(a1)
	var a2 := CharacterAppearance.create_default(&"female")
	a2.accessories = [&"backpack"]
	variants.append(a2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 3:
		var a := CharacterAppearance.create_default(&"female" if i % 2 == 0 else &"male")
		a.randomize_from(GameData.customization_catalog, rng)
		variants.append(a)
	var x := -2.4
	for a in variants:
		var avatar := ChibiAvatar.new()
		add_child(avatar)
		avatar.apply_appearance(a)
		avatar.position = Vector3(x, 0, 0)
		avatar.rotation_degrees.y = 15
		x += 1.2
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://preview_characters.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
