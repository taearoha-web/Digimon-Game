extends Node
## Watching a guild war (GuildWarSpectate) through the real game (Main): a Lv.30 hero in a
## field opens a live 20 vs 20 war; both guilds are AI and the hero is out of it (hidden,
## no body, never a target, never hurt, no HUD skill bar); the spectator's camera follows,
## pans, zooms (drag / touch / pinch / wheel) and cycles its focus; the clock starts at
## what is left of the war; a short war ends with its result on the board and the league
## hook called when there is one, nothing paid; leaving goes back to the field and the
## spot. Then the hero fights itself with 19 members against 20.
##   XDG_DATA_HOME=/tmp/x godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_spectate_test.tscn
var checks := 0
var failures := 0
var main: Node


## Stands in for GuildLeague.spectated_result (the league's own hook, when it has one).
class Hook:
	extends RefCounted
	var calls: Array = []

	func spectated_result(info: Dictionary, result: Dictionary) -> void:
		calls.append([info, result])


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	Game.set_process(false)
	Game.slot = 1
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await wait(0.2)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.delete_save()
	Game.new_profile(&"warrior", "ผู้ชม")
	Game.profile.level = 30
	Game.profile.hp = Game.stats_now().max_hp
	Game.playing = true
	main.hud.visible = true
	main._traveling = false
	await main.go(&"meadow", true, true)
	await wait(0.3)
	_colors()
	await _watch_from_start()
	await _watch_late()
	await _desk_league_war()
	await _fight_19_and_hero_vs_20()
	GuildWarSpectate.league_hook = null
	print("GUILD WAR SPECTATE: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("PASS")
	get_tree().quit(1 if failures > 0 else 0)


func _info(elapsed: float, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var info := GuildWarSpectate.demo_match(rng, 20)
	info["elapsed"] = elapsed
	info["league_match"] = ["Alpha", "Neverdie"]
	info["slot_start"] = int(Time.get_unix_time_from_system()) - int(elapsed)
	return info


## The guilds' colours: the match_info's own, else the league's, else blue / red.
func _colors() -> void:
	check(GuildWarSpectate.side_color({"ally_color": Color.GREEN}, 0) == Color.GREEN, "a colour given with the war is used")
	check(GuildWarSpectate.side_color({"league_match": [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]}, 1) == WorldPlayers.GUILD_COLORS[WorldPlayers.NEVERDIE], "a league guild id brings its colour")
	check(GuildWarSpectate.side_color({"ally_name": "Alpha"}, 0) == WorldPlayers.GUILD_COLORS[WorldPlayers.ALPHA], "a guild's name brings its colour")
	check(GuildWarSpectate.side_color({"enemy_name": "ไม่มีกิลด์นี้"}, 1) == GuildWarSpectate.ENEMY_FALLBACK, "an unknown guild is red")


## From the first second: the whole clock, the countdown, all gates up, nobody fallen.
func _watch_from_start() -> void:
	var meadow: Zone = main.zone
	check(meadow != null and meadow.zone_id == &"meadow", "the hero starts in a field")
	await GuildWarSpectate.spectate(get_tree(), _info(0.0, 7))
	var zone: Zone = main.zone
	check(zone != null and zone.zone_id == &"guildwar" and zone.watching(), "a Lv.30 hero opens the war to watch (no Lv.100 needed)")
	if zone == null or zone.gw_match == null:
		return
	var m := zone.gw_match
	check(is_equal_approx(m.time_left, GuildWarData.DURATION), "from the start the whole clock is left (%.1f)" % m.time_left)
	check(m.state == "intro" and m.gates_left() == 5 and m.score == [0, 0], "the countdown, five gates, no falls")
	check(m.allies.size() == 20 and m.enemies.size() == 20, "20 vs 20 (%d / %d)" % [m.allies.size(), m.enemies.size()])
	await _leave(&"meadow")


func _watch_late() -> void:
	var gold := int(Game.profile.gold)
	var pink := Game.jewel_count("pink")
	var deaths := int(Game.profile.get("deaths", 0))
	var spot := Vector3(6.0, 0.0, -4.0)
	var meadow: Zone = main.zone
	meadow.hero.global_position = spot + Vector3(0, 0.2, 0)
	await wait(0.3)
	spot = meadow.hero.global_position
	var info := _info(300.0, 11)
	await GuildWarSpectate.spectate(get_tree(), info)
	var zone: Zone = main.zone
	check(zone != null and zone.watching(), "the late war opens")
	if zone == null or zone.gw_match == null:
		return
	var m := zone.gw_match
	var hero := zone.hero
	var view := m.spectator
	# 20 vs 20, both AI, each led by one of its own.
	check(m.all_fighters().size() == 40 and m.allies.size() == 20 and m.enemies.size() == 20, "twenty a side, all AI")
	check(m.ai_leader(0) != null and m.ai_leader(1) != null and not m.hero_leads(), "each guild is led by one of its fighters")
	check(m.ally_name == "Alpha" and m.enemy_name == "Neverdie", "the guilds' names")
	check(m.team_color(1) == WorldPlayers.GUILD_COLORS[WorldPlayers.NEVERDIE], "the guilds' colours")
	# The hero is not in it.
	check(hero.spectating and not hero.visible and hero.is_dead(), "the hero is hidden and out of the war")
	check(hero.process_mode == Node.PROCESS_MODE_DISABLED and hero.collision_layer == 0, "the hero has no body on the field")
	check(not m.hero_alive() and m._strength(0).y == 20, "the hero is not counted on a side")
	for f in m.all_fighters():
		check(f.party != GuildWarMatch.HERO_PARTY and not f.in_hero_party(), "%s is in no party of the hero's" % f.rival_name)
	check(not main.hud.visible, "the hero's HUD (skill bar) is hidden")
	check(view != null and view.camera != null and get_viewport().get_camera_3d() == view.camera, "the spectator's camera is the eye")
	# Late: the clock and the field as they stand.
	check(absf(m.time_left - (GuildWarData.DURATION - 300.0)) < 0.01, "the clock starts at what is left (%.1f)" % m.time_left)
	check(m.tier_open(0) and m.score[0] + m.score[1] > 0, "a late watcher finds the first tier open and falls on the board (%s)" % str(m.score))
	check(view.clock_text() != "", "the board shows the clock")
	# The countdown is short: the war is on.
	await wait(2.0)
	check(m.state == "fight", "the fight is on")
	for f in m.enemies:
		check(not f._targets().has(hero), "%s never aims at the hero" % f.rival_name)
		break
	var hp := int(Game.profile.hp)
	hero.take_damage(999999.0, m.enemies[0])
	check(int(Game.profile.hp) == hp and not hero._dead, "the hero takes no damage")
	await wait(3.0)
	check(int(Game.profile.hp) == hp and m.hero_deaths == 0 and int(Game.profile.get("deaths", 0)) == deaths, "watching, the hero is never hurt and never falls")
	# The camera: moves, pans, zooms, follows a focus.
	var cam_before := view.camera.global_position
	view.pan_by(Vector2(-300, 0))
	await wait(0.6)
	check(view.camera.global_position.distance_to(cam_before) > 2.0, "a drag moves the camera")
	var dist := view._distance_goal
	view.zoom_by(1.5)
	check(view._distance_goal < dist, "zooming in brings it closer")
	await _touch_and_wheel(view)
	var goals: Array[Vector3] = []
	var names: Array[String] = []
	for k in GuildWarSpectate.FOCUS_COUNT:
		goals.append(view.goal)
		names.append(view.focus_button.text)
		view.cycle_focus()
	check(view.focus == GuildWarSpectate.FOCUS_AUTO, "the focus cycles back to following the action")
	check(names[1].contains("ปราสาท") and names[2].contains("Alpha") and names[3].contains("Neverdie"), "the focus button names castle, side A, side B (%s)" % str(names))
	check(goals[1].z < -10.0, "the castle focus looks at the castle (%s)" % str(goals[1]))
	check(goals[2].distance_to(goals[3]) > 0.5 or goals[1].distance_to(goals[2]) > 0.5, "side A and side B are looked at apart")
	view.cycle_focus()
	var before_follow := view.camera.global_position
	await wait(1.0)
	check(view.camera.global_position.distance_to(before_follow) > 0.05, "the camera glides to its focus")
	check(view.view_radius() > view.distance * tan(deg_to_rad(GuildWarSpectate.FOV) * 0.5), "the war draws as far as the view reaches (%.1f m)" % view.view_radius())
	var in_middle := 0
	for f in m.all_fighters():
		if not f.is_dead() and f.global_position.distance_to(view.view_center()) < 6.0:
			in_middle += 1
			check(f.visual.visible, "%s in the middle of the view is drawn" % f.rival_name)
	print("  fighters in the middle of the view: ", in_middle)
	# A short war: the bell rings, the result shows and goes to the league's hook.
	var hook := Hook.new()
	GuildWarSpectate.league_hook = hook
	m.score = [m.score[0] + 3, m.score[1]]
	m.time_left = 1.5
	var t0 := Time.get_ticks_msec()
	while m.state != "done" and Time.get_ticks_msec() - t0 < 20000:
		await wait(0.2)
	check(m.state == "done", "the short war ends")
	check(hook.calls.size() == 1, "the league hook is called once")
	if hook.calls.size() == 1:
		var r: Dictionary = hook.calls[0][1]
		check(bool(r.spectated) and int(r.winner) >= 0 and String(r.winner_name) != "", "the result names the winner (%s)" % str(r.get("winner_name")))
		check(hook.calls[0][0].get("league_match", []) == ["Alpha", "Neverdie"] and r.league_match == ["Alpha", "Neverdie"], "the hook gets the league match")
	check(view.result_shown(), "the board shows the result")
	check(not main.guildwar_screen.is_open, "no war-reward screen for a watcher")
	check(int(Game.profile.gold) == gold and Game.jewel_count("pink") == pink, "watching pays nothing")
	# Without a hook the league is asked only when it has one (no error either way).
	GuildWarSpectate.league_hook = null
	GuildWarSpectate.report(info, {"spectated": true})
	check(GuildWarSpectate.last_result.get("spectated", false), "a report without a hook is kept")
	await _leave(&"meadow")
	var back: Zone = main.zone
	check(back.hero.global_position.distance_to(spot) < 1.5, "back at the spot it watched from (%s)" % str(back.hero.global_position))


## A touch drag pans, two fingers pinch, the wheel zooms (the events the phone and the
## desktop send).
func _touch_and_wheel(view: GuildWarSpectate) -> void:
	var cam := view.camera.global_position
	var center := get_viewport().get_visible_rect().size * 0.5
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = center
	get_viewport().push_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(0, 160)
	drag.relative = Vector2(0, 160)
	get_viewport().push_input(drag)
	await wait(0.6)
	check(view.camera.global_position.distance_to(cam) > 2.0, "a swipe pans the camera")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = center + Vector2(100, 160)
	get_viewport().push_input(second)
	var dist := view._distance_goal
	var pinch := InputEventScreenDrag.new()
	pinch.index = 1
	pinch.position = center + Vector2(300, 160)
	pinch.relative = Vector2(200, 0)
	get_viewport().push_input(pinch)
	check(view._distance_goal < dist, "spreading two fingers zooms in")
	for k in [1, 0]:
		var up := InputEventScreenTouch.new()
		up.index = k
		up.pressed = false
		get_viewport().push_input(up)
	dist = view._distance_goal
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = center
	get_viewport().push_input(wheel)
	check(view._distance_goal > dist, "the wheel zooms out")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = center
	motion.relative = Vector2(120, 0)
	var pan_before := view.pan
	get_viewport().push_input(motion)
	check(view.pan.distance_to(pan_before) > 1.0, "a mouse drag pans")


## Leaves through the board's button: back to `to`, the HUD back, the hero itself again.
func _leave(to: StringName) -> void:
	var zone: Zone = main.zone
	zone.gw_match.spectator.press_leave()
	var t0 := Time.get_ticks_msec()
	while (main.zone == zone or main.zone == null or main._traveling) and Time.get_ticks_msec() - t0 < 30000:
		await wait(0.1)
	var back: Zone = main.zone
	check(back != null and back.zone_id == to, "leaving goes back to %s (%s)" % [to, back.zone_id if back else &"-"])
	if back != null:
		check(main.hud.visible and not back.hero.spectating and back.hero.visible, "the hero and its HUD are back")
		check(Game.current_zone == to, "the game is in %s again" % to)


## The guild-war desk's "ชมการแข่งขัน" on a live league round (GuildLeague.live_round_info):
## all four real guilds in their own colours, the castle with the round's holder, and the
## watched result goes into the league table for that round (GuildLeague.spectated_result),
## with no reward.
func _desk_league_war() -> void:
	GuildWarSpectate.league_hook = null
	var w := GuildLeague.week_of(float(WorldPlayers.START_UNIX) + 21.0 * 86400.0)
	var at := GuildLeague.slot_start(WorldEvents.day_of(GuildLeague.week_start(w)) + 2, 1)
	check(GuildLeague.is_round(at), "a league round is on the schedule")
	check(GuildLeague.spectated_result({"league_round": [1, 2, 3, 4], "slot_start": at + 7}, {"winner": 0}) == 0, "a watched war off the schedule counts nothing")
	WorldPresence.clock_offset = float(at) + 240.0 - WorldPlayers.now()
	var gold := int(Game.profile.gold)
	main.guildwar_screen.watch()
	var t0 := Time.get_ticks_msec()
	while (main.zone == null or not main.zone.watching() or main._traveling) and Time.get_ticks_msec() - t0 < 60000:
		await wait(0.2)
	var zone: Zone = main.zone
	check(zone != null and zone.watching(), "the desk's watch button opens the live league round")
	if zone == null or not zone.watching():
		WorldPresence.clock_offset = 0.0
		return
	var m := zone.gw_match
	check(m.team_count() == 4 and Array(m.team_names) == [GuildLeague.name_of(1), GuildLeague.name_of(2), GuildLeague.name_of(3), GuildLeague.name_of(4)], "the round's four guilds (%s)" % [m.team_names])
	var colours_ok := true
	for t in 4:
		colours_ok = colours_ok and m.team_color(t) == GuildLeague.color_of(t + 1)
	check(colours_ok, "each in its guild colour")
	var held := GuildLeague.start_holder(at)
	check(m.castle_owner == (held - 1 if held > 0 else -1), "the castle is with the round's holder (%d)" % m.castle_owner)
	check(m.side(0).size() == GuildWarData.GUILD_SIDE and m.side(3).size() == GuildWarData.GUILD_SIDE, "twenty a guild (%d / %d)" % [m.side(0).size(), m.side(3).size()])
	check(absf(m.time_left - (GuildWarData.DURATION - 240.0)) < 3.0, "the clock is the round's (%.0f s left)" % m.time_left)
	while m.state != "fight" and Time.get_ticks_msec() - t0 < 90000:
		await wait(0.2)
	m.score[1] += 4
	m.time_left = 1.0
	while m.state != "done" and Time.get_ticks_msec() - t0 < 120000:
		await wait(0.2)
	var r := GuildWarSpectate.last_result
	var recorded := {}
	for e in GuildLeague.real_wars(w):
		if int(e.get("at", -1)) == at and GuildLeague.is_round_record(e):
			recorded = e
	check(not recorded.is_empty(), "the watched result is in the league for that round")
	if not recorded.is_empty():
		check(int(recorded.k1) == int(r.score[0]) and int(recorded.k2) == int(r.score[1]) and int(recorded.own) == held, "as it was watched (%s)" % [recorded])
	check(int(Game.profile.gold) == gold, "watching a league war pays nothing")
	await _leave(&"meadow")
	WorldPresence.clock_offset = 0.0


## The hero plays: 19 of its guild beside it against 20.
func _fight_19_and_hero_vs_20() -> void:
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var roster := GuildWarSpectate.demo_match(rng, 20)
	(roster.ally as Array).resize(19)
	GuildWarMatch.next_roster = roster
	await main.go(&"guildwar", false, true)
	var zone: Zone = main.zone
	check(zone != null and zone.zone_id == &"guildwar" and not zone.watching(), "the hero goes to fight")
	if zone == null or zone.gw_match == null:
		return
	var m := zone.gw_match
	check(m.allies.size() == 19 and m.enemies.size() == 20 and m._strength(0).y == 20 and m._strength(1).y == 20, "19 members and the hero against 20")
	check(main.hud.visible and not zone.hero.spectating and zone.hero.visible, "the hero plays with its HUD")
	check(GuildWarMatch.next_roster.is_empty(), "the given line-ups are used once")
	await wait(6.0)
	check(m.state == "fight", "the 20 vs 20 war runs")
	var drawn := 0
	for f in m.all_fighters():
		drawn += 1 if f.visual.visible else 0
	check(drawn < m.all_fighters().size(), "fighters out of view are not drawn (%d of %d drawn)" % [drawn, m.all_fighters().size()])
	main._traveling = false
	await main.go(&"town", false, true)
