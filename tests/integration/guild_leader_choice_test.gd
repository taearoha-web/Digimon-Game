extends Node
## The player picks who leads each guild (หัวหน้ากิลด์, Game.set_guild_leader): the save
## (profile.guild_leaders, validated, repaired, round trip), the fallbacks (a pick that
## left the guild, moving guild), the player's other characters (other save slots) as
## members of their guild, the guild screen's picker, and the guild war: by default the
## hero leads ours and the rival's strongest leads theirs; a member picked for ours is put
## in the line-up, crowned, tank-built, our commander's leader, takes the altar itself and
## the hero cannot; a member picked for theirs leads them; another character of the
## player picked to lead is not in the war and the default leads instead (told in a line).
## godot --headless --path . res://tests/integration/guild_leader_choice_test.tscn
var failures: Array[String] = []
var checks := 0

const ALT_NAME := "ราชาวานร"
const ALT_SLOT := 3
const MAIN_SLOT := 2
const ALT2_SLOT := 4
const ALT2_NAME := "เงาจันทร์"


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.set_process(false)
	GameSettings.load_settings()
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 20.0 * 86400.0 - WorldPlayers.now()
	_make_characters()
	_save_and_fallbacks()
	await _guild_screen()
	await _war_default()
	await _war_ally_leader()
	await _war_rival_leader()
	await _war_alt_leaders()
	_play_the_alt()
	WorldPresence.clock_offset = 0.0
	print("GUILD LEADER CHOICE: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _t() -> float:
	return WorldPresence.clock()


func _hero(cls: StringName, hero_name: String, stars: int) -> void:
	Game.new_profile(cls, hero_name)
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": stars, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(stars)}
	Game.profile.hp = Game.stats_now().max_hp


## Two other characters of the player (Neverdie and Alpha, Lv.100), then the one played
## (Alpha).
func _make_characters() -> void:
	Game.slot = ALT_SLOT
	_hero(&"lancer", ALT_NAME, 120)
	check(Game.join_guild(WorldPlayers.NEVERDIE), "the other character joins Neverdie")
	check(Game.save(), "the other character is saved in its slot")
	Game.slot = ALT2_SLOT
	_hero(&"mage", ALT2_NAME, 40)
	Game.join_guild(WorldPlayers.ALPHA)
	check(Game.save(), "a second other character (Alpha) is saved")
	# A low one in a guild flag but under Lv.100 is not a member (cannot be in a guild).
	Game.slot = 5
	Game.new_profile(&"archer", "เด็กใหม่")
	Game.profile.level = 40
	Game.profile.flags[Game.GUILD_FLAG] = WorldPlayers.NEVERDIE
	Game.save()
	Game.slot = MAIN_SLOT
	_hero(&"warrior", "GL", 200)
	Game.join_guild(WorldPlayers.ALPHA)
	check(Game.save(), "the played character is saved")


func _member_not(g: int, avoid: Array) -> String:
	var best := ""
	var best_level := 1 << 30
	for i in WorldPlayers.members_at(g, _t()):
		var s := WorldPlayers.state(i, _t())
		if avoid.has(String(s.name)):
			continue
		# The weakest: most likely out of a full line-up (it must be brought in).
		var score := int(s.level) * 1000 + int(s.get("stars", 0))
		if score < best_level:
			best_level = score
			best = String(s.name)
	return best


func _save_and_fallbacks() -> void:
	var t := _t()
	var alpha := WorldPlayers.ALPHA
	var never := WorldPlayers.NEVERDIE
	check(WorldPlayers.members_at(alpha, t).size() >= 3 and WorldPlayers.members_at(never, t).size() >= 3, "both guilds have members on day 20")
	# Defaults: the hero leads its own guild, the other's strongest leads it.
	check(Game.hero_leads_guild(alpha) and Game.guild_leader_name(alpha) == "" and String(Game.guild_leader_of(alpha).kind) == "hero", "by default the hero leads its own guild")
	check(Game.guild_leader_name(never) == WorldPlayers.guild_leader(never, t), "by default the other guild's strongest leads it (%s)" % Game.guild_leader_name(never))
	check(Game.guild_leader_label(alpha).begins_with("คุณ"), "the hero shown as leader: %s" % Game.guild_leader_label(alpha))
	# The other characters: only those at Lv.100 in that guild, never the played one.
	var alts_n := Game.guild_alts(never)
	var alts_a := Game.guild_alts(alpha)
	check(alts_n.size() == 1 and String(alts_n[0].name) == ALT_NAME and int(alts_n[0].slot) == ALT_SLOT and int(alts_n[0].level) == 100 and int(alts_n[0].stars) == 120 and String(alts_n[0]["class"]) == "lancer", "Neverdie lists the player's other character only (%s)" % [alts_n])
	check(alts_a.size() == 1 and String(alts_a[0].name) == ALT2_NAME, "Alpha lists the other Alpha character, not the one played (%s)" % [alts_a])
	# The game registry lists every character the player made (the low one too), not played now.
	var reg := RegistryScreen.rows(t)
	var mine := reg.filter(func(r): return bool(r.get("alt", false)))
	check(mine.size() == 3 and mine.any(func(r): return String(r.name) == ALT_NAME and int(r.guild) == never and not bool(r.online)), "the registry lists the player's other characters (%s)" % [mine.map(func(r): return r.name)])
	check(not mine.any(func(r): return int(r.slot) == MAIN_SLOT), "the played one is not listed twice")
	check(mine.any(func(r): return String(r.name) == "เด็กใหม่" and int(r.guild) == 0), "a character under Lv.100 shows without a guild")
	# Picks.
	var mate := _member_not(alpha, [])
	check(mate != "" and Game.set_guild_leader(alpha, mate), "a member of our guild can be picked to lead it")
	check(Game.guild_leader_name(alpha) == mate and not Game.hero_leads_guild(alpha) and Game.guild_war_leader(alpha) == mate, "our guild is led by %s" % mate)
	var rival := _member_not(never, [WorldPlayers.guild_leader(never, t)])
	check(rival != "" and Game.set_guild_leader(never, rival) and Game.guild_leader_name(never) == rival, "a member of the other guild can be picked to lead it (%s)" % rival)
	check(not Game.set_guild_leader(alpha, rival), "a member of the other guild cannot lead ours")
	check(not Game.set_guild_leader(alpha, "ไม่มีคนนี้"), "nobody unknown can lead")
	check(not Game.set_guild_leader(alpha, Game.alt_pick(ALT_SLOT)), "a character in the other guild cannot lead ours")
	check(not Game.set_guild_leader(alpha, Game.alt_pick(MAIN_SLOT)), "the played slot is not an 'other character'")
	# The save: valid, kept through a save and a load, junk refused or repaired.
	check(Game._valid_profile(Game.profile), "the game accepts its own save with leaders")
	check(Game.save(), "saved with the picks")
	check(Game.load_game(MAIN_SLOT), "loaded back")
	check(Game.guild_leader_pick(alpha) == mate and Game.guild_leader_pick(never) == rival, "the picks come back from the save (%s)" % Game.profile.get("guild_leaders"))
	var bad := Game.profile.duplicate(true)
	bad["guild_leaders"] = ["x"]
	check(not Game._valid_profile(bad), "a list for guild leaders is refused")
	bad["guild_leaders"] = {"1": 5}
	check(not Game._valid_profile(bad), "a number for a leader is refused")
	bad["guild_leaders"] = {"1": "x".repeat(200)}
	check(not Game._valid_profile(bad), "an over-long leader name is refused")
	bad["guild_leaders"] = {"1": mate, "9": "ใครก็ได้", "abc": ""}
	check(Game._valid_profile(bad), "unknown guild keys pass the type check")
	var fixed := Game._repair(bad)
	check(fixed.guild_leaders == {"1": mate}, "and the repair keeps only the two guilds (%s)" % [fixed.guild_leaders])
	var old := Game.profile.duplicate(true)
	old.erase("guild_leaders")
	check(Game._valid_profile(old) and not Game._repair(old).has("guild_leaders"), "an old save without leaders loads with the defaults")
	# A pick that left (not a member any more) falls back to the default.
	Game.profile["guild_leaders"] = {"1": rival, "2": mate}
	check(Game.hero_leads_guild(alpha), "a pick who is not in our guild: the hero leads again")
	check(Game.guild_leader_name(never) == WorldPlayers.guild_leader(never, t), "a pick who is not in theirs: their strongest leads again")
	Game.profile["guild_leaders"] = {"1": Game.alt_pick(9)}
	check(Game.hero_leads_guild(alpha), "a deleted other character: the hero leads again")
	# Moving guild: the new guild is led by the hero, the old one by its default.
	Game.profile["guild_leaders"] = {"1": mate, "2": rival}
	check(Game.join_guild(never), "the hero moves to Neverdie")
	check(Game.hero_leads_guild(never) and Game.guild_leader_pick(never) == "", "moving resets our own guild's leader to the hero")
	check(Game.guild_leader_pick(alpha) == "" and Game.guild_leader_name(alpha) == WorldPlayers.guild_leader(alpha, t), "the guild left is led by its strongest again")
	check(Game.join_guild(alpha), "and back to Alpha")
	check(Game.hero_leads_guild(alpha), "back home the hero leads")
	Game.profile.erase("guild_leaders")


func _labels(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_labels(child, out)


func _guild_screen() -> void:
	var alpha := WorldPlayers.ALPHA
	var never := WorldPlayers.NEVERDIE
	var t := _t()
	var screen := GuildScreen.new()
	add_child(screen)
	await _frames(1)
	screen.open_roster()
	await _frames(2)
	var texts: Array[String] = []
	_labels(screen, texts)
	check(texts.any(func(x: String): return x.begins_with("%s (ตัวละครของคุณ)" % ALT_NAME)), "the guild screen lists the other character in Neverdie")
	check(texts.any(func(x: String): return x.contains("ไม่ได้เล่นอยู่")), "tagged as not being played")
	check(texts.has("สมาชิก %d คน · ออนไลน์ %d" % [WorldPlayers.members_at(never, t).size() + 1, WorldPlayers.members_at(never, t).filter(func(i): return bool(WorldPlayers.state(i, t).online)).size()]), "Neverdie's member count includes it")
	var lead_a := screen.find_child("LeaderAlpha", true, false) as Label
	check(lead_a != null and lead_a.text.contains("คุณ (GL)"), "Alpha's leader line names the hero (%s)" % (lead_a.text if lead_a else "-"))
	var btn_a := screen.find_child("PickLeaderAlpha", true, false) as Button
	var btn_n := screen.find_child("PickLeaderNeverdie", true, false) as Button
	check(btn_a != null and btn_n != null and not btn_a.disabled and not btn_n.disabled, "each guild column has a เลือกหัวหน้ากิลด์ button")
	# Our guild's picker: ตัวฉัน first (the current leader), then every member, the other
	# Alpha character among them.
	btn_a.pressed.emit()
	await _frames(2)
	var picker := screen.find_child("LeaderPicker", true, false)
	check(picker != null, "the picker opens")
	if picker == null:
		return
	var picks := _picks(picker)
	check(picks.size() == WorldPlayers.members_at(alpha, t).size() + 2, "it lists ตัวฉัน, every Alpha member and the other Alpha character (%d)" % picks.size())
	check(not picks.is_empty() and String(picks[0].get_meta("pick")) == "" and picks[0].disabled and picks[0].text == "หัวหน้าตอนนี้", "ตัวฉัน first, marked as the leader now")
	var mine_texts: Array[String] = []
	_labels(picker, mine_texts)
	check(mine_texts.any(func(x: String): return x.begins_with("ตัวฉัน")), "the hero's row reads ตัวฉัน")
	check(picks.size() > 1 and String(picks[1].get_meta("pick")) == Game.alt_pick(ALT2_SLOT) and not picks[1].disabled, "the other Alpha character comes right after ตัวฉัน and can be picked")
	var mate := _member_not(alpha, [])
	var mate_btn: Button = null
	for b in picks:
		if String(b.get_meta("pick")) == mate:
			mate_btn = b
	check(mate_btn != null and not mate_btn.disabled, "the member %s is offered" % mate)
	if mate_btn != null:
		mate_btn.pressed.emit()
	await _frames(2)
	check(Game.guild_leader_pick(alpha) == mate, "choosing saves the pick")
	check(screen.find_child("LeaderPicker", true, false) == null or screen.find_child("LeaderPicker", true, false).is_queued_for_deletion(), "and closes the picker")
	lead_a = screen.find_child("LeaderAlpha", true, false) as Label
	check(lead_a != null and lead_a.text.contains(mate), "the leader line shows the new leader (%s)" % (lead_a.text if lead_a else "-"))
	# The other guild's picker: its members and the player's character there, no ตัวฉัน.
	btn_n = screen.find_child("PickLeaderNeverdie", true, false) as Button
	btn_n.pressed.emit()
	await _frames(2)
	picker = screen.find_child("LeaderPicker", true, false)
	picks = _picks(picker) if picker != null else []
	check(picks.size() == WorldPlayers.members_at(never, t).size() + 1 and picks.all(func(b: Button): return String(b.get_meta("pick")) != ""), "Neverdie's picker lists its members and the other character, no ตัวฉัน (%d)" % picks.size())
	var current := picks.filter(func(b: Button): return b.disabled)
	check(current.size() == 1 and String(current[0].get_meta("pick")) == WorldPlayers.guild_leader(never, t), "their strongest is marked as the leader now")
	var alt_btn: Button = null
	for b in picks:
		if String(b.get_meta("pick")) == Game.alt_pick(ALT_SLOT):
			alt_btn = b
	check(alt_btn != null and not alt_btn.disabled and picks[0] == alt_btn, "the other character in Neverdie is listed first and can be picked")
	if alt_btn != null:
		alt_btn.pressed.emit()
	await _frames(2)
	check(Game.guild_leader_pick(never) == Game.alt_pick(ALT_SLOT), "picking it saves it")
	var lead_n := screen.find_child("LeaderNeverdie", true, false) as Label
	check(lead_n != null and lead_n.text.contains("%s (ตัวละครของคุณ · ไม่ได้เล่นอยู่)" % ALT_NAME), "Neverdie's leader line names it as the player's character (%s)" % (lead_n.text if lead_n else "-"))
	# Closing the screen closes a picker left open.
	screen.open_leader_picker(never)
	await _frames(1)
	screen.close_screen()
	await _frames(2)
	check(screen.find_child("LeaderPicker", true, false) == null, "closing the screen drops the picker")
	screen.queue_free()
	await _frames(2)
	get_tree().paused = false
	Game.profile.erase("guild_leaders")


func _picks(picker: Node) -> Array[Button]:
	var out: Array[Button] = []
	for b in picker.find_children("Pick_*", "Button", true, false):
		out.append(b as Button)
	out.sort_custom(func(a: Button, b: Button): return int(a.name.substr(5)) < int(b.name.substr(5)))
	return out


func _open_war() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_resuming = false
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _close_war(zone: Zone) -> void:
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _names(side: Array) -> Array[String]:
	var out: Array[String] = []
	for f in side:
		out.append(String(f.member.get("name", "")))
	return out


func _war_default() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and bool(m.roster.get("guilds", false)), "default: a war between the two guilds")
	if m == null:
		return
	var hero: Hero = zone.hero
	check(m.hero_leads() and m.leader_of(GuildFighter.TEAM_ALLY) == hero and m.ally_leader == null, "default: the hero leads ours")
	check(hero.get_node_or_null(LeaderMark.NAME) != null and m.allies.all(func(f): return not f.is_leader), "default: the crown on the hero, none on our fighters")
	var strongest := WorldPlayers.guild_leader(WorldPlayers.NEVERDIE, float(m.started_at))
	check(m.enemy_leader != null and m.enemy_leader.is_leader, "default: the rivals have a leader")
	if _names(m.enemies).has(strongest):
		check(String(m.enemy_leader.member.name) == strongest, "default: their strongest in the line-up leads them")
	check(not _names(m.allies).has(ALT2_NAME) and not _names(m.enemies).has(ALT_NAME), "the player's other characters are not in the war")
	check(m.stand_in_lines().is_empty(), "default: nobody stands in")
	await _close_war(zone)


func _war_ally_leader() -> void:
	var alpha := WorldPlayers.ALPHA
	var mate := _member_not(alpha, [])
	Game.set_guild_leader(alpha, mate)
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "ally leader: no match")
		return
	var hero: Hero = zone.hero
	var lead := m.ally_leader
	check(lead != null and String(lead.member.name) == mate, "ally leader: %s is in our line-up and leads it" % mate)
	if lead == null:
		await _close_war(zone)
		return
	check(lead.is_leader and lead.get_node_or_null(LeaderMark.NAME) != null and String(lead.template.name).contains("ผู้นำ"), "ally leader: crowned and named leader")
	check(m.allies.filter(func(f): return f.is_leader).size() == 1, "ally leader: only one of ours leads")
	check(hero.get_node_or_null(LeaderMark.NAME) == null, "ally leader: no crown on the hero")
	var entry: Dictionary = {}
	for info in m.roster.ally:
		if String(info.member.name) == mate:
			entry = info
	check(bool(entry.get("tank", false)), "ally leader: plays a tank's build of its own points")
	var attr_sum := 0
	for key in lead._profile.attrs:
		attr_sum += int(lead._profile.attrs[key])
	check(int(lead._profile.attrs.vit) >= attr_sum * 0.7, "ally leader: VIT-heavy (vit %d of %d)" % [int(lead._profile.attrs.vit), attr_sum])
	var base := HeroStats.compute(lead._profile)
	check(lead.max_hp == int(base.max_hp), "ally leader: no bonus on top of its sheet")
	check(m.leader_of(GuildFighter.TEAM_ALLY) == lead and m.commanders[0].leader() == lead and not m.hero_leads(), "ally leader: our commander's leader")
	# The fight; the AI is held still.
	m._timer = 0.05
	await _frames(6)
	for f in m.all_fighters():
		f._guard_until = 0
		f._dodge = 0.0
		f.set_physics_process(false)
	m.set_process(false)
	var ours: GuildWarCommander = m.commanders[0]
	ours.think(GuildWarCommander.THINK_EVERY)
	check(bool(ours.last_read.leader_ai), "ally leader: our commander plans around an AI leader")
	for g in m.gates:
		g.set_broken_quietly()
	m._update_breakable()
	m.plans.assign(["storm", "storm"])
	# Gates down: our AI leader goes up inside its escort; the hero on the altar cannot.
	for f in m.enemies:
		f.global_position = Vector3(SiegeArena.BASE_X + 20.0, 0.3, 20.0)
	for f in m.allies:
		f.global_position = Vector3(-SiegeArena.BASE_X, 0.3, SiegeArena.BASE_Z)
	lead.global_position = Vector3(0, 0.3, SiegeArena.GATE_Z[2] - 6.0)
	var k := 0
	for f in m.allies:
		if f != lead and k < 3:
			f.global_position = lead.global_position + Vector3(2.0 + k, 0.3, 1.0)
			k += 1
	# Both switches held for us (pinned; castle_switch_test holds them for real).
	m.switch_pin = GuildFighter.TEAM_ALLY
	ours.tactic = GuildWarCommander.GATHER
	ours.since = 1.0
	ours.think(GuildWarCommander.THINK_EVERY)
	m._assign_objectives()
	check(ours.tactic == GuildWarCommander.ESCORT and lead.capture_role, "ally leader: escorted to the altar (%s)" % ours.tactic)
	check(m.allies.filter(func(f): return f.capture_role).size() == 1, "ally leader: only the leader is sent onto the altar")
	var tanks := m.allies.filter(func(f): return f.role == GuildWarCommander.ROLE_TANK and f != lead)
	check(tanks.all(func(f): return f.guard_node == lead or f.switch_post >= 0), "ally leader: our tanks guard it (but the ones holding a switch)")
	var toasts: Array[String] = []
	var listen := func(text: String, _kind: StringName): toasts.append(text)
	Game.toast.connect(listen)
	hero.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	check(not m.hero_can_capture() and m.hero_on_altar_not_leader(), "ally leader: the hero on the altar cannot take it")
	zone._update_interact()
	check(not zone.current_interact.has("altar"), "ally leader: no altar button for the hero")
	m._altar_hint_tick()
	m._altar_hint_tick()
	check(toasts.filter(func(x: String): return x.contains("เฉพาะหัวหน้ากิลด์") and x.contains(mate)).size() == 1, "ally leader: a hint says only the leader takes it, once (%s)" % [toasts])
	m.start_hero_capture()
	check(m.capture.is_empty(), "ally leader: pressing does nothing for the hero")
	hero.global_position = GuildWarMatch.hero_camp()
	m._altar_hint_tick()
	Game.toast.disconnect(listen)
	# The leader steps on: it takes the altar for us.
	lead.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	m._tick_capture(0.1)
	check(not m.capture.is_empty() and int(m.capture.team) == GuildFighter.TEAM_ALLY and m.capturer() == lead and lead.capturing, "ally leader: it starts taking the castle (%s)" % m.capture)
	ours.think(GuildWarCommander.THINK_EVERY)
	check(ours.tactic == GuildWarCommander.GUARD, "ally leader: ours guard it on the altar (%s)" % ours.tactic)
	var theirs: GuildWarCommander = m.commanders[1]
	for f in m.enemies:
		f.global_position = SiegeArena.ALTAR + Vector3(6.0, 0.3, 6.0)
	theirs.think(GuildWarCommander.THINK_EVERY)
	check(theirs.tactic == GuildWarCommander.DEFEND and theirs.focus == lead, "ally leader: the rivals go for our leader on the altar")
	m._tick_capture(5.0)
	check(float(m.capture.get("progress", 0.0)) >= 5.0, "ally leader: the hold counts up")
	# It falls: the count starts over.
	var tries := 0
	while not lead.is_dead() and tries < 80:
		BurstGuard.clear()
		lead.take_hit(lead.max_hp, false)
		tries += 1
	m._tick_capture(0.1)
	check(lead.is_dead() and m.capture.is_empty() and m.castle_owner == -1, "ally leader: felled, the count starts over")
	# Back up, a full hold takes the castle for us.
	lead.respawn()
	lead.global_position = SiegeArena.ALTAR + Vector3(0, 0.3, 0)
	lead.capture_role = true
	for f in m.enemies:
		f.global_position = Vector3(SiegeArena.BASE_X + 20.0, 0.3, 20.0)
	m._tick_capture(0.1)
	check(m.capturer() == lead, "ally leader: back on the altar it starts again")
	m._tick_capture(GuildWarMatch.CAPTURE_TIME)
	check(m.castle_owner == GuildFighter.TEAM_ALLY, "ally leader: a full hold takes the castle for our guild")
	check(m.leader_of(GuildFighter.TEAM_ENEMY) == m.enemy_leader, "the rivals still have their own leader")
	await _close_war(zone)
	# The line-up must bring a picked member in when it is not there.
	var lineup: Array = []
	var others := WorldPlayers.members_at(alpha, _t())
	for i in others:
		var s := WorldPlayers.state(i, _t())
		if String(s.name) != mate and lineup.size() < 3:
			lineup.append(WorldPlayers.fighter(i, _t()))
	var last := String(lineup[lineup.size() - 1].member.name)
	check(GuildWarMatch.ensure_member(lineup, mate, _t()) and lineup.size() == 3 and _names(lineup).has(mate) and not _names(lineup).has(last), "a picked member missing from the line-up takes the last place")
	Game.profile.erase("guild_leaders")


func _war_rival_leader() -> void:
	var never := WorldPlayers.NEVERDIE
	var rival := _member_not(never, [WorldPlayers.guild_leader(never, _t())])
	Game.set_guild_leader(never, rival)
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "rival leader: no match")
		return
	check(_names(m.enemies).has(rival), "rival leader: %s is in their line-up" % rival)
	check(m.enemy_leader != null and String(m.enemy_leader.member.name) == rival and m.enemies.filter(func(f): return f.is_leader).size() == 1, "rival leader: %s leads them" % rival)
	var entry: Dictionary = {}
	for info in m.roster.enemy:
		if String(info.member.name) == rival:
			entry = info
	check(bool(entry.get("tank", false)), "rival leader: tank build")
	check(m.hero_leads() and zone.hero.get_node_or_null(LeaderMark.NAME) != null, "rival leader: the hero still leads ours")
	await _close_war(zone)
	Game.profile.erase("guild_leaders")


func _war_alt_leaders() -> void:
	var alpha := WorldPlayers.ALPHA
	var never := WorldPlayers.NEVERDIE
	check(Game.set_guild_leader(never, Game.alt_pick(ALT_SLOT)) and Game.set_guild_leader(alpha, Game.alt_pick(ALT2_SLOT)), "both guilds led by the player's other characters")
	check(Game.guild_war_leader(alpha) == "" and Game.guild_war_leader(never) == WorldPlayers.guild_leader(never, _t()), "in the war the defaults lead in their place")
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "alt leaders: no match")
		return
	check(not _names(m.allies).has(ALT2_NAME) and not _names(m.enemies).has(ALT_NAME), "alt leaders: never in the war")
	check(m.hero_leads() and m.leader_of(GuildFighter.TEAM_ALLY) == zone.hero, "alt leaders: the hero leads ours in place of the other character")
	check(m.enemy_leader != null and m.enemy_leader.is_leader, "alt leaders: their default leads theirs")
	var lines := m.stand_in_lines()
	check(lines.size() == 2, "alt leaders: a line for each guild (%s)" % [lines])
	check(lines.any(func(x: String): return x.contains("หัวหน้ากิลด์ %s ไม่ได้ลงสนาม" % ALT_NAME) and x.contains(String(m.enemy_leader.member.name) + " นำทัพ")), "alt leaders: told who leads Neverdie instead (%s)" % [lines])
	check(lines.any(func(x: String): return x.contains("หัวหน้ากิลด์ %s ไม่ได้ลงสนาม" % ALT2_NAME) and x.contains("คุณ นำทัพ")), "alt leaders: told the hero leads Alpha instead (%s)" % [lines])
	await _close_war(zone)
	check(Game.save(), "the played character saved with its picks")


## Playing the other character: it is the hero then, and leads its own guild by default.
func _play_the_alt() -> void:
	check(Game.load_game(ALT_SLOT), "the player switches to the other character")
	check(Game.guild() == WorldPlayers.NEVERDIE and Game.hero_leads_guild(WorldPlayers.NEVERDIE) and Game.guild_war_leader(WorldPlayers.NEVERDIE) == "", "played, it leads Neverdie itself")
	var alts := Game.guild_alts(WorldPlayers.ALPHA)
	check(alts.any(func(a): return String(a.name) == "GL") and alts.any(func(a): return String(a.name) == ALT2_NAME), "and the first character is listed in Alpha now (%s)" % [alts])
	check(Game.guild_alts(WorldPlayers.NEVERDIE).is_empty(), "the one played is not listed as another character")
