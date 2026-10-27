extends Node
## The title screen with all ten character slots filled (the list scrolls), on a
## phone-sized window: one shot at the top, one scrolled to the last slot.
##   godot --rendering-driver opengl3 --resolution 1600x736 --path . res://tests/tools/slots_preview.tscn -- OUT_DIR
func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	GameSettings.load_settings()
	var classes: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"warrior"]
	for i in Game.SLOT_COUNT:
		Game.slot = i + 1
		Game.new_profile(classes[i], "ฮีโร่%d" % (i + 1), FaceKit.default_look())
		Game.profile["level"] = 10 + i * 9
		Game.save()
	var menu := MainMenu.new()
	add_child(menu)
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/slots_top.png")
	menu._scroll.scroll_vertical = 100000
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/slots_bottom.png")
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	get_tree().quit()
