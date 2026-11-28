extends Node3D
## The Defender's and the Assassin's ★500 ultimates with mechanics of their own (AscendUlt):
##   กำแพงโล่ถล่ม (eternal_bastion_fall): a wall of shields drives 10 m ahead, strikes and
##   carries what it meets (a boss holds its ground), crushes them at the end; the two hits
##   add up to the whole multiplier times the DEF factor (ATK 50% + DEF 50%, DEF capped at
##   3x ATK), read off the current sheet (a DEF buff raises it);
##   ประหารเลือดพร่อง (timeless_night_execution): a blink behind ONE foe (the target, else
##   the nearest in reach, else none) and one slash: x1 at full HP to x3 under 30%, through
##   all of its DEF.
## Both stop at once when the caster is freed mid-cast, and an AI fighter (Rival) casts the
## same mechanics with the same numbers.
##   godot --headless --path . res://tests/integration/ascend_ult_defender_assassin_test.tscn
const WALL := "eternal_bastion_fall"
const CUT := "timeless_night_execution"
const Wall := preload("res://combat/ascend_ult/eternal_bastion_fall.gd")
const Cut := preload("res://combat/ascend_ult/timeless_night_execution.gd")
var checks := 0
var failures := 0


class RecHero:
	extends Hero
	## Per struck mob: the multipliers of its hits.
	var log := {}
	func _deal(mob: Mob, mult: float, color: Color, vfx: StringName, melee: bool, skill := {}) -> void:
		var key := mob.get_instance_id()
		var list: Array = log.get(key, [])
		list.append(mult)
		log[key] = list
		super._deal(mob, mult, color, vfx, melee, skill)


class RecRival:
	extends Rival
	var log: Array = []
	func _hit(victim: Node3D, mult: float, color: Color, fx := {}) -> void:
		log.append({"victim": victim, "mult": mult})
		super._hit(victim, mult, color, fx)


func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", note)


func profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ult QA")
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": JobData.ASCEND_STARS, "points": JobData.ASCEND_STARS, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000000
	Game.profile.mp = 100000000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	_data()
	await _wall_hero()
	await _wall_def_scaling()
	await _cut_hero()
	await _freed()
	await _ai()
	await get_tree().create_timer(0.6).timeout
	check(VfxBudget.counters() == {"particles": 0, "decorations": 0, "lights": 0}, "the budget is back %s" % VfxBudget.counters())
	Engine.time_scale = 1.0
	Game.has_profile = false
	print("ASCEND ULT DEFENDER/ASSASSIN: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _data() -> void:
	var wall := ClassData.find_skill(&"defender", WALL)
	var cut := ClassData.find_skill(&"assassin", CUT)
	check(AscendUlt.handles(wall) and AscendUlt.handles(cut), "both ultimates play through their own scripts")
	check(String(wall.name) == "กำแพงโล่ถล่ม" and String(cut.name) == "ประหารเลือดพร่อง", "the new names (%s, %s)" % [wall.name, cut.name])
	check(String(wall.desc).begins_with("สกิลเทวาลัย • ") and String(cut.desc).begins_with("สกิลเทวาลัย • "), "the descriptions keep their prefix")
	check(String(wall.desc).contains("10 เมตร") and String(wall.desc).contains("DEF 50%") and String(cut.desc).contains("x3") and String(cut.desc).contains("30%") and String(cut.desc).contains("เจาะเกราะ 100%"), "the descriptions name the numbers")
	check(is_equal_approx(AscendUlt.lead(wall), Wall.LEAD) and is_equal_approx(AscendUlt.lead(cut), Cut.LEAD), "their own cast locks")
	check(is_equal_approx(Wall.CONTACT_SHARE + Wall.CRUSH_SHARE, 1.0), "the wall's two hits share the whole multiplier")
	# The DEF factor: half ATK, half DEF, DEF counted up to 3x ATK.
	check(is_equal_approx(Wall.factor(1000.0, 1000.0), 1.0) and is_equal_approx(Wall.factor(1000.0, 0.0), 0.5) and is_equal_approx(Wall.factor(1000.0, 2000.0), 1.5), "factor = 0.5 + 0.5 DEF/ATK")
	check(is_equal_approx(Wall.factor(1000.0, 1.0e7), 2.0), "DEF is capped at 3x ATK (x2.0 at most)")
	# The HP curve: x1 at full, smooth, x3 at 30% and under.
	check(is_equal_approx(Cut.hp_scale(1.0), 1.0) and is_equal_approx(Cut.hp_scale(0.3), 3.0) and is_equal_approx(Cut.hp_scale(0.05), 3.0), "x1 at full HP, x3 at 30% and under")
	check(is_equal_approx(Cut.hp_scale(0.65), 2.0), "x2 half way (65%%): %.3f" % Cut.hp_scale(0.65))
	var prev := 0.0
	var smooth := true
	for i in 101:
		var v := Cut.hp_scale(1.0 - float(i) / 100.0)
		smooth = smooth and v >= prev - 0.0001 and (i == 0 or v - prev < 0.08)
		prev = v
	check(smooth, "the curve rises steadily with no jump")


func _field(hero_cls: StringName) -> Array:
	profile(hero_cls)
	var field := Node3D.new()
	add_child(field)
	var camera := Camera3D.new()
	field.add_child(camera)
	camera.position = Vector3(4, 18, 14)
	camera.look_at(Vector3(4, 0, 0))
	camera.make_current()
	var hero := RecHero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.position = Vector3.ZERO
	return [field, hero]


func _mob(field: Node3D, hero: Hero, at: Vector3, boss := false) -> Mob:
	var mob := Mob.new()
	mob.setup(&"dawn_stag", 100, at, hero)
	mob.position = at
	field.add_child(mob)
	mob.set_physics_process(false)
	mob.hp = 1000000000
	mob.max_hp = mob.hp
	mob.is_boss = boss
	return mob


func _sum(hero: RecHero, mob: Mob) -> float:
	var total := 0.0
	for m in hero.log.get(mob.get_instance_id(), []):
		total += float(m)
	return total


func _hits(hero: RecHero, mob: Mob) -> int:
	return (hero.log.get(mob.get_instance_id(), []) as Array).size()


## Waits for the ult node [param id] under [param field] to free itself.
func _until_done(field: Node, id: String, limit := 8.0) -> bool:
	var end := Time.get_ticks_msec() + int(limit * 1000.0 / maxf(Engine.time_scale, 0.1))
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		if not is_instance_valid(field) or field.get_node_or_null("AscendUlt_" + id) == null:
			return true
	return false


func _free(field: Node) -> void:
	field.queue_free()
	await field.tree_exited
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# กำแพงโล่ถล่ม on the hero
# ---------------------------------------------------------------------------

func _wall_hero() -> void:
	var parts := _field(&"defender")
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var a := _mob(field, hero, Vector3(3, 0, 0))
	var b := _mob(field, hero, Vector3(6.5, 0, 1.8))
	var side := _mob(field, hero, Vector3(5, 0, 7))
	var behind := _mob(field, hero, Vector3(-3, 0, 0))
	var boss := _mob(field, hero, Vector3(8, 0, -2.8), true)
	var beyond := _mob(field, hero, Vector3(13.5, 0, 0.5))
	hero.target = a
	await get_tree().process_frame
	var skill := hero._ranked(ClassData.find_skill(&"defender", WALL))
	var full := float(skill.mult) * hero.rank_mult(skill)
	var factor := Wall.factor(float(hero.stats.atk), hero.effective_def())
	print("  wall: ATK %.0f DEF %.0f factor %.3f full %.2f" % [float(hero.stats.atk), hero.effective_def(), factor, full])
	Engine.time_scale = 2.0
	hero._cast(ClassData.find_skill(&"defender", WALL))
	check(hero.get_node_or_null("StarCast_" + WALL) != null, "the defender's cast starts")
	await _wait(float(skill.hit_delay) + 0.05)
	check(field.get_node_or_null("AscendUlt_" + WALL) != null, "the wall takes over at the release")
	check(await _until_done(field, WALL), "the wall frees itself when done")
	Engine.time_scale = 1.0
	check(is_equal_approx(float(Wall.last.factor), factor), "the DEF factor is read off the sheet at the release (%.3f)" % float(Wall.last.factor))
	for mob: Mob in [a, b]:
		check(_hits(hero, mob) == 2, "a foe in the lane is struck twice (%d)" % _hits(hero, mob))
		check(absf(_sum(hero, mob) - full * factor) <= full * factor * 0.01, "its hits add up to the whole x DEF factor (%.2f of %.2f)" % [_sum(hero, mob), full * factor])
		check(mob.global_position.x >= Wall.START + Wall.DRIVE - 0.2, "it is carried along to the wall's end (x %.2f)" % mob.global_position.x)
	check(_hits(hero, side) == 0 and side.global_position.is_equal_approx(Vector3(5, 0, 7)), "a foe beside the lane is untouched")
	check(_hits(hero, behind) == 0, "a foe behind the defender is untouched")
	check(_hits(hero, boss) == 2 and boss.global_position.distance_to(Vector3(8, 0, -2.8)) < 0.05, "a boss is struck but holds its ground (%d hits)" % _hits(hero, boss))
	check(_hits(hero, beyond) == 1 and absf(_sum(hero, beyond) - full * factor * Wall.CRUSH_SHARE) <= full * 0.01, "a foe where the shields fall takes the crush only (%d)" % _hits(hero, beyond))
	check(a.hp < a.max_hp, "the hits do damage")
	check(_left(field) == 0, "the wall's art is gone (%d)" % _left(field))
	await _free(field)


func _left(field: Node) -> int:
	var n := 0
	for node in field.get_children():
		if String(node.name).begins_with("Bastion") or String(node.name) in ["ExecutionLine", "BlinkStreak"]:
			n += 1
	return n


## The same wall with more DEF (a buff on the sheet) hits harder, by the factor.
func _wall_def_scaling() -> void:
	var results := []
	for buffed in [false, true]:
		var parts := _field(&"defender")
		var field: Node3D = parts[0]
		var hero: RecHero = parts[1]
		var a := _mob(field, hero, Vector3(3, 0, 0))
		hero.target = a
		await get_tree().process_frame
		if buffed:
			hero.receive_buff({"def": 1.5, "secs": 60.0}, Color.WHITE, "QA", false, "qa_def")
			hero.refresh_stats()
		var skill := hero._ranked(ClassData.find_skill(&"defender", WALL))
		var full := float(skill.mult) * hero.rank_mult(skill)
		var factor := Wall.factor(float(hero.stats.atk), hero.effective_def())
		AscendUlt.hero_cast(hero, skill, hero.global_position, a)
		Engine.time_scale = 2.0
		await _until_done(field, WALL)
		Engine.time_scale = 1.0
		check(absf(_sum(hero, a) - full * factor) <= full * factor * 0.01, "%s: the total is the whole x %.3f" % ["buffed" if buffed else "plain", factor])
		results.append([hero.effective_def(), factor, _sum(hero, a)])
		await _free(field)
	print("  wall DEF %.0f -> x%.3f, DEF %.0f -> x%.3f" % [results[0][0], results[0][1], results[1][0], results[1][1]])
	check(float(results[1][0]) > float(results[0][0]) * 1.5, "the DEF buff raises the sheet's DEF")
	check(float(results[1][2]) > float(results[0][2]) * 1.3 and absf(float(results[1][2]) / float(results[0][2]) - float(results[1][1]) / float(results[0][1])) < 0.01, "more DEF, more damage, by the factor")


# ---------------------------------------------------------------------------
# ประหารเลือดพร่อง on the hero
# ---------------------------------------------------------------------------

func _cut_hero() -> void:
	# The full cast through StarSkillSequence: the aimed foe at full HP, x1.
	var parts := _field(&"assassin")
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var a := _mob(field, hero, Vector3(5, 0, 0))
	var other := _mob(field, hero, Vector3(6, 0, 3))
	hero.target = a
	await get_tree().process_frame
	var skill := hero._ranked(ClassData.find_skill(&"assassin", CUT))
	var full := float(skill.mult) * hero.rank_mult(skill)
	hero._cast(ClassData.find_skill(&"assassin", CUT))
	await _wait(float(skill.hit_delay) + 0.05)
	check(field.get_node_or_null("AscendUlt_" + CUT) != null, "the execution takes over at the release")
	await get_tree().create_timer(0.1).timeout
	check(not hero.visual.visible, "the assassin vanishes")
	check(await _until_done(field, CUT), "the execution frees itself")
	check(hero.visual.visible, "and shows again")
	check(_hits(hero, a) == 1 and absf(_sum(hero, a) - full) <= full * 0.001, "ONE slash on the aimed foe at full HP: x1 (%.2f of %.2f)" % [_sum(hero, a), full])
	check(_hits(hero, other) == 0, "single target: nobody else is hit")
	check(hero.global_position.x > a.global_position.x + 0.5, "the assassin stands behind its foe (x %.2f)" % hero.global_position.x)
	await _free(field)
	# The HP curve on the hit (cast straight at the release).
	for pair in [[0.5, Cut.hp_scale(0.5)], [0.2, 3.0], [0.3, 3.0], [0.9, Cut.hp_scale(0.9)]]:
		parts = _field(&"assassin")
		field = parts[0]
		hero = parts[1]
		a = _mob(field, hero, Vector3(4, 0, 0))
		a.hp = int(float(a.max_hp) * float(pair[0]))
		hero.target = a
		await get_tree().process_frame
		AscendUlt.hero_cast(hero, skill, hero.global_position, a)
		await _until_done(field, CUT)
		check(absf(_sum(hero, a) - full * float(pair[1])) <= full * 0.002, "at %d%% HP: x%.3f (%.2f)" % [int(float(pair[0]) * 100.0), float(pair[1]), _sum(hero, a) / full])
		await _free(field)
	# All of its DEF ignored: an armoured foe takes the slash in full; an ordinary hit on it
	# (the control) is all but stopped.
	parts = _field(&"assassin")
	field = parts[0]
	hero = parts[1]
	a = _mob(field, hero, Vector3(4, 0, 0))
	a.stats.def = 1000000.0
	hero.target = a
	await get_tree().process_frame
	var before := a.hp
	AscendUlt.hero_cast(hero, skill, hero.global_position, a)
	await _until_done(field, CUT)
	var dealt := before - a.hp
	var raw := float(hero.stats.atk) * full * HeroStats.SKILL_POWER
	check(dealt >= int(raw * 0.85), "the slash ignores the foe's DEF (%d of ~%d raw)" % [dealt, int(raw)])
	before = a.hp
	hero._deal(a, full, Color.WHITE, &"light", false, skill)
	check(before - a.hp < int(raw * 0.01), "the control hit without the mark is mitigated (%d)" % (before - a.hp))
	await _free(field)
	# No target: the nearest foe within reach; nothing at all out of reach.
	parts = _field(&"assassin")
	field = parts[0]
	hero = parts[1]
	var near := _mob(field, hero, Vector3(-4, 0, 2))
	var far := _mob(field, hero, Vector3(9, 0, 0))
	hero.target = null
	await get_tree().process_frame
	AscendUlt.hero_cast(hero, skill, hero.global_position, null)
	await _until_done(field, CUT)
	check(_hits(hero, near) == 1 and _hits(hero, far) == 0, "no target: the nearest foe in reach is executed")
	await _free(field)
	parts = _field(&"assassin")
	field = parts[0]
	hero = parts[1]
	far = _mob(field, hero, Vector3(40, 0, 0))
	await get_tree().process_frame
	AscendUlt.hero_cast(hero, skill, hero.global_position, null)
	check(await _until_done(field, CUT), "nobody in reach: the cast still ends")
	check(_hits(hero, far) == 0 and hero.visual.visible and hero.global_position.length() < 0.01, "and hits nobody, the assassin shown in place")
	await _free(field)


# ---------------------------------------------------------------------------
# The caster freed mid-cast; the field freed mid-cast
# ---------------------------------------------------------------------------

func _freed() -> void:
	# The wall: the hero freed while it drives; no hit after, the node and its art gone.
	var parts := _field(&"defender")
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	var a := _mob(field, hero, Vector3(2.5, 0, 0))
	var b := _mob(field, hero, Vector3(9, 0, 0))
	await get_tree().process_frame
	var skill := hero._ranked(ClassData.find_skill(&"defender", WALL))
	AscendUlt.hero_cast(hero, skill, hero.global_position, a)
	await _wait(Wall.RISE + 0.45)
	var a_hp := a.hp
	var b_hp := b.hp
	check(a_hp < a.max_hp, "the wall's face struck the first foe")
	hero.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check(field.get_node_or_null("AscendUlt_" + WALL) == null, "the wall stops at once with its caster gone")
	await _wait(2.0)
	check(a.hp == a_hp and b.hp == b_hp, "no hit after the caster is gone")
	check(_left(field) == 0, "its art goes with it (%d)" % _left(field))
	await _free(field)
	# The execution: the hero freed during the vanish; the foe is never cut.
	parts = _field(&"assassin")
	field = parts[0]
	hero = parts[1]
	a = _mob(field, hero, Vector3(4, 0, 0))
	await get_tree().process_frame
	skill = hero._ranked(ClassData.find_skill(&"assassin", CUT))
	AscendUlt.hero_cast(hero, skill, hero.global_position, a)
	await _wait(0.12)
	hero.queue_free()
	await _wait(0.8)
	check(field.get_node_or_null("AscendUlt_" + CUT) == null and a.hp == a.max_hp, "the execution stops with its caster gone: no slash")
	await _free(field)
	# The field freed mid-cast takes both with it.
	for pair in [[&"defender", WALL], [&"assassin", CUT]]:
		parts = _field(pair[0])
		field = parts[0]
		hero = parts[1]
		a = _mob(field, hero, Vector3(3, 0, 0))
		await get_tree().process_frame
		AscendUlt.hero_cast(hero, hero._ranked(ClassData.find_skill(pair[0], pair[1])), hero.global_position, a)
		await _wait(0.2)
		await _free(field)
		check(get_tree().root.find_children("AscendUlt_*", "", true, false).is_empty(), "%s: nothing outlives its field" % pair[1])


# ---------------------------------------------------------------------------
# An AI fighter casts them
# ---------------------------------------------------------------------------

## An AI fighter's sheet of [param cls] (built before the hero's own profile).
func _info(cls: StringName) -> Dictionary:
	profile(cls)
	return {"member": {"class": String(cls), "name": "QA " + String(cls), "level": 100}, "profile": Game.profile.duplicate(true), "look": {"gender": 0},
		"difficulty": 1.0, "mults": {"hp": 1.0, "atk": 1.0, "def": 1.0}}


func _rival(field: Node3D, hero: Hero, info: Dictionary, at: Vector3) -> RecRival:
	var rival := RecRival.new()
	rival.setup_rival(info, at, hero, "QA")
	field.add_child(rival)
	rival.global_position = at
	rival.set_physics_process(false)
	return rival


func _ai() -> void:
	# The wall: a Rival's drives at the hero and its summon-like foes; the same two shares x
	# its own DEF factor (rstats ATK x its buff, its DEF now).
	var info := _info(&"defender")
	var parts := _field(&"assassin")
	var field: Node3D = parts[0]
	var hero: RecHero = parts[1]
	hero.position = Vector3(4, 0, 0)
	var rival := _rival(field, hero, info, Vector3.ZERO)
	await get_tree().process_frame
	hero.stats["dodge"] = 0.0
	var skill := rival._ranked(ClassData.find_skill(&"defender", WALL))
	var whole := float(skill.mult) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(skill))
	var factor := Wall.factor(float(rival.rstats.atk) * rival._atk_boost, float(rival.stats.def))
	var hp := int(Game.profile.hp)
	rival._resolve(skill, hero, hero.global_position)
	check(field.get_node_or_null("AscendUlt_" + WALL) != null, "an AI fighter's cast plays the wall (Rival._resolve)")
	await _until_done(field, WALL)
	var on_hero := rival.log.filter(func(e): return e.victim == hero)
	var total := 0.0
	for e in on_hero:
		total += float(e.mult)
	check(on_hero.size() == 2 and absf(total - whole * factor) <= whole * factor * 0.01, "its wall strikes the hero twice, the whole x its DEF factor (%d, %.2f of %.2f)" % [on_hero.size(), total, whole * factor])
	check(int(Game.profile.hp) < hp, "the hero is hurt")
	check(hero.global_position.distance_to(Vector3(4, 0, 0)) < 0.05, "a player holds its ground (no carry outside the wars)")
	await _free(field)
	# The execution: a Rival blinks behind the hero at half HP and cuts once, x curve,
	# raised by exactly what the hero's DEF would take off.
	info = _info(&"assassin")
	parts = _field(&"defender")
	field = parts[0]
	hero = parts[1]
	hero.position = Vector3(5, 0, 0)
	rival = _rival(field, hero, info, Vector3.ZERO)
	await get_tree().process_frame
	hero.stats["dodge"] = 0.0
	Game.profile.hp = int(float(hero.stats.max_hp) * 0.5)
	skill = rival._ranked(ClassData.find_skill(&"assassin", CUT))
	whole = float(skill.mult) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(skill))
	var through := Cut.pierce_through(rival, hero)
	print("  AI cut: hero DEF %.0f, after the AI's pierce %.0f" % [hero.effective_def(), ClassRoles.pierced(rival, hero.effective_def())])
	check(is_equal_approx(through, (100.0 + ClassRoles.pierced(rival, hero.effective_def())) / 100.0) and through > 1.5, "the AI's slash is raised past the hero's DEF (x%.2f)" % through)
	check(AscendUlt.rival_cast(rival, skill, hero.global_position, hero), "an AI fighter's cast plays the execution")
	await _until_done(field, CUT)
	check(rival.log.size() == 1 and rival.log[0].victim == hero, "one slash, on the hero only (%d)" % rival.log.size())
	if rival.log.size() == 1:
		var want := whole * Cut.hp_scale(0.5) * through
		check(absf(float(rival.log[0].mult) - want) <= want * 0.01, "x%.3f at half HP, through its DEF (%.2f of %.2f)" % [Cut.hp_scale(0.5), float(rival.log[0].mult), want])
	check(rival.global_position.x > hero.global_position.x + 0.5 and rival.visual.visible, "the AI stands behind the hero, shown again (x %.2f)" % rival.global_position.x)
	# The AI freed mid-cast stops at once.
	var hero_hp := int(Game.profile.hp)
	rival.log.clear()
	AscendUlt.rival_cast(rival, skill, hero.global_position, hero)
	await _wait(0.1)
	rival.queue_free()
	await _wait(0.8)
	check(field.get_node_or_null("AscendUlt_" + CUT) == null and int(Game.profile.hp) >= hero_hp, "an AI's execution stops with its caster gone")
	await _free(field)
