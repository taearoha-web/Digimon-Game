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
	var names: PackedStringArray = []
	var zone_mode: bool = args[1].begins_with("zone:")
	var ids: Array = []
	if zone_mode:
		var zone := ZoneData.get_zone(StringName(args[1].substr(5)))
		for camp in zone.camps:
			ids.append_array(camp.monsters)
		if zone.has("boss"):
			ids.append(zone.boss.monster)
		for id in ids:
			names.append(String(MonsterData.get_monster(id).model))
	else:
		names = args[1].split(",")
	var per_row := int(args[2]) if args.size() > 2 else 7
	for i in names.size():
		var v := MonsterVisual.new(); add_child(v)
		if zone_mode:
			var t: Dictionary = MonsterData.get_monster(ids[i])
			v.setup(names[i], minf(float(t.height), 3.2), float(t.get("hover", 0.0)) * 0.5, t.get("tint", Color.WHITE))
		else:
			v.setup(names[i], 2.4, 0.0)
		v.position = Vector3((i % per_row) * 4.0 - (per_row - 1) * 2.0, 0, -float(i / per_row) * 4.5)
		v.rotation_degrees.y = 15
		var tag := Label3D.new(); tag.text = names[i]; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.pixel_size = 0.012; tag.font_size = 40; tag.outline_size = 12; tag.position = v.position + Vector3(0, 3.0, 0); tag.no_depth_test = true; add_child(tag)
	var rows := (names.size() + per_row - 1) / per_row
	var cam := Camera3D.new(); cam.position = Vector3(0, 3.0 + rows * 1.0, 9.0 + rows * 2.2 + per_row * 0.8); cam.rotation_degrees = Vector3(-14, 0, 0); cam.fov = 55; add_child(cam)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
