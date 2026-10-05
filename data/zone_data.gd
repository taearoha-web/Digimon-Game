class_name ZoneData
extends RefCounted
## Hunting fields and the town: levels, monsters, spawn spots and the boss.

const ZONES := {
	&"town": {"name": "หมู่บ้านมิสต์วูด", "scene": "town", "safe": true, "music": &"title"},
	&"meadow": {
		"name": "ทุ่งหญ้ามิสต์วูด", "scene": "field", "level": [1, 6], "music": &"field", "theme": &"meadow",
		"tree_density": 1.0,
		# Each camp is a marked patch of grass where one kind of monster lives.
		"camps": [
			{"name": "ลานสไลม์", "monsters": [&"pink_slime", &"green_slime"], "levels": [1, 3], "pos": Vector2(-26, -15), "radius": 10.0, "count": 5},
			{"name": "คอกไก่ป่า", "monsters": [&"wild_chicken"], "levels": [2, 5], "pos": Vector2(-20, 17), "radius": 9.0, "count": 4},
			{"name": "บึงกบเหลือง", "monsters": [&"yellow_frog"], "levels": [3, 5], "pos": Vector2(2, -19), "radius": 9.0, "count": 4},
			{"name": "สวนเห็ดน้อย", "monsters": [&"mush_baby"], "levels": [3, 6], "pos": Vector2(6, 19), "radius": 9.0, "count": 4},
			{"name": "ทุ่งกระบองเพชร", "monsters": [&"cactus_hat"], "levels": [4, 6], "pos": Vector2(28, -16), "radius": 10.0, "count": 4},
		],
		"boss": {"monster": &"mush_king", "level": 8, "respawn": 120.0},
		"sky": Color("8ed0ff"), "ground": Color("5fbf57"),
	},
	&"dark_forest": {
		"name": "ป่าเงาม่วง", "scene": "field", "level": [7, 14], "music": &"forest", "theme": &"digital",
		"tree_density": 3.0,
		"camps": [
			{"name": "ค่ายออร์คป่า", "monsters": [&"forest_orc"], "levels": [7, 10], "pos": Vector2(-26, -15), "radius": 10.0, "count": 5},
			{"name": "รังผึ้งพิษ", "monsters": [&"poison_bee"], "levels": [7, 11], "pos": Vector2(-20, 17), "radius": 9.0, "count": 4},
			{"name": "ลานกะโหลก", "monsters": [&"skull_orc"], "levels": [9, 12], "pos": Vector2(2, -19), "radius": 9.0, "count": 4},
			{"name": "ซอกเงานินจา", "monsters": [&"shadow_ninja"], "levels": [10, 13], "pos": Vector2(6, 19), "radius": 9.0, "count": 4},
			{"name": "ทุ่งวิญญาณ", "monsters": [&"ghost"], "levels": [11, 14], "pos": Vector2(28, -16), "radius": 10.0, "count": 4},
		],
		"boss": {"monster": &"fire_dragon", "level": 16, "respawn": 180.0},
		"sky": Color("2a2060"), "ground": Color("3a7a62"),
	},
}


static func get_zone(id: StringName) -> Dictionary:
	return ZONES.get(id, ZONES[&"meadow"])
