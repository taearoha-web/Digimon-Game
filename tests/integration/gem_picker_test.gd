extends Node
## The forge's ใส่อัญมณี picker (GemPicker) and the bag's gem order: gems grouped by type
## (ItemData.GEM_ORDER) then size small to large, in the picker rows and the bag grid; a
## tile tap sockets that very gem and takes one off its stack; "ใส่ให้เต็ม" and
## "ใส่ดีที่สุดอัตโนมัติ" fill only the free sockets (the class's main gem, largest
## first) and never touch a gem already in; a socket tap takes its gem back out.
##   godot --headless --path . res://tests/integration/gem_picker_test.tscn

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _count(gem_id: String) -> int:
	return Game.gem_total(gem_id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "อัญมณีQA", FaceKit.default_look())
	Game.profile.level = 90
	Game.profile.bag_slots = Game.MAX_BAG
	Game.profile.inv.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var sword := ItemData.generate(88, &"warrior", rng, 4, "weapon")
	sword["sockets"] = 3
	sword["gems"] = ["emerald_1"]
	Game.profile.inv.append(sword)
	# A jumbled bag: gems in any order with gear between them.
	for g in [["tourmaline", 1, 5], ["amethyst", 0, 1], ["topaz", 0, 2], ["ruby", 2, 32], ["ruby", 1, 21],
			["sapphire", 1, 10], ["ruby", 4, 1], ["onyx", 3, 2]]:
		Game.add_item(ItemData.gem(g[0], g[1], g[2]))
		if g[0] == "topaz":
			Game.profile.inv.append(ItemData.generate(40, &"warrior", rng, 2, "armor"))
			Game.add_item(ItemData.jewel("purple", 4))
	Game.add_item(ItemData.potion("hp_s", 20))

	# --- Order: rows by type in GEM_ORDER, sizes small to large ---
	var rows := GemPicker.rows(Game.profile.inv)
	var types: Array = rows.map(func(r): return r.type)
	check(types == ["ruby", "sapphire", "amethyst", "topaz", "onyx", "tourmaline"], "rows by type in GEM_ORDER, only types the bag holds (%s)" % [types])
	var ruby: Dictionary = rows[0]
	check(ruby.sizes.size() == ItemData.GEM_SIZES.size() and int(ruby.total) == 54, "a row has every size and the type's total")
	var ok_sizes := true
	for k in ruby.sizes.size():
		ok_sizes = ok_sizes and int(ruby.sizes[k].size) == k
	check(ok_sizes, "sizes run small to large")
	check(int(ruby.sizes[0].count) == 0 and int(ruby.sizes[2].count) == 32 and int(ruby.sizes[4].count) == 1, "counts per size (empty sizes stay at 0)")
	check(ItemData.gem_sort_key("ruby_4") < ItemData.gem_sort_key("sapphire_0") and ItemData.gem_sort_key("sapphire_0") < ItemData.gem_sort_key("sapphire_1"), "sort key: type first, then size")
	# The bag grid: gear keeps its place, gems sit together by type then size.
	var order := GameMenu.bag_order(Game.profile.inv)
	check(order.size() == Game.profile.inv.size(), "the grid shows every bag entry once")
	var seen := {}
	for i in order:
		seen[i] = true
	check(seen.size() == order.size(), "no bag index twice")
	# Groups: potions, gems, jewels, costumes, gear (pickup order inside gear).
	var kinds: Array = []
	for i in order:
		var kind := String(Game.profile.inv[i].get("kind", ""))
		if kinds.is_empty() or kinds[kinds.size() - 1] != kind:
			kinds.append(kind)
	check(kinds == ["potion", "gem", "jewel", "equip"], "the grid groups potions, gems, jewels, then gear (%s)" % [kinds])
	var gear_at: Array = []
	for i in order:
		if Game.profile.inv[i].get("kind", "") == "equip":
			gear_at.append(i)
	check(gear_at.size() == 2 and int(gear_at[0]) == 0 and int(gear_at[1]) > 0, "gear keeps its pickup order")
	var gem_ids: Array[String] = []
	var gem_run := []
	for pos in order.size():
		var it: Dictionary = Game.profile.inv[order[pos]]
		if it.get("kind", "") == "gem":
			gem_ids.append(String(it.id))
			gem_run.append(pos)
	var sorted_ids := gem_ids.duplicate()
	sorted_ids.sort_custom(func(a, b): return ItemData.gem_sort_key(a) < ItemData.gem_sort_key(b))
	check(gem_ids == sorted_ids and gem_ids[0] == "ruby_1" and gem_ids[gem_ids.size() - 1] == "tourmaline_1", "bag gems by type then size (%s)" % [gem_ids])
	check(int(gem_run[gem_run.size() - 1]) - int(gem_run[0]) == gem_run.size() - 1, "the gems sit together in the grid")

	# --- Plans ---
	check(GemPicker.free_sockets(sword) == 2, "two free sockets")
	check(GemPicker.main_type(Game.profile) == "ruby", "a warrior's main gem is the ruby")
	check(GemPicker.main_type({"class": "mage"}) == "sapphire", "a caster's main gem is the sapphire")
	var best := GemPicker.best_plan(sword, Game.profile.inv, Game.profile)
	check(Array(best) == ["ruby_4", "ruby_2"], "auto-best: the largest rubies first (%s)" % [best])
	var mage_best := GemPicker.best_plan(sword, Game.profile.inv, {"class": "mage"})
	check(Array(mage_best) == ["sapphire_1", "sapphire_1"], "auto-best for a caster: sapphires (%s)" % [mage_best])
	var fill := GemPicker.fill_plan(sword, Game.profile.inv, "onyx")
	check(Array(fill) == ["onyx_3", "onyx_3"], "fill a type: its largest, up to the free sockets")
	var short := GemPicker.fill_plan(sword, Game.profile.inv, "amethyst")
	check(Array(short) == ["amethyst_0"], "fill with too few gems: as many as there are")
	var lone := {"kind": "equip", "sockets": 3, "gems": []}
	var bag_two := [ItemData.gem("ruby", 4, 1), ItemData.gem("emerald", 3, 4)]
	check(Array(GemPicker.best_plan(lone, bag_two, Game.profile)) == ["ruby_4", "emerald_3", "emerald_3"], "out of main gems: the largest of the rest")
	check(GemPicker.best_plan({"kind": "equip", "sockets": 2, "gems": ["ruby_0", "ruby_0"]}, Game.profile.inv, Game.profile).is_empty(), "no free socket: nothing to plan")

	# --- The sheet from the forge's bag ---
	var menu := GameMenu.new()
	add_child(menu)
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	await _frames(3)
	menu._selected_index = 0
	menu._rebuild()
	await _frames(3)
	check(menu.find_child("GemSocketChips", true, false) != null, "the side column shows the piece's sockets")
	var open := menu.find_child("GemPickerOpen", true, false) as Button
	check(open != null and open.text.contains("2"), "ใส่อัญมณี names the free sockets")
	var old_list := false
	for b in menu.find_children("*", "Button", true, false):
		old_list = old_list or String((b as Button).text).begins_with("ใส่ ")
	check(not old_list, "no long list of ใส่ <gem> buttons any more")
	open.pressed.emit()
	await _frames(3)
	var picker := menu.find_child("GemPicker", true, false) as GemPicker
	check(picker != null, "the picker opens")
	var row_names: Array = []
	for r in picker.find_child("GemRows", true, false).find_children("GemRow_*", "", true, false):
		row_names.append(String(r.name).trim_prefix("GemRow_"))
	check(row_names == types, "the sheet's rows follow the order (%s)" % [row_names])
	var empty_tile := picker.find_child("GemTile_ruby_0", true, false) as Button
	check(empty_tile != null and empty_tile.disabled, "a size the bag lacks is shown dimmed and cannot be tapped")
	var before := _count("ruby_2")
	(picker.find_child("GemTile_ruby_2", true, false) as Button).pressed.emit()
	await _frames(2)
	check((sword.gems as Array) == ["emerald_1", "ruby_2"], "a tap sockets that gem into the next free socket (%s)" % [sword.gems])
	check(_count("ruby_2") == before - 1, "and takes one off its stack")
	check(menu.find_child("GemPicker", true, false) == picker, "the sheet stays open for the next gem")
	# The last ruby ตำนาน: its stack goes and its tile turns dim.
	(picker.find_child("GemTile_ruby_4", true, false) as Button).pressed.emit()
	await _frames(2)
	check(GemPicker.free_sockets(sword) == 0 and _count("ruby_4") == 0, "the last legendary ruby went in")
	var full := true
	for t in picker.find_children("GemTile_*", "Button", true, false):
		full = full and (t as Button).disabled
	check(full, "sockets full: no gem tile can be tapped")
	check((picker.find_child("GemAutoBest", true, false) as Button).disabled, "sockets full: no auto fill")
	# A socket tap takes its gem back out into the bag.
	(picker.find_child("GemSocket0", true, false) as Button).pressed.emit()
	await _frames(2)
	check((sword.gems as Array) == ["ruby_2", "ruby_4"] and _count("emerald_1") == 1, "a socket tap takes the gem out (into the bag)")
	# Auto-best through its confirm: only the free socket, the gems in it stay.
	(picker.find_child("GemAutoBest", true, false) as Button).pressed.emit()
	await _frames(2)
	var yes: Button = null
	for b in picker.find_children("*", "Button", true, false):
		if (b as Button).text == "ใส่เลย":
			yes = b
	check(yes != null, "auto-best asks first")
	if yes != null:
		yes.pressed.emit()
	await _frames(3)
	check((sword.gems as Array) == ["ruby_2", "ruby_4", "ruby_2"], "auto-best fills the free socket with the best ruby left, the others untouched (%s)" % [sword.gems])
	check(ItemData.resonates(sword), "three rubies: resonance")
	check(_count("ruby_2") == 30, "each gem put in left the bag")
	# Fill a type: take two out, then fill with onyx.
	Game.unsocket_gem(sword, 2)
	Game.unsocket_gem(sword, 1)
	picker.refresh()
	(picker.find_child("GemFill_onyx", true, false) as Button).pressed.emit()
	await _frames(2)
	check((sword.gems as Array) == ["ruby_2", "onyx_3", "onyx_3"] and _count("onyx_3") == 0, "ใส่ให้เต็ม fills the free sockets with that type only")
	# Closing: the menu keeps the piece selected though gems ahead of it moved.
	Game.profile.inv.erase(sword)
	Game.profile.inv.append(sword)
	picker.close_sheet()
	await _frames(3)
	check(menu._selected_index == Game.profile.inv.find(sword), "after the sheet the piece stays selected")
	check(menu.find_child("GemPicker", true, false) == null, "the sheet is gone")
	# A bag with no gems at all.
	Game.unsocket_gem(sword, 2)
	for i in range(Game.profile.inv.size() - 1, -1, -1):
		if Game.profile.inv[i].get("kind", "") == "gem":
			Game.profile.inv.remove_at(i)
	menu._selected_index = Game.profile.inv.find(sword)
	menu._rebuild()
	await _frames(2)
	(menu.find_child("GemPickerOpen", true, false) as Button).pressed.emit()
	await _frames(2)
	picker = menu.find_child("GemPicker", true, false) as GemPicker
	check(picker.find_child("GemNone", true, false) != null, "no gems: the sheet says so")
	menu.close_menu()
	await _frames(2)
	check(menu.find_child("GemPicker", true, false) == null, "closing the menu closes the sheet")
	# A piece without sockets shows neither the chips nor the button.
	var plain := ItemData.generate(20, &"warrior", rng, 0, "boots")
	plain["sockets"] = 0
	Game.profile.inv.append(plain)
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	await _frames(2)
	menu._selected_index = Game.profile.inv.find(plain)
	menu._rebuild()
	await _frames(2)
	check(menu.find_child("GemPickerOpen", true, false) == null and menu.find_child("GemSocketChips", true, false) == null, "no sockets: no gem section")
	menu.close_menu()
	print("GEM PICKER: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
