extends Node
## Screenshots of the busy village through the real game scenes: the plaza, the market street
## with its stall keepers, players strolling and chat bubbles, the world chat in the HUD,
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
	# "overview" as the seventh argument: a map from straight above and a high view over
	# the plaza and every district instead of the street shots.
	if args.size() > 6 and args[6] == "overview":
		await _overview(zone)
		get_tree().quit()
		return
	# "fly" as the seventh argument: wings / cape in their flying mode ("ลอย").
	if args.size() > 6 and args[6] == "fly":
		zone.hero.set_wing_mode(HeroVisual.WING_FLY)
		await _wait(1.5)
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
	zone.hero.global_position = Vector3(22, 0.2, 1.0)
	zone.camera_rig.snap_to_target()
	for k in 3:
		zone.presence.chat_once()
		await _wait(0.4)
	await _wait(1.0)
	_talk_near(zone, 2)
	await _wait(0.6)
	await _shot("street")
	zone.hero.global_position = Vector3(46, 0.2, 1.0)
	zone.camera_rig.snap_to_target()
	await _wait(3.0)
	await _shot("stalls")
	main.registry.open_screen()
	await _wait(0.6)
	await _shot("registry")
	main.registry.close_screen()
	get_tree().quit()


## The village from above: the whole map (orthographic, north up), then a high camera over
## the plaza and each district (JapanVillage.DISTRICTS when the layout names them, else
## the eight points of the compass). Nothing is culled by distance for these.
func _overview(zone: Zone) -> void:
	get_window().size = Vector2i(1600, 1000)
	main.hud.visible = false
	for node in zone.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).visibility_range_end = 0.0
		(node as GeometryInstance3D).visibility_range_begin = 0.0
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.far = 600.0
	cam.current = true
	var r := JapanVillage.RADIUS
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = r * 2.3
	cam.look_at_from_position(Vector3(0, 160, 0.01), Vector3.ZERO, Vector3(0, 0, -1))
	await _wait(1.0)
	await _shot("map")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 55.0
	cam.look_at_from_position(Vector3(0, r * 1.05, r * 1.25), Vector3(0, 0, -r * 0.1))
	await _wait(0.6)
	await _shot("whole_from_south")
	var spots: Array = []
	var consts := (JapanVillage as Script).get_script_constant_map()
	if consts.has("DISTRICTS"):
		for d in consts["DISTRICTS"]:
			spots.append([String(d.id), Vector3(d.center.x, 0, d.center.y)])
	else:
		spots.append(["plaza", Vector3.ZERO])
		for k in 8:
			var a := TAU * k / 8.0
			spots.append(["dir%d" % k, Vector3(cos(a), 0, sin(a)) * r * 0.55])
	for s in spots:
		var at: Vector3 = s[1]
		cam.look_at_from_position(at + Vector3(0, 30, 34), at)
		await _wait(0.5)
		await _shot("district_" + String(s[0]))


## The `count` world players nearest the hero say a line of the world chat (bubbles).
func _talk_near(zone: Zone, count: int) -> void:
	var near: Array = get_tree().get_nodes_in_group("world_players")
	near.sort_custom(func(a, b): return a.global_position.distance_to(zone.hero.global_position) < b.global_position.distance_to(zone.hero.global_position))
	for p in near.slice(0, count):
		var s := WorldPlayers.state(p.world_index, WorldPresence.clock())
		var line := WorldChat.line_for(s, randi())
		Game.world_chat.emit(String(s.name), line, WorldPlayers.GUILD_COLORS.get(int(s.guild), Color("bfe8ff")))
		p.bubble(line)
