extends Node
## The guild league's two weekly titles (GuildLeague): แชมป์ลีก (League Champion, first by
## points; the top three still claim REWARDS) and ราชันปราสาท (Castle King, the holder after
## the Sunday's last round round: crown plate, EXP, secret shop); the deciding round (รอบชี้ขาด ×2)
## doubles its placement and capture points (HOLD and falls count once) from
## FINAL_FROM_WEEK on, applied when scoring the raw (official) results; a guild that is both
## is จักรพรรดิแห่งสัปดาห์ and its members claim 10 chaos jewels and the title once with the
## weekly reward (league.emp_claimed, valid in the save); the season-end announcement names
## both titles (and the emperor) once; the league page, desk and HUD chip name both titles.
##   godot --headless --path . res://tests/integration/league_titles_test.tscn
var failures := 0
var checks := 0
const DAY := 86400.0
var toasts: Array[String] = []
var world: Array[String] = []


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
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	Game.world_chat.connect(func(_speaker: String, text: String, _color: Color): world.append(text))
	# wa: one guild wins both titles; wb: one tops the points, another holds the castle.
	var wa := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * DAY)
	var wb := wa + 1
	_official(wa, WorldPlayers.NEVERDIE, WorldPlayers.NEVERDIE)
	_official(wb, WorldPlayers.TITAN, WorldPlayers.LNW)
	_final_round(wa)
	_points(wb)
	_castle_king(wb)
	_emperor(wa, wb)
	_validation(wa)
	_announcement(wa, wb)
	await _ui(wa, wb)
	_hero_round(wb)
	LeagueRounds.reset()
	WorldPresence.clock_offset = 0.0
	print("LEAGUE TITLES: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero(g: int) -> void:
	Game.new_profile(&"warrior", "Titles QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	if g > 0:
		Game.join_guild(g)


## Official results for every round of season w: `top` places first and holds the castle in
## every round but the last, whose castle `king` takes (with two captures).
func _official(w: int, top: int, king: int) -> void:
	var final_at := GuildLeague.final_slot(w)
	for m in GuildLeague.schedule(w):
		var at := int(m.at)
		var k := [5, 5, 5, 5]
		var c := [0, 0, 0, 0]
		k[top - 1] = 30
		c[top - 1] = 1
		var held := top
		if at == final_at and king != top:
			k[king - 1] = 10
			c[top - 1] = 0
			c[king - 1] = 2
			held = king
		check(LeagueRounds.adopt(at, {"at": at, "g": [1, 2, 3, 4], "k": k, "c": c, "held": held, "own": top}), "the official result of %d is taken" % at)


func _final_round(w: int) -> void:
	var at := GuildLeague.final_slot(w)
	var last := "21:30" if WorldEvents.day_of(float(at)) < GuildLeague.EARLY_FINAL_DAY else "20:30"
	check(GuildLeague.clock_text(at) == last and WorldEvents.day_of(float(at)) == WorldEvents.day_of(GuildLeague.week_end(w) - 1.0), "the deciding round is Sunday's last round, %s (%s)" % [last, GuildLeague.clock_text(at)])
	check(GuildLeague.is_final(at) and GuildLeague.mult_of(at) == 2, "it counts ×2")
	var others := 0
	for m in GuildLeague.schedule(w):
		if GuildLeague.is_final(int(m.at)):
			others += 1
	check(others == 1, "one deciding round a week")
	check(not GuildLeague.is_final(at - int(3.5 * 3600.0)) and GuildLeague.mult_of(at - int(3.5 * 3600.0)) == 1, "Sunday 18:00 counts once")
	check(not GuildLeague.is_final(GuildLeague.final_slot(GuildLeague.FINAL_FROM_WEEK - 1)), "seasons before FINAL_FROM_WEEK are scored as they were")
	# The same raw round: placement and captures ×2, HOLD and falls once; its order the same.
	var e := {"at": at, "g": [1, 2, 3, 4], "k": [30, 12, 5, 8], "c": [2, 0, 1, 0], "held": 1, "own": 3}
	var plain := e.duplicate(true)
	plain["at"] = at - DAY
	check(GuildLeague.placement(e) == GuildLeague.placement(plain), "the placement within the round is unchanged")
	var once := 40 + GuildLeague.HOLD + 30 / GuildLeague.KILLS_PER_POINT + 2 * GuildLeague.CAPTURE
	check(GuildLeague.side_points(plain, 1) == once, "a normal round: %d" % GuildLeague.side_points(plain, 1))
	check(GuildLeague.side_points(e, 1) == 80 + GuildLeague.HOLD + 30 / GuildLeague.KILLS_PER_POINT + 4 * GuildLeague.CAPTURE, "the deciding round: placement and captures ×2, HOLD and falls once (%d)" % GuildLeague.side_points(e, 1))
	check(GuildLeague.placement(e) == [1, 3, 2, 4] and GuildLeague.side_points(e, 3) == 50 + 5 / GuildLeague.KILLS_PER_POINT + 2 * GuildLeague.CAPTURE, "2nd: 25 ×2 + falls + a capture ×2 (%d)" % GuildLeague.side_points(e, 3))
	# The frozen result keeps the raw numbers: nothing doubled is stored.
	var kept := LeagueRounds.official_of(GuildLeague.final_slot(w))
	check(not kept.is_empty() and not kept.has("mult") and (kept.c as Array).max() <= 2, "the official result is stored raw (%s)" % [kept])


func _points(w: int) -> void:
	_hero(0)
	pin(GuildLeague.week_end(w) + 3600.0)
	var events := GuildLeague.events(w, [])
	check(events.size() == 21 and events.all(func(e): return bool(e.get("official", false))), "the week's 21 official rounds count")
	# The table is the plain points of every round plus the deciding round's extra.
	var expect := {1: 0, 2: 0, 3: 0, 4: 0}
	for e in events:
		for g in expect:
			var plain: Dictionary = (e as Dictionary).duplicate(true)
			plain["at"] = int(e.at) - 1
			var pts := GuildLeague.side_points(plain, g)
			if GuildLeague.is_final(int(e.at)):
				var i := (e.g as Array).find(g)
				var place := GuildLeague.placement(e).find(g)
				pts += (int(GuildLeague.PLACE_POINTS[place]) + GuildLeague.CAPTURE * int(e.c[i])) * (GuildLeague.FINAL_MULT - 1)
			expect[g] = int(expect[g]) + pts
	var rows := GuildLeague.table(w, [])
	var ok := true
	for r in rows:
		ok = ok and int(r.points) == int(expect[int(r.g)])
	check(ok, "table points = every round's points, the deciding round's placement and captures twice (%s / %s)" % [rows.map(func(r): return [r.g, r.points]), expect])
	var sorted := true
	for k in range(1, rows.size()):
		sorted = sorted and int(rows[k - 1].points) >= int(rows[k].points)
	check(sorted and int(rows[0].g) == WorldPlayers.TITAN, "ranked by points: Titan first")
	# 3DLnw's deciding round: 1st (40 ×2) + HOLD + 10 falls + 2 captures (×2).
	var final_e: Dictionary = events.filter(func(e): return int(e.at) == GuildLeague.final_slot(w))[0]
	check(GuildLeague.side_points(final_e, WorldPlayers.LNW) == 80 + GuildLeague.HOLD + 2 + 20, "the deciding round's winner earns %d" % GuildLeague.side_points(final_e, WorldPlayers.LNW))
	check(GuildLeague.league_champion_of(w, []) == WorldPlayers.TITAN, "แชมป์ลีก: first by points")


func _castle_king(w: int) -> void:
	pin(GuildLeague.week_end(w) + 3600.0)
	var final_at := GuildLeague.final_slot(w)
	check(GuildLeague.holder_after(GuildLeague.slot_start(WorldEvents.day_of(float(final_at)), 1)) == WorldPlayers.TITAN, "Titan held the castle until Sunday's last round")
	check(GuildLeague.holder_after(final_at) == WorldPlayers.LNW, "3DLnw took it in the deciding round")
	check(GuildLeague.champion_of(w, []) == WorldPlayers.LNW and GuildLeague.champion_now() == WorldPlayers.LNW, "ราชันปราสาท: the holder after Sunday's last round")
	check(GuildLeague.crowned(WorldPlayers.LNW) and not GuildLeague.crowned(WorldPlayers.TITAN), "the Castle King wears the crown, the League Champion does not")
	check(GuildLeague.emperor_of(w, []) == 0, "two guilds, no emperor")
	_hero(WorldPlayers.LNW)
	check(GuildLeague.hero_champion() and GuildLeague.exp_mult() > 1.0, "the Castle King's members earn the EXP bonus")
	check(GuildLeague.chip_text().contains(GuildLeague.CASTLE_TITLE), "the HUD chip names the Castle King (%s)" % GuildLeague.chip_text())
	var reward := GuildLeague.claimable()
	check(reward.is_empty() or not bool(reward.emperor), "the Castle King alone gets no emperor bonus")
	_hero(WorldPlayers.TITAN)
	check(not GuildLeague.hero_champion() and GuildLeague.chip_text() == "", "the League Champion has no crown or chip")
	reward = GuildLeague.claimable()
	check(int(reward.get("rank", 0)) == 1 and bool(reward.ranked) and not bool(reward.emperor) and reward.jewels == GuildLeague.REWARDS[1].jewels, "the League Champion claims the rank-1 reward only (%s)" % [reward])


func _chaos() -> int:
	var n := 0
	for item in Game.profile.inv + Game.storage():
		if item is Dictionary and String(item.get("kind", "")) == "jewel" and String(item.get("id", "")) == "chaos":
			n += int(item.get("count", 1))
	return n


func _emperor(wa: int, wb: int) -> void:
	pin(GuildLeague.week_start(wb) + 3600.0)
	check(GuildLeague.league_champion_of(wa, []) == WorldPlayers.NEVERDIE and GuildLeague.champion_of(wa, []) == WorldPlayers.NEVERDIE, "Neverdie won both titles")
	check(GuildLeague.emperor_of(wa, []) == WorldPlayers.NEVERDIE and GuildLeague.emperor_now() == WorldPlayers.NEVERDIE, "and is the week's emperor")
	_hero(WorldPlayers.NEVERDIE)
	Game.check_achievements()  # the new hero's own achievement rewards first
	var gold := int(Game.profile.gold)
	var chaos := _chaos()
	var reward := GuildLeague.claimable()
	check(bool(reward.get("emperor", false)) and bool(reward.ranked) and int(reward.rank) == 1, "the emperor's members claim the bonus with the weekly reward (%s)" % [reward])
	check(int(reward.jewels.chaos) == int(GuildLeague.REWARDS[1].jewels.chaos) + 10 and GuildLeague.reward_text(reward).contains(GuildLeague.EMPEROR_TITLE), "10 more chaos jewels and the title (%s)" % GuildLeague.reward_text(reward))
	check(GuildLeague.claim() == "ok", "claimed")
	check(int(Game.profile.gold) == gold + int(GuildLeague.REWARDS[1].gold) and _chaos() == chaos + int(reward.jewels.chaos), "gold and %d chaos jewels paid (%d gold, %d chaos)" % [int(reward.jewels.chaos), int(Game.profile.gold) - gold, _chaos() - chaos])
	check(int(Game.profile.league.claimed) == wa and int(Game.profile.league.emp_claimed) == wa, "both kept as claimed for the season")
	check(Achievements.is_earned("t_week_emperor", Game.profile), "the title is earned")
	Game.profile.flags[Achievements.TITLE_FLAG] = Achievements.index_of("t_week_emperor")
	check(Achievements.title_of(Game.profile) == "จักรพรรดิแห่งสัปดาห์", "and worn on the name plate (%s)" % Achievements.title_of(Game.profile))
	check(GuildLeague.claimable().is_empty() and GuildLeague.claim() != "ok" and _chaos() == chaos + int(reward.jewels.chaos), "only once a season")
	# A save that took the rank reward before the emperor bonus existed: the bonus alone.
	_hero(WorldPlayers.NEVERDIE)
	GuildLeague.data()["claimed"] = wa
	Game.check_achievements()
	gold = int(Game.profile.gold)
	reward = GuildLeague.claimable()
	check(bool(reward.get("emperor", false)) and not bool(reward.ranked) and int(reward.gold) == 0 and reward.jewels == {"chaos": 10}, "the rank reward taken: the bonus alone (%s)" % [reward])
	var result := GuildLeague.claim()
	check(result == "ok" and int(Game.profile.gold) == gold and GuildLeague.claimable().is_empty(), "and claimed once (%s, %d gold)" % [result, int(Game.profile.gold) - gold])
	# Other guilds: no bonus.
	_hero(WorldPlayers.ALPHA)
	reward = GuildLeague.claimable()
	check(reward.is_empty() or not bool(reward.emperor), "other guilds get no emperor bonus")
	_hero(0)
	check(GuildLeague.claimable().is_empty(), "nor does a hero outside a guild")


func _validation(wa: int) -> void:
	pin(GuildLeague.week_start(wa + 1) + 3600.0)
	_hero(WorldPlayers.NEVERDIE)
	GuildLeague.claim()
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(json) and int(json.league.emp_claimed) == wa, "a save with emp_claimed is valid")
	var fixed := Game._repair(json)
	check(fixed.league.emp_claimed is int and int(fixed.flags[GuildLeague.EMPEROR_FLAG]) == 1, "it comes back as an int, the title flag too")
	for bad in ["2967", 1.5, -2, [], {}]:
		var broken: Dictionary = Game.profile.duplicate(true)
		broken.league["emp_claimed"] = bad
		check(not Game._valid_profile(broken), "a broken emp_claimed is refused (%s)" % [bad])
	check(GuildLeague.INT_KEYS.has("emp_claimed"), "an int key of the league record")
	# The server's list (hosting/accounts/server/accounts.js) names the same keys.
	var server := FileAccess.get_file_as_string("res://hosting/accounts/server/accounts.js")
	var rx := RegEx.create_from_string("const LEAGUE_INTS = new Set\\(\\[([^\\]]*)\\]\\)")
	var m := rx.search(server)
	var keys: Array = []
	if m:
		for part in m.get_string(1).split(","):
			keys.append(part.strip_edges().trim_prefix("'").trim_suffix("'"))
	var mine: Array = GuildLeague.INT_KEYS.duplicate()
	keys.sort()
	mine.sort()
	check(server == "" or keys == mine, "accounts.js LEAGUE_INTS matches GuildLeague.INT_KEYS (%s / %s)" % [keys, mine])


func _announcement(wa: int, wb: int) -> void:
	# The season wb ended: two titles, two guilds.
	pin(GuildLeague.week_start(wb + 1) + 600.0)
	_hero(WorldPlayers.LNW)
	toasts.clear()
	world.clear()
	check(GuildLeague.tick(), "the first look after Sunday 23:59 announces")
	var line := "แชมป์ลีกสัปดาห์นี้: %s · ราชันปราสาท: %s" % [WorldPlayers.guild_name(WorldPlayers.TITAN), WorldPlayers.guild_name(WorldPlayers.LNW)]
	check(world.has(line) and toasts.has(line), "in the world chat and as a toast (%s)" % [world])
	check(not world.any(func(s): return s.contains(GuildLeague.EMPEROR_TITLE)), "no emperor line when two guilds share the titles")
	var count := world.size()
	check(not GuildLeague.tick() and world.size() == count, "only once")
	pin(GuildLeague.week_start(wb + 1) + 7200.0)
	check(not GuildLeague.tick() and world.size() == count, "not again later in the week")
	# The season wa ended: one guild won both.
	pin(GuildLeague.week_start(wb) + 600.0)
	_hero(WorldPlayers.NEVERDIE)
	toasts.clear()
	world.clear()
	check(GuildLeague.tick(), "announced")
	var name := WorldPlayers.guild_name(WorldPlayers.NEVERDIE)
	check(world.has("แชมป์ลีกสัปดาห์นี้: %s · ราชันปราสาท: %s" % [name, name]), "both titles named (%s)" % [world])
	check(world.any(func(s): return s.contains(GuildLeague.EMPEROR_TITLE) and s.contains(name)), "and the emperor line (%s)" % [world])
	check(toasts.any(func(s): return s.contains(GuildLeague.EMPEROR_TITLE) and s.contains("หน้าลีกกิลด์")), "the emperor's members are told to claim (%s)" % [toasts])
	count = world.size()
	check(not GuildLeague.tick() and world.size() == count, "once")


func _ui(wa: int, wb: int) -> void:
	# The league page in the season after wb: both titles named, the ×2 note by the table.
	pin(GuildLeague.week_start(wb + 1) + 3600.0)
	_hero(WorldPlayers.TITAN)
	var holder := Control.new()
	add_child(holder)
	LeagueView.build(holder, func(): pass)
	await get_tree().process_frame
	var champ := holder.find_child("LeagueChampion", true, false) as Label
	check(champ != null and champ.text.contains(GuildLeague.LEAGUE_TITLE) and champ.text.contains(GuildLeague.CASTLE_TITLE)
		and champ.text.contains("Titan") and champ.text.contains("3DLnw"), "the page names both titles and their guilds (%s)" % (champ.text if champ else ""))
	var final_note := holder.find_child("LeagueFinal", true, false) as Label
	check(final_note != null and final_note.text.contains(GuildLeague.FINAL_TAG) and final_note.text.contains("20:30"), "the table shows รอบชี้ขาด ×2 (%s)" % (final_note.text if final_note else ""))
	var emp := holder.find_child("LeagueEmperor", true, false) as Label
	check(emp != null and emp.text.contains(GuildLeague.EMPEROR_TITLE), "and the emperor's rule (%s)" % (emp.text if emp else ""))
	var info := holder.find_child("LeagueInfo", true, false) as Label
	check(info != null and info.text.contains(GuildLeague.LEAGUE_TITLE) and info.text.contains(GuildLeague.CASTLE_TITLE), "the season line explains both titles")
	holder.queue_free()
	# After wa: the emperor is named.
	pin(GuildLeague.week_start(wb) + 3600.0)
	_hero(WorldPlayers.NEVERDIE)
	holder = Control.new()
	add_child(holder)
	LeagueView.build(holder, func(): pass)
	await get_tree().process_frame
	emp = holder.find_child("LeagueEmperor", true, false) as Label
	check(emp != null and emp.text.contains("Neverdie") and emp.text.contains(GuildLeague.EMPEROR_TITLE), "the emperor is named (%s)" % (emp.text if emp else ""))
	var claim := holder.find_child("LeagueClaim", true, false) as Button
	var reward_card := holder.find_child("LeagueReward", true, false)
	var reward_label: Label = reward_card.find_children("*", "Label", true, false)[0] if reward_card else null
	check(claim != null and reward_label != null and reward_label.text.contains(GuildLeague.EMPEROR_TITLE), "the reward card offers the emperor bonus (%s)" % (reward_label.text if reward_label else ""))
	holder.queue_free()
	# The desk on Sunday of wb: the deciding round is marked.
	var final_at := GuildLeague.final_slot(wb)
	pin(float(final_at) - 1800.0)
	_hero(WorldPlayers.ALPHA)
	var desk := GuildWarScreen.new()
	add_child(desk)
	await get_tree().process_frame
	desk.open_lobby()
	await get_tree().process_frame
	var rule := desk.find_child("LeagueFinalRule", true, false) as Label
	check(rule != null and rule.text.contains(GuildLeague.FINAL_TAG) and rule.text.contains(GuildLeague.CASTLE_TITLE), "the desk explains the deciding round (%s)" % (rule.text if rule else ""))
	var row := desk.find_child("Round_%d" % final_at, true, false)
	var row_label: Label = row.find_children("*", "Label", true, false)[0] if row else null
	check(row_label != null and row_label.text.begins_with(GuildLeague.FINAL_TAG), "Sunday's last round is marked รอบชี้ขาด ×2 (%s)" % (row_label.text if row_label else ""))
	var plain := desk.find_child("Round_%d" % GuildLeague.slot_start(WorldEvents.day_of(float(final_at)), 1), true, false)
	var plain_label: Label = plain.find_children("*", "Label", true, false)[0] if plain else null
	check(plain_label != null and not plain_label.text.contains(GuildLeague.FINAL_TAG), "18:00 is not")
	desk.close_screen()
	desk.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	# Achievements: both league titles explained.
	var king := Achievements.entry("t_castle_king")
	var emperor := Achievements.entry("t_week_emperor")
	check(String(king.desc).contains("ราชันปราสาท") and not String(king.desc).contains("แชมป์ปราสาท"), "the Castle King title's text (%s)" % king.desc)
	check(String(emperor.title) == "จักรพรรดิแห่งสัปดาห์" and String(emperor.desc).contains("แชมป์ลีก") and String(emperor.desc).contains("ราชันปราสาท"), "the emperor title names both")


## The hero's own deciding round: its points come back doubled.
func _hero_round(wb: int) -> void:
	var at := GuildLeague.final_slot(wb)
	pin(float(at) + GuildWarData.DURATION + 60.0)
	_hero(WorldPlayers.ALPHA)
	var pts := GuildLeague.record_round([1, 2, 3, 4], [1, 0, 0, 0], [20, 5, 5, 5], 0, float(at), 4)
	check(pts == 80 + GuildLeague.HOLD + 4 + 2 * GuildLeague.CAPTURE, "a deciding round the hero fought pays ×2 placement and captures (%d)" % pts)
	var mine: Dictionary = GuildLeague.real_wars(wb)[0]
	check(int(mine.c1) == 1 and int(mine.k1) == 20, "the record keeps the raw captures and falls")
