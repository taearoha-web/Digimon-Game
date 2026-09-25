extends NewGameScreen
## Step 1: create the human Tamer. Every change is shown live on the 3D
## preview; options come from the data-driven CustomizationCatalog.

const TABS := ["Body", "Hair", "Face", "Outfit", "Extras"]

var catalog: CustomizationCatalog
var appearance: CharacterAppearance
var _avatar: ChibiAvatar
var _preview: Preview3D
var _tab_content: VBoxContainer
var _tab_buttons: Array[Button] = []
var _current_tab := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_init_screen(0, "Create Your Tamer", "Customise how you look in the Digital World. Drag the preview to rotate.")
	_rng.randomize()
	catalog = GameData.customization_catalog
	appearance = draft.appearance.duplicate_appearance() if draft.appearance else CharacterAppearance.create_default()

	var columns := UIUtil.hbox(18)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(columns)

	# Left: live preview.
	var left := UIUtil.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	columns.add_child(left)
	var preview_panel := UIUtil.panel(&"GlassPanel")
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(preview_panel)
	_preview = Preview3D.new()
	_preview.camera_distance = 3.1
	_preview.camera_height = 1.0
	_preview.look_height = 0.72
	_preview.fov = 34
	preview_panel.add_child(_preview)
	_avatar = ChibiAvatar.new()
	_preview.set_subject(_avatar)
	_avatar.apply_appearance(appearance)
	_avatar.play_animation(&"wave")
	var preview_buttons := UIUtil.hbox(10)
	left.add_child(preview_buttons)
	var random_button := UIUtil.button("Randomize", &"AccentButton", Vector2(0, 62))
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_button.pressed.connect(_on_randomize)
	preview_buttons.add_child(random_button)
	var reset_button := UIUtil.button("Reset", &"GhostButton", Vector2(0, 62))
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_on_reset)
	preview_buttons.add_child(reset_button)

	# Right: option tabs.
	var right_panel := UIUtil.panel()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_panel)
	var right := UIUtil.vbox(12)
	right_panel.add_child(right)
	var tab_row := UIUtil.hbox(8)
	right.add_child(tab_row)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var tab := UIUtil.button(TABS[i], &"TabButton", Vector2(0, 56))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(_show_tab.bind(i))
		tab_row.add_child(tab)
		_tab_buttons.append(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_tab_content = UIUtil.vbox(16)
	_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tab_content)

	add_footer_button("Back", &"GhostButton", _on_back_requested)
	add_footer_spacer()
	add_footer_button("Next: Choose Partner", &"PrimaryButton", _on_confirm, 340)
	_tab_buttons[0].button_pressed = true
	_show_tab(0)


func _show_tab(index: int) -> void:
	_current_tab = index
	UIUtil.clear(_tab_content)
	match TABS[index]:
		"Body":
			_tab_content.add_child(UIUtil.label("Body Type", &"SubHeaderLabel"))
			_tab_content.add_child(_body_type_buttons())
			_tab_content.add_child(UIUtil.label("Skin Tone", &"SubHeaderLabel"))
			_tab_content.add_child(_swatches(catalog.skin_tones, appearance.skin_tone, func(c): appearance.skin_tone = c))
		"Hair":
			_tab_content.add_child(_selector("Hairstyle", &"hair_style", catalog.hair_styles))
			_tab_content.add_child(UIUtil.label("Hair Colour", &"SubHeaderLabel"))
			_tab_content.add_child(_swatches(catalog.hair_colors, appearance.hair_color, func(c): appearance.hair_color = c))
		"Face":
			_tab_content.add_child(_selector("Face", &"face", catalog.faces))
			_tab_content.add_child(UIUtil.label("Eye Colour", &"SubHeaderLabel"))
			_tab_content.add_child(_swatches(catalog.eye_colors, appearance.eye_color, func(c): appearance.eye_color = c))
		"Outfit":
			_tab_content.add_child(_selector("Top", &"top", catalog.tops))
			_tab_content.add_child(_swatches(catalog.clothing_colors, appearance.top_color, func(c): appearance.top_color = c))
			_tab_content.add_child(HSeparator.new())
			_tab_content.add_child(_selector("Bottom", &"bottom", catalog.bottoms))
			_tab_content.add_child(_swatches(catalog.clothing_colors, appearance.bottom_color, func(c): appearance.bottom_color = c))
			_tab_content.add_child(HSeparator.new())
			_tab_content.add_child(_selector("Shoes", &"shoes", catalog.shoes))
			_tab_content.add_child(_swatches(catalog.clothing_colors, appearance.shoes_color, func(c): appearance.shoes_color = c))
		"Extras":
			_tab_content.add_child(UIUtil.label("Accessories", &"SubHeaderLabel"))
			for option in catalog.accessories:
				var accessory_id := StringName(option.id)
				var toggle := CheckButton.new()
				toggle.text = str(option.name)
				toggle.button_pressed = appearance.has_accessory(accessory_id)
				toggle.custom_minimum_size = Vector2(0, 56)
				toggle.focus_mode = Control.FOCUS_NONE
				toggle.toggled.connect(func(on: bool):
					AudioManager.play_ui(&"ui_click")
					appearance.set_accessory(accessory_id, on)
					_apply())
				_tab_content.add_child(toggle)
			_tab_content.add_child(UIUtil.label("Accessory Colour", &"SubHeaderLabel"))
			_tab_content.add_child(_swatches(catalog.clothing_colors, appearance.accessory_color, func(c): appearance.accessory_color = c))


func _body_type_buttons() -> Control:
	var row := UIUtil.hbox(12)
	var group := ButtonGroup.new()
	for option in catalog.body_types:
		var body_id := StringName(option.id)
		var b := UIUtil.button(str(option.name), &"ChoiceButton", Vector2(0, 72))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = appearance.body_type == body_id
		b.pressed.connect(func():
			if appearance.body_type == body_id:
				return
			appearance.body_type = body_id
			_apply())
		row.add_child(b)
	return row


func _selector(title: String, slot: StringName, options: Array[Dictionary]) -> OptionSelector:
	var names: Array = []
	for option in options:
		names.append(option.name)
	var current := catalog.index_of_option(slot, appearance.get(slot))
	var selector := OptionSelector.new().setup(title, names, maxi(0, current))
	selector.changed.connect(func(i: int):
		appearance.set(slot, StringName(options[i].id))
		_apply())
	return selector


func _swatches(palette: PackedColorArray, current: Color, setter: Callable) -> ColorSwatches:
	var swatches := ColorSwatches.new().setup(palette, CustomizationCatalog.index_of_color(palette, current))
	swatches.color_selected.connect(func(_i: int, color: Color):
		setter.call(color)
		_apply())
	return swatches


func _apply() -> void:
	_avatar.apply_appearance(appearance)
	_avatar.play_once(&"interact", &"wave")


func _on_randomize() -> void:
	appearance.randomize_from(catalog, _rng, true)
	_apply()
	_show_tab(_current_tab)


func _on_reset() -> void:
	appearance = CharacterAppearance.create_default(appearance.body_type)
	_apply()
	_show_tab(_current_tab)


func _on_confirm() -> void:
	AudioManager.play_ui(&"ui_confirm")
	draft.appearance = appearance.duplicate_appearance()
	go(&"starter_selection")


func _on_back_requested() -> void:
	var ok := await ModalDialog.confirm(self, "Leave Character Creation?", "Your choices will be lost.", "Leave", "Stay")
	if ok:
		SceneManager.goto_scene(&"main_menu")
