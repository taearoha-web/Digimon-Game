extends Node
## Script cost of the village with its world players: builds the town with the hero in it
## and prints the mean and worst process / physics time over a few hundred frames and how
## many world players are shown (compare TOON_WORLD_PLAYERS=0 and 1).
##   TOON_WORLD_PLAYERS=1 TOON_WORLD_DAYS=3.4 godot --headless --path . res://tests/tools/town_perf.tscn -- [quality]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.load_settings()
	GameSettings.quality = int(args[0]) if args.size() > 0 else 0
	Game.set_process(false)
	Game.new_profile(&"warrior", "TownPerf", FaceKit.default_look())
	Game.current_zone = &"town"
	var zone := Zone.new()
	zone.zone_id = &"town"
	add_child(zone)
	for i in 120:
		await get_tree().physics_frame
	var mode := args[1] if args.size() > 1 else ""
	for p in get_tree().get_nodes_in_group("world_players"):
		if mode.contains("noanim") and p.visual.anim != null:
			p.visual.anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if mode.contains("novis"):
			p.visual.set_process(false)
		if mode.contains("nophys"):
			p.set_physics_process(false)
	var proc: Array[float] = []
	var phys: Array[float] = []
	for i in 600:
		await get_tree().process_frame
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	proc.sort()
	phys.sort()
	var mean := func(a: Array[float]) -> float:
		var s := 0.0
		for v in a:
			s += v
		return s / float(a.size())
	print("TOWN shown=%d quality=%d | process p50 %.2f mean %.2f p95 %.2f ms | physics p50 %.2f mean %.2f p95 %.2f ms | nodes %d" % [
		get_tree().get_nodes_in_group("world_players").size(), GameSettings.quality, proc[proc.size() / 2], mean.call(proc), proc[int(proc.size() * 0.95)],
		phys[phys.size() / 2], mean.call(phys), phys[int(phys.size() * 0.95)], int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	get_tree().quit()
