class_name ZoneData
extends RefCounted
## Hunting fields and the town: levels, monsters, spawn spots and the boss.

const ZONES := {
	&"town": {"name": "หมู่บ้านมิสต์วูด", "scene": "town", "safe": true, "music": &"title"},
	&"meadow": {
		"name": "ทุ่งหญ้ามิสต์วูด", "scene": "field", "level": [1, 6], "music": &"field", "theme": &"meadow", "ambience": &"water",
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
		"sky": Color("8ed0ff"), "ground": Color("5fbf57"), "prev": &"town", "next": &"dark_forest",
	},
	&"dark_forest": {
		"name": "ป่าเงาม่วง", "scene": "field", "level": [7, 14], "music": &"forest", "theme": &"digital", "ambience": &"hum",
		"tree_density": 3.0,
		"camps": [
			{"name": "ค่ายออร์คป่า", "monsters": [&"forest_orc"], "levels": [7, 10], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังผึ้งพิษ", "monsters": [&"poison_bee"], "levels": [7, 11], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ลานกะโหลก", "monsters": [&"skull_orc"], "levels": [9, 12], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ซอกเงานินจา", "monsters": [&"shadow_ninja"], "levels": [10, 13], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งวิญญาณ", "monsters": [&"ghost"], "levels": [11, 14], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"fire_dragon", "level": 16, "respawn": 180.0},
		"sky": Color("2a2060"), "ground": Color("3a7a62"),
		"fog": Color("4a3a88"), "ambient": Color(0.7, 0.75, 1.0), "sun": Color(0.85, 0.8, 1.0), "path_color": Color("7a6aa8"), "seed": 9,
		"prev": &"meadow", "next": &"desert",
	},
	&"desert": {
		"name": "ทะเลทรายตะวันเดือด", "scene": "field", "level": [15, 22], "music": &"field", "theme": &"desert", "ambience": &"wind",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานนกทราย", "monsters": [&"sand_birb"], "levels": [15, 18], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังหมาป่าทราย", "monsters": [&"sand_wolf"], "levels": [15, 19], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ดงกระบองเพชร", "monsters": [&"giant_cactus"], "levels": [17, 20], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หุบไดโนทราย", "monsters": [&"sand_dino"], "levels": [18, 21], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ค่ายพ่อมดทราย", "monsters": [&"desert_wizard"], "levels": [19, 22], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"sand_dragon", "level": 24, "respawn": 180.0},
		"sky": Color("5ab0f0"), "ground": Color("c8a468"), "fog": Color("ffe2b0"), "ambient": Color(1.0, 0.95, 0.85), "sun": Color(1.0, 0.93, 0.75),
		"path_color": Color("b08a50"), "seed": 4, "prev": &"dark_forest", "next": &"snow",
	},
	&"snow": {
		"name": "ภูเขาน้ำแข็งนิรันดร์", "scene": "field", "level": [23, 30], "music": &"forest", "theme": &"snow", "weather": &"snow", "ambience": &"wind",
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
	},
	&"volcano": {
		"name": "ปล่องภูเขาไฟคลั่ง", "scene": "field", "level": [31, 40], "music": &"forest", "theme": &"volcano", "weather": &"embers", "ambience": &"fire",
		"tree_density": 0.5,
		"camps": [
			{"name": "เหมืองผึ้งไฟ", "monsters": [&"flame_bee"], "levels": [31, 34], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ลานผีถ่าน", "monsters": [&"ember_ghost"], "levels": [32, 35], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ค่ายออร์คลาวา", "monsters": [&"fire_orc"], "levels": [33, 37], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หุบไดโนลาวา", "monsters": [&"lava_dino"], "levels": [35, 38], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอพ่อมดแมกมา", "monsters": [&"magma_wizard"], "levels": [37, 40], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"magma_dragon", "level": 42, "respawn": 240.0},
		"sky": Color("3a1a14"), "ground": Color("4a3838"), "fog": Color("8a3a22"), "ambient": Color(1.0, 0.62, 0.48), "sun": Color(1.0, 0.58, 0.38),
		"path_color": Color("7a4a3a"), "seed": 8, "prev": &"snow", "next": &"graveyard",
	},
	&"graveyard": {
		"name": "สุสานจันทร์เลือด", "scene": "field", "level": [41, 52], "music": &"forest", "theme": &"graveyard", "ambience": &"hum",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานอัศวินกระดูก", "monsters": [&"bone_knight"], "levels": [41, 45], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ถ้ำค้างคาวเลือด", "monsters": [&"blood_bat"], "levels": [42, 46], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ป่าช้าวิญญาณ", "monsters": [&"grave_ghost"], "levels": [44, 48], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งหมาป่าผีดิบ", "monsters": [&"ghoul_hound"], "levels": [46, 50], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอแม่มดสุสาน", "monsters": [&"grave_witch"], "levels": [48, 52], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"bone_lord", "level": 54, "respawn": 260.0},
		"sky": Color("1a1630"), "ground": Color("3a3a4a"), "fog": Color("3a2a50"), "ambient": Color(0.6, 0.62, 0.9), "sun": Color(0.7, 0.7, 1.0),
		"path_color": Color("5a5a74"), "seed": 21, "prev": &"volcano", "next": &"swamp",
	},
	&"swamp": {
		"name": "หนองน้ำพิษมรณะ", "scene": "field", "level": [53, 64], "music": &"forest", "theme": &"swamp", "ambience": &"water",
		"tree_density": 1.4,
		"camps": [
			{"name": "บึงกบพิษ", "monsters": [&"toxic_frog"], "levels": [53, 57], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "รังผึ้งโรคระบาด", "monsters": [&"plague_bee"], "levels": [54, 58], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ป่าเห็ดพิษ", "monsters": [&"venom_mush"], "levels": [56, 60], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "หนองไดโน", "monsters": [&"swamp_dino"], "levels": [58, 62], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "ทะเลสาบปลาโคลน", "monsters": [&"mud_fish"], "levels": [60, 64], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"toad_king", "level": 66, "respawn": 280.0},
		"sky": Color("2a3a20"), "ground": Color("3a5030"), "fog": Color("4a6a38"), "ambient": Color(0.7, 0.85, 0.6), "sun": Color(0.85, 1.0, 0.7),
		"path_color": Color("6a7a48"), "seed": 22, "prev": &"graveyard", "next": &"storm",
	},
	&"storm": {
		"name": "ภูผาสายฟ้าคำราม", "scene": "field", "level": [65, 76], "music": &"field", "theme": &"storm", "ambience": &"wind",
		"tree_density": 0.5,
		"camps": [
			{"name": "ลานกระต่ายไฟฟ้า", "monsters": [&"volt_bunny"], "levels": [65, 69], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "ผาฝูงนกสายฟ้า", "monsters": [&"volt_pigeon"], "levels": [66, 70], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "หุบนินจาพายุ", "monsters": [&"storm_ninja"], "levels": [68, 72], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "สุสานยักษ์หิน", "monsters": [&"thunder_golem"], "levels": [70, 74], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอพ่อมดพายุ", "monsters": [&"storm_wizard"], "levels": [72, 76], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"storm_dragon", "level": 78, "respawn": 300.0},
		"sky": Color("34425a"), "ground": Color("586470"), "fog": Color("7088a0"), "ambient": Color(0.75, 0.82, 1.0), "sun": Color(0.9, 0.95, 1.0),
		"path_color": Color("7a8494"), "seed": 23, "prev": &"swamp", "next": &"sky",
	},
	&"sky": {
		"name": "นครเมฆาสวรรค์ล่ม", "scene": "field", "level": [77, 88], "music": &"title", "theme": &"sky", "ambience": &"wind",
		"tree_density": 0.6,
		"camps": [
			{"name": "ลานนกทองคำ", "monsters": [&"gold_birb"], "levels": [77, 81], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "สวนทูตสวรรค์ตกต่ำ", "monsters": [&"fallen_angel"], "levels": [78, 82], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "หุบไดโนสุริยะ", "monsters": [&"sun_dino"], "levels": [80, 84], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งหมาป่าเมฆา", "monsters": [&"sky_hound"], "levels": [82, 86], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "วิหารนักบวชมืด", "monsters": [&"sky_priest"], "levels": [84, 88], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"gold_dragon", "level": 90, "respawn": 320.0},
		"sky": Color("8ac0f0"), "ground": Color("e8e0b8"), "fog": Color("f0e8c0"), "ambient": Color(1.0, 0.95, 0.85), "sun": Color(1.0, 0.96, 0.8),
		"path_color": Color("c8b878"), "seed": 24, "prev": &"storm", "next": &"abyss",
	},
	&"abyss": {
		"name": "ขุมนรกอเวจี", "scene": "field", "level": [89, 100], "music": &"forest", "theme": &"abyss", "ambience": &"fire", "weather": &"embers",
		"tree_density": 0.5,
		"camps": [
			{"name": "ค่ายออร์คปีศาจ", "monsters": [&"hell_orc"], "levels": [89, 93], "pos": Vector2(-26, -15), "radius": 10.0, "count": 10},
			{"name": "หุบผีนรก", "monsters": [&"abyss_ghost"], "levels": [90, 94], "pos": Vector2(-20, 17), "radius": 9.0, "count": 10},
			{"name": "ซอกนินจาปีศาจ", "monsters": [&"demon_ninja"], "levels": [92, 96], "pos": Vector2(2, -19), "radius": 9.0, "count": 10},
			{"name": "ทุ่งไดโนนรก", "monsters": [&"hell_dino"], "levels": [94, 98], "pos": Vector2(6, 19), "radius": 9.0, "count": 10},
			{"name": "หอพ่อมดนรก", "monsters": [&"hell_wizard"], "levels": [96, 100], "pos": Vector2(28, -16), "radius": 10.0, "count": 10},
		],
		"boss": {"monster": &"abyss_dragon", "level": 100, "respawn": 360.0},
		"sky": Color("1a0810"), "ground": Color("2a1a22"), "fog": Color("6a1a2a"), "ambient": Color(0.9, 0.5, 0.55), "sun": Color(1.0, 0.45, 0.5),
		"path_color": Color("5a2030"), "seed": 25, "prev": &"sky", "next": &"",
	},
	&"arena": {
		"name": "สนามประลองกล้าหาญ", "scene": "field", "level": [1, 100], "music": &"field", "theme": &"meadow", "arena": true,
		"tree_density": 0.15, "camps": [],
		"sky": Color("9ad0ff"), "ground": Color("b7a874"), "path_color": Color("8a7a52"), "seed": 12, "prev": &"town", "next": &"",
	},
}


static func get_zone(id: StringName) -> Dictionary:
	return ZONES.get(id, ZONES[&"meadow"])
