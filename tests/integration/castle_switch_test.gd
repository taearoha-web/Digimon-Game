extends Node
## The castle's one switch and the altar's barrier (headless): the first guild to stand in
## the circle while it is free takes the switch and keeps it while one of it is inside,
## however many of another guild come in; it is free again only when none of the holder is
## left there (fallen or gone), then the next guild in takes it (most bodies, then the
## first to arrive). The barrier is open only for the holder (no capture can start for
## anyone else), comes back for a guild the moment it loses the switch (the count freezes
## where it was, the progress kept) and falls again when it retakes it (the count goes on
## from the same second); the leader leaving the throne room or falling counts for
## nothing. The switch's look follows the holder (ring, light pillar, label, barrier tint;
## neutral when free, flickering and naming the challenger while fought over); the HUD
## shows "สวิตช์: <guild>", "บาเรียเปิดให้ <guild>" and who to clear out of the circle;
## the hero holds the switch by standing in it; the party can be sent to it; a checkpoint
## keeps its holder. Then the AI: attackers post a sturdy squad on the switch, take it and
## capture the castle on their own (a fixed seed); the castle's holder guards it.
## godot --headless --path . res://tests/integration/castle_switch_test.tscn
var failures: Array[String] = []
var checks := 0
const SEED := 424242


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GWS")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_pure_rules()
	await _switch_and_barrier()
	await _resume()
	await _ai_assault()
	print("CASTLE SWITCH: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _pure_rules() -> void:
	# The most bodies inside take it; the holder keeps it on a level count.
	check(GuildWarMatch.switch_next([0, 0], -1) == -1, "an empty circle: nobody holds it")
	check(GuildWarMatch.switch_next([1, 0], -1) == 0 and GuildWarMatch.switch_next([0, 3], -1) == 1, "the first guild in a free circle takes it")
	check(GuildWarMatch.switch_next([1, 5], 0) == 1 and GuildWarMatch.switch_next([1, 5, 4, 3], 0) == 1, "outnumbered, the holder loses it to the most bodies (2 and 4 guilds)")
	check(GuildWarMatch.switch_next([2, 2], 0) == 0 and GuildWarMatch.switch_next([3, 1, 2], 0) == 0, "level or ahead, the holder keeps it")
	check(GuildWarMatch.switch_next([0, 5], 0) == 1 and GuildWarMatch.switch_next([0, 0], 0) == -1, "none of the holder left: the next guild in takes it, or nobody")
	check(GuildWarMatch.switch_next([0, 2, 3, 0], 0) == 2, "several waiting: the most bodies")
	check(GuildWarMatch.switch_next([0, 2, 2, 0], 0, {1: 7, 2: 4}) == 2 and GuildWarMatch.switch_next([0, 2, 2, 0], 0, {1: 3, 2: 4}) == 1, "level: the one that came in first")
	check(GuildWarMatch.switch_next([0, 2, 2], -1) == 1, "level, no arrival known: the lower team")
	var p: Vector3 = SiegeArena.SWITCH
	check(SiegeArena.section(p) == 4 and SiegeArena.hall_rect().has_point(Vector2(p.x, p.z)) and absf(p.x) + SiegeArena.SWITCH_RADIUS < SiegeArena.THRONE_HALF - 1.5 and p.z - SiegeArena.SWITCH_RADIUS > SiegeArena.BACK_Z + 1.5, "the switch stands inside the throne room, clear of the walls")
	check(not SiegeArena.on_altar(p) and Vector2(p.x - SiegeArena.ALTAR.x, p.z - SiegeArena.ALTAR.z).length() > SiegeArena.ALTAR_RADIUS + SiegeArena.SWITCH_RADIUS + 6.0, "the switch is off the altar")
	var door := Vector3(0, 0, SiegeArena.GATE_Z[2])
	check(p.x < -SiegeArena.SWITCH_RADIUS and Vector2(p.x - door.x, p.z - door.z).length() < 25.0, "on one side, a short walk from the door")
	check(SiegeArena.on_switch(p + Vector3(SiegeArena.SWITCH_RADIUS - 0.2, 0, 0)) and not SiegeArena.on_switch(p + Vector3(SiegeArena.SWITCH_RADIUS + 0.3, 0, 0)), "the circle's edge")


## A war with the gates down (a fixed seed), the AI held still.
func _open_war(siege := {}) -> Zone:
	Game.current_zone = &"guildwar"
	var info := {"gates": [0, 0, 0, 0, 0], "owner": -1}
	info.merge(siege, true)
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, info)
	Game.guildwar_resuming = true
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _away(f: GuildFighter) -> void:
	f.global_position = f.spawn_point + Vector3(0, 0.3, 0)


func _in_circle(f: Node3D, k: int) -> void:
	var a := TAU * float(k) / 7.0
	f.global_position = SiegeArena.SWITCH + Vector3(cos(a), 0, sin(a)) * SiegeArena.SWITCH_RADIUS * 0.5 + Vector3(0, 0.3, 0)


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


## The war HUD's lanes at phone landscape sizes (844x390 and its 2x 1688x780): the board,
## the switch row, the warning and the toasts never overlap, the toasts start under the
## board's column, the switch chip's text stays opaque while it flickers, and the
## switch's floating label hides in the board's band.
func _layout(hud: GuildWarHud, m: GuildWarMatch) -> void:
	var toasts := ToastLayer.new()
	add_child(toasts)
	var window := get_window()
	var was := window.size
	# The HUD's own refresh held off (it would take the forced warning down).
	hud._refresh = 1000.0
	for size in [Vector2i(844, 390), Vector2i(1688, 780)]:
		window.size = size
		hud._barrier.text = GuildWarMatch.BARRIER_TEXT
		hud._barrier.visible = true
		Game.say("กิลด์ %s ยึดสวิตช์ได้! บาเรียเปิดให้กิลด์ %s" % [m.team_name(0), m.team_name(0)], &"info")
		await _frames(4)
		var rects := hud.layout_rects()
		var stack := toasts.stack_rect()
		check(rects.has("board") and rects.has("switch_row") and rects.has("warning"), "%s: the board, the switch row and the warning are shown (%s)" % [size, rects.keys()])
		var names: Array = rects.keys()
		for i in names.size():
			for j in range(i + 1, names.size()):
				var a: Rect2 = rects[names[i]]
				var b: Rect2 = rects[names[j]]
				check(not a.grow(-0.5).intersects(b.grow(-0.5)), "%s: %s and %s do not overlap (%s / %s)" % [size, names[i], names[j], a, b])
		check(stack.size.y > 0.0, "%s: a toast is up" % size)
		for key in names:
			check(not (rects[key] as Rect2).grow(-0.5).intersects(stack), "%s: the toast lane is clear of the %s (%s / %s)" % [size, key, stack, rects[key]])
		check(stack.position.y >= hud.band_bottom(), "%s: the toasts start under the board's column (%.0f >= %.0f)" % [size, stack.position.y, hud.band_bottom()])
		var view := get_viewport().get_visible_rect()
		check(view.encloses(hud.layout_rects().board), "%s: the board is on screen (%s in %s)" % [size, rects.board, view])
		# The switch chip while fought over: the text stays fully opaque, the border swings.
		var alphas: Array[float] = []
		var borders: Array[Color] = []
		for i in 8:
			hud._pulse_chip(0.05)
			alphas.append(hud.switch_label_alpha())
			borders.append(hud.switch_chip_color())
		check(m.switch_contested and alphas.all(func(x: float): return x >= 0.999), "%s: the chip's text stays opaque while contested (%s)" % [size, alphas])
		check(borders.any(func(c: Color): return not _same(c, borders[0])), "%s: the chip's border pulses instead" % size)
	# The floating label: hidden while it would sit in the board's band, capped in size.
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = SiegeArena.SWITCH + Vector3(0, 6.5, 2.0)
	cam.look_at(SiegeArena.SWITCH + Vector3(0, -20, 0.5), Vector3.UP)
	m._fit_switch_label()
	var tag := m.switch_label_screen()
	check(not bool(tag.visible), "the switch label hides above the board's lane or under the camera (%s)" % [tag])
	cam.global_position = SiegeArena.SWITCH + Vector3(16, 8, 3)
	cam.look_at(SiegeArena.SWITCH + Vector3(0, 9, 0), Vector3.UP)
	GuildWarHud.top_band = hud.band_bottom()
	ToastLayer.lane_bottom = 0.0
	m._fit_switch_label()
	tag = m.switch_label_screen()
	check(bool(tag.visible) and float(tag.line_px) <= GuildWarMatch.SWITCH_LABEL_MAX_PX + 0.5 and (tag.pos as Vector2).y > GuildWarHud.top_band, "in view under the board: shown, at most %d px a line (%s)" % [GuildWarMatch.SWITCH_LABEL_MAX_PX, tag])
	cam.global_position = SiegeArena.SWITCH + Vector3(3, 7.5, 1.5)
	cam.look_at(SiegeArena.SWITCH + Vector3(0, 6.5, 0), Vector3.UP)
	m._fit_switch_label()
	tag = m.switch_label_screen()
	check(float(tag.line_px) <= GuildWarMatch.SWITCH_LABEL_MAX_PX + 0.5, "up close the label does not fill the screen (%.1f px)" % float(tag.line_px))
	cam.queue_free()
	toasts.queue_free()
	window.size = was
	hud._refresh = 0.0
	hud._update(0.0, false)
	await _frames(2)


func _switch_and_barrier() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.front_gate() == null, "the war opens with the gates down")
	if m == null:
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "the fight begins")
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
		f._dodge = 0.0
		_away(f)
	m.set_process(false)
	check(zone.find_child("CastleSwitch", true, false) != null and zone.find_child("CastleSwitch1", true, false) == null, "one switch pad stands in the castle")
	check(zone.find_child("AltarBarrier", true, false) != null, "the altar has its barrier")
	var lines: Array[String] = []
	m.feed.connect(func(text: String, _t: int): lines.append(text))
	# Nobody on the switch: the barrier stands for both guilds, the switch looks neutral.
	m.read_switches()
	check(m.switch_owner == -1 and m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY), "the switch free: the barrier stands for both")
	check(m._barrier.visible and _same(m._barrier_mat.albedo_color, GuildWarMatch.BARRIER_COLOR), "the barrier dome is shown, pale blue")
	var look := m.switch_look()
	check(_same(look.ring, Color("f2f2f2")) and String(look.label).begins_with("สวิตช์: ว่าง") and float((look.beam as Color).a) < 0.1, "free: a neutral white ring, a faint pillar, the label says ว่าง (%s)" % [look])
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(not m.hero_can_capture() and m.hero_blocked_by_barrier(), "the hero on the altar cannot start behind the barrier")
	m.start_hero_capture()
	check(m.capture.is_empty(), "pressing does nothing behind the barrier")
	check(m.barrier_line() == GuildWarMatch.BARRIER_TEXT, "the HUD warns: %s" % m.barrier_line())
	var toasts: Array[String] = []
	var listen := func(text: String, _kind: StringName): toasts.append(text)
	Game.toast.connect(listen)
	m._altar_hint_tick()
	m._altar_hint_tick()
	check(toasts.filter(func(x: String): return x == GuildWarMatch.BARRIER_TEXT).size() == 1, "the hero is told once why (%s)" % [toasts])
	# The HUD: the switch chip, the barrier chip and the warning.
	var hud := GuildWarHud.new()
	add_child(hud)
	hud.bind(m)
	hud._update(0.0, false)
	check(hud._switch_row.visible and hud.switch_texts()[0] == "สวิตช์: ว่าง" and hud.switch_texts()[1] == "บาเรียปิดแท่น", "the HUD shows the switch free (%s)" % [hud.switch_texts()])
	check(hud.switch_texts()[2] == GuildWarMatch.BARRIER_TEXT, "and the barrier's warning")
	check(_same(hud.switch_chip_color(), Color("c9c9c9")), "the chip is grey while free")
	var ours: Array[GuildFighter] = []
	for f in m.allies:
		ours.append(f)
	var theirs: Array[GuildFighter] = []
	for f in m.enemies:
		if f != m.enemy_leader:
			theirs.append(f)
	check(ours.size() >= 4 and theirs.size() >= 4, "enough fighters for the test (%d / %d)" % [ours.size(), theirs.size()])
	# The first guild in takes it: the barrier opens for it alone.
	toasts.clear()
	Game.toast.connect(listen)
	ours[0].global_position = SiegeArena.SWITCH + Vector3(0.5, 0.3, 0.5)
	m.read_switches()
	Game.toast.disconnect(listen)
	check(m.switch_owner == GuildFighter.TEAM_ALLY and m.holds_switch(GuildFighter.TEAM_ALLY) and not m.barrier_up(GuildFighter.TEAM_ALLY), "a fighter of ours in the circle takes the switch: the barrier opens for us")
	check(m.barrier_up(GuildFighter.TEAM_ENEMY), "it stays up for the other guild")
	check(lines.any(func(t: String): return t.contains("ยึดสวิตช์ได้") and t.contains("บาเรียเปิดให้")), "the feed tells the switch taken and the barrier open (%s)" % [lines])
	check(toasts.any(func(t: String): return t.contains("ยึดสวิตช์ได้! บาเรียเปิดให้กิลด์ %s" % m.team_name(0))), "a toast tells it (%s)" % [toasts])
	var ally_color := m.team_color(GuildFighter.TEAM_ALLY)
	var enemy_color := m.team_color(GuildFighter.TEAM_ENEMY)
	look = m.switch_look()
	check(_same(look.ring, ally_color) and float((look.beam as Color).a) > 0.2 and String(look.label).contains(m.team_name(0)) and String(look.label).contains("บาเรียเปิดให้"), "held: the ring and the pillar in our colour, the label names us (%s)" % [look])
	check(_same(look.label_color, ally_color.lerp(Color.WHITE, 0.2)), "the label is in our colour")
	check(not _same(look.barrier, GuildWarMatch.BARRIER_COLOR) and _same(look.barrier, ally_color.lerp(Color.WHITE, 0.15)), "the barrier is tinted our colour (open for us)")
	hud._update(0.0, false)
	check(hud.switch_texts()[0] == "สวิตช์: เรา" and hud.switch_texts()[1] == "บาเรียเปิดให้ เรา" and _same(hud.switch_chip_color(), ally_color), "the HUD: สวิตช์: เรา, บาเรียเปิดให้ เรา, in our colour (%s)" % [hud.switch_texts()])
	# The hero leads and goes to the altar: the count runs.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(m.hero_can_capture() and m.barrier_line() == "", "the switch held: the hero may take the altar, no warning")
	m.start_hero_capture()
	check(m.capturer() == hero, "the capture starts")
	m._tick_capture(5.0)
	check(is_equal_approx(float(m.capture.progress), 5.0), "the count runs (%.1f)" % float(m.capture.get("progress", 0.0)))
	# Three enemies come into the circle against our one: it stays ours (first come keeps it).
	for i in 3:
		_in_circle(theirs[i], i + 1)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ALLY and m.switch_contested and m.switch_challenger == GuildFighter.TEAM_ENEMY and not m.barrier_up(GuildFighter.TEAM_ALLY), "three enemies against our one inside: still ours, fought over, no barrier")
	check(m.barrier_up(GuildFighter.TEAM_ENEMY), "and still shut for them")
	m._tick_capture(2.0)
	check(is_equal_approx(float(m.capture.progress), 7.0), "the count goes on while ours stays inside (%.1f)" % float(m.capture.progress))
	look = m.switch_look()
	check(String(look.label) == "%s ถือสวิตช์ · %s กำลังแย่ง" % [m.team_name(0), m.team_name(1)], "the label names holder and challenger (%s)" % look.label)
	# The circle flickers between the two colours while fought over.
	var seen_blend := false
	for i in 12:
		m._tick_switches(0.05)
		var ring: Color = m.switch_look().ring
		if not _same(ring, ally_color):
			seen_blend = true
	check(seen_blend, "the ring flickers towards the challenger's colour")
	hud._update(0.0, false)
	check(hud.switch_texts()[0].begins_with("สวิตช์: เรา") and hud.switch_texts()[0].contains("กำลังแย่ง"), "the HUD shows it ours, fought over (%s)" % [hud.switch_texts()])
	await _layout(hud, m)
	check(lines.any(func(t: String): return t.contains("บุกวงสวิตช์")), "the feed tells the fight in the circle")
	# Our one is pushed out: none of ours left, the enemy (inside) takes it; the barrier is
	# back for us, the count freezes.
	_away(ours[0])
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and m.barrier_up(GuildFighter.TEAM_ALLY) and not m.barrier_up(GuildFighter.TEAM_ENEMY), "none of ours left inside: theirs take it, the barrier opens for them alone")
	check(lines.any(func(t: String): return t.contains("ไล่กิลด์ %s ออกจากวงสวิตช์" % m.team_name(0))), "the feed tells who cleared whom")
	m._tick_capture(7.0)
	check(not m.capture.is_empty() and is_equal_approx(float(m.capture.progress), 7.0) and bool(m.capture.barrier) and bool(m.capture.paused), "the count freezes at 7 s, kept (%s)" % m.capture)
	var want := "บาเรียกันแท่นอยู่ — ต้องไล่กิลด์ %s ออกจากวงสวิตช์ก่อน" % m.team_name(1)
	check(m.capture_line().contains("ต้องไล่กิลด์ %s ออกจากวงสวิตช์ก่อน" % m.team_name(1)) and m.barrier_line() == want, "the bar says who to clear out: %s / %s" % [m.capture_line(), m.barrier_line()])
	look = m.switch_look()
	check(_same(look.ring, enemy_color) and String(look.label).contains(m.team_name(1)) and _same(look.barrier, enemy_color.lerp(Color.WHITE, 0.15)), "the look follows the new holder (%s)" % [look])
	hud._update(0.0, false)
	check(hud.switch_texts()[0] == "สวิตช์: ศัตรู" and hud.switch_texts()[1] == "บาเรียเปิดให้ ศัตรู" and hud.switch_texts()[2] == want and _same(hud.switch_chip_color(), enemy_color), "the HUD shows the switch theirs and the warning (%s)" % [hud.switch_texts()])
	check(lines.any(func(t: String): return t.contains("บาเรียกลับมา")), "the feed tells the barrier came back")
	# Ours come back in (two of them) while theirs are still inside: theirs keep it.
	_in_circle(ours[1], 5)
	_in_circle(ours[2], 6)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and m.switch_challenger == GuildFighter.TEAM_ALLY, "ours coming in later do not take it while theirs stand inside")
	# Two of theirs fall, one is pushed out: none of theirs left, ours take it; the count
	# goes on from 7.
	for i in 2:
		var f := theirs[i]
		var tries := 0
		while not f.is_dead() and tries < 80:
			BurstGuard.clear()
			f.take_hit(f.max_hp, false)
			tries += 1
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY, "one of theirs still inside: still theirs")
	_away(theirs[2])
	m.read_switches()
	m._tick_capture(3.0)
	check(m.switch_owner == GuildFighter.TEAM_ALLY and not m.barrier_up(GuildFighter.TEAM_ALLY) and is_equal_approx(float(m.capture.progress), 10.0) and not bool(m.capture.barrier), "theirs cleared out: ours take it back, the count goes on from the same second (%.1f)" % float(m.capture.progress))
	check(lines.any(func(t: String): return t.contains("บาเรียหายไป")), "the feed tells the barrier fell again")
	# Ours leave the circle: free, the barrier is back for everybody, the look is neutral.
	_away(ours[1])
	_away(ours[2])
	m.read_switches()
	m._tick_capture(4.0)
	check(m.switch_owner == -1 and m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY) and is_equal_approx(float(m.capture.progress), 10.0), "nobody inside: the switch is free, no progress")
	look = m.switch_look()
	check(_same(look.ring, Color("f2f2f2")) and _same(look.barrier, GuildWarMatch.BARRIER_COLOR) and String(look.label).begins_with("สวิตช์: ว่าง"), "free again: neutral (%s)" % [look])
	check(lines.any(func(t: String): return t.contains("สวิตช์ว่าง")), "the feed tells the switch is free")
	# The hero holds it by standing in it (and is the leader: an ally holds while it goes up).
	hero.global_position = SiegeArena.SWITCH + Vector3(0, 0.3, 0)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ALLY, "the hero standing in the circle takes it")
	_in_circle(ours[3], 2)
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m.read_switches()
	m._tick_capture(1.0)
	check(m.switch_owner == GuildFighter.TEAM_ALLY and is_equal_approx(float(m.capture.progress), 11.0), "another of ours inside keeps it: on from 10 to 11 (%.1f)" % float(m.capture.progress))
	# Off the yellow circle (still in the room): the count waits.
	hero.global_position = SiegeArena.ALTAR + Vector3(8.0, 0.3, 0)
	m._tick_capture(3.0)
	check(not m.capture.is_empty() and is_equal_approx(float(m.capture.progress), 11.0), "off the circle: no progress")
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m._tick_capture(1.0)
	check(is_equal_approx(float(m.capture.progress), 12.0), "back on: on from 11")
	# Leaving the altar room: no progress (the count is lost, as ever).
	hero.global_position = Vector3(0, 0.3, SiegeArena.GATE_Z[2] + 6.0)
	m._tick_capture(5.0)
	check(m.capture.is_empty() and m.castle_owner == -1, "the leader left the throne room: no progress, the count is gone")
	# The leader falls: no progress either.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m.start_hero_capture()
	m._tick_capture(2.0)
	check(m.capturer() == hero and is_equal_approx(float(m.capture.progress), 2.0), "back up: a new count")
	hero._invulnerable_until = 0
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 1
	hero.take_damage(1.0e9)
	m._tick_capture(5.0)
	check(hero.is_dead() and m.capture.is_empty() and m.castle_owner == -1, "the leader fell: no progress, the count is gone")
	m.hero_respawn_left = 0.0
	m._respawn_hero()
	# The party is sent to the switch.
	var mates := m.hero_party_members()
	if not mates.is_empty():
		var said := m.order_party_switch()
		check(m.party_switch and said == "สั่งปาร์ตี้ไปยืนยึดสวิตช์", "the party is sent to the switch (%s)" % said)
		m.commanders[0].tactic = GuildWarCommander.PUSH
		m._assign_objectives()
		var alive := mates.filter(func(f): return not f.is_dead())
		check(alive.all(func(f): return f.switch_post and f.goal_point.distance_to(SiegeArena.SWITCH) < SiegeArena.SWITCH_RADIUS), "every one of the party is posted in the circle")
		check(m.order_party_switch() != "" and not m.party_switch, "pressed again: back to the guild's plan")
		m._assign_objectives()
		check(alive.all(func(f): return not f.switch_post or m.commanders[0]._posts.has(f.get_instance_id())), "the party is released")
	# A switch holder stays in its circle and keeps out of Summon's reach.
	var post := ours[3]
	post.switch_post = true
	check(not ours[1]._recall_targets().has(post) or ours[1].team != post.team, "a holder is never pulled away by Summon")
	post.switch_post = false
	# The online status carries the switch; a member's war reads it.
	m.read_switches()
	check(m.switch_code() == GuildFighter.TEAM_ALLY, "the status code says who holds it (%d)" % m.switch_code())
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [1, 12.0, true, true], "sw": 3, "ot": false})
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and m.switch_contested and bool(m.capture.get("barrier", false)), "a member's war takes the switch (fought over) and the barrier from the leader's status")
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [], "sw": [0, 1], "ot": false})
	check(m.switch_owner == GuildFighter.TEAM_ALLY and not m.switch_contested, "an older leader's two codes: the left one's")
	# The checkpoint keeps the holder.
	m.save_checkpoint()
	check(int(Game.guildwar_checkpoint().get("switch", -9)) == GuildFighter.TEAM_ALLY, "the checkpoint stores the switch's holder (%s)" % Game.guildwar_checkpoint().get("switch"))
	hud.queue_free()
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


## A resumed war gives the switch back to its saved holder until somebody steps in; an
## older checkpoint of two switches reads as its left one's.
func _resume() -> void:
	var zone := _open_war({"switch": GuildFighter.TEAM_ENEMY})
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "resume: no match")
		return
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and m.barrier_up(GuildFighter.TEAM_ALLY), "resume: the saved holder holds the switch")
	m._timer = 0.05
	await _frames(6)
	m.set_process(false)
	for f in m.all_fighters():
		f.set_physics_process(false)
		_away(f)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY, "resume: kept while nobody is in the circle")
	var mine: GuildFighter = m.allies[0]
	_in_circle(mine, 0)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ALLY, "resume: none of the holder inside, the first one in takes it")
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	# A checkpoint from the two switches' days (gw_r_sw0 / gw_r_sw1, no gw_r_sw).
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	var flags: Dictionary = Game.profile["flags"]
	flags.erase("gw_r_sw")
	flags["gw_r_sw0"] = 2
	flags["gw_r_sw1"] = 1
	check(int(Game.guildwar_checkpoint().get("switch", -9)) == 1, "an old checkpoint with two holders loads its left one's (%s)" % Game.guildwar_checkpoint().get("switch"))
	Game.guildwar_clear_checkpoint()
	check(not flags.has("gw_r_sw0") and not flags.has("gw_r_sw"), "clearing the checkpoint drops the switch keys")


## The AI on its own: theirs storm an undefended castle (ours held at their camp): a
## squad camps on the switch, then the leader goes up, and the castle is theirs. Then,
## holding it, theirs guard the switch: one of theirs inside keeps it against ours.
func _ai_assault() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "ai: no match")
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "ai: the fight begins")
	for f in m.allies:
		f.set_physics_process(false)
		_away(f)
	hero.global_position = GuildWarMatch.hero_camp()
	hero.set_physics_process(false)
	# Theirs start inside the throne room's door.
	var k := 0
	for f in m.enemies:
		f.global_position = Vector3(float(k % 6 - 3) * 1.6, 0.3, SiegeArena.GATE_Z[2] - 4.0 - float(k / 6) * 1.6)
		k += 1
	var theirs: GuildWarCommander = m.commanders[1]
	var posted := false
	var held := false
	var tanks_first := true
	var tactics := {}
	var t0 := Time.get_ticks_msec()
	var war_s := 0.0
	Engine.time_scale = 4.0
	while m.castle_owner < 0 and Time.get_ticks_msec() - t0 < 120000:
		await get_tree().create_timer(0.25, true, false, true).timeout
		m.time_left = GuildWarData.DURATION
		war_s += 0.25 * Engine.time_scale
		tactics[theirs.tactic] = true
		if not theirs.squad.is_empty():
			if not posted:
				# The first one posted is the sturdiest there was.
				var first: GuildFighter = theirs.squad[0]
				if first.role in [GuildWarCommander.ROLE_ASSASSIN, GuildWarCommander.ROLE_BARD] and m.enemies.any(func(f): return f.role == GuildWarCommander.ROLE_TANK and not f.is_leader and not f.is_dead()):
					tanks_first = false
			posted = true
		if m.holds_switch(GuildFighter.TEAM_ENEMY):
			held = true
	Engine.time_scale = 1.0
	print("ai: the castle fell to theirs after about %.0f s of war" % war_s if m.castle_owner == GuildFighter.TEAM_ENEMY else "ai: no capture after %.0f s of war" % war_s)
	check(posted, "ai: theirs post a squad on the switch")
	check(tanks_first, "ai: sturdy ones go first (a tank before an assassin or a bard)")
	check(tactics.has(GuildWarCommander.SECURE), "ai: theirs secure the switch before the leader goes up (%s)" % [tactics.keys()])
	check(held, "ai: theirs hold the switch")
	check(m.castle_owner == GuildFighter.TEAM_ENEMY, "ai: theirs take the castle on their own (owner %d, capture %s, tactic %s)" % [m.castle_owner, m.capture, theirs.tactic])
	check(theirs.said.any(func(t: String): return t.contains("สวิตช์")), "ai: the plan is called in the war chat (%s)" % [theirs.said])
	# Holding the castle, theirs guard the switch.
	m.set_process(false)
	for f in m.all_fighters():
		f.set_physics_process(false)
	for f in m.enemies:
		if f.is_dead():
			f.respawn()
	theirs.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(theirs.contesting and theirs.tactic == GuildWarCommander.DEFEND, "ai: holding the castle theirs defend and guard the switch (%s)" % theirs.tactic)
	var guards := m.enemies.filter(func(f): return f.switch_post)
	check(theirs.squad.size() >= 2 and guards.size() >= 2, "ai: a guard squad on the switch (%d)" % guards.size())
	check(guards.all(func(f): return f.goal_point.distance_to(SiegeArena.SWITCH) < SiegeArena.SWITCH_RADIUS and not f.is_leader), "ai: the guards go into the circle, never the leader")
	# One guard stays in the circle; ours storm in with three: it stays theirs.
	for f in m.enemies:
		if SiegeArena.on_switch(f.global_position):
			f.global_position = SiegeArena.SWITCH + Vector3(0, 0.3, SiegeArena.SWITCH_RADIUS + 4.0)
	var guard: GuildFighter = guards[0]
	_in_circle(guard, 0)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY, "ai: the guard alone holds the switch")
	var storm: Array[GuildFighter] = []
	for f in m.allies:
		if not f.is_dead() and storm.size() < 3:
			storm.append(f)
			_in_circle(f, storm.size())
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and m.switch_contested, "ai: three of ours against one guard inside: still theirs, fought over")
	# Ours focus whoever stands in the circle for them.
	var ours_cmd: GuildWarCommander = m.commanders[0]
	ours_cmd.tactic = GuildWarCommander.SECURE
	ours_cmd.securing = true
	var foc := ours_cmd._pick_focus()
	check(foc == guard, "ai: ours call the guard in the circle as the focus (%s)" % [foc])
	# Rotation: the guard badly hurt with a fresh one of the squad beside it steps out.
	if guards.size() >= 2:
		var fresh: GuildFighter = guards[1]
		_in_circle(fresh, 4)
		guard.hp = int(guard.max_hp * 0.2)
		var before := theirs.rotated
		theirs._plan_switches(theirs.read())
		check(theirs.rotated > before and not theirs.squad.has(guard) and theirs.squad.has(fresh), "ai: a hurt guard rotates out while a fresh one holds the circle")
	# The guards are cleared out: ours take it.
	for f in m.enemies:
		if SiegeArena.on_switch(f.global_position):
			_away(f)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ALLY, "ai: theirs cleared out of the circle, ours take the switch")
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
