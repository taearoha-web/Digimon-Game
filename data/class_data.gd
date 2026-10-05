class_name ClassData
extends RefCounted
## The four hero classes: look, stats, basic attack and their four skills.
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

const IDS: Array[StringName] = [&"warrior", &"archer", &"mage", &"priest"]

const CLASSES := {
	&"warrior": {
		"name": "นักรบ",
		"title": "ผู้พิทักษ์แนวหน้า",
		"badge": "W",
		"desc": "ถือดาบและโล่ เลือดเยอะและทนที่สุด สู้ประชิดตัว ตีหมู่ด้วยพายุดาบ",
		"model": "Knight",
		"weapon": "sword_1handed",
		"offhand": "shield_badge_color",
		"weapon_kind": "sword",
		"color": Color("ff7a45"),
		"main": "str",
		"base": {"str": 12, "int": 3, "dex": 6, "vit": 12},
		"gain": {"str": 2, "int": 0, "dex": 1, "vit": 2},
		"hp_mult": 1.3,
		"mp_mult": 0.7,
		"attack": {
			"range": 2.4, "interval": 0.8, "mult": 1.0, "hit_delay": 0.22, "projectile": false, "vfx": &"slash",
			"anims": ["1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop"],
		},
		"skills": [
			{"id": "power_slash", "name": "ฟันสะท้านฟ้า", "desc": "ฟันดาบแรงๆ ใส่ศัตรูตัวเดียว", "level": 1, "mp": 6, "cd": 3.0,
				"shape": "single", "mult": 2.4, "range": 2.6, "anim": "1H_Melee_Attack_Chop", "hit_delay": 0.25,
				"color": Color("ffb05a"), "vfx": &"slash", "icon": "sword"},
			{"id": "shield_bash", "name": "โล่กระแทก", "desc": "ใช้โล่กระแทกให้ศัตรูมึนงง 2 วินาที", "level": 4, "mp": 9, "cd": 7.0,
				"shape": "single", "mult": 1.5, "range": 2.4, "anim": "Block_Attack", "hit_delay": 0.25,
				"fx": {"stun": 2.0}, "color": Color("ffe27a"), "vfx": &"impact", "icon": "shield"},
			{"id": "whirlwind", "name": "พายุดาบ", "desc": "หมุนตัวฟันศัตรูรอบตัวทุกตัว", "level": 8, "mp": 16, "cd": 9.0,
				"shape": "burst", "mult": 2.0, "radius": 4.2, "anim": "2H_Melee_Attack_Spin", "hit_delay": 0.35,
				"color": Color("ff9a5a"), "vfx": &"wind", "icon": "spin"},
			{"id": "battle_roar", "name": "คำรามศึก", "desc": "ATK และ DEF เพิ่ม 30% นาน 15 วินาที", "level": 12, "mp": 14, "cd": 25.0,
				"shape": "self", "anim": "Cheer", "hit_delay": 0.2,
				"fx": {"buff": {"atk": 0.3, "def": 0.3, "secs": 15.0}}, "color": Color("ff5a3a"), "vfx": &"aura", "icon": "roar"},
		],
	},
	&"archer": {
		"name": "นักธนู",
		"title": "ผู้พิฆาตระยะไกล",
		"badge": "A",
		"desc": "ยิงหน้าไม้จากระยะไกล คริติคอลสูง ยิงสามดอกและฝนลูกธนูตีหมู่",
		"model": "Ranger",
		"weapon": "crossbow_2handed",
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
		"skills": [
			{"id": "power_shot", "name": "ยิงทะลวง", "desc": "ยิงแรงๆ เจาะเกราะศัตรูตัวเดียว", "level": 1, "mp": 6, "cd": 3.0,
				"shape": "single", "mult": 2.5, "range": 12.0, "anim": "2H_Ranged_Shoot", "hit_delay": 0.2, "projectile": true,
				"color": Color("ffd84a"), "vfx": &"impact", "icon": "arrow"},
			{"id": "triple_shot", "name": "ยิงสามทาง", "desc": "ยิงพร้อมกัน 3 ดอก พุ่งใส่ศัตรูใกล้เคียง", "level": 4, "mp": 10, "cd": 6.0,
				"shape": "fan", "mult": 1.5, "range": 11.0, "hits": 3, "anim": "2H_Ranged_Shoot", "hit_delay": 0.2, "projectile": true,
				"color": Color("8fff9a"), "vfx": &"leaf", "icon": "triple"},
			{"id": "arrow_rain", "name": "ฝนลูกธนู", "desc": "ลูกธนูตกใส่พื้นที่รอบเป้าหมายต่อเนื่อง", "level": 8, "mp": 18, "cd": 10.0,
				"shape": "blast", "mult": 2.2, "range": 10.0, "radius": 4.0, "anim": "2H_Ranged_Shooting", "hit_delay": 0.5,
				"color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"},
			{"id": "swift_step", "name": "ก้าวพลิ้ว", "desc": "วิ่งเร็วขึ้นและคริติคอลสูงขึ้น 12 วินาที", "level": 12, "mp": 12, "cd": 22.0,
				"shape": "self", "anim": "Dodge_Backward", "hit_delay": 0.15,
				"fx": {"buff": {"speed": 0.35, "crit": 0.2, "secs": 12.0}}, "color": Color("7affd0"), "vfx": &"wind", "icon": "boots"},
		],
	},
	&"mage": {
		"name": "จอมเวท",
		"title": "ผู้ควบคุมธาตุ",
		"badge": "M",
		"desc": "เวทธาตุทรงพลัง ตีหมู่เก่งที่สุด แต่เลือดน้อยและต้องรักษาระยะ",
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
		"skills": [
			{"id": "fireball", "name": "ลูกไฟ", "desc": "ลูกไฟพุ่งใส่ศัตรู ติดไฟต่อเนื่อง", "level": 1, "mp": 8, "cd": 3.0,
				"shape": "single", "mult": 2.5, "range": 10.0, "anim": "Spellcast_Shoot", "hit_delay": 0.3, "projectile": true,
				"fx": {"burn": [0.25, 4.0]}, "color": Color("ff7a2a"), "vfx": &"fireball", "icon": "fire"},
			{"id": "frost_nova", "name": "คลื่นน้ำแข็ง", "desc": "คลื่นเย็นรอบตัว ศัตรูช้าลง 3 วินาที", "level": 4, "mp": 14, "cd": 8.0,
				"shape": "burst", "mult": 1.8, "radius": 5.0, "anim": "Spellcast_Raise", "hit_delay": 0.4,
				"fx": {"slow": 3.0}, "color": Color("7fdcff"), "vfx": &"frost", "icon": "ice"},
			{"id": "chain_lightning", "name": "สายฟ้าฟาด", "desc": "สายฟ้ากระโดดไปหาศัตรูสูงสุด 4 ตัว", "level": 8, "mp": 18, "cd": 9.0,
				"shape": "chain", "mult": 2.0, "range": 10.0, "hits": 4, "anim": "Spellcast_Shoot", "hit_delay": 0.3,
				"color": Color("fff06a"), "vfx": &"thunder", "icon": "bolt"},
			{"id": "meteor", "name": "อุกกาบาต", "desc": "อุกกาบาตตกใส่พื้นที่กว้าง ความเสียหายมหาศาล", "level": 12, "mp": 32, "cd": 16.0,
				"shape": "blast", "mult": 4.2, "range": 11.0, "radius": 5.0, "anim": "Spellcast_Long", "hit_delay": 1.0,
				"color": Color("ff5a2a"), "vfx": &"fireball", "icon": "meteor"},
		],
	},
	&"priest": {
		"name": "พรีสต์",
		"title": "ผู้รักษาแสงศักดิ์สิทธิ์",
		"badge": "P",
		"desc": "รักษาตัวเองและเสริมพลัง ตีด้วยแสงศักดิ์สิทธิ์ เหมาะกับการลุยเดี่ยวนานๆ",
		"model": "Mage",
		"weapon": "wand",
		"offhand": "spellbook_closed",
		"weapon_kind": "wand",
		"color": Color("ffe27a"),
		"main": "int",
		"base": {"str": 4, "int": 12, "dex": 5, "vit": 10},
		"gain": {"str": 0, "int": 2, "dex": 1, "vit": 2},
		"hp_mult": 1.0,
		"mp_mult": 1.3,
		"attack": {
			"range": 8.5, "interval": 0.9, "mult": 0.95, "hit_delay": 0.3, "projectile": true, "vfx": &"light",
			"color": Color("fff0a0"),
			"anims": ["Spellcast_Shoot"],
		},
		"skills": [
			{"id": "holy_bolt", "name": "ลำแสงศักดิ์สิทธิ์", "desc": "ลำแสงสว่างโจมตีศัตรูตัวเดียว", "level": 1, "mp": 6, "cd": 2.5,
				"shape": "single", "mult": 2.3, "range": 9.0, "anim": "Spellcast_Shoot", "hit_delay": 0.3, "projectile": true,
				"color": Color("fff2a0"), "vfx": &"light", "icon": "light"},
			{"id": "heal", "name": "ฮีล", "desc": "ฟื้นฟู HP ของตัวเอง 40%", "level": 4, "mp": 14, "cd": 10.0,
				"shape": "self", "anim": "Spellcast_Raise", "hit_delay": 0.3,
				"fx": {"heal": 0.4}, "color": Color("6dff9a"), "vfx": &"heal", "icon": "heal"},
			{"id": "holy_nova", "name": "โนวาศักดิ์สิทธิ์", "desc": "คลื่นแสงรอบตัว ทำร้ายศัตรูและฟื้นฟู HP 12%", "level": 8, "mp": 20, "cd": 10.0,
				"shape": "burst", "mult": 2.0, "radius": 5.0, "anim": "Spellcast_Raise", "hit_delay": 0.4,
				"fx": {"heal": 0.12}, "color": Color("fff0a0"), "vfx": &"light", "icon": "nova"},
			{"id": "blessing", "name": "พรแห่งแสง", "desc": "ATK DEF +25% และคริติคอลสูงขึ้น 20 วินาที", "level": 12, "mp": 22, "cd": 28.0,
				"shape": "self", "anim": "Spellcasting", "hit_delay": 0.3,
				"fx": {"buff": {"atk": 0.25, "def": 0.25, "crit": 0.1, "secs": 20.0}}, "color": Color("ffe27a"), "vfx": &"aura", "icon": "bless"},
		],
	},
}


static func get_class_data(class_id: StringName) -> Dictionary:
	return CLASSES.get(class_id, CLASSES[&"warrior"])


static func get_skill(class_id: StringName, index: int) -> Dictionary:
	var skills: Array = get_class_data(class_id).skills
	return skills[index] if index >= 0 and index < skills.size() else {}


static func find_skill(class_id: StringName, skill_id: String) -> Dictionary:
	for skill in get_class_data(class_id).skills:
		if skill.id == skill_id:
			return skill
	return {}
