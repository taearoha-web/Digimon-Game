extends Node
## Guild daily quests and the guild points shop (GuildQuestData, Game.guild_quests):
## nothing without a guild; three quests a Thai day drawn from the guild and the day
## alone; the hero's kills, field bosses, forge successes, guild-war wins and jewel
## pickups count; the guild mates add their share by the minutes they played today
## (capped, so the hero always has a part); a finished quest is claimed once for guild
## points and gold; the points buy jewels and potions; a new day starts over; the save
## stays valid (flags are ints) and an old save loads; the registrar shows it all.
##   godot --headless --path . res://tests/integration/guild_quest_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func pin(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	WorldPlayers.clear_bonus()
	# Twenty days in at 13:00 Thai time: both guilds have members at Lv.100.
	var t := float(WorldPlayers.START_UNIX) + 20.0 * 86400.0 + 13.0 * 3600.0
	pin(t)
	_no_guild()
	_draw(t)
	_progress(t)
	_claim_and_shop(t)
	_rollover(t)
	_mates(t)
	_save(t)
	await _screen(t)
	print("GUILD QUEST: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _hero() -> void:
	Game.new_profile(&"warrior", "Guild Quest QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4


func _no_guild() -> void:
	_hero()
	check(Game.guild() == 0 and Game.guild_quests().is_empty(), "no guild quests without a guild")
	Game.guild_quest_progress("kills", 5)
	check(not Game.profile.flags.has("gq_kills"), "work outside a guild is not counted")
	check(Game.guild_quest_claim(0) != "ok", "nothing to claim without a guild")
	Game.profile.flags[GuildQuestData.POINTS_FLAG] = 999
	check(Game.guild_shop_buy("chaos") != "ok", "the shop is for guild members")


func _draw(t: float) -> void:
	_hero()
	Game.join_guild(WorldPlayers.ALPHA)
	var day := WorldEvents.day_of(t)
	var a := GuildQuestData.quests_for(WorldPlayers.ALPHA, day)
	check(a.size() == 3, "three quests a day (%d)" % a.size())
	check(a == GuildQuestData.quests_for(WorldPlayers.ALPHA, day), "the same draw for the same guild and day")
	var kinds := {}
	for q in a:
		kinds[q.kind] = true
		check(int(q.target) > 0 and int(q.points) > 0 and int(q.gold) > 0 and String(q.name).contains(str(int(q.target))), "a real quest: %s" % q.name)
	check(kinds.size() == 3, "three different quests")
	var varied := false
	for d in range(1, 8):
		varied = varied or GuildQuestData.quests_for(WorldPlayers.ALPHA, day + d) != a
	check(varied, "the quests change from day to day")
	var no_war := true
	for d in 20:
		for q in GuildQuestData.quests_for(WorldPlayers.ALPHA, day + d, false):
			no_war = no_war and String(q.kind) != "war"
	check(no_war, "no guild-war quest while the other guild has nobody to fight")
	var listed := Game.guild_quests(t)
	check(listed.size() == 3, "the hero sees three guild quests")
	for k in mini(3, listed.size()):
		check(String(listed[k].kind) == String(a[k].kind) and int(listed[k].target) == int(a[k].target), "the hero's quest %d is the guild's draw" % k)


## A moment (13:00 Thai time) of a day whose draw holds `kind`.
func _day_with(kind: String, from_t: float) -> float:
	var t := from_t
	for d in 60:
		for q in GuildQuestData.quests_for(WorldPlayers.ALPHA, WorldEvents.day_of(t)):
			if String(q.kind) == kind:
				return t
		t += 86400.0
	return -1.0


func _quest(kind: String, t: float) -> Dictionary:
	for q in Game.guild_quests(t):
		if String(q.kind) == kind:
			return q
	return {}


func _progress(t0: float) -> void:
	for kind in ["kills", "boss", "enhance", "war", "jewels"]:
		var t := _day_with(kind, t0)
		check(t > 0.0, "some day has the %s quest" % kind)
		if t < 0.0:
			continue
		pin(t)
		_hero()
		Game.join_guild(WorldPlayers.ALPHA)
		var before := _quest(kind, t)
		match kind:
			"kills":
				for k in 7:
					Game.report_kill(&"slime")
			"boss":
				Game.report_kill(&"slime", true)
				Game.report_kill(&"slime", true)
			"enhance":
				var item := ItemData.generate(50, &"warrior", Game.rng, 1, "weapon")
				Game.add_item(item)
				Game.add_item(ItemData.jewel("purple", 5))
				var wins := 0
				for k in 5:
					wins += 1 if Game.enhance_item(item) == "ok" else 0
				check(wins == 5 and int(Game.profile.flags.get("gq_enhance", 0)) == 5, "every forge success counts (%d)" % wins)
			"war":
				Game.guildwar_finish(false, 1, 3, 0, 1, "Alpha", "Neverdie")
				check(int(Game.profile.flags.get("gq_war", 0)) == 0, "a lost war does not count")
				Game.guildwar_finish(true, 3, 1, 2, 0, "Alpha", "Neverdie")
			"jewels":
				Game.guild_quest_progress("jewels", 3)
		var after := _quest(kind, t)
		var want: int = {"kills": 7, "boss": 2, "enhance": 5, "war": 1, "jewels": 3}[kind]
		check(int(after.hero) == int(before.hero) + want, "%s: the hero's work counts (%d -> %d)" % [kind, int(before.hero), int(after.hero)])
		check(int(after.progress) == mini(int(after.hero) + int(after.mates), int(after.target)), "%s: progress is the hero's plus the guild's" % kind)
	# Jewels picked up in the field count through the loot drop.
	pin(_day_with("jewels", t0))
	_hero()
	Game.join_guild(WorldPlayers.ALPHA)
	var ground := Node3D.new()
	add_child(ground)
	var drop := LootDrop.new()
	drop.item = ItemData.jewel("pink", 2)
	drop.gold = 0
	ground.add_child(drop)
	drop.call("_collect")
	check(int(Game.profile.flags.get("gq_jewels", 0)) == 2, "a jewel pickup counts its jewels (%d)" % int(Game.profile.flags.get("gq_jewels", 0)))


func _claim_and_shop(t0: float) -> void:
	var t := _day_with("kills", t0)
	pin(t)
	_hero()
	Game.join_guild(WorldPlayers.ALPHA)
	var q := _quest("kills", t)
	check(not bool(q.done), "not finished without the hero")
	check(Game.guild_quest_claim(int(q.slot)) != "ok", "an unfinished quest is not paid")
	check(int(q.mates) <= int(floor(float(q.target) * GuildQuestData.MATE_CAP)), "the guild's share is capped")
	var need := int(q.target) - int(q.mates)
	var toasts: Array = []
	var listen := func(text: String, _kind: StringName): toasts.append(text)
	Game.toast.connect(listen)
	for k in need:
		Game.report_kill(&"slime")
	Game.toast.disconnect(listen)
	q = _quest("kills", t)
	check(bool(q.done) and not bool(q.claimed), "the kills finish the quest")
	var announced := toasts.filter(func(s): return String(s).contains("ภารกิจกิลด์")).size()
	check(announced == 1, "one toast when it finishes (%d)" % announced)
	var gold := int(Game.profile.gold)
	check(Game.guild_quest_claim(int(q.slot)) == "ok", "a finished quest is claimed")
	check(Game.guild_points() == int(q.points) and int(Game.profile.gold) == gold + int(q.gold), "claiming pays guild points and gold")
	check(Game.guild_quest_claim(int(q.slot)) != "ok" and Game.guild_points() == int(q.points), "a quest is claimed once")
	check(bool(_quest("kills", t).claimed), "it shows as claimed")
	# The shop.
	check(Game.guild_shop_buy("feather") != "ok" and Game.guild_points() == int(q.points), "no feather without the points")
	Game.profile.flags[GuildQuestData.POINTS_FLAG] = 1000
	var spent := 0
	for e in GuildQuestData.SHOP:
		var jewel := String(e.kind) == "jewel"
		var have := Game.jewel_count(String(e.item)) if jewel else Game.potion_count(String(e.item))
		check(Game.guild_shop_buy(String(e.id)) == "ok", "buys %s" % GuildQuestData.shop_name(e))
		spent += int(e.price)
		var now := Game.jewel_count(String(e.item)) if jewel else Game.potion_count(String(e.item))
		check(now == have + int(e.count), "%s: %d more in the bag" % [GuildQuestData.shop_name(e), int(e.count)])
	check(Game.guild_points() == 1000 - spent, "the points are spent (%d left)" % Game.guild_points())
	check(Game.guild_shop_buy("nothing") != "ok", "no unknown goods")
	# Balance: a day of quests buys a chaos jewel in 1-2 days and a feather in about 5.
	var per_day := 0.0
	for d in 30:
		for g in GuildQuestData.quests_for(WorldPlayers.ALPHA, WorldEvents.day_of(t0) + d):
			per_day += float(g.points) / 30.0
	var chaos := float(GuildQuestData.shop_entry("chaos").price) / per_day
	var feather := float(GuildQuestData.shop_entry("feather").price) / per_day
	check(chaos >= 1.0 and chaos <= 2.0, "a chaos jewel takes 1-2 days of quests (%.1f)" % chaos)
	check(feather >= 4.0 and feather <= 6.0, "a feather takes about 5 days (%.1f)" % feather)


func _rollover(t0: float) -> void:
	var t := _day_with("kills", t0)
	pin(t)
	_hero()
	Game.join_guild(WorldPlayers.ALPHA)
	Game.profile.flags[GuildQuestData.POINTS_FLAG] = 40
	Game.report_kill(&"slime")
	var q := _quest("kills", t)
	Game.profile.flags["gq_c%d" % int(q.slot)] = 1
	check(int(_quest("kills", t).hero) >= 1 and bool(_quest("kills", t).claimed), "today's work and claim are kept")
	var next := t + 86400.0
	pin(next)
	var fresh := Game.guild_quests(next)
	var clean := fresh.size() == 3
	for f in fresh:
		clean = clean and int(f.hero) == 0 and not bool(f.claimed)
	check(clean, "a new Thai day starts the quests over")
	check(int(Game.profile.flags.get(GuildQuestData.DAY_FLAG, 0)) == WorldEvents.day_of(next), "the day key moves on")
	check(Game.guild_points() == 40, "the guild points stay")


func _mates(t0: float) -> void:
	# Over a day the guild's share grows (never shrinks) while the members play.
	var day := WorldEvents.day_of(t0)
	var start := GuildQuestData.day_start(day)
	var last := -1.0
	var grows := true
	var moved := false
	var online_seen := false
	for h in range(0, 24, 2):
		var at := start + float(h) * 3600.0 + 60.0
		var m := GuildQuestData.mate_minutes(WorldPlayers.ALPHA, at)
		grows = grows and float(m.minutes) >= last
		moved = moved or (last >= 0.0 and float(m.minutes) > last)
		online_seen = online_seen or int(m.online) > 0
		last = float(m.minutes)
	check(grows and moved, "the guild's minutes grow while it plays (%.0f by night)" % last)
	check(online_seen, "guild members are online during the day")
	check(float(GuildQuestData.mate_minutes(WorldPlayers.ALPHA, start + 30.0).minutes) <= 60.0, "the share starts over at Thai midnight")
	check(GuildQuestData.mate_minutes(WorldPlayers.ALPHA, t0) == GuildQuestData.mate_minutes(WorldPlayers.ALPHA, t0), "the share is the same at the same moment")
	var kill_q := {"kind": "kills", "target": 300}
	var share := GuildQuestData.mate_share(WorldPlayers.ALPHA, kill_q, start + 23.0 * 3600.0)
	check(share > 0 and share <= 210, "the guild helps with the kills, at most 70%% (%d)" % share)
	check(GuildQuestData.mate_share(WorldPlayers.ALPHA, {"kind": "war", "target": 1}, t0) == 0, "only the hero wins the guild war")
	# In the first six hours nobody is at Lv.100: the hero is alone.
	var opening := float(WorldPlayers.START_UNIX) + 0.25 * 86400.0
	check(int(GuildQuestData.mate_minutes(WorldPlayers.ALPHA, opening).members) == 0 and GuildQuestData.mate_share(WorldPlayers.ALPHA, kill_q, opening) == 0, "no guild mates, no share")


func _save(t: float) -> void:
	pin(t)
	_hero()
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save without guild quests is valid")
	Game.join_guild(WorldPlayers.NEVERDIE)
	Game.report_kill(&"slime", true)
	Game.guild_quest_progress("jewels", 4)
	Game.profile.flags[GuildQuestData.POINTS_FLAG] = 12
	Game.profile.flags["gq_c1"] = 1
	Game.guild_quests(t)
	for key in Game.profile.flags:
		if String(key).begins_with("gq_") or key == GuildQuestData.POINTS_FLAG:
			check(Game.profile.flags[key] is int, "%s is an int" % key)
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with guild quests is valid")
	var json: Variant = JSON.parse_string(JSON.stringify(Game.profile))
	check(json is Dictionary and Game._valid_profile(Game._repair(json)), "it survives the JSON round trip")
	# An old save (no guild quest flags at all) loads and starts at zero.
	var old: Dictionary = Game.profile.duplicate(true)
	for key in old.flags.keys():
		if String(key).begins_with("gq_") or key == GuildQuestData.POINTS_FLAG:
			old.flags.erase(key)
	check(Game._valid_profile(old), "an old save is valid")
	Game.profile = old
	check(Game.guild_points() == 0 and Game.guild_quests(t).size() == 3, "an old save starts with no points and today's quests")


func _screen(t: float) -> void:
	pin(t)
	_hero()
	var screen := GuildScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open_screen()
	await get_tree().process_frame
	check(screen.find_child("GuildQuests", true, false) == null, "no quest tab outside a guild")
	screen.close_screen()
	Game.join_guild(WorldPlayers.ALPHA)
	Game.profile.flags[GuildQuestData.POINTS_FLAG] = 60
	screen.open_roster()
	await get_tree().process_frame
	var tab := screen.find_child("GuildQuests", true, false) as Button
	check(tab != null, "a member sees the quest tab")
	if tab:
		tab.pressed.emit()
	await get_tree().process_frame
	check(GuildScreen.view == "quests" and screen.find_child("Quest0", true, false) != null and screen.find_child("Quest2", true, false) != null, "the tab shows three quest cards")
	var points := screen.find_child("GuildPoints", true, false) as Label
	check(points != null and points.text.contains("60"), "the balance is shown")
	var chaos := screen.find_child("Buy_chaos", true, false) as Button
	var feather := screen.find_child("Buy_feather", true, false) as Button
	check(chaos != null and not chaos.disabled and feather != null and feather.disabled, "only affordable goods can be bought")
	if chaos:
		var have := Game.jewel_count("chaos")
		chaos.pressed.emit()
		await get_tree().process_frame
		check(Game.jewel_count("chaos") == have + 1 and Game.guild_points() == 60 - int(GuildQuestData.shop_entry("chaos").price), "the buy button gives a chaos jewel")
	# Finish a quest and claim it from the screen.
	var q: Dictionary = Game.guild_quests(t)[0]
	Game.profile.flags["gq_" + String(q.kind)] = int(q.target)
	screen.open_quests()
	await get_tree().process_frame
	var claim := screen.find_child("Claim0", true, false) as Button
	check(claim != null and not claim.disabled, "a finished quest has a claim button")
	if claim:
		claim.pressed.emit()
		await get_tree().process_frame
		var again := screen.find_child("Claim0", true, false) as Button
		check(again != null and again.disabled and again.text == "รับแล้ว", "claimed from the screen")
	screen.close_screen()
	screen.queue_free()
	await get_tree().process_frame
