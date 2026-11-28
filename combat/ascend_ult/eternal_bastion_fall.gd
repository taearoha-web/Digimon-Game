extends Node
## Defender Ascension ultimate (★500) "กำแพงโล่ถล่ม" (eternal_bastion_fall), an AscendUlt.
##
## A wall of five giant celestial shields rises out of the ground in front of the defender
## (RISE s), then drives straight ahead DRIVE metres (DRIVE_TIME s, eased). Every enemy the
## wall's face meets inside its width is struck once (CONTACT_SHARE) and carried along in
## front of it; when the drive ends the shields tip forward and slam down flat (TIP s): the
## crush (CRUSH_SHARE) strikes everyone the wall carried or met, and anyone standing where
## the shields fall (FALL_REACH metres beyond the face).
##
## Damage scales with the defender's DEFENCE, read once at the release (the current sheet:
## gear, gems, buffs, an armour crack on it): every hit's multiplier is its share of the
## skill's whole multiplier times def_factor = ATK_PART + DEF_PART x min(DEF / ATK, DEF_CAP),
## i.e. the total on one foe is skill.mult x (ATK_PART x ATK + DEF_PART x DEF) in ATK terms,
## with DEF counted up to DEF_CAP x ATK. A ★500 defender in its own gear (ATK ~8.4k, DEF
## ~9.1k) lands ~1.04x the old total; with its own อีจิสแห่งนิรันดร์ (+150% DEF) ~1.86x;
## the cap holds any stack at 2.0x.
##
## Movement: a monster (not a boss) is carried by the bodies' own collision (walls stop it);
## a boss holds its ground and the wall passes over it. An AI caster's wall carries what it
## meets that is no player (summons, companions); players hold their ground as with every
## monster's knock (WarPush's rule), the hits land all the same.
##
## Lifetime: a child of the caster's field; it stops at once (no hit after that) when the
## caster is freed, falls, leaves the field or the duel ends, and frees itself when done.
## The hero's effects use the hero's room of VfxBudget; an AI's wall is lighter.
const K := preload("res://combat/god_art/_kit_melee.gd")
const ID := "eternal_bastion_fall"

const RISE := 0.32
const DRIVE_TIME := 1.1
const TIP := 0.26
const AFTER := 0.6
## How far ahead of the caster the wall's face rises, and how far it drives.
const START := 1.3
const DRIVE := 10.0
## Half the wall's width (five shields of SHIELD_W).
const HALF_WIDTH := 3.7
const SHIELD_W := 1.55
const SHIELD_H := 3.4
## Beyond the face the tipping shields fall on (their height, less their curve).
const FALL_REACH := 3.2
## The two hits on one foe add up to the whole multiplier.
const CONTACT_SHARE := 0.25
const CRUSH_SHARE := 0.75
## DEF scaling (see the header).
const ATK_PART := 0.5
const DEF_PART := 0.5
const DEF_CAP := 3.0
## The hero's cast stays locked this long after the release (the wall rises).
const LEAD := 0.45
const BLUE := Color("5a9aff")
const WHITE := Color("f0f6ff")
const NAVY := Color("0e1e5a")
const GOLD := Color("f6c64a")

static var _cache := {}
## The last cast's numbers (tests).
static var last := {}

var caster: Node3D
var by_hero := false
var skill: Dictionary = {}
## The whole multiplier on one foe before the DEF factor (hero: mult x rank power; AI: mult x
## SKILL_POWER x rank power, as Rival._resolve).
var total_mult := 0.0
var def_factor := 1.0
var clock := 0.0
var origin := Vector3.ZERO
var forward := Vector3.FORWARD
var right := Vector3.RIGHT
var front := START
var met: Array = []
var hits := 0
var crushed := false
var stopped := false

var _field: Node
var _met_ids := {}
var _wall: Node3D
var _pivot: Node3D
var _mat: ShaderMaterial
var _trail: MeshInstance3D
var _dust_at := 0.0
var _fx_contact: Dictionary = {}


## The DEF factor of a caster with [param atk] attack and [param defence] DEF.
static func factor(atk: float, defence: float) -> float:
	return ATK_PART + DEF_PART * clampf(defence / maxf(atk, 1.0), 0.0, DEF_CAP)


static func lead(_skill: Dictionary) -> float:
	return LEAD


func begin_hero(hero: Hero, data: Dictionary, _aim: Vector3, target: Mob) -> void:
	caster = hero
	by_hero = true
	skill = data
	_field = hero.field
	total_mult = float(data.get("mult", 0.0)) * hero.rank_mult(data)
	def_factor = factor(float(hero.stats.atk), hero.effective_def())
	var dir := Vector3(sin(hero.facing()), 0, cos(hero.facing()))
	if hero._valid_target(target):
		var to := hero._flat(target.global_position - hero.global_position)
		if to.length() > 0.5:
			dir = to.normalized()
	_start(hero.global_position, dir)


func begin_rival(rival: Rival, data: Dictionary, aim: Vector3, target: Node3D) -> void:
	caster = rival
	by_hero = false
	skill = data
	_field = rival.get_parent()
	total_mult = float(data.get("mult", 0.0)) * HeroStats.SKILL_POWER * SkillRank.power(rival.skill_rank(data))
	def_factor = factor(float(rival.rstats.get("atk", 1.0)) * rival._atk_boost, float(rival.stats.get("def", 0.0)))
	var to := Vector3(aim.x - rival.global_position.x, 0, aim.z - rival.global_position.z)
	if target != null and is_instance_valid(target):
		to = Vector3(target.global_position.x - rival.global_position.x, 0, target.global_position.z - rival.global_position.z)
	var dir := to.normalized() if to.length() > 0.5 else Vector3(sin(rival._yaw), 0, cos(rival._yaw))
	_start(rival.global_position, dir)


func _start(at: Vector3, dir: Vector3) -> void:
	origin = Vector3(at.x, at.y, at.z)
	forward = dir
	right = Vector3.UP.cross(forward).normalized()
	front = START
	_fx_contact = (skill.get("fx", {}) as Dictionary).duplicate()
	last = {"factor": def_factor, "total": total_mult, "hits": 0, "met": 0, "crushed": false, "stopped": false}
	_room(func():
		_build()
		VfxKit.flash(_field, _at(START, 0.0) + Vector3.UP * 1.6, WHITE, 4.2, 0.3)
		VfxKit.impact_ring(_field, _at(START, 0.0) + Vector3.UP * 0.08, BLUE, HALF_WIDTH, 0.4, WHITE, NAVY)
	)
	_sound(SkillSound.star_beat(0), -4.0)


func _process(delta: float) -> void:
	if stopped:
		return
	if not _caster_ok():
		_stop()
		return
	clock += delta
	var drive_end := RISE + DRIVE_TIME
	if clock < RISE:
		_rise(clock / RISE)
		_meet()
	elif clock < drive_end:
		var s := clampf((clock - RISE) / DRIVE_TIME, 0.0, 1.0)
		front = START + DRIVE * s * s * (3.0 - 2.0 * s)
		_place()
		_meet()
		_carry()
		_dust()
	elif clock < drive_end + TIP:
		front = START + DRIVE
		_place()
		_carry()
		_tip((clock - drive_end) / TIP)
	else:
		if not crushed:
			_tip(1.0)
			_crush()
		var t := (clock - drive_end - TIP) / AFTER
		if _mat:
			_mat.set_shader_parameter("fade", clampf(1.0 - t * 1.2, 0.0, 1.0))
			_mat.set_shader_parameter("age", 0.002 + clock - drive_end - TIP)
		if is_instance_valid(_trail):
			_trail.transparency = clampf(t, 0.0, 1.0)
		if t >= 1.0:
			_finish()


func _exit_tree() -> void:
	stopped = true
	# The wall and its seam live on the field: they go with the cast.
	for node in [_wall, _trail]:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()


func _caster_ok() -> bool:
	if caster == null or not is_instance_valid(caster) or caster.is_queued_for_deletion():
		return false
	if not is_instance_valid(_field) or _field.is_queued_for_deletion():
		return false
	if caster.has_method("is_dead") and caster.is_dead():
		return false
	if by_hero:
		var hero := caster as Hero
		return hero.field == _field and not hero.safe_zone
	return not (caster as Rival).duel_over and caster.get_parent() == _field


func _stop() -> void:
	stopped = true
	last.stopped = true
	queue_free()


func _finish() -> void:
	stopped = true
	queue_free()


# ---------------------------------------------------------------------------
# Who the wall meets, carries and crushes
# ---------------------------------------------------------------------------

## Point [param along] metres ahead of the caster's start, [param side] to its right.
func _at(along: float, side: float) -> Vector3:
	return origin + forward * along + right * side


func _foes() -> Array:
	var out: Array = []
	if by_hero:
		var hero := caster as Hero
		for node in get_tree().get_nodes_in_group("mobs"):
			var mob := node as Mob
			if mob == null or not is_instance_valid(mob) or mob.is_dead():
				continue
			if mob is CastleGate and not (mob as CastleGate).open_to(hero):
				continue
			out.append(mob)
	else:
		var rival := caster as Rival
		for node: Node3D in rival._targets():
			if rival._alive(node):
				out.append(node)
	return out


func _alive(node: Variant) -> bool:
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return false
	if not by_hero:
		return (caster as Rival)._alive(node)
	return node.has_method("is_dead") and not node.is_dead()


static func _body(node: Node3D) -> float:
	return (node as Mob).body_radius() if node is Mob else 0.5


func _local(node: Node3D) -> Vector2:
	var d := node.global_position - origin
	d.y = 0.0
	return Vector2(d.dot(forward), d.dot(right))


## Foes the face reaches (inside its width, not behind where it rose) are struck once and
## carried from then on.
func _meet() -> void:
	for foe: Node3D in _foes():
		var id := foe.get_instance_id()
		if _met_ids.has(id):
			continue
		var p := _local(foe)
		var r := _body(foe)
		if p.x - r <= front and p.x + r >= START - 0.6 and absf(p.y) <= HALF_WIDTH + r:
			_met_ids[id] = true
			met.append(weakref(foe))
			last.met = met.size()
			_strike(foe, CONTACT_SHARE, false)


## Every carried foe is kept in front of the face (a boss or a player holds its ground).
func _carry() -> void:
	for ref: WeakRef in met:
		var foe := ref.get_ref() as Node3D
		if not _alive(foe) or not _movable(foe):
			continue
		var p := _local(foe)
		var want := front + _body(foe) + 0.12
		if p.x >= want:
			continue
		var step := forward * (want - p.x)
		var body := foe as CharacterBody3D
		var hit := body.move_and_collide(step)
		if hit != null and hit.get_normal().y > 0.6:
			body.move_and_collide(hit.get_remainder().slide(hit.get_normal()))
		body.velocity.x = 0.0
		body.velocity.z = 0.0


func _movable(foe: Node3D) -> bool:
	if not (foe is CharacterBody3D) or foe is Hero or foe.is_in_group("remote_players"):
		return false
	if foe is Mob and ((foe as Mob).is_boss or foe is CastleGate):
		return false
	if foe is GuildFighter or foe is Rival:
		return false
	return true


## The slam: everyone met (still standing) and whoever stands where the shields fall.
func _crush() -> void:
	crushed = true
	last.crushed = true
	var victims: Array = []
	for ref: WeakRef in met:
		var foe := ref.get_ref() as Node3D
		if _alive(foe):
			victims.append(foe)
	for foe: Node3D in _foes():
		if foe in victims:
			continue
		var p := _local(foe)
		var r := _body(foe)
		if p.x + r >= front and p.x - r <= front + FALL_REACH and absf(p.y) <= HALF_WIDTH + r:
			victims.append(foe)
	var at := _at(front + FALL_REACH * 0.5, 0.0)
	_room(func():
		VfxKit.shockwave(_field, at + Vector3.UP * 0.1, BLUE, HALF_WIDTH + 1.6)
		VfxKit.impact_ring(_field, at + Vector3.UP * 0.1, GOLD, HALF_WIDTH + 0.6, 0.45, WHITE, NAVY)
		VfxKit.flash(_field, at + Vector3.UP * 0.6, WHITE, 5.0, 0.25)
		for k in [-1.0, 0.0, 1.0]:
			var p := _at(front + FALL_REACH * 0.6, k * HALF_WIDTH * 0.75)
			VfxKit.sparks(_field, p + Vector3.UP * 0.3, GOLD if k == 0.0 else WHITE, 18, 7.0, 0.6)
			VfxKit.impact_smoke(_field, p + Vector3.UP * 0.2, Color(0.72, 0.74, 0.82), 1.6)
	)
	_sound(SkillSound.landing(skill), -2.0)
	_sound(SkillSound.star_beat(0), -3.0)
	if by_hero and is_instance_valid(caster):
		VfxBudget.hero_begin()
		SkillFeel.impact(caster, skill, at, HALF_WIDTH, 0, 1)
		VfxBudget.hero_end()
	for foe: Node3D in victims:
		_strike(foe, CRUSH_SHARE, true)
	if by_hero:
		SkillFeel.beat_done()


func _strike(foe: Node3D, share: float, crush: bool) -> void:
	if not _alive(foe):
		return
	var mult := total_mult * share * def_factor
	hits += 1
	last.hits = hits
	if by_hero:
		var hero := caster as Hero
		VfxBudget.hero_begin()
		if not crush:
			VfxKit.impact(_field, (foe as Mob).hit_point(), WHITE, 1.2)
		hero._deal(foe as Mob, mult, BLUE, &"light", false, skill)
		VfxBudget.hero_end()
	else:
		var rival := caster as Rival
		rival._hit(foe, mult, BLUE, skill.get("fx", {}) if crush else {})
		if is_instance_valid(foe) and foe is Mob and _movable(foe):
			(foe as Mob).apply_stun(DRIVE_TIME + TIP)


# ---------------------------------------------------------------------------
# The wall
# ---------------------------------------------------------------------------

func _room(fn: Callable) -> void:
	if not is_instance_valid(_field):
		return
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
		AudioManager.play_sfx_at(_at(front, 0.0), id, db - 4.0)


func _build() -> void:
	if not (_field is Node3D) or not VfxBudget.can_decorate(2):
		return
	_wall = Node3D.new()
	_wall.name = "BastionWall"
	_field.add_child(_wall)
	VfxBudget.track_decoration(_wall)
	_wall.global_basis = Basis.looking_at(-forward, Vector3.UP)
	_pivot = Node3D.new()
	_wall.add_child(_pivot)
	var body := MeshInstance3D.new()
	body.mesh = wall_mesh()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = K.SOLID
	_mat.set_shader_parameter("age", 1000.0)
	_mat.set_shader_parameter("flight", 0.001)
	_mat.set_shader_parameter("rim_color", Color(0.75, 0.88, 1.0))
	_mat.set_shader_parameter("rim", 0.9)
	_mat.set_shader_parameter("glow_color", Color(1.0, 0.86, 0.45))
	_mat.set_shader_parameter("heat", 1.4)
	body.material_override = _mat
	# The shields stand just behind the face (their front is the face line).
	body.position = Vector3(0, 0, -0.2)
	_pivot.add_child(body)
	_place()
	_rise(0.0)
	if by_hero or VfxBudget.quality() > 0:
		_trail = MeshInstance3D.new()
		_trail.name = "BastionTrail"
		_trail.mesh = trail_mesh()
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_trail.material_override = m
		_field.add_child(_trail)
		_trail.global_basis = Basis.looking_at(-forward, Vector3.UP)


func _place() -> void:
	if is_instance_valid(_wall):
		_wall.global_position = _at(front, 0.0) + Vector3(0, _ground_y(), 0)
	if is_instance_valid(_trail):
		var run := maxf(front - START, 0.01)
		_trail.global_position = _at(START, 0.0) + Vector3(0, _ground_y() + 0.05, 0)
		_trail.scale = Vector3(1, 1, run)


func _ground_y() -> float:
	return origin.y


func _rise(t: float) -> void:
	if not is_instance_valid(_pivot):
		return
	var e := 1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0)
	_pivot.position.y = -SHIELD_H * 1.05 * (1.0 - e)
	if t > 0.0:
		_dust()


## The shields tip over their front edge and slam flat ([param t] 0..1, accelerating).
func _tip(t: float) -> void:
	if not is_instance_valid(_pivot):
		return
	_pivot.position.y = 0.0
	var e := clampf(t, 0.0, 1.0)
	_pivot.rotation.x = PI * 0.5 * e * e
	if e >= 1.0 and _mat and float(_mat.get_shader_parameter("age")) > 100.0:
		_mat.set_shader_parameter("age", 0.002)


func _dust() -> void:
	if clock < _dust_at or not is_instance_valid(_field):
		return
	_dust_at = clock + (0.09 if by_hero else 0.2)
	var side := randf_range(-1.0, 1.0) * HALF_WIDTH
	_room(func():
		VfxKit.impact_smoke(_field, _at(front + 0.3, side) + Vector3.UP * 0.15, Color(0.74, 0.72, 0.68), 1.1)
		if by_hero:
			VfxKit.sparks(_field, _at(front, side) + Vector3.UP * 0.2, GOLD, 6, 3.0, 0.35)
	)


## Five celestial tower shields side by side on a shallow arc, their faces to +Z (the
## wall's forward), standing on the origin line: one SOLID mesh (one draw).
static func wall_mesh() -> ArrayMesh:
	if _cache.has("wall"):
		return _cache.wall
	var st := K.begin()
	var part := _shield()
	for i in 5:
		var k := float(i) - 2.0
		var x := k * SHIELD_W * 0.94
		var z := -absf(k) * 0.22
		var yaw := -k * 0.07
		var lift := 1.0 + (0.12 if i == 2 else 0.0) - absf(k) * 0.04
		var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(SHIELD_W, SHIELD_H * lift, SHIELD_W * 0.9))
		K.stamp(st, part, Transform3D(basis, Vector3(x, 0, z)), 0.0, 0.0)
	_cache.wall = K.finish(st, Vector3(1, 1, 1))
	return _cache.wall


## A tower shield of the heavens, 1 wide and 1 tall, standing on its base, both faces
## dressed: a blue field, a white-gold rim, a star boss and wings of light.
static func _shield() -> K.Part:
	var p := K.Part.new()
	var outline := PackedVector2Array([Vector2(-0.44, 0.0), Vector2(0.44, 0.0), Vector2(0.5, 0.18), Vector2(0.5, 0.78), Vector2(0.36, 0.92), Vector2(0.0, 1.0), Vector2(-0.36, 0.92), Vector2(-0.5, 0.78), Vector2(-0.5, 0.18)])
	var inner := PackedVector2Array()
	for q in outline:
		inner.append(Vector2(q.x * 0.8, 0.52 + (q.y - 0.52) * 0.84))
	p.ink(BLUE.darkened(0.15), 0.6)
	p.slab(outline, -0.05, 0.05)
	for s in [-1.0, 1.0]:
		p.ink(NAVY.lightened(0.15), 0.4)
		p.slab(inner, s * 0.05, s * 0.06)
		p.ink(WHITE, 0.9, 0.35)
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			p.tube(Vector3(a.x, a.y, s * 0.05), Vector3(b.x, b.y, s * 0.05), 0.035, 0.035, 4)
		# The star boss: eight rays of gold round a white gem.
		p.ink(GOLD, 0.9, 0.5)
		p.tube(Vector3(0, 0.56, s * 0.06), Vector3(0, 0.56, s * 0.14), 0.13, 0.07, 8)
		for k in 8:
			var a := TAU * float(k) / 8.0
			var reach := 0.34 if k % 2 == 0 else 0.2
			p.tube(Vector3(0, 0.56, s * 0.065), Vector3(sin(a) * reach, 0.56 + cos(a) * reach, s * 0.065), 0.05 if k % 2 == 0 else 0.03, 0.0, 4, 0.3)
		p.ink(WHITE, 0.0, 1.0)
		p.gem(Vector3(0, 0.56, s * 0.15), Vector3(0.05, 0.05, 0.025))
		# A pair of wings of light under the boss, and a band of gold at the foot.
		p.ink(WHITE.lerp(BLUE, 0.25), 0.6, 0.8)
		for x in [-1.0, 1.0]:
			for k in 3:
				var t := float(k) / 2.0
				p.tube(Vector3(x * 0.1, 0.36 - t * 0.04, s * 0.065), Vector3(x * (0.36 - t * 0.06), 0.42 - t * 0.14, s * 0.065), 0.035, 0.0, 4, 0.3)
		p.ink(GOLD, 0.8, 0.3)
		p.box(Vector3(0, 0.07, s * 0.055), Vector3(0.84, 0.05, 0.02))
	return p


## The seam the wall ploughs: two hot gold furrows under its ends and a faint blue glow
## between, 1 m long along +Z (scaled to the run), as wide as the wall.
static func trail_mesh() -> ArrayMesh:
	if _cache.has("trail"):
		return _cache.trail
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-HALF_WIDTH - 0.2, -HALF_WIDTH + 0.25, -HALF_WIDTH + 0.7, 0.0, HALF_WIDTH - 0.7, HALF_WIDTH - 0.25, HALF_WIDTH + 0.2]
	var cs := [Color(0, 0, 0, 0), Color(1.0, 0.78, 0.3, 0.9), Color(0.2, 0.4, 0.9, 0.25), Color(0.35, 0.55, 1.0, 0.35), Color(0.2, 0.4, 0.9, 0.25), Color(1.0, 0.78, 0.3, 0.9), Color(0, 0, 0, 0)]
	for i in xs.size() - 1:
		var a0 := Vector3(xs[i], 0, 0)
		var b0 := Vector3(xs[i + 1], 0, 0)
		var a1 := Vector3(xs[i], 0, 1)
		var b1 := Vector3(xs[i + 1], 0, 1)
		var ca: Color = cs[i]
		var cb: Color = cs[i + 1]
		# Fades out towards where the wall rose (z 0) and is brightest under the wall (z 1).
		var fa := Color(ca.r, ca.g, ca.b, ca.a * 0.25)
		var fb := Color(cb.r, cb.g, cb.b, cb.a * 0.25)
		for item in [[a0, fa], [b0, fb], [b1, cb], [a0, fa], [b1, cb], [a1, ca]]:
			st.set_color(item[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(item[0])
	_cache.trail = st.commit()
	return _cache.trail
