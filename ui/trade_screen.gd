class_name TradeScreen
extends CanvasLayer
## The trade window with a real player (OnlineTrade): the bag on the left (tap เสนอ; a
## stack picks its count with − and +, things that never trade are greyed), my offer in
## the middle (tap เอาออก) with the gold I add, their offer on the right, and at the
## bottom ล็อก / ยืนยัน / ยกเลิก. Any change unlocks both sides; ยืนยัน works once both
## are locked. Built like the shop and the storage (SafeAreaContainer, GlassPanel, cards,
## TouchScroll). The game keeps running behind it: the other player is live.

## Counts the − and + buttons step through for a stack.
const QTY_STEPS := [1, 5, 10, 20, 50, 99]
## Gold steps the step button cycles through.
const GOLD_STEPS := [100, 1000, 10000, 100000, 1000000]
const LOCKED_TINT := Color(0.55, 0.55, 0.6, 0.85)

var trade: OnlineTrade
var is_open := false
var _qty := {}
var _gold_step := 1
var _root: Control
var _title: Label
var _gold: Label
var _bag_box: VBoxContainer
var _mine_box: VBoxContainer
var _theirs_box: VBoxContainer
var _mine_title: Label
var _theirs_title: Label
var _status: Label
var _my_gold_label: Label
var _step_button: Button
var _lock: Button
var _confirm: Button
var _rebuild_queued := false


func _ready() -> void:
	layer = 61
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
	_title = UIUtil.label("แลกเปลี่ยน", &"HeaderLabel")
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_gold = UIUtil.label("", &"SubHeaderLabel")
	_gold.add_theme_color_override("font_color", UIPalette.GOLD)
	head.add_child(_gold)
	var close := UIUtil.button("ยกเลิก", &"DangerButton", Vector2(140, 60))
	close.name = "Cancel"
	close.pressed.connect(func():
		AudioManager.play_ui(&"ui_cancel")
		if trade != null:
			trade.cancel()
		close_screen())
	head.add_child(close)
	var row := UIUtil.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var bag := _make_list(row, "กระเป๋า — แตะเสนอ")
	_bag_box = bag[1]
	var mine := _make_list(row, "")
	_mine_title = mine[0]
	_mine_box = mine[1]
	var theirs := _make_list(row, "")
	_theirs_title = theirs[0]
	_theirs_box = theirs[1]
	# My gold under my offer: − amount + and the step size.
	var gold_row := UIUtil.hbox(8)
	gold_row.name = "GoldRow"
	(_mine_box.get_parent().get_parent() as Control).add_child(gold_row)
	var minus := UIUtil.button("−", &"", Vector2(60, 52))
	minus.name = "GoldMinus"
	minus.pressed.connect(func(): _step_gold(-1))
	gold_row.add_child(minus)
	_my_gold_label = UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_my_gold_label.name = "MyGold"
	_my_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_my_gold_label.add_theme_color_override("font_color", UIPalette.GOLD)
	gold_row.add_child(_my_gold_label)
	var plus := UIUtil.button("+", &"", Vector2(60, 52))
	plus.name = "GoldPlus"
	plus.pressed.connect(func(): _step_gold(1))
	gold_row.add_child(plus)
	_step_button = UIUtil.button("", &"GhostButton", Vector2(110, 52))
	_step_button.name = "GoldStep"
	_step_button.pressed.connect(func():
		_gold_step = (_gold_step + 1) % GOLD_STEPS.size()
		_refresh_gold())
	gold_row.add_child(_step_button)
	var foot := UIUtil.hbox(14)
	column.add_child(foot)
	_status = UIUtil.label("", &"SmallLabel")
	_status.name = "Status"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_status)
	_lock = UIUtil.button("ล็อก", &"", Vector2(170, 64))
	_lock.name = "Lock"
	_lock.pressed.connect(func():
		AudioManager.play_ui(&"ui_open")
		trade.lock())
	foot.add_child(_lock)
	_confirm = UIUtil.button("ยืนยัน", &"PrimaryButton", Vector2(190, 64))
	_confirm.name = "Confirm"
	_confirm.pressed.connect(func():
		AudioManager.play_sfx(&"coin")
		trade.confirm())
	foot.add_child(_confirm)
	Game.inventory_changed.connect(_queue_rebuild)
	Game.gold_changed.connect(func(_g): _queue_rebuild())


## Follows [param t]: opens with its trade, redraws on every change, closes with it.
func bind(t: OnlineTrade) -> void:
	trade = t
	trade.opened.connect(func(_id: String): open_screen())
	trade.changed.connect(_queue_rebuild)
	trade.closed.connect(func(_reason: String): close_screen())


func _make_list(row: Control, title: String) -> Array:
	var col := UIUtil.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	row.add_child(col)
	var label := UIUtil.label(title, &"SubHeaderLabel")
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(label)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var box := UIUtil.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return [label, box]


func open_screen() -> void:
	if trade == null or not trade.is_open():
		return
	is_open = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_screen() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_bag_box)
	UIUtil.clear(_mine_box)
	UIUtil.clear(_theirs_box)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if trade != null:
			trade.cancel()
		close_screen()


func _queue_rebuild() -> void:
	if not is_open or _rebuild_queued:
		return
	_rebuild_queued = true
	(func():
		_rebuild_queued = false
		if is_open:
			_rebuild()).call_deferred()


func _step_gold(dir: int) -> void:
	if trade == null:
		return
	trade.set_gold(trade.my_gold + dir * int(GOLD_STEPS[_gold_step]))


func _refresh_gold() -> void:
	_my_gold_label.text = "เหรียญที่ให้: %d" % trade.my_gold
	_step_button.text = "ทีละ %s" % _short(int(GOLD_STEPS[_gold_step]))


static func _short(n: int) -> String:
	if n >= 1000000:
		return "%dM" % (n / 1000000)
	if n >= 1000:
		return "%dK" % (n / 1000)
	return str(n)


func _rebuild() -> void:
	if trade == null or not trade.is_open():
		close_screen()
		return
	var scrolls := [_bag_box.get_parent(), _mine_box.get_parent(), _theirs_box.get_parent()]
	var ys := scrolls.map(func(s): return (s as TouchScroll).retained_vertical_position())
	var who := OnlineTrade.player_name(trade.partner)
	_title.text = "แลกเปลี่ยนกับ %s" % who
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	_mine_title.text = "ของคุณ" + (" · ล็อกแล้ว" if trade.my_lock else "")
	_mine_title.add_theme_color_override("font_color", UIPalette.SUCCESS if trade.my_lock else UIPalette.TEXT)
	_theirs_title.text = "ของ %s" % who + (" · ล็อกแล้ว" if trade.their_lock else "")
	_theirs_title.add_theme_color_override("font_color", UIPalette.SUCCESS if trade.their_lock else UIPalette.TEXT)
	UIUtil.clear(_bag_box)
	UIUtil.clear(_mine_box)
	UIUtil.clear(_theirs_box)
	for i in Game.profile.inv.size():
		_bag_box.add_child(_bag_row(Game.profile.inv[i], i))
	if Game.profile.inv.is_empty():
		_bag_box.add_child(UIUtil.label("กระเป๋าว่างเปล่า", &"DimLabel"))
	for i in trade.mine.size():
		var index: int = i
		var row := _row(trade.mine[i], "เอาออก", func(): trade.take_back(index))
		row.name = "Mine_%d" % i
		_mine_box.add_child(row)
	if trade.mine.is_empty():
		_mine_box.add_child(UIUtil.label("ยังไม่ได้เสนออะไร", &"DimLabel"))
	for i in trade.theirs.size():
		var row := _row(trade.theirs[i], "", Callable())
		row.name = "Theirs_%d" % i
		_theirs_box.add_child(row)
	var gold_line := UIUtil.label("เหรียญที่ได้: %d" % trade.their_gold, &"BoldLabel")
	gold_line.name = "TheirGold"
	gold_line.add_theme_color_override("font_color", UIPalette.GOLD)
	_theirs_box.add_child(gold_line)
	if trade.theirs.is_empty() and trade.their_gold <= 0:
		_theirs_box.add_child(UIUtil.label("รออีกฝ่ายเสนอ…", &"DimLabel"))
	if trade.their_bad:
		var bad := UIUtil.label("ข้อเสนอของอีกฝ่ายมีของที่แลกไม่ได้", &"SmallLabel")
		bad.add_theme_color_override("font_color", UIPalette.WARNING)
		_theirs_box.add_child(bad)
	_refresh_gold()
	_lock.disabled = trade.my_lock
	_lock.text = "ล็อกแล้ว" if trade.my_lock else "ล็อก"
	_confirm.disabled = not trade.can_confirm()
	_confirm.text = "ยืนยันแล้ว" if trade.my_confirm else "ยืนยัน"
	_status.text = _status_text(who)
	for i in scrolls.size():
		(scrolls[i] as TouchScroll).restore_vertical_position(ys[i])


func _status_text(who: String) -> String:
	if trade.my_confirm and not trade.their_confirm:
		return "ยืนยันแล้ว — รอ %s ยืนยัน" % who
	if trade.their_confirm and not trade.my_confirm:
		return "%s ยืนยันแล้ว — กดยืนยันเพื่อแลก" % who
	if trade.my_lock and trade.their_lock:
		return "ล็อกทั้งสองฝ่ายแล้ว — กดยืนยันเพื่อแลก"
	if trade.my_lock:
		return "ล็อกแล้ว — รอ %s ล็อก" % who
	if trade.their_lock:
		return "%s ล็อกแล้ว — ตรวจของแล้วกดล็อก" % who
	return "เลือกของและเหรียญ แล้วกดล็อก (เปลี่ยนข้อเสนอเมื่อไรจะปลดล็อกทั้งสองฝ่าย)"


## A bag slot: เสนอ (gear whole; a stack picks how many with − and +), greyed when it
## never trades or is all in the offer already.
func _bag_row(item: Dictionary, index: int) -> Control:
	var tradable := OnlineTrade.tradable(item)
	var free := trade.free_count(item) if tradable else 0
	var key := "%s|%s" % [String(item.get("kind", "")), String(item.get("id", item.get("uid", "")))]
	var panel := _row(item, "เสนอ", func(): trade.offer(index, clampi(int(_qty.get(key, 1)), 1, maxi(1, free))),
		"แลกไม่ได้" if not tradable else ("เสนอแล้ว" if free <= 0 else ""))
	panel.name = "Bag_%d" % index
	if tradable and free > 1 and ItemData.is_stackable(item):
		var steps := QTY_STEPS.filter(func(n): return int(n) < free)
		steps.append(free)
		if not steps.has(int(_qty.get(key, 1))):
			_qty[key] = 1
		_stepper(panel.find_child("Info", true, false) as Control, key, steps)
	return panel


func _stepper(info: Control, key: String, steps: Array) -> void:
	var stepper := UIUtil.hbox(6)
	stepper.name = "Qty"
	info.add_child(stepper)
	var minus := UIUtil.button("−", &"", Vector2(56, 48))
	minus.name = "QtyMinus"
	var count := UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	count.name = "QtyCount"
	count.custom_minimum_size = Vector2(64, 0)
	var plus := UIUtil.button("+", &"", Vector2(56, 48))
	plus.name = "QtyPlus"
	stepper.add_child(minus)
	stepper.add_child(count)
	stepper.add_child(plus)
	var show := func():
		var n := int(_qty.get(key, 1))
		count.text = "×%d" % n
		minus.disabled = n <= int(steps[0])
		plus.disabled = n >= int(steps[-1])
	var step := func(dir: int):
		var at := steps.find(int(_qty.get(key, 1)))
		_qty[key] = int(steps[clampi((at if at >= 0 else 0) + dir, 0, steps.size() - 1)])
		show.call()
	minus.pressed.connect(step.bind(-1))
	plus.pressed.connect(step.bind(1))
	show.call()


## A card: icon, name (× count), level and stats, a button when [param action_label] is
## set; [param lock] greys the card with its reason and disables the button.
func _row(item: Dictionary, action_label: String, action: Callable, lock := "") -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	if lock != "":
		panel.self_modulate = LOCKED_TINT
	var line := UIUtil.hbox(8)
	panel.add_child(line)
	var icon := TextureRect.new()
	icon.texture = ItemLook.icon(item)
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if lock != "":
		icon.modulate = Color(0.55, 0.55, 0.6, 0.7)
	line.add_child(icon)
	var info := UIUtil.vbox(1)
	info.name = "Info"
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
		summary = "%s  %s" % [ItemData.level_text(int(item.get("level", 1))), summary]
		var cls := SharedStorage.gear_class(item)
		if cls != "" and cls != String(Game.profile.get("class", "")):
			summary += "  (%s)" % (SharedStorage.class_name_of(cls) if SharedStorage.class_name_of(cls) != "" else "อาชีพอื่น")
	if lock != "":
		summary = "%s · %s" % [lock, summary]
	var detail := UIUtil.label(summary, &"SmallLabel")
	if lock != "":
		detail.add_theme_color_override("font_color", UIPalette.WARNING)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(detail)
	if action_label != "":
		var button := UIUtil.button(action_label, &"PrimaryButton" if action_label == "เสนอ" else &"", Vector2(104, 52))
		button.name = "Act"
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.disabled = lock != ""
		button.pressed.connect(func():
			AudioManager.play_sfx(&"pickup")
			action.call())
		line.add_child(button)
	return panel
