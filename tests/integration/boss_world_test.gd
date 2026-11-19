extends Node
## The field bosses live in the world (BossWorld): a boss that is up stands at its spot
## from the moment the hero comes, one that is down shows who took it, when, and when it
## is back (the sign at its spot and the HUD line), and comes back at that time; the
## hero's kill is kept in the save (a trip out and back does not bring it back early);
## the world players' kills are the same for the same clock and roster, by somebody
## really hunting that field, never overlapping; a real player's kill heard from the
## server counts the same; the zone's host tells the server (and a mirror does not).
##   godot --headless --path . res://tests/integration/boss_world_test.tscn
var failures := 0
var checks := 0


class FakeTransport:
	extends RefCounted
	var sent: Array[String] = []
	func send_text(text: String) -> void:
		sent.append(text)
	func poll() -> Array:
		return []
	func is_open() -> bool:
		return true
	func is_closed() -> bool:
		return false
	func frames(t: String) -> Array:
		var out: Array = []
		for text in sent:
			var d: Variant = JSON.parse_string(text)
			if d is Dictionary and String(d.get("t", "")) == t:
				out.append(d)
		return out


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


## The world clock at real unix time t.
func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	Announcer.ticking = false
	Game.new_profile(&"warrior", "BossQA")
	Game.profile.level = 10
	ZoneData.ensure()
	BossWorld.reset()
	BossWorld.ai_mode = 0
	at(float(WorldPlayers.START_UNIX) + 20.0 * 86400.0)
	_data()
	await _entry_and_kill()
	_save()
	await _ai_kill_in_zone()
	_heard()
	_ai_world()
	await _online()
	BossWorld.ai_mode = -1
	BossWorld.reset()
	WorldPresence.clock_offset = 0.0
	print("BOSS WORLD: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _data() -> void:
	var zones := BossWorld.zones()
	for id in [&"meadow", &"dark_forest", &"abyss", &"void", &"dawn_forest", &"eclipse_realm", DivineRegionData.ID, DrownedAbyssData.ID, SkyIsleData.ID]:
		check(zones.has(id), "%s has a world boss" % id)
	for id in [&"town", &"tower", &"arena", &"pvp", &"guildwar", RaidData.ID, DungeonData.ID]:
		check(not BossWorld.has_boss(id), "%s keeps its own rules" % id)
	check(BossWorld.respawn(&"abyss") == 60.0 and BossWorld.respawn(&"meadow") == 120.0 and BossWorld.respawn(SkyIsleData.ID) == SkyIsleData.BOSS_RESPAWN, "the respawn times are the zone data's (the Lv.100 boss's one minute)")
	check(BossWorld.state(&"meadow").alive and BossWorld.chip_text(&"meadow") == "", "never killed: up, no HUD line")


func _field(id: StringName) -> Zone:
	Game.current_zone = id
	Game.profile["spawn_override"] = ""
	var zone := Zone.new()
	zone.zone_id = id
	zone.layout_seed = 11
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	return zone


func _entry_and_kill() -> void:
	var zone: Zone = await _field(&"meadow")
	zone._tick_boss(0.1)
	var boss: Mob = zone._boss
	check(boss != null and is_instance_valid(boss) and boss.monster_id == &"mush_king", "up in the world: the boss stands at its spot the moment the hero comes")
	if boss == null:
		return
	check(boss.hp == boss.max_hp and boss.global_position.distance_to(zone._boss_spot) < 1.5, "full HP, at the boss spot")
	zone._tick_boss_sign(5.0)
	check(zone._boss_sign == null or not zone._boss_sign.visible, "no sign while it stands")
	var kills_before := int(Game.profile.boss_kills.get("mush_king", 0))
	var t0 := WorldPresence.clock()
	boss.take_hit(boss.hp + 10, false, Color.WHITE, zone.hero)
	check(int(Game.profile.boss_kills.get("mush_king", 0)) == kills_before + 1, "the kill still counts for quests and achievements")
	var book: Dictionary = Game.profile.get(BossWorld.KEY, {})
	check(book.has("meadow") and String(book.meadow.by) == "BossQA" and absf(float(book.meadow.at) - t0) <= 1.0, "the hero's kill is in the save (%s)" % str(book))
	var s := BossWorld.state(&"meadow")
	check(not s.alive and String(s.killer) == "BossQA" and absf(float(s.respawn_at) - (float(book.meadow.at) + 120.0)) < 0.01, "down until the kill + its respawn")
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	check(zone._boss == null, "no new boss right away")
	zone._boss_sign_in = 0.0
	zone._tick_boss_sign(0.1)
	check(zone._boss_sign != null and zone._boss_sign.visible and zone._boss_sign_label.text.contains("BossQA") and zone._boss_sign_label.text.contains("เกิดใหม่ใน"), "the sign at the spot: who and when it is back (%s)" % (zone._boss_sign_label.text if zone._boss_sign_label else ""))
	var chip := BossWorld.chip_text(&"meadow")
	check(chip.begins_with("ราชาเห็ดยักษ์ ถูก BossQA ปราบ") and chip.contains("เกิดใหม่ใน 0"), "the HUD line (%s)" % chip)
	zone.queue_free()
	await get_tree().process_frame
	# Out and back in: still down (no farming by walking out).
	var back := float(book.meadow.at) + 120.0
	at(back - 60.0)
	zone = await _field(&"meadow")
	zone._tick_boss(0.1)
	zone._tick_boss_sign(0.1)
	check(zone._boss == null and zone._boss_sign != null and zone._boss_sign.visible, "back in a minute later: still down, the sign up")
	check(BossWorld.chip_text(&"meadow").contains("เมื่อ 1 นาทีก่อน") and BossWorld.chip_text(&"meadow").contains("เกิดใหม่ใน 01:00"), "a minute ago, back in a minute (%s)" % BossWorld.chip_text(&"meadow"))
	at(back - 1.0)
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	check(zone._boss == null, "a second before the time: not yet")
	at(back + 0.5)
	Announcer.history.clear()
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	check(zone._boss != null and is_instance_valid(zone._boss) and zone._boss.hp == zone._boss.max_hp, "back at the kill + 120 s")
	check(not Announcer.history.is_empty() and String(Announcer.history[-1].text).contains("ราชาเห็ดยักษ์"), "its coming back is announced")
	zone._boss_sign_in = 0.0
	zone._tick_boss_sign(0.1)
	check(not zone._boss_sign.visible, "the sign goes when it is back")
	zone.queue_free()
	await get_tree().process_frame


func _save() -> void:
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Game.profile))
	check(Game._valid_profile(saved), "a save with the record is valid")
	var repaired := Game._repair(saved.duplicate(true))
	check(repaired.get(BossWorld.KEY, {}).has("meadow") and repaired[BossWorld.KEY].meadow.at is int, "repair keeps it")
	var old := saved.duplicate(true)
	old.erase(BossWorld.KEY)
	check(Game._valid_profile(old), "an older save without it is valid")
	for bad in [[], {"meadow": 5}, {"meadow": {"at": "x"}}, {"meadow": {"at": -1}}, {"meadow": {"at": 5, "by": 7}}, {"m".repeat(60): {"at": 1}}]:
		var b := saved.duplicate(true)
		b[BossWorld.KEY] = bad
		check(not Game._valid_profile(b), "a broken record is refused (%s)" % str(bad).left(40))
	var stale := saved.duplicate(true)
	stale[BossWorld.KEY] = {"meadow": {"at": int(WorldPresence.clock() - BossWorld.KEEP - 10.0), "by": "x"}, "nowhere": {"at": int(WorldPresence.clock()), "by": "y"}}
	check(Game._repair(stale)[BossWorld.KEY].is_empty(), "repair forgets old kills and unknown fields")
	# A reload (nothing in memory) still has the hero's kill.
	BossWorld.record_kill(&"dark_forest", "BossQA")
	BossWorld._real.clear()
	check(not BossWorld.state(&"dark_forest").alive, "the save alone keeps it down")
	Game.profile[BossWorld.KEY].erase("dark_forest")


func _ai_kill_in_zone() -> void:
	BossWorld.ai_mode = 1
	var zone: Zone = await _field(&"meadow")
	# Nobody hunts the meadow now: stuff a world players' kill into this slot.
	var t := WorldPresence.clock()
	var slot := BossWorld.slot_of(&"meadow", t)
	BossWorld._slots["meadow|%d" % slot] = {}
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	var boss: Mob = zone._boss
	check(boss != null, "up: there")
	if boss == null:
		return
	# Watched by the hero (close by): it does not happen on this screen.
	zone.hero.global_position = boss.global_position + Vector3(6, 0, 0)
	var paid := int(Game.profile.boss_kills.get("mush_king", 0))
	BossWorld._slots["meadow|%d" % slot] = {"at": WorldPresence.clock() + 0.5, "killer": "หนุ่มทดสอบ", "party": 3, "ai": true}
	BossWorld._held.clear()
	at(WorldPresence.clock() + 1.0)
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	check(zone._boss == boss and BossWorld.state(&"meadow").alive, "the hero watches it: the world players' try is held here")
	# Far off and untouched: it is taken away, the sign names the party.
	BossWorld._held.clear()
	zone.hero.global_position = zone._boss_spot + Vector3(-60, 0, -10)
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	check(zone._boss == null and (not is_instance_valid(boss) or boss.is_queued_for_deletion()), "nobody near: the world players took it")
	zone._boss_sign_in = 0.0
	zone._tick_boss_sign(0.1)
	check(zone._boss_sign != null and zone._boss_sign_label.text.contains("ปาร์ตี้ของ หนุ่มทดสอบ"), "the sign names their party (%s)" % (zone._boss_sign_label.text if zone._boss_sign_label else ""))
	check(int(Game.profile.boss_kills.get("mush_king", 0)) == paid, "their kill pays the hero nothing")
	# Fought by the hero: held as well.
	BossWorld._slots.clear()
	BossWorld._held.clear()
	at(t + 130.0)
	slot = BossWorld.slot_of(&"meadow", WorldPresence.clock())
	BossWorld._slots["meadow|%d" % slot] = {}
	zone._boss_timer = 0.0
	zone._tick_boss(0.1)
	boss = zone._boss
	if boss != null:
		boss.take_hit(5, false, Color.WHITE, zone.hero)
		BossWorld._slots["meadow|%d" % slot] = {"at": WorldPresence.clock(), "killer": "หนุ่มทดสอบ", "party": 1, "ai": true}
		zone._boss_timer = 0.0
		zone._tick_boss(0.1)
		check(zone._boss == boss and not boss.is_queued_for_deletion(), "a boss in a fight stays")
	BossWorld._slots.clear()
	BossWorld._held.clear()
	BossWorld.ai_mode = 0
	zone.queue_free()
	await get_tree().process_frame


func _heard() -> void:
	var now := WorldPresence.clock()
	Online._dispatch({"t": "boss_kill", "zone": "abyss", "name": "RealPlayer", "ago": 15000})
	var s := BossWorld.state(&"abyss")
	check(not s.alive and String(s.killer) == "RealPlayer" and absf(float(s.killed_at) - (now - 15.0)) < 1.5, "a real player's kill from the server: down, by that name, 15 s ago")
	check(absf(float(s.respawn_at) - float(s.killed_at) - 60.0) < 0.01, "the Lv.100 boss is back a minute after")
	Online._dispatch({"t": "boss_state", "bosses": [{"zone": "abyss", "name": "Older", "ago": 40000}, {"zone": "void", "name": "Voidy", "ago": 1000}, {"zone": "nowhere", "name": "x", "ago": 0}, {"zone": "desert", "name": "bad", "ago": "soon"}]})
	check(String(BossWorld.state(&"abyss").killer) == "RealPlayer", "an older kill does not replace a newer one")
	check(String(BossWorld.state(&"void").killer) == "Voidy" and BossWorld.state(&"desert").alive, "the server's book on joining; broken entries are skipped")
	check(not Game.profile.get(BossWorld.KEY, {}).has("void"), "heard kills are not written into the hero's save")


func _ai_world() -> void:
	BossWorld.ai_mode = 1
	at(float(WorldPlayers.START_UNIX) + 20.0 * 86400.0 + 7200.0)
	BossWorld.reset()
	var t0 := WorldPresence.clock()
	var first := {}
	var kills := {}
	var down := {}
	var overlap := false
	var lies: Array = []
	for id in BossWorld.zones():
		var last := -1.0
		var list: Array = []
		var n := 0
		var dead := 0
		var t := t0
		while t < t0 + 3.0 * 3600.0:
			var s := BossWorld.state(id, t)
			n += 1
			if not s.alive:
				dead += 1
				if float(s.killed_at) != last:
					if last > 0.0 and float(s.killed_at) < last + BossWorld.respawn(id):
						overlap = true
					last = float(s.killed_at)
					list.append([float(s.killed_at), String(s.killer)])
			t += 15.0
		kills[id] = list
		down[id] = float(dead) / float(n)
		first[id] = list.duplicate()
	# Every world players' kill: somebody of the roster really hunting that field then.
	var c := 0
	for id in kills:
		for k in kills[id]:
			var slot := BossWorld.slot_of(id, float(k[0]))
			var e := BossWorld.ai_kill(id, slot)
			if e.is_empty():
				lies.append([id, k])
				continue
			var h := WorldParties.hunter(int(e.index), float(e.at))
			if h.is_empty() or StringName(h.zone) != id or BossWorld.edge(id, int(h.level), int(h.stars)) <= 0.0:
				lies.append([id, k, h])
			c += 1
	check(c > 0, "the world players bring some bosses down in three hours (%d)" % c)
	check(lies.is_empty(), "each was by somebody hunting that field, fit for its boss (%s)" % str(lies).left(200))
	check(not overlap, "their kills never overlap a boss that is already down")
	# A field nobody fit hunts keeps its boss.
	for id in kills:
		var hunters := 0
		for step in range(0, 36):
			for h in BossWorld.census(id, t0 + step * BossWorld.CENSUS):
				if BossWorld.edge(id, int(h[1]), int(h[2])) > 0.0:
					hunters += 1
		if hunters == 0:
			check((kills[id] as Array).is_empty(), "%s: nobody fit hunts there, the boss stays up" % id)
	# The dragon god falls far less often than the ★200 sanctum's boss.
	check(float(down[SkyIsleData.ID]) < float(down[DivineRegionData.ID]) or (kills[DivineRegionData.ID] as Array).is_empty(), "the dragon god seldom falls (%.2f vs %.2f)" % [down[SkyIsleData.ID], down[DivineRegionData.ID]])
	for id in down:
		check(float(down[id]) <= 0.5, "%s: up most of the time (%.2f down)" % [id, down[id]])
	# The same clock, a fresh device: the same kills.
	BossWorld.reset()
	WorldParties.clear_cache()
	var same := true
	for id in first:
		var again: Array = []
		var last := -1.0
		var t := t0
		while t < t0 + 3.0 * 3600.0:
			var s := BossWorld.state(id, t)
			if not s.alive and float(s.killed_at) != last:
				last = float(s.killed_at)
				again.append([float(s.killed_at), String(s.killer)])
			t += 15.0
		if again != first[id]:
			same = false
	check(same, "every device works out the same kills from the clock and the roster")
	# A real kill pushes a world players' try of the same slot out.
	for id in kills:
		if (kills[id] as Array).is_empty():
			continue
		var k: Array = kills[id][0]
		BossWorld.record_kill(id, "BossQA", float(k[0]) - 5.0, false)
		var s := BossWorld.state(id, float(k[0]) + 1.0)
		check(String(s.killer) == "BossQA", "%s: the boss was already down from a real kill, the world players' try did not happen" % id)
		var r := BossWorld.recent(float(k[0]) + 1.0)
		check(r.any(func(x): return StringName(x.zone) == id and String(x.killer) == "BossQA"), "recent() (the chat's list) tells the truth")
		break
	BossWorld.reset()
	BossWorld.ai_mode = 0


func _online() -> void:
	at(float(WorldPlayers.START_UNIX) + 22.0 * 86400.0)
	BossWorld.reset()
	Game.profile[BossWorld.KEY] = {}
	GameSettings.online_play = true
	var fake := FakeTransport.new()
	Online.use_transport(fake)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "bossqa"}, "players": [], "party": null})
	check(Online.is_online(), "online with a stand-in socket")
	var zone: Zone = await _field(&"meadow")
	zone._tick_boss(0.1)
	var boss: Mob = zone._boss
	if boss != null:
		boss.take_hit(boss.hp + 10, false, Color.WHITE, zone.hero)
	var sent := fake.frames("boss_kill")
	check(sent.size() == 1 and String(sent[0].zone) == "meadow" and String(sent[0].by) == "" and String(sent[0].ai) == "", "the game running the zone tells the server: fields only (%s)" % str(sent))
	zone.queue_free()
	await get_tree().process_frame
	Online.use_transport(null)
	GameSettings.online_play = false
