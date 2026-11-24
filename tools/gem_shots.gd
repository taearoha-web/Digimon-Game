extends Node
## Screenshots of the forge's gem socketing (the side panel of a selected piece and the
## ใส่อัญมณี picker, GemPicker) with a bag of many gem types and sizes in a mixed order,
## into the directory in the GEM_SHOTS env var (user:// when unset). GEM_SHOTS_TAG
## (default "after") prefixes the shot names.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/gem_shots.tscn

var out := ""
var tag := ""


func _ready() -> void:
	out = OS.get_environment("GEM_SHOTS")
	if out == "":
		out = "user://"
	tag = OS.get_environment("GEM_SHOTS_TAG")
	if tag == "":
		tag = "after"
	Game.set_process(false)
	Game.new_profile(&"warrior", "ช่างอัญมณี", FaceKit.default_look())
	Game.profile.level = 90
	Game.profile.gold = 5000000
	Game.profile.bag_slots = Game.MAX_BAG
	Game.profile.inv.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var weapon := ItemData.generate(88, &"warrior", rng, 4, "weapon")
	weapon["sockets"] = 3
	weapon["gems"] = ["ruby_3"]
	weapon["plus"] = 9
	Game.profile.inv.append(weapon)
	# The player's bag from the report: gems picked up in any order, gear between them.
	for g in [["tourmaline", 1, 5], ["amethyst", 0, 1], ["topaz", 0, 2], ["ruby", 2, 32], ["ruby", 1, 21],
			["amethyst", 1, 12], ["topaz", 1, 17], ["sapphire", 1, 10], ["tourmaline", 2, 2], ["emerald", 0, 8],
			["onyx", 1, 3], ["ruby", 0, 40], ["opal", 0, 4], ["sapphire", 2, 6], ["pearl", 1, 2], ["emerald", 2, 3],
			["ruby", 4, 1], ["amethyst", 2, 5], ["topaz", 3, 1], ["ruby", 3, 2]]:
		Game.add_item(ItemData.gem(g[0], g[1], g[2]))
		if g[0] == "ruby" and g[1] == 1:
			Game.profile.inv.append(ItemData.generate(60, &"warrior", rng, 2, "armor"))
	for i in 4:
		Game.profile.inv.append(ItemData.generate(50 + i, &"warrior", rng, i % 4, ItemData.SLOTS[i % ItemData.SLOTS.size()]))
	Game.add_item(ItemData.jewel("drill", 3))
	var menu := GameMenu.new()
	add_child(menu)
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	await _frames(4)
	menu._selected_index = 0
	menu._rebuild()
	await _frames(4)
	_shot("panel")
	var side := menu._detail.get_parent() as ScrollContainer
	side.scroll_vertical = 100000
	await _frames(4)
	_shot("panel_scrolled")
	side.scroll_vertical = 0
	var open := menu.find_child("GemPickerOpen", true, false) as Button
	if open == null:
		get_tree().quit(0)
		return
	open.pressed.emit()
	await _frames(12)
	_shot("picker")
	var picker := menu.find_child("GemPicker", true, false)
	var rows := picker.find_child("GemRows", true, false) as ScrollContainer
	rows.scroll_vertical = 100000
	await _frames(4)
	_shot("picker_scrolled")
	rows.scroll_vertical = 0
	await _frames(2)
	var tile := picker.find_child("GemTile_ruby_4", true, false) as Button
	if tile != null:
		tile.pressed.emit()
	await _frames(6)
	_shot("picker_after_tap")
	(picker.find_child("GemAutoBest", true, false) as Button).pressed.emit()
	await _frames(12)
	_shot("picker_auto_confirm")
	for dialog in menu.find_children("*", "ModalDialog", true, false):
		dialog.queue_free()
	picker.close_sheet()
	await _frames(6)
	_shot("panel_after")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s_%s.png" % [tag, shot_name]))
	print("shot ", shot_name)
