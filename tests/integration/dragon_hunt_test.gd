extends Node
## ล่ามังกรแก้วเจ็ดสี, the dragon hunt week after the x5 festival (DragonHunt; headless):
## - the dates: 20 Nov 2026 07:40 to 27 Nov 07:40 Thai time, again every four weeks;
## - the rare dragon twice as often on the hunt's days (still never close together, one
##   number each), the plain schedule outside them and with the switch off;
## - hunt points: a real kill of the dragon on the isle, a real golden monster in a
##   levelling field (the heroes below ★300), help, nothing outside the hunt;
## - milestones: real items, each claimed once, the title at the last, kept until the
##   next hunt starts and then a fresh record; the save (valid, JSON round trip, repair,
##   malformed records refused);
## - the world players: their points, the top hunters with the hero among them, the
##   same on every read; the server hears of their kills and of the hunt opening;
## - the HUD chip and the menu tab.
##   godot --headless --path . res://tests/integration/dragon_hunt_test.tscn
var failures := 0
var checks := 0


class LootZone:
	extends Zone
	var items: Array[Dictionary] = []
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if not item.is_empty():
			items.append(item)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	WorldEvents.festival_enabled = false
	Game.new_profile(&"warrior", "Hunt QA")
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon().level = SkyIsleData.ENTRY_STAR
	ZoneData.ensure()
	_dates()
	_schedule()
	_points()
	await _real_kills()
	_milestones()
	_saves()
	_world_players()
	await _tab()
	WorldPresence.clock_offset = 0.0
	print("DRAGON HUNT: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _dates() -> void:
	check(DragonHunt.START == WorldEvents.FESTIVAL5_END and float(DragonHunt.START) == thai(2026, 11, 20, 7, 40), "it starts as the x5 festival ends: 20 Nov 2026 07:40")
	check(not DragonHunt.is_on(thai(2026, 11, 20, 7, 39)) and DragonHunt.is_on(thai(2026, 11, 20, 7, 40)), "not a minute before")
	check(DragonHunt.is_on(thai(2026, 11, 27, 7, 39)) and not DragonHunt.is_on(thai(2026, 11, 27, 7, 40)), "seven days: to 27 Nov 07:40")
	check(DragonHunt.index(thai(2026, 11, 10, 12)) == -1 and DragonHunt.index(thai(2026, 12, 1, 12)) == 0 and not DragonHunt.is_on(thai(2026, 12, 1, 12)), "nothing before it; between hunts the last one's record stays")
	check(DragonHunt.is_on(thai(2026, 12, 18, 7, 40)) and DragonHunt.index(thai(2026, 12, 18, 7, 40)) == 1 and not DragonHunt.is_on(thai(2026, 12, 25, 7, 40)), "again four weeks later (18-25 Dec)")
	check(DragonHunt.next_start(thai(2026, 12, 1, 12)) == thai(2026, 12, 18, 7, 40), "the next one's start")
	check(DragonHunt.date_text(float(DragonHunt.START)) == "20 พ.ย. 07:40", "its date in Thai (%s)" % DragonHunt.date_text(float(DragonHunt.START)))


func _schedule() -> void:
	var counts := []
	var ok_double := true
	var ok_gap := true
	var ids := {}
	var last_end := -INF
	for d in range(19, 28):
		var day := WorldEvents.day_of(thai(2026, 11, d, 12))
		var starts := WorldEvents.rare_windows(day)
		counts.append(starts.size())
		var hunt := d >= 20 and d <= 26
		var plain := WorldEvents.RARE_MIN + WorldEvents.roll("rare|%d" % day) % (WorldEvents.RARE_MAX - WorldEvents.RARE_MIN + 1)
		ok_double = ok_double and starts.size() == plain * (2 if hunt else 1)
		var midnight := float(day) * 86400.0 - float(WorldPlayers.TZ)
		for k in starts.size():
			ok_gap = ok_gap and starts[k] - last_end >= float(WorldEvents.RARE_GAP) and starts[k] >= midnight and starts[k] + float(WorldEvents.RARE_LENGTH) <= midnight + 86400.0
			last_end = starts[k] + float(WorldEvents.RARE_LENGTH)
			var now := WorldEvents.rare_now(starts[k] + 60.0)
			ok_gap = ok_gap and not now.is_empty() and not ids.has(int(now.window))
			ids[int(now.window)] = true
	print("dragon_hunt_test: windows 19-27 Nov: %s" % str(counts))
	check(ok_double, "twice the rare dragon's windows on 20-26 Nov, the plain count on 19 and 27 Nov (%s)" % str(counts))
	check(ok_gap, "still never closer than RARE_GAP, inside their day, one number each")
	DragonHunt.enabled = false
	var day := WorldEvents.day_of(thai(2026, 11, 22, 12))
	check(WorldEvents.rare_count(day) <= WorldEvents.RARE_MAX and DragonHunt.chip_text(thai(2026, 11, 22, 12)) == "", "the switch gives the plain schedule back")
	DragonHunt.enabled = true


func _points() -> void:
	Game.profile.erase(DragonHunt.KEY)
	check(DragonHunt.on_golden(thai(2026, 11, 19, 12)) == 0 and DragonHunt.on_rare(1.0, thai(2026, 11, 27, 9)) == 0 and not Game.profile.has(DragonHunt.KEY), "no points outside the hunt")
	var t := thai(2026, 11, 21, 12)
	check(DragonHunt.on_rare(0.0, t) == 0, "standing by is not a hand in it")
	check(DragonHunt.on_rare(0.3, t) == DragonHunt.RARE_HELP, "a hand in someone else's kill: +%d" % DragonHunt.RARE_HELP)
	check(DragonHunt.on_golden(t) == DragonHunt.GOLDEN, "a golden monster: +%d" % DragonHunt.GOLDEN)
	var s := DragonHunt.state(t)
	check(int(s.pts) == DragonHunt.RARE_HELP + DragonHunt.GOLDEN and int(s.golden) == 1 and int(s.kills) == 0 and int(s.n) == 0, "kept in profile.dhunt (%s)" % str(s))
	Game.profile.erase(DragonHunt.KEY)


func _real_kills() -> void:
	# The dragon on the isle, in a window of 22 Nov.
	var day := WorldEvents.day_of(thai(2026, 11, 22, 12))
	var starts := WorldEvents.rare_windows(day)
	at(starts[3] + 20.0)
	DragonHunt.test_time = -1.0
	Game.current_zone = SkyIsleData.ID
	Game.profile["spawn_override"] = ""
	var zone := LootZone.new()
	zone.zone_id = SkyIsleData.ID
	zone.layout_seed = 7
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 600:
		if zone.is_built:
			break
		await get_tree().process_frame
	var node := RareDragon.of(zone)
	if node == null:
		check(false, "the isle has its rare dragon")
		return
	node.set_process(false)
	node.tick()
	var mob := node.find()
	check(mob != null, "a hunt window's dragon comes")
	if mob != null:
		mob.take_hit(mob.hp, false, Color.WHITE, zone.hero)
		var s := DragonHunt.peek()
		check(mob.is_dead() and int(s.pts) == DragonHunt.RARE_KILL and int(s.kills) == 1, "the hero brings it down: +%d hunt points (%s)" % [DragonHunt.RARE_KILL, str(s)])
		check(node.prizes.size() == 1, "and its own prize as always")
		var again := node.spawn(int(mob.get_meta(RareDragon.META)))
		again.take_hit(again.hp, false, Color.WHITE, zone.hero)
		check(int(DragonHunt.peek().pts) == DragonHunt.RARE_KILL, "once a window")
	zone.queue_free()
	await get_tree().process_frame
	# A golden monster in a levelling field, for a hero below ★300.
	Game.paragon().level = 0
	Game.profile.level = 5
	var n := int(floor(thai(2026, 11, 23, 10) / float(WorldEvents.GOLDEN_PERIOD)))
	at(WorldEvents.golden_start(n) + 20.0)
	Game.current_zone = &"meadow"
	var field := LootZone.new()
	field.zone_id = &"meadow"
	field.layout_seed = 7
	add_child(field)
	field.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	field._tick_golden()
	var gold_mob: Mob = field._golden
	check(gold_mob != null, "a golden monster in the meadow")
	if gold_mob != null:
		gold_mob.take_hit(gold_mob.hp, false, Color.WHITE, field.hero)
		var s := DragonHunt.peek()
		check(int(s.pts) == DragonHunt.RARE_KILL + DragonHunt.GOLDEN and int(s.golden) == 1, "a Lv.5 hero earns hunt points from the golden monster (%s)" % str(s))
	field.queue_free()
	await get_tree().process_frame
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon().level = SkyIsleData.ENTRY_STAR


func _bag(id: String) -> int:
	return Game.jewel_count(id)


func _milestones() -> void:
	var t := thai(2026, 11, 24, 12)
	DragonHunt.test_time = t
	Game.profile.erase(DragonHunt.KEY)
	Game.profile.inv.clear()
	var s := DragonHunt.state(t)
	s["pts"] = 260
	check(DragonHunt.claimable(t) == 2, "100 and 250 points reached: two to claim")
	var chaos := _bag("chaos")
	check(DragonHunt.claim(0, t) == "ok" and _bag("chaos") == chaos + 3, "the first: chaos jewels x3 in the bag")
	check(DragonHunt.claim(0, t) == "รับรางวัลขั้นนี้ไปแล้ว" and _bag("chaos") == chaos + 3, "claimed once only")
	check(DragonHunt.claim(2, t) == "แต้มล่ายังไม่ถึง", "not before its points")
	check(DragonHunt.claim(9, t) != "ok" and DragonHunt.claim(-1, t) != "ok", "no such milestone")
	s["pts"] = 2000
	var core := _bag("set_core")
	var n := DragonHunt.claim_all(t)
	check(n == 6 and DragonHunt.claimable(t) == 0 and int(s.got) == (1 << DragonHunt.MILESTONES.size()) - 1, "the rest at once (%d)" % n)
	check(_bag("set_core") == core + 4 and _bag("sky_dragon_egg") == 1 and _bag("dragon_chest") == 2 and _bag("dragon_fragment") == 5, "set cores, chests, fragments and the sky dragon's egg")
	check(Achievements.is_earned(DragonHunt.TITLE_ID, Game.profile) and Achievements.set_title(Game.profile, Achievements.index_of(DragonHunt.TITLE_ID)) and Achievements.title_of(Game.profile) == "นักล่ามังกรแก้ว", "the title นักล่ามังกรแก้ว, worn")
	check(DragonHunt.claim_all(t) == 0, "nothing claims twice")
	# After the hunt: still claimable until the next one; then a fresh record.
	s["pts"] = 2000
	s["got"] = 1
	check(DragonHunt.claimable(thai(2026, 12, 10, 12)) == 6, "what is left can be claimed until the next hunt")
	var next := DragonHunt.state(thai(2026, 12, 18, 9))
	check(int(next.n) == 1 and int(next.pts) == 0 and int(next.got) == 0, "the next hunt starts a fresh record")
	DragonHunt.test_time = -1.0


func _saves() -> void:
	var t := thai(2026, 11, 24, 12)
	Game.profile[DragonHunt.KEY] = {"n": 0, "pts": 1234, "got": 5, "kills": 3, "golden": 9}
	var data := JSON.parse_string(Marshalls.base64_to_utf8(Game.export_code())) as Dictionary
	check(Game._valid_profile(data), "a profile with the hunt record is valid")
	check(data[DragonHunt.KEY].pts is float, "JSON brings numbers back as floats")
	var fixed := Game._repair(data)
	check(fixed[DragonHunt.KEY].pts is int and int(fixed[DragonHunt.KEY].pts) == 1234 and int(fixed[DragonHunt.KEY].got) == 5, "_repair makes them ints again")
	for bad in [[], {"got": 128}, {"pts": -1}, {"pts": 1.5}, {"n": "x"}, {"junk": 1}, {"kills": "many"}]:
		var copy := data.duplicate(true)
		copy[DragonHunt.KEY] = bad
		check(not Game._valid_profile(copy), "refused: %s" % str(bad))
	var broken := data.duplicate(true)
	broken[DragonHunt.KEY] = {"got": 999}
	Game._repair(broken)
	check(not broken.has(DragonHunt.KEY), "_repair drops a broken record")
	var src := FileAccess.get_file_as_string("res://hosting/accounts/server/accounts.js")
	check(src.contains("'dhunt' in profile") and src.contains("2 ** 7 - 1"), "the server checks the same shape")
	check(int(DragonHunt.peek(t).pts) == 1234, "peek reads it")


func _world_players() -> void:
	var t := thai(2026, 11, 26, 21)
	WorldPlayers.ensure_until(t)
	var windows := DragonHunt.ended_windows(0, t)
	var slain := 0
	var first: Dictionary = {}
	for w in windows:
		var h := DragonHunt.window_hunters(int(w.window), float(w.start))
		if int(h.slayer) >= 0:
			slain += 1
			if first.is_empty():
				first = w
	print("dragon_hunt_test: %d hunt windows by 26 Nov 21:00, %d slain by world players" % [windows.size(), slain])
	check(windows.size() >= 6 * 8, "the hunt's windows so far (%d)" % windows.size())
	var t0 := Time.get_ticks_usec()
	var rows := DragonHunt.top(t, 10)
	var cost := float(Time.get_ticks_usec() - t0) / 1000.0
	var ai := rows.filter(func(r): return not bool(r.hero))
	var me := rows.filter(func(r): return bool(r.hero))
	print("dragon_hunt_test: top hunters %s (%.0f ms)" % [str(rows.map(func(r): return "%s %d" % [r.name, r.pts])), cost])
	check(ai.size() >= 9 and me.size() == 1, "world players and the hero in one list")
	var sorted := true
	for k in range(1, mini(rows.size(), 10)):
		sorted = sorted and int(rows[k - 1].pts) >= int(rows[k].pts)
	check(sorted and int(rows[0].rank) == 1, "best first")
	DragonHunt.reset()
	var again := DragonHunt.top(t, 10)
	check(str(again) == str(rows), "the same list when worked out again (every device)")
	var i := int(ai[0].index)
	check(DragonHunt.ai_points(i, 0, thai(2026, 11, 22, 12)) <= DragonHunt.ai_points(i, 0, t) and DragonHunt.ai_points(i, 0, thai(2026, 11, 20, 7, 40)) == 0, "a world player's points only grow from zero")
	check(DragonHunt.ai_points(i, 0, thai(2026, 12, 2, 12)) == DragonHunt.ai_points(i, 0, thai(2026, 11, 27, 7, 40)), "and stop when the hunt ends")
	check(cost < 3000.0, "the list is cheap enough for a menu (%.0f ms)" % cost)
	# The server's news: the opening once, a world player's kill when its window ends.
	Announcer.reset()
	Game.profile.flags.erase(WorldEvents.RARE_FLAG)
	Announcer.tick(thai(2026, 11, 20, 8))
	Announcer.tick(thai(2026, 11, 20, 8) + 1.0)
	var opening := Announcer.history.filter(func(h): return String(h.text).begins_with("ศึกล่ามังกรแก้วเจ็ดสีเริ่มแล้ว"))
	check(opening.size() == 1 and String(opening[0].kind) == "rare", "the hunt's opening is told once")
	if first.is_empty():
		check(slain == 0, "no world player on the isle in any window so far")
		return
	var name := String(WorldPlayers.entry(int(DragonHunt.window_hunters(int(first.window), float(first.start)).slayer)).name)
	Announcer.reset()
	Announcer.tick(float(first.until) - 2.0)
	Announcer.tick(float(first.until) + 1.0)
	var told := Announcer.history.filter(func(h): return String(h.text).contains(name) and String(h.text).contains("ศึกล่ามังกร"))
	check(told.size() == 1, "the server hears %s brought the dragon down (%s)" % [name, str(Announcer.history.map(func(h): return h.text))])
	var line := DragonHunt.AI_SLAIN % [name, WorldEvents.NAME_RARE, DragonHunt.RARE_KILL]
	check(told.size() == 1 and String(told[0].text) == Announcer.clean(line), "in the hunt's words")
	Announcer.tick(float(first.until) + 2.0)
	check(Announcer.history.filter(func(h): return String(h.text).contains(name) and String(h.text).contains("ศึกล่ามังกร")).size() == 1, "once")


func _tab() -> void:
	at(thai(2026, 11, 24, 12))
	Game.profile[DragonHunt.KEY] = {"n": 0, "pts": 300, "got": 1, "kills": 2, "golden": 4}
	var chip := DragonHunt.chip_text(WorldPresence.clock())
	check(chip.begins_with(DragonHunt.NAME) and chip.contains("x2") and chip.contains("แต้มล่า 300") and WorldEvents.chip_lines(WorldPresence.clock()).has(chip), "the HUD chip line (%s)" % chip)
	check(DragonHunt.chip_text(thai(2026, 12, 1, 12)) == "", "no chip line between hunts")
	check(GameMenu.TABS.any(func(tab): return tab[0] == "hunt" and tab[1] == "ล่ามังกรแก้ว"), "the menu has the tab")
	var menu := GameMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu.open_menu(&"hunt")
	await get_tree().process_frame
	var tab: Button = menu._tab_buttons[&"hunt"]
	check(tab.text.ends_with("●"), "a red dot while a milestone waits (%s)" % tab.text)
	var page := menu._content.find_child("DragonHunt", true, false)
	check(page != null and page.find_child("Claim1", true, false) != null and page.find_child("ClaimAll", true, false) != null, "the page with its claim buttons")
	var texts: Array = []
	if page != null:
		for node in page.find_children("*", "Label", true, false):
			texts.append((node as Label).text)
	check(texts.any(func(x: String): return x.contains("Hunt QA") and x.contains("(ฉัน)")), "the hero in the top hunters")
	check(texts.any(func(x: String): return x.contains(WorldEvents.NAME_GOLDEN) and x.contains(str(SkyIsleData.ENTRY_STAR))), "it tells heroes below ★300 to hunt golden monsters")
	(page.find_child("Claim1", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(DragonHunt.is_claimed(DragonHunt.peek(), 1) and not tab.text.ends_with("●"), "claimed from the page; the dot goes")
	menu.close_menu()
	menu.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
