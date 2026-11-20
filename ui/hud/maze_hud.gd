class_name MazeHud
extends Control
## The hero's own line of เขาวงกตหนึ่งในใต้หล้า on the HUD while inside: a small strip in
## the corner under the minimap — "อันดับ 12/52 · 9 คิล" and, only while it matters, the
## hero's shrine or guard ("ที่หลบภัย 7 วิ", "ไม่มีใครทำร้ายได้"). The full board (who
## killed how many) lives in the game menu's "หนึ่งในใต้หล้า" tab (MazeBoardView), like the
## bag or the skills; a tap on the strip opens it (board_requested). Redrawn when a count
## changes (MazeWar.revision) and twice a second for the shrine's clock.

signal board_requested

const WIDTH := 210.0
const HERO_COLOR := Color("8fffb0")
const SAFE_COLOR := Color("8ff7ff")

var match_node: MazeMatch
var _mine: Label
var _status: Label
var _timer := 0.0
var _rev := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UIUtil.panel(&"HudPanel")
	panel.name = "MazeStrip"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = HUD.TRACKER_RIGHT - WIDTH
	panel.offset_right = HUD.TRACKER_RIGHT
	panel.offset_top = HUD.TRACKER_TOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "แตะเพื่อดูตารางอันดับเต็ม"
	panel.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			board_requested.emit())
	add_child(panel)
	var col := UIUtil.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var line := UIUtil.hbox(6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	var tag := _small(line, MazeWar.COLOR, 14)
	tag.text = "เขาวงกต"
	_mine = _small(line, HERO_COLOR, 16)
	_mine.name = "MazeMine"
	_mine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var more := _small(line, Color(1, 1, 1, 0.7), 16)
	more.text = "›"
	_status = _small(col, SAFE_COLOR, 14)
	_status.name = "MazeStatus"
	_status.visible = false


func _small(parent: Control, color: Color, size: int) -> Label:
	var l := UIUtil.label("", &"SmallLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func bind(m: MazeMatch) -> void:
	match_node = m
	refresh()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	if MazeWar.revision != _rev:
		refresh()
	_update_status()


## Redraws the hero's line (MazeWar.hero_rank now).
func refresh() -> void:
	_rev = MazeWar.revision
	var t := MazeWar.now()
	var mine := MazeWar.hero_rank(MazeWar.week_of(t), t)
	_mine.text = "อันดับ %d/%d · %d คิล" % [int(mine.rank), int(mine.of), int(mine.kills)] if int(mine.rank) > 0 else "ยังไม่มีอันดับ"


func _update_status() -> void:
	var text := ""
	if match_node != null and is_instance_valid(match_node):
		if match_node.hero_sheltered():
			text = "ที่หลบภัย: ปลอดภัยอีก %d วิ" % int(ceil(match_node.shelter_left()))
		elif match_node.hero_protected():
			text = "ไม่มีใครทำร้ายได้ชั่วครู่"
	_status.text = text
	_status.visible = text != ""
