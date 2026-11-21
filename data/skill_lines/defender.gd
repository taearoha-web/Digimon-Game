extends RefCounted
## Defender (ผู้พิทักษ์): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[1.395, 1.395], [1.647, 1.796], [1.8, 1.61]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["shield_bash", "aegis_strike", "judgment_shield"],  # single
	["brace"],  # signature: เบ่งเลือด (SIGNATURE_BUFFS, must stay the line id)
	["shield_slam", "bastion_crush"],  # single + stun
	["provoke", "grand_provoke"],  # taunt
	["ground_quake", "titan_quake", "holy_rampart"],  # area around + stun
	["iron_wall", "sanctuary_wall"],  # team guard buff
	["thorn_guard", "unbreakable", "aegis_of_ages"],  # reflect / self guard
	["meteor_shield", "world_bastion"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id is refunded and dropped.
const OLD_IDS := {
	"stalwart": "shield_mastery",
	"living_fortress": "iron_body",
	"heavy_impact": "bash_mastery",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "shield_mastery", "name": "Shield Mastery", "desc": "พลังป้องกัน +8% ต่อดาว", "level": 1, "bonus": {"def": 0.08}},
	{"id": "iron_body", "name": "Iron Body", "desc": "HP สูงสุด +9% และพลังป้องกัน +3% ต่อดาว", "level": 20, "bonus": {"hp": 0.09, "def": 0.03}},
	{"id": "bash_mastery", "name": "Bash Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 60, "bonus": {"atk": 0.05}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var d := &"defender"
	return [
		# single: shield_bash (1) -> aegis_strike (60) -> judgment_shield (90)
		ClassData._sk(d, "shield_bash", "Shield Bash", "ฟาดขอบโล่ใส่ศัตรูตัวเดียว", 1, 10, 3.0, "single", 2.6, {"anim": "Block_Attack", "vfx": &"impact", "color": Color("bcd6f0"), "icon": "shield"}),
		ClassData._sk(d, "aegis_strike", "Aegis Strike", "ฟาดโล่สุดแรงใส่ศัตรูตัวเดียว", 60, 58, 8.0, "single", 7.4, {"range": 3.2, "anim": "Block_Attack", "vfx": &"impact", "color": Color("9fd0ff"), "icon": "shield"}),
		ClassData._sk(d, "judgment_shield", "Judgment Shield", "ฟาดโล่แห่งคำพิพากษาใส่ศัตรูตัวเดียว", 90, 92, 10.0, "single", 17.0, {"range": 3.6, "anim": "2H_Melee_Attack_Slice", "vfx": &"light", "color": Color("fff0a0"), "icon": "shield"}),
		# signature: เบ่งเลือด (SIGNATURE_BUFFS, must stay the line id): brace (5)
		# เบ่งเลือด (was Brace, same id so saves keep their stars): max HP +30% and damage taken
		# -10% at ★1, up to +50% / -25% at ★5 (the buff's "grow", SkillRank.scaled_fx), 1 minute.
		# The max HP is a ceiling for the whole party ("party": only "hp" is shared,
		# BuffBook.party_part): it fills no HP. The damage cut is the Defender's own.
		# A 25 s cooldown keeps it up all the time. Its line id stays "brace" (SIGNATURE_BUFFS).
		ClassData._sk(d, "brace", "เบ่งเลือด", "เพิ่มเพดาน HP สูงสุดของทุกคนในปาร์ตี้ +30% (ไม่เติมเลือด) และผู้พิทักษ์ลดความเสียหายที่ได้รับ 10% นาน 1 นาที (★5: HP สูงสุด +50% ลดดาเมจ 25%)", 5, 12, 25.0, "self", 0.0, {"fx": {"buff": {"hp": 0.30, "guard": 0.10, "secs": 60.0, "party": ["hp"], "grow": {"hp": 0.05, "guard": 0.0375}}}, "anim": "Blocking", "color": Color("ff6b6b"), "icon": "shield"}),
		# single + stun: shield_slam (10) -> bastion_crush (70)
		ClassData._sk(d, "shield_slam", "Shield Slam", "กระแทกหน้าโล่ใส่ศัตรู มึนงง 1.5 วินาที", 10, 14, 6.0, "single", 3.8, {"fx": {"stun": 1.5}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		ClassData._sk(d, "bastion_crush", "Bastion Crush", "กดโล่บดขยี้ศัตรูตัวเดียว มึนงง 1.5 วินาที", 70, 70, 8.0, "single", 12.0, {"range": 3.4, "fx": {"stun": 1.5}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("ff8a5a"), "icon": "shield"}),
		# taunt: provoke (15) -> grand_provoke (72)
		ClassData._sk(d, "provoke", "Provoke", "เคาะโล่ท้าทาย ศัตรูรอบตัวช้าลงและหันมาโจมตีคุณ 4 วินาที", 15, 18, 14.0, "burst", 1.5, {"radius": 7.0, "fx": {"taunt": 4.0, "slow": 2.0}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ff9a6a"), "icon": "roar"}),
		ClassData._sk(d, "grand_provoke", "Grand Provoke", "ท้ารบทั้งสนาม ศัตรูรอบตัวช้าลงและหันมาโจมตีคุณ 5 วินาที", 72, 70, 16.0, "burst", 2.0, {"radius": 8.0, "fx": {"taunt": 5.0, "slow": 2.0}, "anim": "Block_Attack", "vfx": &"impact", "color": Color("ff7a4a"), "icon": "roar"}),
		# area around + stun: ground_quake (20) -> titan_quake (60) -> holy_rampart (80)
		ClassData._sk(d, "ground_quake", "Ground Quake", "ทุบโล่ลงพื้น ศัตรูรอบตัวช้าลง 2 วินาที", 20, 20, 9.0, "burst", 2.4, {"radius": 4.5, "fx": {"slow": 2.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("d8b98a"), "icon": "nova"}),
		ClassData._sk(d, "titan_quake", "Titan Quake", "ทุบพสุธาด้วยโล่ยักษ์ ศัตรูรอบตัวมึนงง 1 วินาที", 60, 62, 12.0, "burst", 7.5, {"radius": 6.5, "fx": {"stun": 1.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": Color("ffb06a"), "icon": "spin"}),
		ClassData._sk(d, "holy_rampart", "Holy Rampart", "กำแพงแสงระเบิดรอบตัว ศัตรูมึนงง 1.5 วินาที", 80, 90, 16.0, "burst", 11.5, {"radius": 7.5, "fx": {"stun": 1.5}, "anim": "2H_Melee_Attack_Spin", "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		# team guard buff: iron_wall (30) -> sanctuary_wall (96)
		ClassData._sk(d, "iron_wall", "Iron Wall", "กำแพงเหล็ก DEF +50% ลดความเสียหาย 15% นาน 1 นาที (ส่งถึงทีม)", 30, 26, 32.0, "self", 0.0, {"fx": {"buff": {"def": 0.5, "guard": 0.15, "secs": 60.0}}, "anim": "Blocking", "color": Color("a8c8e8"), "icon": "shield"}),
		ClassData._sk(d, "sanctuary_wall", "Sanctuary Wall", "กำแพงวิหาร DEF +50% ATK +40% ลดความเสียหาย 25% นาน 1 นาที (ส่งถึงทีม)", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "def": 0.5, "guard": 0.25, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffe9a0"), "icon": "bless"}),
		# reflect / self guard: thorn_guard (40) -> unbreakable (76) -> aegis_of_ages (88)
		ClassData._sk(d, "thorn_guard", "Thorn Guard", "โล่หนาม สะท้อนความเสียหาย 20% กลับใส่ผู้โจมตี DEF +20% นาน 1 นาที", 40, 36, 34.0, "self", 0.0, {"fx": {"buff": {"reflect": 0.2, "def": 0.2, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffb46a"), "icon": "shield"}),
		ClassData._sk(d, "unbreakable", "Unbreakable", "ไม่มีวันแตก DEF +80% ฟื้น HP 30% สะท้อนความเสียหาย 25% นาน 1 นาที", 76, 76, 42.0, "self", 0.0, {"fx": {"heal": 0.3, "buff": {"def": 0.8, "reflect": 0.25, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffd27a"), "icon": "shield"}),
		ClassData._sk(d, "aegis_of_ages", "Aegis of Ages", "อีจิสนิรันดร์ DEF +100% ฟื้น HP 40% โล่ดูดซับ 25% ของ HP สะท้อนความเสียหาย 30% นาน 1 นาที", 88, 90, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 1.0, "shield": 0.25, "reflect": 0.3, "secs": 60.0}}, "anim": "Blocking", "color": Color("ffffff"), "icon": "shield"}),
		# ultimate: meteor_shield (50) -> world_bastion (100)
		ClassData._sk(d, "meteor_shield", "Meteor Shield", "กระโดดทุบโล่ลงกลางฝูงศัตรู มึนงง 1.2 วินาที", 50, 50, 14.0, "blast", 13.5, {"radius": 7.0, "range": 11.0, "fx": {"stun": 1.2}, "anim": "2H_Melee_Attack_Slice", "hit_delay": 0.55, "vfx": &"impact", "color": Color("ffb04a"), "icon": "meteor"}),
		ClassData._sk(d, "world_bastion", "World Bastion", "ปักโล่ลงพิภพ คลื่นป้อมปราการถล่มรอบตัว ศัตรูมึนงง 2 วินาทีแล้วหันมาโจมตีคุณ", 100, 130, 16.0, "burst", 23.0, {"radius": 9.0, "fx": {"stun": 2.0, "taunt": 4.0}, "anim": "2H_Melee_Attack_Slice", "vfx": &"light", "color": Color("ffd84a"), "icon": "nova"}),
	]
