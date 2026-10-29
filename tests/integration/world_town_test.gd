extends Node
## The world is never empty: at any moment of the day (every 10 real minutes over two real
## weeks after the opening, and again a month on) at least MIN_TOWN stall keepers are in
## the village and enough are online; the players with a play schedule are never in the
## village while online (they level in a field, or play the endgame), only stall keepers
## stand there (doing "stall"); the world's clock runs WorldPlayers.SPEED times
## faster than real time; everyone starts at Lv.1 at the opening, newcomers
## arrive on their day; the guild war fields everyone at Lv.100, up to GUILD_SIDE a side.
##   godot --headless --path . res://tests/integration/world_town_test.tscn
## Stall keepers in the village at every moment (the village has JapanVillage.STALLS stalls).
const MIN_TOWN := 16
const MIN_ONLINE := 22

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.clear_bonus()
	var started := Time.get_ticks_msec()
	_clock()
	for from_day in [0.0, 30.0]:
		_busy(from_day, 14.0)
	_veterans()
	_newcomers()
	_guild_war()
	print("WORLD TOWN: %s | %d checks, %d failures (%d ms)" % ["PASS" if failures == 0 else "FAIL", checks, failures, Time.get_ticks_msec() - started])
	get_tree().quit(0 if failures == 0 else 1)


func _clock() -> void:
	var start := float(WorldPlayers.START_UNIX)
	check(is_equal_approx(WorldPlayers.world_time(start + 3600.0), start + 3600.0 * WorldPlayers.SPEED), "an hour of real time is SPEED hours on the world's clock")
	check(is_equal_approx(WorldPlayers.real_time(WorldPlayers.world_time(start + 12345.0)), start + 12345.0), "world and real time convert both ways")
	# The pace of levelling is a real player's: hours played a real week stay sensible.
	for i in WorldPlayers.size():
		var week := WorldPlayers.played_minutes(i, start + 28.0 * 86400.0) / 60.0 / 4.0
		var e := WorldPlayers.entry(i)
		var top := 170.0 if WorldPlayers.in_town_style(i) else 70.0
		check(week >= (0.0 if e.has("join") else 4.0) and week < top, "%s (%s): plays %.0f real hours a week" % [e.name, e.style, week])


func _busy(from_day: float, days: float) -> void:
	var start := float(WorldPlayers.START_UNIX) + from_day * 86400.0
	var low_town := 999
	var low_online := 999
	var low_at := 0.0
	var sum_town := 0.0
	var samples := 0
	var scheduled_in_town := 0
	var t := start
	while t < start + days * 86400.0:
		var town := 0
		var online := 0
		for i in WorldPlayers.size():
			var sess := WorldPlayers.session_at(i, t)
			if sess.is_empty():
				continue
			online += 1
			var in_town := WorldPlayers.town_time(i, float(sess[0]), float(sess[1]), t)
			if in_town:
				town += 1
			if in_town != WorldPlayers.in_town_style(i):
				scheduled_in_town += 1
		if town < low_town:
			low_town = town
			low_at = t
		low_online = mini(low_online, online)
		sum_town += town
		samples += 1
		t += 600.0
	var hour := fposmod((WorldPlayers.world_time(low_at) + WorldPlayers.TZ) / 3600.0, 24.0)
	print("day %d+: village at least %d (world %.1f h), on average %.1f; online at least %d" % [int(from_day), low_town, hour, sum_town / samples, low_online])
	check(low_town >= MIN_TOWN, "day %d+: at least %d stall keepers in the village at every moment (%d)" % [int(from_day), MIN_TOWN, low_town])
	check(low_online >= MIN_ONLINE, "day %d+: at least %d players online at every moment (%d)" % [int(from_day), MIN_ONLINE, low_online])
	check(scheduled_in_town == 0, "day %d+: no player with a play schedule spends its session in the village (%d moments)" % [int(from_day), scheduled_in_town])
	# Where everyone is, every two real hours: online scheduled players are out in a field
	# (or the endgame), and whoever is in the village keeps a stall.
	var wrong: Array[String] = []
	var stalls_full := 0
	t = start
	while t < start + days * 86400.0:
		var keepers := 0
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if not bool(s.online):
				continue
			var in_town := String(s.place) == "town"
			if in_town != (String(s.doing) == "stall"):
				wrong.append("%s %s/%s" % [s.name, s.place, s.doing])
			if not WorldPlayers.in_town_style(i) and in_town and not bool(s.divine):
				wrong.append("%s (%s) in the village" % [s.name, s.style])
			if WorldPlayers.in_town_style(i) and not in_town:
				wrong.append("%s (stall keeper) away from the village" % s.name)
			keepers += 1 if in_town else 0
		stalls_full += 1 if keepers >= JapanVillage.STALLS.size() else 0
		t += 7200.0
	check(wrong.is_empty(), "day %d+: only stall keepers are in the village, scheduled players level (%s)" % [int(from_day), wrong.slice(0, 6)])
	print("day %d+: the village's %d stalls full at %d of %d checks" % [int(from_day), JapanVillage.STALLS.size(), stalls_full, int(days * 12.0)])


func _veterans() -> void:
	var start := float(WorldPlayers.START_UNIX)
	# A fresh opening: nobody brings a head start, everyone begins at Lv.1.
	var ahead: Array[String] = []
	for i in WorldPlayers.size():
		if WorldPlayers.head_work(i) != 0.0 or int(WorldPlayers.state(i, start + 60.0).level) > 3:
			ahead.append("%s Lv.%d" % [WorldPlayers.entry(i).name, int(WorldPlayers.state(i, start + 60.0).level)])
	check(ahead.is_empty(), "when the world opens everyone starts at Lv.1 (%s)" % [ahead])
	# The endgame: a player who completed the divine set enhances it as it plays and
	# spends sessions on boss hunts, helping in the star fields and keeping a stall.
	# The first hardcore player to complete the divine set, from the day it does.
	var who := -1
	var t0 := start
	for d in range(10, 120):
		t0 = start + float(d) * 86400.0
		for i in WorldPlayers.size():
			if String(WorldPlayers.entry(i).style) == "hardcore" and bool(WorldPlayers.state(i, t0).divine):
				who = i
				break
		if who >= 0:
			break
	check(who >= 0, "a hardcore player completes the divine set")
	if who < 0:
		return
	var plus_then := WorldPlayers.divine_plus(WorldPlayers.member(who, t0))
	var plus_later := WorldPlayers.divine_plus(WorldPlayers.member(who, t0 + 20.0 * 86400.0))
	check(plus_later > plus_then and plus_later <= 10, "the divine set is enhanced with play (+%d -> +%d)" % [plus_then, plus_later])
	var kinds := {}
	var t := t0
	while t < t0 + 14.0 * 86400.0:
		var s := WorldPlayers.state(who, t)
		if bool(s.online):
			kinds[String(s.doing)] = true
			check(String(s.place) != "" and (String(s.place) == "town" or ZoneData.access_reason(StringName(s.place), int(s.level), int(s.stars)) == ""), "a divine player goes where it may (%s)" % s.place)
		t += 900.0
	check(kinds.has("boss") and kinds.has("help") and kinds.has("stall"), "a divine player hunts bosses, helps and keeps a stall (%s)" % [kinds.keys()])


func _newcomers() -> void:
	for i in WorldPlayers.size():
		var e := WorldPlayers.entry(i)
		if not e.has("join"):
			continue
		var at := WorldPlayers.joined_at(i)
		var before := WorldPlayers.state(i, at - 60.0)
		check(not bool(before.online) and int(before.level) == 1 and WorldPlayers.played_minutes(i, at - 60.0) == 0.0, "%s: not in the world before its day" % e.name)
		check(WorldPlayers.where_text(before, at - 60.0) != "", "%s: the registry says it has not come yet" % e.name)
		var later := WorldPlayers.state(i, at + 7.0 * 86400.0)
		check(int(later.level) > 1, "%s: levels up after joining (Lv.%d)" % [e.name, int(later.level)])


func _guild_war() -> void:
	Game.new_profile(&"warrior", "Town")
	Game.profile["level"] = 100
	Game.join_guild(WorldPlayers.ALPHA)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := float(WorldPlayers.START_UNIX) + 0.4 * 86400.0
	check(GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, t).is_empty(), "a fresh world has no guild war on the first day")
	t = float(WorldPlayers.START_UNIX) + 20.0 * 86400.0
	var match := GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, t)
	check(not match.is_empty(), "a guild war three weeks on")
	if match.is_empty():
		return
	var ours_100 := WorldPlayers.members_at(WorldPlayers.ALPHA, t).size()
	var theirs_100 := WorldPlayers.members_at(WorldPlayers.NEVERDIE, t).size()
	check(match.ally.size() == mini(GuildWarData.GUILD_SIDE - 1, ours_100) and match.enemy.size() == mini(GuildWarData.GUILD_SIDE, theirs_100), "everyone at Lv.100 fights, up to GUILD_SIDE a side (%d + hero, %d)" % [match.ally.size(), match.enemy.size()])
	# A full guild later on sends GUILD_SIDE.
	var later := GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, float(WorldPlayers.START_UNIX) + 60.0 * 86400.0)
	check(later.ally.size() == GuildWarData.GUILD_SIDE - 1 and later.enemy.size() == GuildWarData.GUILD_SIDE, "a full guild: %d with the hero against %d" % [later.ally.size() + 1, later.enemy.size()])
	# The hero's picks always come along, even past the cap.
	var last := WorldPlayers.members_at(WorldPlayers.ALPHA, t)
	var weakest := ""
	var low := INF
	for i in last:
		var f := WorldPlayers.fighter(i, t)
		if float(f.power) < low:
			low = float(f.power)
			weakest = String(f.member.name)
	Game.guildwar_party_picks = PackedStringArray([weakest])
	var again := GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, t)
	check(again.ally.any(func(f): return String(f.member.name) == weakest), "a picked teammate is always in the line-up (%s)" % weakest)
	Game.guildwar_party_picks = PackedStringArray()
