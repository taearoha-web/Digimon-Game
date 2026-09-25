class_name SafeAreaContainer
extends MarginContainer
## Full-rect container whose margins respect display cutouts / rounded corners
## (DisplayServer safe area) plus a minimum design margin.

@export var min_margin := 16
@export var extra_top := 0
@export var extra_bottom := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var margins := get_safe_margins()
	add_theme_constant_override("margin_left", int(margins.x) + min_margin)
	add_theme_constant_override("margin_top", int(margins.y) + min_margin + extra_top)
	add_theme_constant_override("margin_right", int(margins.z) + min_margin)
	add_theme_constant_override("margin_bottom", int(margins.w) + min_margin + extra_bottom)


## Safe-area insets (left, top, right, bottom) converted to canvas units.
static func get_safe_margins() -> Vector4:
	var loop := Engine.get_main_loop()
	if not loop is SceneTree:
		return Vector4.ZERO
	var root: Window = (loop as SceneTree).root
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	# Screen pixels -> canvas units (canvas_items stretch).
	var canvas_size := root.get_visible_rect().size
	var scale := canvas_size / window_size
	var screen_pos := Vector2(DisplayServer.window_get_position())
	var left := maxf(0.0, safe.position.x - screen_pos.x)
	var top := maxf(0.0, safe.position.y - screen_pos.y)
	var right := maxf(0.0, (screen_pos.x + window_size.x) - (safe.position.x + safe.size.x))
	var bottom := maxf(0.0, (screen_pos.y + window_size.y) - (safe.position.y + safe.size.y))
	# Desktop windows report the whole monitor; ignore implausible values.
	if not (OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")):
		return Vector4.ZERO
	return Vector4(left * scale.x, top * scale.y, right * scale.x, bottom * scale.y)
