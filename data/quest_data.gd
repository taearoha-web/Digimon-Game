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
		"items": [["hp_m", 5]], "zone": "dark_forest", "next": "ghosts"},
	"ghosts": {"name": "วิญญาณไม่สงบ", "desc": "ผีเงาม่วงหลอกหลอนยามค่ำ ส่งพวกมันกลับไปซะ", "target": "ghost", "count": 10, "level": 11,
		"items": [["hp_l", 3], ["mp_l", 3]], "zone": "dark_forest", "next": "dragon"},
	"dragon": {"name": "มังกรเพลิงผู้พิทักษ์", "desc": "มังกรเพลิงเฝ้าใจกลางป่า ปราบมันเพื่อพิสูจน์ความกล้า", "target": "fire_dragon", "count": 1, "level": 14,
		"items": [["hp_l", 5], ["mp_l", 5]], "gear": [16, 3], "zone": "dark_forest", "next": "wolves"},
	"wolves": {"name": "หมาป่าทรายอาละวาด", "desc": "ฝูงหมาป่าทรายรังควานพ่อค้าคาราวาน ไปปราบพวกมันที่ทะเลทราย", "target": "sand_wolf", "count": 12, "level": 15,
		"items": [["hp_l", 4], ["mp_l", 4]], "zone": "desert", "next": "sand_dragon"},
	"sand_dragon": {"name": "มังกรทะเลทราย", "desc": "มังกรผู้เฝ้าโอเอซิสกลางทะเลทราย พิสูจน์ความกล้าของเจ้า", "target": "sand_dragon", "count": 1, "level": 21,
		"items": [["hp_l", 5], ["mp_l", 5]], "gear": [24, 3], "zone": "desert", "next": "yetis"},
	"yetis": {"name": "เยติบนยอดเขา", "desc": "เยติตัวใหญ่ลงมาขโมยเสบียงชาวบ้าน ขึ้นเขาไปจัดการ", "target": "yeti", "count": 12, "level": 24,
		"items": [["hp_l", 6], ["mp_l", 6]], "zone": "snow", "next": "yeti_king"},
	"yeti_king": {"name": "ราชายักษ์หิมะ", "desc": "ราชาเยติผู้ครองยอดเขาน้ำแข็ง ปราบมันเพื่อความสงบของภูเขา", "target": "yeti_king", "count": 1, "level": 30,
		"items": [["hp_l", 8], ["mp_l", 8]], "gear": [32, 3], "zone": "snow", "next": "lava"},
	"lava": {"name": "ออร์คลาวาอาละวาด", "desc": "ออร์คลาวาออกจากปล่องภูเขาไฟมาเผาไร่ ไปหยุดพวกมัน", "target": "fire_orc", "count": 14, "level": 32,
		"items": [["hp_l", 8], ["mp_l", 8]], "zone": "volcano", "next": "magma"},
	"magma": {"name": "มังกรแมกมาจ้าวภูเขาไฟ", "desc": "จ้าวแห่งภูเขาไฟรอเจ้าอยู่ที่ใจกลางปล่อง ปราบมันแล้วเดินทางต่อสู่สุสานจันทร์เลือด", "target": "magma_dragon", "count": 1, "level": 40,
		"items": [["hp_l", 10], ["mp_l", 10]], "gear": [42, 3], "zone": "volcano", "next": "bones"},
	"bones": {"name": "กองทัพอัศวินกระดูก", "desc": "อัศวินกระดูกลุกจากสุสานจันทร์เลือด ไปปราบพวกมัน", "target": "bone_knight", "count": 15, "level": 44,
		"items": [["hp_xl", 10], ["mp_xl", 10]], "zone": "graveyard", "next": "bone_lord"},
	"bone_lord": {"name": "ราชาโครงกระดูกเลือด", "desc": "เจ้าแห่งสุสานตื่นแล้ว ปราบมันให้สิ้นซาก", "target": "bone_lord", "count": 1, "level": 54,
		"items": [["hp_xl", 10], ["mp_xl", 10]], "gear": [56, 3], "zone": "graveyard", "next": "toxic"},
	"toxic": {"name": "หนองน้ำพิษมรณะ", "desc": "กบพิษยักษ์แพร่โรคในหนองน้ำ ไปกำจัดพวกมัน", "target": "toxic_frog", "count": 15, "level": 56,
		"items": [["mp_xl", 10], ["hp_xl", 10]], "zone": "swamp", "next": "toad_king"},
	"toad_king": {"name": "ราชากบพิษ", "desc": "จ้าวแห่งหนองน้ำพิษซ่อนอยู่ใจกลางหนอง", "target": "toad_king", "count": 1, "level": 66,
		"items": [["hp_xl", 10], ["mp_xl", 10]], "gear": [68, 3], "zone": "swamp", "next": "thunder"},
	"thunder": {"name": "ภูผาสายฟ้าคำราม", "desc": "ยักษ์หินสายฟ้าถล่มหมู่บ้านใต้เขา ไปหยุดพวกมัน", "target": "thunder_golem", "count": 15, "level": 68,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "storm", "next": "storm_dragon"},
	"storm_dragon": {"name": "มังกรสายฟ้าคำราม", "desc": "มังกรผู้เรียกพายุอยู่บนยอดเขา", "target": "storm_dragon", "count": 1, "level": 78,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [80, 3], "zone": "storm", "next": "angels"},
	"angels": {"name": "ทูตสวรรค์ตกต่ำ", "desc": "นครเมฆาสวรรค์ล่ม ทูตสวรรค์ที่ตกต่ำคลั่งไปทั่ว", "target": "fallen_angel", "count": 15, "level": 80,
		"items": [["mp_xxl", 10], ["hp_xxl", 10]], "zone": "sky", "next": "gold_dragon"},
	"gold_dragon": {"name": "มังกรทองเทพเจ้า", "desc": "เทพมังกรผู้เฝ้านครเมฆา แข็งแกร่งเกินมนุษย์", "target": "gold_dragon", "count": 1, "level": 90,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [92, 3], "zone": "sky", "next": "hell"},
	"hell": {"name": "ขุมนรกอเวจี", "desc": "ออร์คปีศาจบุกขึ้นมาจากขุมนรก ไปปิดประตูนรก", "target": "hell_orc", "count": 15, "level": 92,
		"items": [["mp_xxl", 10], ["hp_xxl", 10]], "zone": "abyss", "next": "abyss_dragon"},
	"abyss_dragon": {"name": "ราชามังกรอเวจี", "desc": "จ้าวแห่งขุมนรกขวางทางสู่ห้วงจักรวาลวิบัติ ปราบมันแล้วเผชิญหน้ากับจักรพรรดิแห่งห้วงวิบัติ", "target": "abyss_dragon", "count": 1, "level": 100,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "gear": [100, 3], "zone": "abyss", "next": "void_golems"},
	# After Lv.100 the elder's work is gated by ★ (Paragon) instead of level.
	"void_golems": {"name": "ยักษ์หินห้วงว่างเปล่า", "desc": "ยักษ์หินจากห้วงจักรวาลวิบัติเดินขวางทางผู้กล้า ไปทุบพวกมันให้แตก", "target": "void_golem", "count": 15, "level": 100,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "void", "next": "void_emperor"},
	"void_emperor": {"name": "จักรพรรดิแห่งห้วงวิบัติ", "desc": "จักรพรรดิผู้กลืนดวงดาวรออยู่ใจกลางห้วงวิบัติ ปราบมันแล้วประตูสู่ดินแดนแห่งดวงดาวจะเปิด", "target": "void_emperor", "count": 1, "level": 100,
		"items": [["hp_xxl", 15], ["mp_xxl", 15]], "gear": [100, 4], "zone": "void", "next": "dawn_crabs"},
	"dawn_crabs": {"name": "ปูกลีบอรุณบุกป่า", "desc": "ปูกลีบอรุณยึดลำธารในป่าแสงอรุณ ไล่พวกมันออกไป", "target": "dawn_fox", "count": 15, "level": 100, "star": 1,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "dawn_forest", "next": "dawn_bunnies"},
	"dawn_bunnies": {"name": "กระต่ายหมัดจอมป่วน", "desc": "กระต่ายหมัดอรุณต่อยนักเดินทางล้มระเนระนาด สั่งสอนพวกมันหน่อย", "target": "dawn_bunny", "count": 15, "level": 100, "star": 10,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "dawn_forest", "next": "dawn_skulls"},
	"dawn_skulls": {"name": "กะโหลกหนามพฤกษา", "desc": "กะโหลกหนามเฝ้าดงหนามลึกในป่า ปราบพวกมันเพื่อเปิดทางสู่ราชันมังกร", "target": "dawn_thornhart", "count": 5, "level": 100, "star": 20,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "dawn_forest", "next": "dawn_dragon"},
	"dawn_dragon": {"name": "อรุณศิลา ราชันมังกรพฤกษา", "desc": "ราชันมังกรผู้ครองป่าแสงอรุณ ปราบมันแล้วรับวัตถุดิบชุดดาวจากผู้ใหญ่บ้าน", "target": "dawn_ancient_stag", "count": 1, "level": 100, "star": 30,
		"items": [["hp_xxl", 15], ["mp_xxl", 15]], "star_gear": 50, "zone": "dawn_forest", "next": "crystal_wolves"},
	"crystal_wolves": {"name": "หมาป่าเขี้ยวคราม", "desc": "ฝูงหมาป่าเขี้ยวครามล่าคนในหุบเขาผลึก ไปหยุดพวกมัน", "target": "crystal_wolf", "count": 15, "level": 100, "star": 50,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "crystal_valley", "next": "crystal_yetis"},
	"crystal_yetis": {"name": "เยติผลึกน้ำแข็ง", "desc": "เยติผลึกถล่มเหมืองคริสตัลของหมู่บ้าน ขึ้นไปจัดการ", "target": "crystal_yeti", "count": 15, "level": 100, "star": 60,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "crystal_valley", "next": "crystal_behemoths"},
	"crystal_behemoths": {"name": "เบฮีมอธเขาผลึก", "desc": "เบฮีมอธเกราะผลึกปิดทางเข้าลานราชัน ทลายพวกมันลง", "target": "crystal_behemoth", "count": 5, "level": 100, "star": 70,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "crystal_valley", "next": "crystal_king"},
	"crystal_king": {"name": "ไครโอฮอร์น ราชันผลึกคราม", "desc": "ราชันผลึกผู้แช่แข็งทั้งหุบเขา ปราบมันแล้วรับวัตถุดิบชุดดาว", "target": "crystal_horn_king", "count": 1, "level": 100, "star": 80,
		"items": [["hp_xxl", 15], ["mp_xxl", 15]], "star_gear": 100, "zone": "crystal_valley", "next": "sky_wardens"},
	"sky_wardens": {"name": "ผู้พิทักษ์วิหารฟ้า", "desc": "ผู้พิทักษ์วิหารฟ้าคลั่งและไล่ฟันผู้มาเยือนนครลอยฟ้า ไปสงบพวกมัน", "target": "sky_warden", "count": 15, "level": 100, "star": 100,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "sky_citadel", "next": "sky_spirits"},
	"sky_spirits": {"name": "ภูตวายุนภา", "desc": "ภูตวายุก่อพายุรอบนครลอยฟ้า สลายพวกมันก่อนนครจะร่วง", "target": "sky_wind_spirit", "count": 15, "level": 100, "star": 110,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "sky_citadel", "next": "sky_commanders"},
	"sky_commanders": {"name": "แม่ทัพปีกสุริยัน", "desc": "แม่ทัพปีกสุริยันนำทัพเฝ้าบัลลังก์ฟ้า ปราบพวกมันเพื่อไปถึงราชัน", "target": "sky_high_warden", "count": 5, "level": 100, "star": 120,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "sky_citadel", "next": "sky_king"},
	"sky_king": {"name": "เอเธอเรียน ราชันปีกสวรรค์", "desc": "ราชันปีกสวรรค์ผู้ครองนครลอยฟ้า ปราบมันแล้วรับวัตถุดิบชุดดาว", "target": "sky_celestial_king", "count": 1, "level": 100, "star": 130,
		"items": [["hp_xxl", 15], ["mp_xxl", 15]], "star_gear": 150, "zone": "sky_citadel", "next": "eclipse_knights"},
	"eclipse_knights": {"name": "อัศวินเกราะราตรี", "desc": "อัศวินเกราะราตรีตั้งค่ายที่ประตูอาณาจักรสุริยคราส ฝ่าแนวของพวกมัน", "target": "eclipse_warrior", "count": 15, "level": 100, "star": 150,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "eclipse_realm", "next": "eclipse_wraiths"},
	"eclipse_wraiths": {"name": "วิญญาณกะโหลกคราส", "desc": "วิญญาณกะโหลกคราสดูดแสงดาวจนฟ้ามืด ส่งพวกมันกลับสู่ความว่างเปล่า", "target": "eclipse_wraith", "count": 15, "level": 100, "star": 160,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "eclipse_realm", "next": "eclipse_dreadknights"},
	"eclipse_dreadknights": {"name": "ขุนพลเกราะคราส", "desc": "ขุนพลเกราะคราสคุ้มกันราชันสุริยคราส ล้มพวกมันให้หมด", "target": "eclipse_dreadknight", "count": 5, "level": 100, "star": 175,
		"items": [["hp_xxl", 10], ["mp_xxl", 10]], "zone": "eclipse_realm", "next": "eclipse_sovereign"},
	"eclipse_sovereign": {"name": "น็อกซ์ออเรล ราชันสุริยคราส", "desc": "ราชันสุริยคราสจะปรากฏต่อผู้มีดาว 200 เท่านั้น ปราบมันเพื่อนำแสงกลับคืนสู่โลก", "target": "eclipse_sovereign", "count": 1, "level": 100, "star": 200,
		"items": [["hp_xxl", 20], ["mp_xxl", 20]], "star_gear": 200, "zone": "eclipse_realm", "next": "lotus_monks"},
	"lotus_monks": {"name": "นักพรตวานรหยก", "desc": "นักพรตวานรหยกขวางทางเข้าวิหารบัวดารา พิสูจน์ฝีมือให้พวกมันเห็น", "target": "jade_monk", "count": 15, "level": 100, "star": 200,
		"items": [["hp_god", 15], ["mp_xxl", 15]], "zone": "lotus_sanctum", "next": "lotus_guardians"},
	"lotus_guardians": {"name": "โกเลมพิทักษ์วิหาร", "desc": "โกเลมทองคำเฝ้าศาลาในวิหาร ทลายพวกมันเพื่อไปพบเทพพิทักษ์", "target": "temple_guardian", "count": 5, "level": 100, "star": 200,
		"items": [["hp_god", 15], ["mp_xxl", 15]], "zone": "lotus_sanctum", "next": "lotus_seraph"},
	"lotus_seraph": {"name": "ออเรเลีย ราชันปีกบัวดารา", "desc": "บททดสอบสุดท้ายของวีรบุรุษ: ปราบราชันปีกบัวดาราผู้เฝ้าวิหาร", "target": "lotus_seraph", "count": 1, "level": 100, "star": 200,
		"items": [["hp_god", 25], ["mp_xxl", 25]], "star_gear": 200, "zone": "lotus_sanctum", "next": ""},
}

const ORDER: Array[String] = ["slimes", "chickens", "cactus", "mush_king", "orcs", "ghosts", "dragon", "wolves", "sand_dragon", "yetis", "yeti_king", "lava", "magma", "bones", "bone_lord", "toxic", "toad_king", "thunder", "storm_dragon", "angels", "gold_dragon", "hell", "abyss_dragon",
	"void_golems", "void_emperor", "dawn_crabs", "dawn_bunnies", "dawn_skulls", "dawn_dragon",
	"crystal_wolves", "crystal_yetis", "crystal_behemoths", "crystal_king",
	"sky_wardens", "sky_spirits", "sky_commanders", "sky_king",
	"eclipse_knights", "eclipse_wraiths", "eclipse_dreadknights", "eclipse_sovereign",
	"lotus_monks", "lotus_guardians", "lotus_seraph"]


## Meadow keeps its introductory rewards. Later turn-ins pay a predictable
## fraction of a level, with a larger boss bonus, including the Paragon finale.
## Past Lv.100 a ★ quest pays about one ★ of Paragon EXP (two for a boss).
static func reward_for_level(level: int, boss: bool, star := 0) -> Dictionary:
	var lv := clampi(level, 1, 100)
	if star > 0:
		var need := float(HeroStats.exp_to_next(100)) * (1.0 + 0.02 * float(star))
		return {
			"exp": int(round(need * (2.0 if boss else 1.0))),
			# Gold grows gently with ★ so the richest turn-in (a 200★ boss, about
			# 89k) stays inside the late-game upgrade economy (at most 100k).
			"gold": int(round(50.0 * pow(100.0, 1.45) * (1.0 + float(star) / 400.0) * (1.5 if boss else 1.0))),
		}
	return {
		"exp": int(round(float(HeroStats.exp_to_next(lv)) * (1.5 if boss else 0.9))),
		"gold": int(round(50.0 * pow(float(lv), 1.45) * (1.75 if boss else 1.0))),
	}


## A quest is open once the hero is one level short of it and has its ★.
static func unlock_problem(quest: Dictionary) -> String:
	var star := int(quest.get("star", 0))
	if star > 0 and int(Game.paragon().level) < star:
		return "งานนี้ต้องใช้ดาว %d ขึ้นไป กลับมาเมื่อพร้อมนะ" % star
	if int(Game.profile.level) < int(quest.level) - 1:
		return "งานนี้ยังอันตรายเกินไปสำหรับเจ้า กลับมาเมื่อถึงเลเวล %d นะ" % (int(quest.level) - 1)
	return ""


static func get_quest(id: String) -> Dictionary:
	if not QUESTS.has(id):
		return {}
	var quest: Dictionary = QUESTS[id].duplicate(true)
	var reward := reward_for_level(int(quest.level), int(quest.count) == 1, int(quest.get("star", 0)))
	quest["exp"] = int(quest.get("exp", reward.exp))
	quest["gold"] = int(quest.get("gold", reward.gold))
	return quest


## The quest the elder should currently offer or ask about (first not yet rewarded).
static func current_quest() -> String:
	for id in ORDER:
		if Game.quest_status(id) != "done":
			return id
	return ""
