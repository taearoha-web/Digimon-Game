extends Node
## Layout assertions (the action buttons, the world-event chip under the daily tracker,
## the world chat) plus an optional fully populated eight-skill screenshot.
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
	_check(main.title_screen.stage != null and main.title_screen.stage.camera != null, "title shows the hero platform stage")
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
	await _check_event_chip_live(main.hud)
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
	# The world-event chip under the daily tracker (two or three lines) with its longest
	# line: clear of the minimap, the tracker, the utility column (with the dark lord's
	# raven buttons left of the auto button), the top-right chips and the frame's edge.
	var others := {"minimap": Rect2(frame.x - 150.0, 102.0, 140.0, 140.0), "top right chips": Rect2(frame.x - 560.0, 0.0, 560.0, 76.0),
		"raven": Rect2(frame + positions.utility[2] + Vector2(-72.0, 0.0) - Vector2.ONE * 30.8, Vector2.ONE * 61.6),
		"raven mode": Rect2(frame + positions.utility[2] + Vector2(-72.0, -72.0) - Vector2.ONE * 30.8, Vector2.ONE * 61.6)}
	for i in positions.utility.size():
		others["utility %d" % i] = Rect2(frame + positions.utility[i] - Vector2.ONE * 30.8, Vector2.ONE * 61.6)
	for lines in [2, 3]:
		var tracker_height := _text_height(&"SmallLabel", lines)
		others["tracker"] = Rect2(frame.x - 480.0, HUD.TRACKER_TOP, 480.0 + HUD.TRACKER_RIGHT, tracker_height)
		var chip := HUD.event_chip_rect(frame, tracker_height, Vector2(430.0, _text_height(&"SmallLabel", 1) + 12.0))
		_check(Rect2(Vector2.ZERO, frame).encloses(chip), "event chip under %d tracker lines stays inside %s safe frame" % [lines, canvas])
		for key in others:
			_check(not chip.intersects(others[key]), "event chip under %d tracker lines clears the %s at %s" % [lines, key, canvas])


## The height of [param lines] lines of a label of the theme's [param variation].
func _text_height(variation: StringName, lines: int) -> float:
	var label := UIUtil.label("\n".join(PackedStringArray(Array(range(lines)).map(func(_i): return "รายวัน: เสร็จ 0/3"))), variation)
	add_child(label)
	var height := label.get_combined_minimum_size().y
	label.queue_free()
	return height


## The real chip with its longest line, placed by the HUD, against the real controls.
func _check_event_chip_live(hud: HUD) -> void:
	hud._event_in = 1.0e9
	hud._event_label.text = "โบนัสทอง +20% · บอสโลกที่ ทุ่งหญ้ามิสต์วูด 12 นาที"
	hud._event_chip.visible = true
	hud._tracker_timer = 1.0e9
	hud._tracker.visible = true
	hud._tracker.text = "เควสต์: กำจัดหมาป่าเงาในทุ่งหญ้า 7/10\nรายวัน: เสร็จ 1/3"
	hud._place_event_chip()
	await get_tree().process_frame
	await get_tree().process_frame
	var chip := hud._event_chip.get_global_rect()
	_check(chip.size.x > 300.0 and chip.size.y > 20.0, "event chip grew to its long line (%s)" % chip)
	var named := {"minimap": hud.minimap, "tracker": hud._tracker, "hp potion": hud.hp_potion, "mp potion": hud.mp_potion, "auto": hud.auto_button,
		"target": hud.target_button, "raven": hud.raven_button, "raven mode": hud.raven_mode_button,
		"online chip": hud._frame.find_child("OnlineChip", true, false), "chat chip": hud._frame.find_child("ChatChip", true, false),
		"gold chip": hud._gold_label.get_parent().get_parent()}
	for key in named:
		var other: Control = named[key]
		_check(not chip.intersects(other.get_global_rect()), "live event chip %s clears the %s %s" % [chip, key, other.get_global_rect()])
	var chat := hud.world_chat.get_global_rect()
	_check(not chat.intersects(hud.skill_slots[0].get_global_rect().grow(4.0)), "world chat %s clears the first skill" % chat)


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failed += 1
		push_error(label)
