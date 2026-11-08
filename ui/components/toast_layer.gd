class_name ToastLayer
extends CanvasLayer
## Stacked, auto-dismissing notifications driven by Game.toast.

const MAX_VISIBLE := 4
const LIFETIME := 2.6
## Where the stack starts (logical px from the top) when nothing reserves the top centre.
const TOP := 124.0
## The gap under a reserved top band (GuildWarHud.top_band: the guild war's board).
const BAND_GAP := 8.0
const KIND_COLORS := {
	&"info": Color("34e0ff"),
	&"success": Color("5ad17a"),
	&"warning": Color("ffd166"),
	&"quest": Color("ffc93c"),
	&"item": Color("ff8fb1"),
}

var _stack: VBoxContainer
## The bottom of the toasts on screen while any is up, 0 without (the guild war's switch
## label keeps out of the lane: GuildWarMatch._fit_switch_label).
static var lane_bottom := 0.0


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_stack = VBoxContainer.new()
	_stack.anchor_left = 0.5
	_stack.anchor_right = 0.5
	_stack.offset_left = -300
	_stack.offset_right = 300
	_stack.offset_top = TOP
	_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stack.add_theme_constant_override("separation", 8)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stack)
	Game.toast.connect(show_toast)


## The toasts' own lane: under the guild war's board and its rows when one is up (never on
## top of them), at TOP otherwise.
func _process(_delta: float) -> void:
	_stack.offset_top = lane_top()
	lane_bottom = _stack.get_global_rect().end.y if _stack.get_child_count() > 0 else 0.0


func _exit_tree() -> void:
	lane_bottom = 0.0


static func lane_top() -> float:
	return maxf(TOP, GuildWarHud.top_band + BAND_GAP) if GuildWarHud.top_band > 0.0 else TOP


## The stack's rect on screen (tests).
func stack_rect() -> Rect2:
	return _stack.get_global_rect()


func show_toast(text: String, kind: StringName = &"info") -> void:
	if text.strip_edges() == "":
		return
	# Under a guild war's board two at most, so the lane stays over the field's top half.
	var cap := MAX_VISIBLE if GuildWarHud.top_band <= 0.0 else 2
	while _stack.get_child_count() >= cap:
		var oldest := _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var color: Color = KIND_COLORS.get(kind, KIND_COLORS[&"info"])
	if sb:
		sb.border_color = color
		panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BoldLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	panel.add_child(row)
	_stack.add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(LIFETIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(panel.queue_free)
