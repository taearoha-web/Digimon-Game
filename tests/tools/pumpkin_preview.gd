extends Node3D
## Shots of the Halloween pumpkin (PumpkinHead) over the chibi hero, both bodies:
##   godot --rendering-driver opengl3 --path . res://tests/tools/pumpkin_preview.tscn -- OUT_DIR
## Writes OUT_DIR/pumpkin_<gender>.png.
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("2a2340")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("4a6b3a")); add_child(g)
	var out_dir := OS.get_cmdline_user_args()[0]
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 34; cam.position = Vector3(0, 2.2, 7.4); cam.rotation_degrees = Vector3(0, 0, 0)
	for gender in 2:
		var look := FaceKit.default_look(); look["gender"] = gender
		var h := HeroVisual.new(); add_child(h); h.setup(ClassData.START, "", false, {}, look)
		h.rotation_degrees.y = 16
		h.set_pumpkin(true)
		await get_tree().create_timer(0.8).timeout
		# Face the camera for the shot (it spins in play).
		var pk := h.find_child("PumpkinHead", true, false) as PumpkinHead
		if pk:
			pk.set_process(false)
			pk._body.rotation.y = deg_to_rad(-16)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/pumpkin_%d.png" % [out_dir, gender])
		h.queue_free()
		await get_tree().process_frame
	get_tree().quit()
