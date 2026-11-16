class_name SkyIsleData
extends RefCounted
## เกาะลอยฟ้าเทพมังกร: the ★300 hunting field beyond ห้วงสมุทรอสูร. A chain of floating
## islands round the Dragon God's shrine, high over a sea of cloud (SkyIsleArt), with an
## all-dragon bestiary and the hardest field boss of the game, เทพมังกร. The dragon-shaped
## ones ("celestial": a CelestialDragon kind) are the long eastern dragon of the Summoner's
## god skill จักรพรรดิมังกรสวรรค์, each in its own palette, pose, horns and moves; the kirin
## ("beast": "kirin") is sculpted in code the same way (Kirin, KirinVisual); the drake is a
## re-dressed rig. All wear DragonMonsterArt's celestial dressing.
##
## Band (above the ★200-300 fields, EndgameFields): entry at ENTRY_STAR, camps
## Lv.CAMP_MIN-CAMP_MAX, the boss at BOSS_LEVEL, its own MonsterData.ZONE_TUNING / LATE_HP
## rows (TUNING, LATE_HP) measured with tests/tools/balance_probe.tscn against a ★300 hero
## in the 250★ set at +15 (checkpoint "sky_dragon_isle").
##
## Drops: SkyIsleLoot (the zone flag "sky_isle_loot"), the rare dragon (flag "rare_dragon")
## and, as in the Poseidon field, the forge jewels and the set core Zone.jewel_drops rolls
## from the zone's "jewel_drop" / "set_core_drop". Not the shared endgame table
## ("endgame_loot" is false): the isle drops no Lv.100 wings.

const ID: StringName = &"sky_dragon_isle"
const TITLE := "เกาะลอยฟ้าเทพมังกร"
const ENTRY_STAR := 300
## Experience boost of a kill here (Zone: 1 + gear_star / 25): x13, the abyss has x11.
const GEAR_STAR := 300
## Like the star regions, every monster has ten times its designed health.
const TOUGH_HP := 10.0
const CAMP_MIN := 205
const CAMP_MAX := 235
const BOSS_LEVEL := 245
const BOSS_RESPAWN := 180.0
## MonsterData.ZONE_TUNING row: [normal HP, normal attack, boss HP, boss attack], and
## MonsterData.LATE_HP. Measured with the balance probe: a ★300 hero in the 250★ set +15
## needs about 175 basic hits a normal monster (the abyss's band for a ★200 hero in ★200
## gear) and about 600 strongest-skill hits for the Dragon God (the abyss's Poseidon: 450);
## a normal monster needed about 18 hits to bring that hero down, the boss 5-6 (the abyss: 20
## and 8). Then the owner asked for the isle to bite harder (health unchanged): the Dragon
## God hits five times as hard (BOSS_ATK on the measured 513, his normal hits and both
## moves: a heavy hit now all but fells that hero, about 1.1 hits; dodge the circles), and
## the normal monsters twice as hard (NORMAL_ATK, about 9 hits). The elites share the
## normal attack row and keep their strength.
const BOSS_ATK := 5.0
const NORMAL_ATK := 2.0
const TUNING := [0.0692, 424.0, 0.1367, 513.0 * BOSS_ATK]
const LATE_HP := 6.0

## Normal monsters fight with MobAttack moves, the Dragon God with BossAttack's two
## signature moves from the start ("alternate"). "model" is the rig of a non-celestial
## monster (and the fallback of a celestial one). "paint" repaints the rig's flat materials by name
## (the wyrmling's rig is textured: its "tint" does it), "aura" colours DragonMonsterArt's
## dressing, "decor" picks its extra piece, "halo" the colour of the god's sun-halo.
const MONSTERS := {
	&"cloud_whelp": {"name": "ลูกมังกรเมฆา", "celestial": "whelp", "model": "flying/Dragon", "height": 2.0, "hover": 0.9, "hp": 2.0, "atk": 2.3, "def": 1.3, "speed": 3.1, "aggro": true, "attack": "ranged",
		"color": Color("bfe9ff"), "tint": Color.WHITE, "paint": {"Dragon_Main": Color("eef6ff"), "Dragon_Secondary": Color("6fbdf0"), "Dragon_Horn": Color("ffd76a")}, "aura": Color("bfe9ff"), "decor": "cloud", "behavior": "volley", "exp": 2.2, "gold": 2.8},
	&"jade_drake": {"name": "เดรกเกล็ดหยก", "model": "big/Dino", "height": 2.7, "hp": 2.7, "atk": 2.2, "def": 1.9, "speed": 2.9, "aggro": true, "attack": "melee",
		"color": Color("5fe0a8"), "tint": Color.WHITE, "paint": {"Dino_Main": Color("2fb48a"), "Dino_Secondary": Color("eaf4c4")}, "aura": Color("5fe0a8"), "decor": "horns", "behavior": "pounce", "exp": 2.3, "gold": 2.9},
	&"gold_wyrmling": {"name": "มังกรน้อยเกล็ดทอง", "celestial": "wyrmling", "model": "cute/YellowDragon", "height": 2.3, "hp": 2.3, "atk": 2.4, "def": 1.5, "speed": 3.0, "aggro": true, "attack": "melee",
		"color": Color("ffd05a"), "tint": Color(1.3, 1.15, 0.6), "paint": {}, "aura": Color("ffd05a"), "decor": "pearl", "behavior": "spin", "exp": 2.25, "gold": 3.1},
	&"cloud_kirin": {"name": "กิเลนเหยียบเมฆ", "beast": "kirin", "model": "star/Horse_White", "height": 2.7, "hp": 2.2, "atk": 2.6, "def": 1.4, "speed": 3.9, "aggro": true, "attack": "melee",
		"color": Color("ffd36a"), "tint": Color.WHITE, "paint": {"Main": Color("fff6f2"), "Main_Light": Color("ffdbe8"), "Hooves": Color("f0bf4c"), "Hair": Color("ff8fbe"), "Muzzle": Color("ffd2c4")}, "aura": Color("6ff0cc"), "decor": "kirin", "behavior": "lunge", "exp": 2.3, "gold": 2.9},
	&"storm_wyvern": {"name": "ไวเวิร์นอัสนี", "celestial": "wyvern", "model": "dawn/Bat", "height": 3.2, "hover": 0.4, "hp": 2.0, "atk": 2.7, "def": 1.2, "speed": 3.3, "aggro": true, "attack": "ranged",
		"color": Color("b08cff"), "tint": Color.WHITE, "paint": {"Main": Color("6a4fd0"), "Black": Color("2c2670"), "Belly": Color("d4c4ff"), "Nose": Color("ff9ae0")}, "aura": Color("b08cff"), "decor": "sparks", "behavior": "beam", "exp": 2.35, "gold": 2.9},
	&"shrine_dragon": {"name": "มังกรผู้เฝ้าศาลเทพ", "celestial": "guardian", "model": "flying/Dragon_Evolved", "height": 3.8, "hover": 0.6, "hp": 6.0, "atk": 3.0, "def": 2.3, "speed": 3.1, "aggro": true, "attack": "ranged", "elite": true,
		"color": Color("5fe8b8"), "tint": Color.WHITE, "paint": {"Dragon_Main": Color("dc4630"), "Dragon_Secondary": Color("f2bd48"), "Dragon_Horn": Color("fff0c8")}, "aura": Color("7af0c8"), "decor": "pearl", "behavior": "mortar", "exp": 3.6, "gold": 4.2},
	&"emerald_elder": {"name": "พญามังกรมรกต", "celestial": "elder", "model": "dawn/Dragon", "height": 4.2, "hover": 0.0, "hp": 6.6, "atk": 2.9, "def": 2.6, "speed": 3.0, "aggro": true, "attack": "melee", "elite": true,
		"color": Color("3ff0a0"), "tint": Color.WHITE, "paint": {"Main": Color("22a872"), "Wings": Color("0f6f60"), "Belly": Color("f2e6a0"), "Claws": Color("f0bf4c")}, "aura": Color("3ff0a0"), "decor": "horns", "behavior": "cleave", "exp": 3.7, "gold": 4.2},
	# The Dragon God: the god skill's dragon in white gold, coiled on his cloud, crowned and
	# antlered in gold with a jade mane, a jade sun-halo behind his head and the dragon pearl
	# before him (CelestialDragon "god", DragonMonsterArt "god").
	&"dragon_god": {"name": "เทพมังกร", "celestial": "god", "model": "dawn/Dragon", "height": 5.0, "hover": 0.0, "hp": 40.0, "atk": 3.7, "def": 3.0, "speed": 3.0, "aggro": true, "attack": "ranged", "boss": true,
		"color": Color("ffd766"), "tint": Color.WHITE, "paint": {"Main": Color("fff3dc"), "Wings": Color("f2b83a"), "Belly": Color("ffd35a"), "Claws": Color("46b894")}, "aura": Color("ffd766"), "halo": Color("7df0c4"), "decor": "god", "projectile": "orb",
		"behavior": "dragon_breath", "behavior2": "heavens_fall", "alternate": true, "exp": 4.6, "gold": 7.0},
}
const NORMALS: Array[StringName] = [&"cloud_whelp", &"jade_drake", &"gold_wyrmling", &"cloud_kirin", &"storm_wyvern"]
const ELITES: Array[StringName] = [&"shrine_dragon", &"emerald_elder"]
const BOSS: StringName = &"dragon_god"
const CAMP_NAMES := ["รังลูกมังกรเมฆา", "ลานหินเดรกหยก", "เนินมังกรทอง", "ทุ่งกิเลนเหยียบเมฆ", "ผาไวเวิร์นอัสนี", "สุสานกระดูกมังกร"]


static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)


static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * TOUGH_HP
		if NORMALS.has(id):
			m.atk = float(m.atk) * NORMAL_ATK
	return m


## Camp i of n spread over CAMP_MIN..CAMP_MAX (each camp spans 6-8 levels).
static func camp_levels(i: int, n: int) -> Array:
	var span := CAMP_MAX - CAMP_MIN - 8
	var low := CAMP_MIN + int(round(float(span) * float(i) / float(maxi(n - 1, 1))))
	return [low, mini(low + (8 if i == n - 1 else 6), CAMP_MAX)]


## The zone dictionary (ZoneData).
static func zone() -> Dictionary:
	# Five farm camps of one kind each (the fourth and fifth with an elite now and then)
	# and the dragon graveyard, where both elites roost among the jade drakes.
	var positions: Array = SkyIsleArt.layout().camp_positions
	var camps: Array = []
	for i in 6:
		var ids: Array = [NORMALS[i]] if i < 5 else [&"jade_drake", &"jade_drake", &"shrine_dragon", &"emerald_elder"]
		if i == 3: ids = [NORMALS[i], NORMALS[i], NORMALS[i], &"shrine_dragon"]
		elif i == 4: ids = [NORMALS[i], NORMALS[i], NORMALS[i], &"emerald_elder"]
		camps.append({"name": CAMP_NAMES[i], "monsters": ids, "levels": camp_levels(i, 6), "pos": positions[i], "radius": 9.0, "count": 9})
	# "divine_region": ★-field rules as in the sanctuary and the abyss (world boss on
	# weekends, perfect gems); the abyss's jewel and set core rolls; its own loot table.
	return {"name": TITLE, "scene": "field", "theme": ID,
		"level": [100, 100], "music": ID, "ambience": &"wind", "weather": &"windstream",
		"sky": SkyIsleArt.SKY, "fog": SkyIsleArt.HAZE, "ambient": Color("ffe9cf"), "sun": Color("ffd9a0"), "ground": SkyIsleArt.GRASS,
		"sky_palette": [Color("2f74d0"), Color("8fc8f0"), Color("ffe8c6")], "sun_size": 1.6, "moon": false,
		"camps": camps,
		"boss": {"monster": BOSS, "level": BOSS_LEVEL, "respawn": BOSS_RESPAWN, "star": ENTRY_STAR},
		"star": ENTRY_STAR, "gear_star": GEAR_STAR, "divine_region": true,
		"endgame_loot": false, "sky_isle_loot": true, "rare_dragon": true,
		"jewel_drop": EndgameFields.JEWEL_DROP.duplicate(), "set_core_drop": EndgameFields.SET_CORE_DROP,
		"prev": DrownedAbyssData.ID, "next": &""}


## One Thai line for the warp list, the entrance sign and help: what the isle drops
## (docs/SKY_ISLE_PLAN.md; the rates are SkyIsleLoot's).
static func drop_text() -> String:
	return "อาวุธเทพมังกร · ปีก 300 ดาว · ชิ้นส่วนคอสตูม · ไข่สัตว์ขี่ · หีบสมบัติ"
