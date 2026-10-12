class_name OutfitDye
extends RefCounted
## Adds glove / trouser / boot masks to the original skinned chibi body.
## R is copied verbatim from the imported outfit mask; G/B/A are only consumed
## when the outfit shader's part_masks_enabled uniform is set. No geometry,
## skin weights, UVs or materials are replaced, and equipment colour is not
## part of the cache key, so recolouring/re-equipping shares the same mesh.

const MAX_CACHE := 12
static var _cache: Dictionary = {}
static var _order: Array[String] = []
static var _builds := 0


static func masked_mesh(original: Mesh, skin: Skin, skeleton: Skeleton3D) -> Mesh:
	if original == null or skin == null or skeleton == null:
		return original
	if original.get_meta("outfit_dye_masked", false):
		return original
	var bindings := _bindings(skin, skeleton)
	var key := "%d|%d" % [original.get_instance_id(), hash(bindings)]
	if _cache.has(key):
		_order.erase(key)
		_order.append(key)
		return _cache[key]
	var result := _build(original, bindings)
	if result == null:
		return original
	_cache[key] = result
	_order.append(key)
	_builds += 1
	while _order.size() > MAX_CACHE:
		_cache.erase(_order.pop_front())
	return result


static func cache_stats() -> Dictionary:
	return {"entries": _cache.size(), "builds": _builds, "limit": MAX_CACHE}


static func clear_cache() -> void:
	_cache.clear()
	_order.clear()
	_builds = 0


static func _bindings(skin: Skin, skeleton: Skeleton3D) -> Array:
	var out: Array = []
	for bind in skin.get_bind_count():
		var bone := skeleton.find_bone(skin.get_bind_name(bind))
		if bone < 0:
			bone = skin.get_bind_bone(bind)
		if bone < 0 or bone >= skeleton.get_bone_count():
			out.append({"kind": "", "side": "", "head": false, "finger": false,
				"origin": Vector3.ZERO, "endpoint": Vector3.ZERO})
			continue
		var name := String(skeleton.get_bone_name(bone))
		var side := "Left" if name.begins_with("Left") else ("Right" if name.begins_with("Right") else "")
		var kind := name.trim_prefix(side) if side != "" else name
		var head := false
		var ancestor := bone
		while ancestor >= 0:
			if String(skeleton.get_bone_name(ancestor)) in ["Head", "Neck"]:
				head = true
				break
			ancestor = skeleton.get_bone_parent(ancestor)
		var finger := false
		for prefix in ["Thumb", "Index", "Middle", "Ring", "Little"]:
			if kind.begins_with(prefix):
				finger = true
		var origin := skeleton.get_bone_global_rest(bone).origin
		var endpoint := origin
		var target := skeleton.find_bone(side + ("Hand" if kind == "LowerArm" else "Foot"))
		if target >= 0:
			endpoint = skeleton.get_bone_global_rest(target).origin
		out.append({"kind": kind, "side": side, "head": head, "finger": finger,
			"origin": origin, "endpoint": endpoint})
	return out


static func _build(original: Mesh, bindings: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for shape in original.get_blend_shape_count():
		mesh.add_blend_shape(original.get_blend_shape_name(shape))
	if original is ArrayMesh:
		mesh.blend_shape_mode = (original as ArrayMesh).blend_shape_mode
		mesh.custom_aabb = (original as ArrayMesh).custom_aabb
	var any_skin := false
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if vertices.is_empty() or bones.is_empty() or weights.size() != bones.size():
			return null
		var stride := int(bones.size() / vertices.size())
		if stride != 4 and stride != 8:
			return null
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for vertex in vertices.size():
			var red := source_colors[vertex].r if source_colors.size() == vertices.size() else 0.0
			var parts := _vertex_masks(vertices[vertex], vertex * stride, stride, bones, weights, bindings)
			# The old R mask deliberately excludes hands, including leather on
			# fingerless gloves. G uses rig protection independently so that this
			# existing glove texture can be dyed while exposed fingers stay safe.
			colors[vertex] = Color(red, parts.x, parts.y * red, parts.z * red)
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags: int = original.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays,
			original.surface_get_blend_shape_arrays(surface), {}, flags)
		mesh.surface_set_material(surface, original.surface_get_material(surface))
		any_skin = true
	if not any_skin:
		return null
	mesh.set_meta("outfit_dye_masked", true)
	mesh.set_meta("outfit_dye_source", original.get_instance_id())
	return mesh


static func _vertex_masks(vertex: Vector3, start: int, stride: int, bones: PackedInt32Array,
		weights: PackedFloat32Array, bindings: Array) -> Vector3:
	var head := 0.0
	var fingers := 0.0
	var glove := 0.0
	var trouser := 0.0
	var boot := 0.0
	for slot in stride:
		var at := start + slot
		var weight := weights[at]
		var bind := bones[at]
		if weight <= 0.00001 or bind < 0 or bind >= bindings.size():
			continue
		var info: Dictionary = bindings[bind]
		if info.head:
			head += weight
		if info.finger:
			fingers += weight
		match String(info.kind):
			"LowerArm":
				var t := _segment(vertex, info.origin, info.endpoint)
				glove += weight * smoothstep(0.22, 0.52, t)
			"Hand":
				glove += weight
			"Foot", "Toes":
				boot += weight
			"LowerLeg":
				var t := _segment(vertex, info.origin, info.endpoint)
				var cuff := smoothstep(0.23, 0.39, t)
				boot += weight * cuff
				trouser += weight * (1.0 - cuff)
			"UpperLeg":
				# Coat/skirt flaps weighted to a thigh above the pelvis remain
				# torso cloth; only the original trousers use this region.
				trouser += weight * (1.0 - smoothstep(info.origin.y + 0.024, info.origin.y + 0.055, vertex.y))
			"Hips":
				trouser += weight * (1.0 - smoothstep(info.origin.y + 0.018, info.origin.y + 0.050, vertex.y))
	# A protected bone wins even at mixed seams, preventing hair tips, cheeks,
	# lips and finger tips from receiving an equipment tint through interpolation.
	if head >= 0.15:
		return Vector3.ZERO
	glove *= 1.0 - smoothstep(0.06, 0.30, fingers)
	var protect := 1.0 - clampf(head * 6.666667, 0.0, 1.0)
	return Vector3(clampf(glove, 0.0, 1.0), clampf(trouser, 0.0, 1.0), clampf(boot, 0.0, 1.0)) * protect


static func _segment(vertex: Vector3, start: Vector3, finish: Vector3) -> float:
	var axis := finish - start
	return clampf((vertex - start).dot(axis) / maxf(axis.length_squared(), 0.000001), 0.0, 1.0)
