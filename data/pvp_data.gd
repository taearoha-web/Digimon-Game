class_name PvpData
extends RefCounted
## The ranked ladder: rank points (RP), the 17 steps from Copper III to Legend,
## and the AI players the hero is matched against. The higher the rank, the
## stronger and sharper the AI opponent.

const STEP_RP := 100
const MAX_STEP := 16
const TIME_LIMIT := 150.0
## Ranked duels use the war's rules: Lv.100 with 200 stars on both sides.
const MIN_LEVEL := 100

## divs = how many divisions (III, II, I) the tier has.
const TIERS: Array[Dictionary] = [
	{"name": "ทองแดง", "color": Color("d08a52"), "divs": 3, "icon": "1"},
	{"name": "เงิน", "color": Color("cfd8e8"), "divs": 3, "icon": "2"},
	{"name": "ทอง", "color": Color("ffd24a"), "divs": 3, "icon": "3"},
	{"name": "แพลทินัม", "color": Color("6fe8d8"), "divs": 3, "icon": "4"},
	{"name": "เพชร", "color": Color("7fb8ff"), "divs": 3, "icon": "5"},
	{"name": "ปรมาจารย์", "color": Color("c58aff"), "divs": 1, "icon": "6"},
	{"name": "ตำนาน", "color": Color("ff6a5a"), "divs": 1, "icon": "7"},
]
const ROMAN := ["I", "II", "III"]

const NAMES := [
	"ซามูไรหมาป่า", "นักล่าเงา", "Kira", "Luna", "มังกรทอง", "เจ้าชายลมพัด", "Blaze", "ราชินีน้ำแข็ง", "Zephyr",
	"อัศวินดอกไม้", "Nova", "พ่อมดจอมขี้เล่น", "Rex", "สายฟ้าแดง", "Mochi", "ปีศาจน้อย", "Saber", "ดาบพิฆาต",
	"Aria", "ผู้พิทักษ์ป่า", "Vex", "ลมหนาวเหนือ", "Orion", "ศิษย์เอกสำนักเมฆ", "Yuki", "นายพรานจันทร์เสี้ยว",
	"Drako", "แม่มดน้อย", "Hikari", "จอมยุทธ์พเนจร", "Ember", "ไอ้หนูกล้า",
]


# --- Ranks -----------------------------------------------------------------------

static func step(rp: int) -> int:
	return clampi(rp / STEP_RP, 0, MAX_STEP)


## { tier: index into TIERS, div: 0 = lowest division (III) .. divs-1 = highest (I) }
static func place(step_index: int) -> Dictionary:
	var left := step_index
	for t in TIERS.size():
		var divs: int = TIERS[t].divs
		if left < divs:
			return {"tier": t, "div": left}
		left -= divs
	return {"tier": TIERS.size() - 1, "div": 0}


static func tier_of(rp: int) -> Dictionary:
	return TIERS[int(place(step(rp)).tier)]


static func rank_name(rp: int) -> String:
	var p := place(step(rp))
	var tier: Dictionary = TIERS[int(p.tier)]
	if int(tier.divs) == 1:
		return String(tier.name)
	return "%s %s" % [tier.name, ROMAN[int(tier.divs) - 1 - int(p.div)]]


static func step_name(step_index: int) -> String:
	return rank_name(step_index * STEP_RP)


## RP at the first step of the tier the player is in (the "league floor": a
## loss never drops you out of your league, only down its divisions).
static func tier_floor(rp: int) -> int:
	var tier := int(place(step(rp)).tier)
	var first := 0
	for t in tier:
		first += int(TIERS[t].divs)
	return first * STEP_RP


## 0..1 progress to the next step.
static func progress(rp: int) -> float:
	if step(rp) >= MAX_STEP:
		return 1.0
	return float(rp % STEP_RP) / float(STEP_RP)


## Every rank faces the same kind of opponent: a Lv.100, 200-star player, equally sharp.
## Ranks differ only in the gear it wears (see grade_of).
static func difficulty(_rp: int) -> float:
	return GuildWarData.SKILL


## The opponent's gear grade at this rank: a plain 50-star set at the bottom, then 100, 150
## and 200 stars with wings, and the class's divine set with wings at the top.
static func grade_of(rp: int) -> int:
	var grades := GuildWarData.GRADES
	return grades[clampi(step(rp) * grades.size() / (MAX_STEP + 1), 0, grades.size() - 1)]


static func opponent_level(_hero_level: int, _rp: int) -> int:
	return GuildWarData.LEVEL


# --- Results ----------------------------------------------------------------------

static func rp_change(won: bool, timeout: bool, streak: int) -> int:
	if won:
		return 28 + mini(streak, 5) * 3
	return -10 if timeout else -18


static func gold_reward(level: int, rp: int, won: bool) -> int:
	var base := level * (30 + 10 * step(rp))
	return base if won else int(base * 0.2)


static func exp_reward(level: int, rp: int, won: bool) -> int:
	var amount := int(HeroStats.exp_to_next(level) * 0.04 * (1.0 + 0.06 * step(rp)))
	return amount if won else int(amount * 0.25)


# --- The AI opponent ----------------------------------------------------------------

## A full AI player for the rank: { member, profile, mults, difficulty, look, grade, power }.
static func make_opponent(_hero_level: int, rp: int, rng: RandomNumberGenerator, avoid_class: StringName = &"") -> Dictionary:
	var classes: Array[StringName] = []
	for id in ClassData.IDS:
		classes.append(id)
	var class_id: StringName = classes[rng.randi() % classes.size()]
	if class_id == avoid_class and rng.randf() < 0.5:
		class_id = classes[rng.randi() % classes.size()]
	return GuildWarData.make_fighter(class_id, grade_of(rp), NAMES[rng.randi() % NAMES.size()], rng)
