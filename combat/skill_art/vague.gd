extends RefCounted
## Mage Lv.72 "Vague" (ร่างพร่าเลือน): the mage's body blurs (defence, speed). Cosmetic only.
## Wind-up: rings of shimmering violet distortion close in round the mage. Release: a veil
## of mirror-glass wraps the mage (a ward of hex cells), six mirror shards wheel round it
## catching the light, two after-image rings slide off to either side and fade, and the
## air ripples outward; a few glints hang on as it settles.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HAZE := {"c_core": Color("efe6ff"), "c_mid": Color("b79bff"), "c_edge": Color("4a3a9a")}
const GLASS := {"c_core": Color("e8f0ff"), "c_mid": Color("a8b8ff"), "c_edge": Color("4a5ab8")}
const GLINT := {"c_core": Color("fbf6ff"), "c_mid": Color("d4c4ff"), "c_edge": Color("7a6ad0")}
const SHARD := {"tint": Color("d8d0ff"), "ember": Color("c8b8ff"), "glow": Color("f4f0ff"), "rim": 0.95, "shadow": Color("3a2a7a")}


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.2, visual)
	var r := c.toward(origin, aim, duration + 0.15, "Haze", duration)
	if not r:
		return true
	A.ring(r, Vector3.UP * 0.07, 2.8, HAZE, 0.0, duration + 0.1, 0.45, {"to": Vector3.ONE * 0.3})
	A.ring_up(r, Vector3.UP * 1.1, 1.6, GLASS, 0.0, duration + 0.1, 0.4, {"to": Vector3.ONE * 0.5})
	A.flash(r, r.to_local(c.hand()), 1.0, HAZE, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, _center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := A.cast(parent, skill, origin, 1.8)
	var r := c.root(origin, 1.7, "Veil", origin)
	if not r:
		return true
	var cam := r.toward_camera()
	var side := cam.cross(Vector3.UP)
	# The veil of mirror-glass round the mage.
	A.dome(r, Vector3.UP * 0.2, 1.6, GLASS, 0.0, 1.4, 0.6, {"grow": 0.18, "from": 1.8, "veil": true})
	A.dome(r, Vector3.UP * 0.2, 1.62, HAZE, 0.0, 1.2, 0.3, {"grow": 0.18, "from": 1.8})
	A.sigil(r, Vector3.UP * 0.05, 2.4, 6.0, HAZE, 0.0, 1.4, 0.2, 0.5, 1.4)
	# Mirror shards wheeling round it.
	var count := c.n(3, 4, 6)
	var xf := []
	var data := []
	for k in count:
		var a := float(k) * TAU / float(count)
		xf.append(Transform3D(Basis.from_euler(Vector3(0.3 * sin(a * 2.0), a, 0.4)).scaled(Vector3.ONE * 0.85), Vector3(sin(a) * 1.9, 0.5 + 0.6 * float(k % 2), cos(a) * 1.9)))
		data.append(Color(0.03 * float(k), K.rand(float(k)), 0, 0))
	r.swarm(K.mesh("crystal"), K.SOLID, SHARD, xf, data, 0.0, 1.4, {"fin": 0.05, "fout": 0.4, "spin": Vector3(0, 3.2, 0), "grow": 0.2, "from": 0.2})
	# After-images slide off to either side and fade.
	if c.has(0):
		for s in [-1.0, 1.0]:
			A.ring_up(r, Vector3.UP * 1.0, 1.6, HAZE, 0.05, 0.7, 0.8, {"travel": side * s * 1.8, "ease": 2, "fout": 0.4})
	A.ring(r, Vector3.UP * 0.07, 3.6, HAZE, 0.0, 0.6, 0.8)
	if c.has(1):
		A.ring(r, Vector3.UP * 0.08, 2.0, GLASS, 0.12, 0.5, 0.4)
		A.S.motes(r, Vector3.UP * 0.3, 1.3, c.n(4, 6, 9), GLINT, 0.22, 0.15, 0.8, 1.0, 0.8, 10, 4.0)
	return true
