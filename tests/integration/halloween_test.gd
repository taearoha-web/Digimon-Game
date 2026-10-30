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
	check(Game.use_potion_at(0) == "halloween", "drinking the potion")
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
	at(thai(2026, 10, 31, 22))
	Game.profile.exp = 0
	Game.add_exp(100)
	check(Game.profile.exp == 100, "no boost after it ends")
	check(Game.use_potion_at(0) == "halloween" and Game.exp_boost_mult() > 1.0, "the next potion works once the first ran out")
	WorldPresence.clock_offset = 0.0
	print("HALLOWEEN: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
