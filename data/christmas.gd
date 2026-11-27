class_name Christmas
extends RefCounted
## เทศกาลคริสต์มาสและปีใหม่ (Christmas and the New Year): from 1 Dec 2026 00:00 to 2 Jan 2027
## 23:59 Thai time (START .. END, END the first second after), read off the clock
## (WorldPresence.clock(), Thai time WorldPlayers.TZ), the same on every device.
##
## - The village is dressed (ChristmasTown, built while decor_on): snow falling, a big
##   Christmas tree with twinkling lights on the plaza's terrace (in the great sakura's
##   place), strings of bulbs along the lantern lines, snowmen; fireworks over the town in
##   the New Year countdown and a big burst with "สวัสดีปีใหม่ 2027" at midnight.
## - Gift boxes (กล่องของขวัญ, the stackable GIFT) drop from every monster of every hunting
##   ground (WeeklyCollect.zone_ok) at GIFT_DROP a kill (like the Halloween potion), a boss
##   gives GIFT_BOSS. Opened from the bag (open_gifts, one or "เปิดทั้งหมด" up to
##   OPEN_ALL_MAX): one prize a box by GIFT_TABLE: gold, potions, forge jewels for the
##   hero's progress band (WeeklyCollect.tier_of), a piece of the Santa costume (PIECE) or,
##   rarely, the costume itself (once a hero: owned already it gives COSTUME_REPEAT pieces).
## - The Santa costume (ชุดซานต้า, RewardShop.COSTUMES COSTUME) is exchanged for
##   COSTUME_PIECES pieces in the reward shop while the festival runs.
## - Christmas night (24 Dec 18:00 .. 25 Dec 06:00) and the New Year countdown (31 Dec
##   23:00 .. 1 Jan 01:00): EXP +50% (BONUS_EXP) ADDED to the evening's x2 like the Loy
##   Krathong night (WorldEvents.exp_multiplier: x2.5 in the evening hours, x1.5 else).
## The gifts open from the bag at any time; nothing of the hero is kept here (the costume is
## owned through RewardShop's `own`).

const NAME := "คริสต์มาส"
const TITLE := "เทศกาลคริสต์มาสและปีใหม่"
const COLOR := Color("ff5a5a")
## 1 Dec 2026 00:00 .. 3 Jan 2027 00:00 Thai time (open to 2 Jan 23:59).
const START := 1796058000
const END := 1798909200
## Christmas night: 24 Dec 2026 18:00 .. 25 Dec 06:00 Thai time.
const NIGHT_START := 1798110000
const NIGHT_END := 1798153200
## The New Year countdown: 31 Dec 2026 23:00 .. 1 Jan 2027 01:00; midnight NEW_YEAR.
const COUNT_START := 1798732800
const COUNT_END := 1798740000
const NEW_YEAR := 1798736400
const YEAR := 2027
const NEW_YEAR_TEXT := "สวัสดีปีใหม่ 2027"
## The big burst of fireworks after midnight (seconds).
const BURST_LENGTH := 180.0
## The highlights' EXP bonus, added to the evening's (+0.5 = +50%).
const BONUS_EXP := 0.5
## The world hour the town's sky is held at through the highlights (DayNight).
const NIGHT_HOUR := 22.0

const GIFT := "xm_gift"
const PIECE := "xm_piece"
const COSTUME := "santa"
const COSTUME_PIECES := 30
## A costume rolled by a hero who owns it already becomes this many pieces.
const COSTUME_REPEAT := 5
const GIFT_DROP := 0.05
const GIFT_BOSS := 3
const OPEN_ALL_MAX := 100
## One prize a box: [id, chance, name shown in the help].
const GIFT_TABLE := [
	["gold", 0.47, "เหรียญทอง"], ["potion", 0.24, "ยาเลือด/ยามานา ×3"], ["purple", 0.12, "เพชรม่วง ×2"],
	["pink", 0.06, "เพชรชมพู"], ["chaos", 0.028, "เพชรชาออส"], ["piece", 0.08, "ชิ้นส่วนชุดซานต้า"], ["costume", 0.002, "ชุดซานต้า"],
]
## Gold of a box by progress band (WeeklyCollect.tier_of), times 0.5 .. 1.5.
const GIFT_GOLD: Array[int] = [1000, 4000, 12000, 30000, 60000, 120000]
const GIFT_HP: Array[String] = ["hp_s", "hp_m", "hp_l", "hp_xl", "hp_xxl", "hp_god"]
const GIFT_MP: Array[String] = ["mp_s", "mp_m", "mp_l", "mp_xl", "mp_xxl", "mp_xxl"]

## The world chat's festival lines (chat_line): none says what the speaker got.
const CHAT := ["เมอร์รี่คริสต์มาสทุกคน!", "หิมะตกในเมืองสวยมากเลย", "ไปถ่ายรูปกับต้นคริสต์มาสที่ลานกลางเมืองกัน",
	"กล่องของขวัญดรอปจากมอนทุกตัวเลย ล่ากันเถอะ", "ใครได้ชุดซานต้าแล้วบ้าง อยากได้จัง", "ตุ๊กตาหิมะที่ลานกลางเมืองน่ารักมาก",
	"ปีใหม่นี้ขอให้ตีบวกติดทุกคน", "ชิ้นส่วนชุดซานต้าจากกล่องของขวัญ เก็บไว้แลกชุดที่ร้านแลกของรางวัลนะ"]
const CHAT_NIGHT := ["คืนคริสต์มาส EXP +50% ถึง 6 โมงเช้านะ", "เมอร์รี่คริสต์มาส! คืนนี้ล่ายาวเลย", "ไฟต้นคริสต์มาสกระพริบสวยมาก"]
const CHAT_COUNT := ["อีกนิดเดียวจะปีใหม่แล้ว!", "ไปนับถอยหลังที่ลานกลางเมืองกัน", "พลุสวยมาก!", "EXP +50% ถึงตีหนึ่งนะ"]
const CHAT_NEW := ["สวัสดีปีใหม่ 2027!", "Happy New Year 2027!", "ปีใหม่นี้ขอให้ทุกคนดรอปดี ๆ", "พลุเต็มฟ้าเลย สวัสดีปีใหม่!"]
const CHAT_SHARE := 0.12

## false: no festival at all (tests of other events also switch it off with
## WorldEvents.festival_enabled).
static var enabled := true
## Tests pin the clock here (>= 0); otherwise WorldPresence.clock().
static var test_time := -1.0
static var _told_open := false
static var _told_night := false
static var _told_count := false
static var _told_new := false


static func now() -> float:
	return test_time if test_time >= 0.0 else WorldPresence.clock()


static func _t(t: float) -> float:
	return now() if t < 0.0 else t


static func _live() -> bool:
	return enabled and WorldEvents.festival_enabled


# --- The calendar ------------------------------------------------------------------

static func on(t := -1.0) -> bool:
	t = _t(t)
	return _live() and t >= float(START) and t < float(END)


static func night_on(t := -1.0) -> bool:
	t = _t(t)
	return _live() and t >= float(NIGHT_START) and t < float(NIGHT_END)


static func countdown_on(t := -1.0) -> bool:
	t = _t(t)
	return _live() and t >= float(COUNT_START) and t < float(COUNT_END)


## Christmas night or the countdown: the EXP bonus and the town's held night.
static func bonus_on(t := -1.0) -> bool:
	return night_on(t) or countdown_on(t)


## The EXP the highlights add (0 outside them; WorldEvents.exp_multiplier adds it to the
## evening's x2 and multiplies the sum by the festivals').
static func exp_bonus(t: float) -> float:
	return BONUS_EXP if bonus_on(t) else 0.0


## The town is dressed (snow, the tree, the lights, snowmen) through the whole window.
static func decor_on(t := -1.0) -> bool:
	return on(t)


## Fireworks over the town: the countdown.
static func fireworks_on(t := -1.0) -> bool:
	return countdown_on(t)


## 0..1 of the big burst after midnight (0 outside it).
static func burst(t := -1.0) -> float:
	t = _t(t)
	if not countdown_on(t) or t < float(NEW_YEAR) or t >= float(NEW_YEAR) + BURST_LENGTH:
		return 0.0
	return 1.0 - (t - float(NEW_YEAR)) / BURST_LENGTH


## Past midnight of the new year (in the countdown).
static func new_year_on(t := -1.0) -> bool:
	t = _t(t)
	return countdown_on(t) and t >= float(NEW_YEAR)


static func date_text(t: float) -> String:
	return WeeklyCollect.date_text(t)


## "1 ธ.ค. 00:00 - 2 ม.ค. 23:59".
static func window_text() -> String:
	return "%s - %s" % [date_text(float(START)), date_text(float(END - 60))]


## The HUD chip's line ("" outside the festival).
static func chip_text(t: float) -> String:
	if not on(t):
		return ""
	if countdown_on(t):
		if t < float(NEW_YEAR):
			return "นับถอยหลังสู่ปี %d อีก %s · EXP +50%% · พลุเต็มฟ้า" % [YEAR, WorldEvents._span(float(NEW_YEAR) - t)]
		return "%s! EXP +50%% เหลือ %s" % [NEW_YEAR_TEXT, WorldEvents._span(float(COUNT_END) - t)]
	if night_on(t):
		return "คืนคริสต์มาส: EXP +50%% เหลือ %s" % WorldEvents._span(float(NIGHT_END) - t)
	return "%s เหลือ %s · กล่องของขวัญดรอป %s%%" % [TITLE, WeeklyCollect.left_text(float(END) - t), ChatFacts.pct(GIFT_DROP)]


## WorldEvents.current's entries ([] outside the festival).
static func events(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not on(t):
		return out
	out.append({"id": "xmas", "name_th": TITLE, "until": float(END)})
	if night_on(t):
		out.append({"id": "xmas_night", "name_th": "คืนคริสต์มาส EXP +50%", "until": float(NIGHT_END)})
	if countdown_on(t):
		out.append({"id": "newyear", "name_th": "นับถอยหลังปีใหม่ EXP +50%", "until": float(COUNT_END)})
	return out


# --- Gift boxes ---------------------------------------------------------------------

static func gift(count := 1) -> Dictionary:
	return ItemData.jewel(GIFT, count)


## Whether `id` is one of this festival's stackables.
static func is_own_id(id: String) -> bool:
	return id == GIFT or id == PIECE


## The boxes one kill drops at t ([] outside the festival or the hunting grounds): a boss
## GIFT_BOSS, any other monster one at GIFT_DROP.
static func kill_drops(zone: Dictionary, boss: bool, t: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not on(t) or not WeeklyCollect.zone_ok(zone):
		return out
	if boss:
		out.append(gift(GIFT_BOSS))
	elif roll.randf() < GIFT_DROP:
		out.append(gift())
	return out


## The prize id of one box (GIFT_TABLE) for a roll in 0..1.
static func gift_pick(r: float) -> String:
	var acc := 0.0
	for row in GIFT_TABLE:
		acc += float(row[1])
		if r < acc:
			return String(row[0])
	return String(GIFT_TABLE[0][0])


## The prize of one box for band `tier`: {"gold": n} or {"item": item}; "costume" marks
## the costume (only when `owned` is false; owned, it is COSTUME_REPEAT pieces).
static func gift_prize(tier: int, owned: bool, roll: RandomNumberGenerator) -> Dictionary:
	tier = clampi(tier, 0, GIFT_GOLD.size() - 1)
	match gift_pick(roll.randf()):
		"gold":
			return {"gold": int(round(float(GIFT_GOLD[tier]) * roll.randf_range(0.5, 1.5) / 100.0)) * 100}
		"potion":
			return {"item": ItemData.potion(GIFT_HP[tier] if roll.randf() < 0.6 else GIFT_MP[tier], 3)}
		"purple":
			return {"item": ItemData.jewel("purple", 2)}
		"pink":
			return {"item": ItemData.jewel("pink", 1)}
		"chaos":
			return {"item": ItemData.jewel("chaos", 1)}
		"piece":
			return {"item": ItemData.jewel(PIECE, 1)}
		"costume":
			if owned:
				return {"item": ItemData.jewel(PIECE, COSTUME_REPEAT)}
			return {"item": RewardShop.costume_item(COSTUME), "costume": true}
	return {"gold": GIFT_GOLD[tier]}


## Opens up to `count` boxes from the bag (at most OPEN_ALL_MAX a press). Every prize goes
## to the bag or the shared storage (Game.give_or_store); when neither has room the box stays
## shut and the opening stops. The costume is the hero's once (RewardShop's `own`), told to
## the server. Saves. {opened, gold, items, jackpots, stopped}.
static func open_gifts(count := 1, roll: RandomNumberGenerator = null) -> Dictionary:
	var out := {"opened": 0, "gold": 0, "items": [], "jackpots": [], "stopped": ""}
	if not Game.has_profile:
		out.stopped = "ยังไม่มีตัวละคร"
		return out
	if roll == null:
		roll = Game.rng
	var want := mini(mini(count, OPEN_ALL_MAX), Game.jewel_count(GIFT))
	if want <= 0:
		out.stopped = "ไม่มี%s" % String(ItemData.JEWELS[GIFT].name)
		return out
	var tier := WeeklyCollect.hero_tier()
	for i in want:
		var prize := gift_prize(tier, RewardShop.owns(COSTUME), roll)
		if prize.has("item"):
			var item: Dictionary = prize.item
			if not SkyIsleLoot._has_room(item):
				out.stopped = "กระเป๋าและคลังเต็ม — เปิดกล่องที่เหลือไม่ได้"
				break
			Game._spend_jewels(GIFT, 1)
			if bool(prize.get("costume", false)):
				_own_costume()
				(out.jackpots as Array).append(item)
				Announcer.broadcast("★ %s เปิด%sได้ %s! ★" % [String(Game.profile.get("name", "")), String(ItemData.JEWELS[GIFT].name), ItemData.name_of(item)], "jackpot")
			Game.give_or_store(item)
			(out.items as Array).append(item)
		else:
			Game._spend_jewels(GIFT, 1)
			Game.add_gold(int(prize.gold))
			out.gold = int(out.gold) + int(prize.gold)
		out.opened = int(out.opened) + 1
	if int(out.opened) > 0:
		Game.mark_dirty()
		Game.inventory_changed.emit()
		Game.save()
	return out


## Marks the costume owned (the shop's `own`, never made again by migrate_items).
static func _own_costume() -> void:
	var shop := RewardShop.data()
	var own: Array = shop.get("own", [])
	if not own.has(COSTUME):
		own.append(COSTUME)
	shop["own"] = own
	Game.profile.flags[RewardShop.ITEM_FLAG + COSTUME] = 1


## "38%" / "0.2%" as the help prints it.
static func percent(chance: float) -> String:
	return String.num(chance * 100.0, 1).trim_suffix(".0") + "%"


## The bag's help line of one of the festival's stackables ("" for any other id).
static func help(id: String) -> String:
	match id:
		GIFT:
			var rows: PackedStringArray = []
			for row in GIFT_TABLE:
				rows.append("%s %s" % [String(row[2]), percent(float(row[1]))])
			return "กล่องของขวัญ%s: เปิดจากกระเป๋า สุ่มของรางวัล 1 อย่างต่อกล่อง: %s (ชุดซานต้าได้ครั้งเดียว มีแล้วได้ชิ้นส่วน %d ชิ้นแทน) · ดรอปจากมอนทุกสนามล่า %s%% ต่อตัว บอสให้ %d กล่อง ช่วง %s" % [
				TITLE, ", ".join(rows), COSTUME_REPEAT, ChatFacts.pct(GIFT_DROP), GIFT_BOSS, window_text()]
		PIECE:
			return "ชิ้นส่วนชุดซานต้า: ครบ %d ชิ้นแลกชุดซานต้าได้ที่%s (แท็บคอสตูม) ช่วง%s (%s) · ได้จากกล่องของขวัญ" % [COSTUME_PIECES, RewardShop.SHOP_NAME, TITLE, window_text()]
	return ""


# --- Chat ---------------------------------------------------------------------------

## A world player's festival line in the world chat ("" outside the festival).
static func chat_line(s: Dictionary, seed_value: int, t: float) -> String:
	if not on(t) or not s.has("index"):
		return ""
	var pick := absi(hash(seed_value * 17 + 3))
	if new_year_on(t):
		return String(CHAT_NEW[pick % CHAT_NEW.size()])
	if countdown_on(t):
		return String(CHAT_COUNT[pick % CHAT_COUNT.size()])
	if night_on(t) and pick % 2 == 0:
		return String(CHAT_NIGHT[(pick / 2) % CHAT_NIGHT.size()])
	return String(CHAT[(pick / 2) % CHAT.size()])


## The answer of a world player asked about the festival (dates and what it gives).
static func chat_answer(_index: int, t: float) -> String:
	if not _live() or t >= float(END):
		return "%sจบไปแล้ว ปีหน้ามาฉลองด้วยกันใหม่นะ" % TITLE if t >= float(END) and _live() else "ตอนนี้ยังไม่มี%sนะ" % TITLE
	if t < float(START):
		return "%s เริ่ม %s ถึง %s คืนคริสต์มาส 24 ธ.ค. 18:00 ถึง 25 ธ.ค. 06:00 EXP +50%%" % [TITLE, date_text(float(START)), date_text(float(END - 60))]
	if countdown_on(t):
		return "นับถอยหลังปีใหม่อยู่ EXP +50%% ถึง 01:00 พลุที่ลานกลางเมือง กล่องของขวัญดรอป %s%% ถึง %s" % [ChatFacts.pct(GIFT_DROP), date_text(float(END - 60))]
	if night_on(t):
		return "คืนคริสต์มาส EXP +50%% ถึง 25 ธ.ค. 06:00 กล่องของขวัญดรอป %s%% ทุกสนามล่า ชิ้นส่วน %d ชิ้นแลกชุดซานต้า" % [ChatFacts.pct(GIFT_DROP), COSTUME_PIECES]
	return "กล่องของขวัญดรอป %s%% จากมอนทุกสนามล่า ชิ้นส่วน %d ชิ้นแลกชุดซานต้า ถึง %s คืน 24 ธ.ค. กับนับถอยหลัง 31 ธ.ค. 23:00 EXP +50%%" % [ChatFacts.pct(GIFT_DROP), COSTUME_PIECES, date_text(float(END - 60))]


# --- The server's news ------------------------------------------------------------------

## Once a second (Announcer.tick): the opening, Christmas night, the countdown and
## midnight, once each a run of the game.
static func tick(t: float) -> void:
	if not on(t):
		return
	if not _told_open:
		_told_open = true
		Announcer.show(Announcer.clean("%sเริ่มแล้ว! หิมะตกในเมือง กล่องของขวัญดรอปจากมอนทุกสนามล่า ถึง %s" % [TITLE, date_text(float(END - 60))]), "rare")
	if night_on(t) and not _told_night:
		_told_night = true
		Announcer.show(Announcer.clean("เมอร์รี่คริสต์มาส! คืนคริสต์มาส EXP +50% ถึง 06:00"), "rare")
	if countdown_on(t) and t < float(NEW_YEAR) and not _told_count:
		_told_count = true
		Announcer.show(Announcer.clean("นับถอยหลังสู่ปี %d! EXP +50%% ถึง 01:00 พลุเต็มฟ้าที่ลานกลางเมือง" % YEAR), "rare")
	if new_year_on(t) and not _told_new:
		_told_new = true
		_told_count = true
		Announcer.show(Announcer.clean("★ %s! ★" % NEW_YEAR_TEXT), "rare")


static func reset() -> void:
	_told_open = false
	_told_night = false
	_told_count = false
	_told_new = false
