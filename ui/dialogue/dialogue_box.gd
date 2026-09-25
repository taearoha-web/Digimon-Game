class_name DialogueBox
extends CanvasLayer
## Mobile-friendly dialogue UI: speaker tag, typewriter text, Next and Skip.
## Tap anywhere on the box to finish the line / advance.
##
##   await DialogueBox.find(get_tree()).play(&"mira_offer", {"npc_name": "Mira"})

signal finished(dialogue_id: StringName)

const CHARS_PER_SECOND := 50.0

var is_open := false

var _lines: Array[DialogueLine] = []
var _index := 0
var _context := {}
var _dialogue_id: StringName = &""
var _skippable := true
var _root: Control
var _panel: PanelContainer
var _speaker_panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _next_button: Button
var _skip_button: Button
var _typing: Tween
var _open_time := 0


static func find(tree: SceneTree) -> DialogueBox:
	return tree.get_first_node_in_group("dialogue_box") as DialogueBox if tree else null


func _ready() -> void:
	layer = 60
	add_to_group("dialogue_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var column := UIUtil.vbox(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	column.add_child(UIUtil.spacer(false))
	var wrapper := CenterContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(wrapper)
	_panel = UIUtil.panel(&"DialoguePanel")
	_panel.custom_minimum_size = Vector2(980, 190)
	_panel.gui_input.connect(_on_panel_input)
	wrapper.add_child(_panel)
	var inner := UIUtil.vbox(8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(inner)
	var top := UIUtil.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(top)
	_speaker_panel = UIUtil.panel(&"NameTagPanel")
	_speaker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_speaker_panel)
	_speaker = UIUtil.label("", &"NameTagLabel")
	_speaker_panel.add_child(_speaker)
	top.add_child(UIUtil.spacer())
	_skip_button = UIUtil.button("Skip", &"GhostButton", Vector2(120, 52))
	_skip_button.pressed.connect(_skip)
	top.add_child(_skip_button)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size = Vector2(0, 70)
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.add_theme_font_size_override("bold_font_size", 26)
	inner.add_child(_text)
	var bottom := UIUtil.hbox(10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bottom)
	bottom.add_child(UIUtil.spacer())
	_next_button = UIUtil.button("Next ▸", &"AccentButton", Vector2(170, 56))
	_next_button.pressed.connect(_advance)
	bottom.add_child(_next_button)


func play(dialogue_id: StringName, context := {}) -> void:
	var data := GameData.get_dialogue(dialogue_id)
	if data == null:
		push_warning("DialogueBox: missing dialogue '%s'" % dialogue_id)
		return
	await play_lines(data.lines, context, data.skippable, dialogue_id)


func play_lines(lines: Array[DialogueLine], context := {}, skippable := true, dialogue_id: StringName = &"") -> void:
	if is_open:
		await finished
	if lines.is_empty():
		return
	_lines = lines
	_context = context
	_skippable = skippable
	_dialogue_id = dialogue_id
	_index = 0
	is_open = true
	_open_time = Time.get_ticks_msec()
	_root.visible = true
	UIUtil.pop_in(_panel, 0.18)
	EventBus.dialogue_started.emit(dialogue_id)
	_show_line()
	await finished


func _show_line() -> void:
	var line := _lines[_index]
	var speaker := TextVars.format(line.speaker, _context, false)
	_speaker_panel.visible = speaker != ""
	_speaker.text = speaker
	var body := TextVars.format(line.text, _context)
	_text.text = body if speaker != "" else "[i]%s[/i]" % body
	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.25, line.text.length() / CHARS_PER_SECOND))
	var last := _index >= _lines.size() - 1
	_next_button.text = "Close" if last else "Next ▸"
	_skip_button.visible = _skippable and not last
	AudioManager.play_ui(&"dialogue_blip")


func _advance() -> void:
	if not is_open:
		return
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _skip() -> void:
	if is_open and _skippable:
		_close()


func _close() -> void:
	is_open = false
	_root.visible = false
	var id := _dialogue_id
	EventBus.dialogue_finished.emit(id)
	finished.emit(id)


func _on_panel_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if tapped:
		_panel.accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	# Ignore the key press that opened the dialogue.
	if Time.get_ticks_msec() - _open_time < 200:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel") and _skippable:
		get_viewport().set_input_as_handled()
		_skip()
