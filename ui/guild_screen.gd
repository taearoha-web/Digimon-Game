class_name GuildScreen
extends CanvasLayer
## The guild registrar in the village: the two guilds of the world (WorldPlayers), Alpha
## and Neverdie, side by side with every member's class, level, stars and whereabouts
## (online in which field, or when last seen), and the button to join one or move to the
## other. Members are the players who have reached Lv.100; the lists follow their
## schedules while the screen is open.

signal closed()
## The member taps "ไปสงครามกิลด์": main opens the guild-war desk.
signal war_requested()

const REFRESH := 10.0
## How the member lists are sorted: "level" (highest level and stars first) or "class"
## (class by class in ClassData order, each strongest first, under a class heading).
const SORTS := {"level": "เลเวล", "class": "อาชีพ"}

## The list order the player picked (kept while the game runs).
static var sort_by := "level"

var is_open := false
var _root: Control
var _body: Control
var _timer := 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.92)
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
	_body = Control.new()
	panel.add_child(_body)
	Game.guild_changed.connect(func():
		if is_open:
			_build())


func open_screen() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_timer = REFRESH
	_build()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_body)
	get_tree().paused = false
	closed.emit()


func _process(delta: float) -> void:
	if not is_open:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_build()


func _build() -> void:
	var scrolls := _body.find_children("*", "TouchScroll", true, false)
	var kept: Array[int] = []
	for scroll in scrolls:
		kept.append((scroll as TouchScroll).retained_vertical_position())
	UIUtil.clear(_body)
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("นายทะเบียนกิลด์ — Alpha · Neverdie", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var mine := Game.guild()
	if mine > 0:
		var war := UIUtil.button("ไปสงครามกิลด์", &"AccentButton", Vector2(200, 60))
		war.name = "GoWar"
		war.pressed.connect(func():
			close_screen()
			war_requested.emit())
		head.add_child(war)
	for key in SORTS:
		var pick := UIUtil.button("เรียงตาม%s" % SORTS[key], &"AccentButton" if sort_by == key else &"", Vector2(150, 60))
		pick.name = "Sort_%s" % key
		pick.pressed.connect(func():
			sort_by = String(key)
			_build())
		head.add_child(pick)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var status := "คุณอยู่กิลด์ %s · ลงสงครามกิลด์กับเพื่อนร่วมกิลด์ได้ที่ผู้บัญชาการสงครามกิลด์" % WorldPlayers.guild_name(mine) if mine > 0 else "คุณยังไม่มีกิลด์ — เลือกเข้ากิลด์ใดกิลด์หนึ่ง แล้วไปลงสงครามกิลด์กับเพื่อนร่วมกิลด์ได้"
	if mine == 0 and int(Game.profile.level) < Game.GUILD_LEVEL:
		status = "เข้ากิลด์ได้ตั้งแต่เลเวล %d (ตอนนี้เลเวล %d) — ดูรายชื่อสมาชิกได้ก่อน" % [Game.GUILD_LEVEL, int(Game.profile.level)]
	var line := UIUtil.label(status, &"SmallLabel")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(line)
	var row := UIUtil.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var t := WorldPresence.clock()
	for g in [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]:
		row.add_child(_guild_column(g, mine, t))
	var k := 0
	for scroll in _body.find_children("*", "TouchScroll", true, false):
		if k < kept.size():
			(scroll as TouchScroll).restore_vertical_position(kept[k])
		k += 1


func _guild_column(g: int, mine: int, t: float) -> Control:
	var col := UIUtil.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var states: Array[Dictionary] = []
	var online := 0
	# Members are the players who have reached Lv.100 (they join on getting there).
	for i in WorldPlayers.members_at(g, t):
		var s := WorldPlayers.state(i, t)
		states.append(s)
		online += 1 if bool(s.online) else 0
	sort_members(states, sort_by)
	var top := UIUtil.hbox(10)
	col.add_child(top)
	var name_label := UIUtil.label("กิลด์ %s" % WorldPlayers.guild_name(g), &"SubHeaderLabel")
	name_label.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS[g])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UIUtil.label("สมาชิก %d คน · ออนไลน์ %d" % [states.size(), online], &"SmallLabel"))
	# One leader a guild: the hero leads its own; the other's is its strongest member.
	var leader := "คุณ (%s)" % String(Game.profile.get("name", "")) if mine == g else WorldPlayers.guild_leader(g, t)
	var lead_label := UIUtil.label("หัวหน้ากิลด์: %s — คนเดียวที่ยึดแท่นปราสาทได้" % (leader if leader != "" else "ยังไม่มี"), &"SmallLabel")
	lead_label.name = "Leader%s" % WorldPlayers.guild_name(g)
	lead_label.add_theme_color_override("font_color", Color("ffd84a"))
	lead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lead_label)
	var join := UIUtil.button("", &"PrimaryButton" if mine != g else &"", Vector2(0, 58))
	join.name = "Join%s" % WorldPlayers.guild_name(g)
	if mine == g:
		join.text = "กิลด์ของคุณ"
		join.disabled = true
	elif int(Game.profile.level) < Game.GUILD_LEVEL:
		join.text = "เข้ากิลด์ได้ตั้งแต่เลเวล %d" % Game.GUILD_LEVEL
		join.disabled = true
	else:
		join.text = "เข้าร่วมกิลด์ %s" % WorldPlayers.guild_name(g) if mine == 0 else "ย้ายไปกิลด์ %s" % WorldPlayers.guild_name(g)
		join.pressed.connect(func():
			if Game.join_guild(g):
				AudioManager.play_ui(&"ui_open")
				Game.say("เข้าร่วมกิลด์ %s แล้ว! เพื่อนร่วมกิลด์ %d คนจะลงสงครามกิลด์กับคุณ" % [WorldPlayers.guild_name(g), WorldPlayers.members_at(g, WorldPresence.clock()).size()], &"success"))
	col.add_child(join)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := UIUtil.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rows: Array[Dictionary] = []
	for s in states:
		rows.append({"name": String(s.name), "class": StringName(s["class"]), "level": int(s.level), "stars": int(s.get("stars", 0)),
			"level_text": WorldPlayers.level_text(s), "where": WorldPlayers.where_text(s, t), "online": bool(s.online)})
	if mine == g:
		var stars := int(Game.paragon().level)
		rows.append({"name": String(Game.profile.get("name", "คุณ")) + " (คุณ)", "class": Game.class_id(), "level": int(Game.profile.level), "stars": stars,
			"level_text": "Lv.%d%s" % [int(Game.profile.level), " ★%d" % stars if stars > 0 else ""], "where": "ออนไลน์ · ตัวละครของคุณ", "online": true})
	sort_members(rows, sort_by)
	var heading := StringName()
	for r in rows:
		if sort_by == "class" and r["class"] != heading:
			heading = r["class"]
			var count := rows.filter(func(x): return x["class"] == heading).size()
			var head_label := UIUtil.label("%s · %d คน" % [ClassData.get_class_data(heading).name, count], &"BoldLabel")
			head_label.name = "ClassHead_%s" % String(heading)
			head_label.add_theme_color_override("font_color", ClassData.get_class_data(heading).color.lerp(Color.WHITE, 0.35))
			list.add_child(head_label)
		list.add_child(_card(String(r.name), r["class"], String(r.level_text), String(r.where), bool(r.online)))
	if states.is_empty():
		list.add_child(UIUtil.label("ยังไม่มีผู้เล่นถึงเลเวล %d — ผู้เล่นเข้ากิลด์เมื่อถึงเลเวล %d" % [Game.GUILD_LEVEL, Game.GUILD_LEVEL], &"SmallLabel"))
	return col


## Sorts member rows ({class, level, stars, name}) in place: by level and stars, best
## first ("level"), or class by class in ClassData order, best first in each ("class").
static func sort_members(rows: Array, mode: String) -> void:
	rows.sort_custom(func(a, b):
		var ca := ClassData.IDS.find(StringName(a["class"]))
		var cb := ClassData.IDS.find(StringName(b["class"]))
		var pa := int(a.level) * 1000 + int(a.get("stars", 0))
		var pb := int(b.level) * 1000 + int(b.get("stars", 0))
		if mode == "class" and ca != cb:
			return ca < cb
		if pa != pb:
			return pa > pb
		if ca != cb:
			return ca < cb
		return String(a.name) < String(b.name))


func _card(who: String, cls: StringName, level: String, where: String, online: bool) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var dot := UIUtil.label("●", &"BoldLabel")
	dot.add_theme_color_override("font_color", Color("6dff9a") if online else Color("667788"))
	line.add_child(dot)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	info.add_child(UIUtil.label("%s  ·  %s" % [who, ClassData.get_class_data(cls).name], &"BoldLabel"))
	var detail := UIUtil.label(where, &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	line.add_child(UIUtil.label(level, &"BoldLabel"))
	return panel
