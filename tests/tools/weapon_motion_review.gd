extends Node3D
## Real equipped rigs sampled from front/side/rear; no user saves or gameplay.
## -- OUT CLASS [RIG=0] [TIER=0] [CLIP=Idle] [PHASE=0.25]
var actors: Array[HeroVisual] = []


func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 2
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var family := StringName(args[1])
	var rig := int(args[2]) if args.size() > 2 else 0
	var tier := int(args[3]) if args.size() > 3 else 0
	var clip := args[4] if args.size() > 4 else "Idle"
	var phase := float(args[5]) if args.size() > 5 else 0.25
	get_window().size = Vector2i(1200, 720)
	get_window().content_scale_size = Vector2i(1200, 720)
	Scenery.environment(self, Color("243b50"), Color("243b50"), Color("e1eeff"), Color("fff1da"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("78918d"))
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 710
	var gear := {"weapon": ItemData.generate(tier * 10 + 5, family, rng, 0, "weapon")}
	gear.weapon["plus"] = 0
	var report := []
	for i in 3:
		var hero := HeroVisual.new()
		add_child(hero)
		hero.setup(family, "", true, gear, {} if rig == 2 else {"gender": rig})
		hero.position.x = (i - 1) * 2.8
		hero.rotation_degrees.y = [0, -90, 180][i]
		hero.release()
		hero.play(clip, 0.0)
		hero.anim.seek(hero.anim.get_animation(hero.current).length * phase, true)
		hero.anim.pause()
		actors.append(hero)
		if i == 0:
			for bone in hero._skeleton.get_bone_count():
				var name := hero._skeleton.get_bone_name(bone)
				if name.contains("Hand") or name.contains("handslot") or name.begins_with("hand.") or name.contains("Middle") or name.contains("Arm") or name.contains("arm."):
					var pose := hero._skeleton.get_bone_global_pose(bone)
					report.append({"bone": name, "position": pose.origin, "basis": pose.basis})
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	add_child(camera)
	camera.position = Vector3(0, 2.3, 11)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.make_current()
	var label := Label.new()
	label.position = Vector2(25, 20)
	label.add_theme_font_size_override("font_size", 26)
	label.text = "%s / rig %d / tier %d / %s %.2f — front, side, back" % [family, rig, tier, clip, phase]
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(label)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	FileAccess.open(out + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WEAPON MOTION REVIEW: ", out)
	get_tree().quit()
