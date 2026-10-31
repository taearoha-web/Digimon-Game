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
	# Travel drops the skill art meshes cached in the last zone (any class's casts).
	BuffArt.mesh_for({"id": "sacred_sanctuary"})
	check(not BuffArt._meshes.is_empty(), "a buff mesh is cached while it is in use")
	for art in [BuffArt, EliteSkillArt, SpellSpectacle, VfxArt, BardSkillArt, ShadowSkillArt, LordSkillArt, SkillInk, ShaderBurst, ThunderStormArt, VfxKit]:
		art.release_mesh_cache()
	check(BuffArt._meshes.is_empty() and EliteSkillArt._meshes.is_empty() and SpellSpectacle._tube_meshes.is_empty() and VfxArt._art_meshes.is_empty(), "travel releases the cached skill art meshes")
	# An iPhone has its own, lower lines: the readings of the v0.9.4 Dark Lord session
	# that was closed (199 MB heap, 117 MB video) trim the effects there.
	MemoryGuard.ios_override = 1
	MemoryGuard.video_mb = 117.0
	MemoryGuard.heap_mb = 199.0
	MemoryGuard.set_level(MemoryGuard._wanted(2.0), tree)
	check(MemoryGuard.lines()[0] == MemoryGuard.VIDEO_IOS and MemoryGuard.pressure == 1, "an iPhone trims at the readings of the closed session (%d)" % MemoryGuard.pressure)
	MemoryGuard.heap_mb = 240.0
	MemoryGuard.set_level(MemoryGuard._wanted(2.0), tree)
	check(MemoryGuard.pressure == 2, "and goes strict above its heap line")
	MemoryGuard.heap_mb = 1.0
	MemoryGuard.video_mb = 1.0
	MemoryGuard.set_level(MemoryGuard._wanted(MemoryGuard.DROP_AFTER_SECONDS * 3.0), tree)
	check(MemoryGuard.pressure == 2, "an iPhone keeps its raised level (no glow/shadow buffer flips mid-fight)")
	# On an iPhone each level also lowers the drawn resolution (1920 -> 1600 -> 1280 px).
	GameSettings.quality = 2
	check(MemoryGuard.render_quality() == 0, "an iPhone at strict pressure draws at the 1280 px budget (%d)" % MemoryGuard.render_quality())
	MemoryGuard.ios_override = 0
	check(MemoryGuard.render_quality() == 2, "elsewhere the resolution follows the chosen quality")
	MemoryGuard.ios_override = 1
	MemoryGuard.apply_render(tree)
	check(Engine.max_fps == MemoryGuard.IOS_MAX_FPS, "an iPhone runs at a steady 30 fps so it stays cool")
	MemoryGuard.ios_override = 0
	MemoryGuard.apply_render(tree)
	check(Engine.max_fps == 0, "other devices are not capped")
	# A sustained low frame rate on an iPhone steps the guard up (lower resolution, fewer effects).
	MemoryGuard.ios_override = 1
	MemoryGuard.force(-1, tree)
	MemoryGuard.video_mb = 1.0
	MemoryGuard.heap_mb = 1.0
	MemoryGuard.fps_override = 18.0
	for i in 20:
		MemoryGuard.tick(tree, MemoryGuard.TICK_SECONDS)
	check(MemoryGuard.pressure >= 1, "an iPhone held under %d fps steps the guard up (%d)" % [int(MemoryGuard.LOW_FPS), MemoryGuard.pressure])
	MemoryGuard.fps_override = -1.0
	MemoryGuard.ios_override = 0
	# The flat-screen watchdog: two flat readings in a row take the next fallback step.
	MemoryGuard.force(-1, tree)
	GameSettings.quality = 2
	RenderWatchdog.spread_override = 0.0
	for i in 2:
		RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.step == 1 and RenderWatchdog.flat_count == 2, "two flat frames take the first fallback (camera) (%d)" % RenderWatchdog.step)
	for i in 2:
		RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.step == 2 and GameSettings.quality == 1 and MemoryGuard.pressure == 2, "then medium quality at strict pressure (%d, q%d, p%d)" % [RenderWatchdog.step, GameSettings.quality, MemoryGuard.pressure])
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0) and is_equal_approx(tree.root.scaling_3d_scale, 1.0), "and the world drawn at the canvas size again (%.2f)" % MemoryGuard.scale_3d)
	RenderWatchdog.spread_override = 0.5
	RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.step == 2, "a varied picture takes no further step")
	RenderWatchdog.spread_override = 0.0
	RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, false)
	RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, false)
	check(RenderWatchdog.step == 2, "menus and travel fades are never read as a flat screen")
	# A world drawn with almost no triangles counts as a flat screen (no pixel read needed).
	RenderWatchdog.spread_override = -1.0
	RenderWatchdog.triangles_override = 7595
	var big := Node3D.new()
	add_child(big)
	for i in RenderWatchdog.STARVED_NODES:
		big.add_child(Node.new())
	var stand_in := Node3D.new()
	stand_in.add_to_group("hero")
	add_child(stand_in)
	check(RenderWatchdog.world_starved(tree), "a built world drawn with 7.6k triangles is caught from the counters")
	RenderWatchdog.triangles_override = 510000
	check(not RenderWatchdog.world_starved(tree), "a village drawn in full is not")
	RenderWatchdog.triangles_override = -1
	big.queue_free()
	stand_in.queue_free()
	await tree.process_frame
	# The last step: the safe picture (no other players, stalls or lantern glow) and the
	# zone built again; it stays in the settings until the player switches it off.
	var safe_before := GameSettings.safe_picture
	GameSettings.safe_picture = false
	RenderWatchdog.rebuild_override = true
	RenderWatchdog.rebuilds = 0
	RenderWatchdog.spread_override = 0.0
	for i in 8:
		RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.step == RenderWatchdog.STEPS and GameSettings.safe_picture and RenderWatchdog.rebuilds == 1, "flat screens through every step end in the safe picture and one rebuilt zone (step %d, safe %s, rebuilds %d)" % [RenderWatchdog.step, GameSettings.safe_picture, RenderWatchdog.rebuilds])
	check(WorldPresence.limit_here(true) == 0 and WorldPresence.limit_here(false) == 0, "the safe picture shows no other players")
	for i in 4:
		RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.rebuilds == 1, "and rebuilds the zone only once")
	GameSettings.safe_picture = safe_before
	# Settings written before the grey-village fix (no "rev") drop their hidden world
	# players and the watchdog's safe picture; a current file keeps the player's choice.
	var show_before := GameSettings.show_world_players
	var old_file := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"quality": 2, "safe_picture": true, "show_world_players": false}))
	old_file.close()
	GameSettings._loaded = false
	GameSettings.load_settings()
	check(GameSettings.show_world_players and not GameSettings.safe_picture, "an old settings file shows the world players again and leaves the safe picture (show %s, safe %s)" % [GameSettings.show_world_players, GameSettings.safe_picture])
	GameSettings.show_world_players = false
	GameSettings.save_settings()
	GameSettings.show_world_players = true
	GameSettings._loaded = false
	GameSettings.load_settings()
	check(not GameSettings.show_world_players, "a current settings file keeps the world players switched off")
	GameSettings.show_world_players = show_before
	GameSettings.safe_picture = safe_before
	GameSettings.quality = 2
	GameSettings.save_settings()
	RenderWatchdog.rebuild_override = false
	RenderWatchdog.spread_override = -1.0
	RenderWatchdog.step = 0
	RenderWatchdog.flat_count = 0
	# A healthy frame (counters fine) is read back once every PIXEL_EVERY seconds, not
	# every check: ten minutes of checks read the frame about five times.
	RenderWatchdog.triangles_override = 510000
	RenderWatchdog.pixel_reads = 0
	RenderWatchdog._pixel_wait = 0.0
	for i in int(600.0 / RenderWatchdog.CHECK_SECONDS):
		RenderWatchdog.tick(tree, RenderWatchdog.CHECK_SECONDS, true)
	check(RenderWatchdog.pixel_reads >= 4 and RenderWatchdog.pixel_reads <= 6, "ten minutes read the frame back only %d times" % RenderWatchdog.pixel_reads)
	RenderWatchdog.triangles_override = -1
	RenderWatchdog.step = 0
	RenderWatchdog.flat_count = 0
	MemoryGuard.force(-1, tree)
	GameSettings.quality = 2
	MemoryGuard.video_mb = 1.0
	MemoryGuard.heap_mb = 1.0
	MemoryGuard.force(-1, tree)
	MemoryGuard.ios_override = -1
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
	check(report.has("pressure") and report.has("videoMB") and report.has("heapMB") and report.has("scale3d"), "report carries the readings")
	# The 3D resolution scale: every zone starts at full size; high quality stays sharp
	# (a slow stretch does not lower it); below high a phone follows the frame rate (down
	# a step after a slow stretch, up again after a fast one); the HUD is untouched and a
	# desktop always draws at 1.0.
	var phone := MemoryGuard.phone()
	MemoryGuard.force(-1, tree)
	MemoryGuard.reset_scale_3d(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0), "a zone starts at full size (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.fps_override = 20.0
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS * 4:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0), "high quality keeps the sharp picture when the frame rate is low (%.2f)" % MemoryGuard.scale_3d)
	# High comes in two modes on a phone: "สูง (คมชัด)" (high_smooth false) never lowers the
	# scale; "สูง (ลื่น)" follows the frame rate like medium does. Pinned as a phone so the
	# check is real on a desktop too.
	MemoryGuard.phone_override = 1
	GameSettings.high_smooth = false
	MemoryGuard.reset_scale_3d(tree)
	MemoryGuard.fps_override = 20.0
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS * 4:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0), "high (sharp) does not follow the frame rate on a phone (%.2f)" % MemoryGuard.scale_3d)
	GameSettings.high_smooth = true
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0 - MemoryGuard.SCALE_3D_STEP), "high (smooth) follows the frame rate: a slow stretch lowers the scale a step (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.fps_override = 60.0
	for i in MemoryGuard.SCALE_3D_FAST_TICKS * 2:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0), "and a fast stretch brings it back (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.set_scale_3d(0.8, tree)
	GameSettings.high_smooth = false
	MemoryGuard.fps_override = 20.0
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS * 2:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 0.8), "back on high (sharp) the scale holds where it is until the next zone (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.reset_scale_3d(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0), "a new zone on high (sharp) draws at full size again")
	# The mode is kept in the settings file.
	GameSettings.high_smooth = true
	GameSettings.save_settings()
	GameSettings.high_smooth = false
	GameSettings._loaded = false
	GameSettings.load_settings()
	check(GameSettings.high_smooth, "the settings file keeps high (smooth)")
	GameSettings.high_smooth = false
	GameSettings.save_settings()
	MemoryGuard.phone_override = -1
	MemoryGuard.fps_override = 20.0
	GameSettings.quality = 1
	check(is_equal_approx(tree.root.scaling_3d_scale, MemoryGuard.scale_3d), "the root viewport draws 3D at that scale")
	MemoryGuard.set_scale_3d(0.9, tree)
	MemoryGuard.fps_override = 30.0
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, (0.9 - MemoryGuard.SCALE_3D_STEP) if phone else 0.9), "a slow stretch lowers the scale a step on a phone only (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.fps_override = 30.0
	for i in 40:
		MemoryGuard._follow_frame_rate(tree)
	check(MemoryGuard.scale_3d >= MemoryGuard.SCALE_3D_MIN - 0.001, "the scale never drops under the floor (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.fps_override = 60.0
	for i in MemoryGuard.SCALE_3D_FAST_TICKS * 12:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, 1.0) or not phone, "a fast stretch brings it back up to full size (%.2f)" % MemoryGuard.scale_3d)
	# A warm iPhone (slow for HOT_SECONDS): the scale follows the frame rate at high
	# (sharp) too, capped at HOT_SCALE, and decorative effects shrink.
	MemoryGuard.phone_override = 1
	MemoryGuard.ios_override = 1
	GameSettings.quality = 2
	GameSettings.high_smooth = false
	MemoryGuard.reset_scale_3d(tree)
	var effects_cool := MemoryGuard.effect_scale()
	MemoryGuard.busy_override = 0.0
	MemoryGuard.fps_override = 50.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS * 2.0)
	check(not MemoryGuard.hot, "a fast iPhone is not marked warm")
	MemoryGuard.fps_override = 30.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS * 0.5)
	MemoryGuard.fps_override = 55.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS * 0.5)
	MemoryGuard.fps_override = 30.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS * 0.6)
	check(not MemoryGuard.hot, "a quick stretch takes slow seconds back off")
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS)
	check(MemoryGuard.hot, "a long slow stretch marks the iPhone warm")
	check(MemoryGuard.scale_3d <= MemoryGuard.HOT_SCALE + 0.001, "warm: the scale drops to the cap at high (sharp) (%.2f)" % MemoryGuard.scale_3d)
	check(MemoryGuard.effect_scale() < effects_cool, "warm: decorative effects shrink")
	for i in MemoryGuard.SCALE_3D_SLOW_TICKS * 10:
		MemoryGuard._follow_frame_rate(tree)
	check(is_equal_approx(MemoryGuard.scale_3d, MemoryGuard.HOT_FLOOR), "warm: a slow frame rate lowers high (sharp) down to the warm floor (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.fps_override = 60.0
	for i in MemoryGuard.SCALE_3D_FAST_TICKS * 12:
		MemoryGuard._follow_frame_rate(tree)
	check(MemoryGuard.scale_3d <= MemoryGuard.HOT_SCALE + 0.001, "warm: a fast stretch never goes over the cap (%.2f)" % MemoryGuard.scale_3d)
	MemoryGuard.reset_scale_3d(tree)
	check(MemoryGuard.scale_3d <= MemoryGuard.HOT_SCALE + 0.001, "warm: a new zone starts at the cap")
	MemoryGuard.hot = false
	MemoryGuard.hot_seconds = 0.0
	# Held at the 30 fps cap with the scripts filling most of each frame: warm too.
	var cap_before := Engine.max_fps
	Engine.max_fps = 30
	MemoryGuard.fps_override = 30.0
	MemoryGuard.busy_override = 12.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS * 2.0)
	check(not MemoryGuard.hot, "at the cap with light script work the iPhone is not warm")
	MemoryGuard.busy_override = 28.0
	MemoryGuard._watch_heat(tree, MemoryGuard.HOT_SECONDS)
	check(MemoryGuard.hot, "at the cap with 28 ms of script work a frame the iPhone is warm")
	Engine.max_fps = cap_before
	MemoryGuard.busy_override = -1.0
	MemoryGuard.hot = false
	MemoryGuard.hot_seconds = 0.0
	MemoryGuard.ios_override = -1
	MemoryGuard.phone_override = -1
	MemoryGuard.fps_override = -1.0
	GameSettings.quality = 2
	MemoryGuard.reset_scale_3d(tree)
	zone.queue_free()
	await get_tree().process_frame
	print("memory_guard_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
