extends Node
## Isolated native gameplay exercise. Never a claim about physical iPhone FPS.
var main: Node
var checks := 0
var failures := 0
const OUTPUT := "/workspace/toon-artifacts/divine-200-093/playtest"

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ", note)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	InputSetup.ensure_defaults()
	GameSettings.quality = 2
	get_window().size = Vector2i(1280,720)
	get_window().content_scale_size = Vector2i(1280,720)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.new_profile(&"warrior", "ผู้พิทักษ์บัวดารา", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.paragon = {"level":200,"exp":0,"points":0,"spent":200,"alloc":{"atk":60,"hp":60,"def":60,"haste":20}}
	Game.profile.attrs = {"str":400,"int":0,"dex":150,"vit":150}
	for slot in DivineGearData.SLOTS: Game.profile.equip[slot] = DivineGearData.item(&"warrior", slot, Game.rng)
	Game.profile.equip.wings = StarWingData.item("warrior", Game.rng, 4)
	for slot in ["ring","amulet"]: Game.profile.equip[slot] = StarProgression.item(&"warrior", 200, slot, Game.rng)
	Game.fill_loadout()
	Game.profile.loadout = ["lionfang_cleave","crown_breaker","royal_vanguard","celestial_swordfall"]
	Game.fill_loadout()
	await main.go(DivineRegionData.ID, true, true)
	check(Game.current_zone == DivineRegionData.ID, "actual travel reaches sanctuary")
	check(main.zone._camps.size() == 4, "four actual populated camps")
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 300000
	Game.profile.hp = int(hero.stats.max_hp)
	Game.profile.mp = int(hero.stats.max_mp)
	main.zone.camera_rig.yaw = 0.0
	main.zone.camera_rig.pitch_degrees = -26.0
	main.zone.camera_rig._target_distance = 10.0
	main.zone.camera_rig._apply_rotation()
	await get_tree().create_timer(1.0).timeout
	await shot("arrival")
	hero.global_position = Vector3(0,0.3,-16)
	main.zone.camera_rig.snap_to_target()
	main.zone._boss_timer = 0.0
	main.zone._tick_boss(1.0)
	await get_tree().create_timer(0.6).timeout
	var boss: Mob = main.zone._boss
	check(is_instance_valid(boss) and boss.monster_id == &"lotus_seraph", "actual divine boss spawns")
	hero.set_target(boss)
	boss._victim = hero
	boss.hostile = true
	await shot("boss-court")
	boss._begin_slam()
	await get_tree().create_timer(0.5).timeout
	await shot("boss-warning")
	await get_tree().create_timer(2.0).timeout
	hero.use_skill(3)
	await get_tree().create_timer(1.8).timeout
	await shot("swordfall")
	await get_tree().create_timer(4.0).timeout
	check(boss.hp < boss.max_hp, "uploaded sword ultimate damages actual boss")
	var before_kills := int(Game.profile.kills)
	boss.take_hit(boss.max_hp + 1, false, Color.WHITE, hero)
	await get_tree().create_timer(0.2).timeout
	check(int(Game.profile.kills) == before_kills + 1, "boss death updates player progression")
	var loot_count := 0
	for drop in get_tree().get_nodes_in_group("loot"):
		if DivineGearData.is_item(drop.item): loot_count += 1
	check(loot_count == 2, "boss drops two physical uploaded equipment pickups")
	await shot("boss-loot")
	# A short real-time workload includes combat, respawn, pickups,
	# costume skinning, HUD updates and saves, using this isolated QA profile.
	hero.global_position = Vector3(-23,0.3,20)
	hero.set_auto(true)
	var samples: Array[Dictionary] = []
	for sample in 5:
		for i in 10:
			await get_tree().create_timer(1.0).timeout
			Game.profile.hp = int(hero.stats.max_hp)
			Game.profile.mp = int(hero.stats.max_mp)
		var row := {"seconds":(sample+1)*10,"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"staticBytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"drawCalls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),"triangles":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"kills":int(Game.profile.kills)-before_kills}
		samples.append(row)
		print("DIVINE HUNT: ", JSON.stringify(row))
		if sample == 0: await shot("field-combat")
	check(Game.save_code_roundtrip(), "post-hunt profile saves and transfers")
	var report := FileAccess.open(OUTPUT + "/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(), "physical_iphone_tested":false, "samples":samples, "checks":checks, "failures":failures}, "\t"))
	# Travel away and back verifies that meshes, warnings and corpse effects are
	# tied to their owning zone and that the new route remains usable.
	await main.go(&"town", true, true)
	await main.go(DivineRegionData.ID, true, true)
	check(Game.current_zone == DivineRegionData.ID, "repeat travel still works")
	check(main.zone.find_child("LotusSanctumArt",true,false) != null, "new region rebuilds after travel")
	Game.has_profile = false
	print("DIVINE PLAYTEST: ", checks, " checks, ", failures, " failures")
	get_tree().quit(failures)
