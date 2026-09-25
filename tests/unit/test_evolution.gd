extends TestCase


func _ctx(inventory: Inventory) -> Dictionary:
	return {"inventory": inventory, "quest_log": QuestLog.new(), "flags": {}}


func test_level_requirement() -> void:
	var inv := Inventory.new()
	var inst := DigimonInstance.create(&"agumon", 5)
	check(not EvolutionService.can_evolve(inst, _ctx(inv)), "not ready at 5")
	Leveling.grant_exp(inst, 100000)
	check(EvolutionService.can_evolve(inst, _ctx(inv)), "ready at high level")


func test_item_path_needs_item_and_level() -> void:
	var inv := Inventory.new()
	var inst := DigimonInstance.create(&"gabumon", 7)
	var paths := EvolutionService.get_ready_paths(inst, _ctx(inv))
	check(paths.is_empty(), "no shard, not level 10")
	inv.add_item(&"evo_shard", 1)
	paths = EvolutionService.get_ready_paths(inst, _ctx(inv))
	check_eq(paths.size(), 1, "shard path ready at Lv 7")
	check_eq(paths[0].required_item_id, &"evo_shard", "uses shard path")


func test_evolve_preserves_progress_and_consumes_item() -> void:
	var inv := Inventory.new()
	inv.add_item(&"evo_shard", 1)
	var inst := DigimonInstance.create(&"patamon", 7)
	inst.friendship = 30
	inst.experience = 12
	inst.take_damage(10)
	var ratio_before := inst.get_hp_ratio()
	var uid := inst.uid
	var path: EvolutionPath = EvolutionService.get_ready_paths(inst, _ctx(inv))[0]
	var result := EvolutionService.evolve(inst, path, _ctx(inv))
	check(result.ok, "evolved")
	check_eq(inst.species_id, &"angemon", "new species")
	check_eq(inst.uid, uid, "same individual")
	check_eq(inst.level, 7, "level kept")
	check_eq(inst.experience, 12, "exp kept")
	check(inst.friendship >= 30, "friendship kept")
	check(inst.evolution_history.has(&"patamon"), "history recorded")
	check(inst.known_skills.has(&"air_pop"), "old skills kept")
	check(inst.known_skills.has(&"soothing_light"), "new species skills learned")
	check_near(inst.get_hp_ratio(), ratio_before, 0.05, "hp ratio preserved")
	check_eq(inv.count(&"evo_shard"), 0, "shard consumed")
	check(int(result.after[DigimonStats.MAX_HP]) > int(result.before[DigimonStats.MAX_HP]), "champion is stronger")


func test_unmet_requirements_are_described() -> void:
	var inst := DigimonInstance.create(&"agumon", 5)
	var status := EvolutionService.get_paths_status(inst, _ctx(Inventory.new()))
	check_eq(status.size(), 2, "two paths")
	for s in status:
		check(not s.ready, "not ready")
		check(not (s.unmet as PackedStringArray).is_empty(), "explains why")


func test_quest_and_flag_requirements() -> void:
	var path := EvolutionPath.new()
	path.target_species_id = &"greymon"
	path.required_quest_id = &"q_first_steps"
	path.required_flag = &"gateway_unlocked"
	var inst := DigimonInstance.create(&"agumon", 5)
	var log := QuestLog.new()
	var ctx := {"inventory": Inventory.new(), "quest_log": log, "flags": {}}
	check_eq(EvolutionService.get_unmet_requirements(inst, path, ctx).size(), 2, "quest + flag unmet")
	log.set_state(&"q_first_steps", QuestLog.State.REWARDED)
	ctx.flags = {&"gateway_unlocked": true}
	check(EvolutionService.get_unmet_requirements(inst, path, ctx).is_empty(), "all met")
