extends RefCounted
## Defender Lv.88 "Aegis of Ages" (DEF up, heal, absorb shield): an ancient aegis wakes.
## Wind-up: rune rings of azure light start to turn round the defender and the ground clock
## of the ages draws itself. Release: a great round aegis of ivory and gold rises behind the
## defender like a monument, three rune rings turn round the defender at different tilts, a
## sheath of azure light closes round the body (the absorb shield), the clock sigil turns
## under the feet, a halo opens in the sky and warm motes rise (the heal). Azure, ivory and
## old gold.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const G := preload("res://combat/skill_art/_guard.gd")
const ID := "aegis_of_ages"
const AZURE := Color("7ec8ff")
const IVORY := Color("fff2d0")
const OLDGOLD := Color("e8c070")
const DEEP := Color("2a4a8a")
const BEHIND := 1.6


static func _aegis() -> ArrayMesh:
	return M.solid("aa_aegis", G.aegis(DEEP, OLDGOLD, IVORY, AZURE), Vector3.ONE * 2.0)


## The clock of the ages (radius 1): rings, twelve hour marks, two hands.
static func _clock() -> ArrayMesh:
	if M.has("aa_clock"):
		return M.get_mesh("aa_clock")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	K.disc(st, 1.0, M.a(DEEP, 0.4), 0.0, 40, 0.0, Vector3.UP, Vector3.ZERO, M.a(DEEP, 0.0), 0.0, true)
	K.ring(st, 0.97, 0.05, M.a(AZURE, 1.0), 0.004, 72)
	K.ring(st, 0.72, 0.025, M.a(OLDGOLD, 0.9), 0.004, 64)
	K.ring(st, 0.45, 0.02, M.a(AZURE, 0.8), 0.004, 48)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var dir := Vector3(sin(a), 0.005, cos(a))
		K.ribbon(st, PackedVector3Array([dir * 0.76, dir * 0.92]), 0.06 if i % 3 == 0 else 0.03, M.a(OLDGOLD, 1.0), 0.0, 0.0, Vector3.UP, 0.0)
	K.ribbon(st, PackedVector3Array([Vector3(0, 0.006, 0), Vector3(0, 0.006, 0.66)]), 0.05, M.a(IVORY, 1.0), 0.0, 0.0, Vector3.UP, 0.4)
	K.ribbon(st, PackedVector3Array([Vector3(0, 0.006, 0), Vector3(0.38, 0.006, -0.18)]), 0.06, M.a(IVORY, 1.0), 0.0, 0.0, Vector3.UP, 0.4)
	return M.keep("aa_clock", K.finish(st, Vector3.ONE * 0.2, false))


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var caster := G.note(skill, visual, origin, aim)
	var time := maxf(duration, 0.12)
	var r := G.windup(parent, origin, time + 0.06, "Skill_%s_windup" % ID, G.facing(caster), visual)
	if r == null:
		return false
	G.flat(r, G.orbits("aa_orbits", 2, AZURE, 0.03, 1.1), "Rings", Vector3.UP * 1.1, Vector3.ONE * 1.3, time + 0.04, G.lit(AZURE, 0.6, 0.5), {"initial": 1.8, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.97, "spin": 3.0})
	G.flat(r, _clock(), "Clock", Vector3.UP * 0.05, Vector3.ONE * 2.0, time + 0.04, G.lit(AZURE, 0.5, 0.5, {"sweep": time}), {"initial": 0.8, "grow_time": 0.5, "fade_in": 0.05, "decay": 0.97, "spin": -0.8})
	G.motes(r, "aa_gather", [AZURE, IVORY], G.n(10), 0.5, 1.5, 1.6, 0.1, 0.0, time + 0.04, 881)
	G.done(r)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var who := G.caster_of(skill, origin)
	var caster: Node3D = who[0]
	var turn := G.facing(caster)
	var r := G.aura(parent, caster, 2.2, "Skill_%s_aegis" % ID, turn) if caster else G.open(parent, origin, 2.2, "Skill_%s_aegis" % ID, turn, null)
	if r == null:
		return false
	var behind := K.away(r) * BEHIND
	var fit := G.sky_fit(r, behind, 3.6)
	# The aegis rises behind the defender like a monument, its face to the camera.
	G.solid(r, _aegis(), "Aegis", behind + Vector3.UP * 1.7 * fit, Vector3.ONE * 1.5 * fit, 1.9, {"drop": -1.6, "flight": 0.3, "ease": 1.0, "rim_color": AZURE, "rim": 1.0, "glow_color": AZURE, "dim": 0.95}, {"fade_in": 0.03, "decay": 0.78}, Vector3(G.TILT_BACK, K.facing(r), 0))
	G.flat(r, G.orbits("aa_orbits3", 3, AZURE, 0.03, 1.0), "Rings", Vector3.UP * 1.05, Vector3.ONE * 1.35, 2.0, G.lit(AZURE, 0.6, 0.5), {"initial": 0.5, "grow_time": 0.2, "fade_in": 0.03, "decay": 0.8, "spin": 1.6})
	G.flat(r, G.curtain("aa_sheath", M.a(AZURE, 0.6), M.a(IVORY, 0.0), 1.0, 36), "Sheath", Vector3.ZERO, Vector3(0.95, 2.2, 0.95), 1.0, G.lit(AZURE, 0.6, 1.1, {"flow": 3.0}), {"delay": 0.08, "initial": 1.6, "grow_time": 0.3, "fade_in": 0.02, "decay": 0.6})
	G.flat(r, _clock(), "Clock", Vector3.UP * 0.05, Vector3.ONE * 2.6, 2.1, G.lit(AZURE, 0.5, 0.5), {"initial": 0.7, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.8, "spin": -0.5})
	G.motes(r, "aa_heal", [IVORY, AZURE, OLDGOLD], G.n(20), 0.3, 1.3, 2.8, 0.12, 0.15, 1.6, 882)
	M.shock(r, "aa_ring", AZURE, 3.4, 0.0, 0.5, 0.14)
	G.done(r)
	if G.extras(1) > 0:
		var sky := G.aura(parent, caster, 2.0, "Skill_%s_halo" % ID, turn) if caster else null
		if sky:
			var high := G.sky_height(sky, Vector3.ZERO, 3.4)
			G.flat(sky, G.orbits("aa_halo", 1, OLDGOLD, 0.05, 0.0), "Halo", Vector3.UP * high, Vector3.ONE * 0.85, 1.8, G.lit(OLDGOLD, 0.6, 0.5), {"initial": 0.3, "grow_time": 0.3, "fade_in": 0.04, "decay": 0.8, "spin": 1.0})
			G.flat(sky, G.rays("aa_rays", 16, IVORY, 0.05, 0.3), "Rays", Vector3.UP * high, Vector3.ONE * 1.4, 1.2, G.lit(IVORY, 0.55, 0.6), {"delay": 0.1, "initial": 0.4, "grow_time": 0.3, "fade_in": 0.04, "decay": 0.6, "spin": -0.6})
			M.flash(sky, "aa_flash", DEEP.lightened(0.3), 2.4, 0.0, 0.5)
			M.sparks(sky, "aa_glint", [AZURE, IVORY], G.n(12), 0.4, 1.4, 1.0, 2.5, 0.1, 0.2, 1.2, Vector3.UP * 0.5, -0.4, 883, 0.2, 2.0)
			G.done(sky)
	return true
