extends RefCounted
## Mage (นักเวท): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.
## The mage keeps no summons (Spirit Elemental, Dancing Sword and Fire Elemental are
## refunded).

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[0.64, 0.22], [1.33, 0.36], [1.6, 0.84]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["fire_bolt", "dead_ray", "judgment_ray"],  # single
	["agony", "slow_speed"],  # slow
	["fire_ball", "meteo", "hell_meteor"],  # fire blast
	["watornado", "ice_storm"],  # water / ice blast + slow
	["flame_wave", "spirit_burst"],  # burst around the caster
	["enchant_weapon", "silraphim", "magic_overdrive"],  # attack buff
	["energy_shield", "vague"],  # defence buff
	["thunder_storm", "armageddon"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (zenith, diastrophism, spirit_elemental, dancing_sword, distortion,
## fire_elemental) is refunded and dropped.
const OLD_IDS := {
	"mana_pool": "mental_mastery",
	"spell_mastery": "elemental_mastery",
	"arcane_barrier": "archmage_will",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "mental_mastery", "name": "Mental Mastery", "desc": "MP สูงสุด +10% ต่อดาว", "level": 1, "bonus": {"mp": 0.1}},
	{"id": "elemental_mastery", "name": "Elemental Mastery", "desc": "พลังโจมตี +4.5% ต่อดาว", "level": 20, "bonus": {"atk": 0.045}},
	{"id": "archmage_will", "name": "Archmage's Will", "desc": "HP สูงสุด +3% และคริติคอล +1.5% ต่อดาว", "level": 30, "bonus": {"hp": 0.03, "crit": 0.015}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var m := &"mage"
	return [
		# 1 single: Fire Bolt -> Dead Ray (60) -> Judgment Ray (90)
		ClassData._sk(m, "fire_bolt", "Fire Bolt", "ลูกไฟพุ่งใส่ศัตรู ติดไฟต่อเนื่อง", 1, 10, 4.0, "single", 3.4, {"fx": {"burn": [0.3, 4.0]}, "vfx": &"fireball", "color": Color("ff7a2a"), "icon": "fire"}),
		ClassData._sk(m, "dead_ray", "Dead Ray", "รังสีมรณะแรงสูงใส่ศัตรูตัวเดียว", 60, 48, 7.0, "single", 6.4, {"range": 12.0, "vfx": &"thunder", "color": Color("fff06a"), "icon": "bolt"}),
		ClassData._sk(m, "judgment_ray", "Judgment Ray", "เปิดตราพิพากษาบนฟ้า เรียกเสาแสงทองขาวลงใส่เป้าหมายเดียวอย่างรุนแรง 1 ครั้ง", 90, 120, 12.0, "single", 24.0, {"range": 14.0, "projectile": false, "hit_delay": 1.05, "vfx": &"light", "color": Color("fff0a0"), "icon": "bolt"}),
		# 2 slow: Agony -> Slow Speed (60)
		ClassData._sk(m, "agony", "Agony", "คำสาปทรมาน ทำร้ายศัตรูและทำให้ช้าลง 2 วินาที", 5, 12, 3.0, "single", 2.8, {"fx": {"slow": 2.0}, "color": Color("b79bff"), "icon": "light"}),
		ClassData._sk(m, "slow_speed", "Slow Speed", "เวทหน่วงเวลา ศัตรูช้าลงมาก 6 วินาที", 60, 66, 12.0, "blast", 8.0, {"radius": 7.0, "fx": {"slow": 6.0}, "vfx": &"frost", "color": Color("7fdcff"), "icon": "ice"}),
		# 3 fire blast: Fire Ball -> Meteo (60) -> Hell Meteor (90)
		ClassData._sk(m, "fire_ball", "Fire Ball", "ลูกไฟยักษ์ระเบิดเป็นวง", 10, 18, 8.0, "blast", 3.6, {"radius": 3.8, "special": "boom", "fx": {"burn": [0.25, 4.0]}, "vfx": &"fireball", "color": Color("ff6a2a"), "icon": "fire"}),
		ClassData._sk(m, "meteo", "Meteo", "อุกกาบาตตกใส่พื้นที่ ติดไฟ", 60, 80, 16.0, "blast", 11.0, {"radius": 8.0, "special": "meteor", "fx": {"burn": [0.4, 5.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "meteor"}),
		ClassData._sk(m, "hell_meteor", "Hell Meteor", "อุกกาบาตนรกถล่มพื้นที่กว้าง ติดไฟแรง", 90, 110, 18.0, "blast", 16.0, {"radius": 9.0, "special": "meteor", "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff3a2a"), "icon": "meteor"}),
		# 4 water / ice: Watornado -> Ice Storm (70)
		ClassData._sk(m, "watornado", "Watornado", "พายุน้ำหมุนวนถล่มพื้นที่ ศัตรูช้าลง", 15, 22, 10.0, "blast", 3.6, {"radius": 5.2, "fx": {"slow": 3.5}, "vfx": &"frost", "color": Color("7fdcff"), "icon": "ice"}),
		ClassData._sk(m, "ice_storm", "Ice Storm", "พายุน้ำแข็งถล่มพื้นที่กว้าง ศัตรูช้าลง", 70, 96, 16.0, "blast", 15.0, {"radius": 9.0, "fx": {"slow": 5.0}, "vfx": &"frost", "color": Color("aaf0ff"), "icon": "ice"}),
		# 5 burst: Flame Wave -> Spirit Burst (80)
		ClassData._sk(m, "flame_wave", "Flame Wave", "คลื่นเพลิงถาโถมรอบตัว เผาศัตรูทุกตัว", 20, 26, 14.0, "burst", 6.0, {"radius": 7.0, "fx": {"burn": [0.5, 6.0]}, "vfx": &"fireball", "color": Color("ff5a2a"), "icon": "fire"}),
		ClassData._sk(m, "spirit_burst", "Spirit Burst", "วิญญาณระเบิดรอบตัวสร้างความเสียหายมหาศาล", 80, 110, 16.0, "burst", 14.0, {"radius": 9.0, "vfx": &"light", "color": Color("b698f2"), "icon": "nova"}),
		# 6 attack buff: Enchant Weapon -> Silraphim (60) -> Magic Overdrive (90)
		ClassData._sk(m, "enchant_weapon", "Enchant Weapon", "ใส่เวทธาตุให้อาวุธ ATK +35% นาน 1 นาที", 30, 26, 30.0, "self", 0.0, {"fx": {"buff": {"atk": 0.35, "secs": 60.0}}, "color": Color("ff9a5a"), "icon": "bless"}),
		ClassData._sk(m, "silraphim", "Silraphim", "ATK +50% DEF +30% นาน 1 นาที", 60, 66, 40.0, "self", 0.0, {"fx": {"buff": {"atk": 0.5, "def": 0.3, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		ClassData._sk(m, "magic_overdrive", "Magic Overdrive", "ATK +90% คริ +15% นาน 1 นาที", 90, 120, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.9, "crit": 0.15, "secs": 60.0}}, "color": Color("ffd0ff"), "icon": "bless"}),
		# 7 defence buff: Energy Shield -> Vague (70)
		ClassData._sk(m, "energy_shield", "Energy Shield", "โล่พลังงาน DEF +60% นาน 1 นาที", 40, 36, 32.0, "self", 0.0, {"fx": {"buff": {"def": 0.6, "secs": 60.0}}, "color": Color("7fdcff"), "icon": "shield"}),
		ClassData._sk(m, "vague", "Vague", "ร่างพร่าเลือน DEF +70% วิ่งเร็ว +20% นาน 1 นาที", 70, 78, 40.0, "self", 0.0, {"fx": {"buff": {"def": 0.7, "speed": 0.2, "secs": 60.0}}, "color": Color("b79bff"), "icon": "shield"}),
		# 8 ultimate: Thunder Storm (50) -> Armageddon (100)
		ClassData._sk(m, "thunder_storm", "Thunder Storm", "เมฆพายุสุ่มผ่าศัตรูสูงสุด 5 ตัวต่อระลอก รวม 3 ระลอก ห่างกัน 0.75 วินาที รัศมีเท่า Ice Storm", 50, 64, 12.0, "blast", 6.2, {"radius": 9.0, "vfx": &"thunder", "color": Color("dceaff"), "icon": "bolt"}),
		ClassData._sk(m, "armageddon", "Armageddon", "อุกกาบาตยักษ์ถล่มพื้น แตกเป็นสะเก็ดไฟ 10 ลูก ระเบิดทีละลูกทุก 0.5 วินาที ทำความเสียหายและเผาไหม้ทุกฮิต", 100, 180, 24.0, "blast", 22.0, {"radius": 11.0, "special": "meteor", "fx": {"burn": [0.7, 8.0]}, "vfx": &"fireball", "color": Color("ff2a1a"), "icon": "meteor"}),
	]
