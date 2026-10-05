class_name FieldRewards
extends RefCounted
## Rewards for defeating a wild Digimon in the open world. Pure logic (like
## [BattleRewards]): the caller shows popups and toasts.


## Summary: { exp_entries: [{instance, amount, level_ups, participated}],
##            drops: {item_id: qty}, recruit: DigimonInstance|null }
static func apply_victory(species: DigimonSpecies, level: int, party: Array[DigimonInstance],
		participant_uids: Array, rng: RandomNumberGenerator, cfg: RecruitmentConfig, completed_quests: int) -> Dictionary:
	var summary := {"exp_entries": [], "drops": {}, "recruit": null}
	var lead_level := 1
	for inst in party:
		if inst.is_fainted():
			continue
		lead_level = maxi(lead_level, inst.level)
		var participated := participant_uids.has(inst.uid)
		var amount := Leveling.exp_reward(species, level, inst.level)
		if not participated:
			amount = int(amount * Leveling.BENCH_SHARE)
		amount = maxi(1, amount)
		var ups := Leveling.grant_exp(inst, amount)
		if participated:
			inst.add_friendship(1)
		summary.exp_entries.append({"instance": inst, "amount": amount, "level_ups": ups, "participated": participated})
	if species:
		for item_id in species.drop_table.keys():
			if rng.randf() < float(species.drop_table[item_id]):
				summary.drops[StringName(item_id)] = int(summary.drops.get(StringName(item_id), 0)) + 1
		if cfg:
			var chance := RecruitmentService.post_defeat_chance(species, level, lead_level, cfg, completed_quests)
			if RecruitmentService.roll(chance, rng):
				summary.recruit = RecruitmentService.create_recruit(species.id, level, rng)
	return summary
