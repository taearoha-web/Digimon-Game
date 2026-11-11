extends RefCounted
## Priest Lv.100 "Last Judgement" (การพิพากษาครั้งสุดท้าย): the priest's greatest judgement,
## over a whole field, stunning all it strikes. Cosmetic only. Wind-up: the heavens open
## over the far side of the field: a great seal of judgement turns there round a sun of
## gold, a host of swords of light forms under it point down, the judgement seal writes
## itself over the whole circle and the priest's symbol burns. Release (with the real hit):
## the swords rain down onto the field and plant themselves, the sun hurls a great column
## of judgement onto the centre, crosses of light flare over the foes, the ground seal
## blazes gold, two shock rings roll out to the rim and chains of gold bind the foes struck
## (the stun); the swords stand a moment in the light, then feathers fall as it fades.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const GOLD := {"c_core": Color("fff2c0"), "c_mid": Color("ffc84a"), "c_edge": Color("b0601a")}
const SUN := {"c_core": Color("fff4c8"), "c_mid": Color("ffbe40"), "c_edge": Color("e06a2a")}
const HOLY := {"c_core": Color("fffbe0"), "c_mid": Color("fff0a0"), "c_edge": Color("d09a3a")}
const SEAL := {"c_core": Color("ffe8b0"), "c_mid": Color("f0a840"), "c_edge": Color("7a3a1a")}
const DUSK := {"c_core": Color("ffd8a0"), "c_mid": Color("e88a5a"), "c_edge": Color("6e2a52")}
const SWORD := {"tint": Color("fff0c0"), "ember": Color("ffd870"), "glow": Color("fff8e0"), "rim": 0.95, "shadow": Color("a8602a")}
const CHAIN := {"tint": Color("ffe8a0"), "ember": Color("ffd060"), "glow": Color("fff4d0"), "rim": 0.7, "shadow": Color("8a5a1a")}
const PLUME := {"tint": Color("fff8e8"), "ember": Color("ffe8a8"), "glow": Color("fffcf0"), "rim": 0.5, "shadow": Color("c0a06a")}
const FLIGHT := 0.2


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 12.0)), 4.0, 11.0)


## The open heavens: over the far side of the field (they never cover the foes).
static func _sky(r: K, rad: float) -> Vector3:
	var back := -r.toward_camera() * rad * 0.5
	return back + Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position + r.global_basis * back) - 1.4, 4.5, 7.0), 0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.35, visual)
	var rad := _radius(skill)
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.3, "Heavens", duration)
	if g:
		var sky := _sky(g, rad)
		var yaw := A.S.face_camera(g)
		# The seal of judgement turning round a sun of gold.
		A.glow(g, 17, sky, Vector3.ONE * 3.4, Vector3(-1.05, yaw, 0), SEAL, 0.0, duration + 0.28, 0.75, {"p1": 8.0, "p2": 1.0 / maxf(duration * 0.7 / (duration + 0.28), 0.05), "life": duration + 0.28}, {"veil": true, "spin": Vector3(0, 0, 0.5), "fin": 0.06})
		g.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 1.2}), sky, Vector3.ONE * 0.75, Vector3.ZERO, 0.0, duration + 0.28, {"grow": duration * 0.8, "from": 0.2, "fin": 0.05, "fout": 0.05, "priority": 1})
		A.glow(g, 2, sky, Vector3.ONE * 3.0, Vector3.ZERO, GOLD, 0.0, duration + 0.28, 0.45, {"billboard": true, "p1": 16.0, "p2": 0.28}, {"grow": duration, "from": 0.3, "priority": -1})
		# The host of swords forming point down under the seal.
		var swords := c.n(3, 5, 8)
		var xf := []
		var data := []
		for k in swords:
			var off := Vector3((float(k) - float(swords - 1) * 0.5) * 0.95, -1.2 - 0.6 * absf(float(k) - float(swords - 1) * 0.5) * 0.4, 0.0)
			xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.55), sky + Basis(Vector3.UP, yaw) * off + Vector3.DOWN * 1.7))
			data.append(Color(0.04 * float(k), K.rand(float(k)), 0, 0))
		g.swarm(A.mesh("sword"), K.SOLID, SWORD, xf, data, duration * 0.3, duration * 0.7 + 0.02, {"grow": duration * 0.4, "from": 0.3, "fin": 0.1, "fout": 0.02, "priority": 2})
		# The seal of judgement over the whole circle.
		A.sigil(g, Vector3.UP * 0.05, rad, 8.0, SEAL, 0.0, duration + 0.3, duration * 0.85, 0.45, 0.12)
		A.rim(g, Vector3.UP * 0.06, rad, GOLD, 0.0, duration + 0.28, 0.55)
	var w := c.toward(origin, aim, duration + 0.1, "Symbol", duration)
	if w:
		A.glow(w, 2, w.to_local(c.hand()), Vector3.ONE * 1.4, Vector3.ZERO, GOLD, 0.0, duration + 0.1, 0.5, {"billboard": true, "p1": 10.0, "p2": 0.3}, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var stun := float(skill.get("fx", {}).get("stun", 2.0))
	var c := A.cast(parent, skill, origin, stun + 1.0)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), stun + 1.0, "Judgement")
	if not r:
		return true
	var sky := _sky(r, rad)
	var yaw := A.S.face_camera(r)
	# The swords rain down and plant themselves.
	var count := c.n(6, 10, 16)
	var spots := []
	for spot in A.foes(r, centre, rad, c.n(2, 4, 6)):
		spots.append(r.to_local(spot) + Vector3(0.7, 0, 0.5))
	for k in count - spots.size():
		spots.append(K.scatter(k, count, rad * 0.85, 2.0))
	var times := A.delays(spots.size(), 0.18, 1.0)
	A.rain(r, A.mesh("sword"), SWORD, spots, times, Vector3(-0.1, -1, 0.15), 0.6, FLIGHT, 0.0, stun * 0.6, 10.0, 1.0)
	var landed := []
	for t in times:
		landed.append(float(t) + FLIGHT)
	A.marks(r, spots, landed, 1.0, GOLD, 0.0, 0.45, 1, 0.07, 0.75)
	# The sun hurls the column of judgement onto the centre.
	A.flash(r, sky, 4.5, SUN, 0.0, 0.4, 0.35)
	A.beam(r, sky, Vector3.UP * 0.2, 2.2, HOLY, 0.0, 0.7, 0.55, 10.0)
	A.column(r, Vector3.ZERO, 2.0, 9.0, GOLD, 0.05, 0.9, 0.6, -8.0, {"to": Vector3(0.6, 1.0, 0.6), "veil": true})
	A.column(r, Vector3.ZERO, 1.0, 9.5, HOLY, 0.05, 0.75, 0.45, -10.0, {"to": Vector3(0.4, 1.0, 0.4)})
	# The ground seal blazes, crosses flare over the foes, rings roll out.
	A.sigil(r, Vector3.UP * 0.05, rad, 8.0, GOLD, 0.0, 1.6, 0.0, 0.38, -0.3)
	A.glow(r, 0, Vector3.UP * 0.04, Vector3.ONE * rad, K.FLAT, DUSK, 0.0, 1.4, 0.3, {"p1": 1.0}, {"veil": true, "fout": 0.8, "priority": -2})
	A.ring(r, Vector3.UP * 0.07, rad * 1.1, GOLD, 0.05, 0.8, 0.8)
	A.ring(r, Vector3.UP * 0.08, rad * 0.7, SEAL, 0.2, 0.8, 0.65)
	for spot in A.foes(r, centre, rad, c.n(2, 4, 6)):
		var at: Vector3 = r.to_local(spot)
		A.glow(r, 6, at + Vector3.UP * 1.7, Vector3.ONE * 1.1, Vector3(0, yaw, 0), GOLD, 0.08, 0.6, 0.85, {"p1": 0.16, "p2": 7.0}, {"veil": true, "grow": 0.1, "from": 0.5})
		if c.has(1):
			_chains(r, at, stun, c)
	if c.has(0):
		A.S.sparks(r, Vector3.UP * 1.0, c.n(8, 14, 22), HOLY, 0.3, 0.05, 1.0, 12.0, 4.0, 10, 1.4, 3.0)
	if c.has(1):
		A.drift(r, PLUME, Vector3.ZERO, rad * 0.7, c.n(5, 8, 12), 3.5, 0.45, 0.4, 2.0, Vector3.ZERO, 5.0)
	return true


## A ring of golden chains round a foe struck, turning while it is stunned.
static func _chains(r: K, at: Vector3, stun: float, c: A.Cast) -> void:
	var links := c.n(8, 10, 12)
	var xf := []
	var data := []
	for k in links:
		var a := float(k) * TAU / float(links)
		xf.append(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, -PI / 2) * Basis(Vector3.UP, PI / 2 * float(k % 2)), Vector3(sin(a), 0, cos(a)) * 0.9))
		data.append(Color(0, K.rand(float(k)), 0, 0))
	r.swarm(K.mesh("link"), K.SOLID, CHAIN, xf, data, 0.15, stun, {"at": at + Vector3.UP * 0.9, "spin": Vector3(0, 1.2, 0), "grow": 0.2, "from": 2.0, "fin": 0.05, "fout": 0.3})
