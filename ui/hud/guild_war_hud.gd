class_name GuildWarHud
extends Control
## Guild-war overlay: the score and clock, who holds the castle (always shown: ยังไม่มี
## ผู้ครองปราสาท until a guild takes it, then that guild's name in its colour), who is taking
## the altar right now and the hero's respawn countdown (the fighters' HP lives over their
## heads, no roster rows: they cluttered the top of the screen). The war's news (kills, plans, gates, captures)
## goes to the chat box (Game.channel_chat on CHAT_CHANNEL), not over the field.
## Once the gates are down a row under the board shows the castle's switch (สวิตช์: <guild>
## in that guild's colour, flickering while another guild fights for it) and whom the
## altar's barrier is open for (บาเรียเปิดให้ <guild>), the barrier's warning while our
## leader waits on the altar behind it (who to clear out of the circle), and a button that
## sends the hero's party to take the switch.

## The chat channel the war's news goes to (WorldChat tags it [สงคราม]).
const CHAT_CHANNEL := "war"
## The board's width: it fits a phone's top centre.
const BOARD_WIDTH := 530
const ALLY_COLOR := Color("8fd0ff")
const ENEMY_COLOR := Color("ff9a8a")
const NEWS_COLOR := Color("ffe08a")
const TAKING_COLOR := Color("ffb15a")

var match_node: GuildWarMatch
var _score: Label
var _clock: Label
var _owner: Label
var _taking: Label
var _respawn: Label
## The switch's row: [switch chip, barrier chip] (PanelContainer with a Label), the
## barrier's warning and the party's button.
var _switch_row: HBoxContainer
var _chips: Array[PanelContainer] = []
var _barrier: Label
var _party_button: Button
var _pulse := 0.0
## The top column (board, capture line, switch row, warning).
var _top: VBoxContainer
## The bottom (logical px) of the guild-war board's column on screen, 0 without one: the
## toasts start under it and the switch's floating label hides above it (one lane each,
## nothing drawn over the board). The player's HUD and the spectator's board set it.
static var top_band := 0.0
var _refresh := 0.0
## The front gate's last quarter told in the chat (gate index * 4 + quarters left).
var _gate_mark := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := UIUtil.vbox(4)
	_top = top
	top.name = "TopColumn"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -BOARD_WIDTH * 0.5 - 10
	top.offset_right = BOARD_WIDTH * 0.5 + 10
	top.offset_top = 74  # below the target / boss bar that sits at the top centre
	add_child(top)
	var board := UIUtil.panel(&"HudPanel")
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(board)
	var lines := UIUtil.vbox(2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(lines)
	var line := UIUtil.hbox(14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(line)
	_score = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_score)
	_clock = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	line.add_child(_clock)
	# Who holds the castle, always on the board.
	_owner = _outlined(UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_owner.name = "CastleOwner"
	lines.add_child(_owner)
	# Who is taking the altar, only while someone stands on it.
	_taking = _outlined(UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_taking.name = "AltarCapture"
	_taking.add_theme_color_override("font_color", TAKING_COLOR)
	top.add_child(_taking)
	_switch_row = UIUtil.hbox(8)
	_switch_row.name = "SwitchRow"
	_switch_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_switch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(_switch_row)
	_party_button = UIUtil.button("ไปยึดสวิตช์", &"", Vector2(0, 44))
	_party_button.name = "PartySwitch"
	_party_button.add_theme_font_size_override("font_size", 15)
	_party_button.pressed.connect(press_party_switch)
	_switch_row.add_child(_party_button)
	for k in 2:
		var chip := UIUtil.chip(SiegeArena.SWITCH_NAME if k == 0 else "บาเรีย", Color("c9c9c9"), 17)
		chip.name = "SwitchChip" if k == 0 else "BarrierChip"
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_outlined(chip.get_child(0) as Label)
		var sb := chip.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.set_border_width_all(3)
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
		_chips.append(chip)
		_switch_row.add_child(chip)
	_switch_row.visible = false
	_barrier = _outlined(UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	_barrier.name = "BarrierWarning"
	_barrier.add_theme_color_override("font_color", Color("9fe0ff"))
	_barrier.visible = false
	top.add_child(_barrier)
	_respawn = UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_respawn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_respawn.offset_top = 40
	_respawn.add_theme_font_size_override("font_size", 56)
	_respawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_respawn)


static func _outlined(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func bind(m: GuildWarMatch) -> void:
	match_node = m
	m.feed.connect(_on_feed)
	_update(0.0, true)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update(delta, false)
	_pulse_chip(delta)
	# Hidden (the spectator's board up instead): that board keeps the band.
	if is_visible_in_tree():
		top_band = band_bottom()


func _exit_tree() -> void:
	top_band = 0.0


## The bottom of the top column on screen (logical px): the board and the rows under it.
func band_bottom() -> float:
	if _top == null:
		return 0.0
	return _top.get_global_rect().end.y


## The rects on screen of the board, the switch row, the capture line and the warning (tests).
func layout_rects() -> Dictionary:
	var out := {}
	for pair in [["board", _top.get_child(0)], ["taking", _taking], ["switch_row", _switch_row], ["warning", _barrier]]:
		var c := pair[1] as Control
		if c.is_visible_in_tree():
			out[pair[0]] = c.get_global_rect()
	return out


## The switch chip's text colour as drawn (tests): the label stays opaque while fought over.
func switch_label_alpha() -> float:
	var label := _chip_label(0)
	return (label.get_theme_color("font_color") * _chips[0].modulate * label.modulate * modulate).a


## The top bar's texts now (tests): [owner line, capture line].
func bar_texts() -> PackedStringArray:
	return PackedStringArray([_owner.text, _taking.text])


## The switch's row now (tests): [switch chip, barrier chip, barrier warning].
func switch_texts() -> PackedStringArray:
	return PackedStringArray([_chip_label(0).text, _chip_label(1).text, _barrier.text if _barrier.visible else ""])


func _chip_label(k: int) -> Label:
	return _chips[k].get_child(0) as Label


## The switch chip's colour now (tests).
func switch_chip_color() -> Color:
	var sb := _chips[0].get_theme_stylebox("panel") as StyleBoxFlat
	return sb.border_color if sb != null else Color.BLACK


## The party button: the hero's party goes to take the switch (pressed again: back to the plan).
func press_party_switch() -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	var said := match_node.order_party_switch()
	if said != "":
		Game.say(said, &"info")
	_update(0.0, false)


func _update_switches(m: GuildWarMatch) -> void:
	var shown := m.front_gate() == null and m.state in ["fight", "ending"]
	_switch_row.visible = shown
	var color := m.switch_color()
	for k in _chips.size():
		var label := _chip_label(k)
		label.text = m.switch_text() if k == 0 else m.barrier_open_text()
		# Solid dark backing, light text with an outline: readable on snow and on stone.
		label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.6))
		var sb := _chips[k].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.bg_color = Color(color.darkened(0.72), 0.92)
			sb.border_color = color
	_chips[0].modulate = Color.WHITE
	_party_button.visible = shown and not m.mirror and not m.hero_party_members().is_empty()
	_party_button.modulate = Color("9dff9a") if m.party_switch else Color.WHITE
	var warn := m.barrier_line()
	_barrier.text = warn
	_barrier.visible = warn != ""


## Fought over: only the switch chip's border and backing swing between the holder's and
## the challenger's colours (the text stays fully opaque).
func _pulse_chip(delta: float) -> void:
	var m := match_node
	if m == null or not is_instance_valid(m) or _chips.is_empty() or not _switch_row.visible:
		return
	var sb := _chips[0].get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		return
	var color := m.switch_color()
	if m.switch_contested and m.switch_challenger >= 0:
		_pulse += delta
		var w := 0.5 + 0.5 * sin(_pulse * 7.0)
		var mix := color.lerp(m.team_color(m.switch_challenger), w)
		sb.border_color = mix
		sb.bg_color = Color(mix.darkened(0.72), 0.92)
	else:
		_pulse = 0.0


func _update(_delta: float, force: bool) -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	var m := match_node
	_score.text = m.score_line()
	var left := int(ceil(m.time_left))
	_clock.text = "ต่อเวลา!" if m.overtime else "%d:%02d" % [left / 60, left % 60]
	_owner.text = m.owner_line()
	_owner.add_theme_color_override("font_color", Color.WHITE if m.castle_owner < 0 else m.owner_color().lerp(Color.WHITE, 0.25))
	_taking.text = m.capture_line()
	_taking.add_theme_color_override("font_color", TAKING_COLOR if not m.capture.is_empty() else Color("bfe8ff"))
	_taking.visible = _taking.text != ""
	_update_switches(m)
	_tell_gate(m, force)
	if m.hero_respawn_left > 0.0:
		_respawn.text = "เกิดใหม่ใน %d" % int(ceil(m.hero_respawn_left))
	else:
		_respawn.text = ""


## The front gate's HP in the chat, each time it falls past a quarter (and on binding).
func _tell_gate(m: GuildWarMatch, force: bool) -> void:
	var gate := m.front_gate()
	if gate == null:
		return
	# The weaker of the front tier's gates.
	for g in m.front_gates():
		if float(g.hp) / float(maxi(1, g.max_hp)) < float(gate.hp) / float(maxi(1, gate.max_hp)):
			gate = g
	var quarters := int(ceil(4.0 * float(gate.hp) / float(maxi(1, gate.max_hp))))
	var mark := gate.gate_index * 4 + quarters
	if mark == _gate_mark:
		return
	var first := _gate_mark < 0
	_gate_mark = mark
	if force or first or quarters < 4:
		_post(m.gate_status(), NEWS_COLOR)


func _on_feed(text: String, team: int) -> void:
	var color := NEWS_COLOR if team < 0 else (ALLY_COLOR if team == GuildFighter.TEAM_ALLY else ENEMY_COLOR)
	if team > 0 and match_node != null and is_instance_valid(match_node) and match_node.team_count() > 2:
		color = match_node.team_color(team).lerp(Color.WHITE, 0.3)
	_post(text, color)


func _post(text: String, color: Color) -> void:
	Game.channel_chat.emit(CHAT_CHANNEL, "", text, color)
