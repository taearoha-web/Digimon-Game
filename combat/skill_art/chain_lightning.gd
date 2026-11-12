extends RefCounted
## Priest Lv.60 "Chain Lightning" (สายฟ้าสวรรค์): heaven's lightning leaps through eight
## foes. Cosmetic only. Wind-up: a small halo of gold crackles over the raised holy symbol,
## sparks run down to a ring of light at the priest's feet. Release: the symbol flares.
## Every jump of the real chain (SkillTableau.link) is a fork of golden lightning to its
## foe, the links following one another down the chain, while a bolt falls from the sky
## onto each foe struck with a cross-shaped flash and a ring on the ground.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fffbd8"), "c_mid": Color("ffe86a"), "c_edge": Color("c8901a")}
const HALO := {"c_core": Color("fff6c8"), "c_mid": Color("ffd85a"), "c_edge": Color("b8741a")}
const SKY := {"c_core": Color("fffcec"), "c_mid": Color("fff0a0"), "c_edge": Color("d0a040")}
const STEP := 0.045
static var _frame := -1
static var _step := 0


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.glow(r, 1, hand + Vector3.UP * 0.5, Vector3.ONE * 0.8, Vector3(-PI / 2, 0, 0), HALO, 0.0, duration + 0.1, 0.8, {"p1": 0.6, "life": 9.0}, {"grow": duration * 0.6, "from": 0.2, "veil": true})
	A.flash(r, hand, 1.0, HOLY, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	for k in c.n(1, 2, 3):
		var a := float(k) * 2.1
		A.bolt(r, hand + Vector3(sin(a) * 0.6, 0.5, cos(a) * 0.6), hand, 0.35, HOLY, duration * 0.25 * float(k), 0.13, 0.85, float(k) * 1.9)
	A.ring(r, Vector3.UP * 0.06, 1.8, HALO, 0.0, duration + 0.1, 0.6, {"to": Vector3.ONE * 0.6})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 0.6)
	var r := c.toward(origin, center, 0.5, "Flare")
	if r:
		var hand := r.to_local(c.hand())
		A.flash(r, hand, 1.5, HOLY, 0.0, 0.25, 0.5)
		A.glow(r, 6, hand + Vector3.UP * 0.2, Vector3.ONE * 1.0, Vector3(0, A.S.face_camera(r), 0), HALO, 0.0, 0.35, 0.8, {"p1": 0.18, "p2": 6.0})
	return true


## One jump of the chain: a fork of golden lightning, and heaven's bolt on the foe.
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
	A.bolt(r, Vector3.ZERO, path, 0.65, HOLY, delay, 0.2, 0.85, float(_step) * 2.7)
	var ground := Vector3(path.x, -from.y, path.z)
	if c.has(0):
		A.bolt(r, ground + Vector3(0.3, 8.5, -0.2), ground, 0.75, SKY, delay + 0.03, 0.18, 0.9, float(_step) * 4.1 + 2.0)
	A.glow(r, 6, path + Vector3.UP * 0.3, Vector3.ONE * 1.2, Vector3(0, A.S.face_camera(r), 0), HALO, delay + 0.03, 0.4, 0.75, {"p1": 0.16, "p2": 8.0}, {"grow": 0.08, "from": 0.5})
	A.ring(r, ground + Vector3.UP * 0.07, 1.4, HALO, delay + 0.03, 0.45, 0.7)
	if c.has(1):
		A.S.sparks(r, path, c.n(2, 4, 6), HOLY, 0.2, delay + 0.03, 0.45, 6.0, 3.0, 10, 1.0, float(_step))


static func contact(_parent: Node3D, _skill: Dictionary, _at: Vector3, _crit: bool) -> void:
	pass # the link (SkillTableau.link) draws each strike
