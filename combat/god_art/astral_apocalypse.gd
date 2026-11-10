extends RefCounted
## Mage god skill "Astral Apocalypse" (อวสานแห่งดวงดาว). Cosmetic only.
## The field falls away into deep space: a pool of stars opens under the enemies, a small
## star burns over it inside three tilted orbits with their planets. Four waves of
## meteors streak in from four directions, one element each (fire, ice, lightning,
## arcane) with its own tail and its own impact. Then the star collapses into a black
## singularity that drags the light in, and bursts as a supernova: a white-hot shell, a
## prismatic shock ring and stardust falling over the field.
## Every wave is drawn one beat ahead so that it lands on its own contact.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const ID := "astral_apocalypse"
## Where the star burns (root space, set by the wind-up): low over the field and a
## little towards the camera, because the field camera looks down from high up.
static var _star := Vector3(0, 3.6, -1.2)
const FLIGHT := 0.26
const SPACE := {"c_core": Color("9ff0ff"), "c_mid": Color("7a4cff"), "c_edge": Color("0a0626")}
const STARLIGHT := {"c_core": Color.WHITE, "c_mid": Color("a6f2ff"), "c_edge": Color("6f4cff")}
## tint: the rock, ember: its fire and tail, then the impact colours, where it comes
## from, and what it leaves on the ground.
const ELEMENTS := [
	{"tint": Color("7a2a12"), "ember": Color("ff9a2e"), "c_core": Color("fff4b8"), "c_mid": Color("ff8a1a"), "c_edge": Color("e2300a"), "from": Vector3(-0.8, 1.0, 0.1), "mark": Color("1c0d06")},
	{"tint": Color("3a78c8"), "ember": Color("a8ecff"), "c_core": Color.WHITE, "c_mid": Color("8fdcff"), "c_edge": Color("2f7cff"), "from": Vector3(0.8, 1.0, 0.25), "mark": Color("d8f4ff")},
	{"tint": Color("8a6a14"), "ember": Color("fff38a"), "c_core": Color.WHITE, "c_mid": Color("ffee6a"), "c_edge": Color("ffae1a"), "from": Vector3(0.05, 1.0, 0.1), "mark": Color("201a08")},
	{"tint": Color("4a148a"), "ember": Color("e58aff"), "c_core": Color("ffe4ff"), "c_mid": Color("c44dff"), "c_edge": Color("6a1ad0"), "from": Vector3(-0.1, 1.0, -0.85), "mark": Color("1a0630")},
]


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.5)), 4.0, 10.0)


static func _centre(j: int, r: float) -> Vector3:
	var a := float(j) * 2.3 + 0.4
	return Vector3(sin(a), 0, cos(a)) * r * [0.46, 0.46, 0.4, 0.3][j]


static func _glow(e: Dictionary) -> Dictionary:
	return {"c_core": e.c_core, "c_mid": e.c_mid, "c_edge": e.c_edge}


## The meteors of beat [param j] and what their element does to the ground.
static func _meteors(root: K, j: int, r: float, start: float) -> void:
	var q := K.quality()
	var n: int = [2, 3, 4][q] + (1 if j == 3 and q > 0 else 0)
	if MemoryGuard.pressure > 0:
		n = 2
	var e: Dictionary = ELEMENTS[j]
	var centre := _centre(j, r)
	var dir := -(e.from as Vector3).normalized()
	var rocks := []
	var rock_data := []
	var rings := []
	var land_data := []
	var stands := []
	var cards := []
	var marks := []
	for k in n:
		var seed := K.rand(float(k) * 4.7 + float(j) * 2.9)
		var spot := centre + K.scatter(k, n, r * 0.36, float(j) + 0.3)
		var delay := 0.1 * float(k) / float(maxi(1, n - 1))
		rocks.append(K.falling(spot, dir + Vector3(seed - 0.5, 0, K.rand(seed * 9.0) - 0.5) * 0.12, 1.15 + 0.3 * seed, seed * TAU))
		rock_data.append(Color(delay, seed, 0, 0))
		rings.append(K.lying(spot + Vector3.UP * (0.09 + 0.002 * k), 3.0 + seed))
		land_data.append(Color(delay + FLIGHT, seed, 0, 0))
		stands.append(K.standing(spot, Vector3.ONE * (1.3 + 0.5 * seed), seed * TAU))
		cards.append(K.card(spot + Vector3.UP * 0.9, 1.9 + 0.5 * seed))
		marks.append(K.lying(spot + Vector3.UP * (0.05 + 0.002 * k), 2.1 + 0.6 * seed, seed * TAU))
	var window := FLIGHT + 0.1
	root.swarm(K.mesh("meteor"), K.SOLID, {"motion": 1, "flight": FLIGHT, "travel": 17.0, "stick": 0.0, "tint": e.tint, "ember": e.ember, "glow": e.ember, "rim": 0.7, "shadow": Color("1a1030")}, rocks, rock_data, start, window + 0.1, {"fin": 0.01, "fout": 0.02})
	root.swarm(K.mesh("quad"), K.GLOW, _glow(e).merged({"mode": 1, "life": 0.55, "p1": 0.9, "gain": 0.7}), rings, land_data, start, window + 0.6, {"fin": 0.01, "fout": 0.05})
	match j:
		0:
			root.swarm(K.mesh("quad"), K.VEIL, _glow(e).merged({"mode": 8, "billboard": true, "life": 0.6, "grow": Vector2(0.5, 1.5), "drift": Vector3(0, 1.6, 0)}), cards, land_data, start, window + 0.65, {"fin": 0.01, "fout": 0.05, "priority": 1})
		1:
			root.swarm(K.mesh("ice"), K.SOLID, {"motion": 2, "hold": 0.6, "glow": Color("c8f4ff"), "rim": 0.8, "shadow": Color("2a5ac8")}, stands, land_data, start, window + 1.0, {"fin": 0.01, "fout": 0.1})
		2:
			var bolts := []
			for k in n:
				bolts.append(K.standing((stands[k] as Transform3D).origin, Vector3(1.0, 0.85, 1.0), K.rand(float(k)) * TAU))
			root.swarm(K.mesh("bolt"), K.GLOW, _glow(e).merged({"mode": 13, "life": 0.4}), bolts, land_data, start, window + 0.45, {"fin": 0.01, "fout": 0.05, "priority": 1})
		3:
			root.swarm(K.mesh("crystal"), K.SOLID, {"motion": 2, "hold": 0.55, "glow": Color("f0b0ff"), "rim": 0.8, "shadow": Color("2a0a6a")}, stands, land_data, start, window + 0.95, {"fin": 0.01, "fout": 0.1})
	if q >= 1 and MemoryGuard.pressure == 0:
		root.swarm(K.mesh("quad"), K.VEIL, {"mode": 7, "life": 1.4, "grow": Vector2(0.7, 1.0), "c_core": e.c_core, "c_mid": e.c_mid, "c_edge": e.mark}, marks, land_data, start, window + 1.4, {"fin": 0.01, "fout": 0.05, "priority": -1})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var beats: Array = StarSkillData.GOD_BEATS
	# The hero object outlives the cast by a moment: the last beat is the money shot.
	var total := time + float(beats.back()) + 1.3
	var cast := time + float(beats.back()) + 0.45
	var collapse := time + float(beats[beats.size() - 2]) + 0.1
	var origin := caster.global_position
	GodSkillArt._put(art, "planets", StarSkillArt.look(skill), Vector3(0, 3.1, 0), Vector3.ONE * 0.9, Vector3.ZERO, time, {"initial": 0.06, "grow_time": 0.9, "fade_in": 0.12, "decay": 0.97, "opacity": 0.8, "spectral": 1.0, "spin": 1.2})
	var g := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodGround_" + ID, origin)
	if not g:
		return true
	g.bind(caster, ID, cast, time)
	_star = g.stage(0.0, 1.2, 3.6)
	# The ground opens into space (its bright ragged rim is the area indicator).
	g.add(K.mesh("quad"), K.VEIL, SPACE.merged({"mode": 4, "p1": 0.8}), Vector3.UP * 0.045, Vector3.ONE * r / 0.86, K.FLAT, 0.0, total, {"grow": time * 0.6, "from": 0.04, "fin": 0.2, "fout": 0.5, "priority": -2})
	# The doomed star.
	var born := {"grow": time * 0.8, "from": 0.08, "fin": 0.1, "fout": 0.12, "scale_curve": [0.0, 1.0, collapse - 0.25, 1.0, collapse - 0.05, 1.5, collapse + 0.05, 0.2]}
	g.add(K.mesh("sphere"), K.SUN, STARLIGHT.merged({"flow": 2.0}), _star, Vector3.ONE * 0.75, Vector3.ZERO, 0.0, collapse + 0.05, born)
	g.add(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 2, "billboard": true, "p1": 6.0, "p2": 0.22, "gain": 0.6}), _star, Vector3.ONE * 0.75 * 4.4, Vector3.ZERO, 0.0, collapse + 0.05, born)
	_meteors(g, 0, r, time - FLIGHT - 0.1)
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var s := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodSky_" + ID, origin)
	if not s:
		return true
	s.bind(caster, ID, cast, time)
	# Three tilted orbits with their planets wheel round the star until it collapses.
	var q := K.quality()
	for k in [1, 2, 3][q]:
		var tilt: Vector3 = [Vector3(0.5, 0, 0.2), Vector3(-0.35, 0, 0.6), Vector3(0.2, 0, -0.7)][k]
		s.add(K.mesh("orbit%d" % k), K.SOLID, {"glow": Color("a6f2ff"), "rim": 0.5, "shadow": Color("1a1040")}, _star, Vector3.ONE * [1.7, 2.5, 3.3][k], tilt, 0.0, collapse + 0.3,
			{"grow": time * 0.8, "from": 0.05, "spin": Vector3(0, [1.5, -1.1, 0.8][k], 0), "fin": 0.2, "fout": 0.1, "scale_curve": [0.0, 1.0, collapse, 1.0, collapse + 0.3, 0.05]})
	# Stars drifting up out of the pool.
	var motes := []
	var mote_data := []
	for k in VfxBudget.count(24, 8):
		var seed := K.rand(float(k) * 5.1 + 3.0)
		motes.append(K.card(K.scatter(k, 24, r * 0.9) + Vector3.UP * 0.2, 0.25 + 0.25 * seed))
		mote_data.append(Color(seed * (total - 1.6), seed, 0, 0))
	s.swarm(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 10, "billboard": true, "life": 1.5, "drift": Vector3(0, 0.9, 0), "sway": 0.3}), motes, mote_data, 0.1, total - 0.2)
	return true


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var beats: Array = StarSkillData.GOD_BEATS
	var e: Dictionary = ELEMENTS[index]
	K.layer(art, K.mesh("quad"), K.GLOW, _glow(e).merged({"mode": 1, "p1": 1.2}), _centre(index, r) + Vector3.UP * 0.1, Vector3.ONE * r * 0.55, K.FLAT, 0.6, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.75})
	var gap := float(beats[index + 1]) - float(beats[index])
	if index + 1 < beats.size() - 1:
		var next := K.open(parent, point, 1.0, "GodMeteors_" + ID, source)
		if next:
			_meteors(next, index + 1, r, maxf(0.0, gap - FLIGHT - 0.1))
		return true
	# The held breath: the star is gone, a singularity drinks the light.
	var hole := K.open(parent, point, gap, "GodSingularity_" + ID, source)
	if not hole:
		return true
	var swell := [0.0, 0.15, 0.22, 1.0, gap - 0.1, 0.85, gap, 0.12]
	hole.add(K.mesh("sphere"), K.SUN, {"c_core": Color("eafcff"), "c_mid": Color("8a5cff"), "c_edge": Color("05020e"), "invert": 1.0, "flow": 3.0}, _star, Vector3.ONE * 1.5, Vector3.ZERO, 0.08, gap - 0.06, {"scale_curve": swell, "fin": 0.04, "fout": 0.02})
	hole.add(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 11, "billboard": true, "p1": 16.0, "p2": 0.2, "prism": 1.0, "gain": 0.8}), _star, Vector3.ONE * 6.5, Vector3.ZERO, 0.08, gap - 0.06, {"scale_curve": swell, "fin": 0.05, "fout": 0.03, "priority": -1})
	var streaks := []
	var streak_data := []
	var count: int = [8, 16, 24][K.quality()]
	for k in count:
		var seed := K.rand(float(k) * 3.3 + 1.0)
		var a := float(k) * K.GOLDEN
		var from := Vector3(cos(a) * cos(seed * 1.2 - 0.3), sin(seed * 1.2 - 0.3), sin(a) * cos(seed * 1.2 - 0.3))
		streaks.append(K.falling(_star, -from, 1.2 + seed))
		streak_data.append(Color(0.1 + seed * (gap - 0.42), seed, 0.6 + 0.6 * K.rand(seed * 7.0), 0))
	hole.swarm(K.mesh("shard"), K.SOLID, {"motion": 1, "flight": 0.3, "travel": 9.0, "accelerate": 1.0, "stick": 0.0, "ember": Color("c9a8ff"), "rim": 0.0}, streaks, streak_data, 0.0, gap, {"fin": 0.01, "fout": 0.02})
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var q := K.quality()
	K.layer(art, K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 1, "p1": 1.4, "p2": 1.0, "prism": 1.0, "gain": 0.6}), Vector3.UP * 0.11, Vector3.ONE * r * 1.3, K.FLAT, 0.95, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.8})
	var f := K.open(parent, point, 1.0, "GodFinale_" + ID, source)
	if f:
		# Supernova: a white-hot shell that swells and burns away, a blinding flash, a
		# four-point star, then stardust falling over the whole field.
		f.add(K.mesh("sphere"), K.SUN, {"c_core": Color("d8f4ff"), "c_mid": Color("8ad0ff"), "c_edge": Color("7a4cff"), "flow": 5.0}, _star, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, 0.5, {"grow": 0.2, "from": 0.05, "fin": 0.01, "fout": 0.46})
		f.add(K.mesh("quad"), K.GLOW, {"mode": 10, "billboard": true, "life": 0.9, "prism": 0.5, "gain": 0.7, "c_core": Color("eafaff"), "c_mid": Color("a8e4ff"), "c_edge": Color("9a7cff")}, _star, Vector3.ONE * 8.0, Vector3.ZERO, 0.0, 0.9, {"grow": 0.18, "from": 0.2, "fin": 0.01, "fout": 0.4})
		var dust := []
		var dust_data := []
		var count: int = [16, 34, 54][q]
		for k in count:
			var seed := K.rand(float(k) * 2.9 + 5.0)
			dust.append(K.card(K.scatter(k, count, r * 0.95) + Vector3.UP * (2.5 + seed * 4.0), 0.3 + 0.35 * seed))
			dust_data.append(Color(0.15 + seed * 0.7, seed, 0, 0))
		f.swarm(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 10, "billboard": true, "life": 1.7, "prism": 1.0, "drift": Vector3(0, -1.5, 0), "sway": 0.35}), dust, dust_data, 0.0, 2.6, {"fin": 0.01})
		f.add(K.mesh("quad"), K.GLOW, {"mode": 0, "billboard": true, "p1": 2.4, "gain": 0.36, "c_core": Color("eafaff"), "c_mid": Color("a8e4ff"), "c_edge": Color("9a7cff")}, _star, Vector3.ONE * 5.6, Vector3.ZERO, 0.0, 0.3, {"fin": 0.02, "fout": 0.22})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The shock front: a halo racing out level with the star, and a second ring over the ground.
	var avatar := K.open(parent, point, 1.0, "StarGodAvatar_" + ID, source)
	if avatar:
		avatar.add(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 1, "p1": 0.9, "p2": 1.0, "prism": 1.0, "gain": 0.8}), _star, Vector3.ONE * 7.0, K.FLAT, 0.0, 0.85, {"fin": 0.01})
		avatar.add(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 1, "p1": 0.8, "prism": 0.7, "gain": 0.6}), Vector3.UP * 0.12, Vector3.ONE * r * 1.05, K.FLAT, 0.18, 0.8, {"fin": 0.01})
		avatar.lifetime = maxf(avatar.lifetime, 2.0)
	if extras < 2:
		return true
	# Debris of the star thrown outward, and stars left twinkling in the pool.
	var temple := K.open(parent, point, 1.0, "StarGodTemple_" + ID, source)
	if temple:
		var sparks := []
		var spark_data := []
		for k in 36:
			var seed := K.rand(float(k) * 6.1)
			var a := float(k) * K.GOLDEN
			var out := Vector3(cos(a) * cos(seed * 1.3 - 0.2), sin(seed * 1.3 - 0.2), sin(a) * cos(seed * 1.3 - 0.2))
			sparks.append(K.card(_star + out * 0.6, 0.22 + 0.2 * seed, out))
			spark_data.append(Color(seed * 0.12, seed, 0, 0))
		temple.swarm(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 9, "billboard": true, "life": 1.1, "burst": 26.0, "gravity": 3.0, "grow": Vector2(1.0, 0.4)}), sparks, spark_data, 0.0, 1.3, {"fin": 0.01})
		var twinkles := []
		var twinkle_data := []
		for k in 22:
			var seed := K.rand(float(k) * 4.3 + 8.0)
			twinkles.append(K.card(K.scatter(k, 22, r * 0.9) + Vector3.UP * 0.35, 0.3 + 0.3 * seed))
			twinkle_data.append(Color(0.4 + seed * 0.9, seed, 0, 0))
		temple.swarm(K.mesh("quad"), K.GLOW, STARLIGHT.merged({"mode": 10, "billboard": true, "life": 1.0, "prism": 1.0, "drift": Vector3(0, 0.6, 0)}), twinkles, twinkle_data, 0.0, 2.4, {"fin": 0.01})
	return true
