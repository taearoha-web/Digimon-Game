extends RefCounted
## Archer (นักธนู): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[0.69, 0.46], [0.7, 0.56], [0.62, 0.69]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["wind_arrow", "perforation", "lightning_arrow"],  # single
	["elemental_shot", "phoenix_shot", "lethal_sight"],  # single + burn
	["arrow_of_rage", "fierce_wind", "dragon_shot"],  # fan
	["avalanche", "tempest", "phoenix_rain"],  # arrow rain
	["ensnare", "hurricane"],  # area + slow
	["scout_hawk", "dionic_sight", "spirit_of_wind"],  # attack buff
	["golden_falcon", "recall_wolverine", "force_of_nature"],  # summon
	["meteor_arrow"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (perfect_aim, bomb_shot, arrow_of_thunder) is refunded and dropped.
const OLD_IDS := {
	"ranger_mastery": "shooting_mastery",
	"evasion_mastery": "wind_step",
	"wind_walker": "wind_step",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "shooting_mastery", "name": "Shooting Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "wind_step", "name": "Wind Step", "desc": "ความเร็ว +5% และหลบหลีก +1.6% ต่อดาว", "level": 20, "bonus": {"speed": 0.05, "dodge": 0.016}},
	{"id": "hawk_eye", "name": "Hawk Eye", "desc": "คริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"crit": 0.015}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var a := &"archer"
	return [
		# 1 single: Wind Arrow -> Perforation (60) -> Lightning Arrow (90)
		ClassData._sk(a, "wind_arrow", "Wind Arrow", "ลูกศรลมพุ่งเร็วใส่ศัตรูตัวเดียว", 1, 9, 3.0, "single", 3.0, {"color": Color("8fff9a"), "vfx": &"leaf", "icon": "arrow"}),
		ClassData._sk(a, "perforation", "Perforation", "ลูกศรเจาะทะลวงเกราะ แรงมาก", 60, 44, 8.0, "single", 7.0, {"range": 16.0, "color": Color("ffe27a"), "icon": "arrow"}),
		ClassData._sk(a, "lightning_arrow", "Lightning Arrow", "ลูกศรสายฟ้าฟาดศัตรูตัวเดียว", 90, 92, 10.0, "single", 19.0, {"range": 18.0, "vfx": &"thunder", "color": Color("fff06a"), "icon": "bolt"}),
		# 2 single + burn: Elemental Shot -> Phoenix Shot (60) -> Lethal Sight (90)
		ClassData._sk(a, "elemental_shot", "Elemental Shot", "ลูกศรธาตุไฟ ติดไฟต่อเนื่อง", 5, 12, 6.0, "single", 5.0, {"fx": {"burn": [0.35, 4.0]}, "vfx": &"fireball", "color": Color("ff7a2a"), "icon": "fire"}),
		ClassData._sk(a, "phoenix_shot", "Phoenix Shot", "ลูกศรนกฟีนิกซ์ แรงมหาศาล ติดไฟแรง", 60, 50, 12.0, "single", 9.0, {"range": 16.0, "fx": {"burn": [0.5, 5.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		ClassData._sk(a, "lethal_sight", "Lethal Sight", "เล็งสังหาร ยิงแรงมากจากระยะไกล ติดไฟแรง", 90, 90, 9.0, "single", 10.5, {"range": 17.0, "fx": {"burn": [0.5, 5.0]}, "color": Color("ffd84a"), "icon": "arrow"}),
		# 3 fan: Arrow of Rage -> Fierce Wind (60) -> Dragon Shot (90)
		ClassData._sk(a, "arrow_of_rage", "Arrow of Rage", "ยิง 3 ดอกพร้อมกัน", 10, 14, 7.0, "fan", 2.0, {"hits": 3, "color": Color("b8f07a"), "icon": "triple"}),
		ClassData._sk(a, "fierce_wind", "Fierce Wind", "ลมกระโชกยิงลูกศร 7 ดอกพร้อมกัน", 60, 62, 11.0, "fan", 5.5, {"hits": 7, "range": 13.0, "color": Color("8fffd0"), "icon": "triple"}),
		ClassData._sk(a, "dragon_shot", "Dragon Shot", "ลูกศรมังกร 10 ดอกพุ่งใส่ศัตรู", 90, 110, 16.0, "fan", 6.5, {"hits": 10, "range": 14.0, "vfx": &"fireball", "color": Color("ff8a3a"), "icon": "triple"}),
		# 4 arrow rain: Avalanche -> Tempest (60) -> Phoenix Rain (90)
		ClassData._sk(a, "avalanche", "Avalanche", "ห่าลูกศรถล่มพื้นที่เป้าหมาย", 15, 18, 10.0, "blast", 3.2, {"radius": 4.5, "special": "rain", "color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"}),
		ClassData._sk(a, "tempest", "Tempest", "ห่าลูกศรพายุถล่มพื้นที่กว้าง", 60, 66, 16.0, "blast", 14.0, {"radius": 8.0, "special": "rain", "color": Color("ffd84a"), "vfx": &"leaf", "icon": "rain"}),
		ClassData._sk(a, "phoenix_rain", "Phoenix Rain", "ฝนลูกศรเพลิงฟีนิกซ์ ติดไฟรุนแรง", 90, 104, 18.0, "blast", 15.0, {"radius": 8.5, "special": "rain", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		# 5 area + slow: Ensnare -> Hurricane (70)
		ClassData._sk(a, "ensnare", "Ensnare", "ห่าลูกศรบ่วงพันธนาการ ศัตรูช้าลง 5 วินาที", 20, 24, 13.0, "blast", 8.0, {"radius": 6.0, "special": "rain", "fx": {"slow": 5.0}, "color": Color("b8f0a0"), "vfx": &"leaf", "icon": "rain"}),
		ClassData._sk(a, "hurricane", "Hurricane", "พายุลมถล่มรอบตัว ศัตรูช้าลง 3 วินาที", 70, 74, 12.0, "burst", 10.0, {"radius": 7.0, "fx": {"slow": 3.0}, "vfx": &"wind", "color": Color("7affd0"), "icon": "spin"}),
		# 6 attack buff: Scout Hawk -> Dionic Sight (60) -> Spirit of the Wind (90)
		ClassData._sk(a, "scout_hawk", "Scout Hawk", "เหยี่ยวสอดแนม ATK +20% คริติคอล +12% นาน 1 นาที", 30, 22, 28.0, "self", 0.0, {"fx": {"buff": {"atk": 0.2, "crit": 0.12, "secs": 60.0}}, "color": Color("ffd27a"), "icon": "boots"}),
		ClassData._sk(a, "dionic_sight", "Dionic Sight", "ตาแห่งสวรรค์ คริติคอล +30% ATK +20% นาน 1 นาที", 60, 52, 36.0, "self", 0.0, {"fx": {"buff": {"crit": 0.3, "atk": 0.2, "secs": 60.0}}, "color": Color("ffe27a"), "icon": "boots"}),
		ClassData._sk(a, "spirit_of_wind", "Spirit of the Wind", "วิ่งเร็ว +40% ATK +60% คริ +15% นาน 1 นาที", 90, 100, 45.0, "self", 0.0, {"fx": {"buff": {"speed": 0.4, "atk": 0.6, "crit": 0.15, "secs": 60.0}}, "color": Color("7affd0"), "icon": "boots"}),
		# 7 summon: Golden Falcon -> Recall Wolverine (60) -> Force of Nature (80)
		ClassData._sk(a, "golden_falcon", "Golden Falcon", "เรียกเหยี่ยวทองบินโจมตีศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล) และฟื้นฟู HP ให้คุณเมื่อมันโจมตี", 40, 34, 30.0, "summon", 2.4, {"summon": {"kind": "falcon", "count": 1, "secs": 120.0, "interval": 1.0, "heal": 0.01}, "color": Color("ffe27a"), "icon": "triple"}),
		ClassData._sk(a, "recall_wolverine", "Recall Wolverine", "เรียกหมาป่า 2 ตัวกระโจนกัดศัตรูนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 60, 54, 34.0, "summon", 3.2, {"summon": {"kind": "spirit_wolf", "count": 2, "secs": 120.0, "interval": 0.9}, "color": Color("c9e8a0"), "icon": "triple"}),
		ClassData._sk(a, "force_of_nature", "Force of Nature", "เรียกอสูรแห่งธรรมชาติ 2 ตัวมาช่วยรบนาน 2 นาทีหรือจนกว่าจะถูกสังหาร (ใหญ่ขึ้นตามดาวสกิล)", 80, 80, 36.0, "summon", 4.6, {"summon": {"kind": "cactus", "count": 2, "secs": 120.0, "interval": 1.1}, "color": Color("7aff8a"), "icon": "triple"}),
		# 8 ultimate: Meteor Arrow (50)
		ClassData._sk(a, "meteor_arrow", "Meteor Arrow", "ลูกศรอุกกาบาตจากฟ้า พลังทำลายล้างสูงสุด", 50, 60, 15.0, "single", 28.0, {"range": 20.0, "vfx": &"fireball", "fx": {"burn": [0.6, 6.0]}, "color": Color("ff5a2a"), "icon": "meteor"}),
	]
