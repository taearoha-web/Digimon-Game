class_name SkillData
extends Resource
## Data-driven skill definition.

enum Category { PHYSICAL, SPECIAL, SUPPORT }
enum Target { ENEMY, SELF }

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

@export_group("Presentation")
## Animation contract name played by the user (&"attack" or &"skill").
@export var animation: StringName = &"attack"
## VFX preset id understood by BattleVfx.
@export var vfx: StringName = &"impact"
## When true a projectile travels from user to target.
@export var projectile: bool = false
## Sound id understood by AudioManager.
@export var sfx: StringName = &"hit_physical"


func deals_damage() -> bool:
	for effect in effects:
		if effect and effect.type == SkillEffect.Type.DAMAGE:
			return true
	return false


func get_category_name() -> String:
	return ["Physical", "Special", "Support"][category]
