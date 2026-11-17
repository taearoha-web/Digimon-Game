extends Node
## The weekly rare collection (WeeklyCollect, อีเว้นสะสมของแรร์ประจำสัปดาห์), headless:
## - the week: off before 20 Nov 2026 07:40 Thai (the x5 festival's end), weeks from Friday
##   07:40 to Friday 07:40, a new theme every week round all eight, the HUD chip and
##   WorldEvents.current, switched off with WorldEvents.festival_enabled;
## - the pieces: stackable jewels with names, prices and an icon each (all different),
##   valid in a save, refused with an unknown id;
## - drops: every hunting ground (not the village, duels, guild war, arena, tower), the
##   per-kill chance moved by the field's kill pace so an hour finds about the same from
##   the meadow to the ★300 isle (rolled kill by kill at each field's real pace), a set in
##   a few hours, the legendary piece a real hunt; elites, bosses, the golden monster and
##   the world boss roll more; nothing outside the event;
## - the exchange: takes the week's pieces and gives the reward once (gold and items by
##   the hero's band), the weekly limit, nothing for pieces of another theme, a full bag
##   refused with nothing taken, the title for the first set;
## - the record: points for a picked-up piece of the week only, the drop pop-up, a new
##   week starts it over, Game._valid_profile / _repair, a JSON round trip;
## - the AI world players: their pieces grow with their play time this week and are the
##   same when worked out again, the top collectors mix them with the hero, a stall keeper
##   only sells spare pieces it found itself (six lots still), their chat names the theme
##   and their true finds, ChatBrain answers about the event;
## - the menu page and the HUD pop-up build.
##   XDG_DATA_HOME=$(mktemp -d) godot --headless --path . res://tests/integration/weekly_collect_test.tscn
var checks := 0
var failures := 0
const DAY := 86400.0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _hero(level := 60, stars := 0) -> void:
	Game.new_profile(&"warrior", "สะสมQA", FaceKit.default_look())
	Game.profile.level = level
	if level >= Game.MAX_LEVEL:
		Game.profile.adv = 4
		Game.profile.paragon["level"] = stars


func _ready() -> void:
	Game.set_process(false)
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	Announcer.ticking = false
	_week()
	_pieces()
	_drops()
	_exchange()
	_record()
	_ai()
	await _ui()
	WorldPresence.clock_offset = 0.0
	print("WEEKLY COLLECT: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAILED", checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


# --- The week ----------------------------------------------------------------------------

func _week() -> void:
	var start := thai(2026, 11, 20, 7, 40)
	check(float(WeeklyCollect.START) == start and WeeklyCollect.START == WorldEvents.FESTIVAL5_END, "the first week starts 20 Nov 2026 07:40 Thai, as the x5 festival ends")
	check(WorldEvents.weekday(start) == 5, "the week turns on a Friday")
	check(not WeeklyCollect.on(start - 1.0) and WeeklyCollect.week_of(start - 1.0) == -1 and WeeklyCollect.on(start) and WeeklyCollect.week_of(start) == 0, "off before the start, week 0 from it")
	check(WeeklyCollect.week_of(thai(2026, 11, 27, 7, 39)) == 0 and WeeklyCollect.week_of(thai(2026, 11, 27, 7, 40)) == 1, "the reset is Friday 07:40 Thai time")
	check(WeeklyCollect.week_start(1) == thai(2026, 11, 27, 7, 40) and WeeklyCollect.week_end(1) == thai(2026, 12, 4, 7, 40), "week 1 runs 27 Nov to 4 Dec 07:40")
	check(String(WeeklyCollect.theme(0).name) == "ราตรีลอยกระทง", "the first week (with Loy Krathong, 24 Nov 2026) is ราตรีลอยกระทง")
	var seen := {}
	for w in WeeklyCollect.THEMES.size():
		seen[String(WeeklyCollect.theme(w).name)] = true
		check(WeeklyCollect.theme_index(w) != WeeklyCollect.theme_index(w + 1), "week %d and the next differ" % w)
	check(seen.size() == WeeklyCollect.THEMES.size() and WeeklyCollect.theme_index(WeeklyCollect.THEMES.size()) == 0, "eight themes, every one in eight weeks, then round again")
	for th in WeeklyCollect.THEMES:
		check((th.pieces as Array).size() == WeeklyCollect.PIECES, "%s has five pieces" % th.name)
	var mid := thai(2026, 11, 22, 10)
	var chip := WeeklyCollect.chip_text(mid)
	check(chip.contains("ราตรีลอยกระทง") and chip.contains("เหลือ 4 วัน"), "the HUD chip names the theme and counts the week down (%s)" % chip)
	check(WorldEvents.chip_lines(mid).has(chip), "the HUD event chip shows it")
	check(WorldEvents.current(mid).any(func(e): return String(e.id) == "weekly" and float(e.until) == WeeklyCollect.week_end(0) and String(e.name_th).contains("ราตรีลอยกระทง")), "WorldEvents.current lists the week's theme")
	check(WeeklyCollect.chip_text(thai(2026, 11, 18, 10)) == "" and not WorldEvents.current(thai(2026, 11, 18, 10)).any(func(e): return String(e.id) == "weekly"), "nothing before the start")
	check(WeeklyCollect.chip_text(thai(2026, 11, 27, 7, 50)).contains(String(WeeklyCollect.theme(1).name)), "the next week shows the next theme")
	WorldEvents.festival_enabled = false
	check(not WeeklyCollect.on(mid) and WeeklyCollect.chip_text(mid) == "", "the base-rate tests' switch turns it off")
	WorldEvents.festival_enabled = true
	WeeklyCollect.enabled = false
	check(not WeeklyCollect.on(mid), "its own switch turns it off")
	WeeklyCollect.enabled = true
	check(WeeklyCollect.left_text(3.0 * DAY + 4.0 * 3600.0) == "3 วัน 4 ชม." and WeeklyCollect.left_text(5.0 * 3600.0 + 12.0 * 60.0) == "5 ชม. 12 นาที", "countdown text")


# --- The pieces ----------------------------------------------------------------------------

func _pieces() -> void:
	_hero()
	var icons := {}
	for th in WeeklyCollect.THEMES.size():
		for k in WeeklyCollect.PIECES:
			var id := WeeklyCollect.piece_id(th, k)
			var item := WeeklyCollect.piece(th, k, 3)
			check(ItemData.JEWELS.has(id) and String(ItemData.JEWELS[id].name) == String(WeeklyCollect.THEMES[th].pieces[k]), "%s is a jewel named as its theme says" % id)
			check(int(ItemData.JEWELS[id].price) == WeeklyCollect.PRICES[k] and ItemData.JEWELS[id].color == WeeklyCollect.RANK_COLORS[k], "%s priced and coloured by its rank" % id)
			check(ItemData.is_stackable(item) and ItemData.tile_text(item) == "×3" and Game._valid_item(item), "%s is a valid stack" % id)
			check(WeeklyCollect.is_piece(item) and WeeklyCollect.rank_of(item) == k and WeeklyCollect.parse(id) == Vector2i(th, k), "%s parses back" % id)
			check(OnlineTrade.tradable(item) and StallStock.sellable(item) and ItemData.sell_price(item) > 0, "%s trades, goes on a stall and sells" % id)
			var icon := ItemLook.icon(item)
			check(icon != null, "%s has its icon" % id)
			if icon != null:
				icons[icon.resource_path] = true
	check(icons.size() == WeeklyCollect.THEMES.size() * WeeklyCollect.PIECES, "every piece has an icon of its own (%d)" % icons.size())
	for bad in ["wk8_0", "wk0_5", "wk00_0", "wkx_1"]:
		check(not WeeklyCollect.is_piece(ItemData.jewel(bad)) and not Game._valid_item(ItemData.jewel(bad)), "%s is no piece and no valid item" % bad)
	check(not Game._valid_item({"kind": "jewel", "id": "wk0_0", "count": 0}) and not Game._valid_item({"kind": "jewel", "id": "wk0_0", "count": 1, "level": 3}), "a piece stack is checked like any jewel")
	check(not WeeklyCollect.is_piece(ItemData.jewel("purple")) and WeeklyCollect.rank_of(ItemData.gem("ruby", 1)) == -1, "forge jewels are no pieces")


# --- Drops -------------------------------------------------------------------------------

func _drops() -> void:
	ZoneData.ensure()
	var t := thai(2026, 11, 22, 10)
	var fields := 0
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		var bad := bool(z.get("safe", false)) or bool(z.get("pvp", false)) or bool(z.get("guildwar", false)) or bool(z.get("arena", false)) or bool(z.get("tower", false))
		check(WeeklyCollect.zone_ok(z) != bad, "%s: pieces drop %s" % [id, "nowhere" if bad else "here"])
		if bad or (z.get("camps", []) as Array).is_empty():
			continue
		fields += 1
		# An hour of steady hunting finds about the same in every field.
		var common := WeeklyCollect.per_hour(0, z)
		var legend := WeeklyCollect.per_hour(WeeklyCollect.PIECES - 1, z)
		check(common > 7.0 and common < 9.0, "%s: about 8 common pieces an hour (%.2f)" % [id, common])
		check(legend > 0.35 and legend < 0.45, "%s: about 0.4 legendary pieces an hour (%.3f)" % [id, legend])
		for k in WeeklyCollect.PIECES - 1:
			check(WeeklyCollect.per_hour(k, z) > WeeklyCollect.per_hour(k + 1, z), "%s: rank %d drops more than rank %d" % [id, k, k + 1])
		check(WeeklyCollect.chance(0, z, WeeklyCollect.ELITE) > WeeklyCollect.chance(0, z) and WeeklyCollect.chance(4, z, WeeklyCollect.BOSS) >= WeeklyCollect.chance(4, z, WeeklyCollect.ELITE), "%s: elites and bosses roll more" % id)
		check(WeeklyCollect.chance(0, z, WeeklyCollect.WORLD_BOSS) <= WeeklyCollect.CHANCE_CAP, "%s: a kill's chance is capped" % id)
	check(fields >= 15, "every levelling, star and endgame field checked (%d)" % fields)
	check(WeeklyCollect.chance(0, ZoneData.get_zone(&"meadow")) > WeeklyCollect.chance(0, ZoneData.get_zone(&"swamp")) and WeeklyCollect.chance(0, ZoneData.get_zone(&"drowned_abyss")) > WeeklyCollect.chance(0, ZoneData.get_zone(&"crystal_valley")),
		"the per-kill chance follows the field's pace (faster fields lower)")
	check(absf(WeeklyCollect.chance(0, ZoneData.get_zone(&"swamp")) - 1.0 / 150.0 * WeeklyCollect.REF_PACE / WorldGear.kills_per_minute(64, 0)) < 1e-6, "a Lv.53-64 kill: 1/150 at the reference pace, moved by the field's own")
	check(is_equal_approx(WeeklyCollect.chance(0, ZoneData.get_zone(&"swamp"), 1.0, 0.5), WeeklyCollect.chance(0, ZoneData.get_zone(&"swamp")) * 1.5), "fortune adds its share")
	# Rolled kill by kill at the field's real pace, from a newcomer to ★300.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	for id in [&"meadow", &"volcano", &"swamp", &"crystal_valley", &"drowned_abyss", &"sky_dragon_isle"]:
		var z := ZoneData.get_zone(id)
		var hours := 60.0
		var kills := int(WeeklyCollect.pace_of(z) * 60.0 * hours)
		var got := [0, 0, 0, 0, 0]
		for n in kills:
			for item in WeeklyCollect.kill_drops(z, "", 0.0, t, rng):
				got[WeeklyCollect.rank_of(item)] += 1
		var per := got.map(func(c): return float(c) / hours)
		print("weekly_collect_test: %s %d kills/%.0f h: %s an hour" % [id, kills, hours, per.map(func(v): return String.num(v, 2))])
		check(per[0] > 6.5 and per[0] < 9.5, "%s: common pieces an hour by real rolls (%.2f)" % [id, per[0]])
		check(per[4] > 0.15 and per[4] < 0.75, "%s: legendary pieces an hour by real rolls (%.2f)" % [id, per[4]])
	# A full set: the time until all five ranks are found (many players' worth).
	var total := 0.0
	var runs := 200
	for r in runs:
		var need := 0.0
		for k in WeeklyCollect.PIECES:
			# Exponential waiting time of rank k at its hourly rate.
			var rate := 60.0 * WeeklyCollect.REF_PACE / float(WeeklyCollect.RATE[k])
			need = maxf(need, -log(1.0 - rng.randf()) / rate)
		total += need
	var mean := total / float(runs)
	print("weekly_collect_test: a full set takes %.1f hours on average" % mean)
	check(mean > 2.0 and mean < 4.5, "a steady player completes a set in a few hours (%.1f h)" % mean)
	# Monsters of every kind roll more; nothing outside the event or the hunting grounds.
	var swamp := ZoneData.get_zone(&"swamp")
	var plain := 0
	var boss := 0
	for n in 20000:
		plain += WeeklyCollect.kill_drops(swamp, "", 0.0, t, rng).size()
		boss += WeeklyCollect.kill_drops(swamp, "boss", 0.0, t, rng).size()
	check(boss > plain * 7, "a boss drops about ten times as many pieces (%d vs %d)" % [boss, plain])
	var none := 0
	for n in 3000:
		none += WeeklyCollect.kill_drops(swamp, "boss", 0.0, thai(2026, 11, 19, 10), rng).size()
		none += WeeklyCollect.kill_drops(ZoneData.get_zone(&"arena"), "boss", 0.0, t, rng).size()
		none += WeeklyCollect.kill_drops({}, "boss", 0.0, t, rng).size()
	check(none == 0, "nothing before the start, in the arena or in the village (%d)" % none)
	var theme := WeeklyCollect.theme_index(WeeklyCollect.week_of(t))
	var drop: Array = WeeklyCollect.kill_drops(swamp, "world_boss", 0.0, t, rng)
	check(drop.all(func(item): return WeeklyCollect.parse(String(item.id)).x == theme), "the week's own theme drops")


# --- The exchange ------------------------------------------------------------------------

func _give(th: int, counts: Array) -> void:
	for k in counts.size():
		if int(counts[k]) > 0:
			Game.add_item(WeeklyCollect.piece(th, k, int(counts[k])))


func _count(kind: String, id: String) -> int:
	var n := 0
	for item in Game.profile.inv:
		if String(item.get("kind", "")) == kind and String(item.get("id", "")) == id:
			n += int(item.get("count", 1))
	return n


func _exchange() -> void:
	var t := thai(2026, 11, 23, 20)
	pin(t)
	_hero(100, 300)
	check(WeeklyCollect.hero_tier() == 5 and WeeklyCollect.tier_of(30, 0) == 0 and WeeklyCollect.tier_of(70, 0) == 1 and WeeklyCollect.tier_of(100, 50) == 2 and WeeklyCollect.tier_of(100, 150) == 3 and WeeklyCollect.tier_of(100, 250) == 4, "the six bands")
	# Rewards grow with the band and every band gets something worth it.
	for e in WeeklyCollect.OPTIONS:
		var last := -1
		for tier in WeeklyCollect.TIER_NAMES.size():
			var r := WeeklyCollect.rewards(String(e.id), tier, "warrior")
			check(not (r.items as Array).is_empty(), "%s gives items at band %d" % [e.id, tier])
			var worth := int(r.gold)
			for item in r.items:
				check(Game._valid_item(item), "%s reward %s is a valid item" % [e.id, JSON.stringify(item)])
				worth += ItemData.sell_price(item)
			check(worth > last, "%s at band %d is worth more than the band below (%d)" % [e.id, tier, worth])
			last = worth
	var set_r := WeeklyCollect.rewards("set", 5, "warrior")
	check((set_r.items as Array).any(func(i): return String(i.id) == "dragon_fragment") and (set_r.items as Array).any(func(i): return String(i.id) == "chaos") and (set_r.items as Array).any(func(i): return String(i.id) == "set_core"),
		"the ★300 chest holds chaos jewels, set cores and costume fragments")
	check((WeeklyCollect.rewards("set", 0, "mage").items as Array).any(func(i): return String(i.kind) == "gem" and String(i.id).begins_with(String(WorldGear.gem_plan("mage").main))), "the chest's gem is the class's own")
	var th := WeeklyCollect.theme_index(WeeklyCollect.week_of(t))
	var other := posmod(th + 1, WeeklyCollect.THEMES.size())
	check(WeeklyCollect.problem("set") != "", "no pieces: no exchange (%s)" % WeeklyCollect.problem("set"))
	# Another theme's pieces do not count.
	_give(other, [1, 1, 1, 1, 1])
	check(WeeklyCollect.problem("set").contains("ไม่พอ"), "another week's set does not count")
	check(WeeklyCollect.other_pieces(t).size() == 5 and int(WeeklyCollect.other_pieces(t)[0].back) > WeeklyCollect.week_of(t), "they are listed with the week their theme comes back")
	_give(th, [4, 2, 1, 1, 1])
	# Whatever else this fresh hero has earned is paid first (achievement gold).
	Game.check_achievements()
	var gold := int(Game.profile.gold)
	var chaos := _count("jewel", "chaos")
	var frags := _count("jewel", "dragon_fragment")
	check(WeeklyCollect.problem("set") == "", "a full set can be exchanged")
	check(WeeklyCollect.exchange("set") == "ok", "the set is exchanged")
	check(int(Game.profile.gold) == gold + int(set_r.gold), "the chest's gold is paid (%d)" % (int(Game.profile.gold) - gold))
	check(_count("jewel", "chaos") == chaos + 20 and _count("jewel", "dragon_fragment") == frags + 3, "the chest's items are in the bag")
	check(WeeklyCollect.owned(th, 0) == 3 and WeeklyCollect.owned(th, 4) == 0 and WeeklyCollect.owned(other, 4) == 1, "one of each of the week's pieces is taken, the other theme's stay")
	check(WeeklyCollect.used("set") == 1 and int(Game.profile.flags.get(WeeklyCollect.SETS_FLAG, 0)) == 1, "counted once")
	check(Achievements.is_earned("t_wcol", Game.profile) and String(Achievements.entry("t_wcol").title) == "นักสะสมของแรร์", "the first set earns the title นักสะสมของแรร์")
	gold = int(Game.profile.gold)
	check(WeeklyCollect.exchange("set") != "ok" and int(Game.profile.gold) == gold and WeeklyCollect.used("set") == 1, "a second set without the pieces: nothing given, nothing counted")
	# Singles.
	check(WeeklyCollect.exchange("p0") == "ok" and WeeklyCollect.owned(th, 0) == 0 and WeeklyCollect.used("p0") == 1, "three common pieces for the small bag")
	check(WeeklyCollect.exchange("p0") != "ok", "and not again without pieces")
	# The weekly limit.
	_give(th, [0, 0, 0, 0, 5])
	for n in 2:
		check(WeeklyCollect.exchange("p4") == "ok", "a legendary piece for the gold box (%d)" % n)
	check(WeeklyCollect.problem("p4").contains("ครบ") and WeeklyCollect.exchange("p4") != "ok" and WeeklyCollect.owned(th, 4) == 3, "the week's limit holds and keeps the pieces")
	# A full bag: refused, nothing taken.
	_give(th, [0, 0, 1, 0, 0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(20, &"warrior", rng, 1, "helm"))
	for item in WeeklyCollect.rewards("p2", 5, "warrior").items:
		Game.profile.inv = Game.profile.inv.filter(func(x): return not (String(x.get("kind", "")) == String(item.kind) and String(x.get("id", "")) == String(item.id)))
	while Game.inventory_free() > 0:
		Game.profile.inv.append(ItemData.generate(20, &"warrior", rng, 1, "helm"))
	var before: int = Game.profile.inv.size()
	check(WeeklyCollect.problem("p2").contains("กระเป๋า") and WeeklyCollect.exchange("p2") != "ok" and WeeklyCollect.owned(th, 2) == 1 and Game.profile.inv.size() == before, "a full bag: refused, the piece stays")
	# A new week starts the record over.
	pin(t + 7.0 * DAY)
	check(WeeklyCollect.used("set") == 0 and WeeklyCollect.points() == 0, "a new week: the limits and points start over")
	pin(t)


# --- The record ----------------------------------------------------------------------------

func _record() -> void:
	var t := thai(2026, 11, 24, 21)
	pin(t)
	_hero(45)
	var th := WeeklyCollect.theme_index(WeeklyCollect.week_of(t))
	var heard: Array = []
	var sink := func(item: Dictionary, info: Dictionary): heard.append([item, info])
	WeeklyCollect.listen(sink)
	var item := WeeklyCollect.piece(th, 3)
	Game.add_item(item)
	WeeklyCollect.picked(item)
	check(WeeklyCollect.points() == WeeklyCollect.POINTS[3] and int(WeeklyCollect.data().got[3]) == 1, "a picked-up piece of the week scores its points")
	check(heard.size() == 1 and int(heard[0][1].rank) == 3 and int(heard[0][1].kinds) == 1 and int(heard[0][1].have) == 1, "the pop-up hears it with the set progress")
	WeeklyCollect.picked(WeeklyCollect.piece(posmod(th + 3, 8), 4))
	check(WeeklyCollect.points() == WeeklyCollect.POINTS[3], "another theme's piece scores nothing")
	WeeklyCollect.unlisten(sink)
	Game.profile.flags[WeeklyCollect.SETS_FLAG] = 2
	Game.profile.flags[WeeklyCollect.THEMES_FLAG] = 0xFF
	WeeklyCollect.data()["ex"] = {"set": 2, "p1": 4, "gone": 1}
	var copy: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	check(Game._valid_profile(copy), "a save with the record and pieces is valid")
	var fixed := Game._repair(copy)
	var rec: Dictionary = fixed[WeeklyCollect.KEY]
	check(rec.week is int and rec.pts is int and (rec.got as Array).all(func(n): return n is int) and int(rec.ex.set) == 2 and not (rec.ex as Dictionary).has("gone"), "repair: ints back, unknown options dropped")
	check((fixed.inv as Array).any(func(x): return String(x.get("id", "")) == WeeklyCollect.piece_id(th, 3) and x.count is int), "the piece survives the round trip")
	Game.check_achievements()
	check(Achievements.is_earned("t_wcol_all", Game.profile), "all eight themes' sets earn ตำนานนักสะสม")
	for bad in [[], {"week": "x"}, {"pts": -1}, {"got": [1, 2]}, {"ex": {"set": 1001}}, {"junk": 1}, {"ex": []}]:
		var p: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
		p[WeeklyCollect.KEY] = bad
		check(not Game._valid_profile(p), "a broken record is refused (%s)" % JSON.stringify(bad))
	var p2: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	(p2.inv as Array).append({"kind": "jewel", "id": "wk9_0", "count": 1})
	check(not Game._valid_profile(p2), "an unknown piece id is refused")


# --- The AI world players ----------------------------------------------------------------

func _ai() -> void:
	var t := thai(2026, 11, 25, 20)
	pin(t)
	_hero(80)
	var start := WeeklyCollect.week_start(WeeklyCollect.week_of(t))
	var some := 0
	var grows := true
	for i in WorldPlayers.size():
		var a := WeeklyCollect.ai_counts(i, start + 3600.0 * 12.0)
		var b := WeeklyCollect.ai_counts(i, t)
		for k in WeeklyCollect.PIECES:
			grows = grows and int(b[k]) >= int(a[k])
		some += 1 if WeeklyCollect.points_of(b) > 0 else 0
		check(WeeklyCollect.ai_counts(i, start - 60.0).all(func(n): return int(n) == 0) or WeeklyCollect.week_of(start - 60.0) >= 0, "nothing before the week")
	check(grows, "an AI player's pieces only grow during the week")
	check(some > WorldPlayers.size() / 3, "most AI players have found pieces by mid-week (%d of %d)" % [some, WorldPlayers.size()])
	var again := WeeklyCollect.ai_counts(3, t)
	WeeklyCollect._week_minutes.clear()
	check(WeeklyCollect.ai_counts(3, t) == again, "worked out again it is the same")
	check(WeeklyCollect.ai_counts(3, WeeklyCollect.week_start(WeeklyCollect.week_of(t) + 1) + 60.0).all(func(n): return int(n) <= 1), "a new week starts their count over")
	# The top collectors.
	WeeklyCollect.data()["pts"] = 40
	var board := WeeklyCollect.leaderboard(t)
	check(board.size() == WeeklyCollect.TOP, "ten top collectors")
	var sorted := true
	for n in board.size() - 1:
		sorted = sorted and int(board[n].pts) >= int(board[n + 1].pts)
	check(sorted and board.all(func(r): return int(r.pts) > 0), "best first")
	check(board.any(func(r): return not bool(r.hero)), "AI players on the board")
	var rank := WeeklyCollect.hero_rank(t)
	WeeklyCollect.data()["pts"] = int(board[0].pts) + 1
	check(rank > 1 and WeeklyCollect.hero_rank(t) == 1 and bool(WeeklyCollect.leaderboard(t)[0].hero), "the hero climbs to the top with the most points (was %d)" % rank)
	print("weekly_collect_test: top collectors %s" % [WeeklyCollect.leaderboard(t, 5).map(func(r): return "%s %d" % [r.name, int(r.pts)])])
	# Stall keepers sell only spare pieces they found themselves.
	var piece_lots := 0
	for h in range(0, 48, 2):
		var at := start + 3600.0 * (8.0 + float(h))
		for i in WorldPlayers.size():
			if not WorldPlayers.in_town_style(i):
				continue
			var lots := StallStock.full_stock(i, at)
			check(lots.size() <= 6, "six lots at most")
			for lot in lots:
				if not WeeklyCollect.is_piece(lot.item):
					continue
				piece_lots += 1
				var from := StallStock.restock_at(i, at) - StallStock.RESTOCK
				var counts := WeeklyCollect.ai_counts(i, from)
				var k := WeeklyCollect.rank_of(lot.item)
				check(int(lot.item.count) <= int(counts[k]) - 1, "%s sells %d of rank %d, a spare of the %d it found" % [WorldPlayers.entry(i).name, int(lot.item.count), k, int(counts[k])])
				check(WeeklyCollect.parse(String(lot.item.id)).x == WeeklyCollect.theme_index(WeeklyCollect.week_of(from)), "the week's theme")
				check(int(lot.price) == StallStock.goods_price(lot.item) and StallStock.sellable(lot.item), "priced as goods and sellable")
	print("weekly_collect_test: %d stall lots of pieces over two days" % piece_lots)
	check(piece_lots > 0, "stall keepers lay out pieces now and then")
	var quiet := 0
	for i in WorldPlayers.size():
		if WorldPlayers.in_town_style(i):
			quiet += StallStock.full_stock(i, thai(2026, 11, 18, 12)).filter(func(l): return WeeklyCollect.is_piece(l.item)).size()
	check(quiet == 0, "no pieces on the stalls before the event")
	# Chat: the theme and true finds.
	var lines := 0
	var named := 0
	var rx := RegEx.new()
	rx.compile("เก็บ(\\S+?)แล้ว (\\d+) อัน")
	var theme := WeeklyCollect.theme(WeeklyCollect.week_of(t))
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if not bool(s.online):
			continue
		for n in 6:
			var line := WeeklyCollect.chat_line(s, i * 31 + n, t)
			if line == "":
				continue
			lines += 1
			check(line.contains(String(theme.name)), "an AI line names the week's theme (%s)" % line)
			var m := rx.search(line)
			if m != null:
				named += 1
				check(int(m.get_string(2)) == int(WeeklyCollect.ai_counts(i, t)[0]) and m.get_string(1) == String(theme.pieces[0]), "%s tells its true count (%s)" % [s.name, line])
			for k in range(2, WeeklyCollect.PIECES):
				if line.contains(String(theme.pieces[k])) and not line.contains("ลุ้น") and not line.contains("ใคร"):
					check(int(WeeklyCollect.ai_counts(i, t)[k]) > 0, "%s only claims a piece it found (%s)" % [s.name, line])
			for word in ["Lv.", "★", "+", "ชิ้น", "เปอร์เซ็นต์"]:
				check(not line.contains(word), "no claim the chat checks elsewhere (%s in %s)" % [word, line])
	check(lines > 50 and named > 0, "the AI players talk of the week (%d lines, %d counts)" % [lines, named])
	check(WeeklyCollect.chat_line({"index": 0}, 1, thai(2026, 11, 18, 10)) == "", "not before the event")
	var said := WorldChat.line_for(WorldPlayers.state(0, t), 0, t)
	check(said != "", "the single lines still work")
	var weekly_singles := 0
	for seed_value in 400:
		if WorldChat.line_for(WorldPlayers.state(seed_value % WorldPlayers.size(), t), seed_value, t).contains(String(theme.name)):
			weekly_singles += 1
	check(weekly_singles > 0, "the world chat now and then talks of the theme (%d of 400)" % weekly_singles)
	var reply := ChatBrain.reply({"text": "ของแรร์สัปดาห์นี้ธีมอะไร", "player": {"index": 5, "name": String(WorldPlayers.entry(5).name), "level": 50}, "hero": {}, "history": [], "t": t, "channel": "direct"})
	check(String(reply.reply).contains(String(theme.name)) and String(reply.reply).contains(WeeklyCollect.NAME), "ChatBrain answers about the event (%s)" % reply.reply)


# --- The page and the pop-up ---------------------------------------------------------------

func _ui() -> void:
	var t := thai(2026, 11, 26, 12)
	pin(t)
	_hero(100, 120)
	var th := WeeklyCollect.theme_index(WeeklyCollect.week_of(t))
	_give(th, [5, 3, 1, 1, 1])
	var menu := GameMenu.new()
	add_child(menu)
	check(GameMenu.TABS.any(func(p): return String(p[0]) == "weekly" and String(p[1]) == WeeklyCollect.NAME), "the menu has the สะสมของแรร์ tab")
	menu.open_menu(&"weekly")
	await get_tree().process_frame
	await get_tree().process_frame
	var view := menu.find_child("WeeklyCollectView", true, false)
	check(view != null, "the page is built")
	for k in WeeklyCollect.PIECES:
		check(menu.find_child("WeeklyIcon_%d" % k, true, false) is TextureRect, "piece %d shows its icon" % k)
	var buy := menu.find_child("WeeklyBuy_set", true, false) as Button
	check(buy != null and not buy.disabled, "the set can be exchanged from the page")
	check(menu.find_child("WeeklyLeaders", true, false) != null and menu.find_child("WeeklyCountdown", true, false) != null, "top collectors and the countdown")
	var gold := int(Game.profile.gold)
	buy.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(int(Game.profile.gold) > gold and WeeklyCollect.used("set") == 1, "pressing แลก exchanges once")
	var again := menu.find_child("WeeklyBuy_set", true, false) as Button
	check(again != null and again.disabled, "and the button is off without a set")
	menu.close_menu()
	menu.queue_free()
	var popup := WeeklyDropPopup.new()
	popup.size = Vector2(WeeklyDropPopup.WIDTH, WeeklyDropPopup.HEIGHT)
	add_child(popup)
	await get_tree().process_frame
	var item := WeeklyCollect.piece(th, 4)
	Game.add_item(item)
	WeeklyCollect.picked(item)
	WeeklyCollect.picked(WeeklyCollect.piece(th, 0))
	WeeklyCollect.picked(WeeklyCollect.piece(th, 0))
	check(popup.shown.size() == 1 and popup.queue.size() == 1 and int(popup.queue[0].item.count) == 2, "the pop-up shows one at a time and adds up the same piece")
	check((popup.find_child("PieceName", true, false) as Label).text.contains(ItemData.name_of(item)), "it names the piece")
	popup.queue_free()
	await get_tree().process_frame
