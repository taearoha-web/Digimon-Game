extends Node3D
## The Warrior's and the Lancer's ★500 ultimates with mechanics of their own (AscendUlt):
##   ดาบเหินฟ้า (emperor_heavensword): every foe within 8 m thrown into the air and held
##   there until the slam (a boss stays down, stunned briefly), the warrior leaping after
##   them for four aerial slashes and slamming them all down: 6 blows a foe, the whole
##   multiplier in all; nothing beyond 8 m.
##   หอกพายุบูมเมอแรง (dragon_emperor_lance): the lance out 14 m as a storm and back to the
##   hand: 3 blows a foe each way, the whole multiplier in all for a foe on the path,
##   pulled towards the lancer on the way back (never a boss); nothing off the path or past
##   the reach; the weapon back in hand at the catch.
## Both: stop at once (no further blow, every body back on the ground, the lance gone) when
## the caster is freed mid-cast; an AI player's cast deals the same blows with the same
## total (Rival._hit); the budget is returned.
##   godot --headless --path . res://tests/integration/ascend_ult_warrior_lancer_test.tscn
const WAR := "emperor_heavensword"
const LANCE := "dragon_emperor_lance"
var checks := 0
var failures := 0


class RecHero:
	extends Hero
	var log := {}
	func _deal(mob: Mob, mult: float, color: Color, vfx: StringName, melee: bool, skill := {}) -> void:
		var key := mob.get_instance_id()
		var list: Array = log.get(key, [])
		list.append(mult)
		log[key] = list
		super._deal(mob, mult, color, vfx, melee, skill)


class RecRival:
	extends Rival
	var log := {}
	func _hit(victim: Node3D, mult: float, color: Color, fx := {}) -> void:
		var key := victim.get_instance_id()
		var list: Array = log.get(key, [])
		list.append(mult)
		log[key] = list
		super._hit(victim, mult, color, fx)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ascend QA")
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": JobData.ASCEND_STARS, "points": JobData.ASCEND_STARS, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000000
	Game.profile.mp = 100000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	_data()
	await _warrior()
	await _lancer()
	await _cut_short(&"warrior", WAR)
	await _cut_short(&"lancer", LANCE)
	await _ai(&"warrior", WAR, Vector3(0, 0, 3.0), 6)
	await _ai(&"lancer", LANCE, Vector3(0, 0, 6.0), 6)
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("ASCEND ULT WARRIOR LANCER: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _data() -> void:
	var war := ClassData.find_skill(&"warrior", WAR)
	var lance := ClassData.find_skill(&"lancer", LANCE)
	for s in [war, lance]:
		check(AscendUlt.handles(s), "%s plays by its own script" % s.id)
		check(String(s.desc).begins_with("สกิลเทวาลัย • "), "%s keeps the Ascension prefix" % s.id)
	check(String(war.name) == "ดาบเหินฟ้า" and String(lance.name) == "หอกพายุบูมเมอแรง", "the new Thai names")
	check(String(war.shape) == "burst", "ดาบเหินฟ้า is cast round the warrior (burst)")
	check(String(lance.gesture) == "spear_throw", "หอกพายุบูมเมอแรง winds up as a throw")
	check(String(war.desc).contains("8 เมตร") and String(war.desc).contains("1.5 วิ") and String(war.desc).contains("4"), "the warrior's text tells its numbers")
	check(String(lance.desc).contains("14 เมตร") and String(lance.desc).contains("0.6 เมตร"), "the lancer's text tells its numbers")
	var ws: Script = AscendUlt.script_for(war)
	var ls: Script = AscendUlt.script_for(lance)
	var war_shares := float(ws.LAUNCH_SHARE) + float(ws.AIR_SHARE) * float(ws.AIR_SLASHES) + float(ws.SLAM_SHARE)
	var lance_shares := 0.0
	for x in ls.OUT_SHARES + ls.BACK_SHARES:
		lance_shares += float(x)
	check(absf(war_shares - 1.0) < 0.0001 and absf(lance_shares - 1.0) < 0.0001, "the shares add up to the whole (%.3f, %.3f)" % [war_shares, lance_shares])
	check(is_equal_approx(float(ws.RADIUS), 10.0) and is_equal_approx(float(ws.RADIUS), float(AscendSkillData.pool(&"warrior")[0].radius)) and is_equal_approx(float(ws.AIR), 1.5) and is_equal_approx(float(ls.REACH), 14.0), "10 m (the skill radius, so an AI casts from within reach), 1.5 s in the air, 14 m out")


func _field(cls: StringName, hero_at: Vector3, spots: Array) -> Array:
	profile(cls)
	var field := Node3D.new()
	add_child(field)
	var camera := Camera3D.new()
	field.add_child(camera)
	camera.position = Vector3(0, 18, 16)
	camera.look_at(Vector3(0, 1, 0))
	camera.make_current()
	var hero := RecHero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = hero_at
	var mobs: Array[Mob] = []
	for spot in spots:
		var mob := Mob.new()
		mob.setup(&"dawn_stag", 100, spot, hero)
		mob.position = spot
		field.add_child(mob)
		mob.set_physics_process(false)
		mob.hp = 100000000
		mob.max_hp = mob.hp
		mobs.append(mob)
	hero.target = mobs[0] if not mobs.is_empty() else null
	return [field, hero, mobs]


func _total(list: Array) -> float:
	var t := 0.0
	for m in list:
		t += float(m)
	return t


func _ult(field: Node, id: String) -> Node:
	return field.get_node_or_null("AscendUlt_" + id)


func _close(field: Node3D) -> void:
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "budget back %s" % VfxBudget.counters())


# --- ดาบเหินฟ้า --------------------------------------------------------------------------

func _warrior() -> void:
	# Three foes within 8 m, a boss within 8 m, one at 11 m.
	var parts := _field(&"warrior", Vector3.ZERO, [Vector3(2.0, 0, 0), Vector3(-3.0, 0, 4.0), Vector3(0.5, 0, -6.8), Vector3(4.5, 0, 3.5), Vector3(11.0, 0, 0)])
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var mobs: Array = parts[2]
	var boss: Mob = mobs[3]
	boss.is_boss = true
	var far: Mob = mobs[4]
	await get_tree().process_frame
	var skill := hero._ranked(ClassData.find_skill(&"warrior", WAR))
	var full := float(skill.mult) * hero.rank_mult(skill)
	hero._cast(ClassData.find_skill(&"warrior", WAR))
	Engine.time_scale = 2.0
	var node: Node = null
	var peak := {}
	var hero_peak := 0.0
	var held := 0.0
	var boss_stun := 0.0
	var frames := 0
	var saw := false
	while frames < 4000:
		await get_tree().process_frame
		frames += 1
		node = _ult(field, WAR)
		if node != null:
			if not saw:
				saw = true
				held = mobs[0]._stun
				boss_stun = boss._stun
			for m: Mob in mobs:
				peak[m.get_instance_id()] = maxf(float(peak.get(m.get_instance_id(), 0.0)), m.visual.position.y)
			hero_peak = maxf(hero_peak, hero.visual.position.y)
		elif saw:
			break
	Engine.time_scale = 1.0
	# The slam's own bounce (SkillFeel's throw) settles.
	await get_tree().create_timer(0.7).timeout
	check(saw, "ดาบเหินฟ้า: its script takes the cast at the release")
	for i in 3:
		var m: Mob = mobs[i]
		var list: Array = hero.log.get(m.get_instance_id(), [])
		check(list.size() == 6, "foe %d: launch + 4 aerial + slam = 6 blows (%d)" % [i, list.size()])
		check(absf(_total(list) - full) <= full * 0.01, "foe %d: the blows add up to the whole multiplier (%.3f of %.3f)" % [i, _total(list), full])
		check(float(peak.get(m.get_instance_id(), 0.0)) >= 2.5, "foe %d is thrown into the air (%.2f m)" % [i, float(peak.get(m.get_instance_id(), 0.0))])
		check(is_zero_approx(m.visual.position.y), "foe %d is slammed back down" % i)
	check(held >= 1.4, "a thrown foe cannot act in the air (held %.2f s)" % held)
	var boss_list: Array = hero.log.get(boss.get_instance_id(), [])
	check(boss_list.size() == 6 and absf(_total(boss_list) - full) <= full * 0.01, "the boss takes every blow (%d, %.3f of %.3f)" % [boss_list.size(), _total(boss_list), full])
	check(float(peak.get(boss.get_instance_id(), 0.0)) < 0.01, "the boss stays on the ground")
	check(boss_stun > 0.3 and boss_stun < 1.0, "the boss is only stunned briefly (%.2f s)" % boss_stun)
	check(not hero.log.has(far.get_instance_id()), "nothing beyond 8 m is struck")
	check(hero_peak >= 3.0, "the warrior leaps after them (%.2f m)" % hero_peak)
	check(is_zero_approx(hero.visual.position.y) and not hero.has_meta("star_airborne"), "and lands")
	await _close(field)


# --- หอกพายุบูมเมอแรง --------------------------------------------------------------------

func _lancer() -> void:
	# The lancer faces +X (its target at 4 m): foes along the path, one off it, one past it.
	var parts := _field(&"lancer", Vector3.ZERO, [Vector3(4.0, 0, 0), Vector3(9.0, 0, 0.8), Vector3(13.0, 0, -0.5), Vector3(7.0, 0, 7.0), Vector3(19.0, 0, 0), Vector3(6.0, 0, 0.3)])
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var mobs: Array = parts[2]
	var boss: Mob = mobs[5]
	boss.is_boss = true
	await get_tree().process_frame
	var skill := hero._ranked(ClassData.find_skill(&"lancer", LANCE))
	var full := float(skill.mult) * hero.rank_mult(skill)
	hero._cast(ClassData.find_skill(&"lancer", LANCE))
	Engine.time_scale = 2.0
	var saw := false
	var hidden := false
	var far_out := 0.0
	var frames := 0
	while frames < 4000:
		await get_tree().process_frame
		frames += 1
		var node := _ult(field, LANCE)
		if node != null:
			saw = true
			hidden = hidden or not hero.visual._emission_grip.visible
			far_out = maxf(far_out, Vector2(node.storm_at.x, node.storm_at.z).length())
		elif saw:
			break
	Engine.time_scale = 1.0
	check(saw, "หอกพายุบูมเมอแรง: its script takes the cast at the release")
	check(far_out >= 13.5 and far_out <= 14.6, "the lance flies out 14 m (%.2f)" % far_out)
	for i in [0, 1, 2]:
		var m: Mob = mobs[i]
		var list: Array = hero.log.get(m.get_instance_id(), [])
		check(list.size() == 6, "foe on the path %d: 3 blows out + 3 back (%d)" % [i, list.size()])
		check(absf(_total(list) - full) <= full * 0.01, "foe on the path %d: the whole multiplier (%.3f of %.3f)" % [i, _total(list), full])
		var to_hero := Vector3(-m.global_position.x, 0, -m.global_position.z).normalized()
		check(Vector3(m.velocity.x, 0, m.velocity.z).dot(to_hero) > 0.5, "foe on the path %d is dragged towards the lancer" % i)
	var boss_list: Array = hero.log.get(boss.get_instance_id(), [])
	check(boss_list.size() == 6 and absf(_total(boss_list) - full) <= full * 0.01, "a boss on the path takes every blow (%d)" % boss_list.size())
	check(Vector3(boss.velocity.x, 0, boss.velocity.z).length() < 0.01, "and stands its ground")
	check(not hero.log.has(mobs[3].get_instance_id()), "a foe off the path is not struck")
	check(not hero.log.has(mobs[4].get_instance_id()), "a foe past the reach is not struck")
	check(hidden, "the held lance goes with the throw")
	check(hero.visual._emission_grip.visible, "and is back in hand after the catch")
	await _close(field)


# --- Cut short --------------------------------------------------------------------------

func _cut_short(cls: StringName, id: String) -> void:
	var parts := _field(cls, Vector3.ZERO, [Vector3(2.5, 0, 0), Vector3(5.0, 0, 0.5)])
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var mobs: Array = parts[2]
	await get_tree().process_frame
	var log: Dictionary = hero.log
	hero._cast(ClassData.find_skill(cls, id))
	var frames := 0
	while _ult(field, id) == null and frames < 2000:
		await get_tree().process_frame
		frames += 1
	var node := _ult(field, id)
	check(node != null, "%s: the cast is under way" % id)
	await get_tree().create_timer(0.62).timeout
	var before := 0
	for key in log:
		before += (log[key] as Array).size()
	check(before > 0, "%s: some blows landed before the caster went (%d)" % [id, before])
	hero.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(node) or node.is_queued_for_deletion(), "%s: stops at once with its caster gone" % id)
	await get_tree().create_timer(2.0).timeout
	var after := 0
	for key in log:
		after += (log[key] as Array).size()
	check(after == before, "%s: no blow after the caster is gone (%d -> %d)" % [id, before, after])
	for m: Mob in mobs:
		check(is_zero_approx(m.visual.position.y) and is_zero_approx(m.visual.rotation.x), "%s: every body back on the ground" % id)
	check(field.find_children("StormLance", "", true, false).is_empty(), "%s: nothing of it is left" % id)
	await _close(field)


# --- An AI player's cast -------------------------------------------------------------------

func _ai(cls: StringName, id: String, hero_at: Vector3, blows: int) -> void:
	profile(cls)
	var field := Node3D.new()
	add_child(field)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = hero_at
	var info := {"member": {"class": String(cls), "name": "QA", "level": 100}, "profile": Game.profile.duplicate(true), "look": {"gender": 0},
		"difficulty": 1.0, "mults": {"hp": 1.0, "atk": 1.0, "def": 1.0}}
	var rival := RecRival.new()
	rival.setup_rival(info, Vector3.ZERO, hero, "QA")
	field.add_child(rival)
	rival.global_position = Vector3.ZERO
	rival.set_physics_process(false)
	await get_tree().process_frame
	rival.start_fight()
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 100000000
	var skill := rival._ranked(ClassData.find_skill(cls, id))
	var full := float(skill.mult) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(skill))
	rival._resolve(skill, hero, hero.global_position)
	var node := _ult(field, id)
	check(node != null, "%s: an AI player's cast plays the same script" % id)
	var rival_peak := 0.0
	var hero_peak := 0.0
	var frames := 0
	while is_instance_valid(node) and not node.is_queued_for_deletion() and frames < 4000:
		await get_tree().process_frame
		frames += 1
		rival_peak = maxf(rival_peak, rival.visual.position.y)
		hero_peak = maxf(hero_peak, hero.visual.position.y)
	var list: Array = rival.log.get(hero.get_instance_id(), [])
	check(list.size() == blows, "%s (AI): %d blows on the hero (%d)" % [id, blows, list.size()])
	check(absf(_total(list) - full) <= full * 0.01, "%s (AI): the same whole multiplier (%.3f of %.3f)" % [id, _total(list), full])
	check(hero_peak < 0.01, "%s (AI): a real player is never thrown or held" % id)
	if id == WAR:
		check(rival_peak >= 3.0 and is_zero_approx(rival.visual.position.y), "%s (AI): the AI warrior leaps and lands (%.2f)" % [id, rival_peak])
	await _close(field)
