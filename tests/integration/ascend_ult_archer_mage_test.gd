extends Node
## The archer's and the mage's ★500 ultimates with mechanics of their own (AscendUlt):
##   เลนส์ตะวัน (starfall_emperor_arrow): a 3 s sun beam through a golden lens; it burns
##     everything on its line in 15 ticks, follows its target, swings on when it falls;
##   ประตูมิติร้อยบาน (cosmos_genesis): 6 portals round the area fire 12 volleys of fire,
##     ice and lightning bolts at every enemy in it (burn, slow, a stun on the last).
## A real hero cast hands over to the script at the release; the expected enemies are struck
## (and no other); one held the whole time takes exactly the skill's whole multiplier
## (shares add to 1, damage within rounding of the same blows dealt by hand); the caster
## freed or fallen mid-cast stops it at once and leaves no effect budget; an AI player's
## cast (Rival) plays the same mechanic on its own targets.
##   godot --headless --path . res://tests/integration/ascend_ult_archer_mage_test.tscn

const STEP := 1.0 / 30.0
const ARCHER := "starfall_emperor_arrow"
const MAGE := "cosmos_genesis"
const Lens := preload("res://combat/ascend_ult/starfall_emperor_arrow.gd")
const Gates := preload("res://combat/ascend_ult/cosmos_genesis.gd")
const Kit := preload("res://combat/ascend_ult/_ult_kit.gd")


## A monster that keeps every blow it takes.
class Dummy:
	extends Mob
	var taken := 0
	var hits := 0
	func take_hit(amount: int, crit: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		taken += amount
		hits += 1
		return super.take_hit(amount, crit, color, attacker)


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
	GameSettings.quality = 2
	GameSettings.combat_hitstop = false
	Game.set_process(false)
	_data()
	await _archer_cast()
	await _archer_tracking()
	await _mage_cast()
	await _stops(ARCHER)
	await _stops(MAGE)
	await _rival(&"archer", ARCHER)
	await _rival(&"mage", MAGE)
	Game.has_profile = false
	print("ascend_ult_archer_mage_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ult QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": 500, "points": 0, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.party = []
	Game.profile.equip = {}
	Game.profile.hp = 100000000
	Game.profile.mp = 100000000
	Game.current_zone = &"meadow"


func _data() -> void:
	for pair in [[&"archer", ARCHER, "เลนส์ตะวัน", ["3 วิ", "15 ครั้ง", "0.2 วิ", "20%", "6 วิ"]], [&"mage", MAGE, "ประตูมิติร้อยบาน", ["6 บาน", "12 ระลอก", "3 วิ", "8 ม.", "2 วิ", "1.5 วิ", "มึน 1 วิ"]]]:
		var skill := ClassData.find_skill(pair[0], pair[1])
		check(AscendUlt.handles(skill), "%s plays by its own script" % pair[1])
		check(String(skill.name) == pair[2], "%s is named %s (%s)" % [pair[1], pair[2], skill.name])
		var desc := String(skill.desc)
		check(desc.begins_with("สกิลเทวาลัย • "), "%s: the Ascension prefix" % pair[1])
		for word: String in pair[3]:
			check(desc.contains(word), "%s: the description says %s" % [pair[1], word])
		check(GodSkillArt.signature(String(skill.id)) != null, "%s keeps its wind-up art" % pair[1])
	check(is_equal_approx(AscendUlt.lead(ClassData.find_skill(&"archer", ARCHER)), Lens.DURATION + 0.1), "the archer channels: its cast stays locked while the beam shines")
	check(is_equal_approx(AscendUlt.lead(ClassData.find_skill(&"mage", MAGE)), AscendUlt.LEAD), "the mage's cast frees at the usual lead")
	check(Lens.FIRST_TICK + Lens.TICK * float(Lens.TICKS - 1) < Lens.DURATION, "every burn lands within the beam's 3 s")
	check(Gates.OPEN + Gates.GAP * float(Gates.VOLLEYS - 1) <= 3.1, "the volleys fire over about 3 s")
	check(Gates.element_of(Gates.VOLLEYS - 1) == "lightning", "the last volley is lightning (its stun)")


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	return field


func _hero(field: Node3D) -> Hero:
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = Vector3.ZERO
	return hero


func _mob(field: Node3D, hero: Hero, at: Vector3) -> Dummy:
	var mob := Dummy.new()
	mob.setup(&"dawn_stag", 100, at, hero)
	mob.position = at
	field.add_child(mob)
	mob.set_physics_process(false)
	mob.set_process(false)
	mob.hp = 1000000000
	mob.max_hp = mob.hp
	return mob


## Casts [param id] for real and steps the star sequence to its release; returns the ult node.
func _cast(hero: Hero, cls: StringName, id: String) -> Node:
	var skill := ClassData.find_skill(cls, id)
	hero._cast(skill)
	var seq := hero.get_node_or_null("StarCast_" + id) as StarSkillSequence
	check(seq != null, "%s: a real cast starts the star sequence" % id)
	if seq == null:
		return null
	seq.set_process(false)
	var node: Node = null
	var t := 0.0
	while t < float(skill.hit_delay) + 0.2 and node == null:
		seq._process(STEP)
		t += STEP
		node = hero.field.get_node_or_null("AscendUlt_" + id)
	check(node != null, "%s: the release hands the cast to its script" % id)
	if node:
		node.set_process(false)
	return node


func _run(node: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(node) and not bool(node.get("gone")):
		node._process(STEP)
		t += STEP


## What [param mult] dealt by hand in [param blows] equal blows does to a fresh [param mob].
func _reference(hero: Hero, mob: Dummy, mult: float, blows: int, blow: Dictionary, samples := 8) -> float:
	var total := 0
	var hp := mob.hp
	for s in samples:
		mob.taken = 0
		for b in blows:
			hero._deal(mob, mult / float(blows), Color.WHITE, &"light", false, blow)
		total += mob.taken
		mob.hp = hp
	return float(total) / float(samples)


func _archer_cast() -> void:
	_profile(&"archer")
	var field := _field()
	var hero := _hero(field)
	var mark := _mob(field, hero, Vector3(8, 0, 0))
	var on_line := _mob(field, hero, Vector3(4, 0, 0.4))
	var aside := _mob(field, hero, Vector3(5, 0, 6))
	var behind := _mob(field, hero, Vector3(-5, 0, 0))
	var witness := _mob(field, hero, Vector3(30, 0, 30))
	await _frames()
	hero.refresh_stats()
	hero.stats.crit = -10.0
	hero.target = mark
	var node := _cast(hero, &"archer", ARCHER)
	if node == null:
		field.queue_free()
		return
	var skill: Dictionary = node.skill
	check(is_equal_approx(node.total_mult, float(skill.mult) * hero.rank_mult(skill)), "the beam's whole multiplier is the skill's x its rank's power (%.2f)" % node.total_mult)
	check(node.mark() == mark, "the beam locks on the hero's target")
	check(mark.taken == 0 and on_line.taken == 0, "the release itself strikes nobody (the burns are the beam's)")
	check(node.find_child("SunLens", true, false) != null and node.find_child("Beam", true, false) != null and node.find_child("SkyShaft", true, false) != null, "the hero's beam shows its lens, beam and sky shaft")
	check(hero.visual.position.y < 0.01, "the archer stays on the ground")
	_run(node, 1.0)
	check(node.ticks >= 4 and mark.taken > 0 and on_line.taken > 0, "after 1 s the beam is burning its line (%d burns)" % node.ticks)
	var cast_left := hero._cast_until - Time.get_ticks_msec()
	check(cast_left > 0, "the archer is still channelling (its cast locked)")
	_run(node, Lens.DURATION + Lens.FADE_OUT + 0.5)
	check(not is_instance_valid(node) or bool(node.gone), "the beam goes when its 3 s are up")
	check(is_instance_valid(node) and node.ticks == Lens.TICKS, "all %d burns" % Lens.TICKS)
	if is_instance_valid(node):
		var d: Dictionary = node.dealt
		check(absf(float(d.get(mark.get_instance_id(), 0.0)) - 1.0) < 0.0001, "the mark takes the whole multiplier: shares %.4f" % float(d.get(mark.get_instance_id(), 0.0)))
		check(absf(float(d.get(on_line.get_instance_id(), 0.0)) - 1.0) < 0.0001, "a foe on the line before it burns the whole time too")
		check(int(node.burns.get(mark.get_instance_id(), 0)) == Lens.TICKS and mark.hits == Lens.TICKS, "the mark is burnt %d times (%d hits)" % [Lens.TICKS, mark.hits])
	check(aside.taken == 0 and behind.taken == 0 and witness.taken == 0, "off the line, behind the archer and far away: untouched (%d, %d, %d)" % [aside.taken, behind.taken, witness.taken])
	check(mark._slow > 0.0, "the beam slows what it burns")
	check(mark.debuff_left("shred") > 0.0 if mark.has_method("debuff_left") else true, "the last burn cracks its armour")
	# The damage is the multiplier's, within rounding: the same 15 burns dealt by hand.
	var ref := _mob(field, hero, Vector3(40, 0, -40))
	var blow := Kit.strike(skill, {"slow": Lens.SLOW})
	var expected := _reference(hero, ref, float(node.total_mult) if is_instance_valid(node) else 0.0, Lens.TICKS, blow)
	var ratio := float(mark.taken) / maxf(expected, 1.0)
	print("sun lens: mark took %d vs by hand %.0f (ratio %.3f)" % [mark.taken, expected, ratio])
	check(ratio > 0.94 and ratio < 1.06, "the mark's damage is the whole multiplier's (ratio %.3f)" % ratio)
	field.queue_free()
	await field.tree_exited
	await _frames(3)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no effect budget left behind (%s)" % [VfxBudget.counters()])


func _archer_tracking() -> void:
	_profile(&"archer")
	var field := _field()
	var hero := _hero(field)
	var mark := _mob(field, hero, Vector3(8, 0, 0))
	var next := _mob(field, hero, Vector3(1, 0, 9))
	await _frames()
	hero.refresh_stats()
	var skill := hero._ranked(ClassData.find_skill(&"archer", ARCHER))
	var node := AscendUlt.hero_cast(hero, skill, mark.global_position, mark)
	node.set_process(false)
	_run(node, 0.5)
	check(node.direction().dot(Vector3.RIGHT) > 0.98, "the beam points at its mark")
	var next_before := next.taken
	# The mark walks round: the beam follows it.
	mark.global_position = Vector3(-6, 0, 6)
	_run(node, 0.8)
	var to_mark := Kit.flat(mark.global_position).normalized()
	check(node.direction().dot(to_mark) > 0.97, "the beam re-aims at its mark as it moves (%.2f)" % node.direction().dot(to_mark))
	check(node.on_line(mark), "the mark is on the line again")
	check(next.taken > next_before, "swinging round, the beam burns what it sweeps over")
	# The mark falls: the beam swings to the enemy nearest its end.
	var far := _mob(field, hero, Vector3(14, 0, -14))
	mark.free()
	_run(node, 0.6)
	check(node.mark() == next, "its mark gone, the beam swings on to the nearest enemy (%s)" % node.mark())
	check(node.direction().dot(Kit.flat(next.global_position).normalized()) > 0.95, "and points at it")
	var taken := next.taken
	_run(node, 0.4)
	check(next.taken > taken and far.taken == 0, "and burns it (the farther one untouched)")
	field.queue_free()
	await field.tree_exited
	await _frames(3)


func _mage_cast() -> void:
	_profile(&"mage")
	var field := _field()
	var hero := _hero(field)
	var mark := _mob(field, hero, Vector3(9, 0, 0))
	var near := _mob(field, hero, Vector3(12, 0, 4))
	var near2 := _mob(field, hero, Vector3(6, 0, -5))
	var outside := _mob(field, hero, Vector3(9, 0, 12))
	var at_hero := _mob(field, hero, Vector3(-2, 0, 0))
	await _frames()
	hero.refresh_stats()
	hero.stats.crit = -10.0
	hero.target = mark
	var node := _cast(hero, &"mage", MAGE)
	if node == null:
		field.queue_free()
		return
	var skill: Dictionary = node.skill
	check(Kit.flat(node.center).distance_to(Kit.flat(mark.global_position)) < 0.1, "the portals ring the target's area")
	check(is_equal_approx(node.total_mult, float(skill.mult) * hero.rank_mult(skill)), "the volleys' whole multiplier is the skill's x its rank's power (%.2f)" % node.total_mult)
	var portals := node.find_children("Portal_*", "", true, false)
	check(portals.size() == Gates.PORTALS, "%d portals open (%d)" % [Gates.PORTALS, portals.size()])
	_run(node, 1.0)
	check(node.volleys >= 3 and mark.taken > 0, "after 1 s the portals are firing (%d volleys)" % node.volleys)
	check(node.landed.fire > 0 and node.landed.ice > 0, "fire and ice bolts land in turn")
	check(mark._burn_time > 0.0 or mark._slow > 0.0, "the elements leave their marks (burn %.2f, slow %.2f)" % [mark._burn_time, mark._slow])
	var burn_dps := mark._burn_dps
	_run(node, 3.5)
	check(not is_instance_valid(node) or bool(node.gone), "the portals close when the volleys are done")
	if is_instance_valid(node):
		check(node.volleys == Gates.VOLLEYS, "all %d volleys" % Gates.VOLLEYS)
		for foe in [mark, near, near2]:
			var share := float(node.dealt.get(foe.get_instance_id(), 0.0))
			check(absf(share - 1.0) < 0.0001, "a foe in the area takes the whole multiplier: shares %.4f" % share)
		var count := 3 * Gates.VOLLEYS
		check(node.landed.fire + node.landed.ice + node.landed.lightning == count and node.landed.fire == count / 3 and node.landed.lightning == count / 3, "every bolt lands, a third of each element (%s)" % [node.landed])
	check(mark.hits == Gates.VOLLEYS, "the mark takes one bolt a volley (%d)" % mark.hits)
	check(outside.taken == 0 and at_hero.taken == 0, "outside the area and by the mage: untouched (%d, %d)" % [outside.taken, at_hero.taken])
	check(burn_dps > 0.0, "fire bolts set a burn")
	check(mark._stun > 0.0, "the last lightning volley stuns (%.2f)" % mark._stun)
	# Within rounding of the same 12 bolts dealt by hand.
	var ref := _mob(field, hero, Vector3(40, 0, -40))
	var expected := _reference(hero, ref, float(node.total_mult) if is_instance_valid(node) else 0.0, Gates.VOLLEYS, Kit.strike(skill, {}))
	var ratio := float(mark.taken) / maxf(expected, 1.0)
	print("rift gates: mark took %d vs by hand %.0f (ratio %.3f)" % [mark.taken, expected, ratio])
	check(ratio > 0.94 and ratio < 1.06, "the mark's damage is the whole multiplier's (ratio %.3f)" % ratio)
	field.queue_free()
	await field.tree_exited
	await _frames(3)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "no effect budget left behind (%s)" % [VfxBudget.counters()])


## The caster freed (and, on a second cast, fallen) mid-cast: no blow after, the node gone.
func _stops(id: String) -> void:
	var cls := &"archer" if id == ARCHER else &"mage"
	for how in ["freed", "fallen", "field"]:
		_profile(cls)
		var field := _field()
		var hero := _hero(field)
		var mark := _mob(field, hero, Vector3(8, 0, 0))
		await _frames()
		hero.refresh_stats()
		var skill := hero._ranked(ClassData.find_skill(cls, id))
		var node := AscendUlt.hero_cast(hero, skill, mark.global_position, mark)
		node.set_process(false)
		_run(node, 1.0)
		var taken := mark.taken
		check(taken > 0, "%s: struck before the %s" % [id, how])
		match how:
			"freed":
				hero.free()
			"fallen":
				hero._dead = true
			"field":
				field.queue_free()
				await field.tree_exited
				await _frames(2)
				check(not is_instance_valid(node), "%s: the field freed frees it" % id)
				continue
		_run(node, 0.1)
		check(not is_instance_valid(node) or node._ending >= 0.0, "%s: it stops at once when its caster is %s" % [id, how])
		_run(node, 3.0)
		check(mark.taken == taken, "%s: no blow after its caster is %s (%d -> %d)" % [id, how, taken, mark.taken])
		check(not is_instance_valid(node) or bool(node.gone), "%s: and it goes" % id)
		await _frames(2)
		check(not is_instance_valid(node), "%s: freed (caster %s)" % [id, how])
		field.queue_free()
		await field.tree_exited
		await _frames(3)
		check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s: no effect budget left (%s)" % [id, VfxBudget.counters()])


## An AI player (a duel Rival) casts it on the hero: the same mechanic, its own damage.
func _rival(cls: StringName, id: String) -> void:
	_profile(cls)
	var p: Dictionary = Game.profile.duplicate(true)
	var info := {"member": {"class": String(cls), "name": "Ult AI", "level": 100}, "profile": p, "look": {"gender": 0},
		"difficulty": 1.0, "mults": {"hp": 1.0, "atk": 1.0, "def": 1.0}}
	var field := _field()
	var hero := _hero(field)
	hero.global_position = Vector3(8, 0, 0)
	var rival := Rival.new()
	rival.setup_rival(info, Vector3.ZERO, hero, "QA")
	field.add_child(rival)
	rival.global_position = Vector3.ZERO
	rival.set_physics_process(false)
	await _frames()
	rival.start_fight()
	rival.mp = 99999.0
	hero.refresh_stats()
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 100000000
	var skill := ClassData.find_skill(cls, id)
	var hp := int(Game.profile.hp)
	check(AscendUlt.rival_cast(rival, skill, hero.global_position, hero), "%s: an AI player's cast plays its script" % id)
	var node := field.get_node_or_null("AscendUlt_" + id)
	check(node != null and not node.by_hero, "%s: the AI's node is on its field" % id)
	if node:
		node.set_process(false)
		check(is_equal_approx(node.total_mult, Kit.rival_total(rival, skill)), "%s: the AI's whole multiplier (%.2f) is its skill's, as Rival._resolve" % [id, node.total_mult])
		_run(node, 5.0)
		var share := float(node.dealt.get(hero.get_instance_id(), 0.0))
		check(absf(share - 1.0) < 0.0001, "%s: the hero, held in it, takes the whole multiplier (shares %.4f)" % [id, share])
		check(int(Game.profile.hp) < hp, "%s: the AI's blows hurt the hero (%d -> %d)" % [id, hp, int(Game.profile.hp)])
		check(not is_instance_valid(node) or bool(node.gone), "%s: the AI's cast ends" % id)
	# The AI casts it for real (Rival._cast -> _resolve at the release).
	rival._cast_until = 0
	rival._cast(skill, hero)
	await get_tree().create_timer(float(skill.hit_delay) + 0.4).timeout
	var live := field.get_node_or_null("AscendUlt_" + id)
	check(live != null, "%s: a real AI cast opens it at the release" % id)
	# Its fall stops it.
	if live:
		var before := int(Game.profile.hp)
		rival._dead = true
		await _frames(3)
		check(not is_instance_valid(live) or live._ending >= 0.0, "%s: the AI falling stops it" % id)
		await get_tree().create_timer(0.5).timeout
		check(int(Game.profile.hp) >= before, "%s: no blow after (%d -> %d)" % [id, before, int(Game.profile.hp)])
	field.queue_free()
	await field.tree_exited
	await _frames(3)
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "%s: the AI's cast leaves nothing (%s)" % [id, VfxBudget.counters()])
