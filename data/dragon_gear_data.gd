class_name DragonGearData
extends RefCounted
## The Dragon God's gear, dropped only on เกาะลอยฟ้าเทพมังกร (SkyIsleLoot): one weapon a
## class (อาวุธเทพมังกร) and one pair of 300★ wings a class (ปีกเทพมังกร 300 ดาว).
## CONTRACT STUB (docs/SKY_ISLE_PLAN.md): the gear team replaces the bodies (names, stats,
## looks, icons); the function names and the "dragon" marker key stay.

## item["dragon"]: 1 on every piece of this file.
const KEY := "dragon"
const WING_STARS := 300


## The Dragon God weapon of class [param cls].
static func weapon(cls: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var item := StarProgression.item(cls, 200, "weapon", rng)
	item[KEY] = 1
	return item


## The 300★ Dragon God wings of class [param cls].
static func wings(cls: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var item := StarWingData.item(String(cls), rng)
	item[KEY] = 1
	return item


static func is_item(item: Dictionary) -> bool:
	return int(item.get(KEY, 0)) > 0


static func is_weapon(item: Dictionary) -> bool:
	return is_item(item) and String(item.get("slot", "")) == "weapon"


static func is_wings(item: Dictionary) -> bool:
	return is_item(item) and String(item.get("slot", "")) == "wings"
