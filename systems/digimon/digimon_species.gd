class_name DigimonSpecies
extends Resource
## STATIC species definition. Shared by every Digimon of this species.
##
## Never modify a species resource at runtime: per-Digimon progress (level,
## EXP, HP, learned skills…) lives in [DigimonInstance].

enum Stage { FRESH, IN_TRAINING, ROOKIE, CHAMPION, ULTIMATE, MEGA }
enum Attribute { VACCINE, DATA, VIRUS, FREE }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

const STAGE_NAMES := ["Fresh", "In-Training", "Rookie", "Champion", "Ultimate", "Mega"]
const ATTRIBUTE_NAMES := ["Vaccine", "Data", "Virus", "Free"]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]

@export_group("Identity")
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stage: Stage = Stage.ROOKIE
@export var attribute: Attribute = Attribute.DATA
## In-universe classification, e.g. "Reptile", "Beast", "Mammal".
@export var digimon_type: String = ""
## Battle element used for defensive type matchups (see [TypeChart]).
@export var element: StringName = &"neutral"
@export var rarity: Rarity = Rarity.COMMON

@export_group("Base Stats (Level 1)")
@export var base_hp: int = 40
@export var base_sp: int = 20
@export var base_attack: int = 10
@export var base_defense: int = 10
@export var base_special_attack: int = 10
@export var base_special_defense: int = 10
@export var base_speed: int = 10

@export_group("Growth Per Level")
@export var growth_hp: float = 7.0
@export var growth_sp: float = 2.0
@export var growth_attack: float = 1.8
@export var growth_defense: float = 1.6
@export var growth_special_attack: float = 1.8
@export var growth_special_defense: float = 1.6
@export var growth_speed: float = 1.5

@export_group("Skills")
## Skills known when a Digimon of this species is created.
@export var innate_skills: Array[StringName] = []
## level (int) -> skill id (StringName). Learned when reaching that level.
@export var learnset: Dictionary = {}

@export_group("Evolution")
@export var evolutions: Array[EvolutionPath] = []

@export_group("Rewards")
@export var base_exp_yield: int = 40
## Multiplier applied to recruit chances on top of rarity.
@export var recruit_modifier: float = 1.0
## item id (StringName) -> drop chance (0..1) after a win against this species.
@export var drop_table: Dictionary = {}

@export_group("Presentation")
## Optional imported model (.tscn/.glb). Empty = procedural placeholder.
@export_file("*.tscn", "*.scn", "*.glb", "*.gltf") var model_path: String = ""
@export_file("*.png", "*.svg", "*.webp") var icon_path: String = ""
## Animation contract id (see docs/ASSET_REPLACEMENT.md).
@export var animation_set: StringName = &"creature_default"
## event (StringName, e.g. &"cry", &"attack") -> sound id or audio path.
@export var sounds: Dictionary = {}
## Placeholder body plan used by PlaceholderDigimonFactory.
@export var placeholder_body: StringName = &"blob"
## [primary, secondary, accent, eye] colours for the placeholder.
@export var placeholder_colors: PackedColorArray = PackedColorArray()
## Free-form options for the body plan (horns, wings, tail length…).
@export var placeholder_options: Dictionary = {}
@export var model_scale: float = 1.0
## Floating creatures hover above the ground.
@export var hovers: bool = false
@export var move_speed: float = 3.5


func get_base_stat(stat: StringName) -> int:
	match stat:
		&"max_hp": return base_hp
		&"max_sp": return base_sp
		&"attack": return base_attack
		&"defense": return base_defense
		&"special_attack": return base_special_attack
		&"special_defense": return base_special_defense
		&"speed": return base_speed
	push_warning("Unknown stat '%s'" % stat)
	return 0


func get_growth(stat: StringName) -> float:
	match stat:
		&"max_hp": return growth_hp
		&"max_sp": return growth_sp
		&"attack": return growth_attack
		&"defense": return growth_defense
		&"special_attack": return growth_special_attack
		&"special_defense": return growth_special_defense
		&"speed": return growth_speed
	return 0.0


## Skills gained exactly when reaching [param level].
func get_skills_learned_at(level: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for key in learnset.keys():
		if int(key) == level:
			result.append(StringName(learnset[key]))
	return result


## Every skill this species knows at [param level] (innate + learnset).
func get_skills_up_to(level: int) -> Array[StringName]:
	var result: Array[StringName] = innate_skills.duplicate()
	var levels: Array = learnset.keys()
	levels.sort_custom(func(a, b): return int(a) < int(b))
	for key in levels:
		if int(key) <= level:
			var skill_id := StringName(learnset[key])
			if not result.has(skill_id):
				result.append(skill_id)
	return result


func get_stage_name() -> String:
	return L10n.t(STAGE_NAMES[clampi(stage, 0, STAGE_NAMES.size() - 1)])


func get_attribute_name() -> String:
	return L10n.t(ATTRIBUTE_NAMES[clampi(attribute, 0, ATTRIBUTE_NAMES.size() - 1)])


func get_rarity_name() -> String:
	return L10n.t(RARITY_NAMES[clampi(rarity, 0, RARITY_NAMES.size() - 1)])


func get_color(index: int, fallback: Color = Color.WHITE) -> Color:
	if index >= 0 and index < placeholder_colors.size():
		return placeholder_colors[index]
	return fallback
