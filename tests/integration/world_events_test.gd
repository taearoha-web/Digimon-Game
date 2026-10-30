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
	# Its special moves (WorldBoss) and the world players that join in.
	var special := WorldBoss.of(boss)
	check(special != null and special.get_parent() == boss, "the world boss carries a WorldBoss node")
	if special != null:
		_specials(zone, boss, special)
		await _joiners(zone, boss, special)
	# Defeated by the hero: the day's flag, the gold, the rarity-3 piece, no respawn this
	# window. The kill also completes daily quests and achievements that pay gold of
	# their own: every payment is recorded and the bounty must be one of them.
	var paid: Array[int] = []
	var last := [int(Game.profile.gold)]
	var tally := func(total: int):
		paid.append(total - int(last[0]))
		last[0] = total
	Game.gold_changed.connect(tally)
	var gained: Array[Dictionary] = []
	var keep := func(item: Dictionary): gained.append(item)
	Game.item_gained.connect(keep)
	var banners: Array[String] = []
	var note := func(text: String): banners.append(text)
	zone.banner_requested.connect(note)
	var defeated: Array[StringName] = []
	if Game.has_signal("world_boss_defeated"):
		Game.connect("world_boss_defeated", func(z: StringName): defeated.append(z))
	var day := WorldEvents.day_of(WorldPresence.clock())
	var expected := WorldEvents.BOSS_GOLD_PER_10 * maxi(1, int(Game.profile.level) / 10)
	boss.take_hit(boss.hp, false, Color.WHITE, zone.hero)
	Game.gold_changed.disconnect(tally)
	Game.item_gained.disconnect(keep)
	zone.banner_requested.disconnect(note)
	check(boss.is_dead(), "the hero kills it")
	check(int(Game.profile.flags.get(WorldEvents.flag_key(day), 0)) == 1, "the day's window is spent (flag %s)" % WorldEvents.flag_key(day))
	check(paid.has(expected), "the bounty is paid (%s, expected %d)" % [str(paid), expected])
	var legend := gained.filter(func(i): return String(i.get("kind", "")) == "equip" and int(i.get("rarity", 0)) == WorldEvents.BOSS_DROP_RARITY)
	check(legend.size() >= 1, "a rarity-%d piece lands in the bag (%d gained)" % [WorldEvents.BOSS_DROP_RARITY, gained.size()])
	check(not legend.is_empty() and Game.profile.inv.has(legend[0]), "the piece is in the bag")
	check(banners.any(func(b: String): return b.contains(String(source.name)) and b.begins_with("ปราบบอสโลก")), "the banner names the field (%s)" % str(banners))
	if Game.has_signal("world_boss_defeated"):
		check(defeated == [id], "Game.world_boss_defeated names the field (%s)" % str(defeated))
	else:
		print("  (Game.world_boss_defeated not there yet: skipped)")
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


## The special moves: a telegraph first, the hit inside it and not outside, the roar at
## 60% and the summons. The zone does not process, so the node is driven by hand.
func _specials(zone: Zone, boss: Mob, special: WorldBoss) -> void:
	var hero := zone.hero
	var max_hp := int(hero.stats.max_hp)
	hero.stats.dodge = 0.0
	hero.global_position = boss.global_position + Vector3(2.0, 0.3, 0.0)
	Game.profile.hp = max_hp
	check(special.telegraph.is_empty() and special._shapes.is_empty(), "no telegraph before the first move")
	special.tick(30.0)
	check(not special.telegraph.is_empty() and String(special.telegraph.kind) == "stomp", "the first move is telegraphed (%s)" % str(special.telegraph.get("kind", "")))
	check(special._shapes.size() >= 1 and special._shapes.all(func(s): return is_instance_valid(s) and s.is_inside_tree()), "the telegraph is drawn on the ground (%d shapes)" % special._shapes.size())
	check(special.inside(hero.global_position) and not special.inside(boss.global_position + Vector3(9.0, 0, 0)), "the stomp covers %.0f m round the boss" % WorldBoss.STOMP_RADIUS)
	check(boss._winding, "the boss stands still while it winds up")
	check(int(Game.profile.hp) == max_hp, "nothing lands during the telegraph")
	special.tick(1.0)
	check(not special.telegraph.is_empty() and int(Game.profile.hp) == max_hp, "1.0 s in: still winding up")
	special.tick(1.0)
	check(special.telegraph.is_empty() and special._shapes.is_empty() and special.specials == 1, "the stomp lands after %.1f s and the telegraph is gone" % WorldBoss.TELEGRAPH)
	var lost := max_hp - int(Game.profile.hp)
	check(lost >= int(max_hp * 0.25) and lost <= int(max_hp * 0.45), "the hero inside loses about 35%% of max HP (%d of %d)" % [lost, max_hp])
	check(not boss._winding, "the boss moves again")
	# Out of the circle: nothing.
	hero.global_position = boss.global_position + Vector3(12.0, 0.3, 0.0)
	Game.profile.hp = max_hp
	special.force_special("stomp")
	check(not special.inside(hero.global_position), "12 m away is outside the stomp")
	special.tick(2.0)
	check(special.specials == 2 and int(Game.profile.hp) == max_hp, "the hero outside takes nothing")
	# The beam points at the hero: a 3 m wide line, 18 m long.
	hero.global_position = boss.global_position + Vector3(10.0, 0.3, 0.0)
	special.force_special("beam")
	check(String(special.telegraph.kind) == "beam" and special.inside(hero.global_position), "the beam is aimed at the hero")
	check(not special.inside(hero.global_position + Vector3(0, 0, 2.0)) and special.inside(hero.global_position + Vector3(0, 0, 1.2)), "the beam is %.0f m wide" % WorldBoss.BEAM_WIDTH)
	check(special.inside(boss.global_position + Vector3(17.5, 0, 0)) and not special.inside(boss.global_position + Vector3(19.0, 0, 0)), "the beam is %.0f m long" % WorldBoss.BEAM_LENGTH)
	check(not special.inside(boss.global_position - Vector3(3.0, 0, 0)), "nothing behind the boss")
	var escape := special.escape_point(hero.global_position)
	check(not special.inside(escape) and is_equal_approx(Vector2(escape.x - hero.global_position.x, escape.z - hero.global_position.z).length(), 7.0), "the escape point is 7 m to the side, out of the beam")
	special.tick(2.0)
	check(special.specials == 3 and int(Game.profile.hp) < max_hp, "the beam hits the hero in the line")
	# One telegraph at a time.
	special.force_special("stomp")
	special.force_special("beam")
	check(String(special.telegraph.kind) == "stomp", "a second move waits for the first")
	special.tick(2.0)
	# The roar at 60% HP: the banner and a cycle 25% shorter.
	var banners: Array[String] = []
	var note := func(text: String): banners.append(text)
	zone.banner_requested.connect(note)
	check(special.phase == 0 and is_equal_approx(special._haste, 1.0), "no roar above 60%")
	boss.hp = int(float(boss.max_hp) * 0.59)
	special.tick(0.1)
	check(special.phase == 1 and is_equal_approx(special._haste, WorldBoss.ROAR_HASTE), "it roars at 60%% HP and the cycle shortens by 25%% (phase %d)" % special.phase)
	check(banners.has(WorldBoss.ROAR_TEXT), "the roar banner (%s)" % str(banners))
	special.tick(0.1)
	check(special.phase == 1, "one roar per threshold")
	boss.hp = int(float(boss.max_hp) * 0.29)
	special.tick(0.1)
	check(special.phase == 2 and is_equal_approx(special._haste, WorldBoss.ROAR_HASTE * WorldBoss.ROAR_HASTE), "the second roar at 30%")
	zone.banner_requested.disconnect(note)
	# The summons: three of the field's monsters at 60% HP.
	hero.global_position = boss.global_position + Vector3(12.0, 0.3, 0.0)
	special.force_special("summon")
	check(String(special.telegraph.kind) == "summon" and not special._shapes.is_empty(), "the summon is telegraphed too")
	special.tick(2.0)
	var adds: Array[Mob] = []
	for child in zone.get_children():
		var m := child as Mob
		if m and m.has_meta("world_boss_add"):
			adds.append(m)
	check(adds.size() == WorldBoss.SUMMON_COUNT, "%d monsters of the field join (%d)" % [WorldBoss.SUMMON_COUNT, adds.size()])
	var camp_ids: Array = []
	for camp in zone.data.camps:
		camp_ids.append_array(camp.monsters)
	check(adds.all(func(m: Mob): return camp_ids.has(m.monster_id) and m.hostile and not m.is_boss), "they are the field's regular monsters, hostile")
	check(adds.all(func(m: Mob): return m.hp == maxi(1, int(float(m.max_hp) * WorldBoss.SUMMON_HP))), "at 60% HP")
	for m in adds:
		m.queue_free()
	Game.profile.hp = max_hp


## World players hunting in the field: within 40 m the boss is their target, they shout
## about it (rate-limited), step out of a telegraph and take a flat hit when they stay.
func _joiners(zone: Zone, boss: Mob, special: WorldBoss) -> void:
	var i := WorldPlayers.first_of(&"warrior")
	var m := WorldPlayers.member(i)
	var p := FieldPlayer.new()
	p.setup_world(i, m, zone.hero, zone)
	zone.add_child(p)
	p.global_position = boss.global_position + Vector3(8.0, 0.3, 0.0)
	await get_tree().process_frame
	check(p.is_in_group("world_players") and not p.party_mode and not p._camp.is_empty(), "a world player hunts in the field")
	var chat: Array = []
	var hear := func(speaker: String, text: String, _color: Color): chat.append([speaker, text])
	Game.world_chat.connect(hear)
	p._shout_at = 0.0
	check(p._pick_target() == boss, "within 40 m it goes for the world boss")
	check(chat.size() == 1 and String(chat[0][0]) == String(m.name) and WorldEvents.BOSS_SHOUTS.has(String(chat[0][1])), "it shouts about it in the world chat (%s)" % str(chat))
	check(is_instance_valid(p._bubble) and WorldEvents.BOSS_SHOUTS.has(String(p._bubble.text)), "and over its head")
	p._pick_target()
	p._pick_target()
	check(chat.size() == 1 and p._shout_at >= Time.get_ticks_msec() * 0.001 + WorldEvents.BOSS_SHOUT_GAP - 1.0, "one shout per 30 s")
	Game.world_chat.disconnect(hear)
	p.global_position = boss.global_position + Vector3(WorldEvents.BOSS_JOIN_RANGE + 6.0, 0.3, 0.0)
	check(p._pick_target() != boss, "too far away it keeps to its camp")
	# Inside a telegraph it steps out, 7 m perpendicular; staying in, it takes a flat hit.
	p.global_position = boss.global_position + Vector3(2.0, 0.3, 0.0)
	check(not p._dodge_world_boss(0.016).is_finite(), "nothing to dodge without a telegraph")
	special.force_special("stomp")
	var step := p._dodge_world_boss(0.016)
	check(step.is_finite() and step.length() > 1.0 and p._dodge_to.is_finite(), "inside the stomp it steps out")
	check(not special.inside(p._dodge_to) and is_equal_approx(Vector2(p._dodge_to.x - p.global_position.x, p._dodge_to.z - p.global_position.z).length(), 7.0), "to a spot 7 m out of the circle")
	check(step.normalized().dot((p._dodge_to - p.global_position).normalized()) > 0.95, "walking that way")
	p.stats.dodge = 0.0
	var hp_before := p.hp
	special.tick(2.0)
	check(p.hp < hp_before, "a world player still inside takes a hit (%d -> %d)" % [hp_before, p.hp])
	check(not p._dodge_world_boss(0.016).is_finite() and not p._dodge_to.is_finite(), "the dodge is over with the telegraph")
	p.queue_free()
	await get_tree().process_frame


func _world_bosses(zone: Zone) -> int:
	var n := 0
	for child in zone.get_children():
		var mob := child as Mob
		if mob and mob.has_meta("world_boss") and not mob.is_dead():
			n += 1
	return n
