class_name WorldPlayers
extends RefCounted
## The other players of the world: 20 people with fixed names, classes and guilds (ten in
## Alpha, ten in Neverdie). Nobody runs them on a server. Each keeps a daily play
## schedule set by its play style (Thai time, the same on every device), and what it
## has reached is the EXP a real player earns in the hours it played: the auto-hunt rates
## tests/tools/pace_probe.gd measured in the real fields, times the player's own
## efficiency (deaths, trips to town, slower hands than the probe's). So levels, stars,
## whereabouts and who is online are the same for everyone at a given moment, from Lv.1
## on the day the world opened up to Lv.100 ★200. While online a player stands in the
## village at the start and end of a session and otherwise hunts in the field that fits
## its level (WorldPresence shows it there, fighting the field's monsters for real).

## The world opened here (unix seconds; 26 Oct 2026, 07:00 Thai time): every world
## player started at Lv.1.
const START_UNIX := 1792972800
## Schedules run on Thai time.
const TZ := 7 * 3600
const DAY := 86400

const ALPHA := 1
const NEVERDIE := 2
const GUILD_NAMES := {ALPHA: "Alpha", NEVERDIE: "Neverdie"}
const GUILD_COLORS := {ALPHA: Color("ffd24a"), NEVERDIE: Color("ff6f8e")}

const ROSTER: Array[Dictionary] = [
	{"name": "Kaito", "class": &"warrior", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "Shadow_Fang", "class": &"assassin", "guild": ALPHA, "gender": 0, "style": "hardcore"},
	{"name": "น้องแพรวา", "class": &"priest", "guild": ALPHA, "gender": 1, "style": "regular"},
	{"name": "LanceKung", "class": &"lancer", "guild": ALPHA, "gender": 0, "style": "regular"},
	{"name": "SkyArrow", "class": &"archer", "guild": ALPHA, "gender": 0, "style": "student"},
	{"name": "Mintty", "class": &"mage", "guild": ALPHA, "gender": 1, "style": "student"},
	{"name": "Rinrada", "class": &"summoner", "guild": ALPHA, "gender": 1, "style": "night_owl"},
	{"name": "ป้อมปราการ", "class": &"defender", "guild": ALPHA, "gender": 0, "style": "weekend"},
	{"name": "เมจิกหมูกรอบ", "class": &"mage", "guild": ALPHA, "gender": 0, "style": "casual"},
	{"name": "ข้าวเหนียวมะม่วง", "class": &"archer", "guild": ALPHA, "gender": 1, "style": "casual"},
	{"name": "Zerox", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "hardcore"},
	{"name": "BlackLotus", "class": &"assassin", "guild": NEVERDIE, "gender": 1, "style": "hardcore"},
	{"name": "TonkatsuX", "class": &"defender", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "นักล่าตะวัน", "class": &"archer", "guild": NEVERDIE, "gender": 0, "style": "regular"},
	{"name": "Fiora", "class": &"lancer", "guild": NEVERDIE, "gender": 1, "style": "student"},
	{"name": "Yoyo", "class": &"priest", "guild": NEVERDIE, "gender": 1, "style": "student"},
	{"name": "แม่หมอมิว", "class": &"priest", "guild": NEVERDIE, "gender": 1, "style": "night_owl"},
	{"name": "PhantomZ", "class": &"summoner", "guild": NEVERDIE, "gender": 0, "style": "weekend"},
	{"name": "ไฟร์บอลเด้ง", "class": &"mage", "guild": NEVERDIE, "gender": 0, "style": "casual"},
	{"name": "Raijin", "class": &"warrior", "guild": NEVERDIE, "gender": 0, "style": "casual"},
]

## Sessions as [start hour, hours] on weekdays and at weekends (Saturday, Sunday). Each day
## moves every start by up to ±jitter hours and stretches every length by 0.7-1.3; skip is
## the chance a day is missed. eff: how much of the probe's EXP rate the style earns.
const STYLES := {
	"hardcore": {"weekday": [[12.0, 1.5], [18.5, 5.5]], "weekend": [[10.0, 4.5], [18.0, 6.0]], "jitter": 1.0, "skip": 0.03, "eff": 0.18, "label": "ขาโหด"},
	"regular": {"weekday": [[20.0, 3.0]], "weekend": [[14.0, 2.0], [20.0, 3.5]], "jitter": 1.0, "skip": 0.08, "eff": 0.15, "label": "เล่นประจำ"},
	"student": {"weekday": [[16.5, 1.5], [20.5, 2.0]], "weekend": [[10.0, 3.0], [19.0, 3.0]], "jitter": 0.8, "skip": 0.06, "eff": 0.15, "label": "นักเรียน"},
	"night_owl": {"weekday": [[22.0, 4.0]], "weekend": [[21.0, 5.5]], "jitter": 1.2, "skip": 0.08, "eff": 0.16, "label": "สายนอนดึก"},
	"weekend": {"weekday": [[21.0, 1.0]], "weekend": [[10.0, 4.0], [19.0, 4.0]], "jitter": 1.0, "skip": 0.35, "eff": 0.15, "label": "สายเสาร์อาทิตย์"},
	"casual": {"weekday": [[20.0, 1.5]], "weekend": [[15.0, 2.5]], "jitter": 1.5, "skip": 0.25, "eff": 0.13, "label": "เล่นชิลล์"},
}
## Minutes of every session spent in the village: shopping before, selling after.
const TOWN_BEFORE := 6.0
const TOWN_AFTER := 4.0

## EXP per minute of auto-hunting (pace_probe, warrior/mage mean, 60 s each) at each
## level in its field, and at Lv.100 by stars in the star fields.
const LEVEL_RATE := [[1, 900], [3, 1146], [10, 2465], [18, 5498], [26, 12453], [35, 14066], [46, 18823], [58, 21692], [70, 29115], [82, 26128], [94, 36727], [100, 36727]]
const STAR_RATE := [[0, 56160], [25, 26488], [75, 46653], [125, 38994], [175, 41755], [200, 41755]]
## Potions a world player carries out of the village.
const POTIONS := 20
const MP_POTIONS := 10
## Hours of play after ★200 before the class's divine set is complete.
const DIVINE_HOURS := 20.0

static var _table: PackedFloat64Array = PackedFloat64Array()
static var _minutes_cache := {}


static func size() -> int:
	return ROSTER.size()


static func now() -> float:
	return Time.get_unix_time_from_system()


static func entry(i: int) -> Dictionary:
	return ROSTER[i]


static func guild_name(guild: int) -> String:
	return String(GUILD_NAMES.get(guild, ""))


static func members(guild: int) -> Array[int]:
	var out: Array[int] = []
	for i in ROSTER.size():
		if int(ROSTER[i].guild) == guild:
			out.append(i)
	return out


static func other_guild(guild: int) -> int:
	return NEVERDIE if guild == ALPHA else ALPHA


# --- Schedule -------------------------------------------------------------------

## Local day number (Thai time) of a unix time.
static func day_of(t: float) -> int:
	return int(floor((t + TZ) / DAY))


## The sessions player i plays on local day `day`: [[start, end], ...] in unix seconds.
static func sessions_on(i: int, day: int) -> Array:
	var style: Dictionary = STYLES[String(ROSTER[i].style)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [ROSTER[i].name, day])
	if rng.randf() < float(style.skip):
		return []
	# 1970-01-01 was a Thursday: weekday 0 = Monday.
	var weekday := (day + 3) % 7
	var plan: Array = style.weekend if weekday >= 5 else style.weekday
	var out := []
	var midnight := float(day) * DAY - TZ
	var last_end := -INF
	for slot in plan:
		var start := midnight + (float(slot[0]) + rng.randf_range(-1.0, 1.0) * float(style.jitter)) * 3600.0
		var length := float(slot[1]) * rng.randf_range(0.7, 1.3) * 3600.0
		start = maxf(start, last_end + 900.0)
		out.append([start, start + length])
		last_end = start + length
	return out


## Minutes player i has played between the world's opening and t.
static func played_minutes(i: int, t: float) -> float:
	if t <= START_UNIX:
		return 0.0
	var key := "%d|%d" % [i, int(t / 60.0)]
	if _minutes_cache.has(key):
		return _minutes_cache[key]
	if _minutes_cache.size() > 4000:
		_minutes_cache.clear()
	var total := 0.0
	# A session can run past midnight, so the day before the opening counts too.
	for day in range(day_of(START_UNIX) - 1, day_of(t) + 1):
		for s in sessions_on(i, day):
			var a := maxf(float(s[0]), float(START_UNIX))
			var b := minf(float(s[1]), t)
			if b > a:
				total += (b - a) / 60.0
	_minutes_cache[key] = total
	return total


## The session player i is in at t, or [] when offline.
static func session_at(i: int, t: float) -> Array:
	if t < START_UNIX:
		return []
	for day in [day_of(t) - 1, day_of(t)]:
		for s in sessions_on(i, day):
			if t >= float(s[0]) and t < float(s[1]):
				return s
	return []


# --- Progress -------------------------------------------------------------------

## Probe EXP per minute at a level (and at Lv.100, at a star count).
static func rate(level: int, stars: int) -> float:
	if level >= Game.MAX_LEVEL:
		return _lerp_table(STAR_RATE, stars)
	return _lerp_table(LEVEL_RATE, level)


static func _lerp_table(table: Array, x: int) -> float:
	for k in range(1, table.size()):
		if x <= int(table[k][0]):
			var a: Array = table[k - 1]
			var b: Array = table[k]
			var f := clampf(float(x - int(a[0])) / float(maxi(1, int(b[0]) - int(a[0]))), 0.0, 1.0)
			# Rates grow by factors, so they are blended in log space.
			return exp(lerpf(log(float(a[1])), log(float(b[1])), f))
	return float(table[-1][1])


## Probe minutes from Lv.1 to step k: steps 0..99 are Lv.1..100, steps 100..300 are ★0..200.
static func _steps() -> PackedFloat64Array:
	if not _table.is_empty():
		return _table
	var table := PackedFloat64Array()
	var total := 0.0
	table.append(0.0)
	for level in range(1, Game.MAX_LEVEL):
		total += float(HeroStats.exp_to_next(level)) / rate(level, 0)
		table.append(total)
	for star in Game.PARAGON_MAX:
		total += float(HeroStats.exp_to_next(Game.MAX_LEVEL)) * (1.0 + 0.02 * float(star)) / rate(Game.MAX_LEVEL, star)
		table.append(total)
	_table = table
	return table


## How much of the probe's rate player i earns: its style's efficiency and its own hands.
static func efficiency(i: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("eff|%s" % ROSTER[i].name)
	return float(STYLES[String(ROSTER[i].style)].eff) * rng.randf_range(0.88, 1.12)


## {level, stars, frac (0..1 to the next step), minutes (played), divine (bool)} for
## `minutes` of play at efficiency `eff`.
static func progress_for(minutes: float, eff: float) -> Dictionary:
	var steps := _steps()
	var work := minutes * eff
	var k := steps.bsearch(work, false) - 1
	k = clampi(k, 0, steps.size() - 1)
	var frac := 0.0
	if k < steps.size() - 1:
		frac = clampf((work - steps[k]) / maxf(0.001, steps[k + 1] - steps[k]), 0.0, 0.999)
	var level := mini(k + 1, Game.MAX_LEVEL)
	var stars := clampi(k - (Game.MAX_LEVEL - 1), 0, Game.PARAGON_MAX)
	var divine := stars >= Game.PARAGON_MAX and work - steps[steps.size() - 1] >= DIVINE_HOURS * 60.0 * eff
	return {"level": level, "stars": stars, "frac": frac, "minutes": minutes, "divine": divine}


## Everything about player i at time t: the roster entry plus level, stars, online,
## place (the zone id it stands in, "" offline) and the gear grade it wears.
static func state(i: int, t: float = -1.0) -> Dictionary:
	if t < 0.0:
		t = now()
	var e: Dictionary = ROSTER[i]
	var p := progress_for(played_minutes(i, t), efficiency(i))
	var s := session_at(i, t)
	var place := ""
	if not s.is_empty():
		var since := (t - float(s[0])) / 60.0
		var until := (float(s[1]) - t) / 60.0
		place = "town" if since < TOWN_BEFORE or until < TOWN_AFTER else String(hunting_zone(int(p.level), int(p.stars), bool(p.divine)))
	var out := e.duplicate()
	out.merge(p)
	out["index"] = i
	out["online"] = not s.is_empty()
	out["place"] = place
	out["grade"] = grade_of(int(p.level), int(p.stars), bool(p.divine))
	out["last_seen"] = _last_seen(i, t) if s.is_empty() else t
	return out


## When player i last logged off before t (0 if never).
static func _last_seen(i: int, t: float) -> float:
	var day := day_of(t)
	for back in 8:
		var list := sessions_on(i, day - back)
		for k in range(list.size() - 1, -1, -1):
			var end := float(list[k][1])
			if end <= t and end > START_UNIX:
				return end
	return 0.0


## The field a player hunts in: the one whose levels fit, then the star fields by stars,
## and the lotus sanctum (the divine set) from ★200.
static func hunting_zone(level: int, stars: int, _divine := false) -> StringName:
	if level >= Game.MAX_LEVEL:
		if stars >= Game.PARAGON_MAX:
			return DivineRegionData.ID
		var at: StringName = &"void"
		for k in StarProgression.REGIONS.size():
			if stars >= int(StarProgression.ENTRY[k]):
				at = StarProgression.REGIONS[k]
		return at
	ZoneData.ensure()
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if String(z.get("scene", "")) != "field" or z.get("pvp", false) or z.get("arena", false) or z.get("tower", false) or z.has("star"):
			continue
		var band: Array = z.get("level", [0, 0])
		if level >= int(band[0]) and level <= int(band[1]) and id != &"void":
			return id
	return &"meadow"


## Guild-war gear grade (GuildWarData.GRADES): the star set reached, the divine set once
## it is complete; below ★50 the plain 50-star set (war rules dress everyone).
static func grade_of(_level: int, stars: int, divine: bool) -> int:
	if divine:
		return GuildWarData.DIVINE
	var grade := 50
	for g in [100, 150, 200]:
		if stars >= g:
			grade = g
	return grade


# --- Looks and fighters ---------------------------------------------------------------

## Player i's face and hair, always the same.
static func look(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("look|%s" % ROSTER[i].name)
	var l := FaceKit.random_look(rng)
	var gender := int(ROSTER[i].gender)
	if int(l.gender) != gender:
		l["gender"] = gender
		l["hair"] = rng.randi() % FaceKit.option_count("hair", gender)
		ChibiLook.apply_style(l, int(l["hair"]) % ChibiLook.count("style"))
	return l


## A party-member dictionary for the field (Companion reads class, name, level, stars).
static func member(i: int, t: float = -1.0) -> Dictionary:
	var s := state(i, t)
	return {"class": String(s["class"]), "name": String(s.name), "level": int(s.level), "stars": int(s.stars), "exp": 0,
		"stance": "aggressive", "trait": "brave", "gender": int(s.gender), "potions": POTIONS, "mp_potions": MP_POTIONS}


## The character sheet of a world player at its level and stars (for HeroStats): the
## companion's gear and job, plus every stat point spent like a player does (60% main
## stat, 40% vitality) and its skills ranked up as it levels.
static func profile(m: Dictionary) -> Dictionary:
	var p := Game.party_profile(m)
	p["equip"] = equip(m)
	var level := int(m.level)
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	var main := String(JobData.resolve(StringName(m["class"]), int(p.adv)).main)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[main] = int(points * 0.6)
	attrs["vit"] = int(attrs["vit"]) + int(points * 0.4)
	p["attrs"] = attrs
	var skills := {}
	for skill in ClassData.pool(StringName(m["class"])):
		if int(skill.level) <= level:
			skills[String(skill.id)] = clampi(1 + (level - int(skill.level)) / 12, 1, SkillRank.MAX)
	p["skills"] = skills
	return p


static var _gear := {}


## What a world player wears: rare gear of its level enhanced as it goes (+2 to +7, the
## kind a player farms), every slot; past Lv.100 the star set its stars have reached; the
## class wings at the wing level, the star wings from ★100. The same pieces until the next
## tier.
static func equip(m: Dictionary) -> Dictionary:
	var level := int(m.level)
	var stars := int(m.get("stars", 0))
	var tier := 0
	for t in StarProgression.TIERS:
		if stars >= int(t):
			tier = int(t)
	var key := "%s|%d|%d" % [m.name, ItemData.tier_for(level), tier]
	if _gear.has(key):
		return _gear[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var cls := StringName(m["class"])
	var gear := {}
	for slot in ItemData.SLOTS:
		var item: Dictionary = StarProgression.item(cls, tier, slot, rng) if tier > 0 else {}
		if item.is_empty():
			item = ItemData.generate(maxi(1, level), cls, rng, 2, slot)
			if EnhanceFx.can_enhance(item):
				item["plus"] = clampi(2 + level / 20, 2, 7)
		gear[slot] = item
	if level >= ItemData.WING_DROP_LEVEL:
		gear["wings"] = StarWingData.item(String(cls), rng, 3) if stars >= StarWingData.REQUIRED_STARS else ItemData.wings(rng, String(cls), 3)
	if _gear.size() > 200:
		_gear.clear()
	_gear[key] = gear
	return gear


## Player i as a guild-war fighter (GuildWarData.make_fighter) with its own name and face.
static func fighter(i: int, t: float, rng: RandomNumberGenerator) -> Dictionary:
	var s := state(i, t)
	var f := GuildWarData.make_fighter(StringName(s["class"]), int(s.grade), String(s.name), rng)
	f["look"] = look(i)
	f["world"] = i
	f["online"] = bool(s.online)
	return f


## Display line: "Lv.57" or "Lv.100 ★120".
static func level_text(s: Dictionary) -> String:
	return "Lv.%d%s" % [int(s.level), " ★%d" % int(s.stars) if int(s.stars) > 0 else ""]


## Where a player is, for the guild roster.
static func where_text(s: Dictionary, t: float = -1.0) -> String:
	if t < 0.0:
		t = now()
	if t < START_UNIX:
		return "รอเปิดโลก"
	if bool(s.online):
		var place := StringName(s.place)
		return "ออนไลน์ · %s" % (ZoneData.get_zone(place).name if place != &"town" else "หมู่บ้าน")
	var seen := float(s.get("last_seen", 0.0))
	if seen <= 0.0:
		return "ยังไม่เคยเข้าเกม"
	var ago := int((t - seen) / 60.0)
	if ago < 60:
		return "ออฟไลน์ · %d นาทีก่อน" % maxi(1, ago)
	if ago < 60 * 24:
		return "ออฟไลน์ · %d ชม.ก่อน" % (ago / 60)
	return "ออฟไลน์ · %d วันก่อน" % (ago / (60 * 24))
