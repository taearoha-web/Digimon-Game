class_name BossWorld
extends RefCounted
## The field bosses live in the world, not around the hero: each levelling field's boss
## (ZoneData "boss": the field kings, the ★-field kings, the ★200-300 fields' and the
## sky isle's) is up until somebody brings it down, then down for its respawn time
## (the zone data's "respawn", the same as before: the Lv.100 boss's one minute
## included), then up again, whether the hero is there or not. Entering a field finds it
## standing at its spot, or finds its sign: who brought it down, when, and when it comes
## back (chip_text, the zone's sign).
##
## Who brings it down:
## - the hero (and its party): record_kill, kept in the save (Game.profile[KEY]) so a
##   reload or a trip out and back in does not bring it back early;
## - real online players: the zone host's game tells the server (`boss_kill`), the
##   server keeps each zone's last kill and tells everyone (receive);
## - the world players (WorldPlayers) who hunt there: worked out from the clock and the
##   roster alone (ai_kill), so every device sees the same ones. A field's time is cut in
##   slots of GAP times its respawn; in each slot at most one party or player of those
##   hunting that field at the time tries, at a moment of the slot no later than its
##   end less the respawn (so the world's own kills never overlap); whether it brings
##   the boss down is rolled from how many hunt there and how far above the boss they
##   stand (a field nobody hunts keeps its boss; the dragon god seldom falls to them).
##
## state(zone_id, t) is the one answer every screen, the zone and the chat use:
## {alive, killed_at, killer, party, ai, respawn_at, ...}. Only the boss's state is
## kept: nothing is simulated far away.

const KEY := "bossw"
## A slot of the world players' tries is GAP respawns long (GAPS per field).
const GAP := 3.0
const GAPS := {&"sky_dragon_isle": 5.0, &"void": 4.0}
## The chance one hunter fit for the boss (edge 1) brings it down in a slot.
const CHANCE := 0.45
const CHANCES := {&"sky_dragon_isle": 0.08, &"void": 0.25, &"eclipse_realm": 0.2, &"abyss": 0.35}
## No slot is ever surer than this.
const CHANCE_MAX := 0.92
## Who hunts where is looked up on a grid of this many real seconds (shared by every
## field, so one pass over the roster serves them all).
const CENSUS := 300.0
## Kills older than this are forgotten (save, memory): the longest respawn is minutes.
const KEEP := 3600.0
const SAVE_MAX := 48
const NAME_MAX := 24
const ZONE_MAX := 48

## -1: the world players' kills follow WorldPresence.enabled (off headless: tests see a
## boss that only real kills take down); 0 off; 1 on.
static var ai_mode := -1
## Kills heard from the server or seen here: zone -> {at, by}.
static var _real := {}
## "zone|slot": the world players' try of that slot did not happen here (the boss was
## being fought or watched on this screen when it came).
static var _held := {}
static var _slots := {}
static var _census := {}
static var _zones: Array[StringName] = []


## Every field with a world boss.
static func zones() -> Array[StringName]:
	if _zones.is_empty():
		ZoneData.ensure()
		for id in ZoneData.ZONES:
			if has_boss(id):
				_zones.append(id)
	return _zones


static func has_boss(zone_id: StringName) -> bool:
	ZoneData.ensure()
	var z: Variant = ZoneData.ZONES.get(zone_id)
	if not z is Dictionary or not (z as Dictionary).has("boss"):
		return false
	return String(z.get("scene", "")) == "field" and not z.get("arena", false) and not z.get("tower", false) and not z.get("pvp", false)


static func boss(zone_id: StringName) -> Dictionary:
	return ZoneData.ZONES[zone_id].boss if has_boss(zone_id) else {}


static func respawn(zone_id: StringName) -> float:
	return float(boss(zone_id).get("respawn", 60.0))


static func boss_name(zone_id: StringName) -> String:
	var b := boss(zone_id)
	return String(MonsterData.get_monster(b.monster).name) if not b.is_empty() else ""


static func ai_on() -> bool:
	return ai_mode == 1 or (ai_mode == -1 and WorldPresence.enabled)


# --- The answer ----------------------------------------------------------------------

## The boss of [param zone_id] at world time [param t] (WorldPresence.clock() when < 0):
## {zone, monster, name, alive, killed_at (0 never), killer ("" never), party (people in
## the killer's party, 1 alone), ai (a world player's kill), respawn, respawn_at}.
static func state(zone_id: StringName, t: float = -1.0) -> Dictionary:
	if t < 0.0:
		t = WorldPresence.clock()
	var out := {"zone": zone_id, "monster": boss(zone_id).get("monster", &""), "name": boss_name(zone_id), "alive": true,
		"killed_at": 0.0, "killer": "", "party": 1, "ai": false, "respawn": respawn(zone_id), "respawn_at": 0.0}
	if not has_boss(zone_id):
		return out
	var r := respawn(zone_id)
	var last := {}
	var real := latest_real(zone_id)
	var k := float(real.at) if not real.is_empty() and float(real.at) <= t else -INF
	if ai_on():
		var slot := slot_of(zone_id, t)
		if not _held.has("%s|%d" % [zone_id, slot]):
			var c := ai_kill(zone_id, slot)
			# A try while the boss was still down from a real kill did not happen.
			if not c.is_empty() and float(c.at) <= t and float(c.at) >= k + r:
				last = c
	if last.is_empty() and k > -INF:
		last = {"at": k, "killer": String(real.by), "party": 1, "ai": bool(real.get("ai", false))}
	if last.is_empty():
		return out
	out.killed_at = float(last.at)
	out.killer = String(last.killer)
	out.party = int(last.get("party", 1))
	out.ai = bool(last.get("ai", false))
	out.respawn_at = float(last.at) + r
	out.alive = t >= out.respawn_at
	return out


## The bosses brought down within [param within] seconds before [param t], newest first
## (the chat: "who killed which boss" is always one of these).
static func recent(t: float = -1.0, within := 900.0) -> Array:
	if t < 0.0:
		t = WorldPresence.clock()
	var out: Array = []
	for id in zones():
		var s := state(id, t)
		if float(s.killed_at) > 0.0 and t - float(s.killed_at) <= within:
			out.append(s)
	out.sort_custom(func(a, b): return float(a.killed_at) > float(b.killed_at))
	return out


## "ปาร์ตี้ของ X" for a party's kill, else the name.
static func killer_text(s: Dictionary) -> String:
	if String(s.get("killer", "")) == "":
		return ""
	return "ปาร์ตี้ของ %s" % s.killer if int(s.get("party", 1)) > 1 else String(s.killer)


static func ago_text(seconds: float) -> String:
	if seconds < 60.0:
		return "เมื่อสักครู่"
	if seconds < 3600.0:
		return "เมื่อ %d นาทีก่อน" % int(seconds / 60.0)
	return "เมื่อ %d ชั่วโมงก่อน" % int(seconds / 3600.0)


static func clock_text(seconds: float) -> String:
	var s := maxi(0, int(ceil(seconds)))
	return "%02d:%02d" % [s / 60, s % 60]


## The HUD line of a boss that is down: "ราชาเห็ดยักษ์ ถูก X ปราบเมื่อ 3 นาทีก่อน •
## เกิดใหม่ใน 02:15", "" while it is up.
static func chip_text(zone_id: StringName, t: float = -1.0) -> String:
	if t < 0.0:
		t = WorldPresence.clock()
	var s := state(zone_id, t)
	if bool(s.alive) or not has_boss(zone_id):
		return ""
	return "%s ถูก %s ปราบ%s • เกิดใหม่ใน %s" % [s.name, killer_text(s), ago_text(t - float(s.killed_at)), clock_text(float(s.respawn_at) - t)]


# --- Real kills ----------------------------------------------------------------------

## The latest real kill of the zone (this game's save, or heard): {at, by} or {}.
static func latest_real(zone_id: StringName) -> Dictionary:
	var best: Dictionary = _real.get(String(zone_id), {})
	if Game.has_profile and Game.profile.get(KEY) is Dictionary:
		var mine: Variant = Game.profile[KEY].get(String(zone_id))
		if mine is Dictionary and (best.is_empty() or float(mine.get("at", 0)) > float(best.at)):
			best = {"at": float(mine.get("at", 0)), "by": String(mine.get("by", ""))}
	return best


## The boss of [param zone_id] fell to [param by] at [param t] (now when < 0), here: kept
## in memory and, [param save], in the hero's save.
static func record_kill(zone_id: StringName, by: String, t: float = -1.0, save := true) -> void:
	if not has_boss(zone_id):
		return
	if t < 0.0:
		t = WorldPresence.clock()
	var who := by.strip_edges().left(NAME_MAX)
	_real[String(zone_id)] = {"at": float(int(t)), "by": who}
	if save and Game.has_profile:
		if not Game.profile.get(KEY) is Dictionary:
			Game.profile[KEY] = {}
		var book: Dictionary = Game.profile[KEY]
		book[String(zone_id)] = {"at": int(t), "by": who}
		prune(book, t)


## Drops old and unknown entries, keeps at most SAVE_MAX.
static func prune(book: Dictionary, t: float) -> void:
	for id in book.keys():
		var e: Variant = book[id]
		if not e is Dictionary or t - float(e.get("at", 0)) > KEEP or not has_boss(StringName(String(id))):
			book.erase(id)
	while book.size() > SAVE_MAX:
		book.erase(book.keys()[0])


## A save's record (Game._valid_profile): {zone: {at: int, by: text}}.
static func valid(book: Variant) -> bool:
	if not book is Dictionary or (book as Dictionary).size() > 256:
		return false
	for id in book:
		var e: Variant = book[id]
		if not id is String or (id as String).length() > ZONE_MAX or not e is Dictionary:
			return false
		var at: Variant = e.get("at")
		if not (at is int or at is float) or float(at) < 0.0 or float(at) > 1e11 or not e.get("by", "") is String or String(e.get("by", "")).length() > 64:
			return false
	return true


## A frame from the server (Online): `boss_kill` {zone, name, ago} (a real player's kill
## just now) or `boss_state` {bosses: [{zone, name, ago}]} (the server's book on joining).
static func receive(msg: Dictionary) -> void:
	var list: Array = msg.get("bosses", []) if msg.get("bosses") is Array else [msg]
	var now := WorldPresence.clock()
	for e in list.slice(0, 64):
		if not e is Dictionary:
			continue
		var zone_id := StringName(String(e.get("zone", "")).left(ZONE_MAX))
		var ago := float(e.get("ago", 0)) / 1000.0 if (e.get("ago") is int or e.get("ago") is float) else -1.0
		if not has_boss(zone_id) or ago < 0.0 or ago > KEEP:
			continue
		var at := now - ago
		var before := latest_real(zone_id)
		if not before.is_empty() and float(before.at) >= at - 2.0:
			continue
		var who := String(e.get("name", "")).strip_edges().left(NAME_MAX)
		_real[String(zone_id)] = {"at": at, "by": who}
		if String(msg.get("t", "")) == "boss_kill" and who != "":
			Game.world_chat.emit(Announcer.SPEAKER, "%s ปราบ %s ที่%sแล้ว!" % [who, boss_name(zone_id), ZoneData.get_zone(zone_id).name], Color("7dffd8"))


# --- The world players' kills --------------------------------------------------------

static func slot_len(zone_id: StringName) -> float:
	return respawn(zone_id) * float(GAPS.get(zone_id, GAP))


static func _phase(zone_id: StringName) -> float:
	return float(WorldPlayers.START_UNIX) + float(hash("bossw_phase|%s" % zone_id) % 1000) / 1000.0 * slot_len(zone_id)


static func slot_of(zone_id: StringName, t: float) -> int:
	return int(floor((t - _phase(zone_id)) / slot_len(zone_id)))


## Not here: the world players' try in the slot of [param t] (the boss was being fought
## or watched on this screen when it came; another game may still see it).
static func hold(zone_id: StringName, t: float = -1.0) -> void:
	if t < 0.0:
		t = WorldPresence.clock()
	_held["%s|%d" % [zone_id, slot_of(zone_id, t)]] = true


## The world players' kill of slot [param slot] of [param zone_id]: {at, killer, index,
## party, ai: true} or {} (nobody fit hunted there, or the roll said no). The same on
## every device: the slot's own seed, and who hunts where from the roster and the clock.
static func ai_kill(zone_id: StringName, slot: int) -> Dictionary:
	var key := "%s|%d" % [zone_id, slot]
	if _slots.has(key):
		return _slots[key]
	var out := {}
	var r := respawn(zone_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bossw|%s|%d" % [zone_id, slot])
	var at := _phase(zone_id) + float(slot) * slot_len(zone_id) + rng.randf() * (slot_len(zone_id) - r)
	var roll := rng.randf()
	var pick := rng.randf()
	if at >= float(WorldPlayers.START_UNIX):
		var fit: Array = []
		var miss := 1.0
		var base := float(CHANCES.get(zone_id, CHANCE))
		for h in census(zone_id, at):
			var e := edge(zone_id, int(h[1]), int(h[2]))
			if e <= 0.0:
				continue
			fit.append([int(h[0]), e])
			miss *= 1.0 - minf(0.95, base * e)
		if not fit.is_empty() and roll < minf(CHANCE_MAX, 1.0 - miss):
			out = _killer(zone_id, at, fit, pick)
	if _slots.size() > 512:
		_slots.clear()
	_slots[key] = out
	return out


## How far above the boss a hunter of level / stars stands: 0 (not fit to take it on)
## to 1.5. Lv.100 bosses of a ★ field go by the field's stars, the others by level.
static func edge(zone_id: StringName, level: int, stars: int) -> float:
	var b := boss(zone_id)
	var need := int(b.get("star", ZoneData.ZONES[zone_id].get("star", 0)))
	if need > 0:
		if level < Game.MAX_LEVEL:
			return 0.0
		return clampf(float(stars - need + 10) / 40.0, 0.0, 1.5)
	return clampf((float(level) + float(stars) * 0.2 - float(b.level) + 6.0) / 8.0, 0.0, 1.5)


## Who of [param fit] ([index, edge]) took it: picked by edge, still hunting there at
## [param at] and not with the hero; its party's leader names a party's kill.
static func _killer(zone_id: StringName, at: float, fit: Array, pick: float) -> Dictionary:
	var total := 0.0
	for f in fit:
		total += float(f[1])
	var start := 0
	var acc := 0.0
	for k in fit.size():
		acc += float(fit[k][1])
		if pick * total < acc:
			start = k
			break
	for n in fit.size():
		var i := int(fit[(start + n) % fit.size()][0])
		if Game.in_party(i):
			continue
		var h := WorldParties.hunter(i, at)
		if h.is_empty() or StringName(h.zone) != zone_id:
			continue
		var party := WorldParties.party_of(i, at, false)
		var lead := int(party.get("leader", i)) if not party.is_empty() else i
		return {"at": at, "killer": String(WorldPlayers.entry(lead).name), "index": i,
			"party": maxi(1, (party.get("members", []) as Array).size()), "ai": true}
	return {}


## The hunters of [param zone_id] around [param at]: [[index, level, stars]], from one
## pass over the roster per CENSUS step for every field.
static func census(zone_id: StringName, at: float) -> Array:
	var step := int(floor(at / CENSUS))
	if not _census.has(step):
		var t := float(step) * CENSUS
		var by := {}
		for i in WorldPlayers.size():
			if t < WorldPlayers.joined_at(i):
				continue
			var h := WorldParties.hunter(i, t)
			if h.is_empty():
				continue
			if not by.has(h.zone):
				by[h.zone] = []
			by[h.zone].append([i, int(h.level), int(h.stars)])
		if _census.size() > 8:
			_census.clear()
		_census[step] = by
	return _census[step].get(zone_id, [])


## Forgets everything worked out or heard (tests).
static func reset() -> void:
	_real.clear()
	_held.clear()
	_slots.clear()
	_census.clear()
