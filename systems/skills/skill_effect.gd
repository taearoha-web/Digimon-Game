class_name SkillEffect
extends Resource
## A single reusable effect. Skills are lists of effects, resolved generically
## by [SkillEffectResolver] — no skill needs its own battle script.

enum Type {
	DAMAGE,       ## Uses the skill's power/element through DamageCalculator.
	HEAL,         ## Restores [member amount] percent of max HP.
	BUFF,         ## Raises [member stat] by [member amount] stages.
	DEBUFF,       ## Lowers [member stat] by [member amount] stages.
	STATUS,       ## Applies [member status_id] for [member duration] turns.
	RESTORE_SP,   ## Restores [member amount] SP.
	DRAIN,        ## Heals the user for [member amount] percent of damage dealt.
}

enum EffectTarget {
	SKILL_TARGET, ## Whoever the skill targets.
	USER,         ## Always the skill user.
}

@export var type: Type = Type.DAMAGE
@export var target: EffectTarget = EffectTarget.SKILL_TARGET
## Stat id for BUFF / DEBUFF (e.g. &"attack", &"speed").
@export var stat: StringName = &""
## Stages for BUFF/DEBUFF, percent for HEAL/DRAIN, flat SP for RESTORE_SP.
@export var amount: int = 1
@export var status_id: StringName = &""
## Probability (0..1) the effect triggers after the skill hits.
@export_range(0.0, 1.0) var chance: float = 1.0
@export var duration: int = 3
