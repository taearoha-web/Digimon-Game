extends RefCounted
## Priest Lv.96 "Miracle" (ปาฏิหาริย์): a miracle over the party (attack, defence, healing).
## Cosmetic only. Wind-up: a cathedral seal writes itself round the priest, a small sun
## rises over the raised hands and feathers start to fall. Release: the miracle: great
## wings of light unfold behind the priest with a slow beat, the sun over the head flares in
## a corona, a column of golden light pours down through the priest, waves of gold and of
## healing roll out over the party, crosses of healing rise and feathers of light drift
## down all round; the wings fold and the sun sets into the priest.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd25a"), "c_edge": Color("b8701a")}
const SUN := {"c_core": Color("fff6d0"), "c_mid": Color("ffc84a"), "c_edge": Color("e0802a")}
const LIGHT := {"c_core": Color("fffbe8"), "c_mid": Color("fff0b0"), "c_edge": Color("d0a85a")}
const HEAL := {"c_core": Color("f0ffe8"), "c_mid": Color("a8f0c0"), "c_edge": Color("3a9a7a")}
const SEAL := {"c_core": Color("fff0c0"), "c_mid": Color("f0c060"), "c_edge": Color("8a5a1a")}
const WINGS := {"tint": Color("fff2d0"), "ember": Color("ffe8a8"), "glow": Color("fff8e8"), "rim": 0.9, "shadow": Color("c0904a"), "spread": 1.0, "flap": 0.0, "flap_rate": 3.0}
const PLUME := {"tint": Color("fff8e8"), "ember": Color("ffe8a8"), "glow": Color("fffcf0"), "rim": 0.5, "shadow": Color("c0a06a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Seal", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, 2.8, 8.0, SEAL, 0.0, duration + 0.15, duration * 0.8, 0.55, 0.4)
	r.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 1.2}), Vector3.UP * 2.0, Vector3.ONE * 0.28, Vector3.ZERO, 0.0, duration + 0.12, {"travel": Vector3.UP * 0.9, "ease": 2, "grow": duration, "from": 0.2, "fin": 0.05, "fout": 0.02})
	A.glow(r, 2, Vector3.UP * 2.0, Vector3.ONE * 1.2, Vector3.ZERO, GOLD, 0.0, duration + 0.12, 0.4, {"billboard": true, "p1": 12.0, "p2": 0.3}, {"travel": Vector3.UP * 0.9, "ease": 2, "grow": duration, "from": 0.2, "priority": -1})
	if c.has(1):
		A.drift(r, PLUME, Vector3.ZERO, 1.8, c.n(2, 3, 5), 3.0, 0.38, 0.0, duration + 0.6, Vector3.ZERO, 1.0)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 2.4)
	var r := c.root(origin, 2.3, "Miracle", origin)
	if not r:
		return true
	var cam := r.toward_camera()
	# Great wings of light unfold behind the priest with a slow beat.
	A.solid(r, A.mesh("wings"), WINGS.merged({"spread": 0.0}), Vector3(0, 1.75, 0) - cam * 0.35, Vector3.ONE * 0.95, Vector3.ZERO, 0.0, 2.0,
		{"yaw_cam": true, "grow": 0.3, "from": 0.5, "curves": {"spread": [0.0, 0.05, 0.35, 1.0, 1.6, 1.0, 2.0, 0.3], "flap": [0.0, 0.0, 0.3, 0.0, 0.6, 0.55, 1.4, 0.15]}, "fin": 0.08, "fout": 0.5, "priority": -1})
	# The sun flares in a corona over the head.
	var sun := Vector3.UP * 2.9
	r.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 1.4}), sun, Vector3.ONE * 0.36, Vector3.ZERO, 0.0, 1.6, {"scale_curve": [0.0, 1.0, 0.12, 1.5, 0.5, 1.15, 1.6, 0.6], "fin": 0.02, "fout": 0.5, "priority": 1})
	A.glow(r, 2, sun, Vector3.ONE * 2.4, Vector3.ZERO, GOLD, 0.0, 1.5, 0.5, {"billboard": true, "p1": 14.0, "p2": 0.3}, {"grow": 0.15, "from": 0.6, "fout": 0.5})
	# A column of golden light through the priest; waves over the party.
	A.column(r, Vector3.ZERO, 1.1, 5.5, LIGHT, 0.05, 1.1, 0.45, -3.0, {"to": Vector3(0.6, 1.0, 0.6)})
	A.ring(r, Vector3.UP * 0.07, 4.5, GOLD, 0.05, 0.75, 0.8)
	A.ring(r, Vector3.UP * 0.08, 3.0, HEAL, 0.2, 0.7, 0.75)
	A.S.motes(r, Vector3.ZERO, 1.6, c.n(5, 8, 12), HEAL, 0.32, 0.2, 0.8, 1.0, 1.8, 12, 1.0)
	if c.has(0):
		A.ring(r, Vector3.UP * 0.09, 7.0, SEAL, 0.35, 0.9, 0.55)
		A.glow(r, 6, Vector3.UP * 0.06, Vector3.ONE * 2.8, Vector3(-PI / 2, A.S.face_camera(r) + PI, 0), GOLD, 0.0, 1.6, 0.6, {"p1": 0.13, "p2": 5.0}, {"veil": true, "fout": 0.6, "priority": -1})
	if c.has(1):
		A.drift(r, PLUME, Vector3.ZERO, 3.0, c.n(5, 8, 12), 3.6, 0.42, 0.15, 2.0, Vector3.ZERO, 4.0)
		A.S.motes(r, Vector3.ZERO, 3.0, c.n(5, 8, 12), GOLD, 0.24, 0.3, 1.0, 1.0, 1.4, 10, 3.0)
	return true
