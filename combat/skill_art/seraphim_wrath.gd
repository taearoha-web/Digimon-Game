extends RefCounted
## Priest Lv.88 "Seraphim Wrath" (โทสะเสราฟิม): nine orbs of seraphic light. Cosmetic only.
## Wind-up: a seraph of light rises behind the priest, its six wings opening, a halo of
## gold over the priest's head. Release: the seraph's wings beat once and the orbs are
## loosed in a fan; every real orb (SkillTableau.flight) is a small sun of gold with a
## ribbon of light behind it, and the orbs the fan has no foe for fly out through the fan.
## Each hit bursts in a cross of light with a feather or two drifting.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fff8d8"), "c_mid": Color("ffe07a"), "c_edge": Color("c8862a")}
const SUN := {"c_core": Color("fff6d0"), "c_mid": Color("ffd060"), "c_edge": Color("e08a2a")}
const RIBBON := {"c_core": Color("fffbe8"), "c_mid": Color("fff0a0"), "c_edge": Color("d8a04a")}
const SERAPH := {"tint": Color("fff4dc"), "ember": Color("fff0c0"), "glow": Color("fffae8"), "rim": 0.85, "shadow": Color("b8905a"), "spread": 1.0, "flap": 0.0, "flap_rate": 4.0}
const PLUME := {"tint": Color("fff8e8"), "ember": Color("ffe8a8"), "glow": Color("fffcf0"), "rim": 0.5, "shadow": Color("c0a06a")}
const SPREAD := 0.62


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.6, visual)
	var r := c.toward(origin, aim, duration + 0.55, "Seraph", duration)
	if not r:
		return true
	var back := Vector3(0, 0.2, 0) - r.toward_camera() * 0.9
	A.solid(r, K.mesh("seraph"), SERAPH.merged({"spread": 0.0}), back, Vector3.ONE * 0.55, Vector3.ZERO, 0.0, duration + 0.5,
		{"yaw_cam": true, "grow": duration * 0.6, "from": 0.4, "curves": {"spread": [0.0, 0.0, duration, 1.0], "flap": [0.0, 0.0, duration, 0.0, duration + 0.15, 0.7, duration + 0.5, 0.1]}, "fin": 0.1, "fout": 0.25, "priority": -1})
	A.glow(r, 1, Vector3.UP * 2.5, Vector3.ONE * 0.7, K.FLAT, HOLY, 0.0, duration + 0.12, 0.85, {"p1": 0.6, "life": 9.0}, {"grow": duration * 0.8, "from": 0.2, "veil": true})
	A.flash(r, r.to_local(c.hand()), 1.0, SUN, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.0)
	var r := c.toward(origin, center, 0.9, "Loose")
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.flash(r, hand, 1.5, SUN, 0.0, 0.25, 0.5)
	A.glow(r, 6, hand + Vector3.UP * 0.2, Vector3.ONE * 1.1, Vector3(0, A.S.face_camera(r), 0), HOLY, 0.0, 0.35, 0.8, {"p1": 0.16, "p2": 6.0}, {"veil": true})
	A.ring(r, Vector3.UP * 0.07, 2.4, HOLY, 0.0, 0.5, 0.7)
	var hits := int(skill.get("hits", 9))
	var reach := float(skill.get("range", 12.0))
	var spare := hits - A.fan_count(parent, origin, reach, hits)
	if spare > 0 and c.has(0):
		var n := mini(spare, c.n(2, 4, 6))
		for k in n:
			var a := lerpf(-SPREAD, SPREAD, float(k) / float(maxi(1, n - 1)))
			var to := hand + Vector3(sin(a), -0.1, cos(a)) * 9.0
			_orb(r, hand, to, 0.4, 0.03 * float(k))
	return true


static func _orb(r: K, from: Vector3, to: Vector3, seconds: float, start := 0.0) -> void:
	var path := to - from
	r.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 1.5}), from, Vector3.ONE * 0.24, Vector3.ZERO, start, seconds + 0.02, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.02, "fout": 0.04, "priority": 2})
	A.glow(r, 2, from, Vector3.ONE * 0.8, Vector3.ZERO, HOLY, start, seconds + 0.02, 0.45, {"billboard": true, "p1": 8.0, "p2": 0.3}, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.02, "fout": 0.04, "priority": 1})
	A.beam(r, from, to, 0.45, RIBBON, start, seconds * 4.0, 0.7, 9.0, {"veil": true})


## One real orb: a small sun of gold on a ribbon of light.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var c := A.cast(parent, skill, from, seconds + 0.5, null, false)
	var r := c.root(from, seconds + 0.02, "Orb", from - (to - from))
	if not r:
		return null
	var path := r.to_local(to)
	var body := r.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 1.5}), Vector3.ZERO, Vector3.ONE * 0.24, Vector3.ZERO, 0.0, seconds + 0.02, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.02, "fout": 0.04, "priority": 2})
	if not A.essential(r, body):
		return null
	A.glow(r, 2, Vector3.ZERO, Vector3.ONE * 0.8, Vector3.ZERO, HOLY, 0.0, seconds + 0.02, 0.45, {"billboard": true, "p1": 8.0, "p2": 0.3}, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.02, "fout": 0.04, "priority": 1})
	var t := c.root(from, seconds + 0.45, "Trail", from - (to - from))
	A.beam(t, Vector3.ZERO, path, 0.45, RIBBON, 0.0, seconds * 4.0, 0.7, 9.0, {"veil": true})
	return r


## A hit: a cross of light and a feather or two.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	var c := A.cast(parent, skill, at, 0.0, null, false)
	var r := c.root(at, 0.8, "Hit", at + Vector3.BACK)
	if not r:
		return
	A.glow(r, 6, Vector3.UP * 0.3, Vector3.ONE * 0.95, Vector3(0, A.S.face_camera(r), 0), HOLY, 0.0, 0.45, 0.8, {"p1": 0.16, "p2": 7.0}, {"veil": true, "grow": 0.08, "from": 0.5})
	A.flash(r, Vector3.ZERO, 1.2, SUN, 0.0, 0.2, 0.4)
	if c.has(1):
		A.drift(r, PLUME, Vector3.ZERO, 0.3, c.n(1, 2, 2), 0.6, 0.35, 0.0, 0.8, Vector3.ZERO, 9.0)
