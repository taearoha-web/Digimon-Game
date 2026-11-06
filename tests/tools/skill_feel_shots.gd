extends Node3D
## Stills of the skill feel (SkillFeel / UltCutIn) from real Hero._cast calls on a
## deterministic field, seen through the game's own follow camera: the ultimate
## cut-in of a god skill and of a 200-star skill, monsters thrown by a heavy hit and
## the ground marks left behind. Does not use the user's saves.
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/skill_feel_shots.tscn -- OUT_DIR

var out_dir := ""
var rig: ThirdPersonCamera


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.combat_hitstop = true
	GameSettings.ult_cutin = true
	GameSettings.screen_shake = true
	get_window().size = Vector2i(1280, 720)
	seed(808)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-30, 0), Vector2(0, 0), Vector2(30, 3)])]
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	await _scene(&"warrior", "divine_edict", [0.32], ["cutin_god_divine_edict"], 2.6, "marks_divine_edict")
	await _scene(&"lancer", "worldsplitter", [0.32], ["cutin_200_worldsplitter"], 2.4, "marks_worldsplitter")
	await _scene(&"mage", "hell_meteor", [], [], 1.55, "throw_and_scorch_hell_meteor")
	await _scene(&"mage", "ice_storm", [], [], 1.4, "frost_ice_storm")
	print("SKILL FEEL SHOTS: done -> ", out_dir)
	get_tree().quit()


func _scene(cls: StringName, id: String, at: Array, names: Array, after: float, last_name: String) -> void:
	Game.new_profile(cls, "Feel QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 300
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var skill := ClassData.find_skill(cls, id)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.stats.crit = 0.2
	hero.position = Vector3(0, 0, -4)
	hero.field_radius = 40.0
	var mobs: Array[Mob] = []
	for i in 6:
		var mob := Mob.new()
		mob.setup(&"forest_orc" if i % 2 == 0 else &"pink_slime", 100, Vector3.ZERO, hero)
		field.add_child(mob)
		var angle := TAU * float(i) / 6.0
		mob.position = Vector3(cos(angle) * 2.6, 0, 3.0 + sin(angle) * 2.0)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mob.stats.def = 0.0
		mobs.append(mob)
	rig = ThirdPersonCamera.new()
	rig.target = hero
	rig.distance = 9.0
	rig.pitch_degrees = -28.0
	field.add_child(rig)
	hero.camera_rig = rig
	hero.target = mobs[0]
	hero.set_facing(0.0)
	rig.set_yaw_behind(PI)
	rig.snap_to_target()
	VfxKit.warm_shaders(field, Vector3(0, 0, 3))
	await get_tree().create_timer(0.6).timeout
	hero._cast(skill)
	for k in at.size():
		# The cut-in's own clock (capped per frame, so a slow software frame cannot skip it).
		for i in 600:
			var layer := UltCutIn.active()
			if layer == null or layer._t >= float(at[k]):
				break
			await get_tree().process_frame
		await _capture(String(names[k]))
	await get_tree().create_timer(after).timeout
	await _capture(last_name)
	# The art has gone: the marks still lie there, fading.
	await get_tree().create_timer(1.6).timeout
	await _capture(last_name + "_after")
	await get_tree().create_timer(0.4).timeout
	UltCutIn.stop_now()
	Engine.time_scale = 1.0
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(label + ".png"))
