extends Node
## The event boards count every character of the account, as หนึ่งในใต้หล้า does
## (account_characters_test): the weekly rare collection's top collectors (WeeklyCollect),
## the Loy Krathong pageant (LoyKrathong.standings) and the dragon hunt's top hunters
## (DragonHunt.top) list a character not played now under its own name, by the record in
## its own save, tagged as the player's offline character, each character once; its place
## stays its own (the pageant's prize and title come the next time it is played, even
## after the festival), and the one played is ranked among them.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/account_boards_test.tscn
var failures := 0
var checks := 0
var base_offset := 0.0

const A_NAME := "นางนพมาศออฟไลน์"
const B_NAME := "ตัวที่เล่นอยู่"


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	Announcer.ticking = false
	Announcer.relay = false
	WorldPlayers.persist = false
	base_offset = WorldPresence.clock_offset
	_reset()
	_weekly()
	_dragon_hunt()
	_pageant()
	_reset()
	WorldPresence.clock_offset = base_offset
	LoyKrathong.test_time = -1.0
	DragonHunt.test_time = -1.0
	print("ACCOUNT BOARDS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	WeeklyCollect.reset_alts()
	LoyKrathong.reset()


func _at(t: float) -> void:
	WorldPresence.clock_offset += t - WorldPresence.clock()
	LoyKrathong.test_time = t
	DragonHunt.test_time = t


func _hero(for_slot: int, hero_name: String, gender: int) -> void:
	Game.slot = for_slot
	var look := FaceKit.default_look()
	look["gender"] = gender
	Game.new_profile(&"warrior", hero_name, look)
	Game.profile.level = 60
	Game.profile.hp = Game.stats_now().max_hp


func _rows_of(rows: Array, who: String) -> Array:
	return rows.filter(func(r): return String(r.name) == who)


func _labels(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for c in node.get_children():
		out += _labels(c)
	return out


## A (slot 1) collected most this week, then B (slot 2) is played.
func _weekly() -> void:
	var w := WeeklyCollect.week_of(float(WeeklyCollect.START)) + 1
	var t := WeeklyCollect.week_start(w) + 2.0 * 86400.0
	_at(t)
	_hero(1, A_NAME, 1)
	Game.profile[WeeklyCollect.KEY] = {"week": w, "pts": 99000, "got": [10, 0, 0, 0, 0], "ex": {}}
	check(Game.save(), "A saved")
	_hero(3, "ตัวเก่า", 0)
	Game.profile[WeeklyCollect.KEY] = {"week": w - 1, "pts": 98000, "got": [0, 0, 0, 0, 0], "ex": {}}
	check(Game.save(), "an older week's collector saved in slot 3")
	_hero(2, B_NAME, 0)
	Game.profile[WeeklyCollect.KEY] = {"week": w, "pts": 97000, "got": [0, 0, 0, 0, 0], "ex": {}}
	check(Game.save(), "B saved and played")
	var rows := WeeklyCollect.leaderboard(t)
	var a := _rows_of(rows, A_NAME)
	var b := _rows_of(rows, B_NAME)
	check(a.size() == 1 and int(a[0].pts) == 99000 and bool(a[0].mine) and not bool(a[0].hero) and int(a[0].slot) == 1, "A, not played, is on the weekly board once with its points (%s)" % [a])
	check(b.size() == 1 and bool(b[0].hero), "B, played, too (%s)" % [b])
	check(_rows_of(rows, "ตัวเก่า").is_empty(), "a character with last week's record is not on this week's board")
	check(rows.find(a[0]) < rows.find(b[0]), "A ranks above B")
	check(MazeBoardView.who_tag(a[0]) == MazeBoardView.MINE_TAG and MazeBoardView.who_tag(b[0]) == " (คุณ)", "A tagged as the player's offline character")
	var place := -1
	for k in rows.size():
		if bool(rows[k].hero):
			place = k + 1
	check(WeeklyCollect.hero_rank(t) == place, "B's own rank counts A before it (%d / %d)" % [WeeklyCollect.hero_rank(t), place])
	var panel := WeeklyCollectView._leaders(t)
	var text := _labels(panel)
	check(text.contains(A_NAME + MazeBoardView.MINE_TAG) and text.contains(B_NAME + " (คุณ)"), "the board's page tags both")
	panel.free()
	# A played: B is the offline one now, A the hero, each once.
	check(Game.load_game(1), "A loads")
	rows = WeeklyCollect.leaderboard(t)
	a = _rows_of(rows, A_NAME)
	b = _rows_of(rows, B_NAME)
	check(a.size() == 1 and bool(a[0].hero) and b.size() == 1 and bool(b[0].mine) and not bool(b[0].hero) and int(b[0].pts) == 97000, "switched: A played, B offline with its points (%s %s)" % [a, b])
	check(WeeklyCollect.hero_rank(t) == 1 or rows.find(a[0]) == WeeklyCollect.hero_rank(t) - 1, "A's rank")
	_reset()


func _dragon_hunt() -> void:
	var t := DragonHunt.start_of(0) + 86400.0
	_at(t)
	var n := DragonHunt.index(t)
	check(n == 0 and DragonHunt.is_on(t), "the first hunt runs")
	_hero(1, A_NAME, 1)
	Game.profile[DragonHunt.KEY] = {"n": n, "pts": 9000, "got": 1, "kills": 3, "golden": 0}
	check(Game.save(), "A saved")
	_hero(2, B_NAME, 0)
	Game.profile[DragonHunt.KEY] = {"n": n, "pts": 300, "got": 0, "kills": 0, "golden": 0}
	check(Game.save(), "B saved and played")
	var rows := DragonHunt.top(t, 10)
	var a := _rows_of(rows, A_NAME)
	check(a.size() == 1 and int(a[0].pts) == 9000 and bool(a[0].mine) and not bool(a[0].hero) and int(a[0].slot) == 1 and int(a[0].rank) == 1, "A, not played, tops the hunt with its points (%s)" % [a])
	check(_rows_of(rows, B_NAME).size() == 1 and bool(_rows_of(rows, B_NAME)[0].hero), "B is there as the one played")
	check(DragonHunt.claimable(t) == 2, "B's milestones are its own (%d)" % DragonHunt.claimable(t))
	var box := VBoxContainer.new()
	var page := DragonHuntView.build(box, func(): pass)
	var text := _labels(page)
	check(text.contains(A_NAME + " — 9000 แต้ม" + MazeBoardView.MINE_TAG), "the hunt page tags A")
	page.free()
	box.free()
	# The previous hunt's record is not this hunt's.
	var old: Dictionary = Game._read_slot(1)
	old[DragonHunt.KEY] = {"n": n - 1, "pts": 9000, "got": 0, "kills": 0, "golden": 0}
	var f := FileAccess.open(Game.save_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	WeeklyCollect.reset_alts()
	check(_rows_of(DragonHunt.top(t, 10), A_NAME).is_empty(), "an older hunt's points are not on this hunt's board")
	# A played: its milestones from its own save.
	old[DragonHunt.KEY] = {"n": n, "pts": 9000, "got": 1, "kills": 3, "golden": 0}
	f = FileAccess.open(Game.save_path(1), FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(Game.load_game(1), "A loads")
	check(DragonHunt.claimable(t) == DragonHunt.MILESTONES.size() - 1, "A can claim what it reached, the first already claimed (%d)" % DragonHunt.claimable(t))
	var b := _rows_of(DragonHunt.top(t, 100000), B_NAME)
	check(b.size() == 1 and bool(b[0].mine) and not bool(b[0].hero) and int(b[0].pts) == 300, "B offline keeps its points (%s)" % [b])
	_reset()


## A and B both walk the girls' stage; B is played at the result; A, played the day after
## the festival, still gets the crown it won.
func _pageant() -> void:
	_at(float(LoyKrathong.RESULT_AT) - 7200.0)
	_hero(1, A_NAME, 1)
	Game.profile[LoyKrathong.KEY] = {"day": -1, "n": 0, "fl": 0, "pts": 15, "pg": 5000, "pgd": 1, "pgg": 1, "got": 0}
	check(Game.save(), "A saved")
	_hero(2, B_NAME, 1)
	Game.profile[LoyKrathong.KEY] = {"day": -1, "n": 0, "fl": 0, "pts": 15, "pg": 4000, "pgd": 1, "pgg": 1, "got": 0}
	check(Game.save(), "B saved and played")
	var rows := LoyKrathong.standings(1)
	var a := _rows_of(rows, A_NAME)
	var b := _rows_of(rows, B_NAME)
	check(a.size() == 1 and int(a[0].rank) == 1 and bool(a[0].mine) and not bool(a[0].hero) and int(a[0].slot) == 1, "A, not played, leads the stage with its votes (%s)" % [a])
	check(b.size() == 1 and int(b[0].rank) == 2 and bool(b[0].hero), "B second (%s)" % [b])
	check(LoyKrathong.hero_rank() == 2, "B's own place is 2")
	check(_rows_of(LoyKrathong.standings(0), A_NAME).is_empty(), "A is not on the boys' stage")
	check(String(LoyKrathong.standings(1)[0].name) == A_NAME and LoyKrathong.result_text().contains(A_NAME), "the result names A")
	var box := VBoxContainer.new()
	var page := LoyKrathongView._pageant(LoyKrathong.now(), func(): pass)
	check(_labels(page).contains(A_NAME + " — 5,000 โหวต" + MazeBoardView.MINE_TAG), "the pageant page tags A (%s)" % _labels(page))
	page.free()
	box.free()
	# The result while B is played: B gets the second place's prize, no title; once.
	_at(float(LoyKrathong.RESULT_AT) + 60.0)
	LoyKrathong.tick(LoyKrathong.now())
	check(int(LoyKrathong.peek().got) & LoyKrathong.GOT_PRIZE != 0 and not Game.profile.flags.has(LoyKrathong.QUEEN_FLAG), "B settled at second place, no title")
	var pieces := Game.jewel_count(LoyKrathong.PIECE)
	check(LoyKrathong.settle() == "", "settled once")
	LoyKrathong.tick(LoyKrathong.now())
	check(Game.jewel_count(LoyKrathong.PIECE) == pieces, "no second prize")
	check(Game.save(), "B saved")
	var saved_a: Dictionary = Game._read_slot(1)
	check(int(saved_a[LoyKrathong.KEY].got) & LoyKrathong.GOT_PRIZE == 0, "A's save untouched while B is played")
	# A played the day after the festival: it gets the title and the first place's prize.
	_at(float(LoyKrathong.END) + 86400.0)
	check(Game.load_game(1), "A loads")
	check(LoyKrathong.hero_rank() == 1, "A's place is 1")
	LoyKrathong.tick(LoyKrathong.now())
	check(Game.profile.flags.has(LoyKrathong.QUEEN_FLAG) and int(LoyKrathong.peek().got) & LoyKrathong.GOT_PRIZE != 0, "A gets the queen's title after the festival")
	check(Game.jewel_count(LoyKrathong.PIECE) == 10, "and the first place's prize (%d)" % Game.jewel_count(LoyKrathong.PIECE))
	LoyKrathong.tick(LoyKrathong.now())
	check(Game.jewel_count(LoyKrathong.PIECE) == 10, "once")
	var bb := _rows_of(LoyKrathong.standings(1), B_NAME)
	check(bb.size() == 1 and bool(bb[0].mine) and not bool(bb[0].hero) and int(bb[0].rank) == 2, "B stays second, offline (%s)" % [bb])
	_reset()
