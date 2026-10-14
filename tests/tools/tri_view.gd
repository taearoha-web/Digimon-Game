extends Node
## Triangles actually drawn from the hero's start position (needs a real renderer:
## xvfb-run godot --rendering-driver opengl3). Hides one scenery group at a time and
## reports how many primitives / draw calls it was responsible for.
##   ... res://tests/tools/tri_view.tscn -- dark_forest [class] [quality]
func _frame_stats() -> Array:
	for i in 4:
		await get_tree().process_frame
	return [int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else &"town"
	var cls := StringName(args[1]) if args.size() > 1 else &"summoner"
	GameSettings.quality = int(args[2]) if args.size() > 2 else 2
	get_window().size = Vector2i(1600, 736)
	if args.size() > 3:
		get_viewport().mesh_lod_threshold = float(args[3])
	Game.new_profile(cls, "View")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	await get_tree().create_timer(1.5).timeout
	zone.process_mode = Node.PROCESS_MODE_DISABLED  # freeze monsters so every reading sees the same scene
	var base := await _frame_stats()
	if args.size() > 4:
		# args[4] = PNG prefix: one capture per LOD threshold in the SAME scene (zones are randomised).
		Engine.time_scale = 0.0  # freezes shader TIME too, so only the LOD choice can differ between shots
		for th in [1.0, 1.001, 1.5, 2.0, 3.0]:
			get_viewport().mesh_lod_threshold = th
			for i in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_%s.png" % [args[4], str(th)])
			print("SHOT th=%s tris=%d" % [th, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
		get_tree().quit()
		return
	var suns := zone.find_children("*", "DirectionalLight3D", true, false)
	for sun in suns:
		(sun as DirectionalLight3D).shadow_enabled = false
	var no_shadow := await _frame_stats()
	for sun in suns:
		(sun as DirectionalLight3D).shadow_enabled = true
	print("VIEW shadows off: tris=%d draws=%d (shadow passes cost %d tris)" % [no_shadow[0], no_shadow[1], base[0] - no_shadow[0]])
	print("VIEW zone=%s quality=%d total tris=%d draws=%d" % [zone_id, GameSettings.quality, base[0], base[1]])
	var rx := RegEx.new()
	rx.compile("[@0-9_]+$")
	var names: Dictionary = {}
	for child in zone.get_children():
		var key := rx.sub(String(child.name), "", true)
		if not names.has(key):
			names[key] = []
		names[key].append(child)
	var rows: Array = []
	for key in names:
		for node in names[key]:
			if node is Node3D:
				(node as Node3D).visible = false
		var stats := await _frame_stats()
		rows.append([key, base[0] - stats[0], base[1] - stats[1]])
		for node in names[key]:
			if node is Node3D:
				(node as Node3D).visible = true
	rows.sort_custom(func(a, b): return a[1] > b[1])
	for r in rows.slice(0, 16):
		print("  %-30s tris=%7d draws=%4d" % [r[0], r[1], r[2]])
	get_tree().quit()
