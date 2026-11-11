extends RefCounted
## Shared helpers of the "sky" signatures: the Archer's, Mage's and Priest's Lv.60-100
## class skills (combat/skill_art/<skill id>.gd, SkillSignature). Cosmetic ONLY: the hero /
## companion code owns every hit, target, buff and timing; these only dress the beats.
## Everything is staged on GodRangedKit roots (combat/god_art/_kit_ranged.gd): one clock per
## root, one draw and one VfxBudget decoration per piece or swarm, all freed with the root,
## painted by the god_* shaders (tinted cores, never a white-out).
##
## A cast (Cast) knows who casts: the player's own hero draws the full set piece in the
## hero's room of the budget; companions, world players and rivals draw a lighter one
## (lv 0, and only the core when many casts crowd the same second), so a guild war full of
## casters never tanks the frame rate. Every root watches its caster (Watch): the caster
## dying or leaving mid-cast fades the set piece out at once; a wind-up root also follows
## the caster's skill generation (a cancelled wind-up drops it).
## Scripts whose name starts with `_` are kits, never a skill's own art.
const K := preload("res://combat/god_art/_kit_ranged.gd")
const S := preload("res://combat/star_art/_kit_star.gd")
const FLAT := Vector3(-PI / 2, 0, 0)
const GROUPS := ["hero", "companions", "world_players", "gw_fighters"]
static var _recent: Array[int] = []
static var _meshes := {}


## Lives on the caster for the length of a show; frees itself when the caster dies (or at
## its end), which closes every root watching it.
class Watch:
	extends Node
	var life := 1.0
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		var body := get_parent()
		if age >= life or not is_instance_valid(body) or (body.has_method("is_dead") and bool(body.call("is_dead"))):
			queue_free()


## One beat of a cast: who casts, how much it may draw, and its roots.
class Cast:
	var parent: Node3D
	var skill: Dictionary
	var id := ""
	var origin := Vector3.ZERO
	var caster: Node3D
	var visual: HeroVisual
	## The player's own hero (its room of the budget).
	var hero := false
	## 2 full, 1 medium, 0 lean (low quality, memory pressure, companions), -1 core only.
	var lv := 2
	var watch: Node
	var watch_life := 0.0

	## [param low], [param mid], [param high] by this cast's level (core-only casts take low).
	func n(low: int, mid: int, high: int) -> int:
		return [low, low, mid, high][lv + 1]

	## A root at [param at] (world) facing away from [param source], tied to the caster
	## (and, for a wind-up, to its skill generation for the first [param windup] s).
	func root(at: Vector3, seconds: float, part: String, source: Vector3, windup := 0.0) -> K:
		if not is_instance_valid(parent) or not parent.is_inside_tree():
			return null
		if not hero and not VfxBudget.can_decorate(6):
			return null
		var r := K.open(parent, at, seconds, "Sky_%s_%s" % [id, part], source)
		if not r:
			return null
		if is_instance_valid(watch):
			r.watch_ref = weakref(watch)
			r.watch_until = maxf(0.05, watch_life - 0.1)
		if windup > 0.0 and is_instance_valid(visual):
			r.generation_ref = weakref(visual)
			r.generation = visual.skill_generation
			r.generation_until = windup
		return r

	## A root at [param at] whose +Z points (flat) towards [param target].
	func toward(at: Vector3, target: Vector3, seconds: float, part: String, windup := 0.0) -> K:
		var d := Vector3(target.x - at.x, 0, target.z - at.z)
		return root(at, seconds, part, at - d, windup)

	## Whether a detail layer of [param level] draws in this cast.
	func has(level: int) -> bool:
		return lv >= level

	## The caster's weapon hand (world).
	func hand() -> Vector3:
		if is_instance_valid(visual):
			return visual.skill_emission_position()
		if is_instance_valid(caster):
			return S.hand(caster)
		return origin + Vector3.UP * 1.3


## Opens a cast for [param skill] at [param origin]; [param seconds] is how long its show
## lasts (the watch on the caster).
## [param beat]: a wind-up or a release (counted for the crowd), not a carrier, link or hit.
static func cast(parent: Node3D, skill: Dictionary, origin: Vector3, seconds: float, visual: HeroVisual = null, beat := true) -> Cast:
	var c := Cast.new()
	c.parent = parent
	c.skill = skill
	c.id = String(skill.get("id", ""))
	c.origin = origin
	c.visual = visual
	c.hero = VfxBudget.for_hero()
	c.caster = caster_of(parent, origin, visual)
	if c.visual == null and is_instance_valid(c.caster) and c.caster.get("visual") is HeroVisual:
		c.visual = c.caster.get("visual") as HeroVisual
	var now := Time.get_ticks_msec()
	_recent = _recent.filter(func(t: int): return now - t < 1000)
	var crowd := _recent.size()
	if beat:
		_recent.append(now)
	var q := S.q()
	if MemoryGuard.pressure > 0:
		q = mini(q, 0 if MemoryGuard.pressure > 1 else 1)
	c.lv = q if c.hero else (0 if crowd < 3 else -1)
	if is_instance_valid(c.caster) and seconds > 0.0:
		var w := Watch.new()
		w.name = "SkyWatch_" + c.id
		w.life = seconds
		c.caster.add_child(w)
		c.watch = w
		c.watch_life = seconds
	return c


## The character casting at [param origin]: the visual's owner, else whoever stands there.
static func caster_of(parent: Node3D, origin: Vector3, visual: HeroVisual = null) -> Node3D:
	var node: Node = visual
	while is_instance_valid(node) and node != parent:
		if node is Node3D and node.has_method("is_dead") and not node is HeroVisual:
			return node as Node3D
		node = node.get_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	# Whoever stands there (origin: the feet, or the weapon hand of a carrier's flight).
	var best: Node3D = null
	var near := 1.2
	for group in GROUPS:
		for item in parent.get_tree().get_nodes_in_group(group):
			var body := item as Node3D
			if body and absf(origin.y - body.global_position.y) < 2.6:
				var d := Vector2(origin.x - body.global_position.x, origin.z - body.global_position.z).length()
				if d < near:
					near = d
					best = body
	if best:
		return best
	for item in parent.get_children():
		if item is CharacterBody3D and item.has_method("is_dead") and (item as Node3D).global_position.distance_squared_to(origin) < 0.0025:
			return item as Node3D
	return null


## Living foes within [param radius] of [param centre] (ground positions, nearest first).
static func foes(node: Node, centre: Vector3, radius: float, most: int) -> Array:
	return S.foes(node, centre, radius, most)


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## Euler angles that turn a piece's +Y along [param direction].
static func along(direction: Vector3, roll := 0.0) -> Vector3:
	if direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return K.falling(Vector3.ZERO, -direction, 1.0, roll).basis.get_euler()


## Euler angles that point a piece's point (at its origin, shaft along +Y: arrows, swords,
## shards) along [param direction].
static func pointing(direction: Vector3, roll := 0.0) -> Vector3:
	if direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return K.falling(Vector3.ZERO, direction, 1.0, roll).basis.get_euler()


# ---------------------------------------------------------------------------
# Light (god_glow) pieces, in root space
# ---------------------------------------------------------------------------
static func glow(r: K, mode: int, at: Vector3, size: Vector3, angles: Vector3, colours: Dictionary, start: float, seconds: float, gain := 0.5, params := {}, o := {}) -> MeshInstance3D:
	if not r:
		return null
	var p := colours.merged({"mode": mode, "gain": gain}, true).merged(params, true)
	return r.add(K.mesh("quad"), _shader(o), p, at, size, angles, start, seconds, {"fin": 0.05, "fout": seconds * 0.4}.merged(o, true))


## o.veil: alpha-blended (keeps its hue over a bright ground), else additive light.
static func _shader(o: Dictionary) -> Shader:
	return K.VEIL if bool(o.get("veil", false)) else K.GLOW


static func flash(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, gain := 0.5, o := {}) -> void:
	glow(r, 0, at, Vector3.ONE * size, Vector3.ZERO, colours, start, seconds, gain, {"billboard": true, "p1": 2.2}, {"fin": 0.03, "fout": seconds * 0.6}.merged(o, true))


## A shock ring on the ground (alpha-blended unless o.veil is false: it keeps its colour).
static func ring(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, gain := 0.6, o := {}) -> void:
	glow(r, 1, at, Vector3.ONE * size, K.FLAT, colours, start, seconds, gain, {"p1": 0.9}, {"fin": 0.01, "veil": true}.merged(o, true))


## A ring standing up (facing the camera's side of the root).
static func ring_up(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, gain := 0.6, o := {}) -> void:
	if r:
		glow(r, 1, at, Vector3.ONE * size, Vector3(0, S.face_camera(r), 0), colours, start, seconds, gain, {"p1": 0.9}, {"fin": 0.01, "veil": true}.merged(o, true))


## A sigil writing itself on the ground: rings, glyphs and a [param points]-point star.
static func sigil(r: K, at: Vector3, radius: float, points: float, colours: Dictionary, start: float, seconds: float, write := 0.5, gain := 0.45, spin := 0.2, o := {}) -> void:
	glow(r, 17, at, Vector3.ONE * radius, K.FLAT, colours, start, seconds, gain, {"p1": points, "p2": 1.0 / maxf(write / seconds, 0.05), "life": seconds}, {"spin": Vector3(0, 0, spin), "fin": 0.08, "fout": 0.35}.merged(o, true))


## The area rim (a line, a dashed ring and a faint wash).
static func rim(r: K, at: Vector3, radius: float, colours: Dictionary, start: float, seconds: float, gain := 0.55, o := {}) -> void:
	glow(r, 5, at, Vector3.ONE * radius, K.FLAT, colours, start, seconds, gain, {"p1": 28.0}, {"grow": 0.3, "from": 0.4, "fout": 0.3}.merged(o, true))


## A column of light (or fire: [param p1] negative runs it downward) standing on [param at].
static func column(r: K, at: Vector3, radius: float, height: float, colours: Dictionary, start: float, seconds: float, gain := 0.5, p1 := -4.0, o := {}, shader: Shader = null) -> void:
	if r:
		r.add(K.mesh("column"), shader if shader else _shader(o), colours.merged({"mode": 3, "p1": p1, "p2": 0.4, "gain": gain}), at, Vector3(radius, height, radius), Vector3.ZERO, start, seconds, {"fin": 0.02, "fout": seconds * 0.45}.merged(o, true))


## A ring of standing fire (god_glow mode 14) round [param at].
static func fire_wall(r: K, at: Vector3, radius: float, height: float, colours: Dictionary, start: float, seconds: float, gain := 0.7, o := {}) -> void:
	if r:
		r.add(K.mesh("column"), K.VEIL, colours.merged({"mode": 14, "p1": 2.4, "p2": 2.0, "gain": gain}), at, Vector3(radius, height, radius), Vector3.ZERO, start, seconds, {"fin": 0.04, "fout": seconds * 0.4}.merged(o, true))


## A ribbon of light from [param from] to [param to] (drawn out from its start).
static func beam(r: K, from: Vector3, to: Vector3, width: float, colours: Dictionary, start: float, seconds: float, gain := 0.55, p1 := 6.0, o := {}) -> void:
	if r and from.distance_squared_to(to) > 0.0004:
		r.add(K.mesh("beam"), _shader(o), colours.merged({"mode": 16, "p1": p1, "p2": 0.5, "gain": gain, "life": seconds}), from, Vector3(width, from.distance_to(to), width), along(to - from), start, seconds, {"fin": 0.01, "fout": seconds * 0.3}.merged(o, true))


## A jagged bolt of lightning from [param from] down to [param to].
static func bolt(r: K, from: Vector3, to: Vector3, width: float, colours: Dictionary, start: float, seconds: float, gain := 0.85, salt := 0.0, o := {}) -> void:
	if r and from.distance_squared_to(to) > 0.0004:
		var length := from.distance_to(to)
		r.add(K.mesh("bolt"), K.GLOW, colours.merged({"mode": 13, "gain": gain, "seed": salt, "life": seconds}), to, Vector3(width, length / 9.0, width), along(from - to, salt * 2.3), start, seconds, {"fin": 0.01, "fout": 0.05}.merged(o, true))


## A scorch on the ground, its cracks cooling (alpha blended).
static func scorch(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, salt := 1.0) -> void:
	if r:
		r.add(K.mesh("quad"), K.VEIL, colours.merged({"mode": 7, "seed": salt, "life": seconds, "gain": 0.65}), at, Vector3.ONE * size, K.FLAT, start, seconds, {"fin": 0.01, "priority": -1})


## A glass ward over [param at] (fresnel rim, hex cells, a rising sweep).
static func dome(r: K, at: Vector3, radius: float, colours: Dictionary, start: float, seconds: float, gain := 0.35, o := {}) -> void:
	if r:
		r.add(K.mesh("sphere"), _shader(o), colours.merged({"mode": 15, "p1": 2.2, "gain": gain}), at, Vector3(radius, radius * 0.8, radius), Vector3.ZERO, start, seconds, {"grow": 0.25, "from": 0.3, "fin": 0.05, "fout": seconds * 0.4}.merged(o, true))


## Three ribbons of wind winding up round [param at], [param size] = (width, height, width).
static func helix(r: K, at: Vector3, size: Vector3, colours: Dictionary, start: float, seconds: float, spin := 4.0, gain := 0.5, o := {}) -> void:
	if r:
		r.add(K.mesh("helix"), _shader(o), colours.merged({"mode": 16, "p1": 3.0, "p2": 0.6, "gain": gain, "life": seconds * 1.25}), at, size, Vector3.ZERO, start, seconds, {"spin": Vector3(0, spin, 0), "fin": 0.04, "fout": seconds * 0.4}.merged(o, true))


## Billowing puffs over a disc (god_glow mode 8: fire; alpha-blended greys: cloud and smoke).
static func puffs(r: K, centre: Vector3, radius: float, count: int, colours: Dictionary, size: float, start: float, life: float, rise := 0.6, veil := false, salt := 0.0, spread := 0.15, gain := 1.0) -> void:
	if not r or count <= 0:
		return
	var cards := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 2.7 + salt)
		cards.append(K.card(centre + K.scatter(k, count, radius, salt) + Vector3.UP * (0.2 + 0.4 * s), size * (0.7 + 0.6 * s)))
		data.append(Color(s * spread, s, 0, 0))
	r.swarm(K.mesh("quad"), K.VEIL if veil else K.GLOW, colours.merged({"mode": 8, "billboard": true, "life": life, "drift": Vector3(0, rise, 0), "sway": 0.2, "grow": Vector2(0.7, 1.25), "gain": gain}), cards, data, start, life + spread + 0.1, {"fin": 0.01, "priority": -1 if veil else 0})


## Pieces of [param geometry] (point at their origin, shaft along +Y) falling along
## [param direction] onto [param spots] (god_solid motion 1), landing over [param flight] s,
## each [param delays] later; returns nothing.
static func rain(r: K, geometry: Mesh, paint: Dictionary, spots: Array, delays: Array, direction: Vector3, size: float, flight: float, start: float, hold := 0.4, travel := 12.0, stick := 1.0) -> void:
	if not r or spots.is_empty():
		return
	var xf := []
	var data := []
	for k in spots.size():
		var s := K.rand(float(k) * 3.3 + 0.7)
		xf.append(K.falling(spots[k], direction, size * (0.85 + 0.3 * s), s * TAU))
		data.append(Color(float(delays[k]) if k < delays.size() else 0.0, s, 0, 0))
	var last := 0.0
	for d in delays:
		last = maxf(last, float(d))
	r.swarm(geometry, K.SOLID, paint.merged({"motion": 1, "flight": flight, "travel": travel, "hold": hold, "stick": stick, "accelerate": 0.6}), xf, data, start, last + flight + hold + 0.1, {"fin": 0.01, "fout": 0.05})


## A swarm of landing marks (rings or star cards) under each spot, each at its delay.
static func marks(r: K, spots: Array, delays: Array, size: float, colours: Dictionary, start: float, life: float, mode := 1, lift := 0.07, gain := 0.6) -> void:
	if not r or spots.is_empty():
		return
	var xf := []
	var data := []
	var last := 0.0
	for k in spots.size():
		var s := K.rand(float(k) * 1.9 + 3.0)
		var spot: Vector3 = spots[k]
		var d := float(delays[k]) if k < delays.size() else 0.0
		last = maxf(last, d)
		if mode == 1:
			xf.append(K.lying(spot + Vector3.UP * (lift + 0.002 * k), size * (0.8 + 0.4 * s)))
		else:
			xf.append(K.card(spot + Vector3.UP * lift, size * (0.8 + 0.4 * s)))
		data.append(Color(d, s, 0, 0))
	r.swarm(K.mesh("quad"), K.VEIL if mode == 1 else K.GLOW, colours.merged({"mode": mode, "billboard": mode != 1, "life": life, "p1": 0.8, "gain": gain}), xf, data, start, last + life + 0.1, {"fin": 0.01, "fout": 0.05})


## Leaves / feathers drifting and tumbling down (god_solid motion 3 on the feather mesh).
static func drift(r: K, paint: Dictionary, centre: Vector3, radius: float, count: int, height: float, size: float, start: float, hold: float, wind := Vector3.ZERO, salt := 0.0) -> void:
	if not r or count <= 0:
		return
	var xf := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 3.1 + salt)
		xf.append(K.standing(centre + K.scatter(k, count, radius, salt) + Vector3.UP * (height * (0.4 + 0.6 * s)), Vector3.ONE * size * (0.8 + 0.5 * s), s * TAU))
		data.append(Color(s * 0.35, s, 0, 0))
	r.swarm(K.mesh("feather"), K.SOLID, paint.merged({"motion": 3, "hold": hold, "drift": wind + Vector3(0, -height * 0.45 / hold, 0), "sway": 0.45, "tumble": 2.4}), xf, data, start, hold + 0.45, {"fin": 0.01, "fout": 0.05})


## A solid hero object (one mesh painted by god_solid).
static func solid(r: K, geometry: Mesh, paint: Dictionary, at: Vector3, size: Vector3, angles: Vector3, start: float, seconds: float, o := {}) -> MeshInstance3D:
	if not r:
		return null
	return r.add(geometry, K.SOLID, paint, at, size, angles, start, seconds, {"fin": 0.06, "fout": 0.25}.merged(o, true))


## A real projectile's carrier root (SkillTableau.flight): it holds only the body, named
## EssentialSkillProjectile, and is gone at the contact. null (root freed) when the body
## found no room: the shared essential projectile then flies instead.
static func essential(r: K, body: MeshInstance3D) -> K:
	if not r:
		return null
	if body == null:
		r.queue_free()
		return null
	body.name = "EssentialSkillProjectile"
	return r


## Ground spots inside a disc, the k-th of n.
static func spots(count: int, radius: float, salt := 0.0, centre := Vector3.ZERO) -> Array:
	var out := []
	for k in count:
		out.append(centre + K.scatter(k, count, radius, salt))
	return out


## Delays spread over [param span] seconds (deterministic jitter).
static func delays(count: int, span: float, salt := 0.0) -> Array:
	var out := []
	for k in count:
		out.append(span * clampf(float(k) / float(maxi(1, count - 1)) * 0.75 + 0.25 * K.rand(float(k) * 4.1 + salt), 0.0, 1.0))
	return out


## The real enemies a fan / volley skill reaches from [param origin] (ground spots).
static func fan_count(parent: Node, origin: Vector3, reach: float, hits: int) -> int:
	return mini(hits, foes(parent, origin, reach, hits).size())


# ---------------------------------------------------------------------------
# Meshes of this kit (white: god_solid tint / ember paint them), built once
# ---------------------------------------------------------------------------
static func mesh(kind: String) -> Mesh:
	if not _meshes.has(kind):
		match kind:
			"sword": _meshes[kind] = _sword()
			"hand": _meshes[kind] = _hand()
			"phoenix": _meshes[kind] = _phoenix()
			"wings": _meshes[kind] = _wings()
			"needle": _meshes[kind] = _needle()
			"petal": _meshes[kind] = _petal()
			"sector": _meshes[kind] = _sector(0.72)
			_: _meshes[kind] = K.mesh(kind)
	return _meshes[kind]


## A sword of light: the point at the origin, the blade back along +Y, a crossguard of
## three rays, a grip and a jewel pommel.
static func _sword() -> Mesh:
	var b := K.Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	var pale := Color(1, 1, 1, 0.8)
	b.emit = 0.9
	b.loft([
		[Vector3(0, 0.0, 0), x * 0.004, z * 0.002, Color.WHITE, 1.0, 1.0],
		[Vector3(0, 0.35, 0), x * 0.13, z * 0.035, Color.WHITE, 0.95, 1.0],
		[Vector3(0, 2.2, 0), x * 0.16, z * 0.04, Color(0.95, 0.95, 0.97), 0.8, 1.0],
		[Vector3(0, 2.45, 0), x * 0.17, z * 0.045, Color.WHITE, 0.85, 1.0]], 4)
	b.emit = 0.75
	b.tube([Vector3(-0.55, 2.5, 0), Vector3(0, 2.45, 0), Vector3(0.55, 2.5, 0)], [0.07, 0.1, 0.07], 5, Color.WHITE, Color.WHITE)
	for side in [-1.0, 1.0]:
		b.cone(Vector3(side * 0.5, 2.5, 0), Vector3(side * 0.82, 2.72, 0), 0.07, 4, Color.WHITE, pale)
	b.emit = 0.45
	b.tube([Vector3(0, 2.5, 0), Vector3(0, 3.05, 0)], [0.055, 0.05], 5, Color(0.85, 0.85, 0.9), Color(0.85, 0.85, 0.9))
	b.emit = 1.0
	b.ball(Vector3(0, 3.14, 0), Vector3.ONE * 0.11, Color.WHITE, pale, 6, 4)
	return b.commit()


## An open hand of light, palm towards +Z, fingers up (+Y), the wrist at the origin.
static func _hand() -> Mesh:
	var b := K.Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	b.emit = 0.55
	# Palm: a soft slab.
	b.loft([
		[Vector3(0, 0.0, 0), x * 0.2, z * 0.09, Color(0.9, 0.9, 0.95)],
		[Vector3(0, 0.35, 0.01), x * 0.3, z * 0.12, Color.WHITE],
		[Vector3(0, 0.75, 0.02), x * 0.34, z * 0.12, Color.WHITE],
		[Vector3(0, 0.98, 0.0), x * 0.3, z * 0.1, Color.WHITE],
		[Vector3(0, 1.04, 0.0), x * 0.18, z * 0.06, Color.WHITE]], 10)
	# Four fingers, gently spread and curled, and the thumb.
	var fingers := [[-0.24, 0.62, -0.18], [-0.08, 0.78, -0.05], [0.08, 0.74, 0.05], [0.24, 0.58, 0.16]]
	b.emit = 0.6
	for f in fingers:
		var root := Vector3(float(f[0]), 0.96, 0.0)
		var length := float(f[1])
		var lean := float(f[2])
		var mid := root + Vector3(lean * 0.35, length * 0.55, 0.03)
		var tip := root + Vector3(lean * 0.6, length, 0.1)
		b.tube(K.Build.bezier(root, mid, tip, 5), [0.085, 0.08, 0.075, 0.07, 0.06, 0.035], 6, Color.WHITE, Color(1, 1, 1, 0.85))
	b.tube(K.Build.bezier(Vector3(-0.3, 0.3, 0.02), Vector3(-0.6, 0.55, 0.12), Vector3(-0.62, 0.9, 0.2), 5), [0.1, 0.09, 0.08, 0.07, 0.06, 0.035], 6, Color.WHITE, Color(1, 1, 1, 0.85))
	return b.commit()


## A heraldic phoenix with spread wings (facing +Z, its body upright, the tail streaming
## down): the wings are the kit's feathered wings, so god_solid's flap beats them.
static func _phoenix() -> Mesh:
	var b := K.Build.new()
	var x := Vector3(1, 0, 0)
	var z := Vector3(0, 0, 1)
	var gold := Color("ffe9a0")
	var flame := Color("ffb15a")
	var deep := Color("ff7a3a")
	b.xf = Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.1))
	for side in [-1.0, 1.0]:
		K._wing(b, side, 1, Vector3(side * 0.16, 2.6, 0), 34.0, 3.1, Color("ffd27a"))
		K._wing(b, side, 2, Vector3(side * 0.16, 2.35, 0), -2.0, 2.6, Color("ff9a4a"))
	b.xf = Transform3D.IDENTITY
	b.emit = 0.6
	# Body: breast to tail root.
	b.loft([
		[Vector3(0, 1.45, -0.05), x * 0.06, z * 0.06, deep],
		[Vector3(0, 1.85, 0.0), x * 0.26, z * 0.24, flame],
		[Vector3(0, 2.45, 0.05), x * 0.32, z * 0.28, gold],
		[Vector3(0, 2.95, 0.08), x * 0.2, z * 0.18, gold],
		[Vector3(0, 3.25, 0.1), x * 0.12, z * 0.12, gold]], 8)
	# Head, beak, crest.
	b.emit = 0.8
	b.ball(Vector3(0, 3.42, 0.14), Vector3(0.2, 0.22, 0.2), Color.WHITE, gold, 8, 5)
	b.cone(Vector3(0, 3.38, 0.3), Vector3(0, 3.28, 0.62), 0.07, 4, Color("ffd060"), Color("ff9a30"))
	for k in 3:
		var a := -0.5 + 0.5 * float(k)
		b.tube(K.Build.bezier(Vector3(0, 3.55, 0.08), Vector3(a * 0.3, 3.95, -0.1), Vector3(a * 0.55, 4.25 - 0.1 * absf(a), -0.35), 5), [0.06, 0.05, 0.04, 0.03, 0.02, 0.005], 4, gold, deep)
	# The tail: long streaming plumes.
	b.emit = 0.75
	for k in 5:
		var a := (float(k) - 2.0) * 0.32
		b.feather(Vector3(0, 1.6, -0.05), Vector3(sin(a) * 1.0, -2.2 + absf(a) * 0.5, -0.15), 0.42, Vector3(0, 0, 1), flame, deep)
	return b.commit()


## A pair of great wings of light (two pairs each side) round their shoulders at the
## origin's height 0: the kit's feathered wings, beaten by god_solid's flap / spread.
static func _wings() -> Mesh:
	var b := K.Build.new()
	for side in [-1.0, 1.0]:
		K._wing(b, side, 1, Vector3(side * 0.16, 0.0, 0), 38.0, 2.8, Color("fff0c0"))
		K._wing(b, side, 2, Vector3(side * 0.16, -0.2, 0), 2.0, 2.4, Color("ffe08a"))
	return b.commit()


## A clock hand: a slim flat blade from the origin along +Z with a diamond near its tip.
static func _needle() -> Mesh:
	var b := K.Build.new()
	b.emit = 0.9
	var up := Vector3(0, 0.012, 0)
	b.quad(Vector3(-0.05, 0, -0.1) + up, Vector3(0.05, 0, -0.1) + up, Vector3(0.02, 0, 0.8) + up, Vector3(-0.02, 0, 0.8) + up)
	b.quad(Vector3(0, 0, 0.72) + up, Vector3(0.09, 0, 0.84) + up, Vector3(0, 0, 1.0) + up, Vector3(-0.09, 0, 0.84) + up)
	b.ball(Vector3(0, 0.01, 0), Vector3(0.08, 0.02, 0.08), Color.WHITE, Color.WHITE, 6, 3)
	return b.commit()


## A lotus petal of light: a curved leaf standing up from the origin, opening towards +Z.
static func _petal() -> Mesh:
	var b := K.Build.new()
	b.emit = 0.7
	var rings := []
	for i in 7:
		var t := float(i) / 6.0
		var w := sin(t * PI) * 0.32 + 0.01
		rings.append([Vector3(0, t * 1.0, 0.25 * t * t), Vector3(w, 0, 0), Vector3(0, 0, w * 0.18), Color(1, 1, 1, 1).lerp(Color(1, 1, 1, 0.7), t), 0.6 + 0.4 * t, 1.0])
	b.loft(rings, 8)
	return b.commit()


## A flat wedge lying on the ground (XZ), its apex at the origin, opening along +Z with
## [param half] radians each side, radius 1: UV.x runs across it, UV.y is 1 at the apex
## (god_glow mode 16 draws a gust out of the apex along it).
static func _sector(half: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var rows := 6
	var point := func(i: int, j: int) -> Array:
		var a := lerpf(-half, half, float(i) / float(segs))
		var d := float(j) / float(rows)
		return [Vector3(sin(a) * d, 0, cos(a) * d), Vector2(float(i) / float(segs), 1.0 - d)]
	for i in segs:
		for j in rows:
			for corner in [[i, j], [i + 1, j + 1], [i + 1, j], [i, j], [i, j + 1], [i + 1, j + 1]]:
				var p: Array = point.call(corner[0], corner[1])
				st.set_normal(Vector3.UP)
				st.set_uv(p[1])
				st.add_vertex(p[0])
	return st.commit()


## A gust: a wedge of wind drawn out of [param at] along +Z (root space), [param reach] long.
static func gust(r: K, at: Vector3, reach: float, colours: Dictionary, start: float, seconds: float, gain := 0.5, yaw := 0.0, o := {}) -> void:
	if r:
		r.add(mesh("sector"), _shader(o), colours.merged({"mode": 16, "p1": 7.0, "p2": 0.8, "gain": gain, "life": seconds}), at, Vector3.ONE * reach, Vector3(0, yaw, 0), start, seconds, {"fin": 0.01, "fout": seconds * 0.3}.merged(o, true))


## Soft round clouds (alpha-blended discs) over a disc at [param centre].
static func clouds(r: K, centre: Vector3, radius: float, count: int, colours: Dictionary, size: float, start: float, seconds: float, gain := 0.7, salt := 0.0) -> void:
	if not r or count <= 0:
		return
	var cards := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 4.3 + salt)
		cards.append(K.card(centre + K.scatter(k, count, radius, salt) + Vector3.UP * 0.4 * s, size * (0.7 + 0.5 * s)))
		data.append(Color(0.04 * float(k), s, 0, 0))
	r.swarm(K.mesh("quad"), K.VEIL, colours.merged({"mode": 0, "p1": 1.6, "billboard": true, "life": seconds, "drift": Vector3(0.15, 0, 0), "grow": Vector2(0.75, 1.1), "gain": gain}), cards, data, start, seconds + 0.04 * count, {"fin": 0.2, "fout": 0.4, "priority": -2})
