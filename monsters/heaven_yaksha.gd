class_name HeavenYaksha
extends RefCounted
## The gate giants of ดินแดนเทวาลัย (HeavenMonsters), sculpted in code in the manner of the
## temple guardians of วัดอรุณ (ยักษ์วัดแจ้ง), with RamakienSculpt's Thai ornament (the khon
## yak mask, the ลาย jacket, the gold ชฎา, กรรเจียก, อินทรธนู, collar and pendant) but whole
## and in cartoon proportions: a big masked head under a tall tiered crown (มงกุฎยอด), a
## round chest and belly, short bowed legs, and a great club (กระบอง).
##   jade  ยักษ์ทวารบาลหยก (jade_yaksha): jade-green hide, a jade jacket of gold ลาย, a
##         five-tier crown, a red-lacquered club ringed in gold
##   king  ท้าวยักษ์เฝ้าทวารสวรรค์ (heaven_gatekeeper): a guardian king in the manner of
##         ท้าวเวสสุวรรณ: crimson hide, an emerald jacket under gold armour (a breastplate,
##         broad shoulder flames, a belt with a demon-face buckle), a seven-tier crown ringed
##         with gold petals, a flame aureole (ประภามณฑล) behind his head, a huge jewelled
##         gold club
##
## One mesh per kind (built once and shared; a lighter one at quality 0), cut into twelve
## rigid parts (UV2.y): the hips, chest, head, upper arms, forearms, thighs, shins and the
## club in the right fist. The shader (shaders/heaven_yaksha.gdshader) poses each part by
## the transform HeavenYakshaVisual hands it for that bone (one uniform array a frame), so
## the giant is one draw (two with the ink outline) whatever it does. No textures, lights
## or particles. Mesh units: +Z is the front, the figure's left at +X, the waist at y = 0,
## the soles at SOLE_Y; HeavenYakshaVisual fits the whole figure to the template height.

const S := preload("res://combat/ramakien_sculpt.gd")
const SHADER := preload("res://shaders/heaven_yaksha.gdshader")
const OUTLINE := preload("res://shaders/heaven_yaksha_outline.gdshader")

## The bones, in this order (UV2.y is the index), their parents and rest pivots.
const KEYS := ["hips", "chest", "neck", "sh_l", "sh_r", "el_l", "el_r", "hip_l", "hip_r", "kn_l", "kn_r", "club"]
const PARENT := [-1, 0, 1, 1, 1, 3, 4, 0, 0, 7, 8, 6]
const PIVOTS := [Vector3(0, -0.02, 0), Vector3(0, 0.03, 0), Vector3(0, 0.372, 0.004),
	Vector3(0.185, 0.315, 0), Vector3(-0.185, 0.315, 0), Vector3(0.205, 0.175, 0), Vector3(-0.205, 0.175, 0),
	Vector3(0.088, -0.07, 0), Vector3(-0.088, -0.07, 0), Vector3(0.102, -0.215, 0.01), Vector3(-0.102, -0.215, 0.01),
	Vector3(-0.215, 0.05, 0)]
const BONES := 12
const SOLE_Y := -0.385
## The heel-to-toe of each foot (left; mirror x for the right), for keeping them planted.
const SOLE := Vector3(0.108, -0.385, 0.03)
## The wrists (left; mirror x; the right one is the club's bone) and the club's grip.
const WRIST := Vector3(0.215, 0.05, 0.0)
const GRIP := Vector3(-0.215, 0.022, 0.0)
const FIST := 0.046

## Per kind: palette, head scale (the cartoon head), crown tiers, the club's length, and
## whether he wears the king's dress.
const KINDS := {
	"jade": {"head": 2.0, "tiers": 5, "spire": 0.37, "club": 0.62, "king": false,
		"skin": Color("44cf98"), "skin_dark": Color("147258"), "cloth": Color("1b8a68"), "cloth_dark": Color("0a4438"),
		"gold": Color("ffc84a"), "gold_dark": Color("7e420c"), "red": Color("d42c3c"), "ivory": Color("fff6e0"), "jewel": Color("ff4a5e"),
		"lines": Color("ffd970"), "ink": Color("123a34"), "rim": Color("fff0b4"), "outline": Color("0f2a2a")},
	"king": {"head": 1.8, "tiers": 7, "spire": 0.47, "club": 0.8, "king": true,
		"skin": Color("e5483c"), "skin_dark": Color("7a1426"), "cloth": Color("148a64"), "cloth_dark": Color("073a2e"),
		"gold": Color("ffd352"), "gold_dark": Color("8a4a08"), "red": Color("c41f36"), "ivory": Color("fff4dc"), "jewel": Color("3ff0c0"),
		"lines": Color("ffe28c"), "ink": Color("3a0a14"), "rim": Color("ffe7a8"), "outline": Color("2a0c14")},
}

static var _meshes := {}
static var _bases := {}
static var _lines := {}


static func has(kind: String) -> bool:
	return KINDS.has(kind)


## The kind's shared mesh (a lighter one at quality 0), its custom AABB grown for the club's
## swings and the fall.
static func mesh(kind: String) -> ArrayMesh:
	var lite := VfxBudget.quality() == 0
	var key := "%s|%d" % [kind, int(lite)]
	if not _meshes.has(key):
		var built := _build(kind, lite)
		_meshes[key] = built
	return _meshes[key]


## The rest figure's height (sole to the crown's tip) in mesh units.
static func figure_height(kind: String) -> float:
	var spec: Dictionary = KINDS.get(kind, KINDS.jade)
	return PIVOTS[2].y + (float(spec.spire) + 0.012) * float(spec.head) - SOLE_Y


## A fresh body material of the kind (each giant poses its own).
static func material(kind: String) -> ShaderMaterial:
	if not _bases.has(kind):
		var spec: Dictionary = KINDS.get(kind, KINDS.jade)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		for key in ["skin", "skin_dark", "cloth", "cloth_dark", "gold", "gold_dark", "red", "ivory", "jewel", "lines", "ink", "rim"]:
			m.set_shader_parameter(key, spec[key])
		m.set_shader_parameter("bones", rest_bones())
		_bases[kind] = m
	var out := (_bases[kind] as ShaderMaterial).duplicate() as ShaderMaterial
	out.set_shader_parameter("detail", 1.0 if VfxBudget.quality() > 0 else 0.0)
	return out


## A fresh ink outline of the kind ([param width] in mesh units).
static func outline(kind: String, width: float) -> ShaderMaterial:
	if not _lines.has(kind):
		var m := ShaderMaterial.new()
		m.shader = OUTLINE
		m.set_shader_parameter("color", KINDS.get(kind, KINDS.jade).outline)
		m.set_shader_parameter("bones", rest_bones())
		_lines[kind] = m
	var out := (_lines[kind] as ShaderMaterial).duplicate() as ShaderMaterial
	out.set_shader_parameter("width", width)
	return out


## The identity pose (every bone at rest).
static func rest_bones() -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(BONES * 4)
	for j in BONES:
		out[j * 4] = Vector3.RIGHT
		out[j * 4 + 1] = Vector3.UP
		out[j * 4 + 2] = Vector3.BACK
		out[j * 4 + 3] = Vector3.ZERO
	return out


static func triangles(m: ArrayMesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		n += m.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
	return n


# ---------------------------------------------------------------------------
# Building: each part into its own SurfaceTool, then merged with its bone in UV2.y.
# ---------------------------------------------------------------------------

static func _begin() -> void:
	S._st = SurfaceTool.new()
	S._st.begin(Mesh.PRIMITIVE_TRIANGLES)
	S._xf = Transform3D.IDENTITY
	S._glow = 0.0
	S._mask = 1.0
	S._tone = 1.0
	S._lean = true


static func _take(acc: Dictionary, part: int) -> void:
	S._st.index()
	var arr := S._st.commit_to_arrays()
	S._st = null
	S._xf = Transform3D.IDENTITY
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	if verts.is_empty():
		return
	var base: int = (acc.v as PackedVector3Array).size()
	acc.v.append_array(verts)
	acc.n.append_array(arr[Mesh.ARRAY_NORMAL])
	acc.c.append_array(arr[Mesh.ARRAY_COLOR])
	acc.uv.append_array(arr[Mesh.ARRAY_TEX_UV])
	var uv2: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV2]
	for i in uv2.size():
		uv2[i].y = float(part)
	acc.uv2.append_array(uv2)
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in ix.size():
		ix[i] += base
	acc.ix.append_array(ix)


static func _build(kind: String, lite: bool) -> ArrayMesh:
	var spec: Dictionary = KINDS.get(kind, KINDS.jade)
	var acc := {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "ix": PackedInt32Array()}
	var king := bool(spec.king)
	for part in BONES:
		_begin()
		match part:
			0: _hips(king, lite)
			1: _chest(king, lite)
			2: _head(spec, lite)
			3: _upper(1.0, king, lite)
			4: _upper(-1.0, king, lite)
			5: _fore(1.0, king, lite)
			6: _fore(-1.0, king, lite)
			7: _thigh(1.0, king, lite)
			8: _thigh(-1.0, king, lite)
			9: _shin(1.0, king, lite)
			10: _shin(-1.0, king, lite)
			11: _club(float(spec.club), king, lite)
		_take(acc, part)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = acc.v
	arrays[Mesh.ARRAY_NORMAL] = acc.n
	arrays[Mesh.ARRAY_COLOR] = acc.c
	arrays[Mesh.ARRAY_TEX_UV] = acc.uv
	arrays[Mesh.ARRAY_TEX_UV2] = acc.uv2
	arrays[Mesh.ARRAY_INDEX] = acc.ix
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Room for the raised club, the whirl and the fall.
	var tall := figure_height(kind)
	out.custom_aabb = AABB(Vector3(-0.9, SOLE_Y - 0.1, -0.9), Vector3(1.8, tall + 0.6, 1.8))
	return out


# ---------------------------------------------------------------------------
# The parts (mesh units, at rest: the arms hang at the sides, the club held out forward)
# ---------------------------------------------------------------------------

## สนับเพลา (the trunks, the jacket's ลาย), the belt and its buckle, the red ห้อยหน้า in a
## gold frame and the gold side leaves (ชายไหว).
static func _hips(king: bool, lite: bool) -> void:
	var sides := 14 if lite else 20
	S._lathe([[0.0, -0.15], [0.1, -0.145], [0.132, -0.11], [0.14, -0.05], [0.134, 0.0], [0.124, 0.04]], Vector3.ZERO, sides, 0.78, S.SKIN, S.P_LAI)
	S._lathe([[0.126, 0.02], [0.136, 0.034], [0.137, 0.066], [0.128, 0.08]], Vector3.ZERO, sides, 0.8, S.GOLD, S.P_ENGRAVE, [0.8, 1.0, 1.0, 0.8])
	var keep := S._xf
	S._xf = keep * Transform3D(Basis(), Vector3(0, 0.05, 0.11))
	if king:
		# The demon-face buckle (หน้ากาล): a round gold plate, glaring ruby eyes, a red gem mouth.
		S._ellipsoid(Vector3.ZERO, Vector3(0.05, 0.044, 0.016), S.GOLD, S.P_ENGRAVE, 5, 10)
		S._glow = 0.9
		for side in [-1.0, 1.0]:
			S._ellipsoid(Vector3(side * 0.018, 0.01, 0.014), Vector3(0.011, 0.009, 0.006), S.RED, S.P_NONE, 4, 6)
		S._glow = 0.4
		S._ellipsoid(Vector3(0, -0.018, 0.013), Vector3(0.02, 0.007, 0.006), S.PEARL, S.P_NONE, 3, 6)
		S._glow = 0.0
	else:
		S._plate(PackedVector2Array([Vector2(0, 0.034), Vector2(0.036, 0), Vector2(0, -0.036), Vector2(-0.036, 0)]), 0.012, S.GOLD, S.P_ENGRAVE)
		S._glow = 0.8
		S._ellipsoid(Vector3(0, 0, 0.007), Vector3(0.014, 0.016, 0.008), S.RED, S.P_NONE, 4, 6)
		S._glow = 0.0
	# ห้อยหน้า: the red front panel in a gold frame, hanging between the knees.
	var drop := 0.24 if king else 0.2
	S._xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0, 0.02, 0.112))
	S._plate(PackedVector2Array([Vector2(-0.056, 0), Vector2(0.056, 0), Vector2(0.05, -drop * 0.8), Vector2(0, -drop), Vector2(-0.05, -drop * 0.8)]), 0.008, S.GOLD, S.P_ENGRAVE)
	S._xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0, 0.02, 0.118))
	S._plate(PackedVector2Array([Vector2(-0.044, -0.014), Vector2(0.044, -0.014), Vector2(0.039, -drop * 0.76), Vector2(0, -drop * 0.93), Vector2(-0.039, -drop * 0.76)]), 0.006, S.RED, S.P_NONE)
	S._glow = 0.5
	S._ellipsoid(Vector3(0, -drop * 0.6, 0.005), Vector3(0.014, 0.017, 0.006), S.GOLD, S.P_ENGRAVE, 4, 6)
	S._glow = 0.0
	# ชายไหว: gold leaves over each hip (the king's longer, two to a side).
	for side in [-1.0, 1.0]:
		for k in (2 if king else 1):
			S._xf = keep * Transform3D(Basis(Vector3.UP, side * (1.15 + 0.5 * k)) * Basis(Vector3.RIGHT, -0.2), Vector3(side * 0.12, 0.03, 0.03 - 0.05 * k))
			S._plate(PackedVector2Array([Vector2(-0.036, 0), Vector2(0.036, 0), Vector2(0.026, -0.12), Vector2(0, -0.15), Vector2(-0.026, -0.12)]), 0.008, S.GOLD, S.P_ENGRAVE)
	S._xf = keep


const BODY := [[0.124, -0.04], [0.13, 0.02], [0.148, 0.08], [0.162, 0.14], [0.17, 0.2], [0.172, 0.25], [0.166, 0.29], [0.15, 0.322], [0.112, 0.35], [0.07, 0.37], [0.05, 0.384], [0.046, 0.41]]


## The jacket (ลาย) over a round chest and belly, the shoulders, the jewelled collar
## (กรองคอ), the pendant (ทับทรวง), crossed chains (สังวาล) and the shoulder flames
## (อินทรธนู). The king wears a gold breastplate over it and broader flames.
static func _chest(king: bool, lite: bool) -> void:
	S._torso(BODY, 0.68, 0.262, 0.03)
	for side in [-1.0, 1.0]:
		S._ellipsoid(Vector3(side * 0.18, 0.312, 0.0), Vector3(0.064, 0.062, 0.058), S.SKIN, S.P_LAI, 5 if lite else 6, 10 if lite else 12)
	S._collar(0.388, 0.062, 0.302, 0.19, 0.68, 12 if lite else 14)
	if king:
		# The breastplate: a gold shell over the chest, its rim beaded, a jade-green gem.
		var rows: Array = []
		for pr: Array in [[0.15, 0.12], [0.168, 0.17], [0.175, 0.22], [0.17, 0.265]]:
			rows.append([float(pr[0]) + 0.008, float(pr[1])])
		S._lathe(rows, Vector3(0, 0, 0.004), 18, 0.74, S.GOLD, S.P_ENGRAVE, [0.85, 1.0, 1.0, 0.85])
		S._pendant(Vector3(0, 0.22, 0.13), 0.044)
		S._glow = 0.9
		S._ellipsoid(Vector3(0, 0.155, 0.124), Vector3(0.018, 0.02, 0.01), S.PEARL, S.P_NONE, 4, 8)
		S._glow = 0.0
	else:
		S._pendant(Vector3(0, 0.25, 0.122), 0.036)
	if not lite:
		S._sash(Vector2(0.13, 0.312), Vector2(-0.11, 0.04), BODY, 0.68, 0.004)
		S._sash(Vector2(-0.13, 0.312), Vector2(0.11, 0.04), BODY, 0.68, 0.009)
	for side in [-1.0, 1.0]:
		S._intharathanu(Vector3(side * 0.2, 0.35, -0.006), side, 0.15 if king else 0.115)
		if king:
			S._intharathanu(Vector3(side * 0.215, 0.33, -0.03), side, 0.11)


## The head in its own frame (the neck's foot at the origin), drawn [code]spec.head[/code]
## times the giant's size: the khon yak mask (staring eyes, the snarl, gold ลาย), ivory
## tusks curling up from the mouth's corners, กรรเจียก at the ears, the jewelled brow band
## and the tiered spire of the crown. The king's crown is taller, ringed with gold petals,
## and a flame aureole stands behind his head.
static func _head(spec: Dictionary, lite: bool) -> void:
	var k := float(spec.head)
	var king := bool(spec.king)
	S._xf = Transform3D(Basis().scaled(Vector3.ONE * k), PIVOTS[2])
	S._lathe([[0.04, -0.01], [0.044, 0.03], [0.041, 0.05]], Vector3(0, 0, 0.004), 10, 0.9, S.SKIN, S.P_NONE)
	S._head(Vector3(0, 0.072, 0.016), Vector3(0.07, 0.074, 0.066), S.P_YAK, "yak", 11 if lite else 13, 16 if lite else 20)
	# Tusks (เขี้ยว): ivory, rising from the mouth's corners and curling out.
	for side in [-1.0, 1.0]:
		S._tube([Vector3(side * 0.026, 0.036, 0.072), Vector3(side * 0.034, 0.05, 0.084), Vector3(side * 0.043, 0.068, 0.084)], [0.0085, 0.0062, 0.0015], 6, S.INK, S.P_NONE, false)
	for side in [-1.0, 1.0]:
		S._kanchiak(Vector3(side * 0.066, 0.078, -0.006), side, 0.1 if king else 0.088)
	S._brow_band(0.122, 0.071, 0.98, 0.036)
	var tiers := int(spec.tiers)
	var spire := float(spec.spire)
	if lite:
		tiers = maxi(3, tiers - 2)
	var crown := [[0.071, 0.152], [0.067, 0.166], [0.06, 0.178]]
	crown.append_array(S._spire(0.18, 0.058 if king else 0.055, spire - 0.1, tiers, spire))
	S._lathe(crown, Vector3(0, 0, -0.002), 10 if lite else 14, 1.0, S.GOLD, S.P_ENGRAVE)
	if king:
		# A ring of gold petals (กลีบบัว) round the crown's foot, each tipped with a jade gem.
		var petals := 7 if lite else 9
		for i in petals:
			var a := lerpf(-2.4, 2.4, float(i) / float(petals - 1))
			var keep := S._xf
			S._xf = keep * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.32), Vector3(sin(a) * 0.058, 0.175, cos(a) * 0.058))
			S._plate(S._flame_poly(0.034, 0.05, 0.0, 0.0, 5), 0.005, S.GOLD, S.P_ENGRAVE)
			S._xf = keep
		S._glow = 0.9
		for i in 3:
			var a := float(i - 1) * 0.7
			S._ellipsoid(Vector3(sin(a) * 0.062, 0.2, cos(a) * 0.062), Vector3.ONE * 0.008, S.PEARL, S.P_NONE, 3, 6)
		S._glow = 0.0
		_aureole(lite)


## ประภามณฑล: an arch of gold flame tongues standing behind the king's head.
static func _aureole(lite: bool) -> void:
	var keep := S._xf
	var n := 9 if lite else 13
	S._glow = 0.35
	for i in n:
		var f := float(i) / float(n - 1)
		var a := lerpf(-1.75, 1.75, f)
		var r := 0.118
		var at := Vector3(sin(a) * r, 0.085 + cos(a) * r * 1.05, -0.07)
		var size := 0.06 * (1.0 + 0.35 * cos(a))
		S._xf = keep * Transform3D(Basis(Vector3.BACK, -a), at)
		S._plate(S._flame_poly(size * 0.55, size, 0.0, 0.18 * signf(a), 6), 0.006, S.GOLD, S.P_ENGRAVE)
	# The ring the flames rise from.
	S._xf = keep
	S._torus(Vector3(0, 0.085, -0.066), Vector3.BACK, 0.112, 0.007, S.GOLD, S.P_ENGRAVE, 16 if lite else 22, 4)
	S._glow = 0.0
	S._xf = keep


## An upper arm from the shoulder (the bone's pivot) to the elbow: the sleeve in ลาย,
## the gold armlet (พาหุรัด) with its flame.
static func _upper(side: float, king: bool, lite: bool) -> void:
	var sh: Vector3 = PIVOTS[3 if side > 0.0 else 4]
	var el: Vector3 = PIVOTS[5 if side > 0.0 else 6]
	var t := 1.1 if king else 1.0
	S._tube([sh + Vector3(0, 0.012, 0), sh.lerp(el, 0.5) + Vector3(side * 0.004, 0, 0), el], [0.056 * t, 0.052 * t, 0.045 * t], 8 if lite else 11, S.SKIN, S.P_LAI)
	var band := sh.lerp(el, 0.62)
	S._torus(band, el - sh, 0.05 * t, 0.011, S.GOLD, S.P_ENGRAVE, 10 if lite else 12, 4)
	S._flame_on(band + Vector3(side * 0.012, 0, 0), Vector3.UP, 0.045)


## A forearm from the elbow: bare skin, two gold bracelets (ทองกร), a clenched fist.
static func _fore(side: float, king: bool, lite: bool) -> void:
	var el: Vector3 = PIVOTS[5 if side > 0.0 else 6]
	var wr := Vector3(WRIST.x * side, WRIST.y, WRIST.z)
	var t := 1.1 if king else 1.0
	S._tube([el + Vector3(0, 0.01, 0), el.lerp(wr, 0.45) + Vector3(0, 0, 0.003), wr], [0.045 * t, 0.044 * t, 0.034 * t], 8 if lite else 10, S.SKIN, S.P_NONE)
	S._torus(el.lerp(wr, 0.86), wr - el, 0.037 * t, 0.009, S.GOLD, S.P_ENGRAVE, 10, 4)
	if not lite:
		S._torus(el.lerp(wr, 0.72), wr - el, 0.039 * t, 0.007, S.GOLD, S.P_ENGRAVE, 10, 4)
	if side > 0.0:
		_fist_at(side, t)


## A clenched fist out of the wrist (the right one holds the club: it is the club's part).
static func _fist_at(side: float, t: float) -> void:
	var wr := Vector3(WRIST.x * side, WRIST.y, WRIST.z)
	var keep := S._xf
	S._xf = keep * S._frame(wr + Vector3(0, -0.004, 0), Vector3.DOWN, Vector3(side, 0, 0)) * Transform3D(Basis().scaled(Vector3.ONE * t), Vector3.ZERO)
	S._fist(FIST)
	S._xf = keep


## A thigh: the trunks' leg in ลาย, a gold knee cuff.
static func _thigh(side: float, king: bool, lite: bool) -> void:
	var hip: Vector3 = PIVOTS[7 if side > 0.0 else 8]
	var kn: Vector3 = PIVOTS[9 if side > 0.0 else 10]
	var t := 1.08 if king else 1.0
	S._tube([hip + Vector3(0, 0.03, 0), hip.lerp(kn, 0.5) + Vector3(side * 0.006, 0, 0.004), kn], [0.074 * t, 0.07 * t, 0.058 * t], 9 if lite else 12, S.SKIN, S.P_LAI)
	S._torus(kn + Vector3(0, 0.014, 0), Vector3.DOWN, 0.059 * t, 0.012, S.GOLD, S.P_ENGRAVE, 10 if lite else 12, 4)


## A shin to the big flat foot: bare skin, a gold anklet.
static func _shin(side: float, king: bool, lite: bool) -> void:
	var kn: Vector3 = PIVOTS[9 if side > 0.0 else 10]
	var ankle := Vector3(SOLE.x * side, SOLE_Y + 0.05, 0.0)
	var t := 1.08 if king else 1.0
	S._tube([kn + Vector3(0, 0.006, 0), kn.lerp(ankle, 0.42) + Vector3(0, 0, 0.012), ankle], [0.054 * t, 0.05 * t, 0.038 * t], 8 if lite else 10, S.SKIN, S.P_NONE)
	S._torus(ankle + Vector3(0, 0.02, 0), Vector3.DOWN, 0.04 * t, 0.009, S.GOLD, S.P_ENGRAVE, 10, 4)
	# The foot: broad, the toes splayed (three toe knobs).
	S._ellipsoid(Vector3(SOLE.x * side, SOLE_Y + 0.026, 0.034), Vector3(0.05, 0.03, 0.078) * t, S.SKIN, S.P_NONE, 5, 10 if lite else 12)
	if not lite:
		for k in 3:
			S._ellipsoid(Vector3(SOLE.x * side + (float(k) - 1.0) * 0.026 * t, SOLE_Y + 0.018, 0.1 * t), Vector3(0.014, 0.014, 0.016) * t, S.SKIN, S.P_NONE, 3, 6)


## กระบอง: the club through the right fist, along +Z at rest (up when the forearm points
## forward): a gold pommel, a lacquered red grip ringed in gold, a long head swelling to an
## eight-sided gold-banded mace with a flame finial. The king's is all gold, longer and
## heavier, studded with jade gems and flanged.
static func _club(length: float, king: bool, lite: bool) -> void:
	_fist_at(-1.0, 1.1 if king else 1.0)
	var keep := S._xf
	S._xf = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), GRIP)
	var grip := S.GOLD if king else S.RED
	var r0 := length * (0.03 if king else 0.028)
	S._ellipsoid(Vector3(0, -length * 0.12, 0), Vector3.ONE * r0 * 1.6, S.GOLD, S.P_ENGRAVE, 4, 8)
	S._tube([Vector3(0, -length * 0.11, 0), Vector3(0, length * 0.42, 0)], [r0, r0 * 1.15], 7 if lite else 8, grip, S.P_ENGRAVE if king else S.P_NONE, false)
	for y: float in ([-0.06, 0.1, 0.26] if not lite else [0.1]):
		S._torus(Vector3(0, length * y, 0), Vector3.UP, r0 * 1.15, r0 * 0.28, S.GOLD, S.P_ENGRAVE, 8, 4)
	# The head: an eight-sided mace swelling from the grip, bands at its waist and crown.
	var prof: Array = []
	var head_r := length * (0.1 if king else 0.088)
	for i in 9:
		var t := float(i) / 8.0
		prof.append([lerpf(r0 * 1.2, head_r, sin(t * PI * 0.62)) * (1.0 - 0.2 * smoothstep(0.75, 1.0, t)), length * lerpf(0.4, 0.92, t)])
	prof.append([head_r * 0.5, length * 0.95])
	prof.append([0.0, length * 0.96])
	S._lathe(prof, Vector3.ZERO, 8, 1.0, S.GOLD if king else S.RED, S.P_ENGRAVE if king else S.P_NONE)
	for y: float in [0.52, 0.72, 0.88]:
		var t := (y - 0.4) / 0.52
		var r := lerpf(r0 * 1.2, head_r, sin(t * PI * 0.62)) * (1.0 - 0.2 * smoothstep(0.75, 1.0, t))
		S._torus(Vector3(0, length * y, 0), Vector3.UP, r * 1.01, length * 0.012, S.GOLD, S.P_ENGRAVE, 8, 3)
	S._glow = 0.6
	S._xf = S._xf * Transform3D(Basis(), Vector3(0, length * 0.94, 0))
	S._plate(S._flame_poly(head_r * 0.9, head_r * 1.5, 0.0, 0.2, 6), head_r * 0.2, S.GOLD, S.P_ENGRAVE)
	S._xf = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), GRIP)
	S._glow = 0.0
	if king:
		# Flanges down the head and jade gems between them.
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI * 0.125
			var keep2 := S._xf
			S._xf = keep2 * Transform3D(Basis(Vector3.UP, a), Vector3(0, length * 0.62, 0))
			S._plate(PackedVector2Array([Vector2(head_r * 0.6, -length * 0.16), Vector2(head_r * 1.32, -length * 0.04), Vector2(head_r * 1.38, length * 0.1), Vector2(head_r * 0.7, length * 0.2)]), length * 0.012, S.GOLD, S.P_ENGRAVE)
			S._xf = keep2
		S._glow = 0.9
		for i in (4 if lite else 8):
			var a := TAU * float(i) / (4.0 if lite else 8.0)
			var y := length * (0.66 if i % 2 == 0 else 0.8)
			var t := (y / length - 0.4) / 0.52
			var r := lerpf(r0 * 1.2, head_r, sin(t * PI * 0.62)) * (1.0 - 0.2 * smoothstep(0.75, 1.0, t))
			S._ellipsoid(Vector3(sin(a) * r, y, cos(a) * r), Vector3.ONE * length * 0.016, S.PEARL, S.P_NONE, 3, 6)
		S._glow = 0.0
	S._xf = keep
