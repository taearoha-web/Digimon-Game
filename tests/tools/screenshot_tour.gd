extends Node
## Drives the real game flow and saves screenshots of each screen.
## Run (needs a display, e.g. xvfb-run):
##   godot --rendering-driver opengl3 --path . res://tests/tools/screenshot_tour.tscn -- <out_dir> [tour]
## Tours: "menus" (default), "world", "battle", "all"

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
		"all":
			await _menus_tour()
			await _world_tour()
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
