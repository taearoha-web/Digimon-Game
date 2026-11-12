extends RefCounted
## Team kit of the arcane classes' regular skills (Summoner, Dark Lord, Bard; Lv.60-100,
## combat/skill_art via SkillSignature). Cosmetic only. Built on the god kit
## (combat/god_art/_kit_arcane.gd: its four shaders, Builder and cached meshes) and the
## arcane star kit (combat/star_art/_kit_star_arcane.gd): every piece is a StarSkillArt
## layer (one clock, the 2/4/6 layer cap, a VfxBudget decoration, freed with its root).
##
## A cast (Cast) decides how much it may draw: the player's own hero opens up to six
## roots at high quality, a companion, a rival or a world player one or two (one in a
## crowd), so a guild war full of casters never pays for the hero's grandeur. Wind-up
## roots die with the caster's skill motion (HeroVisual.skill_generation: death cancels
## it); release roots fade out (StarSkillArt.CLOSE) the moment the caster dies or leaves.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const DS := preload("res://combat/god_art/divine_symphony.gd")
## Toon looks of the SOLID pieces.
const STONE_LOOK := {"rim_color": Color("fff0d0"), "rim": 0.5, "shadow_tint": Color(0.62, 0.55, 0.5)}
const LEAF_LOOK := {"rim_color": Color("f0ffd0"), "rim": 0.6, "shadow_tint": Color(0.55, 0.7, 0.5)}
const GOLD_LOOK := {"rim_color": Color("fff4c8"), "rim": 0.7, "shadow_tint": Color(0.75, 0.55, 0.4)}
const NOTE_LOOK := {"rim_color": Color("fff4ff"), "rim": 0.6, "shadow_tint": Color(0.78, 0.66, 0.9)}
const DARK_LOOK := {"rim_color": Color("d8b8ff"), "rim": 0.75, "shadow_tint": Color(0.55, 0.45, 0.7)}

## The latest wind-up of each skill: who cast it (their visual) and where they aimed,
## so the release (which only gets positions) can follow and watch the same caster.
static var _last := {}
## Recent casts that were not the hero's (ms): a crowd draws less.
static var _recent: Array[int] = []
static var _contacts := {}


class Cast:
	extends RefCounted
	var parent: Node3D
	var skill: Dictionary
	var id := ""
	var origin := Vector3.ZERO
	var point := Vector3.ZERO
	var aim := Vector3.ZERO
	var forward := Vector3.FORWARD
	var visual: HeroVisual
	var caster: Node3D
	## The player's own hero (VfxBudget.for_hero): the full set piece.
	var hero := false
	var q := 2
	## The hero at high quality without memory pressure: the richest details too.
	var rich := false
	## Anyone else: the outline of the set piece only.
	var lite := true
	var rooms := 1
	var opened := 0
	var windup := false
	var watch: Watch
	## Scale of every root (K.frame: what the field camera shows of the sky there).
	var fit := 1.0

	## A root of this cast at [param at] (world), facing the cast's forward. Null when the
	## cast has opened all the roots it may, or the budget is full. [param follow]: the root
	## rides that node (the caster, a creature).
	func open(at: Vector3, seconds: float, tag: String, follow: Node3D = null) -> StarSkillArt:
		if opened >= rooms or not is_instance_valid(parent) or not parent.is_inside_tree() or not VfxBudget.can_decorate(2):
			return null
		var art := StarSkillArt._root(parent, at, seconds, "Skill%s_%s" % [tag, id])
		if art == null:
			return null
		opened += 1
		art.scale = Vector3.ONE * fit
		if Vector2(forward.x, forward.z).length_squared() > 0.001:
			art.rotation.y = atan2(forward.x, forward.z)
		if is_instance_valid(follow):
			art.follow_ref = weakref(follow)
			art.follow_offset = at - follow.global_position
		if windup and is_instance_valid(visual):
			art.generation_ref = weakref(visual)
			art.generation = visual.skill_generation
		else:
			_watch(art, seconds)
		return art

	## The local point of [param world] in [param art] (unscaled by the fit).
	func local(art: StarSkillArt, world: Vector3) -> Vector3:
		return art.to_local(world) if art else Vector3.ZERO

	func _watch(art: StarSkillArt, seconds: float) -> void:
		if not is_instance_valid(caster):
			return
		if watch == null or not is_instance_valid(watch):
			watch = Watch.new()
			watch.name = "SkillWatch_" + id
			watch.caster_ref = weakref(caster)
			parent.add_child(watch)
		watch.roots.append(weakref(art))
		watch.left = maxf(watch.left, seconds + 0.5)

	## Where the caster's hand / staff is now (the visual's emission point), else 1.3 m up.
	func hand() -> Vector3:
		if is_instance_valid(visual) and visual.is_inside_tree():
			return visual.skill_emission_position()
		return origin + Vector3.UP * 1.3


## Fades the cast's release roots out the moment their caster dies or leaves the field.
class Watch:
	extends Node
	var caster_ref: WeakRef
	var roots: Array[WeakRef] = []
	var left := 1.0

	func _process(delta: float) -> void:
		left -= delta
		var who := caster_ref.get_ref() as Node if caster_ref else null
		var gone := not is_instance_valid(who) or not who.is_inside_tree() or (who.has_method("is_dead") and bool(who.call("is_dead")))
		if gone:
			for ref in roots:
				var art := ref.get_ref() as StarSkillArt
				if is_instance_valid(art) and art._closing < 0.0:
					art._closing = art.age
			queue_free()
		elif left <= 0.0:
			queue_free()


static func _caster_of(visual: HeroVisual) -> Node3D:
	if not is_instance_valid(visual):
		return null
	var up := visual.get_parent()
	return up as Node3D if up is Node3D and up.has_method("is_dead") else visual


static func _new(parent: Node3D, skill: Dictionary, origin: Vector3, point: Vector3) -> Cast:
	var c := Cast.new()
	c.parent = parent
	c.skill = skill
	c.id = String(skill.get("id", ""))
	c.origin = origin
	c.point = point
	c.hero = VfxBudget.for_hero()
	c.q = VfxBudget.quality()
	c.rich = c.hero and c.q == 2 and MemoryGuard.pressure == 0
	c.lite = not c.hero
	var now := Time.get_ticks_msec()
	_recent = _recent.filter(func(t: int): return now - t < 1000)
	if c.hero:
		c.rooms = [2, 3, 6][c.q]
		if MemoryGuard.pressure > 0:
			c.rooms = mini(c.rooms, 3)
	else:
		c.rooms = 1 if _recent.size() >= 3 or MemoryGuard.pressure > 0 else [1, 1, 2][c.q]
	return c


## The wind-up of [param skill]; remembers its caster for the release.
static func windup(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, visual: HeroVisual) -> Cast:
	var c := _new(parent, skill, origin, Vector3(aim.x, origin.y, aim.z))
	c.windup = true
	c.aim = aim
	c.visual = visual
	c.caster = _caster_of(visual)
	var d := (aim - origin) * Vector3(1, 0, 1)
	if d.length_squared() > 0.01:
		c.forward = d.normalized()
	elif is_instance_valid(visual):
		c.forward = (visual.global_basis.z * Vector3(1, 0, 1)).normalized()
	_last[c.id] = {"visual": weakref(visual) if visual else null, "origin": origin, "aim": aim, "forward": c.forward, "ms": Time.get_ticks_msec()}
	return c


## The release of [param skill] at [param center] (the caster stands at [param origin]).
static func release(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3) -> Cast:
	var c := _new(parent, skill, origin, center)
	if not c.hero:
		_recent.append(Time.get_ticks_msec())
	var last: Dictionary = _last.get(c.id, {})
	c.aim = center
	if not last.is_empty() and (last.origin as Vector3).distance_to(origin) < 3.0 and Time.get_ticks_msec() - int(last.ms) < 5000:
		var ref: WeakRef = last.visual
		c.visual = ref.get_ref() as HeroVisual if ref else null
		c.forward = last.forward
		if (center - origin).length_squared() < 0.04:
			c.aim = last.aim
	c.caster = _caster_of(c.visual)
	var d := (center - origin) * Vector3(1, 0, 1)
	if d.length_squared() > 0.01:
		c.forward = d.normalized()
	return c


## A light cast for a beat that has no wind-up of its own (a flight, a link, a hit).
## It watches the skill's latest caster, so a hit's flash fades with them too.
static func beat(parent: Node3D, skill: Dictionary, at: Vector3) -> Cast:
	var c := _new(parent, skill, at, at)
	c.rooms = 1
	var last: Dictionary = _last.get(c.id, {})
	if not last.is_empty() and Time.get_ticks_msec() - int(last.ms) < 4000:
		var ref: WeakRef = last.visual
		c.visual = ref.get_ref() as HeroVisual if ref else null
		c.caster = _caster_of(c.visual)
	return c


## At most [param most] contacts of [param id] every [param gap] ms (a burst that hits ten
## monsters, or a chain's seven links in one frame, draws its hit art a few times, not ten).
static func contact_ok(id: String, gap := 70, most := 1) -> bool:
	var now := Time.get_ticks_msec()
	var seen: Array = _contacts.get(id, [])
	seen = seen.filter(func(t: int): return now - t < gap)
	if seen.size() >= most:
		_contacts[id] = seen
		return false
	seen.append(now)
	_contacts[id] = seen
	return true


static func show(art: StarSkillArt) -> void:
	if art:
		art._draw()


## The creatures of [param id] the caster near [param origin] just called (not the ones
## being replaced), nearest first.
static func summons(parent: Node, id: String, origin: Vector3) -> Array:
	var out: Array = []
	if not is_instance_valid(parent):
		return out
	for child in parent.get_children():
		if child is Summon and String(child.skill_id) == id and not child.is_queued_for_deletion():
			var who: Node3D = child.summoner
			if is_instance_valid(who) and who.global_position.distance_to(origin) < 3.0:
				out.append(child)
	return out


## Where the [param slot]-th of [param slots] creatures appears round its summoner
## (Summon._formation), for the wind-up before they exist.
static func formation(skill: Dictionary, slot: int, slots: int) -> Vector3:
	var size := Summon.size_for_rank(maxi(1, Game.effective_rank(skill))) if Game.has_profile else 1.0
	var angle := TAU * float(slot) / float(maxi(slots, 1)) + PI * 0.5
	return Vector3(cos(angle), 0.0, sin(angle)) * (2.6 + 1.2 * (size - 1.0))


## The flat direction away from the field camera at [param node] (a backdrop beyond the
## action reads there without covering it); no camera: -Z.
static func away(node: Node) -> Vector3:
	var view := node.get_viewport() if is_instance_valid(node) and node.is_inside_tree() else null
	var camera := view.get_camera_3d() if view else null
	if camera == null:
		return Vector3.FORWARD
	var d := (-camera.global_basis.z) * Vector3(1, 0, 1)
	return d.normalized() if d.length_squared() > 0.001 else Vector3.FORWARD


## The Euler angles (YXZ) that turn +Z towards [param dir].
static func toward(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	return Vector3(-asin(clampf(d.y, -1.0, 1.0)), atan2(d.x, d.z), 0.0)


## A beam layer of [param mesh] (along +Z, 0..1) from [param from] to [param to] (world)
## in [param art] (its rotation and scale undone).
static func span(art: StarSkillArt, shader: Shader, mesh: Mesh, label: String, from: Vector3, to: Vector3, width: float, seconds: float, style := {}, params := {}) -> ShaderMaterial:
	if art == null:
		return null
	var a := art.to_local(from)
	var b := art.to_local(to)
	var d := b - a
	if d.length() < 0.05:
		return null
	return K.put(art, shader, mesh, label, a, Vector3(width, width, d.length()), toward(d), seconds, style, params)


## Who a team blessing of the caster near [param origin] reaches (its creatures, the
## party and the hero), nearest first, at most [param most].
static func allies(c: Cast, reach := 12.0, most := 4) -> Array:
	var out: Array = []
	if not is_instance_valid(c.parent) or not c.parent.is_inside_tree():
		return out
	for group in ["summons", "companions", "hero"]:
		for node in c.parent.get_tree().get_nodes_in_group(group):
			var n := node as Node3D
			if n == null or n == c.caster or not n.is_inside_tree() or n.is_queued_for_deletion():
				continue
			if n.has_method("is_dead") and bool(n.call("is_dead")):
				continue
			if (n.global_position - c.origin).length() <= reach and (n.global_position - c.origin).length() > 0.6:
				out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_to(c.origin) < b.global_position.distance_to(c.origin))
	return out.slice(0, most)


static func radius(skill: Dictionary, fallback := 5.0) -> float:
	return clampf(float(skill.get("radius", fallback)), 2.0, 12.0)


# ---------------------------------------------------------------------------
# Meshes of the team (each built once per palette, cached by the god kit)
# ---------------------------------------------------------------------------
## A soft beam along +Z from 0 to 1 (two crossed ribbons, 1 wide at the foot, tapering):
## rays, links, tails. UV = (across, along).
static func beam(key: String, core: Color, edge: Color, taper := 0.35) -> ArrayMesh:
	return K.cached("mystic_beam_" + key, func():
		var b := K.Builder.new()
		var rows := 10
		for plane in 2:
			var side := Vector3.RIGHT if plane == 0 else Vector3.UP
			var base := b.v.size()
			for k in rows + 1:
				var f := float(k) / rows
				var w := 0.5 * lerpf(1.0, taper, f)
				var c := core.lerp(edge, f * 0.6)
				c.a *= smoothstep(0.0, 0.08, f) * (1.0 - smoothstep(0.85, 1.0, f))
				var z := Vector3.BACK * f
				b.pt(z - side * w, Vector3.UP, Color(c, 0.0), Vector2(0.0, f))
				b.pt(z, Vector3.UP, c, Vector2(0.5, f))
				b.pt(z + side * w, Vector3.UP, Color(c, 0.0), Vector2(1.0, f))
			for k in rows:
				var a := base + k * 3
				for j in 2:
					b.tri(a + j, a + j + 1, a + j + 4); b.tri(a + j, a + j + 4, a + j + 3)
		return b.mesh())


## A magic seal on the ground (radius 1): two rings, a star polygon {points/step}, tick
## marks and small circles; [param wash] fills it faintly.
static func sigil(key: String, line: Color, wash: Color, points := 6, step := 2, dots := 6) -> ArrayMesh:
	return K.cached("mystic_sigil_" + key, func():
		var b := K.Builder.new()
		b.annulus(0.0, 0.95, 40, Color(wash, wash.a * 0.6), Color(wash, wash.a))
		b.annulus(0.95, 1.0, 56, Color(line, 0.95), Color(line, 0.6), 0.004)
		b.annulus(0.80, 0.83, 56, Color(line, 0.85), Color(line, 0.85), 0.004)
		b.annulus(0.30, 0.32, 32, Color(line, 0.8), Color(line, 0.8), 0.004)
		var verts := []
		for i in points:
			var a := TAU * i / float(points)
			verts.append(Vector3(sin(a), 0, cos(a)) * 0.8)
		for i in points:
			var p: Vector3 = verts[i]
			var q: Vector3 = verts[(i + step) % points]
			var side := (q - p).cross(Vector3.UP).normalized() * 0.014
			var up := Vector3.UP * 0.006
			b.quad(p - side + up, p + side + up, q + side + up, q - side + up, Color(line, 0.9))
		for i in 48:
			var a := TAU * i / 48.0
			var out := Vector3(sin(a), 0, cos(a))
			var s := Vector3(out.z, 0, -out.x) * 0.006
			var long := 0.06 if i % 4 == 0 else 0.03
			b.quad(out * 0.84 - s, out * 0.84 + s, out * (0.84 + long) + s, out * (0.84 + long) - s, Color(line, 0.8))
		for i in dots:
			var a := TAU * (i + 0.5) / float(dots)
			b.xf = Transform3D(Basis.IDENTITY, Vector3(sin(a), 0.005, cos(a)) * 0.56)
			b.annulus(0.06, 0.085, 16, Color(line, 0.9), Color(line, 0.9))
			b.annulus(0.0, 0.06, 12, Color(line, 0.35), Color(line, 0.2))
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## Rock spikes jutting from a ring of radius 1, leaning out, 0.6..1.2 tall (SOLID).
static func spikes(key: String, rock: Color, tip: Color, count := 12, seed_value := 5, lean := 0.35, girth := 1.0) -> ArrayMesh:
	return K.cached("mystic_spikes_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.15, 0.15)
			var out := Vector3(sin(a), 0, cos(a))
			var foot := out * rng.randf_range(0.82, 1.08)
			var tall := rng.randf_range(0.6, 1.2)
			var w := rng.randf_range(0.1, 0.17) * girth
			b.cone(foot - Vector3.UP * 0.1, foot + out * tall * lean + Vector3.UP * tall, w, 5, rock, tip, Vector3.UP, true)
			if i % 2 == 0:
				b.cone(foot + out * 0.12 - Vector3.UP * 0.1, foot + out * (0.12 + tall * 0.5 * lean) + Vector3.UP * tall * 0.45, w * 0.6, 4, rock.darkened(0.1), tip, Vector3.UP, true)
		return b.mesh())


## Vines / roots arching up out of a ring of radius 1 and curling over (SOLID), up to
## about 1 tall; [param thorns] adds hooked thorns.
static func vines(key: String, dark: Color, light: Color, count := 8, thorns := false, seed_value := 3, reach := 1.0, girth := 1.0) -> ArrayMesh:
	return K.cached("mystic_vines_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.2, 0.2)
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x) * rng.randf_range(-0.35, 0.35)
			var tall := rng.randf_range(0.65, 1.0) * reach
			var foot := out * rng.randf_range(0.85, 1.05)
			var pts := [foot - Vector3.UP * 0.12, foot + Vector3.UP * tall * 0.45 + side * 0.2, foot - out * 0.15 + Vector3.UP * tall * 0.95 + side * 0.4, foot - out * 0.42 + Vector3.UP * tall * 0.85 + side * 0.55, foot - out * 0.5 + Vector3.UP * tall * 0.62 + side * 0.4]
			var path := Array(K.smooth(pts, 5))
			var radii := []
			var cols := []
			for k in path.size():
				var f := float(k) / float(path.size() - 1)
				radii.append(lerpf(0.13, 0.02, f) * reach * girth)
				cols.append([light.lerp(dark, 0.3 * f), dark])
			b.tube(path, radii, 6, cols)
			if thorns:
				for k in range(2, path.size() - 2, 3):
					var p: Vector3 = path[k]
					var t := ((path[k + 1] as Vector3) - (path[k - 1] as Vector3)).normalized()
					var n := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
					var s := (1.0 if k % 2 == 0 else -1.0)
					b.cone(p, p + n * s * 0.16 * reach * girth + t * 0.06, 0.035 * reach * girth, 3, dark, light.lerp(Color.WHITE, 0.2), Vector3.UP, true)
		return b.mesh())


## A lotus in bloom on the ground (radius 1): [param rings] rings of cupped petals,
## pale at the tips, a glowing heart (SOLID).
static func lotus(key: String, inner: Color, outer: Color, heart: Color, count := 10, rings := 2) -> ArrayMesh:
	return K.cached("mystic_lotus_" + key, func():
		var b := K.Builder.new()
		for ring in rings:
			var n := count - ring * 2
			var reach := 1.0 - ring * 0.32
			var cup := 0.35 + ring * 0.25
			for i in n:
				var a := TAU * (i + ring * 0.5) / float(n)
				var out := Vector3(sin(a), 0, cos(a))
				var side := Vector3(out.z, 0, -out.x)
				var w := reach * 0.36
				var tip := out * reach + Vector3.UP * reach * cup
				var base := out * 0.08 + Vector3.UP * 0.02
				var mid := out * reach * 0.55 + Vector3.UP * reach * cup * 0.25
				var col_in := inner.lerp(outer, 0.2 * ring)
				var col_out := outer.lerp(Color.WHITE, 0.35)
				b.tri3(base, mid + side * w, mid - side * w, col_in, outer, outer)
				b.tri3(mid - side * w, mid + side * w, tip, outer, outer, col_out)
		b.emit = 0.8
		b.ball(Vector3.UP * 0.12, Vector3(0.16, 0.12, 0.16), heart.lerp(Color.WHITE, 0.3), heart, 10, 5)
		b.emit = 0.0
		return b.mesh())


## A storybook tree (about 1 tall at scale 1): a twisting trunk with roots and a canopy of
## heaped leaf balls (SOLID).
static func tree(key: String, bark: Color, leaf: Color, leaf_hi: Color, seed_value := 9) -> ArrayMesh:
	return K.cached("mystic_tree_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_tree(b, Transform3D.IDENTITY, bark, leaf, leaf_hi, rng)
		return b.mesh())


## A grove: [param count] small trees on a ring of radius 1 (about 0.5 tall) (SOLID).
static func grove(key: String, bark: Color, leaf: Color, leaf_hi: Color, count := 6) -> ArrayMesh:
	return K.cached("mystic_grove_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		for i in count:
			var a := TAU * (i + 0.5) / float(count)
			var s := rng.randf_range(0.4, 0.6)
			_tree(b, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(sin(a), 0, cos(a))), bark, leaf, leaf_hi, rng)
		b.xf = Transform3D.IDENTITY
		return b.mesh())


static func _tree(b: K.Builder, at: Transform3D, bark: Color, leaf: Color, leaf_hi: Color, rng: RandomNumberGenerator) -> void:
	b.xf = at
	var trunk := Array(K.smooth([Vector3(0, -0.05, 0), Vector3(0.04, 0.25, 0.02), Vector3(-0.03, 0.45, -0.02), Vector3(0.02, 0.62, 0.0)], 4))
	var radii := []
	for k in trunk.size():
		radii.append(lerpf(0.11, 0.05, float(k) / float(trunk.size() - 1)))
	b.tube(trunk, radii, 8, [[bark.lightened(0.15), bark.darkened(0.2)]])
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var out := Vector3(sin(a), 0, cos(a))
		b.tube(Array(K.smooth([Vector3.UP * 0.12, out * 0.12 + Vector3.UP * 0.04, out * 0.26 - Vector3.UP * 0.03], 3)), [0.05, 0.03, 0.01], 5, [[bark, bark.darkened(0.25)]])
	for i in 3:
		var a := TAU * i / 3.0 + 1.0
		var out := Vector3(sin(a), 0, cos(a))
		b.tube(Array(K.smooth([Vector3(0, 0.45, 0), out * 0.14 + Vector3.UP * 0.58, out * 0.26 + Vector3.UP * 0.66], 3)), [0.04, 0.025, 0.012], 5, [[bark, bark.darkened(0.2)]])
	for i in 13:
		var a := TAU * i / 13.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(0.12, 0.34) if i > 2 else 0.0
		var p := rng.randf_range(0.17, 0.26)
		var y := 0.78 + rng.randf_range(-0.1, 0.14) + (0.12 if i <= 2 else 0.0)
		b.ball(Vector3(sin(a) * d, y, cos(a) * d), Vector3(p, p * 0.85, p), leaf_hi.lerp(leaf, rng.randf() * 0.5), leaf.darkened(0.25), 10, 6)
	b.xf = Transform3D.IDENTITY


## Standing stones round a ring of radius 1 (height 1 at scale 1): obelisks with gold caps (SOLID).
static func obelisks(key: String, stone: Color, cap: Color, count := 8, seed_value := 17, girth := 1.0) -> ArrayMesh:
	return K.cached("mystic_obelisks_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var a := TAU * i / float(count)
			var out := Vector3(sin(a), 0, cos(a))
			var tall := rng.randf_range(0.75, 1.0)
			var w := 0.09 * girth
			b.xf = Transform3D(Basis(Vector3.UP, a), out)
			b.box(Vector3(0, tall * 0.45 - 0.05, 0), Vector3(w * 2.0, tall * 0.9, w * 1.6), stone.darkened(0.15), stone)
			b.emit = 0.5
			b.cone(Vector3(0, tall * 0.85, 0), Vector3(0, tall * 1.08, 0), w * 1.2, 4, cap, cap.lerp(Color.WHITE, 0.4), Vector3.FORWARD, true)
			b.box(Vector3(0, tall * 0.55, w * 0.81), Vector3(w * 0.9, w * 0.9, 0.01), cap, cap)
			b.emit = 0.0
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## Royal standards on a ring of radius 1 (about 1 tall): dark poles with gold finials and
## pennants of [param cloth] trimmed [param trim] facing out, weighed for the flap (SOLID).
static func standards(key: String, pole: Color, cloth: Color, trim: Color, count := 6) -> ArrayMesh:
	return K.cached("mystic_standards_" + key, func():
		var b := K.Builder.new()
		for i in count:
			var a := TAU * (i + 0.5) / float(count)
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			var foot := out
			b.tube([foot - Vector3.UP * 0.05, foot + Vector3.UP * 1.0], [0.018], 6, [pole])
			b.emit = 0.4
			b.gem(foot + Vector3.UP * 1.04, Vector3(0.04, 0.07, 0.04), trim, trim.lerp(Color.WHITE, 0.4))
			b.emit = 0.0
			b.phase = float(i) / count
			var top := foot + Vector3.UP * 0.95
			for k in 4:
				var f0 := float(k) / 4.0
				var f1 := float(k + 1) / 4.0
				b.weight = f0 * 0.12
				var w0 := lerpf(0.22, 0.12, f0)
				var w1 := lerpf(0.22, 0.12, f1)
				var p0 := top + side * 0.02 + out * f0 * 0.42
				var p1 := top + side * 0.02 + out * f1 * 0.42
				b.weight = f1 * 0.12
				b.quad(p0 - Vector3.UP * w0 * 2.2, p1 - Vector3.UP * w1 * 2.2, p1, p0, cloth.darkened(0.15), cloth if k < 3 else trim)
			b.quad(top + side * 0.025 - Vector3.UP * 0.05, top + side * 0.025 + out * 0.42 - Vector3.UP * 0.03, top + side * 0.025 + out * 0.42, top + side * 0.025, trim)
			b.phase = -1.0
			b.weight = 0.0
		return b.mesh())


## A crown (radius 1, about 1.1 tall): a band and [param points] points with gems (SOLID).
static func crown(key: String, gold: Color, gem: Color, points := 7, spiky := false) -> ArrayMesh:
	return K.cached("mystic_crown_" + key, func():
		var b := K.Builder.new()
		var hi := gold.lerp(Color.WHITE, 0.35)
		b.lathe([[1.0, 0.0, gold.darkened(0.2)], [1.02, 0.08, hi], [1.0, 0.3, gold], [1.03, 0.36, hi], [1.0, 0.4, gold.darkened(0.1)]], 36)
		for i in points:
			var a := TAU * i / float(points)
			var out := Vector3(sin(a), 0, cos(a))
			var side := Vector3(out.z, 0, -out.x)
			var tall := 1.1 if i % 2 == 0 else 0.8
			if spiky: tall *= 1.2
			b.tri3(out * 1.01 + side * 0.32 + Vector3.UP * 0.38, out * 1.01 - side * 0.32 + Vector3.UP * 0.38, out * 1.04 + Vector3.UP * tall, gold, gold, hi)
			b.tri3(out * 0.99 - side * 0.32 + Vector3.UP * 0.38, out * 0.99 + side * 0.32 + Vector3.UP * 0.38, out * 0.98 + Vector3.UP * tall, gold.darkened(0.2), gold.darkened(0.2), gold)
			b.emit = 0.85
			b.ball(out * 1.06 + Vector3.UP * (tall + 0.05), Vector3.ONE * 0.08, hi, gold, 6, 4)
			b.gem(out * 1.05 + Vector3.UP * 0.2, Vector3(0.1, 0.12, 0.05), gem, gem.lerp(Color.WHITE, 0.5))
			b.emit = 0.0
		return b.mesh())


## A crescent moon upright in XY (radius 1, horns up-right), [param tone] lit (VEIL/GLOW).
static func moon(key: String, tone: Color, rim: Color) -> ArrayMesh:
	return K.cached("mystic_moon_" + key, func():
		var b := K.Builder.new()
		b.xf = Transform3D(Basis(Vector3.RIGHT, -PI / 2).rotated(Vector3.BACK, 0.5), Vector3.ZERO)
		K.crescent(b, 1.0, 0.55, PI * 0.15, PI * 1.85, Color(tone, 0.95), Color(rim, 0.7), 28)
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## Jagged bolts of lightning from [param tall] down to the ground at [param count] spots
## on a ring of radius 1 (in metres up, ring units across) (GLOW).
static func lightning(key: String, core: Color, edge: Color, count := 5, tall := 7.0, seed_value := 21, ring := 1.0) -> ArrayMesh:
	return K.cached("mystic_lightning_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.2, 0.2)
			var foot := Vector3(sin(a), 0, cos(a)) * ring * rng.randf_range(0.6, 1.0)
			var top := foot * 0.6 + Vector3.UP * tall + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			K.bolt(b, top, foot, 0.22, core, edge, rng, 7, 0.7)
			if i % 2 == 0:
				var mid := top.lerp(foot, 0.45)
				K.bolt(b, mid, mid + Vector3(rng.randf_range(-1.2, 1.2), -tall * 0.3, rng.randf_range(-1.2, 1.2)), 0.11, core, edge, rng, 4, 0.4)
		return b.mesh())


## A single jagged bolt along +Z from 0 to 1 (crossed ribbons), for links (GLOW).
static func bolt_link(key: String, core: Color, edge: Color, seed_value := 4) -> ArrayMesh:
	return K.cached("mystic_bolt_link_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		K.bolt(b, Vector3.ZERO, Vector3.BACK, 0.06, core, edge, rng, 7, 0.09)
		K.bolt(b, Vector3(0, 0, 0.1), Vector3(0.05, 0.02, 0.95), 0.03, core, edge, rng, 6, 0.12)
		return b.mesh())


## Thin flat shards of glass thrown out and tumbling (burst, VEIL/GLOW): shattering.
static func glass(key: String, tones: Array, count := 26, speed := 6.0, rise := 5.0) -> ArrayMesh:
	return K.cached("mystic_glass_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 47
		for i in count:
			var a := rng.randf() * TAU
			var out := Vector3(sin(a), 0, cos(a))
			b.piece(out * rng.randf_range(0.1, 0.9) + Vector3.UP * rng.randf_range(0.3, 1.6), out * rng.randf_range(0.4, 1.0) * speed + Vector3.UP * rng.randf_range(0.3, 1.0) * rise, rng.randf_range(0.0, 0.08), rng.randf_range(4.0, 10.0), Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)))
			var tone: Color = tones[i % tones.size()]
			var s := rng.randf_range(0.14, 0.3)
			b.tri3(Vector3(-s, -s * 0.6, 0), Vector3(s * 0.8, -s * 0.4, 0), Vector3(rng.randf_range(-0.3, 0.3) * s, s * 1.3, 0), Color(tone, 0.9), Color(tone.lerp(Color.WHITE, 0.4), 0.95), Color(tone, 0.5))
		return b.mesh())


## Orbs on a ring of radius 1 (SOLID, lit): spin the layer to wheel them round.
static func orbs(key: String, tones: Array, count := 3, size := 0.2) -> ArrayMesh:
	return K.cached("mystic_orbs_" + key, func():
		var b := K.Builder.new()
		b.emit = 0.75
		for i in count:
			var a := TAU * i / float(count)
			var tone: Color = tones[i % tones.size()]
			b.ball(Vector3(sin(a), 0, cos(a)), Vector3.ONE * size, tone.lerp(Color.WHITE, 0.35), tone, 10, 6)
		b.emit = 0.0
		return b.mesh())


## Notes standing on a ring of radius 1, facing out (SOLID): spin the layer.
static func note_ring(key: String, tones: Array, count := 8) -> ArrayMesh:
	return K.cached("mystic_note_ring_" + key, func():
		var b := K.Builder.new()
		b.emit = 0.7
		for i in count:
			var a := TAU * i / float(count)
			b.xf = Transform3D(Basis(Vector3.UP, a).scaled(Vector3.ONE * (0.8 if i % 2 else 1.0)), Vector3(sin(a), (0.12 if i % 2 else 0.0), cos(a)))
			DS._note(b, tones[i % tones.size()])
		b.xf = Transform3D.IDENTITY
		b.emit = 0.0
		return b.mesh())


## A dome of light (radius 1, height 1): meridians and rings like a chapel's ribs (VEIL).
static func dome(key: String, rib: Color, glass_tone: Color, ribs := 10) -> ArrayMesh:
	return K.cached("mystic_dome_" + key, func():
		var b := K.Builder.new()
		var profile := []
		for k in 9:
			var f := float(k) / 8.0
			var th := f * PI * 0.5
			profile.append([cos(th), sin(th), Color(glass_tone, glass_tone.a * lerpf(0.9, 0.25, f))])
		b.lathe(profile, 32)
		for i in ribs:
			var a := TAU * i / float(ribs)
			var pts := []
			for k in 11:
				var th := float(k) / 10.0 * PI * 0.5
				pts.append(Vector3(sin(a) * cos(th), sin(th), cos(a) * cos(th)) * 1.005)
			var cols := []
			for k in pts.size(): cols.append(Color(rib, 0.9 - 0.4 * float(k) / pts.size()))
			b.tube(pts, [0.018], 4, cols, Vector3.UP, false)
		for y in [0.0, 0.35, 0.7]:
			var r := cos(asin(y))
			b.xf = Transform3D(Basis.IDENTITY, Vector3.UP * y)
			b.annulus(r * 0.995, r * 1.01, 48, Color(rib, 0.85), Color(rib, 0.6))
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## A comet's rock (radius 1, faceted) with a glowing heart (SOLID).
static func rock(key: String, dark: Color, lit: Color) -> ArrayMesh:
	return K.cached("mystic_rock_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		b.ball(Vector3.ZERO, Vector3.ONE * 0.85, dark.lightened(0.15), dark.darkened(0.3), 9, 6)
		for i in 9:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			b.gem(d * 0.7, Vector3(0.32, 0.4, 0.3), dark, dark.lightened(0.2), 4)
		b.emit = 0.95
		for i in 6:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			b.gem(d * 0.82, Vector3(0.14, 0.2, 0.12), lit, lit.lerp(Color.WHITE, 0.4), 3)
		b.emit = 0.0
		return b.mesh())


## A royal scepter (about 1 long, +Y from the foot): a dark shaft banded gold, a gold
## crown head holding a glowing orb of [param gem] (SOLID).
static func scepter(key: String, shaft: Color, gold: Color, gem: Color) -> ArrayMesh:
	return K.cached("mystic_scepter_" + key, func():
		var b := K.Builder.new()
		var hi := gold.lerp(Color.WHITE, 0.35)
		b.tube([Vector3(0, 0, 0), Vector3(0, 0.74, 0)], [0.028, 0.034], 8, [shaft.darkened(0.2), shaft])
		b.cone(Vector3(0, 0.02, 0), Vector3(0, -0.07, 0), 0.03, 6, gold, hi)
		for y in [0.18, 0.42, 0.66]:
			b.tube([Vector3(0, y - 0.015, 0), Vector3(0, y + 0.015, 0)], [0.045], 8, [hi])
		b.lathe([[0.04, 0.74, gold.darkened(0.2)], [0.1, 0.8, gold], [0.12, 0.86, hi], [0.1, 0.88, gold]], 16)
		for i in 6:
			var a := TAU * i / 6.0
			var out := Vector3(sin(a), 0, cos(a))
			b.cone(out * 0.1 + Vector3.UP * 0.86, out * 0.13 + Vector3.UP * 1.0, 0.025, 4, gold, hi, Vector3.UP, true)
		b.emit = 0.9
		b.ball(Vector3.UP * 0.95, Vector3.ONE * 0.085, gem.lerp(Color.WHITE, 0.35), gem, 10, 6)
		b.emit = 0.0
		return b.mesh())


## A great crescent blade of force (radius 1 arc, upright in XY, its belly towards +Y),
## a hot inner edge and a smoky trailing edge (VEIL).
static func slash(key: String, edge: Color, body: Color, smoke: Color) -> ArrayMesh:
	return K.cached("mystic_slash_" + key, func():
		var b := K.Builder.new()
		b.xf = Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3.ZERO)
		K.crescent(b, 1.0, 0.32, -1.3, 1.3, Color(edge, 0.95), Color(body, 0.85), 24)
		K.crescent(b, 0.86, 0.22, -1.1, 1.1, Color(body, 0.6), Color(smoke, 0.5), 20, 0.02)
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## Five staff lines of light round a ring of radius 1 with notes laid on them (VEIL).
static func staff(key: String, line: Color, tones: Array, notes := 10) -> ArrayMesh:
	return K.cached("mystic_staff_" + key, func():
		var b := K.Builder.new()
		for k in 5:
			var r := 0.86 + 0.032 * k
			b.annulus(r - 0.006, r + 0.006, 64, Color(line, 0.85), Color(line, 0.85))
		b.annulus(0.84, 1.0, 64, Color(line, 0.0), Color(line, 0.16))
		b.emit = 0.7
		for i in notes:
			var a := TAU * i / float(notes) + 0.2
			var on := 0.86 + 0.032 * float([0, 3, 1, 4, 2][i % 5])
			b.xf = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3(1, 0, 0), -PI / 2).scaled(Vector3.ONE * 0.13), Vector3(sin(a), 0.006, cos(a)) * on)
			DS._note(b, Color(tones[i % tones.size()], 0.95))
		b.xf = Transform3D.IDENTITY
		b.emit = 0.0
		return b.mesh())


## Small drums standing on a ring of radius 1, heads tipped to the sky, sticks raised (SOLID).
static func drums(key: String, count := 4, size := 0.22) -> ArrayMesh:
	return K.cached("mystic_drums_" + key, func():
		var b := K.Builder.new()
		for i in count:
			var a := TAU * (i + 0.5) / float(count)
			b.phase = float(i) / count
			b.weight = 1.0
			DS._drum(b, Transform3D(Basis(Vector3.UP, a + PI).scaled(Vector3.ONE * size), Vector3(sin(a), size * 0.8, cos(a))))
		b.phase = -1.0
		b.weight = 0.0
		b.xf = Transform3D.IDENTITY
		return b.mesh())


## A ring of fire tongues built in metres ([param radius] m round, each [param wide] m
## wide and up to [param tall] m tall, leaning out), so a wide ring keeps slim flames
## instead of the stretched blobs a scaled unit ring gives (VEIL with a fire look).
static func fire_ring(key: String, stops: Array, radius: float, count := 18, wide := 0.3, tall := 1.4) -> ArrayMesh:
	return K.cached("mystic_fire_ring_%s_%d" % [key, int(radius * 10.0)], func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 19
		for i in count:
			var a := TAU * i / float(count) + rng.randf_range(-0.1, 0.1)
			var out := Vector3(sin(a), 0, cos(a))
			S.flame(b, out * radius * rng.randf_range(0.94, 1.04), wide * rng.randf_range(0.8, 1.2), tall * (1.0 if i % 2 == 0 else 0.65) * rng.randf_range(0.85, 1.1), stops, out * 0.25)
		return b.mesh())


## Jagged cracks for a wide area: a small scorched heart and thin lit seams (VEIL).
static func scar(key: String, dark: Color, lit: Color, rays := 12) -> ArrayMesh:
	return K.cached("mystic_scar_" + key, func():
		var b := K.Builder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 13
		b.annulus(0.0, 0.1, 20, Color(dark, 0.55), Color(dark, 0.4))
		b.annulus(0.1, 0.2, 20, Color(dark, 0.4), Color(dark, 0.0))
		for i in rays:
			var a := TAU * i / float(rays) + rng.randf_range(-0.15, 0.15)
			var reach := rng.randf_range(0.6, 1.0)
			var here := Vector3(sin(a), 0, cos(a)) * 0.08
			var width := 0.024
			for k in 6:
				a += rng.randf_range(-0.3, 0.3)
				var next := here + Vector3(sin(a), 0, cos(a)) * reach / 6.0
				var side := Vector3(cos(a), 0, -sin(a))
				var thin := width * (1.0 - (k + 1) / 7.0)
				var up := Vector3.UP * 0.005
				b.quad(here - side * width + up, here + side * width + up, next + side * thin + up, next - side * thin + up, Color(dark, 0.7))
				b.quad(here - side * width * 0.4 + up * 2.4, here + side * width * 0.4 + up * 2.4, next + side * thin * 0.4 + up * 2.4, next - side * thin * 0.4 + up * 2.4, lit, Color(lit, 0.8))
				here = next
				width = thin
		return b.mesh())


## The angles (YXZ) that stand a +Y mesh (a tail, a comet) along [param dir].
static func along(dir: Vector3) -> Vector3:
	var t := toward(dir)
	return Vector3(t.x + PI / 2, t.y, 0.0)
