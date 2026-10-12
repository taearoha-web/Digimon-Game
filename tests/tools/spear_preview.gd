extends Node3D
## Lancer spear hold sheet: one hero per clip, three camera angles.
##   godot --rendering-driver opengl3 --path . res://tests/tools/spear_preview.tscn -- <out_prefix> [tier]
const CLIPS := [["Idle", 0.3], ["Running_A", 0.2], ["2H_Melee_Idle", 0.3], ["2H_Melee_Attack_Stab", 0.25], ["2H_Melee_Attack_Slice", 0.3], ["Martial_SpearThrow", 0.5]]

func _ready() -> void:
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color("9fd3f0")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.9, 0.95, 1.0); e.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = e; add_child(we)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45, 30, 0); l.light_energy = 0.7; add_child(l)
	var args := OS.get_cmdline_user_args()
	var tier := int(args[1]) if args.size() > 1 else 5
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var heroes: Array = []
	for i in CLIPS.size():
		var equip := {"weapon": ItemData.generate(tier * 10 + 5, &"lancer", rng, 1, "weapon")}
		var h := HeroVisual.new(); add_child(h); h.setup(&"lancer", "", true, equip)
		h.position = Vector3(-6.25 + i * 2.5, 0, 0)
		heroes.append(h)
	await get_tree().create_timer(0.5).timeout
	for i in CLIPS.size():
		var h: HeroVisual = heroes[i]
		var clip: String = CLIPS[i][0]
		if h.anim.has_animation(clip):
			h.anim.play(clip); h.anim.seek(float(CLIPS[i][1]) * h.anim.current_animation_length, true); h.anim.pause()
		else:
			print("missing clip ", clip)
	get_window().size = Vector2i(400, 400)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 34
	for i in heroes.size():
		for j in heroes.size():
			(heroes[j] as Node3D).visible = i == j
		var h: Node3D = heroes[i]
		for view in [["front", Vector3(0, 1.0, 5.2), -6.0, 25.0], ["side", Vector3(0, 1.0, 5.2), -6.0, 90.0], ["top", Vector3(0, 5.5, 0.01), -90.0, 0.0]]:
			h.rotation_degrees.y = float(view[3])
			cam.position = h.position + (view[1] as Vector3); cam.rotation_degrees = Vector3(float(view[2]), 0, 0)
			for f in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s_%d_%s.png" % [args[0], i, view[0]])
	get_tree().quit()
