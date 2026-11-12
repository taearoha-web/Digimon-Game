extends RefCounted
## Archer Lv.72 "Hurricane" (เฮอริเคน): a storm of wind round the archer. Cosmetic only.
## Wind-up: the wind winds tighter and tighter round the archer, dust and leaves are
## sucked in. Release: the hurricane breaks out: two walls of wind spin round the archer in
## opposite ways, a pinwheel of wind wheels over the ground to the rim, a shock of wind
## rolls out, dust clouds billow and leaves are flung out and round; the wind dies down in eddies.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const WIND := {"c_core": Color("c8fff0"), "c_mid": Color("6af0c8"), "c_edge": Color("1f9a7e")}
const GALE := {"c_core": Color("e0fff6"), "c_mid": Color("8ff5d8"), "c_edge": Color("2a8a7a")}
const DUST := {"c_core": Color("eef2dc"), "c_mid": Color("c2cca8"), "c_edge": Color("7a8a62")}
const LEAF := {"tint": Color("8fe39a"), "ember": Color("c8ff9a"), "glow": Color("e6ffd0"), "rim": 0.45, "shadow": Color("2c6a3a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.0)), 3.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	A.helix(r, Vector3.UP * 0.05, Vector3(1.7, 1.1, 1.7), WIND, 0.0, duration + 0.12, 7.0, 0.45, {"scale_curve": [0.0, 1.5, duration, 0.75]})
	A.ring(r, Vector3.UP * 0.06, 4.0, GALE, 0.0, duration + 0.1, 0.35, {"to": Vector3.ONE * 0.3})
	if c.has(1):
		A.clouds(r, Vector3.UP * 0.3, 2.4, c.n(2, 3, 5), DUST, 0.9, 0.0, duration + 0.15, 0.45, 1.0)
		A.drift(r, LEAF, Vector3.ZERO, 2.6, c.n(3, 5, 7), 0.5, 0.3, 0.0, duration + 0.3, Vector3(0, 3.0, 0), 2.0)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Storm", origin)
	if not r:
		return true
	# Two walls of wind turning opposite ways round the archer.
	A.helix(r, Vector3.UP * 0.05, Vector3(rad * 0.42, 1.7, rad * 0.42), WIND, 0.0, 1.2, 6.0, 0.85, {"grow": 0.25, "from": 0.35, "veil": true})
	if c.has(0):
		A.helix(r, Vector3.UP * 0.05, Vector3(rad * 0.28, 2.4, rad * 0.28), GALE, 0.05, 1.05, -8.0, 0.4, {"grow": 0.2, "from": 0.4})
	# A pinwheel of wind wheeling over the ground out to the rim.
	for k in c.n(2, 3, 4):
		A.gust(r, Vector3.UP * 0.1, rad * 0.98, WIND, 0.0, 0.95, 0.7, float(k) * TAU / float(c.n(2, 3, 4)), {"veil": true, "spin": Vector3(0, -4.5, 0)})
	# A second, faster pinwheel of light over the first.
	if c.has(1):
		for k in 2:
			A.gust(r, Vector3.UP * 0.2, rad * 0.8, GALE, 0.05, 0.8, 0.35, float(k) * PI + 0.6, {"spin": Vector3(0, -7.0, 0)})
	# The shock of wind rolling out to the rim.
	A.ring(r, Vector3.UP * 0.07, rad * 1.08, WIND, 0.0, 0.6, 0.6)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, rad * 0.75, GALE, 0.12, 0.6, 0.45)
		A.clouds(r, Vector3.UP * 0.4, rad * 0.75, c.n(3, 5, 8), DUST, 1.3, 0.05, 0.9, 0.45, 3.0)
	A.S.sparks(r, Vector3.UP * 0.8, c.n(6, 10, 16), WIND, 0.3, 0.0, 0.9, 9.0, 0.6, 9, 1.4, 2.0)
	if c.has(0):
		A.drift(r, LEAF, Vector3.ZERO, rad * 0.6, c.n(4, 7, 11), 2.0, 0.34, 0.1, 1.4, Vector3(1.2, 0, -0.8), 5.0)
	return true
