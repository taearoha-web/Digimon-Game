class_name ShopPanel
extends VBoxContainer
## Buy / Sell screen for a [ShopData]. Rules live in [ShopService]; this is
## only presentation. Open it from anywhere with:
##   await ShopPanel.open_shop(get_tree(), shop)

signal transaction_done()

const LAYER := 30

var shop: ShopData
var _selling := false
var _selected: StringName = &""
var _quantity := 1
var _list: VBoxContainer
var _detail: VBoxContainer
var _coins: Label


## Shows the shop in its own canvas layer, pauses the world while open and
## returns once the player closes it.
static func open_shop(tree: SceneTree, shop_data: ShopData) -> void:
	if shop_data == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	var panel := ShopPanel.new()
	panel.shop = shop_data
	var was_paused := tree.paused
	tree.paused = true
	var sheet := OverlaySheet.open(layer, shop_data.display_name, panel, Vector2(1040, 580))
	await sheet.closed
	tree.paused = was_paused
	layer.queue_free()


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var top := UIUtil.hbox(12)
	add_child(top)
	var group := ButtonGroup.new()
	for mode in [["Buy", false], ["Sell", true]]:
		var selling: bool = mode[1]
		var tab := UIUtil.button(mode[0], &"TabButton", Vector2(120, 52))
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = selling == _selling
		tab.disabled = selling and not shop.buys_items
		tab.pressed.connect(func():
			_selling = selling
			_selected = &""
			refresh())
		top.add_child(tab)
	var greeting := UIUtil.label(shop.greeting, &"DimLabel")
	greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.clip_text = true
	greeting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(greeting)
	var money := UIUtil.panel(&"CardPanel")
	top.add_child(money)
	var money_row := UIUtil.hbox(8)
	money.add_child(money_row)
	money_row.add_child(UIUtil.texture_rect(load("res://assets/icons/ui/coin.svg"), Vector2(28, 28)))
	_coins = UIUtil.label("0", &"ValueLabel")
	money_row.add_child(_coins)

	var body := UIUtil.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(470, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = UIUtil.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail_panel := UIUtil.panel(&"GlassPanel")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_panel)
	_detail = UIUtil.vbox(12)
	detail_panel.add_child(_detail)
	refresh()


func refresh() -> void:
	_coins.text = "%d" % GameState.profile.currency
	UIUtil.clear(_list)
	var items := _sell_items() if _selling else _buy_items()
	if items.is_empty():
		_list.add_child(UIUtil.label("Nothing to sell." if _selling else "Sold out!", &"DimLabel"))
	if _selected != &"" and not items.any(func(it: ItemData): return it.id == _selected):
		_selected = &""
	for item: ItemData in items:
		if _selected == &"":
			_selected = item.id
		var price := item.sell_price if _selling else ShopService.get_buy_price(shop, item)
		var row := UIUtil.button("", &"ChoiceButton", Vector2(0, 64))
		row.toggle_mode = true
		row.button_pressed = item.id == _selected
		row.icon = item.get_icon()
		row.expand_icon = false
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_constant_override("icon_max_width", 44)
		row.text = L10n.t("%s   ·   %d coins   (own %d)") % [item.display_name, price, GameState.inventory.count(item.id)]
		row.pressed.connect(func():
			_selected = item.id
			_quantity = 1
			refresh())
		_list.add_child(row)
	_show_detail()


func _buy_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item_id in shop.stock:
		var item := GameData.get_item(item_id)
		if item and ShopService.get_buy_price(shop, item) > 0:
			out.append(item)
	return out


func _sell_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for entry in GameState.inventory.get_entries():
		var item: ItemData = entry.item
		if ShopService.can_sell(item):
			out.append(item)
	return out


func _max_quantity(item: ItemData) -> int:
	if _selling:
		return GameState.inventory.count(item.id)
	return ShopService.max_affordable(shop, item, GameState.profile, GameState.inventory)


func _show_detail() -> void:
	UIUtil.clear(_detail)
	var item := GameData.get_item(_selected)
	if item == null:
		_detail.add_child(UIUtil.label("Select an item.", &"DimLabel"))
		return
	var head := UIUtil.hbox(14)
	_detail.add_child(head)
	head.add_child(UIUtil.texture_rect(item.get_icon(), Vector2(80, 80)))
	var titles := UIUtil.vbox(4)
	head.add_child(titles)
	titles.add_child(UIUtil.label(item.display_name, &"HeaderLabel"))
	titles.add_child(UIUtil.label(L10n.t("%s · Owned %d") % [item.get_category_name(), GameState.inventory.count(item.id)], &"DimLabel"))
	var desc := UIUtil.label(item.description, &"")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	if item.is_equipment():
		_detail.add_child(UIUtil.label(L10n.t("Held bonus: %s") % item.describe_bonuses(), &"BoldLabel"))

	var max_qty := _max_quantity(item)
	_quantity = clampi(_quantity, 1, maxi(1, max_qty))
	var price := item.sell_price if _selling else ShopService.get_buy_price(shop, item)

	var qty_row := UIUtil.hbox(12)
	_detail.add_child(qty_row)
	qty_row.add_child(UIUtil.label("Quantity", &"SubHeaderLabel"))
	var minus := UIUtil.button("−", &"GhostButton", Vector2(64, 56))
	minus.disabled = _quantity <= 1
	minus.pressed.connect(func():
		_quantity -= 1
		AudioManager.play_ui(&"ui_select")
		_show_detail())
	qty_row.add_child(minus)
	var qty_label := UIUtil.label(str(_quantity), &"ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
	qty_label.custom_minimum_size = Vector2(48, 0)
	qty_row.add_child(qty_label)
	var plus := UIUtil.button("+", &"GhostButton", Vector2(64, 56))
	plus.disabled = _quantity >= max_qty
	plus.pressed.connect(func():
		_quantity += 1
		AudioManager.play_ui(&"ui_select")
		_show_detail())
	qty_row.add_child(plus)
	qty_row.add_child(UIUtil.label(L10n.t("Total %d coins") % (price * _quantity), &"BoldLabel"))

	var action := UIUtil.button(L10n.t("Sell ×%d" if _selling else "Buy ×%d") % _quantity, &"PrimaryButton", Vector2(240, 64))
	action.disabled = max_qty <= 0
	action.pressed.connect(_on_action.bind(item.id))
	_detail.add_child(action)
	if max_qty <= 0 and not _selling:
		var reason := L10n.t("Not enough Data Coins.") if GameState.inventory.count(item.id) < item.max_stack else L10n.t("Your bag can't hold more.")
		_detail.add_child(UIUtil.label(reason, &"SmallLabel"))


func _on_action(item_id: StringName) -> void:
	var result: Dictionary
	if _selling:
		result = ShopService.sell(item_id, _quantity, GameState.profile, GameState.inventory)
	else:
		result = ShopService.buy(shop, item_id, _quantity, GameState.profile, GameState.inventory)
	EventBus.toast(result.message, &"success" if result.ok else &"warning")
	if result.ok:
		AudioManager.play_sfx(&"coin")
		transaction_done.emit()
	else:
		AudioManager.play_ui(&"ui_error")
	_quantity = 1
	refresh()
