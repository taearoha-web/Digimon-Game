extends NewGameScreen
## Step 3: name entry with validation (non-blank, max length, safe characters).

const SUGGESTIONS := ["Hikaru", "Sora", "Ren", "Mika", "Taro", "Yuna", "Kaito", "Aoi", "Leo", "Nova", "Riku", "Emi"]

var _name_input: LineEdit
var _error: Label
var _counter: Label
var _confirm_button: Button


func _ready() -> void:
	_init_screen(2, "What's Your Name?", "This is how Digimon and other Tamers will call you.")

	var columns := UIUtil.hbox(24)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(columns)

	var preview_panel := UIUtil.panel(&"GlassPanel")
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.8
	columns.add_child(preview_panel)
	var preview := Preview3D.new()
	preview.camera_distance = 4.2
	preview.camera_height = 1.2
	preview.look_height = 0.6
	preview.auto_rotate_speed = 0.0
	preview.yaw = 0.0
	preview_panel.add_child(preview)
	var group := Node3D.new()
	var avatar := ChibiAvatar.new()
	group.add_child(avatar)
	avatar.apply_appearance(draft.appearance)
	avatar.position = Vector3(-0.55, 0, 0)
	avatar.rotation_degrees.y = 12
	var partner := DigimonVisual.new()
	group.add_child(partner)
	partner.set_species(draft.starter_species_id)
	partner.position = Vector3(0.65, 0, 0.1)
	partner.rotation_degrees.y = -15
	preview.set_subject(group)

	var form_panel := UIUtil.panel()
	form_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(form_panel)
	var form := UIUtil.vbox(16)
	form.alignment = BoxContainer.ALIGNMENT_CENTER
	form_panel.add_child(form)
	form.add_child(UIUtil.label("Tamer Name", &"SubHeaderLabel"))
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter your name"
	_name_input.max_length = NameValidator.MAX_LENGTH
	_name_input.custom_minimum_size = Vector2(0, 76)
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.text = draft.player_name
	_name_input.select_all_on_focus = true
	_name_input.text_changed.connect(_on_text_changed)
	_name_input.text_submitted.connect(func(_t): _on_confirm())
	form.add_child(_name_input)
	var info_row := UIUtil.hbox(8)
	form.add_child(info_row)
	_error = UIUtil.label("", &"SmallLabel")
	_error.add_theme_color_override("font_color", UIPalette.DANGER)
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_error)
	_counter = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	info_row.add_child(_counter)

	form.add_child(UIUtil.label("Need an idea?", &"DimLabel"))
	var suggestions := HFlowContainer.new()
	suggestions.add_theme_constant_override("h_separation", 8)
	suggestions.add_theme_constant_override("v_separation", 8)
	form.add_child(suggestions)
	var picks := SUGGESTIONS.duplicate()
	picks.shuffle()
	for i in 6:
		var b := UIUtil.button(picks[i], &"ChoiceButton", Vector2(120, 54))
		b.pressed.connect(func():
			_name_input.text = b.text
			_on_text_changed(b.text))
		suggestions.add_child(b)

	add_footer_button("Back", &"GhostButton", _on_back_requested)
	add_footer_spacer()
	_confirm_button = add_footer_button("Next: Confirm", &"PrimaryButton", _on_confirm, 300)
	_on_text_changed(_name_input.text, true)


func _on_text_changed(text: String, silent := false) -> void:
	var error := NameValidator.validate(text)
	_confirm_button.disabled = error != ""
	_error.text = "" if (silent or text.strip_edges() == "") else error
	_counter.text = "%d / %d" % [text.length(), NameValidator.MAX_LENGTH]


func _on_confirm() -> void:
	var error := NameValidator.validate(_name_input.text)
	if error != "":
		_error.text = error
		AudioManager.play_ui(&"ui_error")
		return
	AudioManager.play_ui(&"ui_confirm")
	draft.player_name = NameValidator.sanitize(_name_input.text)
	_name_input.release_focus()
	go(&"confirmation")


func _on_back_requested() -> void:
	draft.player_name = NameValidator.sanitize(_name_input.text)
	go(&"starter_selection")
