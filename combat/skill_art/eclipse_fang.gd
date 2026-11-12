extends RefCounted
## Assassin Lv.80 "Eclipse Fang": the twin daggers close on one foe like the jaws of an
## eclipse. Wind-up: behind the foe the sun goes black, a crimson corona flickering round it,
## and two fang glints open above and below the foe. Release: two great crimson fangs snap
## shut across the foe (the upper one sweeping down, the lower one up), the eclipse flares,
## a second, smaller bite follows, dark petals spray, a crossed scar is torn in the ground
## and a ring of crimson rolls out. Blood crimson, ink black and a blush corona.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "eclipse_fang"
const CRIMSON := Color("ff4f7b")
const BLUSH := Color("ffd0dc")
const WINE := Color("4a0828")
const EMBER := Color("ff8a5a")
const INK := Color(0.05, 0.01, 0.05)
const MID := 1.15
const BEHIND := 2.2


## One fang: a curved crescent in XY (facing +Z), its point at the right end; [param upper]
## bows downward (the upper jaw), else upward.
static func _fang(upper: bool) -> ArrayMesh:
	var key := "ef_fang_%d" % int(upper)
	if M.has(key):
		return M.get_mesh(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 1.0 if upper else -1.0
	var center := Vector3(0, s * 1.05, 0)
	var u := Vector3.RIGHT
	var v := Vector3(0, s, 0)
	# The arc from left (-160 deg) round under/over to right (-20 deg).
	G.crescent(st, center, u, v, 1.25, PI + 0.35, TAU - 0.35, 0.5, M.a(CRIMSON, 0.95), M.a(BLUSH, 0.95), M.a(INK, 1.0), 0.0, 20)
	return M.keep(key, K.finish(st, Vector3.ONE * 0.5, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	var face := K.facing(r)
	var behind := K.away(r) * BEHIND
	G.flat(r, G.eclipse("ef_eclipse", CRIMSON, BLUSH, 14), "Eclipse", behind + Vector3.UP * 3.1, Vector3.ONE * 0.9, time + 0.04, G.lit(CRIMSON, 0.6, 0.6, {"flick": 0.12}), {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.98, "spin": 0.0}, Vector3(G.TILT_BACK, face, 0))
	G.flat(r, _fang(true), "Upper", Vector3.UP * (MID + 0.9), Vector3.ONE * 0.75, time + 0.04, G.lit(BLUSH, 0.6, 0.6), {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.95}, Vector3(G.TILT_BACK, face, 0))
	G.flat(r, _fang(false), "Lower", Vector3.UP * (MID - 0.75), Vector3.ONE * 0.75, time + 0.04, G.lit(BLUSH, 0.6, 0.6), {"initial": 0.5, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.95}, Vector3(G.TILT_BACK, face, 0))
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var r := G.open(parent, spot, 1.4, "Skill_%s_bite" % ID, G.yaw(origin, spot, G.facing(caster)), caster)
	if r == null:
		return false
	var face := K.facing(r)
	var behind := K.away(r) * BEHIND
	var lean := Vector3(G.TILT_BACK, face, 0)
	# The jaws snap shut across the foe.
	G.flat(r, _fang(true), "Upper", Vector3.UP * (MID + 0.4), Vector3.ONE * 1.6, 0.45, G.lit(CRIMSON, 0.7, 0.6, {"sweep": 0.06, "tail": 3.0}), {"travel": Vector3.DOWN * 0.7, "initial": 0.85, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.5}, lean + Vector3(0, 0, 0.25))
	G.flat(r, _fang(false), "Lower", Vector3.UP * (MID - 0.4), Vector3.ONE * 1.6, 0.45, G.lit(CRIMSON, 0.7, 0.6, {"sweep": 0.06, "tail": 3.0}), {"travel": Vector3.UP * 0.7, "initial": 0.85, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.5}, lean + Vector3(0, 0, 0.25))
	G.flat(r, G.eclipse("ef_eclipse", CRIMSON, BLUSH, 14), "Flare", behind + Vector3.UP * 3.1, Vector3.ONE * 1.05, 1.0, G.lit(CRIMSON, 0.65, 0.6, {"flick": 0.1}), {"initial": 0.9, "grow_time": 0.12, "fade_in": 0.01, "decay": 0.6, "spin": 0.6}, lean)
	G.bits(r, G.spray("ef_spray", G.n(28), [CRIMSON, WINE, INK, BLUSH], 0.32, 801, 4.2, 3.0), "Spray", Vector3.UP * MID, 1.2, {"life": 1.0, "gravity": 6.0, "drag": 1.2, "piece": 0.32, "sway": 0.25, "spin": 7.0, "floor_y": 0.06 - MID, "shrink": 0.85}, {"delay": 0.04, "decay": 0.85})
	M.shock(r, "ef_ring", CRIMSON, 2.6, 0.02, 0.42, 0.16)
	G.flat(r, G.rays("ef_scar", 6, CRIMSON, 0.12, 0.05, 802), "Scar", Vector3.UP * 0.06, Vector3.ONE * 1.8, 1.3, G.lit(CRIMSON, 0.55, 0.5, {"flick": 0.1, "sweep": 0.1}), {"delay": 0.03, "fade_in": 0.02, "decay": 0.7})
	G.done(r)
	if G.extras(1) > 0:
		var echo := G.open(parent, spot, 1.0, "Skill_%s_echo" % ID, r.rotation.y, caster)
		if echo:
			# A second, smaller bite at a slant.
			G.flat(echo, _fang(true), "Upper", Vector3.UP * MID, Vector3.ONE * 0.85, 0.36, G.lit(EMBER, 0.7, 0.7, {"sweep": 0.05, "tail": 2.0}), {"delay": 0.12, "fade_in": 0.01, "decay": 0.5}, lean + Vector3(0, 0, -0.6))
			G.flat(echo, _fang(false), "Lower", Vector3.UP * MID, Vector3.ONE * 0.85, 0.36, G.lit(EMBER, 0.7, 0.7, {"sweep": 0.05, "tail": 2.0}), {"delay": 0.12, "fade_in": 0.01, "decay": 0.5}, lean + Vector3(0, 0, -0.6))
			M.flash(echo, "ef_pool", WINE, 1.6, 0.0, 0.8)
			M.sparks(echo, "ef_sparks", [CRIMSON, BLUSH, EMBER], G.n(14), 0.05, 0.4, 3.5, 2.5, 0.1, 0.12, 0.5, Vector3.UP * MID, 6.0, 803, -0.2, 0.3)
			G.done(echo)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CRIMSON, BLUSH], crit, true)
