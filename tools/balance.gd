extends SceneTree
## Rough progression simulator (no 3D): how long one monster takes to kill, how
## much HP it costs and how many minutes a level takes, per class.
##   godot --headless --path . -s res://tools/balance.gd
const OVERHEAD := 4.0   # seconds between kills (walking, targeting)


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var total_all := {}
	for c in ClassData.IDS:
		print("== %s" % ClassData.get_class_data(c).name)
		print("  Lv | zone        | TTK s | HP lost/kill | kills/lv | min/lv | total min")
		var total := 0.0
		for level in range(1, 41):
			var zone := _zone_for(level)
			var mon := _avg_monster(zone, level)
			var profile := _profile(c, level, rng)
			var stats := HeroStats.compute(profile)
			var data := JobData.resolve(c, StringName(profile.job))
			var dps := _dps(data, stats, level)
			var net_hit := float(mon.stats.def)
			var dmg_mult := 100.0 / (100.0 + net_hit)
			var ttk := float(mon.stats.hp) / maxf(dps * dmg_mult, 1.0)
			var mon_dps := float(mon.stats.atk) * (100.0 / (100.0 + float(stats.def))) / 2.3 * 0.65
			var hp_lost := mon_dps * ttk / float(stats.max_hp)
			var exp_kill := float(mon.stats.exp) * _exp_scale(level, int(mon.level))
			var kills := float(HeroStats.exp_to_next(level)) / maxf(exp_kill, 1.0)
			var minutes := kills * (ttk + OVERHEAD) / 60.0
			total += minutes
			if level in [1, 3, 5, 8, 10, 12, 15, 18, 20, 23, 25, 28, 30, 33, 35, 38, 40]:
				print("  %2d | %-11s | %5.1f | %10.0f%% | %8.1f | %6.1f | %7.0f" % [level, zone, ttk, hp_lost * 100.0, kills, minutes, total])
		total_all[c] = total
	print("Total minutes to Lv.40: ", total_all)
	quit()


func _zone_for(level: int) -> String:
	for id in [&"volcano", &"snow", &"desert", &"dark_forest", &"meadow"]:
		if level >= int(ZoneData.get_zone(id).level[0]):
			return String(id)
	return "meadow"


## The average monster of the zone camps at a level a little above the hero's.
func _avg_monster(zone: String, level: int) -> Dictionary:
	var info := ZoneData.get_zone(StringName(zone))
	var hp := 0.0
	var atk := 0.0
	var def := 0.0
	var count := 0
	var lvl := clampi(level, int(info.level[0]), int(info.level[1]))
	var exp_total := 0.0
	for camp in info.camps:
		for m in camp.monsters:
			var s := MonsterData.stats_for(m, lvl)
			hp += float(s.hp)
			atk += float(s.atk)
			def += float(s.def)
			exp_total += float(s.exp)
			count += 1
	return {"level": lvl, "stats": {"hp": hp / count, "atk": atk / count, "def": def / count, "exp": exp_total / count}}


func _exp_scale(hero_level: int, mon_level: int) -> float:
	var gap := hero_level - mon_level
	return 1.0 if gap <= 4 else maxf(0.15, 1.0 - 0.17 * float(gap - 4))


func _profile(c: StringName, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var data := ClassData.get_class_data(c)
	var points := (level - 1) * Game.STAT_POINTS_PER_LEVEL
	var attrs := {"str": 0, "int": 0, "dex": 0, "vit": 0}
	attrs[data.main] = int(points * 0.65)
	attrs["vit"] = int(points * 0.35)
	var equip := {}
	for slot in ["weapon", "armor", "helm", "boots"]:
		equip[slot] = ItemData.generate(maxi(1, level - 2), c, rng, 0 if rng.randf() < 0.7 else 1, slot)
	var job := ""
	if level >= JobData.JOB_LEVEL:
		job = String(JobData.jobs_for(c)[0])
	return {"class": String(c), "level": level, "attrs": attrs, "equip": equip, "job": job}


func _dps(data: Dictionary, stats: Dictionary, level: int) -> float:
	var atk: float = stats.atk
	var crit_mult := 1.0 + float(stats.crit) * (HeroStats.CRIT_DAMAGE - 1.0)
	var attack: Dictionary = data.attack
	var basic := atk * float(attack.mult) * crit_mult / (float(attack.interval) * 1.05)
	var skill_dps := 0.0
	for skill in data.skills:
		if int(skill.level) > level or float(skill.get("mult", 0.0)) <= 0.0:
			continue
		var targets := 1.0
		if skill.shape == "burst" or skill.shape == "blast":
			targets = 2.0
		elif skill.shape == "fan" or skill.shape == "chain":
			targets = 2.0
		var rank := 1.0 + 0.15 * float(clampi(level / 5, 0, 4))
		skill_dps += atk * float(skill.mult) * rank * crit_mult * targets / (float(skill.cd) + 0.9) * 0.6
	return basic + skill_dps
