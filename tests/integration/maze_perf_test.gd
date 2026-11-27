extends Node
## The maze's world players without long frames, the very same results (MazeWar, WorldGear):
## - a slot's fights worked out a step at a time (MazeWar._prepare, as warm does each frame)
##   are the fights the old one-go reading gives (its power: the gear and stats as the Thai
##   day began, read afresh here), on many players and days, and no step takes long;
## - warm catches a cold week up a frame budget at a time; the paced board read meanwhile
##   stays cheap and never counts more than the board will; caught up, it is the very
##   board an unpaced read works out from nothing;
## - a world player's forging run a stretch at a time (WorldGear.advance) is the same
##   forging as run in one go, events and states alike;
## - the next guild war's sides worked out ahead (GuildWarData.warm_sides) read the very
##   powers a cold world gives, and quicker;
## - the world's indices stay inside the keys that hold them (MazeWar, WorldGear).
## A world of the ROSTER and MAZE_PERF_N newcomers (default 1500, made as WorldPlayers makes
## them, past NEWCOMER_MAX), read on day MAZE_PERF_DAY (default 241) after the opening.
##   godot --headless --path . res://tests/integration/maze_perf_test.tscn
var failures := 0
var checks := 0
## The longest single step allowed (a frame's budget is 1.5 ms; a step may run over by
## one stretch of forging or one power read; loose for a busy machine).
const STEP_MS := 40.0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _grow(n: int) -> void:
	WorldPlayers.reset_roster()
	var k := 0
	while WorldPlayers._gen_count < n:
		k += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("newcomers|%d|%d" % [WorldPlayers.START_UNIX, k])
		var count := rng.randi_range(WorldPlayers.NEWCOMERS.x, WorldPlayers.NEWCOMERS.y)
		var midnight := float(WorldPlayers._first_day() + k) * 86400.0 - WorldPlayers.TZ
		var times: Array[float] = []
		for j in count:
			times.append(rng.randf_range(midnight + 1800.0, midnight + 86400.0 - 1800.0))
		times.sort()
		for at in times:
			if WorldPlayers._gen_count >= n:
				break
			var e := WorldPlayers._newcomer(WorldPlayers._gen_count, rng, at)
			e["day"] = k
			WorldPlayers._index[String(e.name)] = WorldPlayers._all.size()
			WorldPlayers._all.append(e)
			WorldPlayers._gen_count += 1
	WorldPlayers._gen_day = 100000


## The power as MazeWar read it before (no cache): its real stats as the day began.
func _old_power(i: int, t: float) -> float:
	var day := WorldEvents.day_of(t)
	var start := maxf(float(day) * 86400.0 - float(WorldPlayers.TZ), WorldPlayers.joined_at(i))
	var sheet := WorldPlayers.profile(MazeWar._sheet_at(i, start))
	return maxf(1.0, GuildWarData.power_of(HeroStats.compute(sheet)))


## Slot k's fights as MazeWar worked them out before, in one go.
func _old_slot_fights(k: int) -> Array:
	var out: Array = []
	var t0 := MazeWar.slot_start(k)
	var mid := t0 + MazeWar.SLOT * 0.5
	var people := MazeWar.inside_at(mid)
	var n := people.size()
	if n < 2:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("maze_slot|%d" % k)
	var powers: Array[float] = []
	for i in people:
		powers.append(_old_power(i, mid))
	var crowd := clampf(float(n - 1) / MazeWar.CROWD, 0.3, 1.0)
	var mean := MazeWar.FIGHTS_PER_MIN * MazeWar.SLOT / 60.0 * float(n) * 0.5 * crowd
	var count := int(mean) + (1 if rng.randf() < mean - floor(mean) else 0)
	for f in count:
		var a := rng.randi() % n
		var b := rng.randi() % (n - 1)
		if b >= a:
			b += 1
		var at := t0 + rng.randf() * MazeWar.SLOT
		var a_wins := rng.randf() < MazeWar.win_chance(powers[a], powers[b])
		out.append([at, people[a] if a_wins else people[b], people[b] if a_wins else people[a]])
	out.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	return out


func _ms_since(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


## Works slot k out the way warm does (budget microseconds a call): {calls, max (ms)}.
func _sliced(k: int, budget: int) -> Dictionary:
	var calls := 0
	var most := 0.0
	while true:
		var t0 := Time.get_ticks_usec()
		var done := MazeWar._prepare(k, t0 + budget)
		most = maxf(most, _ms_since(t0))
		calls += 1
		if done:
			break
	return {"calls": calls, "max": most}


func _board_key(board: Array) -> String:
	var parts: PackedStringArray = []
	for r in board:
		parts.append("%s:%d:%.3f" % [String(r.name), int(r.kills), float(r.at)])
	return ",".join(parts)


## The gear worn without the pieces' uids (made afresh with each item).
func _gear_key(equip: Dictionary) -> String:
	var parts: PackedStringArray = []
	for slot in equip:
		var item: Dictionary = (equip[slot] as Dictionary).duplicate()
		item.erase("uid")
		parts.append("%s=%s" % [slot, str(item)])
	return ";".join(parts)


func _events_key(i: int) -> String:
	var sim: WorldGear.Sim = WorldGear._sims[i]
	var parts: PackedStringArray = []
	for ev in sim.events:
		parts.append("%.5f|%s|%s|%d|%d|%s|%s" % [float(ev.w), ev.kind, ev.slot, int(ev.from), int(ev.to), ev.item, str(ev.get("key", ""))])
	return "\n".join(parts)


func _ready() -> void:
	Game.set_process(false)
	Announcer.ticking = false
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	MazeWar.reset()
	MazeWar.ai_mode = 1
	MazeWar.pace_mode = 0
	var n := int(OS.get_environment("MAZE_PERF_N")) if OS.get_environment("MAZE_PERF_N") != "" else 1500
	var day := float(OS.get_environment("MAZE_PERF_DAY")) if OS.get_environment("MAZE_PERF_DAY") != "" else 241.0
	_grow(n)
	var all := WorldPlayers.size()
	var t := float(WorldPlayers.START_UNIX) + day * 86400.0 + 3600.0 * 20.0
	WorldPresence.clock_offset = t - WorldPlayers.now()
	print("maze_perf: %d players, day %.0f" % [all, day])

	# The keys: MazeWar's held slots (index * 100000 + slot) and WorldGear's reads (events
	# * 4096 + index) hold every index of the most the world can grow to.
	var most := WorldPlayers.ROSTER.size() + WorldPlayers.NEWCOMER_MAX
	check(most < 4096, "every world player fits WorldGear's read key (%d)" % most)
	check(all < 4096, "the test's world fits the keys too")

	# 1. Slots worked out a step at a time = the old one-go fights, on several days.
	var slots: Array[int] = []
	for d in [day * 0.25, day * 0.6, day - 1.0, day]:
		var at := float(WorldPlayers.START_UNIX) + float(int(d)) * 86400.0 + 3600.0 * 13.0
		slots.append(MazeWar.slot_of(at))
		slots.append(MazeWar.slot_of(at) + 1)
	slots.append(MazeWar.slot_of(t))
	# The game's tables a first stats read builds once (HeroStats, the classes: tens of
	# ms once a run, whatever the world's size) are built before the timing.
	_old_power(0, t)
	var worst := 0.0
	var fights := 0
	var people := 0
	var t_all := Time.get_ticks_usec()
	for k in slots:
		var r := _sliced(k, 1500)
		worst = maxf(worst, float(r.max))
		var got := MazeWar.slot_fights(k)
		var mid := MazeWar.slot_start(k) + MazeWar.SLOT * 0.5
		var inside := MazeWar.inside_at(mid)
		people += inside.size()
		var same_power := true
		for i in inside:
			same_power = same_power and MazeWar.power(i, mid) == _old_power(i, mid)
		check(same_power, "slot %d: every power is the old reading's" % k)
		var want := _old_slot_fights(k)
		fights += want.size()
		check(str(got) == str(want), "slot %d: the fights worked out a step at a time are the old ones (%d / %d)" % [k, got.size(), want.size()])
	print("  %d slots (%d in them, %d fights) a step at a time: longest step %.1f ms, all %.0f ms" % [slots.size(), people, fights, worst, _ms_since(t_all)])
	check(worst < STEP_MS, "no step of a slot takes long (%.1f ms)" % worst)
	check(fights > 0 and people > 20, "the slots are busy (%d in, %d fights)" % [people, fights])

	# 2. A cold week caught up by warm, a frame budget at a time; the paced board read
	# meanwhile is cheap and never ahead; caught up, it is the board worked out unpaced.
	MazeWar.reset()
	MazeWar.ai_mode = 1
	MazeWar.pace_mode = 1
	var week := MazeWar.week_of(t)
	var frames := 0
	var warm_most := 0.0
	var board_most := 0.0
	var ahead := false
	var seen := {}
	t_all = Time.get_ticks_usec()
	while true:
		var t0 := Time.get_ticks_usec()
		var done := MazeWar.warm(1500)
		warm_most = maxf(warm_most, _ms_since(t0))
		frames += 1
		if frames % 40 == 0 or done:
			t0 = Time.get_ticks_usec()
			var board := MazeWar.standings(week, t)
			board_most = maxf(board_most, _ms_since(t0))
			for r in board:
				ahead = ahead or int(r.kills) < int(seen.get(String(r.name), 0))
				seen[String(r.name)] = int(r.kills)
		if done or frames > 400000:
			break
	var paced := MazeWar.standings(week, t)
	print("  a cold week (%d slots) caught up in %d frames (%.0f ms): longest frame %.1f ms, longest paced board %.1f ms, %d on the board" % [MazeWar.slot_of(t) - MazeWar.slot_of(MazeWar.week_start(week)), frames, _ms_since(t_all), warm_most, board_most, paced.size()])
	check(frames <= 400000, "warm catches up")
	check(warm_most < STEP_MS, "no frame of warm takes long (%.1f ms)" % warm_most)
	check(board_most < STEP_MS, "the paced board is cheap while warm catches up (%.1f ms)" % board_most)
	check(not ahead, "the paced board only ever grows")
	check(not paced.is_empty(), "the week has a board")
	MazeWar.reset()
	MazeWar.ai_mode = 1
	MazeWar.pace_mode = 0
	var exact := MazeWar.standings(week, t)
	check(_board_key(paced) == _board_key(exact), "caught up, the paced board is the board worked out at once (%d / %d rows)" % [paced.size(), exact.size()])
	for name in seen:
		var row := exact.filter(func(r): return String(r.name) == String(name))
		check(not row.is_empty() and int(row[0].kills) >= int(seen[name]), "%s: the paced board never counted more than the board" % name)
		if failures > 20:
			break

	# 3. Forging run a stretch at a time = run in one go (events and states alike).
	var picks: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 241
	for k in 24:
		picks.append(rng.randi_range(0, all - 1))
	var whole := {}
	var states := {}
	WorldGear.clear()
	for i in picks:
		var w := WorldPlayers.work_at(i, t)
		WorldGear._sim(i, w)
		whole[i] = _events_key(i)
		states[i] = [str(WorldGear.state_at_work(i, w * 0.5)), str(WorldGear.state_at_work(i, w)), _gear_key(WorldGear.equip_at_work(i, w))]
	WorldGear.clear()
	var step_most := 0.0
	for i in picks:
		var w := WorldPlayers.work_at(i, t)
		while true:
			var t0 := Time.get_ticks_usec()
			var done := WorldGear.advance(i, w, t0)
			step_most = maxf(step_most, _ms_since(t0))
			if done:
				break
	for i in picks:
		var w := WorldPlayers.work_at(i, t)
		check(_events_key(i) == String(whole[i]), "player %d: the forging a stretch at a time is the forging in one go" % i)
		check(str(WorldGear.state_at_work(i, w * 0.5)) == String(states[i][0]) and str(WorldGear.state_at_work(i, w)) == String(states[i][1]), "player %d: the same states" % i)
		check(_gear_key(WorldGear.equip_at_work(i, w)) == String(states[i][2]), "player %d: the same gear worn" % i)
	print("  forging a stretch at a time: longest stretch %.2f ms" % step_most)
	check(step_most < STEP_MS, "a stretch of forging is short (%.2f ms)" % step_most)

	# 4. The next guild war's sides worked out ahead (GuildWarData.warm_sides, a frame
	# budget at a time): the round's line-ups are then quick, with the very powers a cold
	# world works out for them in one go.
	WorldGear.clear()
	var at := GuildLeague.next_slot(t)
	var side_most := 0.0
	var side_frames := 0
	while side_frames < 200000:
		var t0 := Time.get_ticks_usec()
		var done := GuildWarData.warm_sides(1000)
		side_most = maxf(side_most, _ms_since(t0))
		side_frames += 1
		if done:
			break
	var t1 := Time.get_ticks_usec()
	var war := GuildWarData.roll_guild_war(rng, GuildLeague.ids(), float(at), -1.0, false)
	var war_ms := _ms_since(t1)
	WorldGear.clear()
	t1 = Time.get_ticks_usec()
	var cold := GuildWarData.roll_guild_war(rng, GuildLeague.ids(), float(at), -1.0, false)
	var cold_ms := _ms_since(t1)
	var sides_of := func(info: Dictionary) -> String:
		var parts: PackedStringArray = []
		for sd in info.get("sides", []):
			var powers: PackedStringArray = []
			for f in sd.lineup:
				powers.append("%d:%.4f" % [int(f.world), float(f.power)])
			parts.append("%d=%s" % [int(sd.guild), ",".join(powers)])
		return ";".join(parts)
	print("  the next war's sides ahead: %d frames, longest %.1f ms; the war's line-ups then %.0f ms (cold %.0f ms)" % [side_frames, side_most, war_ms, cold_ms])
	check(not war.is_empty() and sides_of.call(war) == sides_of.call(cold), "the line-ups read after warm_sides are the cold ones")
	check(side_most < STEP_MS, "no frame of warm_sides takes long (%.1f ms)" % side_most)
	check(war_ms < cold_ms, "the line-ups are quicker once their gear is worked out ahead")

	MazeWar.pace_mode = -1
	MazeWar.ai_mode = -1
	MazeWar.reset()
	WorldPresence.clock_offset = 0.0
	print("maze_perf_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)
