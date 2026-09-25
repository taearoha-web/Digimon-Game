class_name BattleCombatant
extends RefCounted
## Battle-only wrapper around a [DigimonInstance]: stat stages, defending,
## status. HP/SP changes go straight to the instance so they persist.

const MAX_STAGE := 4
const PLAYER_SIDE := 0
const ENEMY_SIDE := 1

var instance: DigimonInstance
var side: int = PLAYER_SIDE
var stages: Dictionary = {}
var is_defending := false
var status_id: StringName = &""
var status_turns := 0
## Extra befriend chance from items used this battle.
var befriend_bonus := 0.0


func _init(p_instance: DigimonInstance = null, p_side: int = PLAYER_SIDE) -> void:
	instance = p_instance
	side = p_side


func get_species() -> DigimonSpecies:
	return instance.get_species()


func get_name() -> String:
	return instance.get_display_name()


## Name with "wild"/"foe" prefix for battle messages.
func get_battle_name() -> String:
	return ("Wild " + get_name()) if side == ENEMY_SIDE else get_name()


func get_level() -> int:
	return instance.level


func is_fainted() -> bool:
	return instance.is_fainted()


func get_effective_stat(stat: StringName) -> float:
	var value := float(instance.get_stat(stat)) * stage_multiplier(int(stages.get(stat, 0)))
	var status_def := StatusEffects.get_def(status_id)
	if stat == DigimonStats.SPEED:
		value *= float(status_def.get("speed_multiplier", 1.0))
	elif stat == DigimonStats.ATTACK:
		value *= float(status_def.get("attack_multiplier", 1.0))
	return maxf(1.0, value)


func get_accuracy_multiplier() -> float:
	return stage_multiplier(int(stages.get(&"accuracy", 0)))


static func stage_multiplier(stage: int) -> float:
	if stage >= 0:
		return 1.0 + 0.25 * stage
	return 1.0 / (1.0 + 0.25 * -stage)


## Returns the change actually applied (0 when already at the limit).
func modify_stage(stat: StringName, delta: int) -> int:
	var current := int(stages.get(stat, 0))
	var next := clampi(current + delta, -MAX_STAGE, MAX_STAGE)
	stages[stat] = next
	return next - current


func reset_battle_state() -> void:
	stages.clear()
	is_defending = false


func apply_status(p_status_id: StringName, turns: int) -> bool:
	if status_id != &"" or not StatusEffects.has_status(p_status_id):
		return false
	status_id = p_status_id
	status_turns = maxi(1, turns)
	return true


func clear_status() -> void:
	status_id = &""
	status_turns = 0


func can_afford(skill: SkillData) -> bool:
	return skill != null and instance.current_sp >= skill.sp_cost


## Equipped skills this combatant can pay for right now.
func get_usable_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in get_equipped_skills():
		if can_afford(skill):
			result.append(skill)
	return result


func get_equipped_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	var registry: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData")
	if registry == null:
		return result
	for skill_id in instance.equipped_skills:
		var skill: SkillData = registry.get_skill(skill_id)
		if skill:
			result.append(skill)
	return result
