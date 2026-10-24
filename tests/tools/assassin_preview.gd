extends Node3D
## The Assassin in its gear: twin daggers of four tiers, a star set, the 200-star
## divine set with the Lv.100 wings and with the star wings, front and back.
##   godot --rendering-driver opengl3 --path . res://tests/tools/assassin_preview.tscn -- OUT_DIR [VIEW front|back|side] [GENDER] [CLASS]
## CLASS (default assassin) lets another line wear the same sets for comparison.
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fdc8c")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var view := args[1] if args.size() > 1 else "front"
	var gender := int(args[2]) if args.size() > 2 else 0
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var a := StringName(args[3]) if args.size() > 3 else &"assassin"
	var sets: Array = []
	for tier in [0, 3, 6, 9]:
		sets.append({"weapon": ItemData.generate(tier * 10 + 5, a, rng, 2, "weapon")})
	var star := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		star[slot] = StarProgression.item(a, 200, slot, rng)
	var divine := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		divine[slot] = DivineGearData.item(a, slot, rng)
	var with_wings := divine.duplicate(); with_wings["wings"] = ItemData.wings(rng, String(a), 3)
	var with_star := divine.duplicate(); with_star["wings"] = StarWingData.item(String(a), rng, 4)
	sets.append_array([star, with_wings, with_star])
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 34
	match view:
		"back":
			cam.position = Vector3(0, 1.7, -5.0); cam.rotation_degrees = Vector3(-6, 180, 0)
		"side":
			cam.position = Vector3(5.0, 1.6, 0); cam.rotation_degrees = Vector3(-6, 90, 0)
		_:
			cam.position = Vector3(0, 1.4, 4.6); cam.rotation_degrees = Vector3(-6, 0, 0)
	for i in sets.size():
		var look := FaceKit.default_look(); look["gender"] = gender
		var h := HeroVisual.new(); add_child(h); h.setup(a, "", true, sets[i], look)
		h.rotation_degrees.y = 25 if view == "front" else 0
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s_%d.png" % [out_dir, a, view, i])
		h.queue_free()
		await get_tree().process_frame
	get_tree().quit()
