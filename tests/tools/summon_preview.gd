extends Node3D
## A summoner hero seen from the game camera with the given summon kinds beside him,
## rendered a few times over a span so a wandering summon (the fairy's orbit) leaves a
## visible path. Prints each summon's distance to the hero and whether it stands
## between the camera and the hero.
## HEAL=1 times the fairy's heal so the second frame catches her twirl.
##   godot --rendering-driver opengl3 --path . res://tests/tools/summon_preview.tscn -- OUT_DIR [KINDS=fairy] [FRAMES=4] [SPAN=6.0] [VIEW town|field] [STARS=3] [HEAL=0]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var kinds := (args[1] if args.size() > 1 else "fairy").split(",")
	var frames := int(args[2]) if args.size() > 2 else 4
	var span := float(args[3]) if args.size() > 3 else 6.0
	var view := args[4] if args.size() > 4 else "town"
	var stars := int(args[5]) if args.size() > 5 else 3
	var heal := args.size() > 6 and args[6] == "1"
	GameSettings.load_settings()
	GameSettings.quality = 2
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("8ed0ff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 1.0; add_child(l)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); g.mesh = pm
	g.material_override = MeshKit.toon(Color("6fbf5f")); add_child(g)
	var floor_body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(80, 1, 80)
	cs.shape = bs; floor_body.add_child(cs); floor_body.position.y = -0.5; add_child(floor_body)
	Game.set_process(false)
	Game.new_profile(&"summoner", "t")
	Game.profile.level = 90
	Game.profile.hp = 5000
	var hero := Hero.new()
	add_child(hero)
	hero.field = self
	hero.refresh_stats()
	hero.global_position = Vector3(0, 0.2, 0)
	hero.set_facing(PI * 0.5)
	# The game camera as world/zone.gd builds it: behind the hero, town framing by default.
	var rig := ThirdPersonCamera.new()
	rig.target = hero
	if view == "field":
		rig.pitch_degrees = -47.0; rig.min_pitch = -56.0; rig.max_pitch = -38.0
		rig.distance = 22.0; rig.min_distance = 14.0; rig.max_distance = 32.0
		rig.height_offset = 0.9; rig.base_fov = 40.0
	else:
		rig.pitch_degrees = -22.0; rig.distance = 8.0; rig.max_distance = 15.0; rig.height_offset = 1.5
	add_child(rig)
	rig.add_excluded_body(hero)
	rig.set_yaw_behind(PI * 1.5)
	rig.snap_to_target()
	hero.camera_rig = rig
	var summons: Array[Summon] = []
	for i in kinds.size():
		var skill := _skill_for(String(kinds[i]))
		var spec: Dictionary = skill.get("summon", {"kind": kinds[i], "count": 1, "secs": 120.0, "interval": 1.0})
		var s := Summon.new()
		s.setup(hero, String(skill.get("id", "fairy_spirit")), spec, 1.0, i, kinds.size(), stars)
		add_child(s)
		if heal and s.is_fairy():
			s._heal_timer = 0.8 + span / float(maxi(frames - 1, 1)) - 0.3
		summons.append(s)
	await get_tree().create_timer(0.8).timeout
	for frame in frames:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/summons_%d.png" % [out_dir, frame])
		var cam := rig.camera.global_position
		for s in summons:
			var flat := s.global_position - hero.global_position
			flat.y = 0.0
			var toward_cam := cam - hero.global_position
			toward_cam.y = 0.0
			var ahead := flat.normalized().dot(toward_cam.normalized())
			print("frame %d %s: %.2f m from the hero, camera-side dot %.2f (%s), body y %.2f" % [frame, s._kind_id, flat.length(), ahead, "between camera and hero" if ahead > 0.3 else "clear", s._visual.position.y if s._visual else 0.0])
		if frame < frames - 1:
			await get_tree().create_timer(span / float(frames - 1)).timeout
	get_tree().quit()


## The summoner skill that calls [param kind], so the summon gets its real spec and crest.
static func _skill_for(kind: String) -> Dictionary:
	for cls in ClassData.CLASSES:
		for skill in ClassData.pool(cls):
			if String(skill.get("summon", {}).get("kind", "")) == kind:
				return skill
	return {}
