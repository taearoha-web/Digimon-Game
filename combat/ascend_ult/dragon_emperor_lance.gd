extends "res://combat/ascend_ult/_warrior_lancer_kit.gd"
## หอกพายุบูมเมอแรง (dragon_emperor_lance): the Lancer's ★500 Ascension ultimate (AscendUlt).
##
## At the release the lancer hurls a giant lance, spinning flat like a boomerang, REACH m
## the way it faces. Spinning, it whips the air into a storm: a funnel of wind STORM m
## round it that travels with it. It sweeps out on a wide curve, hangs a moment spinning at
## the far end, then curves back the other side to the lancer's hand and is caught.
## Every foe the storm touches on the way out takes OUT_SHARES (one blow on contact, two
## more as the storm grinds through it); on the way back it is struck again (BACK_SHARES,
## the last carrying the skill's stun and armour break) and each of those blows drags it
## PULL m along towards the lancer (MuayThai.kick: walls and the guild war's rules hold;
## a real boss stands its ground). A foe the storm touches both ways takes the whole
## multiplier (0.35 + 0.65); one it touches only one way takes that pass's share.
##
## The hero's blows go through Hero._deal, an AI's through Rival._hit (its pull moves AI
## fighters and players by the same rules as MuayThai's kicks). Lifetime: a child of the
## caster's field; the caster falling, leaving, entering a safe zone or ending its duel
## stops it at once (no blow after that, the lance and the storm gone, the weapon back in
## its hand).

const ID := "dragon_emperor_lance"
const K := preload("res://combat/god_art/_kit_melee.gd")
const SOLID := preload("res://shaders/god_melee_solid.gdshader")
const REACH := 14.0
## The storm's reach round the lance (flat metres, plus the foe's body).
const STORM := 2.4
## How far the boomerang's curve swings out to the side, out on one side, back the other.
const SWING := 1.6
## The clock, seconds after the release: out, a hang at the far end, back to the hand.
const OUT := 0.72
const HANG := 0.24
const BACK := 0.64
const CATCH := OUT + HANG + BACK
const END := CATCH + 0.36
## A pass's blows: on contact and two grinding after (seconds after the contact).
const TICKS := [0.0, 0.12, 0.24]
const OUT_SHARES := [0.15, 0.1, 0.1]
const BACK_SHARES := [0.2, 0.15, 0.3]
const PULL := 0.6
## The lance: length (m), spin (rad/s), the height it flies at.
const LANCE := 6.6
const SPIN := 15.0
const FLY_Y := 1.35
static var _lance_mesh: ArrayMesh

var origin := Vector3.ZERO
var yaw := 0.0
var fwd := Vector3.FORWARD
var side := Vector3.RIGHT
var apex := Vector3.ZERO
## Where the storm is now, and on which pass (0 out, 1 back).
var storm_at := Vector3.ZERO
var leg := 0
var caught_on := [{}, {}]
var _due: Array = []
var _storm: Node3D
var _lance: MeshInstance3D
var _lance_mat: ShaderMaterial
var _winds: Array[ShaderMaterial] = []
var _grip: Node3D
var _caught := false
var _puff := 0.0


## The hero's cast stays locked until the lance is back in hand.
static func lead(_skill: Dictionary) -> float:
	return CATCH + 0.15


func begin_hero(hero: Hero, p_skill: Dictionary, _aim: Vector3, _target: Mob) -> void:
	_setup_hero(hero, p_skill)
	_begin()


func begin_rival(rival: Rival, p_skill: Dictionary, aim: Vector3, target: Node3D) -> void:
	_setup_rival(rival, p_skill)
	# An AI throws at what it aimed at (it faces it, but its yaw turns smoothly).
	var to := _flat((target.global_position if is_instance_valid(target) else aim) - rival.global_position)
	if to.length() > 0.5:
		rival._yaw = atan2(to.x, to.z)
	_begin()


func _begin() -> void:
	if not _caller_ok():
		queue_free()
		return
	origin = caster.global_position
	yaw = _caster_yaw()
	fwd = _forward(yaw)
	side = Vector3(fwd.z, 0.0, -fwd.x)
	apex = origin + fwd * REACH
	storm_at = origin + fwd * 0.8
	global_position = storm_at
	_build()
	_hide_weapon(true)
	var hand := _hand()
	_with_room(func():
		VfxKit.flash(_field, hand, light, 2.4, 0.25)
		VfxKit.slash_arc(_field, origin + Vector3.UP * FLY_Y + fwd * 0.9, yaw, light, 3.6, 0.0)
		VfxKit.impact_ring(_field, origin + Vector3.UP * 0.1, color, 3.0, 0.4, light, shade)
		VfxKit.sparks(_field, hand, light, 16, 6.0, 0.4)
	)
	_sound(SkillSound.star_beat(0), -3.0)
	_sound(&"skill_wind", -5.0)
	_beat(storm_at, STORM, 0, 3)
	_beat_done()
	_place()


func _process(delta: float) -> void:
	if done:
		return
	if not _caller_ok():
		_stop()
		return
	clock += delta
	_place()
	_spin(delta)
	_touch()
	_land_due()
	if not _caught and clock >= CATCH:
		_catch()
	if clock >= END:
		_stop()


func _stop() -> void:
	done = true
	_due.clear()
	_hide_weapon(false)
	queue_free()


func _exit_tree() -> void:
	done = true
	_hide_weapon(false)


# ---------------------------------------------------------------------------
# The flight
# ---------------------------------------------------------------------------

## The storm's spot at the cast's clock: out on a curve, a hang, back on the other side.
func _path(t: float) -> Vector3:
	if t <= OUT:
		var e := 1.0 - pow(1.0 - t / OUT, 2.0)
		return origin + fwd * lerpf(0.8, REACH, e) + side * SWING * sin(PI * e)
	if t <= OUT + HANG:
		var h := (t - OUT) / HANG
		return apex + side * 0.35 * sin(h * TAU) + fwd * 0.35 * sin(h * PI)
	var p := clampf((t - OUT - HANG) / BACK, 0.0, 1.0)
	var e2 := p * p * (1.6 - 0.6 * p)
	var hand := _flat(caster.global_position) + Vector3.UP * origin.y if is_instance_valid(caster) else origin
	var to := _flat(hand - apex)
	var across := Vector3(to.z, 0.0, -to.x).normalized() if to.length() > 0.01 else side
	return apex.lerp(hand, e2) + across * SWING * sin(PI * e2)


func _place() -> void:
	var t := minf(clock, CATCH)
	storm_at = _path(t)
	leg = 0 if t <= OUT + HANG else 1
	global_position = storm_at
	if is_instance_valid(_storm):
		# The storm grows on the way out, shrinks into the hand at the catch.
		var grow := smoothstep(0.0, 0.25, clock) * (1.0 - smoothstep(CATCH - 0.22, CATCH, clock))
		_storm.scale = Vector3.ONE * maxf(0.05, grow)
		_storm.visible = not _caught


func _spin(delta: float) -> void:
	if is_instance_valid(_lance):
		_lance.rotation.y += SPIN * delta
	for i in _winds.size():
		_winds[i].set_shader_parameter("age", clock * (1.0 + 0.35 * float(i)))
	if _lance_mat:
		_lance_mat.set_shader_parameter("age", 10.0 + clock)
	# Dust kicked up under the storm as it goes.
	_puff -= delta
	if _puff <= 0.0 and not _caught and shown:
		_puff = 0.12 if VfxBudget.quality() > 1 else 0.24
		var foot := Vector3(storm_at.x, origin.y + 0.15, storm_at.z)
		_with_room(func():
			VfxKit.impact_smoke(_field, foot, Color("cfe6ee"), 1.2)
			if VfxBudget.quality() > 0:
				VfxKit.sparks(_field, foot + Vector3.UP * 1.2, light, 6, 5.0, 0.35)
		)


## Who the storm touches now: each foe once a pass, its blows queued.
func _touch() -> void:
	if clock > CATCH:
		return
	var seen: Dictionary = caught_on[leg]
	var shares: Array = OUT_SHARES if leg == 0 else BACK_SHARES
	for foe: Node3D in _foes(storm_at, STORM):
		var key := foe.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		for i in TICKS.size():
			_due.append({"at": clock + float(TICKS[i]), "ref": weakref(foe), "share": float(shares[i]), "leg": leg, "last": leg == 1 and i == TICKS.size() - 1, "first": i == 0})


## The queued blows whose time has come.
func _land_due() -> void:
	if _due.is_empty():
		return
	var now: Array = []
	var later: Array = []
	for d: Dictionary in _due:
		(now if float(d.at) <= clock else later).append(d)
	_due = later
	if now.is_empty():
		return
	# A light beat of the hero's feel round the blows of this moment (it holds SkillFeel's
	# throw: the storm drags its foes, it does not toss them away).
	_beat(storm_at, STORM, 1, 3)
	for d: Dictionary in now:
		var foe := (d.ref as WeakRef).get_ref() as Node3D
		if not _valid(foe):
			continue
		var at := _hit_point(foe)
		if _strike(foe, float(d.share), bool(d.last)):
			_with_room(func():
				VfxKit.impact(_field, at, color, 1.1 if bool(d.first) else 0.75)
				if bool(d.first):
					VfxKit.slash_arc(_field, at, yaw + clock * SPIN, light, 2.2, 0.25)
			)
			if int(d.leg) == 1:
				_pull(foe)
	_beat_done()


## Dragged along with the storm, towards the lancer (never past its reach of the hand).
func _pull(foe: Node3D) -> void:
	if not _valid(foe) or not is_instance_valid(caster) or heavy(foe):
		return
	var to := _flat(caster.global_position - foe.global_position)
	var room := to.length() - _body(foe) - 1.2
	if room <= 0.05:
		return
	var from := foe.global_position - to.normalized()
	MuayThai.kick(foe, from, minf(PULL, room), caster)


func _catch() -> void:
	_caught = true
	if is_instance_valid(_storm):
		_storm.visible = false
	_hide_weapon(false)
	var hand := _hand()
	_with_room(func():
		VfxKit.flash(_field, hand, light, 3.0, 0.3)
		VfxKit.impact_ring(_field, Vector3(caster.global_position.x, caster.global_position.y + 0.1, caster.global_position.z), color, 2.6, 0.45, light, shade)
		VfxKit.sparks(_field, hand, light, 22, 5.5, 0.5)
		VfxArt.ribbon_spiral(_field, caster.global_position, light, 2.6, 2.0, 0.6, 0.9)
	)
	_sound(SkillSound.landing(skill), -5.0)
	_beat(caster.global_position, 3.0, 2, 3)
	_beat_done()
	_act(["2H_Melee_Attack_Spin", "2H_Melee_Attack_Spinning", "Cheer"], 1.7)


# ---------------------------------------------------------------------------
# The lance and its storm
# ---------------------------------------------------------------------------

func _build() -> void:
	_storm = Node3D.new()
	_storm.name = "Storm"
	add_child(_storm)
	if not shown:
		return
	_with_room(func():
		if VfxBudget.can_decorate():
			_lance = MeshInstance3D.new()
			_lance.name = "StormLance"
			_lance.mesh = _lance_geometry()
			_lance_mat = ShaderMaterial.new()
			_lance_mat.shader = SOLID
			_lance_mat.set_shader_parameter("age", 10.0)
			_lance_mat.set_shader_parameter("rim_color", light)
			_lance_mat.set_shader_parameter("rim", 0.8)
			_lance_mat.set_shader_parameter("glow_color", color.lerp(light, 0.4))
			_lance.material_override = _lance_mat
			_lance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_storm.add_child(_lance)
			_lance.position = Vector3.UP * FLY_Y
			_lance.rotation = Vector3(0.0, yaw, 0.12)
			_lance.scale = Vector3.ONE * LANCE
			VfxBudget.track_decoration(_lance)
		var outer := _funnel(_storm, STORM * 0.38, STORM * 1.2, 6.2, {"spin": 2.4, "rise": 1.4, "twist": 1.7, "bands": 5.0, "top_soft": 0.35, "foot_soft": 0.12, "gain": 1.9})
		if outer:
			_winds.append(outer.material_override as ShaderMaterial)
		if VfxBudget.quality() > 0:
			var inner := _funnel(_storm, STORM * 0.2, STORM * 0.7, 4.8, {"spin": 3.6, "rise": 2.0, "twist": 2.4, "bands": 7.0, "top_soft": 0.35, "foot_soft": 0.1, "gain": 1.3, "color": light, "core": Color.WHITE})
			if inner:
				_winds.append(inner.material_override as ShaderMaterial)
	)


## The thrown lance, lying along +X (centred on its middle, 1 long): a storm-blue shaft
## wound with silver, a long leaf blade with a white-hot spine, a dragon-horned guard and
## a counterweight spike at the butt.
static func _lance_geometry() -> ArrayMesh:
	if _lance_mesh != null:
		return _lance_mesh
	var p := K.Part.new()
	var shaft := Color("1d3a7a")
	var silver := Color("cfe4f2")
	var steel := Color("7f9cc0")
	var glow := Color("6fe0ff")
	p.ink(shaft, 0.35)
	p.tube(Vector3(-0.42, 0, 0), Vector3(0.22, 0, 0), 0.024, 0.024, 8)
	p.ink(silver, 0.8, 0.15)
	for x in [-0.3, -0.16, -0.02, 0.1]:
		p.tube(Vector3(x, 0, 0), Vector3(x + 0.025, 0, 0), 0.032, 0.032, 8)
	# The guard: a collar and four horns swept back.
	p.ink(steel, 0.7)
	p.tube(Vector3(0.2, 0, 0), Vector3(0.26, 0, 0), 0.03, 0.055, 8)
	for i in 4:
		var a := PI / 4.0 + PI / 2.0 * float(i)
		var d := Vector3(0, cos(a), sin(a))
		p.ink(glow, 0.5, 0.5)
		p.tube(Vector3(0.25, 0, 0) + d * 0.04, Vector3(0.15, 0, 0) + d * 0.13, 0.02, 0.0, 4)
	# The blade: a long flat leaf, its spine burning white-blue.
	p.ink(steel, 1.0)
	p.tube(Vector3(0.26, 0, 0), Vector3(0.36, 0, 0), 0.045, 0.1, 4, 0.25, false)
	p.tube(Vector3(0.36, 0, 0), Vector3(0.5, 0, 0), 0.1, 0.0, 4, 0.25, false)
	p.ink(glow, 0.0, 1.0)
	p.box(Vector3(0.38, 0, 0), Vector3(0.2, 0.016, 0.026))
	# The butt: a counterweight and a short spike (it spins balanced).
	p.ink(steel, 0.8)
	p.tube(Vector3(-0.42, 0, 0), Vector3(-0.46, 0, 0), 0.042, 0.042, 8)
	p.tube(Vector3(-0.46, 0, 0), Vector3(-0.5, 0, 0), 0.042, 0.0, 6)
	var st := K.begin()
	K.stamp(st, p)
	_lance_mesh = K.finish(st)
	return _lance_mesh


## The hand that throws and catches (the weapon grip, else at the chest).
func _hand() -> Vector3:
	var hv := _hero_visual()
	if hv != null:
		return hv.skill_emission_position()
	return (caster.global_position if is_instance_valid(caster) else origin) + Vector3.UP * 1.3


## The held lance goes with the throw and comes back with the catch.
func _hide_weapon(hide: bool) -> void:
	if hide:
		var hv := _hero_visual()
		if hv != null and is_instance_valid(hv._emission_grip) and hv._emission_grip.visible:
			_grip = hv._emission_grip
			_grip.visible = false
	elif is_instance_valid(_grip):
		_grip.visible = true
		_grip = null
