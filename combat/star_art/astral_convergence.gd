extends RefCounted
## Mage 150-star "Astral Convergence" (บรรจบแห่งดวงดาว). Cosmetic only.
## A gravity well opens on the field: a pool of night sky under the foes with a galaxy
## turning in it, three orbits with their planets wheeling over it and streaks of
## starlight sucked in from the rim. Before each of the three contacts a ring of light
## collapses from the rim onto the centre (the foes are dragged in with it) and bursts
## there as a star; the third burst is a golden nova: a small sun flares and dies, a
## prismatic shock ring rolls out and star sparks are thrown up.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "astral_convergence"
const BEATS := [0.0, 0.36, 0.72]
const PULL := 0.3
const ASTRAL := {"c_core": Color("c8bcff"), "c_mid": Color("7a66ff"), "c_edge": Color("2a1a8a")}
const SPACE := {"c_core": Color("ffe7a0"), "c_mid": Color("6f5bff"), "c_edge": Color("0e0830")}
const GOLD := {"c_core": Color("ffe8a0"), "c_mid": Color("ffc24a"), "c_edge": Color("c0702a")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.7)), 3.0, 8.5)


## A ring collapsing from the rim onto the centre, ending at [param at] (root time).
static func _collapse(r: K, radius: float, at: float, grand: bool) -> void:
	var start := maxf(0.0, at - PULL)
	r.add(K.mesh("quad"), K.GLOW, (GOLD if grand else ASTRAL).merged({"mode": 5, "p1": 24.0, "gain": 0.95}), Vector3.UP * 0.09, Vector3.ONE * radius, K.FLAT, start, at - start + 0.03,
		{"scale_curve": [0.0, 1.0, at - start, 0.08], "spin": Vector3(0, 0, 3.0), "fin": 0.04, "fout": 0.03})
	r.add(K.mesh("quad"), K.GLOW, ASTRAL.merged({"mode": 5, "p1": 12.0, "gain": 0.5}), Vector3.UP * 1.0, Vector3.ONE * radius * 0.7, K.FLAT, start, at - start + 0.03,
		{"scale_curve": [0.0, 1.0, at - start, 0.05], "spin": Vector3(0, 0, -2.0), "fin": 0.04, "fout": 0.03})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var total := time + float(BEATS.back()) + 0.9
	var g := S.root(parent, centre, total, "StarWindup_Well_" + ID, caster.global_position, caster, time)
	if not g:
		return true
	# The pool of night sky and the galaxy turning in it.
	g.add(K.mesh("quad"), K.VEIL, SPACE.merged({"mode": 4, "p1": 0.5}), Vector3.UP * 0.045, Vector3.ONE * r * 0.75 / 0.86, K.FLAT, 0.0, total, {"grow": time * 0.7, "from": 0.05, "fin": 0.2, "fout": 0.45, "priority": -2})
	g.add(K.mesh("quad"), K.GLOW, ASTRAL.merged({"mode": 11, "p1": 5.0, "p2": 0.08, "prism": 0.25, "gain": 0.55}), Vector3.UP * 0.07, Vector3.ONE * r, K.FLAT, 0.0, total, {"grow": time, "from": 0.4, "spin": Vector3(0, 0, -1.6), "fin": 0.2, "fout": 0.45})
	g.add(K.mesh("quad"), K.GLOW, ASTRAL.merged({"mode": 5, "p1": 30.0, "gain": 0.6}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, total - 0.3, {"grow": 0.4, "from": 0.4, "fout": 0.3})
	# Three orbits wheel over the well, closing in as the spell converges.
	var over := g.stage(0.0, 0.8, 2.8)
	var close := [0.0, 1.0, time + float(BEATS.back()), 0.35, total - 0.3, 0.1]
	for k in [1, 2, 3][S.q()]:
		var tilt: Vector3 = [Vector3(0.45, 0, 0.15), Vector3(-0.3, 0, 0.55), Vector3(0.15, 0, -0.65)][k]
		g.add(K.mesh("orbit%d" % k), K.SOLID, {"glow": Color("c8bcff"), "rim": 0.5, "shadow": Color("1a1040")}, over, Vector3.ONE * [1.5, 2.2, 2.9][k], tilt, 0.0, total - 0.3,
			{"grow": time * 0.7, "from": 0.05, "spin": Vector3(0, [2.0, -1.5, 1.1][k], 0), "scale_curve": close, "fin": 0.2, "fout": 0.25})
	S.flash(g, over, 2.2, GOLD, 0.0, total - 0.3, 0.35, {"grow": time, "from": 0.2, "fout": 0.3})
	# Starlight is sucked in from the rim.
	var streaks := []
	var data := []
	var count := S.n(18, 6)
	for k in count:
		var s := K.rand(float(k) * 3.1 + 2.0)
		var a := float(k) * K.GOLDEN
		var rim := Vector3(sin(a), 0, cos(a)) * r
		streaks.append(K.falling(Vector3.UP * (0.3 + 0.8 * s), -rim.normalized() + Vector3.UP * 0.05, 0.9 + 0.5 * s, s))
		data.append(Color(s * (total - 0.9), s, (r - 0.3) / 12.0, 0))
	g.swarm(K.mesh("shard"), K.SOLID, {"motion": 1, "flight": 0.55, "travel": 12.0, "accelerate": 1.0, "stick": 0.0, "ember": Color("d8ccff"), "rim": 0.0}, streaks, data, 0.0, total - 0.3)
	_collapse(g, r, time, false)
	var w := S.root(parent, caster.global_position, time + 0.1, "StarWindup_Hand_" + ID, centre, caster, time)
	if w:
		S.flash(w, w.to_local(S.hand(caster)), 1.4, ASTRAL, 0.0, time + 0.1, 0.6, {"grow": time, "from": 0.2})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var last := index >= BEATS.size() - 1
	var s := K.open(parent, centre, 1.8, "StarContact_Burst_" + ID, source)
	if not s:
		return true
	# The next collapse, one beat ahead so that it lands on its own contact.
	if not last:
		var gap := float(BEATS[index + 1]) - float(BEATS[index])
		_collapse(s, r, gap, index + 1 == BEATS.size() - 1)
	var heart := Vector3.UP * 1.1
	if not last:
		s.add(K.mesh("quad"), K.GLOW, ASTRAL.merged({"mode": 10, "billboard": true, "life": 0.4, "gain": 0.9}), heart, Vector3.ONE * (2.6 + 0.6 * index), Vector3.ZERO, 0.0, 0.4, {"fin": 0.01})
		S.ring(s, Vector3.UP * 0.1, 3.2 + index, ASTRAL, 0.0, 0.4, 0.7)
		S.sparks(s, heart, S.n(10, 4), ASTRAL, 0.2, 0.0, 0.5, 7.0, 3.0, 10, 1.0, float(index))
		return true
	# The golden nova.
	var nova := s.stage(0.0, 0.6, 2.9)
	s.add(K.mesh("sphere"), K.SUN, GOLD.merged({"flow": 4.0}), nova, Vector3.ONE * 0.8, Vector3.ZERO, 0.0, 0.55, {"grow": 0.12, "from": 0.2, "fin": 0.01, "fout": 0.45})
	s.add(K.mesh("quad"), K.GLOW, GOLD.merged({"mode": 2, "billboard": true, "p1": 10.0, "p2": 0.25, "gain": 0.5}), nova, Vector3.ONE * 3.4, Vector3.ZERO, 0.0, 0.6, {"grow": 0.15, "from": 0.3, "fin": 0.01, "fout": 0.4})
	s.add(K.mesh("quad"), K.GLOW, ASTRAL.merged({"mode": 1, "p1": 1.1, "p2": 1.0, "prism": 0.6, "gain": 0.5}), Vector3.UP * 0.1, Vector3.ONE * r * 1.25, K.FLAT, 0.0, 0.8, {"fin": 0.01})
	s.add(K.mesh("column"), K.GLOW, ASTRAL.merged({"mode": 3, "p1": -6.0, "p2": 0.35, "gain": 0.55}), Vector3.ZERO, Vector3(1.0, 7.0, 1.0), Vector3.ZERO, 0.0, 0.8, {"to": Vector3(0.3, 1.0, 0.3), "fin": 0.01, "fout": 0.35})
	S.sparks(s, nova, S.n(24, 8), GOLD, 0.28, 0.0, 1.0, 11.0, 4.0, 10, 1.3, 3.0)
	if not S.lean():
		S.motes(s, Vector3.ZERO, r * 0.8, S.n(16, 5), ASTRAL.merged({"prism": 0.6}), 0.28, 0.25, 0.6, 1.1, 0.9, 10, 1.0)
	return true
