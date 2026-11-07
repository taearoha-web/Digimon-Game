class_name PetSync
extends RefCounted
## Real players' pets fighting together online (docs/ONLINE_PROTOCOL.md, "Pets").
##
## Each game simulates only its OWN hero's pet (Pet, not lite): its hits land on the
## zone's monsters like the hero's own, so on a mirror they go to the host as the hero's
## `ent_hit` (MirrorMob.take_hit -> EntitySync.forward, credited to this player once)
## and on the host they count as the hero's side (Mob.party_damage). Nobody else's game
## deals that damage again.
##
## So the others SEE the pet fight, the owner's game also tells what its pet does:
## `pet_act {zone, k, e, p}` (k = "a" for a plain attack or the PetData skill id, e = the
## target's shared eid or 0, p = the flat hit point [x, z]). At most RATE a second
## (BURST at once), and only while someone else is here to see it. The server checks the
## skill against the sender's pet and relays it to whoever sees the sender in that zone.
## There the owner's pet is a PetFollower (PetCrowd): it runs to the target, plays the
## attack / skill clip and a cheap version of the effect (act), and never deals damage:
## the monster's HP comes with the host's snapshots as always.

const RATE := 3.0
const BURST := 4.0
## A relayed act whose point is farther than this from its owner is ignored (metres).
const NEAR_OWNER := 30.0

static var _tokens := BURST
static var _last_ms := -1
## Frames sent this session (tests).
static var sent := 0


## The hero's own pet [param pet] attacks ("a") or casts skill [param k], at
## [param target] (null: around itself). Tells the others' games, when anyone sees it.
static func report(pet: Node3D, k: String, target: Node3D) -> void:
	if pet == null or not Online.is_online() or bool(pet.get("lite")):
		return
	var zone := Online.current_zone()
	if String(zone) == "" or Online.serves(zone).is_empty():
		return
	var now := Time.get_ticks_msec()
	if _last_ms < 0:
		_tokens = BURST
	else:
		_tokens = minf(BURST, _tokens + float(now - _last_ms) * 0.001 * RATE)
	_last_ms = now
	if _tokens < 1.0:
		return
	_tokens -= 1.0
	var at := pet.global_position
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		at = target.global_position
	sent += 1
	Online.send("pet_act", {"zone": String(zone), "k": k, "e": eid_of(target), "p": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]})


## The shared id of [param target] (a mirror's or a hosted monster's), 0 for none.
static func eid_of(target: Node) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	if target.has_meta("mirror_eid"):
		return int(target.get_meta("mirror_eid"))
	if target.has_meta("eid"):
		return int(target.get_meta("eid"))
	return 0


## The monster shared as [param eid] in this game (a mirror, or one this game hosts), or null.
static func target_of(eid: int) -> Node3D:
	if eid <= 0:
		return null
	var sync := EntitySync.current
	if sync == null or not is_instance_valid(sync):
		return null
	var node: Variant = null
	if sync.is_mirror():
		node = sync.mirrors.get(eid)
	elif sync.is_host():
		node = sync.ents.get(eid)
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return null
	if (node as Object).has_method("is_dead") and bool(node.call("is_dead")):
		return null
	return node as Node3D


## A relayed `pet_act` checked against what this game knows: {from, k, kind, clip, skill,
## target (Node3D or null), at (Vector3, flat)}; {} when it is not for this zone, the
## sender has no such pet or skill, or it makes no sense.
static func parse(data: Dictionary, zone_id: StringName) -> Dictionary:
	var from := Online.id_of(data.get("from"))
	if from == "" or from == Online.my_id() or String(data.get("zone", "")) != String(zone_id):
		return {}
	var p := Online.player(from)
	if p.is_empty() or String(p.get("zone", "")) != String(zone_id):
		return {}
	var pet_id := PetData.clean_id(p.get("pet", ""))
	if pet_id == "":
		return {}
	var k := String(data.get("k", "")) if data.get("k") is String else ""
	var skill := {}
	if k != "a":
		for s in PetData.get_pet(pet_id).get("skills", []):
			if String(s.id) == k:
				skill = s
				break
		if skill.is_empty():
			return {}
	var pt: Variant = data.get("p")
	if not (pt is Array) or (pt as Array).size() != 2:
		return {}
	var x := Online.num_f(pt[0], INF)
	var z := Online.num_f(pt[1], INF)
	if not is_finite(x) or not is_finite(z) or absf(x) > Online.WORLD_LIMIT or absf(z) > Online.WORLD_LIMIT:
		return {}
	return {"from": from, "pet": pet_id, "k": k, "skill": skill,
		"kind": "attack" if k == "a" else String(skill.get("kind", "")),
		"clip": "attack" if k == "a" else String(skill.get("clip", "attack")),
		"target": target_of(Online.num(data.get("e"), 0)), "at": Vector3(x, 0.0, z)}
