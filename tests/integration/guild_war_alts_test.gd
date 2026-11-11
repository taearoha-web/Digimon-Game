extends Node
## The player's other characters (other save slots, Lv.100 and in a guild) fight in the
## guild war for their own guild, played by the AI with their real build (Game.alt_war_fighter:
## class, level, stars, job advancement, worn gear with its +plus and wings, skill ranks),
## tagged as the player's ((ตัวละครของคุณ · AI)): one in the hero's guild fights beside it,
## one in the rival guild fights against it at full strength (hostile, its blows hurt, its
## falls dealt count for its guild). Each takes a world player's place (the side keeps its
## size), the other slot is never written, and one picked to lead its guild leads it.
## godot --headless --path . res://tests/integration/guild_war_alts_test.tscn
var failures: Array[String] = []
var checks := 0

const MAIN_SLOT := 2
const ALLY_SLOT := 3
const ALLY_NAME := "พรานเงา"
const RIVAL_SLOT := 4
const RIVAL_NAME := "จอมเวทอัคคี"
const ALLY_PLUS := 12
const RIVAL_PLUS := 9

var _files := {}


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
	_alt_fighter()
	_put_alt()
	await _league_war()
	await _fixed_war()
	await _alt_leaders()
	for s in [ALLY_SLOT, RIVAL_SLOT]:
		check(FileAccess.get_file_as_string(Game.save_path(s)) == String(_files[s]), "slot %d's save was never written" % s)
	WorldPresence.clock_offset = 0.0
	print("GUILD WAR ALTS: %d checks, %d failures" % [checks, failures.size()])
	if failures.is_empty():
		print("PASS")
	get_tree().quit(1 if failures.size() > 0 else 0)


func _t() -> float:
	return WorldPresence.clock()


func _hero(cls: StringName, hero_name: String, stars: int, adv: int) -> void:
	Game.new_profile(cls, hero_name)
	Game.profile.level = 100
	Game.profile.adv = adv
	Game.profile["paragon"] = {"level": stars, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(stars)}
	Game.profile.hp = Game.stats_now().max_hp


func _dress(cls: StringName, stars: int, plus: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weapon := StarProgression.item(cls, stars, "weapon", rng)
	weapon["plus"] = plus
	Game.profile.equip["weapon"] = weapon
	Game.profile.equip["armor"] = StarProgression.item(cls, stars, "armor", rng)
	Game.profile.equip["wings"] = StarWingData.item(String(cls), rng, 4)


## One other character in Alpha (the hero's guild), one in Neverdie (the rival), then the
## one played (Alpha).
func _make_characters() -> void:
	Game.slot = ALLY_SLOT
	_hero(&"archer", ALLY_NAME, 150, 4)
	_dress(&"archer", 150, ALLY_PLUS, 11)
	check(Game.join_guild(WorldPlayers.ALPHA), "the ally character joins Alpha")
	check(Game.save(), "the ally character is saved")
	Game.slot = RIVAL_SLOT
	_hero(&"mage", RIVAL_NAME, 100, 3)
	_dress(&"mage", 100, RIVAL_PLUS, 22)
	check(Game.join_guild(WorldPlayers.NEVERDIE), "the rival character joins Neverdie")
	check(Game.save(), "the rival character is saved")
	Game.slot = MAIN_SLOT
	_hero(&"warrior", "GL", 200, 4)
	Game.join_guild(WorldPlayers.ALPHA)
	check(Game.save(), "the played character is saved")
	for s in [ALLY_SLOT, RIVAL_SLOT]:
		_files[s] = FileAccess.get_file_as_string(Game.save_path(s))
	check(Game.guild_alts(WorldPlayers.ALPHA).size() == 1 and Game.guild_alts(WorldPlayers.NEVERDIE).size() == 1, "one other character in each guild")


func _alt_fighter() -> void:
	var info := Game.alt_war_fighter(ALLY_SLOT)
	check(not info.is_empty(), "the ally character reads as a fighter")
	if info.is_empty():
		return
	check(String(info.member["class"]) == "archer" and String(info.member.name) == ALLY_NAME and int(info.member.level) == 100, "its class, name and level (%s)" % [info.member])
	check(int(info.alt) == ALLY_SLOT and String(info.tag).contains(Game.ALT_WAR_TAG) and String(info.tag).contains("★150"), "tagged as the player's, its stars shown (%s)" % info.tag)
	var p: Dictionary = info.profile
	check(int(p.adv) == 4 and int(p.paragon.level) == 150, "its job advancement and stars")
	check(int(p.equip.weapon.get("plus", 0)) == ALLY_PLUS and p.equip.has("wings") and p.equip.has("armor"), "its worn gear with the +plus and wings")
	check(p.has("skills") and p.has("attrs") and not p.has("inv") and not p.has("flags"), "only what the fight needs from the save")
	check(Game.alt_war_fighter(MAIN_SLOT).is_empty() and Game.alt_war_fighter(9).is_empty(), "the one played and an empty slot are no fighters")


func _put_alt() -> void:
	var info := Game.alt_war_fighter(ALLY_SLOT)
	var lineup: Array = []
	for i in WorldPlayers.members_at(WorldPlayers.ALPHA, _t()):
		if lineup.size() < 4:
			lineup.append(WorldPlayers.fighter(i, _t()))
	var last := String(lineup[3].member.name)
	var kept := String(lineup[2].member.name)
	var full := lineup.duplicate()
	check(GuildWarMatch.put_alt(full, info, 4, [last]) and full.size() == 4 and GuildWarMatch.alt_index(full, ALLY_SLOT) == 2, "a full side: it takes the last place not kept (the leader's, a party pick's)")
	check(String(full[3].member.name) == last and not _names(full).has(kept), "the kept one stays")
	check(not GuildWarMatch.put_alt(full, info, 4), "never twice")
	var room := lineup.duplicate()
	check(GuildWarMatch.put_alt(room, info, 6) and room.size() == 5, "a side with room: it joins")


func _names(side: Array) -> Array[String]:
	var out: Array[String] = []
	for f in side:
		out.append(String(f.member.get("name", "")))
	return out


func _open_war() -> Zone:
	Game.current_zone = &"guildwar"
	Game.guildwar_resuming = false
	Game.guildwar_league = {"ours": Game.guild(), "theirs": WorldPlayers.NEVERDIE, "at": int(_t())}
	Game.profile.hp = Game.stats_now().max_hp
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	return zone


func _close_war(zone: Zone) -> void:
	zone.queue_free()
	await _frames(3)
	Game.guildwar_clear_checkpoint()


func _alt_of(side: Array, slot: int) -> GuildFighter:
	for f in side:
		if (f as GuildFighter).alt_slot == slot:
			return f
	return null


## A league round: each character fights for its own guild, the rival one against the hero.
func _league_war() -> void:
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	check(m != null and bool(m.roster.get("guilds", false)), "a league war between Alpha and Neverdie")
	if m == null:
		return
	var hero: Hero = zone.hero
	var ours := _alt_of(m.allies, ALLY_SLOT)
	var theirs := _alt_of(m.enemies, RIVAL_SLOT)
	check(ours != null and theirs != null, "both characters are on the field")
	check(_alt_of(m.enemies, ALLY_SLOT) == null and _alt_of(m.allies, RIVAL_SLOT) == null, "each in its own guild")
	check(m.roster.ally.size() <= GuildWarData.GUILD_SIDE - 1 and m.roster.enemy.size() <= GuildWarData.GUILD_SIDE, "the sides keep their size limit (%d, %d)" % [m.roster.ally.size(), m.roster.enemy.size()])
	if ours == null or theirs == null:
		await _close_war(zone)
		return
	check(String(ours.member["class"]) == "archer" and int(ours._profile.equip.weapon.plus) == ALLY_PLUS and ours._equip.has("wings"), "ours: an archer in its own gear (+%d, wings)" % ALLY_PLUS)
	check(String(theirs.member["class"]) == "mage" and int(theirs._profile.equip.weapon.plus) == RIVAL_PLUS and int(theirs._profile.adv) == 3, "theirs: a mage in its own gear (+%d), its job advancement" % RIVAL_PLUS)
	var sheet := HeroStats.compute(theirs._profile)
	check(theirs.max_hp == int(sheet.max_hp) and is_equal_approx(float(theirs.rstats.atk), float(sheet.atk)), "theirs at full strength (its own sheet, nothing taken off)")
	check(ours.shown_name() == "%s (%s)" % [ALLY_NAME, Game.ALT_WAR_TAG] and ours.rival_name.contains(Game.ALT_WAR_TAG) and String(ours.tag).contains(Game.ALT_WAR_TAG), "named and tagged as the player's character (%s)" % ours.shown_name())
	check(not ours.is_leader and not theirs.is_leader and m.hero_leads(), "not leaders unless picked")
	check(ours.team == GuildFighter.TEAM_ALLY and ours.is_in_group("companions") and not ours.is_in_group("mobs"), "ours fights beside the hero")
	check(theirs.team == GuildFighter.TEAM_ENEMY and theirs.hostile and theirs.is_in_group("mobs") and m.foes_of(GuildFighter.TEAM_ALLY).has(theirs), "theirs is hostile to the hero's guild")
	# The fight: its blows hurt the hero, its falls count for Neverdie.
	m._timer = 0.05
	var tries := 0
	while m.state != "fight" and tries < 120:
		await _frames(1)
		tries += 1
	check(m.state == "fight", "the war begins")
	for f in m.all_fighters():
		f.set_physics_process(false)
	m.set_process(false)
	hero._invulnerable_until = 0
	hero.stats.dodge = 0.0
	Game.profile.hp = int(hero.stats.max_hp)
	var before := int(Game.profile.hp)
	BurstGuard.clear()
	theirs._hit(hero, 1.0, Color.WHITE)
	check(int(Game.profile.hp) < before, "theirs hurts the hero (%d -> %d)" % [before, int(Game.profile.hp)])
	var victim: GuildFighter = null
	for f in m.allies:
		if f != ours:
			victim = f
			break
	var score_before := m.score[GuildFighter.TEAM_ENEMY]
	victim.fell.emit(victim, theirs)
	check(m.score[GuildFighter.TEAM_ENEMY] == score_before + 1 and theirs.kills >= 1, "a fall it deals counts for Neverdie")
	var ours_before := m.score[GuildFighter.TEAM_ALLY]
	theirs.fell.emit(theirs, ours)
	check(m.score[GuildFighter.TEAM_ALLY] == ours_before + 1, "a fall ours deals counts for Alpha")
	await _close_war(zone)


## A fixed 8 v 8 line-up of the two guilds (the hero one of ours): each character takes a
## world player's place and the sides stay 8 v 8.
func _fixed_war() -> void:
	var sides: Array = []
	for g in [WorldPlayers.ALPHA, WorldPlayers.NEVERDIE]:
		var lineup: Array = []
		var want := GuildWarData.TEAM_SIZE - (1 if g == WorldPlayers.ALPHA else 0)
		for i in WorldPlayers.members_at(g, _t()):
			if lineup.size() < want:
				lineup.append(WorldPlayers.fighter(i, _t()))
		sides.append({"lineup": lineup, "name": WorldPlayers.guild_name(g), "guild": g, "power": 0.0})
	if (sides[0].lineup as Array).size() < GuildWarData.TEAM_SIZE - 1 or (sides[1].lineup as Array).size() < GuildWarData.TEAM_SIZE:
		check(false, "8 v 8: both guilds have the members")
		return
	GuildWarMatch.next_roster = {"sides": sides, "guilds": true, "owner": -1}
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "8 v 8: no match")
		return
	check(m.allies.size() == GuildWarData.TEAM_SIZE - 1 and m.enemies.size() == GuildWarData.TEAM_SIZE, "8 v 8 stays 8 v 8 (%d + hero, %d)" % [m.allies.size(), m.enemies.size()])
	check(_alt_of(m.allies, ALLY_SLOT) != null and _alt_of(m.enemies, RIVAL_SLOT) != null, "8 v 8: each character in place of a world player")
	await _close_war(zone)


## Picked to lead: the characters lead their guilds in the war itself.
func _alt_leaders() -> void:
	var alpha := WorldPlayers.ALPHA
	var never := WorldPlayers.NEVERDIE
	check(Game.set_guild_leader(alpha, Game.alt_pick(ALLY_SLOT)) and Game.set_guild_leader(never, Game.alt_pick(RIVAL_SLOT)), "both characters picked to lead")
	check(Game.guild_war_leader(alpha) == ALLY_NAME and Game.guild_war_leader(never) == RIVAL_NAME, "they lead in the war")
	check(GuildWarScreen._our_leader_text(alpha).contains(Game.ALT_WAR_TAG), "the war screen names ours as the player's character")
	var zone := _open_war()
	var m: GuildWarMatch = zone.gw_match
	if m == null:
		check(false, "alt leaders: no match")
		return
	var ours := m.ally_leader
	var theirs := m.enemy_leader
	check(ours != null and ours.alt_slot == ALLY_SLOT and ours.is_leader and not m.hero_leads(), "ours leads Alpha, not the hero")
	check(theirs != null and theirs.alt_slot == RIVAL_SLOT and theirs.is_leader, "theirs leads Neverdie")
	check(m.leader_of(GuildFighter.TEAM_ENEMY) == theirs and m.leader_of(GuildFighter.TEAM_ALLY) == ours, "the war's leaders")
	check(m.allies.filter(func(f): return f.is_leader).size() == 1 and m.enemies.filter(func(f): return f.is_leader).size() == 1, "one leader a side")
	if theirs != null:
		check(not bool(m.roster.enemy[GuildWarMatch.alt_index(m.roster.enemy, RIVAL_SLOT)].get("tank", false)) and theirs.max_hp == int(HeroStats.compute(theirs._profile).max_hp), "it leads with its own build (no tank build)")
		check(theirs._label.text.contains(RIVAL_NAME) and theirs._label.text.contains(Game.ALT_WAR_TAG), "its leader label names it as the player's (%s)" % theirs._label.text)
	check(m.stand_in_lines().is_empty(), "nobody stands in")
	await _close_war(zone)
	Game.profile.erase("guild_leaders")
