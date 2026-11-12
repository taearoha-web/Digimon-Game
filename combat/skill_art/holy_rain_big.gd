extends RefCounted
## Priest Lv.92 "Holy Rain" (ฝนแสงศักดิ์สิทธิ์): a downpour of holy light over a very wide
## field. Cosmetic only. Wind-up: the sky opens over the far side of the area in rings of
## gold, a seal of light writes itself over the whole circle and the first drops of light
## start to fall. Release (with the real hit): the rain of light pours down over the whole
## circle in two waves, every drop landing in a splash of gold, a cross of light flares
## over each foe, a wave rolls out to the rim, motes of gold rise and feathers of light
## drift down as the rain thins.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fffbe0"), "c_mid": Color("fff0a0"), "c_edge": Color("d0a040")}
const GOLD := {"c_core": Color("fff4c8"), "c_mid": Color("ffd86a"), "c_edge": Color("b87a1a")}
const SEAL := {"c_core": Color("fff0c0"), "c_mid": Color("f0c86a"), "c_edge": Color("8a6a2a")}
const DROP := {"tint": Color("fff6d0"), "ember": Color("fff0a0"), "glow": Color("fffcec"), "rim": 0.9, "shadow": Color("c0a05a")}
const PLUME := {"tint": Color("fff8e8"), "ember": Color("ffe8a8"), "glow": Color("fffcf0"), "rim": 0.5, "shadow": Color("c0a06a")}
const FLIGHT := 0.24


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 10.0)), 3.0, 10.0)


static func _sky(r: K, rad: float) -> Vector3:
	var back := -r.toward_camera() * rad * 0.45
	return back + Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position + r.global_basis * back) - 1.0, 4.0, 6.0), 0)


static func _wave(r: K, c: A.Cast, rad: float, count: int, start: float, salt: float) -> void:
	var spots := A.spots(count, rad * 0.92, salt)
	var times := A.delays(count, 0.3, salt)
	A.rain(r, K.mesh("shard"), DROP, spots, times, Vector3(0.08, -1, -0.12), 1.6, FLIGHT, start, 0.1, 10.0, 0.0)
	var landed := []
	for t in times:
		landed.append(float(t) + FLIGHT)
	A.marks(r, spots, landed, 0.85, GOLD, start, 0.4, 1, 0.07, 0.7)
	if c.has(1):
		A.marks(r, spots, landed, 0.7, HOLY, start, 0.3, 10, 0.35, 0.6)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.3, visual)
	var rad := _radius(skill)
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.3, "Sky", duration)
	if g:
		var sky := _sky(g, rad)
		var yaw := A.S.face_camera(g)
		for k in c.n(1, 2, 3):
			A.glow(g, 1, sky + Vector3.UP * 0.3 * float(k), Vector3.ONE * (2.6 + 1.4 * float(k)), Vector3(-1.1, yaw, 0), GOLD, 0.1 * float(k), duration + 0.2, 0.7, {"p1": 0.5, "life": 9.0}, {"grow": duration, "from": 0.2, "veil": true})
		A.sigil(g, Vector3.UP * 0.05, rad, 8.0, SEAL, 0.0, duration + 0.3, duration * 0.85, 0.42, 0.15)
		A.rim(g, Vector3.UP * 0.06, rad, GOLD, 0.0, duration + 0.25, 0.5)
		# The first drops are already falling as the cast ends.
		_wave(g, c, rad, c.n(3, 5, 7), maxf(duration - FLIGHT - 0.08, 0.0), 0.7)
	var w := c.toward(origin, aim, duration + 0.1, "Symbol", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.0, HOLY, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 2.3)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), 2.2, "Rain")
	if not r:
		return true
	_wave(r, c, rad, c.n(7, 12, 18), 0.0, 1.9)
	if c.has(0):
		_wave(r, c, rad, c.n(5, 9, 14), 0.3, 3.7)
	# A cross of light over each foe; a wave to the rim.
	var yaw := A.S.face_camera(r)
	for spot in A.foes(r, centre, rad, c.n(2, 4, 6)):
		var at: Vector3 = r.to_local(spot)
		A.glow(r, 6, at + Vector3.UP * 1.6, Vector3.ONE * 1.0, Vector3(0, yaw, 0), GOLD, 0.05, 0.55, 0.8, {"p1": 0.16, "p2": 7.0}, {"veil": true, "grow": 0.08, "from": 0.5})
	A.ring(r, Vector3.UP * 0.07, rad * 1.1, GOLD, 0.0, 0.75, 0.75)
	A.glow(r, 0, Vector3.UP * 0.04, Vector3.ONE * rad, K.FLAT, HOLY, 0.0, 1.2, 0.3, {"p1": 1.0}, {"veil": true, "fout": 0.7, "priority": -2})
	if c.has(1):
		A.S.motes(r, Vector3.ZERO, rad * 0.8, c.n(6, 9, 14), GOLD, 0.24, 0.2, 0.9, 1.0, 1.6, 10, 2.0)
		A.drift(r, PLUME, Vector3.ZERO, rad * 0.7, c.n(4, 6, 10), 3.2, 0.42, 0.2, 1.8, Vector3.ZERO, 3.0)
	return true
