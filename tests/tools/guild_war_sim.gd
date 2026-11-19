extends Node
## Headless guild-war simulator: whole seeded AI-only wars (watched: every guild AI, the
## hero out of it), one after another, each guild played by the doctrine (GuildWarDoctrine
## over GuildWarCommander: "smart") or by the old commander alone ("old"), for the old-vs-new
## measurement. Every guild gets the SAME line-up (the seed's), so "equal strength" is
## exact; SIM_MULT scales a guild's HP/attack/defence for the unequal wars. Each war is run
## a second time with the brains handed round one guild (SIM_SWAP=1, the default) so a camp
## or a line-up never favours one brain.
##   $G --headless --audio-driver Dummy --fixed-fps 15 --path . res://tests/tools/guild_war_sim.tscn
## env: SIM_TEAMS=2|4, SIM_SEEDS=1,2,3, SIM_SMART=1,0[,0,0], SIM_MULT=1,1[,..],
##      SIM_SECONDS (default the whole war), SIM_SIZE (fighters a guild, 20), SIM_SWAP=0|1,
##      SIM_OUT=/path/results.jsonl (one JSON line a war), SIM_SPEED (Engine.time_scale, 4).
## The physics step is 1/15 s of war time (time_scale 4 at 60 ticks, as the capture
## measurements in guild_war_capture_test / guild_war_4way_test); with --fixed-fps 15 the
## wars run as fast as the machine can (tools/gw_sim_report.py sums the JSON lines up).

class Hook:
	extends RefCounted
	var last: Dictionary = {}

	func spectated_result(_info: Dictionary, result: Dictionary) -> void:
		last = result


func _env(key: String, fallback: String) -> String:
	var v := OS.get_environment(key)
	return v if v != "" else fallback


func _ints(text: String) -> Array:
	return Array(text.split(",")).map(func(x): return int(x))


func _floats(text: String) -> Array:
	return Array(text.split(",")).map(func(x): return float(x))


func _ready() -> void:
	InputSetup.ensure_defaults()
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPlayers.clear_bonus()
	WorldEvents.festival_enabled = false
	Game.new_profile(&"warrior", "Sim")
	Game.profile.level = 100
	Game.current_zone = &"guildwar"
	var teams := int(_env("SIM_TEAMS", "2"))
	var seeds := _ints(_env("SIM_SEEDS", "1"))
	var smart := _ints(_env("SIM_SMART", "1,0" if teams == 2 else "1,0,0,0"))
	var ones: PackedStringArray = []
	for t in teams:
		ones.append("1")
	var mults := _floats(_env("SIM_MULT", ",".join(ones)))
	var seconds := float(_env("SIM_SECONDS", str(GuildWarData.DURATION)))
	var size := int(_env("SIM_SIZE", str(GuildWarData.GUILD_SIDE)))
	var swap := _env("SIM_SWAP", "1") == "1"
	var out_path := _env("SIM_OUT", "")
	var hook := Hook.new()
	GuildWarSpectate.league_hook = hook
	for s in seeds:
		var setups: Array = [[smart, mults]]
		if swap:
			# The same war with the brains (and the strength) handed round by one guild.
			setups.append([smart.slice(1) + smart.slice(0, 1), mults.slice(1) + mults.slice(0, 1)])
		for st in setups:
			var r: Dictionary = await _war(int(s), teams, st[0], st[1], seconds, size, hook)
			print("SIMRESULT ", JSON.stringify(r))
			if out_path != "":
				var fa := FileAccess.open(out_path, FileAccess.READ_WRITE if FileAccess.file_exists(out_path) else FileAccess.WRITE)
				if fa != null:
					fa.seek_end()
					fa.store_line(JSON.stringify(r))
					fa.close()
	GuildWarSpectate.league_hook = null
	get_tree().quit(0)


## One line-up from the seed, the same fighters for every guild (names told apart), each
## guild's strength scaled by its `mults` entry.
static func roster(war_seed: int, teams: int, size: int, mults: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = war_seed
	var base := GuildWarSpectate.demo_war(rng, size, ["A"], [1])
	var lineup: Array = base.sides[0].lineup
	var names := ["Alpha", "Neverdie", "Titan", "3DLnw"]
	var sides: Array = []
	for t in teams:
		var mine: Array = []
		var power := 0.0
		for i in lineup.size():
			var f: Dictionary = (lineup[i] as Dictionary).duplicate(true)
			f.member["name"] = "%s%d" % [String(f.member.name), t]
			var k := float(mults[t]) if t < mults.size() else 1.0
			f["mults"] = {"hp": k, "atk": k, "def": k}
			f["power"] = float(f.power) * k
			power += float(f.power)
			mine.append(f)
		sides.append({"lineup": mine, "name": names[t], "guild": t + 1, "power": power})
	return {"sides": sides, "guilds": false, "owner": -1, "elapsed": 0.0, "slot_start": 1700000000 + war_seed}


func _war(war_seed: int, teams: int, smart: Array, mults: Array, seconds: float, size: int, hook: Hook) -> Dictionary:
	seed(war_seed)
	hook.last = {}
	var flags: Array[bool] = []
	for t in teams:
		flags.append(t < smart.size() and int(smart[t]) != 0)
	GuildWarMatch.next_smart = flags
	GuildWarSpectate._pending = roster(war_seed, teams, size, mults)
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	zone.layout_seed = 77
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	var out := {"seed": war_seed, "teams": teams, "smart": smart, "mults": mults}
	if m == null:
		out["error"] = "no match"
		return out
	m._timer = 0.05
	Engine.time_scale = float(_env("SIM_SPEED", "4"))
	var t0 := Time.get_ticks_msec()
	var clock := 0.0
	var gate_down := {}
	var tier_open := [-1.0, -1.0, -1.0]
	var captures: Array = []
	var owner_now := -1
	var kills := []
	var deaths := []
	kills.resize(teams)
	kills.fill(0)
	deaths.resize(teams)
	deaths.fill(0)
	var phase_time: Array = []
	var plan_time: Array = []
	for t in teams:
		phase_time.append({})
		plan_time.append({})
	var switch_time := []
	switch_time.resize(teams)
	switch_time.fill(0.0)
	var stuck_max := 0.0
	var stuck := {}
	var last_pos := {}
	for f in m.all_fighters():
		f.fell.connect(func(victim: GuildFighter, killer: Node) -> void:
			deaths[victim.team] += 1
			if killer is GuildFighter and (killer as GuildFighter).team != victim.team:
				kills[(killer as GuildFighter).team] += 1)
	var sample := 0.0
	var stuck_who := ""
	var trace := _env("SIM_TRACE", "") != ""
	if trace:
		m.feed.connect(func(text: String, team: int): print("  [%.0f] %d %s" % [clock, team, text]))
	var frame_peak := 0.0
	var frame_sum := 0.0
	var frames := 0
	var last_tick := Time.get_ticks_usec()
	while m.state != "done" and m.state != "ending" and clock < GuildWarData.DURATION + 400.0:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		var frame_ms := float(now - last_tick) / 1000.0
		last_tick = now
		var dt := get_physics_process_delta_time()
		if m.state != "fight":
			continue
		frames += 1
		frame_sum += frame_ms
		frame_peak = maxf(frame_peak, frame_ms)
		clock += dt
		if seconds < GuildWarData.DURATION and clock >= seconds:
			break
		for gi in m.gates.size():
			if m.gates[gi].is_dead() and not gate_down.has(str(gi)):
				gate_down[str(gi)] = snappedf(clock, 1.0)
		for k in 3:
			if float(tier_open[k]) < 0.0 and m.tier_open(k):
				tier_open[k] = snappedf(clock, 1.0)
		if m.castle_owner != owner_now:
			owner_now = m.castle_owner
			captures.append([snappedf(clock, 1.0), owner_now])
		for t in teams:
			if m.holds_switch(t):
				switch_time[t] += dt
			var ph := m.phase_key(t)
			phase_time[t][ph] = float(phase_time[t].get(ph, 0.0)) + dt
			var pl := String(m.plans[t])
			plan_time[t][pl] = float(plan_time[t].get(pl, 0.0)) + dt
		if trace and int(clock / 20.0) != int((clock - dt) / 20.0):
			var rows: PackedStringArray = []
			for t in teams:
				var up := m.side(t).filter(func(f): return not f.is_dead())
				var mid := Vector3.ZERO
				for f in up:
					mid += f.global_position
				mid = mid / float(maxi(1, up.size()))
				var dd: Variant = m.doctrines[t]
				var extra := ""
				if dd != null:
					var fl: Dictionary = dd.field
					extra = " bal %.2f spent %.2f gath %.2f" % [float(fl.get("balance", 0)), float(fl.get("foe_spent", 0)), float(fl.get("gathered", 0))]
				rows.append("t%d %s/%s/%s up %d mid (%.0f,%.0f)%s" % [t, m.plans[t], m.commanders[t].tactic, m.phase_key(t), up.size(), mid.x, mid.z, extra])
			print("[%.0f] %s | sw %d own %d cap %s" % [clock, " | ".join(rows), m.switch_owner, m.castle_owner, str(m.capture.get("team", "-"))])
		sample += dt
		if sample >= 5.0:
			sample = 0.0
			# Stuck: standing, nobody to fight, far from its goal and hardly moved in 5 s.
			for f in m.all_fighters():
				var id := f.get_instance_id()
				var p := f.global_position
				var idle := not f.is_dead() and not f.is_retreating() and (f._victim == null or not is_instance_valid(f._victim)) and Vector2(p.x - f.goal_point.x, p.z - f.goal_point.z).length() > 6.0
				if idle and last_pos.has(id) and (last_pos[id] as Vector3).distance_to(p) < 0.8:
					stuck[id] = float(stuck.get(id, 0.0)) + 5.0
					if float(stuck[id]) > stuck_max:
						stuck_max = float(stuck[id])
						stuck_who = "t%d %s at %s goal %s plan %s phase %s" % [f.team, f.fighter_class(), str(p.round()), str(f.goal_point.round()), m.plans[f.team], m.phase_key(f.team)]
				else:
					stuck[id] = 0.0
				last_pos[id] = p
	Engine.time_scale = 1.0
	var r: Dictionary = hook.last
	var rounded: Array = []
	for t in teams:
		var o := {}
		for key in phase_time[t]:
			o[key] = int(phase_time[t][key])
		var p := {}
		for key in plan_time[t]:
			p[key] = int(plan_time[t][key])
		rounded.append([o, p])
	var peak_us := 0
	var thinks := 0
	var total_us := 0
	var apply_us := 0
	var applies := 0
	var orders: Array = []
	for d in m.doctrines:
		if d != null:
			peak_us = maxi(peak_us, d.peak_us)
			thinks += d.thinks
			total_us += d.total_us
			apply_us += d.apply_us
			applies += d.applies
			orders.append(d.orders_said)
		else:
			orders.append(0)
	var points: Array = []
	for t in teams:
		points.append(m.war_points(t))
	out.merge({
		"clock": snappedf(clock, 1.0), "winner": int(r.get("winner", -2)), "score": Array(m.score), "captures_n": Array(m.captures),
		"owner": m.castle_owner, "capture_log": captures, "kills": kills, "deaths": deaths, "gates": gate_down, "tiers": tier_open,
		"switch_s": switch_time.map(func(x): return int(x)), "phases": rounded.map(func(x): return x[0]), "plans": rounded.map(func(x): return x[1]),
		"points": points, "places": r.get("places", []), "stuck_max": stuck_max, "stuck_who": stuck_who,
		"doctrine_peak_ms": snappedf(float(peak_us) / 1000.0, 0.01), "doctrine_thinks": thinks,
		"doctrine_think_avg_us": int(float(total_us) / float(maxi(1, thinks))), "doctrine_apply_avg_us": int(float(apply_us) / float(maxi(1, applies))), "orders": orders,
		"frame_avg_ms": snappedf(frame_sum / float(maxi(1, frames)), 0.01), "frame_peak_ms": snappedf(frame_peak, 0.1),
		"wall_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1),
	})
	GuildWarMatch.next_smart = []
	zone.queue_free()
	for i in 3:
		await get_tree().process_frame
	Game.guildwar_clear_checkpoint()
	return out
