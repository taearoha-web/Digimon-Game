extends Node
## The Dark Lord's and the Bard's ★500 ultimates with mechanics of their own (AscendUlt):
##   สัญญาโลหิต (heaven_hell_sovereign.gd): a real cast hands over at the release; the dark
##     lord pays 20% of its CURRENT HP, never its last point; three blood blasts round it
##     strike every foe within the radius (shares 0.3 + 0.3 + 0.4 = 1) and none beyond, their
##     damage scaled by the HP paid (0.5 + 2.5 x paid / max HP, at most 1: a cast at 1 HP
##     deals half a cast at full HP); for 10 s after it every hit it lands heals it 20% of
##     the damage (a buff entry "hit_heal", ClassRoles.after_hit), then no more.
##   ระบำสะกดใจ (universe_hymn.gd): the opening chord strikes every foe on the stage (0.3)
##     and makes it dance for 3 s (a boss / a player 1.2 s), held like a stun (a monster
##     beside the hero does not strike it while it dances, and does once it is let go), its
##     body bobbing and twirling under notes and hearts, taking +20% from every hit; the
##     finale (0.7) lands after the dance; foes off the stage are left alone.
## Both stop cleanly when the caster is freed mid-cast (no more blows, the dancers let go),
## and an AI player's cast (a guild war fighter, Rival) plays the same mechanics on the
## other guild's fighters: the price and the drink, the dance and its vulnerability.
##   godot --headless --path . res://tests/integration/ascend_ult_darklord_bard_test.tscn

const DL := &"darklord"
const BD := &"bard"
const PACT := "heaven_hell_sovereign"
const HYMN := "universe_hymn"
const STEP := 0.05


## A monster that keeps the HP each hit took off it.
class Dummy:
	extends Mob
	var taken := 0
	var hits := 0
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		var before := hp
		var killed := super.take_hit(amount, crit, color, attacker)
		taken += before - hp
		hits += 1
		return killed


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


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	InputSetup.ensure_defaults()
	WorldEvents.festival_enabled = false
	GameSettings.load_settings()
	GameSettings.combat_hitstop = false
	Game.set_process(false)
	_data()
	await _pact_cast()
	await _pact_price()
	await _pact_drink()
	await _pact_freed()
	await _hymn_cast()
	await _hymn_hold()
	await _hymn_freed()
	await _guild_war()
	Game.has_profile = false
	print("ascend_ult_darklord_bard_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ascend QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile["paragon"] = {"level": 500, "exp": 0, "points": 0, "spent": 0, "alloc": Game.party_star_alloc(300)}
	Game.profile.equip["wings"] = StarWingData.item(String(cls), Game.rng)
	Game.profile.mp = 100000
	Game.current_zone = &"meadow"


## A field with the hero at the origin and monsters at [param spots] (no defence, so a
## blow's damage is its raw power).
func _field(spots: Array) -> Array:
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	var mobs: Array = []
	for spot: Vector3 in spots:
		var mob := Dummy.new()
		mob.setup(&"dawn_stag", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 1000000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	return [field, hero, mobs]


func _ready_hero(hero: Hero) -> void:
	hero.refresh_stats()
	hero.stats.crit = -10.0
	hero.stats["lifesteal"] = 0.0
	hero.stats.dodge = 0.0
	Game.profile.hp = int(hero.stats.max_hp)
	for mob: Mob in get_tree().get_nodes_in_group("mobs"):
		mob.stats.def = 0.0


func _ult(field: Node, id: String) -> Node:
	return field.get_node_or_null("AscendUlt_" + id)


func _run(node: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(node) and not bool(node.get("gone")):
		node._process(STEP)
		t += STEP


func _free_field(field: Node) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await field.tree_exited
	await _frames(3)


# --- Data ----------------------------------------------------------------------------------

func _data() -> void:
	var pact := ClassData.find_skill(DL, PACT)
	var hymn := ClassData.find_skill(BD, HYMN)
	check(AscendUlt.handles(pact) and AscendUlt.handles(hymn), "both ultimates play by their own scripts (AscendUlt)")
	check(String(pact.name) == "สัญญาโลหิต" and String(hymn.name) == "ระบำสะกดใจ", "the new names (%s, %s)" % [pact.name, hymn.name])
	check(String(pact.desc).begins_with("สกิลเทวาลัย • ") and String(pact.desc).contains("20%") and String(pact.desc).contains("10 วิ") and String(pact.desc).contains("ดูดเลือด"), "the pact's description tells the price and the drink")
	check(String(hymn.desc).begins_with("สกิลเทวาลัย • ") and String(hymn.desc).contains("3 วิ") and String(hymn.desc).contains("+20%") and String(hymn.desc).contains("เต้น"), "the dance's description tells the dance and the +20%")
	check(not pact.fx.has("stun") and not pact.fx.has("burn") and pact.fx.has("pact_leech"), "the pact carries only its own effects (no stun, no burn): %s" % str(pact.fx))
	check(float(hymn.fx.get("stun", 0.0)) == 3.0 and float(hymn.fx.get("dance_taken", 0.0)) == 0.2 and not hymn.fx.has("weaken"), "the dance: 3 s, +20%%, no weaken (%s)" % str(hymn.fx))
	check(String(pact.shape) == "burst", "the pact bursts round the dark lord (shape burst)")
	var Pact: GDScript = AscendUlt.script_for(pact)
	check(Pact.price(1) == 0 and Pact.price(4) == 0 and Pact.price(5) == 1 and Pact.price(1000) == 200, "the price: 20% of the current HP, never the last point")
	check(is_equal_approx(Pact.power_for(200, 1000), 1.0) and is_equal_approx(Pact.power_for(100, 1000), 0.75) and is_equal_approx(Pact.power_for(0, 1000), 0.5) and is_equal_approx(Pact.power_for(900, 1000), 1.0), "the power: 0.5 + 2.5 x paid share, capped at 1")


# --- สัญญาโลหิต -----------------------------------------------------------------------------

func _pact_cast() -> void:
	_profile(DL)
	var built := _field([Vector3(3, 0, 0), Vector3(-4, 0, 3), Vector3(0, 0, -6), Vector3(15, 0, 0)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mobs: Array = built[2]
	await _frames()
	_ready_hero(hero)
	hero.target = mobs[0]
	var skill := ClassData.find_skill(DL, PACT)
	var max_hp := int(hero.stats.max_hp)
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + PACT) as StarSkillSequence
	check(seq != null, "a real cast starts the star sequence")
	if seq == null:
		await _free_field(field)
		return
	seq.set_process(false)
	var ult: Node = null
	while is_instance_valid(seq) and not seq.is_queued_for_deletion() and seq.clock < seq.end:
		seq._process(STEP)
		if ult == null:
			ult = _ult(field, PACT)
			if ult:
				ult.set_process(false)
				# The drink's buff rebuilt the stats: crits off again for the measure.
				hero.stats.crit = -10.0
	check(ult != null, "the release hands the cast to the pact's script")
	if ult == null:
		await _free_field(field)
		return
	var paid: int = ult.paid
	check(paid == int(floor(float(max_hp) * 0.2)) and int(Game.profile.hp) == max_hp - paid, "at full HP the pact takes 20%% (%d of %d, HP %d)" % [paid, max_hp, Game.profile.hp])
	var whole := float(ult.skill.mult) * hero.rank_mult(ult.skill)
	check(absf(float(ult.factor) - 1.0) < 0.001 and absf(float(ult.total_mult) - whole) < 0.001 * whole, "and buys the whole multiplier (x%.2f: %.2f of %.2f)" % [float(ult.factor), float(ult.total_mult), whole])
	var buff := hero._buffs.filter(func(b): return String(b.get("skill_id", "")) == PACT)
	check(buff.size() == 1 and is_equal_approx(float(buff[0].get("hit_heal", 0.0)), 0.2), "the drink is on the hero: a hit_heal 20%% entry (%s)" % str(buff))
	check(buff.size() == 1 and absi(int(buff[0].until) - Time.get_ticks_msec() - 10000) < 1500, "for 10 s")
	var taken_at_release := mobs.map(func(m): return m.taken)
	_run(ult, 2.3)
	var shares: Array = mobs.map(func(m): return float(ult.dealt.get(m.get_instance_id(), 0.0)))
	check(mobs.slice(0, 3).all(func(m): return m.hits == 3), "every foe within 10 m takes three blasts (%s)" % str(mobs.map(func(m): return m.hits)))
	check(shares.slice(0, 3).all(func(s): return absf(s - 1.0) < 0.001), "their shares add up to the whole multiplier (%s)" % str(shares))
	check(mobs[3].taken == 0 and mobs[3].hits == 0, "the foe 15 m off is left alone")
	check(taken_at_release.all(func(t): return t == 0), "nothing struck before the release")
	var full := 0
	for m in mobs.slice(0, 3):
		full += m.taken
	# The same cast at 1 HP: nothing paid, half the power.
	await _frames()
	for m in mobs:
		m.taken = 0
		m.hits = 0
	Game.profile.hp = 1
	var low := AscendUlt.hero_cast(hero, skill, Vector3.ZERO, mobs[0])
	low.set_process(false)
	check(low.paid == 0 and int(Game.profile.hp) == 1 and not hero.is_dead(), "at 1 HP it takes nothing and the hero lives")
	# The blasts measured at the first cast's HP (the hero's own HP-bound bonuses aside).
	Game.profile.hp = max_hp - paid
	hero.stats.crit = -10.0
	check(is_equal_approx(float(low.factor), 0.5), "and buys half the power (x%.2f)" % float(low.factor))
	_run(low, 2.3)
	var weak := 0
	for m in mobs.slice(0, 3):
		weak += m.taken
	var ratio := float(weak) / maxf(float(full), 1.0)
	print("pact: full HP %d dealt, 1 HP %d dealt: ratio %.3f" % [full, weak, ratio])
	check(ratio > 0.46 and ratio < 0.54, "the damage grows with the HP paid: a 1 HP cast deals half (%.3f)" % ratio)
	await _free_field(field)


func _pact_price() -> void:
	_profile(DL)
	var built := _field([Vector3(3, 0, 0)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	await _frames()
	_ready_hero(hero)
	var skill := ClassData.find_skill(DL, PACT)
	var max_hp := int(hero.stats.max_hp)
	for hp in [max_hp / 2, 7, 4, 2, 1]:
		Game.profile.hp = hp
		var ult := AscendUlt.hero_cast(hero, skill, Vector3.ZERO, null)
		ult.set_process(false)
		var want := int(floor(float(hp) * 0.2))
		check(ult.paid == want and int(Game.profile.hp) == hp - want and int(Game.profile.hp) >= 1 and not hero.is_dead(), "HP %d: pays %d, keeps %d" % [hp, ult.paid, Game.profile.hp])
		if hp == max_hp / 2:
			check(absf(float(ult.factor) - 0.75) < 0.01, "at half HP (10%% of max paid) it buys 0.75 (x%.3f)" % float(ult.factor))
		ult.queue_free()
	await _free_field(field)


func _pact_drink() -> void:
	_profile(DL)
	var built := _field([Vector3(2, 0, 0)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mob: Dummy = built[2][0]
	await _frames()
	_ready_hero(hero)
	var skill := ClassData.find_skill(DL, PACT)
	# The party roles off (the Dark Lord's own เงามืด leech), so only the drink heals.
	ClassRoles.enabled = false
	var healed := func() -> Array:
		Game.profile.hp = int(hero.stats.max_hp) / 2
		var before := int(Game.profile.hp)
		var dealt_before := mob.taken
		hero._deal(mob, 2.0, Color.WHITE, &"dark", false)
		return [int(Game.profile.hp) - before, mob.taken - dealt_before]
	var none: Array = healed.call()
	check(none[0] == 0 and none[1] > 0, "without the pact a hit heals nothing (%s)" % str(none))
	var ult := AscendUlt.hero_cast(hero, skill, Vector3.ZERO, null)
	ult.set_process(false)
	ult.queue_free()
	var first: Array = healed.call()
	check(absf(float(first[0]) - float(first[1]) * 0.2) <= 1.5, "with it a hit heals 20%% of its damage (%d of %d)" % first)
	await _wait(9.3)
	var late: Array = healed.call()
	check(absf(float(late[0]) - float(late[1]) * 0.2) <= 1.5, "still at 9.3 s (%d of %d)" % late)
	await _wait(1.0)
	var after: Array = healed.call()
	check(after[0] == 0, "and no more after 10 s (%d of %d)" % after)
	ClassRoles.enabled = true
	await _free_field(field)


func _pact_freed() -> void:
	_profile(DL)
	var built := _field([Vector3(3, 0, 0), Vector3(0, 0, 4)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mobs: Array = built[2]
	await _frames()
	_ready_hero(hero)
	var skill := ClassData.find_skill(DL, PACT)
	var ult := AscendUlt.hero_cast(hero, skill, Vector3.ZERO, mobs[0])
	ult.set_process(false)
	_run(ult, 0.5)
	var blows: int = ult.blows
	check(blows == 2, "the tide struck both (%d)" % blows)
	hero.free()
	_run(ult, 0.1)
	check(not is_instance_valid(ult) or ult.gone, "the hero freed mid-cast: the pact stops at once")
	await _frames(2)
	check(not is_instance_valid(ult), "and is gone")
	check(mobs.all(func(m): return m.hits == 1), "no blast after it (%s)" % str(mobs.map(func(m): return m.hits)))
	# The hero falling.
	var hero2 := Hero.new()
	hero2.field = field
	field.add_child(hero2)
	hero2.set_physics_process(false)
	await _frames()
	_ready_hero(hero2)
	var second := AscendUlt.hero_cast(hero2, skill, Vector3.ZERO, null)
	second.set_process(false)
	hero2._dead = true
	_run(second, 1.0)
	check(not is_instance_valid(second) or second.gone, "the hero's fall stops it too")
	hero2._dead = false
	await _free_field(field)


# --- ระบำสะกดใจ -----------------------------------------------------------------------------

func _hymn_cast() -> void:
	_profile(BD)
	var spots := [Vector3(6, 0, 0), Vector3(8, 0, 3), Vector3(4, 0, -4), Vector3(7, 0, -2), Vector3(25, 0, 0)]
	var built := _field(spots)
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mobs: Array = built[2]
	var boss: Dummy = mobs[3]
	boss.is_boss = true
	await _frames()
	_ready_hero(hero)
	hero.target = mobs[0]
	var skill := ClassData.find_skill(BD, HYMN)
	# A real cast: the sequence hands over at the release.
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + HYMN) as StarSkillSequence
	check(seq != null, "a real cast starts the star sequence")
	var ult: Node = null
	var waited := 0.0
	while ult == null and waited < 4.0:
		await _frames(1)
		waited += get_process_delta_time()
		ult = _ult(field, HYMN)
	check(ult != null, "the release hands the cast to the dance's script")
	if ult == null:
		await _free_field(field)
		return
	var inside := mobs.slice(0, 4)
	check(inside.all(func(m): return m.hits == 1), "the opening chord strikes every foe on the stage (%s)" % str(mobs.map(func(m): return m.hits)))
	check(mobs[4].hits == 0 and mobs[4]._stun == 0.0 and is_equal_approx(mobs[4].taken_mult(), 1.0), "the foe 19 m off the stage is left alone")
	check(mobs.slice(0, 3).all(func(m): return absf(m._stun - 3.0) < 0.05), "they dance for 3 s (stun %s)" % str(mobs.map(func(m): return snappedf(m._stun, 0.01))))
	check(absf(boss._stun - 1.2) < 0.05, "a boss dances 1.2 s (%.2f)" % boss._stun)
	check(inside.all(func(m): return is_equal_approx(m.taken_mult(), 1.2)), "while dancing they take +20%")
	var notes := ult.find_children("*DanceNote*", "MeshInstance3D", true, false)
	check(notes.size() == 12, "notes and hearts over every dancer (%d)" % notes.size())
	# +20% from any source: a plain 1000 lands as 1200.
	var probe: Dummy = mobs[1]
	var hp0: int = probe.hp
	probe.take_hit(1000, false)
	check(hp0 - probe.hp == 1200, "a hit of 1000 takes 1200 while it dances (%d)" % (hp0 - probe.hp))
	var open_dealt: Array = inside.map(func(m): return m.taken)
	open_dealt[1] -= 1200
	# The dance itself: the bodies bob and twirl.
	var vis: Node3D = mobs[0].visual
	var ys := []
	var yaws := []
	for i in 8:
		await _wait(0.12)
		ys.append(vis.position.y)
		yaws.append(vis.rotation.y)
	check(ys.max() - ys.min() > 0.1 and absf(yaws.back() - yaws.front()) > 0.5, "the dancer bobs (%.2f m) and twirls (%.2f rad)" % [ys.max() - ys.min(), absf(yaws.back() - yaws.front())])
	await _wait(0.6)
	check(is_equal_approx(boss.taken_mult(), 1.0), "the boss's +20%% ends with its 1.2 s dance")
	check(boss.visual.rotation.z == 0.0, "and its body is set straight")
	# The finale, after the dance.
	await _wait(1.9)
	check(bool(ult.finale_done), "the finale lands when the tune ends")
	check(inside.all(func(m): return m.hits >= 2), "the finale strikes every foe on the stage")
	check(inside.all(func(m): return is_equal_approx(m.taken_mult(), 1.0)), "after the dance no more +20%")
	var shares: Array = inside.map(func(m): return float(ult.dealt.get(m.get_instance_id(), 0.0)))
	check(shares.all(func(s): return absf(s - 1.0) < 0.001), "the shares add up to the whole multiplier (%s)" % str(shares))
	var ratios: Array = []
	for i in inside.size():
		var fin: int = inside[i].taken - (open_dealt[i] + (1200 if i == 1 else 0))
		ratios.append(float(open_dealt[i]) / maxf(float(fin), 1.0))
	var mean := 0.0
	for r in ratios:
		mean += r
	mean /= float(ratios.size())
	print("hymn: opening / finale damage ratios %s (0.3 / 0.7 = 0.429)" % str(ratios.map(func(r): return snappedf(r, 0.001))))
	check(absf(mean - 0.3 / 0.7) < 0.05, "opening 30%% and finale 70%%, neither raised by the dance (%.3f)" % mean)
	check(vis.rotation.z == 0.0 and absf(vis.position.y) < 0.001, "the dancers are set straight")
	check(ult.find_children("*DanceNote*", "MeshInstance3D", true, false).is_empty() or not is_instance_valid(ult), "their notes are gone")
	await _wait(1.0)
	check(not is_instance_valid(ult), "the dance ends and frees itself")
	await _free_field(field)


## The dance holds a monster beside the hero: it does not strike while it dances, it does
## once it is let go.
func _hymn_hold() -> void:
	_profile(BD)
	var built := _field([Vector3(1.4, 0, 0)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mob: Dummy = built[2][0]
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	ground.add_child(shape)
	field.add_child(ground)
	ground.position = Vector3(0, -0.5, 0)
	await _frames()
	_ready_hero(hero)
	hero.stats.def = 0.0
	Game.profile.hp = 100000000
	mob.hostile = true
	mob._attack_timer = 0.0
	mob.set_physics_process(true)
	var skill := ClassData.find_skill(BD, HYMN)
	var ult := AscendUlt.hero_cast(hero, skill, mob.global_position, mob)
	check(ult != null and mob._stun > 2.9, "the monster dances")
	var hp0 := int(Game.profile.hp)
	await _wait(2.7)
	check(int(Game.profile.hp) == hp0, "while it dances it never strikes the hero (HP %d -> %d)" % [hp0, Game.profile.hp])
	var struck := false
	for i in 50:
		await _wait(0.1)
		if int(Game.profile.hp) < hp0:
			struck = true
			break
	check(struck, "once the dance is over it strikes again")
	await _free_field(field)


func _hymn_freed() -> void:
	_profile(BD)
	var built := _field([Vector3(5, 0, 0), Vector3(6, 0, 2)])
	var field: Node3D = built[0]
	var hero: Hero = built[1]
	var mobs: Array = built[2]
	await _frames()
	_ready_hero(hero)
	var skill := ClassData.find_skill(BD, HYMN)
	var ult := AscendUlt.hero_cast(hero, skill, mobs[0].global_position, mobs[0])
	await _wait(1.0)
	check(ult.blows == 2 and ult.find_children("*DanceNote*", "MeshInstance3D", true, false).size() == 6, "two dancers under their notes")
	hero.free()
	await _frames(3)
	check(not is_instance_valid(ult), "the hero freed mid-dance: the dance stops at once")
	check(mobs.all(func(m): return m.hits == 1), "no finale after it")
	check(mobs.all(func(m): return m.visual.rotation.z == 0.0 and absf(m.visual.position.y) < 0.001), "the dancers are let go, set straight")
	await _free_field(field)


# --- The AI path (a guild war fighter) -------------------------------------------------------

func _guild_war() -> void:
	_profile(DL)
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
		f._guard_until = 0
	var spot := GuildWarMatch.hero_camp() + Vector3(0, 0, -30)
	var caster: GuildFighter = m.allies[0]
	caster.global_position = spot
	hero.global_position = spot + Vector3(-30, 0, 0)
	var enemies: Array = m.enemies.slice(0, 3)
	for i in enemies.size():
		(enemies[i] as GuildFighter).global_position = spot + Vector3(3.0 + 2.0 * i, 0, -1.0)
		(enemies[i] as GuildFighter).max_hp = 100000000
		(enemies[i] as GuildFighter).hp = 100000000
		(enemies[i] as GuildFighter)._dodge = 0.0
	for f in m.enemies.slice(3):
		f.global_position = GuildWarMatch.hero_camp() + Vector3(0, 0, 80)
	for f in m.allies:
		if f != caster:
			f.global_position = GuildWarMatch.hero_camp() + Vector3(0, 0, 40)
	var hero_hp := int(Game.profile.hp)
	# สัญญาโลหิต by an AI.
	caster.member["class"] = "darklord"
	var pact := ClassData.find_skill(DL, PACT)
	caster.hp = caster.max_hp
	var hp0 := caster.hp
	var before: Array = enemies.map(func(e): return int(e.hp))
	check(AscendUlt.rival_cast(caster, pact, enemies[0].global_position, enemies[0]), "an AI fighter casts the pact by its script")
	var ult := _ult(caster.get_parent(), PACT)
	check(ult != null and not ult.by_hero, "the pact plays on the war's field")
	if ult:
		ult.set_process(false)
		check(ult.paid == int(floor(float(hp0) * 0.2)) and caster.hp == hp0 - ult.paid and caster.hp > 0, "it pays 20%% of its HP (%d of %d)" % [ult.paid, hp0])
		var drink := caster._buff_art.buffs.filter(func(b): return String(b.get("skill_id", "")) == PACT)
		check(drink.size() == 1 and is_equal_approx(float(drink[0].hit_heal), 0.2), "the drink is on the fighter")
		_run(ult, 2.3)
		var hurt := 0
		for i in enemies.size():
			if int(enemies[i].hp) < int(before[i]):
				hurt += 1
		check(hurt == enemies.size() and ult.blows == 3 * enemies.size(), "the other guild's fighters take its three blasts (%d hurt, %d blows)" % [hurt, ult.blows])
		check(int(Game.profile.hp) >= hero_hp, "never its own side")
		# The drink: its hits heal it 20% of their damage.
		ClassRoles.enabled = false
		caster.hp = caster.max_hp / 2
		var foe: GuildFighter = enemies[1]
		foe.hp = foe.max_hp
		var c0 := caster.hp
		var f0 := foe.hp
		caster._hit(foe, 3.0, Color.WHITE, {})
		var gain := caster.hp - c0
		var dealt := f0 - foe.hp
		check(dealt > 0 and absf(float(gain) - float(dealt) * 0.2) <= 1.5, "its hit heals it 20%% of the damage (%d of %d)" % [gain, dealt])
		ClassRoles.enabled = true
		if is_instance_valid(ult):
			ult.queue_free()
	# ระบำสะกดใจ by an AI.
	caster.member["class"] = "bard"
	var hymn := ClassData.find_skill(BD, HYMN)
	for e in enemies:
		e.hp = e.max_hp
		e._stun = 0.0
	before = enemies.map(func(e): return int(e.hp))
	var base_hp: int = enemies[2].hp
	enemies[2]._receive(1000, false, hero)
	var base_took: int = base_hp - enemies[2].hp
	enemies[2].hp = base_hp
	check(AscendUlt.rival_cast(caster, hymn, enemies[1].global_position, enemies[1]), "an AI fighter casts the dance by its script")
	var dance := _ult(caster.get_parent(), HYMN)
	check(dance != null, "the dance plays on the war's field")
	if dance:
		check(enemies.all(func(e): return absf(e._stun - 1.2) < 0.05), "the other guild's fighters dance (a player: 1.2 s) (%s)" % str(enemies.map(func(e): return snappedf(e._stun, 0.01))))
		check(enemies.all(func(e): return is_equal_approx(e.taken_mult(), 1.2)), "and take +20% while they do")
		var foe: GuildFighter = enemies[2]
		var raw_before := foe.hp
		foe._receive(1000, false, hero)
		var took := raw_before - foe.hp
		foe.hp = raw_before
		check(absf(float(took) / float(maxi(base_took, 1)) - 1.2) < 0.01, "a guild fighter takes +20%% from a blow while it dances (%d vs %d)" % [took, base_took])
		var hurt := 0
		for i in enemies.size():
			if int(enemies[i].hp) < int(before[i]):
				hurt += 1
		check(hurt >= 2, "the opening chord strikes them (%d)" % hurt)
		check(not m.allies.any(func(a): return a != caster and a._stun > 0.0) and int(Game.profile.hp) >= hero_hp, "never its own side")
		await _wait(3.6)
		check(not is_instance_valid(dance) or dance.finale_done, "its finale lands")
		check(enemies.all(func(e): return is_equal_approx(e.taken_mult(), 1.0)), "and the +20% is over")
	# The AI casts it for real (Rival._cast -> _resolve at the release).
	caster.mp = 100000.0
	var target: GuildFighter = enemies[0]
	caster._cast(hymn, target)
	await _wait(float(hymn.hit_delay) + 0.4)
	check(_ult(caster.get_parent(), HYMN) != null, "an AI fighter's real cast plays the dance")
	zone.queue_free()
	await _frames(4)
	Game.guildwar_resuming = false
	Game.current_zone = &"meadow"
