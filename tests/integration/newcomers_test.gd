extends Node
## New players every day (WorldPlayers newcomers): from the opening on, 2-3 new players log
## in for the first time each Thai day, made from the date alone (the same names, classes,
## faces and guilds on every device, worked out again from scratch), every name its own,
## the classes and the guilds spread evenly; each starts at Lv.1 on its day and levels at
## a hardcore player's pace from then on, joining its guild at Lv.100. The world chat
## welcomes each once (rate-limited). Every player with a play schedule is hardcore and
## they take turns resting: at any hour a good share of them is on, never all. The guild
## war fields each guild's best GUILD_SIDE (the hero counted on ours). Timings printed.
##   godot --headless --path . res://tests/integration/newcomers_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0
const DAYS := 40


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	var started := Time.get_ticks_msec()
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	_daily()
	_pace()
	_welcome()
	_hardcore()
	_staggered()
	_guild_war()
	_perf()
	print("NEWCOMERS: %s | %d checks, %d failures (%d ms)" % ["PASS" if failures == 0 else "FAIL", checks, failures, Time.get_ticks_msec() - started])
	get_tree().quit(0 if failures == 0 else 1)


func _start() -> float:
	return float(WorldPlayers.START_UNIX)


## The newcomers made up to DAYS days after the opening, as plain rows.
func _made() -> Array:
	WorldPlayers.ensure_until(_start() + float(DAYS) * DAY)
	var out := []
	for i in range(WorldPlayers.ROSTER.size(), WorldPlayers._all.size()):
		var e := WorldPlayers.entry(i)
		if int(e.day) > DAYS:
			continue
		out.append([String(e.name), String(e["class"]), int(e.gender), int(e.guild), float(e.join), int(e.day), WorldPlayers.look(i)])
	return out


func _daily() -> void:
	var first := _made()
	# Worked out again from nothing (another device, another day): the same people.
	WorldPlayers.reset_roster()
	check(WorldPlayers._all.is_empty() or WorldPlayers._all.size() == WorldPlayers.ROSTER.size(), "the roster starts over from the hand-made players")
	var again := _made()
	check(first == again, "the same newcomers come out again (%d and %d)" % [first.size(), again.size()])
	var per_day := {}
	var names := {}
	var classes := {}
	var guilds := {}
	for e in WorldPlayers.ROSTER:
		names[String(e.name)] = true
	var dup := 0
	var within := true
	for row in first:
		per_day[int(row[5])] = int(per_day.get(int(row[5]), 0)) + 1
		dup += 1 if names.has(String(row[0])) else 0
		names[String(row[0])] = true
		classes[String(row[1])] = int(classes.get(String(row[1]), 0)) + 1
		guilds[int(row[3])] = int(guilds.get(int(row[3]), 0)) + 1
		var at := _start() + float(row[4]) * DAY
		var thai_day := int(floor((at + WorldPlayers.TZ) / DAY)) - WorldPlayers._first_day()
		within = within and at > _start() and thai_day == int(row[5]) and String(row[0]).length() >= 2 and String(row[0]).length() <= 16
	var counts_ok := true
	for d in DAYS + 1:
		var n := int(per_day.get(d, 0))
		counts_ok = counts_ok and n >= WorldPlayers.NEWCOMERS.x and n <= WorldPlayers.NEWCOMERS.y
	check(counts_ok, "2-3 newcomers every day (%s)" % [per_day.values()])
	check(first.size() >= 2 * (DAYS + 1) and first.size() <= 3 * (DAYS + 1), "%d newcomers in %d days" % [first.size(), DAYS + 1])
	check(dup == 0, "no newcomer has a name already taken (%d)" % dup)
	check(within, "each logs in on its own Thai day, after the opening, under a sensible name")
	var lo := 999
	var hi := 0
	for c in classes:
		lo = mini(lo, int(classes[c]))
		hi = maxi(hi, int(classes[c]))
	check(classes.size() == ClassData.IDS.size() and hi - lo <= 2, "every class among them, evenly (%s)" % [classes])
	check(absi(int(guilds.get(WorldPlayers.ALPHA, 0)) - int(guilds.get(WorldPlayers.NEVERDIE, 0))) <= 1 and guilds.size() == 2, "they join Alpha and Neverdie by turns (%s)" % [guilds])
	var looks_ok := true
	for i in range(WorldPlayers.ROSTER.size(), WorldPlayers._all.size()):
		looks_ok = looks_ok and int(WorldPlayers.look(i).gender) == int(WorldPlayers.entry(i).gender) and WorldPlayers.is_newcomer(i)
		looks_ok = looks_ok and WorldPlayers.index_of(String(WorldPlayers.entry(i).name)) == i
	check(looks_ok, "each has a face of its gender, found by its name")
	var samples := []
	for row in first.slice(0, 6):
		samples.append("%s (%s, %s)" % [row[0], row[1], WorldPlayers.guild_name(int(row[3]))])
	print("first newcomers: %s" % ", ".join(samples))
	# Growth stops at NEWCOMER_MAX.
	WorldPlayers.ensure_until(_start() + 400.0 * DAY)
	check(WorldPlayers._all.size() == WorldPlayers.ROSTER.size() + WorldPlayers.NEWCOMER_MAX, "no more than %d newcomers in all (%d players)" % [WorldPlayers.NEWCOMER_MAX, WorldPlayers._all.size()])
	var last := WorldPlayers.entry(WorldPlayers._all.size() - 1)
	print("newcomer %d comes on day %d" % [WorldPlayers.NEWCOMER_MAX, int(last.day)])


## Lv.1 on the day it joins, then a hardcore player's pace: no ★200 in four days, ★200
## within eight, ★300 with the divine set within sixteen; in its guild from Lv.100.
func _pace() -> void:
	var start := _start()
	var tested := 0
	for i in range(WorldPlayers.ROSTER.size(), WorldPlayers._all.size(), 7):
		var e := WorldPlayers.entry(i)
		if int(e.day) < 8 or int(e.day) > DAYS:
			continue
		tested += 1
		var j := WorldPlayers.joined_at(i)
		var before := WorldPlayers.state(i, j - 60.0)
		check(int(before.level) == 1 and not bool(before.online) and int(before.guild) == 0, "%s: not in the world before its day" % e.name)
		var at_join := WorldPlayers.state(i, j)
		var first := WorldPlayers.state(i, j + 300.0)
		check(int(at_join.level) == 1 and int(at_join.stars) == 0, "%s: Lv.1 when it logs in (Lv.%d)" % [e.name, int(at_join.level)])
		check(int(first.level) < ClassData.LINE_LEVEL and String(first["class"]) == String(ClassData.START), "%s: a Lv.%d Vagabond on its first minutes" % [e.name, int(first.level)])
		check(String(e.style) == "hardcore", "%s plays hardcore" % e.name)
		var d4 := WorldPlayers.state(i, j + 4.0 * DAY)
		var d8 := WorldPlayers.state(i, j + 8.0 * DAY)
		var d16 := WorldPlayers.state(i, j + 16.0 * DAY)
		check(int(d4.stars) < 200, "%s: not at ★200 in four days (%s)" % [e.name, WorldPlayers.level_text(d4)])
		check(int(d8.level) == 100 and int(d8.stars) >= 200, "%s: ★200 within eight days (%s)" % [e.name, WorldPlayers.level_text(d8)])
		check(int(d16.stars) == Game.PARAGON_MAX and bool(d16.divine), "%s: ★300 with the divine set within sixteen days (%s)" % [e.name, WorldPlayers.level_text(d16)])
		check(int(d8.guild) == int(e.guild) and int(first.guild) == 0, "%s: in %s from Lv.100" % [e.name, WorldPlayers.guild_name(int(e.guild))])
		var steady := true
		var last := 0
		var t := j
		while t < j + 10.0 * DAY:
			var p := WorldPlayers.progress_at(i, t)
			var point := int(p.level) + int(p.stars)
			steady = steady and point >= last
			last = point
			t += 0.37 * DAY
		check(steady, "%s: only ever goes up" % e.name)
	check(tested >= 8, "newcomers checked for pace (%d)" % tested)
	check(start > 0.0, "the opening is set")


## The world chat welcomes a newcomer once, the first time this game sees it log in, at
## most one welcome every WELCOME_GAP seconds.
func _welcome() -> void:
	var lines: Array[String] = []
	var listen := func(_speaker: String, text: String, _color: Color) -> void:
		if text.begins_with("ผู้เล่นใหม่"):
			lines.append(text)
	Game.world_chat.connect(listen)
	var a := -1
	for i in range(WorldPlayers.ROSTER.size(), WorldPlayers._all.size()):
		if int(WorldPlayers.entry(i).day) == 12:
			a = i
			break
	check(a >= 0, "a newcomer of day 12")
	if a < 0:
		return
	var b := a + 1
	var presence := WorldPresence.new()
	add_child(presence)
	var j := WorldPlayers.joined_at(a)
	# Seen before it joins, then after: welcomed once.
	presence._announce(WorldPlayers.state(a, j - 30.0), j - 30.0)
	presence._flush_welcome(j - 30.0)
	check(lines.is_empty(), "no welcome before it joins")
	presence._announce(WorldPlayers.state(a, j + 30.0), j + 30.0)
	# The next newcomer, seen for the first time a little after it joined: welcomed too.
	var jb := WorldPlayers.joined_at(b)
	presence._announce(WorldPlayers.state(b, jb + 600.0), jb + 600.0)
	presence._flush_welcome(jb + 600.0)
	check(lines.size() == 1 and lines[0] == "ผู้เล่นใหม่ %s เข้าเกมแล้ว ยินดีต้อนรับ!" % WorldPlayers.entry(a).name, "the world chat welcomes the newcomer (%s)" % [lines])
	presence._flush_welcome(jb + 605.0)
	check(lines.size() == 1, "one welcome at a time")
	presence._flush_welcome(jb + 600.0 + WorldPresence.WELCOME_GAP)
	check(lines.size() == 2 and String(WorldPlayers.entry(b).name) in lines[1], "the next welcome after a pause (%s)" % [lines])
	for k in 3:
		var t := jb + 3600.0 + float(k) * 100.0
		presence._announce(WorldPlayers.state(a, t), t)
		presence._announce(WorldPlayers.state(b, t), t)
		presence._flush_welcome(t)
		WorldPresence.welcome(String(WorldPlayers.entry(a).name))
	check(lines.size() == 2, "each is welcomed only once (%d lines)" % lines.size())
	# An old newcomer seen for the first time long after it joined: no welcome.
	var old := WorldPlayers.ROSTER.size()
	var t_old := WorldPlayers.joined_at(old) + 3.0 * DAY
	presence._announce(WorldPlayers.state(old, t_old), t_old)
	presence._flush_welcome(t_old + 1000.0)
	check(lines.size() == 2, "a player who joined days ago is not welcomed again")
	Game.world_chat.disconnect(listen)
	presence.queue_free()


## Every hand-made player but the stall keepers plays hardcore; the stall keepers stay.
func _hardcore() -> void:
	var keepers := 0
	var all_hard := true
	for i in WorldPlayers.ROSTER.size():
		if WorldPlayers.in_town_style(i):
			keepers += 1
		elif String(WorldPlayers.entry(i).style) != "hardcore":
			all_hard = false
			printerr("not hardcore: %s" % WorldPlayers.entry(i).name)
	check(all_hard, "every scheduled player is hardcore")
	check(keepers >= JapanVillage.STALLS.size() / 2 and keepers <= 16, "a small set of stall keepers keeps the village market (%d)" % keepers)


## They take turns resting: at every sampled hour between about 40% and 85% of the hunters
## who have joined are online, never all; the Thai evening is busier than midday.
func _staggered() -> void:
	var start := _start() + 3.0 * DAY
	var by_hour := {}
	var low := 1.0
	var low_at := ""
	var high := 0.0
	var t := start
	while t < start + 6.0 * DAY:
		var on := 0
		var hunters := 0
		for i in WorldPlayers._all.size():
			if WorldPlayers.in_town_style(i) or t < WorldPlayers.joined_at(i):
				continue
			hunters += 1
			on += 0 if WorldPlayers.session_at(i, t).is_empty() else 1
		var share := float(on) / float(maxi(1, hunters))
		if share < low:
			low_at = "day %.2f world %.1fh (%d of %d)" % [(t - _start()) / DAY, fposmod((WorldPlayers.world_time(t) + WorldPlayers.TZ) / 3600.0, 24.0), on, hunters]
		low = minf(low, share)
		high = maxf(high, share)
		var w := WorldPlayers.world_time(t)
		var hour := int(fposmod((w + WorldPlayers.TZ) / 3600.0, 24.0))
		var cell: Array = by_hour.get(hour, [0.0, 0])
		by_hour[hour] = [float(cell[0]) + share, int(cell[1]) + 1]
		t += 1500.0
	check(low >= 0.36 and high <= 0.88 and high < 1.0, "a good share is online at every hour, never all (%.0f%%-%.0f%%, the fewest at %s)" % [low * 100.0, high * 100.0, low_at])
	var evening := 0.0
	var midday := 0.0
	for h in [20, 21, 22]:
		evening += float(by_hour[h][0]) / float(by_hour[h][1]) / 3.0
	for h in [11, 12, 13]:
		midday += float(by_hour[h][0]) / float(by_hour[h][1]) / 3.0
	check(evening > midday + 0.1, "the Thai evening is busier than midday (%.0f%% vs %.0f%%)" % [evening * 100.0, midday * 100.0])
	var line: PackedStringArray = []
	for h in 24:
		line.append("%02d:%.0f%%" % [h, float(by_hour[h][0]) / float(by_hour[h][1]) * 100.0])
	print("online share by world hour: %s (every sample %.0f%%-%.0f%%)" % [" ".join(line), low * 100.0, high * 100.0])
	for d: float in [8.0, 30.0]:
		var at := _start() + d * DAY + 13.0 * 3600.0
		var joined := 0
		for i in WorldPlayers._all.size():
			joined += 1 if at >= WorldPlayers.joined_at(i) else 0
		print("day %d: %d players in the world, %d online" % [int(d), joined, WorldPresence.online_count(at)])


## Each guild fields its best GUILD_SIDE (the hero counted on ours): nobody left out is
## further along (WorldPlayers.rank_point) than the last picked, and the picked are the
## stronger ones by power too.
func _guild_war() -> void:
	var t := _start() + 30.0 * DAY + 5.0 * 3600.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var t0 := Time.get_ticks_usec()
	var m := GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, t, 1000.0)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	check(not m.is_empty(), "a war on day 30")
	if m.is_empty():
		return
	var ours := WorldPlayers.members_at(WorldPlayers.ALPHA, t)
	var theirs := WorldPlayers.members_at(WorldPlayers.NEVERDIE, t)
	print("day 30: Alpha %d and Neverdie %d members at Lv.100; a war rolled in %.0f ms" % [ours.size(), theirs.size(), ms])
	check(m.ally.size() == GuildWarData.GUILD_SIDE - 1 and m.enemy.size() == GuildWarData.GUILD_SIDE, "full sides: %d with the hero against %d" % [m.ally.size() + 1, m.enemy.size()])
	for side in [[m.ally, ours, "Alpha"], [m.enemy, theirs, "Neverdie"]]:
		var picked := {}
		var last := INF
		var power_in := 0.0
		for f in side[0]:
			picked[int(f.world)] = true
			last = minf(last, WorldPlayers.rank_point(int(f.world), t))
			power_in += float(f.power) / float(side[0].size())
		var further_left := 0
		var power_out := 0.0
		var left_out := 0
		for i in side[1]:
			if picked.has(i):
				continue
			further_left += 1 if WorldPlayers.rank_point(i, t) > last else 0
			power_out += float(WorldPlayers.fighter(i, t).power)
			left_out += 1
		power_out /= float(maxi(1, left_out))
		check(further_left == 0, "%s fields its best (%d further along left out)" % [side[2], further_left])
		check(left_out == 0 or power_in >= power_out, "%s: those picked are stronger on average (%.0f vs %.0f)" % [side[2], power_in, power_out])
		var online_first := true
		var seen_off := false
		for f in side[0]:
			online_first = online_first and not (bool(f.online) and seen_off)
			seen_off = seen_off or not bool(f.online)
		check(online_first, "%s's line-up lists the online first" % side[2])


## What a world of a few hundred costs: a whole read of everyone (WorldPresence reads the
## online ones a few a frame).
func _perf() -> void:
	for d: float in [30.0, 130.0]:
		var t := _start() + d * DAY + 20.0 * 3600.0
		var n := 0
		for i in WorldPlayers._all.size():
			n += 1 if t >= WorldPlayers.joined_at(i) else 0
		for i in n:
			WorldPlayers.state(i, t)
		var t0 := Time.get_ticks_usec()
		var on := 0
		for i in n:
			if not WorldPlayers.session_at(i, t + 12.0).is_empty():
				on += 1
				WorldPlayers.state(i, t + 12.0)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		print("day %d: %d players, %d online; a sync's reads %.1f ms (%.0f us a player online)" % [int(d), n, on, ms, ms * 1000.0 / float(maxi(1, on))])
		check(on > 0 and on < n, "day %d: some online, not all" % int(d))
