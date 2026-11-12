extends RefCounted
## Priest Lv.76 "Heaven Light" (แสงสวรรค์): heaven's light falls all round the priest
## (harming foes, healing the priest). Cosmetic only. Wind-up: a seal of light writes
## itself round the priest, rings open in the sky above. Release (with the real hit):
## shafts of heavenly light fall one after another all over the circle, each striking with
## a cross-shaped flash, a wave of gold rolls out to the rim, healing rises at the priest's
## feet and feathers of light drift down.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fffbe0"), "c_mid": Color("fff0a0"), "c_edge": Color("d0a040")}
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd86a"), "c_edge": Color("b87a1a")}
const HEAL := {"c_core": Color("f0ffe8"), "c_mid": Color("a8f0b8"), "c_edge": Color("3a9a6a")}
const PLUME := {"tint": Color("fff8e8"), "ember": Color("ffe8a8"), "glow": Color("fffcf0"), "rim": 0.5, "shadow": Color("c0a06a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.0)), 3.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var rad := _radius(skill)
	var r := c.toward(origin, aim, duration + 0.15, "Windup", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, rad * 0.9, 8.0, GOLD, 0.0, duration + 0.15, duration * 0.9, 0.42, 0.3)
	var sky := Vector3(0, 5.0, 0) - r.toward_camera() * 1.5
	A.glow(r, 1, sky, Vector3.ONE * 2.6, Vector3(-1.0, A.S.face_camera(r), 0), HOLY, 0.0, duration + 0.12, 0.7, {"p1": 0.6, "life": 9.0, "p2": 1.0}, {"grow": duration, "from": 0.2, "veil": true})
	A.flash(r, r.to_local(c.hand()), 1.0, HOLY, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 1.9)
	var r := c.root(origin, 1.8, "Light", origin)
	if not r:
		return true
	# Shafts of light fall all over the circle, on the foes first.
	var spots := []
	for spot in A.foes(r, A.flat(origin), rad, c.n(2, 4, 6)):
		spots.append(r.to_local(spot))
	for k in c.n(3, 5, 7):
		spots.append(K.scatter(k, c.n(3, 5, 7), rad * 0.85, 2.0))
	var yaw := A.S.face_camera(r)
	for k in spots.size():
		var at: Vector3 = spots[k]
		var t := 0.04 * float(k)
		A.column(r, at, 0.5, 6.5, HOLY, t, 0.45, 0.6, -7.0, {"to": Vector3(0.4, 1.0, 0.4)})
		if c.has(0) and k < 7:
			A.glow(r, 6, at + Vector3.UP * 1.4, Vector3.ONE * 0.9, Vector3(0, yaw, 0), GOLD, t + 0.04, 0.4, 0.8, {"p1": 0.16, "p2": 7.0}, {"veil": true, "grow": 0.08, "from": 0.5})
	A.marks(r, spots, A.delays(spots.size(), 0.0), 1.2, GOLD, 0.04, 0.45)
	# A wave of gold to the rim; healing at the priest's feet.
	A.ring(r, Vector3.UP * 0.07, rad * 1.1, GOLD, 0.0, 0.7, 0.75)
	A.glow(r, 0, Vector3.UP * 0.04, Vector3.ONE * rad, K.FLAT, HOLY, 0.0, 0.9, 0.3, {"p1": 1.0}, {"veil": true, "fout": 0.6, "priority": -2})
	A.ring(r, Vector3.UP * 0.08, 1.8, HEAL, 0.1, 0.6, 0.7)
	A.S.motes(r, Vector3.ZERO, 1.0, c.n(3, 5, 7), HEAL, 0.3, 0.1, 0.4, 0.9, 1.8, 12, 1.0)
	if c.has(1):
		A.drift(r, PLUME, Vector3.ZERO, rad * 0.6, c.n(4, 6, 10), 3.0, 0.42, 0.1, 1.6, Vector3.ZERO, 2.0)
	return true
