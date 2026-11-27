class_name RamakienSculpt
extends RefCounted
## The sculptures of RamakienArt, built once per kind (procedural, no textures) and lit by
## the RamakienSpirit shader (shaders/ramakien_spirit.gdshader): real volume (lathes,
## sculpted heads, tubes with rounded ends, extruded gold plates), smooth normals, and the
## vertex data the shader paints them with (COLOR: tone, mask, material, glow; UV: pattern
## or face coordinates; UV2.x: pattern). The giants stand in unit height (the crown's
## spire or the raised trident at y = 1, the waist at 0), facing +Z, ready to be scaled
## to 12-18 m:
##   hanuman         the white monkey warrior, jade-white in a khon jacket of gold ลาย,
##                   ชฎายอด, กรรเจียก, อินทรธนู, raising the ตรีเพชร in one hand, the other in จีบ
##   thotsakan       ทศกัณฐ์: ten heads as the khon mask stacks them (the main face, a
##                   ring of five at the crown's foot, three above, a เทวดา under the spire),
##                   two front arms (a raised fist and จีบ)
##   thotsakan_arms  its eighteen other arms, fanned round the shoulders like a halo, with
##                   gold armlets and bracelets, holding swords, discs, tridents, clubs, or
##                   clenched (origin at their pivot behind the shoulders)
##   spirit_fist     a clenched fist with its gold bracelet, knuckles along +X, the thumb's
##                   side and the knuckle ridge to +Z, the forearm tapering into light
##   trident         the gold ตรีเพชร, along +X (prongs at +X), x from -1 to 1
## and the ★500 หมัดบรมครูเทวะ's (HeavenlyMasterFist, combat/god_art/heavenly_master_fist.gd):
##   master_deva     บรมครูเทวะ: a serene warm-white deity boxer, bare-chested under gold
##                   sak yant line work, the มงคล on his brow (red cloth wound with gold,
##                   its tail rising behind), a flame crest over the topknot, red
##                   ประเจียด on both arms with their tails flying, hands pressed in ไหว้ครู
##   ruean_kaew      ซุ้มเรือนแก้ว: the gold arch of flame tongues standing behind him
##   devalai         เทวาลัย: the temple ring on the ground (unit radius): gold rims, a
##                   ring of กนก flames laid on the floor, eight lotus pillars with flame
##                   finials, red ประเจียด cloth swagged between them
##   deva_fist       his colossal wrapped fist, knuckles along +X, a ประเจียด on the
##                   forearm, fading into light
## and the light's cards (RamakienLight shader): quad, shaft, disc, trail, embers, veil.

const SKIN := 0.0
const GOLD := 0.25
const RED := 0.5
const INK := 0.75
const PEARL := 1.0
const P_NONE := 0
const P_LAI := 1
const P_HANUMAN := 2
const P_YAK := 3
const P_DEVA := 4
const P_ENGRAVE := 5
## Where the halo arms of ทศกัณฐ์ turn from (model units).
const ARM_PIVOT := Vector3(0, 0.335, -0.05)

static var _st: SurfaceTool
static var _xf := Transform3D.IDENTITY
static var _glow := 0.0
static var _mask := 1.0
## A tone (COLOR.r) multiplier for what is emitted now: crevices are drawn deeper.
static var _tone := 1.0
## Lean detail for the many small pieces (the eighteen halo arms): fewer sides, no caps
## where an end is buried.
static var _lean := false


static func build(kind: String) -> ArrayMesh:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_xf = Transform3D.IDENTITY
	_glow = 0.0
	_mask = 1.0
	_tone = 1.0
	_lean = false
	var aabb := AABB()
	match kind:
		"hanuman":
			# Built mirrored: his raised trident on the viewer's right (he rises on the
			# fighter's left, the side away from a target ahead, so it rises over the field).
			_xf = Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
			_hanuman()
		"thotsakan": _thotsakan()
		"thotsakan_arms": _thotsakan_arms()
		"spirit_fist": _spirit_fist()
		"trident": _trident()
		"master_deva": _master_deva()
		"ruean_kaew": _ruean_kaew()
		"devalai": _devalai()
		"deva_fist": _deva_fist()
		"quad": _card(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
		"shaft": _card(Vector2(-0.5, 0.0), Vector2(0.5, 1.0))
		"trail": _card(Vector2(-1.0, -0.5), Vector2(0.0, 0.5))
		"bank": _card(Vector2(-1.0, 0.0), Vector2(1.0, 1.0))
		"disc": _disc()
		"embers":
			_embers(56)
			aabb = AABB(Vector3(-1.4, -0.4, -1.4), Vector3(2.8, 2.6, 2.8))
		"veil":
			_card(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
			aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_st.index()
	var mesh := _st.commit()
	_st = null
	if aabb.size != Vector3.ZERO:
		mesh.custom_aabb = aabb
	return mesh


# ---------------------------------------------------------------------------
# Emitting
# ---------------------------------------------------------------------------

## One triangle; wound so its face looks along its normals (Godot: clockwise in front).
static func _tri(pa: Vector3, pb: Vector3, pc: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, mat: float, pat: int, ta := 1.0, tb := 1.0, tc := 1.0) -> void:
	var a := _xf * pa
	var b := _xf * pb
	var c := _xf * pc
	var wa := (_xf.basis * na).normalized()
	var wb := (_xf.basis * nb).normalized()
	var wc := (_xf.basis * nc).normalized()
	var g := (b - a).cross(c - a)
	if g.length_squared() < 1e-14:
		return
	if g.dot(wa + wb + wc) > 0.0:
		_emit(a, wa, ua, mat, pat, ta)
		_emit(c, wc, uc, mat, pat, tc)
		_emit(b, wb, ub, mat, pat, tb)
	else:
		_emit(a, wa, ua, mat, pat, ta)
		_emit(b, wb, ub, mat, pat, tb)
		_emit(c, wc, uc, mat, pat, tc)


static func _emit(p: Vector3, n: Vector3, uv: Vector2, mat: float, pat: int, tone: float) -> void:
	_st.set_color(Color(tone * _tone, _mask, mat, _glow))
	_st.set_normal(n)
	_st.set_uv(uv)
	_st.set_uv2(Vector2(float(pat), 0.0))
	_st.add_vertex(p)


## A grid surface: rows (bottom to top) of points (round the shape). seam: the last
## point of each row repeats the first (a closed shape with a UV seam); normals come
## from the neighbours (so displaced, sculpted surfaces shade right).
static func _grid(rows: Array, uvs: Array, mat: float, pat: int, seam: bool, tones: Array = [], outward := 1.0) -> void:
	var m := rows.size()
	var n := (rows[0] as PackedVector3Array).size()
	var normals: Array = []
	for j in m:
		var row: PackedVector3Array = rows[j]
		var down: PackedVector3Array = rows[maxi(j - 1, 0)]
		var up: PackedVector3Array = rows[mini(j + 1, m - 1)]
		var nr := PackedVector3Array()
		nr.resize(n)
		for i in n:
			var il := i - 1
			var ir := i + 1
			if seam:
				if il < 0:
					il = n - 2
				if ir > n - 1:
					ir = 1
			else:
				il = maxi(il, 0)
				ir = mini(ir, n - 1)
			var nn := (row[ir] - row[il]).cross(up[i] - down[i]) * outward
			nr[i] = nn
		normals.append(nr)
	# Poles (a ring shrunk to a point): borrow the next ring's normals.
	for j in m:
		var nr: PackedVector3Array = normals[j]
		for i in n:
			if nr[i].length_squared() < 1e-14:
				var k := j + 1 if j < m - 1 else j - 1
				var other: PackedVector3Array = normals[k]
				var row: PackedVector3Array = rows[j]
				var fallback := other[i]
				if fallback.length_squared() < 1e-14:
					fallback = row[i] - (rows[k] as PackedVector3Array)[i]
				nr[i] = fallback
			nr[i] = nr[i].normalized()
		normals[j] = nr
	for j in m - 1:
		var r0: PackedVector3Array = rows[j]
		var r1: PackedVector3Array = rows[j + 1]
		var n0: PackedVector3Array = normals[j]
		var n1: PackedVector3Array = normals[j + 1]
		var u0: PackedVector2Array = uvs[j]
		var u1: PackedVector2Array = uvs[j + 1]
		var t0 := 1.0 if tones.is_empty() else float(tones[j])
		var t1 := 1.0 if tones.is_empty() else float(tones[j + 1])
		for i in n - 1:
			_tri(r0[i], r1[i + 1], r0[i + 1], n0[i], n1[i + 1], n0[i + 1], u0[i], u1[i + 1], u0[i + 1], mat, pat, t0, t1, t0)
			_tri(r0[i], r1[i], r1[i + 1], n0[i], n1[i], n1[i + 1], u0[i], u1[i], u1[i + 1], mat, pat, t0, t1, t1)


## A surface of revolution round the Y axis through [param c]: profile [r, y] from bottom
## to top, the cross-section squashed to an ellipse (depth [param depth] of the width).
static func _lathe(profile: Array, c: Vector3, sides: int, depth: float, mat: float, pat: int, tones: Array = []) -> void:
	var rows: Array = []
	var uvs: Array = []
	for j in profile.size():
		var pr: Array = profile[j]
		var r := float(pr[0])
		var y := float(pr[1])
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in sides + 1:
			var a := -PI + TAU * float(i) / float(sides)
			row.append(c + Vector3(sin(a) * r, y, cos(a) * r * depth))
			uv.append(Vector2(a * r, y))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, mat, pat, true, tones)


## An ellipsoid (or superellipsoid, [param power] > 2 squarer) at [param c].
static func _ellipsoid(c: Vector3, r: Vector3, mat: float, pat: int, rings := 8, seg := 12, power := 2.0) -> void:
	var rows: Array = []
	var uvs: Array = []
	for j in rings + 1:
		var phi := PI * float(j) / float(rings) - PI * 0.5
		var cy := cos(phi)
		var sy := sin(phi)
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in seg + 1:
			var a := -PI + TAU * float(i) / float(seg)
			var e := 2.0 / power
			var xz := signf(cy) * pow(absf(cy), e)
			var p := Vector3(signf(sin(a)) * pow(absf(sin(a)), e) * xz * r.x, signf(sy) * pow(absf(sy), e) * r.y, signf(cos(a)) * pow(absf(cos(a)), e) * xz * r.z)
			row.append(c + p)
			uv.append(Vector2(a * r.x, p.y + c.y))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, mat, pat, true)


## A tube through [param pts] (radius per point), its ends rounded.
static func _tube(pts: Array, radii: Array, sides: int, mat: float, pat: int, caps := true) -> void:
	var path: Array = pts.duplicate()
	var rad: Array = radii.duplicate()
	if caps:
		var t0 := ((pts[0] as Vector3) - (pts[1] as Vector3)).normalized()
		var t1 := ((pts[pts.size() - 1] as Vector3) - (pts[pts.size() - 2] as Vector3)).normalized()
		var r0 := float(radii[0])
		var r1 := float(radii[radii.size() - 1])
		for k in [0.55, 0.85, 1.0]:
			path.push_front((pts[0] as Vector3) + t0 * r0 * k * 0.9)
			rad.push_front(r0 * sqrt(maxf(1.0 - k * k, 0.0)))
			path.push_back((pts[pts.size() - 1] as Vector3) + t1 * r1 * k * 0.9)
			rad.push_back(r1 * sqrt(maxf(1.0 - k * k, 0.0)))
	var rows: Array = []
	var uvs: Array = []
	var u := Vector3.ZERO
	var along := 0.0
	for j in path.size():
		var p: Vector3 = path[j]
		var a: Vector3 = path[maxi(j - 1, 0)]
		var b: Vector3 = path[mini(j + 1, path.size() - 1)]
		var t := (b - a).normalized()
		if j == 0:
			var helper := Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
			u = t.cross(helper).normalized()
		else:
			u = (u - t * u.dot(t)).normalized()
			along += p.distance_to(path[j - 1])
		var v := t.cross(u)
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		var r := float(rad[j])
		for i in sides + 1:
			var th := TAU * float(i) / float(sides)
			row.append(p + (u * cos(th) + v * sin(th)) * r)
			uv.append(Vector2(th * maxf(r, 0.004), along))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, mat, pat, true)


## A ring round the local Y axis (an armlet, a bracelet, a crown band).
static func _torus(c: Vector3, axis: Vector3, big: float, small: float, mat: float, pat: int, nu := 14, nv := 6) -> void:
	var y := axis.normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	var z := x.cross(y)
	var rows: Array = []
	var uvs: Array = []
	for j in nv + 1:
		var b := TAU * float(j) / float(nv)
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in nu + 1:
			var a := TAU * float(i) / float(nu)
			var d := x * cos(a) + z * sin(a)
			row.append(c + d * (big + small * cos(b)) + y * small * sin(b))
			uv.append(Vector2(a * big, b * small))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, mat, pat, true, [], -1.0)


## A flat plate (extruded polygon in the local XY plane, [param thick] deep).
static func _plate(poly: PackedVector2Array, thick: float, mat: float, pat: int) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		return
	var h := thick * 0.5
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var b := poly[idx[k + 1]]
		var c := poly[idx[k + 2]]
		_tri(Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(c.x, c.y, h), Vector3.BACK, Vector3.BACK, Vector3.BACK, a, b, c, mat, pat)
		_tri(Vector3(a.x, a.y, -h), Vector3(b.x, b.y, -h), Vector3(c.x, c.y, -h), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, a, b, c, mat, pat)
	# The rim: normals out of the edge (the polygon's winding decides "out").
	var area := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		area += p.x * q.y - q.x * p.y
	var sgn := 1.0 if area > 0.0 else -1.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var d := (q - p).normalized()
		var out := Vector3(d.y, -d.x, 0.0) * sgn
		_tri(Vector3(p.x, p.y, h), Vector3(q.x, q.y, h), Vector3(q.x, q.y, -h), out, out, out, p, q, q, mat, pat, 0.8, 0.8, 0.8)
		_tri(Vector3(p.x, p.y, h), Vector3(q.x, q.y, -h), Vector3(p.x, p.y, -h), out, out, out, p, q, p, mat, pat, 0.8, 0.8, 0.8)


## A frame at [param origin] whose Y runs along [param y] and Z leans to [param z_hint].
static func _frame(origin: Vector3, y: Vector3, z_hint := Vector3.BACK) -> Transform3D:
	var yy := y.normalized()
	var zz := (z_hint - yy * z_hint.dot(yy))
	if zz.length_squared() < 1e-6:
		zz = Vector3.RIGHT.cross(yy)
	zz = zz.normalized()
	var xx := yy.cross(zz)
	return Transform3D(Basis(xx, yy, zz), origin)


## Points of a smooth curve through [param ctrl] (Catmull-Rom), [param per] per span.
static func _spline(ctrl: Array, per := 4) -> Array:
	var out: Array = []
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector3 = ctrl[maxi(i - 1, 0)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out


static func _lerp_list(values: Array, count: int) -> Array:
	var out: Array = []
	for k in count:
		var t := float(k) / float(maxi(count - 1, 1)) * float(values.size() - 1)
		var i := mini(int(t), values.size() - 2)
		out.append(lerpf(float(values[i]), float(values[i + 1]), t - float(i)))
	return out


# ---------------------------------------------------------------------------
# Heads: a sculpted ellipsoid whose front carries the mask's coordinates (UV -1..1)
# ---------------------------------------------------------------------------

## A head at [param c] facing +Z of the current frame. style: "monkey" (a muzzle),
## "yak" (bulging eyes, heavy brow, a broad nose), "deva" (smooth, serene).
static func _head(c: Vector3, r: Vector3, pat: int, style: String, rings := 14, seg := 20) -> void:
	var rows: Array = []
	var uvs: Array = []
	for j in rings + 1:
		var phi := PI * float(j) / float(rings) - PI * 0.5
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in seg + 1:
			var a := -PI + TAU * float(i) / float(seg)
			var d := Vector3(sin(a) * cos(phi), sin(phi), cos(a) * cos(phi))
			var fx := d.x
			var fy := d.y
			var front := clampf(d.z * 1.6, 0.0, 1.0)
			var bump := 0.0
			var ex := absf(fx)
			match style:
				"monkey":
					bump += 0.22 * exp(-pow(fx / 0.5, 2.0) - pow((fy + 0.48) / 0.36, 2.0))
					bump += 0.07 * exp(-pow((fy - 0.3) / 0.1, 2.0)) * smoothstep(0.85, 0.3, ex)
					bump += 0.06 * exp(-(pow(ex - 0.33, 2.0) + pow(fy - 0.15, 2.0)) / 0.012)
					bump += 0.05 * exp(-(pow(fx, 2.0) + pow(fy + 0.08, 2.0)) / 0.01)
				"yak":
					bump += 0.1 * exp(-pow((fy - 0.33) / 0.11, 2.0)) * smoothstep(0.9, 0.3, ex)
					bump += 0.11 * exp(-(pow(ex - 0.33, 2.0) + pow(fy - 0.17, 2.0)) / 0.016)
					bump += 0.1 * exp(-(pow(fx / 1.4, 2.0) + pow(fy + 0.12, 2.0)) / 0.012)
					bump += 0.08 * exp(-pow(fx / 0.55, 2.0) - pow((fy + 0.5) / 0.25, 2.0))
					bump += 0.04 * exp(-(pow(ex - 0.5, 2.0) + pow(fy + 0.1, 2.0)) / 0.03)
				"deva":
					bump += 0.04 * exp(-(pow(fx, 2.0) + pow(fy + 0.05, 2.0)) / 0.01)
			var p := Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * (1.0 + bump * front)
			row.append(c + p)
			# The mask's frame in front; behind, x runs on past +-1 (no features there).
			var mx := fx if d.z >= 0.0 else signf(fx) * (2.0 - absf(fx))
			uv.append(Vector2(mx, fy))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, SKIN, pat, true)


# ---------------------------------------------------------------------------
# Ornament
# ---------------------------------------------------------------------------

## A flame (กนก) outline: a leaf that curls over at its tip, [param lean] to the side.
static func _flame_poly(width: float, height: float, lean: float, curl := 0.25, n := 10) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in n + 1:
		var t := float(k) / float(n)
		var half := width * 0.5 * pow(sin(PI * minf(t * 0.92 + 0.08, 1.0)), 0.8) * (1.0 - t * 0.35)
		var x := lean * height * t * t + curl * height * pow(t, 4.0)
		var y := height * t
		left.append(Vector2(x - half, y))
		right.append(Vector2(x + half, y))
	var out := PackedVector2Array()
	for p in right:
		out.append(p)
	var tip := Vector2(lean * height + curl * height * 1.35, height * 1.06)
	out.append(tip)
	for k in range(left.size() - 1, -1, -1):
		out.append(left[k])
	return out


## กรรเจียก: the flame-shaped ear ornament, rising up and back from the ear.
static func _kanchiak(at: Vector3, side: float, size: float) -> void:
	var keep := _xf
	_xf = keep * Transform3D(Basis(Vector3.UP, side * 1.15) * Basis(Vector3.BACK, -side * 0.35), at)
	_plate(_flame_poly(size * 0.5, size, 0.15 * side, -0.22 * side), size * 0.08, GOLD, P_ENGRAVE)
	_glow = 0.6
	_ellipsoid(Vector3(0.0, size * 0.22, size * 0.05), Vector3.ONE * size * 0.09, RED, P_NONE, 4, 6)
	_glow = 0.0
	_xf = keep


## อินทรธนู: the shoulder flame, curving up and out over each shoulder.
static func _intharathanu(at: Vector3, side: float, size: float) -> void:
	var keep := _xf
	_xf = keep * Transform3D(Basis(Vector3.BACK, -side * 0.75) * Basis(Vector3.UP, side * 0.35), at)
	_plate(_flame_poly(size * 0.42, size, 0.05 * side, 0.3 * side, 12), size * 0.07, GOLD, P_ENGRAVE)
	_xf = keep


## กรองคอ: a broad jewelled collar, a flared cone ending in lotus-petal pendants.
static func _collar(y_top: float, r_top: float, y_bottom: float, r_bottom: float, depth: float, petals: int) -> void:
	var rows: Array = []
	var uvs: Array = []
	var sides := petals * 4
	for j in 5:
		var t := float(j) / 4.0
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in sides + 1:
			var a := -PI + TAU * float(i) / float(sides)
			var pet := pow(absf(cos(a * float(petals) * 0.5)), 0.7)
			var y := lerpf(y_top, y_bottom - 0.028 * pet, t)
			var r := lerpf(r_top, r_bottom + 0.004 * pet, t) + 0.006 * sin(t * PI)
			row.append(Vector3(sin(a) * r, y, cos(a) * r * depth + 0.004))
			uv.append(Vector2(a * r, y))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, GOLD, P_ENGRAVE, true, [], -1.0)
	# Red gems round the collar.
	_glow = 0.7
	for k in 7:
		var a := -0.95 + 1.9 * float(k) / 6.0
		var r := lerpf(r_top, r_bottom, 0.55)
		var y := lerpf(y_top, y_bottom, 0.55)
		_ellipsoid(Vector3(sin(a) * r, y, cos(a) * r * depth + 0.012), Vector3.ONE * 0.008, RED, P_NONE, 4, 6)
	_glow = 0.0


## ทับทรวง: the chest pendant, a gold diamond round a red gem.
static func _pendant(at: Vector3, size: float) -> void:
	var keep := _xf
	_xf = keep * Transform3D(Basis(), at)
	var dia := PackedVector2Array([Vector2(0, size), Vector2(size * 0.75, 0), Vector2(0, -size * 1.15), Vector2(-size * 0.75, 0)])
	_plate(dia, size * 0.25, GOLD, P_ENGRAVE)
	_glow = 0.8
	_ellipsoid(Vector3(0, -size * 0.05, size * 0.14), Vector3(size * 0.32, size * 0.42, size * 0.18), RED, P_NONE, 4, 8)
	_glow = 0.0
	_xf = keep


## สังวาล: a gold chain across the chest, laid on the torso's surface.
static func _sash(from: Vector2, to: Vector2, profile: Array, depth: float, front: float) -> void:
	var pts: Array = []
	var radii: Array = []
	for k in 11:
		var t := float(k) / 10.0
		var p := from.lerp(to, t)
		var rx := _profile_r(profile, p.y)
		var rz := rx * depth
		var z := rz * sqrt(maxf(1.0 - pow(p.x / maxf(rx, 0.001), 2.0), 0.0)) + front
		pts.append(Vector3(p.x, p.y, z))
		radii.append(0.0065)
	_tube(pts, radii, 6, GOLD, P_ENGRAVE)


static func _profile_r(profile: Array, y: float) -> float:
	for k in profile.size() - 1:
		var a: Array = profile[k]
		var b: Array = profile[k + 1]
		if y >= float(a[1]) and y <= float(b[1]):
			return lerpf(float(a[0]), float(b[0]), (y - float(a[1])) / maxf(float(b[1]) - float(a[1]), 0.0001))
	return float((profile[0] if y < float((profile[0] as Array)[1]) else profile[profile.size() - 1])[0])


## A torso: the lathe of [param profile] ([r, y]), flattened to [param depth], with the
## chest's muscle pushed forward.
static func _torso(profile: Array, depth: float, chest_y: float, chest: float) -> void:
	var rows: Array = []
	var uvs: Array = []
	var sides := 26
	for pr: Array in profile:
		var r := float(pr[0])
		var y := float(pr[1])
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		for i in sides + 1:
			var a := -PI + TAU * float(i) / float(sides)
			var x := sin(a) * r
			var z := cos(a) * r * depth
			var pec := chest * exp(-pow((absf(x) - r * 0.42) / (r * 0.38), 2.0) - pow((y - chest_y) / 0.045, 2.0)) * maxf(cos(a), 0.0)
			var abs_ := chest * 0.35 * exp(-pow(x / (r * 0.35), 2.0) - pow((y - chest_y + 0.11) / 0.06, 2.0)) * maxf(cos(a), 0.0)
			row.append(Vector3(x, y, z + pec + abs_))
			uv.append(Vector2(a * r, y))
		rows.append(row)
		uvs.append(uv)
	_grid(rows, uvs, SKIN, P_LAI, true)


## An arm from shoulder to wrist through the elbow, a gold armlet (พาหุรัด) and bracelet (ทองกร).
static func _arm(shoulder: Vector3, elbow: Vector3, wrist: Vector3, thick: float, sides := 10, pat := P_LAI) -> void:
	var upper := shoulder.lerp(elbow, 0.5) + (elbow - shoulder).cross(Vector3.BACK).normalized() * thick * 0.1
	var fore := elbow.lerp(wrist, 0.4)
	var pts := _spline([shoulder, upper, elbow, fore, wrist], 3)
	var radii := _lerp_list([thick * 1.2, thick * 1.12, thick * 0.74, thick * 0.9, thick * 0.6], pts.size())
	_tube(pts, radii, sides, SKIN, pat, not _lean)
	var band := shoulder.lerp(elbow, 0.62)
	_torus(band, elbow - shoulder, thick * 0.95, thick * 0.22, GOLD, P_ENGRAVE, 10 if _lean else 12, 4 if _lean else 5)
	_flame_on(band, elbow - shoulder, thick)
	_torus(wrist.lerp(elbow, 0.1), wrist - elbow, thick * 0.72, thick * 0.18, GOLD, P_ENGRAVE, 10 if _lean else 12, 4 if _lean else 5)


## A small gold flame standing out of an armlet.
static func _flame_on(at: Vector3, along: Vector3, thick: float) -> void:
	var keep := _xf
	_xf = keep * _frame(at + Vector3.BACK * thick * 0.9, along, Vector3.BACK)
	_plate(_flame_poly(thick * 0.9, thick * 1.6, 0.0, 0.2), thick * 0.25, GOLD, P_ENGRAVE)
	_xf = keep


## A clenched fist in the frame whose Y runs out of the wrist, Z the back of the hand:
## the palm, four fingers rolled into it (their knuckles a row of ridges), the thumb
## locked across them.
static func _fist(size: float) -> void:
	_ellipsoid(Vector3(0, size * 0.42, -size * 0.04), Vector3(size * 0.7, size * 0.6, size * 0.46), SKIN, P_NONE, 5 if _lean else 6, 8 if _lean else 10, 3.0 if _lean else 2.4)
	for k in 4:
		var x := (float(k) - 1.5) * size * 0.34
		var l := 1.0 - 0.07 * absf(float(k) - 1.2)
		var pts := [Vector3(x, size * 0.82, size * 0.2), Vector3(x, size * 1.12 * l, size * 0.1), Vector3(x, size * 1.14 * l, -size * 0.22), Vector3(x, size * 0.9, -size * 0.42)]
		if _lean:
			_tube(pts, [size * 0.19, size * 0.185, size * 0.17, size * 0.15], 5, SKIN, P_NONE, false)
			continue
		# A full-size fist (a spirit fist, a giant's hand): each finger its own rounded roll,
		# shaded deeper where it tucks into the palm (the gaps between them read as lines),
		# and a knuckle standing up on the back of the hand: a ridge of four bumps that
		# keeps the fist a fist even end-on.
		_tone = 0.82
		_tube(pts, [size * 0.17, size * 0.2, size * 0.18, size * 0.14], 8, SKIN, P_NONE)
		_tone = 1.0
		_ellipsoid(Vector3(x, size * 1.04 * l, size * 0.17), Vector3(size * 0.15, size * 0.13, size * 0.14), SKIN, P_NONE, 5, 8)
	# The thumb, thick and locked across the fingers' middle joints, a gold thumb ring
	# (it reads against the jade from any side).
	var t0 := Vector3(size * 0.7, size * 0.28, -size * 0.12)
	var t1 := Vector3(size * 0.64, size * 0.72, -size * 0.48)
	var t2 := Vector3(size * 0.08, size * 0.86, -size * 0.6)
	_tube([t0, t1, t2], [size * 0.24, size * 0.21, size * 0.17] if not _lean else [size * 0.22, size * 0.19, size * 0.16], 5 if _lean else 8, SKIN, P_NONE)
	if not _lean:
		_torus(t1.lerp(t2, 0.35), t2 - t1, size * 0.2, size * 0.05, GOLD, P_ENGRAVE, 10, 4)


## จีบ: thumb and forefinger meeting in a ring, the other three fingers fanned up and
## bent back (the khon hand), in the frame whose Y runs out of the wrist, Z the palm.
static func _jeeb(size: float) -> void:
	_ellipsoid(Vector3(0, size * 0.5, 0), Vector3(size * 0.62, size * 0.62, size * 0.24), SKIN, P_NONE, 5, 10)
	for k in 3:
		var x := -size * (0.42 - 0.26 * float(k))
		var spread := -0.1 * float(k)
		var base := Vector3(x, size * 1.05, 0)
		var pts := [base, base + Vector3(spread * size, size * 0.42, -size * 0.06), base + Vector3(spread * size * 1.6, size * 0.78, -size * 0.28), base + Vector3(spread * size * 2.0, size * 1.0, -size * 0.6)]
		_tube(pts, [size * 0.15, size * 0.14, size * 0.12, size * 0.1], 6, SKIN, P_NONE)
	var meet := Vector3(size * 0.62, size * 1.25, size * 0.32)
	_tube([Vector3(size * 0.45, size * 1.0, 0), Vector3(size * 0.62, size * 1.42, size * 0.12), meet], [size * 0.15, size * 0.13, size * 0.1], 6, SKIN, P_NONE)
	_tube([Vector3(size * 0.55, size * 0.25, size * 0.1), Vector3(size * 0.85, size * 0.8, size * 0.3), meet], [size * 0.18, size * 0.15, size * 0.1], 6, SKIN, P_NONE)


# ---------------------------------------------------------------------------
# Weapons (in the frame of the hand: Y out of the fist)
# ---------------------------------------------------------------------------

static func _sword(length: float) -> void:
	# Hilt down through the fist, a flame-curled guard, a long leaf blade up.
	_tube([Vector3(0, -length * 0.12, 0), Vector3(0, length * 0.16, 0)], [length * 0.03, length * 0.03], 6, GOLD, P_ENGRAVE)
	var guard := PackedVector2Array([Vector2(-length * 0.13, 0.0), Vector2(-length * 0.16, length * 0.05), Vector2(0, length * 0.03), Vector2(length * 0.16, length * 0.05), Vector2(length * 0.13, 0.0), Vector2(0, -length * 0.02)])
	var keep := _xf
	_xf = keep * Transform3D(Basis(), Vector3(0, length * 0.16, 0))
	_plate(guard, length * 0.03, GOLD, P_ENGRAVE)
	var blade := PackedVector2Array([Vector2(-length * 0.045, 0.0), Vector2(-length * 0.06, length * 0.4), Vector2(-length * 0.035, length * 0.68), Vector2(0, length * 0.82), Vector2(length * 0.035, length * 0.68), Vector2(length * 0.06, length * 0.4), Vector2(length * 0.045, 0.0)])
	_glow = 0.5
	_plate(blade, length * 0.018, PEARL, P_NONE)
	_glow = 0.0
	_xf = keep


static func _chakra(radius: float) -> void:
	# จักร: a gold disc ringed with flame points.
	var keep := _xf
	_xf = keep * Transform3D(Basis(), Vector3(0, radius * 1.1, 0))
	_torus(Vector3.ZERO, Vector3.BACK, radius, radius * 0.16, GOLD, P_ENGRAVE, 12 if _lean else 16, 4 if _lean else 5)
	var star := PackedVector2Array()
	for k in 24:
		var a := TAU * float(k) / 24.0
		var r := radius * (1.45 if k % 2 == 0 else 1.08)
		star.append(Vector2(cos(a), sin(a)) * r)
	_glow = 0.35
	_plate(star, radius * 0.1, GOLD, P_ENGRAVE)
	_glow = 0.0
	_ellipsoid(Vector3.ZERO, Vector3(radius * 0.35, radius * 0.35, radius * 0.2), RED, P_NONE, 4, 8)
	_xf = keep


static func _small_trident(length: float) -> void:
	_tube([Vector3(0, -length * 0.25, 0), Vector3(0, length * 0.7, 0)], [length * 0.025, length * 0.022], 6, GOLD, P_ENGRAVE)
	var keep := _xf
	_xf = keep * Transform3D(Basis(), Vector3(0, length * 0.68, 0))
	_prongs(length * 0.35)
	_xf = keep


static func _club(length: float) -> void:
	_tube([Vector3(0, -length * 0.15, 0), Vector3(0, length * 0.55, 0)], [length * 0.03, length * 0.035], 6, GOLD, P_ENGRAVE)
	var prof: Array = []
	for k in 9:
		var t := float(k) / 8.0
		prof.append([length * (0.02 + 0.1 * sin(PI * t) * (1.0 + 0.15 * cos(t * 18.0))), length * (0.55 + 0.4 * t)])
	prof.append([0.0, length * 0.97])
	_lathe(prof, Vector3.ZERO, 10, 1.0, GOLD, P_ENGRAVE)


## A side prong of a ตรีเพชร: a crescent sweeping out from the shaft and up to a point.
static func _hook_poly(side: float, h: float) -> PackedVector2Array:
	var p0 := Vector2(side * h * 0.04, h * 0.02)
	var p1 := Vector2(side * h * 0.46, h * 0.16)
	var p2 := Vector2(side * h * 0.26, h * 0.8)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		var p := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var d := (p1 - p0).lerp(p2 - p1, t).normalized()
		var n := Vector2(-d.y, d.x)
		var wdt := h * (0.05 * (1.0 - t) + 0.006)
		left.append(p + n * wdt)
		right.append(p - n * wdt)
	var out := PackedVector2Array()
	for p in left:
		out.append(p)
	for k in range(right.size() - 1, -1, -1):
		out.append(right[k])
	return out


## The three prongs of a ตรีเพชร in the local frame (Y up, height [param h]).
static func _prongs(h: float) -> void:
	var centre := PackedVector2Array([Vector2(-h * 0.09, 0), Vector2(-h * 0.13, h * 0.45), Vector2(-h * 0.05, h * 0.85), Vector2(0, h * 1.0), Vector2(h * 0.05, h * 0.85), Vector2(h * 0.13, h * 0.45), Vector2(h * 0.09, 0)])
	_glow = 0.45
	_plate(centre, h * 0.06, GOLD, P_ENGRAVE)
	for side in [-1.0, 1.0]:
		_plate(_hook_poly(side, h), h * 0.05, GOLD, P_ENGRAVE)
	_glow = 0.0
	# The crescent guard under the prongs and a red gem.
	var guard := PackedVector2Array()
	for k in 13:
		var a := PI * float(k) / 12.0
		guard.append(Vector2(-cos(a) * h * 0.3, -sin(a) * h * 0.1 + h * 0.04))
	for k in range(12, -1, -1):
		var a := PI * float(k) / 12.0
		guard.append(Vector2(-cos(a) * h * 0.24, -sin(a) * h * 0.16 - h * 0.02))
	_plate(guard, h * 0.07, GOLD, P_ENGRAVE)
	_glow = 0.8
	_ellipsoid(Vector3(0, -h * 0.02, h * 0.04), Vector3(h * 0.05, h * 0.06, h * 0.03), RED, P_NONE, 4, 6)
	_glow = 0.0


# ---------------------------------------------------------------------------
# Crowns
# ---------------------------------------------------------------------------

## ชฎา: the jewelled band (กระบังหน้า) round the brow, its front peak, gems.
static func _brow_band(y: float, r: float, depth: float, height: float) -> void:
	_lathe([[r * 0.98, y], [r * 1.04, y + height * 0.2], [r * 1.05, y + height * 0.8], [r * 1.0, y + height]], Vector3.ZERO, 22, depth, GOLD, P_ENGRAVE, [0.8, 1.0, 1.0, 0.8])
	var keep := _xf
	_xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, y + height * 0.55, r * depth * 1.02))
	var peak := PackedVector2Array([Vector2(-r * 0.62, -height * 0.5), Vector2(-r * 0.5, height * 0.3), Vector2(-r * 0.2, height * 0.55), Vector2(0, height * 1.5), Vector2(r * 0.2, height * 0.55), Vector2(r * 0.5, height * 0.3), Vector2(r * 0.62, -height * 0.5)])
	_plate(peak, r * 0.06, GOLD, P_ENGRAVE)
	_glow = 0.8
	_ellipsoid(Vector3(0, height * 0.25, r * 0.05), Vector3(r * 0.13, r * 0.16, r * 0.08), RED, P_NONE, 4, 8)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * r * 0.34, height * 0.05, r * 0.04), Vector3.ONE * r * 0.07, RED, P_NONE, 4, 6)
	_glow = 0.0
	_xf = keep


## The spire of a ชฎายอด: tapering tiers of rings (ทรงเครื่อง), a lotus bud, a fine tip.
static func _spire(y0: float, r0: float, y1: float, tiers: int, tip: float) -> Array:
	var prof: Array = []
	var span := (y1 - y0) / float(tiers)
	for k in tiers:
		var t := float(k) / float(tiers)
		var r := r0 * (1.0 - 0.72 * t)
		var y := y0 + span * float(k)
		prof.append([r * 1.0, y])
		prof.append([r * 1.1, y + span * 0.28])
		prof.append([r * 0.98, y + span * 0.55])
		prof.append([r * 0.86, y + span * 0.85])
	# The lotus bud (ยอดเกี้ยว) and the needle.
	var rb := r0 * 0.24
	prof.append([rb * 1.2, y1 + 0.01])
	prof.append([rb * 1.6, y1 + 0.03])
	prof.append([rb * 1.0, y1 + 0.055])
	prof.append([rb * 0.55, y1 + 0.075])
	prof.append([rb * 0.7, y1 + 0.085])
	prof.append([rb * 0.35, y1 + 0.1])
	prof.append([rb * 0.2, tip - 0.035])
	prof.append([rb * 0.35, tip - 0.025])
	prof.append([0.0012, tip - 0.004])
	prof.append([0.0, tip])
	return prof


# ---------------------------------------------------------------------------
# The figures
# ---------------------------------------------------------------------------

const HANUMAN_BODY := [[0.1, -0.06], [0.1, 0.0], [0.104, 0.06], [0.116, 0.13], [0.134, 0.2], [0.146, 0.26], [0.148, 0.3], [0.136, 0.33], [0.1, 0.355], [0.06, 0.37], [0.04, 0.385], [0.037, 0.42], [0.03, 0.44]]
const YAK_BODY := [[0.112, -0.06], [0.112, 0.0], [0.116, 0.06], [0.128, 0.13], [0.148, 0.2], [0.16, 0.26], [0.162, 0.3], [0.15, 0.335], [0.11, 0.36], [0.066, 0.378], [0.046, 0.39], [0.043, 0.425], [0.035, 0.45]]


static func _hanuman() -> void:
	_torso(HANUMAN_BODY, 0.62, 0.262, 0.024)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.152, 0.312, 0.0), Vector3(0.054, 0.054, 0.05), SKIN, P_LAI, 7, 12)
	_collar(0.376, 0.052, 0.305, 0.165, 0.64, 14)
	_pendant(Vector3(0, 0.25, 0.102), 0.028)
	_sash(Vector2(0.12, 0.31), Vector2(-0.1, 0.04), HANUMAN_BODY, 0.62, 0.004)
	_sash(Vector2(-0.12, 0.31), Vector2(0.1, 0.04), HANUMAN_BODY, 0.62, 0.009)
	_lathe([[0.104, 0.05], [0.108, 0.065], [0.108, 0.085], [0.104, 0.1]], Vector3.ZERO, 24, 0.66, GOLD, P_ENGRAVE)
	for side in [-1.0, 1.0]:
		_intharathanu(Vector3(side * 0.17, 0.345, -0.005), side, 0.1)
	# The raised arm (model -X) with the ตรีเพชร held high; the other in จีบ before the chest.
	var s1 := Vector3(-0.152, 0.315, 0.0)
	var e1 := Vector3(-0.29, 0.405, 0.04)
	var w1 := Vector3(-0.255, 0.56, 0.07)
	_arm(s1, e1, w1, 0.04)
	var keep := _xf
	_xf = keep * _frame(w1, w1 - e1, Vector3(0.3, 0, 1))
	_fist(0.04)
	_xf = keep
	var grip := w1 + (w1 - e1).normalized() * 0.035 + Vector3(0, 0, 0.022)
	_tube([Vector3(grip.x, 0.36, grip.z), Vector3(grip.x, 0.86, grip.z)], [0.0075, 0.0068], 8, GOLD, P_ENGRAVE)
	for y in [0.48, 0.66, 0.83]:
		_ellipsoid(Vector3(grip.x, y, grip.z), Vector3(0.013, 0.01, 0.013), GOLD, P_ENGRAVE, 4, 8)
	_xf = keep * Transform3D(Basis(Vector3.UP, 0.25), Vector3(grip.x, 0.855, grip.z))
	_prongs(0.15)
	_xf = keep
	var s2 := Vector3(0.152, 0.315, 0.0)
	var e2 := Vector3(0.248, 0.2, 0.06)
	var w2 := Vector3(0.14, 0.248, 0.15)
	_arm(s2, e2, w2, 0.032)
	_xf = keep * _frame(w2, Vector3(0.15, 1, 0.2), Vector3(0.3, -0.1, 1))
	_jeeb(0.034)
	_xf = keep
	# The head: a white monkey mask, กรรเจียก at the ears, the ชฎายอด.
	_lathe([[0.04, 0.4], [0.042, 0.43], [0.04, 0.45]], Vector3(0, 0, 0.004), 14, 0.9, SKIN, P_NONE)
	_head(Vector3(0, 0.472, 0.016), Vector3(0.064, 0.072, 0.062), P_HANUMAN, "monkey")
	for side in [-1.0, 1.0]:
		_kanchiak(Vector3(side * 0.06, 0.478, -0.006), side, 0.085)
	_brow_band(0.522, 0.066, 0.98, 0.034)
	var crown := [[0.066, 0.552], [0.062, 0.566], [0.056, 0.578]]
	crown.append_array(_spire(0.58, 0.054, 0.71, 5, 0.86))
	_lathe(crown, Vector3(0, 0, -0.002), 18, 1.0, GOLD, P_ENGRAVE)


static func _thotsakan() -> void:
	_torso(YAK_BODY, 0.6, 0.265, 0.03)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.165, 0.318, 0.0), Vector3(0.06, 0.058, 0.054), SKIN, P_LAI, 7, 12)
	_collar(0.385, 0.058, 0.31, 0.18, 0.62, 16)
	_pendant(Vector3(0, 0.252, 0.112), 0.032)
	_sash(Vector2(0.13, 0.315), Vector2(-0.11, 0.04), YAK_BODY, 0.6, 0.004)
	_sash(Vector2(-0.13, 0.315), Vector2(0.11, 0.04), YAK_BODY, 0.6, 0.009)
	_lathe([[0.116, 0.05], [0.12, 0.065], [0.12, 0.085], [0.116, 0.1]], Vector3.ZERO, 24, 0.64, GOLD, P_ENGRAVE)
	for side in [-1.0, 1.0]:
		_intharathanu(Vector3(side * 0.185, 0.352, -0.005), side, 0.11)
	# Front arms: a fist raised to strike (model -X), จีบ before the chest.
	var keep := _xf
	var s1 := Vector3(-0.165, 0.318, 0.0)
	var e1 := Vector3(-0.285, 0.235, 0.06)
	var w1 := Vector3(-0.265, 0.37, 0.12)
	_arm(s1, e1, w1, 0.037)
	_xf = keep * _frame(w1, w1 - e1, Vector3(0.0, -0.2, 1))
	_fist(0.04)
	_xf = keep
	var s2 := Vector3(0.165, 0.318, 0.0)
	var e2 := Vector3(0.262, 0.2, 0.065)
	var w2 := Vector3(0.148, 0.245, 0.16)
	_arm(s2, e2, w2, 0.035)
	_xf = keep * _frame(w2, Vector3(0.15, 1, 0.2), Vector3(0.3, -0.1, 1))
	_jeeb(0.037)
	_xf = keep
	# Ten heads. The main face, its ears' กรรเจียก and brow band.
	_lathe([[0.046, 0.41], [0.048, 0.44], [0.044, 0.46]], Vector3(0, 0, 0.004), 14, 0.9, SKIN, P_NONE)
	_head(Vector3(0, 0.49, 0.016), Vector3(0.07, 0.078, 0.066), P_YAK, "yak")
	for side in [-1.0, 1.0]:
		_kanchiak(Vector3(side * 0.066, 0.494, -0.006), side, 0.09)
	_brow_band(0.543, 0.072, 0.97, 0.036)
	# The crown's core behind the faces, then the spire.
	var core := [[0.07, 0.575], [0.06, 0.6], [0.05, 0.64], [0.044, 0.665], [0.042, 0.672], [0.036, 0.71], [0.03, 0.735], [0.028, 0.745]]
	core.append_array(_spire(0.75, 0.026, 0.84, 3, 1.0))
	_lathe(core, Vector3(0, 0, -0.004), 18, 1.0, GOLD, P_ENGRAVE)
	# A ring of five faces at the crown's foot, three above, a เทวดา under the spire.
	for k in 5:
		var a: float = [0.0, 1.2, -1.2, 2.45, -2.45][k]
		_crown_face(Vector3(0, 0.618, -0.004), a, 0.05, Vector3(0.031, 0.034, 0.028), P_YAK)
	for k in 3:
		var a: float = [0.0, 2.1, -2.1][k]
		_crown_face(Vector3(0, 0.692, -0.004), a, 0.034, Vector3(0.024, 0.027, 0.022), P_YAK)
	_crown_face(Vector3(0, 0.762, -0.004), 0.0, 0.022, Vector3(0.019, 0.022, 0.017), P_DEVA)


## A face of the crown's ring at [param yaw] round the crown, [param out] from its axis,
## with its own little band and a flame over it.
static func _crown_face(centre: Vector3, yaw: float, out: float, r: Vector3, pat: int) -> void:
	var keep := _xf
	_xf = keep * Transform3D(Basis(Vector3.UP, yaw), centre) * Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(0, 0, out))
	_head(Vector3.ZERO, r, pat, "deva" if pat == P_DEVA else "yak", 10, 14)
	_lathe([[r.x * 1.0, r.y * 0.55], [r.x * 1.08, r.y * 0.7], [r.x * 1.06, r.y * 0.95], [r.x * 0.9, r.y * 1.05]], Vector3(0, 0, -r.z * 0.1), 12, 0.95, GOLD, P_ENGRAVE)
	_xf = _xf * Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, r.y * 0.95, r.z * 0.55))
	_plate(_flame_poly(r.x * 0.9, r.y * 0.9, 0.0, 0.0, 6), r.x * 0.12, GOLD, P_ENGRAVE)
	_xf = keep


## The halo arms of ทศกัณฐ์, round [constant ARM_PIVOT] (the mesh's origin): each upper
## arm leaves the shoulders on its own ray and bends at the elbow by its own angle (most
## turn up towards the crown, a few swing out or reach towards the viewer), so from any
## side they read as arms, not rods: muscled upper arms tapering to thin wrists, flared
## gold armlets with flame wings, and hands that hold swords, discs, tridents, clubs or
## make the จีบ; the rays alternate in depth and overlap.
const HALO_HOLDS := [1, 2, 3, 0, 4, 1, 3, 2, 5]
## Per arm (shoulder to crown-side): elbow bend (degrees, + towards the crown), forearm
## reach towards the viewer, forearm length, depth behind the shoulders.
const HALO_BEND := [48.0, 72.0, 30.0, 60.0, -18.0, 66.0, 38.0, -28.0, 54.0]
const HALO_REACH := [0.1, 0.42, -0.22, 0.3, 0.55, -0.18, 0.26, 0.62, -0.08]
const HALO_FORE := [0.12, 0.1, 0.14, 0.11, 0.13, 0.095, 0.135, 0.115, 0.125]
const HALO_DEPTH := [0.0, 0.05, 0.015, 0.06, 0.0, 0.045, 0.02, 0.065, 0.01]


static func _thotsakan_arms() -> void:
	_lean = true
	for side in [-1.0, 1.0]:
		for k in 9:
			# The left and right fans differ a little (the same arm is not mirrored).
			var j := k if side < 0.0 else (k + 4) % 9
			var t := float(k) / 8.0
			var deg := lerpf(30.0, 146.0, t) + (4.0 if side > 0.0 else -3.0) * sin(float(k) * 2.3)
			var theta := deg_to_rad(deg)
			var phi := deg_to_rad(deg - float(HALO_BEND[j]))
			var dir := Vector3(sin(theta) * side, cos(theta), 0.0)
			var fdir := Vector3(sin(phi) * side, cos(phi), float(HALO_REACH[j])).normalized()
			var back := -0.012 - float(HALO_DEPTH[j]) - 0.015 * t
			var upper := 0.125 + 0.03 * sin(PI * t)
			var shoulder := dir * 0.055 + Vector3(0, -0.01, back)
			var elbow := dir * (0.055 + upper) + Vector3(0, 0, back + 0.012)
			var wrist := elbow + fdir * float(HALO_FORE[j])
			var thick := 0.02 - 0.0035 * t
			_halo_arm(shoulder, elbow, wrist, thick, dir, k % 2 == 0)
			var keep := _xf
			_xf = keep * _frame(wrist, wrist - elbow, Vector3.BACK + Vector3(side * 0.3, 0, 0))
			var hold: int = HALO_HOLDS[j]
			if hold == 0:
				_jeeb(thick * 1.25)
			else:
				_fist(thick * 1.25)
				_xf = _xf * Transform3D(Basis(), Vector3(0, thick * 0.55, -thick * 0.15))
				match hold:
					1: _sword(0.27)
					2: _chakra(0.05)
					3: _small_trident(0.26)
					4: _club(0.2)
			_xf = keep
	_lean = false


## One halo arm: a muscled upper arm, the elbow's turn, a forearm thinning to the wrist; a
## flared gold armlet (พาหุรัด) with a flame wing standing out to the side ([param out]),
## a second flame on every other arm, and a bracelet (ทองกร).
static func _halo_arm(shoulder: Vector3, elbow: Vector3, wrist: Vector3, thick: float, out: Vector3, double: bool) -> void:
	var bend_n := (elbow - shoulder).cross(wrist - elbow)
	var bulge := (elbow - shoulder).cross(bend_n).normalized() if bend_n.length_squared() > 1e-10 else Vector3.ZERO
	var biceps := shoulder.lerp(elbow, 0.45) - bulge * thick * 0.25
	var fore := elbow.lerp(wrist, 0.3)
	var pts := _spline([shoulder, biceps, elbow, fore, wrist], 3)
	var radii := _lerp_list([thick * 1.2, thick * 1.38, thick * 0.78, thick * 0.98, thick * 0.5], pts.size())
	_tube(pts, radii, 7, SKIN, P_NONE, false)
	# The elbow's point, so the bend reads even edge-on.
	_ellipsoid(elbow - bulge * thick * 0.1, Vector3.ONE * thick * 0.78, SKIN, P_NONE, 4, 6)
	var band := shoulder.lerp(elbow, 0.6)
	var along := elbow - shoulder
	_torus(band, along, thick * 1.12, thick * 0.3, GOLD, P_ENGRAVE, 10, 4)
	_torus(band + along.normalized() * thick * 0.5, along, thick * 1.0, thick * 0.16, GOLD, P_ENGRAVE, 10, 3)
	var keep := _xf
	var wing := (out * 0.7 + along.normalized() * 0.5 + Vector3.BACK * 0.2).normalized()
	_xf = keep * _frame(band, wing, Vector3.BACK)
	_plate(_flame_poly(thick * 1.3, thick * 2.6, 0.12, 0.3, 7), thick * 0.25, GOLD, P_ENGRAVE)
	if double:
		_xf = keep * _frame(band, (wing - out * 0.9).normalized(), Vector3.BACK)
		_plate(_flame_poly(thick * 0.9, thick * 1.8, -0.15, -0.25, 6), thick * 0.22, GOLD, P_ENGRAVE)
	_xf = keep
	_torus(wrist.lerp(elbow, 0.12), wrist - elbow, thick * 0.78, thick * 0.22, GOLD, P_ENGRAVE, 10, 4)


static func _spirit_fist() -> void:
	# Built with Y out of the wrist, then laid along +X (knuckles first) with the thumb's
	# side to +Z and turned 46 degrees on the travel axis, the back of the hand towards
	# the camera too (the layer keeps +Z to the camera): the knuckle ridge, the rolled
	# fingers and the thumb locked over them all show, never a flat side.
	_xf = Transform3D(Basis(Vector3.RIGHT, 0.8) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO)
	_fist(0.5)
	_torus(Vector3(0, -0.04, 0), Vector3.UP, 0.34, 0.075, GOLD, P_ENGRAVE, 16, 6)
	var pts := [Vector3(0, 0.08, 0), Vector3(0, -0.06, 0), Vector3(0, -0.16, 0), Vector3(0, -0.26, 0), Vector3(0, -0.36, 0), Vector3(0, -0.46, 0), Vector3(0, -0.56, 0)]
	var radii := [0.31, 0.29, 0.27, 0.24, 0.2, 0.15, 0.09]
	# The wrist thins and tapers into light (COLOR.g falls along it, step by step, so no
	# hard rim where the forearm ends).
	var masks := [1.0, 0.72, 0.46, 0.26, 0.12, 0.04]
	for k in 6:
		_mask = float(masks[k])
		_tube([pts[k], pts[k + 1]], [radii[k], radii[k + 1]], 10, SKIN, P_LAI, false)
	_mask = 1.0
	_xf = Transform3D.IDENTITY


static func _trident() -> void:
	# Along +X: the shaft from -1, the prongs out to +1, its face to +Z.
	_xf = Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO)
	_glow = 0.25
	_tube([Vector3(0, -1.0, 0), Vector3(0, 0.36, 0)], [0.05, 0.045], 8, GOLD, P_ENGRAVE)
	for y in [-0.9, -0.3, 0.16, 0.32]:
		_ellipsoid(Vector3(0, y, 0), Vector3(0.085, 0.06, 0.085), GOLD, P_ENGRAVE, 4, 8)
	_glow = 0.0
	_xf = _xf * Transform3D(Basis(), Vector3(0, 0.36, 0))
	_prongs(0.66)
	_xf = Transform3D.IDENTITY


# ---------------------------------------------------------------------------
# The light's cards
# ---------------------------------------------------------------------------

static func _card(lo: Vector2, hi: Vector2) -> void:
	var a := Vector3(lo.x, lo.y, 0)
	var b := Vector3(hi.x, lo.y, 0)
	var c := Vector3(hi.x, hi.y, 0)
	var d := Vector3(lo.x, hi.y, 0)
	_tri(a, c, b, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), 0.0, 0)
	_tri(a, d, c, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), 0.0, 0)


## A ground card (XZ, -1..1, facing up).
static func _disc() -> void:
	var a := Vector3(-1, 0, 1)
	var b := Vector3(1, 0, 1)
	var c := Vector3(1, 0, -1)
	var d := Vector3(-1, 0, -1)
	_tri(a, c, b, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), 0.0, 0)
	_tri(a, d, c, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), 0.0, 0)


## Embers: tiny quads collapsed on their centres (the shader spreads and moves them).
static func _embers(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in n:
		var p := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(-1.0, 1.0) * 0.6)
		var phase := rng.randf()
		var speed := rng.randf()
		var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for i in tri:
				_st.set_color(Color(1, 1, 0, 0))
				_st.set_normal(Vector3.BACK)
				_st.set_uv(corners[i])
				_st.set_uv2(Vector2(phase, speed))
				_st.add_vertex(p)


# ---------------------------------------------------------------------------
# ★500 หมัดบรมครูเทวะ: the master deity, his arch, his temple ring and his fist
# ---------------------------------------------------------------------------

const DEVA_BODY := [[0.1, -0.06], [0.1, 0.0], [0.104, 0.06], [0.118, 0.13], [0.138, 0.2], [0.152, 0.26], [0.155, 0.3], [0.142, 0.333], [0.104, 0.357], [0.062, 0.372], [0.041, 0.386], [0.038, 0.42], [0.031, 0.44]]


## A strip of cloth through [param pts] ([param widths] across, laid across
## [param across] as far as the path allows), seen from both sides.
static func _cloth(pts: Array, widths: Array, across: Vector3, mat: float, pat := P_NONE) -> void:
	var rows: Array = []
	var uvs: Array = []
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var t := ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var a := across - t * t.dot(across)
		a = a.normalized() if a.length_squared() > 1e-8 else t.cross(Vector3.BACK).normalized()
		var w := float(widths[i]) * 0.5
		rows.append(PackedVector3Array([p - a * w, p + a * w]))
		uvs.append(PackedVector2Array([Vector2(0.0, float(i)), Vector2(1.0, float(i))]))
	_grid(rows, uvs, mat, pat, false)
	_grid(rows, uvs, mat, pat, false, [], -1.0)


## A ประเจียด round a limb at [param at] (the limb runs along [param along]): a thick roll
## of red cloth bound by two gold threads, its knot on the [param out] side and two tails
## flying from it ([param fly]: where they stream).
static func _prajiad(at: Vector3, along: Vector3, r: float, out: Vector3, fly: Vector3, tail := 3.2) -> void:
	var ax := along.normalized()
	_torus(at, ax, r, r * 0.32, RED, P_NONE, 14, 6)
	for k in [-1.0, 1.0]:
		_torus(at + ax * r * 0.3 * k, ax, r * 1.02, r * 0.09, GOLD, P_ENGRAVE, 12, 4)
	var side := (out - ax * ax.dot(out)).normalized()
	var knot := at + side * r * 1.2
	_ellipsoid(knot, Vector3.ONE * r * 0.36, RED, P_NONE, 5, 8)
	var f := fly.normalized()
	var bend := f.cross(Vector3.BACK)
	bend = bend.normalized() if bend.length_squared() > 1e-6 else Vector3.UP
	for k in 2:
		var dir := (f + bend * (0.35 if k == 0 else -0.3)).normalized()
		var pts: Array = []
		var widths: Array = []
		for j in 7:
			var t := float(j) / 6.0
			pts.append(knot + dir * r * tail * t + bend * sin(t * PI * 1.6 + float(k)) * r * 0.35 * t)
			widths.append(r * (0.62 - 0.38 * t))
		var across := dir.cross(Vector3.BACK)
		_cloth(pts, widths, across if across.length_squared() > 1e-4 else Vector3.UP, RED)
		_glow = 0.5
		_ellipsoid(pts[6], Vector3.ONE * r * 0.14, GOLD, P_NONE, 4, 6)
		_glow = 0.0


## An arm of the master from shoulder to wrist: sak yant line work, a ประเจียด on the
## upper arm, rope wraps (คาดเชือก) and a gold bracelet at the wrist.
static func _deva_arm(s: Vector3, e: Vector3, w: Vector3, thick: float, side: float) -> void:
	var upper := s.lerp(e, 0.5) + Vector3(side * thick * 0.28, 0, -thick * 0.1)
	var fore := e.lerp(w, 0.38) + Vector3(side * thick * 0.12, -thick * 0.08, 0)
	var pts := _spline([s, upper, e, fore, w], 3)
	var radii := _lerp_list([thick * 1.24, thick * 1.2, thick * 0.8, thick * 0.95, thick * 0.62], pts.size())
	_tube(pts, radii, 12, SKIN, P_LAI)
	_ellipsoid(e + Vector3(side * thick * 0.1, -thick * 0.2, -thick * 0.1), Vector3.ONE * thick * 0.82, SKIN, P_LAI, 5, 8)
	_prajiad(s.lerp(e, 0.5), e - s, thick * 1.22, Vector3(side, 0.15, 0.3), Vector3(side * 0.85, 0.25, -0.25))
	var fw := w - e
	_torus(w.lerp(e, 0.06), fw, thick * 0.66, thick * 0.14, GOLD, P_ENGRAVE, 12, 5)
	for k in 3:
		_torus(w.lerp(e, 0.16 + 0.085 * float(k)), fw, thick * (0.72 + 0.05 * float(k)), thick * 0.11, PEARL, P_NONE, 12, 4)


## Two hands pressed together in ไหว้ครู, in the frame whose Y runs up the fingers and
## Z out of the knuckles' side (the thumbs towards the viewer).
static func _wai_hands(size: float) -> void:
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * size * 0.42, size * 1.45, -size * 0.05), Vector3(size * 0.38, size * 1.5, size * 1.0), SKIN, P_NONE, 6, 10, 2.6)
		_ellipsoid(Vector3(side * size * 0.36, size * 3.45, -size * 0.12), Vector3(size * 0.32, size * 1.4, size * 0.86), SKIN, P_NONE, 6, 10, 2.3)
		_tone = 0.85
		_tube([Vector3(side * size * 0.6, size * 0.45, size * 0.7), Vector3(side * size * 0.55, size * 1.5, size * 1.02), Vector3(side * size * 0.34, size * 2.35, size * 0.98)], [size * 0.34, size * 0.3, size * 0.24], 8, SKIN, P_NONE)
		_tone = 1.0
	# A gold glint between the palms (the master's blessing).
	_glow = 1.0
	_ellipsoid(Vector3(0, size * 4.9, -size * 0.1), Vector3(size * 0.22, size * 0.42, size * 0.22), GOLD, P_NONE, 4, 6)
	_glow = 0.0


## มงคล: a ring of red cloth wound with a gold thread round the brow, a gold ยันต์ plate
## at the front, its tail rising up and back behind the head.
static func _mongkhon(c: Vector3, r: float, small: float) -> void:
	var y := Vector3(0, 1, -0.2).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(y)
	_torus(c, y, r, small, RED, P_NONE, 22, 7)
	var helix: Array = []
	var radii: Array = []
	for k in 97:
		var a := TAU * float(k) / 96.0
		var ph := a * 13.0
		var d := x * cos(a) + z * sin(a)
		helix.append(c + d * (r + small * 1.02 * cos(ph)) + y * small * 1.02 * sin(ph))
		radii.append(small * 0.28)
	_tube(helix, radii, 4, GOLD, P_ENGRAVE, false)
	# The front plate: a gold lotus bud round a glowing gem.
	var keep := _xf
	_xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.2), c + z * (r + small * 0.9) + y * small * 0.2)
	_plate(_flame_poly(small * 2.4, small * 3.0, 0.0, 0.0, 8), small * 0.4, GOLD, P_ENGRAVE)
	_glow = 0.9
	_ellipsoid(Vector3(0, small * 1.0, small * 0.25), Vector3.ONE * small * 0.45, RED, P_NONE, 4, 6)
	_glow = 0.0
	_xf = keep
	# The tail (หางมงคล): out of the back of the ring, up and back, bound in gold.
	var back := c - z * (r + small * 0.3)
	var tail := _spline([back, back + Vector3(0, 0.03, -0.035), back + Vector3(0, 0.09, -0.06), back + Vector3(0, 0.155, -0.052)], 4)
	var tr := _lerp_list([small * 1.05, small * 0.95, small * 0.72, small * 0.4], tail.size())
	_tube(tail, tr, 10, RED, P_NONE)
	for t in [0.25, 0.5, 0.75]:
		var i := int(t * float(tail.size() - 1))
		var along := (tail[mini(i + 1, tail.size() - 1)] as Vector3) - (tail[maxi(i - 1, 0)] as Vector3)
		_torus(tail[i], along, float(tr[i]) * 1.05, float(tr[i]) * 0.28, GOLD, P_ENGRAVE, 10, 4)
	_glow = 0.6
	_ellipsoid(tail[tail.size() - 1], Vector3.ONE * small * 0.55, GOLD, P_ENGRAVE, 5, 8)
	_glow = 0.0


## บรมครูเทวะ (unit height, the waist at 0, facing +Z).
static func _master_deva() -> void:
	_torso(DEVA_BODY, 0.6, 0.262, 0.03)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.158, 0.313, 0.0), Vector3(0.057, 0.057, 0.051), SKIN, P_LAI, 7, 12)
	_collar(0.378, 0.054, 0.312, 0.17, 0.62, 14)
	_sash(Vector2(0.125, 0.31), Vector2(-0.1, 0.04), DEVA_BODY, 0.6, 0.004)
	_lathe([[0.104, 0.05], [0.108, 0.065], [0.108, 0.085], [0.104, 0.1]], Vector3.ZERO, 24, 0.64, GOLD, P_ENGRAVE)
	for side in [-1.0, 1.0]:
		_deva_arm(Vector3(side * 0.158, 0.313, 0.0), Vector3(side * 0.212, 0.168, 0.088), Vector3(side * 0.03, 0.282, 0.2), 0.037, side)
	var keep := _xf
	_xf = keep * _frame(Vector3(0, 0.282, 0.205), Vector3(0, 1, 0.12), Vector3.BACK)
	_wai_hands(0.029)
	_xf = keep
	# The head: serene, hair combed back to a topknot under a flame (รัศมี), the มงคล.
	_lathe([[0.04, 0.4], [0.042, 0.43], [0.04, 0.45]], Vector3(0, 0, 0.004), 14, 0.9, SKIN, P_NONE)
	_head(Vector3(0, 0.475, 0.016), Vector3(0.063, 0.073, 0.061), P_DEVA, "deva")
	_ellipsoid(Vector3(0, 0.5, -0.012), Vector3(0.066, 0.064, 0.062), INK, P_NONE, 10, 16)
	for side in [-1.0, 1.0]:
		_glow = 0.4
		_ellipsoid(Vector3(side * 0.063, 0.447, 0.012), Vector3(0.008, 0.014, 0.008), GOLD, P_ENGRAVE, 4, 6)
		_glow = 0.0
	_mongkhon(Vector3(0, 0.513, 0.006), 0.066, 0.0125)
	_ellipsoid(Vector3(0, 0.567, -0.012), Vector3(0.028, 0.026, 0.028), INK, P_NONE, 6, 10)
	_torus(Vector3(0, 0.556, -0.012), Vector3.UP, 0.026, 0.006, GOLD, P_ENGRAVE, 12, 4)
	_xf = keep * Transform3D(Basis(), Vector3(0, 0.585, -0.012))
	_glow = 0.45
	_plate(_flame_poly(0.05, 0.12, 0.0, 0.18, 12), 0.012, GOLD, P_ENGRAVE)
	_glow = 0.0
	_xf = keep


## A point of [param curve] (Catmull-Rom points) [param t] of the way along, and its tangent.
static func _along(curve: Array, t: float) -> Array:
	var f := clampf(t, 0.0, 1.0) * float(curve.size() - 1)
	var i := mini(int(f), curve.size() - 2)
	var a: Vector3 = curve[i]
	var b: Vector3 = curve[i + 1]
	return [a.lerp(b, f - float(i)), (b - a).normalized()]


## ซุ้มเรือนแก้ว: a gold arch standing in the XY plane (feet at y 0.05, its finial at 1),
## a double rail edged outside with flame tongues, cushions at its shoulders.
static func _ruean_kaew() -> void:
	for side in [-1.0, 1.0]:
		var ctrl := [Vector3(side * 0.37, 0.02, 0), Vector3(side * 0.38, 0.36, 0), Vector3(side * 0.355, 0.6, 0), Vector3(side * 0.26, 0.77, 0), Vector3(side * 0.11, 0.88, 0), Vector3(0, 0.935, 0)]
		var curve := _spline(ctrl, 5)
		_tube(curve, _lerp_list([0.016, 0.015, 0.013, 0.011], curve.size()), 8, GOLD, P_ENGRAVE, false)
		var inner: Array = []
		for p: Vector3 in curve:
			inner.append(Vector3(p.x * 0.88, 0.02 + (p.y - 0.02) * 0.93, 0.004))
		_tube(inner, _lerp_list([0.008, 0.007], inner.size()), 6, GOLD, P_ENGRAVE, false)
		_glow = 0.25
		for k in 15:
			var t := 0.05 + 0.92 * float(k) / 14.0
			var at: Array = _along(curve, t)
			var tan: Vector3 = at[1]
			var out: Vector3 = Vector3(tan.y, -tan.x, 0) * side
			if out.dot(Vector3(side, 0.4, 0)) < 0.0:
				out = -out
			var keep := _xf
			var yaxis: Vector3 = (out + tan * 0.35 * side).normalized()
			_xf = keep * Transform3D(Basis(Vector3.BACK, atan2(-yaxis.x, yaxis.y)), (at[0] as Vector3) + out * 0.01)
			var big := 0.055 + 0.03 * float(k % 2) + 0.02 * t
			_plate(_flame_poly(big * 0.55, big, 0.12 * side, 0.25 * side, 8), 0.01, GOLD, P_ENGRAVE)
			_xf = keep
		_glow = 0.0
		_ellipsoid(Vector3(side * 0.36, 0.6, 0.0), Vector3(0.03, 0.026, 0.026), GOLD, P_ENGRAVE, 5, 8)
		_ellipsoid(Vector3(side * 0.37, 0.03, 0.0), Vector3(0.04, 0.03, 0.03), GOLD, P_ENGRAVE, 5, 8)
	# The finial: a tall flame over a lotus bud with a gem.
	var keep2 := _xf
	_xf = keep2 * Transform3D(Basis(), Vector3(0, 0.925, 0))
	_glow = 0.5
	_plate(_flame_poly(0.07, 0.085, 0.0, 0.1, 10), 0.014, GOLD, P_ENGRAVE)
	_glow = 0.9
	_ellipsoid(Vector3(0, 0.02, 0.01), Vector3(0.012, 0.016, 0.01), RED, P_NONE, 4, 6)
	_glow = 0.0
	_xf = keep2


## เทวาลัย: the temple ring laid round the master's field (unit radius, the floor at 0).
static func _devalai() -> void:
	_lathe([[0.935, 0.0], [0.945, 0.016], [1.0, 0.016], [1.012, 0.0]], Vector3.ZERO, 72, 1.0, GOLD, P_ENGRAVE)
	_lathe([[0.6, 0.0], [0.606, 0.008], [0.628, 0.008], [0.634, 0.0]], Vector3.ZERO, 56, 1.0, GOLD, P_ENGRAVE)
	# A ring of กนก flames laid on the floor, pointing out, leaning with the turn.
	var keep := _xf
	_glow = 0.2
	for k in 16:
		var a := TAU * float(k) / 16.0
		var radial := Vector3(sin(a), 0, cos(a))
		var tangent := Vector3(-cos(a), 0, sin(a))
		_xf = keep * Transform3D(Basis(tangent, radial, Vector3.UP), radial * 0.655 + Vector3.UP * 0.006)
		_plate(_flame_poly(0.075, 0.2, 0.12, 0.42, 12), 0.008, GOLD, P_ENGRAVE)
		# Its red heart (ลายกนก: gold round a red inlay).
		_xf = keep * Transform3D(Basis(tangent, radial, Vector3.UP), radial * 0.675 + Vector3.UP * 0.011)
		_glow = 0.35
		_plate(_flame_poly(0.036, 0.115, 0.12, 0.42, 10), 0.004, RED, P_NONE)
		_glow = 0.2
		# A small flame between each pair, at the outer rim.
		var b := a + TAU / 32.0
		var rb := Vector3(sin(b), 0, cos(b))
		_xf = keep * Transform3D(Basis(Vector3(-cos(b), 0, sin(b)), rb, Vector3.UP), rb * 0.84 + Vector3.UP * 0.006)
		_plate(_flame_poly(0.05, 0.085, 0.0, 0.2, 8), 0.006, GOLD, P_ENGRAVE)
	_glow = 0.0
	_xf = keep
	# Eight lotus pillars, each under a flame finial, red cloth swagged between them.
	var tops: Array = []
	for k in 8:
		var a := TAU * float(k) / 8.0 + TAU / 16.0
		var at := Vector3(sin(a), 0, cos(a)) * 0.968
		# A stepped base, a slim shaft, a lotus capital (บัวหัวเสา), a gem, a flame finial.
		_lathe([[0.03, 0.0], [0.03, 0.01], [0.024, 0.012], [0.024, 0.022], [0.017, 0.026]], at, 8, 1.0, GOLD, P_ENGRAVE)
		_lathe([[0.017, 0.026], [0.0145, 0.05], [0.0125, 0.2], [0.017, 0.206], [0.026, 0.214], [0.03, 0.222], [0.022, 0.228], [0.0, 0.23]], at, 10, 1.0, GOLD, P_ENGRAVE)
		for y in [0.06, 0.19]:
			_torus(at + Vector3.UP * y, Vector3.UP, 0.0145, 0.0035, GOLD, P_ENGRAVE, 10, 4)
		_glow = 0.8
		_ellipsoid(at + Vector3.UP * 0.234, Vector3.ONE * 0.008, RED, P_NONE, 4, 6)
		for j in 2:
			_xf = keep * Transform3D(Basis(Vector3.UP, a + PI * 0.5 * float(j)), at + Vector3.UP * 0.236)
			_glow = 0.55
			_plate(_flame_poly(0.042, 0.11, 0.0, 0.18, 10), 0.006, GOLD, P_ENGRAVE)
		_glow = 0.0
		_xf = keep
		tops.append(at + Vector3.UP * 0.19)
	for k in 8:
		var p0: Vector3 = tops[k]
		var p1: Vector3 = tops[(k + 1) % 8]
		var mid := (p0 + p1) * 0.5 * 1.004 + Vector3.DOWN * 0.05
		var swag := _spline([p0, p0.lerp(mid, 0.55) + Vector3.DOWN * 0.012, mid, p1.lerp(mid, 0.55) + Vector3.DOWN * 0.012, p1], 3)
		_tube(swag, _lerp_list([0.006, 0.008, 0.006], swag.size()), 6, RED, P_NONE, false)
		var thread: Array = []
		for p: Vector3 in swag:
			thread.append(p + Vector3.UP * 0.0075)
		_tube(thread, _lerp_list([0.0022, 0.0022], thread.size()), 4, GOLD, P_ENGRAVE, false)
		_glow = 0.4
		_ellipsoid(mid, Vector3.ONE * 0.007, GOLD, P_ENGRAVE, 4, 6)
		_glow = 0.0
		var hang := [mid, mid + Vector3.DOWN * 0.025 + mid.normalized() * 0.004, mid + Vector3.DOWN * 0.05 + mid.normalized() * 0.002]
		_cloth(hang, [0.01, 0.008, 0.004], mid.normalized().cross(Vector3.UP), RED)


## A forearm (or limb) running from [param a] to [param b], fading into light towards b.
static func _fading(a: Vector3, b: Vector3, r0: float, r1: float, sides := 10, pat := P_LAI) -> void:
	var masks := [1.0, 0.75, 0.48, 0.26, 0.11, 0.03]
	for k in 5:
		_mask = float(masks[k])
		var t0 := float(k) / 5.0
		var t1 := float(k + 1) / 5.0
		_tube([a.lerp(b, t0), a.lerp(b, t1)], [lerpf(r0, r1, t0), lerpf(r0, r1, t1)], sides, SKIN, pat, false)
	_mask = 1.0


## หมัดเทวะ: the master's wrapped fist, knuckles along +X like the spirit fist.
static func _deva_fist() -> void:
	_xf = Transform3D(Basis(Vector3.RIGHT, 0.8) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO)
	_fist(0.5)
	_torus(Vector3(0, -0.03, 0), Vector3.UP, 0.33, 0.06, GOLD, P_ENGRAVE, 16, 6)
	for k in 3:
		_torus(Vector3(0, -0.1 - 0.06 * float(k), 0), Vector3.UP, 0.3 - 0.01 * float(k), 0.035, PEARL, P_NONE, 16, 5)
	_tube([Vector3(0, 0.08, 0), Vector3(0, -0.2, 0)], [0.31, 0.27], 10, SKIN, P_NONE, false)
	_prajiad(Vector3(0, -0.28, 0), Vector3.UP, 0.27, Vector3(0, 0, -1), Vector3(0.2, -1.0, -0.3), 2.6)
	_fading(Vector3(0, -0.2, 0), Vector3(0, -0.62, 0), 0.27, 0.1)
	_xf = Transform3D.IDENTITY
