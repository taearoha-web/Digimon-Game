extends RefCounted
## Assassin (นักฆ่า): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[0.82, 0.847], [0.764, 2.4], [0.848, 0.874]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["twin_fang", "eclipse_fang"],  # single
	["venom_edge", "crimson_cut"],  # single + poison
	["shadow_step", "throat_slit"],  # the kill from the shadows
	["blade_flurry", "thousand_cuts", "abyss_vortex"],  # area round the assassin
	["fan_of_knives", "phantom_legion"],  # thrown knives
	["smoke_bomb", "midnight_execution"],  # area + stun + slow
	["killing_focus", "night_lord", "shadow_sovereign"],  # attack buff
	["shadow_dance", "oblivion_requiem"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (shadow_veil, backstab, night_raid, shadow_clone, phantom_daggers,
## deadly_venom, death_mark) is refunded and dropped.
const OLD_IDS := {
	"killer_instinct": "dagger_mastery",
	"evasive_instinct": "shadow_footwork",
	"night_stalker": "lethal_precision",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "dagger_mastery", "name": "Dagger Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "shadow_footwork", "name": "Shadow Footwork", "desc": "ความเร็ว +2% และหลบ +1.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.02, "dodge": 0.016}},
	{"id": "lethal_precision", "name": "Lethal Precision", "desc": "คริติคอล +2.5% และความเร็ว +2% ต่อดาว", "level": 40, "bonus": {"crit": 0.025, "speed": 0.02}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var n := &"assassin"
	var night := Color("9a6bff")
	var blood := Color("ff4f7b")
	var venom := Color("8be260")
	return [
		# 1 single: Twin Fang -> Eclipse Fang (80)
		ClassData._sk(n, "twin_fang", "Twin Fang", "ฟันมีดคู่ไขว้ใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 1, 8, 2.6, "single", 2.8, {"color": night, "icon": "sword"}),
		ClassData._sk(n, "eclipse_fang", "Eclipse Fang", "เขี้ยวสุริยคราส ฟันมีดคู่ฉีกศัตรูตัวเดียวขาดสะบั้น", 80, 90, 10.0, "single", 17.0, {"range": 3.5, "vfx": &"slash", "color": blood, "icon": "sword"}),
		# 2 single + poison: Venom Edge -> Crimson Cut (60)
		ClassData._sk(n, "venom_edge", "Venom Edge", "แทงคมพิษ ศัตรูติดพิษเสียเลือดต่อเนื่อง 5 วินาที", 5, 12, 5.0, "single", 3.4, {"fx": {"burn": [0.3, 5.0]}, "anim": "1H_Melee_Attack_Stab", "color": venom, "icon": "sword"}),
		ClassData._sk(n, "crimson_cut", "Crimson Cut", "ฟันคมโลหิตอาบพิษใส่ศัตรูตัวเดียว เลือดไหลต่อเนื่อง 5 วินาที", 60, 40, 8.0, "single", 7.6, {"range": 3.1, "fx": {"burn": [0.4, 5.0]}, "color": blood, "icon": "sword"}),
		# 3 the kill from the shadows: Shadow Step -> Throat Slit (70)
		ClassData._sk(n, "shadow_step", "Shadow Step", "ก้าวเงาวาร์ปไปหลังศัตรูไกลถึง 8 เมตรแล้วแทงซ้ำ", 10, 14, 7.0, "single", 4.0, {"range": 8.0, "anim": "1H_Melee_Attack_Stab", "color": night, "icon": "boots"}),
		ClassData._sk(n, "throat_slit", "Throat Slit", "ปาดคอศัตรูตัวเดียวในพริบตา มึนงง 0.8 วินาที", 70, 60, 8.0, "single", 12.6, {"range": 3.3, "fx": {"stun": 0.8}, "color": blood, "icon": "sword"}),
		# 4 area: Blade Flurry -> Thousand Cuts (60) -> Abyss Vortex (90)
		ClassData._sk(n, "blade_flurry", "Blade Flurry", "หมุนมีดคู่เป็นพายุใบมีดรอบตัว", 15, 16, 8.0, "burst", 2.4, {"radius": 4.2, "special": "spin", "color": night, "icon": "spin"}),
		ClassData._sk(n, "thousand_cuts", "Thousand Cuts", "พันคมเงาฟันกระจายรอบตัว", 60, 56, 12.0, "burst", 6.4, {"radius": 6.2, "special": "spin", "color": night, "icon": "spin"}),
		ClassData._sk(n, "abyss_vortex", "Abyss Vortex", "วังวนนรกดูดศัตรูรอบตัว ช้าลงและถูกฉีกต่อเนื่อง", 90, 96, 14.0, "burst", 6, {"radius": 7.5, "special": "spin", "fx": {"slow": 3.0}, "color": night, "icon": "spin"}),
		# 5 thrown knives: Fan of Knives -> Phantom Legion (90)
		ClassData._sk(n, "fan_of_knives", "Fan of Knives", "ขว้างมีดเงาแผ่เป็นพัด 5 เล่ม", 20, 20, 8.0, "fan", 2.4, {"hits": 5, "range": 11.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": night, "icon": "triple"}),
		ClassData._sk(n, "phantom_legion", "Phantom Legion", "กองทัพเงาขว้างมีดพุ่งออก 8 ทิศ", 90, 96, 13.0, "fan", 4, {"hits": 8, "range": 12.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": night, "icon": "triple"}),
		# 6 area + stun + slow: Smoke Bomb -> Midnight Execution (80)
		ClassData._sk(n, "smoke_bomb", "Smoke Bomb", "ปาระเบิดควัน ศัตรูรอบตัวมึนงง 1.2 วินาทีและช้าลง", 30, 26, 16.0, "burst", 1.2, {"radius": 5.0, "fx": {"stun": 1.2, "slow": 3.0}, "anim": "Dodge_Backward", "vfx": &"impact", "color": Color("b8a8d8"), "icon": "nova"}),
		ClassData._sk(n, "midnight_execution", "Midnight Execution", "ประหารเที่ยงคืน กระโจนลงกลางฝูงศัตรู มึนงง 1.2 วินาทีและช้าลง", 80, 90, 14.0, "blast", 6, {"radius": 7.0, "range": 11.0, "fx": {"stun": 1.2, "slow": 3.0}, "anim": "Dualwield_Melee_Attack_Chop", "hit_delay": 0.5, "vfx": &"impact", "color": blood, "icon": "meteor"}),
		# 7 attack buff: Killing Focus -> Night Lord (76) -> Shadow Sovereign (96)
		ClassData._sk(n, "killing_focus", "Killing Focus", "จิตนักฆ่า คริติคอล +15% ATK +25% นาน 1 นาที", 40, 36, 30.0, "self", 0.0, {"fx": {"buff": {"crit": 0.15, "atk": 0.25, "secs": 60.0}}, "color": blood, "icon": "roar"}),
		ClassData._sk(n, "night_lord", "Night Lord", "จ้าวราตรี ATK +35% คริติคอล +20% วิ่งเร็ว +15% ฟื้น HP 20% นาน 1 นาที", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.35, "crit": 0.2, "speed": 0.15, "secs": 60.0}}, "color": night, "icon": "roar"}),
		ClassData._sk(n, "shadow_sovereign", "Shadow Sovereign", "ราชันแห่งเงา ATK +55% คริติคอล +25% หลบ +15% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.25, "dodge": 0.15, "secs": 60.0}}, "color": night, "icon": "bless"}),
		# 8 ultimate: Shadow Dance (50) -> Oblivion Requiem (100)
		ClassData._sk(n, "shadow_dance", "Shadow Dance", "ระบำเงา ฟันกระโดดต่อเนื่องใส่ศัตรู 6 ตัว", 50, 50, 11.0, "chain", 5, {"hits": 6, "range": 10.0, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"slash", "color": night, "icon": "triple"}),
		ClassData._sk(n, "oblivion_requiem", "Oblivion Requiem", "บทเพลงลืมเลือน เงามืดปะทุฉีกทุกสิ่งรอบตัว ศัตรูมึนงง 1.5 วินาที", 100, 130, 16.0, "burst", 10.5, {"radius": 9.0, "fx": {"stun": 1.5}, "special": "spin", "vfx": &"slash", "color": blood, "icon": "nova"}),
	]
