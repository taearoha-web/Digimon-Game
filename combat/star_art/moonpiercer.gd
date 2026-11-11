extends RefCounted
## Archer 50-star "Moonpiercer" (ศรทะลวงจันทรา). Cosmetic only.
## A silver crescent rises behind the archer while moonlight is drawn into the bow and a
## path of moonlight writes itself along the line ahead. The arrow leaves with a crescent
## flash and drags a beam of silver the whole length of the line; on contact the line is
## pierced: rings of light stand round it where it ran through, a crescent flares at its
## far end and silver motes drift up off the moonlit scar.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "moonpiercer"
const SILVER := {"c_core": Color("b9d2ff"), "c_mid": Color("7aa4ff"), "c_edge": Color("3a4fd0")}
## The thin hot line inside the beam: pale, but still moon blue.
const CORE := {"c_core": Color("d6e4ff"), "c_mid": Color("9dbcff"), "c_edge": Color("5a78f0")}
const MOON := {"tint": Color("9dbcff"), "ember": Color("86acff"), "glow": Color("d0e0ff"), "rim": 0.6, "shadow": Color("2c3a8a")}


static func _length(skill: Dictionary) -> float:
	return float(skill.get("length", 18.0))


## The line ahead of the caster, flat: [feet, forward].
static func _line(from: Vector3, to: Vector3) -> Array:
	var feet := Vector3(from.x, 0, from.z)
	var f := (to - from) * Vector3(1, 0, 1)
	return [feet, f.normalized() if f.length_squared() > 0.001 else Vector3.FORWARD]


## How far along the line (metres) each living foe on it stands, nearest first (read only).
static func _pierced(node: Node, feet: Vector3, fwd: Vector3, length: float, width: float) -> Array:
	var out := []
	if not is_instance_valid(node) or not node.is_inside_tree():
		return out
	for item in node.get_tree().get_nodes_in_group("mobs"):
		var mob := item as Mob
		if not mob or mob.is_dead():
			continue
		var offset := (mob.global_position - feet) * Vector3(1, 0, 1)
		var along := offset.dot(fwd)
		if along >= 0.0 and along <= length and (offset - fwd * along).length() <= width + mob.body_radius():
			out.append(along)
	out.sort()
	return out


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var line := _line(caster.global_position, point)
	var feet: Vector3 = line[0]
	var fwd: Vector3 = line[1]
	var length := _length(skill)
	var w := S.root(parent, feet, time + 0.5, "StarWindup_Moon_" + ID, feet - fwd, caster, time)
	if not w:
		return true
	var hand := w.to_local(S.hand(caster))
	# The crescent rises over the archer's shoulder and holds until the arrow is away.
	w.add(K.mesh("crescent"), K.SOLID, MOON, Vector3(0, 1.3, -0.5), Vector3.ONE * 0.95, Vector3(0, 0, -0.45), 0.0, time + 0.3,
		{"grow": time * 0.7, "from": 0.15, "travel": Vector3(0, 1.1, -0.1), "tw": Vector2(0, time * 0.9), "ease": 2, "yaw_cam": true, "fin": 0.1, "fout": 0.2, "priority": 1})
	S.flash(w, Vector3(0, 2.4, -0.6), 2.6, SILVER, 0.0, time + 0.3, 0.22, {"grow": time, "from": 0.2, "fout": 0.25})
	# Moonlight is drawn into the bow hand.
	S.flash(w, hand, 1.2, SILVER, time * 0.2, time * 0.8 + 0.06, 0.55, {"grow": time * 0.8, "from": 0.1, "fout": 0.08})
	var pulls := []
	var data := []
	var count := S.n(10, 4)
	for k in count:
		var s := K.rand(float(k) * 2.7)
		var a := float(k) * K.GOLDEN
		var from := Vector3(cos(a), 0.4 + 0.6 * s, sin(a)).normalized()
		pulls.append(K.falling(hand, -from, 0.5 + 0.3 * s))
		data.append(Color(s * time * 0.5, s, 0.12 + 0.06 * s, 0))
	w.swarm(K.mesh("shard"), K.SOLID, {"motion": 1, "flight": time * 0.45, "travel": 14.0, "accelerate": 1.0, "stick": 0.0, "ember": Color("cfe0ff"), "rim": 0.0}, pulls, data, 0.0, time)
	# The path of moonlight writes itself along the line.
	w.add(K.mesh("quad"), K.GLOW, SILVER.merged({"mode": 16, "p1": 1.5, "p2": 0.6, "gain": 0.32}), Vector3(0, 0.05, length * 0.5 + 0.4), Vector3(0.55, length * 0.5, 1), Vector3(PI / 2, 0, 0), time * 0.15, time + 0.4, {"fin": 0.05, "fout": 0.2})
	return true


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var parent := art.get_parent() as Node3D
	var from := S.hand(caster)
	var l := K.open(parent, from, flight + 1.0, "StarLaunch_Moon_" + ID, from - (point - from))
	if not l:
		return true
	var reach := (point - from).length()
	var along := Vector3(0, 0, reach)
	var aim := K.falling(Vector3.ZERO, Vector3.BACK, 1.0).basis.get_euler()
	# The arrow and the silver beam it drags the length of the line.
	l.add(K.mesh("light_arrow"), K.SOLID, MOON.merged({"rim": 0.9}), Vector3.ZERO, Vector3.ONE * 1.25, aim, 0.0, flight + 0.04, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.04, "priority": 2})
	l.add(K.mesh("beam"), K.GLOW, SILVER.merged({"mode": 16, "p1": 6.0, "p2": 0.5, "gain": 0.75, "life": flight * 4.0}), Vector3.ZERO, Vector3(0.7, reach, 0.7), Vector3(PI / 2, 0, 0), 0.0, flight * 4.0, {"fin": 0.01, "fout": 0.05})
	l.add(K.mesh("beam"), K.GLOW, CORE.merged({"mode": 16, "p1": 8.0, "p2": 0.8, "gain": 0.5, "life": flight * 4.0}), Vector3.ZERO, Vector3(0.22, reach, 0.22), Vector3(PI / 2, 0, 0), 0.0, flight * 4.0, {"fin": 0.01, "fout": 0.05})
	# A crescent rides on the arrow's head, turned to the camera.
	l.add(K.mesh("crescent"), K.SOLID, MOON, Vector3(0, 0, 0.3), Vector3.ONE * 0.55, Vector3(0, 0, -0.45), 0.0, flight + 0.04, {"travel": along, "tw": Vector2(0, flight), "yaw_cam": true, "fin": 0.01, "fout": 0.04, "priority": 2})
	# The release: a crescent flash and a ring of air round the bow.
	l.add(K.mesh("crescent"), K.SOLID, MOON, Vector3.ZERO, Vector3.ONE * 0.6, Vector3(0, 0, -0.45), 0.0, 0.32, {"grow": 0.1, "from": 0.4, "to": Vector3.ONE * 1.8, "yaw_cam": true, "fin": 0.01, "fout": 0.2, "priority": 1})
	S.ring(l, Vector3(0, 0, 0.4), 1.6, SILVER, 0.0, 0.35, 0.7, Vector3.ZERO)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var line := _line(source, point)
	var feet: Vector3 = line[0]
	var fwd: Vector3 = line[1]
	var length := _length(skill)
	var s := K.open(parent, feet, 1.4, "StarContact_Moon_" + ID, feet - fwd)
	if not s:
		return true
	# Every foe on the line is run through: a ring of light round the line and a crescent
	# cut across it; where nobody stands, the rings mark the arrow's way.
	var hits := _pierced(parent, feet, fwd, length, float(skill.get("width", 1.5)))
	var stops: int = [2, 3, 4][S.q()]
	if hits.is_empty():
		for k in stops:
			hits.append(length * (0.2 + 0.6 * float(k) / float(maxi(1, stops - 1))))
	for k in mini(hits.size(), stops):
		var z: float = hits[k]
		var delay := 0.012 * z
		S.ring(s, Vector3(0, 1.1, z), 2.4, SILVER.merged({"p2": 1.0}), delay, 0.5, 0.6, Vector3(0, 0.5, 0))
		s.add(K.mesh("crescent"), K.SOLID, MOON, Vector3(0, 1.15, z), Vector3.ONE * 0.7, Vector3(0, 0, PI * 0.5 + 0.4 * float(k % 2)), delay, 0.36, {"grow": 0.08, "from": 0.3, "to": Vector3.ONE * 1.25, "yaw_cam": true, "fin": 0.01, "fout": 0.25, "priority": 1})
	# The moonlit scar along the ground and the crescent flaring at the end of the line.
	s.add(K.mesh("quad"), K.GLOW, SILVER.merged({"mode": 16, "p1": 3.0, "p2": 0.7, "gain": 0.32, "life": 1.1}), Vector3(0, 0.06, length * 0.5 + 0.4), Vector3(0.7, length * 0.5, 1), Vector3(PI / 2, 0, 0), 0.0, 1.1, {"fin": 0.01})
	var end := Vector3(0, 1.4, length)
	s.add(K.mesh("crescent"), K.SOLID, MOON, end, Vector3.ONE * 1.3, Vector3(0, 0, -0.45), 0.0, 0.8, {"grow": 0.12, "from": 0.3, "travel": Vector3.UP * 0.6, "yaw_cam": true, "fin": 0.01, "fout": 0.45, "priority": 1})
	S.flash(s, end, 3.4, SILVER, 0.0, 0.45, 0.4)
	if S.lean():
		return true
	# Silver motes drift up off the line.
	var cards := []
	var data := []
	var count := S.n(18, 6)
	for k in count:
		var r := K.rand(float(k) * 3.1)
		cards.append(K.card(Vector3((r - 0.5) * 1.2, 0.3 + 0.8 * K.rand(r * 7.0), length * (0.08 + 0.9 * float(k) / float(count))), 0.2 + 0.18 * r))
		data.append(Color(0.05 + r * 0.25, r, 0, 0))
	s.swarm(K.mesh("quad"), K.GLOW, SILVER.merged({"mode": 10, "billboard": true, "life": 0.95, "drift": Vector3(0, 1.1, 0), "sway": 0.2}), cards, data, 0.0, 1.35, {"fin": 0.01})
	return true
