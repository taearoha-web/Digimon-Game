extends RefCounted
## Mage Lv.64 "Silraphim" (ซิลราฟิม): a blessing of arcane strength (attack and defence).
## Cosmetic only. Wind-up: an eight-point arcane sigil writes itself round the mage and
## three crystals rise out of it, circling. Release: the crystals close in over the mage's
## head and burst into stars, two crescents of rose light open behind the shoulders like
## wings, a slim column of light runs through the mage and a ring of light rolls out;
## petals of light drift up as it settles.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const ROSE := {"c_core": Color("ffe4ff"), "c_mid": Color("f0a0ff"), "c_edge": Color("8a4ac8")}
const LILAC := {"c_core": Color("f4e8ff"), "c_mid": Color("c8a0ff"), "c_edge": Color("5a3aa8")}
const STAR := {"c_core": Color("fff0ff"), "c_mid": Color("ffb8f0"), "c_edge": Color("a05ac8")}
const GEM := {"tint": Color("f0c8ff"), "ember": Color("ffd0ff"), "glow": Color("fff0ff"), "rim": 0.9, "shadow": Color("5a2a8a")}
const MOON := {"tint": Color("ffd8ff"), "ember": Color("ffc0f0"), "glow": Color("fff0ff"), "rim": 0.8, "shadow": Color("7a3a9a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Sigil", duration)
	if not r:
		return true
	A.sigil(r, Vector3.UP * 0.05, 2.0, 8.0, LILAC, 0.0, duration + 0.15, duration * 0.8, 0.5, 0.8)
	for k in c.n(1, 2, 3):
		var a := float(k) * TAU / 3.0
		A.solid(r, K.mesh("crystal"), GEM, Vector3(sin(a), 0.2, cos(a)) * 1.3, Vector3.ONE * 0.4, Vector3.ZERO, 0.0, duration + 0.12, {"travel": Vector3(0, 1.2, 0), "ease": 2, "spin": Vector3(0, 3.0, 0), "grow": duration * 0.5, "from": 0.2})
	A.flash(r, r.to_local(c.hand()), 1.0, ROSE, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.8)
	var r := c.root(origin, 1.7, "Bless", origin)
	if not r:
		return true
	var cam := r.toward_camera()
	var yaw := atan2(cam.x, cam.z)
	var crown := Vector3(0, 2.7, 0)
	# The crystals close in over the head and burst into stars.
	for k in c.n(1, 2, 3):
		var a := float(k) * TAU / 3.0
		var from := Vector3(sin(a), 1.4, cos(a)) * Vector3(1.3, 1.0, 1.3)
		A.solid(r, K.mesh("crystal"), GEM, from, Vector3.ONE * 0.4, Vector3.ZERO, 0.0, 0.24, {"travel": crown - from - Vector3(0, 0.5, 0), "ease": 1, "spin": Vector3(0, 6.0, 0), "fout": 0.04})
	A.glow(r, 10, crown, Vector3.ONE * 1.8, Vector3.ZERO, STAR, 0.2, 0.6, 0.85, {"billboard": true})
	A.S.sparks(r, crown, c.n(4, 7, 10), STAR, 0.24, 0.2, 0.6, 5.0, 1.5, 10, 1.0, 1.0)
	# Two crescents of rose light open behind the shoulders like wings.
	for side in [-1.0, 1.0]:
		var at: Vector3 = Vector3(0, 1.8, 0) - cam * 0.4 + cam.cross(Vector3.UP) * float(side) * -1.0
		A.solid(r, K.mesh("crescent"), MOON, at, Vector3(1.05, 1.35, 1.05), Vector3(0, yaw, (PI if side > 0 else 0.0) + side * 0.35), 0.1, 1.4,
			{"grow": 0.3, "from": 0.3, "fin": 0.1, "fout": 0.45, "priority": -1})
		A.glow(r, 0, at, Vector3.ONE * 1.6, Vector3(0, yaw, 0), ROSE, 0.1, 1.2, 0.5, {"p1": 1.4}, {"veil": true, "grow": 0.3, "from": 0.3, "priority": -2})
	# A column of rose light through the mage, rings of light rolling out.
	A.column(r, Vector3.ZERO, 1.0, 4.4, ROSE, 0.05, 0.9, 0.7, 4.0, {"to": Vector3(0.5, 1.0, 0.5), "veil": true})
	A.ring(r, Vector3.UP * 0.07, 3.6, LILAC, 0.1, 0.65, 0.8)
	A.sigil(r, Vector3.UP * 0.05, 2.4, 8.0, ROSE, 0.0, 1.3, 0.0, 0.5, -0.5)
	if c.has(0):
		A.ring(r, Vector3.UP * 0.08, 2.4, ROSE, 0.25, 0.6, 0.7)
	if c.has(1):
		A.S.motes(r, Vector3.ZERO, 1.6, c.n(5, 8, 12), STAR, 0.26, 0.25, 0.8, 1.0, 1.8, 10, 2.0)
		A.drift(r, {"tint": Color("ffd0f4"), "ember": Color("ffe0ff"), "glow": Color("fff0ff"), "rim": 0.5, "shadow": Color("8a4aa0")}, Vector3.ZERO, 1.6, c.n(3, 5, 7), 2.8, 0.3, 0.2, 1.3, Vector3.ZERO, 3.0)
	return true
