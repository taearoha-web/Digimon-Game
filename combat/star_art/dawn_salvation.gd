extends RefCounted
## Priest 200-star "Dawn of Salvation" (รุ่งอรุณแห่งการกอบกู้). Cosmetic only.
## Dawn breaks over the field: a coral-gold sun climbs from the far rim inside its corona,
## its rays slant down onto the field, the ground warms under a rose-gold sigil and
## feathers drift down through the light. Each of the three holy waves is a wall of dawn
## light rolling out from the centre over the foes, a cross of light burning over each,
## while healing washes over the priest's side. On the third the sun flares: a great
## column of dawn falls on the centre, a golden cross burns into the ground and feathers
## rain over the whole field.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "dawn_salvation"
const BEATS := [0.0, 0.65, 1.3]
const DAWN := {"c_core": Color("ffc890"), "c_mid": Color("ff8a5a"), "c_edge": Color("d8406a")}
const SUN := {"c_core": Color("fff0c0"), "c_mid": Color("ffb45a"), "c_edge": Color("f05a50")}
const GILT := {"c_core": Color("ffd88a"), "c_mid": Color("ffb85a"), "c_edge": Color("e8604a")}
const ROSE := {"c_core": Color("ffd2b8"), "c_mid": Color("ff7a6a"), "c_edge": Color("a03060")}
const HEAL := {"c_core": Color("eaffc8"), "c_mid": Color("9ff07a"), "c_edge": Color("f0c060")}
const PLUME := {"motion": 3, "tint": Color("ffe6cc"), "ember": Color("ffd0a0"), "glow": Color("fff2dc"), "rim": 0.5, "shadow": Color("a05a6a")}
## Where the sun hangs (root space of the field roots), set by the wind-up.
static var _sun := Vector3(3.5, 4.2, -0.5)


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.3)), 4.0, 9.0)


static func _feathers(r: K, count: int, radius: float, height: float, start: float, hold: float, salt: float) -> void:
	var plumes := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 3.1 + salt)
		plumes.append(K.standing(K.scatter(k, count, radius, salt) + Vector3.UP * (height * (0.5 + 0.5 * s)), Vector3.ONE * (0.9 + 0.6 * s), s * TAU))
		data.append(Color(s * 0.5, s, 0, 0))
	r.swarm(K.mesh("feather"), K.SOLID, PLUME.merged({"hold": hold, "drift": Vector3(0.15, -height * 0.5 / hold, 0), "sway": 0.5, "tumble": 2.2}), plumes, data, start, hold + 0.55, {"fin": 0.01, "fout": 0.05})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var finale := time + float(BEATS.back())
	var total := finale + 1.3
	var g := S.root(parent, centre, total, "StarWindup_Dawn_" + ID, caster.global_position, caster, time)
	if not g:
		return true
	# The sun climbs from the far rim, flares with the last wave and sets in its glory.
	var up := clampf(GodSkillArt.headroom(g, g.global_position + g.global_basis * g.stage(4.0, 0.0, 0.0)) - 1.2, 2.8, 4.4)
	_sun = g.stage(4.0, 0.0, up)
	var low := g.stage(5.5, -2.0, 0.3)
	var rise := {"travel": _sun - low, "tw": Vector2(0, time * 0.95), "ease": 2, "grow": time * 0.9, "from": 0.35, "fin": 0.2, "fout": 0.4,
		"scale_curve": [0.0, 1.0, finale - 0.3, 1.0, finale - 0.08, 1.3, finale + 0.1, 1.05, total - 0.4, 1.0]}
	g.add(K.mesh("sphere"), K.SUN, SUN.merged({"flow": 0.8}), low, Vector3.ONE * 1.15, Vector3.ZERO, 0.0, total - 0.05, rise)
	g.add(K.mesh("quad"), K.GLOW, SUN.merged({"mode": 2, "billboard": true, "p1": 12.0, "p2": 0.3, "gain": 0.4}), low, Vector3.ONE * 1.15 * 3.4, Vector3.ZERO, 0.0, total - 0.05, rise.merged({"priority": -1}))
	# The ground warms under a rose-gold sigil; the rim marks the area.
	g.add(K.mesh("quad"), K.GLOW, DAWN.merged({"mode": 0, "p1": 1.2, "gain": 0.1}), Vector3.UP * 0.04, Vector3.ONE * r * 1.05, K.FLAT, 0.0, total, {"fin": time, "fout": 0.6})
	g.add(K.mesh("quad"), K.GLOW, ROSE.merged({"mode": 17, "p1": 8.0, "p2": 1.0 / maxf(time * 0.85 / total, 0.05), "gain": 0.4, "life": total}), Vector3.UP * 0.05, Vector3.ONE * r, K.FLAT, 0.0, total, {"spin": Vector3(0, 0, -0.15), "fin": 0.1, "fout": 0.5})
	g.add(K.mesh("quad"), K.GLOW, GILT.merged({"mode": 5, "p1": 30.0, "gain": 0.65}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, total - 0.2, {"grow": 0.5, "from": 0.3, "fout": 0.4})
	if GodSkillArt.extra_roots(1) >= 1:
		var s := S.root(parent, centre, total, "StarWindup_Rays_" + ID, caster.global_position, caster, time)
		if s:
			# Rays slanting down from the sun onto the field, feathers drifting through them.
			for k in [1, 2, 3][S.q()]:
				var land := Vector3(sin(k * 2.3), 0, cos(k * 2.3)) * r * 0.45
				var ray := land - _sun
				s.add(K.mesh("beam"), K.GLOW, GILT.merged({"mode": 16, "p1": 1.2, "p2": 0.4, "gain": 0.3, "life": (total - time * 0.4) * 1.1, "seed": float(k)}), _sun, Vector3(1.2, ray.length(), 1.2), K.falling(Vector3.ZERO, -ray, 1.0).basis.get_euler(), time * 0.4, total - time * 0.4 - 0.3, {"fin": 0.4, "fout": 0.4, "priority": -1})
			_feathers(s, S.n(10, 4), r * 0.7, 4.0, time * 0.3, 2.2, 1.0)
	var w := S.root(parent, caster.global_position, time + 0.1, "StarWindup_Hand_" + ID, centre, caster, time)
	if w:
		S.flash(w, w.to_local(S.hand(caster)), 1.5, GILT, 0.0, time + 0.1, 0.55, {"grow": time, "from": 0.2})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var last := index >= BEATS.size() - 1
	S.heal(parent, source, 3.8 + 0.5 * index, "StarContact_Heal_" + ID, HEAL)
	var s := K.open(parent, centre, 2.2, "StarContact_Wave_" + ID, source)
	if not s:
		return true
	# A wall of dawn light rolls out over the foes; a cross burns over each of them.
	s.add(K.mesh("column"), K.GLOW, DAWN.merged({"mode": 3, "p1": -2.5, "p2": 0.45, "gain": 0.3}), Vector3.ZERO, Vector3(r * 0.3, 1.3 + 0.2 * index, r * 0.3), Vector3.ZERO, 0.0, 0.75, {"to": Vector3(3.5, 0.75, 3.5), "fin": 0.02, "fout": 0.3})
	S.ring(s, Vector3.UP * 0.08, r * 1.15, GILT.merged({"p2": 1.0}), 0.0, 0.7, 0.42)
	for spot in S.foes(s, centre, r, [2, 3, 5][S.q()]):
		var at: Vector3 = s.to_local(spot)
		var delay := 0.25 * at.length() / r
		s.add(K.mesh("quad"), K.GLOW, GILT.merged({"mode": 6, "p1": 0.17, "p2": 7.0, "gain": 0.85}), at + Vector3.UP * 1.6, Vector3.ONE * 1.1, Vector3.ZERO, delay, 0.6, {"yaw_cam": true, "grow": 0.1, "from": 0.5, "fin": 0.01, "fout": 0.3, "priority": 2})
	if not last:
		S.motes(s, Vector3.ZERO, r * 0.8, S.n(10, 4), GILT, 0.26, 0.1, 0.4, 0.9, 1.2, 9, float(index))
		return true
	# The sun flares; a great column of dawn falls on the centre, a golden cross burns into
	# the ground and feathers rain over the field.
	S.flash(s, _sun, 5.0, SUN, 0.0, 0.5, 0.22)
	s.add(K.mesh("column"), K.VEIL, GILT.merged({"mode": 3, "p1": -5.0, "p2": 0.3, "gain": 0.75}), Vector3.ZERO, Vector3(1.2, 10.0, 1.2), Vector3.ZERO, 0.0, 1.2, {"to": Vector3(0.6, 1.0, 0.6), "fin": 0.02, "fout": 0.5})
	s.add(K.mesh("column"), K.GLOW, SUN.merged({"mode": 3, "p1": -8.0, "p2": 0.3, "gain": 0.4}), Vector3.ZERO, Vector3(0.5, 10.5, 0.5), Vector3.ZERO, 0.0, 0.9, {"to": Vector3(0.25, 1.0, 0.25), "fin": 0.02, "fout": 0.4})
	s.add(K.mesh("quad"), K.GLOW, GILT.merged({"mode": 6, "p1": 0.12, "p2": 6.0, "gain": 0.6}), Vector3.UP * 0.1, Vector3.ONE * r * 0.75, Vector3(-PI / 2, PI, 0), 0.0, 1.6, {"fin": 0.01, "fout": 0.7, "priority": 1})
	S.ring(s, Vector3.UP * 0.1, r * 1.35, SUN.merged({"p2": 1.0}), 0.05, 0.8, 0.45)
	S.sparks(s, Vector3.UP * 1.2, S.n(22, 8), GILT, 0.3, 0.0, 1.0, 10.0, 3.5, 10, 1.3, 5.0)
	if not S.lean():
		_feathers(s, S.n(24, 8), r * 0.9, 6.0, 0.0, 1.8, 7.0)
	return true
