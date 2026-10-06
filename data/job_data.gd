class_name JobData
extends RefCounted
## Advanced jobs. Each class line has one path: line (Lv.10) -> advanced job
## (Lv.20) -> master (Lv.40), changed at the Job Master in the village. A job renames the hero and adds stat bonuses
## (skills come from the class pool, see ClassData).
##
## Bonus keys: hp, mp, atk, def (multipliers), crit (added), speed (fraction added).

const JOB_LEVEL := 20
const JOB_COST := 1500
const MASTER_LEVEL := 40
const MASTER_COST := 6000

const JOBS := {
	&"warrior_2": {
		"class": &"warrior", "name": "นักดาบขั้นสูง", "title": "อัศวินผู้กล้า", "color": Color("ffb04a"),
		"desc": "นักดาบที่ผ่านการฝึกขั้นสูง ทนทานและแข็งแกร่งขึ้น ใช้สกิลเลเวล 20-39 ได้",
		"bonus": {"hp": 1.2, "def": 1.1, "atk": 1.1},
	},
	&"archer_2": {
		"class": &"archer", "name": "นักธนูขั้นสูง", "title": "พรานตาเหยี่ยว", "color": Color("5affc0"),
		"desc": "นักธนูที่ยิงแม่นและว่องไวขึ้น คริติคอลสูง ใช้สกิลเลเวล 20-39 ได้",
		"bonus": {"atk": 1.1, "crit": 0.05, "speed": 0.05},
	},
	&"mage_2": {
		"class": &"mage", "name": "นักเวทย์ขั้นสูง", "title": "จอมเวทธาตุ", "color": Color("b79bff"),
		"desc": "นักเวทย์ที่ควบคุมธาตุได้ลึกซึ้งขึ้น พลังเวทและ MP เพิ่มมาก ใช้สกิลเลเวล 20-39 ได้",
		"bonus": {"atk": 1.15, "mp": 1.2, "def": 1.05},
	},
	&"priest_2": {
		"class": &"priest", "name": "นักบวชขั้นสูง", "title": "ผู้รักษาแห่งแสง", "color": Color("fff0a0"),
		"desc": "นักบวชที่อึดและรักษาเก่งขึ้น แสงศักดิ์สิทธิ์แรงขึ้น ใช้สกิลเลเวล 20-39 ได้",
		"bonus": {"hp": 1.15, "def": 1.1, "mp": 1.1, "atk": 1.1},
	},
}


## Third advancement at Lv.40: renames the hero again and boosts the bonuses. Same
## bonus keys as the jobs (multipliers, crit/speed added).
const MASTERS := {
	&"warrior_2": {"name": "ปรมาจารย์นักดาบ", "title": "ราชันย์แห่งสนามรบ", "bonus": {"hp": 1.12, "def": 1.1, "atk": 1.12, "crit": 0.03}},
	&"archer_2": {"name": "ปรมาจารย์นักธนู", "title": "ลูกศรที่ไม่เคยพลาด", "bonus": {"atk": 1.12, "crit": 0.05, "speed": 0.04}},
	&"mage_2": {"name": "ปรมาจารย์นักเวทย์", "title": "ผู้หยุดกาลเวลา", "bonus": {"atk": 1.14, "mp": 1.12, "def": 1.05}},
	&"priest_2": {"name": "ปรมาจารย์นักบวช", "title": "แสงสว่างแห่งความหวัง", "bonus": {"hp": 1.12, "def": 1.08, "mp": 1.1, "atk": 1.1}},
}


## Saves from the branching jobs (paladin, pyromancer...) move to the single path.
static func migrate_job(class_id: StringName, job_id: StringName) -> StringName:
	if job_id == &"" or JOBS.has(job_id):
		return job_id
	return StringName("%s_2" % class_id)


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
