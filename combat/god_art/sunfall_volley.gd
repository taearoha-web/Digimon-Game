extends RefCounted
## Archer god skill "Sunfall Volley" (ศรเทพสุริยาพิโรธ). Cosmetic only.
## A blazing sun rises over the far side of the field; four volleys of sun arrows rain
## out of it on a slant, each arrow planting itself with a burst of fire and a scorch
## mark; then one colossal dragon-headed arrow dives from the sun into the centre: a
## pillar of fire, a wall of flame rolling out to the rim and embers on the wind.
## Every volley is drawn one beat ahead so that it lands on its own contact.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const ID := "sunfall_volley"
const SUN_SIZE := 1.45
## Where the sun hangs (root space, set by the wind-up): low and to the camera's left of
## the field, because the field camera looks down from high up and anything much higher
## leaves the top of the screen; the arrows then cross the view on a slant.
static var _sun := Vector3(5.0, 4.6, -1.0)
const FLIGHT := 0.2
const FIRE := {"c_core": Color("fffbe0"), "c_mid": Color("ffb42a"), "c_edge": Color("f04c0a")}
const CHAR := {"c_core": Color("fff0a0"), "c_mid": Color("ff7a1a"), "c_edge": Color("1c0d06")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)


static func _centre(j: int, r: float) -> Vector3:
	var a := float(j) * 2.2 + 0.6
	return Vector3(sin(a), 0, cos(a)) * r * [0.46, 0.5, 0.42, 0.0][j]


static func _spread(j: int, r: float) -> float:
	return r * [0.4, 0.4, 0.44, 0.88][j]


## The volley of beat [param j]: arrows from the sun, a fire burst and a scorch per arrow.
static func _volley(root: K, j: int, r: float, start: float) -> void:
	var q := K.quality()
	var n: int = [5, 8, 11][q] + j * [1, 2, 3][q]
	if MemoryGuard.pressure > 0:
		n = mini(n, 6)
	var centre := _centre(j, r)
	var spread := _spread(j, r)
	var arrows := []
	var arrow_data := []
	var bursts := []
	var burst_data := []
	var marks := []
	for k in n:
		var seed := K.rand(float(k) * 3.3 + float(j) * 7.1)
		var spot := centre + K.scatter(k, n, spread, float(j))
		var delay := 0.1 * K.rand(float(k) * 1.9 + float(j))
		var dir := (spot - _sun).normalized()
		arrows.append(K.falling(spot + dir * 0.3, dir, 2.3, seed * TAU))
		arrow_data.append(Color(delay, seed, 0, 0))
		bursts.append(K.card(spot + Vector3.UP * 0.55, 1.2))
		burst_data.append(Color(delay + FLIGHT, seed, 0.8 + 0.5 * seed, 0))
		marks.append(K.lying(spot + Vector3.UP * (0.05 + 0.002 * k), 1.0, seed * TAU))
	var window := FLIGHT + 0.1
	root.swarm(K.mesh("arrow"), K.SOLID, {"motion": 1, "flight": FLIGHT, "travel": 15.0, "hold": 0.8, "stick": 1.0, "glow": Color("ffd24a"), "rim": 0.5, "shadow": Color("8a4a1a")}, arrows, arrow_data, start, window + 0.85, {"fin": 0.01, "fout": 0.1})
	root.swarm(K.mesh("quad"), K.VEIL, FIRE.merged({"mode": 8, "billboard": true, "life": 0.5, "grow": Vector2(0.45, 1.5), "drift": Vector3(0, 1.5, 0)}), bursts, burst_data, start, window + 0.55, {"fin": 0.01, "fout": 0.05, "priority": 1})
	if q >= 1 and MemoryGuard.pressure == 0:
		root.swarm(K.mesh("quad"), K.VEIL, CHAR.merged({"mode": 7, "life": 1.5, "grow": Vector2(0.7, 1.0)}), marks, burst_data, start, window + 1.5, {"fin": 0.01, "fout": 0.05, "priority": -1})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var beats: Array = StarSkillData.GOD_BEATS
	# The hero object outlives the cast by a moment: the last beat is the money shot.
	var total := time + float(beats.back()) + 1.3
	var cast := time + float(beats.back()) + 0.45
	var origin := caster.global_position
	GodSkillArt._put(art, "martial/bow", StarSkillArt.look(skill), Vector3(0, 1.7, 0.5), Vector3.ONE * 1.3, Vector3.ZERO, time, {"initial": 0.06, "grow_time": 0.9, "fade_in": 0.12, "decay": 0.97, "opacity": 0.8})
	var g := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodGround_" + ID, origin)
	if not g:
		return true
	g.bind(caster, ID, cast, time)
	# The sun climbs from the far rim of the field, swells when the great arrow leaves it
	# and burns out after the finale.
	_sun = g.stage(5.0, 1.0, 4.6)
	var low := g.stage(8.0, -2.0, 0.6)
	var fire_at := time + float(beats.back())
	var rise := {"travel": _sun - low, "tw": Vector2(0, time * 0.95), "ease": 2, "grow": time * 0.9, "from": 0.35, "fin": 0.15, "fout": 0.28,
		"scale_curve": [0.0, 1.0, fire_at - 0.5, 1.0, fire_at - 0.22, 1.25, fire_at, 0.95, total - 0.4, 1.0, total, 0.6]}
	g.add(K.mesh("sphere"), K.SUN, FIRE.merged({"flow": 1.0}), low, Vector3.ONE * SUN_SIZE, Vector3.ZERO, 0.0, total - 0.05, rise)
	g.add(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 2, "billboard": true, "p1": 9.0, "p2": 0.3, "gain": 0.6}), low, Vector3.ONE * SUN_SIZE * 3.3, Vector3.ZERO, 0.0, total - 0.05, rise)
	g.add(K.mesh("quad"), K.GLOW, {"mode": 5, "p1": 30.0, "gain": 0.9, "c_core": Color("fff6c0"), "c_mid": Color("ffc23a"), "c_edge": Color("ff8a1a")}, Vector3.UP * 0.07, Vector3.ONE * r, K.FLAT, 0.0, total, {"grow": 0.5, "from": 0.3, "fout": 0.5})
	_volley(g, 0, r, time - FLIGHT - 0.1)
	if not K.lean():
		g.add(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 0, "p1": 1.4, "gain": 0.12}), Vector3.UP * 0.06, Vector3.ONE * r * 0.95, K.FLAT, 0.0, total, {"fin": time, "fout": 0.6})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var s := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodSky_" + ID, origin)
	if not s:
		return true
	s.bind(caster, ID, cast, time)
	# Slow prominences round the sun, a shaft of sunlight onto the field, heat rising.
	s.add(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 2, "billboard": true, "p1": 5.0, "p2": 0.2, "gain": 0.22, "seed": 3.0}), low, Vector3.ONE * SUN_SIZE * 5.2, Vector3.ZERO, 0.0, total - 0.05, rise)
	s.add(K.mesh("shaft"), K.GLOW, {"mode": 3, "p1": 0.5, "p2": 0.3, "gain": 0.2, "c_core": Color("fff6c0"), "c_mid": Color("ffd86a"), "c_edge": Color("ffa22a")}, Vector3.ZERO, Vector3(r * 0.7, _sun.length(), r * 0.7), K.falling(Vector3.ZERO, -_sun, 1.0).basis.get_euler(), time * 0.55, total - time * 0.55 - 0.3, {"fin": 0.5, "fout": 0.4})
	var motes := []
	var mote_data := []
	for k in VfxBudget.count(22, 8):
		var seed := K.rand(float(k) * 5.7)
		motes.append(K.card(K.scatter(k, 22, r * 0.9) + Vector3.UP * (0.2 + seed), 0.14 + 0.12 * seed))
		mote_data.append(Color(seed * (time + 1.0), seed, 0, 0))
	s.swarm(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 9, "billboard": true, "life": 1.6, "drift": Vector3(0, 1.5, 0), "sway": 0.4}), motes, mote_data, 0.2, total - 0.3)
	return true


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var beats: Array = StarSkillData.GOD_BEATS
	# This beat's volley has just landed: the ground flashes under it.
	K.layer(art, K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 1, "p1": 1.1, "gain": 1.0}), _centre(index, r) + Vector3.UP * 0.09, Vector3.ONE * _spread(index, r) * 1.25, K.FLAT, 0.6, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.75})
	var gap := float(beats[index + 1]) - float(beats[index])
	if index + 1 < beats.size() - 1:
		var next := K.open(parent, point, 1.0, "GodVolley_" + ID, source)
		if next:
			_volley(next, index + 1, r, maxf(0.0, gap - FLIGHT - 0.1))
		return true
	# The held breath before the finale: the dragon arrow forms at the sun and dives.
	var d := K.open(parent, point, 1.0, "GodDragonArrow_" + ID, source)
	if not d:
		return true
	# It leaves the sun head first and crosses the view on a slant, its back to the camera.
	var dir := (-_sun).normalized()
	var axis := -dir
	var want := d.toward_camera() * 0.5 + Vector3.UP * 0.85
	var back := (want - axis * want.dot(axis)).normalized()
	var angles := Basis(axis.cross(back), axis, back).get_euler()
	var from := _sun + dir * 1.3
	var dive := 0.2
	var lead := 0.32
	d.add(K.mesh("dragon_arrow"), K.SOLID, {"glow": Color("ffb030"), "rim": 0.35, "shadow": Color("b0480c"), "tint": Color("ffe0a0")}, from, Vector3.ONE * 1.45, angles, maxf(0.0, gap - dive - lead), lead + dive + 0.9,
		{"grow": lead, "from": 0.15, "travel": dir * 0.7 - from, "tw": Vector2(lead, lead + dive), "ease": 1, "fin": 0.05, "fout": 0.4, "priority": 2,
		"curves": {"heat": [0.0, 0.6, lead * 0.8, 0.0, lead + dive, 0.0, lead + dive + 0.05, 0.5, lead + dive + 0.4, 0.0]}})
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var q := K.quality()
	K.layer(art, K.mesh("quad"), K.VEIL, CHAR.merged({"mode": 7, "seed": 2.0}), Vector3.UP * 0.06, Vector3.ONE * r * 0.8, K.FLAT, 1.9, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.9, "priority": -1})
	var f := K.open(parent, point, 1.0, "GodFinale_" + ID, source)
	if f:
		# Pillar of fire with a white-hot heart, a wall of flame rolling to the rim.
		f.add(K.mesh("column"), K.VEIL, FIRE.merged({"mode": 14, "p1": 5.0, "p2": 2.2}), Vector3.ZERO, Vector3(1.9, 12.5, 1.9), Vector3.ZERO, 0.0, 1.15, {"grow": 0.12, "from": 0.35, "to": Vector3(0.4, 1.1, 0.4), "fin": 0.02, "fout": 0.55})
		f.add(K.mesh("column"), K.VEIL, FIRE.merged({"mode": 14, "p1": 3.2, "p2": 7.0, "seed": 5.0}), Vector3.ZERO, Vector3(r * 1.04, 2.8, r * 1.04), Vector3.ZERO, 0.02, 1.0, {"grow": 0.8, "from": 0.1, "fin": 0.03, "fout": 0.4})
		f.add(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 1, "p1": 1.2, "p2": 1.0}), Vector3.UP * 0.1, Vector3.ONE * r * 1.25, K.FLAT, 0.0, 0.85, {"fin": 0.01})
		f.add(K.mesh("column"), K.GLOW, {"mode": 3, "p1": 8.0, "p2": 0.3, "gain": 0.7, "c_core": Color.WHITE, "c_mid": Color("fff3b0"), "c_edge": Color("ffc23a")}, Vector3.ZERO, Vector3(0.6, 13.5, 0.6), Vector3.ZERO, 0.0, 0.8, {"to": Vector3(0.15, 1.0, 0.15), "fin": 0.02, "fout": 0.35})
		f.add(K.mesh("quad"), K.GLOW, {"mode": 0, "billboard": true, "p1": 1.9, "gain": 0.6, "c_core": Color.WHITE, "c_mid": Color("fff0a0"), "c_edge": Color("ffb42a")}, Vector3.UP * 1.6, Vector3.ONE * 6.0, Vector3.ZERO, 0.0, 0.3, {"fin": 0.02, "fout": 0.22})
		var embers := []
		var ember_data := []
		var count: int = [14, 30, 48][q]
		for k in count:
			var seed := K.rand(float(k) * 2.3)
			var out := K.scatter(k, count, r * 0.85)
			embers.append(K.card(out * 0.35 + Vector3.UP * (0.3 + seed * 1.6), 0.16 + 0.16 * seed, (out.normalized() + Vector3.UP * (0.6 + seed)).normalized()))
			ember_data.append(Color(seed * 0.45, seed, 0, 0))
		f.swarm(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 9, "billboard": true, "life": 1.9, "drift": Vector3(0.3, 1.1, 0), "sway": 0.5, "burst": 9.0, "grow": Vector2(1.0, 0.5)}), embers, ember_data, 0.0, 2.35, {"fin": 0.01})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The sun answers: a flare bursts from it and fires spring up where the flame wall passes.
	var avatar := K.open(parent, point, 1.0, "StarGodAvatar_" + ID, source)
	if avatar:
		avatar.add(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 2, "billboard": true, "p1": 14.0, "p2": 0.18, "gain": 0.5, "seed": 7.0}), _sun, Vector3.ONE * SUN_SIZE * 6.5, Vector3.ZERO, 0.0, 0.75, {"grow": 0.2, "from": 0.4, "fin": 0.02, "fout": 0.5, "priority": -1})
		var fires := []
		var fire_data := []
		var count: int = [8, 12, 18][q]
		for k in count:
			var seed := K.rand(float(k) * 4.1 + 1.0)
			var a := TAU * float(k) / float(count)
			var d := r * (0.5 + 0.45 * K.rand(float(k) * 1.3))
			fires.append(K.card(Vector3(sin(a), 0, cos(a)) * d + Vector3.UP * 0.8, 1.3 + seed * 0.7))
			fire_data.append(Color(0.75 * d / r + seed * 0.5, seed, 0, 0))
		avatar.swarm(K.mesh("quad"), K.VEIL, FIRE.merged({"mode": 8, "billboard": true, "life": 0.75, "grow": Vector2(0.5, 1.3), "drift": Vector3(0, 1.8, 0)}), fires, fire_data, 0.0, 2.1, {"fin": 0.01})
	if extras < 2:
		return true
	# Glowing fissures and a second breath of embers.
	var temple := K.open(parent, point, 1.0, "StarGodTemple_" + ID, source)
	if temple:
		var marks := []
		var mark_data := []
		for k in 7:
			var seed := K.rand(float(k) * 6.3)
			var a := TAU * float(k) / 7.0 + 0.4
			marks.append(K.lying(Vector3(sin(a), 0, cos(a)) * r * 0.62 + Vector3.UP * (0.045 + 0.002 * k), r * 0.3, seed * TAU))
			mark_data.append(Color(0.3 + seed * 0.2, seed, 0, 0))
		temple.swarm(K.mesh("quad"), K.VEIL, CHAR.merged({"mode": 7, "life": 1.6, "grow": Vector2(0.6, 1.0)}), marks, mark_data, 0.0, 2.2, {"fin": 0.01, "priority": -1})
		var sparks := []
		var spark_data := []
		for k in 26:
			var seed := K.rand(float(k) * 3.9 + 2.0)
			sparks.append(K.card(K.scatter(k, 26, r) + Vector3.UP * 0.3, 0.14 + 0.14 * seed))
			spark_data.append(Color(0.5 + seed * 0.8, seed, 0, 0))
		temple.swarm(K.mesh("quad"), K.GLOW, FIRE.merged({"mode": 9, "billboard": true, "life": 1.3, "drift": Vector3(0.3, 2.0, 0), "sway": 0.6}), sparks, spark_data, 0.0, 2.4, {"fin": 0.01})
	return true
