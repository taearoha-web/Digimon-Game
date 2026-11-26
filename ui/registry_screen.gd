class_name RegistryScreen
extends CanvasLayer
## The game registry: everyone who plays this world (the hero and the world players) with
## class, level and stars, guild and whereabouts, strongest first, filtered by all / online /
## a guild / the party, so the hero knows where to find someone: a player joins the party
## when the hero walks up and taps them (PlayerCard). Party members can be let go here.
## Opened from the online count on the HUD and from the registrar in the village; it
## follows the schedules while open. The world grows by 10-15 newcomers a day, so the list
## comes in pages of PAGE_ROWS (◀ หน้า n/N ▶) with a name search: everyone can be found,
## only the page shown is built, and the hero, its other characters and its party stay
## pinned above every page.

signal closed()

const REFRESH := 10.0
## Rows of one page (the best first). The hero, its other characters and its party are
## pinned on top of every page besides.
const PAGE_ROWS := 50
const FILTERS := [["all", "ทั้งหมด"], ["online", "ออนไลน์"], ["alpha", "Alpha"], ["neverdie", "Neverdie"], ["titan", "Titan"], ["3dlnw", "3DLnw"], ["party", "ปาร์ตี้"]]

var is_open := false
var filter := "all"
## The page shown (from 0) and the name searched for ("" everyone).
var page := 0
var search := ""
var _root: Control
var _body: Control
var _timer := 0.0
## Everyone at the last refresh (rows), so a page, a filter or a letter typed needs no new reads.
var _all: Array[Dictionary] = []
var _t := 0.0
var _title: Label
var _chips: Array[Button] = []
var _search_box: LineEdit
var _party_line: Label
var _scroll: TouchScroll
var _list: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button


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
	Game.party_roster_changed.connect(func():
		if is_open:
			_build())


func open_screen(start_filter := "all") -> void:
	filter = start_filter
	page = 0
	search = ""
	is_open = true
	# The game keeps running under it (auto-hunt goes on; Main._screen_open holds back world taps).
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_timer = REFRESH
	_build()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	# A closed screen keeps nothing: its lists are built again when it opens.
	UIUtil.clear(_body)
	_all = []
	_chips.clear()
	_title = null
	closed.emit()


func _process(delta: float) -> void:
	if not is_open:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_refresh()


## Everyone in the registry at time t (newcomers from the day they join): the hero first
## as a row like the others, and every other character of the account (every save slot,
## a damaged one too, by the name it still has), offline with its own class, level,
## stars, guild and records (`crown`: it holds หนึ่งในใต้หล้า, MazeCrown.mine_holds).
## A world player's row holds what the list sorts and filters by (index, name, class,
## guild, level, stars, online): its whereabouts (WorldPlayers.state) are read only for
## the rows of the page shown, so thousands of players cost a progress read each.
static func rows(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in WorldPlayers.size():
		if t >= WorldPlayers.joined_at(i):
			var e := WorldPlayers.entry(i)
			var p := WorldPlayers.progress_at(i, t)
			out.append({"index": i, "name": String(e.name), "class": String(e["class"]), "guild": WorldPlayers.guild_at(i, int(p.level)),
				"level": int(p.level), "stars": int(p.stars), "online": not WorldPlayers.session_at(i, t).is_empty()})
	if Game.has_profile:
		out.append({"index": -1, "name": String(Game.profile.get("name", "คุณ")), "class": Game.class_id(), "guild": Game.guild(),
			"level": int(Game.profile.level), "stars": int(Game.paragon().level), "online": true, "place": String(Game.current_zone), "you": true,
			"slot": Game.slot, "crown": MazeCrown.mine_holds(Game.slot, String(Game.profile.get("name", "")), t)})
	# The player's other characters (other save slots): listed though not played now.
	var listed := {}
	for alt in Game.all_alts():
		listed[int(alt.slot)] = true
		out.append({"index": -1, "name": String(alt.name), "class": String(alt["class"]), "guild": int(alt.guild),
			"level": int(alt.level), "stars": int(alt.stars), "online": false, "place": "", "alt": true, "slot": int(alt.slot),
			"crown": MazeCrown.mine_holds(int(alt.slot), String(alt.name), t)})
	# A slot whose file cannot be read as a hero (Game.slot_damaged) still shows by its name.
	for i in range(1, Game.SLOT_COUNT + 1):
		if listed.has(i) or (Game.has_profile and i == Game.slot) or not Game.has_save(i):
			continue
		var info := Game.slot_info(i)
		if info.is_empty():
			continue
		out.append({"index": -1, "name": String(info.get("name", "")) if String(info.get("name", "")) != "" else "ตัวละครช่อง %d" % i,
			"class": String(info.get("class", ClassData.DEFAULT)), "guild": 0, "level": int(info.get("level", 1)), "stars": int(info.get("stars", 0)),
			"online": false, "place": "", "alt": true, "slot": i, "damaged": bool(info.get("damaged", false)), "crown": false})
	out.sort_custom(func(a, b):
		var pa := int(a.level) * 1000 + int(a.stars)
		var pb := int(b.level) * 1000 + int(b.stars)
		if pa != pb:
			return pa > pb
		return String(a.name) < String(b.name))
	return out


func _shows(r: Dictionary) -> bool:
	match filter:
		"online": return bool(r.online)
		"alpha": return int(r.guild) == WorldPlayers.ALPHA
		"neverdie": return int(r.guild) == WorldPlayers.NEVERDIE
		"titan": return int(r.guild) == WorldPlayers.TITAN
		"3dlnw": return int(r.guild) == WorldPlayers.LNW
		"party": return bool(r.get("you", false)) or (not bool(r.get("alt", false)) and Game.in_party(int(r.index)))
	return true


## Whether row r's name holds the text searched for (any case; everyone for "").
func _matches(r: Dictionary) -> bool:
	return search == "" or String(r.name).findn(search) >= 0


## Pinned on top of every page: the hero, its other characters and its party.
static func _pinned(r: Dictionary) -> bool:
	return bool(r.get("you", false)) or bool(r.get("alt", false)) or Game.in_party(int(r.index))


## Reads everyone again (opening, every REFRESH seconds, the party changed) and shows the page.
func _build() -> void:
	_t = WorldPresence.clock()
	_all = rows(_t)
	if _title == null:
		_chrome()
	var online := 0
	for r in _all:
		online += 1 if bool(r.online) else 0
	_title.text = "ทะเบียนเกม — ผู้เล่น %d คน · ออนไลน์ %d คน" % [_all.size(), online]
	var names: PackedStringArray = []
	for m in Game.party():
		names.append(String(m.name))
	_party_line.text = "ปาร์ตี้ของคุณ %d/%d คน (รวมคุณ): %s · อยากชวนใคร ไปหาเขาที่แมพที่เขาอยู่แล้วแตะที่ตัว" % [names.size() + 1, Game.PARTY_SIZE, ", ".join(names) if not names.is_empty() else "ยังไม่มีใคร"]
	_fill(true)


## Every REFRESH seconds while open: who is online now (a look-up each), then the page
## again (its rows read whole). The order and the levels of the rows not shown stay as
## they were read on opening: a full read of a world of thousands is kept for opening it.
func _refresh() -> void:
	_t = WorldPresence.clock()
	var online := 0
	for r in _all:
		if int(r.index) >= 0:
			r["online"] = not WorldPlayers.session_at(int(r.index), _t).is_empty()
		online += 1 if bool(r.online) else 0
	_title.text = "ทะเบียนเกม — ผู้เล่น %d คน · ออนไลน์ %d คน" % [_all.size(), online]
	_fill(true)


## The parts that stay while the screen is open: the title, the filters, the search box,
## the pager and the list's scroll.
func _chrome() -> void:
	UIUtil.clear(_body)
	_chips.clear()
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var head := UIUtil.hbox(14)
	column.add_child(head)
	_title = UIUtil.label("", &"HeaderLabel")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var tabs := UIUtil.hbox(8)
	column.add_child(tabs)
	for f in FILTERS:
		var chip := UIUtil.button(String(f[1]), &"", Vector2(0, 50))
		chip.name = "Filter_%s" % f[0]
		chip.set_meta(&"filter", String(f[0]))
		chip.pressed.connect(func():
			filter = String(f[0])
			page = 0
			_fill())
		tabs.add_child(chip)
		_chips.append(chip)
	var tools := UIUtil.hbox(8)
	column.add_child(tools)
	_search_box = LineEdit.new()
	_search_box.name = "Search"
	_search_box.placeholder_text = "ค้นหาชื่อผู้เล่น"
	_search_box.custom_minimum_size = Vector2(0, 52)
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.clear_button_enabled = true
	_search_box.max_length = 24
	_search_box.text = search
	_search_box.text_changed.connect(func(text: String):
		search = text.strip_edges()
		page = 0
		_fill())
	_search_box.text_submitted.connect(func(_text: String): _search_box.release_focus())
	tools.add_child(_search_box)
	_prev = UIUtil.button("◀", &"", Vector2(64, 52))
	_prev.name = "PagePrev"
	_prev.pressed.connect(func(): _turn(-1))
	tools.add_child(_prev)
	_page_label = UIUtil.label("", &"BoldLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.name = "PageLabel"
	_page_label.custom_minimum_size = Vector2(150, 0)
	_page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tools.add_child(_page_label)
	_next = UIUtil.button("▶", &"", Vector2(64, 52))
	_next.name = "PageNext"
	_next.pressed.connect(func(): _turn(1))
	tools.add_child(_next)
	_party_line = UIUtil.label("", &"SmallLabel")
	_party_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_party_line)
	_scroll = TouchScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = UIUtil.vbox(5)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


## Turns the page by `step` (the list starts again at its top).
func _turn(step: int) -> void:
	page += step
	_fill()


## How many pages the rows passing the filter and the search take (pinned ones aside).
func page_count() -> int:
	var n := 0
	for r in _all:
		if _shows(r) and _matches(r) and not _pinned(r):
			n += 1
	return maxi(1, ceili(float(n) / float(PAGE_ROWS)))


## Builds the rows of the page shown (from the rows read last): the pinned ones that pass
## the filter and the search, then the page's PAGE_ROWS. `keep` keeps the scroll where it was.
func _fill(keep := false) -> void:
	if _list == null:
		return
	var kept := _scroll.retained_vertical_position() if keep else 0
	for chip in _chips:
		chip.theme_type_variation = &"PrimaryButton" if String(chip.get_meta(&"filter")) == filter else &""
	UIUtil.clear(_list)
	var pinned: Array[int] = []
	var listed: Array[int] = []
	for k in _all.size():
		var r := _all[k]
		if not _shows(r) or not _matches(r):
			continue
		if _pinned(r):
			pinned.append(k)
		else:
			listed.append(k)
	var pages := maxi(1, ceili(float(listed.size()) / float(PAGE_ROWS)))
	page = clampi(page, 0, pages - 1)
	_page_label.text = "หน้า %d/%d" % [page + 1, pages]
	_prev.disabled = page <= 0
	_next.disabled = page >= pages - 1
	for k in pinned:
		_list.add_child(_row(k + 1, _all[k], _t))
	var from := page * PAGE_ROWS
	for k in listed.slice(from, from + PAGE_ROWS):
		_list.add_child(_row(k + 1, _all[k], _t))
	if listed.is_empty() and search != "":
		_list.add_child(UIUtil.label("ไม่พบผู้เล่นชื่อ \"%s\"" % search, &"SmallLabel"))
	elif pages > 1:
		_list.add_child(UIUtil.label("อันดับ %d-%d จาก %d คน · กด ◀ ▶ เพื่อดูหน้าอื่น หรือค้นหาชื่อ" % [from + 1, mini(from + PAGE_ROWS, listed.size()), listed.size()], &"SmallLabel"))
	_scroll.restore_vertical_position(kept)


func _row(rank: int, r: Dictionary, t: float) -> Control:
	var you := bool(r.get("you", false))
	var alt := bool(r.get("alt", false))
	var i := int(r.index)
	var s := {}
	if not you and not alt and i >= 0:
		# A row shown is read whole (where it is, its level now).
		s = WorldPlayers.state(i, t)
		for key in ["level", "stars", "guild", "online"]:
			r[key] = s[key]
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Row_%s" % ("you" if you else ("alt%d" % int(r.slot) if alt else str(i)))
	var line := UIUtil.hbox(10)
	panel.add_child(line)
	var num := UIUtil.label("#%d" % rank, &"BoldLabel")
	num.custom_minimum_size = Vector2(56, 0)
	line.add_child(num)
	var dot := UIUtil.label("●", &"BoldLabel")
	dot.add_theme_color_override("font_color", Color("6dff9a") if bool(r.online) else Color("667788"))
	line.add_child(dot)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var who := UIUtil.label("%s%s  ·  %s%s" % [r.name, " (คุณ)" if you else (" (ตัวละครของคุณ)" if alt else ""), ClassData.get_class_data(StringName(r["class"])).name,
		"  ·  %s %s" % [MazeCrown.CROWN, MazeCrown.TITLE_NAME] if bool(r.get("crown", false)) else ""], &"BoldLabel")
	if you or alt:
		who.add_theme_color_override("font_color", UIPalette.GOLD)
	info.add_child(who)
	var where := "ตัวละครของคุณ" if you else (("ตัวละครของคุณ · ออฟไลน์ ไม่ได้เล่นอยู่ (ช่องเซฟ %d)%s" % [int(r.slot), " · ไฟล์เซฟเสียหาย" if bool(r.get("damaged", false)) else ""]) if alt \
		else ("ออนไลน์ · ปาร์ตี้กับคุณ" if Game.in_party(i) else WorldPlayers.where_text(s, t)))
	var detail := UIUtil.label(where, &"SmallLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var g := int(r.guild)
	var guild := UIUtil.label(WorldPlayers.guild_name(g) if g > 0 else "ไม่มีกิลด์", &"SmallLabel")
	guild.custom_minimum_size = Vector2(110, 0)
	if g > 0:
		guild.add_theme_color_override("font_color", WorldPlayers.GUILD_COLORS[g])
	line.add_child(guild)
	var level := UIUtil.label(WorldPlayers.level_text(r), &"BoldLabel")
	level.custom_minimum_size = Vector2(130, 0)
	line.add_child(level)
	if not you and not alt and Game.in_party(i):
		var button := UIUtil.button("ออกจากปาร์ตี้", &"", Vector2(170, 52))
		button.pressed.connect(func(): Game.party_kick(i, "%s ออกจากปาร์ตี้แล้ว" % r.name))
		button.name = "Party_%d" % i
		line.add_child(button)
	return panel
