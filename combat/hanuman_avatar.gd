class_name HanumanAvatar
extends Node3D
## หนุมานแผลงฤทธิ์ (the Muay Thai ★200 star skill, StarSkillData "companion"): หนุมาน himself
## answers the call and fights beside his caller for LIFE seconds. He drops in at the
## caller's side out of a gold flash, then leaps from enemy to enemy near the caller,
## striking one at a time (a flying trident thrust as he lands, then Muay Thai: a
## roundhouse kick, a knee, an elbow, a thrust; two blows a foe, then on to the next), yawns
## stars and a crescent moon once (หาวเป็นดาวเป็นเดือน, the stars strike his foe), and ends
## with a leap and a trident slam (stun, kick) before he bows and dissolves into gold.
##
## Damage: the skill's whole multiplier, as the old blast dealt to each target, spread over
## his blows: REGULAR blows of REGULAR_SHARE and the slam's FINAL_SHARE (1.0 in all) on
## a fixed clock of SLOT seconds a blow, so the total holds whatever the leaps. The
## caller deals every blow: the hero's through Hero._deal (kill credit, drops, combo, the
## coliseum and online duels' PvpProxy, the guild war's fighters, the hit-heal), an AI
## fighter's through Rival._hit (its war scale, BurstGuard, the hero's defence). He is not a
## body: nothing targets him, he takes no damage, he holds no slot of the caller's summons.
##
## Lifetime: a child of the caller's field (a zone change frees him with it); the caller
## falling, leaving the field, entering a safe zone or ending its duel sends him away at once
## (no blow after that). One per caller (a new call replaces the old). Visual budget: the
## hero's own always shows (its effects in the hero's room of VfxBudget); an AI fighter's
## shows only while fewer than MAX_AI_SHOWN others do and the quality is above low, else he
## fights unseen (the blows' small impacts still show, budget-gated). Low quality drops the
## outline pass and the ลาย detail.

const ID := "heaven_ring_cataclysm"
const LIFE := 10.0
const ARRIVE := 0.7
const SLOT := 0.62
const REGULAR := 13
const FINAL_SHARE := 0.16
const REGULAR_SHARE := (1.0 - FINAL_SHARE) / float(REGULAR)
## The finale (leap and slam) after the last regular blow; the bow and dissolve fill the rest.
const FINALE := 0.8
const FINALE_HIT := 0.5
## His blows find foes within LEASH m of his caller (the old blast reached 12 + 7.5 m).
const LEASH := 16.0
## ... and within AROUND m of the fight's centre (see _foes).
const AROUND := 9.0
## Metres per figure unit (HanumanSculpt): about 3.6 m to the crown's tip (a head over the
## fighter, like the summoner's legends).
const SCALE := 2.6
## How far from its foe he lands (beyond its body).
const STAND_OFF := 1.3
## A blow lands on its foe within this reach (beyond its body); else on the nearest foe within
## REACH_ALT of him; else it is lost.
const REACH := 4.0
const REACH_ALT := 3.0
const YAWN_SLOT := 6
## Blows on one foe before he leaps to the next (when there is another).
const HITS_PER_FOE := 2
const KICK_METRES := 1.2
const FINAL_STUN := 1.5
const FINAL_KICK := 4.0
const MAX_AI_SHOWN := 2
const GOLD := Color("ffc24a")
const LIGHT := Color("fff0c0")
const FOLLOW_UPS := ["kick", "knee", "thrust", "elbow"]
## When each action's blow lands (seconds into its slot).
const HIT_AT := {"leap": 0.38, "kick": 0.25, "knee": 0.22, "thrust": 0.24, "elbow": 0.2, "yawn": 0.42}
const LEAP_TIME := 0.34

static var _live: Array = []

var caller: Node3D
var skill: Dictionary = {}
## The whole multiplier his blows share (the hero's: mult x rank power; an AI's: mult x
## SKILL_POWER x rank power, as Rival._resolve).
var total_mult := 0.0
var by_hero := false
var shown := true
var clock := 0.0
## What he has dealt (shares of total_mult on a live foe) and how many blows: for tests.
var dealt_share := 0.0
var blows := 0
var gone := false

var _field: Node3D
var _zone: StringName
var _strike: Dictionary = {}
var _strike_final: Dictionary = {}
var _slot := -1
var _action := ""
var _struck := false
var _target: Node3D
var _last: Node3D
var _on_target := 0
## Blows landed on each foe (instance id): he spreads them round.
var _struck_on: Dictionary = {}
var _follow := 0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _vanish_at := 0.0
var _leaving := false
var _yaw := 0.0
var _rig: Node3D
var _joints: Dictionary = {}
var _mat: ShaderMaterial
var _line: ShaderMaterial
var _pose_a := ""
var _moon: MeshInstance3D


# ---------------------------------------------------------------------------
# Calling him
# ---------------------------------------------------------------------------

## The hero's cast (StarSkillSequence, at the release): [param data] the ranked skill.
static func summon(hero: Hero, data: Dictionary) -> HanumanAvatar:
	if not is_instance_valid(hero) or hero.is_dead() or not is_instance_valid(hero.field):
		return null
	return _spawn(hero, hero.field, data, float(data.get("mult", 0.0)) * hero.rank_mult(data), true)


## An AI fighter's cast (Rival._cast, at the release).
static func summon_for(rival: Rival, data: Dictionary) -> HanumanAvatar:
	if not is_instance_valid(rival) or rival.is_dead() or not (rival.get_parent() is Node3D):
		return null
	var mult := float(data.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(data))
	return _spawn(rival, rival.get_parent() as Node3D, data, mult, false)


static func _spawn(who: Node3D, field: Node3D, data: Dictionary, mult: float, hero_side: bool) -> HanumanAvatar:
	dismiss(who)
	var h := HanumanAvatar.new()
	h.name = "Hanuman"
	h.caller = who
	h.skill = data
	h.total_mult = mult
	h.by_hero = hero_side
	h.shown = hero_side or (VfxBudget.quality() > 0 and shown_count() < MAX_AI_SHOWN)
	h._field = field
	h._zone = Game.current_zone
	field.add_child(h)
	_live.append(weakref(h))
	return h


## Every Hanuman still fighting (not leaving): tests, the HUD.
static func active() -> Array:
	var out: Array = []
	var keep: Array = []
	for ref: WeakRef in _live:
		var h := ref.get_ref() as HanumanAvatar
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			keep.append(ref)
			if not h.gone and not h._leaving:
				out.append(h)
	_live = keep
	return out


static func of(who: Node) -> HanumanAvatar:
	for h: HanumanAvatar in active():
		if h.caller == who:
			return h
	return null


static func shown_count() -> int:
	var n := 0
	for h: HanumanAvatar in active():
		if h.shown and not h.by_hero:
			n += 1
	return n


## Sends [param who]'s Hanuman away at once (a new call, the caller leaving).
static func dismiss(who: Node) -> void:
	for h: HanumanAvatar in active():
		if h.caller == who:
			h._leave(true)


# ---------------------------------------------------------------------------
# Life
# ---------------------------------------------------------------------------

func _ready() -> void:
	_strike = {"id": "hanuman_strike", "name": String(skill.get("name", "หนุมาน")), "class": &"muaythai", "star": 0, "shape": "single", "level": 100, "color": GOLD, "vfx": &"light", "fx": {}}
	_strike_final = _strike.duplicate()
	_strike_final["fx"] = {"stun": FINAL_STUN}
	_yaw = _caller_yaw()
	var spot := _side_spot()
	global_position = spot
	rotation.y = _yaw
	if shown:
		_build()
		_pose("fly", "fly", 0.0)
	_with_room(func():
		VfxKit.flash(_field, spot + Vector3.UP * 2.0, LIGHT, 3.2, 0.35)
		VfxArt.motes(_field, spot + Vector3.UP * 2.6, GOLD, "star", 16, 1.2, 1.4, 1.0)
	)
	_sound(SkillSound.star_beat(0), -4.0)
	if by_hero:
		BattleVfx.floating_text(_field, spot + Vector3.UP * 3.6, "หนุมาน!", GOLD, 0.9)


func _process(delta: float) -> void:
	if gone:
		return
	clock += delta
	if _leaving:
		_tick_vanish()
		return
	if not _caller_ok():
		_leave(true)
		_tick_vanish()
		return
	var fight_end := ARRIVE + SLOT * float(REGULAR)
	if clock < ARRIVE:
		_tick_arrive()
	elif clock < fight_end:
		var k := int((clock - ARRIVE) / SLOT)
		if k != _slot:
			_begin(k)
		_tick_action(clock - ARRIVE - SLOT * float(k))
	elif clock < fight_end + FINALE:
		if _slot != REGULAR:
			_slot = REGULAR
			_begin_finale()
		_tick_finale(clock - fight_end)
	else:
		_leave(false)
	if shown and _mat:
		_breathe()


func _exit_tree() -> void:
	gone = true


## The caller can still command him: alive, on this field, out of the safe zone, its duel on.
func _caller_ok() -> bool:
	if caller == null or not is_instance_valid(caller) or caller.is_queued_for_deletion():
		return false
	if caller.has_method("is_dead") and caller.is_dead():
		return false
	if Game.current_zone != _zone:
		return false
	if caller is Hero:
		var hero := caller as Hero
		return hero.field == _field and not hero.safe_zone
	if caller is Rival:
		return not (caller as Rival).duel_over and caller.get_parent() == _field
	return true


func _leave(at_once: bool) -> void:
	if gone or _leaving:
		return
	_leaving = true
	_vanish_at = clock
	_target = null
	if at_once:
		_vanish_at = clock - 0.25
	_with_room(func():
		VfxArt.motes(_field, global_position + Vector3.UP * 1.6, GOLD, "star", 12, 1.0, 2.2, 1.0)
	)


func _tick_vanish() -> void:
	var t := clock - _vanish_at
	if shown and _mat:
		_pose("wai", "wai", 1.0)
		var f := clampf(1.0 - (t - 0.15) / 0.4, 0.0, 1.0)
		_set_fade(f)
		_rig.position.y = maxf(t - 0.15, 0.0) * 1.2 / SCALE
	if t >= 0.6:
		gone = true
		queue_free()


# ---------------------------------------------------------------------------
# Arrival, the blows, the finale
# ---------------------------------------------------------------------------

func _tick_arrive() -> void:
	var t := clock / ARRIVE
	var spot := _side_spot()
	global_position = spot + Vector3.UP * 3.2 * pow(1.0 - minf(t / 0.5, 1.0), 2.0)
	_yaw = lerp_angle(_yaw, _caller_yaw(), 0.2)
	rotation.y = _yaw
	if shown and _mat:
		_set_fade(clampf(t / 0.35, 0.0, 1.0))
		if t < 0.5:
			_pose("fly", "fly", 0.0)
		elif t < 0.7:
			_pose("crouch", "crouch", 0.0)
		else:
			_pose("crouch", "guard", (t - 0.7) / 0.3)
	if t >= 0.5 and not _struck:
		_struck = true
		_with_room(func():
			VfxKit.impact_ring(_field, spot + Vector3.UP * 0.1, GOLD, 2.4, 0.45)
			VfxKit.sparks(_field, spot + Vector3.UP * 0.3, LIGHT, 14, 4.0, 0.5)
		)


func _begin(k: int) -> void:
	_slot = k
	_struck = false
	if _mat:
		_mat.set_shader_parameter("mouth_open", 0.0)
	_from = global_position
	var foe := _pick()
	if foe == null:
		_action = "idle"
		_target = null
		return
	if foe != _target:
		_on_target = 0
	_target = foe
	if k == YAWN_SLOT:
		_action = "yawn"
	elif _on_target == 0 or _flat(foe.global_position - global_position).length() > _body(foe) + STAND_OFF + 1.4:
		_action = "leap"
		_sound(&"dash", -8.0)
		_with_room(func(): VfxArt.motes(_field, global_position + Vector3.UP * 0.3, LIGHT, "star", 6, 0.6, 0.6, 0.6))
	else:
		_action = FOLLOW_UPS[_follow % FOLLOW_UPS.size()]
		_follow += 1
	_to = _stand_by(foe)


func _tick_action(t: float) -> void:
	if _action == "idle":
		_idle_by_caller()
		return
	if _valid(_target):
		_to = _stand_by(_target)
		_face(_target.global_position)
	if _action == "leap":
		var s := clampf(t / LEAP_TIME, 0.0, 1.0)
		var e := s * s * (3.0 - 2.0 * s)
		var arc := 4.0 * s * (1.0 - s) * clampf(_from.distance_to(_to) * 0.22, 0.9, 2.6)
		global_position = _from.lerp(_to, e) + Vector3.UP * arc
		if shown and _mat:
			if t < 0.06:
				_pose("guard", "crouch", t / 0.06)
			elif t < LEAP_TIME:
				_pose("fly", "fly", 0.0)
			elif t < 0.44:
				_pose("fly", "thrust", (t - LEAP_TIME) / 0.1)
			else:
				_pose("thrust", "guard", (t - 0.44) / 0.18)
	else:
		# Closing the last steps on the spot (a foe that shifted, a kick that slid it).
		var p := global_position.lerp(_to, 1.0 - exp(-10.0 * get_process_delta_time()))
		global_position = p
		if shown and _mat:
			_follow_pose(_action, t)
	if not _struck and t >= float(HIT_AT.get(_action, 0.3)):
		_struck = true
		_blow(REGULAR_SHARE, _action, false)


func _follow_pose(action: String, t: float) -> void:
	var hit := float(HIT_AT.get(action, 0.25))
	var wind := {"kick": "kick_chamber", "knee": "knee_chamber", "thrust": "thrust_wind", "elbow": "elbow_wind", "yawn": "yawn_draw"}
	if t < hit * 0.55:
		_pose("guard", wind.get(action, "guard"), t / (hit * 0.55))
	elif t < hit:
		_pose(wind.get(action, "guard"), action, (t - hit * 0.55) / (hit * 0.45))
	elif t < hit + 0.12:
		_pose(action, action, 0.0)
	else:
		_pose(action, "guard", (t - hit - 0.12) / maxf(SLOT - hit - 0.14, 0.05))
	if action == "yawn":
		_mat.set_shader_parameter("mouth_open", clampf(t / 0.3, 0.0, 1.0) * clampf((SLOT - t) / 0.15, 0.0, 1.0))


func _begin_finale() -> void:
	_struck = false
	_from = global_position
	var foe := _pick()
	_target = foe
	_to = _stand_by(foe) if foe else _side_spot()
	if foe:
		_sound(&"dash", -6.0)


func _tick_finale(t: float) -> void:
	if _valid(_target):
		_to = _stand_by(_target, 0.55)
		_face(_target.global_position)
	var s := clampf(t / (FINALE_HIT - 0.04), 0.0, 1.0)
	var arc := 4.0 * s * (1.0 - s) * 3.2 if s < 0.5 else 3.2 * (1.0 - pow((s - 0.5) * 2.0, 2.0))
	global_position = _from.lerp(_to, s * s * (3.0 - 2.0 * s)) + Vector3.UP * arc
	if shown and _mat:
		if t < 0.08:
			_pose("guard", "crouch", t / 0.08)
		elif t < FINALE_HIT - 0.12:
			_pose("crouch", "slam_up", (t - 0.08) / 0.14)
		elif t < FINALE_HIT:
			_pose("slam_up", "slam", (t - FINALE_HIT + 0.12) / 0.12)
		else:
			_pose("slam", "slam", 0.0)
	if not _struck and t >= FINALE_HIT:
		_struck = true
		if _target != null:
			_blow(FINAL_SHARE, "slam", true)


func _idle_by_caller() -> void:
	var spot := _side_spot()
	var to := spot - global_position
	to.y = 0.0
	if to.length() > 0.4:
		global_position += to.normalized() * minf(to.length(), 9.0 * get_process_delta_time())
	global_position.y = spot.y
	_yaw = lerp_angle(_yaw, _caller_yaw(), 1.0 - exp(-6.0 * get_process_delta_time()))
	rotation.y = _yaw
	if shown and _mat:
		_pose("guard", "guard", 0.0)


# ---------------------------------------------------------------------------
# Foes and blows
# ---------------------------------------------------------------------------

## The foe of the next blow: the one he fights while it has blows left; else another round
## the fight, the one he has struck least (the caller's own target first when he begins, then
## the nearest of the least struck, never the one he just left when there is a choice); else
## the same one again.
func _pick() -> Node3D:
	var foes := _foes()
	if foes.is_empty():
		return null
	if _valid(_target) and _target in foes and _on_target < HITS_PER_FOE:
		return _target
	var own := _caller_target()
	if _target == null and own != null and own in foes:
		return own
	var best: Node3D = null
	var best_score := INF
	for foe: Node3D in foes:
		if foe == _target and foes.size() > 1:
			continue
		var score := float(_struck_on.get(foe.get_instance_id(), 0)) * 1000.0 + global_position.distance_to(foe.global_position)
		if score < best_score:
			best_score = score
			best = foe
	return best


## Everyone his caller may strike: within LEASH of the caller and AROUND of the fight (the
## caller's own target, else his, else the caller), as the old blast's area round its target,
## so he never wanders off to wake a quiet herd.
func _foes() -> Array:
	var out: Array = []
	var at := caller.global_position
	var anchor := at
	var own := _caller_target()
	if own != null:
		anchor = own.global_position
	elif _valid(_target):
		anchor = _target.global_position
	var near := func(p: Vector3, r: float) -> bool:
		return _flat(p - at).length() <= LEASH + r and _flat(p - anchor).length() <= AROUND + r
	if by_hero:
		var hero := caller as Hero
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob == null or mob.is_dead() or not is_instance_valid(mob):
				continue
			if mob is CastleGate and not (mob as CastleGate).open_to(hero):
				continue
			if near.call(mob.global_position, mob.body_radius()):
				out.append(mob)
	else:
		var rival := caller as Rival
		for node: Node3D in rival._targets():
			if rival._alive(node) and near.call(node.global_position, 0.0):
				out.append(node)
	return out


func _caller_target() -> Node3D:
	if by_hero:
		var t: Variant = (caller as Hero).target
		return t as Node3D if t is Mob and _valid(t) else null
	var v: Variant = (caller as Rival)._victim
	return v as Node3D if v is Node3D and _valid(v) else null


func _valid(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero and caller is Rival and is_instance_valid(caller):
		return (caller as Rival)._alive(node)
	return node.has_method("is_dead") and not node.is_dead()


## One blow ([param share] of the whole multiplier) on his foe.
func _blow(share: float, kind: String, final: bool) -> void:
	var foe := _target
	if not _valid(foe) or _flat(foe.global_position - global_position).length() > REACH + _body(foe):
		foe = null
		var best_d := REACH_ALT
		for other: Node3D in _foes():
			var d := _flat(other.global_position - global_position).length() - _body(other)
			if d < best_d:
				best_d = d
				foe = other
	if foe == null:
		return
	_on_target += 1
	_last = foe
	_struck_on[foe.get_instance_id()] = int(_struck_on.get(foe.get_instance_id(), 0)) + 1
	blows += 1
	dealt_share += share
	var at := _hit_point(foe)
	var from := global_position
	var room := func():
		match kind:
			"kick", "slam":
				VfxKit.slash_arc(_field, at, _yaw + (0.0 if kind == "kick" else PI * 0.5), LIGHT, 2.4 if kind == "kick" else 3.0, 0.5 if kind == "kick" else -1.2)
			"thrust", "leap":
				VfxKit.flash(_field, at, LIGHT, 1.4, 0.18)
			"yawn":
				_yawn_stars(at)
		VfxKit.impact(_field, at, GOLD, 1.3 if final else 1.0)
		if final:
			VfxKit.shockwave(_field, Vector3(foe.global_position.x, foe.global_position.y + 0.1, foe.global_position.z), GOLD, 3.8)
			VfxKit.impact_ring(_field, foe.global_position + Vector3.UP * 0.1, LIGHT, 3.0, 0.5)
	_with_room(room)
	if final:
		_sound(SkillSound.landing(skill), -3.0)
		_sound(SkillSound.star_beat(0), -4.0)
	var mult := total_mult * share
	if by_hero:
		var hero := caller as Hero
		var mob := foe as Mob
		VfxBudget.hero_begin()
		hero._deal(mob, mult, GOLD, &"light", false, _strike_final if final else _strike)
		VfxBudget.hero_end()
		if is_instance_valid(mob) and not mob.is_dead() and (final or kind == "kick"):
			MuayThai.kick(mob, from, FINAL_KICK if final else KICK_METRES, hero)
	else:
		var rival := caller as Rival
		rival._hit(foe, mult, GOLD, {})
		if final and _valid(foe):
			MuayThai.kick(foe, from, FINAL_KICK, rival)


func _yawn_stars(at: Vector3) -> void:
	var mouth := global_position + Vector3.UP * 2.35 + Vector3(sin(_yaw), 0, cos(_yaw)) * 0.4
	VfxArt.motes(_field, mouth, Color("fff2a8"), "star", 24, 0.8, 2.4, 1.2)
	VfxKit.projectile(_field, GOLD, mouth, at, 0.16, 0.5, "spark")
	if not shown or not VfxBudget.can_decorate():
		return
	# The crescent he yawned rises over him and fades.
	var moon := MeshInstance3D.new()
	moon.mesh = HanumanSculpt.mesh("crescent")
	moon.material_override = _mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_field.add_child(moon)
	VfxBudget.track_decoration(moon)
	moon.global_position = mouth + Vector3.UP * 0.3
	moon.rotation.y = _yaw
	moon.scale = Vector3.ONE * 0.2
	var tw := moon.create_tween().set_parallel()
	tw.tween_property(moon, "scale", Vector3.ONE * 1.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(moon, "global_position", mouth + Vector3.UP * 2.4, 1.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(moon, "rotation:z", 0.5, 1.1)
	tw.chain().tween_property(moon, "scale", Vector3.ONE * 0.01, 0.25)
	tw.chain().tween_callback(moon.queue_free)


func _hit_point(foe: Node3D) -> Vector3:
	if foe.has_method("hit_point"):
		return foe.hit_point()
	return foe.global_position + Vector3.UP * 1.1


func _body(foe: Node3D) -> float:
	return (foe as Mob).body_radius() if foe is Mob else 0.5


## Where he lands to strike [param foe]: on his side of it, STAND_OFF beyond its body.
func _stand_by(foe: Node3D, extra := 0.0) -> Vector3:
	var dir := _flat(global_position - foe.global_position)
	if dir.length_squared() < 0.01:
		dir = _flat(caller.global_position - foe.global_position)
	if dir.length_squared() < 0.01:
		dir = Vector3.BACK
	var p := foe.global_position + dir.normalized() * (_body(foe) + STAND_OFF + extra)
	p.y = _floor_at(p)
	return p


## Where he stands beside a caller facing [param yaw]: on its right, a little ahead (clear of
## the camera behind it; the star art's wind-up gathers there too).
static func side_offset(yaw: float) -> Vector3:
	return Vector3(-cos(yaw), 0.0, sin(yaw)) * 2.3 + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.7


func _side_spot() -> Vector3:
	var p := caller.global_position + side_offset(_caller_yaw())
	p.y = _floor_at(p)
	return p


func _caller_yaw() -> float:
	if caller is Hero:
		return float((caller as Hero)._facing)
	if caller is Rival:
		return float((caller as Rival)._yaw)
	return caller.rotation.y


## The floor under [param p]: the caller's, carried over the guild war's stairs and court.
func _floor_at(p: Vector3) -> float:
	var y := caller.global_position.y
	if Game.current_zone == &"guildwar":
		y += SiegeArena.floor_y(p) - SiegeArena.floor_y(caller.global_position)
	return y


func _face(point: Vector3) -> void:
	var d := _flat(point - global_position)
	if d.length_squared() < 0.0004:
		return
	_yaw = lerp_angle(_yaw, atan2(d.x, d.z), 1.0 - exp(-16.0 * get_process_delta_time()))
	rotation.y = _yaw


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Runs [param fn] (effects) in the hero's room of the visual budget for the hero's own.
func _with_room(fn: Callable) -> void:
	if by_hero:
		VfxBudget.hero_begin()
	fn.call()
	if by_hero:
		VfxBudget.hero_end()


func _sound(id: StringName, db: float) -> void:
	if id == &"" or not AudioManager.has_sound(id):
		return
	if by_hero:
		AudioManager.play_sfx(id, db)
	else:
		AudioManager.play_sfx_at(global_position, id, db - 4.0)


# ---------------------------------------------------------------------------
# The body (HanumanSculpt parts on a joint rig) and its poses
# ---------------------------------------------------------------------------

const JOINTS := ["hips", "chest", "neck", "sh_l", "el_l", "sh_r", "el_r", "tri", "hip_l", "kn_l", "hip_r", "kn_r", "tail"]
## Joint angles in degrees (X: a hanging limb swings back for +, forward for -; Z: the left
## limb out for +, the right for -; Y: a twist). "tri" is the trident's own turn in the
## chest's frame (its prongs +Y): 90 points it ahead. "lift": figure units off the floor.
const POSES := {
	"guard": {"hips": Vector3(0, -12, 0), "chest": Vector3(8, 14, 0), "neck": Vector3(-4, -6, 0), "sh_l": Vector3(-38, 0, 20), "el_l": Vector3(-118, 0, 0), "sh_r": Vector3(-20, 0, -24), "el_r": Vector3(-78, 0, 0), "tri": Vector3(8, 0, -6), "hip_l": Vector3(-26, 0, 10), "kn_l": Vector3(36, 0, 0), "hip_r": Vector3(14, 0, -12), "kn_r": Vector3(26, 0, 0), "tail": Vector3(0, 0, 0)},
	"crouch": {"hips": Vector3(0, -8, 0), "chest": Vector3(24, 8, 0), "neck": Vector3(-16, 0, 0), "sh_l": Vector3(-20, 0, 30), "el_l": Vector3(-90, 0, 0), "sh_r": Vector3(10, 0, -30), "el_r": Vector3(-60, 0, 0), "tri": Vector3(40, 0, -10), "hip_l": Vector3(-58, 0, 16), "kn_l": Vector3(96, 0, 0), "hip_r": Vector3(-40, 0, -16), "kn_r": Vector3(86, 0, 0), "tail": Vector3(18, 0, 0)},
	"fly": {"hips": Vector3(-6, 0, 0), "chest": Vector3(-4, 0, 0), "neck": Vector3(6, 0, 0), "sh_l": Vector3(-80, 0, 34), "el_l": Vector3(-40, 0, 0), "sh_r": Vector3(-168, 0, -14), "el_r": Vector3(-30, 0, 0), "tri": Vector3(118, 0, 0), "hip_l": Vector3(-82, 0, 12), "kn_l": Vector3(120, 0, 0), "hip_r": Vector3(-26, 0, -12), "kn_r": Vector3(96, 0, 0), "tail": Vector3(-24, 0, 0), "lift": 0.0},
	"thrust": {"hips": Vector3(0, -18, 0), "chest": Vector3(16, -20, 0), "neck": Vector3(-10, 14, 0), "sh_l": Vector3(-30, 0, 30), "el_l": Vector3(-110, 0, 0), "sh_r": Vector3(-86, 14, -6), "el_r": Vector3(-6, 0, 0), "tri": Vector3(92, -6, 0), "hip_l": Vector3(-56, 0, 10), "kn_l": Vector3(60, 0, 0), "hip_r": Vector3(30, 0, -8), "kn_r": Vector3(12, 0, 0), "tail": Vector3(-10, 0, 0)},
	"thrust_wind": {"hips": Vector3(0, 10, 0), "chest": Vector3(4, 34, 0), "neck": Vector3(-4, -20, 0), "sh_l": Vector3(-60, 0, 20), "el_l": Vector3(-90, 0, 0), "sh_r": Vector3(-40, -10, -40), "el_r": Vector3(-110, 0, 0), "tri": Vector3(92, 20, 0), "hip_l": Vector3(-30, 0, 10), "kn_l": Vector3(44, 0, 0), "hip_r": Vector3(16, 0, -12), "kn_r": Vector3(30, 0, 0), "tail": Vector3(10, 0, 0)},
	"kick_chamber": {"hips": Vector3(0, 30, 0), "chest": Vector3(0, 10, 0), "neck": Vector3(0, -30, 0), "sh_l": Vector3(-50, 0, 30), "el_l": Vector3(-120, 0, 0), "sh_r": Vector3(0, 0, -40), "el_r": Vector3(-50, 0, 0), "tri": Vector3(20, 0, -20), "hip_l": Vector3(-10, 0, 6), "kn_l": Vector3(26, 0, 0), "hip_r": Vector3(-70, 0, -40), "kn_r": Vector3(110, 0, 0), "tail": Vector3(0, 0, 0)},
	"kick": {"hips": Vector3(0, 70, -18), "chest": Vector3(-4, 0, 6), "neck": Vector3(0, -60, 8), "sh_l": Vector3(-60, 0, 26), "el_l": Vector3(-115, 0, 0), "sh_r": Vector3(24, 0, -42), "el_r": Vector3(-20, 0, 0), "tri": Vector3(-10, 0, -40), "hip_l": Vector3(-4, 0, 4), "kn_l": Vector3(14, 0, 0), "hip_r": Vector3(-86, 0, -66), "kn_r": Vector3(8, 0, 0), "tail": Vector3(-20, 0, 0)},
	"knee_chamber": {"hips": Vector3(0, 0, 0), "chest": Vector3(-8, 0, 0), "neck": Vector3(6, 0, 0), "sh_l": Vector3(-110, 0, 20), "el_l": Vector3(-50, 0, 0), "sh_r": Vector3(-100, 0, -20), "el_r": Vector3(-60, 0, 0), "tri": Vector3(10, 0, 0), "hip_l": Vector3(-8, 0, 6), "kn_l": Vector3(20, 0, 0), "hip_r": Vector3(14, 0, -6), "kn_r": Vector3(70, 0, 0), "tail": Vector3(8, 0, 0)},
	"knee": {"hips": Vector3(0, 0, 0), "chest": Vector3(-16, 0, 0), "neck": Vector3(14, 0, 0), "sh_l": Vector3(-64, 0, 12), "el_l": Vector3(-70, 0, 0), "sh_r": Vector3(-60, 0, -12), "el_r": Vector3(-74, 0, 0), "tri": Vector3(10, 0, 0), "hip_l": Vector3(6, 0, 4), "kn_l": Vector3(8, 0, 0), "hip_r": Vector3(-104, 0, -4), "kn_r": Vector3(128, 0, 0), "tail": Vector3(-14, 0, 0), "lift": 0.03},
	"elbow_wind": {"hips": Vector3(0, -24, 0), "chest": Vector3(6, -30, 0), "neck": Vector3(0, 30, 0), "sh_l": Vector3(-70, 0, 70), "el_l": Vector3(-140, 0, 0), "sh_r": Vector3(-20, 0, -30), "el_r": Vector3(-90, 0, 0), "tri": Vector3(10, 0, -10), "hip_l": Vector3(-28, 0, 10), "kn_l": Vector3(40, 0, 0), "hip_r": Vector3(10, 0, -12), "kn_r": Vector3(30, 0, 0), "tail": Vector3(6, 0, 0)},
	"elbow": {"hips": Vector3(0, 24, 0), "chest": Vector3(14, 34, 0), "neck": Vector3(-6, -30, 0), "sh_l": Vector3(-92, -30, 10), "el_l": Vector3(-150, 0, 0), "sh_r": Vector3(-10, 0, -36), "el_r": Vector3(-70, 0, 0), "tri": Vector3(16, 0, -16), "hip_l": Vector3(-40, 0, 10), "kn_l": Vector3(50, 0, 0), "hip_r": Vector3(22, 0, -12), "kn_r": Vector3(18, 0, 0), "tail": Vector3(-12, 0, 0)},
	"yawn_draw": {"hips": Vector3(0, 0, 0), "chest": Vector3(-10, 0, 0), "neck": Vector3(-14, 0, 0), "sh_l": Vector3(-60, 0, 50), "el_l": Vector3(-60, 0, 0), "sh_r": Vector3(-30, 0, -40), "el_r": Vector3(-60, 0, 0), "tri": Vector3(0, 0, -10), "hip_l": Vector3(-12, 0, 16), "kn_l": Vector3(24, 0, 0), "hip_r": Vector3(-6, 0, -16), "kn_r": Vector3(22, 0, 0), "tail": Vector3(-10, 0, 0)},
	"yawn": {"hips": Vector3(0, 0, 0), "chest": Vector3(-22, 0, 0), "neck": Vector3(-28, 0, 0), "sh_l": Vector3(-120, 0, 66), "el_l": Vector3(-24, 0, 0), "sh_r": Vector3(-40, 0, -60), "el_r": Vector3(-30, 0, 0), "tri": Vector3(0, 0, -24), "hip_l": Vector3(-10, 0, 18), "kn_l": Vector3(22, 0, 0), "hip_r": Vector3(-10, 0, -18), "kn_r": Vector3(22, 0, 0), "tail": Vector3(-26, 0, 0)},
	"slam_up": {"hips": Vector3(-10, 0, 0), "chest": Vector3(-16, 0, 0), "neck": Vector3(12, 0, 0), "sh_l": Vector3(-170, 0, 14), "el_l": Vector3(-30, 0, 0), "sh_r": Vector3(-170, 0, -14), "el_r": Vector3(-30, 0, 0), "tri": Vector3(-30, 0, 0), "hip_l": Vector3(-70, 0, 16), "kn_l": Vector3(110, 0, 0), "hip_r": Vector3(-60, 0, -16), "kn_r": Vector3(110, 0, 0), "tail": Vector3(-30, 0, 0), "lift": 0.0},
	"slam": {"hips": Vector3(0, 0, 0), "chest": Vector3(36, 0, 0), "neck": Vector3(-22, 0, 0), "sh_l": Vector3(-70, 0, 26), "el_l": Vector3(-40, 0, 0), "sh_r": Vector3(-74, 0, -10), "el_r": Vector3(-14, 0, 0), "tri": Vector3(150, 0, 0), "hip_l": Vector3(-66, 0, 18), "kn_l": Vector3(100, 0, 0), "hip_r": Vector3(-30, 0, -18), "kn_r": Vector3(96, 0, 0), "tail": Vector3(20, 0, 0)},
	"wai": {"hips": Vector3(0, 0, 0), "chest": Vector3(10, 0, 0), "neck": Vector3(16, 0, 0), "sh_l": Vector3(-52, 0, -10), "el_l": Vector3(-118, -30, 0), "sh_r": Vector3(-14, 0, -12), "el_r": Vector3(-30, 0, 0), "tri": Vector3(0, 0, 0), "hip_l": Vector3(-4, 0, 6), "kn_l": Vector3(8, 0, 0), "hip_r": Vector3(-4, 0, -6), "kn_r": Vector3(8, 0, 0), "tail": Vector3(10, 0, 0)},
}


func _build() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/hanuman_toon.gdshader")
	_mat.set_shader_parameter("detail", 1.0 if VfxBudget.quality() > 0 else 0.0)
	_mat.set_shader_parameter("fade", 0.0)
	if VfxBudget.quality() > 0:
		_line = ShaderMaterial.new()
		_line.shader = preload("res://shaders/hanuman_outline.gdshader")
		_line.set_shader_parameter("width", 0.0045)
		_line.set_shader_parameter("fade", 0.0)
		_mat.next_pass = _line
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.scale = Vector3.ONE * SCALE
	add_child(_rig)
	var hips := _joint("hips", _rig, Vector3.ZERO, "hips")
	var chest := _joint("chest", hips, Vector3(0, HanumanSculpt.WAIST, 0), "torso")
	var neck := _joint("neck", chest, Vector3(0, HanumanSculpt.NECK - 0.012, 0.004), "head")
	neck.get_child(0).scale = Vector3.ONE * HanumanSculpt.HEAD_SCALE
	for side in [["l", 1.0], ["r", -1.0]]:
		var s: String = side[0]
		var x: float = side[1]
		var sh := _joint("sh_" + s, chest, Vector3(x * HanumanSculpt.SHOULDER.x, HanumanSculpt.SHOULDER.y, 0), "upper_" + s)
		var el := _joint("el_" + s, sh, Vector3(0, -HanumanSculpt.UPPER_LEN, 0), "fore_" + s)
		if s == "r":
			_joint("tri", el, Vector3(0, -HanumanSculpt.FORE_LEN - HanumanSculpt.FIST * 0.6, -0.004), "trident")
		var hip := _joint("hip_" + s, hips, Vector3(x * HanumanSculpt.HIP_JOINT.x, HanumanSculpt.HIP_JOINT.y, 0), "thigh")
		_joint("kn_" + s, hip, Vector3(0, -HanumanSculpt.THIGH_LEN, 0), "shin")
	_joint("tail", hips, HanumanSculpt.TAIL_ROOT, "tail")


func _joint(id: String, parent: Node3D, at: Vector3, part: String) -> Node3D:
	var j := Node3D.new()
	j.name = id
	j.position = at
	parent.add_child(j)
	var mi := MeshInstance3D.new()
	mi.mesh = HanumanSculpt.mesh(part)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if not by_hero else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	j.add_child(mi)
	_joints[id] = j
	return j


func _set_fade(f: float) -> void:
	_mat.set_shader_parameter("fade", f)
	if _line:
		_line.set_shader_parameter("fade", f)


## Sets the body between poses [param a] and [param b] at [param t] (eased), the feet planted
## on the floor unless the pose lifts it.
func _pose(a: String, b: String, t: float) -> void:
	if _rig == null:
		return
	var pa: Dictionary = POSES[a]
	var pb: Dictionary = POSES[b]
	var w := clampf(t, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	var angles := {}
	for id: String in JOINTS:
		var deg: Vector3 = (pa.get(id, Vector3.ZERO) as Vector3).lerp(pb.get(id, Vector3.ZERO) as Vector3, w)
		angles[id] = deg
		if id == "tri":
			continue
		(_joints[id] as Node3D).basis = Basis.from_euler(deg * (PI / 180.0))
	# The trident keeps its turn in the chest's frame, whatever the arm does.
	var arm: Basis = (_joints["sh_r"] as Node3D).basis * (_joints["el_r"] as Node3D).basis
	(_joints["tri"] as Node3D).basis = arm.inverse() * Basis.from_euler((angles["tri"] as Vector3) * (PI / 180.0))
	var lift := lerpf(float(pa.get("lift", 0.0)), float(pb.get("lift", 0.0)), w)
	(_joints["hips"] as Node3D).position.y = _plant() + lift
	_pose_a = b if w >= 0.5 else a


## The hip height that puts the lower foot on the floor (figure units).
func _plant() -> float:
	var low := INF
	for s in ["l", "r"]:
		var hip := _joints["hip_" + s] as Node3D
		var knee := _joints["kn_" + s] as Node3D
		var foot := hip.position + hip.basis * (knee.position + knee.basis * Vector3(0, -HanumanSculpt.FOOT_DROP, 0))
		foot = (_joints["hips"] as Node3D).basis * foot
		low = minf(low, foot.y)
	return -low


## Life on top of the pose: the chest breathes, the tail sways.
func _breathe() -> void:
	var tail := _joints.get("tail") as Node3D
	if tail:
		tail.rotate_object_local(Vector3.UP, sin(clock * 3.1) * 0.25)
		tail.rotate_object_local(Vector3.RIGHT, sin(clock * 2.3 + 1.0) * 0.08)
	var chest := _joints.get("chest") as Node3D
	if chest:
		chest.rotate_object_local(Vector3.RIGHT, sin(clock * 5.0) * 0.025)
