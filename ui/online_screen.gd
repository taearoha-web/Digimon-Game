class_name OnlineScreen
extends CanvasLayer
## "ออนไลน์": the real players online now (Online), with what the hero can do with each:
## กระซิบ (whisper: the typing bar, whisper_requested), ชวนเข้าปาร์ตี้, ขอแลกของ and ท้าดวล
## (the last two only ask: Online.send("trade_req" / "duel_req"); the trade and duel
## screens answer them). The hero's real party is listed on top with ออกจากปาร์ตี้, and
## the leader can let a member go. Opened from the HUD's online count while connected
## (the game registry of the world players is one tap away) and by tapping a real
## player in the world (open_player puts them first). The game keeps running behind it.

signal closed()
## The hero wants to whisper to player id.
signal whisper_requested(id: String)
## The game registry (the world players) instead.
signal registry_requested()

const BUTTON := Vector2(124, 52)
const CLASS_BADGE := 34.0

var is_open := false
## The player tapped in the world: listed first and marked.
var focus_id := ""
var _root: Control
var _body: Control
var _dirty := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.9)
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
	for s in [Online.player_joined, Online.player_left]:
		(s as Signal).connect(func(_id: String): _dirty = true)
	Online.party_changed.connect(func(): _dirty = true)
	Online.disconnected.connect(func(): _dirty = true)
	Online.connected.connect(func(): _dirty = true)


func open_screen() -> void:
	focus_id = ""
	_open()


## Opens with player `id` first (tapped in the world).
func open_player(id: String) -> void:
	focus_id = id
	_open()


func _open() -> void:
	is_open = true
	_root.visible = true
	AudioManager.play_ui(&"ui_open")
	_build()


func close_screen() -> void:
	is_open = false
	_root.visible = false
	UIUtil.clear(_body)
	closed.emit()


func _process(_delta: float) -> void:
	if is_open and _dirty:
		_dirty = false
		_build()


func _build() -> void:
	UIUtil.clear(_body)
	var column := UIUtil.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 14
	column.offset_right = -14
	column.offset_top = 10
	column.offset_bottom = -10
	_body.add_child(column)
	var all := Online.players()
	var head := UIUtil.hbox(12)
	column.add_child(head)
	var title := UIUtil.label("ออนไลน์ — ผู้เล่นจริง %d คน" % all.size() if Online.is_online() else "ออนไลน์ — ยังไม่ได้เชื่อมต่อ", &"HeaderLabel")
	title.name = "OnlineTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var registry := UIUtil.button("ทะเบียนเกม", &"", Vector2(170, 60))
	registry.name = "Registry"
	registry.pressed.connect(func():
		close_screen()
		registry_requested.emit())
	head.add_child(registry)
	var close := UIUtil.button("ปิด", &"PrimaryButton", Vector2(140, 60))
	close.name = "Close"
	close.pressed.connect(close_screen)
	head.add_child(close)
	if not Online.is_online():
		var why := UIUtil.label("เข้าสู่ระบบบัญชี และเปิด \"เล่นออนไลน์\" ในตั้งค่า เพื่อพบผู้เล่นจริงคนอื่น ๆ", &"SmallLabel")
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(why)
		return
	column.add_child(_party_line())
	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := UIUtil.vbox(5)
	list.name = "Players"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if all.is_empty():
		list.add_child(UIUtil.label("ตอนนี้ยังไม่มีผู้เล่นจริงคนอื่นออนไลน์", &"SmallLabel"))
		return
	for id in order(all, focus_id, String(Game.current_zone)):
		list.add_child(_row(all[id]))


## Ids in the order the list shows them: the tapped one, the party, the same zone, then
## the rest strongest first.
static func order(all: Dictionary, focus: String, zone: String) -> Array:
	var members: Array = Online.party().get("members", [])
	var score := {}
	for id in all:
		var p: Dictionary = all[id]
		score[id] = (4_000_000 if id == focus else 0) + (2_000_000 if members.has(id) else 0) \
			+ (1_000_000 if String(p.zone) == zone else 0) + int(p.level) * 1000 + int(p.stars)
	var ids: Array = all.keys()
	ids.sort_custom(func(a, b) -> bool:
		if int(score[a]) != int(score[b]):
			return int(score[a]) > int(score[b])
		return String(a) < String(b))
	return ids


func _party_line() -> Control:
	var row := UIUtil.hbox(10)
	row.name = "PartyLine"
	var names: PackedStringArray = []
	for id in Online.party().get("members", []):
		if id != Online.my_id():
			names.append(Online.display_name(Online.player(id)))
	var text := "ปาร์ตี้ออนไลน์: %s%s" % [", ".join(names) if not names.is_empty() else "รอสมาชิก", " (คุณเป็นหัวหน้า)" if Online.is_leader() else ""] if Online.in_party() else "ยังไม่มีปาร์ตี้ผู้เล่นจริง · กด \"ชวนเข้าปาร์ตี้\" ที่ชื่อผู้เล่นด้านล่าง"
	var label := UIUtil.label(text, &"SmallLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if Online.in_party():
		var leave := UIUtil.button("ออกจากปาร์ตี้", &"", Vector2(170, 52))
		leave.name = "LeaveParty"
		leave.pressed.connect(func():
			Online.leave_party()
			AudioManager.play_ui(&"ui_cancel"))
		row.add_child(leave)
	return row


func _row(p: Dictionary) -> Control:
	var id := String(p.id)
	var member := (Online.party().get("members", []) as Array).has(id)
	var panel := UIUtil.panel(&"CardPanel")
	panel.name = "Row_%s" % id.validate_node_name()
	if id == focus_id:
		panel.modulate = Color(1.08, 1.08, 1.0)
	var line := UIUtil.hbox(8)
	panel.add_child(line)
	var cls := StringName(String(p.cls)) if String(p.cls) != "" else StringName(String((p.look as Dictionary).get("class", ClassData.START)))
	var data := ClassData.get_class_data(cls)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(CLASS_BADGE, CLASS_BADGE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = data.color
	style.set_corner_radius_all(int(CLASS_BADGE * 0.5))
	style.set_border_width_all(2)
	style.border_color = Color("7dff8a") if member else Color.WHITE
	badge.add_theme_stylebox_override("panel", style)
	var letter := UIUtil.label(String(data.badge), &"HudLabel", HORIZONTAL_ALIGNMENT_CENTER)
	letter.add_theme_font_size_override("font_size", 14)
	badge.add_child(letter)
	line.add_child(badge)
	var info := UIUtil.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(info)
	var stars := int(p.stars)
	var who := UIUtil.label("%s  Lv.%d%s  ·  %s" % [Online.display_name(p), int(p.level), " ★%d" % stars if stars > 0 else "", data.name], &"BoldLabel")
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if member:
		who.add_theme_color_override("font_color", Color("7dff8a"))
	info.add_child(who)
	var zone_name := String(ZoneData.get_zone(StringName(String(p.zone))).get("name", String(p.zone))) if String(p.zone) != "" else "-"
	var where := UIUtil.label("ผู้เล่นจริง · %s%s" % [zone_name, " · ปาร์ตี้ของคุณ" if member else ""], &"SmallLabel")
	where.add_theme_color_override("font_color", Color("6dffd0"))
	info.add_child(where)
	var whisper := UIUtil.button("กระซิบ", &"", BUTTON)
	whisper.name = "Whisper"
	whisper.pressed.connect(func():
		close_screen()
		whisper_requested.emit(id))
	line.add_child(whisper)
	if member and Online.is_leader():
		var kick := UIUtil.button("เชิญออก", &"", BUTTON)
		kick.name = "Kick"
		kick.pressed.connect(func():
			Online.kick(id)
			Game.say("เชิญ %s ออกจากปาร์ตี้" % Online.display_name(p), &"info"))
		line.add_child(kick)
	else:
		var invite := UIUtil.button("ชวนเข้าปาร์ตี้", &"PrimaryButton" if not member else &"", BUTTON)
		invite.name = "Invite"
		invite.disabled = member
		invite.pressed.connect(func():
			Online.invite(id)
			Game.say("ส่งคำชวนเข้าปาร์ตี้ถึง %s แล้ว" % Online.display_name(p), &"info"))
		line.add_child(invite)
	var trade := UIUtil.button("ขอแลกของ", &"", BUTTON)
	trade.name = "Trade"
	trade.pressed.connect(func():
		Online.send("trade_req", {"to": id})
		Game.say("ขอแลกของกับ %s แล้ว รอคำตอบ…" % Online.display_name(p), &"info"))
	line.add_child(trade)
	var duel := UIUtil.button("ท้าดวล", &"", BUTTON)
	duel.name = "Duel"
	duel.pressed.connect(func():
		Online.send("duel_req", {"to": id})
		Game.say("ท้าดวล %s แล้ว รอคำตอบ…" % Online.display_name(p), &"info"))
	line.add_child(duel)
	return panel
