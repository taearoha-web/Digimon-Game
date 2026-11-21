extends Node
## Screenshots of the Muay Thai fighter (นักมวยประเจียด): standing in the village with
## its mantra rings orbiting (Lv.95: six rings), in a fight in the meadow throwing its
## skills, and its hand wraps on every chibi body (and the KayKit body) side by side.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . res://tests/tools/muaythai_shots.tscn -- <out_dir> [town|fight|bodies|all]
var main: Node
var out_dir := ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("SHOT ", name)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://shots"
	var mode := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	GameSettings.load_settings()
	GameSettings.quality = 2
	if mode == "bodies":
		await _bodies()
		get_tree().quit()
		return
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	Game.new_profile(&"muaythai", "สิงห์มวย")
	Game.profile["level"] = 95
	Game.profile["adv"] = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	Game.profile.equip["weapon"] = ItemData.generate(95, &"muaythai", rng, 3, "weapon")
	Game.profile.equip["armor"] = ItemData.generate(95, &"muaythai", rng, 3, "armor")
	Game.fill_loadout()
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.playing = true
	if mode in ["town", "all"]:
		await main.go(&"village", true)
		await get_tree().create_timer(2.5).timeout
		await _shot("muaythai_town")
	if mode in ["fight", "all"]:
		await main.go(&"meadow", true)
		await get_tree().create_timer(1.5).timeout
		var hero: Hero = main.zone.hero
		var pack: Array[Mob] = []
		for k in 5:
			var mob := Mob.new()
			var at := hero.global_position + Vector3(-2.4 + k * 1.2, 0, -3.0 - (k % 2) * 1.2)
			mob.setup(&"pink_slime", 3, at, hero)
			mob.position = at + Vector3(0, 0.3, 0)
			main.zone.add_child(mob)
			mob.hp = 9999999
			mob.max_hp = 9999999
			pack.append(mob)
		hero.target = pack[2]
		hero.global_position = pack[2].global_position + Vector3(0, 0.3, 2.4)
		await get_tree().create_timer(1.0).timeout
		var shots := [["mantra_storm", 2], ["fire_dragon_circle", 5], ["muay_king", 7]]
		var bar: Array = Game.class_data().skills
		var k := 0
		for s in shots:
			for i in bar.size():
				if String((bar[i] as Dictionary).get("id", "")) == String(s[0]):
					Game.profile.mp = 99999
					hero.cooldowns.clear()
					hero._cast_until = 0
					hero.use_skill(i)
					hero._physics_process(0.016)
					break
			await get_tree().create_timer(0.55).timeout
			Game.profile.hp = hero.stats.max_hp
			k += 1
			await _shot("muaythai_fight_%d_%s" % [k, s[0]])
			await get_tree().create_timer(0.6).timeout
	get_tree().quit()


## Every body in its wraps (Lv.95 tier, a star pair and the divine pair) in the guard stance.
func _bodies() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.97, 1.0)
	e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 20, 0)
	add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("9fdc8c"))
	add_child(ground)
	var looks: Array = []
	for gender in 2:
		for body in ChibiBodies.count(gender):
			looks.append({"gender": gender, "body": body})
	looks.append({})
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var weapons := [ItemData.generate(5, &"muaythai", rng, 1, "weapon"), ItemData.generate(95, &"muaythai", rng, 3, "weapon")]
	var star := StarGearData.catalogue().filter(func(i): return String(i.class) == "muaythai" and String(i.slot) == "weapon" and int(i.star_tier) == 200)[0]
	weapons.append(star)
	weapons.append(DivineGearData.item(&"muaythai", "weapon", rng))
	var camera := Camera3D.new()
	camera.fov = 30
	add_child(camera)
	for clip_index in 2:
		var row: Array = []
		for i in looks.size():
			var v := HeroVisual.new()
			add_child(v)
			v.setup(&"muaythai", "", true, {"weapon": weapons[i % weapons.size()]}, looks[i])
			v.set_mantra_level(30 + 30 * (i % 3))
			v.position = Vector3((float(i) - float(looks.size() - 1) * 0.5) * 1.6, 0, 0)
			v.rotation.y = 0.35
			v.play("Idle" if clip_index == 0 else "Running_A")
			row.append(v)
		camera.position = Vector3(0, 2.0, 11.5)
		camera.look_at(Vector3(0, 0.9, 0))
		await get_tree().create_timer(0.8).timeout
		await _shot("muaythai_bodies_%s" % ("guard" if clip_index == 0 else "run"))
		# A close-up of the fists on the first two bodies.
		camera.position = Vector3(-6.4, 1.3, 3.4)
		camera.look_at(Vector3(-6.4, 0.95, 0))
		await get_tree().create_timer(0.2).timeout
		await _shot("muaythai_fists_%s" % ("guard" if clip_index == 0 else "run"))
		for v in row:
			v.queue_free()
		await get_tree().process_frame
