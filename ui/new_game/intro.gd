extends Control
## Short narrated intro between New Game and the first map.
## Text comes from the "intro_sequence" DialogueData resource.

const CHARS_PER_SECOND := 45.0

var _lines: Array[DialogueLine] = []
var _index := -1
var _text: RichTextLabel
var _speaker: Label
var _speaker_panel: PanelContainer
var _preview: Preview3D
var _partner: DigimonVisual
var _typing_tween: Tween
var _finished := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIUtil.digital_background())
	_preview = Preview3D.new()
	_preview.anchor_left = 0.25
	_preview.anchor_right = 0.75
	_preview.anchor_bottom = 0.72
	_preview.auto_rotate_speed = 0.0
	_preview.yaw = 0.0
	_preview.show_pedestal = true
	_preview.modulate.a = 0.0
	add_child(_preview)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_partner = DigimonVisual.new()
	_preview.set_subject(_partner)
	var lead := GameState.roster.get_lead()
	_partner.set_species(lead.species_id if lead else &"agumon")
	_preview.frame_height(_partner.model_height)

	var safe := SafeAreaContainer.new()
	add_child(safe)
	var column := UIUtil.vbox(10)
	safe.add_child(column)
	var top := UIUtil.hbox()
	column.add_child(top)
	top.add_child(UIUtil.spacer())
	var skip := UIUtil.button("Skip", &"GhostButton", Vector2(150, 58))
	skip.pressed.connect(_finish)
	top.add_child(skip)
	column.add_child(UIUtil.spacer(false))

	var box := UIUtil.panel(&"DialoguePanel")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(0, 170)
	column.add_child(box)
	var inner := UIUtil.vbox(8)
	box.add_child(inner)
	_speaker_panel = UIUtil.panel(&"NameTagPanel")
	_speaker_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	inner.add_child(_speaker_panel)
	_speaker = UIUtil.label("", &"NameTagLabel")
	_speaker_panel.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 26)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_text)
	var hint := UIUtil.label("Tap to continue ▸", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	inner.add_child(hint)

	var dialogue := GameData.get_dialogue(&"intro_sequence")
	if dialogue:
		_lines = dialogue.lines
	AudioManager.play_music(&"title")
	_advance()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		_on_tap()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_on_tap()


func _on_tap() -> void:
	if _typing_tween and _typing_tween.is_running():
		_typing_tween.kill()
		_text.visible_ratio = 1.0
		return
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line := _lines[_index]
	var speaker := TextVars.format(line.speaker, {}, false)
	_speaker_panel.visible = speaker != ""
	_speaker.text = speaker
	_text.text = TextVars.format(line.text) if speaker != "" else "[i]%s[/i]" % TextVars.format(line.text)
	_text.visible_ratio = 0.0
	_typing_tween = create_tween()
	_typing_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.3, line.text.length() / CHARS_PER_SECOND))
	AudioManager.play_ui(&"dialogue_blip")
	if speaker != "" and _preview.modulate.a < 1.0:
		var t := create_tween()
		t.tween_property(_preview, "modulate:a", 1.0, 0.6)
		_partner.play_once(&"victory", &"idle")
		AudioManager.play_sfx(&"portal")
	elif speaker != "":
		_partner.play_once(&"skill", &"idle")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneManager.goto_map(GameState.world.current_map_id, GameState.world.spawn_id, {"intro": true})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_finish()
