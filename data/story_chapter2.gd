class_name StoryChapter2
extends RefCounted
## บทที่ 2: เงาเหนือดวงดาว — the endgame story chain (★200 to ★300) that follows the
## elder's quests (QuestData). The village scholar ปิ่นดารา opens it; the sanctum guardian
## หยกวารี (วิหารบัวดารา) and the abyss exile นาวิน (ห้วงสมุทรอสูร) carry it. The villain,
## นิรา ราชินีเงาแห่งห้วงลึก, was the sanctum's star priestess: she fell into the abyss and
## now drinks the starlight of the Lotus Scales through a shadow conduit (สายโยงเงา) that
## runs from the sanctum's pools down into the drowned city. That conduit is why the two
## fields share one bestiary's drops (EndgameFields): the abyss monsters are the sanctum's
## drowned guardians, twisted by her shadow. The chain ends on บัลลังก์เงา, her throne
## stage beyond the abyss, whose portal opens only while the finale quest is active.
##
## Quest state lives in Game.profile.quests like the elder's ("new" / "active" / "ready" /
## "done" + progress); the landmark bits in flags[MARKS_FLAG]; the finale in flags[DONE_FLAG]
## and the cosmetic aura in flags[AURA_FLAG] (flags hold integers only). The runtime (dialog,
## escort, bosses, markers) is StoryChapter (systems/core/story_chapter.gd).

const TITLE := "บทที่ 2: เงาเหนือดวงดาว"
const VILLAIN := "นิรา ราชินีเงาแห่งห้วงลึก"
const END_TITLE := "ผู้ดับเงาเหนือดวงดาว"
const ACH_ID := "t_chapter2"
const MARKS_FLAG := "ch2_marks"
const DONE_FLAG := "ch2_done"
const AURA_FLAG := "ch2_aura"
## The special stage beyond the abyss (ZoneData.get_zone special-cases it; not in ZONES).
const STAGE_ID: StringName = &"shadow_throne"
const STAGE_TITLE := "บัลลังก์เงา"
const FIRST := "ch2_omen"
const FINALE := "ch2_throne"
const ESCORT_SECONDS := 60.0

## The NPCs: role -> [name, title, zone they stand in].
const ROLES := {
	"scholar": ["นักปราชญ์ปิ่นดารา", "บทที่ 2: เงาเหนือดวงดาว", &"town"],
	"sanctum_guardian": ["เทพพิทักษ์หยกวารี", "ผู้พิทักษ์วิหารบัวดารา", DivineRegionData.ID],
	"abyss_exile": ["นาวิน ผู้ลี้ภัยทะเลเงา", "ผู้ลี้ภัยจากห้วงลึก", DrownedAbyssData.ID],
}

## type: talk (npc), kill (targets, count), collect (item jewel id, count), investigate
## (marks), escort (seconds), boss (monster, started at the giver), finale (the stage).
## giver offers it and takes it back unless "turn_in" names another role; a talk quest is
## finished and paid by the NPC it sends you to.
const QUESTS := {
	"ch2_omen": {"name": "ลางร้ายเหนือดวงดาว", "type": "talk", "npc": "sanctum_guardian", "giver": "scholar", "turn_in": "sanctum_guardian", "star": 200, "count": 1, "zone": DivineRegionData.ID,
		"desc": "ดาวเหนือวิหารบัวดาราหรี่แสงลงทุกคืน นักปราชญ์ปิ่นดาราขอให้ไปถามเทพพิทักษ์หยกวารีที่หน้าวิหารว่าเกิดอะไรขึ้น", "next": "ch2_sprites"},
	"ch2_sprites": {"name": "ภูตบัวถูกเงาครอบงำ", "type": "kill", "targets": [&"lotus_sprite"], "count": 20, "giver": "sanctum_guardian", "star": 200, "zone": DivineRegionData.ID,
		"desc": "ภูตบัวประกายดาวในสวนบัวเรืองแสงตาดำวาวและไล่ทำร้ายผู้แสวงบุญ สงบพวกมัน 20 ตัวเพื่อเก็บหลักฐานของเงา", "next": "ch2_scales"},
	"ch2_scales": {"name": "เกล็ดบัวที่ไร้แสง", "type": "collect", "item": "lotus_scale", "count": 5, "giver": "sanctum_guardian", "star": 210, "zone": DivineRegionData.ID,
		"desc": "หยกวารีต้องการเกล็ดบัวดารา 5 เกล็ดจากมอนสเตอร์ในวิหารหรือห้วงสมุทรอสูร เพื่อตรวจว่าแสงดาวในเกล็ดถูกดูดไปทางไหน", "next": "ch2_landmarks"},
	"ch2_landmarks": {"type": "investigate", "name": "รอยเงาสามแห่ง", "giver": "sanctum_guardian", "star": 220, "count": 3, "zone": DivineRegionData.ID,
		"marks": [["ศาลาดาวร้าว", Vector3(-23, 0, 5)], ["สระบัวดับแสง", Vector3(25, 0, 4)], ["เสาจารึกเงา", Vector3(-38, 0, -34)]],
		"desc": "เดินไปสำรวจรอยเงาสามแห่งในวิหาร: ศาลาดาวร้าว สระบัวดับแสง และเสาจารึกเงา แล้วกลับมาเล่าให้หยกวารีฟัง", "next": "ch2_exile"},
	"ch2_exile": {"name": "ผู้ลี้ภัยจากห้วงลึก", "type": "talk", "npc": "abyss_exile", "giver": "sanctum_guardian", "turn_in": "abyss_exile", "star": 230, "count": 1, "zone": DrownedAbyssData.ID,
		"desc": "รอยเงาทุกแห่งชี้ลงสู่ห้วงสมุทรอสูร หยกวารีบอกว่ามีผู้ลี้ภัยคนหนึ่งหนีขึ้นมาจากเมืองจมน้ำ ไปหานาวินที่ทางเข้าห้วงสมุทรอสูร", "next": "ch2_mermen"},
	"ch2_mermen": {"name": "พี่น้องที่กลายเป็นเงา", "type": "kill", "targets": [&"abyss_merman"], "count": 15, "giver": "abyss_exile", "star": 235, "zone": DrownedAbyssData.ID,
		"desc": "นักรบเงือกทมิฬเคยเป็นพี่น้องของนาวิน ก่อนราชินีเงาจะกลืนใจพวกเขา ปลดปล่อยพวกเขา 15 คนจากพันธนาการเงา", "next": "ch2_escort"},
	"ch2_escort": {"name": "ถอดรหัสสายโยงเงา", "type": "escort", "seconds": 60, "giver": "abyss_exile", "star": 240, "count": 1, "zone": DrownedAbyssData.ID,
		"desc": "นาวินจะอ่านจารึกบนสายโยงเงากลางเมืองจมน้ำ ปกป้องเขาจากฝูงอสูรให้ครบ 60 วินาที (คุยกับนาวินในห้วงสมุทรอสูรเพื่อเริ่ม)", "next": "ch2_midboss"},
	"ch2_midboss": {"name": "วิหคเงาสะท้อน", "type": "boss", "monster": &"shadow_seraph", "count": 1, "giver": "sanctum_guardian", "star": 250, "zone": DivineRegionData.ID,
		"desc": "จารึกเผยว่าราชินีเงาสร้างเงาสะท้อนของออเรเลียไว้เฝ้าปากสายโยงในวิหาร คุยกับหยกวารีเพื่อเริ่มพิธีเรียกมันออกมา แล้วปราบซาเลีย วิหคเงาสะท้อน", "next": "ch2_chaos"},
	"ch2_chaos": {"name": "ผนึกสายโยงเงา", "type": "collect", "item": "chaos", "count": 8, "giver": "abyss_exile", "star": 260, "zone": DrownedAbyssData.ID,
		"desc": "นาวินต้องใช้เพชรชาออส 8 เม็ดจากมอนสเตอร์ในห้วงสมุทรอสูรหรือวิหารบัวดารา ผนึกปากสายโยงเงาไม่ให้แสงดาวไหลลงไปอีก", "next": "ch2_elites"},
	"ch2_elites": {"name": "ผู้คุมร่องลึก", "type": "kill", "targets": [&"trench_horror", &"leviathan_whelp"], "count": 10, "giver": "abyss_exile", "star": 270, "zone": DrownedAbyssData.ID,
		"desc": "อสูรหนวดร่องลึกและลูกเลวีอาธานคลั่งคุมทางลงสู่บัลลังก์ของราชินีเงา ล้มพวกมัน 10 ตัว", "next": "ch2_tyrant"},
	"ch2_tyrant": {"name": "ราชันสมุทรใต้เงา", "type": "kill", "targets": [&"tidal_tyrant"], "count": 1, "giver": "abyss_exile", "star": 280, "zone": DrownedAbyssData.ID,
		"desc": "โพไซดอน ราชันสมุทรอสูรถูกราชินีเงาครอบงำให้เฝ้าประตูบัลลังก์ ปราบเขาที่ลานบัลลังก์ราชันสมุทรเพื่อปลดเงาออกจากเขา", "next": "ch2_throne"},
	"ch2_throne": {"name": "บัลลังก์เงา", "type": "finale", "monster": &"shadow_queen", "count": 1, "giver": "scholar", "star": 300, "zone": STAGE_ID,
		"desc": "ประตูสู่บัลลังก์เงาจะปรากฏในห้วงสมุทรอสูรขณะที่เควสต์นี้ดำเนินอยู่ (ต้องดาว 300) ลงไปเผชิญหน้ากับนิรา ราชินีเงาแห่งห้วงลึก และดับเงาเหนือดวงดาวให้สิ้น", "next": ""},
}
const ORDER: Array[String] = ["ch2_omen", "ch2_sprites", "ch2_scales", "ch2_landmarks", "ch2_exile", "ch2_mermen", "ch2_escort", "ch2_midboss", "ch2_chaos", "ch2_elites", "ch2_tyrant", "ch2_throne"]

## The chapter's own monsters: the mid-boss (a shadow mirror of the sanctum's seraph, its
## rig in a night tint) and the queen on her throne. Both fight like the fields' bosses
## (MonsterData.stats_for tunes them as their home field, home_of) and carry StoryBoss
## for the telegraphed moves. Health is ten times the design like the fields (TOUGH_HP).
const MONSTERS := {
	&"shadow_seraph": {"name": "ซาเลีย วิหคเงาสะท้อน", "model": "flying/Alpaking_Evolved", "height": 5.0, "hover": 0.6, "hp": 26.0, "atk": 3.2, "def": 2.4, "speed": 2.7, "aggro": true, "attack": "ranged", "boss": true,
		"color": Color("9a6cff"), "tint": Color(0.5, 0.4, 0.95), "home": DivineRegionData.ID, "moves": ["nova", "lance"], "exp": 3.0, "gold": 4.0},
	&"shadow_queen": {"name": "นิรา ราชินีเงาแห่งห้วงลึก", "model": "flying/Demon", "height": 6.2, "hover": 0.8, "hp": 40.0, "atk": 3.6, "def": 2.8, "speed": 2.8, "aggro": true, "attack": "ranged", "boss": true,
		"color": Color("7a4dff"), "tint": Color(0.42, 0.32, 0.8), "home": DrownedAbyssData.ID, "moves": ["lance", "nova"], "exp": 4.0, "gold": 6.0},
}
## The adds the queen's veil calls (phase 2 and 3): drowned guardians of both fields.
const QUEEN_ADDS: Array[StringName] = [&"lotus_sprite", &"tide_squid", &"drown_jelly"]

## The queen's lines in her three phases (StoryStage shows them as dialog interrupts).
const QUEEN_LINES := [
	"นิรา: เจ้าปีนลงมาถึงบัลลังก์ของข้าได้... แต่แสงดาวทั้งหมดเป็นของข้าแล้ว",
	"นิรา: เจ้าคิดว่าดาวจะส่องให้ใครก็ได้งั้นหรือ? ให้ผู้พิทักษ์ที่จมน้ำของข้าสอนเจ้าเสีย!",
	"นิรา: ไม่... แสงนั่น... ข้าเป็นนักบวชแห่งดวงดาวมาก่อน! ห้วงลึกจะไม่ปล่อยข้าไปหรอก!",
]
## The ending pages (EndingScreen with these pages, then the credits).
const ENDING_PAGES := [
	"เมื่อนิรา ราชินีเงาแห่งห้วงลึกล้มลง สายโยงเงาที่ดูดแสงดาวจากวิหารก็ขาดสะบั้น\nแสงจากเกล็ดบัวดาราพุ่งขึ้นจากเมืองจมน้ำกลับคืนสู่ท้องฟ้า",
	"หยกวารีก้มศีรษะให้เจ้าที่หน้าวิหารบัวดารา\nนาวินยืนมองพี่น้องของเขาที่หลุดพ้นจากเงา น้ำตาคลอ\nและปิ่นดาราก็จดบันทึกบทสุดท้ายของตำนานนี้",
	"ดวงดาวเหนือมิสต์วูดสว่างกว่าที่เคย\nชาวบ้านเรียกเจ้าว่า \"ผู้ดับเงาเหนือดวงดาว\"\nและรัศมีดาวเงาที่เหลือจากบัลลังก์ก็เลือกเจ้าเป็นเจ้าของคนใหม่",
	"บทที่ 2 จบลงแล้ว แต่ห้วงลึกยังมีเรื่องเล่าอีกมาก...\nวิหารบัวดาราและห้วงสมุทรอสูรยังรอให้เจ้ากลับไปล่าต่อ",
]


static func has_monster(id: StringName) -> bool:
	return MONSTERS.has(id)


static func monster(id: StringName) -> Dictionary:
	var m: Dictionary = MONSTERS.get(id, {}).duplicate(true)
	if not m.is_empty():
		m.hp = float(m.hp) * EndgameFields.TOUGH_HP
	return m


## The field whose tuning a chapter monster fights with (MonsterData.home_zone).
static func home_of(id: StringName) -> StringName:
	return StringName(MONSTERS.get(id, {}).get("home", &""))


## The throne stage's zone (a story stage: no camps, its boss comes from StoryStage).
static func stage_zone() -> Dictionary:
	return {"name": STAGE_TITLE, "scene": "field", "level": [100, 100], "star": 300, "music": DrownedAbyssData.ID, "theme": &"void",
		"ambience": &"hum", "tree_density": 0.0, "camps": [], "story_stage": true, "divine_region": true,
		"sky": Color("150c2a"), "ground": Color("2a2342"), "fog": Color("3b2a5e"), "ambient": Color(0.6, 0.5, 0.95), "sun": Color(0.8, 0.6, 1.0),
		"path_color": Color("4a3a6e"), "seed": 47, "prev": DrownedAbyssData.ID, "next": &"",
		"sky_palette": [Color("07050f"), Color("1d1238"), Color("4a2d7a")], "sun_size": 0.0, "moon": true}


static func get_quest(id: String) -> Dictionary:
	if not QUESTS.has(id):
		return {}
	var quest: Dictionary = QUESTS[id].duplicate(true)
	quest["id"] = id
	return quest


static func is_quest(id: String) -> bool:
	return QUESTS.has(id)


## EXP, gold and the materials a turn-in pays (EXP and gold scale with the ★ gate like the
## elder's, QuestData.reward_for_level; a boss or the finale pays the boss rate). The
## materials are the two fields' own (EndgameFields): Lotus Scales, hp_god potions, 200★
## stat gems and, for the bosses, a set core.
static func reward(id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var quest := get_quest(id)
	if quest.is_empty():
		return {}
	var boss := String(quest.type) in ["boss", "finale"]
	var base := QuestData.reward_for_level(100, boss, int(quest.star))
	var items: Array = []
	var roll := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		roll.seed = hash(id)
	match String(quest.type):
		"talk":
			items.append(ItemData.potion("hp_god", 5))
		"kill", "investigate", "escort":
			items.append(ItemData.potion("hp_god", 8))
			items.append(ItemData.jewel(EndgameFields.SCALE, 2))
			items.append(Zone.random_stat_gem(200, 1, true, roll))
		"collect":
			items.append(ItemData.potion("mp_xxl", 10))
			items.append(ItemData.jewel(EndgameFields.SCALE, 3))
		"boss":
			items.append(ItemData.potion("hp_god", 15))
			items.append(ItemData.jewel(EndgameFields.SET_CORE, 1))
			items.append(ItemData.jewel(EndgameFields.SCALE, 4))
			items.append(Zone.random_stat_gem(200, 1, true, roll))
		"finale":
			items.append(ItemData.potion("hp_god", 25))
			items.append(ItemData.jewel(EndgameFields.SET_CORE, 2))
			items.append(ItemData.jewel(EndgameFields.SCALE, 10))
			for i in 2:
				items.append(Zone.random_stat_gem(200, 1, true, roll))
	return {"exp": int(base.exp), "gold": int(base.gold), "items": items}


# --- Progress ------------------------------------------------------------------------

static func state(id: String) -> Dictionary:
	return Game.quest_state(id) if Game.has_profile else {}


static func status(id: String) -> String:
	return Game.quest_status(id) if Game.has_profile else "new"


static func progress(id: String) -> int:
	return int(state(id).get("progress", 0))


## The quest the chapter is at (first not yet rewarded), "" once the chapter is over.
static func current() -> String:
	for id in ORDER:
		if status(id) != "done":
			return id
	return ""


static func started() -> bool:
	return status(FIRST) != "new"


static func finished() -> bool:
	return status(FINALE) == "done"


## "" when the hero may take the quest, else why not (the chapter is for Lv.100 heroes
## with the quest's stars).
static func unlock_problem(quest: Dictionary) -> String:
	if int(Game.profile.get("level", 1)) < Game.MAX_LEVEL:
		return "บทที่ 2 เริ่มได้เมื่อถึงเลเวล %d และดาว %d" % [Game.MAX_LEVEL, int(quest.star)]
	if int(Game.paragon().level) < int(quest.star):
		return "ตอนนี้ต้องใช้ดาว %d ขึ้นไป (ตอนนี้ดาว %d) ไปเก็บดาวที่วิหารบัวดาราหรือห้วงสมุทรอสูรก่อนนะ" % [int(quest.star), int(Game.paragon().level)]
	return ""


## The hero may be offered the chapter's first quest (★200, not taken yet).
static func offer_open() -> bool:
	return Game.has_profile and status(FIRST) == "new" and unlock_problem(get_quest(FIRST)) == ""


## The stage portal in the abyss stands only while the finale is active.
static func portal_open() -> bool:
	return Game.has_profile and status(FINALE) == "active"


static func has_aura() -> bool:
	return Game.has_profile and int(Game.profile.get("flags", {}).get(AURA_FLAG, 0)) > 0


## The landmarks visited (bit per mark) of the investigation.
static func marks_seen() -> int:
	return int(Game.profile.get("flags", {}).get(MARKS_FLAG, 0))


static func mark_seen(k: int) -> bool:
	return marks_seen() & (1 << k) != 0


## Counts a kill for the active kill / boss quests hunting this monster (Game.report_kill).
static func on_kill(monster_id: StringName) -> void:
	if not Game.has_profile:
		return
	for id in ORDER:
		if status(id) != "active":
			continue
		var quest := get_quest(id)
		var hunted: Array = quest.get("targets", [])
		if quest.has("monster") and String(quest.type) == "boss":
			hunted = [quest.monster]
		if not hunted.has(monster_id):
			continue
		var have := mini(progress(id) + 1, int(quest.count))
		if have >= int(quest.count):
			Game.set_quest(id, "ready", have)
			Game.say("เควสต์ \"%s\" เสร็จแล้ว! กลับไปรายงาน%s" % [quest.name, turn_in_name(id)], &"quest")
		else:
			Game.set_quest(id, "active", have)


## How many of a collect quest's items the bag holds.
static func collected(id: String) -> int:
	var quest := get_quest(id)
	return Game.jewel_count(String(quest.item)) if String(quest.get("type", "")) == "collect" and Game.has_profile else 0


## The role that pays a quest.
static func turn_in_role(id: String) -> String:
	var quest := get_quest(id)
	return String(quest.get("turn_in", quest.get("giver", "scholar")))


static func turn_in_name(id: String) -> String:
	return String(ROLES[turn_in_role(id)][0])


static func role_name(role: String) -> String:
	return String(ROLES.get(role, ["", "", &""])[0])


## What the tracker and the quest log tell the player to do now for quest `id`.
static func objective_text(id: String) -> String:
	var quest := get_quest(id)
	if quest.is_empty():
		return ""
	var st := status(id)
	if st == "ready":
		return "%s เสร็จแล้ว กลับไปรายงาน%s" % [quest.name, turn_in_name(id)]
	match String(quest.type):
		"talk":
			return "%s: ไปคุยกับ%s" % [quest.name, role_name(String(quest.npc))]
		"kill":
			var names: PackedStringArray = []
			for t in quest.targets:
				names.append(String(MonsterData.get_monster(StringName(t)).name))
			return "%s: ปราบ%s %d/%d" % [quest.name, " หรือ ".join(names), progress(id), int(quest.count)]
		"collect":
			return "%s: เก็บ%s %d/%d" % [quest.name, ItemData.JEWELS[String(quest.item)].name, mini(collected(id), int(quest.count)), int(quest.count)]
		"investigate":
			var seen := 0
			for k in (quest.marks as Array).size():
				if mark_seen(k):
					seen += 1
			return "%s: สำรวจรอยเงาในวิหารบัวดารา %d/%d" % [quest.name, seen, int(quest.count)]
		"escort":
			return "%s: คุยกับนาวินในห้วงสมุทรอสูรเพื่อเริ่ม แล้วปกป้องเขา %d วินาที" % [quest.name, int(quest.seconds)]
		"boss":
			return "%s: คุยกับหยกวารีเพื่อเรียกบอส แล้วปราบ%s" % [quest.name, MonsterData.get_monster(StringName(quest.monster)).name]
		"finale":
			return "%s: เข้าประตูบัลลังก์เงาในห้วงสมุทรอสูร ปราบ%s" % [quest.name, VILLAIN]
	return String(quest.name)


## The HUD tracker's line for the chapter ("" when nothing is in hand).
static func tracker_line() -> String:
	if not Game.has_profile:
		return ""
	var id := current()
	if id == "" or status(id) not in ["active", "ready"]:
		return ""
	return "บทที่ 2: " + objective_text(id)


## Whether an NPC of the chapter should bob its "!" marker: it has a quest to offer the hero
## can take, one to pay, or the hero is sent to it.
static func marker_for(role: String) -> bool:
	if not Game.has_profile or not ROLES.has(role):
		return false
	var id := current()
	if id == "":
		return false
	var quest := get_quest(id)
	var st := status(id)
	if st == "new":
		return String(quest.giver) == role and unlock_problem(quest) == ""
	if st == "ready":
		return turn_in_role(id) == role
	if st == "active":
		if String(quest.type) == "talk":
			return String(quest.npc) == role
		if String(quest.type) in ["escort", "boss"]:
			return String(quest.giver) == role
	return false


## World players' lines about the chapter (WorldChat.line_for): each is true only in the
## state that gates it, read from the hero's own save, so nobody speaks of what has not
## happened. %hero is the hero's name.
static func chat_lines() -> Array:
	if not Game.has_profile or int(Game.profile.get("level", 1)) < Game.MAX_LEVEL:
		return []
	var hero_name := String(Game.profile.get("name", "")).strip_edges()
	if hero_name == "":
		return []
	if finished():
		return ["%s ดับเงาเหนือดวงดาวได้แล้ว ราชินีเงาแห่งห้วงลึกไม่อยู่แล้ว เท่สุด" % hero_name,
			"ดาวเหนือวิหารบัวดาราสว่างขึ้นตั้งแต่ %s ปราบราชินีเงา" % hero_name]
	if started():
		return ["เห็น %s วุ่นอยู่กับเรื่องเงาที่วิหารบัวดาราด้วย สู้ ๆ นะ" % hero_name,
			"นักปราชญ์ปิ่นดาราบอกว่าเงาเหนือดวงดาวมาจากห้วงลึก ใครช่วย %s ได้ช่วยหน่อย" % hero_name]
	if offer_open():
		return ["นักปราชญ์ปิ่นดาราที่หมู่บ้านกำลังหาคนดาว 200 ไปสืบเรื่องเงาเหนือดวงดาวอยู่นะ"]
	return []
