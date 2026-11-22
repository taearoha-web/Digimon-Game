extends Node3D
## The Muay Thai fighter's hand wraps on every body (8 chibi bodies + KayKit) in idle,
## run and a punch, camera close on the hands, laid out as one sheet.
##   godot --rendering-driver opengl3 --resolution 320x320 --path . res://tests/tools/wraps_preview.tscn -- OUT_PNG [LOOK]
## LOOK: the weapon look to wear (wraps_0 by default; star_wraps_200, set_wraps_muaythai,
## divine_wraps_muaythai_200 and dragon_wraps_muaythai too).
const CELL := 320
const CLIPS := [["Idle", 0.35, "wide"], ["Idle", 0.35, "fist"], ["Running_A", 0.3, "wide"], ["attack", 0.45, "fist"]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_png := args[0]
	var look_id := args[1] if args.size() > 1 else "wraps_0"
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var weapon: Dictionary
	if look_id.begins_with("dragon_"):
		weapon = DragonGearData.weapon(&"muaythai", rng)
	elif look_id.begins_with("divine_"):
		weapon = DivineGearData.item(&"muaythai", "weapon", rng)
	elif look_id.begins_with("set_"):
		weapon = SetGearData.item("muaythai", "weapon")
	elif look_id.begins_with("star_"):
		var stars := StarGearData.stars_from_look(look_id)
		for piece in StarGearData.catalogue():
			if String(piece.class) == "muaythai" and String(piece.slot) == "weapon" and StarGearData.stars_from_look(ItemLook.look_of(piece)) == stars:
				weapon = piece.duplicate(true)
	else:
		weapon = ItemData.generate(int(look_id.trim_prefix("wraps_")) * 10 + 5, &"muaythai", rng, 0, "weapon")
	weapon["plus"] = 0
	var bodies: Array = []
	for gender in 2:
		for body in ChibiBodies.count(gender):
			bodies.append([gender, body])
	bodies.append([2, 0])
	var cam := Camera3D.new(); add_child(cam); cam.fov = 30
	var sheet := Image.create(CELL * CLIPS.size() * 2, CELL * int(ceil(bodies.size() / 2.0)), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var attack := String(ClassData.get_class_data(&"muaythai").attack.anims[0])
	for i in bodies.size():
		var entry: Array = bodies[i]
		var look := FaceKit.default_look()
		if entry[0] != 2:
			look["gender"] = entry[0]; look["body"] = entry[1]
		var h := HeroVisual.new(); add_child(h)
		h.setup(&"muaythai", "", true, {"weapon": weapon}, look if entry[0] != 2 else {})
		h.set_process(false)
		for k in CLIPS.size():
			var clip: String = attack if CLIPS[k][0] == "attack" else CLIPS[k][0]
			h.release()
			h.play(clip, 0.0)
			h.anim.seek(h.anim.get_animation(h.current).length * float(CLIPS[k][1]), true)
			h.anim.pause()
			h._skeleton.force_update_all_bone_transforms()
			var s := h._skeleton
			var r := s.global_transform * s.get_bone_global_pose(s.find_bone("handslot.r")).origin
			var lh := s.global_transform * s.get_bone_global_pose(s.find_bone("handslot.l")).origin
			var mid := (r + lh) * 0.5
			var span := maxf(r.distance_to(lh), 0.5)
			cam.position = mid + Vector3(0.35, 0.25, 1.0).normalized() * span * 2.3
			cam.look_at(mid, Vector3.UP)
			await get_tree().process_frame
			if CLIPS[k][2] == "fist":
				# Close on the right fist, looking over the back of the hand at the knuckles
				# (the knuckle dusters' bar and finger rings).
				var grip: Node3D = null
				for n in s.get_children():
					if n is BoneAttachment3D and String(n.name).begins_with("Held_") and (n as BoneAttachment3D).bone_name == "handslot.r":
						grip = n.get_child(0)
				var g := (grip.get_child(0) as Node3D).global_transform
				var at := g * Vector3(-0.03, -0.018, 0.03)
				var side := (g.basis.z.normalized() * 0.75 + g.basis.x.normalized() * 0.5 + g.basis.y.normalized() * 0.35).normalized()
				cam.position = at + side * span * 0.8
				cam.look_at(at, g.basis.x.normalized() if absf(side.dot(g.basis.x.normalized())) < 0.9 else Vector3.UP)
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL, CELL)
			sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % 2) * CELL * CLIPS.size() + k * CELL, (i / 2) * CELL))
		h.queue_free()
		await get_tree().process_frame
	sheet.save_png(out_png)
	get_tree().quit()
