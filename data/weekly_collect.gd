class_name WeeklyCollect
extends RefCounted
## The weekly rare collection (อีเว้นสะสมของแรร์ประจำสัปดาห์). From 20 Nov 2026 07:40 Thai
## time (START: the moment the x5 festival ends) every week runs from Friday 07:40 to the
## next Friday 07:40 (Thai time, read off WorldPresence.clock(), the same on every device)
## and has its own theme (THEMES, round in a fixed order, week n has THEMES[n % 8]) with
## five rare pieces, from the common one (k = 0) to the legendary one (k = 4).
##
## The pieces are forge-jewel stackables ({kind: "jewel", id: "wk<theme>_<k>", count}:
## ItemData.JEWELS holds the names, colours and prices; their icons are
## assets/icons/ui/jewel_wk<theme>_<k>.svg): they stack, sell, trade, go on a stall and
## into the storage like any jewel. They drop from every monster of every hunting ground
## (zone_ok: not the village, the duels, the guild war, the arena or the tower), at most
## one roll a piece a kill (kill_drops). A piece's chance is its RATE (kills a piece at
## REF_PACE kills a minute) moved by the field's own kill pace (WorldGear.KILLS_*, the
## pace a player really hunts there: pace_of), so an hour of steady hunting finds about
## the same in every field from a newcomer's meadow to the ★300 isle: about 8 common, 4
## second, 2 third, 1 fourth and 0.4 legendary pieces (a full set in about three hours,
## the legendary one a real hunt). Elites roll ELITE times, bosses BOSS, the golden
## monster GOLDEN and the world boss WORLD_BOSS times the chance (fortune adds its share).
## The legendary piece is told to everyone (Announcer.broadcast "jackpot").
##
## The exchange (OPTIONS, the menu's "สะสมของแรร์" tab, WeeklyCollectView) takes pieces of
## the CURRENT week's theme for a reward that grows with the hero's progress (tier_of:
## six bands from a newcomer to ★300; rewards), each a limited number of times a week.
## Pieces of other weeks stay in the bag as collectibles: they sell and trade, and count
## again when their theme comes round (every THEMES.size() weeks); nothing expires.
##
## The hero's record is Game.profile[KEY] = {week, pts, got: [5 counts picked up this
## week], ex: {option id: times exchanged this week}}; it starts over when the week
## changes. Points (POINTS a piece) make the week's top collectors (leaderboard), the hero
## among the AI world players, whose pieces are worked out from their own hunting time
## this week (ai_counts: seeded by name and week, the same on every device). A stall
## keeper sells its spare pieces (stall_lot), the AI chat names the theme (chat_line,
## chat_answer) and the HUD chip counts the week down (chip_text).

const KEY := "wcol"
const NAME := "สะสมของแรร์"
const TITLE := "อีเว้นสะสมของแรร์ประจำสัปดาห์"
const COLOR := Color("ffcf5a")
const DAY := 86400
const WEEK := 7 * DAY
## Week 0 starts here: 20 Nov 2026 07:40 Thai time (Friday), when the x5 festival ends.
const START := 1795135200
const PIECES := 5
## Kills a piece at REF_PACE kills a minute: common .. legendary.
const RATE: Array[int] = [150, 300, 600, 1200, 3000]
const REF_PACE := 20.0
## A kill's chance never goes past this (a boss in a slow field).
const CHANCE_CAP := 0.9
const ELITE := 3.0
const BOSS := 10.0
const GOLDEN := 15.0
const WORLD_BOSS := 20.0
## Points a piece of each rank is worth for the week's top collectors.
const POINTS: Array[int] = [1, 2, 5, 12, 40]
const RANKS: Array[String] = ["ธรรมดา", "หายาก", "ล้ำค่า", "มหัศจรรย์", "ตำนาน"]
const RANK_COLORS: Array[Color] = [Color("9fe8a0"), Color("6fc0ff"), Color("ffd23a"), Color("c46bff"), Color("ff5a7a")]
## A piece's base price (ItemData.JEWELS keeps the same numbers).
const PRICES: Array[int] = [3000, 8000, 20000, 50000, 150000]
## The AI world players: the share of their play time that finds pieces (they hunt in
## parties and on errands), less again for a stall keeper sitting in the village.
const AI_HUNT := 0.25
const AI_STALL_HUNT := 0.2
## An AI player's luck and zeal for the week's pieces (a roll of its name and the week).
const AI_LUCK := Vector2(0.5, 1.5)
## A stall keeper with spare pieces lays one lot of them out this often a restock window.
const STALL_SHARE := 0.45
## The week's top collectors shown.
const TOP := 10
## profile.flags: full sets exchanged in all (the title), and a bit per theme exchanged.
const SETS_FLAG := "wcol_sets"
const THEMES_FLAG := "wcol_themes"

## Theme of week n: THEMES[n % size]. Names of the five pieces, common first.
const THEMES: Array[Dictionary] = [
	{"name": "ราตรีลอยกระทง", "color": Color("ffb03a"), "pieces": ["ดอกดาวเรือง", "เทียนหอมพราย", "กระทงจิ๋วนำโชค", "โคมลอยทองคำ", "จันทร์เพ็ญแก้ว"]},
	{"name": "ราตรีดาวตก", "color": Color("8fa8ff"), "pieces": ["ฝุ่นดาว", "เศษดาวตก", "ผลึกดาวหาง", "หัวใจอุกกาบาต", "ดาวเหนือนิรันดร์"]},
	{"name": "เปลวเพลิงฟีนิกซ์", "color": Color("ff6a3d"), "pieces": ["ขี้เถ้าเพลิง", "ขนนกฟีนิกซ์", "เปลวไฟนิรันดร์", "น้ำตาฟีนิกซ์", "ไข่ฟีนิกซ์ทองคำ"]},
	{"name": "สมบัติใต้สมุทร", "color": Color("5ad8d0"), "pieces": ["เปลือกหอยสังข์", "เกล็ดนางเงือก", "ปะการังเลือด", "ไข่มุกราตรี", "ตรีศูลจ้าวสมุทร"]},
	{"name": "ป่าภูตพราย", "color": Color("8af0a0"), "pieces": ["ใบไม้เรืองแสง", "ปีกผีเสื้อพราย", "น้ำค้างจันทรา", "ดอกบัวแก้ว", "มงกุฎราชินีภูต"]},
	{"name": "อาณาจักรน้ำแข็ง", "color": Color("bfe6ff"), "pieces": ["เกล็ดหิมะคริสตัล", "เขี้ยวหมาป่าน้ำแข็ง", "ผลึกน้ำแข็งพันปี", "หัวใจธารน้ำแข็ง", "มงกุฎราชันหิมะ"]},
	{"name": "สุสานฟาโรห์", "color": Color("ffd23a"), "pieces": ["เหรียญทองโบราณ", "ด้วงสคารับ", "ม้วนปาปิรุส", "ดวงตาเทพสุริยะ", "หน้ากากฟาโรห์ทองคำ"]},
	{"name": "วิหารสายฟ้า", "color": Color("ffe45a"), "pieces": ["ประกายสายฟ้า", "ขนอินทรีพายุ", "ผลึกเมฆฝน", "กลองเทพสายฟ้า", "หัวใจพายุนิรันดร์"]},
]

## The exchange: what each option takes (pieces of the week's theme by rank) and how many
## times a week it may be made. Rewards: rewards(id, tier, cls).
const OPTIONS: Array[Dictionary] = [
	{"id": "set", "name": "หีบสมบัตินักสะสม", "need": [1, 1, 1, 1, 1], "limit": 3},
	{"id": "p4", "name": "กล่องแรร์ทองคำ", "need": [0, 0, 0, 0, 1], "limit": 2},
	{"id": "p3", "name": "ถุงสมบัติมหัศจรรย์", "need": [0, 0, 0, 1, 0], "limit": 4},
	{"id": "p2", "name": "กล่องอัญมณีล้ำค่า", "need": [0, 0, 1, 0, 0], "limit": 6},
	{"id": "p1", "name": "ถุงเพชรหายาก", "need": [0, 2, 0, 0, 0], "limit": 8},
	{"id": "p0", "name": "ถุงเพชรนักสะสม", "need": [3, 0, 0, 0, 0], "limit": 10},
]
## The six progress bands (tier_of) and their names.
const TIER_NAMES: Array[String] = ["มือใหม่ (ต่ำกว่า Lv.40)", "Lv.40-99", "Lv.100 ★0-99", "★100-199", "★200-299", "★300"]

## Tests of the progression maths switch every event off with WorldEvents.festival_enabled;
## this switches only the weekly collection off.
static var enabled := true
## The HUD's drop pop-up listens here: sink(item, info) for a piece the hero picked up.
static var _sinks: Array[Callable] = []
## Per AI player and week: its played minutes at the week's start.
static var _week_minutes := {}
## The other save slots' event records (account_alts), by slot: {stamp, ms, name, recs}.
static var _alts := {}
static var _alts_for := ""
## How often (ms) the other slots' files are looked at again (the boards are read often).
const ALT_CHECK_MS := 2000
## The records account_alts reads from another slot's save (this one, LoyKrathong's and
## DragonHunt's), each repaired the way its own module repairs a save.
const ALT_KEYS: Array[String] = ["wcol", "loyk", "dhunt"]


# --- The week ----------------------------------------------------------------------------

static func on(t: float) -> bool:
	return enabled and WorldEvents.festival_enabled and t >= float(START)


## The week number at t (-1 before the first).
static func week_of(t: float) -> int:
	if t < float(START):
		return -1
	return int(floor((t - float(START)) / float(WEEK)))


static func week_start(week: int) -> float:
	return float(START) + float(week) * float(WEEK)


static func week_end(week: int) -> float:
	return week_start(week + 1)


static func theme_index(week: int) -> int:
	return posmod(week, THEMES.size())


static func theme(week: int) -> Dictionary:
	return THEMES[theme_index(week)]


## The id of piece k of theme `th`.
static func piece_id(th: int, k: int) -> String:
	return "wk%d_%d" % [th, k]


static func piece(th: int, k: int, count := 1) -> Dictionary:
	return ItemData.jewel(piece_id(th, k), count)


## [theme, rank] of a piece id, [-1, -1] for anything else.
static func parse(id: String) -> Vector2i:
	if not id.begins_with("wk") or id.length() != 5 or id[3] != "_":
		return Vector2i(-1, -1)
	var th := id.unicode_at(2) - 48
	var k := id.unicode_at(4) - 48
	if th < 0 or th >= THEMES.size() or k < 0 or k >= PIECES:
		return Vector2i(-1, -1)
	return Vector2i(th, k)


static func is_piece(item: Dictionary) -> bool:
	return String(item.get("kind", "")) == "jewel" and parse(String(item.get("id", ""))).x >= 0


## The rank (0..4) of a piece, -1 for anything else.
static func rank_of(item: Dictionary) -> int:
	return parse(String(item.get("id", ""))).y if is_piece(item) else -1


## The next week (from `week` on) that has theme `th`.
static func next_week_of(th: int, week: int) -> int:
	var n := maxi(week, 0)
	while theme_index(n) != th:
		n += 1
	return n


## "20 พ.ย. 07:40" (Thai time).
static func date_text(t: float) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(t) + WorldPlayers.TZ)
	var months := ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
	return "%d %s %02d:%02d" % [int(d.day), months[int(d.month) - 1], int(d.hour), int(d.minute)]


## "3 วัน 4 ชม." / "5 ชม. 12 นาที" / "8 นาที" left until `until`.
static func left_text(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	var days := s / DAY
	var hours := (s % DAY) / 3600
	var minutes := (s % 3600) / 60
	if days > 0:
		return "%d วัน %d ชม." % [days, hours]
	if hours > 0:
		return "%d ชม. %d นาที" % [hours, minutes]
	return "%d นาที" % maxi(1, minutes)


## The HUD chip's line ("" outside the event).
static func chip_text(t: float) -> String:
	if not on(t):
		return ""
	var w := week_of(t)
	return "%s: %s เหลือ %s" % [NAME, String(theme(w).name), left_text(week_end(w) - t)]


## WorldEvents.current's entry ({} outside the event).
static func event(t: float) -> Dictionary:
	if not on(t):
		return {}
	var w := week_of(t)
	return {"id": "weekly", "name_th": "%s: %s" % [NAME, String(theme(w).name)], "until": week_end(w), "week": w}


# --- Drops -------------------------------------------------------------------------------

## Where pieces drop: every hunting ground with monsters, not the village, the duels,
## the guild war, the arena or the tower.
static func zone_ok(zone: Dictionary) -> bool:
	if zone.is_empty() or bool(zone.get("safe", false)):
		return false
	for key in ["pvp", "guildwar", "arena", "tower"]:
		if bool(zone.get(key, false)):
			return false
	return String(zone.get("scene", "field")) != "town"


## Kills a minute a player really makes in `zone` (WorldGear.kills_per_minute of the
## field's own band: its top level, or its stars).
static func pace_of(zone: Dictionary) -> float:
	var stars := int(zone.get("star", 0))
	if stars > 0 or bool(zone.get("star_region", false)) or bool(zone.get("divine_region", false)):
		return WorldGear.kills_per_minute(Game.MAX_LEVEL, maxi(stars, 1))
	var band: Variant = zone.get("level", [1, 1])
	var top := int(band[1]) if band is Array and (band as Array).size() >= 2 else 1
	return WorldGear.kills_per_minute(clampi(top, 1, Game.MAX_LEVEL - 1), 0)


## Chance of piece k in one kill in `zone`: RATE at REF_PACE, moved by the field's pace,
## times `mult` (elite, boss ...) and (1 + fortune), capped.
static func chance(k: int, zone: Dictionary, mult := 1.0, fortune := 0.0) -> float:
	var pace := maxf(0.5, pace_of(zone))
	return minf(CHANCE_CAP, (REF_PACE / pace) / float(RATE[k]) * mult * (1.0 + maxf(fortune, 0.0)))


## The roll multiplier of a kill: "elite", "boss", "golden", "world_boss" or "" (a plain one).
static func mult_of(kind: String) -> float:
	return {"elite": ELITE, "boss": BOSS, "golden": GOLDEN, "world_boss": WORLD_BOSS}.get(kind, 1.0)


## The pieces one kill drops at t (a roll a piece, on `roll`); [] outside the event or
## the hunting grounds.
static func kill_drops(zone: Dictionary, kind: String, fortune: float, t: float, roll: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not on(t) or not zone_ok(zone):
		return out
	var th := theme_index(week_of(t))
	var mult := mult_of(kind)
	for k in PIECES:
		if roll.randf() < chance(k, zone, mult, fortune):
			out.append(piece(th, k))
	return out


## The server-wide line of a legendary piece (Announcer.broadcast "jackpot").
static func jackpot_text(who: String, item: Dictionary) -> String:
	var at := parse(String(item.get("id", "")))
	var th := String(THEMES[maxi(at.x, 0)].name)
	return "%s ได้ %s ของแรร์ระดับตำนาน ธีม%s!" % [who, ItemData.name_of(item), th]


## Pieces an hour of steady hunting finds in `zone` (tests, the panel's help).
static func per_hour(k: int, zone: Dictionary) -> float:
	return chance(k, zone) * pace_of(zone) * 60.0


# --- The hero's record -------------------------------------------------------------------

static func data(t := -1.0) -> Dictionary:
	if not Game.has_profile:
		return {}
	if t < 0.0:
		t = WorldPresence.clock()
	var w := week_of(t)
	var d: Variant = Game.profile.get(KEY)
	if not d is Dictionary or int((d as Dictionary).get("week", -2)) != w:
		d = {"week": w, "pts": 0, "got": [0, 0, 0, 0, 0], "ex": {}}
		Game.profile[KEY] = d
	return d


static func points(t := -1.0) -> int:
	return int(data(t).get("pts", 0))


## A piece the hero picked up (LootDrop): its points for the week (a piece of the week's
## theme only) and the drop pop-up.
static func picked(item: Dictionary) -> void:
	if not Game.has_profile or not is_piece(item):
		return
	var t := WorldPresence.clock()
	var at := parse(String(item.id))
	var count := int(item.get("count", 1))
	if on(t) and at.x == theme_index(week_of(t)):
		var d := data(t)
		d["pts"] = int(d.get("pts", 0)) + POINTS[at.y] * count
		var got: Array = d.get("got", [0, 0, 0, 0, 0])
		got[at.y] = int(got[at.y]) + count
		d["got"] = got
		Game.mark_dirty()
	var info := {"rank": at.y, "have": owned(at.x, at.y), "kinds": kinds_owned(at.x), "theme": String(THEMES[at.x].name)}
	for sink in _sinks.duplicate():
		if sink.is_valid():
			sink.call(item, info)
		else:
			_sinks.erase(sink)


static func listen(sink: Callable) -> void:
	if not _sinks.has(sink):
		_sinks.append(sink)


static func unlisten(sink: Callable) -> void:
	_sinks.erase(sink)


## How many of piece k of theme `th` the hero carries (the bag).
static func owned(th: int, k: int) -> int:
	return Game.jewel_count(piece_id(th, k)) if Game.has_profile else 0


## How many of the five ranks of theme `th` the hero carries at least one of.
static func kinds_owned(th: int) -> int:
	var n := 0
	for k in PIECES:
		if owned(th, k) > 0:
			n += 1
	return n


static func option(id: String) -> Dictionary:
	for e in OPTIONS:
		if String(e.id) == id:
			return e
	return {}


static func used(id: String, t := -1.0) -> int:
	return int((data(t).get("ex", {}) as Dictionary).get(id, 0))


## The hero's progress band: 0 below Lv.40, 1 to Lv.99, 2 Lv.100 ★0-99, 3 ★100-199,
## 4 ★200-299, 5 ★300.
static func tier_of(level: int, stars: int) -> int:
	if level < 40:
		return 0
	if level < Game.MAX_LEVEL:
		return 1
	if stars >= JobData.GOD_STARS:
		return 5
	return 2 + clampi(stars / 100, 0, 2)


static func hero_tier() -> int:
	if not Game.has_profile:
		return 0
	return tier_of(int(Game.profile.get("level", 1)), int((Game.profile.get("paragon", {}) as Dictionary).get("level", 0)))


## What option `id` gives a hero of band `tier` and class `cls`: {gold, items}.
static func rewards(id: String, tier: int, cls: String) -> Dictionary:
	tier = clampi(tier, 0, TIER_NAMES.size() - 1)
	var plan := WorldGear.gem_plan(cls if ClassData.IDS.has(StringName(cls)) else "warrior")
	var main := String(plan.main)
	var special := String(plan.special)
	var items: Array = []
	var gold := 0
	match id:
		"set":
			gold = [30000, 120000, 400000, 1000000, 2500000, 5000000][tier]
			items.append(ItemData.jewel("pink", [5, 8, 12, 15, 20, 25][tier]))
			items.append(ItemData.jewel("chaos", [2, 4, 8, 12, 16, 20][tier]))
			items.append(ItemData.gem(main, [1, 2, 3, 3, 4, 4][tier]))
			items.append(ItemData.gem(special, [0, 1, 2, 2, 3, 3][tier]))
			items.append(ItemData.jewel("drill", [1, 1, 2, 2, 3, 3][tier]))
			if tier >= 2:
				items.append(ItemData.jewel("feather", [0, 0, 1, 2, 2, 3][tier]))
			if tier >= 4:
				items.append(ItemData.jewel("set_core", 1 if tier == 4 else 2))
				items.append(ItemData.jewel("lotus_scale", 2))
			if tier >= 5:
				items.append(ItemData.jewel("dragon_fragment", 3))
		"p4":
			gold = [10000, 40000, 150000, 400000, 1000000, 2000000][tier]
			items.append(ItemData.jewel("chaos", [1, 2, 4, 6, 8, 10][tier]))
			items.append(ItemData.gem(special, [0, 1, 1, 2, 2, 3][tier]))
			if tier == 4:
				items.append(ItemData.jewel("set_core", 1))
			if tier >= 5:
				items.append(ItemData.jewel("dragon_fragment", 2))
		"p3":
			items.append(ItemData.jewel("pink", [2, 3, 4, 5, 6, 8][tier]))
			items.append(ItemData.jewel("chaos", [1, 1, 2, 3, 4, 5][tier]))
			if tier >= 2:
				items.append(ItemData.jewel("drill", 1))
			if tier >= 3:
				items.append(ItemData.jewel("feather", 1))
		"p2":
			items.append(ItemData.gem(main, [0, 1, 2, 2, 3, 3][tier]))
			items.append(ItemData.jewel("purple", [3, 5, 8, 10, 12, 15][tier]))
		"p1":
			items.append(ItemData.jewel("chaos", [1, 1, 1, 2, 2, 3][tier]))
			items.append(ItemData.jewel("purple", [2, 3, 4, 5, 6, 8][tier]))
		"p0":
			gold = [2000, 8000, 30000, 80000, 200000, 400000][tier]
			items.append(ItemData.jewel("purple", [3, 4, 6, 8, 10, 12][tier]))
			items.append(ItemData.jewel("pink", [1, 1, 2, 2, 3, 4][tier]))
	return {"gold": gold, "items": items}


## "ทอง 120,000 · เพชรชมพู ×8 · ..." for a reward.
static func reward_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(r.get("gold", 0)) > 0:
		parts.append("ทอง %s" % PlayerStall.thousands(int(r.gold)))
	for item in r.get("items", []):
		parts.append("%s ×%d" % [ItemData.name_of(item), int(item.get("count", 1))])
	return " · ".join(parts)


## Why option `id` cannot be made now ("" when it can).
static func problem(id: String, t := -1.0) -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if t < 0.0:
		t = WorldPresence.clock()
	if not on(t):
		return "อีเว้นยังไม่เริ่ม (เริ่ม %s)" % date_text(float(START))
	var e := option(id)
	if e.is_empty():
		return "ไม่มีรายการนี้"
	if used(id, t) >= int(e.limit):
		return "แลกครบ %d ครั้งของสัปดาห์นี้แล้ว" % int(e.limit)
	var th := theme_index(week_of(t))
	var need: Array = e.need
	for k in PIECES:
		if owned(th, k) < int(need[k]):
			return "%sไม่พอ (มี %d/%d)" % [String(THEMES[th].pieces[k]), owned(th, k), int(need[k])]
	var r := rewards(id, hero_tier(), String(Game.class_id()))
	var new_stacks := 0
	for item in r.items:
		if not Game.profile.inv.any(func(x): return String(x.get("kind", "")) == String(item.kind) and String(x.get("id", "")) == String(item.id)):
			new_stacks += 1
	# Stacks the exchange empties make room too.
	var freed := 0
	for k in PIECES:
		if int(need[k]) > 0 and owned(th, k) == int(need[k]):
			freed += 1
	if Game.inventory_free() + freed < new_stacks:
		return "กระเป๋าไม่พอ (ต้องว่าง %d ช่อง)" % new_stacks
	return ""


## Makes option `id`: takes its pieces of the week's theme, gives the reward (gold to the
## purse, items to the bag) and counts it against the week's limit. "ok" or the problem.
static func exchange(id: String, t := -1.0) -> String:
	if t < 0.0:
		t = WorldPresence.clock()
	var why := problem(id, t)
	if why != "":
		return why
	var e := option(id)
	var th := theme_index(week_of(t))
	var need: Array = e.need
	for k in PIECES:
		if int(need[k]) > 0:
			Game._spend_jewels(piece_id(th, k), int(need[k]))
	var d := data(t)
	var ex: Dictionary = d.get("ex", {})
	ex[id] = int(ex.get(id, 0)) + 1
	d["ex"] = ex
	var r := rewards(id, hero_tier(), String(Game.class_id()))
	if int(r.gold) > 0:
		Game.add_gold(int(r.gold))
	for item in r.items:
		Game.give_or_store((item as Dictionary).duplicate())
	if id == "set":
		Game.profile.flags[SETS_FLAG] = int(Game.profile.flags.get(SETS_FLAG, 0)) + 1
		Game.profile.flags[THEMES_FLAG] = int(Game.profile.flags.get(THEMES_FLAG, 0)) | (1 << th)
		Game.check_achievements()
	Game.inventory_changed.emit()
	Game.mark_dirty()
	return "ok"


## The hero's pieces of themes other than this week's: [{item, back (the week its theme
## comes again)}].
static func other_pieces(t := -1.0) -> Array:
	if t < 0.0:
		t = WorldPresence.clock()
	var out: Array = []
	if not Game.has_profile:
		return out
	var w := maxi(week_of(t), 0)
	var now_th := theme_index(w) if week_of(t) >= 0 else -1
	for item in Game.profile.inv:
		if is_piece(item):
			var at := parse(String(item.id))
			if at.x != now_th:
				out.append({"item": item, "back": next_week_of(at.x, w + (1 if at.x == theme_index(w) else 0))})
	return out


# --- Saves -------------------------------------------------------------------------------

## The record's shape (Game._valid_profile; accounts.js validWeeklyCollect keeps the same).
static func valid(v: Variant) -> bool:
	if not v is Dictionary or (v as Dictionary).size() > 8:
		return false
	for key in v:
		if not key is String:
			return false
		var value: Variant = v[key]
		match String(key):
			"week":
				if not _int_ok(value, -1.0, 100000.0):
					return false
			"pts":
				if not _int_ok(value, 0.0, 1000000000.0):
					return false
			"got":
				if not value is Array or (value as Array).size() != PIECES:
					return false
				for n in value:
					if not _int_ok(n, 0.0, 1000000.0):
						return false
			"ex":
				if not value is Dictionary or (value as Dictionary).size() > 16:
					return false
				for id in value:
					if not id is String or String(id).length() > 16 or not _int_ok(value[id], 0.0, 1000.0):
						return false
			_:
				return false
	return true


static func _int_ok(v: Variant, lo: float, hi: float) -> bool:
	if not (v is int or v is float):
		return false
	var f := float(v)
	return f == floor(f) and f >= lo and f <= hi


## Numbers back to ints (JSON reads floats); unknown options dropped; a broken record goes.
static func repair(profile: Dictionary) -> void:
	if not profile.has(KEY):
		return
	if not valid(profile[KEY]):
		profile.erase(KEY)
		return
	var d: Dictionary = profile[KEY]
	d["week"] = int(d.get("week", -1))
	d["pts"] = int(d.get("pts", 0))
	var got: Array = []
	for n in d.get("got", [0, 0, 0, 0, 0]):
		got.append(int(n))
	d["got"] = got
	var ex := {}
	var raw: Dictionary = d.get("ex", {})
	for id in raw:
		if not option(String(id)).is_empty():
			ex[String(id)] = int(raw[id])
	d["ex"] = ex


# --- The AI world players ----------------------------------------------------------------

## A well-mixed 0..1 for `key`, the same on every device.
static func _u(key: String) -> float:
	return float(WorldEvents.roll(key) % 1000003) / 1000003.0


## Pieces AI player i picked up this week by t, [c0..c4] (zeros outside the event): its
## real minutes played since the week began (WorldPlayers.played_minutes) times the share
## that hunts (AI_HUNT, AI_STALL_HUNT for a stall keeper; its luck AI_LUCK) at the pace-free hourly rate,
## rounded by a roll of its name and the week, so it only ever grows.
static func ai_counts(i: int, t: float) -> Array:
	var out := [0, 0, 0, 0, 0]
	if not on(t):
		return out
	var w := week_of(t)
	var from := maxf(week_start(w), WorldPlayers.joined_at(i))
	if t <= from:
		return out
	var name := String(WorldPlayers.entry(i).name)
	var key := "%s|%d" % [name, w]
	var base: Variant = _week_minutes.get(key)
	if base == null:
		if _week_minutes.size() > 4000:
			_week_minutes.clear()
		base = WorldPlayers.played_minutes(i, from)
		_week_minutes[key] = base
	var minutes := maxf(0.0, WorldPlayers.played_minutes(i, t) - float(base))
	# Its luck and zeal this week (AI_LUCK): some players chase the pieces harder.
	var luck := AI_LUCK.x + (AI_LUCK.y - AI_LUCK.x) * _u("wluck|%s" % key)
	var hunt := minutes * AI_HUNT * luck * (AI_STALL_HUNT if WorldPlayers.in_town_style(i) else 1.0)
	for k in PIECES:
		var expect := hunt * REF_PACE / float(RATE[k])
		out[k] = int(floor(expect + _u("wcol|%s|%d" % [key, k])))
	return out


static func points_of(counts: Array) -> int:
	var total := 0
	for k in mini(counts.size(), PIECES):
		total += int(counts[k]) * POINTS[k]
	return total


## The week's top collectors at t: [{name, pts, hero, index, mine?, slot?}] best first
## (TOP of them), the hero among the AI players by its points. Every character of the
## account collects (account_rows): the one played (`hero`) and the others, not played now,
## by the points in their own saves under their own names (`mine`, `slot`), each once.
static func leaderboard(t: float, top := TOP) -> Array:
	var rows: Array = []
	if not on(t):
		return rows
	for i in WorldPlayers.size():
		if WorldPlayers.joined_at(i) > t:
			continue
		var pts := points_of(ai_counts(i, t))
		if pts > 0:
			rows.append({"name": String(WorldPlayers.entry(i).name), "pts": pts, "hero": false, "index": i})
	rows.append_array(account_rows(t))
	rows.sort_custom(func(a, b): return int(a.pts) > int(b.pts) if int(a.pts) != int(b.pts) else (bool(a.hero) and not bool(b.hero)) if bool(a.hero) != bool(b.hero) else String(a.name) < String(b.name))
	return rows.slice(0, top)


## The account's characters on the week's board at t: the one played (always, `hero`)
## and every other save slot with points this week (read from its file).
static func account_rows(t: float) -> Array:
	var rows: Array = []
	if not on(t):
		return rows
	if Game.has_profile:
		rows.append({"name": String(Game.profile.get("name", "")), "pts": points(t), "hero": true, "mine": true, "slot": Game.slot, "index": -1})
	var w := week_of(t)
	for a in account_alts(KEY):
		var d: Dictionary = a.rec
		if int(d.get("week", -2)) == w and int(d.get("pts", 0)) > 0:
			rows.append({"name": String(a.name), "pts": int(d.pts), "hero": false, "mine": true, "slot": int(a.slot), "index": -1})
	return rows


## The hero's place among everyone this week (1 = top), 0 without a profile: the world
## players and the account's other characters with more points are before it.
static func hero_rank(t: float) -> int:
	if not Game.has_profile or not on(t):
		return 0
	var mine := points(t)
	var rank := 1
	for i in WorldPlayers.size():
		if WorldPlayers.joined_at(i) <= t and points_of(ai_counts(i, t)) > mine:
			rank += 1
	for r in account_rows(t):
		if not bool(r.hero) and int(r.pts) > mine:
			rank += 1
	return rank


# --- The account's other characters ------------------------------------------------------

## The account's other characters (the save slots not played now) holding a record under
## `key` (one of ALT_KEYS): [{slot, name, rec}], by slot. Their files are read once per
## change (Game._slot_stamp), looked at every ALT_CHECK_MS at most, and all again once the
## character played changes; a damaged or empty slot has none. The event boards
## (WeeklyCollect, LoyKrathong, DragonHunt) list them under their own names, so a
## character not played keeps its points and its place on them.
static func account_alts(key: String) -> Array:
	var out: Array = []
	for i in range(1, Game.SLOT_COUNT + 1):
		if Game.has_profile and i == Game.slot:
			continue
		var a := _alt(i)
		if a.is_empty():
			continue
		var rec: Variant = (a.recs as Dictionary).get(key)
		if rec is Dictionary:
			out.append({"slot": i, "name": String(a.name), "rec": rec})
	return out


## Forgets what was read of the other slots (tests; a save written in the same second
## with the same size keeps its stamp).
static func reset_alts() -> void:
	_alts.clear()
	_alts_for = ""


static func _alt(i: int) -> Dictionary:
	var who := "%d|%s" % [Game.slot, Game.has_profile]
	if who != _alts_for:
		_alts_for = who
		_alts.clear()
	var ms := Time.get_ticks_msec()
	var kept: Variant = _alts.get(i)
	if kept is Dictionary and ms - int(kept.ms) < ALT_CHECK_MS:
		return kept.alt
	var stamp: String = Game._slot_stamp(i)
	if stamp == "":
		_alts[i] = {"stamp": "", "alt": {}, "ms": ms}
		return {}
	if kept is Dictionary and String(kept.stamp) == stamp:
		kept.ms = ms
		return kept.alt
	var raw: Dictionary = Game._read_slot(i)
	var alt := {}
	if not raw.is_empty():
		var holder := {}
		for key in ALT_KEYS:
			if raw.get(key) is Dictionary:
				holder[key] = (raw[key] as Dictionary).duplicate(true)
		repair(holder)
		LoyKrathong.repair(holder)
		DragonHunt.repair(holder)
		alt = {"name": String(raw.get("name", "")), "recs": holder}
	_alts[i] = {"stamp": stamp, "alt": alt, "ms": ms}
	return alt


## A stall keeper's lot of spare pieces in the window starting at `at` ({} for none):
## only pieces it found itself this week (ai_counts), keeping one of each for its own
## set; `key` seeds the pick (the keeper and the window).
static func stall_lot(i: int, at: float, key: String) -> Dictionary:
	if not on(at):
		return {}
	var counts := ai_counts(i, at)
	var spare: Array = []
	var total := 0
	for k in PIECES:
		var s := maxi(0, int(counts[k]) - 1)
		spare.append(s)
		total += s
	if total <= 0 or _u("wstall|%s" % key) >= STALL_SHARE:
		return {}
	var r := int(floor(_u("wstallk|%s" % key) * float(total)))
	var k := 0
	while k < PIECES - 1 and r >= int(spare[k]):
		r -= int(spare[k])
		k += 1
	var n := 1 + int(floor(_u("wstalln|%s" % key) * float(mini(3, int(spare[k])))))
	return piece(theme_index(week_of(at)), k, n)


## A line of AI player `s` (WorldPlayers.state) about the week's collection, "" when it
## has nothing true to say: the theme and the pieces it really found this week.
static func chat_line(s: Dictionary, seed_value: int, t: float) -> String:
	if not on(t) or not s.has("index"):
		return ""
	var th := theme(week_of(t))
	var counts := ai_counts(int(s.index), t)
	var best := -1
	for k in PIECES:
		if int(counts[k]) > 0:
			best = k
	var pick := absi(hash(seed_value * 17 + 3))
	if best < 0:
		return ["สัปดาห์นี้อีเว้น%s ธีม%s ยังเก็บไม่ได้สักอันเลย" % [NAME, String(th.name)],
			"ธีม%s สัปดาห์นี้ ใครเก็บ%sได้บ้าง" % [String(th.name), String(th.pieces[PIECES - 1])]][pick % 2]
	var lines := [
		"สัปดาห์นี้ธีม%s เก็บ%sแล้ว %d อัน" % [String(th.name), String(th.pieces[0]), int(counts[0])],
		"อีเว้น%s ธีม%s ลุ้น%sอยู่ ใครมีบ้าง" % [NAME, String(th.name), String(th.pieces[PIECES - 1])],
	]
	if best >= 2:
		lines.append("เย้ เก็บ%sมาแล้ว ธีม%sสัปดาห์นี้" % [String(th.pieces[best]), String(th.name)])
	if best == PIECES - 1:
		lines.append("ในที่สุด! %sมาแล้ว ครบชุดธีม%sแน่" % [String(th.pieces[best]), String(th.name)])
	return String(lines[pick % lines.size()])


## The answer of AI player `index` asked about the event ("" outside it).
static func chat_answer(index: int, t: float) -> String:
	if not on(t):
		return "อีเว้น%sเริ่ม %s ทุกสัปดาห์ธีมใหม่" % [NAME, date_text(float(START))]
	var w := week_of(t)
	var th := theme(w)
	var counts := ai_counts(index, t) if index >= 0 else [0, 0, 0, 0, 0]
	var kinds := 0
	for k in PIECES:
		if int(counts[k]) > 0:
			kinds += 1
	return "สัปดาห์นี้ธีม%s มี %d แบบ เก็บได้ %d แบบแล้ว แลกที่เมนู%s รีเซ็ตอีก %s" % [String(th.name), PIECES, kinds, NAME, left_text(week_end(w) - t)]
