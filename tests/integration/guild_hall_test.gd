extends Node
## The guild halls (GuildHallData, GuildHall): one hall a guild, built in slices within a
## phone's budget (a few static draws, the node count capped); only that guild's members
## go in (the door, the warp and Main.go all refuse the rest in Thai); the trophy wall
## reads the league's records exactly (the weeks of แชมป์ลีก / ราชันปราสาท / จักรพรรดิ from
## GuildLeague); the castle king's hall alone has the throne; the hall's blessing is
## granted once per half hour with the tier of the guild's league placement and counts in
## Game.add_exp and Game.stats_now (the HUD chip too); the leader's notice survives a save
## and a reload, the AI leader's is the same on every device; the training dummy reports
## damage a second and never falls; the guild mates in the hall are that guild's members.
##   godot --headless --path . res://tests/integration/guild_hall_test.tscn
var failures := 0
var checks := 0

## Static draws of the room itself (the GuildHall node: one batch of three surfaces, the
## ceiling, the signs), and the whole hall's nodes with its mates, dummy and villagers.
const ROOM_DRAWS := 16
const HALL_NODES := 3200


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _hero(g: int) -> void:
	Game.new_profile(&"warrior", "Hall QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	if g > 0:
		Game.join_guild(g)


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.clear_bonus()
	WorldPlayers.persist = false
	LeagueRounds.persist = false
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	GameSettings.quality = 1
	GameSettings.show_world_players = true
	MemoryGuard.force(0, get_tree())
	# A Wednesday 13:00 Thai, three weeks after the world opened: two seasons decided.
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * 86400.0)
	var t := GuildLeague.week_start(w) + 2.0 * 86400.0 + 13.0 * 3600.0
	pin(t)
	_ids()
	_gate(t)
	_trophies(t)
	await _halls(t)
	_buff(t)
	_notice(t)
	_steward(t)
	MemoryGuard.force(-1, get_tree())
	print("GUILD HALL: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _ids() -> void:
	for g in WorldPlayers.GUILDS:
		var id := GuildHallData.id_of(g)
		check(GuildHallData.is_hall(id) and GuildHallData.guild_of(id) == g, "hall id of guild %d round-trips (%s)" % [g, id])
		var z := ZoneData.get_zone(id)
		check(bool(z.get("hall", false)) and bool(z.get("safe", false)) and int(z.get("guild", 0)) == g, "%s is a safe hall zone of its guild" % id)
		check(String(z.name).contains(WorldPlayers.guild_name(g)) and String(z.name).contains(GuildHallData.TITLE), "%s is named after its guild (%s)" % [id, z.name])
		check(not ZoneData.ZONES.has(id), "%s is no field of the world (never a warp destination)" % id)
		check(AudioManager.has_music(z.music), "the hall reuses an existing track (%s)" % z.music)
	for bad in [&"guild_hall_0", &"guild_hall_9", &"guild_hall_x", &"town", &"meadow"]:
		check(not GuildHallData.is_hall(bad), "%s is no hall" % bad)


func _gate(t: float) -> void:
	_hero(0)
	var alpha := GuildHallData.id_of(WorldPlayers.ALPHA)
	var problem := GuildHallData.enter_problem(alpha)
	check(problem != "" and problem.contains("กิลด์"), "outside a guild the hall refuses in Thai (%s)" % problem)
	check(ZoneData.access_reason(alpha, 100, 300) == problem, "Main.go / the portals refuse with the same words")
	Game.join_guild(WorldPlayers.TITAN)
	check(GuildHallData.enter_problem(GuildHallData.id_of(WorldPlayers.TITAN)) == "", "a Titan member may enter Titan's hall")
	check(GuildHallData.hero_hall() == GuildHallData.id_of(WorldPlayers.TITAN), "hero_hall names its own guild's hall")
	var other := GuildHallData.enter_problem(alpha)
	check(other != "" and other.contains("Alpha"), "a Titan member is turned away from Alpha's hall, naming the guild (%s)" % other)
	check(ZoneData.access_reason(alpha, 100, 300) != "", "the access check keeps a Titan out of Alpha's hall")
	Game.profile.level = 50
	Game.profile["flags"].erase(Game.GUILD_FLAG)
	check(GuildHallData.enter_problem(alpha).contains(str(Game.GUILD_LEVEL)), "below the guild level the refusal names the level")
	Game.profile.level = 100


## The trophy wall counts exactly the seasons GuildLeague decided for each guild.
func _trophies(t: float) -> void:
	_hero(WorldPlayers.ALPHA)
	var first := GuildHallData.first_week()
	var last := GuildLeague.week_of(t) - 1
	check(last - first + 1 == 3, "three seasons are over by the pinned time (%d)" % (last - first + 1))
	var league_total := 0
	var castle_total := 0
	for g in WorldPlayers.GUILDS:
		var tr := GuildHallData.trophies(g, t)
		var want_league: Array = []
		var want_castle: Array = []
		var want_emperor: Array = []
		for w in range(first, last + 1):
			var real := GuildLeague.real_wars(w)
			if GuildLeague.league_champion_of(w, real) == g:
				want_league.append(w)
			if GuildLeague.champion_of(w, real) == g:
				want_castle.append(w)
			if GuildLeague.emperor_of(w, real) == g:
				want_emperor.append(w)
		check(tr.league == want_league and tr.castle == want_castle and tr.emperor == want_emperor, "guild %d's trophies match the league's records (%s / %s / %s)" % [g, tr.league, tr.castle, tr.emperor])
		for w in tr.emperor:
			check(tr.league.has(w) and tr.castle.has(w), "an emperor's week is a league and a castle week too")
		league_total += (tr.league as Array).size()
		castle_total += (tr.castle as Array).size()
		var lines := GuildHallData.trophy_lines(g, t)
		check(lines.size() >= 3 and String(lines[0]).begins_with(GuildLeague.LEAGUE_TITLE) and String(lines[0]).contains("%d สัปดาห์" % (tr.league as Array).size()), "the wall's first line counts the league titles (%s)" % lines[0])
		check(String(lines[1]).begins_with(GuildLeague.CASTLE_TITLE) and String(lines[2]).begins_with(GuildLeague.EMPEROR_TITLE), "the wall lists the castle king and the emperor")
	check(league_total == last - first + 1, "every decided season has exactly one league champion (%d of %d)" % [league_total, last - first + 1])
	check(castle_total == last - first + 1, "every decided season has exactly one castle king (%d)" % castle_total)
	check(GuildHallData.week_name(first) == "สัปดาห์ที่ 1", "seasons are named from the opening week")


## Every hall builds in slices, within budget, with its people and furniture; only the
## castle king's has the throne.
func _halls(t: float) -> void:
	var king := GuildLeague.champion_now(t)
	for g in WorldPlayers.GUILDS:
		_hero(g)
		var id := GuildHallData.id_of(g)
		Game.current_zone = id
		var zone := Zone.new()
		zone.zone_id = id
		zone.staged = true
		var frame0 := Engine.get_process_frames()
		add_child(zone)
		check(not zone.is_built, "%s: a staged hall is not finished within add_child" % id)
		if not zone.is_built:
			await zone.built
		check(Engine.get_process_frames() - frame0 > 0, "%s: the hall spreads over several frames" % id)
		check(zone.is_hall and not zone.is_town and zone.hero != null and not zone.hero.safe_zone, "%s: a hall, not the village; the hero may swing at the dummy" % id)
		check(zone.presence == null, "%s: no WorldPresence in the hall (its own crowd instead)" % id)
		var roles := {}
		for npc in zone.npcs:
			roles[npc.role] = npc
		for role in ["steward", "hall_notice", "hall_rest", "warp"]:
			check(roles.has(role), "%s: the hall has its %s" % [id, role])
		check((roles.get("steward") as Npc).display_name == GuildHallData.STEWARD if roles.has("steward") else false, "%s: the steward is %s" % [id, GuildHallData.STEWARD])
		check(zone.portals.size() == 1 and zone.portals[0].to == &"town", "%s: the way out leads to the village" % id)
		var room := zone.get_node_or_null("GuildHall") as Node3D
		check(room != null, "%s: the room is built" % id)
		var draws := 0
		var labels := 0
		if room != null:
			for mi in room.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).mesh != null:
					draws += (mi as MeshInstance3D).mesh.get_surface_count()
			labels = room.find_children("*", "Label3D", true, false).size()
			check(room.get_node_or_null("Hall") != null and room.get_node_or_null("Ceiling") != null, "%s: one batch for the room and one for the ceiling" % id)
			check((room.get_node("Ceiling") as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: the ceiling casts no shadow (the sun lights the room)" % id)
			check(room.get_node_or_null("TrophyText") != null and room.get_node_or_null("RosterText0") != null, "%s: the trophy wall and the roster board have their lettering" % id)
			var roster := (room.get_node("RosterText0") as Label3D).text
			var rows := GuildHallData.roster(g, t)
			check(rows.size() >= 1 and rows.size() <= GuildWarData.GUILD_SIDE, "%s: the board lists the war side (%d)" % [id, rows.size()])
			if not rows.is_empty():
				check(roster.contains(String(rows[0].name)), "%s: the strongest heads the board (%s)" % [id, rows[0].name])
				var sorted := true
				for k in rows.size() - 1:
					sorted = sorted and float(rows[k].power) >= float(rows[k + 1].power)
				check(sorted, "%s: the board is sorted by power" % id)
		check(draws <= ROOM_DRAWS, "%s: the room is a few draws (%d surfaces, %d signs)" % [id, draws, labels])
		var mates := zone.hall_mates()
		var members := WorldPlayers.members_at(g, t)
		var want := mini(GuildHallData.mates_limit(), members.size())
		check(mates.size() == want and mates.size() >= 6 and mates.size() <= 12, "%s: %d guild mates idle in the hall (%d wanted of %d members)" % [id, mates.size(), want, members.size()])
		for m in mates:
			check(int(WorldPlayers.entry(m.world_index).guild) == g and members.has(m.world_index), "%s: %s belongs to the guild" % [id, m.member.name])
			check(m.is_in_group("world_players") and not m.party_mode, "%s: %s is a world player of the hall" % [id, m.member.name])
		var dummies: Array = []
		for node in get_tree().get_nodes_in_group("mobs"):
			if node is TrainingDummy:
				dummies.append(node)
		check(dummies.size() == 1 and get_tree().get_nodes_in_group("mobs").size() == 1, "%s: the training dummy is the only 'monster' (%d)" % [id, get_tree().get_nodes_in_group("mobs").size()])
		var throne := false
		if room != null:
			# The throne and the castle banners are in the batch: the king's sign says it.
			for label in room.find_children("*", "Label3D", true, false):
				throne = throne or String((label as Label3D).text) == "%s %s สัปดาห์นี้" % [GuildLeague.CROWN, GuildLeague.CASTLE_TITLE]
		check(throne == (g == king), "%s: the golden throne and the castle banner only in the castle king's hall (king %d)" % [id, king])
		# The mates stroll and talk without a fight breaking out.
		for i in 40:
			await get_tree().physics_frame
		for m in mates:
			check(m.target == null and not m.is_dead(), "%s: %s stays peaceful" % [id, m.member.name])
			check(m.global_position.is_finite() and absf(m.global_position.x) < GuildHall.HALF_W and absf(m.global_position.z) < GuildHall.HALF_D, "%s: %s stays in the room (%s)" % [id, m.member.name, m.global_position])
		check(zone.hero.global_position.is_finite() and zone.hero.global_position.y > -0.5, "%s: the hero stands on the floor (%s)" % [id, zone.hero.global_position])
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		check(nodes <= HALL_NODES, "%s: the hall's nodes stay under %d (%d)" % [id, HALL_NODES, nodes])
		print("guild_hall_test: %s: %d room surfaces, %d signs, %d mates, %d nodes" % [id, draws, labels, mates.size(), nodes])
		if g == WorldPlayers.ALPHA and not dummies.is_empty():
			_dummy(dummies[0] as TrainingDummy)
		zone.queue_free()
		await _frames(3)


## The dummy counts the hits of the last seconds as damage a second and never dies.
func _dummy(dummy: TrainingDummy) -> void:
	check(dummy.hp == dummy.max_hp and dummy.dps == 0.0, "the dummy starts whole and quiet")
	for k in 4:
		var dead := dummy.take_hit(500, k == 1)
		check(not dead, "a hit never kills the dummy")
	check(dummy.total == 2000 and dummy.hp == dummy.max_hp and not dummy.is_dead(), "the dummy keeps its health after 2000 damage (%d / %d)" % [dummy.hp, dummy.max_hp])
	check(dummy.dps >= 2000.0 / TrainingDummy.WINDOW - 0.5 and dummy.dps <= 2000.0 + 0.5, "the plate reads a DPS (%0.1f)" % dummy.dps)
	check(dummy.best_dps >= dummy.dps, "the best run is kept")
	check(dummy._label.text.contains("DPS") and dummy._label.text.contains(TrainingDummy.NAME), "the plate shows the DPS (%s)" % dummy._label.text.replace("\n", " / "))
	check(dummy.take_hit(0, false) == false and dummy.total == 2000, "a zero hit counts nothing")
	check(not dummy.hostile, "the dummy never turns hostile")


## The blessing: once per half hour, the tier of the guild's placement, counted in EXP and ATK.
func _buff(t: float) -> void:
	_hero(WorldPlayers.NEVERDIE)
	var g := WorldPlayers.NEVERDIE
	Game.profile.level = 60
	check(not GuildHallData.active(t) and GuildHallData.chip_text(t) == "" and GuildHallData.exp_mult(t) == 1.0, "no blessing before a rest")
	var base_atk := float(Game.stats_now().atk)
	var place := GuildHallData.placement(g, t)
	check(place >= 1 and place <= 4, "the guild has a league placement (%d)" % place)
	check(GuildHallData.grant(t) == "ok", "a rest grants the blessing")
	check(GuildHallData.active(t) and GuildHallData.tier(t) == place, "the blessing's tier is the guild's placement (%d)" % GuildHallData.tier(t))
	var bonus: Array = GuildHallData.TIERS[place - 1]
	check(is_equal_approx(GuildHallData.exp_mult(t), 1.0 + float(bonus[0])), "EXP +%d%% at tier %d" % [int(float(bonus[0]) * 100.0), place])
	check(is_equal_approx(float(Game.stats_now().atk), base_atk * (1.0 + float(bonus[1]))), "ATK +%d%% through Game.stats_now (%0.1f -> %0.1f)" % [int(float(bonus[1]) * 100.0), base_atk, float(Game.stats_now().atk)])
	var chip := GuildHallData.chip_text(t)
	check(chip.contains(GuildHallData.BUFF_NAME) and chip.contains("ระดับ %d" % place) and chip.contains("30 นาที"), "the HUD chip names the blessing, its tier and the time left (%s)" % chip)
	check(is_equal_approx(GuildHallData.left(t), float(GuildHallData.BUFF_TIME)), "the blessing runs %d minutes" % (GuildHallData.BUFF_TIME / 60))
	# Game.add_exp counts it.
	var before := int(Game.profile.exp)
	Game.profile.exp = 0
	Game.add_exp(1000)
	var want := int(round(1000.0 * WorldEvents.exp_multiplier(t) * Game.exp_boost_mult() * GuildLeague.exp_mult(t) * GuildHallData.exp_mult(t)))
	check(int(Game.profile.exp) == want, "add_exp(1000) pays %d with the blessing (%d)" % [want, int(Game.profile.exp)])
	Game.profile.exp = before
	# Once per half hour.
	var again := GuildHallData.grant(t + 60.0)
	check(again != "ok" and again.contains("ยังมี"), "a second rest while it runs is refused (%s)" % again)
	check(not GuildHallData.active(t + float(GuildHallData.BUFF_TIME) + 1.0) and GuildHallData.chip_text(t + float(GuildHallData.BUFF_TIME) + 1.0) == "", "it ends after half an hour")
	pin(t + float(GuildHallData.BUFF_TIME) + 5.0)
	check(is_equal_approx(float(Game.stats_now().atk), base_atk), "the attack returns to normal when it ends")
	check(GuildHallData.grant() == "ok", "and a new rest grants it again")
	pin(t)
	# Outside a guild there is nothing to grant.
	_hero(0)
	check(GuildHallData.grant(t) != "ok", "no blessing outside a guild")
	# The tiers weaken from 1st to 4th.
	for k in range(1, GuildHallData.TIERS.size()):
		check(float(GuildHallData.TIERS[k - 1][0]) > float(GuildHallData.TIERS[k][0]) and float(GuildHallData.TIERS[k - 1][1]) > float(GuildHallData.TIERS[k][1]), "tier %d is bigger than tier %d" % [k, k + 1])


## The notice: the leader hero writes it and it survives a save and a reload; another
## leader's is the AI's deterministic line; nobody else may write.
func _notice(t: float) -> void:
	_hero(WorldPlayers.LNW)
	var g := WorldPlayers.LNW
	check(GuildHallData.hero_writes(g, t), "a new member leads its guild by default and may write")
	var empty := GuildHallData.notice(g, t)
	check(bool(empty.mine) and bool(empty.empty) and String(empty.text) == GuildHallData.NOTICE_EMPTY, "the board shows the empty notice before one is written")
	check(GuildHallData.set_notice("นัดรวมพลรอบ 21:30 คืนนี้\nยาเต็มกระเป๋า", t) == "ok", "the leader writes the notice")
	var mine := GuildHallData.notice(g, t)
	check(String(mine.text) == "นัดรวมพลรอบ 21:30 คืนนี้ ยาเต็มกระเป๋า" and bool(mine.mine) and String(mine.by) == "Hall QA", "the board shows the hero's notice on one line, signed")
	check(GuildHallData.set_notice("ก".repeat(GuildHallData.NOTICE_MAX + 1), t) != "ok", "a notice that is too long is refused")
	check(GuildHallData.set_notice("", t) == "ok" and bool(GuildHallData.notice(g, t).empty), "the notice may be cleared")
	check(GuildHallData.set_notice("  สู้ ๆ ทุกคน  ", t) == "ok" and String(GuildHallData.notice(g, t).text) == "สู้ ๆ ทุกคน", "spaces round the notice are trimmed")
	Game.save()
	Game.profile = {}
	Game.has_profile = false
	check(Game.load_game(Game.slot), "the save loads again")
	check(String(Game.profile.get(GuildHallData.NOTICE_KEY, "")) == "สู้ ๆ ทุกคน" and String(GuildHallData.notice(g, t).text) == "สู้ ๆ ทุกคน", "the notice survives a save and a reload")
	# A world player leads: the AI leader's own line, the same on every device.
	var members := WorldPlayers.members_at(g, t)
	check(not members.is_empty(), "3DLnw has members at Lv.100 by now (%d)" % members.size())
	if not members.is_empty():
		var leader := String(WorldPlayers.entry(members[0]).name)
		check(Game.set_guild_leader(g, leader, t), "the player hands the lead to %s" % leader)
		var ai := GuildHallData.notice(g, t)
		check(not bool(ai.mine) and String(ai.by) == leader and String(ai.text) != "" and String(ai.text).ends_with(leader), "the board shows the AI leader's notice signed by it (%s)" % ai.text)
		check(GuildHallData.notice(g, t) == ai and GuildHallData.ai_notice(g, leader, t) == GuildHallData.ai_notice(g, leader, t + 3600.0), "the AI leader's notice is the same on every device all season")
		var seasons := {}
		for k in 6:
			seasons[GuildHallData.ai_notice(g, leader, t + float(k) * 7.0 * 86400.0)] = true
		check(seasons.size() >= 2, "the seasons bring different lines (%d distinct of 6)" % seasons.size())
		check(GuildHallData.set_notice("ขอเขียนบ้าง", t) != "ok", "a member who does not lead may not write")
		check(GuildHallData.ai_notice(WorldPlayers.ALPHA, leader, t).contains("Alpha") or not GuildHallData.ai_notice(WorldPlayers.ALPHA, leader, t).contains("3DLnw"), "the notice speaks of its own guild")
	# Chatter is deterministic by the minute and never empty.
	for i in mini(3, WorldPlayers.size()):
		var line := GuildHallData.chatter(i, g, t)
		check(line != "" and line == GuildHallData.chatter(i, g, t + 30.0), "guild mate %d's line is set by the minute (%s)" % [i, line])


## The steward's words: the blessing's tier, the next round's time and the registration hook.
func _steward(t: float) -> void:
	_hero(WorldPlayers.ALPHA)
	var next := GuildLeague.next_slot(t)
	var war := GuildHallData.war_text(t)
	check(war.contains(GuildLeague.clock_text(next)) and war.contains("ยังไม่ได้สมัคร"), "the steward names the next round and that the hero has not registered (%s)" % war)
	check(GuildLeague.register(t) == "ok", "the steward's button registers the hero (GuildLeague.register)")
	check(GuildHallData.war_text(t).contains("สมัครรอบนี้แล้ว"), "and the steward says so afterwards")
	var buff := GuildHallData.buff_text(WorldPlayers.ALPHA, t)
	check(buff.contains(GuildHallData.BUFF_NAME) and buff.contains("อันดับ %d" % GuildHallData.placement(WorldPlayers.ALPHA, t)), "the steward explains the blessing and the guild's placement (%s)" % buff)
	var lines := GuildHallData.mates(WorldPlayers.ALPHA, t, 8)
	check(lines.size() == mini(8, WorldPlayers.members_at(WorldPlayers.ALPHA, t).size()), "the hall picks up to the asked number of mates (%d)" % lines.size())
	for i in lines:
		check(int(WorldPlayers.entry(i).guild) == WorldPlayers.ALPHA, "mate %s is an Alpha" % WorldPlayers.entry(i).name)
	check(lines == GuildHallData.mates(WorldPlayers.ALPHA, t + 60.0, 8), "the same mates within the hour (every device agrees)")
