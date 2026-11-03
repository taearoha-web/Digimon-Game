extends Node
## The village paving (VillageGround) through the real game: the game camera at the
## plaza, on the main street and at a garden kerb; a high and a far view for distance
## shimmer; the same views at night (ambient and sun turned down, moonlit sun colour);
## and the frame time of the town ground against the old meadow ground at one view.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/paving_shots.tscn -- <out_dir> [quality] [old]
## "old" as the third argument shoots the old Scenery.ground in place of the paving.
var out_dir := "user://paving_shots"
var main: Node
var _n := 0
var zone: Zone
var cam: Camera3D


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _n, name]
	_n += 1
	img.save_png(path)
	print("SHOT ", path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _game_view(pos: Vector3, yaw: float, pitch := -24.0, dist := 6.0) -> void:
	cam.current = false
	zone.camera_rig.camera.current = true
	zone.hero.global_position = pos + Vector3(0, 0.2, 0)
	zone.camera_rig.pitch_degrees = pitch
	zone.camera_rig.distance = dist
	zone.camera_rig._target_distance = dist
	zone.camera_rig._arm.spring_length = dist
	zone.camera_rig.set_yaw_behind(yaw)
	zone.camera_rig.snap_to_target()
	await _wait(1.2)


func _free_view(from: Vector3, to: Vector3) -> void:
	cam.current = true
	cam.global_position = from
	cam.look_at(to)
	await _wait(0.5)


func _views(tag: String) -> void:
	await _game_view(Vector3(0, 0, 15), 0.0)
	await _shot(tag + "_plaza")
	await _game_view(Vector3(3, 0, 13), 0.0, -48.0, 9.0)
	await _shot(tag + "_plaza_high")
	await _game_view(Vector3(0, 0, 36), 0.0)
	await _shot(tag + "_street")
	await _game_view(Vector3(-20, 0, 25), PI * 0.6)
	await _shot(tag + "_garden")
	await _game_view(Vector3(18, 0, 0), -PI * 0.5, -30.0, 10.0)
	await _shot(tag + "_market")
	await _free_view(Vector3(0, 30, 62), Vector3(0, 0, 5))
	await _shot(tag + "_far")
	await _free_view(Vector3(-8, 4.0, 46), Vector3(0, 0, -20))
	await _shot(tag + "_grazing")


func _frame_ms(frames: int) -> float:
	for i in 20:
		await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - t0) / 1000.0 / frames


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	GameSettings.load_settings()
	if args.size() > 1:
		GameSettings.quality = int(args[1])
	var old := args.size() > 2 and args[2] == "old"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"warrior", "ทดสอบ")
	Game.profile.party = []
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = false
	Game.playing = true
	await main.go(&"town", true)
	await _wait(2.0)
	zone = main.zone
	main.hud.visible = false
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.far = 260.0
	zone.add_child(cam)
	var paving := zone.get_node("Ground") as MeshInstance3D
	if old:
		paving.visible = false
		var holder := Node3D.new()
		zone.add_child(holder)
		Scenery.ground(holder, 140.0, Color("7e9568"), Color("a1b586"), 2, Color("cbbba0"), JapanVillage.paths(), 3.6, [], &"village")
		holder.get_node("Floor").queue_free()
	await _views("day")
	# Night: the moon instead of the sun, a dim blue fill.
	var env: Environment = (get_tree().get_first_node_in_group("world_env") as WorldEnvironment).environment
	var sun := get_tree().get_first_node_in_group("sun") as DirectionalLight3D
	var energy := [env.ambient_light_energy, sun.light_energy, sun.light_color, env.background_energy_multiplier]
	env.ambient_light_energy = energy[0] * 0.45
	env.background_energy_multiplier = 0.25
	sun.light_energy = energy[1] * 0.3
	sun.light_color = Color("9fb4e8")
	await _game_view(Vector3(0, 0, 15), 0.0)
	await _shot("night_plaza")
	await _game_view(Vector3(0, 0, 36), 0.0)
	await _shot("night_street")
	await _free_view(Vector3(0, 30, 62), Vector3(0, 0, 5))
	await _shot("night_far")
	env.ambient_light_energy = energy[0]
	env.background_energy_multiplier = energy[3]
	sun.light_energy = energy[1]
	sun.light_color = energy[2]
	# Frame time at a view that is mostly ground: the paving, then the old ground.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _game_view(Vector3(0, 0, 36), 0.0, -40.0, 10.0)
	var ms_now := await _frame_ms(120)
	var holder_old := Node3D.new()
	zone.add_child(holder_old)
	Scenery.ground(holder_old, 140.0, Color("7e9568"), Color("a1b586"), 2, Color("cbbba0"), JapanVillage.paths(), 3.6, [], &"village")
	holder_old.get_node("Floor").queue_free()
	var shown := paving.visible
	paving.visible = false
	var ms_old := await _frame_ms(120)
	holder_old.visible = false
	paving.visible = shown
	var ms_again := await _frame_ms(120)
	var none_ms := 0.0
	paving.visible = false
	none_ms = await _frame_ms(120)
	print("PERF ground frame ms: paving %.2f / %.2f, old ground %.2f, no ground %.2f (paving tris %d)" % [ms_now, ms_again, ms_old, none_ms,
		(paving.mesh as ArrayMesh).surface_get_array_index_len(0) / 3])
	get_tree().quit()
