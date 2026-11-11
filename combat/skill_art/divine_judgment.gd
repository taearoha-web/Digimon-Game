extends RefCounted
## Priest Lv.80 "Divine Judgment" (คำพิพากษาแห่งสวรรค์): heaven's sword passes judgement on
## one foe and binds it (the stun). Cosmetic only. Wind-up: a seal of judgement opens in
## the sky over the foe and a sword of light forms in it point down, while the ground seal
## writes itself under the foe and the priest's symbol glows. Release (with the real hit):
## the sword drops point first onto the foe, a cross of light flares over it, the ground
## seal flashes and a shock ring rolls out; a ring of golden chains closes round the foe and
## turns there while it is stunned, and the sword fades where it stands.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const A := preload("res://combat/skill_art/_sky.gd")
const HOLY := {"c_core": Color("fff6d8"), "c_mid": Color("ffe08a"), "c_edge": Color("c0802a")}
const SEAL := {"c_core": Color("fff0c0"), "c_mid": Color("f4c060"), "c_edge": Color("8a5a1a")}
const SHAFT := {"c_core": Color("fffbe8"), "c_mid": Color("fff0a0"), "c_edge": Color("d8a84a")}
const SWORD := {"tint": Color("fff2c8"), "ember": Color("ffe08a"), "glow": Color("fffae0"), "rim": 0.95, "shadow": Color("a8702a")}
const CHAIN := {"tint": Color("ffe8a0"), "ember": Color("ffd060"), "glow": Color("fff4d0"), "rim": 0.7, "shadow": Color("8a5a1a")}
const DROP := 0.14


static func _sky(r: K) -> Vector3:
	return Vector3(0, clampf(GodSkillArt.headroom(r, r.global_position) - 0.8, 4.5, 6.5), 0)


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := A.cast(parent, skill, origin, duration + 0.3, visual)
	var foe := A.flat(aim)
	var g := c.toward(foe, foe + (foe - origin), duration + 0.25, "Seal", duration)
	if g:
		var sky := _sky(g)
		A.glow(g, 17, sky, Vector3.ONE * 1.8, Vector3(-1.1, A.S.face_camera(g), 0), SEAL, 0.0, duration + 0.2, 0.7, {"p1": 6.0, "p2": 1.0 / maxf(duration * 0.8 / (duration + 0.2), 0.05), "life": duration + 0.2}, {"veil": true, "fin": 0.05, "fout": 0.15})
		A.solid(g, A.mesh("sword"), SWORD, sky + Vector3.DOWN * 3.1, Vector3.ONE * 0.95, Vector3(0, A.S.face_camera(g), 0), duration * 0.3, duration * 0.7 + 0.02,
			{"grow": duration * 0.5, "from": 0.3, "fin": 0.08, "fout": 0.02, "priority": 2})
		A.sigil(g, Vector3.UP * 0.05, 1.8, 6.0, SEAL, 0.0, duration + 0.25, duration * 0.8, 0.5, 0.6)
	var w := c.toward(origin, aim, duration + 0.1, "Symbol", duration)
	if w:
		A.flash(w, w.to_local(c.hand()), 1.0, HOLY, 0.0, duration + 0.1, 0.5, {"grow": duration, "from": 0.2})
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var stun := float(skill.get("fx", {}).get("stun", 1.5))
	var c := A.cast(parent, skill, origin, stun + 0.8)
	var foe := A.flat(center)
	var r := c.toward(foe, foe + (foe - origin), stun + 0.8, "Verdict")
	if not r:
		return true
	var yaw := A.S.face_camera(r)
	var sky := _sky(r)
	# The sword drops point first onto the foe and stands there.
	A.solid(r, A.mesh("sword"), SWORD, sky + Vector3.DOWN * 3.1, Vector3.ONE * 0.95, Vector3(0, yaw, 0), 0.0, DROP + 0.02,
		{"travel": Vector3.DOWN * (sky.y - 3.1 + 0.4), "tw": Vector2(0, DROP), "ease": 1, "fin": 0.01, "fout": 0.01, "priority": 2})
	A.solid(r, A.mesh("sword"), SWORD, Vector3.DOWN * 0.4, Vector3.ONE * 0.95, Vector3(0, yaw, 0), DROP, 0.75, {"fin": 0.01, "fout": 0.4, "priority": 2})
	A.column(r, Vector3.ZERO, 0.6, sky.y, SHAFT, 0.0, 0.4, 0.5, -8.0, {"to": Vector3(0.4, 1.0, 0.4)})
	A.glow(r, 6, Vector3.UP * 1.7, Vector3.ONE * 1.6, Vector3(0, yaw, 0), HOLY, DROP, 0.6, 0.85, {"p1": 0.15, "p2": 7.0}, {"veil": true, "grow": 0.1, "from": 0.5})
	A.ring(r, Vector3.UP * 0.07, 2.8, HOLY, DROP, 0.55, 0.8)
	A.sigil(r, Vector3.UP * 0.05, 1.8, 6.0, SEAL, 0.0, stun + 0.4, 0.0, 0.55, -0.4)
	# A ring of golden chains closes round the foe and turns while it is stunned.
	if c.has(0):
		var links := c.n(8, 10, 14)
		var xf := []
		var data := []
		for k in links:
			var a := float(k) * TAU / float(links)
			# Each link lies along the circle, every other one turned a quarter about its length.
			xf.append(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, -PI / 2) * Basis(Vector3.UP, PI / 2 * float(k % 2)), Vector3(sin(a), 0, cos(a)) * 1.0))
			data.append(Color(0, K.rand(float(k)), 0, 0))
		r.swarm(K.mesh("link"), K.SOLID, CHAIN, xf, data, DROP + 0.05, stun, {"at": Vector3.UP * 0.9, "spin": Vector3(0, 1.4, 0), "grow": 0.2, "from": 2.2, "fin": 0.05, "fout": 0.3})
	if c.has(1):
		A.S.sparks(r, Vector3.UP * 0.9, c.n(5, 8, 12), HOLY, 0.24, DROP, 0.6, 7.0, 3.0, 10, 1.0, 1.0)
		A.ring(r, Vector3.UP * 0.08, 1.6, SEAL, DROP + 0.1, 0.5, 0.6)
	return true
