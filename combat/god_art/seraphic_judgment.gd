extends RefCounted
## Priest god skill "Seraphic Judgment" (พิพากษาแห่งเทวทูต). Cosmetic only.
## A seraph (a robed figure of light with six feathered wings, a halo, a staff and the
## scales of judgement) descends over the field with its wings half folded. Pillars of
## holy light come down wave after wave among drifting feathers, and each wave a soft
## green-gold ripple of healing washes over the caster's side. On the last beat the seraph
## spreads all six wings: a cross of light burns on the ground under a great pillar and
## feathers rain over the field. White, gold and sky blue: serene, never fiery.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const ID := "seraphic_judgment"
## The seraph's feet (root space, set by the wind-up): low over the field and a little
## towards the camera, because the field camera looks down from high up.
static var _hover := Vector3(0, 1.7, -1.6)
const SIZE := 0.95
const HOLY := {"c_core": Color.WHITE, "c_mid": Color("fff1bd"), "c_edge": Color("ffd166")}
## Pillars are alpha blended so that light on light stays gold instead of burning white.
const GILT := {"c_core": Color("fffdf0"), "c_mid": Color("ffe9a0"), "c_edge": Color("ffc84a")}
const AZURE := {"c_core": Color.WHITE, "c_mid": Color("d9f0ff"), "c_edge": Color("8ecbff")}
const HEAL := {"c_core": Color("f6ffe0"), "c_mid": Color("b9f28c"), "c_edge": Color("ffe07a")}
const PLUME := {"motion": 3, "glow": Color("fff2c0"), "rim": 0.5, "shadow": Color("8ab4e8")}


static func _radius(skill: Dictionary) -> float:
	return clampf(float(skill.get("radius", 9.0)), 4.0, 10.0)


static func _spots(index: int, r: float) -> Array:
	var count: int = [1, 2, 2, 3][index]
	if K.lean():
		count = 1
	var out := []
	for k in count:
		var a := float(index) * 1.9 + float(k) * TAU / float(count) + 0.7
		out.append(Vector3(sin(a), 0, cos(a)) * r * (0.5 if count > 1 else 0.42))
	return out


## Feathers drifting down round [param spots].
static func _feathers(root: K, spots: Array, count: int, spread: float, height: float, hold: float, start: float, stagger: float) -> void:
	var plumes := []
	var plume_data := []
	for k in count:
		var seed := K.rand(float(k) * 3.7 + spread)
		var spot: Vector3 = spots[k % spots.size()]
		plumes.append(K.standing(spot + K.scatter(k, count, spread, seed) + Vector3.UP * (height * (0.45 + 0.55 * seed)), Vector3.ONE * (1.0 + 0.7 * seed), seed * TAU))
		plume_data.append(Color(seed * stagger, seed, 0, 0))
	root.swarm(K.mesh("feather"), K.SOLID, PLUME.merged({"hold": hold, "drift": Vector3(0.15, -height * 0.55 / hold, 0), "sway": 0.45, "tumble": 2.4}), plumes, plume_data, start, hold + stagger + 0.05, {"fin": 0.01, "fout": 0.05})


## The healing that washes over the caster's side: soft green-gold rings and rising motes.
static func _heal(parent: Node3D, source: Vector3, size: float) -> void:
	var at := Vector3(source.x, 0, source.z)
	var h := K.open(parent, at, 0.8, "GodHeal_" + ID, at)
	if not h:
		return
	h.add(K.mesh("quad"), K.GLOW, HEAL.merged({"mode": 1, "p1": 1.5, "p2": 1.0, "gain": 0.5}), Vector3.UP * 0.08, Vector3.ONE * size, K.FLAT, 0.0, 0.95, {"fin": 0.02})
	if K.lean():
		return
	var motes := []
	var mote_data := []
	for k in 6:
		var seed := K.rand(float(k) * 2.1 + size)
		motes.append(K.card(K.scatter(k, 6, size * 0.45) + Vector3.UP * (0.4 + seed), 0.22 + 0.12 * seed))
		mote_data.append(Color(seed * 0.3, seed, 0, 0))
	h.swarm(K.mesh("quad"), K.GLOW, HEAL.merged({"mode": 12, "billboard": true, "life": 0.9, "drift": Vector3(0, 1.7, 0), "sway": 0.15}), motes, mote_data, 0.0, 1.25, {"fin": 0.01})


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D
	var r := _radius(skill)
	var beats: Array = StarSkillData.GOD_BEATS
	# The hero object outlives the cast by a moment: the last beat is the money shot.
	var total := time + float(beats.back()) + 1.3
	var cast := time + float(beats.back()) + 0.45
	var fire := time + float(beats.back())
	var origin := caster.global_position
	GodSkillArt._put(art, "plumes", StarSkillArt.look(skill), Vector3.UP * 0.2, Vector3(1.6, 2.6, 1.6), Vector3.ZERO, time, {"travel": Vector3.UP * 1.2, "decay": 0.8, "initial": 0.7, "veil": 0.7})
	var g := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodGround_" + ID, origin)
	if not g:
		return true
	g.bind(caster, ID, cast, time)
	_hover = g.stage(0.0, 1.6, 1.7)
	# The seraph comes down with its wings half folded and opens them wide on the last beat.
	var fall := Vector3(0, -8.5, 0)
	var descend := {"travel": fall, "tw": Vector2(0, time * 0.92), "ease": 2, "bob": 0.1, "fin": 0.3, "fout": 0.45}
	g.add(K.mesh("quad"), K.VEIL, GILT.merged({"mode": 2, "billboard": true, "p1": 12.0, "p2": 0.1, "gain": 0.5}), _hover - fall + Vector3.UP * 3.0 * SIZE, Vector3.ONE * 4.6, Vector3.ZERO, 0.0, total, descend.merged({"priority": -1}))
	g.add(K.mesh("seraph"), K.SOLID, {"glow": Color("fff2c0"), "rim": 0.45, "shadow": Color("86b6ee"), "flap_rate": 3.4}, _hover - fall, Vector3.ONE * SIZE, Vector3.ZERO, 0.0, total, descend.merged({"yaw_cam": true, "priority": 4,
		"curves": {"spread": [0.0, 0.2, time * 0.9, 0.55, fire - 0.3, 0.4, fire + 0.1, 1.0], "flap": [0.0, 0.16, time, 0.1, fire - 0.2, 0.1, fire, 0.0, fire + 0.35, 0.05], "heat": [0.0, 0.5, 0.5, 0.0, fire - 0.05, 0.0, fire + 0.07, 0.35, fire + 0.4, 0.0]}}))
	g.add(K.mesh("quad"), K.GLOW, {"mode": 5, "p1": 24.0, "gain": 0.9, "c_core": Color.WHITE, "c_mid": Color("fff1bd"), "c_edge": Color("9fd4ff")}, Vector3.UP * 0.07, Vector3.ONE * r, K.FLAT, 0.0, total, {"grow": 0.5, "from": 0.3, "fout": 0.5})
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var s := K.open(parent, Vector3(point.x, 0, point.z), total, "StarGodSky_" + ID, origin)
	if not s:
		return true
	s.bind(caster, ID, cast, time)
	# Light from above onto the field, and the first feathers shaken loose.
	s.add(K.mesh("shaft"), K.GLOW, HOLY.merged({"mode": 3, "p1": -0.5, "p2": 0.3, "gain": 0.1}), Vector3.ZERO, Vector3(r * 0.75, 10.0, r * 0.75), Vector3.ZERO, time * 0.3, total - time * 0.3 - 0.1, {"fin": 0.5, "fout": 0.4})
	_feathers(s, [_hover + Vector3.UP * 1.5], VfxBudget.count(14, 5), 3.2, 4.0, 2.0, time * 0.5, total - time * 0.5 - 2.1)
	return true


static func wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var q := K.quality()
	var spots := _spots(index, r)
	K.layer(art, K.mesh("quad"), K.GLOW, HOLY.merged({"mode": 0, "p1": 1.6, "gain": 0.5}), (spots[0] as Vector3) + Vector3.UP * 0.09, Vector3.ONE * 3.4, K.FLAT, 0.5, {"initial": 0.6, "grow_time": 0.2, "fade_in": 0.01, "decay": 0.4})
	var w := K.open(parent, point, 1.0, "GodPillars_" + ID, source)
	if w:
		var pillars := []
		var cores := []
		var rings := []
		var data := []
		var wide := 0.6 + 0.08 * float(index)
		for k in spots.size():
			var spot: Vector3 = spots[k]
			var seed := K.rand(float(k) * 2.3 + float(index))
			pillars.append(K.standing(spot, Vector3(wide, 11.0, wide), seed * TAU))
			cores.append(K.standing(spot, Vector3(wide * 0.38, 11.5, wide * 0.38), seed * TAU))
			rings.append(K.lying(spot + Vector3.UP * (0.08 + 0.002 * k), 3.0 + 0.4 * float(index)))
			data.append(Color(0.07 * float(k), seed, 0, 0))
		w.swarm(K.mesh("column"), K.VEIL, GILT.merged({"mode": 3, "p1": -6.0, "p2": 0.35, "gain": 1.3, "life": 0.75}), pillars, data, 0.0, 0.75 + 0.07 * spots.size(), {"fin": 0.01, "fout": 0.05})
		w.swarm(K.mesh("quad"), K.GLOW, HOLY.merged({"mode": 1, "p1": 0.9, "p2": 1.0, "gain": 0.7, "life": 0.6}), rings, data, 0.0, 0.6 + 0.07 * spots.size(), {"fin": 0.01, "fout": 0.05})
		_feathers(w, spots, [3, 6, 9][q], 1.6, 4.5, 1.5, 0.05, 0.3)
		if q >= 1 and MemoryGuard.pressure == 0:
			w.swarm(K.mesh("column"), K.GLOW, {"mode": 3, "p1": -9.0, "p2": 0.3, "gain": 0.6, "life": 0.55, "c_core": Color.WHITE, "c_mid": Color.WHITE, "c_edge": Color("fff1bd")}, cores, data, 0.0, 0.55 + 0.07 * spots.size(), {"fin": 0.01, "fout": 0.05})
	_heal(parent, source, 3.6 + 0.4 * float(index))
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := _radius(skill)
	var q := K.quality()
	K.layer(art, K.mesh("quad"), K.VEIL, GILT.merged({"mode": 6, "p1": 0.16, "p2": 6.0, "gain": 1.2}), Vector3.UP * 0.1, Vector3.ONE * r, Vector3(-PI / 2, PI, 0), 1.9, {"initial": 1.0, "grow_time": 0.01, "fade_in": 0.01, "decay": 0.72, "priority": 3})
	var f := K.open(parent, point, 1.0, "GodFinale_" + ID, source)
	if f:
		# The great pillar where the cross meets, a calm ring of light, a rain of feathers.
		var heart := Vector3(0, 0, r * 0.3)
		f.add(K.mesh("column"), K.VEIL, GILT.merged({"mode": 3, "p1": -5.0, "p2": 0.3, "gain": 1.3}), heart, Vector3(1.3, 12.0, 1.3), Vector3.ZERO, 0.0, 1.3, {"to": Vector3(0.5, 1.0, 0.5), "fin": 0.02, "fout": 0.5})
		f.add(K.mesh("quad"), K.GLOW, AZURE.merged({"mode": 1, "p1": 0.7, "gain": 0.45}), Vector3.UP * 0.11, Vector3.ONE * r * 1.25, K.FLAT, 0.0, 1.0, {"fin": 0.01})
		_feathers(f, [Vector3.ZERO], [12, 26, 40][q], r * 0.9, 7.0, 2.2, 0.0, 0.5)
		f.add(K.mesh("column"), K.GLOW, {"mode": 3, "p1": -8.0, "p2": 0.3, "gain": 1.0, "c_core": Color.WHITE, "c_mid": Color.WHITE, "c_edge": Color("fff1bd")}, heart, Vector3(0.5, 12.5, 0.5), Vector3.ZERO, 0.0, 0.9, {"to": Vector3(0.2, 1.0, 0.2), "fin": 0.02, "fout": 0.4})
	_heal(parent, source, 5.5)
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# Glory behind the seraph as its wings open.
	var avatar := K.open(parent, point, 1.0, "StarGodAvatar_" + ID, source)
	if avatar:
		var chest := _hover + Vector3.UP * 3.0 * SIZE
		avatar.add(K.mesh("quad"), K.VEIL, GILT.merged({"mode": 2, "billboard": true, "p1": 16.0, "p2": 0.08, "gain": 0.7, "seed": 4.0}), chest, Vector3.ONE * 8.0, Vector3.ZERO, 0.0, 1.8, {"grow": 0.3, "from": 0.25, "fin": 0.03, "fout": 0.8, "priority": -1})
		avatar.add(K.mesh("quad"), K.GLOW, AZURE.merged({"mode": 1, "billboard": true, "p1": 0.5, "gain": 0.35}), chest, Vector3.ONE * 7.0, Vector3.ZERO, 0.05, 0.9, {"fin": 0.01, "priority": -1})
	if extras < 2:
		return true
	# Lesser pillars at the ends of the cross and motes of light rising from it.
	var temple := K.open(parent, point, 1.0, "StarGodTemple_" + ID, source)
	if temple:
		var ends := []
		var end_data := []
		var k := 0
		for at in [Vector3(0, 0, r * 0.9), Vector3(0, 0, -r * 0.9), Vector3(r * 0.58, 0, r * 0.3), Vector3(-r * 0.58, 0, r * 0.3)]:
			ends.append(K.standing(at, Vector3(0.7, 9.0, 0.7)))
			end_data.append(Color(0.12 + 0.08 * k, K.rand(float(k)), 0, 0))
			k += 1
		temple.swarm(K.mesh("column"), K.VEIL, GILT.merged({"mode": 3, "p1": -6.0, "p2": 0.35, "gain": 1.2, "life": 0.9}), ends, end_data, 0.0, 1.4, {"fin": 0.01})
		var motes := []
		var mote_data := []
		for j in 30:
			var seed := K.rand(float(j) * 3.1 + 2.0)
			var along := (seed * 2.0 - 1.0) * r * 0.9
			var at := Vector3(0, 0.3, along) if j % 3 > 0 else Vector3(along * 0.6, 0.3, r * 0.3)
			motes.append(K.card(at, 0.25 + 0.2 * seed))
			mote_data.append(Color(0.2 + K.rand(seed * 5.0) * 1.0, seed, 0, 0))
		temple.swarm(K.mesh("quad"), K.GLOW, HOLY.merged({"mode": 10, "billboard": true, "life": 1.1, "drift": Vector3(0, 1.4, 0), "sway": 0.2}), motes, mote_data, 0.0, 2.4, {"fin": 0.01})
	return true
