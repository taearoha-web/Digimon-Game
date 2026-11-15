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
const HAIR_GOLD := Color("ffd98a")
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


## Hair: cream at the root, warm gold through the middle, gold fire at the tip.
static func _hair(u: float) -> Color:
	var col := MANE.lerp(HAIR_GOLD, smoothstep(0.1, 0.6, u)).lerp(FIRE, smoothstep(0.55, 1.0, u))
	col.a = 1.0 - u
	return col


## One lock of hair: a ribbon folded along its spine (a shallow ridge, so it has volume
## and catches the light like a lock, not a blade), from root to tip in a soft S, tapering
## to a point, cream into gold fire, its flutter growing to the tip (COLOR.a). [param face]
## is the side the ridge faces.
static func _lock(b: K.Builder, root: Vector3, tip: Vector3, width: float, curl: Vector3, face: Vector3, segs := 3, phase := 0.0) -> void:
	var d := tip - root
	var pts := []
	for k in segs + 1:
		var u := float(k) / float(segs)
		pts.append(root + d * u + curl * sin(u * PI) - curl * 0.3 * sin(u * TAU + phase))
	var prev := []
	for k in pts.size():
		var u := float(k) / float(segs)
		var tangent: Vector3 = (pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(face).normalized()
		var up := across.cross(tangent).normalized()
		var w := width * 0.5 * pow(1.0 - u, 0.65) * (0.8 + 0.45 * sin(PI * minf(u * 1.6, 1.0)))
		var col := _hair(u)
		var mid: Vector3 = pts[k] + up * w * 0.55
		var ring := [
			b.pt(pts[k] - across * w, (up * 0.45 - across).normalized(), col),
			b.pt(mid, up, col),
			b.pt(pts[k] + across * w, (up * 0.45 + across).normalized(), col)]
		if not prev.is_empty():
			b.tri(prev[0], prev[1], ring[1]); b.tri(prev[0], ring[1], ring[0])
			b.tri(prev[1], prev[2], ring[2]); b.tri(prev[1], ring[2], ring[1])
		prev = ring


## A tuft of [param n] locks fanned across [param face] from about [param root] to about
## [param tip]: thinner, slightly different in length and curl, so it reads as soft hair.
static func _tuft(b: K.Builder, root: Vector3, tip: Vector3, width: float, curl: Vector3, face: Vector3, n := 3, segs := 3) -> void:
	var d := tip - root
	var across := d.cross(face).normalized()
	for j in n:
		var f := 0.0 if n == 1 else float(j) / float(n - 1) - 0.5
		var long := 1.0 - 0.16 * absf(f) * 2.0 + 0.06 * float(j % 2)
		var off := across * f * width * 0.9
		var r := root + off * 0.5
		var t := root + d * long + off * 0.9 + face * 0.05 * float((j + 1) % 2)
		_lock(b, r, t, width * (1.3 / float(n) + 0.22), curl * (1.0 + 0.3 * f), face, segs, f * 2.0)


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
	# Soft tufts of hair down the spine, cream into gold fire, lying back along it.
	var tufts := 3 if lite else 4
	_part(b, BODY, Vector3.ZERO, 1.0)
	b.emit = 0.18
	for k in tufts:
		var f := float(k) / float(tufts - 1)
		var z := lerpf(0.42, -0.78, f)
		var y := 1.96 - 0.04 * f
		var tall := lerpf(0.24, 0.16, f)
		_tuft(b, Vector3(0, y - 0.08, z + 0.06), Vector3(0, y + tall, z - 0.4), 0.2, Vector3(0, 0.06, 0.04), Vector3.UP, 2, 3)
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
	var sides := 6 if lite else 7
	_part(b, i + 1, hip, 0.0, leg)
	b.weight = 0.8
	var lx := x + side * 0.03
	var lower := JADE.lerp(JADE_DK, 0.55)
	# Radii are (width, depth): a deer's leg, broad from the side, slimmer from the front,
	# muscled above the joint and tapering into a fine cannon over the hoof. The frame's
	# up is +Z so the width stays across the leg all the way down (no twist at the joint).
	if front:
		# Shoulder and forearm, the knee (carpus), the cannon, the fetlock, the pastern.
		b.tube([hip + Vector3(0, 0.14, 0.02), Vector3(lx, 1.2, 0.62), Vector3(lx, 0.98, 0.62), Vector3(lx, knee, kz), Vector3(lx, 0.37, hz - 0.01), Vector3(lx, 0.27, hz + 0.02)],
			[Vector2(0.19, 0.25), Vector2(0.16, 0.2), Vector2(0.125, 0.15), Vector2(0.092, 0.1), Vector2(0.08, 0.086), Vector2(0.072, 0.078)], sides,
			[[JADE, JADE_DK], [JADE, JADE_DK], [JADE, JADE_DK], [lower, JADE_DK], [lower, JADE_DK]], Vector3.BACK, false)
	else:
		# The hind leg: a deep thigh and gaskin, the hock pointing back, the cannon down to the hoof.
		b.tube([hip + Vector3(0, 0.12, 0.04), Vector3(lx, 1.3, -0.5), Vector3(lx, 1.04, -0.62), Vector3(lx, knee + 0.02, kz), Vector3(lx, 0.37, hz - 0.02), Vector3(lx, 0.27, hz)],
			[Vector2(0.22, 0.32), Vector2(0.19, 0.26), Vector2(0.13, 0.16), Vector2(0.092, 0.115), Vector2(0.08, 0.086), Vector2(0.072, 0.078)], sides,
			[[JADE, JADE_DK], [JADE, JADE_DK], [JADE, JADE_DK], [lower, JADE_DK], [lower, JADE_DK]], Vector3.BACK, false)
	b.weight = 0.0
	# The joint: a smooth knob at the knee / hock.
	var joint := Vector3(lx, knee + (0.0 if front else 0.02), kz + (0.03 if front else -0.04))
	b.ball(joint, Vector3(0.09, 0.09, 0.095), JADE, JADE.lerp(JADE_DK, 0.4), 5, 2)
	# Gold cloven hoof.
	b.emit = 0.2
	b.tube([Vector3(lx, 0.29, hz + 0.02), Vector3(lx, 0.15, hz + 0.05)], [0.078, Vector2(0.1, 0.09)], 5 if lite else 7, [[GOLD, GOLD_DK]], Vector3.BACK)
	b.emit = 0.0
	# Feathering at the fetlock: a few soft locks streaming back.
	_part(b, i + 1, hip, 1.0, leg)
	b.emit = 0.2
	var root := Vector3(lx, 0.44, hz - 0.05)
	_tuft(b, root, root + Vector3(side * 0.05, 0.08, -0.3), 0.17, Vector3(0, 0.05, 0.0), Vector3(side, 0.4, 0).normalized(), 2, 2)
	b.emit = 0.0
	# The cloud under the hoof: a cluster of soft round puffs (one at the lowest quality),
	# lit softly by the shader, the big one rimmed in gold where it meets the hoof.
	_part(b, CLOUD_PART + i + 1, hip, 0.0, leg)
	var c := Vector3(lx, cloud_y(), hz)
	b.emit = 0.55
	var a0 := float(i) * 1.7
	var puffs := [[Vector3(0, 0.02, 0.0), Vector3(0.27, 0.17, 0.24)],
		[Vector3(cos(a0), 0, sin(a0)) * 0.22 + Vector3(0, -0.01, 0), Vector3(0.16, 0.11, 0.15)],
		[Vector3(cos(a0 + 2.4), 0, sin(a0 + 2.4)) * 0.2 + Vector3(0, -0.02, 0), Vector3(0.14, 0.09, 0.13)]]
	for k in (1 if lite else 3):
		_puff(b, c + puffs[k][0], puffs[k][1], (10 if lite else 12) if k == 0 else 8, 3 if k == 0 else 2, k == 0)
	b.emit = 0.0


## A round cloud puff: a dome (no hidden underside) with smooth normals, white on top,
## mint-shadowed round its foot ([param gilt]: a gold rim there). The shader lights it
## softly so it reads as vapour.
static func _puff(b: K.Builder, c: Vector3, r: Vector3, lon: int, lat: int, gilt := false) -> void:
	var base := b.v.size()
	var rows := lat + 1
	for i in rows + 1:
		var th := PI * 0.6 * float(mini(i, rows - 1)) / float(rows - 1)
		var inside := i < rows
		for j in lon + 1:
			var ph := TAU * float(j) / float(lon)
			var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) if inside else Vector3(0, -0.3, 0)
			var col := CLOUD_DK.lerp(CLOUD, clampf(d.y * 0.9 + 0.45, 0.0, 1.0))
			if gilt and i == rows - 1:
				col = GOLD.lerp(CLOUD, 0.35)
			b.pt(c + d * r, (d / r).normalized() if inside else Vector3.DOWN, col)
	for i in rows:
		for j in lon:
			var a := base + i * (lon + 1) + j
			var d := a + lon + 1
			if i == 0:
				b.tri(a, d + 1, d)
			else:
				b.tri(a, a + 1, d + 1); b.tri(a, d + 1, d)


static func cloud_y() -> float:
	return 0.09


static func _neck(b: K.Builder, sides: int, lite: bool) -> void:
	_part(b, NECK, NECK_PIVOT)
	b.weight = 0.9
	b.tube([Vector3(0, 1.56, 0.58), Vector3(0, 1.9, 0.92), Vector3(0, 2.24, 1.14), Vector3(0, 2.5, 1.28), Vector3(0, 2.62, 1.34)],
		[Vector2(0.3, 0.36), Vector2(0.22, 0.25), Vector2(0.18, 0.2), Vector2(0.16, 0.17), Vector2(0.1, 0.1)], sides, [[JADE, CREAM]])
	b.weight = 0.0
	# The flowing mane down the crest of the neck: soft tufts of locks, cream into gold
	# fire, falling to either side of the crest and back, with a shorter rank under them.
	_part(b, NECK, NECK_PIVOT, 1.0)
	b.emit = 0.15
	var n := 5 if lite else 6
	for k in n:
		var f := float(k) / float(n - 1)
		var side := -1.0 if k % 2 == 0 else 1.0
		var root := Vector3(0, lerpf(2.64, 1.95, f), lerpf(1.18, 0.55, f))
		var long := lerpf(0.72, 0.56, f)
		var face := Vector3(side * 0.55, 1.0, 0.25).normalized()
		_tuft(b, root, root + Vector3(side * 0.16, -0.1 - 0.22 * f, -long), 0.34, Vector3(side * 0.04, 0.16, 0.0), face, 2 if lite else 3, 3)
		if not lite and (k == 1 or k == 3):
			for s2 in [-1.0, 1.0]:
				var r2 := root + Vector3(s2 * 0.12, -0.12, 0.02)
				_tuft(b, r2, r2 + Vector3(s2 * 0.18, -0.34, -long * 0.75), 0.2, Vector3(s2 * 0.05, 0.06, 0.0), Vector3(s2, 0.5, 0).normalized(), 1, 3)
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
	# Mane flowing back from the skull and down the nape, and a beard under the chin:
	# tufts of soft locks, cream into gold fire, falling with gravity (head frame: +z back
	# up the skull, +y over the brow).
	_part(b, NECK, NECK_PIVOT, 1.0)
	b.emit = 0.22
	var manes := 4 if lite else 6
	for k in manes:
		var a := lerpf(-0.45, PI + 0.45, float(k) / float(manes - 1))
		var out := Vector3(cos(a), sin(a), 0)
		var long := 1.5 + 0.4 * float(k % 3)
		var root := Vector3(out.x * 0.4, out.y * 0.36 + 0.1, 1.5)
		var tip := Vector3(out.x * 0.9, out.y * 0.2 - 1.05, 1.7 + long)
		_tuft(b, root, tip, 0.55, Vector3(out.x * 0.12, 0.42, 0.0), Vector3(out.x, out.y + 0.6, -0.3).normalized(), 2, 3)
	for k in 3:
		var root := Vector3(0.12 * (k - 1), -0.4, 0.95)
		_lock(b, root, Vector3(0.26 * (k - 1), -1.2 - 0.15 * float(k % 2), 1.7), 0.36, Vector3(0, 0, 0.15), Vector3(0, -0.3, -1).normalized(), 3, float(k))
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
	var n := 4 if lite else 5
	for k in n:
		var a := TAU * float(k) / float(n)
		var out := Vector3(cos(a), 0, sin(a))
		var dir := out * 0.16 + Vector3(0, -0.62, -0.12)
		_lock(b, end + out * 0.04, end + dir * (1.0 - 0.12 * float(k % 2)), 0.2, out * 0.07 + Vector3(0, 0, -0.06), out, 3, a)
	b.emit = 0.0
