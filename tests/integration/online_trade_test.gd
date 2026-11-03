extends Node
## Trading with a real player (OnlineTrade + TradeScreen) on fake frames, no network: a
## trade_req asks and answers trade_answer; the window opens; every offer change is sent
## as trade_offer and unlocks both sides; ล็อก / ยืนยัน only once both are locked;
## trade_done swaps the items and the gold at once, saves, logs a chat line; gear of
## another class trades, bound items never do; a stack drunk while offered shrinks the
## offer; closing, the partner's cancel, a zone change and a dropped connection cancel; a
## give no longer in the bag aborts with trade_cancel and nothing moves; a full bag spills
## into the shared storage (even past its room) and nothing is lost; the partner's abort
## after we applied puts everything back; requests while busy are declined.
##   godot --headless --path . res://tests/integration/online_trade_test.tscn

class FakeSocket:
	extends RefCounted
	var sent: Array = []
	func send_text(text: String) -> void:
		sent.append(JSON.parse_string(text))
	func poll() -> Array:
		return []
	func last() -> Dictionary:
		return sent[-1] if not sent.is_empty() else {}
	func of(type: String) -> Array:
		return sent.filter(func(f): return String(f.get("t", "")) == type)

var checks := 0
var failures := 0
var socket := FakeSocket.new()
var trade: OnlineTrade
var screen: TradeScreen
var rng := RandomNumberGenerator.new()
var chat: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	rng.seed = 7
	SharedStorage.read_file()
	Game.new_profile(&"warrior", "Trade QA", FaceKit.default_look())
	Game.profile.level = 40
	Game.current_zone = &"meadow"
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): chat.append("%s: %s" % [speaker, text]))
	Online.use_transport(socket)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "qa"}, "party": null, "players": [
		{"id": "p2", "user": "mali_acc", "name": "Mali", "zone": "meadow", "level": 41},
		{"id": "p3", "user": "nok", "name": "Nok", "zone": "meadow", "level": 30}]})
	trade = OnlineTrade.new()
	add_child(trade)
	screen = TradeScreen.new()
	add_child(screen)
	screen.bind(trade)
	await _frames()
	await _flow()
	await _cancels()
	await _missing()
	await _overflow()
	await _undo()
	_offline()
	print("ONLINE TRADE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _gear(cls: StringName, slot := "weapon") -> Dictionary:
	return ItemData.generate(40, cls, rng, 2, slot)


func _index_of(item: Dictionary) -> int:
	for i in Game.profile.inv.size():
		if OnlineTrade._same(Game.profile.inv[i], item):
			return i
	return -1


func _potions(id: String) -> int:
	var n := 0
	for item in Game.profile.inv:
		if item.get("kind", "") == "potion" and item.id == id:
			n += int(item.count)
	return n


## A trade opened by the partner's request, accepted.
func _open_by_request(from := "p2") -> void:
	Online._dispatch({"t": "trade_req", "from": from})
	trade.answer(true)
	await _frames()


func _flow() -> void:
	Game.profile.gold = 5000
	var sword := _gear(&"warrior")
	var staff := _gear(&"mage")
	var bound := _gear(&"warrior", "ring")
	bound["bound"] = true
	Game.add_item(sword)
	Game.add_item(staff)
	Game.add_item(bound)
	Game.add_item(ItemData.potion("hp_s", 25))
	var potions_before := _potions("hp_s")
	# The request: a prompt card, then trade_answer.
	Online._dispatch({"t": "trade_req", "from": "p2"})
	check(trade.asking == "p2", "a trade_req asks the hero")
	await _frames()
	var ask := OnlineAsk.find_or_make(self)
	check(ask.find_child("AskCard", true, false) != null, "the request shows a prompt card")
	var card_text := ""
	for l in ask.find_children("*", "Label", true, false):
		card_text += (l as Label).text
	check(card_text.contains("Mali") and card_text.contains("แลกเปลี่ยน"), "the prompt names the asker in Thai (%s)" % card_text)
	trade.answer(true)
	await _frames()
	var answer := socket.last()
	check(answer.get("t") == "trade_answer" and answer.get("from") == "p2" and answer.get("ok") == true, "accepting sends trade_answer ok")
	check(trade.is_open() and trade.partner == "p2" and screen.is_open, "the trade window opens")
	# Busy: a second request is declined at once.
	Online._dispatch({"t": "trade_req", "from": "p3"})
	check(socket.last().get("t") == "trade_answer" and socket.last().get("from") == "p3" and socket.last().get("ok") == false, "a request while trading is declined")
	# My offer: gear whole, a stack with a count, gold.
	check(trade.offer(_index_of(sword)), "gear can be offered")
	var offer := socket.last()
	check(offer.get("t") == "trade_offer" and offer.items.size() == 1 and String(offer.items[0].uid) == String(sword.uid), "the offer is sent as trade_offer")
	check(not trade.offer(_index_of(sword)), "the same gear is offered once")
	check(trade.offer(_index_of(staff)), "gear of another class trades")
	check(not trade.offer(_index_of(bound)), "a bound item never trades")
	check(trade.offer(_index_of(ItemData.potion("hp_s")), 10), "a stack is offered with a count")
	offer = socket.last()
	var lot: Dictionary = offer.items.filter(func(i): return i.get("kind") == "potion")[0]
	check(int(lot.count) == 10, "the stack goes out with the count offered (%d)" % int(lot.count))
	trade.set_gold(1200)
	check(int(socket.last().get("gold", -1)) == 1200 and trade.my_gold == 1200, "gold is part of the offer")
	trade.set_gold(999999)
	check(trade.my_gold == 5000, "gold is capped at what the hero has")
	trade.set_gold(1000)
	# Taking back, then offering again.
	var staff_at := -1
	for i in trade.mine.size():
		if OnlineTrade._same(trade.mine[i], staff):
			staff_at = i
	trade.take_back(staff_at)
	check(trade.mine.size() == 2 and socket.last().items.size() == 2, "taking an entry back re-sends the offer")
	# Locks: mine, theirs; a change unlocks both.
	trade.lock()
	check(socket.last().get("t") == "trade_lock" and trade.my_lock, "ล็อก sends trade_lock")
	check(not trade.can_confirm(), "no confirm before the partner locks")
	var their_gear := _gear(&"archer", "armor")
	Online._dispatch({"t": "trade_offer", "from": "p2", "items": [their_gear, ItemData.jewel("purple", 3)], "gold": 300})
	check(trade.theirs.size() == 2 and trade.their_gold == 300 and not trade.their_bad, "their offer is shown")
	check(not trade.my_lock and not trade.their_lock, "their change unlocks both sides")
	Online._dispatch({"t": "trade_lock", "from": "p2"})
	trade.lock()
	check(trade.can_confirm(), "both locked: ยืนยัน works")
	trade.offer(_index_of(ItemData.potion("hp_s")), 1)
	check(not trade.my_lock and not trade.can_confirm(), "my change unlocks both sides too")
	check(int(trade.mine.filter(func(i): return i.get("kind") == "potion")[0].count) == 11, "a second pick adds to the stack offered")
	# A stack drunk while offered: the offer shrinks to what is left.
	var drink_at := _index_of(ItemData.potion("hp_s"))
	Game.remove_item_at(drink_at, potions_before - 5)
	check(int(trade.mine.filter(func(i): return i.get("kind") == "potion")[0].count) == 5 and socket.last().get("t") == "trade_offer", "a stack used meanwhile shrinks the offer (%d)" % int(trade.mine.filter(func(i): return i.get("kind") == "potion")[0].count))
	Online._dispatch({"t": "trade_lock", "from": "p2"})
	trade.lock()
	await _frames()
	# The window shows both offers and the lock state.
	check(screen.find_child("Mine_0", true, false) != null and screen.find_child("Mine_1", true, false) != null, "the window lists my offer")
	check(screen.find_child("Theirs_0", true, false) != null and screen.find_child("Theirs_1", true, false) != null, "the window lists their offer")
	var confirm_button := screen.find_child("Confirm", true, false) as Button
	check(confirm_button != null and not confirm_button.disabled, "ยืนยัน is enabled once both are locked")
	var bound_row := screen.find_child("Bag_%d" % _index_of(bound), true, false)
	check(bound_row != null and (bound_row.find_child("Act", true, false) as Button).disabled, "a bound item's row is greyed")
	trade.confirm()
	check(socket.last().get("t") == "trade_confirm" and trade.my_confirm, "ยืนยัน sends trade_confirm")
	Online._dispatch({"t": "trade_confirm", "from": "p2"})
	# The server's verdict.
	var give := {"items": trade.mine.duplicate(true), "gold": 1000}
	var bag_before: int = Game.profile.inv.size()
	Online._dispatch({"t": "trade_done", "with": "p2", "give": JSON.parse_string(JSON.stringify(give)), "get": JSON.parse_string(JSON.stringify({"items": [their_gear, ItemData.jewel("purple", 3)], "gold": 300}))})
	await _frames()
	check(_index_of(sword) < 0, "the given gear left the bag")
	check(_potions("hp_s") == 0, "the given potions left the bag (%d)" % _potions("hp_s"))
	check(_index_of(their_gear) >= 0, "their gear is in the bag")
	check(Game.jewel_count("purple") == 3, "their jewels are in the bag")
	check(_index_of(staff) >= 0 and _index_of(bound) >= 0, "what was not given stays")
	check(int(Game.profile.gold) == 5000 - 1000 + 300, "the gold moved (%d)" % int(Game.profile.gold))
	check(Game.profile.inv.size() == bag_before - 2 + 2, "bag size adds up")
	check(not trade.is_open() and not screen.is_open, "the window closes after the trade")
	check(chat.any(func(l): return String(l).contains("แลกของกับ Mali สำเร็จ")), "the trade is logged in the chat")
	var saved := Game._read_slot(Game.slot)
	check(int(saved.get("gold", -1)) == int(Game.profile.gold), "the trade is saved at once")


func _cancels() -> void:
	# My request accepted, then closed from my side.
	trade.request("p2")
	check(socket.last().get("t") == "trade_req" and socket.last().get("to") == "p2", "a request sends trade_req")
	Online._dispatch({"t": "trade_answer", "from": "p2", "ok": true})
	check(trade.is_open(), "an accepted request opens the window")
	await _frames()
	(screen.find_child("Cancel", true, false) as Button).pressed.emit()
	check(not trade.is_open() and socket.last().get("t") == "trade_cancel", "closing the window cancels the trade")
	# A refusal.
	Online._dispatch({"t": "trade_answer", "from": "p2", "ok": false})
	check(not trade.is_open(), "a refusal opens nothing")
	# The partner cancels.
	await _open_by_request()
	var sent := socket.sent.size()
	Online._dispatch({"t": "trade_cancel", "from": "p2"})
	check(not trade.is_open() and not screen.is_open and socket.sent.size() == sent, "the partner's cancel closes the window")
	# A zone change.
	await _open_by_request()
	Game.current_zone = &"forest"
	await _frames()
	check(not trade.is_open() and socket.last().get("t") == "trade_cancel", "a zone change cancels")
	Game.current_zone = &"meadow"
	# The connection drops.
	await _open_by_request()
	Online.disconnected.emit()
	check(not trade.is_open(), "a dropped connection cancels")
	# The partner leaves the game.
	await _open_by_request()
	Online._dispatch({"t": "leave", "id": "p2"})
	check(not trade.is_open(), "the partner leaving cancels")
	Online._dispatch({"t": "join", "player": {"id": "p2", "user": "mali_acc", "name": "Mali", "zone": "meadow", "level": 41}})
	# Declining a request.
	Online._dispatch({"t": "trade_req", "from": "p2"})
	trade.answer(false)
	check(socket.last().get("t") == "trade_answer" and socket.last().get("ok") == false and not trade.is_open(), "declining sends trade_answer false")
	# Bad data from the partner blocks confirming.
	await _open_by_request()
	Online._dispatch({"t": "trade_offer", "from": "p2", "items": [{"kind": "equip", "slot": "weapon", "stats": "x"}], "gold": 5})
	Online._dispatch({"t": "trade_lock", "from": "p2"})
	trade.lock()
	check(trade.their_bad and not trade.can_confirm(), "an offer with bad items cannot be confirmed")
	trade.cancel()


func _missing() -> void:
	await _open_by_request()
	var axe := _gear(&"warrior", "helm")
	Game.add_item(axe)
	Game.add_item(ItemData.potion("mp_s", 8))
	trade.offer(_index_of(axe))
	trade.offer(_index_of(ItemData.potion("mp_s")), 8)
	var give := {"items": trade.mine.duplicate(true), "gold": 0}
	# The gear goes behind the trade's back (no signal): the give is no longer there.
	Game.profile.inv.remove_at(_index_of(axe))
	var gold := int(Game.profile.gold)
	var mp := _potions("mp_s")
	var gift := _gear(&"priest", "boots")
	Online._dispatch({"t": "trade_done", "with": "p2", "give": give, "get": {"items": [gift], "gold": 999}})
	check(socket.last().get("t") == "trade_cancel" and socket.last().get("reason") == "missing", "a missing give aborts with trade_cancel")
	check(_index_of(gift) < 0 and int(Game.profile.gold) == gold and _potions("mp_s") == mp, "an aborted trade moves nothing")
	check(not trade.is_open(), "the aborted trade closes")
	# Gold the hero no longer has.
	await _open_by_request()
	Online._dispatch({"t": "trade_done", "with": "p2", "give": {"items": [], "gold": int(Game.profile.gold) + 1}, "get": {"items": [], "gold": 0}})
	check(socket.last().get("t") == "trade_cancel" and int(Game.profile.gold) == gold, "gold the hero lacks aborts too")


func _overflow() -> void:
	# A full bag: what comes in goes to the shared storage; even a full storage takes it.
	Game.profile.inv.clear()
	while Game.profile.inv.size() < Game.bag_size():
		Game.profile.inv.append(_gear(&"warrior", "amulet"))
	var store := SharedStorage.items()
	store.clear()
	while store.size() < SharedStorage.SIZE - 1:
		store.append(_gear(&"mage", "ring"))
	SharedStorage.store()
	await _open_by_request()
	var given: Dictionary = Game.profile.inv[0]
	trade.offer(0)
	var one := _gear(&"lancer", "weapon")
	var two := _gear(&"bard", "armor")
	var three := _gear(&"defender", "helm")
	Online._dispatch({"t": "trade_done", "with": "p2", "give": {"items": [given], "gold": 0}, "get": {"items": [one, two, three], "gold": 0}})
	check(_index_of(given) < 0, "the given gear left the full bag")
	check(_index_of(one) >= 0, "the first piece takes the freed bag slot")
	var stored := SharedStorage.items()
	check(stored.any(func(s): return OnlineTrade._same(s, two)), "a full bag spills into the shared storage")
	check(stored.any(func(s): return OnlineTrade._same(s, three)), "a full storage still takes it (nothing lost)")
	check(stored.size() == SharedStorage.SIZE + 1, "the storage holds past its room (%d)" % stored.size())
	SharedStorage.read_file()
	check(SharedStorage.items().any(func(s): return OnlineTrade._same(s, three)), "the storage was written")
	SharedStorage.items().clear()
	SharedStorage.store()
	Game.profile.inv.clear()


func _undo() -> void:
	Game.profile.gold = 1000
	var mine := _gear(&"warrior", "boots")
	Game.add_item(mine)
	await _open_by_request()
	trade.offer(_index_of(mine))
	var theirs := _gear(&"assassin", "ring")
	Online._dispatch({"t": "trade_done", "with": "p2", "give": {"items": [mine], "gold": 100}, "get": {"items": [theirs], "gold": 0}})
	check(_index_of(theirs) >= 0 and _index_of(mine) < 0 and int(Game.profile.gold) == 900, "applied")
	# The partner's side found its give missing and aborted: undo ours.
	Online._dispatch({"t": "trade_cancel", "from": "p2", "reason": "missing"})
	check(_index_of(mine) >= 0 and _index_of(theirs) < 0 and int(Game.profile.gold) == 1000, "the partner's abort puts everything back")


func _offline() -> void:
	Online.use_transport(null)
	check(not Online.is_online(), "offline after the transport goes")
	var sent := socket.sent.size()
	trade.request("p2")
	check(socket.sent.size() == sent and not trade.is_open(), "offline: nothing is sent, nothing opens")
