extends Node
## What a zone change costs: builds a list of zones one after another (the way
## Main.go does, minus the fade), freeing the previous one, and prints how long
## the synchronous build took, where it went (Zone phases) and the frame times after.
##   godot --path . res://tests/tools/zone_switch_probe.tscn -- town,dark_forest,town,desert  [class]
## Web: ?zones=town,dark_forest,town,desert&cls=summoner
var _last := 0
var _staged := true
var _frames: Array[float] = []


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var zones: PackedStringArray = ["town", "dark_forest", "town", "desert", "town", "snow", "town"]
	var cls := &"summoner"
	if OS.has_feature("web"):
		var query := String(JavaScriptBridge.eval("location.search"))
		for pair in query.trim_prefix("?").split("&"):
			var kv := pair.split("=")
			if kv.size() == 2 and kv[0] == "zones":
				zones = kv[1].split(",")
			elif kv.size() == 2 and kv[0] == "cls":
				cls = StringName(kv[1])
			elif kv.size() == 2 and kv[0] == "staged":
				_staged = kv[1] == "1"
			elif kv.size() == 2 and kv[0] == "q":
				GameSettings.quality = int(kv[1])
	else:
		var args := OS.get_cmdline_user_args()
		if args.size() > 0:
			zones = args[0].split(",")
		if args.size() > 1:
			cls = StringName(args[1])
	Game.new_profile(cls, "Probe")
	Game.profile.level = 100
	Game.profile.adv = 4
	Zone.phase_log = true
	await get_tree().create_timer(1.0).timeout
	var current: Zone = null
	for zone_id in zones:
		if current:
			current.queue_free()
			current = null
			await get_tree().process_frame
		Game.current_zone = StringName(zone_id)
		Zone.phases = []
		await get_tree().process_frame
		_frames.clear()
		var t := Time.get_ticks_usec()
		current = Zone.new()
		current.zone_id = StringName(zone_id)
		current.staged = _staged
		add_child(current)
		if _staged and not current.is_built:
			await current.built
		var build_ms := float(Time.get_ticks_usec() - t) / 1000.0
		var build_worst := 0.0
		for f in _frames:
			build_worst = maxf(build_worst, f)
		var build_frames := _frames.size()
		_frames.clear()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 3500:
			await get_tree().process_frame
		var worst := 0.0
		var over50 := 0
		for f in _frames:
			worst = maxf(worst, f)
			if f > 50.0:
				over50 += 1
		print("SWITCH %s build=%.0fms (%d frames, worst %.0fms) | after: frames=%d worst=%.0fms over50=%d | tris=%d draws=%d video=%.0fMB | %s" % [zone_id, build_ms, build_frames, build_worst, _frames.size(), worst, over50,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, JSON.stringify(Zone.phases)])
	print("PERF done")
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last > 0:
		_frames.append(float(now - _last) / 1000.0)
	_last = now
