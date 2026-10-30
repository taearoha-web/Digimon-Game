extends Node
## Trading with the stall keepers (StallStock): a stall's stock is the same for the same
## keeper and restock window, gear a grade above the merchant's at a higher price,
## potions a little cheaper; buying spends the gold, puts the lot in the bag and takes it
## off the stall until the restock; the stall pays more than the merchant for the bag's
## things; the bought-lot flags of older windows are dropped when a stall opens; the shop
## screen opens a stall (open_stall) and the merchant (open_shop) as before. Haggling is
## deterministic, once a lot a window, and its discount applies to the buy; a keeper's
## announcement names a real lot; consignment takes the item, or a chosen count of a
## stack (the screen's − / + stepper), pays after the due time, at most 8 out at once.
##   godot --headless --path . res://tests/integration/stall_trade_test.tscn
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	Game.new_profile(&"warrior", "Stall QA", FaceKit.default_look())
	Game.profile.level = 42
	var i := _keeper("PotionKing")
	# The middle of the stall's restock window, so the window holds through the test.
	var t0 := float(WorldPlayers.START_UNIX) + 5.0 * 86400.0
	var t := StallStock.restock_at(i, t0) - StallStock.RESTOCK * 0.5
	WorldPresence.clock_offset = t - WorldPlayers.now()
	_stock(i, t)
	_buy(i, t)
	_sell(i)
	_haggle(t)
	_announce(i, t)
	_prune(i, t)
	_consign(i, t)
	await _screen(_keeper("ร้านเกราะพี่โต"))
	WorldPresence.clock_offset = 0.0
	print("STALL TRADE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _keeper(who: String) -> int:
	for i in WorldPlayers.size():
		if String(WorldPlayers.entry(i).name) == who:
			return i
	return 0


static func _summary(lots: Array[Dictionary]) -> Array:
	return lots.map(func(e): return "%s|%s|%d|%d" % [ItemData.name_of(e.item), JSON.stringify(e.item.get("stats", {})), int(e.item.get("count", 1)), int(e.price)])


func _stock(i: int, t: float) -> void:
	var lots := StallStock.stock(i, t)
	check(lots.size() >= 4, "a stall lays out its finds (%d lots)" % lots.size())
	check(_summary(lots) == _summary(StallStock.stock(i, t + 120.0)), "the same stock all through the restock window")
	var next := StallStock.restock_at(i, t) + 60.0
	check(_summary(lots) != _summary(StallStock.stock(i, next)), "a new stock after the restock")
	check(StallStock.window(i, next) == StallStock.window(i, t) + 1, "restocks every %d real minutes" % int(StallStock.RESTOCK / 60.0))
	# Every stall keeper of the roster has something to sell.
	var empty: Array[String] = []
	for n in WorldPlayers.size():
		if WorldPlayers.in_town_style(n) and StallStock.stock(n, t).is_empty():
			empty.append(String(WorldPlayers.entry(n).name))
	check(empty.is_empty(), "every stall keeper has a stock (%s)" % [empty])
	check(StallStock.specialty(i) == "potion" and StallStock.specialty(_keeper("ร้านเกราะพี่โต")) == "armor" and StallStock.specialty(_keeper("LuteSeller")) == "weapon", "a stall's name tells what it sells")
	var potions := lots.filter(func(e): return String(e.item.get("kind", "")) == "potion").size()
	check(potions >= 3, "a potion stall sells potions (%d lots)" % potions)
	# Better than the merchant: the merchant's gear is common or good, a stall's rare and up.
	var npc := ShopScreen.new()
	var npc_best := 0
	for item in npc._stock():
		if String(item.get("kind", "")) == "equip":
			npc_best = maxi(npc_best, int(item.rarity))
	npc.free()
	check(npc_best <= 1, "the merchant sells common and good gear (best %d)" % npc_best)
	var rarities := {}
	for n in WorldPlayers.size():
		if not WorldPlayers.in_town_style(n):
			continue
		for e in StallStock.full_stock(n, t):
			var item: Dictionary = e.item
			match String(item.get("kind", "")):
				"equip":
					rarities[int(item.rarity)] = int(rarities.get(int(item.rarity), 0)) + 1
					check(int(item.rarity) >= 2 and int(item.level) <= int(Game.profile.level), "%s: a find above the merchant's grade the hero can wear (rarity %d, Lv.%d)" % [item.name, int(item.rarity), int(item.level)])
					check(int(e.price) > ItemData.buy_price(item), "%s: costs more than at the merchant (%d > %d)" % [item.name, int(e.price), ItemData.buy_price(item)])
					check(String(item.slot) != "weapon" or StringName(item["class"]) == Game.class_id(), "%s: a weapon for the hero's class" % item.name)
				"potion":
					var npc_price := ItemData.buy_price(item) * int(item.count)
					check(int(e.price) < npc_price, "%s ×%d: cheaper than at the merchant (%d < %d)" % [ItemData.name_of(item), int(item.count), int(e.price), npc_price])
				_:
					check(int(e.price) > 0, "%s: has a price" % ItemData.name_of(item))
	print("stall_trade_test: gear by rarity across the stalls %s" % [rarities])
	check(int(rarities.get(2, 0)) > int(rarities.get(3, 0)) and int(rarities.get(3, 0)) > int(rarities.get(4, 0)) and int(rarities.get(4, 0)) >= 0, "the rarer the grade, the rarer the find (%s)" % [rarities])


func _buy(i: int, t: float) -> void:
	var lots := StallStock.stock(i, t)
	var lot: Dictionary = lots[0]
	for e in lots:
		if String(e.item.get("kind", "")) == "equip":
			lot = e
			break
	var k := int(lot.k)
	Game.profile.gold = int(lot.price) - 1
	check(not StallStock.buy(i, k, t) and int(Game.profile.gold) == int(lot.price) - 1, "no sale without the gold")
	Game.profile.gold = int(lot.price) + 500
	var bag: int = Game.profile.inv.size()
	check(StallStock.buy(i, k, t), "buys a lot")
	check(int(Game.profile.gold) == 500, "the price is paid (%d left)" % int(Game.profile.gold))
	check(Game.profile.inv.size() == bag + 1 and ItemData.name_of(Game.profile.inv[-1]) == ItemData.name_of(lot.item), "the lot is in the bag")
	check(not StallStock.stock(i, t).any(func(e): return int(e.k) == k), "the lot is gone from the stall")
	check(StallStock.stock(i, t).size() == lots.size() - 1, "the rest is still for sale")
	check(not StallStock.buy(i, k, t) and int(Game.profile.gold) == 500, "a lot is sold only once")
	var key := "stall|%s|%d|%d" % [WorldPlayers.entry(i).name, StallStock.window(i, t), k]
	check(Game.profile.flags.get(key) is int and int(Game.profile.flags[key]) == 1, "the sale is kept in the flags (%s)" % key)
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with bought lots is valid")
	check(StallStock.stock(i, StallStock.restock_at(i, t) + 60.0).size() == StallStock.full_stock(i, StallStock.restock_at(i, t) + 60.0).size(), "the restock brings a full stall again")
	# A potion lot stacks onto the bag's bottles.
	for e in StallStock.stock(i, t):
		if String(e.item.get("kind", "")) == "potion":
			var id := String(e.item.id)
			var had := Game.potion_count(id)
			Game.profile.gold = int(e.price)
			check(StallStock.buy(i, int(e.k), t) and Game.potion_count(id) == had + int(e.item.count) and int(Game.profile.gold) == 0, "a potion lot adds its bottles (%s ×%d)" % [id, int(e.item.count)])
			break


func _sell(_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var item := ItemData.generate(40, &"warrior", rng, 2, "armor")
	Game.profile.inv.append(item)
	var index: int = Game.profile.inv.size() - 1
	var npc := ItemData.unit_sell_price(item)
	var stall := StallStock.sell_price(item)
	check(stall > npc, "a stall pays more than the merchant (%d > %d)" % [stall, npc])
	var gold := int(Game.profile.gold)
	check(StallStock.sell(index) and int(Game.profile.gold) == gold + stall and not Game.profile.inv.has(item), "selling pays the stall's price and takes the piece")
	Game.profile.inv.append(ItemData.potion("hp_m", 10))
	var bottle := ItemData.potion("hp_m", 1)
	check(StallStock.sell_price(bottle) > ItemData.unit_sell_price(bottle), "a stall pays more for a bottle too")
	gold = int(Game.profile.gold)
	StallStock.sell(Game.profile.inv.size() - 1, 3)
	check(int(Game.profile.gold) == gold + 3 * StallStock.sell_price(bottle), "sells several bottles at once")


func _haggle(t: float) -> void:
	# Every lot of every stall: the outcome is the same on every try, and the odds hold.
	var by_code := {}
	var accepted := []
	var refused := []
	var countered := []
	for n in WorldPlayers.size():
		if not WorldPlayers.in_town_style(n):
			continue
		for e in StallStock.stock(n, t):
			var k := int(e.k)
			var out := StallStock.haggle_outcome(n, k, t)
			check(out == StallStock.haggle_outcome(n, k, t), "the same haggle outcome every time (%s lot %d)" % [WorldPlayers.entry(n).name, k])
			by_code[int(out.code)] = int(by_code.get(int(out.code), 0)) + 1
			match int(out.code):
				StallStock.HAGGLE_ACCEPTED:
					check(int(out.percent) >= 10 and int(out.percent) <= 20, "an accepted haggle is 10-20%% off (%d)" % int(out.percent))
					accepted.append([n, k])
				StallStock.HAGGLE_REFUSED:
					check(int(out.percent) == 0, "a refusal gives nothing off")
					refused.append([n, k])
				StallStock.HAGGLE_COUNTER:
					check(int(out.percent) > 0 and int(out.percent) < 10, "a counter-offer is a smaller discount (%d)" % int(out.percent))
					countered.append([n, k])
				_:
					check(false, "an unknown haggle code %d" % int(out.code))
	var total := accepted.size() + refused.size() + countered.size()
	print("stall_trade_test: haggle outcomes across the stalls %s" % [by_code])
	check(total > 40 and accepted.size() > total * 0.3 and refused.size() > total * 0.25 and countered.size() > total * 0.05 and countered.size() < total * 0.3, "about 45%% accept, 40%% refuse, 15%% counter (%s of %d)" % [by_code, total])
	var hero := String(Game.profile.name)
	Game.profile.name = "Someone Else"
	var changed := 0
	for pair in accepted + refused:
		if int(StallStock.haggle_outcome(pair[0], pair[1], t).code) != (StallStock.HAGGLE_ACCEPTED if accepted.has(pair) else StallStock.HAGGLE_REFUSED):
			changed += 1
	Game.profile.name = hero
	check(changed > 0, "another hero gets other answers (%d differ)" % changed)
	# An accepted haggle: the keeper says so in the world chat, the price drops, the buy pays it.
	var said := []
	var hear := func(who: String, text: String, color: Color): said.append([who, text, color])
	Game.world_chat.connect(hear)
	var a: int = accepted[0][0]
	var ka: int = accepted[0][1]
	var base := int(StallStock.full_stock(a, t).filter(func(e): return int(e.k) == ka)[0].price)
	check(StallStock.can_haggle(a, ka, t), "a lot not haggled over yet can be")
	var result := StallStock.haggle(a, ka, t)
	var percent := int(result.get("percent", 0))
	check(int(result.get("code", 0)) == StallStock.HAGGLE_ACCEPTED and String(result.get("text", "")).contains("%d%%" % percent), "the keeper accepts (%s)" % [result])
	check(said.size() == 1 and said[0][0] == String(WorldPlayers.entry(a).name) and said[0][1] == result.text and said[0][2] == Color("8ff0ff"), "the keeper's line is in the world chat (%s)" % [said])
	var key := "haggle|%s|%d|%d" % [WorldPlayers.entry(a).name, StallStock.window(a, t), ka]
	check(Game.profile.flags.get(key) is int and int(Game.profile.flags[key]) == StallStock.HAGGLE_ACCEPTED, "the haggle is kept in the flags (%s)" % key)
	var want := maxi(1, int(round(float(base) * float(100 - percent) / 100.0)))
	var lot: Dictionary = StallStock.stock(a, t).filter(func(e): return int(e.k) == ka)[0]
	check(int(lot.price) == want and int(lot.get("base", 0)) == base and want < base, "the stock shows the haggled price (%d of %d, %d%% off)" % [int(lot.price), base, percent])
	check(StallStock.discount(a, ka, t) == percent and not StallStock.can_haggle(a, ka, t) and StallStock.haggle(a, ka, t).is_empty(), "one haggle a lot a window")
	Game.profile.gold = want + 100
	check(StallStock.buy(a, ka, t) and int(Game.profile.gold) == 100, "the buy pays the haggled price (%d left)" % int(Game.profile.gold))
	check(said.size() == 1, "buying says nothing more")
	# A refusal cannot be tried again in the same window; the price stays.
	var r: int = refused[0][0]
	var kr: int = refused[0][1]
	var full := int(StallStock.stock(r, t).filter(func(e): return int(e.k) == kr)[0].price)
	result = StallStock.haggle(r, kr, t)
	check(int(result.get("code", 0)) == StallStock.HAGGLE_REFUSED and said.size() == 2 and said[1][0] == String(WorldPlayers.entry(r).name), "the keeper refuses politely (%s)" % [result])
	check(StallStock.haggle(r, kr, t).is_empty() and said.size() == 2 and StallStock.haggled(r, kr, t) == StallStock.HAGGLE_REFUSED, "a refused haggle is not tried again in the window")
	check(int(StallStock.stock(r, t).filter(func(e): return int(e.k) == kr)[0].price) == full and StallStock.discount(r, kr, t) == 0, "a refusal leaves the price")
	var next := StallStock.restock_at(r, t) + 60.0
	check(StallStock.can_haggle(r, kr, next), "the next window allows another try")
	if not countered.is_empty():
		var c: int = countered[0][0]
		var kc: int = countered[0][1]
		var c_base := int(StallStock.stock(c, t).filter(func(e): return int(e.k) == kc)[0].price)
		result = StallStock.haggle(c, kc, t)
		check(int(result.get("code", 0)) == StallStock.HAGGLE_COUNTER and int(StallStock.stock(c, t).filter(func(e): return int(e.k) == kc)[0].price) < c_base, "a counter-offer takes a little off (%s)" % [result])
	Game.world_chat.disconnect(hear)
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with haggles is valid")


func _announce(i: int, t: float) -> void:
	var text := StallStock.announcement(i, t)
	var lots := StallStock.stock(i, t)
	var named := lots.filter(func(e): return text.contains(ItemData.name_of(e.item)) and text.contains(StallStock._thousands(int(e.price))))
	check(text.begins_with("ร้าน%s: มี" % WorldPlayers.entry(i).name) and text.ends_with("แวะดูได้") and named.size() >= 1, "an announcement names a real lot and its price (%s)" % text)
	check(text == StallStock.announcement(i, t + 1.0), "the same call for a while")
	var armor := _keeper("ร้านเกราะพี่โต")
	var armor_text := StallStock.announcement(armor, t)
	var gear := StallStock.stock(armor, t).filter(func(e): return String(e.item.get("kind", "")) == "equip" and armor_text.contains(ItemData.name_of(e.item)))
	check(armor_text.begins_with("ร้านเกราะพี่โต: มี") and (gear.is_empty() or (armor_text.contains("ระดับ") and armor_text.contains("Lv."))), "a shop's name is not doubled; gear comes with its grade and level (%s)" % armor_text)
	var w := StallStock.window(i, t)
	for e in lots:
		Game.profile.flags["stall|%s|%d|%d" % [WorldPlayers.entry(i).name, w, int(e.k)]] = 1
	check(StallStock.announcement(i, t) == "", "nothing to call out from an empty stall")
	for e in lots:
		Game.profile.flags.erase("stall|%s|%d|%d" % [WorldPlayers.entry(i).name, w, int(e.k)])


func _consign(i: int, t: float) -> void:
	var toasts := []
	var hear := func(text: String, _kind: StringName): toasts.append(text)
	Game.toast.connect(hear)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var item := ItemData.generate(40, &"warrior", rng, 3, "helm")
	Game.profile.inv.append(item)
	var index: int = Game.profile.inv.size() - 1
	var price := StallStock.consign_price(item)
	check(price > StallStock.sell_price(item) and price == int(ceil(float(ItemData.unit_sell_price(item)) * 1.5 - 0.001)), "a consignment pays 1.5x the merchant (%d > %d)" % [price, StallStock.sell_price(item)])
	var gold := int(Game.profile.gold)
	var bag: int = Game.profile.inv.size()
	check(StallStock.consign(index, 0, t) and Game.profile.inv.size() == bag - 1 and not Game.profile.inv.has(item), "consigning takes the piece from the bag")
	check(int(Game.profile.gold) == gold, "nothing is paid yet")
	var due := int(ceil(t / 60.0)) + StallStock.CONSIGN_MINUTES
	var key := "consign|%d|0" % due
	check(Game.profile.flags.get(key) is int and int(Game.profile.flags[key]) == price, "the consignment is kept in the flags (%s = %s)" % [key, Game.profile.flags.get(key)])
	check(StallStock.consignments().size() == 1 and int(StallStock.consignments()[0].gold) == price, "one consignment out")
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with consignments is valid")
	check(StallStock.collect_consignments(float(due) * 60.0 - 61.0) == 0 and int(Game.profile.gold) == gold and Game.profile.flags.has(key), "not paid before the due time")
	toasts.clear()
	check(StallStock.collect_consignments(float(due) * 60.0) == price and int(Game.profile.gold) == gold + price and not Game.profile.flags.has(key), "paid when due, the key dropped")
	check(toasts.any(func(x): return x == "ได้เงินจากของฝากขาย %d เหรียญ" % price), "a toast tells of the gold (%s)" % [toasts])
	check(StallStock.consignments().is_empty(), "nothing left out")
	# Part of a stack: 3 of 10 bottles go, 7 stay, the payout is for 3; the rest can go
	# whole (count 0) or capped at the stack; the cap of 8; the stall pays the due ones
	# as it opens.
	var stack := ItemData.potion("hp_l", 10)
	Game.profile.inv.append(stack)
	var slot: int = Game.profile.inv.size() - 1
	var unit := StallStock.consign_price(ItemData.potion("hp_l", 1))
	check(StallStock.consign(slot, 3, t) and int(Game.profile.flags.get("consign|%d|0" % due, 0)) == unit * 3, "3 of a stack are consigned for 3 units (%d)" % (unit * 3))
	check(Game.profile.inv.size() == slot + 1 and Game.profile.inv[slot] == stack and int(stack.count) == 7, "7 bottles stay in the bag (%d)" % int(stack.get("count", 0)))
	check(StallStock.consign(slot, 99, t) and int(Game.profile.flags.get("consign|%d|1" % due, 0)) == unit * 7 and Game.profile.inv.size() == slot, "a count over the stack consigns the rest whole (%d)" % (unit * 7))
	Game.profile.inv.append(ItemData.potion("hp_l", 4))
	check(StallStock.consign(slot, 0, t) and int(Game.profile.flags.get("consign|%d|2" % due, 0)) == unit * 4 and Game.profile.inv.size() == slot, "count 0 is the whole stack (%d)" % (unit * 4))
	var owed := unit * 14
	for n in 7:
		var piece := ItemData.generate(40, &"warrior", rng, 2, "ring")
		Game.profile.inv.append(piece)
		var ok := StallStock.consign(Game.profile.inv.size() - 1, 1, t + 60.0 * n)
		if n < StallStock.CONSIGN_MAX - 3:
			owed += StallStock.consign_price(piece)
			check(ok, "consignment %d of %d goes out" % [n + 4, StallStock.CONSIGN_MAX])
		else:
			check(not ok and Game.profile.inv[-1] == piece, "no more than %d consignments at once" % StallStock.CONSIGN_MAX)
	check(StallStock.consignments().size() == StallStock.CONSIGN_MAX, "%d out" % StallStock.CONSIGN_MAX)
	Game.profile.flags["consign|bad"] = 3
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with %d consignments is valid" % StallStock.CONSIGN_MAX)
	gold = int(Game.profile.gold)
	StallStock.open(i, t + 60.0 * (StallStock.CONSIGN_MINUTES + 9))
	check(int(Game.profile.gold) == gold + owed and StallStock.consignments().is_empty() and not Game.profile.flags.has("consign|bad"), "opening a stall pays everything due (%d) and drops a broken key" % owed)
	Game.toast.disconnect(hear)


func _prune(i: int, t: float) -> void:
	var name := String(WorldPlayers.entry(i).name)
	var w := StallStock.window(i, t)
	Game.profile.flags["stall|%s|%d|0" % [name, w - 1]] = 1
	Game.profile.flags["stall|%s|%d|3" % [name, w - 7]] = 1
	Game.profile.flags["stall|NoSuchStall|%d|0" % w] = 1
	Game.profile.flags["loot_mask"] = 31
	var now := StallStock.bought_keys().filter(func(k):
		var bits := String(k).split("|")
		var who := _keeper(bits[1])
		return String(WorldPlayers.entry(who).name) == bits[1] and int(bits[2]) == StallStock.window(who, t))
	StallStock.open(i, t)
	var left := StallStock.bought_keys()
	check(left.size() == now.size() and left.all(func(k): return now.has(k)), "older windows' keys are dropped when a stall opens (%s)" % [left])
	check(int(Game.profile.flags.get("loot_mask", 0)) == 31, "other flags stay")
	Game.profile.flags["haggle|%s|%d|1" % [name, w]] = 2
	StallStock.open(i, StallStock.restock_at(i, t) + StallStock.RESTOCK * 3.0)
	check(StallStock.bought_keys().is_empty() and not Game.profile.flags.keys().any(func(k): return String(k).begins_with("haggle|")), "after the restock nothing old is kept, haggles neither")


func _screen(i: int) -> void:
	var shop := ShopScreen.new()
	add_child(shop)
	await get_tree().process_frame
	Game.profile.gold = 1000000
	shop.open_stall(i)
	await get_tree().process_frame
	var title := shop.find_child("Title", true, false) as Label
	check(title != null and title.text == "ร้านของ %s" % WorldPlayers.entry(i).name, "the screen is the keeper's stall (%s)" % (title.text if title else "?"))
	var lots := StallStock.stock(i)
	var rows := shop.find_children("Lot_*", "", true, false)
	check(rows.size() == lots.size() and lots.size() > 0, "every lot of the stall is listed (%d rows, %d lots)" % [rows.size(), lots.size()])
	var first := rows[0] as Control
	var button := first.find_child("Buy", true, false) as Button
	check(button != null and button.text == "ซื้อ %d" % int(lots[0].price), "a lot shows the stall's price (%s)" % (button.text if button else "?"))
	var sells := shop.find_children("*", "Button", true, false).filter(func(b): return String(b.name) == "Sell")
	if not Game.profile.inv.is_empty():
		check(sells.size() == Game.profile.inv.size() and (sells[0] as Button).text == "ขาย %d" % StallStock.sell_price(Game.profile.inv[0]), "the bag sells at the stall's price")
	var gold := int(Game.profile.gold)
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(int(Game.profile.gold) == gold - int(lots[0].price), "the screen's button buys the lot")
	check(shop.find_children("Lot_*", "", true, false).size() == lots.size() - 1, "and the lot leaves the list")
	# Haggling from the screen: the button goes, the price shown is the haggled one.
	var left := StallStock.stock(i)
	var row := shop.find_children("Lot_%d" % int(left[0].k), "", true, false)[0] as Control
	var haggle := row.find_child("Haggle", true, false) as Button
	check(haggle != null and haggle.text == "ต่อราคา", "a lot offers to haggle")
	haggle.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	row = shop.find_children("Lot_%d" % int(left[0].k), "", true, false)[0] as Control
	var after := int(StallStock.stock(i).filter(func(e): return int(e.k) == int(left[0].k))[0].price)
	check(StallStock.haggled(i, int(left[0].k)) != 0 and row.find_child("Haggle", true, false) == null and row.find_child("Haggled", true, false) != null, "the haggle is done once")
	check((row.find_child("Buy", true, false) as Button).text == "ซื้อ %d" % after, "the row shows the haggled price (%d)" % after)
	# Consigning from the screen: a piece of gear goes whole, a stack has a stepper.
	var consigns := shop.find_children("*", "Button", true, false).filter(func(b): return String(b.name) == "Consign")
	check(consigns.size() == Game.profile.inv.size() and consigns.size() > 0, "every bag slot can be consigned (%d)" % consigns.size())
	var gear_at := -1
	for n in Game.profile.inv.size():
		if not ItemData.is_stackable(Game.profile.inv[n]):
			gear_at = n
			break
	check(gear_at >= 0, "a piece of gear is in the bag")
	var gear_row := shop.find_child("Bag_%d" % gear_at, true, false) as Control
	var gear_button := gear_row.find_child("Consign", true, false) as Button
	check(gear_row.find_child("Qty", true, false) == null and gear_button.text == "ฝากขาย %d" % StallStock.consign_price(Game.profile.inv[gear_at]), "gear has no stepper and goes whole (%s)" % gear_button.text)
	var bag_now: int = Game.profile.inv.size()
	var outstanding := StallStock.consignments().size()
	gear_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.profile.inv.size() == bag_now - 1 and StallStock.consignments().size() == outstanding + 1, "the button consigns the slot")
	check(shop.find_child("ConsignNote", true, false) != null, "the sell list tells what is out on consignment")
	Game.profile.inv.append(ItemData.potion("mp_xl", 10))
	Game.inventory_changed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var stack_at: int = Game.profile.inv.size() - 1
	var stack_row := shop.find_child("Bag_%d" % stack_at, true, false) as Control
	var stack_button := stack_row.find_child("Consign", true, false) as Button
	var plus := stack_row.find_child("QtyPlus", true, false) as Button
	var minus := stack_row.find_child("QtyMinus", true, false) as Button
	var bottle := StallStock.consign_price(ItemData.potion("mp_xl", 1))
	check(plus != null and minus != null and minus.disabled and stack_button.text == "ฝากขาย ×1 %d" % bottle, "a stack starts at one bottle with a stepper (%s)" % stack_button.text)
	plus.pressed.emit()
	check(stack_button.text == "ฝากขาย ×5 %d" % (bottle * 5) and (stack_row.find_child("QtyCount", true, false) as Label).text == "×5", "+ steps to 5 bottles (%s)" % stack_button.text)
	plus.pressed.emit()
	check(stack_button.text == "ฝากขาย ×10 %d" % (bottle * 10) and plus.disabled, "+ is capped at the stack (%s)" % stack_button.text)
	minus.pressed.emit()
	outstanding = StallStock.consignments().size()
	var due_key := StallStock.consignments()[-1].key if outstanding > 0 else ""
	stack_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var out := StallStock.consignments().filter(func(e): return String(e.key) != due_key)
	check(Game.profile.inv.size() == stack_at + 1 and int(Game.profile.inv[stack_at].count) == 5 and out.size() >= 1 and out.any(func(e): return int(e.gold) == bottle * 5), "the button consigns 5 bottles, 5 stay (%s)" % [out])
	var again := shop.find_child("Bag_%d" % stack_at, true, false) as Control
	check(again != null and (again.find_child("Consign", true, false) as Button).text == "ฝากขาย ×5 %d" % (bottle * 5) and (again.find_child("QtyPlus", true, false) as Button).disabled, "the rebuilt row keeps the count, now the whole stack")
	shop.close_shop()
	check(not get_tree().paused and not shop.is_open, "the stall closes")
	# The merchant as before.
	shop.open_shop()
	await get_tree().process_frame
	check(title.text == "ร้านค้า" and shop.stall == -1, "the merchant's screen is the merchant's again")
	var npc_rows := shop.find_children("*", "Button", true, false).filter(func(b): return String(b.name) == "Buy").size()
	check(npc_rows == shop._stock().size(), "the merchant lists its own stock (%d)" % npc_rows)
	var bag_gold := int(Game.profile.gold)
	if not Game.profile.inv.is_empty():
		var price := ItemData.unit_sell_price(Game.profile.inv[0])
		var sell := shop.find_children("*", "Button", true, false).filter(func(b): return String(b.name) == "Sell")
		(sell[0] as Button).pressed.emit()
		check(int(Game.profile.gold) == bag_gold + price, "the merchant pays its own price (%d)" % price)
	shop.close_shop()
	shop.queue_free()
