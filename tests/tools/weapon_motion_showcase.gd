extends Node3D
## Render actual AnimationPlayer transitions, male and female, at fixed 24 fps.
## godot --path . --fixed-fps 24 --write-movie /tmp/motion.avi ...tscn
var actors: Array[HeroVisual] = []
var family_index := -1
var phase := -1
var clock := 0.0
var title: Label
var attachment_error := 0.0
const DURATION := 5.0
const TITLES := ["Warrior", "Archer", "Mage", "Priest", "Summoner", "Lancer"]


func _ready() -> void:
	Game.set_process(false)
	GameSettings.quality = 2
	get_window().size = Vector2i(960, 640)
	get_window().content_scale_size = Vector2i(960, 640)
	Scenery.environment(self, Color("243b50"), Color("243b50"), Color("e1eeff"), Color("fff1da"))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("78918d"))
	add_child(ground)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.7
	add_child(camera)
	camera.position = Vector3(0, 2.1, 11)
	camera.look_at(Vector3(0, 1.5, 0))
	camera.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	title = Label.new()
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 28)
	ui.add_child(title)
	_next()
	RenderingServer.frame_post_draw.connect(_check_attachments)


func _next() -> void:
	for hero in actors:
		hero.free()
	actors.clear()
	family_index += 1
	if family_index >= ClassData.IDS.size():
		print("WEAPON MOTION SHOWCASE: all six classes complete; max rendered attachment error ", attachment_error)
		get_tree().quit()
		set_process(false)
		return
	var family := ClassData.IDS[family_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 710
	var gear := {"weapon": ItemData.generate(5, family, rng, 0, "weapon")}
	gear.weapon["plus"] = 0
	for rig in 2:
		var hero := HeroVisual.new()
		add_child(hero)
		hero.setup(family, "", true, gear, {"gender": rig})
		hero.position.x = -1.6 if rig == 0 else 1.6
		hero.rotation_degrees.y = 20.0 if rig == 0 else -90.0
		actors.append(hero)
	phase = -1
	clock = 0.0
	print("RECORDING: ", family)


func _process(delta: float) -> void:
	clock += delta
	if clock >= DURATION:
		_next()
		return
	var step := 0 if clock < 0.5 else 1 if clock < 1.8 else 2 if clock < 2.8 else 3 if clock < 4.1 else 4
	if step == phase:
		return
	phase = step
	var family := ClassData.IDS[family_index]
	title.text = "TOON TALE  /  %s\n%s" % [TITLES[family_index], ["Ready", "Running", "Attack", "Skill", "Running"][phase]]
	for hero in actors:
		match phase:
			0: hero.play("Idle", 0.0)
			1, 4:
				hero.release()
				hero.play("Running_A", 0.18)
			2: hero.action(String(ClassData.get_class_data(family).attack.anims[0]))
			3: hero.skill_action(ClassData.pool(family)[0], 0.35)


func _check_attachments() -> void:
	for hero in actors:
		for held in hero._hold_nodes:
			var bone := hero._skeleton.find_bone(held.bone_name)
			var target := hero._skeleton.global_transform * hero._skeleton.get_bone_global_pose(bone)
			attachment_error = maxf(attachment_error, held.global_position.distance_to(target.origin))
