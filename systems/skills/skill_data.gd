class_name SkillData
extends Resource
## Data-driven skill definition.

enum Category { PHYSICAL, SPECIAL, SUPPORT }
enum Target { ENEMY, SELF }
## How a skill is aimed in the open world (field combat):
## SINGLE = hits the targeted monster; BURST = shockwave around the caster that
## hits every monster inside [member area_radius]; BLAST = explodes on the
## target and hits every monster inside [member area_radius] around it.
enum Shape { SINGLE, BURST, BLAST }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.PHYSICAL
@export var element: StringName = &"neutral"
@export var power: int = 40
@export_range(0, 100) var accuracy: int = 95
@export var sp_cost: int = 0
@export var target: Target = Target.ENEMY
## Added to the base critical-hit chance.
@export var crit_bonus: float = 0.0
## Higher priority acts first regardless of Speed.
@export var priority: int = 0
@export var effects: Array[SkillEffect] = []

@export_group("Field combat")
@export var shape: Shape = Shape.SINGLE
## Metres the caster may be from the target when the skill goes off
## (the partner runs up to this distance first). Ignored for BURST.
@export var cast_range: float = 2.4
## Radius in metres of BURST / BLAST skills.
@export var area_radius: float = 0.0
## Seconds before the skill can be used again.
@export var cooldown: float = 3.0

@export_group("Presentation")
## Animation contract name played by the user (&"attack" or &"skill").
@export var animation: StringName = &"attack"
## VFX preset id understood by BattleVfx.
@export var vfx: StringName = &"impact"
## When true a projectile travels from user to target.
@export var projectile: bool = false
## Sound id understood by AudioManager.
@export var sfx: StringName = &"hit_physical"


## Distance the partner must close to before the skill fires.
func get_engage_range() -> float:
	if target == Target.SELF:
		return 0.0
	return area_radius * 0.75 if shape == Shape.BURST else cast_range


func is_area() -> bool:
	return shape != Shape.SINGLE and target == Target.ENEMY


func deals_damage() -> bool:
	for effect in effects:
		if effect and effect.type == SkillEffect.Type.DAMAGE:
			return true
	return false


func get_category_name() -> String:
	return L10n.t(["Physical", "Special", "Support"][category])
