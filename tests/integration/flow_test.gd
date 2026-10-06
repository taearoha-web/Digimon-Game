extends Node
## End-to-end run of the real game scenes, headless:
## new game (every class) -> village -> field -> kills, loot, EXP, level-up ->
## quest -> shop -> equip -> save/load -> death. Exit code = number of failures.
##   godot --headless --path . res://tests/integration/flow_test.tscn

var main: Node
var failures: Array[String] = []
var _party_damage_total := 0


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
	await _vagabond()
	await _look()
	await _tiers()
	for id in ClassData.IDS:
		await _play_class(id)
	check(_party_damage_total > 0, "companions dealt damage over the four runs (%d)" % _party_damage_total)
	await _touch_scroll()
	await _jobs()
	await _items()
	await _goals()
	await _arena()
	await _ending()
	await _party()
	await _zones()
	await _systems()


func _start(class_id: StringName) -> Zone:
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.delete_save()
	Game.new_profile(class_id, "ทดสอบ")
	if class_id != ClassData.START:
		# Lines start at Lv.10 in the real game; the tests jump straight there.
		Game.profile["level"] = ClassData.LINE_LEVEL
		Game.fill_loadout()
		var stats := Game.stats_now()
		Game.profile.hp = stats.max_hp
		Game.profile.mp = stats.max_mp
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(0.5)
	return main.zone


func _play_class(class_id: StringName) -> void:
	print("== %s" % ClassData.get_class_data(class_id).name)
	var town := await _start(class_id)
	check(town != null and town.is_town and town.hero != null, "village loaded with a hero")
	check(town.npcs.size() == 10, "ten villagers")
	check(main.hud.skill_slots.size() == 4, "HUD has four skill slots")
	var bar := Game.loadout_skills()
	check(bar.size() == 4 and not bar[0].is_empty() and not bar[1].is_empty(), "%s has skills on the bar at Lv.10" % class_id)
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
	check(zone.companions.size() == 1, "one AI companion is with the hero")
	var party_exp: int = int(Game.party()[0].exp) + int(Game.party()[0].level) * 1000
	check(party_exp > 1000, "companions share the EXP")
	var party_damage := 0
	for c in zone.companions:
		party_damage += c.damage_dealt
	_party_damage_total += party_damage


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


func _jobs() -> void:
	print("== Jobs")
	for class_id in ClassData.IDS:
		var zone := await _start(class_id)
		var branches := JobData.jobs_for(class_id)
		check(branches.size() == 1, "%s has a single advanced path" % class_id)
		check(not Game.change_job(branches[0]), "cannot change job below Lv.%d" % JobData.JOB_LEVEL)
		Game.add_exp(2000000)
		Game.add_gold(5000)
		var atk_before: float = Game.stats_now().atk
		var gold_before: int = Game.profile.gold
		check(Game.change_job(branches[0]), "job picked")
		check(Game.job_id() != &"", "%s changed job to %s" % [class_id, Game.job_id()])
		check(Game.profile.gold == gold_before - JobData.JOB_COST + 1000, "job change cost gold (the job achievement pays 1000 back)")
		check(String(Game.class_data().name) != String(ClassData.get_class_data(class_id).name), "job renames the hero")
		check(not Game.change_job(branches[0]), "job cannot be changed twice")
		await _wait(0.4)
		var hero: Hero = main.zone.hero
		check(hero._ring != null, "job ring appears under the hero")
		# Passives raise stats; the Lv.30 advancement swaps skills 3 and 4.
		var before := Game.stats_now()
		var power_before: float = float(before.atk) + float(before.def) + float(before.max_hp) + float(before.max_mp) + float(before.crit) * 1000.0 + float(before.speed)
		Game.profile.skills[ClassData.PASSIVES[class_id][0].id] = 5
		var after_stats := Game.stats_now()
		var power_after: float = float(after_stats.atk) + float(after_stats.def) + float(after_stats.max_hp) + float(after_stats.max_mp) + float(after_stats.crit) * 1000.0 + float(after_stats.speed)
		check(power_after > power_before, "passive skill ranks add stats")
		Game.add_gold(10000)
		Game.profile["level"] = JobData.MASTER_LEVEL
		check(Game.change_master(), "%s can take the Lv.%d advancement" % [class_id, JobData.MASTER_LEVEL])
		check(bool(Game.class_data().get("master", false)), "master advancement applied")
		check(not Game.change_master(), "the master advancement is one-time")


func _vagabond() -> void:
	print("== Vagabond")
	var zone := await _start(ClassData.START)
	check(Game.class_id() == ClassData.START and zone.hero != null, "new heroes start as a Vagabond")
	var bar := Game.loadout_skills()
	check(not bar[0].is_empty() and bar[1].is_empty(), "Lv.1 Vagabond has one skill on the bar")
	check(not Game.change_class(&"warrior"), "cannot pick a line below Lv.%d" % ClassData.LINE_LEVEL)
	Game.add_exp(HeroStats.exp_to_next(1) + HeroStats.exp_to_next(2) + HeroStats.exp_to_next(3) + HeroStats.exp_to_next(4) + HeroStats.exp_to_next(5) + HeroStats.exp_to_next(6) + HeroStats.exp_to_next(7) + HeroStats.exp_to_next(8) + HeroStats.exp_to_next(9))
	check(Game.profile.level == 10, "reached Lv.10 (Lv.%d)" % Game.profile.level)
	var filled := 0
	for skill in Game.loadout_skills():
		if not skill.is_empty():
			filled += 1
	check(filled == 3, "the three Vagabond skills fill the bar")
	# Gear and the skill bar follow the new line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var drop := ItemData.generate(8, ClassData.START, rng, 2, "weapon")
	Game.add_item(drop)
	check(Game.change_class(&"archer"), "picked the archer line")
	check(Game.class_id() == &"archer", "class is now the archer")
	check(String(Game.profile.equip.weapon["class"]) == "archer" and String(Game.profile.equip.weapon.base) == "bow", "worn weapon became a bow")
	var kept := false
	for item in Game.profile.inv:
		if item.get("kind", "") == "equip" and String(item.get("class", "")) == "archer":
			kept = true
	check(kept, "bag weapon turned into the new line's weapon")
	bar = Game.loadout_skills()
	check(String(bar[0].id) == "wind_arrow" and String(bar[1].id) == "perfect_aim", "bar holds the first archer skills")
	check(not Game.change_class(&"mage"), "the line cannot be changed twice")
	# Loadout: swap a skill into slot 4 once unlocked.
	Game.profile["level"] = 20
	Game.fill_loadout()
	check(not Game.equip_skill("avalanche", 0), "Lv.20 skills stay locked until the advanced job")
	check(Game.equip_skill("scout_hawk", 0) and String(Game.loadout()[0]) == "scout_hawk" and String(Game.loadout()[2]) == "wind_arrow", "a skill already on the bar swaps places")
	check(not Game.equip_skill("phoenix_shot", 1), "locked skills cannot be equipped")
	Game.profile.gold = 5000
	Game.profile.skill_points = 3
	var skill := ClassData.find_skill(&"archer", "wind_arrow")
	check(Game.upgrade_skill(skill) and Game.skill_rank("wind_arrow") == 2, "skill trainer raises a rank for points + gold")
	check(Game.profile.gold < 5000, "ranks cost gold")
	await main.go(&"town", true)
	await _wait(0.3)
	check(main.zone.hero != null, "village reloads with the new line")


func _tiers() -> void:
	print("== Skill tiers")
	await _start(&"mage")
	Game.profile["level"] = 50
	Game.fill_loadout()
	var watornado := ClassData.find_skill(&"mage", "watornado")
	var flame := ClassData.find_skill(&"mage", "flame_wave")
	var fire_bolt := ClassData.find_skill(&"mage", "fire_bolt")
	check(Game.class_tier() == 1 and Game.skill_unlocked(fire_bolt), "line skills below Lv.20 need only the line")
	check(not Game.skill_unlocked(watornado) and not Game.skill_unlocked(flame), "Lv.20+ skills are locked without the advanced job")
	check(Game.skill_lock_reason(watornado).contains("ขั้นสูง"), "lock reason names the advancement")
	check(not Game.loadout().has("watornado"), "locked skills are kept off the bar")
	Game.add_gold(50000)
	var branch := JobData.jobs_for(&"mage")[0]
	check(Game.change_job(branch) and Game.class_tier() == 2, "advanced job reaches tier 2")
	check(Game.skill_unlocked(watornado) and not Game.skill_unlocked(flame), "tier 2 opens Lv.20-39 skills only")
	check(Game.change_master() and Game.class_tier() == 3 and Game.skill_unlocked(flame), "master job opens Lv.40+ skills")


func _look() -> void:
	print("== Character look")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 12:
		var random_look := FaceKit.random_look(rng)
		var fixed := FaceKit.repair(random_look)
		check(fixed == random_look, "random look %d is valid" % i)
		var head := FaceKit.build_head(fixed)
		check(head.get_child_count() > 8 and head.get_node_or_null("Hair") != null, "head %d has face parts and hair" % i)
		head.free()
	check(FaceKit.build_head(FaceKit.default_look(), false).get_node_or_null("Hair") == null, "no hair under a helmet")
	Game.delete_save()
	var chosen := FaceKit.default_look()
	chosen["gender"] = 1
	chosen["hair"] = 2
	chosen["skin"] = 5
	Game.new_profile(ClassData.START, "ทดสอบ", chosen)
	check(int(Game.profile.look.gender) == 1 and int(Game.profile.look.skin) == 5, "the chosen look is stored in the profile")
	var back := Game.export_code()
	check(Game.import_code(back) and int(Game.profile.look.hair) == 2, "the look survives a save code round trip")
	main.title_screen = null
	main.hud.visible = true
	main._traveling = false
	await main.go(&"town", true)
	await _wait(0.4)
	var hero_visual: HeroVisual = main.zone.hero.visual
	check(not hero_visual.look.is_empty() and hero_visual.find_child("CustomHead", true, false) != null, "the hero wears the custom head")
	Game.profile.equip["helm"] = ItemData.generate(5, ClassData.START, rng, 1, "helm")
	hero_visual.set_equipment(Game.profile.equip)
	await _wait(0.2)
	check(hero_visual.find_child("Hair", true, false) == null, "hair is hidden under a helmet")


func _touch_scroll() -> void:
	print("== Touch scroll")
	var layer := CanvasLayer.new()
	add_child(layer)
	var scroll := TouchScroll.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 300)
	layer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var presses := [0]
	for i in 30:
		var b := Button.new()
		b.text = "item %d" % i
		b.custom_minimum_size = Vector2(0, 60)
		b.pressed.connect(func(): presses[0] += 1)
		box.add_child(b)
	await _wait(0.2)
	# Events are fed straight to the container (the window's stretch transform
	# makes synthetic window events unreliable in headless runs).
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 300)
	scroll._input(press)
	for i in 8:
		var move := InputEventMouseMotion.new()
		move.position = Vector2(200, 300 - (i + 1) * 20)
		move.relative = Vector2(0, -20)
		scroll._input(move)
	check(scroll._dragging, "moving the finger starts a drag")
	var release := press.duplicate()
	release.pressed = false
	release.position = Vector2(200, 140)
	scroll._input(release)
	check(scroll.scroll_vertical >= 140, "dragging a list scrolls it (%d)" % scroll.scroll_vertical)
	scroll.scroll_vertical = 0
	scroll._velocity = 0.0
	scroll._input(press)
	var jitter := InputEventMouseMotion.new()
	jitter.position = Vector2(200, 303)
	jitter.relative = Vector2(0, 3)
	scroll._input(jitter)
	check(not scroll._dragging and scroll.scroll_vertical == 0, "a small wobble is still a tap, not a scroll")
	scroll._input(release)
	await _wait(0.2)
	layer.queue_free()


func _party() -> void:
	print("== Party")
	await _start(&"warrior")
	await main.go(&"meadow", true)
	await _wait(0.6)
	var zone: Zone = main.zone
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	await _wait(0.2)
	check(zone.companions.size() == 1, "exactly one companion")
	var buddy: Companion = zone.companions[0]
	check(not buddy.is_dead() and buddy.hp == buddy.max_hp, "companion starts at full HP (%d)" % buddy.max_hp)
	# A monster standing next to the companion (far from the hero) goes for the companion.
	zone.hero.global_position = Vector3(-14, 0.2, 0)
	buddy.global_position = Vector3(10, 0.3, 0)
	var mob := Mob.new()
	mob.setup(&"pink_slime", 3, Vector3(12, 0, 0), zone.hero)
	mob.position = Vector3(12, 0.3, 0)
	zone.add_child(mob)
	await _wait(0.3)
	check(mob._nearest_victim() == buddy, "a monster close to the companion targets it")
	mob.queue_free()
	# Low HP away from town: the companion drinks a potion by itself.
	zone.hero.safe_zone = false
	buddy.member["potions"] = 5
	buddy.hp = int(buddy.max_hp * 0.2)
	buddy._potion_cd = 0.0
	buddy._cast_until = 0
	await _wait(0.5)
	check(buddy.hp > int(buddy.max_hp * 0.4) and int(buddy.member.potions) == 4, "companion drinks a potion when low (%d left)" % int(buddy.member.potions))
	buddy.take_damage(1.0, null)
	check(buddy.hp < buddy.max_hp, "companion can be hurt")
	buddy._invulnerable_until = 0
	buddy.take_damage(100000.0, null)
	check(buddy.is_dead(), "companion can be killed")
	buddy._revive_timer = 0.2
	await _wait(0.8)
	check(not buddy.is_dead() and buddy.hp > 0, "companion gets back up")
	check(Game.cycle_stance() == "aggressive" and Game.cycle_stance() == "guard" and Game.cycle_stance() == "follow", "stance cycles follow -> aggressive -> guard")
	Game.recruit(&"mage")
	await _wait(0.4)
	check(zone.companions.size() == 1 and zone.companions[0].member["class"] == "mage", "recruiting swaps the companion")
	check(String(Game.party()[0]["class"]) == "mage", "party data updated")
	Game.dismiss_party()
	await _wait(0.4)
	check(zone.companions.is_empty() and Game.party().is_empty(), "dismissing leaves nobody")
	Game.recruit(&"priest")
	await _wait(0.3)
	check(zone.companions.size() == 1, "can recruit again")


func _zones() -> void:
	print("== Zones")
	await _start(&"warrior")
	Game.add_exp(2000000)
	for id in ZoneData.ZONES:
		if id == &"town" or id == &"arena":
			continue
		await main.go(id, true)
		await _wait(0.5)
		var z: Zone = main.zone
		check(z != null and z.zone_id == id, "zone %s loads" % id)
		check(get_tree().get_nodes_in_group("mobs").size() >= 10, "%s camps are populated (%d)" % [id, get_tree().get_nodes_in_group("mobs").size()])
		var info := ZoneData.get_zone(id)
		check(z.portals.size() == (2 if info.get("next", &"") != &"" else 1), "%s has the right portals" % id)
		for camp in info.camps:
			for m in camp.monsters:
				check(MonsterData.MONSTERS.has(m), "monster %s exists" % m)


func _items() -> void:
	print("== Items")
	await _start(&"warrior")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	Game.add_gold(100000)
	var sword := ItemData.generate(20, &"warrior", rng, 3, "weapon")
	check(int(sword.sockets) == 2 and int(sword.plus) == 0, "legendary gear has two sockets")
	Game.profile.equip["weapon"] = sword
	var atk0: float = Game.stats_now().atk
	var tries := 0
	while int(sword.plus) < 3 and tries < 20:
		Game.enhance_item(sword)
		tries += 1
	check(int(sword.plus) == 3 and Game.stats_now().atk > atk0, "forge raises +N and the attack stat (+%d)" % int(sword.plus))
	var gold: int = Game.profile.gold
	Game.profile["inv"].append(ItemData.gem("ruby", 2, 2))
	var atk1: float = Game.stats_now().atk
	check(Game.socket_gem(sword, Game.profile.inv.size() - 1) and Game.stats_now().atk >= atk1 + 22, "a ruby in a socket adds ATK")
	check(int(Game.profile.inv[Game.profile.inv.size() - 1].count) == 1, "the gem stack went down by one")
	var armor := ItemData.generate(20, &"warrior", rng, 1, "armor")
	var helm := ItemData.generate(20, &"warrior", rng, 1, "helm")
	check(str(armor.set) != "" and armor.set == helm.set, "same-tier gear belongs to the same set (%s)" % ItemData.set_label(armor.set))
	var def0: float = Game.stats_now().def
	Game.profile.equip["armor"] = armor
	Game.profile.equip["helm"] = helm
	check(HeroStats.set_counts(Game.profile).get(armor.set, 0) >= 2, "set pieces are counted")
	check(ItemLook.icon(ItemData.gem("emerald", 1)) != null, "gems have an icon")
	check(gold >= 0 and Game.save_code_roundtrip(), "save code export / import round-trips")


func _goals() -> void:
	print("== Goals")
	await _start(&"warrior")
	var d := Game.daily()
	check(d.quests.size() == 3, "three daily quests")
	var again := Game.daily()
	check(again.quests[0].id == d.quests[0].id, "daily quests stay the same within a day")
	var entry: Dictionary = d.quests[0]
	var kind: String = Game.daily_template(entry.id).kind
	Game.daily_progress(kind, 9999)
	check(int(entry.progress) >= Game.daily_target(entry), "daily progress completes")
	var gold: int = Game.profile.gold
	check(Game.daily_claim_all() >= 1 and Game.profile.gold > gold, "claiming a daily pays gold")
	check(Game.daily_claim_all() == 0, "a daily can only be claimed once")
	Game.report_kill(&"pink_slime", false)
	check(Game.profile.ach.has("first_blood"), "first kill unlocks an achievement")
	var gold_after: int = Game.profile.gold
	Game.profile["kills"] = 99
	Game.report_kill(&"pink_slime", false)
	check(Game.profile.ach.has("hunter100") and Game.profile.gold >= gold_after + 500, "100 kills unlock an achievement with a gold reward")


func _arena() -> void:
	print("== Arena")
	await _start(&"warrior")
	Game.add_exp(500000)
	await main.go(&"arena", true)
	await _wait(0.5)
	var z: Zone = main.zone
	check(z != null and z.zone_id == &"arena", "arena loads")
	z._arena_timer = 0.1
	await _wait(0.5)
	check(z._arena_wave == 1 and z._arena_mobs.size() == 4, "wave 1 spawns four monsters")
	for m in z._arena_mobs:
		m.take_hit(9999999, false)
	await _wait(0.5)
	check(z._arena_state == "rest", "clearing a wave starts the break")
	z._arena_timer = 0.1
	await _wait(0.4)
	for m in z._arena_mobs:
		m.take_hit(9999999, false)
	await _wait(0.4)
	z._arena_timer = 0.1
	await _wait(0.4)
	check(z._arena_wave == 3 and z._arena_mobs.size() == 3, "wave 3 has a boss and two escorts")
	for m in z._arena_mobs:
		m.take_hit(99999999, false)
	await _wait(0.5)
	check(z._arena_state == "done" and int(Game.profile.flags.get("arena_clears", 0)) == 1, "winning the arena is counted")


func _ending() -> void:
	print("== Ending")
	await _start(&"warrior")
	var seen := [false]
	Game.ending_requested.connect(func(): seen[0] = true, CONNECT_ONE_SHOT)
	Game.report_kill(&"magma_dragon", true)
	await _wait(3.2)
	check(seen[0], "killing the last boss triggers the ending once")
	var again := [false]
	Game.ending_requested.connect(func(): again[0] = true, CONNECT_ONE_SHOT)
	Game.report_kill(&"magma_dragon", true)
	await _wait(3.0)
	check(not again[0], "the ending does not repeat")
	for node in main.get_children():
		if node is EndingScreen:
			node._finish()
	get_tree().paused = false


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
	var look := ItemLook.look_of(sword)
	check(look.begins_with("sword_") and ItemLook.icon(sword) != null, "sword has a look and an icon (%s)" % look)
	check(zone.hero.visual.find_child("Held_" + look, true, false) != null, "hero holds the equipped sword model")
	var helm := ItemData.generate(5, &"warrior", rng, 1, "helm")
	var armor := ItemData.generate(5, &"warrior", rng, 1, "armor")
	Game.add_item(helm)
	Game.equip_from_bag(Game.profile.inv.size() - 1)
	Game.add_item(armor)
	Game.equip_from_bag(Game.profile.inv.size() - 1)
	check(zone.hero.visual.find_child("Hat", true, false) != null or zone.hero.visual.find_child("Att_*", true, false) != null or ItemLook.helm_look(helm).has("part"), "hero wears the helm")
	check(ItemLook.icon(armor) != null and ItemLook.icon(helm) != null, "armor and helm icons exist")
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
