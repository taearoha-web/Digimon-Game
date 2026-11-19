class_name MazeBoard
extends CanvasLayer
## The full board of เขาวงกตหนึ่งในใต้หล้า (MazeWar.standings): this week's kills, rank
## 1 to last (the hero's row lit, real players tagged), the crown's holder (MazeCrown), the
## week's countdown, the past weeks' champions and the maze's rules. Opened from the
## maze keeper in the village and from the HUD's board inside the maze; it can send the
## hero in. Redrawn while open when a count changes (MazeWar.revision).

signal enter_requested

## Rows shown (the hero's own is added under them when it ranks lower).
const ROWS := 60
const HERO_COLOR := Color("8fffb0")
const REAL_COLOR := Color("8fd0ff")

var is_open := false
var _root: Control
var _list: VBoxContainer
var _head: Label
var _crown: Label
var _mine: Label
var _enter: Button
var _rev := -1
var _timer := 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.12, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var safe := SafeAreaContainer.new()
	_root.add_child(safe)
	var frame := Control.new()
	safe.add_child(frame)
	var panel := UIUtil.panel(&"GlassPanel")
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 50
	panel.offset_top = 12
	panel.offset_right = -50
	panel.offset_bottom = -12
	frame.add_child(panel)
	var column := UIUtil.vbox(8)
	panel.add_child(column)
	var top := UIUtil.hbox(12)
	column.add_child(top)
	var titles := UIUtil.vbox(2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	var title := UIUtil.label("ตารางอันดับ %s" % MazeWar.TITLE, &"HeaderLabel")
	title.add_theme_color_override("font_color", MazeWar.COLOR)
	titles.add_child(title)
	_head = UIUtil.label("", &"SmallLabel")
	titles.add_child(_head)
	_enter = UIUtil.button("เข้าเขาวงกต", &"PrimaryButton", Vector2(170, 56))
	_enter.name = "EnterMaze"
	_enter.pressed.connect(func():
		close_board()
		enter_requested.emit())
	top.add_child(_enter)
	var close := UIUtil.button("ปิด", &"", Vector2(110, 56))
	close.name = "CloseBoard"
	close.pressed.connect(close_board)
	top.add_child(close)
	_crown = UIUtil.label("", &"BoldLabel")
	_crown.name = "CrownHolder"
	_crown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crown.add_theme_color_override("font_color", MazeWar.COLOR)
	column.add_child(_crown)
	_mine = UIUtil.label("", &"BoldLabel")
	_mine.name = "MyRank"
	_mine.add_theme_color_override("font_color", HERO_COLOR)
	column.add_child(_mine)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = UIUtil.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func open_board() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_rev = -1
	_rebuild()


func close_board() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	UIUtil.clear(_list)
	get_tree().paused = false


func _process(delta: float) -> void:
	if not is_open:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		if MazeWar.revision != _rev:
			_rebuild()
		else:
			_head.text = _head_text()


func _head_text() -> String:
	var t := MazeWar.now()
	return "สัปดาห์ %s · %s · นับเฉพาะการฆ่าผู้เล่น (คุณ ผู้เล่นจริง และผู้เล่น AI)" % [MazeWar.week_text(MazeWar.week_of(t)), MazeWar.left_text(t)]


func _rebuild() -> void:
	_rev = MazeWar.revision
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	_head.text = _head_text()
	var crown := MazeCrown.holder(t)
	_crown.text = "%s ปัจจุบัน: %s (%d คิล สัปดาห์ก่อน) — ที่ 1 ของสัปดาห์นี้ได้ยศและชุด เทพราชันหนึ่งในใต้หล้า ครองหนึ่งสัปดาห์" % [MazeCrown.TITLE_NAME, String(crown.name) + (" (คุณ)" if bool(crown.get("hero", false)) else ""), int(crown.kills)] \
		if not crown.is_empty() else "ยังไม่มี%s — ที่ 1 ของสัปดาห์ได้ยศและชุด เทพราชันหนึ่งในใต้หล้า ครองหนึ่งสัปดาห์" % MazeCrown.TITLE_NAME
	_enter.visible = Game.current_zone != MazeWar.ID
	var board := MazeWar.standings(week, t)
	var mine := -1
	for k in board.size():
		if bool(board[k].hero):
			mine = k
	_mine.text = "อันดับของคุณ: %d จาก %d · %d คิล" % [mine + 1, board.size(), int(board[mine].kills)] if mine >= 0 else "คุณยังไม่มีอันดับสัปดาห์นี้ — ล้มผู้เล่นในเขาวงกตเพื่อขึ้นกระดาน (Lv.%d ขึ้นไป)" % MazeWar.MIN_LEVEL
	UIUtil.clear(_list)
	if board.is_empty():
		_list.add_child(UIUtil.label("ยังไม่มีใครล้มใครสัปดาห์นี้", &"SmallLabel"))
	for k in mini(ROWS, board.size()):
		_list.add_child(_row(k + 1, board[k]))
	if mine >= ROWS:
		_list.add_child(UIUtil.label("…", &"SmallLabel"))
		_list.add_child(_row(mine + 1, board[mine]))
	_list.add_child(_section("แชมป์หนึ่งในใต้หล้าสัปดาห์ก่อน ๆ"))
	var champs := MazeWar.champions(8)
	if champs.is_empty():
		_list.add_child(UIUtil.label("ยังไม่มี (สัปดาห์แรกของเขาวงกต)", &"SmallLabel"))
	for c in champs:
		var line := UIUtil.label("%s · %s%s · %d คิล" % [MazeWar.week_text(int(c.week)), String(c.name), " (คุณ)" if bool(c.hero) else "", int(c.kills)], &"SmallLabel")
		_list.add_child(line)
	_list.add_child(_section("กติกา"))
	for rule in rules():
		var r := UIUtil.label("• " + rule, &"SmallLabel")
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(r)


## The maze's rules as the board and the keeper tell them.
static func rules() -> PackedStringArray:
	return PackedStringArray([
		"เข้าได้ตลอดเวลา Lv.%d ขึ้นไป ทุกคนเป็นศัตรูกันหมด นับเฉพาะการฆ่าผู้เล่น (ไม่มีมอนสเตอร์)" % MazeWar.MIN_LEVEL,
		"ล้มแล้วเกิดใหม่ใน %d วินาที ณ จุดสุ่มทั่วเขาวงกต ไกลจากศัตรู และไม่มีใครทำร้ายได้ %d วินาที" % [int(MazeWar.RESPAWN), int(MazeWar.SPAWN_GUARD)],
		"ที่หลบภัย %d แห่ง: ในวงไม่มีใครทำร้ายได้และโจมตีใครไม่ได้ ได้ครั้งละ %d วินาที แล้วที่นั้นจะไม่คุ้มครองคุณอีก %d วินาที ออกจากวงยังได้รับการคุ้มครองอีก %s วินาที (โจมตีไม่ได้)" % [MazeLayout.safe_count(), int(MazeWar.SAFE_MAX), int(MazeWar.SAFE_COOLDOWN), str(MazeWar.SAFE_LEAVE)],
		"ฆ่าคนเดิมซ้ำนับได้ครั้งเดียวใน %d วินาที (ไม่มีการฟาร์มจุดเกิด)" % int(MazeWar.REKILL_GAP),
		"ตัดรอบทุกวันจันทร์ 00:00 พร้อมลีกกิลด์ ที่ 1 ได้ยศ %s และชุด เทพราชันหนึ่งในใต้หล้า ใช้ได้หนึ่งสัปดาห์" % MazeCrown.TITLE_NAME,
	])


func _section(text: String) -> Control:
	var l := UIUtil.label(text, &"BoldLabel")
	l.add_theme_color_override("font_color", MazeWar.COLOR)
	return l


func _row(rank: int, r: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(12)
	panel.add_child(line)
	var place := UIUtil.label("%d" % rank, &"HeaderLabel" if rank <= 3 else &"BoldLabel")
	place.custom_minimum_size = Vector2(56, 0)
	if rank <= 3:
		place.add_theme_color_override("font_color", [MazeWar.COLOR, Color("dfe6ee"), Color("e0a070")][rank - 1])
	line.add_child(place)
	var who := String(r.name)
	var tag := ""
	if bool(r.hero):
		tag = " (คุณ)"
	elif int(r.index) < 0:
		tag = " · ผู้เล่นจริง"
	var name_label := UIUtil.label(who + tag, &"BoldLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	if bool(r.hero):
		name_label.add_theme_color_override("font_color", HERO_COLOR)
	elif int(r.index) < 0:
		name_label.add_theme_color_override("font_color", REAL_COLOR)
	line.add_child(name_label)
	line.add_child(UIUtil.label("%d คิล" % int(r.kills), &"BoldLabel"))
	return panel
