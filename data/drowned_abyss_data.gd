class_name DrownedAbyssData
extends RefCounted
## ห้วงสมุทรอสูร: the post-story levelling field for 200★ to 300★, beyond the
## Lotus Sanctum. A drowned temple city on the sea floor with its own bestiary
## (existing Quaternius rigs re-dressed: new names, sizes, palettes and a
## bioluminescent aura, see DeepMonsterArt) and its own drop table: the forge
## jewels three times as often as anywhere else, the 20,000 HP potion, gems,
## the mount materials and the rare set material ("set_core").
## The entry needs ENTRY_STAR stars, read the way every star field does
## (ZoneData.access_reason with Game.paragon().level), so it stays open once
## the star cap grows past 200.

const ID: StringName = &"drowned_abyss"
const TITLE := "ห้วงสมุทรอสูร"
const ENTRY_STAR := 200
## Experience boost of a kill here (Zone: 1 + gear_star / 25): the climb from
## 200★ to 300★ takes about fifteen kills a star.
const GEAR_STAR := 250
## Like the star regions, every monster has ten times its designed health.
const TOUGH_HP := 10.0

## Forge jewels per kill (Zone.jewel_drops reads the zone's "jewel_drop"):
## three times the purple and chaos rate and twice the pink rate of other fields.
const JEWEL_DROP := {"purple": 0.03, "pink": 0.01, "chaos": 0.03}
## The set material (the set crafting's own jewel, ItemData.JEWELS["set_core"]):
## 0.1% a kill, rolled only in this field.
const SET_CORE := "set_core"
const SET_CORE_DROP := 0.001
## Gems and potions a kill drops on top of the jewels and gold.
const GEM_NORMAL := 0.10
const GEM_ELITE := 0.25
const GEM_BOSS := 4
const POTION_NORMAL := 0.08
const POTION_ELITE := 0.20
const POTION_BOSS := 5

## Normal monsters fight with MobAttack moves, the tyrant with BossAttack's.
## "aura" colours the glow DeepMonsterArt puts on each of them.
const MONSTERS := {
	&"abyss_angler": {"name": "ปลาโคมมรณะ", "model": "big/Fish", "height": 2.3, "hover": 0.5, "hp": 2.0, "atk": 2.2, "def": 1.3, "speed": 2.8, "aggro": true, "attack": "ranged",
		"color": Color("6ef3ff"), "tint": Color(0.5, 1.15, 1.5), "aura": Color("6ef3ff"), "behavior": "mortar", "exp": 1.6, "gold": 2.0},
	&"reef_crab": {"name": "ปูเกราะปะการังโลหิต", "model": "dawn/Crab", "height": 2.1, "hp": 2.6, "atk": 2.1, "def": 1.8, "speed": 2.6, "aggro": true, "attack": "melee",
		"color": Color("ff5a7a"), "tint": Color(1.5, 0.55, 0.7), "aura": Color("ff5a7a"), "behavior": "spin", "exp": 1.7, "gold": 2.1},
	&"tide_squid": {"name": "หมึกเงาคลื่นคลั่ง", "model": "flying/Squidle", "height": 2.3, "hover": 0.9, "hp": 2.0, "atk": 2.4, "def": 1.2, "speed": 2.9, "aggro": true, "attack": "ranged",
		"color": Color("b98cff"), "tint": Color(0.9, 0.7, 1.6), "aura": Color("b98cff"), "behavior": "beam", "exp": 1.65, "gold": 2.0},
	&"drown_jelly": {"name": "แมงกะพรุนวิญญาณจมน้ำ", "model": "flying/Glub_Evolved", "height": 2.1, "hover": 1.1, "hp": 1.9, "atk": 2.3, "def": 1.2, "speed": 2.7, "aggro": true, "attack": "ranged",
		"color": Color("7affd8"), "tint": Color(0.7, 1.5, 1.3), "aura": Color("7affd8"), "behavior": "volley", "exp": 1.6, "gold": 2.0},
	&"abyss_merman": {"name": "นักรบเงือกทมิฬ", "model": "big/Ninja", "height": 2.6, "hp": 2.3, "atk": 2.5, "def": 1.5, "speed": 3.6, "aggro": true, "attack": "melee",
		"color": Color("4ad8c8"), "tint": Color(0.45, 1.0, 1.1), "aura": Color("4ad8c8"), "behavior": "lunge", "exp": 1.75, "gold": 2.2},
	&"trench_horror": {"name": "อสูรหนวดร่องลึก", "model": "cute/Cthulhu", "height": 3.5, "hp": 5.5, "atk": 2.8, "def": 2.2, "speed": 2.9, "aggro": true, "attack": "ranged", "elite": true,
		"color": Color("3affc8"), "tint": Color(0.4, 1.4, 1.2), "aura": Color("3affc8"), "behavior": "beam", "exp": 2.6, "gold": 3.0},
	&"leviathan_whelp": {"name": "ลูกเลวีอาธานคลั่ง", "model": "flying/Dragon", "height": 3.7, "hover": 0.5, "hp": 6.0, "atk": 2.7, "def": 2.4, "speed": 3.2, "aggro": true, "attack": "melee", "elite": true,
		"color": Color("2ab8ff"), "tint": Color(0.4, 0.9, 1.6), "aura": Color("2ab8ff"), "behavior": "pounce", "exp": 2.7, "gold": 3.0},
	&"tidal_tyrant": {"name": "ทาลัสซาร์ ราชันสมุทรอสูร", "model": "summon/Poseidon", "height": 5.8, "hp": 32.0, "atk": 3.4, "def": 2.6, "speed": 2.8, "aggro": true, "attack": "ranged", "boss": true,
		"color": Color("5cf0ff"), "tint": Color(0.55, 0.95, 1.35), "aura": Color("5cf0ff"), "behavior": "freeze_ring", "behavior2": "rift_trail", "exp": 3.4, "gold": 5.0},
}
const NORMALS: Array[StringName] = [&"abyss_angler", &"reef_crab", &"tide_squid", &"drown_jelly", &"abyss_merman"]
const ELITES: Array[StringName] = [&"trench_horror", &"leviathan_whelp"]
const BOSS: StringName = &"tidal_tyrant"
const CAMP_NAMES := ["ลานโคมมรณะ", "แนวปะการังโลหิต", "ซากวิหารหมึกเงา", "สวนแมงกะพรุนวิญญาณ", "ค่ายเงือกทมิฬ", "ร่องลึกเลวีอาธาน"]
const CAMP_LEVELS := [[180, 186], [182, 188], [184, 190], [186, 192], [188, 196], [192, 200]]


static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)


static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * TOUGH_HP
	return m


static func zone() -> Dictionary:
	# Five farm camps of one kind each (the last two with an elite now and then)
	# and a deep trench of both elites with the reef's crabs.
	var positions: Array = DrownedAbyssArt.layout().camp_positions
	var camps: Array = []
	for i in 6:
		var ids: Array = [NORMALS[i]] if i < 5 else [&"reef_crab", &"reef_crab", &"trench_horror", &"leviathan_whelp"]
		if i == 3: ids = [NORMALS[i], NORMALS[i], NORMALS[i], &"trench_horror"]
		elif i == 4: ids = [NORMALS[i], NORMALS[i], NORMALS[i], &"leviathan_whelp"]
		camps.append({"name": CAMP_NAMES[i], "monsters": ids, "levels": CAMP_LEVELS[i], "pos": positions[i], "radius": 9.0, "count": 9})
	return {"name": TITLE, "scene": "field", "theme": ID, "star": ENTRY_STAR, "gear_star": GEAR_STAR,
		# Post-story like the sanctuary: ★-field rules (world boss on weekends,
		# perfect gems) and it may follow the ending field in the travel chain.
		"divine_region": true,
		"level": [100, 100], "music": ID, "ambience": &"water", "weather": &"bubbles",
		"jewel_drop": JEWEL_DROP, "set_core_drop": SET_CORE_DROP,
		"sky": Color("10324a"), "fog": Color("1d6a7c"), "ambient": Color("6fc9d8"), "sun": Color("9fe8ff"), "ground": Color("1f4a52"),
		"sky_palette": [Color("040d1e"), Color("0c3550"), Color("1e7486")], "sun_size": 0.0, "moon": true,
		"camps": camps,
		"boss": {"monster": BOSS, "level": 210, "respawn": 150.0, "star": ENTRY_STAR},
		"prev": DivineRegionData.ID, "next": &""}


## What a kill here drops besides gold, the jewels (Zone.jewel_drops) and the
## mount materials: stat gems and the 20,000 HP potion (hp_god), mana now and then.
## Chances grow by (1 + fortune) like every drop.
static func kill_drops(boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
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
