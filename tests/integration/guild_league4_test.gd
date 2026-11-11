extends Node
## The four-guild league (GuildLeague, WorldPlayers, GuildWarData): Alpha, Neverdie, Titan
## and 3DLnw; everyone picks a guild of its own and each guild has at least twenty who
## reach Lv.100; three rounds a day at 12:00, 18:00 and 20:30 Thai (21:30 before GuildLeague.EARLY_FINAL_DAY), each round one castle
## war of all four guilds; registration closes five minutes before a round; the hero fights
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
	_idle_points(w)
	await _desk(w)
	WorldPresence.clock_offset = 0.0
	print("GUILD LEAGUE 4: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## Rounds fought without the player: guild points by the guild's place in each round,
## once, from the first round of the day for a character never credited, not for a round
## the hero fought for real, nothing outside a guild.
func _idle_points(w: int) -> void:
	var day := WorldEvents.day_of(GuildLeague.week_start(w)) + 2
	_hero(WorldPlayers.TITAN, 0)
	Game.profile["flags"].erase(GuildLeague.IDLE_FLAG)
	Game.profile["flags"][GuildQuestData.POINTS_FLAG] = 0
	# After the day's three rounds: all three credited, each 5-15 points.
	pin(float(GuildLeague.slot_start(day, 2)) + GuildWarData.DURATION + 60.0)
	var got := GuildLeague.credit_idle_rounds()
	check(got >= 3 * GuildLeague.IDLE_POINTS[-1] and got <= 3 * GuildLeague.IDLE_POINTS[0] and Game.guild_points() == got, "three rounds without the player pay guild points (%d)" % got)
	check(GuildLeague.credit_idle_rounds() == 0 and Game.guild_points() == got, "each round is paid once")
	# The next day's first round: one more, paid once.
	pin(float(GuildLeague.slot_start(day + 1, 0)) + GuildWarData.DURATION + 60.0)
	var more := GuildLeague.credit_idle_rounds()
	check(more >= GuildLeague.IDLE_POINTS[-1] and more <= GuildLeague.IDLE_POINTS[0], "the next round pays too (%d)" % more)
	# Outside a guild: the clock moves on, nothing is paid.
	Game.new_profile(&"warrior", "League4 Solo", FaceKit.default_look())
	Game.profile.level = 100
	pin(float(GuildLeague.slot_start(day + 1, 1)) + GuildWarData.DURATION + 60.0)
	check(GuildLeague.credit_idle_rounds() == 0 and Game.guild_points() == 0, "no guild, no points")


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
	for d in range(first, maxi(first + 10, GuildLeague.EARLY_FINAL_DAY + 3)):
		var rounds := GuildLeague.rounds_on(d)
		check(rounds.size() == 3, "three rounds on day %d" % d)
		var times: Array = rounds.map(func(r): return GuildLeague.clock_text(int(r.at)))
		var last := "21:30" if d < GuildLeague.EARLY_FINAL_DAY else "20:30"
		check(times == ["12:00", "18:00", last], "rounds at 12:00, 18:00, %s Thai on day %d (%s)" % [last, d, times])
		for r in rounds:
			check(WorldEvents.day_of(float(r.at)) == d, "a round is on its own Thai day")
			check(r.guilds == [1, 2, 3, 4], "one war a round, all four guilds in it")
	var at := GuildLeague.slot_start(first + 3, 1)
	check(GuildLeague.live_slot(float(at)) == at and GuildLeague.live_slot(float(at) + GuildWarData.DURATION - 1.0) == at and GuildLeague.live_slot(float(at) + GuildWarData.DURATION) == -1, "a round is on for DURATION")
	check(GuildLeague.next_slot(float(at) - 1.0) == at and GuildLeague.next_slot(float(at)) == GuildLeague.slot_start(first + 3, 2), "the next round")
	check(GuildLeague.next_slot(float(GuildLeague.slot_start(first + 3, 2)) + 10.0) == GuildLeague.slot_start(first + 4, 0), "after the last round the next is tomorrow's 12:00")
	check(GuildLeague.schedule(GuildLeague.week_of(float(at))).size() == 21, "21 rounds a week")


func _seeded(w: int) -> void:
	_hero(0)
	var wars := GuildLeague.sim_wars(w)
	check(wars.size() == 21, "every round of the week has a result (%d)" % wars.size())
	var copy: Array = wars.duplicate(true)
	GuildLeague._sim_cache.clear()
	GuildLeague._power_cache.clear()
	WorldPlayers.reset_roster()
	check(GuildLeague.sim_wars(w) == copy, "the seeded results come out the same when worked out again (same on every device)")
	# The stronger guilds by real fighter power place better more often. Their power is
	# their members' real forged gear (WorldGear), so the guilds stand close: over a few
	# weeks, the pairs a few percent apart are counted.
	var stronger_ahead := 0
	var pairs := 0
	# Each round begun with nobody holding the castle (sim_round's own 0): the holder's
	# defending edge and the chain of holders are their own checks, and with guilds only a
	# few percent apart a lucky holder kept over a week would hide what power does.
	for week in [w, w + 1, w + 2, w + 3]:
		for at in GuildLeague.schedule(week):
			var e := GuildLeague.sim_round(int(at.at), 0)
			if e.is_empty():
				continue
			var order := GuildLeague.placement(e)
			for i in order.size():
				for j in range(i + 1, order.size()):
					var pa := GuildLeague.week_power(order[i], int(e.at))
					var pb := GuildLeague.week_power(order[j], int(e.at))
					if absf(pa - pb) < 0.02 * maxf(pa, pb):
						continue
					pairs += 1
					if pa >= pb:
						stronger_ahead += 1
	check(pairs == 0 or stronger_ahead > pairs / 2, "the stronger guild places ahead more often (%d of %d)" % [stronger_ahead, pairs])
	var e0: Dictionary = wars[0]
	var p_manual := 0.0
	var g0 := int(e0.g[0])
	for i in GuildWarData.best_members(g0, float(e0.at), GuildWarData.GUILD_SIDE):
		p_manual += float(WorldPlayers.fighter(i, float(e0.at)).power)
	check(absf(p_manual - GuildLeague.side_power(g0, int(e0.at))) < 0.01, "a guild's might is its strongest twenty's fighter power")
	# Before anybody reaches Lv.100 there is no war.
	var opening := GuildLeague.week_of(float(WorldPlayers.START_UNIX))
	var none := GuildLeague.sim_round(GuildLeague.slot_start(WorldEvents.day_of(float(WorldPlayers.START_UNIX)) - 1, 0), 0)
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
	# Before the round: only its waiting room (from five minutes before; GuildWarMatch.lobby_until).
	check(GuildLeague.enter_problem(float(at) - 301.0) != "", "no war before the waiting room opens")
	check(GuildLeague.enter_problem() == "" and int(GuildLeague.enter_match().get("at", 0)) == at, "the waiting room is open five minutes before (%s)" % GuildLeague.enter_problem())
	# The round begins: told once, then the hero may go in (late too).
	pin(float(at) + 5.0)
	check(GuildLeague.tell_round() and not GuildLeague.tell_round(), "the hero is told once that its round began")
	check(GuildLeague.enter_problem() == "", "registered and among the strongest: the war can be entered (%s)" % GuildLeague.enter_problem())
	pin(float(at) + GuildWarData.DURATION - 60.0)
	check(GuildLeague.enter_problem() == "", "late is fine while the round runs")
	var m := GuildLeague.enter_match()
	check(m.guilds == [WorldPlayers.ALPHA, 2, 3, 4] and int(m.at) == at, "the war to enter is the round's, all four guilds, ours first (%s)" % [m])
	pin(float(at) + GuildWarData.DURATION + 1.0)
	check(GuildLeague.enter_problem() != "", "over when the round ends")
	# Without registering: the round runs anyway, the hero can only watch.
	var next := GuildLeague.next_slot(GuildLeague.now())
	pin(float(next) + 60.0)
	check(not GuildLeague.registered(next) and GuildLeague.enter_problem().contains("ชม"), "not registered: watch only (%s)" % GuildLeague.enter_problem())
	pin(float(next) + GuildWarData.DURATION + 60.0)
	var state := GuildLeague.round_state(next)
	check(String(state.state) == "done" and not (state.war as Dictionary).is_empty(), "the round still ran on time and has a result")
	# Outside a guild or below Lv.100: no registering.
	_hero(0, 300)
	check(GuildLeague.register() != "ok", "no guild, no registering")
	Game.profile.level = 99
	check(GuildLeague.register() != "ok", "below Lv.100, no registering")


func _line_up(w: int) -> void:
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 3, 0)
	var g := WorldPlayers.TITAN
	var rival := WorldPlayers.ALPHA
	# A weak hero (Lv.100, no stars) is outside its guild's strongest twenty.
	_hero(g, 0)
	var place := GuildLeague.hero_place(at)
	# Leading the guild (the default after joining) always makes the side.
	check(Game.hero_leads_guild(g, float(at)) and GuildLeague.hero_makes_side(at), "the guild's leader fights whatever its place (#%d)" % place)
	check(Game.set_guild_leader(g, WorldPlayers.guild_leader(g, float(at)), float(at)), "a member is picked to lead instead")
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
	var info := GuildLeague.live_round_info()
	check(not info.is_empty() and (info.sides as Array).size() == 4 and (info.sides as Array).all(func(sd): return (sd.lineup as Array).size() == GuildWarData.GUILD_SIDE), "a live round to watch has all four twenties")
	check(bool(info.guilds) and info.league_round == [1, 2, 3, 4] and int(info.slot_start) == at and absf(float(info.elapsed) - 300.0) < 2.0, "with its guilds, round and time gone (%.0f s)" % float(info.get("elapsed", -1)))
	check(String(info.sides[0].name) == WorldPlayers.guild_name(1) and float(info.sides[3].power) > 0.0, "named and weighed")
	check(GuildLeague.live_round_info(float(at) - 10.0).is_empty(), "nothing to watch off the schedule")


func _live_result(w: int) -> void:
	_hero(WorldPlayers.NEVERDIE, 300)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 4, 2)
	pin(float(at) + GuildWarData.DURATION + 600.0)
	var own := GuildLeague.start_holder(at)
	var sim := GuildLeague.sim_round(at, own)
	var before := GuildLeague.round_state(at)
	check(String(before.state) == "done" and before.war == sim and not bool(before.get("real", false)), "without the hero the seeded result stands")
	# The hero fights it (Neverdie first): its live result takes the round's place.
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at, "owner": own}
	GuildLeague.war_finished({"won": false}, true, [0, 2, 0, 0], 1, [5, 25, 3, 4])
	var after := GuildLeague.round_state(at)
	check(bool(after.get("real", false)) and int(after.war.held) == WorldPlayers.ALPHA and GuildLeague.placement(after.war)[0] == WorldPlayers.ALPHA, "the hero's live result counts, with who held the castle")
	var t := float(at) + GuildWarData.DURATION + 600.0
	var events := GuildLeague.events(w, GuildLeague.real_wars(w), t)
	check(events.filter(func(e): return int(e.at) == at).size() == 1, "one result for that round, not two")
	# Fighting the same round again replaces the result, never doubles it.
	GuildLeague.current_match = {"guilds": [2, 1, 3, 4], "at": at, "owner": own}
	GuildLeague.war_finished({"won": true}, true, [3, 0, 0, 0], 0, [40, 2, 1, 1])
	check(GuildLeague.real_wars(w).size() == 1 and GuildLeague.placement(GuildLeague.round_state(at).war)[0] == WorldPlayers.NEVERDIE, "a rejoined round keeps one result")
	pin(float(at) + 60.0)
	check(GuildLeague.enter_problem() != "", "a round fought is not entered twice")


func _table(w: int) -> void:
	_hero(WorldPlayers.LNW, 300)
	# The week over: all of its rounds count (a round not over is never counted).
	pin(GuildLeague.week_end(w) + 60.0)
	var rows := GuildLeague.table(w, [])
	check(rows.size() == 4, "the table has the four guilds")
	var gs: Array = rows.map(func(r): return int(r.g))
	gs.sort()
	check(gs == [1, 2, 3, 4], "and only them (%s)" % [gs])
	check(GuildLeague.ids() == WorldPlayers.GUILDS, "no hired guild in the league")
	var wins := 0
	for r in rows:
		wins += int(r.wins)
	check(wins == 21, "21 rounds, one first place each")
	var champ := GuildLeague.champion_of(w, [])
	check(WorldPlayers.GUILDS.has(champ), "the champion is one of the four (%s)" % WorldPlayers.guild_name(champ))
	# The castle's holder carries from round to round.
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
	# A checkpoint keeps the league round's guilds in team order.
	Game.guildwar_save_checkpoint(5, 600.0, false, [1, 2, 3, 4], 0, 0, 1800000000, {"league": [4, 1, 2, 3], "teams": 4})
	var saved := Game.guildwar_checkpoint()
	check(saved.league == [4, 1, 2, 3] and int(saved.t0) == 1800000000 and saved.scores == [1, 2, 3, 4], "a cut-off league war remembers its guilds and scores")
	# An old two-guild checkpoint still reads.
	for k in 4:
		Game.profile.flags.erase("gw_r_lg%d" % k)
	Game.profile.flags["gw_r_la"] = 4
	Game.profile.flags["gw_r_lb"] = 1
	check(Game.guildwar_checkpoint().league == [4, 1], "an old checkpoint's pair is kept")
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
	check(desk.find_children("Round_*", "", true, false).size() == 3, "three rounds today, one war each")
	var owner := desk.find_child("LeagueOwner", true, false) as Label
	check(owner != null and owner.text != "", "the desk tells who holds the castle (%s)" % (owner.text if owner else ""))
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
	check(watch.size() == 1, "ชมการแข่งขัน for the live round")
	check(go.text.contains("4 กิลด์"), "one war of all four guilds (%s)" % go.text)
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
	check(desk.find_children("Watch_*", "Button", true, false).size() == 1, "but watching is open")
	desk.close_screen()
	desk.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
