extends Node3D
## Screenshots of บททดสอบเทวาลัย (AscensionData): the trial guardian's fight on its altar,
## the promotion banner with its pillar of heaven, and six of the ★500 Ascension ultimates
## on real casts (Hero._cast), from a gameplay-like camera. Into ASCEND_SHOTS (env) or user://.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tools/ascend_shots.tscn

var cam: Camera3D
var title: Label
var out := ""
const ULTS := [&"warrior", &"mage", &"summoner", &"darklord", &"bard", &"muaythai"]


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "เทวาลัย", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": 500, "points": 0, "spent": 300, "exp": 0, "alloc": {}}
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		var piece := Star500Gear.item(String(cls), slot)
		if not piece.is_empty():
			Game.profile.equip[slot] = piece
	Game.profile.hp = 1000000
	Game.profile.mp = 1000000
	Game.profile.party = []
	Game.fill_loadout()


func _capture(file: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))
	print("CAPTURE ", file)


func _frame(focus: Vector3, distance := 21.0) -> void:
	cam.position = focus + Vector3(0, distance * 0.72, distance * 0.7)
	cam.look_at(focus + Vector3.UP * 1.5)


func _ready() -> void:
	out = OS.get_environment("ASCEND_SHOTS")
	if out == "":
		out = "user://"
	DirAccess.make_dir_recursive_absolute(out)
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.combat_hitstop = false
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	Scenery.environment(self, Color("5a5aa0"), Color("b8a8e8"), Color("f0e8ff"), Color("ffe8c0"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 140)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("c8bfa0"))
	add_child(ground)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	title = Label.new()
	title.position = Vector2(22, 16)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color("1a1030"))
	title.add_theme_constant_override("outline_size", 6)
	layer.add_child(title)
	await _trial()
	for cls in ULTS:
		await _ult(cls)
	Game.has_profile = false
	get_tree().quit()


func _trial() -> void:
	_profile(&"lancer")
	Game.profile.adv = JobData.GOD_ADV
	Game.profile.flags[AscensionData.STEP_FLAG] = AscensionData.TRIAL
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = AscendTrial.ALTAR + Vector3(-7, 0, 3)
	var trial := AscendTrial.new()
	trial.setup(field, hero)
	field.add_child(trial)
	trial.set_process(false)
	trial.step(AscendTrial.INTRO + 0.1)
	var boss := trial.boss
	boss.set_physics_process(false)
	hero.target = boss
	title.text = "%s • %s" % [AscensionData.STAGE_TITLE, AscensionData.BOSS_NAME]
	_frame(AscendTrial.ALTAR + Vector3(-3, 0, 1), 24.0)
	await get_tree().create_timer(0.8).timeout
	var moves := StoryBoss.of(boss)
	moves.force_special("lance")
	hero._cast(ClassData.find_skill(&"lancer", "heavenrend_spear"))
	# Past the cut-in: the god spear's waves round the guardian and its lance telegraph.
	await get_tree().create_timer(2.6).timeout
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	moves.force_special("nova")
	await get_tree().create_timer(0.3).timeout
	await _capture("trial_boss_fight")
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	boss.take_hit(int(boss.max_hp * 0.65), false, Color.WHITE, hero)
	moves.force_special("rain")
	await get_tree().create_timer(1.4).timeout
	await _capture("trial_boss_phase3")
	boss.take_hit(boss.hp, false, Color.WHITE, hero)
	trial.step(0.01)
	title.text = ""
	_frame(hero.global_position, 15.0)
	await get_tree().create_timer(1.2).timeout
	await _capture("promotion_banner")
	field.queue_free()
	await field.tree_exited


func _ult(cls: StringName) -> void:
	_profile(cls)
	var skill: Dictionary = ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][0]))
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(-3, 0, 3)
	var mobs: Array[Mob] = []
	for i in 4:
		var mob := Mob.new()
		var spot := Vector3(3 + (i % 2) * 2.5, 0, -1 - (i / 2) * 2.5)
		mob.setup(&"fallen_angel", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0]
	_frame(Vector3(1.5, 0, 0), 24.0)
	title.text = "TOON TALE • %s • ★500 %s" % [skill.name, JobData.ascend_step(cls).name]
	hero._cast(skill)
	await get_tree().create_timer(float(skill.hit_delay) + 0.75).timeout
	await _capture("ult_%s_%s_wave" % [cls, skill.id])
	await get_tree().create_timer(1.0).timeout
	await _capture("ult_%s_%s_finale" % [cls, skill.id])
	await get_tree().create_timer(1.6).timeout
	field.queue_free()
	await field.tree_exited
