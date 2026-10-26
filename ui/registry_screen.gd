class_name RegistryScreen
extends CanvasLayer
## The game registry: everyone who plays this world (the hero and the world players) with
## class, level and stars, guild and whereabouts, strongest first, filtered by all / online /
## a guild / the party. Online players can be asked to join the hero's party here
## (Game.party_invite) and party members let go. Opened from the online count on the HUD
## and from the registrar in the village; it follows the schedules while open.

signal closed()

const REFRESH := 10.0
const FILTERS := [["all", "ทั้งหมด"], ["online", "ออนไลน์"], ["alpha", "Alpha"], ["neverdie", "Neverdie"], ["party", "ปาร์ตี้"]]

var is_open := false
var filter := "all"
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
	Game.party_roster_changed.connect(func():
		if is_open:
			_build())


func open_screen(start_filter := "all") -> void:
	filter = start_filter
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


## Everyone in the registry at time t: the hero first as a row like the others.
static func rows(t: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in WorldPlayers.size():
		out.append(WorldPlayers.state(i, t))
	if Game.has_profile:
		out.append({"index": -1, "name": String(Game.profile.get("name", "คุณ")), "class": Game.class_id(), "guild": Game.guild(),
			"level": int(Game.profile.level), "stars": int(Game.paragon().level), "online": true, "place": String(Game.current_zone), "you": true})
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
		"party": return bool(r.get("you", false)) or Game.in_party(int(r.index))
	return true


func _build() -> void:
	var kept := -1
	var old := _body.find_children("*", "TouchScroll", true, false)
	if not old.is_empty():
		kept = (old[0] as TouchScroll).retained_vertical_position()
	UIUtil.clear(_body)
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var t := WorldPresence.clock()
	var all := rows(t)
	var online := 0
	for r in all:
		online += 1 if bool(r.online) else 0
	var head := UIUtil.hbox(14)
	column.add_child(head)
	var title := UIUtil.label("ทะเบียนเกม — ผู้เล่น %d คน · ออนไลน์ %d คน" % [all.size(), online], &"HeaderLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.pressed.connect(close_screen)
	head.add_child(close)
	var tabs := UIUtil.hbox(8)
	column.add_child(tabs)
	for f in FILTERS:
		var chip := UIUtil.button(String(f[1]), &"PrimaryButton" if filter == String(f[0]) else &"", Vector2(0, 50))
		chip.name = "Filter_%s" % f[0]
		chip.pressed.connect(func():
			filter = String(f[0])
			_build())
		tabs.add_child(chip)
	var names: PackedStringArray = []
	for m in Game.party():
		names.append(String(m.name))
	var party_line := UIUtil.label("ปาร์ตี้ของคุณ %d/%d: %s · ชวนผู้เล่นที่ออนไลน์เข้าปาร์ตี้ได้จากรายชื่อด้านล่าง" % [names.size(), Game.PARTY_MAX, ", ".join(names) if not names.is_empty() else "ยังไม่มีใคร"], &"SmallLabel")
	party_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(party_line)
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var rank := 0
	for r in all:
		rank += 1
		if _shows(r):
			list.add_child(_row(rank, r, t))
	if kept >= 0:
		scroll.restore_vertical_position(kept)


func _row(rank: int, r: Dictionary, t: float) -> Control:
	var you := bool(r.get("you", false))
	var i := int(r.index)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Row_%s" % ("you" if you else str(i))
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
	var who := UIUtil.label("%s%s  ·  %s" % [r.name, " (คุณ)" if you else "", ClassData.get_class_data(StringName(r["class"])).name], &"BoldLabel")
	if you:
		who.add_theme_color_override("font_color", UIPalette.GOLD)
	info.add_child(who)
	var where := "ตัวละครของคุณ" if you else ("ออนไลน์ · ปาร์ตี้กับคุณ" if Game.in_party(i) else WorldPlayers.where_text(r, t))
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
	if not you:
		var button: Button
		if Game.in_party(i):
			button = UIUtil.button("ออกจากปาร์ตี้", &"", Vector2(170, 52))
			button.pressed.connect(func(): Game.party_kick(i, "%s ออกจากปาร์ตี้แล้ว" % r.name))
		else:
			button = UIUtil.button("ชวนปาร์ตี้", &"PrimaryButton", Vector2(170, 52))
			button.disabled = not bool(r.online) or Game.party().size() >= Game.PARTY_MAX
			button.pressed.connect(func():
				var why := Game.party_invite(i)
				if why != "":
					Game.say(why, &"warning"))
		button.name = "Party_%d" % i
		line.add_child(button)
	return panel
