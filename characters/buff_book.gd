class_name BuffBook
extends RefCounted
## Timed buffs on a companion or a summon: keeps the list, adds up their effect
## and shows / removes their lasting auras (see BuffAura). The hero keeps its own
## list in Hero because its stats are rebuilt from it.

var buffs: Array[Dictionary] = []
var auras: Dictionary = {} # kind -> BuffAura


const GROUP_LIMIT := 2

## Each recipient has independent self / ally queues, oldest first. A multi-stat
## skill occupies ONE slot. Recasting refreshes and makes that skill newest.
static func identity(buff: Dictionary) -> String:
	return String(buff.get("skill_id", buff.get("name", "")))

static func group_count(entries: Array, ally: bool, now := -1) -> int:
	if now < 0:
		now = Time.get_ticks_msec()
	var count := 0
	for buff in entries:
		if int(buff.until) > now and bool(buff.get("ally", false)) == ally and not bool(buff.get("overheal", false)):
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
	while group_count(next, ally, now) >= GROUP_LIMIT and not bool(data.get("overheal", false)):
		for i in next.size():
			if bool(next[i].get("ally", false)) == ally and not bool(next[i].get("overheal", false)):
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
