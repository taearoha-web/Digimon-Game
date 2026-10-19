extends Node
## The memory guard: pressure levels rise at once and fall only after a calm
## stretch; the effect budget, shadow map and glow follow the level; the
## readings a zone reports stay inside the phone budget at rest.
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	await get_tree().process_frame
	GameSettings.load_settings()
	GameSettings.quality = 2
	var tree := get_tree()
	MemoryGuard.force(-1, tree)
	check(MemoryGuard.pressure == 0, "starts at no pressure")
	var full := VfxBudget.particle_limit()
	var full_count := VfxBudget.count(40)
	var full_decor := VfxBudget.decoration_limit()
	check(full == 420 and full_count == 40 and full_decor == 88, "high quality budget at rest (%d, %d, %d)" % [full, full_count, full_decor])
	check(VfxBudget.can_light(), "effect lights allowed at rest on high quality")
	# Readings above the phone/desktop raise line move the level up at once.
	MemoryGuard.video_mb = 1.0e9
	MemoryGuard.set_level(MemoryGuard._wanted(2.0), tree)
	check(MemoryGuard.pressure == 2, "a huge reading raises straight to strict")
	check(MemoryGuard.raises == 1, "the raise is counted")
	check(VfxBudget.particle_limit() == int(420 * 0.4) and VfxBudget.count(40) == 16 and VfxBudget.decoration_limit() == int(88 * 0.4), "strict pressure trims the budget (%d, %d, %d)" % [VfxBudget.particle_limit(), VfxBudget.count(40), VfxBudget.decoration_limit()])
	check(VfxBudget.count(3) >= 1, "every effect keeps at least its minimum")
	check(not VfxBudget.can_light(), "no effect lights under pressure")
	check(not MemoryGuard.glow_allowed(), "no glow under pressure")
	check(MemoryGuard.shadow_size() == 1024, "strict pressure shrinks the shadow map")
	# Calm readings: the level only drops after DROP_AFTER_SECONDS below the drop line.
	MemoryGuard.video_mb = 1.0
	MemoryGuard.heap_mb = 1.0
	MemoryGuard.set_level(MemoryGuard._wanted(2.0), tree)
	check(MemoryGuard.pressure == 2, "a calm reading does not drop the level at once")
	MemoryGuard.set_level(MemoryGuard._wanted(MemoryGuard.DROP_AFTER_SECONDS), tree)
	check(MemoryGuard.pressure == 1, "after the calm stretch the level drops one step")
	MemoryGuard.set_level(MemoryGuard._wanted(MemoryGuard.DROP_AFTER_SECONDS), tree)
	check(MemoryGuard.pressure == 0, "and then back to normal")
	check(VfxBudget.particle_limit() == full and VfxBudget.count(40) == full_count, "the full budget is back")
	# A reading between the lines keeps the level where it is.
	var raise: float = MemoryGuard.VIDEO_DESKTOP[0] if not MemoryGuard.phone() else MemoryGuard.VIDEO_PHONE[0]
	MemoryGuard.video_mb = raise + 1.0
	MemoryGuard.set_level(MemoryGuard._wanted(2.0), tree)
	check(MemoryGuard.pressure == 1, "the first line raises to trimmed")
	MemoryGuard.video_mb = raise - 5.0
	MemoryGuard.set_level(MemoryGuard._wanted(MemoryGuard.DROP_AFTER_SECONDS), tree)
	check(MemoryGuard.pressure == 1, "between the drop and raise lines the level holds")
	MemoryGuard.force(-1, tree)
	check(MemoryGuard.pressure == 0, "force(-1) resets")
	# A built zone registers its environment with the guard and follows the glow rule.
	Game.new_profile(&"mage", "Guard QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.current_zone = &"meadow"
	var zone := Zone.new()
	zone.zone_id = &"meadow"
	zone.staged = true
	add_child(zone)
	if not zone.is_built:
		await zone.built
	print("memory_guard_test: zone built")
	var envs := tree.get_nodes_in_group("world_env")
	check(envs.size() == 1 and envs[0] is WorldEnvironment, "the zone's environment is registered")
	var env: Environment = (envs[0] as WorldEnvironment).environment
	check(env.glow_enabled == MemoryGuard.glow_allowed(), "glow follows the guard at rest")
	MemoryGuard.force(1, tree)
	check(not env.glow_enabled, "trimmed pressure switches glow off in the live zone")
	MemoryGuard.force(-1, tree)
	check(env.glow_enabled == MemoryGuard.glow_allowed(), "glow returns when the pressure clears")
	# The guard's own tick reads the monitors without error.
	MemoryGuard._accum = MemoryGuard.TICK_SECONDS
	MemoryGuard.tick(tree, 0.1)
	check(MemoryGuard.video_mb >= 0.0 and MemoryGuard.heap_mb >= 0.0, "tick reads the monitors")
	var report := MemoryGuard.report()
	check(report.has("pressure") and report.has("videoMB") and report.has("heapMB"), "report carries the readings")
	zone.queue_free()
	await get_tree().process_frame
	print("memory_guard_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
