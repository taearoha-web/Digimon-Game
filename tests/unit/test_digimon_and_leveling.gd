extends TestCase


func test_instance_stats_come_from_species() -> void:
	var inst := DigimonInstance.create(&"agumon", 5, seeded_rng(3))
	var species := GameData.get_species(&"agumon")
	var expected_hp := int(round(species.base_hp + species.growth_hp * 4)) + int(inst.bonus_stats[DigimonStats.MAX_HP])
	check_eq(inst.get_max_hp(), expected_hp, "hp formula")
	check_eq(inst.current_hp, inst.get_max_hp(), "starts healed")
	check(inst.known_skills.has(&"ember_breath"), "innate skill")
	check(inst.equipped_skills.size() >= 1 and inst.equipped_skills.size() <= DigimonInstance.MAX_EQUIPPED_SKILLS, "equipped size")


func test_species_data_is_not_mutated() -> void:
	var species := GameData.get_species(&"gabumon")
	var base_before := species.base_attack
	var inst := DigimonInstance.create(&"gabumon", 5)
	Leveling.grant_exp(inst, 5000)
	check_eq(species.base_attack, base_before, "species untouched after level ups")
	check(inst.level > 5, "instance leveled")


func test_serialization_roundtrip() -> void:
	var inst := DigimonInstance.create(&"patamon", 7, seeded_rng(9))
	inst.nickname = "Pat"
	inst.friendship = 42
	inst.take_damage(10)
	var copy := DigimonInstance.from_dict(JSON.parse_string(JSON.stringify(inst.to_dict())))
	check_eq(copy.uid, inst.uid, "uid")
	check_eq(copy.species_id, inst.species_id, "species")
	check_eq(copy.level, 7, "level")
	check_eq(copy.current_hp, inst.current_hp, "hp")
	check_eq(copy.friendship, 42, "friendship")
	check_eq(copy.get_display_name(), "Pat", "nickname")
	check_eq(copy.get_stat(DigimonStats.ATTACK), inst.get_stat(DigimonStats.ATTACK), "stats")
	check_eq(copy.known_skills, inst.known_skills, "skills")


func test_heal_damage_revive() -> void:
	var inst := DigimonInstance.create(&"agumon", 5)
	var max_hp := inst.get_max_hp()
	check_eq(inst.take_damage(9999), max_hp, "damage clamps")
	check(inst.is_fainted(), "fainted")
	check_eq(inst.heal(20), 0, "cannot heal fainted")
	check(inst.revive(50), "revive")
	check_eq(inst.current_hp, int(max_hp * 0.5), "revived at 50%")
	check(not inst.revive(50), "cannot revive twice")


func test_skill_equip_rules() -> void:
	var inst := DigimonInstance.create(&"agumon", 20)
	check(inst.known_skills.size() >= 4, "knows several skills")
	check_eq(inst.equipped_skills.size(), mini(inst.known_skills.size(), 4), "auto equip up to 4")
	while inst.equipped_skills.size() > 1:
		check(inst.set_skill_equipped(inst.equipped_skills[0], false), "unequip")
	check(not inst.set_skill_equipped(inst.equipped_skills[0], false), "must keep one skill")


func test_exp_curve_increases() -> void:
	var previous := 0
	for level in range(1, 60):
		var need := Leveling.exp_to_next(level)
		check(need > previous, "curve strictly increasing at %d" % level)
		previous = need
	check_eq(Leveling.exp_to_next(Leveling.MAX_LEVEL), 0, "no exp at max level")


func test_level_up_learns_skills_and_grows_stats() -> void:
	var inst := DigimonInstance.create(&"agumon", 5, seeded_rng(4))
	var atk := inst.get_stat(DigimonStats.ATTACK)
	check(not inst.known_skills.has(&"claw_swipe"), "claw swipe learned at 6")
	var ups := Leveling.grant_exp(inst, Leveling.exp_to_next(5))
	check_eq(ups.size(), 1, "one level up")
	check_eq(inst.level, 6, "now level 6")
	check(inst.known_skills.has(&"claw_swipe"), "learned claw swipe")
	check(ups[0].learned.has(&"claw_swipe"), "level up record lists new skill")
	check(inst.get_stat(DigimonStats.ATTACK) > atk, "attack grew")


func test_multi_level_gain() -> void:
	var inst := DigimonInstance.create(&"gabumon", 5)
	var total := 0
	for level in range(5, 9):
		total += Leveling.exp_to_next(level)
	var ups := Leveling.grant_exp(inst, total + 3)
	check_eq(ups.size(), 4, "four levels")
	check_eq(inst.level, 9, "level 9")
	check_eq(inst.experience, 3, "leftover exp")


func test_exp_reward_scales_with_level() -> void:
	var species := GameData.get_species(&"kunemon")
	var low := Leveling.exp_reward(species, 3, 5)
	var high := Leveling.exp_reward(species, 7, 5)
	check(high > low, "higher level foes give more EXP")
	check(low >= 1, "minimum 1 EXP")
