class_name BattleRewards
extends RefCounted
## Computes and applies end-of-battle rewards (EXP, level-ups, drops,
## recruitment offers). Pure logic: the caller adds drops/recruits to
## GameState and shows the UI.


## Summary:
## { exp_entries: [{instance, amount, old_level, old_progress, level_ups, participated}],
##   drops: {item_id: qty}, recruit: DigimonInstance|null, recruit_chance: float }
static func apply_victory(controller: BattleController) -> Dictionary:
	var summary := _base_summary()
	var enemy_species := controller.enemy.get_species()
	var enemy_level := controller.enemy.get_level()
	summary.exp_entries = _award_exp(controller, enemy_species, enemy_level, 1.0)

	if enemy_species:
		for item_id in enemy_species.drop_table.keys():
			if controller.rng.randf() < float(enemy_species.drop_table[item_id]):
				summary.drops[StringName(item_id)] = int(summary.drops.get(StringName(item_id), 0)) + 1

	if controller.request.is_wild and controller.request.can_befriend:
		var chance := RecruitmentService.post_defeat_chance(enemy_species, enemy_level,
				controller.player.get_level(), controller.recruit_config, controller.completed_quests)
		summary.recruit_chance = chance
		if RecruitmentService.roll(chance, controller.rng):
			summary.recruit = RecruitmentService.create_recruit(enemy_species.id, enemy_level, controller.rng)
	return summary


## Befriending ends the battle peacefully: half EXP and the new friend.
static func apply_recruited(controller: BattleController) -> Dictionary:
	var summary := _base_summary()
	summary.exp_entries = _award_exp(controller, controller.enemy.get_species(), controller.enemy.get_level(), 0.5)
	summary.recruit = controller.recruited_instance
	summary.recruit_chance = 1.0
	return summary


static func _base_summary() -> Dictionary:
	return {"exp_entries": [], "drops": {}, "recruit": null, "recruit_chance": 0.0}


static func _award_exp(controller: BattleController, enemy_species: DigimonSpecies, enemy_level: int, scale: float) -> Array:
	var entries: Array = []
	for inst in controller.party:
		if inst.is_fainted():
			continue
		var participated := controller.participant_uids.has(inst.uid)
		var amount := Leveling.exp_reward(enemy_species, enemy_level, inst.level)
		if not participated:
			amount = int(amount * Leveling.BENCH_SHARE)
		amount = maxi(1, int(amount * scale))
		var old_level := inst.level
		var old_progress := Leveling.exp_progress(inst)
		var ups := Leveling.grant_exp(inst, amount)
		if participated:
			inst.add_friendship(2)
			inst.battles_won += 1
		entries.append({
			"instance": inst,
			"amount": amount,
			"old_level": old_level,
			"old_progress": old_progress,
			"level_ups": ups,
			"participated": participated,
		})
	return entries
