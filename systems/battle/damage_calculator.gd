class_name DamageCalculator
extends RefCounted
## THE damage formula. Every damage number in the game comes from here.
##
##   level_factor = 2 * level / 5 + 2
##   base   = (level_factor * power * ATK / DEF) / 40 + 2
##   damage = base * SCALE * same_element * type * critical * variance * defend
##
## ATK/DEF are Attack/Defense for physical skills and Sp. Attack/Sp. Defense
## for special skills, already multiplied by battle stages (buff/debuff).

const DAMAGE_SCALE := 2.5
const BASE_CRIT_CHANCE := 0.0625
const CRIT_MULTIPLIER := 1.5
const MIN_VARIANCE := 0.85
const MAX_VARIANCE := 1.0
const DEFEND_MULTIPLIER := 0.5


## Returns { amount: int, critical: bool, type_multiplier: float, same_element: bool }
static func calculate(attacker: BattleCombatant, defender: BattleCombatant, skill: SkillData,
		rng: RandomNumberGenerator, chart: TypeChart, options := {}) -> Dictionary:
	var physical := skill.category == SkillData.Category.PHYSICAL
	var atk := attacker.get_effective_stat(DigimonStats.ATTACK if physical else DigimonStats.SPECIAL_ATTACK)
	var def := defender.get_effective_stat(DigimonStats.DEFENSE if physical else DigimonStats.SPECIAL_DEFENSE)
	var level_factor := 2.0 * float(attacker.get_level()) / 5.0 + 2.0
	var base := (level_factor * float(skill.power) * atk / maxf(def, 1.0)) / 40.0 + 2.0

	var attacker_species := attacker.get_species()
	var defender_species := defender.get_species()
	var same_element := skill.element != &"neutral" and attacker_species != null and attacker_species.element == skill.element
	var stab := chart.same_element_bonus if (same_element and chart) else 1.0
	var type_mult := get_type_multiplier(attacker_species, defender_species, skill, chart)

	var crit_chance := BASE_CRIT_CHANCE + skill.crit_bonus
	var critical: bool = options.get("force_crit", false) or (not options.get("no_crit", false) and rng.randf() < crit_chance)
	var crit_mult := CRIT_MULTIPLIER if critical else 1.0
	var variance := 1.0 if options.get("no_variance", false) else rng.randf_range(MIN_VARIANCE, MAX_VARIANCE)
	var defend_mult := DEFEND_MULTIPLIER if defender.is_defending else 1.0

	var amount := int(round(base * DAMAGE_SCALE * stab * type_mult * crit_mult * variance * defend_mult))
	return {
		"amount": maxi(1, amount),
		"critical": critical,
		"type_multiplier": type_mult,
		"same_element": same_element,
	}


static func get_type_multiplier(attacker_species: DigimonSpecies, defender_species: DigimonSpecies,
		skill: SkillData, chart: TypeChart) -> float:
	if chart == null or defender_species == null:
		return 1.0
	var mult := chart.get_element_multiplier(skill.element, defender_species.element)
	if attacker_species:
		mult *= chart.get_attribute_multiplier(attacker_species.attribute, defender_species.attribute)
	return mult


## True when the skill lands. Self-targeted and 100-accuracy skills never miss.
static func roll_hit(attacker: BattleCombatant, skill: SkillData, rng: RandomNumberGenerator) -> bool:
	if skill.target == SkillData.Target.SELF or skill.accuracy >= 100:
		return true
	var chance := float(skill.accuracy) / 100.0 * attacker.get_accuracy_multiplier()
	return rng.randf() < chance


static func effectiveness_text(type_multiplier: float) -> String:
	if type_multiplier >= 1.2:
		return "It's super effective!"
	if type_multiplier <= 0.85:
		return "It's not very effective…"
	return ""
