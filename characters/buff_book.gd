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
	buffs.append(buff)


## Sum of one effect ("atk", "def", "speed", "crit") over the buffs still running.
func total(key: String) -> float:
	var now := Time.get_ticks_msec()
	var sum := 0.0
	for buff in buffs:
		if int(buff.until) > now:
			sum += float(buff.get(key, 0.0))
	return sum


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
