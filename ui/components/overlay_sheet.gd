class_name OverlaySheet
extends Control
## Full-screen modal sheet: dimmed background, titled panel, close button and
## a content slot. Used for Settings / Save / Load from any screen.

signal closed()

var content: Control
var _panel: PanelContainer
var _title: Label


static func open(parent: Node, title: String, content_node: Control, min_size := Vector2(900, 560)) -> OverlaySheet:
	var sheet := OverlaySheet.new()
	parent.add_child(sheet)
	sheet._build(title, content_node, min_size)
	return sheet


func _build(title: String, content_node: Control, min_size: Vector2) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = min_size
	center.add_child(_panel)
	var box := UIUtil.vbox(14)
	_panel.add_child(box)
	var header := UIUtil.hbox(12)
	box.add_child(header)
	_title = UIUtil.label(title, &"HeaderLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := UIUtil.icon_button("res://assets/icons/ui/close.svg", Vector2(64, 64))
	close.pressed.connect(close_sheet)
	header.add_child(close)
	box.add_child(HSeparator.new())
	content = content_node
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	AudioManager.play_ui(&"ui_open")
	await get_tree().process_frame
	UIUtil.pop_in(_panel)


func close_sheet() -> void:
	AudioManager.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_sheet()
