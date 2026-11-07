extends Node
## The four-guild league (GuildLeague, WorldPlayers, GuildWarData): Alpha, Neverdie, Titan
## and 3DLnw; everyone picks a guild of its own and each guild has at least twenty who
## reach Lv.100; three rounds a day at 12:00, 18:00 and 21:30 Thai, two wars a round, all
## six pairs every day; registration closes five minutes before a round; the hero fights
## only among its guild's strongest twenty; wars the hero does not fight get a seeded
## result from real power (the same after everything is worked out again); the hero's live
## result takes its war's place; old saves leave their guild once; the save stays valid;
## the table and the champion have the four guilds only; the desk shows the schedule.
##   godot --headless --path . res://tests/integration/guild_league4_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0


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
	_guilds()
	_schedule()
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * DAY)
	_seeded(w)
	_registration(w)
	_line_up(w)
	_live_result(w)
	_table(w)
	_migration()
	_validation()
	await _desk(w)
	WorldPresence.clock_offset = 0.0
	print("GUILD LEAGUE 4: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## A hero at Lv.100 with `stars`; at ★300 it also wears the whole divine set at +10, as
## far as anyone can be (it then always ranks among its guild's strongest).
func _hero(g := WorldPlayers.ALPHA, stars := 0) -> void:
	Game.new_profile(&"warrior", "League4 QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.paragon()["level"] = stars
	if stars >= Game.PARAGON_MAX:
		max_out()
	if g > 0:
		Game.join_guild(g)


static func max_out() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for slot in DivineGearData.SLOTS:
		var item := DivineGearData.item(Game.class_id(), slot, rng)
		item["plus"] = 10
		Game.profile.equip[slot] = item


func _guilds() -> void:
	check(WorldPlayers.GUILDS == [1, 2, 3, 4] and WorldPlayers.GUILD_NAMES.size() == 4, "four guilds")
	check(WorldPlayers.guild_name(WorldPlayers.TITAN) == "Titan" and WorldPlayers.guild_name(WorldPlayers.LNW) == "3DLnw", "Titan and 3DLnw")
	var colors := {}
	for g in WorldPlayers.GUILDS:
		colors[WorldPlayers.GUILD_COLORS[g].to_html()] = true
	check(colors.size() == 4, "each guild has its own colour")
	# Everyone's pick is its own (by name), the same when the world is worked out again.
	var picks := []
	for i in WorldPlayers.ROSTER.size():
		picks.append(int(WorldPlayers.entry(i).guild))
	WorldPlayers.reset_roster()
	var again := []
	for i in WorldPlayers.ROSTER.size():
		again.append(int(WorldPlayers.entry(i).guild))
	check(picks == again and not picks.has(0), "every roster player picked one of the four, the same every time")
	# Twenty or more who reach Lv.100 in each, three weeks after the opening.
	var t := float(WorldPlayers.START_UNIX) + 21.0 * DAY
	WorldPlayers.ensure_until(t)
	var sizes := {}
	for g in WorldPlayers.GUILDS:
		sizes[g] = WorldPlayers.members_at(g, t).size()
		check(int(sizes[g]) >= GuildWarData.GUILD_SIDE, "%s has %d at Lv.100 by day 21" % [WorldPlayers.guild_name(g), int(sizes[g])])
	# The roster alone (newcomers aside) gives each guild twenty hardcore players.
	var hardcore := {}
	for i in WorldPlayers.ROSTER.size():
		if String(WorldPlayers.entry(i).style) == "hardcore":
			var g := int(WorldPlayers.entry(i).guild)
			hardcore[g] = int(hardcore.get(g, 0)) + 1
	for g in WorldPlayers.GUILDS:
		check(int(hardcore.get(g, 0)) >= WorldPlayers.GUILD_MIN, "%s draws %d hardcore roster players" % [WorldPlayers.guild_name(g), int(hardcore.get(g, 0))])
	# Newcomers pick by name too.
	var ok := true
	for i in range(WorldPlayers.ROSTER.size(), WorldPlayers.size()):
		ok = ok and int(WorldPlayers.entry(i).guild) == WorldPlayers.pick_guild(String(WorldPlayers.entry(i).name))
	check(ok and WorldPlayers.size() > WorldPlayers.ROSTER.size(), "daily newcomers pick one of the four by name")
	check(GuildWarData.GUILD_SIDE == 20, "twenty a side")


func _schedule() -> void:
	var first := WorldEvents.day_of(float(WorldPlayers.START_UNIX))
	for d in range(first, first + 10):
		var pairs := {}
		var rounds := GuildLeague.rounds_on(d)
		check(rounds.size() == 3, "three rounds on day %d" % d)
		var times: Array = rounds.map(func(r): return GuildLeague.clock_text(int(r.at)))
		check(times == ["12:00", "18:00", "21:30"], "rounds at 12:00, 18:00, 21:30 Thai (%s)" % [times])
		for r in rounds:
			check(WorldEvents.day_of(float(r.at)) == d, "a round is on its own Thai day")
			var in_round := {}
			for p in r.pairs:
				pairs["%d-%d" % [mini(int(p[0]), int(p[1])), maxi(int(p[0]), int(p[1]))]] = true
				in_round[int(p[0])] = true
				in_round[int(p[1])] = true
			check(in_round.size() == 4 and (r.pairs as Array).size() == 2, "two wars a round, every guild in one")
		check(pairs.size() == 6, "day %d's rounds cover all six pairs (%s)" % [d, pairs.keys()])
		check(GuildLeague.pairs_on(d, 0) != GuildLeague.pairs_on(d + 1, 0), "who meets at 12:00 rotates by the day")
	var at := GuildLeague.slot_start(first + 3, 1)
	check(GuildLeague.live_slot(float(at)) == at and GuildLeague.live_slot(float(at) + GuildWarData.DURATION - 1.0) == at and GuildLeague.live_slot(float(at) + GuildWarData.DURATION) == -1, "a round is on for DURATION")
	check(GuildLeague.next_slot(float(at) - 1.0) == at and GuildLeague.next_slot(float(at)) == GuildLeague.slot_start(first + 3, 2), "the next round")
	check(GuildLeague.next_slot(float(GuildLeague.slot_start(first + 3, 2)) + 10.0) == GuildLeague.slot_start(first + 4, 0), "after 21:30 the next is tomorrow's 12:00")
	check(GuildLeague.schedule(GuildLeague.week_of(float(at))).size() == 42, "42 wars a week")


func _seeded(w: int) -> void:
	_hero(0)
	var wars := GuildLeague.sim_wars(w)
	check(wars.size() == 42, "every war of the week has a result (%d)" % wars.size())
	var copy: Array = wars.duplicate(true)
	GuildLeague._sim_cache.clear()
	GuildLeague._power_cache.clear()
	WorldPlayers.reset_roster()
	check(GuildLeague.sim_wars(w) == copy, "the seeded results come out the same when worked out again (same on every device)")
	# The stronger side by real fighter power wins more often.
	var stronger_won := 0
	for e in wars:
		var pa := GuildLeague.side_power(int(e.a), int(e.at))
		var pb := GuildLeague.side_power(int(e.b), int(e.at))
		if (pa >= pb) == (int(e.win) == int(e.a)):
			stronger_won += 1
	check(stronger_won > wars.size() / 2, "the stronger guild wins most wars (%d of %d)" % [stronger_won, wars.size()])
	var e0: Dictionary = wars[0]
	var p_manual := 0.0
	for i in GuildWarData.best_members(int(e0.a), float(e0.at), GuildWarData.GUILD_SIDE):
		p_manual += float(WorldPlayers.fighter(i, float(e0.at)).power)
	check(absf(p_manual - GuildLeague.side_power(int(e0.a), int(e0.at))) < 0.01, "a guild's might is its strongest twenty's fighter power")
	# Before anybody reaches Lv.100 there is no war.
	var opening := GuildLeague.week_of(float(WorldPlayers.START_UNIX))
	var none := GuildLeague.sim_war(GuildLeague.slot_start(WorldEvents.day_of(float(WorldPlayers.START_UNIX)) - 1, 0), 1, 2)
	check(none.is_empty(), "no members, no war")
	check(GuildLeague.table(opening - 1, []).all(func(r): return int(r.points) == 0), "a week before the opening has no points")


func _registration(w: int) -> void:
	_hero(WorldPlayers.ALPHA, 300)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 1)
	pin(float(at) - 3600.0)
	check(GuildLeague.next_slot(GuildLeague.now()) == at, "the next round is 18:00")
	check(GuildLeague.register_problem(at, float(at) - 301.0) == "", "registration is open until five minutes before")
	check(GuildLeague.register_problem(at, float(at) - 300.0) != "", "and closed from five minutes before (%s)" % GuildLeague.register_problem(at, float(at) - 300.0))
	check(GuildLeague.register(float(at) - 299.0) != "ok" and not GuildLeague.registered(at), "too late to register")
	check(GuildLeague.register() == "ok" and GuildLeague.registered(at), "registers for the next round")
	check(int(Game.profile.league.reg) == at, "kept in the save (league.reg)")
	check(GuildLeague.unregister() == "ok" and not GuildLeague.registered(at), "can cancel before it closes")
	check(GuildLeague.register() == "ok", "and register again")
	pin(float(at) - 200.0)
	check(GuildLeague.unregister() != "ok" and GuildLeague.registered(at), "no cancelling once closed")
	# Before the round: nothing to enter yet.
	check(GuildLeague.enter_problem() != "", "no war before the round starts")
	# The round begins: told once, then the hero may go in (late too).
	pin(float(at) + 5.0)
	check(GuildLeague.tell_round() and not GuildLeague.tell_round(), "the hero is told once that its round began")
	check(GuildLeague.enter_problem() == "", "registered and among the strongest: the war can be entered (%s)" % GuildLeague.enter_problem())
	pin(float(at) + GuildWarData.DURATION - 60.0)
	check(GuildLeague.enter_problem() == "", "late is fine while the round runs")
	var m := GuildLeague.enter_match()
	check(int(m.ours) == WorldPlayers.ALPHA and int(m.theirs) == GuildLeague.opponent(WorldPlayers.ALPHA, at) and int(m.at) == at, "the war to enter is the round's (%s)" % [m])
	pin(float(at) + GuildWarData.DURATION + 1.0)
	check(GuildLeague.enter_problem() != "", "over when the round ends")
	# Without registering: the round runs anyway, the hero can only watch.
	var next := GuildLeague.next_slot(GuildLeague.now())
	pin(float(next) + 60.0)
	check(not GuildLeague.registered(next) and GuildLeague.enter_problem().contains("ชม"), "not registered: watch only (%s)" % GuildLeague.enter_problem())
	pin(float(next) + GuildWarData.DURATION + 60.0)
	var pair: Array = GuildLeague.pairs_at(next)[0]
	var state := GuildLeague.match_state(next, int(pair[0]), int(pair[1]))
	check(String(state.state) == "done" and not (state.war as Dictionary).is_empty(), "the round still ran on time and has a result")
	# Outside a guild or below Lv.100: no registering.
	_hero(0, 300)
	check(GuildLeague.register() != "ok", "no guild, no registering")
	Game.profile.level = 99
	check(GuildLeague.register() != "ok", "below Lv.100, no registering")


func _line_up(w: int) -> void:
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 3, 0)
	var g := WorldPlayers.TITAN
	var rival := GuildLeague.opponent(g, at)
	# A weak hero (Lv.100, no stars) is outside its guild's strongest twenty.
	_hero(g, 0)
	var place := GuildLeague.hero_place(at)
	check(place > GuildWarData.GUILD_SIDE and not GuildLeague.hero_makes_side(at), "a weak hero ranks #%d, not in the twenty" % place)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var weak := GuildWarData.roll_guild_match(rng, g, rival, float(at))
	check(not bool(weak.hero_in) and weak.ally.size() == GuildWarData.GUILD_SIDE, "the line-up is the guild's twenty, without the weak hero")
	# Its party picks do not get a weak member in either.
	var members := WorldPlayers.members_at(g, float(at))
	var best := GuildWarData.best_members(g, float(at), 999)
	var outsider := String(WorldPlayers.entry(best[best.size() - 1]).name)
	Game.guildwar_party_picks = PackedStringArray([outsider])
	var with_pick := GuildWarData.roll_guild_match(rng, g, rival, float(at))
	if members.size() > GuildWarData.GUILD_SIDE:
		check(not with_pick.ally.any(func(f): return String(f.member.name) == outsider), "a party pick outside the twenty stays out (%s)" % outsider)
	Game.guildwar_party_picks = PackedStringArray()
	# A strong hero takes a place: nineteen members and the hero.
	_hero(g, 300)
	place = GuildLeague.hero_place(at)
	check(place >= 1 and place <= GuildWarData.GUILD_SIDE, "a ★300 hero ranks #%d" % place)
	var strong := GuildWarData.roll_guild_match(rng, g, rival, float(at))
	check(bool(strong.hero_in) and strong.ally.size() == GuildWarData.GUILD_SIDE - 1 and strong.enemy.size() == GuildWarData.GUILD_SIDE, "nineteen and the hero against twenty")
	check(int(strong.ally_guild) == g and int(strong.enemy_guild) == rival, "the two guilds are named in the roster")
	# The party screen offers the line-up only.
	var mates := GuildWarScreen.war_mates(g, float(at))
	check(mates.size() == GuildWarData.GUILD_SIDE - 1, "the party screen offers the nineteen (%d)" % mates.size())
	# Watching: both sides of a live war, twenty each.
	pin(float(at) + 300.0)
	var info := GuildLeague.live_match_info(g, rival)
	check(not info.is_empty() and info.ally.size() == GuildWarData.GUILD_SIDE and info.enemy.size() == GuildWarData.GUILD_SIDE, "a live war to watch has both twenties")
	check(bool(info.guilds) and info.league_match == [g, rival] and int(info.slot_start) == at and absf(float(info.elapsed) - 300.0) < 2.0, "with its guilds, round and time gone (%.0f s)" % float(info.get("elapsed", -1)))
	check(String(info.ally_name) == WorldPlayers.guild_name(g) and float(info.enemy_power) > 0.0, "named and weighed")
	check(GuildLeague.live_match_info(g, g).is_empty() and GuildLeague.live_match_info(g, rival, float(at) - 10.0).is_empty(), "nothing to watch off the schedule")


func _live_result(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE, 300)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 4, 2)
	var rival := GuildLeague.opponent(WorldPlayers.NEVERDIE, at)
	var a := mini(WorldPlayers.NEVERDIE, rival)
	var b := maxi(WorldPlayers.NEVERDIE, rival)
	var sim := GuildLeague.sim_war(at, a, b)
	pin(float(at) + GuildWarData.DURATION + 600.0)
	var before := GuildLeague.match_state(at, a, b)
	check(String(before.state) == "done" and before.war == sim and not bool(before.get("real", false)), "without the hero the seeded result stands")
	# The hero fights it and loses: its live result takes the war's place.
	var lose := 1 if int(sim.win) == WorldPlayers.NEVERDIE else 0
	GuildLeague.current_match = {"ours": WorldPlayers.NEVERDIE, "theirs": rival, "at": at}
	var result := {"won": lose == 0}
	GuildLeague.war_finished(result, true, [0, 2], 1, [5, 25])
	var after := GuildLeague.match_state(at, a, b)
	check(bool(after.get("real", false)) and int(after.war.win) == (WorldPlayers.NEVERDIE if lose == 0 else rival), "the hero's live result counts")
	check(int(after.war.held) == rival, "with who held the castle")
	var t := float(at) + GuildWarData.DURATION + 600.0
	var events := GuildLeague.events(w, GuildLeague.real_wars(w), t)
	check(events.filter(func(e): return int(e.at) == at and ((int(e.a) == a and int(e.b) == b) or (int(e.a) == b and int(e.b) == a))).size() == 1, "one result for that war, not two")
	# Fighting the same round again replaces the result, never doubles it.
	GuildLeague.current_match = {"ours": WorldPlayers.NEVERDIE, "theirs": rival, "at": at}
	GuildLeague.war_finished({"won": true}, true, [3, 0], 0, [40, 2])
	check(GuildLeague.real_wars(w).size() == 1 and int(GuildLeague.match_state(at, a, b).war.win) == WorldPlayers.NEVERDIE, "a rejoined round keeps one result")
	pin(float(at) + 60.0)
	check(GuildLeague.enter_problem() != "", "a round fought is not entered twice")


func _table(w: int) -> void:
	_hero(WorldPlayers.LNW, 300)
	var rows := GuildLeague.table(w, [])
	check(rows.size() == 4, "the table has the four guilds")
	var gs: Array = rows.map(func(r): return int(r.g))
	gs.sort()
	check(gs == [1, 2, 3, 4], "and only them (%s)" % [gs])
	check(GuildLeague.ids() == WorldPlayers.GUILDS, "no hired guild in the league")
	var wins := 0
	for r in rows:
		wins += int(r.wins)
	check(wins == 42, "42 wars, one winner each")
	var champ := GuildLeague.champion_of(w, [])
	check(WorldPlayers.GUILDS.has(champ), "the champion is one of the four (%s)" % WorldPlayers.guild_name(champ))
	# The castle holder walks back to the last round in which someone held it.
	var last_round := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_end(w) - 1.0), 2)
	pin(float(last_round) + GuildWarData.DURATION + 10.0)
	check(WorldPlayers.GUILDS.has(GuildLeague.holder(w, [], GuildLeague.now())), "someone holds the castle")
	# Next week the champion's members wear the crown, the hero's guild too when it won.
	pin(GuildLeague.week_start(w + 1) + 3600.0)
	check(GuildLeague.champion_now() == champ and GuildLeague.crowned(champ), "last week's champion is crowned")
	Game.join_guild(champ)
	check(GuildLeague.hero_champion() and absf(GuildLeague.exp_mult() - 1.0 - GuildLeague.EXP_BONUS) < 0.0001, "its members (the hero too) earn the EXP bonus")
	check(GuildLeague.shop_problem(GuildLeague.shop_entry("pink20")) in ["", "ทองไม่พอ"], "and may shop at the secret shop")
	var other := WorldPlayers.ALPHA if champ != WorldPlayers.ALPHA else WorldPlayers.TITAN
	Game.join_guild(other)
	check(not GuildLeague.hero_champion() and GuildLeague.exp_mult() == 1.0, "other guilds get nothing")
	var rank := GuildLeague.rank_of(w, [], other)
	check(GuildLeague.claimable().is_empty() == not GuildLeague.REWARDS.has(rank), "the top three claim rewards (rank %d)" % rank)


func _migration() -> void:
	_hero(WorldPlayers.ALPHA, 0)
	check(int(Game.profile.flags.get(Game.GUILD4_FLAG, 0)) == 1, "a new hero needs no re-pick")
	# An old save: a guild, leader picks, a registration, no flag.
	var old: Dictionary = Game.profile.duplicate(true)
	old.flags.erase(Game.GUILD4_FLAG)
	old.flags[Game.GUILD_FLAG] = WorldPlayers.NEVERDIE
	old["guild_leaders"] = {"2": "", "1": "Kaito"}
	old["league"] = {"week": 1, "wars": [], "reg": 1800000000}
	old.gold = 123456
	var json: Variant = JSON.parse_string(JSON.stringify(old))
	check(json is Dictionary and Game._valid_profile(json), "the old save is valid")
	var fixed := Game._repair(json)
	check(int(fixed.flags.get(Game.GUILD_FLAG, 0)) == 0 and not fixed.has("guild_leaders") and int(fixed.flags[Game.GUILD4_FLAG]) == 1, "it leaves its guild once")
	check(int(fixed.gold) == 123456 and int(fixed.level) == 100 and fixed.league.has("week") and not fixed.league.has("reg"), "everything else stays")
	# Picking again sticks: the next load does not clear it.
	fixed.flags[Game.GUILD_FLAG] = WorldPlayers.TITAN
	var twice := Game._repair(JSON.parse_string(JSON.stringify(fixed)))
	check(int(twice.flags[Game.GUILD_FLAG]) == WorldPlayers.TITAN, "only once: the new pick stays")
	check(not Game.migrate_guild4(twice), "the flag stops it")
	# Through the real save and load.
	Game.profile.flags.erase(Game.GUILD4_FLAG)
	Game.profile.flags[Game.GUILD_FLAG] = WorldPlayers.NEVERDIE
	check(Game.save() and Game.load_game(), "saves and loads")
	check(Game.guild() == 0, "the loaded hero picks its guild again")
	check(Game.join_guild(WorldPlayers.LNW) and Game.save() and Game.load_game() and Game.guild() == WorldPlayers.LNW, "joins 3DLnw and keeps it after a reload")


func _validation() -> void:
	_hero(WorldPlayers.TITAN, 300)
	check(Game.guild() == WorldPlayers.TITAN and Game._valid_profile(Game.profile.duplicate(true)), "a save in Titan is valid")
	var d := GuildLeague.data()
	d["reg"] = GuildLeague.next_slot(GuildLeague.now())
	d["told"] = -1
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(json), "reg and told are valid")
	var fixed := Game._repair(json)
	check(fixed.league.reg is int and int(fixed.league.reg) == int(d.reg), "and come back as ints")
	var bad: Dictionary = Game.profile.duplicate(true)
	bad.league["reg"] = "12:00"
	check(not Game._valid_profile(bad), "a broken registration is refused")
	var bad2: Dictionary = Game.profile.duplicate(true)
	bad2.league["reg"] = -5
	check(not Game._valid_profile(bad2), "a negative registration is refused")
	Game.profile.flags[Game.GUILD_FLAG] = 9
	check(Game.guild() == 0, "an unknown guild id reads as none")
	Game.profile.flags[Game.GUILD_FLAG] = WorldPlayers.LNW
	check(Game.guild() == WorldPlayers.LNW, "guild 4 is real")
	# A checkpoint keeps the league war's two guilds.
	Game.guildwar_save_checkpoint(5, 600.0, false, [1, 2], 0, 0, 1800000000, {"league": [4, 1]})
	var saved := Game.guildwar_checkpoint()
	check(saved.league == [4, 1] and int(saved.t0) == 1800000000, "a cut-off league war remembers its guilds")
	Game.guildwar_save_checkpoint(5, 600.0, false, [1, 2], 0, 0, 1800000000, {})
	check((Game.guildwar_checkpoint().league as Array).is_empty(), "a practice war has none")
	Game.guildwar_clear_checkpoint()


func _desk(w: int) -> void:
	_hero(WorldPlayers.ALPHA, 300)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 5, 0)
	pin(float(at) - 1800.0)
	var desk := GuildWarScreen.new()
	add_child(desk)
	await get_tree().process_frame
	desk.open_lobby()
	await get_tree().process_frame
	check(desk.find_child("LeagueSchedule", true, false) != null, "the desk shows the day's schedule")
	var countdown := desk.find_child("LeagueCountdown", true, false) as Label
	check(countdown != null and countdown.text.contains("12:00") and countdown.text.contains("ปิดรับสมัครใน"), "with a countdown to the next round (%s)" % (countdown.text if countdown else ""))
	check(desk.find_children("Match_*", "", true, false).size() == 6, "six wars today")
	var go := desk.find_child("EnterWar", true, false) as Button
	check(go != null and go.disabled, "no war to enter before the round")
	var practice := desk.find_child("PracticeWar", true, false) as Button
	check(practice != null and not practice.disabled and practice.text.contains("ไม่นับคะแนนลีก"), "practice wars count nothing in the league")
	var reg := desk.find_child("LeagueRegister", true, false) as Button
	reg.pressed.emit()
	await get_tree().process_frame
	check(GuildLeague.registered(at), "registered from the desk")
	var rank := desk.find_child("LeagueRank", true, false) as Label
	check(rank != null and rank.text.contains("อันดับในกิลด์ #") and rank.text.contains("ติดตัวจริง"), "the place in the guild is shown (%s)" % (rank.text if rank else ""))
	desk.close_screen()
	pin(float(at) + 90.0)
	desk.open_lobby()
	await get_tree().process_frame
	go = desk.find_child("EnterWar", true, false) as Button
	check(go != null and not go.disabled, "the round is on: เข้าสู่สงคราม (%s)" % (go.text if go else ""))
	var watch := desk.find_children("Watch_*", "Button", true, false)
	check(watch.size() == 2, "ชมการแข่งขัน for each live war")
	go.pressed.emit()
	await get_tree().process_frame
	check(int(Game.guildwar_league.get("at", 0)) == at and desk.candidates.size() == GuildWarData.GUILD_SIDE - 1, "into the party screen with the line-up (%d)" % desk.candidates.size())
	desk.close_screen()
	Game.guildwar_league = {}
	# A weak hero in the same round may only watch.
	_hero(WorldPlayers.ALPHA, 0)
	desk.open_lobby()
	await get_tree().process_frame
	go = desk.find_child("EnterWar", true, false) as Button
	check(go != null and go.disabled, "not registered: no entering (%s)" % (go.text if go else ""))
	check(desk.find_children("Watch_*", "Button", true, false).size() == 2, "but watching is open")
	desk.close_screen()
	desk.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
