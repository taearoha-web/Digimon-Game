extends Node
## เทศกาลลอยกระทง (LoyKrathong; headless):
## - the dates (22 Nov 2026 07:40 to 26 Nov 07:40 Thai), the night (24 Nov 19:00-23:00),
##   the switches, the night's EXP added to the evening's (x3, then x2, never x4);
## - materials drop in every hunting ground at about the same hourly rate (pace scaled),
##   never in the village or outside the festival; real kills drop them;
## - crafting takes the materials; floating takes a krathong, pays its band's reward once,
##   counts the day (at most 5), the top tier's rares and their server line;
## - the pageant: splendour, once a day, the best entry kept, the AI field the same on
##   every read, the result once, the winner's title by the hero's gender;
## - the world players' floats (seeded by time) and chat lines, the HUD chip, events;
## - the village's pier and stage (the interaction points), floating at the pier;
## - the Naga rises on the night only, in a levelling field, as the celestial serpent,
##   drops its scales and pieces, once a window;
## - the festival costume (pieces / points, festival only, its art), the menu tab;
## - the save record and items (valid, JSON round trip, repair, malformed refused).
##   godot --headless --path . res://tests/integration/loy_krathong_test.tscn
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
	LoyKrathong.test_time = t


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	Announcer.relay = false
	var look := FaceKit.default_look()
	look["gender"] = 1
	Game.new_profile(&"warrior", "Krathong QA", look)
	Game.profile.level = 60
	ZoneData.ensure()
	_dates()
	_exp()
	_drops()
	_crafting()
	_floating()
	_pageant()
	_world_players()
	_chip()
	_costume()
	_saves()
	await _village()
	await _naga()
	await _tab()
	WorldPresence.clock_offset = 0.0
	LoyKrathong.test_time = -1.0
	print("LOY KRATHONG: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _dates() -> void:
	check(float(LoyKrathong.START) == thai(2026, 11, 22, 7, 40) and float(LoyKrathong.END) == thai(2026, 11, 26, 7, 40), "22 Nov 07:40 to 26 Nov 07:40 Thai time")
	check(float(LoyKrathong.NIGHT_START) == thai(2026, 11, 24, 19) and float(LoyKrathong.NIGHT_END) == thai(2026, 11, 24, 23), "the night: Tue 24 Nov 19:00-23:00")
	check(WorldEvents.weekday(float(LoyKrathong.NIGHT_START)) == 2, "24 Nov 2026 is a Tuesday")
	check(not LoyKrathong.on(thai(2026, 11, 22, 7, 39)) and LoyKrathong.on(thai(2026, 11, 22, 7, 40)) and LoyKrathong.on(thai(2026, 11, 26, 7, 39)) and not LoyKrathong.on(thai(2026, 11, 26, 7, 40)), "on to the minute")
	check(not LoyKrathong.night_on(thai(2026, 11, 24, 18, 59)) and LoyKrathong.night_on(thai(2026, 11, 24, 19)) and LoyKrathong.night_on(thai(2026, 11, 24, 22, 59)) and not LoyKrathong.night_on(thai(2026, 11, 24, 23)) and not LoyKrathong.night_on(thai(2026, 11, 23, 20)), "the night window, that night only")
	check(float(LoyKrathong.RESULT_AT) == thai(2026, 11, 25, 20), "the pageant's result on the last evening, 25 Nov 20:00")
	check(LoyKrathong.date_text(float(LoyKrathong.START)) == "22 พ.ย. 07:40", "its date in Thai")
	LoyKrathong.enabled = false
	check(not LoyKrathong.on(thai(2026, 11, 23, 12)) and LoyKrathong.chip_text(thai(2026, 11, 23, 12)) == "", "LoyKrathong.enabled switches it off")
	LoyKrathong.enabled = true
	WorldEvents.festival_enabled = false
	check(not LoyKrathong.on(thai(2026, 11, 23, 12)) and not LoyKrathong.night_on(thai(2026, 11, 24, 20)), "WorldEvents.festival_enabled = false switches it off too")
	WorldEvents.festival_enabled = true
	# The dragon hunt was moved clear of it.
	check(not DragonHunt.is_on(thai(2026, 11, 24, 12)) and DragonHunt.is_on(thai(2026, 11, 27, 7, 40)), "the dragon hunt starts after the festival (27 Nov)")


func _exp() -> void:
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 24, 19, 30)), 3.0), "the night 19:00-21:00: evening x2 + night x2 = x3 (%s)" % WorldEvents.exp_multiplier(thai(2026, 11, 24, 19, 30)))
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 24, 22)), 2.0), "21:00-23:00: x2")
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 24, 23, 30)), 1.0) and is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 24, 18)), 1.0), "nothing outside the night")
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 25, 19, 30)), 2.0), "another evening keeps its plain x2")
	WorldEvents.festival_enabled = false
	check(is_equal_approx(WorldEvents.exp_multiplier(thai(2026, 11, 24, 19, 30)), 2.0), "the base-rate switch leaves the evening's x2 alone")
	WorldEvents.festival_enabled = true


func _drops() -> void:
	var t := thai(2026, 11, 23, 12)
	var fields: Array = []
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if WeeklyCollect.zone_ok(z) and not z.get("camps", []).is_empty():
			fields.append(z)
	check(fields.size() >= 5, "hunting grounds to test (%d)" % fields.size())
	var ok := true
	var spread := []
	for k in LoyKrathong.MATS.size():
		var want := 60.0 * LoyKrathong.REF_PACE / float(LoyKrathong.RATE[k])
		for z in fields:
			var h := LoyKrathong.per_hour(k, z)
			ok = ok and absf(h - want) / want < 0.02
		spread.append(snappedf(want, 0.1))
	check(ok, "every field's hour of hunting finds the same: %s an hour (newcomer to ★300)" % str(spread))
	check(is_equal_approx(LoyKrathong.per_hour(0, fields[0]), 20.0) and is_equal_approx(LoyKrathong.per_hour(3, fields[0]), 0.4), "~20 ใบตอง and ~0.4 เกล็ดพญานาค an hour")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var meadow := ZoneData.get_zone(&"meadow")
	var counts := [0, 0, 0, 0]
	var kills := int(round(WeeklyCollect.pace_of(meadow) * 60.0 * 10.0))
	for i in kills:
		for item in LoyKrathong.kill_drops(meadow, "", 0.0, t, rng):
			counts[LoyKrathong.MATS.find(String(item.id))] += 1
	print("loy_krathong_test: ten hours in the meadow (%d kills): %s" % [kills, str(counts)])
	check(absi(int(counts[0]) - 200) < 40 and absi(int(counts[1]) - 80) < 25 and int(counts[2]) > 10 and int(counts[2]) < 45 and int(counts[3]) <= 15, "the dice agree with the rates (%s)" % str(counts))
	check(LoyKrathong.kill_drops(meadow, "", 0.0, thai(2026, 11, 21, 12), rng).is_empty() and LoyKrathong.kill_drops(meadow, "", 0.0, thai(2026, 11, 27, 12), rng).is_empty(), "nothing before or after the festival")
	var none := true
	for i in 500:
		none = none and LoyKrathong.kill_drops(ZoneData.get_zone(&"town"), "", 0.0, t, rng).is_empty()
	check(none, "nothing in the village")
	check(LoyKrathong.chance(3, meadow, WeeklyCollect.mult_of("world_boss")) > LoyKrathong.chance(3, meadow) * 19.0, "the world boss rolls x20")


func _give(id: String, n: int) -> void:
	Game.give_or_store(ItemData.jewel(id, n))


func _crafting() -> void:
	var t := thai(2026, 11, 23, 12)
	check(LoyKrathong.craft(0, t) != "ok", "no leaves, no krathong")
	_give("lk_leaf", 9)
	_give("lk_lotus", 2)
	_give("lk_candle", 1)
	_give("lk_scale", 1)
	check(LoyKrathong.craft(0, thai(2026, 11, 21, 12)) != "ok", "not before the festival")
	check(LoyKrathong.craft(0, t) == "ok" and Game.jewel_count("lk_leaf") == 6 and Game.jewel_count("lk_k0") == 1, "กระทงใบตอง: three leaves")
	check(LoyKrathong.craft(3, t) == "ok" and Game.jewel_count("lk_leaf") == 3 and Game.jewel_count("lk_lotus") == 0 and Game.jewel_count("lk_candle") == 0 and Game.jewel_count("lk_scale") == 0 and Game.jewel_count("lk_k3") == 1, "กระทงเทพนาคา: leaves, lotuses, a candle and a scale")
	check(LoyKrathong.craft(1, t).begins_with("ดอกบัวไม่พอ"), "a lotus krathong needs lotuses (%s)" % LoyKrathong.craft(1, t))
	for k in LoyKrathong.KRATHONGS.size():
		check(ItemData.JEWELS.has(String(LoyKrathong.KRATHONGS[k].id)) and ItemData.name_of(LoyKrathong.krathong(k)) == String(LoyKrathong.KRATHONGS[k].name), "krathong %d is a stackable item" % k)
		check(ResourceLoader.exists("res://assets/icons/ui/jewel_%s.svg" % String(LoyKrathong.KRATHONGS[k].id)), "krathong %d has its icon" % k)
	for id in LoyKrathong.MATS + [LoyKrathong.PIECE]:
		check(ItemData.JEWELS.has(id) and ResourceLoader.exists("res://assets/icons/ui/jewel_%s.svg" % id), "%s is an item with an icon" % id)


func _floating() -> void:
	var t := thai(2026, 11, 23, 12)
	Game.profile.erase(LoyKrathong.KEY)
	# The rewards grow with the band.
	var grows := true
	for tier in range(1, 6):
		grows = grows and int(LoyKrathong.rewards(0, tier, "warrior").gold) > int(LoyKrathong.rewards(0, tier - 1, "warrior").gold)
		grows = grows and int(LoyKrathong.rewards(1, tier, "warrior").items[0].count) >= int(LoyKrathong.rewards(1, tier - 1, "warrior").items[0].count)
	check(grows, "the rewards grow with the hero's band")
	check(String(LoyKrathong.rewards(2, 3, "warrior").items[0].id) == "chaos" and float(LoyKrathong.rewards(2, 3, "warrior").core) > 0.0, "กระทงทองคำ: chaos jewels and a set-core chance")
	check(LoyKrathong.float_krathong(1, "x", t).result != "ok", "no lotus krathong in the bag: nothing floats")
	check(LoyKrathong.clean_wish("  ขอให้\nตีบวกติด   +15  ") == "ขอให้ ตีบวกติด +15" and LoyKrathong.clean_wish("ก".repeat(90)).length() == LoyKrathong.WISH_MAX, "a wish: one line, at most %d characters" % LoyKrathong.WISH_MAX)
	check(not LoyKrathong.clean_wish("ไอ้ควายขอให้รวย").contains("ควาย"), "rude words starred out")
	var gold := int(Game.profile.gold)
	var heard: Array = []
	var sink := func(e: Dictionary): heard.append(e)
	LoyKrathong.listen(sink)
	var r := LoyKrathong.rewards(0, WeeklyCollect.hero_tier(), "warrior")
	var potion := String(r.items[0].id)
	var before := _count_potion(potion)
	var out := LoyKrathong.float_krathong(0, "ขอให้ตีบวกติด", t)
	check(String(out.result) == "ok" and int(Game.profile.gold) == gold + int(r.gold) and _count_potion(potion) == before + 5, "กระทงใบตอง floated: gold and potions (%s)" % str(out))
	check(Game.jewel_count("lk_k0") == 0 and LoyKrathong.points() == 10 and LoyKrathong.floats_left(t) == LoyKrathong.DAILY_FLOATS - 1, "the krathong is gone, 10 points, a float counted")
	check(heard.size() == 1 and String(heard[0].wish) == "ขอให้ตีบวกติด" and bool(heard[0].hero), "the pier hears of it, wish and all")
	check(LoyKrathong.float_krathong(0, "again", t).result != "ok" and int(Game.profile.gold) == gold + int(r.gold), "paid once: no second reward without a second krathong")
	# The daily cap.
	_give("lk_k1", 6)
	var floated := 1
	for i in 6:
		if String(LoyKrathong.float_krathong(1, "", t).result) == "ok":
			floated += 1
	check(floated == LoyKrathong.DAILY_FLOATS and LoyKrathong.floats_left(t) == 0 and Game.jewel_count("lk_k1") == 2, "at most %d floats a day (%d)" % [LoyKrathong.DAILY_FLOATS, floated])
	check(LoyKrathong.float_problem(1, t).contains("ครบ"), "the sixth is refused")
	check(LoyKrathong.floats_left(thai(2026, 11, 24, 0, 5)) == LoyKrathong.DAILY_FLOATS and String(LoyKrathong.float_krathong(1, "", thai(2026, 11, 24, 0, 5)).result) == "ok", "a new Thai day, new floats")
	check(LoyKrathong.float_krathong(1, "", thai(2026, 11, 26, 8)).result != "ok", "none after the festival")
	LoyKrathong.unlisten(sink)
	# The top tier's rares: their odds, and the server line.
	var roll := RandomNumberGenerator.new()
	roll.seed = 99
	var kinds := {}
	for i in 20000:
		var rare := LoyKrathong.rare_roll(roll)
		var id := String(rare.items[0].get("id", rare.items[0].get("kind", "")))
		kinds[id] = int(kinds.get(id, 0)) + 1
	print("loy_krathong_test: 20000 กระทงเทพนาคา rare rolls: %s" % str(kinds))
	check(absi(int(kinds.get(SkyIsleLoot.EGG, 0)) - 200) < 60 and absi(int(kinds.get(SkyIsleLoot.FRAGMENT, 0)) - 2000) < 200 and int(kinds.get(LoyKrathong.PIECE, 0)) > 15000 and int(kinds.get(LoyKrathong.COSTUME, 0)) > 100, "egg 1%%, costume 1%%, fragments 10%%, pieces the rest (%s)" % str(kinds))
	var seed_value := 1
	while seed_value < 100000:
		roll.seed = seed_value
		roll.randf()
		if roll.randf() < 0.11 and roll.randf() >= 0.0:
			roll.seed = seed_value
			roll.randf()
			var r2 := roll.randf()
			if r2 >= 0.02 and r2 < 0.11:
				break
		seed_value += 1
	roll.seed = seed_value
	Announcer.history.clear()
	_give("lk_k3", 1)
	var big := LoyKrathong.float_krathong(3, "ขอให้ได้ปีกเทพ", thai(2026, 11, 25, 9), roll)
	check(String(big.result) == "ok" and bool(big.jackpot) and Game.jewel_count(SkyIsleLoot.FRAGMENT) >= 3, "a rare from กระทงเทพนาคา (%s)" % str(big.get("items", [])))
	check(Announcer.history.any(func(h): return String(h.text).contains("Krathong QA") and String(h.text).contains(ItemData.JEWELS[SkyIsleLoot.FRAGMENT].name)) , "told to the server (Announcer.broadcast jackpot)")


func _count_potion(id: String) -> int:
	var n := 0
	for item in Game.profile.inv:
		if String(item.get("kind", "")) == "potion" and String(item.get("id", "")) == id:
			n += int(item.get("count", 1))
	return n


func _pageant() -> void:
	Game.profile.erase(LoyKrathong.KEY)
	var t := thai(2026, 11, 22, 12)
	var bare := LoyKrathong.splendour({}, "")
	var gear := {}
	for slot in ItemData.SLOTS:
		gear[slot] = {"rarity": 4, "plus": 15}
	gear["wings"] = {"rarity": 4, "plus": 12}
	var full := LoyKrathong.splendour(gear, LoyKrathong.COSTUME)
	check(bare == 0 and full >= 95 and full <= 100, "splendour: bare 0, the festival costume with mythic +15 gear and wings ~100 (%d)" % full)
	check(LoyKrathong.splendour(gear, LoyKrathong.COSTUME) > LoyKrathong.splendour(gear, "royal") and LoyKrathong.splendour(gear, "royal") > LoyKrathong.splendour(gear, ""), "the festival costume counts most, any costume helps")
	var first := LoyKrathong.enter(t)
	check(String(first.result) == "ok" and int(first.votes) == LoyKrathong.hero_splendour() * LoyKrathong.VOTE_PER + LoyKrathong.crowd("Krathong QA", WorldEvents.day_of(t)), "an entry: splendour x %d + the day's crowd" % LoyKrathong.VOTE_PER)
	check(LoyKrathong.enter(t + 3600.0).result != "ok", "once a day")
	var second := LoyKrathong.enter(thai(2026, 11, 23, 12))
	check(String(second.result) == "ok" and int(LoyKrathong.peek().pg) == maxi(int(first.votes), int(second.votes)) and int(LoyKrathong.peek().pgg) == 1, "the next day again, the best kept, entered as a girl")
	check(LoyKrathong.enter(thai(2026, 11, 25, 20, 30)).result != "ok", "no entries after the result")
	var girls := LoyKrathong.contestants(1)
	var boys := LoyKrathong.contestants(0)
	check(girls.size() == LoyKrathong.PAGEANT_FIELD and boys.size() == LoyKrathong.PAGEANT_FIELD, "%d AI contestants a stage" % LoyKrathong.PAGEANT_FIELD)
	check(girls.all(func(i): return int(WorldPlayers.look(i).gender) == 1) and boys.all(func(i): return int(WorldPlayers.look(i).gender) == 0), "girls for นางนพมาศ, boys for หนุ่มลอยกระทง")
	var a := LoyKrathong.standings(1)
	LoyKrathong.reset()
	var b := LoyKrathong.standings(1)
	check(str(a) == str(b) and a.size() == LoyKrathong.PAGEANT_FIELD + 1, "the stage reads the same every time, the hero on it")
	var sorted := true
	for k in range(1, a.size()):
		sorted = sorted and int(a[k - 1].votes) >= int(a[k].votes)
	check(sorted and a.any(func(row): return bool(row.hero)), "ranked by votes")
	print("loy_krathong_test: the นางนพมาศ stage: %s" % str(a.map(func(row): return "%s %d" % [row.name, row.votes])))
	check(LoyKrathong.settle(thai(2026, 11, 25, 19)) == "", "nothing before the result")
	# The hero takes the crown.
	LoyKrathong.data()["pg"] = 999999
	var chaos := Game.jewel_count("chaos")
	check(LoyKrathong.settle(thai(2026, 11, 25, 20, 1)) == "ok" and LoyKrathong.hero_rank() == 1, "the result: first place")
	check(int(Game.profile.flags.get(LoyKrathong.QUEEN_FLAG, 0)) == 1 and Achievements.is_earned("t_lk_queen", Game.profile) and not Achievements.is_earned("t_lk_king", Game.profile), "the title นางนพมาศ ๒๕๖๙ (a girl's)")
	check(Achievements.set_title(Game.profile, Achievements.index_of("t_lk_queen")) and Achievements.title_of(Game.profile) == "นางนพมาศ ๒๕๖๙", "worn")
	check(Game.jewel_count("chaos") == chaos + 10 and LoyKrathong.settle(thai(2026, 11, 25, 21)) == "" and Game.jewel_count("chaos") == chaos + 10, "the prize once")
	check(Achievements.TABLE[Achievements.TABLE.size() - 2].id == "t_lk_queen" and Achievements.TABLE[Achievements.TABLE.size() - 1].id == "t_lk_king", "the titles appended to the table")
	Announcer.history.clear()
	LoyKrathong.reset()
	LoyKrathong.tick(thai(2026, 11, 25, 20, 2))
	check(Announcer.history.any(func(h): return String(h.text).contains("ประกาศผล") and String(h.text).contains("Krathong QA")), "the result is told to everyone")


func _world_players() -> void:
	var t := thai(2026, 11, 23, 15)
	var day := LoyKrathong.ai_floats(t)
	var again := LoyKrathong.ai_floats(t)
	check(str(day) == str(again), "the world players' floats are read off the clock")
	var n_day := 0
	var n_night := 0
	var ok := true
	for k in 80:
		var e := LoyKrathong.ai_float(int(floor(thai(2026, 11, 23, 19) / LoyKrathong.FLOAT_SLOT)) + k)
		var f := LoyKrathong.ai_float(int(floor(float(LoyKrathong.NIGHT_START) / LoyKrathong.FLOAT_SLOT)) + k)
		n_day += 0 if e.is_empty() else 1
		n_night += 0 if f.is_empty() else 1
		for x in [e, f]:
			if not x.is_empty():
				ok = ok and LoyKrathong.WISHES.has(String(x.wish)) and int(x.tier) >= 0 and int(x.tier) < 4 and String(x.name) != ""
	check(n_day > 25 and n_night > n_day, "someone floats a krathong every minute or two, more on the night (%d / %d)" % [n_day, n_night])
	check(ok, "each with a wish, a tier and a name")
	check(LoyKrathong.ai_floats(thai(2026, 11, 21, 12)).is_empty() and LoyKrathong.ai_floats(thai(2026, 11, 27, 12)).is_empty(), "none outside the festival")
	var lines := 0
	var night_lines := 0
	for i in 40:
		var s := WorldPlayers.state(i % WorldPlayers.size(), t)
		var line := LoyKrathong.chat_line(s, i * 31, t)
		if line != "":
			lines += 1
			check(not line.contains("%"), "a whole line (%s)" % line)
		if LoyKrathong.chat_line(s, i * 31, thai(2026, 11, 24, 20, 5)) in LoyKrathong.CHAT_NIGHT:
			night_lines += 1
	check(lines == 40 and night_lines > 0, "the festival's lines, the night's on the night (%d)" % night_lines)
	check(LoyKrathong.chat_line(WorldPlayers.state(0, t), 5, thai(2026, 11, 28, 12)) == "", "no festival line after it")
	var said := 0
	for k in 400:
		var s := WorldPlayers.state(k % WorldPlayers.size(), t)
		var line := WorldChat.line_for(s, k * 7919 + 3, t)
		if line in LoyKrathong.CHAT or LoyKrathong.CHAT.any(func(c: String): return c.split("%")[0] != "" and line.begins_with(c.split("%")[0])):
			said += 1
	check(said > 5, "the world chat says them now and then (%d of 400)" % said)
	check(ChatBrain.intent_of("ลอยกระทงที่ไหน") == "loyk" and ChatBrain.intent_of("พญานาคขึ้นกี่โมง") == "loyk", "asked about the festival")
	check(LoyKrathong.chat_answer(0, t).contains("ท่าน้ำ") and LoyKrathong.chat_answer(0, thai(2026, 11, 20, 12)).contains("22 พ.ย."), "the answer: where to float, or when it starts")


func _chip() -> void:
	Game.profile.erase(LoyKrathong.KEY)
	var t := thai(2026, 11, 23, 12)
	var chip := LoyKrathong.chip_text(t)
	check(chip.begins_with(LoyKrathong.TITLE) and chip.contains("ลอยได้อีก 5") and WorldEvents.chip_lines(t).has(chip), "the HUD chip (%s)" % chip)
	check(WorldEvents.chip_lines(t).find(chip) <= 1, "near the top of the chip")
	check(LoyKrathong.chip_text(thai(2026, 11, 24, 19, 10)).begins_with("คืนลอยกระทง") and LoyKrathong.chip_text(thai(2026, 11, 24, 20, 5)).begins_with(LoyKrathong.NAGA_NAME), "the night, then the Naga")
	check(LoyKrathong.chip_text(thai(2026, 11, 27, 12)) == "", "no chip after it")
	var ids := WorldEvents.current(thai(2026, 11, 24, 21, 5)).map(func(e): return String(e.id))
	check(ids.has("loyk") and ids.has("loyk_night") and ids.has("naga") and ids.has("exp2") == false, "WorldEvents.current (%s)" % str(ids))


func _costume() -> void:
	var t := thai(2026, 11, 23, 12)
	check(RewardShop.COSTUMES.has(LoyKrathong.COSTUME) and RewardShop.costume_rarity(LoyKrathong.COSTUME) == 4, "the festival costume is a mythic costume")
	check(LoyKrathong.costume_problem("pieces", t).contains("ไม่พอ") and LoyKrathong.costume_problem("pieces", thai(2026, 11, 27, 12)).contains("เทศกาล"), "pieces needed, festival only")
	at(thai(2026, 11, 28, 12))
	check(RewardShop.problem("costume", LoyKrathong.COSTUME).contains(LoyKrathong.TITLE), "the reward shop sells it only during the festival")
	check(not RewardShop.world_cosmetics(0, t).values().has(LoyKrathong.COSTUME), "world players do not buy it with coins")
	at(t)
	_give(LoyKrathong.PIECE, LoyKrathong.COSTUME_PIECES)
	var have := Game.jewel_count(LoyKrathong.PIECE)
	check(LoyKrathong.exchange_costume("pieces", t) == "ok" and RewardShop.owns(LoyKrathong.COSTUME) and Game.jewel_count(LoyKrathong.PIECE) == have - LoyKrathong.COSTUME_PIECES, "exchanged for %d pieces" % LoyKrathong.COSTUME_PIECES)
	var index := RewardShop.bag_index(LoyKrathong.COSTUME)
	check(index >= 0 and RewardShop.valid_costume_item(Game.profile.inv[index]) and Game._valid_item(Game.profile.inv[index]), "a costume item in the bag")
	check(LoyKrathong.exchange_costume("points", t) != "ok", "once")
	check(RewardShop.wear_from_bag(index) == "ok" and RewardShop.worn_costume() == LoyKrathong.COSTUME, "worn from the costume slot")
	check(LoyKrathong.hero_splendour() >= 35, "it counts on the stage")
	var parts := CostumeArt.parts(LoyKrathong.COSTUME)
	var built := parts.size() == 5
	for p in parts:
		built = built and CostumeArt.mesh_of(LoyKrathong.COSTUME, String(p[1]), false) != null
	check(built and CostumeArt.MOTES.has(LoyKrathong.COSTUME), "its art: crown, sabai, belt, armlets, candle motes")
	# The points path on a fresh record.
	RewardShop.take_off_costume()
	var shop := RewardShop.data()
	(shop.own as Array).erase(LoyKrathong.COSTUME)
	var i2 := RewardShop.bag_index(LoyKrathong.COSTUME)
	if i2 >= 0:
		Game.profile.inv.remove_at(i2)
	LoyKrathong.data()["pts"] = LoyKrathong.COSTUME_POINTS
	check(LoyKrathong.exchange_costume("points", t) == "ok" and LoyKrathong.points() == 0 and RewardShop.bag_index(LoyKrathong.COSTUME) >= 0, "or for %d festival points" % LoyKrathong.COSTUME_POINTS)


func _saves() -> void:
	Game.profile[LoyKrathong.KEY] = {"day": 20415, "n": 3, "fl": 12, "pts": 420, "pg": 1234, "pgd": 20415, "pgg": 1, "got": 3}
	Game.profile.inv.append(ItemData.jewel("lk_scale", 2))
	Game.profile.inv.append(ItemData.jewel("lk_k2", 1))
	var data: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	check(Game._valid_profile(data), "a profile with the record and the items is valid")
	check(data[LoyKrathong.KEY].pts is float, "JSON brings numbers back as floats")
	var fixed := Game._repair(data)
	check(fixed[LoyKrathong.KEY].pts is int and int(fixed[LoyKrathong.KEY].pg) == 1234 and int(fixed[LoyKrathong.KEY].day) == 20415, "_repair makes them ints again")
	for bad in [[], {"junk": 1}, {"n": 101}, {"pgg": 2}, {"got": 4}, {"pts": -1}, {"pts": 1.5}, {"day": -2}, {"pts": "9"}]:
		var copy := data.duplicate(true)
		copy[LoyKrathong.KEY] = bad
		check(not Game._valid_profile(copy), "refused: %s" % str(bad))
	var junk := data.duplicate(true)
	junk.inv.append({"kind": "jewel", "id": "lk_k9", "count": 1})
	check(not Game._valid_profile(junk), "an unknown lk_ item is refused")
	var broken := data.duplicate(true)
	broken[LoyKrathong.KEY] = {"got": 99}
	broken = Game._repair(broken)
	check(not broken.has(LoyKrathong.KEY), "_repair drops a broken record")
	check(LoyKrathong.valid({}) and LoyKrathong.valid({"day": -1, "n": 0, "fl": 0, "pts": 0, "pg": 0, "pgd": -1, "pgg": 0, "got": 0}), "empty and fresh records are valid")


func _village() -> void:
	at(thai(2026, 11, 23, 20))
	Game.current_zone = &"town"
	Game.profile["spawn_override"] = ""
	var zone := Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 5
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 1200:
		if zone.is_built:
			break
		await get_tree().process_frame
	var pier := LoyKrathongPier.current
	check(zone.is_built and pier != null and pier.get_parent() == zone, "the village has its pier during the festival")
	if pier == null:
		zone.queue_free()
		return
	var roles := zone.npcs.map(func(n): return n.role)
	check(roles.has("loyk_pier") and roles.has("loyk_stage"), "the pier and the stage are interaction points (%s)" % str(roles))
	check(pier.find_child("FullMoon", true, false) != null and pier.find_child("SkyLanterns", true, false) != null and pier.find_child("BulbHalos", true, false) != null, "the moon, the sky lanterns and the lights")
	var point: Node3D = null
	for n in zone.npcs:
		if n.role == "loyk_pier":
			point = n
	zone.hero.global_position = point.global_position
	check(LoyKrathongPier.hero_at_pier(), "the hero at the pier")
	zone.hero.global_position = Vector3(0, 0, 19)
	check(not LoyKrathongPier.hero_at_pier(), "not from the plaza")
	# A float at the pier sets a krathong on the water with the wish over it.
	Game.profile.erase(LoyKrathong.KEY)
	_give("lk_k2", 1)
	var floats := pier._floats.size()
	LoyKrathong.float_krathong(2, "ขอให้ได้ปีกเทพ", thai(2026, 11, 23, 20))
	check(pier._floats.size() == floats + 1, "the krathong sets off")
	var last: Node3D = pier._floats[pier._floats.size() - 1].node
	var label := last.get_node_or_null("Wish") as Label3D
	check(label != null and label.text.contains("ขอให้ได้ปีกเทพ") and label.text.contains("Krathong QA"), "its wish floats above it")
	pier._sync_floats(thai(2026, 11, 23, 20))
	check(pier._floats.size() >= floats + 1 and pier._floats.size() <= LoyKrathongPier.MAX_FLOATS, "the world players' krathongs join it")
	var p0 := LoyKrathongPier.path_at(0.0, 0.0)
	var p1 := LoyKrathongPier.path_at(1.0, 0.0)
	check(p0.x < 0.0 and p1.x > 0.0 and absf(p0.y - LoyKrathongPier.WATER_Y) < 0.01, "they drift from the pier across the pond")
	for k in 4:
		check(LoyKrathongPier.krathong_mesh(k) != null and LoyKrathongPier.krathong_mesh(k) == LoyKrathongPier.krathong_mesh(k), "krathong %d: one cached mesh" % k)
	zone.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Outside the festival the village is as it was.
	at(thai(2026, 11, 28, 12))
	var plain := Zone.new()
	plain.zone_id = &"town"
	plain.layout_seed = 5
	add_child(plain)
	plain.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 1200:
		if plain.is_built:
			break
		await get_tree().process_frame
	check(plain.is_built and LoyKrathongPier.current == null and not plain.npcs.any(func(n): return n.role == "loyk_pier"), "no pier after the festival")
	plain.queue_free()
	await get_tree().process_frame


func _naga() -> void:
	check(LoyKrathong.naga_now(thai(2026, 11, 24, 19, 30)).is_empty() and not LoyKrathong.naga_now(thai(2026, 11, 24, 20, 5)).is_empty() and not LoyKrathong.naga_now(thai(2026, 11, 24, 22, 19)).is_empty() and LoyKrathong.naga_now(thai(2026, 11, 24, 22, 21)).is_empty(), "the Naga rises at 20:00, 21:00, 22:00 for 20 minutes")
	check(LoyKrathong.naga_now(thai(2026, 11, 23, 20, 5)).is_empty(), "the night only")
	var w20 := int(LoyKrathong.naga_now(thai(2026, 11, 24, 20, 5)).window)
	var w21 := int(LoyKrathong.naga_now(thai(2026, 11, 24, 21, 5)).window)
	check(w20 != w21, "each window its own")
	at(thai(2026, 11, 24, 20, 5))
	Game.current_zone = &"meadow"
	Game.profile["spawn_override"] = ""
	Game.profile.flags.erase(LoyKrathong.NAGA_FLAG)
	var zone := LootZone.new()
	zone.zone_id = &"meadow"
	zone.layout_seed = 11
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 1200:
		if zone.is_built:
			break
		await get_tree().process_frame
	zone._tick_naga()
	var naga: Mob = zone._naga
	check(naga != null and naga.has_meta("naga") and String(naga.template.get("celestial", "")) == "naga" and naga.visual is CelestialDragonVisual, "the Naga rises in the meadow as the celestial serpent")
	if naga == null:
		zone.queue_free()
		return
	var plain := MonsterData.stats_for(StringName(zone.data.boss.monster), int(zone.data.boss.level))
	check(naga.max_hp == int(float(plain.hp) * LoyKrathong.NAGA_HP) and String(naga.template.name) == LoyKrathong.NAGA_NAME, "the field boss's HP x%d, named %s" % [int(LoyKrathong.NAGA_HP), LoyKrathong.NAGA_NAME])
	check(WorldBoss.of(naga) != null and naga.find_child("NagaWater", true, false) != null, "the world boss's moves and the churning water")
	check(CelestialDragon.has("naga") and int(CelestialDragon.pose("naga").count) > 20 and String(CelestialDragon.KINDS.naga.horns) == "crest", "its own kind of serpent: crested and crowned")
	zone.items.clear()
	naga.take_hit(naga.hp, false, Color.WHITE, zone.hero)
	await get_tree().process_frame
	await get_tree().process_frame
	var scales := 0
	var pieces := 0
	for item in zone.items:
		if String(item.get("id", "")) == "lk_scale":
			scales += int(item.count)
		if String(item.get("id", "")) == LoyKrathong.PIECE:
			pieces += int(item.count)
	check(naga.is_dead() and scales >= 2 and pieces >= 2, "it drops เกล็ดพญานาค (%d) and costume pieces (%d)" % [scales, pieces])
	check(int(Game.profile.flags.get(LoyKrathong.NAGA_FLAG, -1)) == w20 and LoyKrathong.naga_done(w20), "once a window")
	zone._naga = null
	zone._tick_naga()
	check(zone._naga == null, "it does not rise again in the same window")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var eggs := 0
	for i in 5000:
		var d := LoyKrathong.naga_drops(rng)
		if String((d.jackpot as Dictionary).get("id", "")) == SkyIsleLoot.EGG:
			eggs += 1
	check(eggs > 50 and eggs < 160, "its rares: the egg about 2%% (%d of 5000)" % eggs)
	at(thai(2026, 11, 24, 23, 30))
	zone._tick_naga()
	check(zone._naga == null, "none after the night")
	zone.queue_free()
	await get_tree().process_frame


func _tab() -> void:
	at(thai(2026, 11, 23, 12))
	check(GameMenu.TABS.any(func(tab): return tab[0] == "loyk" and tab[1] == "ลอยกระทง"), "the menu has the tab")
	var menu := GameMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu.open_menu(&"loyk")
	await get_tree().process_frame
	var page := menu._content.find_child("LoyKrathongView", true, false)
	check(page != null, "the page")
	if page != null:
		for name in ["LoykCountdown", "LoykMats", "LoykWish", "LoykCraft_0", "LoykFloat_3", "LoykEnter", "LoykPageant", "LoykCostume", "LoykCostume_pieces"]:
			check(page.find_child(name, true, false) != null, "the page has %s" % name)
		var texts: Array = []
		for node in page.find_children("*", "Label", true, false):
			texts.append((node as Label).text)
		check(texts.any(func(x: String): return x.contains("22 พ.ย.") and x.contains("24 พ.ย.")), "its dates and the night")
		check(texts.any(func(x: String): return x.contains("ไปที่ท่าน้ำ")), "floating is at the pier")
		_give("lk_leaf", 3)
		(page.find_child("LoykCraft_0", true, false) as Button).pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		check(Game.jewel_count("lk_k0") >= 1, "made from the page")
	menu.close_menu()
	menu.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
