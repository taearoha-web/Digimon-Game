class_name JobData
extends RefCounted
## Advancement path of every class line. After the line is chosen at Lv.10 a hero
## advances four more times at the Job Master:
##   Lv.20 advanced -> Lv.40 supreme -> Lv.60 master -> Lv.80 legend
## Each step renames the hero, adds stat multipliers and STR/INT/DEX/VIT, and
## opens the next block of skills (see ClassData.skill_tier).
##
## Bonus keys: hp, mp, atk, def (multipliers), crit (added), speed (fraction added).

const TIER_LEVELS := [20, 40, 60, 80]
const TIER_COSTS := [1500, 6000, 20000, 60000]
const TIER_SKILL_POINTS := [2, 3, 4, 5]
const MAX_ADV := 4

## Per class: the four steps in order.
const PATHS := {
	&"warrior": [
		{"name": "นักดาบขั้นสูง", "title": "อัศวินผู้กล้า", "color": Color("ffb04a"),
			"desc": "ฝึกขั้นสูง ทนทานและแข็งแกร่งขึ้น ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"hp": 1.2, "def": 1.1, "atk": 1.1}, "attrs": {"str": 12, "vit": 8, "dex": 3}},
		{"name": "นักดาบขั้นสุดยอด", "title": "ราชันย์แห่งสนามรบ", "color": Color("ff8a3a"),
			"desc": "ถึงขั้นสุดยอด ฟันหนักและอึดทะลุเกราะ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"hp": 1.12, "def": 1.1, "atk": 1.12, "crit": 0.03}, "attrs": {"str": 20, "vit": 14, "dex": 5}},
		{"name": "ปรมาจารย์นักดาบ", "title": "ผู้ครองดาบทั้งปวง", "color": Color("ff5a3a"),
			"desc": "ปรมาจารย์แห่งดาบ พลังล้นเหลือ ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"hp": 1.12, "def": 1.1, "atk": 1.12, "crit": 0.03}, "attrs": {"str": 28, "vit": 20, "dex": 8}},
		{"name": "นักดาบในตำนาน", "title": "วีรบุรุษที่โลกจดจำ", "color": Color("ffe27a"),
			"desc": "ตำนานแห่งนักดาบ สุดยอดของสายดาบ ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"hp": 1.15, "def": 1.12, "atk": 1.15, "crit": 0.04}, "attrs": {"str": 40, "vit": 28, "dex": 12}},
	],
	&"archer": [
		{"name": "นักธนูขั้นสูง", "title": "พรานตาเหยี่ยว", "color": Color("5affc0"),
			"desc": "ยิงแม่นและว่องไวขึ้น คริติคอลสูง ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.1, "crit": 0.05, "speed": 0.05}, "attrs": {"dex": 12, "str": 4, "vit": 5}},
		{"name": "นักธนูขั้นสุดยอด", "title": "ลมพัดพิฆาต", "color": Color("7affd0"),
			"desc": "ยิงไกลเฉียบขาด เรียกสัตว์คู่ใจได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.12, "crit": 0.05, "speed": 0.04}, "attrs": {"dex": 20, "str": 8, "vit": 8}},
		{"name": "ปรมาจารย์นักธนู", "title": "ลูกศรที่ไม่เคยพลาด", "color": Color("ffe27a"),
			"desc": "ปรมาจารย์แห่งธนู ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.12, "crit": 0.05, "speed": 0.04}, "attrs": {"dex": 28, "str": 12, "vit": 11}},
		{"name": "นักธนูในตำนาน", "title": "เทพแห่งสายลม", "color": Color("fff0a0"),
			"desc": "ตำนานแห่งนักธนู ยิงทะลุฟ้า ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.15, "crit": 0.06, "speed": 0.05}, "attrs": {"dex": 40, "str": 16, "vit": 16}},
	],
	&"mage": [
		{"name": "นักเวทย์ขั้นสูง", "title": "จอมเวทธาตุ", "color": Color("b79bff"),
			"desc": "ควบคุมธาตุได้ลึกซึ้งขึ้น พลังเวทและ MP เพิ่มมาก ใช้สกิลเลเวล 20-39 ได้",
			"bonus": {"atk": 1.15, "mp": 1.2, "def": 1.05}, "attrs": {"int": 12, "vit": 5, "dex": 3}},
		{"name": "นักเวทย์ขั้นสุดยอด", "title": "ผู้เรียกวิญญาณ", "color": Color("9a7bff"),
			"desc": "เรียกวิญญาณและดาบเวทมาช่วยรบได้ ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.14, "mp": 1.12, "def": 1.05}, "attrs": {"int": 20, "vit": 8, "dex": 5}},
		{"name": "ปรมาจารย์นักเวทย์", "title": "ผู้หยุดกาลเวลา", "color": Color("7fdcff"),
			"desc": "ปรมาจารย์แห่งเวท พลังทำลายล้างมหาศาล ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.14, "mp": 1.12, "def": 1.05}, "attrs": {"int": 28, "vit": 11, "dex": 8}},
		{"name": "นักเวทย์ในตำนาน", "title": "จอมเวทผู้ล่วงลับกาลเวลา", "color": Color("ffd0ff"),
			"desc": "ตำนานแห่งนักเวทย์ ร่ายเวทผ่าฟ้า ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "mp": 1.15, "def": 1.06}, "attrs": {"int": 40, "vit": 16, "dex": 12}},
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
			"bonus": {"atk": 1.12, "crit": 0.03, "speed": 0.03, "hp": 1.08}, "attrs": {"dex": 11, "str": 5, "vit": 5}},
		{"name": "นักหอกขั้นสุดยอด", "title": "ผู้พิชิตแนวหน้า", "color": Color("6ecbff"),
			"desc": "แทงทะลุหลายตัวเป็นแนวยาว ใช้สกิลเลเวล 40-59 ได้",
			"bonus": {"atk": 1.13, "crit": 0.04, "speed": 0.04, "hp": 1.1}, "attrs": {"dex": 19, "str": 8, "vit": 9}},
		{"name": "ปรมาจารย์นักหอก", "title": "ผู้ครองหอกทะลวงฟ้า", "color": Color("b8e6ff"),
			"desc": "ปรมาจารย์แห่งหอก ใช้สกิลเลเวล 60-79 ได้",
			"bonus": {"atk": 1.13, "crit": 0.04, "speed": 0.04, "hp": 1.1, "def": 1.06}, "attrs": {"dex": 27, "str": 11, "vit": 13}},
		{"name": "นักหอกในตำนาน", "title": "ราชันย์หอกมังกร", "color": Color("ffd84a"),
			"desc": "ตำนานแห่งหอก แทงทะลุฟ้าดิน ใช้สกิลเลเวล 80 ขึ้นไปได้",
			"bonus": {"atk": 1.16, "crit": 0.05, "speed": 0.05, "hp": 1.12, "def": 1.08}, "attrs": {"dex": 39, "str": 16, "vit": 18}},
	],
}


## Step [param index] (0..3) of a class path, or {}.
static func step(class_id: StringName, index: int) -> Dictionary:
	var path: Array = PATHS.get(class_id, [])
	return path[index] if index >= 0 and index < path.size() else {}


## The newest step a hero with [param adv] steps has reached, or {}.
static func current(class_id: StringName, adv: int) -> Dictionary:
	return step(class_id, adv - 1)


## Name of tier 0..5 of a class: Vagabond, line, then the four steps.
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


## How many steps a companion of [param level] has taken.
static func adv_for_level(level: int) -> int:
	var n := 0
	for need in TIER_LEVELS:
		if level >= int(need):
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
