extends Node
## What a bigger world costs a phone: the world of the ROSTER and N newcomers (made as
## WorldPlayers makes them, past NEWCOMER_MAX) read the ways the game reads it (every
## state, the online count, a sync's reads, the registry, guild war line-ups, the league,
## the maze, the world parties), timed, on the day the last of them joined. Picks
## WorldPlayers.NEWCOMER_MAX. WORLD_BENCH_N: the newcomer counts, comma separated
## (default 600,1500,3000).
##   godot --headless --path . res://tools/world_scale_bench.tscn


func _ms(c: Callable) -> float:
	var t0 := Time.get_ticks_usec()
	c.call()
	return float(Time.get_ticks_usec() - t0) / 1000.0


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


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	var counts: Array[int] = [600, 1500, 3000]
	if OS.get_environment("WORLD_BENCH_N") != "":
		counts.clear()
		for part in OS.get_environment("WORLD_BENCH_N").split(","):
			counts.append(int(part))
	for n: int in counts:
		_grow(n)
		var days := float(WorldPlayers._gen_day)
		var last_join := 0.0
		for i in WorldPlayers._all.size():
			last_join = maxf(last_join, WorldPlayers.joined_at(i))
		var t := last_join + 3600.0 * 20.0
		if OS.get_environment("WORLD_BENCH_DAY") != "":
			t = float(WorldPlayers.START_UNIX) + float(OS.get_environment("WORLD_BENCH_DAY")) * 86400.0 + 3600.0 * 20.0
		WorldPresence.clock_offset = t - WorldPlayers.now()
		var all := WorldPlayers._all.size()
		var out := "N=%d (+%d newcomers, last joins day %.0f, read on day %.0f):" % [all, n, (last_join - WorldPlayers.START_UNIX) / 86400.0, (t - WorldPlayers.START_UNIX) / 86400.0]
		# The first read of everyone, part by part: the minutes played (each player's days
		# summed once), the sessions, the maze's Lv.MIN_LEVEL moment, the rest of state.
		var cold_min := _ms(func():
			for i in all:
				WorldPlayers.played_minutes(i, t))
		var cold_prog := _ms(func():
			for i in all:
				WorldPlayers.progress_at(i, t))
		var cold_maze := _ms(func():
			for i in all:
				MazeWar.ready_at(i, t))
		out += " cold: minutes %.0f, progress %.0f, maze ready %.0f ms;" % [cold_min, cold_prog, cold_maze]
		var cold := _ms(func():
			for i in all:
				WorldPlayers.state(i, t))
		out += " state cold %.0f ms;" % cold
		var warm := _ms(func():
			for i in all:
				WorldPlayers.state(i, t + 12.0))
		out += " state all (+12s) %.1f ms (%.0f us each);" % [warm, warm * 1000.0 / all]
		var online := [0]
		var sess := _ms(func():
			online[0] = WorldPresence.online_count(t + 30.0))
		out += " online_count %.2f ms (%d on);" % [sess, online[0]]
		var reads := _ms(func():
			for i in all:
				if not WorldPlayers.session_at(i, t + 40.0).is_empty():
					WorldPlayers.state(i, t + 40.0))
		out += " sync reads (online states) %.1f ms;" % reads
		var prog := _ms(func():
			for i in all:
				WorldPlayers.rank_point(i, t + 50.0))
		out += " rank_point all %.1f ms;" % prog
		var size_ms := _ms(func():
			for k in 1000:
				WorldPlayers.size())
		out += " size() x1000 %.2f ms;" % size_ms
		var reg := _ms(func(): RegistryScreen.rows(t + 60.0))
		var reg2 := _ms(func(): RegistryScreen.rows(t + 60.0))
		out += " registry rows %.1f / again %.1f ms;" % [reg, reg2]
		var mem := _ms(func(): WorldPlayers.members_at(WorldPlayers.ALPHA, t + 70.0))
		out += " members_at %.1f ms;" % mem
		print(out)
		out = "   N=%d:" % all
		var heavy := OS.get_environment("WORLD_BENCH_HEAVY") != ""
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var best := _ms(func(): GuildWarData.best_members(WorldPlayers.ALPHA, t + 80.0, GuildWarData.GUILD_SIDE))
		out += " war line-up (best_members) %.1f ms;" % best
		if heavy:
			var war := _ms(func(): GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, t + 80.0, 1000.0, false))
			out += " war roll %.1f ms;" % war
		var at := GuildLeague.next_slot(t + 90.0)
		var lg := _ms(func(): GuildLeague.side_power(WorldPlayers.TITAN, at)) if heavy else 0.0
		var weeks := GuildLeague.week_of(t) - GuildLeague.week_of(float(GuildLeague.LEAGUE_START)) + 1
		out += " league side_power %.1f ms (the castle's chain from the first week: %d weeks x 4 guilds, about %.1f s cold);" % [lg, weeks, lg * weeks * 4.0 / 1000.0]
		if heavy and lg * weeks * 4.0 < 120000.0:
			var w := GuildLeague.week_of(t)
			var tab := _ms(func(): GuildLeague.table(w, [], t))
			var tab2 := _ms(func(): GuildLeague.table(w, [], t + 5.0))
			out += " league table cold %.0f / again %.1f ms;" % [tab, tab2]
		MazeWar._cands_n = -1
		var cands := _ms(func(): MazeWar.candidates())
		var inside := _ms(func(): MazeWar.inside_at(t + 100.0))
		var k0 := MazeWar.slot_of(t + 200.0)
		var fights := _ms(func(): MazeWar.slot_fights(k0))
		var fights2 := _ms(func(): MazeWar.slot_fights(k0 + 1))
		out += " maze candidates %.1f, inside_at %.1f, slot_fights %.1f / next %.1f ms;" % [cands, inside, fights, fights2]
		var parties := _ms(func(): WorldParties.parties_at(t + 300.0))
		out += " parties_at %.1f ms;" % parties
		var hunt := _ms(func(): IsleLuck.hunters_at(t + 310.0))
		out += " isle hunters_at %.1f ms" % hunt
		print(out)
	get_tree().quit(0)
