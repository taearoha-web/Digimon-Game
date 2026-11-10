class_name MeleeArt
extends Node3D
## Class-signature layers of the three front-line classes, over the shared
## skill pipeline: the Warrior's steel and fire (WarriorArt), the Lancer's wind
## and dragon (LancerArt) and the Defender's holy shield and stone
## (DefenderArt). Every Lv.10-100 skill and every star skill of these lines.
##
## One pooled rig per cast holds timed layers (shared unit meshes from
## MeleeShapes in shaders/melee_art) and three CPU particle sets drawn as one
## MultiMesh each: sparks / embers / wind motes, debris and mirror shards, all
## with gravity, drag and turbulence. Layers ease in with overshoot, sweep a hot
## head over a cooling tail, then dissolve through noise.
##
## Budget: rigs, layer slots and particle arrays are pooled (an idle rig parks
## under one hidden holder at the root; nothing is allocated per frame).
## Decorations / particles / lights are reserved in VfxBudget. Tier 2 = full;
## tier 1 (medium quality or MemoryGuard pressure 1): no debris or lights, half
## the particles, fewer layers; tier 0 (low quality or pressure 2): the core
## silhouette only. Cosmetic only: it never selects victims, deals damage or
## changes timing; a cancelled wind-up (new skill generation) is dropped.

const SHADER := preload("res://shaders/melee_art.gdshader")
const GLOW_SHADER := preload("res://shaders/melee_glow.gdshader")
const SPARK_SHADER := preload("res://shaders/melee_spark.gdshader")
const DEBRIS_SHADER := preload("res://shaders/melee_debris.gdshader")
const FAMILIES := ["warrior", "lancer", "defender"]
const HOLDER := "MeleeArtPool"
## Rigs alive at once (busy + parked); a busy field reuses them, never grows.
const POOL_CAP := 6
const LAYER_CAP := [4, 8, 20]
const PARTICLE_CAP := 72
## Decorations left free for the shared pipeline, hits and other casters.
const RESERVE := 10
enum { RIBBON, GROUND, PANEL, AURA, SOLID, RING }
enum { SPARK, DEBRIS, SHARD }

## Off switch for perf comparisons and the before/after review.
static var enabled := true
## Totals for tests and probes.
static var built_layers := 0
static var built_particles := 0
static var _rig_count := 0

var age := 0.0
var lifetime := 0.5
var tier := 2
var busy := false
var owner_ref: WeakRef
var generation := -1
var _field_ref: WeakRef
var _claimed := 0
var _claimed_parts := 0
## What the hero's own room (VfxBudget) paid of the claims above.
var _claimed_hero := 0
var _claimed_parts_hero := 0
var _light_claimed := false
var _slots: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _specs: Array[Dictionary] = []
var _used := 0
var _sets: Array[Dictionary] = []
var _light: OmniLight3D
var _light_spec := {}
## The caster a self-centred composition (a buff's aura) rides along with.
var _follow: WeakRef


static func handles(skill: Dictionary) -> bool:
	return enabled and not skill.is_empty() and SkillShow.family_of(skill) in FAMILIES


static func family(skill: Dictionary) -> String:
	if skill.has("star"):
		for cls in FAMILIES:
			if String(skill.get("id", "")) in StarSkillData.IDS.get(StringName(cls), []):
				return cls
	return SkillShow.family_of(skill)


static func handles_star(skill: Dictionary) -> bool:
	return enabled and skill.has("star") and family(skill) in FAMILIES


## 2 full, 1 trimmed, 0 core only (quality and memory pressure).
static func tier_now() -> int:
	var q := VfxBudget.quality()
	var p := MemoryGuard.pressure
	if q == 0 or p >= 2:
		return 0
	if q == 1 or p == 1:
		return 1
	return 2


static func _alive(parent: Node) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


static func _yaw(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.x, d.z) if Vector2(d.x, d.z).length_squared() > 0.001 else 0.0


# ---------------------------------------------------------------------------
# Entry points (SkillShow / StarSkillArt hooks)
# ---------------------------------------------------------------------------

## Wind-up, bound to the caster's skill generation (a cancel drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or skill.has("star") or duration < 0.1 or not _alive(parent):
		return
	var rig := acquire(parent, origin, _yaw(origin, aim), duration + 0.12)
	if rig == null:
		return
	if visual:
		rig.owner_ref = weakref(visual)
		rig.generation = visual.skill_generation
	var ctx := context(skill, origin, aim)
	match SkillShow.family_of(skill):
		"warrior": WarriorArt.charge(rig, skill, ctx, duration)
		"lancer": LancerArt.charge(rig, skill, ctx, duration)
		"defender": DefenderArt.charge(rig, skill, ctx, duration)
	rig.commit()


## Release, at the same beat as the damage (delay: an area's landing wait).
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent):
		return
	var shape := String(skill.get("shape", "single"))
	var at := center if shape == "blast" else origin
	var aim := center
	if Vector2(center.x - origin.x, center.z - origin.z).length() < 0.5:
		# Bursts and self casts are centred on the caster: face the nearest foe.
		aim = _nearest_foe(parent, origin, float(skill.get("radius", 4.0)) + 3.0, origin + Vector3.BACK)
	var rig := acquire(parent, Vector3(at.x, origin.y, at.z), _yaw(origin, aim), 1.0)
	if rig == null:
		return
	var ctx := context(skill, origin, center)
	ctx.d = maxf(delay, 0.0)
	if shape == "self":
		rig.follow(_caster_near(parent, origin))
	match SkillShow.family_of(skill):
		"warrior": WarriorArt.play(rig, skill, ctx)
		"lancer": LancerArt.play(rig, skill, ctx)
		"defender": DefenderArt.play(rig, skill, ctx)
	rig.commit()


## Star skills: one composition per real contact beat (StarSkillSequence).
static func star(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not handles_star(skill) or GodSkillArt.owns(skill) or not _alive(parent):
		return
	var ground := Vector3(point.x, source.y, point.z)
	var yaw := _yaw(source, point)
	if Vector2(point.x - source.x, point.z - source.z).length() < 0.5:
		# A burst / self beat lands on the caster: face the nearest foe instead.
		yaw = _yaw(source, _nearest_foe(parent, source, float(skill.get("radius", 6.0)) + 2.0, source + Vector3.BACK))
	var rig := acquire(parent, ground, yaw, 1.0)
	if rig == null:
		return
	var ctx := context(skill, source, point)
	ctx.index = index
	if String(skill.get("shape", "")) == "self":
		rig.follow(_caster_near(parent, source))
	match family(skill):
		"warrior": WarriorArt.star(rig, skill, ctx)
		"lancer": LancerArt.star(rig, skill, ctx)
		"defender": DefenderArt.star(rig, skill, ctx)
	rig.commit()


## Star wind-up (StarSkillArt.telegraph), bound to the caster's generation.
static func star_charge(caster: Node3D, skill: Dictionary, point: Vector3, duration: float) -> void:
	if not handles_star(skill) or GodSkillArt.owns(skill) or not is_instance_valid(caster):
		return
	var parent := caster.get_parent() as Node3D
	if not _alive(parent):
		return
	var origin := caster.global_position
	var rig := acquire(parent, origin, _yaw(origin, point), duration + 0.12)
	if rig == null:
		return
	var visual := caster.get("visual") as HeroVisual if "visual" in caster else null
	if visual:
		rig.owner_ref = weakref(visual)
		rig.generation = visual.skill_generation
	var ctx := context(skill, origin, point)
	match family(skill):
		"warrior": WarriorArt.charge(rig, skill, ctx, duration)
		"lancer": LancerArt.charge(rig, skill, ctx, duration)
		"defender": DefenderArt.charge(rig, skill, ctx, duration)
	rig.commit()


static func _nearest_foe(parent: Node, from: Vector3, reach: float, fallback: Vector3) -> Vector3:
	var best := fallback
	var best_d := reach
	for node in parent.get_tree().get_nodes_in_group("mobs"):
		var mob := node as Node3D
		if mob and mob.is_inside_tree():
			var d := Vector2(mob.global_position.x - from.x, mob.global_position.z - from.z).length()
			if d < best_d and d > 0.3:
				best_d = d
				best = mob.global_position
	return best


## The hero standing on `at` (the caster of a self cast), or null.
static func _caster_near(parent: Node, at: Vector3) -> Node3D:
	for node in parent.get_tree().get_nodes_in_group("hero"):
		var hero := node as Node3D
		if hero and hero.is_inside_tree() and Vector2(hero.global_position.x - at.x, hero.global_position.z - at.z).length() < 0.6:
			return hero
	return null


static func context(skill: Dictionary, origin: Vector3, target: Vector3) -> Dictionary:
	var flat := Vector2(target.x - origin.x, target.z - origin.z)
	return {"id": String(skill.get("id", "")), "shape": String(skill.get("shape", "single")),
		"reach": clampf(flat.length(), 1.2, 16.0), "radius": clampf(float(skill.get("radius", 3.0)), 1.5, 10.0),
		"level": int(skill.get("level", 1)), "star": int(skill.get("star", 0)), "d": 0.0, "index": 0,
		"power": clampf(float(skill.get("level", 1)) / 100.0, 0.1, 1.0) if not skill.has("star") else 1.0}


# ---------------------------------------------------------------------------
# The pool
# ---------------------------------------------------------------------------

## The pool's home: one plain Node per viewport (so a field, a preview
## sub-viewport and the world each draw their own), created on first use. A rig
## lives there for good; it is not reparented into the field, which keeps a
## field's children to its own nodes and lets the rig outlive nothing: it is
## bound to its field (tree_exiting) and stops the moment the field goes.
static func _holder_of(parent: Node) -> Node:
	var viewport := parent.get_viewport()
	if viewport.has_meta(HOLDER):
		var known: Node = viewport.get_meta(HOLDER)
		if is_instance_valid(known) and not known.is_queued_for_deletion():
			return known
	var holder := Node.new()
	holder.name = HOLDER
	# Deferred: the viewport may be busy adding children (a cast from a _ready).
	viewport.add_child.call_deferred(holder)
	viewport.set_meta(HOLDER, holder)
	return holder


## A ready rig at `at` (world), facing yaw, bound to parent, or null when the
## budget or the pool is spent.
static func acquire(parent: Node3D, at: Vector3, yaw: float, seconds: float) -> MeleeArt:
	if not VfxBudget.can_decorate(2 + RESERVE):
		return null
	var holder := _holder_of(parent)
	var found: MeleeArt = null
	for child in holder.get_children():
		if child is MeleeArt and not (child as MeleeArt).busy:
			found = child
			break
	if found == null:
		if _rig_count >= POOL_CAP:
			return null
		found = MeleeArt.new()
		found.name = "MeleeArt"
		holder.add_child(found)
	found._bind(parent)
	found._begin(at, yaw, seconds)
	return found


func _init() -> void:
	_rig_count += 1
	# The whole rig is built once (layer slots, particle sets, a light) and reused,
	# so a warm pool never adds a node however many casts follow.
	for i in LAYER_CAP[2]:
		_add_slot()
	_pset(SHARD)
	_light = OmniLight3D.new()
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)


func _add_slot() -> void:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	node.material_override = mat
	add_child(node)
	_slots.append(node)
	_mats.append(mat)
	_specs.append({})


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_rig_count -= 1
		_release_claims()
	elif what == NOTIFICATION_EXIT_TREE and busy:
		_release_claims()


func _bind(parent: Node) -> void:
	_field_ref = weakref(parent)
	if not parent.tree_exiting.is_connected(_on_field_gone):
		parent.tree_exiting.connect(_on_field_gone, CONNECT_ONE_SHOT)


func _on_field_gone() -> void:
	if busy:
		finish()


func _begin(at: Vector3, yaw: float, seconds: float) -> void:
	busy = true
	age = 0.0
	lifetime = seconds
	tier = tier_now()
	owner_ref = null
	generation = -1
	_follow = null
	_used = 0
	_light_spec = {}
	# The holder is a plain Node: the rig's own transform is its world transform.
	transform = Transform3D(Basis(Vector3.UP, yaw), at)
	visible = true
	for s in _sets:
		s.count = 0
		(s.node as MultiMeshInstance3D).visible = false
	set_process(true)


func _release_claims() -> void:
	for i in _claimed:
		VfxBudget.release_decoration(i < _claimed_hero)
	VfxBudget.release_particles(_claimed_parts - _claimed_parts_hero)
	VfxBudget.release_particles(_claimed_parts_hero, true)
	if _light_claimed:
		VfxBudget._lights = maxi(0, VfxBudget._lights - 1)
	_claimed = 0
	_claimed_parts = 0
	_claimed_hero = 0
	_claimed_parts_hero = 0
	_light_claimed = false


func _claim(cost := 1) -> bool:
	if not VfxBudget.can_decorate(cost + RESERVE):
		return false
	for i in cost:
		if VfxBudget.reserve_decoration():
			_claimed_hero += 1
	_claimed += cost
	return true


## Back to the pool (hidden, idle, budget given back).
func finish() -> void:
	for i in _used:
		_slots[i].visible = false
	_used = 0
	for s in _sets:
		s.count = 0
		(s.node as MultiMeshInstance3D).visible = false
	if _light:
		_light.visible = false
	_release_claims()
	busy = false
	set_process(false)
	visible = false
	owner_ref = null
	_follow = null
	var field: Node = _field_ref.get_ref() if _field_ref else null
	if is_instance_valid(field) and field.tree_exiting.is_connected(_on_field_gone):
		field.tree_exiting.disconnect(_on_field_gone)
	_field_ref = null


## Binds the rig's position to a caster (a buff aura walks with its hero).
func follow(who: Node3D) -> void:
	_follow = weakref(who) if is_instance_valid(who) else null


## Called once the composition is authored: a rig with nothing to show goes back.
func commit() -> void:
	var parts := 0
	for s in _sets:
		parts += int(s.count)
	if _used == 0 and parts == 0:
		finish()
		return
	_draw()


# ---------------------------------------------------------------------------
# Authoring
# ---------------------------------------------------------------------------

## One timed layer. core: kept at tier 0. Style keys: travel (over move s), ease ("out",
## "in", "back"), initial, grow (seconds), overshoot, spin, roll, sweep (head
## time), tail, exit, thick, symmetric, opacity, fade_in, dissolve, pulse (bpm),
## veins, pattern, wave, drop/land, bill ("axis" Vector3 / "upright"), glow,
## ink (blend instead of add; ground layers default to ink), front.
func layer(kind: String, mode: int, c: Array, at: Vector3, size: Vector3, rot := Vector3.ZERO, start := 0.0, seconds := 0.8, style := {}, core := false) -> void:
	if (tier == 0 and not core) or _used >= int(LAYER_CAP[tier]) or not _claim():
		return
	if _used >= _slots.size():
		_add_slot()
	var node := _slots[_used]
	var mat := _mats[_used]
	node.mesh = MeleeShapes.mesh(kind)
	node.visible = false
	# Light adds onto the scene; "ink" layers (smears, scorch) blend and keep their dark rim.
	var ink := bool(style.get("ink", mode == GROUND))
	if mat.shader != (SHADER if ink else GLOW_SHADER):
		mat.shader = SHADER if ink else GLOW_SHADER
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("tail", float(style.get("tail", 0.6)))
	mat.set_shader_parameter("thick", float(style.get("thick", 0.6)))
	mat.set_shader_parameter("symmetric", 1.0 if bool(style.get("symmetric", false)) else 0.0)
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.9)) * (1.0 if ink else 0.72))
	mat.set_shader_parameter("veins", float(style.get("veins", 0.0)))
	mat.set_shader_parameter("pattern", float(style.get("pattern", 0.0)))
	mat.set_shader_parameter("wave", float(style.get("wave", 0.0)))
	mat.set_shader_parameter("glow", float(style.get("glow", 1.0)))
	mat.set_shader_parameter("narrow", float(style.get("narrow", 0.0)))
	mat.set_shader_parameter("seed", randf())
	mat.set_shader_parameter("pulse", 0.0)
	mat.render_priority = int(style.get("front", 0))
	var spec := _specs[_used]
	spec.clear()
	spec.merge(style)
	spec.at = at
	spec.size = size
	spec.rot = rot
	spec.start = start
	spec.seconds = maxf(seconds, 0.05)
	_used += 1
	built_layers += 1
	lifetime = maxf(lifetime, start + seconds + 0.05)


func _pset(kind: int) -> Dictionary:
	while _sets.size() <= kind:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = MeleeShapes.mesh(["spark", "rock", "shard"][_sets.size()])
		mm.instance_count = PARTICLE_CAP
		mm.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = DEBRIS_SHADER if _sets.size() == DEBRIS else SPARK_SHADER
		if _sets.size() == SHARD:
			mat.set_shader_parameter("shard", 1.0)
		node.material_override = mat
		node.visible = false
		add_child(node)
		var data := {"node": node, "mm": mm, "mat": mat, "count": 0,
			"pos": PackedVector3Array(), "vel": PackedVector3Array(), "spin": PackedVector3Array(),
			"life": PackedFloat32Array(), "span": PackedFloat32Array(), "size": PackedFloat32Array(),
			"drag": PackedFloat32Array(), "grav": PackedFloat32Array(), "turb": PackedFloat32Array(),
			"col": PackedColorArray()}
		for key in ["pos", "vel", "spin", "life", "span", "size", "drag", "grav", "turb", "col"]:
			data[key].resize(PARTICLE_CAP)
		_sets.append(data)
	return _sets[kind]


## Emits up to `count` particles of a kind (scaled by the tier); returns how many.
## Each: [position, velocity] from the generator; start delays the birth.
func emit(kind: int, count: int, at: Vector3, velocity: Vector3, spread: float, color: Color, size: float, life: float, start := 0.0, gravity := 9.0, drag := 1.5, turbulence := 0.0, jitter := 0.0) -> int:
	if tier == 0 or (kind == DEBRIS and tier < 2):
		return 0
	var want := VfxBudget.count(count if tier == 2 else maxi(1, count / 2), 0)
	var s := _pset(kind)
	var room := mini(want, PARTICLE_CAP - int(s.count))
	room = mini(room, VfxBudget.particle_room())
	if room <= 0:
		return 0
	if int(s.count) == 0 and not _claim():
		return 0
	room = VfxBudget.reserve_particles(room)
	if room <= 0:
		return 0
	_claimed_parts += room
	if VfxBudget.last_from_hero:
		_claimed_parts_hero += room
	var base := velocity.length()
	var dir := velocity.normalized() if base > 0.001 else Vector3.UP
	for k in room:
		var i := int(s.count)
		var v := (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread).normalized() * base * randf_range(0.55, 1.15)
		s.pos[i] = at + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1)) * jitter
		s.vel[i] = v
		s.spin[i] = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		s.life[i] = -start - randf() * 0.04
		s.span[i] = life * randf_range(0.7, 1.15)
		s.size[i] = size * randf_range(0.6, 1.25)
		s.drag[i] = drag
		s.grav[i] = gravity
		s.turb[i] = turbulence
		s.col[i] = color
		s.count = i + 1
	built_particles += room
	lifetime = maxf(lifetime, start + life * 1.2 + 0.1)
	(s.node as MultiMeshInstance3D).visible = true
	return room


## Particles drawn in from a ring toward `at` (a wind-up gathering in).
func gather(kind: int, count: int, at: Vector3, radius: float, color: Color, size: float, life: float, start := 0.0) -> void:
	var n := emit(kind, count, at, Vector3.UP * 0.1, 0.0, color, size, life, start, 0.0, 0.0, 0.0)
	if n == 0:
		return
	var s := _pset(kind)
	for k in n:
		var i := int(s.count) - n + k
		var a := randf() * TAU
		var from := at + Vector3(sin(a) * radius, randf_range(-0.4, 0.9), cos(a) * radius)
		s.pos[i] = from
		s.vel[i] = (at - from) / maxf(life * 0.8, 0.05)


## A short flash of real light (tier 2 only, within the shared light cap).
func light(at: Vector3, color: Color, energy: float, reach: float, start := 0.0, seconds := 0.35) -> void:
	if tier < 2 or _light_claimed or not VfxBudget.can_light():
		return
	VfxBudget._lights += 1
	_light_claimed = true
	_light.light_color = color
	_light.omni_range = reach
	_light.visible = false
	# Softer than the authored figure: several casts and the shared layers stack.
	_light_spec = {"at": at, "energy": energy * 0.7, "start": start, "seconds": seconds}


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not busy:
		return
	if owner_ref:
		var visual := owner_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation != generation:
			finish()
			return
	if _follow:
		var who := _follow.get_ref() as Node3D
		if is_instance_valid(who) and who.is_inside_tree():
			# Translation only: the composition keeps its facing as the caster moves.
			position = who.global_position
	age += delta
	_draw()
	_simulate(delta)
	if age >= lifetime:
		finish()


static func _ease(t: float, kind: String) -> float:
	match kind:
		"in": return t * t
		"back":
			var c := 1.9
			return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)
		"linear": return t
	return 1.0 - pow(1.0 - t, 3.0)


## A heartbeat: a strong beat, a softer echo, then rest.
static func heartbeat(time: float, bpm: float) -> float:
	var f := fposmod(time * bpm / 60.0, 1.0)
	return exp(-pow(f * 9.0, 2.0)) + 0.6 * exp(-pow((f - 0.24) * 10.0, 2.0))


func _draw() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in _used:
		var node := _slots[i]
		var spec := _specs[i]
		var local := age - float(spec.start)
		var seconds := float(spec.seconds)
		var t := clampf(local / seconds, 0.0, 1.0)
		node.visible = local >= 0.0 and t < 1.0
		if not node.visible:
			continue
		var grow := clampf(local / float(spec.get("grow", seconds * 0.3)), 0.0, 1.0)
		var g := _ease(grow, "back" if bool(spec.get("overshoot", false)) else "out")
		var scale_now: Vector3 = spec.size * maxf(0.01, lerpf(float(spec.get("initial", 0.6)), 1.0, g))
		var moved := clampf(local / float(spec.get("move", seconds)), 0.0, 1.0)
		var at: Vector3 = spec.at + (spec.get("travel", Vector3.ZERO) as Vector3) * _ease(moved, String(spec.get("ease", "out")))
		if spec.has("drop"):
			at.y += float(spec.drop) * (1.0 - smoothstep(0.0, maxf(0.01, float(spec.get("land", 0.15))), local))
		var rot: Vector3 = spec.rot
		rot.y += float(spec.get("spin", 0.0)) * local
		rot.z += float(spec.get("roll", 0.0)) * local
		var basis := Basis.from_euler(rot)
		if spec.has("bill") and camera:
			basis = _billboard(spec.bill, at, camera, rot.z)
		node.transform = Transform3D(basis * Basis.from_scale(scale_now.sign() * scale_now.abs().max(Vector3.ONE * 0.003)), at)
		var mat := _mats[i]
		var sweep_time := float(spec.get("sweep", 0.0))
		var head := 1.0
		if sweep_time > 0.0:
			var s := clampf(local / sweep_time, 0.0, 1.0)
			head = _ease(s, "out") + maxf(0.0, local - sweep_time) / maxf(seconds - sweep_time, 0.05) * float(spec.get("exit", 0.0)) * (1.0 + float(spec.get("tail", 0.6)))
		mat.set_shader_parameter("sweep", head)
		mat.set_shader_parameter("age", local)
		mat.set_shader_parameter("appear", smoothstep(0.0, float(spec.get("fade_in", 0.08)), t))
		mat.set_shader_parameter("gone", smoothstep(float(spec.get("dissolve", 0.55)), 1.0, t))
		if spec.has("pulse"):
			mat.set_shader_parameter("pulse", heartbeat(local, float(spec.pulse)))
	if not _light_spec.is_empty() and _light:
		var lt := (age - float(_light_spec.start)) / float(_light_spec.seconds)
		_light.visible = lt >= 0.0 and lt < 1.0
		if _light.visible:
			_light.position = _light_spec.at
			_light.light_energy = float(_light_spec.energy) * (1.0 - lt) * (1.0 - lt) * smoothstep(0.0, 0.08, lt)


## Billboards: "upright" turns round Y toward the camera; a Vector3 axis keeps
## local +X on that (rig-local) axis and turns the face toward the camera.
func _billboard(mode: Variant, at: Vector3, camera: Camera3D, roll: float) -> Basis:
	var to_cam := basis.inverse() * (camera.global_position - transform * at)
	if mode is Vector3:
		var x := (mode as Vector3).normalized()
		var z := (to_cam - x * to_cam.dot(x))
		z = z.normalized() if z.length_squared() > 0.0001 else Vector3.UP
		var y := z.cross(x)
		return Basis(x, y, z) * Basis(Vector3.BACK, roll)
	var flat := Vector3(to_cam.x, 0, to_cam.z)
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.0001 else 0.0
	return Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll)


func _simulate(delta: float) -> void:
	if _sets.is_empty():
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var view := Vector3(0, 1, 1)
	if camera:
		view = basis.inverse() * (camera.global_position - position)
	var floor_y := 0.02
	for kind in _sets.size():
		var s := _sets[kind]
		var count := int(s.count)
		if count == 0:
			continue
		var mm: MultiMesh = s.mm
		var pos: PackedVector3Array = s.pos
		var vel: PackedVector3Array = s.vel
		var life: PackedFloat32Array = s.life
		var alive := 0
		for i in count:
			life[i] += delta
			var lt: float = life[i] / float(s.span[i])
			if life[i] < 0.0 or lt >= 1.0:
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), pos[i]))
				mm.set_instance_color(i, Color(0, 0, 0, 0))
				if life[i] < 0.0:
					alive += 1
				continue
			alive += 1
			var v := vel[i]
			var turb := float(s.turb[i])
			if turb > 0.0:
				var q := pos[i]
				v += Vector3(sin(q.y * 2.3 + life[i] * 3.1 + float(i)), cos(q.x * 1.7 + life[i] * 2.3), sin(q.z * 2.1 - life[i] * 2.7 + float(i) * 0.7)) * turb * delta
			v.y -= float(s.grav[i]) * delta
			v *= maxf(0.0, 1.0 - float(s.drag[i]) * delta)
			var p := pos[i] + v * delta
			if kind == DEBRIS and p.y < floor_y and v.y < 0.0:
				# Bounce once or twice, losing most of the energy, then settle.
				p.y = floor_y
				v = Vector3(v.x * 0.5, -v.y * 0.32, v.z * 0.5)
			vel[i] = v
			pos[i] = p
			var c: Color = s.col[i]
			var size := float(s.size[i])
			if kind == DEBRIS:
				var spin: Vector3 = s.spin[i] * life[i]
				var shrink := 1.0 - smoothstep(0.75, 1.0, lt)
				mm.set_instance_transform(i, Transform3D(Basis.from_euler(spin).scaled(Vector3.ONE * size * shrink), p))
				mm.set_instance_color(i, Color(c.r, c.g, c.b, (1.0 - lt) * (1.0 - lt)))
			else:
				var speed := v.length()
				var dir := v / speed if speed > 0.001 else Vector3.UP
				var length := size * (1.6 + speed * 0.16) if kind == SPARK else size * 2.2
				var side := dir.cross(view - p)
				side = side.normalized() if side.length_squared() > 0.000001 else Vector3.RIGHT
				var width := size * (0.55 if kind == SPARK else 1.0)
				if kind == SHARD:
					var a := life[i] * 6.0 + float(i)
					side = (side * cos(a) + side.cross(dir) * sin(a)).normalized()
				var fwd := side.cross(dir)
				mm.set_instance_transform(i, Transform3D(Basis(side * width, dir * length, fwd * width), p - dir * length * 0.8))
				var fade := smoothstep(0.0, 0.08, lt) * (1.0 - smoothstep(0.55, 1.0, lt))
				mm.set_instance_color(i, Color(c.r, c.g, c.b, fade))
		mm.visible_instance_count = count
		if alive == 0:
			s.count = 0
			mm.visible_instance_count = 0
			(s.node as MultiMeshInstance3D).visible = false
		if kind == SHARD:
			(s.mat as ShaderMaterial).set_shader_parameter("age", age)


# ---------------------------------------------------------------------------
# Shared building blocks of the three lines (rig-local: +Z toward the target)
# ---------------------------------------------------------------------------

## A blade arc: a crescent whose head burns white and sweeps across in `sweep`
## seconds while the tail cools to the palette and the dark rim, then lingers
## and dissolves. roll tilts the plane (0 flat, +-1 diagonal), mirror flips
## the direction. Sparks shear off the leading edge as it passes.
func slash(c: Array, at: Vector3, radius: float, yaw: float, roll: float, start: float, mirror := false, span := "arc220", sweep := 0.12, sparks := 10, core := true, seconds := 0.55) -> void:
	var sx := -1.0 if mirror else 1.0
	layer(span, RIBBON, c, at, Vector3(radius * sx, 1, radius), Vector3(0, yaw, roll), start, seconds, {"sweep": sweep, "tail": 1.15, "thick": 0.62, "initial": 0.92, "grow": 0.1, "dissolve": 0.45, "fade_in": 0.02}, core)
	# A thinner, darker after-smear just outside: the cooling trail lags behind.
	layer(span, RIBBON, [c[2].lerp(c[0], 0.5), c[0], c[2]], at + Vector3.UP * 0.02, Vector3(radius * 1.08 * sx, 1, radius * 1.08), Vector3(0, yaw, roll), start + 0.035, seconds * 1.15, {"sweep": sweep * 1.4, "tail": 1.2, "thick": 0.42, "initial": 0.95, "opacity": 0.8, "dissolve": 0.35, "fade_in": 0.05, "ink": true})
	if sparks <= 0:
		return
	var half: float = {"arc150": deg_to_rad(75.0), "arc220": deg_to_rad(110.0), "arc330": deg_to_rad(165.0)}.get(span, deg_to_rad(110.0))
	var basis := Basis.from_euler(Vector3(0, yaw, roll))
	for k in 3:
		var f := 0.35 + 0.3 * float(k)
		var a := (-half + 2.0 * half * f) * sx
		var p := at + basis * (Vector3(sin(a), 0, cos(a)) * radius)
		var tangent := basis * (Vector3(cos(a), 0, -sin(a)) * sx)
		var out := basis * Vector3(sin(a), 0, cos(a))
		emit(SPARK, sparks / 3 + 1, p, (tangent * 0.8 + out * 0.6 + Vector3.UP * 0.4) * 7.0, 0.35, c[0].lerp(c[1], 0.4), 0.13, 0.5, start + sweep * f, 9.0, 1.2)


## A light streak from a to b (the thrust's piercing line): the head runs out in
## `sweep`, the tail lags and cools.
func streak(c: Array, a: Vector3, b: Vector3, width: float, start: float, seconds := 0.55, sweep := 0.08, style := {}, core := true) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.01:
		return
	var yaw := atan2(d.x, d.z)
	var pitch := -asin(clampf(d.y / length, -1.0, 1.0))
	var options := {"sweep": sweep, "tail": 0.85, "thick": 0.55, "symmetric": true, "initial": 1.0, "dissolve": 0.4, "fade_in": 0.02}
	options.merge(style, true)
	layer("streak", RIBBON, c, a, Vector3(width, width, length), Vector3(pitch, yaw, 0), start, seconds, options, core)


## A flat ring (shock, ripple, wind) at `at`, turned by rot, growing r0 -> r1.
func ring(c: Array, at: Vector3, r0: float, r1: float, start: float, seconds := 0.5, rot := Vector3.ZERO, style := {}, core := false) -> void:
	var options := {"initial": r0 / maxf(r1, 0.01), "grow": seconds * 0.8, "dissolve": 0.3, "fade_in": 0.05}
	options.merge(style, true)
	layer("ring", RING, c, at, Vector3.ONE * r1, rot, start, seconds, options, core)


## Ground cracks with glowing seams that run out from the centre and cool.
func cracks(c: Array, at: Vector3, radius: float, start: float, seconds := 1.3, alt := false, core := false) -> void:
	var yaw := randf() * TAU
	var kind := "cracks_b" if alt else "cracks"
	layer(kind, GROUND, c, at + Vector3.UP * 0.03, Vector3.ONE * radius, Vector3(0, yaw, 0), start, seconds, {"sweep": 0.22, "initial": 1.0, "dissolve": 0.6, "fade_in": 0.02, "opacity": 0.8}, core)
	# The molten seam glows on top of the scorched crack and cools first.
	layer(kind, GROUND, c, at + Vector3.UP * 0.05, Vector3.ONE * radius, Vector3(0, yaw, 0), start, seconds * 0.75, {"sweep": 0.22, "initial": 1.0, "dissolve": 0.4, "fade_in": 0.02, "opacity": 0.9, "ink": false, "narrow": 0.55})


## Rock chips thrown up from the ground, glowing at the cracks, with gravity and bounce.
func chips(at: Vector3, count: int, speed: float, tint: Color, hot: float, size: float, start := 0.0, spread := 0.9) -> void:
	emit(DEBRIS, count, at + Vector3.UP * 0.1, Vector3.UP * speed, spread, Color(tint.r, tint.g, tint.b, hot), size * 1.9, 1.2, start, 13.0, 0.4, 0.0, 0.35)


## Embers / motes drifting up with turbulence.
func embers(at: Vector3, count: int, radius: float, color: Color, start := 0.0, life := 1.1, rise := 1.6, size := 0.06) -> void:
	emit(SPARK, count, at, Vector3.UP * rise, 0.5, color, size, life, start, -0.6, 0.9, 5.0, radius)


## The elite moment and its lasting aura, round the caster (rig origin): a
## magic circle on the ground turning slowly over a dark under-print, a pillar
## of light bursting up at the cast with a shock ring, two rune rings orbiting
## at waist and crown in opposite senses, a soft inner glow and embers rising
## through the whole linger. grand: the elite set (full size, both rings and
## the pillar); otherwise a lighter circle and one ring for the lesser buffs.
## The layers are drawn first so a trimmed tier keeps the circle.
func ascend(c: Array, size: float, d: float, linger := 2.4, grand := true) -> void:
	var soft := [c[0], c[1].lerp(c[0], 0.25), c[2]]
	layer("sigil", RING, soft, Vector3(0, 0.05, 0), Vector3.ONE * size * 1.2, Vector3.ZERO, d, linger, {"initial": 0.3, "grow": 0.4, "overshoot": true, "spin": 0.45, "opacity": 0.62 if grand else 0.5, "dissolve": 0.72, "fade_in": 0.1}, grand)
	layer("sigil", RING, [c[2], c[2].lerp(c[0], 0.35), c[2]], Vector3(0, 0.035, 0), Vector3.ONE * size * 1.24, Vector3.ZERO, d, linger, {"initial": 0.3, "grow": 0.4, "overshoot": true, "spin": 0.45, "opacity": 0.35, "dissolve": 0.7, "fade_in": 0.1, "ink": true})
	layer("runes", RING, soft, Vector3(0, 0.95, 0), Vector3.ONE * size * 0.55, Vector3(0.22, 0, 0.08), d + 0.08, linger * 0.92, {"initial": 0.2, "grow": 0.35, "overshoot": true, "spin": 1.5, "opacity": 0.72, "dissolve": 0.7, "fade_in": 0.12})
	if grand:
		layer("runes", RING, soft, Vector3(0, 2.05, 0), Vector3.ONE * size * 0.36, Vector3(-0.18, 0, -0.1), d + 0.16, linger * 0.85, {"initial": 0.2, "grow": 0.3, "overshoot": true, "spin": -2.2, "opacity": 0.66, "dissolve": 0.7, "fade_in": 0.12})
		# The cast moment: a column of light leaps up and thins away in half a second.
		layer("aura", AURA, soft, Vector3.ZERO, Vector3(0.5, 4.6, 0.5) * Vector3(size * 0.45, 1, size * 0.45), Vector3.ZERO, d, 0.6, {"initial": 0.15, "grow": 0.14, "overshoot": true, "opacity": 0.4, "dissolve": 0.3, "fade_in": 0.03})
		ring(soft, Vector3(0, 0.1, 0), 0.4, size * 1.7, d, 0.55, Vector3.ZERO, {"opacity": 0.5})
	# A soft glow that stays with the caster (the lasting aura).
	layer("aura", AURA, soft, Vector3.ZERO, Vector3(0.72, 1.7 + 0.3 * size, 0.72), Vector3.ZERO, d + 0.1, linger, {"initial": 0.6, "grow": 0.4, "opacity": 0.26, "dissolve": 0.7, "fade_in": 0.2})
	var ember: Color = (c[0] as Color).lerp(c[1], 0.3)
	for k in (3 if grand else 2):
		embers(Vector3(0, 0.15, 0), 9 if grand else 6, size * 0.6, ember, d + linger * 0.3 * k, 1.4, 1.8, 0.06)
	if grand:
		light(Vector3(0, 1.4, 0), c[0], 2.2, size * 3.0, d, 0.6)
