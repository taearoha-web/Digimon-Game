class_name ZoneData
extends RefCounted
## Hunting fields and the town: levels, monsters, spawn spots and the boss.

const BASE_ZONES := {
	&"town": {"name": "หมู่บ้านมิสต์วูด", "scene": "town", "safe": true, "music": &"town"},
	&"meadow": {
		"name": "ทุ่งหญ้ามิสต์วูด", "scene": "field", "level": [1, 6], "music": &"meadow", "theme": &"meadow", "ambience": &"water",
		"tree_density": 1.0,
		# Each camp is a marked patch of grass where one kind of monster lives.
		"camps": [
			{"name": "ลานสไลม์", "monsters": [&"pink_slime", &"green_slime"], "levels": [1, 3], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "คอกไก่ป่า", "monsters": [&"wild_chicken"], "levels": [2, 5], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "บึงกบเหลือง", "monsters": [&"yellow_frog"], "levels": [3, 5], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "สวนเห็ดน้อย", "monsters": [&"mush_baby"], "levels": [3, 6], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งกระบองเพชร", "monsters": [&"cactus_hat"], "levels": [4, 6], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"mush_king", "level": 8, "respawn": 120.0},
		"sky": Color("9fc5df"), "ground": Color("91aa77"), "prev": &"town", "next": &"dark_forest",
		"sky_palette": [Color("5f9bd9"), Color("a9cfe9"), Color("eef0d8")], "sun_size": 1.0, "weather": &"petals",
	},
	&"dark_forest": {
		"name": "ป่าเงาม่วง", "scene": "field", "level": [7, 14], "music": &"dark_forest", "theme": &"digital", "ambience": &"hum",
		"tree_density": 3.0,
		"camps": [
			{"name": "ค่ายออร์คป่า", "monsters": [&"forest_orc"], "levels": [7, 10], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังผึ้งพิษ", "monsters": [&"poison_bee"], "levels": [7, 11], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ลานกะโหลก", "monsters": [&"skull_orc"], "levels": [9, 12], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ซอกเงานินจา", "monsters": [&"shadow_ninja"], "levels": [10, 13], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งวิญญาณ", "monsters": [&"ghost"], "levels": [11, 14], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"fire_dragon", "level": 16, "respawn": 180.0},
		"sky": Color("4d456d"), "ground": Color("617c71"),
		"fog": Color("7e7398"), "ambient": Color(0.7, 0.75, 1.0), "sun": Color(0.85, 0.8, 1.0), "path_color": Color("958aab"), "seed": 9,
		"prev": &"meadow", "next": &"desert",
		"sky_palette": [Color("2d2550"), Color("5c4f85"), Color("9a86b0")], "sun_size": 0.5, "moon": true, "weather": &"fireflies",
	},
	&"desert": {
		"name": "ทะเลทรายตะวันเดือด", "scene": "field", "level": [15, 22], "music": &"desert", "theme": &"desert", "ambience": &"wind",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานนกทราย", "monsters": [&"sand_birb"], "levels": [15, 18], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังหมาป่าทราย", "monsters": [&"sand_wolf"], "levels": [15, 19], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ดงกระบองเพชร", "monsters": [&"giant_cactus"], "levels": [17, 20], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หุบไดโนทราย", "monsters": [&"sand_dino"], "levels": [18, 21], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ค่ายพ่อมดทราย", "monsters": [&"desert_wizard"], "levels": [19, 22], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"sand_dragon", "level": 24, "respawn": 180.0},
		"sky": Color("b7cad9"), "ground": Color("d9ba8c"), "fog": Color("efdcc1"), "ambient": Color(1.0, 0.95, 0.85), "sun": Color(1.0, 0.93, 0.75),
		"path_color": Color("bea17d"), "seed": 4, "prev": &"dark_forest", "next": &"snow",
		"sky_palette": [Color("5d95c8"), Color("c0ccd4"), Color("f4e2c0")], "sun_size": 1.6, "weather": &"sand",
	},
	&"snow": {
		"name": "ภูเขาน้ำแข็งนิรันดร์", "scene": "field", "level": [23, 30], "music": &"snow", "theme": &"snow", "weather": &"snow", "ambience": &"wind",
		"tree_density": 1.4,
		"camps": [
			{"name": "ลานกระต่ายหิมะ", "monsters": [&"snow_bunny"], "levels": [23, 26], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังผึ้งน้ำแข็ง", "monsters": [&"ice_bee", &"snow_pigeon"], "levels": [23, 27], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "บึงปลาลอยฟ้า", "monsters": [&"ice_fish"], "levels": [25, 28], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ถ้ำเยติ", "monsters": [&"yeti"], "levels": [26, 30], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ลานน้ำแข็งนิรันดร์", "monsters": [&"yeti", &"ice_bee"], "levels": [28, 30], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"yeti_king", "level": 32, "respawn": 200.0},
		"sky": Color("9cc4f0"), "ground": Color("e4eef8"), "fog": Color("e6f2ff"), "ambient": Color(0.88, 0.94, 1.0), "sun": Color(0.96, 0.98, 1.0),
		"path_color": Color("a8bcd4"), "seed": 6, "prev": &"desert", "next": &"volcano",
		"sky_palette": [Color("6aa4e8"), Color("b9d4f2"), Color("eef4fc")], "sun_size": 0.9,
	},
	&"volcano": {
		"name": "ปล่องภูเขาไฟคลั่ง", "scene": "field", "level": [31, 40], "music": &"volcano", "theme": &"volcano", "weather": &"embers", "ambience": &"fire",
		"tree_density": 0.5,
		"camps": [
			{"name": "ถ้ำค้างคาวเพลิง", "monsters": [&"flame_bee"], "levels": [31, 34], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ลานวิญญาณถ่าน", "monsters": [&"ember_ghost"], "levels": [32, 35], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ค่ายออร์คลาวา", "monsters": [&"fire_orc"], "levels": [33, 37], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หุบมังกรน้อยลาวา", "monsters": [&"lava_dino"], "levels": [35, 38], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอจอมเวทแมกมา", "monsters": [&"magma_wizard"], "levels": [37, 40], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"magma_dragon", "level": 42, "respawn": 240.0},
		"sky": Color("614646"), "ground": Color("6e595c"), "fog": Color("a46e60"), "ambient": Color(1.0, 0.62, 0.48), "sun": Color(1.0, 0.58, 0.38),
		"path_color": Color("947568"), "seed": 8, "prev": &"snow", "next": &"graveyard",
		"sky_palette": [Color("3a2630"), Color("6c3f3c"), Color("b4634a")], "sun_size": 1.3,
	},
	&"graveyard": {
		"name": "สุสานจันทร์เลือด", "scene": "field", "level": [41, 52], "music": &"graveyard", "theme": &"graveyard", "ambience": &"hum",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานอัศวินกระดูก", "monsters": [&"bone_knight"], "levels": [41, 45], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ถ้ำค้างคาวเลือด", "monsters": [&"blood_bat"], "levels": [42, 46], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ป่าช้าวิญญาณ", "monsters": [&"grave_ghost"], "levels": [44, 48], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งแมวผีดิบ", "monsters": [&"ghoul_hound"], "levels": [46, 50], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอแม่มดสุสาน", "monsters": [&"grave_witch"], "levels": [48, 52], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"bone_lord", "level": 54, "respawn": 260.0},
		"sky": Color("3b3b55"), "ground": Color("626474"), "fog": Color("69657f"), "ambient": Color(0.6, 0.62, 0.9), "sun": Color(0.7, 0.7, 1.0),
		"path_color": Color("92909d"), "seed": 21, "prev": &"volcano", "next": &"swamp",
		"sky_palette": [Color("181a30"), Color("34365a"), Color("6d6a86")], "sun_size": 0.0, "moon": true, "weather": &"wisps",
	},
	&"swamp": {
		"name": "หนองน้ำพิษมรณะ", "scene": "field", "level": [53, 64], "music": &"swamp", "theme": &"swamp", "ambience": &"water",
		"tree_density": 1.4,
		"camps": [
			{"name": "บึงกบพิษ", "monsters": [&"toxic_frog"], "levels": [53, 57], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังแมลงโรคระบาด", "monsters": [&"plague_bee"], "levels": [54, 58], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ป่าเห็ดพิษ", "monsters": [&"venom_mush"], "levels": [56, 60], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หนองอสุรกาย", "monsters": [&"swamp_dino"], "levels": [58, 62], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ทะเลสาบปลาโคลน", "monsters": [&"mud_fish"], "levels": [60, 64], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"toad_king", "level": 66, "respawn": 280.0},
		"sky": Color("435a59"), "ground": Color("667e69"), "fog": Color("82988a"), "ambient": Color(0.7, 0.85, 0.6), "sun": Color(0.85, 1.0, 0.7),
		"path_color": Color("9caa83"), "seed": 22, "prev": &"graveyard", "next": &"storm",
		"sky_palette": [Color("3b5a62"), Color("6f8d84"), Color("aebfa0")], "sun_size": 0.7, "weather": &"fireflies",
	},
	&"storm": {
		"name": "ภูผาสายฟ้าคำราม", "scene": "field", "level": [65, 76], "music": &"storm", "theme": &"storm", "ambience": &"wind",
		"tree_density": 0.5,
		"camps": [
			{"name": "ลานลิงสายฟ้า", "monsters": [&"volt_bunny"], "levels": [65, 69], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ผาฝูงนกสายฟ้า", "monsters": [&"volt_pigeon"], "levels": [66, 70], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "หุบนินจาพายุ", "monsters": [&"storm_ninja"], "levels": [68, 72], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "สุสานยักษ์หิน", "monsters": [&"thunder_golem"], "levels": [70, 74], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอจอมเวทพายุ", "monsters": [&"storm_wizard"], "levels": [72, 76], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"storm_dragon", "level": 78, "respawn": 300.0},
		"sky": Color("34425a"), "ground": Color("586470"), "fog": Color("7088a0"), "ambient": Color(0.75, 0.82, 1.0), "sun": Color(0.9, 0.95, 1.0),
		"path_color": Color("7a8494"), "seed": 23, "prev": &"swamp", "next": &"sky",
		"sky_palette": [Color("2a3650"), Color("4e617d"), Color("8aa0b4")], "sun_size": 0.0, "weather": &"rain",
	},
	&"sky": {
		"name": "นครเมฆาสวรรค์ล่ม", "scene": "field", "level": [77, 88], "music": &"sky", "theme": &"sky", "ambience": &"wind",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานนกทองคำ", "monsters": [&"gold_birb"], "levels": [77, 81], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "สวนทูตสวรรค์ตกต่ำ", "monsters": [&"fallen_angel"], "levels": [78, 82], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "หุบมังกรน้อยสุริยะ", "monsters": [&"sun_dino"], "levels": [80, 84], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งกวางเมฆา", "monsters": [&"sky_hound"], "levels": [82, 86], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "วิหารนักบวชมืด", "monsters": [&"sky_priest"], "levels": [84, 88], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"gold_dragon", "level": 90, "respawn": 320.0},
		"sky": Color("8ac0f0"), "ground": Color("e8e0b8"), "fog": Color("f0e8c0"), "ambient": Color(1.0, 0.95, 0.85), "sun": Color(1.0, 0.96, 0.8),
		"path_color": Color("c8b878"), "seed": 24, "prev": &"storm", "next": &"abyss",
		"sky_palette": [Color("4f98e8"), Color("9fcbf2"), Color("fdf1cf")], "sun_size": 1.4, "weather": &"motes",
	},
	&"abyss": {
		"name": "ขุมนรกอเวจี", "scene": "field", "level": [89, 100], "music": &"abyss", "theme": &"abyss", "ambience": &"fire", "weather": &"brimstone",
		"tree_density": 0.5,
		"camps": [
			{"name": "ค่ายออร์คปีศาจ", "monsters": [&"hell_orc"], "levels": [89, 93], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "หุบผีนรก", "monsters": [&"abyss_ghost"], "levels": [90, 94], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ค่ายนักรบเผ่าปีศาจ", "monsters": [&"demon_ninja"], "levels": [92, 96], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งสัตว์ประหลาดนรก", "monsters": [&"hell_dino"], "levels": [94, 98], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอปีศาจหนวดนรก", "monsters": [&"hell_wizard"], "levels": [96, 100], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"abyss_dragon", "level": 100, "respawn": 60.0},
		"sky": Color("43313f"), "ground": Color("5e4658"), "fog": Color("84556c"), "ambient": Color(0.9, 0.5, 0.55), "sun": Color(1.0, 0.45, 0.5),
		"path_color": Color("916e82"), "seed": 25, "prev": &"sky", "next": &"void",
		"sky_palette": [Color("2a1225"), Color("5a2338"), Color("9a4a5c")], "sun_size": 0.0, "moon": true,
	},
	&"void": {
		"name": "ห้วงจักรวาลวิบัติ", "scene": "field", "level": [100, 100], "music": &"void", "theme": &"void", "weather": &"runes", "ambience": &"hum",
		"tree_density": 0.4,
		"camps": [
			{"name": "ลานยักษ์หินว่างเปล่า", "monsters": [&"void_golem"], "levels": [100, 100], "pos": Vector2(-26, -15), "radius": 10.0, "count": 8},
			{"name": "สุสานดาวดับ", "monsters": [&"star_wraith"], "levels": [100, 100], "pos": Vector2(-20, 17), "radius": 9.0, "count": 8},
			{"name": "รอยแยกมิติ", "monsters": [&"rift_stalker"], "levels": [100, 100], "pos": Vector2(2, -19), "radius": 9.0, "count": 8},
			{"name": "รังหนวดอนันต์", "monsters": [&"tentacle_horror"], "levels": [100, 100], "pos": Vector2(6, 19), "radius": 9.0, "count": 8},
			{"name": "เตาหลอมซูเปอร์โนวา", "monsters": [&"nova_drake", &"void_golem"], "levels": [100, 100], "pos": Vector2(28, -16), "radius": 10.0, "count": 8},
		],
		"boss": {"monster": &"void_emperor", "level": 100, "respawn": 90.0},
		# Rich farming: more and better drops than any other field.
		"loot": {"stars": true, "gear": 0.30, "rarity_boost": 0.07, "gem": 0.2, "potion": 0.5, "wing": 0.006, "shard": 0.03, "boss_shards": 10, "boss_wing": 0.6, "boss_items": 4},
		"sky": Color("292942"), "ground": Color("4c4669"), "fog": Color("716795"), "ambient": Color(0.65, 0.5, 1.0), "sun": Color(0.85, 0.6, 1.0),
		"path_color": Color("877ca7"), "seed": 31, "prev": &"abyss", "next": &"",
		"sky_palette": [Color("120f2a"), Color("2f2358"), Color("6b5aa0")], "sun_size": 0.0, "moon": true,
	},
	&"tower": {
		"name": "หอคอยห้วงวิบัติ", "scene": "field", "level": [100, 100], "music": &"tower", "theme": &"void", "weather": &"embers", "ambience": &"hum",
		"tree_density": 0.2, "camps": [], "tower": true,
		"loot": {"stars": true, "gear": 0.22, "rarity_boost": 0.06, "gem": 0.15, "potion": 0.35, "wing": 0.004, "boss_wing": 0.5, "boss_items": 4},
		"sky": Color("292942"), "ground": Color("4c4669"), "fog": Color("716795"), "ambient": Color(0.65, 0.5, 1.0), "sun": Color(0.85, 0.6, 1.0),
		"path_color": Color("877ca7"), "seed": 33, "prev": &"town", "next": &"",
		"sky_palette": [Color("120f2a"), Color("2f2358"), Color("6b5aa0")], "sun_size": 0.0, "moon": true,
	},
	&"pvp": {
		"name": "โคลีเซียมจัดอันดับ", "scene": "field", "level": [10, 100], "music": &"pvp", "pvp": true,
		"tree_density": 0.0, "camps": [], "sky": Color("4d63c8"), "ground": Color("d6c08a"), "prev": &"town", "next": &"",
	},
	&"guildwar": {
		"name": "สงครามกิลด์ · โคลีเซียม", "scene": "field", "level": [100, 100], "music": &"guildwar", "pvp": true, "guildwar": true,
		"tree_density": 0.0, "camps": [], "sky": Color("4d63c8"), "ground": Color("d6c08a"), "prev": &"town", "next": &"",
	},
	&"arena": {
		"name": "สนามประลองกล้าหาญ", "scene": "field", "level": [1, 100], "music": &"arena", "theme": &"meadow", "arena": true,
		"tree_density": 0.15, "camps": [],
		"sky": Color("9ad0ff"), "ground": Color("b7a874"), "path_color": Color("8a7a52"), "seed": 12, "prev": &"town", "next": &"",
	},
}


## The hunting fields grew (Zone.HUNT_RADIUS): four more camps each in the outer ring, the
## field's own monsters two kinds at a time, a few levels wide inside the field's band. The
## field bosses stay as they were.
const OUTER_SPOTS: Array[Vector2] = [Vector2(-48, -36), Vector2(-44, 38), Vector2(14, -48), Vector2(52, -34)]
const OUTER_CAMPS := {
	&"meadow": [["ทุ่งไก่ป่าริมลำธาร", [&"pink_slime", &"wild_chicken"], [1, 4]], ["หนองกบหลังเนิน", [&"wild_chicken", &"yellow_frog"], [2, 5]],
		["ป่าเห็ดชายทุ่ง", [&"yellow_frog", &"mush_baby"], [3, 6]], ["เนินกระบองเพชรใหญ่", [&"mush_baby", &"cactus_hat"], [4, 6]]],
	&"dark_forest": [["ค่ายออร์คชายป่า", [&"forest_orc", &"poison_bee"], [7, 10]], ["โพรงผึ้งเงา", [&"poison_bee", &"skull_orc"], [8, 11]],
		["ลานฝึกนินจาร้าง", [&"skull_orc", &"shadow_ninja"], [10, 13]], ["สุสานวิญญาณลึก", [&"shadow_ninja", &"ghost"], [11, 14]]],
	&"desert": [["โอเอซิสนกทราย", [&"sand_birb", &"sand_wolf"], [15, 18]], ["เนินทรายหมาป่า", [&"sand_wolf", &"giant_cactus"], [16, 19]],
		["ซากเมืองไดโนทราย", [&"giant_cactus", &"sand_dino"], [18, 21]], ["หอพ่อมดทรายเก่า", [&"sand_dino", &"desert_wizard"], [19, 22]]],
	&"snow": [["ลานหิมะกระต่าย", [&"snow_bunny", &"snow_pigeon"], [23, 26]], ["หน้าผานกพิราบหิมะ", [&"snow_pigeon", &"ice_fish"], [24, 27]],
		["ทะเลสาบน้ำแข็ง", [&"ice_fish", &"yeti"], [26, 29]], ["ยอดเขาเยติ", [&"yeti", &"ice_bee"], [27, 30]]],
	&"volcano": [["ลานผึ้งไฟ", [&"flame_bee", &"ember_ghost"], [31, 34]], ["หุบวิญญาณเถ้าถ่าน", [&"ember_ghost", &"fire_orc"], [33, 36]],
		["บ่อลาวาไดโน", [&"fire_orc", &"lava_dino"], [35, 38]], ["ปล่องจอมเวทแมกมา", [&"lava_dino", &"magma_wizard"], [37, 40]]],
	&"graveyard": [["ป้อมอัศวินกระดูก", [&"bone_knight", &"blood_bat"], [41, 45]], ["หอระฆังค้างคาว", [&"blood_bat", &"grave_ghost"], [43, 47]],
		["ลานผีเร่ร่อน", [&"grave_ghost", &"ghoul_hound"], [46, 50]], ["โบสถ์แม่มดร้าง", [&"ghoul_hound", &"grave_witch"], [48, 52]]],
	&"swamp": [["ลำธารกบพิษ", [&"toxic_frog", &"plague_bee"], [53, 57]], ["รังแมลงใต้ราก", [&"plague_bee", &"venom_mush"], [55, 59]],
		["บึงเห็ดยักษ์", [&"venom_mush", &"swamp_dino"], [57, 61]], ["โคลนลึกอสุรกาย", [&"swamp_dino", &"mud_fish"], [60, 64]]],
	&"storm": [["ทุ่งหญ้าฟ้าผ่า", [&"volt_bunny", &"volt_pigeon"], [65, 69]], ["รังนกพายุ", [&"volt_pigeon", &"storm_ninja"], [67, 71]],
		["เหมืองยักษ์หิน", [&"storm_ninja", &"thunder_golem"], [69, 73]], ["แท่นบูชาสายฟ้า", [&"thunder_golem", &"storm_wizard"], [72, 76]]],
	&"sky": [["ระเบียงนกทอง", [&"gold_birb", &"fallen_angel"], [77, 81]], ["สวนลอยฟ้าร้าง", [&"fallen_angel", &"sun_dino"], [79, 83]],
		["ลานกวางสุริยะ", [&"sun_dino", &"sky_hound"], [81, 85]], ["หอระฆังเมฆา", [&"sky_hound", &"sky_priest"], [84, 88]]],
	&"abyss": [["ประตูนรกชั้นนอก", [&"hell_orc", &"abyss_ghost"], [89, 93]], ["ธารวิญญาณเพลิง", [&"abyss_ghost", &"demon_ninja"], [91, 95]],
		["ลานประลองปีศาจ", [&"demon_ninja", &"hell_dino"], [93, 97]], ["หอคอยหนวดปีศาจ", [&"hell_dino", &"hell_wizard"], [96, 100]]],
	&"void": [["เศษดาวลอยคว้าง", [&"void_golem", &"star_wraith"], [100, 100]], ["ทางเดินมิติแตก", [&"star_wraith", &"rift_stalker"], [100, 100]],
		["บ่อหนวดอนันต์", [&"rift_stalker", &"tentacle_horror"], [100, 100]], ["แกนซูเปอร์โนวา", [&"tentacle_horror", &"nova_drake"], [100, 100]]],
}
## Monsters per outer camp (the Lv.100 void keeps its smaller camps).
const OUTER_COUNT := 8
const OUTER_COUNT_VOID := 6

static var ZONES: Dictionary = {}

static func ensure() -> void:
	if not ZONES.is_empty(): return
	ZONES = BASE_ZONES.duplicate(true)
	for id in OUTER_CAMPS:
		var extra: Array = OUTER_CAMPS[id]
		for k in extra.size():
			ZONES[id]["camps"].append({"name": extra[k][0], "monsters": extra[k][1], "levels": extra[k][2], "pos": OUTER_SPOTS[k],
				"radius": 9.0, "count": OUTER_COUNT_VOID if id == &"void" else OUTER_COUNT, "outer": true})
	ZONES[&"void"]["next"] = &"dawn_forest"
	ZONES.merge(StarProgression.zones())
	ZONES[&"eclipse_realm"]["next"] = DivineRegionData.ID
	ZONES[DivineRegionData.ID] = DivineRegionData.zone()

static func get_zone(id: StringName) -> Dictionary:
	ensure()
	return ZONES.get(id, ZONES[&"meadow"])

static func access_reason(id: StringName, level: int, stars: int) -> String:
	var z := get_zone(id)
	if level < int(z.get("level", [1,1])[0]): return "ต้องเลเวล %d" % int(z.level[0])
	if stars < int(z.get("star", 0)): return "ต้องเลเวล 100 ดาว %d" % int(z.star)
	return ""
