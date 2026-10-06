extends Node3D
## Hair / outfit lineup: godot --path . res://tests/tools/look_preview.tscn -- out.png mode
## mode: hair_m | hair_f | outfits | classes
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 0.9; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var mode := args[1]
	var looks: Array = []
	var cls: Array = []
	match mode:
		"hair_m", "hair_f":
			var gender := 0 if mode == "hair_m" else 1
			for i in FaceKit.option_count("hair", gender):
				var look := FaceKit.default_look()
				look["gender"] = gender; look["hair"] = i; look["hair_color"] = (i * 3 + 1) % FaceKit.HAIR_COLORS.size(); look["skin"] = i % 4
				looks.append(look); cls.append(ClassData.START)
		"outfits":
			for i in FaceKit.OUTFITS.size():
				var look := FaceKit.default_look()
				look["gender"] = i % 2; look["hair"] = i % 5; look["hair_color"] = i % 8; look["outfit"] = i
				looks.append(look); cls.append(ClassData.START)
		_:
			var rng := RandomNumberGenerator.new(); rng.seed = 3
			for c in ClassData.IDS:
				looks.append(FaceKit.random_look(rng)); cls.append(c)
	var n := looks.size()
	var per_row := 4
	for i in n:
		var h := HeroVisual.new(); add_child(h); h.setup(cls[i], "", true, {}, looks[i])
		h.position = Vector3((i % per_row) * 3.0 - (min(n, per_row) - 1) * 1.5, 0, -float(i / per_row) * 4.5); h.rotation_degrees.y = 12
	var rows := (n + per_row - 1) / per_row
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.4 + rows * 1.0, 9.0 + rows * 2.2); cam.rotation_degrees = Vector3(-8, 0, 0); cam.fov = 40; add_child(cam)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
