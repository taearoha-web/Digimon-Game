extends Node3D
## Captures actual Hero casts in a meadow clearing, including genuine chibi gear.
## Use a disposable XDG_DATA_HOME and a rendering display:
## godot --path . --fixed-fps 24 res://tests/tools/spectacle_showcase.tscn -- OUT_DIR armageddon 24 1280 720 2
## Select armageddon, ultimates, ultimates_no_meteor, CLASS, SKILL_ID, or catalogue. Catalogue writes
## several phases per skill; other modes write every frame for a video encoder.

class TrainingMob extends Mob:
	var hits := 0

	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits += 1
		return super.take_hit(amount, critical, color, attacker)

	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass


var out_dir := ""
var selector := "armageddon"
var fps := 24
var camera: Camera3D
var caption: Label
var subcaption: Label
var manifest: Array[Dictionary] = []
var failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Spectacle showcase requires a display and OUT_DIR [armageddon|ultimates|ultimates_no_meteor|CLASS|SKILL_ID|catalogue] [fps] [width] [height] [quality]")
		get_tree().quit(1)
		return
	out_dir = args[0]
	selector = args[1] if args.size() > 1 else "armageddon"
	fps = clampi(int(args[2]), 6, 60) if args.size() > 2 else 24
	var dimensions := Vector2i(int(args[3]), int(args[4])) if args.size() > 4 else Vector2i(1280, 720)
	get_window().size = dimensions
	get_window().content_scale_size = dimensions
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = clampi(int(args[5]), 0, 2) if args.size() > 5 else 2
	_build_stage()
	var families: Array[StringName] = [&"vagabond"]
	families.append_array(ClassData.IDS)
	for family in families:
		var pool := ClassData.pool(family)
		for skill in pool:
			var chosen := selector in ["catalogue", String(family), String(skill.id)]
			if selector == "ultimates":
				chosen = family != &"vagabond" and skill == pool.back()
			elif selector == "ultimates_no_meteor":
				chosen = family != &"vagabond" and skill == pool.back() and String(skill.id) != "armageddon"
			if chosen:
				await _capture(family, skill, selector == "catalogue" or selector == String(family))
	if manifest.is_empty():
		failures += 1
		printerr("No skill matched: ", selector)
	var file := FileAccess.open(out_dir.path_join("showcase.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	else:
		failures += 1
	_stop_audio()
	for child in get_children():
		child.queue_free()
	camera = null
	caption = null
	subcaption = null
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("SPECTACLE SHOWCASE: %d skills, %d failures -> %s" % [manifest.size(), failures, out_dir])
	get_tree().quit(failures)


func _build_stage() -> void:
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var clearings: Array[Vector3] = [Vector3(0, 0, 14)]
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(-40, 1), Vector2(-15, 2), Vector2(0, 0), Vector2(20, 3), Vector2(40, -1)])]
	Scenery.ground(self, 85.0, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, clearings, &"meadow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 419
	Scenery.populate(self, &"meadow", rng, 46.0, clearings, 0.62, false)
	WorldArt.landscape(self, &"meadow", 48.0, 871)
	camera = Camera3D.new()
	camera.fov = 51.0
	camera.far = 260.0
	add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.09, 0.12, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.size.y = 95
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	caption = Label.new()
	caption.position = Vector2(28, 14)
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_color", Color("fff2d6"))
	overlay.add_child(caption)
	subcaption = Label.new()
	subcaption.position = Vector2(29, 52)
	subcaption.add_theme_font_size_override("font_size", 18)
	subcaption.add_theme_color_override("font_color", Color("cfdfce"))
	overlay.add_child(subcaption)


func _capture(family: StringName, skill: Dictionary, stills: bool) -> void:
	seed(773 + String(skill.id).hash())
	Game.new_profile(family, "Toon Tale", {"gender": 1 if family in [&"mage", &"priest", &"summoner"] else 0})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.skills[String(skill.id)] = 1
	Game.profile.loadout[0] = String(skill.id)
	var equipment_rng := RandomNumberGenerator.new()
	equipment_rng.seed = 881
	for slot in ["weapon", "armor", "helm", "boots"]:
		Game.profile.equip[slot] = ItemData.generate(100, family, equipment_rng, 2, slot)
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.stats.atk = 100.0
	hero.stats.crit = 0.0
	hero.stats.haste = 0.0
	hero.position = Vector3(-4, 0, 3)
	var target := TrainingMob.new()
	target.setup(&"forest_orc", 100, Vector3.ZERO, hero)
	field.add_child(target)
	target.position = Vector3(2, 0, 0)
	target.hp = 10000000
	target.max_hp = 10000000
	target.set_physics_process(false)
	hero.target = target
	hero.set_facing(atan2(target.position.x - hero.position.x, target.position.z - hero.position.z))
	var meteor := String(skill.id) == "armageddon"
	var focal := Vector3(0, 6.0 if meteor else 1.7, 0)
	camera.position = focal + (Vector3(18, 14, 29) if meteor else Vector3(10, 8, 16))
	camera.look_at(focal)
	caption.text = "%s  /  %s" % [String(family).to_upper(), String(skill.name)]
	subcaption.text = "Lv.%d · Actual game character and combat effects" % int(skill.level)
	for i in maxi(2, int(fps * 0.35)):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	SkillShow._recent_shows.clear()
	hero._cast(skill)
	var duration := 9.5 if meteor else (5.0 if String(skill.shape) == "summon" else 3.0)
	var folder := out_dir.path_join(String(skill.id))
	DirAccess.make_dir_recursive_absolute(folder)
	var frames := ceili(duration * float(fps))
	var milestones: Array[int] = []
	var phase_times := [0.35, 0.9, 1.35, 2.15, 2.8]
	if meteor:
		phase_times = [0.35, 1.2, 1.8, 2.2, 2.7, 3.2, 4.7, 6.2, 7.2]
	for when in phase_times:
		milestones.append(roundi(float(when) * float(fps)))
	var captures := 0
	for i in frames:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var t := float(i) / float(fps)
		if meteor:
			if t > 2.0:
				var blend := smoothstep(2.0, 3.4, t)
				var focus := focal.lerp(Vector3(0, 2.0, 0), blend)
				camera.position = focus + Vector3(18, 14, 29).lerp(Vector3(13, 13, 21), blend)
				camera.look_at(focus)
			subcaption.text = "Giant meteor + 10 fragments (0.5 s apart) · %d / 11 hits · %.1f s" % [target.hits, t]
		if not stills or i in milestones:
			var frame := get_viewport().get_texture().get_image()
			var filename := folder.path_join("frame_%04d.png" % i)
			if frame.save_png(filename) != OK:
				failures += 1
				printerr("Could not save: ", filename)
			captures += 1
	manifest.append({"skill": String(skill.id), "class": String(family), "name": String(skill.name), "frames": captures,
		"fps": fps, "duration": duration, "quality": GameSettings.quality, "stills": stills, "real_mob_hits": target.hits, "hero_model": hero.visual.model.scene_file_path})
	print("SPECTACLE SKILL: %s · %d captures · %d damage events" % [skill.id, captures, target.hits])
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame


func _stop_audio() -> void:
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
