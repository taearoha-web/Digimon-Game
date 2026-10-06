class_name StorageScreen
extends CanvasLayer
## The warehouse keeper: park bag items in the storage, take them back out, and
## buy more bag slots.

signal closed()

var is_open := false
var _root: Control
var _bag_box: VBoxContainer
var _store_box: VBoxContainer
var _bag_title: Label
var _store_title: Label
var _gold: Label
var _expand: Button


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
	var title := UIUtil.label("คลังเก็บของ", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold = UIUtil.label("", &"SubHeaderLabel")
	_gold.add_theme_color_override("font_color", UIPalette.GOLD)
	head.add_child(_gold)
	_expand = UIUtil.button("", &"", Vector2(250, 60))
	_expand.pressed.connect(func():
		if Game.expand_bag():
			AudioManager.play_sfx(&"coin"))
	head.add_child(_expand)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_storage)
	head.add_child(close)
	var row := UIUtil.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left := _make_list(row)
	_bag_title = left[0]
	_bag_box = left[1]
	var right := _make_list(row)
	_store_title = right[0]
	_store_box = right[1]
	Game.inventory_changed.connect(func(): if is_open: _rebuild())
	Game.gold_changed.connect(func(_g): if is_open: _rebuild())


func _make_list(row: Control) -> Array:
	var col := UIUtil.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := UIUtil.label("", &"SubHeaderLabel")
	col.add_child(title)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := UIUtil.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return [title, box]


func open_storage() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_storage() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func _rebuild() -> void:
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	var cost := Game.bag_expand_cost()
	_expand.text = "ขยายกระเป๋า +%d (%d)" % [Game.BAG_STEP, cost] if cost > 0 else "กระเป๋าเต็มขนาด"
	_expand.disabled = cost <= 0 or int(Game.profile.gold) < cost
	_bag_title.text = "กระเป๋า (%d/%d) — แตะเพื่อฝาก" % [Game.profile.inv.size(), Game.bag_size()]
	_store_title.text = "คลัง (%d/%d) — แตะเพื่อเบิก" % [Game.storage().size(), Game.STORAGE_SIZE]
	UIUtil.clear(_bag_box)
	UIUtil.clear(_store_box)
	for i in Game.profile.inv.size():
		var index: int = i
		_bag_box.add_child(_row(Game.profile.inv[i], "ฝาก", func(): Game.deposit_item(index)))
	if Game.profile.inv.is_empty():
		_bag_box.add_child(UIUtil.label("กระเป๋าว่างเปล่า", &"DimLabel"))
	var stored := Game.storage()
	for i in stored.size():
		var index: int = i
		_store_box.add_child(_row(stored[i], "เบิก", func(): Game.withdraw_item(index)))
	if stored.is_empty():
		_store_box.add_child(UIUtil.label("คลังว่างเปล่า — ฝากของที่ยังไม่ใช้ไว้ได้", &"DimLabel"))


func _row(item: Dictionary, action_label: String, action: Callable) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ItemLook.icon(item)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	line.add_child(icon)
	var info := UIUtil.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var qty := " ×%d" % int(item.count) if ItemData.is_stackable(item) and int(item.get("count", 1)) > 1 else ""
	var name_label := UIUtil.label(ItemData.name_of(item) + qty, &"BoldLabel")
	name_label.add_theme_color_override("font_color", ItemData.color_of(item))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var summary := ", ".join(ItemData.stat_lines(item))
	if item.get("kind", "") == "equip":
		summary = "Lv.%d  %s" % [int(item.level), summary]
	var detail := UIUtil.label(summary, &"SmallLabel")
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(detail)
	var button := UIUtil.button(action_label, &"PrimaryButton", Vector2(110, 52))
	button.pressed.connect(func():
		AudioManager.play_sfx(&"pickup")
		action.call())
	line.add_child(button)
	return panel
