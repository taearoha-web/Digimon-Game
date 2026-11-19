extends Node
## The guild leader's war doctrine (GuildWarDoctrine over GuildWarCommander), headless:
##   - the decisions (pure): the respawn window (exploit a spent front, wait for the wave
##     while outweighed, with entry / exit thresholds and a least hold), the phase for
##     each scenario of attack, defence and a war of four, the phase's hysteresis (two
##     thinks, at once when urgent), the last minutes' plans, the commander's tactic under
##     the hints (stage the wave, push at once, all in), the leader sent up in a window;
##   - squads by class (Defender / Warrior / Lancer vanguard, Priest and Bard support,
##     Mage / Archer / Summoner ranged, Assassin hunters, the switch squad, the leader's
##     guard), each with its strongest standing as squad leader;
##   - in a war: every guild has a doctrine (the same brain), the phase on the HUD, the
##     squads' rules on the fighters (retreat thresholds by role, the hurt falling back to
##     the support squad at the front, a tank peeling for a healer under attack, the extra
##     lean on the called target, which wins a fighter's pick), orders in Thai in the feed
##     and rate-limited (urgent ones sooner), acknowledgements on the doctrine's own dice,
##     a gate falling and the leader going down re-planned at once, the same reading giving
##     the same decisions (deterministic), the hero leading: advice, its own orders first;
##   - a war of four: the guild leading the war and the one busy with a third guild are
##     the called target's first picks;
##   - online: a mirror never thinks (only the host runs the AI), it shows the host's phase.
##   godot --headless --audio-driver Dummy --path . res://tests/integration/guild_war_commander_test.tscn
var failures: Array[String] = []
var checks := 0
const D := preload("res://world/guild_war_doctrine.gd")
const C := preload("res://world/guild_war_commander.gd")


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
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	Game.new_profile(&"warrior", "GWD")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_windows()
	_phases()
	_hysteresis()
	_last_minutes()
	_muster()
	_besiege()
	_hinted_tactics()
	_squad_rules()
	_gate_paths()
	await _in_war()
	await _four_way()
	print("GUILD WAR COMMANDER: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


# ---------------------------------------------------------------------------
# The decisions
# ---------------------------------------------------------------------------

## A calm reading: attacking, even at the front, everyone up.
static func _calm() -> Dictionary:
	return {"balance": 1.0, "foe_spent": 0.1, "alive_share": 1.0, "coming": 0.0, "foe_near": 6, "gathered": 0.3,
		"holding": false, "enemy_capturing": false, "we_capturing": false, "time_left": 900.0}


func _windows() -> void:
	var r := _calm()
	var w := D.pick_window(false, false, 0.0, 100.0, r)
	check(not w[0] and not w[1], "an even fight: neither push at once nor wait")
	r.foe_spent = 0.6
	r.balance = 2.0
	w = D.pick_window(false, false, 0.0, 100.0, r)
	check(w[0] and not w[1], "their front spent (60%% down or walking back) and ours outweighs it: exploit the respawn window")
	r.foe_spent = 0.35
	r.balance = 1.1
	check(D.pick_window(true, false, 5.0, 100.0, r)[0], "once exploiting it keeps going while their front stays thin (exit threshold below the entry)")
	check(not D.pick_window(false, false, 0.0, 100.0, r)[0], "but the same reading does not start it")
	check(not D.pick_window(true, false, D.EXPLOIT_MAX + 1.0, 100.0, r)[0], "never longer than %d s" % int(D.EXPLOIT_MAX))
	r.foe_spent = 0.6
	r.balance = 2.0
	r.alive_share = 0.4
	check(not D.pick_window(false, false, 0.0, 100.0, r)[0], "with most of ours down there is no window to exploit")
	# Outweighed at the front with our own on the way back: wait for the wave.
	r = _calm()
	r.balance = 0.4
	r.coming = 0.4
	w = D.pick_window(false, false, 0.0, 100.0, r)
	check(not w[0] and w[1], "outweighed at the front (0.4) with 40%% of ours on the way: pull back and wait for the wave")
	r.coming = 0.1
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "outweighed with nobody coming: no point waiting")
	r.coming = 0.4
	r.foe_near = 2
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "two of theirs at the front are no reason to wait")
	r.foe_near = 6
	check(not D.pick_window(false, false, 0.0, D.WAIT_REST - 1.0, r)[1], "not again within %d s of the last wave going" % int(D.WAIT_REST))
	r.gathered = 0.5
	check(D.pick_window(false, true, 5.0, 0.0, r)[1], "waiting: the wave is not ready with half the guild at the rally point")
	r.gathered = 0.8
	check(not D.pick_window(false, true, 5.0, 0.0, r)[1], "most of the guild at the rally point: the wave goes")
	r.gathered = 0.2
	check(not D.pick_window(false, true, D.WAIT_MAX + 1.0, 0.0, r)[1], "never waits more than %d s" % int(D.WAIT_MAX))
	r.time_left = 60.0
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "in the last minutes nobody waits")
	r.time_left = 900.0
	r.teams = 4
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "a war of four: nobody stands back (every fall dealt is a point, the others take them)")
	r = _calm()
	r.balance = 0.3
	r.coming = 0.5
	r.holding = true
	w = D.pick_window(false, false, 0.0, 100.0, r)
	check(not w[0] and not w[1], "the castle's holder neither waits nor chases a window (it defends)")
	r.holding = false
	r.we_capturing = true
	check(not D.pick_window(false, false, 0.0, 100.0, r)[1], "our leader on the altar: nobody pulls back")


func _phases() -> void:
	var base := {"tactic": C.PUSH, "plan": "rush", "gates_up": true}
	var r := base.duplicate()
	check(D.phase_for(r) == "breach", "pushing a standing gate: ทลายประตู")
	r.tactic = C.GATHER
	check(D.phase_for(r) == "form", "gathering before a gate: จัดทัพ")
	r.engage = true
	check(D.phase_for(r) == "exploit", "their front spent: ฉวยจังหวะบุก")
	r.engage = false
	r.wait = true
	check(D.phase_for(r) == "wait", "outweighed: ถอยรอกำลังเสริม")
	r = base.duplicate()
	r.tactic = C.FALLBACK
	check(D.phase_for(r) == "recover", "a lost fight: ถอยฟื้นพล")
	r.tactic = C.PUSH
	r.plan = "regroup"
	check(D.phase_for(r) == "recover", "the regroup plan: ถอยฟื้นพล")
	r = base.duplicate()
	r.plan = "hold"
	check(D.phase_for(r) == "hold", "a weaker guild of four holding the bridge foot: ตั้งรับจุดคอขวด")
	r = base.duplicate()
	r.gates_up = false
	r.tactic = C.SECURE
	check(D.phase_for(r) == "switch", "gates down, the switch first: ชิงสวิตช์")
	r.tactic = C.ESCORT
	check(D.phase_for(r) == "assault", "escorting the leader to the altar: บุกแท่น")
	r.waiting = true
	check(D.phase_for(r) == "vulture", "letting two other guilds trade first: รอซ้ำเติม")
	r.waiting = false
	r.we_capturing = true
	check(D.phase_for(r) == "capture", "our leader on the altar: คุ้มกันการยึดแท่น")
	r.enemy_capturing = true
	check(D.phase_for(r) == "stop", "another guild on the altar comes first: สกัดการยึด")
	r = {"tactic": C.DEFEND, "plan": "gates", "gates_up": true, "holding": true}
	check(D.phase_for(r) == "hold", "the holder behind its gates: ตั้งรับจุดคอขวด")
	r.gates_up = false
	r.plan = "defend"
	check(D.phase_for(r) == "guard", "the holder with the gates down: เฝ้าปราสาท")
	r.counter = true
	check(D.phase_for(r) == "counter", "the attackers spent: สวนกลับ")
	for key in D.PHASES:
		check(String(D.PHASES[key]).length() > 0 and _thai(String(D.PHASES[key])), "phase %s has a Thai name (%s)" % [key, D.PHASES[key]])


func _hysteresis() -> void:
	check(D.settle_phase("breach", 1.0, "", "form") == "breach", "a calm change seen once is not taken (no flicker)")
	check(D.settle_phase("breach", 3.0, "form", "form") == "form", "seen on two thinks running it is taken")
	check(D.settle_phase("breach", D.PHASE_MIN + 0.1, "", "form") == "form", "after %d s held a change is taken at once" % int(D.PHASE_MIN))
	check(D.settle_phase("breach", 0.5, "", "stop") == "stop", "an enemy on the altar changes the phase at once")
	check(D.settle_phase("stop", 0.5, "", "assault") == "assault", "and leaving an urgent phase too")
	check(D.settle_phase("", 0.0, "", "form") == "form", "the first phase is taken at once")
	check(D.settle_phase("form", 0.5, "breach", "form") == "form", "unchanged stays")


func _last_minutes() -> void:
	check(D.adjust_plan("forward", 600.0, true, false) == "forward", "early on the plan is the match's own")
	check(D.adjust_plan("forward", 90.0, true, false) == "defend", "the last two minutes, the holder: everyone round the altar")
	check(D.adjust_plan("gates", 90.0, true, true) == "gates", "behind its gates it keeps them")
	check(D.adjust_plan("regroup", 90.0, false, false) == "storm", "the others never pull back to regroup at the end")
	check(D.adjust_plan("hold", 90.0, false, true) == "rush", "nor hold back at the bridge foot")
	check(D.adjust_plan("split", 90.0, false, false) == "split", "an attacking plan stays")


## The race for the castle: muster at the last gate as it is about to fall.
func _muster() -> void:
	var r := {"owner": -1, "enemy_capturing": false}
	check(D.pick_muster(r, 0.2), "nobody holds the castle, the last gate at 20%%: the whole guild musters there")
	check(not D.pick_muster(r, 0.8), "not while it still holds out")
	check(not D.pick_muster(r, -1.0), "not before the last tier is the front")
	r.owner = 1
	check(not D.pick_muster(r, 0.2), "a holder behind it: the siege goes on as before")
	check(D.phase_for({"muster": true, "gates_up": true, "tactic": C.PUSH, "plan": "rush"}) == "muster", "its phase: รวมพลหน้าประตูสุดท้าย")


## Besieging a holder whose defence keeps winning the trades.
func _besiege() -> void:
	var r := {"owner": 1, "holding": false, "gates_up": false, "time_left": 600.0}
	var bad := {"loss": 6.0, "kill": 1.0}
	check(D.pick_besiege(false, 0.0, r, bad, false), "the waves keep losing to the holder (6 falls for 1): stop feeding it, besiege")
	check(not D.pick_besiege(false, 0.0, r, {"loss": 6.0, "kill": 4.0}, false), "an even trade is no reason to")
	check(not D.pick_besiege(false, 0.0, r, bad, true), "the holder's front spent: strike instead")
	check(D.pick_besiege(true, 10.0, r, {"loss": 0.0, "kill": 0.0}, false), "once besieging it holds at least a while (hysteresis)")
	check(not D.pick_besiege(true, D.BESIEGE_MAX + 1.0, r, bad, false), "and tries a wave again after %d s" % int(D.BESIEGE_MAX))
	r.time_left = 60.0
	check(not D.pick_besiege(false, 0.0, r, bad, false), "never in the last minutes (all in)")
	r.time_left = 600.0
	r.gates_up = true
	check(not D.pick_besiege(false, 0.0, r, bad, false), "only with the gates down")
	r.gates_up = false
	r.teams = 4
	check(not D.pick_besiege(false, 0.0, r, bad, false), "only in a war of two")
	check(D.phase_for({"besiege": true, "wait": true, "gates_up": false, "tactic": C.GATHER}) == "besiege", "its phase: ล้อมรอจังหวะ")


## The commander's tactic with the doctrine's hints (none: the old brain, unchanged).
func _hinted_tactics() -> void:
	var s := {
		"plan": "storm", "gates_up": false, "holding": false, "enemy_capturing": false, "we_capturing": false,
		"alive_share": 0.9, "loss_heat": 0.0, "kill_heat": 0.0, "leader_ai": true, "leader_alive": true,
		"leader_hp": 1.0, "leader_threat": 0, "leader_in_castle": true, "escort": 4, "escort_need": 3,
		"gathered": 0.2, "at_front": 0.5, "enemies_at_rally": 0, "switch": false,
	}
	check(C.pick_tactic(C.SECURE, 5.0, s) == C.SECURE, "the old brain: securing the switch it keeps at it")
	s["hold_back"] = true
	check(C.pick_tactic(C.SECURE, 5.0, s) == C.GATHER, "the doctrine's wave: the guild stages out of reach instead of trickling in")
	s["leader_on_altar"] = true
	check(C.pick_tactic(C.ESCORT, 5.0, s) == C.ESCORT, "never while its leader stands on the altar")
	s.erase("leader_on_altar")
	s.hold_back = false
	s.gates_up = true
	s.plan = "rush"
	check(C.pick_tactic(C.GATHER, 1.0, s) == C.GATHER, "gathering at a gate, a fifth there: it waits (old rule)")
	s["engage_now"] = true
	check(C.pick_tactic(C.GATHER, 1.0, s) == C.PUSH, "in the other guild's respawn window it pushes at once")
	s.engage_now = false
	s["hold_back"] = true
	check(C.pick_tactic(C.PUSH, 5.0, s) == C.GATHER, "outweighed at the gate: back to the rally point for the wave")
	check(C.pick_tactic(C.GATHER, C.GATHER_MAX + 1.0, s) == C.GATHER, "and it waits there past the old %d s" % int(C.GATHER_MAX))
	s.hold_back = false
	s.loss_heat = 5.0
	s.alive_share = 0.5
	check(C.pick_tactic(C.PUSH, 20.0, s) == C.FALLBACK, "a lost fight falls back (old rule)")
	s["all_in"] = true
	check(C.pick_tactic(C.PUSH, 20.0, s) == C.PUSH, "all in at the end: no falling back")
	check(C.pick_tactic(C.FALLBACK, 1.0, s) != C.FALLBACK, "and one falling back comes again at once")
	# The leader sent up in the window.
	var lg := {"switch": true, "vanguard": 1, "escort": 1, "escort_need": 3, "altar_foes": 3}
	check(not C.leader_may_go(lg, 2.0), "three foes round the altar, one of ours there: the leader waits (old rule)")
	lg["engage_now"] = true
	check(C.leader_may_go(lg, 2.0), "their front spent: the leader goes up with its first two at the altar")
	lg["switch"] = false
	check(not C.leader_may_go(lg, 2.0), "never with the barrier up")


func _squad_rules() -> void:
	var cases := {&"defender": D.SQUAD_VANGUARD, &"warrior": D.SQUAD_VANGUARD, &"lancer": D.SQUAD_VANGUARD,
		&"priest": D.SQUAD_SUPPORT, &"bard": D.SQUAD_SUPPORT, &"mage": D.SQUAD_RANGED, &"archer": D.SQUAD_RANGED,
		&"summoner": D.SQUAD_RANGED, &"assassin": D.SQUAD_HUNTERS}
	for cls in cases:
		var role := C.role_of(cls, cls in [&"mage", &"archer", &"summoner"])
		check(D.squad_for(role, false, false, false) == cases[cls], "%s fights in %s" % [cls, D.SQUAD_NAMES[cases[cls]]])
	check(D.squad_for(C.ROLE_TANK, true, false, false) == D.SQUAD_SWITCH, "posted to the switch: the switch squad")
	check(D.squad_for(C.ROLE_TANK, false, true, false) == D.SQUAD_GUARD, "the leader's bodyguard: its guard")
	check(D.squad_for(C.ROLE_TANK, false, false, true) == D.SQUAD_LEADER, "the leader is no squad's")
	check(D.retreat_for(C.ROLE_HEALER) > D.retreat_for(C.ROLE_TANK) and D.retreat_for(C.ROLE_RANGED) == D.RETREAT_SQUISHY, "the squishy back line falls back earlier than the tanks")
	for key in D.SQUAD_NAMES:
		check(_thai(String(D.SQUAD_NAMES[key])), "squad %s has a Thai name" % key)


## Along the wall between a tier's two gates the way runs square on to the open one first
## (no fighter left pressed into the gatehouse's corner), farther off straight to it.
func _gate_paths() -> void:
	var was: Array = SiegeArena.lane_open.duplicate(true)
	SiegeArena.lane_open = [[true, false], [false, false]]
	var p := SiegeArena.route(Vector3(3, 0, -16), SiegeArena.ALTAR)
	check(is_equal_approx(p.x, -SiegeArena.LANE_X) and p.z > SiegeArena.GATE_Z[0] + 4.0, "pressed to the middle wall: first to a point square in front of the open left gate (%s)" % p)
	p = SiegeArena.route(Vector3(-SiegeArena.LANE_X, 0, -12), SiegeArena.ALTAR)
	check(p.is_equal_approx(Vector3(-SiegeArena.LANE_X, 0, -18)), "square in front of it: through the gate (%s)" % p)
	p = SiegeArena.route(Vector3(0, 0, 4), SiegeArena.ALTAR)
	check((SiegeArena.CONNECTORS[0] as Array).has(p), "far off the wall: straight to the opening as before (%s)" % p)
	SiegeArena.lane_open = was


static func _thai(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x0E00 and c <= 0x0E7F:
			return true
	return false


# ---------------------------------------------------------------------------
# In a war
# ---------------------------------------------------------------------------

func _roster(teams: int, roll: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	var names := ["Alpha", "Neverdie", "Titan", "3DLnw"].slice(0, teams)
	var info := GuildWarSpectate.demo_war(rng, GuildWarData.GUILD_SIDE, names, [1, 2, 3, 4].slice(0, teams))
	info["guilds"] = false
	(info.sides[0].lineup as Array).resize(GuildWarData.GUILD_SIDE - 1)
	info["owner"] = -1
	return info


func _war(teams: int, roll: int, pick_leader := true) -> GuildWarMatch:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(roll, GuildWarData.DURATION, false, [0, 0, 0, 0].slice(0, teams), 0, 0, 0, {"teams": teams} if teams > 2 else {})
	Game.guildwar_resuming = true
	GuildWarMatch.next_roster = _roster(teams, roll)
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		return null
	if pick_leader and m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	await _frames(6)
	zone.hero.global_position = GuildWarMatch.hero_camp()
	zone.hero.set_physics_process(false)
	return m


func _drop(m: GuildWarMatch) -> void:
	if m != null and is_instance_valid(m):
		m.zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _in_war() -> void:
	var m := await _war(2, 4242)
	check(m != null and m.state == "fight", "a war of two begins")
	if m == null:
		return
	check(m.doctrines.size() == 2 and m.doctrines[0] != null and m.doctrines[1] != null and m.doctrines[0].get_script() == m.doctrines[1].get_script(), "every guild has a doctrine, the same brain")
	check(m.commanders[0].doctrine == m.doctrines[0] and m.commanders[1].doctrine == m.doctrines[1], "each over its own commander")
	var feed: Array[String] = []
	m.feed.connect(func(text: String, _team: int): feed.append(text))
	# Let it think a few beats (the AI runs).
	var t0 := Time.get_ticks_msec()
	while m.doctrines[1].thinks < 3 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	var d1: GuildWarDoctrine = m.doctrines[1]
	check(d1.phase != "" and D.PHASES.has(d1.phase), "the doctrine is in a phase (%s)" % d1.phase)
	check(m.phase_name(1) == D.PHASES[d1.phase], "the phase's name for the board")
	check(m.sides_status().contains("ขั้น: "), "our HUD line shows our phase (%s)" % m.sides_status())
	check(m.plans_line().contains(m.team_name(1)) and m.plans_line().contains("›"), "the watcher's line shows each guild's plan and phase (%s)" % m.plans_line())
	check(feed.any(func(t): return t.contains("⚑") and _thai(t)), "the leader announced its plan in Thai in the feed")
	check(d1.peak_us < 20000, "a think costs little (%d us)" % d1.peak_us)
	# Hold everything still: only what each check does happens.
	for f in m.all_fighters():
		f.set_physics_process(false)
	m.set_process(false)
	# Squads by class, each with a leader of its own.
	d1.assign_squads()
	var lead := m.ai_leader(1)
	var all_in := true
	for f in m.enemies:
		var key := String(d1.squad_of.get(f.get_instance_id(), ""))
		if key == "":
			all_in = false
			continue
		if f == lead:
			check(key == D.SQUAD_LEADER, "the leader is the leader")
			continue
		var want := D.squad_for(m.commanders[1]._role(f, lead), m.commanders[1].post_of(f), key == D.SQUAD_GUARD, false)
		check(key == want, "%s (%s) is in %s" % [f.rival_name, f.fighter_class(), key])
	check(all_in, "every member is in one squad")
	for key in d1.squad_leads:
		var sl: GuildFighter = d1.squad_leads[key]
		check(sl != null and String(d1.squad_of.get(sl.get_instance_id(), "")) == key and not sl.is_dead(), "%s's leader is one of it, standing" % key)
	# The squads' rules: retreat thresholds, the lean on the called target.
	m.commanders[1].apply()
	for f in m.enemies:
		if f == lead:
			continue
		var r := m.commanders[1]._role(f, lead)
		if r == C.ROLE_RANGED or r == C.ROLE_HEALER:
			check(is_equal_approx(f.retreat_below, D.RETREAT_SQUISHY), "%s falls back at %d%%" % [f.fighter_class(), int(D.RETREAT_SQUISHY * 100.0)])
		elif r == C.ROLE_TANK:
			check(is_equal_approx(f.retreat_below, D.RETREAT_STURDY), "a tank stays in to %d%%" % int(D.RETREAT_STURDY * 100.0))
		check(f.focus_bonus == D.FOCUS_BONUS, "everyone leans harder on the called target")
	# The hurt fall back to the support squad at the front, not the far camp.
	var priest: GuildFighter = null
	var tank: GuildFighter = null
	var mage: GuildFighter = null
	for f in m.enemies:
		if f == lead:
			continue
		var r := m.commanders[1]._role(f, lead)
		if r == C.ROLE_HEALER and priest == null:
			priest = f
		elif r == C.ROLE_TANK and tank == null:
			tank = f
		elif r == C.ROLE_RANGED and mage == null:
			mage = f
	check(priest != null and tank != null and mage != null, "the line-up has a priest, a tank and a ranged fighter")
	if priest != null and tank != null and mage != null:
		var front := d1.objective_point()
		d1.field["front"] = front
		priest.global_position = front + Vector3(3, 0.3, 6)
		mage.global_position = front + Vector3(-3, 0.3, 4)
		tank.global_position = front + Vector3(0, 0.3, 9)
		m.commanders[1].apply()
		check(d1.support_at.is_finite() and Vector2(d1.support_at.x - priest.global_position.x, d1.support_at.z - priest.global_position.z).length() < 8.0, "the support squad's place at the front is known")
		check(mage.rear_point.is_finite() and mage.rear_point.distance_to(d1.support_at) < 0.1, "a hurt mage falls back to the healers at the front, not its camp")
		check(not priest.rear_point.is_finite() or priest.rear_point != d1.support_at, "the healers themselves fall back as before")
		# A tank peels for the priest under attack.
		var foe: GuildFighter = m.allies[0]
		foe.global_position = priest.global_position + Vector3(1.5, 0, 0)
		foe._victim = priest
		m.commanders[1].apply()
		check(tank.guard_node == priest, "the nearest tank peels for the priest under attack")
		foe._victim = null
		foe.global_position = GuildWarMatch.hero_camp()
		m.commanders[1].apply()
		check(tank.guard_node != priest, "and goes back to guarding its leader once it is safe")
	# The called target wins a fighter's pick with the doctrine's lean.
	await _focus_pick(m)
	# Orders: Thai, rate-limited, urgent sooner, acknowledged on the doctrine's dice.
	d1._last_order = -1.0e9
	d1._order_at.clear()
	feed.clear()
	check(d1.order("test_a", "แผน: ทดสอบคำสั่ง"), "an order is told")
	check(feed.any(func(t): return t.contains("⚑ แผน: ทดสอบคำสั่ง")), "in the feed, with its mark (%s)" % str(feed))
	check(not d1.order("test_a", "แผน: ทดสอบคำสั่ง"), "the same order is not told again at once")
	check(not d1.order("test_b", "แผน: อีกคำสั่ง"), "nor another within %d s" % int(D.ORDER_GAP))
	check(d1.order("test_c", "ด่วน!", true), "an urgent one is told at once")
	check(m.commanders[1]._last_call == m.commanders[1].clock, "the commander's own callouts wait after an order (no spam)")
	d1.clock += D.ORDER_GAP + 0.1
	check(d1.order("test_b", "แผน: อีกคำสั่ง"), "after %d s the next order goes" % int(D.ORDER_GAP))
	var twin := GuildWarDoctrine.new(m, 1)
	var other := GuildWarDoctrine.new(m, 1)
	var same := true
	for i in 20:
		same = same and twin._rng.randi() == other._rng.randi()
	check(same, "the acknowledgements' dice come from the war's seed and the team (deterministic)")
	# Deterministic: the same reading gives the same decisions.
	var a := d1.read_field()
	var b := d1.read_field()
	a.erase("front")
	b.erase("front")
	check(a == b, "the same field read twice gives the same reading")
	var wa := D.pick_window(false, false, 0.0, 100.0, a)
	check(wa == D.pick_window(false, false, 0.0, 100.0, b) and D.phase_for(a) == D.phase_for(b), "and the same window and phase")
	# Events re-plan at once: a phase change is announced, the leader's fall is called.
	d1._last_order = -1.0e9
	d1._order_at.clear()
	feed.clear()
	d1.phase = ""
	d1.think()
	check(feed.any(func(t): return t.contains("⚑")), "a new phase is announced (%s)" % d1.phase)
	var gate := m.front_gate()
	d1._think_left = 2.0
	m.set_process(true)
	if gate != null:
		gate.take_hit(gate.hp + 10, false)
	m.set_process(false)
	check(d1._think_left <= 0.3, "a gate down: the doctrine thinks again within a beat")
	# Online: a mirror runs no doctrine; it shows the host's phase.
	m.set_process(true)
	m.mirror = true
	var before := d1.thinks
	for i in 40:
		await get_tree().process_frame
	check(d1.thinks == before, "a mirror's game never runs the doctrine (only the host's does)")
	m.mirror_sync("gw", {"tl": 600.0, "pp": ["rush", "breach"]})
	check(m.mirror_phase == "breach" and m.phase_name(0) == D.PHASES.breach and m.plans[0] == "rush", "a mirror shows the host's plan and phase")
	m.mirror_sync("gw", {"tl": 600.0, "pp": ["rush", "nonsense"]})
	check(m.mirror_phase == "", "an unknown phase is not shown")
	m.mirror = false
	m.set_process(false)
	await _drop(m)
	await _hero_leads()
	await _legacy()


## Two of the other guild alike but for distance: the called one, farther, wins the
## doctrine's fighter's pick (the old lean alone picks the nearer).
func _focus_pick(m: GuildWarMatch) -> void:
	var me: GuildFighter = null
	for f in m.enemies:
		if not f.is_leader and f.role == C.ROLE_MELEE:
			me = f
			break
	if me == null:
		for f in m.enemies:
			if not f.is_leader and f.role == C.ROLE_TANK:
				me = f
				break
	var pair: Array[GuildFighter] = []
	for f in m.allies:
		if f.is_leader or f.is_healer() or f.sings() or f.in_hero_party():
			continue
		pair.append(f)
		if pair.size() == 2:
			break
	if me == null or pair.size() < 2:
		check(false, "a fighter and two alike to pick from")
		return
	for f in m.all_fighters():
		if f != me and not pair.has(f):
			f.global_position = Vector3(200, 0.3, 200) if f.team == 0 else Vector3(-200, 0.3, 200)
	var at := SiegeArena.PLAZA + Vector3(0, 0.3, 0)
	me.global_position = at
	pair[0].global_position = at + Vector3(5, 0, 0)
	pair[1].global_position = at + Vector3(17, 0, 0)
	for f in pair:
		f.hp = f.max_hp
		f._guard_until = 0
	me.objective = null
	me.hold_range = 0.0
	me.keep_back = false
	me.switch_post = false
	me.capture_role = false
	me.dive = null
	me.guard_node = null
	me.focus = pair[1]
	me._victim = null
	me._grudge = 0.0
	GuildFighter.forget_view()
	me.focus_bonus = 0.0
	GuildFighter._view_frame = -1
	var old_pick := me._nearest_victim()
	me.focus_bonus = D.FOCUS_BONUS
	var new_pick := me._nearest_victim()
	check(old_pick == pair[0], "without the doctrine's lean the nearer one is picked")
	check(new_pick == pair[1], "with it the guild's called target is (focus fire)")


## The hero leading ours: the doctrine advises, the hero's own orders come first and the
## AI fills in the rest.
func _hero_leads() -> void:
	var m := await _war(2, 77, false)
	if m == null:
		check(false, "a war led by the hero")
		return
	check(m.hero_leads() and m.doctrines[0] != null, "the hero leads ours, a doctrine still runs for it")
	var d0: GuildWarDoctrine = m.doctrines[0]
	var feed: Array[String] = []
	m.feed.connect(func(text: String, _team: int): feed.append(text))
	d0._last_order = -1.0e9
	check(d0.order("advice", "แผน: บุกประตูซ้าย"), "an order for the hero's guild")
	check(feed.any(func(t): return t.contains("⚑ แนะนำ:")), "told as a ที่ปรึกษา's advice (the player leads)")
	for f in m.all_fighters():
		f.set_physics_process(false)
	m.set_process(false)
	m.commanders[0].think(1.5)
	d0.think()
	m.order_guild(C.ORDER_FALLBACK)
	m._assign_objectives()
	var home := m.home_of(0)
	var obeyed := true
	for f in m.allies:
		if not f.is_dead():
			obeyed = obeyed and f.goal_point.distance_to(home) < 8.0 and not f.rear_point.is_finite()
	check(obeyed, "the hero's order (fall back to camp) decides every member's goal over the doctrine")
	check(m.allies.all(func(f): return f.focus_bonus == D.FOCUS_BONUS), "and the AI still fills in the rest (its squads' rules)")
	await _drop(m)


## GuildWarMatch.legacy_ai / next_smart: the old brain alone (the measurement's baseline).
func _legacy() -> void:
	GuildWarMatch.next_smart = [true, false]
	var m := await _war(2, 99)
	GuildWarMatch.next_smart = []
	if m == null:
		check(false, "a war of a doctrine against the old brain")
		return
	check(m.doctrines[0] != null and m.doctrines[1] == null and m.commanders[1].doctrine == null, "one guild plays the doctrine, the other the old commander alone")
	check(m.phase_key(1).begins_with("old:") and m.phase_name(1) == "", "the old brain has no phase")
	await _drop(m)


# ---------------------------------------------------------------------------
# A war of four
# ---------------------------------------------------------------------------

func _four_way() -> void:
	var m := await _war(4, 2024)
	if m == null or m.team_count() != 4:
		check(false, "a war of four")
		return
	check(m.doctrines.size() == 4 and m.doctrines.all(func(d): return d != null), "four guilds, four doctrines")
	for f in m.all_fighters():
		f.set_physics_process(false)
	m.set_process(false)
	var d0: GuildWarDoctrine = m.doctrines[0]
	# Guild 2 leads on points.
	m.score[2] = 40
	d0.read_field()
	check(d0.leading_team == 2, "the doctrine knows who leads the war (guild 2 on points)")
	var leader_f: GuildFighter = m.side(2)[1]
	var other_f: GuildFighter = m.side(1)[1]
	check(d0.focus_extra(leader_f) >= 6.0 and d0.focus_extra(leader_f) > d0.focus_extra(other_f), "the leading guild's fighters are the first pick for the called target")
	var busy: GuildFighter = m.side(3)[1]
	var calm := d0.focus_extra(busy)
	busy._victim = m.side(1)[2]
	check(d0.focus_extra(busy) >= calm + 5.0, "one busy with a third guild is hit from behind (third-party)")
	busy._victim = m.side(0)[2]
	check(d0.focus_extra(busy) == calm, "one fighting us is no third party")
	m.castle_owner = 3
	d0.read_field()
	check(d0.leading_team == 3, "the castle's holder leads the war whatever the points")
	m.castle_owner = -1
	m.score[2] = 0
	await _drop(m)
