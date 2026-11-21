extends RefCounted
## Warrior (นักดาบ): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[1.016, 1.6], [1.2, 0.85], [1.149, 1.183]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["raving", "triple_impact", "brandish"],  # single
	["impact", "destroyer", "sword_of_justice"],  # single + stun
	["brutal_swing", "cyclone_strike", "grand_cross"],  # area
	["roar", "bone_crash", "double_crash"],  # area + stun
	["sword_blast", "piercing", "divine_piercing"],  # long reach
	["concentration", "berserker", "triumph_of_valhalla"],  # attack buff
	["holy_valor", "drastic_spirit", "godly_shield"],  # defence buff
	["rage_of_zecram", "gladiator"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (avenging_crash, swift_axe) is refunded and dropped.
const OLD_IDS := {
	"weapon_mastery": "melee_mastery",
	"holy_body": "physical_training",
	"immortal_body": "battle_instinct",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "melee_mastery", "name": "Melee Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "physical_training", "name": "Physical Training", "desc": "HP สูงสุด +4% และพลังป้องกัน +4% ต่อดาว", "level": 20, "bonus": {"hp": 0.04, "def": 0.04}},
	{"id": "battle_instinct", "name": "Battle Instinct", "desc": "คริติคอล +1.5% และ HP สูงสุด +5% ต่อดาว", "level": 60, "bonus": {"crit": 0.015, "hp": 0.05}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var w := &"warrior"
	return [
		# 1 single: Raving -> Triple Impact (60) -> Brandish (90)
		ClassData._sk(w, "raving", "Raving", "ฟันรัวใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 1, 10, 3.0, "single", 3.0, {"color": Color("ffb05a"), "icon": "sword"}),
		ClassData._sk(w, "triple_impact", "Triple Impact", "ฟันต่อเนื่อง 3 ครั้งใส่เป้าหมายเดียว", 60, 40, 6.0, "single", 4.6, {"color": Color("ff9a5a"), "icon": "sword"}),
		ClassData._sk(w, "brandish", "Brandish", "ฟันกวาดแรงสูงใส่ศัตรูตัวเดียว", 90, 60, 8.0, "single", 13.0, {"range": 3.4, "color": Color("ff5a3a"), "icon": "sword"}),
		# 2 single + stun: Impact -> Destroyer (60) -> Sword of Justice (90)
		ClassData._sk(w, "impact", "Impact", "ฟันกระแทกหนักๆ ศัตรูมึนงง 1.5 วินาที", 5, 12, 6.0, "single", 3.4, {"fx": {"stun": 1.5}, "vfx": &"impact", "anim": "Block_Attack", "color": Color("ffe27a"), "icon": "shield"}),
		ClassData._sk(w, "destroyer", "Destroyer", "ฟันทำลายล้างศัตรูตัวเดียว มึนงง 1.5 วินาที", 60, 40, 9.0, "single", 8.2, {"range": 3.2, "fx": {"stun": 1.5}, "color": Color("ff3a3a"), "icon": "sword"}),
		ClassData._sk(w, "sword_of_justice", "Sword of Justice", "ดาบแห่งความยุติธรรมฟันขาดศัตรูตัวเดียว มึนงง 1.5 วินาที", 90, 92, 10.0, "single", 18.0, {"range": 3.6, "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("fff0a0"), "icon": "sword"}),
		# 3 area: Brutal Swing -> Cyclone Strike (60) -> Grand Cross (90)
		ClassData._sk(w, "brutal_swing", "Brutal Swing", "หมุนตัวฟันรอบทิศ", 10, 16, 9.0, "burst", 2.8, {"radius": 4.3, "special": "spin", "color": Color("ff9a5a"), "icon": "spin"}),
		ClassData._sk(w, "cyclone_strike", "Cyclone Strike", "พายุดาบหมุนรอบตัว ศัตรูมึนงง 1 วินาที", 60, 62, 12.0, "burst", 8.0, {"radius": 6.5, "special": "spin", "fx": {"stun": 1.0}, "color": Color("ff8a4a"), "icon": "spin"}),
		ClassData._sk(w, "grand_cross", "Grand Cross", "ไม้กางเขนดาบถล่มรอบตัว ศัตรูมึนงง 1.5 วินาที", 90, 90, 16.0, "burst", 13.0, {"radius": 7.5, "special": "spin", "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("fff0a0"), "icon": "spin"}),
		# 4 area + stun: Roar -> Bone Crash (60) -> Double Crash (80)
		ClassData._sk(w, "roar", "Roar", "คำรามก้อง ศัตรูรอบตัวมึนงง 2.5 วินาที", 15, 18, 14.0, "burst", 1.4, {"radius": 6.0, "fx": {"stun": 2.5}, "vfx": &"impact", "anim": "Cheer", "color": Color("ffd27a"), "icon": "roar"}),
		ClassData._sk(w, "bone_crash", "Bone Crash", "ทุบพื้นถล่มศัตรูรอบตัว มึนงง 1.2 วินาที", 60, 58, 12.0, "burst", 4.8, {"radius": 5.2, "fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ff8a4a"), "icon": "spin"}),
		ClassData._sk(w, "double_crash", "Double Crash", "กระแทกสองครั้งติด ศัตรูรอบตัวบาดเจ็บหนัก มึนงง 1.2 วินาที", 80, 80, 11.0, "burst", 9.5, {"radius": 5.5, "fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ff7a3a"), "icon": "spin"}),
		# 5 long reach: Sword Blast -> Piercing (60) -> Divine Piercing (90)
		ClassData._sk(w, "sword_blast", "Sword Blast", "ปล่อยคลื่นดาบพุ่งไปไกลใส่ศัตรู", 20, 24, 8.0, "single", 9.5, {"range": 9.0, "projectile": true, "vfx": &"impact", "color": Color("ffb04a"), "icon": "sword"}),
		ClassData._sk(w, "piercing", "Piercing", "ดาบพุ่งทะลวงศัตรู 6 ตัวต่อเนื่อง", 60, 62, 12.0, "chain", 5.5, {"hits": 6, "range": 9.0, "vfx": &"slash", "color": Color("ffd27a"), "icon": "sword"}),
		ClassData._sk(w, "divine_piercing", "Divine Piercing", "ดาบศักดิ์สิทธิ์พุ่งไปที่ศัตรู 8 ทิศ", 90, 100, 14.0, "fan", 5.5, {"hits": 8, "range": 12.0, "vfx": &"light", "color": Color("fff0a0"), "icon": "triple"}),
		# 6 attack buff: Concentration -> Berserker (60) -> Triumph of Valhalla (96)
		ClassData._sk(w, "concentration", "Concentration", "ATK +30% คริติคอล +15% นาน 1 นาที", 30, 24, 30.0, "self", 0.0, {"fx": {"buff": {"atk": 0.3, "crit": 0.15, "secs": 60.0}}, "color": Color("ffb04a"), "icon": "roar"}),
		ClassData._sk(w, "berserker", "Berserker", "ATK +55% วิ่งเร็ว +15% นาน 1 นาที", 60, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "speed": 0.15, "secs": 60.0}}, "color": Color("ff4a3a"), "icon": "roar"}),
		ClassData._sk(w, "triumph_of_valhalla", "Triumph of Valhalla", "ATK +80% คริ +20% วิ่งเร็ว +20% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.8, "crit": 0.2, "speed": 0.2, "secs": 60.0}}, "color": Color("ffd84a"), "icon": "roar"}),
		# 7 defence buff: Holy Valor -> Drastic Spirit (70) -> Godly Shield (90)
		ClassData._sk(w, "holy_valor", "Holy Valor", "ATK +40% DEF +30% นาน 1 นาที", 40, 40, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "def": 0.3, "secs": 60.0}}, "color": Color("ffe27a"), "icon": "roar"}),
		ClassData._sk(w, "drastic_spirit", "Drastic Spirit", "ATK +40% DEF +80% ฟื้นฟู HP 30% นาน 1 นาที", 70, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.3, "buff": {"atk": 0.4, "def": 0.8, "secs": 60.0}}, "color": Color("ffe9a0"), "icon": "shield"}),
		ClassData._sk(w, "godly_shield", "Godly Shield", "ATK +40% DEF +120% ฟื้นฟู HP 40% นาน 1 นาที", 90, 90, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"atk": 0.4, "def": 1.2, "secs": 60.0}}, "color": Color("ffffff"), "icon": "shield"}),
		# 8 ultimate: Rage of Zecram (50) -> Gladiator (100)
		ClassData._sk(w, "rage_of_zecram", "Rage of Zecram", "พลังโกรธาปะทุ ฟันศัตรูรอบตัวอย่างรุนแรง", 50, 50, 10.0, "burst", 4.0, {"radius": 4.8, "color": Color("ff5a3a"), "icon": "spin"}),
		ClassData._sk(w, "gladiator", "Gladiator", "การฟันสังหารสุดยอดของนักดาบในตำนาน", 100, 130, 14.0, "single", 26.0, {"range": 3.8, "color": Color("ff3a3a"), "icon": "sword"}),
	]
