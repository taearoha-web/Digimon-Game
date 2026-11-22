extends RefCounted
## Muay Thai fighter (นักมวยประเจียด): its 8 skill lines (see "Skill lines" in
## data/class_data.gd). A bruiser of the front line who fights with wrapped fists,
## knees, elbows and kicks; the class mechanics (combo, hit-heal, the orbiting mantra
## rings) live in combat/muay_thai.gd and read the fx keys below:
##   combo        extra combo stacks the hit adds (on top of the one every hit gives)
##   combo_power  the hit grows by this share per combo stack (the ultimates), and
##                spends the combo
##   kick         metres the hit throws the target back (a guild war leader on the
##                altar is pushed off the yellow circle, MuayThai.kick)
##   buff.hit_heal  extra share of damage dealt healed back while the buff runs
## Every stage keeps its line's identity (stun, kick, ring throw, burn).

## [single-target, area] damage factors (ClassData.skill_tune) of the stages available
## at Lv.1-35 / Lv.36-75 / Lv.76-100 (and the star skills). Measured with
## tests/tools/class_dps_probe.tscn at Lv.26 (snow), Lv.70 (storm) and Lv.100 ★200
## (lotus_sanctum): a bruiser a little below the warrior and the assassin.
const TUNE := [[1.0, 1.15], [1.05, 0.82], [1.75, 0.9]]

## The 8 lines in bar order, each its stage ids, first stage first.
const LINES := [
	["jab_cross", "flame_hook", "sun_fist"],  # single, builds combo
	["back_elbow", "flying_knee", "thunder_elbow"],  # elbow / knee + stun
	["ring_throw", "twin_rings", "mantra_storm"],  # the rings fly out and back
	["push_kick", "body_throw", "earth_kick"],  # moves enemies (kick, throw)
	["sweep_kick", "flame_ring_spin", "fire_dragon_circle"],  # spin around self
	["wai_khru", "ram_muay", "sacred_mongkhon"],  # ritual buff (ATK + hit-heal)
	["ring_guard", "iron_prajiad"],  # ring guard (damage cut, reflect)
	["thousand_ring_fist", "muay_king"],  # ultimate, grows with the combo
]

const OLD_IDS := {}

## The 3 passives: always on once the level is reached, +bonus per star (atk, def,
## hp, mp fractions; crit, speed, dodge added; hit_heal a share of damage dealt
## healed back, combo seconds added to the combo window, MuayThai).
const PASSIVES := [
	{"id": "iron_fist", "name": "กำปั้นเหล็ก", "desc": "พลังโจมตี +5% ต่อดาว", "level": 1, "bonus": {"atk": 0.05}},
	{"id": "fighter_heart", "name": "ใจนักสู้", "desc": "HP สูงสุด +5% และตีแล้วฟื้นเลือดเพิ่ม 0.5% ของดาเมจต่อดาว", "level": 20, "bonus": {"hp": 0.05, "hit_heal": 0.005}},
	{"id": "muay_rhythm", "name": "จังหวะมวย", "desc": "คอมโบค้างนานขึ้น 0.2 วินาที และวิ่งเร็ว +2% ต่อดาว", "level": 60, "bonus": {"combo": 0.2, "speed": 0.02}},
]


## Every stage: ClassData._sk(class, id, name, desc, LEVEL, mp, cd, shape, mult, extra).
static func skills() -> Array:
	var c := &"muaythai"
	var ember := Color("ff8a2a")  # the class's orange-gold fire
	var gold := Color("ffc24a")
	var sun := Color("ffe27a")
	var blaze := Color("ff5a1f")
	var punch := {"anim": "Unarmed_Melee_Attack_Punch_A", "vfx": &"impact"}
	return [
		# 1 single, builds combo: หมัดตรง -> หมัดเหวี่ยงเพลิง (60) -> หมัดสุริยัน (90)
		ClassData._sk(c, "jab_cross", "หมัดตรง", "หมัดหนึ่ง-สองใส่ศัตรูตัวเดียว เพิ่มคอมโบ +2", 1, 10, 3.0, "single", 3.0, _x(punch, {"fx": {"combo": 2}, "color": gold, "icon": "fist"})),
		ClassData._sk(c, "flame_hook", "หมัดเหวี่ยงเพลิง", "หมัดเหวี่ยงลุกเป็นไฟใส่ศัตรูตัวเดียว ติดไฟ 4 วินาที เพิ่มคอมโบ +3", 60, 40, 6.0, "single", 4.6, _x(punch, {"fx": {"combo": 3, "burn": [0.3, 4.0]}, "vfx": &"fire", "color": ember, "icon": "fist"})),
		ClassData._sk(c, "sun_fist", "หมัดสุริยัน", "หมัดลุกโชนดั่งดวงอาทิตย์ใส่ศัตรูตัวเดียว ติดไฟ 5 วินาที เพิ่มคอมโบ +4", 90, 60, 8.0, "single", 13.0, _x(punch, {"range": 3.2, "fx": {"combo": 4, "burn": [0.4, 5.0]}, "vfx": &"fire", "color": sun, "icon": "fist"})),
		# 2 elbow / knee + stun: ศอกกลับ -> เข่าลอย (60) -> ศอกฟ้าผ่า (90)
		ClassData._sk(c, "back_elbow", "ศอกกลับ", "หมุนตัวฟาดศอกกลับใส่ศัตรูตัวเดียว มึนงง 1.5 วินาที", 5, 12, 6.0, "single", 3.4, {"fx": {"stun": 1.5}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": gold, "icon": "elbow"}),
		ClassData._sk(c, "flying_knee", "เข่าลอย", "กระโดดเข่าลอยใส่ศัตรูตัวเดียว มึนงง 1.5 วินาที", 60, 40, 9.0, "single", 8.2, {"range": 3.2, "fx": {"stun": 1.5}, "anim": "Jump_Full_Short", "vfx": &"impact", "color": ember, "icon": "elbow"}),
		ClassData._sk(c, "thunder_elbow", "ศอกฟ้าผ่า", "กระโดดสับศอกลงดั่งฟ้าผ่าใส่ศัตรูตัวเดียว มึนงง 1.5 วินาที", 90, 92, 10.0, "single", 18.0, {"range": 3.6, "fx": {"stun": 1.5}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"thunder", "color": sun, "icon": "elbow"}),
		# 3 ring throw: ขว้างประเจียด -> วงประเจียดคู่ (60) -> พายุวงมนตรา (90)
		ClassData._sk(c, "ring_throw", "ขว้างประเจียด", "ขว้างวงประเจียดเรืองแสงพุ่งไปกระทบศัตรู 3 ตัวต่อเนื่องแล้วบินกลับมาที่แขน", 10, 16, 9.0, "chain", 2.8, {"hits": 3, "range": 10.0, "rings": true, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"fire", "color": gold, "icon": "ring"}),
		ClassData._sk(c, "twin_rings", "วงประเจียดคู่", "ขว้างวงประเจียดสองวงกระทบศัตรู 5 ตัวต่อเนื่องแล้วบินกลับ ติดไฟ 3 วินาที", 60, 60, 12.0, "chain", 6.0, {"hits": 5, "range": 11.0, "rings": true, "fx": {"burn": [0.25, 3.0]}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"fire", "color": ember, "icon": "ring"}),
		ClassData._sk(c, "mantra_storm", "พายุวงมนตรา", "วงประเจียดทุกวงพุ่งออกไปรอบทิศ กระทบศัตรูได้ 6 ตัวแล้วบินกลับ ติดไฟ 4 วินาที", 90, 100, 14.0, "fan", 6.5, {"hits": 6, "range": 12.0, "rings": true, "fx": {"burn": [0.3, 4.0]}, "anim": "2H_Melee_Attack_Spin", "vfx": &"fire", "color": sun, "icon": "ring"}),
		# 4 moves enemies: ถีบ -> จับทุ่ม (70) -> ถีบพสุธา (90)
		ClassData._sk(c, "push_kick", "ถีบ", "ถีบศัตรูตัวเดียวกระเด็นถอยหลัง 4 เมตร มึนงง 0.6 วินาที (ถีบหัวหน้ากิลด์ตกแท่นได้)", 15, 18, 10.0, "single", 2.6, {"fx": {"kick": 4.0, "stun": 0.6}, "anim": "Block_Attack", "vfx": &"impact", "color": gold, "icon": "kick"}),
		ClassData._sk(c, "body_throw", "จับทุ่ม", "จับศัตรูทุ่มลงพื้นกระเด็นออกไป 3 เมตร มึนงง 2 วินาที (ทุ่มหัวหน้ากิลด์ตกแท่นได้)", 70, 70, 12.0, "single", 10.0, {"fx": {"kick": 3.0, "stun": 2.0}, "anim": "Dualwield_Melee_Attack_Chop", "vfx": &"impact", "color": ember, "icon": "kick"}),
		ClassData._sk(c, "earth_kick", "ถีบพสุธา", "ถีบพื้นสะเทือน ศัตรูรอบตัวกระเด็นออกไป 5 เมตร มึนงง 0.8 วินาที", 90, 90, 14.0, "burst", 9.0, {"radius": 5.5, "fx": {"kick": 5.0, "stun": 0.8}, "anim": "Block_Attack", "vfx": &"impact", "color": blaze, "icon": "kick"}),
		# 5 spin around self: เตะกวาด -> วงหมุนเพลิง (60) -> วงล้อมมังกรไฟ (80)
		ClassData._sk(c, "sweep_kick", "เตะกวาด", "หมุนตัวเตะกวาดศัตรูรอบตัว", 20, 22, 9.0, "burst", 3.0, {"radius": 4.5, "special": "spin", "anim": "2H_Melee_Attack_Spin", "vfx": &"impact", "color": gold, "icon": "spin"}),
		ClassData._sk(c, "flame_ring_spin", "วงหมุนเพลิง", "วงประเจียดหมุนลุกเป็นไฟรอบตัว เผาศัตรูรอบตัว ติดไฟ 4 วินาที", 60, 60, 12.0, "burst", 7.5, {"radius": 6.0, "special": "spin", "rings": true, "fx": {"burn": [0.35, 4.0]}, "anim": "2H_Melee_Attack_Spin", "vfx": &"fire", "color": ember, "icon": "spin"}),
		ClassData._sk(c, "fire_dragon_circle", "วงล้อมมังกรไฟ", "มังกรไฟวนล้อมรอบตัว เผาศัตรูรอบตัว ติดไฟ 5 วินาที มึนงง 1 วินาที", 80, 85, 13.0, "burst", 10.0, {"radius": 7.0, "special": "spin", "rings": true, "fx": {"burn": [0.4, 5.0], "stun": 1.0}, "anim": "2H_Melee_Attack_Spin", "vfx": &"fire", "color": blaze, "icon": "spin"}),
		# 6 ritual buff: ไหว้ครู -> รำมวยบูชาครู (60) -> มงคลศักดิ์สิทธิ์ (96)
		ClassData._sk(c, "wai_khru", "ไหว้ครู", "ไหว้ครูก่อนชก ATK +30% และตีแล้วฟื้นเลือดเพิ่ม 3% ของดาเมจ นาน 1 นาที (เฉพาะตัว)", 30, 24, 30.0, "self", 0.0, {"fx": {"buff": {"atk": 0.3, "hit_heal": 0.03, "secs": 60.0, "self_only": true}}, "anim": "Cheer", "color": gold, "icon": "bless"}),
		ClassData._sk(c, "ram_muay", "รำมวยบูชาครู", "รำมวยบูชาครู ATK +55% วิ่งเร็ว +10% ตีแล้วฟื้นเลือดเพิ่ม 5% ของดาเมจ นาน 1 นาที (เฉพาะตัว)", 60, 44, 36.0, "self", 0.0, {"fx": {"buff": {"atk": 0.55, "speed": 0.1, "hit_heal": 0.05, "secs": 60.0, "self_only": true}}, "anim": "Cheer", "color": ember, "icon": "bless"}),
		ClassData._sk(c, "sacred_mongkhon", "มงคลศักดิ์สิทธิ์", "สวมมงคลศักดิ์สิทธิ์ ATK +80% คริ +15% วิ่งเร็ว +15% ตีแล้วฟื้นเลือดเพิ่ม 6% ของดาเมจ นาน 1 นาที (เฉพาะตัว)", 96, 110, 50.0, "self", 0.0, {"fx": {"buff": {"atk": 0.8, "crit": 0.15, "speed": 0.15, "hit_heal": 0.06, "secs": 60.0}}, "anim": "Cheer", "color": sun, "icon": "bless"}),
		# 7 ring guard: วงคุ้มกาย -> ประเจียดเหล็ก (70)
		ClassData._sk(c, "ring_guard", "วงคุ้มกาย", "วงประเจียดรวมเป็นโล่รอบตัว ลดความเสียหายที่ได้รับ 15% DEF +20% นาน 1 นาที (เฉพาะตัว)", 40, 36, 34.0, "self", 0.0, {"fx": {"buff": {"guard": 0.15, "def": 0.2, "secs": 60.0, "self_only": true}}, "anim": "Blocking", "color": gold, "icon": "shield"}),
		ClassData._sk(c, "iron_prajiad", "ประเจียดเหล็ก", "ประเจียดแกร่งดั่งเหล็ก ลดความเสียหาย 20% DEF +40% สะท้อนความเสียหาย 20% กลับใส่ผู้โจมตี ฟื้น HP 20% นาน 1 นาที (เฉพาะตัว)", 70, 70, 40.0, "self", 0.0, {"fx": {"heal": 0.2, "buff": {"guard": 0.2, "def": 0.4, "reflect": 0.2, "secs": 60.0, "self_only": true}}, "anim": "Blocking", "color": ember, "icon": "shield"}),
		# 8 ultimate, grows with the combo: หมัดพันวง (50) -> ราชันมวยไทย (100)
		ClassData._sk(c, "thousand_ring_fist", "หมัดพันวง", "วงประเจียดทุกวงรวมเป็นหมัดเดียวใส่ศัตรูตัวเดียว ยิ่งคอมโบสูงยิ่งแรง (+3% ต่อคอมโบ ใช้คอมโบหมด)", 50, 50, 12.0, "single", 9.0, _x(punch, {"range": 3.2, "rings": true, "fx": {"combo_power": 0.03}, "vfx": &"fire", "color": ember, "icon": "fist"})),
		ClassData._sk(c, "muay_king", "ราชันมวยไทย", "วงประเจียดทั้งหมดถล่มลงที่เป้าหมาย ศัตรูรอบๆ กระเด็นออก 4 เมตร มึนงง 1 วินาที ยิ่งคอมโบสูงยิ่งแรง (+3% ต่อคอมโบ ใช้คอมโบหมด)", 100, 130, 14.0, "blast", 18.0, {"range": 7.0, "radius": 5.5, "rings": true, "fx": {"combo_power": 0.03, "kick": 4.0, "stun": 1.0}, "anim": "Jump_Full_Short", "hit_delay": 0.5, "vfx": &"fire", "color": sun, "icon": "meteor"}),
	]


static func _x(base: Dictionary, more: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(more, true)
	return out
