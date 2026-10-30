class_name BuffBook
extends RefCounted
## Timed buffs on a companion or a summon: keeps the list, adds up their effect
## and shows / removes their lasting auras (see BuffAura). The hero keeps its own
## list in Hero because its stats are rebuilt from it.

var buffs: Array[Dictionary] = []
var auras: Dictionary = {} # kind -> BuffAura


const GROUP_LIMIT := 2
## Songs (the Bard's, "song" in the buff) keep slots of their own: two per
## recipient, whoever sang them, one per family (SONG_FAMILIES): an attack song and a
## ward song (defence, guard, shield; the healing songs) play together, two attack songs
## never stack: a new song takes over from the one of its own family. The same song sung
## again refreshes itself; a song never takes, evicts or loses one of the two self + two
## ally slots.
const SONG_LIMIT := 2
const SONG_FAMILIES := ["attack", "ward"]

## Each recipient has independent self / ally queues, oldest first. A multi-stat
## skill occupies ONE slot. Recasting refreshes and makes that skill newest.
static func identity(buff: Dictionary) -> String:
	return String(buff.get("skill_id", buff.get("name", "")))

static func is_song(buff: Dictionary) -> bool:
	return bool(buff.get("song", false))

## A stance (the Bard's Virtuoso): it stays on its caster and is never shared.
static func is_self_only(buff: Dictionary) -> bool:
	return bool(buff.get("self_only", false))

static func is_song_skill(skill: Dictionary) -> bool:
	var fx: Variant = skill.get("fx")
	return fx is Dictionary and (fx as Dictionary).get("buff") is Dictionary and is_song(fx.buff)

## A song's family: "ward" when it guards (defence, damage cut, shield), else "attack".
static func song_family(buff: Dictionary) -> String:
	for key in ["def", "guard", "shield"]:
		if float(buff.get(key, 0.0)) > 0.0:
			return "ward"
	return "attack"


## The family of a song skill ("" for anything else).
static func skill_song_family(skill: Dictionary) -> String:
	return song_family(skill.fx.buff) if is_song_skill(skill) else ""


## The songs still playing on a recipient, oldest first.
static func songs_of(entries: Array, now := -1) -> Array:
	if now < 0:
		now = Time.get_ticks_msec()
	var out: Array = []
	for buff in entries:
		if int(buff.until) > now and is_song(buff):
			out.append(buff)
	return out

## The newest song still playing on a recipient, or {}.
static func song_of(entries: Array, now := -1) -> Dictionary:
	var list := songs_of(entries, now)
	return {} if list.is_empty() else list[-1]

## Seconds left of song `id` on a recipient (0 when it is not playing).
static func song_left_of(entries: Array, id: String, now := -1) -> float:
	if now < 0:
		now = Time.get_ticks_msec()
	for buff in songs_of(entries, now):
		if identity(buff) == id:
			return (float(buff.until) - float(now)) / 1000.0
	return 0.0

## Whether a song slot is free on a recipient.
static func song_slot_free(entries: Array, now := -1) -> bool:
	return songs_of(entries, now).size() < SONG_LIMIT

## The song a new one would take over from: the one of `family` playing ({} when that
## family's slot is free); without a family, the oldest song once both slots are taken.
static func song_to_replace(entries: Array, family := "", now := -1) -> Dictionary:
	var list := songs_of(entries, now)
	if family != "":
		for buff in list:
			if song_family(buff) == family:
				return buff
		return {}
	return {} if list.size() < SONG_LIMIT else list[0]

## Seconds left of the song playing on a recipient (0 without one).
static func song_left(entries: Array, now := -1) -> float:
	if now < 0:
		now = Time.get_ticks_msec()
	var song := song_of(entries, now)
	return 0.0 if song.is_empty() else (float(song.until) - float(now)) / 1000.0

## A song with every number (not its length) raised by [param factor] (the Bard's star set).
static func boost_song(buff: Dictionary, factor: float) -> Dictionary:
	var out := buff.duplicate()
	for key in out:
		if key != "secs" and (out[key] is float or out[key] is int):
			out[key] = float(out[key]) * factor
	return out

static func group_count(entries: Array, ally: bool, now := -1) -> int:
	if now < 0:
		now = Time.get_ticks_msec()
	var count := 0
	for buff in entries:
		if int(buff.until) > now and bool(buff.get("ally", false)) == ally and not bool(buff.get("overheal", false)) and not is_song(buff):
			count += 1
	return count

static func contains(entries: Array, id: String, ally: bool, now := -1) -> bool:
	if now < 0:
		now = Time.get_ticks_msec()
	for buff in entries:
		if int(buff.until) > now and bool(buff.get("ally", false)) == ally and identity(buff) == id:
			return true
	return false

static func insert(entries: Array, data: Dictionary, color: Color, label: String, ally := false, skill_id := "", now := -1) -> Array[Dictionary]:
	if now < 0:
		now = Time.get_ticks_msec()
	var id := skill_id if not skill_id.is_empty() else label
	var next: Array[Dictionary] = []
	for entry in entries:
		if int(entry.until) > now and not (bool(entry.get("ally", false)) == ally and identity(entry) == id):
			next.append(entry)
	if is_song(data):
		# One song per family: the same song sung again (by anyone) refreshes itself and a
		# new song takes over from the one of its family; the limit is a safety net.
		var family := song_family(data)
		next = next.filter(func(b): return not (is_song(b) and (identity(b) == id or song_family(b) == family)))
		var songs := next.filter(func(b): return is_song(b)).size()
		while songs >= SONG_LIMIT:
			for i in next.size():
				if is_song(next[i]):
					next.remove_at(i)
					break
			songs -= 1
	else:
		while group_count(next, ally, now) >= GROUP_LIMIT and not bool(data.get("overheal", false)):
			for i in next.size():
				if bool(next[i].get("ally", false)) == ally and not bool(next[i].get("overheal", false)) and not is_song(next[i]):
					next.remove_at(i)
					break
	var buff := data.duplicate(true)
	buff.merge({"until": now + int(float(data.get("secs", 10.0)) * 1000.0),
		"total": float(data.get("secs", 10.0)), "name": label, "skill_id": id,
		"ally": ally, "color": color}, true)
	next.append(buff)
	return next

func add(data: Dictionary, color: Color, label := "", ally := true, skill_id := "") -> void:
	buffs = insert(buffs, data, color, label, ally, skill_id)


## Sum of one effect ("atk", "def", "speed", "crit") over the buffs still running.
func total(key: String) -> float:
	var now := Time.get_ticks_msec()
	var values: Array = []
	for buff in buffs:
		if int(buff.until) > now:
			values.append(float(buff.get(key, 0.0)))
	return stack(values)


## Buffs of one stat don't simply add up: the strongest counts in full, every
## other one adds a quarter of its value (four attack buffs: x2.1, not x3.3).
static func stack(values: Array) -> float:
	var best := 0.0
	var sum := 0.0
	for v in values:
		best = maxf(best, float(v))
		sum += maxf(float(v), 0.0)
	return best + 0.25 * (sum - best)


## Drops expired buffs and keeps the auras in step. [param top] returns the
## height of the body (called only when an aura has to be created).
func tick(host: Node3D, alive: bool, top: Callable) -> void:
	if buffs.is_empty() and auras.is_empty():
		return
	var now := Time.get_ticks_msec()
	if not buffs.is_empty():
		buffs = buffs.filter(func(b): return int(b.until) > now)
	BuffAura.sync(host, auras, buffs, now, alive, top)


func clear(host: Node3D) -> void:
	buffs.clear()
	BuffAura.sync(host, auras, buffs, Time.get_ticks_msec(), false, func(): return 2.0)

## A protection skill occupies its existing self/ally slot, including its shield.
## Share of damage taken that active buffs send back (thorns); the strongest wins, at most 40%.
static func reflect(entries: Array, now := -1) -> float:
	if now < 0:
		now = Time.get_ticks_msec()
	var best := 0.0
	for entry in entries:
		if int(entry.get("until", 0)) > now:
			best = maxf(best, float(entry.get("reflect", 0.0)))
	return minf(best, 0.4)


static func absorb(entries: Array, incoming: int) -> int:
	var now := Time.get_ticks_msec()
	var guards: Array=[]
	for entry in entries:
		if int(entry.until)>now: guards.append(float(entry.get("guard",0.0)))
	var amount := int(ceil(incoming*(1.0-clampf(stack(guards),0.0,0.45))))
	for entry in entries:
		if int(entry.until)<=now or not entry.has("shield_left"): continue
		var absorbed := mini(amount,int(entry.shield_left))
		entry.shield_left=int(entry.shield_left)-absorbed
		amount-=absorbed
		if int(entry.shield_left)<=0: entry.until=0
	return maxi(0,amount)
