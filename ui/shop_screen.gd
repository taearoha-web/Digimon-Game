class_name ShopScreen
extends CanvasLayer
## The merchant: potions and gear to buy, anything in the bag to sell.

signal closed()

var is_open := false
var _root: Control
var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _gold: Label


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
	var title := UIUtil.label("ร้านค้า", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
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
	Game.inventory_changed.connect(func(): if is_open: _rebuild())
	Game.gold_changed.connect(func(_g): if is_open: _rebuild())


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
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_shop() -> void:
	is_open = false
	_root.visible = false
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
		stock.append(ItemData.potion("hp_xxl"))
		stock.append(ItemData.potion("mp_xxl"))
	stock.append(ItemData.potion("town_scroll"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [ItemData.tier_for(level), Game.profile.class])
	for slot in ItemData.SLOTS:
		stock.append(ItemData.generate(maxi(1, level), Game.class_id(), rng, 0 if rng.randf() < 0.65 else 1, slot))
	return stock


func _rebuild() -> void:
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	UIUtil.clear(_buy_box)
	UIUtil.clear(_sell_box)
	for item in _stock():
		_buy_box.add_child(_row(item, ItemData.buy_price(item), "ซื้อ", func(): Game.buy_item(item.duplicate(true))))
	var empty := true
	for i in Game.profile.inv.size():
		var item: Dictionary = Game.profile.inv[i]
		empty = false
		var price := ItemData.unit_sell_price(item)
		_sell_box.add_child(_row(item, price, "ขาย", func(): Game.sell_item(i)))
	if empty:
		_sell_box.add_child(UIUtil.label("กระเป๋าว่างเปล่า", &"DimLabel"))


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
	if action_label == "ซื้อ" and int(Game.profile.gold) < price:
		button.disabled = true
	button.pressed.connect(func():
		AudioManager.play_sfx(&"coin")
		action.call())
	line.add_child(button)
	return panel
