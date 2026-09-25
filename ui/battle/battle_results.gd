class_name BattleResults
extends Control
## End-of-battle overlays: victory results (EXP bars, drops) and the
## recruitment offer. Each is an awaitable static helper.

signal closed(accepted: bool)

var _panel: PanelContainer


static func show_victory(parent: Node, title: String, summary: Dictionary) -> void:
	var view := BattleResults.new()
	parent.add_child(view)
	view._build_victory(title, summary)
	await view.closed
	view.queue_free()


## Returns true when the player welcomes the Digimon.
static func ask_recruit(parent: Node, inst: DigimonInstance, forced := false) -> bool:
	var view := BattleResults.new()
	parent.add_child(view)
	view._build_recruit(inst, forced)
	var accepted: bool = await view.closed
	view.queue_free()
	return accepted


func _frame(accent: Color, min_width := 700.0) -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(min_width, 0)
	var sb := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if sb:
		sb.border_color = accent
		sb.set_border_width_all(3)
		_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var box := UIUtil.vbox(12)
	_panel.add_child(box)
	return box


func _build_victory(title: String, summary: Dictionary) -> void:
	var box := _frame(UIPalette.GOLD)
	var header := UIUtil.label(title, &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	header.add_theme_font_size_override("font_size", 48)
	box.add_child(header)
	var bars: Array = []
	for entry in summary.get("exp_entries", []):
		var inst: DigimonInstance = entry.instance
		var row := UIUtil.hbox(12)
		box.add_child(row)
		var name_label := UIUtil.label(inst.get_display_name(), &"BoldLabel")
		name_label.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_label)
		var level_label := UIUtil.label("Lv %d" % int(entry.old_level), &"ValueLabel")
		level_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(level_label)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"EXPBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(260, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.step = 0.001
		bar.value = float(entry.old_progress)
		row.add_child(bar)
		var gain := UIUtil.label("+%d EXP%s" % [int(entry.amount), "" if entry.participated else " (shared)"], &"BoldLabel")
		gain.add_theme_color_override("font_color", UIPalette.CYAN)
		row.add_child(gain)
		bars.append({"bar": bar, "level_label": level_label, "entry": entry})
	var drops: Dictionary = summary.get("drops", {})
	if not drops.is_empty():
		var parts: Array = []
		for item_id in drops.keys():
			var item := GameData.get_item(StringName(item_id))
			parts.append("%s ×%d" % [item.display_name if item else String(item_id), int(drops[item_id])])
		var drop_label := UIUtil.label("Found: " + ", ".join(parts), &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		drop_label.add_theme_color_override("font_color", UIPalette.PINK)
		box.add_child(drop_label)
	var ok := UIUtil.button("Continue", &"PrimaryButton", Vector2(260, 64))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.disabled = true
	box.add_child(ok)
	ok.pressed.connect(func(): closed.emit(true))
	UIUtil.pop_in(_panel)
	# Animate EXP bars, looping once per level gained.
	for b in bars:
		var bar: ProgressBar = b.bar
		var entry: Dictionary = b.entry
		var level := int(entry.old_level)
		for up in entry.level_ups:
			var t := create_tween()
			t.tween_property(bar, "value", 1.0, 0.35)
			await t.finished
			level = int(up.level)
			(b.level_label as Label).text = "Lv %d" % level
			(b.level_label as Label).add_theme_color_override("font_color", UIPalette.GOLD)
			AudioManager.play_ui(&"level_up_blip")
			bar.value = 0.0
		var t2 := create_tween()
		t2.tween_property(bar, "value", Leveling.exp_progress(entry.instance), 0.4)
		await t2.finished
	ok.disabled = false


func _build_recruit(inst: DigimonInstance, forced: bool) -> void:
	var box := _frame(UIPalette.PINK, 640)
	var preview := Preview3D.new()
	preview.custom_minimum_size = Vector2(0, 240)
	box.add_child(preview)
	var visual := DigimonVisual.new()
	preview.set_subject(visual)
	visual.set_species(inst.species_id)
	preview.frame_height(visual.model_height)
	visual.play_animation(&"victory")
	var species := inst.get_species()
	var title := "%s joined your team!" % inst.get_display_name() if forced else "%s wants to join your team!" % inst.get_display_name()
	var header := UIUtil.label(title, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(header)
	if species:
		box.add_child(UIUtil.label("Lv %d · %s · %s · %s" % [inst.level, species.get_stage_name(), species.get_attribute_name(), species.digimon_type],
			&"DimLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var destination := "It will join your party." if GameState.roster.party.size() < DigimonRoster.MAX_PARTY else "Your party is full — it will wait in your Collection."
	if GameState.roster.is_full():
		destination = "Your Collection is full! Make room to recruit more Digimon."
	box.add_child(UIUtil.label(destination, &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIUtil.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	if not forced:
		var no := UIUtil.button("Not now", &"GhostButton", Vector2(200, 64))
		no.pressed.connect(func(): closed.emit(false))
		row.add_child(no)
	var yes := UIUtil.button("Welcome!" if not forced else "Great!", &"PrimaryButton", Vector2(240, 64))
	yes.disabled = GameState.roster.is_full()
	yes.pressed.connect(func(): closed.emit(true))
	row.add_child(yes)
	if GameState.roster.is_full() and forced:
		var close := UIUtil.button("OK", &"GhostButton", Vector2(200, 64))
		close.pressed.connect(func(): closed.emit(false))
		row.add_child(close)
	AudioManager.play_sfx(&"recruit")
	UIUtil.pop_in(_panel)
