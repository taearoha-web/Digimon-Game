class_name RaidData
extends RefCounted
## The daily party raid (ดันเจี้ยนปาร์ตี้, zone RAID / "raid"): three floors in one crimson
## arena (RaidArenaArt). Floor 1 is a pack of monsters, floor 2 a pack with a mid-boss,
## floor 3 the raid boss (RaidBoss): a tank buster on whoever holds its threat, telegraphed
## blood circles, adds that shield it, a second phase at 50% HP and an enrage timer.
##
## It takes a party of MIN_PARTY or more: the hero and the world players who joined
## (Game.world_party, FieldPlayer party_mode). RUNS_PER_DAY entries a Thai day (the
## device's date, GoalsData.today), counted when the party goes in. A clear pays once per
## entry (claim) and the first clear of the day adds the chest (FIRST_CHEST).
##
## Strength follows the party (scale): the monsters' HP comes from the party's attack
## (how long a party of that power needs, BOSS_TTK / MID_TTK / TRASH_TTK) and their hits
## from the party's HP and defence, so a fresh Lv.40 party and a 250★ party both get a
## fight of the same length; the level shown and the rewards follow the party's level and
## stars. Not in ZoneData.ZONES (it is entered from the raid keeper, not walked to):
## ZoneData.get_zone answers for it.

const ID: StringName = &"raid"
const TITLE := "ดันเจี้ยนปาร์ตี้ · วิหารอสูรโลหิต"
const SHORT := "ดันเจี้ยนปาร์ตี้"
const KEEPER := "ผู้เฝ้าวิหารโลหิต"
const MIN_LEVEL := 30
const MIN_PARTY := 3
const RUNS_PER_DAY := 2
const FLOORS := 3
const BOSS_NAME := "ราชันอสูรโลหิต"
const MID_NAME_PREFIX := "ผู้คุมชั้น · "
const BOSS_MODEL: StringName = &"void_emperor"
const BOSS_TINT := Color(1.9, 0.38, 0.42)
const BOSS_COLOR := Color("ff2f4a")
## Seconds a party of its power needs for one boss / mid-boss / monster (before skills).
const BOSS_TTK := 130.0
const MID_TTK := 30.0
const TRASH_TTK := 6.0
## A member's damage a second against the raid: attack x this, through the monster's DEF.
const DPS_PER_ATK := 1.6
## Hits: a share of the party's average max HP after its average DEF.
const BOSS_HIT := 0.1
const MID_HIT := 0.06
const TRASH_HIT := 0.03
## Monsters per floor (floor 2 also has its mid-boss); each member past three adds one.
const TRASH := [6, 4, 0]
## Flags in the profile (Game.profile.flags).
const F_DAY := "raid_day"
const F_RUNS := "raid_runs"
const F_FIRST := "raid_first"
const F_OPEN := "raid_open"
const F_CLEARS := "raid_clears"

## The monsters of a floor for parties below the stars: the field whose band fits.
const FIELDS: Array[StringName] = [&"meadow", &"dark_forest", &"desert", &"snow", &"volcano", &"graveyard", &"swamp", &"storm", &"sky", &"abyss"]
const STAR_POOL: Array[StringName] = [&"void_golem", &"star_wraith", &"rift_stalker", &"tentacle_horror", &"nova_drake"]
const STAR_MID: StringName = &"abyss_dragon"


static func zone() -> Dictionary:
	return {
		"name": TITLE, "scene": "field", "level": [MIN_LEVEL, 100], "music": &"guildwar", "theme": &"abyss", "weather": &"brimstone",
		"ambience": &"hum", "tree_density": 0.0, "camps": [], "tower": true, "raid": true,
		"loot": {"gear": 0.05, "potion": 0.3, "gem": 0.06, "boss_items": 2},
		"sky": Color("2a0c14"), "ground": Color("4a1c22"), "fog": Color("6e2430"), "ambient": Color(1.0, 0.55, 0.55), "sun": Color(1.0, 0.45, 0.4),
		"path_color": Color("7a2a32"), "seed": 41, "prev": &"town", "next": &"",
		"sky_palette": [Color("12040a"), Color("3a0c18"), Color("8a1e2c")], "sun_size": 0.0, "moon": true,
	}


# --- Who goes in --------------------------------------------------------------------

## The hero and the world players in the party.
static func party_size() -> int:
	return 1 + Game.world_party.size()


## Entries left today (resets when the Thai day changes).
static func runs_left(today := "") -> int:
	if not Game.has_profile:
		return 0
	var day := today if today != "" else GoalsData.today()
	var flags: Dictionary = Game.profile.flags
	if String(flags.get(F_DAY, "")) != day:
		return RUNS_PER_DAY
	return clampi(RUNS_PER_DAY - int(flags.get(F_RUNS, 0)), 0, RUNS_PER_DAY)


static func runs_text(today := "") -> String:
	return "เหลือ %d/%d รอบวันนี้" % [runs_left(today), RUNS_PER_DAY]


## Whether today's first clear chest is still waiting.
static func first_chest_ready(today := "") -> bool:
	var day := today if today != "" else GoalsData.today()
	return Game.has_profile and String(Game.profile.flags.get(F_FIRST, "")) != day


## "" when the party may go in now, otherwise why not (Thai).
static func entry_block(today := "") -> String:
	if not Game.has_profile:
		return "ยังไม่มีตัวละคร"
	if int(Game.profile.level) < MIN_LEVEL:
		return "ต้องเลเวล %d ขึ้นไป" % MIN_LEVEL
	if party_size() < MIN_PARTY:
		return "ต้องมีปาร์ตี้อย่างน้อย %d คน (ตอนนี้ %d คน) ชวนผู้เล่นเข้าปาร์ตี้ก่อน" % [MIN_PARTY, party_size()]
	if runs_left(today) <= 0:
		return "วันนี้เข้าครบ %d รอบแล้ว พรุ่งนี้มาใหม่นะ" % RUNS_PER_DAY
	return ""


## Spends one of today's entries and opens a run (a clear of it pays once, claim).
## Returns "" or why not.
static func enter(today := "") -> String:
	var why := entry_block(today)
	if why != "":
		return why
	var day := today if today != "" else GoalsData.today()
	var flags: Dictionary = Game.profile.flags
	if String(flags.get(F_DAY, "")) != day:
		flags[F_DAY] = day
		flags[F_RUNS] = 0
	flags[F_RUNS] = int(flags.get(F_RUNS, 0)) + 1
	flags[F_OPEN] = "%s#%d" % [day, int(flags[F_RUNS])]
	Game.mark_dirty()
	Game.save()
	return ""


## The run in progress ("" when none is open, or it was paid).
static func open_run() -> String:
	return String(Game.profile.flags.get(F_OPEN, "")) if Game.has_profile else ""


## World players worth asking along: online, not in the party yet, the closest in level
## first. Invites them (Game.party_invite) until the party has MIN_PARTY people; returns
## how many joined.
static func recruit(t: float = -1.0) -> int:
	if not Game.has_profile:
		return 0
	var now := t if t >= 0.0 else WorldPresence.clock()
	var level := int(Game.profile.level)
	var list: Array = []
	for i in WorldPlayers.size():
		if Game.in_party(i):
			continue
		var s := WorldPlayers.state(i, now)
		if not bool(s.online):
			continue
		list.append([absi(int(s.level) - level), i])
	list.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var joined := 0
	for entry in list:
		if party_size() >= MIN_PARTY or Game.world_party.size() >= Game.PARTY_MAX:
			break
		if Game.party_invite(int(entry[1])) == "":
			joined += 1
	return joined


# --- How strong ---------------------------------------------------------------------

## The party as numbers: {level (shown), stars, size, atk_sum, hp_avg, def_avg}.
## members: [{level, stars, atk, max_hp, def}], the hero first.
static func party_power(members: Array) -> Dictionary:
	var n := maxi(1, members.size())
	var level := 0.0
	var stars := 0.0
	var atk := 0.0
	var hp := 0.0
	var def := 0.0
	for m in members:
		level += float(m.get("level", 1))
		stars += float(m.get("stars", 0))
		atk += float(m.get("atk", 10))
		hp += float(m.get("max_hp", 100))
		def += float(m.get("def", 0))
	return {"level": int(round(level / n)), "stars": int(round(stars / n)), "size": members.size(),
		"atk_sum": atk, "hp_avg": hp / n, "def_avg": def / n}


## The level the raid's monsters show: the party's level, past Lv.100 its stars too.
static func shown_level(power: Dictionary) -> int:
	var lv := int(power.get("level", 1))
	if lv >= 100:
		return 100 + int(float(power.get("stars", 0)) * 0.45)
	return maxi(1, lv + 2)


## {hp, atk, def, level} of a raid monster of `role` ("trash", "mid", "boss").
static func monster_stats(power: Dictionary, role: String) -> Dictionary:
	var level := shown_level(power)
	var eff := float(level) if level <= 50 else 50.0 + float(level - 50) * 0.55
	var def := (1.0 + eff * 1.5) * (2.0 if role == "boss" else (1.6 if role == "mid" else 1.0))
	var dps := HeroStats.mitigate(float(power.get("atk_sum", 10.0)) * DPS_PER_ATK, def)
	var ttk: float = {"boss": BOSS_TTK, "mid": MID_TTK}.get(role, TRASH_TTK)
	var hit: float = {"boss": BOSS_HIT, "mid": MID_HIT}.get(role, TRASH_HIT)
	var atk := hit * float(power.get("hp_avg", 100.0)) * (100.0 + float(power.get("def_avg", 0.0))) / 100.0
	return {"hp": maxi(50, int(round(dps * ttk))), "atk": maxi(5, int(round(atk))), "def": int(round(def)), "level": level}


## What a floor holds: {ids: [StringName], mid: StringName (floor 2), boss: bool}.
static func floor_plan(floor_no: int, power: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pool := trash_pool(int(power.get("level", 1)))
	var extra := maxi(0, int(power.get("size", 3)) - MIN_PARTY)
	var ids: Array[StringName] = []
	var count: int = TRASH[clampi(floor_no - 1, 0, TRASH.size() - 1)]
	if count > 0:
		count += extra
	for i in count:
		ids.append(pool[rng.randi() % pool.size()])
	var plan := {"ids": ids, "mid": &"", "boss": floor_no >= FLOORS}
	if floor_no == 2:
		plan["mid"] = mid_boss(int(power.get("level", 1)))
	return plan


static func trash_pool(level: int) -> Array[StringName]:
	if level >= 100:
		return STAR_POOL
	var out: Array[StringName] = []
	var best := field_for(level)
	for camp in best.get("camps", []):
		for id in camp.monsters:
			if not out.has(StringName(id)):
				out.append(StringName(id))
	return out if not out.is_empty() else STAR_POOL


static func mid_boss(level: int) -> StringName:
	if level >= 100:
		return STAR_MID
	return StringName(field_for(level).get("boss", {}).get("monster", STAR_MID))


static func field_for(level: int) -> Dictionary:
	var best := ZoneData.get_zone(&"meadow")
	for id in FIELDS:
		var info := ZoneData.get_zone(id)
		if level >= int(info.level[0]):
			best = info
	return best


# --- Rewards ------------------------------------------------------------------------

## The clear's rewards: {gold, exp, items: [item], first: bool}. The first clear of the
## day adds the chest: more jewels and, for 250★ parties, a sure set core (SetGearData).
static func rewards(level: int, stars: int, first: bool, rng: RandomNumberGenerator) -> Dictionary:
	var eff := float(level) + float(stars) * 0.45
	var gold := int(round((6000.0 + eff * eff * 5.0) * (1.0 if first else 0.5)))
	var exp_amount := 0
	if level < Game.MAX_LEVEL:
		exp_amount = int(round(float(HeroStats.exp_to_next(level)) * (0.3 if first else 0.15)))
	else:
		exp_amount = int(round(float(HeroStats.star_need(clampi(stars, 0, Game.PARAGON_MAX - 1))) * (0.35 if first else 0.18)))
	var items: Array = []
	var jewels := {"purple": 6, "pink": 4, "chaos": 4} if first else {"purple": 3, "pink": 2, "chaos": 2}
	if stars >= 50:
		jewels["feather"] = 2 if first else 1
	for id in jewels:
		items.append(ItemData.jewel(id, int(jewels[id])))
	var core_chance := 0.0
	if stars >= SetGearData.STARS:
		core_chance = 1.0 if first else 0.25
	elif stars >= 200:
		core_chance = 0.3 if first else 0.08
	if core_chance > 0.0 and rng.randf() < core_chance:
		items.append(ItemData.jewel(SetGearData.CORE, 1))
	if first:
		items.append(ItemData.potion("hp_xl" if level >= 60 else "hp_l", 5))
	return {"gold": gold, "exp": maxi(1, exp_amount), "items": items, "first": first}


## Pays the open run's clear once (Game: gold, EXP, items into the bag or storage) and
## returns what it paid, or {} when there is nothing open (already paid).
static func claim(rng: RandomNumberGenerator, today := "") -> Dictionary:
	if open_run() == "":
		return {}
	var day := today if today != "" else GoalsData.today()
	var flags: Dictionary = Game.profile.flags
	var first := String(flags.get(F_FIRST, "")) != day
	flags[F_OPEN] = ""
	if first:
		flags[F_FIRST] = day
	var paid := rewards(int(Game.profile.level), int(Game.paragon().level), first, rng)
	Game.add_gold(int(paid.gold))
	Game.add_exp(int(paid.exp))
	for item in paid.items:
		Game.give_or_store(item)
	Game.flag_add(F_CLEARS)
	if Game.has_method("daily_progress"):
		Game.daily_progress("raid", 1)
	Game.mark_dirty()
	Game.save()
	return paid


## One line per reward (the result screen and the chat).
static func reward_lines(paid: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if paid.is_empty():
		return out
	out.append("เหรียญ +%d · EXP +%d" % [int(paid.gold), int(paid.exp)])
	for item in paid.items:
		out.append("%s x%d" % [ItemData.name_of(item), int(item.get("count", 1))])
	return out
