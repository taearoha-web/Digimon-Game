extends RefCounted
## Dark Lord (ดาร์กลอร์ด): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework.
const TUNE := [[1.03, 0.915], [1.6, 0.8], [1.5, 0.75]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["force", "chaos_strike", "chaos_sovereign"],  # single
	["fire_burst", "fire_scream", "dark_comet"],  # fire on a pack
	["earthshake", "earth_dominion"],  # area + stun
	["electric_spike", "thunder_lord"],  # chain lightning
	["birds", "raven_storm"],  # the raven: marks the target for the party
	["commanders_aura", "lord_of_command", "emperors_command"],  # the Lord's own attack buff (self only)
	["summon"],  # party warp
	["infernal_scream", "imperial_judgment"],  # ultimate (Imperial Judgment pulls in)
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (critical_damage, force_wave, iron_defense, fire_blast, plasma_storm,
## chaotic_diseier, royal_crush) is refunded and dropped.
const OLD_IDS := {
	"dark_dominion": "scepter_mastery",
	"emperor_will": "royal_vigor",
	"raven_bond": "command_presence",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "scepter_mastery", "name": "Scepter Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "royal_vigor", "name": "Royal Vigor", "desc": "HP สูงสุด +8% และพลังป้องกัน +3% ต่อดาว", "level": 20, "bonus": {"hp": 0.08, "def": 0.03}},
	{"id": "command_presence", "name": "Command Presence", "desc": "พลังป้องกัน +3% MP +3% และคริติคอล +1.5% ต่อดาว", "level": 40, "bonus": {"def": 0.03, "mp": 0.03, "crit": 0.015}},
]

## The raven's mark (Birds, Raven Storm): the party deals this much more to the marked
## target for this many seconds (ClassRoles.raven_mark).
const RAVEN_MARK := [0.15, 5.0]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var k := &"darklord"
	var royal := Color("e8b64a")
	var dark := Color("8a4dff")
	var fire := Color("ff6a2a")
	var bolt := Color("8fd8ff")
	var force := {"range": 9.0, "projectile": true, "anim": "Spellcast_Shoot", "hit_delay": 0.28}
	return [
		# 1 single: Force -> Chaos Strike (60) -> Chaos Sovereign (90)
		ClassData._sk(k, "force", "Force", "ปล่อยพลังมืดจากคทาพุ่งใส่ศัตรูตัวเดียว", 1, 8, 2.6, "single", 2.8, force.merged({"vfx": &"impact", "color": dark, "icon": "light"})),
		ClassData._sk(k, "chaos_strike", "Chaos Strike", "ฟาดคทาแห่งความโกลาหลใส่ศัตรูตัวเดียว แรงมาก", 60, 40, 7.0, "single", 9.0, {"range": 3.0, "vfx": &"impact", "color": dark, "icon": "sword"}),
		ClassData._sk(k, "chaos_sovereign", "Chaos Sovereign", "ราชันแห่งความโกลาหล ฟาดพลังมืดฉีกศัตรูตัวเดียว", 90, 92, 10.0, "single", 17.0, {"range": 3.6, "vfx": &"impact", "color": dark, "icon": "sword"}),
		# 2 fire on a pack: Fire Burst -> Fire Scream (40) -> Dark Comet (80)
		ClassData._sk(k, "fire_burst", "Fire Burst", "คทาจุดระเบิดเพลิงรอบศัตรูเป้าหมาย", 5, 12, 6.0, "blast", 2.6, {"radius": 3.6, "range": 9.0, "anim": "Spellcast_Shoot", "hit_delay": 0.4, "vfx": &"fireball", "color": fire, "icon": "fire"}),
		ClassData._sk(k, "fire_scream", "Fire Scream", "คำรามเพลิง ระเบิดไฟใส่ฝูงศัตรู ติดไฟต่อเนื่อง", 40, 36, 10.0, "blast", 3.8, {"radius": 4.6, "range": 10.0, "fx": {"burn": [0.35, 4.0]}, "anim": "Spellcast_Shoot", "hit_delay": 0.45, "vfx": &"fireball", "color": fire, "icon": "fire"}),
		ClassData._sk(k, "dark_comet", "Dark Comet", "อัญเชิญดาวหางมืดเพลิงตกใส่ฝูงศัตรู ติดไฟต่อเนื่อง", 80, 76, 13.0, "blast", 5, {"radius": 6.0, "range": 11.0, "special": "meteor", "fx": {"burn": [0.45, 5.0]}, "anim": "Spellcast_Long", "hit_delay": 0.6, "vfx": &"impact", "color": dark, "icon": "meteor"}),
		# 3 area + stun: Earthshake -> Earth Dominion (90)
		ClassData._sk(k, "earthshake", "Earthshake", "กระทืบคทาลงพื้น แผ่นดินสั่นรอบตัว ศัตรูมึนงง 1.2 วินาที", 10, 14, 9.0, "burst", 2.4, {"radius": 4.8, "fx": {"stun": 1.2}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": royal, "icon": "nova"}),
		ClassData._sk(k, "earth_dominion", "Earth Dominion", "ปกครองพสุธา แผ่นดินแยกถล่มรอบตัว ศัตรูมึนงง 1.5 วินาที", 90, 100, 14.0, "burst", 6, {"radius": 8.0, "fx": {"stun": 1.5}, "anim": "2H_Melee_Attack_Slice", "vfx": &"impact", "color": royal, "icon": "nova"}),
		# 4 chain lightning: Electric Spike -> Thunder Lord (70)
		ClassData._sk(k, "electric_spike", "Electric Spike", "หอกสายฟ้าฟาดลงแล้วกระโดดไปศัตรู 5 ตัว", 15, 16, 9.0, "chain", 3.0, {"hits": 5, "range": 10.0, "vfx": &"thunder", "color": bolt, "icon": "bolt"}),
		ClassData._sk(k, "thunder_lord", "Thunder Lord", "จ้าวสายฟ้า ฟาดสายฟ้ากระโดดใส่ศัตรู 7 ตัว", 70, 66, 11.0, "chain", 5, {"hits": 7, "range": 11.0, "vfx": &"thunder", "color": bolt, "icon": "bolt"}),
		# 5 the raven: Birds -> Raven Storm (88). The ravens dive the target and mark it:
		# the party deals +15% to it for 5 s; on a lone target every raven lands on it.
		ClassData._sk(k, "birds", "Birds", "ปล่อยฝูงอีกาเงา 5 ตัวโฉบใส่ศัตรู (ถ้ามีตัวเดียว โฉบใส่ตัวนั้นทั้งฝูง) ประทับตราอีกา ทั้งปาร์ตี้ทำดาเมจใส่เป้าหมาย +15% นาน 5 วินาที", 20, 20, 9.0, "fan", 2.4, {"hits": 5, "range": 11.0, "converge": true, "fx": {"raven_mark": RAVEN_MARK}, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		ClassData._sk(k, "raven_storm", "Raven Storm", "พายุอีกาเงา 8 ตัวโฉบใส่ศัตรูรอบทิศ (ถ้ามีตัวเดียว โฉบใส่ตัวนั้นทั้งฝูง) ประทับตราอีกา ทั้งปาร์ตี้ทำดาเมจใส่เป้าหมาย +15% นาน 5 วินาที", 88, 96, 13.0, "fan", 4, {"hits": 8, "range": 12.0, "converge": true, "fx": {"raven_mark": RAVEN_MARK}, "anim": "Spellcast_Shoot", "vfx": &"impact", "color": dark, "icon": "triple"}),
		# 6 self attack buff (BuffBook.reaches_party: not shared): Commander's Aura -> Lord of Command (76) -> Emperor's Command (96)
		ClassData._sk(k, "commanders_aura", "Commander's Aura", "รัศมีผู้บัญชาการ ATK +35% DEF +20% นาน 1 นาที (เฉพาะตัว)", 30, 26, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.35, "def": 0.2, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		ClassData._sk(k, "lord_of_command", "Lord of Command", "จ้าวบัญชาการ ATK +35% คริ +15% DEF +25% ฟื้น HP 20% นาน 1 นาที (บัฟเฉพาะตัว)", 76, 76, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"atk": 0.35, "crit": 0.15, "def": 0.25, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		ClassData._sk(k, "emperors_command", "Emperor's Command", "ราชโองการจักรพรรดิ ATK +55% คริ +20% วิ่งเร็ว +15% นาน 1 นาที (เฉพาะตัว)", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.2, "speed": 0.15, "secs": 60.0}}, "anim": "Cheer", "color": royal, "icon": "bless"}),
		# 7 party warp: Summon
		ClassData._sk(k, "summon", "Summon", "วาร์ปเพื่อนทั้งปาร์ตี้มาอยู่ข้างตัวทันที ฟื้น HP ทีม 10%", 40, 30, 20.0, "self", 0.0, {"fx": {"recall": true, "heal": 0.1}, "anim": "Spellcast_Raise", "vfx": &"aura", "color": dark, "icon": "bless"}),
		# 8 ultimate: Infernal Scream (50) -> Imperial Judgment (100), which pulls the
		# monsters round the Lord in to it.
		ClassData._sk(k, "infernal_scream", "Infernal Scream", "เสียงคำรามนรก เพลิงพายุถล่มรอบตัว ติดไฟแรง", 50, 50, 13.0, "burst", 6.6, {"radius": 7.0, "fx": {"burn": [0.5, 5.0]}, "anim": "Spellcast_Raise", "vfx": &"fireball", "color": fire, "icon": "nova"}),
		ClassData._sk(k, "imperial_judgment", "Imperial Judgment", "คำพิพากษาจักรพรรดิ พลังมืด ไฟ และสายฟ้าระเบิดรอบตัว ดูดศัตรูรอบตัวเข้ามารวมกันตรงหน้า มึนงง 1.5 วินาที", 100, 130, 16.0, "burst", 10.5, {"radius": 9.0, "fx": {"stun": 1.5, "pull": true}, "anim": "Spellcast_Raise", "vfx": &"thunder", "color": royal, "icon": "nova"}),
	]
