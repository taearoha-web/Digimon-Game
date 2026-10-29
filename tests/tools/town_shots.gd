extends Node
## Screenshots of the busy village through the real game scenes: the plaza with its stall
## keepers, players strolling and chat bubbles, the world chat in the HUD, the main street,
## and the registry. DAYS moves the clock to that many days after the world opened.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/town_shots.tscn -- <out_dir> [DAYS] [quality] [class] [level]
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
	var days := float(args[1]) if args.size() > 1 else 2.4
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	GameSettings.load_settings()
	if args.size() > 2:
		GameSettings.quality = int(args[2])
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + days * 86400.0 - WorldPlayers.now()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	var cls := StringName(args[3]) if args.size() > 3 else &"bard"
	var level := int(args[4]) if args.size() > 4 else 60
	Game.new_profile(cls, "ทดสอบ")
	Game.profile["level"] = level
	Game.profile["adv"] = JobData.adv_for_level(level)
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = ItemData.generate(level, cls, Game.rng, 3, slot)
	# "star" / "divine" as the sixth argument: the ★200 set and star wings (or the divine set).
	var kit := args[5] if args.size() > 5 else ""
	if kit != "":
		Game.paragon().level = 200
		for slot in ["weapon", "armor", "helm", "boots"]:
			Game.profile.equip[slot] = DivineGearData.item(cls, slot, Game.rng) if kit == "divine" else StarProgression.item(cls, 200, slot, Game.rng)
		Game.profile.equip["wings"] = StarWingData.item(String(cls), Game.rng, 3)
	Game.profile.party = []
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	await main.go(&"town", true)
	await _wait(3.0)
	var zone: Zone = main.zone
	print("TOWN shown ", get_tree().get_nodes_in_group("world_players").size(), " online ", WorldPresence.online_count())
	# Some lines of chat first, so the HUD's world chat and a few bubbles show.
	for k in 6:
		zone.presence.chat_once()
		await _wait(0.4)
	zone.hero.global_position = Vector3(0, 0.2, 15.0)
	zone.camera_rig.snap_to_target()
	await _wait(2.0)
	_talk_near(zone, 3)
	await _wait(0.6)
	await _shot("plaza")
	zone.hero.global_position = Vector3(-20, 0.2, 7.0)
	zone.camera_rig.snap_to_target()
	for k in 3:
		zone.presence.chat_once()
		await _wait(0.4)
	await _wait(1.0)
	_talk_near(zone, 2)
	await _wait(0.6)
	await _shot("street")
	zone.hero.global_position = Vector3(10, 0.2, 10.0)
	zone.camera_rig.snap_to_target()
	await _wait(3.0)
	await _shot("stalls")
	main.registry.open_screen()
	await _wait(0.6)
	await _shot("registry")
	main.registry.close_screen()
	get_tree().quit()


## The `count` world players nearest the hero say a line of the world chat (bubbles).
func _talk_near(zone: Zone, count: int) -> void:
	var near: Array = get_tree().get_nodes_in_group("world_players")
	near.sort_custom(func(a, b): return a.global_position.distance_to(zone.hero.global_position) < b.global_position.distance_to(zone.hero.global_position))
	for p in near.slice(0, count):
		var s := WorldPlayers.state(p.world_index, WorldPresence.clock())
		var line := WorldChat.line_for(s, randi())
		Game.world_chat.emit(String(s.name), line, WorldPlayers.GUILD_COLORS.get(int(s.guild), Color("bfe8ff")))
		p.bubble(line)
