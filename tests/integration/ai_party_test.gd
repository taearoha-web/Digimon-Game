extends Node
## The world players party up among themselves (WorldParties): parties of 2-5 people of a
## similar level hunting the same field, the same on every device for the same moment
## (worked out again from scratch, the same parties come out), breaking up and forming
## anew over time; partying levels a player faster than hunting alone; in the field the
## party hunts together (the others keep near the leader and fight its camp), a healer
## heals a hurt mate, a Dark Lord's Summon pulls a straggler back (never the hero), the
## name plate and the card say whose party it is, and the hero can still ask one of them
## into its own party (it comes alone, or now and then politely says no).
##   godot --headless --path . res://tests/integration/ai_party_test.tscn
var failures := 0
var checks := 0
var main: Node


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.persist = false
	WorldPlayers.clear_bonus()
	var t := _party_moment(float(WorldPlayers.START_UNIX) + 2.0 * 86400.0)
	check(t > 0.0, "parties of world players are about at some point")
	if t <= 0.0:
		_finish()
		return
	_forming(t)
	_rotation(t)
	_exp()
	await _field(t)
	await _invite(t)
	_finish()


func _finish() -> void:
	WorldPresence.clock_offset = 0.0
	print("AI PARTY: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## A moment from `from` on with at least two parties in the world, one of them of three or
## more in an ordinary field.
func _party_moment(from: float) -> float:
	var t := from
	while t < from + 6.0 * 86400.0:
		var all := WorldParties.parties_at(t)
		if all.size() >= 2 and all.any(func(p): return (p.members as Array).size() >= 3):
			return t
		t += 1800.0
	return -1.0


func _key(parties: Array) -> Array:
	var out: Array = []
	for p in parties:
		out.append([String(p.id), (p.members as Array).duplicate(), int(p.leader), String(p.zone)])
	out.sort()
	return out


func _forming(t: float) -> void:
	var first := _key(WorldParties.parties_at(t))
	WorldParties.clear_cache()
	var again := _key(WorldParties.parties_at(t))
	check(first == again and not first.is_empty(), "the same moment gives the same parties when worked out again (%d parties)" % first.size())
	var sizes_ok := true
	var band_ok := true
	var place_ok := true
	var lead_ok := true
	var in_two := {}
	var unique := true
	for p in WorldParties.parties_at(t):
		var members: Array = p.members
		sizes_ok = sizes_ok and members.size() >= WorldParties.SIZE_MIN and members.size() <= WorldParties.SIZE_MAX
		lead_ok = lead_ok and int(p.leader) == int(members[0])
		var lead := WorldParties.hunter(int(p.leader), float(p.from))
		for m in members:
			unique = unique and not in_two.has(int(m))
			in_two[int(m)] = true
			var h := WorldParties.hunter(int(m), float(p.from))
			band_ok = band_ok and not h.is_empty() and WorldParties.fits(lead, h)
			var s := WorldPlayers.state(int(m), t)
			place_ok = place_ok and bool(s.online) and String(s.place) == String(p.zone) and String(s.party_id) == String(p.id) and int(s.party_leader) == int(p.leader)
			band_ok = band_ok and absi(int(s.level) - int(WorldPlayers.state(int(p.leader), t).level)) <= WorldParties.BAND + 6
	check(sizes_ok, "every party has two to five people")
	check(lead_ok, "the leader is the party's first")
	check(unique, "nobody is in two parties at once")
	check(band_ok, "a party's people are of a similar level (within %d levels or %d stars)" % [WorldParties.BAND, WorldParties.STAR_BAND])
	check(place_ok, "the state of each member names its party and its field")
	# Stall keepers never party; some hunters prefer to go alone.
	var solo_hunters := 0
	for i in WorldPlayers.size():
		var s := WorldPlayers.state(i, t)
		if WorldPlayers.in_town_style(i):
			check(String(s.party_id) == "", "%s keeps its stall alone" % s.name)
		elif bool(s.online) and String(s.doing) == "hunt" and String(s.party_id) == "":
			solo_hunters += 1
	check(solo_hunters > 0, "some hunters hunt alone (%d)" % solo_hunters)
	check(WorldParties.taste(WorldPlayers.index_of(String(WorldPlayers.ROSTER[0].name))) >= 0.0, "taste is a share")


## Parties last a while and break up: the same party a few minutes later, other parties
## hours later; someone who logs off leaves its party.
func _rotation(t: float) -> void:
	var now := WorldParties.parties_at(t)
	var soon := WorldParties.parties_at(t + 60.0)
	var kept := 0
	var soon_ids := soon.map(func(p): return String(p.id))
	for p in now:
		kept += 1 if soon_ids.has(String(p.id)) else 0
	check(kept >= maxi(1, now.size() - 2), "a minute later most parties are still together (%d of %d)" % [kept, now.size()])
	var later_ids := {}
	for p in WorldParties.parties_at(t + 4.0 * WorldParties.SLOT):
		later_ids[String(p.id)] = true
	var same := 0
	for p in now:
		same += 1 if later_ids.has(String(p.id)) else 0
	check(same == 0, "two hours later the parties have changed (%d still the same)" % same)
	# Over a day many different parties form, and a player's partners change.
	var ids := {}
	var partners := {}
	var x := t
	while x < t + 86400.0:
		for p in WorldParties.parties_at(x):
			ids[String(p.id)] = true
			for m in p.members:
				var key := int(m)
				if not partners.has(key):
					partners[key] = {}
				for o in p.members:
					if int(o) != key:
						partners[key][int(o)] = true
		x += WorldParties.SLOT
	var changing := partners.values().filter(func(d): return (d as Dictionary).size() >= 2).size()
	check(ids.size() >= 10, "many parties form over a day (%d)" % ids.size())
	check(changing > 0, "players party with different people over the day (%d)" % changing)
	# Someone logging off leaves its party: a member whose session ends within the slot.
	var gone_ok := false
	var found := false
	for p in now:
		for m in p.members:
			var s := WorldPlayers.session_at(int(m), t)
			if s.is_empty() or float(s[1]) >= float(p.until):
				continue
			found = true
			var after := float(s[1]) + 60.0
			gone_ok = WorldParties.party_of(int(m), after).is_empty()
			for o in p.members:
				if int(o) != int(m):
					var q := WorldParties.party_of(int(o), after)
					gone_ok = gone_ok and (q.is_empty() or not (q.members as Array).has(int(m)))
			break
		if found:
			break
	if found:
		check(gone_ok, "a member who logs off has left its party")


## Partying levels faster: the same player over the same play earns more with its party
## share; a stall keeper (who never parties) earns nothing extra.
func _exp() -> void:
	var t := float(WorldPlayers.START_UNIX) + 5.0 * 86400.0
	var social := -1
	var afk := -1
	for i in WorldPlayers.size():
		if afk < 0 and WorldPlayers.in_town_style(i):
			afk = i
		if social < 0 and WorldParties.taste(i) >= 0.4 and not WorldPlayers.ROSTER[i].has("vet"):
			social = i
	check(social >= 0 and afk >= 0, "a player who likes parties and a stall keeper")
	if social < 0 or afk < 0:
		return
	check(WorldPlayers.party_work(afk, t) == 0.0, "a stall keeper earns nothing from parties")
	var eff := WorldPlayers.efficiency(social)
	var minutes := WorldPlayers.own_minutes(social, t)
	var others := WorldPlayers.bonus_work(social) + WorldPlayers.head_work(social) + WorldPlayers.halloween_work(social, t)
	var solo := WorldPlayers.progress_for(minutes, eff, others)
	var s := WorldPlayers.state(social, t)
	var points_solo := (int(solo.level) + int(solo.stars)) * 1000.0 + float(solo.frac) * 999.0
	var points := (int(s.level) + int(s.stars)) * 1000.0 + float(s.frac) * 999.0
	check(WorldPlayers.party_work(social, t) > 0.0 and points > points_solo, "%s levels faster for its parties (Lv.%d ★%d vs Lv.%d ★%d alone)" % [s.name, int(s.level), int(s.stars), int(solo.level), int(solo.stars)])
	var share := WorldPlayers.party_work(social, t) / maxf(0.001, minutes * eff)
	check(share > 0.0 and share <= WorldParties.EXP_BONUS, "the party bonus is modest (%.1f%% more)" % (share * 100.0))
	# Two players of one style: the one who parties more is further along per minute played.
	check(WorldParties.EXP_BONUS > 0.0 and WorldParties.EXP_BONUS <= 0.3, "partying pays a modest bonus")


func _field(t: float) -> void:
	WorldPresence.enabled = true
	GameSettings.show_world_players = true
	InputSetup.ensure_defaults()
	# A party in a hunting field to walk into.
	var party := {}
	var x := t
	while party.is_empty() and x < t + 3.0 * 86400.0:
		for p in WorldParties.parties_at(x):
			var z := ZoneData.get_zone(StringName(p.zone))
			if (p.members as Array).size() >= 2 and String(z.get("scene", "")) == "field" and not z.get("pvp", false):
				party = p
				t = x
				break
		x += 1800.0
	check(not party.is_empty(), "a party hunts in a field at some point")
	if party.is_empty():
		return
	WorldPresence.clock_offset = t - WorldPlayers.now()
	Game.new_profile(&"warrior", "AI Party QA", FaceKit.default_look())
	Game.profile.level = clampi(int(WorldPlayers.state(int(party.leader), t).level), 1, 100)
	Game.profile.adv = JobData.adv_for_level(int(Game.profile.level))
	Game.paragon().level = int(WorldPlayers.state(int(party.leader), t).stars)
	Game.profile.party = []
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	await main.go(StringName(party.zone), true)
	await get_tree().create_timer(1.0).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	check(zone.zone_id == StringName(party.zone) and not zone._camps.is_empty(), "the hero walks into the party's field (%s)" % zone.zone_id)
	if zone.zone_id != StringName(party.zone) or zone._camps.is_empty():
		return
	check(zone.presence != null, "the field shows the world players")
	# The party's people are shown together.
	var shown_members := 0
	for m in party.members:
		var f: Variant = zone.presence.shown.get(int(m))
		if f != null and is_instance_valid(f):
			shown_members += 1
			check(String((f as FieldPlayer).ai_party_id) == String(party.id), "%s knows its party" % (f as FieldPlayer).member.name)
			check(String((f as FieldPlayer)._label.text).contains("ปาร์ตี้ของ %s" % WorldPlayers.entry(int(party.leader)).name), "the name plate says whose party (%s)" % (f as FieldPlayer)._label.text)
	check(shown_members >= mini(2, (party.members as Array).size()) or zone.presence.shown.size() >= WorldPresence.limit_here(false) - 1, "the party is shown together (%d of %d)" % [shown_members, (party.members as Array).size()])
	# A party of our own making in this field: a leader, a priest and a Dark Lord, each
	# its real world player, kept from dying, spread far apart to begin with.
	# (The schedule's own look at who stands here waits meanwhile.)
	zone.presence._timer = 9999.0
	for i in zone.presence.shown.keys():
		zone.presence._drop_shown(i)
	await get_tree().process_frame
	var lead_i := WorldPlayers.first_of(&"warrior")
	var priest_i := WorldPlayers.first_of(&"priest")
	var lord_i := WorldPlayers.first_of(&"darklord")
	var level := clampi(int(WorldPlayers.state(int(party.leader), t).level), 40, 99)
	var fake := {"party_id": "test|party", "party_leader": lead_i, "party_members": [lead_i, priest_i, lord_i]}
	var bodies := {}
	# The camp farthest from the field's portals (the hero stands near the party there).
	var camp: Dictionary = zone._camps[0]
	var best := -1.0
	for c in zone._camps:
		var gap := INF
		for portal in zone.portals:
			gap = minf(gap, Vector2(c.pos.x - portal.pos.x, c.pos.y - portal.pos.z).length())
		if gap > best:
			best = gap
			camp = c
	var k := 0
	for i in [lead_i, priest_i, lord_i]:
		var m := WorldPlayers.member(i, t)
		m["class"] = String(WorldPlayers.entry(i)["class"])
		m["level"] = level
		m["stars"] = 0
		var f := FieldPlayer.new()
		f.setup_world(i, m, hero, zone)
		f.doing = "hunt"
		f.set_ai_party(fake)
		zone.add_child(f)
		zone.presence.shown[i] = f
		f.global_position = Vector3(camp.pos.x, 0.3, camp.pos.y) + Vector3(-20.0 + 20.0 * k, 0, 18.0)
		f._invulnerable_until = Time.get_ticks_msec() + 600000
		bodies[i] = f
		k += 1
	var lead := bodies[lead_i] as FieldPlayer
	var priest := bodies[priest_i] as FieldPlayer
	var lord := bodies[lord_i] as FieldPlayer
	hero.global_position = Vector3(camp.pos.x, 0.3, camp.pos.y) + Vector3(0, 0, -6.0)
	await get_tree().create_timer(0.5).timeout
	check(priest.party_leader() == lead and lord.party_leader() == lead and lead.party_leader() == null, "the others follow the leader; the leader leads")
	check(priest.camp() == lead.camp() and lord.camp() == lead.camp(), "the party hunts the leader's camp")
	# Summon: the Dark Lord pulls a straggler back to itself, never the hero.
	var spec := ClassData.find_skill(&"darklord", "summon")
	priest.global_position = lord.global_position + Vector3(30.0, 0, 0)
	priest._mates_in = 0.0
	lord._mates_in = 0.0
	await get_tree().physics_frame
	var hero_at := hero.global_position
	check(lord._shape_score(spec, 2.0, 1.0) > 9.0, "a Dark Lord of the party wants to Summon a mate far behind")
	lord._apply_self(spec)
	check(priest.global_position.distance_to(lord.global_position) < 4.0, "Summon brings the straggler back (%.1f m)" % priest.global_position.distance_to(lord.global_position))
	check(hero.global_position.distance_to(hero_at) < 0.5, "the hero is not pulled by another party's Summon")
	# A world player alone never summons (the hero's party is not its business).
	var lone := FieldPlayer.new()
	var lone_m := WorldPlayers.member(lord_i, t)
	lone_m["class"] = "darklord"
	lone_m["level"] = level
	lone.setup_world(lord_i, lone_m, hero, zone)
	zone.add_child(lone)
	lone.global_position = hero.global_position + Vector3(40, 0.3, 0)
	await get_tree().physics_frame
	check(lone._shape_score(spec, 2.0, 1.0) == 0.0, "a Dark Lord hunting alone never casts Summon")
	lone.queue_free()
	# Hunting together: after a while the others stand near the leader and fight its camp.
	var near_ok := true
	var same_fight := false
	var spread := 0.0
	for step in 24:
		await get_tree().create_timer(0.5).timeout
		if step < 10:
			continue
		for f in [priest, lord]:
			var d: float = (f as FieldPlayer).global_position.distance_to(lead.global_position)
			spread = maxf(spread, d)
			var tgt: Mob = (f as FieldPlayer).target
			if tgt != null and is_instance_valid(tgt) and tgt == lead.target:
				same_fight = true
	near_ok = spread < 14.0
	check(near_ok, "the others keep near the leader (at most %.1f m)" % spread)
	check(same_fight or lead.target == null, "they fight what the leader fights")
	# A healer heals a hurt mate.
	lead._potion_cd = 999.0
	lead.hp = int(float(lead.max_hp) * 0.3)
	lead._since_hurt = 0.0
	priest.global_position = lead.global_position + Vector3(2, 0, 0)
	priest._mates_in = 0.0
	priest.cooldowns.clear()
	priest._cast_until = 0
	priest.mp = 99999.0
	var mob: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_dead():
			mob = node
			break
	priest.target = mob
	var before := float(lead.hp) / float(lead.max_hp)
	check(priest._ally_hp_ratio() <= 0.31, "the healer sees its hurt mate (%.2f)" % priest._ally_hp_ratio())
	var cast := priest._try_skills(2.0)
	await get_tree().create_timer(1.6).timeout
	var after := float(lead.hp) / float(lead.max_hp)
	check(cast and after > before + 0.2, "the priest heals its hurt mate (%.0f%% -> %.0f%%)" % [before * 100.0, after * 100.0])
	# A puppet of another game's party member says whose party too (no AI of its own).
	var pup := FieldPlayer.new()
	pup.puppet = true
	pup.setup_world(priest_i, WorldPlayers.member(priest_i, t), hero, zone)
	pup.set_ai_party(fake)
	zone.add_child(pup)
	await get_tree().process_frame
	check(String(pup._label.text).contains("ปาร์ตี้ของ") and not pup.in_ai_party(), "a mirrored member shows its party on the name plate")
	pup.queue_free()
	# The card says whose party it is.
	for i in bodies:
		zone.presence._drop_shown(i)
	await get_tree().process_frame


func _invite(t: float) -> void:
	if main == null:
		return
	WorldPresence.clock_offset = t - WorldPlayers.now()
	if not Game.has_profile:
		Game.new_profile(&"warrior", "AI Party QA", FaceKit.default_look())
		Game.profile.party = []
	var zone: Zone = main.zone
	var yes := -1
	var no := -1
	var party := {}
	for p in WorldParties.parties_at(t):
		for m in p.members:
			if WorldParties.refuses(int(m), t):
				if no < 0:
					no = int(m)
			elif yes < 0 and (p.members as Array).size() >= 3:
				yes = int(m)
				party = p
	check(yes >= 0, "someone in a party of three or more to ask")
	if yes >= 0:
		var s := WorldPlayers.state(yes, t)
		Game.profile.level = clampi(int(s.level), 1, 100)
		check(Game.has_profile and Game.guild() == 0, "the hero is in no guild (no guild mate's yes)")
		var answer := Game.party_invite(yes)
		check(answer == "" and Game.in_party(yes), "%s leaves its party to join the hero (%s)" % [s.name, answer])
		check(WorldParties.party_of(yes, t).is_empty() and String(WorldPlayers.state(yes, t).party_id) == "", "it is no longer in its world party")
		var rest := true
		for m in party.members:
			if int(m) != yes:
				var q := WorldParties.party_of(int(m), t)
				rest = rest and not q.is_empty() and not (q.members as Array).has(yes)
		check(rest, "the rest of its party hunts on without it")
		Game.party_kick(yes)
		check(not WorldParties.party_of(yes, t).is_empty(), "let go, it is back with its party")
	if no >= 0:
		var s := WorldPlayers.state(no, t)
		Game.profile.level = clampi(int(s.level), 1, 100)
		var why := Game.party_invite(no)
		check(why.contains("ขอโทษ") and not Game.in_party(no), "now and then one says no politely (%s)" % why)
		check(Game.party_invite(no, true) == "" and Game.in_party(no), "asked with force it comes anyway")
		Game.dismiss_party()
	# The card names the party.
	if yes >= 0:
		var f := FieldPlayer.new()
		f.setup_world(yes, WorldPlayers.member(yes, t), zone.hero, zone)
		f.set_ai_party(WorldPlayers.state(yes, t))
		zone.add_child(f)
		f.global_position = zone.hero.global_position + Vector3(2, 0.3, 0)
		await get_tree().process_frame
		main.player_card.open_card(f, zone.hero)
		var line := main.player_card.find_child("AiParty", true, false) as Label
		check(line != null and line.text.contains("ปาร์ตี้ของ"), "the player card says whose party it is (%s)" % (line.text if line != null else "none"))
		main.player_card.close_card()
		f.queue_free()
