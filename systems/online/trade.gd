class_name OnlineTrade
extends Node
## Trading with a real player (docs/ONLINE_PROTOCOL.md, trade_* frames). Lives beside the
## HUD for the whole session and does nothing while Online is offline.
##
## A `trade_req` asks the hero (OnlineAsk, Thai) and answers `trade_answer`; an accepted
## request on either side opens the trade (TradeScreen). Both sides fill an offer from the
## bag (gear whole, a stack with a count) plus gold; every change is sent as `trade_offer`
## and unlocks both sides. "ล็อก" sends `trade_lock`; when both are locked "ยืนยัน" sends
## `trade_confirm`; the server then sends `trade_done {give, get}`, applied here at once:
## `give` must still be in the bag (else the trade is aborted with `trade_cancel` and
## nothing changes), it leaves the bag, `get` comes in (a full bag spills into the shared
## storage, past its room if it must: nothing is ever lost), the gold moves and the game is
## saved. Closing the window, changing zone, the partner leaving or the connection dropping
## cancels a trade still open. A partner that aborts a trade we already applied (its own
## `give` went missing) is undone within UNDO_SECONDS when what we got is still here.

signal opened(partner: String)
## The offers, locks or confirmations changed.
signal changed
signal closed(reason: String)

## Seconds the hero has to answer a request before it is declined.
const ASK_SECONDS := 20.0
## Entries in one offer (a frame is at most 8 KB; a piece of gear is up to ~600 bytes).
const MAX_OFFER := 8
## How long after a done trade the partner's abort still undoes it.
const UNDO_SECONDS := 15.0
const LOG_COLOR := Color("8ff0ff")
const LOG_SPEAKER := "ระบบ"
## Item kinds that can change hands; anything else (and anything marked bound / quest)
## stays with its owner. Gear of another class trades: that is what drops of other
## classes are for.
## A reward-shop costume ("costume") is not among them: it moves through the storage only.
const TRADE_KINDS := ["equip", "potion", "jewel", "gem"]

## The other player's id while a trade is open ("" = none).
var partner := ""
## My offer: item dicts (stackables carry the offered "count").
var mine: Array = []
var my_gold := 0
## Their offer, checked (Game._valid_item) and repaired.
var theirs: Array = []
var their_gold := 0
## Their offer held something not allowed (bad data): confirming is blocked.
var their_bad := false
var my_lock := false
var their_lock := false
var my_confirm := false
var their_confirm := false
## A request waiting for the hero's answer (the asker's id, "" = none).
var asking := ""
## Answers busy requests with false while this returns true (the duel sets it).
var busy_check := Callable()

var _zone: StringName = &""
## True while a done trade is being applied (its own bag changes are not offer changes).
var _applying := false
var _ask_card: Control
var _last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Online.message.connect(_on_message)
	Online.disconnected.connect(func(): _close("disconnect", false))
	Online.player_left.connect(func(id: String):
		if id == partner:
			Game.say("%s ออกจากเกม — ยกเลิกการแลกเปลี่ยน" % player_name(id), &"warning")
			_close("left", false)
		elif id == asking:
			_drop_ask())
	Game.inventory_changed.connect(_prune_offer)
	Game.gold_changed.connect(func(_g): _prune_offer())


func _process(_delta: float) -> void:
	if partner != "" and Game.current_zone != _zone:
		Game.say("เปลี่ยนพื้นที่ — ยกเลิกการแลกเปลี่ยน", &"warning")
		cancel()


func is_open() -> bool:
	return partner != ""


static func player_name(id: String) -> String:
	var p: Dictionary = Online.players().get(id, {})
	var n := String(p.get("name", ""))
	if n == "":
		n = String(p.get("user", ""))
	return n if n != "" else "ผู้เล่น"


## Whether [param item] may change hands at all.
static func tradable(item: Dictionary) -> bool:
	if not String(item.get("kind", "")) in TRADE_KINDS:
		return false
	# The Legendary Guild Wings stay with the account (the shared storage moves them).
	if LegendWings.is_item(item):
		return false
	for key in ["bound", "quest", "no_trade"]:
		if bool(item.get(key, false)):
			return false
	return true


## Asks [param id] to trade (the online player list does the same).
func request(id: String) -> void:
	if not Online.is_online() or partner != "" or id == "":
		return
	Online.send("trade_req", {"to": id})
	Game.say("ส่งคำขอแลกเปลี่ยนถึง %s แล้ว" % player_name(id), &"info")


# ---------------------------------------------------------------------------
# Frames
# ---------------------------------------------------------------------------

func _on_message(type: String, data: Dictionary) -> void:
	var from := String(data.get("from", ""))
	match type:
		"trade_req":
			_on_request(from)
		"trade_answer":
			if bool(data.get("ok", false)):
				if partner == "" and Game.has_profile:
					_open(from)
			else:
				Game.say("%s ไม่รับการแลกเปลี่ยน" % player_name(from), &"warning")
		"trade_offer":
			if from == partner:
				_take_offer(data)
		"trade_lock":
			if from == partner:
				their_lock = true
				changed.emit()
		"trade_confirm":
			if from == partner:
				their_confirm = true
				changed.emit()
		"trade_cancel":
			if from == partner and partner != "":
				Game.say("%s ยกเลิกการแลกเปลี่ยน" % player_name(from), &"warning")
				_close("cancel", false)
			elif from == asking:
				_drop_ask()
			elif not _last.is_empty() and from == String(_last.partner):
				_undo_last()
		"trade_done":
			_apply_done(data)


func _on_request(from: String) -> void:
	if from == "" or not Game.has_profile:
		return
	if partner != "" or asking != "" or (busy_check.is_valid() and bool(busy_check.call())):
		Online.send("trade_answer", {"from": from, "ok": false})
		return
	asking = from
	var ask := OnlineAsk.find_or_make(self)
	_ask_card = ask.ask("%s ขอแลกเปลี่ยนของกับคุณ" % player_name(from), "แลกเปลี่ยน", "ปฏิเสธ", ASK_SECONDS, answer)


## The hero's answer to the request waiting (the prompt's buttons, or a timeout).
func answer(ok: bool) -> void:
	if asking == "":
		return
	var from := asking
	_drop_ask()
	Online.send("trade_answer", {"from": from, "ok": ok and partner == ""})
	if ok and partner == "":
		_open(from)


func _drop_ask() -> void:
	asking = ""
	OnlineAsk.withdraw(_ask_card)
	_ask_card = null


func _open(id: String) -> void:
	partner = id
	_zone = Game.current_zone
	mine.clear()
	theirs.clear()
	my_gold = 0
	their_gold = 0
	their_bad = false
	_unlock()
	opened.emit(id)
	changed.emit()


func _unlock() -> void:
	my_lock = false
	their_lock = false
	my_confirm = false
	their_confirm = false


func _take_offer(data: Dictionary) -> void:
	theirs.clear()
	their_bad = false
	var list: Variant = data.get("items", [])
	if list is Array:
		for raw in list:
			if theirs.size() >= MAX_OFFER:
				their_bad = true
				break
			if not Game._valid_item(raw) or not tradable(raw):
				their_bad = true
				continue
			var item: Dictionary = (raw as Dictionary).duplicate(true)
			Game._repair_item(item)
			theirs.append(item)
	else:
		their_bad = true
	var gold: Variant = data.get("gold", 0)
	their_gold = maxi(0, int(gold)) if (gold is int or gold is float) else 0
	_unlock()
	changed.emit()


# ---------------------------------------------------------------------------
# My side
# ---------------------------------------------------------------------------

## How many of a bag entry's kind are still free to offer (a stack's count, gear 1/0).
func free_count(item: Dictionary) -> int:
	if ItemData.is_stackable(item):
		return maxi(0, _bag_count(item) - _offered_count(item))
	return 0 if _offered(item) >= 0 else 1


## Offers [param count] of the bag entry at [param index] (a stack) or the piece of gear.
func offer(index: int, count := 1) -> bool:
	if partner == "" or index < 0 or index >= Game.profile.inv.size():
		return false
	var item: Dictionary = Game.profile.inv[index]
	if not tradable(item):
		Game.say(LegendWings.TRADE_TEXT if LegendWings.is_item(item) else "ของชิ้นนี้แลกเปลี่ยนไม่ได้", &"warning")
		return false
	if ItemData.is_stackable(item):
		var n := mini(count, free_count(item))
		if n <= 0:
			return false
		var at := _offered(item)
		if at >= 0:
			mine[at]["count"] = int(mine[at].count) + n
		else:
			if mine.size() >= MAX_OFFER:
				Game.say("เสนอได้ครั้งละไม่เกิน %d ชิ้น" % MAX_OFFER, &"warning")
				return false
			var lot := item.duplicate(true)
			lot["count"] = n
			mine.append(lot)
	else:
		if _offered(item) >= 0:
			return false
		if mine.size() >= MAX_OFFER:
			Game.say("เสนอได้ครั้งละไม่เกิน %d ชิ้น" % MAX_OFFER, &"warning")
			return false
		mine.append(item.duplicate(true))
	_send_offer()
	return true


## Takes entry [param i] of my offer back.
func take_back(i: int) -> void:
	if partner == "" or i < 0 or i >= mine.size():
		return
	mine.remove_at(i)
	_send_offer()


func set_gold(amount: int) -> void:
	if partner == "":
		return
	var gold := clampi(amount, 0, int(Game.profile.get("gold", 0)))
	if gold == my_gold:
		return
	my_gold = gold
	_send_offer()


func lock() -> void:
	if partner == "" or my_lock:
		return
	my_lock = true
	Online.send("trade_lock")
	changed.emit()


func can_confirm() -> bool:
	return partner != "" and my_lock and their_lock and not my_confirm and not their_bad


func confirm() -> void:
	if not can_confirm():
		return
	var room := _room_problem()
	if room != "":
		Game.say(room, &"warning")
	my_confirm = true
	Online.send("trade_confirm")
	changed.emit()


## Closes the trade from this side (the window's ยกเลิก / close, a zone change).
func cancel() -> void:
	if partner == "":
		return
	_close("cancel", true)


func _send_offer() -> void:
	_unlock()
	Online.send("trade_offer", {"items": mine.duplicate(true), "gold": my_gold})
	changed.emit()


## Keeps my offer within the bag: a stack drunk or gear sold while the window is open.
func _prune_offer() -> void:
	if partner == "" or _applying:
		return
	var dirty := false
	for i in range(mine.size() - 1, -1, -1):
		var lot: Dictionary = mine[i]
		if ItemData.is_stackable(lot):
			var have := _bag_count(lot)
			if have <= 0:
				mine.remove_at(i)
				dirty = true
			elif int(lot.count) > have:
				lot["count"] = have
				dirty = true
		elif _bag_index(lot) < 0:
			mine.remove_at(i)
			dirty = true
	if my_gold > int(Game.profile.get("gold", 0)):
		my_gold = int(Game.profile.get("gold", 0))
		dirty = true
	if dirty:
		_send_offer()


## A warning when what comes in will not fit in the bag (it then goes to storage).
func _room_problem() -> String:
	var need := 0
	for item in theirs:
		if not (ItemData.is_stackable(item) and _bag_count(item) > 0):
			need += 1
	for lot in mine:
		if not ItemData.is_stackable(lot) or int(lot.count) >= _bag_count(lot):
			need -= 1
	if need > Game.inventory_free():
		return "กระเป๋าไม่พอ — ของที่ล้นจะถูกส่งเข้าคลังรวม"
	return ""


# ---------------------------------------------------------------------------
# The bag
# ---------------------------------------------------------------------------

static func _same(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("kind", "")) != String(b.get("kind", "")):
		return false
	if ItemData.is_stackable(a):
		return String(a.get("id", "")) == String(b.get("id", ""))
	var uid := String(a.get("uid", ""))
	if uid != "" or String(b.get("uid", "")) != "":
		return uid == String(b.get("uid", ""))
	for key in ["slot", "name", "base", "class"]:
		if String(a.get(key, "")) != String(b.get(key, "")):
			return false
	for key in ["level", "rarity", "plus"]:
		if int(a.get(key, 0)) != int(b.get(key, 0)):
			return false
	return JSON.stringify(a.get("stats", {}), "", true) == JSON.stringify(b.get("stats", {}), "", true)


static func _bag_index(item: Dictionary) -> int:
	var inv: Array = Game.profile.get("inv", [])
	for i in inv.size():
		if _same(inv[i], item):
			return i
	return -1


static func _bag_count(item: Dictionary) -> int:
	var n := 0
	for entry in Game.profile.get("inv", []):
		if _same(entry, item):
			n += int(entry.get("count", 1)) if ItemData.is_stackable(entry) else 1
	return n


func _offered(item: Dictionary) -> int:
	for i in mine.size():
		if _same(mine[i], item):
			return i
	return -1


func _offered_count(item: Dictionary) -> int:
	var at := _offered(item)
	return int(mine[at].get("count", 1)) if at >= 0 else 0


## Why [param give] cannot leave the bag ("" when all of it is there).
static func missing(give: Dictionary) -> String:
	var want := {}
	var gear := []
	for raw in give.get("items", []):
		if not raw is Dictionary:
			return "ข้อมูลไม่ถูกต้อง"
		var item: Dictionary = raw
		if ItemData.is_stackable(item):
			var key := "%s|%s" % [item.get("kind", ""), item.get("id", "")]
			if not want.has(key):
				want[key] = [item, 0]
			want[key][1] = int(want[key][1]) + int(item.get("count", 1))
		else:
			gear.append(item)
	for key in want:
		if _bag_count(want[key][0]) < int(want[key][1]):
			return ItemData.name_of(want[key][0])
	var used := {}
	for item in gear:
		var found := -1
		var inv: Array = Game.profile.get("inv", [])
		for i in inv.size():
			if not used.has(i) and _same(inv[i], item):
				found = i
				break
		if found < 0:
			return ItemData.name_of(item)
		used[found] = true
	if int(give.get("gold", 0)) > int(Game.profile.get("gold", 0)):
		return "เหรียญ"
	return ""


## Removes [param item] (a stack's count across its piles, or the piece of gear).
static func _take_from_bag(item: Dictionary) -> void:
	var inv: Array = Game.profile.inv
	if ItemData.is_stackable(item):
		var left := int(item.get("count", 1))
		for i in range(inv.size() - 1, -1, -1):
			if left <= 0:
				break
			if _same(inv[i], item):
				var have := int(inv[i].get("count", 1))
				if have > left:
					inv[i]["count"] = have - left
					left = 0
				else:
					inv.remove_at(i)
					left -= have
	else:
		var at := _bag_index(item)
		if at >= 0:
			inv.remove_at(at)


## Puts [param item] in the bag, else the shared storage, else past the storage's room
## (it holds up to SharedStorage.MAX_ITEMS for moved-in old storages): never lost.
## Returns "bag" or "storage".
static func receive(item: Dictionary) -> String:
	if Game.add_item(item):
		return "bag"
	if not SharedStorage.put(item):
		SharedStorage.items().append(item)
	Game.say("กระเป๋าเต็ม — %s ถูกส่งเข้าคลังรวม" % ItemData.name_of(item), &"warning")
	return "storage"


func _apply_done(data: Dictionary) -> void:
	if partner == "":
		return
	# The server names the other player (`with`): a verdict for another trade is not ours.
	if String(data.get("with", partner)) != partner:
		return
	var give: Dictionary = data.get("give", {}) if data.get("give") is Dictionary else {}
	var got: Dictionary = data.get("get", {}) if data.get("get") is Dictionary else {}
	var who := partner
	var lack := missing(give)
	var incoming: Array = []
	for raw in got.get("items", []):
		if not Game._valid_item(raw) or not tradable(raw):
			lack = "ของจากอีกฝ่ายไม่ถูกต้อง"
			break
		var item: Dictionary = (raw as Dictionary).duplicate(true)
		Game._repair_item(item)
		incoming.append(item)
	var get_gold := maxi(0, int(got.get("gold", 0)))
	var give_gold := maxi(0, int(give.get("gold", 0)))
	if lack != "":
		Online.send("trade_cancel", {"reason": "missing"})
		Game.say("แลกไม่สำเร็จ: %s ไม่อยู่ในกระเป๋าแล้ว — ยกเลิกการแลก" % lack, &"warning")
		_close("abort", false)
		return
	_applying = true
	for raw in give.get("items", []):
		_take_from_bag(raw)
	var stored := 0
	for item in incoming:
		if receive(item) == "storage":
			stored += 1
	if get_gold != give_gold:
		Game.add_gold(get_gold - give_gold)
	Game.inventory_changed.emit()
	# The shared storage first, then the hero (Game._commit_storage): a crash between
	# the two can only leave an item in both places, never in neither.
	Game._commit_storage(true)
	_applying = false
	_last = {"partner": who, "gave": give.duplicate(true), "got": {"items": incoming.duplicate(true), "gold": get_gold}, "at": _now()}
	var who_name := player_name(who)
	Game.say("แลกของกับ %s สำเร็จ" % who_name + (" (ของ %d ชิ้นเข้าคลังรวม)" % stored if stored > 0 else ""), &"success")
	Game.post_chat("world", LOG_SPEAKER, "แลกของกับ %s สำเร็จ" % who_name, LOG_COLOR)
	AudioManager.play_sfx(&"coin")
	_close("done", false)


func _now() -> float:
	return Time.get_ticks_msec() * 0.001


## The partner aborted a trade this side already applied: put it back while what came
## in is still here (bag or shared storage); otherwise nothing moves.
func _undo_last() -> void:
	var last := _last
	_last = {}
	if _now() - float(last.at) > UNDO_SECONDS:
		return
	var got: Dictionary = last.got
	var give: Dictionary = last.gave
	var plan := []
	var inv: Array = Game.profile.inv
	var store := SharedStorage.items()
	for item in got.items:
		if ItemData.is_stackable(item):
			var have := _bag_count(item)
			for s in store:
				if _same(s, item):
					have += int(s.get("count", 1))
			if have < int(item.get("count", 1)):
				plan = []
				break
			plan.append(item)
		else:
			if _bag_index(item) < 0 and not store.any(func(s): return _same(s, item)):
				plan = []
				break
			plan.append(item)
	if plan.size() != got.items.size() or int(Game.profile.gold) < int(got.gold):
		Game.say("%s ยกเลิกการแลก แต่ของที่ได้มาถูกใช้ไปแล้ว" % player_name(String(last.partner)), &"warning")
		return
	for item in plan:
		if ItemData.is_stackable(item):
			var left := int(item.get("count", 1))
			var from_bag := mini(left, _bag_count(item))
			if from_bag > 0:
				var part: Dictionary = item.duplicate()
				part["count"] = from_bag
				_take_from_bag(part)
				left -= from_bag
			for i in range(store.size() - 1, -1, -1):
				if left <= 0:
					break
				if _same(store[i], item):
					var have := int(store[i].get("count", 1))
					if have > left:
						store[i]["count"] = have - left
						left = 0
					else:
						store.remove_at(i)
						left -= have
		elif _bag_index(item) >= 0:
			inv.remove_at(_bag_index(item))
		else:
			for i in store.size():
				if _same(store[i], item):
					store.remove_at(i)
					break
	for raw in give.get("items", []):
		var back: Dictionary = (raw as Dictionary).duplicate(true)
		Game._repair_item(back)
		receive(back)
	var delta := int(give.get("gold", 0)) - int(got.gold)
	if delta != 0:
		Game.add_gold(delta)
	Game.inventory_changed.emit()
	Game._commit_storage(true)
	Game.say("%s ยกเลิกการแลก — คืนของทั้งหมดแล้ว" % player_name(String(last.partner)), &"warning")


func _close(reason: String, tell: bool) -> void:
	if asking != "" and reason in ["disconnect"]:
		_drop_ask()
	if partner == "":
		return
	if tell:
		Online.send("trade_cancel")
	partner = ""
	mine.clear()
	theirs.clear()
	my_gold = 0
	their_gold = 0
	their_bad = false
	_unlock()
	closed.emit(reason)
