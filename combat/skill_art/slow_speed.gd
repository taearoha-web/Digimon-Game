extends RefCounted
## Mage Lv.68 "Slow Speed" (หน่วงเวลา): time itself is slowed over the area. Cosmetic only.
## Wind-up: a clock dial (twelve-point sigil) writes itself over the target area and the
## staff glows ice-blue. Release (with the real hit): the dial flares, its two hands sweep
## round and drag to a crawl, a dome of frozen time closes over the foes, frost motes hang
## nearly still in the air and a ring of cold rolls in from the rim; the dome thins and the
## hands stop.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const TIME := {"c_core": Color("e8fbff"), "c_mid": Color("7fdcff"), "c_edge": Color("2a6ab8")}
const FROST := {"c_core": Color("f2fdff"), "c_mid": Color("b0ecff"), "c_edge": Color("4a8ac8")}
const DEEP := {"c_core": Color("d8f0ff"), "c_mid": Color("6ab0f0"), "c_edge": Color("2a3a9a")}
const HAND := {"tint": Color("d8f6ff"), "ember": Color("a8e8ff"), "glow": Color("f0fcff"), "rim": 0.6, "shadow": Color("2a4a8a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.0)), 3.0, 10.0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var rad := _radius(skill)
	var centre := A.flat(aim)
	var g := c.toward(centre, centre + (centre - origin), duration + 0.15, "Dial", duration)
	if g:
		A.sigil(g, Vector3.UP * 0.05, rad, 12.0, TIME, 0.0, duration + 0.15, duration * 0.9, 0.45, 0.0)
		A.rim(g, Vector3.UP * 0.06, rad, FROST, 0.0, duration + 0.12, 0.45)
	var w := c.toward(origin, aim, duration + 0.1, "Staff", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.1, TIME, 0.0, duration + 0.1, 0.55, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var rad := _radius(skill)
	var c := A.cast(parent, skill, origin, 2.4)
	var centre := A.flat(center)
	var r := c.toward(centre, centre + (centre - origin), 2.3, "Time")
	if not r:
		return true
	# The dial flares; its hands sweep round and drag to a crawl.
	A.sigil(r, Vector3.UP * 0.05, rad, 12.0, TIME, 0.0, 2.2, 0.0, 0.55, 0.0)
	A.flash(r, Vector3.UP * 0.1, rad * 0.8, FROST, 0.0, 0.3, 0.3)
	# Each hand sweeps fast, then drags (two pieces meeting at the same angle).
	for hand in [[rad * 0.78, 1.6, 0.0, -7.0, -0.9, 0.1], [rad * 0.5, 2.0, 2.1, -2.2, -0.25, 0.12]]:
		var size := Vector3(float(hand[1]), 1.0, float(hand[0]))
		var a0 := float(hand[2])
		var at := Vector3.UP * float(hand[5])
		A.solid(r, A.mesh("needle"), HAND, at, size, Vector3(0, a0, 0), 0.0, 0.45, {"spin": Vector3(0, float(hand[3]), 0), "scale_curve": [0.0, 0.3, 0.15, 1.0], "fin": 0.05, "fout": 0.01, "priority": 1})
		A.solid(r, A.mesh("needle"), HAND, at, size, Vector3(0, a0 + float(hand[3]) * 0.45, 0), 0.45, 1.65, {"spin": Vector3(0, float(hand[4]), 0), "fin": 0.01, "fout": 0.6, "priority": 1})
	# A dome of frozen time over the foes; a ring of cold rolls in from the rim.
	A.dome(r, Vector3.ZERO, rad * 0.95, DEEP, 0.05, 1.9, 0.35, {"grow": 0.3, "from": 0.2, "veil": true})
	A.rim(r, Vector3.UP * 0.07, rad * 1.1, FROST, 0.0, 1.0, 0.6, {"to": Vector3.ONE * 0.4, "grow": 0.01, "from": 1.0})
	if c.has(0):
		A.S.motes(r, Vector3.ZERO, rad * 0.8, c.n(6, 10, 16), FROST, 0.26, 0.0, 0.6, 2.0, 0.15, 9, 2.0)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, rad * 0.6, TIME, 0.3, 0.9, 0.4, {"to": Vector3.ONE * 0.5})
		A.S.motes(r, Vector3.ZERO, rad * 0.6, c.n(3, 5, 8), TIME, 0.4, 0.2, 0.8, 1.6, 0.05, 10, 5.0)
	return true
