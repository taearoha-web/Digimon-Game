extends Node
## Actual paused bag/shop controls, multiple sale signals and shrinking lists.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func settle() -> void:
	for i in 5:
		await get_tree().process_frame

func no_visible_jump(scroll: TouchScroll, expected: int) -> void:
	for frame in 3:
		await RenderingServer.frame_post_draw
		check(scroll.scroll_vertical == expected, "rendered frame retains sale position")

## The character page's own list, found in the tree (not through the menu's bookkeeping).
func character_scroll(menu: GameMenu) -> TouchScroll:
	for node in menu._content.find_children("*", "TouchScroll", true, false):
		if not node.is_queued_for_deletion():
			return node
	return null

func fill_bag() -> void:
	Game.profile.inv.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 750
	for i in Game.bag_size():
		Game.profile.inv.append(ItemData.generate(20 + i % 20, &"warrior", rng, 0, "weapon"))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	Game.new_profile(&"warrior", "Sale scroll QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.gold = 100000
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	fill_bag()
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"inventory")
	await settle()
	check(menu._page_scroll.get_v_scroll_bar().max_value > menu._page_scroll.size.y, "fixture bag scrolls")
	menu._page_scroll.scroll_vertical = 550
	var before := menu._page_scroll.scroll_vertical
	check(before > 100, "fixture starts below the first page")
	menu._selected_index = 28
	menu._refresh_detail()
	for i in 3:
		var count: int = Game.profile.inv.size()
		var gold: int = Game.profile.gold
		var price := ItemData.sell_price(Game.profile.inv[menu._selected_index])
		# Press the real pinned sell button, which emits multiple rebuild signals.
		var sell: Button
		for node in menu._actions.find_children("*", "Button", true, false):
			if node.text.begins_with("ขาย +"):
				sell = node
		check(sell != null, "bag sale action is available")
		if sell:
			sell.pressed.emit()
		await no_visible_jump(menu._page_scroll, before)
		await settle()
		check(menu._page_scroll.scroll_vertical == before, "repeated bag sale retains scroll")
		check(Game.profile.inv.size() == count - 1 and Game.profile.gold == gold + price, "exactly one correct sale per press")
		check(menu._selected_index == 28, "next item stays selected")
	# Several notifications before layout must not replace the saved offset with zero.
	Game.inventory_changed.emit()
	Game.profile_changed.emit()
	Game.quest_changed.emit()
	await settle()
	check(menu._page_scroll.scroll_vertical == before, "back-to-back rebuilds retain pending position")
	menu.show_tab(&"character")
	menu.show_tab(&"inventory")
	await settle()
	check(menu._page_scroll.scroll_vertical == 0, "new tab visit does not inherit a stale pending restore")
	# Star points: the character page keeps its place after each press, and a press can spend many points.
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 200, "spent": 0, "alloc": {}}
	menu.show_tab(&"character")
	await settle()
	var page := character_scroll(menu)
	check(page.get_v_scroll_bar().max_value > page.size.y, "character fixture scrolls")
	page.scroll_vertical = int(page.get_v_scroll_bar().max_value)
	var char_y := page.scroll_vertical
	check(char_y > 100, "character fixture starts below the first page")
	for name in ["Paragon_def_10", "Paragon_def_5", "Paragon_def_1"]:
		var points := int(Game.paragon().points)
		var press := menu.find_child(name, true, false) as Button
		check(press != null and not press.disabled, "%s is available" % name)
		if press:
			press.pressed.emit()
		await no_visible_jump(character_scroll(menu), char_y)
		await settle()
		check(character_scroll(menu).scroll_vertical == char_y, "%s keeps the character page in place" % name)
		check(points - int(Game.paragon().points) == int(name.get_slice("_", 2)), "%s spends that many points" % name)
	var top := menu.find_child("Paragon_hp_max", true, false) as Button
	if top:
		top.pressed.emit()
	await settle()
	check(int(Game.paragon().alloc.hp) == int(Game.PARAGON_STATS.hp[2]), "max fills the stat to its cap")
	check((menu.find_child("Paragon_hp_1", true, false) as Button).disabled, "a full stat disables its buttons")
	menu.close_menu()
	menu.queue_free()
	await settle()
	fill_bag()
	var shop := ShopScreen.new()
	add_child(shop)
	shop.open_shop()
	await settle()
	var selling := shop._sell_box.get_parent() as TouchScroll
	var buying := shop._buy_box.get_parent() as TouchScroll
	selling.scroll_vertical = 1400
	buying.scroll_vertical = 240
	var sell_y := selling.scroll_vertical
	var buy_y := buying.scroll_vertical
	check(sell_y > 100, "merchant fixture starts below first page")
	for i in 3:
		var row := shop._sell_box.get_child(20)
		var buttons := row.find_children("*", "Button", true, false)
		(buttons[0] as Button).pressed.emit()
		await no_visible_jump(selling, sell_y)
		await settle()
		check(selling.scroll_vertical == sell_y and buying.scroll_vertical == buy_y, "merchant keeps both independent scroll positions")
	# At the end of the list a removed row should clamp to the new last page.
	selling.scroll_vertical = int(selling.get_v_scroll_bar().max_value)
	var bottom := selling.scroll_vertical
	Game.sell_item(Game.profile.inv.size() - 1)
	await settle()
	var bar := selling.get_v_scroll_bar()
	check(selling.scroll_vertical > 0 and selling.scroll_vertical <= bottom and absf(selling.scroll_vertical - (bar.max_value - bar.page)) < 2, "last-row sale stays at the new bottom")
	# A stacked item remains in the same location after selling one unit.
	var potion := ItemData.potion("hp_s")
	potion.count = 3
	Game.profile.inv[20] = potion
	Game.inventory_changed.emit()
	await settle()
	selling.scroll_vertical = 1200
	before = selling.scroll_vertical
	Game.sell_item(20)
	await settle()
	check(Game.profile.inv[20].count == 2 and selling.scroll_vertical == before, "stacked sale retains count and scroll")
	Game.profile.inv = [ItemData.potion("hp_s")]
	Game.inventory_changed.emit()
	await settle()
	Game.sell_item(0)
	await settle()
	check(Game.profile.inv.is_empty() and selling.scroll_vertical == 0, "empty list safely clamps to zero")
	shop.close_shop()
	shop.queue_free()
	await settle()
	for player in AudioManager._ui_pool:
		player.stop()
		player.stream = null
	print("SALE SCROLL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
