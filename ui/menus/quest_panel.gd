class_name QuestPanel
extends HBoxContainer
## Quest log: list of known quests with state, objectives checklist and rewards.

var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: StringName = &""


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = UIUtil.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail_panel := UIUtil.panel(&"GlassPanel")
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detail_panel)
	_detail = UIUtil.vbox(10)
	detail_panel.add_child(_detail)
	var tracked := QuestManager.get_tracked_quest()
	if tracked:
		_selected = tracked.id
	refresh()


func refresh() -> void:
	UIUtil.clear(_list)
	var any := false
	for quest in GameData.get_all_quests():
		var state := QuestManager.get_state(quest.id)
		if state == QuestLog.State.LOCKED:
			continue
		any = true
		if _selected == &"":
			_selected = quest.id
		var b := UIUtil.button("%s   [%s]" % [quest.title, QuestLog.STATE_NAMES[state]], &"ChoiceButton", Vector2(0, 60))
		b.toggle_mode = true
		b.button_pressed = quest.id == _selected
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_selected = quest.id
			refresh())
		_list.add_child(b)
	if not any:
		_list.add_child(UIUtil.label("No quests yet. Talk to people!", &"DimLabel"))
	_show_detail()


func _show_detail() -> void:
	UIUtil.clear(_detail)
	var quest := GameData.get_quest(_selected)
	if quest == null:
		return
	var state := QuestManager.get_state(quest.id)
	var head := UIUtil.hbox(10)
	_detail.add_child(head)
	head.add_child(UIUtil.label(quest.title, &"HeaderLabel"))
	var color := UIPalette.SUCCESS if state >= QuestLog.State.COMPLETED else (UIPalette.GOLD if state == QuestLog.State.ACTIVE else UIPalette.CYAN)
	head.add_child(UIUtil.chip(QuestLog.STATE_NAMES[state], color))
	var summary := UIUtil.label(TextVars.format(quest.summary, {}, false), &"DimLabel")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(summary)
	var giver := GameData.get_npc(quest.giver_npc_id)
	if giver:
		_detail.add_child(UIUtil.label("From: %s (%s)" % [giver.display_name, giver.title], &"SmallLabel"))
	_detail.add_child(UIUtil.label("Objectives", &"SubHeaderLabel"))
	var step := GameState.quest_log.get_step(quest.id)
	for i in quest.objectives.size():
		var objective := quest.objectives[i]
		var done := state >= QuestLog.State.COMPLETED or (state == QuestLog.State.ACTIVE and i < step)
		var current := state == QuestLog.State.ACTIVE and i == step
		var row := UIUtil.hbox(10)
		row.add_child(UIUtil.texture_rect(load("res://assets/icons/ui/check.svg" if done else "res://assets/icons/ui/circle_empty.svg"), Vector2(28, 28)))
		var text := TextVars.format(objective.description, {}, false)
		if current and objective.required_count > 1:
			text += " (%d/%d)" % [GameState.quest_log.get_progress(quest.id), objective.required_count]
		var l := UIUtil.label(text, &"BoldLabel" if current else &"DimLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_detail.add_child(row)
	if quest.turn_in_npc_id != &"":
		var npc := GameData.get_npc(quest.turn_in_npc_id)
		var row := UIUtil.hbox(10)
		var turned_in := state == QuestLog.State.REWARDED
		row.add_child(UIUtil.texture_rect(load("res://assets/icons/ui/check.svg" if turned_in else "res://assets/icons/ui/circle_empty.svg"), Vector2(28, 28)))
		row.add_child(UIUtil.label("Report to %s" % (npc.display_name if npc else "?"), &"BoldLabel" if state == QuestLog.State.COMPLETED else &"DimLabel"))
		_detail.add_child(row)
	_detail.add_child(UIUtil.label("Rewards", &"SubHeaderLabel"))
	var rewards: Array = []
	if quest.reward_exp > 0:
		rewards.append("%d EXP" % quest.reward_exp)
	if quest.reward_currency > 0:
		rewards.append("%d Data Coins" % quest.reward_currency)
	for item_id in quest.reward_items.keys():
		var item := GameData.get_item(StringName(item_id))
		rewards.append("%s ×%d" % [item.display_name if item else String(item_id), int(quest.reward_items[item_id])])
	var reward_label := UIUtil.label(", ".join(rewards) if not rewards.is_empty() else "—", &"")
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(reward_label)
