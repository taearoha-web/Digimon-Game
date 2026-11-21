extends Node
## Looks of the guild war's castle (SiegeArena) from the player's camera and from the air,
## with the frame's draw calls and triangles at each view:
##   xvfb-run -a godot --rendering-driver opengl3 --audio-driver Dummy --path . res://tests/tools/siege_look_shots.tscn -- <out_dir> [prefix] [quality] [per_side]
var out_dir := "user://shots"
var prefix := "shot"

## Where the hero stands and which way the camera looks (yaw 0 looks north, at the castle).
const PLAYER_VIEWS := [
	["camp", Vector3(-70.0, 0.3, 20.0), -1.2],
	["plaza", Vector3(0.0, 0.3, 24.0), 0.0],
	["bridge", Vector3(4.0, 0.3, -3.0), 0.0],
	["gate1", Vector3(12.0, 0.3, -12.0), 0.0],
	["yard1", Vector3(6.0, 0.3, -28.0), 0.0],
	["yard2", Vector3(-6.0, 0.3, -64.0), 0.0],
	["gate3", Vector3(0.0, 0.3, -84.0), 0.0],
	["stairs", Vector3(0.0, 0.3, -94.0), 0.0],
	["throne", Vector3(3.0, 0.3, -108.0), 0.0],
	["altar", Vector3(0.0, 0.3, -124.0), 0.0],
	["altar_back", Vector3(0.0, 0.3, -122.0), PI],
	["climb", Vector3(-4.0, 0.3, -97.0), 0.5],
]
## Free cameras: [name, from, look at].
const AIR_VIEWS := [
	["overview", Vector3(0.0, 92.0, 62.0), Vector3(0.0, 0.0, -30.0)],
	["front", Vector3(0.0, 11.0, 40.0), Vector3(0.0, 14.0, -60.0)],
	["aerial", Vector3(70.0, 50.0, 26.0), Vector3(0.0, 8.0, -70.0)],
	["throne_air", Vector3(26.0, 26.0, -70.0), Vector3(0.0, 4.0, -128.0)],
	["low_field", Vector3(-40.0, 2.2, 50.0), Vector3(0.0, 16.0, -80.0)],
]


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s_%s.png" % [out_dir, prefix, name]
	img.save_png(path)
	print("SHOT %s draws=%d tris=%d" % [path, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	InputSetup.ensure_defaults()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		prefix = args[1]
	GameSettings.quality = int(args[2]) if args.size() > 2 else 1
	var per_side := int(args[3]) if args.size() > 3 else 8
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1600, 736)
	Game.new_profile(&"warrior", "Look")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = Game.stats_now().max_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var info := GuildWarSpectate.demo_match(rng, per_side)
	Game.current_zone = &"guildwar"
	(info.ally as Array).resize(per_side - 1)
	GuildWarMatch.next_roster = info
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	for i in 30:
		await get_tree().process_frame
	# The war's fighters stand still and harmless: the pictures are of the place.
	for f in m.all_fighters():
		f.set_physics_process(false)
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m.set_physics_process(false)
	m.set_process(false)
	var rig: ThirdPersonCamera = zone.camera_rig
	var arena: Object = SiegeArena.new()
	# Each place at the fighting tilt, at the old highest tilt and (where the zone allows
	# it) tilted up at the castle.
	var tilts := [[-47.0, "p"], [-38.0, "t"]]
	if rig.max_pitch > -30.0:
		tilts.append([rig.max_pitch, "u"])
	for v in PLAYER_VIEWS:
		var at: Vector3 = v[1]
		if arena.has_method("floor_y"):
			at.y = float(arena.call("floor_y", at)) + 0.3
		zone.hero.global_position = at
		zone.hero.velocity = Vector3.ZERO
		for tilt in tilts:
			rig.pitch_degrees = float(tilt[0])
			rig.set_yaw_behind(float(v[2]))
			rig.snap_to_target()
			for i in 14:
				await get_tree().process_frame
			await _shot("%s_%s" % [tilt[1], v[0]])
		print("HERO %s y=%.2f floor=%s" % [v[0], zone.hero.global_position.y, zone.hero.is_on_floor()])
	var cam := Camera3D.new()
	zone.add_child(cam)
	cam.fov = 60.0
	cam.far = 600.0
	cam.current = true
	for v in AIR_VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await _shot("a_" + String(v[0]))
	get_tree().quit(0)
