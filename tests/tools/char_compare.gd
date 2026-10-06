extends Node3D
## Current heroes (top row) vs Quaternius RPG Character Pack (bottom row).
## godot --path . res://tests/tools/char_compare.tscn -- out.png
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 0.9; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var classes := ["warrior", "archer", "mage", "priest"]
	for i in classes.size():
		var h := HeroVisual.new(); add_child(h); h.setup(StringName(classes[i]), "", true, {})
		h.position = Vector3(-4.5 + i * 3.0, 0, 0); h.visible = args.size() < 2 or args[1] == "ours"; h.rotation_degrees.y = 15
	var rpg := ["Warrior", "Ranger", "Wizard", "Cleric", "Rogue", "Monk"]
	for i in rpg.size():
		var scene := load("res://assets/models/characters/rpg/%s.gltf" % rpg[i]) as PackedScene
		var m := scene.instantiate() as Node3D
		add_child(m)
		var box := MonsterVisual._bounds(m)
		var fit := 1.9 / maxf(box.size.y, 0.001)
		m.scale = Vector3.ONE * fit
		m.position = Vector3(-7.5 + i * 3.0, -box.position.y * fit, 0)
		m.rotation_degrees.y = 15
		m.visible = args.size() < 2 or args[1] == "rpg"
		var ap := MonsterVisual._find_player(m)
		if ap and ap.has_animation("Idle"):
			ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("Idle")
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.6, 11.0); cam.rotation_degrees = Vector3(-10, 0, 0); cam.fov = 55; add_child(cam)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
