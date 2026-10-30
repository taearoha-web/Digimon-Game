extends Node
## Titled achievements (Achievements): the rules read a crafted profile, check_all earns
## each one once, Game's hooks count the hero's first chat line and a world boss, the
## chosen title changes title_of and the hero's name plate, the menu's "ตำแหน่ง" tab
## lists them with a working button, and a profile with ach / title still validates.
##   godot --headless --path . res://tests/integration/achievements_test.tscn

var failures := 0
var checks := 0
var _earned_signals: Array = []
var _title_signals: Array = []


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func settle() -> void:
	for i in 5:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	var started := Time.get_ticks_msec()
	Game.new_profile(&"warrior", "ทดสอบตำแหน่ง", FaceKit.default_look())
	Game.achievement_earned.connect(func(id: String): _earned_signals.append(id))
	Game.title_changed.connect(func(title: String): _title_signals.append(title))
	_rules()
	_earn_once()
	_hooks()
	_titles()
	await _name_plate()
	await _menu()
	_validates()
	print("ACHIEVEMENTS: %s | %d checks, %d failures (%d ms)" % ["PASS" if failures == 0 else "FAIL", checks, failures, Time.get_ticks_msec() - started])
	get_tree().quit(0 if failures == 0 else 1)


## A profile on its way: some goals met, the next step of each not.
func _craft() -> void:
	var p := Game.profile
	p.kills = 63
	p.level = 50
	p.gold = 1000000
	p.adv = 0
	p.boss_kills = {"forest_king": 1}
	p.paragon = {"level": 100}
	p.equip.weapon["plus"] = 7
	p.tower = {"best": 12}
	var flags: Dictionary = p.flags
	flags.clear()
	for key in ["guild", "gw_wins", "dailies", "tut"]:
		flags[key] = {"guild": 1, "gw_wins": 1, "dailies": 7, "tut": Achievements.TUTORIAL_DONE}[key]
	for k in 10:
		flags["%sKeeper|3|%d" % [StallStock.HAGGLE_FLAG, k]] = StallStock.HAGGLE_ACCEPTED
	for k in 2:
		flags["%sOther|3|%d" % [StallStock.HAGGLE_FLAG, k]] = StallStock.HAGGLE_REFUSED
	for k in 3:
		flags["%s%d|%d" % [StallStock.CONSIGN_FLAG, 1000 + k, k]] = 500
	p.ach = {}


func _rules() -> void:
	_craft()
	var p := Game.profile
	check(Achievements.TABLE.size() >= 24, "at least 24 titled achievements")
	var ids := {}
	for row in Achievements.TABLE:
		check(not ids.has(row.id), "unique id %s" % row.id)
		ids[row.id] = true
		check(GoalsData.ACHIEVEMENTS.filter(func(a): return a.id == row.id).is_empty(), "%s does not collide with GoalsData" % row.id)
		check(Achievements.value_of(row.kind, p) >= 0 and int(row.goal) > 0, "kind %s evaluates against a goal" % row.kind)
	check(Achievements.value_of("kills", p) == 63, "kills read")
	check(Achievements.progress("t_kill100", p) == "63/100", "progress text 63/100, got %s" % Achievements.progress("t_kill100", p))
	check(Achievements.progress("t_kill1", p) == "1/1", "progress capped at the goal")
	check(Achievements.value_of("level", p) == 50, "level read")
	check(Achievements.value_of("stars", p) == 100, "stars from paragon.level")
	check(Achievements.value_of("plus", p) == 7, "best worn plus")
	check(Achievements.value_of("gold", p) == 1000000, "gold read")
	check(Achievements.value_of("bosses", p) == 1, "boss kills summed")
	check(Achievements.value_of("tower", p) == 12, "tower best from tower.best")
	check(Achievements.value_of("guild", p) == 1, "guild flag")
	check(Achievements.value_of("tutorial", p) == 1, "tutorial flag 99")
	check(Achievements.value_of("job", p) == 0, "no job change yet")
	check(Achievements.value_of("chat", p) == 0, "no chat yet")
	check(Achievements.stall_counts(p.flags) == [10, 3], "10 accepted haggles and 3 consignments counted, got %s" % str(Achievements.stall_counts(p.flags)))
	check(Achievements.progress("nope", p) == "", "unknown id has no progress")
	check(Achievements.entry("t_boss1").title == "ผู้ล้มยักษ์", "entry by id")
	check(Achievements.index_of("missing") == -1, "missing index")


func _earn_once() -> void:
	var p := Game.profile
	var fresh := Achievements.check_all(p, {"party": 1})
	var expected := ["t_kill1", "t_boss1", "t_lv10", "t_lv50", "t_star1", "t_star50", "t_star100", "t_party", "t_haggle",
		"t_plus7", "t_gold", "t_guild", "t_gw_win", "t_tower10", "t_daily7", "t_tutorial"]
	check(fresh == expected, "first check_all earns exactly the met goals in table order, got %s" % str(fresh))
	check(Achievements.earned(p) == expected, "earned() lists them in table order")
	check(int(p.flags.get(Achievements.PARTY_FLAG, 0)) == 1, "party sticky flag set from live party")
	check(int(p.flags.get(Achievements.HAGGLE_FLAG, 0)) == 10, "haggle sticky counter")
	check(int(p.flags.get(Achievements.CONSIGN_FLAG, 0)) == 3, "consign sticky counter")
	check(Achievements.check_all(p).is_empty(), "second check_all earns nothing")
	p.flags.clear()
	p.flags[Achievements.PARTY_FLAG] = 1
	check(Achievements.check_all(p).is_empty() and int(p.flags.get(Achievements.HAGGLE_FLAG, 0)) == 0, "dropped haggle keys do not raise the counter")
	p.kills = 100
	check(Achievements.check_all(p) == ["t_kill100"], "only the new one is returned")
	check(Achievements.check_all(p).is_empty(), "and only once")
	check(p.ach.get("t_kill1000", false) == false, "1000 kills not earned")
	for value in p.ach.values():
		check(value is bool, "ach values are bool")


func _hooks() -> void:
	var p := Game.profile
	_earned_signals.clear()
	Game.world_chat.emit("คนอื่น", "สวัสดี", Color.WHITE)
	check(not p.ach.get("t_chat", false), "another speaker's line does not count")
	Game.world_chat.emit(String(p.name), "สวัสดีทุกคน", Color.WHITE)
	check(p.ach.get("t_chat", false) == true, "the hero's first chat line earns t_chat")
	check(_earned_signals == ["t_chat"], "achievement_earned emitted once for the chat, got %s" % str(_earned_signals))
	Game.world_boss_defeated.emit(&"meadow")
	check(int(p.flags.get(Achievements.WORLD_BOSS_FLAG, 0)) == 1 and p.ach.get("t_worldboss", false) == true, "a world boss earns t_worldboss")
	check(_earned_signals.size() == 2, "achievement_earned for the world boss too")
	# check_achievements (the rewarded list, called at level-up) and save run the titled check too.
	p.kills = 1000
	Game.check_achievements()
	check(p.ach.get("t_kill1000", false) == true, "Game.check_achievements earns titled ones")
	p.level = 100
	Game.save()
	check(p.ach.get("t_lv100", false) == true, "Game.save earns titled ones first")


func _titles() -> void:
	var p := Game.profile
	_title_signals.clear()
	check(Achievements.title_of(p) == "", "no title at first")
	check(not Game.set_title(Achievements.index_of("t_lv10")), "an achievement without a title cannot be worn")
	check(not Game.set_title(Achievements.index_of("t_star200")), "an unearned title cannot be worn")
	check(not Game.set_title(99), "index out of range refused")
	check(Achievements.title_of(p) == "" and _title_signals.is_empty(), "refusals change nothing")
	var boss := Achievements.index_of("t_boss1")
	check(Game.set_title(boss), "an earned title is worn")
	check(Achievements.title_of(p) == "ผู้ล้มยักษ์", "title_of reads the chosen title")
	check(int(p.flags.get(Achievements.TITLE_FLAG, -1)) == boss, "the flag holds the table index")
	check(_title_signals == ["ผู้ล้มยักษ์"], "title_changed emitted with the title")
	p.ach.erase("t_boss1")
	check(Achievements.title_of(p) == "", "a title whose achievement is gone is not shown")
	p.ach["t_boss1"] = true
	check(Game.set_title(-1), "taken off")
	check(Achievements.title_of(p) == "" and not p.flags.has(Achievements.TITLE_FLAG), "no title flag after taking it off")
	check(_title_signals == ["ผู้ล้มยักษ์", ""], "title_changed emitted with \"\" when taken off")


func _name_plate() -> void:
	var field := Node3D.new()
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	await get_tree().process_frame
	check(is_instance_valid(hero._name_plate) and hero._name_plate is Label3D, "the hero has a name plate")
	check(hero._name_plate.text == "ทดสอบตำแหน่ง", "the plate shows the name alone without a title, got %s" % hero._name_plate.text)
	Game.set_title(Achievements.index_of("t_gold"))
	check(hero._name_plate.text == "「เศรษฐี」\nทดสอบตำแหน่ง", "the plate shows the title on its own line, got %s" % hero._name_plate.text)
	Game.set_title(-1)
	check(hero._name_plate.text == "ทดสอบตำแหน่ง", "the plate drops the title when taken off")
	field.queue_free()
	await get_tree().process_frame


func _menu() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"titles")
	await settle()
	check(menu._tab_buttons.has(&"titles") and menu._tab_buttons[&"titles"].disabled, "the titles tab exists and is selected")
	check(is_instance_valid(menu._page_scroll), "the titles page scrolls")
	var buttons: Array[Node] = menu._content.find_children("*", "Button", true, false)
	var wear: Array = buttons.filter(func(b: Node) -> bool: return (b as Button).text == "ใช้ตำแหน่ง")
	var titled_earned := 0
	for row in Achievements.TABLE:
		if Achievements.is_earned(row.id, Game.profile) and String(row.title) != "":
			titled_earned += 1
	check(wear.size() == titled_earned and titled_earned > 0, "one wear button per earned titled achievement (%d / %d)" % [wear.size(), titled_earned])
	var labels: Array[Node] = menu._content.find_children("*", "Label", true, false)
	check(labels.any(func(l: Node) -> bool: return (l as Label).text.contains("63/") or (l as Label).text.contains("/1000")), "progress text shown")
	(wear[0] as Button).pressed.emit()
	await settle()
	check(Achievements.title_of(Game.profile) == "มือใหม่", "the first wear button wears the first title, got %s" % Achievements.title_of(Game.profile))
	buttons = menu._content.find_children("*", "Button", true, false)
	var off: Array = buttons.filter(func(b: Node) -> bool: return (b as Button).text == "ถอดตำแหน่ง")
	check(off.size() == 1, "after wearing, one take-off button")
	(off[0] as Button).pressed.emit()
	await settle()
	check(Achievements.title_of(Game.profile) == "", "the take-off button clears the title")
	menu.close_menu()
	await settle()
	menu.queue_free()
	await get_tree().process_frame


func _validates() -> void:
	Game.set_title(Achievements.index_of("t_kill1"))
	var p := Game.profile
	check(Game._valid_profile(p), "a profile with titled ach and a title flag validates")
	var json: Variant = JSON.parse_string(JSON.stringify(p))
	check(json is Dictionary and Game._valid_profile(json), "and after a JSON round trip")
	var bad := p.duplicate(true)
	bad.ach["t_kill1"] = 1
	check(not Game._valid_profile(bad), "ach values must stay bool")
	Game.set_title(-1)
