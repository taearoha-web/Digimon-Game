extends Node3D
## Row of heroes in different gear: godot --path . res://tests/tools/gear_preview.tscn -- out.png [class]
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.5
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 0.7; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var classes: Array = [args[1]] if args.size() > 1 else ["warrior", "archer", "mage", "priest"]
	var row := 0
	for c in classes:
		for i in 10:
			var equip := {}
			if true:
				equip["weapon"] = ItemData.generate(i * 10 + 5, StringName(c), rng, 1, "weapon")
				equip["armor"] = ItemData.generate(i * 10 + 5, StringName(c), rng, 1, "armor")
				equip["helm"] = ItemData.generate(i * 10 + 5, StringName(c), rng, 1, "helm")
				equip["boots"] = ItemData.generate(i * 10 + 5, StringName(c), rng, 1, "boots")
				equip["amulet"] = ItemData.generate(i * 10 + 5, StringName(c), rng, 1, "amulet")
			var h := HeroVisual.new(); add_child(h); h.setup(StringName(c), "", true, equip)
			h.position = Vector3(-13.5 + i * 3.0, 0, -row * 3.2); h.rotation_degrees.y = 10
		row += 1
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.4 + 1.2 * (classes.size() - 1), 10.5 + 1.2 * (classes.size() - 1)); cam.rotation_degrees = Vector3(-10, 0, 0); cam.fov = 62; add_child(cam)
	cam.position.z -= 0
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
