class_name MainMenu
extends CanvasLayer
## The character select after logging in: a sky platform with ten numbered circles
## (TitleStage). The hero of save slot N stands on circle N; a tap picks a hero, and
## "สร้างตัวละคร" makes a new one, who lands on the first free circle in number order.
## With no heroes yet the platform stands empty, as painted.

signal new_game_pressed(slot: int)
signal continue_pressed(slot: int)

## Set by Main after a hero was created: that slot's hero lands in a column of light.
var arrival_slot := 0
var stage: TitleStage
var _selected := 0
## slot -> Game.slot_overview(slot), read once per build.
var _slots: Dictionary = {}
var _root: Control
var _tap: TouchCameraArea
var _plates: Dictionary = {}   # slot -> PanelContainer
var _plate_layer: Control
var _counter: Label
var _name: Label
var _detail: Label
var _hint: Label
var _play: Button
var _create: Button
var _delete: Button
var _panel: PanelContainer
var _building := false


func _ready() -> void:
	layer = 50
	stage = TitleStage.new()
	stage.name = "TitleStage"
	add_child(stage)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# Taps that miss every button land here and pick the hero under the finger.
	_tap = TouchCameraArea.new()
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.tapped.connect(_on_tap)
	_root.add_child(_tap)
	_plate_layer = Control.new()
	_plate_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_plate_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate_layer)
	var safe := SafeAreaContainer.new()
	safe.min_margin = 18
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_build_masthead(frame)
	_build_panel(frame)
	_selected = Game.last_slot()
	_root.resized.connect(_layout)
	AudioManager.play_music(&"title")
	# The painting and the bar are right from the first frame; the heroes follow.
	_read_slots()
	_refresh()
	_layout()
	# One frame later: a zone being left is freed by then (one camera, one environment).
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_layout()
	await _build_heroes()


func _build_masthead(frame: Control) -> void:
	var titles := UIUtil.vbox(0)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.position = Vector2.ZERO
	frame.add_child(titles)
	var title := UIUtil.label("TOON TALE", &"TitleLabel")
	title.add_theme_font_size_override("font_size", 34)
	_outline(title, 10)
	titles.add_child(title)
	var sub := UIUtil.label("เลือกฮีโร่ของคุณ  ·  v%s" % ProjectSettings.get_setting("application/config/version", ""), &"BoldLabel")
	_outline(sub, 6)
	titles.add_child(sub)
	_counter = UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_outline(_counter, 6)
	_counter.anchor_left = 1.0
	_counter.anchor_right = 1.0
	_counter.offset_left = -260
	_counter.offset_right = 0
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_counter)


func _build_panel(frame: Control) -> void:
	_panel = UIUtil.panel(&"GlassPanel")
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(_panel)
	var row := UIUtil.hbox(14)
	_panel.add_child(row)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	_name = UIUtil.label("", &"HeaderLabel")
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_name)
	_detail = UIUtil.label("", &"BoldLabel")
	_detail.clip_text = true
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_detail)
	_hint = UIUtil.label("", &"SmallLabel")
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(_hint)
	_delete = UIUtil.button("ลบ", &"GhostButton", Vector2(96, 64))
	_delete.pressed.connect(_on_delete)
	row.add_child(_delete)
	_create = UIUtil.button("+ สร้างตัวละคร", &"GhostButton", Vector2(200, 64))
	_create.name = "CreateButton"
	_create.pressed.connect(_on_create)
	row.add_child(_create)
	_play = UIUtil.button("เริ่มผจญภัย", &"PrimaryButton", Vector2(200, 64))
	_play.name = "PlayButton"
	_play.pressed.connect(_on_play)
	row.add_child(_play)


func _outline(label: Label, size: int) -> void:
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.24, 0.9))
	label.add_theme_constant_override("outline_size", size)


func _layout() -> void:
	if stage == null or stage.camera == null:
		return
	var canvas := get_viewport().get_visible_rect().size
	stage.layout(canvas)
	_panel.custom_minimum_size = Vector2(minf(canvas.x - 36.0, 1040.0), 0)
	_update_plates()


## Reads every slot once and puts its hero on its circle, one hero per frame so a
## phone never stalls on ten models at once.
func _read_slots() -> void:
	_slots.clear()
	for i in range(1, Game.SLOT_COUNT + 1):
		var overview := Game.slot_overview(i)
		if not overview.is_empty():
			_slots[i] = overview
	if _slots.has(arrival_slot):
		_selected = arrival_slot
	elif not _slots.has(_selected):
		_selected = int(_slots.keys().min()) if not _slots.is_empty() else 0


func _build_heroes() -> void:
	_building = true
	for i in range(1, Game.SLOT_COUNT + 1):
		if not _slots.has(i) or not is_inside_tree():
			continue
		stage.add_hero(i, _slots[i], i == arrival_slot)
		_make_plate(i)
		if i == _selected:
			stage.select(i)
			_style_plates()
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_building = false
	arrival_slot = 0
	_update_plates()


func _make_plate(slot: int) -> void:
	if _plates.has(slot):
		(_plates[slot] as Node).queue_free()
	var info: Dictionary = _slots[slot]
	var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
	# One compact line, never wider than its circle: ten plates in two rows stay apart
	# and clear of the circles behind them.
	var plate := PanelContainer.new()
	plate.name = "Plate%d" % slot
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.clip_contents = true
	var line := UIUtil.hbox(6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(line)
	# The circle's number leads, so the numbered spots still read with heroes on them.
	var number := UIUtil.label(str(slot), &"BoldLabel")
	number.add_theme_font_size_override("font_size", 15)
	number.add_theme_color_override("font_color", TitleStage.GOLD)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(number)
	var who := UIUtil.label(String(info.name), &"BoldLabel")
	who.add_theme_font_size_override("font_size", 15)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.name = "Name"
	line.add_child(who)
	var lv := UIUtil.label("Lv.%d%s" % [int(info.level), " ★%d" % int(info.stars) if int(info.get("stars", 0)) > 0 else ""], &"SmallLabel")
	lv.add_theme_font_size_override("font_size", 13)
	lv.add_theme_color_override("font_color", cls.color.lightened(0.45))
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(lv)
	_plate_layer.add_child(plate)
	_plates[slot] = plate
	_style_plates()


func _style_plates() -> void:
	for slot in _plates:
		var on := int(slot) == _selected
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.09, 0.22, 0.82 if on else 0.62)
		sb.border_color = TitleStage.GOLD if on else Color(0.75, 0.86, 1.0, 0.45)
		sb.set_border_width_all(2 if on else 1)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		(_plates[slot] as PanelContainer).add_theme_stylebox_override("panel", sb)


func _process(_delta: float) -> void:
	# Plates follow heads that grow in (arrival) and the layout; ten unprojections a frame.
	if not _plates.is_empty():
		_update_plates()


func _update_plates() -> void:
	for slot in _plates:
		var plate := _plates[slot] as Control
		if not is_instance_valid(plate):
			continue
		var head := stage.head_screen(int(slot))
		var size := _plate_size(plate, int(slot))
		plate.size = size
		plate.position = Vector2(head.x - size.x * 0.5, head.y - size.y - 4.0)


## The plate's natural width (whole name) capped at its circle's width.
func _plate_size(plate: Control, slot: int) -> Vector2:
	var natural := plate.get_combined_minimum_size()
	var who := plate.find_child("Name", true, false) as Label
	var full := natural.x
	if who:
		var font := who.get_theme_font(&"font")
		full += font.get_string_size(who.text, HORIZONTAL_ALIGNMENT_LEFT, -1, who.get_theme_font_size(&"font_size")).x
	return Vector2(minf(full, maxf(stage.spot_width(slot) * 0.98, 90.0)), natural.y)


func _refresh() -> void:
	var count := _slots.size()
	_counter.text = "ฮีโร่ %d/%d" % [count, Game.SLOT_COUNT]
	var free := Game.free_slot()
	_create.disabled = free == 0
	_create.text = "+ สร้างตัวละคร" if free > 0 else "ครบ %d ตัวแล้ว" % Game.SLOT_COUNT
	_create.theme_type_variation = &"PrimaryButton" if count == 0 else &"GhostButton"
	var info: Dictionary = _slots.get(_selected, {})
	var used := not info.is_empty()
	_play.visible = used
	_delete.visible = used
	if used:
		var cls := JobData.resolve(StringName(info["class"]), int(info.adv))
		_name.text = String(info.name)
		_detail.text = "จุด %d · %s · Lv.%d%s" % [_selected, cls.name, int(info.level), "  ★%d" % int(info.stars) if int(info.get("stars", 0)) > 0 else ""]
		_detail.add_theme_color_override("font_color", cls.color.lightened(0.35))
		_hint.text = "%s · เวลาเล่น %s" % [ZoneData.get_zone(StringName(info.zone)).name, UIUtil.format_play_time(float(info.play_time))]
	elif count == 0:
		_name.text = "ลานแห่งฮีโร่ยังว่างอยู่"
		_detail.text = "สร้างฮีโร่ตัวแรก แล้วเขาจะมายืนที่จุด %d" % maxi(free, 1)
		_detail.add_theme_color_override("font_color", TitleStage.GOLD)
		_hint.text = "ฮีโร่ตัวต่อไปยืนจุดถัดไปตามเลข สูงสุด %d ตัว" % Game.SLOT_COUNT
	else:
		_name.text = "แตะฮีโร่บนลานเพื่อเลือก"
		_detail.text = "ฮีโร่ตัวใหม่จะยืนที่จุด %d" % free if free > 0 else "ลานเต็มแล้ว ลบฮีโร่ที่ไม่ใช้เพื่อสร้างใหม่"
		_detail.add_theme_color_override("font_color", TitleStage.GOLD)
		_hint.text = ""


func _select(slot: int) -> void:
	if slot == _selected or not _slots.has(slot):
		return
	AudioManager.play_ui(&"ui_click")
	_selected = slot
	stage.select(slot)
	_style_plates()
	_refresh()


func _on_tap(at: Vector2) -> void:
	var slot := stage.slot_at(at)
	if slot > 0:
		_select(slot)


func _on_play() -> void:
	if _slots.has(_selected):
		continue_pressed.emit(_selected)


## The next hero takes the first free circle in number order.
func _on_create() -> void:
	var free := Game.free_slot()
	if free > 0:
		AudioManager.play_ui(&"ui_click")
		new_game_pressed.emit(free)


func _on_delete() -> void:
	var info: Dictionary = _slots.get(_selected, {})
	if info.is_empty():
		return
	var slot := _selected
	var ok: bool = await ModalDialog.confirm(self, "ลบฮีโร่ที่จุด %d?" % slot,
			"ลบ %s (Lv.%d) ถาวร กู้คืนไม่ได้" % [info.name, int(info.level)], "ลบเลย", "ยกเลิก", true)
	if not ok or not is_inside_tree():
		return
	Game.delete_save(slot)
	_slots.erase(slot)
	stage.remove_hero(slot)
	if _plates.has(slot):
		(_plates[slot] as Node).queue_free()
		_plates.erase(slot)
	_selected = int(_slots.keys().min()) if not _slots.is_empty() else 0
	if _selected > 0:
		stage.select(_selected)
	_style_plates()
	_refresh()
