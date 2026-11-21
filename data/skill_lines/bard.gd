extends RefCounted
## Bard (นักดนตรี): its 8 skill lines (see "Skill lines" in data/class_data.gd).
## A line is one bar skill that evolves with level. Every stage is a whole skill (its
## own id, name, desc, shape, effects and art); its level is when it becomes
## available: the unlock level for a line's first stage, the evolution level after.
## The two songs (attack: Valor March, ward: Iron Ballad) are their lines' first stages,
## so a song's slot and the AI's song rules keep working by line id. The old self-only
## stances (Virtuoso, Maestro's Fervor) are gone; their points are refunded.

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum) so the class's DPS stayed where it was before the rework (a support
## class: about half the median, the owner's call).
const TUNE := [[0.914, 0.632], [0.49, 0.82], [0.49, 0.413]]

## The 8 lines in bar order, each its stage ids, first stage first. A line's id is
## its first stage's id: the bar slot and the skill's star rank are kept under it.
const LINES := [
	["staccato_shot", "heartstring", "aria_of_ruin"],  # single
	["valor_march", "heroic_anthem", "hymn_of_legends"],  # attack song
	["discord", "shattering_rhapsody", "grand_dissonance"],  # area + armour crack
	["sorrow_note", "lament"],  # weaken
	["echo_chain", "eternal_echo"],  # chain
	["iron_ballad", "sanctuary_serenade"],  # ward song
	["slumber_lullaby", "thunder_crescendo"],  # area + stun
	["grand_finale"],  # ultimate
]

## Old ids (from before the rework) that are no stage of a line but carry their star
## rank to another skill: the higher rank stays, the other's points come back. Every
## other old id (resonance, triad_chord, war_drum, virtuoso, cascade, fortissimo,
## maestro_fervor) is refunded and dropped.
const OLD_IDS := {
	"harmonic_power": "lute_mastery",
	"standing_ovation": "stage_presence",
	"breath_control": "perfect_pitch",
}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added).
const PASSIVES := [
	{"id": "lute_mastery", "name": "Lute Mastery", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "stage_presence", "name": "Stage Presence", "desc": "HP สูงสุด +8% และพลังป้องกัน +3% ต่อดาว", "level": 20, "bonus": {"hp": 0.08, "def": 0.03}},
	{"id": "perfect_pitch", "name": "Perfect Pitch", "desc": "คริติคอล +1.5% และ MP สูงสุด +5% ต่อดาว", "level": 40, "bonus": {"crit": 0.015, "mp": 0.05}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
## LEVEL is when the stage is available (unlock / evolution level); the damage curve
## and the TUNE band follow it. Must be in the same order as LINES within a line.
static func skills() -> Array:
	var b := &"bard"
	var rose := Color("ff6fb5")  # songs, the class accent
	var tone := Color("ffb3dc")  # notes
	var gilt := Color("f0c870")  # ward songs
	var disso := Color("b07aff")  # armour-cracking discords (shred)
	var sorrow := Color("8fb8ff")  # strength-sapping laments (weaken)
	var aqua := Color("9fe8ff")  # serenades, echoes
	var tempest := Color("c79bff")  # thunder
	var shine := Color("ffd36b")  # the great song
	var dream := Color("a8c8ff")  # the lullaby
	var note := {"projectile": true, "anim": "Spellcast_Shoot"}  # no vfx here: merged() never overwrites
	return [
		# 1 single: Staccato Shot -> Heartstring (60) -> Aria of Ruin (90)
		ClassData._sk(b, "staccato_shot", "Staccato Shot", "ดีดพิณยิงโน้ตแหลมพุ่งใส่ศัตรูตัวเดียวอย่างรวดเร็ว", 1, 8, 2.6, "single", 2.8, note.merged({"range": 10.0, "hit_delay": 0.28, "vfx": &"light", "color": tone, "icon": "light"})),
		ClassData._sk(b, "heartstring", "Heartstring", "ดีดสายใจ โน้ตทรงพลังพุ่งใส่ศัตรูตัวเดียว ช้าลง 3 วินาที", 60, 40, 7.0, "single", 6.0, note.merged({"range": 10.0, "hit_delay": 0.32, "fx": {"slow": 3.0}, "vfx": &"light", "color": rose, "icon": "light"})),
		ClassData._sk(b, "aria_of_ruin", "Aria of Ruin", "อาเรียแห่งหายนะ โน้ตเสียงสูงสุดขีดผ่าลงศัตรูตัวเดียวอย่างรุนแรง", 90, 92, 10.0, "single", 17.0, {"range": 11.0, "projectile": false, "hit_delay": 0.6, "anim": "Spellcast_Raise", "vfx": &"light", "color": rose, "icon": "light"}),
		# 2 attack song: Valor March -> Heroic Anthem (60) -> Hymn of Legends (96)
		ClassData._sk(b, "valor_march", "Valor March", "เพลง: มาร์ชกล้าหาญ ทั้งปาร์ตี้ ATK +15% วิ่งเร็ว +12% นาน 1 นาที", 5, 12, 25.0, "self", 0.0, {"fx": {"buff": {"atk": 0.15, "speed": 0.12, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": rose, "icon": "bless"}),
		ClassData._sk(b, "heroic_anthem", "Heroic Anthem", "เพลง: เพลงชาติวีรชน ทั้งปาร์ตี้ ATK +40% คริติคอล +10% นาน 1 นาที", 60, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.4, "crit": 0.1, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": rose, "icon": "bless"}),
		ClassData._sk(b, "hymn_of_legends", "Hymn of Legends", "เพลง: บทเพลงแห่งตำนาน ทั้งปาร์ตี้ ATK +55% คริติคอล +20% วิ่งเร็ว +15% นาน 1 นาที", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "crit": 0.2, "speed": 0.15, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"aura", "color": shine, "icon": "bless"}),
		# 3 area + armour crack: Discord -> Shattering Rhapsody (70) -> Grand Dissonance (90)
		ClassData._sk(b, "discord", "Discord", "ดีดเสียงไม่ประสาน คลื่นเสียงเพี้ยนระเบิดใส่ฝูงศัตรู เกราะแตก 15% นาน 8 วินาที", 10, 14, 9.0, "blast", 2.4, {"radius": 4.2, "range": 10.0, "hit_delay": 0.45, "anim": "Spellcast_Shoot", "fx": {"shred": [0.15, 8.0]}, "vfx": &"debuff", "color": disso, "icon": "nova"}),
		ClassData._sk(b, "shattering_rhapsody", "Shattering Rhapsody", "ราพโซดีสายฟ้าฟาดตามจังหวะถล่มฝูงศัตรู เกราะแตก 22% นาน 8 วินาที และช้าลง 3 วินาที", 70, 70, 13.0, "blast", 5.0, {"radius": 6.0, "range": 11.0, "hit_delay": 0.55, "anim": "Spellcast_Long", "fx": {"shred": [0.22, 8.0], "slow": 3.0}, "vfx": &"thunder", "color": tempest, "icon": "bolt"}),
		ClassData._sk(b, "grand_dissonance", "Grand Dissonance", "มหาเสียงไม่ประสานถล่มพื้นที่กว้าง ศัตรูเกราะแตก 25% และอ่อนแรง 20% นาน 8 วินาที", 90, 96, 15.0, "blast", 6.4, {"radius": 7.0, "range": 11.0, "hit_delay": 0.6, "anim": "Spellcast_Long", "fx": {"shred": [0.25, 8.0], "weaken": [0.2, 8.0]}, "vfx": &"debuff", "color": disso, "icon": "nova"}),
		# 4 weaken: Sorrow Note -> Lament (60)
		ClassData._sk(b, "sorrow_note", "Sorrow Note", "โน้ตเศร้าสร้อยพุ่งใส่ศัตรูตัวเดียว ศัตรูอ่อนแรง โจมตีเบาลง 15% นาน 6 วินาที", 15, 16, 8.0, "single", 1.9, note.merged({"range": 10.0, "hit_delay": 0.3, "fx": {"weaken": [0.15, 6.0]}, "vfx": &"debuff", "color": sorrow, "icon": "light"})),
		ClassData._sk(b, "lament", "Lament", "บทเพลงคร่ำครวญถล่มฝูงศัตรู ศัตรูช้าลง 3 วินาทีและอ่อนแรง โจมตีเบาลง 20% นาน 8 วินาที", 60, 54, 12.0, "blast", 4.4, {"radius": 5.2, "range": 11.0, "hit_delay": 0.5, "anim": "Spellcast_Long", "fx": {"slow": 3.0, "weaken": [0.2, 8.0]}, "vfx": &"debuff", "color": sorrow, "icon": "nova"}),
		# 5 chain: Echo Chain -> Eternal Echo (80)
		ClassData._sk(b, "echo_chain", "Echo Chain", "โน้ตก้องสะท้อนกระโดดไปหาศัตรูสูงสุด 5 ตัว", 20, 20, 9.0, "chain", 3.0, {"hits": 5, "range": 10.0, "hit_delay": 0.3, "anim": "Spellcast_Shoot", "vfx": &"light", "color": aqua, "icon": "bolt"}),
		ClassData._sk(b, "eternal_echo", "Eternal Echo", "เสียงก้องนิรันดร์ โน้ตสะท้อนกระโดดไปหาศัตรูสูงสุด 8 ตัว", 80, 90, 13.0, "chain", 4.8, {"hits": 8, "range": 12.0, "hit_delay": 0.3, "anim": "Spellcast_Shoot", "vfx": &"light", "color": aqua, "icon": "bolt"}),
		# 6 ward song: Iron Ballad -> Sanctuary Serenade (64)
		ClassData._sk(b, "iron_ballad", "Iron Ballad", "เพลง: บัลลาดเหล็กกล้า ฟื้นฟู HP 15% ทั้งปาร์ตี้ DEF +30% ลดความเสียหายที่ได้รับ 8% นาน 1 นาที", 30, 26, 30.0, "self", 0.0, {"fx": {"heal": 0.15, "buff": {"def": 0.3, "guard": 0.08, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"heal", "color": gilt, "icon": "shield"}),
		ClassData._sk(b, "sanctuary_serenade", "Sanctuary Serenade", "เพลง: เซเรเนดแห่งวิหาร ฟื้นฟู HP 25% ทั้งปาร์ตี้ DEF +40% ลดความเสียหายที่ได้รับ 12% โล่ดูดซับ 10% ของ HP นาน 1 นาที", 64, 70, 40.0, "self", 0.0, {"fx": {"heal": 0.25, "buff": {"def": 0.4, "guard": 0.12, "shield": 0.1, "song": true, "secs": 60.0}}, "anim": "Cheer", "vfx": &"heal", "color": aqua, "icon": "shield"}),
		# 7 area + stun: Slumber Lullaby -> Thunder Crescendo (92)
		ClassData._sk(b, "slumber_lullaby", "Slumber Lullaby", "เพลงกล่อมนิทราโปรยโน้ตลงพื้นที่ ศัตรูหลับมึนงง 1.8 วินาที", 40, 40, 14.0, "blast", 3.6, {"radius": 5.5, "range": 11.0, "hit_delay": 0.5, "anim": "Spellcast_Long", "fx": {"stun": 1.8}, "vfx": &"aura", "color": dream, "icon": "rain"}),
		ClassData._sk(b, "thunder_crescendo", "Thunder Crescendo", "เครสเชนโดสายฟ้า กลองฟ้าคำรามรอบตัว ศัตรูมึนงง 1.2 วินาทีและอ่อนแรง 24% นาน 8 วินาที", 92, 104, 14.0, "burst", 5.6, {"radius": 8.0, "hit_delay": 0.45, "anim": "1H_Melee_Attack_Chop", "fx": {"stun": 1.2, "weaken": [0.24, 8.0]}, "vfx": &"thunder", "color": tempest, "icon": "nova"}),
		# 8 ultimate: Grand Finale (50)
		ClassData._sk(b, "grand_finale", "Grand Finale", "มหาคอนเสิร์ตปิดม่าน เวทีแสงและเสียงระเบิดถล่มพื้นที่กว้างมาก ศัตรูมึนงง 1.5 วินาที เกราะแตก 20% และอ่อนแรง 20% นาน 8 วินาที", 50, 60, 18.0, "blast", 7.0, {"radius": 9.5, "range": 12.0, "hit_delay": 0.9, "anim": "Spellcast_Long", "fx": {"stun": 1.5, "shred": [0.2, 8.0], "weaken": [0.2, 8.0]}, "vfx": &"light", "color": rose, "icon": "nova"}),
	]
