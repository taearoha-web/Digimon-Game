extends Node3D
## The Dark Lord's raven hunting, in each of its modes (single, group, auto), on a
## deterministic field: real Hero, real DarkRaven, a pack of dummy monsters. Saves
## stills while it circles, as it stoops and just after each strike (the peck art),
## and prints the strikes and the monsters each mode reached.
##   godot --rendering-driver opengl3 --path . res://tests/tools/raven_showcase.tscn -- OUT_DIR
class Dummy extends Mob:
	var hits := 0
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits += 1
		return super.take_hit(amount, critical, color, attacker)
	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass

var camera: Camera3D
var title: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	get_window().size = Vector2i(960, 540)
	get_window().content_scale_size = Vector2i(960, 540)
	seed(77)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = []
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_shadow_color", Color("283540"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(title)
	Game.new_profile(&"darklord", "Raven QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.equip["wings"] = ItemData.wings(Game.rng, "darklord", 3)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.position = Vector3(-1.5, 0, 0)
	var mobs: Array[Dummy] = []
	for spot in [Vector3(2.4, 0, 0.3), Vector3(3.4, 0, -0.9), Vector3(3.2, 0, 1.4), Vector3(4.3, 0, 0.4), Vector3(1.8, 0, -1.6)]:
		var mob := Dummy.new()
		mob.setup(&"forest_orc", 100, spot, hero)
		field.add_child(mob)
		mob.position = spot
		mob.hp = 10000000
		mob.max_hp = 10000000
		mob.stats.def = 0.0
		mob.set_physics_process(false)
		mobs.append(mob)
	hero.target = mobs[0]
	hero.set_facing(atan2(mobs[0].position.x - hero.position.x, mobs[0].position.z - hero.position.z))
	hero._sync_raven()
	VfxKit.warm_shaders(field, Vector3.ZERO)
	camera.position = Vector3(1.0, 4.2, 7.6)
	camera.look_at(Vector3(1.4, 1.0, 0))
	# Perched first, close up on the arm.
	title.text = "อีกาเกาะแขน"
	hero.set_raven_attack(false)
	await get_tree().create_timer(1.0).timeout
	var arm := hero.raven.global_position
	camera.position = arm + Vector3(0.9, 0.35, 1.6)
	camera.look_at(arm + Vector3(0, 0.05, 0))
	await _capture(out_dir, "raven_perch")
	camera.position = Vector3(1.0, 4.2, 7.6)
	camera.look_at(Vector3(1.4, 1.0, 0))
	for mode in [DarkRaven.Mode.SINGLE, DarkRaven.Mode.GROUP, DarkRaven.Mode.AUTO]:
		for mob in mobs:
			mob.hits = 0
		hero.set_raven_mode(mode)
		hero.set_raven_attack(true)
		title.text = "อีกา • โจมตี%s" % DarkRaven.MODE_NAMES[mode]
		var name: String = ["single", "group", "auto"][mode]
		var before := hero.raven_strikes
		var shots := 0
		var circled := false
		var clock := 0.0
		while clock < 7.0 and shots < 2:
			await get_tree().process_frame
			clock += get_process_delta_time()
			if not circled and clock > 1.2 and hero.raven.state == DarkRaven.State.FLY:
				circled = true
				await _capture(out_dir, "raven_%s_circle" % name)
			if hero.raven_strikes > before + shots:
				shots += 1
				await get_tree().create_timer(0.06).timeout
				await _capture(out_dir, "raven_%s_strike%d" % [name, shots])
		var reached := 0
		for mob in mobs:
			if mob.hits > 0:
				reached += 1
		print("RAVEN %s: strikes=%d monsters_hit=%d" % [name, hero.raven_strikes - before, reached])
		hero.set_raven_attack(false)
		await get_tree().create_timer(1.6).timeout
	get_tree().quit()


func _capture(out_dir: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
