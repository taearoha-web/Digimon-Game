extends RefCounted
## Warrior 150 stars "Royal Vanguard": the king's vanguard musters. Wind-up: a royal seal of
## gold draws itself round the warrior and five blue-and-gold war banners grind up out of the
## ground in a horseshoe (open towards the camera, so the warrior stays in view). Release:
## a column of light bursts from every banner, ribs of gold arch over the company like a
## pavilion, the royal crest (a blue shield under a gold crown) rises over the warrior and
## a gold ring rolls out over the allies the buff reaches. Royal blue, gold and white silk.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const BLUE := Color("3a7bff")
const NAVY := Color("1c2a6e")
const GOLD := Color("ffc93a")
const PALE := Color("ffe58a")
const WOOD := Color("5a3a24")
const RING := 3.6
const BANNERS := 5
const HIGH := 3.4
const ID := "royal_vanguard"


## Where banner [param i] stands: a horseshoe round the origin, its gap at +Z.
static func _spot(i: int) -> Vector3:
	var ang := lerpf(0.75, TAU - 0.75, float(i) / float(BANNERS - 1))
	return Vector3(sin(ang), 0, cos(ang)) * RING


## A war banner on the origin, 3.4 tall, its cloth facing +Z.
static func _banner() -> K.Part:
	var p := K.Part.new()
	p.ink(WOOD, 0.2)
	p.tube(Vector3.ZERO, Vector3(0, HIGH, 0), 0.06, 0.05, 6)
	p.ink(GOLD, 1.0)
	p.gem(Vector3(0, HIGH + 0.2, 0), Vector3(0.1, 0.24, 0.1))
	p.tube(Vector3(-0.62, HIGH - 0.15, 0), Vector3(0.62, HIGH - 0.15, 0), 0.04, 0.04, 6)
	for s in [-1.0, 1.0]:
		p.gem(Vector3(s * 0.66, HIGH - 0.15, 0), Vector3(0.07, 0.07, 0.07))
	# The cloth: a swallowtail with a slight wave, gold-bordered, the royal lion's disc.
	var outline := PackedVector2Array([Vector2(-0.58, HIGH - 0.18), Vector2(0.58, HIGH - 0.18), Vector2(0.58, HIGH - 1.95), Vector2(0.0, HIGH - 1.55), Vector2(-0.58, HIGH - 1.95)])
	var inner := PackedVector2Array()
	for q in outline:
		inner.append(Vector2(q.x * 0.84, lerpf(HIGH - 0.95, q.y, 0.9)))
	p.ink(GOLD, 0.6)
	p.slab(outline, 0.02, 0.06)
	p.ink(BLUE, 0.3)
	p.slab(inner, 0.0, 0.085)
	p.ink(GOLD, 0.9, 0.4)
	p.ball(Vector3(0, HIGH - 0.85, 0.1), Vector3(0.26, 0.26, 0.04), 8, 3)
	p.ink(NAVY, 0.2)
	p.gem(Vector3(0, HIGH - 0.85, 0.13), Vector3(0.11, 0.14, 0.03))
	return p


static func _banners() -> ArrayMesh:
	if M.has("vanguard_banners"):
		return M.get_mesh("vanguard_banners")
	var st := K.begin()
	var part := _banner()
	for i in BANNERS:
		var at := _spot(i)
		var yaw := atan2(at.x, at.z)
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, yaw).rotated(Vector3(cos(yaw), 0, -sin(yaw)), 0.06), at), 0.06 * float(i), 1.0)
	return M.keep("vanguard_banners", K.finish(st, Vector3(0.5, 5.0, 0.5)))


## The royal seal: two gold rings, crenellated ticks, a blue band between.
static func _seal() -> ArrayMesh:
	if M.has("vanguard_seal"):
		return M.get_mesh("vanguard_seal")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ring(st, 1.0, 0.05, M.a(GOLD, 1.0), 0.0, 72)
	K.ring(st, 0.86, 0.12, M.a(BLUE, 0.8), 0.0, 72)
	K.ring(st, 0.74, 0.025, M.a(GOLD, 0.9), 0.0, 72)
	for i in 24:
		var ang := TAU * float(i) / 24.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		if i % 2 == 0:
			K.ribbon(st, PackedVector3Array([dir * 0.93 - side * 0.05, dir * 0.93 + side * 0.05]), 0.08, M.a(GOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
		else:
			K.ribbon(st, PackedVector3Array([dir * 0.6, dir * 0.72]), 0.025, M.a(PALE, 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("vanguard_seal", K.finish(st, Vector3.ONE * 0.2, false))


## A column of light rising from every banner.
static func _columns() -> ArrayMesh:
	if M.has("vanguard_columns"):
		return M.get_mesh("vanguard_columns")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BANNERS:
		var at := _spot(i)
		K.beam(st, at, 9.0, 0.9, M.a(GOLD, 0.75), 2, 0.03 * float(i), 0.0, 0.2)
		K.disc(st, 1.0, M.a(PALE, 0.8), 0.04, 16, 0.03 * float(i), Vector3.UP, at, M.a(GOLD, 0.0), -1.0)
	return M.keep("vanguard_columns", K.finish(st, Vector3.ONE * 0.3, false))


## Ribs of gold arching from the banners over the company (a pavilion of light).
static func _ribs() -> ArrayMesh:
	if M.has("vanguard_ribs"):
		return M.get_mesh("vanguard_ribs")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BANNERS:
		var at := _spot(i)
		var pts := PackedVector3Array()
		for k in 13:
			var t := float(k) / 12.0
			var ang := t * PI * 0.5
			pts.append(at * cos(ang) * 0.98 + Vector3.UP * (HIGH + sin(ang) * 2.2))
		var side := Vector3(at.z, 0, -at.x).normalized()
		K.ribbon(st, pts, 0.28, M.a(GOLD, 0.9), 0.02 * float(i), 0.0, side, 0.0, 0.0, 1.0, M.a(PALE, 0.4))
	return M.keep("vanguard_ribs", K.finish(st, Vector3.ONE * 0.3, false))


## The royal crest: a blue shield under a gold crown, facing +Z.
static func _crest() -> ArrayMesh:
	if M.has("vanguard_crest"):
		return M.get_mesh("vanguard_crest")
	var st := K.begin()
	K.stamp(st, M.shield(BLUE, GOLD, PALE))
	K.stamp(st, M.crown(GOLD, BLUE.lightened(0.2)), Transform3D(Basis().scaled(Vector3(0.3, 0.32, 0.12)), Vector3(0, 0.84, 0)))
	return M.keep("vanguard_crest", K.finish(st, Vector3.ONE * 0.5))


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var stay := time + 1.5
	var gap := K.facing(art)
	# The banners and the seal stand through the muster: a root of their own (the wind-up's
	# root ends with the warrior's motion).
	var hold := M.stage(art, stay, "StarStage_" + ID)
	if hold == null:
		return false
	# The banners rise first (they carry the wind-up), then the seal draws itself round them.
	K.put(hold, K.SOLID, _banners(), "VanguardBanners", Vector3.ZERO, Vector3.ONE, stay, {"drop": -4.6, "flight": time * 0.75, "ease": 1.0, "rim_color": PALE, "rim": 0.55, "glow_color": PALE}, {"fade_in": 0.05, "decay": 0.86}, Vector3(0, gap, 0))
	K.put(hold, K.FLAT, _seal(), "VanguardSeal", Vector3.UP * 0.06, Vector3.ONE * (RING + 0.9), stay, {"sweep": time * 0.7, "soft": 0.5, "hot": M.hot(GOLD, 0.8), "core": 0.5, "add": 0.45}, {"initial": 0.6, "grow_time": 0.4, "fade_in": 0.05, "spin": 0.12, "decay": 0.85})
	M.dust(art, "vanguard_dust", Color("bfa58a"), 16, RING - 0.4, RING + 0.4, 0.0, time + 0.3, Vector3.ZERO, 0.8, 41)
	M.sparks(art, "vanguard_motes", [GOLD, PALE, BLUE.lightened(0.3)], 26, 0.4, RING, 0.3, 2.0, 0.13, 0.1, time + 0.4, Vector3.ZERO, -1.4, 42, 0.1, 1.0)
	hold._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index > 0:
		return true
	var gap := K.facing(art)
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The muster: light from every banner, the pavilion of ribs, the crest over the warrior.
	K.put(art, K.FLAT, _columns(), "VanguardColumns", Vector3.ZERO, Vector3.ONE, 0.9, {"soft": 1.6, "hot": M.hot(PALE, 0.8), "core": 0.6, "flow": 2.5, "flash": 0.3, "add": 0.7}, {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.35}, Vector3(0, gap, 0))
	K.put(art, K.SOLID, _crest(), "VanguardCrest", Vector3.UP * 3.0, Vector3.ONE * 2.1, 1.5, {"rim_color": PALE, "rim": 0.7, "glow_color": PALE, "heat": 0.4}, {"initial": 0.3, "grow_time": 0.18, "fade_in": 0.03, "decay": 0.75, "face_camera": true, "travel": Vector3.UP * 1.1})
	K.put(art, K.FLAT, _ribs(), "VanguardRibs", Vector3.ZERO, Vector3.ONE, 1.1, {"sweep": 0.3, "soft": 0.8, "hot": M.hot(GOLD, 0.8), "core": 0.5, "add": 0.6}, {"fade_in": 0.02, "decay": 0.55}, Vector3(0, gap, 0))
	M.shock(art, "vanguard_ring", GOLD, reach * 1.35, 0.02, 0.7, 0.12)
	M.sparks(art, "vanguard_burst", [GOLD, PALE, BLUE.lightened(0.35)], 40, 0.5, RING, 2.2, 6.0, 0.16, 0.0, 1.4, Vector3.ZERO, 2.5, 43, 0.3, 3.0)
	M.shock(art, "vanguard_ring_b", BLUE, reach * 0.9, 0.12, 0.6, 0.2)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	# The company's blessing drifts up: gold motes and a soft glow over the seal.
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 2.0, "StarAfter_" + ID, source)
	if after:
		M.flash(after, "vanguard_glow", BLUE, RING + 1.0, 0.0, 0.8)
		M.sparks(after, "vanguard_drift", [GOLD, PALE], 30, 0.5, RING + 0.5, 0.2, 1.6, 0.12, 0.2, 1.8, Vector3.ZERO, -0.8, 44, 0.3, 2.0)
		after._draw()
	return true
