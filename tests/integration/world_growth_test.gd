extends Node
## The world players grow their characters like keen players do, truly and the same on
## every device (WorldGear, WorldPlayers.skill_ranks; headless):
## - enhancing: the + of what they wear follows the forge's own odds
##   (ItemData.enhance_chance) on the jewels their kills dropped; +15 is for the long-time
##   top players, nobody early, never everyone;
## - skills: the stars they buy at the Skill Master are the points they earned
##   (WorldPlayers.skill_points), never more, and only ever go up;
## - gems: only kinds that fit the class (WorldGear.gem_plan), never more than the piece
##   has sockets (a fourth only at +15), fused at ItemData.GEM_FUSE_CHANCE, bigger with time;
## - it all reaches their power (the guild war's fighter sheet), their card and their chat,
##   and the guild war's sides stay within reach (GEM_KEEN).
##   godot --headless --path . res://tests/integration/world_growth_test.tscn
var failures := 0
var checks := 0
const DAYS := [6.0, 15.0, 30.0, 60.0, 120.0, 200.0]


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _t(day: float) -> float:
	return float(WorldPlayers.START_UNIX) + day * 86400.0


func _power(i: int, t: float, strip := false) -> float:
	var sheet := WorldPlayers.profile(WorldPlayers.member(i, t))
	if strip:
		sheet = sheet.duplicate(true)
		for slot in sheet.equip:
			if (sheet.equip[slot] as Dictionary).has("gems"):
				sheet.equip[slot]["gems"] = []
	return GuildWarData.power_of(HeroStats.compute(sheet))


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	WorldGear.clear()
	Game.new_profile(&"warrior", "Growth QA")
	_plans()
	var sample: Array[int] = []
	for i in range(0, WorldPlayers.size(), 6):
		if _t(3.0) >= WorldPlayers.joined_at(i):
			sample.append(i)
	_growth(sample)
	_odds()
	_reach()
	_determinism(sample)
	print("WORLD GROWTH: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## Each class builds on the gem that fits it.
func _plans() -> void:
	for cls in ClassData.IDS:
		var plan := WorldGear.gem_plan(String(cls))
		var caster := String(ClassData.get_class_data(cls).get("main", "")) == "int"
		if cls == &"defender":
			check(plan.main == "amethyst" and WorldGear.gem_for_slot("defender", "ring") == "emerald" and WorldGear.gem_for_slot("defender", "armor") == "amethyst", "the Defender stacks defence, health in its jewellery")
		else:
			check(plan.main == ("sapphire" if caster else "ruby"), "%s builds on %s" % [cls, "sapphire" if caster else "ruby"])
			check(WorldGear.gem_for_slot(String(cls), "weapon") == plan.main and WorldGear.gem_for_slot(String(cls), "armor") == "emerald", "%s: attack gems in the weapon, emeralds in the armour" % cls)
		check(ItemData.GEMS.has(plan.main) and ItemData.GEMS.has(plan.body) and ItemData.SPECIAL_GEMS.has(plan.special), "%s plans real gems" % cls)
	check(String(ItemData.GEMS.ruby.stat) == "atk" and String(ItemData.GEMS.sapphire.stat) == "matk" and String(ItemData.GEMS.amethyst.stat) == "def" and String(ItemData.GEMS.emerald.stat) == "hp", "the gem table is the one the plan reads")


func _growth(sample: Array[int]) -> void:
	var fits := true
	var room := true
	var fourth := true
	var skill_up := true
	var skill_true := true
	var power_up := true
	var best_up := true
	var worn_gems := 0
	var wearers := {}
	var grew := 0
	var plus15_early := 0
	var plus15_late := 0
	var late_n := 0
	var size_early := 0.0
	var size_late := 0.0
	for i in sample:
		var job := String(WorldPlayers.entry(i)["class"])
		var plan := WorldGear.gem_plan(job)
		var last_stars := -1
		var last_power := 0.0
		var last_best := -1
		var first_power := 0.0
		for d in DAYS:
			var t := _t(d)
			var s := WorldPlayers.state(i, t)
			var equip := WorldPlayers.equip(WorldPlayers.member(i, t))
			var gear := WorldGear.gear(i, t)
			for slot in equip:
				var item: Dictionary = equip[slot]
				var gems: Array = item.get("gems", [])
				room = room and gems.size() <= int(item.get("sockets", 0)) and int(item.get("sockets", 0)) <= ItemData.max_sockets(item)
				fourth = fourth and (int(item.get("sockets", 0)) <= ItemData.MAX_SOCKETS or int(item.get("plus", 0)) >= ItemData.MAX_PLUS)
				for k in gems.size():
					worn_gems += 1
					wearers[i] = true
					var kind := String(gems[k]).split("_")[0]
					var size := int(String(gems[k]).split("_")[1])
					fits = fits and size >= 0 and size <= ItemData.GEM_MAX_SIZE and (kind == WorldGear.gem_for_slot(job, String(slot)) or (kind == String(plan.special) and String(slot) == "ring"))
					if is_equal_approx(d, DAYS[1]):
						size_early += float(size)
					if is_equal_approx(d, DAYS[-1]):
						size_late += float(size)
			# Skills: the stars bought are the points earned, one star each for free.
			var cls := StringName(String(s["class"]))
			# (The Ascension's skills and points once it has won the trial, ascended_at.)
			var won := WorldPlayers.ascended_at(i, t)
			var ranks := WorldPlayers.skill_ranks(cls, int(s.level), int(s.stars), won)
			var stars := 0
			for id in ranks:
				stars += int(ranks[id])
				skill_true = skill_true and int(ranks[id]) >= 1 and int(ranks[id]) <= SkillRank.MAX
			skill_true = skill_true and stars - ranks.size() <= WorldPlayers.skill_points(int(s.level), int(s.stars), won)
			var sum := WorldPlayers.skill_summary(i, t)
			skill_true = skill_true and int(sum.stars) == stars and int(sum.skills) == ranks.size()
			if String(s["class"]) == job:
				skill_up = skill_up and stars >= last_stars
				last_stars = stars
			var power := _power(i, t)
			power_up = power_up and power >= last_power * 0.93
			last_power = maxf(last_power, power)
			if first_power <= 0.0:
				first_power = power
			if int(s.level) >= Game.MAX_LEVEL and int(s.stars) >= 200:
				best_up = best_up and int(gear.gems.best) >= last_best
				last_best = int(gear.gems.best)
			if is_equal_approx(d, DAYS[1]) and int(gear.weapon.plus) >= ItemData.MAX_PLUS:
				plus15_early += 1
			if is_equal_approx(d, DAYS[-1]):
				late_n += 1
				plus15_late += 1 if int(gear.weapon.plus) >= ItemData.MAX_PLUS else 0
		grew += 1 if last_power > first_power * 1.5 else 0
	print("world_growth_test: %d players, %d gem readings on %d players; weapon +15 at day %d: %d, at day %d: %d of %d; gem size sum %.0f -> %.0f" % [sample.size(), worn_gems, wearers.size(),
		int(DAYS[1]), plus15_early, int(DAYS[-1]), plus15_late, late_n, size_early, size_late])
	check(sample.size() >= 15 and worn_gems > 200 and wearers.size() >= sample.size() * 2 / 3, "most players wear gems (%d of %d)" % [wearers.size(), sample.size()])
	check(fits, "every gem fits its wearer's class and slot")
	check(room, "never more gems than sockets, never more sockets than the piece may have")
	check(fourth, "a fourth socket only on a +15 piece")
	check(skill_true, "skill stars: 1 to 5 each, bought with points really earned")
	check(skill_up, "skill stars only go up")
	check(power_up and grew >= sample.size() * 2 / 3, "their power grows with time (%d of %d grew by half or more)" % [grew, sample.size()])
	check(best_up, "at the endgame the best gem worn never gets smaller")
	check(size_late > size_early * 1.5, "gems get bigger and more with time (%.0f -> %.0f)" % [size_early, size_late])
	# The race for the top (WorldGear.ZEAL): the keen forgers reach +15 within weeks.
	check(plus15_late > 0 and plus15_late >= plus15_early, "the long-time players forge their weapons to +15 (%d of %d; %d by day %d)" % [plus15_late, late_n, plus15_early, int(DAYS[1])])


## The forge's and the fuse's odds, counted over everyone's life so far.
func _odds() -> void:
	var tries := {}
	var made := {}
	var jumps := true
	for i in WorldPlayers.size():
		for e in WorldGear.events(i, WorldPlayers.joined_at(i) - 1.0, _t(DAYS[-1])):
			var kind := String(e.kind)
			if kind == "enhance_ok" or kind == "enhance_fail":
				var from := int(e.from)
				tries[from] = int(tries.get(from, 0)) + 1
				if kind == "enhance_ok":
					made[from] = int(made.get(from, 0)) + 1
					jumps = jumps and int(e.to) == from + 1 and int(e.to) <= ItemData.MAX_PLUS
			if kind == "gems":
				jumps = jumps and (e.gems as Array).size() == int(e.to)
	var ok := true
	var line := ""
	for from in range(0, ItemData.MAX_PLUS):
		var n := int(tries.get(from, 0))
		if n < 400:
			continue
		var rate := float(int(made.get(from, 0))) / float(n)
		var want := ItemData.enhance_chance(from)
		line += " +%d %.2f/%.2f(%d)" % [from, rate, want, n]
		ok = ok and absf(rate - want) < 0.05
	print("world_growth_test: enhance success / the forge's odds (tries):%s" % line)
	check(ok and line != "", "enhancing succeeds at the forge's own odds")
	check(jumps, "a success is one + at a time, up to +%d" % ItemData.MAX_PLUS)
	var fuse_ok := true
	var fuse_line := ""
	for s in ItemData.GEM_FUSE_CHANCE.size():
		var n := int(WorldGear.fuse_tries[s])
		if n < 200:
			continue
		var rate := float(int(WorldGear.fuse_made[s])) / float(n)
		fuse_line += " %s %.2f/%.2f(%d)" % [ItemData.GEM_SIZES[s], rate, float(ItemData.GEM_FUSE_CHANCE[s]), n]
		fuse_ok = fuse_ok and absf(rate - float(ItemData.GEM_FUSE_CHANCE[s])) < 0.06
	print("world_growth_test: gem fuses made / the forge's odds (tries):%s" % fuse_line)
	check(fuse_ok and fuse_line != "", "gems fuse at the forge's own odds")
	check(WorldGear.GEM_KEEN > 0.0 and WorldGear.GEM_KEEN <= 1.0 and WorldGear.GEM_KEEN_FIELD <= 1.0 and WorldGear.GEM_KEEN_ENDGAME <= 1.0, "they use a share of the gems their kills drop, never more")
	check(WorldGear.GEM_FUSE_TOP >= ItemData.GEM_MAX_SIZE or int(WorldGear.fuse_tries[WorldGear.GEM_FUSE_TOP]) == 0, "they fuse up to size %s" % ItemData.GEM_SIZES[mini(WorldGear.GEM_FUSE_TOP, ItemData.GEM_MAX_SIZE)])


## It reaches the fighter sheet, the card and the chat; the guild war stays in reach.
func _reach() -> void:
	var t := _t(120.0)
	var worst := 0.0
	var line := ""
	for g in WorldPlayers.GUILDS:
		var with := 0.0
		var bare := 0.0
		for i in GuildWarData.side_ids(g, t).ids:
			with += _power(i, t)
			bare += _power(i, t, true)
		if bare > 0.0:
			worst = maxf(worst, with / bare)
			line += " %s x%.2f" % [WorldPlayers.guild_name(g), with / bare]
	print("world_growth_test: a guild side's power with its gems over without, day 120:%s" % line)
	check(worst > 1.02, "gems count in a fighter's power")
	check(worst <= MAX_GEM_LIFT, "but a side is at most %.0f%% stronger for them (%.2f)" % [(MAX_GEM_LIFT - 1.0) * 100.0, worst])
	var who := -1
	for i in WorldPlayers.size():
		if t >= WorldPlayers.joined_at(i) and int(WorldGear.gear(i, t).gems.count) >= 6:
			who = i
			break
	check(who >= 0, "someone wears six gems or more by day 120")
	if who < 0:
		return
	var gear := WorldGear.gear(who, t)
	var card := PlayerCard.gear_lines(who, t)
	check(card.contains("อัญมณี: %d/%d ช่อง" % [int(gear.gems.count), int(gear.gems.sockets)]) and card.contains(String(gear.gems.main_name)) and card.contains("สกิล: "), "the card shows its gems and skill stars (%s)" % card)
	var fighter := WorldPlayers.fighter(who, t)
	var worn := 0
	for slot in fighter.profile.equip:
		worn += ((fighter.profile.equip[slot] as Dictionary).get("gems", []) as Array).size()
	check(worn == int(gear.gems.count) and float(fighter.power) > _power(who, t, true), "its guild war fighter wears the same gems and is stronger for them")
	var s := WorldPlayers.state(who, t)
	var player := {"index": who, "name": String(s.name), "class": "", "level": int(s.level), "stars": int(s.stars), "style": "", "doing": "hunt", "place": "", "guild": "", "gender": 0, "inParty": false}
	var said := String(ChatBrain.reply({"text": "ฝังอัญมณีอะไรไว้บ้าง", "player": player, "hero": {"name": "x", "level": 60, "stars": 0}, "history": [], "t": t, "channel": "direct"}).reply)
	check(said.contains("%d เม็ด" % int(gear.gems.count)) and said.contains(String(gear.gems.main_name)), "asked, it tells its real gems (%s)" % said)
	check(WorldGear.signature_at_work(who, WorldPlayers.work_at(who, t)).contains("g:"), "its gear signature carries the gems (a new gem refreshes its body and sheet)")


## A guild side may be this much stronger for its gems (WorldGear.GEM_KEEN keeps it so).
## The race for the top (WorldGear.ZEAL): legendary gems in every socket nearly double a side.
const MAX_GEM_LIFT := 2.0


## The same on every device: worked out again from nothing, and whatever was read first.
func _determinism(sample: Array[int]) -> void:
	var t := _t(90.0)
	var before := {}
	for i in sample:
		before[i] = [WorldGear.signature_at_work(i, WorldPlayers.work_at(i, t)), JSON.stringify(WorldGear.gear(i, t).gems)]
	WorldGear.clear()
	var same := true
	for k in range(sample.size() - 1, -1, -1):
		var i := sample[k]
		# Another device read a later day first.
		WorldGear.gear(i, _t(150.0))
		same = same and before[i][0] == WorldGear.signature_at_work(i, WorldPlayers.work_at(i, t)) and before[i][1] == JSON.stringify(WorldGear.gear(i, t).gems)
	check(same, "gear, + and gems are the same worked out again, in another order")
	var names := {}
	for kind in WorldGear.KINDS:
		names[kind] = true
	var known := true
	for i in sample:
		for e in WorldGear.events(i, _t(80.0), _t(90.0)):
			known = known and names.has(String(e.kind))
	check(known, "every event is of a known kind")
