extends RefCounted
## Archer 100-star "Hunter's Verdict" (ศรตัดสินนักล่า). Cosmetic only.
## The hunt locks on: a jade reticle closes on the prey from twice its size, turning,
## while a lock ring settles on the ground and the wind winds round the archer's feet.
## Two quick jade shots each tighten the reticle with a ring of light and a spray of
## sparks; the third, the verdict, is a heavy arrow with a long wake: the reticle snaps
## shut and bursts, a column of jade light stands over the prey, a giant arrow is left
## planted in the scorched ground and stars of light scatter.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "hunters_verdict"
const JADE := {"c_core": Color("a4f5c8"), "c_mid": Color("1fd38a"), "c_edge": Color("0d7a5a")}
const LIME := {"c_core": Color("e2ffb0"), "c_mid": Color("8ef07a"), "c_edge": Color("1fa070")}
const ARROW := {"tint": Color("8fe8b8"), "ember": Color("3fe39a"), "glow": Color("c8ffd8"), "rim": 0.7, "shadow": Color("0d5a4a")}
const SCAR := {"c_core": Color("b8ffcf"), "c_mid": Color("2fbf7a"), "c_edge": Color("0b2a20")}
## The three shots leave the bow this long after the release (StarSkillSequence beats).
const SHOTS := [0.0, 0.26, 0.68]


## Which of the three shots is leaving now (from the running cast's clock).
static func _shot(skill: Dictionary) -> int:
	var ref: WeakRef = GodSkillArt._casts.get(ID)
	var cast := ref.get_ref() as StarSkillSequence if ref else null
	if not is_instance_valid(cast):
		return 2
	var t := cast.clock - float(skill.get("hit_delay", 0.62))
	return 0 if t < 0.13 else (1 if t < 0.47 else 2)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var origin := caster.global_position
	var prey := Vector3(point.x, 0, point.z)
	var total := time + float(SHOTS.back()) + 0.28 + 0.15
	var lock := S.root(parent, prey, total, "StarWindup_Lock_" + ID, origin, caster, time)
	if lock:
		# The reticle closes on the prey and tightens a notch at every hit.
		var close := [0.0, 2.3, time, 1.15, time + 0.3, 1.0, time + 0.56, 0.86, total - 0.1, 0.78]
		lock.add(K.mesh("reticle"), K.SOLID, ARROW.merged({"rim": 0.2}), Vector3.UP * 1.25, Vector3.ONE * 1.1, Vector3.ZERO, 0.0, total,
			{"scale_curve": close, "spin": Vector3(0, 0, 1.6), "yaw_cam": true, "fin": 0.12, "fout": 0.06, "priority": 2})
		lock.add(K.mesh("quad"), K.GLOW, JADE.merged({"mode": 5, "p1": 18.0, "gain": 0.7}), Vector3.UP * 0.06, Vector3.ONE * 1.5, K.FLAT, 0.0, total,
			{"scale_curve": [0.0, 2.2, time, 1.0], "spin": Vector3(0, 0, -0.8), "fin": 0.15, "fout": 0.1})
	var w := S.root(parent, Vector3(origin.x, 0, origin.z), time + 0.2, "StarWindup_Wind_" + ID, origin - (prey - origin), caster, time)
	if w:
		w.add(K.mesh("helix"), K.GLOW, JADE.merged({"mode": 16, "p1": 2.5, "p2": 0.7, "gain": 0.55, "life": time + 0.6}), Vector3.ZERO, Vector3(0.8, 0.85, 0.8), Vector3.ZERO, 0.0, time + 0.2,
			{"spin": Vector3(0, 5.0, 0), "grow": time * 0.6, "from": 0.4, "fin": 0.08, "fout": 0.15})
		S.flash(w, w.to_local(S.hand(caster)), 1.1, JADE, time * 0.3, time * 0.7 + 0.1, 0.6, {"grow": time * 0.7, "from": 0.1, "fout": 0.08})
	return true


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var parent := art.get_parent() as Node3D
	var shot := _shot(skill)
	var verdict := shot == 2
	var from := S.hand(caster)
	var l := K.open(parent, from, flight + 1.2, "StarLaunch_Shot_" + ID, from - (point - from))
	if not l:
		return true
	var reach := (point - from).length()
	var along := Vector3(0, 0, reach)
	var aim := K.falling(Vector3.ZERO, Vector3.BACK, 1.0).basis.get_euler()
	var size := 1.9 if verdict else 1.05
	l.add(K.mesh("light_arrow"), K.SOLID, ARROW, Vector3.ZERO, Vector3.ONE * size, aim, 0.0, flight + 0.03, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03, "priority": 2})
	l.add(K.mesh("beam"), K.GLOW, JADE.merged({"mode": 16, "p1": 7.0, "p2": 0.6, "gain": 0.75 if verdict else 0.55, "life": flight * 4.0}), Vector3.ZERO, Vector3(0.9 if verdict else 0.45, reach, 0.9 if verdict else 0.45), Vector3(PI / 2, 0, 0), 0.0, flight * 4.0, {"fin": 0.01, "fout": 0.05})
	S.ring(l, Vector3(0, 0, 0.5), 2.2 if verdict else 1.3, JADE.merged({"p2": 1.0 if verdict else 0.0}), 0.0, 0.35, 0.75, Vector3.ZERO)
	if verdict:
		# The verdict's wake: wind winding round the arrow's path.
		l.add(K.mesh("helix"), K.GLOW, LIME.merged({"mode": 16, "p1": 4.0, "p2": 0.8, "gain": 0.6, "life": flight * 3.0}), Vector3.ZERO, Vector3(0.55, reach / 2.6, 0.55), Vector3(PI / 2, 0, 0), 0.0, flight * 3.0, {"fin": 0.01, "fout": 0.1})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var prey := Vector3(point.x, 0, point.z)
	var verdict := index >= 2
	var s := K.open(parent, prey, 1.6, "StarContact_Hit_" + ID, source)
	if not s:
		return true
	var chest := Vector3.UP * 1.25
	if not verdict:
		# A shot lands: a ring of jade light, the reticle's echo and a spray of sparks.
		S.ring(s, Vector3.UP * 0.07, 2.6 + 0.5 * index, JADE, 0.0, 0.45, 0.7)
		s.add(K.mesh("reticle"), K.SOLID, ARROW.merged({"rim": 0.2}), chest, Vector3.ONE * 0.6, Vector3.ZERO, 0.0, 0.3, {"grow": 0.06, "from": 2.2, "to": Vector3.ONE * 1.6, "yaw_cam": true, "fin": 0.01, "fout": 0.2, "priority": 2})
		S.flash(s, chest, 1.8, JADE, 0.0, 0.22, 0.45)
		S.sparks(s, chest, S.n(10, 4), JADE, 0.22, 0.0, 0.5, 7.0, 6.0, 9, 1.0, float(index))
		return true
	# The verdict: the reticle snaps shut and bursts, a column of jade light stands over the
	# prey, the giant arrow stays planted in the scorched ground, stars of light scatter.
	s.add(K.mesh("reticle"), K.SOLID, ARROW.merged({"rim": 0.2}), chest, Vector3.ONE * 1.0, Vector3.ZERO, 0.0, 0.3, {"to": Vector3.ONE * 0.15, "yaw_cam": true, "spin": Vector3(0, 0, 9.0), "fin": 0.01, "fout": 0.1, "priority": 2})
	s.add(K.mesh("column"), K.GLOW, JADE.merged({"mode": 3, "p1": -5.0, "p2": 0.35, "gain": 1.0}), Vector3.ZERO, Vector3(0.9, 7.5, 0.9), Vector3.ZERO, 0.0, 0.85, {"to": Vector3(0.35, 1.0, 0.35), "fin": 0.01, "fout": 0.4})
	S.ring(s, Vector3.UP * 0.08, 5.2, JADE.merged({"p2": 1.0}), 0.0, 0.6, 0.85)
	S.ring(s, chest, 3.2, LIME, 0.04, 0.4, 0.6, Vector3.ZERO, {"yaw_cam": true})
	var lean := Basis(Vector3(1, 0, 0), 0.55)
	var planted := K.falling(Vector3(0, 0.02, -0.35), lean * Vector3.DOWN, 1.0).basis.get_euler()
	s.add(K.mesh("light_arrow_bare"), K.SOLID, ARROW, Vector3(0, -0.25, -0.35), Vector3.ONE * 1.9, planted, 0.0, 1.3, {"fin": 0.01, "fout": 0.45, "priority": 1})
	s.add(K.mesh("quad"), K.VEIL, SCAR.merged({"mode": 7, "seed": 4.0, "life": 1.5}), Vector3.UP * 0.05, Vector3.ONE * 2.2, K.FLAT, 0.0, 1.5, {"fin": 0.01, "priority": -1})
	S.sparks(s, chest, S.n(22, 8), LIME, 0.3, 0.0, 0.8, 10.0, 5.0, 10, 1.0, 7.0)
	if not S.lean():
		S.motes(s, Vector3.ZERO, 1.6, S.n(10, 4), JADE, 0.25, 0.2, 0.5, 1.0, 1.4, 9, 3.0)
	return true
