extends RefCounted
## Team "blade" kit: the Warrior and Lancer Lv.60-100 class skills' signature art
## (combat/skill_art/<skill id>.gd, SkillSignature). Built on the god melee kit
## (combat/god_art/_kit_melee.gd: its SOLID / FLAT / BITS shaders and mesh builders) and the
## melee star kit (combat/star_art/_melee.gd: arcs, shock rings, flashes, fissures, sparks,
## rubble, dust, the lance and the shield). Cosmetic ONLY: the hero / companion code owns
## every hit, target, buff and timing.
##
## A cast is a few StarSkillArt roots (one clock each, the 2/4/6 layer cap of the quality,
## one VfxBudget decoration per layer, every layer built at once and shown on its own
## delay, so a later beat costs nothing later). Their names carry the skill id.
##   wind-up roots   bound to the caster's skill motion (HeroVisual.skill_generation): a
##                   cancelled or interrupted wind-up takes them down at once
##   release roots   bound to a Watch on the caster: the caster dying or leaving fades
##                   them out within StarSkillArt.CLOSE
## How much a cast may draw (tier 0..2) follows the quality, the memory pressure and who
## casts: the player's own hero (VfxBudget.for_hero) gets everything the quality allows;
## companions, AI players and rivals draw only the core root of each beat (tier 0), so a
## guild war full of casters never tanks the frame rate. Meshes are cached statics.
const K := preload("res://combat/god_art/_kit_melee.gd")
const M := preload("res://combat/star_art/_melee.gd")
const PREFIX := "SkillArt_"
## Recent wind-ups (to find the caster again at the release): {id, visual, at, aim, ms}.
static var _recent: Array = []


## Watches a caster: frees itself when the caster dies, is freed, or [member until] passes;
## the release roots bound to it then fade out (StarSkillArt.cast_ref).
class Watch extends Node:
	var caster: WeakRef
	var until := 3.0
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		var c: Object = caster.get_ref() if caster else null
		if age >= until or not is_instance_valid(c) or Watch.dead(c):
			queue_free()

	static func dead(c: Object) -> bool:
		if c.has_method("is_dead"):
			return bool(c.call("is_dead"))
		var d: Variant = c.get("_dead")
		return d is bool and d


# ---------------------------------------------------------------------------
# Colour helpers
# ---------------------------------------------------------------------------
static func a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## A tinted hot core: the colour brightened, never plain white.
static func hot(color: Color, alpha := 1.0) -> Color:
	return M.hot(color, alpha)


## A gentler core for long bright strokes (trails, beams) that must never read white.
static func warm(color: Color, alpha := 1.0) -> Color:
	var c := color.lerp(Color.WHITE, 0.15)
	return Color(c.r, c.g, c.b, alpha)


# ---------------------------------------------------------------------------
# The cast
# ---------------------------------------------------------------------------
static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## How much this cast may draw: 2 everything, 1 trimmed, 0 the core only. Companions, AI
## players and rivals (anything but the player's own hero) always draw the core only: in a
## guild war dozens of them cast at once.
static func tier(hero: bool) -> int:
	if not hero:
		return 0
	return clampi(VfxBudget.quality() - MemoryGuard.pressure, 0, 2)


static func _remember(id: String, visual: HeroVisual, at: Vector3, aim: Vector3) -> void:
	var now := Time.get_ticks_msec()
	_recent = _recent.filter(func(e: Dictionary) -> bool: return now - int(e.ms) < 4000 and (e.visual as WeakRef).get_ref() != null)
	if visual:
		_recent.append({"id": id, "visual": weakref(visual), "at": at, "aim": aim, "ms": now})
	if _recent.size() > 48:
		_recent = _recent.slice(_recent.size() - 48)


## The latest wind-up of [param id] cast from about [param at]: {visual, aim} or {}.
static func _recall(id: String, at: Vector3) -> Dictionary:
	var best := {}
	var near := 2.5
	for e in _recent:
		if String(e.id) != id:
			continue
		var visual := (e.visual as WeakRef).get_ref() as HeroVisual
		if not is_instance_valid(visual):
			continue
		var d := flat(visual.global_position - at).length() if visual.is_inside_tree() else flat(e.at - at).length()
		if d <= near:
			near = d
			best = e
	return best


## The caster of a HeroVisual (the hero, a companion, a player): its parent, as a rule.
static func _caster_of(visual: HeroVisual) -> Node:
	if not is_instance_valid(visual):
		return null
	var p := visual.get_parent()
	while p and not (p.has_method("is_dead") or p.get("_dead") != null):
		p = p.get_parent() if not p is Window else null
	return p


## The context of one beat: {parent, skill, id, origin, center, fwd, hero, tier, visual, watch}.
static func cast(parent: Node3D, skill: Dictionary, origin: Vector3, center: Vector3, visual: HeroVisual = null) -> Dictionary:
	var id := String(skill.get("id", ""))
	var aim := center
	if visual == null:
		var e := _recall(id, origin)
		if not e.is_empty():
			visual = (e.visual as WeakRef).get_ref() as HeroVisual
			aim = e.aim if flat(center - origin).length_squared() < 0.04 else center
	var fwd := flat(aim - origin)
	if fwd.length_squared() < 0.04 and is_instance_valid(visual) and visual.is_inside_tree():
		fwd = flat(visual.global_basis.z)
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.BACK
	var hero := VfxBudget.for_hero()
	return {"parent": parent, "skill": skill, "id": id, "origin": flat(origin) + Vector3.UP * origin.y,
		"center": center, "fwd": fwd, "hero": hero, "tier": tier(hero), "visual": visual, "watch": null}


## A root of the cast at [param at] (world), facing the cast's forward. [param need]: the
## tier it needs (0: always). Release roots are tied to the caster's Watch.
static func open(c: Dictionary, at: Vector3, seconds: float, tag: String, need := 0) -> StarSkillArt:
	if int(c.tier) < need or not is_instance_valid(c.parent) or not (c.parent as Node).is_inside_tree():
		return null
	if not VfxBudget.can_decorate(2):
		return null
	var art := StarSkillArt._root(c.parent, at, seconds, PREFIX + String(c.id) + "_" + tag)
	if art == null:
		return null
	var f: Vector3 = c.fwd
	art.rotation.y = atan2(f.x, f.z)
	var visual: HeroVisual = c.visual
	if bool(c.get("windup", false)):
		if is_instance_valid(visual):
			art.generation_ref = weakref(visual)
			art.generation = visual.skill_generation
		return art
	var watch := _watch(c)
	if watch:
		art.cast_ref = weakref(watch)
		art.cast_until = art.lifetime + 0.1
		watch.until = maxf(watch.until, art.lifetime + 0.2)
	return art


static func _watch(c: Dictionary) -> Watch:
	var w: Watch = c.watch
	if is_instance_valid(w):
		return w
	var caster := _caster_of(c.visual)
	if caster == null:
		return null
	w = Watch.new()
	w.name = "SkillArtWatch_" + String(c.id)
	w.caster = weakref(caster)
	(c.parent as Node).add_child(w)
	c.watch = w
	return w


## The wind-up's context: like [method cast], its roots bound to the skill motion.
static func windup(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, visual: HeroVisual) -> Dictionary:
	_remember(String(skill.get("id", "")), visual, origin, aim)
	var c := cast(parent, skill, origin, aim, visual)
	c.windup = true
	return c


## Ground under [param p].
static func ground(p: Vector3, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.z)


## The living foes within [param radius] of [param at] (world ground positions), nearest first.
static func foes(node: Node, at: Vector3, radius: float, most := 12) -> Array:
	var out := []
	if not is_instance_valid(node) or not node.is_inside_tree():
		return out
	for item in node.get_tree().get_nodes_in_group("mobs"):
		var mob := item as Mob
		if mob and not mob.is_dead() and flat(mob.global_position - at).length() <= radius + mob.body_radius():
			out.append(mob)
	out.sort_custom(func(x: Mob, y: Mob) -> bool: return flat(x.global_position - at).length_squared() < flat(y.global_position - at).length_squared())
	return out.slice(0, most)


## The mob standing nearest [param at] (within 1.5 m), or null.
static func mob_at(node: Node, at: Vector3) -> Mob:
	var list := foes(node, at, 1.5, 1)
	return list[0] if not list.is_empty() else null


## The pierce line of a lancer thrust (Pierce.victims): [reach, the mobs on it in order].
static func pierce_line(c: Dictionary) -> Array:
	var spec: Dictionary = (c.skill as Dictionary).get("pierce", {})
	var reach := float(spec.get("len", 6.0))
	var target := mob_at(c.parent, c.center)
	var hit: Array = [target] if target else []
	if target:
		for extra in Pierce.victims((c.parent as Node).get_tree(), c.origin, target.global_position, spec, target):
			hit.append(extra)
	return [reach, hit]


## Local (root space) position of a world point for a root facing the cast's forward at origin.
static func local(c: Dictionary, world: Vector3, from: Vector3) -> Vector3:
	var f: Vector3 = c.fwd
	var right := Vector3(f.z, 0, -f.x)
	var d := world - from
	return Vector3(d.dot(right), d.y, d.dot(f))


# ---------------------------------------------------------------------------
# Layers (thin wrappers over K.put so each skill reads as a list of its beats)
# ---------------------------------------------------------------------------
## A FLAT light/shadow layer.
static func light(art: StarSkillArt, mesh: Mesh, label: String, at: Vector3, size: Vector3, seconds: float, params := {}, style := {}, angles := Vector3.ZERO) -> ShaderMaterial:
	if art == null:
		return null
	var p := {"soft": 0.7, "core": 0.45, "add": 0.6}
	p.merge(params, true)
	return K.put(art, K.FLAT, mesh, label, at, size, seconds, p, style, angles)


## A SOLID body layer.
static func body(art: StarSkillArt, mesh: Mesh, label: String, at: Vector3, size: Vector3, seconds: float, params := {}, style := {}, angles := Vector3.ZERO) -> ShaderMaterial:
	if art == null:
		return null
	return K.put(art, K.SOLID, mesh, label, at, size, seconds, params, style, angles)


## A BITS layer (debris, embers, feathers, dust).
static func bits(art: StarSkillArt, mesh: Mesh, label: String, at: Vector3, seconds: float, params := {}, style := {}, size := Vector3.ONE, angles := Vector3.ZERO) -> ShaderMaterial:
	if art == null:
		return null
	return K.put(art, K.BITS, mesh, label, at, size, seconds, params, style, angles)


# ---------------------------------------------------------------------------
# Mesh builders (cached in M's store under their key)
# ---------------------------------------------------------------------------
static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _done(key: String, st: SurfaceTool, pad := 0.5) -> ArrayMesh:
	return M.keep(key, K.finish(st, Vector3.ONE * pad, false))


## A slash of light: a crescent from angle a0 to a1 (0 is +Z) round the origin, radius r
## (to r1 at its end), height y0 to y1; a wide flat blade, an upright edge for depth and a
## dark back edge. UV.y runs along it (sweep it with "sweep" / "tail").
static func slash(key: String, r: float, a0: float, a1: float, y0: float, y1: float, width: float, body_color: Color, edge: Color, back: Color, r1 := -1.0, upright := 0.5) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	var rr := r if r1 < 0.0 else r1
	var pts := M.arc(Vector3.ZERO, r, a0, a1, y0, y1, 28, rr)
	K.ribbon(st, pts, width, body_color, 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, edge)
	if upright > 0.0:
		var mid := pts[pts.size() / 2]
		K.ribbon(st, pts, width * upright, a(body_color, body_color.a * 0.85), 0.0, 0.0, flat(mid).normalized(), 1.0)
	if back.a > 0.0:
		var inner := M.arc(Vector3.ZERO, r * 0.86, a0, a1, y0, y1, 28, rr * 0.88)
		K.ribbon(st, inner, width * 0.16, back, 0.0, 0.0, Vector3.UP, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return _done(key, st)


## A slash in a vertical plane (XY, facing +Z): an arc of radius r round the origin from
## angle a0 to a1 (0 is +Y, PI/2 is +X). Turn it with the layer's angles.
static func vslash(key: String, r: float, a0: float, a1: float, width: float, body_color: Color, edge: Color, back: Color) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	var pts := PackedVector3Array()
	var n := 28
	for i in n + 1:
		var t := float(i) / float(n)
		var ang := lerpf(a0, a1, t)
		var rad := r * (1.0 + 0.08 * sin(t * PI))
		pts.append(Vector3(sin(ang) * rad, cos(ang) * rad, 0.0))
	K.ribbon(st, pts, width, body_color, 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, edge)
	K.ribbon(st, pts, width * 0.45, a(body_color, body_color.a * 0.8), 0.0, 0.0, Vector3.UP, 1.0)
	if back.a > 0.0:
		var inner := PackedVector3Array()
		for p in pts:
			inner.append(p * 0.9)
		K.ribbon(st, inner, width * 0.16, back, 0.0, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	return _done(key, st)


## A ground spiral (n turns from r0 to r1), UV.y along it: a whirl mark or wind on the floor.
static func spiral(key: String, r0: float, r1: float, turns: float, width: float, color: Color, end_color := Color(0, 0, 0, -1), arms := 1, plain := false) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for k in arms:
		var pts := PackedVector3Array()
		var n := int(turns * 26.0) + 2
		for i in n + 1:
			var t := float(i) / float(n)
			var ang := t * turns * TAU + TAU * float(k) / float(arms)
			var rad := lerpf(r0, r1, t)
			pts.append(Vector3(sin(ang) * rad, 0.0, cos(ang) * rad))
		K.ribbon(st, pts, width, color, 0.0, 0.0, Vector3.UP, 0.6, 0.0, 1.0, end_color, plain)
	return _done(key, st)


## A funnel of wind round +Y: [param strands] helices rising from radius r0 at y 0 to r1
## at height h, [param turns] turns each; UV.y runs up (sweep / flow).
static func funnel(key: String, r0: float, r1: float, h: float, turns: float, strands: int, width: float, color: Color, top_color: Color) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for k in strands:
		var pts := PackedVector3Array()
		var n := int(turns * 22.0) + 2
		var phase := TAU * float(k) / float(strands)
		var hk := h * (0.75 + 0.25 * float((k * 7) % strands) / float(maxi(1, strands - 1)))
		for i in n + 1:
			var t := float(i) / float(n)
			var ang := t * turns * TAU + phase
			var rad := lerpf(r0, r1, t * t)
			pts.append(Vector3(sin(ang) * rad, t * hk, cos(ang) * rad))
		K.ribbon(st, pts, width * (0.8 + 0.4 * float(k % 2)), color, 0.0, 0.0, Vector3.UP, 0.8, 0.0, 1.0, top_color)
	return _done(key, st)


## A ground lane along +Z from z0 to z1: soft floor, two edges, chevrons pointing forward.
static func lane(key: String, z0: float, z1: float, width: float, floor_color: Color, edge: Color, chevrons := 6) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	K.ribbon(st, PackedVector3Array([Vector3(0, 0, z0), Vector3(0, 0, z1)]), width, floor_color, 0.0, 0.0, Vector3.UP, 0.0, 0.0, 1.0, Color(0, 0, 0, -1), true)
	for s in [-0.5, 0.5]:
		K.ribbon(st, PackedVector3Array([Vector3(s * width, 0, z0), Vector3(s * width * 0.85, 0, z1)]), 0.07, edge, 0.0, 0.0, Vector3.UP, 0.0)
	for i in chevrons:
		var z := lerpf(z0 + 0.4, z1 - 0.4, (float(i) + 0.5) / float(chevrons))
		var w := width * 0.32
		K.ribbon(st, PackedVector3Array([Vector3(-w, 0, z - 0.35), Vector3(0, 0, z), Vector3(w, 0, z - 0.35)]), 0.09, a(edge, edge.a * 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	return _done(key, st, 0.3)


## A long streak along +Z from 0 to 1 (crossed planes): the body of a thrust or a flight.
static func streak(key: String, width: float, color: Color, tip_color: Color, planes := 2) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for k in planes:
		var ang := PI * float(k) / float(planes)
		var up := Vector3(cos(ang), sin(ang), 0)
		K.ribbon(st, PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, 1.0)]), width, color, 0.0, 0.0, up, 0.0, 0.0, 1.0, tip_color)
	return _done(key, st, 0.3)


## Rings standing across +Z (a pierce's pressure rings): unit radius, in the XY plane.
static func hoop(key: String, color: Color, width := 0.16, sides := 40) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	var pts := PackedVector3Array()
	for i in sides + 1:
		var ang := TAU * float(i) / float(sides)
		pts.append(Vector3(sin(ang), cos(ang), 0.0))
	K.ribbon(st, pts, width, color, 0.0, 0.0, Vector3.BACK, 0.0)
	return _done(key, st, 0.3)


## A rune circle on the ground, radius 1: two rings, ticks and [param glyphs] small runes.
static func runes(key: String, color: Color, glyphs := 8, inner := 0.78) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	K.ring(st, 1.0, 0.045, color, 0.0, 72)
	K.ring(st, inner, 0.025, a(color, color.a * 0.8), 0.0, 64)
	for i in 36:
		var ang := TAU * float(i) / 36.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		K.ribbon(st, PackedVector3Array([dir * 0.955, dir * (0.92 if i % 3 else 0.88)]), 0.018, color, 0.0, 0.0, Vector3.UP, 0.0)
	for i in glyphs:
		var ang := TAU * (float(i) + 0.5) / float(glyphs)
		var mid := Vector3(sin(ang), 0, cos(ang)) * (inner + 1.0) * 0.5
		var side := Vector3(cos(ang), 0, -sin(ang))
		var out := Vector3(sin(ang), 0, cos(ang))
		var s := (1.0 - inner) * 0.32
		# A small angular rune: a stave and two strokes off it.
		K.ribbon(st, PackedVector3Array([mid - out * s, mid + out * s]), 0.022, color, 0.0, 0.0, Vector3.UP, 0.0)
		var k := rng.randi() % 3
		var b0 := mid + out * s * (0.6 if k == 0 else -0.2)
		K.ribbon(st, PackedVector3Array([b0, b0 + side * s * 0.8 - out * s * 0.5]), 0.02, color, 0.0, 0.0, Vector3.UP, 0.0)
		if k != 2:
			K.ribbon(st, PackedVector3Array([mid, mid - side * s * 0.8 + out * s * 0.4]), 0.02, color, 0.0, 0.0, Vector3.UP, 0.0)
	return _done(key, st, 0.2)


## Flame tongues standing round a circle of radius 1 (UV.y up): an aura of fire.
static func flames(key: String, count: int, h: float, width: float, base: Color, tip: Color, seed_value := 3) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var ang := TAU * float(i) / float(count) + rng.randf_range(-0.15, 0.15)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var side := Vector3(dir.z, 0, -dir.x)
		var hh := h * rng.randf_range(0.6, 1.1)
		var bend := rng.randf_range(-0.25, 0.25)
		var pts := PackedVector3Array()
		for k in 6:
			var t := float(k) / 5.0
			pts.append(dir * (1.0 - 0.35 * t) + side * bend * t * t + Vector3.UP * hh * t)
		var w := width * rng.randf_range(0.7, 1.2)
		K.ribbon(st, pts, w, base, 0.0, 0.0, dir, 1.0, 0.0, 1.0, tip)
		K.ribbon(st, pts, w * 0.8, base, 0.0, 0.0, side, 1.0, 0.0, 1.0, tip)
	return _done(key, st)


## A pair of wings in the XY plane (facing +Z), shoulders at the origin, about 1 high and
## 2.2 across: [param feathers] long flight feathers each side over a softer covert layer.
static func wings(key: String, feathers: int, color: Color, tip: Color, covert: Color, spread := 1.0) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for s in [-1.0, 1.0]:
		# The arm of the wing: out from the shoulder and up in an arch to the wrist.
		var arm := PackedVector3Array()
		for i in 9:
			var t := float(i) / 8.0
			arm.append(Vector3(s * (0.12 + 1.05 * t * spread), 0.15 + 0.62 * sin(t * PI * 0.62), 0.0))
		# Flight feathers hang off the arm, longer towards the tip and swept out there.
		for i in feathers:
			var t := float(i) / float(maxi(1, feathers - 1))
			var root := arm[int(round(t * 8.0))] + Vector3(0, -0.02, -0.01 * t)
			var ang := lerpf(0.05, 1.05, t * t)
			var dir := Vector3(sin(ang) * s, -cos(ang), 0)
			var length := lerpf(0.55, 0.95, t)
			var tipp := root + dir * length
			var pts := PackedVector3Array([root, root.lerp(tipp, 0.55) + Vector3(s * 0.04, 0, 0), tipp])
			K.ribbon(st, pts, lerpf(0.22, 0.18, t), color, 0.0, 0.0, Vector3.BACK, 0.55, 0.0, 1.0, tip)
		# Coverts: a softer scalloped row along the arm, over the roots of the feathers.
		for i in maxi(3, feathers - 2):
			var t := float(i) / float(maxi(1, feathers - 3))
			var root := arm[int(round(t * 8.0))] + Vector3(0, 0.03, 0.01)
			K.ribbon(st, PackedVector3Array([root, root + Vector3(s * 0.05, -0.18, 0), root + Vector3(s * 0.04, -0.34, 0)]), 0.24, covert, 0.0, 0.0, Vector3.BACK, 0.8, 0.0, 1.0, a(covert, 0.2))
		K.ribbon(st, arm, 0.12, a(tip, 0.95), 0.0, 0.0, Vector3.BACK, 0.3)
	return _done(key, st)


## Speed lines streaming back along -Z from a box round the origin (UV.y backward).
static func speedlines(key: String, count: int, length: float, color: Color, seed_value := 5, radius := 0.9, h0 := 0.2, h1 := 1.9) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var ang := rng.randf() * TAU
		var p := Vector3(cos(ang) * radius * rng.randf_range(0.6, 1.2), rng.randf_range(h0, h1), rng.randf_range(-0.3, 0.6))
		var l := length * rng.randf_range(0.5, 1.0)
		K.ribbon(st, PackedVector3Array([p, p - Vector3(0, 0, l * 0.5), p - Vector3(0, 0, l)]), rng.randf_range(0.05, 0.11), color, 0.0, 0.0, Vector3(p.x, p.y - 1.0, 0).normalized() if absf(p.x) > 0.01 else Vector3.UP, 0.7, 0.0, 1.0, a(color, 0.0))
	return _done(key, st)


## Bits thrown INWARD from a ring of radius r (gathering power): one BITS mesh.
static func gather(key: String, shape: String, count: int, r: float, speed: float, up: float, colors: Array, piece: float, seed_value := 1, y0 := 0.1, y1 := 1.6, spread := 0.2) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var ang := rng.randf() * TAU
		var dir := Vector3(sin(ang), 0, cos(ang))
		var origin := dir * r * rng.randf_range(0.8, 1.1) + Vector3.UP * rng.randf_range(y0, y1)
		var swirl := Vector3(dir.z, 0, -dir.x) * rng.randf_range(0.2, 0.5)
		var vel := (-dir + swirl) * speed * rng.randf_range(0.7, 1.0) + Vector3.UP * up * rng.randf_range(0.3, 1.0)
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.5, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, rng.randf() * spread, piece, basis)
	return M.keep(key, K.finish(st, Vector3(r + speed + 4.0, up + 6.0, r + speed + 4.0), false))


## Bits thrown round a ring TANGENTIALLY (a whirl flinging sparks): one BITS mesh.
static func whirl(key: String, shape: String, count: int, r0: float, r1: float, speed: float, up: float, colors: Array, piece: float, seed_value := 1, turn := 1.0, y0 := 0.3, y1 := 1.6) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var ang := rng.randf() * TAU
		var dir := Vector3(sin(ang), 0, cos(ang))
		var tangent := Vector3(dir.z, 0, -dir.x) * turn
		var origin := dir * lerpf(r0, r1, rng.randf()) + Vector3.UP * rng.randf_range(y0, y1)
		var vel := (tangent * 0.8 + dir * 0.6) * speed * rng.randf_range(0.6, 1.0) + Vector3.UP * up * rng.randf_range(0.2, 1.0)
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.5, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, rng.randf() * 0.12, piece, basis)
	return M.keep(key, K.finish(st, Vector3(r1 + speed + 4.0, up + 6.0, r1 + speed + 4.0), false))


## Bits falling gently from the sky over a disc (feathers, petals, motes).
static func fall(key: String, shape: String, count: int, r: float, h0: float, h1: float, colors: Array, piece: float, seed_value := 1, spread := 0.8) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var ang := rng.randf() * TAU
		var origin := Vector3(sin(ang), 0, cos(ang)) * r * sqrt(rng.randf()) + Vector3.UP * rng.randf_range(h0, h1)
		var vel := Vector3(rng.randf_range(-0.4, 0.4), -rng.randf_range(0.8, 1.6), rng.randf_range(-0.4, 0.4))
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.6, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, rng.randf() * spread, piece, basis)
	return M.keep(key, K.finish(st, Vector3(r + 3.0, h1 + 4.0, r + 3.0), false))


## Bits thrown along a line (+Z from z0 to z1): debris kicked up along a thrust.
static func line_burst(key: String, shape: String, count: int, z0: float, z1: float, width: float, out: float, up: float, colors: Array, piece: float, seed_value := 1, forward := 0.0, spread := 0.0) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var t := rng.randf()
		var x := rng.randf_range(-width, width)
		var origin := Vector3(x, rng.randf_range(0.05, 0.5), lerpf(z0, z1, t))
		var vel := Vector3(signf(x) * out * rng.randf_range(0.3, 1.0), up * rng.randf_range(0.4, 1.0), forward * rng.randf_range(0.3, 1.0))
		var color: Color = colors[rng.randi() % colors.size()]
		var size := piece * rng.randf_range(0.45, 1.0)
		var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * size)
		K.bit(st, K._bit_shape(shape, rng, color), origin, vel, spread * t, piece, basis)
	return M.keep(key, K.finish(st, Vector3(width + out + 5.0, up + 8.0, z1 + forward + 5.0), false))


## Rock spikes (a SOLID formation) bursting up along +Z from z0 to z1, staggered by
## distance over [param stagger] seconds; they rise from [param drop] metres below.
static func spikes_line(key: String, count: int, z0: float, z1: float, width: float, height: float, rock: Color, glow: Color, stagger := 0.2, seed_value := 1) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := K.begin()
	for i in count:
		var t := (float(i) + rng.randf()) / float(count)
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(side * width * rng.randf_range(0.4, 1.0), -0.1, lerpf(z0, z1, t))
		var h := height * rng.randf_range(0.6, 1.1)
		var lean := Basis(Vector3.BACK, -side * rng.randf_range(0.2, 0.45)) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.1))
		var part := K.spike(rng, rock, 0.25)
		if glow.a > 0.0:
			part.ink(glow, 0.0, 1.0)
			part.box(Vector3(0, 0.3, 0), Vector3(0.06, 0.5, 0.06))
		K.stamp(st, part, Transform3D(lean.scaled(Vector3(h * 0.6, h, h * 0.6)), at), stagger * t, 1.0)
	return M.keep(key, K.finish(st, Vector3(1, height + 3.0, 1)))


## Rock spikes in a ring of radius r (SOLID), staggered round it.
static func spikes_ring(key: String, count: int, r: float, height: float, rock: Color, glow: Color, stagger := 0.15, seed_value := 1) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := K.begin()
	for i in count:
		var ang := TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var at := dir * r * rng.randf_range(0.9, 1.05) + Vector3.DOWN * 0.1
		var h := height * rng.randf_range(0.6, 1.1)
		var lean := Basis(Vector3(dir.z, 0, -dir.x), rng.randf_range(0.25, 0.5))
		var part := K.spike(rng, rock, 0.2)
		if glow.a > 0.0:
			part.ink(glow, 0.0, 1.0)
			part.box(Vector3(0, 0.3, 0), Vector3(0.06, 0.5, 0.06))
		K.stamp(st, part, Transform3D(lean.scaled(Vector3(h * 0.6, h, h * 0.6)), at), stagger * float(i) / float(count), 1.0)
	return M.keep(key, K.finish(st, Vector3(1, height + 3.0, 1)))


## Hoops standing across +Z from z0 to z1 (pressure rings round a thrust), each lit
## [param per] seconds per metre after the first, growing in radius along the line.
static func hoops(key: String, count: int, z0: float, z1: float, r0: float, r1: float, color: Color, per := 0.0, y := 1.1, width := 0.16) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for i in count:
		var t := float(i) / float(maxi(1, count - 1))
		var z := lerpf(z0, z1, t)
		var r := lerpf(r0, r1, t)
		var pts := PackedVector3Array()
		for k in 33:
			var ang := TAU * float(k) / 32.0
			pts.append(Vector3(sin(ang) * r, y + cos(ang) * r, z))
		K.ribbon(st, pts, width, color, (z - z0) * per, 0.0, Vector3.BACK, 0.0)
	return _done(key, st)


## Flame tongues standing along +Z from z0 to z1, kindled [param per] s per metre.
static func flame_line(key: String, count: int, z0: float, z1: float, spread: float, h: float, width: float, base: Color, tip: Color, per := 0.0, seed_value := 1) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := _st()
	for i in count:
		var z := lerpf(z0, z1, (float(i) + rng.randf()) / float(count))
		var x := rng.randf_range(-spread, spread)
		var hh := h * rng.randf_range(0.5, 1.0) * (1.0 - 0.4 * absf(x) / maxf(spread, 0.01))
		var bend := rng.randf_range(-0.3, 0.3)
		var pts := PackedVector3Array()
		for k in 6:
			var t := float(k) / 5.0
			pts.append(Vector3(x + bend * t * t, hh * t, z + 0.15 * t))
		# Two crossed planes, so a tongue reads from any side.
		var w := width * rng.randf_range(0.7, 1.2)
		K.ribbon(st, pts, w, base, (z - z0) * per, 0.0, Vector3.BACK, 1.0, 0.0, 1.0, tip)
		K.ribbon(st, pts, w * 0.85, base, (z - z0) * per, 0.0, Vector3.RIGHT, 1.0, 0.0, 1.0, tip)
	return _done(key, st)


## A serpent of light along +Z from z0 to z1 (a dragon's body): a wide band weaving
## [param waves] times with amplitude [param amp] side to side and up and down.
static func serpent(key: String, z0: float, z1: float, amp: float, waves: float, width: float, color: Color, tail_color: Color, y := 1.2) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	var pts := PackedVector3Array()
	var n := int((z1 - z0) * 3.0) + 8
	for i in n + 1:
		var t := float(i) / float(n)
		var ph := t * waves * TAU
		pts.append(Vector3(sin(ph) * amp, y + cos(ph * 0.5) * amp * 0.35, lerpf(z0, z1, t)))
	K.ribbon(st, pts, width, tail_color, 0.0, 0.0, Vector3.UP, 0.3, 0.0, 1.0, color)
	K.ribbon(st, pts, width * 0.55, a(color, color.a * 0.85), 0.0, 0.0, Vector3.RIGHT, 0.3, 0.0, 1.0, color)
	return _done(key, st)


## Forward chevrons (arrowheads of light) flat on the ground, pointing +Z, [param gap] apart.
static func chevrons(key: String, count: int, color: Color, gap := 0.45, width := 0.18) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for i in count:
		var z := float(i) * gap
		K.ribbon(st, PackedVector3Array([Vector3(-0.55, 0, z - 0.45), Vector3(0, 0, z), Vector3(0.55, 0, z - 0.45)]), width, color, 0.0, 0.0, Vector3.UP, 0.0, float(i) / float(count), float(i + 1) / float(count))
	return _done(key, st)


## Lances in a ring of radius r pointing along the spin and a little out (a whirl of
## spears): one SOLID mesh.
static func lance_ring(key: String, count: int, r: float, length: float, shaft: Color, metal: Color, glow: Color, y := 1.0, tilt := 0.0) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := K.begin()
	var part := M.lance(shaft, metal, glow)
	for i in count:
		var ang := TAU * float(i) / float(count)
		var dir := Vector3(sin(ang), 0, cos(ang))
		var tangent := Vector3(-dir.z, 0, dir.x)
		var fwd := (tangent * 0.85 + dir * 0.5 + Vector3.UP * tilt).normalized()
		var basis := Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		K.stamp(st, part, Transform3D(basis.scaled(Vector3.ONE * length), dir * r - fwd * length * 0.5 + Vector3.UP * (y + 0.3 * sin(ang * 3.0))), 0.0, 0.0)
	return M.keep(key, K.finish(st, Vector3.ONE))


## The flares of a pierce: for each foe on the line a standing flash and a ring round the
## thrust, lit when the thrust reaches it ([param speed] m/s from [param from]), sparks
## thrown. Two layers on [param art] (a root with no rotation).
static func pierce_hits(art: StarSkillArt, c: Dictionary, victims: Array, from: Vector3, color: Color, accent: Color, speed: float, size := 1.2) -> void:
	if art == null or victims.is_empty():
		return
	var at := art.global_position
	var flares := _st()
	var spray := _st()
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	var dir: Vector3 = c.fwd
	var u := dir.cross(Vector3.UP).normalized()
	for mob in victims:
		if not is_instance_valid(mob):
			continue
		var p: Vector3 = (mob as Mob).global_position + Vector3.UP * 1.0
		var when := flat(p - from).length() / maxf(speed, 1.0)
		K.disc(flares, size * 1.1, a(color, 0.95), 0.0, 16, when, dir, p - at, a(accent, 0.0), -1.0)
		var ring := PackedVector3Array()
		for k in 25:
			var ang := TAU * float(k) / 24.0
			ring.append(p - at + (u * cos(ang) + Vector3.UP * sin(ang)) * size * 0.8)
		K.ribbon(flares, ring, 0.18, a(accent, 1.0), when, 0.0, dir, 0.0)
		K.burst_at(spray, rng, "ember", 7, flat(p - at) + Vector3.UP * 0.5, 0.1, 0.4, 3.5, 3.0, [color, accent], 0.13, when, 0.03, 0.4, 1.0)
	light(art, K.finish(flares, Vector3.ONE * 0.5, false), "PierceFlares", Vector3.ZERO, Vector3.ONE, 1.0, {"soft": 0.8, "hot": hot(accent), "add": 0.7, "flash": 0.3}, {"fade_in": 0.01, "decay": 0.85})
	bits(art, K.finish(spray, Vector3.ONE * 8.0, false), "PierceSpray", Vector3.ZERO, 1.2, {"life": 0.6, "gravity": 7.0, "drag": 1.5, "piece": 0.13, "add": 0.75, "shrink": 0.3})


# ---------------------------------------------------------------------------
# Solid parts
# ---------------------------------------------------------------------------
## A broadsword: grip on the origin, point at +Y 1; a wide blade with a glowing fuller,
## a winged crossguard and a gem in the pommel.
static func sword(blade: Color, guard: Color, glow: Color, grip := Color("4a2a1a"), wide := 0.07) -> K.Part:
	var p := K.Part.new()
	p.ink(grip, 0.2)
	p.tube(Vector3(0, -0.02, 0), Vector3(0, 0.17, 0), 0.03, 0.028, 6)
	p.ink(guard, 0.9)
	p.ball(Vector3(0, -0.04, 0), Vector3(0.045, 0.045, 0.045), 6, 3)
	var k := wide / 0.07
	p.box(Vector3(0, 0.19, 0), Vector3(0.3 * k, 0.04 * sqrt(k), 0.07))
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.15 * k, 0.19, 0), Vector3(s * 0.21 * k, 0.26, 0), 0.03 * sqrt(k), 0.0, 4, 0.6)
	p.ink(glow, 0.0, 1.0)
	p.gem(Vector3(0, 0.19, 0.04), Vector3(0.035, 0.035, 0.025))
	p.ink(blade, 1.0)
	var out := PackedVector2Array([Vector2(-wide, 0.21), Vector2(wide, 0.21), Vector2(wide * 0.93, 0.84), Vector2(0.0, 1.0), Vector2(-wide * 0.93, 0.84)])
	p.slab(out, -0.016 * sqrt(k), 0.016 * sqrt(k))
	p.ink(glow, 0.0, 1.0)
	p.box(Vector3(0, 0.5, 0), Vector3(0.022 * k, 0.52, 0.036 * sqrt(k)))
	return p


## A round Norse shield, face to +Z, radius 1: boss, rim, four painted quarters.
static func round_shield(field_a: Color, field_b: Color, rim: Color, boss: Color) -> K.Part:
	var p := K.Part.new()
	var n := 16
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var c0 := Vector3(sin(a0), cos(a0), 0)
		var c1 := Vector3(sin(a1), cos(a1), 0)
		p.ink(field_a if (i / 4) % 2 == 0 else field_b, 0.4)
		p.tri(Vector3(0, 0, 0.08), c0 * 0.9 + Vector3(0, 0, 0.03), c1 * 0.9 + Vector3(0, 0, 0.03))
		p.tri(Vector3(0, 0, -0.04), c1 * 0.9, c0 * 0.9)
		p.ink(rim, 0.8)
		p.quad(c0 * 0.9 + Vector3(0, 0, 0.03), c0 + Vector3(0, 0, 0.02), c1 + Vector3(0, 0, 0.02), c1 * 0.9 + Vector3(0, 0, 0.03))
		p.quad(c0, c0 + Vector3(0, 0, -0.05), c1 + Vector3(0, 0, -0.05), c1)
	p.ink(boss, 1.0, 0.3)
	p.ball(Vector3(0, 0, 0.1), Vector3(0.22, 0.22, 0.14), 8, 4)
	return p


## A cartoon dragon's head facing +Z, about 1 long: snout, jaws, horns, eyes, a mane.
static func dragon_head(scale_color: Color, belly: Color, horn: Color, eye: Color) -> K.Part:
	var p := K.Part.new()
	# Skull and upper snout, the brow ridges over the eyes.
	p.ink(scale_color, 0.5)
	p.ball(Vector3(0, 0.04, 0.0), Vector3(0.3, 0.27, 0.32), 9, 5)
	p.tube(Vector3(0, 0.08, 0.12), Vector3(0, 0.05, 0.7), 0.2, 0.12, 7, 0.75)
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.1, 0.2, 0.08), Vector3(s * 0.16, 0.26, 0.32), 0.07, 0.03, 5, 0.6)
	# The lower jaw hanging open in a roar, the dark mouth and the fangs.
	p.ink(belly, 0.3)
	p.tube(Vector3(0, -0.1, 0.06), Vector3(0, -0.36, 0.58), 0.14, 0.07, 6, 0.6)
	p.ink(Color("5a0e0a"), 0.2)
	p.tube(Vector3(0, -0.02, 0.14), Vector3(0, -0.12, 0.6), 0.11, 0.05, 6, 0.55)
	p.ink(Color("fff4dc"), 0.8)
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.09, 0.0, 0.62), Vector3(s * 0.09, -0.14, 0.64), 0.03, 0.0, 4)
		p.tube(Vector3(s * 0.12, -0.0, 0.4), Vector3(s * 0.12, -0.12, 0.41), 0.024, 0.0, 4)
		p.tube(Vector3(s * 0.06, -0.3, 0.52), Vector3(s * 0.06, -0.16, 0.54), 0.026, 0.0, 4)
	# Long horns swept back, ear frills, whiskers off the snout.
	p.ink(horn, 0.9)
	for s in [-1.0, 1.0]:
		p.tube(Vector3(s * 0.16, 0.22, -0.04), Vector3(s * 0.3, 0.45, -0.4), 0.075, 0.035, 5)
		p.tube(Vector3(s * 0.3, 0.45, -0.4), Vector3(s * 0.34, 0.5, -0.75), 0.035, 0.0, 4)
		p.tube(Vector3(s * 0.24, 0.0, -0.08), Vector3(s * 0.52, 0.06, -0.36), 0.05, 0.0, 4, 0.5)
		p.tube(Vector3(s * 0.12, 0.02, 0.66), Vector3(s * 0.42, -0.1, 0.5), 0.02, 0.006, 3)
		p.tube(Vector3(s * 0.42, -0.1, 0.5), Vector3(s * 0.6, -0.3, 0.2), 0.006, 0.0, 3)
	# The mane: a crest of spines down the back of the head.
	p.ink(scale_color.darkened(0.25), 0.4)
	for i in 6:
		var z := -0.1 - 0.12 * float(i)
		p.tube(Vector3(0, 0.24 - 0.04 * float(i), z), Vector3(0, 0.5 - 0.05 * float(i), z - 0.16), 0.06, 0.0, 4, 0.4)
	# Big glowing eyes, the nostrils.
	p.ink(eye, 0.0, 1.0)
	for s in [-1.0, 1.0]:
		p.gem(Vector3(s * 0.17, 0.15, 0.22), Vector3(0.07, 0.05, 0.04))
	p.ink(scale_color.darkened(0.45), 0.5)
	for s in [-1.0, 1.0]:
		p.gem(Vector3(s * 0.06, 0.13, 0.68), Vector3(0.03, 0.022, 0.02))
	return p


## A Norse horned helm, face +Z, about 1 wide.
static func horned_helm(metal: Color, horn: Color, trim: Color) -> K.Part:
	var p := K.Part.new()
	p.ink(metal, 0.9)
	p.ball(Vector3(0, 0.1, 0), Vector3(0.36, 0.34, 0.36), 9, 5)
	p.ink(trim, 1.0, 0.25)
	p.tube(Vector3(0, -0.04, 0), Vector3(0, 0.06, 0), 0.38, 0.38, 12, 1.0, false)
	p.box(Vector3(0, 0.15, 0.33), Vector3(0.07, 0.42, 0.06))
	p.box(Vector3(0, -0.12, 0.34), Vector3(0.09, 0.24, 0.05))
	p.ink(horn, 0.6)
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * 0.3, 0.12, 0), Vector3(s * 0.55, 0.22, 0.02), Vector3(s * 0.7, 0.45, 0.04), Vector3(s * 0.68, 0.72, 0.05)]
		for i in 3:
			p.tube(pts[i], pts[i + 1], 0.11 - 0.035 * float(i), 0.11 - 0.035 * float(i + 1), 6)
	return p


## A hemisphere lattice (meridians and parallels) of radius 1 round the origin: a ward.
static func dome(key: String, color: Color, meridians := 10, parallels := 3, width := 0.05) -> ArrayMesh:
	if M.has(key):
		return M.get_mesh(key)
	var st := _st()
	for i in meridians:
		var ang := TAU * float(i) / float(meridians)
		var pts := PackedVector3Array()
		for k in 13:
			var e := PI * 0.5 * float(k) / 12.0
			pts.append(Vector3(sin(ang) * cos(e), sin(e), cos(ang) * cos(e)))
		K.ribbon(st, pts, width, color, 0.0, 0.0, Vector3(sin(ang), 0, cos(ang)), 0.0, 0.0, 1.0, a(color, color.a * 0.4))
	for j in parallels:
		var e := PI * 0.5 * float(j + 0.6) / float(parallels + 0.6)
		var pts := PackedVector3Array()
		for k in 49:
			var ang := TAU * float(k) / 48.0
			pts.append(Vector3(sin(ang) * cos(e), sin(e), cos(ang) * cos(e)))
		K.ribbon(st, pts, width * 0.8, a(color, color.a * 0.8), 0.0, 0.0, Vector3.UP, 0.0)
	K.ring(st, 1.0, width * 2.2, color, 0.02, 64)
	return _done(key, st)


## The bright core of a hit at the root's origin: a flash, a shock ring, thrown sparks.
static func impact(art: StarSkillArt, key: String, color: Color, accent: Color, r: float, delay := 0.0, count := 20, at := Vector3.ZERO) -> void:
	if art == null:
		return
	M.flash(art, key + "_flash", color, r * 0.7, delay, 0.35, 0.09)
	M.shock(art, key + "_shock", color, r, delay, 0.45, 0.2, 0.1)
	M.sparks(art, key + "_sparks", [color, accent, color.lerp(accent, 0.5)], count, 0.2, r * 0.3, r * 1.1, r * 0.9, 0.15, delay, 0.8, at, 6.0, key.hash() % 97)


## A release root that follows the caster (a self buff): it rides along if he moves.
static func follow(c: Dictionary, art: StarSkillArt) -> void:
	if art == null:
		return
	var who := _caster_of(c.visual) as Node3D
	if who:
		art.follow_ref = weakref(who)
		art.follow_offset = Vector3.ZERO
		art.global_position = who.global_position


## The point of the caster's weapon hand (world), or a point at chest height.
static func hand(c: Dictionary) -> Vector3:
	var visual: HeroVisual = c.visual
	if is_instance_valid(visual) and visual.is_inside_tree():
		return visual.skill_emission_position()
	return (c.origin as Vector3) + Vector3.UP * 1.2 + (c.fwd as Vector3) * 0.5


## How far up a piece standing at [param world] may reach on screen (metres, design max).
static func sky(c: Dictionary, world: Vector3, design: float) -> float:
	return minf(design, GodSkillArt.headroom(c.parent, world))


## Turns a root so its +Z faces the camera (an open side or a front put towards the viewer).
static func turn_to_camera(art: Node3D) -> void:
	if art == null or not art.is_inside_tree():
		return
	var camera := art.get_viewport().get_camera_3d()
	if camera == null:
		return
	var d := flat(camera.global_position - art.global_position)
	if d.length_squared() > 0.01:
		art.rotation.y = atan2(d.x, d.z)
