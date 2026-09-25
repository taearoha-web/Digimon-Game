class_name BattleAI
extends RefCounted
## Simple, readable enemy decision making.


## Returns a command dictionary like the player's: {"type": "skill", "skill_id": id}
static func choose_command(actor: BattleCombatant, foe: BattleCombatant, rng: RandomNumberGenerator,
		chart: TypeChart) -> Dictionary:
	var skills := actor.get_usable_skills()
	if skills.is_empty():
		return {"type": "struggle"}
	var hp_ratio := actor.instance.get_hp_ratio()
	var scored: Array[Dictionary] = []
	for skill in skills:
		scored.append({"skill": skill, "score": _score(skill, actor, foe, hp_ratio, chart)})
	scored.sort_custom(func(a, b): return a.score > b.score)
	# Mostly pick the best option, sometimes the second best (less robotic).
	var pick: Dictionary = scored[0]
	if scored.size() > 1 and rng.randf() < 0.25:
		pick = scored[1]
	return {"type": "skill", "skill_id": pick.skill.id}


static func _score(skill: SkillData, actor: BattleCombatant, foe: BattleCombatant, hp_ratio: float,
		chart: TypeChart) -> float:
	var score := 0.0
	for effect in skill.effects:
		if effect == null:
			continue
		match effect.type:
			SkillEffect.Type.DAMAGE:
				var mult := DamageCalculator.get_type_multiplier(actor.get_species(), foe.get_species(), skill, chart)
				score += float(skill.power) * mult * float(skill.accuracy) / 100.0
			SkillEffect.Type.HEAL:
				score += 90.0 if hp_ratio < 0.35 else (10.0 if hp_ratio < 0.6 else -50.0)
			SkillEffect.Type.BUFF:
				var stage := int(actor.stages.get(effect.stat, 0))
				score += 25.0 if stage < 2 and hp_ratio > 0.5 else 0.0
			SkillEffect.Type.DEBUFF:
				var foe_stage := int(foe.stages.get(effect.stat, 0))
				score += 22.0 if foe_stage > -2 else 0.0
			SkillEffect.Type.STATUS:
				score += 28.0 * effect.chance if foe.status_id == &"" else 0.0
	# Prefer cheap skills when SP is low.
	if actor.instance.current_sp < skill.sp_cost * 2:
		score -= 10.0
	return score
