extends Node
## Plays a guild war in fast forward (headless) to check the fight: who falls, how often,
## the longest single hit, that the war ends and the result is paid out.
##   godot --headless --path . res://tests/tools/guild_war_sim.tscn -- [class] [sim seconds] [time scale]
var _kills: Array[String] = []
var _hit_max := 0.0
var _finished := false
var _tick := 0


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
	m.feed.connect(func(text: String, team: int): _kills.append("%3d %s" % [int(seconds - m.time_left), text]))
	m.finished.connect(func(r: Dictionary):
		_finished = true
		print("RESULT won=%s score %d:%d kills=%d deaths=%d gold=%d exp=%d" % [r.won, r.score_us, r.score_them, r.kills, r.deaths, r.gold, r.exp]))
	var hero := zone.hero
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
		if _tick % 10 == 0:
			print("  dbg ", GuildFighter.dbg)
			print("  t+%ds state=%s left=%d score=%s hero_hp=%d" % [(Time.get_ticks_msec() - t0) / 1000, m.state, int(m.time_left), m.score, int(Game.profile.hp)])
	Engine.time_scale = 1.0
	for line in _kills.slice(0, 40):
		print("  ", line)
	print("score ", m.score, " hero kills ", m.hero_kills, " deaths ", m.hero_deaths, " overtime ", m.overtime, " finished ", _finished)
	for f in m.all_fighters():
		print("  %s %-14s K%d D%d A%d hp=%3d%% pos=(%.0f,%.0f) frozen=%s retreat=%s" % ["A" if f.team == 0 else "E", f.rival_name, f.kills, f.deaths, f.assists, int(f.hp_ratio() * 100.0), f.global_position.x, f.global_position.z, f._frozen, f._retreating])
	get_tree().quit(0 if _finished else 1)
