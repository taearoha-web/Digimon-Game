extends Node
## Screenshots of the world players through the real game scenes: a field with online
## players hunting, the village with the guild registrar, the guild roster and the guild
## war lobby. DAYS moves the clock to that many days after the world opened.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/world_players_shots.tscn -- <out_dir> [DAYS]
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


## The first moment after `from` with at least `want` players hunting in the same field.
func _busy_field(from: float, want: int) -> Array:
	var t := from
	while t < from + 30.0 * 86400.0:
		var count := {}
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			var place := String(s.place)
			if bool(s.online) and place != "" and place != "town":
				count[place] = int(count.get(place, 0)) + 1
				if int(count[place]) >= want:
					return [t, StringName(place)]
		t += 900.0
	return []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var days := float(args[1]) if args.size() > 1 else 0.3
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"lancer", "ทดสอบ")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.profile.party = []
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	var found := _busy_field(float(WorldPlayers.START_UNIX) + days * 86400.0, 3)
	if found.is_empty():
		found = _busy_field(float(WorldPlayers.START_UNIX) + days * 86400.0, 1)
	WorldPresence.clock_offset = float(found[0]) - WorldPlayers.now()
	print("FIELD ", found[1], " at day ", (float(found[0]) - WorldPlayers.START_UNIX) / 86400.0)
	await main.go(found[1], true)
	await _wait(4.0)
	var zone: Zone = main.zone
	zone.hero._invulnerable_until = Time.get_ticks_msec() + 600000
	var bots := get_tree().get_nodes_in_group("world_players")
	await _wait(4.0)
	if not bots.is_empty():
		var bot: FieldPlayer = bots[0]
		zone.hero.global_position = bot.global_position + Vector3(-3.0, 0.2, 5.0)
		zone.camera_rig.snap_to_target()
	await _wait(1.5)
	await _shot("field_players")
	await _wait(6.0)
	await _shot("field_players_later")
	await main.go(&"town", true)
	await _wait(2.0)
	for npc in main.zone.npcs:
		if npc.role == "guild":
			main.zone.hero.global_position = npc.global_position + Vector3(0, 0.2, 5.0)
	await _wait(1.5)
	await _shot("town_registrar")
	main.guild_screen.open_screen()
	await _wait(0.5)
	await _shot("guild_roster")
	Game.join_guild(WorldPlayers.ALPHA)
	await _wait(0.5)
	await _shot("guild_joined")
	main.guild_screen.close_screen()
	main.guildwar_screen.open_lobby()
	await _wait(0.5)
	await _shot("war_lobby")
	main.guildwar_screen.close_screen()
	get_tree().quit()
