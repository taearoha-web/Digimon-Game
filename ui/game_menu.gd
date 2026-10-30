class_name GameMenu
extends CanvasLayer
## The in-game menu: character (stat points), bag + equipment, skills,
## quests and settings. Pauses the game while open.

signal closed()
signal title_requested()

const TABS := [
	["character", "ตัวละคร"], ["inventory", "กระเป๋า"], ["skills", "สกิล"], ["quests", "เควสต์"], ["achievements", "ความสำเร็จ"], ["titles", "ตำแหน่ง"], ["settings", "ตั้งค่า"],
]

var is_open := false
var current_tab: StringName = &"inventory"

var _root: Control
var _content: Control
var _tab_buttons: Dictionary = {}
var _selected_index := -1
var _selected_slot := ""
var _detail: VBoxContainer
## Buttons for the selected item, pinned above the scrolling detail text.
var _actions: VBoxContainer
var _item_buttons: Array[Dictionary] = []
## The tab's main scroll list; a rebuild (after a sale, a point spent, ...)
## puts it back where it was instead of jumping to the top.
var _page_scroll: TouchScroll
## Keep each stat's typed quantity when the menu refreshes after allocation.
var _stat_amounts: Dictionary = {}
## Opened from the blacksmith: items can be enhanced and socketed.
var forge_mode := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.78)
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
	var row := UIUtil.hbox(14)
	panel.add_child(row)
	var tabs := UIUtil.vbox(8)
	tabs.custom_minimum_size = Vector2(190, 0)
	row.add_child(tabs)
	for tab in TABS:
		var b := UIUtil.button(String(tab[1]), &"", Vector2(0, 54))
		b.pressed.connect(func(): show_tab(StringName(tab[0])))
		tabs.add_child(b)
		_tab_buttons[StringName(tab[0])] = b
	tabs.add_child(UIUtil.spacer(false))
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(0, 66))
	close.pressed.connect(close_menu)
	tabs.add_child(close)
	_content = Control.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_content)
	Game.profile_changed.connect(_queue_rebuild)
	Game.inventory_changed.connect(_queue_rebuild)
	Game.quest_changed.connect(_queue_rebuild)


func open_menu(tab: StringName = &"inventory") -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	show_tab(tab)


func close_menu() -> void:
	forge_mode = false
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_content)
	get_tree().paused = false
	AudioManager.play_ui(&"ui_cancel")
	closed.emit()


func show_tab(tab: StringName) -> void:
	_page_scroll = null
	current_tab = tab
	_selected_index = -1
	_selected_slot = ""
	_rebuild()



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
	var keep_y := _page_scroll.retained_vertical_position() if is_instance_valid(_page_scroll) else 0
	_page_scroll = null
	for key in _tab_buttons:
		_tab_buttons[key].disabled = key == current_tab
	UIUtil.clear(_content)
	match current_tab:
		&"character": _build_character()
		&"inventory": _build_inventory()
		&"skills": _build_skills()
		&"quests": _build_quests()
		&"achievements": _build_achievements()
		&"titles": _build_titles()
		&"settings": _build_settings()
	if is_instance_valid(_page_scroll):
		_page_scroll.restore_vertical_position(keep_y)


# ---------------------------------------------------------------------------
# Character
# ---------------------------------------------------------------------------

func _build_character() -> void:
	var p := Game.profile
	var stats := Game.stats_now()
	var data := Game.class_data()
	var row := UIUtil.hbox(20)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	var left_scroll := TouchScroll.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(left_scroll)
	_page_scroll = left_scroll
	var left := UIUtil.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	left.add_child(UIUtil.label("%s  Lv.%d  (%s)" % [p.name, p.level, data.name], &"HeaderLabel"))
	var points := UIUtil.label("แต้มสถานะที่ใช้ได้: %d" % int(p.points), &"SubHeaderLabel")
	left.add_child(points)
	left.add_child(UIUtil.label("กรอกจำนวนแต้ม แล้วกดเพิ่มที่ค่าสถานะที่ต้องการ", &"SmallLabel"))
	var names := {"str": "STR พลัง", "int": "INT ปัญญา", "dex": "DEX ความคล่อง", "vit": "VIT ความทนทาน"}
	var notes := {"str": "เพิ่มพลังโจมตีของนักรบ (และนักหอกเล็กน้อย)", "int": "เพิ่มพลังเวทและ MP", "dex": "เพิ่มพลังโจมตีของนักธนู/นักหอก คริติคอล หลบหลีก และความเร็วสกิล", "vit": "เพิ่ม HP และพลังป้องกัน"}
	for key in ["str", "int", "dex", "vit"]:
		var block := UIUtil.vbox(3)
		left.add_child(block)
		var line := UIUtil.hbox(10)
		block.add_child(line)
		var label := UIUtil.label("%s  %d" % [names[key], int(stats.attrs[key])], &"BoldLabel")
		label.custom_minimum_size = Vector2(250, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var amount := LineEdit.new()
		amount.name = "StatAmount_" + key
		amount.custom_minimum_size = Vector2(116, 56)
		amount.alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		amount.max_length = 9
		amount.placeholder_text = "จำนวน"
		amount.text = String(_stat_amounts.get(key, "1"))
		amount.editable = int(p.points) > 0
		amount.select_all_on_focus = true
		line.add_child(amount)
		var plus := UIUtil.button("เพิ่ม", &"PrimaryButton", Vector2(100, 56))
		plus.name = "StatAdd_" + key
		line.add_child(plus)
		var note := UIUtil.label(notes[key], &"SmallLabel")
		note.name = "StatNote_" + key
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(note)
		var validate := func():
			var count := _stat_amount(amount.text)
			plus.disabled = count <= 0 or count > int(p.points)
			note.text = notes[key]
			note.remove_theme_color_override("font_color")
			if int(p.points) > 0 and plus.disabled:
				note.text = "กรอกจำนวนเต็มตั้งแต่ 1 ถึง %d แต้ม" % int(p.points)
				note.add_theme_color_override("font_color", UIPalette.WARNING)
		amount.text_changed.connect(func(text: String):
			_stat_amounts[key] = text
			validate.call())
		if OS.has_feature("web"):
			# Godot 4.3's experimental phone keyboard uses set_text without
			# emitting text_changed. Sync only the focused input while editing.
			var keyboard_sync := Timer.new()
			keyboard_sync.wait_time = 0.05
			amount.add_child(keyboard_sync)
			keyboard_sync.timeout.connect(func():
				if String(_stat_amounts.get(key, "1")) != amount.text:
					_stat_amounts[key] = amount.text
					validate.call())
			amount.focus_entered.connect(keyboard_sync.start)
			amount.focus_exited.connect(keyboard_sync.stop)
		plus.pressed.connect(func(): _apply_stat_amount(key, amount, plus))
		amount.text_submitted.connect(func(_text: String): _apply_stat_amount(key, amount, plus))
		validate.call()
	if int(p.level) >= Game.MAX_LEVEL:
		_build_paragon(left)
	var right := UIUtil.vbox(6)
	right.custom_minimum_size = Vector2(380, 0)
	row.add_child(right)
	right.add_child(UIUtil.label("ค่าพลัง", &"SubHeaderLabel"))
	for line in [
		["HP", "%d / %d" % [p.hp, stats.max_hp]], ["MP", "%d / %d" % [p.mp, stats.max_mp]],
		["พลังโจมตี", "%d" % int(stats.atk)], ["พลังป้องกัน", "%d" % int(stats.def)],
		["คริติคอล", "%.1f%%" % (float(stats.crit) * 100.0)], ["หลบหลีก", "%.1f%%" % (float(stats.dodge) * 100.0)], ["ความเร็วสกิล", "+%.1f%%" % (float(stats.haste) * 100.0)],
		["EXP", _exp_text()], ["สังหารมอนสเตอร์", "%d ตัว" % int(p.kills)],
		["เวลาเล่น", UIUtil.format_play_time(float(p.play_time))],
	]:
		var r := UIUtil.hbox(8)
		var k := UIUtil.label(line[0], &"DimLabel")
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(k)
		r.add_child(UIUtil.label(line[1], &"BoldLabel"))
		right.add_child(r)


## Reject fractions, signs and malformed pasted text instead of rounding them.
static func _stat_amount(text: String) -> int:
	var value := text.strip_edges()
	if value.is_empty() or value.length() > 9:
		return 0
	for digit in value:
		if digit < "0" or digit > "9":
			return 0
	return value.to_int()


func _apply_stat_amount(key: String, amount: LineEdit, plus: Button) -> void:
	if plus.disabled or not amount.is_inside_tree():
		return
	var count := _stat_amount(amount.text)
	_stat_amounts[key] = amount.text
	# Hide the phone keyboard before the profile signal replaces this row.
	plus.disabled = true
	amount.release_focus()
	if Game.spend_point(key, count):
		if not Game.save():
			Game.say("อัปแต้มแล้ว แต่ยังบันทึกไม่ได้ ระบบจะลองบันทึกให้อีกครั้ง", &"warning")
	else:
		_rebuild()


func _exp_text() -> String:
	var p := Game.profile
	if int(p.level) >= Game.MAX_LEVEL:
		var para := Game.paragon()
		if int(para.level) >= Game.PARAGON_MAX:
			return "ระดับสูงสุด ดาว %d" % Game.PARAGON_MAX
		return "ดาว %d  %d / %d" % [int(para.level), int(para.exp), Game.paragon_need()]
	return "%d / %d" % [p.exp, HeroStats.exp_to_next(p.level)]


## Paragon buttons per stat: +1, +5, +10 and 0 = everything that still fits.
const PARAGON_STEPS := [1, 5, 10, 0]


func _spend_paragon(key: String, count: int) -> void:
	if Game.paragon_spend(key, count) and not Game.save():
		Game.say("อัปแต้มแล้ว แต่ยังบันทึกไม่ได้ ระบบจะลองบันทึกให้อีกครั้ง", &"warning")


## Paragon points (after Lv.100): permanent bonuses with a gold refund button.
func _build_paragon(parent: Control) -> void:
	var para := Game.paragon()
	var head := UIUtil.hbox(8)
	head.add_child(UIUtil.star_count(int(para.level), 28, &"SubHeaderLabel"))
	head.add_child(UIUtil.label("ระดับเหนือเลเวล / %d  ·  แต้มที่ใช้ได้ %d" % [Game.PARAGON_MAX, int(para.points)], &"SubHeaderLabel"))
	parent.add_child(head)
	for key in Game.PARAGON_STATS:
		var info: Array = Game.PARAGON_STATS[key]
		var used := int(para.alloc[key])
		var block := UIUtil.vbox(3)
		parent.add_child(block)
		var line := UIUtil.hbox(6)
		block.add_child(line)
		var label := UIUtil.label("%s %d/%d" % [info[0], used, int(info[2])], &"BoldLabel")
		label.custom_minimum_size = Vector2(200, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var room := mini(int(para.points), int(info[2]) - used)
		for step in PARAGON_STEPS:
			# A step larger than what is left spends what is left.
			var count := room if step == 0 else mini(int(step), room)
			var plus := UIUtil.button("สุด" if step == 0 else "+%d" % int(step), &"PrimaryButton", Vector2(68, 52))
			plus.name = "Paragon_%s_%s" % [key, "max" if step == 0 else str(step)]
			plus.disabled = room <= 0
			plus.pressed.connect(func(): _spend_paragon(key, count))
			line.add_child(plus)
		block.add_child(UIUtil.label(String(info[3]).replace("%%", "%"), &"SmallLabel"))
	if int(para.spent) > 0:
		var reset := UIUtil.button("คืนแต้มทั้งหมด (%d เหรียญ)" % Game.paragon_reset_cost(), &"", Vector2(0, 48))
		reset.pressed.connect(func():
			if Game.paragon_reset():
				Game.say("คืนแต้มพาราก้อนแล้ว", &"success")
			else:
				Game.say("เหรียญไม่พอ", &"warning"))
		parent.add_child(reset)


# ---------------------------------------------------------------------------
# Inventory & equipment
# ---------------------------------------------------------------------------

func _build_inventory() -> void:
	_item_buttons.clear()
	var row := UIUtil.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(row)
	# Paper doll + equipment slots
	var equip := UIUtil.vbox(6)
	equip.custom_minimum_size = Vector2(240, 0)
	row.add_child(equip)
	var preview := HeroPreview.new(Vector2i(240, 290))
	equip.add_child(preview)
	preview.show_hero(Game.class_id(), Game.profile.equip, "", Game.profile.get("look", {}))
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 6)
	slots.add_theme_constant_override("v_separation", 6)
	equip.add_child(slots)
	for slot in ItemData.EQUIP_SLOTS:
		var item: Variant = Game.profile.equip.get(slot)
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 74)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 58)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if item != null:
			b.icon = ItemLook.icon(item)
			b.tooltip_text = ItemData.name_of(item)
			_style_item_button(b, ItemData.color_of(item), _selected_slot == slot)
		else:
			b.text = ItemData.SLOT_NAMES[slot]
			b.add_theme_font_size_override("font_size", 16)
			b.modulate = Color(1, 1, 1, 0.7)
		b.pressed.connect(func():
			_selected_slot = slot
			_selected_index = -1
			_refresh_detail())
		slots.add_child(b)
		_item_buttons.append({"button": b, "slot": slot, "index": -1, "color": ItemData.color_of(item) if item != null else UIPalette.TEXT_MUTED})
	# Bag grid
	var middle := UIUtil.vbox(6)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	var head := UIUtil.hbox(8)
	middle.add_child(head)
	var count_label := UIUtil.label("กระเป๋า (%d/%d)" % [Game.profile.inv.size(), Game.bag_size()], &"SubHeaderLabel")
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(count_label)
	var auto_sell := UIUtil.button("ขายอัตโนมัติ", &"", Vector2(150, 50))
	auto_sell.add_theme_font_size_override("font_size", 18)
	auto_sell.pressed.connect(_open_auto_sell)
	head.add_child(auto_sell)
	auto_sell.visible = not forge_mode
	var filter := UIUtil.button("ตัวกรองเก็บของ", &"", Vector2(160, 50))
	filter.add_theme_font_size_override("font_size", 18)
	filter.pressed.connect(_open_loot_filter)
	head.add_child(filter)
	filter.visible = not forge_mode
	middle.add_child(UIUtil.label("แตะไอเทมเพื่อเทียบกับอุปกรณ์ที่ใส่", &"SmallLabel"))
	var scroll := TouchScroll.new()
	_page_scroll = scroll
	scroll.name = "BagScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in Game.bag_size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(90, 92)
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		if i < Game.profile.inv.size():
			var item: Dictionary = Game.profile.inv[i]
			b.icon = ItemLook.icon(item)
			b.text = ("×%d" % int(item.count)) if ItemData.is_stackable(item) else ItemData.level_text(int(item.level)).replace("Lv.100 ", "")
			b.add_theme_color_override("font_color", ItemData.color_of(item))
			b.add_theme_font_size_override("font_size", 17)
			_style_item_button(b, ItemData.color_of(item), _selected_index == i)
			b.tooltip_text = "%s · %s" % [ItemData.name_of(item), ItemData.RARITY_NAMES[int(item.get("rarity", 0))]]
			_item_buttons.append({"button": b, "slot": "", "index": i, "color": ItemData.color_of(item)})
			b.pressed.connect(func():
				_selected_index = i
				_selected_slot = ""
				_refresh_detail())
		else:
			b.disabled = true
		grid.add_child(b)
	var side := UIUtil.vbox(8)
	side.custom_minimum_size = Vector2(260, 0)
	row.add_child(side)
	_actions = UIUtil.vbox(6)
	side.add_child(_actions)
	var detail_scroll := TouchScroll.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(detail_scroll)
	_detail = UIUtil.vbox(8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_refresh_detail()


## "Compared with what you wear now": the worn item of the same slot and the
## stat differences (green = better, red = worse).
func _build_compare(item: Dictionary) -> void:
	var slot := String(item.slot)
	var worn: Variant = Game.profile.equip.get(slot)
	_detail.add_child(UIUtil.label("เทียบกับที่ใส่อยู่", &"SubHeaderLabel"))
	var now := HeroStats.gear_bonus({"equip": {slot: worn}} if worn != null else {"equip": {}})
	var then := HeroStats.gear_bonus({"equip": {slot: item}})
	var labels := {"atk": "พลังโจมตี", "matk": "โจมตีเวทย์", "def": "พลังป้องกัน", "hp": "HP", "mp": "MP", "crit": "คริติคอล"}
	var any := false
	for key in ["atk", "matk", "def", "hp", "mp", "crit"]:
		var delta := float(then.get(key, 0.0)) - float(now.get(key, 0.0))
		if absf(delta) < 0.0005:
			continue
		any = true
		var text := "%s %s%s" % [labels[key], "+" if delta > 0.0 else "-", ("%.1f%%" % (absf(delta) * 100.0)) if key == "crit" else str(int(round(absf(delta))))]
		var diff := UIUtil.label(text + (" (ดีกว่า)" if delta > 0.0 else " (แย่กว่า)"), &"BoldLabel")
		diff.add_theme_color_override("font_color", Color("6dff9a") if delta > 0.0 else Color("ff7a8a"))
		_detail.add_child(diff)
	if not any:
		_detail.add_child(UIUtil.label("ค่าพลังเท่ากัน", &"SmallLabel"))
	if worn == null:
		var none := UIUtil.label("(ช่อง%sยังว่างอยู่)" % ItemData.SLOT_NAMES.get(slot, slot), &"SmallLabel")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(none)
		return
	var name_label := UIUtil.label("ที่ใส่อยู่: " + ItemData.name_of(worn), &"SmallLabel")
	name_label.add_theme_color_override("font_color", ItemData.color_of(worn))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(name_label)
	var worn_lines := ItemData.level_text(int(worn.level)) + " · " + " · ".join(ItemData.stat_lines(worn))
	var worn_label := UIUtil.label(worn_lines, &"DimLabel")
	worn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	worn_label.custom_minimum_size = Vector2(240, 0)
	_detail.add_child(worn_label)


func _refresh_detail() -> void:
	for entry in _item_buttons:
		if is_instance_valid(entry.button):
			var selected: bool = (entry.slot != "" and entry.slot == _selected_slot) or (entry.slot == "" and entry.index == _selected_index)
			_style_item_button(entry.button, entry.color, selected)
	if _detail == null or not is_instance_valid(_detail):
		return
	UIUtil.clear(_detail)
	if _actions != null and is_instance_valid(_actions):
		UIUtil.clear(_actions)
	var item: Variant = null
	if _selected_slot != "":
		item = Game.profile.equip.get(_selected_slot)
	elif _selected_index >= 0 and _selected_index < Game.profile.inv.size():
		item = Game.profile.inv[_selected_index]
	if item == null:
		_detail.add_child(UIUtil.label("แตะไอเทมเพื่อดูรายละเอียด", &"DimLabel"))
		return
	var big := TextureRect.new()
	big.texture = ItemLook.icon(item)
	big.custom_minimum_size = Vector2(0, 72)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(big)
	var title := UIUtil.label(ItemData.name_of(item), &"SubHeaderLabel")
	title.add_theme_color_override("font_color", ItemData.color_of(item))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(title)
	if item.get("kind", "") == "equip":
		_detail.add_child(UIUtil.label("%s • %s • ต้องการ %s" % [ItemData.SLOT_NAMES[item.slot], ItemData.RARITY_NAMES[int(item.rarity)], ItemData.level_text(int(item.level))], &"SmallLabel"))
		if item.get("class", "") != "":
			_detail.add_child(UIUtil.label("อาชีพ: " + String(ClassData.get_class_data(StringName(item["class"])).name), &"SmallLabel"))
	if _selected_slot == "" and item.get("kind", "") == "equip":
		_build_compare(item)
	for line in ItemData.detail_lines(item):
		var detail_label := UIUtil.label(line, &"BoldLabel" if not line.begins_with("เซ็ต") else &"SmallLabel")
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(detail_label)
	if item.get("kind", "") == "equip" and str(item.get("set", "")) != "":
		var counts := HeroStats.set_counts(Game.profile)
		var set_label := UIUtil.label("สวมอยู่ %d/4 ชิ้น: 2=HP • 3=โจมตี • 4=ป้องกัน+คริ" % int(counts.get(item.set, 0)), &"DimLabel")
		set_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		set_label.custom_minimum_size = Vector2(240, 0)
		_detail.add_child(set_label)
	if forge_mode and item.get("kind", "") == "equip":
		_build_forge_buttons(item)
	# Actions sit above the scrolling text so they never need scrolling to.
	var target: Control = _actions if _actions != null and is_instance_valid(_actions) else _detail
	if item.get("kind", "") == "equip":
		var problem := Game.equip_problem(item)
		var equipped := _selected_slot != ""
		if equipped:
			var take := UIUtil.button("ถอด", &"", Vector2(0, 58))
			take.pressed.connect(func(): Game.unequip(_selected_slot); _selected_slot = ""; _rebuild())
			target.add_child(take)
		else:
			var pair := UIUtil.hbox(6)
			target.add_child(pair)
			var wear := UIUtil.button("สวมใส่" if problem == "" else problem, &"PrimaryButton", Vector2(0, 58))
			wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wear.clip_text = true
			wear.disabled = problem != ""
			wear.pressed.connect(func(): Game.equip_from_bag(_selected_index); _selected_index = -1; _rebuild())
			pair.add_child(wear)
			var sell := UIUtil.button("ขาย +%d" % ItemData.sell_price(item), &"", Vector2(0, 58))
			sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sell.pressed.connect(func(): _sell_selected(1))
			pair.add_child(sell)
	elif item.get("kind", "") == "jewel":
		var craft := String(item.get("id", "")) in StarWingData.CRAFT_COST
		var how := UIUtil.label(("ใช้ตีปีกที่ช่างตีเหล็ก: ปีกเลเวล 100 + เพชรชาออส 1 เม็ด + ขนนก 1 ขน ได้ปีก 100 ดาวประจำอาชีพ (โอกาส %d%%)" % int(StarWingData.CRAFT_CHANCE * 100.0)) if craft
			else ("เจาะช่องอัญมณีเพิ่มให้อาวุธ/ชุด/ปีก ทีละ 1 ช่อง สูงสุด %d ช่อง (ตีบวก +15 ได้ช่องที่ 4) · กดที่ไอเทมแล้วเลือก \"เจาะช่องอัญมณีเพิ่ม\"" % ItemData.MAX_SOCKETS) if String(item.get("id", "")) == "drill"
			else "ใช้ตีบวกที่ช่างตีเหล็ก: เพชรม่วงตี +1 ถึง +6 (สำเร็จ 100%) · เพชรชมพูตี +7 ถึง +9 (50%) · +10 ใช้เพชรม่วง 3 + ชมพู 2 (50%) · +11 ถึง +15 ใช้เพชรมากขึ้น (40% ลดลงถึง 15%)", &"DimLabel")
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(how)
		var sell_jewel := UIUtil.button("ขาย +%d" % ItemData.unit_sell_price(item), &"", Vector2(0, 58))
		sell_jewel.pressed.connect(func(): _sell_selected(1))
		target.add_child(sell_jewel)
	elif item.get("kind", "") == "gem":
		_detail.add_child(UIUtil.label("ไปที่ช่างตีเหล็กเพื่อใส่ลงช่องในอาวุธ/ชุด", &"DimLabel"))
		var info := ItemData.gem_info(item)
		if info.size < ItemData.GEM_MAX_SIZE:
			var gem_id := String(item.id)
			var fuse := UIUtil.button("รวม 3 เม็ด → %s (%d%% · %d เหรียญ)" % [ItemData.GEM_SIZES[info.size + 1], int(float(ItemData.GEM_FUSE_CHANCE[info.size]) * 100.0), int(ItemData.GEM_FUSE_GOLD[info.size])], &"PrimaryButton", Vector2(0, 58))
			fuse.disabled = int(item.get("count", 1)) < 3
			fuse.pressed.connect(func():
				var result := Game.fuse_gem(gem_id)
				match result:
					"ok":
						Game.say("รวมอัญมณีสำเร็จ! ได้%s%s" % [ItemData.GEMS[info.type].name, ItemData.GEM_SIZES[info.size + 1]], &"success")
						AudioManager.play_sfx(&"level_up")
					"fail":
						Game.say("รวมอัญมณีพลาด... เสียไป 1 เม็ด", &"warning")
					_:
						Game.say(result, &"warning")
				_selected_index = -1
				_rebuild())
			target.add_child(fuse)
		var sell_gem := UIUtil.button("ขาย +%d" % ItemData.unit_sell_price(item), &"", Vector2(0, 58))
		sell_gem.pressed.connect(func(): _sell_selected(1))
		target.add_child(sell_gem)
	else:
		var use := UIUtil.button("ใช้", &"PrimaryButton", Vector2(0, 58))
		use.pressed.connect(func(): _use_potion(_selected_index))
		target.add_child(use)


## Sells the selected bag item and keeps the selection on the next one, so a
## row of junk can be sold by tapping "sell" again and again.
func _sell_selected(count: int) -> void:
	if _selected_index < 0 or _selected_index >= Game.profile.inv.size():
		return
	Game.sell_item(_selected_index, count)
	if _selected_index >= Game.profile.inv.size():
		_selected_index = Game.profile.inv.size() - 1
	_rebuild()


const LEVEL_STEPS := [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]


## Auto-sell: pick the grades and a level limit, see what would go, sell it all.
func _open_auto_sell() -> void:
	UIUtil.clear(_content)
	var flags: Dictionary = Game.profile.flags
	var state := {"mask": int(flags.get("autosell_mask", 3)), "level": int(flags.get("autosell_level", 0))}
	var box := UIUtil.vbox(12)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("ขายอัตโนมัติ", &"HeaderLabel"))
	box.add_child(UIUtil.label("1. เลือกเกรดที่จะขาย (เรียงจากต่ำสุดไปสูงสุด)", &"BoldLabel"))
	var grades := UIUtil.hbox(8)
	box.add_child(grades)
	var level_row := UIUtil.hbox(10)
	var level_label := UIUtil.label("", &"SubHeaderLabel")
	var preview := UIUtil.label("", &"BoldLabel")
	var sell := UIUtil.button("", &"PrimaryButton", Vector2(320, 64))
	var refresh := func():
		var picked := Game.auto_sell_indices(int(state.mask), int(state.level))
		var gold := 0
		for i in picked:
			gold += ItemData.sell_price(Game.profile.inv[i])
		level_label.text = "ทุกเลเวล" if int(state.level) == 0 else "ต่ำกว่า Lv.%d" % int(state.level)
		preview.text = "จะขาย %d ชิ้น ได้ %d เหรียญ" % [picked.size(), gold]
		sell.text = "ขาย %d ชิ้น" % picked.size()
		sell.disabled = picked.is_empty()
	for r in 5:
		var chip := _grade_toggle(r, (int(state.mask) >> r) & 1 == 1, "ขาย", "ไม่ขาย")
		chip.toggled.connect(func(on: bool):
			state["mask"] = (int(state.mask) | (1 << r)) if on else (int(state.mask) & ~(1 << r))
			refresh.call())
		grades.add_child(chip)
	box.add_child(UIUtil.label("2. เลเวลของไอเทม", &"BoldLabel"))
	box.add_child(level_row)
	var minus := UIUtil.button("−", &"", Vector2(72, 60))
	var plus := UIUtil.button("+", &"", Vector2(72, 60))
	level_label.custom_minimum_size = Vector2(220, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minus.pressed.connect(func():
		state["level"] = LEVEL_STEPS[maxi(0, LEVEL_STEPS.find(int(state.level)) - 1)]
		refresh.call())
	plus.pressed.connect(func():
		state["level"] = LEVEL_STEPS[mini(LEVEL_STEPS.size() - 1, LEVEL_STEPS.find(int(state.level)) + 1)]
		refresh.call())
	level_row.add_child(minus)
	level_row.add_child(level_label)
	level_row.add_child(plus)
	var keep := UIUtil.label("ไม่ขายเสมอ: ของที่สวมอยู่ ของที่ตีบวกแล้ว ของที่ใส่อัญมณี และปีก", &"DimLabel")
	keep.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(keep)
	box.add_child(preview)
	var buttons := UIUtil.hbox(10)
	box.add_child(buttons)
	sell.pressed.connect(func():
		Game.auto_sell(int(state.mask), int(state.level))
		_selected_index = -1
		_rebuild())
	buttons.add_child(sell)
	var back := UIUtil.button("กลับ", &"", Vector2(160, 64))
	back.pressed.connect(_rebuild)
	buttons.add_child(back)
	refresh.call()


## Pickup filter: which grades of dropped gear the hero picks up.
func _open_loot_filter() -> void:
	UIUtil.clear(_content)
	var box := UIUtil.vbox(12)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("ตัวกรองเก็บของ", &"HeaderLabel"))
	box.add_child(UIUtil.label("เลือกเกรดอุปกรณ์ที่จะเก็บเมื่อมอนสเตอร์ดรอป (เรียงจากต่ำสุดไปสูงสุด)", &"BoldLabel"))
	var grades := UIUtil.hbox(8)
	box.add_child(grades)
	for r in 5:
		var chip := _grade_toggle(r, (Game.loot_mask() >> r) & 1 == 1, "เก็บ", "ไม่เก็บ")
		chip.toggled.connect(func(on: bool):
			Game.set_loot_mask((Game.loot_mask() | (1 << r)) if on else (Game.loot_mask() & ~(1 << r))))
		grades.add_child(chip)
	var quick := UIUtil.hbox(8)
	box.add_child(quick)
	for spec in [["เก็บทุกเกรด", 31], ["ดี ขึ้นไป", 30], ["หายาก ขึ้นไป", 28], ["ในตำนาน ขึ้นไป", 24]]:
		var b := UIUtil.button(String(spec[0]), &"", Vector2(0, 54))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			Game.set_loot_mask(int(spec[1]))
			_open_loot_filter())
		quick.add_child(b)
	var note := UIUtil.label("ยา อัญมณี เหรียญ และปีก เก็บเสมอ · ของเกรดที่ปิดไว้จะไม่ดรอปให้เก็บ", &"DimLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var back := UIUtil.button("กลับ", &"PrimaryButton", Vector2(200, 64))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_rebuild)
	box.add_child(back)


## A grade chip in its rarity colour that switches between [param on_text] and [param off_text].
func _grade_toggle(rarity: int, on: bool, on_text: String, off_text: String) -> Button:
	var chip := Button.new()
	chip.toggle_mode = true
	chip.custom_minimum_size = Vector2(150, 74)
	chip.add_theme_font_size_override("font_size", 18)
	var color: Color = ItemData.RARITY_COLORS[rarity]
	var paint := func(state: bool):
		chip.text = "%s\n%s" % [ItemData.RARITY_NAMES[rarity], ("✔ " + on_text) if state else ("✖ " + off_text)]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.85) if state else Color(0.12, 0.14, 0.22, 0.9)
		style.set_corner_radius_all(12)
		style.set_border_width_all(3)
		style.border_color = color
		for key in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			chip.add_theme_stylebox_override(key, style)
		var text_color := Color("1a1a24") if state else color
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			chip.add_theme_color_override(key, text_color)
	chip.button_pressed = on
	paint.call(on)
	chip.toggled.connect(func(state: bool): paint.call(state))
	return chip


## Lv.100 wings + a chaos jewel + a feather: a try at the class's 100★ wings.
func _build_wing_craft(item: Dictionary, spot: Control) -> void:
	var enough := true
	for id in StarWingData.CRAFT_COST:
		enough = enough and Game.jewel_count(id) >= int(StarWingData.CRAFT_COST[id])
	var in_bag := _selected_slot == ""
	var need := UIUtil.label("ตีปีก 100 ดาว: ใช้เพชรชาออส 1 เม็ด + ขนนก 1 ขน · มีเพชรชาออส %d ขนนก %d%s" % [Game.jewel_count("chaos"), Game.jewel_count("feather"), "" if in_bag else " · ถอดปีกเก็บเข้ากระเป๋าก่อน"], &"SmallLabel")
	need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	need.add_theme_color_override("font_color", Color("fff1b8") if enough and in_bag else Color("ff8a8a"))
	spot.add_child(need)
	var btn := UIUtil.button("ตีปีก 100 ดาว  (%d%%)" % int(StarWingData.CRAFT_CHANCE * 100.0), &"PrimaryButton", Vector2(0, 58))
	btn.disabled = not (enough and in_bag)
	btn.pressed.connect(func():
		var result := Game.craft_star_wings(item)
		match result:
			"ok":
				Game.say("ตีปีกสำเร็จ! ได้ %s" % ItemData.name_of(item), &"success")
				AudioManager.play_sfx(&"level_up")
				Game.screen_flash.emit(Color("ffd23f"), 0.3)
			"fail":
				Game.say("ตีปีกพลาด... (เพชรชาออสกับขนนกหายไป ปีกเลเวล 100 ยังอยู่)", &"warning")
			_:
				Game.say(result, &"warning")
		_selected_index = Game.profile.inv.find(item)
		_rebuild())
	spot.add_child(btn)


func _build_forge_buttons(item: Dictionary) -> void:
	var plus := int(item.get("plus", 0))
	# The forge sits with the actions above the scrolling text: tapping it again and
	# again never needs scrolling back down after the screen redraws.
	var spot: Control = _actions if _actions != null and is_instance_valid(_actions) else _detail
	if StarWingData.can_craft(item):
		_build_wing_craft(item, spot)
	if not EnhanceFx.can_enhance(item):
		_detail.add_child(UIUtil.label("แหวนและสร้อยเป็นของวิเศษคงที่ ตีบวกไม่ได้ (ฝังอัญมณีได้)", &"DimLabel"))
	elif plus < ItemData.MAX_PLUS:
		var cost := ItemData.enhance_cost(item)
		var enough := true
		for id in cost:
			enough = enough and Game.jewel_count(id) >= int(cost[id])
		var need := UIUtil.label("ใช้ %s · มีเพชรม่วง %d ชมพู %d" % [ItemData.jewel_cost_text(cost), Game.jewel_count("purple"), Game.jewel_count("pink")], &"SmallLabel")
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.add_theme_color_override("font_color", Color("e8dcff") if enough else Color("ff8a8a"))
		spot.add_child(need)
		var btn := UIUtil.button("ตีบวก +%d  (%d%%)" % [plus + 1, int(ItemData.enhance_chance(plus) * 100.0)], &"PrimaryButton", Vector2(0, 58))
		btn.disabled = not enough
		btn.pressed.connect(func():
			var result := Game.enhance_item(item)
			match result:
				"ok":
					var new_plus := int(item.get("plus", 0))
					var g := EnhanceFx.grade(new_plus)
					var mood: String = ["", "", "เรืองแสงแล้ว!", "ลุกโชนแล้ว!", "ขีดสุด! เปลวเพลิงโอบอาวุธ!"][g] if g >= 2 else ""
					Game.say("ตีบวกสำเร็จ! %s %s" % [ItemData.name_of(item), mood], &"success")
					AudioManager.play_sfx(&"level_up")
					if g >= 2:
						Game.screen_flash.emit(EnhanceFx.color_of(new_plus), 0.12 + 0.07 * float(g))
				"fail":
					Game.say("ตีบวกพลาด... (เพชรหายไป ไอเทมยังอยู่ที่ +%d)" % int(item.get("plus", 0)), &"warning")
				_:
					Game.say(result, &"warning")
			# Spent jewels can empty a stack ahead of the piece in the bag: keep the piece selected.
			if _selected_slot == "":
				_selected_index = Game.profile.inv.find(item)
			_rebuild())
		spot.add_child(btn)
	else:
		_detail.add_child(UIUtil.label("ตีบวกสูงสุด +%d แล้ว" % ItemData.MAX_PLUS, &"DimLabel"))
	var socketed: Array = item.get("gems", [])
	for k in socketed.size():
		var socket_index: int = k
		var worn := ItemData.gem_info({"id": socketed[k]})
		var take := UIUtil.button("ถอด %s ออก" % worn.name, &"", Vector2(0, 50))
		take.add_theme_color_override("font_color", worn.color)
		take.pressed.connect(func():
			var result := Game.unsocket_gem(item, socket_index)
			if result == "ok":
				Game.say("ถอด%sแล้ว (เก็บเข้ากระเป๋า)" % worn.name, &"success")
				AudioManager.play_sfx(&"pickup")
			else:
				Game.say(result, &"warning")
			_rebuild())
		_detail.add_child(take)
	if EnhanceFx.can_enhance(item) and int(item.get("sockets", 0)) < ItemData.max_sockets(item):
		var drill := UIUtil.button("เจาะช่องอัญมณีเพิ่ม (สว่านเจาะ 1 · มี %d)" % Game.jewel_count("drill"), &"", Vector2(0, 52))
		drill.disabled = Game.jewel_count("drill") < 1
		drill.pressed.connect(func():
			var result := Game.drill_socket(item)
			if result == "ok":
				Game.say("เจาะช่องอัญมณีสำเร็จ! (%d ช่อง)" % int(item.sockets), &"success")
				AudioManager.play_sfx(&"level_up")
			else:
				Game.say(result, &"warning")
			_rebuild())
		_detail.add_child(drill)
	var free := int(item.get("sockets", 0)) - (item.get("gems", []) as Array).size()
	if free > 0:
		var seen := {}
		for i in Game.profile.inv.size():
			var gem: Dictionary = Game.profile.inv[i]
			if gem.get("kind", "") == "gem" and not seen.has(gem.id):
				seen[gem.id] = true
				var info := ItemData.gem_info(gem)
				var put := UIUtil.button("ใส่ %s ×%d" % [info.name, int(gem.count)], &"", Vector2(0, 50))
				put.add_theme_color_override("font_color", info.color)
				put.pressed.connect(func():
					if Game.socket_gem(item, i):
						Game.say("ใส่อัญมณีแล้ว", &"success")
					_rebuild())
				_detail.add_child(put)


func _use_potion(index: int) -> void:
	var item: Dictionary = Game.profile.inv[index]
	var def: Dictionary = ItemData.POTIONS[item.id]
	if def.has("town"):
		if Game.in_duel():
			Game.say("หนีจากการดวลไม่ได้!", &"warning")
			return
		close_menu()
		var main := get_tree().current_scene
		if main and main.has_method("use_town_scroll"):
			Game.remove_item_at(index)
			main.use_town_scroll()
		return
	Game.use_potion_at(index)
	AudioManager.play_sfx(&"item_use")
	_selected_index = -1
	_rebuild()


# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------

func _build_skills() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("แถบสกิล: เลือกใส่ได้ %d ช่อง   •   แต้มสกิล %d (ไปอัปที่ปรมาจารย์สกิลในหมู่บ้าน)" % [ClassData.SLOTS, int(Game.profile.skill_points)], &"SubHeaderLabel"))
	var bar_row := UIUtil.hbox(8)
	box.add_child(bar_row)
	var bar: Array = Game.loadout_skills()
	for i in bar.size():
		var slot_panel := UIUtil.panel(&"CardPanel")
		slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_content := UIUtil.vbox(4)
		slot_panel.add_child(slot_content)
		if not bar[i].is_empty():
			var portrait := SkillIcons.portrait(bar[i], 44.0)
			portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot_content.add_child(portrait)
		var slot_label := UIUtil.label("%d. %s" % [i + 1, bar[i].name if not bar[i].is_empty() else "— ว่าง —"], &"BoldLabel")
		slot_label.clip_text = true
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_content.add_child(slot_label)
		bar_row.add_child(slot_panel)
	var pool: Array = Game.skill_pool()
	for skill in pool:
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		line.add_child(SkillIcons.portrait(skill))
		var info := UIUtil.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		var unlocked := Game.skill_unlocked(skill)
		var rank := Game.effective_rank(skill)
		var title_row := UIUtil.hbox(12)
		info.add_child(title_row)
		var title_label := UIUtil.label(String(skill.name), &"BoldLabel")
		if not unlocked:
			title_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		title_row.add_child(title_label)
		if unlocked:
			title_row.add_child(StarRow.new(rank, Game.MAX_SKILL_RANK, 18.0))
		else:
			title_row.add_child(UIUtil.label(Game.skill_lock_reason(skill), &"SmallLabel"))
		var desc := UIUtil.label("%s  •  MP %d  •  คูลดาวน์ %.1f วิ" % [skill.desc, SkillRank.mp(skill, maxi(rank, 1)), SkillRank.cooldown(skill, maxi(rank, 1))], &"SmallLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		var upcoming := SkillRank.next_changes(SkillRank.table(skill), rank)
		if unlocked and not upcoming.is_empty():
			var next := UIUtil.label("อัปเป็นดาว %d ที่ครูฝึกสกิล: %s" % [rank + 1, ",  ".join(upcoming)], &"SmallLabel")
			next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			next.add_theme_color_override("font_color", UIPalette.SUCCESS)
			info.add_child(next)
		var equipped := Game.loadout().find(skill.id)
		for slot in ClassData.SLOTS:
			var b := UIUtil.button(str(slot + 1), &"PrimaryButton" if equipped == slot else &"", Vector2(48, 52))
			b.disabled = not unlocked or equipped == slot
			b.pressed.connect(func():
				if Game.equip_skill(skill.id, slot):
					AudioManager.play_ui(&"ui_select"))
			line.add_child(b)
	var passives: Array = Game.passive_pool()
	if not passives.is_empty():
		box.add_child(UIUtil.label("สกิลติดตัว (ทำงานเองตลอด)", &"SubHeaderLabel"))
	for skill in passives:
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var info := UIUtil.vbox(2)
		panel.add_child(info)
		var unlocked := Game.skill_unlocked(skill)
		var rank := Game.effective_rank(skill)
		var title_row := UIUtil.hbox(12)
		info.add_child(title_row)
		var title_label := UIUtil.label(String(skill.name), &"BoldLabel")
		if not unlocked:
			title_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		title_row.add_child(title_label)
		if unlocked:
			title_row.add_child(StarRow.new(rank, Game.MAX_SKILL_RANK, 18.0))
		else:
			title_row.add_child(UIUtil.label(Game.skill_lock_reason(skill), &"SmallLabel"))
		info.add_child(UIUtil.label(String(skill.desc), &"SmallLabel"))


# ---------------------------------------------------------------------------
# Quests
# ---------------------------------------------------------------------------

func _build_quests() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("เควสต์รายวัน (รับรางวัลที่กระดานในหมู่บ้าน)", &"SubHeaderLabel"))
	var reward := GoalsData.reward_for(int(Game.profile.level))
	var streak := Game.daily_streak()
	box.add_child(UIUtil.label("ติดต่อกัน %d วัน • โบนัสรางวัล +%d%% • ทำครบ 3 งานรับหีบรางวัล" % [streak, int(minf(maxf(float(streak) - 1.0, 0.0), 6.0) * 10.0)], &"DimLabel"))
	for entry in Game.daily().quests:
		var template := Game.daily_template(entry.id)
		var target := Game.daily_target(entry)
		var done: bool = int(entry.progress) >= target
		var dpanel := UIUtil.panel(&"CardPanel")
		box.add_child(dpanel)
		var dcol := UIUtil.vbox(2)
		dpanel.add_child(dcol)
		var state := "รับรางวัลแล้ว" if entry.claimed else ("เสร็จแล้ว — ไปรับที่กระดาน" if done else "%d / %d" % [int(entry.progress), target])
		var dtitle := UIUtil.label("%s — %s" % [template.name, state], &"BoldLabel")
		if entry.claimed:
			dtitle.add_theme_color_override("font_color", UIPalette.SUCCESS)
		dcol.add_child(dtitle)
		dcol.add_child(UIUtil.label(String(template.desc) % target, &"SmallLabel"))
		dcol.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d" % [int(reward.exp), int(reward.gold)], &"DimLabel"))
	box.add_child(UIUtil.label("เควสต์เนื้อเรื่อง (รับจากผู้ใหญ่บ้านในหมู่บ้าน)", &"SubHeaderLabel"))
	for id in QuestData.ORDER:
		var quest := QuestData.get_quest(id)
		var status := Game.quest_status(id)
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var col := UIUtil.vbox(2)
		panel.add_child(col)
		var state_text: String = {"new": "ยังไม่ได้รับ", "active": "กำลังทำ", "ready": "เสร็จแล้ว — กลับไปรายงาน", "done": "สำเร็จแล้ว เสร็จแล้ว"}[status]
		var gate := "ดาว %d+" % int(quest.star) if int(quest.get("star", 0)) > 0 else "Lv.%d+" % int(quest.level)
		var title := UIUtil.label("%s  (%s)  — %s" % [quest.name, gate, state_text], &"BoldLabel")
		if status == "done":
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		var detail := UIUtil.label(quest.desc, &"SmallLabel")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(detail)
		if status == "active" or status == "ready":
			col.add_child(UIUtil.label("ความคืบหน้า: %d / %d  (%s)" % [int(Game.quest_state(id).get("progress", 0)), int(quest.count), MonsterData.get_monster(StringName(quest.target)).name], &"DimLabel"))
		col.add_child(UIUtil.label("รางวัล: EXP %d • เหรียญ %d" % [int(quest.exp), int(quest.gold)], &"DimLabel"))


# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------

func _build_achievements() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var done_count := 0
	for ach in GoalsData.ACHIEVEMENTS:
		if Game.profile.get("ach", {}).has(ach.id):
			done_count += 1
	box.add_child(UIUtil.label("ความสำเร็จ  %d / %d" % [done_count, GoalsData.ACHIEVEMENTS.size()], &"HeaderLabel"))
	for ach in GoalsData.ACHIEVEMENTS:
		var done: bool = Game.profile.get("ach", {}).has(ach.id)
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var col := UIUtil.vbox(2)
		panel.add_child(col)
		var value := mini(Game.achievement_value(ach.check), int(ach.goal))
		var title := UIUtil.label("%s%s" % ["(สำเร็จ) " if done else "", ach.name], &"BoldLabel")
		if done:
			title.add_theme_color_override("font_color", UIPalette.SUCCESS)
		col.add_child(title)
		col.add_child(UIUtil.label("%s  (%d / %d)" % [ach.desc, value, int(ach.goal)], &"SmallLabel"))
		var parts: PackedStringArray = []
		if ach.reward.has("gold"):
			parts.append("เหรียญ %d" % int(ach.reward.gold))
		if ach.reward.has("sp"):
			parts.append("แต้มสกิล %d" % int(ach.reward.sp))
		if ach.reward.has("gem"):
			parts.append("อัญมณี")
		col.add_child(UIUtil.label("รางวัล: " + " • ".join(parts), &"DimLabel"))


# ---------------------------------------------------------------------------
# Titles (Achievements): the title shown above the hero's head
# ---------------------------------------------------------------------------

func _build_titles() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var worn := Achievements.title_of(Game.profile)
	box.add_child(UIUtil.label("ตำแหน่ง  %d / %d" % [Achievements.earned(Game.profile).size(), Achievements.TABLE.size()], &"HeaderLabel"))
	box.add_child(UIUtil.label("ตำแหน่งที่ใช้: %s" % (worn if worn != "" else "ไม่มี"), &"SubHeaderLabel"))
	for k in Achievements.TABLE.size():
		var row: Dictionary = Achievements.TABLE[k]
		var done := Achievements.is_earned(row.id, Game.profile)
		var has_title := String(row.title) != ""
		var panel := UIUtil.panel(&"CardPanel")
		box.add_child(panel)
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var col := UIUtil.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var title := UIUtil.label("%s%s" % ["(สำเร็จ) " if done else "", row.name], &"BoldLabel")
		title.add_theme_color_override("font_color", UIPalette.SUCCESS if done else UIPalette.TEXT_MUTED)
		col.add_child(title)
		var detail := UIUtil.label("%s  (%s)" % [row.desc, Achievements.progress(row.id, Game.profile)], &"SmallLabel")
		if not done:
			detail.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		col.add_child(detail)
		if has_title:
			col.add_child(UIUtil.label("ตำแหน่ง: %s" % row.title, &"DimLabel"))
		if done and has_title:
			var wearing := Achievements.title_index(Game.profile) == k
			var b := UIUtil.button("ถอดตำแหน่ง" if wearing else "ใช้ตำแหน่ง", &"" if wearing else &"PrimaryButton", Vector2(150, 56))
			b.pressed.connect(func():
				Game.set_title(-1 if wearing else k)
				_queue_rebuild())
			line.add_child(b)


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

func _build_settings() -> void:
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(scroll)
	_page_scroll = scroll
	var box := UIUtil.vbox(12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UIUtil.label("ตั้งค่า", &"HeaderLabel"))
	for entry in [["เพลง", "Music"], ["เสียงเอฟเฟกต์", "SFX"]]:
		var line := UIUtil.hbox(14)
		box.add_child(line)
		var label := UIUtil.label(entry[0], &"BoldLabel")
		label.custom_minimum_size = Vector2(220, 0)
		line.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(420, 40)
		var bus := AudioServer.get_bus_index(entry[1])
		slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus)) if bus >= 0 else 1.0
		slider.value_changed.connect(func(v: float):
			if bus >= 0:
				AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.001))))
		line.add_child(slider)
	# Camera speed
	var cam_line := UIUtil.hbox(14)
	box.add_child(cam_line)
	var cam_label := UIUtil.label("ความเร็วหมุนกล้อง", &"BoldLabel")
	cam_label.custom_minimum_size = Vector2(220, 0)
	cam_line.add_child(cam_label)
	var cam_slider := HSlider.new()
	cam_slider.min_value = 0.4
	cam_slider.max_value = 2.5
	cam_slider.step = 0.1
	cam_slider.value = GameSettings.camera_speed
	cam_slider.custom_minimum_size = Vector2(420, 40)
	cam_slider.value_changed.connect(func(v: float):
		GameSettings.camera_speed = v
		GameSettings.save_settings())
	cam_line.add_child(cam_slider)
	# Graphics quality
	var q_line := UIUtil.hbox(10)
	box.add_child(q_line)
	var q_label := UIUtil.label("คุณภาพกราฟิก", &"BoldLabel")
	q_label.custom_minimum_size = Vector2(220, 0)
	q_line.add_child(q_label)
	for i in 3:
		var qb := UIUtil.button(String(GameSettings.QUALITY_NAMES[i]), &"PrimaryButton" if GameSettings.quality == i else &"", Vector2(180, 56))
		qb.pressed.connect(func():
			GameSettings.quality = i
			GameSettings.save_settings()
			GameSettings.apply_live(get_tree())
			MemoryGuard.reset_scale_3d(get_tree())
			Game.say("ตั้งคุณภาพ: %s (ต้นไม้และหญ้าจะเปลี่ยนเมื่อเข้าแมพใหม่)" % GameSettings.quality_name(), &"info")
			_rebuild())
		q_line.add_child(qb)
	if GameSettings.quality >= 2:
		# High comes in two modes: sharp (the 3D scale stays at 1.0) or smooth (on a phone
		# the 3D scale follows the frame rate like medium does; the HUD stays crisp).
		var smooth := CheckButton.new()
		smooth.text = "สูง (ลื่น): ลดความละเอียด 3D อัตโนมัติเมื่อเฟรมตก (ปิด = สูง (คมชัด))"
		smooth.button_pressed = GameSettings.high_smooth
		smooth.toggled.connect(func(on: bool):
			GameSettings.high_smooth = on
			GameSettings.save_settings()
			MemoryGuard.reset_scale_3d(get_tree())
			Game.say("คุณภาพ: %s" % GameSettings.quality_name(), &"info"))
		box.add_child(smooth)
	var others := CheckButton.new()
	others.text = "แสดงผู้เล่นคนอื่น (AI) ในแมพ"
	others.button_pressed = GameSettings.show_world_players
	others.toggled.connect(func(on: bool):
		GameSettings.show_world_players = on
		GameSettings.save_settings()
		Game.say("ผู้เล่นคนอื่นในแมพ: %s (มีผลเมื่อเข้าแมพใหม่)" % ("แสดง" if on else "ซ่อน"), &"info"))
	box.add_child(others)
	var safe := CheckButton.new()
	safe.text = "โหมดภาพปลอดภัย (ไม่มีผู้เล่นคนอื่น/ร้านค้า/แสงโคม ใช้เมื่อจอเป็นสีเดียว)"
	safe.button_pressed = GameSettings.safe_picture
	safe.toggled.connect(func(on: bool):
		GameSettings.safe_picture = on
		GameSettings.save_settings()
		Game.say("โหมดภาพปลอดภัย: %s (มีผลเมื่อเข้าแมพใหม่)" % ("เปิด" if on else "ปิด"), &"info"))
	box.add_child(safe)
	var hitstop := CheckButton.new()
	hitstop.text = "ชะลอภาพเมื่อโจมตีหนัก (ปิดเพื่อเล่นต่อเนื่อง)"
	hitstop.button_pressed = GameSettings.combat_hitstop
	hitstop.toggled.connect(func(on: bool):
		GameSettings.combat_hitstop = on
		GameSettings.save_settings())
	box.add_child(hitstop)
	var save := UIUtil.button("บันทึกเกม", &"PrimaryButton", Vector2(320, 66))
	save.pressed.connect(func():
		if Game.save():
			Game.say("บันทึกเกมแล้ว", &"success")
		else:
			Game.say("บันทึกไม่สำเร็จ กรุณาสำรองรหัสเซฟ", &"warning"))
	box.add_child(save)
	if OS.has_feature("web"):
		var account := UIUtil.button("บัญชี / เซฟออนไลน์", &"PrimaryButton", Vector2(320, 66))
		account.pressed.connect(Game.open_cloud_account)
		box.add_child(account)
		var report := UIUtil.button("รายงานการหลุด", &"", Vector2(320, 66))
		report.pressed.connect(func():
			JavaScriptBridge.eval("if (window.toonSession) window.toonSession.showReport();", true))
		box.add_child(report)
	# Save backup: the save lives in this browser only, so offer copy / paste.
	var backup := UIUtil.button("สำรอง / นำเข้าเซฟ", &"", Vector2(320, 66))
	backup.pressed.connect(_open_backup)
	box.add_child(backup)
	if Game.ending_unlocked():
		var ending := UIUtil.button("ดูตอนจบอีกครั้ง", &"", Vector2(320, 66))
		ending.pressed.connect(func():
			close_menu()
			Game.ending_requested.emit())
		box.add_child(ending)
	var title := UIUtil.button("กลับหน้าหลัก", &"", Vector2(320, 66))
	title.pressed.connect(func():
		Game.save()
		close_menu()
		title_requested.emit())
	box.add_child(title)


## A text box holding the save as a code: copy it somewhere safe, or paste a code and import.
func _open_backup() -> void:
	UIUtil.clear(_content)
	var box := UIUtil.vbox(10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(box)
	box.add_child(UIUtil.label("สำรองเซฟ", &"HeaderLabel"))
	box.add_child(UIUtil.label("กดค้างที่กล่องข้อความเพื่อคัดลอก เก็บรหัสนี้ไว้ในโน้ต แล้ววางกลับมาเพื่อนำเข้าบนเครื่องไหนก็ได้", &"SmallLabel"))
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(0, 180)
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text = Game.export_code()
	box.add_child(edit)
	var destination_row := UIUtil.hbox(12)
	box.add_child(destination_row)
	destination_row.add_child(UIUtil.label("นำเข้าไปยังช่อง", &"BoldLabel"))
	var destination := OptionButton.new()
	destination.custom_minimum_size = Vector2(370, 56)
	var suggested := Game.free_slot()
	if suggested <= 0:
		suggested = Game.slot
	for save_slot in range(1, Game.SLOT_COUNT + 1):
		var info := Game.slot_info(save_slot)
		var title := "ช่อง %d · ว่าง" % save_slot if info.is_empty() else "ช่อง %d · %s Lv.%d" % [save_slot, info.name, info.level]
		destination.add_item(title, save_slot)
	destination.select(suggested - 1)
	destination_row.add_child(destination)
	var row := UIUtil.hbox(10)
	box.add_child(row)
	var copy := UIUtil.button("คัดลอกรหัส", &"PrimaryButton", Vector2(240, 60))
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(edit.text)
		Game.say("คัดลอกแล้ว", &"success"))
	row.add_child(copy)
	var imp := UIUtil.button("ตรวจสอบและนำเข้า", &"", Vector2(260, 60))
	imp.pressed.connect(func(): _confirm_backup(edit.text, destination.get_selected_id()))
	row.add_child(imp)
	var back := UIUtil.button("กลับ", &"", Vector2(160, 60))
	back.pressed.connect(_rebuild)
	row.add_child(back)


## Review validated identity and the exact destination before any file changes.
func _confirm_backup(code: String, target_slot: int) -> void:
	var info := Game.preview_import(code)
	if info.is_empty():
		Game.say("รหัสไม่ถูกต้องหรือข้อมูลเซฟเสียหาย", &"warning")
		return
	var existing := Game.slot_info(target_slot)
	var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
	var message := "%s · %s · Lv.%d\nพื้นที่: %s\nเวลาเล่น: %s\n\nปลายทาง: ช่อง %d" % [
		info.name, cls.name, int(info.level), ZoneData.get_zone(StringName(info.zone)).name,
		UIUtil.format_play_time(float(info.play_time)), target_slot]
	if not existing.is_empty():
		message += "\nจะแทนที่ %s (Lv.%d) ในช่องนี้" % [existing.name, int(existing.level)]
	else:
		message += " (ว่าง)"
	var approved: bool = await ModalDialog.confirm(self, "ตรวจสอบเซฟก่อนนำเข้า", message,
		"นำเข้าและเล่นเซฟนี้", "ยกเลิก", not existing.is_empty())
	if not approved:
		return
	if Game.import_code(code, target_slot):
		Game.say("นำเข้าเซฟช่อง %d สำเร็จ!" % target_slot, &"success")
		close_menu()
	else:
		Game.say("นำเข้าไม่สำเร็จ กรุณาตรวจรหัสและพื้นที่จัดเก็บ", &"warning")


## Rarity belongs to the frame; item artwork keeps its original readable colours.
func _style_item_button(button: Button, rarity: Color, selected: bool) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UIPalette.CARD.lerp(rarity, 0.10 if state == "normal" else 0.20)
		style.border_color = UIPalette.GOLD if selected else Color(rarity, 0.7)
		style.set_border_width_all(3 if selected else 2)
		style.set_corner_radius_all(13)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		button.add_theme_stylebox_override(state, style)
