extends Node
## The recurring events that follow Halloween (WorldEvents): the weekend jewel rush
## (forge jewels x2 all Saturday and Sunday, Thai time; feathers not) and the golden
## monster (มอนทองคำ: one 3-minute window every 15 minutes, read off the clock, in
## every levelling field, never in town or the guild war), its drops, the minimap dot
## and the HUD chip line.
##   godot --headless --path . res://tests/integration/weekend_events_test.tscn
var failures := 0
var checks := 0


class DropZone:
	extends Zone
	var jewels := {}
	func _spawn_loot(item: Dictionary, _gold: int, _from: Vector3) -> void:
		if item.get("kind", "") == "jewel":
			jewels[item.id] = int(jewels.get(item.id, 0)) + 1


## A zone that records its drops instead of putting them on the ground.
class LootZone:
	extends Zone
	var gold_piles: Array[int] = []
	var items: Array[Dictionary] = []
	func _spawn_loot(item: Dictionary, gold: int, _from: Vector3) -> void:
		if gold > 0:
			gold_piles.append(gold)
		if not item.is_empty():
			items.append(item)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Unix time of a Thai-time moment.
func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


## Moves the game clock to `t`.
func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Weekend QA")
	ZoneData.ensure()
	_jewel_rush()
	_hud()
	_schedule()
	await _golden()
	WorldPresence.clock_offset = 0.0
	print("WEEKEND EVENTS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _jewel_rush() -> void:
	# Saturday 7 and Sunday 8 Nov 2026 (after Halloween), the Friday and Monday round them.
	check(WorldEvents.jewel_multiplier(thai(2026, 11, 7, 0, 0)) == 2.0 and WorldEvents.jewel_multiplier(thai(2026, 11, 8, 23, 59)) == 2.0, "Saturday 00:00 to Sunday 23:59: jewels x2")
	check(WorldEvents.jewel_multiplier(thai(2026, 11, 6, 23, 59)) == 1.0 and WorldEvents.jewel_multiplier(thai(2026, 11, 9, 0, 0)) == 1.0, "Friday 23:59 and Monday 00:00: no rush")
	# Drops, same seed on a Wednesday and on a Saturday: purple / pink / chaos double.
	var counts := {}
	for when in [thai(2026, 11, 4, 10), thai(2026, 11, 7, 10)]:
		at(when)
		var zone := DropZone.new()
		zone.zone_id = &"meadow"
		zone.data = ZoneData.get_zone(&"meadow")
		zone.rng.seed = 4242
		for i in 30000:
			zone._drop_jewels(Vector3.ZERO)
		counts[WorldEvents.is_weekend(when)] = zone.jewels
		zone.free()
	var week: Dictionary = counts[false]
	var end: Dictionary = counts[true]
	for id in ItemData.JEWEL_DROP:
		var expect := 30000.0 * float(ItemData.JEWEL_DROP[id])
		var a := int(week.get(id, 0))
		var b := int(end.get(id, 0))
		check(a > expect * 0.7 and a < expect * 1.3, "weekday %s at its usual rate (%d, ~%d)" % [id, a, int(expect)])
		check(b > expect * 2.0 * 0.75 and b < expect * 2.0 * 1.25, "weekend %s doubled (%d, ~%d)" % [id, b, int(expect * 2.0)])
		check(b > a * 1.5, "more %s on the weekend (%d vs %d)" % [id, b, a])
	# Feathers: the same seed and the same number of rolls give the same feathers.
	var region := &""
	for id in StarProgression.REGIONS:
		if int(ZoneData.get_zone(id).get("star", 0)) >= ItemData.FEATHER_STARS:
			region = id
			break
	check(region != &"", "a feather field exists")
	var feathers := []
	for when in [thai(2026, 11, 4, 10), thai(2026, 11, 7, 10)]:
		at(when)
		var zone := DropZone.new()
		zone.zone_id = region
		zone.data = ZoneData.get_zone(region)
		zone.rng.seed = 99
		for i in 30000:
			zone._drop_jewels(Vector3.ZERO)
		feathers.append(int(zone.jewels.get("feather", 0)))
		zone.free()
	check(feathers[0] > 0 and feathers[0] == feathers[1], "feathers are not doubled (weekday %d, weekend %d)" % [feathers[0], feathers[1]])


func _hud() -> void:
	var sat := WorldEvents.weekend_text(thai(2026, 11, 7, 10))
	check(sat.begins_with(WorldEvents.NAME_WEEKEND_JEWEL) and sat.ends_with("38 ชม."), "Saturday 10:00: the rush, 38 hours left (%s)" % sat)
	var sun := WorldEvents.weekend_text(thai(2026, 11, 8, 23))
	check(sun.ends_with("60 นาที"), "Sunday 23:00: an hour left (%s)" % sun)
	check(WorldEvents.weekend_text(thai(2026, 11, 4, 10)) == "", "no rush line on a Wednesday")
	var lines := WorldEvents.chip_lines(thai(2026, 11, 7, 10))
	check(lines.size() == 2 and String(lines[0]) == WorldEvents.describe(thai(2026, 11, 7, 10)) and String(lines[1]) == sat, "Saturday chip: the event line and the rush (%s)" % str(lines))
	lines = WorldEvents.chip_lines(thai(2026, 11, 4, 10))
	check(lines.size() == 1 and not String(lines[0]).contains(WorldEvents.NAME_WEEKEND_JEWEL), "Wednesday chip: no rush (%s)" % str(lines))
	# Halloween keeps its line until it ends (the last Saturday of October).
	lines = WorldEvents.chip_lines(thai(2026, 10, 31, 10))
	check(lines.size() == 3 and String(lines[2]) == WorldEvents.halloween_text(thai(2026, 10, 31, 10)) and String(lines[1]).begins_with(WorldEvents.NAME_WEEKEND_JEWEL), "31 Oct chip: event, rush and Halloween (%s)" % str(lines))
	lines = WorldEvents.chip_lines(thai(2026, 11, 1, 10))
	check(lines.size() == 2 and not lines.any(func(l): return String(l).contains("ฮาโลวีน")), "1 Nov chip: Halloween gone, the rush still on (%s)" % str(lines))
	# The HUD reads its lines from chip_lines.
	var src := FileAccess.get_file_as_string("res://ui/hud/hud.gd")
	check(src.contains("WorldEvents.chip_lines(t)"), "the HUD chip shows WorldEvents.chip_lines")


func _schedule() -> void:
	var t0 := thai(2026, 11, 4, 0)
	var n0 := int(floor(t0 / float(WorldEvents.GOLDEN_PERIOD)))
	var prev := -1.0
	var day_windows := 0
	for n in range(n0, n0 + 96 * 3):
		var start := WorldEvents.golden_start(n)
		var base := float(n * WorldEvents.GOLDEN_PERIOD)
		check(start >= base and start <= base + float(WorldEvents.GOLDEN_PERIOD - WorldEvents.GOLDEN_LENGTH), "window %d starts inside its period" % n)
		if prev > 0.0:
			var gap := start - prev
			check(gap >= 10.0 * 60.0 and gap <= 18.0 * 60.0, "about 10-18 minutes between golden monsters (%d s)" % int(gap))
		prev = start
		var on := WorldEvents.golden_now(start + 1.0)
		check(int(on.get("window", -1)) == n and is_equal_approx(float(on.until), start + float(WorldEvents.GOLDEN_LENGTH)), "on just after the start of window %d" % n)
		check(WorldEvents.golden_now(start - 1.0).is_empty() and WorldEvents.golden_now(start + float(WorldEvents.GOLDEN_LENGTH)).is_empty(), "off before and after window %d" % n)
		if start < t0 + 86400.0:
			day_windows += 1
	check(day_windows == 96, "96 golden monsters a day (%d)" % day_windows)
	check(WorldEvents.golden_start(n0 + 5) == WorldEvents.golden_start(n0 + 5), "the same for everyone")
	# Its ground: every levelling field, nothing else.
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		var levelling: bool = String(z.get("scene", "")) == "field" and not z.get("camps", []).is_empty() and not bool(z.get("pvp", false)) and not bool(z.get("arena", false)) and not bool(z.get("tower", false)) and not bool(z.get("safe", false))
		check(WorldEvents.golden_field(z) == levelling, "golden field %s: %s" % [id, levelling])
	check(WorldEvents.golden_field(ZoneData.get_zone(&"meadow")) and not WorldEvents.golden_field(ZoneData.get_zone(&"town")), "the meadow yes, the town no")
	for id in ZoneData.ZONES:
		if bool(ZoneData.ZONES[id].get("guildwar", false)):
			check(not WorldEvents.golden_field(ZoneData.ZONES[id]), "never in the guild war (%s)" % id)
	for id in StarProgression.REGIONS:
		check(WorldEvents.golden_field(ZoneData.get_zone(id)), "the ★ region %s has it" % id)
	check(WorldEvents.golden_tier(ZoneData.get_zone(&"meadow")) == 1 and WorldEvents.golden_tier(ZoneData.get_zone(&"abyss")) == 10, "field tiers: meadow 1, abyss 10")
	# Its items: always a purple and a pink jewel, chaos 25%, a stat gem now and then.
	var roll := RandomNumberGenerator.new()
	roll.seed = 5
	var chaos := 0
	var gems := 0
	var both := true
	for i in 4000:
		var items := Zone.golden_drops(30, false, roll)
		both = both and items.any(func(it): return it.get("kind", "") == "jewel" and it.id == "purple") and items.any(func(it): return it.get("kind", "") == "jewel" and it.id == "pink")
		chaos += items.filter(func(it): return it.get("kind", "") == "jewel" and it.id == "chaos").size()
		gems += items.filter(func(it): return it.get("kind", "") == "gem").size()
	check(both, "a purple and a pink jewel every time")
	check(chaos > 850 and chaos < 1150, "chaos about 25%% (%d / 4000)" % chaos)
	check(gems > 300 and gems < 500, "a stat gem about 10%% (%d / 4000)" % gems)


func _golden() -> void:
	# A Wednesday morning window (no EXP x2, no world boss, no weekend).
	var n := int(floor(thai(2026, 11, 4, 10) / float(WorldEvents.GOLDEN_PERIOD)))
	var t := WorldEvents.golden_start(n) + 20.0
	at(t)
	Game.profile.level = 5
	Game.current_zone = &"meadow"
	Game.profile["spawn_override"] = ""
	var zone := LootZone.new()
	zone.zone_id = &"meadow"
	zone.layout_seed = 7
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	check(zone.hero != null and zone._golden == null and _goldens(zone) == 0, "the field is built without a golden monster")
	var chat: Array = []
	var hear := func(speaker: String, text: String, _c: Color): chat.append([speaker, text])
	Game.world_chat.connect(hear)
	var said: Array = []
	var note := func(text: String, _kind: StringName): said.append(text)
	var has_say := Game.has_signal("toast")
	if has_say:
		Game.connect("toast", note)
	var rng_state := zone.rng.state
	zone._tick_golden()
	var gold_mob: Mob = zone._golden
	check(gold_mob != null and is_instance_valid(gold_mob) and gold_mob.is_inside_tree() and _goldens(zone) == 1, "a golden monster appears in the window")
	if gold_mob == null:
		Game.world_chat.disconnect(hear)
		return
	check(zone.rng.state == rng_state, "the zone's seeded rolls are untouched")
	check(String(gold_mob.template.name) == WorldEvents.NAME_GOLDEN and int(gold_mob.get_meta("golden")) == n, "named มอนทองคำ, of window %d" % n)
	check(gold_mob.template.get("tint") == WorldEvents.GOLDEN_COLOR and gold_mob.find_child("GoldenSparkle", true, false) != null, "gold-tinted with a sparkle")
	check(not String(MonsterData.get_monster(gold_mob.monster_id).name).contains(WorldEvents.NAME_GOLDEN), "the monster template itself is untouched")
	var plain := int(MonsterData.stats_for(gold_mob.monster_id, gold_mob.level).hp)
	check(gold_mob.max_hp == int(plain * WorldEvents.GOLDEN_HP) and gold_mob.hp == gold_mob.max_hp, "five times the HP (%d vs %d)" % [gold_mob.max_hp, plain])
	var camp := zone.camp_near(gold_mob.global_position)
	check(not camp.is_empty() and (camp.monsters as Array).has(gold_mob.monster_id) and gold_mob.level == int(camp.levels[1]), "one of the field's monsters, in its camp, at the camp's top level")
	var expect_camp: Dictionary = zone._camps[WorldEvents.golden_pick(n, &"meadow", zone._camps.size(), 1).x]
	check(camp.get("name", "") == expect_camp.name, "in the window's camp (%s)" % String(expect_camp.name))
	check(chat.any(func(c): return String(c[1]).contains(WorldEvents.NAME_GOLDEN) and String(c[1]).contains("ปรากฏ")), "announced in the world chat (%s)" % str(chat))
	if has_say:
		check(said.any(func(s): return String(s).contains(WorldEvents.NAME_GOLDEN)), "and on screen (%s)" % str(said))
	var mark := Minimap.mob_marker(gold_mob)
	check(mark[0] == WorldEvents.GOLDEN_COLOR and float(mark[1]) > 3.0, "a gold dot on the minimap")
	check(Minimap.mob_marker(_any_plain(zone))[0] != WorldEvents.GOLDEN_COLOR, "other monsters stay red")
	zone._tick_golden()
	check(_goldens(zone) == 1 and zone._golden == gold_mob, "one at a time")
	# Killed by the hero: the pile of gold and the jewels, the window spent.
	chat.clear()
	zone.gold_piles.clear()
	zone.items.clear()
	gold_mob.take_hit(gold_mob.hp, false, Color.WHITE, zone.hero)
	check(gold_mob.is_dead(), "the hero kills it")
	var pile := WorldEvents.GOLDEN_GOLD * WorldEvents.golden_tier(zone.data)
	check(zone.gold_piles.has(pile), "a pile of %d gold (%s)" % [pile, str(zone.gold_piles)])
	check(zone.items.any(func(i): return i.get("kind", "") == "jewel" and i.id == "purple") and zone.items.any(func(i): return i.get("kind", "") == "jewel" and i.id == "pink"), "a purple and a pink jewel")
	check(int(Game.profile.flags.get(WorldEvents.GOLDEN_FLAG, -1)) == n, "the window is spent")
	check(chat.any(func(c): return String(c[1]).contains("ปราบ" + WorldEvents.NAME_GOLDEN)), "the kill is announced (%s)" % str(chat))
	check(Game._valid_profile(JSON.parse_string(Marshalls.base64_to_utf8(Game.export_code())) as Dictionary), "a profile with the flag is valid")
	await get_tree().process_frame
	zone._tick_golden()
	check(_goldens(zone) == 0, "no second one in the same window")
	# Coming back in the same window (a new zone): still spent.
	zone._golden_window = -1
	zone._tick_golden()
	check(_goldens(zone) == 0, "the kill keeps it down for the window")
	# The next window brings a new one; it runs off when its 3 minutes are over.
	at(WorldEvents.golden_start(n + 1) + 5.0)
	zone._tick_golden()
	var next: Mob = zone._golden
	check(next != null and _goldens(zone) == 1 and int(next.get_meta("golden")) == n + 1, "the next window brings a new one")
	at(WorldEvents.golden_start(n + 1) + float(WorldEvents.GOLDEN_LENGTH) + 1.0)
	zone._tick_golden()
	await get_tree().process_frame
	check(_goldens(zone) == 0 and zone._golden == null, "it runs off when the window ends")
	zone._tick_golden()
	check(_goldens(zone) == 0, "nothing between windows")
	# Never in the town or the guild war, even in a window.
	at(WorldEvents.golden_start(n + 2) + 5.0)
	var meadow := zone.data
	for id in ZoneData.ZONES:
		var z: Dictionary = ZoneData.ZONES[id]
		if bool(z.get("guildwar", false)) or bool(z.get("safe", false)):
			zone.data = z
			zone._tick_golden()
			check(_goldens(zone) == 0, "no golden monster in %s" % id)
	zone.data = meadow
	zone.is_town = true
	zone._tick_golden()
	check(_goldens(zone) == 0, "no golden monster in a town zone")
	zone.is_town = false
	zone._tick_golden()
	check(_goldens(zone) == 1, "back in the field it comes")
	Game.world_chat.disconnect(hear)
	if has_say:
		Game.disconnect("toast", note)
	zone.queue_free()
	await get_tree().process_frame


func _goldens(zone: Zone) -> int:
	var count := 0
	for child in zone.get_children():
		var mob := child as Mob
		if mob and mob.has_meta("golden") and not mob.is_dead() and not mob.is_queued_for_deletion():
			count += 1
	return count


func _any_plain(zone: Zone) -> Mob:
	for child in zone.get_children():
		var mob := child as Mob
		if mob and not mob.has_meta("golden") and not mob.is_boss:
			return mob
	return Mob.new()
