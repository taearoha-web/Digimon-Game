extends Node
## What the other players' pets cost: a zone full of world players (the village on a busy
## day, or a field), counted and timed. Prints the players, the pets shown, the node and
## object counts and the mean / worst frame (process + physics) over the measured frames.
##   godot --headless --path . res://tests/tools/pet_crowd_probe.tscn -- [ZONE] [FRAMES] [DAY] [off]
## "off" measures the same zone without the other players' pets (PetCrowd.enabled false):
## the cost before pets. ZONE "where" lists where the world players are at that DAY.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else &"town"
	var frames := int(args[1]) if args.size() > 1 else 300
	var day := float(args[2]) if args.size() > 2 else 3.4
	PetCrowd.enabled = not (args.size() > 3 and args[3] == "off")
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + day * 86400.0 - WorldPlayers.now()
	if zone_id == &"where":
		var places := {}
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, WorldPresence.clock())
			if bool(s.online):
				places[String(s.place)] = int(places.get(String(s.place), 0)) + 1
		print("PET PROBE where: ", places)
		get_tree().quit(0)
		return
	Game.new_profile(&"warrior", "Probe", FaceKit.default_look())
	Game.profile.level = 60
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	for i in 150:
		await get_tree().physics_frame
	# Stand in the middle of the players, so the most pets are near.
	var players := get_tree().get_nodes_in_group("world_players")
	if not players.is_empty() and zone.hero:
		var middle := Vector3.ZERO
		for p in players:
			middle += (p as Node3D).global_position
		middle /= float(players.size())
		zone.hero.global_position = Vector3(middle.x, zone.hero.global_position.y, middle.z)
	for i in 60:
		await get_tree().physics_frame
	var total := 0.0
	var worst := 0.0
	for i in frames:
		await get_tree().process_frame
		var t := Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		total += t
		worst = maxf(worst, t)
	var pets := 0
	for group in ["pet_followers", "ai_pets"]:
		for n in get_tree().get_nodes_in_group(group):
			if (n as Node3D).visible:
				pets += 1
	print("PET PROBE %s: players %d, other pets shown %d, nodes %d, objects %d, frame mean %.2f ms, worst %.2f ms" % [
		zone_id, get_tree().get_nodes_in_group("world_players").size(), pets,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		total / float(frames) * 1000.0, worst * 1000.0])
	get_tree().quit(0)
