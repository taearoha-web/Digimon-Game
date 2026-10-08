extends Node
## Run with an isolated user directory:
## XDG_DATA_HOME=/tmp/toon-save-tests godot --headless --path . res://tests/integration/save_progression_test.tscn

var failures := 0
var checks := 0


func _ready() -> void:
	Game.set_process(false)
	Game.slot = 1
	Game.new_profile(&"warrior", "ผู้พิทักษ์ทดสอบ", FaceKit.default_look())
	_test_invalid_backups()
	_test_import_destinations()
	_test_write_failures()
	_test_progression()
	_test_quest_rewards()
	_test_settings()
	print("SAVE / PROGRESSION: %d checks, %d failures" % [checks, failures])
	Game.has_profile = false
	get_tree().quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func code(data: Dictionary) -> String:
	return Marshalls.utf8_to_base64(JSON.stringify(data))


func _test_invalid_backups() -> void:
	var original := Game.profile.duplicate(true)
	var disk_before := FileAccess.get_file_as_string(Game.save_path(1))
	var malformed: Array = []
	for change in [
		{"class": "missing_class"}, {"level": -1}, {"level": 101}, {"level": "40"},
		{"gold": -50}, {"hp": []}, {"attrs": {"str": {}}}, {"skills": {"slash": []}},
		{"equip": {"weapon": null}}, {"inv": ["not an item"]}, {"storage": [42]},
		{"loadout": [{}]}, {"quests": {"slimes": "done"}}, {"quests": {"slimes": {"progress": []}}},
		{"paragon": {"alloc": []}}, {"paragon": {"level": 201}}, {"paragon": {"alloc": {"atk": 61}}},
		{"party": [{"class": "missing"}]}, {"party": [1]}, {"daily": {"quests": {}}},
		{"daily": {"quests": [{"id": "missing"}]}}, {"look": {"skin": []}},
		{"flags": {"kills": []}}, {"pvp": {"wins": "ten"}}, {"ach": {"first_blood": []}},
		{"spawn_override": []},
	]:
		var broken := original.duplicate(true)
		broken.merge(change, true)
		malformed.append(broken)
	for bad_item in [
		{"kind": "potion", "id": "missing", "count": 1},
		{"kind": "gem", "id": "ruby_broken", "count": 1},
		{"kind": "gem", "id": "ruby_0", "count": -1},
		{"kind": "potion", "id": "hp_s", "count": 1, "stats": {"atk": []}},
		{"kind": "potion", "id": "hp_s", "count": 1, "level": []},
		{"kind": "gem", "id": "ruby_0", "count": 1, "price": {}},
	]:
		var broken := original.duplicate(true)
		broken.inv = [bad_item]
		malformed.append(broken)
	var broken_gear := original.duplicate(true)
	broken_gear.equip.weapon.stats = {"atk": {}}
	malformed.append(broken_gear)
	for broken in malformed:
		check(Game.preview_import(code(broken)).is_empty(), "malformed preview is rejected")
		check(not Game.import_code(code(broken)), "malformed import is rejected")
		check(Game.profile == original and Game.slot == 1, "invalid import preserves active profile")
	check(not Game.import_code("not a save"), "invalid base64 rejected")
	check(FileAccess.get_file_as_string(Game.save_path(1)) == disk_before, "invalid imports preserve saved file")
	check(Game.preview_import(code({"class": "mage", "level": 7})).level == 7, "minimal legacy profile repairs missing optional fields")
	check(Game.save_code_roundtrip(), "new profile roundtrip compares actual data")
	var imported := [0]
	var watch_import := func(): imported[0] += 1
	Game.profile_imported.connect(watch_import)
	Game.current_zone = &"snow"
	var pure_before := Game.profile.duplicate(true)
	check(Game.save_code_roundtrip() and imported[0] == 0, "roundtrip validation does not request live scene reload")
	check(Game.profile == pure_before and FileAccess.get_file_as_string(Game.save_path(1)) == disk_before, "export and roundtrip leave profile and saved file unchanged")
	Game.current_zone = &"town"
	Game.profile_imported.disconnect(watch_import)
	var veteran := original.duplicate(true)
	veteran.flags = {"arena_day": GoalsData.today(), "daily_last": GoalsData.today(), "arena_clears": 5}
	veteran.party = [{"class": "priest", "name": "เพื่อน", "level": 1, "mp_potions": 3}]
	check(not Game.preview_import(code(veteran)).is_empty(), "existing arena dates and companion stock are compatible")


func _test_import_destinations() -> void:
	var incoming := Game.profile.duplicate(true)
	incoming["name"] = "นักเดินทางนำเข้า"
	incoming["zone"] = "snow"
	incoming["hp"] = 999999
	incoming["mp"] = 999999
	var original := Game.profile.duplicate(true)
	var previous_file := FileAccess.get_file_as_string(Game.save_path(1))
	check(Game.preview_import(code(incoming)).zone == "snow", "preview reports destination zone")
	check(Game.profile == original, "preview leaves current profile intact")
	check(not Game.import_code(code(incoming), 5), "out-of-range destination refused")
	check(Game.import_code(code(incoming), 2), "backup imports into chosen slot")
	check(Game.slot == 2 and Game.current_zone == &"snow" and Game.profile.zone == "snow", "import restores matching zone and destination")
	check(int(Game.profile.hp) == int(Game.stats_now().max_hp) and int(Game.profile.mp) == int(Game.stats_now().max_mp), "import clamps vitals")
	check(FileAccess.get_file_as_string(Game.save_path(1)) == previous_file, "importing another slot preserves original slot")
	check(Game.slot_profile_preview(1).equip.has("weapon") and Game.slot == 2, "cosmetic preview leaves active slot intact")
	incoming.zone = "pvp"
	check(Game.import_code(code(incoming), 2) and Game.current_zone == &"town", "duel import safely resumes in town")
	incoming.zone = "unknown_zone"
	check(Game.import_code(code(incoming), 2) and Game.profile.zone == "town", "obsolete zone falls back to town")
	check(Game.load_game(1) and Game.profile.name == original.name, "original save loads after other-slot import")


func _test_write_failures() -> void:
	var dir := DirAccess.open("user://")
	var temp_name := Game.save_path().get_file() + ".tmp"
	check(dir.make_dir(temp_name) == OK, "test creates a blocked temporary path")
	var disk_before := FileAccess.get_file_as_string(Game.save_path())
	Game.profile.gold += 321
	Game.mark_dirty()
	check(not Game.save() and Game._dirty, "failed write retains pending changes")
	check(FileAccess.get_file_as_string(Game.save_path()) == disk_before, "failed write preserves previous good file")
	var incoming := Game.profile.duplicate(true)
	incoming.name = "must not replace"
	var before := Game.profile.duplicate(true)
	check(not Game.import_code(code(incoming)), "failed import write reports failure")
	check(Game.profile == before and Game._dirty, "failed import write preserves active state")
	dir.remove(temp_name)
	check(Game.save() and not Game._dirty, "retry succeeds and clears dirty flag")
	before = Game.profile.duplicate(true)
	var target_name := Game.save_path(4).get_file()
	if FileAccess.file_exists(Game.save_path(4)):
		dir.remove(target_name)
	check(dir.make_dir(target_name) == OK, "test blocks atomic rename destination")
	check(not Game.import_code(code(incoming), 4), "rename failure reports failed import")
	check(Game.slot == 1 and Game.profile == before, "rename failure does not switch hero or slot")
	dir.remove(target_name)
	dir.remove(target_name + ".tmp")


func _test_progression() -> void:
	Game.new_profile(&"warrior", "ดาวทดสอบ")
	Game.profile.level = 99
	Game.profile.exp = 0
	Game.add_exp(HeroStats.exp_to_next(99) + 321)
	check(Game.profile.level == 100 and Game.profile.exp == 0, "level cap clears regular EXP")
	check(int(Game.paragon().exp) == 321, "crossing reward transfers exact overflow into Paragon")
	var paragon_need := Game.paragon_need()
	Game.add_exp(paragon_need - 321)
	check(int(Game.paragon().level) == 1 and int(Game.paragon().exp) == 0, "transferred EXP contributes to next Paragon level")
	var before := Game.profile.duplicate(true)
	Game.add_exp(-100)
	check(Game.profile == before, "negative EXP is ignored")
	Game.paragon().level = Game.PARAGON_MAX - 1
	Game.paragon().exp = 0
	Game.add_exp(Game.paragon_need() + 1000)
	check(int(Game.paragon().level) == Game.PARAGON_MAX and int(Game.paragon().exp) == 0, "Paragon cap does not retain unusable EXP")
	var legacy := Game.profile.duplicate(true)
	legacy.paragon = {}
	legacy.exp = 900
	var migrated := Game._decode_import(code(legacy))
	check(migrated.exp == 0 and int(migrated.paragon.exp) == 900, "legacy stranded EXP is recovered")
	check(Game.save_code_roundtrip(), "Paragon profile survives roundtrip")


func _test_quest_rewards() -> void:
	check(QuestData.get_quest("slimes").exp == 90 and QuestData.get_quest("mush_king").gold == 900, "introductory quest rewards preserved")
	for id in QuestData.ORDER:
		var quest := QuestData.get_quest(id)
		if int(quest.level) <= 6:
			continue
		var level := int(quest.level)
		var exp_left := int(quest.exp)
		while level < 100 and exp_left >= HeroStats.exp_to_next(level):
			exp_left -= HeroStats.exp_to_next(level)
			level += 1
		check(level - int(quest.level) <= 1, "quest %s does not skip progression tiers" % id)
		check(int(quest.gold) > 0 and int(quest.gold) <= 100000, "quest %s gold stays within late-game upgrade economy" % id)
	check(QuestData.get_quest("abyss_dragon").exp < HeroStats.exp_to_next(100) * 2, "final reward earns bounded Paragon EXP")


func _test_settings() -> void:
	var file := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"quality": {}, "camera_speed": "bad", "vibration": []}))
	file.close()
	GameSettings._loaded = false
	GameSettings.quality = -1
	GameSettings.camera_speed = 1.0
	GameSettings.vibration = true
	GameSettings.load_settings()
	check(GameSettings.quality in [1, 2] and GameSettings.camera_speed == 1.0 and GameSettings.vibration, "malformed settings fall back to usable defaults")
