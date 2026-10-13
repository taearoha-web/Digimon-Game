extends Node
## Frame cost of a real field with auto hunting: builds the zone, lets a Lv.100
## hero (full skill bar, endless HP and MP) hunt on auto, and prints per-frame
## wall time, scripted process / physics time and node counts.
##   godot --headless --path . res://tests/tools/zone_perf_probe.tscn -- [zone] [class] [seconds] [quality]
var frame_ms: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var _last := 0
var spikes: Array = []
var _t0 := 0
var _on := false


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		# Browser run: ?zone=abyss&cls=lancer&sec=20&q=1&exp=noanim,spikes
		var query := String(JavaScriptBridge.eval("location.search"))
		var values := {}
		for pair in query.trim_prefix("?").split("&"):
			var kv := pair.split("=")
			if kv.size() == 2:
				values[kv[0]] = kv[1]
		args = PackedStringArray([values.get("zone", "abyss"), values.get("cls", "lancer"), values.get("sec", "20"), values.get("q", "1")])
		args.append_array(String(values.get("exp", "")).split(",", false))
	var zone_id := StringName(args[0]) if args.size() > 0 else &"abyss"
	var cls := StringName(args[1]) if args.size() > 1 else &"lancer"
	var seconds := float(args[2]) if args.size() > 2 else 20.0
	GameSettings.quality = int(args[3]) if args.size() > 3 else 1
	GameSettings.combat_hitstop = false
	if "noflourish" in args:
		ClassFlourish.enabled = false
	Game.new_profile(cls, "Perf")
	var p := Game.profile
	p.level = 100
	p.adv = 4
	p.attrs = {"str": 400, "int": 400, "dex": 400, "vit": 900}
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	await get_tree().create_timer(1.0).timeout
	var hero := zone.hero
	# Stand in the first camp so auto hunting really fights.
	var camp: Dictionary = zone.data.camps[0]
	hero.global_position = Vector3(camp.pos.x - float(camp.radius) * 0.5, 0.2, camp.pos.y)
	await get_tree().create_timer(0.5).timeout
	p.hp = 1000000000
	p.mp = 1000000000
	hero.set_auto(true)
	var mobs := get_tree().get_nodes_in_group("mobs").size()
	print("ZONE %s class %s mobs=%d quality=%d | video=%.0fMB texture=%.0fMB buffer=%.0fMB static=%.0fMB" % [zone_id, cls, mobs, GameSettings.quality,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	_on = true
	_t0 = Time.get_ticks_usec()
	var start := Time.get_ticks_msec()
	var kills0 := int(p.get("kills", 0))
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		p.hp = 1000000000
		p.mp = 1000000000
		_experiment(args, zone)
		await get_tree().create_timer(0.5).timeout
	_on = false
	var census := {}
	for node in zone.find_children("*", "", true, false):
		var key := String(node.get_class())
		if node.get_script() != null:
			key += ":" + String(node.get_script().get_global_name())
		census[key] = int(census.get(key, 0)) + 1
	var rows: Array = census.keys()
	rows.sort_custom(func(a, b): return census[a] > census[b])
	var line := "CENSUS"
	for k in rows.slice(0, 14):
		line += " %s=%d" % [k, census[k]]
	print(line, " tweens=", get_tree().get_processed_tweens().size())
	if "spikes" in args:
		print("SPIKES ", JSON.stringify(spikes))
	var fm := frame_ms.duplicate()
	fm.sort()
	var total := 0.0
	var over33 := 0
	var over50 := 0
	for v in fm:
		total += v
		if v > 33.0: over33 += 1
		if v > 50.0: over50 += 1
	var pm := process_ms.duplicate()
	pm.sort()
	var ph := physics_ms.duplicate()
	ph.sort()
	print("PERF frames=%d mean=%.2fms p50=%.2f p95=%.2f p99=%.2f max=%.2f over33=%d over50=%d | process p50=%.2f p95=%.2f max=%.2f | physics p50=%.2f p95=%.2f max=%.2f | kills=%d mobs=%d nodes=%d objects=%d resources=%d" % [
		fm.size(), total / maxf(1.0, fm.size()), fm[fm.size() / 2], fm[int(fm.size() * 0.95)], fm[int(fm.size() * 0.99)], fm[-1], over33, over50,
		pm[pm.size() / 2], pm[int(pm.size() * 0.95)], pm[-1], ph[ph.size() / 2], ph[int(ph.size() * 0.95)], ph[-1],
		int(p.get("kills", 0)) - kills0, get_tree().get_nodes_in_group("mobs").size(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	get_tree().quit()


## Switch one cost off to see how much of the frame it was.
##   noanim   mobs stop animating      nomobphys   mobs stop physics
##   nohero   hero visual stops        nocompanion  no companions or summons
func _experiment(args: PackedStringArray, zone: Zone) -> void:
	if "nolabels" in args:
		BattleVfx._floating_active = 1000
	for node in get_tree().get_nodes_in_group("mobs"):
		var mob := node as Mob
		if mob == null:
			continue
		if "noanim" in args and mob.visual:
			for player in mob.visual.find_children("*", "AnimationPlayer", true, false):
				(player as AnimationPlayer).active = false
		if "nomobphys" in args:
			mob.set_physics_process(false)
		if "nomobvis" in args and mob.visual:
			mob.visual.visible = false
	if "nocompanion" in args:
		for node in get_tree().get_nodes_in_group("companions") + get_tree().get_nodes_in_group("summons"):
			node.queue_free()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _on and _last > 0:
		frame_ms.append(float(now - _last) / 1000.0)
		if float(now - _last) / 1000.0 > 10.5:
			spikes.append([snappedf(float(now - _t0) / 1000000.0, 0.001), snappedf(float(now - _last) / 1000.0, 0.1)])
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_last = now
