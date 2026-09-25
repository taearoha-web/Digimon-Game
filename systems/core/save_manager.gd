extends Node
## Autoload "SaveManager": versioned JSON saves with backups and migration.
##
## * Slot 0 is the autosave, slots 1..SLOT_COUNT are manual.
## * Writes go to a temp file first, then replace the real file; the previous
##   file is kept as ".bak". A corrupt save falls back to its backup and never
##   crashes the game.
## * Every save carries "version"; [method migrate] upgrades old saves step by
##   step (add a `_migrate_vN` function when SAVE_VERSION increases).

signal save_completed(slot: int, ok: bool)
signal load_completed(slot: int, ok: bool)

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const AUTOSAVE_SLOT := 0
const SLOT_COUNT := 3
## Minimum seconds between two non-forced autosaves.
const AUTOSAVE_MIN_INTERVAL := 8.0

var last_error: String = ""
## Overridable (tests point this at a scratch folder).
var save_dir: String = SAVE_DIR
var _last_autosave_time: float = -1000.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(save_dir)


func get_slot_path(slot: int) -> String:
	if slot == AUTOSAVE_SLOT:
		return save_dir.path_join("autosave.json")
	return save_dir.path_join("slot_%d.json" % slot)


func slot_exists(slot: int) -> bool:
	var path := get_slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func has_any_save() -> bool:
	for slot in range(0, SLOT_COUNT + 1):
		if slot_exists(slot):
			return true
	return false


## Most recently written valid slot, or -1.
func get_latest_slot() -> int:
	var best_slot := -1
	var best_time := -1
	for slot in range(0, SLOT_COUNT + 1):
		var info := get_slot_info(slot)
		if info.exists and not info.corrupt and int(info.saved_at) > best_time:
			best_time = int(info.saved_at)
			best_slot = slot
	return best_slot


## Lightweight metadata for Save/Load UI.
func get_slot_info(slot: int) -> Dictionary:
	var info := {"slot": slot, "exists": false, "corrupt": false, "saved_at": 0}
	if not slot_exists(slot):
		return info
	info.exists = true
	var data = _read_valid(get_slot_path(slot))
	if data == null:
		info.corrupt = true
		return info
	info.saved_at = int(data.get("saved_at", 0))
	var meta = data.get("meta", {})
	if meta is Dictionary:
		info.merge(meta)
	return info


func save_game(slot: int, is_autosave := false) -> bool:
	if not GameState.is_game_active:
		last_error = L10n.t("No active game")
		save_completed.emit(slot, false)
		return false
	_capture_live_world_state()
	var data := build_save_data()
	var ok := _write_json_atomic(get_slot_path(slot), data)
	if ok:
		if slot != AUTOSAVE_SLOT:
			GameState.active_slot = slot
		EventBus.game_saved.emit(slot, is_autosave)
	save_completed.emit(slot, ok)
	return ok


## Autosaves after important events. Throttled unless [param force].
func autosave(reason: String = "", force := false) -> bool:
	if not GameState.is_game_active:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if not force and now - _last_autosave_time < AUTOSAVE_MIN_INTERVAL:
		return false
	_last_autosave_time = now
	var ok := save_game(AUTOSAVE_SLOT, true)
	if ok and reason != "":
		print_verbose("Autosaved: %s" % reason)
	return ok


func load_game(slot: int) -> bool:
	var data = _read_valid(get_slot_path(slot))
	if data == null:
		last_error = L10n.t("Save data is missing or corrupted.")
		load_completed.emit(slot, false)
		return false
	data = migrate(data)
	if data == null:
		last_error = L10n.t("Save data is from an unsupported version.")
		load_completed.emit(slot, false)
		return false
	GameState.load_from_dict(data.get("state", {}))
	GameState.active_slot = slot if slot != AUTOSAVE_SLOT else GameState.active_slot
	var settings_data = data.get("settings", {})
	if settings_data is Dictionary and not settings_data.is_empty():
		Settings.load_dict(settings_data)
	EventBus.game_loaded.emit(slot)
	load_completed.emit(slot, true)
	return true


func delete_slot(slot: int) -> void:
	var path := get_slot_path(slot)
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func build_save_data() -> Dictionary:
	var lead := GameState.roster.get_lead()
	var lead_species := lead.get_species() if lead else null
	var map_data: MapData = GameData.get_map(GameState.world.current_map_id)
	var party_species: Array = []
	for member in GameState.roster.get_party():
		party_species.append(String(member.species_id))
	return {
		"version": SAVE_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"meta": {
			"player_name": GameState.profile.player_name,
			"lead_name": lead.get_display_name() if lead else "",
			"lead_species": lead_species.display_name if lead_species else "",
			"lead_level": lead.level if lead else 0,
			"party_species": party_species,
			"play_time": int(GameState.profile.play_time_seconds),
			"map_name": map_data.display_name if map_data else String(GameState.world.current_map_id),
			"owned_count": GameState.roster.size(),
		},
		"state": GameState.to_dict(),
		"settings": Settings.to_dict(),
	}


## Upgrades [param data] to SAVE_VERSION. Returns null when impossible.
func migrate(data: Dictionary) -> Variant:
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_warning("SaveManager: save version %d is newer than supported %d" % [version, SAVE_VERSION])
		return null
	while version < SAVE_VERSION:
		var method := "_migrate_v%d" % version
		if not has_method(method):
			push_warning("SaveManager: no migration from version %d" % version)
			return null
		data = call(method, data)
		version += 1
		data["version"] = version
	return data


## Version 0 = prototype saves that stored the state at the top level.
func _migrate_v0(data: Dictionary) -> Dictionary:
	if not data.has("state"):
		var state := {}
		for key in ["profile", "roster", "inventory", "quests", "world"]:
			if data.has(key):
				state[key] = data[key]
		data["state"] = state
	if not data.has("meta"):
		data["meta"] = {}
	return data


## Validates the basic shape of a save dictionary.
func is_valid_save(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("version"):
		return false
	var state = data.get("state", data)
	return state is Dictionary and state.get("profile", null) is Dictionary and state.get("roster", null) is Dictionary


func _capture_live_world_state() -> void:
	# The active map (if any) stores the player's transform before saving.
	get_tree().call_group("save_listeners", "on_before_save")


func _read_valid(path: String) -> Variant:
	var data = _read_json(path)
	if is_valid_save(data):
		return data
	var backup = _read_json(path + ".bak")
	if is_valid_save(backup):
		push_warning("SaveManager: '%s' unreadable, using backup" % path)
		return backup
	return null


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _write_json_atomic(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		last_error = L10n.t("Cannot write save (%s)") % error_string(FileAccess.get_open_error())
		push_warning("SaveManager: " + last_error)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Verify what we wrote can be read back before replacing the real save.
	if not is_valid_save(_read_json(tmp_path)):
		last_error = L10n.t("Save verification failed")
		DirAccess.remove_absolute(tmp_path)
		return false
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		last_error = L10n.t("Cannot finalize save (%s)") % error_string(err)
		push_warning("SaveManager: " + last_error)
		return false
	return true
