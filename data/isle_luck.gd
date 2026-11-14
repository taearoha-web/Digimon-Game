class_name IsleLuck
extends RefCounted
## The world players' jackpots on เกาะลอยฟ้าเทพมังกร. The world players are "the server"
## for a hero playing alone, so now and then one of them who is hunting on the isle gets
## a jackpot and the whole server hears of it (Announcer.tick), like a real player's.
## Read off the real clock like the rest of the living world, so every device (and every
## real player online) sees the same player get the same thing at the same second.
##
## Time is cut into SLOT-second slots; a slot is lucky with chance CHANCE (a hash of its
## number), at a second of its own. The winner is one of the world players hunting on
## the isle at that second (WorldPlayers.state: place and doing); with nobody there, the
## slot passes. What it gets is one of the isle's jackpots (SkyIsleLoot.is_jackpot of the
## real item), weighted by the owner's drop rates (SkyIsleLoot.*_DROP), the weapon or
## wings of the winner's own class.
##
## It is news only: the world players' gear model (WorldGear) is not changed by it, so
## none of them starts wearing the Dragon God's gear because of a line in the chat.

const SLOT := 12 * 60
## About one jackpot in SLOT / CHANCE seconds (40 minutes) while someone hunts there.
const CHANCE := 0.3
## [what (Announcer.WHATS), the rate constant's value] of every jackpot kind.
const KINDS := [["weapon", SkyIsleLoot.WEAPON_DROP], ["wings", SkyIsleLoot.WING_DROP], ["fragment", SkyIsleLoot.FRAGMENT_DROP], ["egg", SkyIsleLoot.EGG_DROP]]

static var _cache := {}


## The jackpot of slot `n`: {slot, at (unix), index, name, cls, what, rate, item}, or {}
## when the slot is not lucky or nobody hunts on the isle then.
static func at_slot(n: int) -> Dictionary:
	if _cache.has(n):
		return _cache[n]
	if _cache.size() > 64:
		_cache.clear()
	var out := _roll(n)
	_cache[n] = out
	return out


static func _roll(n: int) -> Dictionary:
	if float(WorldEvents.roll("isleluck|%d" % n) % 10000) >= CHANCE * 10000.0:
		return {}
	var at := float(n) * float(SLOT) + float(WorldEvents.roll("isleluck|at|%d" % n) % SLOT)
	var hunters := hunters_at(at)
	if hunters.is_empty():
		return {}
	var s: Dictionary = hunters[WorldEvents.roll("isleluck|who|%d" % n) % hunters.size()]
	var cls := StringName(String(s.get("job", s.get("class", "warrior"))))
	var kinds: Array = []
	var total := 0.0
	for k in KINDS:
		var item := Announcer.item_of(String(k[0]), cls)
		if item.is_empty() or not SkyIsleLoot.is_jackpot(item):
			continue
		kinds.append([String(k[0]), float(k[1]), item])
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
	return {"slot": n, "at": at, "index": int(s.index), "name": String(s.name), "cls": cls, "what": String(pick[0]), "rate": float(pick[1]), "item": pick[2]}


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
