class_name WarpScreen
extends CanvasLayer
## The warp crystal's destination list: the village and every field whose level
## requirement the hero meets. Picking one travels there.

signal warp_chosen(zone_id: StringName)

var is_open := false
var _root: Control
var _list: VBoxContainer
var _here: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 60
	panel.offset_top = 12
	panel.offset_right = -60
	panel.offset_bottom = -12
	frame.add_child(panel)
	var column := UIUtil.vbox(8)
	panel.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title_box := UIUtil.vbox(0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_box)
	title_box.add_child(UIUtil.label("เสาวาป — เลือกปลายทาง", &"HeaderLabel"))
	_here = UIUtil.label("", &"SmallLabel")
	title_box.add_child(_here)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(130, 56))
	close.pressed.connect(close_warp)
	head.add_child(close)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = UIUtil.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


## Every place the crystal can send the hero, in travel order.
static func destinations() -> Array[StringName]:
	var out: Array[StringName] = [&"town"]
	var id: StringName = &"meadow"
	while id != &"" and ZoneData.ZONES.has(id) and not out.has(id):
		out.append(id)
		id = StringName(ZoneData.get_zone(id).get("next", &""))
	return out


static func unlocked(zone_id: StringName, level: int) -> bool:
	var z := ZoneData.get_zone(zone_id)
	return not z.has("level") or level >= int(z.level[0])


func open_warp() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_warp() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _rebuild() -> void:
	var level := int(Game.profile.get("level", 1))
	var here := ZoneData.get_zone(Game.current_zone)
	_here.text = "ตอนนี้อยู่ที่ %s · เลเวลของเจ้า Lv.%d — ฟรีไม่เสียเหรียญ" % [here.name, level]
	UIUtil.clear(_list)
	for id in destinations():
		_list.add_child(_row(id, level))


func _row(id: StringName, level: int) -> Control:
	var z := ZoneData.get_zone(id)
	var is_here := id == Game.current_zone
	var open := unlocked(id, level)
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(12)
	panel.add_child(line)
	var icon := UIUtil.label("เมือง" if id == &"town" else "แมพ", &"SmallLabel")
	line.add_child(icon)
	var info := UIUtil.vbox(1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var name_label := UIUtil.label(String(z.name) + ("  (อยู่ที่นี่)" if is_here else ""), &"BoldLabel")
	name_label.clip_text = true
	if not open:
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	info.add_child(name_label)
	var detail := "ปลอดภัย · ร้านค้า · เซฟจุดฟื้นฟู" if id == &"town" else "มอนสเตอร์ Lv.%d–%d · บอสประจำแมพ" % [int(z.level[0]), int(z.level[1])]
	if not open:
		detail = "ล็อก · ต้องเลเวล %d ขึ้นไป" % int(z.level[0])
	info.add_child(UIUtil.label(detail, &"SmallLabel"))
	var go := UIUtil.button("วาป" if open and not is_here else ("อยู่ที่นี่" if is_here else "ล็อก"), &"PrimaryButton", Vector2(130, 52))
	go.disabled = is_here or not open
	go.pressed.connect(func():
		close_warp()
		warp_chosen.emit(id))
	line.add_child(go)
	return panel
