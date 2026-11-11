extends RefCounted
## Assassin Lv.64 "Throat Slit": one silent cut, and only afterwards the spray. Wind-up: a
## crimson glint runs along the edge of a blade at the foe's throat, a thin crimson crescent
## moon wakes behind the foe and the assassin's shadow stretches to it. Release: a razor line
## of crimson light opens straight across the foe at throat height and runs wide to both
## sides, the assassin's shadow stands behind the foe for a blink, and a beat later the cut
## bursts: a crescent flare, a spray of dark petals thrown along the cut, a cross scar on
## the ground and the stars of the stun. Blood crimson, blush and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "throat_slit"
const CRIMSON := Color("ff4f7b")
const BLUSH := Color("ffd0dc")
const WINE := Color("4a0828")
const INK := Color(0.05, 0.01, 0.05)
const NECK := 1.35


## The razor line: a long, very thin stroke along X (2 across), its middle hottest.
static func _razor() -> ArrayMesh:
	if M.has("ts_razor"):
		return M.get_mesh("ts_razor")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := PackedVector3Array()
	for i in 17:
		pts.append(Vector3(lerpf(-1.0, 1.0, float(i) / 16.0), 0, 0))
	K.ribbon(st, pts, 0.07, M.a(CRIMSON, 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0)
	K.ribbon(st, pts, 0.02, M.a(BLUSH, 1.0), 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0)
	return M.keep("ts_razor", K.finish(st, Vector3.ONE * 0.2, false))


## The crescent flare behind the cut (facing +Z, radius 1).
static func _flare() -> ArrayMesh:
	if M.has("ts_flare"):
		return M.get_mesh("ts_flare")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	G.crescent(st, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, 1.0, -2.3, -0.84, 0.42, M.a(CRIMSON, 0.95), M.a(BLUSH, 0.9), M.a(INK, 1.0), 0.0, 20)
	return M.keep("ts_flare", K.finish(st, Vector3.ONE * 0.4, false))


static func _scar() -> ArrayMesh:
	if M.has("ts_scar"):
		return M.get_mesh("ts_scar")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var ang := PI * 0.25 + PI * 0.5 * float(k)
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.ribbon(st, PackedVector3Array([-dir, Vector3.ZERO, dir]), 0.16, M.a(CRIMSON, 0.9), 0.05 * float(k), 0.0, Vector3.UP, 1.0)
		K.ribbon(st, PackedVector3Array([-dir, Vector3.ZERO, dir]), 0.06, M.a(INK, 1.0), 0.05 * float(k), 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return M.keep("ts_scar", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	var face := K.facing(r)
	var behind := K.away(r) * 0.9
	G.flat(r, G.moon("ts_moon", CRIMSON, WINE, 0.5), "Moon", behind + Vector3.UP * 3.0, Vector3.ONE * 1.2, time + 0.04, G.lit(CRIMSON, 0.55, 0.6), {"initial": 0.4, "grow_time": 0.8, "fade_in": 0.15, "decay": 0.98}, Vector3(G.TILT_BACK, face, 0))
	G.flat(r, _razor(), "Glint", Vector3.UP * NECK, Vector3(0.4, 1, 1), time + 0.04, G.lit(BLUSH, 0.75, 0.6), {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.2, "decay": 0.95}, Vector3(0, face, 0.12))
	var local_origin := r.to_local(Vector3(origin.x, 0.0, origin.z))
	var reach := local_origin.length()
	if reach > 0.3:
		G.flat(r, G.streak("ts_shadow", Color(0.06, 0.01, 0.06, 0.6), Color(0.06, 0.01, 0.06, 0.1)), "Shadow", Vector3.UP * 0.04, Vector3(0.6, 0.6, reach), time + 0.04, {"soft": 0.5, "add": 0.0, "sweep": time}, {"fade_in": 0.05, "decay": 0.95}, Vector3(0, atan2(local_origin.x, local_origin.z), 0))
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var r := G.open(parent, spot, 1.4, "Skill_%s_cut" % ID, G.yaw(origin, spot, G.facing(caster)), caster)
	if r == null:
		return false
	var face := K.facing(r)
	var behind := K.away(r) * 0.75
	# The silent line, wide across the throat; the burst a beat later.
	G.flat(r, _razor(), "Razor", Vector3.UP * NECK, Vector3(3.4, 2.4, 1), 0.55, G.lit(BLUSH, 0.8, 0.6, {"sweep": 0.05}), {"initial": 0.15, "grow_time": 0.18, "fade_in": 0.01, "decay": 0.55}, Vector3(0, face, 0.12))
	G.solid(r, M.solid("ts_figure", M.figure(INK, WINE, CRIMSON)), "Blink", behind, Vector3.ONE * 1.0, 0.32, {"rim_color": CRIMSON, "rim": 1.4, "glow_color": Color("ff7a9a"), "dim": 0.8}, {"fade_in": 0.01, "decay": 0.35}, Vector3(0, face + PI, 0))
	G.flat(r, _flare(), "Flare", Vector3.UP * NECK, Vector3.ONE * 2.1, 0.55, G.lit(CRIMSON, 0.7, 0.6, {"sweep": 0.06, "tail": 3.0}), {"delay": 0.14, "initial": 0.7, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.5}, Vector3(G.TILT_BACK, face, 0.4))
	G.bits(r, G.spray("ts_spray", G.n(26), [CRIMSON, WINE, INK, BLUSH], 0.3, 604), "Spray", Vector3.UP * NECK, 1.2, {"life": 1.0, "gravity": 6.0, "drag": 1.2, "piece": 0.3, "sway": 0.2, "spin": 7.0, "floor_y": 0.06 - NECK, "shrink": 0.85}, {"delay": 0.14, "decay": 0.85})
	G.flat(r, _scar(), "Scar", Vector3.UP * 0.06, Vector3.ONE * 1.6, 1.35, G.lit(CRIMSON, 0.55, 0.5, {"flick": 0.1}), {"delay": 0.16, "fade_in": 0.02, "decay": 0.7}, Vector3(0, face, 0))
	M.sparks(r, "ts_sparks", [CRIMSON, BLUSH], G.n(12), 0.05, 0.3, 3.0, 2.0, 0.09, 0.14, 0.5, Vector3.UP * NECK, 6.0, 641, -0.2, 0.2)
	G.done(r)
	if G.extras(1) > 0:
		var after := G.open(parent, spot, 1.2, "Skill_%s_after" % ID, r.rotation.y, caster)
		if after:
			M.shock(after, "ts_ring", CRIMSON, 2.2, 0.14, 0.4, 0.14)
			M.flash(after, "ts_pool", WINE, 1.6, 0.14, 0.7)
			G.daze(after, Color("ffd070"), Vector3.UP * 2.25, 0.5, 0.9, 0.2, 4)
			G.done(after)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CRIMSON, BLUSH], crit, true)
