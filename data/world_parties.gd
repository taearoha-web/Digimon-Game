class_name WorldParties
extends RefCounted
## The world players (WorldPlayers) party up among themselves like real players: two to
## five people hunting the same field at a similar level team up for a while, then the
## party breaks up (someone logs off, the slot ends, they level apart) and new ones form.
##
## Nothing is stored or sent: who partied with whom is worked out from the roster and the
## clock alone, so every device (and every real player of an online zone) sees the same
## parties at the same moment. Time is cut in SLOT real seconds (each field's slots start
## at a moment of their own, so not every party in the world changes at once); at the
## start of a slot the online hunters of a field who feel like a party this time (taste,
## by play style and person) are grouped by level (BAND levels, STAR_BAND stars at
## Lv.100), guild mates and old buddies first. During the slot a party only loses people:
## those who log off, and anyone the hero takes into its own party (Game.in_party); a
## party down to one person is over.
##
## Partying pays like it does for real players: a player earns EXP_BONUS more while it
## hunts in a party, for the share of its play it spends in one (its taste), so the
## players who like parties level a little faster (WorldPlayers.party_work).

## Real seconds of a party slot (parties form at its start and last until its end).
const SLOT := 1800.0
const SIZE_MIN := 2
const SIZE_MAX := 5
## Odds of the size a party aims for (2, 3, 4, 5 people).
const SIZE_ODDS := [0.3, 0.3, 0.2, 0.2]
## How far apart in level (below Lv.100) and in stars (at Lv.100) a party's people may be.
const BAND := 8
const STAR_BAND := 30
## A player needs at least this many real seconds left in its session to start a party.
const MIN_LEFT := 600.0
## Partying earns this much more EXP than hunting alone (on the share of play spent in one).
const EXP_BONUS := 0.2
## How much each play style likes to party (the share of its hunting time it looks for
## one). Stall keepers never do; players abroad mostly go alone. Everyone with a play
## schedule is hardcore now (WorldPlayers.STYLES), a grinder who still parties often.
const STYLE_TASTE := {"hardcore": 0.45, "regular": 0.55, "student": 0.65, "night_owl": 0.45, "weekend": 0.55,
	"casual": 0.5, "daytime": 0.5, "early": 0.4, "overseas": 0.3, "afk": 0.0}
## About one player in LONER is a loner: it seldom parties at all.
const LONER := 7
const LONER_TASTE := 0.15

## slot key -> Array of parties ({id, zone, leader, members, slot, from, until}) as formed
## at the slot's start (before anyone left).
static var _formed := {}


## How much player i likes to party (0..1): its style's taste, its own way (0.6-1.4 of it),
## and a loner's little.
static func taste(i: int) -> float:
	var hit: Variant = _taste.get(i)
	if hit != null:
		return hit
	var value := _work_taste(WorldPlayers.entry(i))
	_taste[i] = value
	return value


## Per player: its taste (fixed by name and style).
static var _taste := {}


static func _work_taste(e: Dictionary) -> float:
	var base := float(STYLE_TASTE.get(String(e.style), 0.4))
	if base <= 0.0:
		return 0.0
	if hash("loner|%s" % e.name) % LONER == 0:
		return LONER_TASTE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("party_taste|%s" % e.name)
	return clampf(base * rng.randf_range(0.6, 1.4), 0.0, 0.9)


## Whether players i and j are old buddies (they party together first, like friends do).
static func buddies(i: int, j: int) -> bool:
	if i == j:
		return false
	var a := String(WorldPlayers.entry(mini(i, j)).name)
	var b := String(WorldPlayers.entry(maxi(i, j)).name)
	return hash("buddy|%s|%s" % [a, b]) % 9 == 0


## The slot of `zone` that real time t falls in, and its start.
static func slot_of(zone: StringName, t: float) -> int:
	return int(floor((t - _phase(zone)) / SLOT))


static func slot_start(zone: StringName, slot: int) -> float:
	return float(slot) * SLOT + _phase(zone)


## Each field's slots start at a moment of its own.
static func _phase(zone: StringName) -> float:
	return float(hash("party_phase|%s" % zone) % 1000) / 1000.0 * SLOT + float(WorldPlayers.START_UNIX)


## Where player i hunts at real time t and at what, worked out from its schedule alone (no
## party EXP of this device, so every device agrees): {zone, level, stars, point, end} or
## {} when it is not out hunting (offline, a stall keeper, an endgame break).
static func hunter(i: int, t: float) -> Dictionary:
	if WorldPlayers.in_town_style(i) or taste(i) <= 0.0:
		return {}
	var s := WorldPlayers.session_at(i, t)
	if s.is_empty():
		return {}
	var p := WorldPlayers.progress_for(WorldPlayers.played_minutes(i, t), WorldPlayers.efficiency(i), schedule_extra(i, t))
	var plan := WorldPlayers.endgame_plan(i, float(s[0]), int(p.level), int(p.stars), bool(p.divine))
	if String(plan.doing) not in ["hunt", "boss"]:
		return {}
	return {"zone": StringName(plan.place), "level": int(p.level), "stars": int(p.stars),
		"point": int(p.level) + int(p.stars), "end": float(s[1])}


## The probe minutes player i's schedule alone has added by real time t on top of its
## play (a veteran's head start, the Halloween potions, partying), the same on every device.
static func schedule_extra(i: int, t: float) -> float:
	var extra := WorldPlayers.head_work(i)
	var played := WorldPlayers.played_minutes(i, t)
	var eff := WorldPlayers.efficiency(i)
	if t > float(WorldEvents.HALLOWEEN_START):
		var from := WorldPlayers.played_minutes(i, float(WorldEvents.HALLOWEEN_START))
		var last := WorldPlayers.played_minutes(i, float(WorldEvents.HALLOWEEN_END))
		extra += maxf(0.0, minf(played, last) - from) * eff * WorldPlayers.halloween_share(i) * WorldPlayers.HALLOWEEN_EXTRA
	extra += played * eff * taste(i) * EXP_BONUS
	return extra


## The parties of `zone` formed at the start of its slot `slot` (before anyone left).
static func formed(zone: StringName, slot: int) -> Array:
	var key := "%s|%d" % [zone, slot]
	if _formed.has(key):
		return _formed[key]
	var all := _form_all(slot_start(zone, slot), zone, slot)
	if _formed.size() > 96:
		_formed.clear()
	_formed[key] = all
	return all


## Groups the hunters of `zone` who feel like a party at real time t0 (its slot's start).
static func _form_all(t0: float, zone: StringName, slot: int) -> Array:
	var pool: Array = []
	for i in WorldPlayers.size():
		if t0 < WorldPlayers.joined_at(i):
			continue
		var h := hunter(i, t0)
		if h.is_empty() or StringName(h.zone) != zone or float(h.end) - t0 < MIN_LEFT:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("wants_party|%s|%s|%d" % [WorldPlayers.entry(i).name, zone, slot])
		if rng.randf() >= taste(i):
			continue
		h["index"] = i
		pool.append(h)
	# The strongest first: each party gathers round the strongest one left (its leader).
	pool.sort_custom(func(a, b): return int(a.point) > int(b.point) or (int(a.point) == int(b.point) and int(a.index) < int(b.index)))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("party_sizes|%s|%d" % [zone, slot])
	var out: Array = []
	var taken := {}
	for lead in pool:
		var li := int(lead.index)
		if taken.has(li):
			continue
		var want := _roll_size(rng)
		var near: Array = []
		for o in pool:
			var oi := int(o.index)
			if oi == li or taken.has(oi) or not fits(lead, o):
				continue
			near.append(o)
		# Guild mates and buddies first, then the closest in level.
		var g := int(WorldPlayers.entry(li).guild)
		near.sort_custom(func(a, b):
			var ka := _affinity(li, g, int(a.index)) * 1000 - absi(int(a.point) - int(lead.point))
			var kb := _affinity(li, g, int(b.index)) * 1000 - absi(int(b.point) - int(lead.point))
			return ka > kb or (ka == kb and int(a.index) < int(b.index)))
		var members: Array[int] = [li]
		for o in near:
			if members.size() >= want:
				break
			members.append(int(o.index))
		if members.size() < SIZE_MIN:
			continue
		for m in members:
			taken[m] = true
		out.append({"id": "%s|%d|%d" % [zone, slot, li], "zone": zone, "slot": slot, "leader": li, "members": members,
			"from": t0, "until": t0 + SLOT})
	return out


static func _roll_size(rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	for k in SIZE_ODDS.size():
		roll -= float(SIZE_ODDS[k])
		if roll < 0.0:
			return SIZE_MIN + k
	return SIZE_MAX


## 2: a buddy, 1: a guild mate (the roster's side, the guild they will join), 0: anyone.
static func _affinity(i: int, guild: int, j: int) -> int:
	if buddies(i, j):
		return 2
	return 1 if guild > 0 and int(WorldPlayers.entry(j).guild) == guild else 0


## Whether two hunters (hunter()) are close enough in level to party: BAND levels apart
## below Lv.100, STAR_BAND stars apart at Lv.100 (a Lv.100 never with one below).
static func fits(a: Dictionary, b: Dictionary) -> bool:
	var top_a := int(a.level) >= Game.MAX_LEVEL
	var top_b := int(b.level) >= Game.MAX_LEVEL
	if top_a != top_b:
		return false
	if top_a:
		return absi(int(a.stars) - int(b.stars)) <= STAR_BAND
	return absi(int(a.level) - int(b.level)) <= BAND


## Parties are looked at in steps of this many real seconds (who logged off is seen
## within one step, the same moment on every device).
const STEP := 30.0
## "zone|slot|step" -> {member index: the party as it stood at that step}, and the
## hunters by "index|step".
static var _now := {}
static var _hunters := {}


## Forgets every party worked out so far (tests: the same parties come out again).
static func clear_cache() -> void:
	_formed.clear()
	_now.clear()
	_hunters.clear()
	_taste.clear()


## hunter() kept for the step of real time t.
static func hunter_at(i: int, t: float) -> Dictionary:
	var tb := floorf(t / STEP) * STEP
	var key := "%d|%d" % [i, int(tb / STEP)]
	if _hunters.has(key):
		return _hunters[key]
	if _hunters.size() > 2048:
		_hunters.clear()
	var h := hunter(i, tb)
	_hunters[key] = h
	return h


## The party player i is in at real time t, as it stands then: {id, zone, leader (the
## first of its people still there), members (leader first), from, until}, or {} alone.
## Those who logged off, moved on to another field or went with the hero (Game.in_party;
## `skip_hero` false keeps them) have left it; one left alone is no party.
static func party_of(i: int, t: float, skip_hero := true) -> Dictionary:
	if i < 0 or i >= WorldPlayers.size() or WorldPlayers.in_town_style(i) or taste(i) <= 0.0:
		return {}
	if skip_hero and _with_hero(i):
		return {}
	var h := hunter_at(i, t)
	if h.is_empty():
		return {}
	var p: Variant = _table(StringName(h.zone), t).get(i)
	if p == null:
		return {}
	if not skip_hero:
		return p
	var party := p as Dictionary
	var left: Array[int] = []
	for m in party.members:
		if not _with_hero(int(m)):
			left.append(int(m))
	if left.size() == (party.members as Array).size():
		return party
	if left.size() < SIZE_MIN:
		return {}
	var out := party.duplicate()
	out["members"] = left
	out["leader"] = left[0]
	return out


## The parties of `zone` at the step of real time t: member -> party, with only the people
## still online and still hunting this field (the hero's own party not looked at here).
static func _table(zone: StringName, t: float) -> Dictionary:
	var slot := slot_of(zone, t)
	var step := int(floorf(t / STEP))
	var key := "%s|%d|%d" % [zone, slot, step]
	if _now.has(key):
		return _now[key]
	var table := {}
	for p in formed(zone, slot):
		var left: Array[int] = []
		for m in p.members:
			var h := hunter_at(int(m), t)
			if not h.is_empty() and StringName(h.zone) == zone:
				left.append(int(m))
		if left.size() < SIZE_MIN:
			continue
		var now_p: Dictionary = p.duplicate()
		now_p["members"] = left
		now_p["leader"] = left[0]
		for m in left:
			table[m] = now_p
	if _now.size() > 256:
		_now.clear()
	_now[key] = table
	return table


static func _with_hero(i: int) -> bool:
	return Game.in_party(i)


## Every party in the world at real time t (each once), for the registry and tests.
static func parties_at(t: float) -> Array:
	var seen := {}
	var out: Array = []
	for i in WorldPlayers.size():
		var p := party_of(i, t)
		if p.is_empty() or seen.has(String(p.id)):
			continue
		seen[String(p.id)] = true
		out.append(p)
	return out


## The party's name as players call it: "ปาร์ตี้ของ <leader>".
static func label(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	return "ปาร์ตี้ของ %s" % String(WorldPlayers.entry(int(p.leader)).name)


## Asked into the hero's party while in a party of its own, a player now and then says
## no politely (the same answer for the same party: about one ask in REFUSE).
const REFUSE := 4
static func refuses(i: int, t: float) -> bool:
	var p := party_of(i, t)
	if p.is_empty():
		return false
	return hash("refuse|%s|%s" % [WorldPlayers.entry(i).name, p.id]) % REFUSE == 0
