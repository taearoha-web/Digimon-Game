class_name Kirin
extends RefCounted
## กิเลนเหยียบเมฆ: the qilin of เกาะลอยฟ้าเทพมังกร, sculpted in code like the isle's
## eastern dragons (CelestialDragon): a slender deer-and-horse body in jade hide with
## gold-edged dragon scales and a cream belly, a dragon's head with glowing eyes, gold
## whiskers, a flowing cream mane tipped in gold fire and a beard, one swept golden
## antler-horn, flame tufts down the spine and at the ankles, an ox tail with a fiery
## tuft, gold cloven hooves, and under every hoof a small swirling cloud it treads on.
##
## One mesh (vertex colours, built once; a lighter one at quality 0) and one shader
## (shaders/kirin.gdshader) that poses it: every vertex knows its part (body, a leg, the
## cloud under a hoof, the neck and head, the tail) and that part's pivot, so the legs
## swing and bend at the knee, the clouds drift round under the hooves, the head nods,
## the tail swishes and the mane streams, all from a few scalars KirinVisual tweens. No
## textures, lights or particles; each kirin on the field has its own small material
## (the Compatibility renderer has no per-instance uniforms).
##
## Mesh metres: +Z is the front, the hooves' clouds stand on y = 0, the horn tip is at
## about 3.2 m; KirinVisual scales it to the template's height.

const K := preload("res://combat/god_art/_kit_arcane.gd")
const SHADER := preload("res://shaders/kirin.gdshader")

const JADE := Color("1aa889")
const JADE_DK := Color("0b6158")
const JADE_LT := Color("5fe0b8")
const GOLD := Color("ffd04a")
const GOLD_DK := Color("c47f16")
const CREAM := Color("ffe9b4")
const CREAM_DK := Color("f2cf86")
const MANE := Color("fffaf0")
const FIRE := Color("ffaa36")
const EYE := Color("fff27a")
const CLOUD := Color("ffffff")
const CLOUD_DK := Color("bfe9dc")

## Parts (CUSTOM1.w in the shader).
const BODY := 0
const NECK := 5
const TAIL := 6
const CLOUD_PART := 10
## The legs: hip (pivot), knee height, knee z, hoof z. FL FR HL HR.
const LEGS := [
	{"hip": Vector3(-0.23, 1.42, 0.56), "knee": 0.7, "knee_z": 0.6, "hoof_z": 0.62, "front": true},
	{"hip": Vector3(0.23, 1.42, 0.56), "knee": 0.7, "knee_z": 0.6, "hoof_z": 0.62, "front": true},
	{"hip": Vector3(-0.23, 1.5, -0.6), "knee": 0.74, "knee_z": -0.76, "hoof_z": -0.66, "front": false},
	{"hip": Vector3(0.23, 1.5, -0.6), "knee": 0.74, "knee_z": -0.76, "hoof_z": -0.66, "front": false},
]
const NECK_PIVOT := Vector3(0, 1.72, 0.62)
const TAIL_PIVOT := Vector3(0, 1.78, -0.98)
## The nose and where the head sits (mesh metres, at rest), for dressing and tests.
const NOSE := Vector3(0, 2.36, 2.02)
const HEAD := Vector3(0, 2.62, 1.45)
## The rest bounds, grown for the gallop, the rear and the fall.
const BOX := AABB(Vector3(-1.9, -0.3, -2.3), Vector3(3.8, 4.4, 5.0))
const HEIGHT := 3.2

static var _meshes := {}
static var _base: ShaderMaterial


## The shared kirin mesh (a lighter one at quality 0).
static func mesh() -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	if not _meshes.has(lite):
		var built := _build(lite)
		built.custom_aabb = BOX
		_meshes[lite] = built
	return _meshes[lite]


## A fresh material for one kirin.
static func material() -> ShaderMaterial:
	if _base == null:
		_base = ShaderMaterial.new()
		_base.shader = SHADER
		_base.set_shader_parameter("hind_z", LEGS[2].hoof_z)
		_base.set_shader_parameter("scale_gold", GOLD)
		_base.set_shader_parameter("rim_color", Color("dcfff2"))
		_base.set_shader_parameter("shadow_tint", Color(0.74, 0.68, 0.76))
		_base.set_shader_parameter("rim", 0.32)
	return _base.duplicate() as ShaderMaterial


## A kirin ready to place: the body at mesh scale (scale it yourself), its own material.
static func body() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "KirinBody"
	mi.mesh = mesh()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi


static func triangles(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return n


# ---------------------------------------------------------------------------
# The mesh.
# ---------------------------------------------------------------------------
static func _part(b: K.Builder, part: int, pivot := Vector3.ZERO, flutter := 0.0, leg := {}) -> void:
	b.customs = true
	b.pivot = pivot
	b.tumble = float(part)
	b.vel = Vector3(float(leg.get("knee", 0.0)), float(leg.get("knee_z", 0.0)), flutter)
	b.wait = float(leg.get("hoof_z", 0.0))


## A colour whose alpha marks how much of the tuft's flutter it carries (0: all of it).
static func _tip(c: Color) -> Color:
	return Color(c, 0.0)


## A flame-shaped tuft: a flat ribbon (both faces drawn) in the plane across [param face],
## from root to tip in an S, widest a third of the way, cream to fire, fluttering to its tip.
static func _flame(b: K.Builder, root: Vector3, tip: Vector3, width: float, curl: Vector3, face := Vector3.RIGHT, root_col := MANE, tip_col := FIRE, segs := 3) -> void:
	var d := tip - root
	var pts := []
	for k in segs + 1:
		var u := float(k) / float(segs)
		pts.append(root + d * u + curl * sin(u * PI) - curl * 0.35 * sin(u * TAU))
	var prev := []
	for k in pts.size():
		var u := float(k) / float(segs)
		var tangent: Vector3 = (pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(face).normalized()
		var w := width * sin(PI * (0.15 + 0.85 * u))
		var col := root_col.lerp(tip_col, pow(u, 1.3))
		col.a = 1.0 - u
		var here := [pts[k] - across * w * 0.5, pts[k] + across * w * 0.5, col]
		if not prev.is_empty():
			b.quad(prev[0], prev[1], here[1], here[0], prev[2], here[2])
		prev = here


static func _build(lite: bool) -> ArrayMesh:
	var b := K.Builder.new()
	var sides := 6 if lite else 9
	_torso(b, sides, lite)
	for i in LEGS.size():
		_leg(b, i, LEGS[i], lite)
	_neck(b, sides, lite)
	_head(b, lite)
	_tail(b, lite)
	return b.mesh()


static func _torso(b: K.Builder, sides: int, lite: bool) -> void:
	_part(b, BODY)
	b.weight = 1.0
	# Rump to chest: round haunches, a slim waist, a deep chest rising into the neck.
	var path := [Vector3(0, 1.6, -1.04), Vector3(0, 1.62, -0.9), Vector3(0, 1.6, -0.62), Vector3(0, 1.54, -0.3), Vector3(0, 1.53, 0.05), Vector3(0, 1.56, 0.4), Vector3(0, 1.62, 0.7), Vector3(0, 1.68, 0.86)]
	var radii := [Vector2(0.12, 0.12), Vector2(0.33, 0.35), Vector2(0.42, 0.43), Vector2(0.37, 0.38), Vector2(0.38, 0.41), Vector2(0.41, 0.47), Vector2(0.35, 0.42), Vector2(0.16, 0.2)]
	b.tube(path, radii, sides + 1, [[JADE, CREAM]])
	b.weight = 0.0
	# Flame tufts down the spine, cream fading to gold fire, blown back.
	var tufts := 4 if lite else 6
	_part(b, BODY, Vector3.ZERO, 1.0)
	b.emit = 0.2
	for k in tufts:
		var f := float(k) / float(tufts - 1)
		var z := lerpf(0.5, -0.8, f)
		var y := 1.98 - 0.04 * f
		var tall := lerpf(0.36, 0.26, f)
		_flame(b, Vector3(0, y - 0.06, z + 0.08), Vector3(0, y + tall, z - 0.32), 0.22, Vector3(0, 0.02, 0.07))
	b.emit = 0.0
	# Gold swirls on shoulder and haunch (the kirin's flame marks), flat on the hide.
	if lite:
		return
	b.emit = 0.45
	_part(b, BODY)
	for side in [-1.0, 1.0]:
		for at in [Vector3(side * 0.425, 1.62, 0.42), Vector3(side * 0.435, 1.66, -0.62)]:
			var n := 10
			var prev := []
			for i in n:
				var u := float(i) / float(n - 1)
				var a := u * TAU * 1.3
				var r := lerpf(0.21, 0.03, u)
				var dir := Vector3(0, sin(a), cos(a) * 1.2)
				var w := lerpf(0.05, 0.016, u)
				var p: Vector3 = at + Vector3(side * 0.03 * (1.0 - u * u), 0, 0) + dir * r
				var here := [p - dir.normalized() * w, p + dir.normalized() * w]
				if not prev.is_empty():
					b.quad(prev[0], prev[1], here[1], here[0], GOLD, GOLD)
				prev = here
	b.emit = 0.0


static func _leg(b: K.Builder, i: int, leg: Dictionary, lite: bool) -> void:
	var hip: Vector3 = leg.hip
	var x := hip.x
	var side := signf(x)
	var front := bool(leg.front)
	var knee := float(leg.knee)
	var kz := float(leg.knee_z)
	var hz := float(leg.hoof_z)
	var sides := 5 if lite else 7
	_part(b, i + 1, hip, 0.0, leg)
	b.weight = 0.8
	var lx := x + side * 0.03
	if front:
		b.tube([hip + Vector3(0, 0.12, 0), Vector3(lx, 1.12, 0.6), Vector3(lx, knee + 0.04, kz), Vector3(lx, 0.36, hz - 0.01), Vector3(lx, 0.25, hz + 0.02)],
			[0.16, 0.12, 0.085, 0.065, 0.07], sides, [[JADE, JADE_DK], [JADE, JADE_DK], [JADE_DK, JADE_DK]])
	else:
		# The hind leg: a strong thigh, the hock pointing back, the cannon down to the hoof.
		b.tube([hip + Vector3(0, 0.1, 0.02), Vector3(lx, 1.2, -0.48), Vector3(lx, 0.98, -0.6), Vector3(lx, knee, kz), Vector3(lx, 0.36, hz - 0.02), Vector3(lx, 0.25, hz)],
			[Vector2(0.2, 0.24), 0.16, 0.12, 0.08, 0.065, 0.07], sides, [[JADE, JADE_DK], [JADE, JADE_DK], [JADE, JADE_DK], [JADE_DK, JADE_DK]])
	b.weight = 0.0
	# Gold cloven hoof.
	b.emit = 0.2
	b.tube([Vector3(lx, 0.28, hz + 0.02), Vector3(lx, 0.15, hz + 0.05)], [0.075, Vector2(0.095, 0.085)], 5 if lite else 6, [[GOLD, GOLD_DK]])
	b.emit = 0.0
	# Flame tufts at the ankle, streaming back.
	_part(b, i + 1, hip, 1.0, leg)
	b.emit = 0.2
	for k in 2:
		var o := side * (0.05 if k == 0 else -0.04)
		var root := Vector3(lx + o, 0.42 - 0.05 * k, hz - 0.03)
		_flame(b, root, root + Vector3(o, 0.18 - 0.1 * k, -0.34 + 0.06 * k), 0.17, Vector3(0, 0.05, 0.0))
	b.emit = 0.0
	# The cloud under the hoof: soft puffs and a gold-trimmed curl (ruyi).
	_part(b, CLOUD_PART + i + 1, hip, 0.0, leg)
	var c := Vector3(lx, cloud_y(), hz)
	b.emit = 0.65
	var puffs := [Vector3(0, 0.0, 0.0), Vector3(0.17, -0.01, -0.12), Vector3(-0.16, -0.01, 0.1)]
	for k in (1 if lite else 2):
		var o: Vector3 = puffs[k]
		var r := 0.22 if k == 0 else 0.16
		b.ball(c + o, Vector3(r * 1.15, r * 0.5, r), CLOUD, CLOUD_DK, 6, 4)
	# The ruyi curl round the hoof: a flat ribbon of cloud with a gold lining.
	var curl := []
	var n := 6 if lite else 9
	for k in n:
		var u := float(k) / float(n - 1)
		var a := u * TAU * 1.2 + float(i) * 1.7
		curl.append([c + Vector3(cos(a), 0.0, sin(a)) * lerpf(0.36, 0.1, u) + Vector3(0, 0.07 + 0.04 * u, 0), Vector3(cos(a), 0, sin(a)), lerpf(0.11, 0.03, u)])
	for k in n - 1:
		var p: Array = curl[k]
		var q: Array = curl[k + 1]
		b.quad(p[0] - p[1] * p[2], p[0] + p[1] * p[2], q[0] + q[1] * q[2], q[0] - q[1] * q[2], CLOUD, CLOUD)
		if not lite:
			b.emit = 0.7
			var up := Vector3(0, 0.012, 0)
			b.quad(p[0] + p[1] * p[2] * 0.55 + up, p[0] + p[1] * p[2] + up, q[0] + q[1] * q[2] + up, q[0] + q[1] * q[2] * 0.55 + up, GOLD, GOLD)
			b.emit = 0.65
	b.emit = 0.0


static func cloud_y() -> float:
	return 0.09


static func _neck(b: K.Builder, sides: int, lite: bool) -> void:
	_part(b, NECK, NECK_PIVOT)
	b.weight = 0.9
	b.tube([Vector3(0, 1.56, 0.58), Vector3(0, 1.9, 0.92), Vector3(0, 2.24, 1.14), Vector3(0, 2.5, 1.28), Vector3(0, 2.62, 1.34)],
		[Vector2(0.3, 0.36), Vector2(0.22, 0.25), Vector2(0.18, 0.2), Vector2(0.16, 0.17), Vector2(0.1, 0.1)], sides, [[JADE, CREAM]])
	b.weight = 0.0
	# The flowing mane down the crest of the neck, cream into gold fire, in two ranks.
	_part(b, NECK, NECK_PIVOT, 1.0)
	b.emit = 0.15
	var n := 5 if lite else 7
	for k in n:
		var f := float(k) / float(n - 1)
		var root := Vector3(0, lerpf(2.66, 1.95, f), lerpf(1.2, 0.55, f))
		var long := lerpf(0.75, 0.55, f)
		_flame(b, root, root + Vector3(0, 0.18 - 0.2 * f, -long), 0.3, Vector3(0, 0.1, 0.0))
		if not lite and k % 2 == 1:
			for side in [-1.0, 1.0]:
				var r2 := root + Vector3(side * 0.13, -0.1, 0.05)
				_flame(b, r2, r2 + Vector3(side * 0.2, -0.12, -long * 0.85), 0.24, Vector3(side * 0.05, 0.06, 0.0), Vector3(1, 0.4 * side, 0).normalized())
	b.emit = 0.0


## The dragon head, built nose-first in its own frame (+z runs back up the skull).
static func _head(b: K.Builder, lite: bool) -> void:
	_part(b, NECK, NECK_PIVOT)
	var s := 0.34
	var th := 0.36
	var basis := Basis(Vector3(1.15, 0, 0) * s, Vector3(0, cos(th), sin(th)) * 1.2 * s, Vector3(0, sin(th), -cos(th)) * 1.15 * s)
	b.xf = Transform3D(basis, NOSE)
	var sides := 6 if lite else 9
	var top := JADE.lerp(JADE_LT, 0.35)
	b.weight = 0.55
	b.tube([Vector3(0, 0.05, 0), Vector3(0, 0.09, 0.3), Vector3(0, 0.13, 0.75), Vector3(0, 0.22, 1.15), Vector3(0, 0.16, 1.55), Vector3(0, 0.0, 1.95)],
		[Vector2(0.24, 0.15), Vector2(0.33, 0.21), Vector2(0.4, 0.28), Vector2(0.56, 0.42), Vector2(0.56, 0.48), Vector2(0.44, 0.44)], sides,
		[[top, CREAM], [top, CREAM], [JADE, CREAM], [JADE, CREAM], [JADE, CREAM], [JADE, CREAM]])
	b.weight = 0.0
	# Lower jaw, the mouth just open, two small fangs.
	b.tube([Vector3(0, -0.3, 0.16), Vector3(0, -0.36, 0.55), Vector3(0, -0.34, 1.0), Vector3(0, -0.2, 1.45)],
		[Vector2(0.17, 0.07), Vector2(0.25, 0.09), Vector2(0.33, 0.12), Vector2(0.4, 0.15)], 5 if lite else 7, [[CREAM, CREAM_DK]])
	b.quad(Vector3(-0.26, -0.24, 0.3), Vector3(0.26, -0.24, 0.3), Vector3(0.34, -0.12, 1.3), Vector3(-0.34, -0.12, 1.3), Color("c8304a"), Color("6a1028"))
	# Nose pad with nostrils.
	b.ball(Vector3(0, 0.12, 0.08), Vector3(0.22, 0.13, 0.15), top, JADE, 5 if lite else 6, 3 if lite else 4)
	for side in [-1.0, 1.0]:
		b.ball(Vector3(side * 0.11, 0.17, 0.02), Vector3(0.06, 0.04, 0.05), Color("08403a"), Color("08403a"), 4, 2)
		b.cone(Vector3(side * 0.16, -0.06, 0.24), Vector3(side * 0.17, -0.3, 0.28), 0.05, 4, Color("fbfff2"))
		# Gold brow ridge over the lit eye.
		b.emit = 0.3
		b.tube([Vector3(side * 0.18, 0.42, 0.6), Vector3(side * 0.42, 0.58, 0.92), Vector3(side * 0.56, 0.62, 1.32)], [0.07, 0.1, 0.04], 4, [[GOLD, GOLD_DK]])
		b.emit = 1.0
		b.ball(Vector3(side * 0.43, 0.38, 0.98), Vector3(0.13, 0.12, 0.16), Color("fffef0"), EYE, 5 if lite else 7, 4)
		b.emit = 0.0
		b.ball(Vector3(side * 0.54, 0.38, 0.95), Vector3(0.035, 0.09, 0.07), Color("1a0a1e"), Color("1a0a1e"), 4, 2)
		b.emit = 1.0
		b.ball(Vector3(side * 0.56, 0.43, 0.92), Vector3(0.02, 0.025, 0.025), Color.WHITE, Color.WHITE, 4, 2)
		b.emit = 0.0
		# Leaf ears, cream inside.
		b.tube([Vector3(side * 0.42, 0.5, 1.55), Vector3(side * 0.72, 0.7, 1.85), Vector3(side * 0.98, 0.78, 2.12)], [Vector2(0.12, 0.05), Vector2(0.1, 0.04), 0.0], 5, [[JADE, CREAM]], Vector3.UP, false)
		# Cheek fins, jade to cream.
		b.tri3(Vector3(side * 0.52, 0.18, 1.25), Vector3(side * 0.56, -0.24, 1.38), Vector3(side * 1.05, 0.05, 2.0), JADE_LT, JADE, _tip(CREAM))
		# Gold whiskers trailing from the snout.
		_part(b, NECK, NECK_PIVOT, 1.0)
		b.emit = 0.45
		var whisker := []
		var thin := []
		for k in (6 if lite else 9):
			var u := float(k) / (5.0 if lite else 8.0)
			whisker.append(Vector3(side * (0.22 + 0.6 * sin(u * 2.2) + 0.15 * u), -0.05 - 0.9 * u + 0.25 * sin(u * 5.0) * u, 0.18 + u * 2.6))
			thin.append(lerpf(0.05, 0.014, u))
		var wc := []
		for k in whisker.size():
			wc.append(Color(GOLD, 1.0 - float(k) / float(whisker.size() - 1)))
		b.tube(whisker, thin, 3, wc)
		b.emit = 0.0
		_part(b, NECK, NECK_PIVOT)
	# The golden antler-horn: one swept horn from the brow, ringed, with two tines.
	b.emit = 2.0
	var horn := [Vector3(0, 0.42, 1.18), Vector3(0, 0.95, 1.45), Vector3(0, 1.55, 1.85), Vector3(0, 2.05, 2.4), Vector3(0, 2.3, 3.0), Vector3(0, 2.28, 3.4)]
	var path := K.smooth(horn, 1 if lite else 2)
	var rr := []
	var cols := []
	for k in path.size():
		var u := float(k) / float(path.size() - 1)
		rr.append(lerpf(0.17, 0.0, pow(u, 1.2)))
		cols.append(GOLD if k % 2 == 0 else GOLD_DK.lerp(GOLD, 0.45))
	b.tube(Array(path), rr, 5 if lite else 6, cols)
	if not lite:
		for side in [-1.0, 1.0]:
			b.tube([Vector3(0, 1.25, 1.64), Vector3(side * 0.3, 1.7, 1.75), Vector3(side * 0.42, 2.0, 2.0)], [0.08, 0.05, 0.0], 5, [[GOLD, GOLD_DK]])
	b.emit = 0.0
	# Mane flowing back from the skull and a beard under the chin, cream into fire.
	_part(b, NECK, NECK_PIVOT, 1.0)
	b.emit = 0.25
	var manes := 5 if lite else 9
	for k in manes:
		var a := lerpf(-0.6, PI + 0.6, float(k) / float(manes - 1))
		var out := Vector3(cos(a), sin(a), 0)
		var long := 1.5 + 0.55 * float(k % 3)
		b.cone(Vector3(out.x * 0.42, out.y * 0.38 + 0.08, 1.55), Vector3(out.x * 1.0, out.y * 0.85 - 0.2, 1.7 + long), Vector2(0.22, 0.18), 4, MANE, _tip(FIRE))
	for k in 3:
		b.cone(Vector3(0.14 * (k - 1), -0.4, 0.95), Vector3(0.32 * (k - 1), -1.25 - 0.15 * float(k % 2), 1.75), 0.13, 4, MANE, _tip(FIRE))
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY


## The ox tail: a thin jade whip ending in a fiery tuft.
static func _tail(b: K.Builder, lite: bool) -> void:
	_part(b, TAIL, TAIL_PIVOT)
	var whip := [TAIL_PIVOT + Vector3(0, -0.02, 0.1), Vector3(0, 1.84, -1.2), Vector3(0, 1.7, -1.46), Vector3(0, 1.36, -1.62), Vector3(0, 1.05, -1.62)]
	b.weight = 0.5
	b.tube(Array(K.smooth(whip, 2)), [0.08, 0.07, 0.06, 0.05, 0.05], 5, [[JADE, JADE_DK]])
	b.weight = 0.0
	_part(b, TAIL, TAIL_PIVOT, 0.8)
	b.emit = 0.2
	var end := Vector3(0, 1.12, -1.62)
	var n := 5 if lite else 7
	for k in n:
		var a := TAU * float(k) / float(n)
		var out := Vector3(cos(a), 0, sin(a))
		var dir := out * 0.2 + Vector3(0, -0.6, -0.14)
		_flame(b, end + out * 0.04, end + dir, 0.26, out * 0.08 + Vector3(0, 0, -0.05), Vector3(-sin(a), 0, cos(a)))
	b.emit = 0.0
