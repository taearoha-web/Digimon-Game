extends Node
## Party roles (ClassRoles): every class has one trait that helps its whole party, each
## different; a trait counts once per party (two of a class do not double it) and only
## while a member of that class lives; it reaches the hero, the AI party members and, in
## the guild war, exactly the fighter's own party (the same reach as buffs). Real hits,
## blows, regeneration and cooldowns use it; the HUD party card and the character screen
## show it in Thai.
##   godot --headless --path . res://tests/integration/class_roles_test.tscn
var failures := 0
var checks := 0
var main: Node


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	_data()
	await _guild_war()
	await _field()
	print("CLASS ROLES: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


## One distinct, modest trait per class, written in Thai.
func _data() -> void:
	var names := {}
	for cls in ClassData.IDS:
		var t := ClassRoles.trait_of(cls)
		check(not t.is_empty(), "%s has a party role" % cls)
		if t.is_empty():
			continue
		check(String(t.name) != "" and String(t.text).begins_with("ทั้งปาร์ตี้") or cls == &"mage", "%s's role is a short Thai line for the party (%s)" % [cls, t.get("text", "")])
		check(not names.has(t.name), "%s's role name is its own (%s)" % [cls, t.name])
		names[t.name] = true
		var v := float(t.value)
		check(v > 0.0 and v <= 0.12, "%s's number is modest (%s)" % [cls, v])
		check(ClassRoles.line(cls).contains(String(t.name)) and ClassRoles.tooltip(cls).contains(String(ClassData.get_class_data(cls).name)), "%s's role line and tooltip" % cls)
	check(names.size() == ClassData.IDS.size(), "ten classes, ten different roles")
	check(ClassRoles.trait_of(ClassData.START).is_empty(), "the Vagabond has no role yet")
	check(ClassRoles.summary([&"warrior", &"warrior", &"mage"]).contains("ขาดอีก 8"), "a summary counts each class once (%s)" % ClassRoles.summary([&"warrior", &"warrior", &"mage"]))


# ---------------------------------------------------------------------------
# The guild war: a trait keeps to the fighter's own party
# ---------------------------------------------------------------------------

func _classes_of(m: GuildWarMatch, party: int, hero: Hero) -> Array:
	var out := {}
	for f in m.party_members(party):
		if not f.is_dead():
			out[f.fighter_class()] = true
	if party == GuildWarMatch.HERO_PARTY and hero != null:
		out[Game.class_id()] = true
	var keys := out.keys()
	keys.sort()
	return keys


func _sorted(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func _guild_war() -> void:
	Game.set_process(false)
	Game.new_profile(&"warrior", "Role GW")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	Game.guildwar_party_chosen = false
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and GuildWarMatch.in_war(), "a guild war is on")
	if m == null:
		zone.queue_free()
		return
	ClassRoles.invalidate()
	var hero: Hero = m.hero
	check(_sorted(ClassRoles.party_classes(hero)) == _classes_of(m, GuildWarMatch.HERO_PARTY, hero), "war: the hero's party roles are its own party's classes (%s)" % [_sorted(ClassRoles.party_classes(hero))])
	var ok := true
	var reach_ok := true
	var fighters := m.all_fighters()
	for f in fighters:
		var want := _classes_of(m, f.party, hero)
		if _sorted(ClassRoles.party_classes(f)) != want:
			ok = false
			printerr("  %s (party %d): %s != %s" % [f.rival_name, f.party, _sorted(ClassRoles.party_classes(f)), want])
	for a in fighters.slice(0, 8) + [hero]:
		for b in fighters:
			if GuildWarMatch.buff_reaches(a, b) != (ClassRoles.party_key(a) == ClassRoles.party_key(b)):
				reach_ok = false
	check(ok and fighters.size() >= 10, "war: every fighter gets exactly its own party's roles (%d fighters)" % fighters.size())
	check(reach_ok, "war: a role reaches whom a buff reaches (GuildWarMatch.buff_reaches)")
	# A role of the other guild never helps the hero's party.
	var foreign := &""
	for f in m.enemies:
		if not ClassRoles.has(hero, f.fighter_class()):
			foreign = f.fighter_class()
			break
	check(foreign == &"" or not ClassRoles.has(hero, foreign), "war: the rival guild's %s does not help the hero" % foreign)
	# กำแพงเหล็ก in the war: a fighter with a Defender in its party takes less from a blow.
	var guarded: GuildFighter = null
	var bare: GuildFighter = null
	for f in fighters:
		if ClassRoles.has(f, &"defender"):
			guarded = f if guarded == null else guarded
		else:
			bare = f if bare == null else bare
	if guarded != null:
		check(is_equal_approx(ClassRoles.taken(guarded), 0.9) and ClassRoles.guard(guarded, 1000) == 900, "war: a party with a Defender takes -10%")
	if bare != null:
		check(ClassRoles.guard(bare, 1000) == 1000, "war: a party without one takes it all")
	# The hero is a Warrior: its party hits +8%, a fallen Warrior gives nothing.
	check(is_equal_approx(ClassRoles.outgoing(hero, fighters[0]), 1.0 + 0.08 + (0.12 if ClassRoles.has(hero, &"assassin") and ClassRoles.hp_ratio(fighters[0]) < 0.35 else 0.0)), "war: the Warrior hero's party hits harder")
	zone.queue_free()
	await _frames(3)
	ClassRoles.invalidate()
	check(not GuildWarMatch.in_war(), "the war is over")
	Game.set_process(true)


# ---------------------------------------------------------------------------
# The field: the hero and its AI party
# ---------------------------------------------------------------------------

## World player indices of [param cls] (in the party they are AI members).
func _players_of(cls: StringName, count: int) -> Array[int]:
	var out: Array[int] = []
	var t := WorldPresence.clock()
	for i in WorldPlayers.size():
		if StringName(WorldPlayers.state(i, t)["class"]) == cls:
			out.append(i)
			if out.size() >= count:
				break
	return out


func _party(classes: Array) -> void:
	for i in Game.world_party.duplicate():
		Game.party_kick(i)
	var used := {}
	for cls in classes:
		var picks := _players_of(StringName(cls), int(used.get(cls, 0)) + 1)
		var idx: int = picks[-1] if picks.size() > int(used.get(cls, 0)) else -1
		used[cls] = int(used.get(cls, 0)) + 1
		check(idx >= 0 and Game.party_invite(idx, true) == "", "a %s joins the party" % cls)
	await _wait(0.6)
	ClassRoles.invalidate()


func _member(cls: StringName) -> Companion:
	for c in main.zone.companions:
		if is_instance_valid(c) and String(c.member["class"]) == String(cls):
			return c
	return null


func _field() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _wait(0.3)
	if main.title_screen:
		main.title_screen.queue_free()
		main.title_screen = null
	Game.new_profile(ClassData.START, "Role QA", FaceKit.default_look())
	Game.profile.level = 30
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 40.0 * 86400.0 - WorldPlayers.now()
	main.hud.visible = true
	main._traveling = false
	await main.go(&"meadow", true)
	await _wait(0.5)
	var hero: Hero = main.zone.hero
	hero._invulnerable_until = 0
	hero.stats["dodge"] = 0.0
	hero.stats["crit"] = 0.0
	var mob: Mob = null
	var other: Mob = null
	for node in get_tree().get_nodes_in_group("mobs"):
		if node is Mob and not (node as Mob).is_boss and not (node as Mob).is_dead():
			if mob == null:
				mob = node
			elif other == null:
				other = node
	check(mob != null and other != null, "the meadow has monsters")
	if mob == null or other == null:
		return
	for target in [mob, other]:
		target.set_physics_process(false)
		target.max_hp = 100000000
		target.hp = 100000000

	# Alone, a Vagabond: nothing.
	ClassRoles.invalidate()
	check(ClassRoles.party_classes(hero).is_empty(), "a lone Vagabond has no party role")
	check(is_equal_approx(ClassRoles.outgoing(hero, mob), 1.0) and ClassRoles.guard(hero, 1000) == 1000 and is_equal_approx(ClassRoles.cd_rate(hero), 1.0), "and no effect")
	hero.cooldowns = {"probe": 10.0}
	hero._tick_timers(1.0)
	check(is_equal_approx(float(hero.cooldowns.probe), 9.0), "cooldowns run at normal speed (%s)" % hero.cooldowns.probe)

	# แนวหน้า: two Warriors give +8% once.
	await _party([&"warrior", &"warrior"])
	var warrior := _member(&"warrior")
	check(warrior != null and ClassRoles.has(hero, &"warrior") and ClassRoles.has(warrior, &"warrior"), "a Warrior in the party: the hero and the members have แนวหน้า")
	check(is_equal_approx(ClassRoles.outgoing(hero, mob), 1.08), "two Warriors: +8%%, not +16%% (%s)" % ClassRoles.outgoing(hero, mob))
	seed(11)
	var before := mob.hp
	hero._deal(mob, 1.0, Color.WHITE, &"", false)
	var with_trait := before - mob.hp
	for c in main.zone.companions:
		c._dead = true
	ClassRoles.invalidate()
	check(not ClassRoles.has(hero, &"warrior"), "fallen Warriors give nothing")
	seed(11)
	before = mob.hp
	hero._deal(mob, 1.0, Color.WHITE, &"", false)
	var without := before - mob.hp
	for c in main.zone.companions:
		c._dead = false
	ClassRoles.invalidate()
	check(without > 0 and absi(with_trait - int(round(float(without) * 1.08))) <= 2, "a real hit: %d with แนวหน้า, %d without" % [with_trait, without])
	# The HUD party card tells the member's role.
	await _wait(0.6)
	var card: Control = main.hud._party_cards[0].card
	check(card.tooltip_text.contains("แนวหน้า"), "the party card's tooltip tells the role (%s)" % card.tooltip_text)

	# กำแพงเหล็ก, พรแห่งแสง, ตราเวท, ตาเหยี่ยว.
	await _party([&"defender", &"priest", &"mage", &"archer"])
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp
	hero._buffs.clear()
	var blow := float(max_hp) * 0.4
	var expect := maxi(1, int(round(HeroStats.mitigate(blow, hero.effective_def()))))
	hero.take_damage(blow, null)
	var lost := max_hp - int(Game.profile.hp)
	check(lost == int(ceil(float(expect) * 0.9)), "กำแพงเหล็ก: a blow of %d takes %d (-10%%)" % [expect, lost])
	var defender := _member(&"defender")
	check(defender != null and ClassRoles.guard(defender, 1000) == 900, "and the members take -10% too")
	Game.profile.hp = max_hp / 2
	var hp0 := int(Game.profile.hp)
	ClassRoles.regen(hero, 10.0)
	var healed := int(Game.profile.hp) - hp0
	var want := int(float(max_hp) * 0.005 * 10.0)
	check(healed >= want and healed <= want + 1, "พรแห่งแสง: 10 s give %d HP (0.5%%/s of %d, want %d)" % [healed, max_hp, want])
	var priest := _member(&"priest")
	if priest != null:
		priest.hp = priest.max_hp / 2
		var php := priest.hp
		ClassRoles.regen(priest, 10.0)
		check(priest.hp - php >= int(float(priest.max_hp) * 0.05), "and the members heal too (%d)" % (priest.hp - php))
	var mage := _member(&"mage")
	check(not ClassRoles.marked(mob, "hero"), "no mark before the Mage hits")
	ClassRoles.after_hit(hero, other, 100)
	check(not ClassRoles.marked(other, "hero"), "a Vagabond's hit leaves no mark")
	ClassRoles.after_hit(mage, mob, 100)
	check(ClassRoles.marked(mob, "hero") and is_equal_approx(ClassRoles.outgoing(hero, mob), 1.10), "ตราเวท: the Mage's target takes +10%% from the party (%s)" % ClassRoles.outgoing(hero, mob))
	check(is_equal_approx(ClassRoles.outgoing(defender, mob), 1.10), "for the members' hits too")
	check(is_equal_approx(ClassRoles.outgoing(hero, other), 1.0), "an unmarked monster takes the normal damage")
	var marks: Dictionary = mob.get_meta(ClassRoles.MARK_META)
	marks["hero"] = Time.get_ticks_msec() - 1
	check(is_equal_approx(ClassRoles.outgoing(hero, mob), 1.0), "the mark wears off")
	check(is_equal_approx(ClassRoles.crit_bonus(hero), 0.08) and is_equal_approx(ClassRoles.crit_bonus(priest), 0.08), "ตาเหยี่ยว: crit +8% for everyone")
	check(ClassRoles.pierce(hero) == 0.0 and ClassRoles.party_classes(hero).size() == 4, "only the four roles present")

	# จุดตาย, ทะลวงเกราะ, พันธะวิญญาณ, เงามืด.
	await _party([&"assassin", &"lancer", &"summoner", &"darklord"])
	mob.hp = int(mob.max_hp * 0.3)
	check(is_equal_approx(ClassRoles.outgoing(hero, mob), 1.12), "จุดตาย: +12%% under 35%% HP (%s)" % ClassRoles.outgoing(hero, mob))
	mob.hp = int(mob.max_hp * 0.5)
	check(is_equal_approx(ClassRoles.outgoing(hero, mob), 1.0), "and nothing above it")
	check(is_equal_approx(ClassRoles.pierced(hero, 300.0), 270.0) and is_equal_approx(ClassRoles.pierced(_member(&"summoner"), 300.0), 270.0), "ทะลวงเกราะ: 10% of DEF ignored")
	check(is_equal_approx(ClassRoles.pierced(mob, 300.0), 300.0), "monsters do not pierce")
	Game.profile.mp = 0
	var max_mp := int(hero.stats.max_mp)
	ClassRoles.regen(hero, 10.0)
	var mp_want := int(float(max_mp) * 0.006 * 10.0)
	check(int(Game.profile.mp) >= mp_want and int(Game.profile.mp) <= mp_want + 1, "พันธะวิญญาณ: 10 s give %d MP (want %d)" % [int(Game.profile.mp), mp_want])
	Game.profile.hp = max_hp / 2
	hp0 = int(Game.profile.hp)
	ClassRoles.after_hit(hero, mob, 1000)
	var drunk := int(Game.profile.hp) - hp0
	check(drunk >= 40 and drunk <= 41, "เงามืด: 1000 damage dealt gives back %d HP (4%%)" % drunk)
	var lord := _member(&"darklord")
	if lord != null:
		lord.hp = lord.max_hp / 2
		var lhp := lord.hp
		ClassRoles.after_hit(lord, mob, 1000)
		check(lord.hp - lhp >= 40, "and the members drink too (%d)" % (lord.hp - lhp))

	# ประสานเสียง: two Bards, cooldowns 10% shorter once.
	await _party([&"bard", &"bard"])
	hero.cooldowns = {"probe": 10.0}
	hero._tick_timers(1.0)
	check(absf(float(hero.cooldowns.probe) - (10.0 - 1.0 / 0.9)) < 0.01, "ประสานเสียง: a second takes %.3f off a cooldown (10%% shorter, not 20%%)" % (10.0 - float(hero.cooldowns.probe)))
	var bard := _member(&"bard")
	check(bard != null and is_equal_approx(ClassRoles.cd_rate(bard), 1.0 / 0.9), "the Bards' own cooldowns too")

	# The character screen names the role.
	for i in Game.world_party.duplicate():
		Game.party_kick(i)
	Game.profile["class"] = "mage"
	var menu := GameMenu.new()
	add_child(menu)
	menu.open_menu(&"character")
	await _frames(2)
	var role := menu.find_child("ClassRole", true, false) as Label
	check(role != null and role.text.contains("ตราเวท"), "the character screen shows the class's party role (%s)" % (role.text if role else "none"))
	menu.queue_free()
	Game.profile["class"] = String(ClassData.START)
