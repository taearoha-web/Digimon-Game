extends RefCounted
## Priest (นักบวช): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.
## The heal line keeps Healing as its first stage, so ClassData.AI_ALL_HEALS and the
## AI buff kit find it by line id.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[1.718, 1.718], [0.74, 0.74], [1.8, 1.8]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["holy_bolt", "judgement_light", "divine_judgment"],  # single
	["healing", "hand_of_god", "prayer"],  # heal
	["multi_spark", "vigor_ball", "seraphim_wrath"],  # fan
	["divine_lightning", "chain_lightning"],  # chain
	["holy_mind", "glacial_spike"],  # slow
	["holy_reflection", "blessing_aura", "miracle"],  # buff
	["extinction", "heaven_light", "last_judgement"],  # holy area
	["summon_muspell"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (grand_healing, virtual_life, resurrection, regeneration_field,
## holy_rain_big) is refunded and dropped.
const OLD_IDS := {
	"faith": "divine_grace",
	"sanctity": "divine_grace",
	"divine_power": "holy_aura",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "meditation", "name": "Meditation", "desc": "MP สูงสุด +5% ต่อดาว", "level": 1, "bonus": {"mp": 0.05}},
	{"id": "divine_grace", "name": "Divine Grace", "desc": "HP สูงสุด +8% และพลังป้องกัน +4% ต่อดาว", "level": 20, "bonus": {"hp": 0.08, "def": 0.04}},
	{"id": "holy_aura", "name": "Holy Aura", "desc": "พลังโจมตี +4.5% และ MP +3% ต่อดาว", "level": 30, "bonus": {"atk": 0.045, "mp": 0.03}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var p := &"priest"
	return [
		# 1 single: Holy Bolt -> Judgement (60) -> Divine Judgment (90)
		ClassData._sk(p, "holy_bolt", "Holy Bolt", "ลำแสงศักดิ์สิทธิ์โจมตีศัตรูตัวเดียว", 1, 10, 3.0, "single", 3.2, {"color": Color("fff2a0"), "icon": "light"}),
		ClassData._sk(p, "judgement_light", "Judgement", "แสงพิพากษาผ่าลงใส่ศัตรูตัวเดียว", 60, 70, 12.0, "single", 10.0, {"projectile": false, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		ClassData._sk(p, "divine_judgment", "Divine Judgment", "คำพิพากษาแห่งสวรรค์ผ่าลงศัตรูตัวเดียว มึนงง 1.5 วินาที", 90, 110, 16.0, "single", 15.0, {"projectile": false, "fx": {"stun": 1.5}, "vfx": &"light", "color": Color("ffe08a"), "icon": "nova"}),
		# 2 heal: Healing -> Hand of God (60) -> Prayer (90)
		ClassData._sk(p, "healing", "Healing", "ฟื้นฟู HP ของตัวเอง 40%", 5, 14, 9.0, "self", 0.0, {"fx": {"heal": 0.4}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("6dff9a"), "icon": "heal"}),
		ClassData._sk(p, "hand_of_god", "Hand of God", "มือพระเจ้า ฟื้นฟู HP 90%", 60, 80, 24.0, "self", 0.0, {"fx": {"heal": 0.9}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		ClassData._sk(p, "prayer", "Prayer", "สวดมนต์ ฟื้นฟู HP 100% และ DEF +50% นาน 1 นาที", 90, 120, 50.0, "self", 0.0, {"fx": {"heal": 1.0, "buff": {"def": 0.5, "secs": 60.0}}, "vfx": &"heal", "anim": "Spellcast_Raise", "color": Color("d8ffe0"), "icon": "heal"}),
		# 3 fan: Multi Spark -> Vigor Ball (40) -> Seraphim Wrath (90)
		ClassData._sk(p, "multi_spark", "Multi Spark", "ยิงลูกประกายสายฟ้า 4 ลูก", 10, 16, 7.0, "fan", 2.0, {"hits": 4, "vfx": &"thunder", "color": Color("fff06a"), "icon": "triple"}),
		ClassData._sk(p, "vigor_ball", "Vigor Ball", "ลูกพลังชีวิต 5 ลูกพุ่งใส่ศัตรู", 40, 38, 9.0, "fan", 3.0, {"hits": 5, "color": Color("ffe9a0"), "icon": "triple"}),
		ClassData._sk(p, "seraphim_wrath", "Seraphim Wrath", "ลูกแสงเสราฟิม 9 ลูกพุ่งใส่ศัตรู", 90, 118, 14.0, "fan", 5.5, {"hits": 9, "color": Color("fff0a0"), "icon": "triple"}),
		# 4 chain: Divine Lightning -> Chain Lightning (60)
		ClassData._sk(p, "divine_lightning", "Divine Lightning", "สายฟ้าสวรรค์กระโดดไปหาศัตรูสูงสุด 5 ตัว", 15, 22, 9.0, "chain", 2.8, {"hits": 5, "color": Color("fff06a"), "icon": "bolt"}),
		ClassData._sk(p, "chain_lightning", "Chain Lightning", "สายฟ้าสวรรค์ฟาดศัตรู 8 ตัว", 60, 70, 11.0, "chain", 5.5, {"hits": 8, "color": Color("fff06a"), "icon": "bolt"}),
		# 5 slow: Holy Mind -> Glacial Spike (60)
		ClassData._sk(p, "holy_mind", "Holy Mind", "จิตศักดิ์สิทธิ์ ทำร้ายและทำให้ศัตรูช้าลง 4 วินาที", 20, 20, 10.0, "single", 3.4, {"fx": {"slow": 4.0}, "color": Color("ffe9a0"), "icon": "light"}),
		ClassData._sk(p, "glacial_spike", "Glacial Spike", "หอกน้ำแข็งแทงพื้น ศัตรูช้าลง", 60, 56, 14.0, "blast", 6.0, {"radius": 6.0, "fx": {"slow": 4.0}, "vfx": &"frost", "color": Color("aaf0ff"), "icon": "ice"}),
		# 6 buff: Holy Reflection -> Blessing Aura (64) -> Miracle (96)
		ClassData._sk(p, "holy_reflection", "Holy Reflection", "โล่แสงสะท้อน DEF +45% นาน 1 นาที", 30, 28, 30.0, "self", 0.0, {"fx": {"buff": {"def": 0.45, "secs": 60.0}}, "anim": "Spellcast_Raise", "color": Color("fff0a0"), "icon": "shield"}),
		ClassData._sk(p, "blessing_aura", "Blessing Aura", "ATK +50% DEF +40% นาน 1 นาที", 64, 84, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.4, "secs": 60.0}}, "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		ClassData._sk(p, "miracle", "Miracle", "ปาฏิหาริย์ ATK +80% DEF +60% ฟื้นฟู HP 50% นาน 1 นาที", 96, 140, 55.0, "self", 0.0, {"fx": {"heal": 0.5, "buff": {"atk": 0.8, "def": 0.6, "secs": 60.0}}, "vfx": &"aura", "anim": "Spellcast_Raise", "color": Color("ffe27a"), "icon": "bless"}),
		# 7 holy area: Extinction (40) -> Heaven Light (70) -> Last Judgement (100)
		ClassData._sk(p, "extinction", "Extinction", "คลื่นแสงล้างบาปรอบตัว ฟื้นฟู HP 10%", 40, 46, 14.0, "burst", 5.2, {"radius": 6.5, "fx": {"heal": 0.1}, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		ClassData._sk(p, "heaven_light", "Heaven Light", "แสงสวรรค์ถล่มรอบตัว ฟื้นฟู HP 15%", 70, 90, 14.0, "burst", 10.5, {"radius": 8.0, "fx": {"heal": 0.15}, "vfx": &"light", "color": Color("fff0a0"), "icon": "nova"}),
		ClassData._sk(p, "last_judgement", "Last Judgement", "การพิพากษาครั้งสุดท้ายถล่มพื้นที่ ศัตรูมึนงง 2 วินาที", 100, 180, 24.0, "blast", 24.0, {"radius": 12.0, "fx": {"stun": 2.0}, "vfx": &"light", "color": Color("ffd36b"), "icon": "nova"}),
		# 8 ultimate: Summon Muspell (50)
		ClassData._sk(p, "summon_muspell", "Summon Muspell", "เรียกวิญญาณพิทักษ์ผู้ยิ่งใหญ่มาช่วยรบนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 50, 76, 36.0, "summon", 4.4, {"summon": {"kind": "muspell", "count": 1, "secs": 120.0, "interval": 1.2}, "color": Color("aaf0ff"), "icon": "nova"}),
	]
