extends Node
## หนึ่งในใต้หล้า's weekly crown (MazeCrown): the week's champion of เขาวงกตหนึ่งในใต้หล้า
## (MazeWar.champion, injected here) gets the title and the timed costume once (worn at
## once, its end on the item and the slot, the countdown on its tooltip and tile), nothing
## is granted, toasted or announced twice across settles, reloads and sessions; a second
## win in a row renews the same costume and the title (never a second costume); at its end
## the costume goes from the bag, the old storage, the shared storage, the costume slot and
## a stall lot, the title comes off with a notice and cannot be worn until won again; a
## world player who holds it wears the costume and the grand plate (name plate, card,
## stall, looks); the crown cannot be sold, traded, consigned, set on a stall, stored in
## the shared storage or bought; the grand plate over the hero's head; the server-wide
## announcement; save validation in the game and on the server (node).
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/maze_crown_test.tscn
var failures := 0
var checks := 0
var toasts: Array[String] = []
var base_offset := 0.0
var week := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	Announcer.ticking = false
	base_offset = WorldPresence.clock_offset
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	_reset()
	week = MazeWar.week_of(MazeCrown.now())
	_award()
	await _plates()
	_reload()
	_renew()
	_refusals()
	_expiry()
	_ai_holder()
	_saves()
	_stale()
	WorldPresence.clock_offset = base_offset
	MazeCrown.test_champions.clear()
	MazeCrown.reset_session()
	_reset()
	print("MAZE CROWN: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()


## Moves the game's clock to unix time t.
func _at(t: float) -> void:
	WorldPresence.clock_offset += t - WorldPresence.clock()
	MazeCrown.clear_cache()


func _crowns(list: Array) -> int:
	return list.filter(func(x): return MazeCrown.is_crown_item(x)).size()


## Every crown costume the hero has: the bag, the old storage, the shared storage, the slot.
func _all_crowns() -> int:
	var n := _crowns(Game.profile.inv) + _crowns(Game.profile.get("storage", [])) + _crowns(SharedStorage.items())
	return n + (1 if RewardShop.worn_costume() == MazeCrown.COSTUME_ID else 0)


func _award() -> void:
	Game.slot = 1
	Game.new_profile(&"warrior", "Crown QA", FaceKit.default_look())
	Game.profile.level = 100
	RewardShop.wear("costume", "")
	RewardShop.add_coins(5000)
	check(RewardShop.buy("costume", "sakura") == "ok" and RewardShop.wear("costume", "sakura") == "ok", "the hero wears another costume first")
	# Nothing to hand out before a champion is known.
	MazeCrown.settle()
	check(_all_crowns() == 0 and int(MazeCrown.record().done) == week - 1, "no champion: nothing granted, the week marked done")
	# The champion of the week that just ended is the hero (a fresh record: done back to -1).
	Game.profile.erase(MazeCrown.KEY)
	MazeCrown.test_champions[week - 1] = {"name": "Crown QA", "kills": 57, "hero": true, "index": -1}
	toasts.clear()
	var heard := Announcer.history.size()
	MazeCrown.settle()
	var ends := int(MazeWar.week_end(week))
	check(RewardShop.worn_costume() == MazeCrown.COSTUME_ID and int(RewardShop.data().cx) == ends, "the crown costume is worn at once, ending with the next week (%d)" % ends)
	check(RewardShop.bag_index("sakura") >= 0, "the costume worn before went to the bag")
	check(_all_crowns() == 1, "exactly one crown costume")
	check(Achievements.title_of(Game.profile) == MazeCrown.TITLE_NAME and MazeCrown.wears_title(Game.profile), "the title is worn")
	check(MazeCrown.until_of(Game.profile) == ends and int(MazeCrown.record().wins) == 1 and int(MazeCrown.record().last) == week - 1, "the record: until, wins, last")
	check(toasts.any(func(s: String): return s.contains("57 ศพ") and s.contains(MazeCrown.TITLE_NAME)), "the hero hears it won (%s)" % [toasts])
	var line := "%s Crown QA ครองหนึ่งในใต้หล้าประจำสัปดาห์ด้วย 57 ศพ!" % MazeCrown.CROWN
	check(Announcer.history.size() == heard + 1 and String(Announcer.history[-1].text) == line and String(Announcer.history[-1].kind) == "crown", "announced server-wide once: %s" % [Announcer.history.slice(heard)])
	# The item: the countdown on its tooltip and tile, its name, its icon.
	var item: Dictionary = Game.equipped(Game.COSTUME_SLOT)
	check(int(item.get("expires", 0)) == ends and RewardShop.valid_costume_item(item), "the slot's item carries its end")
	var lines := ItemData.stat_lines(item)
	check(lines.any(func(s: String): return s.contains(MazeCrown.left_text(ends))) and lines.has(MazeCrown.NOTE), "the tooltip counts down (%s)" % [lines])
	check(ItemData.tile_text(item) == MazeCrown.tile_left(ends) and ItemData.name_of(item) == MazeCrown.COSTUME_NAME, "the tile counts down too, the name")
	check(ItemLook.icon(item) != null and ItemLook.icon(item) != ItemLook.icon(RewardShop.costume_item("royal")), "with its own icon")
	check(MazeCrown.left_text(MazeCrown.now() + 5 * 86400 + 3 * 3600 + 120) == "หมดอายุใน 5 วัน 3 ชม." and MazeCrown.left_text(MazeCrown.now() - 1) == "หมดอายุแล้ว", "the countdown reads in Thai")
	check(MazeCrown.left_text(MazeCrown.now() + 2 * 3600 + 15 * 60 + 5) == "หมดอายุใน 2 ชม. 15 นาที", "hours and minutes on the last day")
	# Settling again (the next check, another call from team maze) changes nothing.
	toasts.clear()
	var before := JSON.stringify(Game.profile)
	for n in 3:
		MazeCrown.settle()
	check(JSON.stringify(Game.profile) == before and toasts.is_empty() and Announcer.history.size() == heard + 1, "settle is idempotent")
	# Taken off and worn again from the bag keeps its end.
	check(Game.unequip(Game.COSTUME_SLOT) and _crowns(Game.profile.inv) == 1 and not RewardShop.data().has("cx"), "taken off: into the bag, the slot's end cleared")
	check(int(Game.profile.inv[RewardShop.bag_index(MazeCrown.COSTUME_ID)].expires) == ends, "the bag's item keeps its end")
	check(RewardShop.wear("costume", MazeCrown.COSTUME_ID) == "ok" and int(RewardShop.data().cx) == ends, "worn again: the end back in the slot")
	check(RewardShop.wear("costume", "sakura") == "ok" and int(Game.profile.inv[RewardShop.bag_index(MazeCrown.COSTUME_ID)].expires) == ends, "another costume over it: back to the bag with its end")
	RewardShop.wear("costume", MazeCrown.COSTUME_ID)


func _plates() -> void:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	check(hero.visual.costume == MazeCrown.COSTUME_ID, "the hero in the world wears the sovereign")
	var plate := hero._name_plate.get_node_or_null("CrownPlate") as Node3D
	check(plate != null and plate.position.y > 0.0, "the grand crown plate stands over the hero's name")
	var face := plate.get_node_or_null("CrownTitle") as Label3D if plate else null
	check(face != null and face.text.contains(MazeCrown.TITLE_NAME) and face.modulate == MazeCrown.COLOR, "gold, with the title")
	check(plate != null and plate.get_child_count() == 3, "two glow rims under the gold face")
	check(not hero._name_plate.text.contains(MazeCrown.TITLE_NAME), "the title is not repeated on the name line")
	check(hero.visual.find_children("*", "OmniLight3D", true, false).is_empty() and hero.visual.find_children("*", "GPUParticles3D", true, false).is_empty(), "no lights, no GPU particles")
	# Another title worn: the plate goes, the plain line comes back.
	Game.profile.ach["t_kill1"] = true
	Game.set_title(Achievements.index_of("t_kill1"))
	await get_tree().process_frame
	check(hero._name_plate.get_node_or_null("CrownPlate") == null and hero._name_plate.text.contains("มือใหม่"), "another title: an ordinary line, no crown plate")
	check(Game.set_title(Achievements.index_of(MazeCrown.ACH_ID)), "the crown title is worn again while it lasts")
	await get_tree().process_frame
	check(hero._name_plate.get_node_or_null("CrownPlate") != null, "and the plate is back")
	# The titles page shows how long it lasts.
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"titles")
	await get_tree().process_frame
	var left := menu.find_child("TitleLeft_%s" % MazeCrown.ACH_ID, true, false) as Label
	check(left != null and left.text == MazeCrown.left_text(MazeCrown.until_of(Game.profile)), "the titles page counts the crown down")
	menu.close_menu()
	menu.free()
	get_tree().paused = false
	field.queue_free()
	await get_tree().process_frame


func _reload() -> void:
	check(Game.save(), "saved with the crown")
	var heard := Announcer.history.size()
	toasts.clear()
	check(Game.load_game(1), "reloaded")
	check(_all_crowns() == 1 and RewardShop.worn_costume() == MazeCrown.COSTUME_ID and int(MazeCrown.record().wins) == 1, "after a reload: one crown, still worn, one win")
	check(MazeCrown.wears_title(Game.profile), "the title still worn")
	# A new session (the announcement guard gone): the record alone keeps it from coming twice.
	MazeCrown.reset_session()
	check(Game.load_game(1) and _all_crowns() == 1 and int(MazeCrown.record().wins) == 1, "a new session: still one crown")
	check(Announcer.history.size() == heard and toasts.filter(func(s: String): return s.contains("ศพ")).is_empty(), "nothing announced or toasted again")
	# A second character of the account never gets it (the champion is this hero's game).
	Game.slot = 2
	Game.new_profile(&"mage", "Other QA", FaceKit.default_look())
	MazeCrown.test_champions[week - 1] = {"name": "Crown QA", "kills": 57, "hero": false, "index": -1}
	MazeCrown.settle()
	check(_all_crowns() == 0 and not MazeCrown.wears_title(Game.profile), "another hero who did not win gets nothing")
	MazeCrown.test_champions[week - 1] = {"name": "Crown QA", "kills": 57, "hero": true, "index": -1}
	check(Game.load_game(1), "back to the champion")


func _renew() -> void:
	# The hero wins the next week too: same costume, its end and the title's moved on.
	var t := MazeWar.week_end(week) + 120.0
	_at(t)
	MazeCrown.test_champions[week] = {"name": "Crown QA", "kills": 64, "hero": true, "index": -1}
	toasts.clear()
	MazeCrown.settle()
	var ends := int(MazeWar.week_end(week + 1))
	check(_all_crowns() == 1 and int(RewardShop.data().cx) == ends, "won twice in a row: one costume, renewed to %d (%s)" % [ends, RewardShop.data().get("cx")])
	check(MazeCrown.until_of(Game.profile) == ends and MazeCrown.wears_title(Game.profile) and int(MazeCrown.record().wins) == 2, "the title renewed, two wins")
	check(toasts.any(func(s: String): return s.contains("ต่ออีกสัปดาห์")), "the hero hears it renewed (%s)" % [toasts])
	check(not toasts.any(func(s: String): return s.contains("หมดอายุ")), "nothing expired at the handover to itself")
	# A copy in the bag too (an old save): renewing leaves a single one.
	Game.profile.inv.append(MazeCrown.crown_item(ends - 100))
	MazeCrown._renew_costume(ends, t)
	check(_all_crowns() == 1, "a second copy anywhere goes when renewing")


func _refusals() -> void:
	RewardShop.wear("costume", "")
	var at := RewardShop.bag_index(MazeCrown.COSTUME_ID)
	var item: Dictionary = Game.profile.inv[at]
	var gold := int(Game.profile.gold)
	Game.sell_item(at)
	check(RewardShop.bag_index(MazeCrown.COSTUME_ID) == at and int(Game.profile.gold) == gold, "the merchant does not buy it")
	check(not OnlineTrade.tradable(item), "untradable")
	check(not StallStock.sell(at) and not StallStock.consign(at), "no stall keeper buys or consigns it")
	check(PlayerStall.list_item(at, 100) < 0, "the hero's stall refuses it")
	check(not Game.deposit_item(at) and _crowns(SharedStorage.items()) == 0 and RewardShop.bag_index(MazeCrown.COSTUME_ID) == at, "the shared storage refuses it")
	check(MazeCrown.deposit_lock(item) != "" and MazeCrown.deposit_lock(RewardShop.costume_item("royal")) == "", "only the crown is locked")
	check(RewardShop.problem("costume", MazeCrown.COSTUME_ID) != "" and RewardShop.buy("costume", MazeCrown.COSTUME_ID) != "ok", "never bought in the reward shop")
	check(RewardShop.price_text(RewardShop.COSTUMES[MazeCrown.COSTUME_ID]).contains(MazeCrown.TITLE_NAME), "its card says how it is won")
	check(RewardShop.costume_rarity(MazeCrown.COSTUME_ID) == 4, "a mythic costume")
	RewardShop.wear("costume", MazeCrown.COSTUME_ID)


func _expiry() -> void:
	var ends := int(MazeWar.week_end(week + 1))
	# Copies everywhere (as a forged or stale save would hold them), all ending together.
	Game.profile.inv.append(MazeCrown.crown_item(ends))
	Game.profile.storage.append(MazeCrown.crown_item(ends))
	SharedStorage.put(MazeCrown.crown_item(ends))
	Game.profile.stall["lots"] = [{"lot": 9, "item": MazeCrown.crown_item(ends), "price": 10, "listed_at": 0.0}]
	var keep := ItemData.potion("hp_s", 3)
	Game.profile.inv.append(keep)
	# A minute before the end: everything still there.
	_at(float(ends) - 60.0)
	check(MazeCrown.expire() == 1 and (Game.profile.stall.lots as Array).is_empty(), "before its end only a crown on a stall goes (it never belongs there)")
	check(_all_crowns() == 4 and MazeCrown.wears_title(Game.profile), "before its end the rest stays")
	Game.profile.stall["lots"] = [{"lot": 9, "item": MazeCrown.crown_item(ends), "price": 10, "listed_at": 0.0}]
	# The end passes while playing; the next week's champion is a world player.
	var i := 7
	MazeCrown.test_champions[week + 1] = {"name": String(WorldPlayers.entry(i).name), "kills": 81, "hero": false, "index": i}
	_at(float(ends) + 5.0)
	toasts.clear()
	var heard := Announcer.history.size()
	MazeCrown.settle()
	check(_all_crowns() == 0, "at the end the costume is gone from the bag, the old storage, the shared storage and the slot")
	check((Game.profile.stall.lots as Array).is_empty(), "and from a stall lot")
	check(Game.profile.inv.has(keep), "nothing else is touched")
	check(RewardShop.worn_costume() == "" and not RewardShop.data().has("cx"), "the slot is empty, its end cleared")
	check(Achievements.title_of(Game.profile) == "" and Achievements.title_index(Game.profile) < 0, "the title came off")
	check(toasts.any(func(s: String): return s.contains("หมดอายุ") and s.contains(MazeCrown.COSTUME_NAME)), "a notice for the costume (%s)" % [toasts])
	check(toasts.any(func(s: String): return s.contains("หมดอายุ") and s.contains(MazeCrown.TITLE_NAME)), "a notice for the title")
	check(toasts.any(func(s: String): return s.contains("ส่งต่อให้ %s" % WorldPlayers.entry(i).name)), "the hero hears it lost the crown")
	check(String(Announcer.history[-1].text).contains("%s ครองหนึ่งในใต้หล้า" % WorldPlayers.entry(i).name) and Announcer.history.size() == heard + 1, "the new champion is announced")
	check(Achievements.is_earned(MazeCrown.ACH_ID, Game.profile) and not Game.set_title(Achievements.index_of(MazeCrown.ACH_ID)), "still earned in the list, but cannot be worn until won again")
	SharedStorage.read_file()
	check(_crowns(SharedStorage.items()) == 0, "the shared storage file was written without it")
	# On load too: a save still holding an expired crown (worn and in the bag) loses it.
	Game.profile.inv.append(MazeCrown.crown_item(ends))
	RewardShop.data()["cos"] = MazeCrown.COSTUME_ID
	RewardShop.data()["cx"] = ends
	Game.profile.flags[Achievements.TITLE_FLAG] = Achievements.index_of(MazeCrown.ACH_ID)
	check(Game.save() and Game.load_game(1), "a stale save loads")
	check(_all_crowns() == 0 and Achievements.title_index(Game.profile) < 0, "and the expired crown is gone on load")
	# A forged end further ahead than any crown lasts goes as well.
	Game.profile.inv.append(MazeCrown.crown_item(int(MazeCrown.now()) + 60 * 86400))
	check(MazeCrown.expire() == 1 and _all_crowns() == 0, "a forged far end goes")


func _ai_holder() -> void:
	var i := 7
	var t := MazeCrown.now()
	check(MazeCrown.ai_holds(i, t) and not MazeCrown.ai_holds(i + 1, t), "world player %d holds the crown this week" % i)
	var h := MazeCrown.holder(t)
	check(int(h.kills) == 81 and int(h.until) == int(MazeWar.week_end(week + 2)), "the holder: its kills, until the end of the next week")
	check(String(RewardShop.world_cosmetics(i, t).cos) == MazeCrown.COSTUME_ID, "it wears the sovereign")
	check(String(PlayerLook.of_member(WorldPlayers.member(i, t), i).cos) == MazeCrown.COSTUME_ID, "its look carries it (town, fields, the maze)")
	var bought := 0
	for k in WorldPlayers.size():
		if k != i and String(RewardShop.world_cosmetics(k, t).cos) == MazeCrown.COSTUME_ID:
			bought += 1
	check(bought == 0, "nobody else ever buys it")
	# Its name plate: the grand plate over the name.
	var p := FieldPlayer.new()
	p.setup_world(i, WorldPlayers.member(i, t), null, null)
	p._label = Label3D.new()
	p.add_child(p._label)
	p._label.text = p._level_text()
	check(p._label.get_node_or_null("CrownPlate") != null, "its name plate wears the crown plate")
	var q := FieldPlayer.new()
	q.setup_world(i + 1, WorldPlayers.member(i + 1, t), null, null)
	q._label = Label3D.new()
	q.add_child(q._label)
	q._label.text = q._level_text()
	check(q._label.get_node_or_null("CrownPlate") == null, "another world player does not")
	check(p._costume_id() == MazeCrown.COSTUME_ID and q._costume_id() != MazeCrown.COSTUME_ID, "the costume it is dressed in")
	p.free()
	q.free()
	# The next week ends with nobody: it passes on, the costume and plate go with it.
	_at(MazeWar.week_end(week + 2) + 30.0)
	check(not MazeCrown.ai_holds(i) and String(RewardShop.world_cosmetics(i).cos) != MazeCrown.COSTUME_ID, "a week later it no longer holds it")
	_at(t)


func _saves() -> void:
	# Back to the real week: an end the server's clock finds less than a crown's life ahead.
	_at(MazeWar.week_end(week) - 3600.0)
	var ends := int(MazeWar.week_end(week))
	MazeCrown.test_champions[week] = {"name": "Crown QA", "kills": 64, "hero": true, "index": -1}
	Game.profile.inv.append(MazeCrown.crown_item(ends))
	RewardShop.data()["cos"] = "sakura"
	var p: Dictionary = Game.profile.duplicate(true)
	p.inv.append(MazeCrown.crown_item(ends))
	p[RewardShop.KEY]["cos"] = MazeCrown.COSTUME_ID
	p[RewardShop.KEY]["cx"] = ends
	check(Game._valid_profile(p), "a profile with the crown worn and in the bag passes")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(p))
	check(Game._valid_profile(parsed), "after JSON too")
	var fixed := Game._repair(parsed.duplicate(true))
	var it: Dictionary = fixed.inv[fixed.inv.size() - 1]
	check(it.expires is int and int(it.expires) == ends and fixed[RewardShop.KEY].cx is int and fixed[MazeCrown.KEY].until is int, "the repair turns the ends back into ints")
	for bad_end in [null, "123", 12, 1.5e10, 1700000000.5]:
		var copy := p.duplicate(true)
		var item := MazeCrown.crown_item(ends)
		if bad_end == null:
			item.erase("expires")
		else:
			item["expires"] = bad_end
		copy.inv.append(item)
		check(not Game._valid_profile(copy), "a crown with a bad end is refused (%s)" % [bad_end])
		check(not SharedStorage.valid_items([item]), "in the storage too (%s)" % [bad_end])
	var other := RewardShop.costume_item("royal")
	other["expires"] = ends
	check(not RewardShop.valid_costume_item(other), "no other costume carries an end")
	for bad in [{"done": -2}, {"wins": -1}, {"until": 5}, {"until": "x"}, {"zzz": 1}, {"done": 1, "until": 0, "wins": 0, "last": 1, "x": 2}, []]:
		var copy := p.duplicate(true)
		copy[MazeCrown.KEY] = bad
		check(not Game._valid_profile(copy), "a broken crown record is refused (%s)" % [bad])
	var worn_bad := p.duplicate(true)
	worn_bad[RewardShop.KEY]["cx"] = 5
	var repaired := Game._repair(worn_bad.duplicate(true))
	check(String(repaired[RewardShop.KEY].cos) == "" and not repaired[RewardShop.KEY].has("cx"), "a worn crown with a broken end comes off on repair")
	var stray := p.duplicate(true)
	stray[RewardShop.KEY]["cos"] = "sakura"
	check(not Game._repair(stray.duplicate(true))[RewardShop.KEY].has("cx"), "an end on another worn costume is dropped")
	# The server takes the cloud bundle with the crown and refuses an absurd one.
	Game.profile[RewardShop.KEY]["cos"] = MazeCrown.COSTUME_ID
	Game.profile[RewardShop.KEY]["cx"] = ends
	check(Game.save(), "saved with the crown")
	_server(Game.cloud_bundle_json(), true, "the server accepts the crown")
	var raw: Dictionary = JSON.parse_string(Game.cloud_bundle_json())
	var slot_key := String.num_int64(Game.slot)
	(raw.slots[slot_key].inv as Array).append({"kind": "costume", "id": MazeCrown.COSTUME_ID, "rarity": 4, "expires": int(Time.get_unix_time_from_system()) + 400 * 86400})
	_server(JSON.stringify(raw), false, "the server refuses a crown that lasts a year")
	raw = JSON.parse_string(Game.cloud_bundle_json())
	raw.slots[slot_key][MazeCrown.KEY] = {"done": 1, "until": 99, "wins": 0, "last": -1}
	_server(JSON.stringify(raw), false, "the server refuses a broken crown record")


func _server(text: String, want: bool, label: String) -> void:
	var dir := OS.get_environment("XDG_DATA_HOME")
	var path := (dir if dir != "" else OS.get_user_data_dir()).path_join("maze_crown_bundle.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var script := ProjectSettings.globalize_path("res://tests/integration/save_survival_server.mjs")
	var output: Array = []
	var code := OS.execute("node", [script, path], output, true)
	DirAccess.remove_absolute(path)
	if code == -1 or (output.size() > 0 and String(output[0]).contains("command not found")):
		print("node not found: the server check is skipped")
		return
	check((code == 0) == want, "%s: %s" % [label, output[0] if output.size() > 0 else ""])


## A champion saved by an older build names a world player no longer on the roster (its
## index holds another name now): it is dropped, the week settled again, and the hero who
## really killed the most gets the crown.
func _stale() -> void:
	_reset()
	WorldPresence.clock_offset = base_offset
	MazeCrown.test_champions.clear()
	MazeCrown.reset_session()
	MazeCrown.clear_cache()
	MazeWar.reset()
	var w := MazeWar.week_of(MazeCrown.now()) - 1
	if MazeWar.week_end(w) <= float(MazeWar.OPEN_UNIX):
		check(true, "stale champion: no week ended since the opening yet (skipped)")
		return
	Game.slot = 2
	Game.new_profile(&"muaythai", "Stale QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile[MazeWar.KEY] = {"weeks": {str(w): {"k": 99, "at": int(MazeWar.week_end(w)) - 600, "d": 0, "live": {}, "held": {}}},
		"champs": {str(w): {"name": "Raijin", "kills": 15, "hero": false, "index": 19}}}
	Game.profile[MazeCrown.KEY] = {"done": w, "until": 0, "wins": 0, "last": -1}
	check(MazeWar.stale_champ({"name": "Raijin", "kills": 15, "hero": false, "index": 19}), "a name not at its index is stale")
	check(not MazeWar.stale_champ({"name": String(WorldPlayers.entry(19).name), "kills": 15, "hero": false, "index": 19}), "the name at its index is not")
	check(not MazeWar.stale_champ({"name": "Someone", "kills": 15, "hero": false, "index": -1}), "a real player is not")
	MazeCrown.settle()
	var c := MazeWar.champion(w)
	check(bool(c.get("hero", false)) and int(c.get("kills", 0)) == 99, "the week's champion is worked out again: the hero (%s)" % [c])
	check(MazeCrown.wears_title(Game.profile) and RewardShop.worn_costume() == MazeCrown.COSTUME_ID, "the hero gets the title and the costume")
	check(int(MazeCrown.record().done) == w and int(MazeCrown.record().wins) == 1, "the week is settled once more (%s)" % [MazeCrown.record()])
	var again := _all_crowns()
	MazeCrown.settle()
	check(_all_crowns() == again and int(MazeCrown.record().wins) == 1, "settling again changes nothing")
