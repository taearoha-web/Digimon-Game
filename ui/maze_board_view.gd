class_name MazeBoardView
extends RefCounted
## The full board of เขาวงกตหนึ่งในใต้หล้า as a tab of the game menu (GameMenu "maze"),
## like the bag or the skills: this week's kills rank 1 to last (MazeWar.standings, the
## hero's row lit, real players tagged), the hero's own place, the crown's holder
## (MazeCrown), the week's countdown, the past weeks' champions and the maze's rules, with
## "เข้าเขาวงกต" outside the maze. Opened from the menu, from a tap on the maze's HUD strip
## and from the maze keeper. While open it redraws itself when a count changes
## (MazeWar.revision) and ticks the countdown every second.

const TAB_ID := &"maze"
const TAB_NAME := "หนึ่งในใต้หล้า"
## Rows shown (the hero's own is added under them when it ranks lower).
const ROWS := 60
const HERO_COLOR := Color("8fffb0")
const REAL_COLOR := Color("8fd0ff")
## The account's other characters (not played now: their kills stay on the board).
const MINE_COLOR := Color("ffd27a")
const MINE_TAG := " (ตัวละครของคุณ · ออฟไลน์)"


## Builds the page into `content`; `refresh` rebuilds the tab (kept scroll), `enter` sends
## the hero into the maze (the menu closes first).
static func build(content: Control, refresh: Callable, enter: Callable = Callable()) -> TouchScroll:
	var page := UIUtil.vbox(8)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(page)
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	var top := UIUtil.hbox(12)
	page.add_child(top)
	var titles := UIUtil.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	var title := UIUtil.label("ตารางอันดับ %s" % MazeWar.TITLE, &"SubHeaderLabel")
	title.add_theme_color_override("font_color", MazeWar.COLOR)
	titles.add_child(title)
	var head := UIUtil.label(head_text(), &"SmallLabel")
	head.name = "MazeWeek"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(head)
	if enter.is_valid() and Game.current_zone != MazeWar.ID:
		var go := UIUtil.button("เข้าเขาวงกต", &"PrimaryButton", Vector2(170, 56))
		go.name = "EnterMaze"
		go.pressed.connect(enter)
		top.add_child(go)
	var board := MazeWar.standings(week, t)
	var mine := -1
	for k in board.size():
		if bool(board[k].hero):
			mine = k
	var me := UIUtil.label("อันดับของคุณ: %d จาก %d · %d คิล" % [mine + 1, board.size(), int(board[mine].kills)] if mine >= 0 \
		else "คุณยังไม่มีอันดับสัปดาห์นี้ — ล้มผู้เล่นในเขาวงกตเพื่อขึ้นกระดาน (Lv.%d ขึ้นไป)" % MazeWar.MIN_LEVEL, &"BoldLabel")
	me.name = "MyRank"
	me.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	me.add_theme_color_override("font_color", HERO_COLOR)
	page.add_child(me)
	var scroll := TouchScroll.new()
	scroll.name = "MazeBoardView"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var list := UIUtil.vbox(4)
	list.name = "MazeList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var crown := MazeCrown.holder(t)
	var crown_label := UIUtil.label("%s ปัจจุบัน: %s (%d คิล สัปดาห์ก่อน) — ที่ 1 ของสัปดาห์นี้ได้ยศและชุด เทพราชันหนึ่งในใต้หล้า ครองหนึ่งสัปดาห์" % [MazeCrown.TITLE_NAME, String(crown.name) + who_tag(crown), int(crown.kills)] \
		if not crown.is_empty() else "ยังไม่มี%s — ที่ 1 ของสัปดาห์ได้ยศและชุด เทพราชันหนึ่งในใต้หล้า ครองหนึ่งสัปดาห์" % MazeCrown.TITLE_NAME, &"BoldLabel")
	crown_label.name = "CrownHolder"
	crown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	crown_label.add_theme_color_override("font_color", MazeWar.COLOR)
	list.add_child(crown_label)
	var rows := UIUtil.vbox(4)
	rows.name = "MazeRows"
	list.add_child(rows)
	if board.is_empty():
		rows.add_child(UIUtil.label("ยังไม่มีใครล้มใครสัปดาห์นี้", &"SmallLabel"))
	for k in mini(ROWS, board.size()):
		rows.add_child(_row(k + 1, board[k]))
	if mine >= ROWS:
		rows.add_child(UIUtil.label("…", &"SmallLabel"))
		rows.add_child(_row(mine + 1, board[mine]))
	list.add_child(_section("แชมป์หนึ่งในใต้หล้าสัปดาห์ก่อน ๆ"))
	var champs := MazeWar.champions(8)
	if champs.is_empty():
		list.add_child(UIUtil.label("ยังไม่มี (สัปดาห์แรกของเขาวงกต)", &"SmallLabel"))
	for c in champs:
		list.add_child(UIUtil.label("%s · %s%s · %d คิล" % [MazeWar.week_text(int(c.week)), String(c.name), who_tag(c), int(c.kills)], &"SmallLabel"))
	list.add_child(_section("กติกา"))
	for rule in rules():
		var r := UIUtil.label("• " + rule, &"SmallLabel")
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(r)
	# Live while open: the countdown every second, the whole page when a count changes.
	var rev := MazeWar.revision
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.process_mode = Node.PROCESS_MODE_ALWAYS
	tick.timeout.connect(func():
		if MazeWar.revision != rev and refresh.is_valid():
			rev = MazeWar.revision
			refresh.call()
		elif is_instance_valid(head):
			head.text = head_text())
	page.add_child(tick)
	return scroll


## " (คุณ)" for the one played, MINE_TAG for another character of the account, "" else.
static func who_tag(r: Dictionary) -> String:
	if bool(r.get("hero", false)):
		return " (คุณ)"
	return MINE_TAG if bool(r.get("mine", false)) else ""


static func head_text() -> String:
	var t := MazeWar.now()
	return "สัปดาห์ %s · %s · นับเฉพาะการฆ่าผู้เล่น (คุณ ผู้เล่นจริง และผู้เล่น AI)" % [MazeWar.week_text(MazeWar.week_of(t)), MazeWar.left_text(t)]


## The maze's rules as the board and the keeper tell them.
static func rules() -> PackedStringArray:
	return PackedStringArray([
		"เข้าได้ตลอดเวลา Lv.%d ขึ้นไป ทุกคนเป็นศัตรูกันหมด นับเฉพาะการฆ่าผู้เล่น (ไม่มีมอนสเตอร์)" % MazeWar.MIN_LEVEL,
		"ล้มแล้วเกิดใหม่ใน %d วินาที ณ จุดสุ่มทั่วเขาวงกต ไกลจากศัตรู และไม่มีใครทำร้ายได้ %d วินาที" % [int(MazeWar.RESPAWN), int(MazeWar.SPAWN_GUARD)],
		"ที่หลบภัย %d แห่ง: ในวงไม่มีใครทำร้ายได้และโจมตีใครไม่ได้ ได้ครั้งละ %d วินาที แล้วที่นั้นจะไม่คุ้มครองคุณอีก %d วินาที ออกจากวงยังได้รับการคุ้มครองอีก %s วินาที (โจมตีไม่ได้)" % [MazeLayout.safe_count(), int(MazeWar.SAFE_MAX), int(MazeWar.SAFE_COOLDOWN), str(MazeWar.SAFE_LEAVE)],
		"ฆ่าคนเดิมซ้ำนับได้ครั้งเดียวใน %d วินาที (ไม่มีการฟาร์มจุดเกิด)" % int(MazeWar.REKILL_GAP),
		"ตัดรอบทุกวันจันทร์ 00:00 พร้อมลีกกิลด์ ที่ 1 ได้ยศ %s และชุด เทพราชันหนึ่งในใต้หล้า ใช้ได้หนึ่งสัปดาห์" % MazeCrown.TITLE_NAME,
	])


static func _section(text: String) -> Control:
	var l := UIUtil.label(text, &"BoldLabel")
	l.add_theme_color_override("font_color", MazeWar.COLOR)
	return l


static func _row(rank: int, r: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(12)
	panel.add_child(line)
	var place := UIUtil.label("%d" % rank, &"HeaderLabel" if rank <= 3 else &"BoldLabel")
	place.custom_minimum_size = Vector2(56, 0)
	if rank <= 3:
		place.add_theme_color_override("font_color", [MazeWar.COLOR, Color("dfe6ee"), Color("e0a070")][rank - 1])
	line.add_child(place)
	var tag := who_tag(r)
	if tag == "" and int(r.index) < 0:
		tag = " · ผู้เล่นจริง"
	var name_label := UIUtil.label(String(r.name) + tag, &"BoldLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	if bool(r.hero):
		name_label.add_theme_color_override("font_color", HERO_COLOR)
	elif bool(r.get("mine", false)):
		name_label.add_theme_color_override("font_color", MINE_COLOR)
	elif int(r.index) < 0:
		name_label.add_theme_color_override("font_color", REAL_COLOR)
	line.add_child(name_label)
	line.add_child(UIUtil.label("%d คิล" % int(r.kills), &"BoldLabel"))
	return panel
