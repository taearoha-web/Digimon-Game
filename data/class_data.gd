class_name ClassData
extends RefCounted
## Hero classes: the Vagabond (Lv.1-9) and the four lines chosen at Lv.10 (sword,
## bow, mage, priest, summoner). Each class has a pool of active skills modelled on
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

const START: StringName = &"vagabond"
const LINE_LEVEL := 10
const SLOTS := 8
## The four lines picked at Lv.10 (also the AI companion classes).
const IDS: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer"]

const CLASSES := {
	&"vagabond": {
		"name": "นักเดินทาง",
		"title": "ผู้ยังไม่เลือกเส้นทาง",
		"badge": "V",
		"desc": "นักเดินทางไร้สังกัด ถือดาบสั้นสู้ประชิดตัว พอถึงเลเวล 10 จะเลือกสายได้: สายดาบ สายธนู นักเวทย์ นักบวช หรือผู้เรียกอสูร หรือนักหอก",
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
		"hp_mult": 0.95,
		"mp_mult": 0.9,
		"attack": {
			"range": 11.0, "interval": 0.85, "mult": 1.0, "hit_delay": 0.2, "projectile": true, "vfx": &"impact",
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
		"hp_mult": 0.8,
		"mp_mult": 1.5,
		"attack": {
			"range": 9.5, "interval": 0.95, "mult": 1.0, "hit_delay": 0.3, "projectile": true, "vfx": &"impact",
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
		"hp_mult": 0.95,
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
		"crit_bonus": 0.04,
		"attack": {
			"range": 3.8, "interval": 0.72, "mult": 1.0, "hit_delay": 0.2, "projectile": false, "vfx": &"slash",
			"anims": ["2H_Melee_Attack_Stab", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Stab"],
		},
	},
}



## Passive skills: always on once the level is reached, +[per] per rank.
## Keys of [bonus]: atk, def, hp, mp (fractions), crit, speed, dodge (added).
const PASSIVES := {
	&"vagabond": [
		{"id": "toughness", "name": "Toughness", "desc": "HP สูงสุด +3% ต่อดาว", "level": 3, "bonus": {"hp": 0.03}},
	],
	&"warrior": [
		{"id": "melee_mastery", "name": "Melee Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "physical_training", "name": "Physical Training", "desc": "HP สูงสุด +4% ต่อดาว", "level": 20, "bonus": {"hp": 0.04}},
		{"id": "holy_body", "name": "Holy Body", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 30, "bonus": {"def": 0.04}},
		{"id": "weapon_mastery", "name": "Weapon Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 40, "bonus": {"atk": 0.025}},
		{"id": "battle_instinct", "name": "Battle Instinct", "desc": "คริติคอล +1.5% ต่อดาว", "level": 60, "bonus": {"crit": 0.015}},
		{"id": "immortal_body", "name": "Immortal Body", "desc": "HP สูงสุด +5% ต่อดาว", "level": 80, "bonus": {"hp": 0.05}},
	],
	&"archer": [
		{"id": "shooting_mastery", "name": "Shooting Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "wind_step", "name": "Wind Step", "desc": "ความเร็ว +2% และหลบ +0.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.02, "dodge": 0.006}},
		{"id": "hawk_eye", "name": "Hawk Eye", "desc": "คริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"crit": 0.015}},
		{"id": "evasion_mastery", "name": "Evasion Mastery", "desc": "หลบหลีก +1% ต่อดาว", "level": 40, "bonus": {"dodge": 0.01}},
		{"id": "ranger_mastery", "name": "Ranger Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "wind_walker", "name": "Wind Walker", "desc": "ความเร็ว +3% ต่อดาว", "level": 80, "bonus": {"speed": 0.03}},
	],
	&"mage": [
		{"id": "mental_mastery", "name": "Mental Mastery", "desc": "MP สูงสุด +5% ต่อดาว", "level": 10, "bonus": {"mp": 0.05}},
		{"id": "elemental_mastery", "name": "Elemental Mastery", "desc": "พลังโจมตี +2% ต่อดาว", "level": 20, "bonus": {"atk": 0.02}},
		{"id": "arcane_barrier", "name": "Arcane Barrier", "desc": "HP สูงสุด +3% ต่อดาว", "level": 30, "bonus": {"hp": 0.03}},
		{"id": "mana_pool", "name": "Mana Pool", "desc": "MP สูงสุด +5% ต่อดาว", "level": 40, "bonus": {"mp": 0.05}},
		{"id": "spell_mastery", "name": "Spell Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "archmage_will", "name": "Archmage's Will", "desc": "คริติคอล +1.5% ต่อดาว", "level": 80, "bonus": {"crit": 0.015}},
	],
	&"priest": [
		{"id": "meditation", "name": "Meditation", "desc": "MP สูงสุด +5% ต่อดาว", "level": 10, "bonus": {"mp": 0.05}},
		{"id": "divine_grace", "name": "Divine Grace", "desc": "HP สูงสุด +4% ต่อดาว", "level": 20, "bonus": {"hp": 0.04}},
		{"id": "holy_aura", "name": "Holy Aura", "desc": "พลังโจมตี +2% และ MP +3% ต่อดาว", "level": 30, "bonus": {"atk": 0.02, "mp": 0.03}},
		{"id": "faith", "name": "Faith", "desc": "HP สูงสุด +4% ต่อดาว", "level": 40, "bonus": {"hp": 0.04}},
		{"id": "divine_power", "name": "Divine Power", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "sanctity", "name": "Sanctity", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 80, "bonus": {"def": 0.04}},
	],
	&"summoner": [
		{"id": "nature_bond", "name": "Nature Bond", "desc": "MP สูงสุด +5% ต่อดาว", "level": 10, "bonus": {"mp": 0.05}},
		{"id": "beast_tamer", "name": "Beast Tamer", "desc": "พลังโจมตี +2% ต่อดาว", "level": 20, "bonus": {"atk": 0.02}},
		{"id": "wild_vitality", "name": "Wild Vitality", "desc": "HP สูงสุด +4% ต่อดาว", "level": 30, "bonus": {"hp": 0.04}},
		{"id": "spirit_ward", "name": "Spirit Ward", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "primal_focus", "name": "Primal Focus", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "gaia_heart", "name": "Gaia's Heart", "desc": "HP +4% และ MP +4% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "mp": 0.04}},
	],
	&"lancer": [
		{"id": "spear_mastery", "name": "Spear Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "light_footwork", "name": "Light Footwork", "desc": "ความเร็ว +2% และหลบ +0.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.02, "dodge": 0.006}},
		{"id": "keen_point", "name": "Keen Point", "desc": "คริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"crit": 0.015}},
		{"id": "iron_stance", "name": "Iron Stance", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "dragon_fang", "name": "Dragon Fang", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "valkyrie_heart", "name": "Valkyrie's Heart", "desc": "HP +4% และความเร็ว +2% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "speed": 0.02}},
	],
}

static var _pools: Dictionary = {}


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


static func find_skill(class_id: StringName, skill_id: String) -> Dictionary:
	for skill in pool(class_id):
		if skill.id == skill_id:
			return skill
	return {}


## Advancement tier a skill needs: 1 = the chosen line (Lv.10), then the four
## advancements at Lv.20 / 40 / 60 / 80 give tiers 2..5. Vagabond skills need none (0).
static func skill_tier(skill: Dictionary) -> int:
	var level := int(skill.get("level", 1))
	if level < LINE_LEVEL:
		return 0
	if level < 20:
		return 1
	if level < 40:
		return 2
	if level < 60:
		return 3
	return 4 if level < 80 else 5


## Current tier of a hero: 0 Vagabond, 1 line, 2..5 after each advancement.
static func tier_of(class_id: StringName, adv: int) -> int:
	if class_id == START:
		return 0
	return 1 + clampi(adv, 0, 4)


## The first unlocked skills fill the empty bar slots.
static func default_loadout(class_id: StringName, level: int, current: Array = [], tier := 3) -> Array:
	var out: Array = []
	for i in SLOTS:
		out.append(String(current[i]) if i < current.size() else "")
	var pool_skills := pool(class_id)
	# Drop ids that no longer belong to this class or are not unlocked.
	for i in SLOTS:
		var skill := find_skill(class_id, out[i])
		if skill.is_empty() or int(skill.level) > level or skill_tier(skill) > tier or out.find(out[i]) != i:
			out[i] = ""
	for skill in pool_skills:
		if int(skill.level) > level or skill_tier(skill) > tier or out.has(skill.id):
			continue
		var empty := out.find("")
		if empty < 0:
			break
		out[empty] = skill.id
	return out


# --- skill table -----------------------------------------------------------

## High-level skills hit a lot harder on paper; the damage audit showed them
## one-shooting their own zones with farmed gear. Their multiplier fades from
## 100% at Lv.20 to 65% at Lv.100 (summons included).
static func damage_curve(level: int) -> float:
	return 1.0 - 0.35 * clampf(float(level - 20) / 80.0, 0.0, 1.0)


static func _sk(cls: StringName, id: String, name: String, desc: String, level: int, mp: int, cd: float, shape: String, mult: float, extra := {}) -> Dictionary:
	mult *= damage_curve(level)
	var melee := cls == &"vagabond" or cls == &"warrior" or cls == &"lancer"
	var caster := cls == &"mage" or cls == &"priest" or cls == &"summoner"
	var skill := {"id": id, "name": name, "desc": desc, "level": level, "mp": mp, "cd": cd, "shape": shape, "mult": mult}
	match shape:
		"single":
			skill["range"] = 4.2 if cls == &"lancer" else 2.9 if melee else (10.5 if caster else 13.0)
			skill["projectile"] = not melee
			skill["anim"] = "2H_Melee_Attack_Stab" if cls == &"lancer" else "1H_Melee_Attack_Chop" if melee else ("Spellcast_Shoot" if caster else "2H_Ranged_Shoot")
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
	var v := &"vagabond"
	_pools[v] = [
		_sk(v, "power_strike", "Power Strike", "ฟันหนักๆ ใส่ศัตรูตัวเดียว", 1, 6, 3.0, "single", 2.3, {"color": Color("ffb05a"), "icon": "sword"}),
		_sk(v, "round_slash", "Round Slash", "หมุนตัวฟันศัตรูรอบตัว", 4, 12, 8.0, "burst", 1.8, {"radius": 4.0, "special": "spin", "color": Color("ffc27a"), "icon": "spin"}),
		_sk(v, "second_wind", "Second Wind", "ฟื้นฟู HP 35%", 7, 14, 16.0, "self", 0.0, {"fx": {"heal": 0.35}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
	]
	var w := &"warrior"
	_pools[w] = [
		_sk(w, "raving", "Raving", "ฟันรัวใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 10, 10, 3.0, "single", 3.0, {"color": Color("ffb05a"), "icon": "sword"}),
		_sk(w, "impact", "Impact", "ฟันกระแทกหนักๆ ศัตรูมึนงง 1.5 วินาที", 10, 12, 6.0, "single", 3.4, {"fx": {"stun": 1.5}, "vfx": &"impact", "anim": "Block_Attack", "color": Color("ffe27a"), "icon": "shield"}),
		_sk(w, "triple_impact", "Triple Impact", "ฟันต่อเนื่อง 3 ครั้งใส่เป้าหมายเดียว", 14, 16, 6.0, "single", 4.6, {"color": Color("ff9a5a"), "icon": "sword"}),
		_sk(w, "brutal_swing", "Brutal Swing", "หมุนตัวฟันรอบทิศ", 17, 20, 9.0, "burst", 2.8, {"radius": 4.3, "special": "spin", "color": Color("ff9a5a"), "icon": "spin"}),
		_sk(w, "roar", "Roar", "คำรามก้อง ศัตรูรอบตัวมึนงง 2.5 วินาที", 20, 20, 14.0, "burst", 1.4, {"radius": 6.0, "fx": {"stun": 2.5}, "vfx": &"impact", "anim": "Cheer", "color": Color("ffd27a"), "icon": "roar"}),
		_sk(w, "rage_of_zecram", "Rage of Zecram", "พลังโกรธาปะทุ ฟันศัตรูรอบตัวอย่างรุนแรง", 24, 26, 10.0, "burst", 4.0, {"radius": 4.8, "color": Color("ff5a3a"), "icon": "spin"}),
		_sk(w, "concentration", "Concentration", "ATK +30% คริติคอล +15% นาน 1 นาที", 27, 24, 30.0, "self", 0.0, {"fx": {"buff": {"atk": 0.3, "crit": 0.15, "secs": 60.0}}, "color": Color("ffb04a"), "icon": "roar"}),
		_sk(w, "avenging_crash", "Avenging Crash", "ฟันจู่โจมแรงสูงใส่ศัตรูตัวเดียว", 31, 28, 7.0, "single", 6.2, {"range": 3.1, "color": Color("ff5a3a"), "icon": "sword"}),
		_sk(w, "swift_axe", "Swift Axe", "วิ่งเร็ว +30% ATK +20% นาน 1 นาที", 35, 26, 30.0, "self", 0.0, {"fx": {"buff": {"speed": 0.3, "atk": 0.2, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
		_sk(w, "bone_crash", "Bone Crash", "ทุบพื้นถล่มศัตรูรอบตัว มึนงง 1.2 วินาที", 39, 38, 12.0, "burst", 4.8, {"radius": 5.2, "fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ff8a4a"), "icon": "spin"}),
		_sk(w, "destroyer", "Destroyer", "ฟันทำลายล้างศัตรูตัวเดียว", 43, 40, 9.0, "single", 8.2, {"range": 3.2, "color": Color("ff3a3a"), "icon": "sword"}),
		_sk(w, "berserker", "Berserker", "ATK +55% วิ่งเร็ว +15% นาน 1 นาที", 47, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "speed": 0.15, "secs": 60.0}}, "color": Color("ff4a3a"), "icon": "roar"}),
		_sk(w, "sword_blast", "Sword Blast", "ปล่อยคลื่นดาบพุ่งไปไกลใส่ศัตรู", 52, 48, 8.0, "single", 9.5, {"range": 9.0, "projectile": true, "vfx": &"impact", "color": Color("ffb04a"), "icon": "sword"}),
		_sk(w, "holy_valor", "Holy Valor", "ATK +40% DEF +30% นาน 1 นาที", 56, 52, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "def": 0.3, "secs": 60.0}}, "color": Color("ffe27a"), "icon": "roar"}),
		_sk(w, "cyclone_strike", "Cyclone Strike", "พายุดาบหมุนรอบตัว ศัตรูมึนงง 1 วินาที", 60, 62, 12.0, "burst", 8.0, {"radius": 6.5, "special": "spin", "fx": {"stun": 1.0}, "color": Color("ff8a4a"), "icon": "spin"}),
		_sk(w, "brandish", "Brandish", "ฟันกวาดแรงสูงใส่ศัตรูตัวเดียว", 64, 60, 8.0, "single", 13.0, {"range": 3.4, "color": Color("ff5a3a"), "icon": "sword"}),
		_sk(w, "double_crash", "Double Crash", "กระแทกสองครั้งติด ศัตรูรอบตัวบาดเจ็บหนัก", 68, 70, 11.0, "burst", 9.5, {"radius": 5.5, "vfx": &"impact", "color": Color("ff7a3a"), "icon": "spin"}),
		_sk(w, "piercing", "Piercing", "ดาบพุ่งทะลวงศัตรู 6 ตัวต่อเนื่อง", 72, 72, 12.0, "chain", 5.5, {"hits": 6, "range": 9.0, "vfx": &"slash", "color": Color("ffd27a"), "icon": "sword"}),
		_sk(w, "drastic_spirit", "Drastic Spirit", "DEF +80% ฟื้นฟู HP 30% นาน 1 นาที", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.3, "buff": {"def": 0.8, "secs": 60.0}}, "color": Color("ffe9a0"), "icon": "shield"}),
		_sk(w, "grand_cross", "Grand Cross", "ไม้กางเขนดาบถล่มรอบตัว ศัตรูมึนงง 1.5 วินาที", 80, 90, 16.0, "burst", 13.0, {"radius": 7.5, "special": "spin", "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("fff0a0"), "icon": "spin"}),
		_sk(w, "sword_of_justice", "Sword of Justice", "ดาบแห่งความยุติธรรมฟันขาดศัตรูตัวเดียว", 84, 92, 10.0, "single", 18.0, {"range": 3.6, "vfx": &"light", "color": Color("fff0a0"), "icon": "sword"}),
		_sk(w, "godly_shield", "Godly Shield", "DEF +120% ฟื้นฟู HP 40% นาน 1 นาที", 88, 90, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 1.2, "secs": 60.0}}, "color": Color("ffffff"), "icon": "shield"}),
		_sk(w, "divine_piercing", "Divine Piercing", "ดาบศักดิ์สิทธิ์พุ่งไปที่ศัตรู 8 ทิศ", 92, 100, 14.0, "fan", 5.5, {"hits": 8, "range": 12.0, "vfx": &"light", "color": Color("fff0a0"), "icon": "triple"}),
		_sk(w, "triumph_of_valhalla", "Triumph of Valhalla", "ATK +80% คริ +20% วิ่งเร็ว +20% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.8, "crit": 0.2, "speed": 0.2, "secs": 60.0}}, "color": Color("ffd84a"), "icon": "roar"}),
		_sk(w, "gladiator", "Gladiator", "การฟันสังหารสุดยอดของนักดาบในตำนาน", 100, 130, 14.0, "single", 26.0, {"range": 3.8, "color": Color("ff3a3a"), "icon": "sword"}),
	]
	var a := &"archer"
	_pools[a] = [
		_sk(a, "wind_arrow", "Wind Arrow", "ลูกศรลมพุ่งเร็วใส่ศัตรูตัวเดียว", 10, 9, 3.0, "single", 3.0, {"color": Color("8fff9a"), "vfx": &"leaf", "icon": "arrow"}),
		_sk(a, "perfect_aim", "Perfect Aim", "เล็งแม่นยำ ยิงแรงจากระยะไกล", 10, 12, 5.0, "single", 3.8, {"range": 14.0, "color": Color("ffd84a"), "icon": "arrow"}),
		_sk(a, "scout_hawk", "Scout Hawk", "เหยี่ยวสอดแนม ATK +20% คริติคอล +12% นาน 1 นาที", 13, 16, 28.0, "self", 0.0, {"fx": {"buff": {"atk": 0.2, "crit": 0.12, "secs": 60.0}}, "color": Color("ffd27a"), "icon": "boots"}),
		_sk(a, "arrow_of_rage", "Arrow of Rage", "ยิง 3 ดอกพร้อมกัน", 16, 18, 7.0, "fan", 2.0, {"hits": 3, "color": Color("b8f07a"), "icon": "triple"}),
		_sk(a, "avalanche", "Avalanche", "ห่าลูกศรถล่มพื้นที่เป้าหมาย", 20, 24, 10.0, "blast", 3.2, {"radius": 4.5, "special": "rain", "color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"}),
		_sk(a, "elemental_shot", "Elemental Shot", "ลูกศรธาตุไฟ ติดไฟต่อเนื่อง", 24, 22, 6.0, "single", 5.0, {"fx": {"burn": [0.35, 4.0]}, "vfx": &"fireball", "color": Color("ff7a2a"), "icon": "fire"}),
		_sk(a, "golden_falcon", "Golden Falcon", "เรียกเหยี่ยวทองบินโจมตีศัตรูนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล) และฟื้นฟู HP ให้คุณเมื่อมันโจมตี", 28, 30, 30.0, "summon", 2.4, {"summon": {"kind": "falcon", "count": 1, "secs": 180.0, "interval": 1.0, "heal": 0.01}, "color": Color("ffe27a"), "icon": "triple"}),
		_sk(a, "bomb_shot", "Bomb Shot", "ลูกศรระเบิดสร้างความเสียหายเป็นวง ติดไฟ", 32, 32, 10.0, "blast", 4.2, {"radius": 4.5, "fx": {"burn": [0.3, 4.0]}, "vfx": &"fireball", "color": Color("ff8a3a"), "icon": "fire"}),
		_sk(a, "perforation", "Perforation", "ลูกศรเจาะทะลวงเกราะ แรงมาก", 36, 32, 8.0, "single", 7.0, {"range": 16.0, "color": Color("ffe27a"), "icon": "arrow"}),
		_sk(a, "recall_wolverine", "Recall Wolverine", "เรียกหมาป่า 2 ตัวกระโจนกัดศัตรูนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 40, 40, 34.0, "summon", 3.2, {"summon": {"kind": "wolf", "count": 2, "secs": 180.0, "interval": 0.9}, "color": Color("c9e8a0"), "icon": "triple"}),
		_sk(a, "phoenix_shot", "Phoenix Shot", "ลูกศรนกฟีนิกซ์ แรงมหาศาล ติดไฟแรง", 44, 44, 12.0, "single", 9.0, {"range": 16.0, "fx": {"burn": [0.5, 5.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(a, "dionic_sight", "Dionic Sight", "ตาแห่งสวรรค์ คริติคอล +30% ATK +20% นาน 1 นาที", 52, 52, 36.0, "self", 0.0, {"fx": {"buff": {"crit": 0.3, "atk": 0.2, "secs": 60.0}}, "color": Color("ffe27a"), "icon": "boots"}),
		_sk(a, "lethal_sight", "Lethal Sight", "เล็งสังหาร ยิงแรงมากจากระยะไกล", 56, 54, 9.0, "single", 10.5, {"range": 17.0, "color": Color("ffd84a"), "icon": "arrow"}),
		_sk(a, "fierce_wind", "Fierce Wind", "ลมกระโชกยิงลูกศร 7 ดอกพร้อมกัน", 60, 62, 11.0, "fan", 5.5, {"hits": 7, "range": 13.0, "color": Color("8fffd0"), "icon": "triple"}),
		_sk(a, "force_of_nature", "Force of Nature", "เรียกอสูรแห่งธรรมชาติ 2 ตัวมาช่วยรบนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 64, 80, 36.0, "summon", 4.6, {"summon": {"kind": "beast", "count": 2, "secs": 180.0, "interval": 1.1}, "color": Color("7aff8a"), "icon": "triple"}),
		_sk(a, "ensnare", "Ensnare", "ห่าลูกศรบ่วงพันธนาการ ศัตรูช้าลง 5 วินาที", 68, 66, 13.0, "blast", 8.0, {"radius": 6.0, "special": "rain", "fx": {"slow": 5.0}, "color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"}),
		_sk(a, "hurricane", "Hurricane", "พายุลมถล่มรอบตัว ศัตรูช้าลง 3 วินาที", 72, 74, 12.0, "burst", 10.0, {"radius": 7.0, "fx": {"slow": 3.0}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		_sk(a, "arrow_of_thunder", "Arrow of Thunder", "ลูกศรสายฟ้ากระโดดไปหาศัตรู 6 ตัว", 76, 78, 12.0, "chain", 6.0, {"hits": 6, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(a, "tempest", "Tempest", "ห่าลูกศรพายุถล่มพื้นที่กว้าง", 80, 96, 16.0, "blast", 14.0, {"radius": 8.0, "special": "rain", "color": Color("ffd84a"), "vfx": &"leaf", "icon": "rain"}),
		_sk(a, "lightning_arrow", "Lightning Arrow", "ลูกศรสายฟ้าฟาดศัตรูตัวเดียว", 84, 92, 10.0, "single", 19.0, {"range": 18.0, "vfx": &"thunder", "color": Color("fff06a"), "icon": "bolt"}),
		_sk(a, "phoenix_rain", "Phoenix Rain", "ฝนลูกศรเพลิงฟีนิกซ์ ติดไฟรุนแรง", 88, 104, 18.0, "blast", 15.0, {"radius": 8.5, "special": "rain", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(a, "spirit_of_wind", "Spirit of the Wind", "วิ่งเร็ว +40% ATK +50% คริ +15% นาน 1 นาที", 92, 100, 45.0, "self", 0.0, {"fx": {"buff": {"speed": 0.4, "atk": 0.5, "crit": 0.15, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
		_sk(a, "dragon_shot", "Dragon Shot", "ลูกศรมังกร 10 ดอกพุ่งใส่ศัตรู", 96, 118, 16.0, "fan", 6.5, {"hits": 10, "range": 14.0, "vfx": &"fireball", "color": Color("ff8a3a"), "icon": "triple"}),
		_sk(a, "meteor_arrow", "Meteor Arrow", "ลูกศรอุกกาบาตจากฟ้า พลังทำลายล้างสูงสุด", 100, 140, 15.0, "single", 28.0, {"range": 20.0, "vfx": &"fireball", "fx": {"burn": [0.6, 6.0]}, "color": Color("ff5a2a"), "icon": "meteor"}),
	]
	var m := &"mage"
	_pools[m] = [
		_sk(m, "agony", "Agony", "คำสาปทรมาน ทำร้ายศัตรูและทำให้ช้าลง 2 วินาที", 10, 10, 3.0, "single", 2.8, {"fx": {"slow": 2.0}, "color": Color("b79bff"), "icon": "light"}),
		_sk(m, "fire_bolt", "Fire Bolt", "ลูกไฟพุ่งใส่ศัตรู ติดไฟต่อเนื่อง", 10, 12, 4.0, "single", 3.4, {"fx": {"burn": [0.3, 4.0]}, "vfx": &"fireball", "color": Color("ff7a2a"), "icon": "fire"}),
		_sk(m, "zenith", "Zenith", "พลังป้องกัน +30% ATK +12% นาน 1 นาที", 13, 18, 30.0, "self", 0.0, {"fx": {"buff": {"def": 0.3, "atk": 0.12, "secs": 60.0}}, "color": Color("8ecbff"), "icon": "bless"}),
		_sk(m, "fire_ball", "Fire Ball", "ลูกไฟยักษ์ระเบิดเป็นวง", 16, 22, 8.0, "blast", 3.6, {"radius": 3.8, "special": "boom", "fx": {"burn": [0.25, 4.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(m, "watornado", "Watornado", "พายุน้ำหมุนวนถล่มพื้นที่ ศัตรูช้าลง", 20, 26, 10.0, "blast", 3.6, {"radius": 5.2, "fx": {"slow": 3.5}, "vfx": &"frost", "color": Color("7fdcff"), "icon": "ice"}),
		_sk(m, "enchant_weapon", "Enchant Weapon", "ใส่เวทธาตุให้อาวุธ ATK +35% นาน 1 นาที", 24, 26, 30.0, "self", 0.0, {"fx": {"buff": {"atk": 0.35, "secs": 60.0}}, "color": Color("ff9a5a"), "icon": "bless"}),
		_sk(m, "dead_ray", "Dead Ray", "รังสีมรณะแรงสูงใส่ศัตรูตัวเดียว", 28, 30, 7.0, "single", 6.4, {"range": 12.0, "vfx": &"thunder", "color": Color("fff06a"), "icon": "bolt"}),
		_sk(m, "energy_shield", "Energy Shield", "โล่พลังงาน DEF +60% นาน 1 นาที", 31, 32, 32.0, "self", 0.0, {"fx": {"buff": {"def": 0.6, "secs": 60.0}}, "color": Color("7fdcff"), "icon": "shield"}),
		_sk(m, "diastrophism", "Diastrophism", "แผ่นดินไหวถล่มพื้นที่กว้าง ศัตรูมึนงง", 35, 46, 14.0, "blast", 5.4, {"radius": 7.0, "special": "meteor", "fx": {"stun": 1.2}, "color": Color("c8a060"), "icon": "meteor"}),
		_sk(m, "spirit_elemental", "Spirit Elemental", "เรียกวิญญาณธาตุยิงเวทใส่ศัตรูนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 39, 40, 34.0, "summon", 4.2, {"summon": {"kind": "elemental", "count": 1, "secs": 180.0, "interval": 1.3}, "color": Color("7fe3ff"), "icon": "bless"}),
		_sk(m, "dancing_sword", "Dancing Sword", "เรียกดาบเวท 3 เล่มร่ายรำฟันศัตรูนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 43, 42, 30.0, "summon", 2.6, {"summon": {"kind": "sword", "count": 3, "secs": 180.0, "interval": 0.7}, "color": Color("e6f4ff"), "icon": "bolt"}),
		_sk(m, "flame_wave", "Flame Wave", "คลื่นเพลิงถาโถมรอบตัว เผาศัตรูทุกตัว", 47, 56, 14.0, "burst", 6.0, {"radius": 7.0, "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "fire"}),
		_sk(m, "distortion", "Distortion", "บิดมิติรอบตัว ศัตรูช้าลง 4 วินาที", 52, 62, 12.0, "burst", 7.5, {"radius": 7.0, "fx": {"slow": 4.0}, "color": Color("b79bff"), "icon": "nova"}),
		_sk(m, "fire_elemental", "Fire Elemental", "เรียกเอเลเมนทัลไฟยักษ์ยิงลูกไฟนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 56, 80, 36.0, "summon", 6.0, {"summon": {"kind": "fire_elemental", "count": 1, "secs": 180.0, "interval": 1.2}, "color": Color("ff7a2a"), "icon": "fire"}),
		_sk(m, "meteo", "Meteo", "อุกกาบาตตกใส่พื้นที่ ติดไฟ", 60, 90, 16.0, "blast", 11.0, {"radius": 8.0, "special": "meteor", "fx": {"burn": [0.4, 5.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "meteor"}),
		_sk(m, "silraphim", "Silraphim", "ATK +50% DEF +30% นาน 1 นาที", 64, 70, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.3, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		_sk(m, "slow_speed", "Slow Speed", "เวทหน่วงเวลา ศัตรูช้าลงมาก 6 วินาที", 68, 72, 12.0, "blast", 8.0, {"radius": 7.0, "fx": {"slow": 6.0}, "vfx": &"frost", "color": Color("7fdcff"), "icon": "ice"}),
		_sk(m, "vague", "Vague", "ร่างพร่าเลือน DEF +70% วิ่งเร็ว +20% นาน 1 นาที", 72, 78, 40.0, "self", 0.0, {"fx": {"buff": {"def": 0.7, "speed": 0.2, "secs": 60.0}}, "color": Color("b79bff"), "icon": "shield"}),
		_sk(m, "thunder_storm", "Thunder Storm", "พายุสายฟ้ากระโดดฟาดศัตรู 8 ตัว", 76, 86, 12.0, "chain", 6.2, {"hits": 8, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(m, "hell_meteor", "Hell Meteor", "อุกกาบาตนรกถล่มพื้นที่กว้าง ติดไฟแรง", 80, 110, 18.0, "blast", 16.0, {"radius": 9.0, "special": "meteor", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff3a2a"), "icon": "meteor"}),
		_sk(m, "ice_storm", "Ice Storm", "พายุน้ำแข็งถล่มพื้นที่กว้าง ศัตรูช้าลง", 84, 112, 16.0, "blast", 15.0, {"radius": 9.0, "fx": {"slow": 5.0}, "vfx": &"frost", "color": Color("aaf0ff"), "icon": "ice"}),
		_sk(m, "spirit_burst", "Spirit Burst", "วิญญาณระเบิดรอบตัวสร้างความเสียหายมหาศาล", 88, 120, 16.0, "burst", 14.0, {"radius": 9.0, "vfx": &"fireball", "color": Color("ffb04a"), "icon": "nova"}),
		_sk(m, "magic_overdrive", "Magic Overdrive", "ATK +90% คริ +15% นาน 1 นาที", 92, 120, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.9, "crit": 0.15, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		_sk(m, "judgment_ray", "Judgment Ray", "รังสีพิพากษาจากสวรรค์ใส่ศัตรูตัวเดียว", 96, 130, 12.0, "single", 24.0, {"range": 14.0, "vfx": &"thunder", "color": Color("fff0a0"), "icon": "bolt"}),
		_sk(m, "armageddon", "Armageddon", "วันสิ้นโลก อุกกาบาตมหาศาลถล่มทั้งพื้นที่", 100, 180, 24.0, "blast", 22.0, {"radius": 11.0, "special": "meteor", "fx": {"burn": [0.7, 8.0]}, "vfx": &"fireball", "color": Color("ff2a1a"), "icon": "meteor"}),
	]
	var p := &"priest"
	_pools[p] = [
		_sk(p, "holy_bolt", "Holy Bolt", "ลำแสงศักดิ์สิทธิ์โจมตีศัตรูตัวเดียว", 10, 10, 3.0, "single", 2.9, {"color": Color("fff2a0"), "icon": "light"}),
		_sk(p, "healing", "Healing", "ฟื้นฟู HP ของตัวเอง 40%", 10, 14, 9.0, "self", 0.0, {"fx": {"heal": 0.4}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(p, "multi_spark", "Multi Spark", "ยิงลูกประกายสายฟ้า 4 ลูก", 14, 18, 7.0, "fan", 2.0, {"hits": 4, "vfx": &"thunder", "color": Color("fff06a"), "icon": "triple"}),
		_sk(p, "holy_mind", "Holy Mind", "จิตศักดิ์สิทธิ์ ทำร้ายและทำให้ศัตรูช้าลง 4 วินาที", 17, 20, 10.0, "single", 3.4, {"fx": {"slow": 4.0}, "color": Color("ffe9a0"), "icon": "light"}),
		_sk(p, "divine_lightning", "Divine Lightning", "สายฟ้าสวรรค์กระโดดไปหาศัตรูสูงสุด 5 ตัว", 20, 26, 9.0, "chain", 2.8, {"hits": 5, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(p, "holy_reflection", "Holy Reflection", "โล่แสงสะท้อน DEF +45% นาน 1 นาที", 24, 28, 30.0, "self", 0.0, {"fx": {"buff": {"def": 0.45, "secs": 60.0}}, "anim": "Spellcast_Raise", "color": Color("fff0a0"), "icon": "shield"}),
		_sk(p, "grand_healing", "Grand Healing", "ฟื้นฟู HP 65%", 28, 38, 16.0, "self", 0.0, {"fx": {"heal": 0.65}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(p, "vigor_ball", "Vigor Ball", "ลูกพลังชีวิต 5 ลูกพุ่งใส่ศัตรู", 32, 34, 9.0, "fan", 3.0, {"hits": 5, "color": Color("ffe9a0"), "icon": "triple"}),
		_sk(p, "extinction", "Extinction", "คลื่นแสงล้างบาปรอบตัว ฟื้นฟู HP 10%", 36, 46, 14.0, "burst", 5.2, {"radius": 6.5, "fx": {"heal": 0.1}, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "virtual_life", "Virtual Life", "พลังชีวิตจำลอง ฟื้นฟู HP 30% ATK +20% DEF +30% นาน 1 นาที", 40, 44, 34.0, "self", 0.0, {"fx": {"heal": 0.3, "buff": {"atk": 0.2, "def": 0.3, "secs": 60.0}}, "vfx": &"aura", "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		_sk(p, "glacial_spike", "Glacial Spike", "หอกน้ำแข็งแทงพื้น ศัตรูช้าลง", 44, 50, 14.0, "blast", 6.0, {"radius": 6.0, "fx": {"slow": 4.0}, "vfx": &"frost", "color": Color("aaf0ff"), "icon": "ice"}),
		_sk(p, "resurrection", "Resurrection", "ฟื้นฟู HP 100% และ DEF +35% นาน 1 นาที", 48, 60, 45.0, "self", 0.0, {"fx": {"heal": 1.0, "buff": {"def": 0.35, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		_sk(p, "summon_muspell", "Summon Muspell", "เรียกวิญญาณพิทักษ์ผู้ยิ่งใหญ่มาช่วยรบนาน 3 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 52, 80, 36.0, "summon", 4.4, {"summon": {"kind": "muspell", "count": 1, "secs": 180.0, "interval": 1.2}, "color": Color("aaf0ff"), "icon": "nova"}),
		_sk(p, "regeneration_field", "Regeneration Field", "ฟื้นฟู HP 50% DEF +30% นาน 1 นาที", 56, 76, 28.0, "self", 0.0, {"fx": {"heal": 0.5, "buff": {"def": 0.3, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(p, "chain_lightning", "Chain Lightning", "สายฟ้าสวรรค์ฟาดศัตรู 8 ตัว", 60, 70, 11.0, "chain", 5.5, {"hits": 8, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(p, "blessing_aura", "Blessing Aura", "ATK +50% DEF +40% นาน 1 นาที", 64, 84, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.4, "secs": 60.0}}, "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		_sk(p, "judgement_light", "Judgement", "แสงพิพากษาตกใส่พื้นที่", 68, 80, 12.0, "blast", 10.0, {"radius": 7.0, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "hand_of_god", "Hand of God", "มือพระเจ้า ฟื้นฟู HP 90%", 72, 96, 24.0, "self", 0.0, {"fx": {"heal": 0.9}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		_sk(p, "heaven_light", "Heaven Light", "แสงสวรรค์ถล่มรอบตัว ฟื้นฟู HP 15%", 76, 100, 14.0, "burst", 10.5, {"radius": 8.0, "fx": {"heal": 0.15}, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "divine_judgment", "Divine Judgment", "คำพิพากษาแห่งสวรรค์ ศัตรูมึนงง 1.5 วินาที", 80, 110, 16.0, "blast", 15.0, {"radius": 9.0, "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("ffffff"), "icon": "nova"}),
		_sk(p, "prayer", "Prayer", "สวดมนต์ ฟื้นฟู HP 100% และ DEF +50% นาน 1 นาที", 84, 120, 50.0, "self", 0.0, {"fx": {"heal": 1.0, "buff": {"def": 0.5, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		_sk(p, "seraphim_wrath", "Seraphim Wrath", "ลูกแสงเสราฟิม 9 ลูกพุ่งใส่ศัตรู", 88, 118, 14.0, "fan", 5.5, {"hits": 9, "color": Color("fff0a0"), "icon": "triple"}),
		_sk(p, "holy_rain_big", "Holy Rain", "ฝนแสงศักดิ์สิทธิ์ถล่มพื้นที่กว้างมาก", 92, 130, 18.0, "blast", 16.0, {"radius": 10.0, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "miracle", "Miracle", "ปาฏิหาริย์ ATK +80% DEF +60% ฟื้นฟู HP 50% นาน 1 นาที", 96, 140, 55.0, "self", 0.0, {"fx": {"heal": 0.5, "buff": {"atk": 0.8, "def": 0.6, "secs": 60.0}}, "vfx": &"aura", "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		_sk(p, "last_judgement", "Last Judgement", "การพิพากษาครั้งสุดท้ายถล่มพื้นที่ ศัตรูมึนงง 2 วินาที", 100, 180, 24.0, "blast", 24.0, {"radius": 12.0, "fx": {"stun": 2.0}, "vfx": &"light", "color": Color("ffffff"), "icon": "nova"}),
	]
	var s := &"summoner"
	var sm := func(id: String, name: String, desc: String, level: int, mp: int, cd: float, mult: float, kind: String, count: int, interval: float, color: Color, extra := {}) -> Dictionary:
		var spec := {"kind": kind, "count": count, "secs": 180.0, "interval": interval}
		spec.merge(extra.get("spec", {}))
		return _sk(s, id, name, desc + " (นาน 3 นาทีหรือจนกว่าจะถูกสังหาร ใหญ่ขึ้นตามดาวสกิล)", level, mp, cd, "summon", mult, {"summon": spec, "color": color, "icon": "triple"})
	_pools[s] = [
		_sk(s, "thorn_shot", "Thorn Shot", "ยิงหนามธรรมชาติใส่ศัตรูตัวเดียว", 10, 9, 3.0, "single", 2.9, {"color": Color("a8f07a"), "icon": "arrow"}),
		sm.call("spirit_cat", "Spirit Cat", "เรียกแมววิญญาณกระโจนข่วนศัตรู", 10, 14, 24.0, 2.2, "cat", 1, 0.8, Color("ffd8a0")),
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
		sm.call("wind_drake", "Wind Drake", "เรียกมังกรลมบินพ่นลมใส่ศัตรู", 84, 100, 40.0, 12.0, "drake", 1, 1.2, Color("7affd0")),
		_sk(s, "gaia_blessing", "Gaia's Blessing", "ฟื้นฟู HP 40% DEF +60% ATK +40% นาน 1 นาที (ส่งถึงทีมและอสูร)", 88, 96, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 0.6, "atk": 0.4, "secs": 60.0}}, "vfx": &"heal", "color": Color("d8ffb0"), "icon": "bless"}),
		sm.call("primal_legion", "Primal Legion", "เรียกอสูรป่าดึกดำบรรพ์ 3 ตัว", 92, 110, 45.0, 10.0, "beast", 3, 1.0, Color("7aff8a")),
		_sk(s, "cataclysm", "Cataclysm", "ธรรมชาติพิโรธ ถล่มรอบตัวอย่างรุนแรง", 96, 118, 16.0, "burst", 22.0, {"radius": 9.0, "vfx": &"leaf", "color": Color("b8ff7a"), "icon": "spin"}),
		sm.call("elder_dragon", "Elder Dragon", "เรียกมังกรโบราณผู้เป็นตำนาน", 100, 150, 50.0, 28.0, "elder_dragon", 1, 1.2, Color("ffd84a")),
	]
	var l := &"lancer"
	var pc := func(n: int, length: float, width := 1.3, keep := 0.7) -> Dictionary:
		return {"n": n, "len": length, "w": width, "k": keep}
	_pools[l] = [
		_sk(l, "thrust", "Thrust", "แทงหอกใส่ศัตรูตัวเดียว ทะลุไปโดนตัวหลังอีก 2 ตัว", 10, 9, 3.0, "single", 3.0, {"pierce": pc.call(2, 6.5), "color": Color("9ad8ff"), "icon": "sword"}),
		_sk(l, "stagger", "Stagger", "ด้ามหอกกระแทก ศัตรูมึนงง 1.2 วินาที", 10, 12, 6.0, "single", 3.2, {"fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
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
