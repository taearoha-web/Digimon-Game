extends Node3D
## Shared combat online (EntitySync, MirrorMob; docs/ONLINE_PROTOCOL.md "Shared combat"),
## each side of it alone with a fake transport (no network):
## - host: a party member stands in the field: every monster gets an eid, snapshots and
##   spawn events go out, a member's ent_hit hurts the monster and puts its threat on the
##   member's RemotePlayer, a monster's blow on that player becomes an `ent_event hit`, a
##   kill sends `dead` with the killer and the damage share; offline nothing is sent;
## - mirror: another member hosts: no own monsters, mirrors built from spawn events glide
##   to the snapshots with their HP bar, the hero's hit goes out as ent_hit, a `hit` hurts
##   the hero, `dead` drops loot and gives EXP here, and a dropped link takes the mirrors
##   away and brings the field's own monsters back.
## godot --headless --path . res://tests/integration/online_combat_test.tscn
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


## A stand-in for the client core's RemotePlayer: just a body in the group.
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
	Game.new_profile(&"warrior", "Online QA", FaceKit.default_look())
	Game.profile.level = 12
	Game.profile.party = []
	Game.profile.hp = Game.stats_now().max_hp
	await _offline()
	await _host()
	await _mirror()
	Online.use_transport(null)
	print("ONLINE COMBAT: %d checks, %d failures" % [checks, failures])
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
	return zone


func own_mobs(zone: Zone) -> Array:
	return zone.get_children().filter(func(c): return c is Mob and not (c is MirrorMob) and not c.is_queued_for_deletion())


func mirrors(zone: Zone) -> Array:
	return zone.get_children().filter(func(c): return c is MirrorMob and not c.is_queued_for_deletion())


## Offline and solo: the sync sleeps, nothing goes out, monsters spawn as always.
func _offline() -> void:
	var zone: Zone = await make_zone(&"meadow")
	check(zone.sync != null and not zone.sync.is_host() and not zone.sync.is_mirror(), "offline: the field's sync sleeps")
	check(not EntitySync.hosting() and not EntitySync.mirroring(), "offline: nobody hosts or mirrors")
	check(own_mobs(zone).size() > 0, "offline: the camps are full as always")
	var mob: Mob = own_mobs(zone)[0]
	check(not mob.has_meta("eid"), "offline: monsters get no eid")
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [{"id": "p9", "name": "Solo", "zone": "meadow", "pos": [0, 0, 0]}], "party": null})
	await seconds(0.4)
	check(not link.sent.any(func(f): return f is Dictionary and String(f.get("t", "")).begins_with("ent_")), "online without a party: nothing about monsters is sent")
	Online.use_transport(null)
	zone.queue_free()
	await frames(3)


## The host side.
func _host() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Buddy", "user": "buddy", "zone": "meadow", "pos": [0, 0, 0], "hp": 500, "max_hp": 500, "anim": "idle"},
		{"id": "p3", "name": "Stranger", "user": "stranger", "zone": "meadow", "pos": [0, 0, 0], "hp": 500, "max_hp": 500}],
		"party": {"id": "party1", "leader": "me", "members": ["me", "p2"]}})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "me"})
	var zone: Zone = await make_zone(&"meadow")
	var mobs := own_mobs(zone)
	check(mobs.size() > 3, "host: the host spawns its camps")
	var mob: Mob = mobs[0]
	mob.set_physics_process(false)
	var buddy := RemoteDouble.new("p2")
	zone.add_child(buddy)
	buddy.global_position = mob.global_position + Vector3(2.0, 0, 0)
	var stranger := RemoteDouble.new("p3")
	zone.add_child(stranger)
	stranger.global_position = mob.global_position + Vector3(-2.0, 0, 0)
	zone.hero.global_position = mob.global_position + Vector3(30.0, 0, 30.0)
	zone.sync.update_mode()
	check(zone.sync.is_host() and EntitySync.hosting(), "host: a party member in the field makes this game the host")
	await seconds(0.6)
	check(mob.has_meta("eid") and int(mob.get_meta("eid")) > 0, "host: monsters get an eid")
	var eid := int(mob.get_meta("eid", 0))
	var snaps := link.frames("ent_snap")
	check(snaps.size() >= 1, "host: snapshots go out (%d)" % snaps.size())
	var row: Array = []
	if not snaps.is_empty():
		check(String(snaps[-1].zone) == "meadow", "host: the snapshot names the zone")
		for r in snaps[-1].ents:
			if int(r[0]) == eid:
				row = r
		check((snaps[-1].ents as Array).size() <= EntitySync.SNAP_CAP, "host: at most SNAP_CAP in a snapshot")
	check(row.size() == 7 and absf(float(row[1]) - mob.global_position.x) < 0.11 and int(row[4]) == mob.hp and int(row[5]) == mob.max_hp, "host: the snapshot row: eid, x, z, yaw, hp, max hp, flags")
	# Spawn events (paced): wait until ours is described.
	var spawn: Dictionary = {}
	for i in 60:
		for f in link.events("spawn"):
			if int(f.eid) == eid:
				spawn = f
		if not spawn.is_empty():
			break
		await seconds(0.1)
	check(not spawn.is_empty() and String(spawn.data.m) == String(mob.monster_id) and int(spawn.data.lv) == mob.level and int(spawn.data.mhp) == mob.max_hp, "host: a spawn event describes the monster (id, level, HP)")
	var first_sent := Time.get_ticks_msec()
	var count := link.sent.size()
	await seconds(1.0)
	check(link.sent.size() - count <= int(EntitySync.RATE * 1.0 + EntitySync.BURST), "host: frames stay under the rate (%d in 1 s)" % (link.sent.size() - count))
	# Targets: the party member, never a stranger.
	var targets := mob._targets()
	check(targets.has(buddy), "host: the party member's RemotePlayer is a victim")
	check(not targets.has(stranger), "host: a player outside the party is not")
	# A member's hit: HP drops, threat goes to its RemotePlayer, the monster chases it.
	mob.max_hp = 100000
	mob.hp = 100000
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 700, "crit": true, "from": "p2"})
	check(mob.hp == 100000 - 700, "host: ent_hit takes the damage off (%d)" % mob.hp)
	check(mob.threat_of(buddy) >= 699.0, "host: the threat goes to the member's RemotePlayer")
	check(mob._pick_victim() == buddy, "host: the monster goes for the member who hit it")
	check(mob.hostile, "host: the hit monster is angry")
	# Effects ride along.
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 0, "crit": false, "fx": {"stun": 1.5, "shred": [0.2, 4.0]}, "from": "p2"})
	check(mob._stun > 1.0 and mob.debuff_left("shred") > 3.0, "host: a member's stun and armour crack land")
	# The monster's blow on the member is sent to that member.
	link.sent.clear()
	mob._deliver(buddy, 321.0)
	await seconds(0.3)
	var hits := link.events("hit")
	check(hits.size() == 1 and String(hits[0].data.to) == "p2" and int(hits[0].data.dmg) == 321 and int(hits[0].eid) == eid, "host: a strike on the member becomes ent_event hit {to, dmg}")
	# A boss move's danger circles go out as a cast.
	link.sent.clear()
	mob.template = mob.template.duplicate()
	mob.is_boss = true
	EntitySync.cast(mob, [[mob.global_position, 5.5, 1.2]], "attack", "ทดสอบ")
	await seconds(0.3)
	var casts := link.events("cast")
	check(casts.size() == 1 and (casts[0].data.c as Array).size() == 1 and absf(float(casts[0].data.c[0][2]) - 5.5) < 0.01, "host: a telegraph goes out as ent_event cast")
	mob.is_boss = false
	# A describe request (an empty hit) sends the spawn again.
	link.sent.clear()
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": 0, "crit": false, "from": "p2"})
	await seconds(0.4)
	check(link.events("spawn").any(func(f): return int(f.eid) == eid), "host: an empty ent_hit asks for the spawn again")
	# The kill: dead with the killer and the share.
	link.sent.clear()
	Online._dispatch({"t": "ent_hit", "zone": "meadow", "eid": eid, "dmg": mob.hp + 5, "crit": false, "from": "p2"})
	await seconds(0.3)
	var dead := link.events("dead")
	check(dead.size() == 1 and int(dead[0].eid) == eid, "host: the kill sends ent_event dead")
	if dead.size() == 1:
		check(String(dead[0].data.killer) == "p2", "host: the member who struck last is the killer")
		check(int(dead[0].data.share.get("p2", 0)) >= 99000 and dead[0].data.share.has("me"), "host: the damage share names everyone")
	# A monster that leaves without dying is gone for the mirrors too.
	var other: Mob = null
	for m in own_mobs(zone):
		if m.has_meta("eid") and not m.is_dead():
			other = m
			break
	if other != null:
		var other_eid := int(other.get_meta("eid"))
		link.sent.clear()
		other.queue_free()
		await seconds(0.4)
		check(link.events("gone").any(func(f): return int(f.eid) == other_eid), "host: a monster freed without dying is announced gone")
	# The member leaves the zone: hosting stops.
	Online._dispatch({"t": "state", "id": "p2", "zone": "town"})
	zone.sync.update_mode()
	check(not zone.sync.is_host(), "host: alone again, nothing is shared")
	Online.use_transport(null)
	zone.queue_free()
	await frames(3)


## The mirror side.
func _mirror() -> void:
	var link := FakeLink.new()
	Online.use_transport(link)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "me"}, "players": [
		{"id": "p2", "name": "Leader", "user": "leader", "zone": "meadow", "pos": [0, 0, 0], "hp": 500, "max_hp": 500}],
		"party": {"id": "party1", "leader": "p2", "members": ["me", "p2"]}})
	Online._dispatch({"t": "host", "zone": "meadow", "id": "p2"})
	var zone: Zone = await make_zone(&"meadow")
	zone.sync.update_mode()
	check(zone.sync.is_mirror(), "mirror: another member hosts: this field mirrors")
	check(own_mobs(zone).is_empty(), "mirror: no own monsters spawn")
	var hero := zone.hero
	var at := hero.global_position + Vector3(4.0, 0, 0)
	var id: StringName = (zone.data.camps[0].monsters as Array)[0]
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "spawn", "from": "p2",
		"data": {"m": String(id), "lv": 4, "x": at.x, "z": at.z, "y": 0.5, "hp": 900, "mhp": 1000}})
	await frames(2)
	var list := mirrors(zone)
	check(list.size() == 1, "mirror: a spawn event builds a mirror")
	if list.is_empty():
		return
	var m: MirrorMob = list[0]
	check(m.is_in_group("mobs") and m.eid == 7 and m.monster_id == id and m.level == 4, "mirror: it is a monster to the hero (group mobs), same id and level")
	check(String(m.template.model) == String(MonsterData.get_monster(id).model) and is_equal_approx(m.visual.height, float(MonsterData.get_monster(id).height)), "mirror: the same model and height as the real one")
	check(m.hp == 900 and m.max_hp == 1000, "mirror: the host's HP")
	# A snapshot moves it (gliding) and sets its HP bar.
	var goal := at + Vector3(3.0, 0, 1.0)
	Online._dispatch({"t": "ent_snap", "zone": "meadow", "from": "p2", "ents": [[7, goal.x, goal.z, 1.2, 600, 1000, EntitySync.F_HOSTILE]]})
	var start := m.global_position
	await seconds(0.5)
	var flat := Vector2(m.global_position.x - goal.x, m.global_position.z - goal.z).length()
	check(flat < 0.5 and Vector2(start.x - goal.x, start.z - goal.z).length() > 2.0, "mirror: it glides to the snapshot (%.2f m off)" % flat)
	check(m.hp == 600 and m._bar.visible and m.hostile, "mirror: HP and bar follow the snapshot")
	check(own_mobs(zone).is_empty(), "mirror: still no own monsters")
	# A snapshot from somebody who is not the host is ignored.
	Online._dispatch({"t": "ent_snap", "zone": "meadow", "from": "p5", "ents": [[7, 0.0, 0.0, 0.0, 1, 1000, 0]]})
	check(m.hp == 600, "mirror: only the host's snapshots count")
	# The hero's own hit goes out as ent_hit.
	link.sent.clear()
	hero.stats["crit"] = 0.0
	hero._deal(m, 1.0, Color.WHITE, &"", true)
	m.apply_stun(1.2)
	await seconds(0.25)
	var outs := link.frames("ent_hit")
	check(outs.size() == 1 and int(outs[0].eid) == 7 and int(outs[0].dmg) > 0 and String(outs[0].zone) == "meadow", "mirror: the hero's hit goes to the host as ent_hit")
	if outs.size() == 1:
		check(outs[0].has("fx") and float(outs[0].fx.stun) > 1.0, "mirror: a stun rides along with the hit")
		check(m.hp < 600 and not m.is_dead(), "mirror: the hit shows here at once, the mirror does not die by itself")
	check(hero.nearest_mob(30.0) == m, "mirror: the hero's targeting finds the mirror")
	# The host's monster strikes the hero.
	hero.stats["dodge"] = 0.0
	hero._invulnerable_until = 0
	var hp_before := int(Game.profile.hp)
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "hit", "from": "p2", "data": {"to": "me", "dmg": 80}})
	check(int(Game.profile.hp) < hp_before, "mirror: a hit event hurts the hero (%d -> %d)" % [hp_before, int(Game.profile.hp)])
	hp_before = int(Game.profile.hp)
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "hit", "from": "p2", "data": {"to": "p2", "dmg": 80}})
	check(int(Game.profile.hp) == hp_before, "mirror: a hit meant for another member does not")
	# A cast draws the telegraph and plays the windup.
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "cast", "from": "p2", "data": {"c": [[goal.x, goal.z, 3.0, 1.0]], "a": "attack", "n": "ทดสอบ"}})
	check(m._anim_lock > Time.get_ticks_msec(), "mirror: a cast plays the windup")
	# The kill: loot and EXP here, as if the hero had killed it.
	var exp_before := int(Game.profile.exp)
	var level_before := int(Game.profile.level)
	var drops_before := zone.get_children().filter(func(c): return c is LootDrop).size()
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 7, "ev": "dead", "from": "p2", "data": {"killer": "p2", "share": {"p2": 700, "me": 300}}})
	await frames(2)
	check(m.is_dead() or not is_instance_valid(m), "mirror: dead on the host's word")
	var drops := zone.get_children().filter(func(c): return c is LootDrop).size()
	check(drops > drops_before, "mirror: the kill drops this game's loot (%d)" % (drops - drops_before))
	check(int(Game.profile.exp) > exp_before or int(Game.profile.level) > level_before, "mirror: the kill gives EXP")
	check(zone.sync.mirrors.is_empty(), "mirror: the dead mirror is forgotten")
	# A field boss mirror carries its kind (its drop table).
	Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 9, "ev": "spawn", "from": "p2",
		"data": {"m": String(zone.data.boss.monster), "lv": int(zone.data.boss.level), "x": at.x, "z": at.z + 6.0, "hp": 5000, "mhp": 5000, "k": "field_boss"}})
	await frames(1)
	var boss: MirrorMob = zone.sync.mirrors.get(9)
	check(boss != null and boss.is_boss and zone._is_field_boss(boss), "mirror: the field boss is mirrored as the field's boss")
	if boss != null:
		Online._dispatch({"t": "ent_event", "zone": "meadow", "eid": 9, "ev": "phase", "from": "p2", "data": {"p": 2}})
		check(boss.phase == 2, "mirror: the boss phase plays here")
	# Unknown eids in a snapshot ask the host (an empty ent_hit).
	link.sent.clear()
	Online._dispatch({"t": "ent_snap", "zone": "meadow", "from": "p2", "ents": [[42, at.x, at.z, 0.0, 10, 10, 0]]})
	await seconds(0.25)
	check(link.frames("ent_hit").any(func(f): return int(f.eid) == 42 and int(f.dmg) == 0), "mirror: an unknown eid is asked for")
	# Meanwhile the field spawns nothing of its own.
	await seconds(1.8)
	check(own_mobs(zone).is_empty(), "mirror: the camps stay empty while mirroring")
	# The link drops: mirrors vanish, the field is back to normal.
	Online.use_transport(null)
	await frames(2)
	check(not zone.sync.is_mirror() and not EntitySync.mirroring(), "drop: the mirror ends with the link")
	check(mirrors(zone).is_empty(), "drop: the mirrors are gone")
	check(own_mobs(zone).size() > 3, "drop: the field spawns its own monsters again (%d)" % own_mobs(zone).size())
	zone.queue_free()
	await frames(3)
