extends RefCounted
## Archer Lv.76 "Arrow of Thunder" (ศรอัสนี): one arrow of lightning leaping from foe to
## foe. Cosmetic only. Wind-up: sparks crackle up and down the drawn bow, a ring of static
## at the feet. Release: the bow cracks with a ring of light. Every jump of the real chain
## (SkillTableau.link) is a thunder arrow streaking to its foe inside a jagged bolt, the
## links following one another down the chain; every foe struck flares in a star of
## thunder with sparks thrown off.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const BOLT := {"c_core": Color("fffad0"), "c_mid": Color("ffe85a"), "c_edge": Color("d08a1a")}
const STATIC := {"c_core": Color("fff6b0"), "c_mid": Color("f0d84a"), "c_edge": Color("8a6a2a")}
const ARROW := {"tint": Color("fff2a0"), "ember": Color("ffe85a"), "glow": Color("fff8d0"), "rim": 0.8, "shadow": Color("7a5a1a")}
## Links in the same frame follow one another down the chain.
const STEP := 0.05
static var _frame := -1
static var _step := 0


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.flash(r, hand, 1.0, BOLT, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.3})
	for k in c.n(1, 2, 3):
		var off := Vector3(sin(float(k) * 2.4), 0.5 + 0.3 * float(k), cos(float(k) * 2.4)) * 0.8
		A.bolt(r, hand + off, hand, 0.5, BOLT, duration * 0.3 * float(k), 0.16, 0.9, float(k) * 1.7)
	A.ring(r, Vector3.UP * 0.06, 1.6, STATIC, 0.0, duration + 0.1, 0.45, {"to": Vector3.ONE * 0.6})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 0.6)
	var r := c.toward(origin, center, 0.5, "Crack")
	if r:
		var hand := r.to_local(c.hand())
		A.flash(r, hand, 1.5, BOLT, 0.0, 0.25, 0.6)
		A.glow(r, 1, hand + Vector3(0, 0, 0.3), Vector3.ONE * 1.4, Vector3.ZERO, STATIC, 0.0, 0.35, 0.7, {"p1": 0.6})
	return true


## One jump of the chain: a thunder arrow inside a bolt.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_step = 0
	var delay := STEP * float(_step)
	_step += 1
	var c := A.cast(parent, skill, from, 0.0, null, false)
	var r := c.root(from, delay + 0.7, "Link%d" % _step, from - (to - from))
	if not r:
		return
	var path := r.to_local(to)
	A.bolt(r, Vector3.ZERO, path, 0.75, BOLT, delay, 0.22, 0.9, float(_step) * 3.1)
	if c.has(0):
		A.bolt(r, Vector3.ZERO, path, 0.4, STATIC, delay + 0.08, 0.16, 0.7, float(_step) * 5.3 + 1.0)
		A.solid(r, K.mesh("light_arrow"), ARROW, Vector3.ZERO, Vector3.ONE * 1.1, A.pointing(path), delay, 0.1, {"travel": path, "tw": Vector2(0, 0.08), "fin": 0.01, "fout": 0.02, "priority": 2})
	# The foe struck: a star of thunder and sparks.
	A.glow(r, 10, path, Vector3.ONE * 1.9, Vector3.ZERO, BOLT, delay + 0.06, 0.4, 0.85, {"billboard": true})
	if c.has(1):
		A.S.sparks(r, path, c.n(3, 5, 8), BOLT, 0.22, delay + 0.06, 0.45, 7.0, 3.0, 10, 1.0, float(_step))


static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	var c := A.cast(parent, skill, at, 0.0, null, false)
	if not c.has(1):
		return
	var r := c.root(at, 0.6, "Hit", at + Vector3.BACK)
	if r:
		A.ring(r, Vector3(0, 0.08 - at.y, 0), 1.3, STATIC, STEP * float(maxi(0, _step - 1)) + 0.05, 0.4, 0.5)
