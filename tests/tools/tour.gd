extends Node
## Plays the real game scenes and saves screenshots.
## godot --rendering-driver opengl3 --path . res://tests/tools/tour.tscn -- <out_dir> <class> [tour]
## Tours: "field" (default), "town", "menus", "skills"

var out_dir := "user://shots"
var class_id: StringName = &"warrior"
var tour := "field"
var job := ""
var master := false
var main: Node
var _n := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	if args.size() > 1: class_id = StringName(args[1])
	if args.size() > 2: tour = args[2]
	if args.size() > 3: job = args[3]
	if args.size() > 4: master = args[4] == "master"
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	run()


func run() -> void:
	if tour == "slots":
		for i in 3:
			Game.slot = i + 1
			Game.new_profile([&"warrior", &"mage", &"priest"][i], ["ไรเดน", "ลูน่า", "ซันนี่"][i])
			Game.profile["level"] = [34, 52, 12][i]
			Game.profile["adv"] = [1, 2, 0][i]
			Game.profile["zone"] = ["desert", "graveyard", "meadow"][i]
			Game.save()
		Game.has_profile = false
		main._show_title()
		await _wait(0.6)
		await _shot("title_slots")
		get_tree().quit()
		return
	await _shot("title")
	main.title_screen.new_game_pressed.emit(1)
	await _wait(0.8)
	await _shot("class_select")
	main.class_screen._set_gender(1)
	main.class_screen.look["hair"] = 1
	main.class_screen.look["skin"] = 5
	main.class_screen.look["mouth"] = 2
	main.class_screen._refresh()
	await _wait(0.6)
	await _shot("class_select_mage")
	if tour == "faces":
		var cs = main.class_screen
		for g in 2:
			cs._set_gender(g)
			for h in 5:
				cs.look["hair"] = h
				cs.look["hair_color"] = (h * 2 + g) % 8
				cs.look["skin"] = (h * 3 + g * 2) % 8
				cs.look["eyes"] = h
				cs.look["eye_color"] = h % 6
				cs.look["nose"] = h % 4
				cs.look["mouth"] = h
				cs._refresh()
				await _wait(0.35)
				await _shot("face_g%d_h%d" % [g, h])
		get_tree().quit()
		return
	main.class_screen.cancelled.emit()
	await _wait(0.3)
	var look_rng := RandomNumberGenerator.new()
	look_rng.seed = 7
	Game.new_profile(class_id, "ทดสอบ", FaceKit.random_look(look_rng))
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
		"line": await _line()
		"zones": await _zones()
		"hud": await _hud_check()
		"timers": await _timers_check()
		"warp": await _warp_check()
		"pvp": await _pvp_check()
		"enhance": await _enhance_check()
		"wings": await _wings_check()
		"void": await _void_check()
		"paragon": await _paragon_check()
		_: await _field()
	print("tour done: ", _n)
	get_tree().quit()


func _paragon_check() -> void:
	Game.dismiss_party()
	_level(100)
	Game.paragon()["level"] = 37
	Game.paragon()["points"] = 12
	Game.paragon()["spent"] = 25
	Game.paragon()["alloc"]["atk"] = 15
	Game.paragon()["alloc"]["hp"] = 10
	Game.profile_changed.emit()
	main.menu.open_menu(&"character")
	await _wait(0.6)
	await _shot("paragon_menu")


func _void_check() -> void:
	Game.dismiss_party()
	_level(100)
	Game.profile["adv"] = 4
	Game.fill_loadout()
	await main.go(&"void", true, true)
	await _wait(1.2)
	var hero: Hero = main.zone.hero
	await _shot("void_start")
	hero.global_position = Vector3(-24, 0.2, -10)
	main.zone.camera_rig.snap_to_target()
	await _wait(1.0)
	await _shot("void_camp")
	hero.global_position = Vector3(26, 0.2, 22)
	main.zone.camera_rig.snap_to_target()
	await _wait(2.5)
	await _shot("void_boss")


func _wings_check() -> void:
	Game.dismiss_party()
	_level(100)
	var hero: Hero = main.zone.hero
	hero.global_position = Vector3(-2.0, 0.2, 14.0)
	main.zone.camera_rig.snap_to_target()
	main.zone.camera_rig.zoom(2.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cam := Camera3D.new()
	main.zone.add_child(cam)
	cam.fov = 45
	hero.set_facing(0.0)
	for kind in ItemData.WING_KINDS:
		Game.profile.equip["wings"] = ItemData.wings(rng, kind)
		hero.refresh_stats()
		hero.visual.set_equipment(Game.profile.equip)
		await _wait(0.8)
		var fwd := Vector3(sin(hero.visual.rotation.y), 0, cos(hero.visual.rotation.y))
		var base := hero.global_position + Vector3(0, 1.1, 0)
		for view in ["back", "side"]:
			var off := -fwd * 4.2 + Vector3(0, 0.8, 0) if view == "back" else fwd.cross(Vector3.UP) * 4.2 + Vector3(0, 0.8, 0)
			cam.global_position = base + off
			cam.look_at(base, Vector3.UP)
			cam.make_current()
			await _wait(0.4)
			await _shot("wings_%s_%s" % [kind, view])


func _enhance_check() -> void:
	Game.dismiss_party()
	_level(60)
	var hero: Hero = main.zone.hero
	hero.global_position = Vector3(-2.0, 0.2, 14.0)
	main.zone.camera_rig.snap_to_target()
	main.zone.camera_rig.zoom(2.5)
	hero.set_facing(PI)
	main.zone.camera_rig.set_yaw_behind(PI)
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 3
	for slot in ["armor", "helm", "boots", "ring", "amulet"]:
		Game.profile.equip[slot] = ItemData.generate(60, Game.class_id(), gear_rng, 2, slot)
	Game.profile.equip["wings"] = ItemData.wings(gear_rng, "hp")
	for plus in [0, 2, 5, 8, 10]:
		for slot in Game.profile.equip:
			if not (slot in EnhanceFx.FIXED_SLOTS):
				Game.profile.equip[slot]["plus"] = plus
		Game.inventory_changed.emit()
		hero.visual.set_equipment(Game.profile.equip)
		await _wait(1.3)
		await _shot("plus_%d" % plus)


func _pvp_check() -> void:
	Game.dismiss_party()
	_level(int(job) if job != "" else 40)
	Game.profile["adv"] = 2
	Game.fill_loadout()
	Game.pvp()["rp"] = 640
	await main.go(&"pvp", true, true)
	await _wait(1.0)
	var zone: Zone = main.zone
	await _shot("pvp_intro")
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.position = Vector3(-6, 24, 52)
	cam.look_at(Vector3(0, 3, 0))
	cam.fov = 70
	cam.make_current()
	await _wait(0.5)
	await _shot("pvp_overview")
	cam.position = Vector3(0, 10, 5)
	cam.look_at(Vector3(0, 7, -30))
	await _wait(0.3)
	await _shot("pvp_stands")
	zone.camera_rig.camera.make_current()
	await _wait(4.0)
	zone.hero.set_auto(true)
	for i in 6:
		await _wait(2.2)
		await _shot("pvp_fight")
	print("rival hp: ", zone.pvp_match.rival.hp, "/", zone.pvp_match.rival.max_hp, " hero hp: ", Game.profile.hp)


func _warp_check() -> void:
	Game.dismiss_party()
	_level(30)
	var hero: Hero = main.zone.hero
	hero.global_position = Vector3(-2.0, 0.2, 7.0)
	main.zone.camera_rig.snap_to_target()
	await _wait(0.8)
	await _shot("town_stone")
	main.warp.open_warp()
	await _wait(0.4)
	await _shot("warp_list")
	main.warp.close_warp()
	await main.go(&"snow", true, true)
	await _wait(1.0)
	await _shot("snow_arrive")
	main.zone.hero.global_position = main.zone.hero.global_position + Vector3(2.0, 0, -2.0)
	await _wait(0.6)
	await _shot("snow_stone")


func _hud_check() -> void:
	Game.dismiss_party()
	_level(100)
	Game.profile["adv"] = 4
	Game.fill_loadout()
	await main.go(&"meadow", true)
	await _wait(1.0)
	await _shot("hud_field")
	main.zone.hero.cooldowns[Game.class_data().skills[2].id] = 5.0
	await _wait(0.4)
	await _shot("hud_cooldown")


func _timers_check() -> void:
	Game.dismiss_party()
	_level(100)
	Game.profile["adv"] = 4
	Game.fill_loadout()
	await main.go(&"meadow", true)
	await _wait(1.0)
	var hero: Hero = main.zone.hero
	Game.profile["look"]["hair_color"] = 1
	Game.profile["look"]["hair"] = 5
	hero.visual.look = Game.profile["look"]
	hero.visual.refresh()
	hero.global_position = Vector3(-18, 0.2, 2)
	main.zone.camera_rig.snap_to_target()
	await _wait(0.5)
	main.zone.camera_rig.zoom(2.0)
	var only := job
	if only == "" or only == "shield":
		hero.receive_buff({"def": 0.8, "secs": 25.0}, Color("ffe9a0"), "Drastic Spirit", true)
	if only == "" or only == "power":
		hero.receive_buff({"atk": 0.55, "secs": 18.0}, Color("ff4a3a"), "Berserker")
	if only == "" or only == "wind":
		hero.receive_buff({"speed": 0.3, "secs": 20.0}, Color("7affd0"), "Swift Axe")
	if only == "" or only == "spark":
		hero.receive_buff({"crit": 0.15, "secs": 25.0}, Color("ffd27a"), "Scout Hawk")
	if only == "" or only == "summon":
		var wolf := Summon.new()
		wolf.setup(hero, "recall_wolverine", {"kind": "wolf", "count": 2, "secs": 180.0, "interval": 0.9}, 3.0, 0, 2, 2)
		main.zone.add_child(wolf)
		hero._summons.append(wolf)
		wolf.life = 120.0
	await _wait(5.0)
	await _shot("timers_full")
	hero._buffs[0]["until"] = Time.get_ticks_msec() + 2500
	await _wait(0.4)
	await _shot("timers_low")


func _line() -> void:
	_level(10)
	main._talk_job()
	await _wait(0.6)
	await _shot("line_choice")
	main._show_line(&"mage")
	await _wait(0.6)
	await _shot("line_mage")
	main.dialog.close()
	main.menu.open_menu(&"skills")
	await _wait(0.6)
	await _shot("menu_skills_vagabond")


func _zones() -> void:
	_level(100)
	for id in [&"graveyard", &"swamp", &"storm", &"sky", &"abyss"]:
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
	Game.dismiss_party()
	_level(100 if job != "" else 12)
	if job != "":
		Game.profile["adv"] = int(job)
		var bars := {"archer": ["recall_wolverine", "golden_falcon", "force_of_nature", "tempest"], "mage": ["spirit_elemental", "dancing_sword", "fire_elemental", "armageddon"], "warrior": ["cyclone_strike", "grand_cross", "brandish", "gladiator"], "priest": ["summon_muspell", "divine_judgment", "holy_rain_big", "last_judgement"]}
		Game.profile["loadout"] = bars[String(class_id)]
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
	main.shop.close_shop()
	main.trainer.open_trainer()
	await _wait(0.5)
	await _shot("skill_trainer")
	main.trainer.close_trainer()


func _level(level: int) -> void:
	Game.profile.level = level
	Game.profile.skill_points = level
	Game.fill_loadout()
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
