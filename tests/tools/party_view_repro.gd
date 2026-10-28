extends Node
## A Vagabond in the meadow with a world player of the given class in the party:
## shots at 3 s and 8 s, and whether the camera and the hero stay finite.
##   godot --rendering-driver opengl3 --resolution 2000x921 --path . res://tests/tools/party_view_repro.tscn -- OUT_DIR CLASS [ZONE]
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var cls := StringName(args[1])
	var zone_id := StringName(args[2]) if args.size() > 2 else &"meadow"
	DirAccess.make_dir_recursive_absolute(out)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(&"vagabond", "Wardermor", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile.level = 6
	var who := WorldPlayers.first_of(cls)
	if args.size() > 4:
		for i in WorldPlayers.ROSTER.size():
			if String(WorldPlayers.ROSTER[i].name) == args[4]:
				who = i
	Game.party_invite(who, true)
	# The member as a fresh Lv.5 (how it looked when it joined early in the world's life).
	if args.size() > 3:
		Game._party_members[who]["level"] = int(args[3])
		Game._party_members[who]["stars"] = 0
		Game._party_members[who]["frac"] = 0.0
		Game._party_members[who]["divine_frac"] = 0.0
	await main.go(zone_id, true)
	var hero: Hero = main.zone.hero
	hero.set_auto(true)
	for k in 2:
		await get_tree().create_timer(3.0 if k == 0 else 5.0).timeout
		var cam := get_viewport().get_camera_3d()
		print("t=%d cam=%s hero=%s finite=%s" % [k, str(cam.global_position), str(hero.global_position), str(cam.global_position.is_finite() and hero.global_position.is_finite())])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, cls, k])
	get_tree().quit()
