extends Node3D
## The Priest's and the Summoner's ★500 ultimates with mechanics of their own (AscendUlt):
##   เทวทูตคุ้มชีวิต (eternal_dawn_judgment, EternalDawnJudgment): the angel's descent strikes
##     every foe in the radius for DESCENT_SHARE; for WARD s a guarded member (the hero, its
##     companions; an AI's own side) who would fall gets up with REVIVE_HP of its HP, once,
##     and a holy explosion (REVIVE_SHARE, at most REVIVE_POOL a foe) bursts round it; the
##     descent and the explosions never pass the whole multiplier on one foe.
##   หลอมรวมอสูร (primordial_beast_court, PrimordialBeastCourt): the caster's summons (never
##     the "ascend_titan") are fed and dismissed; ONE blow on every foe in the radius of
##     BASE_SHARE + FEED_SHARE x min(fed, MAX_FED) of the multiplier.
## Both stop at once when the caster is freed, and an AI player casts them the same way.
##   godot --headless --path . res://tests/integration/ascend_ult_priest_summoner_test.tscn
const STEP := 1.0 / 60.0
const PRIEST := "eternal_dawn_judgment"
const SUMMONER := "primordial_beast_court"
const EPS := 0.0001
var checks := 0
var failures := 0


class RecHero:
	extends Hero
	## Per struck mob: the multipliers of the hero's hits.
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
	Game.new_profile(cls, "Ult QA")
	Game.profile.level = 100
	Game.profile.adv = JobData.ASCEND_ADV
	Game.profile.paragon = {"level": JobData.ASCEND_STARS, "points": JobData.ASCEND_STARS, "spent": 0, "exp": 0, "alloc": {}}
	Game.profile.look = {"gender": 0}
	Game.profile.party = []
	Game.profile.equip = {}
	for slot in ItemData.EQUIP_SLOTS:
		Game.profile.equip[slot] = StarProgression.item(cls, 100 if slot == "wings" else 200, slot, Game.rng)
	Game.profile.hp = 100000
	Game.profile.mp = 100000


func _ready() -> void:
	Game.set_process(false)
	InputSetup.ensure_defaults()
	GameSettings.load_settings()
	GameSettings.quality = 2
	GameSettings.ult_cutin = false
	ZoneData.ensure()
	Game.current_zone = &"meadow"
	_data()
	await _priest_hero()
	await _priest_expiry_and_free()
	await _priest_ai()
	await _summoner_hero()
	await _summoner_free()
	await _summoner_ai()
	await _full_casts()
	Game.has_profile = false
	print("ASCEND ULT PRIEST SUMMONER: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(failures)


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _run(node: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds and is_instance_valid(node) and not bool(node.get("gone")):
		node._process(STEP)
		t += STEP


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	return field


func _hero(field: Node3D, at := Vector3.ZERO) -> RecHero:
	var hero := RecHero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.global_position = at
	hero.refresh_stats()
	hero.stats["dodge"] = 0.0
	Game.profile.hp = int(hero.stats.max_hp)
	return hero


func _mob(field: Node3D, hero: Node3D, at: Vector3) -> Mob:
	var mob := Mob.new()
	mob.setup(&"eclipse_warrior", 100, at, hero)
	mob.position = at
	field.add_child(mob)
	mob.set_physics_process(false)
	mob.hp = 1000000000
	mob.max_hp = mob.hp
	return mob


func _companion(field: Node3D, hero: Hero, who: String, index: int, at: Vector3) -> Companion:
	var c := Companion.new()
	c.setup({"name": who, "class": &"warrior", "level": 100, "stars": 0, "stance": "follow"}, index, hero, field)
	field.add_child(c)
	c.set_physics_process(false)
	c.set_process(false)
	c.global_position = at
	c.stats["dodge"] = 0.0
	return c


## Sum of one mob's logged multipliers, as shares of [param total].
func _shares(log: Dictionary, node: Node, total: float) -> Array:
	var out: Array = []
	for m in log.get(node.get_instance_id(), []):
		out.append(float(m) / total)
	return out


func _sum(list: Array) -> float:
	var s := 0.0
	for v in list:
		s += float(v)
	return s


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


# ---------------------------------------------------------------------------

func _data() -> void:
	for pair in [[&"priest", PRIEST, "เทวทูตคุ้มชีวิต"], [&"summoner", SUMMONER, "หลอมรวมอสูร"]]:
		var ult := ClassData.find_skill(pair[0], pair[1])
		check(not ult.is_empty() and AscendUlt.handles(ult), "%s plays by its own script" % pair[1])
		check(String(ult.name) == pair[2] and String(ult.desc).begins_with("สกิลเทวาลัย • "), "%s: its new Thai name and description (%s)" % [pair[1], ult.name])
		var god: Dictionary = StarSkillData.pool(pair[0])[4]
		check(absf(float(ult.mult) - float(god.mult) * AscendSkillData.ULT_POWER) < 0.001, "%s keeps the Ascension's total multiplier" % pair[1])
	var priest := ClassData.find_skill(&"priest", PRIEST)
	check(String(priest.desc).contains("60%") and String(priest.desc).contains("30%") and String(priest.desc).contains("10 วิ") and String(priest.desc).contains("20%"), "the priest's text names its numbers")
	var summ := ClassData.find_skill(&"summoner", SUMMONER)
	check(String(summ.desc).contains("80%") and String(summ.desc).contains("+10%") and String(summ.desc).contains("120%"), "the summoner's text names its formula")
	check(EternalDawnJudgment.DESCENT_SHARE + EternalDawnJudgment.REVIVE_POOL <= 1.0 + EPS and EternalDawnJudgment.DESCENT_SHARE >= 0.5, "the ward's budget: descent a solid share, all within the total")
	check(_near(PrimordialBeastCourt.share_for(0), 0.8) and _near(PrimordialBeastCourt.share_for(2), 1.0) and _near(PrimordialBeastCourt.share_for(4), 1.2) and _near(PrimordialBeastCourt.share_for(9), 1.2), "the fusion's formula: 0.8 + 0.1 a summon, capped at four")


## The hero's angel: the descent, the saves (once each), the explosions, the budget.
func _priest_hero() -> void:
	profile(&"priest")
	var field := _field()
	var hero := _hero(field)
	var ult := ClassData.find_skill(&"priest", PRIEST)
	var total := float(ult.mult) * hero.rank_mult(ult)
	var aim := Vector3(8, 0, 0)
	var a := _mob(field, hero, aim)
	var b := _mob(field, hero, aim + Vector3(4, 0, 2))
	var far := _mob(field, hero, Vector3(40, 0, 0))
	# Near the party, outside the descent's radius: only the explosions reach it.
	var d := _mob(field, hero, Vector3(-4, 0, 0))
	var c1 := _companion(field, hero, "Buddy QA", 0, Vector3(-3, 0, 1.5))
	var c2 := _companion(field, hero, "Pal QA", 1, Vector3(-3, 0, -1.5))
	await _frames()
	var w := AscendUlt.hero_cast(hero, ult, aim, a) as EternalDawnJudgment
	check(w != null and w.get_parent() == field and w.by_hero, "the hero's cast hands over to the angel on the field")
	if w == null:
		return
	w.set_process(false)
	_run(w, EternalDawnJudgment.DESCEND_AT + 0.05)
	check(w.descended, "the angel descends")
	check(_shares(hero.log, a, total).size() == 1 and _near(_sum(_shares(hero.log, a, total)), EternalDawnJudgment.DESCENT_SHARE), "the descent strikes the aimed foe for 60%% (%s)" % str(_shares(hero.log, a, total)))
	check(_near(_sum(_shares(hero.log, b, total)), EternalDawnJudgment.DESCENT_SHARE), "and every foe in the radius")
	check(not hero.log.has(far.get_instance_id()) and not hero.log.has(d.get_instance_id()), "never a foe outside it")
	check(w.covers(hero) and w.covers(c1) and w.covers(c2) and not w.covers(a), "the hero and its companions are guarded, a monster is not")
	# A companion falls: it gets up at 30%, the explosion strikes round it.
	c1.take_damage(1.0e12, a)
	check(not c1.is_dead() and c1.hp == maxi(1, int(round(float(c1.max_hp) * EternalDawnJudgment.REVIVE_HP))), "a companion's fall is turned into 30%% HP (%d / %d)" % [c1.hp, c1.max_hp])
	await _frames()
	check(_near(_sum(_shares(hero.log, d, total)), EternalDawnJudgment.REVIVE_SHARE), "its holy explosion strikes the foe beside it for 20%%")
	check(_shares(hero.log, a, total).size() == 1, "not the foes far from it")
	c2.take_damage(1.0e12, a)
	await _frames()
	check(not c2.is_dead() and w.saves == 2, "the second companion is saved too")
	check(_near(_sum(_shares(hero.log, d, total)), EternalDawnJudgment.REVIVE_POOL), "a second explosion on the same foe (40%% in all)")
	# The hero falls: saved; its explosion finds the foe's pool spent.
	Game.profile.hp = 10
	hero.take_damage(1.0e12, d)
	check(not hero.is_dead() and int(Game.profile.hp) == maxi(1, int(round(float(hero.stats.max_hp) * EternalDawnJudgment.REVIVE_HP))), "the hero's fall is turned into 30%% HP (%d / %d)" % [int(Game.profile.hp), int(hero.stats.max_hp)])
	await _frames()
	check(w.saves == 3 and _near(_sum(_shares(hero.log, d, total)), EternalDawnJudgment.REVIVE_POOL), "a foe never takes more than 40%% from the explosions")
	for mob in [a, b, d, far]:
		check(_sum(_shares(hero.log, mob, total)) <= 1.0 + EPS, "a foe never takes more than the whole multiplier (%.3f)" % _sum(_shares(hero.log, mob, total)))
	# Once each: the second fall is real.
	c1.take_damage(1.0e12, a)
	check(c1.is_dead() and w.saves == 3, "a companion is saved once a cast: the second fall is real")
	hero._invulnerable_until = 0
	hero.take_damage(1.0e12, d)
	check(hero.is_dead(), "the hero is saved once too")
	_run(w, 0.1)
	check(not is_instance_valid(w) or w.gone, "its caster fallen, the ward ends")
	field.queue_free()
	await _frames(3)


## The ward's 10 s, and its caster freed in the middle of the cast.
func _priest_expiry_and_free() -> void:
	profile(&"priest")
	var field := _field()
	var hero := _hero(field)
	var ult := ClassData.find_skill(&"priest", PRIEST)
	var a := _mob(field, hero, Vector3(6, 0, 0))
	var c := _companion(field, hero, "Late QA", 0, Vector3(-2, 0, 0))
	await _frames()
	var w := AscendUlt.hero_cast(hero, ult, a.global_position, a) as EternalDawnJudgment
	w.set_process(false)
	_run(w, EternalDawnJudgment.WARD + 0.05)
	c.take_damage(1.0e12, a)
	check(c.is_dead() and w.saves == 0, "after 10 s the ward is gone: a fall is real")
	_run(w, EternalDawnJudgment.EXIT + 0.2)
	await _frames()
	check(not is_instance_valid(w), "the angel leaves and the node frees itself")
	# Freed mid-cast: no descent, no ward.
	var hp := a.hp
	var w2 := AscendUlt.hero_cast(hero, ult, a.global_position, a) as EternalDawnJudgment
	w2.set_process(false)
	_run(w2, 0.2)
	hero.queue_free()
	await _frames()
	if is_instance_valid(w2):
		_run(w2, 1.0)
	await _frames()
	check(not is_instance_valid(w2) and a.hp == hp and EternalDawnJudgment.active().is_empty(), "its caster freed mid-cast, it stops at once (no descent)")
	field.queue_free()
	await _frames(3)


func _ai_info(cls: StringName) -> Dictionary:
	profile(cls)
	var p: Dictionary = Game.profile.duplicate(true)
	return {"member": {"class": String(cls), "name": "AI QA", "level": 100}, "profile": p, "look": {"gender": 0},
		"difficulty": 1.0, "mults": {"hp": 1.0, "atk": 1.0, "def": 1.0}}


func _rival(field: Node3D, hero: Hero, cls: StringName, at: Vector3) -> RecRival:
	var info := _ai_info(cls)
	var rival := RecRival.new()
	rival.setup_rival(info, at, hero, "QA")
	field.add_child(rival)
	rival.global_position = at
	rival.set_physics_process(false)
	return rival


## An AI priest's angel: the same descent on its foe, the same save (itself) and explosion.
func _priest_ai() -> void:
	var field := _field()
	var info_rival_at := Vector3(3, 0, 0)
	profile(&"priest")
	var hero := _hero(field)
	Game.profile.hp = 1000000000
	var rival := _rival(field, hero, &"priest", info_rival_at)
	await _frames()
	rival.start_fight()
	rival._dodge = 0.0
	profile(&"priest")
	hero.refresh_stats()
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 1000000000
	var ult := rival._ranked(ClassData.find_skill(&"priest", PRIEST))
	var total := float(ult.mult) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(ult))
	check(AscendUlt.rival_cast(rival, ult, hero.global_position, hero), "an AI priest's cast plays the script")
	var w := field.get_node_or_null("AscendUlt_" + PRIEST) as EternalDawnJudgment
	check(w != null and not w.by_hero, "its angel is on the field")
	if w == null:
		return
	w.set_process(false)
	_run(w, EternalDawnJudgment.DESCEND_AT + 0.05)
	check(_near(_sum(_shares(rival.log, hero, total)), EternalDawnJudgment.DESCENT_SHARE), "its descent strikes the hero for 60%% (%s)" % str(_shares(rival.log, hero, total)))
	check(w.covers(rival) and not w.covers(hero), "it guards its own side, not the hero")
	rival.take_hit(rival.hp + 1000, false, Color.WHITE, hero)
	check(not rival.is_dead() and not rival.duel_over and rival.hp == maxi(1, int(round(float(rival.max_hp) * EternalDawnJudgment.REVIVE_HP))), "the AI's fall is turned into 30%% HP (%d / %d)" % [rival.hp, rival.max_hp])
	await _frames()
	check(_near(_sum(_shares(rival.log, hero, total)), EternalDawnJudgment.DESCENT_SHARE + EternalDawnJudgment.REVIVE_SHARE), "its explosion strikes the hero beside it")
	rival.take_hit(rival.hp + 1000, false, Color.WHITE, hero)
	check(rival.is_dead(), "saved once: the second fall is real")
	_run(w, 0.1)
	check(not is_instance_valid(w) or w.gone, "its fall ends the ward")
	field.queue_free()
	await _frames(3)


func _summon(field: Node3D, owner: Node3D, kind: String, slot: int) -> Summon:
	var s := Summon.new()
	s.setup(owner, "moonwolf_pact", {"kind": kind, "count": 1, "secs": 120.0}, 2.0, slot, 5, 1)
	field.add_child(s)
	s.set_process(false)
	return s


## The hero's fusion: the summons fed (never the Titan) and dismissed, one blow scaled by
## how many.
func _summoner_hero() -> void:
	profile(&"summoner")
	var field := _field()
	var hero := _hero(field)
	var ult := ClassData.find_skill(&"summoner", SUMMONER)
	var total := float(ult.mult) * hero.rank_mult(ult)
	var aim := Vector3(8, 0, 0)
	var a := _mob(field, hero, aim)
	var b := _mob(field, hero, aim + Vector3(5, 0, 3))
	var far := _mob(field, hero, Vector3(40, 0, 0))
	var fed: Array = []
	for i in 3:
		var s := _summon(field, hero, ["wind_king", "poseidon", "wolf"][i], i)
		hero._summons.append(s)
		fed.append(s)
	var titan := _summon(field, hero, "beast", 3)
	titan.set_meta(PrimordialBeastCourt.KEEP_META, true)
	hero._summons.append(titan)
	await _frames()
	var f := AscendUlt.hero_cast(hero, ult, aim, a) as PrimordialBeastCourt
	check(f != null and f.by_hero, "the hero's cast hands over to the fusion")
	if f == null:
		return
	f.set_process(false)
	check(f.fed == 3 and _near(f.share, 1.1), "three summons fed: 80%% + 3 x 10%% = 110%% (%d, %.2f)" % [f.fed, f.share])
	check(hero._summons.size() == 1 and hero._summons[0] == titan and is_instance_valid(titan) and titan.is_in_group("summons"), "the Titan is never fed")
	check(fed.all(func(s): return is_instance_valid(s) and not s.is_in_group("summons") and s.is_dead()), "the fed ones leave the fight at once")
	_run(f, PrimordialBeastCourt.SLAM_AT - 0.1)
	check(hero.log.is_empty(), "no blow before the beast slams")
	await _frames()
	check(fed.all(func(s): return not is_instance_valid(s)), "the fed summons are dismissed when they fuse")
	_run(f, 0.15)
	check(f.struck, "the beast smashes the area")
	check(_shares(hero.log, a, total).size() == 1 and _near(_sum(_shares(hero.log, a, total)), 1.1), "ONE blow on the aimed foe at 110%% (%s)" % str(_shares(hero.log, a, total)))
	check(_shares(hero.log, b, total).size() == 1 and _near(_sum(_shares(hero.log, b, total)), 1.1), "and on every foe in the radius")
	check(not hero.log.has(far.get_instance_id()), "never outside it")
	_run(f, PrimordialBeastCourt.DISSOLVE + 0.1)
	await _frames()
	check(not is_instance_valid(f) and is_instance_valid(titan), "the beast dissolves; the Titan stays")
	# Nothing out: base power.
	titan.queue_free()
	hero._summons.clear()
	hero.log.clear()
	await _frames()
	var f0 := AscendUlt.hero_cast(hero, ult, aim, a) as PrimordialBeastCourt
	f0.set_process(false)
	check(f0.fed == 0 and _near(f0.share, 0.8), "with no summons it still works at 80%%")
	_run(f0, PrimordialBeastCourt.SLAM_AT + 0.05)
	check(_near(_sum(_shares(hero.log, a, total)), 0.8), "its blow lands at 80%%")
	_run(f0, 2.0)
	# Five fed: capped at 120%.
	hero.log.clear()
	for i in 5:
		hero._summons.append(_summon(field, hero, "wolf", i))
	await _frames()
	var f5 := AscendUlt.hero_cast(hero, ult, aim, a) as PrimordialBeastCourt
	f5.set_process(false)
	check(f5.fed == 5 and _near(f5.share, 1.2) and hero._summons.is_empty(), "five fed, the blow capped at 120%%")
	_run(f5, PrimordialBeastCourt.SLAM_AT + 0.05)
	check(_near(_sum(_shares(hero.log, a, total)), 1.2), "its blow lands at 120%%")
	_run(f5, 2.0)
	field.queue_free()
	await _frames(3)


func _summoner_free() -> void:
	profile(&"summoner")
	var field := _field()
	var hero := _hero(field)
	var ult := ClassData.find_skill(&"summoner", SUMMONER)
	var a := _mob(field, hero, Vector3(6, 0, 0))
	var list: Array = []
	for i in 2:
		var s := _summon(field, hero, "wolf", i)
		hero._summons.append(s)
		list.append(s)
	await _frames()
	var hp := a.hp
	var f := AscendUlt.hero_cast(hero, ult, a.global_position, a) as PrimordialBeastCourt
	f.set_process(false)
	_run(f, 0.3)
	hero.queue_free()
	await _frames()
	if is_instance_valid(f):
		_run(f, 2.0)
	await _frames()
	check(not is_instance_valid(f) and a.hp == hp, "its caster freed mid-rush, it stops at once (no blow)")
	check(list.all(func(s): return not is_instance_valid(s)), "the fed summons are dismissed all the same")
	field.queue_free()
	await _frames(3)


## An AI summoner feeds its own creatures (SummonMob) the same way and strikes the hero.
func _summoner_ai() -> void:
	var field := _field()
	profile(&"summoner")
	var hero := _hero(field)
	var rival := _rival(field, hero, &"summoner", Vector3(3, 0, 0))
	await _frames()
	rival.start_fight()
	profile(&"summoner")
	hero.refresh_stats()
	hero.stats["dodge"] = 0.0
	Game.profile.hp = 1000000000
	rival._summon(ClassData.find_skill(&"summoner", "moonwolf_pact"))
	rival._summon(ClassData.find_skill(&"summoner", "eclipse_sovereign"))
	await _frames()
	var mobs := rival._summons.duplicate()
	check(mobs.size() == 2 and mobs.all(func(s): return s is SummonMob), "the AI has two creatures out (%d)" % mobs.size())
	var ult := rival._ranked(ClassData.find_skill(&"summoner", SUMMONER))
	var total := float(ult.mult) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(ult))
	check(AscendUlt.rival_cast(rival, ult, hero.global_position, hero), "an AI summoner's cast plays the script")
	var f := field.get_node_or_null("AscendUlt_" + SUMMONER) as PrimordialBeastCourt
	check(f != null and not f.by_hero and f.fed == mobs.size() and rival._summons.is_empty(), "its creatures are fed (%d)" % (f.fed if f else -1))
	if f == null:
		return
	check(mobs.all(func(s): return not s.is_in_group("mobs")), "nobody can target them any more")
	f.set_process(false)
	_run(f, PrimordialBeastCourt.SLAM_AT + 0.05)
	var want := PrimordialBeastCourt.share_for(mobs.size())
	check(_shares(rival.log, hero, total).size() == 1 and _near(_sum(_shares(rival.log, hero, total)), want), "its one blow strikes the hero at %.0f%% (%s)" % [want * 100.0, str(_shares(rival.log, hero, total))])
	await _frames()
	check(mobs.all(func(s): return not is_instance_valid(s)), "its creatures are dismissed")
	_run(f, 2.0)
	field.queue_free()
	await _frames(3)


## Both through the real casts: the hero's star sequence hands over at the release, an AI's
## _cast -> _resolve does the same.
func _full_casts() -> void:
	for pair in [[&"priest", PRIEST], [&"summoner", SUMMONER]]:
		profile(pair[0])
		var field := _field()
		var hero := _hero(field)
		var mob := _mob(field, hero, Vector3(0, 0, 6))
		hero.target = mob
		if pair[0] == &"summoner":
			hero._summons.append(_summon(field, hero, "wolf", 0))
		await _frames()
		var ult := ClassData.find_skill(pair[0], pair[1])
		hero._cast_now(ult)
		check(hero.has_node("StarCast_" + pair[1]), "%s: the hero's cast plays as a star sequence" % pair[1])
		await get_tree().create_timer(float(ult.hit_delay) + 0.25).timeout
		var node := field.get_node_or_null("AscendUlt_" + pair[1])
		check(node != null, "%s: handed over to its script at the release" % pair[1])
		if pair[0] == &"summoner" and node:
			check(int(node.fed) == 1 and hero._summons.is_empty(), "the wolf is fed")
		await get_tree().create_timer(2.6).timeout
		check(not hero.has_node("StarCast_" + pair[1]), "%s: the star sequence ends" % pair[1])
		# The AI's real cast.
		var rival := _rival(field, hero, pair[0], Vector3(0, 0, 4))
		await _frames()
		rival.start_fight()
		rival.mp = 99999.0
		profile(pair[0])
		hero.refresh_stats()
		Game.profile.hp = 1000000000
		rival._cast(ult, hero)
		await get_tree().create_timer(float(ult.hit_delay) + 2.2).timeout
		var ai_node: Node = null
		for n in field.get_children():
			if String(n.name).begins_with("AscendUlt_" + pair[1]) and n != node and not bool(n.get("by_hero")):
				ai_node = n
		check(ai_node != null or rival.log.has(hero.get_instance_id()), "%s: an AI's real cast plays the script" % pair[1])
		check(rival.log.has(hero.get_instance_id()), "%s: and strikes the hero" % pair[1])
		field.queue_free()
		await _frames(3)
