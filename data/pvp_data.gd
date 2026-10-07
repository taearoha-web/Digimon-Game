class_name PvpData
extends RefCounted
## The ranked ladder: rank points (RP), the 17 steps from Copper III to Legend,
## and the AI players the hero is matched against. The higher the rank, the
## stronger and sharper the AI opponent.

const STEP_RP := 100
const MAX_STEP := 16
const TIME_LIMIT := 150.0
const MIN_LEVEL := 10

## divs = how many divisions (III, II, I) the tier has.
const TIERS: Array[Dictionary] = [
	{"name": "ทองแดง", "color": Color("d08a52"), "divs": 3, "icon": "🥉"},
	{"name": "เงิน", "color": Color("cfd8e8"), "divs": 3, "icon": "🥈"},
	{"name": "ทอง", "color": Color("ffd24a"), "divs": 3, "icon": "🥇"},
	{"name": "แพลทินัม", "color": Color("6fe8d8"), "divs": 3, "icon": "💠"},
	{"name": "เพชร", "color": Color("7fb8ff"), "divs": 3, "icon": "💎"},
	{"name": "ปรมาจารย์", "color": Color("c58aff"), "divs": 1, "icon": "👑"},
	{"name": "ตำนาน", "color": Color("ff6a5a"), "divs": 1, "icon": "🔥"},
]
const ROMAN := ["I", "II", "III"]

const NAMES := [
	"ซามูไรหมาป่า", "นักล่าเงา", "Kira", "Luna★", "มังกรทอง", "เจ้าชายลมพัด", "Blaze", "ราชินีน้ำแข็ง", "Zephyr",
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


## How sharp the AI is at this rank: 0 (Copper III) .. 1 (Legend).
static func difficulty(rp: int) -> float:
	return float(step(rp)) / float(MAX_STEP)


static func stars(rp: int) -> int:
	return 1 + int(round(difficulty(rp) * 4.0))


static func opponent_level(hero_level: int, rp: int) -> int:
	var delta := int(round(lerpf(-3.0, 3.0, difficulty(rp))))
	return clampi(hero_level + delta, MIN_LEVEL, 100)


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

## A fake hero for the AI: { member, profile, mults, difficulty }.
static func make_opponent(hero_level: int, rp: int, rng: RandomNumberGenerator, avoid_class: StringName = &"") -> Dictionary:
	var t := difficulty(rp)
	var level := opponent_level(hero_level, rp)
	var classes: Array[StringName] = []
	for id in ClassData.IDS:
		classes.append(id)
	var class_id: StringName = classes[rng.randi() % classes.size()]
	if class_id == avoid_class and rng.randf() < 0.5:
		class_id = classes[rng.randi() % classes.size()]
	var adv := JobData.adv_for_level(level)
	var data := JobData.resolve(class_id, adv)
	var points := int(3.0 * float(level - 1) * lerpf(0.4, 1.0, t))
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[String(data.main)] = int(points * 0.6)
	attrs["vit"] = int(points * 0.4)
	var rarity := clampi(1 + step(rp) / 5, 1, 4)
	var equip := {}
	for slot in ItemData.SLOTS:
		equip[slot] = ItemData.generate(level, class_id, rng, rarity, slot)
	var name: String = NAMES[rng.randi() % NAMES.size()]
	var member := {"class": String(class_id), "name": name, "level": level}
	return {
		"member": member,
		"profile": {"class": String(class_id), "level": level, "attrs": attrs, "equip": equip, "adv": adv},
		"mults": {"hp": lerpf(0.7, 1.2, t), "atk": lerpf(0.5, 1.1, t), "def": lerpf(0.6, 1.1, t)},
		"difficulty": t,
		"look": FaceKit.random_look(rng),
	}
