class_name EternalDawnJudgment
extends Node3D
## เทวทูตคุ้มชีวิต (the Priest's ★500 ultimate, AscendUlt; id eternal_dawn_judgment): a guardian
## angel descends on the aimed point in a burst of holy light, then flies to its caster's
## side and guards the party for WARD seconds. Anyone it guards who would fall in that time
## gets back up at once with REVIVE_HP of their HP instead, and a holy explosion bursts round
## them; each guarded member is saved at most once a cast.
##
##   descent   DESCEND_AT s after the release: every foe within the skill's radius of the
##             aimed point takes DESCENT_SHARE of the skill's whole multiplier (and its fx:
##             the 1.5 s stun).
##   revive    a guarded member's fall (Hero / Companion / Rival / GuildFighter _die call
##             spare first) is turned into REVIVE_HP of max HP; next frame foes within
##             REVIVE_RADIUS m of them take REVIVE_SHARE (no fx). A foe takes at most
##             REVIVE_POOL from the explosions of one cast (two of them), so the descent and
##             the explosions together never pass the whole multiplier on one target.
##
## Who is guarded: the hero's cast, the hero and its companions (in a guild war only its own
## party: GuildWarMatch.buff_reaches); an AI player's, itself, and for a guild fighter its
## own guild's party (and the hero, when the fighter is in the hero's party). The caster
## deals every blow: the hero's through Hero._deal, an AI's through Rival._hit.
##
## Lifetime: a child of the caster's field (a zone change frees it); the caster gone, dead
## (once its own save is spent), off the field, in a safe zone or out of its duel ends the
## ward at once. The angel is not a body: nothing targets it. An AI caster's angel shows only
## while fewer than MAX_AI_SHOWN others do and the quality is above low (the bursts and the
## saves still play, budget-gated).

const ID := "eternal_dawn_judgment"
const WARD := 10.0
const DESCEND_AT := 0.55
const DESCENT_SHARE := 0.6
const REVIVE_SHARE := 0.2
const REVIVE_POOL := 0.4
const REVIVE_HP := 0.3
const REVIVE_RADIUS := 5.0
## The angel's glide from the aimed point to the caster's side, and its exit.
const GLIDE_FROM := 1.2
const GLIDE_TIME := 0.7
const EXIT := 0.8
const MAX_AI_SHOWN := 2
const GOLD := Color("ffd84a")
const WHITE := Color("ffffff")
const ROSE := Color("8a4a6a")
const SPIRIT := preload("res://shaders/ascend_spirit.gdshader")

static var _live: Array = []

var caster: Node3D
var skill: Dictionary = {}
var total_mult := 0.0
var by_hero := false
var shown := true
var clock := 0.0
var center := Vector3.ZERO
var gone := false
## For tests: shares of total_mult each foe (instance id) took, the members saved (instance
## id -> true), how many saves and whether the descent landed.
var dealt: Dictionary = {}
var saved: Dictionary = {}
var saves := 0
var descended := false

var _field: Node3D
var _zone: StringName
var _exploded_on: Dictionary = {}
var _angel: Node3D
var _wings: Array[Node3D] = []
var _mats: Array[ShaderMaterial] = []
var _lit: Array[MeshInstance3D] = []
var _halos: Dictionary = {}
var _spot := Vector3.ZERO
var _glide_from := Vector3.ZERO
var _yaw := 0.0
var _beat_fx := {}


# ---------------------------------------------------------------------------
# The casts (AscendUlt)
# ---------------------------------------------------------------------------

func begin_hero(hero: Hero, p_skill: Dictionary, aim: Vector3, _target: Mob) -> void:
	_start(hero, p_skill, aim, float(p_skill.get("mult", 0.0)) * hero.rank_mult(p_skill), true)


func begin_rival(rival: Rival, p_skill: Dictionary, aim: Vector3, _target: Node3D) -> void:
	var mult := float(p_skill.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(p_skill))
	_start(rival, p_skill, aim, mult, false)


func _start(who: Node3D, p_skill: Dictionary, aim: Vector3, mult: float, hero_side: bool) -> void:
	caster = who
	skill = p_skill
	total_mult = mult
	by_hero = hero_side
	_field = get_parent() as Node3D
	_zone = Game.current_zone
	center = Vector3(aim.x, who.global_position.y, aim.z)
	shown = hero_side or (VfxBudget.quality() > 0 and _shown_count() < MAX_AI_SHOWN)
	_beat_fx = {"id": ID + "_revive", "name": String(skill.get("name", "")), "class": &"priest", "star": 0, "shape": "blast", "level": 100, "color": GOLD, "vfx": &"light", "fx": {}}
	_yaw = _caster_yaw()
	_live.append(weakref(self))
	global_position = center
	if shown:
		_build_angel()
		_angel.global_position = center + Vector3.UP * 12.0
	_with_room(func():
		VfxArt.sky_strike(_field, center, GOLD, 2.4, 16.0, 0.7)
		VfxArt.motes(_field, center + Vector3.UP * 6.0, WHITE, "star", 18, 2.0, 1.0, 1.0)
	)
	if by_hero:
		BattleVfx.floating_text(_field, caster.global_position + Vector3.UP * 3.2, String(skill.get("name", "")), GOLD, 1.0)


# ---------------------------------------------------------------------------
# The ward (Hero / Companion / Rival / GuildFighter._die)
# ---------------------------------------------------------------------------

## Every ward still guarding.
static func active() -> Array:
	var out: Array = []
	var keep: Array = []
	for ref: WeakRef in _live:
		var w := ref.get_ref() as EternalDawnJudgment
		if is_instance_valid(w) and not w.is_queued_for_deletion() and not w.gone:
			keep.append(ref)
			out.append(w)
	_live = keep
	return out


## Called by a party member about to fall: true when a ward catches it (it stands again with
## REVIVE_HP of its HP and must not die), false to let it fall.
static func spare(member: Node) -> bool:
	if _live.is_empty() or member == null or not is_instance_valid(member):
		return false
	for w: EternalDawnJudgment in active():
		if w._guarding() and w.covers(member) and not w.saved.has(member.get_instance_id()):
			w._save(member as Node3D)
			return true
	return false


## The ward is up: its time not out and its caster still commanding it.
func _guarding() -> bool:
	return not gone and clock < WARD and _caster_ok()


## [param member] is one of the caster's party.
func covers(member: Node) -> bool:
	if member == caster:
		return true
	if not (member is Node3D) or not member.is_inside_tree():
		return false
	if by_hero:
		return member.is_in_group("companions") and GuildWarMatch.buff_reaches(caster, member)
	if caster is GuildFighter:
		var gf := caster as GuildFighter
		if member is GuildFighter:
			return (member as GuildFighter).team == gf.team and GuildWarMatch.buff_reaches(gf, member)
		if member is Hero:
			return gf.team == GuildFighter.TEAM_ALLY and GuildWarMatch.buff_reaches(gf, member)
	return false


func _save(member: Node3D) -> void:
	saved[member.get_instance_id()] = true
	saves += 1
	_restore(member)
	var at := member.global_position
	_with_room(func():
		VfxKit.heal(_field, at, GOLD)
		VfxArt.star_flash(_field, at + Vector3.UP * 1.4, WHITE, 2.6, 0.4)
		if shown and is_instance_valid(_angel):
			VfxArt.beam(_field, _angel.global_position + Vector3.UP * 2.6, at + Vector3.UP * 1.2, GOLD, 0.5, 0.45)
	)
	BattleVfx.floating_text(_field, at + Vector3.UP * 3.0, "เทวทูตคุ้มชีวิต!", GOLD, 1.2)
	_sound(&"heal", -4.0)
	_drop_halo(member.get_instance_id())
	# The blast waits for the frame's end: the fall comes from inside someone's blow.
	_explode.call_deferred(weakref(member), at)


## Back on its feet with REVIVE_HP of its HP.
static func _restore(member: Node3D) -> void:
	if member is Hero:
		var hero := member as Hero
		Game.profile.hp = maxi(1, int(round(float(hero.stats.max_hp) * REVIVE_HP)))
		return
	if "hp" in member and "max_hp" in member:
		var top := maxi(1, int(member.get("max_hp")))
		var hp := maxi(1, int(round(float(top) * REVIVE_HP)))
		member.set("hp", hp)
		if member.has_method("_update_bar"):
			member.call("_update_bar")
		else:
			var bar: Variant = member.get("_bar")
			if bar is FieldHpBar:
				(bar as FieldHpBar).set_ratio(float(hp) / float(top))


## The holy explosion round a saved member: REVIVE_SHARE on each foe within REVIVE_RADIUS,
## never past REVIVE_POOL a foe this cast.
func _explode(member_ref: WeakRef, fallback: Vector3) -> void:
	if gone or not _caster_ok():
		return
	var member := member_ref.get_ref() as Node3D
	var at := member.global_position if is_instance_valid(member) else fallback
	_with_room(func():
		VfxKit.shockwave(_field, at + Vector3.UP * 0.12, GOLD, REVIVE_RADIUS)
		VfxKit.impact_ring(_field, at + Vector3.UP * 0.1, WHITE, REVIVE_RADIUS * 0.8, 0.5)
		VfxArt.rays_burst(_field, at + Vector3.UP * 1.3, GOLD, 3.2, 0.45)
		VfxArt.motes(_field, at + Vector3.UP * 1.0, WHITE, "star", 14, 1.6, 2.0, 0.9)
	)
	_sound(SkillSound.star_beat(0), -6.0)
	for foe: Node3D in _foes(at, REVIVE_RADIUS):
		var id := foe.get_instance_id()
		var room := REVIVE_POOL - float(_exploded_on.get(id, 0.0))
		var share := minf(REVIVE_SHARE, room)
		if share <= 0.0001:
			continue
		_exploded_on[id] = float(_exploded_on.get(id, 0.0)) + share
		_strike(foe, share, _beat_fx)


# ---------------------------------------------------------------------------
# Life
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if gone:
		return
	if not _caster_ok():
		_end()
		return
	clock += delta
	if not descended and clock >= DESCEND_AT:
		descended = true
		_descent()
	if shown and is_instance_valid(_angel):
		_move_angel()
	_tick_halos()
	if clock >= WARD + EXIT:
		_end()


func _exit_tree() -> void:
	gone = true


func _end() -> void:
	if gone:
		return
	gone = true
	queue_free()


## The angel lands: the burst of holy light round the aimed point.
func _descent() -> void:
	var r := float(skill.get("radius", 10.0))
	_with_room(func():
		VfxKit.flash(_field, center + Vector3.UP * 1.6, WHITE, 5.0, 0.4)
		VfxKit.shockwave(_field, center + Vector3.UP * 0.12, GOLD, r)
		VfxKit.impact_ring(_field, center + Vector3.UP * 0.1, WHITE, r * 0.85, 0.6, GOLD, ROSE)
		VfxArt.rays_burst(_field, center + Vector3.UP * 2.2, GOLD, 5.5, 0.6)
		VfxArt.rune_circle(_field, center + Vector3.UP * 0.08, GOLD, r * 0.7, 1.0, 0.8)
		VfxArt.motes(_field, center + Vector3.UP * 2.0, WHITE, "star", 24, r * 0.5, 2.5, 1.2)
	)
	_sound(SkillSound.star_beat(0), -3.0)
	var landing := SkillSound.landing(skill)
	if landing != &"":
		_sound(landing, -5.0)
	var foes := _foes(center, r)
	if by_hero:
		SkillFeel.impact(caster, skill, center, r, 0, 1)
		SkillFeel.area_from(center)
	for foe: Node3D in foes:
		_strike(foe, DESCENT_SHARE, skill)
	if by_hero:
		SkillFeel.area_done()
		SkillFeel.beat_done()


## One blow of [param share] of the whole multiplier on [param foe], dealt by the caster.
func _strike(foe: Node3D, share: float, data: Dictionary) -> void:
	if not _valid(foe):
		return
	var id := foe.get_instance_id()
	dealt[id] = float(dealt.get(id, 0.0)) + share
	var mult := total_mult * share
	if by_hero:
		(caster as Hero)._deal(foe as Mob, mult, GOLD, &"light", false, data)
	else:
		(caster as Rival)._hit(foe, mult, GOLD, data.get("fx", {}))


## Every foe of the caster within [param radius] m of [param at].
func _foes(at: Vector3, radius: float) -> Array:
	var out: Array = []
	if by_hero:
		var hero := caster as Hero
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob == null or not is_instance_valid(mob) or mob.is_dead():
				continue
			if mob is CastleGate and not (mob as CastleGate).open_to(hero):
				continue
			if _flat(mob.global_position - at).length() <= radius + mob.body_radius():
				out.append(mob)
	else:
		var rival := caster as Rival
		for node: Node3D in rival._targets():
			if rival._alive(node) and _flat(node.global_position - at).length() <= radius + 0.4:
				out.append(node)
	return out


func _valid(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero and caster is Rival and is_instance_valid(caster):
		return (caster as Rival)._alive(node)
	return node.has_method("is_dead") and not node.is_dead()


## The caster can still hold the ward: there, alive, on this field, out of the safe zone,
## its duel on.
func _caster_ok() -> bool:
	if caster == null or not is_instance_valid(caster) or caster.is_queued_for_deletion():
		return false
	if not is_instance_valid(_field) or _field.is_queued_for_deletion():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if Game.current_zone != _zone:
		return false
	if caster is Hero:
		var hero := caster as Hero
		return hero.field == _field and not hero.safe_zone
	if caster is Rival:
		return not (caster as Rival).duel_over and caster.get_parent() == _field
	return true


func _caster_yaw() -> float:
	if caster is Hero:
		return float((caster as Hero)._facing)
	if caster is Rival:
		return float((caster as Rival)._yaw)
	return caster.rotation.y


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _shown_count() -> int:
	var n := 0
	for w: EternalDawnJudgment in active():
		if w.shown and not w.by_hero:
			n += 1
	return n


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
		AudioManager.play_sfx_at(center, id, db - 4.0)


# ---------------------------------------------------------------------------
# The angel: a white-gold seraph sculpted from primitives, four wings of long feathers,
# a halo; it dives on the aimed point, then glides to hover at the caster's left.
# ---------------------------------------------------------------------------

func _material(body: Color, core: Color, shade: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SPIRIT
	m.set_shader_parameter("body", body)
	m.set_shader_parameter("core", core)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("fade", 0.0)
	_mats.append(m)
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_angel() -> void:
	_angel = Node3D.new()
	_angel.name = "GuardianAngel"
	add_child(_angel)
	var robe := _material(Color("fff8ec"), WHITE, Color("d9a860"))
	var skin := _material(Color("ffe6cc"), WHITE, Color("d89a70"))
	var hair := _material(GOLD, Color("fff6c0"), Color("b06a20"))
	var gold := _material(Color("ffc83a"), Color("fff4c0"), ROSE)
	var plume := _material(Color("fffdf6"), Color("fff0a0"), Color("e0b870"))
	var halo := MeshKit.toon(Color("ffe680"), {"unshaded": true, "emission": 2.0})
	var eye := MeshKit.toon(Color("6a3a5a"), {"unshaded": true})
	var body := Node3D.new()
	body.name = "Body"
	_angel.add_child(body)
	# The robe flares into light where feet would be: the angel never stands.
	_part(body, MeshKit.cone(), robe, Vector3(0, 1.25, 0), Vector3(1.7, 2.3, 1.5))
	_part(body, MeshKit.torus(), gold, Vector3(0, 0.12, 0), Vector3(1.75, 0.6, 1.55))
	_part(body, MeshKit.capsule(), robe, Vector3(0, 2.65, 0), Vector3(0.62, 0.56, 0.46))
	_part(body, MeshKit.torus(), gold, Vector3(0, 2.25, 0), Vector3(0.72, 0.5, 0.56))
	_part(body, MeshKit.sphere(), gold, Vector3(0, 3.0, 0.2), Vector3(0.3, 0.3, 0.12))
	_part(body, MeshKit.sphere(), skin, Vector3(0, 3.62, 0.04), Vector3(0.66, 0.7, 0.64))
	_part(body, MeshKit.sphere(), hair, Vector3(0, 3.78, -0.06), Vector3(0.74, 0.62, 0.72))
	_part(body, MeshKit.capsule(), hair, Vector3(0, 3.25, -0.26), Vector3(0.36, 0.5, 0.22), Vector3(-8, 0, 0))
	for x in [-0.13, 0.13]:
		_lit.append(_part(body, MeshKit.sphere_low(), eye, Vector3(x, 3.6, 0.33), Vector3(0.09, 0.12, 0.05)))
	_lit.append(_part(body, MeshKit.torus(), halo, Vector3(0, 4.25, -0.1), Vector3(0.82, 0.55, 0.82), Vector3(-14, 0, 0)))
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.44 * side, 3.05, 0.0)
		shoulder.rotation_degrees = Vector3(-20, 0, 58.0 * side)
		body.add_child(shoulder)
		_part(shoulder, MeshKit.capsule(), robe, Vector3(0, -0.45, 0), Vector3(0.2, 0.45, 0.2))
		_part(shoulder, MeshKit.sphere(), skin, Vector3(0, -0.98, 0), Vector3(0.22, 0.22, 0.22))
		# Two wings a side: the great upper pair and a lower one, long feathers fanned out.
		for tier in 2:
			var wing := Node3D.new()
			wing.position = Vector3(0.22 * side, 3.05 - 0.55 * tier, -0.32)
			wing.set_meta("side", side)
			wing.set_meta("tier", tier)
			body.add_child(wing)
			_wings.append(wing)
			var count := 7 if tier == 0 else 5
			for i in count:
				var f := float(i) / float(count - 1)
				var angle := lerpf(18.0, 112.0, f) if tier == 0 else lerpf(80.0, 140.0, f)
				var length := (lerpf(2.5, 1.5, f) if tier == 0 else lerpf(1.5, 1.0, f))
				var dir := Vector3(sin(deg_to_rad(angle)) * side, cos(deg_to_rad(angle)), 0)
				_part(wing, MeshKit.sphere(), plume, dir * length * 0.5, Vector3(0.3, length, 0.07), Vector3(0, -12.0 * side, -angle * side))
	_set_fade(0.0)


func _set_fade(f: float, glow := 0.0) -> void:
	for m in _mats:
		m.set_shader_parameter("fade", f)
		m.set_shader_parameter("glow", glow)
	for mi in _lit:
		mi.visible = f > 0.05


## Where it hovers by the caster: on its left, a little ahead, raised (clear of the camera
## behind the caster, and opposite หนุมาน's side).
func _guard_spot() -> Vector3:
	var yaw := _caster_yaw()
	return caster.global_position + Vector3(cos(yaw), 0.0, -sin(yaw)) * 2.6 + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.8 + Vector3.UP * 1.3


func _move_angel() -> void:
	var t := clock
	var bob := sin(t * 2.2) * 0.12
	var fade := 1.0
	var glow := 0.0
	var at: Vector3
	if t < DESCEND_AT:
		var s := t / DESCEND_AT
		at = center + Vector3.UP * (12.0 * pow(1.0 - s, 2.0) + 0.6)
		fade = clampf(s * 3.0, 0.0, 1.0)
		glow = 1.0 - s * 0.6
		_face(caster.global_position)
	elif t < GLIDE_FROM:
		at = center + Vector3.UP * (0.6 + bob)
		glow = clampf(0.6 - (t - DESCEND_AT) * 2.0, 0.0, 1.0)
		_face(caster.global_position)
		_glide_from = at
	elif t < GLIDE_FROM + GLIDE_TIME:
		var s := smoothstep(0.0, 1.0, (t - GLIDE_FROM) / GLIDE_TIME)
		at = _glide_from.lerp(_guard_spot(), s) + Vector3.UP * sin(s * PI) * 1.6
		_face(_guard_spot() + Vector3(sin(_caster_yaw()), 0, cos(_caster_yaw())) * 4.0)
	else:
		at = _guard_spot() + Vector3.UP * bob
		_yaw = lerp_angle(_yaw, _caster_yaw(), 1.0 - exp(-5.0 * get_process_delta_time()))
		_angel.rotation.y = _yaw
		if t > WARD:
			var s := clampf((t - WARD) / EXIT, 0.0, 1.0)
			at += Vector3.UP * s * s * 6.0
			fade = 1.0 - s
			glow = s
	_angel.global_position = _angel.global_position.lerp(at, 1.0 - exp(-18.0 * get_process_delta_time())) if t >= DESCEND_AT else at
	var flap := sin(t * (9.0 if t < DESCEND_AT + 0.4 else 3.0)) * (14.0 if t < GLIDE_FROM + GLIDE_TIME else 7.0)
	for wing in _wings:
		var side := float(wing.get_meta("side"))
		var tier := int(wing.get_meta("tier"))
		wing.rotation_degrees = Vector3(0, -24.0 * side, (flap - 6.0 * tier) * side)
	_set_fade(fade, glow)


func _face(point: Vector3) -> void:
	var d := _flat(point - _angel.global_position)
	if d.length_squared() > 0.01:
		_yaw = lerp_angle(_yaw, atan2(d.x, d.z), 1.0 - exp(-10.0 * get_process_delta_time()))
		_angel.rotation.y = _yaw


# ---------------------------------------------------------------------------
# A small halo over each guarded member while its save is unspent.
# ---------------------------------------------------------------------------

func _members() -> Array:
	var out: Array = [caster]
	if by_hero:
		for node in get_tree().get_nodes_in_group("companions"):
			if node != caster and is_instance_valid(node) and not node.is_dead() and covers(node):
				out.append(node)
	elif caster is GuildFighter:
		for f in (caster as GuildFighter)._crew():
			if f != caster and is_instance_valid(f) and not f._dead and covers(f):
				out.append(f)
		var hero: Variant = (caster as Rival).hero
		if hero is Hero and is_instance_valid(hero) and covers(hero):
			out.append(hero)
	return out


func _tick_halos() -> void:
	if not shown:
		return
	var live := clock < WARD
	var seen := {}
	if live:
		for m: Node3D in _members():
			var id := m.get_instance_id()
			if saved.has(id):
				continue
			seen[id] = true
			var halo := _halos.get(id) as MeshInstance3D
			if halo == null or not is_instance_valid(halo):
				halo = _make_halo()
				if halo == null:
					continue
				_halos[id] = halo
			halo.global_position = m.global_position + Vector3.UP * 2.75
			halo.rotation.y = clock * 1.6
			var mat := halo.material_override as StandardMaterial3D
			if mat:
				var a := 0.55 + 0.25 * sin(clock * 4.0)
				if clock > WARD - 1.5:
					a *= 0.5 + 0.5 * sin(clock * 18.0)
				halo.transparency = 1.0 - clampf(a, 0.0, 1.0)
	for id in _halos.keys():
		if not seen.has(id):
			_drop_halo(id)


func _make_halo() -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.torus()
	mi.material_override = MeshKit.toon(Color("ffe680"), {"unshaded": true, "emission": 2.0})
	mi.scale = Vector3(0.55, 0.5, 0.55)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	VfxBudget.track_decoration(mi)
	return mi


func _drop_halo(id: int) -> void:
	var halo := _halos.get(id) as MeshInstance3D
	_halos.erase(id)
	if halo != null and is_instance_valid(halo):
		halo.queue_free()
