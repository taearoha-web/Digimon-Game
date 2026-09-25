class_name ItemData
extends Resource
## Data-driven item definition. Behaviour is resolved by [ItemService].

enum Category { CONSUMABLE, EVOLUTION, QUEST, KEY }
enum UseEffect {
	NONE,
	HEAL_HP,          ## Heals a flat [member effect_value] HP.
	HEAL_HP_PERCENT,  ## Heals [member effect_value] percent of max HP.
	RESTORE_SP,       ## Restores a flat [member effect_value] SP.
	REVIVE,           ## Revives a fainted Digimon with [member effect_value] percent HP.
	FULL_RESTORE,     ## Full HP + SP.
	BEFRIEND_BOOST,   ## Adds [member effect_value] percent to the next befriend attempt.
}

const CATEGORY_NAMES := ["Consumables", "Evolution Items", "Quest Items", "Key Items"]

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.CONSUMABLE
@export var max_stack: int = 99
@export_file("*.png", "*.svg") var icon_path: String = ""
## Fallback tint for procedural icons.
@export var icon_color: Color = Color(0.4, 0.8, 1.0)
@export var use_effect: UseEffect = UseEffect.NONE
@export var effect_value: int = 0
@export var usable_in_field: bool = false
@export var usable_in_battle: bool = false
@export var consumed_on_use: bool = true
@export var sell_price: int = 0


func is_usable(in_battle: bool) -> bool:
	if use_effect == UseEffect.NONE:
		return false
	return usable_in_battle if in_battle else usable_in_field


func get_category_name() -> String:
	return CATEGORY_NAMES[clampi(category, 0, CATEGORY_NAMES.size() - 1)]


func get_icon() -> Texture2D:
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	return null
