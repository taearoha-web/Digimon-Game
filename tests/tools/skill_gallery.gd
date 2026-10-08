extends Node3D
## Rendered contact sheet, independent of saves and combat AI.
## godot --path . res://tests/tools/skill_gallery.tscn -- /tmp/skills.png [all|warrior|archer|mage|priest|vagabond]
## Omit the class for a representative eight-skill sheet; 'all' captures 102.

var camera: Camera3D
var caption: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Expected output PNG path")
		get_tree().quit(1)
		return
	GameSettings.load_settings()
	GameSettings.quality = 2
	get_window().size = Vector2i(720, 480)
	get_window().content_scale_size = Vector2i(720, 480)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("263f46")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e3f1ef")
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("fff1d9")
	sun.light_energy = 1.2
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("4e7068"))
	add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(7, 8, 11)
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0))
	var layer := CanvasLayer.new()
	add_child(layer)
	caption = Label.new()
	caption.position = Vector2(22, 16)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_color", Color("fff1cf"))
	layer.add_child(caption)
	var chosen: Array[Dictionary] = []
	var examples := ["brutal_swing", "godly_shield", "hurricane", "force_of_nature", "flame_wave", "energy_shield", "grand_healing", "glacial_spike"]
	for family in SkillShow.FAMILY_COLORS:
		for skill in ClassData.pool(StringName(family)):
			if (args.size() > 1 and (args[1] == "all" or args[1] == family)) or (args.size() == 1 and skill.id in examples):
				chosen.append(skill)
	var frames: Array[Image] = []
	for skill in chosen:
		var family := SkillShow.family_of(skill)
		var fx := Node3D.new()
		add_child(fx)
		var hero := HeroVisual.new()
		fx.add_child(hero)
		hero.setup(StringName(family))
		hero.position = Vector3.ZERO
		hero.rotation_degrees.y = 25
		var target := Vector3(2.5, 0, 0)
		camera.size = maxf(8.5, float(skill.get("radius", 2.0)) * 2.15)
		caption.text = "%s  /  %s" % [family.capitalize(), String(skill.name)]
		await get_tree().create_timer(0.12).timeout
		SkillShow._recent_shows.clear()
		SkillShow.anticipate(fx, skill, Vector3.ZERO, 0.25)
		await get_tree().create_timer(0.25).timeout
		SkillShow.play(fx, skill, target, Vector3.ZERO)
		if bool(skill.get("projectile", false)):
			VfxKit.projectile(fx, skill.color, Vector3(0, 1.2, 0), target + Vector3(0, 1, 0), 0.36, 0.3, VfxKit.variant_for(skill.vfx))
		await get_tree().create_timer(0.26).timeout
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.resize(540, 360, Image.INTERPOLATE_LANCZOS)
		frame.convert(Image.FORMAT_RGBA8)
		frames.append(frame)
		fx.queue_free()
		await get_tree().process_frame
	var cols := 4
	var sheet := Image.create(540 * cols, 360 * int(ceil(float(frames.size()) / float(cols))), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("20363d"))
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 540, 360), Vector2i((i % cols) * 540, (i / cols) * 360))
	var error := sheet.save_png(args[0])
	print("SKILL GALLERY: %d skills, saved %s, result %d" % [frames.size(), args[0], error])
	get_tree().quit(error)
