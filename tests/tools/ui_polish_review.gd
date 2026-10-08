extends Node
## Layout assertions plus an optional fully populated eight-skill screenshot.
## Run with a fresh XDG_DATA_HOME to isolate fixture saves.
## godot --headless --path . res://tests/tools/ui_polish_review.tscn
## godot --path . res://tests/tools/ui_polish_review.tscn -- /absolute/shot-folder

var _failed := 0


func _ready() -> void:
	for canvas in [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 960)]:
		_check_layout(canvas)
	_check_layout(Vector2(1280, 720), Vector4(44, 0, 44, 24))
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	_check(main.title_screen._preview != null, "title uses a live selected hero preview")
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.new_profile(&"mage", "ลูน่า")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.fill_loadout()
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	main.hud.visible = true
	await main.go(&"meadow", true)
	await get_tree().create_timer(1.0).timeout
	var filled := 0
	for slot in main.hud.skill_slots:
		if not slot.skill.is_empty():
			filled += 1
	_check(filled == 8, "all eight skill slots are populated in the capture fixture")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(args[0])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0].path_join("hud_eight_skills.png"))
		main.menu.open_menu(&"inventory")
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0].path_join("inventory_polish.png"))
		main.menu.close_menu()
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("ui_polish_review: %d failures" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)


func _check_layout(canvas: Vector2, insets := Vector4.ZERO) -> void:
	var origin := Vector2(16 + insets.x, 16 + insets.y)
	var frame := canvas - origin - Vector2(16 + insets.z, 16 + insets.w)
	var positions := HUD.action_layout(frame)
	var rectangles: Array[Rect2] = []
	for i in positions.skills.size():
		var center: Vector2 = positions.skills[i]
		_check(is_equal_approx(center.y, positions.skills[0].y), "all eight skills share one bottom row")
		if i > 0:
			_check(center.x > positions.skills[i - 1].x, "skills follow slot order from left to right")
		var half_width := maxf(39.6, minf(86.0, positions.skill_spacing - 6.0) * 0.5)
		# Include the enlarged touch circle and the name drawn below each slot.
		rectangles.append(Rect2(frame + center - Vector2(half_width, 40), Vector2(half_width * 2, 102)))
	for i in positions.utility.size():
		var center: Vector2 = positions.utility[i]
		_check(is_equal_approx(center.x, positions.utility[0].x), "utilities form one far-right column")
		_check(frame.y + center.y - 30.8 > 242.0, "utility touch areas clear the minimap")
		if i > 0:
			_check(center.y > positions.utility[i - 1].y, "utilities follow HP, MP, auto, target from top to bottom")
		rectangles.append(Rect2(frame + center - Vector2.ONE * 30.8, Vector2.ONE * 61.6))
	rectangles.append(Rect2(frame + positions.attack - Vector2.ONE * 68.2, Vector2.ONE * 136.4))
	var joystick_center := Vector2(150, canvas.y - 150)
	for i in rectangles.size():
		var rect := rectangles[i]
		_check(Rect2(Vector2.ZERO, frame).encloses(rect), "control %d stays inside %s safe frame" % [i, canvas])
		var global_rect := Rect2(origin + rect.position, rect.size)
		var nearest := Vector2(clampf(joystick_center.x, global_rect.position.x, global_rect.end.x), clampf(joystick_center.y, global_rect.position.y, global_rect.end.y))
		_check(nearest.distance_to(joystick_center) > 104.0 * 1.45, "control %d leaves joystick touch circle clear" % i)
		for j in range(i + 1, rectangles.size()):
			_check(not rect.intersects(rectangles[j]), "controls %d and %d do not overlap" % [i, j])


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
		push_error(label)
