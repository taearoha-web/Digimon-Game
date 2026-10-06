class_name SkillTrainer
extends CanvasLayer
## The Skill Master: spend skill points (and gold) to raise skills up to five
## stars. Skills unlock by level; which four go on the bar is picked in the menu.

signal closed()

var is_open := false
var _root: Control
var _box: VBoxContainer
var _info: Label
var _gold: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 12
	panel.offset_right = -16
	panel.offset_bottom = -12
	frame.add_child(panel)
	var column := UIUtil.vbox(10)
	panel.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("ฝึกสกิล", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold = UIUtil.label("", &"SubHeaderLabel")
	_gold.add_theme_color_override("font_color", UIPalette.GOLD)
	head.add_child(_gold)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_trainer)
	head.add_child(close)
	_info = UIUtil.label("", &"SubHeaderLabel")
	column.add_child(_info)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_box = UIUtil.vbox(6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	Game.profile_changed.connect(func(): if is_open: _rebuild())
	Game.gold_changed.connect(func(_g): if is_open: _rebuild())


func open_trainer() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_trainer() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false
	closed.emit()


func _rebuild() -> void:
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	_info.text = "แต้มสกิลที่ใช้ได้: %d   (ดาวละ 1 แต้ม + เหรียญ, สูงสุด %d ดาว: แรงขึ้น 15%% และวงกว้างขึ้น 8%% ต่อดาว)" % [int(Game.profile.skill_points), Game.MAX_SKILL_RANK]
	UIUtil.clear(_box)
	for skill in Game.skill_pool():
		_box.add_child(_row(skill, false))
	for skill in Game.passive_pool():
		_box.add_child(_row(skill, true))


func _row(skill: Dictionary, passive: bool) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(12)
	panel.add_child(line)
	var info := UIUtil.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var unlocked := Game.skill_unlocked(skill)
	var rank := Game.effective_rank(skill)
	var tag := "[ติดตัว] " if passive else ""
	var title_row := UIUtil.hbox(12)
	info.add_child(title_row)
	var title_label := UIUtil.label(tag + String(skill.name), &"BoldLabel")
	if not unlocked:
		title_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
	title_row.add_child(title_label)
	if unlocked:
		title_row.add_child(StarRow.new(rank, Game.MAX_SKILL_RANK, 20.0))
	else:
		var lock := UIUtil.label(Game.skill_lock_reason(skill), &"SmallLabel")
		title_row.add_child(lock)
	var text := String(skill.desc) if passive else "%s  •  MP %d  •  คูลดาวน์ %.0f วิ" % [skill.desc, int(skill.mp), float(skill.cd)]
	if not passive and String(skill.shape) in ["burst", "blast"]:
		text += "  •  รัศมี %.1f (ดาวละ +%d%%)" % [float(skill.radius) * Game.radius_scale(rank), int(Game.RADIUS_PER_STAR * 100.0)]
	var desc := UIUtil.label(text, &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	var cost := Game.skill_upgrade_cost(skill)
	var maxed := rank >= Game.MAX_SKILL_RANK
	var button := UIUtil.button("เต็มแล้ว" if maxed else ("ล็อก" if not unlocked else "อัป %d" % cost), &"PrimaryButton", Vector2(150, 56))
	button.disabled = not unlocked or maxed or int(Game.profile.skill_points) <= 0 or int(Game.profile.gold) < cost
	button.pressed.connect(func():
		if Game.upgrade_skill(skill):
			AudioManager.play_sfx(&"coin"))
	line.add_child(button)
	return panel
