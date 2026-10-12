extends Node3D
## Native-rendered catalogue of the actual stage builders and skill presentation.
## Use a fresh XDG_DATA_HOME: the zone fixture creates a disposable level-100 save.
## godot --path . res://tests/tools/art_catalog.tscn -- OUT_DIR zones [all|ZONE] [0|1|2]
## godot --path . res://tests/tools/art_catalog.tscn -- OUT_DIR skills [all|CLASS] [0|1|2]
## Each skill gets a PNG and an entry in its family contact sheet, including
## ElementFx meshes invoked by SkillShow and the real projectile renderer.

var out_dir := ""
var selector := "all"
var caption: Label
var camera: Camera3D
var manifest: Array[Dictionary] = []
var failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or DisplayServer.get_name() == "headless":
		printerr("Art catalogue requires a rendering display and: OUT_DIR zones|skills [all|id] [quality]")
		get_tree().quit(1)
		return
	out_dir = args[0]
	selector = args[2] if args.size() > 2 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameSettings.load_settings()
	GameSettings.quality = clampi(int(args[3]), 0, 2) if args.size() > 3 else 2
	Game.set_process(false)
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 18)
	caption.add_theme_font_size_override("font_size", 24)
	caption.add_theme_color_override("font_color", Color("fff2d9"))
	caption.add_theme_color_override("font_shadow_color", Color("182b35"))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	if args[1] == "zones":
		await _zones()
	elif args[1] == "skills":
		await _skills()
	else:
		printerr("Unknown catalogue mode: ", args[1])
		failures += 1
	if manifest.is_empty():
		printerr("No entries matched: ", selector)
		failures += 1
	var file := FileAccess.open(out_dir.path_join("%s_%s_q%d.json" % [args[1], selector, GameSettings.quality]), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
	else:
		failures += 1
	_stop_audio()
	# Flush visual instances before engine shutdown so a capture run can also
	# reveal resource leaks instead of merely abandoning its last lit scene.
	for child in get_children():
		child.queue_free()
	camera = null
	caption = null
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("ART CATALOG: %d %s entries, quality %d, %d failures" % [manifest.size(), args[1], GameSettings.quality, failures])
	get_tree().quit(failures)


func _zones() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	Game.new_profile(&"mage", "Art catalogue")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.fill_loadout()
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp
	var thumbnails: Array[Image] = []
	for id in ZoneData.ZONES:
		if selector != "all" and selector != String(id):
			continue
		seed(8719 + String(id).hash())
		Game.current_zone = id
		Game.profile["spawn_override"] = ""
		var zone := Zone.new()
		zone.zone_id = id
		add_child(zone)
		zone.set_process(false)
		zone.hero.set_physics_process(false)
		zone.hero.set_process(false)
		zone.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		if zone.pvp_match:
			zone.pvp_match.process_mode = Node.PROCESS_MODE_DISABLED
		if zone.tower_run:
			zone.tower_run.process_mode = Node.PROCESS_MODE_DISABLED
		for mob in get_tree().get_nodes_in_group("mobs"):
			mob.set_physics_process(false)
			mob.set_process(false)
		var focus := Vector3(-15, 1.0, -9)
		var offset := Vector3(23, 18, 29)
		if id == &"town":
			focus = Vector3(-2, 2, -6)
			offset = Vector3(30, 24, 40)
		elif id == &"pvp":
			focus = Vector3(0, 1, -2)
			offset = Vector3(30, 25, 38)
		elif id in [&"tower", &"arena"]:
			focus = Vector3(0, 2, -5)
			offset = Vector3(27, 20, 33)
		zone.hero.global_position = Vector3(focus.x - 3, 0.2, focus.z + 4)
		camera = Camera3D.new()
		camera.fov = 54.0
		camera.far = 350.0
		zone.add_child(camera)
		camera.global_position = focus + offset
		camera.look_at(focus)
		camera.make_current()
		caption.text = "%s  ·  %s" % [String(id).capitalize(), String(ZoneData.ZONES[id].name)]
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		var filename := "zone_%s_q%d.png" % [id, GameSettings.quality]
		_save(frame, filename)
		var entry := {"zone": id, "name": ZoneData.ZONES[id].name, "quality": GameSettings.quality, "image": filename,
			"camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "nodes": zone.find_children("*", "", true, false).size()}
		frame.resize(480, 270, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		thumbnails.append(frame)
		# A nearer view also shows the foliage LOD and ground texture at combat
		# distance; the overview alone intentionally spans multiple encounters.
		camera.global_position = zone.hero.global_position + Vector3(0, 4.5, 8.5)
		camera.look_at(zone.hero.global_position + Vector3(0, 1.0, -1.0))
		caption.text = "%s · playfield" % String(id).capitalize()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var playfield_filename := "playfield_%s_q%d.png" % [id, GameSettings.quality]
		_save(get_viewport().get_texture().get_image(), playfield_filename)
		entry["playfield_image"] = playfield_filename
		if ZoneData.ZONES[id].has("boss"):
			var boss := Vector3(30, 0, 26)
			var detail_focus := boss + boss.normalized() * 10.0 + Vector3.UP * 2.5
			zone.hero.global_position = boss + Vector3(-2, 0.2, 2)
			camera.global_position = detail_focus + Vector3(-23, 12, -17)
			camera.look_at(detail_focus)
			caption.text = "%s · landmark" % String(id).capitalize()
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			var detail_filename := "landmark_%s_q%d.png" % [id, GameSettings.quality]
			_save(get_viewport().get_texture().get_image(), detail_filename)
			entry["landmark_image"] = detail_filename
		manifest.append(entry)
		print("ART ZONE: ", id, " -> ", filename)
		zone.queue_free()
		await zone.tree_exited
		await get_tree().process_frame
	_sheet(thumbnails, Vector2i(480, 270), "zones_%s_q%d.png" % [selector, GameSettings.quality], 3)


func _skills() -> void:
	get_window().size = Vector2i(720, 480)
	get_window().content_scale_size = Vector2i(720, 480)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263e45")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("deece7")
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 0.65
	add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(90, 90)
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.material_override = MeshKit.toon(Color("47675e"))
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	var families: Array[StringName] = [&"vagabond"]
	families.append_array(ClassData.IDS)
	for family in families:
		if selector != "all" and selector != String(family):
			continue
		var frames: Array[Image] = []
		for skill in ClassData.pool(family):
			seed(712 + String(skill.id).hash())
			var fx := Node3D.new()
			add_child(fx)
			var hero := HeroVisual.new()
			fx.add_child(hero)
			hero.setup(family)
			hero.rotation_degrees.y = 25.0
			var target := Vector3(3, 0, 0)
			var aim := Vector3(0.9, 1, 0)
			camera.position = aim + Vector3(7, 8, 11)
			camera.look_at(aim)
			camera.size = maxf(9.0, float(skill.get("radius", 2.0)) * 2.15)
			caption.text = "%s · %s\n%s" % [String(family).capitalize(), String(skill.name), String(skill.id)]
			caption.add_theme_font_size_override("font_size", 20)
			await get_tree().create_timer(0.12).timeout
			SkillShow._recent_shows.clear()
			SkillShow.anticipate(fx, skill, Vector3.ZERO, 0.22)
			hero.action(skill.anim, 1.0)
			await get_tree().create_timer(0.22).timeout
			SkillShow.play(fx, skill, target, Vector3.ZERO)
			if bool(skill.get("projectile", false)):
				if family == &"archer":
					VfxKit.arrow(fx, skill.color, Vector3(0, 1.2, 0), target + Vector3.UP, 0.4)
				else:
					VfxKit.projectile(fx, skill.color, Vector3(0, 1.2, 0), target + Vector3.UP, 0.4, 0.5, VfxKit.variant_for(skill.vfx))
			var look := SkillShow.profile_for(skill)
			var capture_time := clampf(float(look.get("tempo", 0.65)) * 0.44, 0.18, 0.42)
			if String(skill.get("special", "")) == "meteor":
				capture_time += 0.55
			await get_tree().create_timer(capture_time).timeout
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			var filename := "skill_%s_q%d.png" % [skill.id, GameSettings.quality]
			_save(frame, filename)
			manifest.append({"skill": skill.id, "family": family, "name": skill.name, "shape": skill.shape,
				"element": ElementFx.element_of(skill), "quality": GameSettings.quality, "image": filename, "capture_seconds": capture_time})
			frame.resize(540, 360, Image.INTERPOLATE_LANCZOS)
			frame.convert(Image.FORMAT_RGBA8)
			frames.append(frame)
			fx.queue_free()
			await fx.tree_exited
			await get_tree().process_frame
		_sheet(frames, Vector2i(540, 360), "skills_%s_q%d.png" % [family, GameSettings.quality], 4)
		print("ART SKILLS: ", family, " -> ", frames.size(), " captures")


func _save(frame: Image, filename: String) -> void:
	if frame.save_png(out_dir.path_join(filename)) != OK:
		printerr("Cannot write: ", filename)
		failures += 1


func _sheet(frames: Array[Image], cell: Vector2i, filename: String, columns: int) -> void:
	if frames.is_empty():
		return
	var rows := ceili(float(frames.size()) / float(columns))
	var sheet := Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("20363d"))
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % columns) * cell.x, (i / columns) * cell.y))
	_save(sheet, filename)


func _stop_audio() -> void:
	AudioManager.stop_music(0.0)
	AudioManager.play_ambient(&"")
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
