class_name EntitySync
extends Node
## Shared monsters of one zone (docs/ONLINE_PROTOCOL.md, "Shared combat" and "Shared
## world (zone-wide, v2)").
##
## Every hunting field and the guild war get one (Zone._ready). It sleeps while the game
## is offline or alone in its zone, so solo play is untouched. The zone host serves
## everyone in an open zone (party or not) and the party in an instanced one
## (Online.serves):
## - HOST (Online.is_zone_host, someone served here): the zone runs its monsters as always.
##   Each one gets a stable `eid`; `ent_snap` goes out 4 times a second (the ones near a
##   served player, at most SNAP_CAP, numbers rounded), `ent_event` for spawns, deaths
##   (killer and everyone's damage share, the host's own included), boss phases, big casts
##   (the danger circles) and the hits a monster lands on a real player (`hit {to, dmg}`,
##   that player's game applies it). An `ent_hit` is applied as Mob.take_hit(dmg, crit,
##   color, Online.remote_node(from)), so the threat system chases whoever hits hardest;
##   the monsters see the served players as victims (Mob._targets, Mob.strike).
## - MIRROR (Online.is_mirror_zone): the zone stops spawning and clears its own monsters;
##   the host's are shown as MirrorMob / MirrorFighter (same model, glide between
##   snapshots, HP bar, telegraphs). The hero's hits on them go out as `ent_hit`.
## - The reward of a kill (earns, Mob.party_share): a game rolls its own loot, EXP and quest
##   credit only when its hero's side dealt damage, or a party member in this zone did;
##   the host too. Nobody else gets anything (no kill stealing).
## - A new host (the old one left or dropped) takes over the monsters as they are: its
##   mirrors become real Mobs at the mirrored spot, HP and boss phase, under the same eids
##   (_take_over), so the other mirrors carry on; mirrors the new host does not confirm
##   within SWEEP_MS go. When nobody else is left (host null) the mirrors become this
##   game's own monsters the same way; only a broken link clears them (the zone spawns
##   its own again).
## Frames are paced by a token bucket (RATE a second) so the server's 30-a-second cap is
## never hit, whatever a skill does.

enum { OFF, HOST, MIRROR }

const SNAP_EVERY := 0.25
## A monster this close (flat metres) to any member is in the snapshot.
const NEAR := 44.0
const SNAP_CAP := 40
## Frames a second this node may send (the player's own `state` frames come on top).
const RATE := 16.0
const BURST := 20.0
const CHECK_EVERY := 0.2
## Hits on one mirror within this many seconds go out as one `ent_hit`.
const HIT_FLUSH := 0.1
## A snapshot names a mirror we never heard of: ask the host to describe it (msec).
const ASK_EVERY := 3000
## Guild war: the leader's war status this often (seconds).
const GW_EVERY := 1.0
## After a host change, mirrors the new host has not spoken of within this long go (msec).
const SWEEP_MS := 10000
## A take-over starts its new eids this far past the highest one seen.
const EID_GAP := 64
## How near (metres) a shared kill the hero has to stand to see "ไม่ได้ร่วมตี".
const NO_CREDIT_NEAR := 22.0
## Snapshot flags.
const F_HOSTILE := 1
const F_ACTING := 2
const F_DEAD := 4
const F_STUN := 8
const F_MOUNTED := 64

## The sync of the zone being played (null between zones).
static var current: EntitySync

var zone: Node3D
var key: StringName = &""
var mode := OFF
## Host: eid -> the zone's Mob. Mirror: eid -> the MirrorMob / MirrorFighter / bound gate.
var ents: Dictionary = {}
var mirrors: Dictionary = {}
var _check := 0.0
var _snap := 0.0
var _gw_timer := 0.0
var _gw_end_sent := false
var _flush := 0.0
var _tokens := BURST
var _next_eid := 1
## Host: eid -> {member id: damage dealt}.
var _share: Dictionary = {}
## Host: frames to send soon ([type, data]) and eids to (re)announce.
var _urgent: Array = []
var _lazy: Array = []
var _lazy_set: Dictionary = {}
var _members: Dictionary = {}
## Host: remote node instance id -> member id (rebuilt every CHECK_EVERY).
var _remote_ids: Dictionary = {}
## Host: whose ent_hit is being applied right now (the killer when it kills).
var _hitting := ""
## Mirror: eid -> {dmg, crit, fx} not sent yet, in order.
var _pending: Dictionary = {}
var _pending_order: Array = []
var _asked: Dictionary = {}
## Mirror: the host the mirrors came from, the highest eid seen, and after a host change
## the mirrors the new host has not confirmed yet (eid -> true) and when they go (msec).
var _host_was := ""
var _seen_top := 0
var _unconfirmed: Dictionary = {}
var _sweep_at := 0
## Reused every snapshot (no garbage on the host either).
var _cands: Array = []
var _member_pos: PackedVector3Array = PackedVector3Array()


## Whether [param p_zone] takes part in shared combat: hunting fields and the guild war,
## not the village, the tower, the arena or a ranked duel.
static func supports(p_zone: Node) -> bool:
	if p_zone == null or not ("data" in p_zone):
		return false
	var d: Dictionary = p_zone.data
	if bool(d.get("safe", false)) or bool(d.get("tower", false)) or bool(d.get("arena", false)):
		return false
	return not bool(d.get("pvp", false)) or bool(d.get("guildwar", false))


## True while this game hosts the shared monsters of its zone.
static func hosting() -> bool:
	return current != null and is_instance_valid(current) and current.mode == HOST


static func mirroring() -> bool:
	return current != null and is_instance_valid(current) and current.mode == MIRROR


## Mirror at build time (the zone then does not spawn its camps at all).
static func mirror_zone(zone_id: StringName) -> bool:
	return Online.is_online() and Online.is_mirror_zone(zone_id)


## A served real player's body (RemotePlayer) still standing, while hosting.
static func remote_alive(node: Variant) -> bool:
	if not hosting() or node == null or not is_instance_valid(node):
		return false
	var id := current.id_of(node)
	if id == "":
		return false
	if (node as Object).has_method("is_dead"):
		return not bool(node.call("is_dead"))
	var p: Variant = Online.players().get(id, {})
	if p is Dictionary:
		return String(p.get("anim", "")) != "dead" and int(p.get("hp", 1)) > 0
	return true


## Mob._credit: damage from a real player on one of the hosted monsters is counted here
## (per player id, for the `dead` share), not as the hero's side's. True when handled.
static func remote_credit(mob: Mob, attacker: Node, amount: int) -> bool:
	if not hosting():
		return false
	if current._hitting != "":
		# _on_ent_hit counts it.
		return true
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_in_group("remote_players"):
		return false
	var id := current.id_of(attacker)
	var eid := int(mob.get_meta("eid", 0))
	if id != "" and eid > 0 and amount > 0:
		var share: Dictionary = current._share.get(eid, {})
		share[id] = int(share.get(id, 0)) + amount
		current._share[eid] = share
	return true


## Host: the damage this game's party members in the zone dealt to [param mob] (their own
## games, through ent_hit); they count as the hero's side for the reward.
static func party_dealt(mob: Mob) -> int:
	if not hosting() or mob == null or not mob.has_meta("eid"):
		return 0
	var share: Dictionary = current._share.get(int(mob.get_meta("eid")), {})
	if share.is_empty():
		return 0
	var total := 0
	for id in Online.party_members_in_zone(current.key):
		total += maxi(0, int(share.get(id, 0)))
	return total


## Host: whether real players other than this game dealt damage to [param mob].
static func dealt_by_others(mob: Mob) -> bool:
	if not hosting() or mob == null or not mob.has_meta("eid"):
		return false
	var share: Dictionary = current._share.get(int(mob.get_meta("eid")), {})
	for id in share:
		if int(share[id]) > 0:
			return true
	return false


## A shared kill pays this game nothing: a small grey word over it when the hero is near.
static func no_credit(mob: Mob) -> void:
	if mob == null or not is_instance_valid(mob) or not mob.is_inside_tree():
		return
	var hero: Variant = mob.hero
	if hero == null or not is_instance_valid(hero) or (hero as Node3D).global_position.distance_to(mob.global_position) > NO_CREDIT_NEAR:
		return
	BattleVfx.floating_text(mob.get_parent(), mob.top_point() + Vector3(0, 0.6, 0), "ไม่ได้ร่วมตี", Color(0.62, 0.62, 0.62), 0.7)


## A monster's strike landed on a real player: that player's game applies it.
static func remote_struck(victim: Node, raw: float, source: Node) -> void:
	if hosting():
		current._hit_remote(victim, raw, source)


## A monster starts a telegraphed move: [param circles] are [position, radius, seconds]
## (the danger circles), [param clip] the animation, [param title] the move's name.
static func cast(mob: Node, circles: Array, clip := "attack", title := "") -> void:
	if not hosting() or mob == null or not is_instance_valid(mob) or not mob.has_meta("eid"):
		return
	current._send_cast(mob as Mob, circles, clip, title)


## The name of whoever [param node] is, for the war feed ("" when not a real player).
static func name_of(node: Variant) -> String:
	if current == null or not is_instance_valid(current) or node == null or not is_instance_valid(node):
		return ""
	var id := current.id_of(node)
	if id == "":
		return ""
	var p: Variant = Online.players().get(id, {})
	return String((p as Dictionary).get("name", (p as Dictionary).get("user", ""))) if p is Dictionary else ""


func setup(p_zone: Node3D) -> void:
	zone = p_zone
	key = StringName(p_zone.get("zone_id"))
	name = "EntitySync"


func _enter_tree() -> void:
	current = self
	if not Online.message.is_connected(_on_message):
		Online.message.connect(_on_message)
		Online.party_changed.connect(_recheck)
		Online.disconnected.connect(_on_disconnected)
		Online.host_changed.connect(_on_host_changed)


func _exit_tree() -> void:
	if current == self:
		current = null
	if Online.message.is_connected(_on_message):
		Online.message.disconnect(_on_message)
		Online.party_changed.disconnect(_recheck)
		Online.disconnected.disconnect(_on_disconnected)
		Online.host_changed.disconnect(_on_host_changed)


func is_mirror() -> bool:
	return mode == MIRROR


func is_host() -> bool:
	return mode == HOST


func _recheck() -> void:
	_check = 0.0


func _on_host_changed(_zone: StringName) -> void:
	_check = 0.0


func _on_disconnected() -> void:
	update_mode()


func _wanted() -> int:
	if not Online.is_online():
		return OFF
	if Online.is_zone_host(key):
		return HOST if not Online.serves(key).is_empty() else OFF
	if Online.is_mirror_zone(key):
		return MIRROR
	return OFF


## Looks at the link, the party and the host again and switches at once.
func update_mode() -> void:
	_check = CHECK_EVERY
	var want := _wanted()
	_refresh_remote_ids()
	if want == mode:
		if mode == MIRROR:
			_host_moved()
		return
	var old := mode
	mode = want
	if old == HOST:
		_stop_host()
	elif old == MIRROR:
		if mode == HOST or Online.is_online():
			# The old host left (and maybe nobody else is here now): this game runs the very
			# monsters it was showing. A broken link clears them instead (below).
			_take_over()
		else:
			_stop_mirror()
	if mode == HOST:
		_start_host()
	elif mode == MIRROR:
		_start_mirror()


func _process(delta: float) -> void:
	_tokens = minf(BURST, _tokens + RATE * delta)
	_check -= delta
	if _check <= 0.0:
		update_mode()
		if mode == HOST:
			_track_members()
	if mode == HOST:
		_host_tick(delta)
	elif mode == MIRROR:
		_flush -= delta
		if _flush <= 0.0:
			_flush = HIT_FLUSH
			_flush_hits()
		if _sweep_at > 0 and Time.get_ticks_msec() >= _sweep_at:
			_sweep()


func _spend() -> bool:
	if _tokens < 1.0:
		return false
	_tokens -= 1.0
	return true


# ---------------------------------------------------------------------------
# Host
# ---------------------------------------------------------------------------

func _start_host() -> void:
	_members.clear()
	_snap = 0.0
	_gw_end_sent = false
	_scan()
	_track_members()
	_announce_all()


func _stop_host() -> void:
	_urgent.clear()
	_lazy.clear()
	_lazy_set.clear()
	_members.clear()


## Who this game serves in the zone; someone new gets everything described again.
func _track_members() -> void:
	var fresh := false
	var now: Dictionary = {}
	for id in Online.serves(key):
		now[String(id)] = true
		if not _members.has(String(id)):
			fresh = true
	_members = now
	if fresh:
		_announce_all()


func _refresh_remote_ids() -> void:
	_remote_ids.clear()
	if not Online.is_online():
		return
	for id in Online.serves(key):
		var node := Online.remote_node(String(id))
		if node != null:
			_remote_ids[node.get_instance_id()] = String(id)


## The served player [param node] is (its RemotePlayer), or "".
func id_of(node: Variant) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var iid := (node as Object).get_instance_id()
	if _remote_ids.has(iid):
		return String(_remote_ids[iid])
	if not (node as Node).is_in_group("remote_players"):
		return ""
	for id in Online.serves(key):
		if Online.remote_node(String(id)) == node:
			_remote_ids[iid] = String(id)
			return String(id)
	return ""


## Shared entities without an eid get one (and are announced); the freed ones are gone.
func _scan() -> void:
	for group in ["mobs", "gw_fighters", "castle_gates"]:
		for node in get_tree().get_nodes_in_group(group):
			var mob := node as Mob
			if mob == null or mob.get_parent() != zone or mob.has_meta("eid") or mob.is_queued_for_deletion():
				continue
			if mob is MirrorMob or mob is MirrorFighter or mob is SummonMob or (mob is Rival and not (mob is GuildFighter)):
				continue
			if mob.is_dead() and not (mob is GuildFighter):
				continue
			_adopt(mob)
	for eid in ents.keys():
		if not is_instance_valid(ents[eid]) or (ents[eid] as Node).is_queued_for_deletion():
			ents.erase(eid)
			_share.erase(eid)
			_urgent.append(["ent_event", {"zone": String(key), "eid": eid, "ev": "gone", "data": {}}])


## [param eid]: the one it already had (a take-over), else a new one.
func _adopt(mob: Mob, eid := 0) -> void:
	if eid <= 0:
		eid = _next_eid
		_next_eid += 1
	else:
		_next_eid = maxi(_next_eid, eid + 1)
	mob.set_meta("eid", eid)
	ents[eid] = mob
	if mob is GuildFighter:
		(mob as GuildFighter).fell.connect(_on_fighter_fell)
	elif mob is CastleGate:
		(mob as CastleGate).broken.connect(_on_gate_broken)
	else:
		mob.died.connect(_on_died)
		if mob.is_boss:
			mob.phase_changed.connect(_on_phase)
	_queue_spawn(eid)


## [param first]: a member asked for this one, it goes before the rest.
func _queue_spawn(eid: int, first := false) -> void:
	if _lazy_set.has(eid):
		if not first:
			return
		_lazy.erase(eid)
	_lazy_set[eid] = true
	if first:
		_lazy.push_front(eid)
	else:
		_lazy.append(eid)


func _announce_all() -> void:
	for eid in ents:
		_queue_spawn(int(eid))


func _host_tick(delta: float) -> void:
	_snap -= delta
	if _snap <= 0.0:
		_snap = SNAP_EVERY
		_scan()
		if _spend():
			_send_snapshot()
	if zone.get("gw_match") != null:
		_gw_tick(delta)
	while not _urgent.is_empty() and _spend():
		var frame: Array = _urgent.pop_front()
		Online.send(String(frame[0]), frame[1])
	while not _lazy.is_empty() and _tokens >= 2.0 and _spend():
		var eid: int = _lazy.pop_front()
		_lazy_set.erase(eid)
		var mob: Variant = ents.get(eid)
		if mob != null and is_instance_valid(mob):
			Online.send("ent_event", {"zone": String(key), "eid": eid, "ev": "spawn", "data": describe(mob)})


static func _q(v: float, step := 0.1) -> float:
	return snappedf(v, step)


## What a member's game needs to build the mirror of [param mob].
func describe(mob: Mob) -> Dictionary:
	var at := mob.global_position
	var d := {"x": _q(at.x), "z": _q(at.z), "y": _q(mob.visual.rotation.y if mob.visual else 0.0, 0.01), "hp": mob.hp, "mhp": mob.max_hp}
	if mob is CastleGate:
		d["gate"] = (mob as CastleGate).gate_index
		d["dead"] = mob.is_dead()
		return d
	if mob is GuildFighter:
		var f := mob as GuildFighter
		var info := {"member": f.member, "profile": f._profile, "look": f._look, "difficulty": f.difficulty, "grade": f.grade, "tag": f.tag}
		d["f"] = var_to_str(info).replace("\n", "")
		d["team"] = f.team
		d["lead"] = f.is_leader
		d["def"] = float(f.stats.get("def", 0.0))
		d["g"] = f.guild_name
		d["sx"] = _q(f.spawn_point.x)
		d["sz"] = _q(f.spawn_point.z)
		d["dead"] = f.is_dead()
		return d
	d["m"] = String(mob.monster_id)
	d["lv"] = mob.level
	# Its home (the camp spot): a player that takes over as host keeps it there.
	d["hx"] = _q(mob.home.x)
	d["hz"] = _q(mob.home.z)
	if mob.phase > 0:
		d["p"] = mob.phase
	if mob.hostile:
		d["h"] = 1
	if mob == zone.get("_boss"):
		d["k"] = "field_boss"
	elif mob == zone.get("_wboss") or mob.has_meta("world_boss"):
		d["k"] = "world_boss"
		d["day"] = int(mob.get_meta("world_boss", 0))
	elif mob.has_meta("golden"):
		d["k"] = "golden"
		d["win"] = int(mob.get_meta("golden", -1))
	return d


func flags_of(mob: Mob) -> int:
	var f := 0
	if mob.hostile:
		f |= F_HOSTILE
	if mob._winding or Time.get_ticks_msec() < mob._anim_lock:
		f |= F_ACTING
	if mob.is_dead():
		f |= F_DEAD
	if mob._stun > 0.0:
		f |= F_STUN
	f |= (clampi(mob.phase, 0, 3) << 4)
	if mob is GuildFighter and (mob as GuildFighter).mount != null:
		f |= F_MOUNTED
	return f


func _send_snapshot() -> void:
	_member_pos.clear()
	var people: Dictionary = Online.players()
	for id in _members:
		var node := Online.remote_node(String(id))
		if node != null:
			_member_pos.append(node.global_position)
		else:
			var p: Variant = people.get(id, {})
			var pos: Variant = (p as Dictionary).get("pos") if p is Dictionary else null
			if pos is Array and (pos as Array).size() >= 3:
				_member_pos.append(Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
	_cands.clear()
	var everywhere := zone.get("gw_match") != null
	for eid in ents:
		var mob: Mob = ents[eid]
		if not is_instance_valid(mob):
			continue
		var best := INF
		for p in _member_pos:
			best = minf(best, Vector2(p.x - mob.global_position.x, p.z - mob.global_position.z).length())
		if everywhere or best <= NEAR:
			_cands.append([best, eid])
	if _cands.size() > SNAP_CAP:
		_cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		_cands.resize(SNAP_CAP)
	var rows: Array = []
	for c in _cands:
		var mob: Mob = ents[c[1]]
		var at := mob.global_position
		rows.append([c[1], _q(at.x), _q(at.z), _q(mob.visual.rotation.y if mob.visual else 0.0, 0.01), mob.hp, mob.max_hp, flags_of(mob)])
	Online.send("ent_snap", {"zone": String(key), "ents": rows})


func _event(eid: int, ev: String, data: Dictionary) -> void:
	_urgent.append(["ent_event", {"zone": String(key), "eid": eid, "ev": ev, "data": data}])


## Everyone's damage on [param mob]: the players' (ent_hit) and this game's own (the
## hero's side). A player rolls the kill's reward only with damage here (or its party's).
func _dead_data(eid: int, mob: Mob, killer: String) -> Dictionary:
	var share := {}
	var others := 0
	for id in _share.get(eid, {}):
		var dealt := int(_share[eid][id])
		share[String(id)] = dealt
		others += dealt
	# A guild-war fighter's damage is not split by side: the leader takes the rest.
	share[Online.my_id()] = maxi(0, mob.max_hp - others) if mob is GuildFighter else maxi(0, mob.party_damage)
	return {"killer": killer, "share": share}


func _on_died(mob: Mob) -> void:
	var eid := int(mob.get_meta("eid", 0))
	if eid <= 0 or mode != HOST:
		return
	var killer := _hitting if _hitting != "" else Online.my_id()
	_event(eid, "dead", _dead_data(eid, mob, killer))
	if mob.party_share() <= 0.0 and dealt_by_others(mob):
		no_credit(mob)
	ents.erase(eid)
	# The zone pays the kill from the share (Mob.party_share) in this same signal; the
	# share goes once everybody heard it.
	_forget_share.call_deferred(eid)
	_lazy_set.erase(eid)


func _forget_share(eid: int) -> void:
	if not ents.has(eid):
		_share.erase(eid)


func _on_fighter_fell(fighter: GuildFighter, killer: Node) -> void:
	var eid := int(fighter.get_meta("eid", 0))
	if eid <= 0 or mode != HOST:
		return
	var who := _hitting
	if who == "":
		who = id_of(killer)
	if who == "":
		who = Online.my_id() if killer == zone.get("hero") or killer == null else ("e%d" % int(killer.get_meta("eid", 0)) if killer.has_meta("eid") else "")
	_event(eid, "dead", _dead_data(eid, fighter, who))
	_share.erase(eid)


func _on_gate_broken(gate: CastleGate) -> void:
	var eid := int(gate.get_meta("eid", 0))
	if eid > 0 and mode == HOST:
		_event(eid, "dead", {"killer": _hitting if _hitting != "" else Online.my_id(), "share": {}})


func _on_phase(mob: Mob, p: int) -> void:
	if mode == HOST and mob.has_meta("eid"):
		_event(int(mob.get_meta("eid")), "phase", {"p": p})


func _send_cast(mob: Mob, circles: Array, clip: String, title: String) -> void:
	# Small monsters' moves only while the line has room (a boss's always go).
	if not mob.is_boss and not bool(mob.template.get("elite", false)) and _tokens < 6.0:
		return
	var near := false
	for id in _members:
		var node := Online.remote_node(String(id))
		if node == null or node.global_position.distance_to(mob.global_position) < NEAR:
			near = true
			break
	if not near:
		return
	var c: Array = []
	for item in circles:
		var at: Vector3 = item[0]
		c.append([_q(at.x), _q(at.z), _q(float(item[1])), _q(float(item[2]), 0.05)])
		if c.size() >= 12:
			break
	var data := {"c": c, "a": clip}
	if title != "":
		data["n"] = title
	_event(int(mob.get_meta("eid")), "cast", data)


func _hit_remote(victim: Node, raw: float, source: Node) -> void:
	var id := id_of(victim)
	if id == "" or raw <= 0.0:
		return
	var eid := int(source.get_meta("eid", 0)) if source != null and is_instance_valid(source) else 0
	_event(eid, "hit", {"to": id, "dmg": int(round(minf(raw, 1.0e9)))})


## A member's hit on one of our monsters, applied as if it stood here.
func _on_ent_hit(data: Dictionary) -> void:
	var eid := int(data.get("eid", 0))
	var mob: Variant = ents.get(eid)
	if mob == null or not is_instance_valid(mob):
		return
	var from := String(data.get("from", ""))
	var dmg := clampi(int(data.get("dmg", 0)), 0, 1000000000)
	var fx: Dictionary = data.get("fx") if data.get("fx") is Dictionary else {}
	if dmg <= 0 and fx.is_empty():
		_queue_spawn(eid, true)
		return
	var m := mob as Mob
	if m.is_dead():
		return
	var who := Online.remote_node(from)
	if dmg > 0:
		var share: Dictionary = _share.get(eid, {})
		share[from] = int(share.get(from, 0)) + mini(dmg, maxi(m.hp, 0))
		_share[eid] = share
		_hitting = from
		m.take_hit(dmg, bool(data.get("crit", false)), Color.WHITE, who)
		_hitting = ""
	if is_instance_valid(m) and not m.is_dead():
		_apply_fx(m, fx, who)


func _apply_fx(m: Mob, fx: Dictionary, who: Node3D) -> void:
	if fx.has("stun"):
		m.apply_stun(clampf(float(fx.stun), 0.0, 6.0))
	if fx.has("freeze"):
		m.apply_freeze(clampf(float(fx.freeze), 0.0, 6.0))
	if fx.has("slow"):
		m.apply_slow(clampf(float(fx.slow), 0.0, 8.0))
	if fx.get("burn") is Array and (fx.burn as Array).size() >= 2:
		m.apply_burn(maxf(0.0, float(fx.burn[0])), clampf(float(fx.burn[1]), 0.0, 10.0))
		if who != null:
			m.burn_source = who
	for mark in Mob.MARKS:
		if fx.get(mark) is Array and (fx[mark] as Array).size() >= 2:
			m.call("apply_" + mark, float(fx[mark][0]), clampf(float(fx[mark][1]), 0.0, 20.0))
	if fx.has("taunt") and who != null:
		m.taunt(who, clampf(float(fx.taunt), 0.0, 8.0))


## The leader's war, told to the members: clock, score, castle, the altar, the end.
func _gw_tick(delta: float) -> void:
	var war: GuildWarMatch = zone.get("gw_match")
	if war == null or war.mirror:
		return
	if war.state in ["ending", "done"]:
		if not _gw_end_sent and not war._result.is_empty():
			_gw_end_sent = true
			_event(0, "gw_end", {"won": bool(war._result.get("won", false)), "us": war.score[0], "them": war.score[1],
				"castle": String(war._result.get("castle", "")), "ours": bool(war._result.get("castle_ours", false)), "ot": war.overtime})
		return
	_gw_timer -= delta
	if _gw_timer > 0.0:
		return
	_gw_timer = GW_EVERY
	var cp: Array = []
	if not war.capture.is_empty():
		cp = [int(war.capture.team), _q(float(war.capture.progress)), bool(war.capture.get("paused", false))]
	_event(0, "gw", {"st": war.state, "tl": _q(war.time_left), "s": [war.score[0], war.score[1]], "o": war.castle_owner, "cp": cp, "ot": war.overtime})


# ---------------------------------------------------------------------------
# Mirror
# ---------------------------------------------------------------------------

func _start_mirror() -> void:
	_pending.clear()
	_pending_order.clear()
	_asked.clear()
	_unconfirmed.clear()
	_sweep_at = 0
	_host_was = Online.zone_host(key)
	if zone.has_method("enter_shared_mirror"):
		zone.call("enter_shared_mirror")


## [param taken_over]: this game hosts now and already made real monsters of the mirrors
## (_take_over); the zone does not fill its camps at once then.
func _stop_mirror(taken_over := false) -> void:
	for eid in mirrors:
		var m: Variant = mirrors[eid]
		if not is_instance_valid(m):
			continue
		if m is CastleGate:
			(m as CastleGate).sync_eid = 0
		else:
			(m as Node).queue_free()
	mirrors.clear()
	_pending.clear()
	_pending_order.clear()
	_unconfirmed.clear()
	_sweep_at = 0
	_host_was = ""
	var war: Variant = zone.get("gw_match")
	if war != null and is_instance_valid(war) and (war as GuildWarMatch).mirror:
		(war as GuildWarMatch).mirror_lost()
	if taken_over:
		if zone.has_method("resume_shared_takeover"):
			zone.call("resume_shared_takeover")
	elif zone.has_method("leave_shared_mirror"):
		zone.call("leave_shared_mirror")


## The old host is gone and this game hosts now: every living mirrored monster becomes a
## real Mob where it stands, with its HP, anger and boss phase, under the same eid (the
## other players' mirrors carry on); the zone counts them in its camps again
## (Zone.adopt_shared). New eids start past every eid seen.
func _take_over() -> void:
	var hero: Node3D = zone.get("hero")
	var top := _seen_top
	for eid in mirrors.keys():
		var m: Variant = mirrors[eid]
		top = maxi(top, int(eid))
		if not (m is MirrorMob) or not is_instance_valid(m) or (m as Mob).is_dead() or (m as Node).is_queued_for_deletion():
			continue
		var mirror := m as MirrorMob
		var mob := _real_mob(mirror, hero)
		mirrors.erase(eid)
		mirror.remove_from_group("mobs")
		mirror.queue_free()
		zone.add_child(mob)
		mob.visual.rotation.y = mob._yaw
		mob._bar.set_ratio(float(mob.hp) / float(maxi(1, mob.max_hp)))
		if mob.hp < mob.max_hp:
			mob._bar.visible = true
			mob._bar_until = Time.get_ticks_msec() * 0.001 + 6.0
		if zone.has_method("adopt_shared"):
			zone.call("adopt_shared", mob, mirror.kind)
		_adopt(mob, int(eid))
		if hero != null and is_instance_valid(hero) and hero.get("target") == mirror:
			hero.call("set_target", mob)
	_next_eid = maxi(_next_eid, top + 1 + EID_GAP)
	_stop_mirror(true)


## A real monster standing exactly as [param m] (the mirror of the old host's).
func _real_mob(m: MirrorMob, hero: Node3D) -> Mob:
	var mob := Mob.new()
	mob.setup(m.monster_id, m.level, m.home, hero)
	if m.kind in ["world_boss", "golden"]:
		mob.template = m.template.duplicate()
	for meta in ["world_boss", "golden", "field_boss"]:
		if m.has_meta(meta):
			mob.set_meta(meta, m.get_meta(meta))
	mob.max_hp = maxi(1, m.max_hp)
	mob.hp = clampi(m.hp, 1, mob.max_hp)
	mob.hostile = m.hostile
	mob.phase = m.phase
	# What the hero's side dealt to it while it was a mirror still counts for the reward.
	mob.party_damage = m.dealt
	mob._yaw = m._yaw
	mob.position = m.global_position + Vector3(0, 0.05, 0)
	return mob


## The mirrors' host changed (another player took over): the mirrors stay and the new
## host's frames go on with the same eids; those it never speaks of go after SWEEP_MS.
func _host_moved() -> void:
	var host := Online.zone_host(key)
	if host == _host_was:
		return
	_host_was = host
	_unconfirmed.clear()
	for eid in mirrors:
		if mirrors[eid] is MirrorMob:
			_unconfirmed[eid] = true
	_sweep_at = Time.get_ticks_msec() + SWEEP_MS if not _unconfirmed.is_empty() else 0
	_asked.clear()


func _sweep() -> void:
	_sweep_at = 0
	for eid in _unconfirmed:
		var m: Variant = mirrors.get(eid)
		if m is MirrorMob and is_instance_valid(m) and not (m as Mob).is_dead():
			mirrors.erase(eid)
			_pending.erase(eid)
			(m as Node).queue_free()
	_unconfirmed.clear()


## Whether this game rolls the reward of the host's kill of eid [param eid] (`dead` data
## [param d]): the hero's side hit it ([param dealt], some of it maybe not counted by the
## host yet), or the share names this game or a party member in this zone with damage.
## A host that sends no share at all (an older game) pays everyone, as before.
func earns(eid: int, d: Dictionary, dealt: int) -> bool:
	_unconfirmed.erase(eid)
	if dealt > 0:
		return true
	var share: Variant = d.get("share")
	if not (share is Dictionary):
		return true
	if Online.num((share as Dictionary).get(Online.my_id(), 0)) > 0:
		return true
	for id in Online.party_members_in_zone(key):
		if Online.num((share as Dictionary).get(String(id), 0)) > 0:
			return true
	return false


## A mirror was hit by the hero (or its party, its summons): queued for the host.
func forward(mob: Mob, amount: int, crit: bool) -> void:
	if mode != MIRROR or amount <= 0:
		return
	var p := _pending_for(int(mob.get_meta("mirror_eid", 0)))
	p.dmg = int(p.dmg) + amount
	p.crit = bool(p.crit) or crit


## A mirror was stunned, slowed, burnt, marked or taunted: the host applies it too.
func forward_fx(mob: Mob, kind: String, value: Variant) -> void:
	if mode != MIRROR:
		return
	var p := _pending_for(int(mob.get_meta("mirror_eid", 0)))
	(p.fx as Dictionary)[kind] = value


func _pending_for(eid: int) -> Dictionary:
	if not _pending.has(eid):
		_pending[eid] = {"dmg": 0, "crit": false, "fx": {}}
		_pending_order.append(eid)
	return _pending[eid]


## Damage of ours the host has not counted yet (the HP bar keeps it off).
func pending_damage(eid: int) -> int:
	return int((_pending[eid] as Dictionary).dmg) if _pending.has(eid) else 0


func _flush_hits() -> void:
	while not _pending_order.is_empty() and _spend():
		var eid: int = _pending_order.pop_front()
		var p: Dictionary = _pending[eid]
		_pending.erase(eid)
		if eid <= 0 or (int(p.dmg) <= 0 and (p.fx as Dictionary).is_empty() and not p.has("ask")):
			continue
		var frame := {"zone": String(key), "eid": eid, "dmg": int(p.dmg), "crit": bool(p.crit)}
		if not (p.fx as Dictionary).is_empty():
			frame["fx"] = p.fx
		Online.send("ent_hit", frame)


func _from_host(data: Dictionary) -> bool:
	return String(data.get("zone", "")) == String(key) and String(data.get("from", "")) == Online.zone_host(key)


func _on_message(type: String, data: Dictionary) -> void:
	match type:
		"ent_hit":
			if mode == HOST and String(data.get("zone", "")) == String(key):
				_on_ent_hit(data)
		"ent_snap":
			if mode == MIRROR and _from_host(data):
				_on_snap(data)
		"ent_event":
			if mode == MIRROR and _from_host(data):
				_on_event(data)
		"host", "party", "welcome", "leave":
			_check = 0.0


func _on_snap(data: Dictionary) -> void:
	var rows: Variant = data.get("ents", [])
	if not (rows is Array):
		return
	for row in rows:
		if not (row is Array) or (row as Array).size() < 7:
			continue
		var eid := int(row[0])
		_seen_top = maxi(_seen_top, eid)
		_unconfirmed.erase(eid)
		var m: Variant = mirrors.get(eid)
		if m == null or not is_instance_valid(m):
			_ask(eid)
			continue
		var hp := int(row[4]) - pending_damage(eid)
		if m is CastleGate:
			_gate_state(m as CastleGate, hp, int(row[5]))
		else:
			m.mirror_state(float(row[1]), float(row[2]), float(row[3]), hp, int(row[5]), int(row[6]))


## Asks the host (an empty ent_hit) to describe a mirror we never saw spawn.
func _ask(eid: int) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_asked.get(eid, -ASK_EVERY)) < ASK_EVERY:
		return
	_asked[eid] = now
	_pending_for(eid)["ask"] = true


func _on_event(data: Dictionary) -> void:
	var eid := int(data.get("eid", 0))
	var ev := String(data.get("ev", ""))
	var d: Dictionary = data.get("data") if data.get("data") is Dictionary else {}
	match ev:
		"spawn":
			_build_mirror(eid, d)
		"dead":
			var m: Variant = mirrors.get(eid)
			if m == null or not is_instance_valid(m):
				return
			if m is CastleGate:
				(m as CastleGate).sync_eid = 0
				mirrors.erase(eid)
				(m as CastleGate).breakable = true
				(m as CastleGate)._batter((m as CastleGate).hp + 1, false)
				return
			if not (m is MirrorFighter):
				mirrors.erase(eid)
			_pending.erase(eid)
			m.mirror_dead(d)
		"gone":
			var m: Variant = mirrors.get(eid)
			mirrors.erase(eid)
			if m != null and is_instance_valid(m) and not (m is CastleGate):
				(m as Node).queue_free()
		"cast":
			var m: Variant = mirrors.get(eid)
			if m != null and is_instance_valid(m) and m.has_method("mirror_cast"):
				m.mirror_cast(d)
		"phase":
			var m: Variant = mirrors.get(eid)
			if m != null and is_instance_valid(m) and m.has_method("mirror_phase"):
				m.mirror_phase(int(d.get("p", 0)))
		"hit":
			if String(d.get("to", "")) == Online.my_id():
				_hurt_hero(eid, float(d.get("dmg", 0)))
		"gw", "gw_end":
			var war: Variant = zone.get("gw_match")
			if war != null and is_instance_valid(war) and (war as GuildWarMatch).mirror:
				(war as GuildWarMatch).mirror_sync(ev, d)


func _build_mirror(eid: int, d: Dictionary) -> void:
	if eid <= 0:
		return
	_seen_top = maxi(_seen_top, eid)
	_unconfirmed.erase(eid)
	var known: Variant = mirrors.get(eid)
	if known != null and is_instance_valid(known):
		if not (known is CastleGate):
			var f := (F_DEAD if bool(d.get("dead", false)) else 0) | (F_HOSTILE if int(d.get("h", 0)) != 0 else 0) | (clampi(int(d.get("p", 0)), 0, 3) << 4)
			known.mirror_state(float(d.get("x", 0.0)), float(d.get("z", 0.0)), float(d.get("y", 0.0)), int(d.get("hp", 1)) - pending_damage(eid), int(d.get("mhp", 1)), f)
		return
	var hero: Node3D = zone.get("hero")
	if d.has("gate"):
		var war: Variant = zone.get("gw_match")
		if war == null or not is_instance_valid(war):
			return
		var k := int(d.gate)
		var gates: Array = (war as GuildWarMatch).gates
		if k < 0 or k >= gates.size():
			return
		var gate: CastleGate = gates[k]
		gate.sync_eid = eid
		gate.set_meta("mirror_eid", eid)
		mirrors[eid] = gate
		if bool(d.get("dead", false)):
			gate.set_broken_quietly()
		else:
			_gate_state(gate, int(d.get("hp", gate.hp)), int(d.get("mhp", gate.max_hp)))
		return
	if d.has("f"):
		var war: Variant = zone.get("gw_match")
		var fighter := MirrorFighter.build(self, eid, d, hero, war as GuildWarMatch if war != null and is_instance_valid(war) else null)
		if fighter == null:
			return
		mirrors[eid] = fighter
		zone.add_child(fighter)
		fighter.after_enter(d)
		return
	var mob := MirrorMob.new()
	mob.setup_mirror(self, eid, d, hero)
	mirrors[eid] = mob
	zone.add_child(mob)


func _gate_state(gate: CastleGate, hp: int, mhp: int) -> void:
	if gate.is_dead():
		return
	if mhp > 0:
		gate.max_hp = mhp
	gate.hp = clampi(hp, 1, gate.max_hp)
	gate._bar.set_ratio(float(gate.hp) / float(maxi(1, gate.max_hp)))


## A monster of the host's struck the hero: dodge and defence as usual.
func _hurt_hero(eid: int, raw: float) -> void:
	var hero: Variant = zone.get("hero")
	if hero == null or not is_instance_valid(hero) or (hero as Hero).is_dead() or raw <= 0.0:
		return
	var h := hero as Hero
	var src: Variant = mirrors.get(eid)
	var source: Node = src as Node if src != null and is_instance_valid(src) else null
	raw = minf(raw, 1.0e9)
	# In the guild war nobody falls to one blow (BurstGuard), as on the leader's side.
	if zone.get("gw_match") != null and "stats" in h and not h.stats.is_empty():
		var amount := maxi(1, int(round(HeroStats.mitigate(raw, h.effective_def()))))
		var allowed := BurstGuard.take(h.get_instance_id(), amount, int(h.stats.max_hp))
		if allowed < amount:
			raw *= float(allowed) / float(amount)
	h.take_damage(raw, source)


## Glides a mirror toward the host's position (no physics but falling onto the floor) and
## returns its flat speed this frame, for the walk / run animation. No allocations.
static func glide(body: Mob, goal: Vector3, goal_yaw: float, delta: float) -> Vector3:
	var before := body.global_position
	var dx := goal.x - before.x
	var dz := goal.z - before.z
	if dx * dx + dz * dz > 144.0:
		body.global_position = Vector3(goal.x, before.y, goal.z)
	else:
		var k := 1.0 - exp(-9.0 * delta)
		body.global_position = Vector3(before.x + dx * k, before.y, before.z + dz * k)
	body.velocity = Vector3(0.0, -0.5 if body.is_on_floor() else body.velocity.y - 18.0 * delta, 0.0)
	body.move_and_slide()
	body._yaw = lerp_angle(body._yaw, goal_yaw, 1.0 - exp(-10.0 * delta))
	if body.visual:
		body.visual.rotation.y = body._yaw
	var after := body.global_position
	var inv := 1.0 / maxf(delta, 0.0001)
	return Vector3((after.x - before.x) * inv, 0.0, (after.z - before.z) * inv)
