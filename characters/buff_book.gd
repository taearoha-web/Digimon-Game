class_name BuffBook
extends RefCounted
## Timed buffs on a companion or a summon: keeps the list, adds up their effect
## and shows / removes their lasting auras (see BuffAura). The hero keeps its own
## list in Hero because its stats are rebuilt from it.

var buffs: Array[Dictionary] = []
var auras: Dictionary = {} # kind -> BuffAura


## [param data] {atk, def, speed, crit, secs}.
func add(data: Dictionary, color: Color, label := "") -> void:
	var buff: Dictionary = data.duplicate()
	buff["until"] = Time.get_ticks_msec() + int(float(buff.get("secs", 10.0)) * 1000.0)
	buff["name"] = label
	buff["color"] = color
	# The same buff cast again refreshes instead of stacking.
	buffs = buffs.filter(func(b): return String(b.get("name", "")) != label)
	buffs.append(buff)


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
