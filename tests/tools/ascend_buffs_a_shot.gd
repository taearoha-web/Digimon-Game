extends Node3D
## One picture of two ★500 buffs: the archer hero standing still with ลมหายใจนักล่า's shot
## readied (AscendBuffs.ReadyCue: the reticle over its head, the ring at its feet) beside a
## warrior companion under โลหิตราชันเดือด's aura (BuffAura).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . \
##     res://tests/tools/ascend_buffs_a_shot.tscn -- OUT.png


func _ready() -> void:
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ascend_buffs_a.png"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("cfeaff")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.97, 1.0)
	e.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	sun.light_energy = 0.95
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = MeshKit.toon(Color("9fdc8c"))
	add_child(ground)
	Game.new_profile(&"archer", "Hawk", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	var hero := Hero.new()
	hero.field = self
	add_child(hero)
	hero.position = Vector3(-1.4, 0, 0)
	hero.set_physics_process(false)
	hero.refresh_stats()
	var hawk := ClassData.find_skill(&"archer", "zenith_hawkeye")
	hero.receive_buff(hawk.fx.buff, hawk.color, hawk.name, false, hawk.id)
	var buddy := Companion.new()
	buddy.setup({"class": "warrior", "name": "Warrior", "level": 100, "exp": 0, "gender": 0}, 0, hero, self)
	add_child(buddy)
	buddy.position = Vector3(1.4, 0, 0)
	buddy.set_physics_process(false)
	var blood := ClassData.find_skill(&"warrior", "sovereign_awakening")
	buddy._apply_self(blood)
	var cam := Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.position = Vector3(0, 2.6, 7.2)
	cam.look_at(Vector3(0, 1.3, 0))
	await get_tree().process_frame
	for i in 6:
		AscendBuffs.tick(hero, 0.25)
	for i in 90:
		await get_tree().process_frame
		hero._sync_auras(Time.get_ticks_msec())
		buddy._book.tick(buddy, true, func(): return BuffAura.measure_top(buddy.visual, buddy))
		hero.visual.play("Idle")
		buddy.visual.play("Idle")
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("ASCEND BUFFS A SHOT: primed %s -> %s" % [AscendBuffs.primed(hero), out])
	get_tree().quit()
