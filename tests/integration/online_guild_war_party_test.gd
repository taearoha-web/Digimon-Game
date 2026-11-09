extends Node3D
## A guild league round together online (GuildLeague.war_room, GuildWarMatch.league_room,
## OnlineGuildWar, EntitySync): two real players in one party and one guild who registered
## for the same round. One process plays both games in turn with a fake transport (Online
## is one autoload): what the first game sends is what the second one hears.
## - host (came in first): its war is in the round's room ("guildwar_<at>_<guild>", not the
##   practice war's "guildwar"), the partner shows as a RemotePlayer on our side, takes the
##   weakest AI member's place (the guild still sends GUILD_SIDE), the fighters and gates go
##   out, the partner's hits land, the status carries all four guilds, the bell carries the
##   round (gw_end lg);
## - member (came in second, by its own desk): its war is a mirror of the room's host
##   (no fighters of its own, the same four guilds, the waiting room on the round's clock),
##   sees the host as a RemotePlayer, the host's fighters and gates, its hits go to the host,
##   the host's bell ends it and the round it records is the host's to the number;
## - swaps: a war of its own when a party member hosts the room becomes a mirror; a mirror
##   named the host / left alone fights on in its own war;
## - the leader's invite names the room: another guild, not registered, too low are told in
##   Thai; a registered member of the guild gets the prompt;
## - offline: the league war as always (its own, the full line-up).
## godot --headless --audio-driver Dummy --path . res://tests/integration/online_guild_war_party_test.tscn
var checks := 0
var failures := 0
var at := 0
var room: StringName = &""
var league: Dictionary = {}
var fighter_spawns: Array = []
var gate_spawn: Dictionary = {}
var host_round: Dictionary = {}
var host_end: Dictionary = {}
var host_status: Dictionary = {}
var toasts: Array[String] = []


class FakeLink:
	extends RefCounted
	var sent: Array = []
	func send_text(text: String) -> void:
		sent.append(JSON.parse_string(text))
	func poll() -> Array:
		return []
	func frames(type: String) -> Array:
		return sent.filter(func(f): return f is Dictionary and String(f.get("t", "")) == type)
	func events(ev: String) -> Array:
		return frames("ent_event").filter(func(f): return String(f.get("ev", "")) == ev)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	Game.toast.connect(func(text: String, _kind: StringName): toasts.append(text))
	_hero()
	at = GuildLeague.slot_start(WorldEvents.day_of(float(WorldPlayers.START_UNIX) + 20.0 * 86400.0), 0)
	pin(float(at) - 3600.0)
	check(GuildLeague.register() == "ok", "registered for the round")
	pin(float(at) - 120.0)
	league = GuildLeague.enter_match()
	check(not league.is_empty(), "the waiting room is open for the registered hero (%s)" % GuildLeague.enter_problem())
	room = GuildLeague.war_room(at, Game.guild())
	check(String(room) == "guildwar_%d_%d" % [at, WorldPlayers.ALPHA] and GuildLeague.room_round(room) == {"at": at, "guild": WorldPlayers.ALPHA}, "the round's room: %s" % room)
	check(GuildLeague.room_round("guildwar").is_empty() and GuildLeague.room_round("guildwar_x_1").is_empty(), "the practice war is no room")
	check(Online.is_instanced(room) and Online.is_instanced(&"guildwar") and not Online.is_instanced(&"meadow"), "the room is party-scoped like the guild war")
	await _host()
	_reset_round()
	await _member()
	_reset_round()
	await _swaps()
	await _invites()
	await _offline()
	Online.use_transport(null)
	WorldPresence.clock_offset = 0.0
	print("ONLINE GUILD WAR PARTY: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _hero() -> void:
	Game.new_profile(&"warrior", "Party QA")
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
	Game.profile.party = []
	Game.join_guild(WorldPlayers.ALPHA)


## The other player's game: the round this one recorded is not there.
func _reset_round() -> void:
	var d := GuildLeague.data()
	d["wars"] = (d.get("wars", []) as Array).filter(func(e): return int(e.get("at", -1)) != at)
	LeagueRounds.reset()
	Game.guildwar_clear_checkpoint()


func _round_entry() -> Dictionary:
	for e in GuildLeague.data().get("wars", []):
		if e is Dictionary and int(e.get("at", -1)) == at:
			return e
	return {}


func war_zone() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_league = league.duplicate(true)
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	while not zone.is_built:
		await get_tree().process_frame
	await frames(2)
	zone.hero.set_physics_process(false)
	return zone


func _leave(zone: Zone) -> void:
	Online.use_transport(null)
	zone.queue_free()
	get_tree().paused = false
	Game.guildwar_league = {}
	await frames(3)


func _player(id: String, name: String, zone: String) -> Dictionary:
	return {"id": id, "name": name, "user": name.to_lower(), "cls": "mage", "level": 100, "look": {"class": "mage"}, "zone": zone, "pos": [0, 0, 0], "hp": 9000, "max_hp": 9000, "anim": "idle"}


# --- The first one in: its war is the room's ------------------------------------------

func _host() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	# The partner is the party's leader: arriving later, it does not take the room over.
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p2", "Buddy", "town")],
		"party": {"id": "party1", "leader": "p2", "members": ["p2", "me"]}})
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and not war.mirror and war.league_room == room, "host: its own league war in the round's room")
	if war == null or war.mirror:
		await _leave(zone)
		return
	check(war.team_count() == 4 and war.lobby_until == at, "host: four guilds, the waiting room until the bell")
	check(zone.net_id() == room and Online.current_zone() == room and zone.sync != null and zone.sync.key == room, "host: the server hears the room, not guildwar (%s)" % Online.current_zone())
	check(link.frames("gw_invite").is_empty() and not war.hold, "host: not the leader, nobody asked, nothing held")
	var full := war.side(GuildFighter.TEAM_ALLY).size()
	check(full == GuildWarData.GUILD_SIDE - 1, "host: alone, the hero and %d AI members (%d)" % [GuildWarData.GUILD_SIDE - 1, full])
	await seconds(0.3)
	check(link.frames("state").any(func(f): return String(f.get("zone", "")) == String(room)) or link.frames("hello").any(func(f): return String(f.get("zone", "")) == String(room)), "host: its state names the room")
	# The partner comes in (its own desk) and the server names this game the room's host.
	Online._dispatch({"t": "state", "id": "p2", "zone": String(room), "pos": [war.hero.global_position.x + 2.0, 0, war.hero.global_position.z]})
	Online._dispatch({"t": "host", "zone": String(room), "id": "me"})
	zone.sync.update_mode()
	check(zone.sync.is_host(), "host: hosts the room's war")
	await frames(3)
	var buddy := Online.remote_node("p2")
	check(buddy != null and is_instance_valid(buddy) and war.team_of(buddy) == GuildFighter.TEAM_ALLY, "host: sees the partner in the arena, on our side")
	check(war.seat_partners() >= 0 and war.side(GuildFighter.TEAM_ALLY).size() == GuildWarData.GUILD_SIDE - 2, "host: the partner takes the weakest AI member's place (%d AI + hero + partner = %d)" % [war.side(GuildFighter.TEAM_ALLY).size(), GuildWarData.GUILD_SIDE])
	check(toasts.any(func(t): return t.contains("แทนที่สมาชิก AI")), "host: told in Thai")
	# Four guilds' fighters, then the gates, at the link's rate.
	var waited := 0
	while waited < 150 and not link.events("spawn").any(func(f): return (f.data as Dictionary).has("gate")):
		await seconds(0.1)
		waited += 1
	for f in link.events("spawn"):
		var d: Dictionary = f.data
		if d.has("f") and int(d.team) != GuildFighter.TEAM_ALLY and fighter_spawns.size() < 3:
			fighter_spawns.append(f)
		if d.has("gate") and int(d.gate) == 0:
			gate_spawn = f
		check(String(f.zone) == String(room), "host: frames go to the room")
	check(fighter_spawns.size() == 3 and not gate_spawn.is_empty(), "host: the rival fighters and the gates are shared")
	# The bell: the partner's hits land, the status carries every guild.
	pin(float(at) + 1.0)
	await seconds(1.2)
	check(war.state == "fight", "host: the war began at the bell")
	var foe: GuildFighter = war.side(2)[0]
	foe._guard_until = 0
	foe._dodge = 0.0
	var before := foe.hp
	Online._dispatch({"t": "ent_hit", "zone": String(room), "eid": int(foe.get_meta("eid", 0)), "dmg": 300, "crit": false, "from": "p2"})
	check(foe.hp < before, "host: the partner's hit lands on a third guild's fighter (%d -> %d)" % [before, foe.hp])
	foe.hp = 5
	var kills := war.score[0]
	Online._dispatch({"t": "ent_hit", "zone": String(room), "eid": int(foe.get_meta("eid", 0)), "dmg": 50, "crit": false, "from": "p2"})
	await seconds(0.3)
	check(foe.is_dead() and war.score[0] == kills + 1, "host: the partner's kill scores for our guild")
	await seconds(0.6)
	var status := link.events("gw")
	check(not status.is_empty() and (status[-1].data.sa as Array).size() == 4 and int(status[-1].data.sa[0]) == war.score[0], "host: the status carries all four guilds' falls")
	if not status.is_empty():
		host_status = status[-1].data
	war.score[1] = 7
	war.captures[2] = 1
	war.castle_owner = 2
	link.sent.clear()
	var results: Array = []
	zone.guildwar_finished.connect(func(r: Dictionary): results.append(r))
	war._end()
	await seconds(0.3)
	var ends := link.events("gw_end")
	check(ends.size() == 1 and ends[0].data.has("lg"), "host: the bell goes out with the round (gw_end lg)")
	if ends.size() == 1:
		host_end = ends[0].data
		var lg: Dictionary = host_end.lg
		check(int(lg.at) == at and int(lg.g[0]) == WorldPlayers.ALPHA and (lg.k as Array).size() == 4 and int(lg.h) == 2, "host: lg has the round, the guilds, every guild's falls and the holder")
	host_round = _round_entry().duplicate(true)
	check(not host_round.is_empty() and int(host_round.g1) == WorldPlayers.ALPHA, "host: the round is recorded here")
	await seconds(3.3)
	check(results.size() == 1, "host: the result screen")
	await _leave(zone)


# --- The second one in: a mirror of the room's war ------------------------------------

func _member() -> void:
	pin(float(at) - 90.0)
	var link := FakeLink.new()
	Online.use_transport(link)
	# This one leads the party; a third member is still in the village.
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p1", "Captain", String(room)), _player("p4", "Late", "town")],
		"party": {"id": "party1", "leader": "me", "members": ["me", "p1", "p4"]}})
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and war.mirror and war.league_room == room, "member: the partner is in the room: its war is a mirror")
	if war == null or not war.mirror:
		await _leave(zone)
		return
	check(get_tree().get_nodes_in_group("gw_fighters").is_empty() and war.all_fighters().is_empty(), "member: no fighters of its own")
	check(war.team_count() == 4 and war.team_guilds[0] == WorldPlayers.ALPHA and war.lobby_until == at and war.state == "intro", "member: the same four guilds, the same waiting room")
	check(zone.net_id() == room and Online.current_zone() == room, "member: in the same room")
	check(link.frames("gw_invite").size() == 1 and String(link.frames("gw_invite")[0].room) == String(room), "member (the leader): its invite names the room for the rest of the party")
	Online._dispatch({"t": "host", "zone": String(room), "id": "p1"})
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "member: mirrors the room's host")
	await frames(2)
	check(Online.remote_node("p1") != null, "member: sees the host in the arena")
	for f in fighter_spawns:
		var spawn: Dictionary = f.duplicate(true)
		spawn["from"] = "p1"
		Online._dispatch(spawn)
	var gate: Dictionary = gate_spawn.duplicate(true)
	gate["from"] = "p1"
	Online._dispatch(gate)
	await frames(2)
	var eid := int(fighter_spawns[0].eid) if not fighter_spawns.is_empty() else 0
	var foe: MirrorFighter = zone.sync.mirrors.get(eid)
	check(foe != null and war.enemies.has(foe), "member: the host's fighter is the same foe here")
	check(war.gates[0].sync_eid == int(gate_spawn.get("eid", -1)), "member: the host's gate")
	if foe == null:
		await _leave(zone)
		return
	# The host's bell rang (its clock): the waiting room is over here too.
	var st: Dictionary = host_status.duplicate(true)
	Online._dispatch({"t": "ent_event", "zone": String(room), "eid": 0, "ev": "gw", "from": "p1", "data": st})
	await seconds(0.5)
	check(war.state == "fight" and war.lobby_until == 0, "member: the host's war runs, so does this one (%s)" % war.state)
	check(war.score.size() == 4 and war.score[0] == int(st.sa[0]), "member: every guild's falls from the host (%s)" % str(war.score))
	link.sent.clear()
	foe.take_hit(120, false, Color.WHITE, zone.hero)
	await seconds(0.3)
	check(link.frames("ent_hit").any(func(f): return int(f.eid) == eid and String(f.zone) == String(room)), "member: a hit on the foe goes to the host")
	Online._dispatch({"t": "ent_event", "zone": String(room), "eid": eid, "ev": "dead", "from": "p1", "data": {"killer": "me", "share": {}}})
	check(foe.is_dead() and war.hero_kills == 1, "member: its kill counts for it")
	var results: Array = []
	zone.guildwar_finished.connect(func(r: Dictionary): results.append(r))
	var end: Dictionary = host_end.duplicate(true)
	Online._dispatch({"t": "ent_event", "zone": String(room), "eid": 0, "ev": "gw_end", "from": "p1", "data": end})
	check(war.state == "ending", "member: the host's bell ends it here")
	var mine := _round_entry()
	var same := not mine.is_empty() and not host_round.is_empty()
	for key in GuildLeague.ROUND_KEYS:
		if same and int(mine.get(key, -1)) != int(host_round.get(key, -2)):
			same = false
			printerr("  round key %s: %s vs host %s" % [key, str(mine.get(key)), str(host_round.get(key))])
	check(same, "member: the round it records is the host's (%s vs %s)" % [str(mine), str(host_round)])
	check(not LeagueRounds.result_of(at).is_empty(), "member: its record of the round goes to the server too (the same one)")
	await seconds(3.4)
	check(results.size() == 1 and int(results[0].get("placement", 0)) == int(host_end.lg.pl) and int(results[0].kills) == 1, "member: the result screen (the host's placement, its own kills)")
	await _leave(zone)


# --- Swaps: one war for the room ------------------------------------------------------

func _swaps() -> void:
	pin(float(at) - 60.0)
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p2", "Buddy", "town")],
		"party": {"id": "party1", "leader": "p2", "members": ["p2", "me"]}})
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and not war.mirror, "swap: in first, its own war")
	# Both came in at once; the server named the partner the room's host.
	OnlineGuildWar.last_travel = {}
	Online._dispatch({"t": "state", "id": "p2", "zone": String(room), "pos": [0, 0, 0]})
	Online._dispatch({"t": "host", "zone": String(room), "id": "p2"})
	zone.sync.update_mode()
	check(not zone.sync.is_mirror() and not zone.sync.is_host(), "swap: its own war takes no mirrors meanwhile")
	check(bool(OnlineGuildWar.last_travel.get("mirror", false)) and OnlineGuildWar.last_travel.get("room") == room and int(OnlineGuildWar.last_travel.league.at) == at, "swap: its war goes, it comes back as the host's mirror")
	check(Online.travel_room == room, "swap: the server keeps hearing the room meanwhile")
	await _leave(zone)
	Online.travel_room = &""
	OnlineGuildWar.mirror_wanted(&"")
	# A mirror the server names the host (the host left, another member stays).
	link = FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p2", "Buddy", String(room)), _player("p3", "Third", String(room))],
		"party": {"id": "party1", "leader": "p2", "members": ["p2", "me", "p3"]}})
	zone = await war_zone()
	war = zone.gw_match
	check(war != null and war.mirror, "swap: a mirror of the room's host")
	OnlineGuildWar.last_travel = {}
	Online._dispatch({"t": "leave", "id": "p2"})
	Online._dispatch({"t": "host", "zone": String(room), "id": "me"})
	zone.sync.update_mode()
	check(OnlineGuildWar.last_travel.has("mirror") and not bool(OnlineGuildWar.last_travel.mirror), "swap: named the host: fights the round on in a war of its own")
	await _leave(zone)
	Online.travel_room = &""
	OnlineGuildWar.mirror_wanted(&"")
	# Left alone in the room (or the link broke): its own war, not a loss.
	link = FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p2", "Buddy", String(room))],
		"party": {"id": "party1", "leader": "p2", "members": ["p2", "me"]}})
	zone = await war_zone()
	war = zone.gw_match
	OnlineGuildWar.last_travel = {}
	war.mirror_lost()
	check(war.state == "intro" and OnlineGuildWar.last_travel.has("mirror") and not bool(OnlineGuildWar.last_travel.mirror), "swap: the host gone: its own war, nothing lost")
	check(_round_entry().is_empty(), "swap: nothing recorded for the round")
	await _leave(zone)
	Online.travel_room = &""
	OnlineGuildWar.mirror_wanted(&"")
	# A practice war is not the room: a partner in the round's room is not mixed in.
	link = FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("p2", "Buddy", String(room))],
		"party": {"id": "party1", "leader": "me", "members": ["me", "p2"]}})
	league = {}
	zone = await war_zone()
	war = zone.gw_match
	check(war != null and not war.mirror and war.league_room == &"" and zone.net_id() == &"guildwar", "swap: a practice war stays in guildwar, apart from the round's room")
	if war != null:
		war.hold = false
	await _leave(zone)
	league = GuildLeague.enter_match()


# --- The leader's invite: who may come ------------------------------------------------

func _invites() -> void:
	pin(float(at) - 60.0)
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [_player("lead1", "Captain", String(room))],
		"party": {"id": "party3", "leader": "lead1", "members": ["lead1", "me"]}})
	Game.current_zone = &"town"
	var coord := OnlineGuildWar.instance
	check(coord != null, "invite: the coordinator is there")
	if coord == null:
		return
	# Another guild's room.
	toasts.clear()
	var other := GuildLeague.war_room(at, WorldPlayers.ALPHA + 1 if WorldPlayers.GUILD_NAMES.has(WorldPlayers.ALPHA + 1) else WorldPlayers.ALPHA - 1)
	Online._dispatch({"t": "gw_invite", "from": "lead1", "room": String(other)})
	check(coord.prompt == null and bool(link.frames("gw_answer").size() == 1) and not bool(link.frames("gw_answer")[0].ok), "invite: another guild's room: no")
	check(toasts.any(func(t): return t.contains("คนละกิลด์")), "invite: told in Thai it is another guild (%s)" % str(toasts))
	# Not registered.
	toasts.clear()
	var reg := int(Game.profile.league.reg)
	Game.profile.league["reg"] = -1
	Online._dispatch({"t": "gw_invite", "from": "lead1", "room": String(room)})
	check(coord.prompt == null and toasts.any(func(t): return t.contains("ไม่ได้สมัคร")), "invite: not registered: told in Thai (%s)" % str(toasts))
	Game.profile.league["reg"] = reg
	# Too low.
	toasts.clear()
	Game.profile.level = 60
	Online._dispatch({"t": "gw_invite", "from": "lead1", "room": String(room)})
	check(coord.prompt == null and not toasts.is_empty() and toasts[-1].contains("ไปไม่ได้"), "invite: too low: told in Thai (%s)" % str(toasts))
	Game.profile.level = 100
	# A registered member of the guild: the prompt; an older server's invite without the
	# room is read from the leader's zone.
	link.sent.clear()
	Online._dispatch({"t": "gw_invite", "from": "lead1"})
	check(coord.prompt != null and is_instance_valid(coord.prompt) and coord._invite_room == room, "invite: the prompt for the round's room")
	var label := coord.prompt.find_child("Text", true, false) as Label if coord.prompt != null else null
	check(label != null and label.text.contains("สงครามลีกรอบ %s" % GuildLeague.clock_text(at)), "invite: the prompt says the round (%s)" % (label.text if label else ""))
	coord.answer(false)
	check(link.frames("gw_answer").size() == 1 and not bool(link.frames("gw_answer")[0].ok) and coord.prompt == null, "invite: no is sent")
	Online.use_transport(null)


# --- Offline: as always ---------------------------------------------------------------

func _offline() -> void:
	pin(float(at) - 60.0)
	Online.use_transport(null)
	OnlineGuildWar.mirror_wanted(&"")
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and not war.mirror and war.team_count() == 4 and war.lobby_until == at, "offline: the league war of its own")
	check(war != null and war.side(GuildFighter.TEAM_ALLY).size() == GuildWarData.GUILD_SIDE - 1 and war.seat_partners() == 0, "offline: the full line-up, nobody stands down")
	pin(float(at) + 1.0)
	await seconds(1.0)
	check(war != null and war.state == "fight", "offline: the bell")
	await _leave(zone)
