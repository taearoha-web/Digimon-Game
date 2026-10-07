class_name TimerBars
extends HBoxContainer
## Top-centre row of small round timer chips: one per active buff (own or from an
## ally) and one per summon (see TimerChip).

var _chips: Dictionary = {} # id -> TimerChip


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	alignment = BoxContainer.ALIGNMENT_CENTER
	visible = false


## [param entries] comes from Hero.timer_status().
func update_entries(entries: Array, delta: float) -> void:
	var seen := {}
	for entry in entries:
		var id := String(entry.id)
		seen[id] = true
		if not _chips.has(id):
			var chip := TimerChip.new()
			add_child(chip)
			_chips[id] = chip
		(_chips[id] as TimerChip).show_values(entry, delta)
	for id in _chips.keys():
		if not seen.has(id):
			(_chips[id] as Control).queue_free()
			_chips.erase(id)
	visible = not _chips.is_empty()
