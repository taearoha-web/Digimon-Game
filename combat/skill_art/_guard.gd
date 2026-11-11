extends RefCounted
## Shared kit of the Defender and Assassin class-skill signatures (combat/skill_art, the
## Lv.60-100 skills of team "guard"), on top of the melee kits (combat/god_art/_kit_melee.gd
## and combat/star_art/_melee.gd: their three shaders, mesh builders and impact layers).
##
## Every piece is one layer of a Root (a StarSkillArt with its one clock, the 2/4/6 layer cap
## and the VfxBudget decoration count). A cast is a few finite roots, all authored when the
## beat is called (later moments are layer delays on the same clock, never timers):
##   * the wind-up root is tied to the caster's skill motion (HeroVisual.skill_generation):
##     a cancelled cast, a death or a zone change drops it at once;
##   * every root watches its caster: when the caster dies it fades out within
##     StarSkillArt.CLOSE seconds;
##   * the player's own hero (VfxBudget.for_hero) gets the whole set piece; a companion, an
##     AI player or a rival gets the core root only, with at most LITE_CAP layers, so a
##     guild war full of casters stays light; memory pressure and quality 0 cut the
##     extra roots as well.
## Cosmetic ONLY: the hero / companion code owns every hit, target, buff and timing.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const LITE_CAP := 3
## Seconds between the hops a chain's carrier makes from victim to victim.
const HOP := 0.11
## Hit flashes one cast may draw in one frame (the hero / anyone else).
const HITS := [4, 1]
## Upright emblems lean back this much (about X) to meet the raised gameplay camera.
const TILT_BACK := -0.22
static var _casts := {}
static var _hits := {}
static var _hops := {}


## A root of a guard signature: a StarSkillArt that keeps its own (lower) layer cap and
## closes when its caster dies.
class Root extends StarSkillArt:
	var cap := 6
	var caster_ref: WeakRef

	func add_mesh(geometry: Mesh, label: String, colors: Dictionary, at: Vector3, size: Vector3, angles: Vector3, seconds: float, style := {}) -> void:
		if layers.size() >= cap:
			return
		super(geometry, label, colors, at, size, angles, seconds, style)

	func _process(delta: float) -> void:
		if caster_ref and _closing < 0.0 and Root.down(caster_ref.get_ref()):
			_closing = age
		super(delta)

	## The caster is gone or lies dead.
	static func down(caster: Variant) -> bool:
		var node := caster as Node
		if not is_instance_valid(node) or not node.is_inside_tree() or node.is_queued_for_deletion():
			return true
		if node.has_method("is_dead"):
			return bool(node.call("is_dead"))
		return bool(node.get("_dead")) if node.get("_dead") != null else false


# ---------------------------------------------------------------------------
# Who casts, and how much they may show
# ---------------------------------------------------------------------------
static func q() -> int:
	return VfxBudget.quality()


## The player's own hero casts this (the whole set piece may play).
static func hero() -> bool:
	return VfxBudget.for_hero()


## How many roots beyond the core one this beat may open: none for anyone but the hero,
## none under memory pressure, fewer at low quality.
static func extras(want: int) -> int:
	if not hero() or MemoryGuard.pressure > 0 or not VfxBudget.can_decorate(4):
		return 0
	return mini(want, [1, 2, 4][q()])


## Pieces in a burst. Burst meshes are cached by key and shared by every cast, so the count
## is fixed (one draw either way); quality and the caster cut layers and roots instead.
static func n(high: int, _low := 3) -> int:
	return high


## The wind-up remembers its caster so the release (which only gets the caster's feet)
## can tie its roots to the same caster.
static func note(skill: Dictionary, visual: HeroVisual, origin: Vector3, aim: Vector3) -> Node3D:
	var caster: Node3D = visual.get_parent() as Node3D if is_instance_valid(visual) else null
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	var list: Array = _casts.get(id, [])
	list = list.filter(func(e): return now - int(e.ms) < 4000 and (e.ref as WeakRef).get_ref() != null)
	if caster:
		list.append({"ref": weakref(caster), "ms": now, "aim": aim, "origin": origin})
	_casts[id] = list
	if _casts.size() > 64:
		_casts.clear()
	return caster


## The caster of this release (the one whose feet are at [param origin]) and its aim.
static func caster_of(skill: Dictionary, origin: Vector3) -> Array:
	var id := String(skill.get("id", ""))
	var list: Array = _casts.get(id, [])
	var best := -1
	var near := 1.5
	for i in list.size():
		var node := (list[i].ref as WeakRef).get_ref() as Node3D
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var d := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if d < near:
			near = d
			best = i
	if best < 0:
		return [null, Vector3.INF]
	var entry: Dictionary = list[best]
	list.remove_at(best)
	return [(entry.ref as WeakRef).get_ref(), entry.aim]


## The flat yaw from [param from] to [param to] (or [param fallback] when they meet).
static func yaw(from: Vector3, to: Vector3, fallback := 0.0) -> float:
	var d := (to - from) * Vector3(1, 0, 1)
	return atan2(d.x, d.z) if d.length_squared() > 0.01 else fallback


## Where the caster faces (its model's yaw), 0 without one.
static func facing(caster: Node3D) -> float:
	if not is_instance_valid(caster):
		return 0.0
	var visual := StarSkillArt._visual(caster)
	var node: Node3D = visual if visual else caster
	var f := node.global_basis.z
	return atan2(f.x, f.z) if Vector2(f.x, f.z).length_squared() > 0.001 else 0.0


# ---------------------------------------------------------------------------
# Roots
# ---------------------------------------------------------------------------
## A root of the cast at [param at] turned to [param turn]. [param label] must carry the
## skill id. Null when there is no room.
static func open(parent: Node3D, at: Vector3, seconds: float, label: String, turn: float, caster: Node3D, cap := 6) -> Root:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return null
	if not VfxBudget.can_decorate():
		return null
	var r := Root.new()
	r.name = label
	r.lifetime = maxf(0.08, seconds)
	r.cap = mini(cap if hero() else mini(cap, LITE_CAP), [2, 4, 6][q()])
	if is_instance_valid(caster):
		r.caster_ref = weakref(caster)
	parent.add_child(r)
	r.global_position = at
	r.rotation.y = turn
	return r


## The wind-up root: also dropped the moment the caster's skill motion is cancelled.
static func windup(parent: Node3D, at: Vector3, seconds: float, label: String, turn: float, visual: HeroVisual, cap := 6) -> Root:
	var caster: Node3D = visual.get_parent() as Node3D if is_instance_valid(visual) else null
	var r := open(parent, at, seconds, label, turn, caster, cap)
	if r and is_instance_valid(visual):
		r.generation_ref = weakref(visual)
		r.generation = visual.skill_generation
	return r


## A root that rides along with the caster (a stance or aura round it).
static func aura(parent: Node3D, caster: Node3D, seconds: float, label: String, turn: float, cap := 6) -> Root:
	var at := caster.global_position if is_instance_valid(caster) else Vector3.ZERO
	var r := open(parent, at, seconds, label, turn, caster, cap)
	if r and is_instance_valid(caster):
		r.follow_ref = weakref(caster)
		r.follow_offset = Vector3.ZERO
	return r


## How much a piece [param height] m tall standing at [param spot] (root space) must shrink
## to stay inside the camera's frame (1: it fits).
static func sky_fit(r: Node3D, spot: Vector3, height: float) -> float:
	if r == null or not r.is_inside_tree():
		return 1.0
	return GodSkillArt.fit(r, r.to_global(spot), height, 0.6)


## The height a sky piece may use over [param spot] (root space): [param design] when the
## camera sees that high, lower when it does not, never below the head.
static func sky_height(r: Node3D, spot: Vector3, design: float) -> float:
	return maxf(2.3, K.sky(r, spot, design)) if r else design


## Shows the layers' first state at once (no frame of default transforms).
static func done(r: StarSkillArt) -> void:
	if r:
		r._draw()


# ---------------------------------------------------------------------------
# Layers (thin wrappers over the melee kits)
# ---------------------------------------------------------------------------
static func flat(r: StarSkillArt, mesh: Mesh, label: String, at: Vector3, size: Vector3, seconds: float, params := {}, style := {}, angles := Vector3.ZERO) -> ShaderMaterial:
	return K.put(r, K.FLAT, mesh, label, at, size, seconds, params, style, angles)


static func solid(r: StarSkillArt, mesh: Mesh, label: String, at: Vector3, size: Vector3, seconds: float, params := {}, style := {}, angles := Vector3.ZERO) -> ShaderMaterial:
	return K.put(r, K.SOLID, mesh, label, at, size, seconds, params, style, angles)


static func bits(r: StarSkillArt, mesh: Mesh, label: String, at: Vector3, seconds: float, params := {}, style := {}) -> ShaderMaterial:
	return K.put(r, K.BITS, mesh, label, at, Vector3.ONE, seconds, params, style)


## The usual light of a stroke: a tinted hot core (never white), additive.
static func lit(color: Color, add := 0.65, soft := 0.7, extra := {}) -> Dictionary:
	return {"soft": soft, "hot": M.hot(color), "core": 0.45, "add": add, "gain": 1.1}.merged(extra, true)


## Light motes rising and burning out (a heal, a blessing, a gathering).
static func motes(r: StarSkillArt, key: String, colors: Array, count: int, r0: float, r1: float, up: float, piece := 0.12, delay := 0.0, seconds := 1.2, seed_value := 11) -> void:
	bits(r, K.burst(key, "ember", count, r0, r1, 0.3, up, colors, piece, seconds * 0.4, seed_value, 0.1, 1.2), "Motes", Vector3.ZERO, seconds + delay, {"life": seconds * 0.7, "gravity": -0.6, "drag": 1.4, "piece": piece, "add": 0.85, "shrink": 0.3, "spin": 3.0}, {"delay": delay, "decay": 0.85})


## Pieces drawn IN from a ring to the centre (a vortex, a gathering): one BITS mesh whose
## pieces start on radii [param r0]..[param r1] and come to rest at the centre (drag).
static func inward(key: String, shape: String, count: int, r0: float, r1: float, colors: Array, piece: float, drag := 3.0, swirl := 0.6, spread := 0.3, seed_value := 13, y0 := 0.2, y1 := 1.4) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := rng.randf() * TAU
		var dir := Vector3(sin(a), 0, cos(a))
		var rad := lerpf(r0, r1, sqrt(rng.randf()))
		var origin := dir * rad + Vector3.UP * rng.randf_range(y0, y1)
		var side := Vector3(dir.z, 0, -dir.x)
		var vel := (-dir * rad + side * rad * swirl) * drag * rng.randf_range(0.85, 1.0) + Vector3.UP * rng.randf_range(-0.2, 0.6)
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.5, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, rng.randf() * spread, piece, basis)
	return M.keep(key, K.finish(st, Vector3.ONE * (r1 + 3.0), false))


## Spinning stars of a stun over the area (a level ring of [param count] stars, radius 1).
static func daze(r: StarSkillArt, color: Color, at: Vector3, size: float, seconds: float, delay := 0.0, count := 5) -> void:
	var key := "guard_daze_%d_%s" % [count, color.to_html()]
	if not M.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in count:
			var ang := TAU * float(i) / float(count)
			var c := Vector3(sin(ang), 0, cos(ang))
			var pts := PackedVector3Array()
			for k in 11:
				var a2 := TAU * float(k) / 10.0
				var rad := 0.22 if k % 2 == 0 else 0.09
				pts.append(c + Vector3(sin(a2) * rad, cos(a2) * rad, 0))
			K.ribbon(st, pts, 0.07, M.a(color, 1.0), 0.0, 0.0, Vector3.BACK, 0.0)
		M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))
	flat(r, M.get_mesh(key), "Daze", at, Vector3.ONE * size, seconds, {"soft": 0.4, "hot": M.hot(color), "core": 0.5, "add": 0.6}, {"delay": delay, "initial": 0.4, "grow_time": 0.2, "fade_in": 0.05, "spin": 4.0, "decay": 0.75})


## A ring standing in the XY plane (facing +Z) of [param radius].
static func ring_xy(st: SurfaceTool, radius: float, width: float, color: Color, sides := 48, z := 0.0) -> void:
	var pts := PackedVector3Array()
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		pts.append(Vector3(sin(a) * radius, cos(a) * radius, z))
	K.ribbon(st, pts, width, color, 0.0, 0.0, Vector3.BACK, 0.0)


# ---------------------------------------------------------------------------
# Strokes and marks (meshes cached by key, built once)
# ---------------------------------------------------------------------------
## A slash: an arc of light in the plane of [param u] / [param v] round [param center]
## with an ink line along its inner edge (a black cut over a hot edge, one draw).
static func crescent(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, radius: float, a0: float, a1: float, width: float, color: Color, edge: Color, ink: Color, delay := 0.0, steps := 18) -> void:
	var normal := u.cross(v).normalized()
	var pts := M.arc_in(center, u, v, radius, a0, a1, steps)
	K.ribbon(st, pts, width, color, delay, 0.0, normal, 1.0, 0.0, 1.0, edge)
	if ink.a > 0.0:
		var inner := M.arc_in(center, u, v, radius - width * 0.32, a0, a1, steps)
		K.ribbon(st, inner, width * 0.24, ink, delay, 0.0, normal, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)


## A storm of [param count] cuts round the origin at random tilts and heights, each lit at
## its own moment (over [param over] seconds): one FLAT mesh.
static func cut_storm(key: String, count: int, r0: float, r1: float, over: float, color: Color, edge: Color, ink: Color, seed_value := 21, y0 := 0.4, y1 := 2.0, width := 0.32) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var ang := rng.randf() * TAU
		var spot := Vector3(sin(ang), 0, cos(ang)) * lerpf(r0, r1, sqrt(rng.randf())) + Vector3.UP * rng.randf_range(y0, y1)
		var tilt := rng.randf_range(-1.2, 1.2)
		var turn := rng.randf() * TAU
		var u := Vector3(cos(turn), 0, -sin(turn))
		var v := Vector3(0, cos(tilt), 0) + Vector3(sin(turn), 0, cos(turn)) * sin(tilt)
		var rad := rng.randf_range(0.7, 1.3)
		var a0 := rng.randf_range(-2.6, -1.4)
		crescent(st, spot, u, v.normalized(), rad, a0, a0 + rng.randf_range(1.6, 2.4), width * rng.randf_range(0.7, 1.2), color, edge, ink, over * float(i) / float(maxi(1, count - 1)) + rng.randf_range(-0.02, 0.02), 12)
	return M.keep(key, K.finish(st, Vector3.ONE * 1.5, false))


## A ground sigil of radius 1: [param rings] concentric rings, ticks and [param spokes]
## radial strokes, all in one colour (alpha shapes it).
static func sigil(key: String, color: Color, rings := 2, ticks := 24, spokes := 0, fill := 0.0) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if fill > 0.0:
		K.disc(st, 1.0, M.a(color.darkened(0.55), fill), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(color.darkened(0.55), 0.0), 0.0, true)
	K.ring(st, 0.97, 0.05, M.a(color, 1.0), 0.004, 72)
	for k in rings - 1:
		var rr := 0.86 - 0.22 * float(k)
		K.ring(st, rr, 0.025, M.a(color, 0.8), 0.004, 64)
	for i in ticks:
		var a := TAU * float(i) / float(ticks)
		var dir := Vector3(sin(a), 0.005, cos(a))
		var long := 0.09 if i % 3 == 0 else 0.045
		K.ribbon(st, PackedVector3Array([dir * (0.92 - long), dir * 0.92]), 0.02, M.a(color, 0.9), 0.0, 0.0, Vector3.UP, 0.0)
	for i in spokes:
		var a := TAU * float(i) / float(spokes) + PI / float(spokes)
		var dir := Vector3(sin(a), 0.005, cos(a))
		K.ribbon(st, PackedVector3Array([dir * 0.18, dir * 0.5, dir * 0.84]), 0.035, M.a(color, 0.9), 0.0, 0.0, Vector3.UP, 0.8)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## A ring of [param count] chevrons on the ground (radius 1) pointing at the centre.
static func chevrons(key: String, count: int, color: Color, size := 0.14) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := TAU * float(i) / float(count)
		var dir := Vector3(sin(a), 0, cos(a))
		var side := Vector3(dir.z, 0, -dir.x)
		var tip := dir * (1.0 - size)
		K.ribbon(st, PackedVector3Array([tip + dir * size + side * size, tip, tip + dir * size - side * size]), size * 0.55, M.a(color, 1.0), 0.0, 0.0, Vector3.UP, 0.2)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## A unit stroke along +Z (0..1), level, for trails scaled to a hop's length.
static func streak(key: String, color: Color, edge: Color, ink := Color(0, 0, 0, 0)) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 9:
		pts.append(Vector3(0, 0, float(i) / 8.0))
	K.ribbon(st, pts, 1.0, color, 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, edge)
	if ink.a > 0.0:
		K.ribbon(st, pts, 0.28, ink, 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	# The crossed plane, so the trail reads from the side too.
	K.ribbon(st, pts, 0.6, M.a(color, color.a * 0.6), 0.0, 0.0, Vector3.RIGHT, 1.0, 0.0, 1.0, M.a(edge, edge.a * 0.6))
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## A crescent moon (or a full disc when [param bite] is 0) facing +Z, radius 1.
static func moon(key: String, body: Color, glow: Color, bite := 0.62) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.5, M.a(glow, 0.45), 0.0, 40, 0.0, Vector3.BACK, Vector3.ZERO, M.a(glow, 0.0), 0.0, true)
	if bite <= 0.0:
		K.disc(st, 1.0, M.a(body, 1.0), 0.01, 40, 0.0, Vector3.BACK, Vector3.ZERO, M.a(body.lightened(0.2), 1.0), 0.0, true)
	else:
		# A crescent: the lit rim from -100 to 100 degrees, thick in the middle.
		var outer := PackedVector3Array()
		for i in 25:
			var a := lerpf(-PI * 0.86, PI * 0.86, float(i) / 24.0)
			outer.append(Vector3(sin(a), cos(a), 0.01) * 0.86)
		K.ribbon(st, outer, bite * 0.5, M.a(body, 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## An eclipse facing +Z, radius 1: a black sun, a corona of [param rays] tinted flames.
static func eclipse(key: String, corona: Color, rim: Color, rays := 14) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = rays * 7 + 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.9, M.a(corona, 0.5), 0.0, 48, 0.0, Vector3.BACK, Vector3.ZERO, M.a(corona, 0.0), 0.0, true)
	for i in rays:
		var a := TAU * float(i) / float(rays) + rng.randf_range(-0.1, 0.1)
		var dir := Vector3(sin(a), cos(a), 0)
		var long := rng.randf_range(1.35, 1.9)
		K.ribbon(st, PackedVector3Array([dir * 0.9, dir * lerpf(0.9, long, 0.5) + Vector3(dir.y, -dir.x, 0) * 0.08, dir * long]), 0.22, M.a(corona, 0.95), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, M.a(rim, 0.0))
	ring_xy(st, 1.0, 0.14, M.a(rim, 1.0), 56, 0.01)
	K.disc(st, 0.94, Color(0.03, 0.0, 0.04, 1.0), 0.02, 40, 0.0, Vector3.BACK, Vector3.ZERO, Color(0.08, 0.0, 0.06, 1.0), 0.0, true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.4, false))


## A ring of light standing up as a wall of [param height] round radius 1 (crossed
## vertical strokes): a dome's ribs, a rampart of light, a sanctuary's arches.
static func curtain(key: String, color: Color, edge: Color, height := 1.0, sides := 40, arc := TAU) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2.ZERO)
	for i in sides:
		var a0 := arc * float(i) / float(sides)
		var a1 := arc * float(i + 1) / float(sides)
		var p0 := Vector3(sin(a0), 0, cos(a0))
		var p1 := Vector3(sin(a1), 0, cos(a1))
		var v0 := float(i) / float(sides)
		var v1 := float(i + 1) / float(sides)
		# UV.x runs up the wall (0 bottom .. 1 top: the hot core sits low with soft); UV.y round.
		for item in [[p0, 0.5, v0, color], [p1, 0.5, v1, color], [p1 + Vector3.UP * height, 0.0, v1, M.a(edge, 0.0)], [p0, 0.5, v0, color], [p1 + Vector3.UP * height, 0.0, v1, M.a(edge, 0.0)], [p0 + Vector3.UP * height, 0.0, v0, M.a(edge, 0.0)]]:
			st.set_color(item[3])
			st.set_uv(Vector2(item[1], item[2]))
			st.add_vertex(item[0])
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## Spokes of light from the centre out to radius 1 at ground level (sun rays, a seal's arms).
static func rays(key: String, count: int, color: Color, width := 0.08, r0 := 0.15, seed_value := 31) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a := TAU * float(i) / float(count) + rng.randf_range(-0.08, 0.08)
		var dir := Vector3(sin(a), 0, cos(a))
		K.ribbon(st, PackedVector3Array([dir * r0, dir * lerpf(r0, 1.0, 0.5), dir * rng.randf_range(0.75, 1.0)]), width, M.a(color, 1.0), 0.0, 0.0, Vector3.UP, 0.9)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## Rings in tilted planes round the origin (radius 1): an astrolabe, orbiting runes.
static func orbits(key: String, count: int, color: Color, width := 0.035, tilt := 0.9) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in count:
		var turn := PI * float(k) / float(count)
		var u := Vector3(cos(turn), 0, -sin(turn))
		var w := Vector3(sin(turn), 0, cos(turn))
		var v := (Vector3.UP * cos(tilt) + w * sin(tilt)).normalized()
		var pts := M.arc_in(Vector3.ZERO, u, v, 1.0, 0.0, TAU, 56)
		K.ribbon(st, pts, width, M.a(color, 1.0), 0.0, 0.0, u.cross(v), 0.0)
		# Runes: short bars across the ring.
		for i in 6:
			var a := TAU * float(i) / 6.0 + 0.3 * float(k)
			var p := (u * cos(a) + v * sin(a))
			K.ribbon(st, PackedVector3Array([p * 0.93, p * 1.07]), width * 2.2, M.a(color, 1.0), 0.0, 0.0, u.cross(v), 0.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


# ---------------------------------------------------------------------------
# Hits, hops and flights shared by the signatures
# ---------------------------------------------------------------------------
## A hit flash on one victim (SkillTableau.contact): a tinted star burst and a few sparks,
## at most HITS per cast per frame.
static func hit(parent: Node3D, skill: Dictionary, at: Vector3, colors: Array, crit := false, slash := false) -> void:
	var id := String(skill.get("id", ""))
	var frame := Engine.get_process_frames()
	var seen: Array = _hits.get(id, [-1, 0])
	if int(seen[0]) != frame:
		seen = [frame, 0]
	if int(seen[1]) >= int(HITS[0 if hero() else 1]):
		return
	seen[1] = int(seen[1]) + 1
	_hits[id] = seen
	if _hits.size() > 128:
		_hits.clear()
	var r := open(parent, at, 0.7, "Skill_%s_hit" % id, randf() * TAU, null, 3)
	if r == null:
		return
	var c0: Color = colors[0]
	var c1: Color = colors[1 % colors.size()]
	if slash:
		flat(r, _hit_cross(), "HitCross", Vector3.ZERO, Vector3.ONE * (1.3 if crit else 1.0), 0.32, lit(c0, 0.7), {"fade_in": 0.01, "decay": 0.4, "face_camera": true}, Vector3(0, 0, randf_range(-0.6, 0.6)))
	else:
		flat(r, _hit_star(), "HitStar", Vector3.ZERO, Vector3.ONE * (1.2 if crit else 0.9), 0.3, lit(c0, 0.7), {"initial": 0.4, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.35, "face_camera": true})
	M.sparks(r, "guard_hit_sparks", [c0, c1], 8, 0.05, 0.25, 3.0, 2.0, 0.09, 0.0, 0.45, Vector3.ZERO, 6.0, 41, -0.2, 0.2)
	done(r)


## A four-point star facing +Z (radius 1).
static func _hit_star() -> ArrayMesh:
	if M.has("guard_hit_star"):
		return M.get_mesh("guard_hit_star")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var a := PI * 0.5 * float(k)
		var dir := Vector3(sin(a), cos(a), 0)
		K.ribbon(st, PackedVector3Array([Vector3.ZERO, dir * (1.0 if k % 2 == 0 else 0.7)]), 0.3, Color(1, 1, 1, 1), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(1, 1, 1, 0.2))
	K.disc(st, 0.4, Color(1, 1, 1, 0.8), 0.0, 20, 0.0, Vector3.BACK, Vector3.ZERO, Color(1, 1, 1, 0.0), 0.0, true)
	return M.keep("guard_hit_star", K.finish(st, Vector3.ONE * 0.2, false))


## Two crossed cuts facing +Z (radius 1).
static func _hit_cross() -> ArrayMesh:
	if M.has("guard_hit_cross"):
		return M.get_mesh("guard_hit_cross")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var d := Vector3(s * 0.75, 0.66, 0)
		K.ribbon(st, PackedVector3Array([-d, Vector3.ZERO, d]), 0.2, Color(1, 1, 1, 1), 0.0, 0.0, Vector3.BACK, 1.0)
	return M.keep("guard_hit_cross", K.finish(st, Vector3.ONE * 0.2, false))


## The hop index of a chain link in this frame (links of one cast arrive in one frame).
static func hop(skill: Dictionary) -> int:
	var id := String(skill.get("id", ""))
	var frame := Engine.get_process_frames()
	var seen: Array = _hops.get(id, [-1, -1])
	var index := int(seen[1]) + 1 if int(seen[0]) == frame else 0
	_hops[id] = [frame, index]
	return index


## A root at [param to] whose SOLID carrier [param mesh] flies in from [param from] over
## [param flight] seconds after [param delay], a trail along the way, a flash where it lands.
## Returns the root (null: no room).
static func carry(parent: Node3D, skill: Dictionary, mesh: Mesh, from: Vector3, to: Vector3, delay: float, flight: float, size: float, colors: Array, label: String, solid_params := {}, spin := 0.0, angles := Vector3.ZERO, linger := 0.3, trail_width := 0.35) -> Root:
	var id := String(skill.get("id", ""))
	var r := open(parent, to, delay + flight + linger + 0.1, "Skill_%s_%s" % [id, label], 0.0, null, 4)
	if r == null:
		return null
	var c0: Color = colors[0]
	var c1: Color = colors[1 % colors.size()]
	# The carrier rides the layer's own travel (root space), so it may spin and turn freely.
	var params := {"rim_color": c1, "rim": 1.0, "glow_color": c0}
	params.merge(solid_params, true)
	solid(r, mesh, "Carrier", from - to, Vector3.ONE * size, flight, params, {"delay": delay, "travel": to - from, "fade_in": 0.01, "decay": 0.97, "spin": spin}, angles)
	# The trail: a unit stroke laid from the start to the landing.
	var d := from - to
	var length := d.length()
	if length > 0.2:
		var trail := streak("guard_trail_%s" % c0.to_html(), M.a(c0, 0.9), M.a(c1, 0.0))
		var turn := atan2(d.x, d.z)
		var pitch := -atan2(d.y, Vector2(d.x, d.z).length())
		flat(r, trail, "Trail", Vector3.ZERO, Vector3(trail_width * size, trail_width * size, length), flight + 0.22, lit(c0, 0.7, 0.8, {"sweep": flight, "tail": 1.4}), {"delay": delay, "fade_in": 0.01, "decay": 0.6}, Vector3(pitch, turn, 0))
	return r


# ---------------------------------------------------------------------------
# Solid parts and set pieces of the Defender and the Assassin
# ---------------------------------------------------------------------------
## A tower shield standing on its foot at the origin, face to +Z, 1 tall: a tall field with
## a rounded top, a rim, a cross of studs and a boss.
static func tower(field: Color, rim: Color, boss: Color) -> K.Part:
	var p := K.Part.new()
	var outline := PackedVector2Array()
	for i in 9:
		var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / 8.0)
		outline.append(Vector2(sin(a) * 0.36, 0.86 + cos(a) * 0.12))
	outline.append(Vector2(0.36, 0.06))
	outline.append(Vector2(0.24, 0.0))
	outline.append(Vector2(-0.24, 0.0))
	outline.append(Vector2(-0.36, 0.06))
	var inner := PackedVector2Array()
	for q in outline:
		var c := Vector2(0, 0.5)
		inner.append(c + (q - c) * 0.86)
	p.ink(rim, 0.8)
	p.slab(outline, -0.05, 0.05)
	p.ink(field, 0.45)
	p.slab(inner, -0.075, 0.075)
	p.ink(rim, 0.8)
	p.box(Vector3(0, 0.5, 0.08), Vector3(0.06, 0.78, 0.02))
	p.box(Vector3(0, 0.62, 0.08), Vector3(0.56, 0.06, 0.02))
	p.ink(boss, 0.9, 0.4)
	p.gem(Vector3(0, 0.62, 0.1), Vector3(0.1, 0.11, 0.07))
	for y in [0.2, 0.86]:
		p.ball(Vector3(0, y, 0.085), Vector3(0.035, 0.035, 0.03), 5, 3)
	return p


## A round aegis facing +Z, radius 1 round the origin: rim, three bands, a sun boss.
static func aegis(field: Color, rim: Color, boss: Color, rays_color: Color) -> K.Part:
	var p := K.Part.new()
	var outer := PackedVector2Array()
	var mid := PackedVector2Array()
	var core := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		outer.append(Vector2(sin(a), cos(a)))
		mid.append(Vector2(sin(a), cos(a)) * 0.8)
		core.append(Vector2(sin(a), cos(a)) * 0.34)
	p.ink(rim, 0.8)
	p.slab(outer, -0.06, 0.06)
	p.ink(field, 0.5)
	p.slab(mid, -0.09, 0.09)
	p.ink(rays_color, 0.6, 0.5)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var d := Vector3(sin(a), cos(a), 0)
		p.tube(d * 0.36 + Vector3(0, 0, 0.1), d * 0.74 + Vector3(0, 0, 0.1), 0.05, 0.0, 3, 0.4)
	p.ink(boss, 0.9, 0.45)
	p.slab(core, -0.13, 0.13)
	p.gem(Vector3(0, 0, 0.16), Vector3(0.16, 0.16, 0.08))
	return p


## A hex lattice dome of light round the origin (radius 1): small hexagon outlines on a
## half sphere, each lit at its own moment (UV2 delay by height: it builds from the ground).
static func hex_dome(key: String, color: Color, rings := 4, build := 0.25) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings:
		var lat := lerpf(0.12, 1.3, float(k) / float(rings))
		var count := maxi(1, int(round(float(rings * 3) * cos(lat))))
		for i in count:
			var lon := TAU * (float(i) + 0.5 * float(k % 2)) / float(count)
			var n := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
			var u := Vector3.UP.cross(n).normalized() if absf(n.y) < 0.99 else Vector3.RIGHT
			var v := n.cross(u)
			var size := 0.17 * (1.0 - 0.25 * float(k) / float(rings))
			var pts := PackedVector3Array()
			for j in 7:
				var a := TAU * float(j) / 6.0
				pts.append(n + (u * cos(a) + v * sin(a)) * size)
			K.ribbon(st, pts, 0.03, M.a(color, 1.0), build * float(k) / float(rings), 0.0, n, 0.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## A crenellated rampart ring of light (radius 1, [param height] tall): a curtain with
## merlons on top, each a little upright stroke.
static func battlement(key: String, color: Color, edge: Color, height := 0.25, merlons := 24) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_uv2(Vector2.ZERO)
	var sides := merlons * 2
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := Vector3(sin(a0), 0, cos(a0))
		var p1 := Vector3(sin(a1), 0, cos(a1))
		var h := height * (1.0 if i % 2 == 0 else 0.72)
		var v0 := float(i) / float(sides)
		var v1 := float(i + 1) / float(sides)
		for item in [[p0, 0.5, v0, color], [p1, 0.5, v1, color], [p1 + Vector3.UP * h, 0.12, v1, edge], [p0, 0.5, v0, color], [p1 + Vector3.UP * h, 0.12, v1, edge], [p0 + Vector3.UP * h, 0.12, v0, edge]]:
			st.set_color(item[3])
			st.set_uv(Vector2(item[1], item[2]))
			st.add_vertex(item[0])
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## A bold "!" facing +Z, 1 tall, its foot at the origin (the challenge over a taunted foe).
static func bang(key: String, color: Color) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ribbon(st, PackedVector3Array([Vector3(0, 1.0, 0), Vector3(0, 0.62, 0), Vector3(0, 0.34, 0)]), 0.2, M.a(color, 1.0), 0.0, 0.0, Vector3.BACK, 0.55)
	K.disc(st, 0.1, M.a(color, 1.0), 0.0, 14, 0.0, Vector3.BACK, Vector3(0, 0.12, 0), M.a(color, 1.0), 0.0, true)
	K.disc(st, 0.42, M.a(color, 0.35), -0.01, 20, 0.0, Vector3.BACK, Vector3(0, 0.55, 0), M.a(color, 0.0), 0.0, true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## Ground spots of the living foes within [param radius] of [param center] (read only),
## nearest first, at most [param most].
static func foes(node: Node, center: Vector3, radius: float, most: int) -> Array:
	var out := []
	if not is_instance_valid(node) or not node.is_inside_tree():
		return out
	for item in node.get_tree().get_nodes_in_group("mobs"):
		var mob := item as Mob
		if mob and not mob.is_dead() and Vector2(mob.global_position.x - center.x, mob.global_position.z - center.z).length() <= radius + mob.body_radius():
			out.append(mob.global_position * Vector3(1, 0, 1))
	out.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	return out.slice(0, most)


## The ring of [param count] shadow figures round the origin at [param radius], facing in
## (or out), each rising on its own moment.
static func legion(key: String, count: int, radius: float, cloth: Color, trim: Color, eyes: Color, inward := true, stagger := 0.03) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := K.begin()
	var part := M.figure(cloth, trim, eyes)
	for i in count:
		var ang := TAU * float(i) / float(count)
		var at := Vector3(sin(ang), 0, cos(ang)) * radius
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, ang + (PI if inward else 0.0)), at), stagger * float(i), 1.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 2.0))


## Daggers in a ring (radius 1) pointing outward, level: scaled up, they fly out.
static func dagger_ring(key: String, count: int, blade: Color, grip: Color, edge: Color, length := 0.35) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := K.begin()
	var part := M.dagger(blade, grip, edge)
	for i in count:
		var ang := TAU * float(i) / float(count)
		var dir := Vector3(sin(ang), 0, cos(ang))
		# The dagger's +Y (its point) laid along dir.
		var basis := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI * 0.5)
		K.stamp(st, part, Transform3D(basis.scaled(Vector3.ONE * length), dir * (1.0 - length * 0.5)), 0.0, 1.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5))


## A dagger laid along +Z (point forward), centred: a thrown blade.
static func thrown(key: String, blade: Color, grip: Color, edge: Color) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := K.begin()
	K.stamp(st, M.dagger(blade, grip, edge), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.5)), 0.0, 1.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5))


## [param count] short blade glints round a level ring of radius 1 (thin arcs).
static func glints(key: String, color: Color, count := 6) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var a0 := TAU * float(i) / float(count)
		K.ribbon(st, M.arc(Vector3.ZERO, 1.0, a0, a0 + 0.55, 0.0, 0.0, 8), 0.07, M.a(color, 1.0), 0.0, 0.0, Vector3.UP, 1.0)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.2, false))


## A spray of petals thrown out of a cut (a burst round the origin, quick and low).
static func spray(key: String, count: int, colors: Array, piece: float, seed_value := 51, out := 3.6, up := 2.6) -> ArrayMesh:
	return K.burst(key, "feather", count, 0.05, 0.35, out, up, colors, piece, 0.06, seed_value, -0.1, 0.1)
