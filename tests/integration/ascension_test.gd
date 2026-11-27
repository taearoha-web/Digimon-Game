extends Node
## บททดสอบเทวาลัย, the ★500 job change (AscensionData, AscendSkillData, JobData adv 6):
## the Ascension's names and bonuses for all 11 classes, the 22 skills (power, cost, buff
## rules, icons, art), the gate (★500 and the trial, never the Job Master), the sage's
## dialog and the three steps through the real Main (hunt, tokens, the trial stage with its
## guardian's moves, phases and enrage), a failed try and a retry, the promotion with its
## banner and celebration, the AI players' own trial (WorldPlayers.ascended_at: no Ascension
## by ★500 alone; their tries against the guardian, deterministic; the announcement), the
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
	# ★500 alone is no Ascension: adv_for's Ascension step needs the trial won (ascended).
	check(JobData.adv_for(100, 500) == JobData.GOD_ADV and JobData.adv_for(100, 500, true) == JobData.ASCEND_ADV, "adv_for: ★500 stays a God until it has passed the trial")
	check(JobData.adv_for(100, 499, true) == JobData.GOD_ADV and JobData.adv_for(99, 500, true) == JobData.LEGEND_ADV, "adv_for: never Ascended below Lv.100 ★500")
	var ranks := WorldPlayers.skill_ranks(&"lancer", 100, 500, true)
	var not_yet := WorldPlayers.skill_ranks(&"lancer", 100, 500)
	var lower := WorldPlayers.skill_ranks(&"lancer", 100, 499, true)
	for id in AscendSkillData.IDS[&"lancer"]:
		check(ranks.has(id) and not not_yet.has(id) and not lower.has(id), "%s: only a ★500 AI that passed the trial knows it" % id)
	check(WorldPlayers.skill_points(100, 500, true) == WorldPlayers.skill_points(100, 500) + JobData.ASCEND_SKILL_POINTS, "the Ascension's skill points")
	check(WorldPlayers.skill_points(100, 500) == WorldPlayers.skill_points(100, 499), "no Ascension points for ★500 alone")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 500, "ascended": true}) == String(JobData.ascend_step(&"bard").name), "a ★500 plate that passed names its Ascension")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 500}) == JobData.god_name(&"bard"), "a ★500 plate of nobody's is still a God")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 500, "adv": JobData.GOD_ADV}) == JobData.god_name(&"bard"), "a real player's ★500 God plate (adv 5) is a God")
	check(WorldPlayers.god_title({"class": &"bard", "level": 100, "stars": 300}) == JobData.god_name(&"bard"), "a ★300 AI is still a God")
	var ult: Dictionary = ClassData.find_skill(&"assassin", "timeless_night_execution")
	check(ClassData.knows(ult, 100, 1 + JobData.adv_for(100, 500, true), 500) and not ClassData.knows(ult, 100, 1 + JobData.adv_for(100, 500), 500), "a rival / guild fighter casts it only after the trial")
	check(ClassData.knows(ult, 100, ClassData.tier_of(&"assassin", JobData.adv_for(100, 500, true)), 500) and not ClassData.knows(ult, 100, ClassData.tier_of(&"assassin", JobData.adv_for(100, 500)), 500), "the same through tier_of")
	_ai_trial()


## The world players' own trial (WorldPlayers.ascended_at): read off their work, the same
## on every device; a ★500 player is no Ascended before its win, the weak fail, the strong
## pass, some pass within days and not everyone, and the answers never change.
func _ai_trial() -> void:
	var was_festival := WorldEvents.festival_enabled
	WorldEvents.festival_enabled = false
	WorldPlayers.clear_bonus()
	var n := mini(WorldPlayers.ROSTER.size(), WorldPlayers.size())
	var w500 := WorldPlayers.star500_work()
	check(WorldPlayers.TRIAL_PREP_WORK > 0.0 and WorldPlayers.trial_work(0, 0) > w500, "the first try comes after the hunt and the tokens (%.0f probe minutes past ★500)" % WorldPlayers.TRIAL_PREP_WORK)
	var hours := (WorldPlayers.trial_work(0, 1) - WorldPlayers.trial_work(0, 0)) / 60.0 / WorldPlayers.efficiency(0)
	check(is_equal_approx(hours, WorldPlayers.TRIAL_EVERY_HOURS), "a try every %.1f hours of its play" % hours)
	# The guardian is the trial's own (AscensionData's MONSTERS through MonsterData).
	var g := WorldPlayers.guardian()
	var mob := MonsterData.stats_for(AscensionData.BOSS_ID, AscendTrial.BOSS_LEVEL)
	check(int(g.hp) == int(mob.hp) and int(g.atk) == int(mob.atk), "the AI fights the stage's guardian (hp %d atk %d)" % [int(g.hp), int(g.atk)])
	# Weak and strong: the same sheet scaled down and up.
	var i0 := 0
	var sheet := WorldPlayers.trial_sheet(i0, WorldPlayers.trial_work(i0, 0))
	check(int(sheet.adv) == JobData.GOD_ADV and int(sheet.level) == 100 and int(sheet.paragon.level) == JobData.ASCEND_STARS, "a try is fought as the ★500 God it is")
	var st := HeroStats.compute(sheet)
	var weak := st.duplicate()
	weak.atk = float(st.atk) * 0.2
	weak.max_hp = int(float(st.max_hp) * 0.5)
	var strong := st.duplicate()
	strong.atk = float(st.atk) * 6.0
	strong.max_hp = int(float(st.max_hp) * 3.0)
	strong.lifesteal = 0.1
	var mid := WorldPlayers.trial_odds(sheet, st, 1.0)
	var low := WorldPlayers.trial_odds(sheet, weak, 1.0)
	var high := WorldPlayers.trial_odds(sheet, strong, 1.0)
	check(float(low.kill) > float(mid.kill) and float(high.kill) < float(mid.kill) and float(high.last) > float(low.last), "more attack kills faster, more HP lasts longer")
	check(WorldPlayers.trial_chance(float(low.margin)) == 0.0, "a weak sheet has no chance (margin %.2f)" % float(low.margin))
	# The same guardian as the hero's (one standard): a sheet that lasts as long as it needs
	# has an even chance; more than that, better.
	check(WorldPlayers.trial_chance(float(high.margin)) > WorldPlayers.trial_chance(float(mid.margin)) and is_equal_approx(WorldPlayers.trial_chance(1.0), 0.5), "a strong sheet stands far better (margin %.2f), an even fight is an even chance" % float(high.margin))
	check(WorldPlayers.trial_odds(sheet, st, 1.2).margin > WorldPlayers.trial_odds(sheet, st, 0.8).margin, "better hands, better odds")
	print("  AI trial: %s kill %.0fs last %.0fs margin %.2f chance %.2f" % [WorldPlayers.entry(i0).name, float(mid.kill), float(mid.last), float(mid.margin), WorldPlayers.trial_chance(float(mid.margin))])
	# Every roster player: not Ascended at ★500 before its first try; the answers stable.
	var passes := {}
	var never_early := true
	var first_try := []
	for i in n:
		never_early = never_early and not WorldPlayers.ascended_at_work(i, w500) and not WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 0) - 1.0)
		first_try.append(WorldPlayers.trial_chance(float(WorldPlayers.trial_odds(WorldPlayers.trial_sheet(i, WorldPlayers.trial_work(i, 0)), HeroStats.compute(WorldPlayers.trial_sheet(i, WorldPlayers.trial_work(i, 0))), WorldPlayers.trial_hands(i)).margin)))
		for k in [0, 5, 15, 30, 60, 150]:
			if not passes.has(k):
				passes[k] = 0
			passes[k] += 1 if WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, k)) else 0
	check(never_early, "no world player is Ascended at ★500 before its first try")
	# Deterministic: the same answers read in another order with the caches emptied.
	var late := []
	for i in n:
		late.append(WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 40)))
	WorldPlayers._trial.clear()
	var same := true
	for i in range(n - 1, -1, -1):
		var a := WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 40))
		var b := WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 3))
		same = same and a == bool(late[i]) and (not b or a)
		same = same and WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 40)) == a
	check(same, "the same pass or fail whatever was read first, and a pass is never taken back")
	print("  AI trial passes of %d roster players by try %s: %s" % [n, str(passes.keys()), str(passes.values())])
	check(int(passes[0]) < n / 2, "most do not pass at the first try (%d / %d)" % [int(passes[0]), n])
	check(int(passes[150]) > 0 and int(passes[150]) < n, "some pass as their gear grows, not everyone (%d / %d by try 150)" % [int(passes[150]), n])
	check(int(passes[150]) < n, "some never pass (%d / %d after a month of tries)" % [int(passes[150]), n])
	check(int(passes[150]) >= int(passes[15]) and int(passes[15]) >= int(passes[0]), "passes only add up")
	# The strongest first try wins within a few; a no-chance first try fails it.
	var best := 0
	var none := -1
	for i in n:
		best = i if float(first_try[i]) > float(first_try[best]) else best
		if none < 0 and float(first_try[i]) == 0.0:
			none = i
	check(float(first_try[best]) > 0.0 and WorldPlayers.ascended_at_work(best, WorldPlayers.trial_work(best, 150)), "the strongest (%s, %.0f%% a try) passes in the end" % [WorldPlayers.entry(best).name, 100.0 * float(first_try[best])])
	check(none >= 0 and not WorldPlayers.ascended_at_work(none, WorldPlayers.trial_work(none, 0)), "a weak one fails its first try")
	# One who passes: a God at ★500 until the try it wins, Ascended from it.
	var who := -1
	for i in n:
		if WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 30)) and not WorldPlayers.ascended_at_work(i, WorldPlayers.trial_work(i, 0)):
			who = i
			break
	check(who >= 0, "someone passes after failing first")
	if who >= 0:
		var win := WorldPlayers._trial_pass(who, INF)
		var e := WorldPlayers.entry(who)
		var cls := StringName(e["class"])
		var before := _sheet_at(who, win - 1.0)
		var after := _sheet_at(who, win + 1.0)
		var sb := WorldPlayers.profile(before)
		var sa := WorldPlayers.profile(after)
		check(int(before.stars) == JobData.ASCEND_STARS and int(sb.adv) == JobData.GOD_ADV and not WorldPlayers.ascended_sheet(before), "%s at ★500 before its win: a God (adv %d)" % [e.name, int(sb.adv)])
		check(int(sa.adv) == JobData.ASCEND_ADV and WorldPlayers.ascended_sheet(after), "%s after its win: Ascended" % e.name)
		for id in AscendSkillData.IDS[cls]:
			check(not (sb.skills as Dictionary).has(id) and (sa.skills as Dictionary).has(id), "%s: %s only after the win" % [e.name, id])
		check(WorldPlayers.god_title(before) == JobData.god_name(cls) and WorldPlayers.god_title(after) == String(JobData.ascend_step(cls).name), "%s: its plate turns from God to %s" % [e.name, WorldPlayers.god_title(after)])
		check(PlayerLook.of_member(before, who).adv == JobData.GOD_ADV and PlayerLook.of_member(after, who).adv == JobData.ASCEND_ADV, "its look follows")
		check(WorldPlayers.trial_tries(who, win) >= 2 and WorldPlayers.trial_tries(who, win) == WorldPlayers.trial_tries(who, win + 1000.0), "its tries stop at the win (%d)" % WorldPlayers.trial_tries(who, win))
		# In real time: the world chat's announcement (Announcer, WorldPlayers.take_ascended).
		var t_win := _time_of_work(who, win)
		check(not WorldPlayers.ascended_at(who, t_win - 120.0) and WorldPlayers.ascended_at(who, t_win + 120.0), "ascended_at follows its play in real time")
		Announcer.reset()
		var heard: Array = []
		var sink := func(text: String, kind: String): heard.append([text, kind])
		Announcer.listen(sink)
		for _k in int(ceil(float(WorldPlayers.size()) / float(WorldPlayers.WATCH_SLICE))) + 1:
			WorldPlayers.take_ascended(t_win - 120.0)
		var told: Array[int] = []
		for _k in int(ceil(float(WorldPlayers.size()) / float(WorldPlayers.WATCH_SLICE))) + 1:
			told.append_array(WorldPlayers.take_ascended(t_win + 120.0))
		check(told.has(who), "the watch finds %s's pass" % e.name)
		Announcer.reset()
		Announcer.ticking = true
		for _k in int(ceil(float(WorldPlayers.size()) / float(WorldPlayers.WATCH_SLICE))) + 1:
			Announcer._ascend_t = -INF
			Announcer.tick(t_win - 120.0)
		for _k in int(ceil(float(WorldPlayers.size()) / float(WorldPlayers.WATCH_SLICE))) + 1:
			Announcer._ascend_t = -INF
			Announcer.tick(t_win + 120.0)
		var line := Announcer.ASCENDED % [String(e.name), AscensionData.TITLE]
		check(heard.any(func(h): return String(h[0]) == Announcer.clean(line) and String(h[1]) == "ascend"), "the world chat announces: %s" % line)
		Announcer.unlisten(sink)
		Announcer.reset()
	WorldEvents.festival_enabled = was_festival


## World player i's member sheet at work w (what its play shows then).
func _sheet_at(i: int, w: float) -> Dictionary:
	var p := WorldPlayers.progress_for(0.0, WorldPlayers.efficiency(i), w)
	var e := WorldPlayers.entry(i)
	return {"class": String(e["class"]), "name": String(e.name), "level": int(p.level), "stars": int(p.stars),
		"frac": float(p.frac), "divine_frac": float(p.divine_frac), "after": float(p.after)}


## The real time world player i's work reaches w (work_at only grows).
func _time_of_work(i: int, w: float) -> float:
	var lo := WorldPlayers.joined_at(i)
	var hi := lo + 400.0 * 86400.0
	for _k in 60:
		var mid := (lo + hi) * 0.5
		if WorldPlayers.work_at(i, mid) >= w:
			hi = mid
		else:
			lo = mid
	return hi


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
	# However well geared (the owner's +15 hero took ~1% a blow), a blow takes at least
	# FLOOR_SHARE of max HP before guard and shields.
	check(boss.has_meta(AscensionData.FLOOR_META), "the guardian carries its base attack for the floor")
	var saved_def: Variant = hero.stats.def
	hero.stats.def = 10000000.0
	hero._invulnerable_until = 0
	Game.profile.hp = int(hero.stats.max_hp)
	var hp0 := int(Game.profile.hp)
	hero.stats.dodge = 0.0
	Mob.strike(hero, float(boss.stats.atk), boss)
	var floor_hit := hp0 - int(Game.profile.hp)
	check(floor_hit >= int(float(hero.stats.max_hp) * AscensionData.FLOOR_SHARE * 0.5), "a huge DEF still takes a real share a blow (%d of %d HP, before guard: %.0f%%)" % [floor_hit, int(hero.stats.max_hp), AscensionData.FLOOR_SHARE * 100.0])
	# A story move's blow (StoryBoss, raw many times the guardian's attack) is never
	# lifted past FLOOR_MAX_SCALE x the floor (it once took 300k+ off a 155k hero).
	Game.profile.hp = int(hero.stats.max_hp)
	hero._invulnerable_until = 0
	hp0 = int(Game.profile.hp)
	Mob.strike(hero, float(boss.stats.atk) * 12.0, boss)
	var story_hit := hp0 - int(Game.profile.hp)
	check(story_hit <= int(ceil(float(hero.stats.max_hp) * AscensionData.FLOOR_SHARE * AscensionData.FLOOR_MAX_SCALE)) + 1, "a huge raw blow is held to the floor's cap (%d of %d HP)" % [story_hit, int(hero.stats.max_hp)])
	hero.stats.def = saved_def
	Game.profile.hp = int(hero.stats.max_hp)
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
