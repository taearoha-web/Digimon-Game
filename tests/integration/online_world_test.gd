extends Node3D
## The shared world online (WorldPresence, FieldPlayer puppets; docs/ONLINE_PROTOCOL.md
## "Shared world"), each side alone with a fake transport (no network):
## - offline: the field's own world players hunt, the world chat is made here, nothing
##   goes out;
## - host: another real player in the zone: `wp_snap` lists the zone's players near it
##   (roster index, x, z, yaw, anim, flags), a cast goes out as `wp_event skill` with the
##   target's eid, a bubble as `wp_event bubble`, a player leaving as `wp_event leave`;
##   the world host sends its world-chat lines as `ai_chat`;
## - mirror: someone else hosts: no own world players, the snapshot's players come as
##   puppets dressed from their roster index, glide between snapshots, ride, cast at the
##   mirrored monster, bubble, and leave when no longer listed; the world chat is not
##   made here, the world host's `ai_chat` lines are shown (with a bubble);
## - the host role comes here: the puppets carry on as ordinary world players where they
##   stand; the link drops: the same, and the world chat is made here again.
## godot --headless --path . res://tests/integration/online_world_test.tscn
var checks := 0
var failures := 0
var world_lines: Array = []
var place: StringName = &""
## World players scheduled in `place` at the test's moment.
var here: Array[int] = []


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
		return frames("wp_event").filter(func(f): return String(f.get("ev", "")) == ev)


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
	GameSettings.show_world_players = true
	GameSettings.quality = 2
	WorldPlayers.persist = false
	WorldPresence.enabled = true
	Game.new_profile(&"warrior", "Online World QA", FaceKit.default_look())
	Game.profile.level = 30
	Game.profile.party = []
	Game.profile.hp = Game.stats_now().max_hp
	Game.world_chat.connect(func(speaker: String, text: String, _c: Color): world_lines.append([speaker, text]))
	_find_moment()
	check(here.size() >= 3, "a field with at least three world players (%s: %d)" % [place, here.size()])
	if here.size() >= 3:
		await _offline()
		await _host()
		await _mirror()
	Online.use_transport(null)
	WorldPresence.clock_offset = 0.0
	print("ONLINE WORLD: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


## A moment when some hunting field has three or more scheduled world players.
func _find_moment() -> void:
	for h in 24 * 30:
		var t := float(WorldPlayers.START_UNIX) + 30.0 * 86400.0 + h * 3600.0
		var count := {}
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if not bool(s.online) or Game.in_party(i):
				continue
			var z := StringName(s.place)
			var d := ZoneData.get_zone(z)
			if d.is_empty() or bool(d.get("safe", false)) or bool(d.get("pvp", false)) or bool(d.get("tower", false)) or bool(d.get("arena", false)):
				continue
			if not count.has(z):
				count[z] = []
			(count[z] as Array).append(i)
		for z in count:
			if (count[z] as Array).size() >= 3:
				WorldPresence.clock_offset = t - WorldPlayers.now()
				place = z
				here.assign(count[z])
				return


func make_zone() -> Zone:
	Game.current_zone = place
	var zone := Zone.new()
	zone.zone_id = place
	zone.layout_seed = 777
	add_child(zone)
	while not zone.is_built:
		await get_tree().process_frame
	await frames(3)
	zone.hero.set_physics_process(false)
	return zone


func own_players() -> Array:
	return get_tree().get_nodes_in_group("world_players").filter(func(n): return n is FieldPlayer and not (n as FieldPlayer).puppet and not n.is_queued_for_deletion())


func puppets(zone: Zone) -> Dictionary:
	var out := {}
	for i in zone.presence.shown:
		var p: Variant = zone.presence.shown[i]
		if p != null and is_instance_valid(p) and (p as FieldPlayer).puppet and not (p as Node).is_queued_for_deletion():
			out[i] = p
	return out


func welcome(link: FakeLink, host: String, whost: String) -> void:
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Buddy", "user": "buddy", "zone": String(place), "pos": [0, 0, 0], "hp": 500, "max_hp": 500, "anim": "idle"}],
		"party": {"id": "party1", "leader": host, "members": ["me", "p2"]}})
	Online._dispatch({"t": "whost", "id": whost})
	Online._dispatch({"t": "host", "zone": String(place), "id": host})


## Offline and solo: the field's own players, the chat made here, nothing sent.
func _offline() -> void:
	var zone: Zone = await make_zone()
	check(zone.presence != null and zone.presence.mode == WorldPresence.LOCAL, "offline: the world players are this game's own")
	check(own_players().size() >= 3, "offline: the scheduled players hunt here (%d)" % own_players().size())
	check(puppets(zone).is_empty(), "offline: no puppets")
	check(not WorldPresence.world_chat_relayed(), "offline: the world chat is made here")
	world_lines.clear()
	WorldPresence.chat_clock_override = 10000.0
	zone.presence._posted.clear()
	zone.presence._quiet_until = -1.0
	for k in 6:
		zone.presence.chat_once()
		WorldPresence.chat_clock_override += 20.0
	WorldPresence.chat_clock_override = -1.0
	check(world_lines.size() >= 1, "offline: the players talk in the world chat (%d)" % world_lines.size())
	zone.queue_free()
	await frames(3)


## The host side: this game runs the players and tells the other real player.
func _host() -> void:
	var link := FakeLink.new()
	welcome(link, "me", "me")
	var zone: Zone = await make_zone()
	var wp := zone.presence
	check(wp.mode == WorldPresence.HOST, "host: another real player here makes this game the zone host (%d)" % wp.mode)
	var mine := own_players()
	check(mine.size() >= 3, "host: its own players hunt here (%d)" % mine.size())
	if mine.is_empty():
		return
	# The other real player stands by the first of them.
	var near := mine[0] as FieldPlayer
	Online._dispatch({"t": "state", "id": "p2", "zone": String(place), "pos": [near.global_position.x, 0.0, near.global_position.z], "yaw": 0.0, "anim": "idle", "hp": 500, "max_hp": 500})
	await seconds(0.7)
	var snaps := link.frames("wp_snap")
	check(snaps.size() >= 2, "host: snapshots go out about 4 a second (%d)" % snaps.size())
	if snaps.is_empty():
		return
	var last: Dictionary = snaps[-1]
	check(String(last.get("zone", "")) == String(place), "host: the snapshot names the zone")
	var rows: Array = last.get("ps", [])
	check(rows.size() >= 1 and rows.size() <= WorldPresence.WP_CAP, "host: the zone's players near the other player are listed (%d)" % rows.size())
	var by_index := {}
	for r in rows:
		by_index[int(r[0])] = r
	check(by_index.has(near.world_index), "host: the player beside the other real player is in it")
	var p2: Vector3 = Online.remote_node("p2").global_position if Online.remote_node("p2") != null else near.global_position
	for i in wp.shown:
		var f := wp.shown[i] as FieldPlayer
		if f == null or not is_instance_valid(f) or not f.on_wire():
			continue
		var far := Vector2(f.global_position.x - p2.x, f.global_position.z - p2.z).length() > WorldPresence.WP_NEAR + 3.0
		if far:
			check(not by_index.has(i), "host: a player far from every real player is left out (%d)" % i)
	if by_index.has(near.world_index):
		var row: Array = by_index[near.world_index]
		check(row.size() == 6, "host: a row is [index, x, z, yaw, anim, flags]")
		check(absf(float(row[1]) - near.global_position.x) < 2.0 and absf(float(row[2]) - near.global_position.z) < 2.0, "host: the row has where it stands")
		var anim := String(row[4])
		check(anim in ["idle", "run", "attack", "dead", "sit"] or anim.begins_with("skill:"), "host: the anim is one of the protocol's (%s)" % anim)
		check(int(row[5]) == near.wire_flags() or int(row[5]) >= 0, "host: flags are a number")
	# A cast at a monster: the skill and the monster's eid go out.
	var mob: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_dead():
			mob = node
			break
	check(mob != null, "host: monsters are about")
	var skill: Dictionary = {}
	for s in near.data.skills:
		if not s.has("star"):
			skill = s
			break
	if mob != null and not skill.is_empty():
		if not mob.has_meta("eid"):
			mob.set_meta("eid", 4242)
		var eid := int(mob.get_meta("eid"))
		near.target = mob
		link.sent.clear()
		wp._ev_tokens = WorldPresence.EVENT_BURST
		near._cast(skill)
		var casts := link.events("skill")
		check(casts.size() == 1 and int(casts[0].index) == near.world_index and String(casts[0].data.id) == String(skill.id) and int(casts[0].data.eid) == eid, "host: the cast goes out with the skill and the monster's eid (%s)" % [casts])
		check(near.wire_anim() == "skill:" + String(skill.id), "host: the anim says the skill just after the cast (%s)" % near.wire_anim())
	# A bubble over a listed player goes out; the world host's line goes as ai_chat. (The
	# event budget is refilled before each: a busy field's own casts may have spent it.)
	link.sent.clear()
	wp._ev_tokens = WorldPresence.EVENT_BURST
	wp._say("world", WorldPlayers.state(near.world_index, WorldPresence.clock()), "ใครอยู่แถวนี้บ้าง")
	var bubbles := link.events("bubble")
	check(bubbles.size() == 1 and int(bubbles[0].index) == near.world_index and String(bubbles[0].data.text) == "ใครอยู่แถวนี้บ้าง", "host: the bubble goes out (%s)" % [bubbles])
	wp.flush_ai_chat()
	var ai := link.frames("ai_chat")
	check(ai.size() == 1 and (ai[0].lines as Array).size() == 1 and String(ai[0].lines[0].text) == "ใครอยู่แถวนี้บ้าง" and String(ai[0].lines[0].ch) == "world" and int(ai[0].lines[0].index) == near.world_index and String(ai[0].lines[0].color) != "", "host: the world host sends its world line as ai_chat (%s)" % [ai])
	# A guild line stays here.
	link.sent.clear()
	wp._say("guild", WorldPlayers.state(near.world_index, WorldPresence.clock()), "กิลด์ไปไหนกัน")
	wp.flush_ai_chat()
	check(link.frames("ai_chat").is_empty() and link.events("bubble").is_empty(), "host: guild chat is not shared")
	# A turn of the world chat goes out batched.
	link.sent.clear()
	WorldPresence.chat_clock_override = 50000.0
	wp._posted.clear()
	wp._quiet_until = -1.0
	wp._queue.clear()
	for k in 8:
		wp._chat_in = 0.0
		wp.chat_tick(0.0)
		WorldPresence.chat_clock_override += 20.0
	WorldPresence.chat_clock_override = -1.0
	check(link.frames("ai_chat").size() >= 1, "host: the world chat's turns go out as ai_chat (%d)" % link.frames("ai_chat").size())
	# Leaving.
	link.sent.clear()
	await seconds(0.3)
	wp._drop_shown(near.world_index)
	var leaves := link.events("leave")
	check(leaves.size() == 1 and int(leaves[0].index) == near.world_index, "host: a player leaving goes out (%s)" % [leaves])
	# Not world host: no ai_chat, the world chat not made here.
	Online._dispatch({"t": "whost", "id": "p2"})
	check(WorldPresence.world_chat_relayed(), "host: another world host makes the chat")
	link.sent.clear()
	world_lines.clear()
	WorldPresence.chat_clock_override = 90000.0
	for k in 6:
		wp._chat_in = 0.0
		wp.chat_tick(0.0)
		WorldPresence.chat_clock_override += 20.0
	WorldPresence.chat_clock_override = -1.0
	check(link.frames("ai_chat").is_empty() and world_lines.filter(func(l): return String(l[0]) != "ประกาศ").is_empty(), "host: not the world host: no world chat made or sent (%s)" % [world_lines])
	Online.use_transport(null)
	zone.queue_free()
	await frames(3)


## The mirror side: another real player's game runs this zone's players.
func _mirror() -> void:
	var link := FakeLink.new()
	welcome(link, "p2", "p2")
	var zone: Zone = await make_zone()
	var wp := zone.presence
	check(wp.mode == WorldPresence.MIRROR, "mirror: someone else hosts the zone (%d)" % wp.mode)
	check(own_players().is_empty(), "mirror: no world players of this game's own (%d)" % own_players().size())
	await seconds(0.3)
	check(own_players().is_empty() and wp.shown.is_empty(), "mirror: still none before a snapshot")
	var t := WorldPresence.clock()
	var a: int = here[0]
	var b: int = here[1]
	var c: int = here[2]
	# One with a mount rides, if any has one.
	for i in here:
		if i != a and not WorldPlayers.mount_of(WorldPlayers.member(i, t)).is_empty():
			if i == b or i == c:
				break
			c = i
			break
	var rides := not WorldPlayers.mount_of(WorldPlayers.member(c, t)).is_empty()
	var at := zone.hero.global_position + Vector3(4.0, 0.0, 4.0)
	var snap := func(rows: Array) -> void:
		Online._dispatch({"t": "wp_snap", "zone": String(place), "from": "p2", "ps": rows})
	snap.call([[a, at.x, at.z, 0.5, "run", 0], [b, at.x + 3.0, at.z, 0.0, "idle", 0], [c, at.x - 3.0, at.z, 1.0, "idle", FieldPlayer.F_RIDING]])
	await frames(2)
	var got := puppets(zone)
	check(got.size() == 3 and got.has(a) and got.has(b) and got.has(c), "mirror: the snapshot's players come as puppets (%s)" % [got.keys()])
	check(own_players().is_empty(), "mirror: and nothing of its own")
	for i in got:
		var p := got[i] as FieldPlayer
		var m := WorldPlayers.member(i, t)
		check(p.world_index == i and String(p.member.name) == String(WorldPlayers.entry(i).name), "mirror: puppet %d is that roster player" % i)
		check(String(p.member["class"]) == String(m["class"]) and p._equip_sig == WorldPlayers.gear_signature(m), "mirror: puppet %d wears its own look and gear" % i)
		check(p.is_in_group("world_players") and p.target == null, "mirror: a puppet hunts nothing")
	if got.has(c) and rides:
		check((got[c] as FieldPlayer).mount != null, "mirror: the riding flag puts it on its mount")
	# A spoof from someone not hosting changes nothing.
	Online._dispatch({"t": "wp_snap", "zone": String(place), "from": "p9", "ps": []})
	check(puppets(zone).size() == 3, "mirror: a snapshot from someone else is ignored")
	# Interpolation between two snapshots.
	await seconds(0.25)
	snap.call([[a, at.x + 4.0, at.z, 0.5, "run", 0], [b, at.x + 3.0, at.z, 0.0, "idle", 0], [c, at.x - 3.0, at.z, 1.0, "idle", FieldPlayer.F_RIDING]])
	var pa := puppets(zone).get(a) as FieldPlayer
	if pa != null:
		check(pa.puppet_snapshots() >= 2, "mirror: the puppet keeps the snapshots")
		var t0: float = pa._p_t[pa.puppet_snapshots() - 2]
		var t1: float = pa._p_t[pa.puppet_snapshots() - 1]
		var mid := pa.puppet_sample((t0 + t1) * 0.5)
		check(absf(mid.x - (at.x + 2.0)) < 0.3, "mirror: halfway between two snapshots it stands halfway (%.2f vs %.2f)" % [mid.x, at.x + 2.0])
		check(absf(pa.global_position.x - (at.x + 4.0)) > 0.5, "mirror: played behind the newest snapshot, not snapped to it")
		await seconds(0.6)
		check(absf(pa.global_position.x - (at.x + 4.0)) < 0.3, "mirror: then it gets there (%.2f)" % pa.global_position.x)
	# A cast at the mirrored monster plays there.
	var mob := Mob.new()
	mob.setup(&"pink_slime", 1, at + Vector3(0, 0, 6.0), zone.hero)
	zone.add_child(mob)
	mob.set_physics_process(false)
	mob.set_meta("eid", 555)
	check(wp.mob_by_eid(555) == mob, "mirror: the target is found by its eid")
	var skill: Dictionary = {}
	if pa != null:
		for s in pa.data.skills:
			if not s.has("star") and String(s.get("shape", "")) in ["single", "chain", "fan", "blast"]:
				skill = s
				break
	if pa != null and not skill.is_empty():
		Online._dispatch({"t": "wp_event", "zone": String(place), "from": "p2", "index": a, "ev": "skill", "data": {"id": String(skill.id), "eid": 555}})
		await seconds(clampf(float(skill.get("hit_delay", 0.35)), 0.05, 1.5) + 0.3)
		check(pa.puppet_show_at.is_finite() and Vector2(pa.puppet_show_at.x - mob.global_position.x, pa.puppet_show_at.z - mob.global_position.z).length() < 0.5, "mirror: the cast lands on the mirrored monster (%s vs %s)" % [pa.puppet_show_at, mob.global_position])
		check(mob.hp == mob.max_hp, "mirror: a puppet's cast hurts nothing")
	# A bubble.
	Online._dispatch({"t": "wp_event", "zone": String(place), "from": "p2", "index": b, "ev": "bubble", "data": {"text": "สวัสดีครับ"}})
	var pb := puppets(zone).get(b) as FieldPlayer
	check(pb != null and is_instance_valid(pb._bubble) and pb._bubble.text == "สวัสดีครับ", "mirror: the host's bubble shows over the puppet")
	# Missing from the snapshot: gone.
	snap.call([[a, at.x + 4.0, at.z, 0.5, "idle", 0]])
	await frames(2)
	got = puppets(zone)
	check(got.size() == 1 and got.has(a), "mirror: players no longer listed leave (%s)" % [got.keys()])
	# The world chat: made by the world host, shown here.
	check(WorldPresence.world_chat_relayed(), "mirror: another game makes the world chat")
	world_lines.clear()
	WorldPresence.chat_clock_override = 130000.0
	wp._posted.clear()
	for k in 6:
		wp._chat_in = 0.0
		wp.chat_tick(0.0)
		wp.chat_once()
		WorldPresence.chat_clock_override += 20.0
	WorldPresence.chat_clock_override = -1.0
	check(world_lines.filter(func(l): return String(l[0]) != "ประกาศ").is_empty() and link.frames("ai_chat").is_empty(), "mirror: no world chat of its own (%s)" % [world_lines])
	var name_a := String(WorldPlayers.entry(a).name)
	Online._dispatch({"t": "ai_chat", "from": "p2", "lines": [{"ch": "world", "speaker": name_a, "text": "ไปตีบอสกันไหม", "color": "ffaa00", "index": a}, {"ch": "guild", "speaker": "x", "text": "no"}]})
	check(world_lines.size() == 1 and String(world_lines[0][0]) == name_a and String(world_lines[0][1]) == "ไปตีบอสกันไหม", "mirror: the world host's line is in the world chat (%s)" % [world_lines])
	pa = puppets(zone).get(a) as FieldPlayer
	check(pa != null and is_instance_valid(pa._bubble) and pa._bubble.text == "ไปตีบอสกันไหม", "mirror: with a bubble over the speaker standing here")
	Online._dispatch({"t": "ai_chat", "from": "p9", "lines": [{"ch": "world", "speaker": "Spoof", "text": "หลอก"}]})
	check(world_lines.size() == 1, "mirror: ai_chat from someone not the world host is ignored")
	# The host role comes here: the puppets carry on as this game's own, where they stand.
	var before := pa.global_position if pa != null else Vector3.ZERO
	Online._dispatch({"t": "state", "id": "p2", "zone": String(place), "pos": [at.x, 0.0, at.z], "yaw": 0.0, "anim": "idle", "hp": 500, "max_hp": 500})
	Online._dispatch({"t": "host", "zone": String(place), "id": "me"})
	check(wp.mode == WorldPresence.HOST, "handover: this game hosts now (%d)" % wp.mode)
	check(pa != null and is_instance_valid(pa) and not pa.is_queued_for_deletion() and not pa.puppet and wp.shown.get(a) == pa, "handover: the same body, no longer a puppet")
	check(pa != null and is_instance_valid(pa) and pa.global_position.distance_to(before) < 0.5, "handover: right where it stood")
	link.sent.clear()
	await seconds(0.6)
	var after := link.frames("wp_snap")
	check(not after.is_empty() and (after[-1].ps as Array).any(func(r): return int(r[0]) == a), "handover: and it is in this game's snapshots now")
	# Back to mirror, then the link drops: the puppets stay as this game's own.
	Online._dispatch({"t": "host", "zone": String(place), "id": "p2"})
	check(wp.mode == WorldPresence.MIRROR, "mirror again (%d)" % wp.mode)
	await frames(2)
	check(own_players().is_empty(), "mirror again: this game's own players went")
	snap.call([[a, at.x, at.z, 0.5, "idle", 0]])
	await frames(2)
	var pz := puppets(zone).get(a) as FieldPlayer
	check(pz != null, "mirror again: the puppet is back")
	Online.use_transport(null)
	check(wp.mode == WorldPresence.LOCAL, "link gone: the zone is this game's own again (%d)" % wp.mode)
	check(pz != null and is_instance_valid(pz) and not pz.puppet and not pz.is_queued_for_deletion(), "link gone: the puppet carries on as a world player")
	check(not WorldPresence.world_chat_relayed(), "link gone: the world chat is made here again")
	world_lines.clear()
	WorldPresence.chat_clock_override = 170000.0
	wp._posted.clear()
	wp._queue.clear()
	wp._quiet_until = -1.0
	for k in 6:
		wp.chat_once()
		WorldPresence.chat_clock_override += 20.0
	WorldPresence.chat_clock_override = -1.0
	check(world_lines.size() >= 1, "link gone: the players talk again (%d)" % world_lines.size())
	zone.queue_free()
	await frames(3)
