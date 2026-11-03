extends Node3D
## The shared world, zone-wide (docs/ONLINE_PROTOCOL.md "Shared world (zone-wide, v2)"):
## every real player in the same open zone sees and fights the same monsters, party or
## not; instanced zones stay party-only. Fake transport, no network:
## - the Online API: zone_members, serves, is_instanced, is_mirror_zone without a party;
## - mirror without a party: the field mirrors the zone host, the hero's hits go out as
##   ent_hit; a kill pays loot / EXP only when the hero's side hit it or a party member in
##   the field did (the share), the world boss bounty too; nobody else gets anything;
## - host with two players outside its party: both are served (snapshots near either of
##   them, both are victims, a blow on one becomes ent_event hit); the host is paid only
##   for kills it (or a party member) took part in, and its `dead` share names everyone;
## - hand-over: the host leaves, this game takes over the mirrored monsters as real Mobs
##   (spot, HP, boss phase, same eid), no fresh camps burst out, and the frames go on;
##   another mirror keeps its mirrors through a host change and drops the ones the new
##   host never speaks of; left alone (host null) the mirrors become its own monsters.
## godot --headless --path . res://tests/integration/online_zone_test.tscn
var checks := 0
var failures := 0


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


## A stand-in for a RemotePlayer: just a body in the group.
class RemoteDouble:
	extends Node3D
	func _init(id: String) -> void:
		set_meta("online_id", id)
		add_to_group("remote_players")
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
	Game.new_profile(&"warrior", "Zone QA", FaceKit.default_look())
	Game.profile.level = 12
	Game.profile.party = []
	Game.profile.hp = Game.stats_now().max_hp
	_api()
	await _mirror_solo()
	await _host_strangers()
	await _handover()
	await _host_moved()
	Online.use_transport(null)
	print("ONLINE ZONE: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func player(id: String, zone: String, pos := Vector3.ZERO) -> Dictionary:
	return {"id": id, "name": id.to_upper(), "user": id, "zone": zone, "pos": [pos.x, pos.y, pos.z], "hp": 500, "max_hp": 500, "anim": "idle"}


func connect_as(players: Array, party: Variant) -> FakeLink:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": players, "party": party})
	return link


func make_zone(id: StringName) -> Zone:
	Game.current_zone = id
	var zone := Zone.new()
	zone.zone_id = id
	zone.layout_seed = 777
	add_child(zone)
	await frames(2)
	zone.hero.set_physics_process(false)
	return zone


func own_mobs(zone: Zone) -> Array:
	return zone.get_children().filter(func(c): return c is Mob and not (c is MirrorMob) and not c.is_queued_for_deletion() and not c.is_dead())


func mirrors(zone: Zone) -> Array:
	return zone.get_children().filter(func(c): return c is MirrorMob and not c.is_queued_for_deletion())


func drops(zone: Zone) -> int:
	return zone.get_children().filter(func(c): return c is LootDrop).size()


func spawn(zone: Zone, eid: int, extra := {}) -> MirrorMob:
	var at := zone.hero.global_position + Vector3(3.0 + eid * 0.5, 0, 0)
	var id: StringName = (zone.data.camps[0].monsters as Array)[0]
	var d := {"m": String(id), "lv": 3, "x": at.x, "z": at.z, "y": 0.0, "hp": 800, "mhp": 1000}
	d.merge(extra, true)
	Online._dispatch({"t": "ent_event", "zone": String(zone.zone_id), "eid": eid, "ev": "spawn", "from": Online.zone_host(zone.zone_id), "data": d})
	await frames(1)
	var m: Variant = zone.sync.mirrors.get(eid)
	return m as MirrorMob if m != null and is_instance_valid(m) else null


## What a kill paid this game: {loot, exp} (loot = drops on the ground, exp gained).
func kill(zone: Zone, eid: int, share: Dictionary) -> Dictionary:
	var exp_before := int(Game.profile.exp)
	var level_before := int(Game.profile.level)
	var loot_before := drops(zone)
	Online._dispatch({"t": "ent_event", "zone": String(zone.zone_id), "eid": eid, "ev": "dead", "from": Online.zone_host(zone.zone_id), "data": {"killer": "x", "share": share}})
	await frames(2)
	return {"loot": drops(zone) - loot_before, "exp": int(Game.profile.exp) != exp_before or int(Game.profile.level) != level_before}


## The Online API.
func _api() -> void:
	connect_as([player("p2", "meadow"), player("p3", "meadow"), player("p4", "guildwar"), player("p5", "guildwar"), player("p6", "town")],
		{"id": "pt", "leader": "me", "members": ["me", "p3", "p4"]})
	check(Online.zone_members(&"meadow").size() == 2 and Online.zone_members(&"meadow").has("p2") and Online.zone_members(&"meadow").has("p3"), "zone_members: everyone in the zone, party or not")
	check(Online.is_instanced(&"guildwar") and Online.is_instanced(&"tower") and Online.is_instanced(&"pvp") and Online.is_instanced(&"arena") and not Online.is_instanced(&"meadow"), "is_instanced: tower, pvp, guildwar, arena")
	var open: Array = Online.serves(&"meadow")
	check(open.size() == 2 and open.has("p2"), "serves: an open zone serves everyone there")
	check(Online.serves(&"guildwar") == ["p4"], "serves: an instanced zone serves only the party (%s)" % [Online.serves(&"guildwar")])
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	check(Online.is_mirror_zone(&"meadow"), "is_mirror_zone: a player outside the party hosts: mirror")
	Online._dispatch({"t": "party", "party": null})
	check(Online.is_mirror_zone(&"meadow") and Online.zone_host(&"meadow") == "p2", "leaving the party keeps the open zone's host")
	check(Online.serves(&"guildwar").is_empty(), "serves: no party, nobody served in an instanced zone")
	Online.use_transport(null)


## Mirror of a zone host outside the party.
func _mirror_solo() -> void:
	var link := connect_as([player("p2", "meadow"), player("p3", "meadow")], {"id": "pt", "leader": "me", "members": ["me", "p3"]})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "mirror: a non-party host makes this field a mirror")
	check(own_mobs(zone).is_empty(), "mirror: no own monsters")
	var m := await spawn(zone, 3)
	check(m != null and mirrors(zone).size() == 1, "mirror: the host's spawn builds a mirror")
	if m == null:
		return
	link.sent.clear()
	zone.hero.stats["crit"] = 0.0
	zone.hero._deal(m, 1.0, Color.WHITE, &"", true)
	await seconds(0.25)
	var hits := link.frames("ent_hit")
	check(hits.size() == 1 and int(hits[0].eid) == 3 and int(hits[0].dmg) > 0, "mirror: the hero's hit on a non-party host's monster goes out as ent_hit")
	check(m.dealt > 0, "mirror: the hero's side damage is counted here")
	# Killed with the hero's damage (the share may not have it yet): paid.
	var paid := await kill(zone, 3, {"p2": 1000})
	check(paid.loot > 0 and paid.exp, "loot: the hero hit it: loot and EXP (%s)" % [paid])
	# Never touched, the share has only a stranger: nothing.
	await spawn(zone, 4)
	paid = await kill(zone, 4, {"p2": 1000, "me": 0})
	check(paid.loot == 0 and not paid.exp, "loot: no part in the kill: no loot, no EXP (%s)" % [paid])
	# The share names the hero (its hits reached the host): paid.
	await spawn(zone, 5)
	paid = await kill(zone, 5, {"p2": 900, "me": 100})
	check(paid.loot > 0 and paid.exp, "loot: the share names the hero: paid")
	# A party member in the field hit it: the hero shares the reward.
	await spawn(zone, 6)
	paid = await kill(zone, 6, {"p2": 900, "p3": 100})
	check(paid.loot > 0 and paid.exp, "loot: a party member in the field took part: paid too")
	# A party member elsewhere does not count.
	Online._dispatch({"t": "state", "id": "p3", "zone": "town"})
	await spawn(zone, 7)
	paid = await kill(zone, 7, {"p2": 900, "p3": 100})
	check(paid.loot == 0 and not paid.exp, "loot: a party member in another zone does not count")
	# The world boss bounty follows the same rule.
	var boss_info: Dictionary = zone.data.boss
	await spawn(zone, 8, {"m": String(boss_info.monster), "lv": int(boss_info.level), "k": "world_boss", "day": 900001, "hp": 9000, "mhp": 9000})
	var gold := int(Game.profile.gold)
	await kill(zone, 8, {"p2": 9000})
	check(int(Game.profile.gold) == gold, "world boss: no part, no bounty")
	await spawn(zone, 9, {"m": String(boss_info.monster), "lv": int(boss_info.level), "k": "world_boss", "day": 900002, "hp": 9000, "mhp": 9000})
	await kill(zone, 9, {"p2": 8000, "me": 1000})
	check(int(Game.profile.gold) > gold, "world boss: took part: the bounty is paid")
	Online.use_transport(null)
	await frames(2)
	zone.queue_free()
	await frames(3)


## Host serving two players outside its party.
func _host_strangers() -> void:
	var link := connect_as([player("p2", "meadow"), player("p3", "meadow")], null)
	Online._dispatch({"t": "host", "zone": "meadow", "id": "me"})
	var zone: Zone = await make_zone(&"meadow")
	var mobs := own_mobs(zone)
	check(mobs.size() > 3, "host: the camps spawn")
	var near: Mob = mobs[0]
	var far: Mob = null
	for m in mobs:
		if Vector2(m.global_position.x - near.global_position.x, m.global_position.z - near.global_position.z).length() > EntitySync.NEAR + 12.0:
			far = m
			break
	for m in mobs:
		m.set_physics_process(false)
	var a := RemoteDouble.new("p2")
	zone.add_child(a)
	a.global_position = near.global_position + Vector3(2.0, 0, 0)
	var b := RemoteDouble.new("p3")
	zone.add_child(b)
	b.global_position = near.global_position + Vector3(-2.0, 0, 0)
	zone.hero.global_position = near.global_position + Vector3(0, 0, 90.0)
	zone.sync.update_mode()
	check(zone.sync.is_host(), "host: two players outside the party make this game the host")
	await seconds(0.6)
	var eid := int(near.get_meta("eid", 0))
	var snaps := link.frames("ent_snap")
	var ids: Array = []
	if not snaps.is_empty():
		for r in snaps[-1].ents:
			ids.append(int(r[0]))
	check(ids.has(eid), "host: a monster near the served players is in the snapshot")
	if far != null:
		check(not ids.has(int(far.get_meta("eid", -1))), "host: a monster far from every served player is not")
	var targets := near._targets()
	check(targets.has(a) and targets.has(b), "host: both non-party players are victims")
	link.sent.clear()
	near._deliver(b, 222.0)
	await seconds(0.3)
	var hits := link.events("hit")
	check(hits.size() == 1 and String(hits[0].data.to) == "p3" and int(hits[0].data.dmg) == 222, "host: a blow on a non-party player becomes ent_event hit")
	# Killed by p2 alone: the host (no damage) gets nothing.
	near.max_hp = 5000
	near.hp = 5000
	var exp_before := int(Game.profile.exp)
	var level_before := int(Game.profile.level)
	var loot_before := drops(zone)
	link.sent.clear()
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 1000, "crit": false, "from": "p3"})
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 6000, "crit": false, "from": "p2"})
	await seconds(0.3)
	check(near.is_dead() or not is_instance_valid(near), "host: the players' hits kill it")
	check(drops(zone) == loot_before and int(Game.profile.exp) == exp_before and int(Game.profile.level) == level_before, "host: no part in the kill: no loot, no EXP")
	var dead := link.events("dead")
	check(dead.size() == 1 and int(dead[0].data.share.get("p2", 0)) == 4000 and int(dead[0].data.share.get("p3", 0)) == 1000 and int(dead[0].data.share.get("me", -1)) == 0,
		"host: the dead share names every attacker and the host's own 0 (%s)" % [dead[0].data.share if dead.size() == 1 else "-"])
	# The host hit it too: paid.
	var second: Mob = null
	for m in own_mobs(zone):
		if m.has_meta("eid") and m != near:
			second = m
			break
	if second != null:
		second.max_hp = 3000
		second.hp = 3000
		second.take_hit(50, false, Color.WHITE, zone.hero)
		loot_before = drops(zone)
		exp_before = int(Game.profile.exp)
		level_before = int(Game.profile.level)
		link.sent.clear()
		Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": int(second.get_meta("eid")), "dmg": 9000, "crit": false, "from": "p2"})
		await seconds(0.3)
		check(drops(zone) > loot_before and (int(Game.profile.exp) > exp_before or int(Game.profile.level) > level_before), "host: took part: loot and EXP")
		dead = link.events("dead")
		check(dead.size() == 1 and int(dead[0].data.share.get("me", 0)) == 50, "host: its own damage is in the share")
	# A party member's kill pays the host too.
	Online._dispatch({"t": "party", "party": {"id": "pt", "leader": "me", "members": ["me", "p3"]}})
	var third: Mob = null
	for m in own_mobs(zone):
		if m.has_meta("eid"):
			third = m
			break
	if third != null:
		third.max_hp = 3000
		third.hp = 3000
		loot_before = drops(zone)
		Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": int(third.get_meta("eid")), "dmg": 100, "crit": false, "from": "p3"})
		Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": int(third.get_meta("eid")), "dmg": 9000, "crit": false, "from": "p2"})
		await seconds(0.3)
		check(drops(zone) > loot_before, "host: a party member took part: the host is paid")
	Online.use_transport(null)
	await frames(2)
	zone.queue_free()
	await frames(3)


## The host leaves: this game takes over the monsters as they are.
func _handover() -> void:
	var link := connect_as([player("p2", "meadow"), player("p3", "meadow")], null)
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "hand-over: a mirror first")
	var camp: Dictionary = zone.data.camps[0]
	var m := await spawn(zone, 5, {"x": float(camp.pos.x) + 1.0, "z": float(camp.pos.y), "hx": float(camp.pos.x), "hz": float(camp.pos.y), "h": 1})
	var boss_info: Dictionary = zone.data.boss
	var b := await spawn(zone, 11, {"m": String(boss_info.monster), "lv": int(boss_info.level), "k": "field_boss", "hp": 3000, "mhp": 6000, "p": 1})
	check(m != null and b != null and b.phase == 1, "hand-over: the mirrors (a boss already in phase 1)")
	if m == null or b == null:
		return
	zone.hero.stats["crit"] = 0.0
	zone.hero._deal(m, 1.0, Color.WHITE, &"", true)
	var hp_m := m.hp
	var at_m := m.global_position
	var dealt := m.dealt
	zone.hero.set_target(m)
	await frames(1)
	Online._dispatch({"t": "leave", "id": "p2"})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "me"})
	zone.sync.update_mode()
	check(zone.sync.is_host(), "hand-over: this game hosts now")
	await frames(1)
	check(mirrors(zone).is_empty(), "hand-over: no mirror left")
	var by_eid := {}
	for mob in own_mobs(zone):
		if mob.has_meta("eid"):
			by_eid[int(mob.get_meta("eid"))] = mob
	var real: Mob = by_eid.get(5)
	var boss: Mob = by_eid.get(11)
	check(real != null and boss != null, "hand-over: the mirrors became real monsters under the same eids")
	check(own_mobs(zone).size() == 2, "hand-over: no fresh camps burst out (%d monsters)" % own_mobs(zone).size())
	if real != null:
		check(real.hp == hp_m and real.max_hp == 1000, "hand-over: the HP carries over (%d / %d)" % [real.hp, hp_m])
		check(Vector2(real.global_position.x - at_m.x, real.global_position.z - at_m.z).length() < 0.2, "hand-over: it stands where the mirror stood")
		check(real.hostile and real.party_damage == dealt, "hand-over: anger and the hero's damage carry over")
		check(real.home.distance_to(Vector3(float(camp.pos.x), 0.0, float(camp.pos.y))) < 0.2 and (zone._camps[0].mobs as Array).has(real), "hand-over: it goes home to its camp and counts for it")
		check(zone.hero.target == real, "hand-over: the hero's target follows")
	if boss != null:
		check(boss.phase == 1 and boss.hp == 3000 and boss.max_hp == 6000 and zone._boss == boss, "hand-over: the field boss keeps HP and phase and is the field's boss")
	# The frames go on: snapshots and spawns under the old eids, new ones past them.
	var c := RemoteDouble.new("p3")
	zone.add_child(c)
	if real != null:
		c.global_position = real.global_position + Vector3(1.5, 0, 0)
	await seconds(0.8)
	var snaps := link.frames("ent_snap")
	check(not snaps.is_empty() and (snaps[-1].ents as Array).any(func(r): return int(r[0]) == 5), "hand-over: snapshots name the taken-over monsters")
	await seconds(2.0)
	check(link.events("spawn").any(func(f): return int(f.eid) == 11), "hand-over: the other players hear the monsters described again")
	var fresh := own_mobs(zone).filter(func(x): return x.has_meta("eid") and int(x.get_meta("eid")) != 5 and int(x.get_meta("eid")) != 11)
	check(fresh.all(func(x): return int(x.get_meta("eid")) > 11 + EntitySync.EID_GAP - 1), "hand-over: new monsters get new eids past the old ones")
	if real != null:
		Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": 5, "dmg": 10, "crit": false, "from": "p3"})
		check(real.hp == hp_m - 10, "hand-over: the other players' hits land on the taken-over monster")
	Online.use_transport(null)
	await frames(2)
	zone.queue_free()
	await frames(3)


## Another player becomes the host: the mirrors stay, the old host is not heard any more,
## the mirrors the new host never names go.
func _host_moved() -> void:
	connect_as([player("p2", "meadow"), player("p3", "meadow")], null)
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	var keep := await spawn(zone, 21)
	var stale := await spawn(zone, 22)
	check(keep != null and stale != null, "host moved: two mirrors")
	if keep == null or stale == null:
		return
	Online._dispatch({"t": "leave", "id": "p2"})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p3"})
	zone.sync.update_mode()
	check(zone.sync.is_mirror() and mirrors(zone).size() == 2, "host moved: still a mirror, the mirrors stay")
	check(own_mobs(zone).is_empty(), "host moved: no double spawn")
	var at := keep.global_position + Vector3(2.0, 0, 0)
	Online._dispatch({"t": "ent_snap", "zone": "meadow", "from": "p3", "ents": [[21, at.x, at.z, 0.0, 444, 1000, 0]]})
	check(keep.hp == 444, "host moved: the new host's snapshot moves the same mirror")
	Online._dispatch({"t": "ent_snap", "zone": "meadow", "from": "p2", "ents": [[21, at.x, at.z, 0.0, 10, 1000, 0]]})
	check(keep.hp == 444, "host moved: the old host is not heard any more")
	zone.sync._sweep_at = 1
	await frames(2)
	check(is_instance_valid(keep) and not keep.is_queued_for_deletion(), "host moved: a confirmed mirror stays")
	check(not is_instance_valid(stale) or stale.is_queued_for_deletion(), "host moved: a mirror the new host never names goes")
	# The host leaves and nobody else is here: the mirror becomes this game's own monster.
	var hp := keep.hp
	Online._dispatch({"t": "leave", "id": "p3"})
	Online._dispatch({"t": "host", "zone": "meadow", "id": null})
	zone.sync.update_mode()
	await frames(1)
	check(not zone.sync.is_mirror() and not zone.sync.is_host() and mirrors(zone).is_empty(), "alone: no mirror, nothing hosted")
	var own := own_mobs(zone)
	check(own.size() == 1 and own[0].hp == hp, "alone: the monster stays as it was (%d own)" % own.size())
	Online.use_transport(null)
	await frames(2)
	zone.queue_free()
	await frames(3)
