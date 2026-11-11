extends RefCounted
## Mage Lv.88 "Spirit Burst" (วิญญาณระเบิด): the spirits gathered round the mage burst out
## over the whole circle. Cosmetic only. Wind-up: wisps of violet spirit spiral in from
## the rim and gather into the mage, a sigil writes itself underfoot and a ring of spirit
## light closes in. Release (with the real hit): a nova: an orb of spirit light flares on
## the mage, three waves of violet light roll out to the rim one after another, the wisps
## fly out over the foes and a spiral of spirit light wheels round on the ground; the
## wisps rise and fade.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const SPIRIT := {"c_core": Color("f2e8ff"), "c_mid": Color("b698f2"), "c_edge": Color("4a2a9a")}
const WISP := {"c_core": Color("faf4ff"), "c_mid": Color("d0b8ff"), "c_edge": Color("7a5ad0")}
const NOVA := {"c_core": Color("ffe8ff"), "c_mid": Color("e0a8ff"), "c_edge": Color("6a2aa8")}
const DEEP := {"c_core": Color("e0d0ff"), "c_mid": Color("8a6ae0"), "c_edge": Color("2a1a6a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 3.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var rad := _radius(skill)
	var r := c.toward(origin, aim, duration + 0.15, "Gather", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, 2.4, 7.0, SPIRIT, 0.0, duration + 0.15, duration * 0.8, 0.5, 0.7)
	A.ring(r, Vector3.UP * 0.07, rad * 0.9, DEEP, 0.0, duration + 0.12, 0.6, {"to": Vector3.ONE * 0.15})
	A.flash(r, Vector3.UP * 1.2, 1.6, WISP, 0.0, duration + 0.1, 0.45, {"grow": duration, "from": 0.1})
	# Wisps spiral in from the rim.
	var count := c.n(5, 8, 12)
	var cards := []
	var data := []
	for k in count:
		var a := float(k) * TAU / float(count)
		var at := Vector3(sin(a), 0.6 + 0.6 * K.rand(float(k)), cos(a)) * Vector3(rad * 0.7, 1, rad * 0.7)
		cards.append(K.card(at, 0.55, (Vector3(0, 1.2, 0) - at).normalized()))
		data.append(Color(0.02 * float(k), K.rand(float(k) + 3.0), 0, 0))
	r.swarm(K.mesh("quad"), K.GLOW, WISP.merged({"mode": 9, "billboard": true, "life": duration + 0.1, "burst": rad * 2.4, "gain": 1.1}), cards, data, 0.0, duration + 0.15, {"fin": 0.05})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Nova", origin)
	if not r:
		return true
	# The orb flares on the mage.
	A.glow(r, 2, Vector3.UP * 1.2, Vector3.ONE * 3.0, Vector3.ZERO, NOVA, 0.0, 0.45, 0.6, {"billboard": true, "p1": 9.0, "p2": 0.4}, {"grow": 0.1, "from": 0.4, "veil": true, "priority": -1})
	A.column(r, Vector3.ZERO, 1.2, 5.0, SPIRIT, 0.0, 0.7, 0.55, 4.0, {"to": Vector3(0.3, 1.0, 0.3), "veil": true})
	# Three waves rolling out to the rim.
	for k in c.n(2, 3, 3):
		A.ring(r, Vector3.UP * (0.07 + 0.01 * k), rad * 1.1, [SPIRIT, NOVA, DEEP][k], 0.12 * float(k), 0.7, 0.75 - 0.12 * float(k))
	A.glow(r, 0, Vector3.UP * 0.05, Vector3.ONE * rad, K.FLAT, DEEP, 0.0, 1.0, 0.35, {"p1": 0.8}, {"veil": true, "grow": 0.3, "from": 0.2, "fout": 0.6, "priority": -2})
	# A spiral of spirit light wheeling on the ground.
	A.glow(r, 11, Vector3.UP * 0.06, Vector3.ONE * rad * 0.85, K.FLAT, SPIRIT, 0.0, 1.1, 0.6, {"p1": 6.0, "p2": 0.12}, {"veil": true, "spin": Vector3(0, 0, 2.0), "grow": 0.25, "from": 0.2})
	# The wisps fly out over the foes, then rise.
	A.S.sparks(r, Vector3.UP * 1.0, c.n(8, 14, 20), WISP, 0.5, 0.0, 1.0, rad * 1.6, -0.6, 9, 2.4, 1.0)
	if c.has(1):
		A.S.motes(r, Vector3.ZERO, rad * 0.7, c.n(5, 8, 12), WISP, 0.35, 0.4, 0.7, 1.0, 1.6, 9, 2.0)
		A.sigil(r, Vector3.UP * 0.05, 2.6, 7.0, NOVA, 0.0, 1.0, 0.0, 0.5, -1.0)
	return true
