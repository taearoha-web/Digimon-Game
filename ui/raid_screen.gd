class_name RaidScreen
extends CanvasLayer
## The party raid keeper (RaidData): today's entries ("เหลือ N/2 รอบวันนี้"), the party
## (it takes MIN_PARTY people), what the floors and the boss hold, the rewards, a button
## that asks online world players along, and the way in. Also the result after a run.

signal enter_requested()
signal go_home_requested()

var is_open := false
var _root: Control
var _body: Control
var _msg: Label


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.01, 0.03, 0.95)
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


func close_screen() -> void:
	is_open = false
	_root.visible = false
	UIUtil.clear(_body)
	get_tree().paused = false


func _column() -> VBoxContainer:
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_right = -18
	column.offset_top = 12
	column.offset_bottom = -12
	_body.add_child(column)
	return column


func _build_lobby(note := "") -> void:
	UIUtil.clear(_body)
	var column := _column()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label(RaidData.TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("ff8a96"))
	head.add_child(title)
	var runs := UIUtil.label(RaidData.runs_text(), &"SubHeaderLabel")
	runs.add_theme_color_override("font_color", Color("ffd84a") if RaidData.runs_left() > 0 else Color("a08890"))
	head.add_child(runs)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var info := UIUtil.label(("ลงดันเจี้ยน 3 ชั้นพร้อมปาร์ตี้ %d คนขึ้นไป (คุณ + เพื่อนร่วมปาร์ตี้) วันละ %d รอบ\n" +
		"ชั้น 1: ฝูงมอนสเตอร์ · ชั้น 2: ฝูงมอนสเตอร์ + ผู้คุมชั้น · ชั้น 3: %s\n" +
		"ความยากปรับตามเลเวลและดาวของปาร์ตี้ ล้มทั้งทีมเท่ากับเสียรอบนั้น (ไม่เสียเหรียญ)") % [RaidData.MIN_PARTY, RaidData.RUNS_PER_DAY, RaidData.BOSS_NAME], &"SmallLabel")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(info)
	list.add_child(_card("กลไกบอส — ต้องแบ่งหน้าที่", "• ทุบทำลาย: วงแดงตามตัวคนที่บอสเล็ง แรงมาก ให้ผู้พิทักษ์ยั่วยุดึงบอสแล้วเปิดเบ่งเลือดรับแทน\n• ฝนโลหิต / ระเบิดโลหิต: วงแดงบนพื้น เดินออกก่อนวงเต็ม\n• เรียกสมุน: ตอนเลือด 75%% และช่วงที่ 2 บอสมีโล่จนกว่าสมุนจะตายหมด ฆ่าสมุนก่อน!\n• เลือด 50%%: ช่วงที่ 2 บอสแรงขึ้นและเร็วขึ้น\n• คลั่งเมื่อครบ %d:%02d นาที: แรง x%d ต้องปราบให้ทัน" % [int(RaidBoss.ENRAGE_TIME) / 60, int(RaidBoss.ENRAGE_TIME) % 60, int(RaidBoss.ENRAGE_ATK)]))
	var stars := int(Game.paragon().level)
	var preview := RaidData.rewards(int(Game.profile.level), stars, true, RandomNumberGenerator.new())
	var chest := "หีบเคลียร์แรกของวัน (%s): " % ("ยังไม่ได้รับ" if RaidData.first_chest_ready() else "รับแล้ววันนี้")
	var reward_text := chest + "เหรียญ %d · EXP %d · เพชรม่วง/ชมพู/ชาออส · ขนนก (50 ดาว+) · แก่นเทพหลอมเซต (250 ดาว การันตีหีบแรก, รอบสองลุ้น 25%%; 200 ดาวลุ้น)\nรอบที่สองของวัน: ครึ่งหนึ่งของหีบแรก" % [int(preview.gold), int(preview.exp)]
	list.add_child(_card("รางวัล", reward_text))
	# The party.
	var names: PackedStringArray = ["คุณ (Lv.%d%s)" % [int(Game.profile.level), (" ★%d" % stars) if stars > 0 else ""]]
	for m in Game.party():
		var ms := Game.party_stars(m)
		names.append("%s %s Lv.%d%s" % [String(m.name), String(ClassData.get_class_data(StringName(m["class"])).get("name", String(m["class"]))), int(m.level), (" ★%d" % ms) if ms > 0 else ""])
	list.add_child(_card("ปาร์ตี้ของคุณ (%d/%d คน)" % [RaidData.party_size(), RaidData.MIN_PARTY], "\n".join(names)))
	var buttons := UIUtil.hbox(12)
	column.add_child(buttons)
	var block := RaidData.entry_block()
	var go := UIUtil.button("เข้าดันเจี้ยน", &"PrimaryButton", Vector2(300, 76))
	go.disabled = block != ""
	go.pressed.connect(func():
		var why := RaidData.enter()
		if why != "":
			_build_lobby(why)
			return
		close_screen()
		enter_requested.emit())
	buttons.add_child(go)
	var find := UIUtil.button("หาเพื่อนร่วมทีม", &"", Vector2(260, 76))
	find.disabled = RaidData.party_size() >= RaidData.MIN_PARTY or Game.world_party.size() >= Game.PARTY_MAX
	find.pressed.connect(func():
		var n := RaidData.recruit()
		_build_lobby("มีผู้เล่นตอบรับ %d คน" % n if n > 0 else "ตอนนี้ไม่มีใครว่าง ลองชวนผู้เล่นในแมพ หรือรอสักพัก"))
	buttons.add_child(find)
	_msg = UIUtil.label(note if note != "" else block, &"BoldLabel")
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_msg)


func _card(title: String, text: String) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var box := UIUtil.vbox(2)
	panel.add_child(box)
	box.add_child(UIUtil.label(title, &"BoldLabel"))
	var body := UIUtil.label(text, &"SmallLabel")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel


func show_result(result: Dictionary) -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	UIUtil.clear(_body)
	var column := _column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var cleared := bool(result.get("cleared", false))
	var heading := UIUtil.label("พิชิตดันเจี้ยนปาร์ตี้!" if cleared else "ปาร์ตี้ล้ม", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", Color("ffd84a") if cleared else Color("ff6a7a"))
	column.add_child(heading)
	var secs := int(result.get("seconds", 0))
	column.add_child(UIUtil.label("ถึงชั้น %d/%d · เวลา %d:%02d" % [int(result.get("floor", 1)), RaidData.FLOORS, secs / 60, secs % 60], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var paid: Dictionary = result.get("paid", {})
	if not paid.is_empty():
		if bool(paid.get("first", false)):
			var chest := UIUtil.label("หีบเคลียร์แรกของวัน!", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
			chest.add_theme_color_override("font_color", Color("ffd84a"))
			column.add_child(chest)
		var lines := UIUtil.label("\n".join(RaidData.reward_lines(paid)), &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(lines)
	elif not cleared:
		column.add_child(UIUtil.label("รอบนี้ไม่ได้รางวัล · ลองให้ผู้พิทักษ์รับทุบทำลายและหลบวงสีแดง", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIUtil.label(RaidData.runs_text(), &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var home := UIUtil.button("กลับเมือง", &"PrimaryButton", Vector2(300, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)
