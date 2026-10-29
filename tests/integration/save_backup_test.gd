extends Node
## SaveBackup: a backup copies every slot and writes its index, list() is newest first,
## pruning keeps 7 daily + 3 manual, a restore refuses a corrupted copy and puts a good
## one back after a "before-restore" backup, and maybe_daily runs once per day.
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
	SaveBackup.reset_daily_cache()
	_test_daily()
	_test_copy_and_index()
	_test_order_and_prune()
	_test_restore()
	print("SAVE BACKUP: %d checks, %d failures" % [checks, failures])
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
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
	check(dir.begins_with(SaveBackup.ROOT + "/") and dir.get_file().ends_with("-manual"), "backup folder named <stamp>-<reason>: %s" % dir)
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
	print("DEBUG dailies: ", dailies)
	for e in listed:
		print("DEBUG listed: ", e.dir, " ", e.reason)
	for i in range(1, listed.size()):
		check(listed[i - 1].dir > listed[i].dir, "list is newest first (%s before %s)" % [listed[i - 1].dir.get_file(), listed[i].dir.get_file()])
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
	# The good copy comes back, after a before-restore backup of the changed hero.
	var changed := FileAccess.get_file_as_string(Game.save_path(3))
	check(SaveBackup.restore(good, 3), "a valid backup restores")
	check(FileAccess.get_file_as_string(Game.save_path(3)) == before, "slot 3 holds the backed-up bytes again")
	check(Game.slot_info(3).level == 12 and Game.slot_info(3).name == "จอมเวทสำรอง", "the restored hero reads back")
	check(_count("before-restore") == 1, "a before-restore backup was made")
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
	check(SaveBackup.restore_all(good), "restore_all of a valid backup")
	check(Game.has_save(1) and Game.has_save(3) and Game.has_save(7), "restore_all brought the deleted heroes back")
	check(Game.slot_info(7).level == 20, "slot 7 restored")
	check(FileAccess.get_file_as_string(Game.save_path(9)) == nine, "a slot the backup lacks is left as it is")
	check(not SaveBackup.restore_all(broken), "restore_all refuses a backup with a corrupted slot")
	check(not SaveBackup.restore_all("user://backups/missing-folder"), "restore_all of a missing folder is refused")
