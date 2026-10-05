class_name ModalDialog
extends Control
## Blocking confirm/info dialog built from theme styles.
##
##   var ok: bool = await ModalDialog.confirm(self, "Quit?", "Unsaved progress will be lost.")

signal closed(confirmed: bool)

var _panel: PanelContainer


static func confirm(parent: Node, title: String, message: String, confirm_text := "Yes", cancel_text := "No",
		danger := false) -> bool:
	var dialog := ModalDialog.new()
	parent.add_child(dialog)
	dialog._build(title, message, confirm_text, cancel_text, danger)
	var result: bool = await dialog.closed
	return result


static func info(parent: Node, title: String, message: String, ok_text := "OK") -> void:
	var dialog := ModalDialog.new()
	parent.add_child(dialog)
	dialog._build(title, message, ok_text, "", false)
	await dialog.closed


func _build(title: String, message: String, confirm_text: String, cancel_text: String, danger: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 50
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)
	var box := UIUtil.vbox(18)
	_panel.add_child(box)
	box.add_child(UIUtil.label(title, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var body := UIUtil.label(message, &"", HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(500, 0)
	box.add_child(body)
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	if cancel_text != "":
		var cancel := UIUtil.button(cancel_text, &"GhostButton", Vector2(200, 64))
		cancel.pressed.connect(_close.bind(false))
		buttons.add_child(cancel)
	var ok := UIUtil.button(confirm_text, &"DangerButton" if danger else &"PrimaryButton", Vector2(200, 64))
	ok.pressed.connect(_close.bind(true))
	buttons.add_child(ok)
	AudioManager.play_ui(&"ui_open")
	await get_tree().process_frame
	UIUtil.pop_in(_panel)


func _close(confirmed: bool) -> void:
	closed.emit(confirmed)
	queue_free()
