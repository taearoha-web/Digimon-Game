extends Node3D
## The ★500 Ascension buffs that became mechanics (AscendBuffs), on the hero and on the AI
## (a party companion and a guild war fighter, i.e. Rival._hit / _cast / _tick):
##   warrior  โลหิตราชันเดือด  ATK +100%, 3% max HP lost each second, never below 1 HP
##   archer   ลมหายใจนักล่า    1 s standing still readies a sure crit (+50% crit damage),
##                              a cue shows it; +30% run speed
##   lancer   หอกทะลวงเกราะ    40% of the target's DEF ignored (ClassRoles.pierced)
##   mage     ร่ายซ้ำ          25%: a skill casts again for free; no chain, no ★500, no buff
##   assassin ล่าต่อเนื่อง      a kill dashes to the nearest enemy in 10 m (walls stop it),
##                              the next hit on it is a sure crit; 0.3 s between dashes
##   godot --headless --path . res://tests/integration/ascend_buffs_a_test.tscn
var failures := 0
var checks := 0


class RecordingMob extends Mob:
	var hits: Array = [] # [amount, crit]
	func take_hit(amount: int, critical: bool, color := Color.WHITE, attacker: Node = null) -> bool:
		hits.append([amount, critical])
		return super.take_hit(amount, critical, color, attacker)
	func knock_back(_from: Vector3, _strength := 2.5) -> void:
		pass


## A guild fighter that records the raw blows it takes (and can be told to fall).
class RecFighter extends GuildFighter:
	var raws: Array = []
	var fall := false
	func take_damage(raw: float, _attacker: Node = null) -> void:
		raws.append(raw)
		if fall:
			hp = 0
			_dead = true


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
	else:
		print("  ok: ", message)


func _ready() -> void:
	ClassRoles.enabled = false
	Game.set_process(false)
	WorldEvents.festival_enabled = false
	await get_tree().process_frame
	_data()
	await _warrior()
	await _archer()
	await _lancer()
	await _mage()
	await _assassin()
	print("ASCEND BUFFS A: %s | %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


static func buff_skill(cls: StringName) -> Dictionary:
	return ClassData.find_skill(cls, String(AscendSkillData.IDS[cls][1]))


func _data() -> void:
	var want := {
		&"warrior": [{"atk": 1.0, "drain": 0.03}, "โลหิตราชันเดือด", ["+100%", "3%", "HP 1"]],
		&"archer": [{"still_shot": 0.5, "speed": 0.3}, "ลมหายใจนักล่า", ["1 วิ", "+50%", "+30%"]],
		&"lancer": [{"armor_pen": 0.4}, "หอกทะลวงเกราะ", ["40%"]],
		&"mage": [{"echo": 0.25}, "ร่ายซ้ำ", ["25%"]],
		&"assassin": [{"hunt": 10.0}, "ล่าต่อเนื่อง", ["10 เมตร", "0.3 วิ"]],
	}
	for cls in want:
		var skill := buff_skill(cls)
		var buff: Dictionary = skill.fx.buff.duplicate()
		check(float(buff.secs) == 60.0, "%s buff lasts 60 s" % cls)
		buff.erase("secs")
		check(buff == want[cls][0], "%s buff is the mechanic only %s" % [cls, JSON.stringify(buff)])
		check(String(skill.name) == want[cls][1], "%s buff is named %s" % [cls, want[cls][1]])
		for n in want[cls][2]:
			check(String(skill.desc).begins_with("สกิลเทวาลัย • ") and String(skill.desc).contains(n), "%s desc says %s" % [cls, n])


func _profile(cls: StringName) -> void:
	Game.new_profile(cls, "Ascend QA", FaceKit.default_look())
	Game.profile.level = 100
	Game.profile.adv = 4
	Game.profile.hp = 99999
	Game.profile.mp = 99999


func _field() -> Node3D:
	var field := Node3D.new()
	add_child(field)
	return field


func _hero(cls: StringName, field: Node3D) -> Hero:
	_profile(cls)
	var hero := Hero.new()
	hero.field = field
	field.add_child(hero)
	hero.set_physics_process(false)
	hero.refresh_stats()
	Game.profile.hp = int(hero.stats.max_hp)
	return hero


func _cast_buff(hero: Hero, cls: StringName) -> void:
	var skill := buff_skill(cls)
	hero.receive_buff(skill.fx.buff, skill.color, skill.name, false, skill.id)


func _mob(field: Node3D, hero: Node3D, at: Vector3, hp := 10000000) -> RecordingMob:
	var mob := RecordingMob.new()
	mob.setup(&"pink_slime", 1, at, hero)
	field.add_child(mob)
	mob.global_position = at
	mob.hp = hp
	mob.max_hp = maxi(hp, 1)
	mob.stats.def = 0.0
	mob.set_physics_process(false)
	return mob


func _companion(cls: StringName, hero: Hero, field: Node3D) -> Companion:
	var c := Companion.new()
	c.setup({"class": String(cls), "name": "QA " + String(cls), "level": 100, "exp": 0, "gender": 0}, 0, hero, field)
	field.add_child(c)
	c.set_physics_process(false)
	c.stats.crit = 0.0
	c.mp = 100000.0
	var skill := buff_skill(cls)
	c._apply_self(skill)
	return c


func _fighter(cls: StringName, team: int, at: Vector3, hero: Node3D, seed_value: int, rec := false) -> GuildFighter:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var f: GuildFighter = RecFighter.new() if rec else GuildFighter.new()
	f.setup_fighter(GuildWarData.make_fighter(cls, 2, "QA %s %d" % [cls, seed_value], rng), team, hero, at, "[QA]")
	add_child(f)
	f.set_physics_process(false)
	f.global_position = at
	f._frozen = false
	f.rstats["crit"] = 0.0
	f._buff_crit = 0.0
	return f


func _fighter_buff(f: GuildFighter, cls: StringName) -> void:
	f._resolve(buff_skill(cls), null, Vector3.ZERO)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


# --- warrior --------------------------------------------------------------------

func _warrior() -> void:
	var field := _field()
	var hero := _hero(&"warrior", field)
	var base_atk := float(hero.stats.atk)
	_cast_buff(hero, &"warrior")
	var ratio := float(hero.stats.atk) / base_atk
	check(ratio > 1.9 and ratio < 2.1, "warrior hero: ATK x%.2f (+100%%)" % ratio)
	var max_hp := int(hero.stats.max_hp)
	Game.profile.hp = max_hp
	AscendBuffs.tick(hero, 1.0)
	var lost := max_hp - int(Game.profile.hp)
	check(absi(lost - int(max_hp * 0.03)) <= 1, "warrior hero: 1 s drains 3%% of max HP (%d of %d)" % [lost, max_hp])
	var before := int(Game.profile.hp)
	hero._tick_timers(0.5)
	check(int(Game.profile.hp) < before, "warrior hero: the drain runs in the hero's own frame")
	Game.profile.hp = 5
	AscendBuffs.tick(hero, 1.0)
	check(int(Game.profile.hp) == 1, "warrior hero: the drain stops at 1 HP (%d)" % int(Game.profile.hp))
	for i in 5:
		AscendBuffs.tick(hero, 1.0)
	check(int(Game.profile.hp) == 1 and not hero.is_dead(), "warrior hero: never kills")
	# The AI: a party companion and a guild war fighter.
	var buddy := _companion(&"warrior", hero, field)
	check(absf(buddy._buffed_atk() / float(buddy.stats.atk) - 2.0) < 0.01, "warrior companion: ATK x2")
	buddy.hp = buddy.max_hp
	AscendBuffs.tick(buddy, 1.0)
	check(absi(buddy.max_hp - buddy.hp - int(buddy.max_hp * 0.03)) <= 1, "warrior companion: drains 3%%/s (%d of %d)" % [buddy.max_hp - buddy.hp, buddy.max_hp])
	buddy.hp = 3
	for i in 4:
		AscendBuffs.tick(buddy, 1.0)
	check(buddy.hp == 1 and not buddy.is_dead(), "warrior companion: stops at 1 HP")
	var f := _fighter(&"warrior", GuildFighter.TEAM_ALLY, Vector3(30, 0, 0), hero, 3)
	_fighter_buff(f, &"warrior")
	check(BuffBook.contains(f._buff_art.buffs, "sovereign_awakening", false) and is_equal_approx(f._atk_boost, 2.0), "warrior fighter: buff on, ATK x2")
	f.hp = f.max_hp
	f._tick(1.0)
	check(absi(f.max_hp - f.hp - int(f.max_hp * 0.03)) <= 1, "warrior fighter: its own frame drains 3%%/s (%d of %d)" % [f.max_hp - f.hp, f.max_hp])
	f.hp = 2
	for i in 4:
		f._tick(1.0)
	check(f.hp == 1 and not f.is_dead(), "warrior fighter: stops at 1 HP")
	f.queue_free()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- archer ---------------------------------------------------------------------

func _still(unit: Node3D, secs: float) -> void:
	var steps := int(ceil(secs / 0.25))
	for i in steps:
		AscendBuffs.tick(unit, 0.25)


func _archer() -> void:
	var field := _field()
	var hero := _hero(&"archer", field)
	var base_speed := float(hero.stats.speed)
	_cast_buff(hero, &"archer")
	# Speed buffs add to the base walking speed (HeroStats.MOVE_SPEED x (1 + buffs + gear)).
	check(absf(float(hero.stats.speed) - base_speed - HeroStats.MOVE_SPEED * 0.3) < 0.02, "archer hero: run speed +30%% of the base (%.2f -> %.2f)" % [base_speed, float(hero.stats.speed)])
	hero.stats.crit = 0.0
	var mob := _mob(field, hero, Vector3(4, 0, 0))
	hero.target = mob
	AscendBuffs.tick(hero, 0.25)
	_still(hero, 0.5)
	hero.global_position += Vector3(0, 0, 1.0)
	AscendBuffs.tick(hero, 0.25)
	_still(hero, 0.75)
	check(not AscendBuffs.primed(hero), "archer hero: a step resets the aim")
	_still(hero, 0.5)
	check(AscendBuffs.primed(hero), "archer hero: 1 s still readies the shot")
	await get_tree().process_frame
	var cue: Node3D = null
	for child in hero.get_children():
		if child is AscendBuffs.ReadyCue:
			cue = child
	check(cue != null and cue.visible, "archer hero: the ready cue shows")
	hero._deal(mob, 1.0, Color.WHITE, &"slash", false)
	hero._deal(mob, 1.0, Color.WHITE, &"slash", false)
	check(mob.hits.size() == 2 and bool(mob.hits[0][1]) and not bool(mob.hits[1][1]), "archer hero: the readied hit crits, the next does not")
	var want := hero.crit_mult() + 0.5
	var r := float(mob.hits[0][0]) / maxf(1.0, float(mob.hits[1][0]))
	check(r > want * 0.82 and r < want * 1.2, "archer hero: crit damage +50%% (x%.2f, want ~x%.2f)" % [r, want])
	await get_tree().process_frame
	check(cue == null or not is_instance_valid(cue) or not cue.visible, "archer hero: the cue goes once fired")
	_still(hero, 1.0)
	var skill := ClassData.find_skill(&"archer", String(ClassData.pool(&"archer").filter(func(s): return String(s.shape) == "single" and not s.has("star"))[0].id))
	hero._deal(mob, 1.0, skill.color, skill.vfx, false, skill)
	check(bool(mob.hits[-1][1]), "archer hero: a skill hit takes the readied shot too")
	# Companion.
	var buddy := _companion(&"archer", hero, field)
	check(is_equal_approx(AscendBuffs.run_mult(buddy), 1.3), "archer companion: +30% run speed")
	AscendBuffs.tick(buddy, 0.25)
	_still(buddy, 1.0)
	check(AscendBuffs.primed(buddy), "archer companion: readies")
	buddy._deal(mob, 1.0, Color.WHITE, &"slash", false, null)
	check(bool(mob.hits[-1][1]), "archer companion: sure crit")
	# Guild war fighter.
	var f := _fighter(&"archer", GuildFighter.TEAM_ENEMY, Vector3(30, 0, 0), hero, 4)
	var foe: RecFighter = _fighter(&"warrior", GuildFighter.TEAM_ALLY, Vector3(34, 0, 0), hero, 5, true)
	_fighter_buff(f, &"archer")
	check(is_equal_approx(AscendBuffs.run_mult(f), 1.3), "archer fighter: +30% run speed (Mob chase)")
	f._tick(0.25)
	for i in 4:
		f._tick(0.25)
	check(AscendBuffs.primed(f), "archer fighter: readies in its own frame")
	f._hit(foe, 1.0, Color.WHITE)
	f._hit(foe, 1.0, Color.WHITE)
	var fr := float(foe.raws[0]) / maxf(1.0, float(foe.raws[1]))
	var fwant := HeroStats.CRIT_DAMAGE + 0.5
	check(foe.raws.size() == 2 and fr > fwant * 0.82 and fr < fwant * 1.2, "archer fighter: sure crit +50%% (x%.2f, want ~x%.2f)" % [fr, fwant])
	f.queue_free()
	foe.queue_free()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- lancer ---------------------------------------------------------------------

func _lancer() -> void:
	var field := _field()
	var hero := _hero(&"lancer", field)
	check(is_equal_approx(ClassRoles.pierced(hero, 1000.0), 1000.0), "lancer hero: no pen without the buff")
	_cast_buff(hero, &"lancer")
	check(is_equal_approx(ClassRoles.pierced(hero, 1000.0), 600.0), "lancer hero: 40%% of DEF ignored (%.0f)" % ClassRoles.pierced(hero, 1000.0))
	hero.stats.crit = 0.0
	var mob := _mob(field, hero, Vector3(3, 0, 0))
	mob.stats.def = float(hero.stats.atk) * 2.0
	var with_pen := 0.0
	var without := 0.0
	for i in 6:
		hero._deal(mob, 1.0, Color.WHITE, &"slash", false)
		with_pen += float(mob.hits[-1][0])
	hero._buffs.clear()
	hero.refresh_stats()
	hero.stats.crit = 0.0
	for i in 6:
		hero._deal(mob, 1.0, Color.WHITE, &"slash", false)
		without += float(mob.hits[-1][0])
	check(with_pen > without * 1.15, "lancer hero: hits land harder through armour (%.0f vs %.0f)" % [with_pen, without])
	hero.set_meta(AscendBuffs.META_PEN, 1.0)
	check(is_equal_approx(ClassRoles.pierced(hero, 1000.0), 0.0), "a skill's META_PEN 1.0 ignores all DEF (shared armor_pen)")
	hero.remove_meta(AscendBuffs.META_PEN)
	var buddy := _companion(&"lancer", hero, field)
	check(is_equal_approx(ClassRoles.pierced(buddy, 1000.0), 600.0), "lancer companion: 40% pen")
	var f := _fighter(&"lancer", GuildFighter.TEAM_ENEMY, Vector3(30, 0, 0), hero, 6)
	_fighter_buff(f, &"lancer")
	check(is_equal_approx(ClassRoles.pierced(f, 1000.0), 600.0), "lancer fighter: 40% pen (the hero's and fighters' take_damage read it)")
	f.queue_free()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- mage -----------------------------------------------------------------------

func _force_echo(list: Array, chance: float) -> void:
	for b in list:
		if b.has("echo"):
			b.echo = chance


func _mage() -> void:
	var field := _field()
	var hero := _hero(&"mage", field)
	_cast_buff(hero, &"mage")
	_force_echo(hero._buffs, 1.0)
	var mob := _mob(field, hero, Vector3(5, 0, 0))
	hero.target = mob
	var bolt := ClassData.find_skill(&"mage", "fire_bolt")
	var ult := ClassData.find_skill(&"mage", String(AscendSkillData.IDS[&"mage"][0]))
	check(AscendBuffs.echoes(bolt) and not AscendBuffs.echoes(ult) and not AscendBuffs.echoes(buff_skill(&"mage")) and not AscendBuffs.echoes(ClassData.find_skill(&"mage", "enchant_weapon")), "mage: attacks echo; the ★500 ultimate and buffs never")
	check(not AscendBuffs.roll_echo(hero, ult) and not AscendBuffs.roll_echo(hero, buff_skill(&"mage")), "mage: no echo queued for the ultimate or a buff even at 100%")
	Game.profile.mp = 50000
	var mp0 := int(Game.profile.mp)
	hero._cast_now(bolt)
	var paid := mp0 - int(Game.profile.mp)
	check(paid == hero.mp_cost(bolt), "mage hero: the cast pays once (%d)" % paid)
	var cd := float(hero.cooldowns.get(bolt.id, 0.0))
	await _wait(2.5)
	check(mob.hits.size() == 2, "mage hero: the skill landed twice: cast + echo (%d hits)" % mob.hits.size())
	check(mp0 - int(Game.profile.mp) == paid and is_equal_approx(float(hero.cooldowns.get(bolt.id, 0.0)), cd), "mage hero: the echo costs no MP and no cooldown")
	await _wait(1.5)
	check(mob.hits.size() == 2, "mage hero: an echo never echoes")
	# At 25%: about a quarter of the casts queue an echo.
	_force_echo(hero._buffs, 0.25)
	var queued := 0
	seed(7)
	for i in 400:
		if AscendBuffs.roll_echo(hero, bolt):
			queued += 1
	check(queued > 70 and queued < 130, "mage: 25%% echo chance (%d / 400)" % queued)
	await _wait(0.5)
	# Companion.
	var buddy := _companion(&"mage", hero, field)
	_force_echo(buddy._book.buffs, 1.0)
	var mob2 := _mob(field, hero, Vector3(-5, 0, 0))
	buddy.target = mob2
	var bmp := buddy.mp
	buddy._cast(bolt)
	await _wait(2.5)
	check(mob2.hits.size() == 2 and is_equal_approx(bmp - buddy.mp, float(bolt.mp)), "mage companion: cast + free echo (%d hits, MP %.0f)" % [mob2.hits.size(), bmp - buddy.mp])
	# Guild war fighter.
	var f := _fighter(&"mage", GuildFighter.TEAM_ENEMY, Vector3(30, 0, 0), hero, 7)
	var foe: RecFighter = _fighter(&"warrior", GuildFighter.TEAM_ALLY, Vector3(35, 0, 0), hero, 8, true)
	_fighter_buff(f, &"mage")
	_force_echo(f._buff_art.buffs, 1.0)
	f.mp = 100000.0
	var fmp := f.mp
	f._cast(bolt, foe)
	await _wait(3.0)
	check(foe.raws.size() == 2, "mage fighter: cast + echo (%d blows)" % foe.raws.size())
	check(is_equal_approx(fmp - f.mp, f.skill_mp(bolt)) and int(f.casts.get("fire_bolt", 0)) == 1, "mage fighter: the echo is free (MP %.0f, casts %d)" % [fmp - f.mp, int(f.casts.get("fire_bolt", 0))])
	f.queue_free()
	foe.queue_free()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# --- assassin -------------------------------------------------------------------

func _dashes(unit: Node) -> int:
	var n := 0
	for child in unit.get_children():
		if child is AscendBuffs.HuntDash and not child.is_queued_for_deletion():
			n += 1
	return n


func _assassin() -> void:
	var field := _field()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	field.add_child(floor_body)
	var hero := _hero(&"assassin", field)
	hero.global_position = Vector3.ZERO
	_cast_buff(hero, &"assassin")
	hero.stats.crit = 0.0
	var prey := _mob(field, hero, Vector3(1.2, 0, 0), 1)
	var next := _mob(field, hero, Vector3(7, 0, 0))
	var far := _mob(field, hero, Vector3(0, 0, -30))
	hero._deal(prey, 5.0, Color.WHITE, &"slash", true)
	check(prey.is_dead(), "assassin hero: the kill")
	check(hero.target == next and _dashes(hero) == 1, "assassin hero: the kill sends a dash at the nearest enemy in 10 m (dead %s hunt %.0f hero %s next %s %s)" % [hero.is_dead(), AscendBuffs.value(hero, "hunt"), hero.global_position, next.global_position, next.is_dead()])
	var other := _mob(field, hero, Vector3(-1.2, 0, 0), 1)
	hero._deal(other, 5.0, Color.WHITE, &"slash", true)
	check(other.is_dead() and _dashes(hero) == 1, "assassin hero: a second kill within 0.3 s sends no second dash")
	await _wait(0.45)
	var gap := Vector2(next.global_position.x - hero.global_position.x, next.global_position.z - hero.global_position.z).length()
	check(gap < 2.6 and gap > 0.8, "assassin hero: dashed up to it, not into it (%.2f m left)" % gap)
	hero._deal(next, 0.01, Color.WHITE, &"slash", false)
	hero._deal(next, 0.01, Color.WHITE, &"slash", false)
	check(bool(next.hits[-2][1]) and not bool(next.hits[-1][1]), "assassin hero: the next hit on it is a sure crit, once")
	# Out of reach: nobody within 10 m, no dash.
	await _wait(0.4)
	next.global_position = Vector3(40, 0, 40)
	var lone := _mob(field, hero, hero.global_position + Vector3(1, 0, 0), 1)
	hero._deal(lone, 5.0, Color.WHITE, &"slash", true)
	check(_dashes(hero) == 0, "assassin hero: no enemy within 10 m, no dash (far one at 30 m)")
	# A wall stops the dash.
	await _wait(0.4)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.4, 4, 8)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	field.add_child(wall)
	var start := hero.global_position
	wall.global_position = start + Vector3(3, 2, 0)
	var behind := _mob(field, hero, start + Vector3(8, 0, 0))
	var victim := _mob(field, hero, start + Vector3(-1, 0, 0), 1)
	far.global_position = Vector3(-60, 0, -60)
	await get_tree().physics_frame
	hero._deal(victim, 5.0, Color.WHITE, &"slash", true)
	check(hero.target == behind, "assassin hero: aims at the one behind the wall")
	await _wait(0.45)
	check(hero.global_position.x - start.x < 3.0, "assassin hero: the wall stops the dash (x %.2f, wall at %.2f)" % [hero.global_position.x - start.x, 3.0])
	# Companion.
	var buddy := _companion(&"assassin", hero, field)
	buddy.global_position = Vector3(20, 0, 20)
	var cprey := _mob(field, hero, Vector3(21, 0, 20), 1)
	var cnext := _mob(field, hero, Vector3(25, 0, 20))
	buddy._deal(cprey, 5.0, Color.WHITE, &"slash", true, null)
	check(buddy.target == cnext and _dashes(buddy) == 1, "assassin companion: kill -> dash at the next")
	await _wait(0.4)
	buddy._deal(cnext, 0.01, Color.WHITE, &"slash", false, null)
	check(bool(cnext.hits[-1][1]), "assassin companion: sure crit on it")
	# Guild war fighter.
	var f := _fighter(&"assassin", GuildFighter.TEAM_ENEMY, Vector3(-40, 0, 40), hero, 9)
	var fprey: RecFighter = _fighter(&"warrior", GuildFighter.TEAM_ALLY, Vector3(-39, 0, 40), hero, 10, true)
	var fnext: RecFighter = _fighter(&"warrior", GuildFighter.TEAM_ALLY, Vector3(-34, 0, 40), hero, 11, true)
	hero.global_position = Vector3(60, 0, -60)
	_fighter_buff(f, &"assassin")
	fprey.fall = true
	await get_tree().process_frame
	f._hit(fprey, 1.0, Color.WHITE)
	check(fprey.is_dead() and f._victim == fnext and _dashes(f) == 1, "assassin fighter: kill -> dash at the next foe")
	await _wait(0.4)
	var fgap := Vector2(fnext.global_position.x - f.global_position.x, fnext.global_position.z - f.global_position.z).length()
	check(fgap < 3.0, "assassin fighter: dashed in (%.2f m)" % fgap)
	f._hit(fnext, 1.0, Color.WHITE)
	f._hit(fnext, 1.0, Color.WHITE)
	var ratio := float(fnext.raws[0]) / maxf(1.0, float(fnext.raws[1]))
	check(fnext.raws.size() == 2 and ratio > HeroStats.CRIT_DAMAGE * 0.82, "assassin fighter: the next blow on it is a sure crit (x%.2f)" % ratio)
	for n in [f, fprey, fnext]:
		n.queue_free()
	field.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
