extends RefCounted
## Defender god skill "ปราการแห่งทวยเทพ" (pantheon_bastion): the fortress of the gods.
## Wind-up: a wall of towering god-shields grinds up out of the ground in a ring round the
## hit area (the caster stands inside the fortress). Four waves: each time one giant shield
## is driven outward along the ground in a new direction, ploughing a trench and throwing
## stone. Finale: ribs of light close the dome, the titan shield crashes down behind the
## caster and the whole wall bursts into pillars of light. Steel blue, gold and white:
## heavy, solid stone and metal, nothing glassy.
const K := preload("res://combat/god_art/_kit_melee.gd")
const STEEL := Color("4f74b4")
const DEEP := Color("27406e")
const GOLD := Color("f4c044")
const WHITE := Color("f6f8ff")
const STONE := Color("8d93a2")
const EARTH := Color("6a5d52")
const ID := "pantheon_bastion"
const WALL := 11
## The wall leaves a gate open towards the camera, so the fight inside stays in view.
const GATE := 1.3
const WALL_HEIGHT := 4.8
## The titan shield's height: its emblem stays inside the third-person camera's frame.
const TITAN := 7.8
## How far beyond the caster (as the camera sees it) the titan shield lands.
const BEYOND := 4.6
static var _cache := {}
## The yaw the wall was raised at (the finale breaks the same wall).
static var _gate_yaw := 0.0


## A god-shield: standing on the origin, +Y 1 tall, both faces dressed (seen from inside
## the fortress and from outside). [param grand]: the titan, crowned and winged.
static func _shield(grand := false) -> K.Part:
	var key := "titan_part" if grand else "shield_part"
	if _cache.has(key):
		return _cache[key]
	var p := K.Part.new()
	var outline := PackedVector2Array([Vector2(-0.3, 0.05), Vector2(0.3, 0.05), Vector2(0.36, 0.7), Vector2(0.24, 0.9), Vector2(0, 1.0), Vector2(-0.24, 0.9), Vector2(-0.36, 0.7)])
	var inner := PackedVector2Array()
	for q in outline:
		inner.append(Vector2(q.x * 0.72, 0.52 + (q.y - 0.52) * 0.76))
	p.ink(STEEL, 0.7)
	p.slab(outline, -0.04, 0.04)
	for s in [-1.0, 1.0]:
		p.ink(DEEP, 0.5)
		p.slab(inner, s * 0.04, s * 0.052)
		p.ink(GOLD, 0.9)
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			p.tube(Vector3(a.x, a.y, s * 0.035), Vector3(b.x, b.y, s * 0.035), 0.03, 0.03, 4)
		# The boss and the sun-cross of the pantheon.
		p.tube(Vector3(0, 0.55, s * 0.05), Vector3(0, 0.55, s * 0.12), 0.12, 0.07, 8)
		for k in 8:
			var a := TAU * float(k) / 8.0
			var reach := 0.3 if k % 2 == 0 else 0.19
			p.tube(Vector3(0, 0.55, s * 0.058), Vector3(sin(a) * reach * 0.85, 0.55 + cos(a) * reach, s * 0.058), 0.05 if k % 2 == 0 else 0.035, 0.0, 4, 0.3)
		p.ink(WHITE, 0.0, 1.0)
		p.gem(Vector3(0, 0.55, s * 0.125), Vector3(0.045, 0.045, 0.02))
		p.ink(GOLD, 0.9)
		for x in [-1.0, 1.0]:
			p.gem(Vector3(x * 0.2, 0.3, s * 0.055), Vector3(0.03, 0.03, 0.012))
			p.gem(Vector3(x * 0.22, 0.78, s * 0.055), Vector3(0.03, 0.03, 0.012))
	p.ink(STONE)
	p.box(Vector3(0, 0.03, 0), Vector3(0.86, 0.1, 0.28))
	p.ink(STONE.darkened(0.2))
	p.box(Vector3(0, -0.04, 0), Vector3(0.96, 0.06, 0.36))
	if grand:
		# A crown of three points and a pair of wings of white gold.
		p.ink(GOLD, 0.9, 0.2)
		for x in [-0.14, 0.0, 0.14]:
			p.tube(Vector3(x, 0.95 - absf(x) * 0.3, 0), Vector3(x * 1.3, 1.16 - absf(x) * 0.5, 0), 0.04, 0.0, 4, 0.5)
		for s in [-1.0, 1.0]:
			for k in 5:
				var t := float(k) / 4.0
				p.ink(WHITE.lerp(GOLD, t * 0.6), 0.8, 0.1)
				p.tube(Vector3(s * 0.33, 0.74 - 0.1 * t, 0), Vector3(s * (0.62 - 0.1 * t), 0.98 - 0.42 * t, -0.02), 0.045, 0.0, 4, 0.35)
	_cache[key] = p
	return p


static func _wall_angle(i: int) -> float:
	return GATE * 0.5 + (TAU - GATE) * (float(i) + 0.5) / float(WALL)


## The wall: [shields SOLID, dust BITS], rising one after another round the ring.
static func _wall(r: float) -> Array:
	if _cache.has("wall"):
		return _cache.wall
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var solid := K.begin()
	var dust := SurfaceTool.new()
	dust.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in WALL:
		var a := _wall_angle(i)
		var at := Vector3(sin(a), 0, cos(a)) * r * 0.97
		var delay := 0.065 * float(i)
		# The far side of the ring (opposite the gate) stands lower: the camera has little
		# sky left over it, and the fight inside stays in view.
		var low := lerpf(1.0, 0.72, pow(maxf(0.0, -cos(a)), 2.0))
		var basis := Basis(Vector3.UP, a) * Basis.from_scale(Vector3(1.3, low, 1.6) * WALL_HEIGHT * rng.randf_range(0.94, 1.06))
		K.stamp(solid, _shield(), Transform3D(basis, at), delay, 1.0)
		K.burst_at(dust, rng, "puff", 5, at, 0.2, 1.3, 1.6, 1.4, [Color(0.75, 0.7, 0.62), Color(0.62, 0.58, 0.52)], 0.9, delay + 0.03, 0.2, 0.1, 0.5)
		K.burst_at(dust, rng, "rock", 4, at, 0.2, 1.2, 2.4, 4.5, [EARTH, STONE.darkened(0.2)], 0.4, delay + 0.03, 0.1)
	_cache.wall = [K.finish(solid, Vector3(0.5, 6.0, 0.5)), K.finish(dust, Vector3(5, 6, 5), false)]
	return _cache.wall


## One giant shield driven along +Z to the origin over [param run] metres:
## [shield SOLID, trench and impact FLAT, stone BITS, dust BITS].
static func _slam(run: float) -> Array:
	if _cache.has("slam"):
		return _cache.slam
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var flight := 0.2
	var solid := K.begin()
	K.stamp(solid, _shield(), Transform3D(Basis.from_scale(Vector3(1.25, 1.0, 1.8) * 6.0), Vector3.ZERO), 0.0, 1.0)
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The trench it ploughs: torn earth with a hot gold seam down the middle.
	var path := PackedVector3Array()
	for i in 9:
		path.append(Vector3(0, 0.06, -run + run * float(i) / 8.0))
	K.ribbon(flat, path, 3.6, Color(0.16, 0.11, 0.08, 0.85), 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	for x in [-1.25, 1.25]:
		var edge := PackedVector3Array()
		for i in 9:
			edge.append(Vector3(x + rng.randf_range(-0.15, 0.15), 0.07, -run + run * float(i) / 8.0))
		K.ribbon(flat, edge, 0.4, Color(1.0, 0.76, 0.25, 0.95), 0.0, 0.0, Vector3.UP, 0.3)
	K.disc(flat, 3.6, Color(1.0, 0.92, 0.7, 0.95), 0.09, 20, flight, Vector3.UP, Vector3(0, 0, 0.8), Color(1.0, 0.75, 0.25, 0.0), -1.0)
	K.crack_star(flat, rng, Vector3(0, 0.07, 0.6), 7, 0.2, 3.4, 0.3, Color(0.14, 0.1, 0.1, 1.0), flight, 1, 0.3)
	var arc := PackedVector3Array()
	for i in 17:
		var a := -PI * 0.5 + PI * float(i) / 16.0
		arc.append(Vector3(sin(a) * 3.4, 0.1, 0.4 + cos(a) * 3.4))
	K.ribbon(flat, arc, 0.9, Color(1.0, 0.85, 0.5, 1.0), flight, -1.0, Vector3.UP, 0.8)
	var bits := SurfaceTool.new()
	bits.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dust := SurfaceTool.new()
	dust.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 18:
		var q := float(i + 1) / 18.0
		var side := -1.0 if i % 2 == 0 else 1.0
		var origin := Vector3(side * rng.randf_range(0.8, 1.6), 0.15, -run * (1.0 - q))
		var delay := flight * sqrt(q)
		var vel := Vector3(side * rng.randf_range(1.5, 4.0), rng.randf_range(3.5, 7.0), rng.randf_range(0.5, 3.0))
		var size := rng.randf_range(0.3, 0.6)
		K.bit(bits, K.rock(rng, [STONE, EARTH, STONE.darkened(0.25)][i % 3]), origin, vel, delay, 0.6, Basis.from_scale(Vector3.ONE * size))
		K.bit(dust, K._bit_shape("puff", rng, Color(0.76, 0.71, 0.63)), origin, Vector3(side * rng.randf_range(0.5, 1.6), rng.randf_range(0.6, 1.6), 0.5), delay, 1.2, Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.2)))
	K.burst_at(bits, rng, "rock", 16, Vector3(0, 0, 0.9), 0.3, 1.8, 5.0, 8.0, [STONE, EARTH, STONE.lightened(0.15)], 0.6, flight, 0.03)
	K.burst_at(dust, rng, "puff", 9, Vector3(0, 0, 1.0), 0.5, 2.2, 2.2, 1.6, [Color(0.76, 0.71, 0.63), Color(0.64, 0.6, 0.55)], 1.2, flight, 0.08, 0.2, 0.9)
	_cache.slam = [K.finish(solid, Vector3(0.5, 0.5, run + 1.0)), K.finish(flat, Vector3.ONE * 0.5, false), K.finish(bits, Vector3(8, 8, run + 8.0), false), K.finish(dust, Vector3(6, 6, run + 6.0), false)]
	return _cache.slam


static func _titan() -> ArrayMesh:
	if not _cache.has("titan"):
		var st := K.begin()
		K.stamp(st, _shield(true), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.5)), Vector3.ZERO))
		_cache.titan = K.finish(st, Vector3(0.5, 4.0, 0.5))
	return _cache.titan


## The wall bursting into light: a pillar and a ground flash where each shield stood.
static func _burst_light(r: float) -> ArrayMesh:
	if not _cache.has("burst_light"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in WALL:
			var a := _wall_angle(i)
			var at := Vector3(sin(a), 0, cos(a)) * r * 0.97
			var delay := 0.012 * float(i)
			K.beam(st, at, 9.0, 2.4, Color(1.0, 0.8, 0.36, 0.9), 2, delay, 0.0, 0.7)
			K.disc(st, 2.2, Color(1.0, 0.95, 0.75, 0.95), 0.08, 14, delay, Vector3.UP, at, Color(1.0, 0.75, 0.3, 0.0), -1.0)
		K.ring(st, r * 0.97, 0.9, Color(1.0, 0.8, 0.35, 0.9), 0.07, 56, 0.0, TAU - GATE, GATE * 0.5)
		_cache.burst_light = K.finish(st, Vector3.ONE * 0.5, false)
	return _cache.burst_light


## Ribs of light racing up from the wall to close the dome.
static func _dome(r: float) -> ArrayMesh:
	if not _cache.has("dome"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radius := r * 0.97
		for i in WALL:
			var a := _wall_angle(i)
			var dir := Vector3(sin(a), 0, cos(a))
			var pts := PackedVector3Array()
			for k in 13:
				var t := float(k) / 12.0 * 0.96
				pts.append(dir * radius * cos(t * PI * 0.5) + Vector3.UP * (WALL_HEIGHT * 0.9 + 6.5 * sin(t * PI * 0.5)))
			K.ribbon(st, pts, 0.9, Color(1.0, 0.8, 0.36, 0.95), 0.0, 0.0, dir, 0.25)
		for k in 2:
			var h := [0.35, 0.72][k] as float
			var ring_r := radius * cos(h * PI * 0.5)
			var pts := PackedVector3Array()
			for i in 41:
				var a := TAU * float(i) / 40.0
				pts.append(Vector3(sin(a) * ring_r, WALL_HEIGHT * 0.9 + 6.5 * sin(h * PI * 0.5), cos(a) * ring_r))
			K.ribbon(st, pts, 0.3, Color(1.0, 0.9, 0.6, 0.8), 0.0, 0.0, Vector3.UP, 0.0, h, h)
		_cache.dome = K.finish(st, Vector3.ONE * 0.5, false)
	return _cache.dome


## Fragments of the wall flying apart: steel and gold plates from where each shield stood.
static func _shrapnel(r: float) -> ArrayMesh:
	if not _cache.has("shrapnel"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 51
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in WALL:
			var a := _wall_angle(i)
			var dir := Vector3(sin(a), 0, cos(a))
			var at := dir * r * 0.97
			for k in 5:
				var origin := at + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.6, WALL_HEIGHT), rng.randf_range(-0.3, 0.3))
				var vel := dir * rng.randf_range(1.5, 5.0) + Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(3.0, 8.0), rng.randf_range(-1.5, 1.5))
				var color: Color = [STEEL, GOLD, DEEP, WHITE, STEEL.lightened(0.2)][rng.randi() % 5]
				var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.5, 1.0))
				K.bit(st, K._bit_shape("shard", rng, color), origin, vel, 0.012 * float(i) + rng.randf() * 0.05, 1.0, basis)
		_cache.shrapnel = K.finish(st, Vector3(8, 10, 8), false)
	return _cache.shrapnel


## A glory of rays in the XY plane (it faces the camera behind the titan shield).
static func _glory() -> ArrayMesh:
	if not _cache.has("glory"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 20:
			var a := TAU * float(i) / 20.0
			var dir := Vector3(sin(a), cos(a), 0)
			var reach := 1.0 if i % 2 == 0 else 0.7
			K.ribbon(st, PackedVector3Array([dir * 0.25, dir * reach * 0.6, dir * reach]), 0.14, Color(1.0, 0.86, 0.5, 0.85), 0.0, 0.0, Vector3.BACK, 1.0)
		var pts := PackedVector3Array()
		for i in 41:
			var a := TAU * float(i) / 40.0
			pts.append(Vector3(sin(a) * 0.55, cos(a) * 0.55, 0))
		K.ribbon(st, pts, 0.06, Color(1.0, 0.95, 0.75, 0.9), 0.0, 0.0, Vector3.BACK, 0.0)
		_cache.glory = K.finish(st, Vector3.ONE * 0.2, false)
	return _cache.glory


static func telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var r := K.radius(skill)
	var origin := caster.global_position
	var parent := art.get_parent() as Node3D
	# The caster: the ground under the planted shield brightens.
	K.put(art, K.FLAT, K.glow_disc("bastion_stand", Color(1.0, 0.82, 0.4, 0.75), Color(0.4, 0.6, 1.0, 0.0)), "BastionStand", Vector3.UP * 0.06, Vector3.ONE * 2.6, time, {"soft": 1.0, "add": 0.6}, {"initial": 0.3, "grow_time": 0.8, "fade_in": 0.2, "decay": 0.9})
	# The wall stands from the wind-up until the finale breaks it.
	var hold := time + 1.5 + 0.34
	var ground := K.extra(parent, Vector3(point.x, 0, point.z), hold, "StarGodGround_" + ID, origin)
	if ground:
		var wall := _wall(r)
		_gate_yaw = K.facing(ground)
		var turn := Vector3(0, _gate_yaw, 0)
		K.put(ground, K.SOLID, wall[0], "BastionWall", Vector3.ZERO, Vector3.ONE, hold, {"drop": -5.6, "flight": 0.3, "ease": 1.0, "rim_color": Color("bcd4ff"), "rim": 0.35, "glow_color": Color("fff0c0")}, {"decay": 0.94}, turn)
		K.put(ground, K.FLAT, K.area_ring("bastion_area", Color(1.0, 0.78, 0.3, 1.0), 28), "BastionArea", Vector3.UP * 0.07, Vector3.ONE * r, time + 0.25, {"soft": 0.5, "hot": Color(1, 0.96, 0.8, 0.8), "core": 0.5, "add": 0.35}, {"initial": 0.5, "grow_time": 0.3, "fade_in": 0.1, "spin": 0.15, "decay": 0.9})
		K.put(ground, K.BITS, wall[1], "BastionWallDust", Vector3.ZERO, Vector3.ONE, time + 0.4, {"life": 1.0, "gravity": 6.0, "drag": 2.0, "piece": 0.9, "swell": 1.8, "alpha": 0.5, "shrink": 0.6, "floor_y": 0.05, "spin": 2.0}, {"decay": 0.9}, turn)
		ground._draw()
	if GodSkillArt.extra_roots(1) < 1:
		return true
	var sky := K.extra(parent, Vector3(point.x, 0, point.z), time, "StarGodSky_" + ID, origin, art)
	if sky:
		# The titan shield hangs over the fortress, turning, waiting.
		var spot := K.beyond(sky, BEYOND)
		# As high as the camera shows it whole.
		var omen := TITAN * 0.44
		var hang := maxf(2.2, K.sky(sky, spot, 8.0 + omen) - omen)
		K.put(sky, K.SOLID, _titan(), "BastionOmen", spot + Vector3.UP * (hang + 1.2), Vector3.ONE * omen, time, {"rim_color": Color("fff0c0"), "rim": 0.6, "glow_color": Color("fff0c0")}, {"fade_in": 0.3, "travel": Vector3.DOWN * 1.2, "decay": 0.95, "spin": 1.4, "initial": 0.5, "grow_time": 0.9})
		K.put(sky, K.FLAT, _glory(), "BastionOmenGlory", spot + Vector3.UP * (hang + omen * 0.55), Vector3.ONE * 3.6, time, {"soft": 1.0, "hot": Color(1, 1, 0.9, 0.7), "core": 0.5, "add": 0.6}, {"initial": 0.3, "grow_time": 0.9, "fade_in": 0.3, "decay": 0.9, "face_camera": true})
		sky._draw()
	return true


static func wave(art: StarSkillArt, _parent: Node3D, skill: Dictionary, index: int, _point: Vector3, _source: Vector3) -> bool:
	var r := K.radius(skill)
	var run := r * 0.9 - 1.6
	var meshes := _slam(run)
	# Out on the four diagonals as the camera sees them (every shield shows its face at
	# three quarters), never the same way twice.
	var away := K.away(art)
	var yaw: float = atan2(away.x, away.z) + [PI * 0.25, PI * 1.25, PI * 1.75, PI * 0.75][index % 4]
	var at := Vector3(sin(yaw), 0, cos(yaw)) * r * 0.9
	var turn := Vector3(0, yaw, 0)
	var flight := 0.2
	K.put(art, K.SOLID, meshes[0], "BastionSlam", at, Vector3.ONE, 1.1, {"from": Vector3(0, 0, -run), "flight": flight, "heat": 0.7, "rim_color": Color("bcd4ff"), "rim": 0.4, "glow_color": Color("fff0c0")}, {"decay": 0.75}, turn + Vector3(0.14, 0, 0))
	K.put(art, K.FLAT, meshes[1], "BastionTrench", at, Vector3.ONE, 1.5, {"sweep": flight, "flash": 0.32, "soft": 0.6, "hot": Color(1, 0.86, 0.45, 1.0), "core": 0.3, "add": 0.5}, {"decay": 0.6}, turn)
	K.put(art, K.BITS, meshes[2], "BastionStone", at, Vector3.ONE, 1.5, {"life": 1.3, "gravity": 19.0, "piece": 0.6, "floor_y": 0.08, "shrink": 0.8, "spin": 7.0}, {"decay": 0.9}, turn)
	K.put(art, K.BITS, meshes[3], "BastionDust", at, Vector3.ONE, 1.3, {"life": 1.1, "gravity": -0.6, "drag": 2.2, "piece": 1.2, "swell": 2.0, "alpha": 0.45, "shrink": 0.5, "spin": 1.5}, {"decay": 0.8}, turn)
	return true


static func finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	var r := K.radius(skill)
	var flight := 0.22
	var spot := K.beyond(art, BEYOND)
	var face := K.facing(art)
	# No taller than the camera shows: the crown and the emblem stay in frame.
	var titan := TITAN * GodSkillArt.fit(art, art.to_global(spot), TITAN * 0.97, 0.62)
	var gate := Vector3(0, _gate_yaw, 0)
	# The titan shield comes down behind the caster, its face to the camera.
	K.put(art, K.SOLID, _titan(), "BastionTitan", spot + Vector3.DOWN * titan * 0.05, Vector3(titan * 1.25, titan, titan * 1.25), 2.4, {"drop": 30.0 / titan, "flight": flight, "heat": 0.5, "rim_color": Color("fff0c0"), "rim": 0.45, "glow_color": Color("fff3d0")}, {"decay": 0.82}, Vector3(-0.1, face, 0))
	K.put(art, K.FLAT, _burst_light(r), "BastionBurst", Vector3.ZERO, Vector3.ONE, 1.5, {"flash": 0.5, "soft": 1.5, "hot": Color(1, 0.9, 0.6, 0.6), "core": 0.4, "add": 0.3, "gain": 0.7}, {"delay": flight, "decay": 0.35}, gate)
	K.put(art, K.BITS, _shrapnel(r), "BastionShrapnel", Vector3.ZERO, Vector3.ONE, 2.0, {"life": 1.7, "gravity": 14.0, "piece": 1.0, "floor_y": 0.08, "shrink": 0.8, "spin": 8.0, "hot": Color(1.0, 0.85, 0.5, 0.6)}, {"delay": flight, "decay": 0.9}, gate)
	K.put(art, K.FLAT, K.cracks("bastion_cracks", 9, 0.12, 1.0, 0.05, Color(0.12, 0.1, 0.12, 1.0), 17, 1, 0.3), "BastionCracks", spot * 0.6 + Vector3.UP * 0.07, Vector3.ONE * r * 0.95, 2.2, {"sweep": 0.3, "soft": 0.4, "hot": Color(1, 0.86, 0.45, 1.0), "core": 0.25, "add": 0.6}, {"delay": flight, "decay": 0.7})
	K.put(art, K.FLAT, K.shock("bastion_shock", Color(1.0, 0.85, 0.5, 1.0), 0.2), "BastionShock", Vector3.UP * 0.12, Vector3.ONE * r * 1.3, 0.6, {"soft": 1.2, "hot": Color(1, 0.95, 0.75, 0.7), "core": 0.4, "add": 0.4}, {"delay": flight, "initial": 0.06, "grow_time": 0.75, "fade_in": 0.02, "decay": 0.3})
	K.put(art, K.BITS, K.burst("bastion_rubble", "rock", 36, 0.8, 3.4, 7.0, 10.0, [STONE, EARTH, STONE.darkened(0.25), STONE.lightened(0.12)], 0.7, 0.05, 55), "BastionRubble", spot, Vector3.ONE, 2.2, {"life": 1.8, "gravity": 21.0, "piece": 0.7, "floor_y": 0.1, "shrink": 0.8, "spin": 7.0}, {"delay": flight, "decay": 0.9})
	var extras := GodSkillArt.extra_roots(2)
	if extras < 1:
		return true
	# The dome closes over the fortress as the shield falls, a glory opens behind it.
	var avatar := K.extra(parent, point, 2.2, "StarGodAvatar_" + ID, source)
	if avatar:
		K.put(avatar, K.FLAT, _dome(r), "BastionDome", Vector3.ZERO, Vector3.ONE, 0.75, {"sweep": flight * 1.2, "soft": 0.9, "hot": Color(1, 0.95, 0.75, 0.6), "core": 0.35, "add": 0.35, "gain": 0.75}, {"decay": 0.45}, gate)
		K.put(avatar, K.FLAT, _glory(), "BastionGlory", spot * 1.05 + Vector3.UP * titan * 0.55, Vector3.ONE * titan * 0.85, 1.9, {"soft": 1.0, "hot": Color(1, 0.95, 0.75, 0.5), "core": 0.4, "add": 0.35, "gain": 0.7, "flick": 0.05, "priority": -1}, {"delay": flight, "initial": 0.3, "grow_time": 0.2, "decay": 0.6, "face_camera": true})
		K.put(avatar, K.BITS, K.burst("bastion_motes", "ember", 80, 0.5, r * 0.97, 0.6, 4.0, [GOLD, WHITE, Color("bcd4ff")], 0.2, 0.6, 56, 0.1, 2.0), "BastionMotes", Vector3.ZERO, Vector3.ONE, 2.3, {"life": 1.9, "gravity": -1.4, "drag": 1.0, "piece": 0.2, "sway": 0.25, "add": 0.7, "shrink": 0.3}, {"delay": flight + 0.05, "decay": 0.8})
		avatar._draw()
	if extras < 2:
		return true
	var temple := K.extra(parent, point, 2.2, "StarGodTemple_" + ID, source)
	if temple:
		K.put(temple, K.FLAT, K.shock("bastion_shock2", Color(0.6, 0.78, 1.0, 0.85), 0.1), "BastionShock2", Vector3.UP * 0.1, Vector3.ONE * r * 1.7, 0.9, {"soft": 1.2, "add": 0.6}, {"delay": flight + 0.12, "initial": 0.1, "grow_time": 0.8, "decay": 0.3})
		K.put(temple, K.BITS, K.burst("bastion_dust", "puff", 40, r * 0.6, r, 3.0, 1.4, [Color(0.78, 0.74, 0.68), Color(0.66, 0.64, 0.62)], 1.3, 0.1, 57, 0.2, 1.0), "BastionDustRing", Vector3.ZERO, Vector3.ONE, 1.6, {"life": 1.4, "gravity": -0.5, "drag": 1.8, "piece": 1.3, "swell": 2.2, "alpha": 0.4, "shrink": 0.5, "spin": 1.5}, {"delay": flight, "decay": 0.8})
		temple._draw()
	return true
