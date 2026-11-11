extends RefCounted
## Mage Lv.84 "Ice Storm" (พายุน้ำแข็ง): a blizzard over a wide field. Cosmetic only.
## Wind-up: frost spreads over the target area under a snow-sigil, cold clouds gather at
## its far side and a ring of wind turns; the staff glows ice-blue. Release (with the real
## hit): a hail of ice spears drives down across the circle, crystals of ice burst up out
## of the ground among the foes, a blizzard of snow swirls round the area and the frost
## rings out to the rim; the crystals stand a moment, then shatter into glittering chips.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const ICE := {"c_core": Color("eefcff"), "c_mid": Color("8fe0ff"), "c_edge": Color("2a6ac8")}
const FROST := {"c_core": Color("f6feff"), "c_mid": Color("bff0ff"), "c_edge": Color("5a9ad8")}
const SNOW := {"c_core": Color("ffffff"), "c_mid": Color("e0f6ff"), "c_edge": Color("8ab8e0")}
const CLOUD := {"c_core": Color("eaf4ff"), "c_mid": Color("b0c8e8"), "c_edge": Color("5a6a9a")}
const CRYSTAL := {"tint": Color("bfeeff"), "ember": Color("e8fbff"), "glow": Color("f0fcff"), "rim": 0.95, "shadow": Color("2a4a9a"), "motion": 2}
const SPEAR := {"tint": Color("c8f2ff"), "ember": Color("e8fcff"), "glow": Color("f4fdff"), "rim": 0.9, "shadow": Color("2a5aa0")}
const FLIGHT := 0.22


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 3.0, 10.0)


static func _sky(r: K, rad: float) -> Vector3:
	var back := -r.toward_camera() * rad * 0.55
	return back + Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position + r.global_basis * back) - 1.2, 3.5, 5.5), 0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.3, visual)
	var rad := _radius(skill)
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.25, "Frost", duration)
	if g:
		A.sigil(g, Vector3.UP * 0.05, rad, 6.0, ICE, 0.0, duration + 0.25, duration * 0.85, 0.45, 0.2)
		A.glow(g, 0, Vector3.UP * 0.04, Vector3.ONE * rad, K.FLAT, FROST, 0.0, duration + 0.25, 0.35, {"p1": 1.2}, {"veil": true, "grow": duration, "from": 0.2, "priority": -2})
		A.clouds(g, _sky(g, rad), rad * 0.55, c.n(3, 5, 8), CLOUD, 2.4, 0.0, duration + 1.4, 0.55, 2.0)
		if c.has(1):
			A.helix(g, Vector3.UP * 0.05, Vector3(rad * 0.5, 0.5, rad * 0.5), FROST, 0.0, duration + 0.25, 2.5, 0.6, {"veil": true})
	var w := c.toward(origin, aim, duration + 0.1, "Staff", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.1, ICE, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 2.2)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), 2.1, "Storm")
	if not r:
		return true
	# A hail of ice spears across the circle (the first already falling at the release).
	var count := c.n(6, 10, 14)
	var spots := A.spots(count, rad * 0.9, 3.1)
	var times := A.delays(count, 0.35, 1.0)
	A.rain(r, K.mesh("shard"), SPEAR, spots, times, Vector3(0.2, -1, 0.15), 2.6, FLIGHT, 0.0, 0.35, 9.0, 0.0)
	var landed := []
	for t in times:
		landed.append(float(t) + FLIGHT)
	A.marks(r, spots, landed, 0.9, FROST, 0.0, 0.4)
	# Crystals burst out of the ground among the foes, then shatter.
	var hold := 1.1
	var xf := []
	var data := []
	var crystal_spots := []
	for spot in A.foes(r, centre, rad, c.n(2, 4, 6)):
		crystal_spots.append(r.to_local(spot))
	for k in c.n(2, 4, 7):
		crystal_spots.append(K.scatter(k, c.n(2, 4, 7), rad * 0.75, 5.0))
	for k in crystal_spots.size():
		var s := K.rand(float(k) * 2.9)
		xf.append(K.standing(crystal_spots[k], Vector3.ONE * (0.75 + 0.45 * s), s * TAU))
		data.append(Color(0.04 * float(k), s, 0, 0))
	r.swarm(K.mesh("ice"), K.SOLID, CRYSTAL.merged({"hold": hold}), xf, data, 0.0, hold + 0.5, {"fin": 0.01, "fout": 0.05})
	# The blizzard swirls round the area and the frost rings out.
	A.helix(r, Vector3.UP * 0.05, Vector3(rad * 0.62, 0.9, rad * 0.62), SNOW, 0.0, 1.4, 3.0, 0.65, {"veil": true})
	A.ring(r, Vector3.UP * 0.07, rad * 1.1, ICE, 0.0, 0.7, 0.75)
	A.glow(r, 0, Vector3.UP * 0.04, Vector3.ONE * rad * 0.95, K.FLAT, FROST, 0.0, 1.9, 0.4, {"p1": 1.0}, {"veil": true, "fout": 0.8, "priority": -2})
	if c.has(0):
		A.S.motes(r, Vector3.ZERO, rad * 0.8, c.n(6, 10, 16), SNOW, 0.3, 0.0, 0.8, 1.2, -0.4, 9, 1.0)
		A.S.sparks(r, Vector3.UP * 0.6, c.n(6, 10, 16), FROST, 0.24, hold, 0.6, 6.0, 3.0, 10, 1.4, 3.0)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, rad * 0.7, FROST, 0.12, 0.6, 0.6)
		A.clouds(r, _sky(r, rad), rad * 0.6, c.n(2, 4, 6), CLOUD, 2.6, 0.0, 1.5, 0.5, 4.0)
	return true
