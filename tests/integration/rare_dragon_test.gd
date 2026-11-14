extends Node
## The rare dragon of เกาะลอยฟ้าเทพมังกร (WorldEvents.rare_*, RareDragon; headless):
## - the schedule: 4 to 6 windows of 10 minutes a Thai day, at whole minutes that differ
##   from day to day, never close together, read off the clock (the same on every device);
## - in the zone flagged "rare_dragon": it comes in the window's camp, a boss as strong as
##   the field's own times HP_SCALE, crystal-dressed with its pillar of light, alone;
##   the alert (banner, toast), the minimap diamond, the HUD chip line and the
##   server-wide announcement (Announcer, kind "rare");
## - the prize (SkyIsleLoot.rare_drops) goes to the hero that dealt most of the damage,
##   once a window; world players join only behind the hero's side and hold back;
## - it flies off when the window ends, nothing of it is left behind, a mirror of it
##   (online) is dressed the same and a new host takes it over;
## - never below the zone's star gate or in a zone without the flag; its cost.
##   godot --headless --path . res://tests/integration/rare_dragon_test.tscn
var failures := 0
var checks := 0


## A zone that records its drops instead of putting them on the ground.
class LootZone:
	extends Zone
	var items: Array[Dictionary] = []
	var gold_piles: Array[int] = []
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


func at(t: float) -> void:
	WorldPresence.clock_offset = t - WorldPlayers.now()


func _ready() -> void:
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	Game.new_profile(&"warrior", "Rare QA")
	ZoneData.ensure()
	_schedule()
	await _zone()
	await _gates()
	WorldPresence.clock_offset = 0.0
	print("RARE DRAGON: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _schedule() -> void:
	var day0 := WorldEvents.day_of(thai(2026, 11, 16, 12))
	var counts := {}
	var minutes := {}
	var total := 0
	var ok_count := true
	var ok_order := true
	var ok_gap := true
	var ok_minute := true
	var ok_now := true
	var ids := {}
	var last_end := -INF
	for d in 60:
		var day := day0 + d
		var starts := WorldEvents.rare_windows(day)
		var midnight := float(day) * 86400.0 - float(WorldPlayers.TZ)
		counts[starts.size()] = true
		ok_count = ok_count and starts.size() == WorldEvents.rare_count(day) and starts.size() >= WorldEvents.RARE_MIN and starts.size() <= WorldEvents.RARE_MAX
		for k in starts.size():
			var s: float = starts[k]
			total += 1
			ok_order = ok_order and s >= midnight and s + float(WorldEvents.RARE_LENGTH) <= midnight + 86400.0 and WorldEvents.day_of(s) == day
			ok_gap = ok_gap and s - last_end >= float(WorldEvents.RARE_GAP)
			last_end = s + float(WorldEvents.RARE_LENGTH)
			ok_minute = ok_minute and is_zero_approx(fmod(s - midnight, 60.0))
			minutes[int(s - midnight) / 60] = true
			var mid := WorldEvents.rare_now(s + 300.0)
			ok_now = ok_now and not mid.is_empty() and float(mid.start) == s and float(mid.until) == s + float(WorldEvents.RARE_LENGTH) \
				and WorldEvents.rare_now(s - 1.0).is_empty() and WorldEvents.rare_now(s + float(WorldEvents.RARE_LENGTH)).is_empty() and not WorldEvents.rare_now(s).is_empty()
			if not mid.is_empty():
				ok_now = ok_now and not ids.has(int(mid.window))
				ids[int(mid.window)] = true
	check(ok_count, "4 to 6 windows every Thai day")
	check(counts.size() == WorldEvents.RARE_MAX - WorldEvents.RARE_MIN + 1, "some days 4, some 5, some 6 (%s)" % str(counts.keys()))
	check(ok_order, "every window lies inside its own Thai day")
	check(ok_gap, "two windows are never closer than RARE_GAP")
	check(ok_minute, "a window opens on a whole minute")
	check(ok_now, "rare_now holds from the start for 10 minutes, with a number of its own")
	check(WorldEvents.RARE_LENGTH == 600, "about 10 minutes each")
	check(float(minutes.size()) >= float(total) * 0.85, "the minute of the day is not a habit (%d different in %d windows)" % [minutes.size(), total])
	# No hour of the day is left out over two months, none takes more than its share.
	var hours := {}
	for m in minutes:
		hours[int(m) / 60] = int(hours.get(int(m) / 60, 0)) + 1
	check(hours.size() >= 20, "the windows fall all round the clock (%d different hours)" % hours.size())
	# The same for every device: nothing but the clock goes in, and the values are pinned
	# (a change of the hash would move every player's schedule).
	var again := WorldEvents.rare_windows(day0)
	check(again == WorldEvents.rare_windows(day0) and WorldEvents.rare_count(day0) == again.size(), "the same answer every time it is asked")
	var pinned: Array = []
	for s in again:
		pinned.append(int(s - (float(day0) * 86400.0 - float(WorldPlayers.TZ))) / 60)
	print("rare_dragon_test: 16 Nov 2026 opens at minutes %s; next after noon in %d s" % [str(pinned), int(WorldEvents.rare_next(thai(2026, 11, 16, 12)) - thai(2026, 11, 16, 12))])
	check(pinned == PINNED, "16 Nov 2026 opens at the pinned minutes %s (got %s)" % [str(PINNED), str(pinned)])
	check(WorldEvents.rare_next(again[0] - 5.0) == again[0] and WorldEvents.rare_next(again[-1] + 5.0) == WorldEvents.rare_windows(day0 + 1)[0], "rare_next finds the next opening, over midnight too")
	var camps := {}
	for w in ids:
		camps[WorldEvents.rare_camp(int(w), 5)] = true
	check(camps.size() == 5, "every camp gets its turn")


## Minutes of the Thai day the windows of 16 Nov 2026 open at.
const PINNED := [21, 471, 603, 895, 1175]


func _rares(zone: Zone) -> int:
	var count := 0
	for child in zone.get_children():
		var mob := child as Mob
		if mob and mob.has_meta(RareDragon.META) and not mob.is_dead() and not mob.is_queued_for_deletion():
			count += 1
	return count


func _build(id: StringName) -> LootZone:
	Game.current_zone = id
	Game.profile["spawn_override"] = ""
	var zone := LootZone.new()
	zone.zone_id = id
	zone.layout_seed = 7
	add_child(zone)
	zone.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 600:
		if zone.is_built:
			break
		await get_tree().process_frame
	return zone


func _zone() -> void:
	var day := WorldEvents.day_of(thai(2026, 11, 16, 12))
	var starts := WorldEvents.rare_windows(day)
	Game.profile.level = Game.MAX_LEVEL
	Game.paragon().level = SkyIsleData.ENTRY_STAR
	at(starts[1] - 120.0)
	Announcer.reset()
	var zone := await _build(SkyIsleData.ID)
	var node := RareDragon.of(zone)
	check(zone.is_built and node != null and bool(zone.data.get("rare_dragon", false)), "the isle has its rare dragon node")
	if node == null:
		return
	node.set_process(false)
	node.tick()
	check(_rares(zone) == 0 and node.find() == null and WorldEvents.rare_text(WorldPresence.clock()) == "", "nothing outside a window, nothing on the chip")
	var chat: Array = []
	var hear := func(speaker: String, text: String, _c: Color): chat.append([speaker, text])
	Game.world_chat.connect(hear)
	var said: Array = []
	var note := func(text: String, _kind: StringName): said.append(text)
	Game.toast.connect(note)
	var banners: Array = []
	zone.banner_requested.connect(func(text: String): banners.append(text))
	# The window opens.
	at(starts[1] + 20.0)
	var event := WorldEvents.rare_now(WorldPresence.clock())
	var win := int(event.window)
	var rng_state := zone.rng.state
	node.tick()
	var mob := node.find()
	check(mob != null and _rares(zone) == 1 and mob == node.mob and mob.is_inside_tree(), "the dragon appears when its window opens")
	if mob == null:
		return
	check(zone.rng.state == rng_state, "the zone's seeded rolls are untouched")
	check(String(mob.template.name) == WorldEvents.NAME_RARE and mob.monster_id == RareDragon.ID and int(mob.get_meta(RareDragon.META)) == win, "มังกรแก้วเจ็ดสี of window %d" % win)
	check(mob.is_boss and BossAttack.has_moves(mob.template), "a boss with telegraphed moves")
	var camp: Dictionary = zone._camps[WorldEvents.rare_camp(win, zone._camps.size())]
	check(Vector2(mob.global_position.x - float(camp.pos.x), mob.global_position.z - float(camp.pos.y)).length() <= float(camp.radius), "in the window's camp (%s)" % String(camp.get("name", "")))
	var boss := MonsterData.stats_for(StringName(zone.data.boss.monster), int(zone.data.boss.level))
	check(mob.max_hp == int(float(boss.hp) * RareDragon.HP_SCALE) and mob.hp == mob.max_hp and int(mob.stats.atk) == int(float(boss.atk) * RareDragon.ATK_SCALE), "the field boss's strength, %sx its HP (%d)" % [str(RareDragon.HP_SCALE), mob.max_hp])
	check(mob.level == int(zone.data.boss.level), "at the field boss's level")
	# Its look: the god-skill dragon (CelestialDragon "prism") in rainbow crystal, the beacon,
	# a name seen from afar.
	var crystal := mob.visual as CelestialDragonVisual
	check(crystal != null and crystal.kind == "prism" and float(crystal.mat.get_shader_parameter("prism")) >= 1.0, "a crystal eastern dragon, its scales in rainbow facets")
	check(crystal != null and crystal.body_mesh.mesh == CelestialDragon.mesh("prism"), "its body is the one shared crystal dragon mesh")
	var beacon := mob.get_node_or_null("RareBeacon") as Node3D
	var pillar := mob.get_node_or_null("RareBeacon/Pillar") as MeshInstance3D
	check(beacon != null and pillar != null and pillar.material_override == RareDragon.pillar_material() and (pillar.mesh as CylinderMesh).height >= 40.0, "a pillar of light 40 m and more over it")
	check(mob._label.visibility_range_end >= 60.0 and mob._label.modulate == WorldEvents.RARE_COLOR, "its name shows from across the field")
	var lights := mob.find_children("*", "Light3D", true, false).size() + mob.find_children("*", "GPUParticles3D", true, false).size()
	check(lights == 0 and beacon.get_child_count() <= 3, "no lights, no particles, at most 3 beacon nodes")
	# The alert, the minimap, the chip, the server-wide word.
	check(banners.any(func(b): return String(b).contains(WorldEvents.NAME_RARE) and String(b).contains(String(camp.get("name", "")))), "the zone's banner names the camp (%s)" % str(banners))
	var mark := Minimap.mob_marker(mob)
	check(mark[0] == WorldEvents.RARE_COLOR and float(mark[1]) >= 6.0, "a big jade mark on the minimap")
	var chip := WorldEvents.rare_text(WorldPresence.clock())
	check(chip.contains(WorldEvents.NAME_RARE) and chip.contains(SkyIsleData.TITLE) and chip.contains("10 นาที") and WorldEvents.chip_lines(WorldPresence.clock()).has(chip), "the HUD chip counts it down (%s)" % chip)
	chat.clear()
	Announcer.tick(WorldPresence.clock())
	Announcer.tick(WorldPresence.clock() + 1.0)
	var told := Announcer.history.filter(func(e): return String(e.kind) == "rare")
	check(told.size() == 1 and String(told[0].text).contains(WorldEvents.NAME_RARE) and String(told[0].text).contains(SkyIsleData.TITLE), "announced to the server once (%s)" % str(told))
	check(chat.any(func(c): return String(c[0]) == Announcer.SPEAKER and String(c[1]).contains(WorldEvents.NAME_RARE)), "and in the world chat")
	node.tick()
	check(_rares(zone) == 1 and node.find() == mob and banners.size() == 1, "one at a time, alerted once")
	# World players: only behind the hero's side, never more than HELPERS, and they hold back.
	var helpers: Array = []
	for i in 3:
		var p := FieldPlayer.new()
		p.setup_world(i, WorldPlayers.member(i, WorldPresence.clock()), zone.hero, zone)
		zone.add_child(p)
		p.global_position = mob.global_position + Vector3(3.0 + float(i), 0.3, 2.0)
		helpers.append(p)
	check((helpers[0] as FieldPlayer)._join_rare() == null, "a world player leaves it alone until the hero's side fights it")
	mob.take_hit(maxi(1, mob.max_hp / 20), false, Color.WHITE, zone.hero)
	check(mob.party_damage > 0 and (helpers[0] as FieldPlayer)._join_rare() == mob, "then it joins in")
	(helpers[0] as FieldPlayer).target = mob
	(helpers[1] as FieldPlayer).target = mob
	check((helpers[2] as FieldPlayer)._join_rare() == null, "at most %d world players on it at once" % RareDragon.HELPERS)
	mob.others_damage = mob.party_damage
	check((helpers[0] as FieldPlayer)._join_rare() == null, "they hold back once they dealt their share")
	mob.others_damage = 0
	for p in helpers:
		(p as Node).queue_free()
	# The hero brings it down: the prize, the window spent, told to the server.
	chat.clear()
	zone.items.clear()
	var before := Announcer.history.size()
	mob.take_hit(mob.hp, false, Color.WHITE, zone.hero)
	check(mob.is_dead(), "the hero kills it")
	check(node.prizes.size() == 1 and int(node.prizes[0].window) == win, "SkyIsleLoot.rare_drops paid the prize")
	check((node.prizes[0].items as Array).all(func(i): return zone.items.has(i)), "and every item of it is dropped")
	check(WorldEvents.rare_done(win) and int(Game.profile.flags.get(WorldEvents.RARE_FLAG, -1)) == win, "the window is spent for this hero")
	check(Announcer.history.size() > before and Announcer.history.any(func(e): return String(e.kind) == "rare" and String(e.text).contains("ปราบ") and String(e.text).contains("Rare QA")), "the kill is told to the server by name")
	check(not beacon.visible, "the pillar goes out with it")
	check(WorldEvents.rare_text(WorldPresence.clock()) == "", "the chip line goes once it fell")
	check(Game._valid_profile(JSON.parse_string(Marshalls.base64_to_utf8(Game.export_code())) as Dictionary), "a profile with the flag is valid")
	await _clear(zone)
	node.tick()
	check(_rares(zone) == 0 and zone.find_children("RareBeacon", "", true, false).is_empty(), "no second one in the window, nothing left behind")
	node.window = -1
	node.tick()
	check(_rares(zone) == 0, "coming back in the same window: still spent")
	# Once a window per hero: a second fall in the same window pays nothing.
	var again := node.spawn(win)
	before = Announcer.history.filter(func(e): return String(e.text).contains("ปราบ")).size()
	again.take_hit(again.hp, false, Color.WHITE, zone.hero)
	check(node.prizes.size() == 1 and Announcer.history.filter(func(e): return String(e.text).contains("ปราบ")).size() == before, "the prize is once a window per hero")
	await _clear(zone)
	# The next window: someone else did most of the damage, so no prize here.
	at(starts[2] + 5.0)
	node.tick()
	var third := node.find()
	var win3 := int(WorldEvents.rare_now(WorldPresence.clock()).window)
	check(third != null and int(third.get_meta(RareDragon.META)) == win3 and win3 != win, "the next window brings a new one")
	Announcer.tick(WorldPresence.clock())
	check(Announcer.history.filter(func(e): return String(e.text).contains("ปรากฏ")).size() == 2, "and a new announcement")
	if third != null:
		third.party_damage = third.max_hp / 4
		third.others_damage = third.max_hp * 3
		before = Announcer.history.size()
		third.take_hit(third.hp, false, Color.WHITE, zone.hero)
		check(third.party_share() < 0.5 and node.prizes.size() == 1 and Announcer.history.size() == before, "no prize for the smaller share of the damage")
		check(WorldEvents.rare_done(win3), "but the window is spent all the same")
	await _clear(zone)
	# A later window: it flies off when its 10 minutes are over.
	at(starts[3] + 30.0)
	node.tick()
	var fourth := node.find()
	check(fourth != null, "a fourth window")
	said.clear()
	at(starts[3] + float(WorldEvents.RARE_LENGTH) + 2.0)
	node.tick()
	await get_tree().process_frame
	await get_tree().process_frame
	check(_rares(zone) == 0 and node.mob == null and node.find() == null, "it flies off when the window ends")
	check(said.any(func(s): return String(s).contains("หนี")), "and says so (%s)" % str(said))
	check(zone.find_children("RareBeacon", "", true, false).is_empty(), "its pillar goes with it")
	check(not WorldEvents.rare_done(int(WorldEvents.rare_now(starts[3] + 30.0).window)), "an unbeaten window is not marked spent")
	# Online: a mirror of the host's dragon looks the same; a new host takes it over.
	at(WorldEvents.rare_windows(day + 1)[0] + 30.0)
	var win5 := int(WorldEvents.rare_now(WorldPresence.clock()).window)
	var mirror := MirrorMob.new()
	mirror.setup_mirror(null, 77, {"m": String(RareDragon.ID), "lv": 100, "x": 4.0, "z": 6.0, "k": "rare", "win": win5, "hp": 900, "mhp": 1000}, zone.hero)
	zone.add_child(mirror)
	check(mirror.kind == "rare" and int(mirror.get_meta(RareDragon.META, -1)) == win5 and mirror.get_node_or_null("RareBeacon/Pillar") != null, "a mirror wears the pillar too")
	check(Minimap.mob_marker(mirror)[0] == WorldEvents.RARE_COLOR, "and the minimap mark")
	banners.clear()
	node._alerted = -1
	var live := node.find()
	check(live == mirror, "the zone finds the host's dragon")
	if live != null and int(live.get_meta(RareDragon.META, -1)) != node._alerted:
		node._alerted = win5
		node.alert(live)
	check(banners.size() == 1, "the alert sounds for a mirror as well")
	var real := Mob.new()
	real.setup(mirror.monster_id, mirror.level, mirror.home, zone.hero)
	real.set_meta(RareDragon.META, win5)
	real.max_hp = mirror.max_hp
	real.hp = mirror.hp
	mirror.remove_from_group("mobs")
	mirror.queue_free()
	zone.add_child(real)
	zone.adopt_shared(real, "rare")
	check(node.mob == real and node.window == win5 and real.hp == 900 and real.max_hp == 1000 and int(real.stats.atk) == int(float(boss.atk) * RareDragon.ATK_SCALE), "a new host takes it over as it stands, with its real strength")
	check(real.get_node_or_null("RareBeacon/Pillar") != null, "dressed again")
	node.tick()
	check(_rares(zone) == 1, "and no second one beside it")
	# The cost of a tick with the dragon up.
	var t0 := Time.get_ticks_usec()
	for i in 200:
		node.tick()
	var per := float(Time.get_ticks_usec() - t0) / 200.0
	print("rare_dragon_test: a tick costs %.1f usec with the dragon up" % per)
	check(per < 1500.0, "a tick a second stays cheap (%.1f usec)" % per)
	Game.world_chat.disconnect(hear)
	Game.toast.disconnect(note)
	zone.queue_free()
	await get_tree().process_frame


## The test's zone stands still (no tweens): the fallen ones are taken away by hand.
func _clear(zone: Zone) -> void:
	for child in zone.get_children():
		var mob := child as Mob
		if mob != null and mob.has_meta(RareDragon.META) and mob.is_dead():
			mob.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## Never under the star gate, never in a field without the flag.
func _gates() -> void:
	var day := WorldEvents.day_of(thai(2026, 11, 17, 12))
	var starts := WorldEvents.rare_windows(day)
	at(starts[0] + 30.0)
	Game.paragon().level = SkyIsleData.ENTRY_STAR - 1
	var zone := await _build(SkyIsleData.ID)
	var node := RareDragon.of(zone)
	if node != null:
		node.set_process(false)
		node.tick()
	check(node != null and _rares(zone) == 0, "no dragon for a hero under the isle's gate")
	zone.queue_free()
	await get_tree().process_frame
	Game.paragon().level = SkyIsleData.ENTRY_STAR
	var plain := await _build(&"meadow")
	check(RareDragon.of(plain) == null and RareDragon.live(plain) == null and RareDragon.attach(plain) == null, "a field without the flag has no rare dragon")
	plain.queue_free()
	await get_tree().process_frame
