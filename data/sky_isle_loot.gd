class_name SkyIsleLoot
extends RefCounted
## What a kill on เกาะลอยฟ้าเทพมังกร drops besides gold and Zone._drop_jewels: everything
## the two ★200-300 fields drop (EndgameFields) except their Lv.100 wings, plus the isle's
## own: the Dragon God weapon, the 300★ wings, costume fragments, the mount's egg and
## treasure chests. The jackpots are announced to the whole server (Announcer).
## CONTRACT STUB (docs/SKY_ISLE_PLAN.md): the collectibles team writes the bodies; the
## names and the owner's rates stay.

## The owner's rates, a kill of any monster (fortune does not raise the four jackpots).
const WEAPON_DROP := 0.005
const WING_DROP := 0.001
const FRAGMENT_DROP := 0.001
const EGG_DROP := 0.001
## ItemData.JEWELS ids of the isle's stackable drops.
const FRAGMENT := "dragon_fragment"
const EGG := "sky_dragon_egg"
const CHEST := "dragon_chest"
## The costume the fragments make (RewardShop.COSTUMES id) and how many it takes.
const COSTUME := "dragon_god"
const COSTUME_FRAGMENTS := 50
## The mount the eggs make (MountData.MOUNTS id).
const MOUNT := "sky_dragon"


## Every item one kill drops (gold and the forge jewels aside), for a hero of class cls.
static func kill_drops(cls: StringName, boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	if roll.randf() < WEAPON_DROP:
		out.append(DragonGearData.weapon(ItemData.drop_class(cls, roll), roll))
	if roll.randf() < WING_DROP:
		out.append(DragonGearData.wings(ItemData.drop_class(cls, roll), roll))
	return out


## What the rare dragon (Zone, the zone flag "rare_dragon") drops when it falls.
static func rare_drops(cls: StringName, roll: RandomNumberGenerator) -> Array:
	return kill_drops(cls, true, false, 0.0, roll)


## A drop the whole server hears about.
static func is_jackpot(item: Dictionary) -> bool:
	return DragonGearData.is_item(item)


## Tells the server that [param who] (the hero when "") got [param item].
static func announce(item: Dictionary, who := "") -> void:
	var name := who if who != "" else (String(Game.profile.get("name", "")) if Game.has_profile else "")
	Announcer.broadcast("%s ได้รับ %s จาก%s!" % [name, ItemData.name_of(item), SkyIsleData.TITLE])
