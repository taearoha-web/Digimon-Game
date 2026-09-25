class_name SaveLoadPanel
extends ScrollContainer
## Save / Load slot list. mode = &"save" or &"load".

signal saved(slot: int)
signal loaded(slot: int)

var mode: StringName = &"load"
var _list: VBoxContainer


static func create(p_mode: StringName) -> SaveLoadPanel:
	var panel := SaveLoadPanel.new()
	panel.mode = p_mode
	return panel


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(820, 420)
	_list = UIUtil.vbox(12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	refresh()


func refresh() -> void:
	UIUtil.clear(_list)
	var first := SaveManager.AUTOSAVE_SLOT if mode == &"load" else 1
	for slot in range(first, SaveManager.SLOT_COUNT + 1):
		_list.add_child(_slot_row(slot))


func _slot_row(slot: int) -> Control:
	var info := SaveManager.get_slot_info(slot)
	var card := UIUtil.panel(&"CardPanel")
	var row := UIUtil.hbox(16)
	card.add_child(row)
	var text_box := UIUtil.vbox(2)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var title := "Autosave" if slot == SaveManager.AUTOSAVE_SLOT else L10n.t("Slot %d") % slot
	text_box.add_child(UIUtil.label(title, &"SubHeaderLabel"))
	if not info.exists:
		text_box.add_child(UIUtil.label("Empty", &"DimLabel"))
	elif info.corrupt:
		var bad := UIUtil.label("Save data is damaged and cannot be loaded.", &"DimLabel")
		bad.add_theme_color_override("font_color", UIPalette.DANGER)
		text_box.add_child(bad)
	else:
		text_box.add_child(UIUtil.label(L10n.t("%s  ·  %s Lv %d") % [info.get("player_name", "?"), info.get("lead_name", "?"), int(info.get("lead_level", 0))], &"BoldLabel"))
		text_box.add_child(UIUtil.label(L10n.t("%s  ·  Play time %s  ·  %s") % [info.get("map_name", "?"),
			UIUtil.format_play_time(float(info.get("play_time", 0))), UIUtil.format_date(int(info.saved_at))], &"SmallLabel"))

	if info.exists and (info.corrupt or slot != SaveManager.AUTOSAVE_SLOT):
		var delete := UIUtil.button("Delete", &"GhostButton", Vector2(120, 60))
		delete.pressed.connect(_on_delete.bind(slot))
		row.add_child(delete)
	if mode == &"save":
		if slot != SaveManager.AUTOSAVE_SLOT:
			var save := UIUtil.button("Save", &"PrimaryButton", Vector2(150, 60))
			save.pressed.connect(_on_save.bind(slot, info.exists and not info.corrupt))
			row.add_child(save)
	else:
		var load_button := UIUtil.button("Load", &"PrimaryButton", Vector2(150, 60))
		load_button.disabled = not info.exists or info.corrupt
		load_button.pressed.connect(_on_load.bind(slot))
		row.add_child(load_button)
	return card


func _on_save(slot: int, overwrite: bool) -> void:
	if overwrite:
		var ok := await ModalDialog.confirm(self, "Overwrite?", L10n.t("Replace the data in Slot %d?") % slot, "Overwrite", "Cancel")
		if not ok:
			return
	if SaveManager.save_game(slot):
		AudioManager.play_ui(&"save")
		EventBus.toast(L10n.t("Game saved to Slot %d.") % slot, &"success")
		saved.emit(slot)
	else:
		EventBus.toast(L10n.t("Save failed: %s") % SaveManager.last_error, &"warning")
	refresh()


func _on_load(slot: int) -> void:
	if GameState.is_game_active:
		var ok := await ModalDialog.confirm(self, "Load Game?", "Unsaved progress in the current game will be lost.", "Load", "Cancel")
		if not ok:
			return
	if SaveManager.load_game(slot):
		AudioManager.play_ui(&"ui_confirm")
		loaded.emit(slot)
		SceneManager.goto_map(GameState.world.current_map_id, GameState.world.spawn_id)
	else:
		EventBus.toast(SaveManager.last_error, &"warning")
		refresh()


func _on_delete(slot: int) -> void:
	var ok := await ModalDialog.confirm(self, "Delete Save?", "This cannot be undone.", "Delete", "Cancel", true)
	if ok:
		SaveManager.delete_slot(slot)
		EventBus.toast("Save deleted.", &"info")
		refresh()
