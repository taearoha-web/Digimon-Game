class_name QuestData
extends RefCounted
## Hunting quests given by the village elder. Progress is counted by
## Game.report_kill; rewards are paid out when the player reports back.

const QUESTS := {
	"slimes": {"name": "สไลม์ล้นทุ่ง", "desc": "สไลม์ชมพูแพร่พันธุ์เร็วเกินไป ช่วยกำจัดให้หน่อย", "target": "pink_slime", "count": 8, "level": 1,
		"exp": 90, "gold": 120, "items": [["hp_s", 5]], "zone": "meadow", "next": "chickens"},
	"chickens": {"name": "ไก่ป่าจอมอาละวาด", "desc": "ไก่ป่าไล่จิกชาวบ้านทุกวัน ปราบมันที", "target": "wild_chicken", "count": 10, "level": 2,
		"exp": 200, "gold": 220, "items": [["mp_s", 5]], "zone": "meadow", "next": "cactus"},
	"cactus": {"name": "กระบองเพชรยิงเข็ม", "desc": "กระบองเพชรหมวกใหญ่ยิงเข็มใส่คนเดินทาง จัดการมัน", "target": "cactus_hat", "count": 8, "level": 4,
		"exp": 420, "gold": 360, "items": [["hp_m", 4]], "zone": "meadow", "next": "mush_king"},
	"mush_king": {"name": "ราชาเห็ดยักษ์", "desc": "ราชาเห็ดผู้ดุร้ายอยู่ลึกสุดทุ่งหญ้า ปราบมันเพื่อความสงบของหมู่บ้าน", "target": "mush_king", "count": 1, "level": 6,
		"exp": 1400, "gold": 900, "items": [["hp_m", 5], ["mp_m", 5]], "gear": [8, 2], "zone": "meadow", "next": "orcs"},
	"orcs": {"name": "ออร์คเฝ้าป่า", "desc": "ป่าเงาม่วงเต็มไปด้วยออร์ค กำจัดพวกมันเพื่อเปิดทาง", "target": "forest_orc", "count": 12, "level": 7,
		"exp": 1500, "gold": 800, "items": [["hp_m", 5]], "zone": "dark_forest", "next": "ghosts"},
	"ghosts": {"name": "วิญญาณไม่สงบ", "desc": "ผีเงาม่วงหลอกหลอนยามค่ำ ส่งพวกมันกลับไปซะ", "target": "ghost", "count": 10, "level": 11,
		"exp": 3200, "gold": 1500, "items": [["hp_l", 3], ["mp_l", 3]], "zone": "dark_forest", "next": "dragon"},
	"dragon": {"name": "มังกรเพลิงผู้พิทักษ์", "desc": "มังกรเพลิงเฝ้าใจกลางป่า ปราบมันเพื่อพิสูจน์ความกล้า", "target": "fire_dragon", "count": 1, "level": 14,
		"exp": 9000, "gold": 5000, "items": [["hp_l", 5], ["mp_l", 5]], "gear": [16, 3], "zone": "dark_forest", "next": ""},
}

const ORDER: Array[String] = ["slimes", "chickens", "cactus", "mush_king", "orcs", "ghosts", "dragon"]


static func get_quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})


## The quest the elder should currently offer or ask about (first not yet rewarded).
static func current_quest() -> String:
	for id in ORDER:
		if Game.quest_status(id) != "done":
			return id
	return ""
