extends RefCounted
## Mage Lv.92 "Magic Overdrive" (เวทโอเวอร์ไดรฟ์): the mage's magic runs past its limit
## (attack, crits). Cosmetic only. Wind-up: an astrolabe of three orbits with their
## planets assembles round the mage and starts to turn, a sigil writes itself underfoot.
## Release: overdrive: the orbits spin up hard and tilt, a crown of arcane crystals flares
## over the mage's head, a corona of violet light burns behind it, a column of arcane
## light runs up through it and two rings roll out; stars spark off as it settles.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const ARCANE := {"c_core": Color("fbe8ff"), "c_mid": Color("d08aff"), "c_edge": Color("5a2aa8")}
const ROSE := {"c_core": Color("ffe8f8"), "c_mid": Color("ffa8e8"), "c_edge": Color("9a3a9a")}
const STAR := {"c_core": Color("fff4ff"), "c_mid": Color("ffc8ff"), "c_edge": Color("a05ad0")}
const DEEP := {"c_core": Color("e8d8ff"), "c_mid": Color("9a6aff"), "c_edge": Color("2a1a7a")}
const ORBIT := {"tint": Color("ffffff"), "ember": Color("e8d0ff"), "glow": Color("f0e0ff"), "rim": 0.6, "shadow": Color("4a2a8a")}
const GEM := {"tint": Color("e8c0ff"), "ember": Color("ffd0ff"), "glow": Color("fff0ff"), "rim": 0.9, "shadow": Color("4a1a8a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Astrolabe", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, 2.2, 8.0, ARCANE, 0.0, duration + 0.15, duration * 0.8, 0.5, 0.5)
	for k in c.n(1, 2, 3):
		A.solid(r, K.mesh("orbit%d" % k), ORBIT, Vector3.UP * (1.1 + 0.25 * float(k)), Vector3.ONE * (1.1 + 0.25 * float(k)), Vector3(0.35 * float(k) - 0.3, 0.0, 0.25 * float(k)), 0.04 * float(k), duration + 0.12,
			{"spin": Vector3(0, 1.5 + float(k), 0), "grow": duration * 0.7, "from": 0.2, "fout": 0.05})
	A.flash(r, r.to_local(c.hand()), 1.0, ARCANE, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Overdrive", origin)
	if not r:
		return true
	# The orbits spin up hard and tilt.
	for k in c.n(1, 2, 3):
		A.solid(r, K.mesh("orbit%d" % k), ORBIT, Vector3.UP * (1.1 + 0.25 * float(k)), Vector3.ONE * (1.1 + 0.25 * float(k)), Vector3(0.35 * float(k) - 0.3, 0.0, 0.25 * float(k)), 0.0, 1.3,
			{"spin": Vector3(0, 7.0 + 2.0 * float(k), 0), "to": Vector3.ONE * 1.35, "fout": 0.4})
	# A crown of crystals over the head.
	var crown := Vector3.UP * 2.75
	var count := c.n(3, 5, 7)
	var xf := []
	var data := []
	for k in count:
		var a := float(k) * TAU / float(count)
		xf.append(Transform3D(Basis(Vector3(cos(a), 0, -sin(a)), 0.35).scaled(Vector3.ONE * 0.32), Vector3(sin(a), 0, cos(a)) * 0.55))
		data.append(Color(0.03 * float(k), K.rand(float(k)), 0, 0))
	r.swarm(K.mesh("crystal"), K.SOLID, GEM, xf, data, 0.0, 1.3, {"at": crown, "spin": Vector3(0, 2.5, 0), "grow": 0.25, "from": 0.2, "fin": 0.05, "fout": 0.4})
	# A corona burning behind, a column through, rings rolling out.
	var back := Vector3(0, 1.6, 0) - r.toward_camera() * 0.4
	A.glow(r, 2, back, Vector3.ONE * 2.6, Vector3.ZERO, ARCANE, 0.0, 1.2, 0.5, {"billboard": true, "p1": 12.0, "p2": 0.3}, {"grow": 0.2, "from": 0.4, "fout": 0.5, "priority": -1})
	A.column(r, Vector3.ZERO, 1.0, 5.5, ARCANE, 0.0, 0.8, 0.6, 5.0, {"to": Vector3(0.35, 1.0, 0.35), "veil": true})
	A.ring(r, Vector3.UP * 0.07, 5.2, ARCANE, 0.0, 0.7, 0.8)
	A.glow(r, 0, Vector3.UP * 0.04, Vector3.ONE * 3.4, K.FLAT, DEEP, 0.0, 1.2, 0.35, {"p1": 1.0}, {"veil": true, "fout": 0.6, "priority": -2})
	if c.has(0):
		A.ring(r, Vector3.UP * 0.08, 3.4, ROSE, 0.15, 0.6, 0.7)
		A.glow(r, 10, crown, Vector3.ONE * 1.6, Vector3.ZERO, STAR, 0.0, 0.5, 0.8, {"billboard": true})
	if c.has(1):
		A.sigil(r, Vector3.UP * 0.05, 2.6, 8.0, DEEP, 0.0, 1.4, 0.0, 0.45, -1.2)
		A.S.sparks(r, crown, c.n(6, 9, 14), STAR, 0.24, 0.05, 0.8, 6.0, 2.0, 10, 1.0, 2.0)
	return true
