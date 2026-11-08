class_name EndgameFields
extends RefCounted
## The two ★200-300 fields, วิหารบัวดารา (DivineRegionData) and ห้วงสมุทรอสูร
## (DrownedAbyssData), share one difficulty band and one drop table, so players
## are happy to farm either. Each keeps its own look, bestiary and boss moves;
## the numbers live here.
##
## Band: entry at ENTRY_STAR, camps Lv.CAMP_MIN-CAMP_MAX, the boss at BOSS_LEVEL,
## the same field tuning (MonsterData.ZONE_TUNING / LATE_HP read TUNING and
## LATE_HP), the same EXP boost (GEAR_STAR) and per-role monster multipliers
## inside the same ranges (tests/integration/drowned_abyss_test.gd checks).
##
## Drops of every kill (kill_drops, besides gold, the mount materials, feathers
## and the jewels Zone.jewel_drops rolls from the zone's "jewel_drop" and
## "set_core_drop"): the class's divine pieces (DivineGearData rates), 200★ rings
## and amulets, Lotus Scales (เกล็ดบัวดารา, the 250★ set's jewellery material,
## SetGearData.recipe), stat gems, the 20,000 HP potion and Lv.100 wings.

const ZONES: Array[StringName] = [&"lotus_sanctum", &"drowned_abyss"]
const ENTRY_STAR := 200
## Experience boost of a kill (Zone: 1 + gear_star / 25).
const GEAR_STAR := 250
const TOUGH_HP := 10.0
const CAMP_MIN := 180
const CAMP_MAX := 200
const BOSS_LEVEL := 210
const BOSS_RESPAWN := 150.0
## MonsterData.ZONE_TUNING row of both fields: [normal HP, normal attack, boss HP,
## boss attack], and their MonsterData.LATE_HP. Measured with
## tests/tools/balance_probe.tscn (a 200★ hero in 200★ gear: ~175 basic hits a
## normal monster, ~450 strongest-skill hits the boss).
const TUNING := [0.0411, 80.0, 0.0686, 78.0]
const LATE_HP := 6.0

## Forge jewels a kill (Zone.jewel_drops): three times the purple and chaos and
## twice the pink of the other fields.
const JEWEL_DROP := {"purple": 0.03, "pink": 0.01, "chaos": 0.03}
## The set core (ItemData.JEWELS "set_core"): 0.1% a kill.
const SET_CORE := "set_core"
const SET_CORE_DROP := 0.001
## The Lotus Scale (ItemData.JEWELS "lotus_scale"): the 250★ ring and amulet
## need SetGearData.SCALES each. 0.5% an ordinary monster, 3% an elite, a sure
## SCALE_BOSS from the boss (fortune raises the first two).
const SCALE := "lotus_scale"
const SCALE_NORMAL := 0.005
const SCALE_ELITE := 0.03
const SCALE_BOSS := 2
## 200★ rings and amulets (the divine set has no jewellery): every boss, else
## these chances.
const JEWELRY_NORMAL := 0.10
const JEWELRY_ELITE := 0.40
## Stat gems and the 20,000 HP potion.
const GEM_NORMAL := 0.10
const GEM_ELITE := 0.25
const GEM_BOSS := 4
const POTION_NORMAL := 0.08
const POTION_ELITE := 0.20
const POTION_BOSS := 5
## Lv.100 wings (as in the ★ regions).
const WING_NORMAL := 0.006
const WING_BOSS := 0.6


static func has(zone_id: StringName) -> bool:
	return ZONES.has(zone_id)


## The keys both zone dictionaries share (ZoneData): gate, EXP boost, drop table.
static func zone_fields() -> Dictionary:
	return {"star": ENTRY_STAR, "gear_star": GEAR_STAR, "divine_region": true, "endgame_loot": true,
		"jewel_drop": JEWEL_DROP.duplicate(), "set_core_drop": SET_CORE_DROP}


## Camp i of n spread over CAMP_MIN..CAMP_MAX (each camp spans 6-8 levels).
static func camp_levels(i: int, n: int) -> Array:
	var span := CAMP_MAX - CAMP_MIN - 8
	var low := CAMP_MIN + int(round(float(span) * float(i) / float(maxi(n - 1, 1))))
	return [low, mini(low + (8 if i == n - 1 else 6), CAMP_MAX)]


## Lotus Scales one kill drops (0, 1 or SCALE_BOSS).
static func scale_count(boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> int:
	if boss:
		return SCALE_BOSS
	return 1 if roll.randf() < (SCALE_ELITE if elite else SCALE_NORMAL) * (1.0 + maxf(fortune, 0.0)) else 0


## Gems and potions of a kill (the drowned abyss's table before the merge).
static func supply_drops(boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	var luck := 1.0 + maxf(fortune, 0.0)
	if boss:
		for i in GEM_BOSS:
			out.append(Zone.random_stat_gem(200, 1, true, roll))
		out.append(ItemData.potion("hp_god", POTION_BOSS))
		out.append(ItemData.potion("mp_xxl", 3))
		return out
	if roll.randf() < (GEM_ELITE if elite else GEM_NORMAL) * luck:
		out.append(Zone.random_stat_gem(200, 1, true, roll))
	if roll.randf() < (POTION_ELITE if elite else POTION_NORMAL) * luck:
		out.append(ItemData.potion("hp_god", 1))
	elif roll.randf() < 0.05 * luck:
		out.append(ItemData.potion("mp_xxl", 1))
	return out


## Everything a kill in either field drops besides gold and Zone._drop_jewels:
## divine pieces, 200★ jewellery, Lotus Scales, gems, potions and wings, for a
## hero of class [param cls] (pieces may be any class, ItemData.drop_class).
static func kill_drops(cls: StringName, boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.append_array(DivineGearData.drops(ItemData.drop_class(cls, roll), boss, elite, roll))
	if boss or roll.randf() < (JEWELRY_ELITE if elite else JEWELRY_NORMAL):
		var slot := "ring" if roll.randf() < 0.5 else "amulet"
		out.append(StarProgression.item(ItemData.drop_class(cls, roll), 200, slot, roll))
	var scales := scale_count(boss, elite, fortune, roll)
	if scales > 0 and ItemData.JEWELS.has(SCALE):
		out.append(ItemData.jewel(SCALE, scales))
	out.append_array(supply_drops(boss, elite, fortune, roll))
	if roll.randf() < (WING_BOSS if boss else WING_NORMAL) * (1.0 + maxf(fortune, 0.0)):
		out.append(ItemData.wings(roll, String(ItemData.drop_class(cls, roll))))
	return out


## The drop table as numbers (tests, the world players' gear model, help text).
static func table() -> Dictionary:
	return {"jewel_drop": JEWEL_DROP.duplicate(), "set_core": SET_CORE_DROP,
		"scale": [SCALE_NORMAL, SCALE_ELITE, SCALE_BOSS],
		"divine": [DivineGearData.DROP_NORMAL, DivineGearData.DROP_ELITE, DivineGearData.DROP_BOSS],
		"jewelry": [JEWELRY_NORMAL, JEWELRY_ELITE, 1.0], "gem": [GEM_NORMAL, GEM_ELITE, GEM_BOSS],
		"potion": [POTION_NORMAL, POTION_ELITE, POTION_BOSS], "wing": [WING_NORMAL, WING_NORMAL, WING_BOSS]}


## One Thai line for signs and help: what both fields drop.
static func drop_text() -> String:
	return "ดรอปชุดประจำอาชีพ · แก่นเทพหลอมเซต · เกล็ดบัวดารา · เพชรดรอปเยอะ"
