class_name PvpScreen
extends CanvasLayer
## The ranked-duel desk in the village: your rank, the ladder, the rules and
## the "challenge" button. The same screen shows the verdict after a duel.

signal challenge_requested()
signal go_home_requested()

var is_open := false
var _root: Control
var _body: Control


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 30
	panel.offset_top = 12
	panel.offset_right = -30
	panel.offset_bottom = -12
	frame.add_child(panel)
	_body = Control.new()
	panel.add_child(_body)


func open_lobby() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_build_lobby()


func show_result(result: Dictionary) -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_build_result(result)


func close_screen() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _emblem(rp: int, size: float) -> Control:
	var tier := PvpData.tier_of(rp)
	var color: Color = tier.color
	var circle := PanelContainer.new()
	circle.custom_minimum_size = Vector2(size, size)
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.55)
	style.border_color = color
	style.set_border_width_all(6)
	style.set_corner_radius_all(int(size * 0.5))
	style.shadow_color = Color(color.r, color.g, color.b, 0.5)
	style.shadow_size = 18
	circle.add_theme_stylebox_override("panel", style)
	var icon := UIUtil.label(String(tier.icon), &"", HORIZONTAL_ALIGNMENT_CENTER)
	icon.add_theme_font_size_override("font_size", int(size * 0.5))
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(icon)
	return circle


func _clear() -> void:
	for child in _body.get_children():
		child.queue_free()


func _fill() -> VBoxContainer:
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_right = -18
	column.offset_top = 12
	column.offset_bottom = -12
	_body.add_child(column)
	return column


func _build_lobby() -> void:
	_clear()
	var p := Game.pvp()
	var rp := int(p.rp)
	var column := _fill()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("⚔ ลีกจัดอันดับ — โคลีเซียม", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	# Left: your rank.
	var left := UIUtil.vbox(8)
	left.custom_minimum_size = Vector2(380, 0)
	row.add_child(left)
	var emblem_row := CenterContainer.new()
	emblem_row.add_child(_emblem(rp, 150.0))
	left.add_child(emblem_row)
	var name_label := UIUtil.label(PvpData.rank_name(rp), &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_color_override("font_color", PvpData.tier_of(rp).color)
	name_label.add_theme_font_size_override("font_size", 40)
	left.add_child(name_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 26)
	bar.max_value = 1.0
	bar.value = PvpData.progress(rp)
	bar.show_percentage = false
	left.add_child(bar)
	var next_text := "แรงก์สูงสุดแล้ว!" if PvpData.step(rp) >= PvpData.MAX_STEP else "RP %d / %d → %s" % [rp % PvpData.STEP_RP, PvpData.STEP_RP, PvpData.step_name(PvpData.step(rp) + 1)]
	left.add_child(UIUtil.label(next_text, &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var total := int(p.wins) + int(p.losses)
	var rate := int(round(float(p.wins) * 100.0 / float(maxi(1, total))))
	left.add_child(UIUtil.label("ชนะ %d · แพ้ %d (%d%%) · ชนะติด %d (สูงสุด %d)" % [p.wins, p.losses, rate, p.streak, p.best_streak], &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var rules := UIUtil.label("• ดวลตัวต่อตัวกับผู้เล่น AI ในสนามโคลีเซียม เวลา %d วินาที\n• ชนะ +%d RP (ชนะติดกันได้โบนัส) · แพ้ −%d RP · หมดเวลานับว่าแพ้\n• แพ้แล้วตกได้แค่ดิวิชัน ไม่ตกลีก\n• ห้ามใช้ยา · สกิล ซัมมอน และบัฟใช้ได้เต็มที่\n• ขึ้นลีกใหม่ได้รางวัลเหรียญก้อนใหญ่และอุปกรณ์" % [
			int(PvpData.TIME_LIMIT), PvpData.rp_change(true, false, 0), -PvpData.rp_change(false, false, 0)], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(rules)
	left.add_child(UIUtil.spacer(false))
	var go := UIUtil.button("⚔ ท้าดวล!", &"PrimaryButton", Vector2(0, 80))
	var blocked := int(Game.profile.level) < PvpData.MIN_LEVEL
	go.disabled = blocked
	if blocked:
		go.text = "ต้องเลเวล %d ขึ้นไป" % PvpData.MIN_LEVEL
	go.pressed.connect(func():
		close_screen()
		challenge_requested.emit())
	left.add_child(go)
	# Right: the ladder.
	var right := UIUtil.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("บันไดแรงก์ — ยิ่งสูงยิ่งเจอคู่ต่อสู้เก่ง", &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIUtil.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var mine := PvpData.step(rp)
	for i in range(PvpData.MAX_STEP, -1, -1):
		list.add_child(_ladder_row(i, mine))
	await get_tree().process_frame
	scroll.scroll_vertical = maxi(0, int((PvpData.MAX_STEP - mine) * 62 - 130))


func _ladder_row(step_index: int, mine: int) -> Control:
	var tier: Dictionary = PvpData.TIERS[int(PvpData.place(step_index).tier)]
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var icon := UIUtil.label(String(tier.icon), &"BoldLabel")
	icon.custom_minimum_size = Vector2(46, 0)
	line.add_child(icon)
	var name_label := UIUtil.label(PvpData.step_name(step_index), &"BoldLabel")
	name_label.add_theme_color_override("font_color", tier.color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var level := PvpData.opponent_level(int(Game.profile.level), step_index * PvpData.STEP_RP)
	var stars := "★".repeat(PvpData.stars(step_index * PvpData.STEP_RP)) + "☆".repeat(5 - PvpData.stars(step_index * PvpData.STEP_RP))
	line.add_child(UIUtil.label("คู่ต่อสู้ Lv.%d  %s" % [level, stars], &"SmallLabel"))
	if step_index == mine:
		line.add_child(UIUtil.label("◀ คุณอยู่ที่นี่", &"BoldLabel"))
		panel.modulate = Color(1.2, 1.15, 0.9)
	elif step_index < mine:
		panel.modulate = Color(0.8, 0.85, 0.8)
	return panel


func _build_result(result: Dictionary) -> void:
	_clear()
	var won: bool = result.won
	var column := _fill()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := UIUtil.label("ชนะ!" if won else ("หมดเวลา" if result.timeout else "พ่ายแพ้"), &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 78)
	heading.add_theme_color_override("font_color", Color("ffd84a") if won else Color("9fb4ff"))
	column.add_child(heading)
	column.add_child(UIUtil.label("คู่ต่อสู้: %s (Lv.%d)" % [result.opponent, int(result.opponent_level)], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var emblem_row := CenterContainer.new()
	emblem_row.add_child(_emblem(int(result.rp_after), 120.0))
	column.add_child(emblem_row)
	var delta := int(result.delta)
	var rank_label := UIUtil.label("%s   %s%d RP" % [PvpData.rank_name(int(result.rp_after)), "+" if delta >= 0 else "", delta], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	rank_label.add_theme_color_override("font_color", PvpData.tier_of(int(result.rp_after)).color)
	column.add_child(rank_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(520, 24)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.value = PvpData.progress(int(result.rp_before))
	column.add_child(bar)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(bar, "value", PvpData.progress(int(result.rp_after)), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var rewards := "รางวัล: เหรียญ +%d · EXP +%d" % [int(result.gold), int(result.exp)]
	if int(result.streak) >= 2:
		rewards += " · ชนะติด %d" % int(result.streak)
	column.add_child(UIUtil.label(rewards, &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if bool(result.promoted):
		var promo := UIUtil.label("🎉 เลื่อนลีกเป็น %s!%s" % [PvpData.tier_of(int(result.rp_after)).name, (" ได้รับ " + String(result.item)) if String(result.item) != "" else ""], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
		promo.add_theme_color_override("font_color", Color("ffd84a"))
		column.add_child(promo)
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var again := UIUtil.button("⚔ ดวลอีกครั้ง", &"PrimaryButton", Vector2(320, 76))
	again.pressed.connect(func():
		close_screen()
		challenge_requested.emit())
	buttons.add_child(again)
	var home := UIUtil.button("กลับเมือง", &"", Vector2(260, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)
