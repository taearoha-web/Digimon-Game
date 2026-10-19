extends Node
## Screenshots of the guild war through the real game scenes: lobby, the arena at the start,
## the fight and the result. xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/guild_war_shots.tscn -- <out_dir> [class]
var out_dir := "user://shots"
var main: Node
var _n := 0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _n, name]
	_n += 1
	img.save_png(path)
	print("SHOT ", path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var cls := StringName(args[1]) if args.size() > 1 else &"lancer"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(cls, "ทดสอบ")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 11
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 200, slot, gear_rng)
	Game.profile.equip["wings"] = StarWingData.item(String(cls), gear_rng)
	Game.profile.hp = Game.stats_now().max_hp
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await _wait(1.0)
	main.guildwar_screen.open_lobby()
	await _wait(0.5)
	await _shot("lobby")
	main.guildwar_screen.close_screen()
	await main.go(&"guildwar", false, true)
	await _wait(1.0)
	await _shot("arena_intro")
	# Both guilds' rows from above the centre line, before anybody moves.
	var zone: Zone = main.zone
	var overhead := Camera3D.new()
	zone.add_child(overhead)
	overhead.global_position = Vector3(0.0, 34.0, 26.0)
	overhead.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	overhead.fov = 62.0
	var play_camera := get_viewport().get_camera_3d()
	overhead.current = true
	await _wait(0.3)
	await _shot("formation")
	play_camera.current = true
	overhead.queue_free()
	await _wait(5.2)
	await _shot("fight_start")
	zone.hero.global_position = Vector3(-4.0, 0.3, 0.0)
	zone.hero.set_auto(true)
	for t in 4:
		await _wait(9.0)
		var fps := Engine.get_frames_per_second()
		print("PERF t=%d fps=%d tris=%d draws=%d score=%s hero_hp=%d" % [t, fps, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), zone.gw_match.score, int(Game.profile.hp)])
		await _shot("fight_%d" % t)
	zone.gw_match.time_left = 1.0
	await _wait(6.0)
	await _shot("result")
	print("SCORE ", zone.gw_match.score, " fighters ", zone.gw_match.all_fighters().size(), " expected ", 2 * GuildWarData.TEAM_SIZE - 1)
	get_tree().quit()
