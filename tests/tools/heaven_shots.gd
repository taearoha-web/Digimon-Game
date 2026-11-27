extends Node
## Screenshots of ดินแดนเทวาลัย (HeavenRealmData): an overview, the arrival gate and sign,
## a camp fight, the boss in its court and the abyss's portal to the realm.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tests/tools/heaven_shots.tscn [-- OUT_DIR]
var main: Node
var out := "user://heaven_shots"


func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/" + label + ".png")
	print("shot ", out + "/" + label + ".png")


func _camera(from: Vector3, at: Vector3, fov := 62.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 900.0
	main.zone.add_child(cam)
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.make_current()
	return cam


func _rig(yaw: float, pitch: float, distance: float) -> void:
	var rig = main.zone.camera_rig
	rig.yaw = yaw
	rig.pitch_degrees = pitch
	rig._target_distance = distance
	rig._apply_rotation()
	rig.snap_to_target()
	rig.camera.make_current()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_defaults()
	GameSettings.quality = 2
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(&"warrior", "ผู้มาเยือนเทวาลัย", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level": 300, "exp": 0, "points": 0, "spent": 300, "alloc": {"atk": 90, "hp": 90, "def": 90, "haste": 30}}
	Game.profile.attrs = {"str": 400, "int": 0, "dex": 150, "vit": 150}
	for slot in DivineGearData.SLOTS:
		Game.profile.equip[slot] = DivineGearData.item(&"warrior", slot, Game.rng)
	Game.profile.equip.wings = StarWingData.item("warrior", Game.rng, 4)
	Game.fill_loadout()
	await main.go(HeavenRealmData.ID, true, true)
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	Game.profile.hp = int(hero.stats.max_hp)
	await get_tree().create_timer(1.5).timeout
	# Overviews.
	var cam := _camera(Vector3(0, 52, 92), Vector3(0, 0, -18), 60.0)
	await get_tree().create_timer(0.4).timeout
	await shot("overview_south")
	cam.global_position = Vector3(-88, 34, 26)
	cam.look_at(Vector3(0, 0, -12), Vector3.UP)
	await shot("overview_west")
	cam.global_position = Vector3(14, 9, -20)
	cam.look_at(Vector3(0, 9, -76), Vector3.UP)
	await shot("hall_of_gods")
	cam.queue_free()
	# The arrival: the gate, the stele and its sign.
	hero.global_position = HeavenRealmArt.layout().spawn + Vector3(-2, 0.3, 2)
	_rig(PI * 0.15, -18.0, 13.0)
	await get_tree().create_timer(0.8).timeout
	await shot("arrival_sign")
	# A camp fight at the jade yaksha's terrace.
	var camp: Vector2 = HeavenRealmArt.layout().camp_positions[3]
	hero.global_position = Vector3(camp.x - 5.0, 0.3, camp.y + 3.0)
	_rig(-PI * 0.4, -24.0, 12.0)
	var near: Array = get_tree().get_nodes_in_group("mobs").filter(func(m): return (m as Node3D).global_position.distance_to(hero.global_position) < 14.0)
	for m in near:
		(m as Mob)._victim = hero
		(m as Mob).hostile = true
	if not near.is_empty():
		hero.set_target(near[0])
	await get_tree().create_timer(2.2).timeout
	hero.use_skill(0)
	await get_tree().create_timer(0.6).timeout
	await shot("camp_fight")
	# The boss in its court.
	for m in near:
		if is_instance_valid(m):
			(m as Mob).hostile = false
	hero.global_position = Vector3(2, 0.3, -12)
	main.zone._boss_timer = 0.0
	main.zone._tick_boss(1.0)
	if main.zone._boss == null:
		main.zone._spawn_field_boss(false)
	await get_tree().create_timer(0.6).timeout
	var boss: Mob = main.zone._boss
	_rig(PI * 0.1, -16.0, 15.0)
	await get_tree().create_timer(0.5).timeout
	await shot("boss_court")
	if boss:
		hero.set_target(boss)
		boss._victim = hero
		boss.hostile = true
		await get_tree().create_timer(1.0).timeout
		boss._begin_slam()
		await get_tree().create_timer(0.9).timeout
		await shot("boss_move")
	# The abyss's portal to the realm.
	await main.go(DrownedAbyssData.ID, true, true)
	hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	hero.global_position = Zone.HEAVEN_PORTAL_SPOT + Vector3(5.0, 0.3, 5.0)
	_rig(PI * 0.75, -14.0, 11.0)
	await get_tree().create_timer(1.2).timeout
	await shot("abyss_portal")
	get_tree().quit(0)
