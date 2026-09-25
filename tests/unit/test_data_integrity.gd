extends TestCase
## Validates cross references between data resources (catches typos early).


func test_species_references() -> void:
	var all := GameData.get_all_species()
	check(all.size() >= 19, "expected at least 19 species, got %d" % all.size())
	for species in all:
		check(species.display_name != "", "%s has no display name" % species.id)
		check(species.description != "", "%s has no description" % species.id)
		check(not species.innate_skills.is_empty(), "%s has no innate skills" % species.id)
		for skill_id in species.get_skills_up_to(99):
			check_not_null(GameData.get_skill(skill_id), "%s references missing skill %s" % [species.id, skill_id])
		for path in species.evolutions:
			check_not_null(GameData.get_species(path.target_species_id), "%s evolves into missing %s" % [species.id, path.target_species_id])
			if path.required_item_id != &"":
				check_not_null(GameData.get_item(path.required_item_id), "%s evolution needs missing item" % species.id)
		for item_id in species.drop_table.keys():
			check_not_null(GameData.get_item(StringName(item_id)), "%s drops missing item %s" % [species.id, item_id])
		check(species.placeholder_colors.size() >= 3, "%s needs placeholder colours" % species.id)


func test_starter_roster() -> void:
	var roster := GameData.starter_roster
	check_eq(roster.starter_ids.size(), 3, "starter count")
	for id in [&"agumon", &"gabumon", &"patamon"]:
		check(roster.starter_ids.has(id), "starter %s missing" % id)
		var species := GameData.get_species(id)
		check_not_null(species)
		check_eq(species.stage, DigimonSpecies.Stage.ROOKIE, "%s stage" % id)
		check(not species.evolutions.is_empty(), "%s has an evolution" % id)
	for item_id in roster.starting_items.keys():
		check_not_null(GameData.get_item(StringName(item_id)), "starting item %s" % item_id)


func test_quest_references() -> void:
	var quests := GameData.get_all_quests()
	check(quests.size() >= 3, "expected 3 quests")
	for quest in quests:
		check(not quest.objectives.is_empty(), "%s has no objectives" % quest.id)
		for npc_id in [quest.giver_npc_id, quest.turn_in_npc_id]:
			if npc_id != &"":
				check_not_null(GameData.get_npc(npc_id), "%s references missing NPC %s" % [quest.id, npc_id])
		for d in [quest.offer_dialogue_id, quest.in_progress_dialogue_id, quest.turn_in_dialogue_id, quest.after_dialogue_id]:
			if d != &"":
				check_not_null(GameData.get_dialogue(d), "%s references missing dialogue %s" % [quest.id, d])
		for item_id in quest.reward_items.keys():
			check_not_null(GameData.get_item(StringName(item_id)), "%s rewards missing item %s" % [quest.id, item_id])
		for prereq in quest.prerequisite_quest_ids:
			check_not_null(GameData.get_quest(prereq), "%s prerequisite %s" % [quest.id, prereq])


func test_npcs_and_dialogue() -> void:
	for npc in GameData.get_all("npcs"):
		check_not_null(GameData.get_dialogue(npc.default_dialogue_id), "%s default dialogue" % npc.id)
		check(not npc.appearance.is_empty(), "%s appearance" % npc.id)
		check(npc.service in [&"", &"heal_party", &"shop"], "%s service '%s' is known" % [npc.id, npc.service])
		if npc.service == &"shop":
			check_not_null(GameData.get_shop(npc.shop_id), "%s shop %s" % [npc.id, npc.shop_id])
	for d in GameData.get_all("dialogue"):
		check(not d.lines.is_empty(), "dialogue %s is empty" % d.id)
		for line in d.lines:
			check(line.text.strip_edges() != "", "dialogue %s has an empty line" % d.id)


func test_encounter_tables() -> void:
	for table in GameData.get_all("encounters"):
		check(not table.entries.is_empty(), "%s has no entries" % table.id)
		check(table.max_active > 0 and table.max_active <= 8, "%s max_active sane" % table.id)
		for entry in table.entries:
			check_not_null(GameData.get_species(entry.species_id), "%s spawns missing %s" % [table.id, entry.species_id])
			check(entry.min_level >= 1 and entry.min_level <= entry.max_level, "%s level range" % table.id)


func test_items_and_icons() -> void:
	for item in GameData.get_all("items"):
		check(item.display_name != "", "%s name" % item.id)
		check(item.max_stack >= 1, "%s stack" % item.id)
		check(ResourceLoader.exists(item.icon_path), "%s icon %s" % [item.id, item.icon_path])
		check(item.sell_price <= item.buy_price or item.buy_price == 0, "%s sells for less than it costs" % item.id)
		if item.is_equipment():
			check(not item.equip_bonuses.is_empty(), "%s has equip bonuses" % item.id)
			for stat in item.equip_bonuses.keys():
				check(DigimonStats.ALL.has(StringName(stat)), "%s bonus stat %s is valid" % [item.id, stat])
		else:
			check(item.equip_bonuses.is_empty(), "%s is not equipment but has bonuses" % item.id)


func test_shops() -> void:
	check(GameData.get_all("shops").size() >= 2, "shops registered")
	for shop in GameData.get_all("shops"):
		check(shop.display_name != "", "%s name" % shop.id)
		check(not shop.stock.is_empty(), "%s has stock" % shop.id)
		for item_id in shop.stock:
			var item := GameData.get_item(item_id)
			if check_not_null(item, "%s sells missing %s" % [shop.id, item_id]):
				check(item.buy_price > 0, "%s sells %s with a price" % [shop.id, item_id])
				check(item.category != ItemData.Category.QUEST and item.category != ItemData.Category.KEY,
					"%s must not sell quest/key item %s" % [shop.id, item_id])


func test_maps_and_scenes() -> void:
	for map_data in GameData.get_all("maps"):
		check(ResourceLoader.exists(map_data.scene_path), "map %s scene" % map_data.id)
		check(AudioManager.has_music(map_data.music_id), "map %s music %s" % [map_data.id, map_data.music_id])
		# Every portal must lead to a registered map and an existing spawn point.
		var scene := (load(map_data.scene_path) as PackedScene).instantiate()
		check_not_null(scene.get_node_or_null("SpawnPoints/%s" % map_data.default_spawn_id),
			"map %s default spawn %s" % [map_data.id, map_data.default_spawn_id])
		for node in scene.find_children("*", "Portal", true, false):
			var portal := node as Portal
			var target := GameData.get_map(portal.target_map_id)
			if check_not_null(target, "%s portal %s -> map %s" % [map_data.id, portal.name, portal.target_map_id]):
				var target_scene := (load(target.scene_path) as PackedScene).instantiate()
				check_not_null(target_scene.get_node_or_null("SpawnPoints/%s" % portal.target_spawn_id),
					"%s portal %s -> spawn %s" % [map_data.id, portal.name, portal.target_spawn_id])
				target_scene.free()
		for node in scene.find_children("*", "EncounterSpawner", true, false):
			check_not_null(GameData.get_encounter_table((node as EncounterSpawner).table_id),
				"%s spawner %s table" % [map_data.id, node.name])
		for npc in scene.find_children("*", "Npc", true, false):
			check_not_null(GameData.get_npc((npc as Npc).npc_id), "%s npc %s data" % [map_data.id, npc.name])
		scene.free()
	for key in SceneManager.SCENES.keys():
		check(ResourceLoader.exists(SceneManager.SCENES[key]), "scene %s -> %s" % [key, SceneManager.SCENES[key]])


func test_customization_catalog() -> void:
	var catalog := GameData.customization_catalog
	check_eq(catalog.body_types.size(), 2, "two body types")
	check(catalog.hair_styles.size() >= 5, "hair styles")
	check(catalog.faces.size() >= 3, "faces")
	check_eq(catalog.tops.size(), 4, "tops")
	check_eq(catalog.bottoms.size(), 3, "bottoms")
	check_eq(catalog.shoes.size(), 2, "shoes")
	check_eq(catalog.accessories.size(), 3, "accessories")
	check(catalog.skin_tones.size() >= 4 and catalog.hair_colors.size() >= 6 and catalog.clothing_colors.size() >= 8, "palettes")


func test_skills_are_data_driven() -> void:
	for skill in GameData.get_all("skills"):
		check(skill.display_name != "", "%s name" % skill.id)
		check(not skill.effects.is_empty(), "%s has effects" % skill.id)
		check(skill.accuracy > 0 and skill.accuracy <= 100, "%s accuracy" % skill.id)
		if skill.deals_damage():
			check(skill.power > 0, "%s damaging skill needs power" % skill.id)
		check(BattleVfx.PRESETS.has(skill.vfx), "%s vfx preset %s" % [skill.id, skill.vfx])
