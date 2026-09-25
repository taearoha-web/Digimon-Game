class_name PopupQueue
extends CanvasLayer
## Shows reward / level-up / evolution popups one after another. The game is
## paused while a popup is visible so nothing happens behind it.

signal queue_finished()

## Jobs: { "kind": StringName, "args": Array }
var _queue: Array[Dictionary] = []
var _busy := false
var _root: Control
var _was_paused := false


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


func is_busy() -> bool:
	return _busy or not _queue.is_empty()


func show_quest_rewards(rewards: Dictionary) -> void:
	if rewards.is_empty():
		return
	_enqueue(&"quest", [rewards])
	show_level_ups(rewards.get("level_ups", []))


## entries: [{ "instance": DigimonInstance, "ups": Array[Dictionary] }]
func show_level_ups(entries: Array) -> void:
	for entry in entries:
		var inst: DigimonInstance = entry.instance
		var ups: Array = entry.ups
		if ups.is_empty():
			continue
		_enqueue(&"level_up", [inst, ups])
		_enqueue(&"evolution", [inst])


func show_message(title: String, body: String) -> void:
	_enqueue(&"message", [title, body])


func check_evolution(inst: DigimonInstance) -> void:
	_enqueue(&"evolution", [inst])


## Waits until every queued popup has been closed.
func wait_until_idle() -> void:
	if is_busy():
		await queue_finished


func _enqueue(kind: StringName, args: Array) -> void:
	_queue.append({"kind": kind, "args": args})
	if not _busy:
		_run.call_deferred()


func _run() -> void:
	if _busy:
		return
	_busy = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var args: Array = job.args
		match job.kind:
			&"quest":
				await _quest_popup(args[0])
			&"level_up":
				await _level_up_popup(args[0], args[1])
			&"evolution":
				await _evolution_check(args[0])
			&"message":
				await _message_popup(args[0], args[1])
	get_tree().paused = _was_paused
	_busy = false
	queue_finished.emit()


# ---------------------------------------------------------------------------
# Popup builders (each awaits its own close)
# ---------------------------------------------------------------------------

func _frame(title: String, accent: Color) -> Dictionary:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb:
		sb.border_color = accent
		sb.set_border_width_all(3)
		panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := UIUtil.vbox(12)
	panel.add_child(box)
	var header := UIUtil.label(title, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	header.add_theme_color_override("font_color", accent.lightened(0.3))
	box.add_child(header)
	return {"overlay": overlay, "panel": panel, "box": box}


func _close_button(box: VBoxContainer, text := "OK") -> Button:
	var b := UIUtil.button(text, &"PrimaryButton", Vector2(240, 64))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(b)
	return b


func _quest_popup(rewards: Dictionary) -> void:
	AudioManager.play_sfx(&"quest_complete")
	var f := _frame("Quest Complete!", UIPalette.GOLD)
	var box: VBoxContainer = f.box
	box.add_child(UIUtil.label(str(rewards.get("title", "")), &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var list := UIUtil.vbox(6)
	box.add_child(list)
	if int(rewards.get("exp", 0)) > 0:
		list.add_child(_reward_row(null, L10n.t("+%d EXP for every party member") % int(rewards.exp)))
	if int(rewards.get("currency", 0)) > 0:
		list.add_child(_reward_row(load("res://assets/icons/ui/coin.svg"), L10n.t("+%d Data Coins") % int(rewards.currency)))
	var items: Dictionary = rewards.get("items", {})
	for item_id in items.keys():
		var item := GameData.get_item(StringName(item_id))
		if item:
			list.add_child(_reward_row(item.get_icon(), L10n.t("%s ×%d") % [item.display_name, int(items[item_id])]))
	UIUtil.pop_in(f.panel)
	await _close_button(box).pressed
	f.overlay.queue_free()


func _reward_row(icon: Texture2D, text: String) -> Control:
	var row := UIUtil.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon:
		row.add_child(UIUtil.texture_rect(icon, Vector2(40, 40)))
	else:
		row.add_child(UIUtil.chip("EXP", UIPalette.CYAN))
	row.add_child(UIUtil.label(text, &"BoldLabel"))
	return row


func _level_up_popup(inst: DigimonInstance, ups: Array) -> void:
	AudioManager.play_sfx(&"level_up")
	var last: Dictionary = ups.back()
	var first: Dictionary = ups.front()
	var f := _frame("Level Up!", UIPalette.CYAN)
	var box: VBoxContainer = f.box
	box.add_child(UIUtil.label(L10n.t("%s reached Lv %d!") % [inst.get_display_name(), int(last.level)], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for stat in DigimonStats.ALL:
		var before := int(first.before[stat])
		var after := int(last.after[stat])
		grid.add_child(UIUtil.label(DigimonStats.display_name(stat), &"DimLabel"))
		grid.add_child(UIUtil.label(str(before), &"ValueLabel", HORIZONTAL_ALIGNMENT_RIGHT))
		grid.add_child(UIUtil.label("→ %d" % after, &"ValueLabel"))
		var gain := UIUtil.label("+%d" % (after - before), &"BoldLabel")
		gain.add_theme_color_override("font_color", UIPalette.SUCCESS)
		grid.add_child(gain)
	var learned: Array = []
	for up in ups:
		for skill_id in up.learned:
			var skill := GameData.get_skill(skill_id)
			if skill:
				learned.append(skill.display_name)
	if not learned.is_empty():
		var l := UIUtil.label(L10n.t("New skill learned: %s!") % ", ".join(learned), &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_color", UIPalette.GOLD)
		box.add_child(l)
		AudioManager.play_ui(&"skill_learned")
	UIUtil.pop_in(f.panel)
	await _close_button(box).pressed
	f.overlay.queue_free()


func _evolution_check(inst: DigimonInstance) -> void:
	var ready := EvolutionService.get_ready_paths(inst, GameState.make_evolution_context())
	if ready.is_empty():
		return
	var path: EvolutionPath = ready[0]
	var target := GameData.get_species(path.target_species_id)
	if target == null:
		return
	AudioManager.play_ui(&"evolve_ready")
	var f := _frame("Evolution!", UIPalette.ORANGE)
	var box: VBoxContainer = f.box
	var text := UIUtil.label(L10n.t("%s is ready to evolve into %s!") % [inst.get_display_name(), target.display_name], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	if path.required_item_id != &"":
		var item := GameData.get_item(path.required_item_id)
		box.add_child(UIUtil.label(L10n.t("Uses: %s") % (item.display_name if item else String(path.required_item_id)), &"DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIUtil.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var later := UIUtil.button("Later", &"GhostButton", Vector2(200, 64))
	row.add_child(later)
	var evolve := UIUtil.button("Evolve!", &"PrimaryButton", Vector2(240, 64))
	row.add_child(evolve)
	UIUtil.pop_in(f.panel)
	var choice := [false]
	var done := [false]
	later.pressed.connect(func(): done[0] = true)
	evolve.pressed.connect(func():
		choice[0] = true
		done[0] = true)
	while not done[0]:
		await get_tree().process_frame
	f.overlay.queue_free()
	if choice[0]:
		await EvolutionScreen.play(self, inst, path)


func _message_popup(title: String, body: String) -> void:
	var f := _frame(title, UIPalette.CYAN)
	var label := UIUtil.label(body, &"", HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(540, 0)
	f.box.add_child(label)
	UIUtil.pop_in(f.panel)
	await _close_button(f.box).pressed
	f.overlay.queue_free()
