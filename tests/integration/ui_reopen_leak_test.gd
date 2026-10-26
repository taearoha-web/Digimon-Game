extends Node
## Opening and closing a screen must not leave anything behind: every menu tab, the forge,
## the shop, storage, skill trainer, warp map, the duel / guild-war / tower lobbies and the
## elder's dialogue are opened and closed many times in town, and the town must keep the
## same number of nodes and objects as after the first (warm-up) pass.
##   godot --headless --path . res://tests/integration/ui_reopen_leak_test.tscn
const PASSES := 6
const NODE_TOLERANCE := 4
const OBJECT_TOLERANCE := 12

var main: Node
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Effects a screen plays (the healer's glow) end within a couple of seconds.
func _settle() -> void:
	await get_tree().create_timer(2.5).timeout
	await _frames(4)


func _counts() -> Vector2i:
	return Vector2i(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)))


func _ready() -> void:
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(3)
	Game.delete_save()
	Game.new_profile(&"warrior", "UI", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.gold = 1000000
	Game.add_item(ItemData.potion("hp_xxl", 20))
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(&"warrior", 100, slot, Game.rng)
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	await main.go(&"town", true)
	await _frames(10)
	# Effect materials are held in a bounded ring (MaterialKeeper) so their shaders stay
	# compiled; fill it first, or the healer's glow would read as growth.
	for i in MaterialKeeper.RING_SIZE + 8:
		VfxKit._glow(Color.WHITE, 1.0)
	var screens := _screens()
	for name in screens.keys():
		var action: Callable = screens[name]
		await action.call()
		await _settle()
		var before := _counts()
		var t0 := Time.get_ticks_usec()
		for i in PASSES:
			await action.call()
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / PASSES
		await _settle()
		var after := _counts()
		print("%-22s nodes %+d objects %+d over %d passes, %.0f ms per open+close" % [name, after.x - before.x, after.y - before.y, PASSES, ms])
		check(after.x - before.x <= NODE_TOLERANCE, "%s: %d nodes left behind after %d open/close passes" % [name, after.x - before.x, PASSES])
		check(after.y - before.y <= OBJECT_TOLERANCE, "%s: %d objects left behind after %d open/close passes" % [name, after.y - before.y, PASSES])
	print("UI REOPEN LEAK: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _screens() -> Dictionary:
	var out := {}
	for tab in GameMenu.TABS:
		var id := StringName(tab[0])
		out["menu:%s" % id] = func():
			main.menu.open_menu(id)
			await _frames(2)
			main.menu.close_menu()
			await _frames(2)
	out["menu:all tabs"] = func():
		for tab in GameMenu.TABS:
			main.menu.open_menu(StringName(tab[0]))
			await _frames(2)
		main.menu.close_menu()
		await _frames(2)
	out["forge"] = func():
		main.menu.forge_mode = true
		main.menu.open_menu(&"inventory")
		await _frames(2)
		main.menu.close_menu()
		main.menu.forge_mode = false
		await _frames(2)
	for pair in [["shop", main.shop, "open_shop", "close_shop"], ["storage", main.storage, "open_storage", "close_storage"],
			["trainer", main.trainer, "open_trainer", "close_trainer"], ["warp", main.warp, "open_warp", "close_warp"],
			["pvp lobby", main.pvp_screen, "open_lobby", "close_screen"], ["guild war lobby", main.guildwar_screen, "open_lobby", "close_screen"],
			["tower lobby", main.tower_screen, "open_lobby", "close_screen"], ["game registry", main.registry, "open_screen", "close_screen"],
			["guild registrar", main.guild_screen, "open_screen", "close_screen"]]:
		var screen: Object = pair[1]
		var open_name: String = pair[2]
		var close_name: String = pair[3]
		out[pair[0]] = func():
			screen.call(open_name)
			await _frames(2)
			screen.call(close_name)
			await _frames(2)
	for role in ["elder", "job", "party", "daily", "storage", "skill", "arena", "forge", "healer"]:
		out["npc:%s" % role] = func():
			main._on_npc(role)
			await _frames(2)
			if main.dialog.is_open:
				main.dialog.close()
			await _frames(2)
	return out
