class_name GuildWarLobby
extends CanvasLayer
## The guild war's waiting room on screen (GuildWarMatch.lobby_until): "สงครามเริ่มใน 4:32"
## top-centre under the war board, a big 10-9-8... in the last ten seconds, then "เริ่ม!",
## and a button back to town (the hero may come back until the bell).

const BIG_FROM := 10.0
## How long "เริ่ม!" stays up once the war begins.
const GO_SHOWN := 1.5

var _banner: Label
var _big: Label
var _leave: Button
var _go_left := -1.0


func _ready() -> void:
	layer = 11
	name = "GuildWarLobby"
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var top := UIUtil.vbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -260
	top.offset_right = 260
	top.offset_top = 250  # below the war board (GuildWarHud) at the top centre
	root.add_child(top)
	_banner = _outlined(UIUtil.label("", &"HeaderLabel"), 40)
	_banner.name = "LobbyBanner"
	top.add_child(_banner)
	_leave = UIUtil.button("ออกจากห้องรอ (กลับเมือง)", &"", Vector2(0, 54))
	_leave.name = "LobbyLeave"
	_leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_leave.pressed.connect(leave)
	top.add_child(_leave)
	_big = _outlined(UIUtil.label("", &"HeaderLabel"), 150)
	_big.name = "LobbyCount"
	_big.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_big.grow_vertical = Control.GROW_DIRECTION_BOTH
	_big.visible = false
	root.add_child(_big)


static func _outlined(label: Label, size: int) -> Label:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("ffe9a8"))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.04, 0.0))
	label.add_theme_constant_override("outline_size", maxi(8, size / 8))
	return label


## "สงครามเริ่มใน 4:32" for `left` seconds to the start.
static func banner_text(left: float) -> String:
	var s := maxi(0, int(ceil(left)))
	return "สงครามเริ่มใน %d:%02d" % [s / 60, s % 60]


## The big count: "10".."1" in the last BIG_FROM seconds, "เริ่ม!" at the start, "" before.
static func count_text(left: float) -> String:
	if left <= 0.0:
		return "เริ่ม!"
	if left <= BIG_FROM:
		return str(int(ceil(left)))
	return ""


## Seconds to the start (GuildWarMatch._tick_lobby, every frame while waiting).
func show_left(left: float) -> void:
	if _banner == null:
		return
	_banner.text = banner_text(left)
	var big := count_text(left)
	if big != _big.text and big != "":
		AudioManager.play_sfx(&"coin", -2.0)
	_big.text = big
	_big.visible = big != ""


## The war began: "เริ่ม!" for a moment, then gone.
func started() -> void:
	if _banner == null:
		queue_free()
		return
	_banner.visible = false
	_leave.visible = false
	_big.text = count_text(0.0)
	_big.visible = true
	_go_left = GO_SHOWN


func _process(delta: float) -> void:
	if _go_left > 0.0:
		_go_left -= delta
		if _go_left <= 0.0:
			queue_free()


## Back to town (Main.go): nothing is kept, the hero may come in again until the bell.
func leave() -> void:
	var main := get_tree().get_first_node_in_group(&"game_main") if is_inside_tree() else null
	if main == null or bool(main.get("_traveling")):
		return
	Game.say("ออกจากห้องรอแล้ว — กลับเข้ารอได้ที่ผู้บัญชาการสงครามกิลด์จนกว่าสงครามจะเริ่ม", &"info")
	main.go(&"town", false, true)
