class_name Leveling
extends RefCounted
## EXP curve, EXP rewards and level-up processing. All numbers live here.

const MAX_LEVEL := 99
## Share of EXP given to party members that did not fight.
const BENCH_SHARE := 0.5


## EXP needed to go from [param level] to level + 1.
static func exp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return 15 + level * 10 + int(pow(float(level), 1.5))


## EXP a Digimon of [param receiver_level] earns for defeating the given foe.
static func exp_reward(enemy_species: DigimonSpecies, enemy_level: int, receiver_level: int) -> int:
	var yield_value := enemy_species.base_exp_yield if enemy_species else 30
	var level_mod := clampf(1.0 + float(enemy_level - receiver_level) * 0.1, 0.5, 1.5)
	return maxi(1, int(round(yield_value * float(enemy_level) / 5.0 * level_mod)))


## Adds EXP and processes every level gained.
## Returns one dictionary per level-up:
## { level, before: {stat: v}, after: {stat: v}, gains: {stat: delta}, learned: [skill ids] }
static func grant_exp(inst: DigimonInstance, amount: int) -> Array[Dictionary]:
	var level_ups: Array[Dictionary] = []
	if inst == null or amount <= 0 or inst.level >= MAX_LEVEL:
		return level_ups
	inst.experience += amount
	while inst.level < MAX_LEVEL and inst.experience >= exp_to_next(inst.level):
		inst.experience -= exp_to_next(inst.level)
		level_ups.append(_apply_level_up(inst))
	if inst.level >= MAX_LEVEL:
		inst.experience = 0
	return level_ups


static func _apply_level_up(inst: DigimonInstance) -> Dictionary:
	var before := inst.get_all_stats()
	inst.level += 1
	var after := inst.get_all_stats()
	var gains := {}
	for stat in DigimonStats.ALL:
		gains[stat] = int(after[stat]) - int(before[stat])
	# Growing max HP/SP also restores that much, like most RPGs.
	if not inst.is_fainted():
		inst.current_hp += int(gains[DigimonStats.MAX_HP])
	inst.current_sp += int(gains[DigimonStats.MAX_SP])
	inst.clamp_vitals()
	var learned: Array[StringName] = []
	var species := inst.get_species()
	if species:
		for skill_id in species.get_skills_learned_at(inst.level):
			if inst.learn_skill(skill_id):
				learned.append(skill_id)
	inst.add_friendship(1)
	return {
		"level": inst.level,
		"before": before,
		"after": after,
		"gains": gains,
		"learned": learned,
	}


## Progress towards the next level in 0..1 (for EXP bars).
static func exp_progress(inst: DigimonInstance) -> float:
	var needed := exp_to_next(inst.level)
	if needed <= 0:
		return 1.0
	return clampf(float(inst.experience) / float(needed), 0.0, 1.0)
