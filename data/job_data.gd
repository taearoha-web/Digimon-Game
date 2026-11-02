class_name JobData
extends RefCounted
## Advancement path of every class line. After the line is chosen at Lv.10 a hero
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

const TIER_LEVELS := [20, 40, 60, 80, 100]
const TIER_COSTS := [1500, 6000, 20000, 60000, 1000000]
const TIER_SKILL_POINTS := [2, 3, 4, 5, 6]
const MAX_ADV := 5
## The steps a hero takes by level alone (Lv.20/40/60/80); companions and AI players stop here.
const LEGEND_ADV := 4
## The God step (adv 5) and the stars it needs.
const GOD_ADV := 5
const GOD_STARS := 300
## How much bigger the God step is than the legend step: each multiplier's gain
## (atk 1.18 -> 1 + 0.18 * 1.4 = 1.252), each added crit / speed (x1.4), and each
## STR/INT/DEX/VIT bonus (x1.5).
const GOD_SCALE := 1.4
const GOD_ATTR_SCALE := 1.5
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
			"desc": "บัญชาการทั้งทีม ปล่อยเพลิงและพายุพลาสมา ใช้สกิลเลเวล 40-59 ได้",
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
}


## Step [param index] (0..3, or 4 for the God step) of a class path, or {}.
static func step(class_id: StringName, index: int) -> Dictionary:
	if index == GOD_ADV - 1:
		return god_step(class_id)
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


## "เทพเจ้าแห่ง" + the class's Thai name, e.g. เทพเจ้าแห่งดาร์กลอร์ด.
static func god_name(class_id: StringName) -> String:
	return "เทพเจ้าแห่ง" + String(ClassData.get_class_data(class_id).name)


## True once a hero with [param adv] steps is a God.
static func is_god(adv: int) -> bool:
	return adv >= GOD_ADV


## Stars the step after [param adv] steps needs (0 for the level steps).
static func step_stars(adv: int) -> int:
	return GOD_STARS if adv == GOD_ADV - 1 else 0


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


## Name of tier 0..6 of a class: Vagabond, line, then the four steps and the God step.
static func tier_name(class_id: StringName, tier: int) -> String:
	if tier <= 0:
		return String(ClassData.get_class_data(ClassData.START).name)
	if tier == 1:
		return String(ClassData.get_class_data(class_id).name)
	return String(step(class_id, tier - 2).get("name", "?"))


## Level at which tier 2..5 (steps 1..4) is reached.
static func tier_level(tier: int) -> int:
	return int(TIER_LEVELS[clampi(tier - 2, 0, MAX_ADV - 1)])


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
