class_name WorldGear
extends RefCounted
## What every world player really wears, and how it got there: a forge simulation run
## the same way on every device from the roster alone (no saved state). A player's
## life is played out in its own "work" (the probe minutes of WorldPlayers.work_at: real
## minutes played times its efficiency, plus its party EXP; it only grows), chunk by
## chunk on a fixed grid (_edge), so extending it later gives the very same answer:
##
## * Kills: KILLS_* (the auto-hunt kills per probe minute pace_probe measured in the
##   field of its level / stars) times the chunk; the kills roll the hero's real drop
##   chances: ItemData.JEWEL_DROP in the levelling and star fields; from ★200 (the drowned
##   abyss and the lotus sanctum, which share one drop table: EndgameFields) its jewels,
##   0.1% set core, Lotus Scales (SCALE_DROP) and divine pieces (DIVINE_DROP); the
##   feathers of ItemData.feather_chance; every mount's own material (MountData drop); Lv.100
##   wings in the star fields (WING_DROP, Zone.STAR_WING_DROP). Only its own class's
##   pieces and wings are kept (ItemData.OWN_CLASS_DROP). A chunk's count is its expected
##   count with the fraction rolled on the player's own seeded rng.
## * Finds: a piece per slot every level band (WorldPlayers' finds: some bands miss), the
##   star tiers' pieces after ★50/100/150/200, the divine set's four pieces as its divine
##   hours go by (WorldPlayers.DIVINE_HOURS); worn when better than what it has (its +
##   counts). A find comes at +0.
## * The forge, with the hero's own rules, every chunk:
##   1. the 250★ set (from ★250, SetGearData.SLOTS order): weapon / armour / helm / boots
##      each take the divine piece of that slot at +10 or more, ring and amulet their Lotus
##      Scales, and every try a set core and the jewels (SetGearData.recipe), at its
##      chance; a success uses the divine piece / scales up, a failed try loses only the
##      core and the jewels;
##   2. +1 for the lowest worn piece (ItemData.enhance_cost / enhance_chance, up to +15;
##      while a set piece waits for its divine piece's +10, that piece first; a failed try
##      uses up the jewels and keeps the grade, as at the hero's forge, so a + never drops);
##   3. the mount (MountData.cost / chance: the wolf to Lv.5, then the stag, the griffin,
##      the drake), for the players who take up mounts (WorldPlayers.MOUNT_SHARE);
##   4. from ★100 the 100★ wings (a chaos jewel and a feather, StarWingData.CRAFT_CHANCE).
##
## Every step is an event ({at, kind, slot, from, to, item}) the chats can quote; gear(i, t)
## is the state after the events up to t. A player's simulation is kept and only ever
## extended (snapshots every SNAP events make a read at any t a short replay), and the
## state read for a moment is kept per player and event count.

## The chunk grid: CHUNK_GROWTH of the work so far, CHUNK_MIN..CHUNK_MAX probe minutes.
const CHUNK_MIN := 2.5
const CHUNK_MAX := 120.0
const CHUNK_GROWTH := 0.1
## Kills per probe minute of auto-hunting (pace_probe, warrior, 40 s a sample: Lv.5
## meadow 16.5, Lv.20 desert 42, Lv.60 swamp 46.5, Lv.90 abyss 39, ★30 dawn forest 9,
## ★120 sky citadel 6, ★200 drowned abyss 1.5): by level in the levelling fields, by
## stars in the star fields (ten times the monsters' health) and from ★200 in the two
## endgame maps (the same monster band).
const KILLS_LEVEL := [[1, 16.5], [5, 16.5], [20, 42.0], [60, 46.5], [90, 39.0], [99, 39.0]]
const KILLS_STAR := [[0, 9.0], [30, 9.0], [120, 6.0], [199, 6.0]]
const KILLS_ENDGAME := 1.5
## From here a player hunts the drowned abyss and the lotus sanctum (WorldPlayers.session_zone):
## the two endgame maps share one band and one drop table (EndgameFields).
const ENDGAME_STARS := EndgameFields.ENTRY_STAR
## The share of an endgame map's kills that are elites (its camps' temple golems and the
## like): the divine pieces and Lotus Scales a kill drops blend EndgameFields' normal and
## elite chances by it.
const ELITE_SHARE := 0.1
const DIVINE_DROP := DivineGearData.DROP_NORMAL * (1.0 - ELITE_SHARE) + DivineGearData.DROP_ELITE * ELITE_SHARE
const SCALE_DROP := EndgameFields.SCALE_NORMAL * (1.0 - ELITE_SHARE) + EndgameFields.SCALE_ELITE * ELITE_SHARE
## Lv.100 wings a star-field kill drops (Zone.STAR_WING_DROP).
const WING_DROP := EndgameFields.WING_NORMAL
## The divine piece's + a set piece asks for (SetGearData.recipe's divine_plus).
const SET_DIVINE_PLUS := SetGearData.DIVINE_PLUS
## Events between two snapshots of the state.
const SNAP := 24
const ENHANCE_SLOTS: Array[String] = ["weapon", "armor", "helm", "boots", "wings"]
const KINDS: Array[String] = ["enhance_ok", "enhance_fail", "set_piece", "set_fail", "divine_piece", "wings_up", "wings_fail", "mount_up", "mount_fail", "drop"]

static var _sims := {}
static var _items := {}
static var _read := {}


## Forgets every simulation (tests: worked out again from nothing, as another device would).
static func clear() -> void:
	_sims.clear()
	_items.clear()
	_read.clear()


# --- The API -----------------------------------------------------------------------

## What player i wears at real time t (see the class notes): weapon / armor / helm / boots
## / ring / amulet {name, grade (item level), plus, rarity, kind, key}, wings {tier (0 none,
## 1 Lv.100 wings, 2 the 100★ wings), name, plus}, set_pieces (the 250★ class set, 0-6),
## set_name, divine_pieces (0-4: the slots it has a divine piece for; one forged into a
## set piece is gone), divine_plus (the lowest + among the divine pieces
## it wears, 0 with none worn), mount {name, level, id} or {}.
static func gear(i: int, t: float) -> Dictionary:
	return gear_at_work(i, WorldPlayers.work_at(i, t))


## The events of player i between real times t0 and t1 (t0 < at <= t1), oldest first:
## {at, kind, slot, from, to, item}. Kinds: KINDS.
static func events(i: int, t0: float, t1: float) -> Array:
	var out: Array = []
	if t1 <= t0:
		return out
	var w0 := WorldPlayers.work_at(i, t0)
	var w1 := WorldPlayers.work_at(i, t1)
	if w1 <= w0:
		return out
	var sim := _sim(i, w1)
	var a := sim.works.bsearch(w0, false)
	var b := sim.works.bsearch(w1, false)
	for k in range(a, b):
		var ev: Dictionary = sim.events[k]
		var copy := _public(i, ev)
		copy["at"] = _time_of(i, float(ev.w), t0, t1, w0, w1)
		out.append(copy)
	return out


## The latest event of `kind` of player i in (t - within, t], or {}.
static func last_event(i: int, t: float, kind: String, within: float) -> Dictionary:
	var list := events(i, t - within, t)
	for k in range(list.size() - 1, -1, -1):
		if String(list[k].kind) == kind:
			return list[k]
	return {}


## Brings the players' simulations up to real time t, one chunk at a time, for at most
## `budget` microseconds (WorldPresence calls it each frame): reads after it are a
## look-up. True once everyone is up to date.
static func warm(t: float, budget: int) -> bool:
	var start := Time.get_ticks_usec()
	var n := WorldPlayers.size()
	if n <= 0:
		return true
	# A few players a call (their work read is not free either), round the world.
	for k in mini(n, WARM_PLAYERS):
		var i := (_warm_next + k) % n
		var w := WorldPlayers.work_at(i, t)
		var sim: Sim = _sims.get(i)
		if sim == null:
			sim = _new_sim(i)
			_sims[i] = sim
		while _edge(sim.chunks) <= w:
			_run_chunk(i, sim, sim.chunks)
			sim.chunks += 1
			if Time.get_ticks_usec() - start > budget:
				_warm_next = i
				return false
		if Time.get_ticks_usec() - start > budget:
			_warm_next = (i + 1) % n
			return false
	_warm_next = (_warm_next + mini(n, WARM_PLAYERS)) % n
	return true


static var _warm_next := 0
## Players warm() looks at in one call.
const WARM_PLAYERS := 3


# --- Reading the state ---------------------------------------------------------------

## gear() at work w (probe minutes).
static func gear_at_work(i: int, w: float) -> Dictionary:
	var st := state_at_work(i, w)
	var cls := StringName(WorldPlayers.entry(i)["class"])
	var out := {}
	for slot in ItemData.SLOTS:
		var worn: Variant = (st.worn as Dictionary).get(slot)
		if worn == null:
			out[slot] = {"name": "", "grade": 0, "plus": 0, "rarity": 0, "kind": "", "key": ""}
			continue
		var item := _item(i, slot, String(worn[0]))
		out[slot] = {"name": String(item.get("name", "")), "grade": int(item.get("level", 0)), "plus": int(worn[1]),
			"rarity": int(item.get("rarity", 0)), "kind": _kind_of(String(worn[0])), "key": String(worn[0])}
	var wings: Variant = (st.worn as Dictionary).get("wings")
	if wings == null:
		out["wings"] = {"tier": 0, "name": "", "plus": 0}
	else:
		out["wings"] = {"tier": int(st.wtier), "name": String(_item(i, "wings", String(wings[0])).get("name", "")), "plus": int(wings[1])}
	out["set_pieces"] = int(st.set)
	out["set_name"] = SetGearData.set_label(String(cls))
	out["divine_pieces"] = int(st.divine)
	out["divine_plus"] = divine_plus_of(st)
	var mount := String(st.mount)
	out["mount"] = {} if mount == "" else {"name": String(MountData.info(mount).name), "level": int(st.mounts[mount]), "id": mount}
	return out


## The lowest + among the divine pieces worn (0 with none worn).
static func divine_plus_of(st: Dictionary) -> int:
	var low := -1
	for slot in st.worn:
		var worn: Array = st.worn[slot]
		if String(worn[0]) == "divine":
			low = int(worn[1]) if low < 0 else mini(low, int(worn[1]))
	return maxi(low, 0)


## The worn pieces at work w as full items (WorldPlayers.equip: what HeroStats reads).
static func equip_at_work(i: int, w: float) -> Dictionary:
	var st := state_at_work(i, w)
	var out := {}
	for slot in st.worn:
		var worn: Array = st.worn[slot]
		var item := _item(i, String(slot), String(worn[0])).duplicate(true)
		if item.is_empty():
			continue
		if EnhanceFx.can_enhance(item):
			item["plus"] = int(worn[1])
		out[slot] = item
	return out


## One string for what is worn at work w (changes with a new piece or a +).
static func signature_at_work(i: int, w: float) -> String:
	var st := state_at_work(i, w)
	var parts: PackedStringArray = []
	for slot in ItemData.EQUIP_SLOTS:
		if (st.worn as Dictionary).has(slot):
			var worn: Array = st.worn[slot]
			parts.append("%s:%s+%d" % [slot, worn[0], int(worn[1])])
	return ",".join(parts)


## The mount at work w: {id, level} or {}.
static func mount_at_work(i: int, w: float) -> Dictionary:
	var st := state_at_work(i, w)
	var id := String(st.mount)
	return {} if id == "" else {"id": id, "level": int(st.mounts[id])}


## The state after every event up to work w: {worn {slot: [key, plus]}, wtier, set,
## divine, mounts {id: level}, mount}. Kept per player and event count.
static func state_at_work(i: int, w: float) -> Dictionary:
	var sim := _sim(i, w)
	var n := sim.works.bsearch(w, false)
	var key := n * 4096 + i
	var hit: Variant = _read.get(key)
	if hit != null:
		return hit
	var snap := mini(n / SNAP, sim.snaps.size() - 1)
	var st: Dictionary = _copy(sim.snaps[snap])
	for k in range(snap * SNAP, n):
		_apply(st, sim.events[k])
	if _read.size() > 2048:
		_read.clear()
	_read[key] = st
	return st


## The real time between t0 and t1 at which player i's work reaches w (bisection: the
## work only grows while it plays).
static func _time_of(i: int, w: float, t0: float, t1: float, w0: float, w1: float) -> float:
	var lo := t0
	var hi := t1
	if t1 - t0 < 2.0:
		return t1
	for step in 14:
		var mid := (lo + hi) * 0.5
		if WorldPlayers.work_at(i, mid) >= w:
			hi = mid
		else:
			lo = mid
		if hi - lo < 1.0:
			break
	return hi


static func _public(i: int, ev: Dictionary) -> Dictionary:
	var item := String(ev.item)
	if item == "" and ev.has("key"):
		item = String(_item(i, String(ev.slot), String(ev.key)).get("name", ""))
	var out := {"kind": ev.kind, "slot": ev.slot, "from": ev.from, "to": ev.to, "item": item}
	if ev.has("used"):
		out["used"] = ev.used
	return out


static func _kind_of(key: String) -> String:
	if key == "set":
		return "set"
	if key == "divine":
		return "divine"
	if key.begins_with("s"):
		return "star"
	return "level"


# --- Items ---------------------------------------------------------------------------

## The item behind a find key of player i's slot (made once, kept): "b<band>" a level
## band's find, "s<tier>" a star tier's, "divine", "set", "w<n>" its n-th Lv.100 wings,
## "sw" the 100★ wings.
static func _item(i: int, slot: String, key: String) -> Dictionary:
	var ck := "%d|%s|%s" % [i, slot, key]
	var hit: Variant = _items.get(ck)
	if hit != null:
		return hit
	var e := WorldPlayers.entry(i)
	var name := String(e.name)
	var job := StringName(e["class"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wgear|%s|%s|%s" % [name, slot, key])
	var item := {}
	if key == "set":
		item = SetGearData.item(String(job), slot)
	elif key == "divine":
		item = DivineGearData.item(job, slot, rng)
	elif key == "sw":
		item = StarWingData.item(String(job), rng)
	elif key.begins_with("w"):
		var sim: Sim = _sims.get(i)
		var rarity := int(sim.wing_rarity.get(key, 0)) if sim != null else 0
		item = ItemData.wings(rng, String(job), rarity)
	elif key.begins_with("s"):
		item = StarProgression.item(job, int(key.substr(1)), slot, rng)
	else:
		var find: Dictionary = _sim(i, 0.0).find_info.get("%s|%s" % [slot, key], {})
		var cls := job if float(find.get("at", 99.0)) >= float(ClassData.LINE_LEVEL) else ClassData.START
		item = ItemData.generate(int(find.get("level", 1)), cls, rng, int(find.get("rarity", 0)), slot)
		if key == "b0" and slot == "weapon" and item.has("base"):
			item["name"] = "%s ของมือใหม่" % ItemData.NAMES[item.base][0]
	item["plus"] = 0
	if _items.size() > 12000:
		_items.clear()
	_items[ck] = item
	return item


# --- The simulation ------------------------------------------------------------------

class Sim:
	extends RefCounted
	var rng := RandomNumberGenerator.new()
	var chunks := 0
	var eff := 0.3
	var purple := 0
	var pink := 0
	var chaos := 0
	var feather := 0
	var core := 0
	var scales := 0
	## Mount materials by MountData.ORDER.
	var mats := PackedInt32Array([0, 0, 0, 0])
	## Precomputed finds sorted by work: [w, slot, key, score].
	var finds: Array = []
	var find_info := {}
	var next_find := 0
	## Work at which the divine set's hours are done (the per-kill divine drops start).
	var divine_done := INF
	var live := {}
	var works := PackedFloat64Array()
	var events: Array[Dictionary] = []
	var snaps: Array = []
	var wing_drops := 0
	var wing_rarity := {}
	var rides := false
	var ride_from := 0
	var job := ""


## The fixed chunk grid: edges[c] is where chunk c starts (narrow while levelling, wider
## later: CHUNK_GROWTH of the work so far, CHUNK_MIN..CHUNK_MAX probe minutes).
static var _edges := PackedFloat64Array([0.0])
static var _mount_drops := PackedFloat64Array()


static func _edge(c: int) -> float:
	while _edges.size() <= c + 1:
		var w := _edges[_edges.size() - 1]
		_edges.append(w + clampf(w * CHUNK_GROWTH, CHUNK_MIN, CHUNK_MAX))
	return _edges[c]


## Player i's simulation, run on to cover work w.
static func _sim(i: int, w: float) -> Sim:
	var sim: Sim = _sims.get(i)
	if sim == null:
		sim = _new_sim(i)
		_sims[i] = sim
	while _edge(sim.chunks) <= w:
		_run_chunk(i, sim, sim.chunks)
		sim.chunks += 1
	return sim


static func _new_sim(i: int) -> Sim:
	var sim := Sim.new()
	var e := WorldPlayers.entry(i)
	var name := String(e.name)
	sim.rng.seed = hash("wgear_sim|%s" % name)
	sim.eff = WorldPlayers.efficiency(i)
	sim.job = String(e["class"])
	sim.live = {"worn": {}, "prev": {}, "dv": {}, "wtier": 0, "set": 0, "divine": 0, "mounts": {}, "mount": ""}
	sim.snaps.append(_copy(sim.live))
	# Who takes up mounts, and from which level: drawn as WorldPlayers always has.
	var mrng := RandomNumberGenerator.new()
	mrng.seed = hash("mount|%s" % name)
	sim.rides = mrng.randf() < WorldPlayers.MOUNT_SHARE
	sim.ride_from = mrng.randi_range(WorldPlayers.MOUNT_FROM.x, WorldPlayers.MOUNT_FROM.y)
	sim.finds = _finds(name, sim)
	return sim


## Every find player `name` makes on its way, sorted by work.
static func _finds(name: String, sim: Sim) -> Array:
	var out: Array = []
	for slot in ItemData.SLOTS:
		for band in 10:
			var start := float(band * 10 + 1)
			var rng := WorldPlayers._find_rng(name, slot, "b%d" % band)
			var at := start + rng.randf() * WorldPlayers.FIND_LEVELS
			var rarity := WorldPlayers._roll_find_rarity(rng)
			var missed := rng.randf() < WorldPlayers.MISS
			if band == 0 and slot == "weapon":
				at = 1.0
				rarity = 0
				missed = false
			if missed:
				continue
			var level := clampi(int(at), int(start), int(start) + 9)
			var key := "b%d" % band
			sim.find_info["%s|%s" % [slot, key]] = {"level": level, "rarity": rarity, "at": at}
			out.append([work_of_point(at), slot, key, ItemData.gear_power(level) * ItemData.rarity_mult(rarity, 0.2)])
		for tier in StarProgression.TIERS:
			var start := float(Game.MAX_LEVEL + int(tier))
			var rng := WorldPlayers._find_rng(name, slot, "s%d" % tier)
			var at := start + rng.randf() * WorldPlayers.FIND_STARS
			if rng.randf() < WorldPlayers.STAR_MISS:
				continue
			out.append([work_of_point(at), slot, "s%d" % tier, ItemData.gear_power(Game.MAX_LEVEL + int(tier)) * ItemData.rarity_mult(3, 0.2)])
	# The divine set as WorldPlayers models it: each piece at its own share of the
	# divine hours played from ★200 (all four by DIVINE_HOURS).
	var base := _steps_at(Game.MAX_LEVEL - 1 + WorldPlayers.DIVINE_STARS)
	var need := WorldPlayers.DIVINE_HOURS * 60.0 * sim.eff
	sim.divine_done = base + need
	for slot in DivineGearData.SLOTS:
		var rng := WorldPlayers._find_rng(name, slot, "divine")
		out.append([base + rng.randf_range(0.12, 1.0) * need, slot, "divine", 0.0])
	out.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	return out


static func _steps_at(k: int) -> float:
	var steps := WorldPlayers._steps()
	return steps[clampi(k, 0, steps.size() - 1)]


## Work (probe minutes) at point p (Lv.1-100 with the part of the level, then 100 + stars).
static func work_of_point(p: float) -> float:
	var steps := WorldPlayers._steps()
	var k := clampi(int(floor(p)) - 1, 0, steps.size() - 1)
	if k >= steps.size() - 1:
		return steps[k]
	return steps[k] + (p - floor(p)) * (steps[k + 1] - steps[k])


## [level, stars] at work w.
static func _step_of(w: float) -> Vector2i:
	var steps := WorldPlayers._steps()
	var k := clampi(steps.bsearch(w, false) - 1, 0, steps.size() - 1)
	return Vector2i(mini(k + 1, Game.MAX_LEVEL), clampi(k - (Game.MAX_LEVEL - 1), 0, Game.PARAGON_MAX))


static func kills_per_minute(level: int, stars: int) -> float:
	if level < Game.MAX_LEVEL:
		return _lerp(KILLS_LEVEL, level)
	if stars >= ENDGAME_STARS:
		return KILLS_ENDGAME
	return _lerp(KILLS_STAR, stars)


static func _lerp(table: Array, x: int) -> float:
	for k in range(1, table.size()):
		if x <= int(table[k][0]):
			var a: Array = table[k - 1]
			var b: Array = table[k]
			return lerpf(float(a[1]), float(b[1]), clampf(float(x - int(a[0])) / float(maxi(1, int(b[0]) - int(a[0]))), 0.0, 1.0))
	return float(table[-1][1])


## A count with mean `mean`: its whole part, and one more at the chance of its fraction.
static func _count(rng: RandomNumberGenerator, mean: float) -> int:
	var whole := int(mean)
	return whole + (1 if rng.randf() < mean - float(whole) else 0)


static func _emit(sim: Sim, w: float, kind: String, slot: String, from: int, to: int, item: String, extra := {}) -> void:
	var ev := {"w": w, "kind": kind, "slot": slot, "from": from, "to": to, "item": item}
	for key in extra:
		ev[key] = extra[key]
	_apply(sim.live, ev)
	sim.works.append(w)
	sim.events.append(ev)
	if sim.events.size() % SNAP == 0:
		sim.snaps.append(_copy(sim.live))


## Applies one event to a state (the simulation and every replay share it).
static func _apply(st: Dictionary, ev: Dictionary) -> void:
	var slot := String(ev.slot)
	var worn: Dictionary = st.worn
	match String(ev.kind):
		"drop":
			worn[slot] = [String(ev.key), 0]
			if slot == "wings":
				st.wtier = 1
		"enhance_ok":
			(worn[slot] as Array)[1] = int(ev.to)
		"divine_piece":
			var dv: Dictionary = st.dv
			dv[slot] = int(dv.get(slot, 0)) + 1
			if bool(ev.get("wear", false)):
				if worn.has(slot):
					st.prev[slot] = worn[slot]
				worn[slot] = ["divine", 0]
			st.divine = _divine_count(st)
		"set_piece":
			# The +10 divine piece it wore there went into the forge (the jewellery's
			# Lotus Scales are no piece of its gear).
			if String(ev.get("used", "")).begins_with("divine_"):
				var dv: Dictionary = st.dv
				dv[slot] = int(dv.get(slot, 0)) - 1
				st.divine = _divine_count(st)
			worn[slot] = ["set", 0]
			st.set = int(ev.to)
		"wings_up":
			var plus := int((worn["wings"] as Array)[1]) if worn.has("wings") else 0
			worn["wings"] = [String(ev.key), plus]
			st.wtier = int(ev.to)
		"mount_up":
			st.mounts[String(ev.id)] = int(ev.to)
			var best := ""
			for m in MountData.ORDER:
				if int((st.mounts as Dictionary).get(m, 0)) > 0:
					best = m
			st.mount = best


static func _divine_count(st: Dictionary) -> int:
	var n := 0
	for slot in st.dv:
		if int(st.dv[slot]) > 0:
			n += 1
	return n


static func _copy(st: Dictionary) -> Dictionary:
	var worn := {}
	for slot in st.worn:
		worn[slot] = (st.worn[slot] as Array).duplicate()
	var prev := {}
	for slot in st.prev:
		prev[slot] = (st.prev[slot] as Array).duplicate()
	return {"worn": worn, "prev": prev, "dv": (st.dv as Dictionary).duplicate(), "wtier": st.wtier, "set": st.set, "divine": st.divine,
		"mounts": (st.mounts as Dictionary).duplicate(), "mount": st.mount}


## The worth of a worn piece with its + (finds of the level and star tiers compared).
static func _worn_worth(sim: Sim, slot: String) -> float:
	var worn: Variant = (sim.live.worn as Dictionary).get(slot)
	if worn == null:
		return -1.0
	var key := String(worn[0])
	if key == "set" or key == "divine":
		return INF
	var score := 0.0
	if key.begins_with("s"):
		score = ItemData.gear_power(Game.MAX_LEVEL + int(key.substr(1))) * ItemData.rarity_mult(3, 0.2)
	else:
		var f: Dictionary = sim.find_info.get("%s|%s" % [slot, key], {})
		score = ItemData.gear_power(int(f.get("level", 1))) * ItemData.rarity_mult(int(f.get("rarity", 0)), 0.2)
	return score * (1.0 + HeroStats.PLUS_BONUS * float(int(worn[1])))


## One chunk of play: its finds, its kills' drops, then the forge. Events of the chunk
## are stamped in order inside it: the finds at their own work, the forge after them.
static func _run_chunk(i: int, sim: Sim, c: int) -> void:
	var w0 := _edge(c)
	var w1 := _edge(c + 1)
	var step := _step_of((w0 + w1) * 0.5)
	var level := step.x
	var stars := step.y
	var live: Dictionary = sim.live
	var worn: Dictionary = live.worn
	var at := w0
	while sim.next_find < sim.finds.size() and float(sim.finds[sim.next_find][0]) < w1:
		var f: Array = sim.finds[sim.next_find]
		sim.next_find += 1
		var slot := String(f[1])
		var key := String(f[2])
		at = maxf(at, float(f[0]))
		if key == "divine":
			var wear := not worn.has(slot) or String(worn[slot][0]) not in ["set", "divine"]
			_emit(sim, at, "divine_piece", slot, int(live.divine), 0, "", {"wear": wear, "key": "divine"})
			sim.events[-1].to = int(live.divine)
		elif float(f[3]) > _worn_worth(sim, slot):
			_emit(sim, at, "drop", slot, int(worn[slot][1]) if worn.has(slot) else 0, 0, "", {"key": key})
	# What the kills of this stretch drop.
	var rng := sim.rng
	var kills := (w1 - w0) * kills_per_minute(level, stars)
	var top := level >= Game.MAX_LEVEL
	var endgame := top and stars >= ENDGAME_STARS
	if endgame:
		sim.purple += _count(rng, kills * float(EndgameFields.JEWEL_DROP.purple))
		sim.pink += _count(rng, kills * float(EndgameFields.JEWEL_DROP.pink))
		sim.chaos += _count(rng, kills * float(EndgameFields.JEWEL_DROP.chaos))
		sim.core += _count(rng, kills * EndgameFields.SET_CORE_DROP)
		sim.scales += _count(rng, kills * SCALE_DROP)
	else:
		sim.purple += _count(rng, kills * float(ItemData.JEWEL_DROP.purple))
		sim.pink += _count(rng, kills * float(ItemData.JEWEL_DROP.pink))
		sim.chaos += _count(rng, kills * float(ItemData.JEWEL_DROP.chaos))
	if top:
		var field_star := ENDGAME_STARS if endgame else 0
		if not endgame:
			for k in StarProgression.REGIONS.size():
				if stars >= int(StarProgression.ENTRY[k]):
					field_star = int(StarProgression.ENTRY[k])
		sim.feather += _count(rng, kills * ItemData.feather_chance(field_star))
	if _mount_drops.is_empty():
		for id in MountData.ORDER:
			_mount_drops.append(float(MountData.info(id).drop))
	for k in _mount_drops.size():
		sim.mats[k] += _count(rng, kills * _mount_drops[k])
	at = maxf(at, w0 + (w1 - w0) * 0.05)
	var e0 := sim.events.size()
	# More divine pieces of its own class once the set's hours are done (a forged one
	# is made good this way): DIVINE_DROP a kill, its own class's at OWN_CLASS_DROP.
	if endgame and w0 >= sim.divine_done:
		for n in _count(rng, kills * DIVINE_DROP * ItemData.OWN_CLASS_DROP):
			var slot: String = DivineGearData.SLOTS[rng.randi() % DivineGearData.SLOTS.size()]
			var wear := not worn.has(slot) or String(worn[slot][0]) not in ["set", "divine"]
			at += 0.0001
			_emit(sim, at, "divine_piece", slot, int(live.divine), 0, "", {"wear": wear, "key": "divine"})
			sim.events[-1].to = int(live.divine)
	# Lv.100 wings of its own class in the star fields; a better pair is worn.
	if top and stars >= 1 and int(live.wtier) < 2:
		for n in _count(rng, kills * WING_DROP * ItemData.OWN_CLASS_DROP):
			var r := rng.randf()
			var rarity := 4 if r < 0.03 else (3 if r < 0.12 else (2 if r < 0.30 else (1 if r < 0.60 else 0)))
			var have_r := int(sim.wing_rarity.get(String(worn.wings[0]), -1)) if worn.has("wings") else -1
			if rarity > have_r:
				sim.wing_drops += 1
				var key := "w%d" % sim.wing_drops
				sim.wing_rarity[key] = rarity
				at += 0.0001
				if worn.has("wings"):
					_emit(sim, at, "drop", "wings", int(worn.wings[1]), 0, "", {"key": key})
				else:
					_emit(sim, at, "wings_up", "wings", 0, 1, "", {"key": key})
	_forge(sim, at, level, stars)
	# What the kills brought is picked up and forged bit by bit over the stretch: its
	# events are spread evenly after the finds (their order kept).
	var count := sim.events.size() - e0
	for k in count:
		var ws := at + (w1 - at) * float(k + 1) / float(count + 1)
		sim.events[e0 + k].w = ws
		sim.works[e0 + k] = ws


## The slot the next 250★ set piece is for ("" when the set is done or not open yet).
static func _set_slot(sim: Sim, level: int, stars: int) -> String:
	if level < Game.MAX_LEVEL or stars < SetGearData.STARS or not SetGearData.THEMES.has(sim.job):
		return ""
	var n := int(sim.live.set)
	return SetGearData.SLOTS[n] if n < SetGearData.SLOTS.size() else ""


static func _forge(sim: Sim, at: float, level: int, stars: int) -> void:
	var rng := sim.rng
	var cls := sim.job
	var worn: Dictionary = sim.live.worn
	var ts := _set_slot(sim, level, stars)
	var need := SetGearData.recipe(cls, ts) if ts != "" else {}
	var jewels: Dictionary = need.get("jewels", {})
	var need_p := int(jewels.get("purple", 0))
	var need_k := int(jewels.get("pink", 0))
	var need_c := int(jewels.get("chaos", 0))
	var need_core := int(need.get("core", 1))
	# The 250★ set first, piece by piece in SetGearData.SLOTS order, by its recipe
	# (SetGearData.recipe): a weapon / armour / helm / boots piece takes the divine piece
	# it wears there at +divine_plus (used up on success), a ring or amulet its Lotus
	# Scales (used up on success); every try a set core and the jewels, lost on a fail.
	var guard := 0
	while ts != "" and guard < 12:
		guard += 1
		var divine_slot := String(need.get("divine_slot", "")) != ""
		if divine_slot:
			if not worn.has(ts) or String(worn[ts][0]) != "divine" or int(worn[ts][1]) < int(need.divine_plus):
				break
		elif sim.scales < int(need.get("scales", 0)):
			break
		if sim.core < need_core or sim.purple < need_p or sim.pink < need_k or sim.chaos < need_c:
			break
		sim.core -= need_core
		sim.purple -= need_p
		sim.pink -= need_k
		sim.chaos -= need_c
		var n := int(sim.live.set)
		at += 0.0001
		if rng.randf() < float(need.get("chance", SetGearData.CRAFT_CHANCE)):
			var used := "divine_%s" % ts
			if not divine_slot:
				sim.scales -= int(need.get("scales", 0))
				used = "scales"
			_emit(sim, at, "set_piece", ts, n, n + 1, SetGearData.item_name(cls, ts), {"used": used})
		else:
			_emit(sim, at, "set_fail", ts, n, n, SetGearData.item_name(cls, ts), {"kept": "divine_%s" % ts if divine_slot else "scales"})
		ts = _set_slot(sim, level, stars)
		need = SetGearData.recipe(cls, ts) if ts != "" else {}
		jewels = need.get("jewels", {})
		need_p = int(jewels.get("purple", 0))
		need_k = int(jewels.get("pink", 0))
		need_c = int(jewels.get("chaos", 0))
		need_core = int(need.get("core", 1))
	# While a set piece waits for its divine piece's +10, that piece is enhanced first; once
	# only the core or jewels are missing, the set's jewels are kept back.
	var focus := ""
	var reserve := false
	if ts != "":
		if String(need.get("divine_slot", "")) != "" and worn.has(ts) and String(worn[ts][0]) == "divine" and int(worn[ts][1]) < SET_DIVINE_PLUS:
			focus = ts
		elif sim.core >= need_core:
			reserve = true
	var keep_p := need_p if reserve else 0
	var keep_k := need_k if reserve else 0
	var keep_c := need_c if reserve else 0
	# +1 for the lowest worn piece (the focus first), as long as the jewels last: first
	# the steps up to +9 (no chaos jewel), then the mount, then the steps from +9 on.
	var tries := 0
	for pass_n in 2:
		var cap := 9 if pass_n == 0 else ItemData.MAX_PLUS
		while tries < 200 * (pass_n + 1):
			tries += 1
			var pick := focus if focus != "" and int(worn[focus][1]) < SET_DIVINE_PLUS else ""
			var low := ItemData.MAX_PLUS
			if pick != "":
				low = int(worn[pick][1])
			elif focus == "":
				for slot in ENHANCE_SLOTS:
					if worn.has(slot) and int(worn[slot][1]) < mini(low, cap):
						low = int(worn[slot][1])
						pick = slot
			if pick == "":
				break
			var p_cost := 0
			var k_cost := 0
			var c_cost := 0
			if low < 6:
				p_cost = 1
			elif low < 9:
				k_cost = 1
			else:
				var n := int(ItemData.ENHANCE_HIGH[clampi(low - 9, 0, ItemData.ENHANCE_HIGH.size() - 1)][1])
				p_cost = n
				k_cost = n
				c_cost = n
			if sim.purple - keep_p < p_cost or sim.pink - keep_k < k_cost or sim.chaos - keep_c < c_cost:
				break
			sim.purple -= p_cost
			sim.pink -= k_cost
			sim.chaos -= c_cost
			at += 0.0001
			var ref := {"key": String(worn[pick][0])}
			if rng.randf() < ItemData.enhance_chance(low):
				_emit(sim, at, "enhance_ok", pick, low, low + 1, "", ref)
			else:
				_emit(sim, at, "enhance_fail", pick, low, low, "", ref)
		if pass_n == 0:
			# The mount: the newest one levelled to the top, then the next one crafted.
			if sim.rides and level >= sim.ride_from:
				while tries < 200 * (pass_n + 1) + 60:
					tries += 1
					var k := -1
					for m in MountData.ORDER.size():
						if int((sim.live.mounts as Dictionary).get(MountData.ORDER[m], 0)) < MountData.MAX_LEVEL:
							k = m
							break
					if k < 0:
						break
					var id: String = MountData.ORDER[k]
					var lv := int((sim.live.mounts as Dictionary).get(id, 0))
					var step := MountData.cost(id, lv + 1)
					if sim.mats[k] < int(step.mat) or sim.chaos - keep_c < int(step.chaos):
						break
					sim.mats[k] -= int(step.mat)
					sim.chaos -= int(step.chaos)
					at += 0.0001
					var mname := String(MountData.info(id).name)
					if rng.randf() < MountData.chance(id):
						_emit(sim, at, "mount_up", "mount", lv, lv + 1, mname, {"id": id})
					else:
						_emit(sim, at, "mount_fail", "mount", lv, lv, mname, {"id": id})
	# The 100★ wings from Lv.100 wings: a chaos jewel and a feather, 30%.
	if level >= Game.MAX_LEVEL and stars >= StarWingData.REQUIRED_STARS:
		var wc := int(StarWingData.CRAFT_COST.chaos)
		var wf := int(StarWingData.CRAFT_COST.feather)
		while int(sim.live.wtier) == 1 and sim.feather >= wf and sim.chaos - keep_c >= wc:
			sim.feather -= wf
			sim.chaos -= wc
			at += 0.0001
			if rng.randf() < StarWingData.CRAFT_CHANCE:
				_emit(sim, at, "wings_up", "wings", 1, 2, "", {"key": "sw"})
			else:
				_emit(sim, at, "wings_fail", "wings", 1, 1, StarWingData.item_name(cls))
