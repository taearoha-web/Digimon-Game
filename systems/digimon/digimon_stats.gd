class_name DigimonStats
extends RefCounted
## Stat identifiers and display helpers shared by every system.

const MAX_HP := &"max_hp"
const MAX_SP := &"max_sp"
const ATTACK := &"attack"
const DEFENSE := &"defense"
const SPECIAL_ATTACK := &"special_attack"
const SPECIAL_DEFENSE := &"special_defense"
const SPEED := &"speed"

const ALL: Array[StringName] = [MAX_HP, MAX_SP, ATTACK, DEFENSE, SPECIAL_ATTACK, SPECIAL_DEFENSE, SPEED]
## Stats that can be buffed/debuffed in battle.
const BATTLE_STATS: Array[StringName] = [ATTACK, DEFENSE, SPECIAL_ATTACK, SPECIAL_DEFENSE, SPEED, &"accuracy"]

const DISPLAY_NAMES := {
	&"max_hp": "HP",
	&"max_sp": "SP",
	&"attack": "Attack",
	&"defense": "Defense",
	&"special_attack": "Sp. Attack",
	&"special_defense": "Sp. Defense",
	&"speed": "Speed",
	&"accuracy": "Accuracy",
}

const SHORT_NAMES := {
	&"max_hp": "HP",
	&"max_sp": "SP",
	&"attack": "ATK",
	&"defense": "DEF",
	&"special_attack": "SP.ATK",
	&"special_defense": "SP.DEF",
	&"speed": "SPD",
	&"accuracy": "ACC",
}


static func display_name(stat: StringName) -> String:
	return L10n.t(DISPLAY_NAMES.get(stat, String(stat).capitalize()))


static func short_name(stat: StringName) -> String:
	return L10n.t(SHORT_NAMES.get(stat, String(stat).to_upper()))
