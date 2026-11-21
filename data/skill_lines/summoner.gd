extends RefCounted
## Summoner (นักอัญเชิญ): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[3.0, 0.62], [1.0, 2.3], [1.1, 1.28]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["thorn_shot", "sylvan_ray"],  # single
	["vine_lash", "nature_wrath"],  # multi-target
	["entangle", "world_tree"],  # area + slow
	["spore_burst", "earth_shatter", "cataclysm"],  # area around + slow
	["thorn_storm"],  # rain of thorns
	["forest_blessing", "spirit_link", "gaia_blessing"],  # team buff (ATK/DEF)
	["regrowth", "life_bloom", "fairy_spirit"],  # heal (at Lv.84 the healing fairy heals on her own)
	["wolf_pack", "alpha_wolves", "primal_legion", "elder_dragon"],  # ultimate: the beast summon
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id is refunded and dropped.
const OLD_IDS := {
	"primal_focus": "beast_tamer",
	"spirit_ward": "wild_vitality",
	"gaia_heart": "wild_vitality",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "nature_bond", "name": "Nature Bond", "desc": "MP สูงสุด +9% ต่อดาว", "level": 1, "bonus": {"mp": 0.09}},
	{"id": "beast_tamer", "name": "Beast Tamer", "desc": "พลังโจมตี +4.5% ต่อดาว", "level": 20, "bonus": {"atk": 0.045}},
	{"id": "wild_vitality", "name": "Wild Vitality", "desc": "HP สูงสุด +8% และพลังป้องกัน +4% ต่อดาว", "level": 60, "bonus": {"hp": 0.08, "def": 0.04}},
]


## A summon stage: [count] creatures of [kind] for 2 minutes, acting every [interval] s.
static func _sm(id: String, name: String, desc: String, level: int, mp: int, cd: float, mult: float, kind: String, count: int, interval: float, color: Color, extra := {}) -> Dictionary:
	var spec := {"kind": kind, "count": count, "secs": 120.0, "interval": interval}
	spec.merge(extra.get("spec", {}))
	return ClassData._sk(&"summoner", id, name, desc + " (นาน 2 นาทีหรือจนกว่าจะถูกสังหาร ใหญ่ขึ้นตามดาวสกิล)", level, mp, cd, "summon", mult, {"summon": spec, "color": color, "icon": "triple"})

## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var s := &"summoner"
	return [
		# single: thorn_shot (1) -> sylvan_ray (76)
		ClassData._sk(s, "thorn_shot", "Thorn Shot", "ยิงหนามธรรมชาติใส่ศัตรูตัวเดียว", 1, 9, 3.0, "single", 2.9, {"color": Color("a8f07a"), "icon": "arrow"}),
		ClassData._sk(s, "sylvan_ray", "Sylvan Ray", "รังสีแห่งป่าใส่ศัตรูตัวเดียว", 76, 78, 9.0, "single", 14.0, {"range": 12.0, "vfx": &"leaf", "color": Color("b8ffa0"), "icon": "light"}),
		# multi-target: vine_lash (5) -> nature_wrath (60)
		ClassData._sk(s, "vine_lash", "Vine Lash", "เถาวัลย์ฟาด 3 เส้นพร้อมกัน", 5, 12, 7.0, "fan", 2.0, {"hits": 3, "color": Color("6fe07a"), "icon": "triple"}),
		ClassData._sk(s, "nature_wrath", "Nature's Wrath", "พลังธรรมชาติกระโดดฟาดศัตรู 6 ตัว", 60, 58, 12.0, "chain", 5.6, {"hits": 6, "vfx": &"leaf", "color": Color("7ddc6a"), "icon": "bolt"}),
		# area + slow: entangle (10) -> world_tree (80)
		ClassData._sk(s, "entangle", "Entangle", "รากไม้พันศัตรูในพื้นที่ ช้าลง 4 วินาที", 10, 16, 10.0, "blast", 3.4, {"radius": 4.8, "fx": {"slow": 4.0}, "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		ClassData._sk(s, "world_tree", "World Tree", "ต้นไม้โลกถล่มพื้นที่กว้าง ศัตรูช้าลง 4 วินาที", 80, 100, 16.0, "blast", 15.0, {"radius": 8.5, "fx": {"slow": 4.0}, "special": "rain", "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		# area around + slow: spore_burst (15) -> earth_shatter (64) -> cataclysm (96)
		ClassData._sk(s, "spore_burst", "Spore Burst", "ปล่อยสปอร์ระเบิดรอบตัว ศัตรูช้าลง 3 วินาที", 15, 18, 10.0, "burst", 4.8, {"radius": 5.0, "fx": {"slow": 3.0}, "vfx": &"leaf", "color": Color("b8f07a"), "icon": "nova"}),
		ClassData._sk(s, "earth_shatter", "Earth Shatter", "ทุบพื้นสะเทือนรอบตัว ศัตรูมึนงง 1.2 วินาทีและช้าลง 3 วินาที", 64, 66, 12.0, "burst", 9.0, {"radius": 6.0, "fx": {"stun": 1.2, "slow": 3.0}, "vfx": &"impact", "color": Color("e8c79f"), "icon": "nova"}),
		ClassData._sk(s, "cataclysm", "Cataclysm", "ธรรมชาติพิโรธ ถล่มรอบตัวอย่างรุนแรง ศัตรูมึนงง 1.2 วินาทีและช้าลง 3 วินาที", 96, 118, 16.0, "burst", 22.0, {"radius": 9.0, "fx": {"stun": 1.2, "slow": 3.0}, "vfx": &"leaf", "color": Color("b8ff7a"), "icon": "spin"}),
		# rain of thorns: thorn_storm (20)
		ClassData._sk(s, "thorn_storm", "Thorn Storm", "พายุหนามถล่มพื้นที่เป้าหมาย", 20, 24, 12.0, "blast", 7.0, {"radius": 6.0, "special": "rain", "vfx": &"leaf", "color": Color("8fe07a"), "icon": "rain"}),
		# team buff (ATK/DEF): forest_blessing (30) -> spirit_link (72) -> gaia_blessing (88)
		ClassData._sk(s, "forest_blessing", "Forest Blessing", "พลังป่าคุ้มครอง DEF +25% ATK +12% นาน 1 นาที (ส่งถึงทีมและอสูร)", 30, 26, 30.0, "self", 0.0, {"fx": {"buff": {"def": 0.25, "atk": 0.12, "secs": 60.0}}, "color": Color("7ddc6a"), "icon": "bless"}),
		ClassData._sk(s, "spirit_link", "Spirit Link", "เชื่อมวิญญาณ ATK +50% วิ่งเร็ว +20% DEF +30% นาน 1 นาที (ส่งถึงทีมและอสูร)", 72, 76, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "speed": 0.2, "def": 0.3, "secs": 60.0}}, "color": Color("a8ffd0"), "icon": "bless"}),
		ClassData._sk(s, "gaia_blessing", "Gaia's Blessing", "ฟื้นฟู HP 40% DEF +60% ATK +40% นาน 1 นาที (ส่งถึงทีมและอสูร)", 88, 96, 45.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 0.6, "atk": 0.4, "secs": 60.0}}, "vfx": &"heal", "color": Color("d8ffb0"), "icon": "bless"}),
		# heal (at Lv.84 the healing fairy heals on her own): regrowth (40) -> life_bloom (60) -> fairy_spirit (84)
		ClassData._sk(s, "regrowth", "Regrowth", "ฟื้นฟู HP 35% และ DEF +15% นาน 1 นาที", 40, 36, 20.0, "self", 0.0, {"fx": {"heal": 0.35, "buff": {"def": 0.15, "secs": 60.0}}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
		ClassData._sk(s, "life_bloom", "Life Bloom", "ฟื้นฟู HP 40% DEF +30% นาน 1 นาที", 60, 56, 28.0, "self", 0.0, {"fx": {"heal": 0.4, "buff": {"def": 0.3, "secs": 60.0}}, "vfx": &"heal", "color": Color("6dff9a"), "icon": "heal"}),
		_sm("fairy_spirit", "Fairy Spirit", "อัญเชิญภูตินางฟ้าบินตามติดผู้อัญเชิญ ฟื้นฟู HP 20% ให้ผู้อัญเชิญทุก 10 วินาที และ 10% ให้เพื่อนร่วมทีมที่อยู่ใกล้เธอ", 84, 100, 40.0, 4.0, "fairy", 1, 10.0, Color("ffb6e6"), {"spec": {"heal": 0.2, "ally_heal": 0.1}}),
		# ultimate: the beast summon: wolf_pack (50) -> alpha_wolves (70) -> primal_legion (90) -> elder_dragon (100)
		_sm("wolf_pack", "Wolf Pack", "เรียกหมาป่าแห่งป่า 2 ตัว", 50, 50, 30.0, 2.8, "wolf", 2, 0.9, Color("bfe0ff")),
		_sm("alpha_wolves", "Alpha Wolves", "เรียกหมาป่าจ่าฝูง 3 ตัว", 70, 74, 36.0, 5.0, "wolf", 3, 0.8, Color("9ad0ff")),
		_sm("primal_legion", "Primal Legion", "เรียกอสูรป่าดึกดำบรรพ์ 3 ตัว", 90, 110, 45.0, 10.0, "beast", 3, 1.0, Color("7aff8a")),
		_sm("elder_dragon", "Elder Dragon", "เรียกมังกรโบราณผู้เป็นตำนาน", 100, 150, 50.0, 28.0, "elder_dragon", 1, 1.2, Color("ffd84a")),
	]
