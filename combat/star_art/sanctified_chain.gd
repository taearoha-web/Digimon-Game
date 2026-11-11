extends RefCounted
## Priest 50-star "Sanctified Chain" (สายใยศักดิ์สิทธิ์). Cosmetic only.
## A golden rosary of light gathers turning over the priest's hands on a holy cross
## sigil. At the release a chain of golden links runs out from the priest to every foe it
## binds (up to five), link after link along a beam of light; where it bites, a cross of
## light burns over the foe in a ring of gold. The blessing comes back along it: a soft
## green-gold ring and rising motes of healing wash over the priest's side.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "sanctified_chain"
const HOLY := {"c_core": Color("ffe39a"), "c_mid": Color("ffc23a"), "c_edge": Color("c0701a")}
const HEAL := {"c_core": Color("e6ffb8"), "c_mid": Color("8fe86a"), "c_edge": Color("d8b040")}
const GILT := {"tint": Color("ffd77a"), "ember": Color("ffc84a"), "glow": Color("fff0c0"), "rim": 0.7, "shadow": Color("8a5a20")}
static var _rosary: Mesh
static var _heal_frame := -1


## A rosary: a ring of light (radius 1, XY plane, facing +Z) threaded with ten beads.
static func rosary() -> Mesh:
	if _rosary == null:
		var b := K.Build.new()
		var path := []
		var radii := []
		for k in 33:
			var a := TAU * float(k) / 32.0
			path.append(Vector3(cos(a), sin(a), 0))
			radii.append(0.025)
		b.emit = 0.9
		b.tube(path, radii, 4, Color.WHITE, Color.WHITE)
		for k in 10:
			var a := TAU * float(k) / 10.0
			b.emit = 0.6
			b.ball(Vector3(cos(a), sin(a), 0), Vector3.ONE * (0.11 if k > 0 else 0.16), Color.WHITE, Color(0.9, 0.85, 0.75), 8, 5)
		b.emit = 0.8
		b.tube([Vector3(0, -1.0, 0), Vector3(0, -1.55, 0)], [0.03, 0.03], 4, Color.WHITE, Color.WHITE)
		b.tube([Vector3(-0.2, -1.3, 0), Vector3(0.2, -1.3, 0)], [0.03, 0.03], 4, Color.WHITE, Color.WHITE)
		_rosary = b.commit()
	return _rosary


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var origin := caster.global_position
	var feet := origin * Vector3(1, 0, 1)
	var w := S.root(parent, feet, time + 0.35, "StarWindup_Rosary_" + ID, feet - (point - origin) * Vector3(1, 0, 1), caster, time)
	if not w:
		return true
	var over := w.stage(0.0, 0.25, 2.55)
	w.add(rosary(), K.SOLID, GILT, over, Vector3.ONE * 0.62, Vector3(-0.3, 0, 0), 0.0, time + 0.3,
		{"grow": time * 0.8, "from": 0.2, "spin": Vector3(0, 0, 1.6), "yaw_cam": true, "fin": 0.1, "fout": 0.2, "priority": 2})
	S.flash(w, over, 2.4, HOLY, 0.0, time + 0.3, 0.3, {"grow": time, "from": 0.2, "fout": 0.25})
	w.add(K.mesh("quad"), K.GLOW, HOLY.merged({"mode": 17, "p1": 4.0, "p2": 1.0 / maxf(time * 0.8 / (time + 0.35), 0.05), "gain": 0.7, "life": time + 0.35}), Vector3.UP * 0.05, Vector3.ONE * 1.9, K.FLAT, 0.0, time + 0.35, {"spin": Vector3(0, 0, 0.6), "fin": 0.05, "fout": 0.2})
	S.flash(w, w.to_local(S.hand(caster)), 1.2, HOLY, time * 0.3, time * 0.7 + 0.1, 0.55, {"grow": time * 0.7, "from": 0.1})
	return true


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var parent := art.get_parent() as Node3D
	var from := S.hand(caster)
	var l := K.open(parent, from, flight + 0.9, "StarLaunch_Chain_" + ID, from - (point - from))
	if not l:
		return true
	var reach := (point - from).length()
	var dir := Vector3.BACK
	# The chain runs out link after link, holds a moment and falls away.
	var links := []
	var data := []
	var count := clampi(int(reach / 0.4), 3, 40)
	if S.lean():
		count = mini(count, 16)
	var step := reach / float(count)
	for k in count:
		var t := K.falling(Vector3(0, 0, step * (float(k) + 0.5)), -dir, step / 0.5 * 1.05, PI * 0.5 * float(k % 2))
		links.append(t)
		data.append(Color(flight * float(k) / float(count), K.rand(float(k)), 0, 0))
	l.swarm(K.mesh("link"), K.SOLID, GILT.merged({"motion": 2, "hold": 0.55}), links, data, 0.0, flight + 0.85, {"fin": 0.01, "fout": 0.05, "priority": 1})
	l.add(K.mesh("beam"), K.GLOW, HOLY.merged({"mode": 16, "p1": 5.0, "p2": 0.6, "gain": 0.45, "life": flight * 4.0}), Vector3.ZERO, Vector3(0.5, reach, 0.5), Vector3(PI / 2, 0, 0), 0.0, flight * 4.0, {"fin": 0.01})
	S.flash(l, Vector3.ZERO, 1.3, HOLY, 0.0, 0.25, 0.5)
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var at := Vector3(point.x, 0, point.z)
	var s := K.open(parent, at, 1.2, "StarContact_Bind_" + ID, source)
	if s:
		# A cross of light burns over the bound foe in a ring of gold.
		s.add(K.mesh("quad"), K.GLOW, HOLY.merged({"mode": 6, "p1": 0.18, "p2": 7.0, "gain": 0.9}), Vector3.UP * 1.5, Vector3.ONE * 1.25, Vector3.ZERO, 0.0, 0.7, {"yaw_cam": true, "grow": 0.1, "from": 0.5, "fin": 0.01, "fout": 0.35, "priority": 2})
		S.ring(s, Vector3.UP * 0.08, 2.4, HOLY, 0.0, 0.5, 0.65)
		S.sparks(s, Vector3.UP * 1.1, S.n(7, 3), HOLY, 0.2, 0.0, 0.5, 6.0, 4.0, 10, 1.0, at.x)
	# The blessing washes back over the priest's side once per contact.
	var frame := Engine.get_process_frames()
	if frame != _heal_frame:
		_heal_frame = frame
		S.heal(parent, source, 3.6, "StarContact_Heal_" + ID, HEAL)
	return true
