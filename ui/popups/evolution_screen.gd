class_name EvolutionScreen
extends CanvasLayer
## Evolution cutscene: the Digimon glows, flickers between forms, flashes and
## reveals its new species with a stat comparison. Applies the evolution via
## EvolutionService (data-driven requirements, item consumption, autosave).

signal done()

var _preview: Preview3D
var _visual: DigimonVisual
var _title: Label
var _stats_box: VBoxContainer
var _flash: ColorRect
var _continue: Button


static func play(parent: Node, inst: DigimonInstance, path: EvolutionPath) -> void:
	var screen := EvolutionScreen.new()
	parent.add_child(screen)
	await screen._run(inst, path)
	screen.queue_free()


func _run(inst: DigimonInstance, path: EvolutionPath) -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UIUtil.digital_background())
	_preview = Preview3D.new()
	_preview.anchor_left = 0.2
	_preview.anchor_right = 0.8
	_preview.anchor_bottom = 0.78
	_preview.auto_rotate_speed = 0.6
	root.add_child(_preview)
	_visual = DigimonVisual.new()
	_preview.set_subject(_visual)
	_visual.set_species(inst.species_id)
	_preview.frame_height(maxf(_visual.model_height, 1.4))

	var column := UIUtil.vbox(10)
	column.anchor_left = 0.15
	column.anchor_right = 0.85
	# Pinned to the bottom edge and growing upwards, so the Continue button
	# stays on screen however tall the stats get or however short the window.
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.offset_bottom = -24
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(column)
	_title = UIUtil.label(L10n.t("What? %s is evolving!") % inst.get_display_name(), &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_title)
	_stats_box = UIUtil.vbox(4)
	column.add_child(_stats_box)
	_continue = UIUtil.button("Continue", &"PrimaryButton", Vector2(260, 64))
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.visible = false
	column.add_child(_continue)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	AudioManager.play_sfx(&"evolve")
	var old_species := inst.get_species()
	var target := GameData.get_species(path.target_species_id)
	await get_tree().create_timer(0.8).timeout
	# Flicker between the two forms, speeding up.
	var delay := 0.35
	for i in 8:
		_visual.flash(Color(1, 1, 1), delay)
		_visual.set_species(target if i % 2 == 0 else old_species)
		await get_tree().create_timer(delay).timeout
		delay *= 0.8
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 1.0, 0.25)
	await tween.finished
	var result := EvolutionService.evolve(inst, path, GameState.make_evolution_context())
	_visual.set_species(inst.species_id)
	_preview.frame_height(maxf(_visual.model_height, 1.4))
	tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.6)
	if not result.get("ok", false):
		_title.text = L10n.t("Evolution failed: %s") % result.get("reason", "?")
	else:
		AudioManager.play_sfx(&"level_up")
		_visual.play_once(&"victory", &"idle")
		_title.text = L10n.t("Congratulations! It evolved into %s!") % target.display_name
		_show_stats(result)
		EventBus.digimon_evolved.emit(inst, result.from_species)
		GameState.roster.notify_changed()
		SaveManager.autosave("evolution", true)
	_continue.visible = true
	# Tapping anywhere also continues (in case the button is hidden by the host page).
	root.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
			_continue.pressed.emit())
	await _continue.pressed
	done.emit()


func _show_stats(result: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stats_box.add_child(grid)
	for stat in [DigimonStats.MAX_HP, DigimonStats.ATTACK, DigimonStats.DEFENSE, DigimonStats.SPECIAL_ATTACK, DigimonStats.SPECIAL_DEFENSE, DigimonStats.SPEED]:
		var cell := UIUtil.vbox(0)
		cell.add_child(UIUtil.label(DigimonStats.short_name(stat), &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
		var value := UIUtil.label("%d → %d" % [int(result.before[stat]), int(result.after[stat])], &"ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
		value.add_theme_color_override("font_color", UIPalette.SUCCESS if int(result.after[stat]) > int(result.before[stat]) else UIPalette.TEXT)
		cell.add_child(value)
		grid.add_child(cell)
	var learned: Array = []
	for skill_id in result.get("learned", []):
		var skill := GameData.get_skill(skill_id)
		if skill:
			learned.append(skill.display_name)
	if not learned.is_empty():
		var l := UIUtil.label(L10n.t("New skills: %s") % ", ".join(learned), &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_color", UIPalette.GOLD)
		_stats_box.add_child(l)
