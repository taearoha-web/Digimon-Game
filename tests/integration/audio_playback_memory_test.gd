extends Node
## Same sound workload in the engine's forced Sample and Stream paths.
## Sample reproduces Godot 4.3 issue #96068 even on native (not an iPhone test).
## -- OUT.json [sample|stream]; use isolated XDG data directories.
var samples: Array[Dictionary] = []
var failures: Array[String] = []
var checks := 0
const SOUNDS: Array[StringName] = [&"coin", &"pickup", &"thunder", &"crit"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	Game.set_process(false)
	var args := OS.get_cmdline_user_args()
	var sample_mode := args.size() > 1 and args[1] == "sample"
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			if sample_mode:
				player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
			else:
				check(player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "live audio player uses Stream: " + player.name)
	if not sample_mode:
		# Project settings use 0=Stream/1=Sample, unlike the AudioServer enum.
		check(int(ProjectSettings.get_setting("audio/general/default_playback_type.web")) == 0, "web project default cannot fall back to Sample")
		# The web build mixes on its one thread: a buffer under a slow frame (30 fps on an
		# iPhone, a busy guild war) runs dry and the music stutters.
		check(int(ProjectSettings.get_setting("audio/driver/output_latency.web")) >= 100, "the web audio buffer outlasts a slow frame")
		# A far AI fighter's sound is not played; a near one is, once per repeat window.
		var skipped := AudioManager.near_skipped
		AudioManager.play_sfx_at(Vector3(0, 0, AudioManager.HEAR_RADIUS * 4.0), SOUNDS[0])
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			check(AudioManager.near_skipped == skipped + 1, "a sound far across the field is not played")
		var before := AudioManager.sound_play_requests
		var at := cam.global_position if cam != null else Vector3.ZERO
		AudioManager.play_sfx_at(at, &"heal")
		AudioManager.play_sfx_at(at, &"heal")
		check(AudioManager.sound_play_requests == before + 1, "the same near sound starts once per repeat window")
	for sound in SOUNDS:
		check(AudioManager.has_sound(sound), "fixture sound exists: " + String(sound))
		AudioManager.play_sfx(sound)
	await get_tree().create_timer(0.5).timeout
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await get_tree().create_timer(0.3).timeout
	for cycle in 5:
		if cycle > 0:
			for batch in 25:
				for i in 10:
					AudioManager.play_sfx(SOUNDS[(batch * 10 + i) % SOUNDS.size()])
				await get_tree().process_frame
			for player in AudioManager.get_children():
				if player is AudioStreamPlayer:
					player.stop()
			await get_tree().create_timer(0.4).timeout
		var snapshot := {"cycle": cycle, "play_calls": cycle * 250,
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC))}
		samples.append(snapshot)
		print("AUDIO MEMORY: ", JSON.stringify(snapshot))
	var object_growth := int(samples.back().objects) - int(samples.front().objects)
	if sample_mode:
		check(object_growth >= 900, "forced Sample reproduces retained playback objects")
	else:
		check(object_growth <= 8, "Stream returns to its object baseline after one thousand sound plays")
		check(int(samples.back().resources) <= int(samples.front().resources) + 2, "Stream does not retain extra sound resources")
	check(int(samples.back().nodes) == int(samples.front().nodes), "the audio player pool stays fixed")
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify({"mode": "sample" if sample_mode else "stream", "godot": Engine.get_version_info().string,
			"native_forced_playback_test": true, "physical_iphone_tested": false, "checks": checks,
			"object_growth": object_growth, "sound_ids": SOUNDS, "samples": samples, "failures": failures}, "\t"))
	print("AUDIO MEMORY: ", checks, " checks, ", failures.size(), " failures; object growth ", object_growth)
	get_tree().quit(failures.size())
