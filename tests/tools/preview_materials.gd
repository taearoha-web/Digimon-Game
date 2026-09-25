extends Node3D
## Visual check for material settings under the Compatibility renderer.


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a3a7a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 1.0)
	e.ambient_light_energy = 0.45
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 35, 0)
	light.light_energy = 0.9
	add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 7)
	cam.rotation_degrees = Vector3(-10, 0, 0)
	add_child(cam)
	var configs := [
		["toon+spec+rim", BaseMaterial3D.DIFFUSE_TOON, BaseMaterial3D.SPECULAR_TOON, true],
		["toon nospec", BaseMaterial3D.DIFFUSE_TOON, BaseMaterial3D.SPECULAR_DISABLED, false],
		["burley+schlick", BaseMaterial3D.DIFFUSE_BURLEY, BaseMaterial3D.SPECULAR_SCHLICK_GGX, false],
		["lambert nospec", BaseMaterial3D.DIFFUSE_LAMBERT, BaseMaterial3D.SPECULAR_DISABLED, false],
		["toon nospec rim", BaseMaterial3D.DIFFUSE_TOON, BaseMaterial3D.SPECULAR_DISABLED, true],
	]
	var x := -4.0
	for c in configs:
		for color in [Color("4f9e5a"), Color("ff9e2e"), Color("f6d2b3")]:
			var m := StandardMaterial3D.new()
			m.albedo_color = color
			m.diffuse_mode = c[1]
			m.specular_mode = c[2]
			m.roughness = 0.75
			m.rim_enabled = c[3]
			m.rim = 0.25
			var mi := MeshInstance3D.new()
			mi.mesh = SphereMesh.new()
			mi.material_override = m
			add_child(mi)
			mi.position = Vector3(x, [0.0, 1.1, 2.2][[Color("4f9e5a"), Color("ff9e2e"), Color("f6d2b3")].find(color)], 0)
		var label := Label3D.new()
		label.text = c[0]
		label.position = Vector3(x, -0.8, 0)
		label.pixel_size = 0.003
		add_child(label)
		x += 2.0
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
