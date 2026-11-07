extends Node
## Frame cost of a big guild war: builds the castle siege with `per_side` fighters a side
## (the hero playing as one of ours, or watching: GuildWarSpectate), lets the fight run and
## prints the wall time of each frame (mean, p50, p95, p99, max) and the node count. Run
## with --fixed-fps 60 so every frame is one 1/60 s step and its wall time is its cost:
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tests/tools/guild_war_perf.tscn -- [watch|play] [per_side] [frames] [quality] [experiment|-] [warm-up frames] [guilds]
## `guilds` 4 fights the league round's war: four guilds of `per_side` (4 x 20 = 80 fighters).
## With a display (xvfb-run, no --headless) the frames are drawn too.
var _times: Array[float] = []


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	InputSetup.ensure_defaults()
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() > 0 else "watch"
	var per_side := int(args[1]) if args.size() > 1 else 20
	var frames := int(args[2]) if args.size() > 2 else 1800
	GameSettings.quality = int(args[3]) if args.size() > 3 else 1
	get_window().size = Vector2i(1280, 720)
	Game.new_profile(&"warrior", "Perf")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 11
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(&"warrior", 150, slot, gear_rng)
	Game.profile.hp = Game.stats_now().max_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var guilds := int(args[6]) if args.size() > 6 else 2
	var info := GuildWarSpectate.demo_war(rng, per_side) if guilds > 2 else GuildWarSpectate.demo_match(rng, per_side)
	Game.current_zone = &"guildwar"
	if mode == "watch":
		info["elapsed"] = 400.0
		info["league_match"] = ["Alpha", "Neverdie"]
		info["slot_start"] = 1700000000
		GuildWarSpectate._pending = info
	else:
		# The hero is one of ours: per_side - 1 members beside it.
		var ours: Array = info.sides[0].lineup if guilds > 2 else info.ally
		ours.resize(per_side - 1)
		GuildWarMatch.next_roster = info
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	print("PERF mode=%s guilds=%d fighters=%d (allies %d + hero %s, enemies %d) quality=%d" % [mode, m.team_count() if m.has_method("team_count") else 2, m.all_fighters().size(), m.allies.size(), "out" if m.spectating() else "in", m.all_fighters().size() - m.allies.size(), GameSettings.quality])
	if mode == "play":
		zone.hero.set_auto(true)
	# The countdown, then the armies meet: measure the fight, not the march.
	while m.state != "fight":
		await get_tree().process_frame
	for i in (int(args[5]) if args.size() > 5 else 600):
		await get_tree().process_frame
	# Experiments (5th arg): "still" poses every fighter only every 8th frame (what the
	# skeletons cost), "hidden" hides every fighter's model too, "noai" stops the fighters'
	# brains, "oldcull" culls as before the 20 vs 20 work (distance from the camera only),
	# "aioff" stops only the brains (models posed and culled as ever: the AI's own share).
	var experiment := String(args[4]) if args.size() > 4 and String(args[4]) != "-" else ""
	if experiment == "aioff":
		for f in m.all_fighters():
			f.set_physics_process(false)
	elif experiment == "oldcull":
		m._cull_timer = 1.0e9
	elif experiment != "":
		m._cull_timer = 1.0e9
		for f in m.all_fighters():
			if f.model() != null:
				f.model().set_anim_lod(8)
				f.model().set_far(true)
			if experiment == "hidden":
				f.visual.visible = false
			if experiment == "noai":
				f.set_physics_process(false)
	var thinks_before := GuildFighter.thinks_total
	GuildFighter.thinks_peak = 0
	var last := Time.get_ticks_usec()
	for i in frames:
		if experiment == "oldcull" and i % 15 == 0:
			_old_cull(m)
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		_times.append(float(now - last) / 1000.0)
		last = now
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in sorted:
		total += t
	var pick := func(q: float) -> float: return sorted[clampi(int(q * sorted.size()), 0, sorted.size() - 1)]
	var drawn := 0
	for f in m.all_fighters():
		drawn += 1 if f.visual.visible else 0
	print("PERF_RESULT mode=%s per_side=%d frames=%d mean=%.2fms p50=%.2fms p95=%.2fms p99=%.2fms max=%.2fms nodes=%d summons=%d drawn=%d/%d score=%s" % [mode, per_side, sorted.size(), total / sorted.size(), pick.call(0.5), pick.call(0.95), pick.call(0.99), sorted.back(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), get_tree().get_nodes_in_group("summons").size(), drawn, m.all_fighters().size(), m.score])
	print("PERF_BRAINS full decisions %.2f a frame (peak %d, cap %d)" % [float(GuildFighter.thinks_total - thinks_before) / frames, GuildFighter.thinks_peak, GuildFighter.think_cap(m.all_fighters().size())])
	get_tree().quit(0)


## GuildWarMatch._cull_far as it was: drawn within DRAW_RADIUS of the camera, every other
## frame past POSE_NEAR, nothing about the view.
func _old_cull(m: GuildWarMatch) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var q := clampi(GameSettings.quality, 0, 2)
	var limit: float = GuildWarMatch.DRAW_RADIUS[q]
	var still: float = Zone.ANIM_RADIUS[q]
	for f in m.all_fighters():
		var d2 := f.global_position.distance_squared_to(camera.global_position)
		var shown := d2 < limit * limit
		f.visual.visible = shown
		var far := d2 > GuildWarMatch.POSE_NEAR * GuildWarMatch.POSE_NEAR and not f.in_hero_party()
		if f.model() != null:
			f.model().set_anim_lod(2 if far else 1)
			f.model().set_far(far)
		if f.mount != null:
			f.mount.lod_step = 2 if far else 1
			f.mount.set_far(far)
			f.mount.set_process(shown and d2 < still * still)
