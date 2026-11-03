class_name PlayerStallView
extends VBoxContainer
## The "แผงของฉัน" page (PlayerStall), shown in the game menu's bag tab from any zone:
## the lots on the stall (with how fast each should sell and a button to take it back),
## the last sales, and on the right the bag to pick a thing from, its fair price and the
## asking price (typed, a slider from 50% to 300% of the fair price, quick steps), the
## count of a stack, and "ตั้งขาย". Built for phones: every control is a big touch target.
## [member pick] (the bag slot picked), price and count live in a Dictionary the menu
## keeps, so a rebuild (a sale, the bag changing) keeps them.

signal back_requested()

const ICON := 56
const PICK_SIZE := Vector2(76, 76)
const QUICK_STEPS := [50, 100, 150, 200, 300]

## {"pick": bag index or -1, "price": asking price, "count": stack count}
var view: Dictionary = {}

var _lots_box: VBoxContainer
var _log_box: VBoxContainer
var _count_label: Label
var _side: VBoxContainer
var _syncing := false


func _init(p_view: Dictionary = {}) -> void:
	view = p_view
	for key in ["pick", "price", "count"]:
		if not view.has(key):
			view[key] = -1 if key == "pick" else 0
	name = "PlayerStallView"
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var head := UIUtil.hbox(10)
	add_child(head)
	head.add_child(UIUtil.label("แผงของฉัน", &"HeaderLabel"))
	_count_label = UIUtil.label("", &"SubHeaderLabel")
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)
	var back := UIUtil.button("กลับกระเป๋า", &"", Vector2(170, 56))
	back.name = "Back"
	back.pressed.connect(func(): back_requested.emit())
	head.add_child(back)
	var hint := UIUtil.label("ตั้งขายได้ทุกที่ ผู้เล่น AI ที่สนใจจะมาซื้อเองแม้คุณออกล่าหรือปิดเกม (นับย้อนหลังสูงสุด 12 ชม.) เงินเข้าทันที", &"DimLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var body := UIUtil.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)
	var left := UIUtil.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.add_child(UIUtil.label("ของบนแผง", &"BoldLabel"))
	var lots_scroll := _scroll("LotsScroll", 3.0)
	left.add_child(lots_scroll)
	_lots_box = UIUtil.vbox(6)
	_lots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lots_scroll.add_child(_lots_box)
	left.add_child(UIUtil.label("ขายล่าสุด", &"BoldLabel"))
	var log_scroll := _scroll("LogScroll", 1.2)
	left.add_child(log_scroll)
	_log_box = UIUtil.vbox(4)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(_log_box)
	_side = UIUtil.vbox(6)
	_side.name = "AddPanel"
	_side.custom_minimum_size = Vector2(420, 0)
	body.add_child(_side)
	Game.stall_changed.connect(_refresh)
	_refresh()


func _scroll(scroll_name: String, ratio: float) -> TouchScroll:
	var scroll := TouchScroll.new()
	scroll.name = scroll_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = ratio
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll


func _refresh() -> void:
	if not Game.has_profile:
		return
	var lots := PlayerStall.lots()
	_count_label.text = "%d/%d ช่อง · เงิน %s" % [lots.size(), PlayerStall.MAX_LOTS, PlayerStall.thousands(int(Game.profile.gold))]
	UIUtil.clear(_lots_box)
	if lots.is_empty():
		var empty := UIUtil.label("แผงยังว่าง เลือกของจากกระเป๋าทางขวาแล้วกด \"ตั้งขาย\"", &"DimLabel")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lots_box.add_child(empty)
	var buyers := PlayerStall.pool(WorldPresence.clock())
	for lot in lots:
		_lots_box.add_child(_lot_row(lot, buyers))
	UIUtil.clear(_log_box)
	var sales := PlayerStall.sales()
	if sales.is_empty():
		_log_box.add_child(UIUtil.label("ยังไม่มีใครซื้อ", &"DimLabel"))
	for entry in sales:
		_log_box.add_child(_log_row(entry))
	_build_side()


func _icon(item: Dictionary) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ItemLook.icon(item)
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _lot_row(lot: Dictionary, buyers: Array) -> Control:
	var item: Dictionary = lot.item
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Lot%d" % int(lot.lot)
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	line.add_child(_icon(item))
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var title := UIUtil.label(PlayerStall._label(item), &"BoldLabel")
	title.add_theme_color_override("font_color", ItemData.color_of(item))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title)
	var tag := ItemData.class_tag(item, String(Game.class_id()))
	if tag != "":
		var owner := UIUtil.label(tag, &"SmallLabel")
		owner.add_theme_color_override("font_color", ItemData.CLASS_TAG_COLOR)
		info.add_child(owner)
	var price := int(lot.price)
	var fair := PlayerStall.fair_price(item)
	var mins := int(maxf(0.0, WorldPresence.clock() - float(lot.listed_at)) / 60.0)
	var note := UIUtil.label("%s เหรียญ (%d%%) · %s · วางมา %s" % [PlayerStall.thousands(price), int(round(100.0 * price / maxf(1.0, fair))),
		PlayerStall.speed_text(item, price, PlayerStall.demand(item, buyers)), _ago(mins)], &"SmallLabel")
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(note)
	var take := UIUtil.button("เก็บคืน", &"", Vector2(120, 56))
	take.name = "Unlist"
	var id := int(lot.lot)
	take.pressed.connect(func():
		AudioManager.play_sfx(&"pickup")
		PlayerStall.unlist(id))
	line.add_child(take)
	return panel


func _log_row(entry: Dictionary) -> Control:
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_font_size_override("normal_font_size", 17)
	var mins := int(maxf(0.0, WorldPresence.clock() - float(entry.get("at", 0))) / 60.0)
	var who := String(entry.get("buyer", "")).replace("[", "(")
	row.text = "[color=#bfe8ff]%s[/color] ซื้อ [color=#%s]%s[/color] · [color=#ffd84a]%s เหรียญ[/color] · [color=#8595a8]%s%s[/color]" % [
		who, String(entry.get("color", "ffffff")), String(entry.get("name", "")).replace("[", "("),
		PlayerStall.thousands(int(entry.get("price", 0))), _ago(mins), " · ผู้เล่นจริง" if bool(entry.get("real", false)) else ""]
	return row


static func _ago(minutes: int) -> String:
	if minutes < 1:
		return "เมื่อครู่"
	if minutes < 60:
		return "%d นาทีก่อน" % minutes
	if minutes < 60 * 24:
		return "%d ชม.ก่อน" % (minutes / 60)
	return "%d วันก่อน" % (minutes / 1440)


# --- Adding a lot -------------------------------------------------------------------

func _picked() -> Dictionary:
	var i := int(view.pick)
	if i < 0 or i >= Game.profile.inv.size():
		view["pick"] = -1
		return {}
	var item: Dictionary = (Game.profile.inv[i] as Dictionary).duplicate(true)
	if ItemData.is_stackable(item):
		var stack := int(item.get("count", 1))
		view["count"] = clampi(int(view.count) if int(view.count) > 0 else stack, 1, stack)
		item["count"] = int(view.count)
	return item


func _build_side() -> void:
	UIUtil.clear(_side)
	_side.add_child(UIUtil.label("เลือกของจากกระเป๋า", &"BoldLabel"))
	var scroll := TouchScroll.new()
	scroll.name = "BagPick"
	scroll.custom_minimum_size = Vector2(0, 2 * PICK_SIZE.y + 12)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var any := false
	for i: int in Game.profile.inv.size():
		var item: Dictionary = Game.profile.inv[i]
		if PlayerStall.fair_price(item) <= 0:
			continue
		any = true
		var b := Button.new()
		b.custom_minimum_size = PICK_SIZE
		b.expand_icon = true
		b.icon = ItemLook.icon(item)
		b.add_theme_constant_override("icon_max_width", 54)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = ItemData.name_of(item)
		var tag := ItemData.class_tag(item, String(Game.class_id()))
		if tag != "":
			b.tooltip_text += "\n" + tag
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.1, 0.18, 0.9)
		style.border_color = ItemData.color_of(item) if i != int(view.pick) else Color.WHITE
		style.set_border_width_all(2 if i != int(view.pick) else 4)
		style.set_corner_radius_all(10)
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", style)
		var index: int = i
		b.pressed.connect(func():
			view["pick"] = index
			view["count"] = 0
			var fresh := _picked()
			view["price"] = PlayerStall.fair_price(fresh)
			_build_side())
		grid.add_child(b)
	if not any:
		_side.add_child(UIUtil.label("ไม่มีของที่ตั้งขายได้ในกระเป๋า", &"DimLabel"))
	var item := _picked()
	if item.is_empty():
		var tip := UIUtil.label("แตะไอเทมด้านบนเพื่อตั้งราคา", &"DimLabel")
		_side.add_child(tip)
		return
	var title := UIUtil.label(ItemData.name_of(item), &"SubHeaderLabel")
	title.add_theme_color_override("font_color", ItemData.color_of(item))
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_side.add_child(title)
	var tag := ItemData.class_tag(item, String(Game.class_id()))
	var fair := PlayerStall.fair_price(item)
	var fair_label := UIUtil.label("ราคาแนะนำ %s เหรียญ%s" % [PlayerStall.thousands(fair), " · " + tag if tag != "" else ""], &"SmallLabel")
	if tag != "":
		fair_label.add_theme_color_override("font_color", ItemData.CLASS_TAG_COLOR)
	_side.add_child(fair_label)
	view["price"] = PlayerStall.clamp_price(item, int(view.price) if int(view.price) > 0 else fair)
	# Price: −/+ 10% of the fair price around a typed number, a 50-300% slider, quick steps.
	var row := UIUtil.hbox(6)
	_side.add_child(row)
	var minus := UIUtil.button("−", &"", Vector2(64, 56))
	var field := LineEdit.new()
	field.name = "PriceField"
	field.custom_minimum_size = Vector2(0, 56)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	field.add_theme_font_size_override("font_size", 22)
	var plus := UIUtil.button("+", &"", Vector2(64, 56))
	row.add_child(minus)
	row.add_child(field)
	row.add_child(plus)
	var slider := HSlider.new()
	slider.name = "PriceSlider"
	slider.min_value = PlayerStall.PRICE_MIN * 100.0
	slider.max_value = PlayerStall.PRICE_MAX * 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 36)
	_side.add_child(slider)
	var quick := UIUtil.hbox(4)
	_side.add_child(quick)
	var speed := UIUtil.label("", &"SmallLabel")
	var sell := UIUtil.button("", &"PrimaryButton", Vector2(0, 60))
	sell.name = "ListButton"
	var refresh_price := func():
		_syncing = true
		field.text = PlayerStall.thousands(int(view.price))
		slider.value = 100.0 * float(view.price) / maxf(1.0, float(fair))
		_syncing = false
		speed.text = "ราคา %d%% ของราคาแนะนำ · %s" % [int(round(100.0 * float(view.price) / maxf(1.0, float(fair)))),
			PlayerStall.speed_text(item, int(view.price), PlayerStall.demand(item, PlayerStall.pool(WorldPresence.clock())))]
		sell.text = "ตั้งขาย %s เหรียญ" % PlayerStall.thousands(int(view.price))
		sell.disabled = PlayerStall.lots().size() >= PlayerStall.MAX_LOTS
		if sell.disabled:
			sell.text = "แผงเต็ม (%d ชิ้น)" % PlayerStall.MAX_LOTS
	var set_price := func(value: int):
		view["price"] = PlayerStall.clamp_price(item, value)
		refresh_price.call()
	minus.pressed.connect(func(): set_price.call(int(view.price) - maxi(1, fair / 10)))
	plus.pressed.connect(func(): set_price.call(int(view.price) + maxi(1, fair / 10)))
	field.text_submitted.connect(func(text: String): set_price.call(_parse(text, int(view.price))))
	field.focus_exited.connect(func(): set_price.call(_parse(field.text, int(view.price))))
	slider.value_changed.connect(func(v: float):
		if not _syncing:
			set_price.call(int(round(float(fair) * v / 100.0))))
	for step in QUICK_STEPS:
		var chip := UIUtil.button("%d%%" % step, &"", Vector2(0, 52))
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 18)
		chip.pressed.connect(func(): set_price.call(int(round(float(fair) * step / 100.0))))
		quick.add_child(chip)
	if ItemData.is_stackable(item):
		var stack := int((Game.profile.inv[int(view.pick)] as Dictionary).get("count", 1))
		var count_row := UIUtil.hbox(6)
		_side.add_child(count_row)
		var fewer := UIUtil.button("−", &"", Vector2(64, 52))
		var count_label := UIUtil.label("จำนวน %d / %d" % [int(view.count), stack], &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var more := UIUtil.button("+", &"", Vector2(64, 52))
		var all := UIUtil.button("ทั้งหมด", &"", Vector2(110, 52))
		for spec in [[fewer, -1], [more, 1], [all, stack]]:
			var delta: int = spec[1]
			(spec[0] as Button).pressed.connect(func():
				var before := maxi(1, int(view.count))
				view["count"] = stack if spec[0] == all else clampi(before + delta, 1, stack)
				# Keep the price per piece when the count changes.
				view["price"] = int(round(float(view.price) * float(view.count) / float(before)))
				_build_side())
		count_row.add_child(fewer)
		count_row.add_child(count_label)
		count_row.add_child(more)
		count_row.add_child(all)
	speed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(speed)
	_side.add_child(sell)
	sell.pressed.connect(func():
		var index := int(view.pick)
		var lot := PlayerStall.list_item(index, int(view.price), int(view.count) if ItemData.is_stackable(item) else 0)
		if lot >= 0:
			AudioManager.play_sfx(&"coin")
			view["pick"] = -1
			view["count"] = 0
			view["price"] = 0
			_refresh())
	var blocked := PlayerStall.blocked_reason()
	refresh_price.call()
	if blocked != "":
		sell.disabled = true
		sell.text = blocked


static func _parse(text: String, fallback: int) -> int:
	var digits := ""
	for c in text:
		if c >= "0" and c <= "9":
			digits += c
	return int(digits) if digits != "" and digits.length() < 13 else fallback
