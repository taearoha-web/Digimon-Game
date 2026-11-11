extends RefCounted
## Shared helpers of the ranged star signatures (archer, mage, priest: combat/star_art).
## They stage their pieces on GodRangedKit roots (combat/god_art/_kit_ranged.gd): one
## clock per root, one draw and one VfxBudget decoration per piece or swarm, all freed
## with the root. Cosmetic ONLY: StarSkillSequence owns every contact. Scripts whose
## name starts with `_` are kits, never a skill's own art.
const K := preload("res://combat/god_art/_kit_ranged.gd")


## The skill's own colours (StarSkillArt.COLORS) as glow colours: a tinted core, never white.
static func tones(skill: Dictionary, core_mix := 0.55) -> Dictionary:
	var c := StarSkillArt.look(skill)
	var primary: Color = c.primary
	return {"c_core": primary.lerp(c.accent, core_mix), "c_mid": primary, "c_edge": (c.shade as Color).lerp(primary, 0.35)}


static func glow(core: Color, mid: Color, edge: Color) -> Dictionary:
	return {"c_core": core, "c_mid": mid, "c_edge": edge}


## A root of the cast at [param at] facing away from [param source]. Its label carries the
## skill id: StarSignature then ties it to the running cast (GodSkillArt.bind_roots), so a
## cast that ends early (the hero died or left) takes it away at once.
static func root(parent: Node3D, at: Vector3, seconds: float, label: String, source: Vector3, caster: Node3D = null, windup := 0.0) -> K:
	var r := K.open(parent, at, seconds, label, source)
	if r and windup > 0.0:
		hold(r, caster, windup)
	return r


## Binds a root opened in the wind-up to the caster's skill generation (a cancelled
## wind-up drops it) for the first [param windup] seconds.
static func hold(r: K, caster: Node3D, windup: float) -> void:
	if not r or not is_instance_valid(caster):
		return
	r.generation_until = windup
	var visual := StarSkillArt._visual(caster)
	if visual:
		r.generation_ref = weakref(visual)
		r.generation = visual.skill_generation


## Where the caster's weapon hand is (world): the bow, the staff tip, the holy symbol.
static func hand(caster: Node3D) -> Vector3:
	if not is_instance_valid(caster):
		return Vector3.UP * 1.2
	return StarSkillArt._body_point(caster)


## Ground positions of the living foes within [param radius] of [param centre] (read only,
## for locks and chains drawn on them), nearest first, at most [param most].
static func foes(node: Node, centre: Vector3, radius: float, most: int) -> Array:
	var out := []
	if not is_instance_valid(node) or not node.is_inside_tree():
		return out
	for item in node.get_tree().get_nodes_in_group("mobs"):
		var mob := item as Mob
		if mob and not mob.is_dead() and Vector2(mob.global_position.x - centre.x, mob.global_position.z - centre.z).length() <= radius + mob.body_radius():
			out.append(mob.global_position * Vector3(1, 0, 1))
	out.sort_custom(func(a, b): return a.distance_squared_to(centre) < b.distance_squared_to(centre))
	return out.slice(0, most)


static func q() -> int:
	return K.quality()


static func lean() -> bool:
	return K.lean()


## Fewer instances on low quality and under memory pressure, never none.
static func n(high: int, low := 1) -> int:
	return maxi(low, VfxBudget.count(high, low))


## A soft camera-facing glow (god_glow mode 0).
static func flash(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, gain := 0.5, o := {}) -> void:
	if r:
		r.add(K.mesh("quad"), K.GLOW, colours.merged({"mode": 0, "billboard": true, "p1": 2.2, "gain": gain}), at, Vector3.ONE * size, Vector3.ZERO, start, seconds, {"fin": 0.03, "fout": seconds * 0.6}.merged(o, true))


## A shock ring lying on the ground (mode 1), or standing when [param angles] say so.
static func ring(r: K, at: Vector3, size: float, colours: Dictionary, start: float, seconds: float, gain := 0.6, angles := K.FLAT, o := {}) -> void:
	if r:
		r.add(K.mesh("quad"), K.GLOW, colours.merged({"mode": 1, "p1": 0.9, "gain": gain}), at, Vector3.ONE * size, angles, start, seconds, {"fin": 0.01}.merged(o, true))


## Cards bursting out of [param at] (mode 9 motes or 10 stars), thrown along random
## directions with [param speed], falling with [param fall].
static func sparks(r: K, at: Vector3, count: int, colours: Dictionary, size: float, start: float, life: float, speed := 8.0, fall := 2.5, mode := 9, spread := 1.0, salt := 0.0) -> void:
	if not r or count <= 0:
		return
	var cards := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 3.7 + salt)
		var a := float(k) * K.GOLDEN + salt
		var up := 0.35 + 0.6 * K.rand(s * 9.1 + salt)
		var out := Vector3(cos(a) * spread, up, sin(a) * spread).normalized()
		cards.append(K.card(at + out * 0.2, size * (0.6 + 0.6 * s), out))
		data.append(Color(s * 0.08, s, 0, 0))
	r.swarm(K.mesh("quad"), K.GLOW, colours.merged({"mode": mode, "billboard": true, "life": life, "burst": speed, "gravity": fall, "grow": Vector2(1.0, 0.4)}), cards, data, start, life + 0.15, {"fin": 0.01})


## Motes drifting up over a disc (mode 9 motes, 10 stars, 12 healing plus).
static func motes(r: K, centre: Vector3, radius: float, count: int, colours: Dictionary, size: float, start: float, span: float, life := 1.2, rise := 1.2, mode := 9, salt := 0.0) -> void:
	if not r or count <= 0:
		return
	var cards := []
	var data := []
	for k in count:
		var s := K.rand(float(k) * 5.3 + salt)
		cards.append(K.card(centre + K.scatter(k, count, radius, salt) + Vector3.UP * (0.15 + 0.5 * s), size * (0.6 + 0.7 * s)))
		data.append(Color(s * span, s, 0, 0))
	r.swarm(K.mesh("quad"), K.GLOW, colours.merged({"mode": mode, "billboard": true, "life": life, "drift": Vector3(0, rise, 0), "sway": 0.25}), cards, data, start, span + life + 0.1, {"fin": 0.01})


## Healing washing over the caster's side: a soft ring at the feet and plus motes rising.
static func heal(parent: Node3D, source: Vector3, size: float, label: String, colours: Dictionary, delay := 0.0) -> void:
	var at := Vector3(source.x, 0, source.z)
	var h := K.open(parent, at, 1.0, label, at)
	if not h:
		return
	ring(h, Vector3.UP * 0.08, size, colours.merged({"p2": 1.0}), delay, 0.95, 0.4)
	if not lean():
		motes(h, Vector3.ZERO, size * 0.35, n(7, 3), colours, 0.28, delay, 0.3, 0.9, 1.6, 12, size)


## The yaw (about Y) that turns +Z of a root towards the camera.
static func face_camera(r: K) -> float:
	var d := r.toward_camera()
	return atan2(d.x, d.z)
