extends Node
## Drives the real game flow and saves screenshots of each screen.
## Run (needs a display, e.g. xvfb-run):
##   godot --rendering-driver opengl3 --path . res://tests/tools/screenshot_tour.tscn -- <out_dir> [tour]
## Tours: "menus" (default), "world", "battle", "forest", "all"

var out_dir := "user://screenshots"
var tour := "menus"
var _count := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		tour = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Survive scene changes: move the driver under the root.
	var driver := Node.new()
	driver.name = "TourDriver"
	driver.set_script(get_script())
	driver.set_meta("is_driver", true)
	if not has_meta("is_driver"):
		get_parent().remove_child.call_deferred(self)
		driver.set("out_dir", out_dir)
		driver.set("tour", tour)
		get_tree().root.add_child.call_deferred(driver)
		driver.ready.connect(driver.run, CONNECT_ONE_SHOT)


func run() -> void:
	match tour:
		"menus":
			await _menus_tour()
		"world":
			await _world_tour()
		"battle":
			await _battle_tour()
		"forest":
			await _forest_tour()
		"all":
			await _menus_tour()
			await _world_tour()
			await _battle_tour()
			await _forest_tour()
		_:
			await _menus_tour()
	print("tour complete: %d screenshots" % _count)
	get_tree().quit()


func _menus_tour() -> void:
	await _goto(&"main_menu")
	await _shot("main_menu")
	var menu := get_tree().current_scene
	menu._on_settings()
	await _wait(0.6)
	await _shot("settings")
	for child in menu.get_children():
		if child is OverlaySheet:
			child.queue_free()
	menu._on_new_game()
	await _wait_transition()
	var cc := get_tree().current_scene
	await _shot("character_creation_body")
	cc._show_tab(1)
	await _wait(0.2)
	await _shot("character_creation_hair")
	cc._show_tab(3)
	cc._on_randomize()
	await _wait(0.4)
	await _shot("character_creation_outfit")
	cc._on_confirm()
	await _wait_transition()
	var starter := get_tree().current_scene
	await _wait(0.5)
	await _shot("starter_selection")
	starter._select(0)
	await _wait(0.6)
	await _shot("starter_selected")
	starter._on_confirm()
	await _wait_transition()
	var name_screen := get_tree().current_scene
	name_screen._name_input.text = "Hikaru"
	name_screen._on_text_changed("Hikaru")
	await _shot("player_name")
	name_screen._on_confirm()
	await _wait_transition()
	await _shot("confirmation")
	get_tree().current_scene._on_confirm()
	await _wait_transition()
	await _wait(1.2)
	await _shot("intro")


func _world_tour() -> void:
	var draft := NewGameDraft.new()
	draft.player_name = "Hikaru"
	draft.starter_species_id = &"agumon"
	GameState.start_new_game(draft)
	SceneManager.goto_map(&"starter_zone", &"start", {"intro": true})
	await _wait_transition()
	await _wait(2.5)
	await _shot("world_start")
	var world: WorldMap = get_tree().current_scene
	world.camera_rig.set_yaw_behind(world.player.get_facing() + PI + 0.6)
	await _wait(0.6)
	await _shot("world_start_angle")
	# Walk up to Mira and talk.
	var mira: Npc = world.get_node("NPCs/Mira")
	_teleport(world, mira.global_position + Vector3(0, 0, 2.2))
	await _wait(1.0)
	await _shot("near_mira")
	world.player.try_interact()
	await _wait(1.2)
	await _shot("dialogue")
	while world.dialogue_box.is_open:
		world.dialogue_box._advance()
		await _wait(0.05)
		world.dialogue_box._advance()
		await _wait(0.05)
	await _wait(1.0)
	await _shot("quest_started")
	# Bridge approach ramps (west end, looking east over the river).
	_teleport(world, Vector3(-11.0, 0, 1.5))
	world.camera_rig.set_yaw_behind(-PI * 0.5 - 0.25)
	await _wait(1.2)
	await _shot("bridge")
	# Fight! button next to a wild Digimon.
	var spawner := world.get_node("Spawners/MeadowSpawner") as EncounterSpawner
	spawner.set_encounters_enabled(false)
	var wilds := spawner.find_children("*", "WildDigimon", true, false)
	if wilds.is_empty():
		wilds = world.find_children("*", "WildDigimon", true, false)
	if not wilds.is_empty():
		var wild := wilds[0] as WildDigimon
		wild.set_physics_process(false)
		wild.encounters_enabled = true
		_teleport(world, wild.global_position + Vector3(-2.6, 0, 1.2))
		world.camera_rig.set_yaw_behind(atan2(-2.6, 1.2) + PI)
		await _wait(1.0)
		await _shot("fight_button")
		wild.encounters_enabled = false
	var tg: Node3D = world.get_node("Waypoints/training_grounds")
	_teleport(world, tg.global_position + Vector3(-6, 0, 8))
	world.camera_rig.set_yaw_behind(PI * 0.8)
	await _wait(2.0)
	await _shot("training_grounds")
	var meadow: Node3D = world.get_node("Waypoints/wild_meadow")
	_teleport(world, meadow.global_position + Vector3(-12, 0, -14))
	world.camera_rig.set_yaw_behind(PI * 1.2)
	await _wait(2.5)
	await _shot("wild_meadow")
	var gate: Node3D = world.get_node("Waypoints/gateway")
	_teleport(world, gate.global_position + Vector3(-7, 0, 7))
	world.camera_rig.set_yaw_behind(PI * 1.75)
	await _wait(1.5)
	await _shot("gateway")
	world.pause_menu.open(&"party")
	await _wait(0.8)
	await _shot("menu_party")
	world.pause_menu._show_tab(&"inventory")
	await _wait(0.5)
	await _shot("menu_inventory")
	world.pause_menu._show_tab(&"quests")
	await _wait(0.5)
	await _shot("menu_quests")
	world.pause_menu._show_tab(&"digimon")
	await _wait(0.6)
	await _shot("menu_collection")
	world.pause_menu.close()


func _battle_tour() -> void:
	if not GameState.is_game_active:
		var draft := NewGameDraft.new()
		draft.player_name = "Hikaru"
		draft.starter_species_id = &"gabumon"
		GameState.start_new_game(draft)
	var request := BattleRequest.wild(&"palmon", 4)
	SceneManager.goto_battle(request)
	await _wait_transition()
	await _wait(0.4)
	await _shot("battle_intro")
	var battle: BattleScene = get_tree().current_scene
	while battle.controller.phase != BattleController.Phase.AWAITING_COMMAND or not battle.ui._commands.visible:
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("battle_commands")
	battle.ui._show_skill_menu()
	await _wait(0.3)
	await _shot("battle_skills")
	var turns := 0
	var shot_mid := false
	while not battle.controller.is_finished() and turns < 30:
		while not battle.ui._commands.visible and not battle.controller.is_finished():
			await get_tree().process_frame
			battle.ui._tapped = true
		if battle.controller.is_finished():
			break
		if battle.controller.phase == BattleController.Phase.AWAITING_SWITCH:
			for i in battle.controller.party.size():
				if not battle.controller.party[i].is_fainted():
					battle.ui.hide_menus()
					battle._on_forced_switch(i)
					break
			continue
		var options := battle.controller.get_skill_options()
		var best: Dictionary = {}
		for o in options:
			if o.usable and (best.is_empty() or o.skill.power > best.skill.power):
				best = o
		battle.ui.hide_menus()
		if best.is_empty():
			battle._on_command({"type": "defend"})
		else:
			battle._on_command({"type": "skill", "skill_id": best.skill.id})
		turns += 1
		if not shot_mid:
			await _wait(0.9)
			await _shot("battle_attack")
			shot_mid = true
	# Results / popups
	await _wait(1.5)
	await _shot("battle_end")
	for i in 40:
		await _wait(0.25)
		battle.ui._tapped = true
		for node in battle.ui.find_children("*", "Button", true, false):
			var b := node as Button
			if b.visible and not b.disabled and b.text in ["Continue", "OK", "Welcome!", "Great!", "Later"]:
				await _shot("battle_popup_%d" % i)
				b.pressed.emit()
				break
		for node in battle.popups.find_children("*", "Button", true, false):
			var b := node as Button
			if b.visible and not b.disabled and b.text in ["OK", "Later"]:
				await _shot("battle_popup_q%d" % i)
				b.pressed.emit()
				break
		if SceneManager.is_transitioning:
			break
	await _wait_transition()
	await _wait(1.0)
	await _shot("after_battle_world")


## Shop, gear, gateway travel and the Data Forest.
func _forest_tour() -> void:
	var draft := NewGameDraft.new()
	draft.player_name = "Hikaru"
	draft.starter_species_id = &"patamon"
	GameState.start_new_game(draft)
	GameState.quest_log.set_state(&"q_first_steps", QuestLog.State.REWARDED)
	GameState.set_flag(&"gateway_unlocked")
	GameState.profile.add_currency(1200)
	GameState.inventory.add_item(&"power_chip", 1)
	QuestManager.refresh_availability()
	SceneManager.goto_map(&"starter_zone", &"start")
	await _wait_transition()
	await _wait(1.5)
	var world: WorldMap = get_tree().current_scene
	# Pip's shop in the plaza.
	var pip: Npc = world.get_node("NPCs/Pip")
	_teleport(world, pip.global_position + Vector3(2.0, 0, 0.6))
	world.camera_rig.set_yaw_behind(-PI * 0.45)
	await _wait(1.0)
	await _shot("pip_plaza")
	world.player.try_interact()
	await _skip_dialogue(world)
	await _wait(0.8)
	await _shot("shop_buy")
	var shop := _find_shop()
	if shop:
		shop._selected = &"guard_chip"
		shop._quantity = 1
		shop._on_action(&"guard_chip")
		await _wait(0.4)
		await _shot("shop_bought")
		for node in shop.find_children("*", "Button", true, false):
			if (node as Button).text == "Sell":
				(node as Button).button_pressed = true
				(node as Button).pressed.emit()
				break
		await _wait(0.3)
		await _shot("shop_sell")
		var node: Node = shop
		while node and not node is OverlaySheet:
			node = node.get_parent()
		if node:
			(node as OverlaySheet).close_sheet()
	await _wait(0.6)
	# Gear: inventory tab + chip on the partner.
	world.pause_menu.open(&"inventory")
	await _wait(0.3)
	var inv := world.pause_menu.find_children("*", "InventoryPanel", true, false)
	if not inv.is_empty():
		var gear_tab: Button = (inv[0] as InventoryPanel)._tab_buttons[1]
		gear_tab.button_pressed = true
		gear_tab.pressed.emit()
	await _wait(0.4)
	await _shot("inventory_gear")
	EquipmentService.equip(GameState.roster.get_lead(), &"power_chip", GameState.inventory)
	world.pause_menu._show_tab(&"party")
	await _wait(0.8)
	await _shot("party_with_chip")
	world.pause_menu.close()
	await _wait(0.3)
	# Travel through the Gateway.
	var gate: Node3D = world.get_node("Interactables/Gateway")
	_teleport(world, gate.global_position + Vector3(-2.2, 0, 2.2))
	world.camera_rig.set_yaw_behind(PI * 1.75)
	await _wait(1.0)
	await _shot("gateway_open")
	world.player.try_interact()
	await _wait_transition()
	await _wait(2.0)
	await _shot("forest_arrival")
	var forest: WorldMap = get_tree().current_scene
	# Keep wild Digimon from starting battles while the camera tours the map.
	for node in forest.find_children("*", "EncounterSpawner", true, false):
		(node as EncounterSpawner).set_encounters_enabled(false)
	forest.camera_rig.set_yaw_behind(forest.player.get_facing() + PI + 0.5)
	await _wait(0.8)
	await _shot("forest_arrival_angle")
	var lumi: Npc = forest.get_node("NPCs/Lumi")
	_teleport(forest, lumi.global_position + Vector3(0.4, 0, -2.9))
	forest.camera_rig.set_yaw_behind(3.0)
	await _wait(1.2)
	await _shot("forest_camp")
	forest.player.try_interact()
	await _wait(1.0)
	await _shot("lumi_dialogue")
	await _skip_dialogue(forest)
	await _wait(1.0)
	await _shot("forest_quest_started")
	# Camera yaw looks along (-sin, -cos): yaw = atan2(-dx, -dz) towards the subject.
	for spot in [["crystal_lake", Vector3(-4, 0, 3), -0.31], ["old_ruins", Vector3(-6, 0, 2), -1.39],
			["gateway", Vector3(8, 0, -8), PI * 0.75]]:
		var marker: Node3D = forest.get_node("Waypoints/%s" % spot[0])
		_teleport(forest, marker.global_position + spot[1])
		forest.camera_rig.set_yaw_behind(spot[2])
		await _wait(2.0)
		await _shot("forest_%s" % spot[0])
	var grove: Node3D = forest.get_node("AreaTriggers/whispering_grove")
	_teleport(forest, grove.global_position + Vector3(-10, 0, -10))
	forest.camera_rig.set_yaw_behind(PI * 1.25)
	await _wait(2.0)
	await _shot("forest_grove")
	forest.pause_menu.open(&"quests")
	await _wait(0.6)
	await _shot("forest_quests")
	forest.pause_menu.close()
	# Forest-themed battle arena.
	forest.on_before_save()
	var request := BattleRequest.wild(&"togemon", 9)
	request.return_map_id = &"data_forest"
	request.arena_theme = GameData.get_map(&"data_forest").battle_arena
	SceneManager.goto_battle(request)
	await _wait_transition()
	await _wait(1.5)
	await _shot("forest_battle")


func _skip_dialogue(world: WorldMap) -> void:
	await _wait(0.8)
	while world.dialogue_box.is_open:
		world.dialogue_box._advance()
		await _wait(0.05)
		world.dialogue_box._advance()
		await _wait(0.05)


func _find_shop() -> ShopPanel:
	var found := get_tree().root.find_children("*", "ShopPanel", true, false)
	return found[0] as ShopPanel if not found.is_empty() else null


func _teleport(world: WorldMap, pos: Vector3) -> void:
	world.player.global_position = Vector3(pos.x, world.get_ground_height(pos.x, pos.z) + 0.3, pos.z)
	world.player.velocity = Vector3.ZERO
	world.camera_rig.snap_to_target()
	if world.partner:
		world.partner.teleport_near_target()


func _goto(key: StringName) -> void:
	SceneManager.goto_scene(key)
	await _wait_transition()


func _wait_transition() -> void:
	await get_tree().process_frame
	while SceneManager.is_transitioning:
		await get_tree().process_frame
	await _wait(0.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	_count += 1
	var path := out_dir.path_join("%02d_%s.png" % [_count, shot_name])
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot: ", path)
