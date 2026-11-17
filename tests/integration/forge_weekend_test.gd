extends Node
## สุดสัปดาห์ตีบวก, the forge weekend that follows the x5 festival (WorldEvents.forge_*):
## - the dates: from FESTIVAL5_END (20 Nov 2026 07:40 Thai time) every Saturday and Sunday
##   (Thai time), never before it, never on a weekday;
## - the odds: +FORGE_BONUS on every step that can fail, capped at FORGE_CAP, the sure
##   steps sure, ItemData.enhance_chance itself untouched; the real forge
##   (Game.enhance_item) succeeds that much more often; the switch for tests;
## - what players see: the forge screen's line and the odds on its button, the HUD chip;
## - the world players' forge simulation (WorldGear) keeps the plain odds.
##   godot --headless --path . res://tests/integration/forge_weekend_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Unix time of a Thai-time moment.
func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Forge QA")
	_dates()
	_odds()
	_forge()
	_chip()
	await _screen()
	_world_players()
	WorldPresence.clock_offset = 0.0
	print("FORGE WEEKEND: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _dates() -> void:
	check(WorldEvents.FORGE_START == WorldEvents.FESTIVAL5_END and float(WorldEvents.FORGE_START) == thai(2026, 11, 20, 7, 40), "it follows the x5 festival: 20 Nov 2026 07:40 Thai time")
	check(not WorldEvents.forge_weekend_on(thai(2026, 11, 14, 12)) and not WorldEvents.forge_weekend_on(thai(2026, 11, 15, 23, 59)), "not on the festival's weekend before it")
	check(not WorldEvents.forge_weekend_on(thai(2026, 11, 20, 12)), "Friday 20 Nov is a weekday")
	check(WorldEvents.forge_weekend_on(thai(2026, 11, 21, 0, 0)) and WorldEvents.forge_weekend_on(thai(2026, 11, 22, 23, 59)), "all of Saturday 21 and Sunday 22 Nov (Thai time)")
	check(not WorldEvents.forge_weekend_on(thai(2026, 11, 20, 23, 59)) and not WorldEvents.forge_weekend_on(thai(2026, 11, 23, 0, 0)), "not a minute before or after")
	var weekends := 0
	var wrong := 0
	for d in 70:
		var t := thai(2026, 11, 21, 12) + float(d) * 86400.0
		if WorldEvents.forge_weekend_on(t):
			weekends += 1
		if WorldEvents.forge_weekend_on(t) != WorldEvents.is_weekend(t):
			wrong += 1
	check(weekends == 20 and wrong == 0, "and every weekend after it, the game's weekend (%d days of 70)" % weekends)
	WorldEvents.forge_weekend_enabled = false
	check(not WorldEvents.forge_weekend_on(thai(2026, 11, 21, 12)) and is_equal_approx(WorldEvents.enhance_chance_at(6, thai(2026, 11, 21, 12)), 0.5), "the tests' switch turns it off")
	WorldEvents.forge_weekend_enabled = true


func _odds() -> void:
	var sat := thai(2026, 11, 21, 15)
	var wed := thai(2026, 11, 25, 15)
	var ok_sure := true
	var ok_bonus := true
	var ok_plain := true
	var table: Array[String] = []
	for plus in ItemData.MAX_PLUS:
		var base := ItemData.enhance_chance(plus)
		var boosted := WorldEvents.enhance_chance_at(plus, sat)
		if base >= 1.0:
			ok_sure = ok_sure and boosted == 1.0
		else:
			ok_bonus = ok_bonus and is_equal_approx(boosted, minf(WorldEvents.FORGE_CAP, base + WorldEvents.FORGE_BONUS)) and boosted <= WorldEvents.FORGE_CAP
			table.append("+%d %d%%->%d%%" % [plus + 1, int(round(base * 100.0)), int(round(boosted * 100.0))])
		ok_plain = ok_plain and is_equal_approx(WorldEvents.enhance_chance_at(plus, wed), base)
	print("forge_weekend_test: ", ", ".join(table))
	check(ok_sure, "the sure steps (to +6) stay sure")
	check(ok_bonus and is_equal_approx(WorldEvents.FORGE_BONUS, 0.10), "every step that can fail gets +10 points, never above the cap")
	check(is_equal_approx(WorldEvents.enhance_chance_at(6, sat), 0.6) and is_equal_approx(WorldEvents.enhance_chance_at(14, sat), 0.35), "+7 at 60%, +15 at 35% on the weekend")
	check(ok_plain and is_equal_approx(ItemData.enhance_chance(6), 0.5) and is_equal_approx(ItemData.enhance_chance(14), 0.25), "weekdays and ItemData.enhance_chance keep the plain odds")


## The real forge: a +6 sword tried many times on a Saturday and on a Wednesday.
func _forge() -> void:
	var sword := _sword()
	Game.profile.inv.clear()
	Game.add_item(sword)
	sword = Game.profile.inv[0]
	var rates := []
	for t in [thai(2026, 11, 21, 15), thai(2026, 11, 25, 15)]:
		at(t)
		Game.rng.seed = 4242
		var wins := 0
		var tries := 3000
		Game.profile.inv.append({"kind": "jewel", "id": "pink", "count": tries})
		for k in tries:
			sword["plus"] = 6
			if Game.enhance_item(sword) == "ok":
				wins += 1
		rates.append(float(wins) / float(tries))
	print("forge_weekend_test: +7 from +6 succeeded %.3f on Saturday, %.3f on Wednesday" % [rates[0], rates[1]])
	check(absf(float(rates[0]) - 0.6) < 0.035, "Game.enhance_item succeeds about 60%% on the weekend (%.3f)" % rates[0])
	check(absf(float(rates[1]) - 0.5) < 0.035, "and about 50%% on a weekday (%.3f)" % rates[1])


func _chip() -> void:
	var sat := thai(2026, 11, 21, 15)
	var line := WorldEvents.forge_text(sat)
	check(line.begins_with("%s: โอกาสสำเร็จ +10%%" % WorldEvents.NAME_FORGE) and line.contains("ชม."), "the HUD line names it and counts down (%s)" % line)
	check(WorldEvents.chip_lines(sat).has(line) and WorldEvents.chip_lines(sat).has(WorldEvents.weekend_text(sat)), "on the HUD chip, beside the weekend jewel rush")
	check(WorldEvents.forge_text(thai(2026, 11, 25, 15)) == "" and not WorldEvents.chip_lines(thai(2026, 11, 14, 15)).any(func(l: String): return l.contains(WorldEvents.NAME_FORGE)), "not on a weekday, not before it started")
	check(WorldEvents.forge_text(thai(2026, 11, 22, 23)).contains("นาที") or WorldEvents.forge_text(thai(2026, 11, 22, 23)).contains("ชม."), "Sunday counts down to its own midnight")


## The forge screen shows the line and the boosted odds on the button.
func _screen() -> void:
	at(thai(2026, 11, 21, 15))
	Game.profile.inv.clear()
	var sword := _sword()
	sword["plus"] = 6
	Game.add_item(sword)
	Game.add_item(ItemData.jewel("pink", 3))
	var menu := GameMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu.forge_mode = true
	menu.open_menu(&"inventory")
	menu._selected_index = 0
	menu._rebuild()
	await get_tree().process_frame
	var line := menu._root.find_child("ForgeWeekend", true, false) as Label
	check(line != null and line.text == "สุดสัปดาห์ตีบวก: โอกาสสำเร็จ +10%", "the forge screen says สุดสัปดาห์ตีบวก: โอกาสสำเร็จ +10%% (%s)" % (line.text if line else "none"))
	var button := false
	for node in menu._root.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("ตีบวก +7") and (node as Button).text.contains("60%"):
			button = true
	check(button, "and its button shows 60%")
	at(thai(2026, 11, 25, 15))
	menu._rebuild()
	await get_tree().process_frame
	check(menu._root.find_child("ForgeWeekend", true, false) == null, "no line on a weekday")
	menu.close_menu()
	menu.queue_free()
	get_tree().paused = false
	await get_tree().process_frame


## The world players' forge runs in work, not time: the weekend leaves it alone.
func _world_players() -> void:
	var sat := thai(2026, 11, 22, 20)
	WorldGear.clear()
	var with_bonus := WorldGear.gear(3, sat)
	WorldGear.clear()
	WorldEvents.forge_weekend_enabled = false
	var without := WorldGear.gear(3, sat)
	WorldEvents.forge_weekend_enabled = true
	check(str(with_bonus) == str(without), "a world player's gear is the same with or without the forge weekend")
	var src := FileAccess.get_file_as_string("res://data/world_gear.gd")
	check(src.contains("ItemData.enhance_chance(low)") and not src.contains("enhance_chance_at"), "WorldGear forges at the plain odds")


func _sword() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	return ItemData.generate(40, &"warrior", rng, 1, "weapon")
