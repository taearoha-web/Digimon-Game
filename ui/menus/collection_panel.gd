class_name CollectionPanel
extends HBoxContainer
## Digimon Collection: every owned Digimon (party + storage) with details and
## actions to add to / remove from the party.

var _grid: GridContainer
var _detail: DigimonDetailView
var _actions: HBoxContainer
var _count_label: Label
var _selected_uid := ""


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIUtil.vbox(10)
	left.custom_minimum_size = Vector2(300, 0)
	add_child(left)
	_count_label = UIUtil.label("", &"SubHeaderLabel")
	left.add_child(_count_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	var right := UIUtil.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	_detail = DigimonDetailView.new()
	right.add_child(_detail)
	_detail.changed.connect(refresh)
	_detail.evolve_requested.connect(_on_evolve)
	_actions = UIUtil.hbox(10)
	right.add_child(_actions)
	var all := GameState.roster.get_all()
	if not all.is_empty():
		_selected_uid = all[0].uid
	refresh()


func refresh() -> void:
	var roster := GameState.roster
	_count_label.text = L10n.t("Owned %d / %d") % [roster.size(), roster.capacity]
	UIUtil.clear(_grid)
	for inst in roster.get_all():
		_grid.add_child(_card(inst))
	var selected := roster.get_digimon(_selected_uid)
	_detail.show_digimon(selected)
	UIUtil.clear(_actions)
	if selected == null:
		return
	if roster.is_in_party(selected.uid):
		var to_storage := UIUtil.button("Move to Storage", &"GhostButton", Vector2(0, 60))
		to_storage.disabled = roster.party.size() <= 1
		to_storage.pressed.connect(func():
			roster.remove_from_party(selected.uid)
			refresh())
		_actions.add_child(to_storage)
		if roster.get_party_index(selected.uid) > 0:
			var lead := UIUtil.button("Make Partner", &"AccentButton", Vector2(0, 60))
			lead.pressed.connect(func():
				roster.set_lead(selected.uid)
				EventBus.toast(L10n.t("%s is now your partner!") % selected.get_display_name(), &"success")
				refresh())
			_actions.add_child(lead)
	else:
		if roster.party.size() < DigimonRoster.MAX_PARTY:
			var add := UIUtil.button("Add to Party", &"PrimaryButton", Vector2(0, 60))
			add.pressed.connect(func():
				roster.add_to_party(selected.uid)
				AudioManager.play_ui(&"ui_confirm")
				refresh())
			_actions.add_child(add)
		else:
			for member in roster.get_party():
				var swap := UIUtil.button(L10n.t("Swap with %s") % member.get_display_name(), &"ChoiceButton", Vector2(0, 60))
				swap.pressed.connect(func():
					roster.swap_with_storage(member.uid, selected.uid)
					AudioManager.play_ui(&"ui_confirm")
					refresh())
				_actions.add_child(swap)


func _card(inst: DigimonInstance) -> Control:
	var species := inst.get_species()
	var card := UIUtil.panel(&"CardPanelSelected" if inst.uid == _selected_uid else &"CardPanel")
	card.custom_minimum_size = Vector2(138, 0)
	var box := UIUtil.vbox(2)
	card.add_child(box)
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = species.get_color(0, UIPalette.CYAN) if species else UIPalette.CYAN
	sb.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(0, 8)
	box.add_child(badge)
	box.add_child(UIUtil.label(inst.get_display_name(), &"BoldLabel"))
	box.add_child(UIUtil.label(L10n.t("Lv %d · %s") % [inst.level, species.get_stage_name() if species else "?"], &"SmallLabel"))
	if GameState.roster.is_in_party(inst.uid):
		box.add_child(UIUtil.chip(L10n.t("Party %d") % (GameState.roster.get_party_index(inst.uid) + 1), UIPalette.GOLD, 14))
	card.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_selected_uid = inst.uid
			AudioManager.play_ui(&"ui_select")
			refresh())
	return card


func _on_evolve(inst: DigimonInstance, path: EvolutionPath) -> void:
	await EvolutionScreen.play(self, inst, path)
	refresh()
