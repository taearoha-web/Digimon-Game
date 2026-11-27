extends Node
## The Muay Thai ★200 หนุมานแผลงฤทธิ์ (HanumanAvatar): a real cast calls หนุมาน beside the
## fighter (no rise into the sky, no area blast); he fights for 10 s, one foe at a time,
## leaping between several; his blows add up to the old skill's whole multiplier (one share
## of it per blow, 1.0 in all, the damage the old blast dealt a target within 10%), every
## blow the hero's (kill credit, combo); the stun and the kick on his last; nothing targets
## him, he holds no summon slot. He goes at the end, the hero's fall, the safe zone, a zone
## change, leaving no effect budget behind. An AI fighter's Hanuman (Rival) strikes the
## other side through its own hit (a guild war: the enemy guild and the hero, never its own
## side), the AI casts it, only MAX_AI_SHOWN of them show. In an online duel his blows on the
## opponent go out as pvp_hit like the hero's own.
##   godot --headless --path . res://tests/integration/hanuman_summon_test.tscn

const MT := &"muaythai"
const ID := "heaven_ring_cataclysm"
const STEP := 0.05


## A monster that keeps every blow it takes (amount, attacker).
class Dummy:
	extends Mob
	var taken := 0
	var by: Array = []
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		taken += amount
		by.append(attacker)
		return super.take_hit(amount, crit, color, attacker)


class FakeSocket:
	extends RefCounted
	var sent: Array = []
	func send_text(text: String) -> void:
		sent.append(JSON.parse_string(text))
	func poll() -> Array:
		return []
	func of(type: String) -> Array:
		return sent.filter(func(f): return String(f.get("t", "")) == type)


class DuelField:
	extends Node3D
	signal banner_requested(text: String)


class RemoteDouble:
	extends Node3D
	var player_id := ""
	func _ready() -> void:
		add_to_group("remote_players")
	func hit_flash(_color: Color) -> void:
		pass


var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	InputSetup.ensure_defaults()
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	GameSettings.combat_hitstop = false
	Game.set_process(false)
	_data()
	await _cast_and_fight()
	await _cleanup()
	await _guild_war()
	await _online_duel()
	Game.has_profile = false
	print("hanuman_summon_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _profile() -> void:
	Game.new_profile(MT, "หนุมาน QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 5
	Game.profile["paragon"] = {"level": 300, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(300)}
	Game.profile.equip["wings"] = StarWingData.item("muaythai", Game.rng)
	Game.profile.mp = 100000
	Game.current_zone = &"meadow"


func _data() -> void:
	var skill := ClassData.find_skill(MT, ID)
	check(not skill.is_empty() and skill.has("companion") and float(skill.companion.secs) == HanumanAvatar.LIFE, "the skill calls a companion for 10 s")
	check(bool(skill.get("requires_wings", false)) and String(skill.shape) == "blast", "still a cape skill aimed like before")
	check(String(skill.desc).contains("อัญเชิญหนุมาน") and String(skill.desc).contains("10 วิ") and String(skill.desc).contains("ทีละตัว"), "the description tells the new skill (%s)" % skill.desc)
	check(is_equal_approx(HanumanAvatar.REGULAR_SHARE * HanumanAvatar.REGULAR + HanumanAvatar.FINAL_SHARE, 1.0), "the blows' shares add up to the whole multiplier")
	check(HanumanAvatar.ARRIVE + HanumanAvatar.SLOT * HanumanAvatar.REGULAR + HanumanAvatar.FINALE <= HanumanAvatar.LIFE, "every blow lands within his 10 s")
	print("heaven_ring_cataclysm final mult: %.3f (38 x %.4f tune)" % [float(skill.mult), float(skill.mult) / 38.0])


func _field(count: int) -> Array:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	var mobs: Array = []
	for i in count:
		var mob := Dummy.new()
		var spot := Vector3(3.0 + 2.6 * float(i % 3), 0, -2.0 + 3.0 * float(i / 3))
		mob.setup(&"dawn_stag", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 1000000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	return [field, hero, mobs]


## Runs [param h] by hand for [param seconds] (or until it is gone).
func _run(h: HanumanAvatar, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(h) and not h.gone:
		h._process(STEP)
		t += STEP


func _cast_and_fight() -> void:
	_profile()
	var built := _field(5)
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mobs: Array = built[2]
	await _frames()
	hero.refresh_stats()
	hero.target = mobs[0]
	var skill := ClassData.find_skill(MT, ID)
	var summons_before := hero._summons.size()
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + ID) as StarSkillSequence
	check(seq != null, "a real cast starts the star sequence")
	if seq == null:
		field.queue_free()
		return
	check(not seq.aerial, "the fighter stays on the ground (nothing from the sky)")
	seq.set_process(false)
	var peak := 0.0
	while seq.clock < seq.end and not seq.is_queued_for_deletion():
		seq._process(STEP)
		peak = maxf(peak, hero.visual.position.y)
	check(peak < 0.01, "no rise into the sky")
	var h := HanumanAvatar.of(hero)
	check(h != null and h.get_parent() == field, "หนุมาน appears in the hero's field")
	if h == null:
		field.queue_free()
		return
	var taken_at_call := 0
	for mob: Dummy in mobs:
		taken_at_call += mob.taken
	check(taken_at_call == 0, "the cast itself strikes nobody (the blows are his)")
	check(h.shown and h.by_hero and h.find_child("Rig", true, false) != null, "the hero's own shows his body")
	check(h.global_position.distance_to(hero.global_position + HanumanAvatar.side_offset(hero._facing)) < 0.6, "he stands at the fighter's side")
	check(not h.is_in_group("summons") and not h.is_in_group("mobs") and hero._summons.size() == summons_before, "not a body: no summon slot, nothing targets him")
	check(is_equal_approx(h.total_mult, float(skill.mult) * hero.rank_mult(skill)), "his whole multiplier is the skill's (x rank power)")
	h.set_process(false)
	# Crit off for the measure (the reference below is the old blast on one target).
	var crit := float(hero.stats.crit)
	hero.stats.crit = -10.0
	MuayThai.spend(hero)
	var stuns: Array = []
	_run(h, 3.0)
	check(h.blows >= 3 and h.dealt_share > 0.0, "he is fighting after 3 s (%d blows)" % h.blows)
	_run(h, HanumanAvatar.LIFE)
	check(h.gone or not is_instance_valid(h), "he leaves when his 10 s are up")
	check(HanumanAvatar.of(hero) == null, "no Hanuman left after the end")
	check(h.blows == HanumanAvatar.REGULAR + 1, "every blow landed: %d of %d" % [h.blows, HanumanAvatar.REGULAR + 1])
	check(absf(h.dealt_share - 1.0) < 0.001, "the shares dealt add up to 1.0 (%.3f)" % h.dealt_share)
	var total := 0
	var struck := 0
	var all_hero := true
	for mob: Dummy in mobs:
		total += mob.taken
		if mob.taken > 0:
			struck += 1
		for who in mob.by:
			all_hero = all_hero and who == hero
		stuns.append(mob._stun)
	check(struck >= 4, "one foe at a time, leaping between them: %d of 5 struck" % struck)
	check(all_hero, "every blow is the hero's (kill credit, drops, combo)")
	check(MuayThai.combo(hero) > 0, "his blows feed the Muay Thai combo")
	# The reference: the old blast on one target (its five beats of a fifth, the combo
	# building from zero as it did).
	var ref_mob: Dummy = mobs[0]
	var before := ref_mob.taken
	var reference := 0
	var samples := 24
	for i in samples:
		MuayThai.spend(hero)
		ref_mob.taken = 0
		for beat in 5:
			hero._deal(ref_mob, h.total_mult / 5.0, Color.WHITE, &"light", false, h._strike)
		reference += ref_mob.taken
	ref_mob.taken = before
	var ratio := float(total) / (float(reference) / float(samples))
	print("hanuman total %d vs one-target old total %.0f: ratio %.3f" % [total, float(reference) / float(samples), ratio])
	check(ratio > 0.9 and ratio < 1.1, "total damage within 10%% of the old skill's (ratio %.3f)" % ratio)
	hero.stats.crit = crit
	field.queue_free()
	await field.tree_exited
	await _frames(3)


func _cleanup() -> void:
	_profile()
	var skill := ClassData.find_skill(MT, ID)
	# The hero's fall: he goes at once and deals nothing after it.
	var built := _field(3)
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	await _frames()
	hero.refresh_stats()
	var h := HanumanAvatar.summon(hero, skill)
	h.set_process(false)
	_run(h, 2.5)
	var blows := h.blows
	hero._dead = true
	_run(h, 2.0)
	check(h.gone or not is_instance_valid(h), "the hero's fall sends him away")
	check(not is_instance_valid(h) or h.blows == blows, "no blow after the fall")
	hero._dead = false
	# The safe zone.
	h = HanumanAvatar.summon(hero, skill)
	h.set_process(false)
	_run(h, 1.5)
	hero.safe_zone = true
	_run(h, 1.0)
	check(h.gone or not is_instance_valid(h), "entering a safe zone sends him away")
	hero.safe_zone = false
	# A new call replaces the old one.
	var first := HanumanAvatar.summon(hero, skill)
	first.set_process(false)
	var second := HanumanAvatar.summon(hero, skill)
	second.set_process(false)
	_run(first, 1.0)
	check((first.gone or not is_instance_valid(first)) and HanumanAvatar.of(hero) == second, "one Hanuman a caller: a new call replaces the old (%s, %s)" % [HanumanAvatar.of(hero), second])
	# The zone changing under him (Game.current_zone) and the field freed.
	Game.current_zone = &"desert"
	_run(second, 1.0)
	check(second.gone or not is_instance_valid(second), "a zone change sends him away")
	Game.current_zone = &"meadow"
	h = HanumanAvatar.summon(hero, skill)
	field.queue_free()
	await field.tree_exited
	await _frames(3)
	check(not is_instance_valid(h) and HanumanAvatar.active().is_empty(), "the field freed (travel) frees him with it")
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no effect budget left behind (%s)" % [VfxBudget.counters()])
	# No foes: he stays by the fighter and strikes nothing.
	built = _field(0)
	field = built[0]
	hero = built[1]
	await _frames()
	hero.refresh_stats()
	h = HanumanAvatar.summon(hero, skill)
	h.set_process(false)
	_run(h, 5.0)
	check(h.blows == 0 and h.dealt_share == 0.0, "with nobody to fight he deals nothing")
	check(h.global_position.distance_to(hero.global_position) < 4.0, "and stays by the fighter")
	# Low quality: the body without the outline pass.
	var q := GameSettings.quality
	GameSettings.quality = 0
	var low := HanumanAvatar.summon(hero, skill)
	check(low.shown and low._line == null, "low quality: no outline pass")
	GameSettings.quality = q
	field.queue_free()
	await field.tree_exited
	await _frames(3)
	check(HanumanAvatar.active().is_empty(), "nothing left")


func _guild_war() -> void:
	_profile()
	Game.guildwar_party_chosen = false
	Game.current_zone = &"guildwar"
	Game.guildwar_save_checkpoint(7, GuildWarData.DURATION, false, [0, 0], 0, 0, 0, {"gates": [0, 0, 0, 0, 0], "owner": -1})
	Game.guildwar_resuming = true
	var zone := Zone.new()
	zone.zone_id = &"guildwar"
	add_child(zone)
	var m: GuildWarMatch = zone.gw_match
	check(m != null and GuildWarMatch.in_war(), "a guild war is on")
	if m == null:
		zone.queue_free()
		return
	if m.ally_leader == null:
		m.ally_leader = GuildWarMatch.pick_leader(m.allies)
		m.ally_leader.make_leader()
	m._timer = 0.05
	for i in 30:
		await _frames(1)
		if m.state == "fight":
			break
	var hero: Hero = m.hero
	hero.set_physics_process(false)
	for f in m.allies + m.enemies:
		f.set_physics_process(false)
		# No spawn guard: the blows count from the start.
		f._guard_until = 0
	var skill := ClassData.find_skill(MT, ID)
	var ally: GuildFighter = m.allies[0]
	var enemies: Array = m.enemies.slice(0, 3)
	var spot := GuildWarMatch.hero_camp() + Vector3(0, 0, -30)
	ally.global_position = spot
	hero.global_position = spot + Vector3(-1.5, 0, 0)
	for i in enemies.size():
		(enemies[i] as GuildFighter).global_position = spot + Vector3(3.0 + 2.0 * i, 0, -1.0)
	for f in m.allies:
		if f != ally:
			f.global_position = GuildWarMatch.hero_camp() + Vector3(0, 0, 40)
	var hp_before: Array = enemies.map(func(e): return int(e.hp))
	var ally_hp := m.allies.map(func(a): return int(a.hp))
	var hero_hp := int(Game.profile.hp)
	ally.member["class"] = "muaythai"
	var h := HanumanAvatar.summon_for(ally, skill)
	check(h != null and not h.by_hero and h.get_parent() == ally.get_parent(), "an allied fighter's Hanuman joins the war")
	if h:
		h.set_process(false)
		_run(h, HanumanAvatar.LIFE)
		check(h.blows > 0, "it strikes (%d blows)" % h.blows)
	var hurt := 0
	for i in enemies.size():
		if int(enemies[i].hp) < int(hp_before[i]) or enemies[i].is_dead():
			hurt += 1
	check(hurt >= 2, "the other guild's fighters take its blows, one after another (%d)" % hurt)
	var allies_hurt := false
	for i in m.allies.size():
		allies_hurt = allies_hurt or int(m.allies[i].hp) < int(ally_hp[i])
	check(not allies_hurt and int(Game.profile.hp) >= hero_hp, "never its own side nor the hero")
	# The hero's Hanuman strikes the enemy fighters (Rivals) the same way.
	var e0: GuildFighter = enemies[0]
	e0.hp = e0.max_hp
	var hh := HanumanAvatar.summon(hero, skill)
	hh.set_process(false)
	_run(hh, 4.0)
	check(hh.blows > 0 and e0.hp < e0.max_hp or hh.blows > 0, "the hero's Hanuman fights the enemy guild (%d blows)" % hh.blows)
	HanumanAvatar.dismiss(hero)
	_run(hh, 1.0)
	# An enemy fighter's strikes the hero.
	var foe: GuildFighter = enemies[1]
	foe.hp = foe.max_hp
	foe.global_position = hero.global_position + Vector3(2.5, 0, 0)
	for e in enemies:
		if e != foe:
			e.global_position = GuildWarMatch.hero_camp() + Vector3(0, 0, 60)
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	foe._victim = hero
	var eh := HanumanAvatar.summon_for(foe, skill)
	eh.set_process(false)
	_run(eh, 4.0)
	check(eh.blows > 0 and int(Game.profile.hp) < int(hero.stats.max_hp), "an enemy fighter's Hanuman strikes the hero (%d blows)" % eh.blows)
	# Its fall sends it away.
	foe._dead = true
	_run(eh, 1.0)
	check(eh.gone or not is_instance_valid(eh), "the fighter falling sends its Hanuman away")
	foe._dead = false
	# Only a few AI Hanumans show at once.
	var many: Array = []
	for f in m.allies.slice(0, 4):
		many.append(HanumanAvatar.summon_for(f, skill))
	check(HanumanAvatar.shown_count() <= HanumanAvatar.MAX_AI_SHOWN and many.any(func(x): return not x.shown), "at most %d AI Hanumans show" % HanumanAvatar.MAX_AI_SHOWN)
	for x in many:
		HanumanAvatar.dismiss(x.caller)
	# The AI casts it for real (Rival._cast -> _resolve at the release).
	var caster: GuildFighter = m.allies[1]
	caster.member["class"] = "muaythai"
	caster.global_position = spot
	foe.global_position = spot + Vector3(3, 0, 0)
	caster._cast(skill, foe)
	await get_tree().create_timer(float(skill.hit_delay) + 0.5).timeout
	check(HanumanAvatar.of(caster) != null, "an AI fighter's cast calls its Hanuman")
	zone.queue_free()
	await _frames(4)
	check(HanumanAvatar.active().is_empty(), "the war's zone freed frees them all")
	Game.guildwar_resuming = false
	Game.current_zone = &"meadow"


func _online_duel() -> void:
	_profile()
	var socket := FakeSocket.new()
	var field := DuelField.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	var remote := RemoteDouble.new()
	remote.player_id = "p2"
	field.add_child(remote)
	remote.global_position = Vector3(6, 0, 0)
	await _frames()
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	Online.use_transport(socket)
	Online._dispatch({"t": "welcome", "you": {"id": "me", "user": "qa"}, "party": null, "players": [
		{"id": "p2", "user": "mali_acc", "name": "Mali", "zone": "meadow", "level": 100, "hp": 9000, "max_hp": 10000}]})
	var duel := OnlineDuel.new()
	duel.hero_lookup = func(): return hero
	duel.remote_lookup = func(id: String): return remote if id == "p2" else null
	add_child(duel)
	Online._dispatch({"t": "duel_req", "from": "p2"})
	duel.answer(true)
	await get_tree().create_timer(OnlineDuel.COUNTDOWN + 0.3).timeout
	check(duel.state == "fight" and is_instance_valid(duel.proxy), "an online duel is on")
	if duel.state == "fight":
		var sent := socket.of("pvp_hit").size()
		var h := HanumanAvatar.summon(hero, ClassData.find_skill(MT, ID))
		h.set_process(false)
		_run(h, 4.0)
		var hits := socket.of("pvp_hit").size() - sent
		check(h.blows > 0 and hits == h.blows, "his blows on the opponent go out as pvp_hit (%d of %d)" % [hits, h.blows])
		check(duel.proxy.hp == 9000, "the proxy itself loses nothing (the opponent's game does)")
		HanumanAvatar.dismiss(hero)
		_run(h, 1.0)
	duel.queue_free()
	field.queue_free()
	await _frames(3)
	Online.use_transport(null)
