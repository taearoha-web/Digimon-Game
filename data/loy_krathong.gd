class_name LoyKrathong
extends RefCounted
## เทศกาลลอยกระทง (the Loy Krathong festival): from 22 Nov 2026 07:40 to 26 Nov 07:40 Thai
## time (START .. END), read off the clock (WorldPresence.clock()), the same on every device.
## The night of Loy Krathong is Tuesday 24 Nov 2026 (the full moon of the twelfth lunar
## month), 19:00-23:00 Thai time (NIGHT_START .. NIGHT_END).
##
## - Materials (วัสดุกระทง, forge-jewel stackables MATS: ใบตอง, ดอกบัว, เทียนทอง, เกล็ดพญานาค)
##   drop from every monster of every hunting ground during the festival, the way the
##   weekly rare collection's pieces do (WeeklyCollect.zone_ok / pace_of / mult_of): a
##   piece's chance is its RATE (kills a piece at REF_PACE kills a minute) moved by the
##   field's own kill pace, so an hour of steady hunting finds about the same everywhere:
##   ~20 ใบตอง, 8 ดอกบัว, 2.4 เทียนทอง and 0.4 เกล็ดพญานาค (the Naga brings more).
## - Krathongs (KRATHONGS, four tiers, stackables "lk_k0".."lk_k3") are made from them at
##   the pier or the menu (craft) and floated at the pier in town (float_krathong): the
##   hero picks one from the bag, types a wish (clean_wish: one line, WISH_MAX characters)
##   and it floats away. At most DAILY_FLOATS a Thai day. Each float pays its tier's reward
##   for the hero's progress band (WeeklyCollect.tier_of: newcomer .. ★300; rewards) and
##   festival points (แต้มลอยกระทง, POINTS); the top tier (กระทงเทพนาคา) rolls for rares
##   (rare_roll: the sky isle's egg and costume fragments, the festival costume and its
##   pieces), a big one told to the server (Announcer.broadcast "jackpot").
## - The night: EXP x2 from 19:00 to 23:00, ADDED to the evening EXP x2 rather than
##   multiplied (19:00-21:00 x3, 21:00-23:00 x2; WorldEvents.exp_multiplier), sky lanterns
##   over town and the town's sky held at night (LoyKrathongPier, DayNight), and พญานาค
##   (the Naga, a world boss) rising in every levelling field at NAGA_TIMES for
##   NAGA_LENGTH (naga_now; Zone spawns it like the world boss, at NAGA_HP times the
##   field boss's HP), once a window a hero (flags[NAGA_FLAG]); it drops เกล็ดพญานาค,
##   costume pieces and rolls for rares (naga_drops).
## - The pageant (ประกวดนางนพมาศ / หนุ่มลอยกระทง) on the stage by the pier: once a Thai day
##   the hero enters (enter); the crowd's votes come from how splendid the outfit is
##   (splendour: the costume (the festival costume most), wings, gear grade and +) plus
##   the day's crowd (a roll of the name and the day), best entry kept. The AI world
##   players (contestants: PAGEANT_FIELD girls and boys picked by name) are judged the same
##   way. Girls compete for นางนพมาศ, boys for หนุ่มลอยกระทง (the hero's look.gender). The
##   result comes at RESULT_AT (the last evening, 25 Nov 20:00, told to everyone); the
##   winner's title (Achievements t_lk_queen / t_lk_king, flags QUEEN_FLAG / KING_FLAG) and
##   the prizes are given once (settle).
## - The festival costume (ชุดลอยกระทง, RewardShop.COSTUMES COSTUME) for COSTUME_PIECES
##   pieces (PIECE) or COSTUME_POINTS festival points, only while the festival runs.
##
## The hero's record is Game.profile[KEY] = {day (the Thai day of `n`), n (floats that
## day), fl (floats in all), pts (festival points), pg (best pageant votes, 0 none), pgd
## (the Thai day of the last entry), pgg (the gender entered as: 0 boy, 1 girl), got
## (bits: GOT_*)}, all ints (valid / repair; accounts.js validLoyKrathong keeps the same).

const KEY := "loyk"
const NAME := "ลอยกระทง"
const TITLE := "เทศกาลลอยกระทง"
const COLOR := Color("ffc24a")
const DAY := 86400
## 22 Nov 2026 07:40 .. 26 Nov 07:40 Thai time.
const START := 1795308000
const END := 1795653600
## The night of Loy Krathong: 24 Nov 2026 19:00-23:00 Thai time.
const NIGHT_START := 1795521600
const NIGHT_END := 1795536000
## The pageant's result: 25 Nov 2026 20:00 Thai time (the festival's last evening).
const RESULT_AT := 1795611600
## The night's EXP bonus, added to the evening's (+1 = x2 alone).
const NIGHT_EXP := 1.0
## The world hour the town's sky is held at on the night (DayNight).
const NIGHT_HOUR := 21.5

## Materials, common first.
const MATS: Array[String] = ["lk_leaf", "lk_lotus", "lk_candle", "lk_scale"]
const MAT_NAMES: Array[String] = ["ใบตอง", "ดอกบัว", "เทียนทอง", "เกล็ดพญานาค"]
const MAT_RANKS: Array[String] = ["ธรรมดา", "ไม่ธรรมดา", "หายาก", "หายากมาก"]
## Kills a piece at REF_PACE kills a minute.
const RATE: Array[int] = [60, 150, 500, 3000]
const REF_PACE := 20.0
const CHANCE_CAP := 0.9
## The krathongs: what each takes (MATS counts), its points and look.
const KRATHONGS: Array[Dictionary] = [
	{"id": "lk_k0", "name": "กระทงใบตอง", "need": [3, 0, 0, 0], "pts": 10, "color": Color("7ad06a")},
	{"id": "lk_k1", "name": "กระทงดอกบัว", "need": [3, 2, 0, 0], "pts": 20, "color": Color("ff8fc8")},
	{"id": "lk_k2", "name": "กระทงทองคำ", "need": [3, 2, 1, 0], "pts": 35, "color": Color("ffd23a")},
	{"id": "lk_k3", "name": "กระทงเทพนาคา", "need": [3, 2, 1, 1], "pts": 60, "color": Color("5cf2d0")},
]
const DAILY_FLOATS := 5
const WISH_MAX := 40
## The festival costume and its pieces.
const PIECE := "lk_piece"
const COSTUME := "loykrathong"
const COSTUME_PIECES := 30
const COSTUME_POINTS := 600
## A pageant entry's festival points.
const ENTRY_POINTS := 15
const MAX_POINTS := 1000000
## got bits.
const GOT_COSTUME := 1
const GOT_PRIZE := 2
## The pageant's titles (Achievements) by the flags they read.
const QUEEN_FLAG := "lk_queen"
const KING_FLAG := "lk_king"
const QUEEN_TITLE := "นางนพมาศ ๒๕๖๙"
const KING_TITLE := "หนุ่มลอยกระทง ๒๕๖๙"
const PAGEANT_NAME := "ประกวดนางนพมาศ & หนุ่มลอยกระทง"
## AI contestants of each gender.
const PAGEANT_FIELD := 9
## Votes: splendour (0..100) times VOTE_PER plus the crowd of the day (0..CROWD).
const VOTE_PER := 12
const CROWD := 160
## The Naga (พญานาค) of the night: it rises at these seconds of the Thai day of the
## night, for NAGA_LENGTH, in every levelling field (WorldEvents.golden_field).
const NAGA_NAME := "พญานาค"
const NAGA_TIMES: Array[int] = [20 * 3600, 21 * 3600, 22 * 3600]
const NAGA_LENGTH := 20 * 60
const NAGA_HP := 4.0
const NAGA_FLAG := "lk_naga"
const NAGA_POINTS := 50
const NAGA_HEIGHT := 6.5
const NAGA_COLOR := Color("5cf2d0")
const NAGA_SHOUTS := ["พญานาคขึ้นมาแล้ว! รุมเลย!", "ขอเกล็ดพญานาคสักเกล็ดเถอะ!", "ระวังหางฟาด!", "ตีพญานาคให้ล้ม ได้ลุ้นไข่มังกร!"]
## AI floats at the pier: one chance a FLOAT_SLOT seconds (FLOAT_SHARE by day, more at
## night), each krathong drifting FLOAT_LIFE seconds.
const FLOAT_SLOT := 45.0
const FLOAT_SHARE := 0.55
const FLOAT_SHARE_NIGHT := 0.95
const FLOAT_LIFE := 60.0
## The wishes the world players make (a wish, not a claim: never "ได้<an item>").
const WISHES := ["ขอให้ตีบวกติด", "ขอให้ปีกเทพมาไว ๆ", "ขอให้ไข่มังกรฟ้าเทพดรอปสักใบ", "ขอให้กิลด์ชนะกิลด์วอ", "ขอให้ดาวขึ้นไว ๆ",
	"ขอให้ชุดเทพมังกรครบไว ๆ", "ขอให้เจอคนรู้ใจ", "ขอให้ดรอปดีทุกตัว", "ขอให้ตีบวกติดรวดเดียว", "ขอให้มีแฟนในเกม",
	"ขอให้เพื่อน ๆ ในกิลด์สุขภาพแข็งแรง", "ขอให้เกล็ดพญานาคดรอปเยอะ ๆ", "ขอให้ปีนี้รวย ๆ", "ขอให้ล่ามังกรแก้วได้", "ขอให้แก่นเทพหลอมเซตดรอปเยอะ ๆ"]
## The world chat's festival lines (chat_line). Lines 0, 1, 6 and 7 tell what the speaker
## really did: its own krathong at the pier (own_float: %wish its wish, %name its krathong;
## 6 only when that krathong took a เทียนทอง); 3 only in the evening and night, 5 only
## before the pageant's result; the rest say nothing about the speaker.
const CHAT := ["ลอยกระทงแล้ว %wish สาธุ", "ไปลอย%name ที่ท่าน้ำในเมืองมา สวยมาก", "ใครเก็บใบตองได้เยอะ แบ่งหน่อย", "พระจันทร์เต็มดวงสวยจัง",
	"ไปดูกระทงที่ท่าน้ำในเมืองกันไหม", "ปีนี้จะประกวดนางนพมาศ ใครไปบ้าง", "ได้เทียนทองมาแล้ว ทำ%nameไปลอยแล้ว!", "%wish ด้วยเถิด ลอยกระทงแล้ว"]
## The lines needing the speaker's own krathong (own_float), and the ones about nobody.
const CHAT_OWN: Array[int] = [0, 1, 6, 7]
const CHAT_PLAIN: Array[int] = [2, 4]
const CHAT_NIGHT := ["คืนนี้คืนลอยกระทง EXP x2 ถึงห้าทุ่มนะ", "โคมลอยเต็มฟ้าเลย สวยมาก", "พญานาคขึ้นแล้ว รีบไปตี!", "ขอให้ปีกเทพมาไว ๆ ลอยกระทงคืนนี้"]
## How far back (seconds) a world player's own krathong is something it "just" floated.
const OWN_FLOAT_BACK := 4.0 * 3600.0
const CHAT_SHARE := 0.12

## false: no festival at all (tests of other events' base rates also switch it off with
## WorldEvents.festival_enabled).
static var enabled := true
## Tests pin the clock here (>= 0); otherwise WorldPresence.clock().
static var test_time := -1.0
## Floats the pier shows: sink(entry) for the hero's own ({name, wish, tier, at, hero}).
static var _sinks: Array[Callable] = []
static var _told_open := false
static var _told_night := false
static var _told_result := false
static var _told_naga := -1
static var _ai_cache := {}


static func now() -> float:
	return test_time if test_time >= 0.0 else WorldPresence.clock()


static func _t(t: float) -> float:
	return now() if t < 0.0 else t


# --- The calendar ------------------------------------------------------------------

static func on(t := -1.0) -> bool:
	t = _t(t)
	return enabled and WorldEvents.festival_enabled and t >= float(START) and t < float(END)


static func night_on(t := -1.0) -> bool:
	t = _t(t)
	return enabled and WorldEvents.festival_enabled and t >= float(NIGHT_START) and t < float(NIGHT_END)


## The EXP the night adds (0 outside it; WorldEvents.exp_multiplier adds it to the
## evening's x2 and multiplies the sum by the festivals').
static func exp_bonus(t: float) -> float:
	return NIGHT_EXP if night_on(t) else 0.0


## The town is dressed (the pier's lights, the moon) from the festival's start to its end.
static func decor_on(t := -1.0) -> bool:
	return on(t)


## "22 พ.ย. 07:40" (Thai time).
static func date_text(t: float) -> String:
	return WeeklyCollect.date_text(t)


static func left_text(seconds: float) -> String:
	return WeeklyCollect.left_text(seconds)


## The HUD chip's line ("" outside the festival): the night, the Naga, or the days left.
static func chip_text(t: float) -> String:
	if not on(t):
		return ""
	var naga := naga_now(t)
	if not naga.is_empty() and not naga_done(int(naga.window)):
		return "%s ขึ้นจากน้ำ! ทุกแผนที่ล่า เหลือ %s" % [NAGA_NAME, WorldEvents._span(float(naga.until) - t)]
	if night_on(t):
		return "คืนลอยกระทง: EXP x2 + โคมลอย เหลือ %s" % WorldEvents._span(float(NIGHT_END) - t)
	var floats := " · ลอยได้อีก %d" % floats_left(t) if Game.has_profile else ""
	return "%s เหลือ %s%s" % [TITLE, left_text(float(END) - t), floats]


## WorldEvents.current's entries ([] outside the festival).
static func events(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not on(t):
		return out
	out.append({"id": "loyk", "name_th": TITLE, "until": float(END)})
	if night_on(t):
		out.append({"id": "loyk_night", "name_th": "คืนลอยกระทง EXP x2", "until": float(NIGHT_END)})
	var naga := naga_now(t)
	if not naga.is_empty():
		out.append({"id": "naga", "name_th": NAGA_NAME, "until": float(naga.until)})
	return out


# --- Materials ----------------------------------------------------------------------

static func mat(k: int, count := 1) -> Dictionary:
	return ItemData.jewel(MATS[k], count)


static func krathong(k: int, count := 1) -> Dictionary:
	return ItemData.jewel(String(KRATHONGS[k].id), count)


## The tier (0..3) of a krathong item, -1 for anything else.
static func tier_of_item(item: Dictionary) -> int:
	if String(item.get("kind", "")) != "jewel":
		return -1
	for k in KRATHONGS.size():
		if String(KRATHONGS[k].id) == String(item.get("id", "")):
			return k
	return -1


## Whether `id` is one of this festival's stackables (materials, krathongs, the piece).
static func is_own_id(id: String) -> bool:
	return id.begins_with("lk_") and ItemData.JEWELS.has(id)


## Chance of material k in one kill in `zone` (WeeklyCollect's pace scaling).
static func chance(k: int, zone: Dictionary, mult := 1.0, fortune := 0.0) -> float:
	var pace := maxf(0.5, WeeklyCollect.pace_of(zone))
	return minf(CHANCE_CAP, (REF_PACE / pace) / float(RATE[k]) * mult * (1.0 + maxf(fortune, 0.0)))


## Materials an hour of steady hunting finds in `zone`.
static func per_hour(k: int, zone: Dictionary) -> float:
	return chance(k, zone) * WeeklyCollect.pace_of(zone) * 60.0


## The materials one kill drops at t ([] outside the festival or the hunting grounds);
## kind: WeeklyCollect.mult_of's ("elite", "boss", "golden", "world_boss" or "").
static func kill_drops(zone: Dictionary, kind: String, fortune: float, t: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not on(t) or not WeeklyCollect.zone_ok(zone):
		return out
	var mult := WeeklyCollect.mult_of(kind)
	for k in MATS.size():
		if roll.randf() < chance(k, zone, mult, fortune):
			out.append(mat(k))
	return out


static func owned(id: String) -> int:
	return Game.jewel_count(id) if Game.has_profile else 0


# --- The hero's record ----------------------------------------------------------------

static func peek() -> Dictionary:
	var d: Variant = Game.profile.get(KEY) if Game.has_profile else null
	if d is Dictionary:
		return d
	return {"day": -1, "n": 0, "fl": 0, "pts": 0, "pg": 0, "pgd": -1, "pgg": 0, "got": 0}


static func data() -> Dictionary:
	var d := peek()
	if Game.has_profile:
		Game.profile[KEY] = d
	return d


static func points() -> int:
	return int(peek().get("pts", 0))


static func add_points(amount: int) -> void:
	if not Game.has_profile or amount <= 0:
		return
	var d := data()
	d["pts"] = mini(MAX_POINTS, int(d.get("pts", 0)) + amount)
	Game.mark_dirty()


## Floats the hero may still make on the Thai day of t.
static func floats_left(t := -1.0) -> int:
	var d := peek()
	if int(d.get("day", -1)) != WorldEvents.day_of(_t(t)):
		return DAILY_FLOATS
	return maxi(0, DAILY_FLOATS - int(d.get("n", 0)))


# --- Crafting -------------------------------------------------------------------------

## Why krathong k cannot be made now ("" when it can).
static func craft_problem(k: int, t := -1.0) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if k < 0 or k >= KRATHONGS.size():
		return "ไม่มีกระทงแบบนี้"
	if not on(t):
		return "ทำกระทงได้เฉพาะช่วงเทศกาล (%s - %s)" % [date_text(float(START)), date_text(float(END))]
	var need: Array = KRATHONGS[k].need
	for m in MATS.size():
		if owned(MATS[m]) < int(need[m]):
			return "%sไม่พอ (มี %d/%d)" % [MAT_NAMES[m], owned(MATS[m]), int(need[m])]
	if owned(String(KRATHONGS[k].id)) <= 0 and Game.inventory_free() <= 0:
		var freed := false
		for m in MATS.size():
			freed = freed or (int(need[m]) > 0 and owned(MATS[m]) == int(need[m]))
		if not freed:
			return "กระเป๋าเต็ม"
	return ""


## Makes krathong k from the bag's materials. "ok" or the problem.
static func craft(k: int, t := -1.0) -> String:
	var why := craft_problem(k, t)
	if why != "":
		return why
	var need: Array = KRATHONGS[k].need
	for m in MATS.size():
		if int(need[m]) > 0:
			Game._spend_jewels(MATS[m], int(need[m]))
	Game.give_or_store(krathong(k))
	Game.inventory_changed.emit()
	Game.mark_dirty()
	return "ok"


## "ใบตอง ×3 + ดอกบัว ×2" of krathong k.
static func need_text(k: int) -> String:
	var parts: PackedStringArray = []
	var need: Array = KRATHONGS[k].need
	for m in MATS.size():
		if int(need[m]) > 0:
			parts.append("%s ×%d" % [MAT_NAMES[m], int(need[m])])
	return " + ".join(parts)


# --- Floating -------------------------------------------------------------------------

## What floating krathong k gives a hero of band `tier` (WeeklyCollect.tier_of) and class
## `cls`, before the top tier's rare roll: {gold, items, core (a set-core chance)}.
static func rewards(k: int, tier: int, cls: String) -> Dictionary:
	tier = clampi(tier, 0, WeeklyCollect.TIER_NAMES.size() - 1)
	var items: Array = []
	var gold := 0
	var core := 0.0
	match k:
		0:
			gold = [3000, 12000, 40000, 100000, 200000, 400000][tier]
			var hp: String = ["hp_s", "hp_m", "hp_l", "hp_xl", "hp_xxl", "hp_god"][tier]
			var mp: String = ["mp_s", "mp_m", "mp_l", "mp_xl", "mp_xxl", "mp_xxl"][tier]
			items.append(ItemData.potion(hp, 5))
			items.append(ItemData.potion(mp, 3))
		1:
			items.append(ItemData.jewel("purple", [2, 3, 5, 6, 8, 10][tier]))
			items.append(ItemData.jewel("pink", [1, 1, 2, 3, 4, 5][tier]))
		2:
			gold = [5000, 20000, 60000, 150000, 300000, 600000][tier]
			items.append(ItemData.jewel("chaos", [1, 1, 2, 3, 4, 5][tier]))
			items.append(ItemData.jewel("purple", [2, 3, 4, 5, 6, 8][tier]))
			core = [0.03, 0.05, 0.08, 0.1, 0.15, 0.2][tier]
		3:
			var plan := WorldGear.gem_plan(cls if ClassData.IDS.has(StringName(cls)) else "warrior")
			items.append(ItemData.jewel("chaos", [2, 3, 4, 5, 6, 8][tier]))
			items.append(ItemData.jewel("pink", [2, 3, 4, 5, 6, 8][tier]))
			items.append(ItemData.gem(String(plan.main), [0, 1, 1, 2, 2, 3][tier]))
			core = [0.05, 0.08, 0.12, 0.15, 0.2, 0.3][tier]
	return {"gold": gold, "items": items, "core": core}


## The top tier's rare roll: {items, jackpot (told to the server), text}.
## 1% the sky dragon's egg, 1% the festival costume (5 pieces once owned), 10% three
## costume fragments of the sky isle, 20% three festival pieces, else one piece.
static func rare_roll(roll: RandomNumberGenerator) -> Dictionary:
	var r := roll.randf()
	if r < 0.01:
		return {"items": [ItemData.jewel(SkyIsleLoot.EGG)], "jackpot": true}
	if r < 0.02:
		if not RewardShop.owns(COSTUME):
			return {"items": [RewardShop.costume_item(COSTUME)], "jackpot": true, "costume": true}
		return {"items": [ItemData.jewel(PIECE, 5)], "jackpot": false}
	if r < 0.12:
		return {"items": [ItemData.jewel(SkyIsleLoot.FRAGMENT, 3)], "jackpot": true}
	if r < 0.32:
		return {"items": [ItemData.jewel(PIECE, 3)], "jackpot": false}
	return {"items": [ItemData.jewel(PIECE, 1)], "jackpot": false}


## One line of plain text for a wish: no control characters, single spaces, at most
## WISH_MAX characters, rude words starred out.
static func clean_wish(text: String) -> String:
	var out := ""
	for c in text.strip_edges():
		var code := c.unicode_at(0)
		out += " " if code < 32 or code == 127 else c
	while out.contains("  "):
		out = out.replace("  ", " ")
	var low := out.to_lower()
	for bad in ["เหี้ย", "สัส", "ควาย", "fuck", "อีดอก", "ไอ้บ้า", "กาก"]:
		var at := low.find(bad)
		while at >= 0:
			out = out.substr(0, at) + "♥".repeat(bad.length()) + out.substr(at + bad.length())
			low = out.to_lower()
			at = low.find(bad)
	return out.strip_edges().left(WISH_MAX)


## Why krathong k cannot be floated now ("" when it can).
static func float_problem(k: int, t := -1.0) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if k < 0 or k >= KRATHONGS.size():
		return "ไม่มีกระทงแบบนี้"
	if not on(t):
		return "ลอยกระทงได้เฉพาะช่วงเทศกาล (%s - %s)" % [date_text(float(START)), date_text(float(END))]
	if owned(String(KRATHONGS[k].id)) <= 0:
		return "ไม่มี%sในกระเป๋า (ทำได้ที่ท่าน้ำหรือเมนู%s)" % [String(KRATHONGS[k].name), NAME]
	if floats_left(t) <= 0:
		return "วันนี้ลอยครบ %d ใบแล้ว พรุ่งนี้มาลอยใหม่นะ" % DAILY_FLOATS
	return ""


## Floats krathong k from the bag with `wish`: takes it, counts the day's floats, pays the
## reward (gold to the purse, items to the bag or the storage) and the points, rolls the
## top tier's rares. {result: "ok" or the problem, wish, gold, items}.
static func float_krathong(k: int, wish: String, t := -1.0, roll: RandomNumberGenerator = null) -> Dictionary:
	t = _t(t)
	var why := float_problem(k, t)
	if why != "":
		return {"result": why}
	if roll == null:
		roll = RandomNumberGenerator.new()
		roll.randomize()
	var text := clean_wish(wish)
	Game._spend_jewels(String(KRATHONGS[k].id), 1)
	var d := data()
	var day := WorldEvents.day_of(t)
	if int(d.get("day", -1)) != day:
		d["day"] = day
		d["n"] = 0
	d["n"] = int(d.get("n", 0)) + 1
	d["fl"] = int(d.get("fl", 0)) + 1
	add_points(int(KRATHONGS[k].pts))
	var r := rewards(k, WeeklyCollect.hero_tier(), String(Game.class_id()))
	var got: Array = (r.items as Array).duplicate(true)
	if float(r.core) > 0.0 and roll.randf() < float(r.core):
		got.append(ItemData.jewel("set_core", 1))
	var jackpot := false
	if k == KRATHONGS.size() - 1:
		var rare := rare_roll(roll)
		got.append_array(rare.items)
		jackpot = bool(rare.jackpot)
		if bool(rare.get("costume", false)):
			var shop := RewardShop.data()
			var own: Array = shop.get("own", [])
			if not own.has(COSTUME):
				own.append(COSTUME)
			shop["own"] = own
			Game.profile.flags[RewardShop.ITEM_FLAG + COSTUME] = 1
	if int(r.gold) > 0:
		Game.add_gold(int(r.gold))
	for item in got:
		Game.give_or_store((item as Dictionary).duplicate())
	if jackpot:
		var best: Dictionary = got[got.size() - 1]
		Announcer.broadcast(jackpot_text(String(Game.profile.get("name", "")), best), "jackpot")
	Game.inventory_changed.emit()
	Game.mark_dirty()
	var entry := {"name": String(Game.profile.get("name", "")), "wish": text, "tier": k, "at": t, "hero": true}
	for sink in _sinks.duplicate():
		if sink.is_valid():
			sink.call(entry)
		else:
			_sinks.erase(sink)
	return {"result": "ok", "wish": text, "gold": int(r.gold), "items": got, "jackpot": jackpot}


static func jackpot_text(who: String, item: Dictionary) -> String:
	return "%s ลอย%s แล้วได้ %s!" % [who, String(KRATHONGS[KRATHONGS.size() - 1].name), ItemData.name_of(item)]


static func listen(sink: Callable) -> void:
	if not _sinks.has(sink):
		_sinks.append(sink)


static func unlisten(sink: Callable) -> void:
	_sinks.erase(sink)


## "ทอง 12,000 · ยาเลือดกลาง ×5" of a reward.
static func reward_text(r: Dictionary) -> String:
	var text := WeeklyCollect.reward_text(r)
	if float(r.get("core", 0.0)) > 0.0:
		text += " · ลุ้น%s %d%%" % [ItemData.JEWELS["set_core"].name, int(round(float(r.core) * 100.0))]
	return text


# --- The costume ----------------------------------------------------------------------

## Why the festival costume cannot be exchanged by `how` ("pieces" or "points"); "" if it can.
static func costume_problem(how: String, t := -1.0) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if not on(t):
		return "แลกชุดลอยกระทงได้เฉพาะช่วงเทศกาล"
	if RewardShop.owns(COSTUME):
		return "มีชุดลอยกระทงแล้ว"
	if Game.inventory_free() <= 0 and Game.storage().size() >= Game.STORAGE_SIZE:
		return "กระเป๋าและคลังเต็ม"
	if how == "pieces" and owned(PIECE) < COSTUME_PIECES:
		return "%sไม่พอ (มี %d/%d)" % [ItemData.JEWELS[PIECE].name, owned(PIECE), COSTUME_PIECES]
	if how == "points" and points() < COSTUME_POINTS:
		return "แต้มลอยกระทงไม่พอ (มี %d/%d)" % [points(), COSTUME_POINTS]
	if how not in ["pieces", "points"]:
		return "ไม่มีวิธีแลกนี้"
	return ""


## Exchanges the festival costume (into the bag, worn from the costume slot). "ok" or why not.
static func exchange_costume(how: String, t := -1.0) -> String:
	var why := costume_problem(how, t)
	if why != "":
		return why
	if how == "pieces":
		Game._spend_jewels(PIECE, COSTUME_PIECES)
	else:
		var d := data()
		d["pts"] = int(d.get("pts", 0)) - COSTUME_POINTS
	var d2 := data()
	d2["got"] = int(d2.get("got", 0)) | GOT_COSTUME
	var shop := RewardShop.data()
	var own: Array = shop.get("own", [])
	if not own.has(COSTUME):
		own.append(COSTUME)
	shop["own"] = own
	Game.profile.flags[RewardShop.ITEM_FLAG + COSTUME] = 1
	Game.give_or_store(RewardShop.costume_item(COSTUME))
	Game.inventory_changed.emit()
	Game.mark_dirty()
	return "ok"


# --- The pageant ----------------------------------------------------------------------

## How splendid an outfit is (0..100): the worn costume (the festival's own most: 35, a
## shop costume 6 + 4 a grade), the wings (grade and +, at most 20) and the six pieces of
## gear (grade and +, at most 45). The same sum for the hero and the world players.
static func splendour(equip: Dictionary, costume: String) -> int:
	var score := 0.0
	if costume == COSTUME:
		score += 35.0
	elif RewardShop.COSTUMES.has(costume):
		score += 6.0 + 4.0 * float(RewardShop.costume_rarity(costume))
	var wings: Variant = equip.get("wings")
	if wings is Dictionary and not (wings as Dictionary).is_empty():
		score += minf(20.0, 6.0 + 3.0 * float(int(wings.get("rarity", 0))) + 0.4 * float(int(wings.get("plus", 0))))
	var gear := 0.0
	for slot in ItemData.SLOTS:
		var item: Variant = equip.get(slot)
		if item is Dictionary and not (item as Dictionary).is_empty():
			gear += float(clampi(int(item.get("rarity", 0)), 0, 4)) * 0.9 + float(clampi(int(item.get("plus", 0)), 0, 15)) * 0.3
	score += minf(45.0, gear)
	return clampi(int(round(score)), 0, 100)


static func hero_splendour() -> int:
	if not Game.has_profile:
		return 0
	return splendour(Game.profile.get("equip", {}), RewardShop.worn_costume())


## The crowd of a day for a contestant (0..CROWD-1).
static func crowd(who: String, day: int) -> int:
	return WorldEvents.roll("lkpg|%s|%d" % [who, day]) % CROWD


static func hero_gender() -> int:
	if not Game.has_profile:
		return 0
	return clampi(int((Game.profile.get("look", {}) as Dictionary).get("gender", 0)), 0, 1)


static func title_of(gender: int) -> String:
	return QUEEN_TITLE if gender == 1 else KING_TITLE


## Why the hero cannot enter the pageant now ("" when it can).
static func entry_problem(t := -1.0) -> String:
	t = _t(t)
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if not on(t):
		return "การประกวดจัดเฉพาะช่วงเทศกาล"
	if t >= float(RESULT_AT):
		return "ปิดรับสมัครแล้ว ประกาศผลแล้ว"
	if int(peek().get("pgd", -1)) == WorldEvents.day_of(t):
		return "วันนี้ขึ้นเวทีแล้ว พรุ่งนี้มาใหม่นะ"
	return ""


## The hero walks the stage: today's votes (splendour x VOTE_PER + the day's crowd), the
## best entry kept, ENTRY_POINTS festival points. {result, votes, best, splendour}.
static func enter(t := -1.0) -> Dictionary:
	t = _t(t)
	var why := entry_problem(t)
	if why != "":
		return {"result": why}
	var day := WorldEvents.day_of(t)
	var s := hero_splendour()
	var votes := s * VOTE_PER + crowd(String(Game.profile.get("name", "")), day)
	var d := data()
	d["pgd"] = day
	d["pgg"] = hero_gender()
	d["pg"] = maxi(int(d.get("pg", 0)), votes)
	add_points(ENTRY_POINTS)
	Game.mark_dirty()
	return {"result": "ok", "votes": votes, "best": int(d.pg), "splendour": s}


## The AI contestants of `gender`: PAGEANT_FIELD world players picked by name (the same
## on every device), those who joined before the result.
static func contestants(gender: int) -> Array[int]:
	var key := "field|%d" % gender
	if _ai_cache.has(key):
		return _ai_cache[key]
	WorldPlayers.ensure_until(float(RESULT_AT))
	var picks: Array = []
	for i in WorldPlayers.size():
		if WorldPlayers.joined_at(i) > float(RESULT_AT) or int(WorldPlayers.look(i).get("gender", 0)) != gender:
			continue
		picks.append([WorldEvents.roll("lkpgfield|%s" % String(WorldPlayers.entry(i).name)), i])
	picks.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var out: Array[int] = []
	for p in picks.slice(0, PAGEANT_FIELD):
		out.append(int(p[1]))
	_ai_cache[key] = out
	return out


## World player i's votes: its outfit on the result's eve and its best crowd of the
## festival's days.
static func ai_votes(i: int) -> int:
	var key := "votes|%d" % i
	if _ai_cache.has(key):
		return int(_ai_cache[key])
	var at := float(RESULT_AT) - 3600.0
	var equip := WorldGear.equip_at_work(i, WorldPlayers.work_at(i, at))
	var cos := String(RewardShop.world_cosmetics(i, at).get("cos", ""))
	var name := String(WorldPlayers.entry(i).name)
	var best := 0
	for day in range(WorldEvents.day_of(float(START)), WorldEvents.day_of(float(RESULT_AT)) + 1):
		best = maxi(best, crowd(name, day))
	var votes := splendour(equip, cos) * VOTE_PER + best
	_ai_cache[key] = votes
	return votes


## The ranked stage of `gender`: [{rank, name, votes, hero, index, splendour?}], best first;
## the hero among them once it entered as that gender.
static func standings(gender: int) -> Array:
	var rows: Array = []
	for i in contestants(gender):
		rows.append({"name": String(WorldPlayers.entry(i).name), "votes": ai_votes(i), "hero": false, "index": i})
	var d := peek()
	if Game.has_profile and int(d.get("pg", 0)) > 0 and int(d.get("pgg", 0)) == gender:
		rows.append({"name": String(Game.profile.get("name", "")), "votes": int(d.pg), "hero": true, "index": -1})
	rows.sort_custom(func(a, b): return int(a.votes) > int(b.votes) if int(a.votes) != int(b.votes) else (bool(a.hero) and not bool(b.hero)) if bool(a.hero) != bool(b.hero) else String(a.name) < String(b.name))
	for k in rows.size():
		rows[k]["rank"] = k + 1
	return rows


static func result_out(t := -1.0) -> bool:
	return enabled and _t(t) >= float(RESULT_AT)


## The hero's place on its stage (0: not entered).
static func hero_rank() -> int:
	var d := peek()
	if int(d.get("pg", 0)) <= 0:
		return 0
	for row in standings(int(d.get("pgg", 0))):
		if bool(row.hero):
			return int(row.rank)
	return 0


## The prize of a place (1 = the title): {items}.
static func prize(rank: int) -> Array:
	if rank == 1:
		return [ItemData.jewel("chaos", 10), ItemData.jewel("set_core", 1), ItemData.jewel(PIECE, 10)]
	if rank >= 2 and rank <= 3:
		return [ItemData.jewel("chaos", 5), ItemData.jewel("pink", 10), ItemData.jewel(PIECE, 5)]
	if rank > 3:
		return [ItemData.jewel("purple", 10), ItemData.jewel(PIECE, 2)]
	return []


## After the result, once: the hero's prize and, for the winner, the title. "ok" when
## given now, "" when there is nothing (yet) to give.
static func settle(t := -1.0) -> String:
	if not Game.has_profile or not result_out(t):
		return ""
	var d := peek()
	if int(d.get("pg", 0)) <= 0 or int(d.get("got", 0)) & GOT_PRIZE != 0:
		return ""
	var rank := hero_rank()
	d = data()
	d["got"] = int(d.get("got", 0)) | GOT_PRIZE
	for item in prize(rank):
		Game.give_or_store((item as Dictionary).duplicate())
	if rank == 1:
		var flag := QUEEN_FLAG if int(d.get("pgg", 0)) == 1 else KING_FLAG
		Game.profile.flags[flag] = 1
		Game.check_achievements()
		Game.say("ได้ตำแหน่ง \"%s\"! ใส่ได้ที่เมนูตำแหน่ง" % title_of(int(d.get("pgg", 0))), &"success")
	else:
		Game.say("ผล%s: คุณได้อันดับ %d รับรางวัลแล้ว" % [PAGEANT_NAME, rank], &"success")
	Game.inventory_changed.emit()
	Game.mark_dirty()
	return "ok"


## The result line told to everyone at RESULT_AT.
static func result_text() -> String:
	var queen := standings(1)
	var king := standings(0)
	return "ประกาศผล! %s คือ %s · %s คือ %s" % [QUEEN_TITLE, String(queen[0].name) if not queen.is_empty() else "-", KING_TITLE, String(king[0].name) if not king.is_empty() else "-"]


# --- The Naga ---------------------------------------------------------------------------

## The Naga's window `t` is in: {window, start, until}, or {} outside them.
static func naga_now(t: float) -> Dictionary:
	if not enabled or not WorldEvents.festival_enabled or t < float(NIGHT_START) or t >= float(NIGHT_END):
		return {}
	var day := WorldEvents.day_of(float(NIGHT_START))
	var midnight := float(day) * float(DAY) - float(WorldPlayers.TZ)
	for k in NAGA_TIMES.size():
		var start := midnight + float(NAGA_TIMES[k])
		if t >= start and t < start + float(NAGA_LENGTH):
			return {"window": day * 4 + k, "start": start, "until": start + float(NAGA_LENGTH), "slot": k}
	return {}


static func naga_done(window: int) -> bool:
	return Game.has_profile and int(Game.profile.flags.get(NAGA_FLAG, -1)) == window


## The Naga's items for the hero's side: เกล็ดพญานาค 2-3, festival pieces 2, chaos 2, and a
## roll: 2% the sky dragon egg, 6% three sky isle fragments (both told to the server).
static func naga_drops(roll: RandomNumberGenerator) -> Dictionary:
	var items: Array = [mat(3, 2 + roll.randi() % 2), ItemData.jewel(PIECE, 2), ItemData.jewel("chaos", 2)]
	var r := roll.randf()
	var jackpot := {}
	if r < 0.02:
		jackpot = ItemData.jewel(SkyIsleLoot.EGG)
	elif r < 0.08:
		jackpot = ItemData.jewel(SkyIsleLoot.FRAGMENT, 3)
	if not jackpot.is_empty():
		items.append(jackpot)
	return {"items": items, "jackpot": jackpot}


# --- The world players --------------------------------------------------------------------

## The world player floating a krathong in pier slot `n` ({} for none): {index, name,
## tier, wish, at}. Read off the slot number, the same on every device.
static func ai_float(n: int) -> Dictionary:
	var at := float(n) * FLOAT_SLOT
	if not on(at):
		return {}
	var share := FLOAT_SHARE_NIGHT if night_on(at) else FLOAT_SHARE
	if float(WorldEvents.roll("lkfloat|%d" % n) % 1000) >= share * 1000.0:
		return {}
	var count := WorldPlayers.size()
	if count <= 0:
		return {}
	for tries in 6:
		var i := WorldEvents.roll("lkwho|%d|%d" % [n, tries]) % count
		if WorldPlayers.joined_at(i) > at:
			continue
		# Only someone in the game at that moment walks to the pier.
		if WorldPlayers.session_at(i, at).is_empty():
			continue
		var p := WorldPlayers.progress_at(i, at)
		var tier := clampi(WeeklyCollect.tier_of(int(p.level), int(p.stars)) / 2 + WorldEvents.roll("lktier|%d" % n) % 2, 0, KRATHONGS.size() - 1)
		return {"index": i, "name": String(WorldPlayers.entry(i).name), "tier": tier,
			"wish": String(WISHES[WorldEvents.roll("lkwish|%d" % n) % WISHES.size()]), "at": at}
	return {}


## The world players' krathongs still drifting at t (launched within FLOAT_LIFE), oldest first.
static func ai_floats(t: float) -> Array:
	var out: Array = []
	var last := int(floor(t / FLOAT_SLOT))
	var first := int(floor((t - FLOAT_LIFE) / FLOAT_SLOT))
	for n in range(first, last + 1):
		var e := ai_float(n)
		if not e.is_empty() and float(e.at) <= t and t - float(e.at) < FLOAT_LIFE:
			out.append(e)
	return out


## World player i's latest krathong at the pier at or before t, within OWN_FLOAT_BACK
## ({} for none): what it really floated ({index, name, tier, wish, at} of ai_float).
static func own_float(i: int, t: float) -> Dictionary:
	if not on(t):
		return {}
	var last := int(floor(t / FLOAT_SLOT))
	var first := int(floor(maxf(float(START), t - OWN_FLOAT_BACK) / FLOAT_SLOT))
	for n in range(last, first - 1, -1):
		var e := ai_float(n)
		if not e.is_empty() and int(e.index) == i and float(e.at) <= t:
			return e
	return {}


## A world player's festival line ("" when it has nothing to say): a wish, the pier, the
## moon. What it says it did is what it did (own_float); otherwise a line about nobody.
static func chat_line(s: Dictionary, seed_value: int, t: float) -> String:
	if not on(t) or not s.has("index"):
		return ""
	var pick := absi(hash(seed_value * 13 + 7))
	if night_on(t) and pick % 2 == 0:
		var night := String(CHAT_NIGHT[(pick / 2) % CHAT_NIGHT.size()])
		# The Naga is up only in its windows: a line saying so waits for one.
		if not (night.contains(NAGA_NAME) and naga_now(t).is_empty()):
			return night
	var k := (pick / 2) % CHAT.size()
	var mine: Dictionary = own_float(int(s.index), t) if k in CHAT_OWN else {}
	var hour := WorldEvents.time_of_day(t) / 3600
	if (k in CHAT_OWN and (mine.is_empty() or (k == 6 and int(mine.tier) < 2))) or (k == 3 and hour >= 6 and hour < 18) or (k == 5 and t >= float(RESULT_AT)):
		k = CHAT_PLAIN[pick % CHAT_PLAIN.size()]
	var line := String(CHAT[k])
	if not mine.is_empty():
		line = line.replace("%wish", String(mine.wish)).replace("%name", String(KRATHONGS[int(mine.tier)].name))
	return line


## The answer of a world player asked about the festival.
static func chat_answer(_index: int, t: float) -> String:
	if t < float(START) or not enabled:
		return "%s เริ่ม %s ถึง %s คืนลอยกระทง 24 พ.ย. 19:00-23:00 EXP x2" % [TITLE, date_text(float(START)), date_text(float(END))]
	if not on(t):
		return "%sจบไปแล้ว ปีหน้ามาลอยด้วยกันใหม่นะ" % TITLE
	return "ล่ามอนเก็บใบตอง ดอกบัว เทียนทอง เกล็ดพญานาค ทำกระทงไปลอยที่ท่าน้ำในเมือง วันละ %d ใบ คืน 24 พ.ย. EXP x2 ถึงห้าทุ่ม พญานาคขึ้น 2 ทุ่ม 3 ทุ่ม 4 ทุ่ม" % DAILY_FLOATS


# --- The server's news ------------------------------------------------------------------

## Once a second (Announcer.tick): the opening, the night, each Naga window and the
## pageant's result, once each a run of the game; the hero's pageant prize once out.
static func tick(t: float) -> void:
	if not on(t):
		return
	if not _told_open:
		_told_open = true
		Announcer.show(Announcer.clean("%sเริ่มแล้ว! ล่ามอนเก็บวัสดุ ทำกระทงไปลอยที่ท่าน้ำในเมือง ขอพรได้วันละ %d ใบ" % [TITLE, DAILY_FLOATS]), "rare")
	if night_on(t) and not _told_night:
		_told_night = true
		Announcer.show(Announcer.clean("คืนลอยกระทงมาถึงแล้ว! EXP x2 ถึง 23:00 โคมลอยเต็มฟ้า พญานาคจะขึ้นจากน้ำ 20:00 21:00 22:00"), "rare")
	var naga := naga_now(t)
	if not naga.is_empty() and int(naga.window) != _told_naga:
		_told_naga = int(naga.window)
		Announcer.show(Announcer.clean("%sขึ้นจากน้ำในทุกแผนที่ล่าแล้ว! เหลือ %d นาที" % [NAGA_NAME, maxi(1, int(ceil((float(naga.until) - t) / 60.0)))]), "rare")
	if result_out(t) and not _told_result:
		_told_result = true
		Announcer.show(Announcer.clean(result_text()), "rare")
	if result_out(t):
		settle(t)


static func reset() -> void:
	_told_open = false
	_told_night = false
	_told_result = false
	_told_naga = -1
	_ai_cache.clear()


# --- Saves --------------------------------------------------------------------------------

const _KEYS := ["day", "n", "fl", "pts", "pg", "pgd", "pgg", "got"]


## The record's shape (Game._valid_profile; accounts.js validLoyKrathong keeps the same).
static func valid(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > _KEYS.size():
		return false
	for key in v:
		if not key is String or not _KEYS.has(String(key)):
			return false
		var value: Variant = v[key]
		var lo := -1.0 if String(key) in ["day", "pgd"] else 0.0
		var hi: float = {"day": 100000.0, "pgd": 100000.0, "n": 100.0, "pgg": 1.0, "got": 3.0}.get(String(key), float(MAX_POINTS))
		if not WeeklyCollect._int_ok(value, lo, hi):
			return false
	return true


## Numbers back to ints (JSON reads floats); a broken record goes.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	for key in _KEYS:
		d[key] = int(d.get(key, -1 if key in ["day", "pgd"] else 0))
