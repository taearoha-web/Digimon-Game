extends Node
## Web only: does a repeated action grow the object count / wasm memory?  ?mode=save|sfx|sfxall|poll|cloud  ?n=300
## Found the audio leak: with a suspended browser audio context (no mixing) every sound played kept
## two playback objects and ~110 KB for good. AudioManager now skips sounds while the mixer is stalled.
## Run: temporarily set run/main_scene to this scene and move it out of the export filter
## (tests/* is excluded), export Web to build/probe, then
##   SUSPENDED=1 node tests/tools/web_probe.mjs build/probe "mode=sfx&n=300" 100   (suspended audio context: must stay flat)
##   node tests/tools/web_probe.mjs build/probe "mode=sfx&n=300" 100               (running context: flat too)
var _mode := "save"
var _n := 300


func _ready() -> void:
	var query := String(JavaScriptBridge.eval("location.search")) if OS.has_feature("web") else ""
	for pair in query.trim_prefix("?").split("&"):
		var kv := pair.split("=")
		if kv.size() == 2 and kv[0] == "mode":
			_mode = kv[1]
		elif kv.size() == 2 and kv[0] == "n":
			_n = int(kv[1])
	Game.set_process(false)
	Game.new_profile(&"lancer", "Probe")
	Game.profile.level = 100
	await get_tree().create_timer(1.0).timeout
	if _mode == "sfxall":
		var dir := DirAccess.open("res://audio/sfx")
		var ids: Array[String] = []
		for f in dir.get_files():
			if f.ends_with(".import"):
				ids.append(f.get_basename().get_basename())
		ids.sort()
		for id in ids:
			var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			for i in 20:
				AudioManager.play_sfx(StringName(id))
				await get_tree().create_timer(0.05).timeout
			await get_tree().create_timer(0.3).timeout
			print("PROBE sfx %-24s +%d objs for 20 plays" % [id, int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before])
		print("PERF done")
		get_tree().quit()
		return
	for round_no in 6:
		var o0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var m0 := OS.get_static_memory_usage()
		for i in _n:
			match _mode:
				"save":
					Game.mark_dirty()
					Game.save()
				"sfx":
					AudioManager.play_sfx(&"hit_special")
				"poll":
					Game._poll_cloud_modal()
					Game._record_web_session_sample()
				"cloud":
					Game._queue_cloud_save()
			if i % 20 == 0:
				await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		print("PROBE mode=%s round=%d mixgap=%.2f objs %d -> %d  static %.1f -> %.1f MB  wasm=%s" % [_mode, round_no, AudioServer.get_time_since_last_mix(), o0, int(Performance.get_monitor(Performance.OBJECT_COUNT)), m0 / 1048576.0, OS.get_static_memory_usage() / 1048576.0, str(JavaScriptBridge.eval("typeof Module !== 'undefined' && Module.HEAPU8 ? Module.HEAPU8.length : (window.__godotHeap ? window.__godotHeap() : -1)"))])
	print("PERF done")
	get_tree().quit()
