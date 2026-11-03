extends Node
## Draw calls, triangles and objects drawn in the village at a graphics quality, and
## a screenshot: what a healthy village frame costs (a phone that reports far fewer
## triangles is not drawing the world). "spots" as the third argument also measures the
## view from in front of every villager (where the hero stands to talk), and the average;
## "bare" as the fourth leaves the world players out (the village's own cost only).
##   godot --rendering-driver opengl3 --resolution 1280x589 --path . res://tests/tools/town_draw_probe.tscn -- OUT_DIR QUALITY [spots] [bare]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	GameSettings.load_settings()
	GameSettings.quality = int(args[1]) if args.size() > 1 else 0
	if args.size() > 3 and args[3] == "bare":
		GameSettings.show_world_players = false
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(&"vagabond", "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	GameSettings.apply_live(get_tree())
	await main.go(&"town", true)
	await get_tree().create_timer(3.0).timeout
	for i in 3:
		await RenderingServer.frame_post_draw
	print("TOWN q%d draws=%d tris=%d objects=%d video=%.1fMB" % [GameSettings.quality,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	get_viewport().get_texture().get_image().save_png("%s/town_q%d.png" % [out, GameSettings.quality])
	if args.size() > 2 and args[2] == "spots":
		await _spots(main.zone)
	get_tree().quit()


## The hero 3.5 m in front of each villager, looking at it: draw calls and triangles there.
func _spots(zone: Zone) -> void:
	var draws := 0.0
	var tris := 0.0
	var most := 0
	var count := 0
	for npc in zone.npcs:
		var front := Vector3(sin(npc.visual.rotation.y), 0, cos(npc.visual.rotation.y)) if npc.visual != null else Vector3.BACK
		zone.hero.global_position = npc.global_position + front * 3.5 + Vector3(0, 0.2, 0)
		zone.camera_rig.set_yaw_behind(atan2(front.x, front.z))
		zone.camera_rig.snap_to_target()
		for i in 4:
			await RenderingServer.frame_post_draw
		var d := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var t := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		print("SPOT %s draws=%d tris=%d" % [npc.role, d, t])
		draws += d
		tris += t
		most = maxi(most, d)
		count += 1
	print("SPOTS q%d avg_draws=%.1f max_draws=%d avg_tris=%d" % [GameSettings.quality, draws / count, most, int(tris / count)])
