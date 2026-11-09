class_name DungeonScreen
extends CanvasLayer
## The tomb keeper (DungeonData): three tabs. ดันเจี้ยน: today's entries, the party (it
## takes exactly PARTY_SIZE), the boss's three mechanics and who does what, the rewards, a
## button that asks online world players along and the way in. อันดับ: this week's top
## TOP clear times (DungeonRanking) with each party's class badges, the hero's row lit.
## แลกของ: เกล็ดมังกรโบราณ for the dungeon-only gear and materials (DungeonData.SHOP).
## Also the result after a run.

signal enter_requested()
signal go_home_requested()

const TABS := [["lobby", "ดันเจี้ยน"], ["ranking", "อันดับประจำสัปดาห์"], ["shop", "แลกเกล็ดมังกร"]]

var is_open := false
var tab := "lobby"
var _root: Control
var _body: Control
var _msg: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.08, 0.05, 0.95)
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


func open_lobby(which := "lobby") -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	DungeonRanking.want_fetch()
	tab = which
	_build()


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


func _build(note := "") -> void:
	UIUtil.clear(_body)
	var column := _column()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label(DungeonData.TITLE, &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("8af0b0"))
	head.add_child(title)
	var runs := UIUtil.label(DungeonData.runs_text(), &"SubHeaderLabel")
	runs.add_theme_color_override("font_color", Color("ffd84a") if DungeonData.runs_left() > 0 else Color("90a898"))
	head.add_child(runs)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var tabs := UIUtil.hbox(8)
	column.add_child(tabs)
	for entry in TABS:
		var b := UIUtil.button(String(entry[1]), &"PrimaryButton" if String(entry[0]) == tab else &"", Vector2(0, 50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = String(entry[0]) == tab
		var id := String(entry[0])
		b.pressed.connect(func():
			tab = id
			_build())
		tabs.add_child(b)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	match tab:
		"ranking":
			_ranking(list)
		"shop":
			_shop(list, note)
		_:
			_lobby(list, column, note)


# --- ดันเจี้ยน ---------------------------------------------------------------------------

func _lobby(list: VBoxContainer, column: VBoxContainer, note: String) -> void:
	var info := UIUtil.label(("ดันเจี้ยนกลไกสำหรับปาร์ตี้ %d คนพอดี (คุณ + เพื่อน 3 คน: ผู้เล่นในโลกหรือผู้เล่นออนไลน์จริง) เลเวล %d ขึ้นไป (Lv.%d ★%d) วันละ %d รอบ\n" +
		"ฝูงผู้พิทักษ์สุสาน 2 ฝูง แล้วปราบ%s · ความยากปรับตามพลังปาร์ตี้ · คนที่ล้มจะลุกขึ้นเมื่อเปลี่ยนช่วง ล้มทั้งสี่เท่ากับเสียรอบนั้น") % [DungeonData.PARTY_SIZE, DungeonData.SHOWN_MIN_LEVEL, DungeonData.MIN_LEVEL, DungeonData.MIN_STARS, DungeonData.RUNS_PER_DAY, DungeonData.BOSS_NAME], &"SmallLabel")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(info)
	list.add_child(_card("กลไกบอส — 3 หน้าที่ที่ต้องแบ่งกัน", ("• กระจายตัว (ดวงตาเพลิง): บอสมาร์ค 2 คน ครบ %d วินาทีระเบิดใส่ทุกคนในระยะ %d ม. รอบคนที่ถูกมาร์ค — คนที่ถูกมาร์ควิ่งออกห่างทุกคน (ยืนคนเดียวเจ็บแค่ครึ่ง)\n" +
		"• ล่อบอส (กรงเล็บทำลายล้าง): กรวยแดงเล็งเป้าหมายของบอส แรงเกือบตาย — ให้ผู้พิทักษ์ยั่วยุ/เบ่งเลือดรับไว้ หรือนักบวชใส่โล่ให้เป้าหมาย ถ้าไม่มีผู้พิทักษ์บอสจะสลับเป้าทุกครั้ง ต้องหลบออกข้าง\n" +
		"• สลับเป้า (ศิลามังกร): เลือด 70%% และ 35%% บอสไร้เทียมทานและเรียกศิลา 2 ก้อน ทำลายทั้งคู่ภายใน %d วินาที ไม่ทันบอสฟื้น %d%% แล้วเรียกใหม่\n" +
		"• คลั่งเมื่อครบ %d:%02d นาที: แรง x%d ต้องปราบให้ทัน · เคลียร์ใน %s ได้ตำแหน่ง \"ผู้พิชิตสุสานมังกร\"") % [int(DragonBoss.MARK_TIME), int(DragonBoss.SPREAD_RADIUS), int(DragonBoss.CRYSTAL_TIME), int(DragonBoss.CRYSTAL_HEAL * 100.0), int(DragonBoss.ENRAGE_TIME) / 60, int(DragonBoss.ENRAGE_TIME) % 60, int(DragonBoss.ENRAGE_ATK), DungeonData.time_text(DungeonData.FAST_SECONDS)]))
	var stars := int(Game.paragon().level)
	var preview := DungeonData.rewards(int(Game.profile.level), stars, true, RandomNumberGenerator.new())
	var first := "เคลียร์แรกของสัปดาห์ (%s): เกล็ดมังกรโบราณ x%d + ขนนก" % ["ยังไม่ได้รับ" if DungeonData.first_of_week_ready() else "รับแล้วสัปดาห์นี้", DungeonData.FIRST_WEEK_SCALES]
	list.add_child(_card("รางวัล", "%s\nทุกรอบ: เหรียญ %d · EXP %d · เกล็ดมังกรโบราณ x%d-%d (บอสดรอปเสมอ) · เพชรม่วง/ชมพู/ชาออส\nเกล็ดมังกรแลกของเฉพาะดันเจี้ยนได้ที่แท็บ \"แลกเกล็ดมังกร\" · เวลาที่ดีที่สุดของสัปดาห์ติดอันดับ" % [first, int(preview.gold), int(preview.exp), DungeonData.SCALE_MIN, DungeonData.SCALE_MAX]))
	var names: PackedStringArray = ["คุณ · %s Lv.%d%s" % [String(ClassData.get_class_data(Game.class_id()).get("name", "")), int(Game.profile.level), (" ★%d" % stars) if stars > 0 else ""]]
	for m in Game.party():
		var ms := Game.party_stars(m)
		names.append("%s · %s Lv.%d%s" % [String(m.name), String(ClassData.get_class_data(StringName(m["class"])).get("name", String(m["class"]))), int(m.level), (" ★%d" % ms) if ms > 0 else ""])
	var online := DungeonData.online_members()
	if online > 0:
		names.append("ผู้เล่นออนไลน์ในปาร์ตี้ %d คน" % online)
	var roles: PackedStringArray = []
	roles.append("ผู้พิทักษ์: %s" % ("มี ✓" if DungeonData.has_class(&"defender") else "ไม่มี (บอสจะสลับเป้า ต้องหลบกรวย)"))
	roles.append("นักบวช: %s" % ("มี ✓" if DungeonData.has_class(&"priest") else "ไม่มี"))
	list.add_child(_card("ปาร์ตี้ของคุณ (%d/%d คน) · %s" % [DungeonData.party_size(), DungeonData.PARTY_SIZE, " · ".join(roles)], "\n".join(names)))
	var best := int(Game.profile.flags.get(DungeonData.F_BEST, 0))
	var rank := DungeonRanking.my_rank()
	list.add_child(_card("สถิติของคุณ", "เคลียร์ทั้งหมด %d ครั้ง · เวลาดีที่สุด %s%s" % [int(Game.profile.flags.get(DungeonData.F_CLEARS, 0)), DungeonData.time_text(best) if best > 0 else "-", (" · อันดับสัปดาห์นี้ #%d" % rank) if rank > 0 else ""]))
	var buttons := UIUtil.hbox(12)
	column.add_child(buttons)
	var block := DungeonData.entry_block()
	var go := UIUtil.button("เข้าสุสาน", &"PrimaryButton", Vector2(280, 76))
	go.disabled = block != ""
	go.pressed.connect(func():
		var why := DungeonData.enter()
		if why != "":
			_build(why)
			return
		close_screen()
		enter_requested.emit())
	buttons.add_child(go)
	var find := UIUtil.button("หาเพื่อนร่วมทีม", &"", Vector2(260, 76))
	find.disabled = DungeonData.party_size() >= DungeonData.PARTY_SIZE or Game.world_party.size() >= Game.PARTY_MAX
	find.pressed.connect(func():
		var n := DungeonData.recruit()
		_build("มีผู้เล่นตอบรับ %d คน" % n if n > 0 else "ตอนนี้ไม่มีใครว่าง ลองชวนผู้เล่นในแมพ หรือรอสักพัก"))
	buttons.add_child(find)
	_msg = UIUtil.label(note if note != "" else block, &"BoldLabel")
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_msg)


# --- อันดับประจำสัปดาห์ -----------------------------------------------------------------

func _ranking(list: VBoxContainer) -> void:
	var week := DungeonRanking.week_of()
	var start := int(GuildLeague.week_start(week))
	var head := UIUtil.label("สัปดาห์นี้ (เริ่ม%s จันทร์ 00:00) · เวลาเคลียร์ดีที่สุดของหัวปาร์ตี้แต่ละคน · %d อันดับแรก%s" % [UIUtil.format_date(start), DungeonRanking.TOP, "" if DungeonRanking._link() != null else " · ออฟไลน์: แสดงสถิติในเครื่องและปาร์ตี้ผู้เล่นในโลก"], &"SmallLabel")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(head)
	var board := DungeonRanking.board(week)
	if board.is_empty():
		list.add_child(UIUtil.label("ยังไม่มีใครเคลียร์สัปดาห์นี้", &"BoldLabel"))
	for e in board:
		list.add_child(_row(e))
	var mine := DungeonRanking.local_best(week)
	if not mine.is_empty() and DungeonRanking.my_rank(week) == 0:
		list.add_child(UIUtil.label("เวลาของคุณ %s ยังไม่ติด %d อันดับแรก" % [DungeonData.time_text(int(mine.secs)), DungeonRanking.TOP], &"SmallLabel"))


func _row(e: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var row := UIUtil.hbox(10)
	panel.add_child(row)
	var rank := UIUtil.label("#%d" % int(e.rank), &"BoldLabel")
	rank.custom_minimum_size = Vector2(56, 0)
	rank.add_theme_color_override("font_color", Color("ffd84a") if int(e.rank) <= 3 else Color("d0e8d8"))
	row.add_child(rank)
	var name := UIUtil.label(String(e.name) + (" (คุณ)" if bool(e.mine) else ""), &"BoldLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	if bool(e.mine):
		name.add_theme_color_override("font_color", Color("8af0b0"))
	row.add_child(name)
	for cls in e.classes:
		row.add_child(class_badge(StringName(cls)))
	var secs := UIUtil.label(DungeonData.time_text(int(e.secs)), &"BoldLabel")
	secs.custom_minimum_size = Vector2(90, 0)
	secs.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(secs)
	return panel


## A small chip with the class's badge letter in its colour (ClassData "badge" / "color").
static func class_badge(cls: StringName) -> Control:
	var data := ClassData.get_class_data(cls)
	var chip := UIUtil.chip(String(data.get("badge", "?")), data.get("color", Color.WHITE), 16)
	chip.tooltip_text = String(data.get("name", String(cls)))
	chip.set_meta("class", String(cls))
	return chip


# --- แลกเกล็ดมังกร -------------------------------------------------------------------------

func _shop(list: VBoxContainer, note: String) -> void:
	var have := UIUtil.label("เกล็ดมังกรโบราณของคุณ: %d (บอสในสุสานดรอปเท่านั้น)" % DungeonData.scales(), &"SubHeaderLabel")
	have.add_theme_color_override("font_color", Color("8af0b0"))
	list.add_child(have)
	if note != "":
		var n := UIUtil.label(note, &"BoldLabel")
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(n)
	for e in DungeonData.SHOP:
		var panel := UIUtil.panel(&"CardPanel")
		var row := UIUtil.hbox(12)
		panel.add_child(row)
		var box := UIUtil.vbox(2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		box.add_child(UIUtil.label("%s · เกล็ด x%d" % [String(e.name), int(e.cost)], &"BoldLabel"))
		var desc := UIUtil.label(String(e.desc), &"SmallLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
		if String(e.kind) == "gear":
			var sample := DungeonData.gear(String(e.id), RandomNumberGenerator.new())
			var lines := UIUtil.label(" · ".join(ItemData.stat_lines(sample)) + " · ช่องอัญมณี 3 · ใส่ได้ทุกอาชีพ", &"SmallLabel")
			lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(lines)
		var buy := UIUtil.button("แลก", &"PrimaryButton", Vector2(140, 60))
		buy.disabled = DungeonData.buy_block(String(e.id)) != ""
		var id := String(e.id)
		buy.pressed.connect(func():
			var item := DungeonData.buy(id, _rng)
			if item.is_empty():
				_build(DungeonData.buy_block(id))
			else:
				AudioManager.play_ui(&"ui_open")
				_build("แลก %s แล้ว! อยู่ในกระเป๋า (หรือคลังเมื่อกระเป๋าเต็ม)" % ItemData.name_of(item)))
		row.add_child(buy)
		list.add_child(panel)


func _card(title: String, text: String) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var box := UIUtil.vbox(2)
	panel.add_child(box)
	box.add_child(UIUtil.label(title, &"BoldLabel"))
	var body := UIUtil.label(text, &"SmallLabel")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel


# --- The result -----------------------------------------------------------------------

func show_result(result: Dictionary) -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	UIUtil.clear(_body)
	var column := _column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var cleared := bool(result.get("cleared", false))
	var heading := UIUtil.label("พิชิตสุสานมังกรโบราณ!" if cleared else "ปาร์ตี้ล้มทั้งสี่", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", Color("ffd84a") if cleared else Color("ff6a7a"))
	column.add_child(heading)
	var secs := int(result.get("seconds", 0))
	var where := "บอส" if int(result.get("stage", 1)) > DungeonData.PACKS else "ฝูงที่ %d" % int(result.get("stage", 1))
	column.add_child(UIUtil.label("%s · เวลา %s" % ["เคลียร์" if cleared else "ไปถึง" + where, DungeonData.time_text(secs)], &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if cleared:
		var badges := UIUtil.hbox(6)
		badges.alignment = BoxContainer.ALIGNMENT_CENTER
		for cls in result.get("classes", []):
			badges.add_child(class_badge(StringName(cls)))
		column.add_child(badges)
		var rank := DungeonRanking.my_rank()
		var rank_text := "อันดับสัปดาห์นี้ #%d" % rank if rank > 0 else "ยังไม่ติด %d อันดับแรกของสัปดาห์" % DungeonRanking.TOP
		if bool(result.get("ranked", false)):
			rank_text = "เวลาดีที่สุดใหม่ของสัปดาห์! · " + rank_text
		column.add_child(UIUtil.label(rank_text, &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
		if bool(result.get("fast", false)):
			var fast := UIUtil.label("เคลียร์ใน %s! ได้ตำแหน่ง \"ผู้พิชิตสุสานมังกร\"" % DungeonData.time_text(DungeonData.FAST_SECONDS), &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
			fast.add_theme_color_override("font_color", Color("ffd84a"))
			column.add_child(fast)
	var paid: Dictionary = result.get("paid", {})
	if not paid.is_empty():
		if bool(paid.get("first_week", false)):
			var chest := UIUtil.label("เคลียร์แรกของสัปดาห์: เกล็ดมังกรโบราณ x%d!" % int(paid.get("scales", 0)), &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
			chest.add_theme_color_override("font_color", Color("8af0b0"))
			column.add_child(chest)
		var lines := UIUtil.label("\n".join(DungeonData.reward_lines(paid)), &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(lines)
	elif not cleared:
		column.add_child(UIUtil.label("รอบนี้ไม่ได้รางวัล · กระจายตัวเมื่อถูกมาร์ค ให้ผู้พิทักษ์รับกรงเล็บ ทุบศิลาให้ทัน", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIUtil.label(DungeonData.runs_text(), &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := UIUtil.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var home := UIUtil.button("กลับเมือง", &"PrimaryButton", Vector2(300, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)
