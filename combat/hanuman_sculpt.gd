class_name HanumanSculpt
extends RefCounted
## The body of หนุมาน as a fighting companion (HanumanAvatar, the Muay Thai ★200 skill
## หนุมานแผลงฤทธิ์): the same white monkey warrior RamakienSculpt carves for the giant
## spirit (its helpers, the khon mask, the ลาย jacket, the gold ชฎา), but whole and in
## cartoon proportions (a big head under the crown, short bowed legs, a long curling tail)
## and cut into rigid parts that HanumanAvatar poses joint by joint. Every part is built in
## its own frame, the joint at the origin, a limb hanging along -Y, the figure facing +Z
## (its left at +X), in figure units (HanumanAvatar scales them to metres). Built once per
## kind and shared (release() frees them when a zone unloads).
##   hips      trunks of gold ลาย, the belt, the red ห้อยหน้า and side flaps (the hip joint)
##   torso     the khon jacket, shoulders, collar, chest pendant, crossed chains, อินทรธนู
##             (from the waist)
##   head      neck, the white monkey mask, กรรเจียก, the jewelled band and the ชฎา spire
##   upper_l/r the sleeve and its armlet (from the shoulder)
##   fore_l/r  the forearm, bracelet and a clenched fist (from the elbow)
##   thigh     the trunk leg with its gold knee cuff (from the hip joint)
##   shin      the furred shin, anklet and foot (from the knee)
##   tail      the long white tail curling up behind, a gold ring near its tip
##   trident   the gold ตรีเพชร, the grip at the origin, the prongs up +Y
##   crescent  the yawned moon (หาวเป็นดาวเป็นเดือน), a flat gold crescent facing +Z

const S := preload("res://combat/ramakien_sculpt.gd")
const KINDS := ["hips", "torso", "head", "upper_l", "upper_r", "fore_l", "fore_r", "thigh", "shin", "tail", "trident", "crescent"]
## Joint layout (figure units). The torso's waist sits WAIST over the hip joint.
const WAIST := 0.035
const NECK := 0.40
const SHOULDER := Vector3(0.152, 0.315, 0.0)
const HIP_JOINT := Vector3(0.072, -0.035, 0.0)
const TAIL_ROOT := Vector3(0.0, -0.02, -0.085)
const UPPER_LEN := 0.15
const FORE_LEN := 0.13
const THIGH_LEN := 0.16
const SHIN_LEN := 0.15
## From the knee down to the sole.
const FOOT_DROP := 0.185
## The head is drawn this much bigger than the giant's (the cartoon proportion).
const HEAD_SCALE := 1.6
const FIST := 0.052

static var _meshes: Dictionary = {}


static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m := build(kind)
	_meshes[kind] = m
	return m


## Builds the parts while a Muay Thai fighter's zone loads (SpellSpectacle.warm_geometry),
## spread over frames by [param slicer]; anyone else builds them on the first call.
static func warm(slicer: SceneTree = null) -> void:
	if not Game.has_profile or Game.class_id() != &"muaythai":
		return
	for kind in KINDS:
		mesh(String(kind))
		await FrameSlicer.pace(slicer)


static func release() -> void:
	_meshes.clear()


static func build(kind: String) -> ArrayMesh:
	S._st = SurfaceTool.new()
	S._st.begin(Mesh.PRIMITIVE_TRIANGLES)
	S._xf = Transform3D.IDENTITY
	S._glow = 0.0
	S._mask = 1.0
	S._tone = 1.0
	S._lean = false
	match kind:
		"hips": _hips()
		"torso": _torso()
		"head": _head()
		"upper_l": _upper(1.0)
		"upper_r": _upper(-1.0)
		"fore_l": _fore(1.0)
		"fore_r": _fore(-1.0)
		"thigh": _thigh()
		"shin": _shin()
		"tail": _tail()
		"trident": _trident()
		"crescent": _crescent()
	S._st.index()
	var out := S._st.commit()
	S._st = null
	S._xf = Transform3D.IDENTITY
	return out


static func _hips() -> void:
	# สนับเพลา: short trunks, white with gold ลาย, flaring a little over the thighs.
	S._lathe([[0.0, -0.095], [0.112, -0.088], [0.126, -0.062], [0.122, -0.02], [0.112, 0.03], [0.104, 0.07]], Vector3.ZERO, 22, 0.72, S.SKIN, S.P_LAI)
	# The belt (ผ้าห้อยข้าง's band) and its jewelled buckle.
	S._lathe([[0.108, 0.035], [0.114, 0.048], [0.114, 0.072], [0.108, 0.084]], Vector3.ZERO, 22, 0.74, S.GOLD, S.P_ENGRAVE)
	var keep := S._xf
	S._xf = keep * Transform3D(Basis(), Vector3(0, 0.06, 0.084))
	S._plate(PackedVector2Array([Vector2(0, 0.03), Vector2(0.034, 0), Vector2(0, -0.034), Vector2(-0.034, 0)]), 0.01, S.GOLD, S.P_ENGRAVE)
	S._glow = 0.8
	S._ellipsoid(Vector3(0, 0, 0.006), Vector3(0.013, 0.015, 0.007), S.RED, S.P_NONE, 4, 8)
	S._glow = 0.0
	# ห้อยหน้า: the red front panel in a gold frame, hanging to the knees.
	S._xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.04, 0.088))
	var frame := PackedVector2Array([Vector2(-0.046, 0), Vector2(0.046, 0), Vector2(0.04, -0.15), Vector2(0, -0.19), Vector2(-0.04, -0.15)])
	S._plate(frame, 0.008, S.GOLD, S.P_ENGRAVE)
	S._xf = keep * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, 0.04, 0.094))
	var panel := PackedVector2Array([Vector2(-0.036, -0.012), Vector2(0.036, -0.012), Vector2(0.031, -0.142), Vector2(0, -0.175), Vector2(-0.031, -0.142)])
	S._plate(panel, 0.006, S.RED, S.P_NONE)
	S._glow = 0.5
	S._ellipsoid(Vector3(0, -0.11, 0.004), Vector3(0.012, 0.014, 0.005), S.GOLD, S.P_ENGRAVE, 4, 8)
	S._glow = 0.0
	# ชายไหว / side flaps: gold leaves over each hip.
	for side in [-1.0, 1.0]:
		S._xf = keep * Transform3D(Basis(Vector3.UP, side * 1.2) * Basis(Vector3.RIGHT, -0.18), Vector3(side * 0.1, 0.04, 0.03))
		S._plate(PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.022, -0.1), Vector2(0, -0.125), Vector2(-0.022, -0.1)]), 0.007, S.GOLD, S.P_ENGRAVE)
	S._xf = keep


static func _torso() -> void:
	var body: Array = []
	for pr: Array in RamakienSculpt.HANUMAN_BODY:
		body.append([pr[0], float(pr[1])])
	S._torso(body, 0.62, 0.262, 0.024)
	for side in [-1.0, 1.0]:
		S._ellipsoid(Vector3(side * SHOULDER.x, SHOULDER.y - 0.003, 0.0), Vector3(0.056, 0.056, 0.052), S.SKIN, S.P_LAI, 7, 12)
	S._collar(0.376, 0.052, 0.305, 0.165, 0.64, 14)
	S._pendant(Vector3(0, 0.25, 0.102), 0.03)
	S._sash(Vector2(0.12, 0.31), Vector2(-0.1, 0.04), body, 0.62, 0.004)
	S._sash(Vector2(-0.12, 0.31), Vector2(0.1, 0.04), body, 0.62, 0.009)
	for side in [-1.0, 1.0]:
		S._intharathanu(Vector3(side * 0.172, 0.348, -0.005), side, 0.1)


static func _head() -> void:
	# In the neck's frame: the head is the giant's (RamakienSculpt._hanuman) moved down by NECK.
	S._lathe([[0.04, -0.01], [0.042, 0.03], [0.04, 0.05]], Vector3(0, 0, 0.004), 14, 0.9, S.SKIN, S.P_NONE)
	S._head(Vector3(0, 0.072, 0.016), Vector3(0.066, 0.072, 0.064), S.P_HANUMAN, "monkey", 16, 22)
	for side in [-1.0, 1.0]:
		S._kanchiak(Vector3(side * 0.062, 0.078, -0.006), side, 0.085)
	S._brow_band(0.122, 0.067, 0.98, 0.034)
	var crown := [[0.067, 0.152], [0.063, 0.166], [0.057, 0.178]]
	crown.append_array(S._spire(0.18, 0.055, 0.27, 4, 0.37))
	S._lathe(crown, Vector3(0, 0, -0.002), 18, 1.0, S.GOLD, S.P_ENGRAVE)


static func _upper(side: float) -> void:
	var elbow := Vector3(0, -UPPER_LEN, 0)
	S._tube([Vector3(0, 0.01, 0), Vector3(side * 0.004, -UPPER_LEN * 0.5, 0.0), elbow], [0.046, 0.043, 0.035], 12, S.SKIN, S.P_LAI)
	var band := Vector3(0, -UPPER_LEN * 0.58, 0)
	S._torus(band, Vector3.DOWN, 0.043, 0.009, S.GOLD, S.P_ENGRAVE, 12, 5)
	S._flame_on(band + Vector3(side * 0.012, 0, 0), Vector3.UP, 0.04)


static func _fore(side: float) -> void:
	var wrist := Vector3(0, -FORE_LEN, 0)
	S._tube([Vector3(0, 0.012, 0), Vector3(0, -FORE_LEN * 0.4, 0.002), wrist], [0.034, 0.033, 0.026], 10, S.SKIN, S.P_NONE)
	S._torus(Vector3(0, -FORE_LEN * 0.86, 0), Vector3.DOWN, 0.03, 0.008, S.GOLD, S.P_ENGRAVE, 12, 5)
	S._torus(Vector3(0, -FORE_LEN * 0.74, 0), Vector3.DOWN, 0.031, 0.006, S.GOLD, S.P_ENGRAVE, 12, 4)
	var keep := S._xf
	# The fist out of the wrist, the back of the hand behind (-Z) and a little outward,
	# so a raised guard shows its knuckles to the enemy.
	S._xf = keep * S._frame(wrist + Vector3(0, -0.004, 0), Vector3.DOWN, Vector3(side * 0.35, 0, -1.0))
	S._fist(FIST)
	S._xf = keep


static func _thigh() -> void:
	var knee := Vector3(0, -THIGH_LEN, 0.0)
	S._tube([Vector3(0, 0.02, 0), Vector3(0, -THIGH_LEN * 0.45, 0.004), knee], [0.056, 0.052, 0.042], 12, S.SKIN, S.P_LAI)
	S._torus(knee + Vector3(0, 0.012, 0), Vector3.DOWN, 0.043, 0.01, S.GOLD, S.P_ENGRAVE, 12, 5)


static func _shin() -> void:
	var ankle := Vector3(0, -SHIN_LEN, 0)
	S._tube([Vector3(0, 0.008, 0), Vector3(0, -SHIN_LEN * 0.4, 0.008), ankle], [0.038, 0.036, 0.026], 10, S.SKIN, S.P_NONE)
	S._torus(ankle + Vector3(0, 0.02, 0), Vector3.DOWN, 0.028, 0.008, S.GOLD, S.P_ENGRAVE, 12, 5)
	# The foot: a monkey's long sole, toes gripping.
	S._ellipsoid(Vector3(0, -FOOT_DROP + 0.018, 0.03), Vector3(0.034, 0.02, 0.062), S.SKIN, S.P_NONE, 6, 12)
	S._ellipsoid(Vector3(0, -SHIN_LEN - 0.006, 0.004), Vector3(0.028, 0.022, 0.03), S.SKIN, S.P_NONE, 5, 10)


static func _tail() -> void:
	var ctrl := [Vector3(0, 0, 0), Vector3(0, -0.05, -0.1), Vector3(0, 0.0, -0.22), Vector3(0, 0.16, -0.3), Vector3(0, 0.32, -0.28), Vector3(0, 0.42, -0.18), Vector3(0, 0.44, -0.08), Vector3(0, 0.4, -0.04)]
	var pts := S._spline(ctrl, 4)
	var radii := S._lerp_list([0.026, 0.024, 0.021, 0.019, 0.017, 0.015, 0.013, 0.011], pts.size())
	S._tube(pts, radii, 10, S.SKIN, S.P_NONE)
	var k := pts.size() - 6
	S._torus(pts[k], (pts[k + 1] as Vector3) - (pts[k] as Vector3), 0.017, 0.006, S.GOLD, S.P_ENGRAVE, 12, 5)


static func _trident() -> void:
	S._glow = 0.2
	S._tube([Vector3(0, -0.34, 0), Vector3(0, 0.46, 0)], [0.0105, 0.0095], 8, S.GOLD, S.P_ENGRAVE)
	for y in [-0.33, -0.05, 0.05, 0.3, 0.45]:
		S._ellipsoid(Vector3(0, y, 0), Vector3(0.018, 0.013, 0.018), S.GOLD, S.P_ENGRAVE, 4, 8)
	S._glow = 0.0
	var keep := S._xf
	S._xf = keep * Transform3D(Basis(), Vector3(0, 0.455, 0))
	S._prongs(0.2)
	S._xf = keep


static func _crescent() -> void:
	# Outer arc round the origin (r 0.5, the left side), inner arc round (0.2, 0) through
	# the same two horns: thick in the middle, pointed at the tips.
	var poly := PackedVector2Array()
	for k in 19:
		var a := deg_to_rad(lerpf(50.0, 310.0, float(k) / 18.0))
		poly.append(Vector2(cos(a), sin(a)) * 0.5)
	for k in range(1, 16):
		var a := deg_to_rad(lerpf(287.5, 72.5, float(k) / 16.0))
		poly.append(Vector2(0.2, 0.0) + Vector2(cos(a), sin(a)) * 0.4017)
	S._glow = 1.0
	S._plate(poly, 0.07, S.GOLD, S.P_NONE)
	S._glow = 0.0
