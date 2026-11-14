class_name PlayerStall
extends RefCounted
## แผงของฉัน: the hero's own stall, set out from the bag in any zone (fields included;
## not in the guild war, the arena, the tower or a duel: blocked_reason). The hero keeps
## levelling while the AI world players (WorldPlayers) who want a lot come and buy it.
##
## Static and signal-free: everything works on Game.profile["stall"]
##   {"lots": [{"lot": int (stable id), "item": item dict, "price": int, "listed_at": real seconds}],
##    "next": the next lot id, "log": the last LOG_SIZE sales, newest first
##    [{"at", "buyer", "name", "color", "price", "real"}], "tick": real time ticked up to}
## and tells the rest of the game through Game: Game.stall_changed (the lots or the log
## changed; the online code re-publishes stall_list on it), Game.say toasts (the HUD's
## toast), Game.world_chat lines and Game.add_gold (gold_changed).
##
## API (kept stable for the online code):
##   lots() -> Array[Dictionary]                      the lots on the stall now
##   list_item(bag_index, price, count := 0, at := -1.0) -> int   lot id, -1 when refused
##   unlist(lot) -> bool                              back to the bag (storage when full)
##   sell(lot, buyer_name, real := false) -> Dictionary   {item, price}, {} when gone
##   tick(now_seconds, rng := null) -> Array          AI sales made: [{lot, item, price, buyer, at}]
## `at` / `now_seconds` default to WorldPresence.clock(); tests pass their own, and an rng.
##
## AI buyers: Game ticks the stall every few seconds (TICK_EVERY) and on load (the time the
## game was closed, at most CATCH_UP_CAP). Every whole real minute each lot listed for at
## least NOTICE minutes sells with chance sale_odds: BASE_ODDS of its grade (or kind for
## stackables) times the price factor exp(-PRICE_SLOPE * (price / fair - 1)) (half the fair
## price ~3x as fast, three times it ~1/100) times the demand (demand: the AI players
## whose class fits the piece, weighted by how its level suits theirs and whether they are
## online, over DEMAND_REF) times 1 + PLUS_ODDS per +level. A fair rare piece sells in
## ~5-20 minutes, a fair legendary in ~15-40. The buyer is one of those AI players.

## Lots on the stall at once.
const MAX_LOTS := 10
## Sales kept in the log.
const LOG_SIZE := 20
## The price the hero may ask, as a share of the fair price (fair_price).
const PRICE_MIN := 0.5
const PRICE_MAX := 3.0
## Seconds between two of Game's checks (sales happen on whole minutes).
const TICK_EVERY := 5.0
## The longest stretch caught up after the game was closed (real seconds).
const CATCH_UP_CAP := 12.0 * 3600.0
## Minutes a new lot waits before buyers notice it.
const NOTICE := 3
## Chance a fairly priced lot sells in a minute at demand 1, by grade (common..mythic).
const BASE_ODDS := [0.16, 0.12, 0.075, 0.034, 0.02]
## The same for stackables, by kind.
const STACK_ODDS := {"potion": 0.15, "jewel": 0.08, "gem": 0.08}
## How fast the odds fall as the price climbs over the fair price.
const PRICE_SLOPE := 2.3
## A minute's chance never goes over this.
const ODDS_CAP := 0.6
## Interested AI players (weighted) that make demand 1, and the bounds of the demand.
const DEMAND_REF := 1.2
const DEMAND_MIN := 0.2
const DEMAND_MAX := 1.4
## An offline AI player counts this much of an online one (it shops when it logs in).
const OFFLINE_WEIGHT := 0.25
## Gear within [own - LEVEL_BEHIND, own + LEVEL_AHEAD] of a buyer's level (level + stars)
## suits it fully; lower gear (for an alt or a guildmate) BELOW_WEIGHT, higher AHEAD_WEIGHT.
const LEVEL_AHEAD := 5
const LEVEL_BEHIND := 30
const BELOW_WEIGHT := 0.35
const AHEAD_WEIGHT := 0.1
## Each +level of the piece adds this much to the odds.
const PLUS_ODDS := 0.05
## The AI buyers (their levels and who is online) are looked up once per this many seconds.
const POOL_EVERY := 3600.0
## A tick further than this behind is a catch-up: one summary toast, few chat lines.
const CATCH_UP_QUIET := 180.0
const CATCH_UP_CHAT := 3
const CHAT_SPEAKER := "ตลาด"
const CHAT_COLOR := Color("ffd24a")

static var _pool_key := -1
static var _pool: Array = []
static var _rng: RandomNumberGenerator


## The stall's saved state, created (empty) when missing.
static func state() -> Dictionary:
	if not Game.profile.get("stall") is Dictionary:
		Game.profile["stall"] = empty()
	var s: Dictionary = Game.profile["stall"]
	for key in ["lots", "log"]:
		if not s.get(key) is Array:
			s[key] = []
	return s


static func empty() -> Dictionary:
	return {"lots": [], "next": 1, "log": [], "tick": 0.0}


static func _now(t: float) -> float:
	return WorldPresence.clock() if t < 0.0 else t


static func lots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not Game.has_profile:
		return out
	for lot in state().lots:
		out.append(lot)
	return out


## The sales log, newest first.
static func sales() -> Array:
	return state().log if Game.has_profile else []


static func find(lot: int) -> int:
	var all: Array = state().lots
	for i in all.size():
		if int(all[i].lot) == lot:
			return i
	return -1


## Where the hero may not open the stall ("" = anywhere else, fields included).
static func blocked_reason(zone_id: StringName = &"") -> String:
	if zone_id == &"":
		zone_id = Game.current_zone
	var info := ZoneData.get_zone(zone_id)
	if bool(info.get("guildwar", false)):
		return "เปิดแผงไม่ได้ระหว่างสงครามกิลด์"
	if bool(info.get("tower", false)):
		return "เปิดแผงไม่ได้ในหอคอย"
	if bool(info.get("arena", false)):
		return "เปิดแผงไม่ได้ในสนามประลอง"
	if bool(info.get("pvp", false)):
		return "เปิดแผงไม่ได้ระหว่างดวล"
	return ""


# --- Prices -------------------------------------------------------------------------

## What the lot is fairly worth (the suggested price): what a stall keeper would pay for
## it left on consignment (StallStock.consign_price) times the count.
static func fair_price(item: Dictionary) -> int:
	var qty := int(item.get("count", 1)) if ItemData.is_stackable(item) else 1
	return StallStock.consign_price(item) * maxi(1, qty)


static func min_price(item: Dictionary) -> int:
	return maxi(1, int(ceil(float(fair_price(item)) * PRICE_MIN)))


static func max_price(item: Dictionary) -> int:
	return maxi(min_price(item), int(floor(float(fair_price(item)) * PRICE_MAX)))


static func clamp_price(item: Dictionary, price: int) -> int:
	return clampi(price, min_price(item), max_price(item))


# --- Listing ------------------------------------------------------------------------

## Puts bag slot [param bag_index] on the stall for [param price] gold (count of a stack:
## 0 = all of it). Refused (-1, with a toast) when the stall is full, the price is out
## of PRICE_MIN..PRICE_MAX of the fair price or the thing has no worth.
static func list_item(bag_index: int, price: int, count := 0, at := -1.0) -> int:
	if not Game.has_profile or bag_index < 0 or bag_index >= Game.profile.inv.size():
		return -1
	var s := state()
	if s.lots.size() >= MAX_LOTS:
		Game.say("แผงเต็มแล้ว ตั้งขายได้ไม่เกิน %d ชิ้น" % MAX_LOTS, &"warning")
		return -1
	var source: Dictionary = Game.profile.inv[bag_index]
	if LegendWings.is_item(source):
		Game.say(LegendWings.STALL_TEXT, &"warning")
		return -1
	var item: Dictionary = source.duplicate(true)
	var qty := 1
	if ItemData.is_stackable(source):
		var stack := int(source.get("count", 1))
		qty = stack if count <= 0 else clampi(count, 1, stack)
		item["count"] = qty
	if fair_price(item) <= 0:
		Game.say("ของชิ้นนี้ตั้งขายไม่ได้", &"warning")
		return -1
	if price < min_price(item) or price > max_price(item):
		Game.say("ตั้งราคาได้ %s - %s เหรียญ" % [thousands(min_price(item)), thousands(max_price(item))], &"warning")
		return -1
	at = _now(at)
	var id := maxi(1, int(s.get("next", 1)))
	s["next"] = id + 1
	s.lots.append({"lot": id, "item": item, "price": price, "listed_at": at})
	if float(s.get("tick", 0.0)) <= 0.0 or float(s.tick) > at:
		s["tick"] = at
	Game.remove_item_at(bag_index, qty)
	Game.mark_dirty()
	Game.say("ตั้งขาย %s ราคา %s เหรียญแล้ว" % [_label(item), thousands(price)], &"success")
	_changed()
	return id


## Takes a lot off the stall into the bag (into the storage when the bag is full). Kept
## on the stall when both are full: an item is never lost.
static func unlist(lot: int) -> bool:
	if not Game.has_profile:
		return false
	var k := find(lot)
	if k < 0:
		return false
	var entry: Dictionary = state().lots[k]
	if not Game.give_or_store((entry.item as Dictionary).duplicate(true)):
		return false
	state().lots.remove_at(k)
	Game.mark_dirty()
	_changed()
	return true


## Lot [param lot] is sold to [param buyer_name] (an AI world player, or a real player
## online when [param real]): off the stall, its price paid now, logged, told in a toast
## and the world chat. {item, price}, or {} when the lot is already gone.
static func sell(lot: int, buyer_name: String, real := false) -> Dictionary:
	return _sell(lot, buyer_name, real, _now(-1.0), false)


static func _sell(lot: int, buyer_name: String, real: bool, at: float, quiet: bool) -> Dictionary:
	if not Game.has_profile:
		return {}
	var k := find(lot)
	if k < 0:
		return {}
	var s := state()
	var entry: Dictionary = s.lots[k]
	s.lots.remove_at(k)
	var item: Dictionary = entry.item
	var price := int(entry.price)
	Game.add_gold(price)
	Game.daily_progress("stall_sell")
	s.log.push_front({"at": int(at), "buyer": buyer_name, "name": _label(item), "color": ItemData.color_of(item).to_html(false),
		"price": price, "real": real})
	while s.log.size() > LOG_SIZE:
		s.log.pop_back()
	Game.mark_dirty()
	if not quiet:
		Game.world_chat.emit(CHAT_SPEAKER, chat_line(buyer_name, item, price), CHAT_COLOR)
		Game.say("ขายได้! %s ซื้อ %s ราคา %s เหรียญ" % [buyer_name, _label(item), thousands(price)], &"success")
	_changed()
	return {"item": item, "price": price}


## "<buyer> ซื้อ <item> จากแผงของคุณ ราคา 1,200 เหรียญ"
static func chat_line(buyer_name: String, item: Dictionary, price: int) -> String:
	return "%s ซื้อ %s จากแผงของคุณ ราคา %s เหรียญ" % [buyer_name, _label(item), thousands(price)]


static func _label(item: Dictionary) -> String:
	var qty := int(item.get("count", 1)) if ItemData.is_stackable(item) else 1
	return ItemData.name_of(item) + (" ×%d" % qty if qty > 1 else "")


static func _changed() -> void:
	if Game.has_signal("stall_changed"):
		Game.emit_signal("stall_changed")


# --- AI buyers ----------------------------------------------------------------------

## The AI buyers at real time t: [{name, cls (the roster's class), eff (level + stars),
## online}], looked up once per POOL_EVERY.
static func pool(t: float) -> Array:
	var key := int(floor(t / POOL_EVERY))
	if key != _pool_key:
		_pool_key = key
		_pool = []
		var at := float(key) * POOL_EVERY
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, at)
			var level := int(s.level)
			_pool.append({"name": String(s.name), "cls": String(s.job), "online": bool(s.online),
				"eff": level + (int(s.get("stars", 0)) if level >= Game.MAX_LEVEL else 0)})
	return _pool


## Forgets the cached buyers (tests that move the clock).
static func reset_pool() -> void:
	_pool_key = -1
	_pool = []


## How much buyer [param b] wants [param item] (0: not at all; its class must fit).
static func interest(item: Dictionary, b: Dictionary) -> float:
	var locked := ItemData.gear_class(item)
	if locked != "" and locked != String(b.cls):
		return 0.0
	var w := 1.0 if bool(b.online) else OFFLINE_WEIGHT
	if item.get("kind", "") != "equip":
		return w
	var level := int(item.get("level", 1))
	var eff := int(b.eff)
	if level > eff + LEVEL_AHEAD:
		return w * AHEAD_WEIGHT
	if level < eff - LEVEL_BEHIND:
		return w * BELOW_WEIGHT
	return w


static func demand(item: Dictionary, buyers: Array) -> float:
	var total := 0.0
	for b in buyers:
		total += interest(item, b)
	return clampf(total / DEMAND_REF, DEMAND_MIN, DEMAND_MAX)


## Chance a minute that [param item] on the stall for [param price] sells at [param want] demand.
static func sale_odds(item: Dictionary, price: int, want := 1.0) -> float:
	var fair := fair_price(item)
	if fair <= 0 or price <= 0:
		return 0.0
	var base := 0.0
	if ItemData.is_stackable(item):
		base = float(STACK_ODDS.get(String(item.get("kind", "")), 0.08))
	else:
		base = float(BASE_ODDS[clampi(int(item.get("rarity", 0)), 0, BASE_ODDS.size() - 1)])
	var ratio := float(price) / float(fair)
	var p := base * exp(-PRICE_SLOPE * (ratio - 1.0)) * want * (1.0 + PLUS_ODDS * int(item.get("plus", 0)))
	return clampf(p, 0.0, ODDS_CAP)


## How quickly a lot should go, as the stall screen says it.
static func speed_text(item: Dictionary, price: int, want := 1.0) -> String:
	var p := sale_odds(item, price, want)
	if p <= 0.0:
		return "ไม่มีคนสนใจ"
	var minutes := float(NOTICE) + 0.69 / p
	if minutes < 12.0:
		return "ขายเร็ว (~%d นาที)" % int(ceil(minutes))
	if minutes < 45.0:
		return "พอขายได้ (~%d นาที)" % int(ceil(minutes))
	if minutes < 240.0:
		return "ขายช้า (~%d ชม.)" % int(ceil(minutes / 60.0))
	return "แทบไม่มีคนซื้อ"


## One AI buyer for [param item] (weighted by interest): "" when nobody fits its class.
static func pick_buyer(item: Dictionary, buyers: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for b in buyers:
		total += interest(item, b)
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for b in buyers:
		roll -= interest(item, b)
		if roll <= 0.0 and interest(item, b) > 0.0:
			return String(b.name)
	for k in range(buyers.size() - 1, -1, -1):
		if interest(item, buyers[k]) > 0.0:
			return String(buyers[k].name)
	return ""


## Runs the AI buyers up to [param now_seconds]: each whole minute since the last tick
## (at most CATCH_UP_CAP back) every lot noticed by then may sell (sale_odds). The sales
## made, [{lot, item, price, buyer, at}]; a long catch-up is told in one toast.
static func tick(now_seconds: float, rng: RandomNumberGenerator = null) -> Array:
	var done: Array = []
	if not Game.has_profile:
		return done
	if rng == null:
		if _rng == null:
			_rng = RandomNumberGenerator.new()
			_rng.randomize()
		rng = _rng
	var s := state()
	var last := float(s.get("tick", 0.0))
	if s.lots.is_empty() or last <= 0.0 or now_seconds < last:
		# Nothing to sell, a first tick or a clock set back: start counting from now.
		if not is_equal_approx(last, now_seconds):
			s["tick"] = now_seconds
		return done
	var first := int(floor(maxf(last, now_seconds - CATCH_UP_CAP) / 60.0)) + 1
	var final_minute := int(floor(now_seconds / 60.0))
	if final_minute < first:
		return done
	var quiet := now_seconds - last > CATCH_UP_QUIET
	var wants := {}
	for m in range(first, final_minute + 1):
		if s.lots.is_empty():
			break
		var at := float(m) * 60.0
		var buyers := pool(at)
		for entry in s.lots.duplicate():
			if float(entry.listed_at) + float(NOTICE) * 60.0 > at:
				continue
			var key := "%d|%d" % [int(entry.lot), _pool_key]
			if not wants.has(key):
				wants[key] = demand(entry.item, buyers)
			if rng.randf() >= sale_odds(entry.item, int(entry.price), float(wants[key])):
				continue
			var buyer := pick_buyer(entry.item, buyers, rng)
			if buyer == "":
				continue
			var sold := _sell(int(entry.lot), buyer, false, at, quiet)
			if not sold.is_empty():
				done.append({"lot": int(entry.lot), "item": sold.item, "price": int(sold.price), "buyer": buyer, "at": at})
	s["tick"] = now_seconds
	if quiet and not done.is_empty():
		var total := 0
		for sale in done:
			total += int(sale.price)
		for k in mini(CATCH_UP_CHAT, done.size()):
			var sale: Dictionary = done[done.size() - 1 - k]
			Game.world_chat.emit(CHAT_SPEAKER, chat_line(String(sale.buyer), sale.item, int(sale.price)), CHAT_COLOR)
		Game.say("ระหว่างที่คุณไม่อยู่ แผงของคุณขายได้ %d ชิ้น รวม %s เหรียญ" % [done.size(), thousands(total)], &"success")
	return done


# --- Save ---------------------------------------------------------------------------

## A saved stall that may be loaded: lots of valid items (Game._valid_item) and prices.
static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var s: Dictionary = value
	if not s.get("lots", []) is Array or not s.get("log", []) is Array:
		return false
	if (s.get("lots", []) as Array).size() > MAX_LOTS or (s.get("log", []) as Array).size() > LOG_SIZE * 2:
		return false
	if not Game._valid_integer(s.get("next", 1)) or not Game._valid_number(s.get("tick", 0.0)):
		return false
	for lot in s.get("lots", []):
		if not lot is Dictionary or not Game._valid_integer(lot.get("lot"), 1) or not Game._valid_integer(lot.get("price"), 1):
			return false
		if not Game._valid_number(lot.get("listed_at", 0.0)) or not Game._valid_item(lot.get("item")):
			return false
		# A reward-shop costume never goes on a stall (list_item: no worth).
		if ItemData.is_costume(lot.get("item")):
			return false
	for entry in s.get("log", []):
		if not entry is Dictionary or not entry.get("buyer", "") is String or not entry.get("name", "") is String or not entry.get("color", "") is String:
			return false
		if not Game._valid_integer(entry.get("price", 0)) or not Game._valid_number(entry.get("at", 0)):
			return false
	return true


## Restores the types JSON loses (and the shape older saves lack: an empty stall).
static func repair(data: Dictionary) -> void:
	if not data.get("stall") is Dictionary:
		data["stall"] = empty()
		return
	var s: Dictionary = data["stall"]
	if not s.get("lots") is Array:
		s["lots"] = []
	if not s.get("log") is Array:
		s["log"] = []
	s["lots"] = (s.lots as Array).filter(func(lot): return lot is Dictionary and lot.get("item") is Dictionary)
	s["log"] = (s.log as Array).filter(func(entry): return entry is Dictionary)
	var top := 0
	for lot in s.lots:
		lot["lot"] = int(lot.get("lot", 1))
		lot["price"] = int(lot.get("price", 1))
		lot["listed_at"] = float(lot.get("listed_at", 0.0))
		Game._repair_item(lot.item)
		top = maxi(top, int(lot.lot))
	s["next"] = maxi(int(s.get("next", 1)), top + 1)
	s["tick"] = float(s.get("tick", 0.0))
	for entry in s.log:
		entry["at"] = int(entry.get("at", 0))
		entry["price"] = int(entry.get("price", 0))
		entry["real"] = bool(entry.get("real", false))
	while (s.log as Array).size() > LOG_SIZE:
		(s.log as Array).pop_back()


static func thousands(n: int) -> String:
	var text := str(absi(n))
	var out := ""
	while text.length() > 3:
		out = "," + text.right(3) + out
		text = text.left(text.length() - 3)
	return ("-" if n < 0 else "") + text + out
