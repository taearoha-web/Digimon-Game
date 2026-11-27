class_name HeavenBird
extends RefCounted
## The winged Himmapan folk of ดินแดนเทวาลัย (HeavenMonsters "beast"), sculpted in code
## like the sky isle's kirin (Kirin) and eastern dragons:
##   kinnari  กินรี: the celestial dancer, a slender woman from the waist up (pale gold
##            skin, a red breast cloth edged in gold, a jewelled กรองคอ and ทับทรวง, armlets,
##            bracelets and long gold nails, jade sashes trailing from her wrists) under a
##            tall gold ชฎา with กรรเจียก, on the plump golden body of a swan with tucked
##            bird legs, a ห้อยหน้า of red and gold, a flame-curled fan of tail plumes and
##            white-gold wings. She floats; her arms dance in ตั้งวง and จีบ, and her right
##            hand unfurls a ribbon of light (the "beam").
##   garuda   ครุฑน้อยเทวาลัย: the young garuda warrior, red-feathered, big-headed under a
##            gold ชฎา, a hooked gold beak and round fierce eyes, a gold breastplate
##            (กรองคอ, ทับทรวง, crossed สังวาล, อินทรธนู flames over the shoulders), red and
##            gold ห้อยหน้า, feathered thighs on gold-scaled bird legs with black talons, a
##            short tail fan and great wings of gold, red and jade spread behind him. He
##            swoops on his prey talons first (the "pounce").
## One mesh per kind (vertex colours, built once; a lighter one at quality 0) and one
## shader (shaders/heaven_bird.gdshader, its pose in heaven_bird_pose.gdshaderinc) that
## poses it from a handful of scalars HeavenBirdVisual tweens: every vertex knows its part
## (body, torso, head, an arm, a forearm, a wing, a wing tip, a thigh, a shin, the tail, the
## ribbon) and the side it is on, so the wings beat, the arms dance, the legs walk and
## crouch, the head looks about and the sashes flutter. The ink outline is the material's
## next pass from quality 1 (heaven_bird_ink.gdshader). No textures, lights or particles;
## each bird on the field has its own small material (the Compatibility renderer has no
## per-instance uniforms). The ornament shapes (กนก flames) come from RamakienSculpt.
##
## Mesh metres: +Z is the front, the figure's left at +X, the feet at y = 0;
## HeavenBirdVisual scales a kind to the template's height ("height": the ชฎา's tip).

const K := preload("res://combat/god_art/_kit_arcane.gd")
const R := preload("res://combat/ramakien_sculpt.gd")
const SHADER := preload("res://shaders/heaven_bird.gdshader")
const INK := preload("res://shaders/heaven_bird_ink.gdshader")

## Parts (CUSTOM1.w; heaven_bird_pose.gdshaderinc).
const BODY := 0
const TORSO := 1
const HEAD := 2
const ARM := 3
const FORE := 4
const WING := 5
const WING_TIP := 6
const THIGH := 7
const SHIN := 8
const TAIL := 9
const RIBBON := 10
## Finishes (COLOR.a; heaven_bird.gdshader).
const PLAIN := 1.0
const SCALLOP := 0.875
const VANE := 0.75
const LAI := 0.5
const CLOTH := 0.25

const GOLD := Color("ffc93a")
const GOLD_LT := Color("ffe489")
const GOLD_DK := Color("c47d12")
const RED := Color("d22a36")
const RED_DK := Color("8e1426")
const JADE := Color("1fae8c")
const JADE_LT := Color("6fe6c4")
const WHITE := Color("fff6e2")
const INK_DARK := Color("2a1630")
const GEM := Color("ff3b4e")

## The kinds: the ชฎา's tip (height), the rest bounds grown for every move (box), the
## joints (the figure's left; mirrored), the rest pose (shader scalars), the wing.
const KINDS := {
	"kinnari": {
		"height": 2.8,
		"box": AABB(Vector3(-2.4, -0.7, -2.6), Vector3(4.8, 4.6, 9.4)),
		"joints": {"j_waist": Vector3(0, 1.2, 0.03), "j_neck": Vector3(0, 1.69, 0.0), "j_shoulder": Vector3(0.2, 1.585, 0.0),
			"j_elbow": Vector3(0.24, 1.33, 0.0), "j_hand": Vector3(0.262, 1.04, 0.025), "j_wing": Vector3(0.07, 1.5, -0.13),
			"j_wing_mid": Vector3(0.64, 1.86, -0.27), "j_hip": Vector3(0.12, 0.86, -0.02), "j_knee": Vector3(0.13, 0.52, 0.06),
			"j_foot": Vector3(0.13, 0.12, 0.0), "j_tail": Vector3(0, 0.96, -0.36), "j_center": Vector3(0, 1.3, 0)},
		"rest": {"la_swing": 0.25, "la_raise": 1.25, "la_bend": 1.55, "la_twist": 1.3, "ra_swing": 0.6, "ra_raise": 0.3, "ra_bend": 1.45, "ra_twist": -0.2,
			"leg_swing": -0.8, "leg_bend": 1.3, "talon": -0.5, "wing_raise": 0.12, "wing_sweep": 0.05, "dance": 1.0, "flap_amp": 0.16},
		"wing": {"root": Vector3(0.07, 1.5, -0.13), "mid": Vector3(0.64, 1.86, -0.27), "tip": Vector3(1.2, 2.08, -0.32)},
		"ribbon_len": 6.2,
		"head": Vector3(0, 1.89, 0.02),
	},
	"garuda": {
		"height": 2.56,
		"box": AABB(Vector3(-2.6, -0.6, -2.0), Vector3(5.2, 4.2, 5.4)),
		"joints": {"j_waist": Vector3(0, 0.98, 0.0), "j_neck": Vector3(0, 1.45, 0.02), "j_shoulder": Vector3(0.235, 1.36, 0.0),
			"j_elbow": Vector3(0.3, 1.13, 0.02), "j_hand": Vector3(0.33, 0.93, 0.04), "j_wing": Vector3(0.09, 1.3, -0.15),
			"j_wing_mid": Vector3(0.78, 1.72, -0.3), "j_hip": Vector3(0.14, 0.86, 0.0), "j_knee": Vector3(0.16, 0.5, 0.1),
			"j_foot": Vector3(0.16, 0.08, -0.02), "j_tail": Vector3(0, 0.9, -0.2), "j_center": Vector3(0, 1.1, 0)},
		"rest": {"la_swing": 0.45, "la_raise": 0.55, "la_bend": 1.75, "la_twist": 0.35, "ra_swing": 0.45, "ra_raise": 0.55, "ra_bend": 1.75, "ra_twist": 0.35,
			"crouch": 0.12, "wing_raise": 0.06, "wing_sweep": 0.0, "dance": 0.2, "flap_amp": 0.08},
		"wing": {"root": Vector3(0.09, 1.3, -0.15), "mid": Vector3(0.78, 1.72, -0.3), "tip": Vector3(1.52, 2.06, -0.34)},
		"ribbon_len": 0.0,
		"head": Vector3(0, 1.72, 0.06),
	},
}
## Every scalar a move tweens (rest at the kind's "rest", else 0).
const POSE_KEYS := ["bow", "twist", "sway", "head_pitch", "head_turn", "la_swing", "la_raise", "la_bend", "la_twist", "ra_swing", "ra_raise", "ra_bend", "ra_twist",
	"leg_swing", "leg_bend", "crouch", "talon", "tail_lift", "wing_raise", "wing_sweep", "wing_fold", "lift", "lunge", "dive", "roll", "ribbon", "charge", "fade", "dance"]

static var _meshes := {}
static var _bases := {}
static var _inks := {}
## The frame every piece is laid in (the mirror while the figure's right side is built).
static var _root := Transform3D.IDENTITY
const MIRROR := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)


static func has(kind: String) -> bool:
	return KINDS.has(kind)


static func spec(kind: String) -> Dictionary:
	return KINDS.get(kind, KINDS.kinnari)


## The value a pose scalar rests at for [param kind].
static func rest_value(kind: String, key: String) -> float:
	if key == "fade":
		return 1.0
	return float((spec(kind).rest as Dictionary).get(key, 0.0))


## The shared mesh of a kind (a lighter one at quality 0).
static func mesh(kind: String) -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	var key := "%s|%s" % [kind, lite]
	if not _meshes.has(key):
		var built := _build(kind, lite)
		built.custom_aabb = spec(kind).box
		_meshes[key] = built
	return _meshes[key]


static func _setup(m: ShaderMaterial, kind: String) -> void:
	var s := spec(kind)
	for key in s.joints:
		m.set_shader_parameter(key, s.joints[key])
	for key in s.rest:
		m.set_shader_parameter(key, s.rest[key])
	m.set_shader_parameter("ribbon_len", float(s.ribbon_len))


## A fresh material for one bird (its ink outline as the next pass from quality 1).
static func material(kind: String) -> ShaderMaterial:
	if not _bases.has(kind):
		var base := ShaderMaterial.new()
		base.shader = SHADER
		_setup(base, kind)
		if kind == "garuda":
			base.set_shader_parameter("shadow_tint", Color(0.78, 0.62, 0.7))
			base.set_shader_parameter("line_color", Color("7a2a0c"))
			base.set_shader_parameter("rim_color", Color("ffe2a0"))
		else:
			base.set_shader_parameter("shadow_tint", Color(0.82, 0.72, 0.8))
			base.set_shader_parameter("line_color", Color("9a5410"))
			base.set_shader_parameter("rim_color", Color("fff2c8"))
		_bases[kind] = base
		var ink := ShaderMaterial.new()
		ink.shader = INK
		_setup(ink, kind)
		ink.set_shader_parameter("color", Color("5a1c18") if kind == "garuda" else Color("6a3416"))
		_inks[kind] = ink
	var own := (_bases[kind] as ShaderMaterial).duplicate() as ShaderMaterial
	var q := VfxBudget.quality()
	own.set_shader_parameter("detail", 0.0 if q == 0 else 1.0)
	if q >= 1:
		own.next_pass = (_inks[kind] as ShaderMaterial).duplicate()
	return own


## A bird ready to place: the body at mesh scale (scale it yourself), its own material.
static func body(kind: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "HeavenBirdBody"
	mi.mesh = mesh(kind)
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 1.0
	return mi


static func triangles(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return n


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
static func _part(b: K.Builder, part: int, side := 0.0, flutter := 0.0, ink := true) -> void:
	b.customs = true
	b.tumble = float(part)
	b.pivot = Vector3(side, flutter, 1.0 if ink else 0.0)
	b.vel = Vector3.ZERO
	b.wait = 0.0


static func _c(col: Color, finish: float) -> Color:
	return Color(col.r, col.g, col.b, finish)


## Builds [param piece] (a Callable taking the builder and the side) for the figure's
## left, then mirrored for its right (the winding turned back so the ink still sees out).
static func _both(b: K.Builder, piece: Callable) -> void:
	_root = Transform3D.IDENTITY
	b.xf = _root
	piece.call(b, 1.0)
	var start := b.ix.size()
	_root = MIRROR
	b.xf = _root
	piece.call(b, -1.0)
	_root = Transform3D.IDENTITY
	b.xf = _root
	var i := start
	while i + 2 < b.ix.size():
		var keep := b.ix[i + 1]
		b.ix[i + 1] = b.ix[i + 2]
		b.ix[i + 2] = keep
		i += 3


## A feather, a plume or a flame tongue: a strip folded along its shaft (a shallow ridge
## so it catches the light), from root to tip with a bow ([param curl]) and a curled end
## ([param hook]), rounded at the root and pointed at the tip; UV = (across, along), its
## flutter share (CUSTOM0.x) growing to the tip.
static func _feather(b: K.Builder, root: Vector3, tip: Vector3, width: float, face: Vector3, c0: Color, c1: Color, segs := 3, curl := Vector3.ZERO, hook := Vector3.ZERO, finish := VANE) -> void:
	var d := tip - root
	var pts := []
	for k in segs + 1:
		var u := float(k) / float(segs)
		pts.append(root + d * u + curl * sin(u * PI) + hook * pow(u, 3.0))
	var prev := []
	for k in pts.size():
		var u := float(k) / float(segs)
		var tangent: Vector3 = (pts[mini(k + 1, segs)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(face).normalized()
		var up := across.cross(tangent).normalized()
		var w := width * 0.5 * pow(sin(PI * minf(u * 0.8 + 0.2, 1.0)), 0.55) * (1.0 - 0.2 * u)
		var col := _c(c0.lerp(c1, u), finish)
		b.vel = Vector3(u, 0, 0)
		var ring := [
			b.pt(pts[k] - across * w, (up * 0.5 - across).normalized(), col, Vector2(0.0, u)),
			b.pt(pts[k] + up * w * 0.2, up, col, Vector2(0.5, u)),
			b.pt(pts[k] + across * w, (up * 0.5 + across).normalized(), col, Vector2(1.0, u))]
		if not prev.is_empty():
			b.tri(prev[0], prev[1], ring[1]); b.tri(prev[0], ring[1], ring[0])
			b.tri(prev[1], prev[2], ring[2]); b.tri(prev[1], ring[2], ring[1])
		prev = ring
	b.vel = Vector3.ZERO


## A cloth strip through [param pts] (widths per point, flat across [param face]'s side),
## [param col] in the middle, [param edge] at its borders (a gold hem); UV = (across,
## along) and its flutter share growing along it.
static func _cloth(b: K.Builder, pts: Array, widths: Array, face: Vector3, col: Color, edge: Color, finish := CLOTH, emit := 0.0) -> void:
	var prev := []
	var n := pts.size()
	b.emit = emit
	for k in n:
		var u := float(k) / float(n - 1)
		var tangent: Vector3 = (pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var across := tangent.cross(face).normalized()
		var nor := across.cross(tangent).normalized()
		var w := float(widths[mini(k, widths.size() - 1)]) * 0.5
		b.vel = Vector3(u, 0, 0)
		var hem := _c(edge, LAI)
		var mid := _c(col, finish)
		var ring := [
			b.pt(pts[k] - across * w, nor, hem, Vector2(0.0, u)),
			b.pt(pts[k] - across * w * 0.7, nor, mid, Vector2(0.15, u)),
			b.pt(pts[k] + across * w * 0.7, nor, mid, Vector2(0.85, u)),
			b.pt(pts[k] + across * w, nor, hem, Vector2(1.0, u))]
		if not prev.is_empty():
			for j in 3:
				b.tri(prev[j], prev[j + 1], ring[j + 1]); b.tri(prev[j], ring[j + 1], ring[j])
		prev = ring
	b.vel = Vector3.ZERO
	b.emit = 0.0


## An extruded plate: [param poly] in its own XY plane (its face toward +Z) laid by
## [param local], [param thick] deep, [param col] at its heart shading to [param rim].
static func _plate(b: K.Builder, poly: PackedVector2Array, local: Transform3D, thick: float, col: Color, rim: Color, finish := LAI) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var centre := Vector2.ZERO
	var reach := 0.001
	for p in poly:
		centre += p
	centre /= float(poly.size())
	for p in poly:
		reach = maxf(reach, p.distance_to(centre))
	b.xf = _root * local
	for face: float in [1.0, -1.0]:
		var z := thick * 0.5 * face
		var nor := Vector3(0, 0, face)
		var ids := []
		for p in poly:
			var tone := _c(col.lerp(rim, clampf(p.distance_to(centre) / reach, 0.0, 1.0)), finish)
			ids.append(b.pt(Vector3(p.x, p.y, z), nor, tone, p))
		for t in range(0, tris.size(), 3):
			var a: int = ids[tris[t]]
			var c1: int = ids[tris[t + 1]]
			var c2: int = ids[tris[t + 2]]
			var pa := poly[tris[t]]
			var pb := poly[tris[t + 1]]
			var pc := poly[tris[t + 2]]
			var ccw := (pb - pa).cross(pc - pa) > 0.0
			if ccw == (face > 0.0):
				b.tri(a, c1, c2)
			else:
				b.tri(a, c2, c1)
	# The rim of the plate.
	var n := poly.size()
	var clockwise := 0.0
	for i in n:
		clockwise += poly[i].cross(poly[(i + 1) % n])
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		var tone := _c(rim, finish)
		var a := Vector3(p.x, p.y, -thick * 0.5)
		var c := Vector3(q.x, q.y, -thick * 0.5)
		if clockwise > 0.0:
			b.quad(a, c, c + Vector3(0, 0, thick), a + Vector3(0, 0, thick), tone)
		else:
			b.quad(c, a, a + Vector3(0, 0, thick), c + Vector3(0, 0, thick), tone)
	b.xf = _root


## A band round a limb or the waist (a short tube along y), [param r] across and deep.
static func _band(b: K.Builder, y0: float, y1: float, at: Vector3, r: Vector2, col: Color, sides: int, emit := 0.0) -> void:
	b.emit = emit
	b.tube([at + Vector3(0, y0, 0), at + Vector3(0, (y0 + y1) * 0.5, 0), at + Vector3(0, y1, 0)], [r * 0.97, r * 1.04, r * 0.97], sides, [[_c(col, LAI), _c(col.lerp(GOLD_DK, 0.35), LAI)]], Vector3.BACK)
	b.emit = 0.0


## The ชฎา over a head centred at [param c] (radius [param r]): the jewelled band and its
## front peak (กระบังหน้า) with a red gem, then the spire of tapering tiers (ทรงเครื่อง), a
## lotus bud and a fine needle up to [param tip].
static func _crown(b: K.Builder, c: Vector3, r: float, band_y: float, tip: float, tiers: int, lite: bool) -> void:
	var segs := 8 if lite else 12
	b.emit = 0.12
	b.xf = _root * Transform3D(Basis(), Vector3(c.x, 0, c.z))
	var h := r * 0.5
	b.lathe([[r * 0.86, band_y, _c(GOLD_DK, LAI)], [r * 0.97, band_y + h * 0.15, _c(GOLD, LAI)], [r * 0.99, band_y + h * 0.75, _c(GOLD_LT, LAI)], [r * 0.9, band_y + h, _c(GOLD, LAI)]], segs)
	var y0 := band_y + h
	var r0 := r * 0.84
	var y1 := lerpf(y0, tip, 0.62)
	var span := (y1 - y0) / float(tiers)
	var prof := [[r * 0.9, y0 - 0.005, _c(GOLD, LAI)]]
	for k in tiers:
		var t := float(k) / float(tiers)
		var rr := r0 * (1.0 - 0.68 * t)
		var y := y0 + span * float(k)
		prof.append([rr, y + span * 0.02, _c(GOLD_DK, LAI)])
		prof.append([rr * 1.12, y + span * 0.3, _c(GOLD_LT, LAI)])
		prof.append([rr * 0.98, y + span * 0.62, _c(GOLD, LAI)])
		prof.append([rr * 0.84, y + span * 0.92, _c(GOLD_DK, LAI)])
	var rb := r0 * 0.26
	var bud := tip - y1
	prof.append([rb * 1.35, y1 + bud * 0.02, _c(GOLD, LAI)])
	prof.append([rb * 1.75, y1 + bud * 0.12, _c(GOLD_LT, LAI)])
	prof.append([rb * 1.15, y1 + bud * 0.26, _c(GOLD, LAI)])
	prof.append([rb * 0.6, y1 + bud * 0.36, _c(GOLD_DK, LAI)])
	prof.append([rb * 0.78, y1 + bud * 0.42, _c(GOLD_LT, LAI)])
	prof.append([rb * 0.36, y1 + bud * 0.52, _c(GOLD, LAI)])
	prof.append([rb * 0.2, y1 + bud * 0.8, _c(GOLD, LAI)])
	prof.append([rb * 0.3, y1 + bud * 0.86, _c(GOLD_LT, LAI)])
	prof.append([0.004, y1 + bud * 0.98, _c(GOLD_LT, LAI)])
	prof.append([0.0, tip, _c(GOLD_LT, LAI)])
	b.lathe(prof, segs - 2 if lite else segs)
	b.xf = _root
	# The front peak, a red gem at its heart.
	var peak := PackedVector2Array([Vector2(-r * 0.55, -h * 0.45), Vector2(-r * 0.42, h * 0.3), Vector2(-r * 0.16, h * 0.55), Vector2(0, h * 1.7), Vector2(r * 0.16, h * 0.55), Vector2(r * 0.42, h * 0.3), Vector2(r * 0.55, -h * 0.45)])
	var front := Vector3(c.x, band_y + h * 0.5, c.z + r * 0.96)
	_plate(b, peak, Transform3D(Basis(Vector3.RIGHT, -0.22), front), r * 0.06, GOLD_LT, GOLD_DK)
	b.emit = 0.9
	b.ball(front + Vector3(0, h * 0.2, r * 0.05), Vector3(r * 0.11, r * 0.13, r * 0.06), _c(GEM, PLAIN), _c(RED_DK, PLAIN), 6, 4)
	b.emit = 0.0


## กรรเจียก: the gold flame rising up and back from the ear at [param at] (the left one;
## _both mirrors it).
static func _kanchiak(b: K.Builder, at: Vector3, size: float) -> void:
	var poly := R._flame_poly(size * 0.5, size, -0.18, 0.2, 8)
	var basis := Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)) * Basis(Vector3.BACK, 0.25)
	b.emit = 0.1
	_plate(b, poly, Transform3D(basis, at), size * 0.07, GOLD_LT, GOLD_DK)
	b.emit = 0.6
	b.ball(at + Vector3(0.012, size * 0.22, -size * 0.03), Vector3.ONE * size * 0.08, _c(GEM, PLAIN), _c(RED_DK, PLAIN), 5, 3)
	b.emit = 0.0


## A wing (the left; _both mirrors it): the gold arm of the wing from root to mid (WING) and
## on to the tip (WING_TIP), and rows of feathers hanging from it, the long flight feathers
## behind and the coverts laid over them, sweeping out along the wing toward the tip.
static func _wing(b: K.Builder, side: float, w: Dictionary, rows: Array, lite: bool) -> void:
	var root: Vector3 = w.root
	var mid: Vector3 = w.mid
	var tip: Vector3 = w.tip
	var inner := root.distance_to(mid)
	var total := inner + mid.distance_to(tip)
	var t_mid := inner / total
	_part(b, WING, side)
	b.emit = 0.1
	b.tube([root, root.lerp(mid, 0.5) + Vector3(0, 0.05, 0), mid], [0.06, 0.05, 0.042], 6 if lite else 7, [[_c(GOLD_LT, LAI), _c(GOLD_DK, LAI)]])
	_part(b, WING_TIP, side)
	b.tube([mid, mid.lerp(tip, 0.5) + Vector3(0, 0.035, 0), tip], [0.042, 0.03, 0.0], 6 if lite else 7, [[_c(GOLD_LT, LAI), _c(GOLD_DK, LAI)]])
	b.emit = 0.0
	var out := (tip - mid).normalized()
	var down := Vector3(0.12, -1.0, -0.28).normalized()
	var segs := 2 if lite else 3
	for row in rows:
		var n := int(row.n_lite if lite else row.n)
		if n <= 0:
			continue
		for i in n:
			var t := lerpf(float(row.t0), float(row.t1), (float(i) + 0.5) / float(n))
			var at := root.lerp(mid, t / t_mid) if t < t_mid else mid.lerp(tip, (t - t_mid) / (1.0 - t_mid))
			var tangent := (mid - root).normalized() if t < t_mid else out
			_part(b, WING if t < t_mid else WING_TIP, side, float(row.get("flutter", 0.25)), false)
			var dir := down.lerp(out, pow(t, float(row.get("sweep", 1.6)))).normalized()
			var face := tangent.cross(dir).normalized()
			if face.z < 0.0:
				face = -face
			var long := lerpf(float(row.len0), float(row.len1), pow(t, 0.8))
			var start := at + face * float(row.front)
			b.emit = float(row.get("emit", 0.0))
			_feather(b, start, start + dir * long, float(row.width), face, row.c0, row.c1, segs, face * 0.035, -face * 0.04 + Vector3(0, 0.03, 0))
	b.emit = 0.0


## Eyes on a face: [param at] the left eye's centre, [param r] its size; a dark almond
## (the dancer) or a round white eye with a dark pupil (the garuda).
static func _eye(b: K.Builder, at: Vector3, r: Vector3, round_eye: bool) -> void:
	if round_eye:
		b.emit = 0.6
		b.ball(at, r, _c(Color.WHITE, PLAIN), _c(Color("e8e0d0"), PLAIN), 7, 5)
		b.emit = 0.0
		b.ball(at + Vector3(-r.x * 0.12, 0, r.z * 0.62), Vector3(r.x * 0.5, r.y * 0.6, r.z * 0.5), _c(INK_DARK, PLAIN), _c(INK_DARK, PLAIN), 6, 4)
		b.emit = 1.0
		b.ball(at + Vector3(-r.x * 0.28, r.y * 0.25, r.z * 0.95), Vector3.ONE * r.x * 0.16, _c(Color.WHITE, PLAIN), _c(Color.WHITE, PLAIN), 4, 2)
		b.emit = 0.0
	else:
		b.ball(at, r, _c(INK_DARK, PLAIN), _c(INK_DARK, PLAIN), 7, 4)
		b.emit = 1.0
		b.ball(at + Vector3(r.x * 0.25, r.y * 0.3, r.z * 0.7), Vector3.ONE * r.y * 0.35, _c(Color.WHITE, PLAIN), _c(Color.WHITE, PLAIN), 4, 2)
		b.emit = 0.0


static func _build(kind: String, lite: bool) -> ArrayMesh:
	var b := K.Builder.new()
	b.customs = true
	_root = Transform3D.IDENTITY
	if kind == "garuda":
		_garuda(b, lite)
	else:
		_kinnari(b, lite)
	_root = Transform3D.IDENTITY
	return b.mesh()


# ---------------------------------------------------------------------------
# กินรี.
# ---------------------------------------------------------------------------
const K_SKIN := Color("ffe2c2")
const K_SKIN_LT := Color("fff0dc")
const K_HAIR := Color("2c1a30")
const K_BODY_LT := Color("fffaf0")
const K_BODY := Color("ffd25a")
const K_PLUME := Color("fff8e8")


static func _kinnari(b: K.Builder, lite: bool) -> void:
	var sides := 7 if lite else 10
	var s: Dictionary = spec("kinnari")
	# The golden swan body, a plump breast under the waist.
	_part(b, BODY)
	b.ball(Vector3(0, 0.98, -0.08), Vector3(0.27, 0.28, 0.37), _c(K_BODY_LT, SCALLOP), _c(K_BODY, SCALLOP), 8 if lite else 12, 6 if lite else 8)
	b.ball(Vector3(0, 1.0, 0.1), Vector3(0.21, 0.22, 0.18), _c(K_BODY_LT, SCALLOP), _c(K_BODY, SCALLOP), 7 if lite else 10, 5 if lite else 6)
	# The belt, its ห้อยหน้า of red cloth hemmed in gold, and the gold side flaps.
	b.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.8)), Vector3(0, 0, 0.03))
	b.emit = 0.1
	b.lathe([[0.15, 1.13, _c(GOLD_DK, LAI)], [0.172, 1.15, _c(GOLD, LAI)], [0.176, 1.2, _c(GOLD_LT, LAI)], [0.158, 1.235, _c(GOLD, LAI)]], sides + 2)
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY
	_part(b, BODY, 0.0, 0.35, false)
	_cloth(b, [Vector3(0, 1.17, 0.175), Vector3(0, 1.05, 0.265), Vector3(0, 0.92, 0.3), Vector3(0, 0.8, 0.29), Vector3(0, 0.7, 0.26)], [0.15, 0.15, 0.13, 0.1, 0.02], Vector3(0, 0.25, 1).normalized(), RED, GOLD)
	_both(b, func(bb: K.Builder, side: float):
		_part(bb, BODY, side, 0.2, true)
		_plate(bb, R._flame_poly(0.1, 0.26, 0.1, -0.12, 6), Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.BACK, PI), Vector3(0.17, 1.15, 0.06)), 0.012, GOLD_LT, GOLD_DK))
	# The tail: a fan of long plumes, gold into white, their tips curling up like กนก flames.
	var n := 5 if lite else 7
	for k in n:
		var f := float(k) / float(n - 1) - 0.5
		_part(b, TAIL, 0.0, 0.4, false)
		var root := Vector3(f * 0.2, 0.98 - absf(f) * 0.06, -0.36)
		var tip := root + Vector3(f * 1.15, 0.95 - absf(f) * 0.85, -0.95 + absf(f) * 0.3)
		b.emit = 0.08
		_feather(b, root, tip, 0.26 - absf(f) * 0.08, Vector3(f * 0.9, 0.6, 0.8).normalized(), K_BODY, K_PLUME, 3 if lite else 4, Vector3(0, -0.12, -0.05), Vector3(f * 0.15, 0.4, 0.38))
	b.emit = 0.0
	# The bird legs, tucked under her as she floats.
	_both(b, func(bb: K.Builder, side: float): _kinnari_leg(bb, side, lite))
	# The torso: slim, a red breast cloth hemmed in gold.
	_part(b, TORSO)
	b.tube([Vector3(0, 1.14, 0.03), Vector3(0, 1.26, 0.035), Vector3(0, 1.38, 0.04), Vector3(0, 1.48, 0.035), Vector3(0, 1.57, 0.02), Vector3(0, 1.645, 0.0), Vector3(0, 1.73, 0.0)],
		[Vector2(0.15, 0.115), Vector2(0.138, 0.108), Vector2(0.162, 0.122), Vector2(0.178, 0.13), Vector2(0.19, 0.12), Vector2(0.085, 0.072), Vector2(0.058, 0.056)], sides, [_c(K_SKIN, PLAIN)], Vector3.BACK)
	b.tube([Vector3(0, 1.36, 0.04), Vector3(0, 1.375, 0.041), Vector3(0, 1.395, 0.043), Vector3(0, 1.475, 0.04), Vector3(0, 1.495, 0.038), Vector3(0, 1.51, 0.036)],
		[Vector2(0.17, 0.13), Vector2(0.175, 0.135), Vector2(0.178, 0.137), Vector2(0.188, 0.141), Vector2(0.188, 0.137), Vector2(0.184, 0.131)], sides,
		[_c(GOLD, LAI), _c(GOLD_LT, LAI), _c(RED, CLOTH), _c(RED, CLOTH), _c(GOLD_LT, LAI), _c(GOLD, LAI)], Vector3.BACK, false)
	# The สไบ over her left shoulder, its end flying behind her.
	_part(b, TORSO, 0.0, 0.9, false)
	_cloth(b, [Vector3(-0.08, 1.4, 0.18), Vector3(0.06, 1.5, 0.165), Vector3(0.15, 1.6, 0.08), Vector3(0.17, 1.62, -0.06), Vector3(0.16, 1.45, -0.18), Vector3(0.2, 1.2, -0.32), Vector3(0.26, 0.95, -0.46)],
		[0.1, 0.11, 0.1, 0.09, 0.1, 0.11, 0.08], Vector3(0, 0.3, 1).normalized(), RED, GOLD)
	# The กรองคอ, gems round it and the ทับทรวง below.
	_part(b, TORSO)
	b.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.78)), Vector3(0, 0, 0.012))
	b.emit = 0.12
	b.lathe([[0.07, 1.665, _c(GOLD, LAI)], [0.13, 1.635, _c(GOLD_LT, LAI)], [0.2, 1.59, _c(GOLD, LAI)], [0.212, 1.56, _c(GOLD_DK, LAI)]], sides + 2)
	b.xf = Transform3D.IDENTITY
	b.emit = 0.8
	for k in 5:
		var a := -0.9 + 1.8 * float(k) / 4.0
		b.ball(Vector3(sin(a) * 0.17, 1.6, cos(a) * 0.17 * 0.78 + 0.02), Vector3.ONE * 0.016, _c(GEM, PLAIN), _c(RED_DK, PLAIN), 4, 2)
	b.emit = 0.1
	_plate(b, PackedVector2Array([Vector2(0, 0.05), Vector2(0.035, 0), Vector2(0, -0.06), Vector2(-0.035, 0)]), Transform3D(Basis(), Vector3(0, 1.535, 0.16)), 0.014, GOLD_LT, GOLD_DK)
	b.emit = 0.0
	# The arms (sashes, nails and the hidden ribbon of light).
	_both(b, func(bb: K.Builder, side: float): _kinnari_arm(bb, side, lite, float(s.ribbon_len)))
	# The wings.
	var rows := [
		{"n": 10, "n_lite": 6, "t0": 0.06, "t1": 1.0, "len0": 0.45, "len1": 0.92, "width": 0.17, "c0": Color("fff8ea"), "c1": Color("f2ac30"), "front": 0.0, "sweep": 1.5},
		{"n": 8, "n_lite": 5, "t0": 0.04, "t1": 0.86, "len0": 0.26, "len1": 0.44, "width": 0.16, "c0": Color("f4718f"), "c1": Color("ffd2de"), "front": 0.03, "sweep": 1.8},
		{"n": 7, "n_lite": 0, "t0": 0.02, "t1": 0.7, "len0": 0.12, "len1": 0.2, "width": 0.13, "c0": GOLD, "c1": GOLD_LT, "front": 0.055, "sweep": 2.2, "emit": 0.1},
	]
	_both(b, func(bb: K.Builder, side: float): _wing(bb, side, s.wing, rows, lite))
	# The head: the dancer's face, black hair under the ชฎา, กรรเจียก.
	_part(b, HEAD)
	var hc: Vector3 = s.head
	b.ball(hc, Vector3(0.172, 0.19, 0.172), _c(K_SKIN_LT, PLAIN), _c(K_SKIN, PLAIN), 9 if lite else 12, 6 if lite else 8)
	b.ball(hc + Vector3(0, 0.008, -0.056), Vector3(0.177, 0.188, 0.148), _c(K_HAIR, PLAIN), _c(K_HAIR, PLAIN), 8 if lite else 10, 5 if lite else 6)
	b.emit = 0.3
	b.ball(hc + Vector3(0, -0.08, 0.157), Vector3(0.025, 0.01, 0.011), _c(Color("e0324a"), PLAIN), _c(Color("b01c34"), PLAIN), 5, 3)
	b.emit = 0.0
	_both(b, func(bb: K.Builder, side: float):
		_part(bb, HEAD, side)
		_eye(bb, hc + Vector3(0.064, 0.014, 0.156), Vector3(0.037, 0.023, 0.013), false)
		bb.tube([hc + Vector3(0.027, 0.05, 0.166), hc + Vector3(0.068, 0.062, 0.16), hc + Vector3(0.107, 0.052, 0.141)], [0.007, 0.008, 0.004], 4, [_c(K_HAIR, PLAIN)])
		_kanchiak(bb, hc + Vector3(0.16, 0.01, -0.01), 0.25)
		bb.emit = 0.3
		bb.ball(hc + Vector3(0.17, -0.07, 0.0), Vector3(0.02, 0.034, 0.02), _c(GOLD_LT, LAI), _c(GOLD_DK, LAI), 5, 3)
		bb.emit = 0.0)
	_part(b, HEAD)
	_crown(b, hc, 0.174, hc.y + 0.075, float(s.height), 4, lite)


static func _kinnari_leg(b: K.Builder, side: float, lite: bool) -> void:
	var knee := Vector3(0.13, 0.52, 0.06)
	var foot := Vector3(0.13, 0.12, 0.0)
	_part(b, THIGH, side)
	b.ball(Vector3(0.13, 0.72, 0.02), Vector3(0.1, 0.17, 0.11), _c(K_BODY_LT, SCALLOP), _c(K_BODY, SCALLOP), 6 if lite else 8, 4 if lite else 5)
	_part(b, SHIN, side)
	b.emit = 0.1
	b.tube([knee + Vector3(0, 0.03, 0), Vector3(0.13, 0.32, 0.03), foot], [0.034, 0.028, 0.026], 5 if lite else 6, [[_c(GOLD, LAI), _c(GOLD_DK, LAI)]], Vector3.BACK)
	b.emit = 0.0
	b.vel = Vector3(0, 1, 0)
	for k in 4:
		var a := [-0.5, 0.0, 0.5, PI][k] as float
		var dir := Vector3(sin(a), -0.15, cos(a)).normalized()
		var long := 0.08 if k == 3 else 0.13
		b.tube([foot, foot + dir * long, foot + dir * (long + 0.05) + Vector3(0, -0.04, 0)], [0.022, 0.015, 0.0], 4, [_c(GOLD, LAI), _c(GOLD, LAI), _c(Color("5a3010"), PLAIN)])
	b.vel = Vector3.ZERO


static func _kinnari_arm(b: K.Builder, side: float, lite: bool, ribbon_len: float) -> void:
	var sh := Vector3(0.2, 1.585, 0.0)
	var el := Vector3(0.24, 1.33, 0.0)
	var wr := Vector3(0.258, 1.1, 0.02)
	var hand := Vector3(0.262, 1.04, 0.025)
	var sides := 6 if lite else 8
	_part(b, ARM, side)
	b.ball(sh, Vector3(0.064, 0.062, 0.06), _c(K_SKIN_LT, PLAIN), _c(K_SKIN, PLAIN), sides, 4)
	b.tube([sh + Vector3(0, 0.01, 0), el], [0.056, 0.046], sides, [_c(K_SKIN, PLAIN)])
	_band(b, -0.02, 0.02, Vector3(0.229, 1.46, 0.0), Vector2(0.06, 0.06), GOLD, sides, 0.12)
	b.emit = 0.12
	_plate(b, R._flame_poly(0.05, 0.1, 0.0, 0.1, 6), Transform3D(Basis(Vector3.BACK, -0.5) * Basis(Vector3.UP, PI * 0.5), Vector3(0.28, 1.47, 0.0)), 0.01, GOLD_LT, GOLD_DK)
	b.emit = 0.0
	_part(b, FORE, side)
	b.ball(el, Vector3.ONE * 0.047, _c(K_SKIN, PLAIN), _c(K_SKIN, PLAIN), sides, 4)
	b.tube([el, wr], [0.046, 0.035], sides, [_c(K_SKIN, PLAIN)])
	_band(b, 0.0, 0.035, wr + Vector3(0, 0.0, 0.0), Vector2(0.043, 0.043), GOLD, sides, 0.12)
	b.ball(hand + Vector3(0, 0.012, 0.0), Vector3(0.024, 0.05, 0.036), _c(K_SKIN_LT, PLAIN), _c(K_SKIN, PLAIN), sides, 4)
	b.tube([hand + Vector3(0, -0.03, 0.005), hand + Vector3(0.004, -0.07, 0.02), hand + Vector3(0.014, -0.095, 0.045)], [0.028, 0.02, 0.012], 5, [_c(K_SKIN, PLAIN)])
	# The long gold nails of the dance, alight with the charge.
	b.emit = 2.0
	b.tube([hand + Vector3(0.014, -0.095, 0.045), hand + Vector3(0.028, -0.11, 0.075), hand + Vector3(0.044, -0.104, 0.105)], [0.012, 0.007, 0.0], 4, [_c(GOLD_LT, PLAIN)])
	b.emit = 0.0
	# A jade sash trailing from the wrist.
	_part(b, FORE, side, 1.0, false)
	_cloth(b, [wr + Vector3(0.0, 0.04, -0.045), wr + Vector3(0.03, -0.2, -0.12), wr + Vector3(0.05, -0.48, -0.2), wr + Vector3(0.08, -0.78, -0.24), wr + Vector3(0.1, -1.04, -0.22)],
		[0.06, 0.075, 0.085, 0.08, 0.05], Vector3(1, 0, 0.35).normalized(), JADE, GOLD_LT)
	if side < 0.0:
		# The ribbon of light, folded away in her right hand until she dances it out.
		_part(b, RIBBON, side, 0.0, false)
		b.emit = 2.0
		# Two strips crossed along it, so it reads from above as from the side.
		var n := 14 if lite else 24
		for across: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
			var prev := []
			for k in n + 1:
				var u := float(k) / float(n)
				var w := 0.2 * pow(sin(PI * minf(u * 4.0, 1.0) * 0.5), 0.6) * (1.0 - 0.5 * u) + 0.025
				b.vel = Vector3(u, 0, 0)
				var at := hand + Vector3(0, -u * ribbon_len, 0.0)
				var col := _c(Color("fff2b0").lerp(Color("ffd060"), u), PLAIN)
				var nor := across.cross(Vector3.UP)
				var ring := [b.pt(at - across * w, nor, col, Vector2(0.0, u)), b.pt(at + across * w, nor, col, Vector2(1.0, u))]
				if not prev.is_empty():
					b.tri(prev[0], prev[1], ring[1]); b.tri(prev[0], ring[1], ring[0])
				prev = ring
		b.vel = Vector3.ZERO
		b.emit = 0.0


# ---------------------------------------------------------------------------
# ครุฑน้อยเทวาลัย.
# ---------------------------------------------------------------------------
const G_RED := Color("de3a2a")
const G_RED_DK := Color("9e1c1a")
const G_FACE := Color("ef5a3e")
const G_BEAK := Color("ffc23a")
const G_BEAK_DK := Color("e07a1c")
const G_TALON := Color("2e1a14")


static func _garuda(b: K.Builder, lite: bool) -> void:
	var sides := 7 if lite else 10
	var s: Dictionary = spec("garuda")
	# The hips in red feathers, the belt, the ห้อยหน้า and the gold side flaps.
	_part(b, BODY)
	b.ball(Vector3(0, 0.9, -0.01), Vector3(0.22, 0.17, 0.19), _c(G_RED, SCALLOP), _c(G_RED_DK, SCALLOP), 8 if lite else 10, 5 if lite else 6)
	b.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.84)), Vector3(0, 0, 0.0))
	b.emit = 0.1
	b.lathe([[0.18, 0.92, _c(GOLD_DK, LAI)], [0.205, 0.94, _c(GOLD, LAI)], [0.208, 1.0, _c(GOLD_LT, LAI)], [0.185, 1.03, _c(GOLD, LAI)]], sides + 2)
	b.emit = 0.0
	b.xf = Transform3D.IDENTITY
	_part(b, BODY, 0.0, 0.3, false)
	_cloth(b, [Vector3(0, 0.97, 0.18), Vector3(0, 0.86, 0.2), Vector3(0, 0.72, 0.2), Vector3(0, 0.6, 0.17)], [0.17, 0.16, 0.13, 0.02], Vector3(0, 0.2, 1).normalized(), RED_DK.lerp(RED, 0.4), GOLD)
	_both(b, func(bb: K.Builder, side: float):
		_part(bb, BODY, side, 0.2, true)
		_plate(bb, R._flame_poly(0.1, 0.24, 0.1, -0.12, 6), Transform3D(Basis(Vector3.UP, 1.1) * Basis(Vector3.BACK, PI), Vector3(0.2, 0.94, 0.04)), 0.012, GOLD_LT, GOLD_DK))
	# The tail fan, red into gold.
	var n := 4 if lite else 5
	for k in n:
		var f := float(k) / float(n - 1) - 0.5
		_part(b, TAIL, 0.0, 0.3, false)
		var root := Vector3(f * 0.16, 0.92, -0.18)
		_feather(b, root, root + Vector3(f * 0.6, -0.32 + absf(f) * 0.1, -0.5), 0.17, Vector3(f * 0.5, 1.0, -0.2).normalized(), G_RED, GOLD_LT, 3, Vector3(0, 0.06, 0), Vector3(f * 0.08, 0.12, 0.0))
	# Legs.
	_both(b, func(bb: K.Builder, side: float): _garuda_leg(bb, side, lite))
	# The torso, red, in a gold breastplate.
	_part(b, TORSO)
	b.tube([Vector3(0, 0.94, 0.0), Vector3(0, 1.06, 0.0), Vector3(0, 1.18, 0.01), Vector3(0, 1.28, 0.01), Vector3(0, 1.36, 0.0), Vector3(0, 1.42, 0.0), Vector3(0, 1.5, 0.01)],
		[Vector2(0.17, 0.14), Vector2(0.172, 0.142), Vector2(0.205, 0.16), Vector2(0.222, 0.168), Vector2(0.226, 0.15), Vector2(0.12, 0.1), Vector2(0.1, 0.09)], sides, [[_c(G_FACE, PLAIN), _c(G_RED, PLAIN)]], Vector3.BACK)
	# The กรองคอ over the shoulders.
	b.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.8)), Vector3(0, 0, 0.01))
	b.emit = 0.12
	b.lathe([[0.1, 1.47, _c(GOLD, LAI)], [0.17, 1.44, _c(GOLD_LT, LAI)], [0.245, 1.38, _c(GOLD, LAI)], [0.26, 1.34, _c(GOLD_DK, LAI)]], sides + 2)
	b.xf = Transform3D.IDENTITY
	b.emit = 0.8
	for k in 5:
		var a := -0.9 + 1.8 * float(k) / 4.0
		b.ball(Vector3(sin(a) * 0.2, 1.4, cos(a) * 0.2 * 0.8 + 0.02), Vector3.ONE * 0.02, _c(Color("2fe0a8"), PLAIN), _c(JADE, PLAIN), 4, 2)
	# The ทับทรวง, the crossed สังวาล.
	b.emit = 0.12
	_plate(b, PackedVector2Array([Vector2(0, 0.075), Vector2(0.06, 0), Vector2(0, -0.09), Vector2(-0.06, 0)]), Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 1.22, 0.17)), 0.02, GOLD_LT, GOLD_DK)
	b.emit = 0.9
	b.ball(Vector3(0, 1.215, 0.185), Vector3(0.022, 0.03, 0.012), _c(GEM, PLAIN), _c(RED_DK, PLAIN), 5, 3)
	b.emit = 0.12
	for side: float in [-1.0, 1.0]:
		var pts := []
		for k in 7:
			var t := float(k) / 6.0
			var y := lerpf(1.36, 1.0, t)
			var x := lerpf(0.17, -0.15, t) * side
			var rx := lerpf(0.22, 0.17, t)
			var rz := lerpf(0.16, 0.142, t)
			var z := rz * sqrt(maxf(1.0 - pow(x / rx, 2.0), 0.0)) + 0.012
			pts.append(Vector3(x, y, z))
		b.tube(pts, [0.012], 4, [_c(GOLD, LAI)], Vector3.UP, false)
	b.emit = 0.0
	# อินทรธนู: the gold flames curling up over the shoulders.
	_both(b, func(bb: K.Builder, side: float):
		_part(bb, TORSO, side)
		bb.emit = 0.12
		_plate(bb, R._flame_poly(0.13, 0.26, 0.08, 0.3, 8), Transform3D(Basis(Vector3.BACK, -0.95) * Basis(Vector3.UP, 0.35), Vector3(0.23, 1.38, -0.02)), 0.02, GOLD_LT, GOLD_DK)
		bb.emit = 0.0)
	# Arms.
	_both(b, func(bb: K.Builder, side: float): _garuda_arm(bb, side, lite))
	# Wings.
	var rows := [
		{"n": 11, "n_lite": 7, "t0": 0.05, "t1": 1.0, "len0": 0.62, "len1": 1.05, "width": 0.2, "c0": GOLD, "c1": Color("e3322a"), "front": 0.0, "sweep": 1.4},
		{"n": 9, "n_lite": 5, "t0": 0.03, "t1": 0.86, "len0": 0.34, "len1": 0.55, "width": 0.18, "c0": Color("0f9c7c"), "c1": Color("5fe8b8"), "front": 0.035, "sweep": 1.7},
		{"n": 8, "n_lite": 0, "t0": 0.02, "t1": 0.72, "len0": 0.15, "len1": 0.26, "width": 0.15, "c0": GOLD_DK, "c1": GOLD_LT, "front": 0.065, "sweep": 2.2, "emit": 0.1},
	]
	_both(b, func(bb: K.Builder, side: float): _wing(bb, side, s.wing, rows, lite))
	# The head: big and round, red, a hooked gold beak, round fierce eyes, the ชฎา.
	_part(b, HEAD)
	var hc: Vector3 = s.head
	b.ball(hc, Vector3(0.245, 0.24, 0.235), _c(G_FACE, PLAIN), _c(G_RED, PLAIN), 10 if lite else 14, 7 if lite else 9)
	# Cheek feathers, a white-gold ruff under the beak.
	b.ball(hc + Vector3(0, -0.12, 0.08), Vector3(0.2, 0.1, 0.17), _c(WHITE, SCALLOP), _c(GOLD_LT, SCALLOP), 8 if lite else 10, 4 if lite else 5)
	b.emit = 0.15
	b.tube([hc + Vector3(0, 0.02, 0.19), hc + Vector3(0, 0.02, 0.31), hc + Vector3(0, -0.005, 0.41), hc + Vector3(0, -0.06, 0.47), hc + Vector3(0, -0.12, 0.455)],
		[Vector2(0.09, 0.075), Vector2(0.075, 0.065), Vector2(0.055, 0.05), Vector2(0.032, 0.03), 0.0], sides, [[_c(G_BEAK, PLAIN), _c(G_BEAK_DK, PLAIN)], [_c(G_BEAK, PLAIN), _c(G_BEAK_DK, PLAIN)], [_c(G_BEAK, PLAIN), _c(G_BEAK_DK, PLAIN)], _c(G_BEAK_DK, PLAIN), _c(G_BEAK_DK, PLAIN)], Vector3.UP)
	b.tube([hc + Vector3(0, -0.07, 0.18), hc + Vector3(0, -0.085, 0.3), hc + Vector3(0, -0.095, 0.37)], [Vector2(0.065, 0.04), Vector2(0.045, 0.03), 0.0], 6, [[_c(G_BEAK, PLAIN), _c(G_BEAK_DK, PLAIN)]], Vector3.UP)
	b.emit = 0.0
	_both(b, func(bb: K.Builder, side: float):
		_part(bb, HEAD, side)
		_eye(bb, hc + Vector3(0.1, 0.06, 0.17), Vector3(0.065, 0.072, 0.045), true)
		# A fierce gold brow, flaring up and back like a flame.
		bb.emit = 0.15
		bb.tube([hc + Vector3(0.03, 0.12, 0.215), hc + Vector3(0.1, 0.15, 0.2), hc + Vector3(0.18, 0.17, 0.14), hc + Vector3(0.23, 0.22, 0.06)], [0.018, 0.022, 0.016, 0.0], 5, [_c(GOLD, LAI)])
		bb.emit = 0.0
		_kanchiak(bb, hc + Vector3(0.22, 0.02, -0.03), 0.3))
	_part(b, HEAD)
	_crown(b, hc + Vector3(0, 0, -0.01), 0.205, hc.y + 0.11, float(s.height), 4, lite)


static func _garuda_leg(b: K.Builder, side: float, lite: bool) -> void:
	var knee := Vector3(0.16, 0.5, 0.1)
	var foot := Vector3(0.16, 0.08, -0.02)
	_part(b, THIGH, side)
	b.ball(Vector3(0.155, 0.7, 0.04), Vector3(0.13, 0.21, 0.14), _c(G_RED, SCALLOP), _c(G_RED_DK, SCALLOP), 7 if lite else 9, 5 if lite else 6)
	_band(b, -0.02, 0.02, Vector3(0.16, 0.53, 0.09), Vector2(0.075, 0.075), GOLD, 6 if lite else 8, 0.12)
	_part(b, SHIN, side)
	b.tube([knee, Vector3(0.16, 0.3, 0.04), foot + Vector3(0, 0.03, 0)], [0.05, 0.04, 0.036], 6 if lite else 7, [[_c(GOLD, LAI), _c(GOLD_DK, LAI)]], Vector3.BACK)
	b.ball(foot + Vector3(0, 0.02, 0.0), Vector3(0.05, 0.04, 0.06), _c(GOLD, LAI), _c(GOLD_DK, LAI), 6, 3)
	b.vel = Vector3(0, 1, 0)
	for k in 4:
		var a := [-0.45, 0.0, 0.45, PI][k] as float
		var dir := Vector3(sin(a), -0.2, cos(a)).normalized()
		var long := 0.1 if k == 3 else 0.17
		b.tube([foot, foot + dir * long], [0.03, 0.022], 5, [_c(GOLD, LAI)], Vector3.UP, false)
		b.tube([foot + dir * long, foot + dir * (long + 0.06) + Vector3(0, -0.05, 0)], [0.022, 0.0], 4, [_c(G_TALON, PLAIN)])
	b.vel = Vector3.ZERO


static func _garuda_arm(b: K.Builder, side: float, lite: bool) -> void:
	var sh := Vector3(0.235, 1.36, 0.0)
	var el := Vector3(0.3, 1.13, 0.02)
	var wr := Vector3(0.325, 0.96, 0.035)
	var hand := Vector3(0.33, 0.93, 0.04)
	var sides := 6 if lite else 8
	_part(b, ARM, side)
	b.ball(sh, Vector3(0.08, 0.075, 0.075), _c(G_FACE, PLAIN), _c(G_RED, PLAIN), sides, 4)
	b.tube([sh + Vector3(0, 0.01, 0), el], [0.07, 0.058], sides, [_c(G_RED, PLAIN)])
	_band(b, -0.022, 0.022, Vector3(0.265, 1.24, 0.01), Vector2(0.071, 0.071), GOLD, sides, 0.12)
	_part(b, FORE, side)
	b.ball(el, Vector3.ONE * 0.058, _c(G_RED, PLAIN), _c(G_RED, PLAIN), sides, 4)
	b.tube([el, wr], [0.058, 0.048], sides, [_c(G_RED, PLAIN)])
	_band(b, -0.01, 0.04, wr, Vector2(0.056, 0.056), GOLD, sides, 0.12)
	# A clawed hand: the fist and three gold-nailed talons.
	b.ball(hand + Vector3(0, -0.02, 0), Vector3(0.05, 0.06, 0.055), _c(G_FACE, PLAIN), _c(G_RED, PLAIN), sides, 4)
	b.emit = 2.0
	for k in 3:
		var x := (float(k) - 1.0) * 0.028
		var root := hand + Vector3(x, -0.06, 0.03)
		b.tube([root, root + Vector3(x * 0.4, -0.05, 0.035), root + Vector3(x * 0.6, -0.05, 0.08)], [0.016, 0.011, 0.0], 4, [_c(GOLD_LT, PLAIN)])
	b.emit = 0.0
