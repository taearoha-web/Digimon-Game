class_name MainMenu
extends CanvasLayer
## One live hero turntable keeps the title light enough for phone browsers.

signal new_game_pressed(slot: int)
signal continue_pressed(slot: int)

var _selected := 0
var _row: GridContainer
var _play: Button
var _delete: Button
var _hint: Label
var _root: Control
var _preview: HeroPreview
var _hero_name: Label
var _hero_class: Label
var _hero_zone: Label
var _body: BoxContainer
var _spotlight: PanelContainer


func _ready() -> void:
	layer = 50
	add_child(UIUtil.sky_background())
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var safe := SafeAreaContainer.new()
	safe.min_margin = 28
	_root.add_child(safe)
	var layout := UIUtil.vbox(12)
	safe.add_child(layout)
	var masthead := UIUtil.hbox(18)
	layout.add_child(masthead)
	var titles := UIUtil.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(titles)
	var title := UIUtil.label("TOON TALE", &"TitleLabel")
	title.add_theme_font_size_override("font_size", 54)
	titles.add_child(title)
	titles.add_child(UIUtil.label("ตำนานนักล่าแห่งมิสต์วูด", &"SubHeaderLabel"))
	var chapter := UIUtil.chip("การผจญภัยครั้งใหม่รออยู่", UIPalette.GOLD, 17)
	chapter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	masthead.add_child(chapter)
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 24)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_body)

	_spotlight = UIUtil.panel(&"GlassPanel")
	_spotlight.custom_minimum_size = Vector2(330, 0)
	_spotlight.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spotlight.size_flags_stretch_ratio = 0.8
	_body.add_child(_spotlight)
	var hero_col := UIUtil.vbox(2)
	_spotlight.add_child(hero_col)
	hero_col.add_child(UIUtil.label("ฮีโร่ของคุณ", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_preview = HeroPreview.new(Vector2i(260, 240))
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_col.add_child(_preview)
	_hero_name = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	hero_col.add_child(_hero_name)
	_hero_class = UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	hero_col.add_child(_hero_class)
	_hero_zone = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	hero_col.add_child(_hero_zone)
	hero_col.add_child(UIUtil.label("ลากเพื่อหมุนดูตัวละคร", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var saves := UIUtil.vbox(12)
	saves.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saves.size_flags_stretch_ratio = 1.35
	_body.add_child(saves)
	saves.add_child(UIUtil.label("เลือกการผจญภัย", &"HeaderLabel"))
	_row = GridContainer.new()
	_row.columns = 2
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("h_separation", 12)
	_row.add_theme_constant_override("v_separation", 12)
	saves.add_child(_row)
	_hint = UIUtil.label("", &"SmallLabel")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	saves.add_child(_hint)
	var actions := UIUtil.hbox(12)
	saves.add_child(actions)
	_play = UIUtil.button("เล่น", &"PrimaryButton", Vector2(220, 68))
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.pressed.connect(_on_play)
	actions.add_child(_play)
	_delete = UIUtil.button("ลบเซฟ", &"GhostButton", Vector2(128, 68))
	_delete.pressed.connect(_on_delete)
	actions.add_child(_delete)
	var foot := UIUtil.label("TOON TALE  v%s  ·  ผจญภัยในโลกใบเล็ก เติบโตเป็นฮีโร่คนโปรด" % ProjectSettings.get_setting("application/config/version", ""), &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	layout.add_child(foot)
	_selected = Game.last_slot() if Game.has_save(Game.last_slot()) else maxi(1, Game.free_slot())
	_root.resized.connect(_layout)
	_layout()
	_rebuild()
	AudioManager.play_music(&"title")


func _layout() -> void:
	if _body == null:
		return
	var portrait := get_viewport().get_visible_rect().size.x < 950.0
	_body.vertical = portrait
	_spotlight.custom_minimum_size = Vector2(0, 310) if portrait else Vector2(330, 0)
	_preview.custom_minimum_size = Vector2(230, 190 if portrait else 240)


func _rebuild() -> void:
	UIUtil.clear(_row)
	for i in range(1, Game.SLOT_COUNT + 1):
		_row.add_child(_card(i))
	var info := Game.slot_info(_selected)
	var used := not info.is_empty()
	_play.text = "ออกผจญภัยต่อ" if used else "สร้างฮีโร่ใหม่"
	_delete.visible = used
	_hint.text = "ช่อง %d · บันทึกความคืบหน้าอัตโนมัติ" % _selected if used else "ช่อง %d ว่างอยู่ · แต่งตัวละครแล้วเริ่มเรื่องราวของคุณ" % _selected
	if used:
		var cosmetic := Game.slot_profile_preview(_selected)
		var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
		_preview.show_hero(StringName(info["class"]), cosmetic.get("equip", {}), "", cosmetic.get("look", {}))
		_hero_name.text = String(info.name)
		_hero_class.text = "%s · Lv.%d" % [cls.name, int(info.level)]
		_hero_class.add_theme_color_override("font_color", cls.color.lightened(0.35))
		_hero_zone.text = String(ZoneData.get_zone(StringName(info.zone)).name)
	else:
		_preview.show_hero(ClassData.START, {}, "", FaceKit.default_look())
		_hero_name.text = "เรื่องราวบทใหม่"
		_hero_class.text = "เริ่มต้นด้วยนักเดินทางตัวน้อย"
		_hero_class.add_theme_color_override("font_color", UIPalette.GOLD)
		_hero_zone.text = "เลือกอาชีพเมื่อเลเวล 10"


func _card(i: int) -> Control:
	var info := Game.slot_info(i)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(250, 148)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.button_pressed = i == _selected
	card.pressed.connect(func():
		AudioManager.play_ui(&"ui_click")
		_selected = i
		_rebuild())
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = UIPalette.CARD_HOVER if state in ["hover", "hover_pressed"] else UIPalette.PANEL
		style.border_color = UIPalette.GOLD if i == _selected else Color(UIPalette.TEXT_DIM, 0.26)
		style.set_border_width_all(2 if i == _selected else 1)
		style.set_corner_radius_all(18)
		card.add_theme_stylebox_override(state, style)
	var col := UIUtil.vbox(3)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 18
	col.offset_right = -18
	col.offset_top = 10
	col.offset_bottom = -10
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.add_child(_line("ช่อง %02d%s" % [i, "  ·  เลือกแล้ว" if i == _selected else ""], 16, UIPalette.GOLD))
	if info.is_empty():
		col.add_child(_line("+ สร้างตัวละคร", 24, UIPalette.TEXT))
		col.add_child(_line("เริ่มการผจญภัยครั้งใหม่", 16, UIPalette.TEXT_DIM))
		return card
	var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
	col.add_child(_line(String(info.name), 25, UIPalette.TEXT))
	col.add_child(_line("%s · Lv.%d" % [cls.name, int(info.level)], 18, cls.color.lightened(0.4)))
	col.add_child(_line("เวลาเล่น " + UIUtil.format_play_time(float(info.play_time)), 15, UIPalette.TEXT_DIM))
	return card


func _line(text: String, font_size: int, color: Color) -> Label:
	var label := UIUtil.label(text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _on_play() -> void:
	if Game.slot_info(_selected).is_empty():
		new_game_pressed.emit(_selected)
	else:
		continue_pressed.emit(_selected)


func _on_delete() -> void:
	var info := Game.slot_info(_selected)
	if info.is_empty():
		return
	var ok: bool = await ModalDialog.confirm(self, "ลบเซฟช่อง %d?" % _selected,
			"ลบ %s (Lv.%d) ถาวร กู้คืนไม่ได้" % [info.name, int(info.level)], "ลบเลย", "ยกเลิก", true)
	if ok:
		Game.delete_save(_selected)
		_rebuild()
