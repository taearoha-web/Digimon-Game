extends RefCounted
## Archer Lv.100 "Meteor Arrow" (ศรอุกกาบาต): the archer's greatest arrow comes down from
## the sky as a meteor. Cosmetic only. Wind-up: fire crowns the drawn bow, a red reticle
## locks on the prey and the sky over it begins to glow. Release: the arrow is loosed
## straight up in a streak of fire. The real arrow (SkillTableau.flight) is the meteor:
## it dives out of the glowing sky, a burning rock round a great arrow of flame, and lands
## on the prey at the real hit: a column of fire, two shock rings, a cracked scorch, flame
## bursting all round, sparks and rock thrown up; the burn smoulders as the smoke rises.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const FIRE := {"c_core": Color("ffe8a0"), "c_mid": Color("ff8a3a"), "c_edge": Color("c02a1a")}
const BLAZE := {"c_core": Color("fff0b8"), "c_mid": Color("ffb04a"), "c_edge": Color("e0501a")}
const LOCK := {"c_core": Color("ffd0a0"), "c_mid": Color("ff6a3a"), "c_edge": Color("a02020")}
const ASH := {"c_core": Color("3a2420"), "c_mid": Color("ff6a2a"), "c_edge": Color("1a0e0c")}
const SMOKE := {"c_core": Color("8a7a78"), "c_mid": Color("5a4a4a"), "c_edge": Color("2a2026")}
const RETICLE := {"tint": Color("ffb08a"), "ember": Color("ff7a4a"), "glow": Color("ffd0b0"), "rim": 0.3, "shadow": Color("6a1a1a")}
const ROCK := {"tint": Color("8a4a3a"), "ember": Color("ffb04a"), "glow": Color("ff9a5a"), "rim": 0.8, "shadow": Color("3a1a1a")}
const ARROW := {"tint": Color("ffd08a"), "ember": Color("ff9a3a"), "glow": Color("fff0c0"), "rim": 0.85, "shadow": Color("7a2a1a")}
static var _chips: Mesh
const CHIP := {"tint": Color("6a3a2a"), "ember": Color("ff8a3a"), "glow": Color("ff9a5a"), "rim": 0.5, "shadow": Color("2a1414"), "motion": 3}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.8, visual)
	var w := c.toward(origin, aim, duration + 0.12, "Crown", duration)
	if w:
		var hand := w.to_local(c.hand())
		A.flash(w, hand, 1.5, BLAZE, 0.0, duration + 0.1, 0.6, {"grow": duration, "from": 0.25})
		A.glow(w, 2, hand, Vector3.ONE * 1.4, Vector3.ZERO, FIRE, 0.0, duration + 0.1, 0.5, {"billboard": true, "p1": 9.0, "p2": 0.3}, {"grow": duration, "from": 0.3})
		if c.has(1):
			A.sigil(w, Vector3.UP * 0.05, 1.8, 5.0, LOCK, 0.0, duration + 0.12, duration * 0.8, 0.45, 1.0)
	var prey := A.flat(aim)
	var g := c.toward(prey, prey + (prey - origin), duration + 0.8, "Lock", duration)
	if g:
		A.solid(g, K.mesh("reticle"), RETICLE, Vector3.UP * 1.3, Vector3.ONE * 1.5, Vector3.ZERO, 0.0, duration + 0.75,
			{"scale_curve": [0.0, 2.4, duration * 0.8, 1.0], "spin": Vector3(0, 0, 1.6), "yaw_cam": true, "fin": 0.06, "fout": 0.2, "priority": 2})
		A.ring(g, Vector3.UP * 0.07, 2.6, LOCK, 0.0, duration + 0.7, 0.45, {"to": Vector3.ONE * 0.5})
		var sky := Vector3(-2.0, clampf(GodSkillArt.headroom(g, g.global_position) - 0.5, 5.0, 8.0), 1.0)
		A.flash(g, sky, 5.0, FIRE, 0.0, duration + 0.75, 0.3, {"grow": duration, "from": 0.2, "veil": true})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 0.8)
	var r := c.toward(origin, center, 0.7, "Loose")
	if r:
		var hand := r.to_local(c.hand())
		A.flash(r, hand, 1.9, BLAZE, 0.0, 0.3, 0.6)
		A.beam(r, hand, hand + Vector3(0.0, 9.0, 0.8), 0.7, FIRE, 0.0, 0.6, 0.6, 10.0)
		A.ring(r, Vector3.UP * 0.07, 2.4, FIRE, 0.0, 0.45, 0.5)
	return true


## The real arrow: the meteor out of the sky onto the prey, landing with the hit.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size: float) -> Node3D:
	var c := A.cast(parent, skill, from, seconds + 2.2, null, false)
	var ground := A.flat(to)
	var m := c.toward(ground, ground + A.flat(to - from), seconds + 0.02, "Meteor")
	if not m:
		return null
	var hit := m.to_local(to)
	var sky := Vector3(-2.0, clampf(GodSkillArt.headroom(m, m.global_position) - 0.5, 5.0, 8.0), 1.0)
	var start := sky + Vector3(0, 4.0, -1.0)
	var dive := hit - start
	var o := {"travel": dive, "tw": Vector2(0, seconds), "ease": 1, "fin": 0.02, "fout": 0.03, "priority": 3}
	var body := A.solid(m, K.mesh("light_arrow"), ARROW, start, Vector3.ONE * 2.4 * size, A.pointing(dive), 0.0, seconds + 0.02, o)
	if not A.essential(m, body):
		return null
	A.solid(m, K.mesh("meteor"), ROCK, start, Vector3.ONE * 2.1 * size, A.pointing(dive), 0.0, seconds + 0.02, o)
	A.flash(m, start, 3.0, BLAZE, 0.0, seconds + 0.02, 0.45, o.merged({"fout": 0.02}))
	# The trail and the landing, on their own root.
	var r := c.toward(ground, ground + A.flat(to - from), seconds + 2.2, "Landing")
	if not r:
		return m
	A.beam(r, start, hit, 1.4, FIRE, 0.0, seconds * 4.0, 0.4, 8.0)
	# The landing.
	var t := seconds
	A.column(r, Vector3.ZERO, 1.5, 7.0, BLAZE, t, 0.9, 0.55, -6.0, {"to": Vector3(0.5, 1.0, 0.5)})
	A.ring(r, Vector3.UP * 0.08, 4.6, FIRE, t, 0.6, 0.65)
	A.flash(r, Vector3.UP * 1.0, 4.0, FIRE, t, 0.35, 0.5)
	A.puffs(r, Vector3.ZERO, 2.0, c.n(4, 6, 9), BLAZE, 1.3, t, 0.75, 1.0, true, 2.0, 0.12)
	if c.has(0):
		A.ring(r, Vector3.UP * 0.09, 7.0, BLAZE, t + 0.1, 0.7, 0.45)
		A.scorch(r, Vector3.UP * 0.04, 2.6, ASH, t, 2.0, 5.0)
		A.S.sparks(r, Vector3.UP * 0.6, c.n(8, 14, 22), BLAZE, 0.32, t, 0.9, 11.0, 6.0, 9, 1.2, 1.0)
	if c.has(1):
		var chips := []
		var data := []
		for k in c.n(4, 6, 9):
			var s := K.rand(float(k) * 2.3)
			chips.append(K.standing(Vector3(sin(float(k) * 2.4), 0.5 + s, cos(float(k) * 2.4)) * 0.8, Vector3.ONE * (0.25 + 0.2 * s), s * TAU))
			data.append(Color(0, s, 0, 0))
		r.swarm(_chip(), K.SOLID, CHIP.merged({"hold": 0.8, "drift": Vector3(0, 3.0, 0), "sway": 1.6, "tumble": 5.0}), chips, data, t, 0.9, {"fin": 0.01, "fout": 0.1})
		A.clouds(r, Vector3.UP * 1.6, 1.2, c.n(2, 3, 5), SMOKE, 1.4, t + 0.4, 1.2, 0.4, 7.0)
	return m


static func _chip() -> Mesh:
	if _chips == null:
		var b := K.Build.new()
		b.emit = 0.3
		b.ball(Vector3.ZERO, Vector3(0.5, 0.42, 0.46), Color.WHITE, Color(0.7, 0.7, 0.7), 6, 4)
		_chips = b.commit()
	return _chips


static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass # the meteor's own landing (flight) draws the strike
