extends RefCounted
## Archer Lv.84 "Lightning Arrow" (ศรสายฟ้า): one arrow that is a bolt of lightning.
## Cosmetic only. Wind-up: sparks of lightning are pulled into the drawn bow, a seal of
## static turns under the archer. Release: the bow cracks in a ring of light. The real
## arrow (SkillTableau.flight) is a great arrow of lightning inside a jagged bolt that
## follows it to the foe; as it lands, a bolt answers from the sky onto the same foe, a
## ring of thunder rolls out on the ground and sparks fly.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const BOLT := {"c_core": Color("fffbd8"), "c_mid": Color("ffea5a"), "c_edge": Color("c8861a")}
const VOLT := {"c_core": Color("f2f0ff"), "c_mid": Color("b8b0ff"), "c_edge": Color("5a4ac8")}
const STATIC := {"c_core": Color("fff6b0"), "c_mid": Color("f0d84a"), "c_edge": Color("8a6a2a")}
const ARROW := {"tint": Color("fff0a0"), "ember": Color("ffe85a"), "glow": Color("fffae0"), "rim": 0.85, "shadow": Color("6a4a1a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.flash(r, hand, 1.2, BOLT, 0.0, duration + 0.1, 0.6, {"grow": duration, "from": 0.25})
	A.sigil(r, Vector3.UP * 0.05, 1.7, 5.0, STATIC, 0.0, duration + 0.12, duration * 0.8, 0.5, 1.2)
	for k in c.n(1, 3, 4):
		var a := float(k) * 1.7
		var off := Vector3(sin(a) * 1.1, 0.4 + 0.35 * float(k % 2), cos(a) * 1.1 - 0.4)
		A.bolt(r, hand + off, hand, 0.45, VOLT if k % 2 == 1 else BOLT, duration * 0.22 * float(k), 0.14, 0.85, float(k) * 2.9)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 0.6)
	var r := c.toward(origin, center, 0.5, "Crack")
	if r:
		var hand := r.to_local(c.hand())
		A.flash(r, hand, 1.8, BOLT, 0.0, 0.25, 0.6)
		A.glow(r, 1, hand + Vector3(0, 0, 0.35), Vector3.ONE * 1.8, Vector3.ZERO, STATIC, 0.0, 0.4, 0.75, {"p1": 0.6})
	return true


## The real arrow: a great arrow of lightning inside a bolt; the sky answers as it lands.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size: float) -> Node3D:
	var c := A.cast(parent, skill, from, seconds + 0.9, null, false)
	var a := c.root(from, seconds + 0.02, "Arrow", from - (to - from))
	if not a:
		return null
	var path := a.to_local(to)
	var body := A.solid(a, K.mesh("light_arrow"), ARROW, Vector3.ZERO, Vector3.ONE * 1.5 * size, A.pointing(path), 0.0, seconds + 0.02, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.01, "fout": 0.03, "priority": 2})
	if not A.essential(a, body):
		return null
	# The bolt along the path and the sky's answer, on their own root.
	var r := c.root(from, seconds + 0.9, "Strike", from - (to - from))
	if not r:
		return a
	A.beam(r, Vector3.ZERO, path, 0.6, BOLT, 0.0, seconds * 4.0, 0.45, 12.0)
	if c.has(0):
		A.bolt(r, Vector3.ZERO, path, 0.7, BOLT, seconds * 0.5, seconds * 0.6 + 0.08, 0.75, 4.0)
	# The sky answers onto the same foe.
	var ground := Vector3(path.x, path.y - to.y, path.z)
	A.bolt(r, ground + Vector3(0.6, 9.0, -0.4), ground, 1.1, VOLT, seconds, 0.22, 0.95, 7.0)
	A.bolt(r, ground + Vector3(-0.4, 8.0, 0.5), ground, 0.6, BOLT, seconds + 0.05, 0.16, 0.85, 9.0)
	A.ring(r, ground + Vector3.UP * 0.08, 3.4, BOLT, seconds, 0.5, 0.6)
	A.flash(r, path, 2.6, BOLT, seconds, 0.3, 0.55)
	if c.has(1):
		A.ring(r, ground + Vector3.UP * 0.09, 2.0, VOLT, seconds + 0.08, 0.45, 0.5)
		A.S.sparks(r, path, c.n(5, 8, 12), BOLT, 0.25, seconds, 0.55, 8.0, 3.0, 10, 1.0, 3.0)
	return a


static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass # the arrow's own landing (flight) draws the strike
