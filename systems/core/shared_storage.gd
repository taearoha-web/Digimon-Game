class_name SharedStorage
## The storage (คลังเก็บของ) every character of this save set shares: one list kept in
## its own file beside the slots (PATH), so a hero deposits and another withdraws.
## Gear locked to another class (its "class", "star_class" or "set_gear") is listed for
## everyone but only a hero of that class takes it out (Game.withdraw_item, lock_reason);
## jewels, potions, gems and gear for any class go to anyone.
##
## The file is {"version", "items", "migrated"}. The cloud bundle carries it as two
## top-level fields, "storage" (the items) and "storageMigrated" (the record below).
##
## Before this storage each hero had its own (profile.storage, at most LEGACY_SIZE).
## migrate_slots moves those items in, losing nothing: the shared list may then hold
## more than SIZE (no deposit until it is back under SIZE), up to MAX_ITEMS, the most
## ten full old storages and a full new one can hold; anything past that stays in the
## hero's old storage and moves on a later load. Every moved item is counted in
## "migrated" by its key (key_of: the gear's uid, else a hash of the item), and a
## later pass skips as many items of a key as the record held when it started: a
## crash between writing this file and the slot, a slot restored from a backup made
## before the update, an old save code imported again or a second device that
## migrated the same saves never bring an item in twice.

const PATH := "user://toon_tale_storage.json"
## A file that fails the check is kept here (once) and the storage starts empty.
const BAD_PATH := "user://toon_tale_storage.bad.json"
const VERSION := 1
## Room for deposits. Shared by every hero now: a little under two old storages,
## since potions and jewels of every hero stack into one pile here.
const SIZE := 150
## The old per-hero storage (profile.storage), still read from older saves.
const LEGACY_SIZE := 80
## Ten heroes' full old storages moved into a full shared one (Game.SLOT_COUNT = 10).
const MAX_ITEMS := SIZE + 10 * LEGACY_SIZE
const MAX_KEYS := 4000
const LOCK_TEXT := "อาชีพอื่น ใช้ไม่ได้"

static var _items: Array = []
static var _migrated: Dictionary = {}
static var _loaded := false
## The committed file's items and record as JSON (what the cloud bundle sends).
static var _items_json := "[]"
static var _migrated_json := "{}"


## The shared list (live: change it, then Game commits it with store()).
static func items() -> Array:
	_ensure()
	return _items


static func size() -> int:
	return items().size()


## True when a new entry has no room (a stack joining a pile still fits).
static func full() -> bool:
	return size() >= SIZE


## The record of moved old-storage items: {key: count}.
static func migrated() -> Dictionary:
	_ensure()
	return _migrated


## The class [param item] is locked to ("" = any class): gear only.
static func gear_class(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return ""
	for key in ["class", "star_class", "set_gear"]:
		var cls := String(item.get(key, ""))
		if cls != "":
			return cls
	return ""


## Why a hero of [param cls] cannot take [param item] out ("" when it can).
static func lock_reason(item: Dictionary, cls: String) -> String:
	var locked := gear_class(item)
	return LOCK_TEXT if locked != "" and locked != cls else ""


## The name of a class for the greyed row ("" when unknown).
static func class_name_of(cls: String) -> String:
	return String(ClassData.CLASSES[StringName(cls)].name) if ClassData.CLASSES.has(StringName(cls)) else ""


## The stable key an old-storage item is counted under in the migration record.
static func key_of(item: Dictionary) -> String:
	if item.get("kind", "") == "equip" and String(item.get("uid", "")) != "":
		return "u:" + String(item.uid).left(60)
	return "h:" + JSON.stringify(item, "", true).md5_text().left(20)


## Reads the file again (start, a restore). Returns false when it was unreadable.
## (Not "reload": that name is the script's own Script.reload on a class reference.)
static func read_file() -> bool:
	_loaded = true
	_items = []
	_migrated = {}
	_items_json = "[]"
	_migrated_json = "{}"
	if not FileAccess.file_exists(PATH):
		return true
	var file := FileAccess.open(PATH, FileAccess.READ)
	var text := file.get_as_text() if file != null and file.get_length() <= Game.MAX_SAVE_BYTES * 2 else ""
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if not parsed is Dictionary or not valid(parsed):
		if not FileAccess.file_exists(BAD_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BAD_PATH))
		push_warning("SharedStorage: %s failed the save check; kept as %s" % [PATH, BAD_PATH])
		return false
	_items = parsed.get("items", [])
	for item in _items:
		Game._repair_item(item)
	for key in parsed.get("migrated", {}):
		_migrated[key] = int(parsed.migrated[key])
	_items_json = JSON.stringify(_items)
	_migrated_json = JSON.stringify(_migrated)
	return true


## The file holds a list of valid items (at most MAX_ITEMS) and a record of keys.
static func valid(data: Dictionary) -> bool:
	if not Game._valid_integer(data.get("version", VERSION), 1, VERSION):
		return false
	var list: Variant = data.get("items", [])
	var record: Variant = data.get("migrated", {})
	if not list is Array or not record is Dictionary:
		return false
	return valid_items(list) and valid_record(record)


static func valid_items(list: Array) -> bool:
	if list.size() > MAX_ITEMS:
		return false
	for item in list:
		if not Game._valid_item(item):
			return false
	return true


static func valid_record(record: Dictionary) -> bool:
	if record.size() > MAX_KEYS:
		return false
	for key in record:
		if not key is String or (key as String).length() > 64 or not Game._valid_integer(record[key], 1, 100000):
			return false
	return true


## Writes the list (temporary file, then a rename, like Game._write_profile).
static func store() -> bool:
	_ensure()
	var items_text := JSON.stringify(_items)
	var record_text := JSON.stringify(_migrated)
	var text := "{\"version\":%d,\"items\":%s,\"migrated\":%s}" % [VERSION, items_text, record_text]
	var file := FileAccess.open(PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	var dir := DirAccess.open("user://")
	if error != OK or dir == null or dir.rename((PATH + ".tmp").get_file(), PATH.get_file()) != OK:
		return false
	_items_json = items_text
	_migrated_json = record_text
	return true


## The two cloud bundle fields as JSON text: ,"storage":[...],"storageMigrated":{...}
static func bundle_fields_json() -> String:
	_ensure()
	return ",\"storage\":%s,\"storageMigrated\":%s" % [_items_json, _migrated_json]


## The two cloud bundle fields (Game.build_cloud_bundle): the committed file's data.
static func bundle_fields() -> Dictionary:
	_ensure()
	return {"storage": JSON.parse_string(_items_json), "storageMigrated": JSON.parse_string(_migrated_json)}


## Adds a whole entry (stackables join their pile). False when there is no room.
static func put(item: Dictionary) -> bool:
	var list := items()
	if ItemData.is_stackable(item):
		for existing in list:
			if existing.get("kind", "") == item.get("kind", "") and existing.get("id") == item.get("id"):
				existing["count"] = int(existing.get("count", 1)) + int(item.get("count", 1))
				return true
	if list.size() >= SIZE:
		return false
	list.append(item)
	return true


## Moves the repaired old-storage [param list] in, skipping what [param budget] (a copy
## of the record when the pass began) says was moved before. Returns the items left
## behind (only past MAX_ITEMS) and sets [code]changed[/code] in [param out].
static func absorb(list: Array, budget: Dictionary, out: Dictionary) -> Array:
	var left: Array = []
	var shared := items()
	for item in list:
		if not item is Dictionary:
			continue
		var key := key_of(item)
		if int(budget.get(key, 0)) > 0:
			budget[key] = int(budget[key]) - 1
			out["changed"] = true
			continue
		var stacked := false
		if ItemData.is_stackable(item):
			for existing in shared:
				if existing.get("kind", "") == item.get("kind", "") and existing.get("id") == item.get("id"):
					existing["count"] = int(existing.get("count", 1)) + int(item.get("count", 1))
					stacked = true
					break
		if not stacked:
			if shared.size() >= MAX_ITEMS or (not _migrated.has(key) and _migrated.size() >= MAX_KEYS):
				left.append(item)
				continue
			shared.append(item)
		_migrated[key] = int(_migrated.get(key, 0)) + 1
		out["changed"] = true
		out["moved"] = int(out.get("moved", 0)) + 1
	return left


## Moves the old per-hero storages of every save slot into the shared one (see the
## class notes). The shared file is written first, then each slot without the moved
## items. Returns how many items moved (0 when there was nothing to do).
static func migrate_slots() -> int:
	_ensure()
	var pending: Array = []
	for i in range(1, Game.SLOT_COUNT + 1):
		var raw := Game._read_slot(i)
		if raw.is_empty() or not raw.get("storage") is Array or (raw.storage as Array).is_empty():
			continue
		pending.append([i, raw])
	if pending.is_empty():
		return 0
	# A copy of every slot (and the shared file) from before the move, just in case.
	SaveBackup.backup_now("before-storage")
	var budget := _migrated.duplicate()
	var out := {}
	var rewrite: Array = []
	for entry in pending:
		var raw: Dictionary = entry[1]
		var repaired := Game._repair(raw.duplicate(true))
		var left := absorb(repaired.storage, budget, out)
		raw["storage"] = left
		rewrite.append([entry[0], raw])
	if not bool(out.get("changed", false)):
		return 0
	if not store():
		return 0
	for entry in rewrite:
		Game._write_profile(entry[1], int(entry[0]))
	return int(out.get("moved", 0))


## The same for one profile not yet written (an imported save code): its old storage
## moves in now. True when anything changed; the caller writes the profile after.
static func absorb_profile(data: Dictionary) -> bool:
	_ensure()
	if not data.get("storage") is Array or (data.storage as Array).is_empty():
		return false
	var out := {}
	data["storage"] = absorb(data.storage, _migrated.duplicate(), out)
	if bool(out.get("changed", false)):
		store()
		return true
	return false


static func _ensure() -> void:
	if not _loaded:
		read_file()
