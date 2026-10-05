class_name HeroStats
extends RefCounted
## Derived stats from a profile (level, attributes, equipment) and its buffs.

const MOVE_SPEED := 5.4
const CRIT_DAMAGE := 1.6


static func exp_to_next(level: int) -> int:
	return int(36.0 * pow(float(level), 1.6))


## Attributes = class base + automatic growth per level + points the player spent.
static func attributes(profile: Dictionary) -> Dictionary:
	var data := ClassData.get_class_data(StringName(profile["class"]))
	var level: int = profile["level"]
	var result := {}
	for key in ["str", "int", "dex", "vit"]:
		result[key] = int(data.base[key]) + int(data.gain[key]) * (level - 1) + int(profile["attrs"].get(key, 0))
	return result


static func gear_bonus(profile: Dictionary) -> Dictionary:
	var total := {"atk": 0, "def": 0, "hp": 0, "mp": 0, "crit": 0.0}
	for slot in profile["equip"]:
		var item: Dictionary = profile["equip"][slot]
		for key in item.get("stats", {}):
			total[key] = total.get(key, 0) + item.stats[key]
	return total


## buffs: { atk, def, speed, crit } fractions (0.3 = +30%).
static func compute(profile: Dictionary, buffs := {}) -> Dictionary:
	var data := JobData.resolve(StringName(profile["class"]), StringName(profile.get("job", "")))
	var level: int = profile["level"]
	var attrs := attributes(profile)
	var gear := gear_bonus(profile)
	var main_stat: int = attrs[data.main]
	var atk := (float(main_stat) * 1.0 + level * 1.5 + float(gear.atk)) * (1.0 + float(buffs.get("atk", 0.0))) * float(data.get("atk_mult", 1.0))
	var def := (float(attrs.vit) * 0.9 + level * 1.0 + float(gear.def)) * (1.0 + float(buffs.get("def", 0.0))) * float(data.get("def_mult", 1.0))
	return {
		"attrs": attrs,
		"max_hp": int((40.0 + attrs.vit * 5.0 + level * 8.0) * float(data.hp_mult)) + int(gear.hp),
		"max_mp": int((20.0 + attrs.int * 3.0 + level * 3.0) * float(data.mp_mult)) + int(gear.mp),
		"atk": atk,
		"def": def,
		"crit": clampf(0.05 + attrs.dex * 0.002 + float(gear.crit) + float(buffs.get("crit", 0.0)) + float(data.get("crit_bonus", 0.0)), 0.0, 0.8),
		"speed": MOVE_SPEED * (1.0 + float(buffs.get("speed", 0.0)) + float(data.get("speed_bonus", 0.0))),
		"dodge": clampf(attrs.dex * 0.0012, 0.0, 0.3),
	}


## Damage after the target's defence: 100 / (100 + def).
static func mitigate(raw: float, defence: float) -> float:
	return raw * 100.0 / (100.0 + maxf(defence, 0.0))
