extends RefCounted
## Mage 200-star "Genesis Nova" (โนวากำเนิดธาตุ). Cosmetic only.
## A great rune circle writes itself over the field while four elemental worlds (fire,
## ice, lightning, arcane) wheel above it on one orbit, spiralling in until they fuse into
## a rose-gold core of power. The core then breathes out four waves, one element each: a
## shock ring of its colour and its element bursting out of the ground round the circle
## (flames, ice, lightning, crystals). The last wave is the genesis: the core swells into a
## burning shell and bursts, a prismatic ring rolls past the rim, a pillar of light falls
## through the centre and stardust drifts down.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "genesis_nova"
const BEATS := [0.0, 0.4, 0.8, 1.3]
const NOVA := {"c_core": Color("ffc8e6"), "c_mid": Color("ff4fb0"), "c_edge": Color("8a1a8a")}
const CORE := {"c_core": Color("ffd8a8"), "c_mid": Color("ff6ab8"), "c_edge": Color("b0207a")}
const RUNE := {"c_core": Color("ffd0ea"), "c_mid": Color("e04aa8"), "c_edge": Color("6a1a7a")}
## Fire, ice, lightning, arcane.
const ELEMENTS := [
	{"c_core": Color("ffe08a"), "c_mid": Color("ff8a1a"), "c_edge": Color("e2300a"), "ball": Color("ff7a1a")},
	{"c_core": Color("c8f4ff"), "c_mid": Color("5fc8ff"), "c_edge": Color("2f6cff"), "ball": Color("6fd4ff")},
	{"c_core": Color("fff4a0"), "c_mid": Color("ffe04a"), "c_edge": Color("ff9a1a"), "ball": Color("ffe94a")},
	{"c_core": Color("f2c8ff"), "c_mid": Color("c44dff"), "c_edge": Color("6a1ad0"), "ball": Color("c44dff")},
]
## Where the core burns (root space of the field roots), set by the wind-up.
static var _core := Vector3(0, 3.0, 1.0)
static var _worlds: Mesh


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.3)), 4.0, 9.0)


static func _glow(e: Dictionary) -> Dictionary:
	return {"c_core": e.c_core, "c_mid": e.c_mid, "c_edge": e.c_edge}


## The four elemental worlds on one ring of light (radius 1, XZ plane), in their colours.
static func worlds() -> Mesh:
	if _worlds == null:
		var b := K.Build.new()
		var path := []
		var radii := []
		for k in 41:
			var a := TAU * float(k) / 40.0
			path.append(Vector3(cos(a), 0, sin(a)))
			radii.append(0.02)
		b.emit = 1.0
		b.tube(path, radii, 4, Color("ffc8e6"), Color("ffc8e6"))
		for k in 4:
			var a := TAU * float(k) / 4.0
			var c: Color = ELEMENTS[k].ball
			b.emit = 0.85
			b.ball(Vector3(cos(a), 0, sin(a)), Vector3.ONE * 0.24, c.lerp(Color.WHITE, 0.35), c, 10, 6)
		_worlds = b.commit()
	return _worlds


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var total := time + float(BEATS.back()) + 1.2
	var finale := time + float(BEATS.back())
	var g := S.root(parent, centre, total, "StarWindup_Genesis_" + ID, caster.global_position, caster, time)
	if not g:
		return true
	var up := clampf(GodSkillArt.headroom(g, g.global_position) - 1.6, 2.6, 3.6)
	_core = g.stage(0.0, 1.0, up)
	# The great rune circle and the rim.
	g.add(K.mesh("quad"), K.GLOW, RUNE.merged({"mode": 17, "p1": 7.0, "p2": 1.0 / maxf(time * 0.85 / total, 0.05), "gain": 0.45, "life": total}), Vector3.UP * 0.05, Vector3.ONE * r, K.FLAT, 0.0, total, {"spin": Vector3(0, 0, 0.25), "fin": 0.1, "fout": 0.45})
	g.add(K.mesh("quad"), K.GLOW, NOVA.merged({"mode": 5, "p1": 32.0, "gain": 0.7}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, total - 0.2, {"grow": 0.5, "from": 0.3, "fout": 0.4})
	# The four worlds spiral in and fuse.
	g.add(worlds(), K.SOLID, {"glow": Color("ffd8f0"), "rim": 0.6, "shadow": Color("3a1050")}, _core, Vector3.ONE * 3.0, Vector3(0.35, 0, 0.1), 0.0, time + 0.05,
		{"spin": Vector3(0, 3.2, 0), "scale_curve": [0.0, 0.2, time * 0.25, 1.0, time * 0.7, 0.75, time, 0.05], "fin": 0.1, "fout": 0.06, "priority": 2})
	# The core of power: born as the worlds fuse, breathing on every wave, bursting at the end.
	var pulse := [0.0, 0.05, time - 0.1, 0.05, time + 0.05, 1.15, time + 0.2, 0.85]
	for k in range(1, BEATS.size() - 1):
		var at := time + float(BEATS[k])
		pulse.append_array([at - 0.12, 0.8 + 0.06 * k, at, 1.1 + 0.08 * k, at + 0.15, 0.85 + 0.06 * k])
	pulse.append_array([finale - 0.15, 0.9, finale + 0.05, 1.4, finale + 0.35, 1.5])
	g.add(K.mesh("sphere"), K.SUN, CORE.merged({"flow": 2.5}), _core, Vector3.ONE * 0.62, Vector3.ZERO, 0.0, finale + 0.45, {"scale_curve": pulse, "fin": 0.05, "fout": 0.38})
	g.add(K.mesh("quad"), K.GLOW, CORE.merged({"mode": 2, "billboard": true, "p1": 8.0, "p2": 0.24, "gain": 0.55}), _core, Vector3.ONE * 0.75 * 4.2, Vector3.ZERO, 0.0, finale + 0.45, {"scale_curve": pulse, "fin": 0.05, "fout": 0.35, "priority": -1})
	if not S.lean():
		var pulls := []
		var data := []
		var count := S.n(16, 6)
		for k in count:
			var s := K.rand(float(k) * 2.3 + 7.0)
			var a := float(k) * K.GOLDEN
			pulls.append(K.falling(_core, -Vector3(cos(a), 0.6 * s - 0.4, sin(a)).normalized(), 0.6 + 0.3 * s))
			data.append(Color(s * time * 0.7, s, 0.3, 0))
		g.swarm(K.mesh("shard"), K.SOLID, {"motion": 1, "flight": 0.4, "travel": 12.0, "accelerate": 1.0, "stick": 0.0, "ember": Color("ffb8e0"), "rim": 0.0}, pulls, data, 0.0, time)
	var w := S.root(parent, caster.global_position, time + 0.1, "StarWindup_Hand_" + ID, centre, caster, time)
	if w:
		S.flash(w, w.to_local(S.hand(caster)), 1.5, NOVA, 0.0, time + 0.1, 0.6, {"grow": time, "from": 0.2})
	return true


## What the element of wave [param k] does round the circle.
static func _element(s: K, k: int, r: float) -> void:
	var e: Dictionary = ELEMENTS[k]
	var count: int = [4, 6, 8][S.q()]
	var spots := []
	var data := []
	for j in count:
		var a := TAU * float(j) / float(count) + 0.4 * float(k)
		var d := r * (0.45 + 0.35 * K.rand(float(j) * 1.3 + float(k)))
		spots.append(Vector3(sin(a), 0, cos(a)) * d)
		data.append(Color(0.08 * d / r, K.rand(float(j) + float(k) * 3.0), 0, 0))
	var stands := []
	for spot in spots:
		stands.append(K.standing(spot, Vector3.ONE * (1.0 + 0.3 * K.rand(spot.x)), spot.z))
	match k:
		0:
			var cards := []
			for spot in spots:
				cards.append(K.card(spot + Vector3.UP * 0.8, 1.6))
			s.swarm(K.mesh("quad"), K.VEIL, _glow(e).merged({"mode": 8, "billboard": true, "life": 0.6, "grow": Vector2(0.5, 1.4), "drift": Vector3(0, 1.6, 0)}), cards, data, 0.0, 0.8, {"fin": 0.01, "priority": 1})
		1:
			s.swarm(K.mesh("ice"), K.SOLID, {"motion": 2, "hold": 0.45, "glow": Color("c8f4ff"), "rim": 0.8, "shadow": Color("2a5ac8")}, stands, data, 0.0, 0.85, {"fin": 0.01})
		2:
			var bolts := []
			for spot in spots:
				bolts.append(K.standing(spot, Vector3(0.9, 0.7, 0.9), spot.x))
			s.swarm(K.mesh("bolt"), K.GLOW, _glow(e).merged({"mode": 13, "life": 0.4}), bolts, data, 0.0, 0.5, {"fin": 0.01, "priority": 1})
		3:
			s.swarm(K.mesh("crystal"), K.SOLID, {"motion": 2, "hold": 0.5, "glow": Color("f0b0ff"), "rim": 0.8, "shadow": Color("2a0a6a")}, stands, data, 0.0, 0.9, {"fin": 0.01})


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var k := clampi(index, 0, 3)
	var e: Dictionary = ELEMENTS[k]
	var s := K.open(parent, centre, 2.4, "StarContact_Wave_" + ID, source)
	if not s:
		return true
	S.ring(s, Vector3.UP * 0.1, r * (0.85 + 0.12 * k), _glow(e).merged({"p2": 1.0}), 0.0, 0.55, 0.7)
	S.flash(s, _core, 2.6, _glow(e), 0.0, 0.25, 0.45)
	_element(s, k, r)
	if index < BEATS.size() - 1:
		return true
	# Genesis: the core bursts as a shell, a prismatic ring rolls past the rim, a pillar of
	# light falls through the centre and stardust drifts down.
	s.add(K.mesh("sphere"), K.SUN, CORE.merged({"flow": 5.0}), _core, Vector3.ONE * 1.2, Vector3.ZERO, 0.0, 0.32, {"grow": 0.2, "from": 0.6, "fin": 0.01, "fout": 0.3})
	s.add(K.mesh("quad"), K.GLOW, NOVA.merged({"mode": 1, "p1": 0.8, "p2": 1.0, "prism": 0.6, "gain": 0.35}), Vector3.UP * 0.12, Vector3.ONE * r * 1.35, K.FLAT, 0.05, 0.85, {"fin": 0.01})
	s.add(K.mesh("column"), K.GLOW, NOVA.merged({"mode": 3, "p1": -6.0, "p2": 0.35, "gain": 0.45}), Vector3.ZERO, Vector3(1.0, 8.0, 1.0), Vector3.ZERO, 0.05, 0.9, {"to": Vector3(0.35, 1.0, 0.35), "fin": 0.01, "fout": 0.4})
	s.add(K.mesh("quad"), K.GLOW, CORE.merged({"mode": 17, "p1": 7.0, "p2": 0.0, "gain": 0.3, "life": 1.4}), Vector3.UP * 0.08, Vector3.ONE * r * 0.7, K.FLAT, 0.0, 1.4, {"grow": 0.3, "from": 0.6, "spin": Vector3(0, 0, -0.8), "fin": 0.01, "fout": 0.6})
	S.sparks(s, _core, S.n(26, 8), CORE, 0.3, 0.0, 1.1, 12.0, 4.0, 10, 1.0, 6.0)
	if not S.lean():
		var dust := []
		var data := []
		var count: int = [12, 24, 36][S.q()]
		for j in count:
			var sd := K.rand(float(j) * 2.9 + 5.0)
			dust.append(K.card(K.scatter(j, count, r * 0.95) + Vector3.UP * (2.0 + sd * 3.0), 0.28 + 0.3 * sd))
			data.append(Color(0.2 + sd * 0.6, sd, 0, 0))
		s.swarm(K.mesh("quad"), K.GLOW, NOVA.merged({"mode": 10, "billboard": true, "life": 1.5, "prism": 0.8, "drift": Vector3(0, -1.4, 0), "sway": 0.35}), dust, data, 0.0, 2.3, {"fin": 0.01})
	return true
