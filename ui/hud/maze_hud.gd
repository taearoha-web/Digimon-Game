class_name MazeHud
extends Control
## The live board of เขาวงกตหนึ่งในใต้หล้า on the HUD while the hero is inside: under the
## minimap (where the quest lines go elsewhere), the week's countdown, the crown's holder,
## the top MazeWar.HUD_ROWS by kills, the hero's own place, and the hero's shrine or guard
## (time left in a shrine, "ไม่มีใครทำร้ายได้" while guarded). A tap on it opens the full
## board (board_requested). Redrawn when a count changes (MazeWar.revision) and every
## second for the clocks.

signal board_requested

const WIDTH := 300.0
const HERO_COLOR := Color("8fffb0")
const SAFE_COLOR := Color("8ff7ff")

var match_node: MazeMatch
var _rows: Label
var _head: Label
var _crown: Label
var _mine: Label
var _status: Label
var _timer := 0.0
var _rev := -1
## The rows' text last drawn (tests).
var shown_rows: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UIUtil.panel(&"HudPanel")
	panel.name = "MazeBoardPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = HUD.TRACKER_RIGHT - WIDTH
	panel.offset_right = HUD.TRACKER_RIGHT
	panel.offset_top = HUD.TRACKER_TOP
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			board_requested.emit())
	add_child(panel)
	var col := UIUtil.vbox(1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	_head = _small(col, MazeWar.COLOR)
	_crown = _small(col, MazeWar.COLOR.lerp(Color.WHITE, 0.3))
	_rows = _small(col, Color.WHITE)
	_rows.name = "MazeRows"
	_mine = _small(col, HERO_COLOR)
	_mine.name = "MazeMine"
	_status = _small(col, SAFE_COLOR)
	_status.name = "MazeStatus"
	var hint := _small(col, Color(1, 1, 1, 0.6))
	hint.text = "แตะเพื่อดูตารางเต็ม"


func _small(parent: Control, color: Color) -> Label:
	var l := UIUtil.label("", &"SmallLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_font_size_override("font_size", 15)
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


## Redraws the board (MazeWar.standings now).
func refresh() -> void:
	_rev = MazeWar.revision
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	_head.text = "%s · %s" % [MazeWar.TITLE, MazeWar.left_text(t)]
	var crown := MazeCrown.holder(t)
	_crown.text = "%s: %s" % [MazeCrown.TITLE_NAME, String(crown.name)] if not crown.is_empty() else "%s: ยังไม่มี" % MazeCrown.TITLE_NAME
	var board := MazeWar.standings(week, t)
	var lines := PackedStringArray()
	shown_rows.clear()
	for k in mini(MazeWar.HUD_ROWS, board.size()):
		var r: Dictionary = board[k]
		lines.append("%d. %s%s  %d" % [k + 1, String(r.name).left(14), " (คุณ)" if bool(r.hero) else "", int(r.kills)])
		shown_rows.append({"rank": k + 1, "name": String(r.name), "kills": int(r.kills)})
	if lines.is_empty():
		lines.append("ยังไม่มีใครล้มใคร")
	_rows.text = "\n".join(lines)
	var mine := MazeWar.hero_rank(week, t)
	_mine.text = "คุณ: อันดับ %d/%d · %d คิล" % [int(mine.rank), int(mine.of), int(mine.kills)] if int(mine.rank) > 0 else "คุณ: ยังไม่มีอันดับ"


func _update_status() -> void:
	if match_node == null or not is_instance_valid(match_node):
		_status.text = ""
		return
	if match_node.hero_sheltered():
		_status.text = "ที่หลบภัย: ปลอดภัยอีก %d วินาที" % int(ceil(match_node.shelter_left()))
	elif match_node.hero_protected():
		_status.text = "ไม่มีใครทำร้ายได้ชั่วครู่"
	else:
		_status.text = ""
	_status.visible = _status.text != ""
