class_name ClassData
extends RefCounted
## Hero classes, chosen when the hero is made (sword, bow, mage, priest, summoner,
## spear, great shield, twin daggers, scepter and raven, lute). Each class has a pool of active skills modelled on
## Priston Tale 1 that unlock by level; four of them go on the skill bar.
##
## Skill fields:
##   shape   single | burst (around the hero) | blast (on the target) | fan (several
##           projectiles) | chain (jumps between monsters) | self
##   mult    damage multiplier on the hero's attack stat
##   range   how close the hero must be to the target (burst ignores it)
##   radius  area radius for burst / blast
##   hits    number of projectiles / chain jumps for fan / chain
##   fx      extra effects: stun, slow (seconds), burn (dps multiplier, seconds),
##           heal (fraction of max HP), buff {atk, def, speed, crit, secs}
##   vfx     BattleVfx preset id; color = main colour of projectiles and rings

## The old starter class (นักเดินทาง, Lv.1-9 before a line was taken at Lv.10). Nobody
## is made one any more: an old save still holding it picks its class once on load
## (Game.change_class); the entry stays so such saves, their items and old online data read.
const LEGACY: StringName = &"vagabond"
## The class used when a stored one is missing or unknown.
const DEFAULT: StringName = &"warrior"
const SLOTS := 8
## The playable classes, chosen on the create screen (also the AI companion classes).
const IDS: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard"]

const CLASSES := {
	&"vagabond": {
		"name": "นักเดินทาง",
		"title": "ผู้ยังไม่เลือกเส้นทาง",
		"badge": "V",
		"desc": "อาชีพเริ่มต้นของเซฟเก่า เลือกอาชีพจริงได้ตอนเข้าเกม",
		"model": "Rogue",
		"weapon": "sword_1handed",
		"offhand": "",
		"weapon_kind": "sword",
		"color": Color("c9b79a"),
		"main": "str",
		"base": {"str": 8, "int": 6, "dex": 8, "vit": 9},
		"gain": {"str": 2, "int": 1, "dex": 1, "vit": 2},
		"hp_mult": 1.1,
		"mp_mult": 1.0,
		"attack": {
			"range": 2.4, "interval": 0.8, "mult": 1.0, "hit_delay": 0.22, "projectile": false, "vfx": &"slash",
			"anims": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop"],
		},
	},
	&"warrior": {
		"name": "สายดาบ",
		"title": "ผู้พิทักษ์แนวหน้า",
		"badge": "W",
		"desc": "สายดาบ — ถือดาบและโล่ เลือดเยอะและทนที่สุด สู้ประชิดตัว สกิลแบบ Fighter/Knight ของ Priston Tale",
		"model": "Knight",
		"weapon": "sword_1handed",
		"offhand": "shield_badge_color",
		"weapon_kind": "sword",
		"color": Color("ff7a45"),
		"main": "str",
		"base": {"str": 12, "int": 3, "dex": 6, "vit": 12},
		"gain": {"str": 3, "int": 0, "dex": 1, "vit": 2},
		"hp_mult": 1.3,
		"mp_mult": 0.7,
		"attack": {
			"range": 2.4, "interval": 0.8, "mult": 1.0, "hit_delay": 0.22, "projectile": false, "vfx": &"slash",
			"anims": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop"],
		},
	},
	&"archer": {
		"name": "สายธนู",
		"title": "ผู้พิฆาตระยะไกล",
		"badge": "A",
		"desc": "สายธนู — ยิงจากระยะไกล คริติคอลสูง สกิลแบบ Archer ของ Priston Tale",
		"model": "Ranger",
		"weapon": "bow_withString",
		"offhand": "",
		"weapon_kind": "bow",
		"color": Color("5ad17a"),
		"main": "dex",
		"base": {"str": 5, "int": 4, "dex": 14, "vit": 8},
		"gain": {"str": 0, "int": 1, "dex": 3, "vit": 1},
		"hp_mult": 1.05,
		"mp_mult": 0.9,
		"base_crit": 0.15,
		"attack": {
			"range": 11.0, "interval": 0.85, "mult": 0.8, "hit_delay": 0.2, "projectile": true, "vfx": &"impact",
			"color": Color("e8e0c0"),
			"anims": ["2H_Ranged_Shoot"],
		},
	},
	&"mage": {
		"name": "นักเวทย์",
		"title": "ผู้ควบคุมธาตุ",
		"badge": "M",
		"desc": "สายเวท — เวทธาตุทรงพลัง ตีหมู่เก่งที่สุด แต่เลือดน้อย สกิลแบบ Magician ของ Priston Tale",
		"model": "Mage",
		"weapon": "staff",
		"offhand": "",
		"weapon_kind": "staff",
		"color": Color("8a6bff"),
		"main": "int",
		"base": {"str": 3, "int": 15, "dex": 6, "vit": 6},
		"gain": {"str": 0, "int": 3, "dex": 1, "vit": 1},
		"hp_mult": 0.9,
		"mp_mult": 1.5,
		"attack": {
			"range": 9.5, "interval": 0.95, "mult": 1.1, "hit_delay": 0.3, "projectile": true, "vfx": &"impact",
			"color": Color("b79bff"),
			"anims": ["Spellcast_Shoot"],
		},
	},
	&"priest": {
		"name": "นักบวช",
		"title": "ผู้รักษาแสงศักดิ์สิทธิ์",
		"badge": "P",
		"desc": "สายบวช — รักษาตัวเองและเสริมพลัง ตีด้วยแสงศักดิ์สิทธิ์ สกิลแบบ Priestess ของ Priston Tale",
		"model": "Mage",
		"weapon": "wand",
		"offhand": "spellbook_closed",
		"weapon_kind": "wand",
		"color": Color("ffe27a"),
		"main": "int",
		"base": {"str": 4, "int": 14, "dex": 5, "vit": 10},
		"gain": {"str": 0, "int": 4, "dex": 1, "vit": 2},
		"hp_mult": 1.0,
		"mp_mult": 1.3,
		"attack": {
			"range": 8.5, "interval": 0.9, "mult": 1.05, "hit_delay": 0.3, "projectile": true, "vfx": &"light",
			"color": Color("fff0a0"),
			"anims": ["Spellcast_Shoot"],
		},
	},
	&"summoner": {
		"name": "ผู้เรียกอสูร",
		"title": "ผู้ผูกพันกับป่าและสัตว์",
		"badge": "S",
		"desc": "สายเรียกอสูร — เรียกสัตว์ป่าและเทพพิทักษ์มาสู้เคียงข้าง เสริมพลังให้ทั้งทีม ตัวเองสู้ด้วยเวทธรรมชาติ ยิ่งเรียกมาก ยิ่งแรง แต่ตัวเองเลือดไม่เยอะ",
		"model": "Barbarian",
		"weapon": "lantern",
		"offhand": "tome",
		"weapon_kind": "lantern",
		"color": Color("7ddc6a"),
		"main": "int",
		"base": {"str": 4, "int": 13, "dex": 6, "vit": 9},
		"gain": {"str": 0, "int": 3, "dex": 1, "vit": 2},
		"hp_mult": 1.0,
		"mp_mult": 1.4,
		"attack": {
			"range": 9.0, "interval": 0.9, "mult": 1.0, "hit_delay": 0.3, "projectile": true, "vfx": &"leaf",
			"color": Color("a8f07a"),
			"anims": ["Spellcast_Shoot"],
		},
	},
	&"lancer": {
		"name": "นักหอก",
		"title": "ผู้พิชิตแนวหน้า",
		"badge": "L",
		"desc": "สายหอก — คล่องแคล่วและรวดเร็ว ตีด้วยหอกยาวระยะกลาง แทงทะลุหลายตัวเป็นแนวตรง ยิ่ง DEX สูงยิ่งแรง (STR เสริมเป็นรอง) สกิลแบบ Pikeman ของ Priston Tale",
		"model": "Knight",
		"weapon": "spear",
		"offhand": "",
		"weapon_kind": "spear",
		"color": Color("6ecbff"),
		"main": "dex",
		"sub": "str",
		"base": {"str": 9, "int": 3, "dex": 13, "vit": 9},
		"gain": {"str": 1, "int": 0, "dex": 3, "vit": 2},
		"hp_mult": 1.15,
		"mp_mult": 0.8,
		"attack": {
			"range": 3.8, "interval": 0.72, "mult": 0.8, "hit_delay": 0.2, "projectile": false, "vfx": &"slash",
			"anims": ["2H_Melee_Attack_Stab", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Stab"],
		},
	},
	&"defender": {
		"name": "สายโล่",
		"title": "กำแพงเหล็กผู้ไม่ถอย",
		"badge": "D",
		"desc": "สายโล่ — ถือโล่ใหญ่ใบเดียวเป็นทั้งเกราะและอาวุธ ฟาดโล่ ทุบพื้น พุ่งชน ขว้างโล่เด้งหลายตัว ยั่วยุศัตรูให้มารุมตัวเองและสะท้อนความเสียหายกลับ ทนที่สุดในเกม (STR ตีแรง VIT เสริมพลังโจมตีเป็นรอง)",
		"model": "Knight",
		"weapon": "greatshield",
		"offhand": "",
		"weapon_kind": "greatshield",
		"color": Color("6fa8dc"),
		"main": "str",
		"sub": "vit",
		"base": {"str": 10, "int": 3, "dex": 4, "vit": 15},
		"gain": {"str": 2, "int": 0, "dex": 1, "vit": 3},
		"hp_mult": 1.45,
		"mp_mult": 0.75,
		"attack": {
			"range": 2.6, "interval": 0.9, "mult": 1.0, "hit_delay": 0.26, "projectile": false, "vfx": &"impact",
			"anims": ["Block_Attack", "2H_Melee_Attack_Slice", "Block_Attack"],
		},
	},
	&"assassin": {
		"name": "นักฆ่า",
		"title": "เงาที่ไม่มีใครเห็น",
		"badge": "A",
		"desc": "นักฆ่า — ถือมีดคู่ หลอมตัวกับเงามืด ตีเร็วที่สุดและคริติคอลแรงที่สุด ก้าวเงาไปหลังศัตรู ปาดคอ ใส่พิษ ขว้างมีดเงา แล้วหายไปในควัน (DEX ตีแรงและคริ)",
		"model": "Rogue",
		"weapon": "dagger",
		"offhand": "dagger",
		"weapon_kind": "dagger",
		"color": Color("9a6bff"),
		"main": "dex",
		"base": {"str": 7, "int": 3, "dex": 13, "vit": 8},
		"gain": {"str": 1, "int": 0, "dex": 3, "vit": 2},
		"hp_mult": 1.05,
		"mp_mult": 0.8,
		"base_crit": 0.15,
		"attack": {
			"range": 2.4, "interval": 0.58, "mult": 0.5, "hit_delay": 0.18, "projectile": false, "vfx": &"slash",
			"anims": ["Dualwield_Melee_Attack_Chop", "1H_Melee_Attack_Stab", "1H_Melee_Attack_Slice_Diagonal"],
		},
	},
	&"darklord": {
		"name": "ดาร์กลอร์ด",
		"title": "จอมราชันผู้บัญชาการ",
		"badge": "K",
		"desc": "ดาร์กลอร์ด — ราชันผู้บัญชาการแบบ MU Online ถือคทาราชันมือหนึ่ง อีกแขนมีอีกาคู่ใจเกาะอยู่ สั่งให้อีกาพุ่งไปโจมตีเองได้ ใช้พลังมืด ไฟ และสายฟ้า สั่นแผ่นดิน เสริมพลังทั้งทีม และวาร์ปเพื่อนทั้งปาร์ตี้มาหาตัวได้ (STR ตีแรง INT เสริมเป็นรอง)",
		"model": "Knight",
		"weapon": "scepter",
		"offhand": "",
		"weapon_kind": "scepter",
		"color": Color("e8b64a"),
		"main": "str",
		"sub": "int",
		"base": {"str": 11, "int": 7, "dex": 5, "vit": 10},
		"gain": {"str": 2, "int": 1, "dex": 1, "vit": 2},
		"hp_mult": 1.2,
		"mp_mult": 1.0,
		"attack": {
			"range": 2.6, "interval": 0.78, "mult": 0.95, "hit_delay": 0.24, "projectile": false, "vfx": &"impact",
			"anims": ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal"],
		},
	},
	&"bard": {
		"name": "นักดนตรี",
		"title": "ผู้บรรเลงพิณพเนจร",
		"badge": "B",
		"desc": "นักดนตรี — ดีดพิณยิงโน้ตใส่ศัตรู บรรเลงเพลงเสริมพลังทั้งปาร์ตี้ (เพลงมีช่องของตัวเอง ไม่แย่งช่องบัฟใคร) ทำให้ศัตรูเกราะแตกและอ่อนแรง กล่อมฝูงศัตรูให้หลับ ปิดม่านด้วยมหาคอนเสิร์ต (INT ตีแรง DEX เสริมเป็นรอง)",
		"model": "Ranger",
		"weapon": "lute",
		"offhand": "",
		"weapon_kind": "lute",
		"color": Color("ff6fb5"),
		"main": "int",
		"sub": "dex",
		"base": {"str": 4, "int": 13, "dex": 8, "vit": 8},
		"gain": {"str": 0, "int": 3, "dex": 1, "vit": 2},
		"hp_mult": 1.05,
		"mp_mult": 1.25,
		"attack": {
			"range": 9.0, "interval": 0.9, "mult": 1.0, "hit_delay": 0.28, "projectile": true, "vfx": &"note",
			"color": Color("ffb3dc"), "anims": ["Spellcast_Shoot"],
		},
	},
}



## Passive skills: always on once the level is reached, +[per] per rank.
## Keys of [bonus]: atk, def, hp, mp (fractions), crit, speed, dodge (added).
const PASSIVES := {
	&"summoner": [
		{"id": "nature_bond", "name": "Nature Bond", "desc": "MP สูงสุด +5% ต่อดาว", "level": 1, "bonus": {"mp": 0.05}},
		{"id": "beast_tamer", "name": "Beast Tamer", "desc": "พลังโจมตี +2% ต่อดาว", "level": 20, "bonus": {"atk": 0.02}},
		{"id": "wild_vitality", "name": "Wild Vitality", "desc": "HP สูงสุด +4% ต่อดาว", "level": 30, "bonus": {"hp": 0.04}},
		{"id": "spirit_ward", "name": "Spirit Ward", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "primal_focus", "name": "Primal Focus", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "gaia_heart", "name": "Gaia's Heart", "desc": "HP +4% และ MP +4% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "mp": 0.04}},
	],
	&"lancer": [
		{"id": "spear_mastery", "name": "Spear Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 1, "bonus": {"atk": 0.025}},
		{"id": "light_footwork", "name": "Light Footwork", "desc": "ความเร็ว +2% และหลบ +0.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.02, "dodge": 0.006}},
		{"id": "keen_point", "name": "Keen Point", "desc": "คริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"crit": 0.015}},
		{"id": "iron_stance", "name": "Iron Stance", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "dragon_fang", "name": "Dragon Fang", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "valkyrie_heart", "name": "Valkyrie's Heart", "desc": "HP +4% และความเร็ว +2% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "speed": 0.02}},
	],
	&"defender": [
		{"id": "shield_mastery", "name": "Shield Mastery", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 1, "bonus": {"def": 0.04}},
		{"id": "iron_body", "name": "Iron Body", "desc": "HP สูงสุด +5% ต่อดาว", "level": 20, "bonus": {"hp": 0.05}},
		{"id": "bash_mastery", "name": "Bash Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 30, "bonus": {"atk": 0.025}},
		{"id": "stalwart", "name": "Stalwart", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "heavy_impact", "name": "Heavy Impact", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "living_fortress", "name": "Living Fortress", "desc": "HP +4% และพลังป้องกัน +3% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "def": 0.03}},
	],
}

static var _pools: Dictionary = {}


# --- Skill lines (the 8-skill classes) ------------------------------------------
## A converted class has exactly 8 active skills, its LINES, each of which EVOLVES with
## level: a line is a list of stages [base, evo1, evo2], every stage a whole skill of
## the pool (own id, name, desc, shape, effects and art). A stage's "level" is when it
## becomes available (base: unlock level, others: evolution level); the hero always
## casts the highest stage its level and job advancement (skill_tier) reach. The bar
## slot and the star rank (Game.profile.skills) belong to the LINE, under its id = the
## base stage's id, so evolving keeps both. The class's data lives in its own file
## (data/skill_lines/<class>.gd: TUNE, LINES, OLD_IDS, PASSIVES, skills()); a class
## not listed here still uses its old pool (_build_pools), TUNE and PASSIVES row.
## Every stage dict also carries "skill_line" (its line id; "line" is a star skill's
## beam flag), "stage" (0, 1, 2) and, when a later stage exists, "next_level" (the
## level it is replaced at).
const LINE_FILES := {
	&"warrior": "res://data/skill_lines/warrior.gd",
	&"archer": "res://data/skill_lines/archer.gd",
	&"mage": "res://data/skill_lines/mage.gd",
	&"priest": "res://data/skill_lines/priest.gd",
	&"assassin": "res://data/skill_lines/assassin.gd",
	&"darklord": "res://data/skill_lines/darklord.gd",
	&"bard": "res://data/skill_lines/bard.gd",
}
static var _line_scripts := {}
## Per converted class: {stage id: line id}.
static var _line_index := {}


static func has_lines(cls: StringName) -> bool:
	return LINE_FILES.has(cls)


static func _lines_of(cls: StringName) -> Script:
	if not _line_scripts.has(cls):
		_line_scripts[cls] = load(String(LINE_FILES[cls]))
	return _line_scripts[cls]


## The line ids of a converted class in bar order ([] for an old-style class).
static func line_ids(cls: StringName) -> Array:
	var out: Array = []
	for stages in line_table(cls):
		out.append(String(stages[0]))
	return out


## The stage ids of each line of a converted class, in bar order.
static func line_table(cls: StringName) -> Array:
	return _lines_of(cls).LINES if has_lines(cls) else []


## The line a skill id belongs to: the line id for a stage of a converted class, else
## the id itself (old-style classes, star skills, unknown ids).
static func line_of(cls: StringName, skill_id: String) -> String:
	if not has_lines(cls):
		return skill_id
	pool(cls)
	return String((_line_index.get(cls, {}) as Dictionary).get(skill_id, skill_id))


## Whether [param skill_id] is a line id (a line's first stage) of a converted class.
static func is_line(cls: StringName, skill_id: String) -> bool:
	return has_lines(cls) and line_ids(cls).has(skill_id)


## The key a skill's star rank is kept under in a profile's "skills": its line id.
static func rank_id(skill: Dictionary) -> String:
	return String(skill.get("skill_line", skill.get("id", "")))


## The stage dicts of a line, first stage first ([] when it is no line).
static func line_stages(cls: StringName, line_id: String) -> Array:
	var out: Array = []
	for stages in line_table(cls):
		if String(stages[0]) == line_id:
			for id in stages:
				out.append(find_skill(cls, String(id)))
	return out


## Whether a hero of [param level] and advancement tier [param tier] has reached a stage.
static func stage_reached(skill: Dictionary, level: int, tier: int) -> bool:
	return level >= int(skill.get("level", 1)) and tier >= skill_tier(skill)


## Whether [param skill] is the stage to cast at [param level] / [param tier]: true for
## every skill that is no line stage, false for a stage a later one has replaced.
## (The stage's own unlock is checked by the caller as before.)
static func is_current(skill: Dictionary, level: int, tier: int) -> bool:
	if not skill.has("next_level"):
		return true
	return not stage_reached({"level": int(skill.next_level)}, level, tier)


## The stage of a line a hero casts at [param level] / [param tier]: the highest one
## reached, the first stage when none is (still locked; its level says when).
static func current_stage(cls: StringName, line_id: String, level: int, tier: int) -> Dictionary:
	var stages := line_stages(cls, line_id)
	if stages.is_empty():
		return find_skill(cls, line_id)
	var at: Dictionary = stages[0]
	for stage in stages:
		if stage_reached(stage, level, tier):
			at = stage
	return at


## The next evolution of a line after the current stage, {} at the last one.
static func next_stage(cls: StringName, line_id: String, level: int, tier: int) -> Dictionary:
	var stages := line_stages(cls, line_id)
	var at := stages.find(current_stage(cls, line_id, level, tier))
	return stages[at + 1] if at >= 0 and at + 1 < stages.size() else {}


## The skills of a class as a hero of [param level] / [param tier] sees them: for a
## converted class the current stage of each of its 8 lines plus the star skills, for
## an old-style class its whole pool. Not filtered by unlock (callers check that).
static func kit(cls: StringName, level: int, tier: int) -> Array:
	if not has_lines(cls):
		return pool(cls)
	var out: Array = []
	for line_id in line_ids(cls):
		out.append(current_stage(cls, line_id, level, tier))
	for skill in pool(cls):
		if skill.has("star"):
			out.append(skill)
	return out


## Whether an AI fighter of [param level] / [param tier] / [param stars] can cast a skill:
## unlocked, its tier and star reached, and the line's current stage.
static func knows(skill: Dictionary, level: int, tier: int, stars: int) -> bool:
	return int(skill.get("level", 1)) <= level and skill_tier(skill) <= tier and int(skill.get("star", 0)) <= stars and is_current(skill, level, tier)


## The passive skills of a class (3 for a converted class).
static func passives(cls: StringName) -> Array:
	if has_lines(cls):
		return _lines_of(cls).PASSIVES
	return PASSIVES.get(cls, [])


## Old save data of a converted class: moves the star ranks of [param skills] (id ->
## rank) to today's lines and passives. A stage's rank goes to its line, an OLD_IDS
## entry to its target (the higher rank stays when several meet); anything else is
## dropped. Returns the skill points to refund: every star above the free first one
## that no longer counts. Star skills and current ids stay as they are (idempotent).
static func migrate_ranks(cls: StringName, skills: Dictionary) -> int:
	if not has_lines(cls):
		return 0
	var keep := {}
	for line_id in line_ids(cls):
		keep[line_id] = true
	for passive in passives(cls):
		keep[String(passive.id)] = true
	for skill in pool(cls):
		if skill.has("star"):
			keep[String(skill.id)] = true
	var old_ids: Dictionary = _lines_of(cls).OLD_IDS
	var refund := 0
	var out := {}
	for id in skills.keys():
		var rank := int(skills[id])
		var to := line_of(cls, String(id))
		if not keep.has(to):
			to = String(old_ids.get(String(id), ""))
		if to == "" or not keep.has(to):
			refund += maxi(0, rank - 1)
			continue
		if out.has(to):
			refund += maxi(0, mini(rank, int(out[to])) - 1)
			out[to] = maxi(rank, int(out[to]))
		else:
			out[to] = rank
	skills.clear()
	skills.merge(out)
	return refund


## An old bar of a converted class: every stage id becomes its line id, star skills
## stay, other ids and repeats are emptied (default_loadout then fills the gaps).
static func migrate_bar(cls: StringName, bar: Array) -> Array:
	var out: Array = []
	for i in SLOTS:
		var id := line_of(cls, String(bar[i])) if i < bar.size() else ""
		var ok := id != "" and not out.has(id) and (is_line(cls, id) or find_skill(cls, id).has("star"))
		out.append(id if ok else "")
	return out


## Builds a converted class's pool from its file and checks its shape.
static func _line_pool(cls: StringName) -> Array:
	var script := _lines_of(cls)
	var skills: Array = script.skills()
	var by_id := {}
	for skill in skills:
		by_id[String(skill.id)] = skill
	var index := {}
	var table: Array = script.LINES
	assert(table.size() == SLOTS, "%s: a class has %d skill lines" % [cls, SLOTS])
	for stages in table:
		var line_id := String(stages[0])
		for i in stages.size():
			var skill: Dictionary = by_id.get(String(stages[i]), {})
			assert(not skill.is_empty(), "%s: line stage %s has no skill" % [cls, stages[i]])
			skill["skill_line"] = line_id
			skill["stage"] = i
			index[String(stages[i])] = line_id
			if i + 1 < stages.size():
				var later: Dictionary = by_id.get(String(stages[i + 1]), {})
				assert(int(later.get("level", 0)) > int(skill.level), "%s: %s must evolve later than %s" % [cls, stages[i + 1], stages[i]])
				skill["next_level"] = int(later.get("level", 0))
	for skill in skills:
		assert(index.has(String(skill.id)), "%s: %s is in no line" % [cls, skill.id])
	_line_index[cls] = index
	# The pool stays in unlock order (stable: same-level stages keep the line order).
	var order := {}
	for i in skills.size():
		order[skills[i].id] = i
	skills.sort_custom(func(a, b): return int(a.level) < int(b.level) or (int(a.level) == int(b.level) and int(order[a.id]) < int(order[b.id])))
	return skills


static func get_class_data(class_id: StringName) -> Dictionary:
	return CLASSES.get(class_id, CLASSES[&"warrior"])


## Every active skill of a class, in unlock order.
static func pool(class_id: StringName) -> Array:
	if _pools.is_empty():
		_build_pools()
	return _pools.get(class_id, _pools[&"warrior"])


## Skill by index in the pool (tests, companions).
static func get_skill(class_id: StringName, index: int) -> Dictionary:
	var skills := pool(class_id)
	return skills[index] if index >= 0 and index < skills.size() else {}


## AI players carry at most AI_BUFF_SKILLS buff skills (a class's signature buff, e.g.
## the Defender's เบ่งเลือด, always among them). Songs and healing skills don't count.
const AI_BUFF_SKILLS := 2


## A skill that grants a buff (not a song). A heal that also buffs (Unbreakable,
## Guardian's Oath...) counts: it takes a buff slot like any other.
static func is_buff_skill(skill: Dictionary) -> bool:
	var fx: Variant = skill.get("fx")
	return fx is Dictionary and (fx as Dictionary).get("buff") is Dictionary and not bool((fx as Dictionary).buff.get("song", false))


## AI healers that keep every heal-that-buffs (beyond the two buff picks), and how much
## their heals give: an AI Priest casts all its heals but each one at half strength, so a
## guild with healers stays beatable.
const AI_ALL_HEALS := [&"priest"]
const AI_HEAL_MULT := {&"priest": 0.5}


static func ai_heal_mult(class_id: StringName) -> float:
	return float(AI_HEAL_MULT.get(class_id, 1.0))


static func _heals_and_buffs(skill: Dictionary) -> bool:
	var fx: Variant = skill.get("fx")
	return fx is Dictionary and (fx as Dictionary).has("heal") and (fx as Dictionary).get("buff") is Dictionary


## A class's signature buff, always in its AI kit and kept up first (เบ่งเลือด).
const SIGNATURE_BUFFS := {&"defender": "brace"}


static func is_signature(skill: Dictionary) -> bool:
	return SIGNATURE_BUFFS.values().has(String(skill.get("id", "")))


## The buff skills an AI player brings (ids), picked per player by [param who] from the
## ones unlocked at [param level]: the class signature first, then a stable pick.
static func ai_buff_kit(class_id: StringName, level: int, who: String) -> Array:
	var open: Array = []
	# A converted class: the current stage of each line, kept by line id (evolving
	# keeps the pick).
	var stage_of := {}
	for skill in kit(class_id, level, 1 + JobData.adv_for_level(level)):
		if is_buff_skill(skill) and int(skill.level) <= level and not skill.has("star"):
			open.append(rank_id(skill))
			stage_of[rank_id(skill)] = skill
	var kit: Array = []
	var signature := String(SIGNATURE_BUFFS.get(class_id, ""))
	if signature != "" and open.has(signature):
		kit.append(signature)
		open.erase(signature)
	# An AI healer keeps every heal that also buffs, on top of its two buff picks.
	var heals: Array = []
	if AI_ALL_HEALS.has(class_id):
		for id in open.duplicate():
			if _heals_and_buffs(stage_of[id]):
				heals.append(id)
				open.erase(id)
	var seed := absi(hash(who))
	while kit.size() < AI_BUFF_SKILLS and not open.is_empty():
		var at := seed % open.size()
		kit.append(open[at])
		open.remove_at(at)
		seed = seed / 7 + 13
	return kit + heals


## Whether an AI player with buff kit [param kit] may cast [param skill].
static func ai_allows(skill: Dictionary, kit: Array) -> bool:
	return not is_buff_skill(skill) or kit.has(rank_id(skill))


static func find_skill(class_id: StringName, skill_id: String) -> Dictionary:
	for skill in pool(class_id):
		if skill.id == skill_id:
			return skill
	return {}


## Advancement tier a skill needs: the class's own skills below Lv.20 need none (0),
## then the four advancements at Lv.20 / 40 / 60 / 80 give tiers 2..5.
static func skill_tier(skill: Dictionary) -> int:
	var level := int(skill.get("level", 1))
	if level < 20:
		return 0
	if level < 40:
		return 2
	if level < 60:
		return 3
	return 4 if level < 80 else 5


## Current tier of a hero: 1 its class, 2..5 after each advancement (0 an old Vagabond save).
static func tier_of(class_id: StringName, adv: int) -> int:
	if class_id == LEGACY:
		return 0
	return 1 + clampi(adv, 0, 4)


## The first unlocked skills fill the empty bar slots (a converted class: its lines).
static func default_loadout(class_id: StringName, level: int, current: Array = [], tier := 3, stars := 0) -> Array:
	var out: Array = []
	for i in SLOTS:
		out.append(String(current[i]) if i < current.size() else "")
	var pool_skills := pool(class_id)
	# A converted class: the bar holds line ids (a stage id becomes its line's) and the
	# star skills; its 8 lines fill the gaps in order.
	if has_lines(class_id):
		out = migrate_bar(class_id, out)
		pool_skills = kit(class_id, 1, 1).filter(func(s): return int(s.get("stage", 0)) == 0)
	# Drop ids that no longer belong to this class or are not unlocked.
	for i in SLOTS:
		var skill := find_skill(class_id, out[i])
		if skill.is_empty() or int(skill.level) > level or skill_tier(skill) > tier or int(skill.get("star", 0)) > stars or out.find(out[i]) != i:
			out[i] = ""
	for skill in pool_skills:
		if int(skill.level) > level or skill_tier(skill) > tier or int(skill.get("star", 0)) > stars or out.has(skill.id):
			continue
		var empty := out.find("")
		if empty < 0:
			break
		out[empty] = skill.id
	return out


# --- skill table -----------------------------------------------------------

## Single-target skills finish an enemy harder than area skills hit each enemy:
## every single-target skill (and summon) carries SINGLE_EDGE, every area skill
## (burst, blast, fan, chain) AREA_SHARE, on top of its authored multiplier.
const SINGLE_EDGE := 1.15
const AREA_SHARE := 0.7
## Per-class damage tuning, measured with tests/tools/class_dps_probe.tscn
## (real-time fights against one target and a pack of six at Lv.26, Lv.70 and
## Lv.100 ★200, each class with its strongest bar): [single-target, area]
## factors for skills unlocked at Lv.1-35, Lv.36-75 and Lv.76-100 / star skills,
## so no class stands out in either fight at any stage.
const TUNE := {
	&"summoner": [[0.872, 0.872], [1.499, 1.385], [1.087, 1.242]],
	&"lancer": [[0.691, 0.691], [0.553, 0.737], [0.793, 0.793]],
	&"defender": [[1.395, 1.395], [1.647, 1.796], [1.8, 1.61]],
}
const AREA_SHAPES := ["burst", "blast", "fan", "chain"]


## The tuning factor of a class's skill: its band (by unlock level; star
## skills belong to the last band) and whether it strikes one target or an area.
static func skill_tune(cls: StringName, level: int, star: bool, shape: String) -> float:
	var area := shape in AREA_SHAPES
	var band := 2 if star or level > 75 else (1 if level > 35 else 0)
	var table: Array = _lines_of(cls).TUNE if has_lines(cls) else TUNE.get(cls, [[1.0, 1.0], [1.0, 1.0], [1.0, 1.0]])
	return float(table[band][1 if area else 0]) * (AREA_SHARE if area else SINGLE_EDGE)


## High-level skills hit a lot harder on paper; the damage audit showed them
## one-shooting their own zones with farmed gear. Their multiplier fades from
## 100% at Lv.20 to 65% at Lv.100 (summons included).
static func damage_curve(level: int) -> float:
	return 1.0 - 0.35 * clampf(float(level - 20) / 80.0, 0.0, 1.0)


static func _sk(cls: StringName, id: String, name: String, desc: String, level: int, mp: int, cd: float, shape: String, mult: float, extra := {}) -> Dictionary:
	mult *= damage_curve(level) * skill_tune(cls, level, false, shape)
	var melee := cls == &"vagabond" or cls == &"warrior" or cls == &"lancer" or cls == &"defender" or cls == &"assassin" or cls == &"darklord"
	var caster := cls == &"mage" or cls == &"priest" or cls == &"summoner" or cls == &"bard"
	var skill := {"id": id, "name": name, "desc": desc, "level": level, "mp": mp, "cd": cd, "shape": shape, "mult": mult}
	match shape:
		"single":
			skill["range"] = 4.2 if cls == &"lancer" else 2.9 if melee else (10.5 if caster else 13.0)
			skill["projectile"] = not melee
			skill["anim"] = "2H_Melee_Attack_Stab" if cls == &"lancer" else "Dualwield_Melee_Attack_Chop" if cls == &"assassin" else "1H_Melee_Attack_Chop" if melee else ("Spellcast_Shoot" if caster else "2H_Ranged_Shoot")
			skill["hit_delay"] = 0.25 if melee else (0.3 if caster else 0.2)
			skill["vfx"] = &"slash" if melee else (&"light" if cls == &"priest" else (&"leaf" if cls == &"summoner" else &"impact"))
		"burst":
			skill["radius"] = 4.5
			skill["anim"] = "2H_Melee_Attack_Spin" if melee else ("Spellcast_Raise" if caster else "2H_Ranged_Shooting")
			skill["hit_delay"] = 0.38
			skill["vfx"] = &"slash" if melee else &"impact"
		"blast":
			skill["range"] = 11.0
			skill["radius"] = 4.5
			skill["anim"] = "Spellcast_Long" if caster else "2H_Ranged_Shooting"
			skill["hit_delay"] = 0.8 if caster else 0.5
			skill["vfx"] = &"impact"
		"fan":
			skill["range"] = 12.0
			skill["hits"] = 3
			skill["projectile"] = true
			skill["anim"] = "Spellcast_Shoot" if caster else "2H_Ranged_Shoot"
			skill["hit_delay"] = 0.25
			skill["vfx"] = &"leaf" if cls == &"archer" else &"impact"
		"chain":
			skill["range"] = 11.0
			skill["hits"] = 4
			skill["anim"] = "Spellcast_Shoot"
			skill["hit_delay"] = 0.3
			skill["vfx"] = &"thunder"
		"summon":
			skill["anim"] = "Cheer" if melee else ("Spellcasting" if caster else "Cheer")
			skill["hit_delay"] = 0.35
			skill["vfx"] = &"aura"
		_:
			skill["anim"] = "Cheer" if melee else ("Spellcasting" if caster else "Dodge_Backward")
			skill["hit_delay"] = 0.25
			skill["vfx"] = &"aura"
	for key in extra:
		skill[key] = extra[key]
	return skill


static func _build_pools() -> void:
	# The old starter's skills: only old data and the skill art still look them up.
	var v := &"vagabond"
	_pools[v] = [
		_sk(v, "power_strike", "Power Strike", "ฟันหนักๆ ใส่ศัตรูตัวเดียว", 1, 6, 3.0, "single", 2.3, {"color": Color("ffb05a"), "icon": "sword"}),
		_sk(v, "round_slash", "Round Slash", "หมุนตัวฟันศัตรูรอบตัว", 4, 12, 8.0, "burst", 1.8, {"radius": 4.0, "special": "spin", "color": Color("ffc27a"), "icon": "spin"}),
		_sk(v, "second_wind", "Second Wind", "ฟื้นฟู HP 35%", 7, 14, 16.0, "self", 0.0, {"fx": {"heal": 0.35}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
	]
	var s := &"summoner"
	var sm := func(id: String, name: String, desc: String, level: int, mp: int, cd: float, mult: float, kind: String, count: int, interval: float, color: Color, extra := {}) -> Dictionary:
		var spec := {"kind": kind, "count": count, "secs": 120.0, "interval": interval}
		spec.merge(extra.get("spec", {}))
		return _sk(s, id, name, desc + " (นาน 2 นาทีหรือจนกว่าจะถูกสังหาร ใหญ่ขึ้นตามดาวสกิล)", level, mp, cd, "summon", mult, {"summon": spec, "color": color, "icon": "triple"})
	_pools[s] = [
		_sk(s, "thorn_shot", "Thorn Shot", "ยิงหนามธรรมชาติใส่ศัตรูตัวเดียว", 1, 9, 3.0, "single", 2.9, {"color": Color("a8f07a"), "icon": "arrow"}),
		sm.call("spirit_cat", "Spirit Cat", "เรียกแมววิญญาณกระโจนข่วนศัตรู", 5, 14, 24.0, 2.2, "cat", 1, 0.8, Color("ffd8a0")),
		_sk(s, "forest_blessing", "Forest Blessing", "พลังป่าคุ้มครอง DEF +25% ATK +12% นาน 1 นาที (ส่งถึงทีมและอสูร)", 13, 18, 30.0, "self", 0.0, {"fx": {"buff": {"def": 0.25, "atk": 0.12, "secs": 60.0}}, "color": Color("7ddc6a"), "icon": "bless"}),
		_sk(s, "vine_lash", "Vine Lash", "เถาวัลย์ฟาด 3 เส้นพร้อมกัน", 16, 18, 7.0, "fan", 2.0, {"hits": 3, "color": Color("6fe07a"), "icon": "triple"}),
		_sk(s, "entangle", "Entangle", "รากไม้พันศัตรูในพื้นที่ ช้าลง 4 วินาที", 20, 24, 10.0, "blast", 3.4, {"radius": 4.8, "fx": {"slow": 4.0}, "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		sm.call("wolf_pack", "Wolf Pack", "เรียกหมาป่าแห่งป่า 2 ตัว", 24, 30, 30.0, 2.8, "wolf", 2, 0.9, Color("bfe0ff")),
		_sk(s, "regrowth", "Regrowth", "ฟื้นฟู HP 35% และ DEF +15% นาน 1 นาที", 27, 28, 20.0, "self", 0.0, {"fx": {"heal": 0.35, "buff": {"def": 0.15, "secs": 60.0}}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(s, "spore_burst", "Spore Burst", "ปล่อยสปอร์ระเบิดรอบตัว ศัตรูช้าลง 3 วินาที", 31, 32, 10.0, "burst", 4.8, {"radius": 5.0, "fx": {"slow": 3.0}, "vfx": &"leaf", "color": Color("b8f07a"), "icon": "nova"}),
		sm.call("giant_frog", "Giant Frog", "เรียกกบยักษ์พ่นน้ำพิษใส่ศัตรู", 35, 38, 32.0, 4.0, "frog", 1, 1.1, Color("7fe07a")),
		_sk(s, "beast_rage", "Beast Rage", "ATK +30% วิ่งเร็ว +15% นาน 1 นาที (ส่งถึงทีมและอสูร)", 39, 34, 32.0, "self", 0.0, {"fx": {"buff": {"atk": 0.3, "speed": 0.15, "secs": 60.0}}, "color": Color("ffb04a"), "icon": "roar"}),
		_sk(s, "thorn_storm", "Thorn Storm", "พายุหนามถล่มพื้นที่เป้าหมาย", 43, 46, 12.0, "blast", 7.0, {"radius": 6.0, "special": "rain", "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		sm.call("forest_guardian", "Forest Guardian", "เรียกผู้พิทักษ์ป่าร่างยักษ์", 47, 60, 36.0, 6.0, "guardian", 1, 1.2, Color("c8a070")),
		_sk(s, "life_bloom", "Life Bloom", "ฟื้นฟู HP 40% DEF +30% นาน 1 นาที", 52, 52, 28.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 0.3, "secs": 60.0}}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(s, "nature_wrath", "Nature's Wrath", "พลังธรรมชาติกระโดดฟาดศัตรู 6 ตัว", 56, 58, 12.0, "chain", 5.6, {"hits": 6, "vfx": &"leaf", "color": Color("7ddc6a"), "icon": "bolt"}),
		sm.call("alpha_wolves", "Alpha Wolves", "เรียกหมาป่าจ่าฝูง 3 ตัว", 60, 70, 36.0, 5.0, "wolf", 3, 0.8, Color("9ad0ff")),
		_sk(s, "earth_shatter", "Earth Shatter", "ทุบพื้นสะเทือนรอบตัว ศัตรูมึนงง 1.2 วินาที", 64, 66, 12.0, "burst", 9.0, {"radius": 6.0, "fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("e8c79f"), "icon": "nova"}),
		sm.call("ancient_treant", "Ancient Treant", "เรียกเอนท์โบราณผู้ทรงพลัง", 68, 90, 40.0, 9.0, "treant", 1, 1.3, Color("b0e070")),
		_sk(s, "spirit_link", "Spirit Link", "เชื่อมวิญญาณ ATK +50% วิ่งเร็ว +20% DEF +30% นาน 1 นาที (ส่งถึงทีมและอสูร)", 72, 76, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "speed": 0.2, "def": 0.3, "secs": 60.0}}, "color": Color("a8ffd0"), "icon": "bless"}),
		_sk(s, "sylvan_ray", "Sylvan Ray", "รังสีแห่งป่าใส่ศัตรูตัวเดียว", 76, 78, 9.0, "single", 14.0, {"range": 12.0, "vfx": &"leaf", "color": Color("b8ffa0"), "icon": "light"}),
		_sk(s, "world_tree", "World Tree", "ต้นไม้โลกถล่มพื้นที่กว้าง ศัตรูช้าลง 4 วินาที", 80, 100, 16.0, "blast", 15.0, {"radius": 8.5, "fx": {"slow": 4.0}, "special": "rain", "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		sm.call("fairy_spirit", "Fairy Spirit", "อัญเชิญภูตินางฟ้าบินตามติดผู้อัญเชิญ ฟื้นฟู HP 20% ให้ผู้อัญเชิญทุก 10 วินาที และ 10% ให้เพื่อนร่วมทีมที่อยู่ใกล้เธอ", 84, 100, 40.0, 4.0, "fairy", 1, 10.0, Color("ffb6e6"), {"spec": {"heal": 0.2, "ally_heal": 0.1}}),
		_sk(s, "gaia_blessing", "Gaia's Blessing", "ฟื้นฟู HP 40% DEF +60% ATK +40% นาน 1 นาที (ส่งถึงทีมและอสูร)", 88, 96, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 0.6, "atk": 0.4, "secs": 60.0}}, "vfx": &"heal", "color": Color("d8ffb0"), "icon": "bless"}),
		sm.call("primal_legion", "Primal Legion", "เรียกอสูรป่าดึกดำบรรพ์ 3 ตัว", 92, 110, 45.0, 10.0, "beast", 3, 1.0, Color("7aff8a")),
		_sk(s, "cataclysm", "Cataclysm", "ธรรมชาติพิโรธ ถล่มรอบตัวอย่างรุนแรง", 96, 118, 16.0, "burst", 22.0, {"radius": 9.0, "vfx": &"leaf", "color": Color("b8ff7a"), "icon": "spin"}),
		sm.call("elder_dragon", "Elder Dragon", "เรียกมังกรโบราณผู้เป็นตำนาน", 100, 150, 50.0, 28.0, "elder_dragon", 1, 1.2, Color("ffd84a")),
	]
	var l := &"lancer"
	var pc := func(n: int, length: float, width := 1.3, keep := 0.7) -> Dictionary:
		return {"n": n, "len": length, "w": width, "k": keep}
	_pools[l] = [
		_sk(l, "thrust", "Thrust", "แทงหอกใส่ศัตรูตัวเดียว ทะลุไปโดนตัวหลังอีก 2 ตัว", 1, 9, 4.0, "single", 3.0, {"pierce": pc.call(2, 6.5), "color": Color("9ad8ff"), "icon": "sword"}),
		_sk(l, "stagger", "Stagger", "ด้ามหอกกระแทก ศัตรูมึนงง 1.2 วินาที", 5, 12, 6.0, "single", 3.2, {"fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		_sk(l, "focus", "Focus", "จดจ่อ คริติคอล +15% ATK +10% นาน 1 นาที", 13, 16, 28.0, "self", 0.0, {"fx": {"buff": {"crit": 0.15, "atk": 0.1, "secs": 60.0}}, "color": Color("ffd27a"), "icon": "roar"}),
		_sk(l, "skewer", "Skewer", "แทงเสียบทะลุแนวตรง 3 ตัว", 16, 18, 6.0, "single", 4.2, {"pierce": pc.call(3, 7.5), "color": Color("8fd0ff"), "icon": "sword"}),
		_sk(l, "whirl", "Whirl", "หมุนหอกฟาดรอบตัว", 20, 22, 8.0, "burst", 2.7, {"radius": 4.6, "special": "spin", "color": Color("9ad8ff"), "icon": "spin"}),
		_sk(l, "charge_dash", "Charge Dash", "พุ่งเข้าใส่แล้วแทง ศัตรูมึนงงสั้นๆ", 24, 24, 8.0, "single", 5.0, {"range": 8.5, "fx": {"stun": 0.6}, "pierce": pc.call(2, 8.5), "color": Color("ffb04a"), "icon": "boots"}),
		_sk(l, "wind_stance", "Wind Stance", "ท่าลม วิ่งเร็ว +30% คริติคอล +12% ATK +15% นาน 1 นาที", 27, 26, 30.0, "self", 0.0, {"fx": {"buff": {"speed": 0.3, "crit": 0.12, "atk": 0.15, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
		_sk(l, "impale", "Impale", "ปักหอกเสียบศัตรู ช้าลง 3 วินาที ทะลุ 3 ตัว", 31, 28, 8.0, "single", 6.0, {"fx": {"slow": 3.0}, "pierce": pc.call(3, 8.0), "color": Color("7fdcff"), "icon": "sword"}),
		_sk(l, "spear_wave", "Spear Wave", "คลื่นหอกพุ่งไกลทะลุ 5 ตัว", 35, 34, 9.0, "single", 4.8, {"range": 9.0, "pierce": pc.call(5, 11.0, 1.5), "vfx": &"impact", "color": Color("b8e6ff"), "icon": "arrow"}),
		_sk(l, "iron_resolve", "Iron Resolve", "ใจเหล็ก DEF +50% ฟื้นฟู HP 15% นาน 1 นาที", 39, 34, 32.0, "self", 0.0, {"fx": {"heal": 0.15, "buff": {"def": 0.5, "secs": 60.0}}, "color": Color("c0d0e8"), "icon": "shield"}),
		_sk(l, "spinning_pike", "Spinning Pike", "หอกหมุนเป็นพายุรอบตัว", 43, 40, 10.0, "burst", 5.2, {"radius": 5.0, "special": "spin", "color": Color("8fd0ff"), "icon": "spin"}),
		_sk(l, "hook_strike", "Hook Strike", "เกี่ยวด้วยใบมีดข้างหอก ศัตรูมึนงง 1.5 วินาที", 47, 42, 9.0, "single", 7.0, {"fx": {"stun": 1.5}, "pierce": pc.call(2, 7.0), "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		_sk(l, "war_cry", "War Cry", "ตะโกนศึก ศัตรูรอบตัวมึนงง 2 วินาที", 52, 46, 16.0, "burst", 1.8, {"radius": 7.0, "fx": {"stun": 2.0}, "vfx": &"impact", "anim": "Cheer", "color": Color("ffd27a"), "icon": "roar"}),
		_sk(l, "dragon_tooth", "Dragon Tooth", "เขี้ยวมังกร แทงทะลุศัตรู 6 ตัว", 56, 54, 10.0, "single", 8.5, {"pierce": pc.call(6, 10.0, 1.5), "color": Color("ff8a4a"), "icon": "sword"}),
		_sk(l, "typhoon_spear", "Typhoon Spear", "พายุหอกหมุนถล่มรอบตัว ศัตรูช้าลง", 60, 62, 12.0, "burst", 9.0, {"radius": 6.5, "special": "spin", "fx": {"slow": 2.5}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		_sk(l, "lancer_rush", "Lancer Rush", "บุกทะลวง ATK +45% วิ่งเร็ว +25% คริติคอล +10% นาน 1 นาที", 64, 60, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.45, "speed": 0.25, "crit": 0.1, "secs": 60.0}}, "color": Color("ff9a5a"), "icon": "boots"}),
		_sk(l, "vanguard_strike", "Vanguard Strike", "แทงแนวหน้าทรงพลัง ทะลุ 4 ตัว", 68, 66, 9.0, "single", 12.0, {"range": 4.6, "pierce": pc.call(4, 9.0, 1.5), "color": Color("6ecbff"), "icon": "sword"}),
		_sk(l, "sky_pierce", "Sky Pierce", "หอกพุ่งทะลุฟ้า แทงเป็นเส้นยาวทะลุ 8 ตัว", 72, 74, 11.0, "single", 9.5, {"range": 10.0, "pierce": pc.call(8, 13.0, 1.6), "vfx": &"light", "color": Color("d8f0ff"), "icon": "arrow"}),
		_sk(l, "dragon_stance", "Dragon Stance", "ท่ามังกร ATK +40% DEF +40% ฟื้นฟู HP 20% นาน 1 นาที", 76, 70, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.4, "def": 0.4, "secs": 60.0}}, "color": Color("ffb04a"), "icon": "shield"}),
		_sk(l, "dragon_lance", "Dragon Lance", "หอกมังกรเพลิงแทงทะลุ 8 ตัว ติดไฟ", 80, 90, 11.0, "single", 14.0, {"range": 5.0, "pierce": pc.call(8, 14.0, 1.6), "fx": {"burn": [0.4, 5.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(l, "gale_cyclone", "Gale Cyclone", "ไซโคลนหอกพัดถล่มรอบตัว ศัตรูช้าลง", 84, 96, 14.0, "burst", 14.0, {"radius": 7.5, "special": "spin", "fx": {"slow": 3.0}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		_sk(l, "valkyrie_blessing", "Valkyrie's Blessing", "พรวัลคีรี ATK +60% วิ่งเร็ว +20% คริติคอล +15% นาน 1 นาที", 88, 96, 45.0, "self", 0.0, {"fx": {"buff": {"atk": 0.6, "speed": 0.2, "crit": 0.15, "secs": 60.0}}, "color": Color("ffe9a0"), "icon": "bless"}),
		_sk(l, "gungnir", "Gungnir", "ขว้างหอกเทพเจ้า ทะลุศัตรู 5 ตัวเป็นแนวยาว", 92, 110, 13.0, "single", 17.0, {"range": 13.0, "pierce": pc.call(5, 15.0, 1.8), "vfx": &"light", "color": Color("fff0a0"), "icon": "arrow"}),
		_sk(l, "heaven_rend", "Heaven Rend", "ฟาดหอกฉีกฟ้า ศัตรูรอบตัวมึนงง 1.2 วินาที", 96, 118, 16.0, "burst", 21.0, {"radius": 9.0, "fx": {"stun": 1.2}, "special": "spin", "vfx": &"light", "color": Color("fff0a0"), "icon": "spin"}),
		_sk(l, "ragnarok_lance", "Ragnarok Lance", "หอกแห่งวันสิ้นโลก แทงทะลุศัตรู 10 ตัว", 100, 140, 14.0, "single", 26.0, {"range": 5.5, "pierce": pc.call(10, 15.0, 1.8, 0.8), "vfx": &"light", "color": Color("ffd84a"), "icon": "sword"}),
	]
	var d := &"defender"
	_pools[d] = [
		_sk(d, "shield_bash", "Shield Bash", "ฟาดขอบโล่ใส่ศัตรูตัวเดียว", 1, 10, 3.0, "single", 2.6, {"anim": "Block_Attack", "vfx": &"impact", "color": Color("bcd6f0"), "icon": "shield"}),
		# เบ่งเลือด (was Brace, same id so saves keep their stars): max HP +30% and damage taken
		# -10% at ★1, up to +50% / -25% at ★5 (the buff's "grow", SkillRank.scaled_fx), 1 minute.
		# The max HP is a ceiling for the whole party ("party": only "hp" is shared,
		# BuffBook.party_part): it fills no HP. The damage cut is the Defender's own.
		# A 25 s cooldown keeps it up all the time.
		_sk(d, "brace", "เบ่งเลือด", "เพิ่มเพดาน HP สูงสุดของทุกคนในปาร์ตี้ +30% (ไม่เติมเลือด) และผู้พิทักษ์ลดความเสียหายที่ได้รับ 10% นาน 1 นาที (★5: HP สูงสุด +50% ลดดาเมจ 25%)", 5, 12, 25.0, "self", 0.0, {"fx": {"buff": {"hp": 0.30, "guard": 0.10, "secs": 60.0, "party": ["hp"], "grow": {"hp": 0.05, "guard": 0.0375}}}, "anim": "Blocking", "color": Color("ff6b6b"), "icon": "shield"}),
		_sk(d, "shield_slam", "Shield Slam", "กระแทกหน้าโล่ใส่ศัตรู มึนงง 1.5 วินาที", 14, 16, 6.0, "single", 3.8, {"fx": {"stun": 1.5}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		_sk(d, "provoke", "Provoke", "เคาะโล่ท้าทาย ศัตรูรอบตัวช้าลงและหันมาโจมตีคุณ 4 วินาที", 17, 18, 14.0, "burst", 1.5, {"radius": 7.0, "fx": {"taunt": 4.0, "slow": 2.0}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ff9a6a"), "icon": "roar"}),
		_sk(d, "ground_quake", "Ground Quake", "ทุบโล่ลงพื้น ศัตรูรอบตัวช้าลง 2 วินาที", 20, 20, 9.0, "burst", 2.4, {"radius": 4.5, "fx": {"slow": 2.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("d8b98a"), "icon": "nova"}),
		_sk(d, "shield_toss", "Shield Toss", "ขว้างโล่เด้งไปโดนศัตรู 3 ตัวแล้วกลับมือ", 24, 24, 9.0, "chain", 3.0, {"hits": 3, "range": 9.0, "anim": "Block_Attack", "vfx": &"impact", "color": Color("bcd6f0"), "icon": "triple"}),
		_sk(d, "iron_wall", "Iron Wall", "กำแพงเหล็ก DEF +50% ลดความเสียหาย 15% นาน 1 นาที (ส่งถึงทีม)", 27, 26, 32.0, "self", 0.0, {"fx": {"buff": {"def": 0.5, "guard": 0.15, "secs": 60.0}}, "anim": "Blocking", "color": Color("a8c8e8"), "icon": "shield"}),
		_sk(d, "bulwark_charge", "Bulwark Charge", "ยกโล่พุ่งชนทะลุแนวศัตรู 3 ตัว มึนงงสั้นๆ", 31, 28, 8.0, "single", 4.8, {"range": 8.0, "fx": {"stun": 0.6}, "pierce": pc.call(3, 8.0, 1.6), "anim": "Block_Attack", "vfx": &"impact", "color": Color("ffb04a"), "icon": "boots"}),
		_sk(d, "thorn_guard", "Thorn Guard", "โล่หนาม สะท้อนความเสียหาย 20% กลับใส่ผู้โจมตี DEF +20% นาน 1 นาที", 35, 30, 34.0, "self", 0.0, {"fx": {"buff": {"reflect": 0.2, "def": 0.2, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffb46a"), "icon": "shield"}),
		_sk(d, "quake_slam", "Quake Slam", "ทุบพื้นสั่นสะเทือน ศัตรูรอบตัวมึนงง 1.2 วินาที", 39, 38, 12.0, "burst", 4.0, {"radius": 5.2, "fx": {"stun": 1.2}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("e8c08a"), "icon": "spin"}),
		_sk(d, "aegis_strike", "Aegis Strike", "ฟาดโล่สุดแรงใส่ศัตรูตัวเดียว", 43, 40, 8.0, "single", 7.4, {"range": 3.2, "anim": "Block_Attack", "vfx": &"impact", "color": Color("9fd0ff"), "icon": "shield"}),
		_sk(d, "guardian_oath", "Guardian's Oath", "สาบานผู้พิทักษ์ ฟื้น HP 20% และโล่ดูดซับ 15% ของ HP สูงสุด นาน 1 นาที", 47, 44, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"shield": 0.15, "secs": 60.0}}, "anim": "Blocking", "color": Color("fff0b0"), "icon": "heal"}),
		_sk(d, "shield_wave", "Shield Wave", "ฟาดโล่ส่งคลื่นพลังทะลุศัตรู 5 ตัว", 52, 48, 9.0, "single", 6.5, {"range": 9.0, "pierce": pc.call(5, 11.0, 1.6), "anim": "Block_Attack", "vfx": &"impact", "color": Color("b8e0ff"), "icon": "arrow"}),
		_sk(d, "shockwave_wall", "Shockwave Wall", "ดันโล่สร้างคลื่นกระแทกรอบตัว ศัตรูกระเด็นและมึนงง 0.8 วินาที", 56, 52, 11.0, "burst", 6.0, {"radius": 6.0, "fx": {"stun": 0.8}, "anim": "2H_Melee_Attack_Spin", "vfx": &"impact", "color": Color("9fe8ff"), "icon": "nova"}),
		_sk(d, "titan_quake", "Titan Quake", "ทุบพสุธาด้วยโล่ยักษ์ ศัตรูรอบตัวมึนงง 1 วินาที", 60, 62, 12.0, "burst", 7.5, {"radius": 6.5, "fx": {"stun": 1.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("ffb06a"), "icon": "spin"}),
		_sk(d, "bastion_crush", "Bastion Crush", "กดโล่บดขยี้ศัตรูตัวเดียว", 64, 60, 8.0, "single", 12.0, {"range": 3.4, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("ff8a5a"), "icon": "shield"}),
		_sk(d, "rebound_storm", "Rebound Storm", "ขว้างโล่เด้งรัวไปโดนศัตรู 5 ตัว", 68, 66, 11.0, "chain", 5.6, {"hits": 5, "range": 10.0, "anim": "Block_Attack", "vfx": &"impact", "color": Color("c8e4ff"), "icon": "triple"}),
		_sk(d, "grand_provoke", "Grand Provoke", "ท้ารบทั้งสนาม ศัตรูรอบตัวช้าลงและหันมาโจมตีคุณ 5 วินาที", 72, 70, 16.0, "burst", 2.0, {"radius": 8.0, "fx": {"taunt": 5.0, "slow": 2.0}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ff7a4a"), "icon": "roar"}),
		_sk(d, "unbreakable", "Unbreakable", "ไม่มีวันแตก DEF +80% ฟื้น HP 30% สะท้อนความเสียหาย 25% นาน 1 นาที", 76, 76, 42.0, "self", 0.0, {"fx": {"heal": 0.3, "buff": {"def": 0.8, "reflect": 0.25, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffd27a"), "icon": "shield"}),
		_sk(d, "holy_rampart", "Holy Rampart", "กำแพงแสงระเบิดรอบตัว ศัตรูมึนงง 1.5 วินาที", 80, 90, 16.0, "burst", 11.5, {"radius": 7.5, "fx": {"stun": 1.5}, "anim": "2H_Melee_Attack_Spin", "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(d, "judgment_shield", "Judgment Shield", "ฟาดโล่แห่งคำพิพากษาใส่ศัตรูตัวเดียว", 84, 92, 10.0, "single", 17.0, {"range": 3.6, "anim": "2H_Melee_Attack_Slice", "vfx": &"light", "color": Color("fff0a0"), "icon": "shield"}),
		_sk(d, "aegis_of_ages", "Aegis of Ages", "อีจิสนิรันดร์ DEF +100% ฟื้น HP 40% โล่ดูดซับ 25% ของ HP นาน 1 นาที", 88, 90, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 1.0, "shield": 0.25, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffffff"), "icon": "shield"}),
		_sk(d, "meteor_shield", "Meteor Shield", "กระโดดทุบโล่ลงกลางฝูงศัตรู มึนงง 1.2 วินาที", 92, 100, 14.0, "blast", 13.5, {"radius": 7.0, "range": 11.0, "fx": {"stun": 1.2}, "anim": "2H_Melee_Attack_Slice", "hit_delay": 0.55, "vfx": &"impact", "color": Color("ffb04a"), "icon": "meteor"}),
		_sk(d, "sanctuary_wall", "Sanctuary Wall", "กำแพงวิหาร ATK +40% ลดความเสียหาย 25% นาน 1 นาที (ส่งถึงทีม)", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "guard": 0.25, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffe9a0"), "icon": "bless"}),
		_sk(d, "world_bastion", "World Bastion", "ปักโล่ลงพิภพ คลื่นป้อมปราการถล่มรอบตัว ศัตรูมึนงง 2 วินาทีแล้วหันมาโจมตีคุณ", 100, 130, 16.0, "burst", 23.0, {"radius": 9.0, "fx": {"stun": 2.0, "taunt": 4.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"light", "color": Color("ffd84a"), "icon": "nova"}),
	]

	# The converted classes (LINE_FILES): their 8 skill lines from their own file.
	for line_class in LINE_FILES:
		_pools[line_class] = _line_pool(line_class)
	for star_class in IDS:
		_pools[star_class].append_array(StarSkillData.pool(star_class))
