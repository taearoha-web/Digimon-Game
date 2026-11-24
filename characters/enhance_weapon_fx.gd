class_name EnhanceWeaponFx
extends RefCounted
## How a held weapon looks at its own + (ItemData.MAX_PLUS = 15), in the weapon's own
## colour (the dominant non-dark colour of its materials):
##   +0..+6   nothing
##   +7, +8   a faint glow: a soft fresnel rim overlay (it tints, never whites out)
##   +9       a clearer glow
##   +10..+14 electric arcs crawling along the weapon, more and brighter each step
##            (+10 three clear strands .. +14 seven bright strands with double bolts)
##   +15      +14 and a gyroscope of circular arcs around the hand that holds it
##            (the grip: WeaponKit keeps it at the item's origin, +Y along the weapon)
## Everything moves in shaders (enhance_weapon_glow / enhance_weapon_arc): no script runs
## per frame. The glow is a material overlay on the weapon's own meshes; all the arcs of a
## weapon are ONE MeshInstance3D (one draw), and meshes and materials are shared by every
## weapon of the same size and colour bucket. Quality 0 keeps only the glow; [param light]
## (the other players in a crowd) keeps the glow and one cheap, slow arc mesh. No
## particles and no lights, ever.

const GLOW_SHADER := preload("res://shaders/enhance_weapon_glow.gdshader")
const ARC_SHADER := preload("res://shaders/enhance_weapon_arc.gdshader")
## The steel fallback: a grey or untextured-white weapon crackles in cold blue.
const STEEL := Color("9fd6ff")
## Arc strands by step (+10 .. +14; +15 as +14).
const STRANDS: Array[int] = [3, 4, 5, 6, 7]
## Rings around the hand at +15 (planes of the gyroscope).
const RING_PLANES := 3
## The hand ring's radius in metres (wraps: of the fist's size instead).
const HAND_RING := 0.22
## Arcs are hidden beyond this distance (metres): too small to read.
const FAR := 32.0
const ARC_NAME := "EnhanceArcs"

static var _glow_cache := {}
static var _arc_cache := {}
static var _mesh_cache := {}
static var _color_cache := {}


## Dresses [param item] (a held weapon, grip at its origin) for its +[param plus].
## [param light]: the cheap look of other players in a crowd.
static func apply(item: Node3D, plus: int, light := false) -> void:
	if item == null or plus < 7:
		return
	var meshes := MeshKit.collect_meshes(item)
	if meshes.is_empty():
		return
	var bucket := _bucket(_weapon_color(meshes))
	var glow := _glow_material(bucket, 1 if plus <= 8 else (2 if plus == 9 else (3 if plus < 15 else 4)))
	for m in meshes:
		if m.name == ARC_NAME:
			continue
		m.material_overlay = glow
	if plus < 10 or GameSettings.quality <= 0:
		return
	light = light or MemoryGuard.pressure >= 2
	var step := mini(plus, 14) - 10
	var strands: int = STRANDS[step]
	if light:
		strands = mini(strands, 2)
	elif GameSettings.quality == 1:
		strands = maxi(2, roundi(strands * 0.67))
	var planes := 0
	if plus >= 15:
		planes = 1 if light else RING_PLANES
	_add_arcs(item, meshes, bucket, step + (1 if plus >= 15 else 0), strands, planes, light)


## The look of +[param plus] in short (tests and tooltips): the counts apply() builds.
static func plan(plus: int, light := false, quality := 2) -> Dictionary:
	var out := {"glow": 0, "strands": 0, "rings": 0}
	if plus < 7:
		return out
	out.glow = 1 if plus <= 8 else (2 if plus == 9 else (3 if plus < 15 else 4))
	if plus < 10 or quality <= 0:
		return out
	var n: int = STRANDS[mini(plus, 14) - 10]
	out.strands = mini(n, 2) if light else (maxi(2, roundi(n * 0.67)) if quality == 1 else n)
	out.rings = (1 if light else RING_PLANES) if plus >= 15 else 0
	return out


# --- Colour ----------------------------------------------------------------------------

## The weapon's dominant non-dark colour (vivid accents count for more than grey
## steel); STEEL when nothing coloured is found. Cached per model.
static func _weapon_color(meshes: Array[MeshInstance3D]) -> Color:
	var key := ""
	for m in meshes:
		if m.mesh != null:
			key += str(m.mesh.get_instance_id()) + ":" + str(m.material_override.get_instance_id() if m.material_override else 0) + ","
	if _color_cache.has(key):
		return _color_cache[key]
	var hues := {}
	var grey := 0.0
	var colored := 0.0
	for m in meshes:
		if m.mesh == null or m.name == ARC_NAME:
			continue
		for s in m.mesh.get_surface_count():
			var weight := float(maxi(m.mesh.surface_get_array_len(s), 1))
			var mat := m.get_active_material(s)
			for c in _material_colors(mat):
				var col: Color = c[0]
				var w: float = weight * float(c[1])
				if col.v < 0.2:
					continue
				if col.s < 0.2:
					grey += w * col.v * 0.45
					continue
				var h := int(round(col.h * 24.0)) % 24
				hues[h] = float(hues.get(h, 0.0)) + w * col.v * (0.4 + col.s)
				colored += w * col.v * (0.4 + col.s)
	var out := STEEL
	if not hues.is_empty() and colored > grey * 0.35:
		var best := -1
		var best_w := -1.0
		for h in hues:
			# Neighbouring hues back each other up (a gradient of reds is one red).
			var w := float(hues[h]) + 0.5 * (float(hues.get((h + 1) % 24, 0.0)) + float(hues.get((h + 23) % 24, 0.0)))
			if w > best_w:
				best_w = w
				best = h
		out = Color.from_hsv(float(best) / 24.0, 0.7, 1.0)
	_color_cache[key] = out
	return out


## A material's colours with weights: albedo (or the texture's average when the albedo
## is white), emission counts double.
static func _material_colors(mat: Material) -> Array:
	var out := []
	if mat is BaseMaterial3D:
		var b := mat as BaseMaterial3D
		var albedo := b.albedo_color
		if b.albedo_texture != null and albedo.s < 0.1 and albedo.v > 0.9:
			var tex_col: Variant = _texture_color(b.albedo_texture)
			if tex_col is Color:
				albedo = tex_col
		out.append([albedo, 1.0])
		if b.emission_enabled and b.emission.v > 0.2:
			out.append([b.emission, 2.0])
	elif mat is ShaderMaterial:
		for p in ["albedo", "color", "base_color", "tint", "albedo_color", "glow", "emission"]:
			var v: Variant = (mat as ShaderMaterial).get_shader_parameter(p)
			if v is Color:
				out.append([v, 2.0 if p in ["glow", "emission"] else 1.0])
	return out


## The dominant non-dark colour of a texture (a 16x16 copy), cached; null when it cannot
## be read (no renderer).
static func _texture_color(tex: Texture2D) -> Variant:
	var id := tex.get_instance_id()
	if _color_cache.has(id):
		return _color_cache[id]
	var img := tex.get_image()
	var out: Variant = null
	if img != null and not img.is_empty():
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
		var sum := Vector3.ZERO
		var n := 0.0
		for y in 16:
			for x in 16:
				var c := img.get_pixel(x, y)
				if c.a < 0.5 or c.v < 0.2:
					continue
				var w := 0.3 + c.s
				sum += Vector3(c.r, c.g, c.b) * w
				n += w
		if n > 0.0:
			out = Color(sum.x / n, sum.y / n, sum.z / n)
	_color_cache[id] = out
	return out


## The colour bucket shared by caches: 24 hues, or steel.
static func _bucket(c: Color) -> Color:
	if c == STEEL:
		return STEEL
	return Color.from_hsv(round(c.h * 24.0) / 24.0, 0.7, 1.0)


# --- Materials -------------------------------------------------------------------------

## The glow overlay of a colour at level 1 (+7, +8), 2 (+9), 3 (+10..+14), 4 (+15).
static func _glow_material(color: Color, level: int) -> ShaderMaterial:
	var key := "%s|%d" % [color.to_html(false), level]
	if _glow_cache.has(key):
		return _glow_cache[key]
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("fill", [0.0, 0.035, 0.07, 0.045, 0.05][level])
	m.set_shader_parameter("rim", [0.0, 0.9, 1.5, 1.0, 1.1][level])
	m.set_shader_parameter("rim_power", [2.4, 2.2, 1.8, 2.0, 1.9][level])
	m.set_shader_parameter("breath", [0.0, 0.25, 0.3, 0.28, 0.25][level])
	m.set_shader_parameter("speed", [0.0, 1.4, 1.8, 2.2, 2.6][level])
	m.set_shader_parameter("shimmer", [0.0, 0.55, 0.8, 1.0, 1.25][level])
	MaterialKeeper.keep(m)
	_glow_cache[key] = m
	return m


## The arc material of a colour at step 0 (+10) .. 5 (+15); [param lite] slow and calm.
static func _arc_material(color: Color, step: int, lite: bool) -> ShaderMaterial:
	var key := "%s|%d|%s" % [color.to_html(false), step, lite]
	if _arc_cache.has(key):
		return _arc_cache[key]
	var m := ShaderMaterial.new()
	m.shader = ARC_SHADER
	# A vivid tint so the arcs read even over a pale blade (a white core alone vanishes on it).
	var vivid := Color.from_hsv(color.h, maxf(color.s, 0.8), 1.0) if color.s > 0.08 else color
	m.set_shader_parameter("tint", vivid)
	m.set_shader_parameter("intensity", [1.0, 1.05, 1.1, 1.15, 1.25, 1.3][step])
	m.set_shader_parameter("density", [0.72, 0.76, 0.8, 0.84, 0.9, 0.94][step])
	m.set_shader_parameter("rate", 2.5 if lite else [6.0, 7.0, 8.0, 9.5, 11.0, 12.0][step])
	m.set_shader_parameter("layers", 1.0 if lite or step < 1 else 2.0)
	m.set_shader_parameter("flicker", 0.2 if lite else 0.55)
	m.set_shader_parameter("core_width", [0.0034, 0.0036, 0.0038, 0.004, 0.0042, 0.0044][step])
	m.set_shader_parameter("glow_width", [0.014, 0.0145, 0.015, 0.0155, 0.016, 0.0165][step])
	MaterialKeeper.keep(m)
	_arc_cache[key] = m
	return m


# --- Arcs ------------------------------------------------------------------------------

static func _add_arcs(item: Node3D, meshes: Array[MeshInstance3D], color: Color, step: int, strands: int, planes: int, lite: bool) -> void:
	var box := _bounds(item, meshes)
	var scale := _world_scale(item)
	var c := box.get_center()
	var radius := maxf(box.size.x, box.size.z) * 0.5
	# Wraps sit on the fist: the hand is the wrap's own centre, the ring its size.
	var wraps := HandWraps.is_look(String(item.name))
	var hand := c if wraps else Vector3.ZERO
	var ring := (maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.62) if wraps else HAND_RING / scale
	# The arcs wander a hand's width either side of the weapon's spine, whatever its head.
	var half_w := clampf(radius * 0.8 + 0.03 / scale, 0.07 / scale, 0.13 / scale)
	var depth := minf(radius, 0.05 / scale)
	var q := func(v: float) -> String: return str(snappedf(v, 0.01))
	var key := "%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [strands, planes, q.call(c.x), q.call(c.z), q.call(box.position.y), q.call(box.end.y),
		q.call(radius), q.call(half_w), q.call(depth), q.call(ring), q.call(hand.length())]
	var mesh: ArrayMesh = _mesh_cache.get(key)
	if mesh == null:
		mesh = _build_mesh(c, box.position.y, box.end.y, minf(radius, 0.04 / scale), half_w, depth, strands, hand, ring, planes)
		_mesh_cache[key] = mesh
	var arcs := MeshInstance3D.new()
	arcs.name = ARC_NAME
	arcs.mesh = mesh
	arcs.material_override = _arc_material(color, step, lite)
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arcs.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	arcs.visibility_range_end = FAR / scale if not lite else FAR * 0.6 / scale
	arcs.set_meta("strands", strands)
	arcs.set_meta("rings", planes)
	item.add_child(arcs)


static func _build_mesh(c: Vector3, y0: float, y1: float, radius: float, half_w: float, depth: float, strands: int, hand: Vector3, ring: float, planes: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var span := maxf(y1 - y0, 0.05)
	for i in strands:
		var a := float(i) * 2.39996
		var off := Vector3(cos(a), 0, sin(a)) * radius * 0.5
		var seed := fposmod(float(i) * 0.618034 + 0.137, 1.0)
		var base := verts.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			verts.append(Vector3(c.x + off.x, y0 + corner.y * span, c.z + off.z))
			uvs.append(corner)
			uv2s.append(Vector2(seed, span))
			cols.append(Color(0, clampf(half_w * 2.0, 0.0, 1.0), clampf(depth * 2.0, 0.0, 1.0), 1))
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var half := ring / 0.68
	var tilts := [Basis(), Basis(Vector3.RIGHT, 0.65), Basis(Vector3.BACK, -0.65)]
	for k in planes:
		var b: Basis = tilts[k % tilts.size()]
		var seed := fposmod(float(k) * 0.381966 + 0.71, 1.0)
		var base := verts.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var local := Vector3((corner.x * 2.0 - 1.0) * half, 0, (corner.y * 2.0 - 1.0) * half)
			verts.append(hand + b * local)
			uvs.append(corner)
			uv2s.append(Vector2(seed, half))
			cols.append(Color(1, 0, 0, 1))
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The vertex stage widens the strands: cull by a box that holds them.
	var box := AABB(Vector3(c.x - radius - half_w, y0, c.z - radius - half_w), Vector3((radius + half_w) * 2.0, span, (radius + half_w) * 2.0))
	if planes > 0:
		box = box.merge(AABB(hand - Vector3.ONE * half, Vector3.ONE * half * 2.0))
	mesh.custom_aabb = box.grow(0.02 + depth)
	return mesh


## The weapon's meshes' box in its own space.
static func _bounds(root: Node3D, meshes: Array[MeshInstance3D]) -> AABB:
	var box := AABB()
	var first := true
	for m in meshes:
		if m.mesh == null or m.name == ARC_NAME:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != root:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 1.0, 0.1))


## Metres per unit of the item's space (1 outside the tree).
static func _world_scale(item: Node3D) -> float:
	if not item.is_inside_tree():
		return 1.0
	var s := item.global_transform.basis.get_scale()
	return maxf((absf(s.x) + absf(s.y) + absf(s.z)) / 3.0, 0.05)
