extends Node3D
## Frame cost of the village ground alone: the paving (VillageGround) against the old
## meadow ground (Scenery.ground) and no ground, under the town's sky and sun, at a game
## view that is mostly ground. Rounds alternate so drift hits every variant alike.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/paving_perf.tscn -- [out_dir] [frames] [rounds]
## With an out_dir, one frame of each variant is saved there.


func _frame_ms(frames: int) -> float:
	for i in 10:
		await RenderingServer.frame_post_draw
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - t0) / 1000.0 / frames


func _median(values: Array) -> float:
	var v := values.duplicate()
	v.sort()
	return v[v.size() / 2]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ""
	var frames := int(args[1]) if args.size() > 1 else 60
	var rounds := int(args[2]) if args.size() > 2 else 3
	get_window().size = Vector2i(1600, 736)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	GameSettings.load_settings()
	var look := {"theme": &"village", "palette": [Color("6fa8dc"), Color("b6d4ea"), Color("f3e9dc")], "sun_size": 1.1}
	Scenery.environment(self, Color("a7cddd"), Color("e7e4d7"), Color("c2d2df"), Color("fff0d5"), look)
	var cam := Camera3D.new()
	cam.fov = 58.0
	cam.far = 260.0
	add_child(cam)
	cam.global_position = Vector3(0, 4.2, 42)
	cam.look_at(Vector3(0, 0.8, 30))
	var paving := Node3D.new()
	add_child(paving)
	VillageGround.build(paving, 140.0, JapanVillage.RADIUS, JapanVillage.green_areas(), JapanVillage.paths(), Vector3(0, 0, JapanVillage.PLAZA_RADIUS))
	var old := Node3D.new()
	add_child(old)
	Scenery.ground(old, 140.0, Color("7e9568"), Color("a1b586"), 2, Color("cbbba0"), JapanVillage.paths(), 3.6, [], &"village")
	var results := {"paving": [], "old": [], "none": []}
	for r in rounds:
		for key in ["paving", "old", "none"]:
			paving.visible = key == "paving"
			old.visible = key == "old"
			results[key].append(await _frame_ms(frames))
			if r == 0 and out_dir != "":
				get_viewport().get_texture().get_image().save_png("%s/perf_%s.png" % [out_dir, key])
	print("PERF ground frame ms (median of %d rounds x %d frames): paving %.2f, old ground %.2f, no ground %.2f" % [rounds, frames,
		_median(results.paving), _median(results.old), _median(results.none)])
	print("PERF raw ", results)
	get_tree().quit()
