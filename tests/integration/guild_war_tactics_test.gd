extends Node
## The guild war's tactics (GuildWarCommander) and its tough leaders, headless: the plan
## switches on the right triggers (gather -> push, a lost fight -> fall back and come
## again, the other guild on the altar -> defend, ours on it -> guard, the way clear ->
## escort the leader), the focus target (whoever takes the altar, a healer, an exposed
## leader), the formation (tanks in front of the healers along the push axis), both guilds
## on the same brain, rate-limited callouts, staggered stuns, and the leaders: no bonus at
## all (the same stat rules as everyone, the hero with the player's own stats); the AI
## leader is tough by its own build (its earned points spent VIT-heavy, a tank picked
## first), the same with a seed.
## godot --headless --path . res://tests/integration/guild_war_tactics_test.tscn
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
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GWT")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_decisions()
	_focus_rules()
	_formation_rules()
	_leader_build_rules()
	_determinism()
	await _in_war()
	print("GUILD WAR TACTICS: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


## A calm reading: pushing the first gate, everyone up, nobody on the altar.
static func _calm() -> Dictionary:
	return {
		"plan": "rush", "gates_up": true, "holding": false, "enemy_capturing": false, "we_capturing": false,
		"alive_share": 1.0, "loss_heat": 0.0, "kill_heat": 0.0, "leader_ai": true, "leader_alive": true,
		"leader_hp": 1.0, "leader_threat": 0, "leader_in_castle": false,
		"escort": 0, "escort_need": 3, "gathered": 0.2, "at_front": 0.5, "enemies_at_rally": 0,
	}


func _decisions() -> void:
	var s := _calm()
	check(GuildWarCommander.pick_tactic("", 0.0, s) == GuildWarCommander.GATHER, "the war opens with the guild gathering at the rally point")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 3.0, s) == GuildWarCommander.GATHER, "with a fifth of the guild there it keeps waiting")
	s.gathered = 0.7
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 3.0, s) == GuildWarCommander.PUSH, "once most stand at the rally point it pushes together")
	s.gathered = 0.2
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, GuildWarCommander.GATHER_MAX, s) == GuildWarCommander.PUSH, "it never waits more than %d s" % int(GuildWarCommander.GATHER_MAX))
	s.enemies_at_rally = 3
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 1.0, s) == GuildWarCommander.PUSH, "the other guild at the rally point: it fights instead of waiting")
	s = _calm()
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 5.0, s) == GuildWarCommander.PUSH, "pushing, it keeps pushing")
	s.at_front = 0.1
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, GuildWarCommander.PUSH_MIN + 1.0, s) == GuildWarCommander.GATHER, "strung out (trickling in one by one): it gathers again")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 3.0, s) == GuildWarCommander.PUSH, "but not straight after starting a push")
	# A lost fight: fall back, wait for the fallen, come again.
	s = _calm()
	s.loss_heat = 4.0
	s.kill_heat = 1.0
	s.alive_share = 0.5
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 30.0, s) == GuildWarCommander.FALLBACK, "several down and losing the trades: fall back")
	s.loss_heat = 4.0
	s.kill_heat = 3.0
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 30.0, s) == GuildWarCommander.PUSH, "an even trade is not a lost fight")
	s.kill_heat = 1.0
	s.alive_share = 0.9
	check(GuildWarCommander.pick_tactic(GuildWarCommander.FALLBACK, 2.0, s) == GuildWarCommander.FALLBACK, "it holds the fall back a few seconds even when the fallen are back")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.FALLBACK, GuildWarCommander.FALLBACK_MIN + 1.0, s) == GuildWarCommander.GATHER, "the fallen back: it re-engages (gathering first)")
	s.alive_share = 0.5
	check(GuildWarCommander.pick_tactic(GuildWarCommander.FALLBACK, GuildWarCommander.FALLBACK_MIN + 1.0, s) == GuildWarCommander.FALLBACK, "still short: it keeps waiting")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.FALLBACK, GuildWarCommander.FALLBACK_MAX + 1.0, s) != GuildWarCommander.FALLBACK, "never longer than %d s" % int(GuildWarCommander.FALLBACK_MAX))
	s = _calm()
	s.plan = "regroup"
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 10.0, s) == GuildWarCommander.FALLBACK, "the guild's regroup plan pulls everyone back")
	# The altar.
	s = _calm()
	s.enemy_capturing = true
	s.loss_heat = 9.0
	s.alive_share = 0.2
	check(GuildWarCommander.pick_tactic(GuildWarCommander.FALLBACK, 1.0, s) == GuildWarCommander.DEFEND, "the other guild taking the altar: defend it whatever else")
	s = _calm()
	s.we_capturing = true
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 10.0, s) == GuildWarCommander.GUARD, "our leader taking the altar: guard it")
	s = _calm()
	s.leader_hp = 0.2
	s.leader_threat = 2
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 10.0, s) == GuildWarCommander.GUARD, "the leader hurt with enemies on it: the guild guards it")
	s.leader_threat = 0
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 10.0, s) == GuildWarCommander.PUSH, "hurt but safe: no need")
	# Gates down: the AI leader waits for its escort, then goes for the altar inside it.
	s = _calm()
	s.gates_up = false
	s.plan = "storm"
	s.escort = 1
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 10.0, s) == GuildWarCommander.GATHER, "gates down, the leader alone: gather at the throne room's door first")
	s.escort = 3
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 2.0, s) == GuildWarCommander.ESCORT, "with its escort round it the leader goes for the altar")
	s.escort = 0
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, GuildWarCommander.GATHER_MAX, s) == GuildWarCommander.ESCORT, "a capture is never put off for good (no stalemate)")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.ESCORT, 5.0, s) == GuildWarCommander.ESCORT, "once on the way it keeps going")
	s.leader_alive = false
	check(GuildWarCommander.pick_tactic(GuildWarCommander.ESCORT, 5.0, s) == GuildWarCommander.GATHER, "the leader down: gather again until it is back")
	# Our side: the hero leads; the guild escorts the hero once it is in the castle.
	s = _calm()
	s.gates_up = false
	s.plan = "storm"
	s.leader_ai = false
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 2.0, s) == GuildWarCommander.PUSH, "ours with the hero still outside: secure the throne room")
	s.leader_in_castle = true
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 2.0, s) == GuildWarCommander.ESCORT, "the hero in the castle: escort it to the altar")
	s = _calm()
	s.plan = "defend"
	s.holding = true
	check(GuildWarCommander.pick_tactic(GuildWarCommander.PUSH, 2.0, s) == GuildWarCommander.DEFEND, "holding the castle: defend")
	# The castle switches: an AI leader waits for both before it goes up.
	s = _calm()
	s.gates_up = false
	s.plan = "storm"
	s.escort = 3
	s["switches"] = 1
	check(GuildWarCommander.pick_tactic(GuildWarCommander.GATHER, 2.0, s) == GuildWarCommander.SECURE, "gates down, one switch held: secure both before the leader goes up")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.SECURE, 5.0, s) == GuildWarCommander.SECURE, "it keeps securing")
	check(GuildWarCommander.pick_tactic(GuildWarCommander.SECURE, GuildWarCommander.SECURE_MAX + 1.0, s) == GuildWarCommander.ESCORT, "never stuck securing: after %d s the leader goes up and waits" % int(GuildWarCommander.SECURE_MAX))
	s["switches"] = 2
	check(GuildWarCommander.pick_tactic(GuildWarCommander.SECURE, 3.0, s) == GuildWarCommander.ESCORT, "both held: escort the leader into the altar room")
	s["switches"] = 0
	check(GuildWarCommander.pick_tactic(GuildWarCommander.ESCORT, 3.0, s) == GuildWarCommander.ESCORT, "a switch lost on the way: the leader keeps going and waits on the altar")
	# Squad sizes.
	s = _calm()
	s.gates_up = false
	s["standing"] = 12
	check(str(GuildWarCommander.squad_sizes(s, GuildWarCommander.PUSH, [false, false])) == "[2, 2]", "attackers post two on each switch (%s)" % [GuildWarCommander.squad_sizes(s, GuildWarCommander.PUSH, [false, false])])
	s.we_capturing = true
	check(str(GuildWarCommander.squad_sizes(s, GuildWarCommander.GUARD, [true, false])) == "[2, 3]", "a switch lost while taking the altar: one more goes to retake it")
	s = _calm()
	s.gates_up = false
	s.holding = true
	s["standing"] = 12
	check(str(GuildWarCommander.squad_sizes(s, GuildWarCommander.DEFEND, [false, false])) == "[1, 1]", "the holder contests each switch with one")
	s.enemy_capturing = true
	check(str(GuildWarCommander.squad_sizes(s, GuildWarCommander.DEFEND, [false, false])) == "[2, 2]", "the other guild taking the altar: two to each switch")
	s.gates_up = true
	check(str(GuildWarCommander.squad_sizes(s, GuildWarCommander.DEFEND, [false, false])) == "[0, 0]", "gates up: nobody posted")
	check(GuildWarCommander.holder_fit(GuildWarCommander.ROLE_TANK, false) > GuildWarCommander.holder_fit(GuildWarCommander.ROLE_ASSASSIN, false) and GuildWarCommander.holder_fit(GuildWarCommander.ROLE_ASSASSIN, true) > GuildWarCommander.holder_fit(GuildWarCommander.ROLE_HEALER, true), "tanks hold switches, assassins break them")


func _focus_rules() -> void:
	var other := GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_OTHER, 2, false, false)
	var healer := GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_HEALER, 2, false, false)
	var bard := GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_BARD, 2, false, false)
	var exposed := GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_LEADER, 0, false, false)
	var guarded := GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_LEADER, 4, false, false)
	check(healer > bard and bard > other, "the healer first, then the bard, before anyone else")
	check(exposed > healer, "a leader left alone is worth more than the healer")
	check(guarded < healer, "a leader inside its guard is not worth diving")
	check(GuildWarCommander.focus_score(25.0, 1.0, GuildWarCommander.KIND_OTHER, 2, false, true) > exposed, "whoever takes the altar comes before all")
	check(GuildWarCommander.focus_score(10.0, 0.15, GuildWarCommander.KIND_OTHER, 2, false, false) > other + 5.0, "the weak are finished")
	check(GuildWarCommander.focus_score(10.0, 1.0, GuildWarCommander.KIND_HEALER, 2, true, false) < other, "nobody fresh from its base (spawn guard)")


func _formation_rules() -> void:
	var front := Vector3(0, 0, -15)
	var fwd := Vector3(0, 0, -1)
	var tank := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_TANK, 0, 1)
	var ranged := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_RANGED, 0, 1)
	var bard := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_BARD, 0, 1)
	var healer := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_HEALER, 0, 1)
	var lead := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_LEADER, 0, 1)
	check(tank.dot(fwd) > ranged.dot(fwd) and ranged.dot(fwd) > bard.dot(fwd) and bard.dot(fwd) > healer.dot(fwd), "tanks in front, ranged behind them, bard and healer last along the push axis")
	check(lead.dot(fwd) < tank.dot(fwd) - 3.0, "the leader stands well behind its tanks")
	var a := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_TANK, 0, 3)
	var b := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_TANK, 2, 3)
	check(a.distance_to(b) >= 2.0 * GuildWarCommander.SLOT_GAP - 0.01, "a row spreads across the axis (nobody on top of anybody)")
	var far := GuildWarCommander.slot(front, fwd, GuildWarCommander.ROLE_TANK, GuildWarCommander.ROW_WIDTH, GuildWarCommander.ROW_WIDTH + 1)
	check(far.dot(fwd) < tank.dot(fwd), "a long row wraps into a second row behind")
	check(GuildWarCommander.role_of(&"defender", false) == GuildWarCommander.ROLE_TANK and GuildWarCommander.role_of(&"warrior", false) == GuildWarCommander.ROLE_TANK and GuildWarCommander.role_of(&"lancer", false) == GuildWarCommander.ROLE_TANK, "defender, warrior and lancer are tanks")
	check(GuildWarCommander.role_of(&"priest", true) == GuildWarCommander.ROLE_HEALER and GuildWarCommander.role_of(&"bard", true) == GuildWarCommander.ROLE_BARD, "the priest heals, the bard sings")
	check(GuildWarCommander.role_of(&"archer", true) == GuildWarCommander.ROLE_RANGED and GuildWarCommander.role_of(&"mage", true) == GuildWarCommander.ROLE_RANGED and GuildWarCommander.role_of(&"summoner", true) == GuildWarCommander.ROLE_RANGED, "archer, mage and summoner hold the second line")
	check(GuildWarCommander.role_of(&"assassin", false) == GuildWarCommander.ROLE_ASSASSIN, "the assassin dives")


## The AI leader's build: its own points, spent for staying power; a tank leads.
func _leader_build_rules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var plain := GuildWarData.make_fighter(&"defender", 200, "หัวหน้า", rng)
	var tank := GuildWarData.tank_build(plain)
	var total := Game.STAT_POINTS_PER_LEVEL * (GuildWarData.LEVEL - 1)
	var sum := 0
	for key in tank.profile.attrs:
		sum += int(tank.profile.attrs[key])
	var main := String(JobData.resolve(&"defender", int(tank.profile.adv)).main)
	check(sum <= total and sum >= total - 2, "the leader's build spends exactly the points of its level (%d of %d), no extra" % [sum, total])
	check(int(tank.profile.attrs.vit) >= sum * 0.7 and int(tank.profile.attrs.vit) > int(tank.profile.attrs[main]), "and spends them VIT-heavy (vit %d, %s %d)" % [int(tank.profile.attrs.vit), main, int(tank.profile.attrs[main])])
	var stars := 0
	var plain_stars := 0
	for key in tank.profile.paragon.alloc:
		stars += int(tank.profile.paragon.alloc[key])
	for key in plain.profile.paragon.alloc:
		plain_stars += int(plain.profile.paragon.alloc[key])
	check(stars == plain_stars and stars <= int(tank.profile.paragon.level), "its star points add up the same (%d = %d)" % [stars, plain_stars])
	check(int(tank.profile.paragon.alloc.hp) >= int(plain.profile.paragon.alloc.hp) and int(tank.profile.paragon.alloc.def) >= int(plain.profile.paragon.alloc.def), "health and defence first")
	var a := HeroStats.compute(plain.profile)
	var b := HeroStats.compute(tank.profile)
	check(int(b.max_hp) > int(a.max_hp) and float(b.atk) < float(a.atk), "it trades attack for HP (hp %d -> %d, atk %.0f -> %.0f)" % [int(a.max_hp), int(b.max_hp), float(a.atk), float(b.atk)])
	check(plain.profile.attrs.vit != tank.profile.attrs.vit and plain.profile.equip.size() == tank.profile.equip.size(), "the line-up's own sheet is left alone (a copy), same gear")
	# Who leads: a tank class over a damage dealer, never the healer or the bard.
	var lineup := [GuildWarData.make_fighter(&"priest", 300, "ฮีล", rng), GuildWarData.make_fighter(&"mage", 300, "เวท", rng),
		GuildWarData.make_fighter(&"warrior", 200, "นักรบ", rng), GuildWarData.make_fighter(&"bard", 300, "บาร์ด", rng)]
	check(GuildWarData.leader_index(lineup) == 2, "a warrior leads before a mage, a priest or a bard")
	check(GuildWarData.leader_index(lineup, "เวท") == 1, "the guild's real leader leads when it is there")
	check(GuildWarData.leader_index([lineup[0], lineup[3]]) >= 0, "a guild of only support still has a leader")


## The same seed gives the same decisions and the same focus, every time.
func _determinism() -> void:
	var runs: Array = []
	for round_no in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var tactic := ""
		var held := 0.0
		var trail := PackedStringArray()
		for i in 300:
			var s := _calm()
			s.gates_up = rng.randf() < 0.6
			s.plan = ["rush", "hold", "storm", "split", "defend", "regroup"][rng.randi() % 6]
			s.enemy_capturing = rng.randf() < 0.08
			s.we_capturing = not s.enemy_capturing and rng.randf() < 0.08
			s.alive_share = rng.randf()
			s.loss_heat = rng.randf() * 6.0
			s.kill_heat = rng.randf() * 6.0
			s.leader_ai = rng.randf() < 0.5
			s.leader_hp = rng.randf()
			s.leader_threat = rng.randi() % 3
			s.escort = rng.randi() % 5
			s.gathered = rng.randf()
			s.at_front = rng.randf()
			s.enemies_at_rally = rng.randi() % 3
			var next := GuildWarCommander.pick_tactic(tactic, held, s)
			held = 0.0 if next != tactic else held + 1.5
			tactic = next
			var best := -1
			var best_score := -1.0e9
			for k in 6:
				var score := GuildWarCommander.focus_score(rng.randf() * 30.0, rng.randf(), rng.randi() % 4, rng.randi() % 4, rng.randf() < 0.1, false)
				if score > best_score:
					best_score = score
					best = k
			trail.append("%s:%d" % [tactic, best])
		runs.append(trail)
	check(runs[0] == runs[1], "with a seed the commander decides the same way every time")
	var kinds := {}
	for entry in runs[0]:
		kinds[String(entry).get_slice(":", 0)] = true
	check(kinds.size() >= 5, "and the run goes through most tactics (%s)" % [kinds.keys()])


# ---------------------------------------------------------------------------
# In a war
# ---------------------------------------------------------------------------

## The seed of both guilds' line-ups in the war checks (see _in_war).
const ROSTER_SEED := 777


func _in_war() -> void:
	Game.current_zone = &"guildwar"
	var plain_hp := int(HeroStats.compute(Game.profile).max_hp)
	var plain_def := float(HeroStats.compute(Game.profile).def)
	# A fixed roll of both guilds (the war resumes from a checkpoint with this seed, gates
	# whole, nobody holding the castle): the line-ups are random in a real war, and a rare
	# roll made the toughness checks below depend on luck.
	Game.guildwar_save_checkpoint(ROSTER_SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {})
	Game.guildwar_resuming = true
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.commanders.size() == 2, "the war has a commander for each guild")
	if m == null:
		return
	var hero: Hero = zone.hero
	var ours: GuildWarCommander = m.commanders[0]
	var theirs: GuildWarCommander = m.commanders[1]
	check(ours.get_script() == theirs.get_script() and ours.team == 0 and theirs.team == 1, "both guilds run the same brain")
	# Leaders: no bonus. The rival's leader is exactly what its own (tank) sheet gives.
	var lead := m.enemy_leader
	check(lead != null and lead.is_leader and m.enemies.filter(func(f): return f.is_leader).size() == 1, "the rival guild has one leader")
	var base := HeroStats.compute(lead._profile)
	check(lead.max_hp == int(base.max_hp) and is_equal_approx(float(lead.stats.def), float(base.def)) and is_equal_approx(float(lead.rstats.atk), float(base.atk)), "the rival's leader has no multiplier: HP %d = its sheet's %d, DEF and ATK too" % [lead.max_hp, int(base.max_hp)])
	var attr_sum := 0
	for key in lead._profile.attrs:
		attr_sum += int(lead._profile.attrs[key])
	check(attr_sum <= Game.STAT_POINTS_PER_LEVEL * (GuildWarData.LEVEL - 1) and int(lead._profile.attrs.vit) >= attr_sum * 0.7, "its points are its level's, spent VIT-heavy (vit %d of %d)" % [int(lead._profile.attrs.vit), attr_sum])
	check(String(lead.template.name).contains("ผู้นำ"), "its target bar says ผู้นำ (%s)" % lead.template.name)
	check(int(Game.stats_now().max_hp) == plain_hp and is_equal_approx(float(Game.stats_now().def), plain_def) and int(hero.stats.max_hp) == plain_hp, "the hero leads with the player's own stats (HP %d)" % int(hero.stats.max_hp))
	var normal: GuildFighter = null
	for f in m.enemies:
		if not f.is_leader:
			normal = f
			break
	check(normal != null and not String(normal.template.name).contains("ผู้นำ"), "nobody else is named leader")
	var tanky := 0.0
	for f in m.enemies:
		tanky = maxf(tanky, float(f.max_hp) * (1.0 + float(f.rstats.def) / 100.0))
	var lead_tough := float(lead.max_hp) * (1.0 + float(lead.rstats.def) / 100.0)
	check(lead_tough >= tanky * 0.6, "the leader is among its guild's toughest (%.0f vs top %.0f)" % [lead_tough, tanky])
	# The countdown, then the fight; the AI is held still and the match's clock too, so
	# only what each check does happens.
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "the fight begins")
	for f in m.all_fighters():
		f._guard_until = 0
		f._dodge = 0.0
		f.set_physics_process(false)
	m.set_process(false)
	# Stuns: a leader is held as long as anyone (no resistance bonus).
	normal._stun = 0.0
	normal.apply_stun(2.0)
	var plain_stun := normal._stun
	lead._stun = 0.0
	lead.apply_stun(2.0)
	check(is_equal_approx(lead._stun, plain_stun), "a stun holds the leader as long as anyone (%.2f = %.2f s)" % [lead._stun, plain_stun])
	lead._stun = 0.0
	normal._stun = 0.0
	# Formation: everyone gathers at the rally point in rows, tanks in front of healers.
	ours.tactic = GuildWarCommander.GATHER
	theirs.tactic = GuildWarCommander.GATHER
	ours._place()
	theirs._place()
	m._assign_objectives()
	for c in [ours, theirs]:
		var side: Array[GuildFighter] = m.allies if c.team == 0 else m.enemies
		var fwd: Vector3 = c.forward
		var tanks: Array[float] = []
		var backs: Array[float] = []
		for f in side:
			check(f.goal_point.distance_to(c.rally) < 12.0 and f.objective == null, "team %d: %s waits at the rally point" % [c.team, f.rival_name])
			if f.role == GuildWarCommander.ROLE_TANK and not f.is_leader:
				tanks.append(f.goal_point.dot(fwd))
			elif f.role in [GuildWarCommander.ROLE_HEALER, GuildWarCommander.ROLE_BARD, GuildWarCommander.ROLE_RANGED] or f.is_leader:
				backs.append(f.goal_point.dot(fwd))
		if not tanks.is_empty() and not backs.is_empty():
			check(tanks.min() > backs.max(), "team %d: every tank stands ahead of every ranged, healer, bard and the leader (%.1f > %.1f)" % [c.team, tanks.min(), backs.max()])
	check(lead.hold_range > 0.0 and lead.hold_range <= 8.0, "the AI leader does not charge in alone (hold %.0f m)" % lead.hold_range)
	# The pre-fight buffs go out when the push starts.
	for f in m.enemies:
		f.global_position = f.goal_point + Vector3(0, 0.3, 0)
		f.mp = float(f.rstats.max_mp)
		f.cooldowns.clear()
	theirs.since = 0.0
	theirs.think(GuildWarCommander.THINK_EVERY)
	check(theirs.tactic == GuildWarCommander.PUSH, "the guild at the rally point pushes (%s %s)" % [theirs.tactic, theirs.last_read.get("gathered")])
	var buffers := 0
	for f in m.enemies:
		for skill in f.class_data.get("skills", []):
			if String(skill.shape) == "self" and skill.get("fx", {}).get("buff") is Dictionary and f._knows(skill):
				buffers += 1
				break
	check(buffers == 0 or theirs.buffs_called > 0, "and buffs up before it engages (%d with buffs)" % buffers)
	# Focus: their healer, with ours near it, is the call.
	var healer: GuildFighter = null
	for f in m.enemies:
		if f.is_healer() and not f.is_leader:
			healer = f
	if healer == null:
		healer = normal
		healer.member["class"] = "priest"
	var front := ours.front()
	for f in m.enemies:
		f.global_position = front + Vector3(4.0, 0.3, 4.0) if f != healer else front + Vector3(6.0, 0.3, 8.0)
		# A second healer of theirs (some rosters roll two) stays out of the call.
		if f != healer and f.is_healer() and not f.is_leader:
			f.global_position = Vector3(SiegeArena.BASE_X - 30.0, 0.3, 20.0)
	lead.global_position = front + Vector3(4.0, 0.3, 2.0)
	# Earlier steps leave some of theirs hurt; a wounded one would outrank the healer.
	for f in m.enemies:
		f.hp = f.max_hp
	ours.think(GuildWarCommander.THINK_EVERY)
	check(ours.focus == healer, "ours focus the healer of theirs (%s)" % (ours.focus.name if ours.focus != null else "none"))
	m._assign_objectives()
	check(m.allies.all(func(f): return f.focus == healer), "everyone of ours is told the focus")
	# An exposed leader: alone, far from its guild.
	for f in m.enemies:
		if f != lead:
			f.global_position = Vector3(SiegeArena.BASE_X - 30.0, 0.3, 20.0)
	lead.global_position = front + Vector3(2.0, 0.3, 3.0)
	ours.think(GuildWarCommander.THINK_EVERY)
	check(ours.focus == lead, "a leader left alone becomes the focus")
	# Our fighters lean on the focus when choosing whom to hit.
	var striker: GuildFighter = null
	for f in m.allies:
		if f.role == GuildWarCommander.ROLE_RANGED:
			striker = f
	if striker == null:
		striker = m.allies[0]
	striker.global_position = front + Vector3(0, 0.3, 0)
	striker.focus = lead
	striker.hold_range = 0.0
	striker.objective = null
	var decoy := normal
	decoy.global_position = front + Vector3(-1.5, 0.3, -1.0)
	check(striker._nearest_victim() == lead, "a ranged fighter takes the called target over a closer one")
	striker.focus = null
	# The other guild takes the altar: everyone defends it and focuses the one on it.
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m.plans.assign(["storm", "storm"])
	for f in m.enemies:
		f.global_position = SiegeArena.ALTAR + Vector3(6.0, 0.3, 6.0)
	lead.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	# Theirs hold both switches (pinned; castle_switch_test holds them for real).
	m.switch_pin = GuildFighter.TEAM_ENEMY
	m._start_capture(GuildFighter.TEAM_ENEMY, lead)
	ours.think(GuildWarCommander.THINK_EVERY)
	theirs.think(GuildWarCommander.THINK_EVERY)
	check(ours.tactic == GuildWarCommander.DEFEND and ours.focus == lead, "the rival leader on the altar: ours defend it and focus it (%s)" % ours.tactic)
	check(theirs.tactic == GuildWarCommander.GUARD, "theirs guard their leader on the altar (%s)" % theirs.tactic)
	m._assign_objectives()
	check(m.allies.all(func(f): return f.is_dead() or f.switch_post >= 0 or f.goal_point.distance_to(lead.global_position) < 3.0), "ours all go for the one on the altar (but the switch squads)")
	var posted := m.allies.filter(func(f): return f.switch_post >= 0)
	check(not posted.is_empty() and posted.all(func(f): return f.goal_point.distance_to(SiegeArena.SWITCHES[f.switch_post]) < SiegeArena.SWITCH_RADIUS), "and a squad of ours goes to break their switches (%d)" % posted.size())
	var tank_guard := m.enemies.filter(func(f): return f.role == GuildWarCommander.ROLE_TANK and not f.is_leader)
	check(tank_guard.all(func(f): return f.guard_node == lead or f.switch_post >= 0), "their tanks peel for their leader (but the ones holding a switch)")
	m._cancel_capture()
	# Gates down, theirs not holding: the leader goes up only inside its escort.
	m.capture = {}
	for f in m.enemies:
		f.global_position = Vector3(SiegeArena.BASE_X - 30.0, 0.3, 20.0)
	lead.global_position = Vector3(0, 0.3, SiegeArena.GATE_Z[2] - 6.0)
	theirs.tactic = GuildWarCommander.GATHER
	theirs.since = 1.0
	theirs.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(theirs.tactic == GuildWarCommander.GATHER and not lead.capture_role, "the leader alone at the door waits for its escort (%s)" % theirs.tactic)
	var k := 0
	for f in m.enemies:
		if f != lead and k < 3:
			f.global_position = lead.global_position + Vector3(2.0 + k, 0.3, 1.0)
			k += 1
	theirs.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(theirs.tactic == GuildWarCommander.ESCORT and lead.capture_role, "with three round it the escort takes the leader to the altar (%s)" % theirs.tactic)
	# The hero takes the altar: theirs come for the hero, the assassins too.
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	for f in m.enemies:
		f.global_position = SiegeArena.ALTAR + Vector3(8.0, 0.3, 8.0)
	m.switch_pin = GuildFighter.TEAM_ALLY
	m.start_hero_capture()
	check(m.capturer() == hero, "the hero takes the altar")
	theirs.think(GuildWarCommander.THINK_EVERY)
	ours.think(GuildWarCommander.THINK_EVERY)
	check(theirs.tactic == GuildWarCommander.DEFEND and theirs.focus == hero and theirs.dive == hero, "theirs send everyone, assassins first, at the hero on the altar")
	check(ours.tactic == GuildWarCommander.GUARD, "ours guard the hero (%s)" % ours.tactic)
	m._cancel_capture()
	# Staggered stuns: one lands, the next stun skill on that target waits.
	var stunner: GuildFighter = null
	var stun_skill: Dictionary = {}
	for f in m.all_fighters():
		for skill in f.class_data.get("skills", []):
			if skill.get("fx", {}).has("stun") and String(skill.shape) == "single" and f._knows(skill):
				stunner = f
				stun_skill = skill
				break
		if stunner != null:
			break
	if stunner != null:
		var target: GuildFighter = m.enemies[1] if stunner.team == 0 else m.allies[0]
		target.global_position = stunner.global_position + Vector3(1.5, 0, 0)
		stunner._victim = target
		target._stun = 0.0
		var fresh := stunner._score(stun_skill, "single", 1.5, 1.0)
		stunner.commander().note_cc(target, 1.0)
		var held := stunner._score(stun_skill, "single", 1.5, 1.0)
		check(fresh > 0.0 and held < fresh * 0.5, "a stun waits while the guild's last stun holds the target (%.1f -> %.1f)" % [fresh, held])
		stunner.commander().clock += 2.0
		check(not stunner.commander().cc_fresh(target), "and is free once it ends")
	# Callouts are rate limited.
	var said := []
	var listen := func(text: String, _team: int): said.append(text)
	m.feed.connect(listen)
	theirs._last_call = -1.0e9
	theirs._said_at.clear()
	var before := theirs.calls
	check(theirs.callout("t1", "ทุกคนรวมพลที่ประตูสอง!"), "a callout is said")
	check(not theirs.callout("t2", "โฟกัสนักบวชฝั่งนู้น!"), "a second one at once is not")
	theirs.clock += GuildWarCommander.CALL_GAP + 0.1
	check(not theirs.callout("t1", "ทุกคนรวมพลที่ประตูสอง!"), "the same one again soon is not")
	check(theirs.callout("t3", "ถอย! รวมตัวใหม่"), "another one after the gap is")
	check(theirs.calls - before == 2 and said.size() == 2 and String(said[1]).contains("ถอย"), "two said in the war chat (%s)" % [said])
	m.feed.disconnect(listen)
	# No shield: a heavy blow on the leader low lands like on anyone.
	BurstGuard.clear()
	lead.hp = int(float(lead.max_hp) * 0.4)
	var was := lead.hp
	lead.take_hit(lead.max_hp, false)
	check(lead.hp < was and lead.get_node_or_null("LeaderShield") == null, "nothing soaks a blow on the leader (hp %d -> %d)" % [was, lead.hp])
	m.set_process(true)
	zone.queue_free()
	await _frames(4)
	check(int(Game.stats_now().max_hp) == plain_hp, "after the war the hero's stats are unchanged")
