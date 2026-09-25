class_name TypeChart
extends Resource
## Type advantage data. Attribute triangle + element chart, both editable.

## "attacker_attribute>defender_attribute" (ints as strings, e.g. "0>2") -> multiplier.
@export var attribute_matchups: Dictionary = {}
## attacker element (StringName) -> { defender element -> multiplier }
@export var element_matchups: Dictionary = {}
## Display colours per element.
@export var element_colors: Dictionary = {}
## Bonus when the skill element matches the user's own element.
@export var same_element_bonus: float = 1.2


func get_attribute_multiplier(attacker_attribute: int, defender_attribute: int) -> float:
	var key := "%d>%d" % [attacker_attribute, defender_attribute]
	return float(attribute_matchups.get(key, 1.0))


func get_element_multiplier(skill_element: StringName, defender_element: StringName) -> float:
	var row: Dictionary = element_matchups.get(skill_element, {})
	return float(row.get(defender_element, 1.0))


func get_element_color(element: StringName) -> Color:
	var value = element_colors.get(element, Color(0.85, 0.85, 0.9))
	return value if value is Color else Color(0.85, 0.85, 0.9)
