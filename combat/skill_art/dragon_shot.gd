extends RefCounted
## Archer Lv.96 "Dragon Shot" (ศรมังกร): ten dragon arrows at once. Cosmetic only.
## Wind-up: fire coils round the archer like a dragon's body and the bow glows in its
## jaws. Release: a great dragon's head of gold and jade lunges out of the bow and roars
## (a ring of fire, a fan of flame), and every real arrow (SkillTableau.flight) is a small
## dragon arrow of its own trailing fire; the arrows the fan has no foe for fly out
## through the roar. Each hit bursts in a puff of dragonfire.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const FIRE := {"c_core": Color("ffe9a0"), "c_mid": Color("ff9a3a"), "c_edge": Color("c8401a")}
const JADE := {"c_core": Color("eaffd0"), "c_mid": Color("5ee89a"), "c_edge": Color("1a7a4a")}
const FLAME := {"c_core": Color("fff2b0"), "c_mid": Color("ffb85a"), "c_edge": Color("d8501a")}
const DRAGON := {"tint": Color("ffe2a0"), "ember": Color("ffc85a"), "glow": Color("ffe0a0"), "rim": 0.7, "shadow": Color("7a3a1a")}
const SPREAD := 0.7


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Coil", duration)
	if not r:
		return true
	var hand := r.to_local(c.hand())
	A.helix(r, Vector3.UP * 0.05, Vector3(1.3, 0.8, 1.3), FIRE, 0.0, duration + 0.1, 8.0, 0.5, {"scale_curve": [0.0, 1.4, duration, 0.85]})
	A.flash(r, hand, 1.3, FLAME, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
	if c.has(1):
		A.helix(r, Vector3.UP * 0.4, Vector3(0.9, 0.7, 0.9), JADE, 0.03, duration + 0.08, -10.0, 0.35)
		A.S.sparks(r, hand, c.n(3, 5, 7), FIRE, 0.2, 0.0, duration + 0.1, 3.0, 1.0, 9, 1.0, 2.0)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.2)
	var r := c.toward(origin, center, 1.1, "Roar")
	if not r:
		return true
	var hand := r.to_local(c.hand())
	var hits := int(skill.get("hits", 10))
	var reach := float(skill.get("range", 14.0))
	# The dragon's head lunges out of the bow and roars.
	A.solid(r, K.mesh("dragon_arrow"), DRAGON, hand + Vector3(0, 0.1, 0.6), Vector3.ONE * 0.36, A.pointing(Vector3(0, 0, 1)), 0.0, 0.45,
		{"travel": Vector3(0, 0, 2.4), "tw": Vector2(0, 0.3), "ease": 2, "grow": 0.1, "from": 0.4, "fin": 0.02, "fout": 0.18, "priority": 2})
	A.flash(r, hand + Vector3(0, 0, 1.2), 2.2, FLAME, 0.0, 0.35, 0.55)
	A.glow(r, 1, hand + Vector3(0, 0, 1.4), Vector3.ONE * 2.6, Vector3.ZERO, FIRE, 0.02, 0.45, 0.7, {"p1": 0.8, "p2": 0.6})
	# A fan of flame down the volley.
	for k in c.n(3, 5, 7):
		var a := lerpf(-SPREAD, SPREAD, float(k) / float(maxi(1, c.n(3, 5, 7) - 1)))
		A.beam(r, hand, hand + Vector3(sin(a), -0.1, cos(a)) * 8.5, 0.9, FLAME, 0.03 * float(k % 3), 0.5, 0.35, 8.0)
	if c.has(1):
		A.puffs(r, hand + Vector3(0, -0.3, 1.6), 0.7, c.n(2, 3, 5), FLAME, 0.9, 0.02, 0.55, 0.6, true, 2.0)
	var spare := hits - A.fan_count(parent, origin, reach, hits)
	if spare > 0 and c.has(0):
		var xf := []
		var data := []
		var n := mini(spare, c.n(3, 5, 8))
		for k in n:
			var a := lerpf(-SPREAD, SPREAD, float(k) / float(maxi(1, n - 1)))
			var dir := Vector3(sin(a), -0.07, cos(a))
			xf.append(K.falling(hand + dir * 10.0, dir, 0.11, 0.0))
			data.append(Color(0.03 * float(k), K.rand(float(k)), 0.0, 0))
		r.swarm(K.mesh("dragon_arrow"), K.SOLID, DRAGON.merged({"motion": 1, "flight": 0.4, "travel": 75.0, "hold": 0.1, "stick": 0.0}), xf, data, 0.0, 0.65, {"fin": 0.01, "fout": 0.08})
	return true


## One real arrow: a small dragon arrow trailing fire.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size: float) -> Node3D:
	var c := A.cast(parent, skill, from, seconds + 0.5, null, false)
	var r := c.root(from, seconds + 0.02, "Arrow", from - (to - from))
	if not r:
		return null
	var path := r.to_local(to)
	var body := A.solid(r, K.mesh("dragon_arrow"), DRAGON, Vector3.ZERO, Vector3.ONE * 0.12 * size, A.pointing(path), 0.0, seconds + 0.02, {"travel": path, "tw": Vector2(0, seconds), "fin": 0.01, "fout": 0.03, "priority": 2})
	if not A.essential(r, body):
		return null
	var t := c.root(from, seconds + 0.45, "Trail", from - (to - from))
	A.beam(t, Vector3.ZERO, path, 0.5, FIRE, 0.0, seconds * 4.0, 0.4, 9.0)
	return r


## A hit: a puff of dragonfire.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	var c := A.cast(parent, skill, at, 0.0, null, false)
	var r := c.root(at, 0.8, "Hit", at + Vector3.BACK)
	if not r:
		return
	A.puffs(r, Vector3(0, -0.5, 0), 0.35, c.n(1, 2, 3), FLAME, 0.9, 0.0, 0.5, 0.9, true, 5.0, 0.05)
	A.flash(r, Vector3.ZERO, 1.5, FIRE, 0.0, 0.22, 0.5)
	if c.has(1):
		A.S.sparks(r, Vector3.ZERO, c.n(3, 4, 6), FIRE, 0.2, 0.0, 0.5, 6.0, 4.0, 9, 1.0, 1.0)
