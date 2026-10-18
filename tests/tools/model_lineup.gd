extends Node3D
## Renders glb files side by side (no game code): checks imports quickly.
##   godot --rendering-driver opengl3 --path . res://tests/tools/model_lineup.tscn -- out.png SIZE res://a.glb res://b.glb ...
## SIZE = spacing between models in metres; each model is scaled to fit that spacing.
func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("cfe6f5")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.7
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-35, 25, 0); l.light_energy = 1.0; add_child(l)
	var args := OS.get_cmdline_user_args()
	var spacing := float(args[1])
	var paths := args.slice(2)
	var n := paths.size()
	for i in n:
		var scene := (load(paths[i]) as PackedScene).instantiate() as Node3D
		var holder := Node3D.new(); add_child(holder); holder.add_child(scene)
		var box := AABB()
		var first := true
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		var fit := spacing * 0.85 / maxf(box.size.y, maxf(box.size.x, 0.01))
		holder.scale = Vector3.ONE * fit
		holder.position = Vector3((i - (n - 1) * 0.5) * spacing, -box.get_center().y * fit, 0)
		holder.rotation_degrees.y = float(args[0].contains("back")) * 180.0 + 20.0
		for ap in scene.find_children("*", "AnimationPlayer", true, false):
			var p := ap as AnimationPlayer
			if p.has_animation("Idle"): p.play("Idle")
	var cam := Camera3D.new(); cam.fov = 30
	cam.position = Vector3(0, 0, spacing * maxf(n, 2) * 0.95 + spacing)
	add_child(cam)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0]); get_tree().quit()
