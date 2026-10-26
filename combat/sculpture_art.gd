class_name SculptureArt
extends Node3D
## The engine under the layered skill art of the Assassin (ShadowSkillArt) and the
## Dark Lord (LordSkillArt): one node per cast holding timed layers, each a shared
## sculpture (built once per kind by the subclass, _sculpture) in one of two
## materials. shadow_ink: a dark churning body, a rim in the primary colour and
## bright inlays (COLOR.r) in the accent. shadow_glow: additive energy from the
## primary colour to a white-hot core (COLOR.r). COLOR.g is the opacity mask.
## Each layer grows in, moves (travel, drop, orbit), turns and dissolves out on its
## own clock; the layers are budgeted (VfxBudget) and a cancelled cast (new skill
## generation of the caster's visual) drops a wind-up. Also the geometry helpers
## the subclasses build their sculptures with.

const INK := preload("res://shaders/shadow_ink.gdshader")
const GLOW := preload("res://shaders/shadow_glow.gdshader")
## Decorations left free for hits, flourishes and other casters.
const RESERVE := 8

var age := 0.0
var lifetime := 0.5
var layers: Array[Dictionary] = []
var owner_ref: WeakRef
var generation := -1
var cap := 16


## The shared mesh of a sculpture kind (the subclass builds and caches them).
func _sculpture(_kind: String) -> ArrayMesh:
	return null


static func _alive(parent: Node3D) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


static func _yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length_squared() > 0.001 else 0.0


## One layer: a shared sculpture in the ink or glow material. size scales the
## unit geometry; style keys: initial, grow (speed), travel, accelerate, drop and
## land, spin (around Y, rad/s), roll (around Z, rad/s), turn, orbit and
## orbit_speed, flap, face_camera, fade_in, decay, opacity.
func layer(kind: String, glow: bool, c: Array, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	if layers.size() >= cap or not VfxBudget.can_decorate(1 + RESERVE):
		return
	var node := MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = _sculpture(kind)
	var mat := ShaderMaterial.new()
	mat.shader = GLOW if glow else INK
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.9 if glow else 0.86)))
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	VfxBudget.track_decoration(node)
	layers.append({"node": node, "mat": mat, "at": at, "size": size, "angles": angles, "start": start, "seconds": maxf(seconds, 0.05), "style": style})
	lifetime = maxf(lifetime, start + seconds + 0.02)


func _process(delta: float) -> void:
	if owner_ref:
		var visual := owner_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation != generation:
			queue_free()
			return
	age += delta
	_draw()
	if age >= lifetime:
		queue_free()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for data in layers:
		var node: MeshInstance3D = data.node
		var style: Dictionary = data.style
		var local := age - float(data.start)
		var t := clampf(local / float(data.seconds), 0.0, 1.0)
		node.visible = local >= 0.0 and t < 1.0
		if not node.visible:
			continue
		var rise := 1.0 - pow(1.0 - minf(t * float(style.get("grow", 4.0)), 1.0), 3.0)
		node.scale = (data.size as Vector3) * maxf(0.004, lerpf(float(style.get("initial", 0.55)), 1.0, rise))
		var travel: Vector3 = style.get("travel", Vector3.ZERO)
		var progress := t * t if bool(style.get("accelerate", false)) else 1.0 - pow(1.0 - t, 2.0)
		var at: Vector3 = (data.at as Vector3) + travel * progress
		if style.has("drop"):
			at.y += float(style.drop) * (1.0 - smoothstep(0.0, maxf(0.01, float(style.get("land", 0.15))), local))
		if style.has("orbit"):
			var a := float(style.get("phase", 0.0)) + local * float(style.get("orbit_speed", 3.0))
			at += Vector3(sin(a), 0.0, cos(a)) * float(style.orbit)
		node.position = at
		var rot: Vector3 = (data.angles as Vector3) + (style.get("turn", Vector3.ZERO) as Vector3) * smoothstep(0.0, 0.6, t)
		rot.y += float(style.get("spin", 0.0)) * local
		rot.z += float(style.get("roll", 0.0)) * local + sin(local * 7.0) * float(style.get("flap", 0.0))
		node.rotation = rot
		if bool(style.get("face_camera", false)) and camera:
			var toward := global_basis.inverse() * (camera.global_position - node.global_position)
			node.rotation.y = atan2(toward.x, toward.z)
		var fade := smoothstep(0.0, float(style.get("fade_in", 0.06)), t) * (1.0 - smoothstep(minf(float(style.get("decay", 0.55)), 0.98), 1.0, t))
		var mat: ShaderMaterial = data.mat
		mat.set_shader_parameter("fade", fade)
		mat.set_shader_parameter("age", local)


# ---------------------------------------------------------------------------
# Geometry helpers. Flat pieces lie in the XY plane facing +Z, ground pieces in
# the XZ plane, upright figures stand on y = 0 facing +Z.
# ---------------------------------------------------------------------------

static func _v(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	n = n.normalized() if n.length_squared() > 0.0000001 else Vector3.BACK
	_v(st, a, n, ca)
	_v(st, b, n, cb)
	_v(st, c, n, cc)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_tri(st, a, b, c, ca, cb, cc)
	_tri(st, a, c, d, ca, cc, cd)


## A flat strip from a to b in the plane with normal [param up].
static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, width: float, up: Vector3, ca: Color, cb: Color, end_width := -1.0) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(up).normalized()
	var w2 := width if end_width < 0.0 else end_width
	_quad(st, a - side * width * 0.5, b - side * w2 * 0.5, b + side * w2 * 0.5, a + side * width * 0.5, ca, cb, cb, ca)


## A smooth tube through points (radius per point), coloured per point.
static func _tube(st: SurfaceTool, points: Array, radii: Array, colors: Array, sides := 6) -> void:
	var rings: Array = []
	for i in points.size():
		var p: Vector3 = points[i]
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var axis := (b - a).normalized()
		var helper := Vector3.BACK if absf(axis.z) < 0.9 else Vector3.RIGHT
		var u := axis.cross(helper).normalized()
		var v := axis.cross(u)
		var ring: Array = []
		for s in sides:
			var t := TAU * float(s) / float(sides)
			var d := u * cos(t) + v * sin(t)
			ring.append([p + d * float(radii[i]), d])
		rings.append(ring)
	for i in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var q := [rings[i][s], rings[i + 1][s], rings[i + 1][s2], rings[i][s2]]
			var cols := [colors[i], colors[i + 1], colors[i + 1], colors[i]]
			for k in [0, 1, 2, 0, 2, 3]:
				_v(st, q[k][0], q[k][1], cols[k])


static func _sphere(st: SurfaceTool, centre: Vector3, radius: Vector3, color: Color, rings := 5, seg := 8) -> void:
	for r in rings:
		for s in seg:
			var pts: Array = []
			for k in [[r, s], [r + 1, s], [r + 1, s + 1], [r, s + 1]]:
				var phi := PI * float(k[0]) / float(rings)
				var th := TAU * float(k[1]) / float(seg)
				var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				pts.append([centre + d * radius, d])
			for k in [0, 1, 2, 0, 2, 3]:
				_v(st, pts[k][0], pts[k][1], color)
