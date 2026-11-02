extends Node
## The star cap at ★300 and the God promotion ("เทพเจ้าแห่ง<อาชีพ>"):
## - Game.PARAGON_MAX is 300; the EXP curve is unchanged up to ★200 and grows
##   faster from ★200 to ★300; a hero climbs to exactly ★300 with 300 points and
##   every point has a stat to go into.
## - The God step (JobData.GOD_ADV, adv 5) needs Lv.100, ★300 (JobData.GOD_STARS)
##   and its fee; it is named after the class, adds bigger bonuses than the Lv.80
##   legend step, shows in the character screen and as the name-plate title.
## - It survives the save file and the save code, and a save that claims it
##   without ★300 is refused or falls back to the legend step.

var checks := 0
var failures := 0


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func legend(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "Star300 QA")
	Game.profile.level = Game.MAX_LEVEL
	Game.profile.exp = 0
	Game.profile.adv = JobData.LEGEND_ADV
	Game.profile.paragon = {"level": stars, "exp": 0, "points": stars, "spent": 0, "alloc": {}}
	Game.fill_loadout()
	# Pay the rewards of the achievements this profile already meets first.
	Game.check_achievements()
	Game.profile.gold = 0


func _ready() -> void:
	Game.set_process(false)
	_cap()
	_curve()
	_climb()
	await _god()
	_saves()
	Game.has_profile = false
	print("STAR300: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _cap() -> void:
	check(Game.PARAGON_MAX == 300, "the star cap is 300 (%d)" % Game.PARAGON_MAX)
	check(JobData.GOD_STARS == 300 and JobData.GOD_ADV == 5 and JobData.MAX_ADV == 5 and JobData.LEGEND_ADV == 4, "the God step is adv 5 at ★300")
	var room := 0
	for key in Game.PARAGON_STATS:
		room += int(Game.PARAGON_STATS[key][2])
	check(room >= Game.PARAGON_MAX, "the star stats hold every point up to ★300 (%d)" % room)
	for key in ["atk", "def", "hp"]:
		check(int(Game.PARAGON_STATS[key][2]) == 60, "%s keeps its cap of 60" % key)


func _curve() -> void:
	var base := float(HeroStats.exp_to_next(100)) * HeroStats.STAR_EXP
	for star in 200:
		if HeroStats.star_need(star) != int(base * (1.0 + 0.02 * float(star))):
			check(false, "the curve below ★200 is unchanged (★%d)" % star)
			break
	var last := 0
	var rising := true
	for star in Game.PARAGON_MAX:
		var need := HeroStats.star_need(star)
		rising = rising and need > last
		last = need
	check(rising, "every star costs more than the one before up to ★300")
	var step_low := HeroStats.star_need(150) - HeroStats.star_need(149)
	var step_high := HeroStats.star_need(250) - HeroStats.star_need(249)
	check(step_high >= step_low * 2 - 2, "past ★200 each star grows twice as fast (%d vs %d)" % [step_high, step_low])
	var low := 0.0
	var high := 0.0
	for star in 200:
		low += HeroStats.star_need(star)
	for star in range(200, 300):
		high += HeroStats.star_need(star)
	check(high > low and high < low * 1.5, "★200 -> ★300 is a long but bounded climb (%.2fx the ★0 -> ★200 EXP)" % (high / low))
	var ratio := float(HeroStats.star_need(299)) / float(HeroStats.star_need(200))
	check(ratio > 1.6 and ratio < 2.0, "the last star costs about 1.8x the ★200 one (%.2f)" % ratio)


func _climb() -> void:
	legend(&"mage", 198)
	var gold0 := int(Game.profile.gold)
	var guard := 0
	while int(Game.paragon().level) < Game.PARAGON_MAX and guard < 400:
		Game.add_exp(maxi(1, Game.paragon_need() - int(Game.paragon().exp)))
		guard += 1
	var p := Game.paragon()
	check(int(p.level) == 300 and int(p.points) == 300, "EXP climbs past ★200 to ★300 with one point per star (★%d, %d points)" % [int(p.level), int(p.points)])
	check(Game.paragon_need() == 0 and int(p.exp) == 0, "no EXP is kept at the cap")
	Game.add_exp(99999999)
	check(int(Game.paragon().level) == 300, "no star past 300")
	check(Game.exp_ratio() >= 0.0 and Game.exp_ratio() <= 1.0, "the EXP bar stays valid at the cap")
	var milestone := 0
	for star in [200, 225, 250, 275, 300]:
		milestone += star * 2000 if star > 198 else 0
	check(int(Game.profile.gold) - gold0 >= milestone, "the 25-star gold milestones keep paying to ★300")
	check(Achievements.is_earned("t_star300", Game.profile), "the ★300 achievement is earned")
	for key in Game.PARAGON_STATS:
		Game.paragon_spend(key, 1000)
	check(int(Game.paragon().points) == 0 and int(Game.paragon().spent) == 300, "all 300 points can be spent (%d left)" % int(Game.paragon().points))
	check(Game._valid_profile(Game.profile) and Game.save_code_roundtrip(), "a ★300 hero with every point spent saves")
	Game.paragon().alloc.crit = 61
	check(not Game._valid_profile(Game.profile), "a stat above its cap is refused")
	Game.paragon().alloc.crit = 60
	Game.paragon().level = 301
	check(not Game._valid_profile(Game.profile), "★301 is refused")
	Game.paragon().level = 300


func _god() -> void:
	for cls in ClassData.IDS:
		var god := JobData.god_step(cls)
		var top: Dictionary = JobData.PATHS[cls][JobData.LEGEND_ADV - 1]
		check(String(god.name) == "เทพเจ้าแห่ง" + String(ClassData.get_class_data(cls).name), "%s God name: %s" % [cls, god.name])
		check(String(god.title) != "" and JobData.step(cls, JobData.GOD_ADV - 1) == god, "%s God step has a title and is step 5" % cls)
		for key in top.bonus:
			var a := float(top.bonus[key])
			var b := float(god.bonus[key])
			check(b > a, "%s God %s bonus beats the Lv.80 one (%.3f > %.3f)" % [cls, key, b, a])
		for key in top.attrs:
			check(int(god.attrs[key]) > int(top.attrs[key]), "%s God %s beats the Lv.80 one" % [cls, key])
		check(JobData.adv_for_level(100) == JobData.LEGEND_ADV, "companions stop at the legend step")
	check(JobData.god_name(&"darklord") == "เทพเจ้าแห่งดาร์กลอร์ด", "เทพเจ้าแห่งดาร์กลอร์ด")

	# The requirement: Lv.100, ★300 and the fee, in that order.
	legend(&"darklord", 299)
	check(not Game.is_god() and Game.next_step_stars() == 300, "the next step after the legend needs ★300")
	Game.profile.gold = 10000000
	var skill_points := int(Game.profile.skill_points)
	check(not Game.advance() and Game.adv() == 4, "★299 cannot take the God step")
	check(Game.advance_problem().contains("ดาว 300"), "the refusal names ★300 (%s)" % Game.advance_problem())
	Game.paragon().level = 300
	Game.profile.level = 99
	check(not Game.advance() and Game.advance_problem().contains("100"), "Lv.99 cannot take it (%s)" % Game.advance_problem())
	Game.profile.level = 100
	Game.profile.gold = Game.next_step_cost() - 1
	check(not Game.advance() and Game.advance_problem().contains("เหรียญ"), "the fee is needed (%s)" % Game.advance_problem())
	Game.profile.gold = Game.next_step_cost() + 5
	var before := Game.stats_now()
	check(Game.advance(), "Lv.100 ★300 with the fee takes the God step")
	var after := Game.stats_now()
	check(Game.is_god() and Game.adv() == 5 and int(Game.profile.gold) == 5, "the God step is taken and paid for")
	check(int(Game.profile.skill_points) == skill_points + 6, "the God step gives 6 skill points")
	check(String(Game.class_data().name) == "เทพเจ้าแห่งดาร์กลอร์ด", "the class label reads %s" % Game.class_data().name)
	check(float(after.atk) > float(before.atk) * 1.2 and int(after.max_hp) > int(before.max_hp) * 1.15 and float(after.def) > float(before.def) * 1.1, "the God step lifts attack, HP and defence (%d -> %d atk)" % [int(before.atk), int(after.atk)])
	check(float(after.crit) > float(before.crit), "and critical")
	var god := JobData.god_step(&"darklord")
	for key in god.attrs:
		check(int(after.attrs[key]) == int(before.attrs[key]) + int(god.attrs[key]), "%s +%d from the God step" % [key, int(god.attrs[key])])
	check(int(Game.profile.hp) == int(after.max_hp), "the promotion refills HP")
	check(not Game.advance() and Game.next_step().is_empty(), "nothing after the God step")
	check(Achievements.is_earned(Achievements.GOD_ID, Game.profile), "the God achievement is earned")
	check(Achievements.title_of(Game.profile) == "เทพเจ้าแห่งดาร์กลอร์ด", "the name plate title is the God name (%s)" % Achievements.title_of(Game.profile))
	# The character screen shows the God class and its title.
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await get_tree().process_frame
	var line := menu.find_child("ClassTitle", true, false) as Label
	check(line != null and line.text.contains(String(god.title)), "the character screen shows the God title")
	var header_found := false
	for label in menu.find_children("*", "Label", true, false):
		if (label as Label).text.contains("(เทพเจ้าแห่งดาร์กลอร์ด)"):
			header_found = true
	check(header_found, "the character screen header names เทพเจ้าแห่งดาร์กลอร์ด")
	menu.queue_free()
	await menu.tree_exited
	get_tree().paused = false


func _saves() -> void:
	# The God hero from _god(): saved, reloaded and sent by save code.
	check(Game._valid_profile(Game.profile), "the God hero passes the save check")
	check(Game.save_code_roundtrip(), "the God step survives the save code")
	Game.slot = 1
	check(Game.save(), "the God hero saves")
	Game.profile.adv = 0
	check(Game.load_game(1) and Game.adv() == 5 and Game.is_god(), "the God step comes back from the save file")
	check(String(Game.class_data().name) == "เทพเจ้าแห่งดาร์กลอร์ด", "and the class name with it")
	var bundle := Game.build_cloud_bundle()
	var cloud: Variant = bundle.slots.get("1")
	check(cloud is Dictionary and int(cloud.get("adv", 0)) == 5, "the cloud bundle carries adv 5")
	# A save that claims the God step without ★300.
	var forged: Dictionary = Game.profile.duplicate(true)
	forged.paragon.level = 299
	check(not Game._valid_profile(forged), "adv 5 below ★300 is refused")
	check(int(Game._repair(forged).adv) == JobData.LEGEND_ADV, "and repairs to the legend step")
	var young: Dictionary = Game.profile.duplicate(true)
	young.level = 99
	check(not Game._valid_profile(young), "adv 5 below Lv.100 is refused")
	forged.adv = 6
	check(not Game._valid_profile(forged), "adv 6 does not exist")
