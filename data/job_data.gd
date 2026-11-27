class_name JobData
extends RefCounted
## Advancement path of every class line. From the class picked on the create screen a hero
## advances four more times at the Job Master:
##   Lv.20 advanced -> Lv.40 supreme -> Lv.60 master -> Lv.80 legend
## Each step renames the hero, adds stat multipliers and STR/INT/DEX/VIT, and
## opens the next block of skills (see ClassData.skill_tier).
##
## Bonus keys: hp, mp, atk, def (multipliers), crit (added), speed (fraction added).
##
## The fifth and last step is the God promotion ("เทพเจ้าแห่ง<อาชีพ>"): it needs
## Lv.100 and ★300 (GOD_STARS) on top of its fee, and lifts the legend step's
## bonuses by GOD_SCALE (see god_step).
##
## Past the God step lies the Ascension (adv 6, ASCEND_ADV, "เปลี่ยนอาชีพขั้นที่ 6"): never
## bought from the Job Master, it is granted by the celestial sage's trial (AscensionData,
## "บททดสอบเทวาลัย") to a God at ★500 (ASCEND_STARS) who defeats its guardian; the world
## players too must win it (WorldPlayers.ascended_at, adv_for's ascended). Its grand title
## (ASCEND_TITLES) lifts the legend step's bonuses by ASCEND_SCALE (a step above the God
## step, see ascend_step)
## and opens the two Ascension skills of the class (AscendSkillData, tier ASCEND_TIER).

const TIER_LEVELS := [20, 40, 60, 80, 100]
const TIER_COSTS := [1500, 6000, 20000, 60000, 1000000]
const TIER_SKILL_POINTS := [2, 3, 4, 5, 6]
const MAX_ADV := 6
## The steps a hero takes by level alone (Lv.20/40/60/80); companions and guild-war
## fighters stop here, a world player at ★300 takes the God step too (adv_for), and the
## Ascension only once it has passed the trial (WorldPlayers.ascended_at).
const LEGEND_ADV := 4
## The God step (adv 5) and the stars it needs.
const GOD_ADV := 5
const GOD_STARS := 300
## How much bigger the God step is than the legend step: each multiplier's gain
## (atk 1.18 -> 1 + 0.18 * 1.4 = 1.252), each added crit / speed (x1.4), and each
## STR/INT/DEX/VIT bonus (x1.5).
const GOD_SCALE := 1.4
const GOD_ATTR_SCALE := 1.5
## The Ascension (adv 6): ★500, granted by the trial (AscensionData), never bought.
const ASCEND_ADV := 6
const ASCEND_STARS := 500
## Skill points the Ascension gives (the God step gives 6).
const ASCEND_SKILL_POINTS := 8
## The class tier the Ascension skills need (ClassData.skill_tier / tier_of): above every
## level tier (2..5), so a God at ★500 still needs the trial to cast them.
const ASCEND_TIER := 7
## How much bigger the Ascension is than the legend step (the God step is 1.4 / 1.5):
## atk 1.18 -> 1 + 0.18 * 1.9 = 1.342; crit / speed x1.9; STR/INT/DEX/VIT x2.1.
const ASCEND_SCALE := 1.9
const ASCEND_ATTR_SCALE := 2.1
## The Ascension of each class: [name, title (ฉายา), colour].
const ASCEND_TITLES := {
	&"warrior": ["จักรพรรดิดาบสวรรค์", "ผู้ปกครองคมดาบแห่งเทวาลัย", Color("fff6c8")],
	&"archer": ["จักรพรรดิศรดารา", "ผู้ยิงดวงตะวันให้หยุดนิ่ง", Color("d8fff4")],
	&"mage": ["มหาเทพแห่งจักรวาลเวท", "ผู้เขียนกฎของดวงดาว", Color("f0dcff")],
	&"priest": ["มหาเทพแห่งแสงนิรันดร์", "ผู้ปลุกรุ่งอรุณแห่งเทวาลัย", Color("fffdf0")],
	&"summoner": ["จักรพรรดิอสูรเทวะ", "ผู้บัญชาสรรพสัตว์สามภพ", Color("e4ffc8")],
	&"lancer": ["จักรพรรดิหอกมังกรสวรรค์", "ผู้ทะลวงประตูเทวาลัย", Color("e0f6ff")],
	&"defender": ["ปราการเทวะนิรันดร์", "กำแพงที่สวรรค์พิงหลัง", Color("eef6ff")],
	&"assassin": ["จักรพรรดิเงาไร้กาล", "ผู้พิพากษาในราตรีนิรันดร์", Color("ffd8ee")],
	&"darklord": ["มหาจักรพรรดิอเวจีสวรรค์", "ผู้สวมมงกุฎแห่งแสงและความมืด", Color("ffe48a")],
	&"bard": ["คีตเทพแห่งจักรวาล", "ผู้ขับขานบทเพลงนิรันดร์", Color("fff0fa")],
	&"muaythai": ["บรมครูมวยเทวะ", "หมัดที่สะเทือนเทวาลัย", Color("ffe8c4")],
}
## The God step of each class: its title (ฉายา) and colour; the name is
## "เทพเจ้าแห่ง" + the class's Thai name.
const GOD_TITLES := {
	&"warrior": ["ผู้ฟาดฟันสวรรค์และพิภพ", Color("fff3b0")],
	&"archer": ["ผู้ยิงดวงดาวร่วงจากฟ้า", Color("c8fff0")],
	&"mage": ["ผู้ถือกุญแจแห่งจักรวาล", Color("e6c8ff")],
	&"priest": ["แสงแรกแห่งการสร้างโลก", Color("fffbe6")],
	&"summoner": ["ผู้ปกครองสรรพอสูรบรรพกาล", Color("d8ffb0")],
	&"lancer": ["หอกที่ทะลวงสวรรค์ชั้นเจ็ด", Color("d6f2ff")],
	&"defender": ["โล่ที่โอบอุ้มทั้งโลก", Color("e6f2ff")],
	&"assassin": ["เงาที่แม้ความตายยังเกรงขาม", Color("ffc8e6")],
	&"darklord": ["จ้าวบัลลังก์อเวจีผู้ไร้ขอบเขต", Color("ffd86a")],
	&"bard": ["ผู้บรรเลงบทเพลงสร้างโลก", Color("ffe6f6")],
	&"muaythai": ["หมัดที่สั่นสะเทือนสามภพ", Color("ffe0b0")],
}

## Per class: the four steps in order.
const PATHS := {
	&"warrior": [
		{"name": "นักดาบขั้นสูง", "title": "อัศวินผู้กล้า", "color": Color("ffb04a"),
			"desc": "ฝึกขั้นสูง ทนทานและแข็งแกร่งขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"hp": 1.2, "def": 1.1, "atk": 1.1}, "attrs": {"str": 12, "vit": 8, "dex": 3}},
		{"name": "นักดาบขั้นสุดยอด", "title": "ราชันย์แห่งสนามรบ", "color": Color("ff8a3a"),
			"desc": "ถึงขั้นสุดยอด ฟันหนักและอึดทะลุเกราะ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"hp": 1.12, "def": 1.1, "atk": 1.12, "crit": 0.015}, "attrs": {"str": 20, "vit": 14, "dex": 5}},
		{"name": "ปรมาจารย์นักดาบ", "title": "ผู้ครองดาบทั้งปวง", "color": Color("ff5a3a"),
			"desc": "ปรมาจารย์แห่งดาบ พลังล้นเหลือ ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"hp": 1.12, "def": 1.1, "atk": 1.12, "crit": 0.015}, "attrs": {"str": 28, "vit": 20, "dex": 8}},
		{"name": "นักดาบในตำนาน", "title": "วีรบุรุษที่โลกจดจำ", "color": Color("ffe27a"),
			"desc": "ตำนานแห่งนักดาบ สุดยอดของสายดาบ ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"hp": 1.15, "def": 1.12, "atk": 1.15, "crit": 0.02}, "attrs": {"str": 40, "vit": 28, "dex": 12}},
	],
	&"archer": [
		{"name": "นักธนูขั้นสูง", "title": "พรานตาเหยี่ยว", "color": Color("5affc0"),
			"desc": "ยิงแม่นและว่องไวขึ้น คริติคอลสูง ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "crit": 0.025, "speed": 0.05, "hp": 1.08}, "attrs": {"dex": 12, "str": 4, "vit": 5}},
		{"name": "นักธนูขั้นสุดยอด", "title": "ลมพัดพิฆาต", "color": Color("7affd0"),
			"desc": "ยิงไกลเฉียบขาด เรียกสัตว์คู่ใจได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.14, "crit": 0.025, "speed": 0.04, "hp": 1.08}, "attrs": {"dex": 20, "str": 8, "vit": 8}},
		{"name": "ปรมาจารย์นักธนู", "title": "ลูกศรที่ไม่เคยพลาด", "color": Color("ffe27a"),
			"desc": "ปรมาจารย์แห่งธนู ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.14, "crit": 0.025, "speed": 0.04, "hp": 1.08}, "attrs": {"dex": 28, "str": 12, "vit": 11}},
		{"name": "นักธนูในตำนาน", "title": "เทพแห่งสายลม", "color": Color("fff0a0"),
			"desc": "ตำนานแห่งนักธนู ยิงทะลุฟ้า ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.18, "crit": 0.03, "speed": 0.05, "hp": 1.1}, "attrs": {"dex": 40, "str": 16, "vit": 16}},
	],
	&"mage": [
		{"name": "นักเวทย์ขั้นสูง", "title": "จอมเวทธาตุ", "color": Color("b79bff"),
			"desc": "ควบคุมธาตุได้ลึกซึ้งขึ้น พลังเวทและ MP เพิ่มมาก ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.15, "mp": 1.2, "def": 1.05, "hp": 1.08}, "attrs": {"int": 12, "vit": 5, "dex": 3}},
		{"name": "นักเวทย์ขั้นสุดยอด", "title": "ผู้เรียกวิญญาณ", "color": Color("9a7bff"),
			"desc": "เรียกวิญญาณและดาบเวทมาช่วยรบได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.14, "mp": 1.12, "def": 1.05, "hp": 1.08}, "attrs": {"int": 20, "vit": 8, "dex": 5}},
		{"name": "ปรมาจารย์นักเวทย์", "title": "ผู้หยุดกาลเวลา", "color": Color("7fdcff"),
			"desc": "ปรมาจารย์แห่งเวท พลังทำลายล้างมหาศาล ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.14, "mp": 1.12, "def": 1.05, "hp": 1.08}, "attrs": {"int": 28, "vit": 11, "dex": 8}},
		{"name": "นักเวทย์ในตำนาน", "title": "จอมเวทผู้ล่วงลับกาลเวลา", "color": Color("ffd0ff"),
			"desc": "ตำนานแห่งนักเวทย์ ร่ายเวทผ่าฟ้า ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "mp": 1.15, "def": 1.06, "hp": 1.1}, "attrs": {"int": 40, "vit": 16, "dex": 12}},
	],
	&"priest": [
		{"name": "นักบวชขั้นสูง", "title": "ผู้รักษาแห่งแสง", "color": Color("fff0a0"),
			"desc": "อึดและรักษาเก่งขึ้น แสงศักดิ์สิทธิ์แรงขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"hp": 1.15, "def": 1.1, "mp": 1.1, "atk": 1.1}, "attrs": {"int": 10, "vit": 8, "dex": 3}},
		{"name": "นักบวชขั้นสุดยอด", "title": "ผู้พิทักษ์ศรัทธา", "color": Color("d8ffe0"),
			"desc": "พลังศรัทธากล้าแข็ง ฟื้นฟูและโจมตีได้ในตัว ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"hp": 1.12, "def": 1.08, "mp": 1.1, "atk": 1.1}, "attrs": {"int": 18, "vit": 12, "dex": 4}},
		{"name": "ปรมาจารย์นักบวช", "title": "แสงสว่างแห่งความหวัง", "color": Color("ffffff"),
			"desc": "ปรมาจารย์แห่งแสง ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"hp": 1.12, "def": 1.08, "mp": 1.1, "atk": 1.1}, "attrs": {"int": 26, "vit": 17, "dex": 6}},
		{"name": "นักบวชในตำนาน", "title": "ผู้ประสิทธิ์ปาฏิหาริย์", "color": Color("ffe9a0"),
			"desc": "ตำนานแห่งนักบวช ปาฏิหาริย์แห่งสวรรค์ ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"hp": 1.15, "def": 1.1, "mp": 1.12, "atk": 1.14}, "attrs": {"int": 38, "vit": 24, "dex": 9}},
	],
	&"summoner": [
		{"name": "ผู้เรียกอสูรขั้นสูง", "title": "เพื่อนแห่งสัตว์ป่า", "color": Color("8fe07a"),
			"desc": "ผูกพันกับสัตว์ป่ามากขึ้น พลังเวทและ MP เพิ่ม ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "mp": 1.15, "hp": 1.08, "def": 1.05}, "attrs": {"int": 11, "vit": 6, "dex": 3}},
		{"name": "ผู้เรียกอสูรขั้นสุดยอด", "title": "ผู้นำฝูงอสูร", "color": Color("6fd06a"),
			"desc": "เรียกผู้พิทักษ์ร่างยักษ์มาช่วยรบได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.13, "mp": 1.12, "hp": 1.08, "def": 1.06}, "attrs": {"int": 19, "vit": 10, "dex": 5}},
		{"name": "ปรมาจารย์ผู้เรียกอสูร", "title": "เสียงเรียกแห่งผืนป่า", "color": Color("b0f07a"),
			"desc": "ปรมาจารย์แห่งธรรมชาติ ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.13, "mp": 1.12, "hp": 1.1, "def": 1.06}, "attrs": {"int": 27, "vit": 14, "dex": 8}},
		{"name": "ผู้เรียกอสูรในตำนาน", "title": "ราชันแห่งสรรพสัตว์", "color": Color("ffe27a"),
			"desc": "ตำนานแห่งผู้เรียกอสูร เรียกมังกรโบราณมาช่วยรบ ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "mp": 1.15, "hp": 1.12, "def": 1.08}, "attrs": {"int": 39, "vit": 20, "dex": 12}},
	],
	&"lancer": [
		{"name": "นักหอกขั้นสูง", "title": "ผู้ถือหอกเร็ว", "color": Color("8fd8ff"),
			"desc": "ฝึกหอกจนคล่อง ตีไวและเร็วขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "crit": 0.015, "speed": 0.03, "hp": 1.08}, "attrs": {"dex": 11, "str": 5, "vit": 5}},
		{"name": "นักหอกขั้นสุดยอด", "title": "ผู้พิชิตแนวหน้า", "color": Color("6ecbff"),
			"desc": "แทงทะลุหลายตัวเป็นแนวยาว ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.13, "crit": 0.02, "speed": 0.04, "hp": 1.1}, "attrs": {"dex": 19, "str": 8, "vit": 9}},
		{"name": "ปรมาจารย์นักหอก", "title": "ผู้ครองหอกทะลวงฟ้า", "color": Color("b8e6ff"),
			"desc": "ปรมาจารย์แห่งหอก ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.13, "crit": 0.02, "speed": 0.04, "hp": 1.1, "def": 1.06}, "attrs": {"dex": 27, "str": 11, "vit": 13}},
		{"name": "นักหอกในตำนาน", "title": "ราชันย์หอกมังกร", "color": Color("ffd84a"),
			"desc": "ตำนานแห่งหอก แทงทะลุฟ้าดิน ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "crit": 0.025, "speed": 0.05, "hp": 1.12, "def": 1.08}, "attrs": {"dex": 39, "str": 16, "vit": 18}},
	],
	&"defender": [
		{"name": "ผู้พิทักษ์ขั้นสูง", "title": "โล่เหล็กแห่งแนวหน้า", "color": Color("9fc4e8"),
			"desc": "ยกโล่ได้มั่นคงขึ้น ทนทานกว่าเดิมมาก ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"hp": 1.25, "def": 1.15, "atk": 1.06}, "attrs": {"str": 12, "vit": 8, "dex": 2}},
		{"name": "ผู้พิทักษ์ขั้นสุดยอด", "title": "กำแพงที่ไม่มีวันพัง", "color": Color("6fa8dc"),
			"desc": "ยั่วยุศัตรูทั้งฝูงและสะท้อนความเสียหายได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"hp": 1.15, "def": 1.12, "atk": 1.08}, "attrs": {"str": 20, "vit": 14, "dex": 3}},
		{"name": "ปรมาจารย์ผู้พิทักษ์", "title": "ป้อมปราการเดินได้", "color": Color("b8d8f8"),
			"desc": "ปรมาจารย์แห่งโล่ ทุบพสุธาถล่มรอบตัว ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"hp": 1.15, "def": 1.12, "atk": 1.08}, "attrs": {"str": 28, "vit": 20, "dex": 5}},
		{"name": "ผู้พิทักษ์ในตำนาน", "title": "โล่แห่งสวรรค์", "color": Color("ffe27a"),
			"desc": "ตำนานแห่งโล่ ปราการที่ไม่มีใครทะลวงได้ ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"hp": 1.18, "def": 1.15, "atk": 1.12, "crit": 0.01}, "attrs": {"str": 40, "vit": 28, "dex": 8}},
	],
	&"assassin": [
		{"name": "นักฆ่าขั้นสูง", "title": "เงาไร้เสียง", "color": Color("b18cff"),
			"desc": "ก้าวเงาได้เงียบกว่าเดิม ตีเร็วและหลบไวขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "crit": 0.02, "speed": 0.05, "hp": 1.08}, "attrs": {"dex": 12, "str": 4, "vit": 5}},
		{"name": "นักฆ่าขั้นสุดยอด", "title": "มีดคู่ในความมืด", "color": Color("9a6bff"),
			"desc": "ปาดคอในพริบตา ขว้างมีดเงาทะลุแนวศัตรู ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.14, "crit": 0.025, "speed": 0.04, "hp": 1.08}, "attrs": {"dex": 20, "str": 7, "vit": 9}},
		{"name": "ปรมาจารย์นักฆ่า", "title": "ผู้ครองราตรี", "color": Color("ff4f7b"),
			"desc": "ปรมาจารย์แห่งเงา ร่ายระบำเงาฉีกฝูงศัตรู ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.14, "crit": 0.025, "speed": 0.04, "hp": 1.1}, "attrs": {"dex": 28, "str": 10, "vit": 13}},
		{"name": "นักฆ่าในตำนาน", "title": "ราชันแห่งเงา", "color": Color("ffd0ff"),
			"desc": "ตำนานแห่งนักฆ่า ประหารทุกสิ่งในเงามืด ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.18, "crit": 0.03, "speed": 0.05, "hp": 1.12}, "attrs": {"dex": 40, "str": 14, "vit": 18}},
	],
	&"darklord": [
		{"name": "ลอร์ดขั้นสูง", "title": "ผู้บัญชาการแห่งความมืด", "color": Color("f0c86a"),
			"desc": "คทาราชันตอบสนองคำสั่ง อีกาคู่ใจแข็งแกร่งขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "hp": 1.12, "def": 1.06, "crit": 0.01}, "attrs": {"str": 10, "int": 5, "vit": 6}},
		{"name": "ลอร์ดขั้นสุดยอด", "title": "จอมทัพแห่งเพลิงและสายฟ้า", "color": Color("e8b64a"),
			"desc": "ออกคำบัญชาการเสริมพลังตัวเอง ปล่อยเพลิงและพายุพลาสมา ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.14, "hp": 1.1, "def": 1.08, "crit": 0.015}, "attrs": {"str": 17, "int": 8, "vit": 10}},
		{"name": "ปรมาจารย์ลอร์ด", "title": "จ้าวสายฟ้าและความโกลาหล", "color": Color("8a4dff"),
			"desc": "จ้าวแห่งความโกลาหล เรียกดาวหางมืดและสายฟ้าราชัน ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.14, "hp": 1.1, "def": 1.08, "crit": 0.02}, "attrs": {"str": 24, "int": 11, "vit": 14}},
		{"name": "ดาร์กลอร์ดในตำนาน", "title": "จักรพรรดิอีกาผู้ไร้พ่าย", "color": Color("ffe9a0"),
			"desc": "ตำนานแห่งดาร์กลอร์ด ราชโองการที่ทั้งสนามรบต้องก้มหัว ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.18, "hp": 1.14, "def": 1.1, "crit": 0.025}, "attrs": {"str": 36, "int": 16, "vit": 20}},
	],
	&"bard": [
		{"name": "นักดนตรีขั้นสูง", "title": "ผู้บรรเลงเพลงศึก", "color": Color("ff9fcf"),
			"desc": "นิ้วพลิ้วไหวขึ้น บทเพลงก้องกังวาน ดีดเสียงไม่ประสานให้ศัตรูเกราะแตกได้ ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "mp": 1.12, "hp": 1.1, "def": 1.05, "crit": 0.01}, "attrs": {"int": 10, "dex": 4, "vit": 7}},
		{"name": "นักดนตรีขั้นสุดยอด", "title": "ผู้ขับขานบทเพลงวีรชน", "color": Color("ff6fb5"),
			"desc": "ขับขานเพลงชาติวีรชนปลุกทั้งปาร์ตี้ กล่อมฝูงศัตรูให้หลับใหล ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.12, "mp": 1.1, "hp": 1.08, "def": 1.06, "crit": 0.015}, "attrs": {"int": 18, "dex": 7, "vit": 10}},
		{"name": "ปรมาจารย์นักดนตรี", "title": "วาทยกรแห่งสนามรบ", "color": Color("c36bff"),
			"desc": "ปรมาจารย์แห่งเสียงดนตรี บรรเลงราพโซดีสายฟ้าทำลายเกราะ ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.12, "mp": 1.1, "hp": 1.1, "def": 1.06, "crit": 0.015}, "attrs": {"int": 26, "dex": 10, "vit": 14}},
		{"name": "นักดนตรีในตำนาน", "title": "คีตกวีแห่งดวงดาว", "color": Color("fff0c0"),
			"desc": "ตำนานแห่งนักดนตรี บทเพลงที่ทั้งสนามรบต้องหยุดฟัง ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.15, "mp": 1.12, "hp": 1.12, "def": 1.08, "crit": 0.02}, "attrs": {"int": 36, "dex": 14, "vit": 19}},
	],
	&"muaythai": [
		{"name": "นักมวยขั้นสูง", "title": "นักชกเวทีมวย", "color": Color("ffb06a"),
			"desc": "หมัดหนักขึ้น ศอกและเข่าคมขึ้น ถีบศัตรูกระเด็นได้ ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.12, "hp": 1.12, "def": 1.06, "crit": 0.01}, "attrs": {"str": 10, "vit": 8, "dex": 3}},
		{"name": "นักมวยขั้นสุดยอด", "title": "ยอดมวยวงประเจียด", "color": Color("ff8a2a"),
			"desc": "วงประเจียดคุ้มกายแกร่งขึ้น ชกติดคอมโบได้นานขึ้น ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.12, "hp": 1.12, "def": 1.07, "crit": 0.015}, "attrs": {"str": 18, "vit": 13, "dex": 5}},
		{"name": "ปรมาจารย์มวยไทย", "title": "ครูมวยแห่งวงมนตรา", "color": Color("ff5a1f"),
			"desc": "วงประเจียด 4 วงวนรอบตัว จับทุ่มและเข่าลอยดั่งครูมวย ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.13, "hp": 1.12, "def": 1.08, "crit": 0.015}, "attrs": {"str": 26, "vit": 18, "dex": 7}},
		{"name": "นักมวยในตำนาน", "title": "ราชันมวยไทย", "color": Color("ffe27a"),
			"desc": "ตำนานแห่งหมัดมวย วงประเจียด 6 วงวนรอบกาย ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "hp": 1.14, "def": 1.1, "crit": 0.02}, "attrs": {"str": 36, "vit": 24, "dex": 9}},
	],
}


## Step [param index] (0..3, 4 for the God step, 5 for the Ascension) of a class path, or {}.
static func step(class_id: StringName, index: int) -> Dictionary:
	if index == GOD_ADV - 1:
		return god_step(class_id)
	if index == ASCEND_ADV - 1:
		return ascend_step(class_id)
	var path: Array = PATHS.get(class_id, [])
	return path[index] if index >= 0 and index < path.size() else {}


static var _gods: Dictionary = {}


## The God step of a class: "เทพเจ้าแห่ง<ชื่ออาชีพ>", its legend step's bonuses
## scaled up by GOD_SCALE (multipliers, crit, speed) and GOD_ATTR_SCALE (attributes).
static func god_step(class_id: StringName) -> Dictionary:
	if not PATHS.has(class_id):
		return {}
	if _gods.has(class_id):
		return _gods[class_id]
	var legend: Dictionary = PATHS[class_id][LEGEND_ADV - 1]
	var bonus := {}
	for key in legend.bonus:
		var value := float(legend.bonus[key])
		bonus[key] = snappedf(1.0 + (value - 1.0) * GOD_SCALE, 0.001) if key in ["hp", "mp", "atk", "def"] else snappedf(value * GOD_SCALE, 0.001)
	var attrs := {}
	for key in legend.attrs:
		attrs[key] = int(round(float(legend.attrs[key]) * GOD_ATTR_SCALE))
	var info: Array = GOD_TITLES.get(class_id, ["เทพเจ้า", Color("fff3b0")])
	var result := {"name": god_name(class_id), "title": info[0], "color": info[1], "god": true, "stars": GOD_STARS,
		"desc": "ขั้นสุดท้ายเหนือตำนาน ต้องเลเวล 100 และดาว %d พลังทุกด้านเหนือกว่าขั้นตำนาน ปลดล็อกพลังเทพเจ้าเต็มขั้น" % GOD_STARS,
		"bonus": bonus, "attrs": attrs}
	_gods[class_id] = result
	return result


static var _ascends: Dictionary = {}


## The Ascension of a class (adv 6): its grand name, the legend step's bonuses scaled by
## ASCEND_SCALE / ASCEND_ATTR_SCALE (above the God step's on every key).
static func ascend_step(class_id: StringName) -> Dictionary:
	if not PATHS.has(class_id):
		return {}
	if _ascends.has(class_id):
		return _ascends[class_id]
	var legend: Dictionary = PATHS[class_id][LEGEND_ADV - 1]
	var bonus := {}
	for key in legend.bonus:
		var value := float(legend.bonus[key])
		bonus[key] = snappedf(1.0 + (value - 1.0) * ASCEND_SCALE, 0.001) if key in ["hp", "mp", "atk", "def"] else snappedf(value * ASCEND_SCALE, 0.001)
	var attrs := {}
	for key in legend.attrs:
		attrs[key] = int(round(float(legend.attrs[key]) * ASCEND_ATTR_SCALE))
	var info: Array = ASCEND_TITLES.get(class_id, ["จักรพรรดิเทวาลัย", "ผู้ผ่านบททดสอบเทวาลัย", Color("fff6c8")])
	var result := {"name": info[0], "title": info[1], "color": info[2], "god": true, "ascend": true, "stars": ASCEND_STARS,
		"desc": "เปลี่ยนอาชีพขั้นที่ 6 เหนือเทพเจ้า ต้องดาว %d และผ่านบททดสอบเทวาลัย ปลดล็อกสกิลเทวาลัย 2 สกิล พลังทุกด้านเหนือขั้นเทพเจ้า" % ASCEND_STARS,
		"bonus": bonus, "attrs": attrs}
	_ascends[class_id] = result
	return result


## True once a hero with [param adv] steps has taken the Ascension (adv 6).
static func is_ascended(adv: int) -> bool:
	return adv >= ASCEND_ADV


## "เทพเจ้าแห่ง" + the class's Thai name, e.g. เทพเจ้าแห่งดาร์กลอร์ด.
static func god_name(class_id: StringName) -> String:
	return "เทพเจ้าแห่ง" + String(ClassData.get_class_data(class_id).name)


## True once a hero with [param adv] steps is a God.
static func is_god(adv: int) -> bool:
	return adv >= GOD_ADV


## Stars the step after [param adv] steps needs (0 for the level steps).
static func step_stars(adv: int) -> int:
	return GOD_STARS if adv == GOD_ADV - 1 else (ASCEND_STARS if adv == ASCEND_ADV - 1 else 0)


## "พลังโจมตี +25%  HP +20%  คริติคอล +3.5%" for a step's bonus.
static func bonus_text(bonus: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names := {"atk": "พลังโจมตี", "def": "พลังป้องกัน", "hp": "HP", "mp": "MP"}
	for key in ["atk", "def", "hp", "mp"]:
		if bonus.has(key):
			parts.append("%s +%d%%" % [names[key], int(round((float(bonus[key]) - 1.0) * 100.0))])
	if bonus.has("crit"):
		parts.append("คริติคอล +%.1f%%" % (float(bonus.crit) * 100.0))
	if bonus.has("speed"):
		parts.append("ความเร็ว +%d%%" % int(round(float(bonus.speed) * 100.0)))
	return "  ".join(parts)


## The newest step a hero with [param adv] steps has reached, or {}.
static func current(class_id: StringName, adv: int) -> Dictionary:
	return step(class_id, adv - 1)


## Name of tier 1..6 of a class: the class, then the four steps and the God step
## (ASCEND_TIER names the Ascension).
static func tier_name(class_id: StringName, tier: int) -> String:
	if tier <= 1:
		return String(ClassData.get_class_data(class_id).name)
	if tier >= ASCEND_TIER:
		return String(ascend_step(class_id).get("name", "?"))
	return String(step(class_id, tier - 2).get("name", "?"))


## Level at which tier 2..5 (steps 1..4) is reached.
static func tier_level(tier: int) -> int:
	return int(TIER_LEVELS[clampi(tier - 2, 0, TIER_LEVELS.size() - 1)])


## Attribute bonuses (STR/INT/DEX/VIT) of all steps reached.
static func attr_bonus(class_id: StringName, adv: int) -> Dictionary:
	var total := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	for i in clampi(adv, 0, MAX_ADV):
		var attrs: Dictionary = step(class_id, i).get("attrs", {})
		for key in attrs:
			total[key] += int(attrs[key])
	return total


static func attr_text(attrs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in ["str", "int", "dex", "vit"]:
		if int(attrs.get(key, 0)) > 0:
			parts.append("%s +%d" % [String(key).to_upper(), int(attrs[key])])
	return "  ".join(parts)


## How many steps a companion of [param level] has taken (the level steps only:
## the God step also needs ★300, which companions and AI players do not take).
static func adv_for_level(level: int) -> int:
	var n := 0
	for i in LEGEND_ADV:
		if level >= int(TIER_LEVELS[i]):
			n += 1
	return n


## The steps a world player has taken (WorldPlayers.profile): the level steps, and at
## Lv.100 with ★300 (GOD_STARS) the God step too (the fee is earned along the way). ★500
## (ASCEND_STARS) alone is not the Ascension: like the hero, a world player must pass the
## trial (บททดสอบเทวาลัย), so [param ascended] is whether it has (WorldPlayers.ascended_at /
## ascended_sheet: its own tries against the guardian, read off its seeds and its play,
## the same on every client). Without it a ★500 player stays a God.
static func adv_for(level: int, stars: int, ascended := false) -> int:
	if level >= 100 and stars >= ASCEND_STARS and ascended:
		return ASCEND_ADV
	if level >= 100 and stars >= GOD_STARS:
		return GOD_ADV
	return adv_for_level(level)


## Base class data with every advancement step applied (name, bonuses).
## [code]skills[/code] is the whole class pool; the hero swaps in its bar loadout.
static func resolve(class_id: StringName, adv := 0) -> Dictionary:
	var base: Dictionary = ClassData.CLASSES.get(class_id, ClassData.CLASSES[&"warrior"])
	adv = clampi(adv, 0, MAX_ADV)
	var key := "%s|%d" % [class_id, adv]
	if _cache.has(key):
		return _cache[key]
	var data := base.duplicate()
	data["skills"] = ClassData.pool(class_id)
	if adv > 0 and PATHS.has(class_id):
		var hp := float(base.hp_mult)
		var mp := float(base.mp_mult)
		var atk := 1.0
		var def := 1.0
		var crit := 0.0
		var speed := 0.0
		for i in adv:
			var bonus: Dictionary = step(class_id, i).bonus
			hp *= float(bonus.get("hp", 1.0))
			mp *= float(bonus.get("mp", 1.0))
			atk *= float(bonus.get("atk", 1.0))
			def *= float(bonus.get("def", 1.0))
			crit += float(bonus.get("crit", 0.0))
			speed += float(bonus.get("speed", 0.0))
		var latest := current(class_id, adv)
		data["base_name"] = base.name
		data["name"] = latest.name
		data["title"] = latest.title
		data["desc"] = latest.desc
		data["color"] = latest.color
		data["adv"] = adv
		data["hp_mult"] = hp
		data["mp_mult"] = mp
		data["atk_mult"] = atk
		data["def_mult"] = def
		data["crit_bonus"] = crit
		data["speed_bonus"] = speed
	_cache[key] = data
	return data


static var _cache: Dictionary = {}
