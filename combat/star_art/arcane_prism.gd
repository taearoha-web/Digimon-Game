extends RefCounted
## Mage 50-star "Arcane Prism" (ปริซึมเวท). Cosmetic only.
## A violet prism crystal rises and turns in front of the mage inside a rainbow swirl, a
## rune circle writing itself at the mage's feet. The prism splits its light four ways,
## one element per shot: a fire comet, a lance of ice, a fork of lightning and an arcane
## orb, each flashing the prism in its colour, and each landing in its own way (a burst of
## flame and a scorch, ice crystals and frost, a bolt from the sky with sparks). The
## fourth, arcane, closes the spell with a prismatic ring, a star and a crystal bloom.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const ID := "arcane_prism"
const SHOTS := [0.0, 0.22, 0.44, 0.66]
const ARCANE := {"c_core": Color("ecc0ff"), "c_mid": Color("c04dff"), "c_edge": Color("5a1aa8")}
## Fire, ice, lightning, arcane: glow colours, the body (tint / ember) and the ground mark.
const ELEMENTS := [
	{"c_core": Color("ffe08a"), "c_mid": Color("ff8a1a"), "c_edge": Color("e2300a"), "tint": Color("7a2a12"), "ember": Color("ff9a2e"), "mark": Color("1c0d06")},
	{"c_core": Color("c8f4ff"), "c_mid": Color("5fc8ff"), "c_edge": Color("2f6cff"), "tint": Color("8fdcff"), "ember": Color("7fd8ff"), "mark": Color("cfeeff")},
	{"c_core": Color("fff4a0"), "c_mid": Color("ffe04a"), "c_edge": Color("ff9a1a"), "tint": Color("ffe68a"), "ember": Color("ffe25a"), "mark": Color("201a08")},
	{"c_core": Color("f2c8ff"), "c_mid": Color("c44dff"), "c_edge": Color("6a1ad0"), "tint": Color("b06aff"), "ember": Color("d68aff"), "mark": Color("1a0630")},
]
## Where the prism hangs (world), set by the wind-up.
static var _prism := Vector3.ZERO


static func _glow(e: Dictionary) -> Dictionary:
	return {"c_core": e.c_core, "c_mid": e.c_mid, "c_edge": e.c_edge}


static func _shot(skill: Dictionary) -> int:
	var ref: WeakRef = GodSkillArt._casts.get(ID)
	var cast := ref.get_ref() as StarSkillSequence if ref else null
	if not is_instance_valid(cast):
		return 3
	var t := cast.clock - float(skill.get("hit_delay", 0.48))
	for k in 3:
		if t < (float(SHOTS[k]) + float(SHOTS[k + 1])) * 0.5:
			return k
	return 3


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var origin := caster.global_position
	var feet := origin * Vector3(1, 0, 1)
	var total := time + float(SHOTS.back()) + 0.35
	var w := S.root(parent, feet, total, "StarWindup_Prism_" + ID, feet - ((point - origin) * Vector3(1, 0, 1)), caster, time)
	if not w:
		return true
	var at := Vector3(0, 2.0, 0.85)
	_prism = w.to_global(at)
	w.add(K.mesh("crystal"), K.SOLID, {"tint": Color("c890ff"), "ember": Color("e0a8ff"), "glow": Color("f0d0ff"), "rim": 0.9, "shadow": Color("3a0f6a")}, at + Vector3.DOWN * 0.9, Vector3.ONE * 0.85, Vector3(0.3, 0, 0.25), 0.0, total,
		{"grow": time * 0.7, "from": 0.1, "spin": Vector3(0, 2.6, 0), "bob": 0.06, "fin": 0.08, "fout": 0.2, "priority": 2})
	w.add(K.mesh("quad"), K.GLOW, ARCANE.merged({"mode": 11, "billboard": true, "p1": 10.0, "p2": 0.18, "prism": 1.0, "gain": 0.55}), at, Vector3.ONE * 1.9, Vector3.ZERO, 0.0, total, {"grow": time, "from": 0.2, "fin": 0.1, "fout": 0.2, "priority": -1})
	w.add(K.mesh("quad"), K.GLOW, ARCANE.merged({"mode": 17, "p1": 6.0, "p2": 1.0 / maxf(time * 0.85 / total, 0.05), "gain": 0.65, "life": total}), Vector3.UP * 0.05, Vector3.ONE * 1.9, K.FLAT, 0.0, total, {"spin": Vector3(0, 0, 0.7), "fin": 0.08, "fout": 0.2})
	if not S.lean():
		# Motes of four colours drawn into the prism.
		var pulls := []
		var data := []
		var count := S.n(12, 4)
		for k in count:
			var s := K.rand(float(k) * 4.3)
			var a := float(k) * K.GOLDEN
			pulls.append(K.falling(at, -Vector3(cos(a), 0.3 + 0.5 * s, sin(a)).normalized(), 0.45))
			data.append(Color(s * time * 0.5, s, 0.14, 0))
		w.swarm(K.mesh("shard"), K.SOLID, {"motion": 1, "flight": time * 0.45, "travel": 14.0, "accelerate": 1.0, "stick": 0.0, "ember": Color("e8b0ff"), "rim": 0.0}, pulls, data, 0.0, time)
	return true


static func launch(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, flight: float) -> bool:
	var parent := art.get_parent() as Node3D
	var k := _shot(skill)
	var e: Dictionary = ELEMENTS[k]
	var from := _prism if _prism != Vector3.ZERO else S.hand(caster)
	var l := K.open(parent, from, flight + 0.8, "StarLaunch_Bolt_" + ID, from - (point - from))
	if not l:
		return true
	var reach := (point - from).length()
	var along := Vector3(0, 0, reach)
	var aim := K.falling(Vector3.ZERO, Vector3.BACK, 1.0).basis.get_euler()
	# The prism flashes in the element's colour as the shot leaves it.
	S.flash(l, Vector3.ZERO, 2.2, _glow(e), 0.0, 0.3, 0.6)
	S.ring(l, Vector3(0, 0, 0.3), 1.4, _glow(e), 0.0, 0.3, 0.6, Vector3.ZERO)
	match k:
		0:
			l.add(K.mesh("meteor"), K.SOLID, {"tint": e.tint, "ember": e.ember, "glow": e.ember, "rim": 0.7, "shadow": Color("2a0c04")}, Vector3.ZERO, Vector3.ONE * 0.8, aim, 0.0, flight + 0.02, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03, "priority": 2})
		1:
			l.add(K.mesh("shard"), K.SOLID, {"ember": e.ember, "rim": 0.0}, Vector3.ZERO, Vector3(1.3, 1.1, 1.3), aim, 0.0, flight + 0.02, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03, "priority": 2})
			l.add(K.mesh("light_arrow"), K.SOLID, {"tint": e.tint, "ember": e.ember, "glow": Color.WHITE, "rim": 0.6}, Vector3.ZERO, Vector3(1.0, 0.7, 1.0), aim, 0.0, flight + 0.02, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03, "priority": 2})
		2:
			# Lightning does not fly: it forks from the prism to the foe in an instant.
			var fork := aim
			l.add(K.mesh("bolt"), K.GLOW, _glow(e).merged({"mode": 13, "life": flight + 0.25}), along, Vector3(1.0, reach / 9.0, 1.0), fork, flight * 0.6, 0.35, {"fin": 0.01})
			l.add(K.mesh("sphere"), K.SUN, _glow(e).merged({"flow": 4.0}), Vector3.ZERO, Vector3.ONE * 0.3, Vector3.ZERO, 0.0, flight, {"travel": along, "tw": Vector2(0, flight * 0.6), "fin": 0.01, "fout": 0.02})
		3:
			l.add(K.mesh("sphere"), K.SUN, _glow(e).merged({"flow": 3.0}), Vector3.ZERO, Vector3.ONE * 0.42, Vector3.ZERO, 0.0, flight + 0.02, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03})
			l.add(K.mesh("quad"), K.GLOW, _glow(e).merged({"mode": 11, "billboard": true, "p1": 12.0, "p2": 0.25, "prism": 1.0, "gain": 0.6}), Vector3.ZERO, Vector3.ONE * 1.3, Vector3.ZERO, 0.0, flight + 0.02, {"travel": along, "tw": Vector2(0, flight), "fin": 0.01, "fout": 0.03})
	if k != 2:
		l.add(K.mesh("beam"), K.GLOW, _glow(e).merged({"mode": 16, "p1": 7.0, "p2": 0.6, "gain": 0.6, "life": flight * 3.2}), Vector3.ZERO, Vector3(0.45, reach, 0.45), Vector3(PI / 2, 0, 0), 0.0, flight * 3.2, {"fin": 0.01})
	return true


static func strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	var at := Vector3(point.x, 0, point.z)
	var k := clampi(index, 0, 3)
	var e: Dictionary = ELEMENTS[k]
	var c := _glow(e)
	var s := K.open(parent, at, 1.5, "StarContact_Element_" + ID, source)
	if not s:
		return true
	var chest := Vector3.UP * 1.1
	S.ring(s, Vector3.UP * 0.08, 2.6 + 0.4 * k, c, 0.0, 0.5, 0.7)
	S.flash(s, chest, 2.0, c, 0.0, 0.25, 0.5)
	var mark := {"mode": 7, "seed": float(k) * 3.0, "life": 1.2, "c_core": e.c_core, "c_mid": e.c_mid, "c_edge": e.mark}
	match k:
		0:
			var puffs := []
			var data := []
			for j in 3:
				var s0 := K.rand(float(j) * 2.1)
				puffs.append(K.card(Vector3(sin(j * 2.1), 0, cos(j * 2.1)) * 0.45 + Vector3.UP * (0.7 + 0.3 * s0), 1.3 + 0.4 * s0))
				data.append(Color(0.04 * j, s0, 0, 0))
			s.swarm(K.mesh("quad"), K.VEIL, c.merged({"mode": 8, "billboard": true, "life": 0.55, "grow": Vector2(0.5, 1.4), "drift": Vector3(0, 1.6, 0)}), puffs, data, 0.0, 0.7, {"fin": 0.01, "priority": 1})
		1:
			s.add(K.mesh("ice"), K.SOLID, {"motion": 2, "hold": 0.55, "glow": Color("c8f4ff"), "rim": 0.8, "shadow": Color("2a5ac8")}, Vector3.ZERO, Vector3.ONE * 1.1, Vector3(0, 0.6, 0), 0.0, 1.0, {"fin": 0.01, "fout": 0.1})
		2:
			s.add(K.mesh("bolt"), K.GLOW, c.merged({"mode": 13, "life": 0.35}), Vector3.ZERO, Vector3(0.9, 0.75, 0.9), Vector3(0, 0.4, 0), 0.0, 0.35, {"fin": 0.01})
			S.sparks(s, chest, S.n(12, 4), c, 0.2, 0.0, 0.5, 9.0, 8.0, 9, 1.2, 3.0)
		3:
			# The closing shot: a prismatic ring, a star and a bloom of crystals.
			s.add(K.mesh("quad"), K.GLOW, ARCANE.merged({"mode": 1, "p1": 1.2, "p2": 1.0, "prism": 1.0, "gain": 0.75}), Vector3.UP * 0.1, Vector3.ONE * 5.0, K.FLAT, 0.0, 0.7, {"fin": 0.01})
			s.add(K.mesh("quad"), K.GLOW, c.merged({"mode": 10, "billboard": true, "life": 0.6, "prism": 0.6, "gain": 0.8}), chest + Vector3.UP * 0.4, Vector3.ONE * 3.2, Vector3.ZERO, 0.0, 0.6, {"grow": 0.1, "from": 0.3, "fin": 0.01})
			var bloom := []
			var data := []
			for j in 5:
				var a := TAU * float(j) / 5.0
				bloom.append(K.standing(Vector3(sin(a), 0, cos(a)) * 0.7, Vector3.ONE * (0.7 + 0.15 * (j % 2)), a))
				data.append(Color(0.03 * j, K.rand(float(j)), 0, 0))
			s.swarm(K.mesh("crystal"), K.SOLID, {"motion": 2, "hold": 0.6, "glow": Color("f0b0ff"), "rim": 0.8, "shadow": Color("2a0a6a")}, bloom, data, 0.0, 1.1, {"fin": 0.01, "fout": 0.1})
			S.sparks(s, chest, S.n(16, 6), ARCANE.merged({"prism": 1.0}), 0.24, 0.0, 0.8, 9.0, 3.0, 10, 1.2, 5.0)
	if not S.lean():
		s.add(K.mesh("quad"), K.VEIL, mark, Vector3.UP * (0.05 + 0.003 * k), Vector3.ONE * (1.6 + 0.3 * k), K.FLAT, 0.0, 1.2, {"fin": 0.01, "priority": -1})
	return true
