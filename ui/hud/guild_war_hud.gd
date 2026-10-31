class_name GuildWarHud
extends Control
## Guild-war overlay: the score and clock, who holds the castle (always shown: ยังไม่มี
## ผู้ครองปราสาท until a guild takes it, then that guild's name in its colour), who is taking
## the altar right now, both guilds' fighters with their HP (one compact row per guild, you
## first) and the hero's respawn countdown. The war's news (kills, plans, gates, captures)
## goes to the chat box (Game.channel_chat on CHAT_CHANNEL), not over the field.

## The chat channel the war's news goes to (WorldChat tags it [สงคราม]).
const CHAT_CHANNEL := "war"
## One cell per fighter: eight of these with their gaps fit inside the board's width on a phone.
const CELL_WIDTH := 64
const CELL_GAP := 3
const BOARD_WIDTH := GuildWarData.TEAM_SIZE * CELL_WIDTH + (GuildWarData.TEAM_SIZE - 1) * CELL_GAP
const ALLY_COLOR := Color("8fd0ff")
const ENEMY_COLOR := Color("ff9a8a")
const NEWS_COLOR := Color("ffe08a")
const TAKING_COLOR := Color("ffb15a")

var match_node: GuildWarMatch
var _score: Label
var _clock: Label
var _owner: Label
var _taking: Label
var _rows: Array = [[], []]
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
	for team in 2:
		var row := UIUtil.hbox(CELL_GAP)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_child(row)
		for i in GuildWarData.TEAM_SIZE:
			var cell := VBoxContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.custom_minimum_size = Vector2(CELL_WIDTH, 0)
			cell.add_theme_constant_override("separation", 0)
			var name_label := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			name_label.add_theme_constant_override("outline_size", 5)
			name_label.clip_text = true
			name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.add_child(name_label)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 8)
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(bar)
			row.add_child(cell)
			_rows[team].append([cell, name_label, bar])
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
	_taking.visible = _taking.text != ""
	_tell_gate(m, force)
	for team in 2:
		var fighters := m.allies if team == 0 else m.enemies
		for i in GuildWarData.TEAM_SIZE:
			var entry: Array = _rows[team][i]
			var cell: Control = entry[0]
			var name_label: Label = entry[1]
			var bar: ProgressBar = entry[2]
			# Slot 0 of our guild is the hero.
			var index := i - 1 if team == 0 else i
			if team == 0 and i == 0:
				name_label.text = "คุณ"
				name_label.add_theme_color_override("font_color", Color.WHITE)
				var hp_max := float(m.hero.stats.max_hp) if m.hero != null else 1.0
				bar.value = float(Game.profile.hp) / maxf(hp_max, 1.0) if m.hero_respawn_left <= 0.0 else 0.0
				cell.modulate = Color.WHITE if m.hero_respawn_left <= 0.0 else Color(1, 1, 1, 0.45)
				UIUtil.tint_hp_bar(bar, bar.value)
				continue
			# A smaller war (fewer members at Lv.100) leaves the extra cells out.
			cell.visible = index >= 0 and index < fighters.size()
			if not cell.visible or not is_instance_valid(fighters[index]):
				continue
			var f: GuildFighter = fighters[index]
			name_label.text = String(f.member.name)
			# The hero's party in its own green (they stand first in our row).
			name_label.add_theme_color_override("font_color", GuildWarMatch.PARTY_COLOR if f.in_hero_party() else (ALLY_COLOR if team == 0 else ENEMY_COLOR))
			bar.value = 0.0 if f.is_dead() else f.hp_ratio()
			cell.modulate = Color(1, 1, 1, 0.45) if f.is_dead() else Color.WHITE
			UIUtil.tint_hp_bar(bar, bar.value)
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
