extends Node
## Web only: a Lv.100 summoner auto-hunts in a star region and prints the engine's
## wasm heap, video memory and object counts every 30 s, the numbers an iPhone
## session report shows. ?zone=crystal_valley&n=600&class=summoner
## Run: copy this scene to probe/ (tests/* is excluded from exports), set
## run/main_scene to it, export Web to build/probe, then
##   node tests/tools/web_probe.mjs build/probe "zone=crystal_valley&n=600" 900
var main: Node


func _ready() -> void:
	var query := String(JavaScriptBridge.eval("location.search")) if OS.has_feature("web") else ""
	var zone_id := &"crystal_valley"
	var family := &"summoner"
	var seconds := 600.0
	for pair in query.trim_prefix("?").split("&"):
		var kv := pair.split("=")
		if kv.size() != 2: continue
		match kv[0]:
			"zone": zone_id = StringName(kv[1])
			"class": family = StringName(kv[1])
			"n": seconds = float(kv[1])
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	Game.delete_save()
	Game.new_profile(family, "Probe", FaceKit.default_look())
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.paragon().level = 200
	for skill in ClassData.pool(family):
		Game.profile.skills[String(skill.id)] = 5
	for slot in ["weapon", "armor", "helm", "boots", "amulet", "ring"]:
		Game.profile.equip[slot] = StarProgression.item(family, 200, slot, Game.rng)
	Game.fill_loadout()
	if family == &"summoner":
		Game.profile.loadout = ["fairy_spirit", "primal_legion", "elder_dragon", "cataclysm", "sylvan_ray", "spirit_link", "alpha_wolves", "ancient_treant"]
	await main.go(zone_id, true)
	await get_tree().create_timer(0.5).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	hero.set_auto(true)
	hero._invulnerable_until = Time.get_ticks_msec() + int(seconds * 1000.0) + 5000
	Engine.time_scale = 2.0
	var t := 0.0
	var next_report := 0.0
	var kills0 := int(Game.profile.kills)
	while t < seconds:
		await get_tree().create_timer(0.5).timeout
		t += 1.0
		if not is_instance_valid(hero) or hero != zone.hero:
			hero = zone.hero
			if is_instance_valid(hero):
				hero.set_auto(true)
		if is_instance_valid(hero):
			Game.profile.hp = int(hero.stats.max_hp)
			Game.profile.mp = int(hero.stats.max_mp)
		if t >= next_report:
			next_report += 30.0
			print("PROBE t=%4.0fs kills=%d nodes=%d objects=%d resources=%d static=%.1fMB vram=%.1fMB wasm=%s fps=%d mobs=%d summons=%d" % [t, int(Game.profile.kills) - kills0,
				int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				str(JavaScriptBridge.eval("typeof engine !== 'undefined' && engine.rtenv && engine.rtenv.HEAPU8 ? engine.rtenv.HEAPU8.byteLength : -1")),
				Engine.get_frames_per_second(), get_tree().get_nodes_in_group("mobs").size(), get_tree().get_nodes_in_group("summons").size()])
	print("PERF done")
	get_tree().quit()
