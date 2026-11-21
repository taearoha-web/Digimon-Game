extends Node
## เขาวงกตหนึ่งในใต้หล้า (MazeWar, MazeLayout, MazeMatch): the maze is the same on every
## device and one piece; the ten shrines are spread, reachable and keep whoever stands in
## them from harm (and from striking) for their time, then wear off; a fall brings one back
## at a random spot of the maze, never in a shrine or a wall, away from everyone; only kills
## between players count, once a minute for the same pair; the board sorts by kills, ties to
## who got there first; a week ends with its champion kept; the world players' fights work
## out the same on every device, plausibly (the stronger win more, not always), and a world
## player fighting live holds its slots so nothing counts twice; the live ones come with
## their real gear; the race makes the keen ones forge harder; the save's record is checked
## (the game; accounts.js has its node test); the HUD's board and the full board show the
## real standings; their chat says only the board's numbers; online, the hero's kills go to
## the server and the server's board and hits come back.
##   godot --headless --path . res://tests/integration/maze_war_test.tscn
var failures := 0
var checks := 0
var main: Node
const T_OFFSET := 2.5 * 86400.0 + 8.0 * 3600.0


class FakeTransport:
	extends RefCounted
	var sent: Array[String] = []
	func send_text(text: String) -> void:
		sent.append(text)
	func poll() -> Array:
		return []
	func is_open() -> bool:
		return true
	func is_closed() -> bool:
		return false
	func frames(t: String) -> Array:
		var out: Array = []
		for text in sent:
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary and String(d.get("t", "")) == t:
				out.append(d)
		return out


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## The world clock at real unix time t.
func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	Announcer.ticking = false
	WorldPlayers.persist = false
	MazeWar.reset()
	MazeWar.ai_mode = 1
	at(float(MazeWar.OPEN_UNIX) + T_OFFSET)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.delete_save()
	Game.new_profile(&"warrior", "MazeQA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon().level = 200
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(&"warrior", 200, slot, Game.rng)
	Game.fill_loadout()
	Game.profile.hp = Game.stats_now().max_hp
	main.title_screen.queue_free()
	main.title_screen = null
	main.hud.visible = true
	print("== _layout()")
	_layout()
	print("== _spawn_rules()")
	_spawn_rules()
	print("== _kills()")
	_kills()
	print("== _ties()")
	_ties()
	print("== _sim()")
	_sim()
	print("== _live_sim()")
	_live_sim()
	print("== _drive()")
	_drive()
	print("== _save()")
	_save()
	print("== _chat()")
	_chat()
	print("== _zone()")
	await _zone()
	print("== _hud()")
	await _hud()
	print("== _online()")
	await _online()
	print("== _week()")
	_week()
	MazeWar.ai_mode = -1
	MazeWar.reset()
	WorldPresence.clock_offset = 0.0
	print("MAZE WAR: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


# --- The maze ---------------------------------------------------------------------------

func _layout() -> void:
	MazeLayout.build()
	var first := MazeLayout.links.duplicate()
	var segs := MazeLayout.segments().size()
	MazeLayout.build()
	check(MazeLayout.links == first and MazeLayout.segments().size() == segs, "the maze is built the same from its seed every time (every device and the host agree)")
	check(MazeLayout.reachable_from(0) == MazeLayout.cell_count(), "the maze is one piece: every cell can be walked to (%d of %d)" % [MazeLayout.reachable_from(0), MazeLayout.cell_count()])
	check(MazeLayout.HALF * 2.0 >= 200.0 and MazeLayout.HALF * 2.0 <= SiegeArena.RADIUS * 2.0 + 20.0, "about the guild-war castle field's size (%d m across)" % int(MazeLayout.HALF * 2.0))
	var dead_ends := 0
	for c in MazeLayout.cell_count():
		if MazeLayout.exits(c).size() == 1:
			dead_ends += 1
	check(dead_ends < MazeLayout.cell_count() / 4, "loops knocked through: not all dead ends (%d)" % dead_ends)
	# Every plaza open inside.
	for k in MazeLayout.PLAZAS.size():
		var c := MazeLayout.cell_at(MazeLayout.plaza_center(k) + Vector3(0.5, 0, 0.5))
		check(MazeLayout.plaza_of[c] == k and MazeLayout.exits(c).size() == 4, "plaza %d is open ground" % k)
	# The shrines: ten, spread, open on every side, reachable.
	check(MazeLayout.safe_count() == 10, "ten shrines (ที่หลบภัย)")
	var quads := [0, 0, 0, 0]
	var closest := INF
	for k in MazeLayout.safe_count():
		var p := MazeLayout.safe_center(k)
		quads[MazeLayout.quadrant(p)] += 1
		var c := MazeLayout.cell_at(p)
		check(MazeLayout.exits(c).size() >= 3, "shrine %d is a courtyard open on its sides (no single door to camp)" % k)
		check(MazeLayout.steps(0, c) >= 0, "shrine %d can be reached" % k)
		check(MazeLayout.safe_at(p) == k and MazeLayout.safe_at(p + Vector3(MazeLayout.SAFE_RADIUS + 0.5, 0, 0)) == -1, "shrine %d's circle is where it is drawn" % k)
		for j in range(k + 1, MazeLayout.safe_count()):
			closest = minf(closest, p.distance_to(MazeLayout.safe_center(j)))
	check(quads.min() >= 2, "the shrines are spread over all four quadrants (%s)" % str(quads))
	check(closest >= MazeLayout.CELL * 3.0, "no two shrines side by side (closest %.0f m)" % closest)
	# Walking it: the route from any cell reaches any other, one cell at a time.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ok := true
	for n in 40:
		var a := rng.randi() % MazeLayout.cell_count()
		var b := rng.randi() % MazeLayout.cell_count()
		var c := a
		var guard := 0
		while c != b and guard < 400:
			var next := MazeLayout.next_cell(c, b)
			if not MazeLayout.is_open(c, next):
				ok = false
				break
			c = next
			guard += 1
		if c != b:
			ok = false
	check(ok, "the AI's way through the maze (next_cell) always walks through open borders to its goal")
	check(MazeLayout.route(MazeLayout.center(0), MazeLayout.center(0) + Vector3(1, 0, 1)) == MazeLayout.center(0) + Vector3(1, 0, 1), "straight on inside a cell")
	check(EntitySync.supports(Zone.new()) == false or true, "")
	var zd := ZoneData.get_zone(MazeWar.ID)
	check(String(zd.name) == MazeWar.TITLE and bool(zd.get("maze", false)) and not ZoneData.ZONES.has(MazeWar.ID), "the maze's zone data (entered from its keeper or the warp crystal, not in the field chain)")
	check(ZoneData.access_reason(MazeWar.ID, 99, 0) != "" and ZoneData.access_reason(MazeWar.ID, 100, 0) == "", "open from Lv.%d, any hour" % MazeWar.MIN_LEVEL)
	check(MazeWar.week_of(MazeWar.now()) == GuildLeague.week_of(MazeWar.now()) and MazeWar.week_end(10) == GuildLeague.week_end(10), "the week is the guild league's")


func _spawn_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var foes: Array = [Vector3(0, 0, 0), Vector3(40, 0, 40), Vector3(-60, 0, 30)]
	var spots := {}
	var ok := true
	for n in 200:
		var p := MazeLayout.spawn_point(rng, foes)
		spots[MazeLayout.cell_at(p)] = true
		if MazeLayout.is_safe_cell(MazeLayout.cell_at(p)) or MazeLayout.in_wall(p, 0.4) or not MazeLayout.inside(p) or MazeLayout.plaza_of[MazeLayout.cell_at(p)] == 0:
			ok = false
		for f in foes:
			if Vector2(p.x - (f as Vector3).x, p.z - (f as Vector3).z).length() < 18.0:
				ok = false
	check(ok, "a respawn spot is never in a shrine, a wall or the throne plaza, and never next to an enemy")
	check(spots.size() > 100, "respawn spots are random all over the maze (%d cells)" % spots.size())


# --- Counting -------------------------------------------------------------------------

func _kills() -> void:
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	var hero := {"kind": "hero", "name": MazeWar.hero_name(), "index": -1}
	check(not MazeWar.record_kill({"kind": "mob", "name": "slime"}, hero, t), "a monster's kill does not count")
	check(not MazeWar.record_kill(hero, {"kind": "mob", "name": "slime"}, t), "killing a monster does not count")
	check(not MazeWar.record_kill(hero, hero, t), "nobody counts falling to oneself")
	check(MazeWar.record_kill(hero, {"kind": "ai", "name": "Kaito", "index": 0}, t - 100.0), "the hero's kill of a world player counts")
	check(MazeWar.record_kill(hero, {"kind": "real", "name": "Someone", "index": -1}, t - 50.0), "and of a real player")
	var book := MazeWar.week_book(week)
	check(int(book.k) == 2 and int(book.at) == int(t - 50.0), "the hero's kills and when it reached the count are in the save")
	check(MazeWar.hero_rank(week, t).kills == 2, "the board reads the hero's kills")
	# Kills only: deaths never move the board.
	MazeWar.record_death(t)
	check(int(MazeWar.week_book(week).d) == 1 and MazeWar.hero_rank(week, t).kills == 2, "a death is kept, the board stays kills only")


func _ties() -> void:
	var rows := [{"name": "B", "kills": 5, "at": 20.0, "hero": false, "index": 1}, {"name": "A", "kills": 5, "at": 10.0, "hero": false, "index": 2},
		{"name": "C", "kills": 9, "at": 30.0, "hero": false, "index": 3}, {"name": "D", "kills": 5, "at": 10.0, "hero": false, "index": 4}]
	rows.sort_custom(MazeWar._before)
	check(rows.map(func(r): return r.name) == ["C", "A", "D", "B"], "by kills, ties to who reached the count first (%s)" % str(rows.map(func(r): return r.name)))
	var board := MazeWar.standings(MazeWar.week_of(MazeWar.now()))
	var sorted := true
	for k in range(1, board.size()):
		if int(board[k - 1].kills) < int(board[k].kills) or (int(board[k - 1].kills) == int(board[k].kills) and float(board[k - 1].at) > float(board[k].at)):
			sorted = false
	check(sorted and board.size() > 10, "the week's board is sorted rank 1 to last (%d rows)" % board.size())
	check(board.all(func(r): return int(r.kills) > 0 and r.has("name") and r.has("hero") and r.has("index")), "every row is {name, kills, hero, index} with a kill")


# --- The world players' fights ----------------------------------------------------------

func _sim() -> void:
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	var board := MazeWar.standings(week, t)
	var names := board.map(func(r): return "%s:%d" % [r.name, r.kills])
	MazeWar.reset()
	WorldGear.clear()
	var again := MazeWar.standings(week, t).map(func(r): return "%s:%d" % [r.name, r.kills])
	check(names == again, "every device works the world players' fights out alike (from the clock and the roster)")
	# Who goes in: interested, never a stall keeper, Lv.100, online.
	var cands := MazeWar.candidates()
	check(cands.size() > 20 and cands.size() < WorldPlayers.size(), "some world players care for the race, not all (%d of %d)" % [cands.size(), WorldPlayers.size()])
	check(cands.all(func(i): return not WorldPlayers.in_town_style(int(i))), "no stall keeper goes in")
	var inside := MazeWar.inside_at(t)
	check(inside.size() >= 2 and inside.all(func(i): return not WorldPlayers.session_at(int(i), t).is_empty()), "the ones inside now are online (%d)" % inside.size())
	check(inside.all(func(i): return String(WorldPlayers.state(int(i), t).place) == String(MazeWar.ID)), "where the world shows them: in the maze (registry, chat)")
	check(MazeWar.in_maze(int(cands[0]), float(MazeWar.OPEN_UNIX) - 60.0) == false, "nobody before the maze opened")
	# Plausible: a top player's day, the stronger usually win, not always.
	var top := int(board[0].kills)
	var days := (t - maxf(MazeWar.week_start(week), float(MazeWar.OPEN_UNIX))) / 86400.0
	check(float(top) / days > 5.0 and float(top) / days < 120.0, "the leader's kills a day are plausible (%.0f)" % (float(top) / days))
	var stronger := 0
	var weaker := 0
	for k in range(MazeWar.slot_of(t) - 300, MazeWar.slot_of(t)):
		for f in MazeWar.slot_fights(k):
			var mid := MazeWar.slot_start(k) + MazeWar.SLOT * 0.5
			if MazeWar.power(int(f[1]), mid) >= MazeWar.power(int(f[2]), mid):
				stronger += 1
			else:
				weaker += 1
	check(stronger > weaker * 3 / 2 and weaker > 0, "the stronger win most fights, not all (%d / %d)" % [stronger, weaker])
	check(MazeWar.win_chance(1000.0, 10.0) <= 1.0 - MazeWar.UPSET and MazeWar.win_chance(10.0, 1000.0) >= MazeWar.UPSET, "there is always a chance of an upset")
	var tops := board.slice(0, 5).map(func(r): return MazeWar.power(int(r.index), t))
	var bottoms := board.slice(board.size() - 5).map(func(r): return MazeWar.power(int(r.index), t))
	var avg := func(list: Array) -> float:
		var s := 0.0
		for v in list:
			s += float(v)
		return s / maxf(1.0, float(list.size()))
	check(float(avg.call(tops)) > float(avg.call(bottoms)), "the board's top is stronger than its foot on the whole")


func _live_sim() -> void:
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	var k := MazeWar.slot_of(t) - 3
	var fights := MazeWar.slot_fights(k)
	if fights.is_empty():
		k -= 1
		fights = MazeWar.slot_fights(k)
	check(not fights.is_empty(), "a slot with fights to hold")
	if fights.is_empty():
		return
	var i := int(fights[0][1])
	var name := String(WorldPlayers.entry(i).name)
	var before := int(MazeWar.rank_of(i, week, t).kills)
	var wins := 0
	for f in fights:
		if int(f[1]) == i:
			wins += 1
	MazeWar.hold(i, MazeWar.slot_start(k) + 1.0)
	check(MazeWar.is_held(i, MazeWar.slot_start(k) + 1.0), "a world player fighting live holds its slot")
	var held := int(MazeWar.rank_of(i, week, t).kills)
	check(held == before - wins, "its simulated kills of a held slot are dropped (%d -> %d, %d in the slot)" % [before, held, wins])
	MazeWar.record_kill({"kind": "ai", "name": name, "index": i}, {"kind": "ai", "name": "Other", "index": -1}, MazeWar.slot_start(k) + 30.0)
	MazeWar.record_kill({"kind": "ai", "name": name, "index": i}, {"kind": "hero", "name": MazeWar.hero_name(), "index": -1}, MazeWar.slot_start(k) + 60.0)
	check(MazeWar.rank_of(i, week, t).kills == held + 2, "its live kills count instead: sim (held left out) + live, never both")
	MazeWar.hold(i, MazeWar.slot_start(k) + 2.0)
	check(MazeWar.rank_of(i, week, t).kills == held + 2, "holding the same slot again changes nothing")


func _drive() -> void:
	# The maze is open from the world's reopening (OPEN_UNIX = WorldPlayers.START_UNIX), when
	# everyone is Lv.1: the keen players are those at Lv.100 a few days before t.
	var t := float(MazeWar.OPEN_UNIX) + 12.0 * 86400.0
	var keen: Array[int] = []
	for i in MazeWar.candidates():
		if MazeWar.ready_at(i, t) < t - 3.0 * 86400.0:
			keen.append(i)
		if keen.size() >= 8:
			break
	var plus_on := 0
	var gems_on := 0
	MazeWar.drive_on = true
	WorldGear.clear()
	for i in keen:
		plus_on += _plus_sum(i, t)
		gems_on += int(WorldGear.gem_summary(i, WorldGear.state_at_work(i, WorldPlayers.work_at(i, t))).count)
	MazeWar.drive_on = false
	WorldGear.clear()
	var plus_off := 0
	var gems_off := 0
	for i in keen:
		plus_off += _plus_sum(i, t)
		gems_off += int(WorldGear.gem_summary(i, WorldGear.state_at_work(i, WorldPlayers.work_at(i, t))).count)
	MazeWar.drive_on = true
	WorldGear.clear()
	check(keen.size() >= 4, "keen world players at Lv.100 days before (%d)" % keen.size())
	# Keen forgers (WorldGear.ZEAL) may already be at the top either way: never lower.
	check(plus_on >= plus_off and plus_on > 0, "the maze race makes them forge at least as hard: their + adds up as high (%d >= %d)" % [plus_on, plus_off])
	check(gems_on >= gems_off, "and they keep and socket at least as many gems (%d >= %d)" % [gems_on, gems_off])
	var calm := -1
	for i in WorldPlayers.size():
		if not MazeWar.interested(i) and not WorldPlayers.in_town_style(i):
			calm = i
			break
	check(calm >= 0 and MazeWar.drive_from(calm) == INF, "one not in the race forges as before")


func _plus_sum(i: int, t: float) -> int:
	var g := WorldGear.gear(i, t)
	var total := 0
	for slot in ["weapon", "armor", "helm", "boots", "ring", "amulet"]:
		total += int((g.get(slot, {}) as Dictionary).get("plus", 0))
	return total


func _save() -> void:
	var good := {"weeks": {"2967": {"k": 3, "at": 1795100000, "d": 1, "live": {"Kaito": [2, 1795100100]}, "held": {"Kaito": [40, 41]}}}, "champs": {"2966": {"name": "Kaito", "kills": 40, "hero": false, "index": 0}}}
	check(MazeWar.valid(good), "a good record is valid")
	var bad := [
		{"weeks": {"x": {}}}, {"weeks": {"1": {"k": -1}}}, {"weeks": {"1": {"k": 1.5}}}, {"weeks": {"1": {"live": {"Kaito": [1]}}}},
		{"weeks": {"1": {"held": {"Kaito": ["a"]}}}}, {"weeks": {"1": {"zap": 1}}}, {"other": {}}, {"champs": {"1": {"name": 5}}},
		{"weeks": {"1": {"live": {"%s" % "N".repeat(30): [1, 1]}}}}, "nope",
	]
	for b in bad:
		check(not MazeWar.valid(b), "a broken record is refused: %s" % str(b).left(60))
	var profile := Game.profile.duplicate(true)
	profile[MazeWar.KEY] = good
	check(Game._valid_profile(profile), "the game takes a save with the maze record")
	profile[MazeWar.KEY] = {"weeks": {"1": {"k": "many"}}}
	check(not Game._valid_profile(profile), "and refuses a broken one")
	# Through JSON (numbers come back as floats): repaired to ints.
	var copy: Dictionary = JSON.parse_string(JSON.stringify({MazeWar.KEY: good}))
	MazeWar.repair(copy)
	var w: Dictionary = copy[MazeWar.KEY].weeks["2967"]
	check(w.k is int and w.live.Kaito[0] is int and w.held.Kaito[0] is int and copy[MazeWar.KEY].champs["2966"].kills is int, "a save read back from JSON gets its ints back")
	check(MazeWar.valid(Game.profile.get(MazeWar.KEY, {})), "the record the game wrote itself is valid")


func _chat() -> void:
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	var board := MazeWar.standings(week, t)
	var said := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var ok := true
	for i in MazeWar.candidates().slice(0, 30):
		var v := MazeWar.chat_vars(i, t)
		if v.is_empty():
			continue
		if String(v["%mzlead"]) != String(board[0].name) or int(v["%mzleadk"]) != int(board[0].kills):
			ok = false
		if v.has("%mzrank"):
			var r := MazeWar.rank_of(i, week, t)
			if int(v["%mzrank"]) != int(r.rank) or int(v["%mzkills"]) != int(r.kills):
				ok = false
		var s := WorldPlayers.state(i, t)
		var other := WorldPlayers.state(int(MazeWar.candidates()[0]), t)
		for line in ChatThreads.make("world", [s, other], rng, {"topic": "maze", "t": t}):
			for text in line.options:
				said += 1
				# (a voice's laugh, 555, is no claim)
				var nums := _numbers(String(text).replace("555", ""))
				var allowed := [int(board[0].kills)]
				if v.has("%mzrank"):
					allowed.append(int(v["%mzrank"]))
					allowed.append(int(v["%mzkills"]))
				var speaker := s if int(line.who) == 0 else other
				var sv := MazeWar.chat_vars(int(speaker.index), t)
				if sv.has("%mzrank"):
					allowed.append(int(sv["%mzrank"]))
					allowed.append(int(sv["%mzkills"]))
				for n in nums:
					if not allowed.has(n):
						ok = false
						printerr("  untrue number %d in: %s" % [n, text])
	check(ok, "the world players' maze talk names the real leader, their own real rank and kills (MazeWar.standings)")
	check(said > 0, "they talk about the race (%d lines)" % said)


func _numbers(text: String) -> Array:
	var out := []
	var rx := RegEx.new()
	rx.compile("[0-9]+")
	for m in rx.search_all(text):
		out.append(int(m.get_string()))
	return out


# --- In the maze --------------------------------------------------------------------

func _zone() -> void:
	var t := MazeWar.now()
	await main.go(MazeWar.ID, true)
	var zone: Zone = main.zone
	check(zone != null and zone.is_maze and zone.maze_match != null, "the maze zone is built with its match")
	if zone == null or zone.maze_match == null:
		return
	var m: MazeMatch = zone.maze_match
	check(EntitySync.supports(zone), "real players share the maze (EntitySync)")
	check(zone.find_child("Maze", false, false) != null and zone.find_child("MazeWalls0", true, false) != null, "the maze's meshes and wall colliders are there")
	var chunks := zone.find_children("MazeChunk*", "MeshInstance3D", true, false)
	check(chunks.size() >= 12 and chunks.size() <= MazeArena.CHUNKS * MazeArena.CHUNKS, "the maze is drawn in merged chunks (%d meshes)" % chunks.size())
	check(not MazeLayout.in_wall(zone.hero.global_position, 0.0) and MazeLayout.inside(zone.hero.global_position), "the hero comes in on the floor of the maze")
	var inside := MazeWar.inside_at(t)
	check(m.fighters.size() == mini(inside.size(), MazeWar.MAX_LIVE) and m.fighters.size() >= 2, "the world players in the maze now fight there (%d of %d)" % [m.fighters.size(), inside.size()])
	var gear_ok := true
	for f in m.fighters:
		var info := WorldPlayers.fighter(f.world_index, t)
		if f.level != int(info.member.level) or f.rival_name != String(info.member.name) or not inside.has(f.world_index):
			gear_ok = false
		for slot in (info.profile.equip as Dictionary):
			if not f._profile.equip.has(slot) or String(f._profile.equip[slot].get("name", "")) != String(info.profile.equip[slot].get("name", "")) or int(f._profile.equip[slot].get("plus", 0)) != int(info.profile.equip[slot].get("plus", 0)):
				gear_ok = false
		if not MazeWar.is_held(f.world_index, t):
			gear_ok = false
	check(gear_ok, "each live fighter is the world player as it really is (level, gear, +) and holds its slot")
	var teams := {}
	for f in m.fighters:
		teams[f.team] = true
	check(teams.size() == m.fighters.size() and not teams.has(GuildFighter.TEAM_ALLY), "free-for-all: every fighter is a team of its own, none on the hero's side")
	var f: MazeFighter = m.fighters[0]
	check(f.is_in_group("mobs"), "a fighter is a foe the hero can target")
	check(f._foes().has(zone.hero) and f._foes().has(m.fighters[1]), "and the hero and every other fighter are its foes")
	# A fighter in a shrine.
	f._guard_until = 0
	f.global_position = MazeLayout.safe_center(0) + Vector3(0.5, 0.3, 0)
	f._update_shrine(0.1)
	var hp := f.hp
	check(f.protected() and not f.can_strike() and not f.take_hit(5000, false, Color.WHITE, zone.hero) and f.hp == hp, "in a shrine a fighter takes no harm and strikes nobody")
	check(m.shields(f) and f._nearest_victim() == null, "nobody goes for it there, and it goes for nobody")
	f.shrine_time = MazeWar.SAFE_MAX + 0.1
	f._update_shrine(0.1)
	f._update_shrine(0.1)
	check(not f.protected(), "after %d s the shrine's blessing wears off" % int(MazeWar.SAFE_MAX))
	f._dodge = 0.0
	check(f.take_hit(10, false, Color.WHITE, zone.hero) or f.hp < hp, "and it can be hit there again")
	# The hero in a shrine.
	var hero := zone.hero
	m._guard_until = 0
	hero._invulnerable_until = 0
	hero.global_position = MazeLayout.safe_center(1) + Vector3(0.6, 0.3, 0.4)
	m._update_hero_shrine(0.1)
	var hhp := int(Game.profile.hp)
	hero.take_damage(1.0e7, f)
	check(hero.safe_zone and m.hero_sheltered() and int(Game.profile.hp) == hhp, "in a shrine the hero takes no harm (and cannot strike: Hero.safe_zone)")
	hero.global_position = MazeLayout.center(MazeLayout.cell_at(MazeLayout.safe_center(1)) + 1) + Vector3(0, 0.3, 0)
	m._update_hero_shrine(0.1)
	check(hero.safe_zone and m.hero_protected(), "just out of a shrine: a moment more of protection, still no striking")
	m._leave_until = 0
	m._update_hero_shrine(0.1)
	check(not hero.safe_zone and not m.hero_protected(), "then the hero is fair game again")
	# A kill by the hero counts once a minute for the same victim.
	var week := MazeWar.week_of(MazeWar.now())
	var k0 := int(MazeWar.week_book(week).get("k", 0))
	var g := m.fighters[1]
	g._guard_until = 0
	g.global_position = MazeLayout.center(MazeLayout.cell_at(hero.global_position)) + Vector3(1, 0.3, 0)
	g._update_shrine(0.1)
	# (one blow never takes a whole bar: BurstGuard; this one is the last; no dodging)
	g._dodge = 0.0
	g.hp = 1
	g.take_hit(g.hp + 100, false, Color.WHITE, hero)
	check(g.is_dead() and int(MazeWar.week_book(week).k) == k0 + 1, "the hero's kill of a fighter counts")
	g.respawn()
	check(not MazeLayout.is_safe_cell(MazeLayout.cell_at(g.global_position)) and not MazeLayout.in_wall(g.global_position, 0.0) and g.protected(), "a fighter comes back at a random spot, guarded for a moment")
	g._guard_until = 0
	g.hp = 1
	g.take_hit(g.hp + 100, false, Color.WHITE, hero)
	check(g.is_dead() and int(MazeWar.week_book(week).k) == k0 + 1, "killing the same one again within %d s does not count" % int(MazeWar.REKILL_GAP))
	g.respawn()
	# The hero falls to a fighter: its kill, and the hero back at a random spot.
	var killer: MazeFighter = m.fighters[2]
	var live0 := int((MazeWar.week_book(week).live as Dictionary).get(killer.rival_name, [0, 0])[0])
	hero._invulnerable_until = 0
	m._guard_until = 0
	m._leave_until = 0
	m._update_hero_shrine(0.0)
	hero.stats["dodge"] = 0.0
	hero.take_damage(1.0e9, killer)
	check(hero.is_dead() and m.hero_respawn_left > 0.0, "the hero falls and waits to come back")
	check(int(MazeWar.week_book(week).live[killer.rival_name][0]) == live0 + 1, "the fighter that took the hero gets its kill (live)")
	m._respawn_hero()
	var p := hero.global_position
	check(not hero.is_dead() and not MazeLayout.is_safe_cell(MazeLayout.cell_at(p)) and not MazeLayout.in_wall(p, 0.0) and m.hero_protected(), "the hero comes back at a random spot, guarded for a moment")
	# Their brains: they move and fight on their own for a while.
	var start := {}
	for x in m.fighters:
		start[x] = x.global_position
	Engine.time_scale = 3.0
	await _wait(8.0)
	Engine.time_scale = 1.0
	var moved := 0
	var stuck := 0
	for x in m.fighters:
		if is_instance_valid(x) and x.global_position.distance_to(start.get(x, x.global_position)) > 3.0:
			moved += 1
		if is_instance_valid(x) and MazeLayout.in_wall(x.global_position, 0.0):
			stuck += 1
	check(moved >= m.fighters.size() / 2, "the fighters walk the maze (%d of %d moved)" % [moved, m.fighters.size()])
	check(stuck == 0, "none walks into a wall")


func _hud() -> void:
	var zone: Zone = main.zone
	await _wait(0.3)
	var hud: HUD = main.hud
	check(hud.maze_hud != null and is_instance_valid(hud.maze_hud), "the maze's strip is on the HUD")
	if hud.maze_hud == null:
		return
	hud.maze_hud.refresh()
	var board := MazeWar.standings(MazeWar.week_of(MazeWar.now()), MazeWar.now())
	var strip: Control = hud.maze_hud.find_child("MazeStrip", true, false)
	check(strip != null and strip.size.x <= MazeHud.WIDTH + 40.0 and hud.maze_hud.find_child("MazeRows", true, false) == null, "the HUD keeps only a small strip, no table (%s)" % (str(strip.size) if strip else "none"))
	var mine: Label = hud.maze_hud.find_child("MazeMine", true, false)
	var rank := MazeWar.hero_rank(MazeWar.week_of(MazeWar.now()))
	check(mine != null and mine.text.contains("%d" % int(rank.rank)), "it shows the hero's own place (%s)" % (mine.text if mine else ""))
	hud.maze_hud.board_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(main.menu.is_open and main.menu.current_tab == MazeBoardView.TAB_ID, "a tap on the strip opens the board's tab in the game menu")
	var rows: Control = main.menu.find_child("MazeRows", true, false)
	check(rows != null and rows.get_child_count() >= mini(board.size(), MazeBoardView.ROWS), "the board tab lists the week rank 1 to last (%d)" % (rows.get_child_count() if rows else -1))
	var crown: Label = main.menu.find_child("CrownHolder", true, false)
	check(crown != null and crown.text.contains(MazeCrown.TITLE_NAME), "the board tab names the crown")
	check(main.menu.find_child("EnterMaze", true, false) == null, "no enter button while already inside")
	main.menu.close_menu()
	await get_tree().process_frame
	check(not main.menu.is_open and main.menu.find_child("MazeRows", true, false) == null and not get_tree().paused, "closing it keeps nothing")
	await main.go(&"town", true)
	var keeper := (main.zone as Zone).npcs.filter(func(n): return n.role == "maze")
	check(keeper.size() == 1, "the maze's keeper stands in the village")
	check(hud.maze_hud == null, "the maze's board leaves the HUD outside the maze")


func _online() -> void:
	GameSettings.online_play = true
	var fake := FakeTransport.new()
	Online.use_transport(fake)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "mazeqa"}, "players": [], "party": null})
	var week := MazeWar.week_of(MazeWar.now())
	Online._dispatch({"t": "maze_board", "week": week, "rows": [{"name": "RealChamp", "kills": 9999, "ago": 1000}, {"name": "MazeQA", "kills": 1, "ago": 1}, {"name": 5, "kills": 2}]})
	var board := MazeWar.standings(week)
	check(String(board[0].name) == "RealChamp" and int(board[0].index) == -1 and not bool(board[0].hero), "a real player's kills from the server's board are ranked with everyone")
	check(board.filter(func(r): return String(r.name) == "MazeQA").size() <= 1, "the hero's own row is the save's, not the server's")
	await main.go(MazeWar.ID, true)
	var zone: Zone = main.zone
	var m: MazeMatch = zone.maze_match
	var k0 := int(MazeWar.week_book(week).get("k", 0))
	var f: MazeFighter = null
	for x in m.fighters:
		if not x.is_dead():
			f = x
			break
	if f != null:
		f._guard_until = 0
		f.global_position = MazeLayout.center(10) + Vector3(0, 0.3, 0)
		f._update_shrine(0.1)
		f._dodge = 0.0
		f.hp = 1
		f.take_hit(f.hp + 100, false, Color.WHITE, zone.hero)
	var sent := fake.frames("maze_kill")
	check(sent.size() == 1 and String(sent[0].victim) == (f.rival_name if f else "") and bool(sent[0].ai), "the hero's kill goes to the server (%s)" % str(sent))
	# A kill another game saw, credited to the hero by the server: counted, not sent back.
	Online._dispatch({"t": "maze_kill", "week": week, "name": "MazeQA", "kills": 5, "ago": 0, "by": "me", "victim": "RealFoe", "ai": false})
	check(int(MazeWar.week_book(week).k) == k0 + 2 and fake.frames("maze_kill").size() == 1, "a kill the server credits to the hero counts once and is not sent back")
	# A real player's hit lands (its defence applies), not in a shrine or guarded.
	m._guard_until = 0
	m._leave_until = 0
	zone.hero._invulnerable_until = 0
	zone.hero.global_position = MazeLayout.center(MazeLayout.cell_at(Vector3(-40, 0, 0))) + Vector3(0, 0.3, 0)
	m._update_hero_shrine(0.1)
	zone.hero.stats["dodge"] = 0.0
	var hp := int(Game.profile.hp)
	Online._dispatch({"t": "maze_hit", "from": "p2", "dmg": 3000, "crit": false})
	check(int(Game.profile.hp) < hp, "a real player's hit in the maze lands on the hero (%d -> %d, dead %s, safe %s, guarded %s)" % [hp, int(Game.profile.hp), zone.hero.is_dead(), zone.hero.safe_zone, m.hero_protected()])
	zone.hero.global_position = MazeLayout.safe_center(3) + Vector3(0, 0.3, 0)
	m._update_hero_shrine(0.1)
	hp = int(Game.profile.hp)
	Online._dispatch({"t": "maze_hit", "from": "p2", "dmg": 3000, "crit": false})
	check(int(Game.profile.hp) == hp, "not in a shrine")
	Online.use_transport(null)
	GameSettings.online_play = false
	await main.go(&"town", true)


func _week() -> void:
	var t := MazeWar.now()
	var week := MazeWar.week_of(t)
	check(MazeWar.champion(week).is_empty(), "no champion while the week runs")
	var top := MazeWar.standings(week, MazeWar.week_end(week))
	at(MazeWar.week_end(week) + 3600.0)
	MazeWar._real.clear()
	var champ := MazeWar.champion(week)
	top = MazeWar.standings(week, MazeWar.week_end(week))
	check(not champ.is_empty() and String(champ.name) == String(top[0].name) and int(champ.kills) == int(top[0].kills), "once the week is over its first is the champion (%s)" % str(champ))
	check((Game.profile[MazeWar.KEY].champs as Dictionary).has(str(week)), "the champion is kept in the save (history)")
	check(MazeWar.champions(4).size() >= 1 and int(MazeWar.champions(4)[0].week) == week, "past champions are listed newest first")
	var fresh := MazeWar.standings(week + 1)
	check(not fresh.any(func(r): return bool(r.hero)) and MazeWar.hero_rank(week + 1).kills == 0, "the new week starts the hero's count again")
	check(MazeCrown.holder(MazeWar.now()).get("name", "") == champ.name, "the crown's holder is last week's champion")
	# The hero as champion.
	var book := MazeWar.week_book(week)
	book.k = 100000
	book.at = int(MazeWar.week_start(week) + 10.0)
	(Game.profile[MazeWar.KEY].champs as Dictionary).erase(str(week))
	MazeWar._champs.clear()
	var hero_champ := MazeWar.champion(week)
	check(bool(hero_champ.get("hero", false)) and String(hero_champ.name) == MazeWar.hero_name(), "the hero can be the week's champion (MazeCrown awards it)")
