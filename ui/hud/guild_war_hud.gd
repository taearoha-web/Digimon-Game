class_name GuildWarHud
extends Control
## Guild-war overlay: the score and clock, both guilds' five fighters with their HP,
## a short kill feed and the hero's respawn countdown.

const FEED_LINES := 4
const FEED_SECONDS := 6.0
const ALLY_COLOR := Color("8fd0ff")
const ENEMY_COLOR := Color("ff9a8a")

var match_node: GuildWarMatch
var _score: Label
var _clock: Label
var _orb: Label
var _rows: Array = [[], []]
var _feed_labels: Array[Label] = []
var _feed_age: Array[float] = []
var _respawn: Label
var _refresh := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := UIUtil.vbox(3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -250
	top.offset_right = 250
	top.offset_top = 6
	add_child(top)
	var board := UIUtil.panel(&"HudPanel")
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(board)
	var line := UIUtil.hbox(14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(line)
	_score = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(_score)
	_clock = UIUtil.label("", &"HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	line.add_child(_clock)
	_orb = UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_orb.add_theme_color_override("font_color", GuildWarMatch.ORB_COLOR)
	top.add_child(_orb)
	for team in 2:
		var row := UIUtil.hbox(4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_child(row)
		for i in 5:
			var cell := VBoxContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.custom_minimum_size = Vector2(96, 0)
			cell.add_theme_constant_override("separation", 0)
			var name_label := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.clip_text = true
			cell.add_child(name_label)
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(0, 8)
			bar.show_percentage = false
			bar.max_value = 1.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(bar)
			row.add_child(cell)
			_rows[team].append([cell, name_label, bar])
	var feed := UIUtil.vbox(1)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(feed)
	for i in FEED_LINES:
		var label := UIUtil.label("", &"SmallLabel", HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_font_size_override("font_size", 15)
		feed.add_child(label)
		_feed_labels.append(label)
		_feed_age.append(99.0)
	_respawn = UIUtil.label("", &"TitleLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_respawn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_respawn.offset_top = 40
	_respawn.add_theme_font_size_override("font_size", 56)
	_respawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_respawn)


func bind(m: GuildWarMatch) -> void:
	match_node = m
	m.feed.connect(_on_feed)
	_update(0.0, true)


func _process(delta: float) -> void:
	for i in FEED_LINES:
		_feed_age[i] += delta
		_feed_labels[i].modulate.a = clampf(1.0 - (_feed_age[i] - (FEED_SECONDS - 1.0)), 0.0, 1.0)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update(delta, false)


func _update(_delta: float, force: bool) -> void:
	if match_node == null or not is_instance_valid(match_node):
		return
	var m := match_node
	_score.text = "%s  %d : %d  %s" % [m.ally_name, m.score[0], m.score[1], m.enemy_name]
	var left := int(ceil(m.time_left))
	_clock.text = "ต่อเวลา!" if m.overtime else "%d:%02d" % [left / 60, left % 60]
	_orb.text = "ออร์บพลังรออยู่กลางสนาม!" if m.orb_active else ""
	for team in 2:
		var fighters := m.allies if team == 0 else m.enemies
		for i in 5:
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
			if index < 0 or index >= fighters.size() or not is_instance_valid(fighters[index]):
				continue
			var f: GuildFighter = fighters[index]
			name_label.text = String(f.member.name)
			name_label.add_theme_color_override("font_color", ALLY_COLOR if team == 0 else ENEMY_COLOR)
			bar.value = 0.0 if f.is_dead() else f.hp_ratio()
			cell.modulate = Color(1, 1, 1, 0.45) if f.is_dead() else Color.WHITE
			UIUtil.tint_hp_bar(bar, bar.value)
	if m.hero_respawn_left > 0.0:
		_respawn.text = "เกิดใหม่ใน %d" % int(ceil(m.hero_respawn_left))
	else:
		_respawn.text = ""


func _on_feed(text: String, team: int) -> void:
	for i in range(FEED_LINES - 1, 0, -1):
		_feed_labels[i].text = _feed_labels[i - 1].text
		_feed_labels[i].add_theme_color_override("font_color", _feed_labels[i - 1].get_theme_color("font_color", "Label"))
		_feed_age[i] = _feed_age[i - 1]
	_feed_labels[0].text = text
	_feed_labels[0].add_theme_color_override("font_color", ALLY_COLOR if team == GuildFighter.TEAM_ALLY else ENEMY_COLOR)
	_feed_age[0] = 0.0
