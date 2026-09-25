extends Control
## Title screen: animated background, 3D starter showcase and main actions.

var _continue_button: Button
var _load_button: Button
var _menu_column: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false
	add_child(UIUtil.digital_background())

	var showcase := Preview3D.new()
	showcase.anchor_right = 0.56
	showcase.anchor_bottom = 1.0
	showcase.auto_rotate_speed = 0.25
	add_child(showcase)
	showcase.set_subject(_build_showcase())
	showcase.camera_distance = 6.6
	showcase.camera_height = 2.2
	showcase.look_height = 0.55
	showcase._update_camera()

	var safe := SafeAreaContainer.new()
	safe.min_margin = 28
	add_child(safe)
	var row := UIUtil.hbox(0)
	safe.add_child(row)
	row.add_child(UIUtil.spacer())
	_menu_column = UIUtil.vbox(14)
	_menu_column.custom_minimum_size = Vector2(460, 0)
	_menu_column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_menu_column)

	var title := UIUtil.label("Digimon\nAdventure", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("line_spacing", -10)
	_menu_column.add_child(title)
	var subtitle := UIUtil.label("RPG PROTOTYPE", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_menu_column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	_menu_column.add_child(gap)

	_continue_button = _menu_button("Continue", &"PrimaryButton", _on_continue)
	_menu_button("New Game", &"AccentButton" if SaveManager.has_any_save() else &"PrimaryButton", _on_new_game)
	_load_button = _menu_button("Load Game", &"", _on_load)
	_menu_button("Settings", &"", _on_settings)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_menu_button("Quit", &"GhostButton", _on_quit)

	var footer := UIUtil.label(L10n.t("v%s · Private prototype · Original placeholder art & audio") % ProjectSettings.get_setting("application/config/version", "0.1"),
		&"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_column.add_child(footer)
	_refresh_save_buttons()

	AudioManager.play_music(&"title")
	await get_tree().process_frame
	for child in _menu_column.get_children():
		if child is Control:
			(child as Control).modulate.a = 0.0
	var tween := create_tween()
	for child in _menu_column.get_children():
		if child is Control:
			tween.tween_property(child, "modulate:a", 1.0, 0.12)


func _menu_button(text: String, variation: StringName, callback: Callable) -> Button:
	var b := UIUtil.button(text, variation, Vector2(0, 70))
	b.pressed.connect(callback)
	_menu_column.add_child(b)
	return b


func _build_showcase() -> Node3D:
	var group := Node3D.new()
	var roster: StarterRoster = GameData.starter_roster
	var ids: Array = roster.starter_ids if roster else []
	var spots := [Vector3(0, 0, 0.6), Vector3(-1.25, 0, -0.35), Vector3(1.25, 0, -0.35)]
	for i in mini(ids.size(), spots.size()):
		var visual := DigimonVisual.new()
		group.add_child(visual)
		visual.set_species(ids[i])
		visual.position = spots[i]
		visual.rotation.y = -spots[i].x * 0.3
	return group


func _refresh_save_buttons() -> void:
	var latest := SaveManager.get_latest_slot()
	_continue_button.visible = latest != -1
	_load_button.disabled = not SaveManager.has_any_save()


func _on_continue() -> void:
	var slot := SaveManager.get_latest_slot()
	if slot == -1:
		return
	if SaveManager.load_game(slot):
		AudioManager.play_ui(&"ui_confirm")
		SceneManager.goto_map(GameState.world.current_map_id, GameState.world.spawn_id)
	else:
		EventBus.toast(SaveManager.last_error, &"warning")
		_refresh_save_buttons()


func _on_new_game() -> void:
	AudioManager.play_ui(&"ui_confirm")
	GameState.reset()
	var draft := NewGameDraft.new()
	SceneManager.goto_scene(&"character_creation", {"draft": draft})


func _on_load() -> void:
	var panel := SaveLoadPanel.create(&"load")
	var sheet := OverlaySheet.open(self, "Load Game", panel)
	sheet.closed.connect(_refresh_save_buttons)


func _on_settings() -> void:
	OverlaySheet.open(self, "Settings", SettingsPanel.new())


func _on_quit() -> void:
	var ok := await ModalDialog.confirm(self, "Quit Game?", "See you next time, Tamer!", "Quit", "Stay")
	if ok:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_quit()
