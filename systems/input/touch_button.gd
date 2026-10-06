class_name TouchButton
extends Control
## Round HUD button that works with multitouch (tracks its own finger index),
## unlike regular Buttons which only see the emulated first touch.

signal pressed()
signal released()
signal toggled(on: bool)

@export var text := ""
@export var icon: Texture2D
@export var radius := 60.0
@export var toggle_mode := false
@export var font_size_override := 0
@export var button_pressed := false
@export var accent := Color(0.2, 0.88, 1.0)
@export var disabled := false:
	set(value):
		disabled = value
		queue_redraw()

var _touch_index := -1
var _held := false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	_font = load("res://ui/theme/fonts/heading_font.tres")


func set_label(value: String) -> void:
	text = value
	queue_redraw()


func set_toggled(on: bool) -> void:
	button_pressed = on
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius * 1.1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_press()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_release()
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _touch_index == -1:
			_touch_index = -100
			_press()
		elif not event.pressed and _touch_index == -100:
			_touch_index = -1
			_release()
		accept_event()


func _press() -> void:
	if disabled:
		return
	_held = true
	if toggle_mode:
		button_pressed = not button_pressed
		toggled.emit(button_pressed)
	AudioManager.play_ui(&"ui_click")
	pressed.emit()
	queue_redraw()
	var tween := create_tween()
	pivot_offset = size * 0.5
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)


func _release() -> void:
	_held = false
	released.emit()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_touch_index = -1
		_held = false


func _draw() -> void:
	var center := size * 0.5
	var active := _held or (toggle_mode and button_pressed)
	var alpha := 0.35 if disabled else 1.0
	var fill := Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.45, 0.75 * alpha)
	if active:
		fill = Color(accent.r, accent.g, accent.b, 0.85 * alpha)
	draw_circle(center + Vector2(0, 4), radius, Color(0, 0, 0, 0.25 * alpha))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0, TAU, 64, Color(1, 1, 1, 0.8 * alpha), 3.0, true)
	draw_arc(center, radius - 7, 0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.6 * alpha), 2.0, true)
	var icon_size := radius * 0.9
	var text_y := center.y + radius * 0.32
	if icon:
		var rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5 - Vector2(0, radius * 0.12 if text != "" else 0.0), Vector2(icon_size, icon_size))
		draw_texture_rect(icon, rect, false, Color(1, 1, 1, alpha))
	else:
		text_y = center.y + 8
	if text != "" and _font:
		# Custom-drawn, so translate here (Controls only auto-translate their own text).
		var shown := L10n.t(text)
		var font_size := font_size_override if font_size_override > 0 else (22 if icon else 26)
		var w := _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
		draw_string_outline(_font, Vector2(center.x - w * 0.5, text_y + font_size * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.04, 0.12, alpha))
		draw_string(_font, Vector2(center.x - w * 0.5, text_y + font_size * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, alpha))
