extends Node3D
## Frames of one skill's release at several times after the cast, for timing
## reviews of the authored art (the gallery shows a single instant).
## godot --rendering-driver opengl3 --path . res://tests/tools/skill_frames.tscn -- OUT_PREFIX family skill_id [t1,t2,...]

var camera: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("Expected OUT_PREFIX family skill_id [times]")
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
	camera.look_at(Vector3(1.2, 0.8, 0))
	var family := StringName(args[1])
	var skill := ClassData.find_skill(family, args[2])
	var times: PackedStringArray = (args[3] if args.size() > 3 else "0.1,0.25,0.45,0.8").split(",")
	var fx := Node3D.new()
	add_child(fx)
	var hero := HeroVisual.new()
	fx.add_child(hero)
	var rng := RandomNumberGenerator.new()
	rng.seed = 918
	hero.setup(family, "", true, {"weapon": ItemData.generate(int(skill.get("level", 1)), family, rng, 2, "weapon")}, {"gender": 0})
	hero.rotation_degrees.y = 90
	var target := Vector3(2.5, 0, 0)
	camera.size = maxf(9.0, float(skill.get("radius", 2.0)) * 1.9)
	await get_tree().create_timer(0.12).timeout
	var release := float(skill.hit_delay)
	hero.skill_action(skill, release)
	SkillShow.anticipate(fx, skill, Vector3.ZERO, release, target, hero)
	await get_tree().create_timer(release).timeout
	SkillShow.play(fx, skill, target, Vector3.ZERO)
	if String(skill.shape) == "single":
		SkillTableau.contact(fx, skill, target + Vector3(0, 0.9, 0), true)
	elif String(skill.shape) == "chain":
		SkillTableau.link(fx, skill, Vector3(0, 1.2, 0), target + Vector3(0, 1, 0))
		SkillTableau.link(fx, skill, target + Vector3(0, 1, 0), target + Vector3(1.5, 1, 2.5))
	var clock := 0.0
	for i in times.size():
		var at := float(times[i])
		if at > clock:
			await get_tree().create_timer(at - clock).timeout
			clock = at
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		frame.save_png("%s_%s_%02d.png" % [args[0], args[2], i])
	print("SKILL FRAMES: %s x%d" % [args[2], times.size()])
	get_tree().quit()
