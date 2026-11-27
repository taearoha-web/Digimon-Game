extends Node
## The HUD's event box under the minimap (HUD._update_event_box): the events with a page
## (the Dragon Hunt, the weekly collection, Loy Krathong, Christmas) are buttons that show
## only while their event runs and open their page; the menu's tab bar no longer has them
## (GameMenu.EVENT_PAGES); the action buttons sit in a row above the skills.

var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Event QA", FaceKit.default_look())
	var hud := HUD.new()
	add_child(hud)
	await get_tree().process_frame
	var asked: Array[StringName] = []
	hud.menu_requested.connect(func(tab: StringName): asked.append(tab))
	var b: Dictionary = hud._event_buttons
	check(b.has(&"hunt") and b.has(&"weekly") and b.has(&"loyk") and b.has(&"xmas"), "one button per event with a page")
	# 27 Nov 2026 12:00: the Dragon Hunt and the weekly collection run; Loy Krathong is over.
	var t := thai(2026, 11, 27, 12)
	hud._update_event_box(t)
	check((b.hunt as Button).visible and (b.hunt as Button).text.begins_with(DragonHunt.NAME), "the Dragon Hunt's button shows while it runs (%s)" % (b.hunt as Button).text)
	check((b.weekly as Button).visible and (b.weekly as Button).text.contains(WeeklyCollect.NAME), "the weekly collection's button shows")
	check(not (b.loyk as Button).visible and LoyKrathong.chip_text(t) == "", "Loy Krathong is over: no button")
	check(not (b.xmas as Button).visible, "Christmas not started: no button")
	check(not hud._event_label.text.contains(DragonHunt.NAME) and not hud._event_label.text.contains(WeeklyCollect.NAME), "an event with a button is not repeated as a plain line")
	check(hud._event_chip.visible, "the box shows")
	(b.hunt as Button).pressed.emit()
	(b.weekly as Button).pressed.emit()
	check(asked == [&"hunt", &"weekly"], "a tap opens that event's page (%s)" % [asked])
	# 2 Dec: Christmas runs (its button opens the reward shop: the Santa costume).
	t = thai(2026, 12, 2, 12)
	hud._update_event_box(t)
	check((b.xmas as Button).visible and (b.xmas as Button).text.contains(Christmas.TITLE), "Christmas's button shows while it runs")
	(b.xmas as Button).pressed.emit()
	check(asked.back() == &"reward", "it opens the reward shop")
	# Between hunts the hunt's button is gone; after Christmas, its button too.
	t = thai(2027, 1, 10, 12)
	hud._update_event_box(t)
	check(not (b.hunt as Button).visible or DragonHunt.chip_text(t) != "", "the hunt's button follows its window")
	check(not (b.xmas as Button).visible, "Christmas over: its button is gone")
	# The menu: the event pages open by id but are not in the tab bar.
	for e in GameMenu.EVENT_PAGES:
		check(not GameMenu.TABS.any(func(tab): return tab[0] == e[0]), "%s is not in the tab bar" % e[0])
	var menu := GameMenu.new()
	add_child(menu)
	for e in GameMenu.EVENT_PAGES:
		menu.open_menu(StringName(e[0]))
		await get_tree().process_frame
		check(menu.current_tab == StringName(e[0]) and menu._content.get_child_count() > 0, "the %s page opens" % e[0])
	menu.close_menu()
	# The action buttons: one row above the skills, clear of each other, the skills and attack.
	for canvas in [Vector2(1558, 720), Vector2(1280, 720), Vector2(1280, 960)]:
		var lay := HUD.action_layout(canvas)
		var row: Array = lay.utility + [lay.raven, lay.raven_mode]
		var ok := true
		for i in row.size():
			ok = ok and is_equal_approx((row[i] as Vector2).y, (row[0] as Vector2).y) and (row[i] as Vector2).y < HUD.SKILL_ROW_Y - HUD.SKILL_RADIUS - 28.0 + 0.1
			for j in row.size():
				if i != j:
					ok = ok and (row[i] as Vector2).distance_to(row[j]) >= 56.0
			for c in lay.skills:
				ok = ok and (row[i] as Vector2).distance_to(c) >= HUD.SKILL_RADIUS + 28.0
			ok = ok and (row[i] as Vector2).distance_to(lay.attack) >= HUD.ATTACK_RADIUS + 28.0
		check(ok, "potions, auto, target and the raven in one row above the skills, all clear (%s)" % canvas)
	print("HUD EVENT BOX: %s | %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
