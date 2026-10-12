extends Node3D
## Bounded, deterministic native GL workload, not a prediction of iPhone FPS.
## Run with Godot 4.3, a rendering display, dummy audio and isolated user data:
## godot --path . --audio-driver Dummy --disable-vsync res://tests/tools/combat_perf.tscn -- OUT_DIR LABEL
## The same fixture must be copied unchanged to the clean baseline worktree.

class RecordingMob extends Mob:
	var hits := 0
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits += 1
		return super.take_hit(amount, critical, color, attacker)
	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass

var out_dir := ""
var label := "candidate"
var camera: Camera3D
var records: Array[Dictionary] = []
var failures: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Combat perf requires rendered GL and OUT_DIR [LABEL]")
		get_tree().quit(1)
		return
	out_dir = args[0]
	label = args[1] if args.size() > 1 else "candidate"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	seed(773)
	var start := Time.get_ticks_usec()
	_build_stage()
	var stage_setup_ms := float(Time.get_ticks_usec() - start) / 1000.0
	await _settle(1.0)
	var idle := await _sample(2.0)
	print("COMBAT PERF idle ", JSON.stringify(idle))
	for family in ClassData.IDS:
		var pool := ClassData.pool(family)
		var skill: Dictionary = pool.back()
		await _cast_case(family, skill)
	var overlap := await _overlap_case() if "overlap" in args else {}
	var geometry := await _geometry_cases()
	var result := {
		"fixture": "combat_perf_v1", "label": label, "quality": 2,
		"resolution": [1280, 720], "renderer": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info().string, "display": DisplayServer.get_name(),
		"caveat": "Native software GL on a cloud machine; compare workload, not iPhone FPS.",
		"stage_setup_ms": stage_setup_ms, "idle": idle, "casts": records,
		"geometry_setup": geometry, "overlap": overlap, "failures": failures,
	}
	var file := FileAccess.open(out_dir.path_join("combat_perf.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	else:
		failures.append("Could not write benchmark JSON")
	_stop_audio()
	print("COMBAT PERF COMPLETE ", label, " -> ", out_dir, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _overlap_case() -> Dictionary:
	var field := Node3D.new()
	add_child(field)
	var skills: Array[Dictionary] = []
	for pair in [[&"warrior", "gladiator"], [&"mage", "ice_storm"], [&"priest", "last_judgement"], [&"summoner", "elder_dragon"]]:
		skills.append(ClassData.find_skill(pair[0], pair[1]))
	var camera_before := camera.global_transform
	var fov_before := camera.fov
	SkillShow._recent_shows.clear()
	# Four signatures repeated over a sustained six-second overlap workload.
	var bursts := field.create_tween().set_loops(12)
	bursts.tween_callback(func():
		for i in skills.size():
			var at := Vector3((i - 1.5) * 1.6, 0, 0)
			SkillShow.play(field, skills[i], at, at + Vector3(0, 0, 2))
			SkillTableau.contact(field, skills[i], at + Vector3.UP))
	bursts.tween_interval(0.5)
	var measurements := await _sample(6.8, out_dir.path_join("overlap.png"), 0.8)
	measurements["casts"] = 48
	measurements["camera_stable"] = camera.global_transform.is_equal_approx(camera_before) and is_equal_approx(camera.fov, fov_before)
	if not measurements.camera_stable:
		failures.append("Overlap moved the camera")
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	measurements["remaining_budget"] = VfxBudget.counters()
	if VfxBudget.counters() != {"particles": 0, "decorations": 0, "lights": 0}:
		failures.append("Overlap leaked VFX reservations")
	print("COMBAT PERF overlap ", JSON.stringify(measurements))
	return measurements

func _build_stage() -> void:
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var clearings: Array[Vector3] = [Vector3(0, 0, 14)]
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-40, 1), Vector2(-15, 2), Vector2(0, 0), Vector2(20, 3), Vector2(40, -1)])]
	Scenery.ground(self, 85.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, clearings, &"meadow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	Scenery.populate(self, &"meadow", rng, 46.0, clearings, 0.62, false)
	WorldArt.landscape(self, &"meadow", 48.0, 871)
	camera = Camera3D.new()
	camera.fov = 51.0
	camera.far = 260.0
	add_child(camera)
	camera.position = Vector3(18, 20, 29)
	camera.look_at(Vector3(0, 6, 0))
	camera.make_current()

func _cast_case(family: StringName, skill: Dictionary) -> void:
	seed(773 + String(skill.id).hash())
	Game.new_profile(family, "Combat Perf", {"gender": 1 if family in [&"mage", &"priest", &"summoner"] else 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.skills[String(skill.id)] = 1
	Game.profile.loadout[0] = String(skill.id)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.stats.crit = 0.0
	hero.stats.haste = 0.0
	hero.position = Vector3(-4, 0, 3)
	var mob := RecordingMob.new()
	mob.setup(&"forest_orc", 100, Vector3.ZERO, hero)
	field.add_child(mob)
	mob.position = Vector3(2, 0, 0)
	mob.hp = 10000000
	mob.max_hp = 10000000
	mob.stats.def = 0.0
	mob.set_physics_process(false)
	hero.target = mob
	hero.set_facing(atan2(mob.position.x - hero.position.x, mob.position.z - hero.position.z))
	VfxArt.warm_up()
	VfxKit.warm_shaders(field, Vector3.ZERO)
	await _settle(0.6)
	SkillShow._recent_shows.clear()
	var initial_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var start := Time.get_ticks_usec()
	hero._cast(skill)
	var cast_ms := float(Time.get_ticks_usec() - start) / 1000.0
	var duration := 9.5 if String(skill.id) == "armageddon" else 3.5
	var measurements := await _sample(duration, out_dir.path_join(String(skill.id) + ".png"), 2.1 if String(skill.id) == "armageddon" else 0.75)
	measurements.merge({"class": String(family), "skill": String(skill.id), "synchronous_cast_ms": cast_ms,
		"initial_nodes": initial_nodes, "real_damage_events": mob.hits, "duration_seconds": duration})
	if String(skill.id) == "armageddon" and mob.hits != 11:
		failures.append("Armageddon expected 11 real hits, got %d" % mob.hits)
	records.append(measurements)
	print("COMBAT PERF cast ", String(skill.id), " ", JSON.stringify(measurements))
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	await _settle(0.2)
	if int(VfxBudget.counters().decorations) != 0 or int(VfxBudget.counters().particles) != 0:
		failures.append("Visual reservations not released after %s" % String(skill.id))

func _geometry_cases() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	# Isolate repeated generation from frame rendering and gameplay timers.
	# Every sample gets a fresh field, same random seed and uncrowded budget.
	for family in ClassData.IDS:
		var skill: Dictionary = ClassData.pool(family).back()
		if String(skill.id) == "armageddon":
			continue
		var durations: Array[float] = []
		var mesh_resources := {}
		var material_resources := {}
		var max_nodes := 0
		for repetition in 25:
			seed(1773 + String(skill.id).hash())
			var field := Node3D.new()
			add_child(field)
			var look := SkillShow.profile_for(skill)
			var start := Time.get_ticks_usec()
			SpellSpectacle.cast(field, skill, look, Vector3(2, 0, 0), Vector3(-4, 0, 3), int(look.tier), 0)
			durations.append(float(Time.get_ticks_usec() - start) / 1000.0)
			max_nodes = maxi(max_nodes, field.find_children("*", "", true, false).size())
			for node in field.find_children("*", "MeshInstance3D", true, false):
				var instance := node as MeshInstance3D
				if instance.mesh:
					mesh_resources[instance.mesh.get_instance_id()] = true
				if instance.material_override:
					material_resources[instance.material_override.get_instance_id()] = true
			field.free()
			if repetition % 5 == 4:
				await get_tree().process_frame
		var record := {"skill": String(skill.id), "samples": durations.size(), "setup_ms": _stats(durations),
			"distinct_mesh_resource_ids": mesh_resources.size(), "distinct_material_resource_ids": material_resources.size(),
			"max_generated_nodes": max_nodes}
		cases.append(record)
		print("COMBAT PERF geometry ", JSON.stringify(record))
	return cases

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _sample(seconds: float, screenshot := "", screenshot_time := 0.0) -> Dictionary:
	var wall: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []
	var draws: Array[float] = []
	var render_objects: Array[float] = []
	var nodes: Array[float] = []
	var objects: Array[float] = []
	var particles: Array[float] = []
	var decorations: Array[float] = []
	var memory_mb: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	var simulation_seconds := 0.0
	var captured := screenshot.is_empty()
	# Godot caps simulation delta across long driver stalls. Sample the actual
	# gameplay clock, with a bounded wall deadline and at least thirty frames.
	while (simulation_seconds < seconds or wall.size() < 30) and float(Time.get_ticks_usec() - start) / 1000000.0 < 30.0:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		simulation_seconds += get_process_delta_time()
		wall.append(float(now - previous) / 1000.0)
		previous = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
		memory_mb.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		particles.append(float(VfxBudget.counters().particles))
		decorations.append(float(VfxBudget.counters().decorations))
		if not captured and simulation_seconds >= screenshot_time:
			captured = true
			if get_viewport().get_texture().get_image().save_png(screenshot) != OK:
				failures.append("Could not save screenshot " + screenshot)
			# Exclude PNG readback/write time from the following frame sample.
			previous = Time.get_ticks_usec()
	return {"samples": wall.size(), "simulation_seconds": simulation_seconds, "actual_wall_seconds": float(Time.get_ticks_usec() - start) / 1000000.0,
		"wall_frame_ms": _stats(wall), "process_ms": _stats(process),
		"physics_ms": _stats(physics), "draw_calls": _stats(draws), "render_objects": _stats(render_objects),
		"nodes": _stats(nodes), "objects": _stats(objects), "memory_mb": _stats(memory_mb),
		"particles": _stats(particles), "decorations": _stats(decorations)}

func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	values.sort()
	var total := 0.0
	for value in values:
		total += value
	return {"mean": total / float(values.size()), "p50": values[int(floor(float(values.size() - 1) * 0.5))],
		"p95": values[int(floor(float(values.size() - 1) * 0.95))], "max": values.back()}

func _stop_audio() -> void:
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
