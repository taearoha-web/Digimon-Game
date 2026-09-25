class_name PartyPanel
extends HBoxContainer
## Party management: select, reorder (slot 1 = partner that follows you),
## view stats/skills, evolve, and move members to storage.

var _slots: VBoxContainer
var _detail: DigimonDetailView
var _selected_uid := ""


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UIUtil.vbox(10)
	left.custom_minimum_size = Vector2(290, 0)
	add_child(left)
	left.add_child(UIUtil.label("Active Party", &"SubHeaderLabel"))
	_slots = UIUtil.vbox(10)
	left.add_child(_slots)
	left.add_child(UIUtil.spacer(false))
	var hint := UIUtil.label("Slot 1 is your partner in the field and leads in battle.", &"SmallLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	_detail = DigimonDetailView.new()
	add_child(_detail)
	_detail.changed.connect(refresh)
	_detail.evolve_requested.connect(_on_evolve)
	var party := GameState.roster.get_party()
	if not party.is_empty():
		_selected_uid = party[0].uid
	refresh()


func refresh() -> void:
	UIUtil.clear(_slots)
	var party := GameState.roster.get_party()
	for i in party.size():
		_slots.add_child(_slot_card(i, party[i], party.size()))
	for i in range(party.size(), DigimonRoster.MAX_PARTY):
		var empty := UIUtil.panel(&"GlassPanel")
		empty.custom_minimum_size = Vector2(0, 92)
		empty.add_child(UIUtil.label("Empty slot — add Digimon from the Collection", &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
		_slots.add_child(empty)
	_detail.show_digimon(GameState.roster.get_digimon(_selected_uid))


func _slot_card(index: int, inst: DigimonInstance, party_size: int) -> Control:
	var card := UIUtil.panel(&"CardPanelSelected" if inst.uid == _selected_uid else &"CardPanel")
	var row := UIUtil.hbox(10)
	card.add_child(row)
	var info := UIUtil.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := UIUtil.hbox(8)
	info.add_child(title)
	title.add_child(UIUtil.label("%d." % (index + 1), &"ValueLabel"))
	var name_label := UIUtil.label(inst.get_display_name(), &"BoldLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	title.add_child(UIUtil.label("Lv %d" % inst.level, &"ValueLabel"))
	var hp := ProgressBar.new()
	hp.theme_type_variation = &"HPBar"
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 12)
	UIUtil.set_bar(hp, inst.current_hp, inst.get_max_hp())
	UIUtil.tint_hp_bar(hp, inst.get_hp_ratio())
	info.add_child(hp)
	info.add_child(UIUtil.label("HP %d/%d · SP %d/%d%s" % [inst.current_hp, inst.get_max_hp(), inst.current_sp, inst.get_max_sp(),
		"  · Fainted" if inst.is_fainted() else ""], &"SmallLabel"))
	var arrows := UIUtil.vbox(4)
	row.add_child(arrows)
	var up := UIUtil.icon_button("res://assets/icons/ui/arrow_up.svg", Vector2(48, 40), &"ChoiceButton")
	up.disabled = index == 0
	up.pressed.connect(func(): _move(index, index - 1))
	arrows.add_child(up)
	var down := UIUtil.icon_button("res://assets/icons/ui/arrow_down.svg", Vector2(48, 40), &"ChoiceButton")
	down.disabled = index >= party_size - 1
	down.pressed.connect(func(): _move(index, index + 1))
	arrows.add_child(down)
	card.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
			_selected_uid = inst.uid
			AudioManager.play_ui(&"ui_select")
			refresh())
	return card


func _move(from: int, to: int) -> void:
	if GameState.roster.move_party_member(from, to):
		AudioManager.play_ui(&"ui_confirm")
		if to == 0:
			EventBus.toast("%s is now your partner!" % GameState.roster.get_lead().get_display_name(), &"success")
	refresh()


func _on_evolve(inst: DigimonInstance, path: EvolutionPath) -> void:
	await EvolutionScreen.play(self, inst, path)
	refresh()
