extends RefCounted
## Assassin 100 stars "Shadow Execution": a blur of cuts, then the execution. Wind-up: the
## execution mark (a crimson ring with crossed daggers) burns under the target and the
## assassin's shadow gathers. Cuts 1-5: crimson arcs whip round the target from a new angle
## each time, and a shadow afterimage of the assassin flickers at a new spot round it. The
## sixth: every afterimage closes in and a towering crimson crescent falls through the target
## like a guillotine, a spray of dark petals and a cross scar in the ground. Blood crimson,
## blush and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const CRIMSON := Color("ff3a6e")
const BLUSH := Color("ffd0dc")
const WINE := Color("4a0828")
const INK := Color(0.04, 0.01, 0.05)
const ID := "shadow_execution"
## The angle round the target each cut comes from, and the tilt of its arc.
const ANGLES := [0.6, -1.4, 2.4, -0.4, 1.6]
const TILTS := [0.5, -0.7, 1.1, -0.3, 0.2]


## The execution mark (radius 1): a crimson ring, two crossed daggers.
static func _mark() -> ArrayMesh:
	if M.has("execution_mark"):
		return M.get_mesh("execution_mark")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(WINE, 0.55), 0.0, 36, 0.0, Vector3.UP, Vector3.ZERO, M.a(WINE, 0.0), 0.0, true)
	K.ring(st, 0.95, 0.08, M.a(CRIMSON, 1.0), 0.002, 56)
	for s in [-1.0, 1.0]:
		var dir := Vector3(s * 0.7071, 0.004, 0.7071)
		K.ribbon(st, PackedVector3Array([-dir * 0.7, dir * 0.2, dir * 0.75]), 0.12, M.a(CRIMSON, 1.0), 0.0, 0.0, Vector3.UP, 0.7)
		var guard := Vector3(dir.z, 0, -dir.x)
		K.ribbon(st, PackedVector3Array([-dir * 0.45 - guard * 0.16, -dir * 0.45 + guard * 0.16]), 0.06, M.a(BLUSH, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("execution_mark", K.finish(st, Vector3.ONE * 0.2, false))


## One whip of a cut: an arc round the target's middle (radius 1.4), in a plane tilted by
## [param tilt] about the line of approach.
static func _whip(index: int) -> ArrayMesh:
	var key := "execution_whip%d" % index
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt: float = TILTS[index]
	var u := Vector3.RIGHT
	var v := Vector3(0, cos(tilt), sin(tilt))
	var center := Vector3(0, 1.2, 0)
	var pts := M.arc_in(center, u, v, 1.45, -2.4, 0.6, 20)
	var inner := M.arc_in(center, u, v, 1.25, -2.4, 0.6, 20)
	var normal := u.cross(v)
	K.ribbon(st, pts, 0.55, M.a(CRIMSON, 0.95), 0.0, 0.0, normal, 1.0, 0.0, 1.0, M.a(BLUSH, 0.95))
	K.ribbon(st, inner, 0.14, M.a(INK, 1.0), 0.0, 0.0, normal, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.3, false))


## The guillotine: a tall crescent in the XY plane, falling through the origin.
static func _guillotine() -> ArrayMesh:
	if M.has("execution_guillotine"):
		return M.get_mesh("execution_guillotine")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := M.arc_in(Vector3(-1.7, 3.0, 0), Vector3.RIGHT, Vector3.UP, 3.1, 1.2, -1.2, 26)
	var inner := M.arc_in(Vector3(-1.7, 3.0, 0), Vector3.RIGHT, Vector3.UP, 2.75, 1.2, -1.2, 26)
	K.ribbon(st, pts, 1.6, M.a(CRIMSON, 0.95), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, M.a(BLUSH, 0.95))
	K.ribbon(st, inner, 0.4, M.a(INK, 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("execution_guillotine", K.finish(st, Vector3.ONE * 0.4, false))


## The afterimages closing in: five shadows round the target, lunging at it.
static func _court() -> ArrayMesh:
	if M.has("execution_court"):
		return M.get_mesh("execution_court")
	var st := K.begin()
	var part := M.figure(INK, WINE, CRIMSON)
	for i in 5:
		var ang: float = ANGLES[i]
		var at := Vector3(sin(ang), 0, cos(ang)) * 1.9
		K.stamp(st, part, Transform3D(Basis(Vector3.UP, ang + PI).scaled(Vector3.ONE * 1.05), at), 0.015 * float(i), 1.0)
	return M.keep("execution_court", K.finish(st, Vector3.ONE * 2.0))


## The cross scar left in the ground (radius 1).
static func _scar() -> ArrayMesh:
	if M.has("execution_scar"):
		return M.get_mesh("execution_scar")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ang := PI * 0.25 + PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var pts := PackedVector3Array([-dir, Vector3.ZERO, dir])
		K.ribbon(st, pts, 0.16, M.a(CRIMSON, 0.9), 0.05 * float(k), 0.0, Vector3.UP, 1.0)
		K.ribbon(st, pts, 0.06, M.a(INK, 1.0), 0.05 * float(k), 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("execution_scar", K.finish(st, Vector3.ONE * 0.2, false))


static func _figure() -> ArrayMesh:
	return M.solid("execution_figure", M.figure(INK, WINE, CRIMSON))


static func telegraph(art: StarSkillArt, caster: Node3D, _skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	K.put(art, K.BITS, K.burst("execution_smoke", "puff", 16, 0.2, 0.9, 0.3, 1.6, [Color(0.1, 0.02, 0.06), Color(0.2, 0.04, 0.1), INK], 0.6, 0.6, 151, 0.05, 0.4), "ExecutionSmoke", Vector3.ZERO, Vector3.ONE, time + 0.2, {"life": 0.8, "gravity": -1.0, "drag": 1.5, "piece": 0.6, "swell": 1.6, "alpha": 0.6, "shrink": 0.4, "spin": 2.0}, {"fade_in": 0.05, "decay": 0.9})
	var hold := time + 0.86 + 0.2
	var mark := K.extra(parent, Vector3(point.x, 0, point.z), hold + 0.5, "StarMark_" + ID, caster.global_position)
	if mark:
		K.put(mark, K.FLAT, _mark(), "ExecutionMark", Vector3.UP * 0.06, Vector3.ONE * 1.7, hold + 0.5, {"soft": 0.45, "hot": M.hot(CRIMSON, 0.8), "core": 0.5, "flick": 0.1, "add": 0.55}, {"initial": 2.0, "grow_time": 0.35, "fade_in": 0.08, "spin": 0.5, "decay": 0.85}, Vector3(0, K.facing(mark) + PI, 0))
		mark._draw()
	return true


static func strike(art: StarSkillArt, parent: Node3D, _skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if index < 5:
		var ang: float = ANGLES[index]
		K.put(art, K.FLAT, _whip(index), "ExecutionWhip", Vector3.ZERO, Vector3.ONE, 0.26, {"sweep": 0.05, "tail": 2.5, "soft": 0.7, "hot": M.hot(BLUSH), "core": 0.42, "add": 0.65, "gain": 1.1}, {"fade_in": 0.01, "decay": 0.4}, Vector3(0, ang, 0))
		var at := Vector3(sin(ang), 0, cos(ang)) * 1.8
		K.put(art, K.SOLID, _figure(), "ExecutionShade", at, Vector3.ONE * 1.05, 0.3, {"rim_color": CRIMSON, "rim": 1.3, "glow_color": Color("ff6a8a"), "dim": 0.8}, {"fade_in": 0.01, "decay": 0.35}, Vector3(0, ang + PI, 0))
		M.sparks(art, "execution_sparks", [CRIMSON, BLUSH], 10, 0.05, 0.4, 3.5, 2.0, 0.1, 0.0, 0.45, Vector3.UP * 1.0, 6.0, 152, -0.2, 0.3)
		return true
	# The execution: the shadows close in, the guillotine falls.
	K.put(art, K.SOLID, _court(), "ExecutionCourt", Vector3.ZERO, Vector3.ONE, 0.5, {"rim_color": CRIMSON, "rim": 1.3, "glow_color": Color("ff6a8a"), "dim": 0.8}, {"initial": 1.5, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.5})
	K.put(art, K.FLAT, _guillotine(), "ExecutionGuillotine", Vector3.ZERO, Vector3.ONE * 1.15, 0.55, {"sweep": 0.08, "tail": 3.0, "soft": 0.7, "hot": M.hot(BLUSH), "core": 0.4, "add": 0.65, "gain": 1.2}, {"fade_in": 0.01, "decay": 0.45, "face_camera": true})
	K.put(art, K.BITS, K.burst("execution_petals", "feather", 36, 0.2, 1.0, 4.0, 4.5, [CRIMSON, WINE, INK, BLUSH], 0.4, 0.08, 153, 0.6, 1.8), "ExecutionPetals", Vector3.ZERO, Vector3.ONE, 1.6, {"life": 1.4, "gravity": 3.0, "drag": 1.2, "piece": 0.4, "sway": 0.4, "spin": 6.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
	M.shock(art, "execution_ring", CRIMSON, 3.6, 0.03, 0.45, 0.18)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var after := K.extra(parent, Vector3(point.x, 0, point.z), 1.6, "StarAfter_" + ID, source)
	if after:
		K.put(after, K.FLAT, _scar(), "ExecutionScar", Vector3.UP * 0.07, Vector3.ONE * 2.4, 1.5, {"sweep": 0.08, "soft": 0.5, "hot": M.hot(CRIMSON), "core": 0.4, "flick": 0.12, "add": 0.6}, {"decay": 0.65})
		M.flash(after, "execution_pool", WINE, 2.2, 0.0, 0.9)
		M.sparks(after, "execution_drops", [CRIMSON, BLUSH, WINE], 24, 0.1, 0.6, 3.0, 4.0, 0.13, 0.0, 0.9, Vector3.UP * 1.0, 7.0, 154, -0.2, 0.5)
		after._draw()
	return true
