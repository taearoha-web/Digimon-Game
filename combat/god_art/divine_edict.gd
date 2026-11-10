extends RefCounted
## Warrior god skill "ดาบเทพประกาศิต" (divine_edict): the god-sword's edict.
## Wind-up: clouds part over the target and the point of a colossal sword shows through,
## its shadow growing on the ground. Four waves of blades rain down, each in its own
## formation (fan, ring, cross, spiral), and stay planted, glowing, in cracked ground.
## Finale: the mountain of a sword falls out of the clouds into the centre: shockwave,
## fissures of gold light, thrown rock and a lion's roar. Gold, white steel and crimson.
const K := preload("res://combat/god_art/_kit_melee.gd")
const GOLD := Color("ffc23a")
const PALE := Color("fff3c8")
const CRIMSON := Color("d3152c")
const STEEL := Color("a3b4dc")
const ROCK := Color("6b5a4c")
const ID := "divine_edict"
const SWORD := 3.6
## The god-sword's length: its guard stays inside the third-person camera's frame.
const GIANT := 8.0
const CREVICE := Color(0.2, 0.08, 0.02, 1.0)
static var _cache := {}


## The god-sword: point on the origin, +Y up, 1 long. Steel blade with a glowing gold
## fuller, winged gold guard with a crimson gem, crimson grip, gold pommel.
static func _sword() -> K.Part:
	if _cache.has("part"):
		return _cache.part
	var p := K.Part.new()
	p.ink(STEEL, 1.0)
	p.tube(Vector3.ZERO, Vector3(0, 0.17, 0), 0.0, 0.085, 6, 0.2, false)
	p.tube(Vector3(0, 0.17, 0), Vector3(0, 0.72, 0), 0.085, 0.068, 6, 0.2, false)
	p.ink(GOLD, 0.0, 1.0)
	p.box(Vector3(0, 0.45, 0), Vector3(0.02, 0.5, 0.042))
	# Runes of the edict cut across the fuller.
	for i in 5:
		p.box(Vector3(0, 0.26 + 0.09 * float(i), 0), Vector3(0.05 if i % 2 == 0 else 0.036, 0.012, 0.04))
	p.ink(GOLD, 0.9)
	p.box(Vector3(0, 0.735, 0), Vector3(0.13, 0.05, 0.07))
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.05, 0.735, 0), Vector3(s * 0.2, 0.705, 0), 0.032, 0.02, 5, 0.7)
		p.tube(Vector3(s * 0.2, 0.705, 0), Vector3(s * 0.26, 0.63, 0), 0.02, 0.0, 5, 0.7)
		p.tube(Vector3(s * 0.07, 0.75, 0), Vector3(s * 0.19, 0.83, 0), 0.026, 0.0, 4, 0.5)
		p.tube(Vector3(s * 0.05, 0.75, 0), Vector3(s * 0.11, 0.86, 0), 0.02, 0.0, 4, 0.5)
	p.ink(CRIMSON, 0.7, 0.6)
	p.gem(Vector3(0, 0.735, 0), Vector3(0.04, 0.05, 0.05))
	p.ink(Color("6a1020"), 0.15)
	p.tube(Vector3(0, 0.76, 0), Vector3(0, 0.925, 0), 0.022, 0.018, 6)
	p.ink(GOLD, 0.9)
	p.tube(Vector3(0, 0.84, 0), Vector3(0, 0.855, 0), 0.027, 0.027, 6)
	p.gem(Vector3(0, 0.96, 0), Vector3(0.045, 0.05, 0.045))
	_cache.part = p
	return p


static func _giant() -> ArrayMesh:
	if not _cache.has("giant"):
		var st := K.begin()
		K.stamp(st, _sword())
		_cache.giant = K.finish(st, Vector3(0.5, 4.0, 0.5))
	return _cache.giant


## Where the blades of a wave land: fan, ring, cross, spiral. [x, z, yaw, lean].
static func _formation(index: int, r: float) -> Array:
	var out := []
	match index % 4:
		0:
			for i in 7:
				var a := (float(i) - 3.0) * 0.36
				out.append([sin(a) * r * 0.62, cos(a) * r * 0.62 - r * 0.12, a, 0.16])
		1:
			for i in 8:
				var a := TAU * float(i) / 8.0 + 0.39
				out.append([sin(a) * r * 0.56, cos(a) * r * 0.56, a, 0.1])
		2:
			for i in 8:
				var a := PI / 4.0 + PI / 2.0 * float(i % 4)
				var d := r * (0.42 if i < 4 else 0.8)
				out.append([sin(a) * d, cos(a) * d, a, 0.05])
		3:
			for i in 10:
				var a := float(i) * 0.85 + 1.0
				var d := r * (0.3 + 0.06 * float(i))
				out.append([sin(a) * d, cos(a) * d, a, 0.12])
	return out


## One wave: [swords SOLID, light FLAT (trails, landing flash, cracks), rock BITS].
static func _wave_meshes(index: int, r: float) -> Array:
	var key := "wave%d" % (index % 4)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + index
	var spots := _formation(index, r)
	var solid := K.begin()
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flight := 0.2
	for i in spots.size():
		var s: Array = spots[i]
		var at := Vector3(s[0], 0, s[1])
		var delay := 0.03 * float(i)
		var length := SWORD * rng.randf_range(0.85, 1.12)
		# Leaning out from the centre, a little askew, sunk a hand into the ground.
		var basis := Basis.from_euler(Vector3(float(s[3]) + rng.randf_range(-0.07, 0.07), float(s[2]), rng.randf_range(-0.08, 0.08))) * Basis.from_euler(Vector3(0, rng.randf() * PI, 0))
		K.stamp(solid, _sword(), Transform3D(basis.scaled(Vector3.ONE * length), at + Vector3.DOWN * length * 0.13), delay, 1.0)
		K.beam(flat, at + Vector3.UP * length * 0.5, 7.0, 0.55, Color(GOLD.r, GOLD.g, GOLD.b, 0.75), 2, delay, 1.0, 0.1)
		K.disc(flat, 1.6, Color(1.0, 0.9, 0.55, 0.95), 0.07, 14, delay + flight, Vector3.UP, at, Color(GOLD.r, GOLD.g, GOLD.b, 0.0), -1.0)
		K.crack_star(flat, rng, at + Vector3.UP * 0.05, 5, 0.1, 1.8, 0.2, CREVICE, delay + flight, 1, 0.25)
		K.burst_at(bits, rng, "rock", 5, at, 0.1, 0.5, 3.4, 5.5, [ROCK, ROCK.lightened(0.15), ROCK.darkened(0.2)], 0.3, delay + flight, 0.03)
		K.burst_at(bits, rng, "ember", 4, at, 0.1, 0.4, 2.0, 6.5, [GOLD, PALE], 0.14, delay + flight, 0.05)
	_cache[key] = [K.finish(solid, Vector3(0.5, 16.0, 0.5)), K.finish(flat, Vector3(0.5, 16.0, 0.5), false), K.finish(bits, Vector3(8, 8, 8), false)]
	return _cache[key]


## A ring of cloud with a hole in the middle (the sword comes through it).
static func _clouds() -> ArrayMesh:
	if not _cache.has("clouds"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var st := K.begin(true)
		var p := K.Part.new()
		for i in 13:
			var a := TAU * float(i) / 13.0 + rng.randf_range(-0.12, 0.12)
			var d := rng.randf_range(0.62, 0.9)
			var size := rng.randf_range(0.26, 0.4)
			p.ink(Color("fffaf0").lerp(Color("ffd9a0"), rng.randf() * 0.5))
			var at := Vector3(sin(a) * d, rng.randf_range(-0.04, 0.04), cos(a) * d)
			p.ball(at, Vector3(size, size * 0.42, size), 9, 5)
			p.ball(at + Vector3(rng.randf_range(-0.15, 0.15), size * 0.25, rng.randf_range(-0.15, 0.15)), Vector3(size, size * 0.42, size) * 0.6, 8, 4)
		K.stamp(st, p)
		_cache.clouds = K.finish(st, Vector3.ONE * 0.2)
	return _cache.clouds


## Shafts of light falling from the gap in the clouds.
static func _rays() -> ArrayMesh:
	if not _cache.has("rays"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 7:
			var a := TAU * float(i) / 7.0
			var foot := Vector3(sin(a), 0, cos(a)) * rng.randf_range(0.15, 0.55)
			var top := Vector3(sin(a), 0, cos(a)) * 0.12 + Vector3.UP
			var side := Vector3(cos(a), 0, -sin(a))
			var w := rng.randf_range(0.1, 0.2)
			var color := Color(1.0, 0.86, 0.5, rng.randf_range(0.3, 0.5))
			K.ribbon(st, PackedVector3Array([foot, foot.lerp(top, 0.5), top]), w, color, 0.0, 0.0, side.cross(Vector3.UP).normalized(), 0.0)
		_cache.rays = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.rays


## The lion's roar: rings of sound and spikes of light, in the XY plane (faces the camera).
static func _roar() -> ArrayMesh:
	if not _cache.has("roar"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in 3:
			var radius := 0.45 + 0.27 * float(k)
			var pts := PackedVector3Array()
			for i in 41:
				var a := TAU * float(i) / 40.0
				pts.append(Vector3(sin(a) * radius, cos(a) * radius, 0))
			K.ribbon(st, pts, 0.09 - 0.02 * float(k), Color(GOLD.r, GOLD.g, GOLD.b, 0.9 - 0.2 * float(k)), 0.07 * float(k), 0.0, Vector3.BACK, 0.0)
		for i in 16:
			var a := TAU * float(i) / 16.0
			var dir := Vector3(sin(a), cos(a), 0)
			var reach := 1.25 if i % 2 == 0 else 0.95
			K.ribbon(st, PackedVector3Array([dir * 0.3, dir * (0.3 + reach) * 0.6, dir * reach]), 0.1, Color(PALE.r, PALE.g, PALE.b, 0.8), 0.0, 0.0, Vector3.BACK, 1.0)
		_cache.roar = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.roar


static func _gold(alpha: float, mix := 0.0) -> Color:
	var c := GOLD.lerp(PALE, mix)
	return Color(c.r, c.g, c.b, alpha)


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := K.radius(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The caster: the edict's light stands over the raised blade.
	if not _cache.has("edict"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.beam(st, Vector3.ZERO, 1.0, 0.16, _gold(0.85), 2, 0.0, 0.0, 0.02)
		K.disc(st, 0.3, _gold(0.6), 0.02, 20)
		_cache.edict = K.finish(st, Vector3.ONE * 0.2, false)
	K.put(art, K.FLAT, _cache.edict, "EdictLight", Vector3.UP * 0.05, Vector3(5.0, 7.0, 5.0), time, {"soft": 1.6, "flick": 0.08, "hot": Color(1, 0.97, 0.8, 0.8), "add": 0.6}, {"initial": 0.15, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.9})
	var ground := K.extra(parent, Vector3(point.x, 0, point.z), time, "StarGodGround_" + ID, origin, art)
	if ground:
		# The hit area, and the shadow of what is coming down.
		K.put(ground, K.FLAT, K.area_ring("edict_area", _gold(1.0)), "EdictArea", Vector3.UP * 0.07, Vector3.ONE * r, time + 0.25, {"soft": 0.5, "hot": Color(1, 0.95, 0.7, 0.8), "core": 0.5, "add": 0.3}, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.1, "spin": 0.25, "decay": 0.9})
		K.put(ground, K.FLAT, K.glow_disc("edict_shadow", Color(0.07, 0.03, 0.0, 0.7)), "EdictShadow", Vector3.UP * 0.05, Vector3.ONE * 3.6, time + 0.1, {"soft": 0.8, "add": 0.0}, {"initial": 0.15, "grow_time": 0.95, "fade_in": 0.25, "decay": 0.94})
		K.put(ground, K.FLAT, K.cracks("edict_omen", 7, 0.3, 1.0, 0.09, CREVICE, 5, 1), "EdictOmen", Vector3.UP * 0.06, Vector3.ONE * r * 0.5, time, {"soft": 0.4, "sweep": time * 0.9, "flick": 0.15, "hot": _gold(1.0), "core": 0.3, "add": 0.5}, {"fade_in": 0.05, "decay": 0.92})
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.extra(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		K.put(sky, K.SOLID, _clouds(), "EdictClouds", Vector3.UP * 8.6, Vector3(7.5, 5.0, 7.5), time + 0.5, {"rim_color": GOLD, "rim": 0.4}, {"initial": 0.3, "grow_time": 0.6, "fade_in": 0.3, "spin": 0.35, "decay": 0.85})
		# Only the point shows through the gap; it sinks a little as the edict is spoken.
		K.put(sky, K.SOLID, _giant(), "EdictOmenSword", Vector3.UP * 7.0, Vector3(GIANT * 2.1, GIANT, GIANT * 2.1), time, {"rim_color": GOLD, "rim": 0.5, "glow_color": PALE}, {"fade_in": 0.25, "travel": Vector3.DOWN * 2.2, "decay": 0.97, "spin": 0.5})
		K.put(sky, K.FLAT, _rays(), "EdictRays", Vector3.UP * 0.1, Vector3(r * 0.8, 8.6, r * 0.8), time + 0.3, {"soft": 1.4, "flow": 0.6, "gain": 1.0, "add": 0.45}, {"fade_in": 0.4, "spin": -0.2, "decay": 0.8})
		sky._draw()
	return true


static func wave(art: StarSkillArt, _parent: Node3D, skill: Dictionary, index: int, _point: Vector3, _source: Vector3) -> bool:
	var r := K.radius(skill)
	var meshes := _wave_meshes(index, r)
	# The blades stay planted until the great sword has fallen.
	var stay := (1.5 - 0.32 * float(index)) + 1.7
	K.put(art, K.SOLID, meshes[0], "EdictBlades", Vector3.ZERO, Vector3.ONE, stay, {"drop": 15.0, "flight": 0.2, "heat": 0.7, "rim_color": GOLD, "rim": 0.55, "glow_color": Color("ffd870")}, {"decay": 0.88})
	K.put(art, K.FLAT, meshes[1], "EdictBladeLight", Vector3.ZERO, Vector3.ONE, stay, {"drop": 15.0, "flight": 0.2, "after": 0.14, "flash": 0.3, "sweep": 0.2, "soft": 0.5, "hot": Color(1, 0.86, 0.4, 1.0), "core": 0.3, "flick": 0.1, "add": 0.55}, {"decay": 0.75})
	K.put(art, K.BITS, meshes[2], "EdictBladeRubble", Vector3.ZERO, Vector3.ONE, 1.5, {"life": 1.1, "gravity": 17.0, "piece": 0.3, "floor_y": 0.06, "shrink": 0.75, "hot": Color(1.0, 0.7, 0.25, 0.5)}, {"decay": 0.9})
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := K.radius(skill)
	var flight := 0.24
	var size := Vector3(GIANT * 2.1, GIANT, GIANT * 2.1)
	# The mountain of a sword: out of the clouds, into the centre, to stay.
	K.put(art, K.SOLID, _giant(), "EdictGodSword", Vector3.DOWN * GIANT * 0.13, size, 2.5, {"drop": 30.0 / GIANT, "flight": flight, "heat": 0.6, "rim_color": GOLD, "rim": 0.4, "glow_color": Color("ffd060")}, {"decay": 0.82}, Vector3(0.05, 0.6, 0.04))
	K.put(art, K.FLAT, K.cracks("edict_fissures", 9, 0.1, 1.0, 0.055, CREVICE, 11, 1, 0.3), "EdictFissures", Vector3.UP * 0.07, Vector3.ONE * r * 1.05, 2.4, {"sweep": 0.3, "soft": 0.35, "hot": Color(1, 0.9, 0.5, 1.0), "core": 0.2, "flick": 0.1, "add": 0.7, "gain": 1.2}, {"delay": flight, "decay": 0.7})
	K.put(art, K.BITS, K.burst("edict_rubble", "rock", 46, 0.6, 2.6, 8.5, 11.0, [ROCK, ROCK.lightened(0.18), ROCK.darkened(0.25), Color("8a6f52")], 0.62, 0.05, 21), "EdictRubble", Vector3.ZERO, Vector3.ONE, 2.2, {"life": 1.9, "gravity": 21.0, "piece": 0.62, "floor_y": 0.1, "shrink": 0.8, "spin": 7.0, "hot": Color(1.0, 0.65, 0.2, 0.7)}, {"delay": flight, "decay": 0.9})
	K.put(art, K.FLAT, K.shock("edict_shock", Color(1.0, 0.8, 0.35, 1.0), 0.2), "EdictShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.25, 0.6, {"soft": 1.3, "hot": Color(1, 1, 0.9, 1.0), "core": 0.5, "add": 0.5}, {"delay": flight, "initial": 0.06, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.3})
	if not _cache.has("pillar"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		K.beam(st, Vector3.ZERO, 1.0, 0.3, Color(1.0, 0.8, 0.4, 0.7), 3, 0.0, 0.0, 0.16)
		K.disc(st, 0.36, Color(1.0, 0.9, 0.6, 0.9), 0.01, 28, 0.0, Vector3.UP, Vector3.ZERO, Color(1.0, 0.7, 0.2, 0.0))
		_cache.pillar = K.finish(st, Vector3.ONE * 0.2, false)
	K.put(art, K.FLAT, _cache.pillar, "EdictPillar", Vector3.UP * 0.1, Vector3(r, 10.0, r), 0.8, {"soft": 2.0, "hot": Color(1, 1, 0.9, 0.7), "core": 0.6, "flow": 2.5, "add": 0.7}, {"delay": flight, "initial": 0.5, "grow_time": 0.2, "fade_in": 0.02, "decay": 0.2})
	K.put(art, K.BITS, K.burst("edict_embers", "ember", 70, 0.3, r * 0.75, 1.2, 4.5, [GOLD, PALE, Color("ff8a3a"), CRIMSON.lightened(0.2)], 0.2, 0.5, 23, 0.1, 1.5), "EdictEmbers", Vector3.ZERO, Vector3.ONE, 2.4, {"life": 1.8, "gravity": -1.2, "drag": 1.4, "piece": 0.2, "sway": 0.25, "add": 0.6, "shrink": 0.3, "spin": 3.0}, {"delay": flight + 0.05, "decay": 0.8})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The lion on the guard roars: rings of sound burst from the hilt.
	var avatar := K.extra(parent, point, 2.2, "StarGodAvatar_" + ID, source)
	if avatar:
		var high := Vector3.UP * (GIANT * 0.6)
		K.put(avatar, K.FLAT, _roar(), "EdictRoar", high, Vector3.ONE * 5.2, 1.3, {"soft": 0.9, "sweep": 0.3, "tail": 1.4, "hot": Color(1, 1, 0.85, 0.8), "core": 0.5, "add": 0.45}, {"delay": flight + 0.04, "initial": 0.2, "grow_time": 0.55, "decay": 0.45, "face_camera": true})
		K.put(avatar, K.SOLID, StarGeometry.mesh("lion"), "EdictLion", high + Vector3(0, 0.1, 0), Vector3.ONE * 1.5, 2.0, {"remap": 1.0, "tone_a": Color("9c4312"), "tone_b": Color("ffd870"), "rim_color": PALE, "rim": 0.5}, {"delay": flight + 0.02, "initial": 0.3, "grow_time": 0.1, "fade_in": 0.05, "decay": 0.8, "face_camera": true})
		K.put(avatar, K.FLAT, _rays(), "EdictGlory", Vector3.UP * 0.1, Vector3(r * 0.75, 9.2, r * 0.75), 2.0, {"soft": 1.4, "flow": 0.8, "gain": 1.0, "add": 0.45}, {"delay": flight, "fade_in": 0.1, "spin": 0.3, "decay": 0.6})
		avatar._draw()
	if extras < 2:
		return true
	# The sky it came through, and what it tore loose.
	var temple := K.extra(parent, point, 2.2, "StarGodTemple_" + ID, source)
	if temple:
		K.put(temple, K.SOLID, _clouds(), "EdictCloudRing", Vector3.UP * 9.2, Vector3(9.0, 5.0, 9.0), 2.1, {"rim_color": GOLD, "rim": 0.4}, {"initial": 0.7, "grow_time": 0.5, "spin": 0.5, "decay": 0.7})
		K.put(temple, K.BITS, K.burst("edict_petals", "feather", 60, 0.5, r * 0.95, 0.6, -1.5, [Color("ff2a40"), Color("ff5a5a"), GOLD], 0.55, 0.6, 31, 3.0, 9.0), "EdictPetals", Vector3.ZERO, Vector3.ONE, 2.1, {"life": 2.0, "gravity": 1.6, "drag": 0.8, "piece": 0.55, "sway": 0.5, "spin": 4.0, "floor_y": 0.08, "shrink": 0.85}, {"delay": flight, "decay": 0.8})
		K.put(temple, K.FLAT, K.shock("edict_shock2", Color(1.0, 0.75, 0.3, 0.8), 0.1), "EdictShock2", Vector3.UP * 0.1, Vector3.ONE * r * 1.6, 0.9, {"soft": 1.2, "add": 0.5}, {"delay": flight + 0.12, "initial": 0.1, "grow_time": 0.8, "decay": 0.3})
		temple._draw()
	return true
