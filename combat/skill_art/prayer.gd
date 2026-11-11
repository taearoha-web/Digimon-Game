extends RefCounted
## Priest Lv.84 "Prayer" (สวดมนต์): a prayer answered: full healing and a ward (defence).
## Cosmetic only. Wind-up: a rosary of golden beads circles the priest and closes in, a
## soft light gathers over the folded hands. Release: a lotus of light blooms round the
## priest, petal by petal, a column of gentle light falls through it, healing crosses rise
## and a ward of light cells (the defence) closes over it; two rings carry the blessing to
## the party and the lotus folds away.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const LIGHT := {"c_core": Color("fffbe8"), "c_mid": Color("fff0b0"), "c_edge": Color("d0a85a")}
const HEAL := {"c_core": Color("f0ffe8"), "c_mid": Color("a8f0c0"), "c_edge": Color("3a9a7a")}
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd86a"), "c_edge": Color("b87a1a")}
const WARD := {"c_core": Color("f4fff8"), "c_mid": Color("b8f0d8"), "c_edge": Color("4a9a8a")}
const BEAD := {"tint": Color("ffe8a0"), "ember": Color("ffd870"), "glow": Color("fff4d0"), "rim": 0.7, "shadow": Color("8a5a1a")}
const LOTUS := {"tint": Color("fff0f4"), "ember": Color("ffe0ea"), "glow": Color("fffaf0"), "rim": 0.85, "shadow": Color("c08a9a"), "motion": 2}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Rosary", duration)
	if not r:
		return true
	var beads := c.n(8, 12, 16)
	var xf := []
	var data := []
	for k in beads:
		var a := float(k) * TAU / float(beads)
		xf.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.13), Vector3(sin(a), 0, cos(a)) * 1.6))
		data.append(Color(0, K.rand(float(k)), 0, 0))
	r.swarm(K.mesh("sphere"), K.SOLID, BEAD, xf, data, 0.0, duration + 0.12, {"at": Vector3.UP * 1.0, "spin": Vector3(0, 2.4, 0), "to": Vector3.ONE * 0.55, "grow": 0.15, "from": 0.4, "fin": 0.08, "fout": 0.05})
	A.flash(r, Vector3.UP * 1.5, 1.4, LIGHT, 0.0, duration + 0.1, 0.4, {"grow": duration, "from": 0.2})
	A.ring(r, Vector3.UP * 0.06, 2.0, GOLD, 0.0, duration + 0.1, 0.6, {"to": Vector3.ONE * 0.6})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 2.1)
	var r := c.root(origin, 2.0, "Lotus", origin)
	if not r:
		return true
	# A lotus of light blooms round the priest, petal by petal (two rings of petals).
	var hold := 1.3
	var xf := []
	var data := []
	for ring in c.n(1, 2, 2):
		var petals: int = [6, 8][ring]
		for k in petals:
			var a := float(k) * TAU / float(petals) + float(ring) * 0.39
			var tilt := 0.55 + 0.35 * float(ring)
			var size := 1.2 + 0.35 * float(ring)
			xf.append(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3.ONE * size), Vector3(sin(a), 0, cos(a)) * (0.55 + 0.35 * float(ring))))
			data.append(Color(0.03 * float(k) + 0.1 * float(ring), K.rand(float(k) + 4.0 * ring), 0, 0))
	r.swarm(A.mesh("petal"), K.SOLID, LOTUS.merged({"hold": hold}), xf, data, 0.0, hold + 0.5, {"fin": 0.01, "fout": 0.05})
	# A column of gentle light, healing rising, a ward closing over.
	A.column(r, Vector3.ZERO, 1.0, 4.5, LIGHT, 0.05, 1.0, 0.4, -2.5, {"to": Vector3(0.6, 1.0, 0.6)})
	A.S.motes(r, Vector3.ZERO, 1.2, c.n(4, 7, 10), HEAL, 0.32, 0.1, 0.7, 1.0, 1.8, 12, 1.0)
	A.dome(r, Vector3.ZERO, 1.9, WARD, 0.25, 1.4, 0.4, {"grow": 0.25, "from": 1.6})
	A.ring(r, Vector3.UP * 0.07, 3.6, HEAL, 0.05, 0.7, 0.75)
	if c.has(0):
		A.ring(r, Vector3.UP * 0.08, 5.5, GOLD, 0.25, 0.8, 0.55)
	if c.has(1):
		A.S.motes(r, Vector3.ZERO, 2.2, c.n(4, 6, 9), GOLD, 0.22, 0.3, 0.8, 1.0, 1.2, 10, 2.0)
	return true
