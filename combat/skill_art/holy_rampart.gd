extends RefCounted
## Defender Lv.80 "Holy Rampart": a wall of holy light bursts out round the defender. Wind-up:
## the defender spins up, a holy cross sigil turns under the feet and light rises off it.
## Release: a crenellated rampart of golden light bursts out of the ground and races out to
## the edge of the area, a second, taller wall a beat behind it; pillars of light stand at
## eight gates round the ring, the cross sigil flares across the whole area, feathers of light
## drift and the stars of the stun spin over the foes. Pale gold, honey and dawn rose.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "holy_rampart"
const GOLD := Color("ffe27a")
const HONEY := Color("f0b040")
const PALE := Color("fff3c8")
const ROSE := Color("ffb08a")


## A holy cross sigil (radius 1): rings, a cross of four broad arms, little crosses between.
static func _cross() -> ArrayMesh:
	if M.has("hr_cross"):
		return M.get_mesh("hr_cross")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(HONEY.darkened(0.3), 0.3), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(HONEY, 0.0), 0.0, true)
	K.ring(st, 0.96, 0.05, M.a(GOLD, 1.0), 0.004, 72)
	K.ring(st, 0.82, 0.025, M.a(GOLD, 0.8), 0.004, 64)
	K.ring(st, 0.3, 0.04, M.a(GOLD, 0.9), 0.004, 40)
	for i in 4:
		var a := PI * 0.5 * float(i)
		var dir := Vector3(sin(a), 0.006, cos(a))
		K.ribbon(st, PackedVector3Array([dir * 0.08, dir * 0.5, dir * 0.92]), 0.09, M.a(HONEY, 0.85), 0.0, 0.0, Vector3.UP, 0.6)
		var b := a + PI * 0.25
		var c := Vector3(sin(b), 0.006, cos(b)) * 0.64
		var side := Vector3(cos(b), 0, -sin(b))
		K.ribbon(st, PackedVector3Array([c - Vector3(sin(b), 0, cos(b)) * 0.09, c + Vector3(sin(b), 0, cos(b)) * 0.09]), 0.035, M.a(PALE, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
		K.ribbon(st, PackedVector3Array([c - side * 0.06, c + side * 0.06]), 0.035, M.a(PALE, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	return M.keep("hr_cross", K.finish(st, Vector3.ONE * 0.2, false))


## Eight pillars of light standing on a ring of radius 1 (crossed beams, each from its moment).
static func _gates() -> ArrayMesh:
	if M.has("hr_gates"):
		return M.get_mesh("hr_gates")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		K.beam(st, Vector3(sin(a), 0, cos(a)), 1.0, 0.07, M.a(GOLD, 0.85), 2, 0.02 * float(i % 4), 0.0, 0.015)
	return M.keep("hr_gates", K.finish(st, Vector3.ONE * 0.3, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.yaw(origin, aim), visual)
	if r == null:
		return false
	G.flat(r, _cross(), "Cross", Vector3.UP * 0.05, Vector3.ONE * 2.0, time + 0.04, G.lit(GOLD, 0.55, 0.5), {"initial": 0.4, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.97, "spin": 2.2})
	G.flat(r, G.curtain("hr_rise", M.a(GOLD, 0.55), M.a(PALE, 0.0), 1.0, 32), "Rise", Vector3.ZERO, Vector3(1.1, 1.8, 1.1), time + 0.04, G.lit(GOLD, 0.6, 1.0, {"flow": 3.0}), {"initial": 0.5, "grow_time": 0.9, "fade_in": 0.15, "decay": 0.95})
	G.motes(r, "hr_gather", [GOLD, PALE], G.n(12), 0.4, 1.4, 2.2, 0.1, 0.0, time + 0.04, 801)
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var radius := float(skill.get("radius", 7.5))
	var feet := Vector3(origin.x, 0.0, origin.z)
	var r := G.open(parent, feet, 1.7, "Skill_%s_wall" % ID, turn, caster)
	if r == null:
		return false
	# The rampart races out to the edge, the second wall a beat behind.
	G.flat(r, G.battlement("hr_wall", M.a(GOLD, 0.95), M.a(PALE, 0.55), 0.24, 30), "Rampart", Vector3.ZERO, Vector3(radius, radius * 0.75, radius), 0.75, G.lit(GOLD, 0.6, 0.8, {"flow": 2.0}), {"initial": 0.12, "grow_time": 0.55, "fade_in": 0.01, "decay": 0.55})
	M.shock(r, "hr_ring", GOLD, radius * 1.03, 0.0, 0.5, 0.14)
	G.flat(r, _cross(), "Seal", Vector3.UP * 0.05, Vector3.ONE * radius * 0.95, 1.4, G.lit(HONEY, 0.4, 0.9, {"sweep": 0.3}), {"initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.7, "spin": 0.25})
	G.flat(r, G.battlement("hr_wall_b", M.a(HONEY, 0.95), M.a(ROSE, 0.5), 0.34, 22), "RampartB", Vector3.ZERO, Vector3(radius * 0.8, radius * 0.7, radius * 0.8), 0.8, G.lit(HONEY, 0.6, 0.8), {"delay": 0.12, "initial": 0.12, "grow_time": 0.55, "fade_in": 0.01, "decay": 0.55})
	G.bits(r, K.burst("hr_feathers", "feather", G.n(20), 0.6, radius * 0.6, 1.6, 3.5, [PALE, GOLD, ROSE], 0.32, 0.25, 802, 0.5, 2.2), "Feathers", Vector3.ZERO, 1.6, {"life": 1.4, "gravity": 0.9, "drag": 1.4, "piece": 0.32, "sway": 0.35, "spin": 3.0, "floor_y": 0.06, "add": 0.45, "shrink": 0.8}, {"delay": 0.05, "decay": 0.85})
	M.flash(r, "hr_flash", HONEY.darkened(0.3), 2.0, 0.0, 0.3)
	G.done(r)
	var more := G.extras(2)
	if more > 0:
		var gates := G.open(parent, feet, 1.5, "Skill_%s_gates" % ID, turn, caster)
		if gates:
			G.flat(gates, _gates(), "Gates", Vector3.ZERO, Vector3(radius * 0.92, 3.6, radius * 0.92), 1.0, G.lit(GOLD, 0.65, 1.2), {"delay": 0.18, "initial": 0.3, "grow_time": 0.25, "fade_in": 0.02, "decay": 0.6})
			G.daze(gates, Color("ffe070"), Vector3(0, 2.4, 1.4), 0.8, 1.3, 0.15)
			M.shock(gates, "hr_ring_b", PALE, radius * 1.12, 0.14, 0.55, 0.08)
			G.motes(gates, "hr_motes", [GOLD, PALE], G.n(18), radius * 0.3, radius * 0.9, 3.0, 0.12, 0.2, 1.2, 803)
			G.done(gates)
	return true


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit: bool) -> void:
	G.hit(parent, skill, at, [GOLD, PALE], crit)
