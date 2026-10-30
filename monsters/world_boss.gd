class_name WorldBoss
extends Node
## The world boss's (WorldEvents, Zone._tick_world_boss) special moves, a node on the
## spawned boss Mob. Every CYCLE seconds one of three moves, each shown TELEGRAPH
## seconds ahead as a red shape on the ground so players can step out, then it hits
## everyone still inside for HIT_FRACTION of their max HP (world players take a flat
## hit): "กระทืบ" a circle round the boss, "ลำแสง" a line toward the hero, "เรียกพวก"
## a ring the field's monsters burst out of. At 60% and 30% HP it roars and the cycle
## shortens by ROAR_HASTE. One telegraph at a time, two cheap meshes at most; the Mob's
## own slam waits while a telegraph is up.

const KINDS := ["stomp", "beam", "summon"]
const TITLES := {"stomp": "กระทืบ", "beam": "ลำแสง", "summon": "เรียกพวก"}
const CYCLE := Vector2(9.0, 14.0)
const TELEGRAPH := 1.6
const HIT_FRACTION := 0.35
const STOMP_RADIUS := 6.0
const BEAM_WIDTH := 3.0
const BEAM_LENGTH := 18.0
const SUMMON_RADIUS := 4.0
const SUMMON_COUNT := 3
const SUMMON_HP := 0.6
const ROAR_HASTE := 0.75
const ROAR_AT := [0.6, 0.3]
const ROAR_TEXT := "บอสโลกคำราม! เร็วขึ้น"
const COLOR := Color("ff3a3a")

var mob: Mob
var zone: Zone
## Roars so far (0-2); each one shortens the cycle.
var phase := 0
## The telegraph on the ground, or {} between moves: {kind, center, dir, left}.
var telegraph: Dictionary = {}
var specials := 0
var _cycle := 0.0
var _haste := 1.0
var _next_kind := 0
var _shapes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


## The WorldBoss node on a mob, or null for an ordinary monster.
static func of(m: Node) -> WorldBoss:
	if m == null or not is_instance_valid(m):
		return null
	return m.get_node_or_null("WorldBoss") as WorldBoss


func setup(p_mob: Mob, p_zone: Zone) -> void:
	mob = p_mob
	zone = p_zone
	name = "WorldBoss"
	_rng.seed = hash("wboss|%d" % int(mob.get_meta("world_boss", 0)))
	_cycle = _rng.randf_range(CYCLE.x, CYCLE.y) * 0.6


func _process(delta: float) -> void:
	tick(delta)


## One step: a telegraph counts down and lands; otherwise the cycle counts down to the
## next move. At most one transition per call, so tests can drive it with big deltas.
func tick(delta: float) -> void:
	if mob == null or not is_instance_valid(mob) or mob.is_dead():
		_clear_shapes()
		return
	_check_roar()
	if not telegraph.is_empty():
		telegraph["left"] = float(telegraph.left) - delta
		mob._slam_timer = maxf(mob._slam_timer, 1.0)
		if float(telegraph.left) <= 0.0:
			_fire()
		return
	if mob._returning or mob._stun > 0.0:
		return
	_cycle -= delta
	if _cycle <= 0.0:
		force_special(KINDS[_next_kind])
		_next_kind = (_next_kind + 1) % KINDS.size()


## Starts a move's telegraph now (tests, and the cycle).
func force_special(kind: String) -> void:
	if mob == null or not is_instance_valid(mob) or mob.is_dead() or not telegraph.is_empty():
		return
	var center := mob.global_position
	center.y = 0.0
	var dir := Vector3.FORWARD
	if kind == "beam":
		var target: Node3D = mob._victim if mob._alive(mob._victim) else mob.hero
		if target != null and is_instance_valid(target):
			var to := target.global_position - mob.global_position
			to.y = 0.0
			if to.length_squared() > 0.01:
				dir = to.normalized()
	telegraph = {"kind": kind, "center": center, "dir": dir, "left": TELEGRAPH}
	_cycle = _rng.randf_range(CYCLE.x, CYCLE.y) * _haste
	mob._winding = true
	mob._slam_timer = maxf(mob._slam_timer, TELEGRAPH + 1.0)
	mob.visual.flash(Color(1.0, 0.3, 0.2), TELEGRAPH)
	mob.visual.action("attack", int(TELEGRAPH * 1000.0))
	mob._anim_lock = Time.get_ticks_msec() + int(TELEGRAPH * 1000.0)
	BattleVfx.floating_text(zone, mob.top_point() + Vector3(0, 0.9, 0), String(TITLES[kind]) + "!", Color("ffb3a0"), 1.3)
	_draw_telegraph()


## Is a flat point inside the telegraph on the ground now?
func inside(point: Vector3) -> bool:
	if telegraph.is_empty():
		return false
	var c: Vector3 = telegraph.center
	var d := Vector3(point.x - c.x, 0, point.z - c.z)
	match String(telegraph.kind):
		"stomp":
			return d.length() <= STOMP_RADIUS
		"summon":
			return d.length() <= SUMMON_RADIUS
		"beam":
			var dir: Vector3 = telegraph.dir
			var along := d.dot(dir)
			var side := (d - dir * along).length()
			return along >= -0.5 and along <= BEAM_LENGTH and side <= BEAM_WIDTH * 0.5
	return false


## The nearest spot outside the telegraph for whoever stands at `point`: 7 m out of a
## circle, 7 m to the side of the beam.
func escape_point(point: Vector3) -> Vector3:
	if telegraph.is_empty():
		return point
	var c: Vector3 = telegraph.center
	var d := Vector3(point.x - c.x, 0, point.z - c.z)
	if String(telegraph.kind) == "beam":
		var dir: Vector3 = telegraph.dir
		var side := d - dir * d.dot(dir)
		var perp := side.normalized() if side.length_squared() > 0.01 else dir.rotated(Vector3.UP, PI * 0.5)
		return Vector3(point.x, point.y, point.z) + perp * 7.0
	var out := d.normalized() if d.length_squared() > 0.01 else Vector3.FORWARD
	return Vector3(point.x, point.y, point.z) + out * 7.0


func _fire() -> void:
	var kind := String(telegraph.kind)
	var center: Vector3 = telegraph.center
	var dir: Vector3 = telegraph.dir
	var victims := _victims_inside()
	telegraph = {}
	_clear_shapes()
	specials += 1
	mob._winding = false
	if mob.is_dead():
		return
	var color: Color = mob.template.get("color", Color("ff6a4a"))
	match kind:
		"stomp":
			VfxKit.shockwave(zone, center + Vector3(0, 0.1, 0), color, STOMP_RADIUS)
			BattleVfx.burst(zone, center + Vector3(0, 0.4, 0), color, 30, 1.4)
		"beam":
			var far := center + dir * BEAM_LENGTH
			VfxKit.lightning(zone, mob.hit_point(), far + Vector3(0, 0.8, 0), color)
			VfxKit.pillar(zone, center + dir * (BEAM_LENGTH * 0.5), color, 3.0, BEAM_WIDTH * 0.5, 0.4)
		"summon":
			VfxKit.shockwave(zone, center + Vector3(0, 0.1, 0), Color("ffd84a"), SUMMON_RADIUS)
			_summon(center)
	for v in victims:
		_hit(v)


## Hero, party members and world players standing in the telegraph.
func _victims_inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if mob._alive(mob.hero) and inside(mob.hero.global_position):
		out.append(mob.hero)
	for group in ["companions", "world_players"]:
		for node in get_tree().get_nodes_in_group(group):
			var n := node as Node3D
			if mob._alive(n) and inside(n.global_position):
				out.append(n)
	return out


## HIT_FRACTION of max HP after the victim's own mitigation (HeroStats.mitigate is
## raw * 100 / (100 + DEF), so the raw hit is scaled back up); a world player takes
## twice the boss's attack instead.
func _hit(victim: Node3D) -> void:
	var raw := float(mob.stats.atk) * mob._atk_scale * 2.0
	if victim is Hero:
		var h := victim as Hero
		raw = HIT_FRACTION * float(h.stats.max_hp) * (100.0 + maxf(h.effective_def(), 0.0)) / 100.0
	elif victim is Companion and not victim.is_in_group("world_players"):
		var c := victim as Companion
		raw = HIT_FRACTION * float(c.max_hp) * (100.0 + maxf(float(c.stats.def) * (1.0 + c._book.total("def")), 0.0)) / 100.0
	victim.take_damage(raw, mob)


## Three of the field's monsters at SUMMON_HP, hostile, on the summon ring.
func _summon(center: Vector3) -> void:
	var ids: Array = []
	for camp in zone.data.get("camps", []):
		ids.append_array(camp.monsters)
	if ids.is_empty():
		return
	for i in SUMMON_COUNT:
		var angle := TAU * float(i) / float(SUMMON_COUNT) + _rng.randf()
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * SUMMON_RADIUS
		var add := Mob.new()
		add.setup(ids[_rng.randi() % ids.size()], maxi(1, mob.level - 4), spot, mob.hero)
		add.hp = maxi(1, int(float(add.max_hp) * SUMMON_HP))
		add.position = spot + Vector3(0, 0.3, 0)
		add.set_meta("world_boss_add", true)
		zone.add_child(add)
		add.hostile = true
		BattleVfx.burst(zone, spot + Vector3(0, 0.4, 0), Color("ffd84a"), 12, 0.8)


## At 60% and 30% HP: a roar, the banner, and a faster cycle.
func _check_roar() -> void:
	if phase >= ROAR_AT.size():
		return
	var ratio := float(mob.hp) / float(maxi(1, mob.max_hp))
	if ratio > float(ROAR_AT[phase]):
		return
	phase += 1
	_haste *= ROAR_HASTE
	_cycle = minf(_cycle, CYCLE.x * _haste)
	var color: Color = mob.template.get("color", Color("ff6a4a"))
	VfxKit.shockwave(zone, mob.global_position + Vector3(0, 0.1, 0), color, 7.0)
	mob.visual.flash(Color(1.0, 0.2, 0.15), 1.0)
	BattleVfx.floating_text(zone, mob.top_point() + Vector3(0, 0.9, 0), "คำราม!", Color("ff4a4a"), 1.5)
	zone.banner_requested.emit(ROAR_TEXT)
	Game.say(ROAR_TEXT, &"warning")


# --- The shape on the ground --------------------------------------------------------

func _draw_telegraph() -> void:
	_clear_shapes()
	var center: Vector3 = telegraph.center
	match String(telegraph.kind):
		"stomp":
			_ring(center, STOMP_RADIUS)
		"summon":
			_ring(center, SUMMON_RADIUS)
		"beam":
			var dir: Vector3 = telegraph.dir
			var box := MeshInstance3D.new()
			box.mesh = MeshKit.box()
			box.material_override = _material(0.3)
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			zone.add_child(box)
			box.global_position = center + dir * (BEAM_LENGTH * 0.5) + Vector3(0, 0.05, 0)
			box.rotation.y = atan2(dir.x, dir.z)
			box.scale = Vector3(BEAM_WIDTH, 0.04, BEAM_LENGTH)
			VfxBudget.track_decoration(box)
			_shapes.append(box)
			# The line fills from the boss outward over the telegraph.
			box.scale.z = 0.2
			box.global_position = center + dir * 0.1 + Vector3(0, 0.05, 0)
			var grow := box.create_tween().set_parallel(true)
			grow.tween_property(box, "scale:z", BEAM_LENGTH, TELEGRAPH)
			grow.tween_property(box, "global_position", center + dir * (BEAM_LENGTH * 0.5) + Vector3(0, 0.05, 0), TELEGRAPH)


## A red edge ring and a disc that fills up to the edge over the telegraph.
func _ring(center: Vector3, radius: float) -> void:
	var edge := MeshInstance3D.new()
	edge.mesh = MeshKit.torus()
	edge.material_override = _material(0.9)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(edge)
	edge.global_position = center + Vector3(0, 0.06, 0)
	edge.scale = Vector3(radius, radius * 0.06, radius)
	VfxBudget.track_decoration(edge)
	_shapes.append(edge)
	var fill := MeshInstance3D.new()
	fill.mesh = MeshKit.cylinder()
	var fill_mat := _material(0.25)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(fill)
	fill.global_position = center + Vector3(0, 0.05, 0)
	fill.scale = Vector3(0.2, 0.02, 0.2)
	VfxBudget.track_decoration(fill)
	_shapes.append(fill)
	var tween := fill.create_tween().set_parallel(true)
	tween.tween_property(fill, "scale", Vector3(radius, 0.02, radius), TELEGRAPH)
	tween.tween_property(fill_mat, "albedo_color:a", 0.55, TELEGRAPH)


func _material(alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _clear_shapes() -> void:
	for s in _shapes:
		if is_instance_valid(s):
			s.queue_free()
	_shapes.clear()


func _exit_tree() -> void:
	_clear_shapes()
