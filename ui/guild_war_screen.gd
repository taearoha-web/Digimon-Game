class_name GuildWarScreen
extends CanvasLayer
## The guild-war desk in the village (rules, your record, "go to war") and the
## scoreboard shown when a war ends.

signal enter_requested()
signal go_home_requested()

const MIN_LEVEL := 100

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
	dim.color = Color(0.05, 0.02, 0.08, 0.95)
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
	# A closed screen keeps nothing: its lists are built again when it opens.
	_clear()
	get_tree().paused = false


func _clear() -> void:
	# UIUtil.clear keeps a tapped button in the tree until it is freed (phone touch release).
	UIUtil.clear(_body)


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
	var column := _fill()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("สงครามกิลด์ — โคลีเซียม", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left := UIUtil.vbox(8)
	left.custom_minimum_size = Vector2(420, 0)
	row.add_child(left)
	var flags: Dictionary = Game.profile.get("flags", {})
	var wins := int(flags.get("gw_wins", 0))
	var losses := int(flags.get("gw_losses", 0))
	left.add_child(UIUtil.label("สถิติของคุณ", &"SubHeaderLabel"))
	left.add_child(UIUtil.label("ชนะ %d · แพ้ %d\nล้มศัตรูรวม %d ครั้ง · สูงสุดในศึกเดียว %d" % [wins, losses, int(flags.get("gw_kills", 0)), int(flags.get("gw_best_kills", 0))], &"SmallLabel"))
	var n := GuildWarData.TEAM_SIZE
	var rules := UIUtil.label("• %d ต่อ %d: คุณกับเพื่อน AI %d คน สู้กับกิลด์ศัตรู AI %d คน เวลา 30 นาที\n• ทุกคนสุ่มอาชีพ เลเวล 100 · 200 ดาว ใส่ชุดตั้งแต่ 50 ดาวถึงชุดประจำอาชีพพร้อมปีก (แต่ละกิลด์มีผู้รักษาหรือผู้อัญเชิญอย่างน้อย 1 คน)\n• ล้มศัตรูได้ 1 คะแนน ถูกล้มแล้วเกิดใหม่ที่ฐานใน %d วินาที (ฐานฟื้นเลือดเร็ว)\n• ออร์บพลังปรากฏกลางสนามทุก 1 นาที ใครเก็บได้ทีมนั้นโจมตี/ป้องกันเพิ่ม 20 วินาที\n• ไม่มีใครตายด้วยหมัดเดียว: ความเสียหายต่อการโดน 1 ครั้งไม่เกิน 20%% ของเลือดสูงสุด\n• เสมอ = ต่อเวลา ใครล้มก่อนชนะ · ใช้ยาและสกิลได้เต็มที่\n• เสบียง: ได้ยาเลือดสงครามฟื้น HP 5,000 ครบ %d ขวดทุกครั้งที่เข้าสนาม (เหลือแล้วคืนกิลด์)\n• รางวัล: ชนะ เหรียญ 1,000,000 · แพ้ เหรียญ 500,000" % [n, n, n - 1, n, int(GuildWarData.RESPAWN), GuildWarData.SUPPLY_COUNT], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(rules)
	left.add_child(UIUtil.spacer(false))
	var blocked := int(Game.profile.level) < MIN_LEVEL
	var saved := Game.guildwar_checkpoint()
	if not saved.is_empty() and not blocked:
		var left_sec := int(saved.time_left)
		var again := UIUtil.button("ต่อสงครามเดิม · %d : %d · เหลือ %d:%02d" % [saved.us, saved.them, left_sec / 60, left_sec % 60], &"PrimaryButton", Vector2(0, 80))
		again.pressed.connect(func():
			Game.guildwar_resuming = true
			close_screen()
			enter_requested.emit())
		left.add_child(again)
	var go := UIUtil.button("เริ่มสงครามใหม่!" if not saved.is_empty() else "เข้าสู่สงคราม!", &"" if not saved.is_empty() else &"PrimaryButton", Vector2(0, 80 if saved.is_empty() else 56))
	go.disabled = blocked
	if blocked:
		go.text = "ต้องเลเวล %d ขึ้นไป" % MIN_LEVEL
	go.pressed.connect(func():
		Game.guildwar_resuming = false
		close_screen()
		enter_requested.emit())
	left.add_child(go)
	var right := UIUtil.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("ระดับชุดของนักรบ AI (สุ่มทั้งสองกิลด์ ความแข็งแกร่งรวมสองฝั่งสมดุลกัน)", &"SubHeaderLabel"))
	for grade in GuildWarData.GRADES:
		var panel := UIUtil.panel(&"CardPanel")
		var line := UIUtil.hbox(10)
		panel.add_child(line)
		var name_label := UIUtil.label(GuildWarData.grade_label(grade), &"BoldLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if grade == GuildWarData.DIVINE:
			name_label.add_theme_color_override("font_color", Color("ffd84a"))
		line.add_child(name_label)
		right.add_child(panel)


func _build_result(result: Dictionary) -> void:
	_clear()
	var won: bool = result.won
	var column := _fill()
	var heading := UIUtil.label("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", Color("ffd84a") if won else Color("9fb4ff"))
	column.add_child(heading)
	var score := "%s  %d  :  %d  %s%s" % [result.our_guild, int(result.score_us), int(result.score_them), result.their_guild, "  (ต่อเวลา)" if bool(result.get("overtime", false)) else ""]
	column.add_child(UIUtil.label(score, &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIUtil.label("คุณล้มศัตรู %d ครั้ง · ถูกล้ม %d ครั้ง   |   รางวัล: เหรียญ +%d · EXP +%d" % [int(result.kills), int(result.deaths), int(result.gold), int(result.exp)], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rows: Array = result.get("rows", [])
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		list.add_child(UIUtil.label(String(result.our_guild) if team == GuildFighter.TEAM_ALLY else String(result.their_guild), &"BoldLabel"))
		for r in rows:
			if int(r.team) != team:
				continue
			var line := UIUtil.hbox(10)
			var name_label := UIUtil.label("%s  ·  %s" % [r.name, GuildWarData.grade_label(int(r.grade)) if int(r.grade) >= 0 else "ตัวละครของคุณ"], &"SmallLabel")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_color_override("font_color", Color("8fd0ff") if team == GuildFighter.TEAM_ALLY else Color("ff9a8a"))
			line.add_child(name_label)
			line.add_child(UIUtil.label("ล้ม %d   ถูกล้ม %d   ช่วย %d" % [int(r.kills), int(r.deaths), int(r.assists)], &"SmallLabel"))
			list.add_child(line)
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var again := UIUtil.button("รบอีกครั้ง", &"PrimaryButton", Vector2(320, 76))
	again.pressed.connect(func():
		close_screen()
		enter_requested.emit())
	buttons.add_child(again)
	var home := UIUtil.button("กลับเมือง", &"", Vector2(260, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)
