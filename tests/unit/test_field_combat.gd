extends TestCase
## Real-time field combat: skill shapes in the data, the resolver that applies
## skills, status/stage timers and kill rewards (no scene needed).


func _pair(att: StringName, att_level: int, def: StringName, def_level: int) -> Array:
	var a := BattleCombatant.new(DigimonInstance.create(att, att_level, seeded_rng(1)), BattleCombatant.PLAYER_SIDE)
	var d := BattleCombatant.new(DigimonInstance.create(def, def_level, seeded_rng(2)), BattleCombatant.ENEMY_SIDE)
	return [a, d]


func test_every_skill_has_field_data() -> void:
	var single := 0
	var area := 0
	for id in _all_skill_ids():
		var skill := GameData.get_skill(id)
		check(skill.cooldown > 0.0, "%s has a cooldown" % id)
		if skill.target == SkillData.Target.SELF:
			check_eq(skill.get_engage_range(), 0.0, "%s self skill needs no approach" % id)
			continue
		check(skill.get_engage_range() > 0.0, "%s has an engage range" % id)
		if skill.is_area():
			area += 1
			check(skill.area_radius >= 2.0, "%s area radius" % id)
		else:
			single += 1
			check_eq(skill.area_radius, 0.0, "%s single target has no radius" % id)
	check(single >= 8 and area >= 8, "mix of single (%d) and area (%d) skills" % [single, area])


func test_starters_have_single_and_area_skills() -> void:
	for id in [&"agumon", &"gabumon", &"patamon"]:
		var inst := DigimonInstance.create(id, 5, seeded_rng(3))
		var shapes := {}
		for skill_id in inst.equipped_skills:
			var skill := GameData.get_skill(skill_id)
			shapes[skill.is_area()] = true
		check(shapes.has(true) and shapes.has(false), "%s starts with a single-target and an area skill" % id)


func test_engage_range_by_shape() -> void:
	var burst := GameData.get_skill(&"whirlwind")
	check_eq(burst.shape, SkillData.Shape.BURST, "whirlwind is a burst")
	check_near(burst.get_engage_range(), burst.area_radius * 0.75, 0.001, "burst closes in to 75% of its radius")
	var blast := GameData.get_skill(&"inferno_burst")
	check_eq(blast.shape, SkillData.Shape.BLAST, "inferno burst is a blast")
	check_eq(blast.get_engage_range(), blast.cast_range, "blast fires from cast range")
	var tackle := GameData.get_skill(&"tackle")
	check(tackle.get_engage_range() < 3.0, "melee skills need to get close")


func test_damage_event_and_kill() -> void:
	var c := _pair(&"agumon", 20, &"koromon", 2)
	var rng := seeded_rng(9)
	var skill := GameData.get_skill(&"claw_swipe")
	var hp_before: int = c[1].instance.current_hp
	var events := FieldSkillResolver.resolve(c[0], c[1], skill, rng, GameData.type_chart)
	var damage := events.filter(func(e): return e.type == "damage")
	if damage.is_empty():
		check(events[0].type == "miss", "either hit or miss")
		return
	check(c[1].instance.current_hp < hp_before, "target lost HP")
	check_eq(int(damage[0].hp), c[1].instance.current_hp, "event reports the new HP")
	# A strong hit on a weak monster kills it and says so.
	for i in 10:
		events = FieldSkillResolver.resolve(c[0], c[1], GameData.get_skill(&"inferno_burst"), rng, GameData.type_chart)
	check(c[1].is_fainted(), "repeated hits faint the target")
	var last := events.filter(func(e): return e.type == "damage")
	check(last.is_empty() or bool(last[-1].killed), "kill flag set when the target faints")


func test_damage_scale_reduces_hits() -> void:
	var full := _pair(&"agumon", 10, &"goburimon", 10)
	var scaled := _pair(&"agumon", 10, &"goburimon", 10)
	var skill := GameData.get_skill(&"tackle")
	var a := FieldSkillResolver.resolve(full[0], full[1], skill, seeded_rng(4), GameData.type_chart)
	var b := FieldSkillResolver.resolve(scaled[0], scaled[1], skill, seeded_rng(4), GameData.type_chart, 0.5)
	if a[0].type == "damage" and b[0].type == "damage":
		check(int(b[0].amount) < int(a[0].amount), "damage scale lowers the hit (%d vs %d)" % [int(b[0].amount), int(a[0].amount)])
		check(int(b[0].amount) >= 1, "never below 1")


func test_self_skills_heal_and_buff() -> void:
	var c := _pair(&"patamon", 10, &"kunemon", 8)
	c[0].instance.take_damage(30)
	var events := FieldSkillResolver.resolve(c[0], null, GameData.get_skill(&"soothing_light"), seeded_rng(5), GameData.type_chart)
	check(events.any(func(e): return e.type == "heal" and e.amount > 0), "healing skill heals the user")
	var buff := FieldSkillResolver.resolve(c[0], null, GameData.get_skill(&"battle_cry"), seeded_rng(5), GameData.type_chart)
	check(buff.any(func(e): return e.type == "stat" and e.delta > 0), "battle cry raises a stat")
	check_eq(c[0].stages.get(&"attack", 0), 1, "attack stage +1")
	check(c[0].field_stage_time > 0.0, "buff has a duration")
	FieldSkillResolver.tick(c[0], FieldSkillResolver.STAGE_SECONDS + 1.0)
	check(c[0].stages.is_empty(), "buff wears off")


func test_debuff_and_status_on_enemy() -> void:
	var c := _pair(&"agumon", 10, &"palmon", 8)
	var events := FieldSkillResolver.resolve(c[0], c[1], GameData.get_skill(&"menace"), seeded_rng(1), GameData.type_chart)
	if events[0].type != "miss":
		check_eq(c[1].stages.get(&"attack", 0), -1, "menace lowers Attack")
	var poison := SkillData.new()
	poison.target = SkillData.Target.ENEMY
	poison.accuracy = 100
	var effect := SkillEffect.new()
	effect.type = SkillEffect.Type.STATUS
	effect.status_id = &"poison"
	effect.duration = 2
	poison.effects = [effect]
	var result := FieldSkillResolver.resolve(c[0], c[1], poison, seeded_rng(2), GameData.type_chart)
	check(result.any(func(e): return e.type == "status"), "status applied")
	check_eq(c[1].status_id, &"poison", "poisoned")
	var hp: int = c[1].instance.current_hp
	var ticks: Array[Dictionary] = []
	for i in 6:
		ticks.append_array(FieldSkillResolver.tick(c[1], 0.5))
	check(c[1].instance.current_hp < hp, "poison deals damage over time")
	check(ticks.any(func(e): return e.type == "status_end"), "poison ends after its duration")
	check_eq(c[1].status_id, &"", "status cleared")


func test_stun_disables_and_slows() -> void:
	var c := _pair(&"agumon", 10, &"palmon", 8)
	check(not FieldSkillResolver.is_disabled(c[1]), "not stunned at first")
	c[1].apply_status(&"stun", 2)
	c[1].field_status_time = 3.0
	check(FieldSkillResolver.is_disabled(c[1]), "stun disables")
	check(FieldSkillResolver.speed_factor(c[1]) < 0.9, "stun slows movement")


func test_rewards_exp_drops_and_recruit() -> void:
	var party: Array[DigimonInstance] = [DigimonInstance.create(&"agumon", 5, seeded_rng(1)), DigimonInstance.create(&"gabumon", 5, seeded_rng(2))]
	var species := GameData.get_species(&"kunemon")
	var rng := seeded_rng(11)
	var exp_before: int = party[0].experience
	var summary := FieldRewards.apply_victory(species, 5, party, [party[0].uid], rng, GameData.recruitment_config, 0)
	check_eq(summary.exp_entries.size(), 2, "both healthy party members share EXP")
	var lead_entry: Dictionary = summary.exp_entries[0]
	var bench_entry: Dictionary = summary.exp_entries[1]
	check(lead_entry.participated and not bench_entry.participated, "participation tracked")
	check(int(lead_entry.amount) > int(bench_entry.amount), "participant earns more than the bench")
	check(party[0].experience > exp_before or party[0].level > 5, "EXP applied to the instance")
	party[1].take_damage(9999)
	var again := FieldRewards.apply_victory(species, 5, party, [party[0].uid], rng, GameData.recruitment_config, 0)
	check_eq(again.exp_entries.size(), 1, "fainted members earn nothing")


func _all_skill_ids() -> Array:
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/skills"):
		if f.ends_with(".tres"):
			ids.append(StringName(f.get_basename()))
	return ids
