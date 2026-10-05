extends Node
## Renders each skill of one class and stitches the frames into a contact sheet.
## godot --rendering-driver opengl3 --path . res://tests/tools/vfx_sheet.tscn -- out.png <class> [frame_times...]
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var class_id := StringName(args[1])
	var times: Array[float] = [0.3, 0.6]
	if args.size() > 2:
		times = []
		for i in range(2, args.size()):
			times.append(float(args[i]))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	main.title_screen.queue_free()
	main.title_screen = null
	Game.new_profile(class_id, "t")
	Game.profile.level = 14
	Game.profile.skill_points = 14
	Game.profile_changed.emit()
	main.hud.visible = true
	await main.go(&"meadow", true)
	await get_tree().create_timer(0.8).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	for n in get_tree().get_nodes_in_group("mobs"):
		n.queue_free()
	zone.set_process(false)
	hero.global_position = Vector3(-18, 0.2, 2)
	zone.camera_rig.snap_to_target()
	await get_tree().create_timer(0.4).timeout
	var frames: Array[Image] = []
	for i in 4:
		var pack: Array[Mob] = []
		for j in 5:
			var m := Mob.new()
			m.setup(&"green_slime", 3, hero.global_position + Vector3((3.4 if class_id == &"warrior" else 7.5) + (j % 3) * 1.3, 0, -1.2 + (j / 3) * 2.0 + j * 0.15), hero)
			m.position = m.home + Vector3(0, 0.3, 0)
			m.set_physics_process(false)
			zone.add_child(m)
			pack.append(m)
		await get_tree().create_timer(0.6).timeout
		hero.set_target(pack[1])
		hero.cooldowns.clear()
		Game.profile.mp = 999
		hero.use_skill(i)
		var t := 0.0
		for ft in times:
			await get_tree().create_timer(ft - t).timeout
			t = ft
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			# Crop the action area at full resolution (no downscale).
			frames.append(img.get_region(Rect2i(320, 60, 640, 360)))
		await get_tree().create_timer(1.6).timeout
		for m in pack:
			if is_instance_valid(m):
				m.queue_free()
		await get_tree().create_timer(0.3).timeout
	var cols := times.size()
	var sheet := Image.create(640 * cols, 360 * 4, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 640, 360), Vector2i((i % cols) * 640, (i / cols) * 360))
	sheet.save_png(out)
	get_tree().quit()
