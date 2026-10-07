class_name MainMenu
extends CanvasLayer
## Title screen: four save slots. An empty slot starts a new hero, a used one
## continues it (or deletes it).

signal new_game_pressed(slot: int)
signal continue_pressed(slot: int)

var _selected := 0
var _row: HBoxContainer
var _play: Button
var _delete: Button
var _hint: Label
var _root: Control


func _ready() -> void:
	layer = 50
	add_child(UIUtil.sky_background())
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var title := UIUtil.label("TOON TALE", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 78)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = 22
	_root.add_child(title)
	var sub := UIUtil.label("ตำนานนักล่าแห่งมิสต์วูด · เลือกช่องเซฟ (เล่นได้ 4 ตัวละคร)", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -500
	sub.offset_right = 500
	sub.offset_top = 124
	sub.add_theme_font_size_override("font_size", 24)
	_root.add_child(sub)
	_row = UIUtil.hbox(14)
	_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_row.offset_left = -560
	_row.offset_right = 560
	_row.offset_top = -180
	_row.offset_bottom = 150
	_root.add_child(_row)
	var actions := UIUtil.hbox(16)
	actions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	actions.offset_left = -300
	actions.offset_right = 300
	actions.offset_top = -170
	actions.offset_bottom = -94
	_root.add_child(actions)
	_play = UIUtil.button("เล่น", &"PrimaryButton", Vector2(300, 76))
	_play.pressed.connect(_on_play)
	actions.add_child(_play)
	_delete = UIUtil.button("ลบเซฟ", &"", Vector2(260, 76))
	_delete.pressed.connect(_on_delete)
	actions.add_child(_delete)
	_hint = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -500
	_hint.offset_right = 500
	_hint.offset_top = -88
	_hint.offset_bottom = -58
	_root.add_child(_hint)
	var foot := UIUtil.label("v0.2 · โมเดลตัวละคร KayKit และมอนสเตอร์ Quaternius (CC0)", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.offset_left = -500
	foot.offset_right = 500
	foot.offset_top = -50
	_root.add_child(foot)
	_selected = Game.last_slot() if Game.has_save(Game.last_slot()) else maxi(1, Game.free_slot())
	_rebuild()
	AudioManager.play_music(&"title")


func _rebuild() -> void:
	UIUtil.clear(_row)
	for i in range(1, Game.SLOT_COUNT + 1):
		_row.add_child(_card(i))
	var info := Game.slot_info(_selected)
	var used := not info.is_empty()
	_play.text = "เล่นต่อ" if used else "เริ่มเกมใหม่"
	_delete.visible = used
	_hint.text = "ช่อง %d · เซฟอัตโนมัติ" % _selected if used else "ช่อง %d ว่างอยู่ — เริ่มเกมใหม่เพื่อสร้างตัวละคร" % _selected


func _card(i: int) -> Control:
	var info := Game.slot_info(i)
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(266, 310)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.toggle_mode = true
	card.button_pressed = i == _selected
	card.theme_type_variation = &"PrimaryButton" if i == _selected else &""
	card.pressed.connect(func():
		AudioManager.play_ui(&"ui_click")
		if _selected == i and not Game.slot_info(i).is_empty():
			_on_play()
			return
		_selected = i
		_rebuild())
	var col := UIUtil.vbox(6)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 12
	col.offset_bottom = -10
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(col)
	col.add_child(_line("ช่อง %d" % i, 22, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER))
	if info.is_empty():
		var plus := _line("＋", 84, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		plus.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col.add_child(plus)
		col.add_child(_line("ว่าง", 24, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
		return card
	var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
	var badge := _line(String(ClassData.get_class_data(StringName(info["class"])).get("badge", "?")), 64, cls.color, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(badge)
	col.add_child(_line(String(info.name), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_line("%s  Lv.%d" % [cls.name, int(info.level)], 21, Color("c8f0ff"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_line(String(ZoneData.get_zone(StringName(info.zone)).name), 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_line("เล่นมา " + UIUtil.format_play_time(float(info.play_time)), 16, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
	return card


func _line(text: String, size: int, color: Color, align: int) -> Label:
	var l := UIUtil.label(text, &"", align)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	return l


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
