class_name StorageScreen
extends CanvasLayer
## The warehouse keeper: park bag items in the storage every hero shares
## (SharedStorage), take them back out, and buy more bag slots. Gear of another class
## is listed greyed out with "อาชีพอื่น ใช้ไม่ได้" and cannot be taken out.

signal closed()

var is_open := false
## The card of a storage row the hero cannot take out (gear of another class).
const LOCKED_TINT := Color(0.55, 0.55, 0.6, 0.85)
var _root: Control
var _bag_box: VBoxContainer
var _store_box: VBoxContainer
var _bag_title: Label
var _store_title: Label
var _gold: Label
var _expand: Button
var _deposit_mats: Button
var _deposit_all: Button
var _withdraw_all: Button


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
	# Bulk moves, one write each (Game.deposit_many / withdraw_all).
	var bag_bar := _bar(left[1])
	_deposit_mats = UIUtil.button("ฝากวัตถุดิบทั้งหมด", &"AccentButton", Vector2(0, 52))
	_deposit_mats.name = "DepositMaterials"
	_deposit_mats.pressed.connect(func(): _deposit(Game.material_indices(), "วัตถุดิบ"))
	bag_bar.add_child(_deposit_mats)
	_deposit_all = UIUtil.button("ฝากทั้งหมด", &"", Vector2(0, 52))
	_deposit_all.name = "DepositAll"
	_deposit_all.pressed.connect(func(): _deposit(range(Game.profile.inv.size()), "ทั้งหมด"))
	bag_bar.add_child(_deposit_all)
	var store_bar := _bar(right[1])
	_withdraw_all = UIUtil.button("เบิกทั้งหมด", &"AccentButton", Vector2(0, 52))
	_withdraw_all.name = "WithdrawAll"
	_withdraw_all.pressed.connect(func():
		var ok: bool = await ModalDialog.confirm(_root, "เบิกทั้งหมด?", "ย้ายของในคลังรวมเข้ากระเป๋าจนกระเป๋าเต็ม (ของอาชีพอื่นยังอยู่ในคลัง) · คลังนี้ใช้ร่วมกับทุกตัวละคร", "เบิกเลย", "ยกเลิก")
		if not ok or not is_open:
			return
		var result := Game.withdraw_all()
		if int(result.moved) > 0:
			AudioManager.play_sfx(&"pickup")
			Game.say("เบิก %d รายการ%s" % [int(result.moved), (" · เหลือในคลัง %d (กระเป๋าเต็ม/ของอาชีพอื่น)" % int(result.left)) if int(result.left) > 0 else ""], &"success")
		else:
			Game.say("เบิกไม่ได้ กระเป๋าเต็มหรือเป็นของอาชีพอื่น", &"warning"))
	store_bar.add_child(_withdraw_all)
	Game.inventory_changed.connect(_queue_rebuild)
	Game.gold_changed.connect(func(_g): _queue_rebuild())


## A row of bulk buttons between a list's title and its scroll.
func _bar(box: Control) -> HBoxContainer:
	var bar := UIUtil.hbox(6)
	var col := box.get_parent().get_parent()
	col.add_child(bar)
	col.move_child(bar, 1)
	return bar


## "ฝากวัตถุดิบทั้งหมด" / "ฝากทั้งหมด": the bag entries at [param indices] into the storage,
## after a confirm.
func _deposit(indices: Array, what: String) -> void:
	if indices.is_empty():
		Game.say("ไม่มีของให้ฝาก", &"warning")
		return
	var ok: bool = await ModalDialog.confirm(_root, "ฝาก%s?" % what, "ย้าย %d รายการจากกระเป๋าเข้าคลังรวม (ฝากได้จนคลังเต็ม เบิกคืนได้ทุกเมื่อ)" % indices.size(), "ฝากเลย", "ยกเลิก")
	if not ok or not is_open:
		return
	var result := Game.deposit_many(indices)
	if int(result.moved) > 0:
		AudioManager.play_sfx(&"pickup")
		Game.say("ฝาก %d รายการ%s" % [int(result.moved), (" · เหลือ %d (คลังเต็ม)" % int(result.left)) if int(result.left) > 0 else ""], &"success")
	else:
		Game.say("คลังรวมเต็ม (%d/%d) — เบิกของออกก่อน" % [SharedStorage.size(), Game.STORAGE_SIZE], &"warning")


func _make_list(row: Control) -> Array:
	var col := UIUtil.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := UIUtil.label("", &"SubHeaderLabel")
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	# The game keeps running under it (auto-hunt goes on; Main._screen_open holds back world taps).
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_storage() -> void:
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_bag_box)
	UIUtil.clear(_store_box)
	closed.emit()



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
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	var cost := Game.bag_expand_cost()
	_expand.text = "ขยายกระเป๋า +%d (%d)" % [Game.BAG_STEP, cost] if cost > 0 else "กระเป๋าเต็มขนาด"
	_expand.disabled = cost <= 0 or int(Game.profile.gold) < cost
	_bag_title.text = "กระเป๋า (%d/%d) — แตะเพื่อฝาก" % [Game.profile.inv.size(), Game.bag_size()]
	var stored := Game.storage()
	_store_title.text = "คลังรวมทุกตัวละคร (%d/%d) — แตะเพื่อเบิก" % [stored.size(), Game.STORAGE_SIZE]
	# Old storages moved in may hold more than the room: no deposit until it is under.
	if stored.size() > Game.STORAGE_SIZE:
		_store_title.text = "คลังรวม (%d/%d) เกินความจุ — เบิกออกก่อนจึงฝากเพิ่มได้" % [stored.size(), Game.STORAGE_SIZE]
	_store_title.add_theme_color_override("font_color", UIPalette.WARNING if stored.size() >= Game.STORAGE_SIZE else UIPalette.TEXT)
	UIUtil.clear(_bag_box)
	UIUtil.clear(_store_box)
	_deposit_mats.disabled = Game.material_indices().is_empty()
	_deposit_all.disabled = Game.profile.inv.is_empty()
	_withdraw_all.disabled = stored.is_empty()
	for i in Game.profile.inv.size():
		var index: int = i
		_bag_box.add_child(_row(Game.profile.inv[i], "ฝาก", func(): Game.deposit_item(index)))
	if Game.profile.inv.is_empty():
		_bag_box.add_child(UIUtil.label("กระเป๋าว่างเปล่า", &"DimLabel"))
	for i in stored.size():
		var index: int = i
		_store_box.add_child(_row(stored[i], "เบิก", func(): Game.withdraw_item(index), Game.storage_lock(stored[i])))
	if stored.is_empty():
		_store_box.add_child(UIUtil.label("คลังว่างเปล่า — ฝากของที่ยังไม่ใช้ไว้ได้", &"DimLabel"))


## A row of the bag or the storage. [param lock] (Game.storage_lock) greys the row out
## and disables its button, with the reason and the class the gear is for.
func _row(item: Dictionary, action_label: String, action: Callable, lock := "") -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	if lock != "":
		# Greyed: the card, the icon and the name dim; the reason stays readable.
		panel.self_modulate = LOCKED_TINT
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ItemLook.icon(item)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if lock != "":
		icon.modulate = Color(0.55, 0.55, 0.6, 0.7)
	line.add_child(icon)
	# The player's lock (ItemData.is_locked) moves with the item: a padlock on the icon.
	if ItemData.is_locked(item):
		var padlock := ItemData.lock_badge(20.0)
		padlock.position = Vector2(36, 0)
		icon.add_child(padlock)
	var info := UIUtil.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var qty := " ×%d" % int(item.count) if ItemData.is_stackable(item) and int(item.get("count", 1)) > 1 else ""
	var name_label := UIUtil.label(ItemData.name_of(item) + qty, &"BoldLabel")
	name_label.add_theme_color_override("font_color", ItemData.color_of(item) if lock == "" else ItemData.color_of(item).lerp(UIPalette.TEXT_MUTED, 0.7))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var summary := ", ".join(ItemData.stat_lines(item))
	if item.get("kind", "") == "equip":
		summary = "%s  %s" % [ItemData.level_text(int(item.level)), summary]
	if lock != "":
		var cls := SharedStorage.class_name_of(SharedStorage.gear_class(item))
		summary = "%s%s · %s" % [lock, " (%s)" % cls if cls != "" else "", summary]
	elif ItemData.class_tag(item, String(Game.profile.get("class", ""))) != "":
		# Another class's piece in the bag: it may be stored (only that class takes it out).
		summary = "%s · %s" % [ItemData.class_tag(item, String(Game.profile.get("class", ""))), summary]
	var detail := UIUtil.label(summary, &"SmallLabel")
	if lock != "":
		detail.add_theme_color_override("font_color", UIPalette.WARNING)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(detail)
	var button := UIUtil.button(action_label, &"PrimaryButton", Vector2(110, 52))
	button.disabled = lock != ""
	button.pressed.connect(func():
		AudioManager.play_sfx(&"pickup")
		action.call())
	line.add_child(button)
	# ล็อก / ปลดล็อก (ItemData.set_locked), after the move button.
	if ItemData.can_lock(item):
		var lock_button := UIUtil.button("ปลดล็อก" if ItemData.is_locked(item) else "ล็อก", &"GhostButton", Vector2(96, 52))
		lock_button.name = "LockToggle"
		lock_button.add_theme_font_size_override("font_size", 17)
		lock_button.pressed.connect(func(): Game.toggle_item_lock(item))
		line.add_child(lock_button)
	return panel
