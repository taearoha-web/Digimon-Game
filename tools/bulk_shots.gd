extends Node
## Screenshots of the bulk-action UI (count chooser, gear multi-select, fuse summary,
## shop and storage bulk buttons) into the directory in the BULK_SHOTS env var.
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/bulk_shots.tscn

var out := ""


func _ready() -> void:
	out = OS.get_environment("BULK_SHOTS")
	if out == "":
		out = "user://"
	Game.set_process(false)
	Game.new_profile(&"warrior", "ขายส่ง", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.gold = 5000000
	Game.profile.bag_slots = Game.MAX_BAG
	Game.profile.inv.clear()
	Game.add_item(ItemData.potion("hp_s", 1240))
	Game.add_item(ItemData.gem("ruby", 2, 172))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 14:
		var it := ItemData.generate(40 + i, &"warrior", rng, i % 4, ItemData.SLOTS[i % ItemData.SLOTS.size()])
		if i == 3:
			it["plus"] = 5
		if i == 2:
			ItemData.set_locked(it, true)
		Game.profile.inv.append(it)
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await _frames(4)
	# 0. a locked piece (ล็อก): the padlock on its tile, the note and ปลดล็อก in the panel.
	menu._selected_index = 4
	menu._rebuild()
	await _frames(3)
	_shot("0_bag_locked")
	menu._selected_index = -1
	menu._rebuild()
	await _frames(2)
	# 1. the multi-select with a quick pick.
	(menu.find_child("MultiSellToggle", true, false) as Button).pressed.emit()
	await _frames(3)
	(menu.find_child("MultiPick1", true, false) as Button).pressed.emit()
	await _frames(3)
	_shot("1_gear_multi_select")
	# 2. the stack sell chooser.
	menu._set_multi_sell(false)
	menu._selected_index = 0
	menu._rebuild()
	await _frames(3)
	(menu.find_child("StackSell", true, false) as Button).pressed.emit()
	await _frames(3)
	var picker := menu.find_child("QtyPicker", true, false) as QtyPicker
	(picker.find_child("StepPlus100", true, false) as Button).pressed.emit()
	(picker.find_child("StepPlus10", true, false) as Button).pressed.emit()
	await _frames(12)
	_shot("2_sell_quantity")
	(picker.find_child("QtyCancel", true, false) as Button).pressed.emit()
	await _frames(2)
	# 3. fuse many: the chooser, then the summary.
	menu._selected_index = 1
	menu._rebuild()
	await _frames(3)
	_shot("3_gem_detail")
	(menu.find_child("FuseTimes", true, false) as Button).pressed.emit()
	await _frames(3)
	picker = menu.find_child("QtyPicker", true, false) as QtyPicker
	(picker.find_child("QtyAll", true, false) as Button).pressed.emit()
	await _frames(12)
	_shot("4_fuse_chooser")
	Game.rng.seed = 11
	(picker.find_child("QtyConfirm", true, false) as Button).pressed.emit()
	await _frames(14)
	_shot("5_fuse_result")
	for dialog in menu.find_children("*", "ModalDialog", true, false):
		dialog.queue_free()
	menu.close_menu()
	await _frames(2)
	# 6. the merchant's bulk gear buttons, 7. the storage's bulk moves.
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_shop()
	await _frames(6)
	_shot("6_shop")
	shop.close_shop()
	var store := StorageScreen.new()
	add_child(store)
	store.open_storage()
	await _frames(6)
	_shot("7_storage")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(shot_name + ".png"))
	print("shot ", shot_name)
