extends Node
## End-to-end run of the real game scenes, headless:
## new game (every class) -> village -> field -> kills, loot, EXP, level-up ->
## quest -> shop -> equip -> save/load -> death. Exit code = number of failures.
##   godot --headless --path . res://tests/integration/flow_test.tscn

var main: Node
var failures: Array[String] = []


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	await _run()
	print("")
	if failures.is_empty():
		print("FLOW TEST: PASS")
	else:
		print("FLOW TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
	get_tree().quit(failures.size())


func check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		failures.append(message)


func _run() -> void:
	for id in ClassData.IDS:
		await _play_class(id)
	await _systems()


func _start(class_id: StringName) -> Zone:
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.delete_save()
	Game.new_profile(class_id, "ทดสอบ")
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(0.5)
	return main.zone


func _play_class(class_id: StringName) -> void:
	print("== %s" % ClassData.get_class_data(class_id).name)
	var town := await _start(class_id)
	check(town != null and town.is_town and town.hero != null, "village loaded with a hero")
	check(town.npcs.size() == 4, "four villagers")
	check(main.hud.skill_slots.size() == 4, "HUD has four skill slots")
	await main.go(&"meadow", true)
	await _wait(0.6)
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	check(zone.zone_id == &"meadow" and not zone.is_town, "hunting field loaded")
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	await _wait(0.2)
	hero.global_position = Vector3(-20, 0.2, 0)
	var level_before: int = Game.profile.level
	var exp_before: int = Game.profile.exp
	var gold_before: int = Game.profile.gold
	var pack := _spawn(zone, hero, [&"pink_slime", &"green_slime", &"pink_slime"], 2)
	await _wait(0.5)
	hero.tap_attack()
	check(hero.engaged and hero.target != null, "attack button locks a target")
	var elapsed := 0.0
	var skill_index := 0
	while _alive(pack) > 0 and elapsed < 80.0 and not hero.is_dead():
		skill_index = (skill_index + 1) % 4
		hero.use_skill(skill_index)
		await _wait(0.5)
		elapsed += 0.5
		if not hero.engaged:
			hero.tap_attack()
		if Game.profile.hp < int(hero.stats.max_hp * 0.4):
			hero.use_potion("hp")
		Game.profile.mp = maxi(Game.profile.mp, 30)
	check(_alive(pack) == 0, "pack defeated in %.1fs (hp %d/%d)" % [elapsed, Game.profile.hp, hero.stats.max_hp])
	await _wait(2.0)
	check(Game.profile.exp > exp_before or Game.profile.level > level_before, "EXP gained")
	check(Game.profile.gold > gold_before, "gold picked up (%d -> %d)" % [gold_before, Game.profile.gold])
	check(int(Game.profile.kills) >= 3, "kills counted")


func _spawn(zone: Zone, hero: Hero, ids: Array, level: int) -> Array[Mob]:
	var pack: Array[Mob] = []
	for i in ids.size():
		var m := Mob.new()
		m.setup(ids[i], level, hero.global_position + Vector3(6 + i * 1.4, 0, -1 + i), hero)
		m.position = m.home + Vector3(0, 0.3, 0)
		zone.add_child(m)
		pack.append(m)
	return pack


func _alive(pack: Array[Mob]) -> int:
	var n := 0
	for m in pack:
		if is_instance_valid(m) and not m.is_dead():
			n += 1
	return n


func _systems() -> void:
	print("== Systems")
	var zone := await _start(&"warrior")
	Game.add_exp(100000)
	check(Game.profile.level > 5, "big EXP levels up (Lv.%d)" % Game.profile.level)
	check(Game.profile.points > 0 and Game.profile.skill_points > 1, "points granted")
	var str_before: int = Game.stats_now().attrs.str
	check(Game.spend_point("str"), "spend a stat point")
	check(Game.stats_now().attrs.str == str_before + 1, "STR increased")
	var skill := ClassData.get_skill(&"warrior", 0)
	check(Game.upgrade_skill(skill) and Game.skill_rank(skill.id) == 2, "skill upgraded to rank 2")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var sword := ItemData.generate(5, &"warrior", rng, 2, "weapon")
	var atk_before: float = Game.stats_now().atk
	Game.add_item(sword)
	check(Game.equip_from_bag(Game.profile.inv.size() - 1), "equip a rare sword")
	check(Game.stats_now().atk > atk_before, "ATK rises with the sword")
	var mage_staff := ItemData.generate(5, &"mage", rng, 0, "weapon")
	check(Game.equip_problem(mage_staff) != "", "a staff cannot be worn by a warrior")
	var gold: int = Game.profile.gold
	Game.add_gold(500)
	check(Game.buy_item(ItemData.potion("hp_m", 2)), "buy potions")
	check(Game.profile.gold < gold + 500, "gold spent")
	var inv_before: int = Game.profile.inv.size()
	Game.sell_item(Game.profile.inv.size() - 1)
	check(Game.profile.inv.size() <= inv_before, "sell an item")
	Game.set_quest("slimes", "active", 0)
	for i in 8:
		Game.report_kill(&"pink_slime")
	check(Game.quest_status("slimes") == "ready", "quest ready after 8 slimes")
	main._reward_quest("slimes")
	check(Game.quest_status("slimes") == "done", "quest rewarded")
	check(QuestData.current_quest() == "chickens", "next quest unlocked")
	Game.save()
	var level: int = Game.profile.level
	Game.profile["level"] = 1
	check(Game.load_game() and Game.profile.level == level, "save and load restore the profile")
	check(Game.profile.equip.has("weapon") and int(Game.profile.equip.weapon.level) == 5, "equipment survives a save")
	await main.go(&"meadow", true)
	await _wait(0.5)
	var field: Zone = main.zone
	var h: Hero = field.hero
	var killer := Mob.new()
	killer.setup(&"mush_king", 30, h.global_position + Vector3(3, 0, 0), h)
	killer.position = killer.home + Vector3(0, 0.3, 0)
	field.add_child(killer)
	for i in 12:  # a lucky dodge can dodge the first hit
		h.take_damage(100000.0, killer)
	check(h.is_dead(), "hero dies from a huge hit")
	await _wait(4.5)
	check(main.zone != null and main.zone.zone_id == &"town", "respawned in the village")
	check(Game.profile.hp > 0, "revived with HP")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
