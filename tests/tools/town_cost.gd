extends Node
## Where the village's CPU time goes: builds the town (with world players when
## TOON_WORLD_PLAYERS=1) and measures process / physics time with every part on, then
## with one part switched off at a time (physics server step, each node class's
## callbacks, animation, skeleton updates), so the cost of each part is the difference.
##   TOON_WORLD_PLAYERS=1 TOON_WORLD_DAYS=3.4 godot --headless --path . res://tests/tools/town_cost.tscn -- [quality] [frames]

var frames := 300


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	GameSettings.load_settings()
	GameSettings.quality = int(args[0]) if args.size() > 0 else 2
	frames = int(args[1]) if args.size() > 1 else 300
	Game.set_process(false)
	Game.new_profile(&"warrior", "TownCost", FaceKit.default_look())
	Game.current_zone = &"town"
	var zone := Zone.new()
	zone.zone_id = &"town"
	add_child(zone)
	for i in 120:
		await get_tree().physics_frame
	_census(zone)
	var base := await _measure("all on")
	# Physics server step only (every _physics_process still runs).
	PhysicsServer3D.set_active(false)
	await _measure("physics server off", base)
	PhysicsServer3D.set_active(true)
	for cls in ["FieldPlayer", "Companion", "Hero", "Mob", "Zone", "WorldPresence", "HeroVisual", "AnimationPlayer", "AnimationTree", "Skeleton3D", "GPUParticles3D", "CPUParticles3D", "Camera3D", "Control", "Node3D"]:
		var nodes := _of_class(cls)
		if nodes.is_empty():
			continue
		var saved: Array = []
		for n in nodes:
			saved.append([n, n.is_processing(), n.is_physics_processing(), n.is_processing_internal(), n.is_physics_processing_internal()])
			n.set_process(false)
			n.set_physics_process(false)
			if cls in ["AnimationPlayer", "AnimationTree", "Skeleton3D", "GPUParticles3D", "CPUParticles3D"]:
				n.set_process_internal(false)
				n.set_physics_process_internal(false)
		await _measure("%s off (%d)" % [cls, nodes.size()], base)
		for s in saved:
			s[0].set_process(s[1])
			s[0].set_physics_process(s[2])
			s[0].set_process_internal(s[3])
			s[0].set_physics_process_internal(s[4])
	# Animation players in manual mode: the pose work without the callback.
	var players := _of_class("AnimationPlayer")
	var modes: Array = []
	for p in players:
		modes.append((p as AnimationPlayer).callback_mode_process)
		(p as AnimationPlayer).callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await _measure("animation manual (%d)" % players.size(), base)
	for i in players.size():
		(players[i] as AnimationPlayer).callback_mode_process = modes[i]
	get_tree().quit()


func _of_class(cls: String) -> Array:
	var out: Array = []
	for n in get_tree().root.find_children("*", cls, true, false):
		if n.get_class() == cls or (n.get_script() != null and _script_class(n) == cls):
			out.append(n)
	if out.is_empty():
		# Script classes: match by class_name through the script chain.
		for n in get_tree().root.find_children("*", "", true, false):
			if n.get_script() != null and _script_is(n, cls):
				out.append(n)
	return out


static func _script_class(n: Node) -> String:
	var s: Script = n.get_script()
	return s.get_global_name() if s != null else ""


static func _script_is(n: Node, cls: String) -> bool:
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() == cls:
			return true
		s = s.get_base_script()
	return false


func _census(zone: Node) -> void:
	var counts := {}
	for n in get_tree().root.find_children("*", "", true, false):
		var key := n.get_class()
		if n.get_script() != null and _script_class(n) != "":
			key = _script_class(n)
		counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var parts: PackedStringArray = []
	for k in keys.slice(0, 28):
		parts.append("%s %d" % [k, counts[k]])
	print("CENSUS nodes=%d | %s" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), " · ".join(parts)])
	var processing := 0
	var physics := 0
	for n in get_tree().root.find_children("*", "", true, false):
		processing += 1 if n.is_processing() else 0
		physics += 1 if n.is_physics_processing() else 0
	print("CENSUS processing=%d physics_processing=%d bodies: static %d character %d rigid %d area %d shapes %d" % [processing, physics,
		_of_class("StaticBody3D").size(), _of_class("CharacterBody3D").size(), _of_class("RigidBody3D").size(), _of_class("Area3D").size(),
		get_tree().root.find_children("*", "CollisionShape3D", true, false).size()])


func _measure(label: String, base: Array = []) -> Array:
	var proc: Array[float] = []
	var phys: Array[float] = []
	for i in 30:
		await get_tree().process_frame
	for i in frames:
		await get_tree().process_frame
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	proc.sort()
	phys.sort()
	var p := proc[proc.size() / 2]
	var h := phys[phys.size() / 2]
	var line := "COST %-28s process p50 %6.2f p95 %6.2f | physics p50 %6.2f p95 %6.2f" % [label, p, proc[int(proc.size() * 0.95)], h, phys[int(phys.size() * 0.95)]]
	if not base.is_empty():
		line += " | saves process %5.2f physics %5.2f ms" % [float(base[0]) - p, float(base[1]) - h]
	print(line)
	return [p, h]
