class_name ZoneData
extends RefCounted
## Hunting fields and the town: levels, monsters, spawn spots and the boss.

const ZONES := {
	&"town": {"name": "หมู่บ้านมิสต์วูด", "scene": "town", "safe": true, "music": &"title"},
	&"meadow": {
		"name": "ทุ่งหญ้ามิสต์วูด", "scene": "field", "level": [1, 6], "music": &"field", "theme": &"meadow",
		"spawns": [
			{"monster": &"pink_slime", "levels": [1, 3], "weight": 4},
			{"monster": &"green_slime", "levels": [2, 4], "weight": 3},
			{"monster": &"wild_chicken", "levels": [2, 5], "weight": 3},
			{"monster": &"yellow_frog", "levels": [3, 5], "weight": 2},
			{"monster": &"cactus_hat", "levels": [4, 6], "weight": 2},
			{"monster": &"mush_baby", "levels": [3, 6], "weight": 2},
		],
		"max_monsters": 16, "boss": {"monster": &"mush_king", "level": 8, "respawn": 120.0},
		"sky": Color("8ed0ff"), "ground": Color("5fbf57"),
	},
	&"dark_forest": {
		"name": "ป่าเงาม่วง", "scene": "field", "level": [7, 14], "music": &"forest", "theme": &"digital",
		"spawns": [
			{"monster": &"forest_orc", "levels": [7, 10], "weight": 4},
			{"monster": &"poison_bee", "levels": [7, 11], "weight": 3},
			{"monster": &"skull_orc", "levels": [9, 12], "weight": 3},
			{"monster": &"shadow_ninja", "levels": [10, 13], "weight": 2},
			{"monster": &"ghost", "levels": [11, 14], "weight": 2},
		],
		"max_monsters": 16, "boss": {"monster": &"fire_dragon", "level": 16, "respawn": 180.0},
		"sky": Color("2a2060"), "ground": Color("3a7a62"),
	},
}


static func get_zone(id: StringName) -> Dictionary:
	return ZONES.get(id, ZONES[&"meadow"])
