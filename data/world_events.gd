class_name WorldEvents
extends RefCounted
## Timed world events, the reason to log in every day: a fixed daily schedule read off
## the real clock (WorldPresence.clock()) in Thai time (WorldPlayers.TZ), the same for
## everyone. EXP x2 every evening 19:00-21:00; the world boss (บอสโลก) at 20:30 for
## 20 minutes in the hunting field of the day (the base fields in ZoneData order, one
## a day; on Saturday and Sunday the ★ regions join the rotation); on the weekend gold
## drops pay +20% and forge jewels drop twice as often; every 15 minutes a golden monster
## (มอนทองคำ) visits each levelling field for 3 minutes. Times are seconds of the Thai day; the day index (Thai midnight to
## midnight) names a boss window in profile.flags ("wboss|<day>").

const DAY := 86400
const EXP_START := 19 * 3600
const EXP_END := 21 * 3600
const EXP_MULT := 2.0
const BOSS_START := 20 * 3600 + 30 * 60
const BOSS_LENGTH := 20 * 60
const WEEKEND_GOLD := 1.2
## World boss over the field's own: HP, gold reward per Lv.10 of the hero, the rarity
## of the piece it drops into the bag (its moves: WorldBoss).
const BOSS_HP_SCALE := 3.0
const BOSS_GOLD_PER_10 := 500
const BOSS_DROP_RARITY := 3
## World players hunting in the field join in: they go for the boss within this range
## and shout one of these lines, each at most every BOSS_SHOUT_GAP seconds.
const BOSS_JOIN_RANGE := 40.0
const BOSS_SHOUT_GAP := 30.0
const BOSS_SHOUTS := ["รุมบอสโลก!", "บอสโลกมาแล้ว ช่วยกันตี!", "ระวังท่าใหญ่ หลบ!", "ตีบอสโลกกัน!"]
## Halloween (ฮาโลวีน): until Thai midnight starting 1 Nov 2026 every monster in every
## field may drop a Halloween potion (ItemData.POTIONS "halloween": a random EXP x2 or
## x3 for an hour of real time, Game.drink_exp_potion).
const HALLOWEEN_START := 1793293200
const HALLOWEEN_END := 1793466000
const HALLOWEEN_DROP := 0.05
const NAME_HALLOWEEN := "ฮาโลวีน: น้ำยาฮาโลวีนดรอป 5%"
const NAME_EXP := "EXP x2"
const NAME_BOSS := "บอสโลก"
const NAME_GOLD := "โบนัสทอง +20%"
## Weekend jewel rush (สุดสัปดาห์ดรอปเพชร x2): all of Saturday and Sunday (Thai time)
## the forge jewels (ItemData.JEWEL_DROP: purple, pink, chaos) drop twice as often.
## Feathers are not doubled.
const WEEKEND_JEWEL := 2.0
const NAME_WEEKEND_JEWEL := "สุดสัปดาห์ดรอปเพชร x2"
## The golden monster (มอนทองคำ): every GOLDEN_PERIOD seconds of real time (one window a
## period, read off the clock so everyone sees the same) a gilded monster of the field
## appears in one of its camps for GOLDEN_LENGTH seconds, in every levelling field.
## Its start inside the period moves by GOLDEN_STEP steps (0-2 minutes), so two
## appear 13 to 17 minutes apart. GOLDEN_HP times the HP; it pays GOLDEN_GOLD gold per
## field tier, a purple and a pink jewel, chaos at GOLDEN_CHAOS and a stat gem at GOLDEN_GEM.
const GOLDEN_PERIOD := 15 * 60
const GOLDEN_LENGTH := 3 * 60
const GOLDEN_STEP := 30
const GOLDEN_STEPS := 5
const GOLDEN_HP := 5.0
const GOLDEN_GOLD := 50000
const GOLDEN_CHAOS := 0.25
const GOLDEN_GEM := 0.1
const GOLDEN_COLOR := Color("ffd23a")
const NAME_GOLDEN := "มอนทองคำ"
## profile.flags[GOLDEN_FLAG]: the last window whose golden monster the hero killed.
const GOLDEN_FLAG := "golden"

static var _fields: Array[StringName] = []
static var _star_fields: Array[StringName] = []


## Hunting fields the boss rotates through: ZoneData fields with monsters and a boss
## (no pvp, arena, tower or guild war); the ★ regions (and the divine one) separately.
static func _ensure() -> void:
	if not _fields.is_empty():
		return
	ZoneData.ensure()
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if String(z.get("scene", "")) != "field" or not z.has("boss") or z.get("camps", []).is_empty():
			continue
		if bool(z.get("pvp", false)) or bool(z.get("arena", false)) or bool(z.get("tower", false)):
			continue
		if bool(z.get("star_region", false)) or bool(z.get("divine_region", false)):
			_star_fields.append(id)
		else:
			_fields.append(id)


## Seconds since Thai midnight.
static func time_of_day(t: float) -> int:
	return posmod(int(floor(t)) + WorldPlayers.TZ, DAY)


## Thai day index (days since the epoch, Thai midnight to midnight).
static func day_of(t: float) -> int:
	return int(floor((t + float(WorldPlayers.TZ)) / float(DAY)))


## The profile flag that marks a day's world boss as defeated (flags hold integers).
static func flag_key(day: int) -> String:
	return "wboss|%d" % day


## 0 = Sunday ... 6 = Saturday (1 Jan 1970 was a Thursday).
static func weekday(t: float) -> int:
	return posmod(day_of(t) + 4, 7)


static func is_weekend(t: float) -> bool:
	var w := weekday(t)
	return w == 0 or w == 6


## Unix time of the Thai day's second `secs`, on the day of `t` plus `days`.
static func _at(t: float, secs: int, days := 0) -> float:
	return float(day_of(t) + days) * float(DAY) - float(WorldPlayers.TZ) + float(secs)


## The field of the day's world boss.
static func boss_zone(t: float) -> StringName:
	_ensure()
	var day := day_of(t)
	if is_weekend(t) and not _star_fields.is_empty():
		var all: Array[StringName] = _fields.duplicate()
		all.append_array(_star_fields)
		return all[posmod(day, all.size())]
	return _fields[posmod(day, _fields.size())]


static func exp_multiplier(t: float) -> float:
	var s := time_of_day(t)
	return EXP_MULT if s >= EXP_START and s < EXP_END else 1.0


static func halloween_on(t: float) -> bool:
	return t >= float(HALLOWEEN_START) and t < float(HALLOWEEN_END)


## The HUD line of the Halloween event ("" outside it).
static func halloween_text(t: float) -> String:
	return "%s เหลือ %s" % [NAME_HALLOWEEN, _span(float(HALLOWEEN_END) - t)] if halloween_on(t) else ""


## Forge jewel drop chances: doubled all weekend (Thai time).
static func jewel_multiplier(t: float) -> float:
	return WEEKEND_JEWEL if is_weekend(t) else 1.0


## The HUD line of the weekend jewel rush ("" on weekdays).
static func weekend_text(t: float) -> String:
	if not is_weekend(t):
		return ""
	# Saturday runs to Monday 00:00, Sunday to its own midnight.
	return "%s เหลือ %s" % [NAME_WEEKEND_JEWEL, _span(_at(t, DAY, 1 if weekday(t) == 6 else 0) - t)]


## The HUD event chip's lines at `t` (Hud): the running or next event (describe), the
## weekend jewel rush and the Halloween event, each only while it has something to say.
static func chip_lines(t: float) -> Array:
	return [describe(t), weekend_text(t), halloween_text(t)].filter(func(line: String): return line != "")


## A levelling field (the golden monster's ground): a field with monster camps, not the
## town, pvp, the guild war, the arena or the tower.
static func golden_field(zone: Dictionary) -> bool:
	if String(zone.get("scene", "")) != "field" or zone.get("camps", []).is_empty():
		return false
	for key in ["safe", "pvp", "guildwar", "arena", "tower"]:
		if bool(zone.get(key, false)):
			return false
	return true


## The golden monster window `t` is in: {window, start, until}, or {} between them.
static func golden_now(t: float) -> Dictionary:
	var n := int(floor(t / float(GOLDEN_PERIOD)))
	var start := golden_start(n)
	if t < start or t >= start + float(GOLDEN_LENGTH):
		return {}
	return {"window": n, "start": start, "until": start + float(GOLDEN_LENGTH)}


## Unix time the golden monster of window `n` appears: GOLDEN_STEP times a step fixed
## by `n` into period n.
static func golden_start(n: int) -> float:
	return float(n) * float(GOLDEN_PERIOD) + float(GOLDEN_STEP * posmod(n * 7 + 3, GOLDEN_STEPS))


## The tier of a field for the golden monster's gold: one per 10 levels of the field's
## top level (1-10), one more per 20 stars of a ★ region.
static func golden_tier(zone: Dictionary) -> int:
	var top := int(zone.get("level", [1, 1])[1])
	return clampi(int(ceil(float(top) / 10.0)), 1, 10) + int(zone.get("star", 0)) / 20


## Camp and monster (index into the camp's list) of window `n` in a field: the same for
## everyone hunting there.
static func golden_pick(n: int, zone_id: StringName, camps: int, monsters: int) -> Vector2i:
	var h := absi(String(zone_id).hash())
	return Vector2i(posmod(n * 31 + h, maxi(1, camps)), posmod(n * 17 + h / 7, maxi(1, monsters)))


static func gold_multiplier(t: float) -> float:
	return WEEKEND_GOLD if is_weekend(t) else 1.0


## The world boss window `t` is in: {zone, name_th, until, day}, or {} outside it.
static func boss_now(t: float) -> Dictionary:
	var s := time_of_day(t)
	if s < BOSS_START or s >= BOSS_START + BOSS_LENGTH:
		return {}
	var zone := boss_zone(t)
	return {"id": "wboss", "zone": zone, "name_th": "%sที่ %s" % [NAME_BOSS, ZoneData.get_zone(zone).name],
		"until": _at(t, BOSS_START + BOSS_LENGTH), "day": day_of(t)}


## Every event running at `t`: {id, name_th, until, zone?}.
static func current(t: float) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if exp_multiplier(t) > 1.0:
		list.append({"id": "exp2", "name_th": NAME_EXP, "until": _at(t, EXP_END)})
	var boss := boss_now(t)
	if not boss.is_empty():
		list.append(boss)
	if is_weekend(t):
		list.append({"id": "gold", "name_th": NAME_GOLD, "until": _at(t, DAY)})
	return list


## The next event to start after `t`: {id, name_th, at, in (seconds), zone?}.
static func next_event(t: float) -> Dictionary:
	var best: Dictionary = {}
	for days in 2:
		for start in [[EXP_START, "exp2", NAME_EXP], [BOSS_START, "wboss", NAME_BOSS]]:
			var at := _at(t, int(start[0]), days)
			if at > t and (best.is_empty() or at < float(best.at)):
				best = {"id": String(start[1]), "name_th": String(start[2]), "at": at, "in": at - t}
				if String(start[1]) == "wboss":
					var zone := boss_zone(at)
					best["zone"] = zone
					best["name_th"] = "%sที่ %s" % [NAME_BOSS, ZoneData.get_zone(zone).name]
	return best


## Minutes or hours left, short, for the HUD chip.
static func _span(seconds: float) -> String:
	var m := int(ceil(seconds / 60.0))
	if m >= 120:
		return "%d ชม." % int(round(float(m) / 60.0))
	return "%d นาที" % maxi(1, m)


## One line for the HUD: the running event (the boss first) or the next one.
static func describe(t: float) -> String:
	var now := current(t)
	var boss := boss_now(t)
	if not boss.is_empty():
		return "%s %s" % [boss.name_th, _span(float(boss.until) - t)]
	for e in now:
		if String(e.id) == "exp2":
			return "%s เหลือ %s" % [e.name_th, _span(float(e.until) - t)]
	var next := next_event(t)
	var head := ("%s · " % NAME_GOLD) if is_weekend(t) else ""
	if next.is_empty():
		return head.trim_suffix(" · ")
	return "%s%s ใน %s" % [head, next.name_th, _span(float(next["in"]))]
