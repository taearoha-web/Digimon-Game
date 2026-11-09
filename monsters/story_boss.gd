class_name StoryBoss
extends Node
## The chapter bosses' (StoryChapter2.MONSTERS) special moves, a node on the boss Mob like
## WorldBoss. Every CYCLE seconds one move from `moves` (in turn), each shown TELEGRAPH
## seconds ahead as violet shapes on the ground, then it hits whoever is still inside for
## HIT_FRACTION of their max HP (world players take a flat hit):
##   "nova"  a ring round the boss (NOVA_RADIUS) — step away;
##   "lance" a line toward its victim (LANCE_WIDTH x LANCE_LENGTH) — step aside;
##   "rain"  RAIN_COUNT circles dropped on the hero and its allies — move;
##   "veil"  a ring the boss's adds (`adds`) burst out of, at ADD_HP of their health.
## set_moves changes the set (the queen's phases, StoryStage). One telegraph at a time;
## the Mob's own slam waits while one is up. Nothing chases a dodging player: every shape
## is placed when the move starts.

const TITLES := {"nova": "คลื่นเงา", "lance": "หอกเงา", "rain": "ฝนดาวดับ", "veil": "ม่านเงา"}
const CYCLE := Vector2(8.0, 12.0)
const TELEGRAPH := 1.7
const HIT_FRACTION := 0.35
const NOVA_RADIUS := 6.5
const LANCE_WIDTH := 3.2
const LANCE_LENGTH := 20.0
const RAIN_RADIUS := 3.0
const RAIN_COUNT := 3
const VEIL_RADIUS := 4.5
const ADD_COUNT := 3
const ADD_HP := 0.5
const COLOR := Color("9a5cff")

var mob: Mob
var zone: Node3D
var moves: Array = ["nova", "lance"]
var adds: Array = []
## Seconds between moves scale by this (StoryStage shortens it per phase).
var haste := 1.0
## The telegraph up now, or {} between moves: {kind, shapes: [{center, radius} | {center, dir}], left}.
var telegraph: Dictionary = {}
var specials := 0
var _cycle := 0.0
var _next := 0
var _meshes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


## The StoryBoss node on a mob, or null.
static func of(m: Node) -> StoryBoss:
	if m == null or not is_instance_valid(m):
		return null
	return m.get_node_or_null("StoryBoss") as StoryBoss


func setup(p_mob: Mob, p_zone: Node3D, p_moves: Array, p_adds: Array = []) -> void:
	mob = p_mob
	zone = p_zone
	moves = p_moves.duplicate()
	adds = p_adds.duplicate()
	name = "StoryBoss"
	_rng.seed = hash("story|%s" % String(mob.monster_id))
	_cycle = CYCLE.x * 0.5


func set_moves(p_moves: Array, p_haste := 1.0) -> void:
	moves = p_moves.duplicate()
	haste = p_haste
	_next = 0
	_cycle = minf(_cycle, 2.5)


func _process(delta: float) -> void:
	tick(delta)


## One step; at most one transition per call (tests drive it with big deltas).
func tick(delta: float) -> void:
	if mob == null or not is_instance_valid(mob) or mob.is_dead():
		_clear()
		return
	if not telegraph.is_empty():
		telegraph["left"] = float(telegraph.left) - delta
		mob._slam_timer = maxf(mob._slam_timer, 1.0)
		if float(telegraph.left) <= 0.0:
			_fire()
		return
	if mob._returning or mob._stun > 0.0 or moves.is_empty():
		return
	_cycle -= delta
	if _cycle <= 0.0:
		force_special(String(moves[_next % moves.size()]))
		_next = (_next + 1) % maxi(moves.size(), 1)


## Starts a move's telegraph now.
func force_special(kind: String) -> void:
	if mob == null or not is_instance_valid(mob) or mob.is_dead() or not telegraph.is_empty() or not TITLES.has(kind):
		return
	var center := mob.global_position
	center.y = 0.0
	var shapes: Array = []
	match kind:
		"nova":
			shapes.append({"center": center, "radius": NOVA_RADIUS})
		"veil":
			shapes.append({"center": center, "radius": VEIL_RADIUS})
		"lance":
			var dir := Vector3.FORWARD
			var target: Node3D = mob._victim if mob._alive(mob._victim) else mob.hero
			if target != null and is_instance_valid(target):
				var to := target.global_position - mob.global_position
				to.y = 0.0
				if to.length_squared() > 0.01:
					dir = to.normalized()
			shapes.append({"center": center, "dir": dir})
		"rain":
			var spots: Array = []
			for v in _allies():
				spots.append(v.global_position)
			if spots.is_empty():
				spots.append(center + Vector3.FORWARD * 5.0)
			for i in RAIN_COUNT:
				var at: Vector3 = spots[i % spots.size()]
				var jitter := Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)) if i >= spots.size() else Vector3.ZERO
				shapes.append({"center": Vector3(at.x, 0, at.z) + jitter, "radius": RAIN_RADIUS})
	telegraph = {"kind": kind, "shapes": shapes, "left": TELEGRAPH}
	_cycle = _rng.randf_range(CYCLE.x, CYCLE.y) * haste
	mob._winding = true
	mob._slam_timer = maxf(mob._slam_timer, TELEGRAPH + 1.0)
	mob.visual.flash(Color(0.7, 0.4, 1.0), TELEGRAPH)
	mob.visual.action("attack", int(TELEGRAPH * 1000.0))
	mob._anim_lock = GameClock.msec() + int(TELEGRAPH * 1000.0)
	BattleVfx.floating_text(zone, mob.top_point() + Vector3(0, 0.9, 0), String(TITLES[kind]) + "!", Color("d9b8ff"), 1.3)
	_draw()


## Is a flat point inside the telegraph now?
func inside(point: Vector3) -> bool:
	if telegraph.is_empty():
		return false
	for s in telegraph.shapes:
		var c: Vector3 = s.center
		var d := Vector3(point.x - c.x, 0, point.z - c.z)
		if s.has("radius"):
			if d.length() <= float(s.radius):
				return true
		else:
			var dir: Vector3 = s.dir
			var along := d.dot(dir)
			var side := (d - dir * along).length()
			if along >= -0.5 and along <= LANCE_LENGTH and side <= LANCE_WIDTH * 0.5:
				return true
	return false


func _fire() -> void:
	var kind := String(telegraph.kind)
	var shapes: Array = telegraph.shapes
	var victims := _victims_inside()
	telegraph = {}
	_clear()
	specials += 1
	mob._winding = false
	if mob.is_dead():
		return
	var color: Color = mob.template.get("color", COLOR)
	for s in shapes:
		var c: Vector3 = s.center
		if s.has("radius"):
			VfxKit.shockwave(zone, c + Vector3(0, 0.1, 0), color, float(s.radius))
			BattleVfx.burst(zone, c + Vector3(0, 0.4, 0), color, 24, 1.3)
		else:
			var dir: Vector3 = s.dir
			VfxKit.lightning(zone, mob.hit_point(), c + dir * LANCE_LENGTH + Vector3(0, 0.8, 0), color)
			VfxKit.pillar(zone, c + dir * (LANCE_LENGTH * 0.5), color, 3.0, LANCE_WIDTH * 0.5, 0.4)
	if kind == "veil":
		_summon(shapes[0].center)
	for v in victims:
		_hit(v)


## The hero, party members and world players alive here.
func _allies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if mob._alive(mob.hero):
		out.append(mob.hero)
	for group in ["companions", "world_players"]:
		for node in get_tree().get_nodes_in_group(group):
			var n := node as Node3D
			if mob._alive(n):
				out.append(n)
	return out


func _victims_inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in _allies():
		if inside(n.global_position):
			out.append(n)
	return out


## HIT_FRACTION of max HP after the victim's own mitigation (as WorldBoss._hit).
func _hit(victim: Node3D) -> void:
	var raw := float(mob.stats.atk) * mob._atk_scale * 2.0
	if victim is Hero:
		var h := victim as Hero
		raw = HIT_FRACTION * float(h.stats.max_hp) * (100.0 + maxf(h.effective_def(), 0.0)) / 100.0
	elif victim is Companion and not victim.is_in_group("world_players"):
		var c := victim as Companion
		raw = HIT_FRACTION * float(c.max_hp) * (100.0 + maxf(float(c.stats.def) * (1.0 + c._book.total("def")), 0.0)) / 100.0
	elif victim.has_method("boss_hit"):
		victim.boss_hit(HIT_FRACTION)
		return
	Mob.strike(victim, raw, mob)


func _summon(center: Vector3) -> void:
	if adds.is_empty():
		return
	for i in ADD_COUNT:
		var angle := TAU * float(i) / float(ADD_COUNT) + _rng.randf()
		var spot := center + Vector3(cos(angle), 0, sin(angle)) * VEIL_RADIUS
		var add := Mob.new()
		add.setup(adds[_rng.randi() % adds.size()], maxi(1, mob.level - 10), spot, mob.hero)
		add.hp = maxi(1, int(float(add.max_hp) * ADD_HP))
		add.position = spot + Vector3(0, 0.3, 0)
		add.set_meta("story_add", true)
		zone.add_child(add)
		add.hostile = true
		BattleVfx.burst(zone, spot + Vector3(0, 0.4, 0), COLOR, 12, 0.8)


# --- The shapes on the ground --------------------------------------------------------

func _draw() -> void:
	_clear()
	for s in telegraph.shapes:
		if s.has("radius"):
			_ring(s.center, float(s.radius))
		else:
			var dir: Vector3 = s.dir
			var center: Vector3 = s.center
			var box := MeshInstance3D.new()
			box.mesh = MeshKit.box()
			box.material_override = _material(0.3)
			box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			zone.add_child(box)
			box.global_position = center + dir * 0.1 + Vector3(0, 0.05, 0)
			box.rotation.y = atan2(dir.x, dir.z)
			box.scale = Vector3(LANCE_WIDTH, 0.04, 0.2)
			VfxBudget.track_decoration(box)
			_meshes.append(box)
			var grow := box.create_tween().set_parallel(true)
			grow.tween_property(box, "scale:z", LANCE_LENGTH, TELEGRAPH)
			grow.tween_property(box, "global_position", center + dir * (LANCE_LENGTH * 0.5) + Vector3(0, 0.05, 0), TELEGRAPH)


func _ring(center: Vector3, radius: float) -> void:
	var edge := MeshInstance3D.new()
	edge.mesh = MeshKit.torus()
	edge.material_override = _material(0.9)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(edge)
	edge.global_position = center + Vector3(0, 0.06, 0)
	edge.scale = Vector3(radius, radius * 0.06, radius)
	VfxBudget.track_decoration(edge)
	_meshes.append(edge)
	var fill := MeshInstance3D.new()
	fill.mesh = MeshKit.cylinder()
	var fill_mat := _material(0.22)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(fill)
	fill.global_position = center + Vector3(0, 0.05, 0)
	fill.scale = Vector3(0.2, 0.02, 0.2)
	VfxBudget.track_decoration(fill)
	_meshes.append(fill)
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


func _clear() -> void:
	for m in _meshes:
		if is_instance_valid(m):
			m.queue_free()
	_meshes.clear()


func _exit_tree() -> void:
	_clear()
