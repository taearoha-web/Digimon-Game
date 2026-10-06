class_name JobData
extends RefCounted
## Advanced jobs. At level 20 each class line can pick one of two branches from
## the Job Master in the village. A job renames the hero and adds stat bonuses
## (skills come from the class pool, see ClassData).
##
## Bonus keys: hp, mp, atk, def (multipliers), crit (added), speed (fraction added).

const JOB_LEVEL := 20
const JOB_COST := 1500
const MASTER_LEVEL := 40
const MASTER_COST := 6000

const JOBS := {
	&"paladin": {
		"class": &"warrior", "name": "พาลาดิน", "title": "อัศวินแสงศักดิ์สิทธิ์", "color": Color("ffe27a"),
		"desc": "ทนทานที่สุด ฟันด้วยแสงศักดิ์สิทธิ์ ฟื้นพลังจากการต่อสู้ เหมาะกับการลุยยาวๆ",
		"bonus": {"hp": 1.3, "def": 1.25, "atk": 0.95},
	},
	&"berserker": {
		"class": &"warrior", "name": "เบอร์เซิร์กเกอร์", "title": "นักรบคลั่งเลือด", "color": Color("ff4a3a"),
		"desc": "พลังโจมตีสูงลิ่ว ฟันโหดและทุบพื้นให้ศัตรูมึนงง แลกกับเกราะที่บางลง",
		"bonus": {"hp": 1.1, "atk": 1.22, "def": 0.9},
	},
	&"sniper": {
		"class": &"archer", "name": "สไนเปอร์", "title": "ผู้พิฆาตตาเหยี่ยว", "color": Color("ffd84a"),
		"desc": "ยิงไกลและแม่นยำ คริติคอลสูง ดอกเดียวก็ล้มศัตรูได้",
		"bonus": {"atk": 1.12, "crit": 0.08, "hp": 0.95},
	},
	&"stormer": {
		"class": &"archer", "name": "พรานพายุ", "title": "นักล่าสายลม", "color": Color("5affc0"),
		"desc": "ยิงเป็นห่าฝนและวิ่งไวดั่งลม ตีหมู่และหนีเก่ง",
		"bonus": {"atk": 1.05, "speed": 0.1, "hp": 1.05},
	},
	&"pyromancer": {
		"class": &"mage", "name": "จอมเวทเพลิง", "title": "ผู้เผาผลาญนรก", "color": Color("ff6a2a"),
		"desc": "เวทไฟทำลายล้าง เผาไหม้ศัตรูทั้งฝูง พลังโจมตีสูงสุดในหมู่จอมเวท",
		"bonus": {"atk": 1.2, "mp": 1.1, "hp": 0.95},
	},
	&"cryomancer": {
		"class": &"mage", "name": "จอมเวทน้ำแข็ง", "title": "ราชินีหิมะ", "color": Color("7fe3ff"),
		"desc": "เวทน้ำแข็งและสายฟ้า ทำให้ศัตรูช้าลงและตีหมู่เป็นวงกว้าง ควบคุมสนามรบได้ดี",
		"bonus": {"atk": 1.1, "mp": 1.25, "def": 1.1},
	},
	&"saint": {
		"class": &"priest", "name": "นักบุญ", "title": "ผู้ปกป้องผู้อ่อนแอ", "color": Color("9fffc0"),
		"desc": "สายรักษาและอึด ฟื้นฟูตัวเองได้มหาศาล เสริมเกราะให้ตัวเอง ลุยเดี่ยวได้นานที่สุด",
		"bonus": {"hp": 1.25, "def": 1.15, "mp": 1.1},
	},
	&"inquisitor": {
		"class": &"priest", "name": "ผู้พิพากษา", "title": "คมดาบแห่งแสง", "color": Color("ffb04a"),
		"desc": "สายโจมตีแสงศักดิ์สิทธิ์ พิพากษาศัตรูด้วยแสงสวรรค์ แรงที่สุดในหมู่พรีสต์",
		"bonus": {"atk": 1.2, "hp": 1.0},
	},
}


## Third advancement at Lv.40: renames the hero again and boosts the bonuses. Same bonus keys as the jobs (multipliers, crit/speed added).
const MASTERS := {
	&"paladin": {"name": "โฮลีไนท์", "title": "ผู้พิทักษ์แห่งสวรรค์", "bonus": {"hp": 1.15, "def": 1.12, "atk": 1.08}},
	&"berserker": {"name": "จอมสังหารคลั่ง", "title": "มัจจุราชสนามรบ", "bonus": {"hp": 1.1, "atk": 1.15, "crit": 0.05}},
	&"sniper": {"name": "ผู้พิฆาตเงา", "title": "ลูกศรที่ไม่เคยพลาด", "bonus": {"atk": 1.15, "crit": 0.08}},
	&"stormer": {"name": "จอมพรานพายุ", "title": "เจ้าแห่งสายลม", "bonus": {"atk": 1.1, "speed": 0.08, "hp": 1.1}},
	&"pyromancer": {"name": "ราชาเพลิงนรก", "title": "ผู้เผาโลก", "bonus": {"atk": 1.15, "mp": 1.1}},
	&"cryomancer": {"name": "ราชินีน้ำแข็งนิรันดร์", "title": "ผู้หยุดกาลเวลา", "bonus": {"atk": 1.12, "mp": 1.15, "def": 1.1}},
	&"saint": {"name": "พระผู้ให้ชีวิต", "title": "แสงสว่างแห่งความหวัง", "bonus": {"hp": 1.2, "def": 1.1, "mp": 1.1}},
	&"inquisitor": {"name": "ผู้พิพากษาสูงสุด", "title": "เสียงตัดสินแห่งสวรรค์", "bonus": {"atk": 1.15, "crit": 0.05}},
}


static func get_job(id: StringName) -> Dictionary:
	return JOBS.get(id, {})


static func jobs_for(class_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in JOBS:
		if JOBS[id]["class"] == class_id:
			out.append(id)
	return out


## Base class data with the job applied (name, bonuses) and, when
## [param master] is set, the Lv.40 upgrade (renamed, stronger bonuses).
## [code]skills[/code] is the whole class pool; the hero swaps in its bar loadout.
static func resolve(class_id: StringName, job_id: StringName, master := false) -> Dictionary:
	var base: Dictionary = ClassData.CLASSES.get(class_id, ClassData.CLASSES[&"warrior"])
	var job := get_job(job_id)
	var key := "%s|%s|%s" % [class_id, job_id, master]
	if _cache.has(key):
		return _cache[key]
	var data := base.duplicate()
	data["skills"] = ClassData.pool(class_id)
	if job.is_empty() or job["class"] != class_id:
		_cache[key] = data
		return data
	master = master and MASTERS.has(job_id)
	var bonus: Dictionary = job.bonus
	data["base_name"] = base.name
	data["name"] = job.name
	data["title"] = job.title
	data["desc"] = job.desc
	data["color"] = job.color
	data["job"] = job_id
	data["hp_mult"] = float(base.hp_mult) * float(bonus.get("hp", 1.0))
	data["mp_mult"] = float(base.mp_mult) * float(bonus.get("mp", 1.0))
	data["atk_mult"] = float(bonus.get("atk", 1.0))
	data["def_mult"] = float(bonus.get("def", 1.0))
	data["crit_bonus"] = float(bonus.get("crit", 0.0))
	data["speed_bonus"] = float(bonus.get("speed", 0.0))
	if master:
		var m: Dictionary = MASTERS[job_id]
		var mb: Dictionary = m.bonus
		data["name"] = m.name
		data["title"] = m.title
		data["master"] = true
		data["hp_mult"] = float(data.hp_mult) * float(mb.get("hp", 1.0))
		data["mp_mult"] = float(data.mp_mult) * float(mb.get("mp", 1.0))
		data["atk_mult"] = float(data.atk_mult) * float(mb.get("atk", 1.0))
		data["def_mult"] = float(data.def_mult) * float(mb.get("def", 1.0))
		data["crit_bonus"] = float(data.crit_bonus) + float(mb.get("crit", 0.0))
		data["speed_bonus"] = float(data.speed_bonus) + float(mb.get("speed", 0.0))
	_cache[key] = data
	return data


static var _cache: Dictionary = {}
