class_name ElementFx
extends RefCounted
## Elements that look like what they are:
##   fire   flickering flame tongues (shaders/vfx_flame), embers, scorched ground
##   ice    faceted ice crystals that burst out of the ground, then shatter
##   vine   thorny vines that wind up out of the earth around the enemies
##   plant  sprouts that grow and bloom, mushrooms puffing spores, a world tree
##   leaf   spinning leaves for nature projectiles
## Everything is cosmetic, frees itself and respects [VfxBudget].

const FLAME_SHADER := preload("res://shaders/vfx_flame.gdshader")
const CRYSTAL_SHADER := preload("res://shaders/vfx_crystal.gdshader")
const VINE_SHADER := preload("res://shaders/vfx_vine.gdshader")

## Skills whose nature magic is vines, and those that grow plants.
const VINE_SKILLS := ["entangle", "ensnare", "thorn_storm", "cataclysm"]
const PLANT_SKILLS := {"world_tree": "tree", "spore_burst": "spores", "nature_wrath": "sprouts", "sylvan_ray": "sprouts"}
const BARK := Color("537849")
const THORN := Color("98644f")
const LEAF := Color("53aa77")
const LEAF_LIGHT := Color("b2d991")

static var _flame_quad: QuadMesh
static var _crystal_mesh: ArrayMesh
static var _shard_mesh: ArrayMesh
static var _leaf_mesh: ArrayMesh


## Check at the primitive boundary: callers can saturate the budget between
## two field elements or while a delayed crystal is waiting to shatter.
static func _can_add(parent: Node3D, cost := 1) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion() and VfxBudget.can_decorate(cost)


## The element a skill's effects are drawn as.
static func element_of(skill: Dictionary) -> String:
	var id := String(skill.get("id", ""))
	if id in VINE_SKILLS:
		return "vine"
	if PLANT_SKILLS.has(id):
		return "plant"
	if id == "watornado":
		return "water"
	var style := SkillShow.style_of(skill)
	if style == "leaf" and SkillShow.family_of(skill) == "summoner":
		return "plant"
	return style


# ---------------------------------------------------------------------------
# Fire
# ---------------------------------------------------------------------------

static func _flame_mesh() -> QuadMesh:
	if _flame_quad == null:
		_flame_quad = QuadMesh.new()
		_flame_quad.size = Vector2(1, 1)
		_flame_quad.center_offset = Vector3(0, 0.5, 0)
	return _flame_quad


## One flame tongue standing at [param pos]: flares up, flickers, burns away.
static func flame(parent: Node3D, pos: Vector3, width: float, height: float, duration := 0.9, delay := 0.0) -> MeshInstance3D:
	if not _can_add(parent):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	mat.set_shader_parameter("seed", randf() * 40.0)
	mat.set_shader_parameter("life", 0.0)
	mat.set_shader_parameter("speed", randf_range(2.0, 3.0))
	var mi := MeshInstance3D.new()
	mi.mesh = _flame_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	VfxBudget.track_decoration(mi)
	mi.global_position = pos
	mi.scale = Vector3(width, height * 0.4, width)
	var tween := mi.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(v: float): mat.set_shader_parameter("life", v), 0.0, 1.0, 0.12)
	tween.parallel().tween_property(mi, "scale", Vector3(width, height, width), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(duration - 0.45, 0.05))
	tween.tween_method(func(v: float): mat.set_shader_parameter("life", v), 1.0, 0.0, 0.33)
	tween.parallel().tween_property(mi, "scale:y", height * 1.25, 0.33)
	tween.tween_callback(mi.queue_free)
	return mi


## A field of fire over a blast area (or a ring of it around the caster).
static func fire_field(parent: Node3D, center: Vector3, radius: float, tier := 1, ring := false) -> void:
	if not _can_add(parent, 2):
		return
	var count := VfxBudget.count(7 + tier * 2, 4)
	var r := minf(radius, 6.0)
	if not ring:
		flame(parent, center, 2.2 + tier * 0.1, 3.4 + tier * 0.25, 1.1)
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.25, 0.25)
		var dist := r * (randf_range(0.65, 0.95) if ring else sqrt(randf_range(0.08, 1.0)))
		var p := center + Vector3(cos(angle), 0, sin(angle)) * dist
		flame(parent, p, randf_range(1.1, 1.7), randf_range(1.6, 2.8), randf_range(0.8, 1.1), randf_range(0.0, 0.18))
	_scorch(parent, center, r)
	_heat_glow(parent, center, r)
	# Smoke and a colored pressure edge sell the volume of a fire eruption;
	# they use the shared budget and never create damage or persistent nodes.
	VfxKit.impact_smoke(parent, center + Vector3.UP * 0.35, Color("9e6d70"), minf(r * 0.45, 2.4))
	if tier >= 3:
		VfxKit.impact_ring(parent, center + Vector3.UP * 0.3, Color("f99b4d"), r * 0.78, 0.58)
	VfxArt.motes(parent, center + Vector3(0, 0.3, 0), Color("ffb050"), "ember", 16 + tier * 3, r, 1.8, 1.3)


## A few flames licking up an enemy that was hit.
static func flame_hit(parent: Node3D, pos: Vector3) -> void:
	var ground := Vector3(pos.x, maxf(pos.y - 1.1, 0.0), pos.z)
	for i in 2:
		var off := Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))
		flame(parent, ground + off, randf_range(0.6, 0.9), randf_range(1.1, 1.7), 0.55, i * 0.06)


## Small flames shed along a fireball's path (called while it flies).
static func flame_puff(parent: Node3D, pos: Vector3, size := 0.5) -> void:
	flame(parent, pos - Vector3(0, size * 0.6, 0), size * 1.1, size * 1.8, 0.32)


## Orange firelight spilling over the ground under the flames.
static func _heat_glow(parent: Node3D, center: Vector3, radius: float) -> void:
	if not _can_add(parent):
		return
	var mat := VfxKit._glow(Color("e99b52"), 0.24, false)
	mat.albedo_texture = VfxKit.soft_dot()
	var mi := VfxKit._instance(parent, VfxKit.ground_quad(), mat, center + Vector3(0, 0.05, 0))
	VfxBudget.track_decoration(mi)
	mi.scale = Vector3(radius * 1.2, 1, radius * 1.2)
	var tween := mi.create_tween()
	tween.tween_interval(0.7)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(mi.queue_free)


static func _scorch(parent: Node3D, center: Vector3, radius: float) -> void:
	if not _can_add(parent):
		return
	var mat := VfxKit._glow(Color("705245"), 0.3, false)
	mat.albedo_texture = SpectacleAssets.tex("scorch")
	var mi := VfxKit._instance(parent, VfxKit.ground_quad(), mat, center + Vector3(0, 0.03, 0))
	VfxBudget.track_decoration(mi)
	mi.scale = Vector3(radius * 0.9, 1, radius * 0.9)
	var tween := mi.create_tween()
	tween.tween_interval(0.9)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(mi.queue_free)


# ---------------------------------------------------------------------------
# Ice
# ---------------------------------------------------------------------------

## A hexagonal crystal standing on y = 0 with its tip at y = 1 (flat facets).
static func crystal_mesh() -> ArrayMesh:
	if _crystal_mesh == null:
		_crystal_mesh = _bipyramid(6, 0.5, 0.18, 1.0, -0.12)
	return _crystal_mesh


static func _shard() -> ArrayMesh:
	if _shard_mesh == null:
		_shard_mesh = _bipyramid(4, 0.5, 0.0, 1.0, -0.6)
	return _shard_mesh


static func _bipyramid(sides: int, radius: float, ring_y: float, top: float, bottom: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for i in sides:
		var a := TAU * float(i) / float(sides)
		ring.append(Vector3(cos(a) * radius, ring_y, sin(a) * radius))
	var apex := Vector3(0.04, top, -0.03)
	var foot := Vector3(0, bottom, 0)
	for i in sides:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % sides]
		for face in [[a, apex, b], [b, foot, a]]:
			var tri: Array = face
			var n: Vector3 = ((tri[1] - tri[0]).cross(tri[2] - tri[0])).normalized()
			if n.dot((tri[0] + tri[1] + tri[2]) / 3.0 - Vector3(0, (top + bottom) * 0.5, 0)) < 0.0:
				n = -n
				tri = [tri[0], tri[2], tri[1]]
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


static func _crystal_material(fade := 1.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CRYSTAL_SHADER
	mat.set_shader_parameter("fade", fade)
	return mat


## One crystal bursting out of the ground, holding, then shattering.
static func crystal(parent: Node3D, pos: Vector3, width: float, height: float, tilt: Vector3, hold := 0.7, delay := 0.0) -> void:
	if not _can_add(parent):
		return
	var mat := _crystal_material()
	var mi := MeshInstance3D.new()
	mi.mesh = crystal_mesh()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	VfxBudget.track_decoration(mi)
	mi.global_position = pos
	mi.rotation = tilt
	mi.scale = Vector3(width * 0.4, 0.01, width * 0.4)
	var tween := mi.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(mi, "scale", Vector3(width, height, width), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_callback(func():
		if is_instance_valid(mi) and mi.is_inside_tree():
			shatter(mi.get_parent() as Node3D, mi.global_position + Vector3(0, height * 0.45, 0), width, 4))
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.18)
	tween.parallel().tween_property(mi, "scale", Vector3(width * 1.15, height * 0.6, width * 1.15), 0.18)
	tween.tween_callback(mi.queue_free)


## Ice fragments flying apart from [param pos].
static func shatter(parent: Node3D, pos: Vector3, size: float, count := 5) -> void:
	if not _can_add(parent):
		return
	var mat := _crystal_material()
	for i in VfxBudget.count(count):
		if not _can_add(parent):
			break
		var mi := MeshInstance3D.new()
		mi.mesh = _shard()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		VfxBudget.track_decoration(mi)
		mi.global_position = pos
		mi.scale = Vector3.ONE * size * randf_range(0.18, 0.32)
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.0), randf_range(-1, 1)).normalized()
		var end := pos + dir * randf_range(1.0, 2.0) * size + Vector3(0, -0.6, 0)
		var tween := mi.create_tween().set_parallel(true)
		tween.tween_property(mi, "global_position", end, 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(mi, "rotation", mi.rotation + Vector3(4, 3, 2), 0.42)
		tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.42).set_delay(0.1)
		tween.chain().tween_callback(mi.queue_free)
	VfxArt.motes(parent, pos, Color("e8f8ff"), "snow", 6, size, 0.2, 0.7)


## A forest of ice crystals over a blast area.
static func ice_field(parent: Node3D, center: Vector3, radius: float, tier := 1, ring := false) -> void:
	if not _can_add(parent, 2):
		return
	var r := minf(radius, 6.0)
	var count := VfxBudget.count(7 + tier * 2, 4)
	if not ring:
		crystal(parent, center, 1.4 + tier * 0.08, 3.2 + tier * 0.2, Vector3(0, randf() * TAU, 0), 0.8)
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := r * (randf_range(0.6, 0.95) if ring else sqrt(randf_range(0.1, 1.0)))
		var p := center + Vector3(cos(angle), 0, sin(angle)) * dist
		# Lean outwards from the centre like a frozen burst.
		var lean := Vector3(sin(angle), 0, -cos(angle)) * randf_range(0.15, 0.45)
		crystal(parent, p, randf_range(0.65, 1.05), randf_range(1.6, 2.8), Vector3(lean.x, randf() * TAU, lean.z), randf_range(0.55, 0.8), randf_range(0.0, 0.15))
	_frost(parent, center, r)
	if tier >= 3:
		VfxKit.impact_ring(parent, center + Vector3.UP * 0.45, Color("a0e4ec"), r * 0.72, 0.6)
	VfxKit.impact_smoke(parent, center + Vector3.UP * 0.2, Color("9bced9"), minf(r * 0.4, 2.0))
	VfxArt.motes(parent, center + Vector3(0, 0.2, 0), Color("e8f8ff"), "snow", 14 + tier * 3, r, 0.8, 1.3)


## Ice locking an enemy that was hit: a few crystals at its feet.
static func ice_hit(parent: Node3D, pos: Vector3) -> void:
	var ground := Vector3(pos.x, maxf(pos.y - 1.1, 0.0), pos.z)
	for i in 3:
		var a := TAU * float(i) / 3.0 + randf() * 0.6
		var lean := Vector3(sin(a), 0, -cos(a)) * 0.35
		crystal(parent, ground + Vector3(cos(a), 0, sin(a)) * 0.45, randf_range(0.3, 0.45), randf_range(0.8, 1.3), Vector3(lean.x, randf() * TAU, lean.z), 0.35, i * 0.04)


static func _frost(parent: Node3D, center: Vector3, radius: float) -> void:
	if not _can_add(parent):
		return
	var mat := VfxKit._glow(Color("96d4de"), 0.28, false)
	mat.albedo_texture = VfxArt.texture("snow")
	var mi := VfxKit._instance(parent, VfxKit.ground_quad(), mat, center + Vector3(0, 0.04, 0))
	VfxBudget.track_decoration(mi)
	mi.scale = Vector3(radius, 1, radius)
	mi.rotation.y = randf() * TAU
	var tween := mi.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(mi.queue_free)


## A spinning ice lance (essential projectile silhouette), pointing along -z.
## Its gameplay carrier owns cleanup; decorative saturation must not hide it.
static func ice_lance(holder: Node3D, size: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = crystal_mesh()
	mi.material_override = _crystal_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.scale = Vector3(size * 0.7, size * 3.2, size * 0.7)
	mi.position = Vector3(0, 0, size * 1.2)
	holder.add_child(mi)
	var spin := mi.create_tween().set_loops()
	spin.tween_property(mi, "rotation:y", TAU, 0.4).as_relative()


# ---------------------------------------------------------------------------
# Vines and plants (one growing mesh each; see shaders/vfx_vine)
# ---------------------------------------------------------------------------

static func _grow_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VINE_SHADER
	mat.set_shader_parameter("growth", 0.0)
	mat.set_shader_parameter("wither", 0.0)
	return mat


## Adds a tapering tube along [param points] (UV.y runs from v0 to v1).
static func _tube(st: SurfaceTool, points: Array[Vector3], r0: float, r1: float, color: Color, v0: float, v1: float, sides := 5) -> void:
	var rings: Array = []
	for i in points.size():
		var t := float(i) / float(points.size() - 1)
		var forward: Vector3 = (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := forward.cross(Vector3.UP if absf(forward.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := side.cross(forward).normalized()
		var ring: Array = []
		for k in sides:
			var a := TAU * float(k) / float(sides)
			var n := side * cos(a) + up * sin(a)
			ring.append([points[i] + n * lerpf(r0, r1, t), n])
		rings.append(ring)
	for i in points.size() - 1:
		var va := lerpf(v0, v1, float(i) / float(points.size() - 1))
		var vb := lerpf(v0, v1, float(i + 1) / float(points.size() - 1))
		for k in sides:
			var a: Array = rings[i][k]
			var b: Array = rings[i][(k + 1) % sides]
			var c: Array = rings[i + 1][k]
			var d: Array = rings[i + 1][(k + 1) % sides]
			for vert in [[a, va], [c, vb], [b, va], [b, va], [c, vb], [d, vb]]:
				st.set_color(color)
				st.set_uv(Vector2(0, vert[1]))
				st.set_normal(vert[0][1])
				st.add_vertex(vert[0][0])


## A thorn (small cone) at [param at] pointing along [param dir].
static func _thorn(st: SurfaceTool, at: Vector3, dir: Vector3, length: float, v: float) -> void:
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized() * length * 0.28
	var up := side.cross(dir).normalized() * length * 0.28
	var tip := at + dir * length
	var base := [at + side, at + up, at - side, at - up]
	for k in 4:
		var a: Vector3 = base[k]
		var b: Vector3 = base[(k + 1) % 4]
		var n := (b - a).cross(tip - a).normalized()
		for p in [a, b, tip]:
			st.set_color(THORN)
			st.set_uv(Vector2(0, v))
			st.set_normal(n)
			st.add_vertex(p)


## A gently folded leaf/petal. Its raised center and fine vein catch light,
## while UV.y stays the growth coordinate shared with its stem.
static func _leaf(st: SurfaceTool, at: Vector3, dir: Vector3, size: float, v: float, color := LEAF) -> void:
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized() * size * 0.32
	var tip := at + dir * size
	var mid := at + dir * size * 0.45
	var n := side.cross(dir).normalized()
	var ridge := mid + n * size * 0.08
	var verts: Array[Vector3] = [at, mid + side, tip, mid - side, ridge]
	var across := [0.5, 1.0, 0.5, 0.0, 0.5]
	var tip_color := color.lerp(LEAF_LIGHT, 0.35) if color.g > color.r else color.lightened(0.14)
	for tri in [[0, 1, 4], [1, 2, 4], [2, 3, 4], [3, 0, 4]]:
		var normal := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]]).normalized()
		if normal.dot(n) < 0.0:
			normal = -normal
		for index in tri:
			st.set_color(tip_color if index == 2 or index == 4 else color)
			st.set_uv(Vector2(across[index], v))
			st.set_normal(normal)
			st.add_vertex(verts[index])


## A vine winding up a helix around [param center], with thorns and leaves.
static func vine_mesh(radius: float, height: float, turns: float, phase: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector3] = []
	var steps := 22
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := phase + turns * TAU * t
		var r := radius * (1.0 - 0.35 * t) + 0.12 * sin(t * 9.0)
		points.append(Vector3(cos(a) * r, height * t - 0.15, sin(a) * r))
	_tube(st, points, 0.21, 0.045, BARK, 0.0, 1.0, 6)
	for i in range(2, steps, 2):
		var t := float(i) / float(steps)
		var p: Vector3 = points[i]
		var out := Vector3(p.x, 0, p.z).normalized()
		if i % 4 == 2:
			_thorn(st, p, (out + Vector3(0, 0.4, 0)).normalized(), 0.32 * (1.1 - t * 0.5), t)
		else:
			_leaf(st, p, (out + Vector3(0, 0.6, 0) + (points[i + 1] - p).normalized() * 0.3).normalized(), 0.6 * (1.15 - t * 0.4), t)
	return st.commit()


## A vine bursting from the ground at [param pos]: grows, holds, withers away.
static func vine(parent: Node3D, pos: Vector3, radius: float, height: float, hold := 1.0, delay := 0.0) -> void:
	if not _can_add(parent):
		return
	var mat := _grow_material()
	var mi := MeshInstance3D.new()
	mi.mesh = vine_mesh(radius, height, randf_range(1.2, 1.8), randf() * TAU)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	VfxBudget.track_decoration(mi)
	mi.global_position = pos
	var tween := mi.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(v: float): mat.set_shader_parameter("growth", v), 0.0, 1.0, 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(hold)
	tween.tween_method(func(v: float): mat.set_shader_parameter("wither", v), 0.0, 1.0, 0.25)
	tween.tween_method(func(v: float): mat.set_shader_parameter("growth", v), 1.0, 0.0, 0.3)
	tween.tween_callback(mi.queue_free)


## Thorny vines erupting over a blast area, wrapping whoever stands there.
static func vine_field(parent: Node3D, center: Vector3, radius: float, tier := 1, ring := false) -> void:
	if not _can_add(parent, 2):
		return
	var r := minf(radius, 6.0)
	var count := VfxBudget.count(5 + tier, 3)
	if not ring:
		vine(parent, center, 0.85, 3.4 + tier * 0.2, 1.2)
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := r * (randf_range(0.6, 0.95) if ring else sqrt(randf_range(0.12, 1.0)))
		vine(parent, center + Vector3(cos(angle), 0, sin(angle)) * dist, randf_range(0.45, 0.75), randf_range(2.2, 3.2), randf_range(0.8, 1.2), randf_range(0.0, 0.2))
	VfxArt.motes(parent, center + Vector3(0, 0.3, 0), LEAF_LIGHT, "leaf", 10 + tier * 2, r, 1.0, 1.2)
	_dirt(parent, center, r)


## Vines binding one enemy that was hit.
static func vine_bind(parent: Node3D, pos: Vector3) -> void:
	vine(parent, Vector3(pos.x, maxf(pos.y - 1.1, 0.0), pos.z), 0.6, 2.3, 0.7)


static func _dirt(parent: Node3D, center: Vector3, radius: float) -> void:
	if not _can_add(parent):
		return
	var mat := VfxKit._glow(Color("786443"), 0.28, false)
	mat.albedo_texture = SpectacleAssets.tex("dirt")
	var mi := VfxKit._instance(parent, VfxKit.ground_quad(), mat, center + Vector3(0, 0.03, 0))
	VfxBudget.track_decoration(mi)
	mi.scale = Vector3(radius * 0.8, 1, radius * 0.8)
	var tween := mi.create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_callback(mi.queue_free)


## A sprout: a curved stem with leaves and a flower that opens at the top.
static func sprout_mesh(height: float, flower: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bend := Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var points: Array[Vector3] = []
	for i in 9:
		var t := float(i) / 8.0
		points.append(Vector3(0, height * t, 0) + bend * t * t)
	_tube(st, points, 0.1, 0.05, Color("4a8a2e"), 0.0, 0.75, 4)
	for i in [2, 4, 6]:
		var t := float(i) / 8.0
		for s in [-1.0, 1.0]:
			var dir := Vector3(s * cos(float(i)), 0.5, s * sin(float(i))).normalized()
			_leaf(st, points[i], dir, 0.75 - t * 0.25, t * 0.75)
	var top: Vector3 = points[8]
	for k in 6:
		var a := TAU * float(k) / 6.0
		_leaf(st, top, Vector3(cos(a), 0.35, sin(a)).normalized(), 0.5, 0.85 + float(k) * 0.02, flower)
	for k in 3:
		_leaf(st, top + Vector3(0, 0.02, 0), Vector3(cos(k * 2.1), 1.2, sin(k * 2.1)).normalized(), 0.12, 0.97, Color("ffe060"))
	return st.commit()


static func _grow(parent: Node3D, mesh: Mesh, pos: Vector3, hold: float, delay := 0.0, grow_time := 0.45) -> MeshInstance3D:
	if not _can_add(parent):
		return null
	var mat := _grow_material()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	VfxBudget.track_decoration(mi)
	mi.global_position = pos
	mi.rotation.y = randf() * TAU
	var tween := mi.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(v: float): mat.set_shader_parameter("growth", v), 0.0, 1.0, grow_time).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_method(func(v: float): mat.set_shader_parameter("wither", v), 0.0, 1.0, 0.25)
	tween.parallel().tween_property(mi, "scale", Vector3(1.0, 0.05, 1.0), 0.35).set_delay(0.1)
	tween.tween_callback(mi.queue_free)
	return mi


## A great tree that shoots up, spreads its crown and fades (World Tree).
static func tree_mesh(height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk: Array[Vector3] = []
	for i in 10:
		var t := float(i) / 9.0
		trunk.append(Vector3(sin(t * 3.0) * 0.25, height * 0.62 * t, cos(t * 2.0) * 0.2 - 0.2))
	_tube(st, trunk, 0.55, 0.28, Color("6a4a2e"), 0.0, 0.55, 7)
	var top: Vector3 = trunk[9]
	for b in 5:
		var a := TAU * float(b) / 5.0
		var branch: Array[Vector3] = []
		for i in 6:
			var t := float(i) / 5.0
			branch.append(top - Vector3(0, height * 0.12, 0) + Vector3(cos(a) * t * 2.2, t * height * 0.22 + sin(t * 3.0) * 0.3, sin(a) * t * 2.2))
		_tube(st, branch, 0.22, 0.06, Color("6a4a2e"), 0.45, 0.72, 5)
		var tip: Vector3 = branch[5]
		for k in 9:
			var dir := Vector3(cos(k * 2.4), 0.6 + 0.5 * sin(k * 1.7), sin(k * 2.4)).normalized()
			_leaf(st, tip + dir * 0.25, dir, 1.1, 0.72 + float(k) * 0.03, [LEAF, Color("62c048"), Color("ffb6d0")][k % 3])
	for k in 14:
		var dir := Vector3(cos(k * 1.9), 0.9, sin(k * 1.9)).normalized()
		_leaf(st, top + Vector3(0, 0.4, 0), dir, 1.3, 0.8 + float(k) * 0.012, [Color("62c048"), LEAF, Color("ffc8dc")][k % 3])
	return st.commit()


## Nature magic over an area: a world tree, mushrooms with spores, or sprouts.
static func plant_field(parent: Node3D, center: Vector3, radius: float, kind := "sprouts", tier := 1, ring := false) -> void:
	if not _can_add(parent, 2):
		return
	var r := minf(radius, 6.0)
	match kind:
		"tree":
			_grow(parent, tree_mesh(5.5 + tier * 0.4), center, 1.1, 0.0, 0.6)
			var roots := VfxBudget.count(6, 3)
			for i in roots:
				var a := TAU * float(i) / float(roots)
				vine(parent, center + Vector3(cos(a), 0, sin(a)) * r * 0.75, 0.3, 1.4, 0.9, 0.2)
		"spores":
			var mushrooms := VfxBudget.count(7 + tier, 4)
			for i in mushrooms:
				if not _can_add(parent):
					break
				var a := TAU * float(i) / float(mushrooms) + randf() * 0.4
				var p := center + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.45, 0.9)
				_mushroom(parent, p, randf_range(1.1, 1.8), randf_range(0.0, 0.2))
			VfxArt.motes(parent, center + Vector3(0, 0.5, 0), Color("e8f080"), "star", 22 + tier * 3, r, 2.2, 1.6)
		_:
			var sprouts := VfxBudget.count(7 + tier * 2, 4)
			for i in sprouts:
				if not _can_add(parent):
					break
				var a := TAU * float(i) / float(sprouts) + randf() * 0.4
				var dist := r * (randf_range(0.55, 0.95) if ring else sqrt(randf_range(0.05, 1.0)))
				var flower: Color = [Color("ff9ac8"), Color("fff0a0"), Color("b8a0ff"), Color("ffffff")][i % 4]
				_grow(parent, sprout_mesh(randf_range(1.4, 2.3), flower), center + Vector3(cos(a), 0, sin(a)) * dist, randf_range(0.7, 1.0), randf_range(0.0, 0.2))
	VfxArt.motes(parent, center + Vector3(0, 0.4, 0), LEAF_LIGHT, "leaf", 12 + tier * 2, r, 1.6, 1.3)


static func _mushroom(parent: Node3D, pos: Vector3, size: float, delay: float) -> void:
	if not _can_add(parent, 5):
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = pos
	MeshKit.part(holder, MeshKit.cylinder(), MeshKit.toon(Color("f4ead0")), Vector3(0, 0.3, 0) * size, Vector3(0.22, 0.6, 0.22) * size)
	MeshKit.part(holder, MeshKit.hemisphere(), MeshKit.toon([Color("d8757e"), Color("b795d8"), Color("e0b45b")][randi() % 3]), Vector3(0, 0.55, 0) * size, Vector3(0.75, 0.6, 0.75) * size)
	for k in 3:
		MeshKit.part(holder, MeshKit.sphere_low(), MeshKit.toon(Color("fff2d2")), Vector3(cos(k * 2.1) * 0.22, 0.72, sin(k * 2.1) * 0.22) * size, Vector3.ONE * 0.12 * size)
	for part in holder.get_children():
		VfxBudget.track_decoration(part)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.scale = Vector3(1, 0.01, 1)
	var tween := holder.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(holder, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(holder) and holder.is_inside_tree():
			VfxArt.motes(holder.get_parent() as Node3D, holder.global_position + Vector3(0, 0.8 * size, 0), Color("eef8a0"), "star", 6, 0.6, 1.2, 1.0))
	tween.tween_interval(0.9)
	tween.tween_property(holder, "scale", Vector3(1.1, 0.01, 1.1), 0.2)
	tween.tween_callback(holder.queue_free)


## A flat leaf mesh pointing along +y (used for spinning leaf projectiles).
static func leaf_mesh() -> ArrayMesh:
	if _leaf_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_leaf(st, Vector3(0, -0.5, 0), Vector3.UP, 1.0, 1.0)
		_leaf_mesh = st.commit()
	return _leaf_mesh


## Spinning leaves (essential projectile silhouette) carried by [param holder].
## Its gameplay carrier owns cleanup; decorative saturation must not hide it.
static func leaf_swirl(holder: Node3D, size: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pivot := Node3D.new()
	holder.add_child(pivot)
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = leaf_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * float(k) / 3.0
		mi.position = Vector3(cos(a), sin(a), 0) * size * 0.5
		mi.rotation = Vector3(0, 0, a)
		mi.scale = Vector3.ONE * size * 1.3
		pivot.add_child(mi)
	var spin := pivot.create_tween().set_loops()
	spin.tween_property(pivot, "rotation:z", TAU, 0.35).as_relative()


## Compile the element shaders while a zone loads so the first cast never hitches.
static func warm(parent: Node3D, pos: Vector3) -> void:
	if not _can_add(parent, 3):
		return
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = pos + Vector3(0, -20, 0)
	for shader in [FLAME_SHADER, CRYSTAL_SHADER, VINE_SHADER]:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var mi := MeshInstance3D.new()
		mi.mesh = _flame_mesh()
		mi.material_override = mat
		holder.add_child(mi)
		VfxBudget.track_decoration(mi)
	var cleanup := holder.create_tween()
	cleanup.tween_interval(0.5)
	cleanup.tween_callback(holder.queue_free)
