extends Node
## Memory soak: auto-hunts in a field for a while and prints object/node counts.
##   godot --headless --path . res://tests/tools/soak.tscn -- zone seconds [class]
## With a class, the hero is Lv.100 adv 4 with the class's top loadout (a summoner's
## includes fairy_spirit, primal_legion and elder_dragon).
var main: Node

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	var args := OS.get_cmdline_user_args()
	var zone_id := StringName(args[0]) if args.size() > 0 else &"meadow"
	var seconds := float(args[1]) if args.size() > 1 else 120.0
	var family := StringName(args[2]) if args.size() > 2 else &"warrior"
	Game.delete_save()
	Game.new_profile(family, "soak", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile["level"] = 40 if args.size() <= 2 else 100
	Game.profile["adv"] = 2 if args.size() <= 2 else 4
	if args.size() > 2:
		Game.paragon().level = 200
		for skill in ClassData.pool(family):
			Game.profile.skills[String(skill.id)] = 5
		for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
			Game.profile.equip[slot] = StarProgression.item(family, 200, slot, Game.rng)
	Game.fill_loadout()
	if family == &"summoner":
		Game.profile.loadout = ["fairy_spirit", "primal_legion", "elder_dragon", "cataclysm", "sylvan_ray", "spirit_link", "alpha_wolves", "ancient_treant"]
	await main.go(&"town", true)
	await get_tree().create_timer(0.5).timeout
	await main.go(&"meadow" if zone_id == &"all" else zone_id, true)
	await get_tree().create_timer(0.5).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	if not zone._camps.is_empty():
		var camp: Dictionary = zone._camps[0]
		hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y)
	hero.set_auto(true)
	hero._invulnerable_until = Time.get_ticks_msec() + int(seconds * 1000.0) + 5000
	Engine.time_scale = 3.0
	if zone_id == &"all":
		for id in [&"meadow", &"dark_forest", &"desert", &"snow", &"volcano", &"graveyard", &"swamp", &"storm", &"sky", &"abyss", &"meadow", &"abyss", &"town", &"swamp"]:
			Game.profile["level"] = 100
			await main.go(id, true)
			await get_tree().create_timer(1.5).timeout
			print("zone %s nodes=%d objects=%d resources=%d static=%.1fMB vram=%.1fMB" % [id, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		get_tree().quit()
		return
	var t := 0.0
	var next_report := 0.0
	var kills0 := int(Game.profile.kills)
	while t < seconds:
		await get_tree().create_timer(0.5).timeout
		t += 0.5 * 3.0
		if not is_instance_valid(hero) or hero != zone.hero:
			hero = zone.hero
			if is_instance_valid(hero):
				hero.set_auto(true)
		if is_instance_valid(hero):
			Game.profile.hp = int(hero.stats.max_hp)
			Game.profile.mp = int(hero.stats.max_mp)
		if t >= next_report:
			next_report += 30.0
			print("t=%4.0fs kills=%d nodes=%d objects=%d resources=%d orphan=%d static=%.1fMB vram=%.1fMB loot=%d mobs=%d summons=%d" % [t, int(Game.profile.kills) - kills0,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				get_tree().get_nodes_in_group("loot").size(), get_tree().get_nodes_in_group("mobs").size(), get_tree().get_nodes_in_group("summons").size()])
	Engine.time_scale = 1.0
	get_tree().quit()
