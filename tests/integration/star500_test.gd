extends Node
## The star cap at ★500 and the special pool (Game.SPECIAL_STATS / HeroStats.SPECIAL_STATS):
## - PARAGON_MAX is 500; ★1-★300 still feed the five old stats (60 each), ★301-★500 a
##   point each into the special pool (cdmg, pierce, guard, leech, cdr: 40 points each).
## - Past ★300 every star asks 1.5x the curve's continuation (HeroStats.star_need).
## - Each special stat's effect: crit damage, DEF ignored (ClassRoles.pierced), damage
##   taken (BuffBook.absorb, still under 45% in all), lifesteal, cooldowns.
## - The gold reset, the AI's role-based allocation, the save check, repair and round trips,
##   the star page's special section.

var checks := 0
var failures := 0


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func hero_at(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Star500 QA")
	Game.profile.level = Game.MAX_LEVEL
	Game.profile.exp = 0
	Game.profile.adv = JobData.GOD_ADV if stars >= JobData.GOD_STARS else JobData.LEGEND_ADV
	Game.profile.paragon = {"level": stars, "exp": 0, "points": mini(stars, 300), "spent": 0, "alloc": {}}
	Game.profile.equip = {}
	Game.profile.party = []
	Game.fill_loadout()
	Game.check_achievements()
	Game.profile.gold = 0


func _ready() -> void:
	Game.set_process(false)
	_cap()
	_curve()
	_climb()
	_spend_and_reset()
	_effects()
	await _live_hero()
	_ai()
	_saves()
	await _ui()
	Game.has_profile = false
	print("STAR500: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _cap() -> void:
	check(Game.PARAGON_MAX == 500 and Game.PARAGON_BASE_MAX == 300 and Game.SPECIAL_FROM == 301, "★500 cap, special pool from ★301")
	check(JobData.GOD_STARS == 300, "the God step stays at ★300")
	for key in ["atk", "def", "hp", "crit", "haste"]:
		check(int(Game.PARAGON_STATS[key][2]) == 60, "%s keeps its cap of 60" % key)
	var room := 0
	for key in Game.SPECIAL_STATS:
		check(int(Game.SPECIAL_STATS[key][2]) == 40, "%s caps at 40" % key)
		room += int(Game.SPECIAL_STATS[key][2])
	check(room == Game.PARAGON_MAX - Game.PARAGON_BASE_MAX, "the special caps hold every point of ★301-★500 (%d)" % room)
	check(Game.SPECIAL_STATS.keys() == ["cdmg", "pierce", "guard", "leech", "cdr"], "the five special stats")
	var full := {"cdmg": 0.20, "pierce": 0.20, "guard": 0.06, "leech": 0.02, "cdr": 0.04}
	for key in full:
		check(is_equal_approx(float(Game.SPECIAL_STATS[key][1]) * 40.0, float(full[key])), "%s at 40 points gives %.2f" % [key, float(full[key])])
	check(Game.special_earned(300) == 0 and Game.special_earned(301) == 1 and Game.special_earned(500) == 200 and Game.special_earned(999) == 200, "special points earned")


func _curve() -> void:
	var base := float(HeroStats.exp_to_next(100)) * HeroStats.STAR_EXP
	for star in [0, 150, 299]:
		var growth := 0.02 * float(star) + 0.02 * float(maxi(0, star - 200))
		check(HeroStats.star_need(star) == int(base * (1.0 + growth)), "★%d's cost is unchanged" % star)
	for star in [300, 400, 499]:
		var growth := 0.02 * float(star) + 0.02 * float(star - 200)
		check(HeroStats.star_need(star) == int(base * (1.0 + growth) * 1.5), "★%d costs 1.5x the curve's continuation" % star)
	var low := 0.0
	var high := 0.0
	for star in 300:
		low += HeroStats.star_need(star)
	for star in range(300, 500):
		high += HeroStats.star_need(star)
	check(high > low * 2.0, "★300 -> ★500 is a long goal (%.2fx the ★0 -> ★300 EXP)" % (high / low))


func _climb() -> void:
	hero_at(&"warrior", 298)
	while int(Game.paragon().level) < 301:
		Game.add_exp(1 if int(Game.paragon().level) == 300 else maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
	var p := Game.paragon()
	check(int(p.level) == 301 and int(p.points) == 300 and Game.special_points() == 1, "★301: the old pool stops at 300 points, one special point (★%d, %d, %d)" % [int(p.level), int(p.points), Game.special_points()])
	var guard := 0
	while int(Game.paragon().level) < Game.PARAGON_MAX and guard < 400:
		Game.add_exp(maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
		guard += 1
	p = Game.paragon()
	check(int(p.level) == 500 and int(p.points) == 300 and Game.special_points() == 200, "climbs to ★500: 300 + 200 special points")
	check(Game.paragon_need() == 0 and int(p.exp) == 0, "no EXP kept at ★500")
	Game.add_exp(999999999)
	check(int(Game.paragon().level) == 500, "no star past 500")
	check(Game.exp_ratio() >= 0.0 and Game.exp_ratio() <= 1.0, "the EXP bar stays valid at ★500")


func _spend_and_reset() -> void:
	hero_at(&"warrior", 350)
	check(Game.special_points() == 50, "★350: 50 special points")
	check(not Game.special_spend("crit", 1) and not Game.special_spend("cdmg", 0), "unknown key / zero count refused")
	check(Game.special_spend("cdmg", 1000) and int(Game.paragon().special.cdmg) == 40, "cdmg stops at 40")
	check(Game.special_spend("pierce", 1000) and int(Game.paragon().special.pierce) == 10 and Game.special_points() == 0, "the rest goes to pierce, nothing left")
	check(not Game.special_spend("guard", 1), "no special point left")
	check(Game.paragon_spend("atk", 10) and int(Game.paragon().alloc.atk) == 10, "the old pool works alongside")
	Game.profile.gold = Game.SPECIAL_RESET_COST - 1
	check(not Game.special_reset() and int(Game.paragon().special.cdmg) == 40, "the reset needs %d gold" % Game.SPECIAL_RESET_COST)
	Game.profile.gold = Game.SPECIAL_RESET_COST + 7
	check(Game.special_reset() and int(Game.profile.gold) == 7, "the reset takes 1,000,000 gold")
	check(Game.special_points() == 50 and Game.special_spent_of(Game.paragon().special) == 0, "every special point comes back")
	check(int(Game.paragon().alloc.atk) == 10 and int(Game.paragon().spent) == 10, "the old five stats are untouched by it")
	check(not Game.special_reset(), "nothing to reset")
	hero_at(&"warrior", 300)
	check(Game.special_points() == 0 and not Game.special_spend("cdmg", 1), "locked at ★300")


func _sheet(special: Dictionary) -> Dictionary:
	return {"class": "warrior", "level": 100, "attrs": {}, "equip": {}, "adv": 5,
		"paragon": {"level": 500, "alloc": Game.party_star_alloc(500), "special": special}}


func _effects() -> void:
	var zero := HeroStats.compute(_sheet({}))
	var full := HeroStats.compute(_sheet({"cdmg": 40, "pierce": 40, "guard": 40, "leech": 40, "cdr": 40}))
	check(is_equal_approx(float(full.crit_dmg) - float(zero.crit_dmg), 0.20), "cdmg 40: crit damage +20%")
	check(is_equal_approx(float(full.pierce), 0.20) and float(zero.pierce) == 0.0, "pierce 40: 20% of DEF ignored")
	check(is_equal_approx(float(full.guard), 0.06) and float(zero.guard) == 0.0, "guard 40: 6% less damage taken")
	check(is_equal_approx(float(full.lifesteal) - float(zero.lifesteal), 0.02), "leech 40: lifesteal +2%")
	check(is_equal_approx(float(full.cdr) - float(zero.cdr), 0.04), "cdr 40: cooldowns -4%")
	check(is_equal_approx(float(full.atk), float(zero.atk)) and int(full.max_hp) == int(zero.max_hp), "the special pool leaves ATK and HP alone")
	var over := HeroStats.compute(_sheet({"cdmg": 99}))
	check(is_equal_approx(float(over.crit_dmg) - float(zero.crit_dmg), 0.20), "a forged 99 counts as 40")
	# On top of the gems' capped parts: onyx / pearl / opal past their caps.
	var gems := _sheet({"cdmg": 40, "leech": 40, "cdr": 40})
	var gem_ids: Array = []
	for i in 4:
		gem_ids.append_array([ItemData.gem("onyx", 4).id, ItemData.gem("pearl", 4).id, ItemData.gem("opal", 4).id])
	gems.equip = {"weapon": {"id": "w", "slot": "weapon", "level": 100, "stats": {"atk": 10}, "gems": gem_ids}}
	var capped := HeroStats.compute(gems)
	check(is_equal_approx(float(capped.crit_dmg), HeroStats.MAX_CRIT_DMG + 0.20), "crit damage: gems' cap + 20%% (%.3f)" % float(capped.crit_dmg))
	check(is_equal_approx(float(capped.lifesteal), HeroStats.MAX_LIFESTEAL + 0.02), "lifesteal: gems' cap + 2%% (%.3f)" % float(capped.lifesteal))
	check(is_equal_approx(float(capped.cdr), HeroStats.MAX_CDR + 0.04), "cdr: gems' cap + 4%% (%.3f)" % float(capped.cdr))
	# Guard: a separate cut with the buffs', never past 45% in all.
	var far := Time.get_ticks_msec() + 60000
	check(BuffBook.absorb([], 1000, 0.06) == 940, "6% guard alone: 1000 -> 940")
	check(BuffBook.absorb([{"until": far, "guard": 0.2}], 1000, 0.06) == int(ceil(1000.0 * 0.8 * 0.94)), "with a 20%% guard buff: multiplicative (%d)" % BuffBook.absorb([{"until": far, "guard": 0.2}], 1000, 0.06))
	check(BuffBook.absorb([{"until": far, "guard": 0.45}], 1000, 0.06) == 550, "a 45% guard buff: the total stays at 45%")
	check(BuffBook.absorb([{"until": far, "guard": 0.42}], 1000, 0.06) == 550, "42% + 6%: capped at 45%")
	check(BuffBook.absorb([], 1000) == 1000, "no guard, no cut")
	# Guild war power counts pierce and guard (0 below ★301).
	check(GuildWarData.power_of(full) > GuildWarData.power_of(zero), "guild war power counts the special pool")
	check(is_equal_approx(GuildWarData.power_of(zero), sqrt(float(zero.atk) * float(zero.max_hp) * (1.0 + float(zero.def) / 100.0))), "power unchanged without it")
	# A rival / guild fighter's own pierce (rstats), and its guard on the blows it takes.
	var rival := Rival.new()
	rival.rstats = {"pierce": 0.2, "guard": 0.06}
	check(is_equal_approx(ClassRoles.own_pierce(rival), 0.2) and is_equal_approx(ClassRoles.pierced(rival, 100.0), 80.0), "a fighter's own pierce: 100 DEF -> 80")
	rival.free()
	check(ClassRoles.own_pierce(null) == 0.0, "no attacker, no pierce")


func _live_hero() -> void:
	hero_at(&"warrior", 500)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.refresh_stats()
	await get_tree().process_frame
	var crit0 := hero.crit_mult()
	var skill: Dictionary = ClassData.pool(&"warrior")[0]
	var cd0 := hero.cooldown_of(skill)
	var hits0 := _hit_taken(hero)
	check(is_equal_approx(ClassRoles.pierced(hero, 100.0), 100.0), "no pierce before the points")
	for key in Game.SPECIAL_STATS:
		Game.special_spend(key, 40)
	hero.refresh_stats()
	check(is_equal_approx(hero.crit_mult() - crit0, 0.20), "the hero's crits hit 20%% harder (%.2f -> %.2f)" % [crit0, hero.crit_mult()])
	check(is_equal_approx(ClassRoles.pierced(hero, 100.0), 80.0), "the hero's hits see 20% less DEF")
	check(is_equal_approx(hero.cooldown_of(skill), cd0 * 0.96), "the hero's cooldowns 4%% shorter (%.3f -> %.3f)" % [cd0, hero.cooldown_of(skill)])
	var hits1 := _hit_taken(hero)
	check(hits1 == int(ceil(float(hits0) * 0.94)) or absi(hits1 - int(round(float(hits0) * 0.94))) <= 1, "the hero takes 6%% less (%d -> %d)" % [hits0, hits1])
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp / 2
	hero._leech_left = 0.0
	hero._leech(10000)
	check(int(Game.profile.hp) == max_hp / 2 + 200, "lifesteal 2%%: 10000 dealt heals 200 (%d)" % (int(Game.profile.hp) - max_hp / 2))
	field.queue_free()
	await field.tree_exited


## HP the hero loses to a 5000 raw blow (no dodge, no invulnerability).
func _hit_taken(hero: Hero) -> int:
	hero.stats["dodge"] = 0.0
	hero._invulnerable_until = 0
	Game.profile.hp = 10000000
	var before := int(Game.profile.hp)
	hero.take_damage(50000.0, null)
	return before - int(Game.profile.hp)


func _ai() -> void:
	check(Game.party_special_alloc(300, "warrior").values().all(func(v): return int(v) == 0), "no special point at ★300")
	var dmg := Game.party_special_alloc(340, "warrior")
	check(int(dmg.cdmg) == 40 and int(dmg.pierce) == 0, "a damage class: crit damage first")
	dmg = Game.party_special_alloc(370, "assassin")
	check(int(dmg.cdmg) == 40 and int(dmg.pierce) == 30, "then pierce")
	var tank := Game.party_special_alloc(350, "defender")
	check(int(tank.guard) == 40 and int(tank.leech) == 10 and int(tank.cdmg) == 0, "the Defender: guard, then lifesteal")
	var heal := Game.party_special_alloc(360, "priest")
	check(int(heal.cdr) == 40 and int(heal.guard) == 20, "a healer: cooldowns, then guard")
	check(Game.special_role("bard") == "support" and Game.special_role("summoner") == "support" and Game.special_role("mage") == "damage", "the roles")
	for cls in ClassData.IDS:
		var a := Game.party_special_alloc(500, cls)
		check(Game.special_spent_of(a) == 200 and a == Game.party_special_alloc(500, cls), "%s: all 200 points, the same every time" % cls)
	check(Game.special_spent_of(Game.party_star_alloc(500)) == 300, "the old five stats still take 300 at ★500")
	var sheet := WorldPlayers.profile({"class": "mage", "name": "Star500 AI", "level": 100, "stars": 360, "frac": 0.0, "divine_frac": 0.0})
	check(int(sheet.paragon.special.cdmg) == 40 and int(sheet.paragon.special.pierce) == 20, "a world player's sheet spends its special points (%s)" % str(sheet.paragon.special))
	check(is_equal_approx(float(HeroStats.compute(sheet).pierce), 0.10), "and they count in its stats")
	var party := Game.party_profile({"class": "defender", "name": "Star500 Mate", "level": 100, "stars": 320})
	check(int(party.paragon.special.guard) == 20, "a companion's sheet spends its points by role")
	# The pace model: endless play reaches ★500, past ★300 the stars take longer.
	var steps := WorldPlayers._steps()
	check(steps.size() == Game.MAX_LEVEL + Game.PARAGON_MAX, "the progress table runs to ★500 (%d)" % steps.size())
	var full := WorldPlayers.progress_for(1e10, 0.3)
	check(int(full.stars) == 500, "endless play reaches ★500")
	var to300 := steps[Game.MAX_LEVEL - 1 + 300] - steps[Game.MAX_LEVEL - 1]
	var to500 := steps[Game.MAX_LEVEL - 1 + 500] - steps[Game.MAX_LEVEL - 1 + 300]
	check(to500 > to300 * 1.5, "★300 -> ★500 takes longer than ★0 -> ★300 (%.0f vs %.0f probe minutes)" % [to500, to300])
	var tanky := GuildWarData.tank_build({"profile": WorldPlayers.profile({"class": "lancer", "name": "Star500 Tank", "level": 100, "stars": 340, "frac": 0.0, "divine_frac": 0.0})})
	check(int(tanky.profile.paragon.special.guard) == 40, "a guild leader's tank build: guard first")


func _saves() -> void:
	hero_at(&"darklord", 500)
	for key in Game.SPECIAL_STATS:
		Game.special_spend(key, 40)
	for key in Game.PARAGON_STATS:
		Game.paragon_spend(key, 60)
	check(Game._valid_profile(Game.profile), "a ★500 hero with every point spent passes the save check")
	check(Game.save_code_roundtrip(), "and the save code")
	Game.slot = 1
	check(Game.save(), "it saves")
	Game.paragon().special.cdmg = 0
	check(Game.load_game(1) and int(Game.paragon().special.cdmg) == 40 and int(Game.paragon().level) == 500, "the special pool comes back from the save file")
	var bundle := Game.build_cloud_bundle()
	var cloud: Variant = bundle.slots.get("1")
	check(cloud is Dictionary and int(cloud.paragon.special.guard) == 40, "the cloud bundle carries it")
	var bad: Dictionary = Game.profile.duplicate(true)
	bad.paragon.special.cdmg = 41
	check(not Game._valid_profile(bad), "41 points refused")
	bad = Game.profile.duplicate(true)
	bad.paragon.special["crit"] = 1
	check(not Game._valid_profile(bad), "an unknown special key refused")
	bad = Game.profile.duplicate(true)
	bad.paragon.special = [1]
	check(not Game._valid_profile(bad), "a special that is not a dictionary refused")
	bad = Game.profile.duplicate(true)
	bad.paragon.level = 310
	bad.paragon.special = {"cdmg": 11}
	check(not Game._valid_profile(bad), "more special points than stars past 300 refused")
	bad.paragon.special = {"cdmg": 10}
	check(Game._valid_profile(bad), "exactly the earned points pass")
	bad = Game.profile.duplicate(true)
	bad.paragon.special.pierce = 1.5
	check(not Game._valid_profile(bad), "a fraction refused")
	# Repair: trims to what the stars earned, idempotent; an old save gets an empty pool.
	var trim := {"level": 305, "special": {"cdmg": 40, "pierce": 3, "bogus": 9}}
	Game.repair_special(trim)
	check(trim.special == {"cdmg": 5, "pierce": 0, "guard": 0, "leech": 0, "cdr": 0}, "repair trims to the earned points (%s)" % str(trim.special))
	var again := trim.duplicate(true)
	Game.repair_special(again)
	check(again == trim, "repair is idempotent")
	var old: Dictionary = Game.profile.duplicate(true)
	old.paragon = {"level": 300, "exp": 0, "points": 0, "spent": 300, "alloc": {"atk": 60, "def": 60, "hp": 60, "crit": 60, "haste": 60}}
	check(Game._valid_profile(old), "a ★300 save from before the pool passes")
	var fixed := Game._repair(old.duplicate(true))
	check(Game.special_spent_of(fixed.paragon.special) == 0 and fixed.paragon.special.size() == 5 and Game._valid_profile(fixed), "and repairs to an empty pool")
	var twice := Game._repair(fixed.duplicate(true))
	check(twice.paragon == fixed.paragon, "repairing twice changes nothing")
	var high: Dictionary = Game.profile.duplicate(true)
	var repaired := Game._repair(high.duplicate(true))
	check(int(repaired.paragon.special.cdr) == 40 and int(repaired.paragon.level) == 500, "repair keeps a valid ★500 pool")


func _ui() -> void:
	hero_at(&"warrior", 300)
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await get_tree().process_frame
	check(menu.find_child("SpecialStats", true, false) != null and menu.find_child("SpecialLocked", true, false) != null, "★300: the special section shows locked")
	check(menu.find_child("Special_cdmg_1", true, false) == null, "no + buttons while locked")
	Game.paragon().level = 420
	menu._rebuild()
	await get_tree().process_frame
	check(menu.find_child("SpecialLocked", true, false) == null, "★420: unlocked")
	var plus := menu.find_child("Special_pierce_10", true, false) as Button
	check(plus != null and not plus.disabled, "the +10 button of pierce")
	if plus:
		plus.pressed.emit()
		await get_tree().process_frame
		check(int(Game.paragon().special.pierce) == 10, "it spends 10 points on pierce")
	var max_btn := menu.find_child("Special_cdmg_max", true, false) as Button
	if max_btn:
		max_btn.pressed.emit()
		await get_tree().process_frame
	check(int(Game.paragon().special.cdmg) == 40 and Game.special_points() == 70, "สุด fills cdmg to its cap (%d left)" % Game.special_points())
	var found := false
	for label in menu.find_children("*", "Label", true, false):
		if (label as Label).text.contains("ค่าสถานะพิเศษ"):
			found = true
	check(found, "the section header ค่าสถานะพิเศษ")
	check(menu.find_child("SpecialReset", true, false) != null, "the reset button once points are spent")
	menu.queue_free()
	await menu.tree_exited
	get_tree().paused = false
