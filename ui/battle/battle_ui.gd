class_name BattleUI
extends CanvasLayer
## Battle interface: combatant panels, message box and command menus.
## It only *displays* state and *emits* commands; rules stay in BattleController.

signal command_chosen(command: Dictionary)
signal switch_chosen(index: int)

const MESSAGE_CPS := 60.0

var controller: BattleController

var _root: Control
var _player_name: Label
var _player_level: Label
var _player_hp: ProgressBar
var _player_hp_label: Label
var _player_sp: ProgressBar
var _player_sp_label: Label
var _player_status: HBoxContainer
var _player_attr: HBoxContainer
var _enemy_name: Label
var _enemy_level: Label
var _enemy_hp: ProgressBar
var _enemy_hp_label: Label
var _enemy_status: HBoxContainer
var _enemy_attr: HBoxContainer
var _message: RichTextLabel
var _message_panel: PanelContainer
var _commands: PanelContainer
var _command_box: VBoxContainer
var _typing: Tween
var _tapped := false


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_build_player_panel(frame)
	_build_enemy_panel(frame)
	_build_bottom(frame)
	hide_menus()


func setup(p_controller: BattleController) -> void:
	controller = p_controller
	refresh_all()


func refresh_all() -> void:
	if controller == null:
		return
	var p := controller.player
	_player_name.text = p.get_name()
	_player_level.text = "Lv %d" % p.get_level()
	_set_attribute(_player_attr, p.get_species())
	UIUtil.set_bar(_player_hp, p.instance.current_hp, p.instance.get_max_hp())
	UIUtil.tint_hp_bar(_player_hp, p.instance.get_hp_ratio())
	_player_hp_label.text = "%d / %d" % [p.instance.current_hp, p.instance.get_max_hp()]
	UIUtil.set_bar(_player_sp, p.instance.current_sp, p.instance.get_max_sp())
	_player_sp_label.text = "SP %d / %d" % [p.instance.current_sp, p.instance.get_max_sp()]
	_set_status(_player_status, p.status_id)
	var e := controller.enemy
	_enemy_name.text = e.get_battle_name()
	_enemy_level.text = "Lv %d" % e.get_level()
	_set_attribute(_enemy_attr, e.get_species())
	UIUtil.set_bar(_enemy_hp, e.instance.current_hp, e.instance.get_max_hp())
	UIUtil.tint_hp_bar(_enemy_hp, e.instance.get_hp_ratio())
	_enemy_hp_label.text = "%d%%" % int(round(e.instance.get_hp_ratio() * 100.0))
	_set_status(_enemy_status, e.status_id)


func animate_hp(side: int, hp: int, max_hp: int) -> void:
	var ratio := clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	if side == BattleCombatant.PLAYER_SIDE:
		UIUtil.set_bar(_player_hp, hp, max_hp, true, 0.45)
		UIUtil.tint_hp_bar(_player_hp, ratio)
		_player_hp_label.text = "%d / %d" % [hp, max_hp]
	else:
		UIUtil.set_bar(_enemy_hp, hp, max_hp, true, 0.45)
		UIUtil.tint_hp_bar(_enemy_hp, ratio)
		_enemy_hp_label.text = "%d%%" % int(round(ratio * 100.0))


func set_sp(side: int, sp: int, max_sp: int) -> void:
	if side == BattleCombatant.PLAYER_SIDE:
		UIUtil.set_bar(_player_sp, sp, max_sp, true, 0.3)
		_player_sp_label.text = "SP %d / %d" % [sp, max_sp]


func set_status(side: int, status_id: StringName) -> void:
	_set_status(_player_status if side == BattleCombatant.PLAYER_SIDE else _enemy_status, status_id)


## Shows a message with a typewriter effect and waits (tap to speed up).
func show_message(text: String, hold := 0.55) -> void:
	_message.text = text
	_message.visible_ratio = 0.0
	_tapped = false
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_message, "visible_ratio", 1.0, maxf(0.15, text.length() / MESSAGE_CPS))
	while _typing.is_running() and not _tapped:
		await get_tree().process_frame
	_message.visible_ratio = 1.0
	_tapped = false
	var waited := 0.0
	while waited < hold and not _tapped:
		await get_tree().process_frame
		waited += get_process_delta_time()


func set_prompt(text: String) -> void:
	_message.text = text
	_message.visible_ratio = 1.0


func hide_menus() -> void:
	_commands.visible = false


func show_main_menu() -> void:
	_show_commands()
	set_prompt("What will [b]%s[/b] do?" % TextVars.escape(controller.player.get_name()))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_command_box.add_child(grid)
	_menu_button(grid, "Skills", &"PrimaryButton", _show_skill_menu)
	_menu_button(grid, "Items", &"AccentButton", _show_item_menu)
	_menu_button(grid, "Defend", &"", func(): _choose({"type": "defend"}))
	var befriend := _menu_button(grid, "Befriend", &"", func(): _choose({"type": "befriend"}))
	if controller.request.is_wild and controller.request.can_befriend:
		var chance := RecruitmentService.befriend_chance(controller.enemy, controller.player, controller.recruit_config, controller.completed_quests)
		befriend.text = "Befriend %d%%" % int(round(chance * 100.0))
	else:
		befriend.disabled = true
	_menu_button(grid, "Party", &"", _show_party_menu.bind(false))
	var run := _menu_button(grid, "Run", &"GhostButton", func(): _choose({"type": "escape"}))
	run.disabled = not controller.request.can_escape


func show_forced_switch() -> void:
	_show_party_menu(true)


func _show_skill_menu() -> void:
	_show_commands()
	var options := controller.get_skill_options()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_command_box.add_child(grid)
	var any_usable := false
	for option in options:
		var skill: SkillData = option.skill
		var b := UIUtil.button("%s\n%s · Pow %d · %d SP" % [skill.display_name, String(skill.element).capitalize(), skill.power, skill.sp_cost],
			&"ChoiceButton", Vector2(0, 66))
		if skill.power <= 0:
			b.text = "%s\n%s · %d SP" % [skill.display_name, skill.get_category_name(), skill.sp_cost]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = not option.usable
		b.tooltip_text = skill.description
		_tint_button(b, UIUtil.element_color(skill.element))
		b.pressed.connect(func(): _choose({"type": "skill", "skill_id": skill.id}))
		grid.add_child(b)
		any_usable = any_usable or option.usable
	if not any_usable:
		var struggle := UIUtil.button("Desperate Tackle\n(no SP left)", &"DangerButton", Vector2(0, 66))
		struggle.pressed.connect(func(): _choose({"type": "struggle"}))
		grid.add_child(struggle)
	set_prompt("Choose a skill. Skills cost SP — Defend restores some.")
	_back_button(show_main_menu)


func _show_item_menu() -> void:
	_show_commands()
	var entries := GameState.inventory.get_usable_entries(true)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_command_box.add_child(scroll)
	var list := UIUtil.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if entries.is_empty():
		list.add_child(UIUtil.label("No usable items.", &"DimLabel"))
	for entry in entries:
		var item: ItemData = entry.item
		var b := UIUtil.button("%s ×%d" % [item.display_name, int(entry.quantity)], &"ChoiceButton", Vector2(0, 56))
		b.icon = item.get_icon()
		b.add_theme_constant_override("icon_max_width", 36)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _on_item_selected(item))
		list.add_child(b)
	set_prompt("Choose an item.")
	_back_button(show_main_menu)


func _on_item_selected(item: ItemData) -> void:
	if item.use_effect == ItemData.UseEffect.BEFRIEND_BOOST:
		_choose({"type": "item", "item_id": item.id})
		return
	_show_commands()
	set_prompt("Use %s on…" % item.display_name)
	var list := UIUtil.vbox(8)
	_command_box.add_child(list)
	for inst in controller.party:
		var reason := ItemService.get_block_reason(item, inst, true)
		var b := UIUtil.button("%s  Lv %d  ·  HP %d/%d  ·  SP %d/%d" % [inst.get_display_name(), inst.level, inst.current_hp,
			inst.get_max_hp(), inst.current_sp, inst.get_max_sp()], &"ChoiceButton", Vector2(0, 52))
		b.disabled = reason != ""
		b.pressed.connect(func(): _choose({"type": "item", "item_id": item.id, "target_uid": inst.uid}))
		list.add_child(b)
	_back_button(_show_item_menu)


func _show_party_menu(forced: bool) -> void:
	_show_commands()
	set_prompt("Choose your next Digimon!" if forced else "Switch to which Digimon?")
	var list := UIUtil.vbox(8)
	_command_box.add_child(list)
	for i in controller.party.size():
		var inst := controller.party[i]
		var active := inst == controller.player.instance
		var b := UIUtil.button("%s  Lv %d  ·  HP %d/%d%s" % [inst.get_display_name(), inst.level, inst.current_hp, inst.get_max_hp(),
			"  (in battle)" if active else ("  (fainted)" if inst.is_fainted() else "")], &"ChoiceButton", Vector2(0, 54))
		b.disabled = active or inst.is_fainted()
		b.pressed.connect(func():
			hide_menus()
			if forced:
				switch_chosen.emit(i)
			else:
				command_chosen.emit({"type": "switch", "index": i}))
		list.add_child(b)
	if not forced:
		_back_button(show_main_menu)


func _choose(command: Dictionary) -> void:
	hide_menus()
	command_chosen.emit(command)


func _show_commands() -> void:
	UIUtil.clear(_command_box)
	_commands.visible = true


func _menu_button(parent: Control, text: String, variation: StringName, callback: Callable) -> Button:
	var b := UIUtil.button(text, variation, Vector2(0, 64))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _back_button(callback: Callable) -> void:
	var b := UIUtil.button("Back", &"GhostButton", Vector2(0, 52))
	b.pressed.connect(func():
		AudioManager.play_ui(&"ui_cancel")
		callback.call())
	_command_box.add_child(b)


func _tint_button(button: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if sb:
			sb.border_color = Color(color.r, color.g, color.b, 0.9 if state != "disabled" else 0.3)
			sb.set_border_width_all(3)
			sb.border_width_left = 10
			button.add_theme_stylebox_override(state, sb)


func _set_attribute(box: HBoxContainer, species: DigimonSpecies) -> void:
	UIUtil.clear(box)
	if species:
		box.add_child(UIUtil.chip(species.get_attribute_name(), UIPalette.attribute_color(species.attribute), 14))
		box.add_child(UIUtil.chip(String(species.element).capitalize(), UIUtil.element_color(species.element), 14))


func _set_status(box: HBoxContainer, status_id: StringName) -> void:
	UIUtil.clear(box)
	if status_id != &"":
		box.add_child(UIUtil.chip(StatusEffects.get_display_name(status_id), StatusEffects.get_color(status_id), 14))


func _build_player_panel(frame: Control) -> void:
	var panel := UIUtil.panel(&"HudPanel")
	panel.custom_minimum_size = Vector2(380, 0)
	frame.add_child(panel)
	var box := UIUtil.vbox(4)
	panel.add_child(box)
	var row := UIUtil.hbox(8)
	box.add_child(row)
	_player_name = UIUtil.label("", &"HudLabel")
	_player_name.add_theme_font_size_override("font_size", 24)
	_player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_player_name)
	_player_level = UIUtil.label("", &"ValueLabel")
	_player_level.add_theme_color_override("font_color", UIPalette.GOLD)
	row.add_child(_player_level)
	var chips := UIUtil.hbox(6)
	box.add_child(chips)
	_player_attr = UIUtil.hbox(6)
	chips.add_child(_player_attr)
	_player_status = UIUtil.hbox(6)
	chips.add_child(_player_status)
	var hp_row := UIUtil.hbox(8)
	box.add_child(hp_row)
	hp_row.add_child(UIUtil.label("HP", &"SmallLabel"))
	_player_hp = _bar(&"HPBar", 16)
	hp_row.add_child(_player_hp)
	_player_hp_label = UIUtil.label("", &"ValueLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_player_hp_label.custom_minimum_size = Vector2(96, 0)
	hp_row.add_child(_player_hp_label)
	var sp_row := UIUtil.hbox(8)
	box.add_child(sp_row)
	_player_sp = _bar(&"SPBar", 10)
	sp_row.add_child(_player_sp)
	_player_sp_label = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_player_sp_label.custom_minimum_size = Vector2(96, 0)
	sp_row.add_child(_player_sp_label)


func _build_enemy_panel(frame: Control) -> void:
	var panel := UIUtil.panel(&"HudPanel")
	panel.custom_minimum_size = Vector2(380, 0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -380
	frame.add_child(panel)
	var box := UIUtil.vbox(4)
	panel.add_child(box)
	var row := UIUtil.hbox(8)
	box.add_child(row)
	_enemy_name = UIUtil.label("", &"HudLabel")
	_enemy_name.add_theme_font_size_override("font_size", 24)
	_enemy_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_enemy_name)
	_enemy_level = UIUtil.label("", &"ValueLabel")
	_enemy_level.add_theme_color_override("font_color", UIPalette.GOLD)
	row.add_child(_enemy_level)
	var chips := UIUtil.hbox(6)
	box.add_child(chips)
	_enemy_attr = UIUtil.hbox(6)
	chips.add_child(_enemy_attr)
	_enemy_status = UIUtil.hbox(6)
	chips.add_child(_enemy_status)
	var hp_row := UIUtil.hbox(8)
	box.add_child(hp_row)
	hp_row.add_child(UIUtil.label("HP", &"SmallLabel"))
	_enemy_hp = _bar(&"HPBar", 16)
	hp_row.add_child(_enemy_hp)
	_enemy_hp_label = UIUtil.label("", &"ValueLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	_enemy_hp_label.custom_minimum_size = Vector2(64, 0)
	hp_row.add_child(_enemy_hp_label)


func _build_bottom(frame: Control) -> void:
	var bottom := UIUtil.hbox(12)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.anchor_top = 1.0
	bottom.anchor_right = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -236
	bottom.alignment = BoxContainer.ALIGNMENT_END
	frame.add_child(bottom)
	_message_panel = UIUtil.panel(&"DialoguePanel")
	_message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_message_panel.custom_minimum_size = Vector2(0, 120)
	_message_panel.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_tapped = true)
	bottom.add_child(_message_panel)
	_message = RichTextLabel.new()
	_message.bbcode_enabled = true
	_message.fit_content = true
	_message.scroll_active = false
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_font_size_override("normal_font_size", 25)
	_message.add_theme_font_size_override("bold_font_size", 25)
	_message_panel.add_child(_message)
	_commands = UIUtil.panel()
	_commands.custom_minimum_size = Vector2(560, 0)
	_commands.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(_commands)
	_command_box = UIUtil.vbox(10)
	_commands.add_child(_command_box)


func _bar(variation: StringName, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = variation
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_tapped = true
