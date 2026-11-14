class_name SkyIsleData
extends RefCounted
## เกาะลอยฟ้าเทพมังกร: the ★300 hunting field beyond ห้วงสมุทรอสูร. A chain of floating
## islands round the Dragon God's shrine, with its own dragon bestiary and boss.
## CONTRACT STUB (docs/SKY_ISLE_PLAN.md): the map team replaces the zone, the bestiary and
## the numbers; ID, TITLE, ENTRY_STAR, the zone flags "sky_isle_loot" and "rare_dragon"
## and the function names stay.

const ID: StringName = &"sky_dragon_isle"
const TITLE := "เกาะลอยฟ้าเทพมังกร"
const ENTRY_STAR := 300


static func has_monster(_id: StringName) -> bool:
	return false


static func monster(_id: StringName) -> Dictionary:
	return {}


## The zone dictionary (ZoneData). Stub: the drowned abyss's layout under the isle's name,
## gate and loot flags.
static func zone() -> Dictionary:
	var out := DrownedAbyssData.zone()
	out["name"] = TITLE
	out["star"] = ENTRY_STAR
	out["prev"] = DrownedAbyssData.ID
	out["next"] = &""
	out["endgame_loot"] = false
	out["sky_isle_loot"] = true
	out["rare_dragon"] = true
	if out.has("boss"):
		out["boss"]["star"] = ENTRY_STAR
	return out
