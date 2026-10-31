extends Node
## Halloween event (WorldEvents.halloween_on): until Thai midnight starting 1 Nov 2026
## every field monster may drop a Halloween potion (5%); drinking one gives EXP x2 or
## x3 for an hour of real time, which keeps running while the game is closed.
##   godot --headless --path . res://tests/integration/halloween_test.tscn
var failures := 0
var checks := 0


class DropZone:
	extends Zone
	var potions := 0
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if item.get("kind", "") == "potion" and item.id == "halloween":
			potions += 1


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Unix time of a Thai-time moment.
func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


## Moves the game clock to Thai time `at`.
func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Halloween QA")
	ZoneData.ensure()
	# The window: on until 1 Nov 00:00 Thai, off from then on.
	check(WorldEvents.halloween_on(thai(2026, 10, 30, 22)), "Halloween is on 30 Oct")
	check(WorldEvents.halloween_on(thai(2026, 10, 31, 23, 59)), "still on 31 Oct 23:59")
	check(not WorldEvents.halloween_on(thai(2026, 11, 1, 0)), "over at 1 Nov 00:00 Thai")
	check(WorldEvents.halloween_text(thai(2026, 11, 2, 12)) == "", "no HUD line after the event")
	check(WorldEvents.halloween_text(thai(2026, 10, 31, 23)).contains("5%"), "HUD line during the event")
	# Drops: about 5% of kills in a field during the event, none after it.
	for when in [thai(2026, 10, 31, 10), thai(2026, 11, 1, 10)]:
		at(when)
		var zone := DropZone.new()
		zone.zone_id = &"meadow"
		zone.data = ZoneData.get_zone(&"meadow")
		zone._event_rng.seed = 77
		for i in 4000:
			zone._drop_jewels(Vector3.ZERO)
		if WorldEvents.halloween_on(when):
			check(zone.potions > 140 and zone.potions < 260, "about 5%% of kills drop a Halloween potion (%d / 4000)" % zone.potions)
		else:
			check(zone.potions == 0, "no Halloween potions after the event")
		zone.free()
	check(not ItemData.POTIONS.halloween.has("hp") and not ItemData.POTIONS.halloween.has("mp"), "the potion heals nothing (never used as a quick potion)")
	check(ItemLook.icon(ItemData.potion("halloween")) != null, "the potion has its own icon")
	# Drinking: x2 or x3 for one hour of real time.
	var start := thai(2026, 10, 31, 20)
	at(start)
	Game.profile.inv = [ItemData.potion("halloween", 2)]
	check(Game.exp_boost_mult() == 1.0 and Game.exp_boost_text() == "", "no boost before drinking")
	var atk_before := float(Game.stats_now().atk)
	check(Game.boost_drop() == 0.0, "no extra drop chance before drinking")
	check(Game.use_potion_at(0) == "halloween", "drinking the potion")
	check(is_equal_approx(float(Game.stats_now().atk), atk_before * (1.0 + Game.BOOST_ATK)), "the potion gives +10% attack")
	check(is_equal_approx(Game.boost_drop(), 0.1), "the potion gives +10% drop chance")
	var mult := Game.exp_boost_mult()
	check(mult == 2.0 or mult == 3.0, "EXP x2 or x3 (x%d)" % int(mult))
	check(Game.potion_count("halloween") == 1, "one potion used up")
	check(Game.exp_boost_text().contains("60 นาที"), "HUD shows 60 minutes left: " + Game.exp_boost_text())
	# A second one while the first runs is refused and kept.
	check(Game.use_potion_at(0) == "" and Game.potion_count("halloween") == 1, "a second potion waits until the first runs out")
	# EXP: the potion stacks on top of the evening EXP x2 (20:00 is inside it).
	Game.profile.level = 30
	Game.profile.exp = 0
	Game.add_exp(100)
	check(Game.profile.exp == int(100 * 2 * mult), "EXP x2 evening x potion x%d = %d" % [int(mult), Game.profile.exp])
	# Real time: closed at 20:30 (saved flags only), back at 20:59 and 21:00.
	var saved: Dictionary = Game.profile.flags.duplicate()
	check(Game._valid_profile(Game.profile), "the boost saves in a valid profile")
	at(start + 59 * 60)
	Game.profile.flags = saved
	check(Game.exp_boost_mult() == mult and Game.exp_boost_text().contains("1 นาที"), "back at 20:59: one minute left")
	at(start + 3600)
	check(Game.exp_boost_mult() == 1.0 and Game.exp_boost_text() == "", "at 21:00 the boost has run out even though the game was closed")
	check(is_equal_approx(float(Game.stats_now().atk), float(HeroStats.compute(Game.profile).atk)) and Game.boost_drop() == 0.0, "attack and drop bonus end with it")
	at(thai(2026, 10, 31, 22))
	Game.profile.exp = 0
	Game.add_exp(100)
	check(Game.profile.exp == 100, "no boost after it ends")
	check(Game.use_potion_at(0) == "halloween" and Game.exp_boost_mult() > 1.0, "the next potion works once the first ran out")
	# World players drink potions too: some hours online under x2 / x3, and the event
	# adds to their progress (and only from its start).
	var boosted := 0
	var online_hours := 0
	var start_hw := float(WorldEvents.HALLOWEEN_START)
	for i in WorldPlayers.size():
		for h in 48:
			var t := start_hw + 3600.0 * h + 600.0
			if not WorldPlayers.session_at(i, t).is_empty():
				online_hours += 1
				var m := WorldPlayers.halloween_mult(i, t)
				check(m == 1 or m == 2 or m == 3, "a world player's potion is x2 or x3")
				if m > 1:
					boosted += 1
	check(online_hours > 0 and boosted > online_hours * WorldPlayers.HALLOWEEN_SHARE_MIN * 0.8 and boosted < online_hours * WorldPlayers.HALLOWEEN_SHARE_MAX * 1.2, "world players are under a potion for part of their play (%d of %d hours)" % [boosted, online_hours])
	check(WorldPlayers.halloween_mult(0, start_hw - 3600.0) == 1, "no world player potion before the event")
	var gained := 0.0
	for i in WorldPlayers.size():
		check(WorldPlayers.halloween_work(i, start_hw) == 0.0, "nothing added at the event's start")
		gained += WorldPlayers.halloween_work(i, float(WorldEvents.HALLOWEEN_END) + 86400.0)
	check(gained > 0.0, "the potions add to the world players' progress")
	# The pumpkin: a head-sized jack-o'-lantern floating over a boosted character.
	var visual := HeroVisual.new()
	add_child(visual)
	visual.setup(&"warrior")
	visual.set_pumpkin(true)
	check(visual.has_pumpkin() and visual.find_child("PumpkinHead", true, false) != null, "a boosted character wears the floating pumpkin")
	visual.set_pumpkin(true)
	check(visual.find_children("PumpkinHead", "", true, false).size() == 1, "asking again keeps one pumpkin")
	visual.set_pumpkin(false)
	await get_tree().process_frame
	check(not visual.has_pumpkin() and visual.find_child("PumpkinHead", true, false) == null, "the pumpkin goes when the potion ends")
	visual.queue_free()
	WorldPresence.clock_offset = 0.0
	print("HALLOWEEN: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
