class_name WorldGear
extends RefCounted
## STUB — replaced by the gear-model branch.
##
## A stand-in with the gear model's API so the chat (ChatThreads, ChatBrain, WorldChat)
## compiles and its tests run: what each world player wears, its enhancing, wings, 250★
## set pieces, divine set and mount, and the events between two moments. Everything is
## read off WorldPlayers' progress (level, stars, divine set, hours after it), so it is
## deterministic and only goes up. The chat relies on the API only:
##   gear(i, t), events(i, t0, t1), last_event(i, t, kind, within)
## t is real unix time, like WorldPlayers.state.

const SLOTS: Array[String] = ["weapon", "armor", "helm", "boots"]
const KINDS: Array[String] = ["enhance_ok", "enhance_fail", "set_piece", "divine_piece", "wings_up", "mount_up", "drop"]
## Events fall on this grid of real seconds (each player's own offset).
const STEP := 300.0
## Progress points per +1 on a slot, and each slot's lag.
const PLUS_EVERY := 5.0
const SLOT_LAG := {"weapon": 0.0, "armor": 2.0, "helm": 3.5, "boots": 4.5}
## Share of grid steps with a failed try (an online player at +6 or more).
const FAIL_SHARE := 0.25
## Progress points per find.
const FIND_EVERY := 1.5

static var _cache := {}


static func gear(i: int, t: float) -> Dictionary:
	var key := "%d|%d" % [i, int(t / 60.0)]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 4000:
		_cache.clear()
	var p := WorldPlayers.progress_at(i, t)
	var e := WorldPlayers.entry(i)
	var cls := String(e["class"])
	var level := int(p.level)
	var stars := int(p.stars) if level >= Game.MAX_LEVEL else 0
	var point := _point(p)
	var out := {}
	for slot in SLOTS:
		var plus := clampi(int(maxf(0.0, point - float(SLOT_LAG[slot])) / PLUS_EVERY), 0, ItemData.MAX_PLUS)
		var grade := clampi(int(point / 10.0) * 10, 1, 400)
		out[slot] = {"name": "%s Lv.%d" % [ItemData.SLOT_NAMES[slot], grade], "grade": grade, "plus": plus}
	var tier := 0
	if point >= 112.0:
		tier = 1
	if point >= 215.0:
		tier = 2
	out["wings"] = {"tier": tier, "name": ["", "ปีกนักผจญภัย", "ปีกดารา"][tier]}
	out["set_pieces"] = clampi(int((float(stars) - float(SetGearData.STARS)) / 8.0) + 1, 0, 6) if stars >= SetGearData.STARS else 0
	out["set_name"] = SetGearData.set_label(cls)
	out["divine_pieces"] = clampi(int(float(p.divine_frac) * 4.0), 0, 4)
	out["divine_plus"] = clampi(int(float(p.after) / 3.0), 0, 10) if out.divine_pieces >= 4 else 0
	var m := WorldPlayers.mount_of({"name": String(e.name), "level": level, "stars": stars})
	out["mount"] = {"name": String(MountData.info(String(m.id)).get("name", "")), "level": int(m.level)} if not m.is_empty() else {}
	out["finds"] = int(point / FIND_EVERY)
	_cache[key] = out
	return out


static func events(i: int, t0: float, t1: float) -> Array:
	var out: Array = []
	if t1 <= t0:
		return out
	var off := float(absi(hash("gear|%d" % i)) % int(STEP))
	var k := int(floor((t0 - off) / STEP)) + 1
	while true:
		var at := off + float(k) * STEP
		if at > t1:
			break
		if at > t0:
			out.append_array(_step(i, at))
		k += 1
	return out


static func last_event(i: int, t: float, kind: String, within: float) -> Dictionary:
	var list := events(i, t - within, t)
	for n in range(list.size() - 1, -1, -1):
		if String(list[n].kind) == kind:
			return list[n]
	return {}


## What changed between the grid point before `at` and `at`.
static func _step(i: int, at: float) -> Array:
	var out: Array = []
	var a := gear(i, at - STEP)
	var b := gear(i, at)
	for slot in SLOTS:
		var was := int(a[slot].plus)
		var now := int(b[slot].plus)
		for n in range(was, now):
			out.append({"at": at, "kind": "enhance_ok", "slot": slot, "from": n, "to": n + 1, "item": String(b[slot].name)})
		if now == was and now >= 6 and now < ItemData.MAX_PLUS and not WorldPlayers.session_at(i, at).is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("fail|%d|%d|%s" % [i, int(at), slot])
			if rng.randf() < FAIL_SHARE:
				out.append({"at": at, "kind": "enhance_fail", "slot": slot, "from": now, "to": now, "item": String(b[slot].name)})
	if int(b.set_pieces) > int(a.set_pieces):
		out.append({"at": at, "kind": "set_piece", "slot": "", "from": int(a.set_pieces), "to": int(b.set_pieces), "item": String(b.set_name)})
	if int(b.divine_pieces) > int(a.divine_pieces):
		out.append({"at": at, "kind": "divine_piece", "slot": "", "from": int(a.divine_pieces), "to": int(b.divine_pieces), "item": "ชุดเทพ"})
	if int(b.wings.tier) > int(a.wings.tier):
		out.append({"at": at, "kind": "wings_up", "slot": "wings", "from": int(a.wings.tier), "to": int(b.wings.tier), "item": String(b.wings.name)})
	var ma: Dictionary = a.mount
	var mb: Dictionary = b.mount
	if not mb.is_empty() and (ma.is_empty() or String(ma.name) != String(mb.name) or int(mb.level) > int(ma.level)):
		var from := 0 if ma.is_empty() or String(ma.name) != String(mb.name) else int(ma.level)
		out.append({"at": at, "kind": "mount_up", "slot": "mount", "from": from, "to": int(mb.level), "item": String(mb.name)})
	if int(b.finds) > int(a.finds):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("find|%d|%d" % [i, int(b.finds)])
		var pool := _find_pool(i, at)
		out.append({"at": at, "kind": "drop", "slot": "jewel", "from": 0, "to": 0, "item": String(pool[rng.randi() % pool.size()])})
	return out


static func _point(p: Dictionary) -> float:
	var level := int(p.level)
	if level < Game.MAX_LEVEL:
		return float(level) + float(p.frac)
	return float(Game.MAX_LEVEL + int(p.stars)) + float(p.frac)


static func _find_pool(i: int, at: float) -> Array:
	var p := WorldPlayers.progress_at(i, at)
	var level := int(p.level)
	var stars := int(p.stars) if level >= Game.MAX_LEVEL else 0
	var pool: Array = [ItemData.JEWELS.purple.name]
	if level >= 20:
		pool.append(ItemData.JEWELS.pink.name)
	if level >= 35:
		pool.append(ItemData.JEWELS.wolf_fang.name)
	if level >= Game.MAX_LEVEL:
		pool.append(ItemData.JEWELS.chaos.name)
	if stars >= ItemData.FEATHER_STARS:
		pool.append(ItemData.JEWELS.feather.name)
	if stars >= DrownedAbyssData.ENTRY_STAR:
		pool.append(ItemData.JEWELS.set_core.name)
	return pool
