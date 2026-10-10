extends Node
## Autoload "Game": the player's profile (class, level, items, quests), saving
## and loading, and every rule that changes it (EXP, equipment, potions, gold).
## The 3D hero node reads and writes current HP / MP here so they persist.

signal profile_changed()
signal inventory_changed()
signal gold_changed(gold: int)
signal exp_changed()
signal leveled_up(level: int)
signal paragon_leveled(level: int)
signal toast(text: String, kind: StringName)
signal autosaved()
signal item_gained(item: Dictionary)
signal quest_changed()
signal party_changed()
signal party_leveled(index: int, level: int)
signal party_roster_changed()
signal achievement_unlocked(name: String)
signal ending_requested()
signal screen_flash(color: Color, strength: float)
signal profile_imported()

## The original single save file; it becomes slot 1 the first time slots are used.
const LEGACY_SAVE_PATH := "user://toon_tale_save.json"
const SLOT_COUNT := 4
const META_PATH := "user://toon_tale_meta.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 10.0
const BASE_BAG := 40
const MAX_BAG := 100
const BAG_STEP := 10
const STORAGE_SIZE := 80
const STAT_POINTS_PER_LEVEL := 3
const MAX_LEVEL := 100
const MAX_SKILL_RANK := 5
const MAX_SAVE_BYTES := 1048576
const MAX_SAVE_NUMBER := 1000000000000
## Area skills (burst / blast) grow this much wider per extra star.
const RADIUS_PER_STAR := 0.08

var profile: Dictionary = {}
var has_profile := false
var current_zone: StringName = &"town"
var rng := RandomNumberGenerator.new()
var _autosave_timer := 0.0
var _dirty := false


func _ready() -> void:
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_legacy_save()


func _process(delta: float) -> void:
	if not has_profile:
		return
	profile["play_time"] = float(profile.get("play_time", 0.0)) + delta
	_autosave_timer += delta
	if _autosave_timer > AUTOSAVE_INTERVAL and _dirty:
		if save():
			autosaved.emit()
		else:
			# Retry at the next interval instead of opening a failing file every frame.
			_autosave_timer = 0.0


func _notification(what: int) -> void:
	# Leaving the tab / app, or closing it, saves right away.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_profile:
			save()


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------

func new_profile(class_id: StringName, hero_name: String, look := {}) -> void:
	profile = {
		"version": SAVE_VERSION, "class": String(class_id), "name": hero_name.strip_edges(),
		"level": 1, "exp": 0, "points": 0, "skill_points": 1,
		"attrs": {"str": 0, "int": 0, "dex": 0, "vit": 0},
		"skills": {}, "loadout": ["", "", "", "", "", "", "", ""], "gold": 150, "equip": {}, "inv": [],
		"hp": 1, "mp": 1, "zone": "town", "quests": {}, "kills": 0, "deaths": 0, "play_time": 0.0,
		"flags": {}, "boss_kills": {}, "pvp": {}, "paragon": {}, "tower": {}, "storage": [], "bag_slots": BASE_BAG, "adv": 0,
	}
	if not look.is_empty():
		profile["look"] = FaceKit.repair(look)
	has_profile = true
	var starter := ItemData.generate(1, class_id, rng, 0, "weapon")
	starter["name"] = "%s ของมือใหม่" % ItemData.NAMES[starter.base][0]
	profile["equip"]["weapon"] = starter
	profile["inv"] = [ItemData.potion("hp_s", 5), ItemData.potion("mp_s", 3), ItemData.potion("town_scroll", 1)]
	fill_loadout()
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	current_zone = &"town"
	save()
	profile_changed.emit()
	inventory_changed.emit()


func class_id() -> StringName:
	return StringName(profile.get("class", "warrior"))


## The class with the skill bar loadout as [code]skills[/code] (always ClassData.SLOTS entries, {} = empty slot).
func class_data() -> Dictionary:
	var data := JobData.resolve(class_id(), adv()).duplicate()
	data["skills"] = loadout_skills()
	return data


## Every active skill of the class (the pool the bar is filled from).
func skill_pool() -> Array:
	return ClassData.pool(class_id())


func passive_pool() -> Array:
	return ClassData.PASSIVES.get(class_id(), [])


func loadout_skills() -> Array:
	var out: Array = []
	for id in loadout():
		out.append(ClassData.find_skill(class_id(), String(id)))
	return out


func loadout() -> Array:
	if not profile.get("loadout") is Array or (profile["loadout"] as Array).size() != ClassData.SLOTS:
		fill_loadout()
	return profile["loadout"]


## Keeps the bar valid and puts newly unlocked skills into empty slots.
func fill_loadout() -> void:
	profile["loadout"] = ClassData.default_loadout(class_id(), int(profile.get("level", 1)), profile.get("loadout", []), class_tier())


## Puts a skill on a bar slot; a skill already on the bar swaps places.
func equip_skill(skill_id: String, slot: int) -> bool:
	var skill := ClassData.find_skill(class_id(), skill_id)
	if skill.is_empty() or not skill_unlocked(skill) or slot < 0 or slot >= ClassData.SLOTS:
		return false
	var bar: Array = loadout()
	var from := bar.find(skill_id)
	if from >= 0:
		bar[from] = bar[slot]
	bar[slot] = skill_id
	profile_changed.emit()
	mark_dirty()
	return true


## Vagabond -> one of the four lines (Lv.10, free). Vagabond weapons turn into
## the new line's weapon type with the same level, rarity and enhancement.
func change_class(new_class: StringName) -> bool:
	if class_id() != ClassData.START or not ClassData.IDS.has(new_class) or int(profile["level"]) < ClassData.LINE_LEVEL:
		return false
	profile["class"] = String(new_class)
	var local := RandomNumberGenerator.new()
	local.randomize()
	for slot in profile["equip"]:
		_convert_weapon(profile["equip"][slot], new_class, local)
	for item in profile["inv"]:
		_convert_weapon(item, new_class, local)
	profile["loadout"] = ["", "", "", ""]
	fill_loadout()
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	if party().is_empty():
		ensure_party()
	profile_changed.emit()
	inventory_changed.emit()
	party_changed.emit()
	mark_dirty()
	check_achievements()
	save()
	return true


func _convert_weapon(item: Dictionary, new_class: StringName, rng: RandomNumberGenerator) -> void:
	if item.get("kind", "") != "equip" or item.get("class", "") != String(ClassData.START):
		return
	var fresh := ItemData.generate(int(item.level), new_class, rng, int(item.rarity), "weapon")
	item["class"] = String(new_class)
	item["base"] = fresh.base
	var starter := String(item.get("name", "")).ends_with("ของมือใหม่")
	item["name"] = ("%s ของมือใหม่" % ItemData.NAMES[fresh.base][0]) if starter else fresh.name


## How many advancement steps (Lv.20/40/60/80) the hero has taken (0-4).
func adv() -> int:
	return clampi(int(profile.get("adv", 0)), 0, JobData.MAX_ADV)


## The next advancement step ({} when none is left or the hero is still a Vagabond).
func next_step() -> Dictionary:
	if class_id() == ClassData.START or adv() >= JobData.MAX_ADV:
		return {}
	return JobData.step(class_id(), adv())


func next_step_level() -> int:
	return int(JobData.TIER_LEVELS[adv()]) if adv() < JobData.MAX_ADV else 0


func next_step_cost() -> int:
	return int(JobData.TIER_COSTS[adv()]) if adv() < JobData.MAX_ADV else 0


## Job Master: the next advancement needs its level and fee. Returns false if refused.
func advance() -> bool:
	if next_step().is_empty():
		return false
	if int(profile["level"]) < next_step_level() or int(profile["gold"]) < next_step_cost():
		return false
	profile["gold"] -= next_step_cost()
	profile["skill_points"] += int(JobData.TIER_SKILL_POINTS[adv()])
	profile["adv"] = adv() + 1
	fill_loadout()
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	gold_changed.emit(profile["gold"])
	profile_changed.emit()
	party_changed.emit()
	mark_dirty()
	check_achievements()
	return true


func stats_now(buffs := {}) -> Dictionary:
	return HeroStats.compute(profile, buffs)


## The whole save as one copyable text code (base64 of the JSON).
func export_code() -> String:
	if not has_profile:
		return ""
	var snapshot := profile.duplicate(true)
	snapshot["zone"] = String(current_zone)
	return Marshalls.utf8_to_base64(JSON.stringify(snapshot))


## Inspect a backup without changing the active hero or any save slot.
func preview_import(code: String) -> Dictionary:
	var candidate := _decode_import(code)
	if candidate.is_empty():
		return {}
	return {"name": candidate.name, "class": candidate["class"], "level": candidate.level,
		"adv": candidate.adv, "zone": candidate.zone, "play_time": candidate.play_time}


func _decode_import(code: String) -> Dictionary:
	var clean := code.strip_edges()
	if clean.is_empty() or clean.length() > MAX_SAVE_BYTES * 2:
		return {}
	var format := RegEx.new()
	format.compile("^[A-Za-z0-9+/]+={0,2}$")
	if clean.length() % 4 != 0 or format.search(clean) == null:
		return {}
	var decoded := Marshalls.base64_to_utf8(clean)
	if decoded.is_empty() or decoded.length() > MAX_SAVE_BYTES:
		return {}
	var json := JSON.new()
	if json.parse(decoded) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or not _valid_profile(parsed):
		return {}
	return _repair(parsed)


## Commit only after the backup and destination are valid and disk write succeeds.
func import_code(code: String, target_slot := -1) -> bool:
	var destination := slot if target_slot == -1 else target_slot
	if destination < 1 or destination > SLOT_COUNT:
		return false
	var candidate := _decode_import(code)
	if candidate.is_empty():
		return false
	candidate["resume"] = playing
	candidate["saved_at"] = int(Time.get_unix_time_from_system())
	if not _write_profile(candidate, destination):
		return false
	profile = candidate
	slot = destination
	has_profile = true
	current_zone = StringName(profile.zone)
	_dirty = false
	_autosave_timer = 0.0
	_party_gear.clear()
	_remember_slot()
	profile_changed.emit()
	inventory_changed.emit()
	quest_changed.emit()
	party_changed.emit()
	gold_changed.emit(int(profile.gold))
	exp_changed.emit()
	profile_imported.emit()
	return true


func save_code_roundtrip() -> bool:
	var code := export_code()
	if code == "":
		return false
	var restored := _decode_import(code)
	var snapshot := profile.duplicate(true)
	snapshot["zone"] = String(current_zone)
	# JSON represents all numbers as floats; normalize both sides through JSON
	# so a type-only change never hides a real lost or changed field.
	return not restored.is_empty() and JSON.parse_string(JSON.stringify(restored)) == JSON.parse_string(JSON.stringify(_repair(snapshot)))


## Which of the 4 save slots (1..4) the current profile belongs to.
var slot := 1


func save_path(for_slot := -1) -> String:
	return "user://toon_tale_slot_%d.json" % (slot if for_slot < 1 else for_slot)


func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(save_path(1)):
		var dir := DirAccess.open("user://")
		if dir:
			dir.rename(LEGACY_SAVE_PATH.get_file(), save_path(1).get_file())


## True when the given slot (default: the current one) holds a save.
func has_save(for_slot := -1) -> bool:
	return FileAccess.file_exists(save_path(for_slot))


func any_save() -> bool:
	for i in range(1, SLOT_COUNT + 1):
		if has_save(i):
			return true
	return false


## The first empty slot, or 0 when all four are taken.
func free_slot() -> int:
	for i in range(1, SLOT_COUNT + 1):
		if not has_save(i):
			return i
	return 0


func _read_slot(for_slot: int) -> Dictionary:
	if for_slot < 1 or for_slot > SLOT_COUNT or not has_save(for_slot):
		return {}
	var file := FileAccess.open(save_path(for_slot), FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_SAVE_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and _valid_profile(parsed):
		return parsed
	return {}


## A short summary of a slot for the title screen; {} when it is empty.
func slot_info(for_slot: int) -> Dictionary:
	var raw := _read_slot(for_slot)
	if raw.is_empty():
		return {}
	return {
		"class": String(raw.get("class", "warrior")), "name": String(raw.get("name", "?")),
		"level": int(raw.get("level", 1)), "adv": int(raw.get("adv", 0)), "zone": String(raw.get("zone", "town")),
		"play_time": float(raw.get("play_time", 0.0)), "saved_at": int(raw.get("saved_at", 0)),
		"rank": int(raw.get("pvp", {}).get("rp", 0)) if raw.get("pvp", {}) is Dictionary else 0,
	}


## Cosmetic data for a title-screen preview; does not select or load the slot.
func slot_profile_preview(for_slot: int) -> Dictionary:
	var raw := _read_slot(for_slot)
	if raw.is_empty():
		return {}
	var repaired := _repair(raw)
	return {"class": repaired["class"], "adv": repaired.adv,
		"look": repaired.get("look", {}), "equip": repaired.equip}


func last_slot() -> int:
	if not FileAccess.file_exists(META_PATH):
		return 1
	var file := FileAccess.open(META_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if parsed is Dictionary and _valid_integer(parsed.get("slot", 1), 1, SLOT_COUNT):
		var n := int(parsed.get("slot", 1))
		if n >= 1 and n <= SLOT_COUNT:
			return n
	return 1


func _remember_slot() -> void:
	var file := FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"slot": slot}))


## True while the player is in a zone (false on the title screen). Saved with
## the profile so a reloaded page can drop straight back into the game.
var playing := false

## How long after the last save a reloaded page resumes automatically (seconds).
const RESUME_WINDOW := 12 * 3600


## The browser can discard or reload the page while it is in the background
## (low memory, screen lock). If the last played slot says "in game" and was
## saved recently, the title screen is skipped.
func should_resume() -> bool:
	var raw := _read_slot(last_slot())
	if raw.is_empty():
		return false
	var age := Time.get_unix_time_from_system() - float(raw.get("saved_at", 0))
	return bool(raw.get("resume", false)) and age >= 0.0 and age < RESUME_WINDOW


func save() -> bool:
	if not has_profile:
		return false
	# Keep the last successful metadata and the dirty state until commit succeeds.
	var snapshot := profile.duplicate(true)
	snapshot["zone"] = String(current_zone)
	snapshot["resume"] = playing
	snapshot["saved_at"] = int(Time.get_unix_time_from_system())
	if not _write_profile(snapshot, slot):
		_dirty = true
		return false
	profile["zone"] = snapshot.zone
	profile["resume"] = snapshot.resume
	profile["saved_at"] = snapshot.saved_at
	_remember_slot()
	_autosave_timer = 0.0
	_dirty = false
	return true


## Same-directory rename keeps the previous save intact if writing fails.
func _write_profile(snapshot: Dictionary, destination: int) -> bool:
	if destination < 1 or destination > SLOT_COUNT:
		return false
	var path := save_path(destination)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	var dir := DirAccess.open("user://")
	return dir != null and dir.rename(path.get_file() + ".tmp", path.get_file()) == OK


## Loads a slot (default: the current one) and makes it the active one.
func load_game(from_slot := -1) -> bool:
	var target := slot if from_slot < 1 else from_slot
	var raw := _read_slot(target)
	if raw.is_empty():
		return false
	slot = target
	profile = _repair(raw)
	has_profile = true
	current_zone = StringName(profile.get("zone", "town"))
	_dirty = false
	_autosave_timer = 0.0
	_party_gear.clear()
	_remember_slot()
	profile_changed.emit()
	inventory_changed.emit()
	return true


func delete_save(for_slot := -1) -> void:
	var target := slot if for_slot < 1 else for_slot
	if has_save(target):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path(target)))
	if target == slot:
		has_profile = false
		profile = {}


## Reject wrong types before any typed gameplay code can touch imported JSON.
## Missing optional fields are supported for older saves; malformed ones are not.
func _valid_profile(data: Dictionary) -> bool:
	if not data.get("class") is String or not ClassData.CLASSES.has(StringName(data["class"])):
		return false
	if not _valid_integer(data.get("level"), 1, MAX_LEVEL):
		return false
	if not _valid_integer(data.get("version", SAVE_VERSION), 1, SAVE_VERSION):
		return false
	for key in ["exp", "points", "skill_points", "gold", "hp", "mp", "kills", "deaths", "saved_at"]:
		if not _valid_integer(data.get(key, 0)):
			return false
	if not _valid_number(data.get("play_time", 0.0)) or not _valid_integer(data.get("adv", 0), 0, JobData.MAX_ADV):
		return false
	if not _valid_integer(data.get("bag_slots", BASE_BAG), BASE_BAG, MAX_BAG):
		return false
	for key in ["name", "zone", "job", "spawn_override"]:
		if data.has(key) and not data[key] is String:
			return false
	for key in ["resume", "job3"]:
		if data.has(key) and not data[key] is bool:
			return false
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills", "pvp", "tower", "paragon", "ach", "look", "daily"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	for key in ["inv", "storage", "loadout", "party"]:
		if data.has(key) and not data[key] is Array:
			return false
	for key in ["attrs", "skills", "boss_kills", "pvp", "tower", "look"]:
		for value in data.get(key, {}).values():
			if not _valid_integer(value):
				return false
	for key in data.get("flags", {}):
		var value: Variant = data.flags[key]
		if key in ["daily_last", "arena_day"]:
			if not value is String:
				return false
		elif not _valid_integer(value):
			return false
	for value in data.get("ach", {}).values():
		if not value is bool:
			return false
	for key in ["inv", "storage"]:
		if data.get(key, []).size() > (MAX_BAG if key == "inv" else STORAGE_SIZE):
			return false
		for item in data.get(key, []):
			if not _valid_item(item):
				return false
	for equip_slot in data.get("equip", {}):
		var item: Variant = data.equip[equip_slot]
		if not ItemData.EQUIP_SLOTS.has(equip_slot) or not _valid_item(item):
			return false
		if item.kind != "equip" or item.slot != equip_slot:
			return false
	for skill_id in data.get("loadout", []):
		if not skill_id is String:
			return false
	for state in data.get("quests", {}).values():
		if not state is Dictionary or state.get("status", "new") not in ["new", "active", "ready", "done"] or not _valid_integer(state.get("progress", 0)):
			return false
	var para: Dictionary = data.get("paragon", {})
	for key in para:
		if key not in ["level", "exp", "points", "spent", "alloc"]:
			return false
	if not _valid_integer(para.get("level", 0), 0, PARAGON_MAX) or not para.get("alloc", {}) is Dictionary:
		return false
	for key in ["exp", "points", "spent"]:
		if not _valid_integer(para.get(key, 0)):
			return false
	for key in para.get("alloc", {}):
		if not PARAGON_STATS.has(key) or not _valid_integer(para.alloc[key], 0, int(PARAGON_STATS[key][2])):
			return false
	for member in data.get("party", []):
		if not member is Dictionary or not member.get("class") is String or not ClassData.IDS.has(StringName(member["class"])):
			return false
		if not member.get("name", "") is String or not _valid_integer(member.get("level", 1), 1, MAX_LEVEL) or not _valid_integer(member.get("exp", 0)):
			return false
		if member.get("stance", "follow") not in STANCES or member.get("trait", "brave") not in TRAIT_NAMES:
			return false
		for key in ["potions", "mp_potions", "hp", "mp"]:
			if not _valid_integer(member.get(key, 0)):
				return false
	if data.has("daily"):
		var daily_data: Dictionary = data.daily
		if not daily_data.get("chest", false) is bool:
			return false
		if not daily_data.get("date", "") is String or not daily_data.get("zone", "town") is String or not daily_data.get("quests", []) is Array:
			return false
		for entry in daily_data.get("quests", []):
			if not entry is Dictionary or not entry.get("id") is String or daily_template(entry.id).is_empty():
				return false
			if not _valid_integer(entry.get("progress", 0)) or not entry.get("claimed", false) is bool:
				return false
	return true


func _valid_number(value: Variant, minimum := 0.0, maximum := float(MAX_SAVE_NUMBER)) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _valid_integer(value: Variant, minimum := 0, maximum := MAX_SAVE_NUMBER) -> bool:
	return _valid_number(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


func _valid_gem_id(value: Variant) -> bool:
	if not value is String:
		return false
	var bits: PackedStringArray = value.split("_")
	return bits.size() == 2 and ItemData.GEMS.has(bits[0]) and bits[1] in ["0", "1", "2"]


func _valid_item(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var item: Dictionary = value
	if item.get("kind") in ["potion", "gem"]:
		# Stack items never contain equipment fields. Refuse ambiguous data before
		# item repair or UI code can accidentally interpret those nested values.
		for key in ["stats", "gems", "level", "rarity", "price", "plus", "sockets"]:
			if item.has(key):
				return false
		return _valid_integer(item.get("count", 1), 1) and (ItemData.POTIONS.has(item.get("id")) if item.kind == "potion" else _valid_gem_id(item.get("id")))
	if item.get("kind") != "equip" or not ItemData.EQUIP_SLOTS.has(item.get("slot")):
		return false
	for key in ["uid", "name", "class", "set", "base"]:
		if not item.get(key, "") is String:
			return false
	if not item.get("stats", {}) is Dictionary or not item.get("gems", []) is Array:
		return false
	if item.get("base", "") != "wings" and item.get("base", "") != "wand" and not ItemData.NAMES.has(item.get("base")):
		return false
	if item.get("slot") == "wings" and not (ItemData.WING_INFO.has(item.get("wing")) or ItemData.LEGACY_WING_KINDS.has(item.get("wing"))):
		return false
	if item.get("class", "") != "" and not ClassData.CLASSES.has(StringName(item["class"])):
		return false
	if not _valid_integer(item.get("level"), 1) or not _valid_integer(item.get("rarity", 0), 0, 4):
		return false
	if not _valid_integer(item.get("plus", 0), 0, ItemData.MAX_PLUS) or not _valid_integer(item.get("sockets", 0), 0, 3) or not _valid_integer(item.get("price", 0)):
		return false
	for key in item.get("stats", {}):
		if not ItemData.STAT_LABELS.has(key) or not _valid_number(item.stats[key], 0.0, 10000000.0):
			return false
	if item.get("gems", []).size() > int(item.get("sockets", 0)):
		return false
	for gem_id in item.get("gems", []):
		if not _valid_gem_id(gem_id):
			return false
	return true


## JSON turns ints into floats: restore the types the game expects.
func _repair(data: Dictionary) -> Dictionary:
	var has_hp := data.has("hp")
	var has_mp := data.has("mp")
	for key in ["level", "exp", "points", "skill_points", "gold", "hp", "mp", "kills", "deaths"]:
		data[key] = int(data.get(key, 0))
	data["level"] = maxi(1, int(data["level"]))
	data["version"] = SAVE_VERSION
	data["name"] = String(data.get("name", "นักเดินทาง")).strip_edges().left(80)
	data["play_time"] = float(data.get("play_time", 0.0))
	var zone := StringName(data.get("zone", "town"))
	data["zone"] = String(zone) if ZoneData.ZONES.has(zone) and zone not in [&"pvp", &"tower"] else "town"
	if data.get("look") is Dictionary:
		data["look"] = FaceKit.repair(data["look"])
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills", "pvp"]:
		if not data.get(key) is Dictionary:
			data[key] = {}
	if not data.get("inv") is Array:
		data["inv"] = []
	if not data.get("storage") is Array:
		data["storage"] = []
	data["bag_slots"] = int(data.get("bag_slots", BASE_BAG))
	for stored in data["storage"]:
		_repair_item(stored)
	for key in ["str", "int", "dex", "vit"]:
		data.attrs[key] = int(data.attrs.get(key, 0))
	for skill_id in data.skills.keys():
		data.skills[skill_id] = clampi(int(data.skills[skill_id]), 0, MAX_SKILL_RANK)
	# Older saves: "job" (first advancement) and "job3" (second) became the "adv" step count.
	if not data.has("adv"):
		data["adv"] = 0
		if data.get("job", "") != "":
			data["adv"] = 2 if bool(data.get("job3", false)) else 1
	data.erase("job")
	data.erase("job3")
	data["adv"] = clampi(int(data["adv"]), 0, JobData.MAX_ADV)
	for key in data["flags"]:
		if data["flags"][key] is float:
			data["flags"][key] = int(data["flags"][key])
	for key in data["pvp"]:
		data["pvp"][key] = int(data["pvp"][key])
	if not data.get("tower") is Dictionary:
		data["tower"] = {}
	for key in data["tower"]:
		data["tower"][key] = int(data["tower"][key])
	if not data.get("paragon") is Dictionary:
		data["paragon"] = {}
	for key in data["paragon"]:
		if data["paragon"][key] is Dictionary:
			for k2 in data["paragon"][key]:
				data["paragon"][key][k2] = int(data["paragon"][key][k2])
		else:
			data["paragon"][key] = int(data["paragon"][key])
	_migrate_skills(data)
	for item in data.inv:
		_repair_item(item)
	for slot in data.equip:
		_repair_item(data.equip[slot])
	# Wings from before class wings turn into this class's pair.
	for item in data.inv + data.storage + data.equip.values():
		if item is Dictionary:
			ItemData.migrate_wings(item, String(data.get("class", "warrior")))
	# Recover overflow stranded by saves from before the Lv.100 handoff fix.
	if int(data.level) == MAX_LEVEL and int(data.exp) > 0:
		var para: Dictionary = data.paragon
		para["level"] = int(para.get("level", 0))
		para["exp"] = int(para.get("exp", 0)) + int(data.exp)
		para["points"] = int(para.get("points", 0))
		while int(para.level) < PARAGON_MAX:
			var need := int(float(HeroStats.exp_to_next(MAX_LEVEL)) * (1.0 + 0.02 * float(para.level)))
			if int(para.exp) < need:
				break
			para["exp"] = int(para.exp) - need
			para["level"] = int(para.level) + 1
			para["points"] = int(para.points) + 1
		if int(para.level) == PARAGON_MAX:
			para["exp"] = 0
		data["exp"] = 0
	if data.has("party"):
		data["party"] = data.party.slice(0, 1)
		for member in data.party:
			member["name"] = member.get("name", "เพื่อนร่วมทาง")
			member["level"] = int(member.get("level", 1))
			member["exp"] = int(member.get("exp", 0))
	for entry in data.get("daily", {}).get("quests", []):
		entry["progress"] = int(entry.get("progress", 0))
		entry["claimed"] = bool(entry.get("claimed", false))
	var stats := HeroStats.compute(data)
	data["hp"] = clampi(int(data.hp), 0, int(stats.max_hp)) if has_hp else int(stats.max_hp)
	data["mp"] = clampi(int(data.mp), 0, int(stats.max_mp)) if has_mp else int(stats.max_mp)
	return data


## Saves from before the Priston Tale skill system: refund the skill points
## spent on the old skills and start with a fresh bar.
func _migrate_skills(data: Dictionary) -> void:
	var cls := StringName(data.get("class", "warrior"))
	var valid := {}
	for skill in ClassData.pool(cls):
		valid[skill.id] = true
	for skill in ClassData.PASSIVES.get(cls, []):
		valid[skill.id] = true
	for skill_id in data.skills.keys():
		if not valid.has(skill_id):
			data["skill_points"] = int(data["skill_points"]) + maxi(0, int(data.skills[skill_id]) - 1)
			data.skills.erase(skill_id)
	if not data.get("loadout") is Array:
		data["loadout"] = ["", "", "", "", "", "", "", ""]
	data["loadout"] = ClassData.default_loadout(cls, int(data["level"]), data["loadout"], ClassData.tier_of(cls, int(data.get("adv", 0))))


func _repair_item(item: Dictionary) -> void:
	# The priest's wands became staffs: same tier, staff name.
	if item.get("base", "") == "wand":
		item["base"] = "staff"
		var named := String(item.get("name", ""))
		for tier in ItemData.LEGACY_WAND_NAMES.size():
			if named.begins_with(ItemData.LEGACY_WAND_NAMES[tier] + " ") or named == ItemData.LEGACY_WAND_NAMES[tier]:
				item["name"] = ItemData.NAMES.staff[tier] + named.substr(String(ItemData.LEGACY_WAND_NAMES[tier]).length())
				break
	if item.get("kind") == "equip":
		for key in ["price", "plus", "sockets", "rarity"]:
			item[key] = int(item.get(key, 0))
		item["stats"] = item.get("stats", {})
		item["gems"] = item.get("gems", [])
	else:
		item["count"] = int(item.get("count", 1))
	# Older saves may hold gear above the star cap.
	if item.has("level") and int(item.level) > ItemData.MAX_GEAR_LEVEL:
		item["level"] = ItemData.MAX_GEAR_LEVEL
	for key in ["count", "rarity", "level", "price", "plus", "sockets"]:
		if item.has(key):
			item[key] = int(item[key])
	for key in item.get("stats", {}):
		if key != "crit":
			item.stats[key] = int(item.stats[key])


func mark_dirty() -> void:
	_dirty = true


func say(text: String, kind: StringName = &"info") -> void:
	toast.emit(text, kind)


# ---------------------------------------------------------------------------
# EXP / level
# ---------------------------------------------------------------------------

func add_exp(amount: int) -> void:
	if amount <= 0 or not has_profile:
		return
	if profile["level"] >= MAX_LEVEL:
		_add_paragon_exp(amount)
		return
	profile["exp"] += amount
	var gained := false
	while profile["level"] < MAX_LEVEL and profile["exp"] >= HeroStats.exp_to_next(profile["level"]):
		profile["exp"] -= HeroStats.exp_to_next(profile["level"])
		profile["level"] += 1
		profile["points"] += STAT_POINTS_PER_LEVEL
		profile["skill_points"] += 1
		gained = true
	# The same reward can reach Lv.100 and start earning Paragon immediately.
	if int(profile["level"]) >= MAX_LEVEL and int(profile["exp"]) > 0:
		var overflow := int(profile["exp"])
		profile["exp"] = 0
		_add_paragon_exp(overflow)
	exp_changed.emit()
	if gained:
		fill_loadout()
		var stats := stats_now()
		profile["hp"] = stats.max_hp
		profile["mp"] = stats.max_mp
		leveled_up.emit(profile["level"])
		profile_changed.emit()
		check_achievements()
		if profile.has("party"):
			party_catch_up()
		save()
	mark_dirty()


# ---------------------------------------------------------------------------
# AI party: two companions that fight beside the hero and share EXP
# ---------------------------------------------------------------------------

const PARTY_NAMES := {&"warrior": ["บราโว่", "ทอม"], &"archer": ["ลูน่า", "ฟ้า"], &"mage": ["มิกะ", "เจน"], &"priest": ["นีน่า", "ใบบัว"], &"summoner": ["ไลรา", "เฟิร์น"], &"lancer": ["เรย์", "ซากุระ"]}
## Which chibi model a companion wears (0 boy, 1 girl), from its name.
const PARTY_GIRLS := ["ลูน่า", "ฟ้า", "มิกะ", "เจน", "นีน่า", "ใบบัว", "ไลรา", "เฟิร์น", "ซากุระ"]


func party_gender(member: Dictionary) -> int:
	return 1 if String(member.get("name", "")) in PARTY_GIRLS else 0


const PARTY_BLURBS := {
	&"warrior": "นักรบเกราะหนา ยืนหน้าคอยรับดาเมจ",
	&"archer": "นักธนู ยิงไกลและคริติคอลสูง",
	&"mage": "จอมเวท ตีหมู่แรง แต่เลือดน้อย",
	&"priest": "พรีสต์ ฮีลและเสริมพลังให้คุณ",
	&"summoner": "ผู้เรียกอสูร เรียกสัตว์ป่ามาช่วยรบ",
	&"lancer": "นักหอก แทงทะลุหลายตัว ตีไว",
}
var _party_gear: Dictionary = {}


## One AI companion. New and old saves without a party get a default one
## (a priest, or a mage for a priest); older saves with two keep the first.
func ensure_party() -> void:
	var party: Variant = profile.get("party")
	if party is Array:
		if party.size() > 1:
			profile["party"] = party.slice(0, 1)
		for member in profile["party"]:
			member["level"] = maxi(1, int(member.get("level", 1)))
			member["exp"] = int(member.get("exp", 0))
		return
	recruit(&"mage" if class_id() == &"priest" else &"priest", false)


## Hire a companion of the given class (replaces the current one).
func recruit(c: StringName, announce := true) -> void:
	var names: Array = PARTY_NAMES[c]
	profile["party"] = [{"class": String(c), "name": names[randi() % names.size()], "level": maxi(1, int(profile["level"]) - 1), "exp": 0, "stance": "follow", "trait": ["brave", "careful"][randi() % 2]}]
	mark_dirty()
	party_changed.emit()
	if announce:
		party_roster_changed.emit()


const STANCES := ["follow", "aggressive", "guard"]
const STANCE_NAMES := {"follow": "ตามติด", "aggressive": "บุกลุย", "guard": "ป้องกัน"}
const TRAIT_NAMES := {"brave": "กล้าหาญ", "careful": "ระมัดระวัง"}


## Tap the party card: follow -> aggressive -> guard.
func cycle_stance() -> String:
	var list := party()
	if list.is_empty():
		return ""
	var member: Dictionary = list[0]
	var i := STANCES.find(String(member.get("stance", "follow")))
	member["stance"] = STANCES[(i + 1) % STANCES.size()]
	mark_dirty()
	party_changed.emit()
	return String(member.stance)


func dismiss_party() -> void:
	profile["party"] = []
	mark_dirty()
	party_changed.emit()
	party_roster_changed.emit()


func party() -> Array:
	ensure_party()
	return profile["party"]


## A fake profile so [HeroStats] can work out a companion's stats.
func party_profile(member: Dictionary) -> Dictionary:
	return {"class": member["class"], "level": int(member.level), "attrs": {}, "equip": party_equip(member), "adv": JobData.adv_for_level(int(member.level))}


## Gear that grows with the companion's level (same pieces until the next tier).
func party_equip(member: Dictionary) -> Dictionary:
	var tier := ItemData.tier_for(int(member.level))
	var key := "%s|%d|%d" % [member.name, tier, int(member.level) / 3]
	if _party_gear.has(key):
		return _party_gear[key]
	var local := RandomNumberGenerator.new()
	local.seed = hash(key)
	var gear := {}
	for slot in ["weapon", "armor", "helm"]:
		gear[slot] = ItemData.generate(maxi(1, int(member.level)), StringName(member["class"]), local, 1, slot)
	_party_gear[key] = gear
	return gear


## Every kill's EXP goes to the whole party too: they level up together.
func party_add_exp(amount: int) -> void:
	for i in party().size():
		var member: Dictionary = profile["party"][i]
		if int(member.level) >= MAX_LEVEL:
			continue
		member["exp"] = int(member.exp) + amount
		var gained := false
		while int(member.level) < MAX_LEVEL and int(member.exp) >= HeroStats.exp_to_next(int(member.level)):
			member["exp"] = int(member.exp) - HeroStats.exp_to_next(int(member.level))
			member["level"] = int(member.level) + 1
			gained = true
		if gained:
			party_leveled.emit(i, int(member.level))
	party_changed.emit()
	mark_dirty()


## Companions never fall far behind the hero's level.
func party_catch_up() -> void:
	for i in party().size():
		var member: Dictionary = profile["party"][i]
		var floor_level := maxi(1, int(profile["level"]) - 2)
		if int(member.level) < floor_level:
			member["level"] = floor_level
			member["exp"] = 0
			party_leveled.emit(i, floor_level)
	party_changed.emit()


func exp_ratio() -> float:
	if int(profile["level"]) >= MAX_LEVEL:
		var need := paragon_need()
		return 1.0 if need <= 0 else float(paragon().exp) / float(need)
	return float(profile["exp"]) / float(HeroStats.exp_to_next(profile["level"]))


# ---------------------------------------------------------------------------
# Void Tower and Void Shards
# ---------------------------------------------------------------------------

func tower() -> Dictionary:
	if not profile.get("tower") is Dictionary:
		profile["tower"] = {}
	var t: Dictionary = profile["tower"]
	for key in ["best", "shards", "runs", "best_before"]:
		t[key] = int(t.get(key, 0))
	return t


func tower_add_shards(amount: int) -> void:
	tower()["shards"] = int(tower().shards) + amount
	mark_dirty()


func tower_floor_cleared(floor_no: int) -> void:
	var t := tower()
	if floor_no > int(t.best):
		t["best"] = floor_no
	flag_max("tower_best", int(t.best))
	check_achievements()
	mark_dirty()


func tower_begin_run() -> void:
	var t := tower()
	t["runs"] = int(t.runs) + 1
	t["best_before"] = int(t.best)


func tower_spend(cost: int) -> bool:
	var t := tower()
	if int(t.shards) < cost:
		return false
	t["shards"] = int(t.shards) - cost
	mark_dirty()
	return true


## Re-rolls the random stats and rarity of a pair of wings (same class, plus and gems stay).
func tower_reroll_wings(item: Dictionary) -> String:
	if String(item.get("slot", "")) != "wings":
		return "ใช้กับปีกเท่านั้น"
	if int(tower().shards) < TowerData.COST_REROLL:
		return "ผลึกไม่พอ (ต้องใช้ %d)" % TowerData.COST_REROLL
	var fresh := ItemData.wings(rng, String(item.get("wing", "warrior")))
	tower_spend(TowerData.COST_REROLL)
	item["stats"] = fresh.stats
	item["rarity"] = fresh.rarity
	item["name"] = fresh.name
	item["price"] = fresh.price
	item["sockets"] = maxi(int(fresh.sockets), (item.get("gems", []) as Array).size())
	clamp_vitals()
	profile_changed.emit()
	inventory_changed.emit()
	mark_dirty()
	return "ok"


## "gear": a Lv.100 piece of legendary-or-better gear; "gem": a large gem.
func tower_buy(kind: String) -> String:
	var cost := TowerData.COST_GEAR if kind == "gear" else TowerData.COST_GEM
	if int(tower().shards) < cost:
		return "ผลึกไม่พอ (ต้องใช้ %d)" % cost
	if inventory_free() <= 0 and kind == "gear":
		return "กระเป๋าเต็ม"
	var item: Dictionary
	if kind == "gear":
		item = ItemData.generate(star_gear_level(), class_id(), rng, maxi(3, ItemData.roll_rarity(rng, 0.45)))
	else:
		var kinds := ItemData.GEMS.keys()
		item = ItemData.gem(String(kinds[rng.randi() % kinds.size()]), 2)
	if not add_item(item):
		return "กระเป๋าเต็ม"
	tower_spend(cost)
	return "ok:" + ItemData.name_of(item)


# ---------------------------------------------------------------------------
# Paragon: after Lv.100 EXP keeps levelling the hero up to ★200. Each ★ gives a
# point to spend on permanent bonuses (see PARAGON_STATS).
# ---------------------------------------------------------------------------

const PARAGON_MAX := 200
## key: [name, bonus per point, max points, what it does]
const PARAGON_STATS := {
	"atk": ["พลังโจมตี", 0.003, 60, "พลังโจมตี +0.3%% ต่อแต้ม"],
	"def": ["พลังป้องกัน", 0.005, 60, "พลังป้องกัน +0.5%% ต่อแต้ม"],
	"hp": ["พลังชีวิต", 0.008, 60, "HP สูงสุด +0.8%% ต่อแต้ม"],
	"crit": ["คริติคอล", 0.001, 50, "คริติคอล +0.1%% ต่อแต้ม"],
	"haste": ["ความเร็วสกิล", 0.001, 40, "ความเร็วสกิล +0.1%% ต่อแต้ม"],
}


func paragon() -> Dictionary:
	if not profile.get("paragon") is Dictionary:
		profile["paragon"] = {}
	var p: Dictionary = profile["paragon"]
	for key in ["level", "exp", "points", "spent"]:
		p[key] = int(p.get(key, 0))
	if not p.get("alloc") is Dictionary:
		p["alloc"] = {}
	for key in PARAGON_STATS:
		p["alloc"][key] = int(p["alloc"].get(key, 0))
	return p


## EXP for the next ★ (grows with each ★).
func paragon_need() -> int:
	var lv := int(paragon().level)
	if lv >= PARAGON_MAX:
		return 0
	return int(float(HeroStats.exp_to_next(MAX_LEVEL)) * (1.0 + 0.02 * float(lv)))


func _add_paragon_exp(amount: int) -> void:
	var p := paragon()
	if int(p.level) >= PARAGON_MAX:
		exp_changed.emit()
		return
	p["exp"] = int(p.exp) + amount
	var gained := 0
	while int(p.level) < PARAGON_MAX and int(p.exp) >= paragon_need():
		p["exp"] = int(p.exp) - paragon_need()
		p["level"] = int(p.level) + 1
		p["points"] = int(p.points) + 1
		gained += 1
		flag_max("paragon_level", int(p.level))
		if int(p.level) % 25 == 0:
			add_gold(int(p.level) * 2000)
			say("เหรียญรางวัลหลักไมล์ ดาว %d: +%d" % [int(p.level), int(p.level) * 2000], &"success")
	if int(p.level) >= PARAGON_MAX:
		p["exp"] = 0
	exp_changed.emit()
	if gained > 0:
		paragon_leveled.emit(int(p.level))
		profile_changed.emit()
		check_achievements()
		save()
	mark_dirty()


## Level of a star-zone gear drop: Lv.100 (30%) or 100 + a few stars above your
## paragon level (the extra is the tower floor bonus).
func star_gear_level(bonus := 0) -> int:
	if rng.randf() < 0.15:
		return MAX_LEVEL
	var star := int(paragon().level) + rng.randi_range(1, 8) + bonus
	return MAX_LEVEL + clampi(star, 1, ItemData.MAX_GEAR_STAR)


func paragon_spend(key: String) -> bool:
	var p := paragon()
	var info: Array = PARAGON_STATS.get(key, [])
	if info.is_empty() or int(p.points) <= 0 or int(p.alloc[key]) >= int(info[2]):
		return false
	p["points"] = int(p.points) - 1
	p["spent"] = int(p.spent) + 1
	p["alloc"][key] = int(p.alloc[key]) + 1
	clamp_vitals()
	profile_changed.emit()
	mark_dirty()
	return true


func paragon_reset_cost() -> int:
	return 20000 + 1000 * int(paragon().spent)


## Gives every spent point back for gold.
func paragon_reset() -> bool:
	var p := paragon()
	if int(p.spent) <= 0 or not spend_gold(paragon_reset_cost()):
		return false
	p["points"] = int(p.points) + int(p.spent)
	p["spent"] = 0
	for key in PARAGON_STATS:
		p["alloc"][key] = 0
	clamp_vitals()
	profile_changed.emit()
	mark_dirty()
	return true


func spend_point(attr: String) -> bool:
	if profile["points"] <= 0 or not profile["attrs"].has(attr):
		return false
	profile["points"] -= 1
	profile["attrs"][attr] += 1
	profile_changed.emit()
	mark_dirty()
	return true


func skill_rank(skill_id: String) -> int:
	return int(profile["skills"].get(skill_id, 0))


func skill_unlocked(skill: Dictionary) -> bool:
	return profile["level"] >= int(skill.level) and class_tier() >= ClassData.skill_tier(skill)


## 0 Vagabond, 1 line (Lv.10), then 2..5 for the four advancements (Lv.20/40/60/80).
func class_tier() -> int:
	return ClassData.tier_of(class_id(), adv())


## Why a skill cannot be used yet ("" when it can).
func skill_lock_reason(skill: Dictionary) -> String:
	if profile["level"] < int(skill.level):
		return "ปลดล็อกที่เลเวล %d" % int(skill.level)
	var need := ClassData.skill_tier(skill)
	if class_tier() < need:
		return "ต้องเปลี่ยนเป็น%s (Lv.%d)" % [JobData.tier_name(class_id(), need), ClassData.LINE_LEVEL if need == 1 else JobData.tier_level(need)]
	return ""


## Skills start at rank 1 once their level is reached; ranks 2-5 cost a skill point.
func effective_rank(skill: Dictionary) -> int:
	return maxi(1, skill_rank(skill.id)) if skill_unlocked(skill) else 0


## Radius multiplier of an area skill at a star rank.
func radius_scale(rank: int) -> float:
	return 1.0 + RADIUS_PER_STAR * float(maxi(rank, 1) - 1)


## Gold the Skill Master charges to raise a skill from its current rank.
func skill_upgrade_cost(skill: Dictionary) -> int:
	return 60 * effective_rank(skill) * maxi(1, int(skill.level) / 5)


## Done at the Skill Master: costs one skill point and gold per rank.
func upgrade_skill(skill: Dictionary) -> bool:
	if profile["skill_points"] <= 0 or not skill_unlocked(skill):
		return false
	var rank := effective_rank(skill)
	if rank >= MAX_SKILL_RANK or int(profile["gold"]) < skill_upgrade_cost(skill):
		return false
	profile["gold"] -= skill_upgrade_cost(skill)
	gold_changed.emit(profile["gold"])
	profile["skill_points"] -= 1
	profile["skills"][skill.id] = rank + 1
	profile_changed.emit()
	mark_dirty()
	return true


# ---------------------------------------------------------------------------
# Gold & inventory
# ---------------------------------------------------------------------------

func add_gold(amount: int) -> void:
	profile["gold"] = maxi(0, int(profile["gold"]) + amount)
	gold_changed.emit(profile["gold"])
	mark_dirty()


func spend_gold(amount: int) -> bool:
	if profile["gold"] < amount:
		return false
	add_gold(-amount)
	return true


func bag_size() -> int:
	return clampi(int(profile.get("bag_slots", BASE_BAG)), BASE_BAG, MAX_BAG)


func inventory_free() -> int:
	return bag_size() - profile["inv"].size()


## Gold for the next +10 bag slots at the storage keeper (0 when maxed).
func bag_expand_cost() -> int:
	if bag_size() >= MAX_BAG:
		return 0
	return 1500 * ((bag_size() - BASE_BAG) / BAG_STEP + 1)


func expand_bag() -> bool:
	var cost := bag_expand_cost()
	if cost <= 0 or int(profile["gold"]) < cost:
		return false
	add_gold(-cost)
	profile["bag_slots"] = bag_size() + BAG_STEP
	inventory_changed.emit()
	mark_dirty()
	return true


# --- storage (the warehouse in the village) ----------------------------------

func storage() -> Array:
	if not profile.get("storage") is Array:
		profile["storage"] = []
	return profile["storage"]


func _stack_into(list: Array, item: Dictionary) -> bool:
	if ItemData.is_stackable(item):
		for existing in list:
			if existing.get("kind", "") == item.get("kind", "") and existing.id == item.id:
				existing["count"] = int(existing["count"]) + int(item.get("count", 1))
				return true
	return false


## Moves a whole bag entry into the storage. Returns false when storage is full.
func deposit_item(index: int) -> bool:
	if index < 0 or index >= profile["inv"].size():
		return false
	var item: Dictionary = profile["inv"][index]
	var list := storage()
	if not _stack_into(list, item):
		if list.size() >= STORAGE_SIZE:
			return false
		list.append(item)
	profile["inv"].remove_at(index)
	inventory_changed.emit()
	mark_dirty()
	return true


## Moves a storage entry back into the bag. Returns false when the bag is full.
func withdraw_item(index: int) -> bool:
	var list := storage()
	if index < 0 or index >= list.size():
		return false
	var item: Dictionary = list[index]
	if not _stack_into(profile["inv"], item):
		if profile["inv"].size() >= bag_size():
			return false
		profile["inv"].append(item)
	else:
		inventory_changed.emit()
	list.remove_at(index)
	inventory_changed.emit()
	mark_dirty()
	return true


## Adds an item (stacking potions). Returns false when the bag is full.
func add_item(item: Dictionary) -> bool:
	if ItemData.is_stackable(item):
		for existing in profile["inv"]:
			if existing.get("kind", "") == item.get("kind", "") and existing.id == item.id:
				existing["count"] = int(existing["count"]) + int(item.get("count", 1))
				inventory_changed.emit()
				item_gained.emit(item)
				mark_dirty()
				return true
	if profile["inv"].size() >= bag_size():
		return false
	profile["inv"].append(item)
	if item.get("kind", "") == "equip" and int(item.get("rarity", 0)) >= 3:
		flag_max("got_legend", 1)
		if int(item.get("rarity", 0)) >= 4:
			flag_max("got_mythic", 1)
		check_achievements()
	inventory_changed.emit()
	item_gained.emit(item)
	mark_dirty()
	return true


## One forge attempt (+1). Returns "ok", "fail" (gold spent, nothing else lost) or a reason.
func enhance_item(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return "ไอเทมนี้ตีบวกไม่ได้"
	if not EnhanceFx.can_enhance(item):
		return "แหวนกับสร้อยตีบวกไม่ได้"
	var plus := int(item.get("plus", 0))
	if plus >= ItemData.MAX_PLUS:
		return "บวกสูงสุดแล้ว"
	var cost := ItemData.enhance_cost(item)
	if int(profile["gold"]) < cost:
		return "เหรียญไม่พอ (ต้องใช้ %d)" % cost
	add_gold(-cost)
	if rng.randf() < ItemData.enhance_chance(plus):
		item["plus"] = plus + 1
		item["price"] = int(int(item.price) * 1.12)
		flag_max("best_plus", plus + 1)
		check_achievements()
		clamp_vitals()
		inventory_changed.emit()
		profile_changed.emit()
		mark_dirty()
		return "ok"
	inventory_changed.emit()
	mark_dirty()
	return "fail"


## Puts the gem at bag index into the item's next free socket.
func socket_gem(item: Dictionary, gem_index: int) -> bool:
	if gem_index < 0 or gem_index >= profile["inv"].size():
		return false
	var gem: Dictionary = profile["inv"][gem_index]
	if gem.get("kind", "") != "gem" or item.get("kind", "") != "equip":
		return false
	if not item.has("gems"):
		item["gems"] = []
	if (item["gems"] as Array).size() >= int(item.get("sockets", 0)):
		return false
	(item["gems"] as Array).append(String(gem.id))
	flag_add("gems_set")
	remove_item_at(gem_index, 1)
	check_achievements()
	clamp_vitals()
	profile_changed.emit()
	inventory_changed.emit()
	mark_dirty()
	return true


## Takes the gem in a socket back out into the bag (it is not lost).
func unsocket_gem(item: Dictionary, socket_index: int) -> String:
	var gems: Array = item.get("gems", [])
	if socket_index < 0 or socket_index >= gems.size():
		return "ไม่มีอัญมณีในช่องนี้"
	var bits := String(gems[socket_index]).split("_")
	var gem := ItemData.gem(bits[0], int(bits[1]))
	if not add_item(gem):
		return "กระเป๋าเต็ม"
	gems.remove_at(socket_index)
	clamp_vitals()
	profile_changed.emit()
	inventory_changed.emit()
	mark_dirty()
	return "ok"


func remove_item_at(index: int, count := 1) -> void:
	if index < 0 or index >= profile["inv"].size():
		return
	var item: Dictionary = profile["inv"][index]
	if ItemData.is_stackable(item) and int(item.count) > count:
		item["count"] = int(item.count) - count
	else:
		profile["inv"].remove_at(index)
	inventory_changed.emit()
	mark_dirty()


func potion_count(id: String) -> int:
	for item in profile["inv"]:
		if item.get("kind", "") == "potion" and item.id == id:
			return int(item.count)
	return 0


func total_potions(kind: String) -> int:
	var total := 0
	for item in profile["inv"]:
		if item.get("kind", "") == "potion" and ItemData.POTIONS[item.id].has(kind):
			total += int(item.count)
	return total


## Uses the smallest potion that still helps: "hp" or "mp". Returns its id or "".
func quick_potion(kind: String) -> String:
	var stats := stats_now()
	var missing: int = (stats.max_hp - profile["hp"]) if kind == "hp" else (stats.max_mp - profile["mp"])
	if missing <= 0:
		return ""
	var best_index := -1
	var best_value := 0
	for i in profile["inv"].size():
		var item: Dictionary = profile["inv"][i]
		if item.get("kind", "") != "potion" or not ItemData.POTIONS[item.id].has(kind):
			continue
		var value: int = ItemData.POTIONS[item.id][kind]
		if best_index == -1 or (best_value < missing and value > best_value) or (value >= missing and value < best_value):
			best_index = i
			best_value = value
	if best_index == -1:
		return ""
	var id: String = profile["inv"][best_index].id
	use_potion_at(best_index)
	return id


## A companion drinks from the shared bag: takes the smallest potion that covers
## `missing` (or the biggest one available) and returns its restore value, 0 if none.
func take_potion_for_ally(kind: String, missing: int) -> int:
	if in_duel() or missing <= 0:
		return 0
	var best_index := -1
	var best_value := 0
	for i in profile["inv"].size():
		var item: Dictionary = profile["inv"][i]
		if item.get("kind", "") != "potion" or not ItemData.POTIONS[item.id].has(kind):
			continue
		var value: int = ItemData.POTIONS[item.id][kind]
		if best_index == -1 or (best_value < missing and value > best_value) or (value >= missing and value < best_value):
			best_index = i
			best_value = value
	if best_index == -1:
		return 0
	remove_item_at(best_index)
	profile_changed.emit()
	return best_value


## True while inside a ranked duel (no potions, no escaping).
func in_duel() -> bool:
	return current_zone == &"pvp"


func use_potion_at(index: int) -> String:
	var item: Dictionary = profile["inv"][index]
	if item.get("kind", "") != "potion":
		return ""
	if in_duel():
		say("ใช้ยาในสนามจัดอันดับไม่ได้", &"warning")
		return ""
	var def: Dictionary = ItemData.POTIONS[item.id]
	var stats := stats_now()
	if def.has("hp"):
		profile["hp"] = mini(stats.max_hp, profile["hp"] + int(def.hp))
	if def.has("mp"):
		profile["mp"] = mini(stats.max_mp, profile["mp"] + int(def.mp))
	var id: String = item.id
	remove_item_at(index)
	profile_changed.emit()
	return id


# ---------------------------------------------------------------------------
# Equipment
# ---------------------------------------------------------------------------

## null-safe reason an item cannot be worn ("" = ok).
func equip_problem(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return "ใส่ไม่ได้"
	# Gear above Lv.100 (dropped in the arena and the tower) needs paragon levels:
	# Lv.101 needs ★1, Lv.102 needs ★2 and so on.
	if int(item.level) > int(profile["level"]):
		if int(item.level) <= MAX_LEVEL:
			return "ต้องเลเวล %d" % int(item.level)
		var star := int(item.level) - MAX_LEVEL
		if int(profile["level"]) < MAX_LEVEL or int(paragon().level) < star:
			return "ต้องเลเวล 100 และระดับเหนือเลเวล ดาว %d" % star
	if item.get("class", "") != "" and item["class"] != profile["class"]:
		return "สำหรับอาชีพอื่น"
	return ""


func equip_from_bag(index: int) -> bool:
	var item: Dictionary = profile["inv"][index]
	var problem := equip_problem(item)
	if problem != "":
		say(problem, &"warning")
		return false
	var slot: String = item.slot
	var old: Variant = profile["equip"].get(slot)
	profile["equip"][slot] = item
	profile["inv"].remove_at(index)
	if old != null:
		profile["inv"].insert(index, old)
	clamp_vitals()
	inventory_changed.emit()
	profile_changed.emit()
	mark_dirty()
	return true


func unequip(slot: String) -> bool:
	if not profile["equip"].has(slot) or profile["inv"].size() >= bag_size():
		return false
	profile["inv"].append(profile["equip"][slot])
	profile["equip"].erase(slot)
	clamp_vitals()
	inventory_changed.emit()
	profile_changed.emit()
	mark_dirty()
	return true


func clamp_vitals() -> void:
	var stats := stats_now()
	profile["hp"] = clampi(profile["hp"], 0, stats.max_hp)
	profile["mp"] = clampi(profile["mp"], 0, stats.max_mp)


func sell_item(index: int, count := 1) -> void:
	var item: Dictionary = profile["inv"][index]
	var each := ItemData.unit_sell_price(item)
	var qty := count if ItemData.is_stackable(item) else 1
	add_gold(each * qty)
	remove_item_at(index, qty)


func buy_item(item: Dictionary) -> bool:
	var price := ItemData.buy_price(item) * (int(item.get("count", 1)) if ItemData.is_stackable(item) else 1)
	if profile["gold"] < price:
		say("เหรียญไม่พอ", &"warning")
		return false
	if not ItemData.is_stackable(item) and inventory_free() <= 0:
		say("กระเป๋าเต็ม", &"warning")
		return false
	spend_gold(price)
	add_item(item)
	return true


# ---------------------------------------------------------------------------
# Quests (see QuestData)
# ---------------------------------------------------------------------------

func quest_state(quest_id: String) -> Dictionary:
	return profile["quests"].get(quest_id, {})


func quest_status(quest_id: String) -> String:
	return String(quest_state(quest_id).get("status", "new"))


func set_quest(quest_id: String, status: String, progress := -1) -> void:
	var state: Dictionary = profile["quests"].get(quest_id, {"progress": 0})
	state["status"] = status
	if progress >= 0:
		state["progress"] = progress
	profile["quests"][quest_id] = state
	quest_changed.emit()
	mark_dirty()


## Counts a kill for every active quest hunting this monster.
func report_kill(monster_id: StringName, is_boss := false) -> void:
	profile["kills"] = int(profile["kills"]) + 1
	for quest_id in profile["quests"]:
		var state: Dictionary = profile["quests"][quest_id]
		if state.get("status", "") != "active":
			continue
		var quest := QuestData.get_quest(quest_id)
		if quest.is_empty() or StringName(quest.target) != monster_id:
			continue
		state["progress"] = mini(int(state.get("progress", 0)) + 1, int(quest.count))
		if int(state["progress"]) >= int(quest.count):
			state["status"] = "ready"
			say("เควสต์ \"%s\" เสร็จแล้ว! กลับไปรายงาน" % quest.name, &"quest")
		quest_changed.emit()
	if is_boss:
		profile["boss_kills"][String(monster_id)] = int(profile["boss_kills"].get(String(monster_id), 0)) + 1
	if is_boss and monster_id == &"magma_dragon" and int(profile["flags"].get("ending_seen", 0)) == 0:
		profile["flags"]["ending_seen"] = 1
		get_tree().create_timer(2.5).timeout.connect(func(): ending_requested.emit())
	daily_progress("kills", 1)
	daily_progress("zone_kills", 1)
	if is_boss:
		daily_progress("boss", 1)
	check_achievements()
	mark_dirty()


# ---------------------------------------------------------------------------
# Daily quests and achievements (see GoalsData)
# ---------------------------------------------------------------------------

## Today's three daily quests, created the first time they are needed each day.
func daily() -> Dictionary:
	var today := GoalsData.today()
	var current: Variant = profile.get("daily")
	if current is Dictionary and current.get("date", "") == today and (current.get("quests", []) as Array).size() == 3:
		return current
	var quests: Array = []
	for template in GoalsData.pick_for_date(today):
		quests.append({"id": template.id, "progress": 0, "claimed": false})
	profile["daily"] = {"date": today, "quests": quests, "zone": String(current_zone)}
	return profile["daily"]


func daily_template(id: String) -> Dictionary:
	for template in GoalsData.DAILY_POOL:
		if template.id == id:
			return template
	return {}


func daily_target(entry: Dictionary) -> int:
	return GoalsData.target_for(daily_template(entry.id), int(profile["level"]))


func daily_progress(kind: String, amount: int) -> void:
	if not has_profile:
		return
	if kind == "zone_kills" and (current_zone == &"town" or current_zone == &"arena"):
		return
	for entry in daily().quests:
		var template := daily_template(entry.id)
		if template.get("kind", "") != kind or entry.claimed:
			continue
		var target := daily_target(entry)
		if int(entry.progress) < target:
			entry["progress"] = mini(int(entry.progress) + amount, target)
			if int(entry.progress) >= target:
				say("เควสต์รายวัน \"%s\" เสร็จแล้ว! รับรางวัลที่กระดานในหมู่บ้าน" % template.name, &"quest")


## Consecutive days the daily board was claimed (bonus grows up to 7 days).
func daily_streak() -> int:
	var last := String(profile["flags"].get("daily_last", ""))
	var streak := int(profile["flags"].get("daily_streak", 0))
	if last == GoalsData.today() or last == GoalsData.yesterday():
		return streak
	return 0


## Claims every finished daily quest; returns how many were paid out. The first
## claim of a day extends the streak, and finishing all three adds a bonus chest.
func daily_claim_all() -> int:
	var count := 0
	var today := GoalsData.today()
	for entry in daily().quests:
		if entry.claimed or int(entry.progress) < daily_target(entry):
			continue
		if String(profile["flags"].get("daily_last", "")) != today:
			profile["flags"]["daily_streak"] = daily_streak() + 1
			profile["flags"]["daily_last"] = today
		var bonus := 1.0 + 0.1 * minf(float(daily_streak()) - 1.0, 6.0)
		entry["claimed"] = true
		var reward := GoalsData.reward_for(int(profile["level"]))
		add_exp(int(reward.exp * bonus))
		party_add_exp(int(reward.exp * bonus))
		add_gold(int(reward.gold * bonus))
		profile["flags"]["dailies"] = int(profile["flags"].get("dailies", 0)) + 1
		count += 1
	if count > 0:
		var all_done := true
		for entry in daily().quests:
			all_done = all_done and bool(entry.claimed)
		if all_done and not bool(daily().get("chest", false)):
			daily()["chest"] = true
			_daily_chest()
		flag_max("best_streak", daily_streak())
		check_achievements()
		mark_dirty()
	return count


## Bonus for completing the whole daily board: rare gear plus gems.
func _daily_chest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var level := int(profile["level"])
	var item := ItemData.generate(level, class_id(), rng, maxi(2, ItemData.roll_rarity(rng, 0.25)))
	add_item(item)
	add_item(ItemData.gem(["ruby", "sapphire", "emerald", "topaz", "amethyst"][rng.randi() % 5], 0 if level < 30 else 1))
	say("หีบรางวัลรายวัน: ได้ %s และอัญมณี" % ItemData.name_of(item), &"success")


## Current value of an achievement's counter.
func achievement_value(key: String) -> int:
	match key:
		"kills": return int(profile["kills"])
		"level": return int(profile["level"])
		"job": return 1 if adv() >= 1 else 0
		"job3": return 1 if adv() >= 2 else 0
		"job5": return 1 if adv() >= 4 else 0
		"bosses":
			var n := 0
			for id in profile["boss_kills"]:
				n += int(profile["boss_kills"][id])
			return n
		"boss_types": return (profile["boss_kills"] as Dictionary).size()
		"gold": return int(profile["gold"])
		_: return int(profile["flags"].get(key, 0))


func check_achievements() -> void:
	if not has_profile:
		return
	if not profile.get("ach") is Dictionary:
		profile["ach"] = {}
	for ach in GoalsData.ACHIEVEMENTS:
		if profile["ach"].has(ach.id) or achievement_value(ach.check) < int(ach.goal):
			continue
		profile["ach"][ach.id] = true
		var reward: Dictionary = ach.reward
		if reward.has("gold"):
			add_gold(int(reward.gold))
		if reward.has("sp"):
			profile["skill_points"] += int(reward.sp)
		if reward.has("gem"):
			add_item(ItemData.gem(String(reward.gem[0]), int(reward.gem[1]) - 1, 1))
		profile_changed.emit()
		achievement_unlocked.emit(String(ach.name))
		say("ความสำเร็จ: %s — รับรางวัลแล้ว" % ach.name, &"success")
		mark_dirty()


# ---------------------------------------------------------------------------
# Ranked duels (PvP against AI players)
# ---------------------------------------------------------------------------

func pvp() -> Dictionary:
	if not profile.get("pvp") is Dictionary:
		profile["pvp"] = {}
	var p: Dictionary = profile["pvp"]
	for key in ["rp", "wins", "losses", "streak", "best_streak", "peak_rp"]:
		p[key] = int(p.get(key, 0))
	return p


func pvp_rp() -> int:
	return int(pvp().rp)


## Applies the result of a duel: rank points, gold, EXP and a reward for
## reaching a new league. Returns everything the result screen shows.
func pvp_finish(won: bool, timeout: bool, info: Dictionary, opponent: String) -> Dictionary:
	var p := pvp()
	var before := int(p.rp)
	var streak := int(p.streak)
	var delta := PvpData.rp_change(won, timeout, streak)
	var after := maxi(PvpData.tier_floor(before), before + delta) if delta < 0 else before + delta
	after = clampi(after, 0, 99999)
	p["rp"] = after
	p["peak_rp"] = maxi(int(p.peak_rp), after)
	if won:
		p["wins"] = int(p.wins) + 1
		p["streak"] = streak + 1
		p["best_streak"] = maxi(int(p.best_streak), int(p.streak))
		flag_add("pvp_wins")
	else:
		p["losses"] = int(p.losses) + 1
		p["streak"] = 0
	flag_max("pvp_best_step", PvpData.step(after))
	var level := int(profile.level)
	var gold := PvpData.gold_reward(level, before, won)
	var exp_gain := PvpData.exp_reward(level, before, won)
	var promoted: bool = int(PvpData.place(PvpData.step(after)).tier) > int(PvpData.place(PvpData.step(before)).tier)
	var item_name := ""
	if promoted:
		var tier := int(PvpData.place(PvpData.step(after)).tier)
		gold += level * 300 * tier
		var gear := ItemData.generate(level, class_id(), rng, clampi(1 + tier / 2, 1, 4))
		if add_item(gear):
			item_name = ItemData.name_of(gear)
	add_gold(gold)
	add_exp(exp_gain)
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	check_achievements()
	mark_dirty()
	save()
	return {
		"won": won, "timeout": timeout, "opponent": opponent, "opponent_level": int(info.member.level),
		"opponent_class": String(info.member["class"]), "rp_before": before, "rp_after": after, "delta": after - before,
		"gold": gold, "exp": exp_gain, "promoted": promoted, "item": item_name, "streak": int(p.streak),
	}


func flag_add(key: String, amount := 1) -> void:
	profile["flags"][key] = int(profile["flags"].get(key, 0)) + amount


func flag_max(key: String, value: int) -> void:
	profile["flags"][key] = maxi(int(profile["flags"].get(key, 0)), value)
