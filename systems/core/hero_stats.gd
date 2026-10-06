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
	var total := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "crit": 0.0}
	var sets := {}
	for slot in profile["equip"]:
		var item: Dictionary = profile["equip"][slot]
		var boost := 1.0 + 0.08 * float(item.get("plus", 0))
		for key in item.get("stats", {}):
			total[key] = total.get(key, 0.0) + float(item.stats[key]) * (boost if key != "crit" else 1.0 + 0.04 * float(item.get("plus", 0)))
		for gem_id in item.get("gems", []):
			var info := ItemData.gem_info({"id": gem_id})
			total[info.stat] = total.get(info.stat, 0.0) + float(info.value)
		var set_id := str(item.get("set", ""))
		if set_id != "":
			sets[set_id] = int(sets.get(set_id, 0)) + 1
			sets["%s_level" % set_id] = int(item.get("level", 1))
	for set_id in sets:
		if set_id.ends_with("_level"):
			continue
		var count: int = sets[set_id]
		var level: int = sets["%s_level" % set_id]
		if count >= 2:
			total.hp += 15.0 * level
		if count >= 3:
			total.atk += 3.0 * level
		if count >= 4:
			total.def += 2.0 * level
			total.crit += 0.03
	total["atk"] = int(total.atk)
	total["def"] = int(total.def)
	total["hp"] = int(total.hp)
	total["mp"] = int(total.mp)
	return total


## How many pieces of each set are worn: { set_id: count }.
static func set_counts(profile: Dictionary) -> Dictionary:
	var counts := {}
	for slot in profile["equip"]:
		var set_id := str(profile["equip"][slot].get("set", ""))
		if set_id != "":
			counts[set_id] = int(counts.get(set_id, 0)) + 1
	return counts


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
