extends Node
## The guild war end to end (headless): teams and groups, the countdown, the damage rules
## (war scale, hit cap, burst cap), a fall scoring and the fighter coming back, the hero
## falling and returning, the power orb, sudden death, the result and its pay-out, and the
## ranked-duel opponent (Lv.100 / 200 stars, only the gear grows with the rank).
## godot --headless --path . res://tests/integration/guild_war_match_test.tscn
var failures: Array[String] = []
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GW")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	await _arena_opponents()
	await _war(false)
	await _war(true)
	print("GUILD WAR MATCH: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _arena_opponents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var last_grade := 0
	var skills := {}
	for step in range(0, PvpData.MAX_STEP + 1):
		var rp := step * PvpData.STEP_RP
		var info := PvpData.make_opponent(100, rp, rng, &"warrior")
		var grade := int(info.grade)
		check(int(info.member.level) == 100 and int(info.profile.paragon.level) == 200, "rank %d: the duel opponent is Lv.100 with 200 stars" % step)
		check(grade >= last_grade, "rank %d: gear never gets worse up the ladder" % step)
		check(grade == PvpData.grade_of(rp), "rank %d: grade follows the rank" % step)
		check(is_equal_approx(float(info.difficulty), GuildWarData.SKILL), "rank %d: same sharpness on every rank" % step)
		check(is_equal_approx(float(info.mults.hp), 1.0) and is_equal_approx(float(info.mults.atk), 1.0) and is_equal_approx(float(info.mults.def), 1.0), "rank %d: no stat handicap, like a real player" % step)
		check(info.profile.equip.has("wings") == (grade >= 100), "rank %d: wings exactly from the 100-star grade" % step)
		skills[grade] = true
		last_grade = grade
	check(PvpData.grade_of(0) == 50 and PvpData.grade_of(PvpData.STEP_RP * PvpData.MAX_STEP) == GuildWarData.DIVINE, "the ladder runs from the 50-star set to the divine set")
	check(skills.size() == GuildWarData.GRADES.size(), "every gear grade appears on the ladder")
	check(PvpData.MIN_LEVEL == 100, "ranked duels need Lv.100")


func _war(staged: bool) -> void:
	var label := "staged" if staged else "unstaged"
	Game.current_zone = &"guildwar"
	var gold_before := int(Game.profile.gold)
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.staged = staged
	add_child(zone)
	if staged and not zone.is_built:
		await zone.built
	var m: GuildWarMatch = zone.gw_match
	check(m != null, "%s: the zone makes a match" % label)
	if m == null:
		return
	check(zone.is_built and zone.hero != null, "%s: zone is built" % label)
	check(m.allies.size() == 4 and m.enemies.size() == 5, "%s: hero + 4 allies against 5" % label)
	check(get_tree().get_nodes_in_group("mobs").size() == 5, "%s: only the rival guild is a monster to the hero" % label)
	check(get_tree().get_nodes_in_group("companions").size() == 4, "%s: allies stand with the hero" % label)
	for f in m.allies:
		check(not f.is_in_group("mobs") and f.team == GuildFighter.TEAM_ALLY and f.is_in_group("gw_team0"), "ally is on our side only")
	for f in m.enemies:
		check(f.is_in_group("mobs") and f.is_in_group("gw_team1"), "rival is a monster on the other side")
	check(m.state == "intro", "%s: starts with the countdown" % label)
	var hero: Hero = zone.hero
	# The countdown, then the fight.
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "%s: the fight begins after the countdown" % label)
	for f in m.all_fighters():
		f._guard_until = 0
		# Freeze the AI so the checks below see only what they cause (on a slow machine the
		# fighters would otherwise reach each other and score extra falls in between).
		f.set_physics_process(false)
	# Damage rules: the war scale applies, one hit is capped, a combo is capped.
	var enemy: GuildFighter = m.enemies[0]
	var max_hp := enemy.max_hp
	check(enemy.war_scale == GuildWarData.damage_scale and enemy.war_scale > 1.0, "%s: the war scale is on" % label)
	enemy._dodge = 0.0
	enemy.take_hit(1, false)
	check(max_hp - enemy.hp >= int(GuildWarData.damage_scale) - 1, "%s: damage is multiplied by the war scale (1 -> %d)" % [label, max_hp - enemy.hp])
	var before := enemy.hp
	BurstGuard.clear()
	enemy.take_hit(max_hp * 10, false)
	check(before - enemy.hp <= int(max_hp * BurstGuard.HIT_CAP) + 1, "%s: a huge hit takes at most %d%% of max HP" % [label, int(BurstGuard.HIT_CAP * 100.0)])
	check(not enemy.is_dead(), "%s: nobody is deleted by one hit" % label)
	for i in 8:
		enemy.take_hit(max_hp, false)
	check(float(max_hp - enemy.hp) <= float(max_hp) * (BurstGuard.BURST_CAP + BurstGuard.HIT_CAP) + 2.0 or enemy.is_dead(), "%s: a burst inside two seconds is capped" % label)
	# A fall scores for the other guild and the fighter comes back.
	var feed_lines: Array[String] = []
	m.feed.connect(func(text: String, _t: int): feed_lines.append(text))
	BurstGuard.clear()
	var score_before := m.score[0]
	var guard := 0
	while not enemy.is_dead() and guard < 60:
		BurstGuard.clear()
		enemy.take_hit(max_hp, false)
		guard += 1
	check(enemy.is_dead() and m.score[0] == score_before + 1, "%s: a fall scores a point for our guild" % label)
	check(feed_lines.size() >= 1, "%s: the fall reaches the kill feed" % label)
	check(m.hero_kills == 1, "%s: our own fall is credited to the hero" % label)
	enemy.respawn_left = 0.0
	await _frames(4)
	await get_tree().create_timer(0.1).timeout
	check(not enemy.is_dead() and enemy.hp == enemy.max_hp, "%s: the fighter is back at full health" % label)
	check(enemy.under_guard(), "%s: with a short guard after returning" % label)
	check(enemy.global_position.distance_to(enemy.spawn_point) < 4.0, "%s: at its own base" % label)
	# Our hero falls and returns to base.
	var deaths_before := m.hero_deaths
	var enemy_score := m.score[1]
	hero._invulnerable_until = 0
	Game.profile.hp = 1
	hero.take_damage(1.0e9)
	check(hero.is_dead() and m.hero_deaths == deaths_before + 1 and m.score[1] == enemy_score + 1, "%s: the hero's fall scores for the rivals" % label)
	check(m.hero_respawn_left > 0.0, "%s: and the respawn clock runs" % label)
	m.hero_respawn_left = 0.02
	await _frames(6)
	check(not hero.is_dead() and int(Game.profile.hp) == int(hero.stats.max_hp), "%s: the hero returns at full health" % label)
	check(hero.global_position.distance_to(Vector3(-GuildWarMatch.SPAWN_X, 0.3, 0.0)) < 2.0, "%s: at our base" % label)
	# The power orb.
	m._orb_timer = 0.0
	await _frames(3)
	check(m.orb_active, "%s: the power orb appears" % label)
	hero.global_position = m.orb_position
	await _frames(4)
	check(not m.orb_active and hero._buffs.size() > 0, "%s: taking the orb buffs the hero's guild" % label)
	# Sudden death: tied at the bell, the next fall wins.
	m.score = [3, 3]
	m.time_left = 0.01
	await _frames(4)
	check(m.overtime and m.state == "fight", "%s: a tie at the bell goes to sudden death" % label)
	var finished := {"done": false, "result": {}}
	m.finished.connect(func(r: Dictionary):
		finished.done = true
		finished.result = r)
	var foe: GuildFighter = m.enemies[1]
	for f in m.all_fighters():
		f._guard_until = 0
	foe._dodge = 0.0
	var tries := 0
	while not foe.is_dead() and tries < 60:
		BurstGuard.clear()
		foe.take_hit(foe.max_hp, false)
		tries += 1
	check(m.state in ["ending", "done"], "%s: the next fall ends the war" % label)
	m._end_timer = 0.05
	await get_tree().create_timer(0.4).timeout
	check(finished.done, "%s: the war reports its result" % label)
	var r: Dictionary = finished.result
	check(bool(r.get("won", false)) and int(r.get("score_us", 0)) > int(r.get("score_them", 0)), "%s: we won on the sudden-death fall" % label)
	check(int(r.get("gold", 0)) >= GuildWarData.gold_reward(true, 0) and int(Game.profile.gold) >= gold_before + int(r.gold), "%s: the reward is paid" % label)
	check((r.get("rows", []) as Array).size() == 10, "%s: the scoreboard lists the hero and nine fighters" % label)
	zone.queue_free()
	await _frames(3)
