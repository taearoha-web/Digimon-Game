extends Node3D
## The knuckle dusters on a right fist from the three axes of their own grip space (the
## back of the hand +Z, the striking face +X, the little finger's side -Y) and a three-quarter
## view, on every body (8 chibi bodies + KayKit), idle: one sheet, a row per body.
##   godot --rendering-driver opengl3 --resolution 256x256 --path . res://tests/tools/knuckle_views.tscn -- OUT_PNG [LOOK]
const CELL := 256
const VIEWS := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, -1, 0), Vector3(0.6, 0.35, 0.75)]


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
	else:
		weapon = ItemData.generate(int(look_id.trim_prefix("wraps_")) * 10 + 5, &"muaythai", rng, 0, "weapon")
	weapon["plus"] = 0
	var bodies: Array = []
	for gender in 2:
		for body in ChibiBodies.count(gender):
			bodies.append([gender, body])
	bodies.append([2, 0])
	var cam := Camera3D.new(); add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.01
	var sheet := Image.create(CELL * VIEWS.size(), CELL * bodies.size(), false, Image.FORMAT_RGBA8)
	for i in bodies.size():
		var entry: Array = bodies[i]
		var look := FaceKit.default_look()
		if entry[0] != 2:
			look["gender"] = entry[0]; look["body"] = entry[1]
		var h := HeroVisual.new(); add_child(h)
		h.setup(&"muaythai", "", true, {"weapon": weapon}, look if entry[0] != 2 else {})
		h.set_process(false)
		h.release(); h.play("Idle", 0.0)
		h.anim.seek(0.3, true); h.anim.pause()
		h._skeleton.force_update_all_bone_transforms()
		await get_tree().process_frame
		var root: Node3D = null
		for n in h._skeleton.get_children():
			if n is BoneAttachment3D and (n as BoneAttachment3D).bone_name == "handslot.r":
				root = n.get_child(0).get_child(0)
		var g := root.global_transform
		var k := g.basis.x.length()
		var at := g * Vector3(-0.04, -0.018, 0.02)
		for v in VIEWS.size():
			var dir: Vector3 = (g.basis * (VIEWS[v] as Vector3)).normalized()
			cam.size = 0.34 * k
			cam.position = at + dir * 2.0 * k
			var up := (g.basis * Vector3(1, 0, 0)).normalized() if v != 1 else (g.basis * Vector3(0, 0, 1)).normalized()
			cam.look_at(at, up)
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(CELL, CELL)
			sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(v * CELL, i * CELL))
		h.queue_free()
		await get_tree().process_frame
	sheet.save_png(out_png)
	get_tree().quit()
