class_name GuildWarHud
extends Control
## Guild-war overlay: the score and clock, who holds the castle (always shown: ยังไม่มี
## ผู้ครองปราสาท until a guild takes it, then that guild's name in its colour), who is taking
## the altar right now and the hero's respawn countdown (the fighters' HP lives over their
## heads, no roster rows: they cluttered the top of the screen). The war's news (kills, plans, gates, captures)
## goes to the chat box (Game.channel_chat on CHAT_CHANNEL), not over the field.

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
var _refresh := 0.0
## The front gate's last quarter told in the chat (gate index * 4 + quarters left).
var _gate_mark := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := UIUtil.vbox(3)
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


## The top bar's texts now (tests): [owner line, capture line].
func bar_texts() -> PackedStringArray:
	return PackedStringArray([_owner.text, _taking.text])


func _update(_delta: float, force: bool) -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	var m := match_node
	_score.text = "%s  %d : %d  %s" % [m.ally_name, m.score[0], m.score[1], m.enemy_name]
	var left := int(ceil(m.time_left))
	_clock.text = "ต่อเวลา!" if m.overtime else "%d:%02d" % [left / 60, left % 60]
	_owner.text = m.owner_line()
	_owner.add_theme_color_override("font_color", Color.WHITE if m.castle_owner < 0 else m.owner_color().lerp(Color.WHITE, 0.25))
	_taking.text = m.capture_line()
	_taking.add_theme_color_override("font_color", TAKING_COLOR if not m.capture.is_empty() else Color("bfe8ff"))
	_taking.visible = _taking.text != ""
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
	var quarters := int(ceil(4.0 * float(gate.hp) / float(maxi(1, gate.max_hp))))
	var mark := gate.gate_index * 4 + quarters
	if mark == _gate_mark:
		return
	var first := _gate_mark < 0
	_gate_mark = mark
	if force or first or quarters < 4:
		_post("ประตูชั้นที่ %d/3 เหลือ %d%%" % [gate.gate_index + 1, int(ceil(100.0 * float(gate.hp) / float(maxi(1, gate.max_hp))))], NEWS_COLOR)


func _on_feed(text: String, team: int) -> void:
	_post(text, NEWS_COLOR if team < 0 else (ALLY_COLOR if team == GuildFighter.TEAM_ALLY else ENEMY_COLOR))


func _post(text: String, color: Color) -> void:
	Game.channel_chat.emit(CHAT_CHANNEL, "", text, color)
