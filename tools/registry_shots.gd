extends Node
## Screenshots of the game registry's pages (RegistryScreen): the first page, the next,
## the last, a name search and the online filter, in a world of the ROSTER and its
## newcomers some weeks on (REGISTRY_DAYS, default 30).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tools/registry_shots.tscn
## REGISTRY_SHOTS: the folder the PNGs go to (default user://).

var out := ""


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("registry_%s.png" % shot_name))
	print("saved ", out.path_join("registry_%s.png" % shot_name))


func _ready() -> void:
	out = OS.get_environment("REGISTRY_SHOTS")
	if out == "":
		out = "user://"
	var days := float(OS.get_environment("REGISTRY_DAYS")) if OS.get_environment("REGISTRY_DAYS") != "" else 30.0
	Game.set_process(false)
	WorldPlayers.persist = false
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + days * 86400.0 + 13.0 * 3600.0 - WorldPlayers.now()
	Game.new_profile(&"warrior", "นักทะเบียน", FaceKit.default_look())
	Game.profile.level = 42
	var screen := RegistryScreen.new()
	add_child(screen)
	await _frames(2)
	screen.open_screen()
	await _frames(6)
	_shot("page1")
	(screen.find_child("PageNext", true, false) as Button).pressed.emit()
	await _frames(6)
	_shot("page2")
	for k in screen.page_count():
		(screen.find_child("PageNext", true, false) as Button).pressed.emit()
	await _frames(6)
	_shot("last_page")
	var box := screen.find_child("Search", true, false) as LineEdit
	box.text = "น้อง"
	box.text_changed.emit(box.text)
	await _frames(6)
	_shot("search")
	box.text = ""
	box.text_changed.emit("")
	(screen.find_child("Filter_online", true, false) as Button).pressed.emit()
	await _frames(6)
	_shot("online")
	get_tree().paused = false
	get_tree().quit(0)
