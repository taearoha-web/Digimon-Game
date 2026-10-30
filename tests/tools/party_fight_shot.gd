extends Node
## One screenshot of a mage with a full party of four fighting a pack in the meadow, to
## look at how readable the middle of the screen is (damage numbers, name labels, the
## hero's gold ring).
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/tools/party_fight_shot.tscn -- <out_dir> [width] [height]
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var w := int(args[1]) if args.size() > 1 else 1600
	var h := int(args[2]) if args.size() > 2 else 736
	get_window().size = Vector2i(w, h)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"mage", "ทดสอบ")
	Game.profile["level"] = 20
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	var i := 0
	while Game.world_party.size() < Game.PARTY_MAX and i < WorldPlayers.size():
		Game.party_invite(i * 7 % WorldPlayers.size(), true)
		i += 1
	await main.go(&"meadow", true)
	await get_tree().create_timer(1.5).timeout
	var hero: Hero = main.zone.hero
	# A pack right in front of the hero (tough, so it lasts the whole shot).
	var pack: Array[Mob] = []
	for k in 5:
		var mob := Mob.new()
		var at := hero.global_position + Vector3(-2.0 + k, 0, -3.0 - (k % 2) * 1.2)
		mob.setup(&"pink_slime", 3, at, hero)
		mob.position = at + Vector3(0, 0.3, 0)
		main.zone.add_child(mob)
		mob.hp = 9999999
		mob.max_hp = 9999999
		pack.append(mob)
	for c in main.zone.companions:
		if is_instance_valid(c):
			c.global_position = hero.global_position + Vector3(randf_range(-2.5, 2.5), 0.3, randf_range(-1.0, 1.0))
	hero.target = pack[2]
	# The fight runs a few seconds; the hero's own hits land on the middle one.
	for i in 16:
		await get_tree().create_timer(0.25).timeout
		Game.profile.hp = hero.stats.max_hp
		if i % 2 == 0:
			pack[2].take_hit(380 + i * 3, i % 4 == 0)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/party_fight_%dx%d.png" % [out_dir, w, h])
	var labels := 0
	for n in main.zone.find_children("*", "Label3D", true, false):
		if n.has_meta(&"other"):
			labels += 1
	print("SHOT party %d | others' numbers alive %d" % [main.zone.companions.size(), labels])
	get_tree().quit()
