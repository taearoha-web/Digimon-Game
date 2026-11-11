extends RefCounted
## Archer 150-star "Sylph Step" (ก้าวแห่งภูตลม). Cosmetic only.
## The wind spirit answers: ribbons of turquoise wind wind up round the archer, a wind
## sigil writes itself on the ground and feathers are caught up in the gust. As the
## blessing lands, a pair of glassy sylph wings flares open behind the archer, a whirlwind
## shoots up and a ring of wind rolls out over the field throwing feathers and motes;
## the wind keeps circling the archer for a moment before it settles.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "sylph_step"
const WIND := {"c_core": Color("b6fff0"), "c_mid": Color("3ff0d0"), "c_edge": Color("138a8a")}
const GALE := {"c_core": Color("d8fff4"), "c_mid": Color("7af7d8"), "c_edge": Color("1fa8a0")}
const PLUME := {"motion": 3, "tint": Color("b8fff0"), "ember": Color("6ff5dc"), "glow": Color("e4fffa"), "rim": 0.5, "shadow": Color("177a8a")}
const WINGS := {"tint": Color("9ff8e6"), "ember": Color("52efd2"), "glow": Color("e6fffb"), "rim": 0.8, "shadow": Color("177a8a")}
static var _wings: Mesh


## Two pairs of light sylph wings from the shoulders (GodRangedKit wings: they fold and beat
## in god_solid), feet at the origin, facing +Z.
static func wings() -> Mesh:
	if _wings == null:
		var b := K.Build.new()
		for side in [-1.0, 1.0]:
			K._wing(b, side, 1, Vector3(side * 0.16, 1.55, 0), 38.0, 1.9, Color("7af7d8"))
			K._wing(b, side, 2, Vector3(side * 0.16, 1.4, 0), -18.0, 1.4, Color("b6fff0"))
		_wings = b.commit()
	return _wings


static func _feathers(r: K, count: int, radius: float, start: float, hold: float, rise: float, salt: float) -> void:
	var plumes := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 3.3 + salt)
		plumes.append(K.standing(K.scatter(k, count, radius, salt) + Vector3.UP * (0.2 + 1.4 * s), Vector3.ONE * (0.7 + 0.5 * s), s * TAU))
		data.append(Color(s * 0.3, s, 0, 0))
	r.swarm(K.mesh("feather"), K.SOLID, PLUME.merged({"hold": hold, "drift": Vector3(0, rise, 0), "sway": 0.9, "tumble": 3.5}), plumes, data, start, hold + 0.35, {"fin": 0.01, "fout": 0.05})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var feet := caster.global_position * Vector3(1, 0, 1)
	var w := S.root(parent, feet, time + 0.25, "StarWindup_Gust_" + ID, feet + Vector3.BACK, caster, time)
	if not w:
		return true
	w.add(K.mesh("quad"), K.GLOW, WIND.merged({"mode": 17, "p1": 5.0, "p2": 1.6, "gain": 0.75, "life": time + 0.25}), Vector3.UP * 0.05, Vector3.ONE * 2.6, K.FLAT, 0.0, time + 0.25, {"spin": Vector3(0, 0, 0.8), "fin": 0.05, "fout": 0.1})
	w.add(K.mesh("helix"), K.GLOW, WIND.merged({"mode": 16, "p1": 3.0, "p2": 0.7, "gain": 0.6, "life": time * 1.6}), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), Vector3.ZERO, 0.0, time + 0.15, {"spin": Vector3(0, 4.5, 0), "grow": time, "from": 0.5, "fin": 0.05, "fout": 0.1})
	if not S.lean():
		w.add(K.mesh("helix"), K.GLOW, GALE.merged({"mode": 16, "p1": 4.0, "p2": 0.9, "gain": 0.45, "life": time * 1.6, "seed": 3.0}), Vector3.ZERO, Vector3(0.7, 0.95, 0.7), Vector3(0, 1.0, 0), time * 0.25, time * 0.75 + 0.15, {"spin": Vector3(0, -6.5, 0), "fin": 0.05, "fout": 0.1})
		_feathers(w, S.n(8, 3), 1.4, 0.0, time + 0.2, 1.4, 1.0)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var feet := Vector3(source.x, 0, source.z)
	var s := K.open(parent, feet, 1.9, "StarContact_Bless_" + ID, feet + Vector3.BACK)
	if not s:
		return true
	# The wings flare open behind the archer and beat once before they fade.
	var back := s.stage(0.0, -0.35, 0.0)
	s.add(wings(), K.SOLID, WINGS, back, Vector3.ONE * 1.15, Vector3.ZERO, 0.0, 1.35,
		{"yaw_cam": true, "priority": 2, "fin": 0.06, "fout": 0.5, "curves": {"spread": [0.0, 0.1, 0.2, 1.0, 1.35, 0.85], "flap": [0.0, 0.0, 0.2, 0.22, 1.0, 0.1], "heat": [0.0, 0.35, 0.25, 0.0]}})
	# A whirlwind shoots up and a ring of wind rolls out.
	s.add(K.mesh("helix"), K.GLOW, WIND.merged({"mode": 16, "p1": 6.0, "p2": 0.8, "gain": 0.7, "life": 0.9}), Vector3.ZERO, Vector3(1.1, 1.0, 1.1), Vector3.ZERO, 0.0, 0.9, {"spin": Vector3(0, 9.0, 0), "to": Vector3(1.5, 1.7, 1.5), "fin": 0.01, "fout": 0.3})
	S.ring(s, Vector3.UP * 0.08, 6.5, WIND.merged({"p2": 1.0}), 0.0, 0.7, 0.5)
	S.ring(s, Vector3.UP * 1.1, 3.4, GALE, 0.05, 0.5, 0.5, Vector3.ZERO, {"yaw_cam": true})
	S.sparks(s, Vector3.UP * 1.0, S.n(16, 6), GALE, 0.24, 0.0, 0.8, 9.0, 1.0, 9, 1.4, 2.0)
	if S.lean():
		return true
	_feathers(s, S.n(12, 4), 2.4, 0.0, 1.2, 2.2, 5.0)
	# The wind keeps circling the archer, low, before it settles.
	s.add(K.mesh("helix"), K.GLOW, GALE.merged({"mode": 16, "p1": 2.0, "p2": 0.6, "gain": 0.4, "life": 1.9, "seed": 6.0}), Vector3.ZERO, Vector3(1.0, 0.45, 1.0), Vector3.ZERO, 0.25, 1.6, {"spin": Vector3(0, 3.5, 0), "fin": 0.2, "fout": 0.5})
	return true
