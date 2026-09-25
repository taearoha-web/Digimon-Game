class_name SettingsPanel
extends ScrollContainer
## Settings UI. Changes apply instantly and persist via the Settings autoload.


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(820, 420)
	var box := UIUtil.vbox(18)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)

	box.add_child(UIUtil.label("Audio", &"SubHeaderLabel"))
	box.add_child(_slider_row("Music Volume", &"music_volume", 0.0, 1.0, 0.05, true))
	box.add_child(_slider_row("Sound Effects", &"sfx_volume", 0.0, 1.0, 0.05, true))
	box.add_child(_slider_row("Interface Sounds", &"ui_volume", 0.0, 1.0, 0.05, true))

	box.add_child(UIUtil.label("Graphics", &"SubHeaderLabel"))
	box.add_child(_quality_row())
	box.add_child(_toggle_row("Show FPS Counter", &"show_fps"))
	if Settings.can_fullscreen():
		var fullscreen := CheckButton.new()
		fullscreen.text = "Fullscreen"
		fullscreen.button_pressed = Settings.is_fullscreen()
		fullscreen.custom_minimum_size = Vector2(0, 52)
		fullscreen.focus_mode = Control.FOCUS_NONE
		fullscreen.toggled.connect(func(on: bool):
			AudioManager.play_ui(&"ui_click")
			Settings.set_fullscreen(on))
		box.add_child(fullscreen)

	box.add_child(UIUtil.label("Controls", &"SubHeaderLabel"))
	box.add_child(_slider_row("Camera Sensitivity", &"camera_sensitivity", 0.2, 3.0, 0.1, false))
	box.add_child(_toggle_row("Invert Camera Y", &"invert_camera_y"))

	box.add_child(UIUtil.label("Language", &"SubHeaderLabel"))
	var lang_row := UIUtil.hbox(12)
	var lang_label := UIUtil.label("Language", &"BoldLabel")
	lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lang_label)
	var lang_group := ButtonGroup.new()
	for code in Settings.LANGUAGES.keys():
		# Language names are shown in their own language, never translated.
		var lang := UIUtil.button(Settings.LANGUAGES[code], &"TabButton", Vector2(150, 56))
		lang.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lang.toggle_mode = true
		lang.button_group = lang_group
		lang.button_pressed = Settings.language == code
		lang.pressed.connect(func(): Settings.set_setting(&"language", code))
		lang_row.add_child(lang)
	box.add_child(lang_row)
	box.add_child(UIUtil.label("Some text updates when you reopen a screen.", &"SmallLabel"))


func _slider_row(title: String, key: StringName, min_value: float, max_value: float, step: float, percent: bool) -> Control:
	var row := UIUtil.hbox(16)
	var label := UIUtil.label(title, &"BoldLabel")
	label.custom_minimum_size = Vector2(260, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(Settings.get(key))
	slider.custom_minimum_size = Vector2(0, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := UIUtil.label("", &"ValueLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(value_label)
	var fmt := func(v: float) -> String:
		return "%d%%" % int(round(v * 100.0)) if percent else "%.1fx" % v
	value_label.text = fmt.call(slider.value)
	slider.value_changed.connect(func(v: float):
		value_label.text = fmt.call(v)
		Settings.set_setting(key, v, false))
	slider.drag_ended.connect(func(_changed: bool):
		Settings.save_settings()
		if key == &"sfx_volume":
			AudioManager.play_sfx(&"hit_physical")
		elif key == &"ui_volume":
			AudioManager.play_ui(&"ui_confirm"))
	return row


func _toggle_row(title: String, key: StringName) -> Control:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = bool(Settings.get(key))
	toggle.custom_minimum_size = Vector2(0, 52)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(func(on: bool):
		AudioManager.play_ui(&"ui_click")
		Settings.set_setting(key, on))
	return toggle


func _quality_row() -> Control:
	var row := UIUtil.hbox(12)
	var label := UIUtil.label("Graphics Quality", &"BoldLabel")
	label.custom_minimum_size = Vector2(260, 0)
	row.add_child(label)
	var group := ButtonGroup.new()
	for i in Settings.QUALITY_NAMES.size():
		var b := UIUtil.button(Settings.QUALITY_NAMES[i], &"TabButton", Vector2(150, 56))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Settings.graphics_quality == i
		b.pressed.connect(func(): Settings.set_setting(&"graphics_quality", i))
		row.add_child(b)
	return row
