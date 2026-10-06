class_name DialogBox
extends CanvasLayer
## A speech panel at the bottom of the screen with optional answer buttons.

signal closed()

var is_open := false
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var safe := SafeAreaContainer.new()
	root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_panel = UIUtil.panel(&"DialoguePanel")
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -480
	_panel.offset_right = 480
	_panel.offset_top = -270
	_panel.offset_bottom = -12
	_panel.visible = false
	frame.add_child(_panel)
	var column := UIUtil.vbox(10)
	_panel.add_child(column)
	_speaker = UIUtil.label("", &"SubHeaderLabel")
	_speaker.add_theme_color_override("font_color", UIPalette.GOLD)
	column.add_child(_speaker)
	var text_scroll := TouchScroll.new()
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_scroll.custom_minimum_size = Vector2(0, 90)
	column.add_child(text_scroll)
	_text = UIUtil.label("", &"BoldLabel")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_scroll.add_child(_text)
	_buttons = UIUtil.hbox(14)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)


## options: [{ "label": String, "action": Callable }]. No options = a single "ตกลง".
func say(speaker: String, text: String, options: Array = []) -> void:
	is_open = true
	_speaker.text = speaker
	_text.text = text
	UIUtil.clear(_buttons)
	if options.is_empty():
		options = [{"label": "ตกลง", "action": Callable()}]
	for option in options:
		var b := UIUtil.button(String(option.label), &"PrimaryButton" if option == options[0] else &"", Vector2(140, 52))
		var action: Callable = option.get("action", Callable())
		b.pressed.connect(func():
			close()
			if action.is_valid():
				action.call())
		_buttons.add_child(b)
	_panel.visible = true
	UIUtil.pop_in(_panel)


func close() -> void:
	is_open = false
	_panel.visible = false
	closed.emit()
