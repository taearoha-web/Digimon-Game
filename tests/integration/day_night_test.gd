extends Node
## Morning, day, evening and night (DayNight): the phase function is continuous over the
## whole day, midday is exactly each zone's designed look, night is darker but stays above
## a readability floor, fixed-mood zones are left alone, the hour override works and a
## storm flash still settles on the (night) ambient base.
## godot --headless --path . res://tests/integration/day_night_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _designed() -> DayNight.Look:
	var d := DayNight.Look.new()
	d.top = Color("5f9bd9")
	d.horizon = Color("eef0d8")
	d.fog = Color("d8e4d0")
	d.ambient = Color("c8d8e6")
	d.ambient_energy = 0.33
	d.sun = Color(1.0, 0.96, 0.88)
	d.sun_energy = 0.6
	d.shadow = 0.68
	d.sun_angle = 6.0
	return d


static func _cdiff(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))


static func _ldiff(a: DayNight.Look, b: DayNight.Look) -> float:
	var worst := 0.0
	for pair in [[a.top, b.top], [a.horizon, b.horizon], [a.fog, b.fog], [a.ambient, b.ambient], [a.sun, b.sun], [a.cloud, b.cloud]]:
		worst = maxf(worst, _cdiff(pair[0], pair[1]))
	for pair in [[a.ambient_energy, b.ambient_energy], [a.sun_energy, b.sun_energy], [a.night, b.night],
			[a.lantern - 1.0, b.lantern - 1.0], [a.shadow, b.shadow], [a.sun_angle / 6.0, b.sun_angle / 6.0]]:
		worst = maxf(worst, absf(float(pair[0]) - float(pair[1])))
	return worst


func _pure() -> void:
	var d := _designed()
	for warm in [0.0, 1.0]:
		var prev := DayNight.sample(0.0, d, DayNight.Look.new(), null, null, warm)
		var worst := 0.0
		var worst_at := 0.0
		var angles := DayNight.light_angles(0.0)
		var worst_angle := 0.0
		var h := 0.0
		while h < 24.0:
			h += 0.005
			var cur := DayNight.sample(h, d, DayNight.Look.new(), null, null, warm)
			var step := _ldiff(prev, cur)
			if step > worst:
				worst = step
				worst_at = h
			var a := DayNight.light_angles(h)
			worst_angle = maxf(worst_angle, maxf(absf(a.x - angles.x), absf(a.y - angles.y)))
			angles = a
			prev = cur
		check(worst < 0.02, "warmth %s: no jump between two moments 18 world seconds apart (worst %.4f at %.2f h)" % [warm, worst, worst_at])
		check(worst_angle < 0.6, "warmth %s: the sun and moon turn smoothly (worst %.3f deg)" % [warm, worst_angle])
		check(_ldiff(DayNight.sample(0.0, d, DayNight.Look.new(), null, null, warm), DayNight.sample(23.9999, d, DayNight.Look.new(), null, null, warm)) < 0.001, "warmth %s: midnight joins up" % warm)
		# Midday: exactly the designed look, all day long.
		for at in [DayNight.DAY_FROM, 11.0, 12.0, 14.0, DayNight.DAY_TO]:
			var noon := DayNight.sample(at, d, DayNight.Look.new(), null, null, warm)
			check(_ldiff(noon, d) < 0.00001 and noon.night == 0.0 and noon.lantern == 1.0, "warmth %s: %.1f h is the designed look (off by %.6f)" % [warm, at, _ldiff(noon, d)])
		# Night: darker and bluer, but readable; the stars out.
		var night := DayNight.sample(22.0, d, DayNight.Look.new(), null, null, warm)
		var day_light := d.brightness(42.0)
		var night_light := night.brightness(-DayNight.light_angles(22.0).x)
		check(night_light < day_light * 0.8, "warmth %s: night is darker (%.3f vs %.3f by day)" % [warm, night_light, day_light])
		check(night_light > day_light * 0.4, "warmth %s: night stays readable (%.3f vs %.3f by day)" % [warm, night_light, day_light])
		check(night.top.get_luminance() < d.top.get_luminance() * 0.4 and night.top.b > night.top.r, "warmth %s: the night sky is deep blue (%s)" % [warm, night.top])
		check(night.night == 1.0 and night.lantern > 2.0, "warmth %s: stars out and lanterns bright at night" % warm)
		var dusk := DayNight.sample(18.0, d, DayNight.Look.new(), null, null, warm)
		check(dusk.horizon.r > dusk.horizon.b + 0.2 and dusk.sun.r > dusk.sun.b + 0.3, "warmth %s: an orange sunset (%s / %s)" % [warm, dusk.horizon, dusk.sun])
		var dawn := DayNight.sample(6.5, d, DayNight.Look.new(), null, null, warm)
		check(dawn.sun.r > dawn.sun.b + 0.2 and dawn.brightness(-DayNight.light_angles(6.5).x) > night_light, "warmth %s: a golden, brighter morning" % warm)
	var town_night := DayNight.sample(22.0, d, DayNight.Look.new(), null, null, 1.0)
	var field_night := DayNight.sample(22.0, d, DayNight.Look.new(), null, null, 0.0)
	check(town_night.ambient.r - town_night.ambient.b > field_night.ambient.r - field_night.ambient.b and town_night.lantern > field_night.lantern,
			"the village night is warmer, its lanterns brighter")
	check(DayNight.light_angles(12.0).is_equal_approx(Vector2(-42.0, -32.0)), "noon keeps the designed sun (%s)" % DayNight.light_angles(12.0))
	check(DayNight.disc_elevation(12.0) == 42.0 and DayNight.disc_elevation(2.0) < 0.0 and DayNight.disc_elevation(18.0) > 0.0, "the sun disc: noon as designed, set at night, low at six")
	# Phases and labels.
	var table := {3.0: &"night", 5.5: &"morning", 8.9: &"morning", 9.0: &"day", 15.9: &"day", 16.0: &"evening", 18.9: &"evening", 19.0: &"night", 23.5: &"night"}
	for at in table:
		check(DayNight.phase(at) == table[at], "%.1f h is %s (got %s)" % [at, table[at], DayNight.phase(at)])
	check(DayNight.clock_text(7.5) == "07:30" and DayNight.clock_text(22.1666) == "22:09", "clock text")
	check(DayNight.phase_label(22.0) == "กลางคืน" and DayNight.phase_label(6.0) == "เช้า", "Thai labels")
	# The world's clock: Thai time, SPEED x faster after the opening (a world day every 8 real hours).
	var t0 := float(WorldPlayers.START_UNIX) + 3.0 * 86400.0
	check(absf(DayNight.world_hour(t0 + 8.0 * 3600.0) - DayNight.world_hour(t0)) < 0.001, "a world day passes every 8 real hours")
	check(absf(fposmod(DayNight.world_hour(t0 + 600.0) - DayNight.world_hour(t0), 24.0) - 0.5) < 0.001, "10 real minutes are half a world hour")
	var before := float(WorldPlayers.START_UNIX) - 86400.0
	check(absf(DayNight.world_hour(before) - float(WorldEvents.time_of_day(before)) / 3600.0) < 0.001, "before the opening the world hour is Thai time")
	# The override.
	check(DayNight.fixed_hour == 12.0, "headless runs start at midday (%s)" % DayNight.fixed_hour)
	OS.set_environment("TOON_HOUR", "21.5")
	check(DayNight._initial_hour() == 21.5, "TOON_HOUR sets the hour")
	OS.set_environment("TOON_HOUR", "clock")
	check(is_nan(DayNight._initial_hour()), "TOON_HOUR=clock follows the world clock")
	OS.set_environment("TOON_HOUR", "")
	DayNight.fixed_hour = 3.25
	check(DayNight.hour() == 3.25, "fixed_hour overrides the clock")
	DayNight.fixed_hour = NAN
	check(absf(DayNight.hour() - DayNight.world_hour(WorldPresence.clock())) < 0.01, "NAN follows the clock")
	DayNight.fixed_hour = 12.0


func _build(zone_id: StringName) -> Zone:
	Game.current_zone = zone_id
	var zone := Zone.new()
	zone.zone_id = zone_id
	add_child(zone)
	check(zone.is_built, "%s builds" % zone_id)
	return zone


func _free(zone: Zone) -> void:
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _sun(zone: Zone) -> DirectionalLight3D:
	for child in zone.get_children():
		if child is DirectionalLight3D:
			return child
	return null


func _field() -> void:
	DayNight.fixed_hour = 12.0
	var zone := _build(&"meadow")
	var dn := zone.day_night
	check(dn != null, "the meadow follows the clock")
	if dn == null:
		await _free(zone)
		return
	var env := zone._env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	var data := ZoneData.get_zone(&"meadow")
	var sun := _sun(zone)
	# Midday: what Scenery.environment designed.
	check(_cdiff(sky.sky_top_color, data.sky_palette[0]) < 0.0001 and _cdiff(sky.sky_horizon_color, data.sky_palette[2]) < 0.0001, "noon sky is the designed palette")
	check(sun.rotation_degrees.is_equal_approx(Vector3(-42, -32, 0)) and is_equal_approx(sun.light_energy, 0.6), "noon sun as designed (%s, %.2f)" % [sun.rotation_degrees, sun.light_energy])
	check(is_equal_approx(env.ambient_light_energy, 0.33) and _cdiff(env.ambient_light_color, dn.base.ambient) < 0.0001 and _cdiff(env.fog_light_color, dn.base.fog) < 0.0001, "noon air as designed")
	for i in 6:
		await get_tree().process_frame
	check(not dn._night_sky.visible, "no stars at noon once the night layers have warmed")
	var day_brightness := dn.now.brightness(42.0)
	# Night.
	DayNight.fixed_hour = 22.0
	dn.apply(true)
	check(sky.sky_top_color.get_luminance() < (data.sky_palette[0] as Color).get_luminance() * 0.4, "the night sky darkens")
	check(env.ambient_light_energy > 0.25 and env.ambient_light_energy < 0.5, "night ambient stays up for readability (%.3f)" % env.ambient_light_energy)
	check(sun.light_energy < 0.45 and sun.light_color.b > sun.light_color.r, "the sun turns into cool moonlight (%.2f %s)" % [sun.light_energy, sun.light_color])
	var night_brightness := dn.now.brightness(-sun.rotation_degrees.x)
	check(night_brightness > day_brightness * 0.4 and night_brightness < day_brightness * 0.8, "night light %.3f vs day %.3f: darker but readable" % [night_brightness, day_brightness])
	check(dn._night_sky.visible and dn._night_mat.albedo_color.a > 0.99, "stars and moon out at night")
	check(dn._dots == null or not dn._dots.visible, "the sun disc has set")
	check(is_equal_approx(zone._ambient_base, env.ambient_light_energy), "the storm base follows the night")
	# A storm flash at night brightens, DayNight keeps off it, and it settles on the night base.
	var night_base := env.ambient_light_energy
	zone._storm_flash()
	check(zone.is_flashing(), "a flash is under way")
	env.ambient_light_energy = 9.0   # stands for the flash's peak, whatever the frame timing
	dn.apply()
	check(env.ambient_light_energy == 9.0, "the flash owns the ambient light while it lasts (%.3f)" % env.ambient_light_energy)
	await get_tree().create_timer(0.9).timeout
	check(is_equal_approx(env.ambient_light_energy, night_base), "after the flash the night ambient is back (%.3f vs %.3f)" % [env.ambient_light_energy, night_base])
	# Back to noon: all designed values again.
	DayNight.fixed_hour = 12.0
	dn.apply(true)
	check(_cdiff(sky.sky_top_color, data.sky_palette[0]) < 0.0001 and sun.rotation_degrees.is_equal_approx(Vector3(-42, -32, 0)) and is_equal_approx(env.ambient_light_energy, 0.33),
			"noon again restores the designed look")
	await _free(zone)


func _town() -> void:
	DayNight.fixed_hour = 12.0
	var zone := _build(&"town")
	var dn := zone.day_night
	check(dn != null and dn.warmth == 1.0, "the village follows the clock, warm")
	if dn == null:
		await _free(zone)
		return
	var halos: MultiMeshInstance3D = null
	for node in get_tree().get_nodes_in_group("night_glow"):
		if zone.is_ancestor_of(node) and node.name == "LanternHalos":
			halos = node
	check(halos != null and not dn._glows.is_empty(), "the lantern halos glow at night")
	check(dn._pools != null and dn._pools.multimesh.instance_count > 10, "lantern pools under the low lanterns")
	if halos == null or dn._pools == null:
		await _free(zone)
		return
	var designed := halos.multimesh.buffer
	check((halos.material_override as StandardMaterial3D).albedo_color == Color.WHITE, "noon halos as designed")
	DayNight.fixed_hour = 22.0
	dn.apply(true)
	var glow := (halos.material_override as StandardMaterial3D).albedo_color
	check(glow.r > 1.5 and glow.r > glow.b, "night halos brighter and amber (%s)" % glow)
	check(dn._pools.visible and dn._pool_mat.albedo_color.a > 0.9, "amber pools on the street at night")
	if not designed.is_empty():   # the headless renderer keeps no instance data
		check(halos.multimesh.get_instance_transform(0).basis.get_scale().x > designed[0] * 1.2, "night halos grow")
	DayNight.fixed_hour = 12.0
	dn.apply(true)
	check(halos.multimesh.buffer == designed and (halos.material_override as StandardMaterial3D).albedo_color == Color.WHITE, "noon halos back to the designed ones")
	check(dn._pool_mat.albedo_color.a < 0.01, "no pools by day")
	await _free(zone)


func _fixed() -> void:
	DayNight.fixed_hour = 22.0
	for zone_id in [&"graveyard", &"dark_forest", &"storm", &"tower", &"arena"]:
		check(not DayNight.follows(zone_id), "%s keeps its own mood" % zone_id)
	for zone_id in [&"graveyard", &"dark_forest"]:
		var zone := _build(zone_id)
		var data := ZoneData.get_zone(zone_id)
		check(zone.day_night == null and zone.get_node_or_null("DayNight") == null, "%s has no day/night" % zone_id)
		var sky := zone._env.environment.sky.sky_material as ProceduralSkyMaterial
		check(_cdiff(sky.sky_top_color, data.sky_palette[0]) < 0.0001, "%s keeps its sky at 22:00" % zone_id)
		check(_sun(zone).rotation_degrees.is_equal_approx(Vector3(-42, -32, 0)), "%s keeps its sun" % zone_id)
		await _free(zone)
	DayNight.fixed_hour = 12.0


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "DayNight")
	Game.profile.level = 60
	_pure()
	await _field()
	await _town()
	await _fixed()
	print("")
	if failures.is_empty():
		print("DAY NIGHT TEST: PASS (%d checks)" % checks)
	else:
		print("DAY NIGHT TEST: FAIL (%d of %d)" % [failures.size(), checks])
		for f in failures:
			print("  - ", f)
	get_tree().quit(failures.size())
