class_name GuildWarScreen
extends CanvasLayer
## The guild-war desk in the village: the league's schedule (today's three rounds, a
## countdown, registration for the next round with the hero's place in its guild,
## "เข้าสู่สงคราม" for the registered hero in the line-up while its round is on and
## "ชมการแข่งขัน" for every war being fought), practice wars of hired guilds (no league
## points), the rules and your record; the party screen before a war (pick up to four of
## the line-up into the hero's party of five) and the scoreboard shown when a war ends.

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
## The schedule card's countdown, ticking while the desk is open.
var _countdown: Label


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
	_countdown = null
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
	_countdown = null
	# Back at the desk: no league war is on its way (enter_league sets one again).
	Game.guildwar_league = {}
	# The rounds' official results from the server (GuildLeague / LeagueRounds).
	LeagueRounds.want_fetch()
	var column := _fill()
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("สงครามกิลด์ — ลีก 4 กิลด์ ชิงปราสาท", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"", Vector2(120, 54))
	close.pressed.connect(close_screen)
	head.add_child(close)
	# The way in sits right under the title, full width, so it is always on screen
	# (on a phone the rest scrolls); a blocked button says what is missing.
	var mine := Game.guild()
	var t := WorldPresence.clock()
	var low := int(Game.profile.level) < MIN_LEVEL
	var saved := Game.guildwar_checkpoint()
	var actions := UIUtil.hbox(12)
	actions.name = "WarActions"
	column.add_child(actions)
	if not saved.is_empty() and not low:
		var left_sec := int(saved.time_left)
		var rejoin := Game.guildwar_rejoin_left()
		var again := UIUtil.button("ต่อสงครามเดิม · %d : %d · เหลือ %d:%02d\n(กลับเข้าได้อีก %d นาที)" % [saved.us, saved.them, left_sec / 60, left_sec % 60, maxi(1, int(ceil(rejoin / 60.0)))], &"PrimaryButton", Vector2(0, 84))
		again.name = "ResumeWar"
		again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again.pressed.connect(func():
			Game.guildwar_resuming = true
			Game.guildwar_league = {}
			close_screen()
			enter_requested.emit())
		actions.add_child(again)
	# The league war on now: only for the registered hero who made its guild's line-up.
	var problem := GuildLeague.enter_problem(t)
	var go := UIUtil.button("เข้าสู่สงคราม!", &"PrimaryButton", Vector2(0, 84))
	go.name = "EnterWar"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = low or problem != ""
	if low:
		go.text = "ต้องเลเวล %d ขึ้นไป (ตอนนี้ %d)" % [MIN_LEVEL, int(Game.profile.level)]
	elif problem != "":
		go.text = problem
	elif GuildLeague.lobby_slot(t) >= 0:
		# The waiting room (GuildWarMatch.lobby_until): in early, at the camp, until the bell.
		var at := GuildLeague.lobby_slot(t)
		go.text = "เข้าสู่สนาม (รอเริ่ม) · รอบ %s เริ่มใน %s" % [GuildLeague.clock_text(at), GuildLeague.until_text(at, t)]
		go.add_theme_font_size_override("font_size", 28)
		_pulse(go)
	else:
		var at := GuildLeague.live_slot(t)
		go.text = "เข้าสู่สงคราม! รอบ %s · %d กิลด์ชิงปราสาท" % [GuildLeague.clock_text(at), GuildLeague.rivals_of(mine, at).size() + 1]
		go.add_theme_font_size_override("font_size", 28)
		_pulse(go)
	go.pressed.connect(enter_league)
	actions.add_child(go)
	var practice := UIUtil.button("ซ้อมรบกับกิลด์รับจ้าง\n(ไม่นับคะแนนลีก)", &"", Vector2(250, 84))
	practice.name = "PracticeWar"
	practice.disabled = low
	practice.pressed.connect(enter_practice)
	actions.add_child(practice)
	var row := UIUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var left_scroll := TouchScroll.new()
	left_scroll.custom_minimum_size = Vector2(470, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(left_scroll)
	var left := UIUtil.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	_schedule_panel(left, t)
	_last_war(left)
	var rules := UIUtil.label("• ลีกมี 4 กิลด์: Alpha · Neverdie · Titan · 3DLnw สงครามเปิดตามเวลาจริง วันละ 3 รอบ %s (เวลาไทย) รอบละ %d นาที ทุกรอบทั้ง 4 กิลด์ลงสนามเดียวกัน ชิงปราสาทพร้อมกัน แต้มตามอันดับ (1: 40 · 2: 25 · 3: 15 · 4: 10) + ครองปราสาท + ยึด + ล้ม รวมเป็นตารางรายสัปดาห์\n• แต่ละกิลด์ส่งสมาชิกที่เก่งที่สุด %d คน (เลเวล ดาว ชุดเทพและการตีบวก) ลงด้วยตัวละครจริงของแต่ละคน\n• สมัครรอบถัดไปได้จนถึง %d นาทีก่อนเริ่ม ถ้าอันดับในกิลด์ติด %d อันดับได้ลงสนามเป็นตัวจริง ไม่ติดก็กดชมการแข่งขันได้ เลือกเพื่อนเข้าปาร์ตี้ได้เฉพาะคนที่ติดตัวจริง\n• ไม่สมัครหรือมาไม่ทัน สงครามก็เริ่มตรงเวลา แพ้ชนะตามกำลังจริงของสองกิลด์ (ผลเหมือนกันทุกเครื่อง) — มาสายแต่สมัครไว้ยังเข้าได้จนจบรอบ\n• หลุดกลางสงคราม (แอปปิด เน็ตหลุด) กลับเข้ามาต่อได้ภายใน %d นาที ที่ปุ่มต่อสงครามเดิม\n• แต่ละกิลด์เริ่มที่ค่ายของตัวเองนอกปราสาท (4 ค่ายห่างจากทางขึ้นปราสาทเท่ากัน) ข้ามสะพานไปตีประตูปราสาท 3 ชั้น ชั้น 1 และ 2 มีประตูซ้ายและขวา พังบานไหนก็ผ่านได้ (ประตูที่พังแล้วไม่ต้องตีใหม่)\n• ปราสาทเป็นของกิลด์ที่ครองไว้ตอนจบรอบก่อน จนกว่าจะมีกิลด์อื่นยึดได้: ผู้ครองเริ่มในปราสาท เดินผ่านประตูของตัวเองได้ ตีประตูตัวเองไม่ได้ ออกมาป้องกันประตูและแท่น\n• ยึดแท่นได้เฉพาะหัวหน้ากิลด์ (กิลด์เรา: %s) ยืนในวงสีเหลืองบนแท่นให้ครบ %d วินาที กิลด์ที่ครองปราสาทตอนหมดเวลาได้อันดับ 1 ที่เหลือเรียงตามแต้ม (ล้ม / 5 + ยึด × 5 · ไม่มีใครครอง: ตามแต้ม เสมอ = ต่อเวลา)\n• ถูกล้มแล้วเกิดใหม่ที่ค่ายใน %d วินาที · ไม่มีใครตายด้วยหมัดเดียว: ความเสียหายต่อการโดน 1 ครั้งไม่เกิน 20%% ของเลือดสูงสุด\n• เสบียง: ยาเลือดสงครามฟื้น HP 5,000 ครบ %d ขวดทุกครั้งที่เข้าสนาม (เหลือแล้วคืนกิลด์)\n• รางวัล: ชนะ เหรียญ 10,000,000 + เพชรชมพู 10 เม็ด + ขนนก 2 ขน + EXP · แพ้ เหรียญ 500,000 · ซ้อมรบกับกิลด์รับจ้างได้รางวัลเหมือนกันแต่ไม่นับคะแนนลีก" % [
		_slot_list(), int(GuildWarData.DURATION / 60.0), GuildWarData.GUILD_SIDE, GuildLeague.REGISTER_CLOSE / 60, GuildWarData.GUILD_SIDE, Game.GW_CKPT_LIFETIME / 60,
		_our_leader_text(mine), int(GuildWarMatch.CAPTURE_TIME), int(GuildWarData.RESPAWN), GuildWarData.SUPPLY_COUNT], &"SmallLabel")
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(rules)
	var right := UIUtil.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIUtil.label("สมาชิก 4 กิลด์ (เลเวล 100 ขึ้นไป)" if mine == 0 else "กิลด์ของคุณ: %s · ทุกรอบสู้กับอีก 3 กิลด์พร้อมกัน" % WorldPlayers.guild_name(mine), &"SubHeaderLabel"))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIUtil.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var shown: Array[int] = WorldPlayers.GUILDS.duplicate()
	if mine > 0:
		shown.erase(mine)
		shown.push_front(mine)
	for g in shown:
		var in_guild := WorldPlayers.members_at(g, t)
		var side := GuildWarData.best_members(g, t, GuildWarData.GUILD_SIDE)
		var head_label := UIUtil.label("กิลด์ %s%s · สมาชิก %d คน · ตัวจริง %d คน" % [WorldPlayers.guild_name(g), " (ฝั่งเรา)" if g == mine else (" (คู่แข่ง)" if mine > 0 else ""), in_guild.size(), side.size()], &"BoldLabel")
		head_label.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS[g])
		list.add_child(head_label)
		if in_guild.is_empty():
			list.add_child(UIUtil.label("ยังไม่มีใครถึงเลเวล %d" % Game.GUILD_LEVEL, &"SmallLabel"))
		var people: Array[Dictionary] = []
		for i in side:
			people.append(WorldPlayers.state(i, t))
		GuildScreen.sort_members(people, GuildScreen.sort_by)
		for s in people:
			var row_line := UIUtil.hbox(8)
			var who := UIUtil.label("%s %s · %s" % ["●" if bool(s.online) else "○", s.name, ClassData.get_class_data(StringName(s["class"])).name], &"SmallLabel")
			who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_line.add_child(who)
			var level_label := UIUtil.label(WorldPlayers.level_text(s) + (" · ชุดเทพครบ" if bool(s.divine) else ""), &"SmallLabel")
			if bool(s.divine):
				level_label.add_theme_color_override("font_color", Color("ffd84a"))
			row_line.add_child(level_label)
			list.add_child(row_line)


## "12:00 · 18:00 · 20:30".
static func _slot_list() -> String:
	var parts: PackedStringArray = []
	for s in GuildLeague.SLOTS:
		parts.append("%02d:%02d" % [s / 3600, (s % 3600) / 60])
	return " · ".join(parts)


## The league's schedule card: the countdown to the next round, registration for it (the
## hero's place in its guild: in the line-up or not), and today's rounds with each war's
## state, "ชมการแข่งขัน" on the wars being fought.
func _schedule_panel(box: VBoxContainer, t: float) -> void:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "LeagueSchedule"
	box.add_child(panel)
	var col := UIUtil.vbox(6)
	panel.add_child(col)
	col.add_child(UIUtil.label("ตารางสงครามกิลด์วันนี้ (เวลาไทย)", &"SubHeaderLabel"))
	_countdown = UIUtil.label(_countdown_text(t), &"BoldLabel")
	_countdown.name = "LeagueCountdown"
	_countdown.add_theme_color_override("font_color", Color("ffd84a"))
	_countdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_countdown)
	var mine := Game.guild()
	var next := GuildLeague.next_slot(t)
	# Registration for the next round.
	var reg_line := UIUtil.hbox(8)
	col.add_child(reg_line)
	var reg_text := ""
	if mine > 0:
		var place := GuildLeague.hero_place(next)
		reg_text = "รอบ %s: 4 กิลด์ชิงปราสาท · อันดับในกิลด์ #%d — %s" % [GuildLeague.clock_text(next), place,
			"ติดตัวจริง" if place > 0 and place <= GuildWarData.GUILD_SIDE else "ไม่ติด %d อันดับ (ชมการแข่งขันได้)" % GuildWarData.GUILD_SIDE]
	else:
		reg_text = "เข้ากิลด์ก่อนจึงสมัครลงสงครามได้"
	var reg_label := UIUtil.label(reg_text, &"SmallLabel")
	reg_label.name = "LeagueRank"
	reg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_line.add_child(reg_label)
	var reg := UIUtil.button("", &"AccentButton", Vector2(200, 58))
	reg.name = "LeagueRegister"
	var reg_problem := GuildLeague.register_problem(next, t)
	if GuildLeague.registered(next):
		reg.text = "สมัครแล้ว ✓\n(แตะเพื่อยกเลิก)" if reg_problem == "" else "สมัครแล้ว ✓"
		reg.disabled = reg_problem != ""
		reg.pressed.connect(func():
			var result := GuildLeague.unregister()
			Game.say("ยกเลิกการสมัครรอบ %s แล้ว" % GuildLeague.clock_text(next) if result == "ok" else result, &"info" if result == "ok" else &"warning")
			_build_lobby())
	else:
		reg.text = "สมัครรอบ %s" % GuildLeague.clock_text(next) if reg_problem == "" else reg_problem
		reg.disabled = reg_problem != ""
		reg.pressed.connect(func():
			var result := GuildLeague.register()
			if result == "ok":
				AudioManager.play_ui(&"ui_open")
				Game.say("สมัครสงครามกิลด์รอบ %s แล้ว — เริ่มเมื่อไหร่จะแจ้งเตือน" % GuildLeague.clock_text(next), &"success")
			else:
				Game.say(result, &"warning")
			_build_lobby())
	reg_line.add_child(reg)
	# Who holds the castle as the next (or the live) round begins.
	var live_at := GuildLeague.live_slot(t)
	var owner := UIUtil.label(GuildLeague.owner_text(live_at if live_at >= 0 else next), &"BoldLabel")
	owner.name = "LeagueOwner"
	owner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR)
	col.add_child(owner)
	# The deciding round: Sunday 20:30 counts double and crowns the Castle King.
	var final_at := GuildLeague.final_slot(GuildLeague.week_of(t))
	var final_rule := UIUtil.label("%s · รอบอาทิตย์ %s: แต้มอันดับและแต้มยึดปราสาท ×%d%s · ผู้ครองปราสาทหลังรอบนี้เป็น%s · แต้มรวมอันดับ 1 ของสัปดาห์เป็น%s" % [
		GuildLeague.FINAL_TAG, GuildLeague.clock_text(final_at), GuildLeague.FINAL_MULT,
		"" if GuildLeague.is_final(final_at) else " (เริ่มฤดูกาลหน้า)", GuildLeague.CASTLE_TITLE, GuildLeague.LEAGUE_TITLE], &"SmallLabel")
	final_rule.name = "LeagueFinalRule"
	final_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_rule.add_theme_color_override("font_color", GuildLeague.CROWN_COLOR.lerp(Color.WHITE, 0.3))
	col.add_child(final_rule)
	# Today's rounds (and the one on now, which may have begun yesterday night).
	var day := WorldEvents.day_of(t)
	for r in GuildLeague.rounds_on(day):
		col.add_child(_round_row(int(r.at), t))


## One round: the four guilds in one castle war, its state or placement, and
## "ชมการแข่งขัน" while it is fought.
func _round_row(at: int, t: float) -> Control:
	var box := UIUtil.vbox(2)
	box.name = "Round_%d" % at
	var line := UIUtil.hbox(8)
	box.add_child(line)
	var mine := Game.guild()
	var state := GuildLeague.round_state(at, t)
	var names: PackedStringArray = []
	for g in GuildLeague.guilds_at(at):
		names.append(WorldPlayers.guild_name(g))
	var text := "รอบ %s · %s" % [GuildLeague.clock_text(at), " · ".join(names)]
	if GuildLeague.is_final(at):
		text = "%s · %s" % [GuildLeague.FINAL_TAG, text]
	var own := int(state.get("owner", 0))
	if own > 0:
		text += " (%s %s ครองปราสาท)" % [GuildLeague.CROWN, WorldPlayers.guild_name(own)]
	match String(state.state):
		"wait":
			text += " · รอเริ่ม"
		"live":
			text += " · กำลังรบ เหลือ %d นาที" % maxi(1, int(ceil((float(at) + GuildWarData.DURATION - t) / 60.0)))
		"done":
			var war: Dictionary = state.war
			if war.is_empty():
				text += " · ไม่มีการแข่ง (สมาชิกยังไม่ถึงเลเวล %d)" % Game.GUILD_LEVEL
			elif war.has("g"):
				var places: PackedStringArray = []
				var order := GuildLeague.placement(war)
				for i in order.size():
					places.append("%d.%s" % [i + 1, WorldPlayers.guild_name(order[i])])
				text += " · %s%s%s" % [" ".join(places), " (ครองปราสาท)" if int(war.held) > 0 else "", " · คุณลงสนาม" if bool(state.get("real", false)) else ""]
			else:
				text += " · %s ชนะ%s" % [WorldPlayers.guild_name(int(war.win)), " (ครองปราสาท)" if int(war.held) > 0 else ""]
	var label := UIUtil.label(text, &"BoldLabel" if mine > 0 else &"SmallLabel")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_child(label)
	if String(state.state) == "live":
		var watch_btn := UIUtil.button("ชมการแข่งขัน", &"AccentButton", Vector2(170, 52))
		watch_btn.name = "Watch_%d" % at
		watch_btn.pressed.connect(func(): watch())
		line.add_child(watch_btn)
	return box


## "ตอนนี้ 17:42 · รอบ 18:00 เริ่มใน 18 นาที (ปิดรับสมัครใน 13 นาที)".
static func _countdown_text(t: float) -> String:
	var now_text := GuildLeague.clock_text(int(t))
	var live := GuildLeague.live_slot(t)
	var next := GuildLeague.next_slot(t)
	var left := int(float(next) - t)
	var out := "ตอนนี้ %s · " % now_text
	if live >= 0:
		var end_left := int(float(live) + GuildWarData.DURATION - t)
		out += "รอบ %s กำลังรบ เหลือ %d:%02d · " % [GuildLeague.clock_text(live), end_left / 60, end_left % 60]
	out += "รอบถัดไป %s เริ่มใน %d ชม. %02d นาที %02d วิ" % [GuildLeague.clock_text(next), left / 3600, (left % 3600) / 60, left % 60]
	var close_left := left - GuildLeague.REGISTER_CLOSE
	out += " (ปิดรับสมัครใน %d นาที)" % maxi(1, int(ceil(close_left / 60.0))) if close_left > 0 else " (ปิดรับสมัครแล้ว)"
	return out


func _process(_delta: float) -> void:
	if _countdown != null and is_instance_valid(_countdown) and _root.visible:
		_countdown.text = _countdown_text(WorldPresence.clock())


## "เข้าสู่สงคราม": the league war on now, through the party screen (its picks come from
## the line-up only).
func enter_league() -> void:
	var m := GuildLeague.enter_match()
	if m.is_empty():
		Game.say(GuildLeague.enter_problem(), &"warning")
		return
	Game.guildwar_league = m
	Game.guildwar_resuming = false
	open_party()


## "ซ้อมรบ": a war of hired guilds that counts nothing in the league.
func enter_practice() -> void:
	if int(Game.profile.level) < MIN_LEVEL:
		return
	Game.guildwar_league = {}
	Game.guildwar_resuming = false
	Game.guildwar_party_chosen = false
	Game.say("ซ้อมรบกับกิลด์รับจ้าง — ไม่นับคะแนนลีก", &"info")
	close_screen()
	enter_requested.emit()


const SPECTATE_PATH := "res://world/guild_war_spectate.gd"


## "ชมการแข่งขัน": watches the round on now, all four guilds (GuildWarSpectate, when the
## game has it). `a` / `b` are kept for old callers (the round is the same).
func watch(_a := 0, _b := 0) -> void:
	var info := GuildLeague.live_round_info()
	if info.is_empty():
		var soon := GuildLeague.lobby_slot()
		if soon >= 0:
			Game.say("ยังไม่เริ่ม เริ่มใน %s" % GuildLeague.until_text(soon), &"warning")
			return
		Game.say("ไม่มีการแข่งขันให้ชมตอนนี้", &"warning")
		return
	if not ResourceLoader.exists(SPECTATE_PATH):
		Game.say("โหมดชมการแข่งขันยังไม่เปิดให้ใช้", &"warning")
		return
	var script: Script = load(SPECTATE_PATH)
	if script == null:
		return
	close_screen()
	script.call("spectate", get_tree(), info)


func _build_result(result: Dictionary) -> void:
	_clear()
	var won: bool = result.won
	var column := _fill()
	var heading := UIUtil.label("ชนะสงคราม!" if won else "พ่ายแพ้สงคราม", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_font_size_override("font_size", 64)
	heading.add_theme_color_override("font_color", Color("ffd84a") if won else Color("9fb4ff"))
	column.add_child(heading)
	var places: Array = result.get("places", [])
	if places.size() > 2:
		heading.text = "อันดับ 1! ชนะสงคราม" if won else "จบอันดับ %d จาก %d กิลด์" % [int(result.get("placement", 0)), places.size()]
		var table := PackedStringArray()
		for row in places:
			table.append("%d. %s%s %d" % [int(row.place), GuildLeague.CROWN if bool(row.holder) else "", String(row.name), int(row.kills)])
		column.add_child(UIUtil.label("   ".join(table) + ("  (ต่อเวลา)" if bool(result.get("overtime", false)) else ""), &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	else:
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
	if int(result.get("league", 0)) > 0:
		prize += " · แต้มลีกกิลด์ +%d" % int(result.league)
	column.add_child(UIUtil.label("คุณฆ่า %d ครั้ง · ตาย %d ครั้ง   |   รางวัล: %s" % [int(result.kills), int(result.deaths), prize], &"SubHeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rows: Array = result.get("rows", [])
	var team_names: Array = result.get("team_names", [String(result.our_guild), String(result.their_guild)])
	for team in team_names.size():
		list.add_child(UIUtil.label(String(team_names[team]), &"BoldLabel"))
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
	var again := UIUtil.button("กลับห้องสงครามกิลด์", &"PrimaryButton", Vector2(320, 76))
	again.name = "BackToDesk"
	again.pressed.connect(func():
		Game.guildwar_resuming = false
		_build_lobby())
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


## Our guild mates who fight beside the hero in the league war of the round starting at
## t: the line-up (GuildWarData.side_ids, the hero counted), class by class, strongest
## first. The hero's picks come from these only (a pick never bypasses the line-up).
static func war_mates(guild: int, t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if guild <= 0:
		return out
	for i in GuildWarData.side_ids(guild, t, GuildWarData.hero_rank_point()).ids:
		var st := WorldPlayers.state(i, t)
		out.append({"name": String(st.name), "class": StringName(st["class"]), "level_text": WorldPlayers.level_text(st), "online": bool(st.online),
			"level": int(st.level), "stars": int(st.stars), "rank": int(st.level) * 1000 + int(st.stars)})
	# Class by class (archers, then priests, ...), each strongest first.
	GuildScreen.sort_members(out, "class")
	return out


## Before a new war: pick the hero's party (the last war's picks come back pre-chosen).
func open_party() -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	var league: Dictionary = Game.guildwar_league
	candidates = war_mates(Game.guild(), float(league.at)) if not league.is_empty() else ([] as Array[Dictionary])
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
	var their_names := String(last.get("their_guild", "")).split(" / ")
	for team in 1 + their_names.size():
		var side: Array = rows.filter(func(r): return int(r.get("team", 0)) == team)
		if side.is_empty():
			continue
		side.sort_custom(func(a, b):
			if int(a.kills) != int(b.kills):
				return int(a.kills) > int(b.kills)
			return int(a.deaths) < int(b.deaths))
		var guild_name := String(last.get("our_guild", "")) if team == GuildFighter.TEAM_ALLY else their_names[team - 1]
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
	var heading := StringName()
	for c in candidates:
		if c["class"] != heading:
			heading = c["class"]
			var count := candidates.filter(func(x): return x["class"] == heading).size()
			var role := ClassRoles.trait_of(heading)
			var head_label := UIUtil.label("%s · %d คน%s" % [ClassData.get_class_data(heading).name, count, (" · บทบาท " + String(role.name)) if not role.is_empty() else ""], &"BoldLabel")
			head_label.tooltip_text = ClassRoles.tooltip(heading)
			head_label.mouse_filter = Control.MOUSE_FILTER_PASS
			head_label.name = "MateClass_%s" % String(heading)
			head_label.add_theme_color_override("font_color", ClassData.get_class_data(heading).color.lerp(Color.WHITE, 0.35))
			list.add_child(head_label)
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
	var info := UIUtil.label("%s · %s" % [ClassData.get_class_data(StringName(c["class"])).name, c.level_text], &"SmallLabel", HORIZONTAL_ALIGNMENT_RIGHT)
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
			detail.text = "%s · %s" % [ClassData.get_class_data(StringName(mate["class"])).name, mate.level_text]
			card.add_theme_stylebox_override("panel", _card_style(PICK_COLOR, true))
			name_label.add_theme_color_override("font_color", UIPalette.TEXT)
	var full := picks.size() >= PARTY_SIZE - 1
	_party_note.text = "ปาร์ตี้เต็มแล้ว พร้อมออกรบ" if full else ("ยืนยันได้เลยแม้เลือกไม่ครบ — ที่ว่างจะว่างไว้ (กด สุ่มให้ เพื่อเติมให้ครบ)" if not candidates.is_empty() else "")
	# The roles this party brings (ClassRoles): one of each class is the strongest party.
	var party_classes: Array = [Game.class_id()]
	for name in picks:
		var picked := _find_mate(name)
		if not picked.is_empty():
			party_classes.append(StringName(picked["class"]))
	var roles := ClassRoles.summary(party_classes)
	if roles != "":
		_party_note.text = (_party_note.text + "\n" if _party_note.text != "" else "") + roles
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


## Who takes the altar for our guild in the war (the rules line): the hero, the member
## picked to lead (the guild screen's เลือกหัวหน้ากิลด์), or another character of the
## player picked to lead (played by the AI, tagged as the player's).
static func _our_leader_text(mine: int) -> String:
	if mine <= 0:
		return "คุณ"
	var who := Game.guild_war_leader(mine)
	if who != "" and Game.guild_war_alt_leader(mine) > 0:
		return "%s (%s)" % [who, Game.ALT_WAR_TAG]
	return "คุณ" if who == "" else who
