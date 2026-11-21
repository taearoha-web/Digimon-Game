extends Node
## The world reopening (Sunday 22 Nov 2026, 06:00 Thai time: WorldPlayers.START_UNIX =
## Game.WORLD_EPOCH), the owner's fresh start:
## - a device save from before it (no "world_epoch", or an older one) loses every character,
##   the shared storage (คลัง: items, its migration record), the daily backups, the cached
##   league rounds and dungeon times; the settings and the last-slot record stay; the title
##   then has no hero and offers "+ สร้างตัวละคร" first, with the one-time notice;
## - an online save installed at login (the web page writes the slot files before the game
##   starts) is wiped the same way on the next start, and the emptied set goes up;
## - a new character, the storage file and the cloud bundle carry the epoch; a save code or
##   a backup of an old character is refused;
## - the world: exactly the ROSTER's 100 players, no daily newcomers, everyone Lv.1 with no
##   guild at the reopening and nobody online before it; no league round, frozen result or
##   maze week from before it.
##   godot --headless --path . res://tests/integration/world_reopen_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	var started := Time.get_ticks_msec()
	WorldPlayers.persist = false
	_epoch_constants()
	_local_wipe()
	await _title_after_wipe()
	_cloud_install_wipe()
	_new_save_carries_epoch()
	_old_codes_and_backups()
	_world_players()
	_league_and_maze()
	print("WORLD_REOPEN: %s | %d checks, %d failures (%d ms)" % ["PASS" if failures == 0 else "FAIL", checks, failures, Time.get_ticks_msec() - started])
	get_tree().quit(0 if failures == 0 else 1)


func _write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## A character as an older build saved it (no world_epoch), level and gold of a veteran.
func _old_hero(hero_name: String, cls := "warrior", level := 80) -> Dictionary:
	# new_profile saves the hero in Game.slot: a spare slot, emptied again below.
	var was := Game.slot
	var had := Game.has_save(Game.SLOT_COUNT)
	Game.slot = Game.SLOT_COUNT
	Game.new_profile(StringName(cls), hero_name)
	Game.slot = was
	if not had:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path(Game.SLOT_COUNT)))
	var p: Dictionary = Game.profile.duplicate(true)
	p.erase("world_epoch")
	p["level"] = level
	p["gold"] = 987654
	p["rshop"] = {"lc": 500, "ep": 300}
	p["saved_at"] = int(Time.get_unix_time_from_system()) - 3600
	Game.has_profile = false
	Game.profile = {}
	return p


func _epoch_constants() -> void:
	check(WorldPlayers.START_UNIX == 1795302000, "the reopening is 22 Nov 2026 06:00 Thai (%d)" % WorldPlayers.START_UNIX)
	check(Game.WORLD_EPOCH == WorldPlayers.START_UNIX, "the save epoch is the world's opening")
	var thai := Time.get_datetime_dict_from_unix_time(WorldPlayers.START_UNIX + WorldPlayers.TZ)
	check(int(thai.year) == 2026 and int(thai.month) == 11 and int(thai.day) == 22 and int(thai.hour) == 6 and int(thai.minute) == 0, "06:00 Thai time, 22 Nov (%s)" % str(thai))


## The device as an older build left it: characters, the shared storage, backups, the
## league and dungeon caches, settings.
func _old_device() -> void:
	_write(Game.save_path(1), _old_hero("OldKnight"))
	_write(Game.save_path(2), _old_hero("OldMage", "mage", 60))
	var older := _old_hero("OlderEpoch", "priest", 40)
	older["world_epoch"] = 1793274300
	_write(Game.save_path(3), older)
	_write(SharedStorage.PATH, {"version": 1, "items": [ItemData.potion("hp_s", 30), {"kind": "costume", "id": "sakura", "rarity": 1}], "migrated": {"abc": 1}})
	SaveBackup.backup_now("daily")
	DirAccess.make_dir_recursive_absolute(SaveBackup.ROOT)
	_write(LeagueRounds.PATH, {"official": {}, "seen": {}})
	_write(DungeonRanking.PATH, {"local": {}})
	_write(Game.META_PATH, {"slot": 2})
	GameSettings.save_settings()
	# The device has not seen this reopening yet.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.REOPEN_PATH))


func _local_wipe() -> void:
	_old_device()
	check(Game.has_save(1) and Game.has_save(2) and Game.has_save(3), "the old characters are on the device")
	check(DirAccess.dir_exists_absolute(SaveBackup.ROOT) and not SaveBackup.list().is_empty(), "with a daily backup of them")
	var settings_before := FileAccess.get_file_as_string(GameSettings.PATH)
	var removed := Game.reopen_world()
	SharedStorage.read_file()
	check(removed == 3, "every character from before the reopening removed (%d)" % removed)
	check(not Game.any_save() and Game.free_slot() == 1, "no character left; the first slot is free")
	check(SharedStorage.size() == 0 and SharedStorage.migrated().is_empty(), "the shared storage is emptied (items and record)")
	check(not DirAccess.dir_exists_absolute(SaveBackup.ROOT), "the daily backups of the old characters are gone")
	check(not FileAccess.file_exists(LeagueRounds.PATH) and not FileAccess.file_exists(DungeonRanking.PATH), "the league and dungeon caches are gone")
	check(FileAccess.file_exists(GameSettings.PATH) and FileAccess.get_file_as_string(GameSettings.PATH) == settings_before, "the settings stay")
	check(FileAccess.file_exists(Game.META_PATH), "the last-slot record stays")
	var record := Game.reopen_record()
	check(int(record.get("epoch", 0)) == Game.WORLD_EPOCH and int(record.get("removed", 0)) == 3, "the device keeps a record of its reopening (%s)" % str(record))
	var bundle := Game.build_cloud_bundle()
	check((bundle.slots as Dictionary).is_empty() and (bundle.storage as Array).is_empty() and int(bundle.storageEpoch) == Game.WORLD_EPOCH, "the set that goes up is empty and current (%s)" % JSON.stringify(bundle))
	check(Game.cloud_bundle_json().contains("\"storageEpoch\":%d" % Game.WORLD_EPOCH), "the cached cloud text carries the storage epoch")
	# Once is enough: a second start removes nothing more.
	check(Game.reopen_world() == 0, "a second start removes nothing")


func _title_after_wipe() -> void:
	var notice := Game.reopen_notice()
	check(notice.contains("โลกเปิดใหม่") and notice.contains("รีเซ็ต"), "the one-time notice (%s)" % notice)
	var menu := MainMenu.new()
	add_child(menu)
	await get_tree().process_frame
	var label: Label = menu.reopen_label
	check(label != null and label.visible and label.text.contains("โลกเปิดใหม่"), "the title shows the notice (%s)" % (label.text if label else "none"))
	var create := menu.find_child("CreateButton", true, false) as Button
	var play := menu.find_child("PlayButton", true, false) as Button
	check(create != null and not create.disabled and create.theme_type_variation == &"PrimaryButton", "character creation comes first")
	check(play != null and not play.visible, "no hero to play")
	menu.queue_free()
	await get_tree().process_frame
	check(Game.reopen_notice() == "", "the notice is shown once")
	var menu2 := MainMenu.new()
	add_child(menu2)
	await get_tree().process_frame
	var again: Label = menu2.reopen_label
	var countdown := Game.reopen_countdown()
	check(not again.text.contains("รีเซ็ต") and again.text == countdown, "the next title has only the countdown (%s)" % again.text)
	menu2.queue_free()
	await get_tree().process_frame
	check(Game.reopen_countdown(float(Game.WORLD_EPOCH) - 3600.0 * 2.5).contains("06:00") and Game.reopen_countdown(float(Game.WORLD_EPOCH) - 3600.0 * 2.5).contains("2 ชม. 30"), "a countdown before 06:00")
	check(Game.reopen_countdown(float(Game.WORLD_EPOCH) + 1.0) == "", "no countdown once the world is open")


## The web page installs the online save as slot files before the game starts (accounts.js
## installBundle): an online save from before the reopening on a device that already
## reopened (another device logged in later, an old cached copy) goes on the next start.
func _cloud_install_wipe() -> void:
	_write(Game.save_path(1), _old_hero("CloudOld"))
	var fresh := _old_hero("CloudNew", "archer", 5)
	fresh["world_epoch"] = Game.WORLD_EPOCH
	_write(Game.save_path(4), fresh)
	_write(SharedStorage.PATH, {"version": 1, "items": [ItemData.potion("hp_s", 3)], "migrated": {}})
	SharedStorage.read_file()
	check(SharedStorage.size() == 0, "a storage file without the epoch reads as empty")
	var removed := Game.reopen_world()
	SharedStorage.read_file()
	check(removed == 1 and not Game.has_save(1), "the old online character is removed at the next start")
	check(Game.has_save(4) and String(Game.slot_info(4).name) == "CloudNew", "a character of the reopened world stays")
	check(not FileAccess.file_exists(SharedStorage.PATH) and SharedStorage.size() == 0, "the old storage file is removed")
	check(int(Game.reopen_record().get("removed", 0)) == 4, "the record counts it")
	Game.delete_save(4)


func _new_save_carries_epoch() -> void:
	Game.slot = 1
	Game.new_profile(&"mage", "NewWorld")
	check(int(Game.profile.world_epoch) == Game.WORLD_EPOCH, "a new character belongs to the reopened world")
	check(Game.save(), "it saves")
	var saved: Variant = _read(Game.save_path(1))
	check(saved is Dictionary and int(saved.world_epoch) == Game.WORLD_EPOCH, "its file carries the epoch")
	check(SharedStorage.put(ItemData.potion("hp_s", 2)) and SharedStorage.store(), "a deposit")
	var shared: Variant = _read(SharedStorage.PATH)
	check(shared is Dictionary and int(shared.epoch) == Game.WORLD_EPOCH, "the storage file carries the epoch")
	check(Game.reopen_world() == 0 and Game.has_save(1) and SharedStorage.file_epoch() == Game.WORLD_EPOCH, "a current character and storage are never removed")
	SharedStorage.read_file()
	check(SharedStorage.size() == 1, "the deposit is still there")
	var bundle := Game.build_cloud_bundle()
	check(int((bundle.slots as Dictionary)["1"].world_epoch) == Game.WORLD_EPOCH and int(bundle.storageEpoch) == Game.WORLD_EPOCH, "the cloud bundle carries the epoch")
	check(Game.load_game(1) and Game.has_profile and String(Game.profile.name) == "NewWorld", "it loads")


func _old_codes_and_backups() -> void:
	var code := Game.export_code()
	check(Game.preview_import(code).get("name", "") == "NewWorld", "a code of the reopened world imports")
	var old := _old_hero("CodeOld")
	var old_code := Marshalls.utf8_to_base64(JSON.stringify(old))
	check(Game.preview_import(old_code).is_empty() and not Game.import_code(old_code, 5), "a save code of an old character is refused")
	check(not Game.has_save(5), "nothing written for it")
	Game.load_game(1)
	# A backup folder holding an old character (from another device) is refused.
	var dir := SaveBackup.backup_now("manual")
	check(dir != "", "a backup of the new character")
	_write(dir.path_join(Game.save_path(6).get_file()), _old_hero("BackupOld"))
	check(not SaveBackup.restore(dir, 6) and not Game.has_save(6), "an old character in a backup never comes back")
	check(SaveBackup.restore(dir, 1), "the new character's backup restores")


func _world_players() -> void:
	WorldPlayers.reset_roster()
	var start := float(WorldPlayers.START_UNIX)
	check(WorldPlayers.ROSTER.size() == 100, "the ROSTER holds 100 players (%d)" % WorldPlayers.ROSTER.size())
	check(WorldPlayers.NEWCOMER_MAX == 0, "daily newcomers are off")
	WorldPlayers.ensure_until(start + 400.0 * DAY)
	check(WorldPlayers._all.size() == 100, "a year on, still exactly 100 world players (%d)" % WorldPlayers._all.size())
	var newcomer := false
	var names := {}
	for i in WorldPlayers._all.size():
		newcomer = newcomer or WorldPlayers.is_newcomer(i)
		names[String(WorldPlayers.entry(i).name)] = true
	check(not newcomer and names.size() == 100, "no newcomer, 100 different names")
	var lv1 := 0
	var guildless := 0
	var online_before := 0
	for i in 100:
		var s := WorldPlayers.state(i, start)
		if int(s.level) == 1:
			lv1 += 1
		if int(s.guild) == 0:
			guildless += 1
		if bool(WorldPlayers.state(i, start - 600.0).online):
			online_before += 1
	check(lv1 == 100, "everyone is Lv.1 at the reopening (%d)" % lv1)
	check(guildless == 100, "nobody is in a guild at the reopening (%d)" % guildless)
	check(online_before == 0, "nobody is online before 06:00 (%d)" % online_before)
	check(WorldPlayers.where_text(WorldPlayers.state(0, start - 600.0), start - 600.0) == "รอเปิดโลก", "the roster says the world is not open yet")
	var online_after := 0
	for i in 100:
		if bool(WorldPlayers.state(i, start + 0.5 * DAY).online):
			online_after += 1
	check(online_after > 0, "players are online once it is open (%d at 18:00)" % online_after)


func _league_and_maze() -> void:
	var start := WorldPlayers.START_UNIX
	var first := GuildLeague.next_slot(float(start) - 1.0)
	check(first >= start and GuildLeague.is_round(first), "the first league round is after the reopening (%d)" % first)
	check(GuildLeague.holder_after(first - 1) == 0, "nobody holds the castle before the first round")
	check(not GuildLeague.is_round(1795240800) or 1795240800 >= start, "the extra round of 21 Nov was before it")
	check(LeagueRounds.clean(start - 3600, {"at": start - 3600, "g": [1, 2, 3, 4], "k": [0, 0, 0, 0], "c": [0, 0, 0, 0], "held": 1, "own": 0}).is_empty(), "a round result from before the reopening is never taken")
	check(LeagueRounds.adopt(start - 3600, {"at": start - 3600, "g": [1, 2, 3, 4], "k": [0, 0, 0, 0], "c": [0, 0, 0, 0], "held": 1, "own": 0}) == false, "nor adopted from the server")
	check(MazeWar.OPEN_UNIX == start, "the maze war starts at the reopening")
	var week := MazeWar.week_of(float(start))
	MazeWar.ai_mode = 1
	check(MazeWar.sim_kills(week, float(start)).is_empty(), "no maze kills at the reopening")
	check(MazeWar.champion(week - 1).is_empty(), "no maze champion of the week before")
	MazeWar.ai_mode = -1
