class_name SaveBackup
## Daily copies of the save slots, kept in this device's user:// beside the slots so a
## broken or wrongly deleted hero can be brought back offline (the web page keeps its
## own cloud snapshots). One folder per backup, user://backups/<YYYYMMDD-HHMMSS>-<reason>/,
## holding a copy of every slot file and an index.json (time, reason, per-slot summary).
## At most KEEP_DAILY "daily" and KEEP_MANUAL other ("manual", "before-restore") folders
## stay; the oldest go first. maybe_daily() backs up once per real day.
## The storage every hero shares (SharedStorage.PATH) is copied too: "restore all" puts
## it back with the slots, restoring one hero leaves it as it is (a hero saved before
## the shared storage brings its old storage, which SharedStorage.migrate_slots moves
## in without the items moved before).
## A restored slot gets saved_at = now and RESTORED_MARKER lists the restored slots, so
## the web page's cloud sync (tools/web/accounts.js) sees the restored save as the newer
## one and asks before the online copy could replace it; the page clears the marker.

const ROOT := "user://backups"
const LAST_DAILY_PATH := "user://backups/last_daily.txt"
const RESTORED_MARKER := "user://backups/restored.json"
const INDEX_FILE := "index.json"
const KEEP_DAILY := 7
const KEEP_MANUAL := 3

## The day of the last daily backup, read from LAST_DAILY_PATH once per run.
static var _last_daily := ""
static var _last_daily_read := false


## Copies every existing slot into a new backup folder; its user:// path, or "" when
## there is nothing to back up or the copy failed.
static func backup_now(reason := "daily") -> String:
	var slots: Dictionary = {}
	for i in range(1, Game.SLOT_COUNT + 1):
		var text := _slot_text(i)
		if text != "":
			slots[i] = text
	if slots.is_empty():
		return ""
	var shared := _file_text(SharedStorage.PATH)
	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		return ""
	var dir := _new_dir(reason)
	if dir == "" or DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var index := {"time": int(Time.get_unix_time_from_system()), "reason": reason, "slots": {}}
	for slot in slots:
		if not _write_text(dir.path_join(Game.save_path(slot).get_file()), slots[slot]):
			_remove_dir(dir)
			return ""
		var parsed: Variant = Game.parse_save_text(slots[slot])
		var summary: Dictionary = Game._slot_summary(parsed as Dictionary) if parsed is Dictionary else {}
		index.slots[String.num_int64(slot)] = {"name": summary.get("name", "?"), "class": summary.get("class", "warrior"),
			"level": summary.get("level", 1), "adv": summary.get("adv", 0)}
	if shared != "":
		var parsed_shared: Variant = JSON.parse_string(shared)
		index["storage"] = (parsed_shared.get("items", []) as Array).size() if parsed_shared is Dictionary and parsed_shared.get("items") is Array else 0
		if not _write_text(dir.path_join(SharedStorage.PATH.get_file()), shared):
			_remove_dir(dir)
			return ""
	if not _write_text(dir.path_join(INDEX_FILE), JSON.stringify(index)):
		_remove_dir(dir)
		return ""
	_prune()
	return dir


## Every backup, newest first: {dir, time, reason, slots: {"1": {name, class, level, adv}},
## storage: items in the shared storage copy (-1 when the backup has none)}.
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names := Array(_backup_names())
	names.sort_custom(func(a: String, b: String) -> bool: return _sort_key(a) > _sort_key(b))
	for name in names:
		var dir := ROOT.path_join(name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(INDEX_FILE)))
		if not parsed is Dictionary or not parsed.get("slots") is Dictionary:
			continue
		out.append({"dir": dir, "time": int(parsed.get("time", 0)), "reason": String(parsed.get("reason", "manual")), "slots": parsed.slots,
			"storage": int(parsed.get("storage", 0)) if FileAccess.file_exists(dir.path_join(SharedStorage.PATH.get_file())) else -1})
	return out


## Puts the backed-up copy of [param slot] back as the live slot file (its saved_at set
## to now), after a "before-restore" backup of every current slot. False when the backup
## is missing or fails Game's validation: the live slot is then untouched.
static func restore(dir: String, slot: int) -> bool:
	var text := _valid_backup_text(dir, slot)
	if text == "":
		return false
	backup_now("before-restore")
	if not _write_slot(slot, _stamped(text)):
		return false
	_mark_restored([slot])
	return true


## Restores every slot the backup holds (slots it lacks stay as they are) and the
## shared storage when the backup has it.
static func restore_all(dir: String) -> bool:
	var shared := ""
	if dir.begins_with(ROOT + "/") and FileAccess.file_exists(dir.path_join(SharedStorage.PATH.get_file())):
		shared = _file_text(dir.path_join(SharedStorage.PATH.get_file()))
		var parsed: Variant = JSON.parse_string(shared)
		if not parsed is Dictionary or not SharedStorage.valid(parsed):
			return false
	var texts: Dictionary = {}
	for i in range(1, Game.SLOT_COUNT + 1):
		if FileAccess.file_exists(dir.path_join(Game.save_path(i).get_file())):
			var text := _valid_backup_text(dir, i)
			if text == "":
				return false
			texts[i] = text
	if texts.is_empty():
		return false
	backup_now("before-restore")
	var ok := true
	var restored: Array = []
	for slot in texts:
		if _write_slot(slot, _stamped(texts[slot])):
			restored.append(slot)
		else:
			ok = false
	if shared != "":
		if _write_slot_file(SharedStorage.PATH, shared):
			SharedStorage.read_file()
		else:
			ok = false
	if not restored.is_empty():
		_mark_restored(restored)
	return ok


## The restore marker: {time, slots: [int]} of the slots restored since the web page
## last cleared it (the page reads the same file from the browser's store); {} when none.
static func restored_marker() -> Dictionary:
	if not FileAccess.file_exists(RESTORED_MARKER):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESTORED_MARKER))
	if not parsed is Dictionary or not parsed.get("slots") is Array:
		return {}
	var slots: Array = []
	for slot in parsed.slots:
		if (slot is float or slot is int) and int(slot) >= 1 and int(slot) <= Game.SLOT_COUNT:
			slots.append(int(slot))
	return {"time": int(parsed.get("time", 0)), "slots": slots}


## Backup copies already brought back by recover_hidden ({"<backup folder>|<slot>": 1}).
const RECOVERED_PATH := "user://backups/recovered.json"


## Heroes the save check once hid and the cloud sync then deleted: for each empty slot,
## the newest backup copy of that slot comes back when that copy is one the save check
## refuses (or cannot even parse) but salvage reads (Game.salvage_profile). Such a hero
## was invisible on the character select, so the player cannot have deleted it on
## purpose. Skipped when a hero of that name and class is already in a slot; each copy
## comes back at most once (RECOVERED_PATH). Returns the slots restored.
static func recover_hidden() -> Array:
	var done: Variant = JSON.parse_string(_file_text(RECOVERED_PATH)) if FileAccess.file_exists(RECOVERED_PATH) else {}
	if not done is Dictionary:
		done = {}
	var deleted: Dictionary = (done as Dictionary).get("deleted", {}) if (done as Dictionary).get("deleted") is Dictionary else {}
	var live := {}
	for i in range(1, Game.SLOT_COUNT + 1):
		var info := Game.slot_info(i)
		if not info.is_empty():
			live["%s|%s" % [info.get("name", ""), info.get("class", "")]] = true
	var restored: Array = []
	var entries := list()
	for i in range(1, Game.SLOT_COUNT + 1):
		if Game.has_save(i):
			continue
		for entry in entries:
			if not (entry.slots as Dictionary).has(str(i)):
				continue
			var key := "%s|%d" % [String(entry.dir).get_file(), i]
			var raw := _file_text(String(entry.dir).path_join(Game.save_path(i).get_file()))
			var parsed: Variant = Game.parse_save_text(raw)
			var strict: bool = JSON.new().parse(raw) == OK and parsed is Dictionary and Game._valid_profile(parsed)
			# The newest copy of the slot decides: a readable one means the hero was shown
			# then, so it may have been deleted on purpose since.
			# Deleted on purpose (note_deleted) after this copy was made: it stays deleted.
			if strict or done.has(key) or not parsed is Dictionary or float(deleted.get(str(i), 0)) >= float(entry.time):
				break
			var text := _valid_backup_text(String(entry.dir), i)
			var saved: Variant = Game.parse_save_text(text) if text != "" else null
			if not saved is Dictionary:
				break
			var who := "%s|%s" % [String(saved.get("name", "")), String(saved.get("class", ""))]
			done[key] = 1
			if live.has(who):
				break
			if _write_slot(i, _stamped(text)):
				live[who] = true
				restored.append(i)
			break
	if not restored.is_empty():
		_mark_restored(restored)
		Game._slot_json.clear()
		Game._queue_cloud_save()
	if not (done as Dictionary).is_empty():
		DirAccess.make_dir_recursive_absolute(ROOT)
		_write_text(RECOVERED_PATH, JSON.stringify(done))
	return restored


## The player deleted the hero of [param slot] (Game.delete_save): recover_hidden never
## brings back a copy made before now.
static func note_deleted(slot: int) -> void:
	var done: Variant = JSON.parse_string(_file_text(RECOVERED_PATH)) if FileAccess.file_exists(RECOVERED_PATH) else {}
	if not done is Dictionary:
		done = {}
	if not done.get("deleted") is Dictionary:
		done["deleted"] = {}
	done.deleted[str(slot)] = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(ROOT)
	_write_text(RECOVERED_PATH, JSON.stringify(done))


## A daily backup, at most once per real (local) day; true when one was made now.
static func maybe_daily() -> bool:
	var today := Time.get_date_string_from_system()
	if not _last_daily_read:
		_last_daily_read = true
		_last_daily = FileAccess.get_file_as_string(LAST_DAILY_PATH).strip_edges() if FileAccess.file_exists(LAST_DAILY_PATH) else ""
	if _last_daily == today:
		return false
	if backup_now("daily") == "":
		return false
	_last_daily = today
	_write_text(LAST_DAILY_PATH, today)
	return true


## Forgets the cached day (tests): the next maybe_daily reads LAST_DAILY_PATH again.
static func reset_daily_cache() -> void:
	_last_daily_read = false
	_last_daily = ""


static func _slot_text(slot: int) -> String:
	return _file_text(Game.save_path(slot))


static func _file_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Game.MAX_SAVE_BYTES:
		return ""
	return file.get_as_text()


## The slot's bytes inside the backup when they parse to a profile Game accepts.
static func _valid_backup_text(dir: String, slot: int) -> String:
	if slot < 1 or slot > Game.SLOT_COUNT or not dir.begins_with(ROOT + "/"):
		return ""
	var path := dir.path_join(Game.save_path(slot).get_file())
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Game.MAX_SAVE_BYTES:
		return ""
	var text := file.get_as_text()
	var parsed: Variant = Game.parse_save_text(text)
	if not parsed is Dictionary:
		return ""
	if Game._valid_profile(parsed as Dictionary):
		return text if JSON.new().parse(text) == OK else JSON.stringify(parsed)
	# A copy the save check refuses (a check that once refused legitimate data hid such
	# heroes): it comes back salvaged, only what fails taken out (Game.salvage_profile).
	var saved := Game.salvage_profile(parsed as Dictionary)
	return JSON.stringify(saved) if not saved.is_empty() else ""


## The validated slot text with saved_at set to now: a restored save is the newest one,
## so the web page's sync (newest saved_at wins) does not put the online copy back over it.
static func _stamped(text: String) -> String:
	var parsed: Variant = Game.parse_save_text(text)
	if not parsed is Dictionary:
		return text
	parsed["saved_at"] = int(Time.get_unix_time_from_system())
	return JSON.stringify(parsed)


## Adds [param slots] to RESTORED_MARKER (merged with the slots already listed).
static func _mark_restored(slots: Array) -> void:
	var listed: Array = restored_marker().get("slots", [])
	for slot in slots:
		if not listed.has(int(slot)):
			listed.append(int(slot))
	listed.sort()
	_write_text(RESTORED_MARKER, JSON.stringify({"time": int(Time.get_unix_time_from_system()), "slots": listed}))


## Same-directory rename, like Game._write_profile: a failed write leaves the slot intact.
static func _write_slot(slot: int, text: String) -> bool:
	return _write_slot_file(Game.save_path(slot), text)


static func _write_slot_file(path: String, text: String) -> bool:
	if not _write_text(path + ".tmp", text):
		return false
	var dir := DirAccess.open("user://")
	return dir != null and dir.rename(path.get_file() + ".tmp", path.get_file()) == OK


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK


## <YYYYMMDD-HHMMSS>-<reason>, plus a two-digit suffix when another backup (of any
## reason) was made in the same second, one above the highest of that second: the
## names then order the backups as they were made even after some were pruned.
static func _new_dir(reason: String) -> String:
	var d := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
	var seq := 0
	for name in _backup_names():
		if name.begins_with(stamp + "-"):
			seq = maxi(seq, _seq_of(name))
	if seq >= 99:
		return ""
	var base := ROOT.path_join("%s-%s" % [stamp, reason])
	return base if seq == 0 else "%s-%02d" % [base, seq + 1]


## The same-second sequence number of a backup folder name (1 without a suffix).
static func _seq_of(name: String) -> int:
	var n := name.length()
	if n > 3 and name[n - 3] == "-" and name.substr(n - 2).is_valid_int():
		return int(name.substr(n - 2))
	return 1


## Time stamp then sequence: the order the backups were made, whatever their reason.
static func _sort_key(name: String) -> String:
	return "%s-%02d" % [name.substr(0, 15), _seq_of(name)]


static func _backup_names() -> PackedStringArray:
	var out: PackedStringArray = []
	var root := DirAccess.open(ROOT)
	if root == null:
		return out
	for name in root.get_directories():
		if FileAccess.file_exists(ROOT.path_join(name).path_join(INDEX_FILE)):
			out.append(name)
	return out


## Keeps the newest KEEP_DAILY daily and KEEP_MANUAL other backups.
static func _prune() -> void:
	var daily := 0
	var manual := 0
	for entry in list():
		var is_daily: bool = entry.reason == "daily"
		if is_daily:
			daily += 1
		else:
			manual += 1
		if (is_daily and daily > KEEP_DAILY) or (not is_daily and manual > KEEP_MANUAL):
			_remove_dir(entry.dir)


static func _remove_dir(dir: String) -> void:
	var folder := DirAccess.open(dir)
	if folder == null:
		return
	for name in folder.get_files():
		folder.remove(name)
	DirAccess.remove_absolute(dir)
