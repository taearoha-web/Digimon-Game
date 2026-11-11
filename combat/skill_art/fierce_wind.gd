extends RefCounted
## Archer Lv.60 "Fierce Wind" (ลมกระโชก): seven arrows on one gust. Cosmetic only.
## Wind-up: the wind winds itself round the bow and the leaves at the archer's feet stir.
## Release: a gust bursts from the bow in a fan (streaks of wind, a ring round the shot,
## dust kicked back), leaves are blown down the fan, and each real arrow rides its own
## ribbon of wind; the arrows the fan has no foe for fly out down the gust. Each hit is
## a small burst of wind and leaves.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const WIND := {"c_core": Color("d2fff0"), "c_mid": Color("7ff5c8"), "c_edge": Color("23a886")}
const GUST := {"c_core": Color("b8ffe8"), "c_mid": Color("5ee8bc"), "c_edge": Color("1a7f6e")}
const DUST := {"c_core": Color("e8f2dc"), "c_mid": Color("b7c8a6"), "c_edge": Color("6f845e")}
const ARROW := {"tint": Color("c8ffe8"), "ember": Color("8fffd0"), "glow": Color("d8fff2"), "rim": 0.7, "shadow": Color("1f6a58")}
const LEAF := {"tint": Color("8fe39a"), "ember": Color("c8ff9a"), "glow": Color("e6ffd0"), "rim": 0.45, "shadow": Color("2c6a3a")}
const SPREAD := 0.62


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.helix(r, hand + Vector3(0, -0.7, 0), Vector3(0.9, 0.55, 0.9), WIND, 0.0, duration + 0.1, 9.0, 0.45, {"scale_curve": [0.0, 1.6, duration, 0.7]})
	A.flash(r, hand, 0.9, WIND, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	if c.has(1):
		A.ring(r, Vector3.UP * 0.06, 2.2, GUST, 0.0, duration + 0.1, 0.4, {"to": Vector3.ONE * 0.4})
		A.drift(r, LEAF, Vector3.ZERO, 1.6, c.n(2, 4, 6), 0.6, 0.35, 0.0, duration + 0.3, Vector3(0, 2.0, 0), 1.0)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.4)
	var r := c.toward(origin, center, 1.4, "Gust")
	if not r:
		return true
	var hand := r.to_local(c.hand())
	var hits := int(skill.get("hits", 7))
	var reach := float(skill.get("range", 13.0))
	# The bow: a burst of wind and a ring round the shot.
	A.flash(r, hand, 1.2, WIND, 0.0, 0.25, 0.4)
	A.ring_up(r, hand + Vector3(0, 0, 0.4), 1.5, GUST, 0.0, 0.4, 0.8)
	# The gust: a wedge of wind rolling down the fan over the ground, streaks along it.
	A.gust(r, Vector3(0, 0.15, 0.3), 10.5, GUST, 0.0, 0.75, 0.75, 0.0, {"veil": true})
	if c.has(0):
		A.gust(r, Vector3(0, 0.9, 0.3), 9.0, WIND, 0.03, 0.6, 0.3, 0.0, {"priority": 1})
	for k in c.n(2, 3, 5):
		var a := lerpf(-SPREAD, SPREAD, float(k) / float(maxi(1, c.n(2, 3, 5) - 1)))
		var to := hand + Vector3(sin(a), -0.15, cos(a)) * (8.5 + 1.5 * K.rand(float(k)))
		A.beam(r, hand, to, 0.55, GUST, 0.02 * float(k % 3), 0.5, 0.65, 9.0, {"veil": true})
	if c.has(1):
		A.puffs(r, Vector3(0, 0, -0.6), 0.8, c.n(2, 3, 5), DUST, 0.75, 0.0, 0.6, 0.4, true, 2.0)
		A.drift(r, LEAF, Vector3(0, 0.6, 2.5), 1.6, c.n(3, 6, 10), 1.4, 0.5, 0.02, 1.0, Vector3(0, 0, 6.0), 4.0)
	# Arrows the fan has no foe for fly out down the gust (the real ones fly themselves).
	var spare := hits - A.fan_count(parent, origin, reach, hits)
	if spare > 0 and c.has(0):
		var xf := []
		var data := []
		for k in mini(spare, c.n(2, 4, 7)):
			var a := lerpf(-SPREAD, SPREAD, float(k) / float(maxi(1, mini(spare, c.n(2, 4, 7)) - 1)))
			var dir := Vector3(sin(a), -0.08, cos(a))
			xf.append(K.falling(hand + dir * 10.0, dir, 1.0, float(k)))
			data.append(Color(0.02 * float(k), K.rand(float(k)), 0.85, 0))
		r.swarm(K.mesh("light_arrow"), K.SOLID, ARROW.merged({"motion": 1, "flight": 0.42, "travel": 10.0, "hold": 0.1, "stick": 0.0}), xf, data, 0.0, 0.7, {"fin": 0.01, "fout": 0.1})
	return true


## One real arrow on its own ribbon of wind.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size: float) -> Node3D:
	var c := A.cast(parent, skill, from, seconds + 0.5, null, false)
	var r := c.root(from, seconds + 0.02, "Arrow", from - (to - from))
	if not r:
		return null
	var path := r.to_local(to)
	var body := A.solid(r, K.mesh("light_arrow"), ARROW, Vector3.ZERO, Vector3.ONE * 0.95 * size, A.pointing(path), 0.0, seconds + 0.02, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.01, "fout": 0.04, "priority": 2})
	if not A.essential(r, body):
		return null
	var t := c.root(from, seconds + 0.4, "Trail", from - (to - from))
	A.beam(t, Vector3.ZERO, path, 0.4, GUST, 0.0, seconds * 4.0, 0.7, 10.0, {"veil": true})
	return r


## A hit: a small burst of wind and leaves.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	var c := A.cast(parent, skill, at, 0.0, null, false)
	var r := c.root(at, 0.7, "Hit", at + Vector3.BACK)
	if not r:
		return
	A.flash(r, Vector3.ZERO, 1.3, WIND, 0.0, 0.25, 0.55)
	A.ring_up(r, Vector3.ZERO, 1.5, GUST, 0.0, 0.35, 0.6)
	if c.has(1):
		A.drift(r, LEAF, Vector3.ZERO, 0.4, c.n(2, 3, 4), 0.4, 0.28, 0.0, 0.6, Vector3(0, 1.6, 0), 7.0)
