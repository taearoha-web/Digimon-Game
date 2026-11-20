extends Node
## The guild war's gates and the leader's orders (headless): the hero's attack button and
## auto go for the front tier's gate when no foe is near and hurt it, never a standing gate
## of a tier already open nor the holder's own gates; the hero leading our guild has the
## command button (บัญชาการ), a member leading it hides it; each order moves our fighters
## (gate, switch, rally round the hero, fall back, defend) and ตามแผน AI clears it.
## godot --headless --path . res://tests/integration/guild_war_orders_test.tscn
var failures: Array[String] = []
var checks := 0
const SEED := 515151


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
	Game.new_profile(&"warrior", "GWO")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	await _war()
	print("GUILD WAR ORDERS: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _war() -> void:
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(SEED, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {})
	Game.guildwar_resuming = true
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null, "the war is up")
	if m == null:
		return
	var hero: Hero = zone.hero
	m._timer = 0.05
	await _frames(6)
	check(m.state == "fight", "the fight begins")
	for f in m.all_fighters():
		f.set_physics_process(false)
		f.global_position = f.spawn_point + Vector3(0, 0.3, 0)
	m.set_process(false)
	hero._invulnerable_until = 0
	hero.stats.dodge = 0.0
	var gates := m.gates
	# --- The hero and the gates ---------------------------------------------
	hero.global_position = SiegeArena.gate_front(0, 0) + Vector3(0, 0.3, 1.0)
	hero.set_target(null)
	hero.tap_attack()
	check(hero.target == gates[0] and hero.engaged, "the attack button locks the front gate when no foe is near (%s)" % hero.target)
	var hp0 := gates[0].hp
	hero._deal(hero.target, 1.0, Color.WHITE, &"", true)
	check(gates[0].hp < hp0, "the hero's blow hurts the gate (%d -> %d)" % [hp0, gates[0].hp])
	# Far from the gate on the bridge: still the nearest gate to batter.
	hero.global_position = Vector3(10, 0.3, -8.0)
	hero.set_target(null)
	hero.tap_attack()
	check(hero.target == gates[1], "from the bridge the nearer front gate (%s)" % hero.target)
	# Auto with nobody round: it goes for the gate.
	hero.set_target(null)
	hero.set_auto(true)
	hero._auto_think()
	check(hero.auto and hero.target is CastleGate and (hero.target as CastleGate).breakable, "auto goes for a front gate (%s)" % hero.target)
	hero.set_auto(false)
	# Tier one opened by the right gate: the left one still stands but is not a target.
	gates[1].take_damage(float(gates[1].max_hp) * 2.0)
	await _frames(1)
	hero.global_position = SiegeArena.gate_front(0, 0) + Vector3(0, 0.3, 1.0)
	hero.set_target(null)
	check(not hero.mobs_in_range(30.0).has(gates[0]), "a standing gate of an open tier is no target")
	hero.tap_attack()
	check(hero.target == null or hero.target == gates[2] or hero.target == gates[3], "the attack button skips it (%s)" % hero.target)
	hero.set_target(null)
	hero.tap_target(gates[0])
	check(hero.target == null, "tapping it does not lock it")
	# Our own castle: our gates are not ours to batter.
	m.castle_owner = GuildFighter.TEAM_ALLY
	check(hero.war_gate() == null and not gates[2].open_to(hero), "holding the castle the hero does not batter its own gates")
	m.castle_owner = -1
	# --- The leader's orders --------------------------------------------------
	var hud := GuildWarHud.new()
	add_child(hud)
	hud.bind(m)
	hud._update(0.0, true)
	await _frames(2)
	check(m.hero_leads() and m.hero_commands() and hud.command_text() == GuildWarHud.COMMAND_LABEL, "the leading hero has the command button (%s)" % hud.command_text())
	hud.toggle_orders()
	check(hud.orders_open() and hud.order_buttons().size() >= 8, "it opens the orders (%d)" % hud.order_buttons().size())
	var small := 0
	for b in hud.order_buttons():
		if b.get_combined_minimum_size().y < 54.0:
			small += 1
	check(small == 0, "every order button is thumb-sized")
	var lines: Array[String] = []
	m.feed.connect(func(text: String, _t: int): lines.append(text))
	var c: GuildWarCommander = m.commanders[0]
	# Gate (tier two, the left gate).
	hud.press_order("gate", {"lane": 0})
	check(not hud.orders_open() and c.order == "gate" and hud.command_text().contains("ตีประตู"), "the gate order stands on the button (%s)" % hud.command_text())
	check(lines.any(func(t): return t.begins_with("หัวกิลสั่ง")), "the order is told in the war chat (%s)" % [lines])
	var at_gate := 0
	for f in m.allies:
		if f.objective == gates[2] and f.goal_point.distance_to(SiegeArena.gate_front(1, 0)) < 9.0:
			at_gate += 1
	check(at_gate >= m.allies.size() - 1, "every fighter goes for the left gate (%d of %d)" % [at_gate, m.allies.size()])
	# The switch waits for the gates.
	var said := m.order_guild("switch")
	check(not bool(said.ok) and c.order == "gate", "no switch order with the gates up")
	# Rally round the hero.
	hero.global_position = Vector3(-6, 0.3, -30.0)
	m.order_guild("rally")
	var near := 0
	for f in m.allies:
		if f.goal_point.distance_to(hero.global_position * Vector3(1, 0, 1)) < 8.0:
			near += 1
	check(near >= m.allies.size() - 1, "rally: everyone round the hero (%d of %d)" % [near, m.allies.size()])
	# Fall back to camp.
	m.order_guild("fallback")
	var home := m.home_of(0)
	check(m.allies.all(func(f): return f.goal_point.distance_to(home) < 8.0 and f.objective == null), "fall back: everyone to the camp")
	# Gates down: the switch, defend.
	for g in gates:
		if not g.is_dead():
			g.take_damage(float(g.max_hp) * 2.0)
	await _frames(1)
	m.order_guild("switch")
	check(c.order == "switch" and m.allies.all(func(f): return SiegeArena.on_switch(f.goal_point)), "switch: everyone into the circle")
	# The two switches: one side, then the other, then the guild split between them.
	hud.close_orders()
	hud.open_orders()
	var names := hud.order_buttons().map(func(b: Button): return String(b.name))
	for want in ["Order_switches", "Order_switch_0", "Order_switch_1"]:
		var b: Button = hud.order_buttons()[names.find(want)] if names.has(want) else null
		check(b != null and not b.disabled, "the panel offers %s with the gates down (%s)" % [want, names])
	check(hud.order_buttons().all(func(b: Button): return b.get_combined_minimum_size().x <= GuildWarHud.ORDER_BUTTON.x + 1.0), "the split order's two-line label fits its button")
	hud.press_order("switch", {"side": 0})
	check(c.order_name() == "ยึดสวิตช์ซ้าย" and hud.command_text() == "สั่ง: ยึดสวิตช์ซ้าย" and m.allies.all(func(f): return f.is_leader or SiegeArena.on_switch(f.goal_point, 0)), "ยึดสวิตช์ซ้าย: everyone into the left circle (%s)" % hud.command_text())
	check(c.said.any(func(t: String): return t.contains("ไปสวิตช์ซ้าย")), "the commander calls it out (%s)" % [c.said])
	hud.press_order("switch", {"side": 1})
	check(c.order_name() == "ยึดสวิตช์ขวา" and m.allies.all(func(f): return f.is_leader or (SiegeArena.on_switch(f.goal_point, 1) and f.switch_side == 1)), "ยึดสวิตช์ขวา: everyone into the right circle")
	lines.clear()
	hud.press_order("switches")
	check(c.order == GuildWarCommander.ORDER_SPLIT and c.order_name() == "แบ่งยึดสวิตช์ซ้าย-ขวา" and hud.command_text() == "สั่ง: แบ่งยึดซ้าย-ขวา", "the split order stands (%s)" % hud.command_text())
	var group: Array = [[], []]
	for f in m.allies:
		if f.is_leader:
			continue
		check(c.split_side.has(f.get_instance_id()), "every member has a side (%s)" % f.rival_name)
		(group[c.split_of(f)] as Array).append(f)
	check(absi((group[0] as Array).size() - (group[1] as Array).size()) <= 1, "two groups of the same size (%d / %d)" % [(group[0] as Array).size(), (group[1] as Array).size()])
	var power: Array[float] = [0.0, 0.0]
	var tanks: Array[int] = [0, 0]
	var support: Array[int] = [0, 0]
	for k in 2:
		for f in group[k]:
			power[k] += f.power
			var r := c._role(f, null)
			tanks[k] += 1 if r == GuildWarCommander.ROLE_TANK else 0
			support[k] += 1 if r == GuildWarCommander.ROLE_HEALER or r == GuildWarCommander.ROLE_BARD else 0
	check(minf(power[0], power[1]) >= maxf(power[0], power[1]) * 0.8, "balanced by strength (%.0f / %.0f)" % [power[0], power[1]])
	check(tanks[0] + tanks[1] < 2 or (tanks[0] >= 1 and tanks[1] >= 1), "a tank on each side (%s)" % [tanks])
	check(support[0] + support[1] < 2 or (support[0] >= 1 and support[1] >= 1), "a healer or bard on each side (%s)" % [support])
	for k in 2:
		var holders: Array = (group[k] as Array).filter(func(f): return f.switch_post)
		var guards: Array = (group[k] as Array).filter(func(f): return not f.switch_post)
		check(holders.size() >= 1 and holders.size() <= GuildWarCommander.SPLIT_HOLDERS and holders.all(func(f): return f.switch_side == k and SiegeArena.on_switch(f.goal_point, k)), "%s: the holders stand in the circle (%d)" % [SiegeArena.SWITCH_NAMES[k], holders.size()])
		var ring: Vector3 = SiegeArena.SWITCHES[k]
		check(guards.all(func(f): return not SiegeArena.on_switch(f.goal_point) and Vector2(f.goal_point.x - ring.x, f.goal_point.z - ring.z).length() < SiegeArena.SWITCH_RADIUS + GuildWarCommander.SPLIT_GUARD_RING + 1.0), "%s: the rest guard round its edge (%d)" % [SiegeArena.SWITCH_NAMES[k], guards.size()])
		check(holders.any(func(f): return c._role(f, null) == GuildWarCommander.ROLE_TANK) or tanks[k] == 0, "%s: a tank holds the circle" % SiegeArena.SWITCH_NAMES[k])
	check(c.said.any(func(t: String): return t.begins_with("แบ่งทีม!") and t.contains("สวิตช์ซ้าย") and t.contains("สวิตช์ขวา")), "the commander tells the split in the war chat (%s)" % [c.said])
	check(lines.any(func(t: String): return t.contains("หัวกิลสั่ง: แบ่งยึดสวิตช์ซ้าย-ขวา")), "and the order (%s)" % [lines])
	check(m.plans_line().contains("สั่ง: แบ่งยึดสวิตช์ซ้าย-ขวา") and m.sides_status().contains("สั่ง: แบ่งยึดสวิตช์ซ้าย-ขวา") and m.order_code() == "แบ่งยึดสวิตช์ซ้าย-ขวา", "the plan lines (HUD, watcher, online status) show it (%s)" % m.plans_line())
	# The groups stay put as fighters fall and come back.
	var keep := c.split_side.duplicate()
	c.apply()
	check(c.split_side == keep, "the groups are kept for the order's life")
	# They obey: let ours walk (theirs held at their camp) until both circles are ours.
	for f in m.allies:
		f.set_physics_process(true)
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 40000 and not m.holds_switch(GuildFighter.TEAM_ALLY):
		await get_tree().create_timer(0.5, true, false, true).timeout
		c.apply()
		m.read_switches()
	Engine.time_scale = 1.0
	check(m.holds_switch(GuildFighter.TEAM_ALLY) and m.count_switch(0)[0] >= 1 and m.count_switch(1)[0] >= 1, "split: our guild walks in and holds both switches (%s, %d / %d inside)" % [m.switch_owners, m.count_switch(0)[0], m.count_switch(1)[0]])
	for f in m.allies:
		f.set_physics_process(false)
	m.order_guild("defend")
	check(m.allies.filter(func(f): return f.goal_point.distance_to(SiegeArena.ALTAR) < 8.0).size() >= m.allies.size() / 2, "defend: round the altar")
	# Back to the AI.
	hud.press_order("auto")
	check(c.order == "" and not c.has_order() and hud.command_text() == GuildWarHud.COMMAND_LABEL, "ตามแผน AI clears the order")
	# A member leading our guild: no command button.
	m.ally_leader = GuildWarMatch.pick_leader(m.allies)
	hud._update(0.0, true)
	check(not m.hero_commands() and hud.command_text() == "" and not bool(m.order_guild("rally").ok), "a member leading: no command button, no orders")
	m.ally_leader = null
	m.mirror = true
	check(not m.hero_commands(), "a party member's view of its leader's war: no orders")
	m.mirror = false
	hud.queue_free()
	zone.queue_free()
	await _frames(2)
