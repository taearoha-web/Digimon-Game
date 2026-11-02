class_name HeroStats
extends RefCounted
## Derived stats from a profile (level, attributes, equipment) and its buffs.

const MOVE_SPEED := 5.4
## Each +1 of enhancement adds this share of the item's stats (+50% at +10).
const PLUS_BONUS := 0.05
## Crit chance: every class starts at BASE_CRIT (archer and assassin at their
## class "base_crit"); DEX, gear, job advancement, passives, star points and
## buffs add to it, up to 100%.
const MAX_CRIT := 1.0
const BASE_CRIT := 0.10
const CRIT_PER_DEX := 0.00025
## Items carry crit as a rating (the values they have always stored); this share
## of it is crit chance, so a full +10 set of the best gear gives about 30%.
## Socketed topaz gems count in full.
const GEAR_CRIT_SCALE := 0.2
const CRIT_DAMAGE := 1.6
## Skill damage relative to the authored multipliers. Measured with
## tests/tools/balance_probe.tscn: at 1.0 the strongest skill one-shot a
## normal monster on every field (100-230% of its HP); at 0.4 it takes 2-3
## casts while basic attacks keep their pace.
const SKILL_POWER := 0.4
## DEX makes skills and attacks quicker with diminishing returns: the haste
## approaches MAX_HASTE, half of it at HASTE_HALF_DEX (about 13% at 130 DEX, 27%
## at 600). Star points add on top, up to MAX_HASTE.
const HASTE_HALF_DEX := 280.0
const MAX_HASTE := 0.4


static func exp_to_next(level: int) -> int:
	return int(36.0 * pow(float(level), 1.6))


## Past Lv.100 every star asks this much more than a Lv.100 level did (the climb to
## ★200 is the long farm), and 2% more per star already reached.
const STAR_EXP := 1.5
## Per star already reached, as a share of the ★0 cost: 2% up to ★200, then 4%
## from ★200 to ★300 (STAR_STEEP_FROM), so the last hundred stars keep getting
## harder: ★200 costs 5x the ★0 star, ★250 7x, ★299 about 9x, and ★200 -> ★300
## asks about 1.17x the EXP of the whole ★0 -> ★200 climb.
const STAR_GROWTH := 0.02
const STAR_STEEP_FROM := 200
const STAR_STEEP_GROWTH := 0.02


## EXP from star `star` to the next (★0 -> ★1 is `star` 0).
static func star_need(star: int) -> int:
	var growth := STAR_GROWTH * float(star) + STAR_STEEP_GROWTH * float(maxi(0, star - STAR_STEEP_FROM))
	return int(float(exp_to_next(100)) * STAR_EXP * (1.0 + growth))


## Attributes = class base + automatic growth per level + points the player spent.
static func attributes(profile: Dictionary) -> Dictionary:
	var data := ClassData.get_class_data(StringName(profile["class"]))
	var level: int = profile["level"]
	var result := {}
	var advance := JobData.attr_bonus(StringName(profile["class"]), int(profile.get("adv", 0)))
	for key in ["str", "int", "dex", "vit"]:
		result[key] = int(data.base[key]) + int(data.gain[key]) * (level - 1) + int(profile["attrs"].get(key, 0)) + int(advance[key])
	return result


static func gear_bonus(profile: Dictionary) -> Dictionary:
	var total := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "crit": 0.0, "matk": 0.0}
	var gems := {}
	var gem_count := {}
	var sets := {}
	for slot in profile["equip"]:
		var item: Dictionary = profile["equip"][slot]
		var boost := 1.0 + PLUS_BONUS * float(item.get("plus", 0))
		for key in item.get("stats", {}):
			total[key] = total.get(key, 0.0) + float(item.stats[key]) * (boost if key != "crit" else (1.0 + 0.04 * float(item.get("plus", 0))) * GEAR_CRIT_SCALE)
		var ring := 1.0 + ItemData.GEM_RESONANCE if ItemData.resonates(item) else 1.0
		for gem_id in item.get("gems", []):
			var info := ItemData.gem_info({"id": gem_id})
			gems[info.stat] = float(gems.get(info.stat, 0.0)) + float(info.value) * ring
			gem_count[info.type] = int(gem_count.get(info.type, 0)) + 1
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
	total["matk"] = int(total.matk)
	# Gem shares (ItemData.GEMS) and the set of 12 of one stat gem.
	total["gems"] = gems
	var gem_set := ""
	for type in ItemData.STAT_GEMS:
		if int(gem_count.get(type, 0)) >= ItemData.GEM_SET_COUNT:
			gem_set = type
	total["gem_set"] = gem_set
	# The 250-star class set (SetGearData.BONUS): pieces of the hero's own class.
	total["set_gear"] = SetGearData.worn_count(profile["equip"], String(profile.get("class", "")))
	return total


## The 2/4/6 piece bonus of the hero's 250-star class set: {hp, atk, def, crit, crit_dmg} shares.
static func set_gear_bonus(profile: Dictionary) -> Dictionary:
	return SetGearData.bonus(SetGearData.worn_count(profile.get("equip", {}), String(profile.get("class", ""))))


## Sum of the always-on passive skills (rank 1 once unlocked, up to 5 stars).
static func passive_bonus(profile: Dictionary) -> Dictionary:
	var total := {"atk": 0.0, "def": 0.0, "hp": 0.0, "mp": 0.0, "crit": 0.0, "speed": 0.0, "dodge": 0.0}
	var level: int = profile["level"]
	for passive in ClassData.PASSIVES.get(StringName(profile["class"]), []):
		if level < int(passive.level) or ClassData.skill_tier(passive) > ClassData.tier_of(StringName(profile["class"]), int(profile.get("adv", 0))):
			continue
		var rank := maxi(1, int(profile.get("skills", {}).get(passive.id, 0)))
		for key in passive.bonus:
			total[key] += float(passive.bonus[key]) * rank
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
## Gem set abilities applied in combat (Hero): ruby +25% ATK under 30% HP, amethyst +20%
## DEF under 50% HP. Topaz's +5% crit is in compute.
const GEM_SET_FURY := 0.25
const GEM_SET_BULWARK := 0.2
const GEM_SET_HAWK := 0.05
## Caps on the special gems' totals.
const MAX_LIFESTEAL := 0.1
const MAX_CDR := 0.3
const MAX_FORTUNE := 0.5
## Onyx crit damage on top of CRIT_DAMAGE (1.6): at most +0.6, crits up to x2.2.
const MAX_CRIT_DMG := 0.6


static func compute(profile: Dictionary, buffs := {}) -> Dictionary:
	var data := JobData.resolve(StringName(profile["class"]), int(profile.get("adv", 0)))
	var level: int = profile["level"]
	var attrs := attributes(profile)
	var gear := gear_bonus(profile)
	var passive := passive_bonus(profile)
	var para: Dictionary = (profile.get("paragon", {}) as Dictionary).get("alloc", {}) if profile.get("paragon") is Dictionary else {}
	var main_stat: int = attrs[data.main]
	var sub_stat: float = float(attrs[data.sub]) * 0.5 if data.has("sub") else 0.0
	var gems: Dictionary = gear.get("gems", {})
	var caster := String(data.main) == "int"
	# Ruby raises every class's attack; sapphire a caster's (magic) attack and everyone's MP.
	var gem_atk := 1.0 + float(gems.get("atk", 0.0)) + (float(gems.get("matk", 0.0)) if caster else 0.0)
	var atk := (float(main_stat) * 1.0 + sub_stat + level * 1.5 + float(gear.atk) + (float(gear.matk) if caster else 0.0)) * (1.0 + float(buffs.get("atk", 0.0))) * float(data.get("atk_mult", 1.0)) * (1.0 + float(passive.atk)) * (1.0 + 0.003 * float(para.get("atk", 0))) * gem_atk
	var def := (float(attrs.vit) * 0.9 + level * 1.0 + float(gear.def)) * (1.0 + float(buffs.get("def", 0.0))) * float(data.get("def_mult", 1.0)) * (1.0 + float(passive.def)) * (1.0 + 0.005 * float(para.get("def", 0))) * (1.0 + float(gems.get("def", 0.0)))
	var gem_set := String(gear.get("gem_set", ""))
	# The active mount's bonus (MountData.bonus) counts ridden or not.
	var ride := mount_bonus(profile)
	atk *= 1.0 + float(ride.get("atk", 0.0))
	def *= 1.0 + float(ride.get("def", 0.0))
	var set_bonus := SetGearData.bonus(int(gear.get("set_gear", 0)))
	atk *= 1.0 + float(set_bonus.get("atk", 0.0))
	def *= 1.0 + float(set_bonus.get("def", 0.0))
	return {
		"set_gear": int(gear.get("set_gear", 0)),
		"crit_dmg": minf(float(gems.get("crit_dmg", 0.0)), MAX_CRIT_DMG) + float(set_bonus.get("crit_dmg", 0.0)),
		"lifesteal": minf(float(gems.get("lifesteal", 0.0)), MAX_LIFESTEAL),
		"cdr": minf(float(gems.get("cdr", 0.0)), MAX_CDR),
		"fortune": minf(float(gems.get("fortune", 0.0)), MAX_FORTUNE),
		"gem_set": gem_set,
		"attrs": attrs,
		"max_hp": int(((40.0 + attrs.vit * 5.0 + level * 8.0) * float(data.hp_mult) * (1.0 + float(passive.hp)) * (1.0 + 0.008 * float(para.get("hp", 0))) + float(gear.hp)) * (1.0 + float(gems.get("hp", 0.0))) * (1.0 + float(ride.get("hp", 0.0))) * (1.0 + float(set_bonus.get("hp", 0.0)))),
		"max_mp": int(((20.0 + attrs.int * 3.0 + level * 3.0) * float(data.mp_mult) * (1.0 + float(passive.mp)) + float(gear.mp)) * (1.0 + float(gems.get("matk", 0.0)))),
		"atk": atk,
		"def": def,
		"crit": clampf(float(data.get("base_crit", BASE_CRIT)) + attrs.dex * CRIT_PER_DEX + float(gear.crit) + float(gems.get("crit", 0.0)) + (GEM_SET_HAWK if gem_set == "topaz" else 0.0) + float(buffs.get("crit", 0.0)) + float(data.get("crit_bonus", 0.0)) + float(passive.crit) + 0.001 * float(para.get("crit", 0)) + float(ride.get("crit", 0.0)) + float(set_bonus.get("crit", 0.0)), 0.0, MAX_CRIT),
		"speed": MOVE_SPEED * (1.0 + float(buffs.get("speed", 0.0)) + float(data.get("speed_bonus", 0.0)) + float(passive.speed)),
		"dodge": clampf(attrs.dex * 0.0012 + float(passive.dodge) + float(buffs.get("dodge",0.0)), 0.0, 0.35),
		"haste": clampf(MAX_HASTE * float(attrs.dex) / (float(attrs.dex) + HASTE_HALF_DEX) + 0.001 * float(para.get("haste", 0)), 0.0, MAX_HASTE),
	}


## Stat shares of the profile's active mount at its level (MountData.bonus; {} with none).
static func mount_bonus(profile: Dictionary) -> Dictionary:
	var id: Variant = profile.get("mount", "")
	var levels: Variant = profile.get("mounts", {})
	if not id is String or not levels is Dictionary:
		return {}
	return MountData.bonus(id, int(levels.get(id, 0)))


## Damage after the target's defence: 100 / (100 + def).
static func mitigate(raw: float, defence: float) -> float:
	return raw * 100.0 / (100.0 + maxf(defence, 0.0))


## Burn / poison / bleed per second a skill leaves: its share of attack per
## second, reduced by the target's defence like the hit itself.
static func burn_dps(atk: float, per_second: float, defence: float) -> float:
	return mitigate(atk * per_second, defence)
