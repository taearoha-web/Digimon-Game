extends Node3D
## Every class in its full ★500 set (ชุดเทวาลัย, Star500Gear: seven pieces, weapon +15),
## in one sheet from the front three-quarter and one from behind (the wings), plus
## close-ups of three weapons.
##   xvfb-run godot --rendering-driver opengl3 --resolution 360x420 --path . res://tests/tools/star500_sheet.tscn -- OUT_DIR [PLUS]
## Writes OUT_DIR/star500_front.png, star500_back.png, star500_weapon_<kind>.png.
const COLS := 6
const WEAPONS := ["warrior", "mage", "defender"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var plus := int(args[1]) if args.size() > 1 else 15
	DirAccess.make_dir_recursive_absolute(out_dir)
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("bcd6ee")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fcf8c")); add_child(g)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 30
	var tiles := {"front": [], "back": []}
	for cls in StarGearData.CLASSES:
		var equip := {}
		for slot in Star500Gear.SLOTS:
			equip[slot] = Star500Gear.item(cls, slot)
		equip["weapon"]["plus"] = plus
		var h := HeroVisual.new(); add_child(h)
		h.setup(StringName(cls), "", true, equip, FaceKit.default_look())
		var mid := Vector3(0, 1.05, 0)
		for shot in ["front", "back"]:
			cam.position = mid + (Vector3(2.0, 0.5, 7.6) if shot == "front" else Vector3(1.6, 0.9, -7.6))
			cam.look_at(mid, Vector3.UP)
			await get_tree().create_timer(0.7).timeout
			await RenderingServer.frame_post_draw
			tiles[shot].append(get_viewport().get_texture().get_image())
		h.queue_free()
		await get_tree().process_frame
	for shot in tiles:
		var list: Array = tiles[shot]
		var rows := ceili(list.size() / float(COLS))
		var size := Vector2((list[0] as Image).get_size())
		var sheet := Image.create(int(size.x) * COLS, int(size.y) * rows, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("bcd6ee"))
		for i in list.size():
			var img: Image = list[i]
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % COLS) * int(size.x), (i / COLS) * int(size.y)))
		sheet.save_png("%s/star500_%s.png" % [out_dir, shot])
	# Weapons up close, turned a little, on the sky.
	g.visible = false
	get_window().size = Vector2i(720, 720)
	await get_tree().process_frame
	for cls in WEAPONS:
		var look := Star500Gear.look_id(cls, "weapon")
		var w := Star500GearArt.build(look)
		add_child(w)
		w.rotation_degrees = Vector3(0, -25, -20 if Star500Gear.weapon_kind(cls) != "greatshield" else 0)
		var box := AABB()
		var first := true
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		var c := box.get_center()
		var span := maxf(box.size.y, box.size.x)
		cam.position = c + Vector3(0, 0, span * 2.1)
		cam.look_at(c, Vector3.UP)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/star500_weapon_%s.png" % [out_dir, Star500Gear.weapon_kind(cls)])
		w.queue_free()
		await get_tree().process_frame
	get_tree().quit()
