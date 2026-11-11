extends RefCounted
## Archer 200-star "Celestial Hunt" (ล่าหมู่ดาว). Cosmetic only.
## The archer draws on the night sky: a constellation of the Hunter's Bow lights up star by
## star over the field while a star chart writes itself on the ground and a reticle locks
## on every foe inside it. Three times the archer looses into the sky and a volley of
## star arrows rains down out of the constellation, each arrow landing in a burst of
## starlight. Then the brightest star lets go of one great golden arrow onto the prey: a
## pillar of starlight, a four-point star blazing over it, the chart burning gold and
## stardust thrown over the field while the constellation fades.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "celestial_hunt"
const STAR := {"c_core": Color("fff0b0"), "c_mid": Color("8f9bff"), "c_edge": Color("3a3ad0")}
const NIGHT := {"c_core": Color("9aa6ff"), "c_mid": Color("5a6bff"), "c_edge": Color("2a2496")}
const GOLD := {"c_core": Color("ffe28a"), "c_mid": Color("ffc23a"), "c_edge": Color("c8701a")}
const ARROW := {"tint": Color("b8c0ff"), "ember": Color("ffe07a"), "glow": Color("9aa8ff"), "rim": 0.8, "shadow": Color("1f1e6e")}
const GREAT := {"tint": Color("ffe9a0"), "ember": Color("ffd257"), "glow": Color("aab4ff"), "rim": 0.9, "shadow": Color("4a2a8a")}
const BEATS := [0.0, 0.4, 0.8, 1.3]
const FLIGHT := 0.28
## The Hunter's Bow (constellation, in its own plane, metres): the bow's arc, the string,
## the arrow laid on it. Lines join these stars; star 9 (the arrow's head) is the brightest.
const STARS := [Vector3(-1.1, 1.5, 0), Vector3(-0.35, 1.05, 0), Vector3(0.05, 0.0, 0), Vector3(-0.35, -1.05, 0), Vector3(-1.1, -1.5, 0),
	Vector3(-1.45, 0.0, 0), Vector3(-2.2, 0.05, 0), Vector3(-0.8, 0.0, 0), Vector3(0.9, 0.0, 0), Vector3(1.75, 0.0, 0)]
const LINES := [[0, 1], [1, 2], [2, 3], [3, 4], [0, 5], [5, 4], [6, 5], [5, 7], [7, 2], [2, 8], [8, 9]]
## Where the constellation hangs (root space of the ground root, set by the wind-up).
static var _sky := Vector3(0, 5.0, 1.0)
static var _turn := Basis.IDENTITY
static var _lines: Mesh


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.3)), 4.0, 9.0)


static func lines() -> Mesh:
	if _lines == null:
		var b := K.Build.new()
		b.emit = 1.0
		for pair in LINES:
			b.tube([STARS[pair[0]], STARS[pair[1]]], [0.035, 0.035], 4, Color.WHITE, Color.WHITE)
		_lines = b.commit()
	return _lines


## The star [param k] of the constellation in the ground root's space.
static func _star(k: int) -> Vector3:
	return _sky + _turn * ((STARS[k] as Vector3) * 1.25)


## Which shot is leaving now (from the running cast's clock): 0..2 volleys, 3 the great arrow.
static func _shot(skill: Dictionary) -> int:
	var ref: WeakRef = GodSkillArt._casts.get(ID)
	var cast := ref.get_ref() as StarSkillSequence if ref else null
	if not is_instance_valid(cast):
		return 3
	var t := cast.clock - float(skill.get("hit_delay", 1.2))
	for k in 3:
		if t < (float(BEATS[k]) + float(BEATS[k + 1])) * 0.5:
			return k
	return 3


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var origin := caster.global_position
	var centre := Vector3(point.x, 0, point.z)
	var total := time + float(BEATS.back()) + FLIGHT + 0.9
	var g := S.root(parent, centre, total, "StarWindup_Chart_" + ID, origin, caster, time)
	if not g:
		return true
	# The constellation hangs low over the field, towards the camera, turned to face it.
	var up := clampf(GodSkillArt.headroom(g, g.global_position + g.global_basis * g.stage(0, 1.5, 0)) - 2.0, 3.6, 5.6)
	_sky = g.stage(0.0, 1.5, up)
	var yaw := S.face_camera(g)
	_turn = Basis.from_euler(Vector3(-0.35, yaw, 0))
	var fade := time + float(BEATS.back()) + FLIGHT + 0.35
	g.add(lines(), K.SOLID, {"tint": Color("aab4ff"), "ember": Color("9aa8ff"), "glow": Color("c8d0ff"), "rim": 0.3}, _sky, Vector3.ONE * 1.25, _turn.get_euler(), time * 0.25, fade - time * 0.25,
		{"grow": time * 0.5, "from": 0.6, "fin": time * 0.4, "fout": 0.4})
	var cards := []
	var data := []
	for k in STARS.size():
		cards.append(K.card(_sky + _turn * ((STARS[k] as Vector3) * 1.25), 0.85 if k == 9 else 0.5 + 0.12 * float(k % 3)))
		data.append(Color(time * 0.08 * float(k), K.rand(float(k)), 0, 0))
	g.swarm(K.mesh("quad"), K.GLOW, STAR.merged({"mode": 10, "billboard": true, "life": fade, "gain": 1.2}), cards, data, 0.0, fade, {"fin": 0.01, "fout": 0.4})
	S.flash(g, _sky, 6.5, NIGHT, 0.0, fade, 0.14, {"grow": time, "from": 0.3, "fin": time * 0.6, "fout": 0.5})
	# The star chart on the ground: rim, rings, glyphs and an eight-point star.
	g.add(K.mesh("quad"), K.GLOW, NIGHT.merged({"mode": 17, "p1": 8.0, "p2": 1.0 / maxf(time * 0.8 / total, 0.05), "gain": 0.5, "life": total}), Vector3.UP * 0.05, Vector3.ONE * r, K.FLAT, 0.0, total, {"spin": Vector3(0, 0, 0.12), "fin": 0.1, "fout": 0.4})
	g.add(K.mesh("quad"), K.GLOW, STAR.merged({"mode": 5, "p1": 30.0, "gain": 0.6}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, total, {"grow": 0.5, "from": 0.3, "fout": 0.4})
	# A reticle locks on every foe in the circle.
	var foes := S.foes(g, centre, r, [2, 4, 6][S.q()])
	for spot in foes:
		var at: Vector3 = g.to_local(spot) + Vector3.UP * 1.2
		g.add(K.mesh("reticle"), K.SOLID, ARROW.merged({"rim": 0.2, "ember": Color("ffd257")}), at, Vector3.ONE * 0.7, Vector3.ZERO, time * 0.35, fade - time * 0.35,
			{"scale_curve": [0.0, 2.0, time * 0.55, 1.0], "spin": Vector3(0, 0, 1.4), "yaw_cam": true, "fin": 0.1, "fout": 0.25, "priority": 2})
	# Starlight at the bow as the archer aims at the sky.
	var w := S.root(parent, origin, time + 0.2, "StarWindup_Bow_" + ID, origin - (centre - origin), caster, time)
	if w:
		S.flash(w, w.to_local(S.hand(caster)), 1.4, GOLD, time * 0.3, time * 0.7 + 0.15, 0.55, {"grow": time * 0.7, "from": 0.1})
	return true


## The volley of wave [param j]: star arrows out of the constellation onto the field.
static func _volley(r: K, j: int, radius: float, centre: Vector3) -> void:
	var count: int = [4, 6, 8][S.q()] + j * [0, 1, 1][S.q()]
	if MemoryGuard.pressure > 0:
		count = mini(count, 5)
	var arrows := []
	var data := []
	var bursts := []
	var burst_data := []
	var marks := []
	for k in count:
		var s := K.rand(float(k) * 3.9 + float(j) * 5.3)
		var spot := centre + K.scatter(k, count, radius * 0.75, float(j) * 1.3)
		var from := _star(k % STARS.size())
		var dir := (spot - from).normalized()
		var delay := 0.06 * K.rand(float(k) * 1.7 + float(j))
		arrows.append(K.falling(spot + dir * 0.25, dir, 1.1, s * TAU))
		data.append(Color(delay, s, (from - spot).length() / 12.0, 0))
		bursts.append(K.card(spot + Vector3.UP * 0.5, 1.1 + 0.4 * s))
		burst_data.append(Color(delay + FLIGHT, s, 0, 0))
		marks.append(K.lying(spot + Vector3.UP * (0.07 + 0.002 * k), 1.6 + 0.4 * s))
	r.swarm(K.mesh("light_arrow"), K.SOLID, ARROW.merged({"motion": 1, "flight": FLIGHT, "travel": 12.0, "hold": 0.45, "stick": 1.0}), arrows, data, 0.0, FLIGHT + 0.6, {"fin": 0.01, "fout": 0.08})
	r.swarm(K.mesh("quad"), K.GLOW, STAR.merged({"mode": 10, "billboard": true, "life": 0.45, "gain": 0.7}), bursts, burst_data, 0.0, FLIGHT + 0.6, {"fin": 0.01, "fout": 0.05})
	r.swarm(K.mesh("quad"), K.GLOW, NIGHT.merged({"mode": 1, "life": 0.5, "p1": 0.8, "gain": 0.7}), marks, burst_data, 0.0, FLIGHT + 0.65, {"fin": 0.01, "fout": 0.05})


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var parent := art.get_parent() as Node3D
	var shot := _shot(skill)
	var ref: WeakRef = GodSkillArt._casts.get(ID)
	var cast := ref.get_ref() as StarSkillSequence if ref else null
	var centre: Vector3 = cast.center if is_instance_valid(cast) else Vector3(point.x, 0, point.z)
	var origin := caster.global_position
	var r := _radius(skill)
	var v := K.open(parent, centre, 1.4, "StarLaunch_Volley_" + ID, origin)
	if not v:
		return true
	# The archer looses into the sky: a streak of starlight from the bow upward.
	var hand := v.to_local(S.hand(caster))
	v.add(K.mesh("beam"), K.GLOW, GOLD.merged({"mode": 16, "p1": 6.0, "p2": 0.6, "gain": 0.6, "life": 0.5}), hand, Vector3(0.35, 7.0, 0.35), Vector3.ZERO, 0.0, 0.5, {"fin": 0.01})
	S.flash(v, hand, 1.5, GOLD, 0.0, 0.25, 0.55)
	if shot < 3:
		_volley(v, shot, r, Vector3.ZERO)
		# The constellation answers: the stars the arrows come from flare.
		S.flash(v, _sky, 4.0 + float(shot), STAR, 0.0, 0.35, 0.25)
		return true
	# The great arrow: out of the brightest star, head first, onto the prey.
	var prey := v.to_local(point) * Vector3(1, 0, 1)
	var from := _star(9)
	var dir := (prey - from).normalized()
	var aim := K.falling(Vector3.ZERO, dir, 1.0).basis.get_euler()
	v.add(K.mesh("light_arrow"), K.SOLID, GREAT, from, Vector3.ONE * 3.2, aim, 0.0, flight + 0.06,
		{"travel": prey - from + dir * 0.2, "tw": Vector2(0, flight), "ease": 1, "fin": 0.01, "fout": 0.05, "priority": 3, "curves": {"heat": [0.0, 0.3, flight, 0.0]}})
	v.add(K.mesh("beam"), K.GLOW, GOLD.merged({"mode": 16, "p1": 8.0, "p2": 0.5, "gain": 0.6, "life": flight * 3.5}), from, Vector3(0.8, (prey - from).length(), 1.1), K.falling(Vector3.ZERO, -dir, 1.0).basis.get_euler(), 0.0, flight * 3.5, {"fin": 0.01})
	S.flash(v, from, 5.0, GOLD, 0.0, 0.45, 0.4)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var at := Vector3(point.x, 0, point.z)
	var r := _radius(skill)
	if index < 3:
		# Each volley lands: the chart pulses under it.
		var p := K.open(parent, at, 0.8, "StarContact_Volley_" + ID, source)
		if p:
			S.ring(p, Vector3.UP * 0.08, r * 1.15, NIGHT.merged({"p2": 1.0}), 0.0, 0.55, 0.55)
		return true
	var f := K.open(parent, at, 2.0, "StarContact_Great_" + ID, source)
	if not f:
		return true
	# The great arrow lands: a pillar of starlight, a four-point star blazing over the prey,
	# the chart burning gold, stardust thrown over the field.
	f.add(K.mesh("column"), K.GLOW, GOLD.merged({"mode": 3, "p1": -6.0, "p2": 0.35, "gain": 0.7}), Vector3.ZERO, Vector3(0.9, 8.0, 0.9), Vector3.ZERO, 0.0, 1.0, {"to": Vector3(0.4, 1.0, 0.4), "fin": 0.01, "fout": 0.45})
	f.add(K.mesh("quad"), K.GLOW, STAR.merged({"mode": 10, "billboard": true, "life": 0.9, "gain": 0.8}), Vector3.UP * 2.2, Vector3.ONE * 3.6, Vector3.ZERO, 0.0, 0.9, {"grow": 0.12, "from": 0.3, "fin": 0.01, "fout": 0.35})
	f.add(K.mesh("quad"), K.GLOW, GOLD.merged({"mode": 17, "p1": 4.0, "p2": 0.0, "gain": 0.6, "life": 1.6}), Vector3.UP * 0.09, Vector3.ONE * 3.4, K.FLAT, 0.0, 1.6, {"grow": 0.2, "from": 0.4, "spin": Vector3(0, 0, 1.2), "fin": 0.01, "fout": 0.6})
	S.ring(f, Vector3.UP * 0.1, r * 1.2, GOLD.merged({"p2": 1.0}), 0.0, 0.75, 0.55)
	S.sparks(f, Vector3.UP * 1.0, S.n(26, 8), STAR, 0.3, 0.0, 1.1, 11.0, 4.0, 10, 1.2, 4.0)
	if not S.lean():
		S.motes(f, Vector3.ZERO, r * 0.8, S.n(18, 6), STAR, 0.3, 0.2, 0.7, 1.2, 1.0, 10, 2.0)
		f.add(K.mesh("quad"), K.VEIL, {"mode": 7, "seed": 2.0, "life": 1.8, "c_core": Color("fff0b0"), "c_mid": Color("8f9bff"), "c_edge": Color("15124a")}, Vector3.UP * 0.05, Vector3.ONE * 2.6, K.FLAT, 0.0, 1.8, {"fin": 0.01, "priority": -1})
	return true
