extends Node3D
## Renders the four classes and some monsters side by side.
## godot --path . res://tests/tools/preview_cast.tscn -- out.png
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.shadow_enabled = true; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 30); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var i := 0
	for c in ClassData.IDS:
		var h := HeroVisual.new(); add_child(h); h.setup(c); h.position = Vector3(-4.5 + i * 3.0, 0, 0); h.rotation_degrees.y = 10
		i += 1
	var mons := [[&"pink_slime"], [&"wild_chicken"], [&"cactus_hat"], [&"mush_king"], [&"forest_orc"], [&"poison_bee"], [&"fire_dragon"]]
	i = 0
	for m in mons:
		var d := MonsterData.get_monster(m[0]); var v := MonsterVisual.new(); add_child(v)
		v.setup(d.model, d.height, float(d.get("hover", 0.0))); v.position = Vector3(-7.5 + i * 2.6, 0, -5)
		i += 1
	var cam := Camera3D.new(); cam.position = Vector3(0, 2.6, 7.0); cam.rotation_degrees = Vector3(-8, 0, 0); cam.fov = 55; add_child(cam)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]); get_tree().quit()
