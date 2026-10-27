class_name SkillTrainer
extends CanvasLayer
## The Skill Master: spend skill points (and gold) to raise skills up to five
## stars. Skills unlock by level; the eight bar slots are picked in the menu.

signal closed()

var is_open := false
var _root: Control
var _box: VBoxContainer
var _info: Label
var _gold: Label
var _scroll: TouchScroll


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
	_scroll = scroll
	_box = UIUtil.vbox(6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	Game.profile_changed.connect(_queue_rebuild)
	Game.gold_changed.connect(func(_g): _queue_rebuild())


func open_trainer() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rebuild()


func close_trainer() -> void:
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_box)
	get_tree().paused = false
	closed.emit()



## Several signals usually fire for one action (an upgrade changes the skill points and
## the gold, a sale the bag and the gold); rebuild once, at the end of the frame.
var _rebuild_queued := false


func _queue_rebuild() -> void:
	if not is_open or _rebuild_queued:
		return
	_rebuild_queued = true
	(func():
		_rebuild_queued = false
		if is_open:
			_rebuild()).call_deferred()

func _rebuild() -> void:
	_gold.text = "เหรียญ: %d" % int(Game.profile.gold)
	_info.text = "แต้มสกิลที่ใช้ได้: %d   (ดาวละ 1 แต้ม + เหรียญ, สูงสุด %d ดาว)\nทุกดาว: ดาเมจ +%d%%  รัศมี +%d%%  คูลดาวน์ -%d%%  ฮีล +%d%%  บัฟ +%d%%  มึน/ช้า/ยั่วยุ/ลดเกราะ/อ่อนแรง +%d%%  MP +%d%%  (ดาว 3 และ 5 เพิ่มเป้า/ลูกธนู)" % [
			int(Game.profile.skill_points), Game.MAX_SKILL_RANK, _pct(SkillRank.POWER_PER_STAR), _pct(SkillRank.RADIUS_PER_STAR),
			_pct(SkillRank.CD_PER_STAR), _pct(SkillRank.HEAL_PER_STAR), _pct(SkillRank.BUFF_PER_STAR), _pct(SkillRank.CONTROL_PER_STAR), _pct(SkillRank.MP_PER_STAR)]
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Upgrading rebuilds the list: keep the page where the player was.
	var keep_y := _scroll.retained_vertical_position() if is_instance_valid(_scroll) else 0
	UIUtil.clear(_box)
	for skill in Game.skill_pool():
		_box.add_child(_row(skill, false))
	for skill in Game.passive_pool():
		_box.add_child(_row(skill, true))
	if is_instance_valid(_scroll):
		_scroll.restore_vertical_position(keep_y)


static func _pct(value: float) -> int:
	return int(round(value * 100.0))


func _row(skill: Dictionary, passive: bool) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(12)
	panel.add_child(line)
	if not passive:
		line.add_child(SkillIcons.portrait(skill))
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
	var shown := maxi(rank, 1)
	var text := String(skill.desc) if passive else "%s  •  MP %d  •  คูลดาวน์ %.1f วิ" % [skill.desc, SkillRank.mp(skill, shown), SkillRank.cooldown(skill, shown)]
	var desc := UIUtil.label(text, &"SmallLabel")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)
	info.add_child(SkillRankTable.build(SkillRank.passive_table(skill) if passive else SkillRank.table(skill), rank))
	var cost := Game.skill_upgrade_cost(skill)
	var maxed := rank >= Game.MAX_SKILL_RANK
	var button := UIUtil.button("เต็มแล้ว" if maxed else ("ล็อก" if not unlocked else "อัป %d" % cost), &"PrimaryButton", Vector2(150, 56))
	button.disabled = not unlocked or maxed or int(Game.profile.skill_points) <= 0 or int(Game.profile.gold) < cost
	button.pressed.connect(func():
		if Game.upgrade_skill(skill):
			AudioManager.play_sfx(&"coin"))
	line.add_child(button)
	return panel
