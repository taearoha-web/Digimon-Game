class_name ClassData
extends RefCounted
## Hero classes: the Vagabond (Lv.1-9) and the lines chosen at Lv.10 (sword,
## bow, mage, priest, summoner, spear, great shield, twin daggers, scepter and raven, lute). Each class has a pool of active skills modelled on
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
const IDS: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard"]

const CLASSES := {
	&"vagabond": {
		"name": "นักเดินทาง",
		"title": "ผู้ยังไม่เลือกเส้นทาง",
		"badge": "V",
		"desc": "นักเดินทางไร้สังกัด ถือดาบสั้นสู้ประชิดตัว พอถึงเลเวล 10 จะเลือกสายได้: สายดาบ สายธนู นักเวทย์ นักบวช ผู้เรียกอสูร นักหอก สายโล่ นักฆ่ามีดคู่ ดาร์กลอร์ด หรือนักดนตรี",
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
	&"defender": [
		{"id": "shield_mastery", "name": "Shield Mastery", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 10, "bonus": {"def": 0.04}},
		{"id": "iron_body", "name": "Iron Body", "desc": "HP สูงสุด +5% ต่อดาว", "level": 20, "bonus": {"hp": 0.05}},
		{"id": "bash_mastery", "name": "Bash Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 30, "bonus": {"atk": 0.025}},
		{"id": "stalwart", "name": "Stalwart", "desc": "พลังป้องกัน +4% ต่อดาว", "level": 40, "bonus": {"def": 0.04}},
		{"id": "heavy_impact", "name": "Heavy Impact", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "living_fortress", "name": "Living Fortress", "desc": "HP +4% และพลังป้องกัน +3% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "def": 0.03}},
	],
	&"assassin": [
		{"id": "dagger_mastery", "name": "Dagger Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "shadow_footwork", "name": "Shadow Footwork", "desc": "ความเร็ว +2% และหลบ +0.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.02, "dodge": 0.006}},
		{"id": "lethal_precision", "name": "Lethal Precision", "desc": "คริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"crit": 0.015}},
		{"id": "evasive_instinct", "name": "Evasive Instinct", "desc": "หลบหลีก +1% ต่อดาว", "level": 40, "bonus": {"dodge": 0.01}},
		{"id": "killer_instinct", "name": "Killer Instinct", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "night_stalker", "name": "Night Stalker", "desc": "คริติคอล +1% และความเร็ว +2% ต่อดาว", "level": 80, "bonus": {"crit": 0.01, "speed": 0.02}},
	],
	&"darklord": [
		{"id": "scepter_mastery", "name": "Scepter Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "royal_vigor", "name": "Royal Vigor", "desc": "HP สูงสุด +4% ต่อดาว", "level": 20, "bonus": {"hp": 0.04}},
		{"id": "command_presence", "name": "Command Presence", "desc": "พลังป้องกัน +3% และ MP +3% ต่อดาว", "level": 30, "bonus": {"def": 0.03, "mp": 0.03}},
		{"id": "raven_bond", "name": "Raven Bond", "desc": "คริติคอล +1.5% ต่อดาว", "level": 40, "bonus": {"crit": 0.015}},
		{"id": "dark_dominion", "name": "Dark Dominion", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "emperor_will", "name": "Emperor's Will", "desc": "HP +4% และพลังป้องกัน +3% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "def": 0.03}},
	],
	&"bard": [
		{"id": "lute_mastery", "name": "Lute Mastery", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 10, "bonus": {"atk": 0.025}},
		{"id": "breath_control", "name": "Breath Control", "desc": "MP สูงสุด +5% ต่อดาว", "level": 20, "bonus": {"mp": 0.05}},
		{"id": "stage_presence", "name": "Stage Presence", "desc": "HP สูงสุด +4% ต่อดาว", "level": 30, "bonus": {"hp": 0.04}},
		{"id": "perfect_pitch", "name": "Perfect Pitch", "desc": "คริติคอล +1.5% ต่อดาว", "level": 40, "bonus": {"crit": 0.015}},
		{"id": "harmonic_power", "name": "Harmonic Power", "desc": "พลังโจมตี +2.5% ต่อดาว", "level": 60, "bonus": {"atk": 0.025}},
		{"id": "standing_ovation", "name": "Standing Ovation", "desc": "HP +4% และพลังป้องกัน +3% ต่อดาว", "level": 80, "bonus": {"hp": 0.04, "def": 0.03}},
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
static func default_loadout(class_id: StringName, level: int, current: Array = [], tier := 3, stars := 0) -> Array:
	var out: Array = []
	for i in SLOTS:
		out.append(String(current[i]) if i < current.size() else "")
	var pool_skills := pool(class_id)
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
	&"warrior": [[1.016, 1.016], [0.403, 0.403], [1.032, 1.183]],
	&"archer": [[0.527, 0.527], [0.515, 0.515], [0.676, 0.676]],
	&"mage": [[0.441, 0.36], [1.33, 0.34], [1.73, 0.789]],
	&"priest": [[1.718, 1.718], [0.74, 0.74], [1.8, 1.8]],
	&"summoner": [[0.872, 0.872], [1.499, 1.385], [1.087, 1.242]],
	&"lancer": [[0.691, 0.691], [0.553, 0.737], [0.793, 0.793]],
	&"defender": [[1.395, 1.395], [1.647, 1.796], [1.8, 1.61]],
	&"assassin": [[0.922, 0.922], [0.834, 0.834], [0.809, 0.809]],
	&"darklord": [[0.95, 0.95], [0.85, 0.85], [0.95, 0.95]],
	&"bard": [[1.05, 0.66], [0.55, 1.05], [0.92, 0.56]],
}
const AREA_SHAPES := ["burst", "blast", "fan", "chain"]


## The tuning factor of a class's skill: its band (by unlock level; star
## skills belong to the last band) and whether it strikes one target or an area.
static func skill_tune(cls: StringName, level: int, star: bool, shape: String) -> float:
	var area := shape in AREA_SHAPES
	var band := 2 if star or level > 75 else (1 if level > 35 else 0)
	var table: Array = TUNE.get(cls, [[1.0, 1.0], [1.0, 1.0], [1.0, 1.0]])
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
		_sk(a, "golden_falcon", "Golden Falcon", "เรียกเหยี่ยวทองบินโจมตีศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล) และฟื้นฟู HP ให้คุณเมื่อมันโจมตี", 28, 30, 30.0, "summon", 2.4, {"summon": {"kind": "falcon", "count": 1, "secs": 120.0, "interval": 1.0, "heal": 0.01}, "color": Color("ffe27a"), "icon": "triple"}),
		_sk(a, "bomb_shot", "Bomb Shot", "ลูกศรระเบิดสร้างความเสียหายเป็นวง ติดไฟ", 32, 32, 10.0, "blast", 4.2, {"radius": 4.5, "fx": {"burn": [0.3, 4.0]}, "vfx": &"fireball", "color": Color("ff8a3a"), "icon": "fire"}),
		_sk(a, "perforation", "Perforation", "ลูกศรเจาะทะลวงเกราะ แรงมาก", 36, 32, 8.0, "single", 7.0, {"range": 16.0, "color": Color("ffe27a"), "icon": "arrow"}),
		_sk(a, "recall_wolverine", "Recall Wolverine", "เรียกหมาป่า 2 ตัวกระโจนกัดศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 40, 40, 34.0, "summon", 3.2, {"summon": {"kind": "spirit_wolf", "count": 2, "secs": 120.0, "interval": 0.9}, "color": Color("c9e8a0"), "icon": "triple"}),
		_sk(a, "phoenix_shot", "Phoenix Shot", "ลูกศรนกฟีนิกซ์ แรงมหาศาล ติดไฟแรง", 44, 44, 12.0, "single", 9.0, {"range": 16.0, "fx": {"burn": [0.5, 5.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(a, "dionic_sight", "Dionic Sight", "ตาแห่งสวรรค์ คริติคอล +30% ATK +20% นาน 1 นาที", 52, 52, 36.0, "self", 0.0, {"fx": {"buff": {"crit": 0.3, "atk": 0.2, "secs": 60.0}}, "color": Color("ffe27a"), "icon": "boots"}),
		_sk(a, "lethal_sight", "Lethal Sight", "เล็งสังหาร ยิงแรงมากจากระยะไกล", 56, 54, 9.0, "single", 10.5, {"range": 17.0, "color": Color("ffd84a"), "icon": "arrow"}),
		_sk(a, "fierce_wind", "Fierce Wind", "ลมกระโชกยิงลูกศร 7 ดอกพร้อมกัน", 60, 62, 11.0, "fan", 5.5, {"hits": 7, "range": 13.0, "color": Color("8fffd0"), "icon": "triple"}),
		_sk(a, "force_of_nature", "Force of Nature", "เรียกอสูรแห่งธรรมชาติ 2 ตัวมาช่วยรบนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 64, 80, 36.0, "summon", 4.6, {"summon": {"kind": "cactus", "count": 2, "secs": 120.0, "interval": 1.1}, "color": Color("7aff8a"), "icon": "triple"}),
		_sk(a, "ensnare", "Ensnare", "ห่าลูกศรบ่วงพันธนาการ ศัตรูช้าลง 5 วินาที", 68, 66, 13.0, "blast", 8.0, {"radius": 6.0, "special": "rain", "fx": {"slow": 5.0}, "color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"}),
		_sk(a, "hurricane", "Hurricane", "พายุลมถล่มรอบตัว ศัตรูช้าลง 3 วินาที", 72, 74, 12.0, "burst", 10.0, {"radius": 7.0, "fx": {"slow": 3.0}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		_sk(a, "arrow_of_thunder", "Arrow of Thunder", "ลูกศรสายฟ้ากระโดดไปหาศัตรู 6 ตัว", 76, 78, 12.0, "chain", 6.0, {"hits": 6, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(a, "tempest", "Tempest", "ห่าลูกศรพายุถล่มพื้นที่กว้าง", 80, 96, 16.0, "blast", 14.0, {"radius": 8.0, "special": "rain", "color": Color("ffd84a"), "vfx": &"leaf", "icon": "rain"}),
		_sk(a, "lightning_arrow", "Lightning Arrow", "ลูกศรสายฟ้าฟาดศัตรูตัวเดียว", 84, 92, 10.0, "single", 19.0, {"range": 18.0, "vfx": &"thunder", "color": Color("fff06a"), "icon": "bolt"}),
		_sk(a, "phoenix_rain", "Phoenix Rain", "ฝนลูกศรเพลิงฟีนิกซ์ ติดไฟรุนแรง", 88, 104, 18.0, "blast", 15.0, {"radius": 8.5, "special": "rain", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		_sk(a, "spirit_of_wind", "Spirit of the Wind", "วิ่งเร็ว +40% ATK +60% คริ +15% นาน 1 นาที", 92, 100, 45.0, "self", 0.0, {"fx": {"buff": {"speed": 0.4, "atk": 0.6, "crit": 0.15, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
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
		_sk(m, "spirit_elemental", "Spirit Elemental", "เรียกวิญญาณธาตุยิงเวทใส่ศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 39, 40, 34.0, "summon", 4.2, {"summon": {"kind": "elemental", "count": 1, "secs": 120.0, "interval": 1.3}, "color": Color("7fe3ff"), "icon": "bless"}),
		_sk(m, "dancing_sword", "Dancing Sword", "เรียกดาบเวท 3 เล่มร่ายรำฟันศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 43, 42, 30.0, "summon", 2.6, {"summon": {"kind": "sword", "count": 3, "secs": 120.0, "interval": 0.7}, "color": Color("e6f4ff"), "icon": "bolt"}),
		_sk(m, "flame_wave", "Flame Wave", "คลื่นเพลิงถาโถมรอบตัว เผาศัตรูทุกตัว", 47, 56, 14.0, "burst", 6.0, {"radius": 7.0, "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "fire"}),
		_sk(m, "distortion", "Distortion", "บิดมิติรอบตัว ศัตรูช้าลง 4 วินาที", 52, 62, 12.0, "burst", 7.5, {"radius": 7.0, "fx": {"slow": 4.0}, "color": Color("b79bff"), "icon": "nova"}),
		_sk(m, "fire_elemental", "Fire Elemental", "เรียกเอเลเมนทัลไฟยักษ์ยิงลูกไฟนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 56, 80, 36.0, "summon", 6.0, {"summon": {"kind": "fire_elemental", "count": 1, "secs": 120.0, "interval": 1.2}, "color": Color("ff7a2a"), "icon": "fire"}),
		_sk(m, "meteo", "Meteo", "อุกกาบาตตกใส่พื้นที่ ติดไฟ", 60, 90, 16.0, "blast", 11.0, {"radius": 8.0, "special": "meteor", "fx": {"burn": [0.4, 5.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "meteor"}),
		_sk(m, "silraphim", "Silraphim", "ATK +50% DEF +30% นาน 1 นาที", 64, 70, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.3, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		_sk(m, "slow_speed", "Slow Speed", "เวทหน่วงเวลา ศัตรูช้าลงมาก 6 วินาที", 68, 72, 12.0, "blast", 8.0, {"radius": 7.0, "fx": {"slow": 6.0}, "vfx": &"frost", "color": Color("7fdcff"), "icon": "ice"}),
		_sk(m, "vague", "Vague", "ร่างพร่าเลือน DEF +70% วิ่งเร็ว +20% นาน 1 นาที", 72, 78, 40.0, "self", 0.0, {"fx": {"buff": {"def": 0.7, "speed": 0.2, "secs": 60.0}}, "color": Color("b79bff"), "icon": "shield"}),
		_sk(m, "thunder_storm", "Thunder Storm", "เมฆพายุสุ่มผ่าศัตรูสูงสุด 5 ตัวต่อระลอก รวม 3 ระลอก ห่างกัน 0.75 วินาที รัศมีเท่า Ice Storm", 76, 86, 12.0, "blast", 6.2, {"radius": 9.0, "vfx": &"thunder", "color": Color("dceaff"), "icon": "bolt"}),
		_sk(m, "hell_meteor", "Hell Meteor", "อุกกาบาตนรกถล่มพื้นที่กว้าง ติดไฟแรง", 80, 110, 18.0, "blast", 16.0, {"radius": 9.0, "special": "meteor", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff3a2a"), "icon": "meteor"}),
		_sk(m, "ice_storm", "Ice Storm", "พายุน้ำแข็งถล่มพื้นที่กว้าง ศัตรูช้าลง", 84, 112, 16.0, "blast", 15.0, {"radius": 9.0, "fx": {"slow": 5.0}, "vfx": &"frost", "color": Color("aaf0ff"), "icon": "ice"}),
		_sk(m, "spirit_burst", "Spirit Burst", "วิญญาณระเบิดรอบตัวสร้างความเสียหายมหาศาล", 88, 120, 16.0, "burst", 14.0, {"radius": 9.0, "vfx": &"light", "color": Color("b698f2"), "icon": "nova"}),
		_sk(m, "magic_overdrive", "Magic Overdrive", "ATK +90% คริ +15% นาน 1 นาที", 92, 120, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.9, "crit": 0.15, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		_sk(m, "judgment_ray", "Judgment Ray", "เปิดตราพิพากษาบนฟ้า เรียกเสาแสงทองขาวลงใส่เป้าหมายเดียวอย่างรุนแรง 1 ครั้ง", 96, 130, 12.0, "single", 24.0, {"range": 14.0, "projectile": false, "hit_delay": 1.05, "vfx": &"light", "color": Color("fff0a0"), "icon": "bolt"}),
		_sk(m, "armageddon", "Armageddon", "อุกกาบาตยักษ์ถล่มพื้น แตกเป็นสะเก็ดไฟ 10 ลูก ระเบิดทีละลูกทุก 0.5 วินาที ทำความเสียหายและเผาไหม้ทุกฮิต", 100, 180, 24.0, "blast", 22.0, {"radius": 11.0, "special": "meteor", "fx": {"burn": [0.7, 8.0]}, "vfx": &"fireball", "color": Color("ff2a1a"), "icon": "meteor"}),
	]
	var p := &"priest"
	_pools[p] = [
		_sk(p, "holy_bolt", "Holy Bolt", "ลำแสงศักดิ์สิทธิ์โจมตีศัตรูตัวเดียว", 10, 10, 3.0, "single", 3.2, {"color": Color("fff2a0"), "icon": "light"}),
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
		_sk(p, "summon_muspell", "Summon Muspell", "เรียกวิญญาณพิทักษ์ผู้ยิ่งใหญ่มาช่วยรบนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 52, 80, 36.0, "summon", 4.4, {"summon": {"kind": "muspell", "count": 1, "secs": 120.0, "interval": 1.2}, "color": Color("aaf0ff"), "icon": "nova"}),
		_sk(p, "regeneration_field", "Regeneration Field", "ฟื้นฟู HP 50% DEF +30% นาน 1 นาที", 56, 76, 28.0, "self", 0.0, {"fx": {"heal": 0.5, "buff": {"def": 0.3, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("6dff9a"), "icon": "heal"}),
		_sk(p, "chain_lightning", "Chain Lightning", "สายฟ้าสวรรค์ฟาดศัตรู 8 ตัว", 60, 70, 11.0, "chain", 5.5, {"hits": 8, "color": Color("fff06a"), "icon": "bolt"}),
		_sk(p, "blessing_aura", "Blessing Aura", "ATK +50% DEF +40% นาน 1 นาที", 64, 84, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.4, "secs": 60.0}}, "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		_sk(p, "judgement_light", "Judgement", "แสงพิพากษาผ่าลงใส่ศัตรูตัวเดียว", 68, 80, 12.0, "single", 10.0, {"projectile": false, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "hand_of_god", "Hand of God", "มือพระเจ้า ฟื้นฟู HP 90%", 72, 96, 24.0, "self", 0.0, {"fx": {"heal": 0.9}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		_sk(p, "heaven_light", "Heaven Light", "แสงสวรรค์ถล่มรอบตัว ฟื้นฟู HP 15%", 76, 100, 14.0, "burst", 10.5, {"radius": 8.0, "fx": {"heal": 0.15}, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "divine_judgment", "Divine Judgment", "คำพิพากษาแห่งสวรรค์ผ่าลงศัตรูตัวเดียว มึนงง 1.5 วินาที", 80, 110, 16.0, "single", 15.0, {"projectile": false, "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("ffffff"), "icon": "nova"}),
		_sk(p, "prayer", "Prayer", "สวดมนต์ ฟื้นฟู HP 100% และ DEF +50% นาน 1 นาที", 84, 120, 50.0, "self", 0.0, {"fx": {"heal": 1.0, "buff": {"def": 0.5, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		_sk(p, "seraphim_wrath", "Seraphim Wrath", "ลูกแสงเสราฟิม 9 ลูกพุ่งใส่ศัตรู", 88, 118, 14.0, "fan", 5.5, {"hits": 9, "color": Color("fff0a0"), "icon": "triple"}),
		_sk(p, "holy_rain_big", "Holy Rain", "ฝนแสงศักดิ์สิทธิ์ถล่มพื้นที่กว้างมาก", 92, 130, 18.0, "blast", 16.0, {"radius": 10.0, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		_sk(p, "miracle", "Miracle", "ปาฏิหาริย์ ATK +80% DEF +60% ฟื้นฟู HP 50% นาน 1 นาที", 96, 140, 55.0, "self", 0.0, {"fx": {"heal": 0.5, "buff": {"atk": 0.8, "def": 0.6, "secs": 60.0}}, "vfx": &"aura", "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		_sk(p, "last_judgement", "Last Judgement", "การพิพากษาครั้งสุดท้ายถล่มพื้นที่ ศัตรูมึนงง 2 วินาที", 100, 180, 24.0, "blast", 24.0, {"radius": 12.0, "fx": {"stun": 2.0}, "vfx": &"light", "color": Color("ffffff"), "icon": "nova"}),
	]
	var s := &"summoner"
	var sm := func(id: String, name: String, desc: String, level: int, mp: int, cd: float, mult: float, kind: String, count: int, interval: float, color: Color, extra := {}) -> Dictionary:
		var spec := {"kind": kind, "count": count, "secs": 120.0, "interval": interval}
		spec.merge(extra.get("spec", {}))
		return _sk(s, id, name, desc + " (นาน 2 นาทีหรือจนกว่าจะถูกสังหาร ใหญ่ขึ้นตามดาวสกิล)", level, mp, cd, "summon", mult, {"summon": spec, "color": color, "icon": "triple"})
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
		_sk(l, "thrust", "Thrust", "แทงหอกใส่ศัตรูตัวเดียว ทะลุไปโดนตัวหลังอีก 2 ตัว", 10, 9, 4.0, "single", 3.0, {"pierce": pc.call(2, 6.5), "color": Color("9ad8ff"), "icon": "sword"}),
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
	var d := &"defender"
	_pools[d] = [
		_sk(d, "shield_bash", "Shield Bash", "ฟาดขอบโล่ใส่ศัตรูตัวเดียว", 10, 10, 3.0, "single", 2.6, {"anim": "Block_Attack", "vfx": &"impact", "color": Color("bcd6f0"), "icon": "shield"}),
		_sk(d, "brace", "Brace", "ตั้งโล่รับ ลดความเสียหายที่ได้รับ 15% DEF +20% นาน 1 นาที", 10, 12, 25.0, "self", 0.0, {"fx": {"buff": {"guard": 0.15, "def": 0.2, "secs": 60.0}}, "anim": "Blocking", "color": Color("9fc4e8"), "icon": "shield"}),
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

	# Assassin: twin daggers and the shadows. Violet night, a crimson edge for the kills.
	var n := &"assassin"
	var night := Color("9a6bff")
	var blood := Color("ff4f7b")
	var venom := Color("8be260")
	_pools[n] = [
		_sk(n, "twin_fang", "Twin Fang", "ฟันมีดคู่ไขว้ใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 10, 8, 2.6, "single", 2.8, {"color": night, "icon": "sword"}),
		_sk(n, "shadow_veil", "Shadow Veil", "ม่านเงาห่อตัว หลบ +10% วิ่งเร็ว +15% นาน 1 นาที", 10, 12, 25.0, "self", 0.0, {"fx": {"buff": {"dodge": 0.1, "speed": 0.15, "secs": 60.0}}, "anim": "Dodge_Backward", "color": night, "icon": "boots"}),
		_sk(n, "venom_edge", "Venom Edge", "แทงคมพิษ ศัตรูติดพิษเสียเลือดต่อเนื่อง 5 วินาที", 14, 14, 5.0, "single", 3.4, {"fx": {"burn": [0.3, 5.0]}, "anim": "1H_Melee_Attack_Stab", "color": venom, "icon": "sword"}),
		_sk(n, "shadow_step", "Shadow Step", "ก้าวเงาวาร์ปไปหลังศัตรูไกลถึง 8 เมตรแล้วแทงซ้ำ", 17, 16, 7.0, "single", 4.0, {"range": 8.0, "anim": "1H_Melee_Attack_Stab", "color": night, "icon": "boots"}),
		_sk(n, "blade_flurry", "Blade Flurry", "หมุนมีดคู่เป็นพายุใบมีดรอบตัว", 20, 20, 8.0, "burst", 2.4, {"radius": 4.2, "special": "spin", "color": night, "icon": "spin"}),
		_sk(n, "fan_of_knives", "Fan of Knives", "ขว้างมีดเงาแผ่เป็นพัด 5 เล่ม", 24, 22, 8.0, "fan", 2.4, {"hits": 5, "range": 11.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": night, "icon": "triple"}),
		_sk(n, "killing_focus", "Killing Focus", "จิตนักฆ่า คริติคอล +15% ATK +25% นาน 1 นาที", 27, 24, 30.0, "self", 0.0, {"fx": {"buff": {"crit": 0.15, "atk": 0.25, "secs": 60.0}}, "color": blood, "icon": "roar"}),
		_sk(n, "backstab", "Backstab", "แทงทะลุหลังศัตรูตัวเดียว ความเสียหายรุนแรง", 31, 28, 7.0, "single", 6.0, {"range": 3.0, "anim": "1H_Melee_Attack_Stab", "color": blood, "icon": "sword"}),
		_sk(n, "smoke_bomb", "Smoke Bomb", "ปาระเบิดควัน ศัตรูรอบตัวมึนงง 1.2 วินาทีและช้าลง", 35, 30, 16.0, "burst", 1.2, {"radius": 5.0, "fx": {"stun": 1.2, "slow": 3.0}, "anim": "Dodge_Backward", "vfx": &"impact", "color": Color("b8a8d8"), "icon": "nova"}),
		_sk(n, "night_raid", "Night Raid", "หายตัวเข้าเงา ฟันกระโดดไปมาใส่ศัตรู 4 ตัว", 39, 36, 10.0, "chain", 3.6, {"hits": 4, "range": 9.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"slash", "color": night, "icon": "triple"}),
		_sk(n, "crimson_cut", "Crimson Cut", "ฟันคมโลหิตใส่ศัตรูตัวเดียว เลือดไหลต่อเนื่อง 5 วินาที", 43, 40, 8.0, "single", 7.6, {"range": 3.1, "fx": {"burn": [0.4, 5.0]}, "color": blood, "icon": "sword"}),
		_sk(n, "shadow_clone", "Shadow Clone", "ร่างเงาสะท้อนการโจมตี ATK +40% หลบ +15% นาน 1 นาที", 47, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "dodge": 0.15, "secs": 60.0}}, "color": night, "icon": "roar"}),
		_sk(n, "phantom_daggers", "Phantom Daggers", "ขว้างมีดเงาพุ่งทะลุศัตรู 5 ตัวเป็นแนวยาว", 52, 48, 9.0, "single", 6.4, {"range": 10.0, "pierce": pc.call(5, 12.0, 1.4), "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": night, "icon": "arrow"}),
		_sk(n, "deadly_venom", "Deadly Venom", "โปรยหมอกพิษมรณะใส่ฝูงศัตรู ติดพิษและช้าลง", 56, 52, 11.0, "blast", 4.4, {"radius": 4.8, "range": 10.0, "fx": {"burn": [0.45, 6.0], "slow": 3.0}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": venom, "icon": "nova"}),
		_sk(n, "thousand_cuts", "Thousand Cuts", "พันคมเงาฟันกระจายรอบตัว", 60, 60, 12.0, "burst", 6.4, {"radius": 6.2, "special": "spin", "color": night, "icon": "spin"}),
		_sk(n, "throat_slit", "Throat Slit", "ปาดคอศัตรูตัวเดียวในพริบตา มึนงง 0.8 วินาที", 64, 60, 8.0, "single", 12.6, {"range": 3.3, "fx": {"stun": 0.8}, "color": blood, "icon": "sword"}),
		_sk(n, "shadow_dance", "Shadow Dance", "ระบำเงา ฟันกระโดดต่อเนื่องใส่ศัตรู 6 ตัว", 68, 66, 11.0, "chain", 5, {"hits": 6, "range": 10.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"slash", "color": night, "icon": "triple"}),
		_sk(n, "death_mark", "Death Mark", "ประทับตรามรณะลงพื้น ศัตรูในวงเกราะลดลง 20% นาน 8 วินาที", 72, 70, 13.0, "blast", 5, {"radius": 6.0, "range": 11.0, "fx": {"shred": [0.2, 8.0]}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": blood, "icon": "nova"}),
		_sk(n, "night_lord", "Night Lord", "จ้าวราตรี ATK +35% คริติคอล +20% วิ่งเร็ว +15% ฟื้น HP 20% นาน 1 นาที", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.35, "crit": 0.2, "speed": 0.15, "secs": 60.0}}, "color": night, "icon": "roar"}),
		_sk(n, "eclipse_fang", "Eclipse Fang", "เขี้ยวสุริยคราส ฟันมีดคู่ฉีกศัตรูตัวเดียวขาดสะบั้น", 80, 90, 10.0, "single", 17.0, {"range": 3.5, "vfx": &"slash", "color": blood, "icon": "sword"}),
		_sk(n, "abyss_vortex", "Abyss Vortex", "วังวนนรกดูดศัตรูรอบตัว ช้าลงและถูกฉีกต่อเนื่อง", 84, 96, 14.0, "burst", 6, {"radius": 7.5, "special": "spin", "fx": {"slow": 3.0}, "color": night, "icon": "spin"}),
		_sk(n, "phantom_legion", "Phantom Legion", "กองทัพเงาขว้างมีดพุ่งออก 8 ทิศ", 88, 96, 13.0, "fan", 4, {"hits": 8, "range": 12.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": night, "icon": "triple"}),
		_sk(n, "midnight_execution", "Midnight Execution", "ประหารเที่ยงคืน กระโจนลงกลางฝูงศัตรู มึนงง 1.2 วินาที", 92, 104, 14.0, "blast", 6, {"radius": 7.0, "range": 11.0, "fx": {"stun": 1.2}, "anim": "Dualwield_Melee_Attack_Chop", "hit_delay": 0.5, "vfx": &"impact", "color": blood, "icon": "meteor"}),
		_sk(n, "shadow_sovereign", "Shadow Sovereign", "ราชันแห่งเงา ATK +55% คริติคอล +25% หลบ +15% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.25, "dodge": 0.15, "secs": 60.0}}, "color": night, "icon": "bless"}),
		_sk(n, "oblivion_requiem", "Oblivion Requiem", "บทเพลงลืมเลือน เงามืดปะทุฉีกทุกสิ่งรอบตัว ศัตรูมึนงง 1.5 วินาที", 100, 130, 16.0, "burst", 10.5, {"radius": 9.0, "fx": {"stun": 1.5}, "special": "spin", "vfx": &"slash", "color": blood, "icon": "nova"}),
	]

	# Dark Lord: the commander of MU Online with a scepter and a raven. Royal gold, dark
	# force violet, fire and the lightning of Electric Spike.
	var k := &"darklord"
	var royal := Color("e8b64a")
	var dark := Color("8a4dff")
	var fire := Color("ff6a2a")
	var bolt := Color("8fd8ff")
	var force := {"range": 9.0, "projectile": true, "anim": "Spellcast_Shoot", "hit_delay": 0.28}
	_pools[k] = [
		_sk(k, "force", "Force", "ปล่อยพลังมืดจากคทาพุ่งใส่ศัตรูตัวเดียว", 10, 8, 2.6, "single", 2.8, force.merged({"vfx": &"impact", "color": dark, "icon": "light"})),
		_sk(k, "critical_damage", "Critical Damage", "บัญชาการ ทีมคริติคอล +12% ATK +15% นาน 1 นาที", 10, 12, 25.0, "self", 0.0, {"fx": {"buff": {"crit": 0.12, "atk": 0.15, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "roar"}),
		_sk(k, "fire_burst", "Fire Burst", "คทาจุดระเบิดเพลิงรอบศัตรูเป้าหมาย", 13, 14, 6.0, "blast", 2.6, {"radius": 3.6, "range": 9.0, "anim": "Spellcast_Shoot", "hit_delay": 0.4, "vfx": &"fireball", "color": fire, "icon": "fire"}),
		_sk(k, "summon", "Summon", "วาร์ปเพื่อนทั้งปาร์ตี้มาอยู่ข้างตัวทันที ฟื้น HP ทีม 10%", 16, 20, 20.0, "self", 0.0, {"fx": {"recall": true, "heal": 0.1}, "anim": "Spellcast_Raise", "vfx": &"aura", "color": dark, "icon": "bless"}),
		_sk(k, "earthshake", "Earthshake", "กระทืบคทาลงพื้น แผ่นดินสั่นรอบตัว ศัตรูมึนงง 1.2 วินาที", 20, 20, 9.0, "burst", 2.4, {"radius": 4.8, "fx": {"stun": 1.2}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": royal, "icon": "nova"}),
		_sk(k, "force_wave", "Force Wave", "คลื่นพลังมืด 3 สายแผ่ออกเป็นพัด", 24, 22, 8.0, "fan", 2.3, {"hits": 3, "range": 11.0, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		_sk(k, "electric_spike", "Electric Spike", "หอกสายฟ้าฟาดลงแล้วกระโดดไปศัตรู 5 ตัว", 27, 26, 9.0, "chain", 3.0, {"hits": 5, "range": 10.0, "vfx": &"thunder", "color": bolt, "icon": "bolt"}),
		_sk(k, "fire_scream", "Fire Scream", "คำรามเพลิง ระเบิดไฟใส่ฝูงศัตรู ติดไฟต่อเนื่อง", 31, 30, 10.0, "blast", 3.8, {"radius": 4.6, "range": 10.0, "fx": {"burn": [0.35, 4.0]}, "anim": "Spellcast_Shoot", "hit_delay": 0.45, "vfx": &"fireball", "color": fire, "icon": "fire"}),
		_sk(k, "birds", "Birds", "ปล่อยฝูงอีกาเงา 5 ตัวโฉบใส่ศัตรูหลายตัว", 35, 30, 9.0, "fan", 2.4, {"hits": 5, "range": 11.0, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		_sk(k, "chaos_strike", "Chaos Strike", "ฟาดคทาแห่งความโกลาหลใส่ศัตรูตัวเดียว แรงมาก", 39, 34, 7.0, "single", 6.0, {"range": 3.0, "vfx": &"impact", "color": dark, "icon": "sword"}),
		_sk(k, "iron_defense", "Iron Defense", "เกราะราชัน ทีม DEF +40% ฟื้น HP 15% นาน 1 นาที", 43, 36, 32.0, "self", 0.0, {"fx": {"heal": 0.15, "buff": {"def": 0.4, "secs": 60.0}}, "color": royal, "icon": "shield"}),
		_sk(k, "commanders_aura", "Commander's Aura", "รัศมีผู้บัญชาการ ทีม ATK +35% DEF +20% นาน 1 นาที", 47, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.35, "def": 0.2, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		_sk(k, "fire_blast", "Fire Blast", "ลูกไฟราชันพุ่งใส่ศัตรูตัวเดียว ไฟลุกแรง", 52, 46, 8.0, "single", 7.6, force.merged({"fx": {"burn": [0.45, 5.0]}, "vfx": &"fireball", "color": fire, "icon": "fire"})),
		_sk(k, "plasma_storm", "Plasma Storm", "พายุพลาสมาถล่มพื้นที่ ศัตรูช้าลง", 56, 54, 11.0, "blast", 4.4, {"radius": 5.2, "range": 11.0, "fx": {"slow": 3.0}, "anim": "Spellcast_Long", "hit_delay": 0.55, "vfx": &"thunder", "color": bolt, "icon": "bolt"}),
		_sk(k, "chaotic_diseier", "Chaotic Diseier", "ปลดปล่อยพลังโกลาหล 6 สายพุ่งทะลวง", 60, 60, 11.0, "fan", 5.0, {"hits": 6, "range": 12.0, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		_sk(k, "royal_crush", "Royal Crush", "ทุบคทาราชันใส่ศัตรูตัวเดียว มึนงง 0.8 วินาที", 64, 60, 8.0, "single", 12.4, {"range": 3.3, "fx": {"stun": 0.8}, "vfx": &"impact", "color": royal, "icon": "sword"}),
		_sk(k, "thunder_lord", "Thunder Lord", "จ้าวสายฟ้า ฟาดสายฟ้ากระโดดใส่ศัตรู 7 ตัว", 68, 66, 11.0, "chain", 5, {"hits": 7, "range": 11.0, "vfx": &"thunder", "color": bolt, "icon": "bolt"}),
		_sk(k, "dark_comet", "Dark Comet", "อัญเชิญดาวหางมืดตกใส่ฝูงศัตรู", 72, 70, 13.0, "blast", 5, {"radius": 6.0, "range": 11.0, "special": "meteor", "anim": "Spellcast_Long", "hit_delay": 0.6, "vfx": &"impact", "color": dark, "icon": "meteor"}),
		_sk(k, "lord_of_command", "Lord of Command", "จ้าวบัญชาการ ทีม ATK +35% คริ +15% DEF +25% ฟื้น HP 20% นาน 1 นาที", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.35, "crit": 0.15, "def": 0.25, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		_sk(k, "infernal_scream", "Infernal Scream", "เสียงคำรามนรก เพลิงพายุถล่มรอบตัว ติดไฟแรง", 80, 90, 13.0, "burst", 6.6, {"radius": 7.0, "fx": {"burn": [0.5, 5.0]}, "anim": "Spellcast_Raise", "vfx": &"fireball", "color": fire, "icon": "nova"}),
		_sk(k, "chaos_sovereign", "Chaos Sovereign", "ราชันแห่งความโกลาหล ฟาดพลังมืดฉีกศัตรูตัวเดียว", 84, 92, 10.0, "single", 17.0, {"range": 3.6, "vfx": &"impact", "color": dark, "icon": "sword"}),
		_sk(k, "raven_storm", "Raven Storm", "พายุอีกาเงา 8 ตัวโฉบใส่ศัตรูรอบทิศ", 88, 96, 13.0, "fan", 4, {"hits": 8, "range": 12.0, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		_sk(k, "earth_dominion", "Earth Dominion", "ปกครองพสุธา แผ่นดินแยกถล่มรอบตัว ศัตรูมึนงง 1.5 วินาที", 92, 104, 14.0, "burst", 6, {"radius": 8.0, "fx": {"stun": 1.5}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": royal, "icon": "nova"}),
		_sk(k, "emperors_command", "Emperor's Command", "ราชโองการจักรพรรดิ ทีม ATK +55% คริ +20% วิ่งเร็ว +15% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.2, "speed": 0.15, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		_sk(k, "imperial_judgment", "Imperial Judgment", "คำพิพากษาจักรพรรดิ พลังมืด ไฟ และสายฟ้าระเบิดรอบตัว ศัตรูมึนงง 1.5 วินาที", 100, 130, 16.0, "burst", 10.5, {"radius": 9.0, "fx": {"stun": 1.5}, "anim": "Spellcast_Raise", "vfx": &"thunder", "color": royal, "icon": "nova"}),
	]

	# Bard: a lute, notes and songs. Rose and gold for the music, violet for the
	# discords that crack armour, pale blue for the laments that sap strength.
	var b := &"bard"
	var rose := Color("ff6fb5")  # songs, the class accent
	var tone := Color("ffb3dc")  # notes
	var gilt := Color("f0c870")  # drums, ward songs
	var disso := Color("b07aff")  # armour-cracking discords (shred)
	var sorrow := Color("8fb8ff")  # strength-sapping laments (weaken)
	var aqua := Color("9fe8ff")  # serenades, echoes
	var tempest := Color("c79bff")  # thunder
	var shine := Color("ffd36b")  # the great song
	var dream := Color("a8c8ff")  # the lullaby
	var note := {"projectile": true, "anim": "Spellcast_Shoot"}  # no vfx here: merged() never overwrites
	_pools[b] = [
		_sk(b, "staccato_shot", "Staccato Shot", "ดีดพิณยิงโน้ตแหลมพุ่งใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 10, 8, 2.6, "single", 2.8, note.merged({"range": 10.0, "hit_delay": 0.28, "vfx": &"light", "color": tone, "icon": "light"})),
		_sk(b, "valor_march", "Valor March", "เพลง: มาร์ชกล้าหาญ ทั้งปาร์ตี้ ATK +15% วิ่งเร็ว +12% นาน 1 นาที", 10, 12, 25.0, "self", 0.0, {"fx": {"buff": {"atk": 0.15, "speed": 0.12, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": rose, "icon": "bless"}),
		_sk(b, "resonance", "Resonance", "ดีดคอร์ดก้องกังวาน คลื่นเสียงระเบิดรอบศัตรูเป้าหมาย ช้าลง 2 วินาที", 13, 14, 6.0, "blast", 2.6, {"radius": 3.8, "range": 10.0, "hit_delay": 0.42, "anim": "Spellcast_Shoot", "fx": {"slow": 2.0}, "vfx": &"impact", "color": tone, "icon": "nova"}),
		_sk(b, "sorrow_note", "Sorrow Note", "โน้ตเศร้าสร้อยพุ่งใส่ศัตรูตัวเดียว ศัตรูอ่อนแรง โจมตีเบาลง 15% นาน 6 วินาที", 16, 16, 8.0, "single", 1.9, note.merged({"range": 10.0, "hit_delay": 0.3, "fx": {"weaken": [0.15, 6.0]}, "vfx": &"debuff", "color": sorrow, "icon": "light"})),
		_sk(b, "discord", "Discord", "ดีดเสียงไม่ประสาน คลื่นเสียงเพี้ยนระเบิดใส่ฝูงศัตรู เกราะแตก 15% นาน 8 วินาที", 20, 20, 9.0, "blast", 2.4, {"radius": 4.2, "range": 10.0, "hit_delay": 0.45, "anim": "Spellcast_Shoot", "fx": {"shred": [0.15, 8.0]}, "vfx": &"debuff", "color": disso, "icon": "nova"}),
		_sk(b, "iron_ballad", "Iron Ballad", "เพลง: บัลลาดเหล็กกล้า ฟื้นฟู HP 15% ทั้งปาร์ตี้ DEF +30% ลดความเสียหายที่ได้รับ 8% นาน 1 นาที", 24, 22, 30.0, "self", 0.0, {"fx": {"heal": 0.15, "buff": {"def": 0.3, "guard": 0.08, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"heal", "color": gilt, "icon": "shield"}),
		_sk(b, "triad_chord", "Triad Chord", "ดีดคอร์ดสามเสียง ยิงโน้ต 3 ลูกแผ่เป็นพัด", 27, 26, 8.0, "fan", 2.5, {"hits": 3, "range": 11.0, "hit_delay": 0.26, "anim": "Spellcast_Shoot", "vfx": &"light", "color": tone, "icon": "triple"}),
		_sk(b, "echo_chain", "Echo Chain", "โน้ตก้องสะท้อนกระโดดไปหาศัตรูสูงสุด 5 ตัว", 31, 30, 9.0, "chain", 3.0, {"hits": 5, "range": 10.0, "hit_delay": 0.3, "anim": "Spellcast_Shoot", "vfx": &"light", "color": aqua, "icon": "bolt"}),
		_sk(b, "war_drum", "War Drum", "กระทืบเท้าตามจังหวะกลองศึก คลื่นเสียงกระหึ่มรอบตัว ศัตรูมึนงง 1.2 วินาที", 35, 30, 12.0, "burst", 2.6, {"radius": 5.0, "hit_delay": 0.4, "anim": "1H_Melee_Attack_Chop", "fx": {"stun": 1.2}, "vfx": &"impact", "color": gilt, "icon": "nova"}),
		_sk(b, "heartstring", "Heartstring", "ดีดสายใจ โน้ตทรงพลังพุ่งใส่ศัตรูตัวเดียว ช้าลง 3 วินาที", 39, 34, 7.0, "single", 6.0, note.merged({"range": 10.0, "hit_delay": 0.32, "fx": {"slow": 3.0}, "vfx": &"light", "color": rose, "icon": "light"})),
		_sk(b, "virtuoso", "Virtuoso", "ฝีมือขั้นเทพ (เฉพาะตัวเอง ไม่ใช่เพลง ใช้คู่กับเพลงได้) ATK +25% คริติคอล +12% นาน 1 นาที", 43, 36, 32.0, "self", 0.0, {"fx": {"buff": {"atk": 0.25, "crit": 0.12, "self_only": true, "secs": 60.0}}, "anim": "Spellcasting", "vfx": &"aura", "color": rose, "icon": "roar"}),
		_sk(b, "heroic_anthem", "Heroic Anthem", "เพลง: เพลงชาติวีรชน ทั้งปาร์ตี้ ATK +40% คริติคอล +10% นาน 1 นาที", 47, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "crit": 0.1, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": rose, "icon": "bless"}),
		_sk(b, "slumber_lullaby", "Slumber Lullaby", "เพลงกล่อมนิทราโปรยโน้ตลงพื้นที่ ศัตรูหลับมึนงง 1.8 วินาที", 52, 50, 14.0, "blast", 3.6, {"radius": 5.5, "range": 11.0, "hit_delay": 0.5, "anim": "Spellcast_Long", "fx": {"stun": 1.8}, "vfx": &"aura", "color": dream, "icon": "rain"}),
		_sk(b, "lament", "Lament", "บทเพลงคร่ำครวญถล่มฝูงศัตรู ศัตรูช้าลง 3 วินาทีและอ่อนแรง โจมตีเบาลง 20% นาน 8 วินาที", 56, 54, 12.0, "blast", 4.4, {"radius": 5.2, "range": 11.0, "hit_delay": 0.5, "anim": "Spellcast_Long", "fx": {"slow": 3.0, "weaken": [0.2, 8.0]}, "vfx": &"debuff", "color": sorrow, "icon": "nova"}),
		_sk(b, "cascade", "Cascade of Notes", "โน้ตดนตรี 6 ลูกพรั่งพรูเป็นสายน้ำใส่ศัตรูหลายตัว", 60, 60, 11.0, "fan", 5.0, {"hits": 6, "range": 12.0, "hit_delay": 0.28, "anim": "Spellcast_Shoot", "vfx": &"light", "color": tone, "icon": "triple"}),
		_sk(b, "sanctuary_serenade", "Sanctuary Serenade", "เพลง: เซเรเนดแห่งวิหาร ฟื้นฟู HP 25% ทั้งปาร์ตี้ DEF +40% ลดความเสียหายที่ได้รับ 12% โล่ดูดซับ 10% ของ HP นาน 1 นาที", 64, 70, 40.0, "self", 0.0, {"fx": {"heal": 0.25, "buff": {"def": 0.4, "guard": 0.12, "shield": 0.1, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"heal", "color": aqua, "icon": "shield"}),
		_sk(b, "fortissimo", "Fortissimo", "ฟอร์ติสซิโม เสียงดังสุดขีดกระแทกศัตรูตัวเดียวทันที มึนงง 0.8 วินาที", 68, 64, 8.0, "single", 12.0, {"range": 10.0, "projectile": false, "hit_delay": 0.36, "anim": "Spellcast_Shoot", "fx": {"stun": 0.8}, "vfx": &"impact", "color": rose, "icon": "nova"}),
		_sk(b, "shattering_rhapsody", "Shattering Rhapsody", "ราพโซดีสายฟ้าฟาดตามจังหวะถล่มฝูงศัตรู เกราะแตก 22% นาน 8 วินาที และช้าลง 3 วินาที", 72, 70, 13.0, "blast", 5.0, {"radius": 6.0, "range": 11.0, "hit_delay": 0.55, "anim": "Spellcast_Long", "fx": {"shred": [0.22, 8.0], "slow": 3.0}, "vfx": &"thunder", "color": tempest, "icon": "bolt"}),
		_sk(b, "maestro_fervor", "Maestro's Fervor", "ไฟแห่งวาทยกร (เฉพาะตัวเอง ไม่ใช่เพลง ใช้คู่กับเพลงได้) ฟื้นฟู HP 20% ATK +35% คริติคอล +15% วิ่งเร็ว +12% นาน 1 นาที", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.35, "crit": 0.15, "speed": 0.12, "self_only": true, "secs": 60.0}}, "anim": "Spellcasting", "vfx": &"aura", "color": gilt, "icon": "roar"}),
		_sk(b, "grand_dissonance", "Grand Dissonance", "มหาเสียงไม่ประสานถล่มพื้นที่กว้าง ศัตรูเกราะแตก 25% และอ่อนแรง 20% นาน 8 วินาที", 80, 96, 15.0, "blast", 6.4, {"radius": 7.0, "range": 11.0, "hit_delay": 0.6, "anim": "Spellcast_Long", "fx": {"shred": [0.25, 8.0], "weaken": [0.2, 8.0]}, "vfx": &"debuff", "color": disso, "icon": "nova"}),
		_sk(b, "aria_of_ruin", "Aria of Ruin", "อาเรียแห่งหายนะ โน้ตเสียงสูงสุดขีดผ่าลงศัตรูตัวเดียวอย่างรุนแรง", 84, 92, 10.0, "single", 17.0, {"range": 11.0, "projectile": false, "hit_delay": 0.6, "anim": "Spellcast_Raise", "vfx": &"light", "color": rose, "icon": "light"}),
		_sk(b, "eternal_echo", "Eternal Echo", "เสียงก้องนิรันดร์ โน้ตสะท้อนกระโดดไปหาศัตรูสูงสุด 8 ตัว", 88, 96, 13.0, "chain", 4.8, {"hits": 8, "range": 12.0, "hit_delay": 0.3, "anim": "Spellcast_Shoot", "vfx": &"light", "color": aqua, "icon": "bolt"}),
		_sk(b, "thunder_crescendo", "Thunder Crescendo", "เครสเชนโดสายฟ้า กลองฟ้าคำรามรอบตัว ศัตรูมึนงง 1.2 วินาทีและอ่อนแรง 24% นาน 8 วินาที", 92, 104, 14.0, "burst", 5.6, {"radius": 8.0, "hit_delay": 0.45, "anim": "1H_Melee_Attack_Chop", "fx": {"stun": 1.2, "weaken": [0.24, 8.0]}, "vfx": &"thunder", "color": tempest, "icon": "nova"}),
		_sk(b, "hymn_of_legends", "Hymn of Legends", "เพลง: บทเพลงแห่งตำนาน ทั้งปาร์ตี้ ATK +55% คริติคอล +20% วิ่งเร็ว +15% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.2, "speed": 0.15, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": shine, "icon": "bless"}),
		_sk(b, "grand_finale", "Grand Finale", "มหาคอนเสิร์ตปิดม่าน เวทีแสงและเสียงระเบิดถล่มพื้นที่กว้างมาก ศัตรูมึนงง 1.5 วินาที เกราะแตก 20% และอ่อนแรง 20% นาน 8 วินาที", 100, 140, 18.0, "blast", 10.5, {"radius": 9.5, "range": 12.0, "hit_delay": 0.9, "anim": "Spellcast_Long", "fx": {"stun": 1.5, "shred": [0.2, 8.0], "weaken": [0.2, 8.0]}, "vfx": &"light", "color": rose, "icon": "nova"}),
	]

	for star_class in IDS:
		_pools[star_class].append_array(StarSkillData.pool(star_class))
