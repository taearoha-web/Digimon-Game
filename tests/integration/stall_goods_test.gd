extends Node
## The stall keepers sell goods worth buying (StallStock), matched to their own progress:
## - the + of their gear by progress (plus_band): a newcomer's +1..+9 at most, a veteran's
##   +7..+12 most of the time and a rare +13..+15 showpiece (ของเด่น, is_hot) from ★200;
## - the tiers by progress: star tiers from ★50, 100★ wings from ★100, divine pieces and
##   200★ jewellery from ★200, a very rare 250★ set piece from ★250, the sky isle's goods
##   only from ★300 (the egg rarer than the fragment, rarer than the chest); legendary and
##   mythic more often than not, sockets filled with the gems the class builds on;
## - never the Dragon God's gear, a costume or the guild's legend wings; every lot passes
##   the save checks and may be traded;
## - prices: the forge jewels of the + and the gems are in the price, buying to consign
##   back never pays (even haggled), bulk jewels at the stall's markup; best lots first;
## - the same stock on every call (and for every device: a seed of the keeper and the
##   window); six lots a stall at most; the town is not flooded with +15s;
## - buying with a full bag puts the lot in the storage, and refuses (spending nothing)
##   when both are full; a save with what was bought is valid after a JSON round trip;
## - the stall screen shows the + and the ของเด่น badge.
##   godot --headless --path . res://tests/integration/stall_goods_test.tscn
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
	Game.new_profile(&"warrior", "Goods QA", FaceKit.default_look())
	_prices_of_plus()
	var stats := {}
	for row in [["Lv.10", 10, 0], ["Lv.50", 50, 0], ["Lv.90", 90, 0], ["★30", 100, 30], ["★120", 100, 120], ["★170", 100, 170],
			["★220", 100, 220], ["★270", 100, 270], ["★300", 100, 300]]:
		stats[row[0]] = _bracket(String(row[0]), int(row[1]), int(row[2]))
	_compare(stats)
	_town()
	_full_bag()
	await _screen()
	print("STALL GOODS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


## The forge jewels of a + are in its price, and the price climbs with every step.
func _prices_of_plus() -> void:
	var last := -1
	for plus in range(0, ItemData.MAX_PLUS + 1):
		var v := StallStock.enhance_value(plus)
		check(v > last, "the jewels for +%d are worth more than for +%d (%d)" % [plus, plus - 1, v])
		last = v
	# +6 is six purple jewels, never failing.
	check(StallStock.enhance_value(6) == 6 * int(ItemData.JEWELS.purple.price), "+6 is six purple jewels (%d)" % StallStock.enhance_value(6))
	print("stall_goods_test: jewels for +7 %d, +10 %d, +12 %d, +13 %d, +15 %d" % [StallStock.enhance_value(7), StallStock.enhance_value(10),
		StallStock.enhance_value(12), StallStock.enhance_value(13), StallStock.enhance_value(15)])


## 240 windows of every speciality for a seller of `level` and `stars`: what it lays out.
func _bracket(label: String, level: int, stars: int) -> Dictionary:
	var s := {"gear": 0, "plus": {}, "hot": 0, "rarity": {}, "star": 0, "wings": 0, "star_wings": 0, "divine": 0, "jewelry200": 0,
		"set": 0, "isle": {}, "jewels": {}, "gems": {}, "socketed": 0, "filled_ok": 0, "legacy": 0, "lots": 0, "examples": []}
	var cap := StallStock.gear_cap(level, stars)
	var band := StallStock.plus_band(level, stars)
	var top_plus := int(band.hi)
	for pair in band.show:
		top_plus = maxi(top_plus, int(pair[0]))
	for n in 240:
		var spec: String = StallStock.KINDS.keys()[n % StallStock.KINDS.size()]
		var key := "%s|%d" % [label, n]
		var lots := StallStock.lots_for(key, spec, level, stars, &"warrior")
		if n < 20:
			# Made afresh (not the kept copy): the seed alone decides, as on another device.
			check(_summary(lots) == _summary(StallStock._make_lots(key, spec, level, stars, &"warrior")), "%s: the same lots for the same keeper and window" % label)
			var copy := StallStock.lots_for(key, spec, level, stars, &"warrior")
			copy[0].price = -1
			copy[0].item["plus"] = 99
			check(_summary(lots) == _summary(StallStock.lots_for(key, spec, level, stars, &"warrior")), "%s: a changed copy leaves the stall's lots alone" % label)
		var total := 0
		for v in StallStock.KINDS[spec].values():
			total += int(v)
		check(lots.size() <= total and lots.size() <= 6, "%s: a stall keeps to its %d lots (%d)" % [label, total, lots.size()])
		for k in lots.size() - 1:
			check(not StallStock._better(lots[k + 1], lots[k]), "%s: the best lot first (%d before %d)" % [label, int(lots[k].price), int(lots[k + 1].price)])
		s.lots += lots.size()
		for e in lots:
			var item: Dictionary = e.item
			check(Game._valid_item(item) and OnlineTrade.tradable(item), "%s: %s passes the save checks and may be traded" % [label, ItemData.name_of(item)])
			check(not DragonGearData.is_item(item) and not ItemData.is_costume(item) and not LegendWings.is_item(item), "%s: never the Dragon God's gear, a costume or the legend wings" % label)
			check(bool(e.hot) == StallStock.is_hot(item), "%s: the hot flag is the item's" % label)
			match String(item.get("kind", "")):
				"equip":
					_gear(label, level, stars, cap, top_plus, e, s)
				"jewel":
					s.jewels[String(item.id)] = int(s.jewels.get(String(item.id), 0)) + 1
					if String(item.id) in StallStock.ISLE_GOODS.map(func(p): return String(p[0])):
						s.isle[String(item.id)] = int(s.isle.get(String(item.id), 0)) + 1
					var want := int(round(float(ItemData.JEWELS[item.id].price) * StallStock.JEWEL_MARKUP * int(item.count) * (StallStock.HOT_PREMIUM if bool(e.hot) else 1.0)))
					check(int(e.price) == want, "%s: %s ×%d at the stall's markup (%d, want %d)" % [label, ItemData.name_of(item), int(item.count), int(e.price), want])
					check(int(item.count) >= 1 and int(item.count) <= int(StallStock.BULK.get(String(item.id), [1, 1])[1]), "%s: a bulk lot of %s ×%d" % [label, item.id, int(item.count)])
				"gem":
					var size := int(ItemData.gem_info(item).size)
					s.gems[size] = int(s.gems.get(size, 0)) + 1
					check(size <= StallStock.gem_cap(level, stars), "%s: gems up to its size (%s)" % [label, item.id])
					check(float(e.price) * 0.8 > float(StallStock.consign_price(item) * int(item.count)), "%s: a gem lot haggled down still costs more than it consigns for" % label)
				"potion":
					check(int(e.price) < ItemData.buy_price(item) * int(item.count), "%s: potions under the merchant's price" % label)
	var p := s.plus as Dictionary
	var keys := p.keys()
	keys.sort()
	print("stall_goods_test: %s: %d gear lots, + %s, hot %d, rarity %s, star %d, wings %d (100★ %d), divine %d, 200★ jewellery %d, set %d, legacy %d, socketed %d, isle %s, gems %s" % [
		label, int(s.gear), keys.map(func(k): return "+%d:%d" % [k, p[k]]), int(s.hot), s.rarity, int(s.star), int(s.wings), int(s.star_wings), int(s.divine),
		int(s.jewelry200), int(s.set), int(s.legacy), int(s.socketed), s.isle, s.gems])
	for line in s.examples:
		print("stall_goods_test:   %s" % line)
	return s


func _gear(label: String, level: int, stars: int, cap: int, top_plus: int, e: Dictionary, s: Dictionary) -> void:
	var item: Dictionary = e.item
	var plus := int(item.get("plus", 0))
	s.gear += 1
	s.plus[plus] = int(s.plus.get(plus, 0)) + 1
	s.rarity[int(item.rarity)] = int(s.rarity.get(int(item.rarity), 0)) + 1
	s.hot += 1 if bool(e.hot) else 0
	check(int(item.level) <= cap, "%s: %s Lv.%d within its reach (Lv.%d)" % [label, item.name, int(item.level), cap])
	check(plus <= (StallStock.SET_PLUS_MAX if SetGearData.is_item(item) else top_plus), "%s: %s +%d within its band (+%d)" % [label, item.name, plus, top_plus])
	check(level >= Game.MAX_LEVEL or plus <= 9, "%s: below Lv.100 never +10 or more (+%d)" % [label, plus])
	check(int(item.rarity) >= 2, "%s: above the merchant's grade" % label)
	var gems: Array = item.get("gems", [])
	check(gems.size() <= int(item.sockets) and int(item.sockets) <= ItemData.max_sockets(item), "%s: gems in its sockets (%d of %d)" % [label, gems.size(), int(item.sockets)])
	if not gems.is_empty():
		s.socketed += 1
		var owner := ItemData.gear_class(item)
		owner = owner if ClassData.IDS.has(StringName(owner)) else "warrior"
		var slot := String(item.slot)
		var want := WorldGear.gem_for_slot(owner, "weapon" if slot == "wings" else slot)
		var ok := true
		for k in gems.size():
			var kind := String(gems[k]).split("_")[0]
			ok = ok and (kind == want or (slot == "ring" and k == 0 and kind == String(WorldGear.gem_plan(owner).special)))
			ok = ok and int(String(gems[k]).split("_")[1]) <= StallStock.gem_cap(level, stars)
		check(ok, "%s: %s carries the gems its class builds on (%s)" % [label, item.name, gems])
	if SetGearData.is_item(item):
		s.set += 1
		check(stars >= SetGearData.STARS, "%s: a set piece only from ★250" % label)
	elif DivineGearData.is_item(item):
		s.divine += 1
		check(stars >= DivineGearData.STARS, "%s: a divine piece only from ★200" % label)
	elif StarWingData.is_wing(item):
		s.star_wings += 1
		s.wings += 1
		check(stars >= StarWingData.REQUIRED_STARS, "%s: 100★ wings only from ★100" % label)
	elif String(item.slot) == "wings":
		s.wings += 1
		check(level >= Game.MAX_LEVEL, "%s: wings only from Lv.100" % label)
	elif item.has("star_tier"):
		s.star += 1
		check(stars >= int(item.star_tier), "%s: ★%d gear only from ★%d" % [label, int(item.star_tier), int(item.star_tier)])
		if int(item.star_tier) == 200 and String(item.slot) in ["ring", "amulet"]:
			s.jewelry200 += 1
	else:
		s.legacy += 1
		check(level < Game.MAX_LEVEL or stars < int(StarProgression.TIERS[0]) or String(item.slot) != "", "%s: older gear" % label)
	# Price: the jewels of the + and the gems are in it, haggled 20% off it still costs
	# more than the stall pays back for it (and its gems) on consignment.
	var resale := StallStock.consign_price(item)
	for g in gems:
		resale += StallStock.consign_price(ItemData.gem(String(g).split("_")[0], int(String(g).split("_")[1])))
	check(float(e.price) * 0.8 > float(resale), "%s: %s +%d haggled still dearer than its consignment (%d vs %d)" % [label, item.name, plus, int(e.price), resale])
	check(int(e.price) >= int(float(StallStock.enhance_value(plus)) * StallStock.ENHANCE_MARGIN), "%s: the + is paid for (+%d, %d)" % [label, plus, int(e.price)])
	check(int(e.price) > ItemData.buy_price(item) and int(e.price) > StallStock.sell_price(item), "%s: dearer than the merchant and what a stall pays" % label)
	var showcase := SetGearData.is_item(item) or plus >= 14 or (DivineGearData.is_item(item) and plus >= 12)
	if ((s.examples as Array).size() < 3 and (plus >= 10 or (s.examples as Array).is_empty())) or (showcase and (s.examples as Array).size() < 7):
		s.examples.append("%s%s (%s %s, %d gems) %s" % ["[ของเด่น] " if bool(e.hot) else "", ItemData.name_of(item), ItemData.RARITY_NAMES[int(item.rarity)],
			ItemData.level_text(int(item.level)), gems.size(), PlayerStall.thousands(int(e.price))])


func _share(s: Dictionary, lo: int, hi: int) -> float:
	var n := 0
	for k in s.plus:
		if int(k) >= lo and int(k) <= hi:
			n += int(s.plus[k])
	return float(n) / maxf(1.0, float(s.gear))


func _compare(st: Dictionary) -> void:
	var newb: Dictionary = st["Lv.10"]
	var vet: Dictionary = st["★300"]
	check(_share(newb, 1, 4) > 0.85 and _share(newb, 7, 15) == 0.0, "a Lv.10 keeper sells +1..+4, never +7 (%.2f)" % _share(newb, 1, 4))
	check(_share(st["Lv.50"], 3, 8) == 1.0 and _share(st["Lv.90"], 4, 9) == 1.0, "Lv.50 and Lv.90 keepers: good + for their level")
	for label in ["★220", "★270", "★300"]:
		var s: Dictionary = st[label]
		var show := _share(s, 13, 15)
		check(_share(s, 7, 12) > 0.85, "%s: +7..+12 most of the time (%.2f)" % [label, _share(s, 7, 12)])
		check(show > 0.01 and show < 0.12, "%s: +13..+15 now and then (%.3f)" % [label, show])
		check(_share(s, 15, 15) < 0.025, "%s: a +15 is rare (%.3f)" % [label, _share(s, 15, 15)])
		check(int(s.divine) > 0 and int(s.jewelry200) > 0 and int(s.star_wings) > 0, "%s: divine pieces, 200★ jewellery and 100★ wings (%d, %d, %d)" % [label, int(s.divine), int(s.jewelry200), int(s.star_wings)])
		var legend := int(s.rarity.get(3, 0)) + int(s.rarity.get(4, 0))
		check(float(legend) / float(s.gear) > 0.75 and int(s.rarity.get(4, 0)) > 0, "%s: legendary and mythic most of the time (%s)" % [label, s.rarity])
		check(float(s.socketed) / float(s.gear) > 0.6, "%s: most pieces come socketed (%d of %d)" % [label, int(s.socketed), int(s.gear)])
		check(int(s.legacy) == 0, "%s: no old Lv.100-120 gear (%d)" % [label, int(s.legacy)])
	check(int(st["★220"].set) == 0 and int(st["★270"].set) + int(vet.set) > 0, "set pieces only from ★250, and they do appear (%d, %d)" % [int(st["★270"].set), int(vet.set)])
	check(float(int(st["★270"].set) + int(vet.set)) / float(int(st["★270"].gear) + int(vet.gear)) < 0.05, "a set piece is very rare")
	check((vet.isle as Dictionary).has("dragon_chest") and int(vet.isle.get("sky_dragon_egg", 0)) <= int(vet.isle.get("dragon_chest", 0)), "a ★300 keeper sells the isle's chests, the egg rarer (%s)" % [vet.isle])
	for label in st:
		if label != "★300":
			check((st[label].isle as Dictionary).is_empty(), "%s: no sky isle goods below ★300 (%s)" % [label, st[label].isle])
	check(int(st["★120"].star_wings) > 0 and int(st["★120"].divine) == 0 and int(st["★120"].star) > 0, "★120: star gear and 100★ wings, no divine piece")
	check(int(st["★30"].star) == 0 and int(st["★30"].star_wings) == 0, "★30: no star tier gear yet")
	for label in ["Lv.10", "Lv.50", "Lv.90"]:
		var s: Dictionary = st[label]
		check(int(s.wings) + int(s.star) + int(s.divine) + int(s.set) == 0, "%s: no endgame gear" % label)
		check(float(int(s.rarity.get(3, 0)) + int(s.rarity.get(4, 0))) / float(s.gear) > 0.4, "%s: still good pieces, legendary often (%s)" % [label, s.rarity])
	check((vet.jewels as Dictionary).has("chaos") and (vet.jewels as Dictionary).has("feather") and (vet.jewels as Dictionary).has("lotus_scale") and (vet.jewels as Dictionary).has("set_core") and (vet.jewels as Dictionary).has("dragon_scale"), "a veteran sells chaos jewels, feathers, Lotus Scales, set cores and dragon scales (%s)" % [vet.jewels])
	check(int((vet.gems as Dictionary).get(ItemData.GEM_MAX_SIZE, 0)) > 0 and int((vet.gems as Dictionary).get(3, 0)) > 0, "and perfect and legendary gems (%s)" % [vet.gems])


## The town now: every keeper's stall, the + and the hot lots across it.
func _town() -> void:
	var t := WorldPresence.clock()
	var counts := {}
	var plus15 := 0
	var hot := 0
	var keepers := 0
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not WorldPlayers.in_town_style(i) and String(s.doing) != "stall":
			continue
		keepers += 1
		var who := StallStock.seller(i, t)
		var lots := StallStock.full_stock(i, t)
		check(lots.size() <= 6, "%s: six lots at most (%d)" % [WorldPlayers.entry(i).name, lots.size()])
		var best: Dictionary = lots[0] if not lots.is_empty() else {}
		for e in lots:
			if String(e.item.get("kind", "")) == "equip":
				var plus := int(e.item.get("plus", 0))
				counts[plus] = int(counts.get(plus, 0)) + 1
				plus15 += 1 if plus == 15 else 0
			hot += 1 if bool(e.hot) else 0
		if not best.is_empty():
			print("stall_goods_test: town: %s (Lv.%d ★%d, %s): %s%s %s" % [WorldPlayers.entry(i).name, int(who.level), int(who.stars), StallStock.specialty(i),
				"[ของเด่น] " if bool(best.hot) else "", ItemData.name_of(best.item), PlayerStall.thousands(int(best.price))])
	print("stall_goods_test: town now: %d keepers, + of gear %s, %d hot lots" % [keepers, counts, hot])
	check(keepers >= 10, "the town's keepers are checked (%d)" % keepers)
	check(plus15 <= 2, "the town is not flooded with +15s (%d)" % plus15)


## Buying with a full bag: into the storage; with both full: refused, nothing spent.
func _full_bag() -> void:
	var i := -1
	var t := WorldPresence.clock()
	for n in WorldPlayers.size():
		if WorldPlayers.in_town_style(n) and StallStock.stock(n, t).any(func(e): return String(e.item.get("kind", "")) == "equip"):
			i = n
			break
	check(i >= 0, "a keeper with gear")
	if i < 0:
		return
	var lots := StallStock.stock(i, t).filter(func(e): return String(e.item.get("kind", "")) == "equip")
	var lot: Dictionary = lots[0]
	var keep: Array = SharedStorage.items().duplicate(true)
	SharedStorage.items().clear()
	Game.profile.inv.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(20, &"warrior", rng, 1, "helm"))
	Game.profile.gold = int(lot.price) + 7
	check(StallStock.buy(i, int(lot.k), t), "buys with a full bag")
	check(int(Game.profile.gold) == 7 and SharedStorage.items().size() == 1 and ItemData.name_of(SharedStorage.items()[0]) == ItemData.name_of(lot.item), "the lot goes to the storage and the price is paid")
	check(not StallStock.stock(i, t).any(func(e): return int(e.k) == int(lot.k)), "and leaves the stall")
	while not SharedStorage.full():
		SharedStorage.items().append(ItemData.generate(20, &"warrior", rng, 1, "boots"))
	var next: Array = StallStock.stock(i, t)
	if not next.is_empty():
		var other: Dictionary = next[0]
		var stacks: bool = ItemData.is_stackable(other.item) and (Game.profile.inv.any(func(x): return x.get("id", "") == other.item.get("id", "x")))
		Game.profile.gold = int(other.price) + 7
		var gold := int(Game.profile.gold)
		if not stacks:
			check(not StallStock.buy(i, int(other.k), t) and int(Game.profile.gold) == gold and StallStock.stock(i, t).any(func(e): return int(e.k) == int(other.k)), "bag and storage full: refused, nothing spent, the lot stays")
	SharedStorage.items().clear()
	SharedStorage.items().append_array(keep)
	# Every kind of lot a veteran sells survives a save: bought into the bag, through JSON.
	Game.profile.inv.clear()
	var added := 0
	for n in 60:
		for e in StallStock.lots_for("save|%d" % n, StallStock.KINDS.keys()[n % 5], 100, 300, &"warrior"):
			if Game.inventory_free() > 0 and (bool(e.hot) or int(e.item.get("plus", 0)) >= 12 or added < 20):
				var item: Dictionary = (e.item as Dictionary).duplicate(true)
				Game.add_item(item)
				added += 1
	check(added > 20, "a bag of a veteran's goods (%d)" % added)
	var raw: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(raw is Dictionary, "the save is JSON")
	if raw is Dictionary:
		var repaired: Dictionary = Game._repair(raw)
		check(Game._valid_profile(repaired), "a save holding a veteran's goods is valid after a round trip")
		check(SharedStorage.valid_items(Game.profile.inv.duplicate(true)), "and the storage would take them too")
	Game.profile.inv.clear()


## The stall screen: the + on the icon and the ของเด่น badge, the best lot first.
func _screen() -> void:
	var t := WorldPresence.clock()
	var shop := ShopScreen.new()
	add_child(shop)
	await get_tree().process_frame
	Game.profile.gold = 100000000
	var keeper := -1
	for n in WorldPlayers.size():
		if (WorldPlayers.in_town_style(n) or String(WorldPlayers.state(n, t).doing) == "stall") and StallStock.stock(n, t).any(func(e): return int(e.item.get("plus", 0)) > 0):
			keeper = n
			if StallStock.stock(n, t).any(func(e): return bool(e.hot)):
				break
	check(keeper >= 0, "a stall with forged gear")
	if keeper >= 0:
		shop.open_stall(keeper)
		await get_tree().process_frame
		var lots := StallStock.stock(keeper)
		var rows := shop.find_children("Lot_*", "", true, false)
		check(rows.size() == lots.size() and String(rows[0].name) == "Lot_%d" % int(lots[0].k), "the rows follow the stall's order, the best first")
		for k in rows.size():
			var plus := int(lots[k].item.get("plus", 0))
			var badge := rows[k].find_child("PlusBadge", true, false)
			check((badge != null) == (plus > 0), "a lot shows its + on the icon (+%d)" % plus)
			if badge != null:
				check(((badge as Control).get_child(0) as Label).text == "+%d" % plus, "the badge reads +%d" % plus)
			check((rows[k].find_child("HotBadge", true, false) != null) == bool(lots[k].hot), "the ของเด่น badge on a showpiece only")
	shop.close_shop()
	shop.queue_free()


static func _summary(lots: Array[Dictionary]) -> Array:
	return lots.map(func(e): return "%d|%s|%s|%s|%d|%d|%d" % [int(e.k), ItemData.name_of(e.item), JSON.stringify(e.item.get("stats", {})), JSON.stringify(e.item.get("gems", [])),
		int(e.item.get("count", 1)), int(e.item.get("plus", 0)), int(e.price)])
