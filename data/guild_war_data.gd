class_name GuildWarData
extends RefCounted
## Guild war: two guilds of five fight for 30 minutes. Our guild is the hero plus four
## AI players, the rival guild is five AI players. Every AI is Lv.100 with 200 stars,
## a random class and a gear grade from a plain 50-star set up to the class's divine
## set with wings, built from the same star gear a real player can wear (so the
## AI is as strong as a player in the same gear). Our four allies are picked so both
## guilds field about the same total power; the hero fights with the real character.

const TEAM_SIZE := 5
const DURATION := 1800.0
## A fallen fighter comes back at its base this many seconds later.
const RESPAWN := 8.0
const LEVEL := 100
const STARS := 200
## How sharp the AI plays (0..1, see Rival): quick to react, a few human slips.
const SKILL := 0.9
## Same class at most this many times in one guild.
const MAX_SAME_CLASS := 2
## Everything hurts this many times more in a war. A 200-star fighter's defence cuts almost
## all damage (against monsters that is what keeps the game steady), so between two such
## fighters a fall would take minutes; this brings a fall to about 15-30 seconds.
static var damage_scale := 12.0
## Total power of the two guilds may differ by at most this share.
const BALANCE_TOLERANCE := 0.06

## Gear grades, weakest first: stars of the star set, or DIVINE for the class's divine
## set. Wings come with 100 stars and up (they unlock there).
const DIVINE := 300
const GRADES: Array[int] = [50, 100, 150, 200, DIVINE]
const GRADE_NAMES := {50: "ชุด 50★", 100: "ชุด 100★ + ปีก", 150: "ชุด 150★ + ปีก", 200: "ชุด 200★ + ปีก", DIVINE: "ชุดประจำอาชีพ + ปีก"}

const GUILDS := ["อัศวินอรุณ", "เงาจันทรา", "มังกรเพลิง", "สายฟ้าฟ้าคราม", "ราชสีห์ทอง", "หมาป่าพายุ", "ผีเสื้อราตรี", "ดาบนภา"]


## One fighter ready for GuildFighter.setup_fighter.
static func make_fighter(class_id: StringName, grade: int, name: String, rng: RandomNumberGenerator) -> Dictionary:
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = rng.randi()
	var equip := {}
	for slot in ItemData.SLOTS:
		if grade == DIVINE and slot in DivineGearData.SLOTS:
			equip[slot] = DivineGearData.item(class_id, slot, gear_rng)
		else:
			equip[slot] = StarProgression.item(class_id, mini(grade, STARS), slot, gear_rng)
	if grade >= StarWingData.REQUIRED_STARS:
		equip["wings"] = StarWingData.item(String(class_id), gear_rng)
	var data := JobData.resolve(class_id, JobData.adv_for_level(LEVEL))
	# A full Lv.100 character: every stat point spent, 60% on the main stat, 40% vitality.
	var points := Game.STAT_POINTS_PER_LEVEL * (LEVEL - 1)
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[String(data.main)] = int(points * 0.6)
	attrs["vit"] = int(points * 0.4)
	var profile := {"class": String(class_id), "level": LEVEL, "attrs": attrs, "equip": equip, "adv": JobData.adv_for_level(LEVEL),
			"paragon": {"level": STARS, "alloc": Game.party_star_alloc(STARS)}}
	return {
		"member": {"class": String(class_id), "name": name, "level": LEVEL},
		"profile": profile,
		"mults": {"hp": 1.0, "atk": 1.0, "def": 1.0},
		"difficulty": SKILL,
		"look": FaceKit.random_look(rng),
		"grade": grade,
		"power": power_of(HeroStats.compute(profile)),
	}


## One number for "how strong": attack times staying power.
static func power_of(stats: Dictionary) -> float:
	return sqrt(float(stats.atk) * float(stats.max_hp) * (1.0 + float(stats.def) / 100.0))


static func hero_power() -> float:
	return power_of(Game.stats_now())


## The two guilds: { ally: [4 fighters], enemy: [5 fighters], ally_name, enemy_name, ally_power, enemy_power }.
## Classes and grades are random; the rival line-up is picked to match our guild's total power.
static func roll_match(rng: RandomNumberGenerator, power_of_hero: float = -1.0) -> Dictionary:
	if power_of_hero < 0.0:
		power_of_hero = hero_power()
	var hero_class := Game.class_id()
	var names := PvpData.NAMES.duplicate()
	var used := {}
	var take_name := func() -> String:
		for i in 40:
			var name: String = names[rng.randi() % names.size()]
			if not used.has(name):
				used[name] = true
				return name
		return "%s%d" % [names[0], used.size()]
	# One candidate per (class, grade): same gear is reused wherever it is picked.
	var pool := {}
	var classes: Array[StringName] = []
	for id in StarGearData.CLASSES:
		classes.append(StringName(id))
	for id in classes:
		for grade in GRADES:
			pool["%s|%d" % [id, grade]] = make_fighter(id, grade, "", rng)
	# Our four allies are random; the rival guild is the best of many random line-ups at
	# matching hero + allies in total power, so a match is never lopsided before it starts.
	var best: Array = _pick_team(rng, classes, pool, TEAM_SIZE - 1, [hero_class])
	var ally_power := power_of_hero
	for f in best:
		ally_power += float(f.power)
	var enemy: Array = []
	var enemy_power := 0.0
	var best_gap := INF
	for attempt in 300:
		var line_up := _pick_team(rng, classes, pool, TEAM_SIZE, [])
		var total := 0.0
		for f in line_up:
			total += float(f.power)
		var gap := absf(total - ally_power) / ally_power
		if gap < best_gap:
			best_gap = gap
			enemy = line_up
			enemy_power = total
		if gap < BALANCE_TOLERANCE * 0.4:
			break
	var all_fighters := enemy + best
	for f in all_fighters:
		f.member["name"] = take_name.call()
	var guild_a: String = GUILDS[rng.randi() % GUILDS.size()]
	var guild_b: String = GUILDS[rng.randi() % GUILDS.size()]
	while guild_b == guild_a:
		guild_b = GUILDS[rng.randi() % GUILDS.size()]
	return {"ally": best, "enemy": enemy, "ally_name": guild_a, "enemy_name": guild_b, "ally_power": ally_power, "enemy_power": enemy_power}


static func _pick_team(rng: RandomNumberGenerator, classes: Array[StringName], pool: Dictionary, count: int, already: Array) -> Array:
	var team: Array = []
	var counts := {}
	for id in already:
		counts[id] = int(counts.get(id, 0)) + 1
	while team.size() < count:
		var id: StringName = classes[rng.randi() % classes.size()]
		if int(counts.get(id, 0)) >= MAX_SAME_CLASS:
			continue
		counts[id] = int(counts.get(id, 0)) + 1
		var grade: int = GRADES[rng.randi() % GRADES.size()]
		var source: Dictionary = pool["%s|%d" % [id, grade]]
		var copy := source.duplicate(true)
		copy["look"] = FaceKit.random_look(rng)
		team.append(copy)
	return team


static func grade_label(grade: int) -> String:
	return String(GRADE_NAMES.get(grade, "ชุด %d★" % grade))


## Gold for a finished war: more for winning and for every fall you scored.
static func gold_reward(won: bool, kills: int) -> int:
	return (80000 if won else 30000) + 1500 * kills


## EXP (stars at Lv.100) for a finished war.
static func exp_reward(level: int, won: bool) -> int:
	return int(HeroStats.exp_to_next(level) * (0.12 if won else 0.05))
