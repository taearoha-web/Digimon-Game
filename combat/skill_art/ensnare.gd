extends RefCounted
## Archer Lv.68 "Ensnare" (บ่วงพันธนาการ): a rain of snare arrows. Cosmetic only.
## Wind-up: a reticle of vines writes itself on the target area, the archer draws skyward.
## Release: a volley streaks up from the bow. Landing (with the real hit): the snare arrows
## rain down onto the circle, each one planting itself in a green ring, thorned vines lash
## out from the centre along the ground and coil round every foe caught (the slow); a ring
## of vines tightens over the area and leaves settle.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const VINE := {"c_core": Color("e6ffb0"), "c_mid": Color("8fe060"), "c_edge": Color("2f7a3a")}
const SNARE := {"c_core": Color("f2ffcc"), "c_mid": Color("b8f0a0"), "c_edge": Color("4a9a52")}
const BOW := {"c_core": Color("f4ffd8"), "c_mid": Color("b8f0a0"), "c_edge": Color("3a8a4a")}
const ARROW := {"tint": Color("d0f5b0"), "ember": Color("b8f0a0"), "glow": Color("efffd8"), "rim": 0.6, "shadow": Color("2a5a2e")}
const LEAF := {"tint": Color("8fd77a"), "ember": Color("c8ff9a"), "glow": Color("e6ffd0"), "rim": 0.45, "shadow": Color("2c6a3a")}
const FLIGHT := 0.3


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 6.0)), 3.0, 9.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.8, visual)
	var centre := A.flat(aim)
	var r := c.toward(centre, centre + (centre - origin), duration + 0.7, "Reticle", duration)
	if r:
		var rad := _radius(skill)
		A.sigil(r, Vector3.UP * 0.05, rad, 6.0, VINE, 0.0, duration + 0.7, duration, 0.42, 0.25)
		A.rim(r, Vector3.UP * 0.06, rad, SNARE, 0.0, duration + 0.65, 0.5)
	var w := c.toward(origin, aim, duration + 0.1, "Draw", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.0, BOW, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay: float) -> bool:
	var land := maxf(impact_delay, 0.0)
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, land + 1.8)
	var centre := A.flat(center)
	# The volley leaves the bow skyward.
	var v := c.toward(origin, centre, 0.6, "Volley")
	if v:
		var hand := v.to_local(c.hand())
		A.flash(v, hand, 1.3, BOW, 0.0, 0.25, 0.55)
		A.beam(v, hand, hand + Vector3(0, 7.0, 2.5), 0.5, SNARE, 0.0, 0.5, 0.5, 9.0)
	var r := c.toward(centre, centre + (centre - origin), land + 1.7, "Snare")
	if not r:
		return true
	# The snare arrows rain down, landing with the real hit.
	var count := c.n(5, 8, 12)
	var spots := A.spots(count, rad * 0.85, 1.7)
	var times := A.delays(count, 0.14, 2.0)
	var fall := maxf(land - FLIGHT, 0.0)
	A.rain(r, K.mesh("light_arrow_bare"), ARROW, spots, times, Vector3(-0.15, -1, 0.1), 1.0, minf(FLIGHT, maxf(land, 0.12)), fall, 0.7, 10.0)
	var landed := []
	for t in times:
		landed.append(float(t) + minf(FLIGHT, maxf(land, 0.12)))
	A.marks(r, spots, landed, 1.1, SNARE, fall, 0.45)
	# Vines lash out along the ground and coil round the foes caught.
	if c.has(0):
		for k in c.n(3, 5, 7):
			var a := float(k) * TAU / float(c.n(3, 5, 7)) + 0.3
			var tip := Vector3(sin(a), 0.08, cos(a)) * rad * (0.75 + 0.2 * K.rand(float(k)))
			A.beam(r, Vector3.UP * 0.08, tip, 0.45, VINE, land, 0.9, 0.5, 4.0)
	for spot in A.foes(r, centre, rad, c.n(2, 3, 5)):
		var at: Vector3 = r.to_local(spot)
		A.helix(r, at, Vector3(0.75, 0.6, 0.75), VINE, land + 0.05, 1.3, 2.5, 0.6, {"grow": 0.2, "from": 0.2})
	A.rim(r, Vector3.UP * 0.07, rad * 1.05, VINE, land, 1.4, 0.6, {"to": Vector3.ONE * 0.8, "grow": 0.01, "from": 1.0})
	if c.has(1):
		A.drift(r, LEAF, Vector3.ZERO, rad * 0.7, c.n(3, 5, 8), 2.2, 0.32, land, 1.3, Vector3(0.3, 0, 0), 4.0)
	return true
