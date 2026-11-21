class_name MuayThai
extends RefCounted
## The Muay Thai fighter's (นักมวยประเจียด) class mechanics, shared by the hero, its
## companions and world players (Companion), rivals and guild war fighters (Rival):
##
##   combo      every hit the fighter lands adds 1 (a skill's fx "combo" adds more), up
##              to COMBO_MAX; COMBO_WINDOW seconds without a hit (more with the จังหวะมวย
##              passive) and it is gone. Each stack: +COMBO_DAMAGE damage.
##   hit-heal   every hit heals the fighter a share of the damage it dealt: HIT_HEAL,
##              +HIT_HEAL_STEP per combo stack, + the ใจนักสู้ passive + the ritual buffs'
##              "hit_heal".
##   rings      the mantra rings (MantraRings) orbiting the body: RING_LEVELS by level;
##              they cut the damage the fighter takes (RING_GUARD).
##   combo_power  the ultimates grow by this share per stack and spend the combo.
##   kick       throws the target back (metres): monsters slide, a rival / guild war fighter
##              too (bosses hold their ground); a guild war leader standing on the altar is
##              pushed clear of the yellow circle (its capture count pauses, GuildWarMatch).
##
## State is kept as metadata on the fighter (META), like ClassRoles' marks, so every kind
## of body works without new fields. The hero and companions read the wall clock, the
## rivals GameClock (their combat runs on it).

const CLASS := &"muaythai"
const COMBO_WINDOW := 3.0
const COMBO_MAX := 20
const COMBO_DAMAGE := 0.01
const HIT_HEAL := 0.02
const HIT_HEAL_STEP := 0.002
## [from level, rings], highest first.
const RING_LEVELS := [[90, 6], [60, 4], [1, 2]]
## Damage taken is cut by this share with 2 / 4 / 6 rings.
const RING_GUARD := {2: 0.04, 4: 0.06, 6: 0.08}
## The slide of a kick decays like a knock-back (Mob._physics_process: 12 m/s each second).
const SLIDE_DECAY := 12.0
## How far past the yellow circle's edge a kicked leader lands.
const ALTAR_CLEAR := 1.2
const META := &"muay_combo"
const HEAL_META := &"muay_heal"


static func is_fighter(unit: Variant) -> bool:
	return ClassRoles.class_of(unit) == CLASS


## Rings orbiting a fighter of [param level]: 2, 4 from Lv.60, 6 from Lv.90.
static func ring_count(level: int) -> int:
	for row in RING_LEVELS:
		if level >= int(row[0]):
			return int(row[1])
	return 2


static func level_of(unit: Variant) -> int:
	if unit is Hero:
		return int(Game.profile.get("level", 1))
	if unit is Companion:
		return int((unit as Companion).member.get("level", 1))
	if unit is Mob:
		return int((unit as Mob).level)
	return 1


static func _now(unit: Variant) -> int:
	return GameClock.msec() if unit is Mob else Time.get_ticks_msec()


static func _stats(unit: Variant) -> Dictionary:
	if unit is Hero:
		return (unit as Hero).stats
	if unit is Companion:
		return (unit as Companion).stats
	if unit is Rival:
		return (unit as Rival).rstats
	return {}


## Seconds a combo lasts without a hit (the จังหวะมวย passive adds to it).
static func window(unit: Variant) -> float:
	return COMBO_WINDOW + float(_stats(unit).get("combo_secs", 0.0))


## The fighter's combo now (0 once the window ran out).
static func combo(unit: Variant) -> int:
	if unit == null or not is_instance_valid(unit) or not (unit as Object).has_meta(META):
		return 0
	var state: Array = (unit as Object).get_meta(META)
	if _now(unit) - int(state[1]) > int(window(unit) * 1000.0):
		return 0
	return int(state[0])


static func add_combo(unit: Variant, stacks: int) -> int:
	var now := combo(unit)
	var count := mini(COMBO_MAX, now + stacks)
	(unit as Object).set_meta(META, [count, _now(unit)])
	return count


## Takes the combo away (an ultimate spent it); returns how much there was.
static func spend(unit: Variant) -> int:
	var had := combo(unit)
	if unit != null and is_instance_valid(unit):
		(unit as Object).set_meta(META, [0, _now(unit)])
	return had


## Damage multiplier of the fighter's hits from its combo (1 for any other class).
static func damage_mult(unit: Variant) -> float:
	if not is_fighter(unit):
		return 1.0
	return 1.0 + COMBO_DAMAGE * float(combo(unit))


## An ultimate's multiplier: +combo_power per stack. Spends the combo; every target of
## the same cast (an area ultimate hits several within SPENT_MS) gets the same power.
static func finisher(unit: Variant, fx: Dictionary) -> float:
	if not fx.has("combo_power") or not is_fighter(unit):
		return 1.0
	var obj := unit as Object
	var spent: Array = obj.get_meta(SPENT_META, [0, -100000])
	var stacks := spend(unit)
	if _now(unit) - int(spent[1]) <= SPENT_MS:
		stacks = int(spent[0])
	else:
		obj.set_meta(SPENT_META, [stacks, _now(unit)])
	return 1.0 + float(fx.combo_power) * float(stacks)


const SPENT_META := &"muay_spent"
const SPENT_MS := 400


## Share of damage dealt the fighter heals back now.
static func heal_share(unit: Variant) -> float:
	return HIT_HEAL + HIT_HEAL_STEP * float(combo(unit)) + float(_stats(unit).get("hit_heal", 0.0)) + buff_total(unit, "hit_heal")


## The fighter's running buffs (hero, companion, rival) summed for [param key].
static func buff_total(unit: Variant, key: String) -> float:
	var list: Array = []
	if unit is Hero:
		list = (unit as Hero)._buffs
	elif unit is Companion:
		list = (unit as Companion)._book.buffs
	elif unit is Rival:
		list = (unit as Rival)._buff_art.buffs
	var now := Time.get_ticks_msec()
	var total := 0.0
	for buff in list:
		if int(buff.get("until", 0)) > now:
			total += float(buff.get(key, 0.0))
	return total


## A hit of the fighter landed for [param dealt] (ClassRoles.after_hit): one combo stack
## and the hit-heal.
static func after_hit(attacker: Variant, dealt: int) -> void:
	if dealt <= 0 or not is_fighter(attacker):
		return
	var share := heal_share(attacker)
	var before := combo(attacker)
	var count := add_combo(attacker, 1)
	ClassRoles._gain(attacker, HEAL_META, float(dealt) * share, "hp")
	# The player's own fighter calls its combo at every fifth stack.
	if attacker is Hero and count != before and count % 5 == 0 and is_instance_valid((attacker as Hero).field):
		BattleVfx.floating_text((attacker as Hero).field, (attacker as Hero).global_position + Vector3(0, 2.9, 0), "คอมโบ %d!" % count, Color("ffb347"), 0.8)


## A skill's own effects on a landed hit: extra combo stacks, the kick.
static func skill_fx(attacker: Variant, victim: Variant, fx: Dictionary) -> void:
	if fx.is_empty() or not is_fighter(attacker):
		return
	if fx.has("combo"):
		add_combo(attacker, int(fx.combo))
	if fx.has("kick") and attacker is Node3D:
		kick(victim, (attacker as Node3D).global_position, float(fx.kick))


## Damage multiplier the mantra rings leave on a hit the fighter takes.
static func ring_guard(victim: Variant) -> float:
	if not is_fighter(victim):
		return 1.0
	return 1.0 - float(RING_GUARD.get(ring_count(level_of(victim)), 0.0))


## The body's HeroVisual (hero, companion, rival), or null.
static func visual_of(unit: Variant) -> HeroVisual:
	if unit is Hero or unit is Companion:
		return unit.visual as HeroVisual
	if unit is Rival and (unit as Rival)._rv:
		return (unit as Rival)._rv.hero_visual
	return null


## A skill that uses the rings ("rings": ring throws, the spin, the ultimates): the
## orbiting rings are lent out and their flying copies (MantraRings.fly) go to
## [param center] and back: to points around it for the throws and the spin (one per
## ring the fighter has, at most 6), all at the target for the ultimates.
static func ring_show(caster: Variant, skill: Dictionary, center: Vector3) -> void:
	if not bool(skill.get("rings", false)) or not (caster is Node3D) or not is_instance_valid(caster):
		return
	var body := caster as Node3D
	var field := body.get_parent()
	var count := ring_count(level_of(caster))
	var visual := visual_of(caster)
	var secs := 0.7
	# Cosmetic copies: they keep within the effects budget (VfxBudget), the hero's own
	# casts first; the orbit is lent out only when they fly.
	if not VfxBudget.can_decorate(count):
		return
	if visual != null and is_instance_valid(visual.rings):
		visual.rings.lend(secs)
	var from := body.global_position + Vector3(0, MantraRings.HEIGHT, 0)
	var shape := String(skill.get("shape", "single"))
	for i in count:
		var to := center + Vector3(0, 1.0, 0)
		if shape in ["chain", "fan", "burst"]:
			var a := TAU * float(i) / float(count)
			var reach := float(skill.get("radius", 3.0)) * 0.8 if shape == "burst" else 1.6
			to = (body.global_position if shape == "burst" else center) + Vector3(cos(a) * reach, 1.0, sin(a) * reach)
		elif shape == "blast":
			to = center + Vector3(0, 0.3, 0)
		MantraRings.fly(field, from, to, body, secs, 1.8 if shape in ["single", "blast"] else 1.4)


## Throws [param victim] [param metres] away from [param from]. A body standing on the
## guild war altar goes clear of the yellow circle whatever the kick's length.
static func kick(victim: Variant, from: Vector3, metres: float) -> void:
	if victim == null or not is_instance_valid(victim) or not (victim is Node3D) or metres <= 0.0:
		return
	var body := victim as Node3D
	if body is Mob and (body as Mob).is_dead():
		return
	var dir := body.global_position - from
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, 1)
	var dist := metres
	if GuildWarMatch.in_war() and SiegeArena.on_altar(body.global_position):
		var off := body.global_position - SiegeArena.ALTAR
		off.y = 0.0
		# Off the circle the shortest way (away from its middle), however it was struck.
		if off.length() > 0.25:
			dir = off
		dist = maxf(dist, SiegeArena.ALTAR_RADIUS - off.length() + ALTAR_CLEAR)
	dir = dir.normalized()
	if body is Mob:
		var mob := body as Mob
		# Real bosses hold their ground; rivals and guild fighters (also flagged is_boss so
		# monsters' knock-backs leave them be) are thrown like anyone.
		if mob.is_boss and not (mob is Rival):
			return
		var speed := sqrt(2.0 * SLIDE_DECAY * dist)
		mob.velocity.x = dir.x * speed
		mob.velocity.z = dir.z * speed
		# Held for the slide: it cannot walk against it (a stun of the same hit may be longer).
		mob._stun = maxf(mob._stun, speed / SLIDE_DECAY)
	elif body is CharacterBody3D:
		(body as CharacterBody3D).move_and_collide(dir * dist)
