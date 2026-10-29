extends Node
## Timed world events (WorldEvents): the schedule is fixed by the real clock in Thai
## time (EXP x2 19:00-21:00, the world boss 20:30 for 20 minutes in the field of the
## day, +20% gold on the weekend), add_exp doubles in the window, and the world boss
## spawns in its field during the window, once a window.
##   godot --headless --path . res://tests/integration/world_events_test.tscn
var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## Unix time of a Thai-time moment.
func thai(year: int, month: int, day: int, hour: int, minute := 0) -> float:
	return float(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}) - WorldPlayers.TZ)


func _ready() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Events QA")
	ZoneData.ensure()
	_schedule()
	_exp()
	await _boss()
	WorldPresence.clock_offset = 0.0
	print("WORLD EVENTS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _schedule() -> void:
	# Wednesday 28 Oct 2026 and the Saturday after.
	check(WorldEvents.weekday(thai(2026, 10, 28, 12)) == 3 and WorldEvents.weekday(thai(2026, 10, 31, 12)) == 6, "weekdays in Thai time")
	check(WorldEvents.time_of_day(thai(2026, 10, 28, 19, 30)) == 19 * 3600 + 1800, "time of the Thai day")
	check(WorldEvents.exp_multiplier(thai(2026, 10, 28, 19, 30)) == 2.0, "19:30 Thai: EXP x2")
	check(WorldEvents.exp_multiplier(thai(2026, 10, 28, 19, 0)) == 2.0, "19:00 starts it")
	check(WorldEvents.exp_multiplier(thai(2026, 10, 28, 10, 0)) == 1.0, "10:00 Thai: no EXP bonus")
	check(WorldEvents.exp_multiplier(thai(2026, 10, 28, 21, 0)) == 1.0, "21:00 ends it")
	check(WorldEvents.gold_multiplier(thai(2026, 10, 31, 10)) == 1.2 and WorldEvents.gold_multiplier(thai(2026, 11, 1, 23)) == 1.2, "Saturday and Sunday: gold x1.2")
	check(WorldEvents.gold_multiplier(thai(2026, 10, 28, 10)) == 1.0 and WorldEvents.gold_multiplier(thai(2026, 11, 2, 1)) == 1.0, "weekdays: no gold bonus")
	# The world boss window and its field.
	var boss := WorldEvents.boss_now(thai(2026, 10, 28, 20, 35))
	check(not boss.is_empty() and String(boss.id) == "wboss", "20:35: the world boss is on")
	check(WorldEvents.boss_now(thai(2026, 10, 28, 20, 29)).is_empty() and WorldEvents.boss_now(thai(2026, 10, 28, 20, 50)).is_empty(), "20:29 and 20:50: no world boss")
	check(is_equal_approx(float(boss.get("until", 0.0)), thai(2026, 10, 28, 20, 50)), "the window ends at 20:50")
	check(_hunting_field(StringName(boss.get("zone", &""))), "the boss field is a real hunting field (%s)" % boss.get("zone", ""))
	check(String(boss.name_th).begins_with("บอสโลกที่ "), "named in Thai")
	var fields := {}
	var star_weekend := 0
	for d in 56:
		var t := thai(2026, 10, 28, 20, 35) + float(d * 86400)
		var zone := WorldEvents.boss_zone(t)
		check(_hunting_field(zone), "day %d boss field is a hunting field (%s)" % [d, zone])
		var star := StarProgression.is_region(zone) or zone == DivineRegionData.ID
		check(WorldEvents.is_weekend(t) or not star, "a ★ region only on the weekend (day %d: %s)" % [d, zone])
		if star:
			star_weekend += 1
		fields[zone] = true
	check(fields.size() >= 8, "the boss rotates through the fields (%d in 8 weeks)" % fields.size())
	check(star_weekend > 0, "a ★ region hosts the boss on some weekends (%d)" % star_weekend)
	check(WorldEvents.boss_zone(thai(2026, 10, 28, 20, 35)) == WorldEvents.boss_zone(thai(2026, 10, 28, 20, 45)), "one field for the whole window")
	# What is on and what comes next.
	var ids: Array = WorldEvents.current(thai(2026, 10, 31, 19, 30)).map(func(e): return String(e.id))
	check(ids == ["exp2", "gold"], "Saturday 19:30: EXP x2 and the gold bonus (%s)" % str(ids))
	ids = WorldEvents.current(thai(2026, 10, 28, 20, 35)).map(func(e): return String(e.id))
	check(ids == ["exp2", "wboss"], "Wednesday 20:35: EXP x2 and the world boss (%s)" % str(ids))
	check(WorldEvents.current(thai(2026, 10, 28, 10)).is_empty(), "Wednesday 10:00: nothing on")
	var next := WorldEvents.next_event(thai(2026, 10, 28, 10))
	check(String(next.get("id", "")) == "exp2" and is_equal_approx(float(next.get("in", 0.0)), 9.0 * 3600.0), "10:00: EXP x2 in 9 hours")
	next = WorldEvents.next_event(thai(2026, 10, 28, 19, 30))
	check(String(next.get("id", "")) == "wboss" and is_equal_approx(float(next.get("in", 0.0)), 3600.0) and _hunting_field(StringName(next.get("zone", &""))), "19:30: the world boss in an hour")
	next = WorldEvents.next_event(thai(2026, 10, 28, 20, 35))
	check(String(next.get("id", "")) == "exp2" and is_equal_approx(float(next.get("in", 0.0)), (22.0 * 60.0 + 25.0) * 60.0), "20:35: EXP x2 tomorrow")
	var a := float(WorldEvents.next_event(thai(2026, 10, 28, 10))["in"])
	var b := float(WorldEvents.next_event(thai(2026, 10, 28, 10) + 60.0)["in"])
	check(is_equal_approx(a - b, 60.0), "next_event counts down")
	# The HUD line.
	var line := WorldEvents.describe(thai(2026, 10, 28, 19, 18))
	check(line.begins_with("EXP x2 เหลือ ") and line.ends_with("นาที"), "19:18 chip: EXP x2 with minutes left (%s)" % line)
	line = WorldEvents.describe(thai(2026, 10, 28, 20, 38))
	check(line.begins_with("บอสโลกที่ ") and line.ends_with("12 นาที"), "20:38 chip: the world boss and its field (%s)" % line)
	line = WorldEvents.describe(thai(2026, 10, 28, 17, 0))
	check(line == "EXP x2 ใน 2 ชม.", "17:00 chip: the next event (%s)" % line)
	line = WorldEvents.describe(thai(2026, 10, 31, 10, 0))
	check(line.begins_with("โบนัสทอง +20% · ") and line.ends_with("ใน 9 ชม."), "Saturday chip: the gold bonus and the next event (%s)" % line)


func _hunting_field(id: StringName) -> bool:
	if not ZoneData.ZONES.has(id):
		return false
	var z: Dictionary = ZoneData.ZONES[id]
	return String(z.scene) == "field" and z.has("boss") and not z.get("camps", []).is_empty() \
		and not bool(z.get("pvp", false)) and not bool(z.get("arena", false)) and not bool(z.get("tower", false))


func _exp() -> void:
	Game.profile.level = 5
	Game.profile.exp = 0
	WorldPresence.clock_offset = thai(2026, 10, 28, 19, 30) - WorldPlayers.now()
	check(is_equal_approx(WorldEvents.exp_multiplier(WorldPresence.clock()), 2.0), "the world clock is in the window")
	Game.add_exp(10)
	check(int(Game.profile.exp) == 20, "add_exp doubles in the window (%d)" % int(Game.profile.exp))
	WorldPresence.clock_offset = thai(2026, 10, 28, 10, 0) - WorldPlayers.now()
	Game.add_exp(10)
	check(int(Game.profile.exp) == 30, "add_exp is plain outside it (%d)" % int(Game.profile.exp))


func _boss() -> void:
	var t0 := thai(2026, 10, 28, 20, 35)
	WorldPresence.clock_offset = t0 - WorldPlayers.now()
	var event := WorldEvents.boss_now(WorldPresence.clock())
	var id := StringName(event.zone)
	var source: Dictionary = ZoneData.get_zone(id)
	Game.profile.level = int(source.level[0])
	Game.current_zone = id
	Game.profile["spawn_override"] = ""
	var zone := Zone.new()
	zone.zone_id = id
	zone.layout_seed = 7
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	check(zone.hero != null and zone._wboss == null, "the field is built without a world boss yet")
	zone._tick_world_boss()
	var boss: Mob = zone._wboss
	check(boss != null and is_instance_valid(boss) and boss.is_inside_tree(), "the world boss spawns in the field of the day during the window")
	if boss == null:
		return
	var plain := int(MonsterData.stats_for(source.boss.monster, int(source.boss.level)).hp)
	check(boss.max_hp == int(plain * WorldEvents.BOSS_HP_SCALE) and boss.hp == boss.max_hp, "three times the field boss's HP (%d vs %d)" % [boss.max_hp, plain])
	check(String(boss.template.name).begins_with("บอสโลก ") and boss.is_boss, "named บอสโลก and a boss")
	check(String(MonsterData.get_monster(source.boss.monster).name) == String(MonsterData.MONSTERS[source.boss.monster].name) and not String(MonsterData.get_monster(source.boss.monster).name).begins_with("บอสโลก"), "the monster template itself is untouched")
	zone._tick_world_boss()
	check(zone._wboss == boss and _world_bosses(zone) == 1, "not a second one while it lives")
	# Defeated by the hero: the day's flag, the gold, no respawn this window.
	# The kill also completes daily quests and achievements that pay gold of their own:
	# every payment is recorded and the bounty must be one of them.
	var paid: Array[int] = []
	var last := [int(Game.profile.gold)]
	var tally := func(total: int):
		paid.append(total - int(last[0]))
		last[0] = total
	Game.gold_changed.connect(tally)
	var day := WorldEvents.day_of(WorldPresence.clock())
	var expected := WorldEvents.BOSS_GOLD_PER_10 * maxi(1, int(Game.profile.level) / 10)
	boss.take_hit(boss.hp, false, Color.WHITE, zone.hero)
	Game.gold_changed.disconnect(tally)
	check(boss.is_dead(), "the hero kills it")
	check(int(Game.profile.flags.get(WorldEvents.flag_key(day), 0)) == 1, "the day's window is spent (flag %s)" % WorldEvents.flag_key(day))
	check(paid.has(expected), "the bounty is paid (%s, expected %d)" % [str(paid), expected])
	zone._tick_world_boss()
	check(_world_bosses(zone) == 0, "no second world boss in the same window")
	# The flag is a plain integer the save accepts.
	var raw := JSON.parse_string(Marshalls.base64_to_utf8(Game.export_code())) as Dictionary
	check(Game._valid_profile(raw), "a profile with the flag is valid")
	# Outside the window (and in another field) nothing spawns even with the flag gone.
	Game.profile.flags.erase(WorldEvents.flag_key(day))
	WorldPresence.clock_offset = thai(2026, 10, 28, 10, 0) - WorldPlayers.now()
	zone._tick_world_boss()
	check(_world_bosses(zone) == 0, "no world boss outside the window")
	WorldPresence.clock_offset = t0 - WorldPlayers.now()
	zone.zone_id = &"town"
	zone._tick_world_boss()
	check(_world_bosses(zone) == 0, "no world boss in another field")
	zone.zone_id = id
	zone._tick_world_boss()
	check(_world_bosses(zone) == 1, "a new window spawns it again")
	zone.queue_free()


func _world_bosses(zone: Zone) -> int:
	var n := 0
	for child in zone.get_children():
		var mob := child as Mob
		if mob and mob.has_meta("world_boss") and not mob.is_dead():
			n += 1
	return n
