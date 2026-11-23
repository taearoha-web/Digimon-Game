extends Node
## Every character of the account keeps its name and its records when another one is
## played: the registry lists every save slot (a damaged one too) offline with its own
## class, level, stars and guild; หนึ่งในใต้หล้า (MazeWar / MazeCrown) is one board for the
## whole account, so the kills of a character not played now stay on it under its name,
## it is the week's champion when it killed most (no world player, nor the character
## played, takes its week because it is offline), it gets the title and the costume for
## the crown's whole term (the next time it is played when it was offline at the week's
## end) and keeps them in its save while another one is played; a champion an older
## build worked out without it (only the one played was counted) is worked out again.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/account_characters_test.tscn
var failures := 0
var checks := 0
var base_offset := 0.0
var week := 0

const A_NAME := "หนึ่งเดียวในปฐพี"
const B_NAME := "ตัวรอง"
const C_NAME := "เด็กฝึกหัด"


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
	MazeWar.ai_mode = 0
	_reset()
	# Two days into a week after the maze opened.
	week = MazeWar.week_of(MazeWar.now())
	while MazeWar.week_start(week) <= float(MazeWar.OPEN_UNIX):
		week += 1
	_at(MazeWar.week_start(week) + 2.0 * 86400.0 + 3600.0)
	_make_characters()
	_registry()
	_board_while_offline()
	_week_ends_offline()
	_champion_played_again()
	_switch_back()
	_older_save()
	WorldPresence.clock_offset = base_offset
	MazeWar.ai_mode = -1
	MazeWar.reset()
	MazeCrown.reset_session()
	_reset()
	print("ACCOUNT CHARACTERS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _reset() -> void:
	Game.has_profile = false
	for i in range(1, Game.SLOT_COUNT + 1):
		Game.delete_save(i)
	SharedStorage.items().clear()
	SharedStorage.migrated().clear()
	SharedStorage.store()
	MazeWar.reset()
	MazeCrown.reset_session()


func _at(t: float) -> void:
	WorldPresence.clock_offset += t - WorldPresence.clock()
	MazeCrown.clear_cache()


func _hero(for_slot: int, cls: StringName, hero_name: String, level: int, stars: int) -> void:
	Game.slot = for_slot
	Game.new_profile(cls, hero_name, FaceKit.default_look())
	Game.profile.level = level
	if stars > 0:
		Game.profile["paragon"] = {"level": stars, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(stars)}
	Game.profile.hp = Game.stats_now().max_hp


## The hero of the slot played kills `n` world players in the maze, a minute apart.
func _kills(n: int) -> void:
	for k in n:
		_at(MazeWar.now() + 61.0)
		var victim := String(WorldPlayers.entry(k % WorldPlayers.size()).name)
		check(MazeWar.record_kill({"kind": "hero"}, {"kind": "ai", "name": victim, "index": k}), "a maze kill counts")


func _crowns_of(p: Dictionary) -> int:
	var n := 0
	for list in [p.get("inv", []), p.get("storage", [])]:
		for item in list:
			n += 1 if MazeCrown.is_crown_item(item) else 0
	var shop: Variant = p.get(RewardShop.KEY)
	if shop is Dictionary and String((shop as Dictionary).get("cos", "")) == MazeCrown.COSTUME_ID:
		n += 1
	return n


func _row(rows: Array, who: String) -> Dictionary:
	for r in rows:
		if String(r.name) == who:
			return r
	return {}


## A (slot 1) is the strongest and kills most this week, C (slot 3) is low, slot 4 holds a
## damaged file; B (slot 2) is played from then on.
func _make_characters() -> void:
	_hero(1, &"warrior", A_NAME, 100, 30)
	_kills(5)
	check(Game.save(), "A is saved in slot 1")
	_hero(3, &"archer", C_NAME, 40, 0)
	check(Game.save(), "C is saved in slot 3")
	var bad := FileAccess.open(Game.save_path(4), FileAccess.WRITE)
	bad.store_string("{not a hero")
	bad.close()
	_hero(2, &"mage", B_NAME, 100, 0)
	_kills(2)
	check(Game.save(), "B is saved in slot 2 and played")


func _registry() -> void:
	var rows := RegistryScreen.rows(WorldPresence.clock())
	var a := _row(rows, A_NAME)
	var b := _row(rows, B_NAME)
	var c := _row(rows, C_NAME)
	check(bool(b.get("you", false)) and bool(b.online) and int(b.slot) == 2, "the registry lists B as the one played (%s)" % [b])
	check(bool(a.get("alt", false)) and not bool(a.online) and int(a.slot) == 1 and String(a["class"]) == "warrior" and int(a.level) == 100 and int(a.stars) == 30, "A listed offline with its class, level and stars (%s)" % [a])
	check(bool(c.get("alt", false)) and not bool(c.online) and int(c.level) == 40 and int(c.guild) == 0, "C (under Lv.100) listed offline without a guild (%s)" % [c])
	var damaged := rows.filter(func(r): return bool(r.get("alt", false)) and int(r.get("slot", 0)) == 4)
	check(damaged.size() == 1 and bool(damaged[0].get("damaged", false)) and not bool(damaged[0].online), "a damaged slot still shows (%s)" % [damaged])
	check(rows.filter(func(r): return bool(r.get("you", false)) or bool(r.get("alt", false))).size() == 4, "every slot once: the one played and three others")
	# Every filter that should show them shows them.
	var screen := RegistryScreen.new()
	screen.filter = "all"
	check(screen._shows(a) and screen._shows(c), "the 'all' filter shows the other characters")
	screen.filter = "online"
	check(not screen._shows(a) and screen._shows(b), "'online' shows the one played, not the offline ones")
	screen.free()


func _board_while_offline() -> void:
	var board := MazeWar.standings(week)
	check(board.size() == 2, "both characters are on this week's board (%s)" % [board])
	if board.size() < 2:
		return
	check(String(board[0].name) == A_NAME and int(board[0].kills) == 5 and bool(board[0].get("mine", false)) and not bool(board[0].hero) and int(board[0].slot) == 1, "A, not played, is first with its kills (%s)" % [board[0]])
	check(String(board[1].name) == B_NAME and int(board[1].kills) == 2 and bool(board[1].hero), "B, played, second (%s)" % [board[1]])
	check(MazeBoardView.who_tag(board[0]) == MazeBoardView.MINE_TAG and MazeBoardView.who_tag(board[1]) == " (คุณ)", "the board tags A as the player's offline character")
	check(int(MazeWar.hero_rank(week).rank) == 2, "B's own rank is 2")
	# The server's board names A too (a real player row of the same name): counted once.
	MazeWar.receive({"t": "maze_board", "week": week, "rows": [{"name": A_NAME, "kills": 4, "ago": 0}, {"name": "คนอื่นจริง", "kills": 1, "ago": 0}]})
	board = MazeWar.standings(week)
	var a_rows := board.filter(func(r): return String(r.name) == A_NAME)
	check(a_rows.size() == 1 and int(a_rows[0].kills) == 5 and bool(a_rows[0].get("mine", false)), "A once, by its own save (%s)" % [a_rows])
	check(board.size() == 3, "and the other real player (%s)" % [board])


## The week ends while B is played: A is the champion, B gets nothing, no world player wears it.
func _week_ends_offline() -> void:
	_at(MazeWar.week_end(week) + 3600.0)
	MazeCrown.settle()
	var c := MazeWar.champion(week)
	check(String(c.get("name", "")) == A_NAME and bool(c.get("mine", false)) and int(c.get("slot", 0)) == 1 and not bool(c.get("hero", true)), "A is the week's champion though offline (%s)" % [c])
	var saved: Dictionary = (Game.profile[MazeWar.KEY] as Dictionary).champs.get(str(week), {})
	check(String(saved.get("name", "")) == A_NAME and bool(saved.get("hero", false)) and int(saved.get("slot", 0)) == 1, "B's save keeps A as champion with its slot (%s)" % [saved])
	check(_crowns_of(Game.profile) == 0 and not MazeCrown.wears_title(Game.profile), "B, played, gets neither the costume nor the title")
	var h := MazeCrown.holder()
	check(String(h.get("name", "")) == A_NAME and MazeCrown.mine_holds(1, A_NAME) and not MazeCrown.mine_holds(2, B_NAME), "the crown's holder is A (%s)" % [h])
	var ai := false
	for i in mini(WorldPlayers.size(), 400):
		ai = ai or MazeCrown.ai_holds(i)
	check(not ai, "no world player wears the crown")
	check(bool(_row(RegistryScreen.rows(WorldPresence.clock()), A_NAME).get("crown", false)), "the registry marks A as หนึ่งในใต้หล้า")
	var champs := MazeWar.champions(1)
	check(champs.size() == 1 and String(champs[0].name) == A_NAME and MazeBoardView.who_tag(champs[0]) == MazeBoardView.MINE_TAG, "the champions' list shows A as the player's character")
	check(Game.save(), "B saved")


## A is played again: it gets the title and the costume until the end of the next week.
func _champion_played_again() -> void:
	check(Game.load_game(1), "A loads")
	var ends := int(MazeWar.week_end(week + 1))
	check(_crowns_of(Game.profile) == 1 and RewardShop.worn_costume() == MazeCrown.COSTUME_ID, "A wears the crown costume")
	check(MazeCrown.wears_title(Game.profile) and MazeCrown.until_of(Game.profile) == ends, "A wears the title until the next week's end")
	var item: Dictionary = Game.equipped(Game.COSTUME_SLOT)
	check(int(item.get("expires", 0)) == ends, "the costume ends with the crown's full term (%d)" % ends)
	check(bool(MazeWar.champion(week).hero), "the champion is the one played now")
	MazeCrown.settle()
	MazeCrown.settle()
	check(_crowns_of(Game.profile) == 1, "settled again: still one costume")
	check(Game.save(), "A saved")


## B played again: A keeps everything in its save; B still has nothing; the board still names A.
func _switch_back() -> void:
	check(Game.load_game(2), "B loads again")
	var a: Dictionary = Game._read_slot(1)
	check(MazeCrown.wears_title(a) and _crowns_of(a) == 1, "A keeps its title and costume while offline")
	check(_crowns_of(Game.profile) == 0 and not MazeCrown.wears_title(Game.profile), "B still has neither")
	check(MazeCrown.mine_holds(1, A_NAME) and not bool(MazeCrown.holder().get("hero", true)), "the holder is still A")
	# Days later, still within the crown's term.
	_at(MazeWar.week_end(week) + 5.0 * 86400.0)
	MazeCrown.settle()
	check(MazeCrown.mine_holds(1, A_NAME), "A holds it all week")
	check(Game.save(), "B saved")


## An older build worked out B's champion without A (only B was counted then): a world
## player. It is worked out again from every character's save; older champion records
## without a slot name their own save's character.
func _older_save() -> void:
	var champs: Dictionary = (Game.profile[MazeWar.KEY] as Dictionary).champs
	champs[str(week)] = {"name": String(WorldPlayers.entry(0).name), "kills": 3, "hero": false, "index": 0}
	MazeWar.reset()
	MazeCrown.clear_cache()
	var c := MazeWar.champion(week)
	check(String(c.get("name", "")) == A_NAME and int(c.get("slot", 0)) == 1, "a world player saved by an older build gives the week back to A (%s)" % [c])
	check(int(((Game.profile[MazeWar.KEY] as Dictionary).champs[str(week)] as Dictionary).get("slot", 0)) == 1, "and the save is corrected")
	# A record without a slot (an older save of the champion itself) means that save's own.
	champs[str(week)] = {"name": B_NAME, "kills": 9, "hero": true, "index": -1}
	MazeWar.reset()
	var own := MazeWar.champion(week)
	check(bool(own.get("hero", false)) and int(own.get("slot", 0)) == 2, "an older own record reads as this character's (%s)" % [own])
	# Validation and repair keep the slot.
	var rec := {"weeks": {}, "champs": {str(week): {"name": A_NAME, "kills": 5.0, "hero": true, "index": -1.0, "slot": 1.0}}}
	check(MazeWar.valid(rec), "a champion with a slot is valid")
	var holder := {MazeWar.KEY: rec}
	MazeWar.repair(holder)
	check(holder[MazeWar.KEY].champs[str(week)] == {"name": A_NAME, "kills": 5, "hero": true, "index": -1, "slot": 1}, "repair keeps the slot as an int (%s)" % [holder[MazeWar.KEY]])
	check(not MazeWar.valid({"champs": {"1": {"slot": -1}}}) and not MazeWar.valid({"champs": {"1": {"slot": 1.5}}}), "a bad slot is refused")
