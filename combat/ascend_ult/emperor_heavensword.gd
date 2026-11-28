extends "res://combat/ascend_ult/_warrior_lancer_kit.gd"
## ดาบเหินฟ้า (emperor_heavensword): the Warrior's ★500 Ascension ultimate (AscendUlt).
##
## At the release the warrior cuts upward through a gale: every foe within RADIUS m is
## thrown into the air (its body rises FOE_HEIGHT m) and hangs there, unable to act
## (held as a stun) until the slam, AIR seconds later. The warrior leaps up after them and
## flashes from one to the next for AIR_SLASHES slashes (each cuts every foe in the air),
## turns over and drives down at the centre: the slam hammers them all back into the
## ground under a shockwave (the skill's stun and armour break land with it).
## A foe too heavy to throw (a real boss, a castle gate; a guild fighter under its spawn
## guard is not thrown either) stays on the ground: it takes the
## same blows and a short stun (Mob.apply_stun, shortened on a boss) at the launch.
##
## Damage: the whole multiplier, spread over a foe's blows: the launch LAUNCH_SHARE, each
## aerial slash AIR_SHARE, the slam SLAM_SHARE (1.0 in all for a foe caught at the launch);
## a foe that walks in later takes the slam only. The hero's blows go through Hero._deal,
## an AI's through Rival._hit; an AI's ultimate throws AI fighters and monsters into the
## air, never a real player (players are never held: they take the blows only).
##
## Lifetime: a child of the caster's field; the caster falling, leaving, entering a safe
## zone or ending its duel stops it at once (no blow after that) and every body it lifted
## is set back on the ground. Only the bodies' visuals rise (as SkillFeel's throw does):
## positions, collisions and targeting stay on the ground.

const ID := "emperor_heavensword"
const RADIUS := 10.0
## The clock, seconds after the release.
const LEAP := Vector2(0.08, 0.42)
const SLASHES := [0.52, 0.7, 0.88, 1.06]
const DIVE := Vector2(1.26, 1.5)
const SLAM := 1.5
const END := 2.05
## The shares of the whole multiplier: 0.2 + 4 x 0.1 + 0.4 = 1.0.
const LAUNCH_SHARE := 0.2
const AIR_SHARE := 0.1
const SLAM_SHARE := 0.4
const AIR_SLASHES := 4
## How long a thrown foe hangs (its stun): from the launch to the slam.
const AIR := SLAM
## A heavy foe's stun at the launch (Mob.apply_stun keeps 40% of it on a boss: 0.6 s).
const HEAVY_STUN := 1.5
const FOE_HEIGHT := 3.6
const HERO_HEIGHT := 4.3
const RISE := 0.34

## Each foe caught at the launch: {ref, lifted, phase, jolt}.
var caught: Array = []
var center := Vector3.ZERO
var yaw := 0.0
var _slash := 0
var _slammed := false
var _lifted_self := false
var _air_off := Vector3.ZERO
var _air_face := 0.0
var _draft: MeshInstance3D
var _draft_mat: ShaderMaterial


## The hero's cast stays locked until the warrior has landed.
static func lead(_skill: Dictionary) -> float:
	return END - 0.1


func begin_hero(hero: Hero, p_skill: Dictionary, _aim: Vector3, _target: Mob) -> void:
	_setup_hero(hero, p_skill)
	_begin()


func begin_rival(rival: Rival, p_skill: Dictionary, _aim: Vector3, _target: Node3D) -> void:
	_setup_rival(rival, p_skill)
	_begin()


func _begin() -> void:
	if not _caller_ok():
		queue_free()
		return
	center = Vector3(caster.global_position.x, caster.global_position.y, caster.global_position.z)
	global_position = center
	yaw = _caster_yaw()
	_air_face = yaw
	var visual := _body_visual()
	var riding := caster is Hero and (caster as Hero).is_riding()
	if visual != null and not riding:
		_lifted_self = true
		caster.set_meta("star_airborne", true)
	_launch()


func _process(delta: float) -> void:
	if done:
		return
	if not _caller_ok():
		_stop()
		return
	clock += delta
	_fly_foes()
	_fly_self(delta)
	if _draft_mat:
		_draft_mat.set_shader_parameter("age", clock)
		_draft_mat.set_shader_parameter("fade", 1.0 - smoothstep(0.4, 1.0, clock))
	while _slash < SLASHES.size() and clock >= float(SLASHES[_slash]):
		_aerial(_slash)
		_slash += 1
	if not _slammed and clock >= SLAM:
		_slam()
	if clock >= END:
		_stop()


func _stop() -> void:
	done = true
	_settle_all()
	queue_free()


func _exit_tree() -> void:
	done = true
	_settle_all()


# ---------------------------------------------------------------------------
# The three moves
# ---------------------------------------------------------------------------

## The rising slash: everything round the warrior goes up.
func _launch() -> void:
	var foes := _foes(center, RADIUS)
	var fwd := _forward(yaw)
	_with_room(func():
		VfxKit.slash_arc(_field, center + Vector3.UP * 1.7 + fwd * 0.9, yaw, light, 5.2, PI * 0.5)
		VfxKit.impact_ring(_field, center + Vector3.UP * 0.08, color, RADIUS, 0.55, light, shade)
		VfxKit.flash(_field, center + Vector3.UP * 1.4 + fwd * 0.6, light, 3.4, 0.3)
		VfxArt.ribbon_spiral(_field, center, light, 6.5, 2.2, 1.0, RADIUS * 0.32)
		if shown:
			_draft = _funnel(self, RADIUS * 0.3, RADIUS * 0.55, 6.5, {"spin": 1.4, "rise": 2.6, "twist": 0.9, "bands": 13.0, "top_soft": 0.55, "foot_soft": 0.1, "gain": 0.55})
			if _draft:
				_draft_mat = _draft.material_override as ShaderMaterial
		for foe: Node3D in foes:
			VfxKit.pillar(_field, foe.global_position, color, 4.8, 0.55, 0.45, light)
			VfxKit.sparks(_field, foe.global_position + Vector3.UP * 0.3, light, 10, 4.5, 0.45)
	)
	_sound(SkillSound.star_beat(0), -3.0)
	_sound(&"skill_wind", -6.0)
	_beat(center, RADIUS, 0, 2 + AIR_SLASHES)
	for foe: Node3D in foes:
		# A guild fighter fresh from its base (spawn guard) shrugs it off as it shrugs off stuns.
		var guarded := foe.has_method("under_guard") and bool(foe.call("under_guard"))
		var lifted := not heavy(foe) and not guarded and foe is Mob and is_instance_valid((foe as Mob).visual)
		caught.append({"ref": weakref(foe), "lifted": lifted, "phase": randf() * TAU, "jolt": 0.0, "spin": randf_range(-1.0, 1.0)})
		if lifted:
			var mob := foe as Mob
			mob._stun = maxf(mob._stun, AIR + 0.05)
			mob._winding = false
			_unfeel(mob)
		elif foe is Mob and foe.has_method("apply_stun"):
			(foe as Mob).apply_stun(HEAVY_STUN)
		_strike(foe, LAUNCH_SHARE, false)
		_unfeel(foe)
	_beat_done()
	_act(["Jump_Full_Short", "Jump_Full_Long", "Jump_Start"], 1.4)


## One aerial slash: the warrior flashes to the next foe, every foe in the air is cut.
func _aerial(k: int) -> void:
	var live := _live()
	var spot := center + Vector3.UP * HERO_HEIGHT
	if not live.is_empty():
		var aim: Node3D = live[k % live.size()]
		var to := _flat(aim.global_position - center)
		var reach := maxf(0.0, to.length() - _body(aim) - 1.1)
		_air_off = to.normalized() * reach if to.length() > 0.01 else Vector3.ZERO
		spot = center + _air_off + Vector3.UP * HERO_HEIGHT
		if to.length() > 0.01:
			_air_face = atan2(to.x, to.z)
	var ring_yaw := yaw + float(k) * PI * 0.5
	_with_room(func():
		VfxKit.slash_arc(_field, center + Vector3.UP * (FOE_HEIGHT + 0.9), ring_yaw, color, RADIUS * 0.85, 0.18 * (1.0 if k % 2 == 0 else -1.0))
		VfxKit.flash(_field, spot + Vector3.UP * 0.8, light, 1.8, 0.16)
		for foe: Node3D in live:
			var at := _air_point(foe)
			VfxKit.slash_arc(_field, at, _air_face + (0.6 if k % 2 == 0 else -0.6), light, 2.7, 0.7 if k % 2 == 0 else -0.7)
			VfxKit.impact(_field, at, color, 1.0)
		if k == AIR_SLASHES - 1:
			VfxArt.cross_slash(_field, spot + Vector3.UP * 0.6, _air_face, light, 3.2)
	)
	if k == AIR_SLASHES - 1:
		_dive_mark()
	_sound(SkillSound.star_beat(k + 1), -7.0)
	_beat(spot, 3.0, k + 1, 2 + AIR_SLASHES)
	for foe: Node3D in live:
		if _strike(foe, AIR_SHARE, false):
			_jolt(foe)
		_unfeel(foe)
	_beat_done()
	_act(["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "2H_Melee_Attack_Spin", "1H_Melee_Attack_Chop"].slice(k % 4) + ["1H_Melee_Attack_Chop"], 1.8)


## The slam: down at the centre, every foe driven into the ground.
func _slam() -> void:
	_slammed = true
	var foes := _live()
	for foe: Node3D in _foes(center, RADIUS):
		if not foes.has(foe):
			foes.append(foe)
	_settle_all()
	_with_room(func():
		VfxKit.slam(_field, center, color, RADIUS)
		VfxKit.flash(_field, center + Vector3.UP * 1.0, light, 5.5, 0.35)
		VfxArt.rays_burst(_field, center + Vector3.UP * 0.6, light, 4.5, 0.4)
		VfxKit.spikes(_field, center, RADIUS * 0.7, Color("c9b48a"), 12, 1.4, 0.18)
		VfxKit.impact_ring(_field, center + Vector3.UP * 0.1, light, RADIUS * 1.05, 0.6, light, shade)
		for foe: Node3D in foes:
			VfxKit.impact_smoke(_field, foe.global_position + Vector3.UP * 0.2, Color("d9c4a0"), 1.3)
			VfxKit.impact(_field, _hit_point(foe), color, 1.3)
	)
	_sound(SkillSound.landing(skill), -3.0)
	_sound(SkillSound.star_beat(0), -4.0)
	_beat(center, RADIUS, 1 + AIR_SLASHES, 2 + AIR_SLASHES)
	for foe: Node3D in foes:
		_strike(foe, SLAM_SHARE, true)
	_beat_done()
	_act(["Martial_GroundSlam", "1H_Melee_Attack_Chop"], 1.6)


## Where the warrior will come down: a ring of light on the ground at the centre, closing.
func _dive_mark() -> void:
	_with_room(func():
		VfxKit.impact_ring(_field, center + Vector3.UP * 0.08, light, RADIUS * 0.55, DIVE.y - SLASHES[AIR_SLASHES - 1], light, shade)
		VfxArt.beam(_field, center + Vector3.UP * (HERO_HEIGHT + 2.5), center + Vector3.UP * 0.1, light, 0.6, DIVE.y - SLASHES[AIR_SLASHES - 1] + 0.1)
	)


# ---------------------------------------------------------------------------
# Bodies in the air
# ---------------------------------------------------------------------------

## The caught foes still standing (in the air or, heavy, on the ground).
func _live() -> Array:
	var out: Array = []
	for entry: Dictionary in caught:
		var foe := (entry.ref as WeakRef).get_ref() as Node3D
		if _valid(foe):
			out.append(foe)
	return out


func _entry(foe: Node3D) -> Dictionary:
	for entry: Dictionary in caught:
		if (entry.ref as WeakRef).get_ref() == foe:
			return entry
	return {}


func _jolt(foe: Node3D) -> void:
	var entry := _entry(foe)
	if not entry.is_empty():
		entry.jolt = 0.55


## Where a foe's body is now (lifted with its visual).
func _air_point(foe: Node3D) -> Vector3:
	var at := _hit_point(foe)
	var entry := _entry(foe)
	if not entry.is_empty() and bool(entry.lifted) and foe is Mob:
		at.y += (foe as Mob).visual.position.y
	return at


## The thrown bodies' flight: up, hanging (bobbing, knocked higher by each cut), down at the slam.
func _fly_foes() -> void:
	var delta := get_process_delta_time()
	for entry: Dictionary in caught:
		if not bool(entry.lifted):
			continue
		var mob := (entry.ref as WeakRef).get_ref() as Mob
		if mob == null or not is_instance_valid(mob) or not is_instance_valid(mob.visual):
			continue
		if mob.is_dead():
			_ground(mob)
			entry.lifted = false
			continue
		_unfeel(mob)
		entry.jolt = maxf(0.0, float(entry.jolt) - delta * 2.4)
		var up := smoothstep(0.0, RISE, clock) * (1.0 - pow(clampf((clock - DIVE.x) / (SLAM - DIVE.x), 0.0, 1.0), 2.0))
		var bob := sin(clock * 5.0 + float(entry.phase)) * 0.12 * up
		mob.visual.position.y = FOE_HEIGHT * up + bob + float(entry.jolt) * up
		mob.visual.rotation.x = -0.9 * up * (0.6 + 0.4 * sin(clock * 3.0 + float(entry.phase)))
		mob.visual.rotation.z = float(entry.spin) * 0.35 * up


## The warrior's own leap: up after them, across to each foe, over and down to the centre.
func _fly_self(delta: float) -> void:
	if not _lifted_self:
		return
	var visual := _body_visual()
	if visual == null:
		return
	var up := 0.0
	if clock < LEAP.y:
		up = smoothstep(LEAP.x, LEAP.y, clock)
	elif clock < DIVE.x:
		up = 1.0 + sin((clock - LEAP.y) * 6.0) * 0.03
	elif clock < SLAM:
		var p := (clock - DIVE.x) / (SLAM - DIVE.x)
		up = (1.0 + 0.22 * sin(p * PI)) * (1.0 - p * p * p)
	var off := _air_off if clock < DIVE.x else Vector3.ZERO
	var cur := Vector3(visual.position.x, 0.0, visual.position.z)
	cur = cur.lerp(off, 1.0 - exp(-(26.0 if clock < DIVE.x else 18.0) * delta))
	visual.position = Vector3(cur.x, HERO_HEIGHT * up, cur.z)
	# Facing each foe in the air, a front flip into the dive.
	if caster is Hero:
		visual.rotation.y = lerp_angle(visual.rotation.y, _air_face if clock < DIVE.x else yaw, 1.0 - exp(-20.0 * delta))
	var flip := clampf((clock - DIVE.x) / (SLAM - DIVE.x - 0.04), 0.0, 1.0) if clock < SLAM else 0.0
	visual.rotation.x = -TAU * smoothstep(0.0, 1.0, flip) if clock < SLAM else 0.0
	if clock >= SLAM:
		_land_self()


func _land_self() -> void:
	if not _lifted_self:
		return
	_lifted_self = false
	var visual := _body_visual()
	if is_instance_valid(caster):
		caster.remove_meta("star_airborne")
	if visual != null:
		visual.position = Vector3.ZERO
		visual.rotation.x = 0.0
		if caster is Hero:
			visual.rotation.y = float((caster as Hero)._facing)


## SkillFeel's own throw of a struck body would fight this flight: it is let go.
func _unfeel(foe: Node3D) -> void:
	if not (foe is Mob) or not is_instance_valid((foe as Mob).visual):
		return
	var entry := _entry(foe)
	if entry.is_empty() or not bool(entry.lifted):
		return
	var visual := (foe as Mob).visual
	for key in [&"feel_arc", &"feel_tilt"]:
		if visual.has_meta(key):
			var tw: Variant = visual.get_meta(key)
			if tw is Tween and (tw as Tween).is_valid():
				(tw as Tween).kill()
			visual.remove_meta(key)


func _ground(mob: Mob) -> void:
	if is_instance_valid(mob) and is_instance_valid(mob.visual):
		mob.visual.position.y = 0.0
		mob.visual.rotation.x = 0.0
		mob.visual.rotation.z = 0.0


## Every body back on the ground (the slam, or the cast cut short).
func _settle_all() -> void:
	for entry: Dictionary in caught:
		if bool(entry.lifted):
			var mob := (entry.ref as WeakRef).get_ref() as Mob
			_ground(mob)
			entry.lifted = false
	_land_self()
