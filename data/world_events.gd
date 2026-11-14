class_name WorldEvents
extends RefCounted
## Timed world events, the reason to log in every day: a fixed daily schedule read off
## the real clock (WorldPresence.clock()) in Thai time (WorldPlayers.TZ), the same for
## everyone. EXP x2 every evening 19:00-21:00; the world boss (บอสโลก) at 19:30 for
## 20 minutes in the hunting field of the day (the base fields in ZoneData order, one
## a day; on Saturday and Sunday the ★ regions join the rotation); on the weekend gold
## drops pay +20% and forge jewels drop twice as often; a few times a day the rare dragon
## (มังกรแก้วเจ็ดสี) visits เกาะลอยฟ้าเทพมังกร for 10 minutes (rare_now); every 15 minutes a golden monster
## (มอนทองคำ) visits each levelling field for 3 minutes. Times are seconds of the Thai day; the day index (Thai midnight to
## midnight) names a boss window in profile.flags ("wboss|<day>").

const DAY := 86400
const EXP_START := 19 * 3600
const EXP_END := 21 * 3600
const EXP_MULT := 2.0
const BOSS_START := 19 * 3600 + 30 * 60
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
## The week's festival (เทศกาล EXP x3 + ดรอปเพชร x3): from 3 Nov 2026 21:35 Thai time for
## seven days every EXP is tripled (on top of the evening EXP x2 and the Halloween potion)
## and the forge jewels (purple, pink, chaos) drop three times as often as they did
## (on top of the weekend jewel rush). The same for everyone, read off the clock.
const FESTIVAL_START := 1793747700
const FESTIVAL_END := FESTIVAL_START + 7 * DAY
const FESTIVAL_EXP := 3.0
const FESTIVAL_JEWEL := 3.0
const NAME_FESTIVAL := "เทศกาล EXP x3 + ดรอปเพชร x3"
## The second festival (เทศกาล EXP x5 + ดรอปเพชร/แก่นเทพ x5): from 13 Nov 2026 07:40 Thai
## time for seven days every EXP is x5 (on top of the evening EXP x2), the forge jewels
## (purple, pink, chaos) drop five times as often (on top of the weekend rush) and so does
## the set material (แก่นเทพหลอมเซต, Zone.set_core_roll). The same for everyone.
const FESTIVAL5_START := 1794530400
const FESTIVAL5_END := FESTIVAL5_START + 7 * DAY
const FESTIVAL5_EXP := 5.0
const FESTIVAL5_JEWEL := 5.0
const FESTIVAL5_CORE := 5.0
const NAME_FESTIVAL5 := "เทศกาล EXP x5 + ดรอปเพชร/แก่นเทพ x5"
## Tests of the progression maths that run on the real clock switch the festival off.
static var festival_enabled := true
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

## The rare dragon (มังกรแก้วเจ็ดสี) of the zones flagged "rare_dragon" (เกาะลอยฟ้าเทพมังกร;
## RareDragon runs it): RARE_MIN to RARE_MAX windows a Thai day (rare_count), each
## RARE_LENGTH seconds, at a minute nobody can learn by habit: the day is cut into as many
## equal parts as it has windows and each window starts at a whole minute of its part picked
## by a hash of the day (rare_windows), never within RARE_GAP of the next part. Read off
## the clock, so every device opens the same windows. profile.flags[RARE_FLAG]: the last
## window whose dragon the hero saw fall.
const RARE_MIN := 4
const RARE_MAX := 6
const RARE_LENGTH := 10 * 60
const RARE_GAP := 30 * 60
const NAME_RARE := "มังกรแก้วเจ็ดสี"
const RARE_COLOR := Color("7dffd8")
const RARE_FLAG := "rare_dragon"
## A window's number: its Thai day times RARE_SLOTS plus its place in the day.
const RARE_SLOTS := 8

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


## EXP multiplier at `t`: the evening EXP x2 times the running festival's (x3 or x5).
static func exp_multiplier(t: float) -> float:
	return (EXP_MULT if evening_exp(t) else 1.0) * (FESTIVAL_EXP if festival_on(t) else 1.0) * (FESTIVAL5_EXP if festival5_on(t) else 1.0)


## The daily evening EXP x2 (19:00-21:00 Thai time).
static func evening_exp(t: float) -> bool:
	var s := time_of_day(t)
	return s >= EXP_START and s < EXP_END


static func festival_on(t: float) -> bool:
	return festival_enabled and t >= float(FESTIVAL_START) and t < float(FESTIVAL_END)


static func festival5_on(t: float) -> bool:
	return festival_enabled and t >= float(FESTIVAL5_START) and t < float(FESTIVAL5_END)


## Set material (แก่นเทพหลอมเซต) drop chances: x5 during the second festival.
static func core_multiplier(t: float) -> float:
	return FESTIVAL5_CORE if festival5_on(t) else 1.0


## The HUD line of the festival ("" outside it): days left while more than two remain.
static func festival_text(t: float) -> String:
	var name := NAME_FESTIVAL5 if festival5_on(t) else (NAME_FESTIVAL if festival_on(t) else "")
	if name == "":
		return ""
	var left := float(FESTIVAL5_END if festival5_on(t) else FESTIVAL_END) - t
	var span := "%d วัน" % int(ceil(left / float(DAY))) if left > 2.0 * float(DAY) else _span(left)
	return "%s เหลือ %s" % [name, span]


static func halloween_on(t: float) -> bool:
	return t >= float(HALLOWEEN_START) and t < float(HALLOWEEN_END)


## The HUD line of the Halloween event ("" outside it).
static func halloween_text(t: float) -> String:
	return "%s เหลือ %s" % [NAME_HALLOWEEN, _span(float(HALLOWEEN_END) - t)] if halloween_on(t) else ""


## Forge jewel drop chances: doubled all weekend (Thai time), x3 / x5 during the festivals.
static func jewel_multiplier(t: float) -> float:
	return (WEEKEND_JEWEL if is_weekend(t) else 1.0) * (FESTIVAL_JEWEL if festival_on(t) else 1.0) * (FESTIVAL5_JEWEL if festival5_on(t) else 1.0)


## The HUD line of the weekend jewel rush ("" on weekdays).
static func weekend_text(t: float) -> String:
	if not is_weekend(t):
		return ""
	# Saturday runs to Monday 00:00, Sunday to its own midnight.
	return "%s เหลือ %s" % [NAME_WEEKEND_JEWEL, _span(_at(t, DAY, 1 if weekday(t) == 6 else 0) - t)]


## The HUD event chip's lines at `t` (Hud): the running or next event (describe), the
## weekend jewel rush and the Halloween event, each only while it has something to say.
static func chip_lines(t: float) -> Array:
	return [festival_text(t), rare_text(t), describe(t), weekend_text(t), halloween_text(t)].filter(func(line: String): return line != "")


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


## A well-mixed number (0 .. 2^32-1) for `key`, the same on every device: a string's hash
## alone moves by one when its last digit does, so neighbouring days would follow a pattern.
static func roll(key: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	rng.randi()
	return rng.randi()


## How many times the rare dragon comes on Thai day `day` (RARE_MIN..RARE_MAX).
static func rare_count(day: int) -> int:
	return RARE_MIN + roll("rare|%d" % day) % (RARE_MAX - RARE_MIN + 1)


## Unix times the rare dragon's windows of Thai day `day` open, in order.
static func rare_windows(day: int) -> Array[float]:
	var out: Array[float] = []
	var count := rare_count(day)
	var part := DAY / count
	var minutes := maxi(1, (part - RARE_LENGTH - RARE_GAP) / 60)
	var midnight := float(day) * float(DAY) - float(WorldPlayers.TZ)
	for k in count:
		out.append(midnight + float(k * part + 60 * (roll("rare|%d|%d" % [day, k]) % minutes)))
	return out


## The rare dragon's window `t` is in: {window, start, until, day, slot}, or {} outside.
static func rare_now(t: float) -> Dictionary:
	var day := day_of(t)
	var starts := rare_windows(day)
	for k in starts.size():
		if t >= starts[k] and t < starts[k] + float(RARE_LENGTH):
			return {"window": day * RARE_SLOTS + k, "start": starts[k], "until": starts[k] + float(RARE_LENGTH), "day": day, "slot": k}
	return {}


## Unix time the next window opens after `t` (tests and probes; the game never shows it).
static func rare_next(t: float) -> float:
	for days in 2:
		for start in rare_windows(day_of(t) + days):
			if start > t:
				return start
	return t + float(DAY)


## The camp (index) the dragon of `window` comes to in a field of `camps` camps.
static func rare_camp(window: int, camps: int) -> int:
	return roll("rarecamp|%d" % window) % maxi(1, camps)


## Whether this hero already saw the dragon of `window` fall (its prize is once a window).
static func rare_done(window: int) -> bool:
	return Game.has_profile and int(Game.profile.flags.get(RARE_FLAG, -1)) == window


## The HUD line while the rare dragon lives ("" outside a window and once it fell).
static func rare_text(t: float) -> String:
	var event := rare_now(t)
	if event.is_empty() or rare_done(int(event.window)):
		return ""
	return "%s ที่%s เหลือ %s" % [NAME_RARE, SkyIsleData.TITLE, _span(float(event.until) - t)]


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
	if festival_on(t):
		list.append({"id": "festival", "name_th": NAME_FESTIVAL, "until": float(FESTIVAL_END)})
	if festival5_on(t):
		list.append({"id": "festival5", "name_th": NAME_FESTIVAL5, "until": float(FESTIVAL5_END)})
	if evening_exp(t):
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
