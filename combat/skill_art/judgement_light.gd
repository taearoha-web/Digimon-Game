extends RefCounted
## Priest Lv.68 "Judgement" (แสงพิพากษา): a shaft of judgement on one foe. Cosmetic only.
## Wind-up: a small seal of light writes itself under the foe, light gathers over it, and
## the priest's symbol glows. Release (with the real hit): the shaft of light slams down on
## the foe, a cross of light burns over it, a ring rolls out from its feet and sparks of
## gold fly; the seal fades with the last light.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fff8d8"), "c_mid": Color("ffe07a"), "c_edge": Color("c08a2a")}
const SHAFT := {"c_core": Color("fffbe8"), "c_mid": Color("fff0a0"), "c_edge": Color("d8a84a")}
const SEAL := {"c_core": Color("fff0c0"), "c_mid": Color("f0c86a"), "c_edge": Color("8a6a2a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var foe := A.flat(aim)
	var g := c.toward(foe, foe + (foe - origin), duration + 0.2, "Seal", duration)
	if g:
		A.sigil(g, Vector3.UP * 0.05, 1.5, 6.0, SEAL, 0.0, duration + 0.2, duration * 0.8, 0.55, 0.8)
		A.flash(g, Vector3.UP * 4.0, 1.6, HOLY, 0.0, duration + 0.1, 0.4, {"grow": duration, "from": 0.2})
	var w := c.toward(origin, aim, duration + 0.1, "Symbol", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 0.9, HOLY, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.3)
	var foe := A.flat(center)
	var r := c.toward(foe, foe + (foe - origin), 1.2, "Shaft", 0.0)
	if not r:
		return true
	A.column(r, Vector3.ZERO, 0.75, 6.0, SHAFT, 0.0, 0.55, 0.55, -6.0, {"to": Vector3(0.45, 1.0, 0.45)})
	A.column(r, Vector3.ZERO, 1.1, 5.0, HOLY, 0.0, 0.45, 0.65, -4.0, {"to": Vector3(0.6, 1.0, 0.6), "veil": true})
	A.glow(r, 6, Vector3.UP * 1.6, Vector3.ONE * 1.3, Vector3(0, A.S.face_camera(r), 0), HOLY, 0.03, 0.6, 0.8, {"p1": 0.16, "p2": 6.0}, {"grow": 0.1, "from": 0.5, "veil": true})
	A.ring(r, Vector3.UP * 0.07, 2.2, HOLY, 0.0, 0.5, 0.75)
	if c.has(0):
		A.sigil(r, Vector3.UP * 0.05, 1.5, 6.0, SEAL, 0.0, 0.9, 0.0, 0.55, -0.6)
	if c.has(1):
		A.S.sparks(r, Vector3.UP * 0.8, c.n(4, 7, 10), HOLY, 0.24, 0.0, 0.6, 6.0, 3.0, 10, 1.0, 1.0)
	return true
