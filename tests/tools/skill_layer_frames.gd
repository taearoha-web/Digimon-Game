extends Node3D
## Frame strips of real Hero._cast calls (skills, star skills and god skills) on a
## deterministic meadow with monsters, for reviewing the shared skill layer stack
## (SkillLayers): anticipation, core, secondary motion, environment, afterglow.
## Each skill becomes one 3x2 sheet: the wind-up, the release and the dissipation.
## Pass "nolayers" to render with SkillLayers switched off (a before/after pair).
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/tools/skill_layer_frames.tscn -- OUT_DIR TAG class:skill,class:skill [nolayers] [q0|q1|q2]

const FRAME := Vector2i(640, 360)
var out_dir := ""
var tag := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or DisplayServer.get_name() == "headless":
		printerr("Expected OUT_DIR TAG class:skill,... [nolayers] [q0|q1|q2]")
		get_tree().quit(1)
		return
	out_dir = args[0]
	tag = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	for q in ["q0", "q1", "q2"]:
		if q in args:
			GameSettings.quality = int(q.substr(1))
	GameSettings.combat_hitstop = false
	GameSettings.ult_cutin = false
	GameSettings.screen_shake = false
	SkillLayers.enabled = not ("nolayers" in args)
	get_window().size = Vector2i(1280, 720)
	seed(808)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	Scenery.ground(self, 60.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), [] as Array[PackedVector2Array], 2.5, [Vector3.ZERO], &"meadow")
	for entry in String(args[2]).split(",", false):
		var parts := String(entry).split(":")
		await _scene(StringName(parts[0]), parts[1])
	print("SKILL LAYER FRAMES: done -> ", out_dir)
	get_tree().quit()


func _skill(cls: StringName, id: String) -> Dictionary:
	var skill := ClassData.find_skill(cls, id)
	if skill.is_empty():
		for star in StarSkillData.pool(cls):
			if String(star.id) == id:
				return star
	return skill


func _scene(cls: StringName, id: String) -> void:
	Game.new_profile(cls, "Layer QA", {"gender": 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 300
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var skill := _skill(cls, id)
	if skill.is_empty():
		printerr("unknown skill ", cls, ":", id)
		return
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.position = Vector3(0, 0, -3.5)
	hero.field_radius = 40.0
	var mobs: Array[Mob] = []
	for i in 5:
		var mob := Mob.new()
		mob.setup(&"forest_orc" if i % 2 == 0 else &"pink_slime", 100, Vector3.ZERO, hero)
		field.add_child(mob)
		var angle := TAU * float(i) / 5.0
		mob.position = Vector3(cos(angle) * 2.2, 0, 3.0 + sin(angle) * 1.6) if i > 0 else Vector3(0, 0, 3.0)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mob.set_physics_process(false)
		mobs.append(mob)
	var cam := Camera3D.new()
	cam.fov = 52.0
	field.add_child(cam)
	cam.position = Vector3(8.2, 5.4, -3.6)
	cam.look_at(Vector3(0, 1.0, 0.6))
	cam.current = true
	hero.target = mobs[0]
	hero.set_facing(0.0)
	VfxKit.warm_shaders(field, Vector3(0, 0, 3))
	await get_tree().create_timer(0.7).timeout
	var delay := float(skill.get("hit_delay", 0.4))
	var times := [delay * 0.55, delay + 0.05, delay + 0.22, delay + 0.5, delay + 0.95, delay + 1.7]
	if skill.has("star"):
		times = [delay * 0.55, delay + 0.08, delay + 0.4, delay + 0.9, delay + 1.6, delay + 2.6]
	var frames: Array[Image] = []
	var clock := 0.0
	var lab := "lab" in OS.get_cmdline_user_args()
	if lab:
		# Only the shared layers, without the class art: for tuning them.
		var origin := hero.global_position
		var center := mobs[0].global_position if String(skill.shape) in ["single", "blast", "chain", "fan"] else origin
		SkillLayers.anticipate(field, skill, origin, delay, center, hero.visual)
		get_tree().create_timer(delay).timeout.connect(func():
			if skill.has("star"):
				SkillLayers.star_beat(field, skill, center, 0, 1, origin)
			else:
				SkillLayers.release(field, skill, center, origin, 0.0)
				if bool(skill.get("projectile", false)) or String(skill.shape) in ["fan", "chain"]:
					SkillLayers.contact(field, skill, mobs[0].hit_point(), false))
	else:
		hero._cast(skill)
	for at in times:
		if float(at) > clock:
			await get_tree().create_timer(float(at) - clock).timeout
			clock = float(at)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if "full" in OS.get_cmdline_user_args():
			image.save_png(out_dir.path_join("%s_%s_%s_f%d.png" % [tag, cls, id, frames.size()]))
		image.resize(FRAME.x, FRAME.y, Image.INTERPOLATE_BILINEAR)
		frames.append(image)
	var sheet := Image.create(FRAME.x * 3, FRAME.y * 2, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, FRAME), Vector2i((i % 3) * FRAME.x, (i / 3) * FRAME.y))
	sheet.save_png(out_dir.path_join("%s_%s_%s.png" % [tag, cls, id]))
	var pool := SkillLayerPool.existing(get_tree())
	print("frames ", id, " counters ", VfxBudget.counters(), " nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		" pressure ", MemoryGuard.pressure, " pool ", pool.node_count() if pool else 0, " borrowed ", pool.borrowed if pool else 0, " last ", SkillLayers.last)
	field.queue_free()
	await field.tree_exited
	await get_tree().create_timer(0.3).timeout
