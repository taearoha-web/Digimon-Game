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
		"exp": 9000, "gold": 5000, "items": [["hp_l", 5], ["mp_l", 5]], "gear": [16, 3], "zone": "dark_forest", "next": "wolves"},
	"wolves": {"name": "หมาป่าทรายอาละวาด", "desc": "ฝูงหมาป่าทรายรังควานพ่อค้าคาราวาน ไปปราบพวกมันที่ทะเลทราย", "target": "sand_wolf", "count": 12, "level": 15,
		"exp": 6000, "gold": 3000, "items": [["hp_l", 4], ["mp_l", 4]], "zone": "desert", "next": "sand_dragon"},
	"sand_dragon": {"name": "มังกรทะเลทราย", "desc": "มังกรผู้เฝ้าโอเอซิสกลางทะเลทราย พิสูจน์ความกล้าของเจ้า", "target": "sand_dragon", "count": 1, "level": 21,
		"exp": 15000, "gold": 8000, "items": [["hp_l", 5], ["mp_l", 5]], "gear": [24, 3], "zone": "desert", "next": "yetis"},
	"yetis": {"name": "เยติบนยอดเขา", "desc": "เยติตัวใหญ่ลงมาขโมยเสบียงชาวบ้าน ขึ้นเขาไปจัดการ", "target": "yeti", "count": 12, "level": 24,
		"exp": 22000, "gold": 9000, "items": [["hp_l", 6], ["mp_l", 6]], "zone": "snow", "next": "yeti_king"},
	"yeti_king": {"name": "ราชายักษ์หิมะ", "desc": "ราชาเยติผู้ครองยอดเขาน้ำแข็ง ปราบมันเพื่อความสงบของภูเขา", "target": "yeti_king", "count": 1, "level": 30,
		"exp": 40000, "gold": 14000, "items": [["hp_l", 8], ["mp_l", 8]], "gear": [32, 3], "zone": "snow", "next": "lava"},
	"lava": {"name": "ออร์คลาวาอาละวาด", "desc": "ออร์คลาวาออกจากปล่องภูเขาไฟมาเผาไร่ ไปหยุดพวกมัน", "target": "fire_orc", "count": 14, "level": 32,
		"exp": 50000, "gold": 16000, "items": [["hp_l", 8], ["mp_l", 8]], "zone": "volcano", "next": "magma"},
	"magma": {"name": "มังกรแมกมาจ้าวภูเขาไฟ", "desc": "จ้าวแห่งภูเขาไฟรอเจ้าอยู่ที่ใจกลางปล่อง นี่คือบททดสอบสุดท้าย", "target": "magma_dragon", "count": 1, "level": 40,
		"exp": 120000, "gold": 40000, "items": [["hp_l", 10], ["mp_l", 10]], "gear": [42, 3], "zone": "volcano", "next": "bones"},
	"bones": {"name": "กองทัพอัศวินกระดูก", "desc": "อัศวินกระดูกลุกจากสุสานจันทร์เลือด ไปปราบพวกมัน", "target": "bone_knight", "count": 15, "level": 44,
		"exp": 200000, "gold": 60000, "items": [["hp_xl", 10], ["mp_xl", 10]], "zone": "graveyard", "next": "bone_lord"},
	"bone_lord": {"name": "ราชาโครงกระดูกเลือด", "desc": "เจ้าแห่งสุสานตื่นแล้ว ปราบมันให้สิ้นซาก", "target": "bone_lord", "count": 1, "level": 54,
		"exp": 500000, "gold": 150000, "items": [["hp_xl", 10], ["mp_xl", 10]], "gear": [56, 3], "zone": "graveyard", "next": "toxic"},
	"toxic": {"name": "หนองน้ำพิษมรณะ", "desc": "กบพิษยักษ์แพร่โรคในหนองน้ำ ไปกำจัดพวกมัน", "target": "toxic_frog", "count": 15, "level": 56,
		"exp": 700000, "gold": 200000, "items": [["mp_xl", 10], ["hp_xl", 10]], "zone": "swamp", "next": "toad_king"},
	"toad_king": {"name": "ราชาเห็ดพิษ", "desc": "จ้าวแห่งหนองน้ำพิษซ่อนอยู่ใจกลางหนอง", "target": "toad_king", "count": 1, "level": 66,
		"exp": 1500000, "gold": 400000, "items": [["hp_xl", 10], ["mp_xl", 10]], "gear": [68, 3], "zone": "swamp", "next": "thunder"},
	"thunder": {"name": "ภูผาสายฟ้าคำราม", "desc": "ยักษ์หินสายฟ้าถล่มหมู่บ้านใต้เขา ไปหยุดพวกมัน", "target": "thunder_golem", "count": 15, "level": 68,
		"exp": 2000000, "gold": 500000, "items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "storm", "next": "storm_dragon"},
	"storm_dragon": {"name": "มังกรสายฟ้าคำราม", "desc": "มังกรผู้เรียกพายุอยู่บนยอดเขา", "target": "storm_dragon", "count": 1, "level": 78,
		"exp": 4000000, "gold": 1000000, "items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [80, 3], "zone": "storm", "next": "angels"},
	"angels": {"name": "ทูตสวรรค์ตกต่ำ", "desc": "นครเมฆาสวรรค์ล่ม ทูตสวรรค์ที่ตกต่ำคลั่งไปทั่ว", "target": "fallen_angel", "count": 15, "level": 80,
		"exp": 5000000, "gold": 1500000, "items": [["mp_xxl", 10], ["hp_xxl", 10]], "zone": "sky", "next": "gold_dragon"},
	"gold_dragon": {"name": "มังกรทองเทพเจ้า", "desc": "เทพมังกรผู้เฝ้านครเมฆา แข็งแกร่งเกินมนุษย์", "target": "gold_dragon", "count": 1, "level": 90,
		"exp": 9000000, "gold": 3000000, "items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [92, 3], "zone": "sky", "next": "hell"},
	"hell": {"name": "ขุมนรกอเวจี", "desc": "ออร์คปีศาจบุกขึ้นมาจากขุมนรก ไปปิดประตูนรก", "target": "hell_orc", "count": 15, "level": 92,
		"exp": 12000000, "gold": 4000000, "items": [["mp_xxl", 10], ["hp_xxl", 10]], "zone": "abyss", "next": "abyss_dragon"},
	"abyss_dragon": {"name": "ราชามังกรอเวจี", "desc": "จ้าวแห่งขุมนรกคือศัตรูสุดท้ายของโลก ปราบมัน และกลายเป็นตำนาน", "target": "abyss_dragon", "count": 1, "level": 100,
		"exp": 30000000, "gold": 10000000, "items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [100, 3], "zone": "abyss", "next": ""},
}

const ORDER: Array[String] = ["slimes", "chickens", "cactus", "mush_king", "orcs", "ghosts", "dragon", "wolves", "sand_dragon", "yetis", "yeti_king", "lava", "magma", "bones", "bone_lord", "toxic", "toad_king", "thunder", "storm_dragon", "angels", "gold_dragon", "hell", "abyss_dragon"]


static func get_quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})


## The quest the elder should currently offer or ask about (first not yet rewarded).
static func current_quest() -> String:
	for id in ORDER:
		if Game.quest_status(id) != "done":
			return id
	return ""
