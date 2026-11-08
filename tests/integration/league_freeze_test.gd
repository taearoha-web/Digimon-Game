extends Node
## Past league rounds are frozen (GuildLeague, LeagueRounds): an ended round is worked out
## once and never again, even when the seeded inputs change (a code update that changes
## fighter power: here the seed's salt); the server's official results override this
## device's own; the device's record survives a restart without a server; a round still
## running or yet to come is never shown as decided; the chain of castle holders goes on
## from the frozen holder; ended rounds the server lacks are posted (the hero's fought
## round at once) and the server's answer (first writer wins) is adopted.
##   godot --headless --path . res://tests/integration/league_freeze_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0


## A stand-in for /api/league/* (hosting/worker/league.mjs): first writer wins, an
## unfinished round is refused.
class FakeServer:
	extends RefCounted
	var rounds := {}
	var replies := {}
	var seq := 0
	var posts: Array = []
	var gets := 0

	func send(method: String, path: String, body: String) -> int:
		seq += 1
		var status := 404
		var out: Variant = {}
		if method == "GET" and path.begins_with(LeagueRounds.API_ROUNDS):
			gets += 1
			var q := path.get_slice("?", 1)
			var from := int(q.get_slice("from=", 1).get_slice("&", 0))
			var to := int(q.get_slice("to=", 1))
			var list: Array = []
			var keys := rounds.keys()
			keys.sort()
			for at in keys:
				if int(at) >= from and int(at) <= to:
					list.append({"at": int(at), "result": rounds[at]})
			status = 200
			out = {"rounds": list, "now": int(LeagueRounds.now())}
		elif method == "POST" and path == LeagueRounds.API_ROUND:
			var b: Variant = JSON.parse_string(body)
			var at := int(b.at)
			posts.append(b)
			if LeagueRounds.now() < float(at) + GuildWarData.DURATION - LeagueRounds.SERVER_MARGIN:
				status = 409
			elif rounds.has(at):
				status = 200
				out = {"stored": false, "round": {"at": at, "result": rounds[at]}}
			else:
				rounds[at] = b.result
				status = 201
				out = {"stored": true, "round": {"at": at, "result": b.result}}
		replies[seq] = JSON.stringify({"status": status, "body": JSON.stringify(out)})
		return seq

	func poll(id: int) -> String:
		var v: String = replies.get(id, "")
		replies.erase(id)
		return v


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	LeagueRounds.persist = false
	LeagueRounds.transport = null
	LeagueRounds.reset()
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * DAY)
	_frozen(w)
	_restart(w)
	_not_decided(w)
	_official(w)
	_posting(w)
	_hero_round(w)
	GuildLeague.sim_salt = ""
	LeagueRounds.transport = null
	LeagueRounds.persist_moved_clock = false
	WorldPresence.clock_offset = 0.0
	print("LEAGUE FREEZE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero(g: int) -> void:
	Game.new_profile(&"warrior", "Freeze QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.join_guild(g)


## Every round of season w over by now: [at].
func _ended(w: int) -> Array[int]:
	var out: Array[int] = []
	for m in GuildLeague.schedule(w):
		if GuildLeague.ended(int(m.at)):
			out.append(int(m.at))
	return out


func _holders(list: Array[int]) -> Array:
	return list.map(func(at): return GuildLeague.holder_after(at))


func _results(list: Array[int]) -> Array:
	return list.map(func(at): return GuildLeague.round_results(at, GuildLeague.start_holder(at), []))


func _frozen(w: int) -> void:
	# Wednesday 13:00 Thai: Monday's, Tuesday's and today's 12:00 rounds are over.
	pin(GuildLeague.week_start(w) + 2.0 * DAY + 13.0 * 3600.0)
	var list := _ended(w)
	check(list.size() == 7, "seven rounds of the week are over (%d)" % list.size())
	var holders := _holders(list)
	var results := _results(list)
	var table := GuildLeague.table(w, [])
	check(list.all(func(at): return not LeagueRounds.seen_of(at).is_empty()), "each ended round is kept once worked out")
	# A code update changes the seeded results (fighter power, AI, balance...).
	GuildLeague.sim_salt = "|update"
	GuildLeague._sim_cache.clear()
	GuildLeague._power_cache.clear()
	GuildLeague._champ_cache.clear()
	var changed := 0
	for at in list:
		var own := GuildLeague.start_holder(at)
		if GuildLeague.sim_round(at, own) != LeagueRounds.seen_of(at):
			changed += 1
	check(changed > 0, "the update would seed the ended rounds differently (%d of %d)" % [changed, list.size()])
	check(_holders(list) == holders, "but the castle's holders of the ended rounds stay as they were")
	check(_results(list) == results, "and so do the rounds' results")
	check(GuildLeague.table(w, []) == table, "and the table")
	# The chain goes on from the frozen holder: the next round to end is seeded from it.
	var next := GuildLeague.next_slot(GuildLeague.now())
	var frozen_holder := GuildLeague.holder_after(list[list.size() - 1])
	check(GuildLeague.start_holder(next) == frozen_holder, "the next round begins with the frozen holder")
	pin(float(next) + GuildWarData.DURATION + 1.0)
	check(GuildLeague.holder_after(next) == GuildLeague._after(GuildLeague.round_results(next, frozen_holder, []), frozen_holder), "and is worked out from it")
	check(int(LeagueRounds.seen_of(next).get("own", -1)) == frozen_holder, "its frozen result began with the frozen holder")
	check(_holders(list) == holders, "the older rounds still stand")


func _restart(w: int) -> void:
	# The device's record is in its own file (not the save): a restart reads it back, even
	# with the update's seeding and no server.
	var path := "user://league_freeze_test.json"
	LeagueRounds.path = path
	LeagueRounds.persist = true
	LeagueRounds.persist_moved_clock = true
	pin(GuildLeague.week_start(w) + 2.0 * DAY + 13.0 * 3600.0)
	var list := _ended(w)
	var holders := _holders(list)
	var results := _results(list)
	LeagueRounds.save_file()
	check(FileAccess.file_exists(path), "the frozen rounds are written to user://")
	GuildLeague.sim_salt = "|another update"
	GuildLeague._sim_cache.clear()
	LeagueRounds.reset()
	LeagueRounds.load_file()
	check(list.all(func(at): return not LeagueRounds.seen_of(at).is_empty()), "and read back after a restart")
	check(_holders(list) == holders and _results(list) == results, "the ended rounds stand after the restart and another update (offline)")
	# A round kept with a moved world clock (ahead of the real one) is no history.
	LeagueRounds.persist_moved_clock = false
	LeagueRounds.load_file()
	var real_now := WorldPlayers.now()
	check(LeagueRounds.seen.keys().all(func(at): return float(at) + GuildWarData.DURATION <= real_now + LeagueRounds.SERVER_MARGIN), "rounds from a moved clock are not read back as history")
	LeagueRounds.persist_moved_clock = true
	LeagueRounds.load_file()
	LeagueRounds.persist = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	LeagueRounds.path = LeagueRounds.PATH


func _not_decided(w: int) -> void:
	# Wednesday 18:05: the 18:00 round is being fought.
	var live := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 1)
	# (The tests above already moved the clock past this round: start this device afresh.)
	LeagueRounds.reset()
	pin(float(live) + 300.0)
	var prev := GuildLeague.prev_slot(live)
	var later := GuildLeague.next_slot(float(live))
	var far := GuildLeague.slot_start(WorldEvents.day_of(float(live)) + 2, 0)
	check(String(GuildLeague.round_state(live).state) == "live", "the round on now is live")
	check(String(GuildLeague.round_state(later).state) == "wait" and String(GuildLeague.round_state(far, float(far) + DAY).state) == "wait", "later rounds wait (even asked about a later time)")
	check(GuildLeague.events(w, []).all(func(e): return int(e.at) < live), "the table counts no round still running or to come")
	check(GuildLeague.table(w, []) == GuildLeague.table(w, [], GuildLeague.now()), "a table asked about the week's end is today's")
	var now_holder := GuildLeague.holder_after(prev)
	check(GuildLeague.start_holder(live) == now_holder, "the live round began with the holder of the round before")
	check(GuildLeague.holder_after(live) == now_holder and GuildLeague.holder_after(far) == now_holder, "a running or future round foretells no holder")
	check(GuildLeague.start_holder(later) == now_holder and GuildLeague.start_holder(far) == now_holder, "later rounds begin, as far as anyone knows, with today's holder")
	check(GuildLeague.holder(w, []) == now_holder, "the holder now")
	check(LeagueRounds.seen.keys().all(func(at): return GuildLeague.ended(int(at))), "no running or future round is kept as decided")
	check(LeagueRounds.result_of(live).is_empty() and LeagueRounds.result_of(later).is_empty(), "the live and next rounds have no result")


func _official(w: int) -> void:
	# The server has a different result of an ended round: it wins over this device's.
	pin(GuildLeague.week_start(w) + 2.0 * DAY + 20.0 * 3600.0)
	var list := _ended(w)
	var server := FakeServer.new()
	var at1 := list[2]
	_holders(list)  # every ended round worked out (and kept) on this device
	var mine := LeagueRounds.seen_of(at1)
	var other := 0
	for g in mine.g:
		if int(g) != int(mine.held):
			other = int(g)
			break
	var theirs: Dictionary = mine.duplicate(true)
	theirs["held"] = other
	server.rounds[at1] = theirs
	# The latest ended round too: the chain goes on from its official holder.
	var last := list[list.size() - 1]
	var lmine := LeagueRounds.seen_of(last)
	var lother := 0
	for g in lmine.g:
		if int(g) != int(lmine.held) and int(g) != other:
			lother = int(g)
			break
	var ltheirs: Dictionary = lmine.duplicate(true)
	ltheirs["held"] = lother
	server.rounds[last] = ltheirs
	LeagueRounds.transport = server
	LeagueRounds._fetch_at = 0.0
	LeagueRounds.poll()
	LeagueRounds.poll()
	check(server.gets >= 1 and LeagueRounds.is_official(at1) and LeagueRounds.is_official(last), "the server's rounds are fetched")
	check(GuildLeague.holder_after(at1) == other, "the official holder overrides this device's")
	var state := GuildLeague.round_state(at1)
	check(bool(state.get("official", false)) and int(state.war.held) == other, "the desk shows the official result")
	var counted := GuildLeague.events(w, []).filter(func(e): return int(e.at) == at1)
	check(counted.size() == 1 and int(counted[0].held) == other, "and the table counts it")
	check(GuildLeague.holder_after(last) == lother and GuildLeague.holder(w, []) == lother, "the castle is with the official holder of the latest round")
	var next := GuildLeague.next_slot(GuildLeague.now())
	check(GuildLeague.start_holder(next) == lother, "the next round begins with it")
	pin(float(next) + GuildWarData.DURATION + 1.0)
	GuildLeague.holder_after(next)
	check(int(LeagueRounds.result_of(next).get("own", -1)) == lother, "and is worked out from it")


func _posting(w: int) -> void:
	# The rounds of this season and the last the server lacks are posted, POST_DELAY after
	# their bell; the server keeps the first and answers with it.
	var server: FakeServer = LeagueRounds.transport
	pin(GuildLeague.week_start(w) + 2.0 * DAY + 21.0 * 3600.0)
	var due := LeagueRounds.due(GuildLeague.now())
	check(not due.is_empty(), "ended rounds the server lacks are due to be posted (%d)" % due.size())
	for i in 200:
		LeagueRounds.poll()
		if LeagueRounds.due(GuildLeague.now()).is_empty() and LeagueRounds._pending.is_empty():
			break
	var window := LeagueRounds.window(GuildLeague.now())
	var all_in := true
	var same := true
	var at := GuildLeague.next_slot(float(window.x) - 1.0)
	while GuildLeague.ended(at):
		all_in = all_in and server.rounds.has(at) and LeagueRounds.is_official(at)
		same = same and LeagueRounds.clean(at, server.rounds.get(at)) == LeagueRounds.result_of(at)
		at = GuildLeague.next_slot(float(at))
	check(all_in, "every ended round of the two seasons is on the server (%d stored)" % server.rounds.size())
	check(same, "with this device's results, and the device adopted them")
	# A round just over: a device that did not take part waits POST_DELAY.
	var bell := float(at) + GuildWarData.DURATION
	pin(bell + 10.0)
	check(not LeagueRounds.due(GuildLeague.now()).has(at), "a seeded round is not posted right at the bell")
	pin(bell + LeagueRounds.POST_DELAY + 1.0)
	check(LeagueRounds.due(GuildLeague.now()).has(at), "but after POST_DELAY")
	# Another device was first: its result is adopted.
	GuildLeague.holder_after(at)
	var first: Dictionary = LeagueRounds.seen_of(at).duplicate(true)
	first["k"] = (first.k as Array).map(func(v): return int(v) + 1)
	server.rounds[at] = first
	for i in 4:
		LeagueRounds.poll()
	check(LeagueRounds.official_of(at) == LeagueRounds.clean(at, first), "the first writer's result is adopted (%s)" % [LeagueRounds.official_of(at)])


func _hero_round(w: int) -> void:
	# The hero fights a round: its result is posted at once (before the seeded ones).
	var server: FakeServer = LeagueRounds.transport
	_hero(WorldPlayers.TITAN)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 3, 0)
	pin(float(at) + GuildWarData.DURATION + 2.0)
	var own := GuildLeague.start_holder(at)
	GuildLeague.current_match = {"guilds": [3, 1, 2, 4], "at": at, "owner": own}
	GuildLeague.war_finished({"won": true}, true, [2, 0, 0, 0], 0, [44, 9, 8, 7])
	check(LeagueRounds.due(GuildLeague.now()).has(at), "the hero's round is due at once")
	for i in 4:
		LeagueRounds.poll()
	check(server.rounds.has(at) and int(server.rounds[at].held) == WorldPlayers.TITAN, "the hero's real result is the round's official one")
	check(GuildLeague.holder_after(at) == WorldPlayers.TITAN, "and the castle is Titan's")
	# A round the server already has: the hero's own result does not replace it.
	var at2 := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 3, 1)
	pin(float(at2) + GuildWarData.DURATION + 2.0)
	var theirs := {"at": at2, "g": [1, 2, 3, 4], "k": [30, 1, 1, 1], "c": [2, 0, 0, 0], "held": 1, "own": 3}
	server.rounds[at2] = theirs
	GuildLeague.current_match = {"guilds": [3, 1, 2, 4], "at": at2, "owner": 0}
	GuildLeague.war_finished({"won": true}, true, [2, 0, 0, 0], 0, [44, 9, 8, 7])
	for i in 4:
		LeagueRounds.poll()
	check(int(server.rounds[at2].held) == WorldPlayers.ALPHA, "the server keeps the first result")
	check(GuildLeague.holder_after(at2) == WorldPlayers.ALPHA and GuildLeague.holder(w, GuildLeague.real_wars(w)) == WorldPlayers.ALPHA, "and every device follows it, the hero's too")
	var state := GuildLeague.round_state(at2)
	check(bool(state.get("real", false)) and bool(state.get("official", false)) and int(state.war.held) == WorldPlayers.ALPHA, "the desk shows the official result, marked as fought")
