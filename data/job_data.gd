class_name JobData
extends RefCounted
## Second-class jobs. At level 15 each class can pick one of two branches from
## the Job Master in the village. A job renames the hero, adds stat bonuses and
## replaces the first two skills with stronger ones.
##
## Bonus keys: hp, mp, atk, def (multipliers), crit (added), speed (fraction added).

const JOB_LEVEL := 15
const JOB_COST := 1500
const MASTER_LEVEL := 30
const MASTER_COST := 6000

const JOBS := {
	&"paladin": {
		"class": &"warrior", "name": "พาลาดิน", "title": "อัศวินแสงศักดิ์สิทธิ์", "color": Color("ffe27a"),
		"desc": "ทนทานที่สุด ฟันด้วยแสงศักดิ์สิทธิ์ ฟื้นพลังจากการต่อสู้ เหมาะกับการลุยยาวๆ",
		"bonus": {"hp": 1.3, "def": 1.25, "atk": 0.95},
		"skills": [
			{"id": "holy_blade", "name": "ฟันแสงสวรรค์", "desc": "ดาบเรืองแสงฟันแรงๆ และฟื้นฟู HP 6%", "level": 15, "mp": 12, "cd": 4.0,
				"shape": "single", "mult": 3.6, "range": 2.8, "anim": "1H_Melee_Attack_Chop", "hit_delay": 0.25,
				"fx": {"heal": 0.06}, "color": Color("fff0a0"), "vfx": &"light", "icon": "sword"},
			{"id": "divine_wall", "name": "ปราการศักดิ์สิทธิ์", "desc": "DEF +60% นาน 12 วินาที และฟื้นฟู HP 20%", "level": 15, "mp": 20, "cd": 20.0,
				"shape": "self", "anim": "Cheer", "hit_delay": 0.2,
				"fx": {"heal": 0.2, "buff": {"def": 0.6, "secs": 12.0}}, "color": Color("ffe27a"), "vfx": &"aura", "icon": "shield"},
		],
	},
	&"berserker": {
		"class": &"warrior", "name": "เบอร์เซิร์กเกอร์", "title": "นักรบคลั่งเลือด", "color": Color("ff4a3a"),
		"desc": "พลังโจมตีสูงลิ่ว ฟันโหดและทุบพื้นให้ศัตรูมึนงง แลกกับเกราะที่บางลง",
		"bonus": {"hp": 1.1, "atk": 1.22, "def": 0.9},
		"skills": [
			{"id": "rage_slash", "name": "ฟันคลั่ง", "desc": "ฟันหนักมากใส่ศัตรูตัวเดียว", "level": 15, "mp": 12, "cd": 4.0,
				"shape": "single", "mult": 4.6, "range": 2.8, "anim": "1H_Melee_Attack_Chop", "hit_delay": 0.25,
				"color": Color("ff5a3a"), "vfx": &"slash", "icon": "sword"},
			{"id": "earthquake", "name": "แผ่นดินไหว", "desc": "ทุบพื้น ศัตรูรอบตัวบาดเจ็บและมึนงง 1.5 วินาที", "level": 15, "mp": 22, "cd": 12.0,
				"shape": "burst", "mult": 3.0, "radius": 5.5, "anim": "2H_Melee_Attack_Spin", "hit_delay": 0.35,
				"fx": {"stun": 1.5}, "color": Color("ff8a4a"), "vfx": &"impact", "icon": "spin"},
		],
	},
	&"sniper": {
		"class": &"archer", "name": "สไนเปอร์", "title": "ผู้พิฆาตตาเหยี่ยว", "color": Color("ffd84a"),
		"desc": "ยิงไกลและแม่นยำ คริติคอลสูง ดอกเดียวก็ล้มศัตรูได้",
		"bonus": {"atk": 1.12, "crit": 0.08, "hp": 0.95},
		"skills": [
			{"id": "piercing_shot", "name": "ยิงทะลวงเกราะ", "desc": "ยิงแรงมากจากระยะไกล", "level": 15, "mp": 14, "cd": 5.0,
				"shape": "single", "mult": 5.0, "range": 14.0, "anim": "2H_Ranged_Shoot", "hit_delay": 0.2, "projectile": true,
				"color": Color("ffe27a"), "vfx": &"impact", "icon": "arrow"},
			{"id": "eagle_eye", "name": "ตาเหยี่ยว", "desc": "ATK +25% คริติคอล +30% นาน 14 วินาที", "level": 15, "mp": 16, "cd": 24.0,
				"shape": "self", "anim": "Cheer", "hit_delay": 0.2,
				"fx": {"buff": {"atk": 0.25, "crit": 0.3, "secs": 14.0}}, "color": Color("ffd84a"), "vfx": &"aura", "icon": "boots"},
		],
	},
	&"stormer": {
		"class": &"archer", "name": "พรานพายุ", "title": "นักล่าสายลม", "color": Color("5affc0"),
		"desc": "ยิงเป็นห่าฝนและวิ่งไวดั่งลม ตีหมู่และหนีเก่ง",
		"bonus": {"atk": 1.05, "speed": 0.1, "hp": 1.05},
		"skills": [
			{"id": "storm_volley", "name": "พายุลูกศร", "desc": "ยิง 5 ดอกพร้อมกันใส่ศัตรูใกล้เคียง", "level": 15, "mp": 18, "cd": 7.0,
				"shape": "fan", "mult": 1.8, "range": 12.0, "hits": 5, "anim": "2H_Ranged_Shoot", "hit_delay": 0.2, "projectile": true,
				"color": Color("8fffd0"), "vfx": &"leaf", "icon": "triple"},
			{"id": "gale_burst", "name": "ลมพัดกระจาย", "desc": "คลื่นลมรอบตัว ศัตรูช้าลง 3 วินาที", "level": 15, "mp": 20, "cd": 11.0,
				"shape": "burst", "mult": 2.6, "radius": 5.5, "anim": "2H_Ranged_Shooting", "hit_delay": 0.4,
				"fx": {"slow": 3.0}, "color": Color("7affd0"), "vfx": &"wind", "icon": "spin"},
		],
	},
	&"pyromancer": {
		"class": &"mage", "name": "จอมเวทเพลิง", "title": "ผู้เผาผลาญนรก", "color": Color("ff6a2a"),
		"desc": "เวทไฟทำลายล้าง เผาไหม้ศัตรูทั้งฝูง พลังโจมตีสูงสุดในหมู่จอมเวท",
		"bonus": {"atk": 1.2, "mp": 1.1, "hp": 0.95},
		"skills": [
			{"id": "inferno", "name": "พลุเพลิงนรก", "desc": "ระเบิดไฟใส่พื้นที่ ติดไฟแรง 5 วินาที", "level": 15, "mp": 24, "cd": 8.0,
				"shape": "blast", "mult": 3.4, "range": 11.0, "radius": 4.2, "anim": "Spellcast_Long", "hit_delay": 0.7,
				"fx": {"burn": [0.4, 5.0]}, "color": Color("ff6a2a"), "vfx": &"fireball", "icon": "fire"},
			{"id": "sea_of_flame", "name": "ทะเลเพลิง", "desc": "คลื่นไฟรอบตัวเผาศัตรูทุกตัว", "level": 15, "mp": 30, "cd": 14.0,
				"shape": "burst", "mult": 3.2, "radius": 6.0, "anim": "Spellcast_Raise", "hit_delay": 0.45,
				"fx": {"burn": [0.3, 5.0]}, "color": Color("ff8a3a"), "vfx": &"fireball", "icon": "fire"},
		],
	},
	&"cryomancer": {
		"class": &"mage", "name": "จอมเวทน้ำแข็ง", "title": "ราชินีหิมะ", "color": Color("7fe3ff"),
		"desc": "เวทน้ำแข็งและสายฟ้า ทำให้ศัตรูช้าลงและตีหมู่เป็นวงกว้าง ควบคุมสนามรบได้ดี",
		"bonus": {"atk": 1.1, "mp": 1.25, "def": 1.1},
		"skills": [
			{"id": "ice_spear", "name": "หอกน้ำแข็ง", "desc": "หอกน้ำแข็งแรงๆ ศัตรูช้าลง 3 วินาที", "level": 15, "mp": 16, "cd": 4.0,
				"shape": "single", "mult": 4.0, "range": 11.0, "anim": "Spellcast_Shoot", "hit_delay": 0.3, "projectile": true,
				"fx": {"slow": 3.0}, "color": Color("7fe3ff"), "vfx": &"frost", "icon": "ice"},
			{"id": "blizzard", "name": "พายุหิมะ", "desc": "พายุหิมะถล่มพื้นที่กว้าง ศัตรูช้าลงมาก", "level": 15, "mp": 30, "cd": 14.0,
				"shape": "blast", "mult": 3.4, "range": 11.0, "radius": 5.5, "anim": "Spellcast_Long", "hit_delay": 0.8,
				"fx": {"slow": 4.0}, "color": Color("aaf0ff"), "vfx": &"frost", "icon": "ice"},
		],
	},
	&"saint": {
		"class": &"priest", "name": "นักบุญ", "title": "ผู้ปกป้องผู้อ่อนแอ", "color": Color("9fffc0"),
		"desc": "สายรักษาและอึด ฟื้นฟูตัวเองได้มหาศาล เสริมเกราะให้ตัวเอง ลุยเดี่ยวได้นานที่สุด",
		"bonus": {"hp": 1.25, "def": 1.15, "mp": 1.1},
		"skills": [
			{"id": "divine_heal", "name": "รักษาศักดิ์สิทธิ์", "desc": "ฟื้นฟู HP 65% และ DEF +30% นาน 10 วินาที", "level": 15, "mp": 26, "cd": 14.0,
				"shape": "self", "anim": "Spellcast_Raise", "hit_delay": 0.3,
				"fx": {"heal": 0.65, "buff": {"def": 0.3, "secs": 10.0}}, "color": Color("6dff9a"), "vfx": &"heal", "icon": "heal"},
			{"id": "sanctuary", "name": "เขตศักดิ์สิทธิ์", "desc": "คลื่นแสงรอบตัวทำร้ายศัตรู และฟื้นฟู HP 20%", "level": 15, "mp": 28, "cd": 12.0,
				"shape": "burst", "mult": 2.6, "radius": 6.0, "anim": "Spellcast_Raise", "hit_delay": 0.4,
				"fx": {"heal": 0.2}, "color": Color("c9ffd8"), "vfx": &"light", "icon": "nova"},
		],
	},
	&"inquisitor": {
		"class": &"priest", "name": "ผู้พิพากษา", "title": "คมดาบแห่งแสง", "color": Color("ffb04a"),
		"desc": "สายโจมตีแสงศักดิ์สิทธิ์ พิพากษาศัตรูด้วยแสงสวรรค์ แรงที่สุดในหมู่พรีสต์",
		"bonus": {"atk": 1.2, "hp": 1.0},
		"skills": [
			{"id": "judgement", "name": "คำพิพากษา", "desc": "แสงสวรรค์ผ่าลงใส่ศัตรู ทำให้มึนงง 1.5 วินาที", "level": 15, "mp": 18, "cd": 5.0,
				"shape": "single", "mult": 4.4, "range": 10.0, "anim": "Spellcast_Shoot", "hit_delay": 0.3, "projectile": true,
				"fx": {"stun": 1.5}, "color": Color("ffd27a"), "vfx": &"light", "icon": "light"},
			{"id": "holy_rain", "name": "ฝนแสงสวรรค์", "desc": "ลำแสงนับสิบถล่มลงมาเป็นวงกว้าง", "level": 15, "mp": 32, "cd": 14.0,
				"shape": "blast", "mult": 3.6, "range": 11.0, "radius": 5.5, "anim": "Spellcast_Long", "hit_delay": 0.8,
				"color": Color("fff0a0"), "vfx": &"light", "icon": "nova"},
		],
	},
}


## Third advancement at Lv.30: renames the hero again, boosts the bonuses and
## replaces skills 3 and 4. Same bonus keys as the jobs (multipliers, crit/speed added).
const MASTERS := {
	&"paladin": {"name": "โฮลีไนท์", "title": "ผู้พิทักษ์แห่งสวรรค์", "bonus": {"hp": 1.15, "def": 1.12, "atk": 1.08},
		"skills": [
			{"id": "heaven_blade", "name": "ดาบสวรรค์ตกลง", "desc": "ดาบแสงถล่มศัตรูรอบตัว ฟื้นฟู HP 10%", "level": 30, "mp": 34, "cd": 12.0,
				"shape": "burst", "mult": 4.2, "radius": 6.0, "anim": "2H_Melee_Attack_Spin", "hit_delay": 0.4,
				"fx": {"heal": 0.1}, "color": Color("fff0a0"), "vfx": &"light", "icon": "spin"},
			{"id": "holy_wings", "name": "ปีกศักดิ์สิทธิ์", "desc": "ATK +30% DEF +50% นาน 20 วิ และฟื้นฟู HP 30%", "level": 30, "mp": 38, "cd": 32.0,
				"shape": "self", "anim": "Cheer", "hit_delay": 0.2,
				"fx": {"heal": 0.3, "buff": {"atk": 0.3, "def": 0.5, "secs": 20.0}}, "color": Color("ffe27a"), "vfx": &"aura", "icon": "roar"}]},
	&"berserker": {"name": "จอมสังหารคลั่ง", "title": "มัจจุราชสนามรบ", "bonus": {"hp": 1.1, "atk": 1.15, "crit": 0.05},
		"skills": [
			{"id": "blood_storm", "name": "พายุเลือด", "desc": "พายุคมดาบถล่มรอบตัว ศัตรูมึนงง 1 วินาที", "level": 30, "mp": 36, "cd": 12.0,
				"shape": "burst", "mult": 4.8, "radius": 6.5, "anim": "2H_Melee_Attack_Spin", "hit_delay": 0.4,
				"fx": {"stun": 1.0}, "color": Color("ff3a3a"), "vfx": &"slash", "icon": "spin"},
			{"id": "last_rage", "name": "คลั่งสุดขีด", "desc": "ATK +60% คริ +15% วิ่งเร็ว +20% นาน 15 วิ", "level": 30, "mp": 36, "cd": 34.0,
				"shape": "self", "anim": "Cheer", "hit_delay": 0.2,
				"fx": {"buff": {"atk": 0.6, "crit": 0.15, "speed": 0.2, "secs": 15.0}}, "color": Color("ff4a3a"), "vfx": &"aura", "icon": "roar"}]},
	&"sniper": {"name": "ผู้พิฆาตเงา", "title": "ลูกศรที่ไม่เคยพลาด", "bonus": {"atk": 1.15, "crit": 0.08},
		"skills": [
			{"id": "fate_arrow", "name": "ลูกศรพิชิตชะตา", "desc": "ลูกศรเดียวแรงมหาศาลจากระยะไกล", "level": 30, "mp": 36, "cd": 9.0,
				"shape": "single", "mult": 8.5, "range": 16.0, "anim": "2H_Ranged_Shoot", "hit_delay": 0.25, "projectile": true,
				"color": Color("ffe27a"), "vfx": &"impact", "icon": "arrow"},
			{"id": "sky_rain", "name": "ฝนลูกศรสวรรค์", "desc": "ลูกศรนับร้อยถล่มพื้นที่กว้าง", "level": 30, "mp": 40, "cd": 15.0,
				"shape": "blast", "mult": 4.5, "range": 12.0, "radius": 6.0, "anim": "2H_Ranged_Shooting", "hit_delay": 0.6,
				"color": Color("ffd84a"), "vfx": &"leaf", "icon": "rain"}]},
	&"stormer": {"name": "จอมพรานพายุ", "title": "เจ้าแห่งสายลม", "bonus": {"atk": 1.1, "speed": 0.08, "hp": 1.1},
		"skills": [
			{"id": "eight_winds", "name": "พายุศร 8 ทิศ", "desc": "ยิง 8 ดอกพร้อมกัน", "level": 30, "mp": 38, "cd": 10.0,
				"shape": "fan", "mult": 2.4, "range": 13.0, "hits": 8, "anim": "2H_Ranged_Shoot", "hit_delay": 0.2, "projectile": true,
				"color": Color("8fffd0"), "vfx": &"leaf", "icon": "triple"},
			{"id": "killing_wind", "name": "สายลมพิฆาต", "desc": "คลื่นลมกว้างถล่มศัตรู ช้าลง 4 วินาที", "level": 30, "mp": 38, "cd": 13.0,
				"shape": "burst", "mult": 3.8, "radius": 6.5, "anim": "2H_Ranged_Shooting", "hit_delay": 0.4,
				"fx": {"slow": 4.0}, "color": Color("7affd0"), "vfx": &"wind", "icon": "spin"}]},
	&"pyromancer": {"name": "ราชาเพลิงนรก", "title": "ผู้เผาโลก", "bonus": {"atk": 1.15, "mp": 1.1},
		"skills": [
			{"id": "hell_meteor", "name": "อุกกาบาตนรก", "desc": "อุกกาบาตยักษ์ ความเสียหายมหาศาลและติดไฟ", "level": 30, "mp": 55, "cd": 16.0,
				"shape": "blast", "mult": 7.0, "range": 12.0, "radius": 7.0, "anim": "Spellcast_Long", "hit_delay": 1.0,
				"fx": {"burn": [0.5, 6.0]}, "color": Color("ff5a2a"), "vfx": &"fireball", "icon": "meteor"},
			{"id": "flame_armor", "name": "เกราะเพลิง", "desc": "ATK +40% DEF +30% นาน 18 วิ", "level": 30, "mp": 36, "cd": 30.0,
				"shape": "self", "anim": "Spellcasting", "hit_delay": 0.3,
				"fx": {"buff": {"atk": 0.4, "def": 0.3, "secs": 18.0}}, "color": Color("ff7a2a"), "vfx": &"aura", "icon": "fire"}]},
	&"cryomancer": {"name": "ราชินีน้ำแข็งนิรันดร์", "title": "ผู้หยุดกาลเวลา", "bonus": {"atk": 1.12, "mp": 1.15, "def": 1.1},
		"skills": [
			{"id": "absolute_zero", "name": "จุดเยือกแข็งสัมบูรณ์", "desc": "คลื่นน้ำแข็งกว้าง ศัตรูมึนงง 2 วินาที", "level": 30, "mp": 46, "cd": 14.0,
				"shape": "burst", "mult": 5.0, "radius": 7.0, "anim": "Spellcast_Raise", "hit_delay": 0.5,
				"fx": {"stun": 2.0, "slow": 4.0}, "color": Color("bfefff"), "vfx": &"frost", "icon": "ice"},
			{"id": "death_blizzard", "name": "พายุหิมะมรณะ", "desc": "พายุหิมะมหาศาลถล่มพื้นที่กว้าง", "level": 30, "mp": 54, "cd": 16.0,
				"shape": "blast", "mult": 6.0, "range": 12.0, "radius": 7.0, "anim": "Spellcast_Long", "hit_delay": 0.9,
				"fx": {"slow": 5.0}, "color": Color("aaf0ff"), "vfx": &"frost", "icon": "ice"}]},
	&"saint": {"name": "พระผู้ให้ชีวิต", "title": "แสงสว่างแห่งความหวัง", "bonus": {"hp": 1.2, "def": 1.1, "mp": 1.1},
		"skills": [
			{"id": "miracle", "name": "อัศจรรย์ฟื้นคืน", "desc": "ฟื้นฟู HP 100% และ DEF +40% นาน 12 วิ", "level": 30, "mp": 56, "cd": 30.0,
				"shape": "self", "anim": "Spellcast_Raise", "hit_delay": 0.3,
				"fx": {"heal": 1.0, "buff": {"def": 0.4, "secs": 12.0}}, "color": Color("6dff9a"), "vfx": &"heal", "icon": "heal"},
			{"id": "holy_domain", "name": "เขตแดนศักดิ์สิทธิ์", "desc": "แสงสวรรค์รอบตัวทำร้ายศัตรู ฟื้นฟู HP 30%", "level": 30, "mp": 44, "cd": 14.0,
				"shape": "burst", "mult": 3.5, "radius": 7.0, "anim": "Spellcast_Raise", "hit_delay": 0.4,
				"fx": {"heal": 0.3}, "color": Color("d8ffe0"), "vfx": &"light", "icon": "nova"}]},
	&"inquisitor": {"name": "ผู้พิพากษาสูงสุด", "title": "เสียงตัดสินแห่งสวรรค์", "bonus": {"atk": 1.15, "crit": 0.05},
		"skills": [
			{"id": "final_judgement", "name": "แสงพิพากษาทั้งปวง", "desc": "ลำแสงจากสวรรค์ถล่มพื้นที่กว้าง ศัตรูมึนงง 2 วินาที", "level": 30, "mp": 56, "cd": 16.0,
				"shape": "blast", "mult": 7.0, "range": 12.0, "radius": 7.0, "anim": "Spellcast_Long", "hit_delay": 0.9,
				"fx": {"stun": 2.0}, "color": Color("fff0a0"), "vfx": &"light", "icon": "nova"},
			{"id": "light_sword", "name": "ดาบแสงสวรรค์", "desc": "ดาบแสงพุ่งเจาะศัตรูตัวเดียว ทำให้มึนงง", "level": 30, "mp": 34, "cd": 8.0,
				"shape": "single", "mult": 9.0, "range": 11.0, "anim": "Spellcast_Shoot", "hit_delay": 0.3, "projectile": true,
				"fx": {"stun": 1.0}, "color": Color("ffd27a"), "vfx": &"light", "icon": "light"}]},
}


static func get_job(id: StringName) -> Dictionary:
	return JOBS.get(id, {})


static func jobs_for(class_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in JOBS:
		if JOBS[id]["class"] == class_id:
			out.append(id)
	return out


## Base class data with the job applied (name, bonuses, first two skills) and,
## when [param master] is set, the Lv.30 upgrade (renamed, skills 3 and 4).
static func resolve(class_id: StringName, job_id: StringName, master := false) -> Dictionary:
	var base: Dictionary = ClassData.CLASSES.get(class_id, ClassData.CLASSES[&"warrior"])
	var job := get_job(job_id)
	if job.is_empty() or job["class"] != class_id:
		return base
	master = master and MASTERS.has(job_id)
	var key := "%s|%s|%s" % [class_id, job_id, master]
	if _cache.has(key):
		return _cache[key]
	var data := base.duplicate()
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
	var skills: Array = (base.skills as Array).duplicate()
	skills[0] = job.skills[0]
	skills[1] = job.skills[1]
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
		skills[2] = m.skills[0]
		skills[3] = m.skills[1]
	data["skills"] = skills
	_cache[key] = data
	return data


static var _cache: Dictionary = {}
