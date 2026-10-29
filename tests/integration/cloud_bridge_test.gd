extends Node
## Run with an isolated user directory. The probe records committed cloud
## requests without needing a browser or changing native save behavior.

class CloudProbe:
	extends "res://systems/core/game.gd"
	var requests: Array[Dictionary] = []
	var pretend_file_slot := 0
	func _queue_cloud_save() -> void:
		requests.append(build_cloud_bundle())
	func has_save(for_slot := -1) -> bool:
		var target: int = slot if for_slot < 1 else for_slot
		return target == pretend_file_slot or super.has_save(for_slot)

var failures := 0
var checks := 0
var probe: CloudProbe


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	probe = CloudProbe.new()
	add_child(probe)
	probe.set_process(false)
	_clear_slots()
	_test_full_bundle()
	_test_failed_commits()
	_test_import_and_delete()
	_test_safe_script()
	_test_modal_pause()
	_test_background_pause()
	# Give the audio thread time to release the two stopped playback fixtures.
	await get_tree().create_timer(0.2, true, false, true).timeout
	probe.has_profile = false
	Game.has_profile = false
	print("CLOUD BRIDGE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _clear_slots() -> void:
	for i in range(1, probe.SLOT_COUNT + 1):
		var path := ProjectSettings.globalize_path(probe.save_path(i))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	probe.requests.clear()


func _test_full_bundle() -> void:
	probe.new_profile(&"mage", "ลูกแก้ว ' \\\" \n 日本語 🌟", FaceKit.default_look())
	var template := probe.profile.duplicate(true)
	for i in range(1, probe.SLOT_COUNT + 1):
		probe.slot = i
		probe.profile = template.duplicate(true)
		probe.profile["name"] = "ช่อง %d: '); window.bad = true; //" % i
		probe.profile["cloud_bridge_test_payload"] = {"unicode": "สระไม้เอก: ก่ ข้ 💫", "values": [i, null, true, {"nested": "\n\t\\\""}]}
		probe.profile["gold"] = i * 777
		check(probe.save(), "slot %d saves successfully" % i)
	check(probe.requests.size() == probe.SLOT_COUNT + 1, "new profile and each successful save request a cloud snapshot")
	var disk_before: Dictionary = {}
	for i in range(1, probe.SLOT_COUNT + 1):
		disk_before[str(i)] = FileAccess.get_file_as_string(probe.save_path(i))
	var profile_before := probe.profile.duplicate(true)
	var bundle := probe.build_cloud_bundle()
	check(bundle.slots.size() == probe.SLOT_COUNT and bundle.selectedSlot == probe.SLOT_COUNT, "bundle includes every slot and the selected slot")
	for i in range(1, probe.SLOT_COUNT + 1):
		check(bundle.slots[str(i)] == JSON.parse_string(disk_before[str(i)]), "slot %d data stays exact, including unknown fields" % i)
		check(FileAccess.get_file_as_string(probe.save_path(i)) == disk_before[str(i)], "building a bundle leaves slot %d unchanged" % i)
	check(probe.profile == profile_before and probe.slot == probe.SLOT_COUNT, "building a bundle leaves the active profile and selection unchanged")
	# The upload text comes from the cached slot texts and says the same as the bundle
	# (compared as JSON: parsed numbers are floats).
	var canon := func(text: String) -> String: return JSON.stringify(JSON.parse_string(text))
	check(canon.call(probe.cloud_bundle_json()) == canon.call(JSON.stringify(bundle)), "the cached upload text is the bundle")
	var again := probe.cloud_bundle_json()
	check(canon.call(again) == canon.call(JSON.stringify(bundle)) and again == probe.cloud_bundle_json(), "and stays the same while nothing changes")
	bundle.slots["1"].gold = 0
	check(probe._read_slot(1).gold == 777, "bundle dictionaries are independent of persisted data")
	probe.slot = 99
	check(probe.build_cloud_bundle().selectedSlot == probe.SLOT_COUNT, "selected slot is clamped to the supported range")
	probe.slot = 4
	var file := FileAccess.open(probe.save_path(3), FileAccess.WRITE)
	file.store_string("{\"class\":\"missing\",\"level\":1}")
	file.close()
	check(not probe.build_cloud_bundle().slots.has("3"), "invalid local slots are excluded rather than uploaded")
	check(not JSON.parse_string(probe.cloud_bundle_json()).slots.has("3"), "a slot file changed behind the cache is read again (excluded here)")
	check(probe._write_profile(JSON.parse_string(disk_before["3"]), 3), "fixture restores the valid third slot")


func _test_failed_commits() -> void:
	var dir := DirAccess.open("user://")
	var temporary := probe.save_path(4).get_file() + ".tmp"
	check(dir.make_dir(temporary) == OK, "fixture blocks the atomic temporary write path")
	var requests_before := probe.requests.size()
	var saved_before := FileAccess.get_file_as_string(probe.save_path(4))
	probe.profile.gold += 100
	check(not probe.save(), "failed save reports failure")
	check(probe.requests.size() == requests_before, "failed save never requests a cloud upload")
	check(FileAccess.get_file_as_string(probe.save_path(4)) == saved_before, "failed save preserves the committed local slot")
	var code := Marshalls.utf8_to_base64(saved_before)
	check(not probe.import_code(code, 4), "failed import reports failure")
	check(probe.requests.size() == requests_before, "failed import never requests a cloud upload")
	var warnings: Array[String] = []
	var record_warning := func(message: String, kind: StringName):
		if kind == &"warning":
			warnings.append(message)
	probe.toast.connect(record_warning)
	check(not probe._save_before_cloud_account(), "failed local commit blocks opening the account switch panel")
	check(warnings.size() == 1 and warnings[0].contains("สำรองรหัสเซฟ"), "blocked account switching explains how to preserve progress in Thai")
	check(probe.requests.size() == requests_before, "blocked account switching never uploads an older local snapshot")
	probe.toast.disconnect(record_warning)
	check(dir.remove(temporary) == OK, "fixture removes the blocked temporary path")
	check(not probe.import_code("not a save", 2), "invalid import is rejected")
	check(probe.requests.size() == requests_before, "invalid import never requests a cloud upload")
	probe.delete_save(probe.SLOT_COUNT + 1)
	check(probe.requests.size() == requests_before, "out-of-range deletion never requests a cloud upload")
	check(probe._save_before_cloud_account(), "successful local commit permits the account panel")
	check(probe.requests.size() == requests_before + 1, "opening an account panel queues the successfully committed latest progress")


func _test_import_and_delete() -> void:
	var incoming := probe._read_slot(1)
	incoming.name = "ตัวละครนำเข้า ' \\\" 🌿"
	var requests_before := probe.requests.size()
	check(probe.import_code(Marshalls.utf8_to_base64(JSON.stringify(incoming)), 2), "valid import commits to its destination")
	check(probe.requests.size() == requests_before + 1, "successful import queues one snapshot")
	check(probe.requests.back().selectedSlot == 2 and probe.requests.back().slots["2"].name == incoming.name, "import snapshot contains the committed destination and identity")
	requests_before = probe.requests.size()
	probe.delete_save(1)
	check(probe.requests.size() == requests_before + 1, "successful deletion queues one snapshot")
	check(not probe.requests.back().slots.has("1") and probe.requests.back().slots.size() == probe.SLOT_COUNT - 1, "deletion snapshot removes only the deleted slot")
	probe.delete_save(1)
	check(probe.requests.size() == requests_before + 1, "deleting an already-empty slot produces no duplicate request")
	var current := probe.profile.duplicate(true)
	var path := probe.save_path(2).get_file()
	var dir := DirAccess.open("user://")
	check(dir.rename(path, path + ".held") == OK, "fixture moves the active slot file")
	check(dir.make_dir(path) == OK, "fixture blocks slot removal with a non-empty directory")
	var held := FileAccess.open(probe.save_path(2) + "/blocker", FileAccess.WRITE)
	held.store_string("preserve")
	held.close()
	# Exercise the remove failure after a file-exists check, without depending
	# on Unix write permissions (tests can run as root).
	probe.pretend_file_slot = 2
	probe.delete_save(2)
	check(probe.requests.size() == requests_before + 1, "failed removal never uploads a deletion snapshot")
	check(probe.has_profile and probe.profile == current, "failed removal preserves the active profile")
	probe.pretend_file_slot = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe.save_path(2) + "/blocker"))
	dir.remove(path)
	dir.rename(path + ".held", path)
	probe.profile = current
	probe.has_profile = true


func _test_safe_script() -> void:
	var payload := JSON.stringify({"slots": {"1": {"name": "');window.bad=true;// \" \\ \n ไทย 💥"}}, "selectedSlot": 1})
	var source := probe._cloud_save_script(payload)
	var prefix := "if (typeof window.toonCloudSave === 'function') { window.toonCloudSave("
	var suffix := "); }"
	check(source.begins_with(prefix) and source.ends_with(suffix), "bridge feature-detects the optional browser upload hook")
	var argument := source.substr(prefix.length(), source.length() - prefix.length() - suffix.length())
	check(JSON.parse_string(argument) == payload, "dangerous quotes, newlines and Unicode remain a single encoded string argument")
	var separators := String.chr(0x2028) + String.chr(0x2029)
	var escaped := probe._cloud_save_script(separators)
	check(not escaped.contains(String.chr(0x2028)) and not escaped.contains(String.chr(0x2029)), "JavaScript line separators are escaped in generated source")


func _test_modal_pause() -> void:
	get_tree().paused = false
	probe._set_cloud_modal_open(true)
	check(get_tree().paused and probe._cloud_modal_paused, "account modal pauses live gameplay")
	probe._set_cloud_modal_open(true)
	probe._set_cloud_modal_open(false)
	check(not get_tree().paused and not probe._cloud_modal_paused, "closing the account modal restores live gameplay")
	get_tree().paused = true
	probe._set_cloud_modal_open(true)
	probe._set_cloud_modal_open(false)
	check(get_tree().paused, "closing the account modal preserves an already-paused game menu")
	get_tree().paused = false
	probe.profile.play_time = 0.0
	probe._set_cloud_modal_open(true)
	probe._process(0.5)
	check(probe.profile.play_time == 0.0, "account dialog time does not advance the active profile")
	probe._set_cloud_modal_open(false)


func _test_background_pause() -> void:
	get_tree().paused = false
	var music: AudioStreamPlayer = AudioManager.get_child(0)
	var other: AudioStreamPlayer = AudioManager.get_child(1)
	var silence := AudioStreamWAV.new()
	silence.data = PackedByteArray([128, 128, 128, 128])
	silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
	silence.loop_end = 4
	music.stream = silence
	other.stream = silence
	music.play()
	other.play()
	music.stream_paused = false
	other.stream_paused = true
	probe._apply_web_pause_mask(1)
	check(get_tree().paused and music.stream_paused, "hidden browser pauses the hunt and audio")
	probe._apply_web_pause_mask(3)
	probe._apply_web_pause_mask(2)
	check(get_tree().paused and not music.stream_paused, "visible browser resumes sound but keeps the account dialog paused")
	check(other.stream_paused, "background resume preserves a previously paused audio player")
	probe._apply_web_pause_mask(0)
	check(not get_tree().paused, "returning without a dialog resumes the hunt")
	get_tree().paused = true
	probe._apply_web_pause_mask(1)
	probe._apply_web_pause_mask(4)
	probe._apply_web_pause_mask(0)
	check(get_tree().paused, "hidden and report transitions preserve an already open game menu")
	get_tree().paused = false
	other.stream_paused = false
	music.stop()
	other.stop()
	music.stream = null
	other.stream = null
