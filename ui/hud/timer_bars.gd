class_name TimerBars
extends VBoxContainer
## Compact status lanes below the hero: self / friends / the song / summons. The
## song (a Bard's) has a lane of its own, as it has its own slot (BuffBook.SONG_LIMIT).
var _chips: Dictionary = {}
var _rows: Dictionary = {}
var _summon_flow: HFlowContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	for group in ["self", "ally", "song", "summon"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 5)
		add_child(row)
		var label := Label.new()
		label.text = {"self": "ใช้เอง", "ally": "จากเพื่อน", "song": "เพลง", "summon": "อัญเชิญ"}[group]
		label.custom_minimum_size.x = 62
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color("bcd3e9"))
		label.add_theme_color_override("font_outline_color", Color("182137"))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		if group == "summon":
			_summon_flow = HFlowContainer.new()
			_summon_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_summon_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(_summon_flow)
		_rows[group] = row
		row.hide()
	visible = false

func update_entries(entries: Array, delta: float) -> void:
	var seen := {}
	var groups := {}
	for entry in entries:
		var id := String(entry.id)
		var group := "summon" if String(entry.kind) == "summon" else ("song" if bool(entry.get("song", false)) else ("ally" if bool(entry.ally) else "self"))
		seen[id] = true
		groups[group] = int(groups.get(group, 0)) + 1
		if not _chips.has(id):
			var chip := TimerChip.new()
			if group == "summon":
				_summon_flow.add_child(chip)
			else:
				_rows[group].add_child(chip)
			_chips[id] = chip
		if group == "summon":
			_summon_flow.move_child(_chips[id], int(groups[group]) - 1)
		else:
			_rows[group].move_child(_chips[id], int(groups[group]))
		(_chips[id] as TimerChip).show_values(entry, delta)
	for id in _chips.keys():
		if not seen.has(id):
			(_chips[id] as Control).hide()
			(_chips[id] as Control).queue_free()
			_chips.erase(id)
	for group in _rows:
		_rows[group].visible = groups.has(group)
		if group == "song":
			_rows[group].get_child(0).text = "เพลง\n%d/%d" % [int(groups.get(group, 0)), BuffBook.SONG_LIMIT]
		elif group != "summon":
			_rows[group].get_child(0).text = "%s\n%d/%d" % ["ใช้เอง" if group == "self" else "จากเพื่อน", int(groups.get(group, 0)), BuffBook.GROUP_LIMIT]
	visible = not _chips.is_empty()
