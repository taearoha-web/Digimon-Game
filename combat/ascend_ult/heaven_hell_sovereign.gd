extends Node3D
## Dark Lord ★500 สัญญาโลหิต (heaven_hell_sovereign, AscendUlt): a blood pact. At the
## release the Dark Lord pays PRICE (20%) of its CURRENT HP (never its life: at least 1 HP
## is left, price()), and its blood breaks out round it in three blasts on every foe within
## the skill's radius (10 m) of the caster, then the pact drinks: for LEECH_SECS (10 s)
## every hit the caster lands heals it LEECH (20%) of the damage dealt.
##
##   0.00 s  the pact   blood bursts from the caster (the price over its head), a blood
##                      seal turns at its feet, the pact's mark (a buff "สัญญาโลหิต") is set
##   0.30 s  the tide   a ring of blood rolls out to the radius                   30%
##   0.85 s  thorns     blood thorns burst up under every foe                     30%
##   1.80 s  blood moon a crimson moon swelled over the caster bursts             40%
##   ..10 s  the drink  a ring of blood at the caster's feet, motes drawn into it
##
## Damage: the skill's whole multiplier M (god mult x ULT_POWER, x star rank) on each foe,
## spread over the three blasts (SHARES add up to 1), scaled by the price actually paid:
##   factor = clamp(BASE + GROWTH x paid / max HP, BASE, CAP) = 0.5 + 2.5 x paid share
## so a cast at full HP (paying 20% of max HP) deals the whole M, a cast at half HP (paying
## 10%) 0.75 M, a cast at 1 HP (paying nothing) half of it: the blood is the power, and the
## most it can buy is the ultimate's own M (CAP), never more.
##
## The drink is a timed buff entry {"hit_heal": LEECH, "secs": LEECH_SECS, "overheal": true}
## (an extra entry that takes none of the three own-buff slots) on the hero's buff list
## (Hero.receive_buff) or an AI player's (Rival._buff_art); ClassRoles.after_hit heals
## every hitter by its running buffs' "hit_heal" (the Muay Thai fighter's through its own
## hit-heal), so every hit of the caster's drinks: its basic attacks, its skills, these
## blasts too.
##
## The node owns its clock (a child of the caster's field) and stops at once when the
## caster falls, is freed, leaves the field or the zone, enters a safe zone or ends its duel
## (no blast after that). An AI player's cast plays the same blasts through Rival._hit, its
## art lighter (no moon or seal at low quality, VfxBudget's shared room only).

const KIT := preload("res://combat/ascend_ult/_pact_dance_kit.gd")
const ID := "heaven_hell_sovereign"
const PRICE := 0.2
const BASE := 0.5
const GROWTH := 2.5
const CAP := 1.0
const LEECH := 0.2
const LEECH_SECS := 10.0
## [seconds after the release, share of the multiplier, kind]
const BLASTS := [[0.3, 0.3, "tide"], [0.85, 0.3, "thorns"], [1.8, 0.4, "moon"]]
const MOON_RISE := 0.9
const MOON_HEIGHT := 4.2
const MOON_SIZE := 1.5
## The hero's cast stays locked this long after the release (AscendUlt.lead).
const LEAD := 0.6
## Blood: crimson, a pale pink-white core, a near-black shade (AscendSkillData.COLORS).
const BLOOD := Color("e0203a")
const PALE := Color("ffb0a8")
const DARK := Color("2a0410")
const BRIGHT := Color("ff3a4a")

var caster: Node3D
var by_hero := false
var skill: Dictionary = {}
var radius := 10.0
## What was paid and what it bought (for tests and the HUD).
var paid := 0
var factor := 1.0
var total_mult := 0.0
var clock := 0.0
var gone := false
## Blasts landed: how many blows, and each foe's share of total_mult (instance id -> share).
var blows := 0
var dealt: Dictionary = {}
var _next := 0
var _field: Node
var _zone: StringName
var _blow: Dictionary = {}
var _seal: MeshInstance3D
var _tide: MeshInstance3D
var _moon: MeshInstance3D
var _drink: MeshInstance3D
var _mote_wait := 0.0
var _moon_tried := false


static func lead(_skill: Dictionary) -> float:
	return LEAD


## HP the pact takes from [param hp]: PRICE of it, never the last point.
static func price(hp: int) -> int:
	return clampi(int(floor(float(hp) * PRICE)), 0, maxi(hp - 1, 0))


## What [param paid] of [param max_hp] buys: the share of the multiplier dealt.
static func power_for(paid_hp: int, max_hp: int) -> float:
	return clampf(BASE + GROWTH * float(paid_hp) / float(maxi(max_hp, 1)), BASE, CAP)


func begin_hero(hero: Hero, p_skill: Dictionary, _aim: Vector3, _target: Mob) -> void:
	_begin(hero, true, p_skill)


func begin_rival(rival: Rival, p_skill: Dictionary, _aim: Vector3, _target: Node3D) -> void:
	_begin(rival, false, p_skill)


func _begin(who: Node3D, hero_side: bool, p_skill: Dictionary) -> void:
	caster = who
	by_hero = hero_side
	skill = p_skill
	radius = float(skill.get("radius", 10.0))
	_field = get_parent()
	_zone = Game.current_zone
	_blow = KIT.strike(skill, {})
	if not KIT.caster_ok(caster, _field, _zone):
		_finish()
		return
	# The price: PRICE of the current HP, never the last point.
	var hp := KIT.hp_of(caster)
	var most := KIT.max_hp_of(caster)
	var share := float((skill.get("fx", {}) as Dictionary).get("blood_price", PRICE))
	paid = clampi(int(floor(float(hp) * share)), 0, maxi(hp - 1, 0))
	KIT.set_hp(caster, hp - paid)
	factor = power_for(paid, most)
	total_mult = KIT.total(caster, by_hero, skill) * factor
	# The drink: a timed hit-heal entry that takes no own-buff slot.
	var leech: Array = (skill.get("fx", {}) as Dictionary).get("pact_leech", [LEECH, LEECH_SECS])
	var drink := {"hit_heal": float(leech[0]), "secs": float(leech[1]), "overheal": true}
	if by_hero:
		(caster as Hero).receive_buff(drink, BLOOD, String(skill.get("name", "สัญญาโลหิต")), false, ID)
	else:
		var rival := caster as Rival
		rival._buff_art.add(drink, BLOOD, String(skill.get("name", "สัญญาโลหิต")), false, ID, BuffBook.own_limit(rival.member.get("class", "")))
	global_position = KIT.flat(caster.global_position)
	KIT.with_room(by_hero, _pact_art)
	KIT.sound(by_hero, global_position, SkillSound.star_beat(0), -3.0)


func _process(delta: float) -> void:
	if gone:
		return
	if not KIT.caster_ok(caster, _field, _zone):
		_finish()
		return
	clock += delta
	global_position = KIT.flat(caster.global_position)
	while _next < BLASTS.size() and clock >= float(BLASTS[_next][0]):
		_blast(_next)
		_next += 1
	KIT.with_room(by_hero, _tick_art.bind(delta))
	if clock >= float(((skill.get("fx", {}) as Dictionary).get("pact_leech", [LEECH, LEECH_SECS]) as Array)[1]):
		_finish()


func _finish() -> void:
	if gone:
		return
	gone = true
	set_process(false)
	queue_free()


# ---------------------------------------------------------------------------
# The blasts
# ---------------------------------------------------------------------------

func _blast(index: int) -> void:
	var share := float(BLASTS[index][1])
	var kind := String(BLASTS[index][2])
	var center := global_position
	var foes := KIT.foes(caster, by_hero, center, radius)
	KIT.with_room(by_hero, _blast_art.bind(kind, center, foes))
	KIT.sound(by_hero, center, SkillSound.star_beat(0 if index == BLASTS.size() - 1 else index), -3.0 if index != 1 else -6.0)
	if index == BLASTS.size() - 1:
		KIT.sound(by_hero, center, SkillSound.landing(skill), -6.0)
	if by_hero:
		SkillFeel.impact(caster, skill, center, radius, index, BLASTS.size())
		SkillFeel.area_from(center)
	for foe in foes:
		if not is_instance_valid(caster) or gone:
			break
		var id := (foe as Node).get_instance_id()
		dealt[id] = float(dealt.get(id, 0.0)) + share
		blows += 1
		KIT.deal(caster, by_hero, foe, total_mult * share, BLOOD, _blow)
	if by_hero:
		SkillFeel.area_done()
		SkillFeel.beat_done()


# ---------------------------------------------------------------------------
# Art (cosmetic only)
# ---------------------------------------------------------------------------

func _fancy() -> bool:
	return by_hero or VfxBudget.quality() > 0


## The price paid: blood bursts from the caster, the number over its head, the seal.
func _pact_art() -> void:
	var chest := caster.global_position + Vector3.UP * 1.3
	VfxKit.flash(_field, chest, BRIGHT, 2.6, 0.32)
	VfxKit.sparks(_field, chest, BLOOD, 30, 5.5, 0.7)
	VfxArt.motes(_field, caster.global_position, BLOOD, "flame", 14, 0.9, 0.6, 1.0)
	if paid > 0:
		BattleVfx.floating_text(_field, caster.global_position + Vector3.UP * 2.9, "-%d HP" % paid, BRIGHT, 1.0)
	if by_hero:
		BattleVfx.floating_text(_field, caster.global_position + Vector3.UP * 3.6, "สัญญาโลหิต ×%.2f" % factor, PALE, 0.9)
	if _fancy():
		_seal = KIT.piece(self, "disc", KIT.material(KIT.SEAL, BLOOD, PALE, DARK, false, {"band": 0.8, "speed": 1.4}), "BloodSeal")
		if _seal:
			_seal.position = Vector3.UP * 0.07
			_seal.scale = Vector3.ONE * 3.2
	_tide = KIT.piece(self, "disc", KIT.material(KIT.TIDE, BLOOD, PALE, DARK, false, {"band": 0.12, "width": 0.07, "fade": 0.0}), "BloodTide")
	if _tide:
		_tide.position = Vector3.UP * 0.05
		_tide.scale = Vector3.ONE * radius


func _blast_art(kind: String, center: Vector3, foes: Array) -> void:
	match kind:
		"tide":
			VfxKit.shockwave(_field, center + Vector3.UP * 0.12, BLOOD, radius)
			VfxKit.impact_ring(_field, center + Vector3.UP * 0.1, BRIGHT, radius * 0.55, 0.5, PALE, DARK)
			for foe in foes.slice(0, 10):
				VfxKit.impact(_field, KIT.hit_point(foe), BLOOD, 1.0)
		"thorns":
			VfxKit.spikes(_field, center, 2.2, DARK, 9, 2.0, 0.12)
			for foe in foes.slice(0, 10):
				var at: Vector3 = KIT.flat((foe as Node3D).global_position)
				VfxKit.spikes(_field, at, 1.1 + KIT.body(foe) * 0.5, BLOOD, 7, 2.6, 0.06)
				VfxKit.sparks(_field, KIT.hit_point(foe), BRIGHT, 12, 4.0, 0.5)
		"moon":
			var top := center + Vector3.UP * MOON_HEIGHT
			VfxKit.flash(_field, top, BRIGHT, 6.0, 0.4)
			VfxArt.rays_burst(_field, top, BLOOD, 5.0, 0.45, 1.2)
			VfxKit.shockwave(_field, center + Vector3.UP * 0.15, BRIGHT, radius * 1.05)
			VfxKit.fire_ring(_field, center, BLOOD, radius * 0.9, 16, 1.0)
			VfxKit.sparks(_field, top, BLOOD, 40, 9.0, 0.9)
			for foe in foes.slice(0, 10):
				VfxKit.projectile(_field, BLOOD, top, KIT.hit_point(foe), 0.12, 0.45, "orb")
				VfxKit.impact(_field, KIT.hit_point(foe), BRIGHT, 1.3)
			if is_instance_valid(_moon):
				_moon.queue_free()
			_moon = null
			# The drink: a ring of blood stays at the caster's feet for the rest of the pact.
			_drink = KIT.piece(self, "disc", KIT.material(KIT.TIDE, BLOOD, PALE, DARK, false, {"band": 0.82, "width": 0.12, "speed": 1.8, "fade": 0.0}), "BloodDrink")
			if _drink:
				_drink.position = Vector3.UP * 0.06
				_drink.scale = Vector3.ONE * 1.3


func _tick_art(delta: float) -> void:
	# The seal turns and fades after the moon.
	if is_instance_valid(_seal):
		_seal.rotation.y += delta * 0.8
		KIT.set_fade(_seal, clampf(clock / 0.25, 0.0, 1.0) * clampf((2.3 - clock) / 0.5, 0.0, 1.0))
		if clock > 2.3:
			_seal.queue_free()
	# The tide rolls out from the caster to the radius.
	if is_instance_valid(_tide):
		var t := clampf((clock - 0.2) / 0.5, 0.0, 1.0)
		var mat := _tide.material_override as ShaderMaterial
		mat.set_shader_parameter("band", lerpf(0.12, 0.95, 1.0 - pow(1.0 - t, 2.0)))
		KIT.set_fade(_tide, clampf((clock - 0.15) / 0.1, 0.0, 1.0) * clampf((1.25 - clock) / 0.4, 0.0, 1.0))
		if clock > 1.25:
			_tide.queue_free()
	# The blood moon swells over the caster until it bursts.
	if clock >= MOON_RISE and _next < BLASTS.size() and _fancy():
		if not _moon_tried:
			_moon_tried = true
			_moon = KIT.piece(self, "orb", KIT.material(KIT.MOON, BLOOD, PALE, DARK, false, {"speed": 1.5}), "BloodMoon")
			if _moon:
				VfxKit.sparks(_field, global_position + Vector3.UP * 1.4, BLOOD, 16, 3.0, 0.6)
		if is_instance_valid(_moon):
			var grow := clampf((clock - MOON_RISE) / (float(BLASTS[2][0]) - MOON_RISE), 0.0, 1.0)
			_moon.position = Vector3.UP * lerpf(1.6, MOON_HEIGHT, sqrt(grow))
			_moon.scale = Vector3.ONE * lerpf(0.15, MOON_SIZE, grow) * (1.0 + 0.06 * sin(clock * 22.0))
			_moon.rotation.y += delta * 1.5
			if fmod(clock, 0.22) < delta:
				VfxKit.projectile(_field, BLOOD, caster.global_position + Vector3.UP * 1.3, global_position + _moon.position, 0.18, 0.18, "orb")
	# The drink: a pulsing ring at the feet, motes of blood drawn into the caster.
	if is_instance_valid(_drink):
		var left := float(((skill.get("fx", {}) as Dictionary).get("pact_leech", [LEECH, LEECH_SECS]) as Array)[1]) - clock
		KIT.set_fade(_drink, clampf((clock - 1.8) / 0.3, 0.0, 1.0) * clampf(left / 0.6, 0.0, 1.0) * (0.7 + 0.3 * sin(clock * 5.0)))
		_mote_wait -= delta
		if _mote_wait <= 0.0:
			_mote_wait = 1.1
			VfxArt.motes(_field, caster.global_position, BLOOD, "flame", 6, 0.7, 0.2, 0.9)
