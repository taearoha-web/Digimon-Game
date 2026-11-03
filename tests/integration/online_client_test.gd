extends Node
## The online client (Online, RemotePlayer, the chat and party pieces) without a network:
## a stand-in transport (use_transport) records what the game sends and Online._dispatch
## plays the server's frames. Checks the hello after connecting, the state throttle
## (changes at most 8 / 5 a second, a heartbeat every 2 s), welcome / join / state /
## leave turning into RemotePlayers that come, walk and go only in the hero's zone, a
## look rebuilding the body, the chat routing (world / party / whisper, the real-player
## mark, "/w name text", the server's copy of the hero's lines), the party frames
## (party, party_members_in_zone, zone_host, is_mirror_zone, invitations), a drop and a
## reconnect, the "เล่นออนไลน์" switch, and malformed frames changing nothing.
##   godot --headless --path . res://tests/integration/online_client_test.tscn

var checks := 0
var failures := 0
var zone: Zone
var hero: Hero
var toasts: Array = []
var signals := {}


class FakeTransport:
	extends RefCounted
	var sent: Array[String] = []
	var inbox: Array[String] = []
	var open := true
	var closed := false

	func send_text(text: String) -> void:
		sent.append(text)

	func poll() -> Array:
		var out := inbox.duplicate()
		inbox.clear()
		return out

	func is_open() -> bool:
		return open and not closed

	func is_closed() -> bool:
		return closed

	func frames(t: String) -> Array:
		var out: Array = []
		for text in sent:
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary and String(d.get("t", "")) == t:
				out.append(d)
		return out


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("  ok   ", message)


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	GameSettings.online_play = true
	GameSettings.quality = 2
	WorldPresence.enabled = false
	WorldPlayers.persist = false
	Online.set_process(false)
	Game.new_profile(&"mage", "ลูน่าออนไลน์", FaceKit.default_look())
	Game.playing = true
	Game.toast.connect(func(text: String, _k: StringName): toasts.append(text))
	for s in ["connected", "disconnected", "party_changed", "player_joined", "player_left", "host_changed"]:
		signals[s] = 0
		Online.connect(s, func(_a = null): signals[s] = int(signals[s]) + 1)
	zone = Zone.new()
	zone.zone_id = &"town"
	zone.layout_seed = 4242
	add_child(zone)
	if not zone.is_built:
		await zone.built
	hero = zone.hero
	hero.set_physics_process(false)
	await get_tree().process_frame
	check(Online._zone == zone, "the zone told Online it is built (zone_entered)")
	check(not Online.is_online() and Online.my_id() == "", "offline until a transport is given (headless)")
	Online.send("chat", {"ch": "world", "text": "x"})
	var fake := FakeTransport.new()
	await _hello(fake)
	_throttle(fake)
	await _players(fake)
	await _looks(fake)
	await _chat(fake)
	_party(fake)
	_malformed(fake)
	var fake2 := await _reconnect(fake)
	await _offline_switch(fake2)
	print("ONLINE CLIENT: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _tick(seconds: float, step := 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		Online._tick(step)
		t += step


func _hello(fake: FakeTransport) -> void:
	Online.use_transport(fake)
	check(Online.is_online(), "a given transport is online at once")
	check(int(signals.connected) == 1, "connected is emitted")
	var hellos := fake.frames("hello")
	check(hellos.size() == 1 and fake.sent.size() == 1, "the first frame is one hello")
	if hellos.is_empty():
		return
	var h: Dictionary = hellos[0]
	for key in ["name", "cls", "level", "stars", "look", "zone", "pos", "yaw", "hp", "max_hp", "mount"]:
		check(h.has(key), "hello has %s" % key)
	check(h.name == "ลูน่าออนไลน์" and h.cls == "mage" and int(h.level) == 1 and h.zone == "town", "hello: name, class, level and zone")
	check(h.pos is Array and (h.pos as Array).size() == 3 and absf(float(h.pos[0]) - hero.global_position.x) < 0.02, "hello: the hero's position [x, y, z]")
	check(int(h.max_hp) >= int(h.hp) and int(h.hp) > 0, "hello: hp and max_hp")
	var look: Dictionary = h.look
	var own := PlayerLook.of_profile(Game.profile)
	check(look.get("class") == "mage" and look.has("face") and look.has("equip") and look.has("wing_mode"), "hello: the look (PlayerLook: class, face, equip, wing pose)")
	check((look.equip as Dictionary).keys() == own.equip.keys() and (look.equip as Dictionary).has("weapon"), "hello: the worn pieces of the hero (Game.hero_look)")
	check(not (look.equip.weapon as Dictionary).has("stats") and (look.equip.weapon as Dictionary).has("uid"), "the wire look leaves the stats out, keeps what the look reads")
	check(JSON.stringify(h).to_utf8_buffer().size() < OnlineSocket.MAX_FRAME, "hello fits in a frame")


func _throttle(fake: FakeTransport) -> void:
	fake.sent.clear()
	# Standing still: only the heartbeat, every 2 s.
	_tick(0.5)
	var first := fake.frames("state").size()
	fake.sent.clear()
	_tick(4.1)
	check(fake.frames("state").size() == 2, "still: a heartbeat every 2 s (%d in 4.1 s)" % fake.frames("state").size())
	# Moving every frame: at most 8 a second (high quality).
	GameSettings.quality = 2
	check(is_equal_approx(Online.state_rate(), 8.0), "8 states a second on a desktop at high quality")
	fake.sent.clear()
	for k in 60:
		hero.global_position += Vector3(0.05, 0, 0)
		Online._tick(1.0 / 60.0)
	var n := fake.frames("state").size()
	check(n >= 7 and n <= 9, "moving: about 8 states a second (%d)" % n)
	GameSettings.quality = 0
	check(is_equal_approx(Online.state_rate(), 5.0), "5 a second on low quality (phones too)")
	fake.sent.clear()
	for k in 60:
		hero.global_position += Vector3(0.05, 0, 0)
		Online._tick(1.0 / 60.0)
	n = fake.frames("state").size()
	check(n >= 4 and n <= 6, "moving on low quality: about 5 a second (%d)" % n)
	GameSettings.quality = 2
	var s: Dictionary = fake.frames("state").back()
	for key in ["pos", "yaw", "anim", "hp", "max_hp", "zone", "mount"]:
		check(s.has(key), "state has %s" % key)
	check(s.anim == "run" or s.anim == "idle", "anim is idle / run while walking (%s)" % s.anim)
	check(first <= 1, "no burst of states after hello (%d)" % first)
	# A skill: anim "skill:<id>" for a moment.
	hero.last_cast_id = "fireball"
	Online._on_skill(0)
	fake.sent.clear()
	_tick(0.2)
	var skill_states := fake.frames("state").filter(func(d): return String(d.anim).begins_with("skill:"))
	check(not skill_states.is_empty() and skill_states[0].anim == "skill:fireball", "a cast sends anim skill:<id>")
	_tick(1.0)


func _player(id: String, name: String, zone_id: String, pos: Vector3, cls := "warrior") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var equip := {"weapon": ItemData.generate(30, StringName(cls), rng, 2, "weapon"), "armor": ItemData.generate(30, StringName(cls), rng, 1, "armor")}
	var look := {"class": cls, "adv": 1, "face": FaceKit.default_look(), "equip": PlayerLook.wire_equip(equip), "wing_mode": 0, "level": 30, "stars": 0}
	return {"id": id, "user": "u_" + id, "name": name, "cls": cls, "level": 30, "stars": 0, "look": look, "zone": zone_id,
		"pos": [pos.x, pos.y, pos.z], "yaw": 0.0, "hp": 900, "max_hp": 1000, "mount": "", "party": null}


func _remotes() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("remote_players"):
		if not node.is_queued_for_deletion():
			out.append(node)
	return out


func _players(fake: FakeTransport) -> void:
	var at := hero.global_position
	Online._dispatch({"t": "welcome", "you": {"id": "me1", "user": "luna"}, "party": null,
		"players": [_player("p2", "Kaito", "town", at + Vector3(3, 0, 0)), _player("p3", "Mira", "meadow", Vector3(5, 0, 5), "priest")]})
	check(Online.my_id() == "me1", "welcome: my id")
	check(Online.players().size() == 2 and Online.players().has("p2") and Online.players().has("p3"), "welcome: the players")
	check(Online.players_in_zone(&"town").size() == 1 and Online.players_in_zone(&"meadow").size() == 1, "players_in_zone")
	var r2 := Online.remote_node("p2") as RemotePlayer
	check(r2 != null and r2.get_parent() == zone, "a player in the hero's zone is a RemotePlayer in it")
	check(Online.remote_node("p3") == null, "a player in another zone is not shown")
	check(_remotes().size() == 1, "one RemotePlayer")
	if r2 == null:
		return
	check(r2.is_in_group("remote_players") and not r2.is_in_group("world_players") and not r2.is_in_group("mobs") and not r2.is_in_group("companions"),
		"a real player is not a world player, a monster or a companion")
	check(not (r2 as Node is Mob) and not (r2 as Node is FieldPlayer), "the hero's attacks (mobs only) never reach it")
	check(r2.position.distance_to(at + Vector3(3, 0, 0)) < 0.01, "it stands where its player is")
	check(r2.visual != null and r2.visual.class_id == &"warrior" and r2.visual.equip.has("weapon"), "dressed from its look: class and gear")
	check(r2._label.text.contains("Kaito") and r2._tag.text == "ผู้เล่นจริง", "name tag and the ผู้เล่นจริง mark")
	check(r2._bar.visible and r2.hp == 900, "HP bar (hurt)")
	# join: in the zone it comes, elsewhere not.
	Online._dispatch({"t": "join", "player": _player("p4", "Nok", "town", at + Vector3(-3, 0, 2), "archer")})
	Online._dispatch({"t": "join", "player": _player("p5", "Far", "desert", Vector3.ZERO)})
	check(Online.remote_node("p4") != null and Online.remote_node("p5") == null, "join: only the same zone's player appears")
	check(int(signals.player_joined) >= 4, "player_joined for each")
	# state: it walks, ~100 ms behind.
	var goal := at + Vector3(3, 0, 4)
	Online._dispatch({"t": "state", "id": "p2", "pos": [goal.x, goal.y, goal.z], "yaw": 1.0, "anim": "run", "hp": 1000, "max_hp": 1000, "zone": "town", "mount": ""})
	check(r2.anim == "run" and r2.hp == 1000, "state: anim and hp")
	check(r2.position.distance_to(goal) > 0.5, "it does not jump to the new spot at once")
	await get_tree().create_timer(0.45).timeout
	check(r2.position.distance_to(goal) < 0.05, "it walked to the new spot (%.2f m left)" % r2.position.distance_to(goal))
	# the interpolation itself
	var r4 := Online.remote_node("p4") as RemotePlayer
	r4._snap_n = 0
	r4.push_snapshot(Vector3(0, 0, 0), 0.0, 10.0)
	r4.push_snapshot(Vector3(1, 0, 0), 0.0, 10.125)
	check(r4.sample(10.0625).distance_to(Vector3(0.5, 0, 0)) < 0.01, "halfway between two states halfway in time")
	r4.push_snapshot(Vector3(1, 0, 0), 0.0, 10.25)
	r4.push_snapshot(Vector3(2, 0, 0), 0.0, 12.0)
	check(r4.sample(11.875 - 0.0001).distance_to(Vector3(1, 0, 0)) < 0.01 and r4.sample(12.0).distance_to(Vector3(2, 0, 0)) < 0.01,
		"after a pause it starts walking one send interval before the new state")
	r4.push_snapshot(Vector3(80, 0, 0), 0.0, 12.1)
	check(r4.position.distance_to(Vector3(80, 0, 0)) < 0.01 and r4.snapshot_count() == 1, "a warp is not walked")
	# other animations
	Online._dispatch({"t": "state", "id": "p2", "anim": "attack"})
	check(r2.anim == "attack" and r2.visual.busy_until > Time.get_ticks_msec(), "attack plays a swing")
	Online._dispatch({"t": "state", "id": "p2", "anim": "skill:fireball"})
	check(r2.anim == "skill:fireball", "a skill anim")
	Online._dispatch({"t": "state", "id": "p2", "anim": "dead", "hp": 0})
	check(r2.is_dead() and r2.visual.current == "Death_A", "dead: it falls")
	Online._dispatch({"t": "state", "id": "p2", "anim": "idle", "hp": 500})
	check(not r2.is_dead(), "back up")
	Online._dispatch({"t": "state", "id": "p2", "mount": "thunder_wolf"})
	check(r2.is_riding(), "it rides its mount")
	Online._dispatch({"t": "state", "id": "p2", "mount": ""})
	check(not r2.is_riding(), "and gets off")
	# zone changes: p3 comes into town, p2 goes to the meadow.
	Online._dispatch({"t": "state", "id": "p3", "zone": "town", "pos": [at.x + 1, at.y, at.z + 1]})
	check(Online.remote_node("p3") != null, "a player arriving in the zone appears")
	Online._dispatch({"t": "state", "id": "p2", "zone": "meadow", "pos": [0, 0, 0]})
	check(Online.remote_node("p2") == null, "a player leaving the zone goes")
	# leave
	var left_before := int(signals.player_left)
	Online._dispatch({"t": "leave", "id": "p4"})
	check(Online.remote_node("p4") == null and not Online.players().has("p4") and int(signals.player_left) == left_before + 1, "leave: gone")
	await get_tree().process_frame
	check(_remotes().size() == 1, "only p3 is shown now (%d)" % _remotes().size())
	Online._dispatch({"t": "state", "id": "p2", "zone": "town", "pos": [at.x + 3, at.y, at.z]})
	check(Online.remote_node("p2") != null, "p2 back in town")
	# A message is emitted for every frame.
	var seen: Array = []
	var cb := func(type: String, _d: Dictionary): seen.append(type)
	Online.message.connect(cb)
	Online._dispatch({"t": "trade_req", "from": "p2"})
	Online._dispatch({"t": "something_new", "x": 1})
	Online.message.disconnect(cb)
	check(seen == ["trade_req", "something_new"], "message(type, data) for every frame, unknown ones too")


func _looks(_fake: FakeTransport) -> void:
	var r2 := Online.remote_node("p2") as RemotePlayer
	if r2 == null:
		check(false, "p2 shown for the look checks")
		return
	var visual_before := r2.visual.model
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var helm := ItemData.generate(40, &"warrior", rng, 3, "helm")
	helm["plus"] = 7
	var look: Dictionary = (Online.players().p2.look as Dictionary).duplicate(true)
	look.equip["helm"] = PlayerLook.wire_equip({"helm": helm}).helm
	Online._dispatch({"t": "look", "id": "p2", "look": look, "level": 31, "stars": 0})
	check(r2.visual.equip.has("helm") and int(r2.visual.equip.helm.plus) == 7, "look: a new piece is put on (with its plus)")
	check(r2.visual.model == visual_before, "a new piece re-dresses, the body stays")
	check(r2._label.text.contains("Lv.31"), "the new level shows")
	look = look.duplicate(true)
	look["class"] = "mage"
	look.equip = {}
	Online._dispatch({"t": "look", "id": "p2", "look": look})
	await get_tree().process_frame
	check(r2.visual.class_id == &"mage", "a new class rebuilds the body")
	# The same look code as a FieldPlayer: a world player's look dresses the same way.
	var m := WorldPlayers.member(3, WorldPlayers.START_UNIX + 90 * 86400.0)
	var wl := PlayerLook.of_member(m, 3)
	var clean := PlayerLook.clean(wl)
	check(String(clean["class"]) == String(m["class"]) and clean.equip.keys() == WorldPlayers.equip(m).keys(), "a world player's look survives the network check (PlayerLook.clean)")
	var v := HeroVisual.new()
	add_child(v)
	PlayerLook.dress(v, clean)
	check(v.class_id == StringName(m["class"]) and v.equip.keys() == WorldPlayers.equip(m).keys() and v.chibi, "dressed exactly like the FieldPlayer (class, gear, chibi face)")
	v.queue_free()


func _chat(fake: FakeTransport) -> void:
	var box := WorldChat.new()
	add_child(box)
	var chat := AiChat.new()
	add_child(chat)
	chat.set_process(false)
	(chat.transport as ChatBrain.LocalTransport).delay = Vector2.ZERO
	Online._dispatch({"t": "chat", "ch": "world", "from": "p2", "user": "u_p2", "name": "Kaito", "text": "สวัสดีชาวโลก [b]x[/b]"})
	var line := String(box.lines()[box.lines().size() - 1]) if box.lines().size() > 0 else ""
	check(line.contains("Kaito") and line.contains("ผู้เล่นจริง") and line.contains("rp:p2") and line.contains("สวัสดีชาวโลก"), "a real player's world line, with the mark and a link")
	check(not line.contains("[b]"), "brackets in a line never open a tag")
	var tapped := []
	box.real_name_tapped.connect(func(id: String): tapped.append(id))
	box._on_meta("rp:p2")
	check(tapped == ["p2"], "tapping the name: whisper to that player")
	Online._dispatch({"t": "chat", "ch": "party", "from": "p3", "name": "Mira", "text": "ไปกันเลย"})
	box.set_tab("party")
	check(box.lines().size() == 1 and String(box.lines()[0]).contains("ไปกันเลย") and String(box.lines()[0]).contains("ปาร์ตี้"), "a party line on the party tab")
	box.set_tab("all")
	Online._dispatch({"t": "chat", "ch": "whisper", "from": "p3", "name": "Mira", "to": "me1", "text": "กระซิบนะ"})
	line = String(box.lines()[box.lines().size() - 1])
	check(line.contains("กระซิบ") and line.contains("กระซิบนะ"), "a whisper to the hero, tagged")
	var count := box.history().size()
	Online._dispatch({"t": "chat", "ch": "world", "from": "me1", "name": "ลูน่าออนไลน์", "text": "ของฉันเอง"})
	check(box.history().size() == count, "the server's copy of the hero's world line is not shown twice")
	# The hero types.
	fake.sent.clear()
	var why := chat.submit("/w Kaito ไปล่าบอสไหม", {"index": -1, "channel": "world"})
	var whispers := fake.frames("chat")
	check(why == "" and whispers.size() == 1 and whispers[0].ch == "whisper" and whispers[0].to == "p2" and whispers[0].text == "ไปล่าบอสไหม", "\"/w name text\" whispers to that real player")
	Online._dispatch({"t": "chat", "ch": "whisper", "from": "me1", "name": "ลูน่าออนไลน์", "to": "p2", "text": "ไปล่าบอสไหม"})
	check(String(box.lines()[box.lines().size() - 1]).contains("(ถึง Kaito)"), "the hero's whisper shows when it comes back")
	fake.sent.clear()
	chat.submit("ไม่มีใครชื่อนี้", {"index": -1, "channel": "whisper", "to": "nobody", "name": "ใครสักคน"})
	check(fake.frames("chat").is_empty(), "no whisper to someone not online")
	fake.sent.clear()
	why = chat.submit("สวัสดีทุกคน", {"index": -1, "channel": "world"})
	var worlds := fake.frames("chat")
	check(worlds.size() == 1 and worlds[0].ch == "world" and worlds[0].text == "สวัสดีทุกคน", "a world line goes to the real players too")
	check(box.history()[box.history().size() - 1].contains("สวัสดีทุกคน"), "and shows at once beside the world players'")
	fake.sent.clear()
	why = chat.submit("ทุกคนพร้อมไหม", {"index": -1, "channel": "party"})
	check(why == AiChat.NO_PARTY and fake.frames("chat").is_empty(), "no party at all: the note, nothing sent")
	Online._dispatch({"t": "party", "party": {"id": "pt1", "leader": "me1", "members": ["me1", "p2"]}})
	fake.sent.clear()
	why = chat.submit("ทุกคนพร้อมไหม", {"index": -1, "channel": "party"})
	var party_lines := fake.frames("chat")
	check(why == "" and party_lines.size() == 1 and party_lines[0].ch == "party", "with a real party: the party line is sent")
	Online._dispatch({"t": "party", "party": null})
	box.queue_free()
	chat.queue_free()


func _party(fake: FakeTransport) -> void:
	toasts.clear()
	var changed := int(signals.party_changed)
	Online._dispatch({"t": "party", "party": {"id": "pt9", "leader": "me1", "members": ["me1", "p2", "p3"]}})
	check(Online.in_party() and Online.party().leader == "me1" and Online.party().members == ["me1", "p2", "p3"], "party(): the party")
	check(int(signals.party_changed) == changed + 1, "party_changed")
	check(toasts.any(func(t): return String(t).contains("ปาร์ตี้")), "a toast says so (%s)" % [toasts])
	Online._dispatch({"t": "state", "id": "p3", "zone": "meadow"})
	check(Online.party_members_in_zone(&"town") == ["p2"] and Online.party_members_in_zone(&"meadow") == ["p3"], "party_members_in_zone (me excluded)")
	check((Online.remote_node("p2") as RemotePlayer).in_party, "a member's RemotePlayer shows it")
	# The HUD: the real party's cards (never more cards than Game.PARTY_MAX in all).
	var hud := HUD.new()
	add_child(hud)
	hud.bind(zone)
	hud._update_party()
	hud.update_online()
	var shown: Array = hud._online_cards.filter(func(e): return (e.card as Control).visible)
	check(shown.size() == 2 and String((shown[0].title as Label).text).contains("Kaito"), "the HUD shows the real party's cards")
	var all_cards := shown.size() + hud._party_cards.filter(func(e): return (e.card as Control).visible).size()
	check(all_cards <= Game.PARTY_MAX, "never more party cards than the phone layout holds (%d)" % all_cards)
	check(String(hud._online_label.text) == "ออนไลน์ %d" % (WorldPresence.online_count() + 1 + Online.players().size()), "the online count has the real players")
	check((shown[0].kick as Control).visible, "the leader may let a member go")
	hud.queue_free()
	# The online list: whisper, invite, trade and duel buttons.
	var screen := OnlineScreen.new()
	add_child(screen)
	var whispered := []
	screen.whisper_requested.connect(func(id: String): whispered.append(id))
	screen.open_player("p3")
	var rows := screen._body.find_child("Players", true, false)
	check(rows != null and rows.get_child_count() == Online.players().size(), "one row per real player")
	var first := rows.get_child(0) if rows != null else null
	check(first != null and first.name == "Row_p3", "the tapped player is listed first")
	fake.sent.clear()
	for b in ["Trade", "Duel"]:
		var button := first.find_child(b, true, false) as Button
		if button != null:
			button.pressed.emit()
	check(fake.frames("trade_req").size() == 1 and fake.frames("trade_req")[0].to == "p3", "ขอแลกของ sends trade_req")
	check(fake.frames("duel_req").size() == 1 and fake.frames("duel_req")[0].to == "p3", "ท้าดวล sends duel_req")
	var kick := first.find_child("Kick", true, false) as Button
	check(kick != null, "the leader sees เชิญออก for a member")
	(first.find_child("Whisper", true, false) as Button).pressed.emit()
	check(whispered == ["p3"] and not screen.is_open, "กระซิบ opens the whisper bar")
	screen.queue_free()
	var hosts := int(signals.host_changed)
	Online._dispatch({"t": "host", "zone": "town", "id": "me1"})
	check(Online.zone_host(&"town") == "me1" and Online.is_zone_host(&"town") and not Online.is_mirror_zone(&"town"), "the hero hosts the town")
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p3"})
	check(Online.zone_host(&"meadow") == "p3" and Online.is_mirror_zone(&"meadow") and not Online.is_zone_host(&"meadow"), "someone else hosts the meadow: a mirror zone")
	Online._dispatch({"t": "host", "zone": "meadow", "id": null})
	check(Online.zone_host(&"meadow") == "" and not Online.is_mirror_zone(&"meadow"), "nobody shares: play alone")
	check(int(signals.host_changed) == hosts + 3, "host_changed each time")
	toasts.clear()
	Online._dispatch({"t": "party", "party": {"id": "pt9", "leader": "me1", "members": ["me1", "p2"]}})
	check(toasts.any(func(t): return String(t).contains("Mira") and String(t).contains("ออก")), "a member leaving: a toast")
	toasts.clear()
	Online._dispatch({"t": "leave", "id": "p2"})
	check(toasts.any(func(t): return String(t).contains("Kaito")), "a party member logging off: a toast")
	Online._dispatch({"t": "join", "player": _player("p2", "Kaito", "town", hero.global_position + Vector3(2, 0, 0))})
	Online._dispatch({"t": "party", "party": null})
	check(not Online.in_party() and Online.party().is_empty() and Online.zone_host(&"town") == "", "party null: no party, no hosts")
	# An invitation and its answer (the card at the top).
	var prompt := OnlinePrompt.new()
	add_child(prompt)
	toasts.clear()
	Online._dispatch({"t": "party_invite", "from": "p2", "name": "Kaito"})
	check(Online.pending_invite().get("from") == "p2" and toasts.any(func(t): return String(t).contains("ชวน")), "an invitation waits, with a toast")
	check(prompt.is_showing() and prompt._text.text.contains("Kaito"), "the invitation card shows")
	fake.sent.clear()
	prompt.answer(true)
	check(not prompt.is_showing(), "answered: the card goes")
	prompt.queue_free()
	# The screen's invite button.
	var screen2 := OnlineScreen.new()
	add_child(screen2)
	screen2.open_screen()
	var invite := screen2._body.find_child("Row_p2", true, false).find_child("Invite", true, false) as Button
	invite.pressed.emit()
	check(fake.frames("party_invite").size() == 1 and fake.frames("party_invite")[0].to == "p2", "ชวนเข้าปาร์ตี้ sends party_invite")
	screen2.queue_free()
	Online._dispatch({"t": "party_answer", "from": "p2", "ok": false})
	check(toasts.any(func(t): return String(t).contains("ปฏิเสธ")), "a declined invitation is told")
	var answers := fake.frames("party_answer")
	check(answers.size() == 1 and answers[0].from == "p2" and answers[0].ok == true and Online.pending_invite().is_empty(), "party_answer sent")
	toasts.clear()
	Online._dispatch({"t": "error", "code": "full", "text": "ปาร์ตี้เต็มแล้ว"})
	check(toasts.has("ปาร์ตี้เต็มแล้ว"), "an error is shown in Thai")


func _malformed(fake: FakeTransport) -> void:
	var before := Online.players().size()
	var bad: Array = [{}, {"t": ""}, {"t": 5}, {"t": "join"}, {"t": "join", "player": 5}, {"t": "join", "player": {"id": [1]}},
		{"t": "leave", "id": {}}, {"t": "state", "id": [1]}, {"t": "state", "id": "p2", "pos": "x", "hp": "y", "yaw": "z", "anim": 4, "mount": 3, "zone": 9},
		{"t": "state", "id": "p2", "pos": [1, "a", null]}, {"t": "state", "id": "nobody", "pos": [0, 0, 0]},
		{"t": "look", "id": "p2", "look": {"class": "bogus", "face": {"gender": [1], "hair": 99999}, "equip": {"weapon": {"kind": "equip", "slot": "armor"}, "armor": [1],
			"helm": {"kind": "equip", "slot": "helm", "level": "abc"}, "boots": {"kind": "equip", "slot": "boots", "name": 5, "base": "boots", "level": 3}, "ring": "x"}}},
		{"t": "look", "id": "p2", "look": "nope"}, {"t": "players", "players": "no"},
		{"t": "party", "party": {"members": "x"}}, {"t": "party", "party": 7}, {"t": "host", "zone": 5}, {"t": "host"},
		{"t": "chat", "ch": "world", "from": "p2", "text": 5}, {"t": "chat", "ch": 3}, {"t": "party_invite"}, {"t": "welcome", "players": "no", "you": 3},
		{"t": "error", "text": {}}, {"t": "state", "id": "p2", "pos": [1e40, 0, 0]}]
	for b in bad:
		Online._dispatch(b)
	fake.inbox.append_array(["not json", "[1,2]", "{\"t\":", "\"str\"", "{\"t\":\"leave\",\"id\":null}"])
	Online._tick(0.016)
	check(Online.is_online(), "still online after malformed frames")
	var r2 := Online.remote_node("p2") as RemotePlayer
	check(r2 != null and r2.position.is_finite(), "the RemotePlayer is still fine")
	check(r2 != null and r2.visual.class_id == &"vagabond" and r2.visual.equip.is_empty(), "a broken look becomes the plain default (%s)" % [r2.visual.equip.keys() if r2 else []])
	check(Online.players().size() == before, "no junk player was added, nobody lost")
	# A full list of junk: nobody valid is online (the list replaces the old one).
	Online._dispatch({"t": "players", "players": [1, "a", null, {"id": {}}]})
	check(Online.players().is_empty() and Online.is_online(), "a list of junk: no players, still online")
	Online._dispatch({"t": "join", "player": _player("p2", "Kaito", "town", hero.global_position + Vector3(2, 0, 0))})
	Online._dispatch({"t": "join", "player": _player("p3", "Mira", "town", hero.global_position + Vector3(-2, 0, 0), "priest")})


func _reconnect(fake: FakeTransport) -> FakeTransport:
	check(_remotes().size() >= 1, "players shown before the drop")
	var drops := int(signals.disconnected)
	fake.closed = true
	Online._tick(0.016)
	await get_tree().process_frame
	check(not Online.is_online() and int(signals.disconnected) == drops + 1, "a closed socket: disconnected")
	check(_remotes().is_empty() and Online.players().is_empty() and Online.my_id() == "", "the drop clears everyone off the screen")
	check(Online._retry_in >= 2.0, "the next try waits the backoff (%.1f s)" % Online._retry_in)
	check(OnlineSocket.delay_for(0) == 2.0 and OnlineSocket.delay_for(3) == 16.0 and OnlineSocket.delay_for(9) == 30.0, "backoff 2, 4, 8, 16, 30 s")
	var fake2 := FakeTransport.new()
	Online.use_transport(fake2)
	check(Online.is_online() and fake2.frames("hello").size() == 1, "reconnected: hello again")
	Online._dispatch({"t": "welcome", "you": {"id": "me1", "user": "luna"}, "party": null,
		"players": [_player("p2", "Kaito", "town", hero.global_position + Vector3(3, 0, 0))]})
	check(_remotes().size() == 1 and Online.remote_node("p2") != null, "after the welcome the players are back")
	# Kicked (another tab took over): gone, and no automatic return.
	var fake3 := FakeTransport.new()
	Online.use_transport(fake3)
	toasts.clear()
	Online._dispatch({"t": "kicked", "reason": "elsewhere"})
	check(not Online.is_online() and Online._kicked and toasts.any(func(t): return String(t).contains("ที่อื่น")), "kicked: offline, told why, no reconnecting")
	Online.use_transport(fake2)
	Online._dispatch({"t": "welcome", "you": {"id": "me1", "user": "luna"}, "party": null,
		"players": [_player("p2", "Kaito", "town", hero.global_position + Vector3(3, 0, 0))]})
	return fake2


func _offline_switch(fake: FakeTransport) -> void:
	check(Online.is_online() and _remotes().size() == 1, "online again before the switch")
	Online.set_enabled(false)
	await get_tree().process_frame
	check(not GameSettings.online_play and not Online.is_online(), "the switch off: offline")
	check(_remotes().is_empty(), "the switch off: nobody else on screen")
	var n := fake.sent.size()
	Online.send("chat", {"ch": "world", "text": "hello"})
	check(fake.sent.size() == n, "send is a no-op offline")
	Online.use_transport(FakeTransport.new())
	check(not Online.is_online(), "no connection while switched off")
	Online.set_enabled(true)
	check(GameSettings.online_play, "the switch back on")
	var again := FakeTransport.new()
	Online.use_transport(again)
	check(Online.is_online(), "connects again when switched on")
	Online.use_transport(null)
	check(not Online.is_online(), "use_transport(null) drops")
