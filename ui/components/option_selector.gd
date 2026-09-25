class_name OptionSelector
extends HBoxContainer
## "Label   <  Value  >" row used by the character creator. Large touch targets.

signal changed(index: int)

var options: Array = [] # Array of display strings
var index := 0

var _title: Label
var _value: Label


func setup(title: String, option_names: Array, start_index := 0) -> OptionSelector:
	options = option_names
	index = clampi(start_index, 0, maxi(0, options.size() - 1))
	add_theme_constant_override("separation", 8)
	_title = UIUtil.label(title, &"BoldLabel")
	_title.custom_minimum_size = Vector2(150, 0)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_title)
	var left := UIUtil.icon_button("res://assets/icons/ui/arrow_left.svg", Vector2(58, 58), &"ChoiceButton")
	left.pressed.connect(func(): step(-1))
	add_child(left)
	_value = UIUtil.label("", &"ValueLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_value.custom_minimum_size = Vector2(190, 0)
	_value.clip_text = true
	add_child(_value)
	var right := UIUtil.icon_button("res://assets/icons/ui/arrow_right.svg", Vector2(58, 58), &"ChoiceButton")
	right.pressed.connect(func(): step(1))
	add_child(right)
	_refresh()
	return self


func step(direction: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + direction, 0, options.size())
	_refresh()
	changed.emit(index)


func set_index(value: int, emit := false) -> void:
	index = clampi(value, 0, maxi(0, options.size() - 1))
	_refresh()
	if emit:
		changed.emit(index)


func _refresh() -> void:
	if _value:
		_value.text = str(options[index]) if index < options.size() else "-"
