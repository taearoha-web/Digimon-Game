extends Node
## Trading with the stall keepers (StallStock): a stall's stock is the same for the same
## keeper and restock window, gear a grade above the merchant's at a higher price,
## potions a little cheaper; buying spends the gold, puts the lot in the bag and takes it
## off the stall until the restock; the stall pays more than the merchant for the bag's
## things; the bought-lot flags of older windows are dropped when a stall opens; the shop
## screen opens a stall (open_stall) and the merchant (open_shop) as before.
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
	_prune(i, t)
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


func _prune(i: int, t: float) -> void:
	var name := String(WorldPlayers.entry(i).name)
	var w := StallStock.window(i, t)
	Game.profile.flags["stall|%s|%d|0" % [name, w - 1]] = 1
	Game.profile.flags["stall|%s|%d|3" % [name, w - 7]] = 1
	Game.profile.flags["stall|NoSuchStall|%d|0" % w] = 1
	Game.profile.flags["loot_mask"] = 31
	var now := StallStock.bought_keys().filter(func(k): return k.contains("|%d|" % w) and k.contains(name))
	StallStock.open(i, t)
	var left := StallStock.bought_keys()
	check(left.size() == now.size() and left.all(func(k): return now.has(k)), "older windows' keys are dropped when a stall opens (%s)" % [left])
	check(int(Game.profile.flags.get("loot_mask", 0)) == 31, "other flags stay")
	StallStock.open(i, StallStock.restock_at(i, t) + StallStock.RESTOCK * 3.0)
	check(StallStock.bought_keys().is_empty(), "after the restock nothing old is kept")


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
