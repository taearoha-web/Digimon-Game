extends Node
## SaveBackup: a backup copies every slot and writes its index, list() is newest first,
## pruning keeps 7 daily + 3 manual, a restore refuses a corrupted copy and puts a good
## one back after a "before-restore" backup (saved_at stamped with now and the restored
## slots listed in backups/restored.json for the web page's cloud sync), and maybe_daily
## runs once per day.
## Run with an isolated user directory:
## XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/save_backup_test.tscn

var failures := 0
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _ready() -> void:
	Game.set_process(false)
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	for entry in SaveBackup.list():
		SaveBackup._remove_dir(entry.dir)
	DirAccess.remove_absolute(SaveBackup.LAST_DAILY_PATH)
	DirAccess.remove_absolute(SaveBackup.RESTORED_MARKER)
	SaveBackup.reset_daily_cache()
	_test_daily()
	_test_copy_and_index()
	_test_order_and_prune()
	_test_restore()
	await _test_screen()
	print("SAVE BACKUP: %d checks, %d failures" % [checks, failures])
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	DirAccess.remove_absolute(SaveBackup.RESTORED_MARKER)
	get_tree().quit(0 if failures == 0 else 1)


func _make_hero(slot: int, cls: StringName, hero_name: String, level: int) -> void:
	Game.slot = slot
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile["level"] = level
	check(Game.save(), "hero %d saved" % slot)


func _count(reason: String) -> int:
	var n := 0
	for entry in SaveBackup.list():
		if entry.reason == reason:
			n += 1
	return n


## The two slot texts hold the same save apart from saved_at.
func _same_save(a: String, b: String) -> bool:
	var pa: Variant = JSON.parse_string(a)
	var pb: Variant = JSON.parse_string(b)
	if not pa is Dictionary or not pb is Dictionary:
		return false
	pa.erase("saved_at")
	pb.erase("saved_at")
	return pa == pb


func _saved_at(text: String) -> int:
	var parsed: Variant = JSON.parse_string(text)
	return int(parsed.get("saved_at", 0)) if parsed is Dictionary else -1


## With no save there is nothing to back up and the day is not spent; the first save of
## the day (Game.save's hook) makes the daily backup, the next saves do not.
func _test_daily() -> void:
	check(not SaveBackup.maybe_daily(), "no slots: no daily backup")
	check(SaveBackup.list().is_empty(), "no slots: no backup folder listed")
	_make_hero(1, &"warrior", "นักรบสำรอง", 5)
	check(_count("daily") == 1, "the first save of the day backed up (hook in Game.save)")
	check(FileAccess.file_exists(SaveBackup.LAST_DAILY_PATH), "the day is remembered on disk")
	check(FileAccess.get_file_as_string(SaveBackup.LAST_DAILY_PATH).strip_edges() == Time.get_date_string_from_system(), "last_daily.txt holds today")
	check(Game.save() and _count("daily") == 1, "a second save the same day makes no new daily backup")
	check(not SaveBackup.maybe_daily(), "maybe_daily is a no-op for the rest of the day")
	SaveBackup.reset_daily_cache()
	check(not SaveBackup.maybe_daily() and _count("daily") == 1, "the remembered day survives a restart (read from disk)")
	# Yesterday's marker: a new day backs up once more.
	var file := FileAccess.open(SaveBackup.LAST_DAILY_PATH, FileAccess.WRITE)
	file.store_string("2000-01-01")
	file.close()
	SaveBackup.reset_daily_cache()
	check(SaveBackup.maybe_daily() and _count("daily") == 2, "a new day backs up again")
	check(not SaveBackup.maybe_daily() and _count("daily") == 2, "and only once")


func _test_copy_and_index() -> void:
	_make_hero(3, &"mage", "จอมเวทสำรอง", 12)
	_make_hero(7, &"archer", "นักธนูสำรอง", 20)
	var dir := SaveBackup.backup_now("manual")
	var stamp := dir.get_file().substr(0, 15)
	check(dir.begins_with(SaveBackup.ROOT + "/") and stamp.substr(0, 8).is_valid_int() and stamp[8] == "-" and stamp.substr(9).is_valid_int() and dir.get_file().substr(15).begins_with("-manual"), "backup folder named <YYYYMMDD-HHMMSS>-<reason>: %s" % dir)
	for slot in [1, 3, 7]:
		var copy := dir.path_join(Game.save_path(slot).get_file())
		check(FileAccess.file_exists(copy), "slot %d copied" % slot)
		check(FileAccess.get_file_as_string(copy) == FileAccess.get_file_as_string(Game.save_path(slot)), "slot %d copy is byte-identical" % slot)
	for slot in [2, 4, 5, 6, 8, 9, 10]:
		check(not FileAccess.file_exists(dir.path_join(Game.save_path(slot).get_file())), "empty slot %d not copied" % slot)
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(SaveBackup.INDEX_FILE)))
	check(index is Dictionary and String(index.get("reason", "")) == "manual", "index holds the reason")
	check(index is Dictionary and absi(int(index.get("time", 0)) - int(Time.get_unix_time_from_system())) < 10, "index holds the time")
	var slots: Dictionary = index.get("slots", {}) if index is Dictionary else {}
	check(slots.size() == 3 and slots.has("1") and slots.has("3") and slots.has("7"), "index lists the three slots")
	check(slots.has("3") and String(slots["3"].name) == "จอมเวทสำรอง" and String(slots["3"]["class"]) == "mage" and int(slots["3"].level) == 12, "index summary: name / class / level")
	var listed := SaveBackup.list()
	check(not listed.is_empty() and listed[0].dir == dir and listed[0].reason == "manual" and listed[0].slots.size() == 3, "list() shows the new backup first with its summary")
	var second := SaveBackup.backup_now("manual")
	check(second != "" and second != dir, "two backups in one second get different folders")
	check(SaveBackup.list()[0].dir == second, "the later one lists first")


func _test_order_and_prune() -> void:
	var dailies: Array[String] = []
	for i in 9:
		dailies.append(SaveBackup.backup_now("daily"))
	var listed := SaveBackup.list()
	var dirs: Array = listed.map(func(entry: Dictionary) -> String: return entry.dir)
	check(dirs[0] == dailies[8], "list is newest first")
	for i in range(3, 9):
		check(dirs.find(dailies[i]) >= 0 and dirs.find(dailies[i]) < dirs.find(dailies[i - 1]), "list keeps the order made: %s before %s" % [dailies[i].get_file(), dailies[i - 1].get_file()])
	check(_count("daily") == SaveBackup.KEEP_DAILY, "at most %d daily backups kept (%d)" % [SaveBackup.KEEP_DAILY, _count("daily")])
	check(not DirAccess.dir_exists_absolute(dailies[0]) and not DirAccess.dir_exists_absolute(dailies[1]), "the oldest dailies were pruned")
	check(DirAccess.dir_exists_absolute(dailies[8]) and DirAccess.dir_exists_absolute(dailies[2]), "the newest 7 dailies stay")
	# _test_copy_and_index made 2 manual backups; 3 more leave the newest 3.
	var manuals: Array[String] = []
	for i in 3:
		manuals.append(SaveBackup.backup_now("manual"))
	check(_count("manual") == SaveBackup.KEEP_MANUAL, "at most %d manual backups kept (%d)" % [SaveBackup.KEEP_MANUAL, _count("manual")])
	check(DirAccess.dir_exists_absolute(manuals[2]) and DirAccess.dir_exists_absolute(manuals[0]), "the newest 3 manual backups stay")
	check(_count("daily") == SaveBackup.KEEP_DAILY, "manual backups do not push out dailies")
	var root := DirAccess.open(SaveBackup.ROOT)
	check(root != null and root.get_directories().size() == SaveBackup.KEEP_DAILY + SaveBackup.KEEP_MANUAL, "no stray folders left behind")


func _test_restore() -> void:
	var good := SaveBackup.backup_now("manual")
	var before := FileAccess.get_file_as_string(Game.save_path(3))
	# The live hero changes after the backup: a restore must bring the old copy back.
	Game.slot = 3
	check(Game.load_game(3), "slot 3 loads")
	Game.profile["level"] = 40
	Game.profile["name"] = "เปลี่ยนชื่อแล้ว"
	check(Game.save(), "changed hero saved")
	check(FileAccess.get_file_as_string(Game.save_path(3)) != before, "the live slot differs from the backup")
	Game.has_profile = false
	# A corrupted copy is refused and the live slot untouched.
	var broken := SaveBackup.backup_now("manual")
	var broken_copy := broken.path_join(Game.save_path(3).get_file())
	var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(broken_copy))
	bad["level"] = 999
	var file := FileAccess.open(broken_copy, FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	var live_before := FileAccess.get_file_as_string(Game.save_path(3))
	var manual_before := _count("manual")
	var before_restore_before := _count("before-restore")
	check(not SaveBackup.restore(broken, 3), "a corrupted backup is refused")
	check(FileAccess.get_file_as_string(Game.save_path(3)) == live_before, "refused restore leaves the live slot alone")
	check(_count("before-restore") == before_restore_before, "refused restore makes no before-restore backup")
	file = FileAccess.open(broken_copy, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	check(not SaveBackup.restore(broken, 3), "unparsable backup is refused")
	check(not SaveBackup.restore(good, 5), "a slot the backup lacks cannot be restored")
	check(not SaveBackup.restore(good, 0) and not SaveBackup.restore(good, 11), "slot out of range refused")
	check(not SaveBackup.restore("user://toon_tale_slot_1.json", 1) and not SaveBackup.restore("user://", 1), "only folders under backups/ are restored from")
	check(_count("manual") == manual_before, "refusals change nothing")
	check(not FileAccess.file_exists(SaveBackup.RESTORED_MARKER) and SaveBackup.restored_marker().is_empty(), "refusals write no restore marker")
	# The good copy comes back, after a before-restore backup of the changed hero.
	var changed := FileAccess.get_file_as_string(Game.save_path(3))
	var now := int(Time.get_unix_time_from_system())
	check(SaveBackup.restore(good, 3), "a valid backup restores")
	var restored_text := FileAccess.get_file_as_string(Game.save_path(3))
	check(_same_save(restored_text, before), "slot 3 holds the backed-up save again")
	check(_saved_at(restored_text) >= now and _saved_at(restored_text) - now < 10 and _saved_at(restored_text) >= _saved_at(before), "the restored slot's saved_at is stamped with now (%d, backup %d)" % [_saved_at(restored_text), _saved_at(before)])
	check(Game.slot_info(3).level == 12 and Game.slot_info(3).name == "จอมเวทสำรอง", "the restored hero reads back")
	check(_count("before-restore") == 1, "a before-restore backup was made")
	var marker := SaveBackup.restored_marker()
	check(FileAccess.file_exists(SaveBackup.RESTORED_MARKER) and marker.get("slots", []) == [3] and int(marker.get("time", 0)) >= now and int(marker.get("time", 0)) - now < 10, "restore writes backups/restored.json {time, slots: [3]}: %s" % JSON.stringify(marker))
	var raw_marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveBackup.RESTORED_MARKER))
	check(raw_marker is Dictionary and raw_marker.get("slots") is Array and raw_marker.slots.size() == 1 and int(raw_marker.slots[0]) == 3, "the marker file is plain JSON the web page can read")
	var safety: Dictionary = {}
	for entry in SaveBackup.list():
		if entry.reason == "before-restore":
			safety = entry
	check(not safety.is_empty() and FileAccess.get_file_as_string(String(safety.dir).path_join(Game.save_path(3).get_file())) == changed, "the before-restore backup holds the hero as it was before")
	check(_count("manual") + _count("before-restore") <= SaveBackup.KEEP_MANUAL, "before-restore backups count against the manual limit")
	# restore_all brings every slot of the backup back, and only those.
	Game.delete_save(1)
	Game.delete_save(7)
	_make_hero(9, &"warrior", "คนใหม่", 2)
	var nine := FileAccess.get_file_as_string(Game.save_path(9))
	Game.has_profile = false
	var seven_backup := FileAccess.get_file_as_string(good.path_join(Game.save_path(7).get_file()))
	now = int(Time.get_unix_time_from_system())
	check(SaveBackup.restore_all(good), "restore_all of a valid backup")
	check(Game.has_save(1) and Game.has_save(3) and Game.has_save(7), "restore_all brought the deleted heroes back")
	check(Game.slot_info(7).level == 20, "slot 7 restored")
	var seven := FileAccess.get_file_as_string(Game.save_path(7))
	check(_same_save(seven, seven_backup) and _saved_at(seven) >= now and _saved_at(seven) - now < 10, "restore_all stamps every restored slot's saved_at with now (%d)" % _saved_at(seven))
	check(_saved_at(FileAccess.get_file_as_string(Game.save_path(1))) >= now and _saved_at(FileAccess.get_file_as_string(Game.save_path(3))) >= now, "slots 1 and 3 stamped too")
	check(FileAccess.get_file_as_string(Game.save_path(9)) == nine, "a slot the backup lacks is left as it is")
	marker = SaveBackup.restored_marker()
	check(marker.get("slots", []) == [1, 3, 7] and int(marker.get("time", 0)) >= now, "restore_all adds its slots to the marker: %s" % JSON.stringify(marker))
	check(not SaveBackup.restore_all(broken), "restore_all refuses a backup with a corrupted slot")
	check(not SaveBackup.restore_all("user://backups/missing-folder"), "restore_all of a missing folder is refused")
	check(SaveBackup.restored_marker().get("slots", []) == [1, 3, 7], "refused restore_all leaves the marker as it was")



func _buttons(node: Node, text: String) -> Array[Button]:
	var out: Array[Button] = []
	for child in node.find_children("*", "Button", true, false):
		if (child as Button).text == text and (child as Button).is_visible_in_tree():
			out.append(child)
	return out


## The screen lists the backups newest first, opens one to its heroes, and a restore
## takes a second tap on the same button, then emits restored.
func _test_screen() -> void:
	var screen := BackupScreen.new()
	add_child(screen)
	var restored := [0]
	screen.restored.connect(func(): restored[0] += 1)
	screen.open_screen()
	await get_tree().process_frame
	var backups := SaveBackup.list()
	check(screen._box.get_child_count() == backups.size(), "one row per backup (%d)" % screen._box.get_child_count())
	var first := screen._box.get_child(0).find_children("*", "Label", true, false)[0] as Label
	check(first.text.begins_with(BackupScreen.format_time(int(backups[0].time))) and first.text.ends_with("%d ตัวละคร" % backups[0].slots.size()), "row text: %s" % first.text)
	check(BackupScreen.reason_text("daily") == "รายวัน" and BackupScreen.reason_text("before-restore") == "ก่อนกู้คืน", "reasons in Thai")
	check(_buttons(screen, "กู้คืนช่องนี้").is_empty(), "rows start folded")
	# Open the newest backup that holds slot 7 (restore_all's before-restore copy has it).
	var target := {}
	for entry in backups:
		if entry.slots.has("7"):
			target = entry
			break
	check(not target.is_empty(), "a listed backup holds slot 7")
	var row_index := backups.find(target)
	var toggles := _buttons(screen, "ดูตัวละคร")
	check(toggles.size() == backups.size(), "every row has a toggle")
	toggles[row_index].pressed.emit()
	await get_tree().process_frame
	var per_slot := _buttons(screen, "กู้คืนช่องนี้")
	check(per_slot.size() == target.slots.size(), "the open row shows one restore button per hero (%d)" % per_slot.size())
	check(_buttons(screen, "ซ่อน").size() == 1, "the open row can fold again")
	var keys: Array = target.slots.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	var seven := per_slot[keys.find("7")]
	Game.delete_save(7)
	seven.pressed.emit()
	check(seven.text == "แตะอีกครั้งเพื่อยืนยัน" and not Game.has_save(7) and restored[0] == 0, "the first tap only arms the button")
	seven.pressed.emit()
	await get_tree().process_frame
	check(Game.has_save(7) and restored[0] == 1, "the second tap restores slot 7 and emits restored")
	check(screen._status.text == "กู้คืนจุด 7 แล้ว", "status line: %s" % screen._status.text)
	check(screen._box.get_child_count() == SaveBackup.list().size(), "the list is rebuilt after the restore")
	var now_count := SaveBackup.list().size()
	_buttons(screen, "สำรองตอนนี้")[0].pressed.emit()
	await get_tree().process_frame
	check(SaveBackup.list().size() <= now_count + 1 and _count("manual") >= 1 and screen._status.text == "สำรองแล้ว", "สำรองตอนนี้ makes a manual backup")
	screen.close_screen()
	check(not screen._root.visible and screen._box.get_child_count() == 0, "a closed screen keeps nothing")
	screen.queue_free()
