class_name UIUtil
extends RefCounted
## Small helpers for building UI from code consistently with the theme.

const DIGITAL_BG_SHADER := preload("res://shaders/ui_digital_background.gdshader")


static func label(text: String, variation: StringName = &"", align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l


static func button(text: String, variation: StringName = &"", min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): AudioManager.play_ui(&"ui_click"))
	return b


static func icon_button(icon_path: String, min_size := Vector2(72, 72), variation: StringName = &"IconButton") -> Button:
	var b := Button.new()
	b.icon = load(icon_path)
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): AudioManager.play_ui(&"ui_click"))
	return b


static func panel(variation: StringName = &"") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != &"":
		p.theme_type_variation = variation
	return p


static func vbox(separation := 10) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func hbox(separation := 10) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", separation)
	return b


static func margin(all: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	return m


static func spacer(horizontal := true) -> Control:
	var c := Control.new()
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Full-rect animated digital background.
static func digital_background() -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = DIGITAL_BG_SHADER
	rect.material = mat
	return rect


## Coloured pill with text, e.g. attribute or element tags.
static func chip(text: String, color: Color, font_size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.22)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color.lightened(0.35))
	p.add_child(l)
	return p


static func set_bar(bar: ProgressBar, value: float, max_value: float, animate := false, duration := 0.35) -> void:
	bar.max_value = maxf(1.0, max_value)
	if animate and bar.is_inside_tree():
		var tween := bar.create_tween()
		tween.tween_property(bar, "value", value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		bar.value = value


static func tint_hp_bar(bar: ProgressBar, ratio: float) -> void:
	var color := UIPalette.hp_color(ratio)
	if bar.has_meta("hp_tint") and bar.get_meta("hp_tint") == color:
		return
	bar.set_meta("hp_tint", color)
	bar.remove_theme_stylebox_override("fill")
	var fill := bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	if fill:
		fill.bg_color = color
		bar.add_theme_stylebox_override("fill", fill)


## Quick scale "pop" used when a panel appears.
static func pop_in(control: Control, duration := 0.22) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.85, 0.85)
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8)


static func format_play_time(seconds: float) -> String:
	var s := int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func format_date(unix_time: int) -> String:
	if unix_time <= 0:
		return "-"
	var d := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute]


static func element_color(element: StringName) -> Color:
	var loop := Engine.get_main_loop()
	var reg: Node = (loop as SceneTree).root.get_node_or_null("GameData") if loop is SceneTree else null
	if reg and reg.type_chart:
		return reg.type_chart.get_element_color(element)
	return UIPalette.TEXT_DIM


static func texture_rect(texture: Texture2D, min_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.custom_minimum_size = min_size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
