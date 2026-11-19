class_name AnnounceBanner
extends Control
## The server-wide announcement banner of the HUD (Announcer): one line that slides in
## from the right across a strip at the top centre of the screen, stays long enough to
## read and slides out to the left. Gold with a star for a jackpot drop, jade with a
## diamond for the rare dragon. Several arriving together wait their turn (at most
## QUEUE_MAX; the oldest waiting ones are dropped, they are in the world chat anyway) and
## the same text is never queued twice. A line wider than the strip scrolls across it
## instead of stopping. A short fanfare from the SFX set plays as each one comes in.
## It takes no input and sits in its own strip (Hud places it between the top bars and
## the toasts), so it never covers the skill buttons, the chat or the event chip.

const QUEUE_MAX := 6
const HEIGHT := 40.0
const FONT_SIZE := 22
## Seconds: sliding in, held in the middle, sliding out.
const SLIDE_IN := 0.45
const HOLD := 3.6
const SLIDE_OUT := 0.4
## A line wider than the strip crosses it at this speed (logical px a second).
const SCROLL_SPEED := 150.0
const ICONS := {"jackpot": "★", "rare": "◆", "crown": "♛"}
const SFX := {"jackpot": &"confirm_big", "rare": &"encounter", "crown": &"confirm_big"}

## The strip's bottom on screen while a line is up, 0 without: the toasts start under it
## (ToastLayer.lane_top), so a toast never lies on a banner.
static var band_bottom := 0.0

## Lines still to come: [{text, kind}], the next first.
var queue: Array = []
## The line on screen now ({} between two).
var current := {}
## Every line shown since the banner was made (tests).
var shown: Array = []
## While true nothing new starts (the guild war's board owns the top centre).
var hold := false
## How fast the slide runs (tests hurry it).
var speed := 1.0
var _pill: PanelContainer
var _icon: Label
var _label: Label
var _tween: Tween


func _ready() -> void:
	name = "AnnounceBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = HEIGHT
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.visible = false
	add_child(_pill)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	_pill.add_child(row)
	_icon = UIUtil.label("", &"SmallLabel")
	_icon.add_theme_font_size_override("font_size", FONT_SIZE)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_label = UIUtil.label("", &"SmallLabel")
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	Announcer.listen(push)


func _exit_tree() -> void:
	Announcer.unlisten(push)
	band_bottom = 0.0


## Queues an announcement ([param kind]: "jackpot" or "rare"); it starts at once when the
## strip is free.
func push(text: String, kind: String) -> void:
	if text == "" or String(current.get("text", "")) == text or queue.any(func(e): return String(e.text) == text):
		return
	queue.append({"text": text, "kind": kind})
	while queue.size() > QUEUE_MAX:
		queue.pop_front()
	_next()


func _process(_delta: float) -> void:
	band_bottom = get_global_rect().end.y if _pill.visible and is_visible_in_tree() else 0.0
	if current.is_empty() and not queue.is_empty() and not hold:
		_next()


func _next() -> void:
	if not current.is_empty() or queue.is_empty() or hold or not is_inside_tree():
		return
	current = queue.pop_front()
	shown.append(current)
	var kind := String(current.kind)
	var color: Color = Announcer.COLORS.get(kind, Announcer.COLORS.jackpot)
	_icon.text = String(ICONS.get(kind, "★"))
	_icon.add_theme_color_override("font_color", color)
	_label.text = String(current.text)
	_label.add_theme_color_override("font_color", color.lightened(0.35))
	_pill.add_theme_stylebox_override("panel", _style(color))
	_pill.visible = true
	_pill.modulate.a = 1.0
	_pill.reset_size()
	var w := _pill.get_combined_minimum_size().x
	_pill.size = Vector2(w, HEIGHT)
	_pill.position = Vector2(size.x, 0.0)
	AudioManager.play_sfx(SFX.get(kind, &"confirm_big"), -4.0, 0.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_speed_scale(speed)
	if w <= size.x:
		# It fits: in to the middle, a pause to read it, out to the left.
		_tween.tween_property(_pill, "position:x", (size.x - w) * 0.5, SLIDE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(HOLD)
		_tween.tween_property(_pill, "position:x", -w, SLIDE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		# Wider than the strip: it crosses it from end to end, pausing at both.
		_tween.tween_property(_pill, "position:x", 8.0, SLIDE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(1.0)
		_tween.tween_property(_pill, "position:x", size.x - w - 8.0, (w - size.x + 16.0) / SCROLL_SPEED)
		_tween.tween_interval(1.4)
		_tween.tween_property(_pill, "modulate:a", 0.0, SLIDE_OUT)
	_tween.tween_callback(_done)


func _done() -> void:
	_pill.visible = false
	current = {}
	_next()


static func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.14, 0.86)
	style.set_corner_radius_all(18)
	style.set_border_width_all(2)
	style.border_color = color
	style.content_margin_left = 16
	style.content_margin_right = 18
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## The pill's rect on screen while a line is up (tests: it stays in its strip).
func pill_rect() -> Rect2:
	return _pill.get_global_rect() if _pill.visible else Rect2()
