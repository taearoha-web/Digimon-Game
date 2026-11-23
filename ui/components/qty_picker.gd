class_name QtyPicker
extends Control
## A blocking count chooser for bulk actions (sell a stack, fuse gems many times):
## − / + steps, quick −10 −1 +1 +10 +100, a slider, "ทั้งหมด", a live line saying what
## the count gives, and one confirm. Built from theme styles like ModalDialog; every
## control is a big touch target.
##
##   var n: int = await QtyPicker.pick(self, "ขายยาเลือดเล็ก", 1000, func(n): return "ได้ %d เหรียญ" % (n * 5), "ขาย")
##   if n > 0: ...   # 0 = cancelled

signal closed(count: int)

const STEPS := [-10, -1, 1, 10, 100]

var count := 1
var max_count := 1
var _describe: Callable
var _panel: PanelContainer
var _count_label: Label
var _line: Label
var _slider: HSlider
var _confirm: Button
var _confirm_text := ""
var _step_buttons := {}


## Opens the chooser over [param parent] and waits: the count picked, 0 when cancelled.
## [param describe] (count -> String) is the live line under the count.
static func pick(parent: Node, title: String, max_value: int, describe: Callable, confirm_text := "ยืนยัน",
		start := 1, icon: Texture2D = null, note := "") -> int:
	if max_value <= 0:
		return 0
	var dialog := QtyPicker.new()
	parent.add_child(dialog)
	dialog._build(title, max_value, describe, confirm_text, start, icon, note)
	var result: int = await dialog.closed
	return result


func _build(title: String, max_value: int, describe: Callable, confirm_text: String, start: int, icon: Texture2D, note: String) -> void:
	name = "QtyPicker"
	max_count = max_value
	count = clampi(start, 1, max_value)
	_describe = describe
	_confirm_text = confirm_text
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(_panel)
	var box := UIUtil.vbox(14)
	_panel.add_child(box)
	var head := UIUtil.hbox(12)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(head)
	if icon != null:
		head.add_child(UIUtil.texture_rect(icon, Vector2(56, 56)))
	var title_label := UIUtil.label(title, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(440, 0)
	head.add_child(title_label)
	if note != "":
		var note_label := UIUtil.label(note, &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.custom_minimum_size = Vector2(560, 0)
		box.add_child(note_label)
	_count_label = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_count_label.name = "QtyCount"
	_count_label.add_theme_color_override("font_color", UIPalette.GOLD)
	box.add_child(_count_label)
	var steps := UIUtil.hbox(8)
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(steps)
	for d in STEPS:
		var b := UIUtil.button(("+%d" % d) if d > 0 else ("−%d" % -d), &"", Vector2(100, 60))
		b.name = "Step%s%d" % ["Plus" if d > 0 else "Minus", absi(d)]
		b.pressed.connect(_set_count.bind(-1, d))
		steps.add_child(b)
		_step_buttons[d] = b
	var slide := UIUtil.hbox(10)
	box.add_child(slide)
	var one := UIUtil.button("1", &"GhostButton", Vector2(80, 60))
	one.name = "QtyOne"
	one.pressed.connect(_set_count.bind(1, 0))
	slide.add_child(one)
	_slider = HSlider.new()
	_slider.name = "QtySlider"
	_slider.min_value = 1
	_slider.max_value = max_value
	_slider.step = 1
	_slider.value = count
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size = Vector2(0, 48)
	_slider.editable = max_value > 1
	_slider.value_changed.connect(func(v: float): _set_count(int(v), 0, false))
	slide.add_child(_slider)
	var all := UIUtil.button("ทั้งหมด (%d)" % max_value, &"AccentButton", Vector2(170, 60))
	all.name = "QtyAll"
	all.pressed.connect(_set_count.bind(max_value, 0))
	slide.add_child(all)
	_line = UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_line.name = "QtyLine"
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(560, 0)
	box.add_child(_line)
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var cancel := UIUtil.button("ยกเลิก", &"GhostButton", Vector2(200, 64))
	cancel.name = "QtyCancel"
	cancel.pressed.connect(_close.bind(false))
	buttons.add_child(cancel)
	_confirm = UIUtil.button("", &"PrimaryButton", Vector2(260, 64))
	_confirm.name = "QtyConfirm"
	_confirm.pressed.connect(_close.bind(true))
	buttons.add_child(_confirm)
	_show()
	AudioManager.play_ui(&"ui_open")
	await get_tree().process_frame
	if is_instance_valid(_panel):
		UIUtil.pop_in(_panel)


## Sets the count to [param value] (or steps it by [param delta] when value < 0).
func _set_count(value: int, delta: int, move_slider := true) -> void:
	count = clampi(value if value > 0 else count + delta, 1, max_count)
	if move_slider and _slider != null:
		_slider.set_value_no_signal(count)
	_show()


func _show() -> void:
	_count_label.text = "×%d" % count
	_line.text = String(_describe.call(count)) if _describe.is_valid() else ""
	_confirm.text = "%s ×%d" % [_confirm_text, count]
	for d in _step_buttons:
		(_step_buttons[d] as Button).disabled = (d < 0 and count <= 1) or (d > 0 and count >= max_count)


func _close(confirmed: bool) -> void:
	closed.emit(count if confirmed else 0)
	queue_free()
