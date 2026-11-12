extends RefCounted
## Priest Lv.72 "Hand of God" (หัตถ์พระเจ้า): a great hand of light heals the priest.
## Cosmetic only. Wind-up: the clouds part over the priest (a ring of light opening in
## the sky) and motes of light gather. Release: an open hand of light reaches down out of
## the opening, palm turned to bless, and lowers over the priest; light pours from the palm
## in a soft column, a healing ring washes out at the feet with crosses of healing rising
## through it, and the hand fades back into the sky.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const LIGHT := {"c_core": Color("fffbe0"), "c_mid": Color("fff0a8"), "c_edge": Color("d8b05a")}
const HEAL := {"c_core": Color("f0ffe8"), "c_mid": Color("a8f0b8"), "c_edge": Color("3a9a6a")}
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd86a"), "c_edge": Color("b87a1a")}
const HAND := {"tint": Color("ffe6a8"), "ember": Color("ffd878"), "glow": Color("fff2c8"), "rim": 0.9, "shadow": Color("b07a3a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var sky := Vector3(0, 4.6, 0) - r.toward_camera() * 0.6
	A.glow(r, 1, sky, Vector3.ONE * 1.6, Vector3(-1.0, A.S.face_camera(r), 0), GOLD, 0.0, duration + 0.12, 0.8, {"p1": 0.6, "life": 9.0}, {"grow": duration, "from": 0.2, "veil": true})
	A.flash(r, sky, 2.0, LIGHT, 0.0, duration + 0.1, 0.35, {"grow": duration, "from": 0.2})
	A.S.motes(r, Vector3.ZERO, 1.4, c.n(4, 6, 9), LIGHT, 0.24, 0.0, duration * 0.6, 0.8, 2.2, 10, 1.0)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 2.0)
	var r := c.root(origin, 1.9, "Hand", origin)
	if not r:
		return true
	var cam := r.toward_camera()
	var yaw := atan2(cam.x, cam.z)
	var over := Vector3(0, 2.4, 0) - cam * 0.7
	# The hand reaches down out of the sky, palm turned to bless, and lowers over the priest.
	A.solid(r, A.mesh("hand"), HAND, over + Vector3(0, 1.0, 0), Vector3.ONE * 1.35, Vector3(-0.85, yaw, 0), 0.0, 1.6,
		{"travel": Vector3(0, -0.7, 0), "tw": Vector2(0, 0.45), "ease": 2, "grow": 0.3, "from": 0.6, "fin": 0.15, "fout": 0.5, "priority": 1})
	A.glow(r, 2, over + Vector3(0, 0.6, 0) - cam * 0.3, Vector3.ONE * 2.4, Vector3.ZERO, GOLD, 0.1, 1.3, 0.5, {"billboard": true, "p1": 14.0, "p2": 0.32}, {"priority": -1, "fout": 0.5})
	# Light pours from the palm onto the priest; healing washes out at the feet.
	A.column(r, Vector3.ZERO, 0.9, 4.0, LIGHT, 0.3, 1.0, 0.45, -3.0, {"to": Vector3(0.7, 1.0, 0.7)})
	A.ring(r, Vector3.UP * 0.07, 2.8, HEAL, 0.35, 0.7, 0.75)
	A.S.motes(r, Vector3.ZERO, 1.4, c.n(4, 7, 10), HEAL, 0.32, 0.35, 0.6, 1.0, 1.8, 12, 2.0)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, 1.8, GOLD, 0.5, 0.6, 0.6)
		A.S.motes(r, Vector3.ZERO, 1.8, c.n(4, 6, 9), GOLD, 0.22, 0.4, 0.8, 1.0, 1.4, 10, 3.0)
	return true
