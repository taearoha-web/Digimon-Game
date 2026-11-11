extends RefCounted
## Priest Lv.64 "Blessing Aura" (ออร่าแห่งพร): a blessing of attack and defence for the
## party. Cosmetic only. Wind-up: motes of gold rise round the priest and a halo forms
## over the raised hands. Release: the blessing spreads: a golden sun-cross burns into the
## ground under the priest, an aura of gold (a dome of light cells) swells round it, two
## rings roll out to bless the party around, and petals of light drift down.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd86a"), "c_edge": Color("b87a1a")}
const AURA := {"c_core": Color("fff8dc"), "c_mid": Color("ffe27a"), "c_edge": Color("c8902a")}
const WARM := {"c_core": Color("fff0d0"), "c_mid": Color("ffc87a"), "c_edge": Color("a8602a")}
const PETAL := {"tint": Color("fff0c0"), "ember": Color("ffe08a"), "glow": Color("fff8e0"), "rim": 0.5, "shadow": Color("b8803a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	A.glow(r, 1, Vector3.UP * 2.6, Vector3.ONE * 0.75, K.FLAT, GOLD, 0.0, duration + 0.12, 0.9, {"p1": 0.6, "life": 9.0}, {"grow": duration * 0.8, "from": 0.2, "veil": true})
	A.S.motes(r, Vector3.ZERO, 1.6, c.n(4, 7, 10), AURA, 0.24, 0.0, duration * 0.6, 0.8, 2.0, 10, 1.0)
	A.ring(r, Vector3.UP * 0.06, 2.2, GOLD, 0.0, duration + 0.1, 0.6, {"to": Vector3.ONE * 0.5})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Bless", origin)
	if not r:
		return true
	# A sun-cross burning into the ground, an aura of gold swelling round the priest.
	A.glow(r, 6, Vector3.UP * 0.06, Vector3.ONE * 3.0, Vector3(-PI / 2, A.S.face_camera(r) + PI, 0), GOLD, 0.0, 1.5, 0.65, {"p1": 0.14, "p2": 5.0}, {"veil": true, "fout": 0.6})
	A.dome(r, Vector3.ZERO, 2.2, AURA, 0.0, 1.4, 0.55, {"grow": 0.3, "from": 0.4, "veil": true})
	A.ring(r, Vector3.UP * 0.07, 5.0, GOLD, 0.05, 0.75, 0.85)
	A.flash(r, Vector3.UP * 1.3, 2.0, WARM, 0.0, 0.35, 0.35)
	if c.has(0):
		A.ring(r, Vector3.UP * 0.08, 6.5, AURA, 0.2, 0.8, 0.55)
		A.column(r, Vector3.ZERO, 0.9, 3.8, AURA, 0.0, 0.7, 0.35, 3.0, {"to": Vector3(0.5, 1.0, 0.5)})
	if c.has(1):
		A.drift(r, PETAL, Vector3.ZERO, 2.0, c.n(4, 6, 10), 2.4, 0.3, 0.1, 1.6, Vector3.ZERO, 3.0)
		A.S.motes(r, Vector3.ZERO, 2.2, c.n(5, 8, 12), GOLD, 0.22, 0.2, 0.8, 1.0, 1.4, 10, 2.0)
	return true
