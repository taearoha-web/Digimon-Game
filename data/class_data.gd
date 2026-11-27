class_name ClassData
extends RefCounted
## Hero classes, chosen when the hero is made (sword, bow, mage, priest, summoner,
## spear, great shield, twin daggers, scepter and raven, lute, wrapped fists). Each class has a pool of active skills modelled on
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
const IDS: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard", &"muaythai"]

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
		"desc": "สายเรียกอสูร — เรียกสัตว์ป่าและเทพพิทักษ์มาสู้เคียงข้าง เสริมพลังตัวเองและอสูร ภูตินางฟ้าฟื้นเลือดให้ทีม ตัวเองสู้ด้วยเวทธรรมชาติ ยิ่งเรียกมาก ยิ่งแรง แต่ตัวเองเลือดไม่เยอะ",
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
		"desc": "ดาร์กลอร์ด — ราชันผู้บัญชาการแบบ MU Online ถือคทาราชันมือหนึ่ง อีกแขนมีอีกาคู่ใจเกาะอยู่ สั่งให้อีกาพุ่งไปโจมตีเองได้ ใช้พลังมืด ไฟ และสายฟ้า สั่นแผ่นดิน เสริมพลังตัวเอง และวาร์ปเพื่อนทั้งปาร์ตี้มาหาตัวได้ (STR ตีแรง INT เสริมเป็นรอง)",
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
	&"muaythai": {
		"name": "นักมวยประเจียด",
		"short": "นักมวย",
		"title": "นักชกแห่งวงมนตรา",
		"badge": "T",
		"desc": "นักมวยประเจียด — สวมสนับมือทั้งสองข้าง ชกด้วยหมัด ศอก เข่า และเท้า ยิ่งชกติดคอมโบยิ่งแรงและยิ่งฟื้นเลือดจากการตี มีวงประเจียดมนตราลอยวนรอบตัว (2 วง เพิ่มเป็น 4 วงที่ Lv.60 และ 6 วงที่ Lv.90) ขว้างวงออกไปแล้วบินกลับ ถีบและทุ่มศัตรูกระเด็น ทนทานแนวหน้า (STR ตีแรง VIT เสริมเป็นรอง)",
		"model": "Barbarian",
		"weapon": "wraps",
		"offhand": "wraps",
		"weapon_kind": "wraps",
		"color": Color("ff8a2a"),
		"main": "str",
		"sub": "vit",
		"base": {"str": 11, "int": 3, "dex": 6, "vit": 12},
		"gain": {"str": 2, "int": 0, "dex": 1, "vit": 3},
		"hp_mult": 1.4,
		"mp_mult": 0.75,
		"attack": {
			"range": 2.3, "interval": 0.62, "mult": 0.62, "hit_delay": 0.18, "projectile": false, "vfx": &"impact",
			"anims": ["Unarmed_Melee_Attack_Punch_A", "1H_Melee_Attack_Stab", "Unarmed_Melee_Attack_Punch_A"],
		},
	},
}



## Passive skills: always on once the level is reached, +[per] per rank.
## Keys of [bonus]: atk, def, hp, mp (fractions), crit, speed, dodge (added).
const PASSIVES := {}

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
	&"summoner": "res://data/skill_lines/summoner.gd",
	&"lancer": "res://data/skill_lines/lancer.gd",
	&"defender": "res://data/skill_lines/defender.gd",
	&"muaythai": "res://data/skill_lines/muaythai.gd",
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


## The owner's party-buff rule: every class's buffs buff only their caster (and its own
## summons), EXCEPT the Priest's and the Bard's (songs too) and the Defender's เบ่งเลือด,
## which reach the whole party. _build_pools marks those buffs "team" (BuffBook.reaches_party);
## a stance (self_only) stays the caster's whatever its class.
const PARTY_BUFF_CLASSES := [&"priest", &"bard"]
const PARTY_BUFF_SKILLS := ["brace"]


## Whether [param skill] of class [param cls] is a buff that reaches the party.
static func is_party_buff_skill(cls: StringName, skill: Dictionary) -> bool:
	var fx: Variant = skill.get("fx")
	if not (fx is Dictionary and (fx as Dictionary).get("buff") is Dictionary) or bool(fx.buff.get("self_only", false)):
		return false
	return PARTY_BUFF_CLASSES.has(cls) or PARTY_BUFF_SKILLS.has(String(skill.get("id", "")))


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
	# The Ascension skills (AscendSkillData) need the trial's step (JobData.ASCEND_TIER).
	if bool(skill.get("ascend", false)):
		return JobData.ASCEND_TIER
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
	# The Ascension (adv 6) opens its own tier, above the God step's (still 5).
	if adv >= JobData.ASCEND_ADV:
		return JobData.ASCEND_TIER
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
	var melee := cls == &"vagabond" or cls == &"warrior" or cls == &"lancer" or cls == &"defender" or cls == &"assassin" or cls == &"darklord" or cls == &"muaythai"
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
	# The converted classes (LINE_FILES): their 8 skill lines from their own file.
	for line_class in LINE_FILES:
		_pools[line_class] = _line_pool(line_class)
	for star_class in IDS:
		_pools[star_class].append_array(StarSkillData.pool(star_class))
		# The Ascension's ultimate and buff (adv 6, ★500): after the god skill.
		_pools[star_class].append_array(AscendSkillData.pool(star_class))
	# The party-buff rule (BuffBook.reaches_party): only these buffs reach the party.
	for cls in _pools:
		for skill in _pools[cls]:
			if is_party_buff_skill(cls, skill):
				skill["fx"] = (skill.fx as Dictionary).duplicate(true)
				skill.fx.buff["team"] = true
