extends Node
## Screenshots of the Christmas and New Year festival (Christmas, ChristmasTown): the village
## on Christmas night, the tree, the Santa costume by day in the snow, the countdown and the
## midnight fireworks, into the directory in the XMAS_SHOTS env var (user:// when unset).
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://tools/xmas_shots.tscn

var out := ""
var cam: Camera3D


func thai(year: int, month: int, day: int, hour: int, minute := 0, second := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": second}) - WorldPlayers.TZ)


func _ready() -> void:
	out = OS.get_environment("XMAS_SHOTS")
	if out == "":
		out = "user://"
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.set_process(false)
	WorldPlayers.persist = false
	Announcer.relay = false
	Game.new_profile(&"warrior", "ซานต้า", FaceKit.default_look())
	Game.profile.level = 60
	RewardShop.data()["cos"] = Christmas.COSTUME
	var shots := [
		["santa", thai(2026, 12, 10, 12), Vector3(1.0, 1.5, 15.6), Vector3(0, 1.15, 19)],
		["fireworks", thai(2027, 1, 1, 0, 0, 20), Vector3(0, 2.2, 27), Vector3(0, 20, -6)],
	]
	for s in shots:
		await _shot(String(s[0]), float(s[1]), s[2], s[3])
	get_tree().quit(0)


func _shot(name: String, t: float, eye: Vector3, look: Vector3) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()
	Game.current_zone = &"town"
	Game.profile["spawn_override"] = ""
	var zone := Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 5
	add_child(zone)
	for i in 2000:
		if zone.is_built:
			break
		await get_tree().process_frame
	if zone.hero != null:
		zone.hero.global_position = Vector3(0, 0, 19)
		zone.hero.rotation.y = 0.0
	cam = Camera3D.new()
	cam.fov = 60.0
	zone.add_child(cam)
	cam.global_position = eye
	cam.look_at(look)
	cam.make_current()
	for i in 90:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("xmas_%s.png" % name))
	print("shot ", name)
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
