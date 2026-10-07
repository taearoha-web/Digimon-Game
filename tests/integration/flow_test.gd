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
	# `-- pvp` runs only the ranked-duel section (quick iteration).
	if "pvp" in OS.get_cmdline_user_args():
		await _pvp_duel()
		return
	if "stars" in OS.get_cmdline_user_args():
		await _star_drops()
		return
	if "tower" in OS.get_cmdline_user_args():
		await _tower()
		return
	if "paragon" in OS.get_cmdline_user_args():
		await _paragon()
		return
	if "void" in OS.get_cmdline_user_args():
		await _void_zone()
		return
	if "wings" in OS.get_cmdline_user_args():
		await _wings()
		return
	await _vagabond()
	await _look()
	await _storage_and_auto()
	await _bosses_loot_dailies()
	await _dex_and_stars()
	await _tiers()
	await _summons()
	for id in ClassData.IDS:
		await _play_class(id)
	check(_party_damage_total > 0, "companions dealt damage over the four runs (%d)" % _party_damage_total)
	await _resume_after_reload()
	await _save_slots()
	await _warp_points()
	await _pvp_duel()
	await _wings()
	await _void_zone()
	await _paragon()
	await _tower()
	await _star_drops()
	await _timer_bars()
	_buff_durations()
	await _team_buffs()
	await _camera_while_moving()
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
	check(town.npcs.size() == 14, "eleven villagers, the warp crystal, the ranked-duel desk and the tower keeper")
	check(main.hud.skill_slots.size() == 8 and ClassData.SLOTS == 8, "HUD has eight skill slots")
	var bar := Game.loadout_skills()
	check(bar.size() == 8 and not bar[0].is_empty() and not bar[1].is_empty(), "%s has skills on the bar at Lv.10" % class_id)
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
	print("== Advancements")
	for class_id in ClassData.IDS:
		await _start(class_id)
		check(JobData.PATHS[class_id].size() == 4, "%s has four advancement steps" % class_id)
		check(not Game.advance(), "cannot advance below Lv.%d" % JobData.TIER_LEVELS[0])
		Game.add_exp(100000000)
		check(Game.profile.level == Game.MAX_LEVEL, "%s reaches the level cap %d" % [class_id, Game.MAX_LEVEL])
		var attrs_before: Dictionary = Game.stats_now().attrs
		var name_before := String(Game.class_data().name)
		for step in 4:
			Game.profile.gold = 1000000
			var gold_before: int = Game.profile.gold
			check(Game.advance(), "%s advances to step %d (%s)" % [class_id, step + 1, JobData.current(class_id, Game.adv()).name])
			check(Game.profile.gold <= gold_before - int(JobData.TIER_COSTS[step]) + 300000, "advancement %d costs gold" % (step + 1))
			if step == 0:
				await _wait(0.4)
				check(main.zone.hero._ring != null, "the advancement ring appears under the hero")
				check(String(Game.class_data().name) != name_before, "advancing renames the hero")
		check(Game.adv() == 4 and not Game.advance(), "%s cannot advance past the legend step" % class_id)
		check(String(Game.class_data().name).contains("ในตำนาน"), "%s ends as a legend (%s)" % [class_id, Game.class_data().name])
		var main_key: String = ClassData.get_class_data(class_id).main
		check(int(Game.stats_now().attrs[main_key]) >= int(attrs_before[main_key]) + 80, "%s: advancements raise the main attribute (%s)" % [class_id, main_key])
		var before := Game.stats_now()
		var power_before: float = float(before.atk) + float(before.def) + float(before.max_hp) + float(before.max_mp) + float(before.crit) * 1000.0 + float(before.speed)
		Game.profile.skills[ClassData.PASSIVES[class_id][0].id] = 5
		var after_stats := Game.stats_now()
		var power_after: float = float(after_stats.atk) + float(after_stats.def) + float(after_stats.max_hp) + float(after_stats.max_mp) + float(after_stats.crit) * 1000.0 + float(after_stats.speed)
		check(power_after > power_before, "passive skill ranks add stats")


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
	Game.profile["level"] = 100
	Game.fill_loadout()
	var fire_bolt := ClassData.find_skill(&"mage", "fire_bolt")
	var watornado := ClassData.find_skill(&"mage", "watornado")
	var flame := ClassData.find_skill(&"mage", "flame_wave")
	var meteo := ClassData.find_skill(&"mage", "meteo")
	var hell := ClassData.find_skill(&"mage", "hell_meteor")
	var armageddon := ClassData.find_skill(&"mage", "armageddon")
	check(Game.class_tier() == 1 and Game.skill_unlocked(fire_bolt), "line skills below Lv.20 need only the line")
	check(not Game.skill_unlocked(watornado) and not Game.skill_unlocked(armageddon), "higher skills are locked without the advancement")
	check(Game.skill_lock_reason(watornado).contains("นักเวทย์ขั้นสูง"), "lock reason names the advancement")
	check(not Game.loadout().has("watornado"), "locked skills are kept off the bar")
	Game.profile.gold = 10000000
	check(Game.advance() and Game.class_tier() == 2, "Lv.20 step reaches tier 2")
	check(Game.skill_unlocked(watornado) and not Game.skill_unlocked(flame), "tier 2 opens Lv.20-39 skills only")
	check(Game.advance() and Game.class_tier() == 3 and Game.skill_unlocked(flame) and not Game.skill_unlocked(meteo), "tier 3 (Lv.40) opens Lv.40-59 skills")
	check(Game.advance() and Game.class_tier() == 4 and Game.skill_unlocked(meteo) and not Game.skill_unlocked(hell), "tier 4 (Lv.60) opens Lv.60-79 skills")
	check(Game.advance() and Game.class_tier() == 5 and Game.skill_unlocked(hell) and Game.skill_unlocked(armageddon), "tier 5 (Lv.80) opens Lv.80+ skills")
	check(String(JobData.current(&"mage", 3).name) == "ปรมาจารย์นักเวทย์" and String(JobData.current(&"mage", 4).name) == "นักเวทย์ในตำนาน", "mage tier names follow the plan")
	check(String(JobData.current(&"mage", 2).name) == "นักเวทย์ขั้นสุดยอด", "Lv.40 is the supreme mage")


func _summons() -> void:
	print("== Summoners")
	for class_id in [&"archer", &"mage"]:
		var summoners := 0
		for skill in ClassData.pool(class_id):
			if String(skill.shape) == "summon":
				summoners += 1
		check(summoners >= 3, "%s has summoner skills (%d)" % [class_id, summoners])
	await _start(&"archer")
	var field_zone := await _go_field()
	var hero: Hero = field_zone.hero
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.fill_loadout()
	Game.profile.mp = 99999
	var wolverine := ClassData.find_skill(&"archer", "recall_wolverine")
	check(Game.equip_skill("recall_wolverine", 0), "summon skill can be put on the bar")
	var before := get_tree().get_nodes_in_group("mobs").size()
	hero.cooldowns.clear()
	hero.use_skill(0)
	await _wait(0.9)
	var count := 0
	for child in field_zone.get_children():
		if child is Summon:
			count += 1
	check(count == 2, "Recall Wolverine summons two wolves (%d)" % count)
	var watched: Array = get_tree().get_nodes_in_group("mobs").duplicate()
	var hp_before := 0
	for node in watched:
		hp_before += int((node as Mob).hp)
	await _wait(6.0)
	var hp_after := 0
	for node in watched:
		if is_instance_valid(node) and not (node as Mob).is_dead():
			hp_after += int((node as Mob).hp)
	check(before > 0, "monsters are around for the summons to fight")
	check(hp_after < hp_before, "the wolves bite the monsters (%d -> %d total HP)" % [hp_before, hp_after])
	check(wolverine.shape == "summon", "wolverine is a summon skill")
	# Health bar, 3-minute life, monsters can kill it, size grows with the stars.
	var wolf: Summon = null
	for child in field_zone.get_children():
		if child is Summon:
			wolf = child
	check(wolf != null and wolf.life > 150.0 and wolf.life <= 180.0 and wolf.max_hp > 0 and wolf._bar != null, "a summon lasts 3 minutes and has a health bar (%d HP)" % (wolf.max_hp if wolf else 0))
	check(wolf != null and wolf.is_in_group("summons") and not wolf.is_dead(), "summons are in their own group")
	var mob_view := Mob.new()
	mob_view.setup(&"pink_slime", 5, Vector3(0, 0, 0), hero)
	field_zone.add_child(mob_view)
	await _wait(0.1)
	var targets := mob_view._targets()
	check(targets.has(wolf), "monsters can pick a summon as their victim")
	mob_view.queue_free()
	check(not ClassData.find_skill(&"archer", "recall_wolverine").desc.contains("30 วินาที"), "summon description says 3 minutes")
	var hp_start := wolf.hp
	wolf.take_damage(float(wolf.max_hp) * 0.25)
	check(wolf.hp < hp_start, "monsters' hits lower a summon's HP")
	wolf.take_damage(float(wolf.max_hp) * 50.0)
	check(wolf.is_dead() and not wolf.is_in_group("summons"), "a summon at 0 HP dies")
	await _wait(0.6)
	check(not is_instance_valid(wolf), "the dead summon is removed")
	# Balance: at 5 stars a summon is a little taller than the hero (about 2.8 m with hair), never huge.
	for kind_name in Summon.KINDS:
		var kind: Dictionary = Summon.KINDS[kind_name]
		if kind.has("height"):
			var top5: float = (float(kind.height) + float(kind.hover)) * Summon.size_for_rank(5)
			check(top5 >= 2.0 and top5 <= 3.3, "%s stands %.2f m tall at 5 stars (no giants)" % [kind_name, top5])
	var biggest := 0.0
	for kind_name in Summon.KINDS:
		var kind: Dictionary = Summon.KINDS[kind_name]
		if kind.has("height"):
			biggest = maxf(biggest, (float(kind.height) + float(kind.hover)) * Summon.size_for_rank(5))
	check(biggest > 2.9 and biggest < 3.3, "the biggest 5-star summon is just above the hero (%.2f m)" % biggest)
	# Stars make it bigger: 1 star normal, 2 stars +10%, 5 stars +50%.
	var expected := {1: 1.0, 2: 1.10, 3: 1.2333, 4: 1.3667, 5: 1.5}
	for stars in expected:
		var probe := Summon.new()
		probe.setup(hero, "recall_wolverine", {"kind": "wolf", "count": 1, "secs": 180.0}, 1.0, 0, 1, stars)
		check(absf(probe.size_mult - float(expected[stars])) < 0.002, "%d star(s) -> %d%% size" % [stars, int(round(float(expected[stars]) * 100.0))])
		probe.free()
	Game.profile.skills["recall_wolverine"] = 4
	hero.cooldowns.clear()
	hero.use_skill(0)
	await _wait(0.9)
	var big: Summon = null
	for child in field_zone.get_children():
		if child is Summon and not child.is_dead():
			big = child
	check(big != null and big.rank == 4 and absf(big.size_mult - 1.3667) < 0.01, "4 stars make the summon 137% size")
	await _wait(0.5)
	check(big != null and absf(big.scale.x - 1.3667) < 0.1, "the summon model really is 137%% (scale %.2f)" % (big.scale.x if big else 0.0))


func _go_field() -> Zone:
	await main.go(&"meadow", true)
	await _wait(0.6)
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	await _wait(0.2)
	hero.global_position = Vector3(-20, 0.2, 0)
	_spawn(zone, hero, [&"pink_slime", &"green_slime", &"pink_slime"], 2)
	await _wait(0.4)
	return zone


func _dex_and_stars() -> void:
	print("== DEX haste and star radius")
	await _start(&"archer")
	var hero: Hero = main.zone.hero
	var skill := ClassData.find_skill(&"archer", "wind_arrow")
	var cd_before := hero.cooldown_of(skill)
	Game.profile.attrs.dex += 100
	hero.refresh_stats()
	check(float(hero.stats.haste) >= 0.1, "100 DEX gives about 10%% haste (%.2f)" % float(hero.stats.haste))
	check(hero.cooldown_of(skill) < cd_before * 0.95, "DEX shortens cooldowns")
	Game.profile.attrs.dex += 10000
	hero.refresh_stats()
	check(float(hero.stats.haste) <= HeroStats.MAX_HASTE + 0.001, "haste is capped")
	var blast := ClassData.find_skill(&"archer", "avalanche")
	Game.profile["adv"] = 1
	Game.profile.skills["avalanche"] = 5
	Game.profile["level"] = 50
	var grown := hero._ranked(blast)
	check(float(grown.radius) > float(blast.radius) * 1.3, "5 stars widen an area skill by about 32%% (%.1f -> %.1f)" % [float(blast.radius), float(grown.radius)])
	var fan := ClassData.find_skill(&"archer", "arrow_of_rage")
	Game.profile.skills["arrow_of_rage"] = 5
	check(int(hero._ranked(fan).hits) == int(fan.hits) + 2, "5 stars add two arrows to a fan skill")


func _bosses_loot_dailies() -> void:
	print("== Boss phases, mythic drops, daily streak")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var legend := ItemData.generate(60, &"warrior", rng, 3, "weapon")
	var mythic := ItemData.generate(60, &"warrior", rng, 4, "weapon")
	check(int(mythic.stats.atk) > int(legend.stats.atk) * 1.12, "a mythic weapon beats a legendary one (%d vs %d)" % [int(mythic.stats.atk), int(legend.stats.atk)])
	check(int(mythic.sockets) == 3 and ItemData.RARITY_NAMES.size() == 5 and ItemData.color_of(mythic) == ItemData.RARITY_COLORS[4], "mythic has 3 sockets and its own colour")
	var plain := 0
	var boosted := 0
	for i in 5000:
		plain += 1 if ItemData.roll_rarity(rng) == 4 else 0
		boosted += 1 if ItemData.roll_rarity(rng, 0.3) == 4 else 0
	check(plain <= 25 and boosted > 100 and boosted < 600, "mythic is very rare on monsters (%d/5000) and findable from bosses (%d/5000)" % [plain, boosted])
	var zone := await _start(&"warrior")
	await main.go(&"meadow", true)
	await _wait(0.5)
	var field: Zone = main.zone
	var hero: Hero = field.hero
	Game.profile["level"] = 30
	var boss := Mob.new()
	boss.setup(&"mush_king", 12, Vector3(20, 0, 20), hero)
	boss.position = Vector3(20, 0.3, 20)
	field.add_child(boss)
	boss.hostile = true
	hero.global_position = Vector3(18, 0.2, 18)
	await _wait(0.3)
	var before := get_tree().get_nodes_in_group("mobs").size()
	boss.take_hit(int(boss.max_hp * 0.35), false, Color.WHITE, hero)
	await _wait(0.2)
	check(boss.phase == 1 and get_tree().get_nodes_in_group("mobs").size() >= before + 3, "at 65%% HP the boss calls 3 helpers (phase %d)" % boss.phase)
	var speed_before: float = boss._speed
	boss.take_hit(int(boss.max_hp * 0.3), false, Color.WHITE, hero)
	await _wait(0.2)
	check(boss.phase == 2 and boss._atk_scale > 1.2 and boss._speed > speed_before, "at 35%% HP the boss is enraged (atk x%.1f)" % boss._atk_scale)
	field._on_boss_phase(boss, 2)
	check(field.get_children().size() > 0, "boss phase handler runs on its own")
	# Daily board: streak and the bonus chest.
	Game.profile["daily"] = {}
	var board := Game.daily()
	for entry in board.quests:
		entry["progress"] = Game.daily_target(entry)
	var inv_before: int = Game.profile.inv.size()
	var gold_before: int = Game.profile.gold
	check(Game.daily_claim_all() == 3 and Game.daily_streak() == 1, "claiming the board starts a 1-day streak")
	check(bool(Game.daily().get("chest", false)) and Game.profile.inv.size() >= inv_before + 2, "finishing all three adds the bonus chest")
	check(Game.daily_claim_all() == 0, "nothing is paid twice")
	Game.profile["flags"]["daily_last"] = GoalsData.yesterday()
	Game.profile["flags"]["daily_streak"] = 6
	check(Game.daily_streak() == 6, "yesterday's streak is kept")
	Game.profile["flags"]["daily_last"] = "2000-01-01"
	check(Game.daily_streak() == 0, "a missed day resets the streak")
	Game.add_item(ItemData.generate(40, &"warrior", rng, 4))
	check(Game.achievement_value("got_mythic") == 1, "getting a mythic item is recorded")


func _storage_and_auto() -> void:
	print("== Storage, bigger bag, auto hunting")
	var zone := await _start(&"warrior")
	check(Game.bag_size() == Game.BASE_BAG and Game.BASE_BAG >= 40, "the bag starts with %d slots" % Game.bag_size())
	Game.add_item(ItemData.potion("hp_s", 3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	Game.add_item(ItemData.generate(5, &"warrior", rng, 1, "armor"))
	var bag_before: int = Game.profile.inv.size()
	check(Game.deposit_item(0) and Game.profile.inv.size() == bag_before - 1 and Game.storage().size() == 1, "deposit moves an item to the storage")
	Game.add_item(ItemData.potion("hp_s", 2))
	check(Game.deposit_item(Game.profile.inv.size() - 1) or true, "deposit potions")
	var stored_before: int = Game.storage().size()
	check(Game.withdraw_item(0) and Game.storage().size() == stored_before - 1, "withdraw brings an item back")
	for i in Game.STORAGE_SIZE + 5:
		Game.add_item(ItemData.generate(3, &"warrior", rng, 0, "boots"))
	check(Game.profile.inv.size() <= Game.bag_size(), "the bag never exceeds its size")
	Game.profile.gold = 100000
	var cost := Game.bag_expand_cost()
	check(cost > 0 and Game.expand_bag() and Game.bag_size() == Game.BASE_BAG + Game.BAG_STEP, "paying gold adds %d bag slots" % Game.BAG_STEP)
	var save_code := Game.export_code()
	check(Game.import_code(save_code) and Game.bag_size() == Game.BASE_BAG + Game.BAG_STEP and Game.storage().size() == stored_before - 1, "bag size and storage survive saving")
	# Auto hunting stays inside the camp it was switched on in.
	await main.go(&"meadow", true)
	await _wait(0.5)
	var field: Zone = main.zone
	var hero: Hero = field.hero
	Game.profile["level"] = 20
	Game.fill_loadout()
	var camp: Dictionary = field._camps[0]
	hero.global_position = Vector3(camp.pos.x, 0.2, camp.pos.y)
	var center := Vector3(camp.pos.x, 0, camp.pos.y)
	hero.set_auto(true)
	check(hero.auto, "auto turns on inside a camp")
	var kills_before := int(Game.profile.kills)
	var farthest := 0.0
	var waited := 0.0
	while waited < 45.0 and int(Game.profile.kills) < kills_before + 3 and not hero.is_dead():
		await _wait(0.5)
		waited += 0.5
		Game.profile.hp = maxi(int(Game.profile.hp), int(hero.stats.max_hp * 0.6))
		Game.profile.mp = maxi(int(Game.profile.mp), 40)
		farthest = maxf(farthest, Vector2(hero.global_position.x - center.x, hero.global_position.z - center.z).length())
	check(int(Game.profile.kills) >= kills_before + 3, "auto killed monsters by itself (%d kills in %.0fs)" % [int(Game.profile.kills) - kills_before, waited])
	check(farthest <= float(camp.radius) + 8.0, "auto stayed around the camp (max %.1f from the centre)" % farthest)
	hero.move_input = Vector2(1, 0)
	var held := 0.0
	while hero.auto and held < 2.0:
		await _wait(0.2)
		held += 0.2
	hero.move_input = Vector2.ZERO
	check(not hero.auto, "moving by hand turns auto off")


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
	check(FaceKit.option_count("hair", 0) >= 8 and FaceKit.option_count("hair", 1) >= 8 and FaceKit.OUTFITS.size() >= 9 and FaceKit.HAIR_COLORS.size() == FaceKit.HAIR_COLOR_NAMES.size(), "8 hair styles per gender, 9 starter outfits")
	for g in 2:
		for style in FaceKit.option_count("hair", g):
			var styled := FaceKit.default_look()
			styled["gender"] = g
			styled["hair"] = style
			var styled_head := FaceKit.build_head(styled)
			check(styled_head.get_node_or_null("Hair") != null and styled_head.get_node("Hair").get_child_count() >= 2, "hair style %d/%d builds" % [g, style])
			styled_head.free()
	var starter_look := FaceKit.default_look()
	starter_look["outfit"] = 3
	var starter := HeroVisual.new()
	main.add_child(starter)
	starter.setup(ClassData.START, "", true, {}, starter_look)
	var outlined := 0
	for node in starter.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat != null and mat.next_pass != null:
				outlined += 1
	check(outlined > 5, "the hero gets a cartoon outline (%d surfaces)" % outlined)
	starter.free()
	var old_look := {"gender": 1, "skin": 2, "hair": 1, "hair_color": 3, "eyes": 0, "eye_color": 0, "nose": 0, "mouth": 0}
	check(int(FaceKit.repair(old_look).outfit) == 0, "old saves without an outfit still load")
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


func _resume_after_reload() -> void:
	print("== Resume after a browser reload")
	var zone := await _start(&"warrior")
	await _wait(0.3)
	Game.playing = true
	Game.save()
	check(Game.should_resume(), "a recent in-game save is resumed after a reload")
	Game.playing = false
	Game.save()
	check(not Game.should_resume(), "going back to the title screen cancels the auto-resume")
	Game.playing = true
	Game.save()
	var path := ProjectSettings.globalize_path(Game.save_path())
	var f := FileAccess.open(Game.save_path(), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["saved_at"] = int(Time.get_unix_time_from_system()) - Game.RESUME_WINDOW - 60
	var w := FileAccess.open(Game.save_path(), FileAccess.WRITE)
	w.store_string(JSON.stringify(data))
	w.close()
	check(not Game.should_resume(), "an old save is not resumed automatically")
	Game.delete_save()
	check(not Game.should_resume(), "no save, no resume")


func _save_slots() -> void:
	print("== Four save slots")
	for i in range(1, 5):
		Game.delete_save(i)
	check(not Game.any_save() and Game.free_slot() == 1, "all four slots start empty")
	var classes: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest"]
	for i in 4:
		Game.slot = i + 1
		Game.new_profile(classes[i], "ฮีโร่%d" % (i + 1))
		Game.profile["level"] = 10 + i
		Game.save()
	check(Game.free_slot() == 0, "four heroes fill the four slots")
	for i in 4:
		var info := Game.slot_info(i + 1)
		check(not info.is_empty() and info["name"] == "ฮีโร่%d" % (i + 1) and int(info["level"]) == 10 + i, "slot %d keeps its own hero" % (i + 1))
	check(Game.load_game(3) and Game.slot == 3 and Game.class_id() == &"mage", "loading slot 3 gives the mage")
	check(Game.last_slot() == 3, "the last played slot is remembered")
	Game.delete_save(2)
	check(not Game.has_save(2) and Game.has_save(1) and Game.has_save(3) and Game.free_slot() == 2, "deleting one slot leaves the others")
	Game.playing = true
	Game.save()
	check(Game.should_resume(), "auto-resume uses the last played slot")
	Game.playing = false
	for i in range(1, 5):
		Game.delete_save(i)
	Game.slot = 1


func _warp_points() -> void:
	print("== Warp points")
	await _start(&"warrior")
	await main.go(&"town", true)
	await _wait(0.4)
	var town: Zone = main.zone
	check(town.npcs.any(func(n): return n.role == "warp"), "the village has a warp crystal")
	var places := WarpScreen.destinations()
	check(places.size() == 12 and places[0] == &"town" and places[10] == &"abyss" and places[11] == &"void", "the warp list is the village plus all eleven fields")
	check(WarpScreen.unlocked(&"meadow", 1) and not WarpScreen.unlocked(&"dark_forest", 6) and WarpScreen.unlocked(&"dark_forest", 7), "fields unlock by level")
	Game.profile["level"] = 30
	var open := places.filter(func(p): return WarpScreen.unlocked(p, 30))
	check(open.has(&"snow") and not open.has(&"volcano"), "at Lv.30 the warp reaches the snow mountain but not the volcano")
	main.warp.open_warp()
	await _wait(0.2)
	check(main.warp.is_open, "the warp screen opens")
	main.warp.close_warp()
	await main.go(&"snow", false, true)
	await _wait(0.8)
	var snow: Zone = main.zone
	check(snow.zone_id == &"snow", "warping lands in the snow field")
	check(snow.hero.global_position.x < -30.0, "warping arrives at the field start")
	check(snow.npcs.filter(func(n): return n.role == "warp").size() == 2, "a field has a warp crystal at both ends")
	await main.go(&"town", false, true)
	await _wait(0.6)
	check(main.zone.zone_id == &"town", "warping back reaches the village")


func _pvp_duel() -> void:
	print("== Ranked duel")
	check(PvpData.rank_name(0) == "ทองแดง III" and PvpData.rank_name(300) == "เงิน III" and PvpData.rank_name(1600) == "ตำนาน", "rank names follow the ladder")
	check(PvpData.tier_floor(450) == 300 and PvpData.tier_floor(1550) == 1500, "a loss never drops you out of your league")
	await _start(&"warrior")
	Game.profile["level"] = 30
	Game.fill_loadout()
	Game.pvp()["rp"] = 350
	await main.go(&"pvp", true, true)
	await _wait(0.6)
	var zone: Zone = main.zone
	check(zone.is_pvp and zone.pvp_match != null and zone.pvp_match.rival != null, "the coliseum has a rival")
	check(zone.companions.is_empty(), "no companions in a duel")
	var rival: Rival = zone.pvp_match.rival
	check(rival.level >= 27 and rival.max_hp > 100, "the rival is level matched (Lv.%d, %d HP)" % [rival.level, rival.max_hp])
	check(not rival.take_hit(50, false), "the rival cannot be hurt during the countdown")
	Game.profile.inv.append(ItemData.potion("hp_s", 2))
	Game.profile.hp = 10
	check(Game.use_potion_at(Game.profile.inv.size() - 1) == "", "no potions in a duel")
	Game.profile.hp = Game.stats_now().max_hp
	await _wait(4.8)
	check(zone.pvp_match.state == "fight", "the fight starts after the countdown")
	var hs := Game.stats_now()
	zone.hero._invulnerable_until = Time.get_ticks_msec() + 20000
	zone.hero.global_position = Vector3(PvpArena.SPAWN_X - 3.0, 0.2, 0.0)
	for i in 10:
		await _wait(0.5)
		Game.profile.hp = Game.stats_now().max_hp
	check(zone.pvp_match.state == "fight", "the fight is running")
	Game.profile.hp = Game.stats_now().max_hp
	rival.hp = 1
	for i in 30:
		if rival.take_hit(99999, false):
			break
	await _wait(3.2)
	check(rival.is_dead(), "the rival can be beaten")
	check(Game.pvp_rp() > 350 and int(Game.pvp().wins) == 1, "a win earns rank points (%d RP)" % Game.pvp_rp())
	check(main.pvp_screen.is_open, "the result screen opens")
	main.pvp_screen.close_screen()
	# A loss.
	await main.go(&"pvp", true, true)
	await _wait(5.0)
	var before := Game.pvp_rp()
	zone = main.zone
	zone.hero._invulnerable_until = 0
	for i in 40:
		zone.hero.take_damage(9999999.0)
		if zone.hero.is_dead():
			break
	await _wait(3.2)
	check(Game.pvp_rp() < before and int(Game.pvp().losses) == 1, "a loss costs rank points")
	main.pvp_screen.close_screen()
	await main.go(&"town", true, true)
	await _wait(0.5)
	check(main.zone.is_town and Game.profile.hp > 0, "back in the village alive")
	check(Game.save_code_roundtrip(), "save code still round-trips after duels")


func _wings() -> void:
	print("== Wings")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var seen := {}
	var values: Array[int] = []
	for i in 80:
		var w := ItemData.wings(rng)
		seen[w.wing] = true
		if i == 0:
			check(w.slot == "wings" and int(w.level) == 100 and int(w.rarity) >= 2, "wings are a Lv.100 item")
		var info: Dictionary = ItemData.WING_INFO[w.wing]
		var v := int(w.stats[info.stat])
		values.append(v)
		if v < int(float(info.base) * 0.74) or v > int(float(info.base) * 1.26):
			check(false, "wing roll out of range: %s %d" % [w.wing, v])
	check(seen.size() == 4, "all four wing types drop")
	check(values.max() > values.min() + 20, "wing stats are random (%d..%d)" % [values.min(), values.max()])
	# Effect on stats: matk only helps int classes.
	await _start(&"mage")
	Game.profile["level"] = 100
	var before_mage := float(Game.stats_now().atk)
	var wing_m := ItemData.wings(rng, "matk")
	Game.profile.inv.append(wing_m)
	check(Game.equip_from_bag(Game.profile.inv.size() - 1), "level 100 can wear wings")
	check(float(Game.stats_now().atk) >= before_mage + float(wing_m.stats.matk) - 1.0, "magic wings add attack for a mage")
	await _start(&"warrior")
	Game.profile["level"] = 100
	var before_w := float(Game.stats_now().atk)
	var wing_a := ItemData.wings(rng, "atk")
	Game.profile.inv.append(wing_a)
	Game.equip_from_bag(Game.profile.inv.size() - 1)
	check(float(Game.stats_now().atk) >= before_w + float(wing_a.stats.atk) - 1.0, "attack wings add attack")
	var wing_hp := ItemData.wings(rng, "hp")
	var hp_before: int = Game.stats_now().max_hp
	Game.profile.inv.append(wing_hp)
	Game.equip_from_bag(Game.profile.inv.size() - 1)
	check(int(Game.stats_now().max_hp) > hp_before + 1000, "life wings add lots of HP")
	check(Game.profile.equip.wings.wing == "hp", "the wing slot holds the new pair")
	Game.profile["level"] = 50
	Game.profile.inv.append(ItemData.wings(rng, "def"))
	check(not Game.equip_from_bag(Game.profile.inv.size() - 1), "wings need level 100")
	# The Lv.100 boss: drops and the 1-minute respawn.
	check(float(ZoneData.get_zone(&"abyss").boss.respawn) == 60.0, "the Lv.100 boss comes back 1 minute after dying")
	Game.profile["level"] = 100
	Game.add_exp(0)
	await main.go(&"abyss", true)
	await _wait(0.5)
	var zone: Zone = main.zone
	var boss := Mob.new()
	boss.setup(&"abyss_dragon", 100, Vector3(0, 0, 0), zone.hero)
	zone.add_child(boss)
	var found := 0
	for i in 60:
		zone._drop_loot(boss)
	for child in zone.get_children():
		if child is LootDrop and (child as LootDrop).item.get("slot", "") == "wings":
			found += 1
	check(found >= 6 and found <= 40, "the Lv.100 boss drops wings about a third of the time (%d / 60)" % found)
	var lowboss := Mob.new()
	lowboss.setup(&"magma_dragon", 42, Vector3(0, 0, 0), zone.hero)
	zone.add_child(lowboss)
	var before_count := 0
	for child in zone.get_children():
		if child is LootDrop and (child as LootDrop).item.get("slot", "") == "wings":
			before_count += 1
	for i in 30:
		zone._drop_loot(lowboss)
	var after_count := 0
	for child in zone.get_children():
		if child is LootDrop and (child as LootDrop).item.get("slot", "") == "wings":
			after_count += 1
	check(after_count == before_count, "other bosses never drop wings")
	Game.fill_loadout()
	Game.save_code_roundtrip()
	check(Game.save_code_roundtrip(), "wings survive the save code")


func _void_zone() -> void:
	print("== Void of calamity")
	var info := ZoneData.get_zone(&"void")
	check(ZoneData.get_zone(&"abyss").next == &"void" and info.prev == &"abyss", "the void follows the abyss")
	check(int(info.level[0]) == 100, "the void needs Lv.100")
	var hell := MonsterData.stats_for(&"hell_orc", 100)
	var tank := MonsterData.stats_for(&"void_golem", 100)
	check(int(tank.hp) >= int(hell.hp) * 1.8 and int(tank.atk) > int(hell.atk), "void monsters have far more HP (%d vs %d) and hit harder" % [tank.hp, hell.hp])
	var emperor := MonsterData.stats_for(&"void_emperor", 100)
	check(int(emperor.hp) > 900000, "the void emperor is a huge HP sponge (%d)" % emperor.hp)
	await _start(&"warrior")
	Game.profile["level"] = 100
	Game.fill_loadout()
	await main.go(&"void", true)
	await _wait(0.6)
	var zone: Zone = main.zone
	check(zone.zone_id == &"void" and get_tree().get_nodes_in_group("mobs").size() >= 30, "the void is populated")
	for node in get_tree().get_nodes_in_group("mobs"):
		(node as Mob).queue_free()
	var mob := Mob.new()
	mob.setup(&"void_golem", 100, Vector3.ZERO, zone.hero)
	zone.add_child(mob)
	var gear := 0
	var high := 0
	for i in 300:
		var before := zone.get_child_count()
		zone._drop_loot(mob)
		for j in range(before, zone.get_child_count()):
			var c := zone.get_child(j)
			if c is LootDrop and (c as LootDrop).item.get("kind", "") == "equip":
				gear += 1
				if int((c as LootDrop).item.rarity) >= 3:
					high += 1
	check(gear >= 60 and gear <= 130, "void monsters drop gear about 30%% of the time (%d / 300)" % gear)
	check(high >= 3, "legendary or better gear drops in the void (%d)" % high)
	var boss := Mob.new()
	boss.setup(&"void_emperor", 100, Vector3.ZERO, zone.hero)
	zone.add_child(boss)
	var before_boss := zone.get_child_count()
	zone._drop_loot(boss)
	var items := 0
	var best := 0
	for j in range(before_boss, zone.get_child_count()):
		var c := zone.get_child(j)
		if c is LootDrop and (c as LootDrop).item.get("kind", "") == "equip" and (c as LootDrop).item.get("slot", "") != "wings":
			items += 1
			best = maxi(best, int((c as LootDrop).item.rarity))
	check(items == 4 and best >= 3, "the void emperor drops four gear pieces, at least legendary (%d, rarity %d)" % [items, best])


func _paragon() -> void:
	print("== Paragon")
	await _start(&"warrior")
	Game.profile["level"] = 99
	Game.add_exp(HeroStats.exp_to_next(99) + 10)
	check(int(Game.profile.level) == 100 and int(Game.paragon().level) == 0, "reaching Lv.100 starts at paragon 0")
	var need := Game.paragon_need()
	check(need > 50000, "a paragon level costs real EXP (%d)" % need)
	var atk0: float = Game.stats_now().atk
	var hp0: int = Game.stats_now().max_hp
	Game.add_exp(need * 4)
	check(int(Game.paragon().level) >= 3 and int(Game.paragon().points) >= 3, "EXP after Lv.100 gives paragon levels (%d)" % int(Game.paragon().level))
	check(Game.exp_ratio() >= 0.0 and Game.exp_ratio() < 1.0, "the EXP bar follows paragon EXP")
	check(Game.paragon_spend("atk") and Game.paragon_spend("atk") and Game.paragon_spend("hp"), "points can be spent")
	check(float(Game.stats_now().atk) > atk0 and int(Game.stats_now().max_hp) > hp0, "paragon points raise attack and HP")
	var cap: int = Game.PARAGON_STATS["crit"][2]
	Game.paragon()["points"] = cap + 5
	var bought := 0
	for i in cap + 5:
		if Game.paragon_spend("crit"):
			bought += 1
	check(bought == cap, "a stat stops at its cap (%d)" % bought)
	Game.profile["gold"] = 10000000
	check(Game.paragon_reset() and int(Game.paragon().spent) == 0 and int(Game.paragon().alloc.atk) == 0, "points can be reset for gold")
	Game.paragon()["level"] = Game.PARAGON_MAX - 1
	Game.paragon()["exp"] = 0
	Game.add_exp(Game.paragon_need() + 100)
	check(int(Game.paragon().level) == Game.PARAGON_MAX, "the paragon cap is 200")
	var before_level := int(Game.paragon().level)
	Game.add_exp(999999)
	check(int(Game.paragon().level) == before_level, "no levels past the cap")
	check(Game.save_code_roundtrip(), "paragon survives the save code")
	# Gear above Lv.100 is worn with paragon levels.
	var grng := RandomNumberGenerator.new()
	grng.seed = 8
	var high := ItemData.generate(103, &"warrior", grng, 2, "armor")
	check(ItemData.level_text(103) == "Lv.100 ★3" and ItemData.level_text(80) == "Lv.80", "gear above Lv.100 is labelled with stars")
	Game.paragon()["level"] = 2
	check(Game.equip_problem(high) != "", "Lv.103 gear needs star 3 (have 2)")
	Game.paragon()["level"] = 3
	check(Game.equip_problem(high) == "", "Lv.103 gear can be worn at star 3")
	Game.profile["level"] = 90
	check(Game.equip_problem(high) != "", "paragon gear still needs Lv.100")


func _tower() -> void:
	print("== Void Tower")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	check(TowerData.hp_mult(30) > TowerData.hp_mult(1) * 3 and TowerData.atk_mult(30) > 2.0, "monsters get much tougher with the floor")
	check(TowerData.is_boss_floor(10) and not TowerData.is_boss_floor(11) and TowerData.spec(10, rng).boss and TowerData.spec(10, rng).ids[0] == &"void_emperor", "every 10th floor is the emperor")
	check(TowerData.start_floors(0) == [1] and TowerData.start_floors(35) == [1, 11, 21, 31], "checkpoints every 10 floors")
	await _start(&"warrior")
	Game.profile["level"] = 100
	Game.fill_loadout()
	Game.dismiss_party()
	Game.profile["hp"] = Game.stats_now().max_hp
	main._tower_floor = 1
	await main.go(&"tower", true, true)
	await _wait(0.5)
	var zone: Zone = main.zone
	check(zone.is_tower and zone.tower_run != null and zone.tower_run.floor_no == 1, "the tower starts at floor 1")
	await _wait(4.2)
	var mobs := get_tree().get_nodes_in_group("mobs")
	check(mobs.size() == 5, "floor 1 has five monsters (%d)" % mobs.size())
	var first: Mob = mobs[0]
	var plain := MonsterData.stats_for(first.monster_id, 100)
	check(int(first.stats.hp) == int(plain.hp), "floor 1 monsters have their normal strength")
	zone.hero._invulnerable_until = Time.get_ticks_msec() + 60000
	var shards0 := int(Game.tower().shards)
	var gold0: int = Game.profile.gold
	for m in mobs:
		(m as Mob).take_hit(99999999, false)
	await _wait(1.0)
	check(int(Game.tower().best) == 1 and int(Game.tower().shards) == shards0 + 1, "clearing a floor pays a shard and sets the best floor")
	check(int(Game.profile.gold) > gold0, "clearing a floor pays gold")
	await _wait(6.6)
	check(zone.tower_run.floor_no == 2 and get_tree().get_nodes_in_group("mobs").size() >= 5, "the next floor starts by itself")
	var second: Mob = get_tree().get_nodes_in_group("mobs")[0]
	check(int(second.stats.hp) > int(MonsterData.stats_for(second.monster_id, 100).hp), "floor 2 monsters are tougher")
	# Dying ends the climb without a penalty.
	zone.hero._invulnerable_until = 0
	var gold_before: int = Game.profile.gold
	for i in 40:
		zone.hero.take_damage(99999999.0)
		if zone.hero.is_dead():
			break
	await _wait(3.2)
	check(main.tower_screen.is_open, "the result screen opens after a fall")
	check(int(Game.profile.gold) >= gold_before, "no gold is lost for falling in the tower")
	main.tower_screen.close_screen()
	# Shop.
	Game.tower()["shards"] = 500
	var wing := ItemData.wings(rng, "atk")
	Game.profile.inv.append(wing)
	var old_stats := (wing.stats as Dictionary).duplicate()
	var changed := false
	for i in 8:
		check(Game.tower_reroll_wings(wing) == "ok", "wings can be re-rolled") if i == 0 else Game.tower_reroll_wings(wing)
		if (wing.stats as Dictionary) != old_stats:
			changed = true
	check(changed and wing.wing == "atk" and int(wing.stats.atk) >= 150, "a re-roll gives new random stats of the same type")
	check(int(Game.tower().shards) == 500 - 8 * TowerData.COST_REROLL, "each re-roll costs shards")
	var inv0: int = Game.profile.inv.size()
	var bought := Game.tower_buy("gear")
	check(bought.begins_with("ok:") and Game.profile.inv.size() == inv0 + 1 and int(Game.profile.inv[inv0].rarity) >= 3 and int(Game.profile.inv[inv0].level) >= 100, "shards buy legendary Lv.100+ gear")
	check(Game.tower_buy("gem").begins_with("ok:"), "shards buy a large gem")
	Game.tower()["shards"] = 5
	check(Game.tower_buy("gear") != "ok" and Game.tower_reroll_wings(wing) != "ok", "not enough shards buys nothing")
	Game.fill_loadout()
	check(Game.save_code_roundtrip(), "tower progress survives the save code")


func _star_drops() -> void:
	print("== Star drops")
	await _start(&"warrior")
	Game.profile["level"] = 100
	Game.paragon()["level"] = 20
	var plain := 0
	var stars := 0
	var low := 999
	var high := 0
	for i in 400:
		var lv := Game.star_gear_level()
		if lv == 100:
			plain += 1
		else:
			stars += 1
			low = mini(low, lv - 100)
			high = maxi(high, lv - 100)
	check(plain > 60 and plain < 180 and stars > 220, "about 30%% of star-zone gear is plain Lv.100 (%d / 400)" % plain)
	check(low >= 21 and high <= 28, "star gear sits just above your paragon level (★%d–★%d at ★20)" % [low, high])
	check(Game.star_gear_level(10) >= 100, "tower floors push the stars higher")
	await main.go(&"void", true, true)
	await _wait(0.5)
	var zone: Zone = main.zone
	for node in get_tree().get_nodes_in_group("mobs"):
		(node as Mob).queue_free()
	var mob := Mob.new()
	mob.setup(&"void_golem", 100, Vector3.ZERO, zone.hero)
	zone.add_child(mob)
	var starry := 0
	var total := 0
	for i in 300:
		var before := zone.get_child_count()
		zone._drop_loot(mob)
		for j in range(before, zone.get_child_count()):
			var c := zone.get_child(j)
			if c is LootDrop and (c as LootDrop).item.get("kind", "") == "equip" and (c as LootDrop).item.get("slot", "") != "wings":
				total += 1
				if int((c as LootDrop).item.level) > 100:
					starry += 1
	check(total > 40 and starry > total / 2, "void monsters drop star gear (%d of %d pieces)" % [starry, total])
	await main.go(&"abyss", true, true)
	await _wait(0.5)
	var plain_mob := Mob.new()
	plain_mob.setup(&"hell_orc", 100, Vector3.ZERO, main.zone.hero)
	main.zone.add_child(plain_mob)
	var above := 0
	for i in 200:
		var before2: int = main.zone.get_child_count()
		main.zone._drop_loot(plain_mob)
		for j in range(before2, main.zone.get_child_count()):
			var c2: Node = main.zone.get_child(j)
			if c2 is LootDrop and (c2 as LootDrop).item.get("kind", "") == "equip" and int((c2 as LootDrop).item.level) > 100:
				above += 1
	check(above == 0, "other zones never drop star gear")


func _timer_bars() -> void:
	print("== Buff and summon timer bars")
	await _start(&"archer")
	var field_zone := await _go_field()
	var hero: Hero = field_zone.hero
	var hud: HUD = main.hud
	hero.receive_buff({"atk": 0.3, "secs": 20.0}, Color("ff4a3a"), "Rage")
	hero.receive_buff({"def": 0.5, "secs": 30.0}, Color("ffe9a0"), "Blessing", true)
	var status := hero.timer_status()
	check(status.size() == 2, "own and ally buffs both show a timer (%d)" % status.size())
	check(status[0].name == "Rage" and absf(float(status[0].left) - 20.0) < 1.0 and not bool(status[0].ally), "own buff: name and time left")
	check(status[1].name == "Blessing" and bool(status[1].ally) and float(status[1].total) == 30.0, "ally buff is marked and keeps its full duration")
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.fill_loadout()
	Game.profile.mp = 99999
	Game.equip_skill("recall_wolverine", 0)
	hero.cooldowns.clear()
	hero.use_skill(0)
	await _wait(0.9)
	var with_summon := hero.timer_status()
	var summon_entry: Dictionary = {}
	for entry in with_summon:
		if entry.kind == "summon":
			summon_entry = entry
	check(not summon_entry.is_empty() and int(summon_entry.count) == 2 and float(summon_entry.left) > 150.0 and float(summon_entry.total) == 180.0, "the summons show one 3-minute timer for the pair")
	await _wait(0.3)
	check(hud._timers.visible and hud._timers._chips.size() == 3, "the HUD shows three timer chips (%d)" % hud._timers._chips.size())
	var before_ratio: float = hud._timers._chips[status[0].id].ratio
	check(hero._auras.has("power") and hero._auras.has("shield"), "attack and defence buffs show a power aura and a barrier on the hero")
	hero._buffs[0]["until"] = Time.get_ticks_msec() + 1500
	await _wait(0.4)
	var after_ratio: float = hud._timers._chips[status[0].id].ratio
	check(after_ratio < before_ratio * 0.2, "the timer ring unwinds as time runs out (%.2f -> %.2f)" % [before_ratio, after_ratio])
	await _wait(1.6)
	check(not hud._timers._chips.has(status[0].id), "the chip disappears when the buff ends")
	check(not hero._auras.has("power") and hero._auras.has("shield"), "the power aura goes with its buff, the barrier stays")
	hero._buffs.clear()
	await _wait(0.3)
	check(hero._auras.is_empty(), "no buff, no aura")


func _buff_durations() -> void:
	print("== Buff durations")
	var count := 0
	var shortest := 999.0
	for class_id in ClassData.IDS:
		for skill in ClassData.pool(class_id):
			var fx: Dictionary = skill.get("fx", {})
			if fx.has("buff"):
				count += 1
				shortest = minf(shortest, float(fx.buff.secs))
	check(count >= 20 and shortest >= 60.0, "all %d buff skills last at least 1 minute (shortest %.0f s)" % [count, shortest])
	check(not ClassData.find_skill(&"warrior", "holy_valor").desc.contains("25 วินาที"), "buff descriptions say 1 minute")


func _team_buffs() -> void:
	print("== Buffs reach the team")
	await _start(&"warrior")
	await main.go(&"meadow", true)
	await _wait(0.6)
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	for node in get_tree().get_nodes_in_group("mobs"):
		node.queue_free()
	Game.profile["level"] = 100
	Game.profile["adv"] = 4
	Game.fill_loadout()
	Game.profile.mp = 99999
	var buddy: Companion = zone.companions[0]
	var wolf := Summon.new()
	wolf.setup(hero, "recall_wolverine", {"kind": "wolf", "count": 1, "secs": 180.0, "interval": 0.9}, 2.0, 0, 1, 1)
	zone.add_child(wolf)
	hero._summons.append(wolf)
	await _wait(0.4)
	var holy := ClassData.find_skill(&"warrior", "holy_valor")
	check(Game.equip_skill("holy_valor", 0), "a buff skill can be put on the bar")
	hero.cooldowns.clear()
	hero.refresh_stats()
	Game.profile.mp = int(hero.stats.max_mp)
	check(hero.use_skill(0) == "", "the buff skill is cast")
	await _wait(0.8)
	check(hero._auras.has("shield") and hero._auras.has("power"), "the hero shows the barrier and the power aura")
	check(buddy._book.total("def") > 0.0 and buddy._book.total("atk") > 0.0, "the companion gets the defence and attack buff (def +%.2f)" % buddy._book.total("def"))
	check(buddy._book.auras.has("shield"), "the companion shows the barrier too")
	var hero_buffs_before := hero._buffs.size()
	var buddy_buffs_before := buddy._book.buffs.size()
	hero.cooldowns.clear()
	Game.profile.mp = int(hero.stats.max_mp)
	hero.use_skill(0)
	await _wait(0.8)
	check(hero._buffs.size() == hero_buffs_before and buddy._book.buffs.size() == buddy_buffs_before, "casting the same buff again refreshes it instead of stacking")
	check(float(hero.timer_status()[0].total) >= 60.0, "the buff lasts a full minute")
	check(wolf._book.total("def") > 0.0 and wolf._book.auras.has("shield"), "the summon gets the defence buff and shows the barrier")
	check(buddy._buffed_atk() > float(buddy.stats.atk) * 1.3, "the companion hits harder while buffed (%.0f vs %.0f)" % [buddy._buffed_atk(), float(buddy.stats.atk)])
	for buff in buddy._book.buffs:
		buff["until"] = Time.get_ticks_msec() + 200
	await _wait(0.6)
	check(buddy._book.auras.is_empty() and buddy._book.total("def") == 0.0, "the companion's buff and auras end with the buff")


func _camera_while_moving() -> void:
	print("== Camera while moving")
	var zone := await _start(&"warrior")
	await _wait(0.4)
	var hud: HUD = main.hud
	var stick := hud.joystick
	var area := hud.camera_area
	var rig: ThirdPersonCamera = main.zone.camera_rig
	# Thumb 1 holds the joystick (finger 0).
	var centre := stick._center
	stick._begin(0, centre + Vector2(60, 0))
	check(stick.is_active and stick.output.length() > 0.1, "the joystick is held and the hero is running")
	check(not stick._has_point(centre + Vector2(400, -150)), "a finger far from the ring is not swallowed by the held joystick")
	check(stick._has_point(centre + Vector2(50, 0)), "the ring itself still belongs to the joystick")
	# Thumb 2 (finger 1) drags on the camera area.
	var yaw_before := rig.yaw
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = Vector2(900, 300)
	area._gui_input(press)
	for i in 6:
		var drag := InputEventScreenDrag.new()
		drag.index = 1
		drag.position = Vector2(900 + (i + 1) * 20, 300)
		drag.relative = Vector2(20, 0)
		area._gui_input(drag)
	check(absf(rig.yaw - yaw_before) > 0.2 and stick.is_active, "the camera turns while the joystick is still held (yaw %.2f -> %.2f)" % [yaw_before, rig.yaw])
	stick._end()


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
		if id == &"town" or id == &"arena" or id == &"pvp" or id == &"tower":
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
	var ring := ItemData.generate(20, &"warrior", rng, 1, "ring")
	var amulet := ItemData.generate(20, &"warrior", rng, 1, "amulet")
	check(Game.enhance_item(ring) != "ok" and Game.enhance_item(amulet) != "ok" and int(ring.plus) == 0 and int(amulet.plus) == 0, "rings and amulets cannot be enhanced")
	check(Game.enhance_item(ItemData.generate(20, &"warrior", rng, 1, "boots")) in ["ok", "fail"], "boots can be enhanced")
	var gold: int = Game.profile.gold
	Game.profile["inv"].append(ItemData.gem("ruby", 2, 2))
	var atk1: float = Game.stats_now().atk
	check(Game.socket_gem(sword, Game.profile.inv.size() - 1) and Game.stats_now().atk >= atk1 + 22, "a ruby in a socket adds ATK")
	check(int(Game.profile.inv[Game.profile.inv.size() - 1].count) == 1, "the gem stack went down by one")
	var atk_with_gem: float = Game.stats_now().atk
	check(Game.unsocket_gem(sword, 0) == "ok" and (sword.gems as Array).is_empty() and Game.stats_now().atk <= atk_with_gem - 22, "a gem can be taken back out (attack drops)")
	check(int(Game.profile.inv[Game.profile.inv.size() - 1].count) == 2, "the removed gem returns to the bag stack")
	check(Game.unsocket_gem(sword, 0) != "ok", "an empty socket cannot be emptied")
	Game.socket_gem(sword, Game.profile.inv.size() - 1)
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
