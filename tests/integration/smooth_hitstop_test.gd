extends Node
## Mobile smooth mode must never slow simulation; the optional cinematic mode
## still restores the caller's clock and cannot chain on simultaneous AoE hits.

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _ready() -> void:
	GameSettings.load_settings()
	var saved := GameSettings.combat_hitstop
	var saved_scale := Engine.time_scale
	HitFeel._last_stop = 0
	HitFeel._stopped = false
	GameSettings.combat_hitstop = false
	for i in 30:
		HitFeel.hitstop(get_tree(), HitFeel.stop_for(true, 20.0))
	check(is_equal_approx(Engine.time_scale, saved_scale), "smooth combat preserves game speed on repeated critical hits")
	check(not HitFeel._stopped and HitFeel._last_stop == 0, "disabled hitstop reserves no cooldown or timer")
	GameSettings.combat_hitstop = true
	HitFeel.hitstop(get_tree(), 0.03)
	check(Engine.time_scale < 0.2 and HitFeel._stopped, "optional cinematic hitstop remains available")
	var stamp := HitFeel._last_stop
	HitFeel.hitstop(get_tree(), 0.1)
	check(HitFeel._last_stop == stamp, "simultaneous hits never extend the slowdown")
	await get_tree().create_timer(0.1, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, saved_scale) and not HitFeel._stopped, "cinematic mode restores the original clock")
	GameSettings.combat_hitstop = saved
	Engine.time_scale = saved_scale
	print("SMOOTH HITSTOP: %s | 5 checks" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)
