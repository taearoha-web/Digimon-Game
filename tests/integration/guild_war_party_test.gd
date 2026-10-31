extends Node
## Parties in the guild war (headless): parties of at most five, everybody on both sides in
## exactly one, the sizes even, the player's picks from the party screen honoured (and
## "สุ่มให้" filling the rest), the rest dealt at random; buffs only inside the caster's
## party (hero -> ally, ally -> hero, ally -> ally, the rival guild, the allied Bard's song
## on the hero), heals as before; the hero's party on the name tags; the AI's buff wish;
## the parties kept across a resume; nothing changes outside the war.
## godot --headless --path . res://tests/integration/guild_war_party_test.tscn
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
	Game.set_process(false)
	GameSettings.load_settings()
	Game.new_profile(&"warrior", "GW")
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile["paragon"] = {"level": 200, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(200)}
	Game.profile.hp = Game.stats_now().max_hp
	_deal()
	await _hired_war()
	await _guild_war()
	await _lobby_button()
	check(not GuildWarMatch.in_war() and GuildWarMatch.buff_reaches(null, self), "outside the war a buff reaches everyone as before")
	print("GUILD WAR PARTY: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


## The way into the war sits at the top of the desk, on screen and pressable, and the
## party screen's confirm button too (they used to fall below a phone's screen).
func _lobby_button() -> void:
	Game.join_guild(WorldPlayers.ALPHA)
	var desk := GuildWarScreen.new()
	add_child(desk)
	desk.open_lobby()
	await _frames(3)
	var go := desk.find_child("EnterWar", true, false) as Button
	var view := get_viewport().get_visible_rect()
	check(go != null and not go.disabled and go.visible, "the desk has an enabled 'เข้าสู่สงคราม!' button")
	check(go != null and go.get_global_rect().end.y < view.size.y * 0.35, "the button sits near the top of the screen (%s)" % (go.get_global_rect() if go else Rect2()))
	go.pressed.emit()
	await _frames(3)
	var confirm := desk.find_child("ConfirmParty", true, false) as Button
	check(confirm != null and confirm.get_global_rect().end.y < view.size.y * 0.45, "the party screen's confirm button is near the top too")
	desk.close_screen()
	desk.queue_free()
	await _frames(1)


## Checks a side's parties: each at most five, sizes at most one apart (`skip_first`
## leaves out the hero's chosen party), every index 0..count-1 exactly once.
func _check_split(parties: Array, count: int, label: String, skip_first := false, hero := false) -> void:
	var seen := {}
	var sizes: Array[int] = []
	for p in parties.size():
		var party: Array = parties[p]
		check(party.size() >= 1 and party.size() <= GuildWarMatch.PARTY_SIZE, "%s: party %d has 1..5 members (%d)" % [label, p, party.size()])
		if not (skip_first and p == 0):
			sizes.append(party.size())
		for i in party:
			check(not seen.has(i), "%s: %d is in one party only" % [label, i])
			seen[i] = true
	check(seen.size() == count + (1 if hero else 0), "%s: everyone has a party (%d of %d)" % [label, seen.size(), count + (1 if hero else 0)])
	if not sizes.is_empty():
		check(sizes.max() - sizes.min() <= 1, "%s: the dealt parties are even in size %s" % [label, sizes])
		check(sizes.size() == ceili(float(sizes.reduce(func(a, b): return a + b, 0)) / 5.0), "%s: as few parties as five-a-party allows %s" % [label, sizes])


## The dealing on its own: random, even, at most five, the picks first.
func _deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for n in [1, 4, 5, 6, 8, 13, 23, 25, 26]:
		var items: Array = []
		for i in n:
			items.append(i)
		_check_split(GuildWarMatch.split_parties(items, rng), n, "split %d" % n)
	var plan := GuildWarMatch.roll_parties(7, 8, [], false, rng)
	check((plan[0][0] as Array)[0] == -1, "no choice: the hero is dealt and its party listed first")
	_check_split(plan[0], 7, "no choice, ours", false, true)
	_check_split(plan[1], 8, "no choice, theirs")
	check((plan[0] as Array).map(func(p): return p.size()) == [4, 4] and (plan[1] as Array).map(func(p): return p.size()) == [4, 4], "hero + 7 against 8: two parties of four a side")
	plan = GuildWarMatch.roll_parties(24, 25, [3, 9, 9, 30, -2, 11, 17, 20], true, rng)
	check(plan[0][0] == [-1, 3, 9, 11, 17], "the hero's party is the hero and its first four valid picks (%s)" % [plan[0][0]])
	_check_split(plan[0], 24, "chosen, ours", true, true)
	_check_split(plan[1], 25, "chosen, theirs")
	plan = GuildWarMatch.roll_parties(10, 6, [4], true, rng)
	check(plan[0][0] == [-1, 4], "fewer than four picks: the hero's party stays as chosen")
	_check_split(plan[0], 10, "one pick, ours", true, true)
	plan = GuildWarMatch.roll_parties(10, 6, [], true, rng)
	check(plan[0][0] == [-1], "no picks: the hero is a party of one")
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	check(GuildWarMatch.roll_parties(20, 20, [1, 2], true, a) == GuildWarMatch.roll_parties(20, 20, [1, 2], true, b), "the same seed deals the same parties")


func _make_war() -> Zone:
	Game.current_zone = &"guildwar"
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _start(m: GuildWarMatch) -> void:
	m._timer = 0.05
	await _frames(6)
	for f in m.all_fighters():
		f._guard_until = 0
		f.set_physics_process(false)


## Every fighter of the war in a party of its own side, the match's lists agree.
func _check_war_parties(m: GuildWarMatch, label: String) -> void:
	var counts := {}
	for f in m.all_fighters():
		check(f.party >= 0, "%s: %s has a party" % [label, f.rival_name])
		check((f.party < GuildWarMatch.ENEMY_PARTY_BASE) == (f.team == GuildFighter.TEAM_ALLY), "%s: %s's party is of its own guild" % [label, f.rival_name])
		counts[f.party] = int(counts.get(f.party, 0)) + 1
	counts[GuildWarMatch.HERO_PARTY] = int(counts.get(GuildWarMatch.HERO_PARTY, 0)) + 1
	for p in counts:
		check(int(counts[p]) <= GuildWarMatch.PARTY_SIZE, "%s: party %d has at most five (%d)" % [label, p, counts[p]])
	var listed := 0
	for team in 2:
		for p in m.parties_of(team):
			listed += m.party_members(p).size()
	check(listed == m.all_fighters().size(), "%s: the parties list every fighter once" % label)
	check(m.hero_party_members().size() + 1 == int(counts[GuildWarMatch.HERO_PARTY]), "%s: the hero's party is told" % label)
	for f in m.allies:
		var tagged := f._label.text.begins_with("◆ ")
		check(tagged == (f.party == GuildWarMatch.HERO_PARTY) and (f._label.modulate == GuildWarMatch.PARTY_COLOR) == tagged, "%s: %s's name tag shows the hero's party (%s)" % [label, f.rival_name, f._label.text])
	for f in m.enemies:
		check(not f._label.text.begins_with("◆"), "%s: no rival wears our party mark" % label)


## Hired guilds (no guild, no party screen): the hero is dealt with everybody else.
func _hired_war() -> void:
	Game.guildwar_party_chosen = false
	var zone := _make_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and GuildWarMatch.in_war() and GuildWarMatch.current == m, "hired: the war is the current one")
	if m == null:
		return
	check(not m.party_chosen and m.party_picks.is_empty(), "hired: no choice made")
	_check_war_parties(m, "hired")
	check((m.party_plan[0] as Array).map(func(p): return p.size()) == [4, 4] and (m.party_plan[1] as Array).map(func(p): return p.size()) == [4, 4], "hired: hero + 7 and 8 are dealt in fours (%s / %s)" % [m.party_plan[0], m.party_plan[1]])
	zone.queue_free()
	await _frames(3)


func _guild_war() -> void:
	WorldPresence.clock_offset = float(WorldPlayers.START_UNIX) + 20.0 * 86400.0 - WorldPlayers.now()
	Game.join_guild(WorldPlayers.ALPHA)
	# The party screen: tap two guild mates, a fifth is refused, "สุ่มให้" fills, removal works.
	var screen := GuildWarScreen.new()
	add_child(screen)
	await _frames(2)
	screen.open_lobby()
	await _frames(1)
	screen.open_party()
	await _frames(2)
	var mates := screen.candidates
	check(mates.size() >= 12, "the party screen lists our guild mates (%d)" % mates.size())
	check(mates.size() == WorldPlayers.members_at(WorldPlayers.ALPHA, WorldPresence.clock()).size(), "every guild mate who fights is offered")
	check(screen._slots.size() == 5 and String((screen._slots[0].name as Label).text).contains("คุณ"), "five places, the hero in the first")
	var first := String(mates[0].name)
	var second := String(mates[3].name)
	var row := screen._rows[first] as Dictionary
	check(String((row.who as Label).text).contains(first) and (row.button as Button).is_inside_tree(), "a guild mate's row shows its name")
	(row.button as Button).pressed.emit()
	screen.toggle_pick(second)
	check(screen.picks == PackedStringArray([first, second]), "tapping adds to the party")
	check(String((screen._slots[1].name as Label).text) == first and (screen._slots[1].drop as Control).visible, "the pick takes a place with a remove button")
	check(screen._party_count.text.contains("3/5"), "the count tells 3/5 (%s)" % screen._party_count.text)
	screen.auto_fill()
	check(screen.picks.size() == 4 and screen.picks[0] == first and screen.picks[1] == second, "สุ่มให้ fills the empty places and keeps the picks")
	var outsider := ""
	for c in mates:
		if not screen.picks.has(String(c.name)):
			outsider = String(c.name)
			break
	screen.toggle_pick(outsider)
	check(screen.picks.size() == 4 and not screen.picks.has(outsider), "a full party takes nobody else")
	var buttons: Array[String] = []
	_collect_buttons(screen, buttons)
	check(buttons.has("สุ่มให้") and buttons.any(func(t: String): return t.begins_with("ยืนยันปาร์ตี้")), "the screen offers สุ่มให้ and a confirm")
	(screen._slots[4].drop as Button).pressed.emit()
	screen.toggle_pick(screen.picks[2])
	check(screen.picks == PackedStringArray([first, second]), "removing works from a place and from the list")
	var entered := {"n": 0}
	screen.enter_requested.connect(func(): entered.n += 1)
	screen.confirm_party()
	check(entered.n == 1 and not screen.is_open and Game.guildwar_party_chosen and Game.guildwar_party_picks == PackedStringArray([first, second]), "confirming with two picks goes to war")
	# The war honours the picks: the hero, the two and nobody else in the hero's party.
	var zone := _make_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and m.party_chosen and not Game.guildwar_party_chosen, "guild: the war takes the choice once")
	if m == null:
		screen.queue_free()
		return
	var mine := m.hero_party_members().map(func(f): return String(f.member.name))
	mine.sort()
	var want := [first, second]
	want.sort()
	check(mine == want, "guild: the hero's party is the hero and its two picks (%s)" % [mine])
	_check_war_parties(m, "guild")
	_check_split(m.party_plan[0], m.allies.size(), "guild ours", true, true)
	_check_split(m.party_plan[1], m.enemies.size(), "guild theirs")
	check(m.parties_of(GuildFighter.TEAM_ENEMY).size() >= 2 and m.parties_of(GuildFighter.TEAM_ALLY).size() >= 2, "guild: both guilds have several parties")
	check(m.allies[0].party == GuildWarMatch.HERO_PARTY and m.allies[1].party == GuildWarMatch.HERO_PARTY and m.allies[0].spawn_point.x > m.allies[m.allies.size() - 1].spawn_point.x, "guild: our party stands in the front row")
	await _start(m)
	await _buffs(m, zone.hero)
	await _resume(m, zone)
	screen.queue_free()
	WorldPresence.clock_offset = 0.0
	await _frames(2)


func _skill(cls: StringName, id: String) -> Dictionary:
	var skill := ClassData.find_skill(cls, id)
	check(not skill.is_empty(), "skill %s exists" % id)
	return skill


func _reset(fighters: Array, hero: Hero) -> void:
	for f in fighters:
		f._atk_boost = 1.0
		f._def_boost = 1.0
		f._buff_until = 0.0
		f._sync_def()
	hero._buffs.clear()
	hero.refresh_stats()


func _buffs(m: GuildWarMatch, hero: Hero) -> void:
	var mates := m.hero_party_members()
	var others: Array[GuildFighter] = []
	var other_party := -1
	for f in m.allies:
		if f.party != GuildWarMatch.HERO_PARTY and (other_party < 0 or f.party == other_party):
			other_party = f.party
			others.append(f)
	var foes := m.party_members(GuildWarMatch.ENEMY_PARTY_BASE)
	var foes2 := m.party_members(GuildWarMatch.ENEMY_PARTY_BASE + 1)
	check(mates.size() == 2 and others.size() >= 2 and foes.size() >= 2 and foes2.size() >= 1, "buffs: parties to test with")
	if mates.size() < 2 or others.size() < 2 or foes.size() < 2 or foes2.is_empty():
		return
	var a := mates[0]
	var a2 := mates[1]
	var b := others[0]
	var b2 := others[1]
	var e := foes[0]
	var e2 := foes[1]
	var e3 := foes2[0]
	# Everybody stands together on the plaza: only the party decides who gets a buff.
	var spot := SiegeArena.PLAZA + Vector3(0, 0.3, 0)
	hero.global_position = spot
	var everyone: Array = [a, a2, b, b2, e, e2, e3]
	for k in everyone.size():
		(everyone[k] as GuildFighter).global_position = spot + Vector3(cos(k * 0.9) * 2.5, 0, sin(k * 0.9) * 2.5)
	await _frames(1)
	check(GuildWarMatch.buff_reaches(hero, a) and not GuildWarMatch.buff_reaches(hero, b) and not GuildWarMatch.buff_reaches(a, b) and GuildWarMatch.buff_reaches(b, b2), "buff_reaches follows the parties")
	check(GuildWarMatch.buff_reaches(e, e2) and not GuildWarMatch.buff_reaches(e, e3) and not GuildWarMatch.buff_reaches(e, a) and not GuildWarMatch.buff_reaches(hero, e), "and the rival guild's")
	var focus := _skill(&"warrior", "concentration")
	# Hero -> allies: only the hero's party.
	_reset(everyone, hero)
	hero._apply_self_fx(focus)
	check(BuffBook.contains(hero._buffs, "concentration", false), "hero: the caster keeps its own buff")
	check(a._atk_boost > 1.2 and a2._atk_boost > 1.2, "hero -> party: both party mates get the buff")
	check(b._atk_boost == 1.0 and b2._atk_boost == 1.0, "hero -> another party: nothing")
	check(e._atk_boost == 1.0, "hero -> rival: nothing")
	# Ally -> hero and ally -> ally.
	_reset(everyone, hero)
	a._resolve(focus, null, Vector3.ZERO)
	check(a._atk_boost > 1.2, "ally: the caster keeps its own buff")
	check(BuffBook.contains(hero._buffs, "concentration", true), "party mate -> hero: the hero gets it (as an ally's buff)")
	var entry: Dictionary = hero._buffs.filter(func(x): return String(x.get("skill_id", "")) == "concentration").front() if not hero._buffs.is_empty() else {}
	check(not entry.is_empty() and float(entry.get("total", entry.get("secs", 99.0))) <= 30.0, "party mate -> hero: for 30 s at most")
	check(a2._atk_boost > 1.2, "party mate -> party mate: gets it")
	check(b._atk_boost == 1.0 and b2._atk_boost == 1.0 and e._atk_boost == 1.0, "party mate -> other parties and rivals: nothing")
	_reset(everyone, hero)
	b._resolve(focus, null, Vector3.ZERO)
	check(hero._buffs.is_empty(), "another party -> hero: nothing")
	check(b2._atk_boost > 1.2 and a._atk_boost == 1.0 and a2._atk_boost == 1.0, "another party -> its own mate only")
	# The rival guild deals the same way.
	_reset(everyone, hero)
	e._resolve(_skill(&"warrior", "holy_valor"), null, Vector3.ZERO)
	check(e2._atk_boost > 1.2 and e2._def_boost > 1.2, "rival -> its party mate: gets it")
	check(e3._atk_boost == 1.0 and b._atk_boost == 1.0 and hero._buffs.is_empty(), "rival -> its other party, us: nothing")
	# Out of reach the party still misses out (12 m as before).
	_reset(everyone, hero)
	a2.global_position = spot + Vector3(20, 0, 0)
	a._resolve(focus, null, Vector3.ZERO)
	check(a2._atk_boost == 1.0, "a party mate 20 m away is out of reach")
	a2.global_position = spot + Vector3(-2, 0, 2)
	# Heals reach everybody near as before: a heal-and-buff skill heals the other party, buffs only ours.
	_reset(everyone, hero)
	for f in everyone:
		f.hp = f.max_hp / 2
	Game.profile.hp = int(hero.stats.max_hp) / 2
	var hp_hero := int(Game.profile.hp)
	a._resolve(_skill(&"warrior", "drastic_spirit"), null, Vector3.ZERO)
	check(b.hp > b.max_hp / 2 and int(Game.profile.hp) > hp_hero, "heal: a party mate's heal still reaches another party and the hero")
	check(b._def_boost == 1.0 and a2._def_boost > 1.5, "heal: but its buff only the party")
	var b_hp := b.hp
	hero._heal(0.3)
	check(b.hp > b_hp, "heal: the hero's heal reaches a fighter of another party")
	var e_hp := e.hp
	b._heal(0.3)
	check(e.hp == e_hp, "heal: never the rivals")
	# The allied Bard's song: reaches the hero only from the hero's party.
	var anthem := _skill(&"bard", "heroic_anthem")
	_reset(everyone, hero)
	b._resolve(anthem, null, Vector3.ZERO)
	check(hero.song_entry().is_empty(), "song: another party's Bard does not reach the hero")
	check(b2._atk_boost > 1.0, "song: it reaches its own party")
	a._resolve(anthem, null, Vector3.ZERO)
	var song := hero.song_entry()
	check(String(song.get("skill_id", "")) == "heroic_anthem" and bool(song.get("ally", false)) and float(song.get("total", 99.0)) <= 30.0, "song: a party mate's song reaches the hero for 30 s at most")
	_reset(everyone, hero)
	hero._apply_self_fx(_skill(&"bard", "valor_march"))
	a._resolve(anthem, null, Vector3.ZERO)
	check(String(hero.song_entry().get("skill_id", "")) == "valor_march", "song: still never over the hero's own")
	# A stance stays on its caster.
	_reset(everyone, hero)
	a._resolve(_skill(&"bard", "virtuoso"), null, Vector3.ZERO)
	check(a2._atk_boost == 1.0 and not BuffBook.contains(hero._buffs, "virtuoso", true), "a stance stays its own")
	# The AI: a buff is worth more with the party around than alone.
	_reset(everyone, hero)
	var together := a._score(focus, "self", 5.0, 1.0)
	check(a.party_near(GuildFighter.BUFF_REACH) == 2, "AI: counts its party near (hero + mate: %d)" % a.party_near(GuildFighter.BUFF_REACH))
	check(b.party_near(GuildFighter.BUFF_REACH) == 1, "AI: not other parties (%d)" % b.party_near(GuildFighter.BUFF_REACH))
	hero.global_position = spot + Vector3(40, 0, 0)
	a2.global_position = spot + Vector3(-40, 0, 0)
	var alone := a._score(focus, "self", 5.0, 1.0)
	check(together > alone and alone > 0.0, "AI: a buff with the party near (%.1f) beats one alone (%.1f), which still counts" % [together, alone])
	hero.global_position = spot


## The parties come back with the war after a resume.
func _resume(m: GuildWarMatch, zone: Zone) -> void:
	m.save_checkpoint()
	var ckpt := Game.guildwar_checkpoint()
	check(bool(ckpt.get("chosen", false)) and str(ckpt.get("picks", [])) == str(m.party_picks), "resume: the picks are kept in the save (%s)" % [ckpt.get("picks")])
	var before := _party_names(m)
	zone.queue_free()
	await _frames(3)
	check(not GuildWarMatch.in_war(), "the war is over once its zone is gone")
	Game.guildwar_resuming = true
	var back := _make_war()
	var bm: GuildWarMatch = back.gw_match
	check(bm != null and bm.resumed and bm.party_chosen and _party_names(bm) == before, "resume: the same parties come back")
	back.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _party_names(m: GuildWarMatch) -> Dictionary:
	var out := {}
	for f in m.all_fighters():
		out[f.rival_name] = f.party
	return out


func _collect_buttons(node: Node, out: Array[String]) -> void:
	if node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_buttons(child, out)
