extends RefCounted
## Priest 150-star "Sacred Sanctuary" (วิหารศักดิ์สิทธิ์). Cosmetic only.
## A holy sigil writes itself round the priest while slender pillars of light rise on its
## rim. The consecration: a dome of mint glass rises over the circle and melts away, a
## column of light stands at its heart and a ring of light rolls to the rim. For the ten
## seconds the sanctuary stands, its sigil glows and turns on the ground between its
## pillars, and every two seconds (each healing contact) it breathes: a soft ring runs
## out to the rim, the pillars flare and healing motes rise all over it. On the last
## breath the pillars climb into the sky and the sigil fades.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "sacred_sanctuary"
## Two seconds between the healing contacts (StarSkillSequence beats).
const PULSE := 2.0
const LAST := 4
const JADE := {"c_core": Color("7ff0c4"), "c_mid": Color("2fe0a0"), "c_edge": Color("1a8a7a")}
const MINT := {"c_core": Color("dcffe8"), "c_mid": Color("7ff0bf"), "c_edge": Color("2fb08a")}
const GILT := {"c_core": Color("c8ffd8"), "c_mid": Color("6fe8b0"), "c_edge": Color("2fa88a")}
const HEAL := {"c_core": Color("e6ffd0"), "c_mid": Color("6fe890"), "c_edge": Color("c8d860")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 8.0)), 3.0, 8.0)


static func _pillars(r: K, radius: float, start: float, seconds: float, height: float, gain: float, salt: float) -> void:
	var count: int = [3, 4, 6][S.q()]
	var cols := []
	var data := []
	for k in count:
		var a := TAU * float(k) / float(count) + 0.3
		cols.append(K.standing(Vector3(sin(a), 0, cos(a)) * radius * 0.94, Vector3(0.32, height, 0.32), a))
		data.append(Color(0.04 * float(k), K.rand(float(k) + salt), 0, 0))
	r.swarm(K.mesh("column"), K.GLOW, GILT.merged({"mode": 3, "p1": -3.0, "p2": 0.4, "gain": gain, "life": seconds}), cols, data, start, seconds + 0.3, {"fin": 0.15, "fout": 0.3})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var feet := caster.global_position * Vector3(1, 0, 1)
	var w := S.root(parent, feet, time + 0.25, "StarWindup_Sigil_" + ID, feet + Vector3.BACK, caster, time)
	if not w:
		return true
	w.add(K.mesh("quad"), K.GLOW, JADE.merged({"mode": 17, "p1": 6.0, "p2": 1.0 / maxf(time * 0.9 / (time + 0.25), 0.05), "gain": 0.7, "life": time + 0.25}), Vector3.UP * 0.05, Vector3.ONE * r, K.FLAT, 0.0, time + 0.25, {"grow": time * 0.5, "from": 0.4, "spin": Vector3(0, 0, 0.3), "fin": 0.05, "fout": 0.12})
	w.add(K.mesh("quad"), K.GLOW, JADE.merged({"mode": 5, "p1": 36.0, "gain": 0.6}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, time * 0.3, time * 0.7 + 0.25, {"grow": time * 0.6, "from": 0.3, "fout": 0.12})
	_pillars(w, r, time * 0.35, time * 0.65 + 0.3, 3.0, 0.55, 1.0)
	S.flash(w, w.to_local(S.hand(caster)), 1.3, MINT, 0.0, time + 0.1, 0.5, {"grow": time, "from": 0.2})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var r := _radius(skill)
	var centre := Vector3(point.x, 0, point.z)
	var last := index >= LAST
	# This breath's stretch of the sanctuary: until the next breath, crossfading into it.
	var span := 1.3 if last else PULSE + 0.25
	var z := K.open(parent, centre, span, "StarContact_Sanctum_" + ID, centre + Vector3.BACK)
	if not z:
		return true
	var first := index == 0
	z.add(K.mesh("quad"), K.GLOW, JADE.merged({"mode": 17, "p1": 6.0, "p2": 0.0, "gain": 0.27, "life": span + 4.0}), Vector3.UP * 0.05, Vector3.ONE * r, K.FLAT, 0.0, span,
		{"spin": Vector3(0, 0, 0.3), "fin": 0.05 if first else 0.25, "fout": 1.0 if last else 0.25})
	z.add(K.mesh("quad"), K.GLOW, JADE.merged({"mode": 5, "p1": 36.0, "gain": 0.36}), Vector3.UP * 0.06, Vector3.ONE * r, K.FLAT, 0.0, span, {"fin": 0.05 if first else 0.25, "fout": 1.0 if last else 0.25})
	_pillars(z, r, 0.0, span - 0.3, 6.5 if last else 3.2, 0.7 if not last else 0.6, float(index))
	# The breath: a ring to the rim and healing motes rising all over the sanctuary.
	S.ring(z, Vector3.UP * 0.08, r * 1.02, MINT.merged({"p2": 1.0}), 0.0, 0.9, 0.4)
	S.motes(z, Vector3.ZERO, r * 0.85, S.n(14, 5), HEAL, 0.32, 0.0, 0.6, 1.0, 1.4, 12, float(index))
	if first:
		# The consecration: a dome of mint glass that rises and melts, a column at the heart.
		z.add(K.mesh("sphere"), K.GLOW, MINT.merged({"mode": 15, "p1": 2.4, "gain": 0.45}), Vector3.ZERO, Vector3(r * 0.92, r * 0.42, r * 0.92), Vector3.ZERO, 0.0, 1.0,
			{"grow": 0.35, "from": 0.3, "spin": Vector3(0, 0.5, 0), "fin": 0.02, "fout": 0.6})
		z.add(K.mesh("column"), K.GLOW, GILT.merged({"mode": 3, "p1": -5.0, "p2": 0.35, "gain": 0.75}), Vector3.ZERO, Vector3(0.9, 8.0, 0.9), Vector3.ZERO, 0.0, 0.9, {"to": Vector3(0.35, 1.0, 0.35), "fin": 0.01, "fout": 0.4})
		S.ring(z, Vector3.UP * 0.1, r * 1.2, JADE.merged({"p2": 1.0}), 0.0, 0.7, 0.6)
	elif not S.lean():
		S.flash(z, Vector3.UP * 0.6, r * 0.6, MINT, 0.0, 0.5, 0.12)
	return true
