class_name GuildWarScreen
extends CanvasLayer
## The guild-war desk in the village (rules, your record, "go to war"), the party screen
## before a new war (pick up to four guild mates into the hero's party of five) and the
## scoreboard shown when a war ends.

signal enter_requested()
signal go_home_requested()

const MIN_LEVEL := 100

var is_open := false
var _root: Control
var _body: Control
## The party screen: our guild mates to pick from ({name, class, level, online}), the
## names picked (at most PARTY_SIZE - 1), the hero's five places and the list's rows.
var candidates: Array[Dictionary] = []
var picks: PackedStringArray = []
var _slots: Array[Dictionary] = []
var _rows: Dictionary = {}
var _party_count: Label
var _party_note: Label


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
	_slots.clear()
	_rows.clear()
	candidates.clear()
	_party_count = null
	_party_note = null
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
	var title := UIUtil.label("สงครามกิลด์ — ชิงปราสาท", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	# The way in sits right under the title, full width, so it is always on screen
	# (on a phone the rules below scroll); a blocked button says what is missing.
	var mine := Game.guild()
	var t := WorldPresence.clock()
	var no_rival := GuildWarData.guild_war_blocked(mine, t) if mine > 0 else ""
	var blocked := int(Game.profile.level) < MIN_LEVEL or mine == 0 or no_rival != ""
	var saved := Game.guildwar_checkpoint()
	var actions := UIUtil.hbox(12)
	actions.name = "WarActions"
	column.add_child(actions)
	if not saved.is_empty() and not blocked:
		var left_sec := int(saved.time_left)
		var rejoin := Game.guildwar_rejoin_left()
		var again := UIUtil.button("ต่อสงครามเดิม · %d : %d · เหลือ %d:%02d\n(กลับเข้าได้อีก %d นาที)" % [saved.us, saved.them, left_sec / 60, left_sec % 60, maxi(1, int(ceil(rejoin / 60.0)))], &"PrimaryButton", Vector2(0, 84))
		again.name = "ResumeWar"
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(func():
			Game.guildwar_resuming = true
			close_screen()
			enter_requested.emit())
		actions.add_child(again)
	var go := UIUtil.button("เริ่มสงครามใหม่!" if not saved.is_empty() else "เข้าสู่สงคราม!", &"PrimaryButton", Vector2(0, 84))
	go.name = "EnterWar"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = blocked
	if blocked:
		go.text = "ต้องเลเวล %d ขึ้นไป (ตอนนี้ %d)" % [MIN_LEVEL, int(Game.profile.level)] if int(Game.profile.level) < MIN_LEVEL else ("เข้ากิลด์ที่นายทะเบียนกิลด์ก่อน" if mine == 0 else "ยังไม่มีคู่สงคราม: " + no_rival)
	else:
		go.add_theme_font_size_override("font_size", 30)
		_pulse(go)
	go.pressed.connect(func():
		Game.guildwar_resuming = false
		open_party())
	actions.add_child(go)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left_scroll := TouchScroll.new()
	left_scroll.custom_minimum_size = Vector2(420, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(left_scroll)
	var left := UIUtil.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	_last_war(left)
	var rules := UIUtil.label("• ชิงปราสาท Alpha ปะทะ Neverdie: ทุกคนในกิลด์ที่เลเวล 100 ขึ้นไปลงสนามทั้งหมด คุณกับสมาชิกกิลด์ทุกคน สู้กับสมาชิกอีกกิลด์ทุกคน เวลา %d นาที\n• หลุดกลางสงคราม (แอปปิด เน็ตหลุด) กลับเข้ามาต่อได้ภายใน %d นาที ที่ปุ่มต่อสงครามเดิม\n• AI ของทั้งสองกิลด์วางแผนเองตามสถานการณ์: บุกประตู ตั้งรับหัวสะพาน ถอยรวมพล บุกห้องบัลลังก์ แบ่งทีมขวางทาง หรือล้อมแท่นตั้งรับ (แผนขึ้นในแถบข่าว)\n• สมาชิกกิลด์คือผู้เล่นที่ถึงเลเวล 100 แล้ว ทุกคนลงสนามด้วยเลเวล ดาว แต้มสถานะ และชุดที่เก็บได้จริงของตัวเอง\n• กิลด์เราเริ่มที่ค่ายฝั่งซ้าย อีกกิลด์ฝั่งขวา ปะทะกันที่ลานกลาง ข้ามสะพานไปตีประตูปราสาท 3 ชั้น (ประตูที่พังแล้วไม่ต้องตีใหม่)\n• ยึดแท่นได้เฉพาะหัวหน้ากิลด์ (กิลด์เรา: คุณ) ยืนในวงสีเหลืองบนแท่นแล้วกดยึดให้ครบ %d วินาที ออกนอกวงหยุดนับไว้ กลับเข้าวงนับต่อ ถ้าหัวหน้าล้มหรือออกจากห้องบัลลังก์ต้องนับใหม่\n• แตะที่ตัวศัตรูเพื่อเลือกเป้าโจมตี\n• กิลด์ที่ยึดปราสาทไว้ได้ตอนหมดเวลาชนะ (ไม่มีใครยึด: นับคนที่ล้มได้ เสมอ = ต่อเวลา)\n• ถูกล้มแล้วเกิดใหม่ที่ค่ายของตัวเองใน %d วินาที แล้วเดินกลับขึ้นไปใหม่ (ค่ายฟื้นเลือดเร็ว)\n• ไม่มีใครตายด้วยหมัดเดียว: ความเสียหายต่อการโดน 1 ครั้งไม่เกิน 20%% ของเลือดสูงสุด\n• เสบียง: ได้ยาเลือดสงครามฟื้น HP 5,000 ครบ %d ขวดทุกครั้งที่เข้าสนาม (เหลือแล้วคืนกิลด์)\n• รางวัล: ชนะ เหรียญ 10,000,000 + เพชรชมพู 10 เม็ด + ขนนก 2 ขน + EXP · แพ้ เหรียญ 500,000" % [int(GuildWarData.DURATION / 60.0), Game.GW_CKPT_LIFETIME / 60, int(GuildWarMatch.CAPTURE_TIME), int(GuildWarData.RESPAWN), GuildWarData.SUPPLY_COUNT], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(rules)
	var right := UIUtil.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("สมาชิกสองกิลด์ (เลเวล 100 ขึ้นไป)" if mine == 0 else "กิลด์ของคุณ: %s" % WorldPlayers.guild_name(mine), &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIUtil.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for g in ([mine, WorldPlayers.other_guild(mine)] if mine > 0 else [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]):
		var in_guild := WorldPlayers.members_at(g, t)
		var head_label := UIUtil.label("กิลด์ %s%s · สมาชิก %d คน" % [WorldPlayers.guild_name(g), " (ฝั่งเรา)" if g == mine else (" (คู่แข่ง)" if mine > 0 else ""), in_guild.size()], &"BoldLabel")
		head_label.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS[g])
		list.add_child(head_label)
		if in_guild.is_empty():
			list.add_child(UIUtil.label("ยังไม่มีใครถึงเลเวล %d" % Game.GUILD_LEVEL, &"SmallLabel"))
		for i in in_guild:
			var s := WorldPlayers.state(i, t)
			var row_line := UIUtil.hbox(8)
			var who := UIUtil.label("%s %s · %s" % ["●" if bool(s.online) else "○", s.name, ClassData.get_class_data(StringName(s["class"])).name], &"SmallLabel")
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_line.add_child(who)
			var level_label := UIUtil.label(WorldPlayers.level_text(s) + (" · ชุดเทพครบ" if bool(s.divine) else ""), &"SmallLabel")
			if bool(s.divine):
				level_label.add_theme_color_override("font_color", Color("ffd84a"))
			row_line.add_child(level_label)
			list.add_child(row_line)


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
	var castle := String(result.get("castle", ""))
	column.add_child(UIUtil.label("ปราสาทเป็นของกิลด์ %s" % castle if castle != "" else "ไม่มีกิลด์ไหนยึดปราสาทได้ — ตัดสินจากจำนวนคนที่ล้มได้", &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var prize := "เหรียญ +%s" % _commas(int(result.gold))
	var jewels: Dictionary = result.get("jewels", {})
	for id in jewels:
		prize += " · %s +%d" % [ItemData.JEWELS[id].name, int(jewels[id])]
	if int(result.exp) > 0:
		prize += " · EXP +%d" % int(result.exp)
	column.add_child(UIUtil.label("คุณฆ่า %d ครั้ง · ตาย %d ครั้ง   |   รางวัล: %s" % [int(result.kills), int(result.deaths), prize], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
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
			var shown := "ตัวละครของคุณ" if int(r.grade) < 0 else (String(r.get("tag", "")) if String(r.get("tag", "")) != "" else GuildWarData.grade_label(int(r.grade)))
			var name_label := UIUtil.label("%s  ·  %s" % [r.name, shown], &"SmallLabel")
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
		Game.guildwar_resuming = false
		open_party())
	buttons.add_child(again)
	var home := UIUtil.button("กลับเมือง", &"", Vector2(260, 76))
	home.pressed.connect(func():
		close_screen()
		go_home_requested.emit())
	buttons.add_child(home)


# ---------------------------------------------------------------------------
# The party screen: who fights beside the hero
# ---------------------------------------------------------------------------

const PARTY_SIZE := GuildWarMatch.PARTY_SIZE
const PICK_COLOR := GuildWarMatch.PARTY_COLOR


## Our guild mates at Lv.100 who will fight in the next war: online first, then the
## strongest (as the war lines them up).
static func war_mates(guild: int, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if guild <= 0:
		return out
	for i in WorldPlayers.members_at(guild, t):
		var st := WorldPlayers.state(i, t)
		out.append({"name": String(st.name), "class": StringName(st["class"]), "level": WorldPlayers.level_text(st), "online": bool(st.online), "rank": int(st.level) * 1000 + int(st.stars)})
	out.sort_custom(func(a, b):
		if bool(a.online) != bool(b.online):
			return bool(a.online)
		return int(a.rank) > int(b.rank))
	return out


## Before a new war: pick the hero's party (the last war's picks come back pre-chosen).
func open_party() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	candidates = war_mates(Game.guild(), WorldPresence.clock())
	picks = PackedStringArray()
	for name in Game.guildwar_party_picks:
		if picks.size() < PARTY_SIZE - 1 and candidates.any(func(c): return String(c.name) == name):
			picks.append(name)
	_build_party()


## Taps a guild mate: in the party it leaves, else it joins while there is room.
func toggle_pick(name: String) -> void:
	var at := picks.find(name)
	if at >= 0:
		picks.remove_at(at)
		AudioManager.play_ui(&"ui_cancel")
	elif picks.size() < PARTY_SIZE - 1:
		picks.append(name)
	else:
		Game.say("ปาร์ตี้เต็มแล้ว (%d คน) — ถอดใครออกก่อนจึงเพิ่มได้" % PARTY_SIZE, &"warning")
		return
	_refresh_party()


## "สุ่มให้": fills the empty places with random guild mates (the picks stay).
func auto_fill() -> void:
	var pool: Array = []
	for c in candidates:
		if not picks.has(String(c.name)):
			pool.append(String(c.name))
	pool.shuffle()
	while picks.size() < PARTY_SIZE - 1 and not pool.is_empty():
		picks.append(String(pool.pop_back()))
	_refresh_party()


func clear_picks() -> void:
	picks = PackedStringArray()
	_refresh_party()


## Goes to war with this party (fewer than four picks is fine: the places stay empty).
func confirm_party() -> void:
	Game.guildwar_party_picks = picks.duplicate()
	Game.guildwar_party_chosen = true
	Game.guildwar_resuming = false
	close_screen()
	enter_requested.emit()


## The last war's scoreboard on the desk: the result, then everyone's falls dealt and
## taken, each guild best first (profile.gw_last, written by Game.guildwar_finish).
func _last_war(box: VBoxContainer) -> void:
	box.add_child(UIUtil.label("สถิติรอบล่าสุด", &"SubHeaderLabel"))
	var last: Dictionary = Game.profile.get("gw_last", {})
	if last.is_empty():
		var none := UIUtil.label("ยังไม่มีรอบล่าสุด — ลงสงครามแล้วสถิติการฆ่าและการตายของทุกคนจะขึ้นที่นี่", &"SmallLabel")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(none)
		return
	var won := bool(last.get("won", false))
	var head := UIUtil.label("%s · %s %d : %d %s" % ["ชนะ" if won else "แพ้", String(last.get("our_guild", "")), int(last.get("score_us", 0)), int(last.get("score_them", 0)), String(last.get("their_guild", ""))], &"BoldLabel")
	head.add_theme_color_override("font_color", Color("ffd84a") if won else Color("9fb4ff"))
	box.add_child(head)
	var rows: Array = last.get("rows", [])
	for team in [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY]:
		var side: Array = rows.filter(func(r): return int(r.get("team", 0)) == team)
		if side.is_empty():
			continue
		side.sort_custom(func(a, b):
			if int(a.kills) != int(b.kills):
				return int(a.kills) > int(b.kills)
			return int(a.deaths) < int(b.deaths))
		var guild_name := String(last.get("our_guild" if team == GuildFighter.TEAM_ALLY else "their_guild", ""))
		var title := UIUtil.label("กิลด์ %s%s" % [guild_name, " (ฝั่งเรา)" if team == GuildFighter.TEAM_ALLY else ""], &"SmallLabel")
		title.add_theme_color_override("font_color", Color("8fd0ff") if team == GuildFighter.TEAM_ALLY else Color("ff9a8a"))
		box.add_child(title)
		for r in side:
			var line := UIUtil.hbox(8)
			line.name = "LastWarRow"
			var me := String(r.get("name", "")) == "คุณ"
			var cls := String(r.get("class", ""))
			var cls_name := String(ClassData.get_class_data(StringName(cls)).name) if ClassData.CLASSES.has(StringName(cls)) else ""
			var who := UIUtil.label("%s%s" % [r.get("name", ""), (" · " + cls_name) if cls_name != "" else ""], &"SmallLabel")
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			who.clip_text = true
			if me:
				who.add_theme_color_override("font_color", Color("ffd84a"))
			line.add_child(who)
			line.add_child(UIUtil.label("ฆ่า %d · ตาย %d" % [int(r.get("kills", 0)), int(r.get("deaths", 0))], &"SmallLabel"))
			box.add_child(line)


## 10000000 -> "10,000,000".
static func _commas(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## A gentle glow pulse on the way into the war, so the button catches the eye.
func _pulse(button: Button) -> void:
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "modulate", Color(1.1, 1.06, 0.95), 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(button, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)


func _build_party() -> void:
	_clear()
	_slots.clear()
	_rows.clear()
	var column := _fill()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("จัดปาร์ตี้ก่อนออกรบ", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := UIUtil.button("กลับ", &"", Vector2(120, 54))
	back.pressed.connect(_build_lobby)
	head.add_child(back)
	var rules := UIUtil.label("ปาร์ตี้ละไม่เกิน %d คน · บัฟจากสกิลถึงเฉพาะคนในปาร์ตี้เดียวกัน (ฮีลยังถึงทุกคนที่อยู่ใกล้เหมือนเดิม) · เพื่อนที่ไม่ได้เลือกและกิลด์คู่แข่งจะถูกสุ่มจัดเป็นปาร์ตี้ละไม่เกิน %d คน" % [PARTY_SIZE, PARTY_SIZE], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.add_theme_color_override("font_color", UIPalette.TEXT_DIM)
	column.add_child(rules)
	# The buttons sit on top, always on screen; the five places below scroll on a phone.
	var tools := UIUtil.hbox(10)
	column.add_child(tools)
	var fill := UIUtil.button("สุ่มให้", &"AccentButton", Vector2(150, 72))
	fill.name = "AutoFill"
	fill.pressed.connect(auto_fill)
	tools.add_child(fill)
	var wipe := UIUtil.button("ล้างทั้งหมด", &"", Vector2(150, 72))
	wipe.name = "ClearPicks"
	wipe.pressed.connect(clear_picks)
	tools.add_child(wipe)
	var go := UIUtil.button("ยืนยันปาร์ตี้ · เข้าสู่สงคราม!", &"PrimaryButton", Vector2(0, 72))
	go.name = "ConfirmParty"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.add_theme_font_size_override("font_size", 28)
	go.pressed.connect(confirm_party)
	_pulse(go)
	tools.add_child(go)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	# Left: the hero's five places.
	var left_scroll := TouchScroll.new()
	left_scroll.custom_minimum_size = Vector2(430, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(left_scroll)
	var left := UIUtil.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	_party_count = UIUtil.label("", &"SubHeaderLabel")
	_party_count.add_theme_color_override("font_color", PICK_COLOR)
	left.add_child(_party_count)
	for k in PARTY_SIZE:
		left.add_child(_slot_card(k))
	_party_note = UIUtil.label("", &"SmallLabel")
	_party_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_party_note.add_theme_color_override("font_color", UIPalette.TEXT_DIM)
	left.add_child(_party_note)
	# Right: our guild mates, tap to add or remove.
	var right := UIUtil.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("เพื่อนร่วมกิลด์ %d คน — แตะเพื่อเพิ่ม / ถอด" % candidates.size(), &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIUtil.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if candidates.is_empty():
		var none := UIUtil.label("ยังไม่มีเพื่อนร่วมกิลด์ให้เลือก — ระบบจะจัดปาร์ตี้ให้เอง", &"SmallLabel")
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(none)
	for c in candidates:
		list.add_child(_mate_row(c))
	_refresh_party()


## A round class badge with the class letter.
static func _badge(class_id: StringName, size := 34.0) -> PanelContainer:
	var data := ClassData.get_class_data(class_id)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(size, size)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.set_corner_radius_all(int(size * 0.5))
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	badge.add_theme_stylebox_override("panel", style)
	var letter := UIUtil.label(String(data.badge), &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.add_theme_font_size_override("font_size", 16)
	badge.add_child(letter)
	return badge


static func _card_style(color: Color, filled: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18) if filled else Color(0.07, 0.12, 0.19, 0.6)
	style.border_color = color if filled else Color(1, 1, 1, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


## Place k of the hero's party: the hero itself, a pick with "ถอด", or an empty place.
func _slot_card(k: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 50)
	var line := UIUtil.hbox(10)
	card.add_child(line)
	var badge_holder := CenterContainer.new()
	badge_holder.custom_minimum_size = Vector2(34, 34)
	line.add_child(badge_holder)
	var name_label := UIUtil.label("", &"BoldLabel")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(name_label)
	var detail := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(detail)
	var drop := UIUtil.button("ถอด", &"DangerButton", Vector2(76, 40))
	drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drop.add_theme_font_size_override("font_size", 16)
	drop.pressed.connect(func():
		if k - 1 < picks.size():
			toggle_pick(picks[k - 1]))
	line.add_child(drop)
	_slots.append({"card": card, "badge": badge_holder, "name": name_label, "detail": detail, "drop": drop, "key": "?"})
	return card


## One guild mate in the list: a full-width button (badge, name, class, level, state).
func _mate_row(c: Dictionary) -> Control:
	var row := Button.new()
	row.name = "Mate_" + String(c.name)
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0, 52)
	row.theme_type_variation = &"ChoiceButton"
	row.pressed.connect(func():
		AudioManager.play_ui(&"ui_click")
		toggle_pick(String(c.name)))
	var line := UIUtil.hbox(10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 10
	line.offset_right = -10
	row.add_child(line)
	line.add_child(_badge(StringName(c["class"]), 32.0))
	var who := UIUtil.label("%s %s" % ["●" if bool(c.online) else "○", c.name], &"BoldLabel")
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(who)
	var info := UIUtil.label("%s · %s" % [ClassData.get_class_data(StringName(c["class"])).name, c.level], &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(info)
	var state := UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.custom_minimum_size = Vector2(104, 0)
	line.add_child(state)
	_rows[String(c.name)] = {"button": row, "state": state, "who": who}
	return row


func _find_mate(name: String) -> Dictionary:
	for c in candidates:
		if String(c.name) == name:
			return c
	return {}


## The places and the list after a change, in place (the list keeps its scroll).
func _refresh_party() -> void:
	if _party_count == null or not is_instance_valid(_party_count):
		return
	_party_count.text = "ปาร์ตี้ของคุณ %d/%d" % [picks.size() + 1, PARTY_SIZE]
	for k in _slots.size():
		var entry: Dictionary = _slots[k]
		var mate := {} if k == 0 or k - 1 >= picks.size() else _find_mate(picks[k - 1])
		var key := "hero" if k == 0 else String(mate.get("name", ""))
		if key == entry.key:
			continue
		entry["key"] = key
		var holder: Control = entry.badge
		UIUtil.clear(holder)
		var card: PanelContainer = entry.card
		var name_label: Label = entry.name
		var detail: Label = entry.detail
		(entry.drop as Control).visible = k > 0 and not mate.is_empty()
		if k == 0:
			holder.add_child(_badge(Game.class_id()))
			name_label.text = "%s (คุณ · หัวหน้า)" % String(Game.profile.get("name", "คุณ"))
			var stars := int(Game.paragon().level)
			detail.text = "%s · Lv.%d%s" % [String(Game.class_data().name), int(Game.profile.level), " ★%d" % stars if stars > 0 else ""]
			card.add_theme_stylebox_override("panel", _card_style(UIPalette.GOLD, true))
			name_label.add_theme_color_override("font_color", UIPalette.GOLD)
		elif mate.is_empty():
			name_label.text = "ว่าง — แตะชื่อเพื่อนทางขวาเพื่อเพิ่ม"
			detail.text = ""
			card.add_theme_stylebox_override("panel", _card_style(Color.WHITE, false))
			name_label.add_theme_color_override("font_color", UIPalette.TEXT_MUTED)
		else:
			holder.add_child(_badge(StringName(mate["class"])))
			name_label.text = String(mate.name)
			detail.text = "%s · %s" % [ClassData.get_class_data(StringName(mate["class"])).name, mate.level]
			card.add_theme_stylebox_override("panel", _card_style(PICK_COLOR, true))
			name_label.add_theme_color_override("font_color", UIPalette.TEXT)
	var full := picks.size() >= PARTY_SIZE - 1
	_party_note.text = "ปาร์ตี้เต็มแล้ว พร้อมออกรบ" if full else ("ยืนยันได้เลยแม้เลือกไม่ครบ — ที่ว่างจะว่างไว้ (กด สุ่มให้ เพื่อเติมให้ครบ)" if not candidates.is_empty() else "")
	for name in _rows:
		var r: Dictionary = _rows[name]
		var picked := picks.has(String(name))
		var state: Label = r.state
		state.text = "✓ ในปาร์ตี้" if picked else ("เต็ม" if full else "+ เพิ่ม")
		state.add_theme_color_override("font_color", PICK_COLOR if picked else (UIPalette.TEXT_MUTED if full else UIPalette.CYAN))
		var row: Button = r.button
		if picked:
			var style := _card_style(PICK_COLOR, true)
			for kind in ["normal", "hover", "pressed"]:
				row.add_theme_stylebox_override(kind, style)
		else:
			for kind in ["normal", "hover", "pressed"]:
				row.remove_theme_stylebox_override(kind)
		row.modulate = Color(1, 1, 1, 0.6) if full and not picked else Color.WHITE
