class_name QuestLog
extends RefCounted
## Runtime quest progress (serialisable). Rules live in QuestManager.

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED, REWARDED }

const STATE_NAMES := ["Locked", "Available", "Active", "Completed", "Rewarded"]

signal changed(quest_id: StringName)

## quest_id -> { "state": int, "step": int, "progress": int }
var _entries: Dictionary = {}


func get_state(quest_id: StringName) -> int:
	return int(_entries.get(quest_id, {}).get("state", State.LOCKED))


func set_state(quest_id: StringName, state: int) -> void:
	var entry := _ensure(quest_id)
	if int(entry.state) == state:
		return
	entry.state = state
	changed.emit(quest_id)


func get_step(quest_id: StringName) -> int:
	return int(_entries.get(quest_id, {}).get("step", 0))


func get_progress(quest_id: StringName) -> int:
	return int(_entries.get(quest_id, {}).get("progress", 0))


func set_step(quest_id: StringName, step: int, progress: int = 0) -> void:
	var entry := _ensure(quest_id)
	entry.step = step
	entry.progress = progress
	changed.emit(quest_id)


func set_progress(quest_id: StringName, progress: int) -> void:
	var entry := _ensure(quest_id)
	entry.progress = progress
	changed.emit(quest_id)


func get_quest_ids() -> Array:
	return _entries.keys()


func count_in_state(min_state: int) -> int:
	var total := 0
	for quest_id in _entries.keys():
		if int(_entries[quest_id].state) >= min_state:
			total += 1
	return total


func to_dict() -> Dictionary:
	var out := {}
	for key in _entries.keys():
		var e: Dictionary = _entries[key]
		out[String(key)] = {"state": int(e.state), "step": int(e.step), "progress": int(e.progress)}
	return out


func load_dict(data: Dictionary) -> void:
	_entries.clear()
	for key in data.keys():
		var e = data[key]
		if e is Dictionary:
			_entries[StringName(str(key))] = {
				"state": clampi(int(e.get("state", State.LOCKED)), State.LOCKED, State.REWARDED),
				"step": maxi(0, int(e.get("step", 0))),
				"progress": maxi(0, int(e.get("progress", 0))),
			}


func _ensure(quest_id: StringName) -> Dictionary:
	if not _entries.has(quest_id):
		_entries[quest_id] = {"state": State.LOCKED, "step": 0, "progress": 0}
	return _entries[quest_id]
