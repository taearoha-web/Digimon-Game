extends Node
## Captures retained resources after leaving real scenes, rather than comparing
## different live maps with different amounts of scenery.
var main: Node
var samples: Array[Dictionary] = []

func _ready() -> void:
	GameSettings.load_settings()
	GameSettings.quality = 2
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.2).timeout
	Game.new_profile(&"mage", "Travel memory QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	var zones := [&"meadow", &"dark_forest", &"desert", &"snow", &"volcano", &"graveyard", &"swamp", &"storm", &"sky", &"abyss", &"void", &"town"]
	Engine.time_scale = 6.0
	for id in zones:
		await main.go(id, true)
		await get_tree().create_timer(1.0).timeout
		main._clear_zone()
		main.hud.visible = false
		await get_tree().process_frame
		await get_tree().create_timer(4.0).timeout
		var sample := {"zone": String(id),
			"nature_entries": NatureKit._cache.size(),
			"finish_materials": StorybookFinish._materials.size(),
			"hero_parts": HeroParts._cache.size(),
			"mesh_materials": MeshKit._materials.size(),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))}
		samples.append(sample)
		print("TRAVEL MEMORY: ", JSON.stringify(sample))
	Engine.time_scale = 1.0
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var report := FileAccess.open(args[0], FileAccess.WRITE)
		report.store_string(JSON.stringify(samples, "\t"))
	get_tree().quit()
