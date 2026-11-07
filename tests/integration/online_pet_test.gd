extends Node3D
## Real players' pets fighting together online (PetSync, PetFollower.act, PetCrowd;
## docs/ONLINE_PROTOCOL.md "Pets"), each side alone with a fake transport (no network):
## - owner (a mirror): the hero's own pet hits a mirrored monster: the damage goes to the
##   host once, inside the hero's ent_hit; each attack / skill also goes out as a
##   `pet_act` (target eid, skill id, point), paced, and only while someone sees it;
## - viewer (the host): another player's pet is a PetFollower; a relayed `pet_act` makes it
##   run to the monster and play the clip and a cheap effect, with no damage at all (the
##   monster's HP, its damage share and this game's own side are untouched); the owner's
##   ent_hit is counted once; this game's own pet counts once as its own side; malformed
##   acts do nothing; after the fight it follows again;
## - nothing leaks: the followers, their effects and the crowd's Online hook go with the zone.
## godot --headless --path . res://tests/integration/online_pet_test.tscn
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
	Game.new_profile(&"warrior", "Pet QA", FaceKit.default_look())
	Game.profile.level = 12
	Game.profile.party = []
	Game.profile["pet"] = "fire"
	Game.profile.hp = Game.stats_now().max_hp
	var hooks := Online.message.get_connections().size()
	await _owner_side()
	await _viewer_side()
	Online.use_transport(null)
	await frames(3)
	# Zone-lived listeners (the crowd's, the sync's) go with their zone; the one per-tree
	# OnlineGuildWar (OnlineGuildWar.ensure) stays.
	var left := Online.message.get_connections().filter(func(c): return not (c.callable.get_object() is OnlineGuildWar))
	check(left.size() == hooks, "no leak: Online's listeners are back to %d (%s)" % [hooks, str(left.map(func(c): return c.callable.get_object()))])
	check(get_tree().get_nodes_in_group("pet_followers").is_empty(), "no leak: no pet follower is left")
	print("ONLINE PET: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func make_zone(id: StringName) -> Zone:
	Game.current_zone = id
	var zone := Zone.new()
	zone.zone_id = id
	zone.layout_seed = 777
	add_child(zone)
	await frames(2)
	zone.hero.set_physics_process(false)
	zone.hero.set_process(false)
	return zone


func _sum_dmg(link: FakeLink, eid: int) -> int:
	var total := 0
	for f in link.frames("ent_hit"):
		if int(f.eid) == eid:
			total += int(f.dmg)
	return total


## The owner's game mirrors the host's monster; its own pet fights it.
func _owner_side() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Leader", "user": "leader", "zone": "meadow", "pos": [0, 0, 0], "hp": 500, "max_hp": 500}],
		"party": {"id": "party1", "leader": "p2", "members": ["me", "p2"]}})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "owner: another player hosts: this field mirrors")
	var pet := zone.pet
	check(pet != null and not pet.lite, "owner: the hero's own pet is out")
	if pet == null:
		zone.queue_free()
		return
	pet.set_process(false)
	var at := zone.hero.global_position + Vector3(3.0, 0, 0)
	var id: StringName = (zone.data.camps[0].monsters as Array)[0]
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "spawn", "from": "p2",
		"data": {"m": String(id), "lv": 4, "x": at.x, "z": at.z, "y": 0.5, "hp": 900000, "mhp": 1000000}})
	await frames(2)
	var m: MirrorMob = zone.sync.mirrors.get(7)
	check(m != null, "owner: the host's monster is mirrored")
	if m == null:
		zone.queue_free()
		return
	pet.global_position = m.global_position + Vector3(1.2, 0, 0)
	await seconds(0.3)
	link.sent.clear()
	PetSync._last_ms = -1
	var before := pet.dealt
	# A plain attack and a skill on the mirror.
	pet._target = m
	pet._basic_attack()
	await seconds(0.4)
	pet._target = m
	pet.cast(PetData.get_pet("fire").skills[0])
	await seconds(0.9)
	var dealt := pet.dealt - before
	var acts := link.frames("pet_act")
	check(acts.size() == 2, "owner: the attack and the skill go out as pet_act (%d)" % acts.size())
	if acts.size() == 2:
		check(String(acts[0].k) == "a" and int(acts[0].e) == 7 and String(acts[0].zone) == "meadow", "owner: pet_act names the plain attack and the target's eid")
		check(String(acts[1].k) == "fireball" and int(acts[1].e) == 7, "owner: pet_act names the skill id and the target's eid")
		var p: Array = acts[1].p
		check(p.size() == 2 and absf(float(p[0]) - m.global_position.x) < 0.11 and absf(float(p[1]) - m.global_position.z) < 0.11, "owner: pet_act carries the target's flat point")
		check(not acts[0].has("dmg") and not acts[1].has("dmg"), "owner: pet_act carries no damage")
	check(dealt > 0, "owner: the pet hit the mirror (%d)" % dealt)
	check(_sum_dmg(link, 7) == dealt and m.dealt == dealt, "owner: the pet's damage goes to the host once, in the hero's ent_hit (%d sent, %d dealt)" % [_sum_dmg(link, 7), dealt])
	# Paced: a burst of acts sends at most BURST frames.
	link.sent.clear()
	for i in 12:
		PetSync.report(pet, "a", m)
	check(link.frames("pet_act").size() <= int(PetSync.BURST), "owner: pet_act is paced (%d of 12 sent)" % link.frames("pet_act").size())
	# Nobody else in the field: nothing goes out.
	await seconds(1.5)
	Online._dispatch({"t": "state", "id": "p2", "zone": "town"})
	link.sent.clear()
	PetSync.report(pet, "a", m)
	check(link.frames("pet_act").is_empty(), "owner: alone in the field, no pet_act")
	Online.use_transport(null)
	zone.queue_free()
	await frames(3)


## The viewer's game hosts; another player's pet shows its fight here.
func _viewer_side() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Buddy", "user": "buddy", "zone": "meadow", "pos": [0, 0, 0], "hp": 500, "max_hp": 500, "anim": "idle", "pet": "water", "level": 30, "look": {"class": "mage"}}],
		"party": {"id": "party1", "leader": "me", "members": ["me", "p2"]}})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "me"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	check(zone.sync.is_host(), "viewer: this game hosts the field")
	if zone.pet != null:
		# This game's own pet acts only when the test says so.
		zone.pet.set_process(false)
	await seconds(0.4)
	var mob: Mob = null
	for c in zone.get_children():
		if c is Mob and not (c is MirrorMob) and c.has_meta("eid") and not c.is_dead():
			mob = c
			break
	check(mob != null, "viewer: a hosted monster with an eid")
	var remote := Online.remote_node("p2") as RemotePlayer
	check(remote != null, "viewer: the other player is a RemotePlayer here")
	if mob == null or remote == null or zone.pet_crowd == null:
		zone.queue_free()
		return
	mob.set_physics_process(false)
	mob.max_hp = 1000000
	mob.hp = 1000000
	var eid := int(mob.get_meta("eid"))
	var spot := mob.global_position + Vector3(5.0, 0, 0)
	zone.hero.global_position = mob.global_position + Vector3(8.0, 0, 3.0)
	Online._dispatch({"t": "state", "id": "p2", "zone": "meadow", "pos": [spot.x, spot.y, spot.z], "yaw": 0.0, "anim": "idle", "hp": 500, "max_hp": 500})
	await seconds(0.5)
	zone.pet_crowd.refresh(true)
	var f := zone.pet_crowd.pet_for(remote) as PetFollower
	check(f != null and f.pet_id == "water", "viewer: the other player's pet follows it (PetFollower)")
	if f == null:
		zone.queue_free()
		return
	# The owner's own hit on the monster (its pet's damage rides in it): counted once.
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 500, "crit": false, "from": "p2"})
	var share: Dictionary = zone.sync._share.get(eid, {})
	check(int(share.get("p2", 0)) == 500 and mob.hp == 1000000 - 500, "viewer: the owner's ent_hit is counted once (%d)" % int(share.get("p2", 0)))
	var hp := mob.hp
	var own_side := mob.party_damage
	link.sent.clear()
	var far := f.global_position.distance_to(mob.global_position)
	# Relayed acts: the follower runs to the monster and plays them; no damage anywhere.
	Online._dispatch({"t": "pet_act", "from": "p2", "zone": "meadow", "k": "a", "e": eid, "p": [mob.global_position.x, mob.global_position.z]})
	check(f.fighting(), "viewer: a relayed pet_act puts the follower in the fight")
	await seconds(1.0)
	check(f.acts >= 1, "viewer: the follower played the attack (%d)" % f.acts)
	check(f.global_position.distance_to(mob.global_position) < far - 1.0, "viewer: it ran to the monster (%.1f -> %.1f m)" % [far, f.global_position.distance_to(mob.global_position)])
	var acts := f.acts
	Online._dispatch({"t": "pet_act", "from": "p2", "zone": "meadow", "k": "water_jet", "e": eid, "p": [mob.global_position.x, mob.global_position.z]})
	await seconds(0.9)
	check(f.acts == acts + 1, "viewer: a skill act plays too")
	check(mob.hp == hp and mob.party_damage == own_side and int(zone.sync._share.get(eid, {}).get("p2", 0)) == 500, "viewer: the follower deals no damage (HP %d, share %d)" % [mob.hp, int(zone.sync._share.get(eid, {}).get("p2", 0))])
	check(link.frames("ent_hit").is_empty(), "viewer: nothing is sent as a hit for the follower")
	# Malformed or foreign acts change nothing.
	acts = f.acts
	for bad in [
		{"t": "pet_act", "from": "p2", "zone": "meadow", "k": "fireball", "e": eid, "p": [spot.x, spot.z]},
		{"t": "pet_act", "from": "p2", "zone": "meadow", "k": "a", "e": eid},
		{"t": "pet_act", "from": "p2", "zone": "forest", "k": "a", "e": eid, "p": [spot.x, spot.z]},
		{"t": "pet_act", "from": "p9", "zone": "meadow", "k": "a", "e": eid, "p": [spot.x, spot.z]},
		{"t": "pet_act", "from": "p2", "zone": "meadow", "k": "a", "e": 0, "p": [spot.x + 900.0, spot.z]},
		{"t": "pet_act", "from": "p2", "zone": "meadow", "k": "a", "e": "x", "p": ["a", null]}]:
		Online._dispatch(bad)
	await seconds(0.9)
	check(f.acts == acts, "viewer: malformed, foreign or far acts show nothing (%d)" % (f.acts - acts))
	# This game's own pet: its damage is its own side's, once.
	var pet := zone.pet
	if pet != null:
		pet.set_process(false)
		var dealt := pet.strike(mob, 1.0)
		check(dealt > 0 and mob.party_damage == own_side + dealt and int(zone.sync._share.get(eid, {}).get("me", 0)) == 0, "viewer: the host's own pet counts once, as its own side (%d)" % dealt)
		Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": mob.hp + 5, "crit": false, "from": "p2"})
		await seconds(0.3)
		var dead := link.events("dead").filter(func(e): return int(e.eid) == eid)
		check(dead.size() == 1, "viewer: the kill goes out once")
		if dead.size() == 1:
			check(int(dead[0].data.share.get("me", 0)) == own_side + dealt, "viewer: the share names the host's own side once (%d)" % int(dead[0].data.share.get("me", 0)))
	# The fight ends: it follows its owner again.
	await seconds(PetFollower.FIGHT_HOLD + 1.5)
	check(not f.fighting(), "viewer: after the fight the follower follows again")
	var gap := Vector2(f.global_position.x - remote.global_position.x, f.global_position.z - remote.global_position.z).length()
	check(gap < 4.0, "viewer: back by its owner (%.1f m)" % gap)
	var bolts := zone.find_children("PetBolt*", "", true, false).size()
	check(bolts == 0, "viewer: no effect left behind (%d)" % bolts)
	Online.use_transport(null)
	zone.queue_free()
	await frames(3)
	check(not is_instance_valid(f), "no leak: the follower went with the zone")
