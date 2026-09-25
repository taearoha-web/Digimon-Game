class_name ItemData
extends Resource
## Data-driven item definition. Behaviour is resolved by [ItemService].

enum Category { CONSUMABLE, EVOLUTION, QUEST, KEY, EQUIPMENT }
enum UseEffect {
	NONE,
	HEAL_HP,          ## Heals a flat [member effect_value] HP.
	HEAL_HP_PERCENT,  ## Heals [member effect_value] percent of max HP.
	RESTORE_SP,       ## Restores a flat [member effect_value] SP.
	REVIVE,           ## Revives a fainted Digimon with [member effect_value] percent HP.
	FULL_RESTORE,     ## Full HP + SP.
	BEFRIEND_BOOST,   ## Adds [member effect_value] percent to the next befriend attempt.
}

const CATEGORY_NAMES := ["Consumables", "Evolution Items", "Quest Items", "Key Items", "Equipment"]

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
## Shop price (0 = not sold in shops).
@export var buy_price: int = 0
## Price paid when the player sells one (0 = cannot be sold).
@export var sell_price: int = 0
## EQUIPMENT only: stat id (StringName) -> flat bonus while held.
@export var equip_bonuses: Dictionary = {}


func is_usable(in_battle: bool) -> bool:
	if use_effect == UseEffect.NONE:
		return false
	return usable_in_battle if in_battle else usable_in_field


func is_equipment() -> bool:
	return category == Category.EQUIPMENT


## "+6 ATK, +20 HP" style summary of equip bonuses.
func describe_bonuses() -> String:
	var parts: Array = []
	for stat in equip_bonuses.keys():
		var value := int(equip_bonuses[stat])
		parts.append("%s%d %s" % ["+" if value >= 0 else "", value, DigimonStats.short_name(StringName(stat))])
	return ", ".join(parts)


func get_category_name() -> String:
	return CATEGORY_NAMES[clampi(category, 0, CATEGORY_NAMES.size() - 1)]


func get_icon() -> Texture2D:
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	return null
