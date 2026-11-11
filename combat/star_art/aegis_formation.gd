extends RefCounted
## Lancer 150 stars "Aegis Formation": the phalanx locks shields. Wind-up: a formation grid
## draws itself on the ground and a ring of tall spectral tower shields rises round the
## lancer, a spear standing upright behind each (the ring opens towards the camera). Release:
## the spears drop level, points outward, over the shield rims with a flash on every point;
## a wall of blue light runs up round the formation, gold chevrons race round its foot and a
## ring of light rolls out to the allies. Sky blue, steel, gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const BLUE := Color("4aa8ff")
const NAVY := Color("1e3f78")
const STEEL := Color("c8daf0")
const GOLD := Color("ffd25a")
const PALE := Color("fff2b0")
const ID := "aegis_formation"
const RING := 3.0
const COUNT := 7
const TALL := 2.1


static func _spot(i: int) -> float:
	return lerpf(0.62, TAU - 0.62, float(i) / float(COUNT - 1))


## A tall tower shield standing on the origin, face to +Z, 2.1 tall.
static func _tower() -> K.Part:
	var p := K.Part.new()
	var w := 0.55
	p.ink(GOLD, 0.8)
	p.box(Vector3(0, TALL * 0.5, 0), Vector3(w * 2.0 + 0.1, TALL, 0.1))
	p.ink(BLUE, 0.5)
	p.box(Vector3(0, TALL * 0.5, 0.03), Vector3(w * 2.0 - 0.1, TALL - 0.16, 0.1))
	p.box(Vector3(0, TALL * 0.5, -0.03), Vector3(w * 2.0 - 0.1, TALL - 0.16, 0.1))
	p.ink(NAVY, 0.3)
	p.box(Vector3(0, TALL * 0.5, 0.06), Vector3(0.12, TALL - 0.3, 0.06))
	p.box(Vector3(0, TALL * 0.62, 0.06), Vector3(w * 2.0 - 0.3, 0.12, 0.06))
	p.ink(GOLD, 1.0, 0.4)
	p.gem(Vector3(0, TALL * 0.62, 0.12), Vector3(0.14, 0.16, 0.08))
	return p


## The shield ring, opening at +Z (turned to the camera at run time).
static func _shields() -> ArrayMesh:
	if M.has("aegis_shields"):
		return M.get_mesh("aegis_shields")
	var st := K.begin()
	var part := _tower()
	for i in COUNT:
		var ang := _spot(i)
		var at := Vector3(sin(ang), 0, cos(ang)) * RING
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, ang), at), 0.04 * float(i), 1.0)
	return M.keep("aegis_shields", K.finish(st, Vector3(0.5, 4.0, 0.5)))


## The spears behind the shields: upright, or lowered over the rims, points outward.
static func _spears(lowered: bool) -> ArrayMesh:
	var key := "aegis_spears_low" if lowered else "aegis_spears_up"
	if M.has(key):
		return M.get_mesh(key)
	var st := K.begin()
	var part := M.lance(Color("3a2a30"), STEEL, BLUE.lightened(0.3))
	for i in COUNT:
		var ang := _spot(i)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var basis := Basis(Vector3.UP, ang)
		var xf: Transform3D
		if lowered:
			xf = Transform3D((basis * Basis(Vector3.RIGHT, PI * 0.5 - 0.08)).scaled(Vector3.ONE * 3.6), dir * (RING - 1.6) + Vector3.UP * 1.5)
		else:
			xf = Transform3D(basis.scaled(Vector3.ONE * 3.6), dir * (RING - 0.45) + Vector3.UP * 0.1)
		K.stamp(st, part, xf, 0.03 * float(i), 1.0)
	return M.keep(key, K.finish(st, Vector3(0.5, 4.0, 0.5)))


## The formation grid on the ground (radius 1): rings, spokes and chevrons.
static func _grid() -> ArrayMesh:
	if M.has("aegis_grid"):
		return M.get_mesh("aegis_grid")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.ring(st, 1.0, 0.04, M.a(BLUE, 1.0), 0.0, 64)
	K.ring(st, 0.62, 0.025, M.a(BLUE, 0.8), 0.0, 64)
	for i in 12:
		var ang := TAU * float(i) / 12.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(cos(ang), 0, -sin(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.62, dir * 1.0]), 0.018, M.a(STEEL, 0.7), 0.0, 0.0, Vector3.UP, 0.0)
		var c := dir * 0.81
		K.ribbon(st, PackedVector3Array([c - side * 0.08 - dir * 0.05, c + dir * 0.04, c + side * 0.08 - dir * 0.05]), 0.03, M.a(GOLD, 0.95), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("aegis_grid", K.finish(st, Vector3.ONE * 0.2, false))


## A wall of light round the formation (radius 1, 1 tall, open towards +Z).
static func _wall() -> ArrayMesh:
	if M.has("aegis_wall"):
		return M.get_mesh("aegis_wall")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var a0 := lerpf(0.45, TAU - 0.45, float(i) / float(n))
		var a1 := lerpf(0.45, TAU - 0.45, float(i + 1) / float(n))
		var p0 := Vector3(sin(a0), 0, cos(a0))
		var p1 := Vector3(sin(a1), 0, cos(a1))
		st.set_normal(Vector3.UP)
		st.set_uv2(Vector2.ZERO)
		for item in [[p0, 0.0, 0.0], [p1, 1.0, 0.0], [p1 + Vector3.UP, 1.0, 1.0], [p0, 0.0, 0.0], [p1 + Vector3.UP, 1.0, 1.0], [p0 + Vector3.UP, 0.0, 1.0]]:
			var h: float = item[2]
			st.set_color(M.a(BLUE.lerp(PALE, 0.15), 0.7 * (1.0 - h)))
			st.set_uv(Vector2(0.5, -1.0 - h))
			st.add_vertex(item[0])
	K.ring(st, 1.0, 0.05, M.a(GOLD, 1.0), 0.0, 64, 0.0, TAU - 0.9, 0.45)
	return M.keep("aegis_wall", K.finish(st, Vector3.ONE * 0.2, false))


## A flash on every spear point.
static func _glints() -> ArrayMesh:
	if M.has("aegis_glints"):
		return M.get_mesh("aegis_glints")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in COUNT:
		var ang := _spot(i)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var at := dir * (RING + 1.95) + Vector3.UP * 1.55
		var side := Vector3(cos(ang), 0, -sin(ang))
		K.ribbon(st, PackedVector3Array([at - side * 0.5, at + side * 0.5]), 0.18, M.a(PALE, 0.95), 0.0, 0.0, dir, 1.0)
		K.ribbon(st, PackedVector3Array([at - Vector3.UP * 0.5, at + Vector3.UP * 0.5]), 0.18, M.a(PALE, 0.95), 0.0, 0.0, dir, 1.0)
	return M.keep("aegis_glints", K.finish(st, Vector3.ONE * 0.3, false))


static func telegraph(art: StarSkillArt, _caster: Node3D, _skill: Dictionary, _point: Vector3, time: float) -> bool:
	var gap := Vector3(0, K.facing(art), 0)
	var stay := time + 1.4
	# The shield ring and its grid stand through the release: a root of their own (the
	# wind-up's root ends with the lancer's motion).
	var hold := M.stage(art, stay, "StarStage_" + ID)
	if hold == null:
		return false
	K.put(hold, K.SOLID, _shields(), "AegisShields", Vector3.ZERO, Vector3.ONE, stay, {"drop": -2.6, "flight": time * 0.7, "ease": 1.0, "rim_color": PALE, "rim": 0.6, "glow_color": PALE}, {"fade_in": 0.05, "decay": 0.85}, gap)
	K.put(art, K.SOLID, _spears(false), "AegisSpearsUp", Vector3.ZERO, Vector3.ONE, time + 0.02, {"drop": -4.0, "flight": time * 0.8, "ease": 1.0, "rim_color": BLUE, "rim": 0.6, "glow_color": BLUE.lightened(0.4)}, {"fade_in": 0.05, "decay": 0.99}, gap)
	K.put(hold, K.FLAT, _grid(), "AegisGrid", Vector3.UP * 0.06, Vector3.ONE * (RING + 0.8), stay, {"sweep": time * 0.6, "soft": 0.5, "hot": M.hot(BLUE, 0.8), "core": 0.5, "add": 0.45}, {"initial": 0.7, "grow_time": 0.4, "fade_in": 0.05, "spin": -0.15, "decay": 0.85})
	M.dust(art, "aegis_dust", Color("b6b8c0"), 14, RING - 0.3, RING + 0.4, 0.0, time + 0.3, Vector3.ZERO, 0.75, 81)
	hold._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index > 0:
		return true
	var gap := Vector3(0, K.facing(art), 0)
	var reach := clampf(float(skill.get("radius", 8.0)), 4.0, 9.0)
	# The spears drop level over the shield rims, and the formation locks in light.
	K.put(art, K.SOLID, _spears(true), "AegisSpearsLow", Vector3.ZERO, Vector3.ONE, 1.4, {"heat": 0.5, "rim_color": BLUE, "rim": 0.7, "glow_color": PALE}, {"fade_in": 0.01, "decay": 0.85}, gap)
	K.put(art, K.FLAT, _wall(), "AegisWall", Vector3.UP * 0.05, Vector3(RING + 0.35, 3.2, RING + 0.35), 1.0, {"soft": 0.4, "flow": 1.8, "add": 0.6, "gain": 1.1}, {"initial": 0.9, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.45}, gap)
	K.put(art, K.FLAT, _glints(), "AegisGlints", Vector3.ZERO, Vector3.ONE, 0.35, {"soft": 0.8, "hot": M.hot(PALE), "core": 0.4, "add": 0.75}, {"initial": 0.3, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.3}, gap)
	M.shock(art, "aegis_ring", BLUE, reach * 1.35, 0.03, 0.7, 0.12)
	M.sparks(art, "aegis_motes", [BLUE.lightened(0.3), GOLD, PALE], 30, RING - 0.3, RING + 0.3, 0.4, 3.5, 0.13, 0.0, 1.2, Vector3.ZERO, -0.6, 82, 0.2, 2.0)
	M.shock(art, "aegis_ring_b", GOLD, RING + 0.6, 0.0, 0.5, 0.25)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.8, "StarAfter_" + ID, source)
	if after:
		M.flash(after, "aegis_glow", BLUE, RING + 0.8, 0.0, 0.7)
		M.pillar(after, "aegis_pillar", BLUE, 1.4, 6.0, 0.0, 0.6)
		after._draw()
	return true
