class_name NewGameScreen
extends Control
## Base for the New Game steps: shared background, step header and footer.
## The draft travels between screens via SceneManager params {"draft": NewGameDraft}.

const STEPS := ["Tamer", "Partner", "Name", "Confirm"]

var draft: NewGameDraft
var body: Control
var footer: HBoxContainer


func _init_screen(step_index: int, title: String, subtitle: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var params := SceneManager.take_params()
	draft = params.get("draft") as NewGameDraft
	if draft == null:
		draft = NewGameDraft.new()
	add_child(UIUtil.digital_background())
	var safe := SafeAreaContainer.new()
	add_child(safe)
	var root := UIUtil.vbox(12)
	safe.add_child(root)

	var header := UIUtil.hbox(16)
	root.add_child(header)
	var titles := UIUtil.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(UIUtil.label(title, &"HeaderLabel"))
	titles.add_child(UIUtil.label(subtitle, &"DimLabel"))
	header.add_child(_step_indicator(step_index))

	body = Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	footer = UIUtil.hbox(16)
	root.add_child(footer)
	if AudioManager.current_music_id != &"title":
		AudioManager.play_music(&"title")


func _step_indicator(step_index: int) -> Control:
	var row := UIUtil.hbox(6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in STEPS.size():
		var active := i == step_index
		var done := i < step_index
		var color := UIPalette.GOLD if active else (UIPalette.CYAN if done else UIPalette.TEXT_MUTED)
		var chip := UIUtil.chip("%d  %s" % [i + 1, STEPS[i]], color, 17)
		row.add_child(chip)
	return row


func add_footer_button(text: String, variation: StringName, callback: Callable, min_width := 220.0) -> Button:
	var b := UIUtil.button(text, variation, Vector2(min_width, 68))
	b.pressed.connect(callback)
	footer.add_child(b)
	return b


func add_footer_spacer() -> void:
	footer.add_child(UIUtil.spacer())


func go(scene_key: StringName) -> void:
	SceneManager.goto_scene(scene_key, {"draft": draft})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_requested()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_requested()


## Override: Android back button / Esc.
func _on_back_requested() -> void:
	pass
