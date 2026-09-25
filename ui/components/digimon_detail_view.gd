class_name DigimonDetailView
extends HBoxContainer
## Shared detail view for one owned Digimon: 3D preview, stage/attribute,
## level + EXP, stats, skills (tap to equip / unequip, max 4) and evolution
## paths with their requirements (Evolve button when ready).

signal changed()
signal evolve_requested(inst: DigimonInstance, path: EvolutionPath)

var instance: DigimonInstance
var _preview: Preview3D
var _visual: DigimonVisual
var _info: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_panel := UIUtil.panel(&"GlassPanel")
	preview_panel.custom_minimum_size = Vector2(210, 0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(preview_panel)
	_preview = Preview3D.new()
	preview_panel.add_child(_preview)
	_visual = DigimonVisual.new()
	_preview.set_subject(_visual)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_info = UIUtil.vbox(8)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_info)
	if instance:
		show_digimon(instance)


func show_digimon(inst: DigimonInstance) -> void:
	instance = inst
	if _info == null:
		return
	UIUtil.clear(_info)
	if inst == null:
		_visual.set_species(null)
		_info.add_child(UIUtil.label("Select a Digimon.", &"DimLabel"))
		return
	var species := inst.get_species()
	_visual.set_species(species)
	_preview.frame_height(_visual.model_height)

	_info.add_child(UIUtil.label(inst.get_display_name(), &"HeaderLabel"))
	if species:
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		_info.add_child(chips)
		chips.add_child(UIUtil.chip(species.get_stage_name(), UIPalette.stage_color(species.stage)))
		chips.add_child(UIUtil.chip(species.get_attribute_name(), UIPalette.attribute_color(species.attribute)))
		chips.add_child(UIUtil.chip(String(species.element).capitalize(), UIUtil.element_color(species.element)))
		chips.add_child(UIUtil.chip(species.digimon_type, UIPalette.TEXT_DIM))
		var meta := UIUtil.label("Friendship %d · Battles won %d" % [inst.friendship, inst.battles_won], &"SmallLabel")
		meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(meta)

	var level_row := UIUtil.hbox(10)
	_info.add_child(level_row)
	level_row.add_child(UIUtil.label("Lv %d" % inst.level, &"ValueLabel"))
	var exp_bar := ProgressBar.new()
	exp_bar.theme_type_variation = &"EXPBar"
	exp_bar.show_percentage = false
	exp_bar.custom_minimum_size = Vector2(0, 12)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIUtil.set_bar(exp_bar, inst.experience, Leveling.exp_to_next(inst.level))
	level_row.add_child(exp_bar)
	_info.add_child(UIUtil.label("%d / %d EXP to next level" % [inst.experience, Leveling.exp_to_next(inst.level)], &"SmallLabel"))

	var vitals := GridContainer.new()
	vitals.columns = 2
	vitals.add_theme_constant_override("h_separation", 12)
	_info.add_child(vitals)
	vitals.add_child(UIUtil.label("HP %d/%d" % [inst.current_hp, inst.get_max_hp()], &"BoldLabel"))
	vitals.add_child(UIUtil.label("SP %d/%d" % [inst.current_sp, inst.get_max_sp()], &"BoldLabel"))

	_info.add_child(UIUtil.label("Stats", &"SubHeaderLabel"))
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 18)
	_info.add_child(stats)
	for stat in [DigimonStats.ATTACK, DigimonStats.DEFENSE, DigimonStats.SPEED, DigimonStats.SPECIAL_ATTACK, DigimonStats.SPECIAL_DEFENSE, DigimonStats.MAX_SP]:
		var cell := UIUtil.hbox(6)
		cell.add_child(UIUtil.label(DigimonStats.short_name(stat), &"SmallLabel"))
		cell.add_child(UIUtil.label(str(inst.get_stat(stat)), &"ValueLabel"))
		stats.add_child(cell)

	_info.add_child(UIUtil.label("Skills (tap to equip · max %d)" % DigimonInstance.MAX_EQUIPPED_SKILLS, &"SubHeaderLabel"))
	var skills := UIUtil.vbox(6)
	_info.add_child(skills)
	for skill_id in inst.known_skills:
		var skill := GameData.get_skill(skill_id)
		if skill == null:
			continue
		var equipped := inst.equipped_skills.has(skill_id)
		var b := UIUtil.button("%s%s  ·  %s %d · %d SP" % ["✓ " if equipped else "", skill.display_name, String(skill.element).capitalize(),
			skill.power, skill.sp_cost], &"ChoiceButton", Vector2(0, 52))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = equipped
		b.tooltip_text = skill.description
		b.pressed.connect(func():
			if not inst.set_skill_equipped(skill_id, not inst.equipped_skills.has(skill_id)):
				EventBus.toast("Keep between 1 and %d skills equipped." % DigimonInstance.MAX_EQUIPPED_SKILLS, &"warning")
			show_digimon(inst)
			changed.emit())
		skills.add_child(b)

	_info.add_child(UIUtil.label("Evolution", &"SubHeaderLabel"))
	var statuses := EvolutionService.get_paths_status(inst, GameState.make_evolution_context())
	if statuses.is_empty():
		_info.add_child(UIUtil.label("No known evolutions yet.", &"DimLabel"))
	for status in statuses:
		var target: DigimonSpecies = status.target
		var path: EvolutionPath = status.path
		var row := UIUtil.hbox(10)
		_info.add_child(row)
		var desc := UIUtil.label("→ %s (%s): %s" % [target.display_name, target.get_stage_name(),
			", ".join(EvolutionService.describe_requirements(path))], &"BoldLabel" if status.ready else &"DimLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		if status.ready:
			var evolve := UIUtil.button("Evolve", &"PrimaryButton", Vector2(150, 56))
			evolve.pressed.connect(func(): evolve_requested.emit(inst, path))
			row.add_child(evolve)
	if species and species.description != "":
		var d := UIUtil.label(species.description, &"SmallLabel")
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info.add_child(d)
