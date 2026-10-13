extends Node
## Damage balance report across the whole game, using the real formulas:
## HeroStats.compute, MonsterData.stats_for, HeroStats.mitigate and the skill
## rank multiplier. For every class at checkpoints from Lv.10 to the 200-star
## Lotus Sanctum, a hero wearing gear fit for that point fights a field's
## normal monster and its boss.
##   godot --headless --path . res://tests/tools/balance_probe.tscn [-- check]
## With "check" it fails (exit code = failures) when a field leaves its band.
## Columns: basic = basic hits to kill a normal monster, skill% = the best
## skill hit (rank 5, no crit) as a share of a normal monster's HP,
## boss = best-skill hits to kill the boss, die_n / die_b = normal / boss hits
## to kill the hero.

const CHECKPOINTS := [
	# [label, hero level, stars, zone, gear: "lv" | star tier | "divine"]
	# The hero sits in the middle of each field's level range, wearing rare
	# (+5) gear of that level, or the previous region's star set.
	["meadow", 4, 0, &"meadow", "lv"],
	["dark_forest", 10, 0, &"dark_forest", "lv"],
	["desert", 18, 0, &"desert", "lv"],
	["snow", 26, 0, &"snow", "lv"],
	["volcano", 35, 0, &"volcano", "lv"],
	["graveyard", 46, 0, &"graveyard", "lv"],
	["swamp", 58, 0, &"swamp", "lv"],
	["storm", 70, 0, &"storm", "lv"],
	["sky", 82, 0, &"sky", "lv"],
	["abyss", 94, 0, &"abyss", "lv"],
	["void", 100, 0, &"void", "lv"],
	["dawn_forest", 100, 25, &"dawn_forest", "lv"],
	["crystal_valley", 100, 75, &"crystal_valley", 50],
	["sky_citadel", 100, 125, &"sky_citadel", 100],
	["eclipse_realm", 100, 175, &"eclipse_realm", 150],
	["lotus_sanctum", 100, 200, &"lotus_sanctum", 200],
	["lotus_divine", 100, 200, &"lotus_sanctum", "divine"],
]

var rng := RandomNumberGenerator.new()
var failures := 0
## Basic hits for a normal monster and strongest-skill hits for the boss, per
## field, that ZONE_TUNING aims at (checked within 30%).
const AIM := {
	"meadow": [3, 12], "dark_forest": [4, 15], "desert": [5, 18], "snow": [6, 20],
	"volcano": [7, 22], "graveyard": [8, 24], "swamp": [9, 26], "storm": [10, 28],
	"sky": [11, 30], "abyss": [12, 32], "void": [28, 80], "dawn_forest": [62, 150],
	"crystal_valley": [84, 195], "sky_citadel": [105, 245], "eclipse_realm": [128, 320],
	"lotus_sanctum": [175, 450],
}
## Fields from Lv.100 whose monsters carry x2..x5 health (MonsterData.LATE_HP):
## their aims above are the earlier ones times that, and a skill takes a smaller
## share of a monster's health.
const LATE := ["void", "dawn_forest", "crystal_valley", "sky_citadel", "eclipse_realm", "lotus_sanctum", "lotus_divine"]


func _ready() -> void:
	rng.seed = 4242
	Game.set_process(false)
	var rows: Array = []
	for cp in CHECKPOINTS:
		for cls in ClassData.IDS:
			rows.append(_measure(cls, cp))
	_print(rows)
	_arena()
	if "check" in OS.get_cmdline_user_args():
		print("BALANCE CHECK: %s | %d failures" % ["PASS" if failures == 0 else "FAIL", failures])
		get_tree().quit(failures)
	else:
		get_tree().quit()


func _hero(cls: StringName, level: int, stars: int, gear: Variant) -> Dictionary:
	Game.new_profile(cls, "Balance")
	var p := Game.profile
	p.level = level
	p.adv = JobData.adv_for_level(level)
	var main := String(JobData.resolve(cls, int(p.adv)).main)
	# A reasonable build: two thirds of the points into the main stat, the rest into VIT.
	var points := Game.STAT_POINTS_PER_LEVEL * (level - 1)
	p.attrs = {"str": 0, "int": 0, "dex": 0, "vit": 0}
	p.attrs[main] = int(points * 2 / 3)
	p.attrs["vit"] = points - int(points * 2 / 3)
	var para := Game.paragon()
	para.level = stars
	var spend := stars
	for key in ["atk", "hp", "def", "crit"]:
		var put := mini(spend / 2 if key == "atk" else spend, int(Game.PARAGON_STATS[key][2]))
		para.alloc[key] = put
		spend -= put
	p.equip = {}
	for slot in ItemData.SLOTS:
		var item: Dictionary
		if typeof(gear) == TYPE_STRING and gear == "divine":
			item = DivineGearData.item(cls, slot, rng) if DivineGearData.SLOTS.has(slot) else StarProgression.item(cls, 200, slot, rng)
		elif typeof(gear) == TYPE_INT:
			item = StarProgression.item(cls, int(gear), slot, rng)
		else:
			item = ItemData.generate(level, cls, rng, 2, slot)
		item.plus = 5
		p.equip[slot] = item
	return HeroStats.compute(p)


func _measure(cls: StringName, cp: Array) -> Dictionary:
	var level: int = cp[1]
	var stars: int = cp[2]
	var stats := _hero(cls, level, stars, cp[4])
	var zone := ZoneData.get_zone(cp[3])
	var normal := {"hp": 0.0, "def": 0.0, "atk": 0.0}
	for camp in zone.camps:
		var mob_level := int((int(camp.levels[0]) + int(camp.levels[1])) / 2)
		var one := MonsterData.stats_for(StringName(camp.monsters[0]), mob_level)
		for key in normal:
			normal[key] += float(one[key]) / float(zone.camps.size())
	var boss_id := StringName(zone.boss.monster)
	var boss := MonsterData.stats_for(boss_id, int(zone.boss.level))
	var best := 1.0
	var tier := ClassData.tier_of(cls, JobData.adv_for_level(level))
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level and ClassData.skill_tier(skill) <= tier and int(skill.get("star", 0)) <= stars:
			best = maxf(best, float(skill.mult) * 1.6 * HeroStats.SKILL_POWER)
	var basic := HeroStats.mitigate(float(stats.atk), float(normal.def))
	var skill_hit := HeroStats.mitigate(float(stats.atk) * best, float(normal.def))
	var skill_boss := HeroStats.mitigate(float(stats.atk) * best, float(boss.def))
	var hurt_n := HeroStats.mitigate(float(normal.atk), float(stats.def))
	var hurt_b := HeroStats.mitigate(float(boss.atk) * 1.6, float(stats.def))
	return {"cp": cp[0], "cls": String(cls), "atk": int(stats.atk), "hp": int(stats.max_hp),
		"mob_hp": int(normal.hp), "boss_hp": int(boss.hp),
		"basic": float(normal.hp) / maxf(basic, 1.0), "skill_pct": 100.0 * skill_hit / float(normal.hp),
		"boss": float(boss.hp) / maxf(skill_boss, 1.0), "max_hit": int(skill_hit * HeroStats.CRIT_DAMAGE),
		"die_n": float(stats.max_hp) / maxf(hurt_n, 1.0), "die_b": float(stats.max_hp) / maxf(hurt_b, 1.0)}


func _print(rows: Array) -> void:
	# Per field: the median class, which tuning aims at.
	var by_zone := {}
	for r in rows:
		if not by_zone.has(r.cp): by_zone[r.cp] = []
		by_zone[r.cp].append(r)
	for cp in by_zone:
		var line := "ZONE %s" % cp
		for key in ["basic", "skill_pct", "boss", "die_n", "die_b", "max_hit"]:
			var values: Array = by_zone[cp].map(func(r): return float(r[key]))
			values.sort()
			var median: float = (float(values[2]) + float(values[3])) * 0.5
			line += " %s=%.2f" % [key, median]
			_band(cp, key, median)
		print(line)
	print("BALANCE checkpoint | class | atk | hp | mob_hp | basic | skill% | max_hit | boss | die_n | die_b")
	for r in rows:
		print("BALANCE %s | %s | %d | %d | %d | %.1f | %.0f%% | %d | %.1f | %.1f | %.1f" % [r.cp, r.cls, r.atk, r.hp, r.mob_hp,
			r.basic, r.skill_pct, r.max_hit, r.boss, r.die_n, r.die_b])


## Bands every field must stay in: nothing one-shots, nothing takes forever,
## monsters stay a threat and no hit is absurd.
func _band(cp: String, key: String, value: float) -> void:
	var ok := true
	match key:
		"basic": ok = not AIM.has(cp) or absf(value / float(AIM[cp][0]) - 1.0) <= 0.3
		"boss": ok = not AIM.has(cp) or absf(value / float(AIM[cp][1]) - 1.0) <= 0.3
		"skill_pct": ok = cp == "meadow" or (value >= (8.0 if cp in LATE else 25.0) and value <= 100.0)
		"die_n": ok = value >= 10.0 and value <= 40.0
		"die_b": ok = value >= 3.0 and value <= 15.0
		"max_hit": ok = value <= 120000.0
	if not ok:
		failures += 1
		printerr("FAIL %s %s = %.2f is out of its band" % [cp, key, value])


## Arena / ranked duel: a hero against PvpData's AI opponent at the bottom,
## middle and top of the ladder. Both sides use their strongest unlocked
## skill (rank 3) and basic attacks.
func _arena() -> void:
	for level in [30, 60, 100]:
		for rp in [0, PvpData.STEP_RP * PvpData.MAX_STEP / 2, PvpData.STEP_RP * PvpData.MAX_STEP]:
			var hero_skill := []
			var rival_skill := []
			var hero_basic := []
			for cls in ClassData.IDS:
				var stats := _hero(cls, level, 0, "lv")
				var info := PvpData.make_opponent(level, rp, rng, cls)
				var base := HeroStats.compute(info.profile)
				var r_hp := float(base.max_hp) * float(info.mults.hp)
				var r_atk := float(base.atk) * float(info.mults.atk)
				var r_def := float(base.def) * float(info.mults.def)
				var mine := _best_skill(cls, level, 1.3)
				var theirs := _best_skill(StringName(info.member["class"]), int(info.member.level), 1.0)
				hero_basic.append(r_hp / maxf(HeroStats.mitigate(float(stats.atk), r_def), 1.0))
				hero_skill.append(r_hp / maxf(HeroStats.mitigate(float(stats.atk) * mine, r_def), 1.0))
				rival_skill.append(float(stats.max_hp) / maxf(HeroStats.mitigate(r_atk * theirs, float(stats.def)), 1.0))
			var med := func(a: Array) -> float:
				a.sort()
				return (float(a[2]) + float(a[3])) * 0.5
			var line := "ARENA Lv%d rp%d basic=%.2f skill=%.2f rival_skill=%.2f" % [level, rp, med.call(hero_basic), med.call(hero_skill), med.call(rival_skill)]
			print(line)
			# Duels last: no side falls to one or two skills, none drags on.
			if med.call(hero_skill) < 4.0 or med.call(hero_skill) > 20.0 or med.call(rival_skill) < 4.0 or med.call(rival_skill) > 25.0:
				failures += 1
				printerr("FAIL arena out of band: " + line)


## Strongest unlocked skill multiplier as dealt in combat (rank multiplier,
## SKILL_POWER), at least a basic attack.
func _best_skill(cls: StringName, level: int, rank: float) -> float:
	var best := 1.0
	var tier := ClassData.tier_of(cls, JobData.adv_for_level(level))
	for skill in ClassData.pool(cls):
		if int(skill.level) <= level and ClassData.skill_tier(skill) <= tier and not skill.has("star"):
			best = maxf(best, float(skill.mult) * rank * HeroStats.SKILL_POWER)
	return best
