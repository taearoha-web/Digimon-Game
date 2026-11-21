extends Node3D
## Contact sheet of one hero body (ChibiBodies) holding every class's weapon in its
## key poses: a row per class (idle, walk, run, its attack, its cast / weapon clip).
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/weapon_grip_sheet.tscn -- OUT.png GENDER BODY [VIEW] [before]
## VIEW: front | side (default front). "before" plays the gender's original body's
## weapon poses on this body (how the new bodies held their weapons before they had
## their own baked poses).
const FAMILIES := [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard"]
const COLS := 6
const CELL := Vector2i(220, 240)


func _cells(family: StringName) -> Array:
	var data := ClassData.get_class_data(family)
	var attack := String(data.attack.anims[0])
	var extra: Array = {
		&"archer": [["2H_Ranged_Shoot", 0.4], ["2H_Ranged_Shooting", 0.3]],
		&"lancer": [["Martial_GroundSlam", 0.35], ["Martial_SpearThrow", 0.6]],
		&"bard": [["Spellcasting", 0.3], ["Cheer", 0.4]],
		&"defender": [["Blocking", 0.4], ["Spellcast_Shoot", 0.3]],
	}.get(family, [["Spellcast_Shoot", 0.3], ["Spellcast_Long", 0.5]])
	return [["Idle", 0.3], ["Walking_A", 0.25], ["Running_A", 0.75], [attack, 0.4]] + extra


func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.95, 0.97, 1.0); e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 20, 0); l.light_energy = 0.95; add_child(l)
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var gender := int(args[1]) if args.size() > 1 else 0
	var body := int(args[2]) if args.size() > 2 else 0
	var view := args[3] if args.size() > 3 else "front"
	var before := args.size() > 4 and args[4] == "before"
	get_viewport().size = CELL
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 34; cam.position = Vector3(0, 1.15, 4.6); cam.rotation_degrees = Vector3(-4, 0, 0)
	var sheet := Image.create(CELL.x * COLS, CELL.y * FAMILIES.size(), false, Image.FORMAT_RGBA8)
	var look := FaceKit.default_look(); look["gender"] = gender; look["body"] = body
	var rng := RandomNumberGenerator.new()
	for row in FAMILIES.size():
		var family: StringName = FAMILIES[row]
		var cells := _cells(family)
		for col in mini(cells.size(), COLS):
			var cell: Array = cells[col]
			rng.seed = 7
			var equip := {"weapon": ItemData.generate(55, family, rng, 0, "weapon")}
			var h := HeroVisual.new(); add_child(h)
			h.setup(family, "", true, equip, look)
			if before:
				WeaponPoses.install(h.anim, h._skeleton, family, HeroVisual.CHIBI_MODELS[gender], {}, h._gear_scale)
			h.rotation_degrees.y = 90.0 if view == "side" else 30.0
			var clip := String(cell[0])
			if h.anim.has_animation(clip):
				h.anim.play(clip, 0.0)
				h.anim.seek(h.anim.get_animation(clip).length * float(cell[1]), true)
				h.anim.pause()
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
			h.queue_free()
			await get_tree().process_frame
	sheet.save_png(out)
	get_tree().quit()
