extends Node3D
## Lines up monster models: godot --path . res://tests/tools/monster_preview.tscn -- out.png dir1/Name,dir2/Name,...
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.5
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 0.9; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 40); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var args := OS.get_cmdline_user_args()
	var names: PackedStringArray = args[1].split(",")
	var per_row := 8
	for i in names.size():
		var v := MonsterVisual.new(); add_child(v)
		v.setup(names[i], 2.0)
		v.position = Vector3((i % per_row) * 3.0 - (per_row - 1) * 1.5, 0, -float(i / per_row) * 3.2)
		v.rotation_degrees.y = 15
	var rows := (names.size() + per_row - 1) / per_row
	var cam := Camera3D.new(); cam.position = Vector3(0, 3.2 + rows * 0.8, 11.0 + rows * 1.2); cam.rotation_degrees = Vector3(-12, 0, 0); cam.fov = 55; add_child(cam)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
