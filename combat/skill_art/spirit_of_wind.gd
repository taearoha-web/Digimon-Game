extends RefCounted
## Archer Lv.92 "Spirit of the Wind" (วิญญาณแห่งสายลม): the wind itself takes the archer's
## side (speed, attack, crits). Cosmetic only. Wind-up: a ring of wind closes in on the
## archer and leaves are drawn round and up. Release: the spirit of the wind rises round
## the archer: two spirals of wind climb and spin out, wings of jade wind open behind the
## shoulders with one great beat, feathers of wind whirl up and a gust ring runs out over
## the ground; the wind settles in a few leaves and motes.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const WIND := {"c_core": Color("d8fff2"), "c_mid": Color("7affd0"), "c_edge": Color("1f9a7e")}
const JADE := {"c_core": Color("e8fff0"), "c_mid": Color("8ff5c8"), "c_edge": Color("2a8a6a")}
const SKY := {"c_core": Color("f0fff8"), "c_mid": Color("b8fff0"), "c_edge": Color("4ab8a0")}
const WINGS := {"tint": Color("aef5d8"), "ember": Color("d8fff0"), "glow": Color("e8fff8"), "rim": 0.9, "shadow": Color("2a7a6a"), "spread": 1.0, "flap": 0.0, "flap_rate": 5.0}
const PLUME := {"tint": Color("b8f8e0"), "ember": Color("e0fff4"), "glow": Color("f0fff8"), "rim": 0.6, "shadow": Color("3a8a7a")}
const LEAF := {"tint": Color("8fe39a"), "ember": Color("c8ff9a"), "glow": Color("e6ffd0"), "rim": 0.45, "shadow": Color("2c6a3a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	A.ring(r, Vector3.UP * 0.06, 3.2, WIND, 0.0, duration + 0.1, 0.45, {"to": Vector3.ONE * 0.35})
	A.helix(r, Vector3.UP * 0.05, Vector3(1.2, 0.9, 1.2), JADE, 0.0, duration + 0.1, 8.0, 0.4, {"scale_curve": [0.0, 1.5, duration, 0.8]})
	if c.has(1):
		A.drift(r, LEAF, Vector3.ZERO, 2.2, c.n(3, 5, 8), 0.4, 0.3, 0.0, duration + 0.3, Vector3(0, 3.0, 0), 1.0)
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Spirit", origin)
	if not r:
		return true
	# Two spirals of wind climbing round the archer.
	A.helix(r, Vector3.UP * 0.05, Vector3(1.0, 1.2, 1.0), WIND, 0.0, 1.1, 7.0, 0.45, {"to": Vector3(1.6, 1.25, 1.6)})
	if c.has(0):
		A.helix(r, Vector3.UP * 0.4, Vector3(0.7, 1.0, 0.7), SKY, 0.08, 0.95, -9.0, 0.35, {"to": Vector3(1.4, 1.2, 1.4)})
	# Wings of jade wind open behind the shoulders with one great beat.
	var back := Vector3(0, 1.65, 0) - r.toward_camera() * 0.25
	A.solid(r, A.mesh("wings"), WINGS.merged({"spread": 0.0}), back, Vector3.ONE * 0.62, Vector3.ZERO, 0.0, 1.3,
		{"grow": 0.25, "from": 0.4, "yaw_cam": true, "curves": {"spread": [0.0, 0.1, 0.28, 1.0], "flap": [0.0, 0.0, 0.3, 0.0, 0.5, 0.6, 1.1, 0.0]}, "fout": 0.45, "priority": -1})
	# A gust ring over the ground, feathers of wind whirling up.
	A.ring(r, Vector3.UP * 0.07, 4.2, WIND, 0.0, 0.6, 0.55)
	A.flash(r, Vector3.UP * 1.2, 2.2, JADE, 0.0, 0.35, 0.4)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, 2.6, SKY, 0.1, 0.5, 0.45)
		A.drift(r, PLUME, Vector3.ZERO, 1.4, c.n(4, 6, 10), 0.4, 0.34, 0.0, 1.5, Vector3(0, 2.2, 0), 2.0)
		A.S.motes(r, Vector3.ZERO, 1.6, c.n(5, 8, 12), SKY, 0.22, 0.2, 0.7, 1.0, 1.8, 9, 3.0)
	if c.has(0):
		A.drift(r, LEAF, Vector3.ZERO, 2.4, c.n(3, 5, 7), 1.8, 0.3, 0.2, 1.5, Vector3(0.8, 0, 0.4), 4.0)
	return true
