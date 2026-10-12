extends Node3D
var out_dir := "/workspace/toon-artifacts/thunder-storm-v076"
var label: Label
var waves: Array = []
func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.quality = 2
	Game.new_profile(&"mage", "Thunder Storm", {"gender": 1})
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.skills["thunder_storm"] = 1
	Game.profile.hp = 100000
	Game.profile.mp = 100000
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	Scenery.environment(self, Color("789bba"), Color("adc2c6"), Color("d9e5f0"), Color("ffe4bf"))
	var paths: Array[PackedVector2Array] = []
	Scenery.ground(self, 60, Color("607f61"), Color("779265"), 912, Color("a59f7e"), paths, 2.5, [Vector3.ZERO], &"meadow")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	add_child(camera)
	camera.position = Vector3(18, 12, 24)
	camera.look_at(Vector3(0, 2.5, 0))
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("20252c"))
	label.text = "TOON TALE / Thunder Storm"
	layer.add_child(label)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3(-10, 0, 1)
	var target: Mob
	for i in 8:
		var mob := Mob.new()
		mob.setup(&"forest_orc", 100, Vector3.ZERO, hero)
		field.add_child(mob)
		mob.position = Vector3(sin(i * TAU / 7) * 6, 0, cos(i * TAU / 7) * 6) if i > 0 else Vector3.ZERO
		mob.hp = 10000000
		mob.max_hp = mob.hp
		mob.set_physics_process(false)
		if i == 0:
			target = mob
	hero.target = target
	hero.set_facing(PI * 0.5)
	field.child_entered_tree.connect(func(node):
		if node is ThunderStormSequence:
			node.wave_fired.connect(_wave)
	)
	hero._cast(ClassData.find_skill(&"mage", "thunder_storm"))
	await get_tree().create_timer(4.0).timeout
	var f := FileAccess.open(out_dir.path_join("showcase.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"waves": waves, "radius": 9.0, "single_cloud": true}, "\t"))
	field.queue_free()
	await field.tree_exited
	print("THUNDER SHOWCASE: ", waves.size(), " real waves captured")
	get_tree().quit()
func _wave(index: int, targets: Array) -> void:
	label.text = "TOON TALE / Thunder Storm — Wave %d / 3 — %d targets" % [index + 1, targets.size()]
	waves.append({"wave": index + 1, "target_count": targets.size()})
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join("wave-%d.png" % (index + 1)))
