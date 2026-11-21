class_name IsleLuck
extends RefCounted
## The world players' jackpots on เกาะลอยฟ้าเทพมังกร. The world players are "the server"
## for a hero playing alone, so now and then one of them who is hunting on the isle gets
## a jackpot and the whole server hears of it (Announcer.tick), like a real player's.
## Read off the real clock like the rest of the living world, so every device (and every
## real player online) sees the same player get the same thing at the same second.
##
## Time is cut into SLOT-second slots; a slot is lucky with chance CHANCE (a hash of its
## number). In a lucky slot:
## - the Dragon God's weapon and wings are only ever the world players' real drops: they
##   hunt them for real (WorldGear: their isle kills drop them at the owner's rates; the
##   first of a kind is put on, a "drop", another is a "spare"), so the slot's first such
##   drop (DRAGON_KINDS) by a player hunting on the isle at that second is the jackpot,
##   at that second, with the very piece it got (real_drop);
## - otherwise the jackpot is rolled as it always was, among KINDS (those that are
##   jackpots: SkyIsleLoot.is_jackpot) weighted by the owner's drop rates
##   (SkyIsleLoot.*_DROP); a weapon or wings roll, with no real drop to fill it, lets the
##   slot pass; the egg goes to one of the world players hunting on the isle at a second
##   of the slot's own (WorldPlayers.state: place and doing; with nobody there, the slot
##   passes).
## So nobody is announced with a Dragon God piece its gear (WorldGear.gear: the player
## card, its fights) does not show, and no line hands one out.
##
## Working a player's forging out from nothing is not free (WorldGear: WorldPresence warms
## everyone over the first frames), so while a candidate's forging is not worked out yet
## the slot waits (nothing announced, nothing kept) unless `cold` allows the work (tests).

const SLOT := 12 * 60
## About one jackpot in SLOT / CHANCE seconds (40 minutes) while someone hunts there.
const CHANCE := 0.3
## [what (Announcer.WHATS), the rate constant's value] of every jackpot kind a lucky slot
## rolls (the weapon and wings only ever filled by a real drop: DRAGON_KINDS).
const KINDS := [["weapon", SkyIsleLoot.WEAPON_DROP], ["wings", SkyIsleLoot.WING_DROP], ["fragment", SkyIsleLoot.FRAGMENT_DROP], ["egg", SkyIsleLoot.EGG_DROP]]
## [what, the rate, WorldGear slot] of the jackpots that are the world players' real drops.
const DRAGON_KINDS := [["weapon", SkyIsleLoot.WEAPON_DROP, "weapon"], ["wings", SkyIsleLoot.WING_DROP, "wings"]]

static var _cache := {}
## Whether a slot may work a player's forging out from nothing (tests); otherwise it waits
## for WorldGear.warm.
static var cold := false
## Marks real_drop's answer as not final yet (a candidate's forging was not worked out).
const WAIT := {"wait": true}


## The jackpot of slot `n`: {slot, at (unix), index, name, cls, what, rate, item}, or {}
## when the slot is not lucky or nobody hunts on the isle then.
static func at_slot(n: int) -> Dictionary:
	if _cache.has(n):
		return _cache[n]
	if _cache.size() > 64:
		_cache.clear()
	var out := _roll(n)
	if out.has("wait"):
		return {}
	_cache[n] = out
	return out


static func _roll(n: int) -> Dictionary:
	if float(WorldEvents.roll("isleluck|%d" % n) % 10000) >= CHANCE * 10000.0:
		return {}
	var real := real_drop(float(n) * float(SLOT), float(n + 1) * float(SLOT))
	if not real.is_empty():
		if not real.has("wait"):
			real["slot"] = n
		return real
	# No real Dragon God drop in the slot: the jackpot is rolled as ever, the weapon and
	# wings weighed in, but those only ever come from a real drop, so such a roll lets the
	# slot pass.
	var kinds: Array = []
	var total := 0.0
	for k in KINDS:
		var probe := Announcer.item_of(String(k[0]), ClassData.IDS[0])
		if probe.is_empty() or not SkyIsleLoot.is_jackpot(probe):
			continue
		kinds.append(k)
		total += float(k[1])
	if kinds.is_empty():
		return {}
	var r := float(WorldEvents.roll("isleluck|what|%d" % n) % 100000) / 100000.0 * total
	var pick: Array = kinds[kinds.size() - 1]
	for k in kinds:
		r -= float(k[1])
		if r < 0.0:
			pick = k
			break
	if DRAGON_KINDS.any(func(d): return String(d[0]) == String(pick[0])):
		return {}
	var at := float(n) * float(SLOT) + float(WorldEvents.roll("isleluck|at|%d" % n) % SLOT)
	var hunters := hunters_at(at)
	if hunters.is_empty():
		return {}
	var s: Dictionary = hunters[WorldEvents.roll("isleluck|who|%d" % n) % hunters.size()]
	var cls := StringName(String(s.get("job", s.get("class", "warrior"))))
	return {"slot": n, "at": at, "index": int(s.index), "name": String(s.name), "cls": cls, "what": String(pick[0]), "rate": float(pick[1]), "item": Announcer.item_of(String(pick[0]), cls)}


## The first Dragon God piece a world player really got in (t0, t1] while hunting on the
## isle (WorldGear's "drop" / "spare" events of key WorldGear.DRAGON: its own class):
## {at, index, name, cls, what, rate, item, real}, {} for none, WAIT while a candidate's
## forging is not worked out (see `cold`). Only a player at ★300 (WorldGear.ISLE_STARS)
## who played then is looked at.
static func real_drop(t0: float, t1: float) -> Dictionary:
	var w300 := WorldGear.isle_work()
	var best := {}
	for i in WorldPlayers.size():
		var w1 := WorldPlayers.work_at(i, t1)
		if w1 < w300 or w1 <= WorldPlayers.work_at(i, t0):
			continue
		if not cold and not WorldGear.is_warm(i, w1):
			return WAIT
		for e in WorldGear.events(i, t0, t1):
			if String(e.get("key", "")) != WorldGear.DRAGON or not (String(e.kind) in ["drop", "spare"]):
				continue
			if not best.is_empty() and float(e.at) >= float(best.at):
				break
			var s := WorldPlayers.state(i, float(e.at))
			if not (bool(s.get("online", false)) and StringName(String(s.get("place", ""))) == SkyIsleData.ID and String(s.get("doing", "")) in ["hunt", "boss"]):
				continue
			for k in DRAGON_KINDS:
				if String(k[2]) == String(e.slot):
					best = {"at": float(e.at), "index": i, "name": String(s.name), "cls": StringName(String(s.get("job", s.get("class", "warrior")))),
						"what": String(k[0]), "rate": float(k[1]), "item": WorldGear.piece(i, String(e.slot), WorldGear.DRAGON), "real": true}
			break
	return best


## The states of the world players hunting on the isle at real time `t`.
static func hunters_at(t: float) -> Array:
	var out: Array = []
	for i in WorldPlayers.size():
		if WorldPlayers.session_at(i, t).is_empty():
			continue
		var s := WorldPlayers.state(i, t)
		if bool(s.get("online", false)) and StringName(String(s.get("place", ""))) == SkyIsleData.ID and String(s.get("doing", "")) in ["hunt", "boss"]:
			out.append(s)
	return out


## The jackpots that fell in (from, to], oldest first.
static func due(from: float, to: float) -> Array:
	var out: Array = []
	for n in range(int(floor(from / float(SLOT))), int(floor(to / float(SLOT))) + 1):
		var e := at_slot(n)
		if not e.is_empty() and float(e.at) > from and float(e.at) <= to:
			out.append(e)
	return out


## A rate as the chat says it: 0.005 -> "0.5" (percent).
static func percent(rate: float) -> String:
	return str(snappedf(rate * 100.0, 0.01))


static func clear() -> void:
	_cache.clear()
