extends NewGameScreen
## Step 4: summary of every choice. Confirming creates the save.

var _busy := false


func _ready() -> void:
	_init_screen(3, "Ready for Adventure?", "Check your choices. You can go back to change anything.")
	if not draft.is_complete():
		push_warning("Confirmation opened with an incomplete draft")

	var columns := UIUtil.hbox(24)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(columns)

	var preview_panel := UIUtil.panel(&"GlassPanel")
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(preview_panel)
	var preview := Preview3D.new()
	preview.camera_distance = 4.4
	preview.camera_height = 1.3
	preview.look_height = 0.6
	preview.auto_rotate_speed = 0.2
	preview_panel.add_child(preview)
	var group := Node3D.new()
	var avatar := ChibiAvatar.new()
	group.add_child(avatar)
	avatar.apply_appearance(draft.appearance)
	avatar.position = Vector3(-0.6, 0, 0)
	var partner := DigimonVisual.new()
	group.add_child(partner)
	partner.set_species(draft.starter_species_id)
	partner.position = Vector3(0.7, 0, 0.1)
	preview.set_subject(group)
	avatar.play_animation(&"wave")

	var summary_panel := UIUtil.panel()
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(summary_panel)
	var summary := UIUtil.vbox(10)
	summary_panel.add_child(summary)

	summary.add_child(UIUtil.label("Tamer", &"SubHeaderLabel"))
	summary.add_child(UIUtil.label(draft.player_name, &"HeaderLabel"))
	var catalog := GameData.customization_catalog
	var a := draft.appearance
	var outfit := "%s · %s · %s" % [
		catalog.find_option(&"top", a.top).get("name", a.top),
		catalog.find_option(&"bottom", a.bottom).get("name", a.bottom),
		catalog.find_option(&"shoes", a.shoes).get("name", a.shoes)]
	summary.add_child(UIUtil.label("%s body · %s hair · %s face" % [
		catalog.find_option(&"body_type", a.body_type).get("name", a.body_type),
		catalog.find_option(&"hair_style", a.hair_style).get("name", a.hair_style),
		catalog.find_option(&"face", a.face).get("name", a.face)], &"DimLabel"))
	summary.add_child(UIUtil.label(outfit, &"DimLabel"))
	summary.add_child(HSeparator.new())

	var species := GameData.get_species(draft.starter_species_id)
	summary.add_child(UIUtil.label("Partner", &"SubHeaderLabel"))
	if species:
		var name_row := UIUtil.hbox(10)
		name_row.add_child(UIUtil.label(species.display_name, &"HeaderLabel"))
		name_row.add_child(UIUtil.chip(species.get_attribute_name(), UIPalette.attribute_color(species.attribute)))
		name_row.add_child(UIUtil.chip(species.get_stage_name(), UIPalette.stage_color(species.stage)))
		summary.add_child(name_row)
		var desc := UIUtil.label(species.description, &"DimLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_child(desc)
	summary.add_child(UIUtil.spacer(false))
	var note := UIUtil.label("Your progress will be autosaved after you confirm.", &"SmallLabel")
	summary.add_child(note)

	add_footer_button("Back", &"GhostButton", _on_back_requested)
	add_footer_spacer()
	add_footer_button("Begin Adventure!", &"PrimaryButton", _on_confirm, 340)


func _on_confirm() -> void:
	if _busy:
		return
	if not draft.is_complete():
		EventBus.toast("Something is missing — please go back and check.", &"warning")
		return
	_busy = true
	AudioManager.play_ui(&"confirm_big")
	GameState.start_new_game(draft)
	SaveManager.autosave("starter confirmed", true)
	SceneManager.goto_scene(&"intro")


func _on_back_requested() -> void:
	if not _busy:
		go(&"player_name")
