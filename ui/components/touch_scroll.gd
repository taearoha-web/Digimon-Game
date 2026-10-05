class_name TouchScroll
extends ScrollContainer
## A vertical scroll list you can flick with a finger (or mouse) from anywhere,
## even when the drag starts on a button. Short taps still press the button;
## once the finger has moved a few pixels the list scrolls instead and keeps
## gliding after release.

const THRESHOLD := 10.0
const FRICTION := 0.04

var _pressed := false
var _dragging := false
var _start := Vector2.ZERO
var _velocity := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if get_global_rect().has_point(mb.position):
				_pressed = true
				_dragging = false
				_start = mb.position
				_velocity = 0.0
		else:
			if _dragging:
				get_viewport().set_input_as_handled()
			_pressed = false
			_dragging = false
	elif event is InputEventMouseMotion and _pressed:
		var mm := event as InputEventMouseMotion
		if not _dragging and absf(mm.position.y - _start.y) > THRESHOLD:
			_dragging = true
			# Cancel the press on whatever button the finger started on.
			get_viewport().gui_release_focus()
		if _dragging:
			scroll_vertical -= int(mm.relative.y)
			_velocity = lerpf(_velocity, mm.relative.y / maxf(get_process_delta_time(), 0.001), 0.5)
			get_viewport().set_input_as_handled()
	elif (event is InputEventScreenDrag or event is InputEventScreenTouch) and (_dragging or _pressed):
		# Touch screens also send raw touch events; ours is the only scroller.
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _pressed or absf(_velocity) < 8.0:
		_velocity = 0.0 if not _pressed else _velocity
		return
	scroll_vertical -= int(_velocity * delta)
	_velocity *= pow(FRICTION, delta)
