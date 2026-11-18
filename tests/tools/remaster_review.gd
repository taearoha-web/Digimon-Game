extends Node3D
## Before/after review shots for the Blender remasters (tools/blender/remaster_monsters.py):
## each monster in the meadow's light at the game camera's pitch, idle / mid-attack /
## close-up / back, saved as <outdir>/<id>_<mode>.png (600 px squares).
##   godot --rendering-driver opengl3 --path . res://tests/tools/remaster_review.tscn -- <outdir> [orig|new] [id,id,...]
## "orig" renders the original models (MonsterVisual.use_remaster off).
const IDS := [&"pink_slime", &"green_slime", &"wild_chicken", &"yellow_frog", &"mush_baby", &"cactus_hat", &"mush_king"]


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
	var ids: Array = IDS
	if args.size() > 2:
		ids = Array(args[2].split(","))
	for id in ids:
		var t: Dictionary = MonsterData.get_monster(StringName(id))
		var v := CelestialDragonVisual.make(self, t)
		var h := float(t.height)
		for mode in ["idle", "attack", "close", "back"]:
			v.rotation_degrees.y = 25.0 if mode != "back" else 155.0
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
