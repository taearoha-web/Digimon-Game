class_name PrimordialBeastCourt
extends Node3D
## หลอมรวมอสูร (the Summoner's ★500 ultimate, AscendUlt; id primordial_beast_court): every
## summon its caster has out rushes in to the aimed point, spirals together over it and
## fuses into one giant chimera beast (a maned lion's head with horns, griffin wings, four
## clawed legs, a serpent tail, and on its back one soul gem a summon in that summon's
## colour), which rears up and smashes the aimed area with ONE blow, then dissolves.
##
## Damage: one blow on every foe within the skill's radius of the aimed point, of
##     share = BASE_SHARE + FEED_SHARE x min(fed, MAX_FED)
## of the skill's whole multiplier: 0.8 with no summons, 1.0 with two (the old god-skill's
## total), 1.2 at most (four or more fed), with the skill's fx (the 2 s stun, the 25%
## armour crack for 8 s). The fed summons are dismissed (taken out of their summoner's list
## at the release, freed when they fuse). A summon marked "ascend_titan" (the Summoner's
## ★500 buff's Titan) is never fed; nor is one already falling or fading. With nothing out
## the beast forms out of the caster's own spirit at base power.
##
## The caster deals the blow: the hero's through Hero._deal, an AI's through Rival._hit
## (its summons, Summon or SummonMob, are fed the same way). Lifetime: a child of the
## caster's field; the caster gone, dead, off the field, in a safe zone or out of its duel
## ends it at once (the fed summons are dismissed all the same, no blow). An AI caster's
## beast shows only while fewer than MAX_AI_SHOWN others do and the quality is above low.

const ID := "primordial_beast_court"
const BASE_SHARE := 0.8
const FEED_SHARE := 0.1
const MAX_FED := 4
## The meta that keeps a summon out of the fusion (the Titan of the ★500 buff).
const KEEP_META := &"ascend_titan"
const RUSH := 0.7
const FORM := 0.45
const REAR := 0.45
const SLAM_AT := 1.75
const DISSOLVE := 0.85
const LUNGE := 1.8
## Where the summons meet: over the aimed point.
const MEET_HEIGHT := 3.4
const MAX_AI_SHOWN := 2
const JADE := Color("3af0a0")
const MINT := Color("e8fff4")
const DEEP := Color("0a3a3a")
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
## For tests: how many summons were fed, the blow's share, the foes it struck (instance id
## -> share), and whether it landed.
var fed := 0
var share := BASE_SHARE
var dealt: Dictionary = {}
var struck := false

var _field: Node3D
var _zone: StringName
var _dir := Vector3.FORWARD
## The fed summons: {node, from, colour, phase}.
var _rush: Array = []
var _fused := false
var _beast: Node3D
var _body: Node3D
var _head: Node3D
var _tail: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _mats: Array[ShaderMaterial] = []
var _gems: Array[MeshInstance3D] = []
var _trail_at := 0.0


## The blow's share of the whole multiplier for [param summons] fed.
static func share_for(summons: int) -> float:
	return BASE_SHARE + FEED_SHARE * float(clampi(summons, 0, MAX_FED))


# ---------------------------------------------------------------------------
# The casts (AscendUlt)
# ---------------------------------------------------------------------------

func begin_hero(hero: Hero, p_skill: Dictionary, aim: Vector3, _target: Mob) -> void:
	_start(hero, p_skill, aim, float(p_skill.get("mult", 0.0)) * hero.rank_mult(p_skill), true, hero._summons)


func begin_rival(rival: Rival, p_skill: Dictionary, aim: Vector3, _target: Node3D) -> void:
	var mult := float(p_skill.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(p_skill))
	_start(rival, p_skill, aim, mult, false, rival._summons)


func _start(who: Node3D, p_skill: Dictionary, aim: Vector3, mult: float, hero_side: bool, list: Array) -> void:
	caster = who
	skill = p_skill
	total_mult = mult
	by_hero = hero_side
	_field = get_parent() as Node3D
	_zone = Game.current_zone
	center = Vector3(aim.x, who.global_position.y, aim.z)
	shown = hero_side or (VfxBudget.quality() > 0 and _shown_count() < MAX_AI_SHOWN)
	var d := _flat(center - who.global_position)
	_dir = d.normalized() if d.length() > 0.5 else Vector3(sin(_caster_yaw()), 0, cos(_caster_yaw()))
	global_position = center
	_live.append(weakref(self))
	_feed(list)
	share = share_for(fed)
	if shown:
		_build_beast()
	_with_room(func():
		VfxArt.rune_circle(_field, center + Vector3.UP * 0.08, JADE, float(skill.get("radius", 10.0)) * 0.6, RUSH + FORM, 1.2)
	)
	if by_hero:
		BattleVfx.floating_text(_field, caster.global_position + Vector3.UP * 3.2, "%s ×%d" % [String(skill.get("name", "")), fed] if fed > 0 else String(skill.get("name", "")), JADE, 1.0)
	_sound(&"summon", -4.0)


## Takes every summon of [param list] that can be fed off the field and out of its
## summoner's list: they no longer fight, nothing targets them, they fly to the meeting.
func _feed(list: Array) -> void:
	var keep: Array = []
	for s in list:
		if not _feedable(s):
			if is_instance_valid(s):
				keep.append(s)
			continue
		var node := s as Node3D
		var colour: Color = JADE
		var kind: Variant = node.get("_kind")
		if kind is Dictionary and (kind as Dictionary).has("color"):
			colour = (kind as Dictionary).color
		_rush.append({"node": node, "from": node.global_position, "colour": colour, "phase": float(_rush.size())})
		_take(node)
	fed = _rush.size()
	list.clear()
	list.append_array(keep)


func _feedable(s: Variant) -> bool:
	if s == null or not is_instance_valid(s) or (s as Node).is_queued_for_deletion():
		return false
	var node := s as Node3D
	if node == null or node.has_meta(KEEP_META) or node.get("_fading") == true or node.get("_expired") == true:
		return false
	return node.has_method("is_dead") and not node.is_dead()


## Stops a fed summon where it is: no AI, no bar, no target for anyone.
func _take(node: Node3D) -> void:
	node.set_meta(&"ascend_fused", true)
	node.set_process(false)
	node.set_physics_process(false)
	node.remove_from_group("summons")
	node.remove_from_group("mobs")
	if "_dead" in node:
		node.set("_dead", true)
	if node is Mob:
		var mob := node as Mob
		mob.hostile = false
		mob.collision_layer = 0
		mob.set_targeted(false)
	for key in ["_bar", "_label", "_alert"]:
		var n: Variant = node.get(key)
		if n is Node3D:
			(n as Node3D).visible = false
	BurstGuard.forget(node.get_instance_id())


func _dismiss_fed() -> void:
	for r: Dictionary in _rush:
		var node: Node3D = r.node
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_rush.clear()


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
	if clock < RUSH:
		_tick_rush(clock / RUSH)
	elif not _fused:
		_fuse()
	if shown and is_instance_valid(_beast):
		_pose_beast()
	if not struck and clock >= SLAM_AT:
		struck = true
		_slam()
	if clock >= SLAM_AT + DISSOLVE:
		_end()


func _exit_tree() -> void:
	gone = true
	_dismiss_fed()


func _end() -> void:
	if gone:
		return
	gone = true
	_dismiss_fed()
	queue_free()


func _meet() -> Vector3:
	return center + Vector3.UP * MEET_HEIGHT


## The fed summons fly in, spiralling tighter round the meeting point, shrinking into light.
func _tick_rush(t: float) -> void:
	var meet := _meet()
	var e := t * t * (3.0 - 2.0 * t)
	var trail := clock >= _trail_at
	if trail:
		_trail_at = clock + 0.12
	for r: Dictionary in _rush:
		var node: Node3D = r.node
		if not is_instance_valid(node):
			continue
		var from: Vector3 = r.from
		var swirl := (1.0 - e) * 2.4
		var a := float(r.phase) * TAU / maxf(float(fed), 1.0) + e * TAU * 1.25
		var p := from.lerp(meet, e) + Vector3(cos(a), 0.0, sin(a)) * swirl * sin(e * PI) + Vector3.UP * sin(e * PI) * 1.4
		var d := _flat(p - node.global_position)
		if d.length_squared() > 0.0004:
			node.rotation.y = atan2(d.x, d.z)
		node.global_position = p
		node.scale = Vector3.ONE * lerpf(1.0, 0.35, e)
		if trail and shown:
			_with_room(func(): VfxArt.motes(_field, p + Vector3.UP * 0.8, r.colour, "star", 5, 0.4, 0.4, 0.5))
	if fed == 0 and trail and shown:
		# Nothing out: the caster's own spirit streams to the meeting.
		var from := caster.global_position + Vector3.UP * 1.4
		_with_room(func(): VfxKit.projectile(_field, JADE, from, meet, 0.35, 0.45, "spark"))


## They meet: a flash, and the beast takes form.
func _fuse() -> void:
	_fused = true
	var meet := _meet()
	_with_room(func():
		VfxKit.flash(_field, meet, MINT, 4.8, 0.4)
		VfxArt.rays_burst(_field, meet, JADE, 4.4, 0.5)
		VfxArt.motes(_field, meet, JADE, "star", 26, 2.2, 1.0, 1.0)
		for r: Dictionary in _rush:
			VfxKit.sparks(_field, meet, r.colour, 10, 6.0, 0.6)
	)
	_dismiss_fed()
	_sound(SkillSound.star_beat(1), -4.0)


## THE blow: every foe in the radius, once, at the fused share.
func _slam() -> void:
	var r := float(skill.get("radius", 10.0))
	_with_room(func():
		VfxKit.flash(_field, center + Vector3.UP * 1.0, MINT, 6.0, 0.45)
		VfxKit.shockwave(_field, center + Vector3.UP * 0.12, JADE, r)
		VfxKit.impact_ring(_field, center + Vector3.UP * 0.1, MINT, r * 0.8, 0.6, JADE, DEEP)
		VfxKit.slam(_field, center, JADE, r * 0.6)
		VfxKit.spikes(_field, center, r * 0.7, JADE, 12, 2.4, 0.2)
		VfxKit.impact_smoke(_field, center + Vector3.UP * 0.4, Color("9ad8c0"), 3.0)
	)
	_sound(SkillSound.star_beat(0), -2.0)
	var landing := SkillSound.landing(skill)
	if landing != &"":
		_sound(landing, -4.0)
	var foes := _foes(center, r)
	if by_hero:
		SkillFeel.impact(caster, skill, center, r, 0, 1)
		SkillFeel.area_from(center)
	for foe: Node3D in foes:
		if not _valid(foe):
			continue
		dealt[foe.get_instance_id()] = share
		var mult := total_mult * share
		if by_hero:
			(caster as Hero)._deal(foe as Mob, mult, JADE, &"light", false, skill)
		else:
			(caster as Rival)._hit(foe, mult, JADE, skill.get("fx", {}))
	if by_hero:
		SkillFeel.area_done()
		SkillFeel.beat_done()


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
	var keep: Array = []
	for ref: WeakRef in _live:
		var b := ref.get_ref() as PrimordialBeastCourt
		if is_instance_valid(b) and not b.gone:
			keep.append(ref)
			if b.shown and not b.by_hero:
				n += 1
	_live = keep
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
# The chimera: sculpted from primitives in the jade spirit light (about 5 m at the
# shoulder when it rears), beyond the aimed point and facing back at the caster.
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


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _build_beast() -> void:
	_beast = Node3D.new()
	_beast.name = "Chimera"
	add_child(_beast)
	# Beyond the point, facing back at the caster (and the camera behind it).
	_beast.rotation.y = atan2(-_dir.x, -_dir.z)
	var hide := _material(JADE, MINT, DEEP)
	var belly := _material(Color("9af5cf"), MINT, Color("1a6a5a"))
	var mane := _material(Color("ffd56a"), Color("fff6d0"), Color("6a4a10"))
	var horn := _material(Color("f4fff8"), MINT, Color("5a8a7a"))
	var wing := _material(Color("6af0d0"), MINT, Color("0e4a4a"))
	var eye := MeshKit.toon(Color("fff27a"), {"unshaded": true, "emission": 3.0})
	# The body pivots at the hips so it can rear and slam.
	_body = _pivot(_beast, Vector3(0, 1.9, -1.1))
	var b := _body
	_part(b, MeshKit.sphere(), hide, Vector3(0, 0.55, 2.0), Vector3(2.3, 2.1, 2.3))
	_part(b, MeshKit.sphere(), hide, Vector3(0, 0.15, 0.4), Vector3(1.9, 1.7, 2.6))
	_part(b, MeshKit.sphere(), belly, Vector3(0, -0.25, 1.4), Vector3(1.5, 1.2, 2.2))
	# Legs: front pair under the chest, hind pair under the haunch, big clawed paws.
	for side in [-1.0, 1.0]:
		for front in [true, false]:
			var z := 2.15 if front else -0.1
			var leg := _pivot(b, Vector3(0.78 * side, -0.1, z))
			leg.set_meta("front", front)
			_part(leg, MeshKit.capsule(), hide, Vector3(0, -0.75, 0), Vector3(0.62 if front else 0.72, 0.72, 0.62 if front else 0.78))
			_part(leg, MeshKit.sphere(), belly, Vector3(0, -1.6, 0.18), Vector3(0.78, 0.42, 0.95))
			for c in [-0.22, 0.0, 0.22]:
				_part(leg, MeshKit.cone(), horn, Vector3(c, -1.68, 0.66), Vector3(0.14, 0.34, 0.14), Vector3(90, 0, 0))
	# Neck, head, mane, horns, eyes, jaw.
	_part(b, MeshKit.capsule(), hide, Vector3(0, 1.35, 2.75), Vector3(0.78, 0.7, 0.78), Vector3(40, 0, 0))
	_head = _pivot(b, Vector3(0, 2.0, 3.35))
	var h := _head
	for i in 12:
		var a := TAU * float(i) / 12.0
		var out := Vector3(sin(a), cos(a), 0.0)
		_part(h, MeshKit.cone(), mane, out * 0.78 + Vector3(0, 0, -0.35), Vector3(0.55, 1.15, 0.55), Vector3(-15, 0, -rad_to_deg(a)))
	_part(h, MeshKit.sphere(), mane, Vector3(0, 0, -0.3), Vector3(1.7, 1.7, 1.0))
	_part(h, MeshKit.sphere(), hide, Vector3(0, 0, 0.1), Vector3(1.25, 1.15, 1.35))
	_part(h, MeshKit.sphere(), belly, Vector3(0, -0.22, 0.78), Vector3(0.82, 0.6, 0.85))
	_part(h, MeshKit.sphere(), hide, Vector3(0, -0.55, 0.62), Vector3(0.7, 0.32, 0.78))
	for side in [-1.0, 1.0]:
		_part(h, MeshKit.cone(), horn, Vector3(0.38 * side, 0.62, -0.05), Vector3(0.26, 1.1, 0.26), Vector3(-32, 0, -22.0 * side))
		_part(h, MeshKit.sphere_low(), eye, Vector3(0.3 * side, 0.18, 0.66), Vector3(0.22, 0.14, 0.12))
		_part(h, MeshKit.cone(), horn, Vector3(0.18 * side, -0.48, 1.05), Vector3(0.1, 0.28, 0.1), Vector3(180, 0, 0))
	# Griffin wings from the shoulders, long feathers fanned.
	for side in [-1.0, 1.0]:
		var w := _pivot(b, Vector3(0.62 * side, 1.35, 1.65))
		w.set_meta("side", side)
		_wings.append(w)
		for i in 8:
			var f := float(i) / 7.0
			var angle := lerpf(14.0, 96.0, f)
			var length := lerpf(3.4, 1.8, f)
			var dir := Vector3(sin(deg_to_rad(angle)) * side, cos(deg_to_rad(angle)), -0.25)
			_part(w, MeshKit.sphere(), wing, dir * length * 0.5, Vector3(0.42, length, 0.09), Vector3(0, -16.0 * side, -angle * side))
	# The serpent tail: a curling chain ending in a fanged head.
	var prev := _pivot(b, Vector3(0, 0.3, -1.1))
	for i in 7:
		var seg := _pivot(prev, Vector3(0, 0.12, -0.55) if i > 0 else Vector3.ZERO)
		var size := lerpf(0.75, 0.38, float(i) / 6.0)
		_part(seg, MeshKit.sphere(), hide if i % 2 == 0 else belly, Vector3.ZERO, Vector3.ONE * size)
		_tail.append(seg)
		prev = seg
	var snake := _pivot(prev, Vector3(0, 0.2, -0.45))
	_tail.append(snake)
	_part(snake, MeshKit.sphere(), hide, Vector3.ZERO, Vector3(0.5, 0.42, 0.7))
	for side in [-1.0, 1.0]:
		_part(snake, MeshKit.sphere_low(), eye, Vector3(0.16 * side, 0.12, -0.22), Vector3(0.1, 0.08, 0.08))
	# A soul gem on its back for every summon it swallowed (one of its own when none).
	var colours: Array = []
	for r: Dictionary in _rush:
		colours.append(r.colour)
	if colours.is_empty():
		colours.append(MINT)
	for i in colours.size():
		var z := lerpf(2.2, -0.6, float(i) / maxf(float(colours.size() - 1), 1.0)) if colours.size() > 1 else 1.0
		var gem := _part(b, MeshKit.sphere_low(), MeshKit.toon(colours[i], {"unshaded": true, "emission": 2.5}), Vector3(0, 1.45 - absf(z - 1.0) * 0.25, z), Vector3(0.36, 0.5, 0.36), Vector3(0, 45, 0))
		_gems.append(gem)
	_beast.visible = false
	_set_fade(0.0, 1.0)


func _set_fade(f: float, glow: float) -> void:
	for m in _mats:
		m.set_shader_parameter("fade", f)
		m.set_shader_parameter("glow", glow)
	for g in _gems:
		g.visible = f > 0.2


## Form (grows out of the light over the point), rear (front lifted, wings up, a roar),
## lunge and slam (body pitched down, paws on the point), then dissolve upward.
func _pose_beast() -> void:
	var t := clock
	if t < RUSH:
		return
	_beast.visible = true
	var start := center + _dir * (2.3 + LUNGE)
	var pos := start
	var pitch := 0.0
	var size := 1.0
	var fade := 1.0
	var glow := 0.0
	var flap := sin(t * 5.0) * 10.0
	var form_end := RUSH + FORM
	var rear_end := form_end + REAR
	if t < form_end:
		var s := (t - RUSH) / FORM
		size = lerpf(0.15, 1.0, 1.0 - pow(1.0 - s, 3.0))
		pos = start.lerp(_meet() - Vector3.UP * 2.0, 1.0 - s)
		fade = clampf(s * 2.0, 0.0, 1.0)
		glow = 1.0 - s
		pitch = -10.0 * s
	elif t < rear_end:
		var s := smoothstep(0.0, 1.0, (t - form_end) / REAR)
		pitch = lerpf(-10.0, -34.0, s)
		pos = start + Vector3.UP * s * 0.6
		flap = lerpf(10.0, 40.0, s)
	elif t < SLAM_AT:
		var s := clampf((t - rear_end) / maxf(SLAM_AT - rear_end, 0.05), 0.0, 1.0)
		var e := s * s
		pitch = lerpf(-34.0, 14.0, e)
		pos = start - _dir * LUNGE * e + Vector3.UP * 0.6 * (1.0 - e)
		flap = lerpf(40.0, -20.0, e)
		glow = e * 0.3
	else:
		var s := clampf((t - SLAM_AT) / DISSOLVE, 0.0, 1.0)
		pitch = lerpf(14.0, 6.0, s)
		pos = start - _dir * LUNGE + Vector3.UP * s * s * 2.5
		fade = 1.0 - smoothstep(0.25, 1.0, s)
		glow = clampf(0.3 + s, 0.0, 1.0)
		flap = -20.0 + s * 30.0
		if s > 0.2 and shown and int(t * 20.0) % 3 == 0:
			_with_room(func(): VfxArt.motes(_field, _beast.global_position + Vector3.UP * 2.5, JADE, "star", 6, 2.0, 1.5, 0.7))
	_beast.global_position = pos
	_beast.scale = Vector3.ONE * size
	_body.rotation_degrees.x = pitch
	for w in _wings:
		var side := float(w.get_meta("side"))
		w.rotation_degrees = Vector3(-10, -20.0 * side, flap * side)
	for i in _tail.size():
		_tail[i].rotation_degrees = Vector3(-14.0 + sin(t * 4.0 - float(i) * 0.7) * 12.0, sin(t * 3.0 - float(i) * 0.6) * 18.0, 0)
	if is_instance_valid(_head):
		_head.rotation_degrees.x = pitch * -0.6 + (14.0 if t >= rear_end and t < SLAM_AT else 0.0)
	for g in _gems:
		g.rotation.y = t * 2.0
	_set_fade(fade, glow)
