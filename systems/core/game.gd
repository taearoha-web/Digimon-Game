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
signal guild_changed()
## A line of the world chat (WorldPresence): who says it, what, the name's colour.
signal world_chat(speaker: String, text: String, color: Color)
## A line of the party or guild chat (AiChat, PartyTalk): "party" or "guild", who says it,
## what, the name's colour. Only the hero's party / guild sees it; the world chat stays
## on world_chat. post_chat sends a line to either by its channel.
signal channel_chat(channel: String, speaker: String, text: String, color: Color)
## A world boss fell with the hero's help (Zone emits it; Achievements counts it).
signal world_boss_defeated(zone: StringName)
## A titled achievement (Achievements.TABLE id) was earned just now; the HUD may show a banner.
signal achievement_earned(id: String)
## The title above the hero's head changed ("" when taken off).
signal title_changed(title: String)

## The original single save file; it becomes slot 1 the first time slots are used.
const LEGACY_SAVE_PATH := "user://toon_tale_save.json"
const SLOT_COUNT := 10
const META_PATH := "user://toon_tale_meta.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 10.0
## The web audio mixer silent this long while the page is shown: iOS is often about to
## close it (a v0.9.4 report: 28 s without a mix, then gone). The game saves at once,
## once per silence, and marks it in the session report.
const AUDIO_STALL_SAVE_SECONDS := 5.0
## An iPhone closes the page after 20-35 minutes of play however light the game runs
## (five v0.9.4 reports: memory, video memory and the frame rate all steady, then gone).
## After IOS_REST_SECONDS the game saves and suggests closing and reopening it, once a
## session, at a moment with no screen open; a fresh page starts the count again.
const IOS_REST_SECONDS := 20 * 60
## After the first, the prompt comes back this often while the game stays open.
const IOS_REST_AGAIN := 5 * 60
var _rest_shown := false
var _rest_next := 0.0
## Above the HUD (10) and the travel fade (90).
const REST_PROMPT_LAYER := 100
var _audio_stall_saved := false
var stall_saves := 0
const BASE_BAG := 40
const MAX_BAG := 100
const BAG_STEP := 10
const STORAGE_SIZE := 80
const STAT_POINTS_PER_LEVEL := 3
const MAX_LEVEL := 100
const MAX_SKILL_RANK := 5
const MAX_SAVE_BYTES := 1048576
const MAX_SAVE_NUMBER := 1000000000000
const ENDING_ZONE := &"eclipse_realm"
## Separate from the legacy magma ending, so old saves can earn the real finale.
const ENDING_FLAG := "eclipse_ending_seen"
## Area skills (burst / blast) grow this much wider per extra star.
const RADIUS_PER_STAR := SkillRank.RADIUS_PER_STAR

var profile: Dictionary = {}
var has_profile := false
var current_zone: StringName = &"town"
var rng := RandomNumberGenerator.new()
var _autosave_timer := 0.0
var _dirty := false
## The browser owns authentication and async uploads. The game only sends
## committed local snapshots and pauses while its account dialog is visible.
const CLOUD_STATUS_INTERVAL := 0.2
var _cloud_status_timer := 0.0
var _cloud_modal_paused := false
var _cloud_previous_pause := false
var _web_next_sample_msec := 0
var last_save_work_ms := 0.0
var peak_save_work_ms := 0.0


func _ready() -> void:
	ZoneData.ensure()
	rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_migrate_legacy_save()
	SaveBackup.maybe_daily()
	world_chat.connect(_on_world_chat)
	channel_chat.connect(func(_channel: String, speaker: String, text: String, color: Color): _on_world_chat(speaker, text, color))
	world_boss_defeated.connect(_on_world_boss_defeated)
	(func(): UIUtil.install_discard_holder(get_tree().root)).call_deferred()


func _process(delta: float) -> void:
	MemoryGuard.tick(get_tree(), delta)
	if OS.has_feature("web"):
		RenderWatchdog.tick(get_tree(), delta, _render_watch_ok())
	if OS.has_feature("web"):
		_cloud_status_timer += delta
		if _cloud_status_timer >= CLOUD_STATUS_INTERVAL:
			_cloud_status_timer = fmod(_cloud_status_timer, CLOUD_STATUS_INTERVAL)
			_poll_cloud_modal()
		if Time.get_ticks_msec() >= _web_next_sample_msec:
			_web_next_sample_msec = Time.get_ticks_msec() + 5000
			_record_web_session_sample()
	if _cloud_modal_paused:
		return
	if not has_profile:
		return
	if OS.has_feature("web"):
		_watch_audio_stall()
		_watch_ios_rest()
	profile["play_time"] = float(profile.get("play_time", 0.0)) + delta
	_ach_timer += delta
	if _ach_timer >= ACH_INTERVAL:
		_check_achievements()
	_gq_timer += delta
	if _gq_timer >= GQ_CHECK_INTERVAL:
		_gq_timer = 0.0
		if guild() > 0:
			_guild_quest_announce()
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
		if OS.has_feature("web"):
			_poll_cloud_modal()


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
		"flags": {}, "boss_kills": {}, "boss_pity": {}, "pvp": {}, "paragon": {}, "tower": {}, "storage": [], "bag_slots": BASE_BAG, "adv": 0,
		# The party is made of world players who join for a session (party_invite), not saved.
		"party": [],
	}
	WorldPlayers.resume_all(WorldPresence.clock())
	world_party.clear()
	_party_members.clear()
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
	profile["loadout"] = ClassData.default_loadout(class_id(), int(profile.get("level", 1)), profile.get("loadout", []), class_tier(), int(paragon().level))


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
	var out := HeroStats.compute(profile, buffs)
	# A running Halloween potion also lifts the attack (BOOST_ATK).
	if has_profile and exp_boost_left() > 0.0:
		out["atk"] = float(out["atk"]) * (1.0 + BOOST_ATK)
	return out


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
	WorldPlayers.resume_all(WorldPresence.clock())
	world_party.clear()
	_party_members.clear()
	current_zone = StringName(profile.zone)
	_dirty = false
	_autosave_timer = 0.0
	_party_gear.clear()
	_remember_slot()
	_queue_cloud_save()
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


## Which of the save slots (1..SLOT_COUNT) the current profile belongs to.
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


## The first empty slot, or 0 when every slot is taken.
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
	return _slot_summary(raw)


## slot_info plus the look and worn gear (slot_profile_preview) from one read of the
## file: the character select shows all ten slots at once.
func slot_overview(for_slot: int) -> Dictionary:
	var raw := _read_slot(for_slot)
	if raw.is_empty():
		return {}
	var out := _slot_summary(raw)
	var repaired := _repair(raw)
	out["look"] = repaired.get("look", {})
	out["equip"] = repaired.equip
	return out


func _slot_summary(raw: Dictionary) -> Dictionary:
	return {
		"class": String(raw.get("class", "warrior")), "name": String(raw.get("name", "?")),
		"level": int(raw.get("level", 1)), "adv": int(raw.get("adv", 0)), "zone": String(raw.get("zone", "town")),
		"play_time": float(raw.get("play_time", 0.0)), "saved_at": int(raw.get("saved_at", 0)),
		"rank": int(raw.get("pvp", {}).get("rp", 0)) if raw.get("pvp", {}) is Dictionary else 0,
		"stars": int(raw.get("paragon", {}).get("level", 0)) if raw.get("paragon", {}) is Dictionary else 0,
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
	_check_achievements()
	var work_started := Time.get_ticks_usec()
	# Keep the last successful metadata and the dirty state until commit succeeds.
	var snapshot := profile.duplicate(true)
	snapshot["zone"] = String(current_zone)
	snapshot["resume"] = playing
	snapshot["saved_at"] = int(Time.get_unix_time_from_system())
	if not _write_profile(snapshot, slot):
		_dirty = true
		_note_save_work(work_started)
		return false
	profile["zone"] = snapshot.zone
	profile["resume"] = snapshot.resume
	profile["saved_at"] = snapshot.saved_at
	_remember_slot()
	_autosave_timer = 0.0
	_dirty = false
	_queue_cloud_save()
	# The world players' party EXP is kept with the world, beside the slots.
	WorldPlayers.store()
	_note_save_work(work_started)
	SaveBackup.maybe_daily()
	return true


func _note_save_work(started: int) -> void:
	last_save_work_ms=float(Time.get_ticks_usec()-started)/1000.0
	peak_save_work_ms=maxf(peak_save_work_ms,last_save_work_ms)


## Same-directory rename keeps the previous save intact if writing fails.
func _write_profile(snapshot: Dictionary, destination: int) -> bool:
	if destination < 1 or destination > SLOT_COUNT:
		return false
	var path := save_path(destination)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	var text := JSON.stringify(snapshot)
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	var dir := DirAccess.open("user://")
	if dir == null or dir.rename(path.get_file() + ".tmp", path.get_file()) != OK:
		return false
	_slot_json[destination] = {"stamp": _slot_stamp(destination), "text": text}
	return true


## Loads a slot (default: the current one) and makes it the active one.
func load_game(from_slot := -1) -> bool:
	var target := slot if from_slot < 1 else from_slot
	var raw := _read_slot(target)
	if raw.is_empty():
		return false
	slot = target
	profile = _repair(raw)
	has_profile = true
	WorldPlayers.resume_all(WorldPresence.clock())
	world_party.clear()
	_party_members.clear()
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
	if target < 1 or target > SLOT_COUNT:
		return
	var existed := has_save(target)
	if existed and DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path(target))) != OK:
		return
	_slot_json.erase(target)
	if target == slot:
		has_profile = false
		profile = {}
	if existed:
		_queue_cloud_save()


## Read every committed slot, without repairing or mutating its saved data.
## Empty / invalid slots stay absent, so deleting a slot reaches the cloud too.
func build_cloud_bundle() -> Dictionary:
	var slots: Dictionary = {}
	for i in range(1, SLOT_COUNT + 1):
		var saved := _read_slot(i)
		if not saved.is_empty():
			slots[String.num_int64(i)] = saved
	return {"slots": slots, "selectedSlot": clampi(slot, 1, SLOT_COUNT)}


## JSON-encode the already serialized bundle as one JavaScript string value.
## Player names and imported strings must never become executable source.
func _cloud_save_script(serialized_bundle: String) -> String:
	var argument := JSON.stringify(serialized_bundle).replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
	return "if (typeof window.toonCloudSave === 'function') { window.toonCloudSave(%s); }" % argument


func _queue_cloud_save() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(_cloud_save_script(cloud_bundle_json()), true)


## The JSON text of every saved slot, kept from the last read or write with the file's
## stamp (modified time and size): the autosave (every 10 s while playing) used to read,
## parse and encode all ten slot files again for each upload, a hitch of a frame or two
## on a phone. A slot file changed by anything else is read again.
var _slot_json: Dictionary = {}


func _slot_stamp(for_slot: int) -> String:
	var path := save_path(for_slot)
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	var size := file.get_length() if file != null else -1
	return "%d:%d" % [FileAccess.get_modified_time(path), size]


## build_cloud_bundle() as JSON, from the cached slot texts (the same bytes the server
## gets either way: JSON.stringify of each slot's validated data).
func cloud_bundle_json() -> String:
	var parts: PackedStringArray = []
	for i in range(1, SLOT_COUNT + 1):
		var stamp := _slot_stamp(i)
		var kept: Variant = _slot_json.get(i)
		if stamp == "":
			_slot_json.erase(i)
			continue
		if kept == null or String(kept.stamp) != stamp:
			var saved := _read_slot(i)
			kept = {"stamp": stamp, "text": JSON.stringify(saved) if not saved.is_empty() else ""}
			_slot_json[i] = kept
		if String(kept.text) != "":
			parts.append("\"%d\":%s" % [i, String(kept.text)])
	return "{\"slots\":{%s},\"selectedSlot\":%d}" % [",".join(parts), clampi(slot, 1, SLOT_COUNT)]


func open_cloud_account() -> void:
	if not OS.has_feature("web"):
		return
	# Commit before opening the panel; account switching itself is handled by
	# the browser, which suppresses old-session uploads before replacing saves.
	if not _save_before_cloud_account():
		return
	JavaScriptBridge.eval("if (typeof window.toonOpenAccountPanel === 'function') { window.toonOpenAccountPanel(); }", true)
	_poll_cloud_modal()


func _save_before_cloud_account() -> bool:
	if has_profile and not save():
		say("บันทึกไม่สำเร็จ กรุณาสำรองรหัสเซฟก่อนเปลี่ยนบัญชี", &"warning")
		return false
	return true


func _poll_cloud_modal() -> void:
	var raw: Variant = JavaScriptBridge.eval("typeof window.toonRuntimePauseMask === 'function' ? window.toonRuntimePauseMask() : (typeof window.toonCloudStatus === 'function' ? window.toonCloudStatus() : null)", true)
	if raw is float or raw is int:
		_apply_web_pause_mask(int(raw))
		return
	if not raw is String:
		return
	var status: Variant = JSON.parse_string(raw)
	if status is Dictionary and status.get("modalOpen") is bool:
		_set_cloud_modal_open(status.modalOpen)


func _apply_web_pause_mask(mask: int) -> void:
	AudioManager.set_backgrounded((mask & 1) != 0)
	_set_cloud_modal_open(mask != 0)


## The flat-screen watchdog only reads a frame of play: a zone, the HUD up, no menu,
## dialog or travel fade over the world.
func _render_watch_ok() -> bool:
	var main := get_tree().current_scene
	if main == null or not main.has_method("_screen_open") or main.get("zone") == null:
		return false
	var hud: Variant = main.get("hud")
	return hud is CanvasItem and (hud as CanvasItem).visible and not bool(main.call("_screen_open"))


func _record_web_session_sample() -> void:
	var hero := get_tree().get_first_node_in_group("hero")
	var sample := {"staticBytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"videoBytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"fps": Engine.get_frames_per_second(), "quality": GameSettings.quality,
		"pressure": MemoryGuard.pressure, "pressureRaises": MemoryGuard.raises, "heapMB": MemoryGuard.heap_mb,
		"scale3d": MemoryGuard.scale_3d, "emitters": get_tree().root.find_children("*", "CPUParticles3D", true, false).size(),
		"renderFallback": RenderWatchdog.step, "flatScreens": RenderWatchdog.flat_count,
		"starvedFrames": RenderWatchdog.starved_count, "pixelReads": RenderWatchdog.pixel_reads,
		"vfx": VfxBudget.report(), "materialsHeld": MaterialKeeper.held(),
		"drawCalls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"triangles": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"renderObjects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"processMs": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physicsMs": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"soundPlayRequests": AudioManager.sound_play_requests,
		"saveWorkMs": last_save_work_ms, "savePeakMs": peak_save_work_ms,
		"audioStreamMode": AudioManager.uses_stream_playback(), "audioStallSeconds": minf(AudioServer.get_time_since_last_mix(), 3600.0),
		"zone": String(current_zone), "class": String(class_id()),
		"audioState": str(JavaScriptBridge.eval("window.toonAudioState ? window.toonAudioState() : 'none'", true)),
		"loot": get_tree().get_nodes_in_group("loot").size(),
		"auto": hero is Hero and hero.auto, "kills": int(profile.get("kills", 0)),
		"saveAgeSeconds": maxi(0, int(Time.get_unix_time_from_system()) - int(profile.get("saved_at", Time.get_unix_time_from_system())))}
	for key in ["particles", "decorations", "lights"]:
		if sample.vfx is Dictionary and sample.vfx.has(key):
			sample[key] = sample.vfx[key]
	sample.merge(RenderWatchdog.camera_report(get_tree()))
	# What the game was doing (a report ended with the world standing still for a minute).
	var main := get_tree().current_scene
	sample["paused"] = get_tree().paused
	sample["screenOpen"] = main != null and main.has_method("_screen_open") and bool(main.call("_screen_open"))
	sample["heroDead"] = hero is Hero and (hero as Hero).is_dead()
	sample["hot"] = MemoryGuard.hot
	sample["hotSeconds"] = snappedf(MemoryGuard.hot_seconds, 1.0)
	sample["stallSaves"] = stall_saves
	if hero is Hero:
		sample["lastSkill"]=hero.last_cast_id
		if hero.field is Zone and hero.field.tower_run:
			var run:TowerRun=hero.field.tower_run
			sample.merge({"towerFloor":run.floor_no,"towerState":run.state,"pendingSpawns":run._pending.size(),"spawnWorkMs":run.last_spawn_ms,"spawnPeakMs":run.peak_spawn_ms})
	JavaScriptBridge.eval("if (window.toonSession) window.toonSession.sample(%s);" % JSON.stringify(JSON.stringify(sample)), true)


func _watch_ios_rest() -> void:
	var up := Time.get_ticks_msec() / 1000.0
	if up < float(IOS_REST_SECONDS) or up < _rest_next or not MemoryGuard.ios():
		return
	if current_zone == &"guildwar":
		return  # never in the middle of a war
	var main := get_tree().current_scene
	if main == null or not main.has_method("_screen_open") or main.get("zone") == null or bool(main.call("_screen_open")):
		return
	if main.has_node("RestPromptLayer"):
		return  # the last one is still up
	_rest_shown = true
	_rest_next = up + float(IOS_REST_AGAIN)
	save()
	# On its own layer above the HUD (a CanvasLayer at 10): under it the HUD took the taps
	# and the button could not be pressed.
	var layer := CanvasLayer.new()
	layer.name = "RestPromptLayer"
	layer.layer = REST_PROMPT_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(layer)
	await ModalDialog.info(layer, "พักเครื่องสักครู่", "เล่นต่อเนื่องมา %d นาทีแล้ว iPhone มักปิดเกมเองเมื่อเปิดนานเกินครึ่งชั่วโมง\n\nบันทึกเซฟให้แล้ว แนะนำปัดปิดแอปแล้วเปิดใหม่ เกมจะกลับมาเล่นต่อได้ทันทีและไม่หลุดกลางทาง" % int(up / 60.0), "เข้าใจแล้ว")
	if is_instance_valid(layer):
		layer.queue_free()


func _watch_audio_stall() -> void:
	var stalled := AudioServer.get_time_since_last_mix() > AUDIO_STALL_SAVE_SECONDS
	if stalled == _audio_stall_saved:
		return
	_audio_stall_saved = stalled
	if stalled and str(JavaScriptBridge.eval("document.visibilityState", true)) == "hidden":
		return  # a hidden page stops mixing on purpose; leaving it already saved
	JavaScriptBridge.eval("if (window.toonSession && window.toonSession.mark) window.toonSession.mark('%s');" % ("audio_stall" if stalled else "audio_back"), true)
	if stalled:
		stall_saves += 1
		save()


func _set_cloud_modal_open(open: bool) -> void:
	if open == _cloud_modal_paused:
		return
	if open:
		_cloud_previous_pause = get_tree().paused
		get_tree().paused = true
	else:
		get_tree().paused = _cloud_previous_pause
	_cloud_modal_paused = open


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
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills", "boss_pity", "pvp", "tower", "paragon", "ach", "look", "daily"]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	for key in ["inv", "storage", "loadout", "party"]:
		if data.has(key) and not data[key] is Array:
			return false
	for key in ["attrs", "skills", "boss_kills", "boss_pity", "pvp", "tower", "look"]:
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
	if data.has("gw_last"):
		var last: Variant = data.gw_last
		if not last is Dictionary or not last.get("rows", []) is Array or (last.get("rows", []) as Array).size() > 200:
			return false
		for key in ["our_guild", "their_guild"]:
			if not last.get(key, "") is String:
				return false
		for key in ["score_us", "score_them", "at"]:
			if not _valid_integer(last.get(key, 0)):
				return false
		for r in last.get("rows", []):
			if not r is Dictionary or not r.get("name", "") is String or not r.get("class", "") is String:
				return false
			for key in ["team", "kills", "deaths"]:
				if not _valid_integer(r.get(key, 0)):
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
		if not _valid_integer(member.get("stars", 0), 0, PARAGON_MAX) or not _valid_integer(member.get("star_exp", 0)):
			return false
		if member.get("stance", "follow") not in STANCES or member.get("trait", "brave") not in TRAIT_NAMES:
			return false
		for key in ["potions", "mp_potions", "hp", "mp"]:
			if not _valid_integer(member.get(key, 0)):
				return false
		if not member.get("look", {}) is Dictionary:
			return false
		for value in member.get("look", {}).values():
			if not _valid_integer(value):
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
	return bits.size() == 2 and ItemData.GEMS.has(bits[0]) and bits[1] in ["0", "1", "2", "3", "4"]


func _valid_item(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var item: Dictionary = value
	if item.get("kind") in ["potion", "gem", "jewel"]:
		# Stack items never contain equipment fields. Refuse ambiguous data before
		# item repair or UI code can accidentally interpret those nested values.
		for key in ["stats", "gems", "level", "rarity", "price", "plus", "sockets"]:
			if item.has(key):
				return false
		if item.kind == "jewel":
			return _valid_integer(item.get("count", 1), 1) and ItemData.JEWELS.has(item.get("id"))
		return _valid_integer(item.get("count", 1), 1) and (ItemData.POTIONS.has(item.get("id")) if item.kind == "potion" else _valid_gem_id(item.get("id")))
	if item.get("kind") != "equip" or not ItemData.EQUIP_SLOTS.has(item.get("slot")):
		return false
	for key in ["uid", "name", "class", "set", "base", "boss"]:
		if not item.get(key, "") is String:
			return false
	if item.has("star_tier"):
		if not _valid_integer(item.star_tier, 50, 200) or not StarProgression.TIERS.has(int(item.star_tier)) or not ClassData.IDS.has(StringName(item.get("star_class", ""))): return false
	if item.has("collection"):
		if not DivineGearData.is_item(item) or not DivineGearData.SLOTS.has(item.slot): return false
		if item.get("star_tier") != 200 or item.get("level") != 300 or item.get("class") != item.get("star_class"): return false
		if item.get("set") != DivineGearData.set_id(String(item.get("class", ""))): return false
	if not item.get("stats", {}) is Dictionary or not item.get("gems", []) is Array:
		return false
	if item.get("base", "") != "wings" and not ItemData.NAMES.has(item.get("base")):
		return false
	if item.get("slot") == "wings" and not (ItemData.WING_INFO.has(item.get("wing")) or ItemData.LEGACY_WING_KINDS.has(item.get("wing"))):
		return false
	if item.get("class", "") != "" and not ClassData.CLASSES.has(StringName(item["class"])):
		return false
	if not _valid_integer(item.get("level"), 1) or not _valid_integer(item.get("rarity", 0), 0, 4):
		return false
	if not _valid_integer(item.get("plus", 0), 0, ItemData.MAX_PLUS) or not _valid_integer(item.get("sockets", 0), 0, ItemData.MAX_SOCKETS + 1) or not _valid_integer(item.get("price", 0)):
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
	data["zone"] = String(zone) if ZoneData.ZONES.has(zone) and zone not in [&"pvp", &"tower", &"guildwar"] else "town"
	if data.get("look") is Dictionary:
		data["look"] = FaceKit.repair(data["look"])
	for key in ["attrs", "skills", "equip", "quests", "flags", "boss_kills", "boss_pity", "pvp"]:
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
	for key in data["boss_pity"]:
		data["boss_pity"][key] = maxi(0, int(data["boss_pity"][key]))
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
	StarWingData.migrate_profile(data)
	# Recover overflow stranded by saves from before the Lv.100 handoff fix.
	if int(data.level) == MAX_LEVEL and int(data.exp) > 0:
		var para: Dictionary = data.paragon
		para["level"] = int(para.get("level", 0))
		para["exp"] = int(para.get("exp", 0)) + int(data.exp)
		para["points"] = int(para.get("points", 0))
		while int(para.level) < PARAGON_MAX:
			var need := HeroStats.star_need(int(para.level))
			if int(para.exp) < need:
				break
			para["exp"] = int(para.exp) - need
			para["level"] = int(para.level) + 1
			para["points"] = int(para.points) + 1
		if int(para.level) == PARAGON_MAX:
			para["exp"] = 0
		data["exp"] = 0
	# Milestone skill points used to be claimed in the retired Star Path menu.
	StarProgression.grant_milestones(data)
	# The hired AI companion retired: the party is made of world players now (party_invite).
	if data.has("party"):
		data["party"] = []
	for entry in data.get("daily", {}).get("quests", []):
		entry["progress"] = int(entry.get("progress", 0))
		entry["claimed"] = bool(entry.get("claimed", false))
	var stats := HeroStats.compute(data)
	data["hp"] = clampi(int(data.hp), 0, int(stats.max_hp)) if has_hp else int(stats.max_hp)
	data["mp"] = clampi(int(data.mp), 0, int(stats.max_mp)) if has_mp else int(stats.max_mp)
	return data


## Saves from before the Priston Tale skill system: refund the skill points
## spent on the old skills and start with a fresh bar.
## Skills that changed id: the rank and the bar slot carry over.
const RENAMED_SKILLS := {"wind_drake": "fairy_spirit"}


func _migrate_skills(data: Dictionary) -> void:
	var cls := StringName(data.get("class", "warrior"))
	for old in RENAMED_SKILLS:
		var now: String = RENAMED_SKILLS[old]
		if data.skills.has(old):
			if not data.skills.has(now):
				data.skills[now] = data.skills[old]
			data.skills.erase(old)
		if data.get("loadout") is Array:
			for i in (data["loadout"] as Array).size():
				if data["loadout"][i] == old:
					data["loadout"][i] = now
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
	data["loadout"] = ClassData.default_loadout(cls, int(data["level"]), data["loadout"], ClassData.tier_of(cls, int(data.get("adv", 0))), int(data.get("paragon", {}).get("level", 0)))


## Weapon kinds of the spell casters (converted between when a class's kind changes).
const CASTER_WEAPONS := ["staff", "wand", "lantern"]


func _repair_item(item: Dictionary) -> void:
	# A class's weapon kind can change (priest staff -> wand, summoner staff ->
	# lantern): spell-caster weapons become the class's kind at the same tier,
	# renamed from the old kind's name list (the priest's first wands included).
	var base := String(item.get("base", ""))
	if item.get("slot", "") == "weapon" and base in CASTER_WEAPONS and ClassData.CLASSES.has(StringName(item.get("class", ""))):
		var want := String(ClassData.get_class_data(StringName(item["class"])).weapon_kind)
		if want in CASTER_WEAPONS:
			var named := String(item.get("name", ""))
			var lists: Array = [ItemData.LEGACY_WAND_NAMES] if base == "wand" else []
			if base != want:
				lists.push_front(ItemData.NAMES[base])
			for names in lists:
				for tier in names.size():
					var old := String(names[tier])
					if named == old or named.begins_with(old + " "):
						item["name"] = String(ItemData.NAMES[want][tier]) + named.substr(old.length())
						break
				if String(item.get("name", "")) != named:
					break
			item["base"] = want
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
	# The evening EXP x2 event (WorldEvents) doubles every EXP the hero earns; a
	# Halloween potion multiplies on top of it.
	amount = int(round(float(amount) * WorldEvents.exp_multiplier(WorldPresence.clock()) * exp_boost_mult()))
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
		save()
	mark_dirty()


# ---------------------------------------------------------------------------
# Party: online world players (WorldPlayers) who join the hero for a while
# ---------------------------------------------------------------------------

## The chibi body of a companion sheet without a look of its own (0 boy, 1 girl).
func party_gender(member: Dictionary) -> int:
	return int(member.get("gender", 0))


## Colours a companion sheet may carry: hair, eye and skin colour from the chibi palette.
const PARTY_LOOK_KEYS := ["hair_tint", "eye_tint", "skin_tone"]


## What a companion sheet's chibi wears: the body and its colours.
func party_look(member: Dictionary) -> Dictionary:
	var look := {"gender": party_gender(member)}
	var rolled: Variant = member.get("look", {})
	if rolled is Dictionary:
		for key in PARTY_LOOK_KEYS:
			look[key] = clampi(int(rolled.get(key, 0)), 0, ChibiLook.count(key) - 1)
	return look


var _party_gear: Dictionary = {}

## A party is at most three people: the hero and two world players.
const PARTY_SIZE := 5
const PARTY_MAX := PARTY_SIZE - 1
## A world player says yes to a stranger within this many levels (guild mates always do).
const PARTY_LEVEL_GAP := 20


## Whether two levels may party up as strangers: within PARTY_LEVEL_GAP, and at the
## star tier (both Lv.100, whatever their stars) always.
static func party_levels_ok(a: int, b: int) -> bool:
	return (a >= MAX_LEVEL and b >= MAX_LEVEL) or absi(a - b) <= PARTY_LEVEL_GAP
## Kill EXP in a party is shared: the pot grows by this much per member and is split
## evenly between everyone in the party.
const PARTY_EXP_BONUS := 0.3
const STANCES := ["follow", "aggressive", "guard"]
const STANCE_NAMES := {"follow": "ตามติด", "aggressive": "บุกลุย", "guard": "ป้องกัน"}
const TRAIT_NAMES := {"brave": "กล้าหาญ", "careful": "ระมัดระวัง"}

## The party, like in an online game, lasts a session: who joined, in order (world player
## indices). It is not saved; a member leaves when its own session ends (party_refresh)
## or when the hero changes character.
var world_party: Array[int] = []
var _party_members := {}


## The members as companion sheets (class, name, level, stars, stance, potions...).
func party() -> Array:
	var out := []
	for i in world_party:
		out.append(_party_members[i])
	return out


func in_party(i: int) -> bool:
	return world_party.has(i)


## Asks world player i to join. Returns "" when it joins, otherwise why not (offline,
## party full, too far apart in level for a stranger). `force` skips the asking (tests).
func party_invite(i: int, force := false) -> String:
	if not has_profile or i < 0 or i >= WorldPlayers.size():
		return "ไม่พบผู้เล่น"
	if world_party.has(i):
		return "อยู่ในปาร์ตี้แล้ว"
	if world_party.size() >= PARTY_MAX:
		return "ปาร์ตี้เต็มแล้ว (ปาร์ตี้ละ %d คนรวมคุณ)" % PARTY_SIZE
	var t := WorldPresence.clock()
	var s := WorldPlayers.state(i, t)
	if not force:
		if not bool(s.online):
			return "%s ออฟไลน์อยู่" % s.name
		var mate := guild() > 0 and int(s.guild) == guild()
		if not mate and not party_levels_ok(int(s.level), int(profile.level)):
			return "%s: เลเวลห่างกันเกินไป ไว้คราวหน้านะ" % s.name
	var m := WorldPlayers.member(i, t)
	m["stance"] = "follow"
	_party_members[i] = m
	world_party.append(i)
	# In the party a member levels by the party's shared EXP only (WorldPlayers.add_exp),
	# not by its own schedule as well.
	WorldPlayers.pause_schedule(i, t)
	say("%s เข้าร่วมปาร์ตี้แล้ว!" % s.name, &"success")
	party_changed.emit()
	party_roster_changed.emit()
	return ""


## Member i leaves the party (`why` is said if given).
func party_kick(i: int, why := "") -> void:
	if not world_party.has(i):
		return
	world_party.erase(i)
	_party_members.erase(i)
	WorldPlayers.resume_schedule(i, WorldPresence.clock())
	if why != "":
		say(why, &"info")
	party_changed.emit()
	party_roster_changed.emit()


func dismiss_party() -> void:
	WorldPlayers.resume_all(WorldPresence.clock())
	world_party.clear()
	_party_members.clear()
	party_changed.emit()
	party_roster_changed.emit()


## Keeps the members' sheets in step with their schedules (levels up on screen) and lets
## go of those whose session has ended.
func party_refresh(t: float) -> void:
	for i in world_party.duplicate():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online):
			party_kick(i, "%s ออกจากเกม — ออกจากปาร์ตี้" % s.name)
			continue
		var m: Dictionary = _party_members[i]
		var up := int(s.level) > int(m.level) or int(s.stars) > int(m.get("stars", 0))
		WorldPlayers.sync_member(m, s)
		if up:
			party_leveled.emit(world_party.find(i), int(s.level))
	party_changed.emit()


## How much of a monster's EXP a character of `level` gets (less for monsters far below).
static func exp_gap_scale(level: int, mob_level: int) -> float:
	var gap := level - mob_level
	return 1.0 if gap <= 4 else maxf(0.15, 1.0 - 0.17 * float(gap - 4))


## A kill worth `base` EXP shared by the party: everyone gets an even part of the pot
## (PARTY_EXP_BONUS more per member), each scaled by its own level against the monster's.
## The members' parts go to them (WorldPlayers.add_exp); returns the hero's.
func share_party_exp(base: float, mob_level: int) -> int:
	var n := 1 + world_party.size()
	var each := base * (1.0 + PARTY_EXP_BONUS * float(n - 1)) / float(n)
	for i in world_party:
		var m: Dictionary = _party_members[i]
		# A member under its own Halloween potion (WorldPlayers.halloween_mult) earns its part x2 / x3.
		var potion := float(WorldPlayers.halloween_mult(i, WorldPresence.clock()))
		WorldPlayers.add_exp(i, each * potion * exp_gap_scale(int(m.level), mob_level), int(m.level), int(m.get("stars", 0)))
	return int(round(each * exp_gap_scale(int(profile.level), mob_level)))


## Tap a party card: follow -> aggressive -> guard for that member.
func cycle_stance(k := 0) -> String:
	var list := party()
	if k < 0 or k >= list.size():
		return ""
	var member: Dictionary = list[k]
	var i := STANCES.find(String(member.get("stance", "follow")))
	member["stance"] = STANCES[(i + 1) % STANCES.size()]
	party_changed.emit()
	return String(member.stance)


## The hero's typed order sets every member's stance at once (PartyTalk.command).
func set_party_stance(stance: String) -> void:
	if not STANCES.has(stance):
		return
	for m in party():
		m["stance"] = stance
	party_changed.emit()


## A fake profile so [HeroStats] can work out a companion's stats.
func party_profile(member: Dictionary) -> Dictionary:
	var stars := party_stars(member)
	return {"class": member["class"], "level": int(member.level), "attrs": {}, "equip": party_equip(member), "adv": JobData.adv_for_level(int(member.level)),
		"paragon": {"level": stars, "alloc": party_star_alloc(stars)}}


## A companion's ★ (0-200).
func party_stars(member: Dictionary) -> int:
	return clampi(int(member.get("stars", 0)), 0, PARAGON_MAX)


## The ★ points a companion spends by itself: half into attack, then health,
## defence and critical, up to each stat's cap.
func party_star_alloc(stars: int) -> Dictionary:
	var alloc := {}
	var spend := stars
	for key in ["atk", "hp", "def", "crit"]:
		var put := mini(spend / 2 if key == "atk" else spend, int(PARAGON_STATS[key][2]))
		alloc[key] = put
		spend -= put
	return alloc


## The star tier of gear a companion wears: none below 50 stars.
func party_gear_tier(member: Dictionary) -> int:
	var tier := 0
	for t in StarProgression.TIERS:
		if party_stars(member) >= t:
			tier = t
	return tier


## Gear that grows with the companion's level (same pieces until the next tier).
## Past Lv.100 it wears the star set that matches its stars.
func party_equip(member: Dictionary) -> Dictionary:
	var stars := party_stars(member)
	var gear_tier := party_gear_tier(member)
	var tier := ItemData.tier_for(int(member.level))
	var key := "%s|%d|%d|%d|%d" % [member.name, tier, int(member.level) / 3, gear_tier, 1 if stars > 0 else 0]
	if _party_gear.has(key):
		return _party_gear[key]
	var local := RandomNumberGenerator.new()
	local.seed = hash(key)
	var gear := {}
	for slot in ["weapon", "armor", "helm"]:
		if gear_tier > 0:
			gear[slot] = StarProgression.item(StringName(member["class"]), gear_tier, slot, local)
		elif stars > 0:
			gear[slot] = ItemData.generate(MAX_LEVEL + mini(stars, 20), StringName(member["class"]), local, 1, slot)
		else:
			gear[slot] = ItemData.generate(maxi(1, int(member.level)), StringName(member["class"]), local, 1, slot)
	# Wings once the companion reaches the wing level, like the hero: its class's
	# Lv.100 wings, then the star wings from 100 stars.
	if int(member.level) >= ItemData.WING_DROP_LEVEL:
		if stars >= StarWingData.REQUIRED_STARS:
			gear["wings"] = StarWingData.item(String(member["class"]), local, 3)
		else:
			gear["wings"] = ItemData.wings(local, String(member["class"]), 3)
	_party_gear[key] = gear
	return gear


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


## Kills of a field boss since its last chase piece (see BossLootData); the dictionary
## is the save's own, so changes persist with the next save.
func boss_pity() -> Dictionary:
	if not profile.get("boss_pity") is Dictionary:
		profile["boss_pity"] = {}
	mark_dirty()
	return profile["boss_pity"]


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
	var fresh := StarWingData.item(String(item.get("wing","warrior")),rng) if StarWingData.is_wing(item) else ItemData.wings(rng, String(item.get("wing", "warrior")))
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
		item = ItemData.gem(ItemData.STAT_GEMS[rng.randi() % ItemData.STAT_GEMS.size()], 2)
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
	return HeroStats.star_need(lv)


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
		fill_loadout()
		if StarProgression.grant_milestones(profile) > 0:
			say("ถึงดาว %d! ปลดล็อกสกิลดาวใหม่ (ดูที่เมนูสกิล) และได้แต้มสกิล +2" % int(p.level), &"success")
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
	return MAX_LEVEL + clampi(star, 1, 20)


## Spends up to `count` points on one stat (fewer when points or the stat cap run out).
func paragon_spend(key: String, count := 1) -> bool:
	var p := paragon()
	var info: Array = PARAGON_STATS.get(key, [])
	if info.is_empty() or count <= 0:
		return false
	var put := mini(count, mini(int(p.points), int(info[2]) - int(p.alloc[key])))
	if put <= 0:
		return false
	p["points"] = int(p.points) - put
	p["spent"] = int(p.spent) + put
	p["alloc"][key] = int(p.alloc[key]) + put
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


## Allocate the requested number atomically, retaining the one-point default.
func spend_point(attr: String, amount: int = 1) -> bool:
	if amount <= 0 or profile.is_empty() or attr not in ["str", "int", "dex", "vit"]:
		return false
	if amount > int(profile["points"]) or not profile["attrs"].has(attr):
		return false
	profile["points"] = int(profile["points"]) - amount
	profile["attrs"][attr] = int(profile["attrs"][attr]) + amount
	profile_changed.emit()
	mark_dirty()
	return true


func skill_rank(skill_id: String) -> int:
	return int(profile["skills"].get(skill_id, 0))


func skill_unlocked(skill: Dictionary) -> bool:
	return profile["level"] >= int(skill.level) and class_tier() >= ClassData.skill_tier(skill) and int(paragon().level) >= int(skill.get("star", 0))


## 0 Vagabond, 1 line (Lv.10), then 2..5 for the four advancements (Lv.20/40/60/80).
func class_tier() -> int:
	return ClassData.tier_of(class_id(), adv())


## Why a skill cannot be used yet ("" when it can).
func skill_lock_reason(skill: Dictionary) -> String:
	if skill.has("star") and int(paragon().level) < int(skill.star):
		return "ปลดล็อกที่เลเวล 100 ดาว %d" % int(skill.star)
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
	return SkillRank.radius_scale(rank)


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


## A reward into the bag, or into storage when the bag is full (stackables join a pile
## there too). Returns false only when both are full.
func give_or_store(item: Dictionary) -> bool:
	if add_item(item):
		return true
	var store: Array = profile.get("storage", [])
	if ItemData.is_stackable(item):
		for existing in store:
			if existing.get("kind", "") == item.get("kind", "") and existing.get("id") == item.id:
				existing["count"] = int(existing.get("count", 1)) + int(item.get("count", 1))
				mark_dirty()
				return true
	if store.size() < STORAGE_SIZE:
		store.append(item)
		profile["storage"] = store
		say("กระเป๋าเต็ม — %s ถูกส่งเข้าคลัง" % ItemData.name_of(item), &"warning")
		mark_dirty()
		return true
	say("กระเป๋าและคลังเต็ม — รับ %s ไม่ได้" % ItemData.name_of(item), &"warning")
	return false


## Jewels of `id` in the bag.
func jewel_count(id: String) -> int:
	var n := 0
	for item in profile["inv"]:
		if item.get("kind", "") == "jewel" and String(item.get("id", "")) == id:
			n += int(item.get("count", 1))
	return n


## Takes `count` jewels of `id` from the bag (the caller checked there are enough).
func _spend_jewels(id: String, count: int) -> void:
	var left := count
	for i in range(profile["inv"].size() - 1, -1, -1):
		var item: Dictionary = profile["inv"][i]
		if left <= 0:
			break
		if item.get("kind", "") != "jewel" or String(item.get("id", "")) != id:
			continue
		var take := mini(left, int(item.get("count", 1)))
		item["count"] = int(item.get("count", 1)) - take
		left -= take
		if int(item.count) <= 0:
			profile["inv"].remove_at(i)


## One forge attempt (+1) with jewels (ItemData.JEWELS). Returns "ok", "fail" (the
## jewels are used up, the piece keeps its grade) or a reason.
func enhance_item(item: Dictionary) -> String:
	if item.get("kind", "") != "equip":
		return "ไอเทมนี้ตีบวกไม่ได้"
	if not EnhanceFx.can_enhance(item):
		return "แหวนกับสร้อยตีบวกไม่ได้"
	var plus := int(item.get("plus", 0))
	if plus >= ItemData.MAX_PLUS:
		return "บวกสูงสุดแล้ว"
	var cost := ItemData.enhance_cost(item)
	for id in cost:
		if jewel_count(id) < int(cost[id]):
			return "เพชรไม่พอ (ต้องใช้ %s)" % ItemData.jewel_cost_text(cost)
	for id in cost:
		if int(cost[id]) > 0:
			_spend_jewels(id, int(cost[id]))
	if rng.randf() < ItemData.enhance_chance(plus):
		item["plus"] = plus + 1
		item["price"] = int(int(item.price) * 1.12)
		flag_max("best_plus", plus + 1)
		guild_quest_progress("enhance", 1)
		check_achievements()
		clamp_vitals()
		inventory_changed.emit()
		profile_changed.emit()
		mark_dirty()
		return "ok"
	inventory_changed.emit()
	mark_dirty()
	return "fail"


## Crafts Lv.100 wings in the bag into this class's 100★ wings with a chaos jewel and
## a feather (StarWingData.CRAFT_COST). Returns "ok", "fail" (the jewels are used up,
## the wings stay) or a reason. The crafted wings keep their uid, plus and gems.
func craft_star_wings(item: Dictionary) -> String:
	if not StarWingData.can_craft(item):
		return "ใช้ปีกเลเวล 100 เท่านั้น"
	if not profile["inv"].any(func(piece): return is_same(piece, item)):
		return "ถอดปีกเก็บเข้ากระเป๋าก่อน"
	var cost: Dictionary = StarWingData.CRAFT_COST
	for id in cost:
		if jewel_count(id) < int(cost[id]):
			return "เพชรไม่พอ (ต้องใช้ เพชรชาออส %d เม็ด + ขนนก %d ขน)" % [int(cost.chaos), int(cost.feather)]
	for id in cost:
		_spend_jewels(id, int(cost[id]))
	if rng.randf() >= StarWingData.CRAFT_CHANCE:
		inventory_changed.emit()
		mark_dirty()
		return "fail"
	var fresh := StarWingData.item(String(class_id()), rng)
	for key in fresh:
		if key not in ["uid", "plus", "gems", "sockets"]:
			item[key] = fresh[key]
	item["sockets"] = maxi(int(fresh.sockets), (item.get("gems", []) as Array).size())
	inventory_changed.emit()
	profile_changed.emit()
	mark_dirty()
	return "ok"


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


## Fuses three gems of one kind and size into one of the next size at the forge
## (ItemData.GEM_FUSE_CHANCE / GEM_FUSE_GOLD). A failed try loses one of the three.
## Returns "ok", "fail" or a reason.
func fuse_gem(gem_id: String) -> String:
	var info := ItemData.gem_info({"id": gem_id})
	if info.size >= ItemData.GEM_MAX_SIZE:
		return "อัญมณีขั้นสูงสุดแล้ว"
	var have := 0
	for it in profile["inv"]:
		if it.get("kind", "") == "gem" and String(it.id) == gem_id:
			have += int(it.get("count", 1))
	if have < 3:
		return "ต้องมี %s 3 เม็ด (มี %d)" % [info.name, have]
	var gold := int(ItemData.GEM_FUSE_GOLD[info.size])
	if int(profile.get("gold", 0)) < gold:
		return "เงินไม่พอ (ต้องใช้ %d)" % gold
	var lucky := rng.randf() < float(ItemData.GEM_FUSE_CHANCE[info.size])
	if lucky and inventory_free() <= 0 and _gem_index(_gem_id_of(info.type, info.size + 1)) < 0 and have > 3:
		return "กระเป๋าเต็ม"
	add_gold(-gold)
	_take_gems(gem_id, 3 if lucky else 1)
	if not lucky:
		inventory_changed.emit()
		mark_dirty()
		return "fail"
	add_item(ItemData.gem(info.type, info.size + 1))
	flag_add("gems_fused")
	inventory_changed.emit()
	mark_dirty()
	return "ok"


func _gem_id_of(type: String, size: int) -> String:
	return "%s_%d" % [type, size]


func _gem_index(gem_id: String) -> int:
	for i in profile["inv"].size():
		var it: Dictionary = profile["inv"][i]
		if it.get("kind", "") == "gem" and String(it.id) == gem_id:
			return i
	return -1


func _take_gems(gem_id: String, count: int) -> void:
	while count > 0:
		var i := _gem_index(gem_id)
		if i < 0:
			return
		var take := mini(count, int(profile["inv"][i].get("count", 1)))
		remove_item_at(i, take)
		count -= take


## Opens one more gem socket on a piece with a drill (สว่านเจาะ), up to
## ItemData.max_sockets (3, a fourth at +15). Returns "ok" or a reason.
func drill_socket(item: Dictionary) -> String:
	if item.get("kind", "") != "equip" or not EnhanceFx.can_enhance(item):
		return "เจาะช่องไม่ได้"
	if int(item.get("sockets", 0)) >= ItemData.max_sockets(item):
		return "ช่องเต็มแล้ว" if int(item.get("plus", 0)) >= 15 else "ช่องเต็มแล้ว (ตีบวก +15 เปิดช่องที่ 4)"
	if jewel_count("drill") < 1:
		return "ต้องใช้สว่านเจาะ 1 อัน"
	_spend_jewels("drill", 1)
	item["sockets"] = int(item.get("sockets", 0)) + 1
	inventory_changed.emit()
	profile_changed.emit()
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


## The Halloween potion's EXP boost, kept in profile.flags as the real (unix) time it
## ends and its multiplier, so it runs out on time even while the game is closed.
const BOOST_UNTIL := "xb_until"
const BOOST_MULT := "xb_mult"
## While it runs the potion also gives +10% attack and +10% drop chance.
const BOOST_ATK := 0.1
const BOOST_DROP := 0.1


## The potion's extra drop chance (0 when none is running), added to the luck of drops.
func boost_drop() -> float:
	return BOOST_DROP if exp_boost_left() > 0.0 else 0.0


## Seconds left on the EXP potion (0 when none is running).
func exp_boost_left() -> float:
	if not has_profile:
		return 0.0
	return maxf(0.0, float(profile["flags"].get(BOOST_UNTIL, 0)) - WorldPresence.clock())


func exp_boost_mult() -> float:
	if exp_boost_left() <= 0.0:
		return 1.0
	return float(clampi(int(profile["flags"].get(BOOST_MULT, 1)), 1, 3))


## The HUD line of a running EXP potion ("" when none).
func exp_boost_text() -> String:
	var left := exp_boost_left()
	if left <= 0.0:
		return ""
	return "น้ำยาฮาโลวีน EXP x%d โจมตี +10%% ดรอป +10%% เหลือ %d นาที" % [int(exp_boost_mult()), maxi(1, int(ceil(left / 60.0)))]


## Drinks a Halloween potion: EXP x2 or x3 for an hour of real time. Refused while
## one still runs (the potion is kept). Returns the multiplier, or 0.
func drink_exp_potion() -> int:
	if exp_boost_left() > 0.0:
		say("น้ำยาฮาโลวีนยังออกฤทธิ์อยู่ (%s)" % exp_boost_text(), &"warning")
		return 0
	var mult: int = ItemData.EXP_BOOST_MULTS[rng.randi() % ItemData.EXP_BOOST_MULTS.size()]
	profile["flags"][BOOST_UNTIL] = int(round(WorldPresence.clock())) + ItemData.EXP_BOOST_TIME
	profile["flags"][BOOST_MULT] = mult
	say("น้ำยาฮาโลวีน: EXP x%d โจมตี +10%% ดรอป +10%% นาน 1 ชั่วโมง!" % mult, &"success")
	var hero := get_tree().get_first_node_in_group("hero")
	if hero is Hero:
		(hero as Hero).refresh_stats()
	return mult


func use_potion_at(index: int) -> String:
	var item: Dictionary = profile["inv"][index]
	if item.get("kind", "") != "potion":
		return ""
	if in_duel():
		say("ใช้ยาในสนามจัดอันดับไม่ได้", &"warning")
		return ""
	var def: Dictionary = ItemData.POTIONS[item.id]
	if def.has("exp_boost") and drink_exp_potion() == 0:
		return ""
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


## Bag items auto-sell would sell: unworn gear of the chosen grades (bit per
## rarity in [param mask]) below [param below_level] (0 = any level). Enhanced
## gear, gear with gems and wings are always kept.
func auto_sell_indices(mask: int, below_level: int) -> Array[int]:
	var out: Array[int] = []
	for i in profile["inv"].size():
		var item: Dictionary = profile["inv"][i]
		if item.get("kind", "") != "equip" or item.get("slot", "") == "wings":
			continue
		if int(item.get("plus", 0)) > 0 or not (item.get("gems", []) as Array).is_empty():
			continue
		if (mask >> clampi(int(item.get("rarity", 0)), 0, 4)) & 1 == 0:
			continue
		if below_level > 0 and int(item.get("level", 1)) >= below_level:
			continue
		out.append(i)
	return out


## Sells everything [method auto_sell_indices] picks. Returns {count, gold}.
func auto_sell(mask: int, below_level: int) -> Dictionary:
	var picked := auto_sell_indices(mask, below_level)
	var total := 0
	for k in range(picked.size() - 1, -1, -1):
		total += ItemData.sell_price(profile["inv"][picked[k]])
		profile["inv"].remove_at(picked[k])
	profile.flags["autosell_mask"] = mask
	profile.flags["autosell_level"] = below_level
	if not picked.is_empty():
		add_gold(total)
		inventory_changed.emit()
		say("ขายอัตโนมัติ %d ชิ้น ได้ %d เหรียญ" % [picked.size(), total], &"success")
	mark_dirty()
	return {"count": picked.size(), "gold": total}


## Grades of dropped gear the hero picks up (bit per rarity; all by default).
func loot_mask() -> int:
	return int(profile.get("flags", {}).get("loot_mask", 31))


func set_loot_mask(mask: int) -> void:
	profile.flags["loot_mask"] = clampi(mask, 0, 31)
	mark_dirty()


## Whether a drop is kept: potions, gems, jewels, gold and wings always are; gear only
## when its grade is switched on in the pickup filter.
func keeps_loot(item: Dictionary) -> bool:
	if item.get("kind", "") != "equip" or item.get("slot", "") == "wings":
		return true
	return (loot_mask() >> clampi(int(item.get("rarity", 0)), 0, 4)) & 1 == 1


func buy_item(item: Dictionary) -> bool:
	var price := ItemData.buy_price(item) * (int(item.get("count", 1)) if ItemData.is_stackable(item) else 1)
	if profile["gold"] < price:
		say("เหรียญไม่พอ", &"warning")
		return false
	# Potions stack onto a bottle already in the bag; a new kind needs a free slot.
	var stacks: bool = ItemData.is_stackable(item) and profile["inv"].any(func(e): return e.get("kind", "") == item.get("kind", "") and e.get("id") == item.id)
	if not stacks and inventory_free() <= 0:
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


func ending_unlocked() -> bool:
	return int(profile.get("flags", {}).get(ENDING_FLAG, 0)) > 0


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
	# The same emperor also appears in the tower; only the final field ends
	# the adventure. An old magma ending must not suppress this first victory.
	if is_boss and current_zone == ENDING_ZONE and monster_id == ZoneData.get_zone(ENDING_ZONE).boss.monster and not ending_unlocked():
		profile["flags"][ENDING_FLAG] = 1
		var victorious_profile := profile
		var victorious_slot := slot
		# Wait for menus to close, and never show another character's finale
		# after a save switch, import, or departure during the victory delay.
		get_tree().create_timer(2.5, false).timeout.connect(func():
			if has_profile and playing and slot == victorious_slot and is_same(profile, victorious_profile) and current_zone == ENDING_ZONE:
				ending_requested.emit()
		, CONNECT_ONE_SHOT)
	daily_progress("kills", 1)
	daily_progress("zone_kills", 1)
	if is_boss:
		daily_progress("boss", 1)
	guild_quest_progress("kills", 1)
	if is_boss:
		guild_quest_progress("boss", 1)
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
	_check_achievements()


# ---------------------------------------------------------------------------
# Titled achievements (Achievements): the title shows above the hero's head
# ---------------------------------------------------------------------------

## Seconds between two checks from _process (check_achievements and save check at once).
const ACH_INTERVAL := 2.0
var _ach_timer := 0.0


## Marks the titled achievements earned by now, announces each and tells the HUD.
func _check_achievements() -> void:
	_ach_timer = 0.0
	if not has_profile:
		return
	for id in Achievements.check_all(profile, {"party": world_party.size()}):
		say("ได้รับความสำเร็จ: %s" % Achievements.entry(id).name, &"success")
		achievement_earned.emit(id)
		mark_dirty()


## The title above the hero's head: the title of the earned achievement at index in
## Achievements.TABLE, or none for a negative index. False (and no change) otherwise.
func set_title(index: int) -> bool:
	if not has_profile or not Achievements.set_title(profile, index):
		return false
	mark_dirty()
	title_changed.emit(Achievements.title_of(profile))
	return true


## A chat line on its channel: "world" goes to world_chat, "party" / "guild" to channel_chat.
func post_chat(channel: String, speaker: String, text: String, color: Color) -> void:
	if channel == "party" or channel == "guild":
		channel_chat.emit(channel, speaker, text, color)
	else:
		world_chat.emit(speaker, text, color)


func _on_world_chat(speaker: String, _text: String, _color: Color) -> void:
	if has_profile and speaker == String(profile.get("name", "")) and int(profile["flags"].get(Achievements.CHAT_FLAG, 0)) == 0:
		flag_max(Achievements.CHAT_FLAG, 1)
		_check_achievements()


func _on_world_boss_defeated(_zone: StringName) -> void:
	if has_profile:
		flag_add(Achievements.WORLD_BOSS_FLAG)
		_check_achievements()


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


## The war in progress, kept in the save so a page the phone threw away in the background
## (or a closed tab) can pick the same war up again: line-ups come from the seed, the rest
## is the clock and the score. Plain ints in the flags, so it travels with every save.
const GW_CKPT_KEYS := ["gw_r_seed", "gw_r_time", "gw_r_us", "gw_r_them", "gw_r_kills", "gw_r_deaths", "gw_r_ot", "gw_r_at", "gw_r_t0", "gw_r_g0", "gw_r_g1", "gw_r_g2", "gw_r_owner", "gw_r_pc", "gw_r_p0", "gw_r_p1", "gw_r_p2", "gw_r_p3"]
## A war cut off (the page closed, the phone dropped it) can be rejoined for 10 minutes.
const GW_CKPT_LIFETIME := 10 * 60
## Set by the lobby's "continue" button; the next guild war zone takes it.
var guildwar_resuming := false
## The party screen's choice for the next guild war (GuildWarScreen): the names of the
## teammates picked into the hero's party, and whether the player chose at all (the war
## takes the choice once; the names stay to be offered again next time).
var guildwar_party_picks: PackedStringArray = []
var guildwar_party_chosen := false


## `siege`: {gates: [what is left of each gate, 0..1000], owner: the castle's holder (-1 none, 0 us, 1 them),
## picks: our roster's indices in the hero's party, chosen: whether the player picked them}.
func guildwar_save_checkpoint(rng_seed: int, time_left: float, overtime: bool, score: Array, kills: int, deaths: int, started_at := 0, siege := {}) -> void:
	var flags: Dictionary = profile["flags"]
	var left: Array = siege.get("gates", [])
	for k in 3:
		flags["gw_r_g%d" % k] = clampi(int(left[k]), 0, 1000) if k < left.size() else 1000
	# Saved flags are never negative: 0 nobody, 1 us, 2 them.
	flags["gw_r_owner"] = clampi(int(siege.get("owner", -1)), -1, 1) + 1
	# The hero's party: roster index + 1 per pick (0 for an empty place).
	var picks: Array = siege.get("picks", [])
	flags["gw_r_pc"] = 1 if bool(siege.get("chosen", false)) else 0
	for k in 4:
		flags["gw_r_p%d" % k] = clampi(int(picks[k]) + 1, 0, 999) if k < picks.size() else 0
	flags["gw_r_seed"] = rng_seed
	# When the war began: the guilds line up as their members were at that moment.
	flags["gw_r_t0"] = started_at
	flags["gw_r_time"] = int(ceil(time_left))
	flags["gw_r_us"] = int(score[0])
	flags["gw_r_them"] = int(score[1])
	flags["gw_r_kills"] = kills
	flags["gw_r_deaths"] = deaths
	flags["gw_r_ot"] = 1 if overtime else 0
	flags["gw_r_at"] = int(Time.get_unix_time_from_system())
	mark_dirty()


## The unfinished war, or {} when there is none (or it is too old to matter).
## Seconds left to rejoin a war that was cut off (0: none to rejoin).
func guildwar_rejoin_left() -> int:
	if guildwar_checkpoint().is_empty():
		return 0
	return maxi(0, GW_CKPT_LIFETIME - (int(Time.get_unix_time_from_system()) - int(profile["flags"]["gw_r_at"])))


func guildwar_checkpoint() -> Dictionary:
	if not has_profile:
		return {}
	var flags: Dictionary = profile.get("flags", {})
	if not flags.has("gw_r_seed") or not flags.has("gw_r_at"):
		return {}
	if int(Time.get_unix_time_from_system()) - int(flags["gw_r_at"]) > GW_CKPT_LIFETIME:
		return {}
	return {"seed": int(flags["gw_r_seed"]), "time_left": float(flags.get("gw_r_time", 0)), "us": int(flags.get("gw_r_us", 0)),
			"them": int(flags.get("gw_r_them", 0)), "kills": int(flags.get("gw_r_kills", 0)), "deaths": int(flags.get("gw_r_deaths", 0)),
			"overtime": int(flags.get("gw_r_ot", 0)) == 1, "t0": int(flags.get("gw_r_t0", 0)),
			"gates": [int(flags.get("gw_r_g0", 1000)), int(flags.get("gw_r_g1", 1000)), int(flags.get("gw_r_g2", 1000))], "owner": clampi(int(flags.get("gw_r_owner", 0)), 0, 2) - 1,
			"chosen": int(flags.get("gw_r_pc", 0)) == 1, "picks": _guildwar_saved_picks(flags)}


func _guildwar_saved_picks(flags: Dictionary) -> Array:
	var out: Array = []
	for k in 4:
		var v := int(flags.get("gw_r_p%d" % k, 0))
		if v > 0:
			out.append(v - 1)
	return out


# ---------------------------------------------------------------------------
# Guild: Alpha or Neverdie, with the world players (WorldPlayers)
# ---------------------------------------------------------------------------

const GUILD_FLAG := "guild"
## A guild takes heroes from this level on.
const GUILD_LEVEL := 100


## The hero's guild (WorldPlayers.ALPHA / NEVERDIE), 0 before joining one.
func guild() -> int:
	if not has_profile:
		return 0
	var g := int(profile.get("flags", {}).get(GUILD_FLAG, 0))
	return g if WorldPlayers.GUILD_NAMES.has(g) else 0


## Joins (or moves to) a guild at the guild registrar, from Lv.100. False if already in it.
func join_guild(g: int) -> bool:
	if not has_profile or not WorldPlayers.GUILD_NAMES.has(g) or guild() == g or int(profile.level) < GUILD_LEVEL:
		return false
	profile["flags"][GUILD_FLAG] = g
	mark_dirty()
	guild_changed.emit()
	return true


# --- Guild daily quests and the guild points shop (GuildQuestData) ---------------
# Saved as ints in profile.flags: gq_day (the Thai day the counters belong to), gq_<kind>
# (the hero's own work today), gq_c<slot> (claimed), gq_n<slot> (announced) and gpoints.

const GQ_CHECK_INTERVAL := 30.0
var _gq_timer := 0.0
## Today's drawn quests by "guild|day" (the draw never changes within a day).
var _gq_cache := {}


func guild_quest_day(t := -1.0) -> int:
	return WorldEvents.day_of(WorldPresence.clock() if t < 0.0 else t)


## Clears yesterday's counters and claims when a new Thai day begins.
func _guild_quest_roll(t := -1.0) -> void:
	var today := guild_quest_day(t)
	var flags: Dictionary = profile["flags"]
	if int(flags.get(GuildQuestData.DAY_FLAG, 0)) == today:
		return
	for key in flags.keys():
		if String(key).begins_with("gq_"):
			flags.erase(key)
	flags[GuildQuestData.DAY_FLAG] = today
	mark_dirty()


func guild_points() -> int:
	if not has_profile:
		return 0
	return int(profile["flags"].get(GuildQuestData.POINTS_FLAG, 0))


## Today's guild quests with their progress: [{slot, kind, name, target, points, gold,
## hero, mates, progress, done, claimed}]; [] outside a guild.
func guild_quests(t := -1.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var g := guild()
	if g <= 0:
		return out
	if t < 0.0:
		t = WorldPresence.clock()
	_guild_quest_roll(t)
	var day := guild_quest_day(t)
	var key := "%d|%d" % [g, day]
	if not _gq_cache.has(key):
		_gq_cache.clear()
		var war_ok := GuildWarData.guild_war_blocked(g, GuildQuestData.day_start(day)) == ""
		_gq_cache[key] = GuildQuestData.quests_for(g, day, war_ok)
	var flags: Dictionary = profile["flags"]
	for base in _gq_cache[key]:
		var q: Dictionary = base.duplicate()
		var hero := int(flags.get("gq_" + String(q.kind), 0))
		var mates := GuildQuestData.mate_share(g, q, t)
		q["hero"] = hero
		q["mates"] = mates
		q["progress"] = mini(hero + mates, int(q.target))
		q["done"] = hero + mates >= int(q.target)
		q["claimed"] = int(flags.get("gq_c%d" % int(q.slot), 0)) > 0
		out.append(q)
	return out


## The hero's own work for the guild quests (kills, boss, enhance, war, jewels).
func guild_quest_progress(kind: String, amount := 1) -> void:
	if not has_profile or guild() <= 0 or amount <= 0:
		return
	_guild_quest_roll()
	if GuildQuestData.template(kind).is_empty():
		return
	flag_add("gq_" + kind, amount)
	mark_dirty()
	_guild_quest_announce(kind)


## Toasts each quest that has just been finished (by the hero or the guild), once
## (only the quests of `kind` when given).
func _guild_quest_announce(kind := "") -> void:
	for q in guild_quests():
		var key := "gq_n%d" % int(q.slot)
		if kind != "" and String(q.kind) != kind:
			continue
		if bool(q.done) and not bool(q.claimed) and int(profile["flags"].get(key, 0)) == 0:
			profile["flags"][key] = 1
			mark_dirty()
			say("ภารกิจกิลด์ \"%s\" สำเร็จ! รับแต้มกิลด์ที่นายทะเบียนกิลด์" % String(q.name), &"quest")


## Claims a finished guild quest once: guild points and gold. "ok" or a reason.
func guild_quest_claim(slot: int) -> String:
	for q in guild_quests():
		if int(q.slot) != slot:
			continue
		if bool(q.claimed):
			return "รับรางวัลภารกิจนี้ไปแล้ว"
		if not bool(q.done):
			return "ภารกิจยังไม่สำเร็จ"
		profile["flags"]["gq_c%d" % slot] = 1
		flag_add(GuildQuestData.POINTS_FLAG, int(q.points))
		add_gold(int(q.gold))
		mark_dirty()
		return "ok"
	return "ไม่มีภารกิจนี้" if guild() > 0 else "ต้องอยู่ในกิลด์ก่อน"


## Buys from the guild points shop (GuildQuestData.SHOP). "ok" or a reason.
func guild_shop_buy(id: String) -> String:
	if guild() <= 0:
		return "ต้องอยู่ในกิลด์ก่อน"
	var e := GuildQuestData.shop_entry(id)
	if e.is_empty():
		return "ไม่มีสินค้านี้"
	if guild_points() < int(e.price):
		return "แต้มกิลด์ไม่พอ (ต้องใช้ %d แต้ม)" % int(e.price)
	if not give_or_store(GuildQuestData.shop_item(e)):
		return "กระเป๋าและคลังเต็ม"
	profile["flags"][GuildQuestData.POINTS_FLAG] = guild_points() - int(e.price)
	mark_dirty()
	return "ok"


## War rations: tops the bag up to GuildWarData.SUPPLY_COUNT war potions.
func guildwar_issue_supply() -> void:
	var missing := GuildWarData.SUPPLY_COUNT - potion_count(GuildWarData.SUPPLY_POTION)
	if missing > 0:
		add_item(ItemData.potion(GuildWarData.SUPPLY_POTION, missing))


## What is left of the rations goes back to the guild when the war ends.
func guildwar_return_supply() -> void:
	for i in range(profile["inv"].size() - 1, -1, -1):
		var item: Dictionary = profile["inv"][i]
		if item.get("kind", "") == "potion" and item.id == GuildWarData.SUPPLY_POTION:
			profile["inv"].remove_at(i)
	inventory_changed.emit()
	mark_dirty()


func guildwar_clear_checkpoint() -> void:
	var flags: Dictionary = profile["flags"]
	for key in GW_CKPT_KEYS:
		flags.erase(key)
	mark_dirty()


## Ends a guild war: gold (and on a win EXP, pink jewels and feathers), the record in
## the flags, and the last war's scoreboard (`rows`: name, class, team, kills, deaths)
## in profile.gw_last for the war desk.
func guildwar_finish(won: bool, score_us: int, score_them: int, kills: int, deaths: int, our_guild: String, their_guild: String, rows: Array = []) -> Dictionary:
	guildwar_clear_checkpoint()
	guildwar_return_supply()
	var level := int(profile.level)
	var gold := GuildWarData.gold_reward(won)
	var exp_gain := GuildWarData.exp_reward(level, won)
	add_gold(gold)
	add_exp(exp_gain)
	var jewels: Dictionary = GuildWarData.WIN_JEWELS if won else {}
	for id in jewels:
		give_or_store(ItemData.jewel(id, int(jewels[id])))
	var board: Array = []
	for r in rows:
		board.append({"name": String(r.get("name", "")), "class": String(r.get("class", "")), "team": int(r.get("team", 0)),
			"kills": int(r.get("kills", 0)), "deaths": int(r.get("deaths", 0))})
	profile["gw_last"] = {"won": won, "score_us": score_us, "score_them": score_them, "our_guild": our_guild,
		"their_guild": their_guild, "at": int(WorldPresence.clock()), "rows": board}
	flag_add("gw_played")
	flag_add("gw_wins" if won else "gw_losses")
	if won:
		guild_quest_progress("war", 1)
	flag_add("gw_kills", kills)
	flag_max("gw_best_kills", kills)
	var stats := stats_now()
	profile["hp"] = stats.max_hp
	profile["mp"] = stats.max_mp
	check_achievements()
	mark_dirty()
	save()
	return {"won": won, "score_us": score_us, "score_them": score_them, "kills": kills, "deaths": deaths, "gold": gold, "exp": exp_gain, "jewels": jewels,
		"our_guild": our_guild, "their_guild": their_guild, "wins": int(profile.flags.get("gw_wins", 0)), "losses": int(profile.flags.get("gw_losses", 0)),
		"best_kills": int(profile.flags.get("gw_best_kills", 0))}


func flag_add(key: String, amount := 1) -> void:
	profile["flags"][key] = int(profile["flags"].get(key, 0)) + amount


func flag_max(key: String, value: int) -> void:
	profile["flags"][key] = maxi(int(profile["flags"].get(key, 0)), value)
