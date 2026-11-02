extends Node
## How long each town screen takes to show: the open call and the next frames (layout,
## text shaping, icons) one by one, in the real Main scene with an endgame hero.
##   godot --headless --path . res://tests/tools/ui_open_probe.tscn -- [class] [repeats]

var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var family := StringName(args[0]) if args.size() > 0 else &"darklord"
	var repeats := int(args[1]) if args.size() > 1 else 2
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.delete_save()
	Game.new_profile(family, "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 200
	for skill in ClassData.pool(family):
		Game.profile.skills[String(skill.id)] = 5
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(family, 200, slot, Game.rng)
	for i in 30:
		Game.add_item(ItemData.generate(100, family, Game.rng, 1, ItemData.SLOTS[i % ItemData.SLOTS.size()]))
	Game.fill_loadout()
	await main.go(&"town", true)
	await get_tree().create_timer(1.0).timeout
	var screens: Array = []
	for tab in GameMenu.TABS:
		screens.append(["menu:" + String(tab[0]), func(): main.menu.open_menu(StringName(tab[0])), func(): main.menu.close_menu()])
	screens.append(["forge", func():
		main.menu.forge_mode = true
		main.menu.open_menu(&"inventory"), func():
		main.menu.close_menu()
		main.menu.forge_mode = false])
	for pair in [[main.shop, "open_shop", "close_shop"], [main.storage, "open_storage", "close_storage"],
			[main.trainer, "open_trainer", "close_trainer"], [main.warp, "open_warp", "close_warp"],
			[main.pvp_screen, "open_lobby", "close_screen"], [main.guildwar_screen, "open_lobby", "close_screen"],
			[main.tower_screen, "open_lobby", "close_screen"]]:
		var target: Object = pair[0]
		screens.append([String(pair[1]) + ":" + String(target.get_script().get_global_name()), Callable(target, pair[1]), Callable(target, pair[2])])
	for r in repeats:
		for s in screens:
			await _measure(r, s[0], s[1], s[2])
	get_tree().quit()


func _measure(r: int, label: String, open: Callable, close: Callable) -> void:
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	open.call()
	var call_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var frames: PackedStringArray = []
	var last := Time.get_ticks_usec()
	var total := call_ms
	for i in 3:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		frames.append("%.0f" % ms)
		total += ms
		last = now
	close.call()
	print("OPEN r%d %-28s call=%6.1fms frames=[%s] total=%6.1fms" % [r, label, call_ms, ", ".join(frames), total])
