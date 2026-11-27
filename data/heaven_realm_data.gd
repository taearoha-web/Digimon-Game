class_name HeavenRealmData
extends RefCounted
## ดินแดนเทวาลัย: the celestial temple realm above the clouds, the hunting field from
## ★300 toward ★500. White marble terraces with gold inlay and jade lawns, a golden hall
## of the gods beyond the boss court, floating islets and a sea of cloud below
## (HeavenRealmArt). Its bestiary is HeavenMonsters.
##
## Entered through a portal in ห้วงสมุทรอสูร (Zone._build_star_field) or the warp
## crystal (WarpScreen lists it after the ★300 isle), gated by ENTRY_STAR the way every
## star field is (ZoneData.access_reason with Game.paragon().level).
##
## Band (above เกาะลอยฟ้าเทพมังกร, SkyIsleData): camps Lv.CAMP_MIN-CAMP_MAX, the boss at
## BOSS_LEVEL, its own MonsterData.ZONE_TUNING / LATE_HP rows (TUNING, LATE_HP: the isle's
## health and attack rows raised by HP_STEP / ATK_STEP), EXP boost x(1 + GEAR_STAR / 25).
##
## Drops (zone flag "heaven_loot", Zone._heaven_loot = kill_drops): the forge jewels and the
## set core from the zone's "jewel_drop" / "set_core_drop" (Zone.jewel_drops, above the
## ★200-300 fields), a sure set core from the boss and SET_CORE_ELITE from an elite, Lotus
## Scales, perfect stat gems, the 20,000 HP potion, Lv.100 wings, and the ★500 gear of
## Star500Gear (data/star500_gear_data.gd, another module: star500_drop calls it only when
## that file is there, so this field works with or without it).

const ID: StringName = &"heaven_realm"
const TITLE := "ดินแดนเทวาลัย"
const ENTRY_STAR := 300
## Experience boost of a kill (Zone: 1 + gear_star / 25): x15, the isle has x13.
const GEAR_STAR := 350
const CAMP_MIN := 240
const CAMP_MAX := 270
const BOSS_LEVEL := 285
const BOSS_RESPAWN := 200.0
## MonsterData.ZONE_TUNING row [normal HP, normal attack, boss HP, boss attack]: the isle's
## (SkyIsleData.TUNING) raised, and its LATE_HP.
const HP_STEP := 1.15
const ATK_STEP := 1.1
const TUNING := [0.0692 * HP_STEP, 424.0 * ATK_STEP, 0.1367 * HP_STEP, 513.0 * 2.0 * ATK_STEP]
const LATE_HP := 6.0

## The forge jewels a kill (Zone.jewel_drops) and the set core: above EndgameFields'.
const JEWEL_DROP := {"purple": 0.04, "pink": 0.015, "chaos": 0.04}
const SET_CORE := "set_core"
const SET_CORE_DROP := 0.002
## Extra set cores: SET_CORE_ELITE an elite, SET_CORE_BOSS sure from the boss.
const SET_CORE_ELITE := 0.015
const SET_CORE_BOSS := 1
## Lotus Scales (EndgameFields.SCALE): normal, elite chance, the boss's sure count.
const SCALE_NORMAL := 0.008
const SCALE_ELITE := 0.05
const SCALE_BOSS := 3
## Perfect stat gems and the 20,000 HP potion: normal, elite chance, the boss's count.
const GEM_NORMAL := 0.14
const GEM_ELITE := 0.35
const GEM_BOSS := 6
const POTION_NORMAL := 0.10
const POTION_ELITE := 0.25
const POTION_BOSS := 6
## Lv.100 wings.
const WING_NORMAL := 0.008
const WING_BOSS := 0.7
## ★500 gear (Star500Gear.drop): rare from ordinary monsters, better from elites and
## the boss. Each chance is raised by the drop luck (fortune).
const STAR500_GEAR_PATH := "res://data/star500_gear_data.gd"
## The ★500 piece chance of a kill these give (Star500Gear.PIECE_CHANCE / BOSS_PIECE_CHANCE,
## an elite ELITE_TRIES rolls), before fortune.
const STAR500_NORMAL := 0.002
const ELITE_TRIES := 3
const STAR500_ELITE := 0.006
const STAR500_BOSS := 0.1
## Where the ★500 gear module is looked for (a test points it at a stand-in).
static var star500_path := STAR500_GEAR_PATH

const CAMP_NAMES := ["ลานโคมสวรรค์", "ทุ่งเมฆสุนัขฟ้า", "สระหงส์ทอง", "ระเบียงยักษ์หยก", "อาศรมฤๅษีเมฆา", "ลานเทพทวารบาล", "บันไดนาคทองคำ"]


## Camp i of n spread over CAMP_MIN..CAMP_MAX (each camp spans 6-8 levels).
static func camp_levels(i: int, n: int) -> Array:
	var span := CAMP_MAX - CAMP_MIN - 8
	var low := CAMP_MIN + int(round(float(span) * float(i) / float(maxi(n - 1, 1))))
	return [low, mini(low + (8 if i == n - 1 else 6), CAMP_MAX)]


## The zone dictionary (ZoneData).
static func zone() -> Dictionary:
	# Five farm camps of one kind each (the fourth and fifth with an elite now and then),
	# the gate-guardians' court of both elites, and the golden stair of the naga.
	var N := HeavenMonsters.NORMALS
	var positions: Array = HeavenRealmArt.layout().camp_positions
	var camps: Array = []
	for i in 7:
		var ids: Array = [N[i]] if i < 5 else []
		if i == 3: ids = [N[3], N[3], N[3], &"heaven_gatekeeper"]
		elif i == 4: ids = [N[4], N[4], N[4], &"celestial_naga"]
		elif i == 5: ids = [N[3], N[1], &"heaven_gatekeeper", &"celestial_naga"]
		elif i == 6: ids = [N[2], N[0], N[2], &"celestial_naga"]
		camps.append({"name": CAMP_NAMES[i], "monsters": ids, "levels": camp_levels(i, 7), "pos": positions[i], "radius": 9.0, "count": 9})
	return {"name": TITLE, "scene": "field", "theme": ID,
		"level": [100, 100], "music": ID, "ambience": &"wind", "weather": &"motes",
		"sky": Color("7fbcf0"), "fog": Color("dcebf8"), "ambient": Color("fff2de"), "sun": Color("ffe4b0"), "ground": Color("efe6d2"),
		"sky_palette": [Color("3f86dc"), Color("a8d4f6"), Color("fff0d8")], "sun_size": 1.8, "moon": false,
		"camps": camps,
		"boss": {"monster": HeavenMonsters.BOSS, "level": BOSS_LEVEL, "respawn": BOSS_RESPAWN, "star": ENTRY_STAR},
		"star": ENTRY_STAR, "gear_star": GEAR_STAR, "divine_region": true,
		"endgame_loot": false, "heaven_loot": true,
		"jewel_drop": JEWEL_DROP.duplicate(), "set_core_drop": SET_CORE_DROP,
		"prev": DrownedAbyssData.ID, "next": &""}


## The entrance and portal sign line.
static func sign_text() -> String:
	return "%s • ดาว %d ขึ้นไป" % [TITLE, ENTRY_STAR]


## One Thai line for the warp list, the entrance sign and help.
static func drop_text() -> String:
	return "อุปกรณ์ 500 ดาว · แก่นเทพหลอมเซต · เกล็ดบัวดารา · เพชรเทพ · ปีก"


## Whether the ★500 gear module (Star500Gear) is in the game.
static func star500_ready() -> bool:
	return _star500_script() != null


static func _star500_script() -> Script:
	if not ResourceLoader.exists(star500_path):
		return null
	var script := load(star500_path) as Script
	if script == null:
		return null
	for m in script.get_script_method_list():
		if String(m.get("name", "")) == "drop":
			return script
	return null


## A ★500 gear piece from Star500Gear.drop(rng, cls, from_boss), or {} when the module
## is not there (or gives nothing back).
static func star500_drop(roll: RandomNumberGenerator, cls: StringName, from_boss: bool) -> Dictionary:
	var script := _star500_script()
	if script == null:
		return {}
	var item: Variant = script.call("drop", roll, cls, from_boss)
	return item if item is Dictionary else {}


## The ★500 pieces the last kill_drops call gave (Zone._heaven_loot marks them).
static var _star500_items: Array = []


## Whether [param item] is a ★500 gear piece: one the last kill_drops call got from
## Star500Gear, or any piece of 500 stars and up.
static func is_star500_item(item: Dictionary) -> bool:
	if _star500_items.any(func(x): return is_same(x, item)):
		return true
	return int(item.get("star_tier", 0)) >= 500


## The ★500 gear chance of a kill (before fortune).
static func star500_chance(boss: bool, elite: bool) -> float:
	return STAR500_BOSS if boss else (STAR500_ELITE if elite else STAR500_NORMAL)


## Everything a kill drops besides gold and Zone._drop_jewels (the forge jewels and the
## zone's set core roll), for a hero of class [param cls].
static func kill_drops(cls: StringName, boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	var luck := 1.0 + maxf(fortune, 0.0)
	_star500_items.clear()
	# ★500 gear first: Star500Gear.drop makes the one chance roll (a piece, else its
	# แก่นเทวาลัย) and picks the class itself; an elite gets ELITE_TRIES of it, fortune
	# a share of one more.
	var tries := ELITE_TRIES if elite and not boss else 1
	if roll.randf() < luck - 1.0:
		tries += 1
	for i in tries:
		var piece := star500_drop(roll, cls, boss)
		if not piece.is_empty():
			out.append(piece)
			if String(piece.get("kind", "")) != "jewel":
				_star500_items.append(piece)
	if ItemData.JEWELS.has(SET_CORE):
		if boss:
			out.append(ItemData.jewel(SET_CORE, SET_CORE_BOSS))
		elif elite and roll.randf() < SET_CORE_ELITE * luck:
			out.append(ItemData.jewel(SET_CORE))
	var scales := SCALE_BOSS if boss else (1 if roll.randf() < (SCALE_ELITE if elite else SCALE_NORMAL) * luck else 0)
	if scales > 0 and ItemData.JEWELS.has(EndgameFields.SCALE):
		out.append(ItemData.jewel(EndgameFields.SCALE, scales))
	if boss:
		for i in GEM_BOSS:
			out.append(Zone.random_stat_gem(200, 1, true, roll))
		out.append(ItemData.potion("hp_god", POTION_BOSS))
		out.append(ItemData.potion("mp_xxl", 4))
	else:
		if roll.randf() < (GEM_ELITE if elite else GEM_NORMAL) * luck:
			out.append(Zone.random_stat_gem(200, 1, true, roll))
		if roll.randf() < (POTION_ELITE if elite else POTION_NORMAL) * luck:
			out.append(ItemData.potion("hp_god", 1))
		elif roll.randf() < 0.06 * luck:
			out.append(ItemData.potion("mp_xxl", 1))
	if roll.randf() < (WING_BOSS if boss else WING_NORMAL) * luck:
		out.append(ItemData.wings(roll, String(ItemData.drop_class(cls, roll))))
	return out


## The drop table as numbers (tests, help text).
static func table() -> Dictionary:
	return {"jewel_drop": JEWEL_DROP.duplicate(), "set_core": [SET_CORE_DROP, SET_CORE_ELITE, SET_CORE_BOSS],
		"scale": [SCALE_NORMAL, SCALE_ELITE, SCALE_BOSS], "gem": [GEM_NORMAL, GEM_ELITE, GEM_BOSS],
		"potion": [POTION_NORMAL, POTION_ELITE, POTION_BOSS], "wing": [WING_NORMAL, WING_NORMAL, WING_BOSS],
		"star500": [STAR500_NORMAL, STAR500_ELITE, STAR500_BOSS]}
