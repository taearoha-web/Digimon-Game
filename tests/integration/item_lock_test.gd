extends Node
## The item lock ("ล็อก", ItemData.LOCK_KEY): a locked bag / storage item is never sold
## (one, a count, multi-select and its quick picks, the merchant's bulk buttons, auto-sell,
## a stall keeper), set on the hero's stall, offered in a trade, or used up as a material
## (forging jewels, gem fuses and sockets, set crafting's divine piece); it keeps its lock
## through storage moves (a locked stack's pile stays locked), save / load and the cloud
## validator; the bag tile shows a padlock and the detail panel "ล็อก / ปลดล็อก".
##   godot --headless --path . res://tests/integration/item_lock_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _gear(rarity: int, seed_text: String, slot := "armor") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var item := ItemData.generate(40, &"warrior", rng, rarity, slot)
	item["set"] = ""
	item["plus"] = 0
	item["gems"] = []
	return item


func _has(item: Dictionary) -> bool:
	return Game.profile.inv.any(func(e): return is_same(e, item))


func _count(kind: String, id: String) -> int:
	var n := 0
	for it in Game.profile.inv:
		if it.get("kind", "") == kind and String(it.get("id", "")) == id:
			n += int(it.get("count", 1))
	return n


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.store()
	Game.slot = 1
	Game.new_profile(&"warrior", "ล็อกQA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.bag_slots = Game.MAX_BAG
	_toggle()
	_selling()
	_stall_and_trade()
	_materials()
	_set_craft()
	_storage()
	_save_and_cloud()
	await _ui()
	check(Game._valid_profile(Game.profile), "the profile still validates")
	print("ITEM LOCK: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _toggle() -> void:
	var sword := _gear(1, "toggle", "weapon")
	check(not ItemData.is_locked(sword) and ItemData.can_lock(sword), "a new piece is unlocked and can be locked")
	check(Game.toggle_item_lock(sword) and sword.get("lock") == true, "ล็อก sets lock: true")
	check(not Game.toggle_item_lock(sword) and not sword.has("lock"), "ปลดล็อก removes the field")
	check(ItemData.can_lock(ItemData.potion("hp_s", 3)) and ItemData.can_lock(ItemData.gem("ruby", 1, 2)) and ItemData.can_lock(ItemData.jewel("chaos", 1)), "stackables can be locked too")
	check(not ItemData.can_lock({"kind": "costume", "id": "x", "rarity": 1}), "a costume (never sold) has no lock")
	check(not Game._valid_item(_with(sword, false)), "a lock that is not true is refused on load")
	check(Game._valid_item(_with(sword, true)), "lock: true loads")


func _with(item: Dictionary, value: Variant) -> Dictionary:
	var copy := item.duplicate(true)
	copy["lock"] = value
	return copy


func _selling() -> void:
	Game.profile.inv.clear()
	Game.profile.gold = 0
	var locked := _gear(0, "sell-locked")
	var free := _gear(0, "sell-free")
	ItemData.set_locked(locked, true)
	Game.profile.inv.append_array([locked, free])
	var potions := ItemData.potion("hp_s", 50)
	ItemData.set_locked(potions, true)
	Game.profile.inv.append(potions)
	Game.sell_item(0, 1)
	check(_has(locked) and int(Game.profile.gold) == 0, "a single sale refuses a locked piece")
	Game.sell_item(2, 30)
	check(_count("potion", "hp_s") == 50 and int(Game.profile.gold) == 0, "the count chooser's sale refuses a locked stack")
	check(Game.bulk_sell_lock(locked) != "", "multi-select cannot pick a locked piece (%s)" % Game.bulk_sell_lock(locked))
	check(Game.bulk_sell_lock(potions) != "", "nor a locked stack")
	check(not Game.bulk_sell_pick(2).has(0) and Game.bulk_sell_pick(2).has(1), "the quick picks / merchant's ≤ buttons skip it and keep the unlocked one")
	var result := Game.sell_many([0, 1, 2])
	check(int(result.count) == 1 and _has(locked) and _count("potion", "hp_s") == 50 and not _has(free), "sell_many sells only the unlocked piece")
	Game.profile.inv.append(_gear(0, "auto-free"))
	var picks := Game.auto_sell_indices(31, 0)
	check(picks.size() == 1 and not is_same(Game.profile.inv[picks[0]], locked), "ขายอัตโนมัติ never takes a locked piece")
	Game.auto_sell(31, 0)
	check(_has(locked), "and the locked piece stays after auto-sell")
	check(not StallStock.sell(0, 1) and _has(locked), "a stall keeper does not buy it")
	check(not StallStock.consign(0, 1) and _has(locked), "nor take it on consignment")
	Game.toggle_item_lock(locked)
	var gold := int(Game.profile.gold)
	Game.sell_item(Game.profile.inv.find(locked), 1)
	check(not _has(locked) and int(Game.profile.gold) > gold, "unlocked, it sells again")


func _stall_and_trade() -> void:
	Game.profile.inv.clear()
	var piece := _gear(1, "stall")
	ItemData.set_locked(piece, true)
	Game.profile.inv.append(piece)
	var lots: int = PlayerStall.state().lots.size()
	var price := PlayerStall.clamp_price(piece, PlayerStall.fair_price(piece))
	check(PlayerStall.list_item(0, price) == -1 and _has(piece) and PlayerStall.state().lots.size() == lots, "a locked piece is not set on the stall")
	check(not OnlineTrade.tradable(piece), "nor traded")
	var gems := ItemData.gem("ruby", 1, 5)
	ItemData.set_locked(gems, true)
	Game.profile.inv.append(gems)
	check(OnlineTrade._bag_count(gems) == 0, "a trade never takes from a locked stack")
	ItemData.set_locked(piece, false)
	check(OnlineTrade.tradable(piece) and PlayerStall.list_item(0, price) > 0 and not _has(piece), "unlocked, it lists")


func _materials() -> void:
	Game.profile.inv.clear()
	Game.profile.gold = 10000000
	var chaos := ItemData.jewel("chaos", 5)
	ItemData.set_locked(chaos, true)
	Game.profile.inv.append(chaos)
	check(Game.jewel_count("chaos") == 0, "a locked jewel stack counts as none for crafting")
	Game._spend_jewels("chaos", 3)
	check(int(chaos.count) == 5 and _has(chaos), "and is never spent")
	var rubies := ItemData.gem("ruby", 0, 9)
	ItemData.set_locked(rubies, true)
	Game.profile.inv.append(rubies)
	check(Game.gem_total("ruby_0") == 0 and Game.fuse_gem_max_tries("ruby_0") == 0, "locked gems are not fused")
	check(Game.fuse_gem("ruby_0") != "ok" and int(rubies.count) == 9, "a single fuse refuses them")
	var many := Game.fuse_gems_many("ruby_0", -1)
	check(int(many.tries) == 0 and int(rubies.count) == 9, "fuse many leaves them")
	var helm := _gear(1, "socket", "helm")
	helm["sockets"] = 2
	Game.profile.inv.append(helm)
	check(not Game.socket_gem(helm, Game.profile.inv.find(rubies)) and (helm.gems as Array).is_empty() and int(rubies.count) == 9, "a locked gem is not set in a socket")
	check(GemPicker.rows(Game.profile.inv).is_empty() and not GemPicker.put(helm, "ruby_0"), "the gem picker does not offer it")
	ItemData.set_locked(rubies, false)
	var total := Game.gem_total("ruby_0")
	var at: int = Game.profile.inv.find(rubies)
	# (The first socketing's achievement may hand a gem back: the socket is what counts.)
	check(total == 9 and Game.socket_gem(helm, at) and (helm.gems as Array) == ["ruby_0"], "unlocked, it sockets (have %d)" % total)


func _set_craft() -> void:
	Game.profile.inv.clear()
	var cls := String(Game.class_id())
	var slot := "weapon"
	var need := SetGearData.recipe(cls, slot)
	if need.is_empty() or String(need.divine_slot) == "":
		check(false, "the warrior's set weapon needs a divine piece")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var divine := DivineGearData.item(StringName(cls), String(need.divine_slot), rng)
	divine["plus"] = SetGearData.DIVINE_PLUS
	Game.profile.inv.append(divine)
	if Game.set_divine_choices(slot).is_empty():
		print("the divine piece does not fit the set recipe here: the set-craft check is skipped")
		return
	ItemData.set_locked(divine, true)
	check(Game.set_divine_choices(slot).is_empty(), "a locked divine piece is never offered to set crafting")
	check(Game.set_piece_problem(slot) != "", "and the set piece cannot be made from it")
	ItemData.set_locked(divine, false)
	check(not Game.set_divine_choices(slot).is_empty(), "unlocked, it is offered again")


func _storage() -> void:
	Game.profile.inv.clear()
	SharedStorage.items().clear()
	var piece := _gear(2, "storage")
	ItemData.set_locked(piece, true)
	Game.profile.inv.append(piece)
	check(Game.deposit_item(0) and ItemData.is_locked(SharedStorage.items()[0]), "a locked piece is deposited with its lock")
	check(Game.withdraw_item(0) and ItemData.is_locked(Game.profile.inv[0]), "and withdrawn with it")
	# A locked stack joining an unlocked pile in the storage locks the pile.
	SharedStorage.put(ItemData.jewel("purple", 4))
	var mine := ItemData.jewel("purple", 2)
	ItemData.set_locked(mine, true)
	Game.profile.inv.append(mine)
	check(Game.deposit_item(Game.profile.inv.size() - 1), "the locked stack deposits")
	var pile: Dictionary = SharedStorage.items().filter(func(e): return String(e.get("id", "")) == "purple")[0]
	check(int(pile.count) == 6 and ItemData.is_locked(pile), "into the pile, which is now locked")
	var dep := Game.deposit_many([0])
	check(int(dep.moved) == 1 and ItemData.is_locked(SharedStorage.items().back()), "ฝากทั้งหมด keeps the lock")
	var all := Game.withdraw_all()
	check(int(all.moved) == 2 and Game.profile.inv.all(func(e): return ItemData.is_locked(e)), "เบิกทั้งหมด keeps both locks")
	# Locking a storage entry from the storage screen saves the storage file.
	Game.deposit_item(0)
	var stored: Dictionary = SharedStorage.items()[0]
	Game.toggle_item_lock(stored)
	SharedStorage.read_file()
	check(not ItemData.is_locked(SharedStorage.items()[0]), "ปลดล็อก in the storage is written to its file")


func _save_and_cloud() -> void:
	Game.profile.inv.clear()
	SharedStorage.items().clear()
	var piece := _gear(3, "save", "boots")
	ItemData.set_locked(piece, true)
	var stack := ItemData.jewel("lk_leaf", 3) if ItemData.JEWELS.has("lk_leaf") else ItemData.jewel("chaos", 3)
	ItemData.set_locked(stack, true)
	Game.profile.inv.append_array([piece, stack])
	var stored := _gear(1, "save-store")
	ItemData.set_locked(stored, true)
	SharedStorage.put(stored)
	SharedStorage.store()
	check(Game.save(), "saved with locked items")
	SharedStorage.read_file()
	check(Game.load_game(1), "loaded")
	var uid := String(piece.uid)
	var back: Array = Game.profile.inv.filter(func(e): return String(e.get("uid", "")) == uid)
	check(back.size() == 1 and ItemData.is_locked(back[0]), "a locked piece survives save / load")
	check(Game.profile.inv.any(func(e): return String(e.get("id", "")) == String(stack.id) and ItemData.is_locked(e)), "a locked stack too")
	check(ItemData.is_locked(SharedStorage.items()[0]), "and a locked storage piece")
	var text := Game.cloud_bundle_json()
	check(text.contains("\"lock\":true") or text.contains("\"lock\": true"), "the cloud bundle carries the lock")
	_server_accepts(text, "the accounts server accepts locked items")
	var bad: Dictionary = JSON.parse_string(text)
	for s in bad.slots:
		var inv: Array = bad.slots[s].get("inv", [])
		if not inv.is_empty():
			inv[0]["lock"] = "yes"
	_server_accepts(JSON.stringify(bad), "a lock that is not true is refused", false)


func _server_accepts(text: String, label: String, want := true) -> void:
	var dir := OS.get_environment("XDG_DATA_HOME")
	var path := (dir if dir != "" else OS.get_user_data_dir()).path_join("item_lock_bundle.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var script := ProjectSettings.globalize_path("res://tests/integration/save_survival_server.mjs")
	var output: Array = []
	var code := OS.execute("node", [script, path], output, true)
	DirAccess.remove_absolute(path)
	if code == -1 or (output.size() > 0 and String(output[0]).contains("command not found")):
		print("node not found: the server check is skipped")
		return
	check((code == 0) == want, "%s: %s" % [label, output[0] if output.size() > 0 else ""])


func _ui() -> void:
	Game.profile.inv.clear()
	var locked := _gear(1, "ui-locked")
	ItemData.set_locked(locked, true)
	Game.profile.inv.append_array([locked, _gear(1, "ui-free")])
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await _frames(3)
	var badges := menu.find_child("BagScroll", true, false).find_children("LockBadge", "", true, false)
	check(badges.size() == 1, "one padlock on the bag tiles (%d)" % badges.size())
	menu._selected_index = 0
	menu._rebuild()
	await _frames(2)
	var toggle := menu.find_child("LockToggle", true, false) as Button
	check(toggle != null and toggle.text == "ปลดล็อก", "the detail panel offers ปลดล็อก")
	var sell := menu.find_child("GearSell", true, false) as Button
	check(sell != null and sell.disabled, "and its sell button is off")
	var stall := menu.find_child("StallItem", true, false) as Button
	check(stall == null or stall.disabled, "and so is ตั้งขายบนแผง")
	check(menu.find_child("LockNote", true, false) != null, "with the lock note")
	toggle.pressed.emit()
	await _frames(2)
	check(not ItemData.is_locked(locked), "ปลดล็อก unlocks it")
	toggle = menu.find_child("LockToggle", true, false) as Button
	check(toggle != null and toggle.text == "ล็อก", "and the button reads ล็อก again")
	toggle.pressed.emit()
	await _frames(2)
	check(ItemData.is_locked(locked), "ล็อก locks it")
	# The multi-select dims it and a tap refuses it.
	menu._set_multi_sell(true)
	await _frames(2)
	(menu.find_child("MultiPick2", true, false) as Button).pressed.emit()
	await _frames(1)
	check(not menu._multi_pick.has(0) and menu._multi_pick.has(1), "เลือกทั้งหมด picks the unlocked piece only")
	menu.close_menu()
	menu.queue_free()
	# The merchant's sell row reads ล็อกอยู่.
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_shop()
	await _frames(3)
	var off := 0
	for b in shop.find_children("Sell", "Button", true, false):
		if (b as Button).disabled and (b as Button).text == "ล็อกอยู่":
			off += 1
	check(off == 1, "the merchant's sell list shows the locked piece as ล็อกอยู่ (%d)" % off)
	shop.close_shop()
	shop.queue_free()
	# The storage rows carry the lock toggle.
	var store := StorageScreen.new()
	add_child(store)
	store.open_storage()
	await _frames(3)
	var rows: int = Game.profile.inv.size() + Game.storage().size()
	var locked_rows: int = (Game.profile.inv + Game.storage()).filter(func(e): return ItemData.is_locked(e)).size()
	var toggles := store.find_children("LockToggle", "Button", true, false)
	check(toggles.size() == rows, "each storage-screen row has ล็อก / ปลดล็อก (%d of %d)" % [toggles.size(), rows])
	var pads := store.find_children("LockBadge", "", true, false).size()
	check(locked_rows >= 1 and pads == locked_rows, "and each locked one a padlock (%d of %d)" % [pads, locked_rows])
	store.close_storage()
	store.queue_free()
	await _frames(1)
