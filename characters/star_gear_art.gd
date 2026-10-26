class_name StarGearArt
extends RefCounted
## Original endgame silhouettes, built once into two vertex-colour surfaces.
## Weapons retain WeaponKit's grip origin and +Y axis. Worn pieces are in
## ChibiGear bone frames; wings use the existing chibi model space.
## No scene processing, particles, lights or shadow casters are added.

const CACHE_LIMIT := 256
static var _cache: Dictionary = {}
static var _solid_material: StandardMaterial3D
static var _glow_material: StandardMaterial3D


static func release_cache() -> void:
	_cache.clear()


static func cloth(class_id: String, stars: int) -> Color:
	return StarGearData.palette(stars, class_id).cloth


static func build(look: String) -> Node3D:
	var kind := StarGearData.kind_from_look(look)
	var stars := StarGearData.stars_from_look(look)
	if kind == "wings":
		return wings(stars, look.split("_")[2] if look.split("_").size()==4 else "warrior")
	var root := Node3D.new()
	root.name = look
	if not _cache.has(look):
		var b := _builder()
		var p := StarGearData.palette(stars)
		var tier := StarGearData.index(stars)
		match kind:
			"sword": _sword(b, p, tier)
			"spear": _spear(b, p, tier)
			"bow": _bow(b, p, tier)
			"staff": _staff(b, p, tier)
			"wand": _wand(b, p, tier)
			"lantern": _lantern(b, p, tier)
			"greatshield": _shield(b, p, tier)
			"dagger": _dagger(b, p, tier)
			"scepter": _scepter(b, p, tier)
			"shield": _shield(b, p, tier)
			"book", "tome": _book(b, p, tier)
		_store(look, b)
	_attach(root, look)
	# The Defender's great shield is the warrior's star shield, grown to its size.
	if kind == "greatshield": root.scale = Vector3.ONE * 1.55
	# The Assassin's star daggers are short blades, one in each hand.
	if kind == "dagger": root.scale = Vector3.ONE * 0.62
	root.set_meta("star_gear", true)
	root.set_meta("weapon_kind", kind)
	return root


## part: chest | pauldron | belt | helm | boots | ring | amulet.
static func armor_piece(part: String, class_id: String, stars: int, side := 1.0) -> Node3D:
	var key := "wear_%s_%s_%d_%d" % [part, class_id, stars, int(side)]
	var root := Node3D.new()
	root.name = "Star_" + part
	if not _cache.has(key):
		var b := _builder()
		var p := StarGearData.palette(stars, class_id)
		var tier := StarGearData.index(stars)
		match part:
			"chest": _chest(b, p, tier, class_id)
			"pauldron": _pauldron(b, p, tier, class_id, side)
			"belt": _belt(b, p, tier, class_id)
			"helm": _helm(b, p, tier, class_id)
			"boots": _boots(b, p, tier, class_id)
			"ring": _ring(b, p, tier, class_id)
			"amulet": _amulet(b, p, tier, class_id)
		_store(key, b)
	_attach(root, key)
	return root


static func build_icon_node(look: String) -> Node3D:
	var kind := StarGearData.kind_from_look(look)
	var stars := StarGearData.stars_from_look(look)
	var bits := look.split("_")
	var cls := String(bits[2]) if bits.size() > 3 else "warrior"
	var root := Node3D.new()
	if kind in ["sword", "spear", "bow", "staff", "wand", "lantern", "shield", "book", "tome", "greatshield", "dagger", "scepter"]:
		root.add_child(build(look))
		root.rotation_degrees.z = -27.0 if kind not in ["bow", "shield", "greatshield"] else -12.0
		return root
	if kind == "wings":
		root.add_child(wings(stars, cls))
		root.rotation_degrees.y = 180.0
		return root
	if kind == "armor":
		root.add_child(armor_piece("chest", cls, stars))
		for side in [-1.0, 1.0]:
			var shoulder := armor_piece("pauldron", cls, stars, side)
			shoulder.position = Vector3(side * 0.135, 0.07, 0)
			root.add_child(shoulder)
		var belt := armor_piece("belt", cls, stars)
		belt.position.y = -0.13
		root.add_child(belt)
	elif kind == "boots":
		var boot_key := "icon_boots_%s_%d" % [cls, stars]
		if not _cache.has(boot_key):
			var b := _builder()
			var p := StarGearData.palette(stars, cls)
			_boots(b, p, StarGearData.index(stars), cls)
			_part(b, MeshKit.box(), p.cloth, Vector3(0, -0.07, 0), Vector3(0.105, 0.16, 0.11))
			_part(b, MeshKit.box(), p.dark, Vector3(0, -0.159, 0.047), Vector3(0.112, 0.031, 0.21))
			_part(b, MeshKit.box(), p.metal, Vector3(0, -0.132, 0.078), Vector3(0.108, 0.038, 0.13))
			_store(boot_key, b)
		_attach(root, boot_key)
		root.rotation_degrees = Vector3(-12, -32, 0)
	else:
		root.add_child(armor_piece(kind, cls, stars))
	root.scale = Vector3.ONE * 5.0
	return root


static func wings(_stars: int, cls := "warrior") -> Node3D:
	return StarWingData.build(cls)

static func _builder() -> Dictionary:
	var solid := SurfaceTool.new()
	var glow := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	return {"solid": solid, "glow": glow, "solid_count": 0, "glow_count": 0}


static func _store(key: String, b: Dictionary) -> void:
	if _solid_material == null:
		_solid_material = StandardMaterial3D.new()
		_solid_material.vertex_color_use_as_albedo = true
		_solid_material.roughness = 0.64
		_solid_material.metallic = 0.18
		_solid_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_solid_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_material = StandardMaterial3D.new()
		_glow_material.vertex_color_use_as_albedo = true
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := ArrayMesh.new()
	for layer in ["solid", "glow"]:
		if b[layer + "_count"] > 0:
			var st: SurfaceTool = b[layer]
			st.index()
			st.set_material(_solid_material if layer == "solid" else _glow_material)
			st.commit(mesh)
	if _cache.size() >= CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
	_cache[key] = mesh


static func _attach(root: Node3D, key: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _cache[key]
	mesh.name = "Art"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("no_outline", true)
	root.add_child(mesh)


static func _part(b: Dictionary, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := false) -> void:
	var basis := Basis.from_euler(rot * PI / 180.0) * Basis.from_scale(size)
	var xform := Transform3D(basis, pos)
	var normals := basis.inverse().transposed()
	var layer := "glow" if glow else "solid"
	var st: SurfaceTool = b[layer]
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normal: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in count:
			var idx := indices[i] if not indices.is_empty() else i
			st.set_color(color)
			st.set_normal((normals * normal[idx]).normalized() if idx < normal.size() else Vector3.UP)
			st.add_vertex(xform * vertices[idx])
		b[layer + "_count"] += count


static func _line(b: Dictionary, p: Array[Vector3], radius: float, color: Color, glow := false) -> void:
	if p.size() < 2:
		return
	_part(b, WeaponKit.tube(p, Vector3.FORWARD, radius, 5), color, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, glow)


static func _ring_at(b: Dictionary, center: Vector3, radius: float, thick: float, color: Color, rot := Vector3(90, 0, 0), glow := false) -> void:
	_part(b, MeshKit.torus(), color, center, Vector3(radius * 2, thick, radius * 2), rot, glow)


## Bevelled 2D silhouette in XY, with a raised centre ridge and back.
static func _shape(b: Dictionary, points: Array[Vector2], center: Vector3, thickness: float, color: Color, glow := false, angle := 0.0) -> void:
	var layer := "glow" if glow else "solid"
	var st: SurfaceTool = b[layer]
	var middle := Vector2.ZERO
	for point in points:
		middle += point
	middle /= float(points.size())
	var basis := Basis(Vector3.BACK, angle)
	for i in points.size():
		var a := Vector3(points[i].x, points[i].y, 0)
		var next: Vector2 = points[(i + 1) % points.size()]
		var c := Vector3(next.x, next.y, 0)
		for face in [-1.0, 1.0]:
			var peak := Vector3(middle.x, middle.y, face * thickness)
			var v := [a, c, peak] if face > 0.0 else [c, a, peak]
			var normal: Vector3 = ((v[1] - v[0]).cross(v[2] - v[0])).normalized()
			# Authored outlines include both winding directions; the front ridge
			# always faces +Z and the rear ridge -Z, including asymmetric crests.
			if normal.z * face < 0.0:
				normal = -normal
			normal = basis * normal
			var shade := color.lightened(0.1) if i % 2 == 0 else color.darkened(0.08)
			for vertex in v:
				st.set_color(shade)
				st.set_normal(normal)
				st.add_vertex(center + basis * vertex)
			b[layer + "_count"] += 3


static func _gem(b: Dictionary, at: Vector3, size: Vector3, p: Dictionary, angle := 0.0) -> void:
	_shape(b, [Vector2(-size.x * 0.5, 0), Vector2(0, size.y * 0.5), Vector2(size.x * 0.5, 0), Vector2(0, -size.y * 0.5)], at, size.z, p.gem, true, angle)


static func _feather(b: Dictionary, at: Vector3, length: float, width: float, angle: float, color: Color, glow := false) -> void:
	_shape(b, [Vector2(0, -length * 0.5), Vector2(-width * 0.52, -length * 0.12), Vector2(-width * 0.34, length * 0.2), Vector2(0, length * 0.5), Vector2(width * 0.34, length * 0.2), Vector2(width * 0.52, -length * 0.12)], at, width * 0.13, color, glow, angle)


static func _shaft(b: Dictionary, p: Dictionary, bottom: float, top: float, width := 0.07) -> void:
	_part(b, MeshKit.cylinder(), p.dark, Vector3(0, (bottom + top) * 0.5, 0), Vector3(width, top - bottom, width))
	for y in [bottom + 0.05, -0.13, 0.13, top - 0.04]:
		_part(b, MeshKit.cylinder(), p.metal, Vector3(0, y, 0), Vector3(width * 1.45, 0.055, width * 1.45))
	for y in [-0.07, 0.0, 0.07]:
		_part(b, MeshKit.cylinder(), p.cloth, Vector3(0, y, 0), Vector3(width * 1.18, 0.04, width * 1.18))


static func _sword(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.22, 0.29, 0.12)
	_gem(b, Vector3(0, -0.25, 0), Vector3(0.16, 0.2, 0.08), p)
	var width := [0.18, 0.15, 0.19, 0.23][t] as float
	var blade: Array[Vector2] = [Vector2(-width, 0.3), Vector2(-width * 0.75, 1.65), Vector2(0, 2.28), Vector2(width * 0.75, 1.65), Vector2(width, 0.3)]
	if t == 1:
		blade = [Vector2(-0.19, 0.34), Vector2(-0.12, 0.68), Vector2(-0.24, 1.1), Vector2(-0.1, 1.3), Vector2(0, 2.34), Vector2(0.1, 1.3), Vector2(0.24, 1.1), Vector2(0.12, 0.68), Vector2(0.19, 0.34)]
	if t == 3:
		blade = [Vector2(-0.25, 0.34), Vector2(-0.2, 0.85), Vector2(-0.3, 1.16), Vector2(-0.13, 1.3), Vector2(-0.14, 1.9), Vector2(0, 2.45), Vector2(0.14, 1.9), Vector2(0.13, 1.3), Vector2(0.3, 1.16), Vector2(0.2, 0.85), Vector2(0.25, 0.34)]
	_shape(b, blade, Vector3.ZERO, 0.07, p.edge)
	_line(b, [Vector3(0, 0.36, 0.081), Vector3(0, 1.77, 0.044), Vector3(0, 2.17, 0.01)], 0.018, p.gem, true)
	for side in [-1.0, 1.0]:
		_feather(b, Vector3(side * 0.24, 0.3, 0), 0.56, 0.15, side * -1.18, p.metal)
		if t >= 2:
			for k in 3:
				_feather(b, Vector3(side * (0.18 + k * 0.07), 0.42 + k * 0.045, -0.025), 0.4 - k * 0.06, 0.09, side * -0.9, p.edge)
	_gem(b, Vector3(0, 0.32, 0.115), Vector3(0.16, 0.22, 0.08), p)
	if t == 3:
		_ring_at(b, Vector3(0, 0.79, 0.01), 0.22, 0.04, p.metal)
		_gem(b, Vector3(0, 1.25, 0.09), Vector3(0.11, 0.19, 0.03), p)


## The Assassin's star dagger (one per hand): a short grip, a guard of swept
## feathers and a blade that grows from a leaf to a crystal, a crescent and a kris.
static func _dagger(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.2, 0.2, 0.1)
	_gem(b, Vector3(0, -0.24, 0), Vector3(0.13, 0.17, 0.07), p)
	var w := [0.15, 0.13, 0.16, 0.17][t] as float
	var blade: Array[Vector2] = [Vector2(-w, 0.24), Vector2(-w * 1.15, 0.55), Vector2(-w * 0.6, 0.95), Vector2(0, 1.25), Vector2(w * 0.6, 0.95), Vector2(w * 1.15, 0.55), Vector2(w, 0.24)]
	if t == 1:
		blade = [Vector2(-w, 0.24), Vector2(-w * 0.7, 0.5), Vector2(-w * 1.2, 0.72), Vector2(-w * 0.5, 0.86), Vector2(0, 1.3), Vector2(w * 0.5, 0.86), Vector2(w * 1.2, 0.72), Vector2(w * 0.7, 0.5), Vector2(w, 0.24)]
	elif t == 2:
		blade = [Vector2(-w, 0.24), Vector2(-w * 0.95, 0.62), Vector2(-w * 0.2, 1.02), Vector2(w * 0.65, 1.34), Vector2(w * 0.85, 1.0), Vector2(w * 1.1, 0.6), Vector2(w, 0.24)]
	elif t == 3:
		blade = [Vector2(-w, 0.24), Vector2(-w * 1.25, 0.45), Vector2(-w * 0.7, 0.62), Vector2(-w * 1.2, 0.8), Vector2(-w * 0.55, 0.98), Vector2(0, 1.38), Vector2(w * 0.55, 0.98), Vector2(w * 1.2, 0.8), Vector2(w * 0.7, 0.62), Vector2(w * 1.25, 0.45), Vector2(w, 0.24)]
	_shape(b, blade, Vector3.ZERO, 0.06, p.edge)
	_line(b, [Vector3(0, 0.3, 0.07), Vector3(w * 0.2 if t == 2 else 0.0, 0.95, 0.04), Vector3(w * 0.5 if t == 2 else 0.0, 1.18, 0.01)], 0.016, p.gem, true)
	for side in [-1.0, 1.0]:
		_feather(b, Vector3(side * 0.2, 0.24, 0), 0.42, 0.13, side * -1.25, p.metal)
		if t >= 1:
			_feather(b, Vector3(side * 0.16, 0.18, -0.02), 0.3, 0.09, side * -2.1, p.dark)
		if t >= 2:
			for k in 2:
				_feather(b, Vector3(side * (0.16 + k * 0.07), 0.32 + k * 0.05, -0.025), 0.32 - k * 0.06, 0.08, side * -0.75, p.edge)
	_gem(b, Vector3(0, 0.25, 0.1), Vector3(0.15, 0.2, 0.07), p)
	if t == 3:
		# The eclipse: a dark ring round the guard with a bright rim.
		_ring_at(b, Vector3(0, 0.25, 0.02), 0.24, 0.04, p.dark)
		_ring_at(b, Vector3(0, 0.25, 0.04), 0.27, 0.014, p.gem, Vector3(90, 0, 0), true)


static func _spear(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.68, 1.2, 0.065)
	_feather(b, Vector3(0, 1.6, 0), 0.9 + t * 0.04, 0.22 + t * 0.015, 0.0, p.edge)
	_line(b, [Vector3(0, 1.24, 0.05), Vector3(0, 1.98, 0.014)], 0.015, p.gem, true)
	for side in [-1.0, 1.0]:
		if t == 1:
			_line(b, [Vector3(side * 0.025, 1.17, 0), Vector3(side * 0.24, 1.36, 0), Vector3(side * 0.24, 1.66, 0)], 0.033, p.metal)
			_feather(b, Vector3(side * 0.24, 1.67, 0), 0.3, 0.095, 0, p.gem, true)
		else:
			for k in (3 if t >= 2 else 1):
				_feather(b, Vector3(side * (0.1 + k * 0.07), 1.17 + k * 0.07, 0), 0.37 - k * 0.035, 0.11, side * -0.72, p.metal if k == 0 else p.edge)
	_gem(b, Vector3(0, 1.18, 0.09), Vector3(0.14, 0.2, 0.05), p)
	if t == 3:
		_ring_at(b, Vector3(0, 1.39, 0), 0.27, 0.033, p.metal)
		for side in [-1.0, 1.0]:
			_feather(b, Vector3(side * 0.28, 1.36, 0), 0.38, 0.085, side * -0.38, p.dark)


static func _bow(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.15, 0.15, 0.09)
	for side in [-1.0, 1.0]:
		var points: Array[Vector3] = [Vector3(0, side * 0.12, 0), Vector3(-0.25, side * 0.38, 0), Vector3(-0.43, side * 0.8, 0), Vector3(-0.2, side * 1.17, 0), Vector3(0.08, side * 1.43, 0)]
		if t == 1:
			points = [Vector3(0, side * 0.12, 0), Vector3(-0.24, side * 0.34, 0), Vector3(-0.5, side * 0.82, 0), Vector3(-0.23, side * 1.0, 0), Vector3(0.08, side * 1.43, 0)]
		_line(b, points, 0.055, p.metal)
		var inner: Array[Vector3] = []
		for point in points:
			inner.append(point + Vector3(0.045, 0, 0.028))
		_line(b, inner, 0.018, p.gem, true)
		for k in 3 + t:
			var y: float = side * (0.44 + k * 0.12)
			_feather(b, Vector3(-0.39 - 0.024 * k, y, -0.018), 0.35 + 0.02 * t, 0.1, side * 0.6, p.edge if t >= 2 else p.cloth)
		_gem(b, Vector3(-0.34, side * 0.67, 0.07), Vector3(0.15, 0.26, 0.05), p)
	_line(b, [Vector3(0.08, -1.43, 0), Vector3(0.17, 0, 0), Vector3(0.08, 1.43, 0)], 0.008, p.edge, true)
	if t >= 2:
		for k in 3:
			_line(b, [Vector3(-0.3 + k * 0.09, -0.65, -0.04), Vector3(-0.3 + k * 0.09, 0.65, -0.04)], 0.009, p.metal)
	if t == 3:
		_ring_at(b, Vector3(-0.42, 0, -0.05), 0.26, 0.035, p.metal)
		_gem(b, Vector3(-0.42, 0, -0.01), Vector3(0.18, 0.3, 0.05), p)


static func _staff(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.85, 1.66, 0.095)
	var top := Vector3(0, 2.05, 0)
	if t == 0:
		for k in 7:
			var a := TAU * k / 7.0
			_feather(b, top + Vector3(sin(a) * 0.26, cos(a) * 0.26, 0), 0.53, 0.19, -a, p.metal)
		_gem(b, top + Vector3(0, 0, 0.04), Vector3(0.4, 0.45, 0.17), p)
	elif t == 1:
		_gem(b, top, Vector3(0.5, 1.05, 0.18), p)
		for side in [-1.0, 1.0]:
			_line(b, [top + Vector3(0, -0.5, 0), top + Vector3(side * 0.4, -0.08, 0), top + Vector3(side * 0.3, 0.39, 0)], 0.052, p.metal)
			_gem(b, top + Vector3(side * 0.4, -0.02, 0), Vector3(0.13, 0.4, 0.08), p)
	else:
		_ring_at(b, top, 0.49, 0.055, p.metal)
		_ring_at(b, top, 0.37, 0.035, p.edge, Vector3(35, 32, 0))
		_ring_at(b, top, 0.35, 0.035, p.metal, Vector3(120, -40, 0))
		_part(b, MeshKit.sphere_low(), p.gem if t == 2 else p.dark, top, Vector3.ONE * 0.34, Vector3.ZERO, t == 2)
		for k in (4 if t == 2 else 8):
			var a := TAU * k / (4.0 if t == 2 else 8.0)
			_gem(b, top + Vector3(sin(a) * 0.57, cos(a) * 0.57, 0), Vector3(0.13, 0.28, 0.05), p, -a)
	_gem(b, Vector3(0, 1.34, 0.055), Vector3(0.12, 0.31, 0.04), p)


static func _wand(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.28, 0.61, 0.078)
	var top := Vector3(0, 0.79, 0)
	if t == 0:
		for k in 5:
			var a := TAU * k / 5.0
			_feather(b, top + Vector3(sin(a) * 0.14, cos(a) * 0.14, 0), 0.29, 0.1, -a, p.edge)
	elif t == 1:
		for a in [0.0, PI * 0.5]:
			_feather(b, top, 0.57, 0.13, a, p.edge)
	elif t == 2:
		for side in [-1.0, 1.0]:
			for k in 3:
				_feather(b, top + Vector3(side * (0.1 + k * 0.055), k * 0.05, 0), 0.35 - k * 0.04, 0.08, side * -0.6, p.edge)
	else:
		_ring_at(b, top, 0.27, 0.032, p.metal)
		for k in 8:
			var a := TAU * k / 8.0
			_feather(b, top + Vector3(sin(a) * 0.3, cos(a) * 0.3, 0), 0.2, 0.075, -a, p.edge)
	_gem(b, top + Vector3(0, 0, 0.06), Vector3(0.18, 0.27, 0.065), p)
	_ring_at(b, top, 0.13, 0.032, p.metal)


## The Dark Lord's star scepter: a royal shaft, an orb in a crown, raven-wing
## feathers sweeping out of the head (more and grander with each star tier).
static func _scepter(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.3, 0.7, 0.082)
	var top := Vector3(0, 0.86, 0)
	_ring_at(b, top + Vector3(0, -0.12, 0), 0.11, 0.03, p.metal, Vector3(90, 0, 0))
	_part(b, MeshKit.sphere_low(), p.gem, top, Vector3.ONE * (0.2 + 0.03 * t), Vector3.ZERO, true)
	# A crown over the orb.
	for k in 5:
		var a := TAU * k / 5.0
		_gem(b, top + Vector3(sin(a) * 0.12, 0.14, cos(a) * 0.12), Vector3(0.05, 0.12, 0.05), p)
	_ring_at(b, top + Vector3(0, 0.1, 0), 0.13, 0.025, p.metal, Vector3(90, 0, 0))
	# Raven-wing feathers on both sides.
	var feathers := 2 + t
	for side in [-1.0, 1.0]:
		for k in feathers:
			_feather(b, top + Vector3(side * (0.13 + k * 0.05), -0.02 + k * 0.035, 0), 0.32 - k * 0.025, 0.07, side * -(0.5 + k * 0.18), p.edge if k % 2 == 0 else p.metal)
	if t >= 2:
		_ring_at(b, top, 0.27, 0.025, p.edge, Vector3(0, 0, 0))
	if t >= 3:
		_ring_at(b, top, 0.3, 0.02, p.metal, Vector3(90, 30, 0))
		_gem(b, top + Vector3(0, 0.34, 0), Vector3(0.07, 0.16, 0.05), p)
	_gem(b, Vector3(0, 0.45, 0.05), Vector3(0.08, 0.16, 0.03), p)


static func _lantern(b: Dictionary, p: Dictionary, t: int) -> void:
	_shaft(b, p, -0.85, 1.12, 0.085)
	_line(b, [Vector3(0, 1.06, 0), Vector3(-0.06, 1.43, 0), Vector3(-0.29, 1.61, 0), Vector3(-0.59, 1.48, 0), Vector3(-0.64, 1.19, 0)], 0.046, p.metal)
	var center := Vector3(-0.6, 0.85, 0)
	_part(b, MeshKit.sphere_low(), p.gem, center, Vector3(0.36, 0.48, 0.36), Vector3.ZERO, true)
	for k in 6:
		var a := TAU * k / 6.0
		var side := Vector3(cos(a), 0, sin(a))
		var path: Array[Vector3] = [center + Vector3(0, -0.35, 0), center + side * 0.23 + Vector3(0, -0.16, 0), center + side * (0.27 if t != 1 else 0.3) + Vector3(0, 0.12, 0), center + Vector3(0, 0.36, 0)]
		_line(b, path, 0.024, p.metal)
		if t == 0 or t == 3:
			_feather(b, center + side * 0.23 + Vector3(0, -0.2, 0), 0.34, 0.12, a * 0.2, p.cloth if t == 0 else p.dark)
		if t == 1:
			_gem(b, center + side * 0.3, Vector3(0.07, 0.42, 0.055), p)
	for y in [-0.3, 0.3]:
		_ring_at(b, center + Vector3(0, y, 0), 0.17, 0.055, p.metal, Vector3.ZERO)
	if t >= 2:
		_part(b, MeshKit.cone(), p.metal, center + Vector3(0, 0.41, 0), Vector3(0.66, 0.23, 0.58))
		_part(b, MeshKit.cone(), p.cloth, center + Vector3(0, 0.49, 0), Vector3(0.4, 0.2, 0.36))
		_ring_at(b, center, 0.35, 0.026, p.edge, Vector3(90, 0, 0), true)
	_line(b, [center + Vector3(0, -0.34, 0), center + Vector3(0, -0.56, 0)], 0.015, p.metal)
	_gem(b, center + Vector3(0, -0.57, 0), Vector3(0.1, 0.2, 0.05), p)


static func _shield(b: Dictionary, p: Dictionary, t: int) -> void:
	var shape: Array[Vector2] = [Vector2(-0.6, 0.57), Vector2(0, 0.77), Vector2(0.6, 0.57), Vector2(0.52, -0.17), Vector2(0, -0.67), Vector2(-0.52, -0.17)]
	if t == 1:
		shape = [Vector2(-0.55, 0.47), Vector2(0, 0.87), Vector2(0.55, 0.47), Vector2(0.69, 0), Vector2(0, -0.8), Vector2(-0.69, 0)]
	if t == 2:
		shape = [Vector2(-0.79, 0.68), Vector2(-0.24, 0.43), Vector2(0, 0.79), Vector2(0.24, 0.43), Vector2(0.79, 0.68), Vector2(0.57, -0.1), Vector2(0, -0.7), Vector2(-0.57, -0.1)]
	if t == 3:
		shape = [Vector2(-0.7, 0.56), Vector2(-0.37, 0.47), Vector2(0, 0.94), Vector2(0.37, 0.47), Vector2(0.7, 0.56), Vector2(0.58, -0.25), Vector2(0, -0.82), Vector2(-0.58, -0.25)]
	_shape(b, shape, Vector3(0, 0.09, 0.14), 0.13, p.metal)
	var inner: Array[Vector2] = []
	for point in shape:
		inner.append(point * 0.84)
	_shape(b, inner, Vector3(0, 0.09, 0.225), 0.12, p.cloth)
	_gem(b, Vector3(0, 0.15, 0.36), Vector3(0.32, 0.46, 0.11), p)
	for side in [-1.0, 1.0]:
		for k in 3:
			_feather(b, Vector3(side * (0.17 + k * 0.09), 0.2 + k * 0.07, 0.3), 0.37, 0.1, side * -0.82, p.edge)
	_part(b, MeshKit.cylinder(), p.dark, Vector3.ZERO, Vector3(0.075, 0.3, 0.075), Vector3(0, 0, 90))


static func _book(b: Dictionary, p: Dictionary, t: int) -> void:
	_part(b, MeshKit.box(), p.cloth, Vector3(0, 0.05, 0.025), Vector3(0.61, 0.77, 0.15))
	_part(b, MeshKit.box(), p.edge, Vector3(0.02, 0.05, 0.01), Vector3(0.54, 0.69, 0.14))
	_part(b, MeshKit.box(), p.dark, Vector3(0, 0.05, 0.1), Vector3(0.61, 0.77, 0.022))
	for side in [-1.0, 1.0]:
		_line(b, [Vector3(side * 0.25, -0.29, 0.13), Vector3(side * 0.25, 0.39, 0.13)], 0.018, p.metal)
	_ring_at(b, Vector3(0, 0.08, 0.13), 0.19, 0.026, p.metal)
	_gem(b, Vector3(0, 0.08, 0.16), Vector3(0.2, 0.31 + t * 0.015, 0.04), p)


static func _chest(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	var heavy := cls in ["warrior", "lancer", "defender"]
	var plate: Array[Vector2] = [Vector2(-0.108, 0.084), Vector2(0, 0.061), Vector2(0.108, 0.084), Vector2(0.086, -0.065), Vector2(0, -0.103), Vector2(-0.086, -0.065)]
	_shape(b, plate, Vector3(0, 0, 0.074), 0.027, p.metal if heavy else p.cloth)
	for side in [-1.0, 1.0]:
		_line(b, [Vector3(side * 0.097, 0.074, 0.097), Vector3(side * 0.073, -0.047, 0.103), Vector3(0, -0.084, 0.1)], 0.004, p.edge)
		_feather(b, Vector3(side * 0.045, 0.043, 0.11), 0.075, 0.022, side * -0.9, p.edge)
	_gem(b, Vector3(0, 0.035, 0.12), Vector3(0.028, 0.044, 0.012), p)
	# The rear cape is split, leaving a clear central wing-root channel.
	for side in [-1.0, 1.0]:
		var length := 0.26 if cls in ["mage", "priest", "summoner"] else 0.2
		_shape(b, [Vector2(-0.047, 0.07), Vector2(0.047, 0.07), Vector2(0.058, -length), Vector2(0, -length + 0.032), Vector2(-0.055, -length)], Vector3(side * 0.062, 0, -0.105), 0.006, p.cloth)
		_line(b, [Vector3(side * 0.1, 0.055, -0.114), Vector3(side * 0.116, -length + 0.02, -0.114)], 0.004, p.metal)
	if cls == "mage":
		_ring_at(b, Vector3(0, 0.029, 0.123), 0.037, 0.005, p.metal)
	elif cls == "priest":
		_part(b, MeshKit.box(), p.edge, Vector3(0, 0.015, 0.133), Vector3(0.012, 0.07, 0.008))
		_part(b, MeshKit.box(), p.edge, Vector3(0, 0.028, 0.133), Vector3(0.045, 0.011, 0.008))
	elif cls == "archer":
		_line(b, [Vector3(-0.09, 0.079, 0.123), Vector3(0.08, -0.059, 0.12)], 0.012, p.dark)
	elif cls == "summoner":
		for side in [-1.0, 1.0]:
			_ring_at(b, Vector3(side * 0.053, 0.02, 0.124), 0.023, 0.004, p.metal)
	elif cls == "assassin":
		# Two daggers crossed on the breast under a crescent.
		for side in [-1.0, 1.0]:
			_line(b, [Vector3(side * -0.045, 0.07, 0.122), Vector3(side * 0.035, -0.035, 0.122)], 0.006, p.edge)
			_line(b, [Vector3(side * 0.025, -0.012, 0.124), Vector3(side * 0.045, -0.032, 0.124)], 0.005, p.metal)
		_ring_at(b, Vector3(0, 0.075, 0.12), 0.022, 0.004, p.gem, Vector3(90, 0, 0), true)
	elif cls == "darklord":
		# A gold raven with spread wings under a small crown.
		for side in [-1.0, 1.0]:
			_feather(b, Vector3(side * 0.035, 0.035, 0.124), 0.07, 0.022, side * -1.1, p.edge)
		_part(b, MeshKit.sphere_low(), p.edge, Vector3(0, 0.03, 0.126), Vector3(0.022, 0.04, 0.01))
		_ring_at(b, Vector3(0, 0.08, 0.12), 0.018, 0.004, p.gem, Vector3(90, 0, 0), true)
	elif cls == "defender":
		# A small heater shield on the breastplate.
		_shape(b, [Vector2(-0.04, 0.04), Vector2(0.04, 0.04), Vector2(0.036, -0.01), Vector2(0, -0.05), Vector2(-0.036, -0.01)], Vector3(0, 0.03, 0.118), 0.008, p.edge)
	if t >= 2:
		for side in [-1.0, 1.0]:
			_feather(b, Vector3(side * 0.078, 0.084, 0.041), 0.1, 0.028, side * -0.65, p.edge)
	if t == 3:
		_ring_at(b, Vector3(0, 0.025, 0.12), 0.058, 0.004, p.gem, Vector3(90, 0, 0), true)


static func _pauldron(b: Dictionary, p: Dictionary, t: int, cls: String, side: float) -> void:
	var heavy := cls in ["warrior", "lancer", "defender"]
	var size := Vector3(0.138, 0.085, 0.127) if heavy else Vector3(0.111, 0.06, 0.108)
	_part(b, MeshKit.hemisphere(), p.metal if heavy else p.cloth, Vector3(side * 0.01, 0.01, 0), size, Vector3(0, 0, side * -15))
	for k in 2 + t:
		var length := 0.076 + k * 0.012
		_feather(b, Vector3(side * (0.035 + k * 0.008), 0.024 + k * 0.01, 0.007 - k * 0.012), length, 0.032, side * -0.8, p.edge if t >= 2 else p.metal)
	_gem(b, Vector3(side * 0.018, 0.047, 0.055), Vector3(0.023, 0.033, 0.009), p)
	if cls == "lancer":
		_feather(b, Vector3(side * 0.072, 0.055, 0), 0.11, 0.028, side * -0.55, p.metal)
	if cls == "summoner":
		_ring_at(b, Vector3(side * 0.064, -0.01, 0.01), 0.03, 0.005, p.metal)
	if cls == "defender":
		# A second, broader plate over the shoulder.
		_part(b, MeshKit.hemisphere(), p.metal.darkened(0.12), Vector3(side * 0.03, -0.012, 0), Vector3(0.16, 0.07, 0.14), Vector3(0, 0, side * -28))


static func _belt(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	_ring_at(b, Vector3(0, 0.09, -0.005), 0.145, 0.035, p.dark, Vector3.ZERO)
	_gem(b, Vector3(0, 0.087, 0.136), Vector3(0.042, 0.044, 0.01), p)
	for side in [-1.0, 1.0]:
		var length := 0.15 if cls in ["mage", "priest", "summoner"] else 0.09
		_feather(b, Vector3(side * 0.09, 0.01, 0.106), length + t * 0.01, 0.075, side * -0.12, p.metal if cls in ["warrior", "lancer", "defender"] else p.cloth)
		_line(b, [Vector3(side * 0.115, 0.065, 0.115), Vector3(side * 0.117, -length * 0.35, 0.115)], 0.0035, p.edge)


static func _helm(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	_ring_at(b, Vector3(0, 0.205, 0.01), 0.199, 0.025, p.metal, Vector3(-8, 0, 0))
	_gem(b, Vector3(0, 0.225, 0.207), Vector3(0.042, 0.064, 0.015), p)
	if cls == "mage":
		_part(b, MeshKit.cone(), p.cloth, Vector3(0, 0.335, -0.035), Vector3(0.25, 0.26 + t * 0.015, 0.22), Vector3(-8, 0, -8))
		_ring_at(b, Vector3(0, 0.228, -0.03), 0.145, 0.012, p.edge, Vector3.ZERO)
	elif cls == "archer":
		for k in 3 + t:
			_feather(b, Vector3(-0.18 - k * 0.009, 0.22 + k * 0.02, 0), 0.16, 0.034, 0.45 + k * 0.08, p.edge if k % 2 else p.cloth)
	elif cls == "summoner":
		for side in [-1.0, 1.0]:
			_feather(b, Vector3(side * 0.18, 0.27, -0.055), 0.2, 0.062, side * -0.37, p.dark)
			_ring_at(b, Vector3(side * 0.192, 0.204, 0.074), 0.035, 0.007, p.metal)
	else:
		for side in [-1.0, 1.0]:
			for k in 2 + t:
				_feather(b, Vector3(side * (0.178 + k * 0.011), 0.235 + k * 0.022, -0.027), 0.095 + k * 0.012, 0.026, side * (-0.72 + k * 0.11), p.edge)
		if cls == "warrior":
			for k in 3:
				_feather(b, Vector3((k - 1) * 0.048, 0.26, 0.18), 0.09 + (0.035 if k == 1 else 0.0), 0.029, 0, p.metal)
		elif cls == "lancer":
			for side in [-1.0, 1.0]:
				_line(b, [Vector3(side * 0.14, 0.24, -0.095), Vector3(side * 0.21, 0.33, -0.1), Vector3(side * 0.17, 0.4, -0.12)], 0.013, p.metal)
				_feather(b, Vector3(side * 0.164, 0.423, -0.12), 0.075, 0.019, side * 0.25, p.edge)
		elif cls == "priest":
			_part(b, MeshKit.box(), p.edge, Vector3(0, 0.267, 0.198), Vector3(0.013, 0.093, 0.013))
			_part(b, MeshKit.box(), p.edge, Vector3(0, 0.281, 0.198), Vector3(0.055, 0.013, 0.013))
		elif cls == "darklord":
			# A royal circlet with a raven crest and two swept wings.
			for k in 5:
				_gem(b, Vector3((k - 2) * 0.04, 0.26 + (0.02 if k == 2 else 0.0), 0.17), Vector3(0.018, 0.045, 0.01), p)
			for side in [-1.0, 1.0]:
				_feather(b, Vector3(side * 0.13, 0.25, 0.1), 0.11, 0.03, side * -0.9, p.metal)
		elif cls == "assassin":
			# A half mask over the brow with a crescent at its peak.
			_shape(b, [Vector2(-0.11, 0.0), Vector2(-0.05, 0.03), Vector2(0, 0.012), Vector2(0.05, 0.03), Vector2(0.11, 0.0), Vector2(0.06, -0.025), Vector2(-0.06, -0.025)], Vector3(0, 0.215, 0.2), 0.01, p.dark)
			_feather(b, Vector3(0, 0.27, 0.19), 0.07, 0.03, 0, p.edge)
	if t == 1:
		for side in [-1.0, 1.0]:
			_gem(b, Vector3(side * 0.115, 0.236, 0.169), Vector3(0.027, 0.071, 0.012), p, side * -0.32)
	if t >= 2:
		_ring_at(b, Vector3(0, 0.43 + (0.06 if cls == "mage" else 0.0), -0.025), 0.11 if t == 2 else 0.145, 0.009, p.metal, Vector3(-15, 0, 0))
	if t == 3:
		for side in [-1.0, 1.0]:
			_gem(b, Vector3(side * 0.145, 0.435, -0.025), Vector3(0.021, 0.049, 0.009), p)


static func _boots(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	_ring_at(b, Vector3(0, -0.025, 0), 0.065, 0.031, p.cloth, Vector3.ZERO)
	_shape(b, [Vector2(-0.043, 0.008), Vector2(0.043, 0.008), Vector2(0.031, -0.09), Vector2(0, -0.12), Vector2(-0.031, -0.09)], Vector3(0, 0, 0.061), 0.014, p.metal)
	_gem(b, Vector3(0, -0.015, 0.08), Vector3(0.021, 0.035, 0.007), p)
	for side in [-1.0, 1.0]:
		for k in (2 if cls in ["archer", "lancer"] or t >= 2 else 1):
			_feather(b, Vector3(side * 0.06, -0.035 + k * 0.014, -0.015), 0.064, 0.02, side * -0.95, p.edge)


static func _ring(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	_ring_at(b, Vector3.ZERO, 0.024, 0.015, p.metal, Vector3(0, 0, 90))
	_gem(b, Vector3(0, 0, 0.027), Vector3(0.026, 0.031, 0.009), p)
	_class_badge(b, Vector3(0, 0, 0.028), 0.027, cls, p)
	if t >= 2:
		for side in [-1.0, 1.0]:
			_feather(b, Vector3(0, side * 0.018, 0.023), 0.025, 0.009, side * -0.65, p.edge)


static func _amulet(b: Dictionary, p: Dictionary, t: int, cls: String) -> void:
	_line(b, [Vector3(-0.075, 0.09, 0.053), Vector3(-0.04, 0.019, 0.103), Vector3(0, -0.016, 0.116), Vector3(0.04, 0.019, 0.103), Vector3(0.075, 0.09, 0.053)], 0.0038, p.metal)
	var center := Vector3(0, -0.018, 0.123)
	_ring_at(b, center, 0.028, 0.005, p.metal)
	_gem(b, center + Vector3(0, 0, 0.007), Vector3(0.03, 0.048, 0.009), p)
	_class_badge(b, center + Vector3(0, 0, 0.005), 0.038, cls, p)
	if t >= 2 or cls == "priest":
		for side in [-1.0, 1.0]:
			_feather(b, center + Vector3(side * 0.028, 0.003, 0), 0.037, 0.013, side * -0.9, p.edge)


static func _class_badge(b: Dictionary, center: Vector3, s: float, cls: String, p: Dictionary) -> void:
	match cls:
		"warrior":
			_shape(b, [Vector2(-s, -s * 0.4), Vector2(-s, s * 0.7), Vector2(-s * 0.4, s * 0.2), Vector2(0, s), Vector2(s * 0.4, s * 0.2), Vector2(s, s * 0.7), Vector2(s, -s * 0.4)], center, s * 0.12, p.metal)
		"archer":
			_feather(b, center + Vector3(-s * 0.7, 0, 0), s * 2.2, s * 0.45, 0.58, p.edge)
			_feather(b, center + Vector3(s * 0.7, 0, 0), s * 2.2, s * 0.45, -0.58, p.edge)
		"lancer":
			_feather(b, center, s * 3.4, s * 0.6, 0, p.edge)
			_line(b, [center + Vector3(-s, -s * 0.35, 0), center + Vector3(s, -s * 0.35, 0)], s * 0.1, p.metal)
		"mage":
			for k in 6:
				var a := TAU * k / 6.0
				_feather(b, center + Vector3(sin(a) * s, cos(a) * s, 0), s * 0.9, s * 0.36, -a, p.metal)
		"priest":
			_part(b, MeshKit.box(), p.edge, center, Vector3(s * 0.33, s * 2.6, s * 0.18))
			_part(b, MeshKit.box(), p.edge, center + Vector3(0, s * 0.35, 0), Vector3(s * 1.8, s * 0.33, s * 0.18))
		"summoner":
			for side in [-1.0, 1.0]:
				_feather(b, center + Vector3(side * s * 0.78, s * 0.35, 0), s * 1.5, s * 0.86, side * -0.5, p.cloth)
				_feather(b, center + Vector3(side * s * 0.65, -s * 0.65, 0), s * 1.2, s * 0.68, side * 0.5, p.metal)
		"darklord":
			# A raven with spread wings.
			for side in [-1.0, 1.0]:
				_feather(b, center + Vector3(side * s * 0.5, s * 0.2, 0), s * 1.8, s * 0.5, side * -1.0, p.edge)
			_part(b, MeshKit.sphere_low(), p.gem, center, Vector3(s * 0.6, s * 0.9, s * 0.4), Vector3.ZERO, true)
		"assassin":
			# Two daggers crossed point-up.
			for side in [-1.0, 1.0]:
				_feather(b, center + Vector3(side * s * 0.3, s * 0.1, 0), s * 2.4, s * 0.42, side * 0.62, p.edge)
