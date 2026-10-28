extends Node3D
## The Dark Lord's raven in each of its looks (DarkRaven.Look, from the scepter):
## Lv.10-40, the five Lv.50-90 themes, Lv.100, a star scepter and the divine one.
## For each, a close shot of it perched on the Lord's arm (beside the face) and one
## of it flying (wings spread, the stardust trailing), then a contact sheet.
##   godot --rendering-driver opengl3 --path . res://tests/tools/raven_looks.tscn -- OUT_DIR [QUALITY] [GENDER]

## Stands in for the Lord that owns the raven (DarkRaven reads `visual`).
class Lord extends Node3D:
	var visual: HeroVisual

	func raven_target() -> Mob:
		return null

	func raven_strike(_mob: Mob, _group := false) -> void:
		pass

	func is_dead() -> bool:
		return false

const SHOT := Vector2i(640, 400)
var camera: Camera3D
var title: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = int(args[1]) if args.size() > 1 else 2
	get_window().size = SHOT
	get_window().content_scale_size = SHOT
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = []
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	camera = Camera3D.new()
	camera.fov = 34
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_shadow_color", Color("283540"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(title)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := &"darklord"
	var shots: Array = [
		["t0", "Lv.10 คทาราชันฝึกหัด", ItemData.generate(5, a, rng, 2, "weapon")],
		["t4_fire", "Lv.50 มังกรเพลิง", ItemData.generate(45, a, rng, 2, "weapon")],
		["t5_ice", "Lv.60 น้ำแข็ง", ItemData.generate(55, a, rng, 2, "weapon")],
		["t6_shadow", "Lv.70 เงามืด", ItemData.generate(65, a, rng, 2, "weapon")],
		["t7_holy", "Lv.80 ศักดิ์สิทธิ์", ItemData.generate(75, a, rng, 2, "weapon")],
		["t8_thunder", "Lv.90 สายฟ้า", ItemData.generate(85, a, rng, 2, "weapon")],
		["t9_crown", "Lv.100 คทาจักรพรรดิเทพ", ItemData.generate(95, a, rng, 3, "weapon")],
		["star200", "★200 คทาจักรพรรดิคราส", StarProgression.item(a, 200, "weapon", rng)],
		["divine", "คทาจักรพรรดิอีกาทมิฬ (เทพ)", DivineGearData.item(a, "weapon", rng)],
	]
	var files: Array[String] = []
	for shot in shots:
		var lord := Lord.new()
		add_child(lord)
		var hv := HeroVisual.new()
		lord.add_child(hv)
		var weapon: Dictionary = shot[2]
		weapon["plus"] = 0
		var face := FaceKit.default_look()
		face["gender"] = int(args[2]) if args.size() > 2 else 0
		hv.setup(a, "", true, {"weapon": weapon}, face)
		lord.visual = hv
		hv.rotation_degrees.y = 20
		var raven := DarkRaven.ensure(lord)
		await get_tree().create_timer(1.2).timeout
		var name: String = shot[0]
		var label := "%s • %s" % [shot[1], DarkRaven.LOOK_NAMES[raven.look]]
		# Perched, close beside the Lord's face.
		title.text = label + " • เกาะแขน"
		var arm := raven.global_position
		camera.position = arm + Vector3(0.55, 0.32, 1.55)
		camera.look_at(arm + Vector3(-0.22, 0.22, 0))
		await _capture(out_dir, "%s_perch" % name)
		files.append(out_dir.path_join("%s_perch.png" % name))
		# Perched, from the Lord's left and a little above: the folded wing and tail.
		var left := hv.global_basis.x
		camera.position = arm + left * 1.5 + hv.global_basis.z * 0.9 + Vector3(0, 0.35, 0)
		camera.look_at(arm + Vector3(0, 0.15, 0))
		await _capture(out_dir, "%s_perch_back" % name)
		files.append(out_dir.path_join("%s_perch_back.png" % name))
		# Flying: driven along an arc by hand so the shot is the same every run.
		title.text = label + " • บิน"
		raven.set_process(false)
		raven.state = DarkRaven.State.FLY
		var center := Vector3(7, 2.6, -3)
		var clock := 0.0
		var pose := "glide"
		while clock < 1.6:
			await get_tree().process_frame
			var dt := 1.0 / 60.0
			clock += dt
			raven._clock += dt
			var ang := -2.6 + clock * 3.2
			var at := center + Vector3(cos(ang) * 2.2, sin(clock * 2.0) * 0.1, sin(ang) * 2.2)
			var ahead := center + Vector3(cos(ang + 0.1) * 2.2, 0, sin(ang + 0.1) * 2.2)
			raven.global_position = at
			raven.look_at(Vector3(ahead.x, at.y, ahead.z), Vector3.UP, true)
			raven._bank = lerpf(raven._bank, 24.0, dt * 4.0)
			pose = "flap" if clock < 0.9 else "glide"
			raven._animate(dt, pose)
		# From above and outside the circle: the spread wings and the trail behind.
		var heading := raven.global_basis.z
		var out := Vector3(raven.global_position.x - center.x, 0, raven.global_position.z - center.z).normalized()
		camera.position = raven.global_position + out * 0.9 - heading * 0.9 + Vector3(0, 2.6, 0)
		camera.look_at(raven.global_position - heading * 0.7)
		await _capture(out_dir, "%s_fly" % name)
		files.append(out_dir.path_join("%s_fly.png" % name))
		lord.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_contact_sheet(files, out_dir.path_join("raven_looks_sheet.png"))
	get_tree().quit()


func _capture(out_dir: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))


## Three columns (perched front, perched behind, flying), one row per look, at half size.
func _contact_sheet(files: Array[String], path: String) -> void:
	var tile := SHOT / 2
	var rows := files.size() / 3
	var sheet := Image.create(tile.x * 3, tile.y * rows, false, Image.FORMAT_RGBA8)
	for i in files.size():
		var img := Image.load_from_file(files[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i((i % 3) * tile.x, (i / 3) * tile.y))
	sheet.save_png(path)
