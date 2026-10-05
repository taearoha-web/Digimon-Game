class_name VirtualJoystick
extends Control
## Circular analog joystick for touch screens (not a D-pad).
##
## * Touch anywhere inside this control's rect (the "zone"); the finger is
##   tracked by index, so it works while other fingers use other controls.
## * Output is a normalised Vector2 (x = right, y = down) with a dead zone,
##   remapped so the usable range is 0..1.
## * The knob springs back to the centre on release.
## * Mouse input also works for desktop testing (emulated mouse events coming
##   from touches are ignored to avoid double handling).

signal input_changed(value: Vector2)
signal released()

const MOUSE_INDEX := -100

## Radius of the base ring in canvas units.
@export var base_radius := 104.0
@export var knob_radius := 46.0
@export_range(0.0, 0.9) var dead_zone := 0.14
## Move the base to where the finger lands (inside the zone) when true.
@export var follow_touch := false
## Distance from the zone's bottom-left corner to the resting centre.
@export var rest_offset := Vector2(150, -150)

var output := Vector2.ZERO
var is_active := false

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_reset_center)
	_reset_center()


func _reset_center() -> void:
	if not is_active:
		_center = Vector2(rest_offset.x, size.y + rest_offset.y)
		_knob = _center
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and _accepts(event.position):
			_begin(event.index, event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_end()
			accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_move(event.position)
			accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _touch_index == -1 and _accepts(event.position):
				_begin(MOUSE_INDEX, event.position)
				accept_event()
			elif not event.pressed and _touch_index == MOUSE_INDEX:
				_end()
				accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _touch_index == MOUSE_INDEX:
			_move(event.position)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_active:
			_end()


## Only touches near the joystick start it unless follow_touch is enabled.
func _accepts(pos: Vector2) -> bool:
	if follow_touch:
		return true
	return pos.distance_to(_center) <= base_radius * 1.6


func _begin(index: int, pos: Vector2) -> void:
	_touch_index = index
	is_active = true
	if follow_touch:
		_center = pos
	_move(pos)


func _move(pos: Vector2) -> void:
	var offset := pos - _center
	var length := offset.length()
	if length > base_radius:
		offset = offset / length * base_radius
		length = base_radius
	_knob = _center + offset
	var strength := length / base_radius
	if strength < dead_zone:
		output = Vector2.ZERO
	else:
		# Remap so the output starts at 0 right after the dead zone.
		output = offset.normalized() * clampf((strength - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	input_changed.emit(output)
	queue_redraw()


func _end() -> void:
	_touch_index = -1
	is_active = false
	output = Vector2.ZERO
	input_changed.emit(output)
	released.emit()
	var tween := create_tween()
	tween.tween_method(func(p: Vector2):
		_knob = p
		queue_redraw(), _knob, _center, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if follow_touch:
		_reset_center()


func _process(delta: float) -> void:
	if is_active:
		_pulse = fmod(_pulse + delta * 2.0, TAU)
		queue_redraw()


func _draw() -> void:
	var alpha := 0.95 if is_active else 0.6
	# Base
	draw_circle(_center, base_radius, Color(0.03, 0.06, 0.16, 0.45 * alpha))
	draw_arc(_center, base_radius, 0, TAU, 64, Color(0.2, 0.88, 1.0, 0.55 * alpha), 4.0, true)
	draw_arc(_center, base_radius * 0.62, 0, TAU, 48, Color(1, 1, 1, 0.12 * alpha), 2.0, true)
	# Direction ticks
	for i in 4:
		var dir := Vector2.RIGHT.rotated(i * PI * 0.5)
		draw_line(_center + dir * (base_radius - 18), _center + dir * (base_radius - 6), Color(1, 1, 1, 0.3 * alpha), 3.0, true)
	# Knob glow + knob
	if is_active:
		draw_circle(_knob, knob_radius + 10 + sin(_pulse) * 2.0, Color(0.2, 0.88, 1.0, 0.18))
	draw_circle(_knob, knob_radius, Color(0.92, 0.97, 1.0, 0.9 * alpha))
	draw_circle(_knob, knob_radius * 0.72, Color(0.2, 0.88, 1.0, 0.85 * alpha))
	draw_arc(_knob, knob_radius, 0, TAU, 48, Color(1, 1, 1, alpha), 3.0, true)
