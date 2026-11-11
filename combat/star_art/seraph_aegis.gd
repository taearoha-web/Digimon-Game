extends RefCounted
## Priest 100-star "Seraph's Aegis" (ปีกพิทักษ์เซราฟ). Cosmetic only.
## Rose-gold feathers drift down round the priest as a halo kindles overhead and three
## pairs of seraph wings unfold behind the shoulders. As the ward lands the wings sweep
## open and beat once, a bubble of rose glass (a fresnel rim and a honeycomb of light
## running up it) swells round the priest and the party, a ring of rose light rolls out
## and feathers burst; the bubble then settles in close to the priest and fades into the
## shield, the wings folding away.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "seraph_aegis"
const ROSE := {"c_core": Color("ffa8da"), "c_mid": Color("ff7ac8"), "c_edge": Color("a03a9a")}
const GOLD := {"c_core": Color("ffe2b0"), "c_mid": Color("ffb86a"), "c_edge": Color("c06a4a")}
const WINGS := {"tint": Color("ffd0ec"), "ember": Color("ffb0dc"), "glow": Color("fff0f8"), "rim": 0.8, "shadow": Color("6a3a8a")}
const PLUME := {"motion": 3, "tint": Color("ffd8ee"), "ember": Color("ffc0e0"), "glow": Color("fff4fa"), "rim": 0.5, "shadow": Color("8a4a9a")}
static var _wings: Mesh


## Three pairs of seraph wings from the shoulders (they fold and beat in god_solid).
static func wings() -> Mesh:
	if _wings == null:
		var b := K.Build.new()
		for side in [-1.0, 1.0]:
			K._wing(b, side, 1, Vector3(side * 0.16, 1.75, 0), 46.0, 1.9, Color("ffb0dc"))
			K._wing(b, side, 2, Vector3(side * 0.16, 1.6, 0), 8.0, 2.2, Color("ffd2a0"))
			K._wing(b, side, 3, Vector3(side * 0.16, 1.4, 0), -32.0, 1.6, Color("ff9ad0"))
		_wings = b.commit()
	return _wings


static func _feathers(r: K, count: int, radius: float, height: float, start: float, hold: float, salt: float) -> void:
	var plumes := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 2.9 + salt)
		plumes.append(K.standing(K.scatter(k, count, radius, salt) + Vector3.UP * (height * (0.5 + 0.5 * s)), Vector3.ONE * (0.8 + 0.5 * s), s * TAU))
		data.append(Color(s * 0.4, s, 0, 0))
	r.swarm(K.mesh("feather"), K.SOLID, PLUME.merged({"hold": hold, "drift": Vector3(0.1, -height * 0.45 / hold, 0), "sway": 0.5, "tumble": 2.4}), plumes, data, start, hold + 0.45, {"fin": 0.01, "fout": 0.05})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var feet := caster.global_position * Vector3(1, 0, 1)
	# One root carries the wind-up and the wings through the ward (they fold at its end).
	var total := time + 1.5
	var w := S.root(parent, feet, total, "StarWindup_Seraph_" + ID, feet + Vector3.BACK, caster, time)
	if not w:
		return true
	var back := w.stage(0.0, -0.3, 0.0)
	w.add(wings(), K.SOLID, WINGS, back, Vector3.ONE * 1.0, Vector3.ZERO, 0.0, total,
		{"yaw_cam": true, "priority": 2, "fin": 0.15, "fout": 0.4,
		"curves": {"spread": [0.0, 0.0, time * 0.9, 0.55, time + 0.12, 1.0, time + 0.8, 0.9, total - 0.2, 0.0], "flap": [0.0, 0.05, time, 0.06, time + 0.1, 0.25, time + 0.6, 0.06], "heat": [time - 0.05, 0.0, time + 0.04, 0.3, time + 0.35, 0.0]}})
	w.add(K.mesh("quad"), K.GLOW, GOLD.merged({"mode": 5, "p1": 1.0, "gain": 1.1}), Vector3.UP * 2.35, Vector3.ONE * 0.42, K.FLAT, time * 0.2, total - time * 0.2, {"grow": time * 0.6, "from": 0.2, "fin": 0.1, "fout": 0.4})
	S.flash(w, Vector3.UP * 2.35, 1.4, GOLD, time * 0.2, total - time * 0.2, 0.3, {"fout": 0.4})
	w.add(K.mesh("quad"), K.GLOW, ROSE.merged({"mode": 17, "p1": 6.0, "p2": 1.0 / maxf(time * 0.9 / total, 0.05), "gain": 0.6, "life": total}), Vector3.UP * 0.05, Vector3.ONE * 2.4, K.FLAT, 0.0, total, {"spin": Vector3(0, 0, 0.4), "fin": 0.05, "fout": 0.4})
	if not S.lean():
		_feathers(w, S.n(8, 3), 1.5, 3.2, 0.0, time + 0.4, 1.0)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var feet := Vector3(source.x, 0, source.z)
	var s := K.open(parent, feet, 1.7, "StarContact_Ward_" + ID, feet + Vector3.BACK)
	if not s:
		return true
	# The bubble of rose glass swells round the party, then settles in on the priest.
	var size := clampf(float(skill.get("radius", 7.1)) * 0.38, 2.0, 3.0)
	s.add(K.mesh("sphere"), K.GLOW, ROSE.merged({"mode": 15, "p1": 2.2, "gain": 0.55}), Vector3.ZERO, Vector3.ONE * size, Vector3.ZERO, 0.0, 1.45,
		{"scale_curve": [0.0, 0.25, 0.18, 1.05, 0.3, 1.0, 0.85, 1.0, 1.35, 0.42], "spin": Vector3(0, 0.8, 0), "fin": 0.02, "fout": 0.4})
	S.ring(s, Vector3.UP * 0.08, size * 2.6, ROSE.merged({"p2": 1.0}), 0.0, 0.6, 0.45)
	S.ring(s, Vector3.UP * 0.1, size * 1.6, GOLD, 0.06, 0.5, 0.45)
	S.flash(s, Vector3.UP * 1.2, 2.6, ROSE, 0.0, 0.3, 0.35)
	S.sparks(s, Vector3.UP * 1.3, S.n(14, 5), GOLD, 0.24, 0.0, 0.8, 7.0, 2.5, 10, 1.3, 3.0)
	if not S.lean():
		_feathers(s, S.n(12, 4), size * 0.9, 2.6, 0.0, 1.1, 4.0)
		S.motes(s, Vector3.ZERO, size * 0.8, S.n(10, 4), ROSE, 0.24, 0.3, 0.6, 1.0, 1.3, 9, 2.0)
	return true
