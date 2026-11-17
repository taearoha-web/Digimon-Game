class_name WeeklyDropPopup
extends Control
## The weekly rare collection's drop pop-up (WeeklyCollect.picked): a card that pops in a
## little under the hero (Hud places it) when the hero picks up a piece, with its
## icon in a glow of its rank's colour, its rank and theme ("ของแรร์ตำนาน · ราตรีลอยกระทง"), the piece's name
## and how much of the week's set the hero carries ("ครบชุด 3/5 แบบ"). It stays HOLD
## seconds and fades; several in a row wait their turn (QUEUE_MAX, the same piece adds up
## instead of queueing twice). It takes no input. Made by Hud (one, kept for the session).

const QUEUE_MAX := 4
const HOLD := 2.6
const WIDTH := 360.0
const HEIGHT := 92.0

## Cards still to show: [{item, info}], the next first.
var queue: Array = []
## The card on screen ({} between two) and every card shown (tests).
var current := {}
var shown: Array = []
## How fast the cards run (tests hurry them).
var speed := 1.0
var _card: PanelContainer
var _glow: Panel
var _icon: TextureRect
var _head: Label
var _name: Label
var _set: Label
var _tween: Tween


func _ready() -> void:
	name = "WeeklyDropPopup"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	_card.size = Vector2(WIDTH, HEIGHT)
	add_child(_card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_card.add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(72, 72)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(holder)
	_glow = Panel.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_glow)
	_icon = UIUtil.texture_rect(null, Vector2(64, 64))
	_icon.name = "Icon"
	_icon.position = Vector2(4, 4)
	_icon.size = Vector2(64, 64)
	holder.add_child(_icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_head = _line(15)
	_head.text = "ของแรร์ประจำสัปดาห์!"
	_head.add_theme_color_override("font_color", WeeklyCollect.COLOR)
	col.add_child(_head)
	_name = _line(21)
	_name.name = "PieceName"
	col.add_child(_name)
	_set = _line(15)
	_set.name = "SetLine"
	_set.add_theme_color_override("font_color", Color("dfe8ff"))
	col.add_child(_set)
	WeeklyCollect.listen(push)


func _exit_tree() -> void:
	WeeklyCollect.unlisten(push)


func _line(font_size: int) -> Label:
	var l := UIUtil.label("", &"SmallLabel")
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	return l


## A piece the hero picked up (WeeklyCollect.picked): shown at once or after the others.
func push(item: Dictionary, info: Dictionary) -> void:
	var id := String(item.get("id", ""))
	for e in queue:
		if String(e.item.get("id", "")) == id:
			e.item["count"] = int(e.item.get("count", 1)) + int(item.get("count", 1))
			e.info = info
			return
	queue.append({"item": item.duplicate(), "info": info})
	while queue.size() > QUEUE_MAX:
		queue.pop_front()
	_next()


func _process(_delta: float) -> void:
	if current.is_empty() and not queue.is_empty():
		_next()


func _next() -> void:
	if not current.is_empty() or queue.is_empty() or not is_inside_tree():
		return
	current = queue.pop_front()
	shown.append(current)
	var item: Dictionary = current.item
	var info: Dictionary = current.info
	var rank := clampi(int(info.get("rank", 0)), 0, WeeklyCollect.PIECES - 1)
	var color: Color = WeeklyCollect.RANK_COLORS[rank]
	_icon.texture = ItemLook.icon(item)
	_glow.add_theme_stylebox_override("panel", _glow_style(color))
	var count := int(item.get("count", 1))
	_name.text = "%s%s" % [ItemData.name_of(item), " ×%d" % count if count > 1 else ""]
	_name.add_theme_color_override("font_color", color.lightened(0.3))
	_head.text = "ของแรร์%s · %s" % [WeeklyCollect.RANKS[rank], String(info.get("theme", ""))]
	_set.text = "สะสมครบชุด %d/%d แบบ · มีชิ้นนี้ %d" % [int(info.get("kinds", 0)), WeeklyCollect.PIECES, int(info.get("have", 0))]
	_card.add_theme_stylebox_override("panel", _card_style(color))
	_card.visible = true
	_card.modulate.a = 0.0
	_card.position = Vector2(size.x * 0.25 + 40.0, 0.0)
	_card.pivot_offset = Vector2(WIDTH * 0.5, HEIGHT * 0.5)
	_card.scale = Vector2(0.8, 0.8)
	AudioManager.play_sfx(&"confirm_big" if rank >= WeeklyCollect.PIECES - 2 else &"pickup", -3.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_speed_scale(speed)
	_tween.set_parallel(true)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.18)
	_tween.tween_property(_card, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD + 0.4 * float(rank))
	_tween.tween_property(_card, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(_done)


func _done() -> void:
	_card.visible = false
	current = {}
	_next()


static func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.15, 0.9)
	style.set_corner_radius_all(16)
	style.set_border_width_all(3)
	style.border_color = color
	style.shadow_color = Color(color.r, color.g, color.b, 0.45)
	style.shadow_size = 10
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func _glow_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.28)
	style.set_corner_radius_all(36)
	style.border_color = Color(color.r, color.g, color.b, 0.8)
	style.set_border_width_all(2)
	return style


## The card's rect on screen while one is up (tests: it stays on screen).
func card_rect() -> Rect2:
	return _card.get_global_rect() if _card.visible else Rect2()
