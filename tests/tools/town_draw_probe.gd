extends Node
## Draw calls, triangles and objects drawn in the village at a graphics quality, and
## a screenshot: what a healthy village frame costs (a phone that reports far fewer
## triangles is not drawing the world).
##   godot --rendering-driver opengl3 --resolution 1280x589 --path . res://tests/tools/town_draw_probe.tscn -- OUT_DIR QUALITY
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	GameSettings.load_settings()
	GameSettings.quality = int(args[1]) if args.size() > 1 else 0
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
	get_tree().quit()
