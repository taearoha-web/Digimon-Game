extends Node
var main: Node
func _ready() -> void:
	GameSettings.load_settings()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"lancer", "perf")
	Game.profile["level"] = 38
	if main.title_screen:
		main.title_screen.queue_free(); main.title_screen = null
	main.hud.visible = true
	for zone_id in [&"town", &"meadow"]:
		await main.go(zone_id, true)
		await get_tree().create_timer(1.5).timeout
		var hero: Hero = main.zone.hero
		var worst_proc := 0.0
		var worst_phys := 0.0
		var sum_proc := 0.0
		var n := 0
		var worst_frame := 0.0
		var t_prev := Time.get_ticks_usec()
		hero.move_input = Vector2(0.6, -0.8)
		for i in 300:
			await get_tree().process_frame
			var t := Time.get_ticks_usec()
			worst_frame = maxf(worst_frame, float(t - t_prev) / 1000.0)
			t_prev = t
			var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			worst_proc = maxf(worst_proc, p); worst_phys = maxf(worst_phys, ph); sum_proc += p; n += 1
		print("ZONE %s: process avg %.2f ms worst %.2f | physics worst %.2f | worst wall frame %.1f ms | nodes %d objects %d draw %d" % [zone_id, sum_proc / n, worst_proc, worst_phys, worst_frame, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		var groups := {}
		for node in get_tree().get_nodes_in_group("mobs"): groups["mobs"] = int(groups.get("mobs", 0)) + 1
		print("  mobs ", groups.get("mobs", 0), " meshes ", _count(main.zone, "MeshInstance3D"), " skeletons ", _count(main.zone, "Skeleton3D"), " anims ", _count(main.zone, "AnimationPlayer"), " lights ", _count(main.zone, "Light3D"), " particles ", _count(main.zone, "GPUParticles3D") + _count(main.zone, "CPUParticles3D"))
	get_tree().quit()
func _count(root: Node, cls: String) -> int:
	var c := 0
	for n in root.find_children("*", cls, true, false): c += 1
	return c
