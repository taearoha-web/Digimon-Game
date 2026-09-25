class_name TouchCameraArea
extends Control
## Invisible area (right side of the HUD) that turns finger drags into camera
## rotation and two-finger pinches into zoom. Buttons placed above it in the
## HUD receive their touches first, so pressing UI never rotates the camera.

signal drag(relative: Vector2)
signal pinch(amount: float)

const MOUSE_INDEX := -100

var _touches: Dictionary = {} # index -> position
var _pinch_distance := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_distance = _current_pinch_distance()
		accept_event()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var distance := _current_pinch_distance()
			if _pinch_distance > 0.0:
				pinch.emit((distance - _pinch_distance) * 0.01)
			_pinch_distance = distance
		elif _touches.size() == 1:
			drag.emit(event.relative)
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_touches[MOUSE_INDEX] = event.position
			else:
				_touches.erase(MOUSE_INDEX)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			pinch.emit(0.6)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			pinch.emit(-0.6)
			accept_event()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _touches.has(MOUSE_INDEX):
			drag.emit(event.relative)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_touches.clear()


func _current_pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1])
