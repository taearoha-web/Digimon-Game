extends Node
## Screenshots of the forge (the jewels in the bag, the enhance button above the
## scrolling text, after a hit and after a miss).
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/forge_shots.tscn -- <out_dir>
var out_dir := "user://shots"
var main: Node
var _n := 0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _n, name]
	_n += 1
	img.save_png(path)
	print("SHOT ", path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"warrior", "ทดสอบ")
	Game.profile["level"] = 40
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await _wait(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 10:
		Game.add_item(ItemData.generate(38, &"warrior", rng, 2 + i % 3, ItemData.SLOTS[i % 4]))
	Game.add_item(ItemData.jewel("purple", 7))
	Game.add_item(ItemData.jewel("pink", 3))
	main.menu.forge_mode = true
	main._open_menu(&"inventory")
	await _wait(0.5)
	main.menu._selected_index = 3
	main.menu._refresh_detail()
	await _wait(0.3)
	await _shot("forge")
	var btn: Button = null
	for b in main.menu.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("ตีบวก +"):
			btn = b
	if btn != null:
		btn.pressed.emit()
	await _wait(0.4)
	await _shot("forge_after_hit")
	get_tree().quit()
