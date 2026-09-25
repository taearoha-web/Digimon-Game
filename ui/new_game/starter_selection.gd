extends NewGameScreen
## Step 2: choose a partner. Cards are generated from the StarterRoster data,
## so adding a starter needs no code change.

var _roster: StarterRoster
var _cards: Array[PanelContainer] = []
var _select_buttons: Array[Button] = []
var _ids: Array[StringName] = []
var _selected := -1
var _confirm_button: Button


func _ready() -> void:
	_init_screen(1, "Choose Your Partner", "Your partner Digimon will follow you everywhere. Drag a preview to rotate it.")
	_roster = GameData.starter_roster
	for species_id in _roster.starter_ids:
		if GameData.get_species(species_id):
			_ids.append(species_id)

	var content := UIUtil.vbox(12)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(content)
	var card_row := UIUtil.hbox(16)
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(card_row)
	for i in _ids.size():
		var card := _build_card(i, GameData.get_species(_ids[i]))
		card_row.add_child(card)
		_cards.append(card)

	add_footer_button("Back", &"GhostButton", _on_back_requested)
	add_footer_spacer()
	_confirm_button = add_footer_button("Confirm Partner", &"PrimaryButton", _on_confirm, 320)
	_confirm_button.disabled = true

	var previous := _ids.find(draft.starter_species_id)
	if previous >= 0:
		_select(previous)


func _build_card(index: int, species: DigimonSpecies) -> PanelContainer:
	var card := UIUtil.panel(&"CardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIUtil.vbox(4)
	card.add_child(box)

	var preview := Preview3D.new()
	preview.custom_minimum_size = Vector2(0, 120)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(preview)
	var visual := DigimonVisual.new()
	preview.set_subject(visual)
	visual.set_species(species)
	preview.frame_height(visual.model_height)
	preview.yaw = 0.35

	var name_row := UIUtil.hbox(8)
	box.add_child(name_row)
	var name_label := UIUtil.label(species.display_name, &"HeaderLabel")
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	name_row.add_child(UIUtil.chip(species.get_attribute_name(), UIPalette.attribute_color(species.attribute)))
	var tagline: String = str(_roster.taglines.get(species.id, species.digimon_type))
	box.add_child(UIUtil.label(L10n.t("%s  ·  %s type  ·  %s") % [tagline, species.digimon_type, UIUtil.element_name(species.element)], &"SmallLabel"))
	var desc := UIUtil.label(species.description.replace(L10n.t(" (Original placeholder model.)"), ""), &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 15)
	desc.max_lines_visible = 3
	desc.custom_minimum_size = Vector2(0, 58)
	box.add_child(desc)

	var level := _roster.starting_level
	var preview_inst := DigimonInstance.create(species.id, level)
	for stat in [DigimonStats.MAX_HP, DigimonStats.ATTACK, DigimonStats.DEFENSE, DigimonStats.SPEED]:
		box.add_child(_stat_row(stat, preview_inst.get_stat(stat)))

	var skill_names: Array = []
	for skill_id in species.innate_skills:
		var skill := GameData.get_skill(skill_id)
		if skill and skill.id != &"tackle":
			skill_names.append(skill.display_name)
	var skill_label := UIUtil.label(L10n.t("Starter skill: %s") % ", ".join(skill_names), &"BoldLabel")
	skill_label.add_theme_font_size_override("font_size", 19)
	box.add_child(skill_label)
	var evo_label := UIUtil.label(_evolution_text(species), &"SmallLabel")
	evo_label.add_theme_color_override("font_color", UIPalette.GOLD)
	evo_label.add_theme_font_size_override("font_size", 15)
	box.add_child(evo_label)

	var select := UIUtil.button("Select", &"ChoiceButton", Vector2(0, 54))
	select.toggle_mode = true
	select.pressed.connect(_select.bind(index))
	box.add_child(select)
	_select_buttons.append(select)
	card.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			_select(index))
	return card


func _stat_row(stat: StringName, value: int) -> Control:
	var row := UIUtil.hbox(8)
	row.add_theme_constant_override("separation", 6)
	var label := UIUtil.label(DigimonStats.short_name(stat), &"SmallLabel")
	label.custom_minimum_size = Vector2(52, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HPBar" if stat == DigimonStats.MAX_HP else &"StatBar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 80.0 if stat == DigimonStats.MAX_HP else 30.0
	bar.value = value
	row.add_child(bar)
	var value_label := UIUtil.label(str(value), &"ValueLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.add_theme_font_size_override("font_size", 19)
	value_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(value_label)
	return row


func _evolution_text(species: DigimonSpecies) -> String:
	var seen: Array = []
	var parts: Array = []
	for path in species.evolutions:
		var target := GameData.get_species(path.target_species_id)
		if target == null or seen.has(target.id):
			continue
		seen.append(target.id)
		parts.append(L10n.t("%s (%s) at Lv %d") % [target.display_name, target.get_stage_name(), path.min_level])
	return L10n.t("Evolves into %s") % ", ".join(parts) if not parts.is_empty() else L10n.t("Evolution: unknown")


func _select(index: int) -> void:
	if index == _selected:
		_select_buttons[index].button_pressed = true
		return
	_selected = index
	AudioManager.play_ui(&"ui_select")
	for i in _cards.size():
		_cards[i].theme_type_variation = &"CardPanelSelected" if i == index else &"CardPanel"
		_select_buttons[i].button_pressed = i == index
		_select_buttons[i].text = "Selected!" if i == index else "Select"
	var preview := _cards[index].get_child(0).get_child(0) as Preview3D
	if preview and preview.subject is DigimonVisual:
		(preview.subject as DigimonVisual).play_once(&"victory", &"idle")
	_confirm_button.disabled = false


func _on_confirm() -> void:
	if _selected < 0:
		return
	AudioManager.play_ui(&"ui_confirm")
	draft.starter_species_id = _ids[_selected]
	go(&"player_name")


func _on_back_requested() -> void:
	if _selected >= 0:
		draft.starter_species_id = _ids[_selected]
	go(&"character_creation")
