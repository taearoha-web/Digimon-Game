class_name StatusEffects
extends RefCounted
## Status effect definitions. Adding a status = adding an entry here; the
## battle controller reads these generic fields instead of special-casing.

const DEFINITIONS := {
	&"poison": {
		"name": "Poison",
		"color": Color(0.62, 0.36, 0.85),
		"damage_percent": 10,   # % of max HP lost at end of turn
		"skip_chance": 0.0,
		"speed_multiplier": 1.0,
		"apply_text": "{target} was poisoned!",
		"tick_text": "{target} is hurt by poison!",
		"end_text": "{target} recovered from poison.",
	},
	&"stun": {
		"name": "Stun",
		"color": Color(1.0, 0.86, 0.25),
		"damage_percent": 0,
		"skip_chance": 0.35,
		"speed_multiplier": 0.5,
		"apply_text": "{target} is stunned!",
		"skip_text": "{target} is stunned and can't move!",
		"end_text": "{target} is no longer stunned.",
	},
	&"burn": {
		"name": "Burn",
		"color": Color(1.0, 0.45, 0.2),
		"damage_percent": 6,
		"skip_chance": 0.0,
		"speed_multiplier": 1.0,
		"attack_multiplier": 0.75,
		"apply_text": "{target} was burned!",
		"tick_text": "{target} is hurt by its burn!",
		"end_text": "{target}'s burn healed.",
	},
}


static func has_status(status_id: StringName) -> bool:
	return DEFINITIONS.has(status_id)


static func get_def(status_id: StringName) -> Dictionary:
	return DEFINITIONS.get(status_id, {})


static func get_display_name(status_id: StringName) -> String:
	return L10n.t(str(get_def(status_id).get("name", String(status_id).capitalize())))


static func get_color(status_id: StringName) -> Color:
	return get_def(status_id).get("color", Color.WHITE)


static func text(status_id: StringName, key: String, target_name: String) -> String:
	var template := L10n.t(str(get_def(status_id).get(key, "")))
	return template.replace("{target}", target_name)
