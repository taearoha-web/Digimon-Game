class_name ColorSwatches
extends HFlowContainer
## Row of round colour buttons (touch friendly).

signal color_selected(index: int, color: Color)

const SWATCH_SIZE := 46.0

var palette: PackedColorArray = PackedColorArray()
var selected := -1


func setup(colors: PackedColorArray, selected_index := -1) -> ColorSwatches:
	palette = colors
	selected = selected_index
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	for i in palette.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "#" + palette[i].to_html(false)
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
	_refresh()
	return self


func select(index: int) -> void:
	selected = index
	_refresh()


func _on_pressed(i: int) -> void:
	AudioManager.play_ui(&"ui_click")
	selected = i
	_refresh()
	color_selected.emit(i, palette[i])


func _refresh() -> void:
	for i in get_child_count():
		var b := get_child(i) as Button
		var is_selected := i == selected
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = palette[i]
			sb.set_corner_radius_all(int(SWATCH_SIZE / 2))
			sb.set_border_width_all(4 if is_selected else 2)
			sb.border_color = Color.WHITE if is_selected else Color(1, 1, 1, 0.25 if state == "normal" else 0.6)
			if is_selected:
				sb.shadow_color = Color(UIPalette.CYAN.r, UIPalette.CYAN.g, UIPalette.CYAN.b, 0.7)
				sb.shadow_size = 6
			b.add_theme_stylebox_override(state, sb)
