extends Node
## Real elapsed-time auto-hunt including the HUD, drops and ten-second saves.
## Run only with isolated XDG data: -- OUT.json WALL_SECONDS [ZONE] [CLASS]
var main: Node
var samples: Array[Dictionary] = []
var simulation_seconds := 0.0

func _process(delta: float) -> void:
	simulation_seconds += delta

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		get_tree().quit(1)
		return
	var duration := float(args[1])
	var zone_id := StringName(args[2]) if args.size() > 2 else &"meadow"
	var family := StringName(args[3]) if args.size() > 3 else &"mage"
	Engine.time_scale = 1.0
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(family, "Isolated long hunt", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.attrs = {"str":0,"int":500,"dex":100,"vit":150}
	for slot in ["weapon","armor","helm","boots","amulet","ring"]:
		Game.profile.equip[slot]=ItemData.generate(120,family,Game.rng,3,slot)
	for skill in ClassData.pool(family):
		Game.profile.skills[String(skill.id)] = 1
	Game.fill_loadout()
	if family == &"mage":
		Game.profile.loadout = ["thunder_storm", "judgment_ray", "armageddon", "ice_storm", "hell_meteor", "energy_shield", "magic_overdrive", "zenith"]
	await main.go(zone_id, true)
	var hero: Hero = main.zone.hero
	if not main.zone._camps.is_empty():
		var camp: Dictionary = main.zone._camps[0]
		hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y)
	hero._invulnerable_until=Time.get_ticks_msec()+int(duration*1000)+5000
	hero.set_auto(true)
	var start := Time.get_ticks_msec()
	var next_report := 0.0
	var initial_sim := simulation_seconds
	var initial_kills := int(Game.profile.kills)
	while float(Time.get_ticks_msec() - start) / 1000.0 < duration:
		await get_tree().create_timer(0.5, true, false, true).timeout
		# Keep the workload fighting instead of ending when the fixture runs out of potions.
		Game.profile.hp = hero.stats.max_hp
		Game.profile.mp = hero.stats.max_mp
		var elapsed := float(Time.get_ticks_msec() - start) / 1000.0
		if elapsed >= next_report:
			next_report += 30.0
			var sample := {"wall_seconds": elapsed, "simulation_seconds": simulation_seconds - initial_sim,
				"tower_floor":main.zone.tower_run.floor_no if main.zone.tower_run else 0,
				"tower_state":main.zone.tower_run.state if main.zone.tower_run else "",
				"kills": int(Game.profile.kills) - initial_kills, "auto": hero.auto,
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
				"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
				"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
				"video_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
				"loot": get_tree().get_nodes_in_group("loot").size(), "bag": Game.profile.inv.size()}
			samples.append(sample)
			print("LONG HUNT: ", JSON.stringify(sample))
			var report := FileAccess.open(args[0], FileAccess.WRITE)
			report.store_string(JSON.stringify({"fixture": "real_clock_hunt_v1", "quality": 2, "class": String(family), "zone": String(zone_id),
				"renderer": RenderingServer.get_video_adapter_name(), "godot": Engine.get_version_info().string,
				"physical_iphone_tested": false, "samples": samples}, "\t"))
	print("LONG HUNT COMPLETE: ", duration, " actual wall seconds")
	get_tree().quit()
