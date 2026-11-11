extends RefCounted
## Mage 100-star "Crystal Prison" (คุกผลึกเหมันต์). Cosmetic only.
## Frost creeps out over the ground from the target, cracking as it spreads, while little
## ice crystals sprout in it and cold motes hang low. On the first contact the prison
## closes: a ring of tall ice pillars bursts out of the ground round the circle, crystals
## grow up behind every foe and a frozen sigil turns under them. On the second they
## shatter: a shock of cold rolls out, ice glints are thrown high and snow drifts down
## over the thawing frost.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "crystal_prison"
const ICE := {"c_core": Color("8fdcff"), "c_mid": Color("2fb8ff"), "c_edge": Color("1a4ad0")}
const FROST := {"c_core": Color("c8f2ff"), "c_mid": Color("6fc8ff"), "c_edge": Color("9fd8ff")}
const CRYSTAL := {"glow": Color("c8f4ff"), "rim": 0.85, "shadow": Color("1f4ab0"), "tint": Color("bfeaff")}
## The prison stands from the first contact to the second (StarSkillSequence beats).
const HOLD := 0.85


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 7.1)), 3.0, 8.0)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var total := time + HOLD + 1.2
	var g := S.root(parent, centre, total, "StarWindup_Frost_" + ID, caster.global_position, caster, time)
	if not g:
		return true
	# Frost creeps out and cracks; it thaws away after the shatter.
	g.add(K.mesh("quad"), K.VEIL, FROST.merged({"mode": 7, "seed": 3.0, "life": total * 1.3, "gain": 0.6}), Vector3.UP * 0.04, Vector3.ONE * r * 1.05, K.FLAT, 0.0, total,
		{"grow": time * 1.1, "from": 0.15, "fin": 0.1, "fout": 0.6, "priority": -2})
	g.add(K.mesh("quad"), K.GLOW, ICE.merged({"mode": 5, "p1": 26.0, "gain": 0.75}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, time + HOLD + 0.1, {"grow": time, "from": 0.2, "fout": 0.15})
	# Little crystals sprout in the frost as it spreads.
	var sprouts := []
	var data := []
	var count := S.n(10, 4)
	for k in count:
		var s := K.rand(float(k) * 2.9)
		var spot := K.scatter(k, count, r * 0.9, 1.0)
		sprouts.append(K.standing(spot, Vector3.ONE * (0.35 + 0.25 * s), s * TAU))
		data.append(Color(time * 0.9 * spot.length() / r, s, 0, 0))
	g.swarm(K.mesh("ice"), K.SOLID, CRYSTAL.merged({"motion": 2, "hold": time + HOLD}), sprouts, data, 0.0, time + HOLD + 0.4, {"fin": 0.01, "fout": 0.05})
	if not S.lean():
		S.motes(g, Vector3.ZERO, r * 0.8, S.n(14, 5), ICE, 0.3, 0.0, time, 1.3, 0.25, 9, 2.0)
		var w := S.root(parent, caster.global_position, time + 0.1, "StarWindup_Cold_" + ID, centre, caster, time)
		if w:
			S.flash(w, w.to_local(S.hand(caster)), 1.3, ICE, 0.0, time + 0.1, 0.55, {"grow": time, "from": 0.2})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	if index == 0:
		var p := K.open(parent, centre, HOLD + 0.5, "StarContact_Prison_" + ID, source)
		if not p:
			return true
		# The prison closes: a ring of ice pillars, crystals behind every foe, a frozen sigil.
		var pillars := []
		var data := []
		var count: int = [6, 9, 12][S.q()]
		for k in count:
			var a := TAU * float(k) / float(count)
			var s := K.rand(float(k) * 1.7)
			pillars.append(K.standing(Vector3(sin(a), 0, cos(a)) * r * 0.92, Vector3(0.9, 1.5 + 0.6 * s, 0.9), a + s))
			data.append(Color(0.02 * float(k % 4), s, 0, 0))
		var camera := p.toward_camera()
		for spot in S.foes(p, centre, r, [2, 4, 5][S.q()]):
			var behind: Vector3 = p.to_local(spot) - camera * 0.75
			pillars.append(K.standing(behind, Vector3(0.8, 1.2, 0.8), K.rand(spot.x)))
			data.append(Color(0.05, K.rand(spot.z), 0, 0))
		p.swarm(K.mesh("ice"), K.SOLID, CRYSTAL.merged({"motion": 2, "hold": HOLD - 0.05}), pillars, data, 0.0, HOLD + 0.4, {"fin": 0.01, "fout": 0.02})
		p.add(K.mesh("quad"), K.GLOW, ICE.merged({"mode": 17, "p1": 6.0, "p2": 0.0, "gain": 0.6, "life": HOLD + 0.1}), Vector3.UP * 0.07, Vector3.ONE * r * 0.85, K.FLAT, 0.0, HOLD + 0.1, {"grow": 0.2, "from": 0.5, "spin": Vector3(0, 0, 0.35), "fin": 0.02, "fout": 0.08})
		S.ring(p, Vector3.UP * 0.1, r * 1.1, ICE.merged({"p2": 1.0}), 0.0, 0.55, 0.5)
		S.sparks(p, Vector3.UP * 0.3, S.n(14, 5), FROST, 0.22, 0.0, 0.6, 6.0, 4.0, 10, 1.6, 1.0)
		return true
	# The shatter: a shock of cold, glints thrown high, snow drifting down.
	var f := K.open(parent, centre, 2.0, "StarContact_Shatter_" + ID, source)
	if not f:
		return true
	S.ring(f, Vector3.UP * 0.1, r * 1.3, ICE.merged({"p2": 1.0}), 0.0, 0.7, 0.4)
	S.ring(f, Vector3.UP * 1.2, r * 0.8, FROST, 0.05, 0.45, 0.3, Vector3.ZERO, {"yaw_cam": true})
	S.flash(f, Vector3.UP * 1.2, r * 0.7, ICE, 0.0, 0.3, 0.22)
	var glints := []
	var data := []
	var count: int = [12, 22, 32][S.q()]
	for k in count:
		var s := K.rand(float(k) * 3.3 + 1.0)
		var a := float(k) * K.GOLDEN
		var at := Vector3(sin(a), 0, cos(a)) * r * (0.35 + 0.6 * K.rand(s * 4.0))
		var out := (Vector3(sin(a), 1.4 + s, cos(a))).normalized()
		glints.append(K.card(at + Vector3.UP * (0.5 + s), 0.25 + 0.2 * s, out))
		data.append(Color(s * 0.06, s, 0, 0))
	f.swarm(K.mesh("quad"), K.GLOW, ICE.merged({"mode": 10, "billboard": true, "life": 0.95, "burst": 7.0, "gravity": 6.0, "grow": Vector2(1.0, 0.5)}), glints, data, 0.0, 1.1, {"fin": 0.01})
	if not S.lean():
		S.motes(f, Vector3.UP * 2.5, r * 0.85, S.n(18, 6), FROST, 0.22, 0.2, 0.6, 1.4, -1.2, 9, 4.0)
	return true
