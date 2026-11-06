extends Node
## Daily / weekly quests and the free monthly pass (DailyPass, ภารกิจ & บัตร): five daily
## quests and three weekly ones drawn per character and Thai day / week, the same draw
## every time; real game events (kills, bosses, trades, the stall, enhancing, party
## minutes, chat, the world boss, guild wars) move them through Game.daily_progress;
## a finished quest is claimed once for pass points, gold and EXP; 30 tiers a month,
## claimed one by one or all at once (the top one grants a title); the day, week and
## month reset on the Thai calendar with a warning before the month ends; the save stays
## valid through JSON, _repair and a save / load; the menu page and the HUD dot work.
##   godot --headless --path . res://tests/integration/daily_pass_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Unix time of a Thai calendar date and hour.
func thai(y: int, m: int, d: int, h := 12) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": h, "minute": 0, "second": 0}) - WorldPlayers.TZ)


func _ready() -> void:
	# Wednesday 18 Nov 2026, noon in Thailand.
	var t := thai(2026, 11, 18)
	DailyPass.test_time = t
	_roll(t)
	_events(t)
	_claim(t)
	_weekly(t)
	_pass(t)
	_resets(t)
	_save(t)
	await _ui(t)
	DailyPass.test_time = -1.0
	print("DAILY PASS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero(hero_name := "Pass QA", level := 60) -> void:
	Game.new_profile(&"warrior", hero_name, FaceKit.default_look())
	Game.profile.level = level
	Game.current_zone = &"meadow"


## Today's list with the given template ids (to test each kind on purpose).
func _force(scope: String, ids: Array) -> void:
	var s := DailyPass.state()
	s[scope] = DailyPass._entries(ids, int(Game.profile.level))


func _entry(scope: String, id: String) -> Dictionary:
	for e in DailyPass.state()[scope]:
		if e.id == id:
			return e
	return {}


func _roll(t: float) -> void:
	_hero()
	var s := DailyPass.state(t)
	check((s.dq as Array).size() == DailyPass.DAILY_COUNT, "five daily quests (%d)" % (s.dq as Array).size())
	check((s.wq as Array).size() == DailyPass.WEEKLY_COUNT, "three weekly quests")
	var kinds := {}
	for e in s.dq:
		var row := DailyPass.template(e.id)
		kinds[row.kind] = true
		check(not row.is_empty() and int(e.t) >= 1 and int(e.p) == 0 and not bool(e.c), "a real daily quest: %s" % e.id)
		check(not bool(row.get("guild", false)), "no guild quest without a guild: %s" % e.id)
	check(kinds.size() == DailyPass.DAILY_COUNT, "five different kinds")
	var day := DailyPass.day_of(t)
	var a := DailyPass.roll("d", "Pass QA|warrior", day, 60, false)
	check(a == DailyPass.roll("d", "Pass QA|warrior", day, 60, false), "the same draw for the same character and day")
	var ids: Array = []
	for e in s.dq:
		ids.append(e.id)
	check(ids == a, "the profile's quests are that draw")
	# Drawn again from scratch (another device): the same five.
	Game.profile.erase(DailyPass.KEY)
	var again: Array = []
	for e in DailyPass.state(t).dq:
		again.append(e.id)
	check(again == ids, "a fresh draw the same day is the same")
	var varied := false
	for d in range(1, 8):
		varied = varied or DailyPass.roll("d", "Pass QA|warrior", day + d, 60, false) != a
	check(varied, "the quests change from day to day")
	var other := false
	for n in 6:
		other = other or DailyPass.roll("d", "Other %d|warrior" % n, day, 60, false) != a
	check(other, "another character draws its own")
	check(DailyPass.target_for(DailyPass.template("d_kills"), 100) > DailyPass.target_for(DailyPass.template("d_kills"), 10), "kill targets scale with the level")
	var low := DailyPass.roll("d", "Pass QA|warrior", day, 1, false)
	check(not low.has("d_enhance") and not low.has("d_raid"), "nothing above the level at Lv.1")
	var guild_seen := false
	for d in 30:
		for id in DailyPass.roll("d", "Pass QA|warrior", day + d, 60, true) + DailyPass.roll("w", "Pass QA|warrior", day + d, 60, true):
			guild_seen = guild_seen or id in ["d_guild_war", "d_league", "w_guild_war", "w_league"]
	check(guild_seen, "guild members also get guild war / league quests")


func _events(t: float) -> void:
	_hero()
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_enhance", "d_chat"])
	_force("wq", ["w_world_boss", "w_party", "w_guild_war"])
	# Kills and bosses through the real kill report.
	var target := int(_entry("dq", "d_kills").t)
	for k in target - 1:
		Game.report_kill(&"slime")
	check(int(_entry("dq", "d_kills").p) == target - 1, "kills count (%d/%d)" % [int(_entry("dq", "d_kills").p), target])
	Game.report_kill(&"slime", true)
	check(int(_entry("dq", "d_kills").p) == target, "the last kill finishes the quest")
	check(int(_entry("dq", "d_boss").p) == 1, "a boss kill counts for the boss quest")
	Game.report_kill(&"slime")
	check(int(_entry("dq", "d_kills").p) == target, "progress stops at the target")
	# Trading: buying from a shop and selling to it.
	Game.profile.gold = 100000
	Game.buy_item(ItemData.potion("hp_s", 1))
	var i: int = Game.profile.inv.size() - 1
	Game.sell_item(i)
	check(int(_entry("dq", "d_trade").p) == 2, "a buy and a sale count as trades (%d)" % int(_entry("dq", "d_trade").p))
	# Enhancing: one forge attempt, success or not.
	for id in ["purple", "pink", "chaos"]:
		Game.add_item(ItemData.jewel(id, 200))
	var result := Game.enhance_item(Game.profile.equip.weapon)
	check(result in ["ok", "fail"], "the forge ran (%s)" % result)
	check(int(_entry("dq", "d_enhance").p) == 1, "an enhance attempt counts")
	# Chat: the hero's own line counts, someone else's does not.
	Game.world_chat.emit("Someone", "hi", Color.WHITE)
	check(int(_entry("dq", "d_chat").p) == 0, "another player's line does not count")
	Game.world_chat.emit(String(Game.profile.name), "สวัสดี", Color.WHITE)
	Game.channel_chat.emit("party", String(Game.profile.name), "ไปกัน", Color.WHITE)
	check(int(_entry("dq", "d_chat").p) == 2, "the hero's chat lines count")
	# World boss, guild war, party minutes (weekly list).
	Game.world_boss_defeated.emit(&"meadow")
	check(int(_entry("wq", "w_world_boss").p) == 1, "the world boss counts")
	# The guild league (GuildLeague.war_finished) reports each finished war once.
	Game.guildwar_finish(true, 10, 5, 3, 1, "A", "B")
	check(int(_entry("wq", "w_guild_war").p) == 0, "guildwar_finish itself does not count (the league reports it)")
	Game.daily_progress("guild_war", 1)
	check(int(_entry("wq", "w_guild_war").p) == 1, "a finished guild war counts")
	Game.daily_progress("raid")
	Game.daily_progress("league", 5)
	Game.daily_progress("nonsense", 3)
	check(int(_entry("wq", "w_guild_war").p) == 1, "other kinds leave it alone")
	DailyPass.tick(120.0)
	check(int(_entry("wq", "w_party").p) == 0, "no party minutes alone")
	var joined := false
	for w in WorldPlayers.size():
		if Game.party_invite(w, true) == "":
			joined = true
			break
	check(joined, "a world player joined the party")
	DailyPass.tick(30.0)
	DailyPass.tick(31.0)
	DailyPass.tick(60.0)
	check(int(_entry("wq", "w_party").p) == 2, "hunting in a party counts minutes (%d)" % int(_entry("wq", "w_party").p))
	Game.dismiss_party()
	# Stall sale (PlayerStall).
	_force("dq", ["d_stall"])
	Game.add_item(ItemData.potion("hp_l", 5))
	var bag: int = Game.profile.inv.size() - 1
	for k in Game.profile.inv.size():
		if Game.profile.inv[k].get("id", "") == "hp_l":
			bag = k
	var lot := PlayerStall.list_item(bag, PlayerStall.fair_price(Game.profile.inv[bag]), 0)
	check(lot > 0, "a lot is on the stall")
	PlayerStall.sell(lot, "Buyer")
	check(int(_entry("dq", "d_stall").p) == 1, "a stall sale counts")
	# The town board's quests still move with the same call.
	check(Game.daily().quests.size() == 3, "the town board keeps its three quests")


func _claim(t: float) -> void:
	_hero()
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_chat", "d_gold"])
	var s := DailyPass.state()
	check(DailyPass.claim_quest("d", 1) == "ภารกิจยังไม่สำเร็จ", "an open quest cannot be claimed")
	check(DailyPass.claimable() == 0, "nothing claimable yet")
	Game.daily_progress("boss")
	check(DailyPass.claimable() == 1, "one claimable after finishing")
	var gold := int(Game.profile.gold)
	var exp_before := int(Game.profile.exp) + int(Game.profile.level) * 1000000
	check(DailyPass.claim_quest("d", 1) == "ok", "a finished quest is claimed")
	check(int(s.pts) == DailyPass.DAILY_POINTS, "daily points (%d)" % int(s.pts))
	check(int(Game.profile.gold) == gold + DailyPass.quest_gold(60, false), "the quest's gold")
	check(int(Game.profile.exp) + int(Game.profile.level) * 1000000 > exp_before, "the quest's EXP")
	check(DailyPass.claim_quest("d", 1) == "รับรางวัลภารกิจนี้ไปแล้ว" and int(s.pts) == DailyPass.DAILY_POINTS, "claimed only once")
	Game.daily_progress("boss")
	check(int(s.dq[1].p) == int(s.dq[1].t), "a claimed quest takes no more progress")
	check(DailyPass.claim_quest("x", 9) != "ok", "a wrong quest is refused")


func _weekly(t: float) -> void:
	_hero()
	_force("wq", ["w_boss", "w_dailies", "w_golden"])
	var s := DailyPass.state()
	Game.daily_progress("boss", 100)
	check(int(_entry("wq", "w_boss").p) == int(_entry("wq", "w_boss").t), "a weekly quest fills up")
	check(DailyPass.claim_quest("w", 0) == "ok" and int(s.pts) == DailyPass.WEEKLY_POINTS, "weekly points (%d)" % int(s.pts))
	check(int(Game.profile.gold) >= DailyPass.quest_gold(60, true), "weekly gold")
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_chat", "d_gold"])
	Game.daily_progress("boss")
	DailyPass.claim_quest("d", 1)
	check(int(_entry("wq", "w_dailies").p) == 1, "claiming a daily counts for the weekly 'dailies' quest")
	# Monday: a new week, a new draw; Sunday night still the old one.
	var sunday := thai(2026, 11, 22, 23)
	DailyPass.state(sunday)
	check(int(_entry("wq", "w_boss").c) == 1, "Sunday night keeps the week")
	var monday := thai(2026, 11, 23, 0) + 60.0
	check(DailyPass.week_of(monday) == DailyPass.week_of(t) + 1, "the week turns on Monday")
	DailyPass.state(monday)
	var fresh := true
	for e in DailyPass.state(monday).wq:
		fresh = fresh and int(e.p) == 0 and not bool(e.c)
	check(fresh, "a new week starts the weekly quests over")
	check(DailyPass.week_end(t) == thai(2026, 11, 23, 0), "the week ends at Monday midnight Thai time")


func _pass(t: float) -> void:
	_hero()
	var s := DailyPass.state(t)
	check(DailyPass.claim_tier(1, t) == "แต้มบัตรยังไม่ถึงขั้นนี้", "tier 1 needs points")
	s["pts"] = DailyPass.TIER_POINTS * 3 + 10
	check(DailyPass.tiers_reached(int(s.pts)) == 3, "three tiers reached")
	var gold := int(Game.profile.gold)
	check(DailyPass.claim_tier(1, t) == "ok" and int(Game.profile.gold) == gold + DailyPass.gold_unit(Game.profile), "tier 1 pays gold")
	check(DailyPass.claim_tier(1, t) != "ok", "a tier is claimed once")
	check(DailyPass.claim_tier(4, t) != "ok", "tier 4 is not reached")
	check(DailyPass.claimable(t) == 2, "two tiers left to claim")
	check(DailyPass.claim_all(t) == 2 and DailyPass.claimable(t) == 0, "รับทั้งหมด claims the rest")
	check(Game.potion_count(DailyPass.potion_id(60)) >= 10 and Game.jewel_count("purple") >= 2, "potions and jewels in the bag")
	# Every reward is real.
	for tier in range(1, DailyPass.TIERS + 1):
		var r := DailyPass.tier_reward(tier, Game.profile)
		check(int(r.gold) > 0 or not (r.items as Array).is_empty(), "tier %d pays something" % tier)
		for item in r.items:
			check(Game._valid_item(item), "tier %d item is valid" % tier)
	var cores := 0
	for tier in range(1, DailyPass.TIERS + 1):
		var row: Dictionary = DailyPass.REWARDS[tier - 1]
		if row.has("jewel") and row.jewel[0] == "set_core":
			cores += 1
	check(cores >= 3, "set cores at the big tiers")
	# The whole track: the top tier's title.
	s["pts"] = DailyPass.TIERS * DailyPass.TIER_POINTS + 999
	DailyPass.claim_all(t)
	check(int(s.got) == (1 << DailyPass.TIERS) - 1, "every tier claimed")
	check(Game.jewel_count("set_core") >= 4 and Game.jewel_count("feather") >= 6, "set cores and feathers")
	check(Achievements.is_earned(DailyPass.TITLE_ID, Game.profile), "the top tier's title is earned")
	check(Game.set_title(Achievements.index_of(DailyPass.TITLE_ID)) and Achievements.title_of(Game.profile) == "นักสะสมแต้ม", "and can be worn")
	# Points stop at the top.
	var cap := {"pts": DailyPass.TIERS * DailyPass.TIER_POINTS - 5}
	DailyPass._add_points(cap, 100)
	check(int(cap.pts) == DailyPass.TIERS * DailyPass.TIER_POINTS, "points stop at the last tier")


func _resets(t: float) -> void:
	_hero()
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_chat", "d_gold"])
	Game.daily_progress("boss")
	var s := DailyPass.state(t)
	s["pts"] = DailyPass.TIER_POINTS * 5
	var day_ids: Array = []
	for e in s.dq:
		day_ids.append(e.id)
	# 23:59 the same day: nothing changes; after Thai midnight: a new draw.
	DailyPass.state(thai(2026, 11, 18, 23) + 3599.0)
	check(int(_entry("dq", "d_boss").p) == 1, "the day lasts until Thai midnight")
	check(DailyPass.day_end(t) == thai(2026, 11, 19, 0), "the day ends at Thai midnight")
	var next := thai(2026, 11, 19, 0) + 1.0
	DailyPass.state(next)
	var ids: Array = []
	var clean := true
	for e in DailyPass.state(next).dq:
		ids.append(e.id)
		clean = clean and int(e.p) == 0 and not bool(e.c)
	check(clean and ids == DailyPass.roll("d", "Pass QA|warrior", DailyPass.day_of(next), 60, false), "a new day draws new quests")
	check(int(DailyPass.state(next).pts) == DailyPass.TIER_POINTS * 5, "the pass keeps its points over days")
	# The month: a warning three days before the end, once; then everything starts over.
	DailyPass.test_time = thai(2026, 11, 20)
	check(DailyPass.check(thai(2026, 11, 20)) == "", "no warning early in the month")
	var late := thai(2026, 11, 29)
	var text := DailyPass.check(late)
	check(text.contains("รีเซ็ต") and text.contains("5 ขั้น"), "a warning near the end: %s" % text)
	check(DailyPass.check(late + 3600.0) == "", "the warning comes once")
	check(DailyPass.month_end(late) == thai(2026, 12, 1, 0), "the month ends at Thai midnight on the 1st")
	var december := thai(2026, 12, 1, 0) + 1.0
	var d := DailyPass.state(december)
	check(int(d.pts) == 0 and int(d.got) == 0, "a new month starts the pass over")
	check(DailyPass.month_of(thai(2026, 12, 31, 23)) + 1 == DailyPass.month_of(thai(2027, 1, 1, 1)), "December rolls into January")
	check(DailyPass.month_end(thai(2026, 12, 15)) == thai(2027, 1, 1, 0), "December ends on 1 Jan")
	# 1 Dec 06:00 Thai is still 30 Nov in UTC: the Thai calendar decides.
	check(DailyPass.month_of(thai(2026, 12, 1, 3)) == DailyPass.month_of(december), "Thai time, not UTC")
	DailyPass.test_time = t


func _save(t: float) -> void:
	_hero()
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save without the pass is valid")
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_chat", "d_gold"])
	Game.daily_progress("boss")
	Game.daily_progress("kills", 3)
	DailyPass.claim_quest("d", 1)
	var s := DailyPass.state()
	s["pts"] = int(s.pts) + DailyPass.TIER_POINTS * 2
	DailyPass.claim_tier(1)
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with the pass is valid")
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(json), "the JSON copy is valid")
	var repaired: Dictionary = Game._repair(json)
	check(Game._valid_profile(repaired) and repaired[DailyPass.KEY].pts is int and repaired[DailyPass.KEY].dq[0].p is int, "_repair brings the ints back")
	check(JSON.stringify(repaired[DailyPass.KEY]) == JSON.stringify(Game.profile[DailyPass.KEY]), "nothing lost in the round trip")
	for bad in [[], {"pts": "x"}, {"got": -1}, {"dq": {}}, {"dq": [{"id": 5}]}, {"dq": [{"id": "d_kills", "p": 1.5}]}, {"wq": [{"id": "w_boss", "c": "yes"}]}, {"zzz": 1}, {"got": 1 << 40}]:
		var copy := Game.profile.duplicate(true)
		copy[DailyPass.KEY] = bad
		check(not Game._valid_profile(copy), "a broken pass is refused: %s" % JSON.stringify(bad))
	var unknown := Game.profile.duplicate(true)
	unknown[DailyPass.KEY]["dq"][0]["id"] = "d_retired"
	check(Game._valid_profile(unknown), "an unknown quest id is not fatal")
	var fixed: Dictionary = Game._repair(unknown)
	check(not fixed[DailyPass.KEY].has("dq") and Game._valid_profile(fixed), "repair drops a list it does not know")
	Game.profile = fixed
	check((DailyPass.state().dq as Array).size() == DailyPass.DAILY_COUNT, "and the day is drawn again")
	# Save to disk and load back.
	_hero("Pass Save QA")
	Game.daily_progress("kills", 2)
	var before := JSON.stringify(DailyPass.state())
	check(Game.save(), "saved")
	check(Game.load_game(), "loaded")
	check(JSON.stringify(DailyPass.state()) == before, "the pass survives save and load")
	check(Game._valid_profile(Game.profile.duplicate(true)), "the loaded save is valid")


func _ui(t: float) -> void:
	_hero("Pass UI QA")
	_force("dq", ["d_kills", "d_boss", "d_trade", "d_chat", "d_gold"])
	Game.daily_progress("boss")
	var holder := Control.new()
	holder.size = Vector2(1100, 640)
	add_child(holder)
	var scroll := DailyPassView.build(holder, func(): pass)
	await get_tree().process_frame
	var all := scroll.find_child("ClaimAll", true, false) as Button
	check(all != null and not all.disabled, "รับทั้งหมด is on")
	var labels := 0
	for node in scroll.find_children("*", "Label", true, false):
		var text := (node as Label).text
		if text.contains("ขั้น") or text.contains("ภารกิจ"):
			labels += 1
	check(labels >= DailyPass.TIERS, "the page lists the quests and the tiers (%d)" % labels)
	holder.queue_free()
	check(GameMenu.TABS.any(func(tab): return tab[0] == "pass" and tab[1] == "ภารกิจ & บัตร"), "the menu has the tab")
	var menu := GameMenu.new()
	add_child(menu)
	await get_tree().process_frame
	menu.open_menu(&"pass")
	await get_tree().process_frame
	var tab: Button = menu._tab_buttons[&"pass"]
	check(tab.text.ends_with("●"), "the tab shows a red dot: %s" % tab.text)
	check(menu._content.find_child("ClaimAll", true, false) != null, "the tab shows the page")
	DailyPass.claim_all()
	menu._rebuild()
	check(not tab.text.ends_with("●"), "no dot once everything is claimed")
	menu.close_menu()
	menu.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
