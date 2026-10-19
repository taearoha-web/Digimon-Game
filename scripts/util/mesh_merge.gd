class_name MeshMerge
extends RefCounted
## Folds the many small static meshes of one model (a weapon of 40 pieces, a
## shoulder guard of 6 primitives) into a single mesh with one surface per
## material. Every surface is a draw call (two with an outline, three with the
## sun's shadow), so this is what keeps a crowd of heroes cheap on a phone.
##
## Only plain pieces are folded: childless, unskinned, visible MeshInstance3Ds
## made of triangles. Pieces whose instance settings differ (overlay, override,
## shadow casting) go into separate merged meshes.

static var _cache := {}
const CACHE_LIMIT := 64


static func release_cache() -> void:
	_cache.clear()


## Merges the pieces under [param root] in place. With a [param cache_key] the
## built meshes are kept, so the next copy of the same model reuses them.
## Returns how many mesh nodes were removed.
static func merge(root: Node3D, cache_key := "") -> int:
	var pieces: Array[MeshInstance3D] = []
	_collect(root, root, pieces)
	if pieces.size() < 2:
		return 0
	# Group by the instance settings that must stay the same for every piece.
	var groups := {}
	var order: Array = []
	for mi in pieces:
		# A mirrored piece would turn inside out once its winding is baked.
		if _relative(mi, root).basis.determinant() <= 0.0:
			continue
		var key := _instance_key(mi)
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		(groups[key] as Array).append(mi)
	# "auto": the key is the pieces themselves (meshes, materials, placement), so
	# every fighter wearing the same look shares one merged mesh instead of
	# baking its own copy (a guild war held sixteen copies of each piece).
	if cache_key == "auto":
		cache_key = _pieces_key(root, order, groups)
	var cached: Array = _cache.get(cache_key, []) if cache_key != "" else []
	var built: Array = []
	var removed := 0
	for g in order.size():
		var members: Array = groups[order[g]]
		if members.size() < 2 and _surface_count(members) < 2:
			built.append(null)
			continue
		var mesh: ArrayMesh = cached[g] if g < cached.size() and cached[g] != null else _build(root, members)
		built.append(mesh)
		if mesh == null:
			continue
		var first := members[0] as MeshInstance3D
		var merged := MeshInstance3D.new()
		merged.name = "Merged%d" % g
		merged.mesh = mesh
		merged.material_overlay = first.material_overlay
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		merged.visibility_range_end = first.visibility_range_end
		for key in first.get_meta_list():
			merged.set_meta(key, first.get_meta(key))
		root.add_child(merged)
		for mi in members:
			(mi as Node).get_parent().remove_child(mi)
			(mi as Node).queue_free()
			removed += 1
	if cache_key != "" and cached.is_empty():
		if _cache.size() >= CACHE_LIMIT:
			_cache.erase(_cache.keys()[0])
		_cache[cache_key] = built
	return removed


static func _pieces_key(root: Node3D, order: Array, groups: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in order:
		var members: Array = groups[key]
		var ids: PackedStringArray = []
		for mi in members:
			var piece := mi as MeshInstance3D
			var t := _relative(piece, root)
			var mats: PackedStringArray = []
			for i in piece.mesh.get_surface_count():
				var m := piece.get_active_material(i)
				mats.append(str(m.get_instance_id()) if m else "0")
			var fine := Vector3.ONE * 0.001
			ids.append("%d:%s:%s:%s,%s,%s" % [piece.mesh.get_instance_id(), ",".join(mats), str(t.origin.snapped(fine)),
				str(t.basis.x.snapped(fine)), str(t.basis.y.snapped(fine)), str(t.basis.z.snapped(fine))])
		parts.append("%d|%s" % [members.size(), "|".join(ids)])
	return "auto:%d" % hash(";".join(parts))


static func _collect(node: Node, root: Node3D, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and _mergeable(child as MeshInstance3D):
			out.append(child as MeshInstance3D)
		elif child is Node3D and not (child is Skeleton3D) and (child as Node3D).visible and child.get_script() == null:
			_collect(child, root, out)


static func _mergeable(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.skin != null or not mi.visible or mi.get_child_count() > 0 or mi.get_script() != null:
		return false
	if mi.name == "BlobShadow" or mi.has_meta("no_merge"):
		return false
	if mi.mesh is PrimitiveMesh:
		return true
	if not mi.mesh is ArrayMesh:
		return false
	for i in mi.mesh.get_surface_count():
		if (mi.mesh as ArrayMesh).surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			return false
	return true


static func _instance_key(mi: MeshInstance3D) -> String:
	return "%d|%d|%d|%d|%.2f|%s" % [
		mi.material_overlay.get_instance_id() if mi.material_overlay else 0,
		mi.cast_shadow, mi.layers, int(mi.has_meta("no_outline")), mi.visibility_range_end,
		str(mi.get_meta("face_detail", false))]


static func _surface_count(members: Array) -> int:
	var n := 0
	for mi in members:
		n += (mi as MeshInstance3D).mesh.get_surface_count()
	return n


## Material each piece surface is drawn with (the instance override wins).
static func _material(mi: MeshInstance3D, surface: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var m := mi.get_surface_override_material(surface)
	return m if m else mi.mesh.surface_get_material(surface)


## One surface moved by [param xform]. Normals use the inverse transpose, so
## squashed spheres and stretched boxes keep their shading.
static func _baked(mesh: Mesh, surface: int, xform: Transform3D) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(surface)
	arrays[Mesh.ARRAY_VERTEX] = xform * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var normal_basis := xform.basis.inverse().transposed()
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		for i in normals.size():
			normals[i] = (normal_basis * normals[i]).normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var tangents := arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array
		for i in range(0, tangents.size(), 4):
			var t := (xform.basis * Vector3(tangents[i], tangents[i + 1], tangents[i + 2])).normalized()
			tangents[i] = t.x
			tangents[i + 1] = t.y
			tangents[i + 2] = t.z
		arrays[Mesh.ARRAY_TANGENT] = tangents
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _build(root: Node3D, members: Array) -> ArrayMesh:
	var by_material := {}
	var materials: Array[Material] = []
	for mi in members:
		var m := mi as MeshInstance3D
		var xform := _relative(m, root)
		for s in m.mesh.get_surface_count():
			var mat := _material(m, s)
			var id := mat.get_instance_id() if mat else 0
			if not by_material.has(id):
				by_material[id] = []
				materials.append(mat)
			(by_material[id] as Array).append([m.mesh, s, xform])
	var out := ArrayMesh.new()
	for mat in materials:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for entry in by_material[mat.get_instance_id() if mat else 0]:
			st.append_from(_baked(entry[0], entry[1], entry[2]), 0, Transform3D.IDENTITY)
		st.set_material(mat)
		st.commit(out)
	return out if out.get_surface_count() > 0 else null
