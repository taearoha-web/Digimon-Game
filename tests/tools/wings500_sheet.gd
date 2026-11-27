extends Node3D
## Every class's ★500 wings (Star500WingArt) on the hero in the full ★500 set, from
## behind at three-quarters, in one sheet with the class names (the art check for
## ปีกเทวาลัย: each class's pair must read as its own at play distance).
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/wings500_sheet.tscn -- [OUT.png] [fly|front]
## Writes OUT.png (default build/wings500_sheet.png). "fly": the pairs spread in flight;
## "front": from the front three-quarter instead.
const COLS := 6
const TILE := Vector2i(400, 460)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://build/wings500_sheet.png")
	var fly := args.size() > 1 and args[1] == "fly"
	var front := args.size() > 1 and args[1] == "front"
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	get_window().size = TILE
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("a9c8e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20 if front else 160, 0); l.light_energy = 0.95; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("9fcf8c")); add_child(g)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 34
	var label := Label3D.new(); label.font_size = 64; label.outline_size = 14; label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test = true; add_child(label)
	var tiles: Array[Image] = []
	for cls in StarGearData.CLASSES:
		var equip := {}
		for slot in Star500Gear.SLOTS:
			equip[slot] = Star500Gear.item(cls, slot)
		var h := HeroVisual.new(); add_child(h)
		h.setup(StringName(cls), "", true, equip, FaceKit.default_look())
		if fly:
			h.set_wing_mode(HeroVisual.WING_FLY, true)
		var mid := Vector3(0, 1.6, 0)
		cam.position = mid + Vector3(4.9, 1.2, 9.4 if front else -9.4)
		cam.look_at(mid, Vector3.UP)
		label.text = cls
		label.position = Vector3(0, -0.25, 0)
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		tiles.append(get_viewport().get_texture().get_image())
		h.queue_free()
		await get_tree().process_frame
	var rows := ceili(tiles.size() / float(COLS))
	# (Cropped under the names: only grass below.)
	var size := Vector2i(tiles[0].get_width(), mini(tiles[0].get_height(), 385))
	var sheet := Image.create(size.x * COLS, size.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("a9c8e8"))
	for i in tiles.size():
		var img := tiles[i]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, size), Vector2i((i % COLS) * size.x, (i / COLS) * size.y))
	sheet.save_png(out)
	print("wings500 sheet: ", out)
	get_tree().quit()
