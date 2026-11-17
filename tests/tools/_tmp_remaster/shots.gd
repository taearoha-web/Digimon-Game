extends Node3D
## Temp: per-monster shots in the meadow's light. args: outdir [orig]
const IDS := [&"pink_slime", &"green_slime", &"wild_chicken", &"yellow_frog", &"mush_baby", &"cactus_hat", &"mush_king", &"toad_king", &"toxic_frog", &"lotus_frog", &"giant_cactus"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var outdir: String = args[0]
	if args.size() > 1 and args[1] == "orig":
		MonsterVisual.use_remaster = false
	var z: Dictionary = ZoneData.get_zone(&"meadow")
	var sky: Color = z.sky
	Scenery.environment(self, sky, sky.lerp(Color.WHITE, 0.35), Color(0.9, 0.95, 1.0), Color(1.0, 0.96, 0.88), {"theme": &"meadow", "palette": z.sky_palette})
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	g.mesh = pm
	g.material_override = MeshKit.toon(Color("91aa77"))
	add_child(g)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.current = true
	if OS.get_environment("NOLOD") != "":
		get_viewport().mesh_lod_threshold = 0.0
	var only: Array = []
	if args.size() > 2:
		only = Array(args[2].split(","))
	for id in IDS:
		if not only.is_empty() and not only.has(String(id)):
			continue
		var t: Dictionary = MonsterData.get_monster(id)
		var v := CelestialDragonVisual.make(self, t)
		var h := float(t.height)
		for mode in ["idle", "attack", "close", "back"]:
			v.rotation_degrees.y = 25.0 if mode != "back" else float(OS.get_environment("BACKYAW") if OS.get_environment("BACKYAW") != "" else "155")
			if mode == "attack":
				var clip: StringName = v._clips.get("attack", &"")
				if clip != &"":
					v.anim.play(clip)
					v.anim.seek(v.anim.get_animation(clip).length * 0.4, true)
					v.anim.pause()
			else:
				v.anim.play(v._clips["idle"])
				v.anim.seek(0.3, true)
				v.anim.pause()
			v.current = "freeze"
			v.model.scale = v._rest_scale
			if OS.get_environment("RESTPOSE") != "":
				v.anim.stop()
				for sk in v.model.find_children("*", "Skeleton3D", true, false):
					(sk as Skeleton3D).reset_bone_poses()
			# The game camera's pitch (-24 degrees), framed on the monster.
			var d := h * (3.3 if mode != "close" else 1.9)
			var pitch := deg_to_rad(-24.0 if mode != "close" else -12.0)
			var focus := Vector3(0, h * 0.5, 0)
			cam.position = focus + Vector3(0, -sin(pitch) * d, cos(pitch) * d)
			cam.look_at(focus)
			for i in 3:
				await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var s := 600
			img = img.get_region(Rect2i((img.get_width() - s) / 2, (img.get_height() - s) / 2, s, s))
			img.save_png("%s/%s_%s.png" % [outdir, id, mode])
		v.queue_free()
		await get_tree().process_frame
	get_tree().quit()
