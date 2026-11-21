extends Node
## The castle's two switches and the altar's barrier (headless). The switches stand left
## and right of the carpet in the throne room, mirrored (as far from the door and from the
## altar as each other), and the altar against the throne room's back wall. Each switch is
## held on its own: the first guild to stand in its circle while it is free takes it and
## keeps it while one of it is inside, however many of another guild come in; it is free
## again only when none of the holder is left there, then the next guild in takes it (most
## bodies, then the first to arrive). The barrier opens only for a guild holding BOTH
## switches (no capture can start for anyone else; one switch is not enough), comes back
## the moment it loses one (the count freezes where it was, the progress kept) and falls
## again when it holds both again (the count goes on from the same second); split between
## two guilds the barrier stays up for both. The leader leaving the throne room or falling
## counts for nothing. Each switch's look follows its holder (ring, light pillar, label;
## neutral when free, flickering and naming the challenger while fought over), the barrier
## is tinted only for a holder of both; the HUD shows "สวิตช์ซ้าย: <guild>", "สวิตช์ขวา:
## <guild>", "บาเรียเปิดให้ <guild>" and which switch to take or clear; the hero holds a
## switch by standing in it; the party can be sent to the one we lack; the online status
## carries both (an older leader's one code stands for both); a checkpoint keeps both
## holders (an older one's one holder holds both). The "either" rule (the simulator's
## alternative): one switch opens the barrier and the count runs at half speed. Then the
## AI: attackers post a squad on each switch, take both and capture the castle on their
## own (a fixed seed); the castle's holder guards both and retakes a side it lost.
## godot --headless --path . res://tests/integration/castle_switch_test.tscn
var failures: Array[String] = []
var checks := 0
const SEED := 424242
const L := 0
const R := 1


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
	await _either_rule()
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
	# The layout: two switches mirrored left and right, the altar against the back wall.
	check(SiegeArena.SWITCHES.size() == 2 and SiegeArena.SWITCH_NAMES == ["สวิตช์ซ้าย", "สวิตช์ขวา"], "two switches, named left and right")
	var a: Vector3 = SiegeArena.SWITCHES[L]
	var b: Vector3 = SiegeArena.SWITCHES[R]
	check(a.x < -SiegeArena.SWITCH_RADIUS and is_equal_approx(a.x, -b.x) and is_equal_approx(a.z, b.z), "mirrored: the left one at -x, the right one at +x (%s / %s)" % [a, b])
	var door := Vector3(0, 0, SiegeArena.GATE_Z[2])
	for p in [a, b]:
		check(SiegeArena.section(p) == 4 and SiegeArena.hall_rect().has_point(Vector2(p.x, p.z)) and absf(p.x) + SiegeArena.SWITCH_RADIUS < SiegeArena.THRONE_HALF * 0.62 - 1.0 and p.z - SiegeArena.SWITCH_RADIUS > SiegeArena.BACK_Z + 1.5, "the switch %s stands inside the throne room, inside the pillars, clear of the walls" % p)
		check(not SiegeArena.on_altar(p) and Vector2(p.x - SiegeArena.ALTAR.x, p.z - SiegeArena.ALTAR.z).length() > SiegeArena.ALTAR_RADIUS + SiegeArena.SWITCH_RADIUS + 6.0, "the switch is off the altar")
		check(Vector2(p.x - door.x, p.z - door.z).length() < 30.0, "a short walk from the door")
	check(is_equal_approx(a.distance_to(door), b.distance_to(door)) and is_equal_approx(a.distance_to(SiegeArena.ALTAR), b.distance_to(SiegeArena.ALTAR)), "as far from the door and from the altar as each other")
	check(is_zero_approx(SiegeArena.ALTAR.x) and SiegeArena.ALTAR.z - SiegeArena.BACK_Z < 12.0 and SiegeArena.ALTAR.z - SiegeArena.ALTAR_RADIUS - 4.0 > SiegeArena.BACK_Z, "the altar stands in the middle against the back wall, with room behind it (z %.1f, wall %.1f)" % [SiegeArena.ALTAR.z, SiegeArena.BACK_Z])
	check(SiegeArena.ALTAR.z < a.z - 15.0 and SiegeArena.KEEP_CAMP.distance_to(SiegeArena.ALTAR) > 40.0, "the altar is past the switches, far from the holder's camp")
	check(SiegeArena.on_switch(a + Vector3(SiegeArena.SWITCH_RADIUS - 0.2, 0, 0), L) and not SiegeArena.on_switch(a + Vector3(SiegeArena.SWITCH_RADIUS + 0.3, 0, 0)), "the circle's edge")
	check(SiegeArena.switch_at(a) == L and SiegeArena.switch_at(b) == R and SiegeArena.switch_at(SiegeArena.ALTAR) == -1 and not SiegeArena.on_switch(a, R), "which circle a point stands in")
	check(SiegeArena.nearer_switch(Vector3(-3, 0, -100)) == L and SiegeArena.nearer_switch(Vector3(3, 0, -100)) == R, "the nearer switch")


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


func _in_circle(f: Node3D, k: int, side := L) -> void:
	var a := TAU * float(k) / 7.0
	f.global_position = SiegeArena.SWITCHES[side] + Vector3(cos(a), 0, sin(a)) * SiegeArena.SWITCH_RADIUS * 0.5 + Vector3(0, 0.3, 0)


func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _hold_still(m: GuildWarMatch) -> void:
	for f in m.all_fighters():
		f.set_physics_process(false)
		f._guard_until = 0
		f._dodge = 0.0
		_away(f)
	m.set_process(false)


## The war HUD's lanes at phone landscape sizes (844x390 and its 2x 1688x780): the board,
## the switch row (both switches' chips and the barrier's), the warning and the toasts never
## overlap, the toasts start under the board's column, the row fits the screen, a switch
## chip's text stays opaque while it flickers, and a switch's floating label hides in the
## board's band.
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
		Game.say("กิลด์ %s ถือสวิตช์ครบ 2 ฝั่ง! บาเรียเปิดให้กิลด์ %s" % [m.team_name(0), m.team_name(0)], &"info")
		await _frames(4)
		var rects := hud.layout_rects()
		var stack := toasts.stack_rect()
		check(rects.has("board") and rects.has("switch_row") and rects.has("warning"), "%s: the board, the switch row and the warning are shown (%s)" % [size, rects.keys()])
		var names: Array = rects.keys()
		for i in names.size():
			for j in range(i + 1, names.size()):
				var ra: Rect2 = rects[names[i]]
				var rb: Rect2 = rects[names[j]]
				check(not ra.grow(-0.5).intersects(rb.grow(-0.5)), "%s: %s and %s do not overlap (%s / %s)" % [size, names[i], names[j], ra, rb])
		check(stack.size.y > 0.0, "%s: a toast is up" % size)
		for key in names:
			check(not (rects[key] as Rect2).grow(-0.5).intersects(stack), "%s: the toast lane is clear of the %s (%s / %s)" % [size, key, stack, rects[key]])
		check(stack.position.y >= hud.band_bottom(), "%s: the toasts start under the board's column (%.0f >= %.0f)" % [size, stack.position.y, hud.band_bottom()])
		var view := get_viewport().get_visible_rect()
		check(view.encloses(hud.layout_rects().board), "%s: the board is on screen (%s in %s)" % [size, rects.board, view])
		check(view.encloses((rects.switch_row as Rect2).grow(-0.5)), "%s: the switch row (two switches and the barrier) fits the screen (%s in %s)" % [size, rects.switch_row, view])
		# A switch chip while fought over: the text stays fully opaque, the border swings.
		var alphas: Array[float] = []
		var borders: Array[Color] = []
		for i in 8:
			hud._pulse_chip(0.05)
			alphas.append(hud.switch_label_alpha(R))
			borders.append(hud.switch_chip_color(R))
		check(m.switch_contested and alphas.all(func(x: float): return x >= 0.999), "%s: the chip's text stays opaque while contested (%s)" % [size, alphas])
		check(borders.any(func(c: Color): return not _same(c, borders[0])), "%s: the fought-over chip's border pulses instead" % size)
	# The floating label: hidden while it would sit in the board's band, capped in size.
	var at: Vector3 = SiegeArena.switch_top(L)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = at + Vector3(0, 6.5, 2.0)
	cam.look_at(at + Vector3(0, -20, 0.5), Vector3.UP)
	m._fit_switch_label()
	var tag := m.switch_label_screen(L)
	check(not bool(tag.visible), "the switch label hides above the board's lane or under the camera (%s)" % [tag])
	cam.global_position = at + Vector3(16, 8, 3)
	cam.look_at(at + Vector3(0, 9, 0), Vector3.UP)
	GuildWarHud.top_band = hud.band_bottom()
	ToastLayer.lane_bottom = 0.0
	m._fit_switch_label()
	tag = m.switch_label_screen(L)
	check(bool(tag.visible) and float(tag.line_px) <= GuildWarMatch.SWITCH_LABEL_MAX_PX + 0.5 and (tag.pos as Vector2).y > GuildWarHud.top_band, "in view under the board: shown, at most %d px a line (%s)" % [GuildWarMatch.SWITCH_LABEL_MAX_PX, tag])
	cam.global_position = at + Vector3(3, 7.5, 1.5)
	cam.look_at(at + Vector3(0, 6.5, 0), Vector3.UP)
	m._fit_switch_label()
	tag = m.switch_label_screen(L)
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
	_hold_still(m)
	check(zone.find_child("CastleSwitch", true, false) != null and zone.find_child("CastleSwitchRight", true, false) != null, "two switch pads stand in the castle")
	check(zone.find_child("AltarBarrier", true, false) != null and (zone.find_child("AltarBarrier", true, false) as Node3D).position.is_equal_approx(SiegeArena.altar_top()), "the altar at the back, on the raised court, has its barrier")
	var lines: Array[String] = []
	m.feed.connect(func(text: String, _t: int): lines.append(text))
	# Nobody on the switches: the barrier stands for both guilds, the switches look neutral.
	m.read_switches()
	check(m.switch_owners == [-1, -1] and m.switch_owner == -1 and m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY), "the switches free: the barrier stands for both")
	check(m._barrier.visible and _same(m._barrier_mat.albedo_color, GuildWarMatch.BARRIER_COLOR), "the barrier dome is shown, pale blue")
	for k in 2:
		var look0 := m.switch_look(k)
		check(_same(look0.ring, Color("f2f2f2")) and String(look0.label).begins_with("%s: ว่าง" % SiegeArena.SWITCH_NAMES[k]) and float((look0.beam as Color).a) < 0.1, "free: a neutral white ring, a faint pillar, the label says %s: ว่าง (%s)" % [SiegeArena.SWITCH_NAMES[k], look0])
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
	Game.toast.disconnect(listen)
	# The HUD: both switch chips, the barrier chip and the warning.
	var hud := GuildWarHud.new()
	add_child(hud)
	hud.bind(m)
	hud._update(0.0, false)
	check(hud._switch_row.visible and hud.switch_texts()[0] == "สวิตช์ซ้าย: ว่าง" and hud.switch_texts()[1] == "สวิตช์ขวา: ว่าง" and hud.switch_texts()[2] == "บาเรียปิดแท่น", "the HUD shows both switches free (%s)" % [hud.switch_texts()])
	check(hud.switch_texts()[3] == GuildWarMatch.BARRIER_TEXT, "and the barrier's warning")
	check(_same(hud.switch_chip_color(L), Color("c9c9c9")) and _same(hud.switch_chip_color(R), Color("c9c9c9")), "the chips are grey while free")
	var ours: Array[GuildFighter] = []
	for f in m.allies:
		ours.append(f)
	var theirs: Array[GuildFighter] = []
	for f in m.enemies:
		if f != m.enemy_leader:
			theirs.append(f)
	check(ours.size() >= 6 and theirs.size() >= 5, "enough fighters for the test (%d / %d)" % [ours.size(), theirs.size()])
	# The first guild in takes the left one: one switch is not enough, the barrier stays.
	ours[0].global_position = SiegeArena.SWITCHES[L] + Vector3(0.5, 0.3, 0.5)
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, -1] and m.holds_switch(GuildFighter.TEAM_ALLY, L) and not m.holds_switch(GuildFighter.TEAM_ALLY) and m.switches_held(GuildFighter.TEAM_ALLY) == 1, "a fighter of ours in the left circle takes the left switch only")
	check(m.switch_owner == -1 and m.barrier_up(GuildFighter.TEAM_ALLY) and not m.hero_can_capture(), "one switch: the barrier still stands for us (both are needed)")
	check(lines.any(func(t: String): return t.contains("ยึดสวิตช์ซ้ายได้") and t.contains("1/2")), "the feed tells the left switch taken, 1 of 2 (%s)" % [lines])
	check(m.barrier_line().contains("ยึดสวิตช์ขวา") and not m.barrier_line().contains("สวิตช์ซ้าย"), "the warning names the switch still needed (%s)" % m.barrier_line())
	var ally_color := m.team_color(GuildFighter.TEAM_ALLY)
	var enemy_color := m.team_color(GuildFighter.TEAM_ENEMY)
	var look := m.switch_look(L)
	check(_same(look.ring, ally_color) and String(look.label).contains(m.team_name(0)) and String(look.label).contains("1/2"), "held: the left ring in our colour, its label names us, 1/2 (%s)" % [look])
	check(_same(m.switch_look(R).ring, Color("f2f2f2")) and _same(look.barrier, GuildWarMatch.BARRIER_COLOR), "the right one still neutral, the barrier untinted")
	hud._update(0.0, false)
	check(hud.switch_texts()[0] == "สวิตช์ซ้าย: เรา" and hud.switch_texts()[1] == "สวิตช์ขวา: ว่าง" and hud.switch_texts()[2] == "บาเรียปิด (ต้องถือครบ 2 ฝั่ง)", "the HUD: left ours, right free, the barrier shut (%s)" % [hud.switch_texts()])
	check(_same(hud.switch_chip_color(L), ally_color) and _same(hud.switch_chip_color(R), Color("c9c9c9")), "each chip in its holder's colour")
	# Ours take the right one too: both held, the barrier opens for us alone.
	toasts.clear()
	Game.toast.connect(listen)
	ours[1].global_position = SiegeArena.SWITCHES[R] + Vector3(-0.5, 0.3, 0.5)
	m.read_switches()
	Game.toast.disconnect(listen)
	check(m.switch_owner == GuildFighter.TEAM_ALLY and m.holds_switch(GuildFighter.TEAM_ALLY) and not m.barrier_up(GuildFighter.TEAM_ALLY), "both switches ours: the barrier opens for us")
	check(m.barrier_up(GuildFighter.TEAM_ENEMY), "it stays up for the other guild")
	check(lines.any(func(t: String): return t.contains("ถือสวิตช์ครบทั้งซ้ายและขวา") and t.contains("บาเรียเปิดให้")), "the feed tells both held and the barrier open (%s)" % [lines])
	check(toasts.any(func(t: String): return t.contains("ถือสวิตช์ครบ 2 ฝั่ง! บาเรียเปิดให้กิลด์ %s" % m.team_name(0))), "a toast tells it (%s)" % [toasts])
	look = m.switch_look(R)
	check(_same(look.ring, ally_color) and float((look.beam as Color).a) > 0.2 and String(look.label).contains("บาเรียเปิด"), "both held: the label says the barrier is open (%s)" % [look])
	check(_same(look.label_color, ally_color.lerp(Color.WHITE, 0.2)), "the label is in our colour")
	check(_same(look.barrier, ally_color.lerp(Color.WHITE, 0.15)), "the barrier is tinted our colour (open for us)")
	hud._update(0.0, false)
	check(hud.switch_texts()[1] == "สวิตช์ขวา: เรา" and hud.switch_texts()[2] == "บาเรียเปิดให้ เรา" and _same(hud.switch_chip_color(2), ally_color), "the HUD: บาเรียเปิดให้ เรา in our colour (%s)" % [hud.switch_texts()])
	# The hero leads and goes to the altar: the count runs.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(m.hero_can_capture() and m.barrier_line() == "", "both held: the hero may take the altar, no warning")
	m.start_hero_capture()
	check(m.capturer() == hero, "the capture starts")
	m._tick_capture(5.0)
	check(is_equal_approx(float(m.capture.progress), 5.0), "the count runs (%.1f)" % float(m.capture.get("progress", 0.0)))
	# Three enemies come into the right circle against our one: it stays ours.
	for i in 3:
		_in_circle(theirs[i], i + 1, R)
	m.read_switches()
	check(m.switch_owners[R] == GuildFighter.TEAM_ALLY and m.switch_challengers[R] == GuildFighter.TEAM_ENEMY and m.switch_contested and not m.barrier_up(GuildFighter.TEAM_ALLY), "three enemies against our one inside the right circle: still ours, fought over, no barrier")
	m._tick_capture(2.0)
	check(is_equal_approx(float(m.capture.progress), 7.0), "the count goes on while ours stays inside (%.1f)" % float(m.capture.progress))
	look = m.switch_look(R)
	check(String(look.label) == "สวิตช์ขวา: %s\n%s กำลังแย่ง" % [m.team_name(0), m.team_name(1)], "the label names holder and challenger (%s)" % look.label)
	var seen_blend := false
	for i in 12:
		m._tick_switches(0.05)
		if not _same(m.switch_look(R).ring, ally_color):
			seen_blend = true
	check(seen_blend and _same(m.switch_look(L).ring, ally_color), "the fought-over ring flickers towards the challenger's colour, the other stays")
	hud._update(0.0, false)
	check(hud.switch_texts()[1].begins_with("สวิตช์ขวา: เรา") and hud.switch_texts()[1].contains("แย่ง"), "the HUD shows the right one ours, fought over (%s)" % [hud.switch_texts()])
	await _layout(hud, m)
	check(lines.any(func(t: String): return t.contains("บุกสวิตช์ขวา")), "the feed tells the fight in the right circle")
	# Our one on the right is pushed out: theirs take the right one; the switches are split,
	# the barrier is back for everybody, the count freezes.
	_away(ours[1])
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY] and m.switch_owner == -1, "split: the left ours, the right theirs")
	check(m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY), "split switches: the barrier stands for both guilds")
	check(lines.any(func(t: String): return t.contains("ชิงสวิตช์ขวาจากกิลด์ %s" % m.team_name(0))) and lines.any(func(t: String): return t.contains("บาเรียกลับมา")), "the feed tells who cleared whom and the barrier back")
	m._tick_capture(7.0)
	check(not m.capture.is_empty() and is_equal_approx(float(m.capture.progress), 7.0) and bool(m.capture.barrier) and bool(m.capture.paused), "the count freezes at 7 s, kept (%s)" % m.capture)
	var want := "บาเรียกันแท่นอยู่ — ต้องถือสวิตช์ครบ 2 ฝั่ง: ไล่กิลด์ %s ออกจากสวิตช์ขวา" % m.team_name(1)
	check(m.barrier_line() == want and m.capture_line().contains("ไล่กิลด์ %s ออกจากสวิตช์ขวา" % m.team_name(1)), "the bar says which circle to clear: %s / %s" % [m.capture_line(), m.barrier_line()])
	look = m.switch_look(R)
	check(_same(look.ring, enemy_color) and _same(look.barrier, GuildWarMatch.BARRIER_COLOR), "the right ring in their colour, the barrier untinted (open for nobody) (%s)" % [look])
	hud._update(0.0, false)
	check(hud.switch_texts()[1] == "สวิตช์ขวา: ศัตรู" and hud.switch_texts()[2] == "บาเรียปิด (ต้องถือครบ 2 ฝั่ง)" and hud.switch_texts()[3] == want and _same(hud.switch_chip_color(R), enemy_color), "the HUD shows the split and the warning (%s)" % [hud.switch_texts()])
	# Theirs take the left one too (ours cleared out): the barrier opens for them alone.
	_away(ours[0])
	_in_circle(theirs[3], 0, L)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY and not m.barrier_up(GuildFighter.TEAM_ENEMY) and m.barrier_up(GuildFighter.TEAM_ALLY), "both theirs: the barrier opens for them alone")
	check(_same(m.switch_look(L).barrier, enemy_color.lerp(Color.WHITE, 0.15)), "the barrier tinted their colour")
	# Ours come back into the left one while theirs are still inside: theirs keep it.
	_in_circle(ours[2], 5, L)
	_in_circle(ours[3], 6, L)
	m.read_switches()
	check(m.switch_owners[L] == GuildFighter.TEAM_ENEMY and m.switch_challengers[L] == GuildFighter.TEAM_ALLY, "ours coming in later do not take it while theirs stand inside")
	# Theirs cleared out of the left one: split again; then ours clear the right one too
	# and the count goes on from 7.
	_away(theirs[3])
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY] and m.barrier_up(GuildFighter.TEAM_ALLY), "the left back to ours: split, still shut for us")
	for i in 2:
		var f := theirs[i]
		var tries := 0
		while not f.is_dead() and tries < 80:
			BurstGuard.clear()
			f.take_hit(f.max_hp, false)
			tries += 1
	m.read_switches()
	check(m.switch_owners[R] == GuildFighter.TEAM_ENEMY, "one of theirs still inside the right circle: still theirs")
	_away(theirs[2])
	_in_circle(ours[4], 1, R)
	m.read_switches()
	m._tick_capture(3.0)
	check(m.switch_owner == GuildFighter.TEAM_ALLY and not m.barrier_up(GuildFighter.TEAM_ALLY) and is_equal_approx(float(m.capture.progress), 10.0) and not bool(m.capture.barrier), "both ours again: the count goes on from the same second (%.1f)" % float(m.capture.progress))
	check(lines.any(func(t: String): return t.contains("บาเรียหายไป")), "the feed tells the barrier fell again")
	# Ours leave the right circle: it is free, the barrier is back.
	_away(ours[4])
	m.read_switches()
	m._tick_capture(4.0)
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, -1] and m.barrier_up(GuildFighter.TEAM_ALLY) and is_equal_approx(float(m.capture.progress), 10.0), "the right one free: the barrier is back, no progress")
	check(_same(m.switch_look(R).ring, Color("f2f2f2")) and String(m.switch_look(R).label).begins_with("สวิตช์ขวา: ว่าง"), "free again: neutral")
	check(lines.any(func(t: String): return t.contains("สวิตช์ขวาว่าง")), "the feed tells the right switch is free")
	# The hero holds the right one by standing in it (an ally holds while it goes up).
	hero.global_position = SiegeArena.SWITCHES[R] + Vector3(0, 0.3, 0)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ALLY, "the hero standing in the right circle takes it")
	_in_circle(ours[5], 2, R)
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
	# The party is sent to the switch our guild lacks.
	var mates := m.hero_party_members()
	if not mates.is_empty():
		_away(ours[5])
		m.read_switches()
		check(m.switch_owners == [GuildFighter.TEAM_ALLY, -1], "the right one free again")
		var said := m.order_party_switch()
		check(m.party_switch and m.party_switch_side == R and said == "สั่งปาร์ตี้ไปยืนยึดสวิตช์ขวา", "the party is sent to the switch we lack (%s)" % said)
		m.commanders[0].tactic = GuildWarCommander.PUSH
		m._assign_objectives()
		var alive := mates.filter(func(f): return not f.is_dead())
		check(alive.all(func(f): return f.switch_post and f.switch_side == R and f.goal_point.distance_to(SiegeArena.SWITCHES[R]) < SiegeArena.SWITCH_RADIUS), "every one of the party is posted in the right circle")
		check(m.order_party_switch() != "" and not m.party_switch, "pressed again: back to the guild's plan")
		m._assign_objectives()
		check(alive.all(func(f): return not f.switch_post or m.commanders[0]._posts.has(f.get_instance_id())), "the party is released")
	# A switch holder stays in its circle and keeps out of Summon's reach.
	var post := ours[3]
	post.switch_post = true
	check(not ours[1]._recall_targets().has(post) or ours[1].team != post.team, "a holder is never pulled away by Summon")
	post.switch_post = false
	# The online status carries both switches; a member's war reads them.
	_in_circle(ours[5], 2, R)
	_in_circle(theirs[4], 3, R)
	_in_circle(ours[2], 5, L)
	m.read_switches()
	check(m.switch_code() == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ALLY + 2], "the status codes say who holds each (left ours, right ours fought over: %s)" % [m.switch_code()])
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [0, 12.0, true, true], "sw": [0, 3], "ot": false})
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY] and m.switch_contested and m.barrier_up(GuildFighter.TEAM_ALLY) and bool(m.capture.get("barrier", false)), "a member's war takes both switches (the right one theirs, fought over) and the barrier from the leader's status")
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [], "sw": 1, "ot": false})
	check(m.switch_owners == [GuildFighter.TEAM_ENEMY, GuildFighter.TEAM_ENEMY] and m.switch_owner == GuildFighter.TEAM_ENEMY and not m.switch_contested, "an older leader's one code (its one switch) stands for both")
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0, 0, 0], "o": -1, "cp": [], "sw": [1, 1], "swa": [[2, -1], [3, 0]], "ot": false})
	check(m.switch_owners == [-1, 0] or m.team_count() < 4, "a league's swa (absolute owners) is clamped to the guilds there are")
	# The checkpoint keeps both holders (the left one also where an older build reads it).
	m.mirror_sync("gw", {"st": "fight", "tl": 100.0, "s": [0, 0], "o": -1, "cp": [], "sw": [0, 1], "ot": false})
	m.save_checkpoint()
	var ck := Game.guildwar_checkpoint()
	check(int(ck.get("switch", -9)) == GuildFighter.TEAM_ALLY and Array(ck.get("switches", [])) == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY], "the checkpoint stores both holders (%s / %s)" % [ck.get("switch"), ck.get("switches")])
	hud.queue_free()
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


## The "either" rule (kept for the simulator's comparison): one switch opens the barrier
## and the count runs at EITHER_RATE; both at full speed; none: shut.
func _either_rule() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "either: no match")
		return
	m._timer = 0.05
	await _frames(6)
	_hold_still(m)
	GuildWarMatch.switch_rule = GuildWarMatch.RULE_EITHER
	var hero: Hero = zone.hero
	var ours: Array = m.allies
	_in_circle(ours[0], 0, L)
	m.read_switches()
	check(not m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY) and is_equal_approx(m.capture_rate(GuildFighter.TEAM_ALLY), GuildWarMatch.EITHER_RATE), "either: one switch opens the barrier, the count at half speed")
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m.start_hero_capture()
	m._tick_capture(4.0)
	check(is_equal_approx(float(m.capture.get("progress", -1.0)), 4.0 * GuildWarMatch.EITHER_RATE), "either: 4 s with one switch count %.1f (%s)" % [4.0 * GuildWarMatch.EITHER_RATE, m.capture])
	_in_circle(ours[1], 1, R)
	m.read_switches()
	m._tick_capture(2.0)
	check(is_equal_approx(float(m.capture.progress), 4.0 * GuildWarMatch.EITHER_RATE + 2.0) and is_equal_approx(m.capture_rate(GuildFighter.TEAM_ALLY), 1.0), "either: with both, full speed")
	GuildWarMatch.switch_rule = GuildWarMatch.RULE_BOTH
	check(not m.barrier_up(GuildFighter.TEAM_ALLY), "the game's rule back (both held: open)")
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


## A resumed war gives each switch back to its saved holder until somebody steps in; an
## older checkpoint's one switch holds both; one of the two switches' first days keeps both.
func _resume() -> void:
	var zone := _open_war({"switches": [GuildFighter.TEAM_ENEMY, GuildFighter.TEAM_ALLY]})
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "resume: no match")
		return
	check(m.switch_owners == [GuildFighter.TEAM_ENEMY, GuildFighter.TEAM_ALLY] and m.barrier_up(GuildFighter.TEAM_ALLY) and m.barrier_up(GuildFighter.TEAM_ENEMY), "resume: the saved holders hold the switches (split)")
	m._timer = 0.05
	await _frames(6)
	_hold_still(m)
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ENEMY, GuildFighter.TEAM_ALLY], "resume: kept while nobody is in the circles")
	var mine: GuildFighter = m.allies[0]
	_in_circle(mine, 0, L)
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ALLY] and not m.barrier_up(GuildFighter.TEAM_ALLY), "resume: none of the holder inside, the first one in takes it (both ours)")
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
	# A checkpoint of the one switch (gw_r_sw, no gw_r_sw1): its holder holds both.
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	var flags: Dictionary = Game.profile["flags"]
	flags["gw_r_sw"] = 2
	flags.erase("gw_r_sw1")
	check(int(Game.guildwar_checkpoint().get("switch", -9)) == 1 and Array(Game.guildwar_checkpoint().get("switches", [])) == [1, 1], "an old checkpoint of the one switch: its holder holds both (%s)" % [Game.guildwar_checkpoint().get("switches")])
	# From the two switches' first days (gw_r_sw0 / gw_r_sw1, no gw_r_sw).
	flags.erase("gw_r_sw")
	flags["gw_r_sw0"] = 2
	flags["gw_r_sw1"] = 1
	check(int(Game.guildwar_checkpoint().get("switch", -9)) == 1 and Array(Game.guildwar_checkpoint().get("switches", [])) == [1, 0], "an old checkpoint with two holders loads both (%s)" % [Game.guildwar_checkpoint().get("switches")])
	Game.guildwar_clear_checkpoint()
	check(not flags.has("gw_r_sw0") and not flags.has("gw_r_sw") and not flags.has("gw_r_sw1"), "clearing the checkpoint drops the switch keys")


## The AI on its own: theirs storm an undefended castle (ours held at their camp): a squad
## camps on each switch, then the leader goes up, and the castle is theirs. Then, holding
## it, theirs guard both switches: one of theirs inside keeps a switch against ours.
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
	var both_posted := false
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
			var sides := {}
			for f in theirs.squad:
				sides[theirs.side_of(f)] = true
			both_posted = both_posted or sides.size() == 2
		if m.holds_switch(GuildFighter.TEAM_ENEMY):
			held = true
	Engine.time_scale = 1.0
	print("ai: the castle fell to theirs after about %.0f s of war" % war_s if m.castle_owner == GuildFighter.TEAM_ENEMY else "ai: no capture after %.0f s of war" % war_s)
	check(posted and both_posted, "ai: theirs post a squad on each switch")
	check(tanks_first, "ai: sturdy ones go first (a tank before an assassin or a bard)")
	check(tactics.has(GuildWarCommander.SECURE), "ai: theirs secure the switches before the leader goes up (%s)" % [tactics.keys()])
	check(held, "ai: theirs hold both switches")
	check(m.castle_owner == GuildFighter.TEAM_ENEMY, "ai: theirs take the castle on their own (owner %d, capture %s, tactic %s)" % [m.castle_owner, m.capture, theirs.tactic])
	check(theirs.said.any(func(t: String): return t.contains("สวิตช์")), "ai: the plan is called in the war chat (%s)" % [theirs.said])
	# Holding the castle, theirs guard both switches.
	m.set_process(false)
	for f in m.all_fighters():
		f.set_physics_process(false)
	for f in m.enemies:
		if f.is_dead():
			f.respawn()
	theirs.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(theirs.contesting and theirs.tactic == GuildWarCommander.DEFEND, "ai: holding the castle theirs defend and guard the switches (%s)" % theirs.tactic)
	var guards := m.enemies.filter(func(f): return f.switch_post)
	var left_guards := guards.filter(func(f): return f.switch_side == L)
	var right_guards := guards.filter(func(f): return f.switch_side == R)
	check(left_guards.size() >= 2 and right_guards.size() >= 2, "ai: a guard squad on each switch (%d left, %d right)" % [left_guards.size(), right_guards.size()])
	check(guards.all(func(f): return f.goal_point.distance_to(SiegeArena.SWITCHES[f.switch_side]) < SiegeArena.SWITCH_RADIUS and not f.is_leader), "ai: the guards go into their circles, never the leader")
	# One guard stays in the left circle; ours storm in with three: it stays theirs.
	for f in m.enemies:
		if SiegeArena.on_switch(f.global_position):
			f.global_position = Vector3(0, 0.3, SiegeArena.GATE_Z[2] - 3.0)
	var guard: GuildFighter = left_guards[0]
	_in_circle(guard, 0, L)
	_in_circle(right_guards[0], 0, R)
	m.read_switches()
	check(m.switch_owner == GuildFighter.TEAM_ENEMY, "ai: one guard on each side holds both switches")
	var storm: Array[GuildFighter] = []
	for f in m.allies:
		if not f.is_dead() and storm.size() < 3:
			storm.append(f)
			_in_circle(f, storm.size(), L)
	m.read_switches()
	check(m.switch_owners[L] == GuildFighter.TEAM_ENEMY and m.switch_contested, "ai: three of ours against one guard inside: still theirs, fought over")
	# Ours focus whoever stands in the circle for them.
	var ours_cmd: GuildWarCommander = m.commanders[0]
	ours_cmd.tactic = GuildWarCommander.SECURE
	ours_cmd.securing = true
	var foc := ours_cmd._pick_focus()
	# Either circle's guard (both switches are theirs: each must fall or be pushed out).
	check(foc == guard or foc == right_guards[0], "ai: ours call a guard in a circle as the focus (%s)" % [foc])
	# Rotation: the guard badly hurt with a fresh one of the same side's squad beside it steps out.
	if left_guards.size() >= 2:
		var fresh: GuildFighter = left_guards[1]
		_in_circle(fresh, 4, L)
		guard.hp = int(guard.max_hp * 0.2)
		var before := theirs.rotated
		theirs._plan_switches(theirs.read())
		check(theirs.rotated > before and not theirs.squad.has(guard) and theirs.squad.has(fresh), "ai: a hurt guard rotates out while a fresh one of its side holds the circle")
	# The left guards are cleared out: ours take the left one; the barrier stays up for us
	# (theirs still hold the right), and theirs send more to win the left one back.
	for f in m.enemies:
		if SiegeArena.on_switch(f.global_position, L):
			_away(f)
	m.read_switches()
	check(m.switch_owners == [GuildFighter.TEAM_ALLY, GuildFighter.TEAM_ENEMY] and m.barrier_up(GuildFighter.TEAM_ALLY), "ai: ours take the left switch, theirs keep the right: still shut for ours")
	theirs._plan_switches(theirs.read())
	var on_left := theirs.squad.filter(func(f): return theirs.side_of(f) == L).size()
	var on_right := theirs.squad.filter(func(f): return theirs.side_of(f) == R).size()
	check(on_left >= on_right and on_left >= 2, "ai: the holder sends at least as many to retake the lost side (%d left, %d right)" % [on_left, on_right])
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()
