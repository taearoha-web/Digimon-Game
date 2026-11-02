extends Node
## Plays a guild war in fast forward (headless) to check the fight: who falls, how often,
## the longest single hit, how the siege goes (gates, the altar, the castle's holder), that
## the war ends and the result is paid out.
##   godot --headless --path . res://tests/tools/guild_war_sim.tscn -- [class] [sim seconds] [time scale] [damage scale] [mode]
## mode: "open" starts with the gates down; "guild" fights Alpha against Neverdie with every
## member (run with TOON_WORLD_DAYS=20 so the guilds are full); "guild_open" both; with
## "lead" the hero plays its guild's leader (its auto fight follows the front gate, then
## goes for the altar and takes it), otherwise it fights round our camp.
var _kills: Array[String] = []
var _hit_max := 0.0
var _finished := false
var _tick := 0
var _census0: Dictionary = {}
## The siege as it went (for the SUMMARY line): when each gate fell, each capture, plan switches.
var _gate_times: Array[int] = []
var _captures: Array[String] = []
var _plan_switches := [0, 0]
var _m: GuildWarMatch
var _hero: Hero


func _census(root: Node) -> Dictionary:
	var out := {}
	for node in root.find_children("*", "", true, false):
		var key := String(node.get_class())
		if node.get_script() != null:
			key += ":" + String(node.get_script().get_global_name())
		out[key] = int(out.get(key, 0)) + 1
	return out


## "lead": the hero's auto fight is centred on the way to the front gate, then the altar;
## on the altar it takes the castle (the same rule before and after any AI change).
func _steer() -> void:
	if _m == null or _m.state != "fight" or _hero.is_dead():
		return
	var gate := _m.front_gate()
	var goal := SiegeArena.ALTAR
	var radius := 3.0
	if gate != null:
		goal = SiegeArena.gate_front(gate.gate_index) + Vector3(-3.0, 0, 2.0)
		radius = 10.0
	elif _m.castle_owner == GuildFighter.TEAM_ALLY:
		goal = SiegeArena.ALTAR + Vector3(0, 0, 5.0)
		radius = 8.0
	var way := SiegeArena.route(_hero.global_position, goal)
	_hero._auto_center = Vector3(way.x, 0.0, way.z)
	_hero._auto_radius = radius if way.distance_to(goal) < 0.5 else 2.0
	if _m.hero_can_capture():
		_m.start_hero_capture()


func _ready() -> void:
	Game.set_process(false)
	GameSettings.load_settings()
	var args := OS.get_cmdline_user_args()
	var cls := StringName(args[0]) if args.size() > 0 else &"warrior"
	var seconds := float(args[1]) if args.size() > 1 else 120.0
	var scale := float(args[2]) if args.size() > 2 else 4.0
	if args.size() > 3:
		GuildWarData.damage_scale = float(args[3])
	Game.new_profile(cls, "Sim")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = 11
	for slot in ItemData.SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 150, slot, gear_rng)
	Game.profile.equip["wings"] = StarWingData.item(String(cls), gear_rng)
	var mode := String(args[4]) if args.size() > 4 else ""
	if mode.contains("guild"):
		Game.profile.flags[Game.GUILD_FLAG] = WorldPlayers.ALPHA
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		printerr("FAIL: no match")
		get_tree().quit(1)
		return
	m.time_left = seconds
	# "open": the gates are already down (to watch the fight for the altar).
	if mode.contains("open"):
		for g in m.gates:
			g.set_broken_quietly()
		m._update_breakable()
	m.feed.connect(func(text: String, team: int):
		var at := int(seconds - m.time_left)
		_kills.append("%3d %s" % [at, text])
		if text.contains("พังแล้ว") or text.contains("ประตูชั้นสุดท้ายพัง"):
			_gate_times.append(at)
		elif text.contains("ยึดปราสาทได้!"):
			_captures.append("%s@%d" % ["A" if team == 0 else "E", at])
		elif text.contains("วางแผน") and team >= 0:
			_plan_switches[team] += 1)
	m.finished.connect(func(r: Dictionary):
		_finished = true
		print("RESULT won=%s score %d:%d kills=%d deaths=%d gold=%d exp=%d" % [r.won, r.score_us, r.score_them, r.kills, r.deaths, r.gold, r.exp]))
	var hero := zone.hero
	if mode.contains("lead"):
		_m = m
		_hero = hero
		get_tree().process_frame.connect(_steer)
	var fighters := m.all_fighters().size()
	var expected: int = 2 * GuildWarData.TEAM_SIZE - 1 if not bool(m.roster.get("guilds", false)) else m.roster.ally.size() + m.roster.enemy.size()
	print("FIGHTERS %d (expected %d) nodes at start %d" % [fighters, expected, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if fighters != expected:
		printerr("FAIL: %d fighters" % fighters)
		get_tree().quit(1)
		return
	print("GUILDS ", m.ally_name, " vs ", m.enemy_name, " power ", int(m.roster.ally_power), " : ", int(m.roster.enemy_power))
	for f in m.all_fighters():
		print("  %s %-14s %-9s grade=%3d hp=%6d atk=%5.0f def=%4.0f" % ["A" if f.team == 0 else "E", f.rival_name, f.member["class"], f.grade, f.max_hp, f.rstats.atk, f.rstats.def])
	Game.profile.hp = Game.stats_now().max_hp
	Game.profile.mp = Game.stats_now().max_mp
	Engine.time_scale = scale
	hero.set_auto(true)
	var t0 := Time.get_ticks_msec()
	while not _finished and Time.get_ticks_msec() - t0 < 600000:
		await get_tree().create_timer(0.5, true, false, true).timeout
		if m.state == "fight" and hero.target == null:
			hero.set_auto(true)
		_tick += 1
		if _tick == 60:
			_census0 = _census(zone)
		if _tick % 10 == 0:
			print("  dbg ", GuildFighter.dbg, " vfx ", VfxBudget.counters(), " nodes ", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), " objects ", int(Performance.get_monitor(Performance.OBJECT_COUNT)), " resources ", int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), " orphans ", int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), " summons ", get_tree().get_nodes_in_group("summons").size(), " static_mb ", snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1), " tweens ", get_tree().get_processed_tweens().size())
			print("  t+%ds state=%s left=%d score=%s hero_hp=%d · %s" % [(Time.get_ticks_msec() - t0) / 1000, m.state, int(m.time_left), m.score, int(Game.profile.hp), m.siege_status()])
			if "commanders" in m:
				print("  TACTICS ours=%s theirs=%s plans=%s" % [m.commanders[0].tactic, m.commanders[1].tactic, m.plans])
	Engine.time_scale = 1.0
	var now := _census(zone)
	var grow: Array = []
	for key in now:
		grow.append([key, int(now[key]) - int(_census0.get(key, 0)), int(now[key])])
	grow.sort_custom(func(a, b): return a[1] > b[1])
	print("NODE GROWTH since 30s (total nodes now %d):" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	for g in grow.slice(0, 14):
		print("  GROW %-40s +%d (now %d)" % [g[0], g[1], g[2]])
	var sig := {}
	for node in zone.find_children("*", "CPUParticles3D", true, false):
		var cp := node as CPUParticles3D
		var par := cp.get_parent()
		var k := "%s/%s amount=%d life=%.2f one_shot=%s emitting=%s" % [par.get_class(), String(par.name).substr(0, 24), cp.amount, cp.lifetime, cp.one_shot, cp.emitting]
		sig[k] = int(sig.get(k, 0)) + 1
	var sk: Array = sig.keys()
	sk.sort_custom(func(a, b): return sig[a] > sig[b])
	for k in sk.slice(0, 8):
		print("  PARTICLES %5d  %s" % [sig[k], k])
	for line in _kills:
		print("  F ", line)
	var r: Dictionary = m._result
	var tactics := ""
	if "commanders" in m:
		for c in m.commanders:
			tactics += " calls%d=%d" % [c.team, c.calls]
	print("SUMMARY won=%s owner=%d score=%d:%d gates_down_at=%s captures=%s plan_switches=%s overtime=%s hero_deaths=%d%s" % [r.get("won", false), m.castle_owner, m.score[0], m.score[1], _gate_times, _captures, _plan_switches, m.overtime, m.hero_deaths, tactics])
	print("score ", m.score, " hero kills ", m.hero_kills, " deaths ", m.hero_deaths, " overtime ", m.overtime, " finished ", _finished)
	for f in m.all_fighters():
		print("  %s %-14s K%d D%d A%d hp=%3d%% pos=(%.0f,%.0f) frozen=%s retreat=%s" % ["A" if f.team == 0 else "E", f.rival_name, f.kills, f.deaths, f.assists, int(f.hp_ratio() * 100.0), f.global_position.x, f.global_position.z, f._frozen, f._retreating])
	get_tree().quit(0 if _finished else 1)
