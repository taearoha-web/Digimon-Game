extends Node
## บททดสอบเทวาลัย, the ★500 job change (AscensionData, AscendSkillData, JobData adv 6):
## the Ascension's names and bonuses for all 11 classes, the 22 skills (power, cost, buff
## rules, icons, art), the gate (★500 and the trial, never the Job Master), the sage's
## dialog and the three steps through the real Main (hunt, tokens, the trial stage with its
## guardian's moves, phases and enrage), a failed try and a retry, the promotion with its
## banner and celebration, the AI players' deterministic Ascension (JobData.adv_for), the
## save check, repair and a save / load.
##   godot --headless --audio-driver Dummy --path . res://tests/integration/ascension_test.tscn

var checks := 0
var failures := 0
var main: Node


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	Game.set_process(false)
	ZoneData.ensure()
	_jobs()
	_skills()
	_ai()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.slot = 1
	Game.delete_save()
	_god(&"darklord", 499)
	Game.playing = true
	main.hud.visible = true
	await _go(&"town")
	_gate()
	await _quest()
	await _trial()
	await _saves()
	print("ASCENSION: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	Game.delete_save()
	get_tree().quit(1 if failures > 0 else 0)


# --- helpers ---------------------------------------------------------------------------

func _god(cls: StringName, stars: int) -> void:
	Game.new_profile(cls, "เทวาลัยQA")
	Game.profile.level = 100
	Game.profile.adv = JobData.GOD_ADV
	Game.profile.paragon = {"level": stars, "points": 0, "spent": stars, "exp": 0, "alloc": Game.party_star_alloc(mini(stars, 300))}
	# Every stat point spent like a world player (60% main stat, 40% vitality).
	var points := Game.STAT_POINTS_PER_LEVEL * 99
	var main_stat := String(JobData.resolve(cls, JobData.GOD_ADV).main)
	Game.profile.attrs = {"str": 0, "int": 0, "dex": 0, "vit": int(points * 0.4)}
	Game.profile.attrs[main_stat] = int(Game.profile.attrs.get(main_stat, 0)) + int(points * 0.6)
	Game.profile.points = 0
	Game.profile.inv = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		var piece := Star500Gear.item(String(cls), slot)
		if not piece.is_empty():
			Game.profile.equip[slot] = piece
	Game.profile.gold = 1000
	Game.fill_loadout()
	_heal()


func _heal() -> void:
	var stats := Game.stats_now()
	Game.profile.hp = stats.max_hp
	Game.profile.mp = stats.max_mp


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _go(zone_id: StringName) -> void:
	main._traveling = false
	await main.go(zone_id, true)
	await _wait(0.3)
	check(main.zone != null and main.zone.zone_id == zone_id and main.zone.is_built, "arrived at %s" % zone_id)


## Waits (up to 20 s) until Main has built [param zone_id].
func _arrive(zone_id: StringName) -> void:
	for i in 200:
		if main.zone != null and is_instance_valid(main.zone) and main.zone.zone_id == zone_id and main.zone.is_built and not main._traveling:
			break
		await _wait(0.1)
	await _wait(0.2)


func _flow() -> AscensionFlow:
	return main.get_node("AscensionFlow") as AscensionFlow


func _talk() -> String:
	if main.dialog.is_open:
		main.dialog.close()
	_flow().talk()
	return String(main.dialog._text.text)


func _press(label: String) -> bool:
	for b in main.dialog._buttons.get_children():
		if b is Button and (b as Button).text == label:
			(b as Button).pressed.emit()
			return true
	return false


func _has_button(label: String) -> bool:
	for b in main.dialog._buttons.get_children():
		if b is Button and (b as Button).text == label:
			return true
	return false


# --- JobData: adv 6 ----------------------------------------------------------------------

func _jobs() -> void:
	var names := {}
	check(JobData.ASCEND_ADV == 6 and JobData.ASCEND_STARS == 500 and JobData.MAX_ADV == 6, "adv 6 at ★500 is the last step")
	check(String(JobData.ascend_step(&"warrior").name) == "จักรพรรดิดาบสวรรค์", "warrior -> จักรพรรดิดาบสวรรค์")
	for cls in ClassData.IDS:
		var asc := JobData.ascend_step(cls)
		var god := JobData.god_step(cls)
		check(String(asc.name) != "" and not names.has(asc.name) and String(asc.title) != "", "%s has its own Ascension name (%s)" % [cls, asc.get("name", "")])
		names[asc.name] = true
		check(JobData.step(cls, JobData.ASCEND_ADV - 1) == asc and JobData.current(cls, 6) == asc, "%s: step 5 is the Ascension" % cls)
		for key in god.bonus:
			check(float(asc.bonus[key]) > float(god.bonus[key]), "%s Ascension %s %.3f above the God step %.3f" % [cls, key, float(asc.bonus[key]), float(god.bonus[key])])
		for key in god.attrs:
			check(int(asc.attrs[key]) > int(god.attrs[key]), "%s Ascension %s above the God step" % [cls, key])
		var data := JobData.resolve(cls, 6)
		check(String(data.name) == String(asc.name) and String(data.title) == String(asc.title) and int(data.adv) == 6, "%s resolve(6) names the Ascension" % cls)
		check(float(data.atk_mult) > float(JobData.resolve(cls, 5).atk_mult) and float(data.hp_mult) > float(JobData.resolve(cls, 5).hp_mult), "%s adv 6 hits and lasts harder than the God" % cls)
		check(JobData.tier_name(cls, JobData.ASCEND_TIER) == String(asc.name), "%s tier name" % cls)
		check(int(JobData.attr_bonus(cls, 6).values().reduce(func(a, b): return a + b)) > int(JobData.attr_bonus(cls, 5).values().reduce(func(a, b): return a + b)), "%s adv 6 attributes stack" % cls)
	check(names.size() == 11, "eleven Ascension names")
	check(ClassData.tier_of(&"mage", 6) == JobData.ASCEND_TIER and ClassData.tier_of(&"mage", 5) == 5, "adv 6 opens its own tier, the God keeps 5")
	print("Ascension names: ", ", ".join(ClassData.IDS.map(func(c): return "%s=%s" % [c, JobData.ascend_step(c).name])))


# --- The 22 skills -----------------------------------------------------------------------

func _skills() -> void:
	var seen := {}
	for cls in ClassData.IDS:
		var mine := AscendSkillData.pool(cls)
		check(mine.size() == 2, "%s has two Ascension skills" % cls)
		var god: Dictionary = StarSkillData.pool(cls)[4]
		var god_in_pool: Dictionary = ClassData.find_skill(cls, String(god.id))
		var ult: Dictionary = ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][0]))
		var buff: Dictionary = ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][1]))
		check(not ult.is_empty() and not buff.is_empty(), "%s: both are in the class pool" % cls)
		if ult.is_empty() or buff.is_empty():
			continue
		for s in [ult, buff]:
			check(not seen.has(s.id), "unique id " + String(s.id))
			seen[s.id] = true
			check(int(s.star) == 500 and bool(s.ascend) and ClassData.skill_tier(s) == JobData.ASCEND_TIER, "%s: ★500 and the Ascension tier" % s.id)
			check(ResourceLoader.exists("res://assets/icons/skills/%s.svg" % s.id) and SkillIcons.for_skill(s) != null, "icon " + String(s.id))
			check(StarSkillArt.handles(s), "star art handles " + String(s.id))
			check(SkillRank.table(s).size() >= 2, "Skill Master table " + String(s.id))
			check(String(s.name).length() > 0 and String(s.desc).contains("สกิลเทวาลัย"), "Thai name and description " + String(s.id))
		# The ultimate: above the god skill in power, cost and cooldown, god-tier art.
		check(StarSkillData.is_god(ult) and String(ult.shape) in ["blast", "burst"] and float(ult.radius) >= 10.0, "%s ultimate: a wide god-tier area" % cls)
		check(float(ult.mult) > float(god_in_pool.mult) * 1.4, "%s ultimate %.1f above its god skill %.1f" % [cls, float(ult.mult), float(god_in_pool.mult)])
		for skill in ClassData.pool(cls):
			if skill.id != ult.id:
				check(float(ult.mult) > float(skill.mult), "%s ultimate stronger than %s" % [cls, skill.id])
		check(int(ult.mp) > int(god.mp) and float(ult.cd) > float(god.cd), "%s ultimate costs more and waits longer" % cls)
		check(GodSkillArt.handles(ult) and GodSkillArt.signature(String(ult.id)) != null and GodSkillArt.owns(ult), "%s ultimate has its god art" % cls)
		check(not ult.get("fx", {}).has("buff") and not BuffBook.is_song_skill(ult), "%s ultimate is an attack" % cls)
		# The buff: a star buff (never god-tier), the party rule, its own art.
		check(not StarSkillData.is_god(buff) and String(buff.shape) == "self" and buff.fx.has("buff"), "%s buff is a star buff" % cls)
		check(StarSignature.owns(buff), "%s buff has its signature art" % cls)
		check(bool(buff.fx.buff.get("team", false)) == (cls in [&"priest", &"bard"]), "%s buff reaches the party only for priest / bard" % cls)
		check(float(buff.fx.buff.secs) == 60.0 and not BuffBook.is_song_skill(buff), "%s buff lasts a minute, not a song" % cls)
		print("  %s: %s (%s) x%.1f mp %d cd %.0f | %s (%s) %s" % [cls, ult.name, ult.id, float(ult.mult), int(ult.mp), float(ult.cd), buff.name, buff.id, JSON.stringify(buff.fx.buff)])
	check(seen.size() == 22, "22 Ascension skills (%d)" % seen.size())
	check(BuffBook.own_limit(&"defender") == 3, "the Defender keeps three own buffs")


# --- AI world players --------------------------------------------------------------------

func _ai() -> void:
	check(JobData.adv_for(100, 500) == 6 and JobData.adv_for(100, 499) == 5 and JobData.adv_for(99, 500) == JobData.LEGEND_ADV, "adv_for: ★500 Ascended, ★499 a God")
	var ranks := WorldPlayers.skill_ranks(&"lancer", 100, 500)
	var lower := WorldPlayers.skill_ranks(&"lancer", 100, 499)
	for id in AscendSkillData.IDS[&"lancer"]:
		check(ranks.has(id) and not lower.has(id), "a ★500 AI knows %s, a ★499 one does not" % id)
	check(WorldPlayers.skill_points(100, 500) == WorldPlayers.skill_points(100, 499) + JobData.ASCEND_SKILL_POINTS, "the Ascension's skill points")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 500}) == String(JobData.ascend_step(&"bard").name), "a ★500 AI's plate names its Ascension")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 300}) == JobData.god_name(&"bard"), "a ★300 AI is still a God")
	var ult: Dictionary = ClassData.find_skill(&"assassin", "timeless_night_execution")
	check(ClassData.knows(ult, 100, 1 + JobData.adv_for(100, 500), 500) and not ClassData.knows(ult, 100, 1 + JobData.adv_for(100, 499), 499), "a rival / guild fighter casts it at ★500 only")
	check(ClassData.knows(ult, 100, ClassData.tier_of(&"assassin", JobData.adv_for(100, 500)), 500), "the same through tier_of")


# --- The gate ----------------------------------------------------------------------------

func _gate() -> void:
	var ult: Dictionary = ClassData.find_skill(&"darklord", "heaven_hell_sovereign")
	check(not Game.skill_unlocked(ult) and Game.skill_lock_reason(ult).contains("500"), "★499: locked, the reason names ★500 (%s)" % Game.skill_lock_reason(ult))
	Game.paragon().level = 500
	check(not Game.skill_unlocked(ult) and Game.skill_lock_reason(ult).contains(AscensionData.TITLE), "★500 God: still locked until the trial (%s)" % Game.skill_lock_reason(ult))
	check(not ClassData.default_loadout(&"darklord", 100, [], Game.class_tier(), 500).has(String(ult.id)), "it stays off a God's bar")
	check(Game.next_step().is_empty() and not Game.advance(), "the Job Master sells nothing past the God step")
	main._on_npc("job")
	check(String(main.dialog._text.text).contains(AscensionData.TITLE), "the Job Master points to the trial")
	main.dialog.close()
	Game.paragon().level = 499
	var said := _talk()
	check(not _has_button("รับบททดสอบ") and said.contains("500"), "the sage refuses ★499")
	check(not AscensionData.start() and AscensionData.step() == 0, "and start() refuses too")
	Game.paragon().level = 500
	check(main.zone.npcs.any(func(n): return n.role == AscensionData.ROLE), "the sage stands in the village")


# --- The quest ---------------------------------------------------------------------------

func _quest() -> void:
	var said := _talk()
	check(_has_button("รับบททดสอบ") and said.contains(AscensionData.TITLE), "★500: the sage offers the trial")
	check(AscensionData.marker(), "the sage's marker shows")
	_press("รับบททดสอบ")
	check(AscensionData.step() == AscensionData.HUNT, "step 1: the hunt")
	check(AscensionData.tracker_line().contains("1/3"), "the tracker shows step 1 (%s)" % AscensionData.tracker_line())
	var elites: Array = (AscensionData.heaven().elites as Dictionary).keys()
	print("  hunt: elite hunt %s, elites %s, zones %s" % [AscensionData.elite_hunt(), elites, AscensionData.hunt_zones()])
	# A monster that does not count, then the hunt.
	Game.report_kill(&"pink_slime", false)
	check(AscensionData.kills() == 0, "a meadow slime does not count")
	var old_zone := Game.current_zone
	Game.current_zone = AscensionData.hunt_zones()[0]
	var elite: StringName = elites[0] if not elites.is_empty() else &"fallen_angel"
	if AscensionData.elite_hunt():
		Game.report_kill(&"heaven_lantern", false)
		check(AscensionData.kills() == 0, "an ordinary heaven monster is no elite")
		Game.report_kill(StringName(AscensionData.heaven().boss), true)
		check(AscensionData.kills() == AscensionData.BOSS_WORTH, "the realm's boss counts %d" % AscensionData.BOSS_WORTH)
	while AscensionData.step() == AscensionData.HUNT:
		Game.report_kill(elite, false)
	check(AscensionData.kills() == AscensionData.HUNT_COUNT and AscensionData.step() == AscensionData.TOKENS, "step 2 after %d" % AscensionData.HUNT_COUNT)
	check(_talk().contains("2/3"), "the sage tells step 2")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var kills := 0
	while AscensionData.step() == AscensionData.TOKENS and kills < 500:
		AscensionData.on_kill(elite, false, rng)
		kills += 1
	check(AscensionData.tokens() == AscensionData.TOKEN_COUNT and AscensionData.step() == AscensionData.TRIAL, "step 3 after %d tokens (%d kills)" % [AscensionData.TOKEN_COUNT, kills])
	Game.current_zone = old_zone
	check(AscensionData.trial_problem() == "", "the trial stage is open")
	check(_talk().contains(AscensionData.BOSS_NAME) and _has_button("เข้าลานบททดสอบ"), "the sage sends the hero to the stage")


# --- The trial ---------------------------------------------------------------------------

func _trial() -> void:
	# A first try that fails: the stage is left (the hero fell) without a win.
	_press("เข้าลานบททดสอบ")
	await _arrive(AscensionData.STAGE_ID)
	check(main.zone != null and main.zone.zone_id == AscensionData.STAGE_ID, "into the trial stage")
	var stage := main.zone.get_node_or_null("AscendTrial") as AscendTrial
	check(stage != null and stage.state == "intro" and AscensionData.tries() == 1, "the trial runs (try 1)")
	check(main.zone.has_node("AscendAltar"), "the altar of light is built")
	await _go(&"town")
	check(AscensionData.step() == AscensionData.TRIAL and not Game.is_ascended(), "a lost try keeps step 3: retry any time")
	_talk()
	_press("เข้าลานบททดสอบ")
	await _arrive(AscensionData.STAGE_ID)
	stage = main.zone.get_node_or_null("AscendTrial") as AscendTrial
	check(stage != null and AscensionData.tries() == 2, "try 2")
	var hero: Hero = main.zone.hero
	stage.step(AscendTrial.INTRO + 0.1)
	var boss := stage.boss
	check(boss != null and is_instance_valid(boss) and boss.monster_id == AscensionData.BOSS_ID and boss.is_boss, "the guardian descends")
	var moves := StoryBoss.of(boss)
	check(moves != null and moves.moves.size() == 2 and BossAttack.has_moves(boss.template), "two story moves and the field bosses' light moves")
	# Balance: tougher than the heaven realm's boss, survivable for a ★500 set, deadly enraged.
	var stats := Game.stats_now()
	var hit := HeroStats.mitigate(float(boss.stats.atk), float(stats.def))
	var heaven_hp := 0
	var heaven_hit := 0.0
	if ResourceLoader.exists(AscensionData.HEAVEN_BESTIARY):
		var heaven_boss := MonsterData.stats_for(StringName(AscensionData.heaven().boss), 285)
		heaven_hp = int(heaven_boss.get("hp", 0))
		heaven_hit = HeroStats.mitigate(float(heaven_boss.get("atk", 0)), float(stats.def))
		print("  heaven boss: hp %d, hit %d = %.1f%% of hero hp" % [heaven_hp, int(heaven_hit), 100.0 * heaven_hit / float(stats.max_hp)])
	var god: Dictionary = ClassData.find_skill(&"darklord", "abyssal_throne")
	var god_hit := float(stats.atk) * float(god.mult)
	print("  balance: guardian hp %d (heaven boss %d), atk %d -> hit %d = %.1f%% of hero hp %d; hero atk %d def %d; god skill ~%d per cast -> %.1f casts" % [
		boss.max_hp, heaven_hp, int(boss.stats.atk), int(hit), 100.0 * hit / float(stats.max_hp), int(stats.max_hp), int(stats.atk), int(stats.def), int(god_hit), float(boss.max_hp) / maxf(1.0, god_hit)])
	check(heaven_hp <= 0 or boss.max_hp > heaven_hp, "the guardian outlasts the heaven realm's boss")
	check(hit < float(stats.max_hp) * 0.25, "a ★500 hero survives several blows (%.1f%%)" % (100.0 * hit / float(stats.max_hp)))
	check(float(boss.max_hp) / maxf(1.0, god_hit) > 12.0, "it takes effort: many god casts")
	# The phases.
	boss.take_hit(int(boss.max_hp * 0.35), false, Color.WHITE, hero)
	check(stage.phase == 1 and moves.moves.size() == 4 and moves.moves.has("veil"), "70%%: phase two widens the moves")
	moves.force_special("rain")
	check(not moves.telegraph.is_empty(), "the star rain telegraphs")
	moves.tick(StoryBoss.TELEGRAPH + 0.1)
	boss.take_hit(int(boss.max_hp * 0.3), false, Color.WHITE, hero)
	check(stage.phase == 2 and moves.moves.size() == 5, "40%%: phase three")
	# The enrage timer.
	var atk := float(boss.stats.atk)
	stage.step(AscensionData.ENRAGE_SECONDS + 1.0)
	check(stage.enraged and float(boss.stats.atk) > atk * 2.0 and moves.haste <= AscendTrial.ENRAGE_HASTE + 0.001, "enraged after %d s" % int(AscensionData.ENRAGE_SECONDS))
	check(HeroStats.mitigate(float(boss.stats.atk), float(stats.def)) > hit * 2.0, "enraged blows hit far harder")
	# The win and the promotion.
	var points := int(Game.profile.skill_points)
	var before := Game.stats_now()
	boss.take_hit(boss.hp, false, Color.WHITE, hero)
	await get_tree().process_frame
	check(stage.state == "ending" and bool(stage.result.get("promoted", false)), "the guardian falls: promoted")
	check(Game.adv() == 6 and Game.is_ascended() and Game.is_god() and AscensionData.step() == AscensionData.DONE, "adv 6")
	check(int(Game.profile.skill_points) == points + JobData.ASCEND_SKILL_POINTS, "+%d skill points" % JobData.ASCEND_SKILL_POINTS)
	var after := Game.stats_now()
	check(float(after.atk) > float(before.atk) and int(after.max_hp) > int(before.max_hp), "the Ascension lifts attack and HP (%d -> %d)" % [int(before.atk), int(after.atk)])
	check(String(Game.class_data().name) == String(JobData.ascend_step(&"darklord").name), "the class reads %s" % Game.class_data().name)
	for id in AscendSkillData.IDS[&"darklord"]:
		var skill := ClassData.find_skill(&"darklord", id)
		check(Game.skill_unlocked(skill) and Game.skill_lock_reason(skill) == "", "%s unlocked" % id)
		check((Game.profile.loadout as Array).has(id), "%s on the bar" % id)
	var banner: Node = main.zone.get_node_or_null("AscendBanner")
	check(banner != null and banner is CanvasLayer, "the promotion banner shows")
	if banner:
		var texts: Array = banner.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		check(texts.any(func(t): return String(t).contains("ขั้นที่ 6")) and texts.any(func(t): return String(t) == String(Game.class_data().name)), "the banner names the step and the new job")
	check(main.zone.has_node("AscendHeaven") or main.zone.has_node("AscendCrown"), "the pillar of heaven rises")
	stage.step(AscendTrial.END_DELAY + 0.1)
	check(stage.state == "done", "the stage ends")
	await _arrive(&"town")
	check(Game.current_zone == &"town", "back in the village")
	check(_talk().contains(String(Game.class_data().name)), "the sage greets the Ascended")
	main.dialog.close()
	main._on_npc("job")
	check(String(main.dialog._text.text).contains(AscensionData.TITLE), "so does the Job Master")
	main.dialog.close()
	# Casting the new ultimate and buff for real.
	hero = main.zone.hero
	_heal()
	var ult := ClassData.find_skill(&"darklord", "heaven_hell_sovereign")
	var buff := ClassData.find_skill(&"darklord", "crown_of_dual_realms")
	hero._cast_now(buff)
	await _wait(1.3)
	hero._cast_until = 0
	check(BuffBook.contains(hero._buffs, "crown_of_dual_realms", false), "the buff is on the hero")
	hero._cast_now(ult)
	check(hero.has_node("StarCast_heaven_hell_sovereign"), "the ultimate plays as a star sequence")
	await _wait(4.4)
	check(not hero.has_node("StarCast_heaven_hell_sovereign"), "and ends")
	# The character screen.
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await get_tree().process_frame
	var line := menu.find_child("ClassTitle", true, false) as Label
	check(line != null and line.text.contains(String(Game.class_data().title)), "the character screen shows the Ascension title")
	menu.queue_free()
	await menu.tree_exited
	get_tree().paused = false


# --- Saves -------------------------------------------------------------------------------

func _saves() -> void:
	check(Game._valid_profile(Game.profile), "the Ascended hero passes the save check")
	check(Game.save_code_roundtrip(), "adv 6 survives the save code")
	check(Game.save(), "saves")
	Game.profile.adv = 0
	check(Game.load_game(1) and Game.adv() == 6 and Game.is_ascended(), "adv 6 comes back from the save file")
	var bundle := Game.build_cloud_bundle()
	var cloud: Variant = bundle.slots.get("1")
	check(cloud is Dictionary and int(cloud.get("adv", 0)) == 6, "the cloud bundle carries adv 6")
	var forged: Dictionary = Game.profile.duplicate(true)
	forged.paragon.level = 499
	check(not Game._valid_profile(forged), "adv 6 below ★500 is refused")
	check(int(Game._repair(forged).adv) == JobData.GOD_ADV, "and repairs to the God step")
	forged = Game.profile.duplicate(true)
	forged.adv = 7
	check(not Game._valid_profile(forged), "adv 7 does not exist")
