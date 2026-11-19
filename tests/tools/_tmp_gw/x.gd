extends Node
## Temp: in-war frames of the doctrine (watched war: plans/phases on the board, orders in the feed).
var out_dir := "/tmp/gwshots"
var main: Node
const Sim := preload("res://tests/tools/guild_war_sim.gd")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("SHOT ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"warrior", "ผู้ชม")
	Game.profile.level = 100
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"meadow", true, true)
	await _wait(0.5)
	var info := Sim.roster(31, 2, 20, [1, 1])
	info["league_match"] = ["Alpha", "Neverdie"]
	info["slot_start"] = int(Time.get_unix_time_from_system())
	await GuildWarSpectate.spectate(get_tree(), info)
	var zone: Zone = main.zone
	var m := zone.gw_match
	m._timer = 0.05
	Engine.time_scale = 4.0
	var shots := [[55.0, "a"], [205.0, "b"], [330.0, "c"], [430.0, "d"], [560.0, "e"]]
	var t0 := 0.0
	for s in shots:
		while m.fight_clock < float(s[0]):
			await get_tree().process_frame
			if m.state != "fight" and m.fight_clock > 5.0:
				break
		Engine.time_scale = 1.0
		await _wait(0.6)
		print("t ", m.fight_clock, " phases ", m.plans_line())
		await _shot(String(s[1]))
		Engine.time_scale = 4.0
	Engine.time_scale = 1.0
	get_tree().quit()
