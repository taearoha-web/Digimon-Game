extends Node
## Screenshots of morning, day, evening and night (DayNight) through the real game scenes:
## for each zone, the same view at each hour. Zones and hours are comma lists.
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/day_night_shots.tscn -- <out_dir> [hours] [zones] [quality]
## e.g. -- /tmp/dn 6.5,12,18,22 town,meadow 2
var out_dir := "user://day_night"
var main: Node


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.jpg" % [out_dir, name]
	img.save_jpg(path, 0.9)
	print("SHOT ", path)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var hours: Array[float] = []
	for part in (args[1] if args.size() > 1 else "6.5,12,18,22").split(","):
		hours.append(float(part))
	var zones := (args[2] if args.size() > 2 else "town,meadow").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	GameSettings.load_settings()
	if args.size() > 3:
		GameSettings.quality = int(args[3])
	DayNight.fixed_hour = hours[0]
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 2.4 * 86400.0 - WorldPlayers.now()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.5)
	Game.new_profile(&"bard", "ทดสอบ")
	Game.profile["level"] = 60
	Game.profile["adv"] = JobData.adv_for_level(60)
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = ItemData.generate(60, &"bard", Game.rng, 3, slot)
	Game.profile.party = []
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	for zone_name in zones:
		await main.go(StringName(zone_name), true)
		await _wait(3.0)
		var zone: Zone = main.zone
		if zone.day_night:
			var dn := zone.day_night
			print("DAYNIGHT %s glows %d pools %d stars %d" % [zone_name, dn._glows.size(), dn._pools.multimesh.instance_count if dn._pools else 0, dn._night_sky.multimesh.instance_count])
		var start := zone.hero.global_position
		# [name, hero spot, camera pitch, camera yaw (degrees; NAN keeps the game's)]: the plaza,
		# the market street toward the east, and a low look at the sky's sun and moon.
		var views: Array = [["plaza", Vector3(0, 0.2, 15.0), NAN, NAN], ["street", Vector3(8, 0.2, 0.5), -16.0, -90.0],
			["sky", Vector3(0, 0.2, 15.0), -6.0, 160.0]] if zone.is_town else [["field", start, NAN, NAN], ["sky", start, -6.0, 160.0]]
		var pitch := zone.camera_rig.pitch_degrees
		var yaw := zone.camera_rig.yaw
		for view in views:
			zone.hero.global_position = view[1]
			zone.camera_rig.pitch_degrees = pitch if is_nan(float(view[2])) else float(view[2])
			zone.camera_rig.set_yaw_behind(yaw if is_nan(float(view[3])) else deg_to_rad(float(view[3])))
			zone.camera_rig.snap_to_target()
			await _wait(1.0)
			for h in hours:
				DayNight.fixed_hour = h
				if zone.day_night:
					zone.day_night.apply(true)
				await _wait(0.4)
				await _shot("%s_%s_%s" % [zone_name, view[0], DayNight.clock_text(h).replace(":", "")])
	get_tree().quit()
