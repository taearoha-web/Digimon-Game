extends Node
## Weekly guild league (GuildLeague): a season is Monday 00:00 to Sunday 23:59 Thai; the
## AI guilds' wars come from the week alone (the same table on every device) and move the
## table through the week; the hero's real war adds its points to its guild; at the week's
## turn the castle holder becomes the champion: its members get the crown plate, EXP +10%
## (also on the HUD chip) and the secret shop (champions only, limits a week); the top
## three claim their reward once; the save stays valid through JSON and a disk round trip;
## the guild registrar and the game menu show the table.
##   godot --headless --path . res://tests/integration/guild_league_test.tscn
var failures := 0
var checks := 0


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
	# A Wednesday 13:00 Thai, three weeks after the world opened.
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * 86400.0)
	var t := GuildLeague.week_start(w) + 2.0 * 86400.0 + 13.0 * 3600.0
	pin(t)
	_season(w, t)
	_real_war(w, t)
	_rollover(w)
	await _screens(w)
	_save(w)
	print("GUILD LEAGUE: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero(g := WorldPlayers.ALPHA) -> void:
	Game.new_profile(&"warrior", "League QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.join_guild(g)


func _season(w: int, t: float) -> void:
	var start := GuildLeague.week_start(w)
	check(WorldEvents.weekday(start) == 1 and WorldEvents.time_of_day(start) == 0, "a season starts on Monday 00:00 Thai")
	check(GuildLeague.week_of(start) == w and GuildLeague.week_of(start - 1.0) == w - 1 and GuildLeague.week_of(GuildLeague.week_end(w) - 1.0) == w, "Sunday 23:59 is still the same season")
	var wars := GuildLeague.sim_wars(w)
	check(wars.size() == 7 * GuildLeague.SLOTS.size(), "three AI wars a day (%d)" % wars.size())
	var copy: Array = wars.duplicate(true)
	GuildLeague._sim_cache.clear()
	check(GuildLeague.sim_wars(w) == copy, "the AI season comes from the week alone (same on every device)")
	check(GuildLeague.sim_wars(w + 1) != copy, "the next week plays out differently")
	var played := {}
	var inside := true
	for e in wars:
		inside = inside and float(e.at) >= start and float(e.at) < GuildLeague.week_end(w)
		played[int(e.a)] = int(played.get(int(e.a), 0)) + 1
		played[int(e.b)] = int(played.get(int(e.b), 0)) + 1
	check(inside, "every AI war is inside its season")
	check(played.size() == GuildLeague.ids().size(), "every league guild plays (%d of %d)" % [played.size(), GuildLeague.ids().size()])
	var zero := GuildLeague.table(w, [], start)
	var mid := GuildLeague.table(w, [], t)
	var final := GuildLeague.table(w, [])
	check(int(zero[0].points) == 0, "the table starts the week at zero")
	check(int(mid[0].points) > 0 and int(final[0].points) > int(mid[0].points), "the table moves through the week without the player")
	var wins := 0
	for r in final:
		wins += int(r.wins)
	check(wins == wars.size() and final.size() == 6, "one winner a war, six guilds")
	check(int(final[0].rank) == 1 and int(final[0].points) >= int(final[1].points), "ranked best first")
	var champ := GuildLeague.champion_of(w, [])
	var last_held := 0
	for e in wars:
		if int(e.held) > 0:
			last_held = int(e.held)
	check(champ == last_held and champ > 0, "the champion holds the castle when the season ends")
	check(GuildLeague.holder(w, [], start) == GuildLeague.champion_of(w - 1, []), "before the first war last week's champion holds the castle")


func _real_war(w: int, t: float) -> void:
	_hero()
	var before := GuildLeague.table(w, GuildLeague.real_wars(w), t)
	var result := Game.guildwar_finish(true, 30, 12, 4, 1, "Alpha", "Neverdie")
	var pts := GuildLeague.war_finished(result, true, [2, 0], 0, [30, 12])
	var expected := GuildLeague.WIN + 2 * GuildLeague.CAPTURE + GuildLeague.HOLD + 30 / GuildLeague.KILLS_PER_POINT
	check(pts == expected and int(result.league) == expected, "a real won war with two captures and the castle: %d points (%d)" % [expected, pts])
	check(GuildLeague.real_wars(w).size() == 1, "the war is kept in the season's record")
	var after := GuildLeague.table(w, GuildLeague.real_wars(w), t)
	var gain := func(g: int) -> int:
		var a := 0
		var b := 0
		for r in before:
			if int(r.g) == g:
				b = int(r.points)
		for r in after:
			if int(r.g) == g:
				a = int(r.points)
		return a - b
	check(gain.call(WorldPlayers.ALPHA) == expected, "the hero's guild earns the points")
	check(gain.call(WorldPlayers.NEVERDIE) == GuildLeague.LOSS + 12 / GuildLeague.KILLS_PER_POINT, "the rival earns the loser's points")
	check(GuildLeague.holder(w, GuildLeague.real_wars(w), t + 1.0) == WorldPlayers.ALPHA, "holding the castle at the bell makes the guild the holder")
	# A war with no guild (hired line-ups) is not a league war.
	var hired := {"won": true}
	check(GuildLeague.war_finished(hired, false, [1, 0], 0, [9, 3]) == 0 and GuildLeague.real_wars(w).size() == 1, "a hired war earns no league points")
	# A war outside any guild is not recorded either.
	_hero(0)
	check(GuildLeague.record_war(0, 0, true, 1, 0, 0, 5, 1) == 0, "no guild, no league points")


func _rollover(w: int) -> void:
	_hero()
	# Sunday 23:30, after the last AI war: Alpha takes and holds the castle; plus a strong
	# week so Alpha also tops the table.
	var late := GuildLeague.week_end(w) - 1800.0
	pin(late)
	for k in 12:
		GuildLeague.record_war(WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, true, 3, 0, 0, 60, 10, late - 3600.0 * float(12 - k))
	GuildLeague.record_war(WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, true, 1, 0, 0, 20, 5, late)
	check(not GuildLeague.hero_champion(), "no crown before the season ends")
	# Monday 10:00 of the next season.
	var t := GuildLeague.week_start(w + 1) + 10.0 * 3600.0
	pin(t)
	var d := GuildLeague.data()
	check(int(d.week) == w + 1 and (d.wars as Array).is_empty() and (d.prev_wars as Array).size() == 13 and int(d.prev_week) == w, "the week turns: last season's wars move aside")
	check(GuildLeague.champion_now() == WorldPlayers.ALPHA and GuildLeague.hero_champion(), "the guild holding the castle at the end is the champion")
	check(GuildLeague.crowned(WorldPlayers.ALPHA) and not GuildLeague.crowned(WorldPlayers.NEVERDIE), "the champion's members (world players too) wear the crown plate")
	check(absf(GuildLeague.exp_mult() - 1.1) < 0.0001, "the champion earns EXP +10%")
	check(GuildLeague.chip_text().contains("EXP +10%"), "the HUD event chip shows the bonus (%s)" % GuildLeague.chip_text())
	Game.profile.level = 50
	Game.profile.exp = 0
	WorldPresence.clock_offset += 0.0
	Game.add_exp(1000)
	check(int(Game.profile.exp) == 1100, "add_exp pays 1,100 for 1,000 (%d)" % int(Game.profile.exp))
	Game.profile.level = 100
	# Announced once.
	check(GuildLeague.tick(), "the week's end is announced")
	check(not GuildLeague.tick(), "only once")
	# The top-three reward, once.
	var reward := GuildLeague.claimable()
	check(int(reward.get("rank", 0)) == 1, "Alpha topped last season (%s)" % str(reward))
	var gold := int(Game.profile.gold)
	var pink := Game.jewel_count("pink")
	check(GuildLeague.claim() == "ok", "the reward is claimed")
	check(int(Game.profile.gold) == gold + int(GuildLeague.REWARDS[1].gold) and Game.jewel_count("pink") == pink + int(GuildLeague.REWARDS[1].jewels.pink), "it pays the gold and jewels")
	check(GuildLeague.claim() != "ok" and GuildLeague.claimable().is_empty(), "only once")
	# The secret shop.
	Game.profile.gold = 200000000
	var cores := Game.jewel_count("set_core")
	check(GuildLeague.shop_buy("set_core") == "ok" and GuildLeague.shop_buy("set_core") == "ok", "the champion buys set cores")
	check(Game.jewel_count("set_core") == cores + 2, "they arrive (%d)" % Game.jewel_count("set_core"))
	check(GuildLeague.shop_buy("set_core") != "ok", "up to the week's limit")
	check(GuildLeague.shop_buy("crown") == "ok" and bool(Game.profile.ach.get("t_castle_king", false)), "the crown is the title ราชันปราสาท")
	check(GuildLeague.shop_buy("crown") != "ok", "the crown is bought once")
	check(Game.set_title(Achievements.index_of("t_castle_king")) and Achievements.title_of(Game.profile) == "ราชันปราสาท", "the title can be worn")
	# Not for anyone else.
	Game.join_guild(WorldPlayers.NEVERDIE)
	check(not GuildLeague.hero_champion() and GuildLeague.exp_mult() == 1.0, "the rival's members get no bonus")
	check(GuildLeague.shop_buy("chaos10") != "ok" and GuildLeague.shop_problem(GuildLeague.shop_entry("chaos10")) != "", "the secret shop is for the champion only")
	check(GuildLeague.chip_text() == "", "no chip line for the rival")
	Game.join_guild(WorldPlayers.ALPHA)
	# The week after next: the shop counts start over, the crown passes on.
	pin(GuildLeague.week_start(w + 2) + 3600.0)
	check(GuildLeague.shop_bought("set_core") == 0, "the shop's limits reset with the season")
	check((GuildLeague.data().prev_wars as Array).is_empty(), "the old record is not carried two seasons")
	pin(t)


func _screens(w: int) -> void:
	# Back in the season Alpha won (the record of week w is lost; rebuild one).
	_hero()
	var late := GuildLeague.week_end(w) - 1800.0
	pin(late)
	GuildLeague.record_war(WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, true, 1, 0, 0, 20, 5, late)
	pin(GuildLeague.week_start(w + 1) + 10.0 * 3600.0)
	check(GuildLeague.hero_champion(), "champion again for the screens")
	var screen := GuildScreen.new()
	add_child(screen)
	screen.open_league()
	await get_tree().process_frame
	var table := screen.find_child("LeagueTable", true, false) as GridContainer
	check(table != null and table.get_child_count() == 6 * 7, "the registrar shows the league table (6 guilds)")
	check(screen.find_child("LeagueBuy_set_core", true, false) != null, "the champion sees the secret shop")
	check(screen.find_child("LeagueClaim", true, false) != null, "and the reward to claim")
	var champ_label := screen.find_child("LeagueChampion", true, false) as Label
	check(champ_label != null and champ_label.text.contains("Alpha"), "last week's champion is named")
	screen.close_screen()
	Game.join_guild(WorldPlayers.NEVERDIE)
	screen.open_league()
	await get_tree().process_frame
	check(screen.find_child("LeagueTable", true, false) != null and screen.find_child("LeagueBuy_set_core", true, false) == null, "no secret shop for others")
	screen.close_screen()
	screen.queue_free()
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"league")
	await get_tree().process_frame
	check(menu.find_child("LeagueTable", true, false) != null, "the game menu has the league tab")
	menu.close_menu()
	menu.queue_free()
	get_tree().paused = false
	var font := ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else null
	check(font == null or font.has_char(GuildLeague.CROWN.unicode_at(0)), "the crown glyph is in the game font")
	await get_tree().process_frame


func _save(w: int) -> void:
	_hero()
	pin(GuildLeague.week_end(w) - 1800.0)
	GuildLeague.record_war(WorldPlayers.ALPHA, WorldPlayers.NEVERDIE, true, 1, 0, 0, 20, 5)
	pin(GuildLeague.week_start(w + 1) + 3600.0)
	Game.profile.gold = 100000000
	GuildLeague.claim()
	GuildLeague.shop_buy("pink20")
	GuildLeague.tick()
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with a league record is valid")
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(json), "the JSON form is valid")
	var repaired := Game._repair(json)
	check(Game._valid_profile(repaired) and repaired.league.week is int and (repaired.league.prev_wars[0] as Dictionary).at is int, "it survives the JSON round trip as ints")
	var bad: Dictionary = Game.profile.duplicate(true)
	bad.league.prev_wars.append({"at": "x"})
	check(not Game._valid_profile(bad), "a broken war record is refused")
	var bad2: Dictionary = Game.profile.duplicate(true)
	bad2.league["junk"] = 1
	check(not Game._valid_profile(bad2), "unknown league keys are refused")
	var old: Dictionary = Game.profile.duplicate(true)
	old.erase("league")
	check(Game._valid_profile(old), "an old save without a league is valid")
	check(Game.save(), "the game saves")
	var claimed := int(Game.profile.league.claimed)
	check(Game.load_game(), "and loads")
	check(Game.profile.has("league") and int(Game.profile.league.claimed) == claimed and GuildLeague.claim() != "ok", "the claim is remembered after loading")
	check(GuildLeague.shop_bought("pink20") == 1, "the shop count is remembered after loading")
