extends TestCase


func _combatants(att_species: StringName, att_level: int, def_species: StringName, def_level: int) -> Array:
	var a := BattleCombatant.new(DigimonInstance.create(att_species, att_level, seeded_rng(1)), BattleCombatant.PLAYER_SIDE)
	var d := BattleCombatant.new(DigimonInstance.create(def_species, def_level, seeded_rng(2)), BattleCombatant.ENEMY_SIDE)
	return [a, d]


func test_damage_is_positive_and_varies() -> void:
	var c := _combatants(&"agumon", 5, &"kunemon", 4)
	var skill := GameData.get_skill(&"ember_breath")
	var rng := seeded_rng(5)
	var amounts := {}
	for i in 30:
		var r := DamageCalculator.calculate(c[0], c[1], skill, rng, GameData.type_chart, {"no_crit": true})
		check(int(r.amount) > 0, "positive damage")
		amounts[int(r.amount)] = true
	check(amounts.size() > 1, "random variation present")


func test_type_advantage() -> void:
	var chart := GameData.type_chart
	var fire := GameData.get_skill(&"ember_breath")
	var agumon := GameData.get_species(&"agumon")
	var palmon := GameData.get_species(&"palmon")
	var gabumon := GameData.get_species(&"gabumon")
	check(DamageCalculator.get_type_multiplier(agumon, palmon, fire, chart) > 1.2, "fire vs plant strong")
	var goburimon := GameData.get_species(&"goburimon")
	check(DamageCalculator.get_type_multiplier(agumon, goburimon, fire, chart) < 1.0, "fire vs earth weak")
	# Attribute triangle: Vaccine (Agumon) beats Virus (Kunemon).
	check(chart.get_attribute_multiplier(DigimonSpecies.Attribute.VACCINE, DigimonSpecies.Attribute.VIRUS) > 1.0, "vaccine > virus")
	check(chart.get_attribute_multiplier(DigimonSpecies.Attribute.DATA, DigimonSpecies.Attribute.VACCINE) > 1.0, "data > vaccine")
	check(chart.get_attribute_multiplier(DigimonSpecies.Attribute.VIRUS, DigimonSpecies.Attribute.DATA) > 1.0, "virus > data")
	check_eq(DamageCalculator.get_type_multiplier(gabumon, gabumon, GameData.get_skill(&"tackle"), chart), 1.0, "neutral mirror")


func test_crit_defend_and_stages() -> void:
	var c := _combatants(&"agumon", 10, &"goburimon", 10)
	var skill := GameData.get_skill(&"tackle")
	var chart := GameData.type_chart
	var base: int = DamageCalculator.calculate(c[0], c[1], skill, seeded_rng(1), chart, {"no_crit": true, "no_variance": true}).amount
	var crit: int = DamageCalculator.calculate(c[0], c[1], skill, seeded_rng(1), chart, {"force_crit": true, "no_variance": true}).amount
	check(crit > base, "critical hits deal more")
	c[1].is_defending = true
	var defended: int = DamageCalculator.calculate(c[0], c[1], skill, seeded_rng(1), chart, {"no_crit": true, "no_variance": true}).amount
	check(defended < base, "defending reduces damage")
	c[1].is_defending = false
	c[0].modify_stage(DigimonStats.ATTACK, 2)
	var buffed: int = DamageCalculator.calculate(c[0], c[1], skill, seeded_rng(1), chart, {"no_crit": true, "no_variance": true}).amount
	check(buffed > base, "attack buff increases damage")
	check_eq(c[0].modify_stage(DigimonStats.ATTACK, 10), 2, "stages clamp at +4")


func _battle(party_species: Array, enemy: StringName, enemy_level: int, seed_value := 7) -> BattleController:
	var party: Array[DigimonInstance] = []
	for s in party_species:
		party.append(DigimonInstance.create(s, 6, seeded_rng(seed_value)))
	var inv := Inventory.new()
	inv.add_item(&"small_patch", 2)
	var controller := BattleController.new()
	controller.setup(party, DigimonInstance.create(enemy, enemy_level, seeded_rng(seed_value + 1)), BattleRequest.wild(enemy, enemy_level), inv, seeded_rng(seed_value))
	controller.start()
	return controller


func test_full_battle_reaches_victory() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3)
	var turns := 0
	while not controller.is_finished() and turns < 40:
		var events := controller.submit({"type": "skill", "skill_id": &"tackle"})
		check(not events.is_empty(), "turn produces events")
		turns += 1
	check(controller.is_finished(), "battle ends")
	check_eq(controller.outcome, BattleController.Outcome.VICTORY, "strong starter wins")
	var summary := BattleRewards.apply_victory(controller)
	check_eq(summary.exp_entries.size(), 1, "exp entry")
	check(int(summary.exp_entries[0].amount) > 0, "exp awarded")


func test_turn_order_uses_speed() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3)
	controller.player.instance.bonus_stats[DigimonStats.SPEED] = 200
	var events := controller.submit({"type": "skill", "skill_id": &"tackle"})
	var first_skill: Dictionary = {}
	for e in events:
		if e.type == "skill":
			first_skill = e
			break
	check_eq(int(first_skill.side), BattleCombatant.PLAYER_SIDE, "faster player acts first")


func test_invalid_commands_do_not_consume_turn() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3)
	controller.player.instance.current_sp = 0
	var events := controller.submit({"type": "skill", "skill_id": &"ember_breath"})
	check_eq(controller.turn, 0, "no turn used")
	check_eq(str(events.back().type), "invalid", "invalid event")
	events = controller.submit({"type": "switch", "index": 0})
	check_eq(str(events.back().type), "invalid", "cannot switch to active")


func test_defend_restores_sp_and_items_heal() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3)
	controller.player.instance.current_sp = 0
	controller.submit({"type": "defend"})
	check(controller.player.instance.current_sp > 0, "defend restores SP")
	controller.player.instance.take_damage(30)
	var hp := controller.player.instance.current_hp
	if not controller.is_finished():
		controller.submit({"type": "item", "item_id": &"small_patch", "target_uid": controller.player.instance.uid})
		check(controller.player.instance.current_hp > hp - 20, "item healed (minus enemy hit)")
		check_eq(controller.inventory.count(&"small_patch"), 1, "item consumed")


func test_forced_switch_and_defeat() -> void:
	var controller := _battle([&"agumon", &"gabumon"], &"goburimon", 30)
	var turns := 0
	var saw_switch := false
	while not controller.is_finished() and turns < 60:
		if controller.phase == BattleController.Phase.AWAITING_SWITCH:
			saw_switch = true
			controller.submit_switch(1)
		else:
			controller.submit({"type": "skill", "skill_id": &"tackle"})
		turns += 1
	check(saw_switch, "forced switch offered when lead fainted")
	check_eq(controller.outcome, BattleController.Outcome.DEFEAT, "overwhelming foe wins")


func test_escape_and_befriend() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3, 11)
	controller.player.instance.bonus_stats[DigimonStats.SPEED] = 500
	controller.submit({"type": "escape"})
	check_eq(controller.outcome, BattleController.Outcome.ESCAPED, "much faster player escapes")
	var controller2 := _battle([&"agumon"], &"kunemon", 3, 12)
	controller2.enemy.instance.current_hp = 1
	controller2.enemy.befriend_bonus = 5.0
	controller2.submit({"type": "befriend"})
	check_eq(controller2.outcome, BattleController.Outcome.RECRUITED, "befriend succeeds at max chance")
	check_not_null(controller2.recruited_instance, "recruit created")
	check_eq(controller2.recruited_instance.species_id, &"kunemon", "recruit species")


func test_status_effects_tick() -> void:
	var controller := _battle([&"agumon"], &"kunemon", 3)
	controller.player.apply_status(&"poison", 3)
	var hp := controller.player.instance.current_hp
	controller.submit({"type": "defend"})
	check(controller.player.instance.current_hp < hp, "poison deals damage at end of turn")
	check(not controller.player.apply_status(&"stun", 2), "only one status at a time")


func test_recruitment_chance_scales_with_hp() -> void:
	var cfg := GameData.recruitment_config
	var a := BattleCombatant.new(DigimonInstance.create(&"agumon", 6), BattleCombatant.PLAYER_SIDE)
	var e := BattleCombatant.new(DigimonInstance.create(&"palmon", 5), BattleCombatant.ENEMY_SIDE)
	var full := RecruitmentService.befriend_chance(e, a, cfg, 0)
	e.instance.current_hp = 1
	var low := RecruitmentService.befriend_chance(e, a, cfg, 0)
	check(low > full, "weakened targets are easier")
	check(low <= cfg.max_chance and full >= cfg.min_chance, "clamped")
	var progressed := RecruitmentService.befriend_chance(e, a, cfg, 3)
	check(progressed > low, "quest progression helps")
	var post := RecruitmentService.post_defeat_chance(e.get_species(), 5, 6, cfg, 0)
	check(post < low, "post-defeat offer is rarer than befriending")
