extends Node3D
## The guild war together online (OnlineGuildWar, EntitySync, MirrorFighter), each side
## alone with a fake transport:
## - leader: going to war in a party sends gw_invite and holds the countdown; the answer
##   and the member's arrival send gw_start {seed, plan}; the leader hosts the fighters and
##   the gates (spawn events fit a frame), its rivals strike the member, the member's hits
##   land, the war's status and its end go out;
## - member: the invite prompt, yes -> gw_answer and the war is a mirror of the leader's:
##   no fighters of its own, mirrored fighters and gates take the hero's hits as ent_hit,
##   the leader's status, kills and bell show here and the result screen opens.
## godot --headless --path . res://tests/integration/online_guild_war_test.tscn
var checks := 0
var failures := 0
var fighter_spawn: Dictionary = {}
var gate_spawn: Dictionary = {}


class FakeLink:
	extends RefCounted
	var sent: Array = []
	var bytes: Array = []
	func send_text(text: String) -> void:
		sent.append(JSON.parse_string(text))
		bytes.append(text.to_utf8_buffer().size())
	func poll() -> Array:
		return []
	func frames(type: String) -> Array:
		return sent.filter(func(f): return f is Dictionary and String(f.get("t", "")) == type)
	func events(ev: String) -> Array:
		return frames("ent_event").filter(func(f): return String(f.get("ev", "")) == ev)


class RemoteDouble:
	extends Node3D
	func _init(id: String) -> void:
		set_meta("online_id", id)
		add_to_group("remote_players")
		# The real Online finds remote players by id in its own table.
		Online._remotes[id] = self


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


func _ready() -> void:
	await get_tree().process_frame
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GW Online")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.profile.party = []
	await _leader()
	await _member()
	Online.use_transport(null)
	print("ONLINE GUILD WAR: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func war_zone() -> Zone:
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	await frames(2)
	zone.hero.set_physics_process(false)
	return zone


func _leader() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Buddy", "user": "buddy", "zone": "town", "pos": [0, 0, 0], "hp": 9000, "max_hp": 9000, "anim": "idle"}],
		"party": {"id": "party1", "leader": "me", "members": ["me", "p2"]}})
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and not war.mirror, "leader: its own war")
	check(link.frames("gw_invite").size() == 1, "leader: going to war asks the party in (gw_invite)")
	check(war.hold, "leader: the countdown holds for the party")
	await seconds(0.5)
	check(war.state == "intro" and is_equal_approx(war._timer, GuildWarMatch.COUNTDOWN), "leader: no countdown while it waits")
	check(OnlineGuildWar.instance != null and is_instance_valid(OnlineGuildWar.instance), "the coordinator lives under the root")
	Online._dispatch({"t": "gw_answer", "from": "p2", "ok": true})
	await frames(3)
	check(link.frames("gw_start").is_empty() and war.hold, "leader: a yes, but the member is not in the war yet")
	Online._dispatch({"t": "state", "id": "p2", "zone": "guildwar", "pos": [war.hero.global_position.x, 0, war.hero.global_position.z]})
	await frames(3)
	var starts := link.frames("gw_start")
	check(starts.size() == 1 and not war.hold, "leader: the member arrived: gw_start, the countdown runs")
	if starts.size() == 1:
		check(int(starts[0].seed) == war.roll_seed and (starts[0].plan.members as Array) == ["p2"] and String(starts[0].plan.ally) == war.ally_name, "leader: gw_start carries the seed and the plan")
	# The leader hosts the war's fighters and gates.
	Online._dispatch({"t": "host", "zone": "guildwar", "id": "me"})
	zone.sync.update_mode()
	check(zone.sync.is_host(), "leader: hosts the war")
	await seconds(2.5)
	for i in link.sent.size():
		var f: Variant = link.sent[i]
		if f is Dictionary and String(f.get("t", "")) == "ent_event" and String(f.get("ev", "")) == "spawn":
			check(int(link.bytes[i]) < 8000, "leader: a spawn frame fits the 8 KB limit (%d bytes)" % int(link.bytes[i]))
			if (f.data as Dictionary).has("f") and int(f.data.team) == GuildFighter.TEAM_ENEMY and fighter_spawn.is_empty():
				fighter_spawn = f
			if (f.data as Dictionary).has("gate") and int(f.data.gate) == 0:
				gate_spawn = f
	check(not fighter_spawn.is_empty(), "leader: the rival fighters are described (look and gear)")
	check(not gate_spawn.is_empty(), "leader: the gates are shared too")
	var snaps := link.frames("ent_snap")
	check(not snaps.is_empty() and (snaps[-1].ents as Array).size() >= war.enemies.size(), "leader: snapshots cover the war")
	# Its rivals see the member as a victim; the member's hits land.
	var foe: GuildFighter = war.enemies[0]
	var buddy := RemoteDouble.new("p2")
	zone.add_child(buddy)
	buddy.global_position = foe.global_position + Vector3(-3, 0, 0)
	zone.sync.update_mode()
	check(foe._targets().has(buddy), "leader: a rival fighter can strike the member")
	foe._frozen = false
	foe._guard_until = 0
	foe._dodge = 0.0
	var before := foe.hp
	Online._dispatch({"t": "ent_hit", "zone": "guildwar", "eid": int(foe.get_meta("eid", 0)), "dmg": 300, "crit": false, "from": "p2"})
	check(foe.hp < before, "leader: the member's hit lands on the rival (%d -> %d)" % [before, foe.hp])
	link.sent.clear()
	foe._hit(buddy, 1.0, Color.WHITE)
	await seconds(0.3)
	check(link.events("hit").any(func(f): return String(f.data.to) == "p2"), "leader: a rival's blow on the member is sent to it")
	# The fight: the war's status goes out, a member's kill is a kill.
	war._timer = 0.01
	await seconds(1.4)
	check(war.state == "fight", "leader: the war began")
	var status := link.events("gw")
	check(not status.is_empty() and String(status[-1].data.st) == "fight", "leader: the war's status goes out")
	foe.hp = 5
	foe._guard_until = 0
	var score_before := war.score[0]
	link.sent.clear()
	Online._dispatch({"t": "ent_hit", "zone": "guildwar", "eid": int(foe.get_meta("eid", 0)), "dmg": 50, "crit": false, "from": "p2"})
	await seconds(0.3)
	check(foe.is_dead() and war.score[0] == score_before + 1, "leader: the member's kill scores for our guild")
	check(link.events("dead").any(func(f): return int(f.eid) == int(foe.get_meta("eid", 0)) and String(f.data.killer) == "p2"), "leader: the fall is sent with the member as killer")
	link.sent.clear()
	war._end()
	await seconds(0.3)
	var ends := link.events("gw_end")
	check(ends.size() == 1 and ends[0].data.has("won") and int(ends[0].data.us) == war.score[0], "leader: the bell goes out (gw_end)")
	await seconds(3.3)
	Online.use_transport(null)
	zone.queue_free()
	get_tree().paused = false
	await frames(3)


func _member() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "lead1", "name": "Captain", "user": "captain", "zone": "guildwar", "pos": [0, 0, 0], "hp": 9000, "max_hp": 9000}],
		"party": {"id": "party2", "leader": "lead1", "members": ["lead1", "me"]}})
	Game.current_zone = &"town"
	var coord := OnlineGuildWar.instance
	check(coord != null, "member: the coordinator is there")
	if coord == null:
		return
	Online._dispatch({"t": "gw_invite", "from": "p7"})
	check(coord.prompt == null, "member: an invite from someone who is not the leader is ignored")
	Online._dispatch({"t": "gw_invite", "from": "lead1"})
	check(coord.prompt != null and is_instance_valid(coord.prompt), "member: the leader's invite shows a prompt")
	coord.answer(true)
	var answers := link.frames("gw_answer")
	check(answers.size() == 1 and bool(answers[0].ok), "member: yes is sent (gw_answer)")
	check(coord.prompt == null, "member: the prompt closes")
	Online._dispatch({"t": "gw_start", "from": "lead1", "seed": 99, "plan": {"ally": "Alpha", "enemy": "Neverdie", "time": 1500.0, "members": ["me"]}})
	Online._dispatch({"t": "host", "zone": "guildwar", "id": "lead1"})
	var zone: Zone = await war_zone()
	var war := zone.gw_match
	check(war != null and war.mirror, "member: the war is a mirror of the leader's")
	if war == null or not war.mirror:
		return
	check(war.allies.is_empty() and war.enemies.is_empty() and get_tree().get_nodes_in_group("gw_fighters").is_empty(), "member: no fighters of its own")
	check(not war.hold and war.ally_name == "Alpha" and war.enemy_name == "Neverdie", "member: the leader's gw_start set the names and the countdown")
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "member: the war mirrors the leader's")
	# The leader's fighter and gate arrive.
	var spawn: Dictionary = fighter_spawn.duplicate(true)
	spawn["from"] = "lead1"
	spawn["eid"] = 501
	Online._dispatch(spawn)
	var gate: Dictionary = gate_spawn.duplicate(true)
	gate["from"] = "lead1"
	gate["eid"] = 601
	gate["data"]["hp"] = 1000
	Online._dispatch(gate)
	await frames(2)
	var mirror: MirrorFighter = zone.sync.mirrors.get(501)
	check(mirror != null and mirror.is_in_group("mobs") and war.enemies.has(mirror), "member: the rival fighter is mirrored as a foe")
	if mirror == null:
		return
	check(mirror._rv != null and String(fighter_spawn.data.f).contains(String(mirror.member.name)) and mirror.rival_name.contains(String(mirror.member.name)), "member: built from the leader's roster entry (model, name)")
	var g: CastleGate = war.gates[0]
	check(g.sync_eid == 601 and g.hp == 1000, "member: the front gate follows the leader's")
	link.sent.clear()
	mirror.take_hit(120, false, Color.WHITE, zone.hero)
	g.take_hit(80, false, Color.WHITE, zone.hero)
	await seconds(0.3)
	var outs := link.frames("ent_hit")
	check(outs.any(func(f): return int(f.eid) == 501 and int(f.dmg) == 120), "member: a hit on the fighter goes to the leader")
	check(outs.any(func(f): return int(f.eid) == 601 and int(f.dmg) == 80) and g.hp == 1000, "member: a hit on the gate goes to the leader, not on the local gate")
	# The leader's status.
	Online._dispatch({"t": "ent_event", "zone": "guildwar", "eid": 0, "ev": "gw", "from": "lead1", "data": {"st": "fight", "tl": GuildWarData.DURATION - 100.0, "s": [3, 2], "o": -1, "cp": [], "ot": false}})
	await frames(3)
	check(war.state == "fight" and war.score == [3, 2] and absf(war.time_left - (GuildWarData.DURATION - 100.0)) < 1.0, "member: clock, score and state follow the leader (%s %s %.1f)" % [war.state, str(war.score), war.time_left])
	# A kill by the hero; the fighter comes back with the leader's.
	Online._dispatch({"t": "ent_event", "zone": "guildwar", "eid": 501, "ev": "dead", "from": "lead1", "data": {"killer": "me", "share": {}}})
	check(mirror.is_dead() and war.hero_kills == 1, "member: the hero's kill counts")
	Online._dispatch({"t": "ent_snap", "zone": "guildwar", "from": "lead1", "ents": [[501, mirror.global_position.x, mirror.global_position.z, 0.0, mirror.max_hp, mirror.max_hp, 1]]})
	check(not mirror.is_dead(), "member: the fighter is back when the leader's is")
	Online._dispatch({"t": "ent_event", "zone": "guildwar", "eid": 601, "ev": "dead", "from": "lead1", "data": {"killer": "lead1", "share": {}}})
	check(g.is_dead(), "member: the gate breaks with the leader's")
	# A blow from the leader's rival.
	zone.hero.stats["dodge"] = 0.0
	var hp_before := int(Game.profile.hp)
	Online._dispatch({"t": "ent_event", "zone": "guildwar", "eid": 501, "ev": "hit", "from": "lead1", "data": {"to": "me", "dmg": 400}})
	check(int(Game.profile.hp) < hp_before, "member: the rival's blow hurts the hero")
	# The bell: the result screen for everyone.
	var results: Array = []
	zone.guildwar_finished.connect(func(r: Dictionary): results.append(r))
	Online._dispatch({"t": "ent_event", "zone": "guildwar", "eid": 0, "ev": "gw_end", "from": "lead1", "data": {"won": true, "us": 5, "them": 2, "castle": "Alpha", "ours": true, "ot": false}})
	check(war.state == "ending", "member: the leader's bell ends the war here")
	await seconds(3.4)
	check(results.size() == 1 and bool(results[0].won) and int(results[0].score_us) == 5 and int(results[0].kills) == 1, "member: the result (won, score, own kills) is shown")
	Online.use_transport(null)
	zone.queue_free()
	get_tree().paused = false
	await frames(3)
