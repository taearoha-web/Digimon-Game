extends RefCounted
## Assassin Lv.92 "Midnight Execution": at midnight the assassin drops out of the moon onto
## the pack. Wind-up: over the target area a blood moon rises in the sky, the shadow of the
## assassin dives out of it head first, and the execution mark burns on the ground below.
## Release: a towering crimson crescent falls through the centre like a guillotine, a cross of
## cuts rips out across the whole area, a crimson ring and a pool of darkness spread, dark
## petals fountain up and the stars of the stun spin; the moon fades. Blood crimson, wine,
## a cold moon and ink.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "midnight_execution"
const CRIMSON := Color("ff4f7b")
const BLUSH := Color("ffd0dc")
const WINE := Color("4a0828")
const MOON := Color("d8304e")
const INK := Color(0.05, 0.01, 0.05)
const SKY := 7.5


## The guillotine: a tall crescent in the XY plane (facing +Z), its edge sweeping down
## through the origin.
static func _guillotine() -> ArrayMesh:
	if M.has("me_guillotine"):
		return M.get_mesh("me_guillotine")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	G.crescent(st, Vector3(-1.7, 3.0, 0), Vector3.RIGHT, Vector3.UP, 3.1, 1.2, -1.2, 1.4, M.a(CRIMSON, 0.95), M.a(BLUSH, 0.95), M.a(INK, 1.0), 0.0, 26)
	return M.keep("me_guillotine", K.finish(st, Vector3.ONE * 0.5, false))


## A diving shadow: the figure turned head down (1.9 tall).
static func _diver() -> ArrayMesh:
	if M.has("me_diver"):
		return M.get_mesh("me_diver")
	var st := K.begin()
	K.stamp(st, M.figure(INK, WINE, CRIMSON), Transform3D(Basis(Vector3.RIGHT, PI * 0.85), Vector3(0, 1.6, 0)), 0.0, 1.0)
	return M.keep("me_diver", K.finish(st, Vector3(1, SKY + 2.0, 1)))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var spot := Vector3(aim.x, 0.0, aim.z)
	var radius := float(skill.get("radius", 7.0))
	var r := G.windup(parent, spot, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, spot), visual)
	if r == null:
		return false
	var face := K.facing(r)
	var behind := K.away(r) * 2.0
	var high := G.sky_height(r, behind, SKY)
	G.flat(r, G.moon("me_moon", MOON, WINE.lightened(0.2), 0.0), "Moon", behind + Vector3.UP * high, Vector3.ONE * 1.7, time + 0.04, {"soft": 0.6, "add": 0.5, "hot": M.a(CRIMSON, 0.6), "core": 0.7}, {"travel": Vector3.UP * 0.4, "initial": 0.5, "grow_time": 0.6, "fade_in": 0.1, "decay": 0.98}, Vector3(G.TILT_BACK, face, 0))
	G.solid(r, _diver(), "Dive", Vector3.ZERO, Vector3.ONE, time + 0.04, {"drop": high - 1.0, "flight": time, "ease": 0.0, "rim_color": CRIMSON, "rim": 1.5, "glow_color": BLUSH, "dim": 0.8}, {"fade_in": 0.05, "decay": 0.97}, Vector3(0, face, 0))
	G.flat(r, G.sigil("me_mark", CRIMSON, 2, 24, 4, 0.4), "Mark", Vector3.UP * 0.05, Vector3.ONE * radius * 0.9, time + 0.04, G.lit(CRIMSON, 0.55, 0.5), {"initial": 0.6, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.97, "spin": 0.8})
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var spot := Vector3(center.x, 0.0, center.z)
	var radius := float(skill.get("radius", 7.0))
	var turn := G.yaw(origin, spot, G.facing(caster))
	var r := G.open(parent, spot, 1.8, "Skill_%s_execute" % ID, turn, caster)
	if r == null:
		return false
	var face := K.facing(r)
	var fit := G.sky_fit(r, Vector3.ZERO, 6.2)
	G.flat(r, _guillotine(), "Guillotine", Vector3.ZERO, Vector3.ONE * 1.5 * fit, 0.6, G.lit(CRIMSON, 0.7, 0.6, {"sweep": 0.08, "tail": 3.0}), {"fade_in": 0.01, "decay": 0.5}, Vector3(G.TILT_BACK, face, 0))
	G.flat(r, G.rays("me_cross2", 8, WINE.lightened(0.4), 0.035, 0.1, 921), "Cross", Vector3.UP * 0.06, Vector3.ONE * radius, 1.4, G.lit(CRIMSON, 0.4, 0.6, {"sweep": 0.18, "flick": 0.08}), {"fade_in": 0.01, "decay": 0.7})
	M.shock(r, "me_ring", CRIMSON, radius * 1.04, 0.0, 0.5, 0.18)
	G.bits(r, K.burst("me_petals", "feather", G.n(36), 0.3, 2.0, 4.5, 6.0, [CRIMSON, WINE, INK, BLUSH], 0.38, 0.1, 922, 0.3, 1.2), "Petals", Vector3.ZERO, 1.7, {"life": 1.5, "gravity": 3.0, "drag": 1.2, "piece": 0.38, "sway": 0.4, "spin": 6.0, "floor_y": 0.08, "shrink": 0.85}, {"decay": 0.9})
	G.flat(r, K.glow_disc("me_pool", Color(0.1, 0.01, 0.05, 0.7)), "Pool", Vector3.UP * 0.035, Vector3.ONE * radius * 0.75, 1.7, {"soft": 0.6, "add": 0.0}, {"initial": 0.2, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.75})
	M.sparks(r, "me_sparks", [CRIMSON, BLUSH], G.n(18), 0.2, 1.0, 4.0, 5.0, 0.11, 0.0, 0.8, Vector3.UP * 0.4, 6.0, 923, 0.0, 0.8)
	G.done(r)
	var more := G.extras(2)
	if more > 0:
		var cuts := G.open(parent, spot, 1.5, "Skill_%s_cuts" % ID, turn, caster)
		if cuts:
			G.flat(cuts, G.cut_storm("me_storm2", 16, radius * 0.35, radius * 0.95, 0.35, M.a(CRIMSON, 0.95), M.a(CRIMSON.lightened(0.25), 0.9), M.a(INK, 1.0), 924, 0.3, 1.5, 0.55), "Storm", Vector3.ZERO, Vector3.ONE, 0.95, G.lit(CRIMSON, 0.65, 0.6, {"sweep": 0.08, "tail": 5.0}), {"delay": 0.06, "fade_in": 0.01, "decay": 0.85})
			G.daze(cuts, Color("ffd070"), Vector3(0, 2.5, 0), 1.0, 1.3, 0.15)
			M.cracks(cuts, "me_cracks", CRIMSON, radius * 0.6, 0.02, 1.3, 8, 925, 0.07)
			M.shock(cuts, "me_ring_b", BLUSH, radius * 0.6, 0.1, 0.45, 0.1)
			G.done(cuts)
	if more > 1:
		var sky := G.open(parent, spot, 0.9, "Skill_%s_moon" % ID, turn, caster)
		if sky:
			var behind := K.away(sky) * 2.0
			var high := G.sky_height(sky, behind, SKY)
			G.flat(sky, G.moon("me_moon", MOON, WINE.lightened(0.2), 0.0), "Moon", behind + Vector3.UP * (high + 0.4), Vector3.ONE * 1.7, 0.8, {"soft": 0.6, "add": 0.5, "hot": M.a(CRIMSON, 0.6), "core": 0.7}, {"fade_in": 0.01, "decay": 0.3}, Vector3(G.TILT_BACK, K.facing(sky), 0))
			G.done(sky)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [CRIMSON, BLUSH], crit, true)
