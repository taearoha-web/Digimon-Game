class_name GuildScreen
extends CanvasLayer
## The guild registrar in the village: the four guilds of the world (WorldPlayers: Alpha,
## Neverdie, Titan and 3DLnw), two by two with every member's class, level, stars and whereabouts
## (online in which field, or when last seen), and the button to join one or move to the
## other. Members are the players who have reached Lv.100; the lists follow their
## schedules while the screen is open.

signal closed()
## The member taps "ไปสงครามกิลด์": main opens the guild-war desk.
signal war_requested()
## "เข้าโถงกิลด์": the hero wants its guild's hall (GuildHallData; Main takes it there).
signal hall_requested()

const REFRESH := 10.0
## Member cards a guild column builds at most (see _guild_column).
const ROWS_MAX := 100
## How the member lists are sorted: "level" (highest level and stars first) or "class"
## (class by class in ClassData order, each strongest first, under a class heading).
const SORTS := {"level": "เลเวล", "class": "อาชีพ"}

## The list order the player picked (kept while the game runs).
static var sort_by := "level"
## What the screen shows: "roster" (both guilds' members) or "quests" (the guild's daily
## quests and the guild points shop, GuildQuestData; members only).
static var view := "roster"
## Class order when sorting by class: archers first, then priests, then the rest.
const CLASS_ORDER: Array[StringName] = [&"archer", &"priest", &"warrior", &"mage", &"summoner", &"lancer", &"defender", &"assassin", &"darklord", &"bard"]


static func class_rank(cls: StringName) -> int:
	var i := CLASS_ORDER.find(cls)
	return i if i >= 0 else CLASS_ORDER.size() + maxi(0, ClassData.IDS.find(cls))

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


## Opens on the members of both guilds.
func open_roster() -> void:
	view = "roster"
	open_screen()


## Opens straight on the guild quests and the guild points shop.
func open_quests() -> void:
	view = "quests"
	open_screen()


## Opens on the weekly guild league (LeagueView).
func open_league() -> void:
	view = "league"
	open_screen()


func close_screen() -> void:
	close_leader_picker()
	close_legend_picker()
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
	var mine := Game.guild()
	if mine == 0 and view == "quests":
		view = "roster"
	var title := UIUtil.label("นายทะเบียนกิลด์" if mine > 0 else "นายทะเบียนกิลด์ — เลือก 1 ใน 4 กิลด์", &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	if mine > 0:
		var war := UIUtil.button("ไปสงครามกิลด์", &"AccentButton", Vector2(180, 60))
		war.name = "GoWar"
		war.pressed.connect(func():
			close_screen()
			war_requested.emit())
		head.add_child(war)
		var hall := UIUtil.button("เข้าโถงกิลด์", &"AccentButton", Vector2(170, 60))
		hall.name = "GoHall"
		hall.pressed.connect(func():
			close_screen()
			hall_requested.emit())
		head.add_child(hall)
		var other := "roster" if view != "roster" else "quests"
		var tab := UIUtil.button("รายชื่อสมาชิก" if other == "roster" else "ภารกิจกิลด์", &"PrimaryButton" if other == "quests" else &"", Vector2(170, 60))
		tab.name = "GuildRoster" if other == "roster" else "GuildQuests"
		tab.pressed.connect(func():
			view = other
			_build())
		head.add_child(tab)
	if view == "roster":
		for key in SORTS:
			var pick := UIUtil.button("เรียงตาม%s" % SORTS[key], &"AccentButton" if sort_by == key else &"", Vector2(140, 60))
			pick.name = "Sort_%s" % key
			pick.pressed.connect(func():
				sort_by = String(key)
				_build())
			head.add_child(pick)
	# The weekly guild league (LeagueView), open to everyone.
	if view != "league":
		var league := UIUtil.button("ลีกกิลด์", &"AccentButton", Vector2(130, 60))
		league.name = "GuildLeague"
		league.pressed.connect(func():
			view = "league"
			_build())
		head.add_child(league)
	elif mine == 0:
		var back := UIUtil.button("รายชื่อสมาชิก", &"", Vector2(170, 60))
		back.pressed.connect(func():
			view = "roster"
			_build())
		head.add_child(back)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(110, 60))
	close.pressed.connect(close_screen)
	head.add_child(close)
	if view == "league":
		LeagueView.build(column, _build)
		_restore_scrolls(kept)
		return
	if view == "quests":
		_quest_view(column, mine)
		_restore_scrolls(kept)
		return
	var status := "คุณอยู่กิลด์ %s · ลงสงครามกิลด์กับเพื่อนร่วมกิลด์ได้ที่ผู้บัญชาการสงครามกิลด์" % WorldPlayers.guild_name(mine) if mine > 0 else "คุณยังไม่มีกิลด์ — เลือกเข้ากิลด์ใดกิลด์หนึ่ง แล้วไปลงสงครามกิลด์กับเพื่อนร่วมกิลด์ได้"
	if mine == 0 and int(Game.profile.level) < Game.GUILD_LEVEL:
		status = "เข้ากิลด์ได้ตั้งแต่เลเวล %d (ตอนนี้เลเวล %d) — ดูรายชื่อสมาชิกได้ก่อน" % [Game.GUILD_LEVEL, int(Game.profile.level)]
	var line := UIUtil.label(status, &"SmallLabel")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(line)
	column.add_child(_legend_row())
	# The four guilds, two to a row.
	var t := WorldPresence.clock()
	var row: HBoxContainer = null
	for k in WorldPlayers.GUILDS.size():
		if k % 2 == 0:
			row = UIUtil.hbox(14)
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(row)
		row.add_child(_guild_column(WorldPlayers.GUILDS[k], mine, t))
	_restore_scrolls(kept)


func _restore_scrolls(kept: Array[int]) -> void:
	var k := 0
	for scroll in _body.find_children("*", "TouchScroll", true, false):
		if k < kept.size():
			(scroll as TouchScroll).restore_vertical_position(kept[k])
		k += 1


# --- Guild quests and the guild points shop -------------------------------------

func _quest_view(column: Control, mine: int) -> void:
	var t := WorldPresence.clock()
	var quests := Game.guild_quests(t)
	var mates := GuildQuestData.mate_minutes(mine, t)
	var left := int(GuildQuestData.day_start(WorldEvents.day_of(t) + 1) - t)
	var info := UIUtil.hbox(12)
	column.add_child(info)
	var points := UIUtil.label("แต้มกิลด์ %d" % Game.guild_points(), &"SubHeaderLabel")
	points.name = "GuildPoints"
	points.add_theme_color_override("font_color", Color("ffd84a"))
	info.add_child(points)
	var line := UIUtil.label("กิลด์ %s · เพื่อนร่วมกิลด์ออนไลน์ %d/%d คนช่วยทำภารกิจ · รีเซ็ตใน %d ชม. %d นาที" % [
		WorldPlayers.guild_name(mine), int(mates.online), int(mates.members), left / 3600, (left % 3600) / 60], &"SmallLabel")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(line)
	var row := UIUtil.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	# Left: today's quests.
	var qcol := UIUtil.vbox(6)
	qcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qcol.size_flags_stretch_ratio = 1.25
	row.add_child(qcol)
	qcol.add_child(UIUtil.label("ภารกิจกิลด์รายวัน", &"BoldLabel"))
	var qscroll := TouchScroll.new()
	qscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	qscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	qcol.add_child(qscroll)
	var qlist := UIUtil.vbox(6)
	qlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qscroll.add_child(qlist)
	for q in quests:
		qlist.add_child(_quest_card(q))
	# Right: the guild points shop.
	var scol := UIUtil.vbox(6)
	scol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(scol)
	scol.add_child(UIUtil.label("ร้านแต้มกิลด์", &"BoldLabel"))
	var sscroll := TouchScroll.new()
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scol.add_child(sscroll)
	var slist := UIUtil.vbox(6)
	slist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(slist)
	for e in GuildQuestData.SHOP:
		slist.add_child(_shop_card(e))


func _quest_card(q: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Quest%d" % int(q.slot)
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var info := UIUtil.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	info.add_child(UIUtil.label(String(q.name), &"BoldLabel"))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = float(q.target)
	bar.value = float(q.progress)
	bar.show_percentage = false
	info.add_child(bar)
	var detail := UIUtil.label("%d/%d · คุณ %d + เพื่อนกิลด์ %d · +%d แต้ม · %s ทอง" % [int(q.progress), int(q.target), int(q.hero), int(q.mates), int(q.points), _num(int(q.gold))], &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var claim := UIUtil.button("", &"PrimaryButton", Vector2(110, 58))
	claim.name = "Claim%d" % int(q.slot)
	if bool(q.claimed):
		claim.text = "รับแล้ว"
		claim.disabled = true
	elif bool(q.done):
		claim.text = "รับรางวัล"
		claim.pressed.connect(func():
			var result := Game.guild_quest_claim(int(q.slot))
			if result == "ok":
				AudioManager.play_sfx(&"coin")
				Game.say("รับรางวัลภารกิจกิลด์: +%d แต้มกิลด์ · %s ทอง" % [int(q.points), _num(int(q.gold))], &"success")
			else:
				Game.say(result, &"warning")
			_build())
	else:
		claim.text = "ยังไม่ครบ"
		claim.disabled = true
	line.add_child(claim)
	return panel


func _shop_card(e: Dictionary) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var item := GuildQuestData.shop_item(e)
	var label := UIUtil.label(GuildQuestData.shop_name(e), &"BoldLabel")
	label.add_theme_color_override("font_color", ItemData.color_of(item).lerp(Color.WHITE, 0.5))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var buy := UIUtil.button("%d แต้ม" % int(e.price), &"AccentButton", Vector2(120, 54))
	buy.name = "Buy_%s" % String(e.id)
	buy.disabled = Game.guild_points() < int(e.price)
	buy.pressed.connect(func():
		var result := Game.guild_shop_buy(String(e.id))
		if result == "ok":
			AudioManager.play_sfx(&"pickup")
			Game.say("แลก %s ด้วย %d แต้มกิลด์แล้ว" % [GuildQuestData.shop_name(e), int(e.price)], &"success")
		else:
			Game.say(result, &"warning")
		_build())
	line.add_child(buy)
	return panel


static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


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
	# The player's other characters in this guild (other save slots) are members too.
	var alts := Game.guild_alts(g)
	var top := UIUtil.hbox(10)
	col.add_child(top)
	var name_label := UIUtil.label("กิลด์ %s" % WorldPlayers.guild_name(g), &"SubHeaderLabel")
	name_label.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS[g])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	var member_count := states.size() + alts.size()
	top.add_child(UIUtil.label("สมาชิก %d คน · ออนไลน์ %d" % [member_count, online], &"SmallLabel"))
	# One leader a guild, picked by the player (Game.guild_leader_of): by default the hero
	# leads its own and the other's is its strongest member.
	var lead := Game.guild_leader_of(g, t)
	var lead_row := UIUtil.hbox(8)
	col.add_child(lead_row)
	var lead_label := UIUtil.label("หัวหน้ากิลด์: %s — คนเดียวที่ยึดแท่นปราสาทได้" % Game.guild_leader_label(g, t), &"SmallLabel")
	lead_label.name = "Leader%s" % WorldPlayers.guild_name(g)
	lead_label.add_theme_color_override("font_color", Color("ffd84a"))
	lead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead_row.add_child(lead_label)
	var pick := UIUtil.button("เลือกหัวหน้ากิลด์", &"AccentButton", Vector2(190, 58))
	pick.name = "PickLeader%s" % WorldPlayers.guild_name(g)
	pick.disabled = states.is_empty() and alts.is_empty() and mine != g
	pick.pressed.connect(func(): open_leader_picker(g))
	lead_row.add_child(pick)
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
			"level_text": WorldPlayers.level_text(s), "where": WorldPlayers.where_text(s, t), "online": bool(s.online),
			"lead": String(lead.kind) == "member" and String(lead.name) == String(s.name)})
	for a in alts:
		rows.append(alt_row(a, String(lead.kind) == "alt" and int(lead.get("slot", 0)) == int(a.slot)))
	if mine == g:
		var stars := int(Game.paragon().level)
		rows.append({"name": String(Game.profile.get("name", "คุณ")) + " (คุณ)", "class": Game.class_id(), "level": int(Game.profile.level), "stars": stars,
			"level_text": "Lv.%d%s" % [int(Game.profile.level), " ★%d" % stars if stars > 0 else ""], "where": "ออนไลน์ · ตัวละครของคุณ", "online": true,
			"lead": String(lead.kind) == "hero"})
	sort_members(rows, sort_by)
	# A big guild lists its best ROWS_MAX (the hero, its other characters and the leader
	# always): the world grows by a few newcomers a day, a phone's list should not.
	var hidden := 0
	if rows.size() > ROWS_MAX:
		var kept: Array[Dictionary] = []
		for r in rows:
			if kept.size() < ROWS_MAX or bool(r.get("lead", false)) or r.has("alt") or String(r.where) == "ออนไลน์ · ตัวละครของคุณ":
				kept.append(r)
			else:
				hidden += 1
		rows = kept
	var heading := StringName()
	for r in rows:
		if sort_by == "class" and r["class"] != heading:
			heading = r["class"]
			var count := rows.filter(func(x): return x["class"] == heading).size()
			var head_label := UIUtil.label("%s · %d คน" % [ClassData.get_class_data(heading).name, count], &"BoldLabel")
			head_label.name = "ClassHead_%s" % String(heading)
			head_label.add_theme_color_override("font_color", ClassData.get_class_data(heading).color.lerp(Color.WHITE, 0.35))
			list.add_child(head_label)
		list.add_child(_card(String(r.name), r["class"], String(r.level_text), String(r.where), bool(r.online), bool(r.get("lead", false))))
	if hidden > 0:
		list.add_child(UIUtil.label("และอีก %d คน" % hidden, &"SmallLabel"))
	if states.is_empty() and alts.is_empty():
		list.add_child(UIUtil.label("ยังไม่มีผู้เล่นถึงเลเวล %d — ผู้เล่นเข้ากิลด์เมื่อถึงเลเวล %d" % [Game.GUILD_LEVEL, Game.GUILD_LEVEL], &"SmallLabel"))
	return col


## Sorts member rows ({class, level, stars, name}) in place: by level and stars, best
## first ("level"), or class by class in ClassData order, best first in each ("class").
static func sort_members(rows: Array, mode: String) -> void:
	rows.sort_custom(func(a, b):
		var ca := class_rank(StringName(a["class"]))
		var cb := class_rank(StringName(b["class"]))
		var pa := int(a.level) * 1000 + int(a.get("stars", 0))
		var pb := int(b.level) * 1000 + int(b.get("stars", 0))
		if mode == "class" and ca != cb:
			return ca < cb
		if pa != pb:
			return pa > pb
		if ca != cb:
			return ca < cb
		return String(a.name) < String(b.name))


## A member row for one of the player's other characters (Game.guild_alts).
static func alt_row(a: Dictionary, is_lead := false) -> Dictionary:
	var stars := int(a.get("stars", 0))
	return {"name": "%s (ตัวละครของคุณ)" % String(a.name), "class": StringName(a["class"]), "level": int(a.level), "stars": stars,
		"level_text": "Lv.%d%s" % [int(a.level), " ★%d" % stars if stars > 0 else ""],
		"where": "ตัวละครของคุณ · ไม่ได้เล่นอยู่ — ลงสงครามกิลด์ให้กิลด์นี้โดย AI", "online": false, "alt": int(a.slot), "lead": is_lead}


func _card(who: String, cls: StringName, level: String, where: String, online: bool, lead := false) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var dot := UIUtil.label("●", &"BoldLabel")
	dot.add_theme_color_override("font_color", Color("6dff9a") if online else Color("667788"))
	line.add_child(dot)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var title := UIUtil.label("%s%s  ·  %s" % ["หัวหน้ากิลด์ · " if lead else "", who, ClassData.get_class_data(cls).name], &"BoldLabel")
	if lead:
		title.add_theme_color_override("font_color", Color("ffd84a"))
	info.add_child(title)
	var detail := UIUtil.label(where, &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	line.add_child(UIUtil.label(level, &"BoldLabel"))
	return panel


# --- The Legendary Guild Wings (ปีกตำนานแห่งกิลด์, LegendWings) -----------------------

var _legend_picker: OverlaySheet


## This week's holder and the streak (LegendWings.line_now), the streak's earlier holders,
## and, while the hero as leader has a pair to hand on, the button that opens the picker.
func _legend_row() -> Control:
	var box := UIUtil.vbox(4)
	var row := UIUtil.hbox(8)
	box.add_child(row)
	var holders := LegendWings.streak_holders()
	var text := LegendWings.line_now()
	if holders.size() > 1:
		var earlier: PackedStringArray = []
		for k in range(1, holders.size()):
			earlier.append("ฤดูกาลที่ %d: %s" % [int(holders[k].w), LegendWings.holder_label({"n": holders[k].n})])
		text += " · ผู้ถือก่อนหน้าในชุดนี้: %s" % ", ".join(earlier)
	var label := UIUtil.label(text, &"SmallLabel")
	label.name = "LegendLine"
	label.add_theme_color_override("font_color", LegendWings.COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var pending := LegendWings.pending()
	if not pending.is_empty():
		var hand := UIUtil.button("มอบปีกตำนาน", &"PrimaryButton", Vector2(170, 58))
		hand.name = "HandLegend"
		hand.pressed.connect(func(): open_legend_picker(int(pending.w)))
		row.add_child(hand)
		var note := UIUtil.label("กิลด์ %s เป็นแชมป์ลีกติดต่อกัน %d สัปดาห์ — คุณเป็นหัวหน้ากิลด์ เลือกสมาชิกที่จะรับปีกตำนานฤดูกาลที่ %d (ผู้ที่ถือปีกของชุดนี้อยู่แล้วรับซ้ำไม่ได้)" % [WorldPlayers.guild_name(int(pending.g)), int(pending.s), int(pending.w)], &"SmallLabel")
		note.name = "LegendPending"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(note)
	return box


## The Thai dialog listing whom the hero as leader may hand season w's pair to.
func open_legend_picker(w: int) -> void:
	close_legend_picker()
	var choices := LegendWings.hand_choices(w)
	if choices.is_empty():
		Game.say("ไม่มีปีกตำนานรอมอบ", &"warning")
		return
	var box := UIUtil.vbox(8)
	var hint := UIUtil.label("%s ฤดูกาลที่ %d · ผู้รับจะใส่ปีกทันทีและถอดไม่ได้ (เปลี่ยนได้เฉพาะปีกตำนานคู่อื่น) · มอบให้ตัวเองได้เมื่อยังไม่มีปีกของแชมป์ชุดนี้" % [LegendWings.NAME, w], &"SmallLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := UIUtil.vbox(6)
	list.name = "LegendChoices"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var k := 0
	for r in choices:
		list.add_child(_legend_card(w, r, k))
		k += 1
	var sheet_size := Vector2(minf(900.0, maxf(560.0, _root.size.x - 80.0)), minf(600.0, maxf(380.0, _root.size.y - 60.0)))
	_legend_picker = OverlaySheet.open(_root, "มอบ%s" % LegendWings.NAME, box, sheet_size)
	_legend_picker.name = "LegendPicker"
	_legend_picker.closed.connect(func(): _legend_picker = null)


func close_legend_picker() -> void:
	if _legend_picker != null and is_instance_valid(_legend_picker):
		_legend_picker.queue_free()
	_legend_picker = null


func _legend_card(w: int, r: Dictionary, k: int) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var who := "ตัวฉัน (%s)" % String(Game.profile.get("name", "")) if bool(r.get("me", false)) else String(r.name)
	var title := UIUtil.label("%s  ·  %s" % [who, ClassData.get_class_data(StringName(r["class"])).name], &"BoldLabel")
	title.clip_text = true
	if bool(r.get("me", false)):
		title.add_theme_color_override("font_color", LegendWings.COLOR)
	info.add_child(title)
	var stars := int(r.get("stars", 0))
	info.add_child(UIUtil.label("Lv.%d%s" % [int(r.level), " ★%d" % stars if stars > 0 else ""], &"SmallLabel"))
	var give := UIUtil.button("มอบให้", &"PrimaryButton", Vector2(150, 58))
	give.name = "Hand_%d" % k
	give.set_meta("pick", String(r.name))
	give.pressed.connect(func(): hand_legend(w, String(r.name), who))
	line.add_child(give)
	return panel


## Hands the pair on (LegendWings.hand_to), closes the picker and tells who got it.
func hand_legend(w: int, pick: String, shown: String) -> bool:
	var result := LegendWings.hand_to(w, pick)
	if result != "ok":
		Game.say(result, &"warning")
		return false
	AudioManager.play_ui(&"ui_open")
	if pick != "":
		Game.say("มอบ%sฤดูกาลที่ %d ให้ %s แล้ว" % [LegendWings.NAME, w, shown], &"success")
	close_legend_picker()
	_build()
	return true


# --- The guild leader picker (เลือกหัวหน้ากิลด์) -----------------------------------

var _picker: OverlaySheet


## Everyone who may lead guild `g`, in the picker's order: for the hero's own guild the
## hero first ("ตัวฉัน"), then the player's other characters in that guild, then the
## members strongest first. [{pick, name, class, level, stars, level_text, where, online, current, me, alt}].
static func leader_choices(g: int, t: float) -> Array[Dictionary]:
	var lead := Game.guild_leader_of(g, t)
	var rows: Array[Dictionary] = []
	for i in WorldPlayers.members_at(g, t):
		var s := WorldPlayers.state(i, t)
		rows.append({"pick": String(s.name), "name": String(s.name), "class": StringName(s["class"]), "level": int(s.level), "stars": int(s.get("stars", 0)),
			"level_text": WorldPlayers.level_text(s), "where": WorldPlayers.where_text(s, t), "online": bool(s.online),
			"current": String(lead.kind) == "member" and String(lead.name) == String(s.name)})
	sort_members(rows, "level")
	# The player's own other characters right after ตัวฉัน, before the world's members.
	var mine: Array[Dictionary] = []
	for a in Game.guild_alts(g):
		var row := alt_row(a, String(lead.kind) == "alt" and int(lead.get("slot", 0)) == int(a.slot))
		row["pick"] = Game.alt_pick(int(a.slot))
		row["current"] = row.lead
		row["where"] = "ตัวละครของคุณ · ไม่ได้เล่นอยู่ — นำทัพในสงครามกิลด์โดย AI"
		mine.append(row)
	sort_members(mine, "level")
	mine.append_array(rows)
	rows = mine
	if g == Game.guild():
		var stars := int(Game.paragon().level)
		rows.push_front({"pick": "", "name": "ตัวฉัน (%s)" % String(Game.profile.get("name", "")), "class": Game.class_id(), "level": int(Game.profile.level), "stars": stars,
			"level_text": "Lv.%d%s" % [int(Game.profile.level), " ★%d" % stars if stars > 0 else ""], "where": "ออนไลน์ · ตัวละครที่คุณเล่นอยู่", "online": true,
			"current": String(lead.kind) == "hero", "me": true})
	return rows


func open_leader_picker(g: int) -> void:
	close_leader_picker()
	var t := WorldPresence.clock()
	var box := UIUtil.vbox(8)
	var hint := UIUtil.label("กิลด์ %s · หัวหน้ากิลด์คนเดียวที่ยึดแท่นปราสาทได้ในสงครามกิลด์ (สมาชิกที่เป็นหัวหน้าลงสนามด้วยค่าสถานะสายแทงก์ของตัวเอง)" % WorldPlayers.guild_name(g), &"SmallLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := UIUtil.vbox(6)
	list.name = "LeaderChoices"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var k := 0
	for r in leader_choices(g, t):
		list.add_child(_choice_card(g, r, k))
		k += 1
	var sheet_size := Vector2(minf(900.0, maxf(560.0, _root.size.x - 80.0)), minf(600.0, maxf(380.0, _root.size.y - 60.0)))
	_picker = OverlaySheet.open(_root, "เลือกหัวหน้ากิลด์ %s" % WorldPlayers.guild_name(g), box, sheet_size)
	_picker.name = "LeaderPicker"
	_picker.closed.connect(func(): _picker = null)


func close_leader_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


func _choice_card(g: int, r: Dictionary, k: int) -> Control:
	var panel := UIUtil.panel(&"CardPanel")
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var dot := UIUtil.label("●", &"BoldLabel")
	dot.add_theme_color_override("font_color", Color("6dff9a") if bool(r.online) else Color("667788"))
	line.add_child(dot)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var title := UIUtil.label("%s  ·  %s" % [String(r.name), ClassData.get_class_data(StringName(r["class"])).name], &"BoldLabel")
	title.clip_text = true
	if bool(r.current):
		title.add_theme_color_override("font_color", Color("ffd84a"))
	info.add_child(title)
	var detail := UIUtil.label("%s · %s" % [String(r.level_text), String(r.where)], &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var choose := UIUtil.button("หัวหน้าตอนนี้" if bool(r.current) else "เลือก", &"" if bool(r.current) else &"PrimaryButton", Vector2(150, 58))
	choose.name = "Pick_%d" % k
	choose.set_meta("pick", String(r.pick))
	choose.disabled = bool(r.current)
	choose.pressed.connect(func(): choose_leader(g, String(r.pick), String(r.name)))
	line.add_child(choose)
	return panel


## Saves the pick, closes the picker and updates the leader line.
func choose_leader(g: int, pick: String, shown: String) -> bool:
	if not Game.set_guild_leader(g, pick):
		Game.say("เลือกหัวหน้ากิลด์ไม่ได้ — สมาชิกคนนี้ไม่ได้อยู่ในกิลด์แล้ว", &"warning")
		return false
	AudioManager.play_ui(&"ui_open")
	var name_shown := shown if pick != "" else "คุณ"
	Game.say("หัวหน้ากิลด์ %s: %s" % [WorldPlayers.guild_name(g), name_shown], &"success")
	# Game.guild_changed rebuilds the open screen with the new leader line.
	close_leader_picker()
	return true
