extends RefCounted
## Lancer (นักหอก): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[0.691, 0.691], [0.553, 0.737], [0.793, 0.793]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["thrust", "dragon_tooth", "sky_pierce"],  # single, pierces
	["stagger", "hook_strike"],  # single + stun
	["whirl", "typhoon_spear", "gale_cyclone"],  # area spin
	["charge_dash", "vanguard_strike"],  # dash + stun
	["spear_wave", "dragon_lance"],  # long reach
	["wind_stance", "lancer_rush", "valkyrie_blessing"],  # attack buff
	["iron_resolve", "dragon_stance"],  # defence buff + heal
	["gungnir", "ragnarok_lance"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id is refunded and dropped.
const OLD_IDS := {
	"dragon_fang": "spear_mastery",
	"keen_point": "light_footwork",
	"valkyrie_heart": "iron_stance",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "spear_mastery", "name": "Spear Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "light_footwork", "name": "Light Footwork", "desc": "ความเร็ว +4% หลบ +0.6% และคริติคอล +1.5% ต่อดาว", "level": 20, "bonus": {"speed": 0.04, "dodge": 0.006, "crit": 0.015}},
	{"id": "iron_stance", "name": "Iron Stance", "desc": "พลังป้องกัน +4% และ HP สูงสุด +4% ต่อดาว", "level": 60, "bonus": {"def": 0.04, "hp": 0.04}},
]


## A pierce spec: [n] enemies along a [length] m line [width] m wide, [keep] of the
## damage to each one behind the first.
static func _pc(n: int, length: float, width := 1.3, keep := 0.7) -> Dictionary:
	return {"n": n, "len": length, "w": width, "k": keep}

## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var l := &"lancer"
	return [
		# single, pierces: thrust (1) -> dragon_tooth (60) -> sky_pierce (90)
		ClassData._sk(l, "thrust", "Thrust", "แทงหอกใส่ศัตรูตัวเดียว ทะลุไปโดนตัวหลังอีก 2 ตัว", 1, 9, 4.0, "single", 3.0, {"pierce": _pc(2, 6.5), "color": Color("9ad8ff"), "icon": "sword"}),
		ClassData._sk(l, "dragon_tooth", "Dragon Tooth", "เขี้ยวมังกร แทงทะลุศัตรู 6 ตัว", 60, 58, 10.0, "single", 8.5, {"pierce": _pc(6, 10.0, 1.5), "color": Color("ff8a4a"), "icon": "sword"}),
		ClassData._sk(l, "sky_pierce", "Sky Pierce", "หอกพุ่งทะลุฟ้า แทงเป็นเส้นยาวทะลุ 8 ตัว", 90, 92, 11.0, "single", 9.5, {"range": 10.0, "pierce": _pc(8, 13.0, 1.6), "vfx": &"light", "color": Color("d8f0ff"), "icon": "arrow"}),
		# single + stun: stagger (5) -> hook_strike (60)
		ClassData._sk(l, "stagger", "Stagger", "ด้ามหอกกระแทก ศัตรูมึนงง 1.2 วินาที", 5, 12, 6.0, "single", 3.2, {"fx": {"stun": 1.2}, "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		ClassData._sk(l, "hook_strike", "Hook Strike", "เกี่ยวด้วยใบมีดข้างหอก ศัตรูมึนงง 1.5 วินาที", 60, 58, 9.0, "single", 7.0, {"fx": {"stun": 1.5}, "pierce": _pc(2, 7.0), "vfx": &"impact", "color": Color("ffe27a"), "icon": "shield"}),
		# area spin: whirl (10) -> typhoon_spear (60) -> gale_cyclone (90)
		ClassData._sk(l, "whirl", "Whirl", "หมุนหอกฟาดรอบตัว", 10, 16, 8.0, "burst", 2.7, {"radius": 4.6, "special": "spin", "color": Color("9ad8ff"), "icon": "spin"}),
		ClassData._sk(l, "typhoon_spear", "Typhoon Spear", "พายุหอกหมุนถล่มรอบตัว ศัตรูช้าลง", 60, 62, 12.0, "burst", 9.0, {"radius": 6.5, "special": "spin", "fx": {"slow": 2.5}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		ClassData._sk(l, "gale_cyclone", "Gale Cyclone", "ไซโคลนหอกพัดถล่มรอบตัว ศัตรูช้าลง", 90, 96, 14.0, "burst", 14.0, {"radius": 7.5, "special": "spin", "fx": {"slow": 3.0}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		# dash + stun: charge_dash (15) -> vanguard_strike (70)
		ClassData._sk(l, "charge_dash", "Charge Dash", "พุ่งเข้าใส่แล้วแทง ศัตรูมึนงงสั้นๆ", 15, 18, 8.0, "single", 5.0, {"range": 8.5, "fx": {"stun": 0.6}, "pierce": _pc(2, 8.5), "color": Color("ffb04a"), "icon": "boots"}),
		ClassData._sk(l, "vanguard_strike", "Vanguard Strike", "พุ่งแทงแนวหน้าทรงพลัง ทะลุ 4 ตัว ศัตรูมึนงงสั้นๆ", 70, 70, 9.0, "single", 12.0, {"range": 4.6, "fx": {"stun": 0.6}, "pierce": _pc(4, 9.0, 1.5), "color": Color("6ecbff"), "icon": "sword"}),
		# long reach: spear_wave (20) -> dragon_lance (80)
		ClassData._sk(l, "spear_wave", "Spear Wave", "คลื่นหอกพุ่งไกลทะลุ 5 ตัว", 20, 24, 9.0, "single", 4.8, {"range": 9.0, "pierce": _pc(5, 11.0, 1.5), "vfx": &"impact", "color": Color("b8e6ff"), "icon": "arrow"}),
		ClassData._sk(l, "dragon_lance", "Dragon Lance", "หอกมังกรเพลิงแทงทะลุ 8 ตัว ติดไฟ", 80, 90, 11.0, "single", 14.0, {"range": 5.0, "pierce": _pc(8, 14.0, 1.6), "fx": {"burn": [0.4, 5.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		# attack buff: wind_stance (30) -> lancer_rush (64) -> valkyrie_blessing (88)
		ClassData._sk(l, "wind_stance", "Wind Stance", "ท่าลม วิ่งเร็ว +30% คริติคอล +12% ATK +15% นาน 1 นาที", 30, 26, 30.0, "self", 0.0, {"fx": {"buff": {"speed": 0.3, "crit": 0.12, "atk": 0.15, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
		ClassData._sk(l, "lancer_rush", "Lancer Rush", "บุกทะลวง ATK +45% วิ่งเร็ว +25% คริติคอล +10% นาน 1 นาที", 64, 60, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.45, "speed": 0.25, "crit": 0.1, "secs": 60.0}}, "color": Color("ff9a5a"), "icon": "boots"}),
		ClassData._sk(l, "valkyrie_blessing", "Valkyrie's Blessing", "พรวัลคีรี ATK +60% วิ่งเร็ว +20% คริติคอล +15% นาน 1 นาที", 88, 96, 45.0, "self", 0.0, {"fx": {"buff": {"atk": 0.6, "speed": 0.2, "crit": 0.15, "secs": 60.0}}, "color": Color("ffe9a0"), "icon": "bless"}),
		# defence buff + heal: iron_resolve (40) -> dragon_stance (76)
		ClassData._sk(l, "iron_resolve", "Iron Resolve", "ใจเหล็ก DEF +50% ฟื้นฟู HP 15% นาน 1 นาที", 40, 38, 32.0, "self", 0.0, {"fx": {"heal": 0.15, "buff": {"def": 0.5, "secs": 60.0}}, "color": Color("c0d0e8"), "icon": "shield"}),
		ClassData._sk(l, "dragon_stance", "Dragon Stance", "ท่ามังกร ATK +40% DEF +40% ฟื้นฟู HP 20% นาน 1 นาที", 76, 70, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.4, "def": 0.4, "secs": 60.0}}, "color": Color("ffb04a"), "icon": "shield"}),
		# ultimate: gungnir (50) -> ragnarok_lance (100)
		ClassData._sk(l, "gungnir", "Gungnir", "ขว้างหอกเทพเจ้า ทะลุศัตรู 5 ตัวเป็นแนวยาว", 50, 50, 13.0, "single", 17.0, {"range": 13.0, "pierce": _pc(5, 15.0, 1.8), "vfx": &"light", "color": Color("fff0a0"), "icon": "arrow"}),
		ClassData._sk(l, "ragnarok_lance", "Ragnarok Lance", "หอกแห่งวันสิ้นโลก แทงทะลุศัตรู 10 ตัว", 100, 140, 14.0, "single", 26.0, {"range": 5.5, "pierce": _pc(10, 15.0, 1.8, 0.8), "vfx": &"light", "color": Color("ffd84a"), "icon": "sword"}),
	]
