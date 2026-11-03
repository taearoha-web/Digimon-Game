extends Node3D
## แผงของฉัน (PlayerStall): listing from the bag (limits, price bounds, stacks), taking a
## lot back (into the storage when the bag is full, kept when both are full), AI sales
## (odds by price, the tuning targets, buyers whose class fits, gold + toast + world chat
## + log), the catch-up after the game was closed (capped at 12 h), the save round trip
## and old saves, and the stall page in the game menu. Seeded dice and injected clocks.
## godot --headless --path . res://tests/integration/player_stall_test.tscn
var checks := 0
var failures := 0
## A fixed moment of the world (the AI players' levels and sessions are set by it).
var t0 := float(WorldPlayers.START_UNIX + 6 * 86400)
var rng := RandomNumberGenerator.new()


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	rng.seed = 424242
	_listing()
	_unlist_overflow()
	_odds_by_price()
	_tuning()
	_buyers_fit()
	_sale_effects()
	_catch_up()
	_save_round_trip()
	await _menu_page()
	print("PLAYER STALL: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _fresh(cls := &"warrior") -> void:
	Game.new_profile(cls, "แผงทดสอบ")
	Game.profile.level = 60
	Game.profile.inv.clear()
	PlayerStall.reset_pool()


func _bag(item: Dictionary) -> int:
	Game.profile.inv.append(item)
	return Game.profile.inv.size() - 1


func _listing() -> void:
	_fresh()
	check(PlayerStall.lots().is_empty() and Game.profile.stall is Dictionary, "a new hero has an empty stall")
	var sword := ItemData.generate(55, &"warrior", rng, 2, "weapon")
	var fair := PlayerStall.fair_price(sword)
	check(fair == StallStock.consign_price(sword) and fair > 0, "the fair price is the consignment value (%d)" % fair)
	check(PlayerStall.min_price(sword) == int(ceil(fair * 0.5)) and PlayerStall.max_price(sword) == int(floor(fair * 3.0)), "the price may be 50%-300% of it")
	var i := _bag(sword)
	check(PlayerStall.list_item(i, PlayerStall.min_price(sword) - 1, 0, t0) == -1 and Game.profile.inv.size() == 1, "under 50% is refused")
	check(PlayerStall.list_item(i, PlayerStall.max_price(sword) + 1, 0, t0) == -1 and Game.profile.inv.size() == 1, "over 300% is refused")
	var lot := PlayerStall.list_item(i, fair, 0, t0)
	check(lot > 0 and Game.profile.inv.is_empty(), "listed: off the bag (lot %d)" % lot)
	var e: Dictionary = PlayerStall.lots()[0]
	check(int(e.lot) == lot and int(e.price) == fair and is_equal_approx(float(e.listed_at), t0) and String(e.item.uid) == String(sword.uid), "the lot keeps id, item, price and time")
	# A stack: a part of it, the rest stays in the bag.
	var potions := ItemData.potion("hp_l", 30)
	i = _bag(potions)
	var part := PlayerStall.list_item(i, PlayerStall.fair_price(ItemData.potion("hp_l", 12)), 12, t0)
	check(part > lot and int(Game.profile.inv[0].count) == 18 and int(PlayerStall.lots()[1].item.count) == 12, "12 of 30 potions on the stall, 18 kept")
	# Up to ten lots.
	for k in 8:
		i = _bag(ItemData.generate(30, &"mage", rng, 1, "weapon"))
		check(PlayerStall.list_item(i, PlayerStall.fair_price(Game.profile.inv[i]), 0, t0) > 0, "lot %d listed" % (k + 3))
	i = _bag(ItemData.generate(30, &"mage", rng, 1, "weapon"))
	check(PlayerStall.lots().size() == PlayerStall.MAX_LOTS and PlayerStall.list_item(i, PlayerStall.fair_price(Game.profile.inv[i]), 0, t0) == -1, "an eleventh lot is refused")
	var ids := PlayerStall.lots().map(func(x): return int(x.lot))
	var unique := {}
	for id in ids:
		unique[id] = true
	check(unique.size() == ids.size(), "lot ids are unique")
	# Back into the bag.
	check(PlayerStall.unlist(lot) and PlayerStall.find(lot) < 0, "a lot comes off the stall")
	check(Game.profile.inv.any(func(it): return String(it.get("uid", "")) == String(sword.uid)), "and is back in the bag")
	check(PlayerStall.unlist(part) and Game.profile.inv.filter(func(it): return it.get("id", "") == "hp_l").size() == 1 and int(Game.profile.inv[0].count) == 30, "the potions join their stack again")
	check(not PlayerStall.unlist(9999), "an unknown lot cannot be taken back")
	var next_id := PlayerStall.list_item(Game.profile.inv.size() - 1, PlayerStall.fair_price(Game.profile.inv[-1]), 0, t0)
	check(next_id > ids.max(), "ids are never reused")
	check(PlayerStall.blocked_reason(&"guildwar") != "" and PlayerStall.blocked_reason(&"tower") != "" and PlayerStall.blocked_reason(&"arena") != "" and PlayerStall.blocked_reason(&"pvp") != "", "no stall in the guild war, tower, arena or a duel")
	check(PlayerStall.blocked_reason(&"meadow") == "" and PlayerStall.blocked_reason(&"town") == "", "fields and the town are fine")


func _unlist_overflow() -> void:
	_fresh()
	var ring := ItemData.generate(40, &"warrior", rng, 3, "ring")
	var lot := PlayerStall.list_item(_bag(ring), PlayerStall.fair_price(ring), 0, t0)
	while Game.profile.inv.size() < Game.bag_size():
		Game.profile.inv.append(ItemData.generate(5, &"warrior", rng, 0, "boots"))
	var stored := SharedStorage.items().size()
	check(SharedStorage.items().size() < SharedStorage.SIZE, "the storage has room")
	check(PlayerStall.unlist(lot), "a full bag: the lot still comes back")
	check(SharedStorage.items().size() == stored + 1 and String(SharedStorage.items()[-1].get("uid", "")) == String(ring.uid), "into the shared storage")
	# Bag and storage full: the lot stays on the stall, nothing is lost.
	Game.profile.inv.pop_back()
	var lot2 := PlayerStall.list_item(_bag(ring.duplicate(true)), PlayerStall.fair_price(ring), 0, t0)
	while Game.profile.inv.size() < Game.bag_size():
		Game.profile.inv.append(ItemData.generate(5, &"warrior", rng, 0, "boots"))
	var keep := SharedStorage.items().duplicate()
	while SharedStorage.items().size() < SharedStorage.SIZE:
		SharedStorage.items().append(ItemData.generate(5, &"warrior", rng, 0, "helm"))
	check(not PlayerStall.unlist(lot2) and PlayerStall.find(lot2) >= 0, "bag and storage full: the lot stays on the stall")
	SharedStorage.items().clear()
	SharedStorage.items().append_array(keep)
	check(PlayerStall.unlist(lot2), "and comes back once there is room")


## Cheap sells fast, 300% almost never.
func _odds_by_price() -> void:
	var item := ItemData.generate(60, &"warrior", rng, 2, "weapon")
	var fair := PlayerStall.fair_price(item)
	var half := PlayerStall.sale_odds(item, PlayerStall.min_price(item))
	var even := PlayerStall.sale_odds(item, fair)
	var double := PlayerStall.sale_odds(item, fair * 2)
	var triple := PlayerStall.sale_odds(item, PlayerStall.max_price(item))
	check(half > even * 2.5 and even > double * 5.0 and double > triple, "odds fall with the price (%.3f %.3f %.4f %.5f)" % [half, even, double, triple])
	check(triple < 0.001, "300%%: about once in 16+ hours (%.5f a minute)" % triple)
	check(PlayerStall.sale_odds(item, fair, 1.4) > PlayerStall.sale_odds(item, fair, 0.5), "more buyers, faster sales")
	var plus := item.duplicate(true)
	plus["plus"] = 6
	check(PlayerStall.sale_odds(plus, PlayerStall.fair_price(plus)) > even, "an enhanced piece is wanted more")
	var mythic := ItemData.generate(60, &"warrior", rng, 4, "weapon")
	check(PlayerStall.sale_odds(mythic, PlayerStall.fair_price(mythic)) < PlayerStall.sale_odds(ItemData.generate(60, &"warrior", rng, 3, "weapon"), fair) + 0.001, "the rarer the piece, the fewer the buyers")
	# Simulated lots on the real minute loop: the cheap ones go first.
	_fresh()
	var counts := [0, 0, 0]
	for round_no in 20:
		var shares := [0.5, 1.0, 3.0]
		for k in 3:
			var piece := ItemData.generate(60, &"warrior", rng, 2, "armor")
			piece["tag"] = k
			PlayerStall.list_item(_bag(piece), PlayerStall.clamp_price(piece, int(PlayerStall.fair_price(piece) * shares[k])), 0, t0)
		PlayerStall.state()["tick"] = t0
		for sale in PlayerStall.tick(t0 + 20 * 60.0, rng):
			counts[int(sale.item.tag)] += 1
		for lot in PlayerStall.lots():
			PlayerStall.unlist(int(lot.lot))
		Game.profile.inv.clear()
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] <= 1, "within 20 minutes: 50%% %d, 100%% %d, 300%% %d of 20" % counts)


## A fair rare piece sells in ~5-20 minutes, a fair legendary in ~15-40 (medians).
func _tuning() -> void:
	for spec in [[2, 5.0, 20.0], [3, 15.0, 40.0]]:
		for slot_cls in [["armor", &"warrior"], ["weapon", &"warrior"], ["weapon", &"summoner"]]:
			var times: Array[float] = []
			for batch in 25:
				_fresh()
				for k in 8:
					var piece := ItemData.generate(100, slot_cls[1], rng, int(spec[0]), String(slot_cls[0]))
					PlayerStall.list_item(_bag(piece), PlayerStall.fair_price(piece), 0, t0)
				for m in 240:
					for sale in PlayerStall.tick(t0 + (m + 1) * 60.0, rng):
						times.append((float(sale.at) - t0) / 60.0)
				for left in PlayerStall.lots().size():
					times.append(999.0)
			times.sort()
			var median := times[times.size() / 2]
			print("tuning: rarity %d %s/%s median %.1f min, p25 %.1f, p75 %.1f" % [int(spec[0]), slot_cls[0], slot_cls[1], median, times[times.size() / 4], times[times.size() * 3 / 4]])
			check(median >= float(spec[1]) and median <= float(spec[2]), "rarity %d %s of a %s at the fair price: median %.1f minutes (want %d-%d)" % [int(spec[0]), slot_cls[0], slot_cls[1], median, int(spec[1]), int(spec[2])])


## The buyer is an AI world player whose class fits the piece.
func _buyers_fit() -> void:
	_fresh()
	var buyers := {}
	for cls in [&"archer", &"bard", &"darklord"]:
		for k in 30:
			var bow := ItemData.generate(100, cls, rng, 1, "weapon")
			var lot := PlayerStall.list_item(_bag(bow), PlayerStall.min_price(bow), 0, t0)
			PlayerStall.state()["tick"] = t0
			var sold := PlayerStall.tick(t0 + 6 * 3600.0, rng)
			check(sold.size() == 1, "a cheap %s piece sells" % cls)
			if sold.is_empty():
				continue
			var who := WorldPlayers.index_of(String(sold[0].buyer))
			check(who >= 0 and StringName(WorldPlayers.entry(who)["class"]) == cls, "%s bought the %s piece" % [sold[0].buyer, cls])
			buyers[String(sold[0].buyer)] = true
			check(PlayerStall.find(lot) < 0, "the lot is gone")
	check(buyers.size() > 5, "many different buyers (%d)" % buyers.size())
	# Any-class armour and stacks sell to anyone.
	var item := ItemData.jewel("purple", 5)
	PlayerStall.list_item(_bag(item), PlayerStall.min_price(item), 0, t0)
	PlayerStall.state()["tick"] = t0
	var sold := PlayerStall.tick(t0 + 6 * 3600.0, rng)
	check(sold.size() == 1 and WorldPlayers.index_of(String(sold[0].buyer)) >= 0, "jewels sell to a world player")


## sell(): gold now, a toast, a world chat line and the log.
func _sale_effects() -> void:
	_fresh()
	var lines: Array = []
	var toasts: Array = []
	var hear := func(speaker: String, text: String, _c: Color): lines.append([speaker, text])
	var toast := func(text: String, _k: StringName): toasts.append(text)
	var changed := [0]
	var ping := func(): changed[0] += 1
	Game.world_chat.connect(hear)
	Game.toast.connect(toast)
	Game.stall_changed.connect(ping)
	var axe := ItemData.generate(70, &"lancer", rng, 3, "weapon")
	var price := PlayerStall.fair_price(axe) * 2
	var lot := PlayerStall.list_item(_bag(axe), price, 0, t0)
	var gold := int(Game.profile.gold)
	var result := PlayerStall.sell(lot, "Fiora")
	check(int(Game.profile.gold) == gold + price, "the price is paid at once")
	check(String(result.get("item", {}).get("uid", "")) == String(axe.uid) and int(result.get("price", 0)) == price, "sell returns the item and the price")
	var want := "Fiora ซื้อ %s จากแผงของคุณ ราคา %s เหรียญ" % [ItemData.name_of(axe), PlayerStall.thousands(price)]
	check(lines.any(func(l): return String(l[1]) == want), "the world chat: %s" % want)
	check(toasts.any(func(t): return String(t).contains("Fiora") and String(t).contains(PlayerStall.thousands(price))), "a toast tells the sale")
	check(changed[0] >= 2, "Game.stall_changed fired on list and sale")
	var log: Array = PlayerStall.sales()
	check(log.size() == 1 and String(log[0].buyer) == "Fiora" and int(log[0].price) == price and String(log[0].name) == ItemData.name_of(axe), "the sale is logged")
	check(PlayerStall.sell(lot, "Fiora").is_empty() and int(Game.profile.gold) == gold + price, "a lot sells once")
	# The log keeps the last 20.
	for k in 25:
		var it := ItemData.potion("hp_s", 1)
		var id := PlayerStall.list_item(_bag(it), PlayerStall.fair_price(it), 0, t0)
		PlayerStall.sell(id, "ลูกค้า%d" % k, k % 2 == 0)
	check(PlayerStall.sales().size() == PlayerStall.LOG_SIZE and String(PlayerStall.sales()[0].buyer) == "ลูกค้า24" and bool(PlayerStall.sales()[0].real), "the log keeps the newest 20")
	Game.world_chat.disconnect(hear)
	Game.toast.disconnect(toast)
	Game.stall_changed.disconnect(ping)


## The game was closed 3 h: the sales of those hours happen on load; never more than 12 h.
func _catch_up() -> void:
	_fresh()
	var toasts: Array = []
	var toast := func(text: String, _k: StringName): toasts.append(text)
	Game.toast.connect(toast)
	for k in 6:
		var piece := ItemData.generate(100, &"warrior", rng, 2, "armor")
		PlayerStall.list_item(_bag(piece), PlayerStall.fair_price(piece), 0, t0)
	var dear := ItemData.generate(100, &"warrior", rng, 3, "armor")
	var dear_lot := PlayerStall.list_item(_bag(dear), PlayerStall.max_price(dear), 0, t0)
	toasts.clear()
	var gold := int(Game.profile.gold)
	var later := t0 + 3 * 3600.0
	var sold := PlayerStall.tick(later, rng)
	check(sold.size() >= 6, "3 h closed: the fairly priced lots sold (%d)" % sold.size())
	check(sold.all(func(s): return float(s.at) >= t0 + PlayerStall.NOTICE * 60.0 and float(s.at) <= later), "each at a minute in those hours")
	var paid := 0
	for s in sold:
		paid += int(s.price)
	check(int(Game.profile.gold) == gold + paid, "their gold is paid")
	check(toasts.size() == 1 and String(toasts[0]).contains("ระหว่างที่คุณไม่อยู่"), "one summary toast instead of one per sale")
	check(is_equal_approx(float(PlayerStall.state().tick), later), "ticked up to now")
	check(PlayerStall.tick(later, rng).is_empty(), "the same moment twice sells nothing more")
	# Cap: two days away count as the last 12 h only.
	PlayerStall.unlist(dear_lot)
	var cheap := ItemData.generate(100, &"warrior", rng, 0, "armor")
	PlayerStall.list_item(_bag(cheap), PlayerStall.min_price(cheap), 0, later)
	var away := later + 48 * 3600.0
	var capped := PlayerStall.tick(away, rng)
	check(capped.size() == 1 and float(capped[0].at) >= away - PlayerStall.CATCH_UP_CAP, "a long absence counts the last 12 h only")
	# A clock set back sells nothing and restarts the count.
	var piece := ItemData.generate(100, &"warrior", rng, 0, "armor")
	PlayerStall.list_item(_bag(piece), PlayerStall.min_price(piece), 0, away)
	check(PlayerStall.tick(away - 3600.0, rng).is_empty() and is_equal_approx(float(PlayerStall.state().tick), away - 3600.0), "a clock set back sells nothing")
	Game.toast.disconnect(toast)


func _save_round_trip() -> void:
	_fresh()
	var a := ItemData.generate(80, &"mage", rng, 3, "weapon")
	a["plus"] = 4
	a["gems"] = ["ruby_1"]
	a["sockets"] = maxi(1, int(a.sockets))
	var gem := ItemData.gem("emerald", 2, 3)
	var lot_a := PlayerStall.list_item(_bag(a), PlayerStall.fair_price(a), 0, t0)
	PlayerStall.list_item(_bag(gem), PlayerStall.fair_price(gem) * 2, 0, t0 + 30.0)
	var c := ItemData.potion("mp_l", 4)
	PlayerStall.sell(PlayerStall.list_item(_bag(c), PlayerStall.fair_price(c), 0, t0), "Kaito")
	var before := JSON.stringify(Game.profile.stall)
	check(Game.save(), "saved")
	check(Game.load_game(), "loaded")
	var s: Dictionary = Game.profile.stall
	check(s.lots.size() == 2 and int(s.lots[0].lot) == lot_a and String(s.lots[0].item.uid) == String(a.uid) and int(s.lots[0].item.plus) == 4, "the lots survive a save")
	check(s.lots[0].item.plus is int and s.lots[0].price is int and s.lots[1].item.count is int and s.next is int, "with their number types")
	check(int(s.lots[1].item.count) == 3 and s.log.size() == 1 and String(s.log[0].buyer) == "Kaito", "the stack and the log too")
	check(JSON.stringify(Game.profile.stall) == before, "the stall reads back the same")
	check(Game.save_code_roundtrip(), "the save code carries the stall")
	# Older saves have no stall: an empty one.
	var old := Game.profile.duplicate(true)
	old.erase("stall")
	check(Game._valid_profile(JSON.parse_string(JSON.stringify(old))), "an old save without a stall is valid")
	var repaired := Game._repair(JSON.parse_string(JSON.stringify(old)))
	check(repaired.stall is Dictionary and (repaired.stall.lots as Array).is_empty() and int(repaired.stall.next) == 1, "and gets an empty stall")
	var bad := Game.profile.duplicate(true)
	bad.stall.lots[0].item = {"kind": "equip", "slot": "nope"}
	check(not Game._valid_profile(JSON.parse_string(JSON.stringify(bad))), "a stall with a broken item is refused")
	bad = Game.profile.duplicate(true)
	for k in 11:
		bad.stall.lots.append(bad.stall.lots[0].duplicate(true))
	check(not Game._valid_profile(JSON.parse_string(JSON.stringify(bad))), "more than ten lots are refused")


## The page in the game menu: open from the bag, pick, list, see it, take it back.
func _menu_page() -> void:
	_fresh()
	Game.current_zone = &"meadow"
	var bow := ItemData.generate(50, &"archer", rng, 2, "weapon")
	Game.profile.inv = [bow, ItemData.potion("hp_m", 9)]
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await get_tree().process_frame
	var button: Button = menu.find_child("StallButton", true, false)
	check(button != null and button.text.contains("0/%d" % PlayerStall.MAX_LOTS), "the bag has a แผงของฉัน button")
	menu.open_stall(0)
	await get_tree().process_frame
	var page: PlayerStallView = menu.find_child("PlayerStallView", true, false)
	check(page != null, "the stall page opens in a field")
	var field: LineEdit = menu.find_child("PriceField", true, false)
	check(field != null and PlayerStallView._parse(field.text, 0) == PlayerStall.fair_price(bow), "the picked item starts at the fair price")
	var list: Button = menu.find_child("ListButton", true, false)
	check(list != null and not list.disabled and list.size.y >= 56.0, "a big ตั้งขาย button")
	list.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(PlayerStall.lots().size() == 1 and Game.profile.inv.size() == 1, "listed from the page")
	page = menu.find_child("PlayerStallView", true, false)
	check(page != null and menu.stall_open, "the page stays open after a listing")
	var take: Button = menu.find_child("Unlist", true, false)
	check(take != null, "the lot has a เก็บคืน button")
	take.pressed.emit()
	await get_tree().process_frame
	check(PlayerStall.lots().is_empty() and Game.profile.inv.size() == 2, "taken back from the page")
	menu.close_menu()
	Game.current_zone = &"guildwar"
	menu.open_menu(&"inventory")
	menu.open_stall()
	await get_tree().process_frame
	check(menu.find_child("PlayerStallView", true, false) == null, "not in the guild war")
	menu.close_menu()
	Game.current_zone = &"town"
	menu.free()
	get_tree().paused = false
