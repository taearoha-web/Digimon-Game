extends Node
## The world players: fifty fixed people in two guilds whose progress follows their daily
## schedules (the same at a given time on every device) from Lv.1 to ★200, wearing what
## they found; the online ones hunt for real in the field that fits them, their kills are
## their own; the hero walks up to one, taps it and asks it into the party (three people,
## EXP shared); the registry lists everyone; the hero joins Alpha or Neverdie at the
## registrar and the guild war lines up the two guilds' members. A new character changes
## nothing about them.
##   godot --headless --path . res://tests/integration/world_players_test.tscn
var failures := 0
var checks := 0
var main: Node


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _ready() -> void:
	WorldPlayers.clear_bonus()
	_roster()
	_progress()
	_gear()
	await _field()
	await _party()
	_guild()
	await _screens()
	print("WORLD PLAYERS: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _roster() -> void:
	check(WorldPlayers.size() == 50, "fifty world players")
	var names := {}
	var classes := {}
	for g in [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]:
		var members := WorldPlayers.members(g)
		check(members.size() == 25, "%s has 25 members" % WorldPlayers.guild_name(g))
		var support := false
		for i in members:
			support = support or GuildWarData.is_support(StringName(WorldPlayers.entry(i)["class"]))
		check(support, "%s has a healer or a summoner" % WorldPlayers.guild_name(g))
	for i in WorldPlayers.size():
		var e := WorldPlayers.entry(i)
		names[String(e.name)] = true
		classes[StringName(e["class"])] = true
		check(ClassData.IDS.has(StringName(e["class"])) and WorldPlayers.STYLES.has(String(e.style)), "%s: a real class and play style" % e.name)
		check(int(WorldPlayers.look(i).gender) == int(e.gender), "%s: the face matches the roster's gender" % e.name)
		check(WorldPlayers.look(i) == WorldPlayers.look(i), "%s: always the same face" % e.name)
	check(names.size() == 50, "every name is different")
	check(classes.size() == ClassData.IDS.size(), "every class is played")
	check(WorldPlayers.guild_name(WorldPlayers.ALPHA) == "Alpha" and WorldPlayers.guild_name(WorldPlayers.NEVERDIE) == "Neverdie", "the guilds are Alpha and Neverdie")


func _progress() -> void:
	var start := float(WorldPlayers.START_UNIX)
	var day := 86400.0
	for i in WorldPlayers.size():
		var e := WorldPlayers.entry(i)
		var before := WorldPlayers.state(i, start - 3600.0)
		check(int(before.level) == 1 and int(before.stars) == 0 and not bool(before.online), "%s: Lv.1 and offline before the world opens" % e.name)
		check(WorldPlayers.state(i, start + 3.3 * day) == WorldPlayers.state(i, start + 3.3 * day), "%s: the same state for the same moment" % e.name)
		var last_level := 1
		var last_stars := 0
		var steady := true
		var zones_ok := true
		var t := start
		while t < start + 160.0 * day:
			var s := WorldPlayers.state(i, t)
			if int(s.level) < last_level or int(s.stars) < last_stars:
				steady = false
			last_level = int(s.level)
			last_stars = int(s.stars)
			var place := String(s.place)
			if place != "" and place != "town" and ZoneData.access_reason(StringName(place), int(s.level), int(s.stars)) != "":
				zones_ok = false
			if bool(s.online) != (place != ""):
				zones_ok = false
			t += day * 0.73
		check(steady, "%s: level and stars only ever go up" % e.name)
		check(zones_ok, "%s: always hunts in a field it may enter" % e.name)
		var end := WorldPlayers.state(i, start + 160.0 * day)
		check(int(end.level) == 100 and int(end.stars) == 200 and int(end.grade) == GuildWarData.DIVINE, "%s: reaches Lv.100 ★200 and the divine set in time (%s)" % [e.name, WorldPlayers.level_text(end)])
		var early := WorldPlayers.state(i, start + 0.5 * day)
		check(int(early.level) < 100, "%s: no Lv.100 in the first twelve hours (%d)" % [e.name, int(early.level)])
		var week := WorldPlayers.played_minutes(i, start + 28.0 * day) / 60.0 / 4.0
		check(week > 5.0 and week < 70.0, "%s: plays %.0f hours a week" % [e.name, week])
		if String(e.style) == "hardcore":
			check(int(WorldPlayers.state(i, start + 21.0 * day).stars) == 200, "%s: a hardcore player reaches ★200 within three weeks" % e.name)
	check(int(WorldPlayers.progress_for(0.0, 0.3).level) == 1, "no play, Lv.1")
	var full := WorldPlayers.progress_for(1e9, 0.3)
	check(int(full.level) == 100 and int(full.stars) == 200 and bool(full.divine), "endless play stops at ★200 with the divine set")
	# Evenings are busy: someone is always on at 21:00 Thai time.
	var busy := true
	for d in range(1, 30):
		var at: float = (floor((start + WorldPlayers.TZ) / day) + float(d)) * day - WorldPlayers.TZ + 21.0 * 3600.0
		var on := 0
		for i in WorldPlayers.size():
			on += 1 if bool(WorldPlayers.state(i, at).online) else 0
		busy = busy and on >= 3
	check(busy, "at least three players online every evening")


## What they wear is what they found: piece by piece, not a new set at each level band.
func _gear() -> void:
	var lagging := false
	var staggered := false
	var rare_kept := false
	var ok_order := true
	var variety := {}
	for i in WorldPlayers.size():
		var e := WorldPlayers.entry(i)
		var name := String(e.name)
		var m := {"name": name, "class": e["class"], "level": 1, "stars": 0, "frac": 0.0}
		var first := WorldPlayers.equip(m)
		check(first.size() == 1 and first.has("weapon") and int(first.weapon.level) == 1, "%s sets out with the beginner's weapon only" % name)
		var changed_at := {}
		var last := {}
		for slot in ItemData.SLOTS:
			last[slot] = -1.0
		for step in range(10, 1000, 3):
			var p := float(step) / 10.0
			for slot in ItemData.SLOTS:
				var f := WorldPlayers._best_find(name, slot, p, 0.0)
				if f.is_empty():
					continue
				var score := ItemData.gear_power(int(f.level)) * ItemData.rarity_mult(int(f.rarity), 0.2) * (1.0 + 0.06 * int(f.plus))
				if score < float(last[slot]) - 0.001:
					ok_order = false
				if score > float(last[slot]) + 0.001 and not changed_at.has("%s|%s" % [slot, f.key]):
					changed_at["%s|%s" % [slot, f.key]] = p
				last[slot] = score
				if ItemData.tier_for(int(f.level)) < ItemData.tier_for(int(p)) - 1:
					lagging = true
				if int(f.rarity) >= 3 and ItemData.tier_for(int(f.level)) < ItemData.tier_for(int(p)):
					rare_kept = true
		var weapon_at := float(changed_at.get("weapon|b5", -1.0))
		var armor_at := float(changed_at.get("armor|b5", -1.0))
		if weapon_at > 0.0 and armor_at > 0.0 and absf(weapon_at - armor_at) > 0.5:
			staggered = true
		var mid := WorldPlayers.equip({"name": name, "class": e["class"], "level": 55, "stars": 0, "frac": 0.5})
		if mid.has("armor"):
			variety["%s+%d" % [mid.armor.name, int(mid.armor.get("plus", 0))]] = true
		var top := WorldPlayers.equip({"name": name, "class": e["class"], "level": 100, "stars": 200, "frac": 0.0, "divine_frac": 1.0})
		var divine := true
		for slot in DivineGearData.SLOTS:
			divine = divine and top.has(slot) and DivineGearData.is_item(top[slot])
		check(divine and top.has("wings") and StarGearData.is_star(top.wings), "%s: the divine set and the star wings in the end" % name)
		check(not WorldPlayers.equip({"name": name, "class": e["class"], "level": 99, "stars": 0, "frac": 0.9}).has("wings"), "%s: no wings before Lv.100" % name)
		var again := WorldPlayers.equip({"name": name, "class": e["class"], "level": 73, "stars": 0, "frac": 0.25})
		WorldPlayers._gear.clear()
		WorldPlayers._gear_sig.clear()
		var fresh := WorldPlayers.equip({"name": name, "class": e["class"], "level": 73, "stars": 0, "frac": 0.25})
		var same := again.size() == fresh.size()
		for slot in again:
			same = same and fresh.has(slot) and String(fresh[slot].name) == String(again[slot].name) and int(fresh[slot].get("plus", 0)) == int(again[slot].get("plus", 0))
		check(same, "%s: the same finds on every device" % name)
	check(ok_order, "a slot's piece only ever gets better")
	check(lagging, "a slot can stay a band or more behind the level (nothing dropped)")
	check(staggered, "slots change at different levels, one find at a time")
	check(rare_kept, "a rare older piece stays on over plainer newer ones")
	check(variety.size() >= 12, "players of a level wear different finds (%d kinds of armour)" % variety.size())
	# A member sheet follows its state, and a new find shows as a changed signature.
	var m := WorldPlayers.member(0, float(WorldPlayers.START_UNIX) + 2.0 * 86400.0)
	var before := WorldPlayers.gear_signature(m)
	var later := WorldPlayers.state(0, float(WorldPlayers.START_UNIX) + 30.0 * 86400.0)
	check(WorldPlayers.sync_member(m, later) and WorldPlayers.gear_signature(m) != before, "playing on brings new pieces to wear")


## A moment (offset from now) when world player `want` is hunting in a field, and that field.
func _hunting_moment(from: float) -> Array:
	var t := from
	while t < from + 40.0 * 86400.0:
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			var place := String(s.place)
			if bool(s.online) and place != "town" and place != "" and int(s.level) >= 3 and int(s.level) < 60:
				var after := WorldPlayers.state(i, t + 300.0)
				if String(after.place) == place:
					return [t, i, StringName(place)]
		t += 600.0
	return []


func _field() -> void:
	WorldPresence.enabled = true
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "World QA", FaceKit.default_look())
	Game.profile.level = 60
	Game.profile.adv = 3
	Game.profile.party = []
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	var moment := _hunting_moment(float(WorldPlayers.START_UNIX) + 3600.0)
	check(not moment.is_empty(), "someone hunts in a field at some point")
	if moment.is_empty():
		return
	WorldPresence.clock_offset = float(moment[0]) - WorldPlayers.now()
	await main.go(moment[2], true)
	await get_tree().create_timer(1.0).timeout
	var zone: Zone = main.zone
	check(zone.presence != null, "a hunting field shows the world players")
	var bots := get_tree().get_nodes_in_group("world_players")
	check(bots.size() >= 1 and bots.size() <= WorldPresence.LIMITS[2], "online players stand in the field (%d)" % bots.size())
	var shown_index := -1
	for node in bots:
		var bot := node as FieldPlayer
		check(bot != null and not bot.is_in_group("companions"), "a world player is not the hero's companion")
		var s := WorldPlayers.state(bot.world_index, WorldPresence.clock())
		check(String(s.place) == String(zone.zone_id) and int(bot.member.level) == int(s.level), "%s is here at its scheduled level" % bot.member.name)
		check(String(bot._label.text).begins_with("[%s] %s" % [WorldPlayers.guild_name(int(s.guild)), s.name]), "the name tag shows the guild and name")
		if int(bot.world_index) == int(moment[1]):
			shown_index = bot.world_index
	check(shown_index >= 0 or bots.size() == WorldPresence.LIMITS[clampi(GameSettings.quality, 0, 2)], "the scheduled player is shown (or the field is full)")
	# Keep the hero out of the fight: whatever dies is the world players' kill.
	var hero: Hero = zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	hero.global_position = zone.entrance() + Vector3(0, 0.2, 0)
	var exp_before := int(Game.profile.exp)
	var level_before := int(Game.profile.level)
	var potions_before := Game.total_potions("hp")
	var died := [0]
	for node in get_tree().get_nodes_in_group("mobs"):
		(node as Mob).died.connect(func(m: Mob):
			if m.party_share() <= 0.0:
				died[0] += 1)
	var dealt := 0
	for i in 40:
		await get_tree().create_timer(0.5).timeout
		for node in get_tree().get_nodes_in_group("mobs"):
			dealt += (node as Mob).others_damage
	check(dealt > 0 or died[0] > 0, "world players fight the field's monsters")
	check(int(Game.profile.exp) == exp_before and int(Game.profile.level) == level_before, "their kills give the hero no EXP")
	check(Game.total_potions("hp") == potions_before, "they drink their own potions, never the hero's")
	# Damage shares: a monster the hero mostly hurt is the hero's kill.
	var mob := Mob.new()
	mob.setup(&"forest_orc", 10, Vector3(200, 0, 200), hero)
	zone.add_child(mob)
	var bot0: Node = bots[0]
	mob.take_hit(30, false, Color.WHITE, bot0)
	mob.take_hit(70, false, Color.WHITE, hero)
	check(is_equal_approx(mob.party_share(), 0.7), "damage shares split the kill (%.2f)" % mob.party_share())
	mob.queue_free()
	# Hours later the session is over: the players log off.
	WorldPresence.clock_offset += 6.0 * 3600.0
	zone.presence.sync(false)
	await get_tree().process_frame
	var still := 0
	for i in zone.presence.shown:
		var s := WorldPlayers.state(int(i), WorldPresence.clock())
		still += 0 if bool(s.online) and String(s.place) == String(zone.zone_id) else 1
	check(still == 0, "only players still here remain after the clock moves")
	WorldPresence.clock_offset = 0.0


## A moment after `from` when some world player is online in a field with a level the
## hero can take, and that player.
func _online_moment(from: float) -> Array:
	var t := from
	while t < from + 20.0 * 86400.0:
		for i in WorldPlayers.size():
			var s := WorldPlayers.state(i, t)
			if bool(s.online) and String(s.place) not in ["", "town"] and int(s.level) >= 5 and int(s.level) < 90:
				var later := WorldPlayers.state(i, t + 600.0)
				if bool(later.online):
					return [t, i]
		t += 900.0
	return []


func _party() -> void:
	var moment := _online_moment(float(WorldPlayers.START_UNIX) + 2.0 * 86400.0)
	check(not moment.is_empty(), "someone is online to party with")
	if moment.is_empty():
		return
	WorldPresence.clock_offset = float(moment[0]) - WorldPlayers.now()
	var who: int = moment[1]
	var s := WorldPlayers.state(who, WorldPresence.clock())
	Game.new_profile(&"warrior", "Party QA", FaceKit.default_look())
	Game.profile.level = clampi(int(s.level), 10, 99)
	Game.profile.adv = JobData.adv_for_level(int(Game.profile.level))
	Game.profile.party = []
	await main.go(StringName(s.place), true)
	await get_tree().create_timer(0.8).timeout
	var zone: Zone = main.zone
	var hero: Hero = zone.hero
	hero._invulnerable_until = Time.get_ticks_msec() + 600000
	check(Game.party().is_empty() and zone.companions.is_empty(), "a hero starts with no party (the hired companion is gone)")
	check(Game.PARTY_SIZE == 3 and Game.PARTY_MAX == 2, "a party is three people: the hero and two")
	# Walk up to someone hunting here and tap them: their card asks them in.
	var bot: FieldPlayer = null
	for i in zone.presence.shown:
		if is_instance_valid(zone.presence.shown[i]) and (bot == null or int(i) == who):
			bot = zone.presence.shown[i]
	check(bot != null, "someone hunts here to walk up to")
	if bot != null:
		Game.profile.level = clampi(int(bot.member.level), 1, 99)
		hero.global_position = bot.global_position + Vector3(30, 0.2, 0)
		await get_tree().create_timer(0.3).timeout
		var camera := get_viewport().get_camera_3d()
		var far_at := camera.unproject_position(bot.global_position + Vector3(0, 1.2, 0))
		check(not PlayerCard.in_reach(bot, hero), "from far away the player is out of reach")
		main._on_world_tapped(far_at)
		check(not main.player_card.is_open, "a far tap asks the hero to walk closer first")
		hero.global_position = bot.global_position + Vector3(2.5, 0.2, 0)
		await get_tree().create_timer(0.4).timeout
		var at := camera.unproject_position(bot.global_position + Vector3(0, 1.2, 0))
		check(zone.player_at(at) == bot, "a tap on a player on screen finds that player")
		check(zone.player_at(at + Vector2(400, 300)) != bot, "a tap beside nobody finds no one")
		main._on_world_tapped(at)
		check(main.player_card.is_open and main.player_card.player == bot, "tapping a player nearby opens its card")
		var invite := main.player_card.find_child("Invite", true, false) as Button
		check(invite != null and not invite.disabled, "the card offers to ask it into the party")
		if invite != null:
			invite.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		check(Game.in_party(bot.world_index) and is_instance_valid(bot) and bot.party_mode, "%s says yes and joins" % bot.member.name)
		check(zone.companions.size() == 1 and zone.companions[0] == bot, "it joins where it stands (the same player, not a copy)")
		check(bot.is_in_group("companions") and not bot.is_in_group("world_players") and not zone.presence.shown.has(bot.world_index), "now its kills count for the party")
		check(main.player_card.find_child("Leave", true, false) != null and main.player_card.find_child("Stance", true, false) != null, "a member's card has stance and leave")
		(main.player_card.find_child("Stance", true, false) as Button).pressed.emit()
		check(String(Game.party()[0].stance) == "aggressive", "the card changes the member's stance")
		(main.player_card.find_child("Leave", true, false) as Button).pressed.emit()
		await get_tree().create_timer(0.3).timeout
		check(not Game.in_party(bot.world_index) and is_instance_valid(bot) and not bot.party_mode and bot.is_in_group("world_players"), "let go, it goes back to hunting on its own")
		check(zone.presence.shown.get(bot.world_index) == bot and zone.companions.is_empty(), "it hunts here again")
		main.player_card.close_card()
	Game.profile.level = clampi(int(s.level), 10, 99)
	check(Game.party_invite(who) == "" and Game.in_party(who), "an online player of a near level joins (%s Lv.%d)" % [s.name, int(s.level)])
	await get_tree().create_timer(0.5).timeout
	check(zone.companions.size() == 1 and zone.companions[0] is FieldPlayer and (zone.companions[0] as FieldPlayer).party_mode, "the member walks with the hero as a companion")
	check(zone.companions[0].is_in_group("companions") and not zone.companions[0].is_in_group("world_players"), "its kills count for the party")
	check(not zone.presence.shown.has(who), "it is not also hunting on its own in the field")
	check(int(Game.party()[0].level) == int(s.level), "it keeps its own level")
	# Who can be asked: offline players cannot; strangers far apart in level say no; guild mates say yes.
	var offline := -1
	var far := -1
	for i in WorldPlayers.size():
		var o := WorldPlayers.state(i, WorldPresence.clock())
		if not bool(o.online) and offline < 0:
			offline = i
		if bool(o.online) and i != who and absi(int(o.level) - int(Game.profile.level)) > Game.PARTY_LEVEL_GAP and far < 0:
			far = i
	check(offline >= 0 and Game.party_invite(offline).contains("ออฟไลน์"), "an offline player cannot join")
	if far >= 0:
		check(Game.party_invite(far).contains("เลเวลห่าง"), "a stranger far apart in level says no")
		Game.profile.level = 100
		Game.join_guild(int(WorldPlayers.entry(far).guild))
		check(Game.party_invite(far) == "", "a guild mate always says yes")
	# Three people at most: the hero and two.
	for i in WorldPlayers.size():
		if Game.party().size() >= Game.PARTY_MAX:
			break
		Game.party_invite(i, true)
	var extra := 0
	while Game.in_party(extra):
		extra += 1
	check(Game.party().size() == Game.PARTY_MAX and Game.party_invite(extra, true).contains("3 คน"), "a party holds three with the hero")
	await get_tree().create_timer(0.4).timeout
	check(zone.companions.size() == Game.PARTY_MAX, "both members walk with the hero")
	# A kill's EXP is shared: everyone gets an even part of a pot that grows with the party.
	Game.profile.level = 50
	Game.profile.exp = 0
	var ids := Game.world_party.duplicate()
	var work_before := []
	for i in ids:
		work_before.append(WorldPlayers.bonus_work(i))
	var orc := Mob.new()
	orc.setup(&"forest_orc", 50, hero.global_position + Vector3(60, 0, 60), hero)
	zone.add_child(orc)
	await get_tree().process_frame
	var base := float(orc.stats.exp) * (1.0 + maxf(0.0, float(zone.data.get("gear_star", 0)) / 25.0))
	orc.take_hit(orc.hp + 100, false, Color.WHITE, hero)
	await get_tree().process_frame
	var want := int(round(base * (1.0 + Game.PARTY_EXP_BONUS * 2.0) / 3.0))
	check(absi(int(Game.profile.exp) - want) <= 1 and int(Game.profile.exp) < int(base), "the hero gets its part of the shared EXP (%d of %d)" % [int(Game.profile.exp), int(base)])
	var shared := true
	for k in ids.size():
		shared = shared and WorldPlayers.bonus_work(ids[k]) > float(work_before[k])
	check(shared, "the members get their parts too")
	var lift := WorldPlayers.progress_for(WorldPlayers.played_minutes(ids[0], WorldPresence.clock()), WorldPlayers.efficiency(ids[0]))
	var with := WorldPlayers.state(ids[0], WorldPresence.clock())
	check(int(with.level) * 1000 + float(with.frac) * 999.0 > int(lift.level) * 1000 + float(lift.frac) * 999.0, "a member's party EXP moves it on")
	# Their sessions end: they leave the party.
	WorldPresence.clock_offset += 12.0 * 3600.0
	zone.presence.sync(false)
	await get_tree().process_frame
	var left := true
	for i in Game.world_party:
		left = left and bool(WorldPlayers.state(i, WorldPresence.clock()).online)
	check(left, "members whose session ended left the party")
	# A new character: the world goes on unchanged (party EXP included), the party is gone.
	var t := WorldPresence.clock()
	var before := []
	for i in WorldPlayers.size():
		before.append(WorldPlayers.state(i, t))
	Game.new_profile(&"mage", "Brand new", FaceKit.default_look())
	var after := []
	for i in WorldPlayers.size():
		after.append(WorldPlayers.state(i, t))
	check(before == after, "a new character does not restart the world players")
	check(Game.party().is_empty(), "a new character starts without a party")
	await _wings(zone)
	WorldPresence.clock_offset = 0.0
	await main.go(&"town", true)


## A player with wings flies, stands or folds them as it pleases, and flying lifts it.
func _wings(zone: Zone) -> void:
	var i := WorldPlayers.first_of(&"mage")
	var m := WorldPlayers.member(i)
	m["level"] = 100
	m["stars"] = 150
	var p := FieldPlayer.new()
	p.setup_world(i, m, zone.hero, zone)
	zone.add_child(p)
	p.global_position = zone.hero.global_position + Vector3(4, 0.3, 4)
	await get_tree().process_frame
	check(p.visual.has_wings(), "a player past its wing drop wears wings")
	var modes := {}
	for k in 40:
		p._wing_think = 0.0
		p._think_wings(0.016)
		modes[p.visual.wing_mode] = true
	check(modes.size() >= 2, "it picks its own wing pose (%d kinds seen)" % modes.size())
	p.visual.set_wing_mode(HeroVisual.WING_FLY)
	p._wing_think = 999.0
	for k in 40:
		await get_tree().physics_frame
	check(p.visual.position.y > 0.4, "flying lifts it off the ground (%.2f)" % p.visual.position.y)
	p.visual.set_wing_mode(HeroVisual.WING_FOLD)
	for k in 60:
		await get_tree().physics_frame
	check(p.visual.position.y < 0.2, "folded wings bring it back down")
	p.queue_free()


func _guild() -> void:
	Game.new_profile(&"warrior", "Guild QA", FaceKit.default_look())
	Game.profile.level = Game.GUILD_LEVEL - 1
	check(not Game.join_guild(WorldPlayers.ALPHA) and Game.guild() == 0, "no guild before Lv.%d" % Game.GUILD_LEVEL)
	Game.profile.level = 100
	Game.profile.adv = 4
	check(Game.guild() == 0, "a new hero has no guild")
	check(Game.join_guild(WorldPlayers.NEVERDIE) and Game.guild() == WorldPlayers.NEVERDIE, "joins Neverdie")
	check(not Game.join_guild(WorldPlayers.NEVERDIE), "already in it")
	check(Game.join_guild(WorldPlayers.ALPHA) and Game.guild() == WorldPlayers.ALPHA, "moves to Alpha")
	check(not Game.join_guild(7) and Game.guild() == WorldPlayers.ALPHA, "no third guild")
	check(Game._valid_profile(Game.profile.duplicate(true)), "a save with a guild is valid")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var t := float(WorldPlayers.START_UNIX) + 20.0 * 86400.0 + 13.0 * 3600.0
	var m := GuildWarData.roll_guild_match(rng, WorldPlayers.ALPHA, t)
	check(m.ally.size() == GuildWarData.TEAM_SIZE - 1 and m.enemy.size() == GuildWarData.TEAM_SIZE, "seven allies and eight rivals")
	check(m.ally_name == "Alpha" and m.enemy_name == "Neverdie", "Alpha against Neverdie")
	var ok_sides := true
	var online_first := true
	var seen_offline := false
	for f in m.ally:
		ok_sides = ok_sides and int(WorldPlayers.entry(int(f.world)).guild) == WorldPlayers.ALPHA
		online_first = online_first and (bool(f.online) or true) and not (bool(f.online) and seen_offline)
		seen_offline = seen_offline or not bool(f.online)
		check(String(f.member.name) == String(WorldPlayers.entry(int(f.world)).name) and int(f.grade) == int(WorldPlayers.state(int(f.world), t).grade), "%s fights under its own name in its own gear" % f.member.name)
	for f in m.enemy:
		ok_sides = ok_sides and int(WorldPlayers.entry(int(f.world)).guild) == WorldPlayers.NEVERDIE
	check(ok_sides, "each side is its guild's members")
	check(online_first, "online members are picked first")
	var again := RandomNumberGenerator.new()
	again.seed = 77
	var m2 := GuildWarData.roll_guild_match(again, WorldPlayers.ALPHA, t)
	check(m2.enemy.map(func(f): return f.member.name) == m.enemy.map(func(f): return f.member.name), "the same seed and moment give the same war")


func _screens() -> void:
	Game.new_profile(&"warrior", "Registrar QA", FaceKit.default_look())
	Game.profile.level = 60
	main.guild_screen.open_screen()
	await get_tree().process_frame
	var locked := main.guild_screen.find_child("JoinAlpha", true, false) as Button
	check(locked != null and locked.disabled and locked.text.contains("100"), "below Lv.100 the registrar only shows the rosters")
	main.guild_screen.close_screen()
	Game.profile.level = 100
	Game.profile.adv = 4
	main.guildwar_screen.open_lobby()
	await get_tree().process_frame
	var go_button: Button = null
	for b in main.guildwar_screen.find_children("*", "Button", true, false):
		if String((b as Button).text).contains("กิลด์ที่นายทะเบียน"):
			go_button = b
	check(go_button != null and go_button.disabled, "no war before joining a guild")
	main.guildwar_screen.close_screen()
	main.guild_screen.open_screen()
	await get_tree().process_frame
	var join := main.guild_screen.find_child("JoinNeverdie", true, false) as Button
	check(join != null and not join.disabled, "the registrar offers Neverdie")
	join.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game.guild() == WorldPlayers.NEVERDIE, "the button joins Neverdie")
	var mine := main.guild_screen.find_child("JoinNeverdie", true, false) as Button
	check(mine != null and mine.disabled and mine.text == "กิลด์ของคุณ", "the screen shows the hero's guild")
	var cards: int = main.guild_screen.find_children("*", "PanelContainer", true, false).size()
	check(cards >= 21, "both rosters and the hero are listed (%d cards)" % cards)
	main.guild_screen.close_screen()
	# The game registry: everyone, the hero among them, online filter and party buttons.
	main.registry.open_screen()
	await get_tree().process_frame
	var rows: int = main.registry.find_children("Row_*", "PanelContainer", true, false).size()
	check(rows == WorldPlayers.size() + 1 and main.registry.find_child("Row_you", true, false) != null, "the registry lists all %d players and the hero (%d rows)" % [WorldPlayers.size() + 1, rows])
	(main.registry.find_child("Filter_online", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var online_rows: int = main.registry.find_children("Row_*", "PanelContainer", true, false).size()
	check(online_rows == WorldPresence.online_count() + 1, "the online filter shows who is on (%d)" % online_rows)
	main.registry.close_screen()
	main.hud.update_online()
	check(String(main.hud._online_label.text) == "ออนไลน์ %d" % (WorldPresence.online_count() + 1), "the HUD shows how many are online")
	main.guildwar_screen.open_lobby()
	await get_tree().process_frame
	var ready := false
	for b in main.guildwar_screen.find_children("*", "Button", true, false):
		if String((b as Button).text) == "เข้าสู่สงคราม!" and not (b as Button).disabled:
			ready = true
	check(ready, "in a guild the war can start")
	main.guildwar_screen.close_screen()
	# The war itself: Neverdie's members on our side, Alpha's across.
	await main.go(&"guildwar", true)
	await get_tree().create_timer(0.5).timeout
	var war: GuildWarMatch = main.zone.gw_match
	check(war != null and war.ally_name == "Neverdie" and war.enemy_name == "Alpha", "the war is Neverdie against Alpha")
	if war != null:
		var ours := true
		for f in war.allies:
			ours = ours and int(WorldPlayers.entry(_index_of(String(f.member.name))).guild) == WorldPlayers.NEVERDIE
		var theirs := true
		for f in war.enemies:
			theirs = theirs and int(WorldPlayers.entry(_index_of(String(f.member.name))).guild) == WorldPlayers.ALPHA
		check(war.allies.size() == GuildWarData.TEAM_SIZE - 1 and ours, "our side is seven Neverdie members")
		check(war.enemies.size() == GuildWarData.TEAM_SIZE and theirs, "across stand eight Alpha members")
		check(war.started_at > 0, "the war remembers when it began")
	await main.go(&"town", true)


func _index_of(who: String) -> int:
	for i in WorldPlayers.size():
		if String(WorldPlayers.entry(i).name) == who:
			return i
	return 0
