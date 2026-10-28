extends Node
## Casts every skill of a class one by one in a field and watches each frame for the
## "flat screen" (the whole view one colour): prints the skill, the frame and any
## visible effect with a non-finite or huge transform at that moment.
##   godot --rendering-driver opengl3 --resolution 800x368 --path . res://tests/tools/flat_frame_probe.tscn -- darklord 64 swamp
var flats := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cls := StringName(args[0]) if args.size() > 0 else &"darklord"
	var level := int(args[1]) if args.size() > 1 else 64
	var field := StringName(args[2]) if args.size() > 2 else &"swamp"
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(cls, "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile.level = level
	Game.profile.adv = JobData.adv_for_level(level)
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = ItemData.generate(level, cls, Game.rng, 3, slot)
	for skill in ClassData.pool(cls):
		Game.profile.skills[String(skill.id)] = 5
	await main.go(field, true)
	await get_tree().create_timer(1.0).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 3600000
	var camp: Dictionary = zone._camps[0]
	hero.global_position = Vector3(camp.pos.x + 3.0, 0.2, camp.pos.y)
	await get_tree().create_timer(0.5).timeout
	var skills: Array = Game.class_data().skills
	for round in 2:
		for skill in skills:
			if not skill.has("id") or int(skill.get("level", 1)) > level:
				continue
			hero.cooldowns.clear()
			hero._cast_until = 0
			Game.profile.mp = 99999
			Game.profile.hp = int(hero.stats.max_hp)
			hero.set_target(hero.nearest_mob())
			hero._cast(skill)
			print("CAST %s" % skill.id)
			for f in 60:
				await RenderingServer.frame_post_draw
				if f % 2 == 0:
					_check(String(skill.id), f, hero)
	print("FLAT PROBE: %d flat frames" % flats)
	get_tree().quit()


func _check(id: String, frame: int, hero: Hero) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(40, 18, Image.INTERPOLATE_NEAREST)
	var sum := Color(0, 0, 0)
	var sq := 0.0
	var n := 0
	# Ignore the HUD: sample the middle band only.
	for y in range(5, 13):
		for x in range(8, 32):
			var c := img.get_pixel(x, y)
			sum += Color(c.r, c.g, c.b)
			n += 1
	var mean := Color(sum.r / n, sum.g / n, sum.b / n)
	for y in range(5, 13):
		for x in range(8, 32):
			var c := img.get_pixel(x, y)
			sq += pow(c.r - mean.r, 2) + pow(c.g - mean.g, 2) + pow(c.b - mean.b, 2)
	var spread := sqrt(sq / n)
	var cam := get_viewport().get_camera_3d()
	if spread < 0.012 or not cam.global_position.is_finite():
		flats += 1
		print("FLAT skill=%s frame=%d spread=%.4f cam=%s hero=%s" % [id, frame, spread, cam.global_position, hero.global_position])
		for node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
			var g := node as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var t := g.global_transform
			var big := maxf(t.basis.x.length(), maxf(t.basis.y.length(), t.basis.z.length()))
			if not t.origin.is_finite() or not is_finite(big) or big > 40.0 or (g.get_aabb().size * big).length() > 400.0:
				print("   suspect %s scale=%.1f aabb=%s at=%s" % [g.get_path(), big, g.get_aabb().size, t.origin])
