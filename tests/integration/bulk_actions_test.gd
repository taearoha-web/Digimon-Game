extends Node
## Bulk actions: selling a stack of 1000 potions in one sale, the gear multi-select
## (Game.bulk_sell_lock / bulk_sell_pick / sell_many) never taking enhanced, socketed or
## special pieces, "รวมหลายครั้ง" / "ผสมต่อจนสุด" (Game.fuse_gems_many / fuse_gems_chain)
## consuming exactly what single fuses would with the real odds (seeded), the storage's
## "ฝากทั้งหมด" / "เบิกทั้งหมด" in one write, the mount's "ทำหลายครั้ง", and the count
## chooser (QtyPicker) itself.
##   godot --headless --path . res://tests/integration/bulk_actions_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _gear(rarity: int, seed_text: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var item := ItemData.generate(40, &"warrior", rng, rarity, "armor")
	item["set"] = ""
	item["plus"] = 0
	item["gems"] = []
	return item


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true


func _count(kind: String, id: String) -> int:
	var n := 0
	for it in Game.profile.inv:
		if it.get("kind", "") == kind and String(it.get("id", "")) == id:
			n += int(it.get("count", 1))
	return n


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "ขายส่งQA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.bag_slots = Game.MAX_BAG
	_sell_potions()
	_gear_multi_select()
	_fuse_many()
	_storage_moves()
	_mount_many()
	await _picker()
	_sell_next()
	check(Game._valid_profile(Game.profile), "the profile still validates for the save / cloud path after every bulk action")
	print("BULK ACTIONS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _sell_potions() -> void:
	Game.profile.inv.clear()
	Game.profile.gold = 0
	Game.add_item(ItemData.potion("hp_s", 1200))
	var unit := ItemData.unit_sell_price(Game.profile.inv[0])
	var signals := [0]
	var on_bag := func(): signals[0] += 1
	Game.inventory_changed.connect(on_bag)
	Game.sell_item(0, 1000)
	Game.inventory_changed.disconnect(on_bag)
	check(_count("potion", "hp_s") == 200, "1000 of 1200 potions sold in one sale (%d left)" % _count("potion", "hp_s"))
	check(int(Game.profile.gold) == unit * 1000, "gold is 1000 × the bottle's price (%d)" % int(Game.profile.gold))
	check(signals[0] == 1, "one bag refresh for the whole sale (%d)" % signals[0])
	Game.sell_item(0, 200)
	check(Game.profile.inv.is_empty() and int(Game.profile.gold) == unit * 1200, "selling the rest empties the slot")
	# Many stacks and pieces in one call: whole stacks.
	Game.add_item(ItemData.potion("mp_s", 50))
	Game.add_item(ItemData.jewel("purple", 30))
	var want := ItemData.sell_price(Game.profile.inv[0]) + ItemData.sell_price(Game.profile.inv[1])
	var before := int(Game.profile.gold)
	var r := Game.sell_many([0, 1, 1, 7])
	check(int(r.count) == 2 and int(r.gold) == want and int(Game.profile.gold) == before + want and Game.profile.inv.is_empty(), "sell_many sells whole stacks once each and ignores bad indices")


func _gear_multi_select() -> void:
	Game.profile.inv.clear()
	var plain0 := _gear(0, "a")
	var plain1 := _gear(1, "b")
	var plain2 := _gear(2, "c")
	var legend := _gear(3, "d")
	var enhanced := _gear(0, "e")
	enhanced["plus"] = 3
	var socketed := _gear(1, "f")
	socketed["sockets"] = 1
	socketed["gems"] = ["ruby_0"]
	var set_piece := _gear(1, "g")
	set_piece["set"] = "wolf"
	var star := _gear(0, "h")
	star["star_tier"] = StarGearData.TIERS[0]
	var dragon := DragonGearData.wings("warrior", RandomNumberGenerator.new())
	var wings := _gear(0, "i")
	wings["slot"] = "wings"
	var worn := _gear(0, "worn")
	Game.profile.equip["armor"] = worn
	for it in [plain0, plain1, plain2, legend, enhanced, socketed, set_piece, star, dragon, wings, ItemData.potion("hp_s", 5)]:
		Game.profile.inv.append(it)
	check(Game.bulk_sell_lock(plain0) == "" and Game.bulk_sell_lock(legend) == "", "plain gear can be picked")
	for it in [enhanced, socketed, set_piece, star, dragon, wings]:
		check(Game.bulk_sell_lock(it) != "", "never picked: %s (%s)" % [ItemData.name_of(it), Game.bulk_sell_lock(it)])
	check(_same(Game.bulk_sell_pick(0), [0]), "≤ ธรรมดา picks the plain common piece only")
	check(_same(Game.bulk_sell_pick(1), [0, 1]), "≤ ดี picks common and good")
	check(_same(Game.bulk_sell_pick(4), [0, 1, 2]), "quick picks stop at หายาก (no legendary)")
	var want := ItemData.sell_price(plain0) + ItemData.sell_price(plain1) + ItemData.sell_price(plain2)
	var before := int(Game.profile.gold)
	# Every index offered: the locked pieces stay, so does the worn piece (never in the bag).
	var r := Game.sell_many(range(Game.profile.inv.size()).filter(func(i): return Game.profile.inv[i].get("kind", "") == "equip"))
	check(int(r.count) == 4 and int(Game.profile.gold) == before + want + ItemData.sell_price(legend), "multi-select sells the four plain pieces (%d)" % int(r.count))
	for it in [enhanced, socketed, set_piece, star, dragon, wings]:
		check(Game.profile.inv.has(it), "kept: %s" % ItemData.name_of(it))
	check(Game.profile.equip.get("armor") == worn, "the worn piece is untouched")
	check(_count("potion", "hp_s") == 5, "the potions were not part of the gear sale")
	Game.profile.equip.erase("armor")


func _fuse_many() -> void:
	Game.profile.inv.clear()
	# A sure size (small -> medium): 30 gems -> 10 tries, 10 medium, 2000 gold.
	Game.add_item(ItemData.gem("ruby", 0, 31))
	Game.profile.gold = 100000
	check(Game.fuse_gem_max_tries("ruby_0") == 10, "max tries of a sure size: gems / 3")
	var r := Game.fuse_gems_many("ruby_0", -1)
	check(int(r.tries) == 10 and int(r.ok) == 10 and int(r.used) == 30, "ผสมทั้งหมด: 10 tries, 10 made, 30 used")
	check(_count("gem", "ruby_0") == 1 and _count("gem", "ruby_1") == 10, "1 small left, 10 medium made")
	check(int(Game.profile.gold) == 100000 - 10 * int(ItemData.GEM_FUSE_GOLD[0]), "gold spent = 10 tries")
	# A risky size (large -> perfect, 70%), seeded: the same dice as single fuses.
	Game.profile.inv.clear()
	Game.add_item(ItemData.gem("emerald", 2, 300))
	Game.profile.gold = 100000000
	Game.rng.seed = 4242
	var expect_ok := 0
	var expect_fail := 0
	var have := 300
	var dice := RandomNumberGenerator.new()
	dice.seed = 4242
	while have >= 3:
		if dice.randf() < float(ItemData.GEM_FUSE_CHANCE[2]):
			expect_ok += 1
			have -= 3
		else:
			expect_fail += 1
			have -= 1
	var gold0 := int(Game.profile.gold)
	var many := Game.fuse_gems_many("emerald_2", -1)
	check(int(many.ok) == expect_ok and int(many.fail) == expect_fail, "seeded: %d ok / %d fail as single fuses would roll" % [int(many.ok), int(many.fail)])
	check(_count("gem", "emerald_2") == have and _count("gem", "emerald_3") == expect_ok, "left %d large, made %d perfect" % [_count("gem", "emerald_2"), _count("gem", "emerald_3")])
	check(int(many.used) == 3 * expect_ok + expect_fail and int(many.used) == 300 - have, "used = 3 per hit + 1 per miss")
	check(gold0 - int(Game.profile.gold) == int(many.tries) * int(ItemData.GEM_FUSE_GOLD[2]), "gold = tries × the fee")
	var rate := float(many.ok) / float(many.tries)
	check(absf(rate - 0.7) < 0.12, "success rate near 70%% (%.2f over %d)" % [rate, int(many.tries)])
	# A fixed count stops there; gold limits too.
	Game.profile.inv.clear()
	Game.add_item(ItemData.gem("topaz", 1, 60))
	Game.profile.gold = int(ItemData.GEM_FUSE_GOLD[1]) * 4 + 10
	var some := Game.fuse_gems_many("topaz_1", 7)
	check(int(some.tries) == 4 and String(some.stopped) == "เงินไม่พอ" and int(Game.profile.gold) == 10, "stops when the gold runs out (4 of 7)")
	Game.profile.gold = 100000
	var three := Game.fuse_gems_many("topaz_1", 3)
	check(int(three.tries) == 3 and _count("gem", "topaz_1") == 60 - 12 - 9, "a count of 3 makes 3 tries")
	check(Game.fuse_gems_many("topaz_4", -1).tries == 0, "the top size cannot fuse")
	# ผสมต่อจนสุด: small -> medium -> large ... as far as it goes.
	Game.profile.inv.clear()
	Game.add_item(ItemData.gem("sapphire", 0, 81))
	Game.profile.gold = 100000000
	var steps := Game.fuse_gems_chain("sapphire_0")
	check(steps.size() >= 3 and int(steps[0].ok) == 27 and int(steps[1].ok) == 9, "chain: 81 small -> 27 medium -> 9 large -> ...")
	check(_count("gem", "sapphire_0") == 0 and _count("gem", "sapphire_1") == 0, "the small and medium gems all went up")


func _storage_moves() -> void:
	Game.profile.inv.clear()
	SharedStorage.items().clear()
	Game.add_item(ItemData.jewel("purple", 10))
	Game.add_item(ItemData.gem("ruby", 1, 4))
	Game.add_item(ItemData.potion("hp_s", 9))
	Game.add_item(_gear(1, "store"))
	check(_same(Game.material_indices(), [0, 1]), "materials: the jewel and the gem")
	var r := Game.deposit_many(Game.material_indices())
	check(int(r.moved) == 2 and Game.profile.inv.size() == 2 and SharedStorage.size() == 2, "ฝากวัตถุดิบ moves both stacks")
	r = Game.deposit_many(range(Game.profile.inv.size()))
	check(int(r.moved) == 2 and Game.profile.inv.is_empty() and SharedStorage.size() == 4, "ฝากทั้งหมด empties the bag")
	var other := _gear(1, "mage")
	other["class"] = "mage"
	SharedStorage.items().append(other)
	Game.add_item(ItemData.jewel("purple", 5))
	r = Game.withdraw_all()
	var locked := Game.storage_lock(other) != ""
	check(int(r.moved) == (4 if locked else 5) and SharedStorage.size() == (1 if locked else 0) and locked, "เบิกทั้งหมด takes all but another class's gear (moved %d, left %d)" % [int(r.moved), SharedStorage.size()])
	check(_count("jewel", "purple") == 15, "a stack joins the bag's pile (15 purple)")
	SharedStorage.items().clear()


func _mount_many() -> void:
	var id := String(MountData.MOUNTS.keys()[0])
	Game.profile.inv.clear()
	Game.add_item(ItemData.jewel(MountData.mat_of(id), 40))
	Game.add_item(ItemData.jewel("chaos", 400))
	var mats0 := Game.mount_mats(id)
	var chaos0 := Game.jewel_count("chaos")
	var lv0 := Game.mount_level(id)
	check(Game.mount_max_tries(id) >= 2, "a mount with materials can take several tries")
	var r := Game.craft_mount_many(id, 50)
	check(int(r.to) - lv0 == int(r.ok) and int(r.tries) == int(r.ok) + int(r.fail), "levels gained = hits (%d tries, %d ok)" % [int(r.tries), int(r.ok)])
	# Each try cost exactly one tap: level L+1 costs L+1 materials.
	var spent := mats0 - Game.mount_mats(id)
	check(spent >= int(r.tries) and spent <= int(r.tries) * MountData.MAX_LEVEL, "materials spent fit the tries (%d)" % spent)
	check(chaos0 >= Game.jewel_count("chaos"), "chaos spent")
	check(int(r.to) == MountData.MAX_LEVEL or String(r.stopped) != "", "stops at the top or when it cannot pay")


func _picker() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	QtyPicker.pick(host, "ขายยาเลือดเล็ก", 1000, func(n: int): return "ได้ %d" % (n * 5), "ขาย")
	await get_tree().process_frame
	var picker := host.get_node_or_null("QtyPicker") as QtyPicker
	check(picker != null, "the chooser opens")
	if picker == null:
		return
	var got := [-1]
	picker.closed.connect(func(c: int): got[0] = c)
	(picker.find_child("StepPlus100", true, false) as Button).pressed.emit()
	(picker.find_child("StepPlus10", true, false) as Button).pressed.emit()
	check(picker.count == 111, "+100 +10 from 1 is 111 (%d)" % picker.count)
	(picker.find_child("StepMinus1", true, false) as Button).pressed.emit()
	check(picker.count == 110, "−1 steps back (%d)" % picker.count)
	(picker.find_child("QtyAll", true, false) as Button).pressed.emit()
	check(picker.count == 1000 and (picker.find_child("StepPlus1", true, false) as Button).disabled, "ทั้งหมด picks the whole stack; + greys out")
	check((picker.find_child("QtyLine", true, false) as Label).text == "ได้ 5000", "the live line follows the count")
	(picker.find_child("QtyConfirm", true, false) as Button).pressed.emit()
	check(got[0] == 1000, "confirm returns the count (%d)" % got[0])
	await get_tree().process_frame
	host.queue_free()


## Selling a piece in the bag picks the tile shown right after it (the bag is shown sorted,
## GameMenu.bag_order), so "ขาย" can be tapped again for the next one.
func _sell_next() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	Game.profile.inv = []
	# Mixed pickup order: gear, a gem, gear, a potion, gear.
	Game.profile.inv.append(ItemData.generate(30, &"warrior", rng, 0, "helm"))
	Game.add_item(ItemData.gem("ruby", 1))
	Game.profile.inv.append(ItemData.generate(31, &"warrior", rng, 0, "boots"))
	Game.add_item(ItemData.potion("hp_s", 3))
	Game.profile.inv.append(ItemData.generate(32, &"warrior", rng, 0, "armor"))
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	var order := GameMenu.bag_order(Game.profile.inv)
	# Pick the first gear tile shown, then sell it: the next shown tile is picked.
	var at := -1
	for k in order.size():
		if String(Game.profile.inv[order[k]].get("kind", "")) not in ["gem", "potion", "jewel"]:
			at = k
			break
	check(at >= 0 and at + 1 < order.size(), "a gear tile with another after it (%s)" % [order])
	if at < 0 or at + 1 >= order.size():
		menu.queue_free()
		return
	var next_item: Dictionary = Game.profile.inv[order[at + 1]]
	menu._selected_index = order[at]
	menu._sell_selected(1)
	check(menu._selected_index >= 0 and Game.profile.inv[menu._selected_index] == next_item, "after a sale the next tile shown is picked (%d)" % menu._selected_index)
	# The last tile: the one before it is picked.
	order = GameMenu.bag_order(Game.profile.inv)
	var before_last: Dictionary = Game.profile.inv[order[order.size() - 2]]
	menu._selected_index = order[order.size() - 1]
	menu._sell_selected(int(Game.profile.inv[order[order.size() - 1]].get("count", 1)))
	check(menu._selected_index >= 0 and Game.profile.inv[menu._selected_index] == before_last, "selling the last tile picks the one before it")
	menu.close_menu()
	menu.queue_free()
