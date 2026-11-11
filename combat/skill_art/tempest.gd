extends RefCounted
## Archer Lv.80 "Tempest" (พายุศร): a storm of arrows over a wide field. Cosmetic only.
## Wind-up: a storm cloud gathers over the target area, a ring of wind turns on the ground
## and the bow glows gold. Release: the archer looses a volley into the cloud. Landing (with
## the real hit): lightning flickers inside the cloud and a downpour of golden storm
## arrows hammers the circle in two waves, every arrow planting itself in a flash; a gust
## sweeps the ground, the planted arrows stand a moment and the cloud thins away.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const STORM := {"c_core": Color("fff3b8"), "c_mid": Color("ffd84a"), "c_edge": Color("c07a1a")}
const GUST := {"c_core": Color("e8fff4"), "c_mid": Color("a8f0d8"), "c_edge": Color("3a8a7a")}
const CLOUD := {"c_core": Color("c8d2e6"), "c_mid": Color("8090b0"), "c_edge": Color("3e4868")}
const SPARK := {"c_core": Color("fffbe0"), "c_mid": Color("ffe27a"), "c_edge": Color("d0901a")}
const ARROW := {"tint": Color("ffe9a0"), "ember": Color("ffd84a"), "glow": Color("fff4c8"), "rim": 0.75, "shadow": Color("7a4a1a")}
const FLIGHT := 0.28


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.0)), 4.0, 10.0)


static func _sky(r: K, rad: float) -> Vector3:
	var back := -r.toward_camera() * rad * 0.55
	return back + Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position + r.global_basis * back) - 1.2, 3.5, 5.5), 0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.8, visual)
	var rad := _radius(skill)
	var centre := A.flat(aim)
	var r := c.toward(centre, centre + (centre - origin), duration + 0.75, "Cloud", duration)
	if r:
		var sky := _sky(r, rad)
		A.clouds(r, sky, rad * 0.55, c.n(4, 6, 9), CLOUD, 2.6, 0.0, duration + 0.95, 0.6, 1.0)
		A.rim(r, Vector3.UP * 0.06, rad, STORM, 0.0, duration + 0.7, 0.5)
		if c.has(1):
			A.ring(r, Vector3.UP * 0.07, rad * 0.9, GUST, 0.0, duration + 0.6, 0.35, {"to": Vector3.ONE * 0.4})
	var w := c.toward(origin, aim, duration + 0.1, "Draw", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.1, STORM, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var land := maxf(impact_delay, 0.0)
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, land + 2.0)
	var centre := A.flat(center)
	var v := c.toward(origin, centre, 0.6, "Volley")
	if v:
		var hand := v.to_local(c.hand())
		A.flash(v, hand, 1.5, STORM, 0.0, 0.25, 0.6)
		for k in c.n(1, 2, 3):
			A.beam(v, hand, hand + Vector3(-0.8 + 0.8 * float(k), 7.5, 3.0), 0.45, STORM, 0.03 * float(k), 0.5, 0.5, 9.0)
	var r := c.toward(centre, centre + (centre - origin), land + 1.9, "Tempest")
	if not r:
		return true
	var sky := _sky(r, rad)
	var fly := minf(FLIGHT, maxf(land, 0.12))
	var fall := maxf(land - fly, 0.0)
	# The cloud darkens and flickers with lightning.
	A.clouds(r, sky + Vector3.UP * 0.2, rad * 0.6, c.n(3, 6, 9), CLOUD, 2.8, 0.0, land + 1.4, 0.75, 4.0)
	for k in c.n(1, 2, 3):
		var at := A.spots(3, rad * 0.6, 7.0)[k] as Vector3
		A.bolt(r, sky + at * 0.4, at, 0.6, STORM, fall + 0.1 * float(k), 0.18, 0.85, float(k) * 2.2)
	# Two waves of golden storm arrows.
	for wave in c.n(1, 2, 2):
		var count := c.n(6, 10, 14)
		var spots := A.spots(count, rad * 0.9, 1.3 + float(wave) * 2.1)
		var times := A.delays(count, 0.16, float(wave) * 3.0)
		var start := fall + 0.22 * float(wave)
		A.rain(r, K.mesh("light_arrow_bare"), ARROW, spots, times, Vector3(0.25, -1, -0.15), 1.15, fly, start, 0.55, 11.0)
		var landed := []
		for t in times:
			landed.append(float(t) + fly)
		A.marks(r, spots, landed, 0.9, SPARK, start, 0.35, 10, 0.3, 0.75)
		if c.has(1):
			A.marks(r, spots, landed, 1.2, STORM, start, 0.45, 1, 0.07, 0.5)
	# A gust sweeps the ground; the rim burns gold.
	A.ring(r, Vector3.UP * 0.08, rad * 1.12, STORM, land, 0.7, 0.55)
	if c.has(0):
		A.helix(r, Vector3.UP * 0.05, Vector3(rad * 0.45, 0.45, rad * 0.45), GUST, land, 1.0, 3.5, 0.35)
	return true
