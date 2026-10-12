extends Node
## Isolated regression for point conservation, persistence and paused-menu input.

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	Game.slot = 1
	Game.new_profile(&"mage", "ทดสอบอัปแต้ม", FaceKit.default_look())
	Game.profile.level = 14
	Game.profile.points = 39
	var before: Dictionary = Game.profile.attrs.duplicate(true)
	var notifications := [0]
	var on_change := func(): notifications[0] += 1
	Game.profile_changed.connect(on_change)
	for entry in [["str", 3], ["int", 20], ["dex", 2], ["vit", 4]]:
		check(Game.spend_point(entry[0], entry[1]), "bulk allocation accepts each stat")
		check(int(Game.profile.attrs[entry[0]]) == int(before[entry[0]]) + entry[1], "allocation adds exactly the chosen quantity")
	check(int(Game.profile.points) == 10 and notifications[0] == 4, "39 points minus 29 allocated; one notification per allocation")
	check(Game.spend_point("str") and int(Game.profile.points) == 9, "legacy one-point calls still work")
	var snapshot := Game.profile.duplicate(true)
	Game._dirty = false
	var signal_count: int = notifications[0]
	for entry in [["int", 0], ["int", -5], ["int", 10], ["int", 999999999], ["gold", 1], ["unknown", 1]]:
		check(not Game.spend_point(entry[0], entry[1]), "invalid allocation is rejected")
		check(Game.profile == snapshot and not Game._dirty and notifications[0] == signal_count, "rejected allocation leaves profile, save state and notifications untouched")
	Game.profile_changed.disconnect(on_change)
	check(Game.save(), "bulk allocation can be saved")
	Game.profile.points = 0
	Game.profile.attrs.int = 0
	check(Game.load_game(1) and int(Game.profile.points) == 9 and Game.profile.attrs == snapshot.attrs, "reload restores allocated attributes and remaining points")
	check(Game.save_code_roundtrip(), "allocated profile retains existing backup/cloud-save representation")
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().paused, "quantity inputs operate while the character menu pauses gameplay")
	for key in ["str", "int", "dex", "vit"]:
		var input := menu.find_child("StatAmount_" + key, true, false) as LineEdit
		check(input != null and input.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER, "each stat offers the numeric phone keyboard")
	for text in ["", "0", "-1", "1.5", "+2", "abc", "10", "999999999"]:
		set_amount(menu, "int", text)
		var button := menu.find_child("StatAdd_int", true, false) as Button
		check(button.disabled, "invalid or unaffordable quantity disables allocation: " + text)
		button.pressed.emit()
		check(int(Game.profile.points) == 9, "invalid UI input cannot consume points")
	set_amount(menu, "int", "5")
	var add := menu.find_child("StatAdd_int", true, false) as Button
	check(not add.disabled, "valid quantity enables allocation")
	add.pressed.emit()
	await get_tree().process_frame
	check(int(Game.profile.points) == 4 and int(Game.profile.attrs.int) == int(snapshot.attrs.int) + 5, "one menu action adds five INT and deducts five points")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(1))).points) == 4, "menu allocation is persisted immediately instead of waiting for autosave")
	var retained := menu.find_child("StatAmount_int", true, false) as LineEdit
	check(retained.text == "5" and (menu.find_child("StatAdd_int", true, false) as Button).disabled, "rebuild retains the quantity and checks it against the new balance")
	set_amount(menu, "vit", "4")
	(menu.find_child("StatAmount_vit", true, false) as LineEdit).text_submitted.emit("4")
	await get_tree().process_frame
	check(int(Game.profile.points) == 0 and int(Game.profile.attrs.vit) == int(snapshot.attrs.vit) + 4, "keyboard submission can allocate the exact remaining balance")
	check(int(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(1))).points) == 0, "spending the final balance is persisted immediately")
	for key in ["str", "int", "dex", "vit"]:
		check((menu.find_child("StatAdd_" + key, true, false) as Button).disabled and not (menu.find_child("StatAmount_" + key, true, false) as LineEdit).editable, "zero balance disables all allocation controls")
	check(not Game.spend_point("str"), "no allocation can make the balance negative")
	menu.close_menu()
	menu.queue_free()
	await get_tree().process_frame
	check(Game.save() and Game.load_game(1) and int(Game.profile.points) == 0, "all-point allocation survives another save and reload")
	# Allow the headless audio driver to release the menu click/open voices.
	for player in AudioManager._ui_pool:
		player.stop()
		player.stream = null
	AudioManager._stream_cache.clear()
	await get_tree().create_timer(0.1).timeout
	print("BULK STATS: %d checks, %d failures" % [checks, failures])
	Game.has_profile = false
	get_tree().quit(0 if failures == 0 else 1)


func set_amount(menu: GameMenu, key: String, text: String) -> void:
	var input := menu.find_child("StatAmount_" + key, true, false) as LineEdit
	input.text = text
	input.text_changed.emit(text)
