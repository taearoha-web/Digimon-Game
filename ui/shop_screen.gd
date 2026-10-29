class_name ShopScreen
extends CanvasLayer
## The merchant: potions and gear to buy, anything in the bag to sell. The same screen
## opens a world player's stall (open_stall): its finds (StallStock) on the buy side at
## the stall's prices, the bag on the sell side at what the stall pays.

signal closed()

## Bottle counts the − and + buttons step through for potions and scrolls.
const QTY_STEPS := [1, 5, 10, 20, 50, 99]

var is_open := false
## Chosen count per stackable item id; kept between visits.
var _qty := {}
var _root: Control
var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _gold: Label
var _title: Label
var _buy_title: Label
var _sell_title: Label
## The world player whose stall is open (WorldPlayers index), -1 for the merchant.
var stall := -1


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	frame.add_child(panel)
	var column := UIUtil.vbox(10)
	panel.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	_title = UIUtil.label("ร้านค้า", &"HeaderLabel")
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_gold = UIUtil.label("", &"SubHeaderLabel")
	_gold.add_theme_color_override("font_color", UIPalette.GOLD)
	head.add_child(_gold)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_shop)
	head.add_child(close)
	var row := UIUtil.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	_buy_box = _make_list(row, "ซื้อ")
	_sell_box = _make_list(row, "ขาย (กระเป๋าของคุณ)")
	_buy_title = _buy_box.get_parent().get_parent().get_child(0) as Label
	_sell_title = _sell_box.get_parent().get_parent().get_child(0) as Label
	Game.inventory_changed.connect(_queue_rebuild)
	Game.gold_changed.connect(func(_g): _queue_rebuild())


func _make_list(row: Control, title: String) -> VBoxContainer:
	var col := UIUtil.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UIUtil.label(title, &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := UIUtil.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


func open_shop() -> void:
	stall = -1
	_title.text = "ร้านค้า"
	_buy_title.text = "ซื้อ"
	_sell_title.text = "ขาย (กระเป๋าของคุณ)"
	_open()


## World player `world_index`'s stall: the good things it found to buy, the bag to sell
## at the stall's better price.
func open_stall(world_index: int) -> void:
	if world_index < 0 or world_index >= WorldPlayers.size():
		return
	stall = world_index
	StallStock.open(world_index)
	_title.text = "ร้านของ %s" % WorldPlayers.entry(world_index).name
	_buy_title.text = "ของดีที่เก็บมาขาย (%s)" % StallStock.KIND_NAMES[StallStock.specialty(world_index)]
	_sell_title.text = "ขายให้ร้านนี้ (ให้ราคาดีกว่าพ่อค้า)"
	_open()


func _open() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_shop() -> void:
	is_open = false
	stall = -1
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_buy_box)
	UIUtil.clear(_sell_box)
	get_tree().paused = false
	closed.emit()


## Stock for the player's level: the same every visit until the next tier.
func _stock() -> Array[Dictionary]:
	var level: int = Game.profile.level
	var stock: Array[Dictionary] = [ItemData.potion("hp_s"), ItemData.potion("mp_s")]
	if level >= 7:
		stock.append(ItemData.potion("hp_m"))
		stock.append(ItemData.potion("mp_m"))
	if level >= 16:
		stock.append(ItemData.potion("hp_l"))
		stock.append(ItemData.potion("mp_l"))
	if level >= 40:
		stock.append(ItemData.potion("hp_xl"))
		stock.append(ItemData.potion("mp_xl"))
	if level >= 70:
		stock.append(ItemData.potion("hp_war"))
		stock.append(ItemData.potion("hp_xxl"))
		stock.append(ItemData.potion("mp_xxl"))
	if level >= 100:
		stock.append(ItemData.potion("hp_god"))
	stock.append(ItemData.potion("town_scroll"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [ItemData.tier_for(level), Game.profile.class])
	for slot in ItemData.SLOTS:
		stock.append(ItemData.generate(maxi(1, level), Game.class_id(), rng, 0 if rng.randf() < 0.65 else 1, slot))
	return stock



## Several signals usually fire for one action (an upgrade changes the skill points and
## the gold, a sale the bag and the gold); rebuild once, at the end of the frame.
var _rebuild_queued := false


func _queue_rebuild() -> void:
	if not is_open or _rebuild_queued:
		return
	_rebuild_queued = true
	(func():
		_rebuild_queued = false
		if is_open:
			_rebuild()).call_deferred()

func _rebuild() -> void:
	var buy_scroll := _buy_box.get_parent() as TouchScroll
	var sell_scroll := _sell_box.get_parent() as TouchScroll
	var buy_y := buy_scroll.retained_vertical_position()
	var sell_y := sell_scroll.retained_vertical_position()
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	UIUtil.clear(_buy_box)
	UIUtil.clear(_sell_box)
	if stall >= 0:
		_stall_rows()
	else:
		for item in _stock():
			if ItemData.is_stackable(item):
				_buy_box.add_child(_bulk_row(item))
			else:
				_buy_box.add_child(_row(item, ItemData.buy_price(item), "ซื้อ", func(): Game.buy_item(item.duplicate(true))))
	var empty := true
	for i in Game.profile.inv.size():
		var item: Dictionary = Game.profile.inv[i]
		empty = false
		if stall >= 0:
			_sell_box.add_child(_row(item, StallStock.sell_price(item), "ขาย", func(): StallStock.sell(i)))
			continue
		var price := ItemData.unit_sell_price(item)
		_sell_box.add_child(_row(item, price, "ขาย", func(): Game.sell_item(i)))
	if empty:
		_sell_box.add_child(UIUtil.label("กระเป๋าว่างเปล่า", &"DimLabel"))
	buy_scroll.restore_vertical_position(buy_y)
	sell_scroll.restore_vertical_position(sell_y)


## The open stall's lots: each bought whole, gone from the stall until it restocks.
func _stall_rows() -> void:
	var who := stall
	var lots := StallStock.stock(who)
	for e in lots:
		var k := int(e.k)
		var row := _row(e.item, int(e.price), "ซื้อ", func(): StallStock.buy(who, k))
		row.name = "Lot_%d" % k
		_buy_box.add_child(row)
	var minutes := maxi(1, int((StallStock.restock_at(who, WorldPresence.clock()) - WorldPresence.clock()) / 60.0))
	var note := "ของชุดใหม่มาในอีก %d ชม. %d นาที" % [minutes / 60, minutes % 60] if minutes >= 60 else "ของชุดใหม่มาในอีก %d นาที" % minutes
	if lots.is_empty():
		note = "ของหมดแล้ว " + note
	_buy_box.add_child(UIUtil.label(note, &"DimLabel"))


## A potion or scroll: − and + pick how many bottles, the button buys them all at once.
func _bulk_row(item: Dictionary) -> Control:
	var id := String(item.id)
	var panel := _row(item, ItemData.buy_price(item), "ซื้อ", func():
		var lot := item.duplicate(true)
		lot["count"] = int(_qty.get(id, 1))
		Game.buy_item(lot))
	var buy := panel.find_child("Buy", true, false) as Button
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var stepper := UIUtil.hbox(6)
	stepper.name = "Qty"
	(panel.find_child("Info", true, false) as Control).add_child(stepper)
	var minus := UIUtil.button("−", &"", Vector2(64, 52))
	minus.name = "QtyMinus"
	var count := UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	count.name = "QtyCount"
	count.custom_minimum_size = Vector2(72, 0)
	var plus := UIUtil.button("+", &"", Vector2(64, 52))
	plus.name = "QtyPlus"
	stepper.add_child(minus)
	stepper.add_child(count)
	stepper.add_child(plus)
	var refresh := func():
		var n := int(_qty.get(id, 1))
		var total := ItemData.buy_price(item) * n
		count.text = "×%d" % n
		buy.text = "ซื้อ %d" % total
		buy.disabled = int(Game.profile.gold) < total
		minus.disabled = n <= QTY_STEPS[0]
		plus.disabled = n >= QTY_STEPS[-1]
	var step := func(dir: int):
		var at := QTY_STEPS.find(int(_qty.get(id, 1)))
		_qty[id] = QTY_STEPS[clampi((at if at >= 0 else 0) + dir, 0, QTY_STEPS.size() - 1)]
		refresh.call()
	minus.pressed.connect(step.bind(-1))
	plus.pressed.connect(step.bind(1))
	refresh.call()
	return panel


func _row(item: Dictionary, price: int, action_label: String, action: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ItemLook.icon(item)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.add_child(icon)
	var info := UIUtil.vbox(1)
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var qty := " ×%d" % int(item.count) if ItemData.is_stackable(item) and int(item.get("count", 1)) > 1 else ""
	var name_label := UIUtil.label(ItemData.name_of(item) + qty, &"BoldLabel")
	name_label.add_theme_color_override("font_color", ItemData.color_of(item))
	info.add_child(name_label)
	var summary := ", ".join(ItemData.stat_lines(item))
	if item.get("kind", "") == "equip":
		summary = "%s  %s" % [ItemData.level_text(int(item.level)), summary]
		if item.get("class", "") != "" and item["class"] != Game.profile["class"]:
			summary += "  (อาชีพอื่น)"
	var detail := UIUtil.label(summary, &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var button := UIUtil.button("%s %d" % [action_label, price], &"PrimaryButton" if action_label == "ซื้อ" else &"", Vector2(150, 56))
	button.name = "Buy" if action_label == "ซื้อ" else "Sell"
	if action_label == "ซื้อ" and int(Game.profile.gold) < price:
		button.disabled = true
	button.pressed.connect(func():
		AudioManager.play_sfx(&"coin")
		action.call())
	line.add_child(button)
	return panel
