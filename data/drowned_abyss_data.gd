class_name DrownedAbyssData
extends RefCounted
## ห้วงสมุทรอสูร: the post-story levelling field for 200★ to 300★, beyond the
## Lotus Sanctum. A drowned temple city on the sea floor with its own bestiary
## (existing Quaternius rigs re-dressed: new names, sizes, palettes and a
## bioluminescent aura, see DeepMonsterArt). Its difficulty band and its drop
## table are the Lotus Sanctum's (EndgameFields): the forge jewels three times as
## often as anywhere else, the divine class pieces, the rare set material
## ("set_core"), Lotus Scales, 200★ jewellery, the 20,000 HP potion, gems,
## wings and the mount materials.
## The entry needs ENTRY_STAR stars, read the way every star field does
## (ZoneData.access_reason with Game.paragon().level), so it stays open once
## the star cap grows past 200.

const ID: StringName = &"drowned_abyss"
const TITLE := "ห้วงสมุทรอสูร"
const ENTRY_STAR := EndgameFields.ENTRY_STAR
## Experience boost of a kill here (Zone: 1 + gear_star / 25), as in the sanctuary.
const GEAR_STAR := EndgameFields.GEAR_STAR
## Like the star regions, every monster has ten times its designed health.
const TOUGH_HP := EndgameFields.TOUGH_HP

## The shared table's numbers under their old names (EndgameFields).
const JEWEL_DROP := EndgameFields.JEWEL_DROP
const SET_CORE := EndgameFields.SET_CORE
const SET_CORE_DROP := EndgameFields.SET_CORE_DROP
const GEM_NORMAL := EndgameFields.GEM_NORMAL
const GEM_ELITE := EndgameFields.GEM_ELITE
const GEM_BOSS := EndgameFields.GEM_BOSS
const POTION_NORMAL := EndgameFields.POTION_NORMAL
const POTION_ELITE := EndgameFields.POTION_ELITE
const POTION_BOSS := EndgameFields.POTION_BOSS

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
	# The summoner's Poseidon himself, grown to a boss: the same rig and clips (Attack throws
	# a water orb, Skill1 / Skill2 cast his two legend skills, LegendMoves) and his own colours.
	&"tidal_tyrant": {"name": "โพไซดอน ราชันสมุทรอสูร", "model": "summon/Poseidon", "height": 5.8, "hp": 32.0, "atk": 3.4, "def": 2.6, "speed": 2.8, "aggro": true, "attack": "ranged", "boss": true,
		"color": Color("5cc8ff"), "tint": Color.WHITE, "aura": Color("5cc8ff"), "projectile": "orb", "legend": "poseidon",
		"behavior": "maelstrom", "behavior2": "glacial_bloom", "alternate": true, "exp": 3.4, "gold": 5.0},
}
const NORMALS: Array[StringName] = [&"abyss_angler", &"reef_crab", &"tide_squid", &"drown_jelly", &"abyss_merman"]
const ELITES: Array[StringName] = [&"trench_horror", &"leviathan_whelp"]
const BOSS: StringName = &"tidal_tyrant"
const CAMP_NAMES := ["ลานโคมมรณะ", "แนวปะการังโลหิต", "ซากวิหารหมึกเงา", "สวนแมงกะพรุนวิญญาณ", "ค่ายเงือกทมิฬ", "ร่องลึกเลวีอาธาน"]


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
		camps.append({"name": CAMP_NAMES[i], "monsters": ids, "levels": EndgameFields.camp_levels(i, 6), "pos": positions[i], "radius": 9.0, "count": 9})
	# Post-story like the sanctuary (EndgameFields.zone_fields: "divine_region", so
	# ★-field rules, world boss on weekends, perfect gems; the shared gate and drops).
	var out := {"name": TITLE, "scene": "field", "theme": ID,
		"level": [100, 100], "music": ID, "ambience": &"water", "weather": &"bubbles",
		"sky": Color("10324a"), "fog": Color("1d6a7c"), "ambient": Color("6fc9d8"), "sun": Color("9fe8ff"), "ground": Color("1f4a52"),
		"sky_palette": [Color("040d1e"), Color("0c3550"), Color("1e7486")], "sun_size": 0.0, "moon": true,
		"camps": camps,
		"boss": {"monster": BOSS, "level": EndgameFields.BOSS_LEVEL, "respawn": EndgameFields.BOSS_RESPAWN, "star": ENTRY_STAR},
		"prev": DivineRegionData.ID, "next": &""}
	out.merge(EndgameFields.zone_fields(), true)
	return out


## Gems and potions a kill drops (EndgameFields.supply_drops; the whole shared
## table is EndgameFields.kill_drops).
static func kill_drops(boss: bool, elite: bool, fortune: float, roll: RandomNumberGenerator) -> Array:
	return EndgameFields.supply_drops(boss, elite, fortune, roll)
