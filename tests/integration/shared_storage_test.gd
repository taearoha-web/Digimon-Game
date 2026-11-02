extends Node
## The storage every hero shares (SharedStorage): a deposit by one hero is seen by
## another, gear of another class stays (greyed out in the storage screen with
## "อาชีพอื่น ใช้ไม่ได้") while jewels, potions and gear for any class go to anyone,
## Game.give_or_store fills it, it survives saving, loading and deleting heroes, rides
## in the cloud bundle, and the old per-hero storages move in once: nothing lost, nothing
## doubled on a second load, a restored old backup or an old save code imported again.
## Run with an isolated user directory:
## XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/shared_storage_test.tscn

var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
		print("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	rng.seed = 20261102
	_reset()
	_test_capacity_choice()
	_test_shared_between_heroes()
	await _test_class_lock_and_screen()
	_test_give_or_store()
	_test_round_trip_and_cloud()
	_test_delete_keeps_storage()
	_test_migration()
	_test_overflow_migration()
	_test_backups()
	print("SHARED STORAGE: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	Game.has_profile = false
	get_tree().quit(0 if failures == 0 else 1)


## No hero, an empty shared storage and no record.
func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()


func _hero(slot: int, cls: StringName, hero_name: String) -> void:
	Game.slot = slot
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile["level"] = 60


func _count(id: String) -> int:
	var n := 0
	for item in SharedStorage.items():
		if item.get("id", "") == id:
			n += int(item.get("count", 1))
	return n


func _index_of_uid(uid: String) -> int:
	for i in SharedStorage.items().size():
		if String(SharedStorage.items()[i].get("uid", "")) == uid:
			return i
	return -1


func _bag_has_uid(uid: String) -> bool:
	return Game.profile.inv.any(func(item): return String(item.get("uid", "")) == uid)


func _test_capacity_choice() -> void:
	check(Game.STORAGE_SIZE == SharedStorage.SIZE and SharedStorage.SIZE >= 120 and SharedStorage.SIZE <= 160, "the shared storage holds %d" % SharedStorage.SIZE)
	check(Game.LEGACY_STORAGE_SIZE == 80 and SharedStorage.MAX_ITEMS == SharedStorage.SIZE + Game.SLOT_COUNT * Game.LEGACY_STORAGE_SIZE, "old storages: 80 each, the hard cap fits ten of them over a full shared one")
	var old := {"class": "mage", "level": 10, "storage": []}
	for i in Game.LEGACY_STORAGE_SIZE:
		old.storage.append(ItemData.potion("hp_s", 1))
	check(Game._valid_profile(old), "an old save with a full old storage (80) still loads")
	old.storage.append(ItemData.potion("hp_s", 1))
	check(not Game._valid_profile(old), "an old storage past 80 is refused as before")


## A deposit by the warrior in slot 1 is in the archer's storage in slot 2.
func _test_shared_between_heroes() -> void:
	print("== Deposit on one hero, visible on another")
	_hero(1, &"warrior", "นักรบคลัง")
	Game.profile.inv.clear()
	Game.add_item(ItemData.jewel("chaos", 3))
	Game.add_item(ItemData.potion("hp_s", 5))
	var warrior_blade := ItemData.generate(40, &"warrior", rng, 2, "weapon")
	var archer_bow := ItemData.generate(40, &"archer", rng, 2, "weapon")
	var any_armor := ItemData.generate(40, &"warrior", rng, 1, "armor")
	check(String(any_armor.get("class", "x")) == "", "plain armour has no class lock")
	for item in [warrior_blade, archer_bow, any_armor]:
		Game.add_item(item)
	var bag: int = Game.profile.inv.size()
	while not Game.profile.inv.is_empty():
		var named := ItemData.name_of(Game.profile.inv[0])
		check(Game.deposit_item(0), "the warrior deposits %s" % named)
	check(SharedStorage.size() == bag and _count("chaos") == 3 and _count("hp_s") == 5, "five entries in the shared storage")
	check(Game.save(), "the warrior saves")
	_hero(2, &"archer", "นักธนูคลัง")
	check(Game.storage().size() == bag and _index_of_uid(warrior_blade.uid) >= 0, "the archer sees the warrior's deposit")
	SharedStorage.read_file()
	check(Game.storage().size() == bag and _index_of_uid(archer_bow.uid) >= 0 and _count("chaos") == 3, "and so does a fresh read of the file")
	Game.add_item(ItemData.jewel("chaos", 2))
	var at: int = Game.profile.inv.size() - 1
	check(Game.deposit_item(at) and _count("chaos") == 5 and SharedStorage.size() == bag, "the archer deposits too; jewels join the warrior's pile")


## Gear of another class stays; jewels, potions and gear for any class go to anyone.
func _test_class_lock_and_screen() -> void:
	print("== Class-locked gear stays, the rest is withdrawn by anyone")
	var warrior_set := SetGearData.item("warrior", "helm")
	var warrior_divine := DivineGearData.item(&"warrior", "armor", rng)
	var warrior_wings := StarWingData.item("warrior", rng, 3)
	var warrior_boots := StarProgression.item(&"warrior", 100, "boots", rng)
	for piece in [warrior_set, warrior_divine, warrior_wings, warrior_boots]:
		SharedStorage.put(piece)
	SharedStorage.store()
	check(Game.class_id() == &"archer", "the archer is playing")
	for i in SharedStorage.size():
		var item: Dictionary = SharedStorage.items()[i]
		var locked := SharedStorage.gear_class(item) not in ["", "archer"]
		check((Game.storage_lock(item) != "") == locked, "%s: locked %s" % [ItemData.name_of(item), locked])
	check(Game.storage_lock(warrior_set) == "อาชีพอื่น ใช้ไม่ได้", "the note reads อาชีพอื่น ใช้ไม่ได้")
	for piece in [warrior_set, warrior_divine, warrior_wings, warrior_boots]:
		check(Game.storage_lock(piece) != "" and Game.equip_problem(piece) != "", "%s is refused as the game refuses to wear it" % ItemData.name_of(piece))
	# The screen: greyed rows with the note and a disabled button for the warrior's gear.
	var screen := StorageScreen.new()
	add_child(screen)
	screen.open_storage()
	await get_tree().process_frame
	var rows := screen._store_box.get_children()
	check(rows.size() == SharedStorage.size(), "one row per shared entry (%d)" % rows.size())
	var greyed := 0
	for i in rows.size():
		var row := rows[i] as Control
		var item: Dictionary = SharedStorage.items()[i]
		var button := row.find_children("*", "Button", true, false)[0] as Button
		var text := " ".join(row.find_children("*", "Label", true, false).map(func(label): return (label as Label).text))
		if Game.storage_lock(item) != "":
			greyed += 1
			check(button.disabled and row.self_modulate == StorageScreen.LOCKED_TINT and text.contains("อาชีพอื่น ใช้ไม่ได้") and text.contains("สายดาบ"), "greyed row for %s: %s" % [ItemData.name_of(item), text])
		else:
			check(not button.disabled and row.self_modulate == Color.WHITE and not text.contains("อาชีพอื่น"), "open row for %s" % ItemData.name_of(item))
	check(greyed == 5, "five warrior pieces greyed out (%d)" % greyed)
	check(screen._store_title.text.contains("คลังรวม"), "the title says the storage is shared: %s" % screen._store_title.text)
	# Pressing a greyed row's button does nothing: the item stays.
	var before := SharedStorage.size()
	var locked_index := -1
	for i in SharedStorage.size():
		if Game.storage_lock(SharedStorage.items()[i]) != "":
			locked_index = i
			break
	check(locked_index >= 0 and not Game.withdraw_item(locked_index) and SharedStorage.size() == before, "withdrawing the warrior's gear is refused")
	# Jewels, potions, plain armour and the archer's own bow come out.
	for id in ["chaos", "hp_s"]:
		var index := -1
		for i in SharedStorage.size():
			if SharedStorage.items()[i].get("id", "") == id:
				index = i
		var had := int(SharedStorage.items()[index].count)
		check(Game.withdraw_item(index) and _count(id) == 0 and Game.profile.inv.any(func(item): return item.get("id", "") == id and int(item.count) >= had), "the archer takes the %s" % id)
	for i in range(SharedStorage.size() - 1, -1, -1):
		var item: Dictionary = SharedStorage.items()[i]
		if Game.storage_lock(item) == "":
			var uid := String(item.get("uid", ""))
			check(Game.withdraw_item(i) and _bag_has_uid(uid) and _index_of_uid(uid) == -1, "the archer takes %s" % ItemData.name_of(item))
	check(SharedStorage.size() == 5 and SharedStorage.items().all(func(item): return SharedStorage.gear_class(item) == "warrior"), "only the warrior's gear is left")
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(SharedStorage.PATH))
	check(on_disk is Dictionary and (on_disk.items as Array).size() == 5, "every change is written to the file at once")
	screen.close_storage()
	screen.queue_free()
	# The warrior takes their own gear back.
	check(Game.save(), "the archer saves")
	check(Game.load_game(1) and Game.class_id() == &"warrior", "back to the warrior")
	check(Game.storage().all(func(item): return Game.storage_lock(item) == ""), "nothing is locked for the warrior")
	check(Game.withdraw_item(0) and SharedStorage.size() == 4, "the warrior takes gear out")
	# Deposits work from any hero, of any item: the warrior deposits the archer's bow.
	Game.add_item(ItemData.generate(30, &"archer", rng, 0, "weapon"))
	check(Game.deposit_item(Game.profile.inv.size() - 1) and SharedStorage.size() == 5, "the warrior deposits an archer bow")
	check(Game.storage_lock(SharedStorage.items()[-1]) != "", "which the warrior cannot take back")


## A full bag sends rewards to the shared storage; stacks join their pile there.
func _test_give_or_store() -> void:
	print("== give_or_store")
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(5, &"warrior", rng, 0, "boots"))
	var before := SharedStorage.size()
	check(Game.give_or_store(ItemData.jewel("purple", 4)) and _count("purple") == 4 and SharedStorage.size() == before + 1, "a jewel goes to the shared storage")
	check(Game.give_or_store(ItemData.jewel("purple", 6)) and _count("purple") == 10 and SharedStorage.size() == before + 1, "more jewels join the pile")
	var ring := ItemData.generate(20, &"warrior", rng, 1, "ring")
	check(Game.give_or_store(ring) and _index_of_uid(ring.uid) >= 0, "gear goes there too")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(SharedStorage.PATH))
	check(disk is Dictionary and (disk.items as Array).any(func(item): return item.get("uid", "") == ring.uid), "and is written at once")
	while not SharedStorage.full():
		SharedStorage.items().append(ItemData.generate(5, &"warrior", rng, 0, "helm"))
	check(not Game.give_or_store(ItemData.generate(5, &"warrior", rng, 0, "helm")), "bag and storage full: refused")
	check(Game.give_or_store(ItemData.jewel("purple", 1)) and _count("purple") == 11, "a stack still joins its pile when full")
	check(Game.craft_set_piece("ring", 0.0) != "ok", "set crafting refuses with no room anywhere")
	Game.profile.inv.clear()
	while SharedStorage.size() > before + 2:
		SharedStorage.items().pop_back()
	SharedStorage.store()


## Saving, reading the file again and loading a hero keep the storage; the cloud
## bundle carries it as "storage" and "storageMigrated".
func _test_round_trip_and_cloud() -> void:
	print("== Save / load round trip, cloud bundle")
	var snapshot := JSON.stringify(SharedStorage.items())
	check(Game.save(), "saved")
	SharedStorage.read_file()
	check(JSON.stringify(SharedStorage.items()) == snapshot, "the file reads back the same list")
	check(Game.load_game(2) and JSON.stringify(Game.storage()) == snapshot, "loading another hero keeps it")
	var bundle := Game.build_cloud_bundle()
	check(bundle.get("storage") is Array and (bundle.storage as Array).size() == SharedStorage.size() and bundle.get("storageMigrated") is Dictionary, "build_cloud_bundle has the shared storage")
	var text: Variant = JSON.parse_string(Game.cloud_bundle_json())
	check(text is Dictionary and JSON.stringify(text.storage) == JSON.stringify(JSON.parse_string(snapshot)) and (text.slots as Dictionary).size() == 2, "cloud_bundle_json carries it too")
	var slot_text: Variant = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(2)))
	check(slot_text is Dictionary and (slot_text.get("storage", []) as Array).is_empty(), "the hero's own save holds no storage")
	var code := Game.export_code()
	check(not Marshalls.base64_to_utf8(code).contains(String(SharedStorage.items()[0].get("uid", "?"))), "a hero's save code does not carry the shared storage")
	# A damaged file is kept aside and the storage starts empty instead of failing.
	var good := FileAccess.get_file_as_string(SharedStorage.PATH)
	var file := FileAccess.open(SharedStorage.PATH, FileAccess.WRITE)
	file.store_string("{\"items\": [{\"kind\": \"potion\", \"id\": \"nope\"}]}")
	file.close()
	check(not SharedStorage.read_file() and SharedStorage.size() == 0 and FileAccess.file_exists(SharedStorage.BAD_PATH), "a broken file is set aside")
	file = FileAccess.open(SharedStorage.PATH, FileAccess.WRITE)
	file.store_string(good)
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SharedStorage.BAD_PATH))
	var again := SharedStorage.read_file()
	check(again and JSON.stringify(SharedStorage.items()) == snapshot, "the good file reads again")


func _test_delete_keeps_storage() -> void:
	print("== Deleting heroes keeps the storage")
	var snapshot := JSON.stringify(SharedStorage.items())
	Game.delete_save(2)
	check(not Game.has_save(2) and FileAccess.file_exists(SharedStorage.PATH) and JSON.stringify(SharedStorage.items()) == snapshot, "deleting the archer keeps the storage")
	Game.delete_save(1)
	SharedStorage.read_file()
	check(not Game.any_save() and JSON.stringify(SharedStorage.items()) == snapshot, "deleting every hero keeps it on disk")
	check(Game.build_cloud_bundle().storage.size() == SharedStorage.size(), "an account with no hero still sends its storage")
	_hero(3, &"mage", "นักเวทใหม่")
	check(JSON.stringify(Game.storage()) == snapshot, "a new hero finds it")


## Writes [param slot] as a save from before the shared storage, holding [param old].
func _old_save(slot: int, cls: StringName, hero_name: String, old: Array) -> void:
	_hero(slot, cls, hero_name)
	check(Game.save(), "%s saved" % hero_name)
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.save_path(slot)))
	raw["storage"] = old.duplicate(true)
	check(Game._write_profile(raw, slot), "%s written with an old storage of %d" % [hero_name, old.size()])
	Game.has_profile = false


func _test_migration() -> void:
	print("== Old per-hero storages move in once")
	_reset()
	var mage_staff := ItemData.generate(50, &"mage", rng, 3, "weapon")
	var helm := ItemData.generate(50, &"mage", rng, 1, "helm")
	var priest_wand := ItemData.generate(50, &"priest", rng, 2, "weapon")
	_old_save(3, &"mage", "เวทเก่า", [ItemData.potion("hp_s", 4), mage_staff, ItemData.jewel("chaos", 2), helm])
	_old_save(4, &"priest", "บวชเก่า", [ItemData.potion("hp_s", 4), priest_wand, ItemData.jewel("chaos", 1)])
	_old_save(5, &"warrior", "ดาบไม่มีคลัง", [])
	var backups_before := SaveBackup.list().size()
	var moved := SharedStorage.migrate_slots()
	check(moved == 7, "seven old entries move in (%d)" % moved)
	check(_count("hp_s") == 8 and _count("chaos") == 3, "equal stacks of two heroes both count: hp %d, chaos %d" % [_count("hp_s"), _count("chaos")])
	for piece in [mage_staff, helm, priest_wand]:
		check(_index_of_uid(piece.uid) >= 0, "%s moved" % ItemData.name_of(piece))
	check(SharedStorage.size() == 5, "five shared entries (%d)" % SharedStorage.size())
	for slot in [3, 4, 5]:
		var raw := Game._read_slot(slot)
		check(not raw.is_empty() and (raw.get("storage", []) as Array).is_empty(), "slot %d keeps no old storage" % slot)
	check(SaveBackup.list().size() == backups_before + 1 and SaveBackup.list()[0].reason == "before-storage", "a backup is made before the move")
	var snapshot := JSON.stringify(SharedStorage.items())
	check(SharedStorage.migrate_slots() == 0 and JSON.stringify(SharedStorage.items()) == snapshot, "a second pass moves nothing")
	check(Game.load_game(3) and JSON.stringify(Game.storage()) == snapshot, "a second load doubles nothing")
	SharedStorage.read_file()
	check(JSON.stringify(SharedStorage.items()) == snapshot, "the record and items read back from the file")
	# A crash between the storage file and the slot, or a slot restored from a backup
	# made before the update: the old storage is in the slot again. Nothing doubles.
	var raw3 := Game._read_slot(3)
	raw3["storage"] = [ItemData.potion("hp_s", 4), mage_staff.duplicate(true), ItemData.jewel("chaos", 2), helm.duplicate(true)]
	Game._write_profile(raw3, 3)
	check(Game.load_game(3) and JSON.stringify(Game.storage()) == snapshot and (Game.profile.storage as Array).is_empty(), "a restored old slot does not bring its items twice")
	# Another device that migrated the same saves sent its bundle: the same record
	# arrives with the same items, and both old slots again (as an untouched copy).
	var raw4 := Game._read_slot(4)
	raw4["storage"] = [ItemData.potion("hp_s", 4), priest_wand.duplicate(true), ItemData.jewel("chaos", 1)]
	Game._write_profile(raw4, 4)
	raw3["storage"] = [ItemData.potion("hp_s", 4)]
	Game._write_profile(raw3, 3)
	check(SharedStorage.migrate_slots() == 0 and JSON.stringify(SharedStorage.items()) == snapshot, "both old slots at once: still nothing doubled")
	# An old save code (export_code before the update) imported again: same items skipped,
	# a piece never seen before moves in.
	var fresh := ItemData.generate(60, &"mage", rng, 4, "armor")
	Game.load_game(3)
	var old_profile := Game.profile.duplicate(true)
	old_profile["storage"] = [mage_staff.duplicate(true), fresh]
	var code := Marshalls.utf8_to_base64(JSON.stringify(old_profile))
	check(Game.import_code(code, 6), "an old save code imports")
	check(_index_of_uid(fresh.uid) >= 0 and SharedStorage.items().filter(func(item): return item.get("uid", "") == mage_staff.uid).size() == 1, "its new piece moves in, the known staff does not double")
	check((Game._read_slot(6).get("storage", []) as Array).is_empty(), "the imported hero keeps no old storage")
	# Game._ready's pass: a fresh start finds an old slot and moves it.
	var lone := ItemData.generate(30, &"warrior", rng, 0, "weapon")
	_old_save(7, &"warrior", "ดาบเก่า", [lone])
	check(Game.load_game(7) and _index_of_uid(lone.uid) >= 0 and (Game.profile.storage as Array).is_empty(), "loading an old hero moves its storage in")


## Old storages that fill more than the room all move in; deposits wait until it is under.
func _test_overflow_migration() -> void:
	print("== Overflow: nothing lost")
	_reset()
	for i in Game.STORAGE_SIZE:
		SharedStorage.items().append(ItemData.generate(10, &"warrior", rng, 0, "boots"))
	SharedStorage.store()
	var old: Array = []
	for i in Game.LEGACY_STORAGE_SIZE:
		old.append(ItemData.generate(12, &"archer", rng, 0, "helm"))
	_old_save(8, &"archer", "ธนูล้น", old)
	check(SharedStorage.migrate_slots() == Game.LEGACY_STORAGE_SIZE, "all 80 old entries move in")
	check(SharedStorage.size() == Game.STORAGE_SIZE + Game.LEGACY_STORAGE_SIZE, "the storage holds %d over its room of %d" % [SharedStorage.size(), Game.STORAGE_SIZE])
	SharedStorage.read_file()
	check(SharedStorage.size() == Game.STORAGE_SIZE + Game.LEGACY_STORAGE_SIZE, "and the file holds them all")
	check(Game.load_game(8), "the archer loads")
	Game.profile.inv.clear()
	Game.add_item(ItemData.generate(12, &"archer", rng, 0, "ring"))
	check(not Game.deposit_item(0) and Game.profile.inv.size() == 1, "no deposit while over the room")
	check(Game.withdraw_item(SharedStorage.size() - 1) and Game.profile.inv.size() == 2, "withdrawing works")
	# Past the hard cap the rest waits in the hero's old storage for the next load.
	_reset()
	for i in SharedStorage.MAX_ITEMS - 2:
		SharedStorage.items().append(ItemData.generate(10, &"warrior", rng, 0, "boots"))
	SharedStorage.store()
	var five: Array = []
	for i in 5:
		five.append(ItemData.generate(14, &"archer", rng, 0, "helm"))
	_old_save(9, &"archer", "ธนูรอ", five)
	check(SharedStorage.migrate_slots() == 2 and SharedStorage.size() == SharedStorage.MAX_ITEMS, "two move in up to the hard cap")
	check((Game._read_slot(9).storage as Array).size() == 3, "three wait in the hero's old storage")
	for i in 3:
		SharedStorage.items().pop_front()
	SharedStorage.store()
	check(SharedStorage.migrate_slots() == 3 and (Game._read_slot(9).storage as Array).is_empty(), "they move once there is room")
	var uids := {}
	for item in SharedStorage.items():
		uids[String(item.get("uid", ""))] = true
	check(five.all(func(item): return uids.has(item.uid)), "all five arrived, none lost")
	_reset()


## A backup copies the shared storage; restoring one hero leaves it, "restore all" puts
## it back.
func _test_backups() -> void:
	print("== Backups")
	_hero(1, &"warrior", "สำรองคลัง")
	Game.add_item(ItemData.jewel("pink", 7))
	check(Game.deposit_item(Game.profile.inv.size() - 1), "deposit before the backup")
	var dir := SaveBackup.backup_now("manual")
	check(dir != "" and FileAccess.file_exists(dir.path_join(SharedStorage.PATH.get_file())), "the backup holds the shared storage")
	check(SaveBackup.list()[0].get("storage", -1) == SharedStorage.size(), "the backup index counts it")
	Game.add_item(ItemData.jewel("pink", 3))
	check(Game.deposit_item(Game.profile.inv.size() - 1) and _count("pink") == 10, "deposit after the backup")
	check(SaveBackup.restore(dir, 1) and _count("pink") == 10, "restoring one hero leaves the shared storage as it is")
	check(Game.load_game(1) and _count("pink") == 10, "and loading that hero doubles nothing")
	check(SaveBackup.restore_all(dir) and _count("pink") == 7, "restore all puts the shared storage back with the heroes")
	SharedStorage.read_file()
	check(_count("pink") == 7, "on disk too")
