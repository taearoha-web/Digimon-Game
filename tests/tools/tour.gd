extends Node
## Plays the real game scenes and saves screenshots.
## godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- <out_dir> <class> [tour]
## Tours: "field" (default), "town", "menus", "skills"

var out_dir := "user://shots"
var class_id: StringName = &"warrior"
var tour := "field"
var job := ""
var main: Node
var _n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: class_id = StringName(args[1])
	if args.size() > 2: tour = args[2]
	if args.size() > 3: job = args[3]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	run()


func run() -> void:
	await _shot("title")
	main.title_screen.new_game_pressed.emit()
	await _wait(0.8)
	await _shot("class_select")
	main.class_screen._select(&"mage")
	await _wait(0.6)
	await _shot("class_select_mage")
	main.class_screen.cancelled.emit()
	await _wait(0.3)
	Game.new_profile(class_id, "ทดสอบ")
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	main.hud.visible = true
	await main.go(&"town", true)
	await _wait(1.2)
	match tour:
		"town": await _town()
		"menus": await _menus()
		"skills": await _skills()
		"zones": await _zones()
		_: await _field()
	print("tour done: ", _n)
	get_tree().quit()


func _zones() -> void:
	_level(30)
	for id in [&"dark_forest", &"desert", &"snow", &"volcano"]:
		await main.go(id, true)
		await _wait(1.5)
		var z: Zone = main.zone
		z.hero.global_position = Vector3(-20, 0.2, -12)
		z.camera_rig.snap_to_target()
		await _wait(1.0)
		await _shot("zone_%s" % id)


func _town() -> void:
	await _shot("town")
	var z: Zone = main.zone
	z.hero.global_position = Vector3(-6, 0.2, -3)
	z.hero.set_facing(-PI * 0.6)
	await _wait(1.0)
	await _shot("town_elder")
	main._on_npc("elder")
	await _wait(0.6)
	await _shot("dialog_elder")


func _field() -> void:
	_level(8)
	await main.go(&"meadow", true)
	await _wait(1.5)
	await _shot("meadow_start")
	var z: Zone = main.zone
	var hero: Hero = z.hero
	# Walk into the field and spawn a pack.
	hero.global_position = Vector3(-18, 0.2, 2)
	z.camera_rig.snap_to_target()
	await _wait(0.5)
	var pack: Array[Mob] = []
	for i in 4:
		var m := Mob.new()
		m.setup([&"pink_slime", &"wild_chicken", &"green_slime", &"yellow_frog"][i], 5, hero.global_position + Vector3(8 + i * 1.5, 0, -2 + i * 1.5), hero)
		m.position = hero.global_position + Vector3(8 + i * 1.5, 0.3, -2 + i * 1.5)
		z.add_child(m)
		pack.append(m)
	await _wait(1.2)
	hero.tap_attack()
	await _wait(2.5)
	await _shot("fight_basic")
	for i in 4:
		hero.cooldowns.clear()
		Game.profile.mp = 999
		hero.use_skill(i)
		await _wait(0.75)
		await _shot("skill_%d" % (i + 1))
		await _wait(1.0)


func _skills() -> void:
	_level(20 if job != "" else 12)
	if job != "":
		Game.profile["job"] = job
		Game.profile_changed.emit()
	await main.go(&"meadow", true)
	await _wait(1.0)
	var z: Zone = main.zone
	var hero: Hero = z.hero
	hero.global_position = Vector3(-18, 0.2, 2)
	z.camera_rig.snap_to_target()
	await _wait(0.4)
	for i in 4:
		var pack: Array[Mob] = []
		for j in 5:
			var m := Mob.new()
			m.setup(&"green_slime", 4, hero.global_position + Vector3(4 + (j % 3) * 1.4, 0, -1.5 + (j / 3) * 2.0 + j * 0.3), hero)
			m.position = m.home + Vector3(0, 0.3, 0)
			z.add_child(m)
			pack.append(m)
		await _wait(0.8)
		hero.set_target(pack[1])
		hero.cooldowns.clear()
		Game.profile.mp = 999
		hero.use_skill(i)
		await _wait(0.45)
		await _shot("cast_%d_a" % (i + 1))
		await _wait(0.25)
		await _shot("cast_%d_b" % (i + 1))
		await _wait(0.3)
		await _shot("cast_%d_c" % (i + 1))
		await _wait(1.2)
		for m in pack:
			if is_instance_valid(m):
				m.queue_free()
		await _wait(0.3)


func _menus() -> void:
	_level(32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		var item := ItemData.generate(30, class_id, rng, 3 if slot == "weapon" else 2, slot)
		item["plus"] = 7 if slot == "weapon" else 2
		Game.profile.equip[slot] = item
	Game.profile["inv"].append(ItemData.gem("ruby", 1, 3))
	Game.profile["inv"].append(ItemData.generate(28, class_id, rng, 2, "armor"))
	await main.go(&"town", true)
	main.menu.forge_mode = true
	main.menu.open_menu(&"inventory")
	main.menu._selected_slot = "weapon"
	main.menu._refresh_detail()
	await _wait(0.8)
	await _shot("menu_forge")
	main.menu.forge_mode = false
	main.menu.show_tab(&"achievements")
	await _wait(0.4)
	await _shot("menu_achievements")
	main.menu.show_tab(&"settings")
	await _wait(0.4)
	await _shot("menu_settings")
	main.menu.show_tab(&"character")
	await _wait(0.5)
	await _shot("menu_character")
	main.menu.show_tab(&"inventory")
	await _wait(0.4)
	await _shot("menu_inventory")
	main.menu.show_tab(&"skills")
	await _wait(0.4)
	await _shot("menu_skills")
	main.menu.show_tab(&"quests")
	await _wait(0.4)
	await _shot("menu_quests")
	main.menu.close_menu()
	main.shop.open_shop()
	await _wait(0.5)
	await _shot("shop")


func _level(level: int) -> void:
	Game.profile.level = level
	Game.profile.skill_points = level
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	Game.profile_changed.emit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [_n, name]))
