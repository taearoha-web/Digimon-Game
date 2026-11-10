class_name GodRangedKit
extends Node3D
## Shared stage for the ranged god skills (archer, mage, priest; combat/god_art/<id>.gd).
## Cosmetic ONLY: StarSkillSequence owns every contact. A root is finite and has one clock;
## every piece is one draw call (a mesh or a MultiMesh swarm animated in its shader) and
## one VfxBudget decoration, and everything frees with the root. The hero objects are real
## procedural meshes (a sun, a dragon-headed arrow, a six-winged seraph, meteors, crystals)
## built once and cached.
const SOLID := preload("res://shaders/god_solid.gdshader")
const SUN := preload("res://shaders/god_sun.gdshader")
const GLOW := preload("res://shaders/god_glow.gdshader")
const VEIL := preload("res://shaders/god_veil.gdshader")
const FLAT := Vector3(-PI / 2, 0, 0)
const GOLDEN := 2.39996

var age := 0.0
var lifetime := 1.0
var pieces: Array[Dictionary] = []
var generation_ref: WeakRef
var generation := -1
var generation_until := 0.0
## The cast itself: when it ends early (the hero died, the zone changed) the art leaves too.
var watch_ref: WeakRef
var watch_until := 0.0
var _closing := -1.0
static var _meshes := {}


# ---------------------------------------------------------------------------
# Roots and pieces
# ---------------------------------------------------------------------------
static func open(parent: Node3D, point: Vector3, seconds: float, label: String, source: Vector3) -> GodRangedKit:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var kit := GodRangedKit.new()
	kit.name = label
	kit.lifetime = maxf(0.1, seconds)
	parent.add_child(kit)
	kit.global_position = point
	var direction := point - source
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		kit.rotation.y = atan2(direction.x, direction.z)
	return kit


## Ties the root to the caster's cast: a skill cancelled during its wind-up ends it at
## once, and so does a cast that stops early (the hero died or left).
func bind(caster: Node3D, id: String, until: float, windup := 0.0) -> void:
	generation_until = windup
	var visual := StarSkillArt._visual(caster)
	if visual:
		generation_ref = weakref(visual)
		generation = visual.skill_generation
	var cast := caster.get_node_or_null("StarCast_" + id) if is_instance_valid(caster) else null
	if cast:
		watch_ref = weakref(cast)
		watch_until = until


## The horizontal direction (in this root's space) from its origin to the camera: big
## pieces turn their good side to the player. Falls back to the caster's side.
func toward_camera() -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var d := global_basis.inverse() * (camera.global_position - global_position)
		d.y = 0.0
		if d.length_squared() > 0.01:
			return d.normalized()
	return Vector3(0, 0, -1)


static func quality() -> int:
	return VfxBudget.quality()


## Where a hero object hangs so that the field camera (high up, looking down) shows it
## whole and it does not cover the enemies: [param left] metres to the camera's left of
## the root, [param near] metres towards the camera, [param up] high.
func stage(left: float, near: float, up: float) -> Vector3:
	var cam := toward_camera()
	return cam.cross(Vector3.UP) * left + cam * near + Vector3.UP * up


## Phones under memory pressure and the low quality keep the hero object and little else.
static func lean() -> bool:
	return MemoryGuard.pressure > 0 or VfxBudget.quality() == 0


static func material(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	return mat


func _track(node: GeometryInstance3D, at: Vector3, size: Vector3, angles: Vector3, start: float, seconds: float, o: Dictionary) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 18.0
	node.visible = false
	add_child(node)
	VfxBudget.track_decoration(node)
	pieces.append({"node": node, "at": at, "size": size, "angles": angles, "start": start, "seconds": maxf(0.04, seconds), "o": o})
	lifetime = maxf(lifetime, start + seconds + 0.02)


## One mesh. Options: from / grow (pop in), to (scale reached at the end), travel + tw
## (window in seconds) + ease (0 linear, 1 accelerating, 2 slowing), spin, bob, yaw_cam,
## fin / fout (fade seconds), curves {uniform: [t, v, t, v...]}, scale_curve [t, v...],
## priority.
func add(geometry: Mesh, shader: Shader, params: Dictionary, at: Vector3, size: Vector3, angles: Vector3, start: float, seconds: float, o := {}) -> MeshInstance3D:
	if not geometry or not VfxBudget.can_decorate():
		return null
	var node := MeshInstance3D.new()
	node.mesh = geometry
	var mat := material(shader, params)
	if not params.has("life"):
		mat.set_shader_parameter("life", seconds)
	mat.render_priority = int(o.get("priority", 0))
	node.material_override = mat
	_track(node, at, size, angles, start, seconds, o)
	return node


## Many copies of one mesh in one draw: each instance has its own transform and
## Color(delay, seed, factor) read by the shaders.
func swarm(geometry: Mesh, shader: Shader, params: Dictionary, xforms: Array, customs: Array, start: float, seconds: float, o := {}) -> MultiMeshInstance3D:
	if not geometry or xforms.is_empty() or not VfxBudget.can_decorate():
		return null
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.use_colors = true
	multi.mesh = geometry
	multi.instance_count = xforms.size()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		multi.set_instance_color(i, Color.WHITE)
		multi.set_instance_custom_data(i, customs[i] if i < customs.size() else Color(0, 0, 0, 0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	var mat := material(shader, params)
	mat.render_priority = int(o.get("priority", 0))
	node.material_override = mat
	_track(node, o.get("at", Vector3.ZERO), Vector3.ONE, Vector3.ZERO, start, seconds, o)
	return node


## A piece of this kit's light inside a StarSkillArt root (the contact roots draw their
## beat there): the star root animates it, this only swaps its material.
static func layer(art: StarSkillArt, geometry: Mesh, shader: Shader, params: Dictionary, at: Vector3, size: Vector3, angles: Vector3, seconds: float, style := {}) -> void:
	if not art:
		return
	var before := art.layers.size()
	art.add_mesh(geometry, "GodLight", {"primary": Color.WHITE, "accent": Color.WHITE, "shade": Color.WHITE}, at, size, angles, seconds, style)
	if art.layers.size() == before:
		return
	var node: MeshInstance3D = art.layers[before].node
	var mat := material(shader, params)
	if not params.has("life"):
		mat.set_shader_parameter("life", seconds)
	mat.render_priority = int(style.get("priority", 0))
	node.material_override = mat
	node.extra_cull_margin = 18.0


func _process(delta: float) -> void:
	if generation_ref and age < generation_until:
		var visual := generation_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation != generation:
			queue_free()
			return
	age += delta
	if watch_ref and _closing < 0.0 and age < watch_until and not is_instance_valid(watch_ref.get_ref()):
		_closing = age
	_draw()
	if age >= lifetime or (_closing >= 0.0 and age > _closing + 0.25):
		queue_free()


static func _curve(points: Array, t: float) -> float:
	var n := points.size() / 2
	if n == 0:
		return 0.0
	if t <= float(points[0]):
		return float(points[1])
	for i in range(1, n):
		var t1 := float(points[i * 2])
		if t <= t1:
			var t0 := float(points[i * 2 - 2])
			return lerpf(float(points[i * 2 - 1]), float(points[i * 2 + 1]), smoothstep(t0, t1, t))
	return float(points[n * 2 - 1])


func _draw() -> void:
	var closing := 1.0 if _closing < 0.0 else clampf(1.0 - (age - _closing) / 0.25, 0.0, 1.0)
	for piece in pieces:
		var node: GeometryInstance3D = piece.node
		var lt := age - float(piece.start)
		var seconds := float(piece.seconds)
		node.visible = lt >= 0.0 and lt < seconds
		if not node.visible:
			continue
		var o: Dictionary = piece.o
		var t := lt / seconds
		var grow := float(o.get("grow", 0.0))
		var s := 1.0
		if grow > 0.0:
			var g := clampf(lt / grow, 0.0, 1.0)
			s = lerpf(float(o.get("from", 0.1)), 1.0, 1.0 - (1.0 - g) * (1.0 - g))
		if o.has("scale_curve"):
			s *= _curve(o.scale_curve, lt)
		var size: Vector3 = piece.size * maxf(0.001, s)
		if o.has("to"):
			size *= Vector3.ONE.lerp(o.to, 1.0 - (1.0 - t) * (1.0 - t))
		node.scale = size
		var pos: Vector3 = piece.at
		if o.has("travel"):
			var window: Vector2 = o.get("tw", Vector2(0, seconds))
			var p := clampf((lt - window.x) / maxf(0.001, window.y - window.x), 0.0, 1.0)
			match int(o.get("ease", 0)):
				1: p = p * p
				2: p = 1.0 - (1.0 - p) * (1.0 - p)
			pos += (o.travel as Vector3) * p
		if o.has("bob"):
			pos.y += sin(age * 1.7) * float(o.bob)
		node.position = pos
		node.rotation = (piece.angles as Vector3) + (o.get("spin", Vector3.ZERO) as Vector3) * lt
		if bool(o.get("yaw_cam", false)):
			var camera := get_viewport().get_camera_3d()
			if camera:
				var direction := global_basis.inverse() * (camera.global_position - node.global_position)
				node.rotation.y = atan2(direction.x, direction.z)
		var fade := smoothstep(0.0, float(o.get("fin", 0.08)), lt) * (1.0 - smoothstep(seconds - float(o.get("fout", 0.25)), seconds, lt)) * closing
		var mat := node.material_override as ShaderMaterial
		mat.set_shader_parameter("fade", fade)
		mat.set_shader_parameter("age", lt)
		if o.has("curves"):
			var curves: Dictionary = o.curves
			for key in curves:
				mat.set_shader_parameter(key, _curve(curves[key], lt))


# ---------------------------------------------------------------------------
# Placement helpers
# ---------------------------------------------------------------------------
## A transform whose +Y points back along [param direction]: a falling piece (motion 1)
## flies along -Y and lands at [param spot].
static func falling(spot: Vector3, direction: Vector3, size: float, roll := 0.0) -> Transform3D:
	var y := -direction.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var basis := Basis(x, y, z).rotated(y, roll)
	return Transform3D(basis.scaled(Vector3.ONE * size), spot)


## A card lying on the ground.
static func lying(spot: Vector3, size: float, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(-PI / 2, yaw, 0)).scaled(Vector3.ONE * size), spot)


static func standing(spot: Vector3, size: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(size), spot)


## A camera-facing card whose +Y (its burst direction) points along [param out].
static func card(spot: Vector3, size: float, out := Vector3.UP) -> Transform3D:
	return falling(spot, -out, size)


## Deterministic scatter inside a disc: the k-th of n spots round [param centre].
static func scatter(k: int, n: int, radius: float, salt := 0.0) -> Vector3:
	var a := float(k) * GOLDEN + salt * 1.7
	var d := radius * sqrt((float(k) + 0.6) / float(maxi(n, 1)))
	return Vector3(sin(a), 0, cos(a)) * d


static func rand(k: float) -> float:
	return fposmod(sin(k * 12.9898 + 4.1) * 43758.5453, 1.0)


# ---------------------------------------------------------------------------
# Mesh builder
# ---------------------------------------------------------------------------
class Build:
	var st := SurfaceTool.new()
	var color := Color.WHITE
	var emit := 0.0
	var alpha := 1.0
	var uv2 := Vector2.ZERO
	var xf := Transform3D.IDENTITY

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func v(p: Vector3, n: Vector3, c: Color, e: float, a: float) -> void:
		st.set_color(c)
		st.set_normal((xf.basis * n).normalized())
		st.set_uv(Vector2(e, a))
		st.set_uv2(uv2)
		st.add_vertex(xf * p)

	func tri(a: Vector3, b: Vector3, c: Vector3, ca := color, cb := color, cc := color) -> void:
		var n := (b - a).cross(c - a)
		n = n.normalized() if n.length_squared() > 0.0000001 else Vector3.UP
		v(a, n, ca, emit, alpha)
		v(b, n, cb, emit, alpha)
		v(c, n, cc, emit, alpha)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cab := color, ccd := color) -> void:
		tri(a, b, c, cab, cab, ccd)
		tri(a, c, d, cab, ccd, ccd)

	## A ring of a loft: [centre, half-axis u, half-axis w, colour, emit, alpha, axial normal].
	func _lv(ring: Array, angle: float) -> void:
		var u: Vector3 = ring[1]
		var w: Vector3 = ring[2]
		var p: Vector3 = ring[0] + u * cos(angle) + w * sin(angle)
		var n := u.normalized() * cos(angle) / maxf(u.length(), 0.001) + w.normalized() * sin(angle) / maxf(w.length(), 0.001)
		n = n.normalized()
		if ring.size() > 6:
			var axial: Vector3 = ring[6]
			n = (n * sqrt(maxf(0.0, 1.0 - axial.length_squared())) + axial).normalized()
		v(p, n, ring[3] if ring.size() > 3 else color, float(ring[4]) if ring.size() > 4 else emit, float(ring[5]) if ring.size() > 5 else alpha)

	func loft(rings: Array, sides := 8) -> void:
		for i in rings.size() - 1:
			for j in sides:
				var a0 := TAU * float(j) / float(sides)
				var a1 := TAU * float(j + 1) / float(sides)
				_lv(rings[i], a0)
				_lv(rings[i + 1], a0)
				_lv(rings[i + 1], a1)
				_lv(rings[i], a0)
				_lv(rings[i + 1], a1)
				_lv(rings[i], a1)

	## A round tube along a path; colours blend from ca to cb.
	func tube(path: Array, radii: Array, sides := 6, ca := color, cb := color) -> void:
		var rings := []
		for i in path.size():
			var prev: Vector3 = path[maxi(i - 1, 0)]
			var next: Vector3 = path[mini(i + 1, path.size() - 1)]
			var t := (next - prev).normalized()
			var ref := Vector3.UP if absf(t.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
			var u := t.cross(ref).normalized()
			var w := t.cross(u).normalized()
			var r := maxf(0.0005, float(radii[mini(i, radii.size() - 1)]))
			rings.append([path[i], u * r, w * r, ca.lerp(cb, float(i) / float(maxi(1, path.size() - 1))), emit, alpha])
		loft(rings, sides)

	func ball(centre: Vector3, radius: Vector3, top := color, bottom := color, sides := 10, bands := 6) -> void:
		var rings := []
		for i in bands + 1:
			var phi := PI * float(i) / float(bands)
			var rr := maxf(0.002, sin(phi))
			rings.append([centre + Vector3(0, cos(phi) * radius.y, 0), Vector3(rr * radius.x, 0, 0), Vector3(0, 0, rr * radius.z), top.lerp(bottom, float(i) / float(bands)), emit, alpha, Vector3(0, cos(phi), 0)])
		loft(rings, sides)

	func cone(base: Vector3, tip: Vector3, radius: float, sides := 5, cb := color, ct := color) -> void:
		tube([base, tip], [radius, 0.0], sides, cb, ct)

	static func bezier(a: Vector3, b: Vector3, c: Vector3, n: int) -> Array:
		var out := []
		for i in n + 1:
			var t := float(i) / float(n)
			out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
		return out

	## A feather: a ridged leaf from its quill to its tip, lying in the plane facing [param face].
	func feather(base: Vector3, along: Vector3, width: float, face: Vector3, cb: Color, ct: Color) -> void:
		var side := along.cross(face).normalized() * width * 0.5
		var mid := base + along * 0.42
		var ridge := mid + face.normalized() * width * 0.22
		var tip := base + along
		var cm := cb.lerp(ct, 0.45)
		tri(base, mid - side, ridge, cb, cm, cm)
		tri(base, ridge, mid + side, cb, cm, cm)
		tri(mid - side, tip, ridge, cm, ct, cm)
		tri(ridge, tip, mid + side, cm, ct, cm)

	func commit() -> ArrayMesh:
		return st.commit()


# ---------------------------------------------------------------------------
# Cached meshes
# ---------------------------------------------------------------------------
static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	return _meshes[kind]


static func _build(kind: String) -> Mesh:
	match kind:
		"quad": return _quad()
		"column": return _column(1.0)
		"shaft": return _column(0.3)
		"sphere":
			var ball := SphereMesh.new()
			ball.radius = 1.0
			ball.height = 2.0
			ball.radial_segments = 28
			ball.rings = 14
			return ball
		"arrow": return _arrow()
		"dragon_arrow": return _dragon_arrow()
		"seraph": return _seraph()
		"feather": return _feather()
		"meteor": return _meteor()
		"ice": return _ice()
		"crystal": return _crystal()
		"shard": return _shard()
		"bolt": return _bolt()
		"orbit0": return _orbit(0)
		"orbit1": return _orbit(1)
		"orbit2": return _orbit(2)
	return null


static func _quad() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for c in corners:
		st.set_normal(Vector3.BACK)
		st.set_uv(Vector2(c.x * 0.5 + 0.5, 0.5 - c.y * 0.5))
		st.add_vertex(Vector3(c.x, c.y, 0))
	return st.commit()


## An open column standing on its origin: radius 1 at the foot, [param top] at the top,
## height 1. UV.x runs round it, UV.y is 1 at the foot.
static func _column(top: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 20
	for j in sides:
		for corner in [[0, 0], [0, 1], [1, 1], [0, 0], [1, 1], [1, 0]]:
			var a := TAU * float(j + corner[0]) / float(sides)
			var y := float(corner[1])
			var r := lerpf(1.0, top, y)
			st.set_normal(Vector3(cos(a), 0, sin(a)))
			st.set_uv(Vector2(float(j + corner[0]) / float(sides), 1.0 - y))
			st.add_vertex(Vector3(cos(a) * r, y, sin(a) * r))
	return st.commit()


## A sun arrow: point at the origin, shaft back along +Y, emerald fletching, a tail of fire.
static func _arrow() -> Mesh:
	var b := Build.new()
	b.emit = 0.85
	b.cone(Vector3(0, 0.46, 0), Vector3.ZERO, 0.13, 4, Color("ffd24a"), Color("fffbe0"))
	b.emit = 0.4
	b.tube([Vector3(0, 0.4, 0), Vector3(0, 1.75, 0)], [0.042, 0.042], 5, Color("ffe9a0"), Color("eaa83a"))
	b.emit = 0.6
	for k in 3:
		var a := TAU * float(k) / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		b.quad(Vector3(0, 1.22, 0), out * 0.2 + Vector3(0, 1.42, 0), out * 0.23 + Vector3(0, 1.86, 0), Vector3(0, 1.74, 0), Color("2cf088"), Color("0f9a5a"))
	# The streak: a hot tail that thins out behind the arrow.
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	b.loft([
		[Vector3(0, 0.1, 0), x * 0.06, z * 0.06, Color("fffbe0"), 1.0, 0.95],
		[Vector3(0, 0.5, 0), x * 0.18, z * 0.18, Color("ffe27a"), 1.0, 0.85],
		[Vector3(0, 2.4, 0), x * 0.13, z * 0.13, Color("ffa22a"), 1.0, 0.55],
		[Vector3(0, 6.5, 0), x * 0.01, z * 0.01, Color("ff6a10"), 1.0, 0.0]], 5)
	return b.commit()


## The archer's finale: a colossal golden arrow whose head is a dragon's (jaws open,
## horns, whiskers, an emerald mane) diving point first; the point is at the origin and
## the shaft runs back along +Y, the dragon's back towards +Z.
static func _dragon_arrow() -> Mesh:
	var b := Build.new()
	var gold := Color("ffc02a")
	var pale := Color("fff0a6")
	var deep := Color("d98612")
	var jade := Color("1fd67a")
	var forest := Color("0e8f58")
	var ivory := Color("fff8e2")
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	b.emit = 0.18
	# Skull: snout, nose, brow, cheeks, neck.
	b.loft([
		[Vector3(0, 0.0, 0.02), x * 0.05, z * 0.04, pale],
		[Vector3(0, 0.16, 0.06), x * 0.25, z * 0.15, pale],
		[Vector3(0, 0.5, 0.08), x * 0.24, z * 0.15, gold],
		[Vector3(0, 0.95, 0.14), x * 0.38, z * 0.22, gold],
		[Vector3(0, 1.35, 0.22), x * 0.54, z * 0.33, gold],
		[Vector3(0, 1.8, 0.16), x * 0.48, z * 0.34, deep],
		[Vector3(0, 2.25, 0.02), x * 0.26, z * 0.26, gold],
		[Vector3(0, 2.75, 0.0), x * 0.14, z * 0.14, deep]], 10)
	# Lower jaw, open.
	b.loft([
		[Vector3(0, 0.22, -0.52), x * 0.04, z * 0.03, pale],
		[Vector3(0, 0.4, -0.5), x * 0.19, z * 0.07, pale],
		[Vector3(0, 0.95, -0.36), x * 0.3, z * 0.1, gold],
		[Vector3(0, 1.55, -0.16), x * 0.36, z * 0.14, deep],
		[Vector3(0, 1.9, -0.05), x * 0.3, z * 0.12, deep]], 8)
	# Fire in the throat.
	b.emit = 1.0
	b.ball(Vector3(0, 1.05, -0.14), Vector3(0.24, 0.42, 0.14), Color("fffbe0"), Color("ff8a1a"), 8, 4)
	# Teeth along both jaws.
	b.emit = 0.6
	for side in [-1.0, 1.0]:
		for k in 5:
			var s := 0.22 + 0.2 * float(k)
			var w := 0.17 + 0.045 * float(k)
			b.cone(Vector3(side * w, s, -0.04 + 0.02 * k), Vector3(side * w, s + 0.03, -0.24 + 0.01 * k), 0.045, 4, ivory, ivory)
			b.cone(Vector3(side * (w - 0.02), s + 0.2, -0.44 + 0.035 * k), Vector3(side * (w - 0.02), s + 0.22, -0.27 + 0.035 * k), 0.04, 4, ivory, ivory)
	# Eyes.
	b.emit = 1.0
	for side in [-1.0, 1.0]:
		b.ball(Vector3(side * 0.43, 1.22, 0.3), Vector3(0.1, 0.14, 0.09), Color("eafff0"), jade, 6, 4)
	# Horns: a great pair sweeping back, a small pair under them.
	b.emit = 0.4
	for side in [-1.0, 1.0]:
		b.tube(Build.bezier(Vector3(side * 0.3, 1.5, 0.42), Vector3(side * 0.62, 2.3, 1.25), Vector3(side * 0.95, 3.6, 1.05), 7), [0.14, 0.13, 0.11, 0.09, 0.07, 0.05, 0.03, 0.005], 6, ivory, Color("ffd76a"))
		b.tube(Build.bezier(Vector3(side * 0.44, 1.75, 0.2), Vector3(side * 0.95, 2.2, 0.5), Vector3(side * 1.15, 3.0, 0.3), 5), [0.09, 0.08, 0.06, 0.045, 0.03, 0.004], 5, ivory, Color("ffd76a"))
	# Whiskers streaming back from the nose.
	b.emit = 0.9
	for side in [-1.0, 1.0]:
		b.tube(Build.bezier(Vector3(side * 0.22, 0.22, 0.05), Vector3(side * 1.5, 1.2, -0.5), Vector3(side * 1.0, 3.9, 0.15), 9), [0.05, 0.05, 0.045, 0.04, 0.035, 0.03, 0.022, 0.015, 0.008, 0.002], 4, Color("b8ffcf"), jade)
	# Cheek fins and the mane down the shaft.
	b.emit = 0.45
	for side in [-1.0, 1.0]:
		for k in 3:
			var root := Vector3(side * 0.46, 1.65 + 0.12 * k, 0.12 - 0.12 * k)
			b.tri(root, root + Vector3(0, 0.3, -0.1), root + Vector3(side * (0.75 - 0.12 * k), 1.0 + 0.3 * k, 0.25 - 0.3 * k), forest, forest, jade)
	for k in 9:
		var s := 1.55 + 0.42 * float(k)
		var tall := 0.62 - 0.045 * float(k)
		var back := 0.3 if k < 2 else 0.13
		b.tri(Vector3(0, s, back), Vector3(0, s + 0.4, back - 0.03), Vector3(0, s + 0.62, back + tall), forest, forest, Color("7dffb0"))
	# Shaft with banded rings.
	b.emit = 0.2
	b.tube([Vector3(0, 2.7, 0), Vector3(0, 8.6, 0)], [0.17, 0.15], 8, gold, deep)
	for k in 4:
		var s := 3.6 + 1.25 * float(k)
		b.tube([Vector3(0, s, 0), Vector3(0, s + 0.18, 0)], [0.24, 0.24], 8, pale, pale)
	# Fletching: four great emerald vanes edged in gold.
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI / 4.0
		var out := Vector3(cos(a), 0, sin(a))
		b.emit = 0.5
		b.quad(Vector3(0, 6.6, 0), out * 0.95 + Vector3(0, 7.4, 0), out * 1.05 + Vector3(0, 8.85, 0), Vector3(0, 8.5, 0), jade, forest)
		b.emit = 0.9
		b.quad(out * 0.95 + Vector3(0, 7.4, 0), out * 1.1 + Vector3(0, 7.45, 0), out * 1.2 + Vector3(0, 9.0, 0), out * 1.05 + Vector3(0, 8.85, 0), pale, gold)
	b.emit = 0.8
	b.ball(Vector3(0, 8.7, 0), Vector3.ONE * 0.2, pale, gold, 6, 4)
	# A tail of fire behind the nock.
	b.loft([
		[Vector3(0, 8.4, 0), x * 0.2, z * 0.2, Color("fffbe0"), 1.0, 0.9],
		[Vector3(0, 9.4, 0), x * 0.55, z * 0.55, Color("ffd24a"), 1.0, 0.7],
		[Vector3(0, 11.5, 0), x * 0.36, z * 0.36, Color("ff8a1a"), 1.0, 0.4],
		[Vector3(0, 15.0, 0), x * 0.02, z * 0.02, Color("ff5a0a"), 1.0, 0.0]], 8)
	return b.commit()


static func _wing(b: Build, side: float, pair: int, root: Vector3, lift: float, length: float, tip: Color) -> void:
	b.uv2 = Vector2(side * float(pair), root.y)
	var white := Color("ffffff")
	var shade := Color("cfe6ff")
	var dir := func(deg: float) -> Vector3:
		var a := deg_to_rad(deg)
		return Vector3(side * cos(a), sin(a), 0)
	var p0 := root
	var p1: Vector3 = p0 + dir.call(lift + 14.0) * length * 0.36
	var p2: Vector3 = p1 + dir.call(lift - 10.0) * length * 0.3
	b.emit = 0.5
	b.tube([p0, p1, p2], [0.09, 0.07, 0.03], 5, white, white)
	var face := Vector3(0, 0, 1)
	# Primaries fan from the wrist, secondaries hang from the arm, coverts lie over both.
	for k in 10:
		var f := float(k) / 9.0
		var base := p1.lerp(p2, 1.0 - f * 0.8) + Vector3(0, 0, -0.03)
		var along: Vector3 = dir.call(lift + 4.0 - 82.0 * f) * length * lerpf(0.66, 0.42, f)
		b.emit = 0.42
		b.feather(base, along, along.length() * 0.21, face, shade, tip)
	for k in 8:
		var f := float(k) / 7.0
		var base := p0.lerp(p1, 1.0 - f * 0.92) + Vector3(0, 0, -0.03)
		var along: Vector3 = dir.call(lift - 80.0 - 14.0 * f) * length * lerpf(0.42, 0.3, f)
		b.emit = 0.42
		b.feather(base, along, along.length() * 0.26, face, shade, white.lerp(tip, 0.5))
	for k in 12:
		var f := float(k) / 11.0
		var base := (p0.lerp(p1, f * 2.0) if f < 0.5 else p1.lerp(p2, f * 2.0 - 1.0)) + Vector3(0, 0, 0.04)
		var along: Vector3 = dir.call(lift - 86.0 + 62.0 * f) * length * lerpf(0.17, 0.26, f)
		b.emit = 0.6
		b.feather(base, along, along.length() * 0.34, face, white, white)
	b.uv2 = Vector2.ZERO


## The priest's seraph: a robed figure of light with six feathered wings, a halo, a staff
## in the right hand and the scales of judgement in the left. Feet at the origin, facing +Z.
static func _seraph() -> Mesh:
	var b := Build.new()
	var white := Color("ffffff")
	var warm := Color("fff3cf")
	var gold := Color("ffc94a")
	var sky := Color("a9d8ff")
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	# The wings sit behind the body.
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.16))
	for side in [-1.0, 1.0]:
		_wing(b, side, 1, Vector3(side * 0.16, 3.0, 0), 44.0, 3.2, gold)
		_wing(b, side, 2, Vector3(side * 0.16, 2.8, 0), 10.0, 3.7, sky)
		_wing(b, side, 3, Vector3(side * 0.16, 2.5, 0), -34.0, 2.7, sky)
	b.xf = Transform3D.IDENTITY
	# Robe: a long gown that tapers to a trailing point, a gold sash at the waist.
	b.emit = 0.5
	b.loft([
		[Vector3(0, 0.0, -0.22), x * 0.03, z * 0.03, sky],
		[Vector3(0, 0.45, -0.12), x * 0.24, z * 0.17, sky],
		[Vector3(0, 1.3, -0.02), x * 0.38, z * 0.25, white],
		[Vector3(0, 2.1, 0.0), x * 0.31, z * 0.21, white],
		[Vector3(0, 2.42, 0.0), x * 0.25, z * 0.18, gold],
		[Vector3(0, 2.55, 0.0), x * 0.25, z * 0.18, gold],
		[Vector3(0, 2.95, 0.0), x * 0.43, z * 0.21, warm],
		[Vector3(0, 3.12, 0.0), x * 0.3, z * 0.17, warm],
		[Vector3(0, 3.26, 0.0), x * 0.1, z * 0.1, warm]], 10)
	# A stole down the front.
	b.emit = 0.75
	b.quad(Vector3(-0.09, 2.9, 0.22), Vector3(0.09, 2.9, 0.22), Vector3(0.11, 0.9, 0.27), Vector3(-0.11, 0.9, 0.27), gold, gold)
	# Head, hair of light and the halo.
	b.emit = 0.6
	b.ball(Vector3(0, 3.52, 0), Vector3.ONE * 0.27, white, warm, 10, 6)
	b.emit = 0.45
	b.loft([
		[Vector3(0, 3.74, -0.06), x * 0.18, z * 0.2, gold],
		[Vector3(0, 3.5, -0.14), x * 0.3, z * 0.24, gold],
		[Vector3(0, 3.0, -0.2), x * 0.26, z * 0.12, warm],
		[Vector3(0, 2.5, -0.24), x * 0.1, z * 0.05, warm]], 8)
	b.emit = 1.0
	var halo := []
	var radii := []
	for k in 17:
		var a := TAU * float(k) / 16.0
		halo.append(Vector3(cos(a) * 0.46, 4.06 + sin(a) * 0.05, sin(a) * 0.46 - 0.05))
		radii.append(0.04)
	b.tube(halo, radii, 5, gold, gold)
	# Arms: the right raises the staff, the left holds out the scales.
	b.emit = 0.5
	b.tube([Vector3(0.38, 2.92, 0), Vector3(0.72, 2.55, 0.22), Vector3(0.8, 2.98, 0.42)], [0.1, 0.08, 0.07], 6, white, warm)
	b.tube([Vector3(-0.38, 2.92, 0), Vector3(-0.78, 2.5, 0.22), Vector3(-1.0, 2.72, 0.42)], [0.1, 0.08, 0.07], 6, white, warm)
	# Staff with a sun-cross head.
	b.emit = 0.85
	b.tube([Vector3(0.8, 0.9, 0.42), Vector3(0.8, 4.75, 0.42)], [0.04, 0.04], 5, gold, gold)
	var head := []
	var head_r := []
	for k in 13:
		var a := TAU * float(k) / 12.0
		head.append(Vector3(0.8 + cos(a) * 0.26, 5.02 + sin(a) * 0.26, 0.42))
		head_r.append(0.04)
	b.tube(head, head_r, 5, gold, gold)
	b.emit = 1.0
	b.ball(Vector3(0.8, 5.02, 0.42), Vector3.ONE * 0.12, white, warm, 6, 4)
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI / 2
		var out := Vector3(cos(a), sin(a), 0)
		b.cone(Vector3(0.8, 5.02, 0.42) + out * 0.26, Vector3(0.8, 5.02, 0.42) + out * 0.56, 0.06, 4, gold, white)
	# Scales: a beam and two pans.
	b.emit = 0.85
	var hand := Vector3(-1.0, 2.72, 0.42)
	b.tube([hand, hand + Vector3(0, -0.2, 0)], [0.03, 0.03], 4, gold, gold)
	b.tube([hand + Vector3(-0.5, -0.2, 0), hand + Vector3(0.5, -0.2, 0)], [0.03, 0.03], 4, gold, gold)
	for side in [-1.0, 1.0]:
		var end := hand + Vector3(side * 0.5, -0.2, 0)
		var pan := end + Vector3(0, -0.5 + side * 0.07, 0)
		b.tri(end, pan + Vector3(-0.17, 0, 0), pan + Vector3(0.17, 0, 0), gold, gold, gold)
		b.cone(pan, pan + Vector3(0, -0.12, 0), 0.19, 8, gold, warm)
	return b.commit()


## One loose feather for the falling plumes (drift motion), centred on its origin.
static func _feather() -> Mesh:
	var b := Build.new()
	b.emit = 0.55
	b.feather(Vector3(0, -0.3, 0), Vector3(0, 0.6, 0), 0.2, Vector3(0, 0, 1), Color("ffffff"), Color("ffe08a"))
	b.emit = 0.9
	b.tri(Vector3(-0.012, -0.42, 0), Vector3(0.012, -0.42, 0), Vector3(0, -0.2, 0.02), Color("ffd060"), Color("ffd060"), Color("ffffff"))
	return b.commit()


## A meteor: a rock whose leading face (towards -Y) glows, with a long tail and a wider
## faint coma. tint paints the rock, ember the fire: one mesh serves all four elements.
static func _meteor() -> Mesh:
	var b := Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	var hot := Color(1, 1, 1, 0)
	var rings := []
	for i in 7:
		var phi := PI * float(i) / 6.0
		var rr := maxf(0.01, sin(phi)) * (0.4 + 0.1 * rand(float(i) * 3.1))
		var front := smoothstep(0.45, 1.0, float(i) / 6.0)
		rings.append([Vector3(0.04 * sin(i * 2.0), 0.42 + cos(phi) * 0.42, 0), x * rr, z * rr * 0.9, Color(0.8, 0.8, 0.8).lerp(hot, front), front, 1.0, Vector3(0, cos(phi), 0)])
	b.loft(rings, 8)
	# The sheath of fire round the rock and the tail behind it.
	b.loft([
		[Vector3(0, -0.2, 0), x * 0.05, z * 0.05, hot, 1.0, 0.9],
		[Vector3(0, -0.05, 0), x * 0.3, z * 0.3, Color(1, 1, 1, 0.3), 1.0, 0.85],
		[Vector3(0, 0.35, 0), x * 0.52, z * 0.52, Color(1, 1, 1, 0.8), 1.0, 0.75],
		[Vector3(0, 1.1, 0), x * 0.44, z * 0.44, Color.WHITE, 1.0, 0.8],
		[Vector3(0, 3.0, 0), x * 0.24, z * 0.24, Color(0.85, 0.85, 0.85), 1.0, 0.6],
		[Vector3(0, 7.5, 0), x * 0.02, z * 0.02, Color(0.6, 0.6, 0.6), 1.0, 0.0]], 9)
	return b.commit()


## A burst of ice: one tall crystal and six leaning round it, growing out of the origin.
static func _ice() -> Mesh:
	var b := Build.new()
	b.emit = 0.35
	for k in 7:
		var a := TAU * float(k) / 6.0
		var lean := 0.0 if k == 6 else 0.6 + 0.25 * rand(float(k))
		var up := Vector3(sin(a) * sin(lean), cos(lean), cos(a) * sin(lean))
		var length := 1.9 if k == 6 else 1.0 + 0.5 * rand(float(k) + 9.0)
		var u := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.UP).normalized()
		var w := up.cross(u).normalized()
		var r := 0.2 if k == 6 else 0.14
		b.loft([
			[Vector3.ZERO, u * r, w * r, Color("59c8ff")],
			[up * length * 0.7, u * r * 0.85, w * r * 0.85, Color("b8ecff")],
			[up * length, u * 0.004, w * 0.004, Color("ffffff")]], 5)
	return b.commit()


## An arcane crystal hovering over its origin.
static func _crystal() -> Mesh:
	var b := Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	b.emit = 0.5
	b.loft([
		[Vector3(0, 0.3, 0), x * 0.004, z * 0.004, Color("5a2cff")],
		[Vector3(0, 0.85, 0), x * 0.3, z * 0.3, Color("b06aff")],
		[Vector3(0, 1.9, 0), x * 0.004, z * 0.004, Color("ffd0ff")]], 4)
	return b.commit()


## A sliver of light that is pulled in (fall motion): its point leads at the origin.
static func _shard() -> Mesh:
	var b := Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	b.loft([
		[Vector3.ZERO, x * 0.004, z * 0.004, Color.WHITE, 1.0, 1.0],
		[Vector3(0, 0.25, 0), x * 0.07, z * 0.07, Color.WHITE, 1.0, 0.9],
		[Vector3(0, 2.2, 0), x * 0.004, z * 0.004, Color(0.8, 0.8, 0.8), 1.0, 0.0]], 4)
	return b.commit()


## A fork of lightning from 9 m up down to the origin: two crossed ribbons (UV.x across).
static func _bolt() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := []
	for k in 10:
		var y := 9.0 * (1.0 - float(k) / 9.0)
		var wide := 0.0 if k == 9 else 0.55
		points.append(Vector3((rand(float(k) * 1.7) - 0.5) * wide * 2.0, y, (rand(float(k) * 2.9 + 5.0) - 0.5) * wide * 2.0))
	for side in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		for k in 9:
			var a: Vector3 = points[k]
			var c: Vector3 = points[k + 1]
			var w := 0.3 * (1.0 - 0.5 * float(k) / 9.0)
			var corners := [[a - side * w, Vector2(0, float(k) / 9.0)], [a + side * w, Vector2(1, float(k) / 9.0)], [c + side * w, Vector2(1, float(k + 1) / 9.0)], [a - side * w, Vector2(0, float(k) / 9.0)], [c + side * w, Vector2(1, float(k + 1) / 9.0)], [c - side * w, Vector2(0, float(k + 1) / 9.0)]]
			for corner in corners:
				st.set_normal(Vector3.BACK)
				st.set_uv(corner[1])
				st.add_vertex(corner[0])
	return st.commit()


## An orbit of the mage's sky: a thin ring of light of radius 1 in the XZ plane carrying
## its planets (one of them ringed).
static func _orbit(variant: int) -> Mesh:
	var b := Build.new()
	var line: Color = [Color("8fe8ff"), Color("c9a2ff"), Color("ffe9a8")][variant]
	var path := []
	var radii := []
	for k in 41:
		var a := TAU * float(k) / 40.0
		path.append(Vector3(cos(a), 0, sin(a)))
		radii.append(0.017)
	b.emit = 1.0
	b.tube(path, radii, 4, line, line)
	var worlds: Array = [
		[[0.6, 0.24, Color("ffb35a"), Color("b8502a")], [3.9, 0.13, Color("d8f6ff"), Color("5a9ad0")]],
		[[2.2, 0.2, Color("6fe0d0"), Color("2a6aa0")]],
		[[4.6, 0.15, Color("ff9ad0"), Color("7a3aa8")], [1.4, 0.09, Color("fff2b0"), Color("c08a3a")]]][variant]
	for world in worlds:
		var a := float(world[0])
		var at := Vector3(cos(a), 0, sin(a))
		b.emit = 0.2
		b.ball(at, Vector3.ONE * float(world[1]), world[2], world[3], 10, 6)
		if variant == 1:
			b.emit = 0.8
			var belt := []
			var belt_r := []
			for k in 17:
				var t := TAU * float(k) / 16.0
				belt.append(at + Vector3(cos(t) * 0.36, sin(t) * 0.08, sin(t) * 0.36))
				belt_r.append(0.03)
			b.tube(belt, belt_r, 3, Color("fff2c0"), Color("fff2c0"))
	return b.commit()
