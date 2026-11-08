extends Node
## The guild war's waiting room (GuildLeague.lobby_slot, GuildWarMatch.lobby_until,
## GuildWarLobby): from five minutes before a league round (when registration closes) the
## registered hero in its guild's line-up may go into the arena early; before that the desk
## says when it opens, an unregistered hero gets no button. Inside, before the bell: the
## hero at its camp with its line-up, nobody hurt, the gates unbreakable, the switch not
## taken, the hero kept within LOBBY_RADIUS of its camp, the countdown banner (and 10-9-8...).
## At the bell the war runs its full DURATION from the round's real start. Leaving and
## coming back works; nothing is checkpointed before the start.
##   godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_lobby_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	_texts()
	var at := GuildLeague.slot_start(WorldEvents.day_of(float(WorldPlayers.START_UNIX) + 20.0 * 86400.0), 0)
	_hero()
	pin(float(at) - 3600.0)
	check(GuildLeague.register() == "ok", "registered for the round")
	await _desk(at)
	await _arena(at)
	WorldPresence.clock_offset = 0.0
	print("GUILD WAR LOBBY: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero() -> void:
	Game.new_profile(&"warrior", "Lobby QA")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 300, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(300)}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for slot in DivineGearData.SLOTS:
		var piece := DivineGearData.item(Game.class_id(), slot, rng)
		piece["plus"] = 10
		Game.profile.equip[slot] = piece
	Game.profile.hp = Game.stats_now().max_hp
	Game.join_guild(WorldPlayers.ALPHA)


func _texts() -> void:
	check(GuildWarLobby.banner_text(272.0) == "สงครามเริ่มใน 4:32", "the banner: %s" % GuildWarLobby.banner_text(272.0))
	check(GuildWarLobby.count_text(11.0) == "" and GuildWarLobby.count_text(9.5) == "10" and GuildWarLobby.count_text(0.4) == "1", "the big count only in the last ten seconds")
	check(GuildWarLobby.count_text(0.0) == "เริ่ม!", "then เริ่ม!")


func _go_button(desk: GuildWarScreen) -> Button:
	desk.open_lobby()
	await _frames(2)
	var go := desk.find_child("EnterWar", true, false) as Button
	return go


func _desk(at: int) -> void:
	var desk := GuildWarScreen.new()
	add_child(desk)
	await _frames(1)
	# Before T-5:00: when the waiting room opens.
	pin(float(at) - 301.0)
	check(GuildLeague.lobby_slot() == -1 and GuildLeague.enter_problem() != "", "no way in before T-5:00")
	var go := await _go_button(desk)
	check(go != null and go.disabled and go.text.contains("เปิดให้เข้ารอได้ตอน %s" % GuildLeague.clock_text(at - 300)), "the desk tells when the waiting room opens (%s)" % (go.text if go else ""))
	desk.close_screen()
	# T-5:00..T: the waiting room.
	pin(float(at) - 299.0)
	check(GuildLeague.lobby_slot() == at and GuildLeague.enter_problem() == "", "the waiting room is open (%s)" % GuildLeague.enter_problem())
	go = await _go_button(desk)
	check(go != null and not go.disabled and go.text.contains("เข้าสู่สนาม (รอเริ่ม)"), "the desk offers เข้าสู่สนาม (รอเริ่ม) (%s)" % (go.text if go else ""))
	go.pressed.emit()
	await _frames(2)
	check(int(Game.guildwar_league.get("at", 0)) == at, "into the party screen for that round")
	desk.close_screen()
	Game.guildwar_league = {}
	# Watching is for live wars only.
	check(GuildLeague.live_round_info().is_empty(), "nothing to watch before the start")
	# Unregistered: no way in.
	var reg := int(Game.profile.league.reg)
	Game.profile.league["reg"] = -1
	go = await _go_button(desk)
	check(go != null and go.disabled, "an unregistered hero gets no button (%s)" % (go.text if go else ""))
	desk.close_screen()
	Game.profile.league["reg"] = reg
	# The round started: the usual live entry.
	pin(float(at) + 30.0)
	check(GuildLeague.lobby_slot() == -1 and GuildLeague.live_slot(GuildLeague.now()) == at and GuildLeague.enter_problem() == "", "after the start: the live entry")
	go = await _go_button(desk)
	check(go != null and not go.disabled and go.text.contains("เข้าสู่สงคราม"), "เข้าสู่สงคราม once it runs (%s)" % (go.text if go else ""))
	desk.close_screen()
	desk.queue_free()
	get_tree().paused = false
	await _frames(1)


func _zone() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_league = GuildLeague.enter_match()
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	return zone


func _arena(at: int) -> void:
	Game.guildwar_clear_checkpoint()
	pin(float(at) - 120.0)
	var zone := _zone()
	await _frames(2)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.lobby_until == at and m.started_at == at and m.state == "intro", "in early: waiting for the bell (lobby %d, start %d, %s)" % [m.lobby_until, m.started_at, m.state])
	check(m.team_count() == 4 and absf(m.time_left - GuildWarData.DURATION) < 0.01, "four guilds, the war's full time still ahead (%.1f)" % m.time_left)
	var home := m.home_of(GuildFighter.TEAM_ALLY)
	var hero := zone.hero
	check(_flat(hero.global_position, home) < GuildWarMatch.LOBBY_RADIUS, "the hero is at its camp (%.1f m)" % _flat(hero.global_position, home))
	check(m.side(GuildFighter.TEAM_ALLY).size() >= GuildWarData.GUILD_SIDE - 1 and m.side(GuildFighter.TEAM_ALLY).all(func(f): return _flat(f.global_position, home) < 20.0), "our line-up stands with it")
	for t in range(1, m.team_count()):
		var camp := m.home_of(t)
		check(m.side(t).all(func(f): return _flat(f.global_position, camp) < 20.0), "guild %d stands at its camp" % t)
	check(Game.guildwar_checkpoint().is_empty(), "no checkpoint while waiting")
	# Nobody is hurt.
	var foe: GuildFighter = m.side(1)[0]
	var foe_hp := foe.hp
	check(not foe.take_hit(100000, false, Color.WHITE, hero) and foe.hp == foe_hp, "a rival cannot be hurt")
	foe.take_damage(100000.0, hero)
	check(foe.hp == foe_hp, "nor by raw damage")
	var hero_hp := int(Game.profile.hp)
	hero.take_damage(100000.0, foe)
	check(int(Game.profile.hp) == hero_hp and not hero.is_dead(), "the hero cannot be hurt")
	check(m.gates.all(func(g): return not g.breakable), "no gate can be broken")
	var gate: CastleGate = m.gates[0]
	var gate_hp := gate.hp
	gate.take_damage(1.0e9, hero)
	gate.take_hit(1000000000, false, Color.WHITE, hero)
	check(gate.hp == gate_hp and not gate.is_dead(), "the front gate takes no harm")
	# The switch: even standing on it nothing is taken (and the hero is pushed back).
	foe.global_position = SiegeArena.SWITCH
	hero.global_position = SiegeArena.SWITCH + Vector3(0, 0.3, 0)
	await _frames(5)
	check(m.switch_owner == -1, "the switch is not taken before the start")
	check(_flat(hero.global_position, home) <= GuildWarMatch.LOBBY_RADIUS + 0.5, "the hero is kept near its camp (%.1f m)" % _flat(hero.global_position, home))
	hero.global_position = home + Vector3(40.0, 0.3, 30.0)
	await _frames(3)
	check(_flat(hero.global_position, home) <= GuildWarMatch.LOBBY_RADIUS + 0.5, "the camp bound holds (%.1f m)" % _flat(hero.global_position, home))
	hero.global_position = home + Vector3(5.0, 0.3, 0.0)
	await _frames(2)
	check(_flat(hero.global_position, home) < 6.0, "inside the bound the hero walks freely")
	# The banner.
	var banner := m.find_child("LobbyBanner", true, false) as Label
	check(banner != null and banner.text.begins_with("สงครามเริ่มใน 1:") or (banner != null and banner.text == "สงครามเริ่มใน 2:00"), "the banner counts down (%s)" % (banner.text if banner else ""))
	var leave := m.find_child("LobbyLeave", true, false) as Button
	check(leave != null and leave.visible, "a way back to town")
	pin(float(at) - 4.5)
	await _frames(2)
	var big := m.find_child("LobbyCount", true, false) as Label
	check(big != null and big.visible and big.text == "5", "the last seconds count big (%s)" % (big.text if big else ""))
	check(m.state == "intro" and Game.guildwar_checkpoint().is_empty(), "still waiting, still no checkpoint")
	# Leave and come back.
	zone.queue_free()
	await _frames(3)
	check(Game.guildwar_checkpoint().is_empty(), "leaving keeps nothing")
	pin(float(at) - 60.0)
	check(GuildLeague.enter_problem() == "", "may come back until the start (%s)" % GuildLeague.enter_problem())
	zone = _zone()
	await _frames(2)
	m = zone.gw_match
	check(m != null and m.lobby_until == at and m.state == "intro", "back in the waiting room")
	# The bell.
	pin(float(at) + 0.2)
	await _frames(3)
	check(m.state == "fight" and m.lobby_until == 0, "the war begins at the round's start (%s)" % m.state)
	check(m.time_left > GuildWarData.DURATION - 3.0 and m.time_left <= GuildWarData.DURATION, "with the full time from the real start (%.1f of %.0f)" % [m.time_left, GuildWarData.DURATION])
	check(m.started_at == at, "started_at is the round's (seeded results unchanged)")
	check(m.gates.any(func(g): return g.breakable), "the front gates can be broken now")
	var foe2: GuildFighter = m.side(1)[0]
	check(not foe2._frozen, "the fighters fight")
	check(not Game.guildwar_checkpoint().is_empty(), "the checkpoint starts with the war")
	big = m.find_child("LobbyCount", true, false) as Label
	check(big != null and big.text == "เริ่ม!", "เริ่ม! (%s)" % (big.text if big else ""))
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	# Entering late (no waiting room): the bell rings on the round's time, as before.
	pin(float(at) + 600.0)
	zone = _zone()
	await _frames(2)
	m = zone.gw_match
	check(m != null and m.lobby_until == 0 and m.find_child("LobbyBanner", true, false) == null, "late entry has no waiting room")
	check(absf(m.time_left - (GuildWarData.DURATION - 600.0)) < 5.0, "and the round's time left (%.1f)" % m.time_left)
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
