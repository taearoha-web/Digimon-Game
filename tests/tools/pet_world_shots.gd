extends Node
## Screenshots of everyone's pets through the real game scenes: the village full of world
## players each with its pet following (the hero's own too), a field with world players
## hunting beside their pets, and the guild war (no pets there).
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/pet_world_shots.tscn -- <out_dir> [DAYS]
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


## Puts the hero (and its camera) in the middle of the world players here.
func _among_players(zone: Zone, back := Vector3(0, 0.2, 6.0)) -> void:
	var bots := get_tree().get_nodes_in_group("world_players")
	if bots.is_empty():
		return
	var best: Node3D = null
	var best_n := -1
	for b in bots:
		var n := 0
		for o in bots:
			if (o as Node3D).global_position.distance_to((b as Node3D).global_position) < 14.0:
				n += 1
		if n > best_n:
			best_n = n
			best = b
	zone.hero.global_position = best.global_position + back
	zone.camera_rig.snap_to_target()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var days := float(args[1]) if args.size() > 1 else 60.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + days * 86400.0 - WorldPlayers.now()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"lancer", "เลี้ยงสัตว์")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 200
	Game.profile.flags[Tutorial.FLAG] = Tutorial.DONE
	Game.choose_pet("fire")
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	# The village.
	await main.go(&"town", true)
	await _wait(4.0)
	var town: Zone = main.zone
	# In front of the busiest row of stalls, looking at the keepers and their pets.
	var keeper: FieldPlayer = null
	var best_n := -1
	for b in get_tree().get_nodes_in_group("world_players"):
		var p := b as FieldPlayer
		if p == null or not p.stall_at.is_finite():
			continue
		var n := 0
		for o in get_tree().get_nodes_in_group("world_players"):
			if (o as Node3D).global_position.distance_to(p.global_position) < 14.0:
				n += 1
		if n > best_n:
			best_n = n
			keeper = p
	if keeper:
		var face := keeper.stall_face
		face.y = 0.0
		face = face.normalized()
		town.hero.global_position = keeper.stall_at + face * 6.0 + Vector3(0, 0.2, 0)
		town.camera_rig.set_yaw_behind(atan2(face.x, face.z))
		town.camera_rig.snap_to_target()
	else:
		_among_players(town)
	await _wait(5.0)
	await _shot("village_pets")
	town.camera_rig.distance = 30.0
	await _wait(2.0)
	await _shot("village_pets_wide")
	# A field with hunters.
	var places := {}
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, WorldPresence.clock())
		if bool(s.online) and String(s.place) != "town" and String(s.place) != "":
			places[String(s.place)] = int(places.get(String(s.place), 0)) + 1
	var field := &"meadow"
	var most := 0
	for p in places:
		if int(places[p]) > most:
			most = int(places[p])
			field = StringName(p)
	print("FIELD ", field, " ", most)
	await main.go(field, true)
	await _wait(5.0)
	var zone: Zone = main.zone
	zone.hero._invulnerable_until = Time.get_ticks_msec() + 600000
	_among_players(zone)
	await _wait(5.0)
	await _shot("field_pets")
	await _wait(4.0)
	await _shot("field_pets_later")
	# The guild war: players fight on their own, no pets.
	await main.go(&"guildwar", false, true)
	await _wait(6.0)
	await _shot("guildwar_no_pets")
	get_tree().quit()
