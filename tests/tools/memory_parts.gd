extends Node
## What a field costs, part by part: static (heap) and video memory with everything,
## then without the world players, the monsters, the hero's raven/cape and the effects.
##   godot --rendering-driver opengl3 --path . res://tests/tools/memory_parts.tscn -- darklord 64 swamp
func _mem(tag: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	print("%-18s static=%6.1fMB video=%6.1fMB tex=%5.1f buf=%5.1f nodes=%5d objects=%5d" % [tag,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))])


func _drop(group: String) -> void:
	for n in get_tree().get_nodes_in_group(group):
		n.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cls := StringName(args[0]) if args.size() > 0 else &"darklord"
	var level := int(args[1]) if args.size() > 1 else 64
	var field := StringName(args[2]) if args.size() > 2 else &"swamp"
	GameSettings.load_settings()
	GameSettings.quality = 1
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	await _mem("title")
	Game.new_profile(cls, "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	await _mem("no title")
	Game.profile.level = level
	Game.profile.adv = JobData.adv_for_level(level)
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = ItemData.generate(level, cls, Game.rng, 3, slot)
	await main.go(field, true)
	main.zone.hero.set_auto(true)
	main.zone.hero._invulnerable_until = Time.get_ticks_msec() + 3600000
	await get_tree().create_timer(30.0).timeout
	print("world players shown: %d, mobs: %d" % [get_tree().get_nodes_in_group("world_players").size(), get_tree().get_nodes_in_group("mobs").size()])
	await _mem("field")
	main.zone.hero.set_auto(false)
	main.zone.presence.set_process(false)
	await _drop("world_players")
	await _mem("- world players")
	await _drop("mobs")
	await _mem("- monsters")
	get_tree().quit()
