class_name JapanKit
extends RefCounted
## Japanese village pieces built from primitives: houses, shops with noren
## curtains, a storehouse, a dojo, a shrine with torii gates, a pagoda, stone
## and paper lanterns, an arched bridge, fences and banners.
##
## Every piece is written into a [JapanKit.Batch]: all its boxes, cylinders and
## roofs become ONE mesh with vertex colours (plus one unshaded surface for the
## glowing lantern paper), so a whole building costs a single draw call.

const WOOD := Color("6b4430")
const WOOD_DARK := Color("3f2a20")
const WOOD_LIGHT := Color("b88a5c")
const PLASTER := Color("f1ebdd")
const TILE := Color("4b5566")
const TILE_DARK := Color("363e4c")
const STONE := Color("a7a59c")
const STONE_DARK := Color("7f7d76")
const VERMILION := Color("d8452e")
const SHOJI := Color("f8f1dc")
const THATCH := Color("b08e58")
const COPPER := Color("4a8f7c")
const GOLD := Color("e8c050")


## Collects primitives (in the batch's local space) into one mesh.
class Batch:
	var _verts := PackedVector3Array()
	var _normals := PackedVector3Array()
	var _colors := PackedColorArray()
	var _indices := PackedInt32Array()
	var _glow_verts := PackedVector3Array()
	var _glow_normals := PackedVector3Array()
	var _glow_colors := PackedColorArray()
	var _glow_indices := PackedInt32Array()
	var _cloth_verts := PackedVector3Array()
	var _cloth_normals := PackedVector3Array()
	var _cloth_colors := PackedColorArray()
	var _cloth_indices := PackedInt32Array()
	## Applied to everything added (a building's position and turn).
	var xform := Transform3D.IDENTITY
	## Lantern flames added so far: [world position, colour], for the halo layer.
	var lights: Array = []

	## `weight`, when given, sends the primitive to the cloth surface: it maps a
	## vertex (in the piece's local space) to how freely it sways, 0..1.
	func add(mesh_arrays: Array, local: Transform3D, color: Color, glow := false, weight := Callable()) -> void:
		var t := xform * local
		var unit: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
		var verts: PackedVector3Array = t * unit
		var nb := Transform3D(t.basis.inverse().transposed(), Vector3.ZERO)
		var normals: PackedVector3Array = nb * (mesh_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		var src_idx: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
		var flip := t.basis.determinant() < 0.0
		var cloth := weight.is_valid()
		var dv := _cloth_verts if cloth else (_glow_verts if glow else _verts)
		var base := dv.size()
		var idx := PackedInt32Array()
		idx.resize(src_idx.size())
		for i in range(0, src_idx.size(), 3):
			idx[i] = src_idx[i] + base
			idx[i + 1] = src_idx[i + (2 if flip else 1)] + base
			idx[i + 2] = src_idx[i + (1 if flip else 2)] + base
		var cols := PackedColorArray()
		cols.resize(verts.size())
		cols.fill(color)
		if cloth:
			for i in verts.size():
				cols[i].a = clampf(float(weight.call(local * unit[i])), 0.0, 1.0)
			_cloth_verts.append_array(verts)
			_cloth_normals.append_array(normals)
			_cloth_colors.append_array(cols)
			_cloth_indices.append_array(idx)
		elif glow:
			_glow_verts.append_array(verts)
			_glow_normals.append_array(normals)
			_glow_colors.append_array(cols)
			_glow_indices.append_array(idx)
		else:
			_verts.append_array(verts)
			_normals.append_array(normals)
			_colors.append_array(cols)
			_indices.append_array(idx)

	func box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, glow := false) -> void:
		add(JapanKit.arrays("box"), JapanKit.place(pos, size, rot), color, glow)

	func cyl(pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO, sides := 8) -> void:
		add(JapanKit.arrays("cyl%d" % sides), JapanKit.place(pos, Vector3(radius * 2.0, height, radius * 2.0), rot), color)

	func cone(pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO) -> void:
		add(JapanKit.arrays("cone"), JapanKit.place(pos, Vector3(radius * 2.0, height, radius * 2.0), rot), color)

	func ball(pos: Vector3, size: Vector3, color: Color, glow := false) -> void:
		add(JapanKit.arrays("ball"), JapanKit.place(pos, size, Vector3.ZERO), color, glow)

	## A swaying cloth panel (banner, noren strip, awning); see [method add].
	func cloth(pos: Vector3, size: Vector3, color: Color, weight: Callable, rot := Vector3.ZERO) -> void:
		add(JapanKit.arrays("box"), JapanKit.place(pos, size, rot), color, false, weight)

	## Remembers a lantern flame for the village's halo layer.
	func light(pos: Vector3, color: Color) -> void:
		lights.append([xform * pos, color])

	## A hipped roof: a four-sided frustum over [param w] x [param d] (its ridge
	## length set by [param ridge], 0..1 of the width), turned by [param yaw].
	func roof(pos: Vector3, w: float, d: float, h: float, color: Color, ridge := 0.35, yaw := 0.0) -> void:
		var key := "roof%d" % int(ridge * 100.0)
		add(JapanKit.arrays(key), JapanKit.place(pos, Vector3(w, h, d), Vector3(0, yaw, 0)), color)

	func is_empty() -> bool:
		return _verts.is_empty() and _glow_verts.is_empty() and _cloth_verts.is_empty()

	## Adds the mesh to [param parent] (cast shadows unless [param shadows] is false).
	func commit(parent: Node3D, node_name: String, shadows := true) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 95.0 * GameSettings.view_scale()
		parent.add_child(mi)
		return mi

	## The batch as one ArrayMesh (solid, glow and cloth surfaces), e.g. for a MultiMesh.
	func mesh() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		if not _verts.is_empty():
			var a := []
			a.resize(Mesh.ARRAY_MAX)
			a[Mesh.ARRAY_VERTEX] = _verts
			a[Mesh.ARRAY_NORMAL] = _normals
			a[Mesh.ARRAY_COLOR] = _colors
			a[Mesh.ARRAY_INDEX] = _indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
			mesh.surface_set_material(mesh.get_surface_count() - 1, JapanKit.solid_material())
		if not _glow_verts.is_empty():
			var g := []
			g.resize(Mesh.ARRAY_MAX)
			g[Mesh.ARRAY_VERTEX] = _glow_verts
			g[Mesh.ARRAY_NORMAL] = _glow_normals
			g[Mesh.ARRAY_COLOR] = _glow_colors
			g[Mesh.ARRAY_INDEX] = _glow_indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g)
			mesh.surface_set_material(mesh.get_surface_count() - 1, JapanKit.glow_material())
		if not _cloth_verts.is_empty():
			var c := []
			c.resize(Mesh.ARRAY_MAX)
			c[Mesh.ARRAY_VERTEX] = _cloth_verts
			c[Mesh.ARRAY_NORMAL] = _cloth_normals
			c[Mesh.ARRAY_COLOR] = _cloth_colors
			c[Mesh.ARRAY_INDEX] = _cloth_indices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, c)
			mesh.surface_set_material(mesh.get_surface_count() - 1, JapanKit.cloth_material())
		return mesh


static var _arrays: Dictionary = {}
static var _solid: StandardMaterial3D
static var _glow: StandardMaterial3D
static var _cloth: ShaderMaterial


static func arrays(key: String) -> Array:
	if _arrays.has(key):
		return _arrays[key]
	var mesh: PrimitiveMesh
	if key == "box":
		mesh = BoxMesh.new()
	elif key.begins_with("cyl"):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = int(key.trim_prefix("cyl"))
		c.rings = 1
		mesh = c
	elif key == "cone":
		var k := CylinderMesh.new()
		k.top_radius = 0.0
		k.bottom_radius = 0.5
		k.height = 1.0
		k.radial_segments = 8
		k.rings = 1
		mesh = k
	elif key == "ball":
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		mesh = s
	elif key.begins_with("roof"):
		_arrays[key] = _roof_arrays(float(key.trim_prefix("roof")) / 100.0)
		return _arrays[key]
	var out := mesh.get_mesh_arrays()
	_arrays[key] = out
	return out


## A unit hipped roof (base 1 x 1 at y = -0.5, ridge along x at y = 0.5).
static func _roof_arrays(ridge: float) -> Array:
	var r := ridge * 0.5
	var p := [Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, -0.5, 0.5),
		Vector3(-r, 0.5, 0.0), Vector3(r, 0.5, 0.0)]
	var faces := [[3, 2, 5, 4], [1, 0, 4, 5], [0, 3, 4], [2, 1, 5], [0, 1, 2, 3]]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for f in faces:
		var a: Vector3 = p[f[0]]
		var b: Vector3 = p[f[1]]
		var c: Vector3 = p[f[2]]
		var n := (b - a).cross(c - a).normalized()
		var centroid := Vector3.ZERO
		for k in f:
			centroid += p[k]
		centroid /= float(f.size())
		var order: Array = f.duplicate()
		if n.dot(centroid) < 0.0:
			order.reverse()
			n = -n
		var base := verts.size()
		for k in order:
			verts.append(p[k])
			normals.append(n)
		for k in range(1, order.size() - 1):
			idx.append_array([base, base + k + 1, base + k])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_INDEX] = idx
	return out


static func place(pos: Vector3, size: Vector3, rot_deg: Vector3) -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(basis * Basis.from_scale(size), pos)


static func solid_material() -> StandardMaterial3D:
	if _solid == null:
		_solid = StandardMaterial3D.new()
		_solid.vertex_color_use_as_albedo = true
		_solid.vertex_color_is_srgb = true
		_solid.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_solid.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_solid.roughness = 1.0
		_solid.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _solid


static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.vertex_color_use_as_albedo = true
		_glow.vertex_color_is_srgb = true
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _glow


## Vertex-coloured cloth that sways in the wind (COLOR.a = freedom to move).
static func cloth_material() -> ShaderMaterial:
	if _cloth == null:
		_cloth = ShaderMaterial.new()
		_cloth.shader = load("res://shaders/cloth_sway.gdshader")
	return _cloth


## Banner fabric: pinned along the pole (x = pole_x) and loosest at the bottom
## free corner. `top` is the rod height, `w` / `h` the cloth size.
static func banner_weight(pole_x: float, top: float, w: float, h: float) -> Callable:
	return func(v: Vector3) -> float:
		return clampf((v.x - pole_x) / w, 0.0, 1.0) * clampf(0.35 + (top - v.y) / h * 0.65, 0.0, 1.0)


## Hanging cloth (noren, awning fringe): pinned at `top`, free `h` below it.
static func hanging_weight(top: float, h: float) -> Callable:
	return func(v: Vector3) -> float:
		return pow(clampf((top - v.y) / h, 0.0, 1.0), 1.2)


## A solid box collider at [param center] (local to [param parent]).
static func collider(parent: Node3D, center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	body.rotation.y = yaw
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


# ---------------------------------------------------------------------------
# Pieces. Each writes into [param b] around its local origin (front = +z).
# ---------------------------------------------------------------------------

## Stone base, timber frame, plaster walls with shoji windows, an engawa porch
## and a tiled hip roof. [param floors] 2 adds a smaller upper storey.
static func house(b: Batch, w: float, d: float, wall: float, roof_color := TILE, floors := 1, plaster := PLASTER) -> void:
	b.box(Vector3(0, 0.2, 0), Vector3(w + 0.4, 0.4, d + 0.4), STONE)
	b.box(Vector3(0, 0.4 + wall * 0.5, 0), Vector3(w, wall, d), plaster)
	# Lower wooden skirt and posts.
	b.box(Vector3(0, 0.4 + wall * 0.18, 0), Vector3(w + 0.04, wall * 0.36, d + 0.04), WOOD)
	for x in [-0.5, -0.17, 0.17, 0.5]:
		for z in [-0.5, 0.5]:
			b.box(Vector3(x * w, 0.4 + wall * 0.5, z * d), Vector3(0.22, wall, 0.22), WOOD_DARK)
	b.box(Vector3(0, 0.4 + wall - 0.12, 0), Vector3(w + 0.1, 0.22, d + 0.1), WOOD_DARK)
	# Shoji windows on the long sides.
	for side in [-1.0, 1.0]:
		for x in [-0.33, 0.33]:
			_shoji(b, Vector3(x * w, 0.4 + wall * 0.62, side * (d * 0.5 + 0.03)), Vector3(w * 0.22, wall * 0.36, 0.05))
	# Porch (engawa) along the front.
	b.box(Vector3(0, 0.55, d * 0.5 + 0.55), Vector3(w * 0.9, 0.12, 1.0), WOOD_LIGHT)
	for x in [-0.45, 0.0, 0.45]:
		b.box(Vector3(x * w, 0.27, d * 0.5 + 0.95), Vector3(0.16, 0.55, 0.16), WOOD_DARK)
	var top := 0.4 + wall
	if floors >= 2:
		b.roof(Vector3(0, top + 0.45, 0), w + 1.6, d + 1.6, 0.9, roof_color, 0.86)
		b.box(Vector3(0, top + 0.9 + wall * 0.32, 0), Vector3(w * 0.72, wall * 0.64, d * 0.72), plaster)
		b.box(Vector3(0, top + 0.9 + 0.1, 0), Vector3(w * 0.74, 0.2, d * 0.74), WOOD_DARK)
		_shoji(b, Vector3(0, top + 0.9 + wall * 0.34, d * 0.36 + 0.03), Vector3(w * 0.4, wall * 0.3, 0.05))
		top += 0.9 + wall * 0.64
	b.roof(Vector3(0, top + 0.85, 0), w + 1.8, d + 1.8, 1.7, roof_color, 0.45)
	b.box(Vector3(0, top + 1.72, 0), Vector3(w * 0.45 + 0.4, 0.24, 0.34), roof_color.darkened(0.25))
	# Upturned eave tips at the corners.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.box(Vector3(x * (w * 0.5 + 0.85), top + 0.1, z * (d * 0.5 + 0.85)), Vector3(0.5, 0.14, 0.5), roof_color.darkened(0.2), Vector3(z * 12.0, 0, -x * 12.0))


static func _shoji(b: Batch, pos: Vector3, size: Vector3) -> void:
	b.box(pos, size, SHOJI)
	var thin := 0.05
	b.box(pos + Vector3(0, 0, 0.02), Vector3(size.x + 0.08, thin, size.z), WOOD_DARK)
	for i in 3:
		var x := (float(i) - 1.0) * size.x / 3.0
		b.box(pos + Vector3(x, 0, 0.02), Vector3(thin, size.y, size.z), WOOD_DARK)
	b.box(pos + Vector3(0, size.y * 0.5, 0.02), Vector3(size.x + 0.08, thin, size.z), WOOD_DARK)
	b.box(pos + Vector3(0, -size.y * 0.5, 0.02), Vector3(size.x + 0.08, thin, size.z), WOOD_DARK)


## A shop front (machiya): a house with an open counter, a noren curtain over
## the door and a hanging sign board.
static func shop(b: Batch, w: float, d: float, noren: Color, sign_color := WOOD_DARK, floors := 2, icon := "") -> void:
	house(b, w, d, 2.8, TILE, floors)
	var front := d * 0.5 + 0.06
	# Open counter with goods.
	b.box(Vector3(-w * 0.22, 1.25, front + 0.02), Vector3(w * 0.4, 1.4, 0.06), WOOD_DARK)
	b.box(Vector3(-w * 0.22, 1.0, front + 0.45), Vector3(w * 0.42, 0.14, 0.8), WOOD_LIGHT)
	for i in 4:
		b.ball(Vector3(-w * 0.36 + i * w * 0.09, 1.18, front + 0.45), Vector3(0.32, 0.26, 0.32), [Color("e8a040"), Color("c8d070"), Color("e86a5a"), Color("f0e0b0")][i])
	# Noren: split cloth strips over the doorway with a white crest, swaying.
	var hang := hanging_weight(2.95, 1.0)
	for i in 4:
		b.cloth(Vector3(w * 0.2 + (i - 1.5) * 0.42, 2.45, front + 0.12), Vector3(0.38, 1.0, 0.04), noren, hang)
	b.cloth(Vector3(w * 0.2, 2.55, front + 0.16), Vector3(0.45, 0.45, 0.02), Color("fff6e8"), hang)
	b.box(Vector3(w * 0.2, 2.98, front + 0.12), Vector3(1.8, 0.07, 0.07), WOOD_DARK)
	# Sign board on the eave, with the trade's icon.
	b.box(Vector3(0, 3.55, front + 0.3), Vector3(w * 0.5, 0.6, 0.12), sign_color)
	b.box(Vector3(0, 3.55, front + 0.37), Vector3(w * 0.42, 0.42, 0.02), GOLD.darkened(0.15))
	sign_icon(b, icon, Vector3(0, 3.55, front + 0.42))


## A trade icon on a sign board: "coin", "hammer", "cup" (sake), "scroll".
static func sign_icon(b: Batch, icon: String, pos: Vector3) -> void:
	match icon:
		"coin":
			b.cyl(pos, 0.2, 0.05, Color("f6d060"), Vector3(90, 0, 0), 12)
			b.box(pos + Vector3(0, 0, 0.03), Vector3(0.08, 0.08, 0.02), Color("b07820"))
		"hammer":
			b.box(pos + Vector3(0.05, 0.12, 0), Vector3(0.34, 0.14, 0.12), Color("50505a"))
			b.cyl(pos + Vector3(0, -0.06, 0), 0.03, 0.32, Color("8a5a30"), Vector3(0, 0, 14), 6)
		"cup":
			b.cyl(pos + Vector3(-0.1, -0.02, 0), 0.1, 0.22, Color("f4f0e6"), Vector3.ZERO, 8)
			b.cyl(pos + Vector3(-0.1, 0.1, 0), 0.08, 0.02, Color("e8463a"), Vector3.ZERO, 8)
			b.ball(pos + Vector3(0.14, 0.02, 0), Vector3(0.16, 0.22, 0.08), Color("e8463a"), true)
		"scroll":
			b.cyl(pos, 0.07, 0.36, Color("f4ead0"), Vector3(0, 0, 90), 8)
			b.box(pos + Vector3(0, -0.02, 0.02), Vector3(0.2, 0.1, 0.02), Color("2a2a30"))


## A white storehouse (kura): thick plaster walls, a checker tile skirt
## (namako) and a heavy roof.
static func kura(b: Batch, w: float, d: float, h: float) -> void:
	b.box(Vector3(0, 0.25, 0), Vector3(w + 0.3, 0.5, d + 0.3), STONE_DARK)
	b.box(Vector3(0, 0.5 + h * 0.5, 0), Vector3(w, h, d), PLASTER)
	var tiles := int(w / 0.6)
	for side in [-1.0, 1.0]:
		for i in tiles:
			for row in 2:
				var dark := (i + row) % 2 == 0
				b.box(Vector3(-w * 0.5 + 0.3 + i * 0.6, 0.75 + row * 0.55, side * (d * 0.5 + 0.02)), Vector3(0.56, 0.5, 0.04), TILE_DARK if dark else Color("e6e2d8"))
	b.box(Vector3(0, 0.5 + h * 0.45, d * 0.5 + 0.05), Vector3(1.4, h * 0.7, 0.1), WOOD_DARK)
	b.box(Vector3(0, 0.5 + h * 0.45, d * 0.5 + 0.12), Vector3(0.9, h * 0.55, 0.05), Color("2a2a30"))
	b.box(Vector3(0, 0.5 + h + 0.15, 0), Vector3(w + 0.3, 0.3, d + 0.3), PLASTER)
	b.roof(Vector3(0, 0.5 + h + 0.9, 0), w + 1.4, d + 1.4, 1.2, TILE_DARK, 0.6)
	b.box(Vector3(0, 0.5 + h + 1.5, 0), Vector3(w * 0.6 + 0.5, 0.28, 0.4), TILE_DARK.darkened(0.3))


## A long training hall (dojo) with a wide veranda and a name board.
static func dojo(b: Batch, w: float, d: float) -> void:
	b.box(Vector3(0, 0.35, 0), Vector3(w + 1.6, 0.7, d + 1.6), STONE)
	b.box(Vector3(0, 0.78, 0), Vector3(w + 1.4, 0.16, d + 1.4), WOOD_LIGHT)
	b.box(Vector3(0, 0.86 + 1.8, 0), Vector3(w, 3.6, d), PLASTER)
	for i in 7:
		var x := -w * 0.5 + i * w / 6.0
		for z in [-1.0, 1.0]:
			b.box(Vector3(x, 0.86 + 1.8, z * (d * 0.5 + 0.6)), Vector3(0.3, 3.6, 0.3), WOOD_DARK)
	for i in 3:
		_shoji(b, Vector3(-w * 0.32 + i * w * 0.32, 2.4, d * 0.5 + 0.04), Vector3(w * 0.24, 2.4, 0.05))
	b.box(Vector3(0, 4.55, 0), Vector3(w + 1.4, 0.3, d + 1.4), WOOD_DARK)
	b.roof(Vector3(0, 5.6, 0), w + 3.4, d + 3.4, 2.2, TILE, 0.55)
	b.box(Vector3(0, 6.7, 0), Vector3(w * 0.55 + 0.5, 0.3, 0.45), TILE_DARK)
	# Steps and the name board.
	for i in 3:
		b.box(Vector3(0, 0.12 + i * 0.22, d * 0.5 + 1.2 + (2 - i) * 0.35), Vector3(3.0, 0.22, 0.4), STONE)
	b.box(Vector3(0, 4.15, d * 0.5 + 0.75), Vector3(2.6, 0.7, 0.12), WOOD_DARK)
	b.box(Vector3(0, 4.15, d * 0.5 + 0.82), Vector3(2.3, 0.5, 0.02), Color("f4ead0"))


## A shrine hall (honden) on a stone terrace with steps, vermilion posts, a
## copper-green roof, a sacred rope (shimenawa) and an offering box.
static func shrine(b: Batch) -> void:
	b.box(Vector3(0, 0.6, 0), Vector3(11.0, 1.2, 9.0), STONE)
	for i in 4:
		b.box(Vector3(0, 0.15 + i * 0.3, 4.5 + (3 - i) * 0.45), Vector3(4.0, 0.3, 0.45), STONE_DARK if i % 2 == 0 else STONE)
	b.box(Vector3(0, 1.28, 0), Vector3(8.6, 0.16, 7.0), WOOD_LIGHT)
	b.box(Vector3(0, 2.9, -0.6), Vector3(7.0, 3.1, 5.2), Color("f6efe2"))
	for x in [-4.0, -1.35, 1.35, 4.0]:
		for z in [-3.2, 2.6]:
			b.cyl(Vector3(x, 2.9, z), 0.2, 3.2, VERMILION)
	b.box(Vector3(0, 4.45, -0.3), Vector3(8.6, 0.3, 6.4), VERMILION.darkened(0.2))
	b.roof(Vector3(0, 5.5, -0.3), 11.4, 9.0, 2.2, COPPER, 0.5)
	b.box(Vector3(0, 6.6, -0.3), Vector3(6.2, 0.35, 0.5), COPPER.darkened(0.3))
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * 2.8, 6.95, -0.3), Vector3(0.18, 0.7, 0.18), COPPER.darkened(0.3), Vector3(0, 0, x * 25.0))
	# Sacred rope with paper streamers, the bell and offering box.
	b.cyl(Vector3(0, 4.1, 2.75), 0.16, 5.6, Color("e8d8a0"), Vector3(0, 0, 90), 6)
	for x in [-1.6, 0.0, 1.6]:
		b.box(Vector3(x, 3.7, 2.8), Vector3(0.18, 0.55, 0.03), Color.WHITE)
	b.ball(Vector3(0, 3.6, 2.9), Vector3(0.45, 0.45, 0.45), GOLD)
	b.box(Vector3(0, 1.75, 3.2), Vector3(1.8, 0.8, 0.8), WOOD)
	b.box(Vector3(0, 2.18, 3.2), Vector3(1.9, 0.08, 0.9), WOOD_DARK)


## A torii gate, [param w] wide between the posts and [param h] tall.
static func torii(b: Batch, w: float, h: float, color := VERMILION) -> void:
	for x in [-0.5, 0.5]:
		b.cyl(Vector3(x * w, h * 0.5, 0), 0.24 * h / 5.0, h, color)
		b.cyl(Vector3(x * w, 0.25, 0), 0.32 * h / 5.0, 0.5, Color("2a2a2a"))
	b.box(Vector3(0, h * 0.78, 0), Vector3(w + 0.9, 0.3, 0.32), color)
	b.box(Vector3(0, h * 0.97, 0), Vector3(w + 2.0, 0.36, 0.5), color)
	b.box(Vector3(0, h * 1.03, 0), Vector3(w + 2.3, 0.2, 0.6), Color("2a2a2a"))
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * (w * 0.5 + 1.05), h * 1.06, 0), Vector3(0.6, 0.2, 0.6), Color("2a2a2a"), Vector3(0, 0, x * 14.0))
	b.box(Vector3(0, h * 0.88, 0), Vector3(0.4, h * 0.2, 0.34), color)


## A five-storey pagoda: vermilion posts and white walls under dark roofs that
## shrink towards the top, crowned by a ringed spire.
static func pagoda(b: Batch, tiers := 5) -> void:
	b.box(Vector3(0, 0.4, 0), Vector3(7.0, 0.8, 7.0), STONE)
	var y := 0.8
	for i in tiers:
		var s := 5.0 - i * 0.62
		var h := 2.1 - i * 0.12
		b.box(Vector3(0, y + h * 0.5, 0), Vector3(s, h, s), Color("f3ece0"))
		for x in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				b.box(Vector3(x * s, y + h * 0.5, z * s), Vector3(0.26, h, 0.26), VERMILION)
		b.box(Vector3(0, y + h * 0.45, s * 0.5 + 0.02), Vector3(s * 0.34, h * 0.6, 0.04), VERMILION.darkened(0.25))
		y += h
		b.roof(Vector3(0, y + 0.35, 0), s + 2.6, s + 2.6, 0.8, TILE_DARK, 0.1)
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				b.box(Vector3(x * (s * 0.5 + 1.25), y + 0.0, z * (s * 0.5 + 1.25)), Vector3(0.45, 0.14, 0.45), TILE_DARK.darkened(0.2), Vector3(z * 14.0, 0, -x * 14.0))
		y += 0.55
	b.cyl(Vector3(0, y + 2.0, 0), 0.12, 4.0, GOLD.darkened(0.25))
	for i in 7:
		b.cyl(Vector3(0, y + 1.0 + i * 0.4, 0), 0.32 - i * 0.02, 0.1, GOLD, Vector3.ZERO, 10)
	b.ball(Vector3(0, y + 4.1, 0), Vector3(0.4, 0.5, 0.4), GOLD)


## A stone lantern (toro) with a glowing fire box.
static func toro(b: Batch, pos: Vector3, scale := 1.0) -> void:
	var s := scale
	b.box(pos + Vector3(0, 0.15, 0) * s, Vector3(0.9, 0.3, 0.9) * s, STONE_DARK)
	b.cyl(pos + Vector3(0, 0.75, 0) * s, 0.16 * s, 0.9 * s, STONE, Vector3.ZERO, 6)
	b.box(pos + Vector3(0, 1.25, 0) * s, Vector3(0.75, 0.15, 0.75) * s, STONE)
	b.box(pos + Vector3(0, 1.58, 0) * s, Vector3(0.5, 0.5, 0.5) * s, Color("ffe3a0"), Vector3.ZERO, true)
	b.light(pos + Vector3(0, 1.58, 0) * s, Color("ffd890"))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.box(pos + Vector3(x * 0.24, 1.58, z * 0.24) * s, Vector3(0.08, 0.52, 0.08) * s, STONE)
	b.roof(pos + Vector3(0, 2.05, 0) * s, 1.1 * s, 1.1 * s, 0.45 * s, STONE, 0.0)
	b.ball(pos + Vector3(0, 2.36, 0) * s, Vector3(0.2, 0.26, 0.2) * s, STONE)


## A paper lantern (chochin) hanging at [param pos].
static func chochin(b: Batch, pos: Vector3, color := Color("e8463a"), size := 1.0) -> void:
	b.ball(pos, Vector3(0.42, 0.58, 0.42) * size, color.lightened(0.15), true)
	b.light(pos, color.lightened(0.3))
	b.cyl(pos + Vector3(0, 0.3, 0) * size, 0.14 * size, 0.08 * size, Color("2a2a2a"), Vector3.ZERO, 6)
	b.cyl(pos - Vector3(0, 0.3, 0) * size, 0.14 * size, 0.08 * size, Color("2a2a2a"), Vector3.ZERO, 6)


## A line of paper lanterns on a rope between two posts.
static func lantern_line(b: Batch, from: Vector3, to: Vector3, count: int, colors: Array) -> void:
	for p in [from, to]:
		b.cyl(p + Vector3(0, 1.9, 0), 0.1, 3.8, WOOD_DARK, Vector3.ZERO, 6)
	var a := from + Vector3(0, 3.6, 0)
	var c := to + Vector3(0, 3.6, 0)
	var length := a.distance_to(c)
	var yaw := rad_to_deg(atan2(c.x - a.x, c.z - a.z))
	b.box((a + c) * 0.5 + Vector3(0, -0.15, 0), Vector3(0.04, 0.04, length), Color("3a3028"), Vector3(0, yaw, 0))
	for i in count:
		var t := (float(i) + 1.0) / (float(count) + 1.0)
		var sag := sin(t * PI) * 0.35
		chochin(b, a.lerp(c, t) + Vector3(0, -0.6 - sag, 0), colors[i % colors.size()], 0.8)


## An arched vermilion bridge along z, [param length] long.
static func bridge(b: Batch, length: float, width := 2.6) -> void:
	var steps := 12
	for i in steps + 1:
		var t := float(i) / float(steps)
		var z := (t - 0.5) * length
		var y := 0.25 + sin(t * PI) * 1.1
		var slope := cos(t * PI) * 1.1 * PI / length
		b.box(Vector3(0, y, z), Vector3(width, 0.18, length / steps + 0.08), WOOD_LIGHT, Vector3(-rad_to_deg(atan(slope)), 0, 0))
		for x in [-1.0, 1.0]:
			if i % 2 == 0:
				b.cyl(Vector3(x * width * 0.5, y + 0.45, z), 0.07, 0.9, VERMILION, Vector3.ZERO, 6)
			b.box(Vector3(x * width * 0.5, y + 0.88, z), Vector3(0.12, 0.1, length / steps + 0.1), VERMILION, Vector3(-rad_to_deg(atan(slope)), 0, 0))
		if i == 0 or i == steps:
			for x in [-1.0, 1.0]:
				b.ball(Vector3(x * width * 0.5, y + 1.0, z), Vector3(0.22, 0.3, 0.22), GOLD)


## Bamboo fence from [param from] to [param to].
static func fence(b: Batch, from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.01)
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var count := int(length / 0.22)
	for i in count:
		var p := from + dir * (float(i) + 0.5) * 0.22
		b.cyl(p + Vector3(0, 0.65, 0), 0.07, 1.3 + (i % 3) * 0.06, Color("c8b46a") if i % 2 == 0 else Color("a8a050"), Vector3.ZERO, 5)
	for h in [0.4, 1.0]:
		b.box((from + to) * 0.5 + Vector3(0, h, 0), Vector3(0.1, 0.08, length), Color("6a5030"), Vector3(0, yaw, 0))


## A tall nobori banner on a pole.
static func banner(b: Batch, pos: Vector3, color: Color) -> void:
	b.cyl(pos + Vector3(0, 2.2, 0), 0.06, 4.4, WOOD_DARK, Vector3.ZERO, 6)
	var weight := banner_weight(pos.x + 0.03, pos.y + 4.0, 0.7, 2.8)
	b.cloth(pos + Vector3(0.38, 2.6, 0), Vector3(0.7, 2.8, 0.03), color, weight)
	b.box(pos + Vector3(0.38, 4.0, 0), Vector3(0.8, 0.05, 0.05), WOOD_DARK)
	b.cloth(pos + Vector3(0.38, 2.6, 0.02), Vector3(0.22, 2.2, 0.01), Color("fff6e0"), weight)


## A market stall: four posts under a cloth awning, a counter with crates and
## fruit, and a short noren along the front eave. Front = +z.
static func stall(b: Batch, w: float, d: float, awning: Color, goods: Array) -> void:
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			b.cyl(Vector3(x * w, 1.25, z * d), 0.07, 2.5, WOOD_DARK, Vector3.ZERO, 6)
	b.box(Vector3(0, 0.85, d * 0.15), Vector3(w * 0.95, 0.1, d * 0.6), WOOD_LIGHT)
	b.box(Vector3(0, 0.45, d * 0.15), Vector3(w * 0.9, 0.7, d * 0.5), WOOD)
	var top := 2.55
	b.cloth(Vector3(0, top, 0), Vector3(w + 0.6, 0.06, d + 0.6), awning, func(v: Vector3) -> float:
		return clampf(absf(v.z) / (d * 0.5 + 0.3) - 0.5, 0.0, 1.0) * 0.6)
	var hang := hanging_weight(top, 0.5)
	for i in int(w / 0.5):
		b.cloth(Vector3(-w * 0.5 + 0.25 + i * 0.5, top - 0.26, d * 0.5 + 0.3), Vector3(0.44, 0.5, 0.03), awning if i % 2 == 0 else Color("f6efe0"), hang)
	for i in goods.size():
		var x := -w * 0.35 + i * (w * 0.7 / maxf(goods.size() - 1, 1))
		if i % 2 == 0:
			b.box(Vector3(x, 1.12, d * 0.1), Vector3(0.55, 0.45, 0.55), Color("b8905a"))
			for j in 4:
				b.ball(Vector3(x - 0.15 + (j % 2) * 0.3, 1.42, d * 0.1 - 0.15 + (j / 2) * 0.3), Vector3(0.22, 0.22, 0.22), goods[i])
		else:
			b.box(Vector3(x, 0.98, d * 0.2), Vector3(0.6, 0.16, 0.5), Color("d8c8a0"))
			for j in 3:
				b.ball(Vector3(x - 0.18 + j * 0.18, 1.16, d * 0.2), Vector3(0.2, 0.2, 0.2), goods[i])
	# A crate or two beside the stall.
	b.box(Vector3(w * 0.5 + 0.5, 0.3, d * 0.3), Vector3(0.6, 0.6, 0.6), Color("a07a48"), Vector3(0, 20, 0))
	b.box(Vector3(-w * 0.5 - 0.45, 0.25, -d * 0.1), Vector3(0.5, 0.5, 0.5), Color("8a6a40"), Vector3(0, -15, 0))


## A covered well with a wooden roof.
static func well(b: Batch) -> void:
	b.cyl(Vector3(0, 0.45, 0), 0.9, 0.9, STONE, Vector3.ZERO, 10)
	b.cyl(Vector3(0, 0.9, 0), 0.72, 0.04, Color("3a6a8a"), Vector3.ZERO, 10)
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * 0.85, 1.4, 0), Vector3(0.14, 2.0, 0.14), WOOD)
	b.box(Vector3(0, 2.1, 0), Vector3(1.9, 0.12, 0.12), WOOD_DARK)
	b.roof(Vector3(0, 2.6, 0), 2.6, 1.8, 0.8, TILE, 0.8)


## The quest notice board (kosatsu): two posts, a small roof, pinned papers.
static func notice_board(b: Batch) -> void:
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * 1.1, 1.3, 0), Vector3(0.18, 2.6, 0.18), WOOD_DARK)
	b.box(Vector3(0, 1.55, 0), Vector3(2.3, 1.4, 0.1), WOOD_LIGHT)
	var notes := [Color("fffaf0"), Color("ffe8b0"), Color("fff0f0"), Color("e8f4ff"), Color("fffaf0")]
	for i in 5:
		b.box(Vector3(-0.8 + i * 0.4, 1.6 + (i % 2) * 0.25, 0.07), Vector3(0.32, 0.5, 0.02), notes[i], Vector3(0, 0, (i % 3 - 1) * 5.0))
	b.roof(Vector3(0, 2.75, 0), 2.9, 0.9, 0.5, TILE, 0.85)


## A training ring for the arena: a raised clay circle with straw edging.
static func ring(b: Batch, radius: float) -> void:
	b.cyl(Vector3(0, 0.2, 0), radius, 0.4, Color("c8a878"), Vector3.ZERO, 24)
	b.cyl(Vector3(0, 0.42, 0), radius * 0.92, 0.06, Color("d8bc8c"), Vector3.ZERO, 24)
	for i in 20:
		var a := TAU * i / 20.0
		b.box(Vector3(cos(a), 0.45, sin(a)) * Vector3(radius * 0.94, 1, radius * 0.94), Vector3(0.9, 0.16, 0.22), Color("d8c88a"), Vector3(0, -rad_to_deg(a) + 90.0, 0))


## The big village gate: two thick posts, a crossbeam and a small tiled roof.
static func village_gate(b: Batch, w: float) -> void:
	for x in [-0.5, 0.5]:
		b.box(Vector3(x * w, 2.4, 0), Vector3(0.6, 4.8, 0.6), WOOD_DARK)
		b.box(Vector3(x * w, 0.3, 0), Vector3(0.9, 0.6, 0.9), STONE)
	b.box(Vector3(0, 4.3, 0), Vector3(w + 1.0, 0.45, 0.5), WOOD)
	b.box(Vector3(0, 3.5, 0), Vector3(w, 0.3, 0.4), WOOD)
	b.roof(Vector3(0, 5.15, 0), w + 2.4, 2.0, 1.1, TILE, 0.85)
	b.box(Vector3(0, 3.9, 0.28), Vector3(2.0, 0.55, 0.08), Color("f2e6c8"))


## A low tile-capped plaster wall (tsuiji-bei) from [param from] to [param to]: a stone
## footing, the wall, dark posts every few metres and a small tiled ridge on top. Four
## boxes and a roof for the whole run, however long.
static func low_wall(b: Batch, from: Vector3, to: Vector3, plaster := PLASTER, cap := TILE_DARK) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.01)
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var mid := (from + to) * 0.5
	b.box(mid + Vector3(0, 0.18, 0), Vector3(0.7, 0.36, length + 0.2), STONE_DARK, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, 0.82, 0), Vector3(0.48, 0.95, length), plaster, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, 0.46, 0), Vector3(0.5, 0.22, length + 0.02), WOOD, Vector3(0, yaw, 0))
	b.roof(mid + Vector3(0, 1.48, 0), length + 0.5, 1.0, 0.42, cap, 0.96, yaw + 90.0)
	b.box(mid + Vector3(0, 1.7, 0), Vector3(0.16, 0.1, length + 0.3), cap.darkened(0.3), Vector3(0, yaw, 0))
	var posts := int(length / 4.5)
	for i in range(1, posts):
		b.box(from + dir * (length * float(i) / float(posts)) + Vector3(0, 0.82, 0), Vector3(0.56, 0.95, 0.2), WOOD_DARK, Vector3(0, yaw, 0))


## A district gate (kabuki-mon): two thick posts on stone feet, a tie beam, a tiled
## roof with gold ends, a name plaque in the district's colour and two paper lanterns.
## [param w] is the opening; the front (+z) is the side the plaque faces.
static func district_gate(b: Batch, w: float, accent: Color, roof_color := TILE_DARK) -> void:
	for x in [-0.5, 0.5]:
		b.box(Vector3(x * w, 0.3, 0), Vector3(1.0, 0.6, 1.0), STONE)
		b.box(Vector3(x * w, 2.6, 0), Vector3(0.62, 4.6, 0.62), WOOD_DARK)
		b.box(Vector3(x * w, 4.2, 0), Vector3(0.7, 0.18, 0.7), GOLD.darkened(0.2))
		# Small side roofs over each post (a kabuki-mon's shoulders).
		b.box(Vector3(x * (w + 1.6), 1.4, 0), Vector3(1.6, 2.8, 0.42), PLASTER)
		b.roof(Vector3(x * (w + 1.6), 3.05, 0), 2.2, 1.2, 0.5, roof_color, 0.6)
	b.box(Vector3(0, 4.55, 0), Vector3(w + 1.4, 0.42, 0.55), WOOD)
	b.box(Vector3(0, 3.7, 0), Vector3(w, 0.24, 0.42), WOOD_DARK)
	b.roof(Vector3(0, 5.45, 0), w + 3.2, 2.6, 1.3, roof_color, 0.7)
	b.box(Vector3(0, 6.08, 0), Vector3(w * 0.7 + 1.0, 0.22, 0.32), roof_color.darkened(0.3))
	for x in [-1.0, 1.0]:
		b.ball(Vector3(x * (w * 0.35 + 0.5), 6.2, 0), Vector3(0.3, 0.36, 0.3), GOLD)
	# The name plaque: a dark frame, the district's colour and a gold rim.
	b.box(Vector3(0, 4.55, 0.36), Vector3(3.4, 0.95, 0.12), WOOD_DARK)
	b.box(Vector3(0, 4.55, 0.43), Vector3(3.2, 0.78, 0.04), accent)
	b.box(Vector3(0, 4.97, 0.44), Vector3(3.3, 0.06, 0.05), GOLD)
	b.box(Vector3(0, 4.13, 0.44), Vector3(3.3, 0.06, 0.05), GOLD)
	for x in [-1.0, 1.0]:
		chochin(b, Vector3(x * (w * 0.5 - 0.9), 3.05, 0.3), accent.lerp(Color("f6efe0"), 0.25), 1.15)


## The great village gate (romon): two storeys on eight vermilion pillars, a wide lower
## roof, a white upper hall with a balcony rail, a crowning roof with gold ends, a name
## plaque and two big red lanterns. [param w] is the opening (front = +z).
static func grand_gate(b: Batch, w: float) -> void:
	var half := w * 0.5
	for x in [-half, half, -half - 3.0, half + 3.0]:
		for z in [-1.4, 1.4]:
			b.cyl(Vector3(x, 2.7, z), 0.32, 5.4, VERMILION)
			b.box(Vector3(x, 0.2, z), Vector3(0.95, 0.4, 0.95), STONE)
	for z in [-1.4, 1.4]:
		b.box(Vector3(0, 5.1, z), Vector3(w + 7.0, 0.42, 0.42), VERMILION.darkened(0.15))
		b.box(Vector3(0, 4.3, z), Vector3(w, 0.28, 0.34), VERMILION.darkened(0.15))
	# Side bays: white plaster panels between the outer pillars.
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * (half + 1.5), 1.9, 0), Vector3(2.7, 3.4, 0.3), PLASTER)
		b.box(Vector3(x * (half + 1.5), 0.35, 0), Vector3(2.8, 0.5, 0.36), WOOD)
	b.roof(Vector3(0, 5.95, 0), w + 10.0, 6.0, 1.2, TILE_DARK, 0.85)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.box(Vector3(x * (half + 5.2), 5.4, z * 3.1), Vector3(0.7, 0.16, 0.7), TILE_DARK.darkened(0.2), Vector3(z * 12.0, 0, -x * 12.0))
	# Upper hall with its balcony.
	b.box(Vector3(0, 6.75, 0), Vector3(w + 4.4, 0.3, 3.6), WOOD)
	b.box(Vector3(0, 8.0, 0), Vector3(w + 2.4, 2.3, 2.4), PLASTER)
	for x in [-1.0, -0.33, 0.33, 1.0]:
		b.box(Vector3(x * (w * 0.5 + 1.2), 8.0, 1.22), Vector3(0.24, 2.3, 0.1), VERMILION)
	_shoji(b, Vector3(-w * 0.2, 8.1, 1.24), Vector3(w * 0.26, 1.2, 0.05))
	_shoji(b, Vector3(w * 0.2, 8.1, 1.24), Vector3(w * 0.26, 1.2, 0.05))
	b.box(Vector3(0, 7.35, 1.85), Vector3(w + 4.2, 0.1, 0.1), VERMILION)
	b.box(Vector3(0, 7.35, -1.85), Vector3(w + 4.2, 0.1, 0.1), VERMILION)
	b.roof(Vector3(0, 9.95, 0), w + 6.0, 5.0, 1.8, TILE_DARK, 0.6)
	b.box(Vector3(0, 10.9, 0), Vector3(w * 0.75 + 1.5, 0.3, 0.4), TILE_DARK.darkened(0.3))
	for x in [-1.0, 1.0]:
		b.ball(Vector3(x * (w * 0.37 + 0.8), 11.15, 0), Vector3(0.45, 0.6, 0.45), GOLD)
		for z in [-1.0, 1.0]:
			b.box(Vector3(x * (half + 3.1), 9.2, z * 2.6), Vector3(0.6, 0.16, 0.6), TILE_DARK.darkened(0.2), Vector3(z * 14.0, 0, -x * 14.0))
	# Plaque and lanterns on the front.
	b.box(Vector3(0, 5.15, 1.7), Vector3(3.8, 1.0, 0.14), WOOD_DARK)
	b.box(Vector3(0, 5.15, 1.78), Vector3(3.5, 0.8, 0.04), Color("f2e6c8"))
	for x in [-1.0, 1.0]:
		chochin(b, Vector3(x * (half - 1.2), 3.3, 1.6), Color("e8463a"), 1.7)
		chochin(b, Vector3(x * (half - 1.2), 3.3, -1.6), Color("e8463a"), 1.7)


## A small castle keep (tenshu) on a sloped stone base: three white storeys under dark
## tiered roofs, vermilion balcony on top, gold dolphin ornaments (shachihoko) and a
## big door with banners. Front = +z.
static func castle_keep(b: Batch) -> void:
	for i in 3:
		var s := 12.0 - i * 0.8
		b.box(Vector3(0, 0.5 + i * 1.0, 0), Vector3(s, 1.0, s - 1.8), STONE_DARK if i % 2 == 0 else STONE)
	var y := 3.0
	var tiers := [[9.4, 7.2, 3.2], [7.0, 5.4, 2.7], [4.8, 3.8, 2.4]]
	for i in tiers.size():
		var t: Array = tiers[i]
		var w: float = t[0]
		var d: float = t[1]
		var h: float = t[2]
		b.box(Vector3(0, y + h * 0.5, 0), Vector3(w, h, d), PLASTER)
		b.box(Vector3(0, y + 0.3, 0), Vector3(w + 0.06, 0.6, d + 0.06), TILE_DARK)
		for x in [-0.5, 0.5]:
			for z in [-0.5, 0.5]:
				b.box(Vector3(x * w, y + h * 0.5, z * d), Vector3(0.24, h, 0.24), WOOD_DARK)
		for x in [-0.25, 0.25]:
			b.box(Vector3(x * w, y + h * 0.6, d * 0.5 + 0.03), Vector3(0.9, 0.7, 0.05), Color("2a2a30"))
		y += h
		b.roof(Vector3(0, y + 0.6, 0), w + 2.6, d + 2.6, 1.2, TILE_DARK, 0.5)
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				b.box(Vector3(x * (w * 0.5 + 1.2), y + 0.05, z * (d * 0.5 + 1.2)), Vector3(0.5, 0.14, 0.5), TILE_DARK.darkened(0.2), Vector3(z * 14.0, 0, -x * 14.0))
		# A gabled dormer on the front of the lower roofs (chidori-hafu).
		if i < 2:
			b.roof(Vector3(0, y + 0.55, d * 0.5 + 0.9), 1.8, 2.6, 1.0, TILE_DARK, 0.5, 90.0)
			b.box(Vector3(0, y + 0.45, d * 0.5 + 1.6), Vector3(1.8, 0.7, 0.06), GOLD.darkened(0.2))
		y += 1.2
	b.box(Vector3(0, y - 0.1, 0), Vector3(3.6, 0.3, 0.4), TILE_DARK.darkened(0.3))
	for x in [-1.0, 1.0]:
		b.ball(Vector3(x * 1.7, y + 0.35, 0), Vector3(0.35, 0.7, 0.3), GOLD)
		b.box(Vector3(x * 1.9, y + 0.7, 0), Vector3(0.36, 0.22, 0.16), GOLD, Vector3(0, 0, x * 40.0))
	# Balcony rail round the top storey.
	b.box(Vector3(0, 14.0, 2.45), Vector3(5.6, 0.1, 0.1), VERMILION)
	# Door, steps and a gold crest over it.
	b.box(Vector3(0, 4.4, 3.65), Vector3(2.2, 2.6, 0.1), WOOD_DARK)
	b.box(Vector3(0, 4.4, 3.7), Vector3(0.06, 2.4, 0.04), GOLD.darkened(0.3))
	b.cyl(Vector3(0, 6.2, 3.68), 0.45, 0.08, GOLD, Vector3(90, 0, 0), 12)
	for i in 3:
		b.box(Vector3(0, 0.5 + i * 1.0, 5.1 + (2 - i) * 0.9), Vector3(3.2, 1.0, 0.9), STONE)


## A light market booth: four posts, a cloth awning and a counter with heaped goods
## (cones and crates, cheaper than the big stall's fruit). Front = +z.
static func market_booth(b: Batch, w: float, d: float, awning: Color, goods: Array) -> void:
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			b.box(Vector3(x * w, 1.2, z * d), Vector3(0.12, 2.4, 0.12), WOOD_DARK)
	b.box(Vector3(0, 0.45, d * 0.1), Vector3(w * 0.92, 0.9, d * 0.55), WOOD)
	b.box(Vector3(0, 0.93, d * 0.1), Vector3(w * 0.96, 0.08, d * 0.62), WOOD_LIGHT)
	b.cloth(Vector3(0, 2.45, 0), Vector3(w + 0.5, 0.06, d + 0.5), awning, func(v: Vector3) -> float:
		return clampf(absf(v.z) / (d * 0.5 + 0.25) - 0.5, 0.0, 1.0) * 0.6)
	b.cloth(Vector3(0, 2.25, d * 0.5 + 0.25), Vector3(w + 0.5, 0.4, 0.03), Color("f6efe0") if awning.get_luminance() < 0.6 else awning.darkened(0.3), hanging_weight(2.45, 0.4))
	for i in goods.size():
		var x := -w * 0.32 + i * (w * 0.64 / maxf(goods.size() - 1, 1))
		b.box(Vector3(x, 1.08, d * 0.12), Vector3(0.5, 0.22, 0.42), Color("b8905a"))
		b.cone(Vector3(x, 1.36, d * 0.12), 0.24, 0.34, goods[i])
	b.box(Vector3(w * 0.5 + 0.35, 0.25, -d * 0.2), Vector3(0.5, 0.5, 0.5), Color("a07a48"), Vector3(0, 18, 0))


## A wooden bench (front = +z).
static func bench(b: Batch, pos: Vector3, yaw: float, w := 2.0) -> void:
	b.box(pos + Vector3(0, 0.46, 0), Vector3(w, 0.1, 0.55), WOOD_LIGHT, Vector3(0, yaw, 0))
	var side := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(w * 0.4, 0, 0)
	for s in [-1.0, 1.0]:
		b.box(pos + side * s + Vector3(0, 0.22, 0), Vector3(0.14, 0.44, 0.5), WOOD_DARK, Vector3(0, yaw, 0))


## A window flower box: a little wooden trough of bright blooms.
static func flower_box(b: Batch, pos: Vector3, w: float, yaw: float) -> void:
	b.box(pos, Vector3(w, 0.3, 0.4), WOOD, Vector3(0, yaw, 0))
	var along := Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3.RIGHT
	var blooms := [Color("f08aa8"), Color("f6d35a"), Color("f4f0e6"), Color("e8463a"), Color("c89ae8")]
	var n := int(w / 0.35)
	for i in n:
		var p := pos + along * (-w * 0.5 + 0.2 + i * (w - 0.4) / maxf(n - 1, 1)) + Vector3(0, 0.22, 0)
		b.box(p, Vector3(0.24, 0.2, 0.24), Color("6f9a52"), Vector3(0, yaw + i * 25.0, 0))
		b.box(p + Vector3(0, 0.14, 0), Vector3(0.16, 0.12, 0.16), blooms[i % blooms.size()], Vector3(0, yaw + i * 40.0, 0))


## A paper parasol (wagasa) on a pole, open over a bench or a stall.
static func parasol(b: Batch, pos: Vector3, color: Color, size := 1.0) -> void:
	b.cyl(pos + Vector3(0, 1.3, 0) * size, 0.05 * size, 2.6 * size, WOOD_LIGHT, Vector3.ZERO, 6)
	b.cone(pos + Vector3(0, 2.75, 0) * size, 1.5 * size, 0.6 * size, color)
	b.cone(pos + Vector3(0, 2.72, 0) * size, 0.5 * size, 0.62 * size, color.lightened(0.35))
	b.ball(pos + Vector3(0, 3.08, 0) * size, Vector3(0.12, 0.12, 0.12) * size, WOOD_DARK)


## A clump of bamboo: tall jointed green stalks with leafy tops.
static func bamboo(b: Batch, pos: Vector3, rng: RandomNumberGenerator, stalks := 6) -> void:
	for i in stalks:
		var a := rng.randf() * TAU
		var p := pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.2, 1.1)
		var h := rng.randf_range(6.0, 8.5)
		var lean := Vector3(rng.randf_range(-4.0, 4.0), 0, rng.randf_range(-4.0, 4.0))
		b.cyl(p + Vector3(0, h * 0.5, 0), 0.09, h, Color("7aa84a") if i % 2 == 0 else Color("6a9a40"), lean, 5)
		b.cone(p + Vector3(lean.z * 0.02 * h, h - 0.6, -lean.x * 0.02 * h), 0.9, 2.4, Color("5f9a48") if i % 3 else Color("78b058"))


## An archery target on a stand (front = +z).
static func target(b: Batch, pos: Vector3) -> void:
	for x in [-0.45, 0.45]:
		b.box(pos + Vector3(x, 0.8, -0.2), Vector3(0.1, 1.6, 0.1), WOOD, Vector3(-12, 0, 0))
	b.cyl(pos + Vector3(0, 1.3, 0), 0.6, 0.12, Color("f4ead0"), Vector3(90, 0, 0), 12)
	b.cyl(pos + Vector3(0, 1.3, 0.02), 0.42, 0.12, Color("1e2a4a"), Vector3(90, 0, 0), 12)
	b.cyl(pos + Vector3(0, 1.3, 0.04), 0.2, 0.12, Color("d8452e"), Vector3(90, 0, 0), 12)


## A garden pavilion (azumaya): four posts, a pyramid roof and a bench inside.
static func pavilion(b: Batch, size := 3.4) -> void:
	b.box(Vector3(0, 0.12, 0), Vector3(size + 0.6, 0.24, size + 0.6), STONE)
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			b.box(Vector3(x * size, 1.4, z * size), Vector3(0.2, 2.6, 0.2), WOOD)
	b.roof(Vector3(0, 3.25, 0), size + 1.8, size + 1.8, 1.4, THATCH.darkened(0.15), 0.0)
	b.ball(Vector3(0, 4.0, 0), Vector3(0.3, 0.3, 0.3), WOOD_DARK)
	bench(b, Vector3(0, 0.0, -size * 0.3), 0.0, size * 0.8)


## A scarecrow (kakashi) in a straw hat.
static func scarecrow(b: Batch, pos: Vector3) -> void:
	b.cyl(pos + Vector3(0, 1.0, 0), 0.06, 2.0, WOOD, Vector3.ZERO, 5)
	b.box(pos + Vector3(0, 1.45, 0), Vector3(1.4, 0.08, 0.08), WOOD)
	b.box(pos + Vector3(0, 1.2, 0), Vector3(0.7, 0.7, 0.22), Color("5a7ad8"))
	b.ball(pos + Vector3(0, 1.85, 0), Vector3(0.36, 0.36, 0.36), Color("f0e6c8"))
	b.cone(pos + Vector3(0, 2.1, 0), 0.5, 0.3, Color("d8bc78"))


## A pond with stone edging and lily pads; returns nothing (water is a
## separate translucent mesh, see [method water]).
static func pond_rim(b: Batch, radius: Vector2, rng: RandomNumberGenerator) -> void:
	var count := int((radius.x + radius.y) * 2.2)
	for i in count:
		var a := TAU * float(i) / float(count)
		var p := Vector3(cos(a) * radius.x, 0.15, sin(a) * radius.y)
		b.ball(p, Vector3(rng.randf_range(0.7, 1.2), rng.randf_range(0.35, 0.6), rng.randf_range(0.7, 1.1)), STONE.lerp(STONE_DARK, rng.randf()))
	for i in 6:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.3, 0.7)
		b.cyl(Vector3(cos(a) * radius.x * r, 0.08, sin(a) * radius.y * r), 0.35, 0.03, Color("5a9a4a"), Vector3.ZERO, 8)


## The pond surface: the same rippling, foam-edged water as the fields' coves.
static func water(parent: Node3D, pos: Vector3, radius: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RegionArt._oval_mesh(radius, 0.0)
	mi.position = pos + Vector3(0, 0.06, 0)
	mi.material_override = RegionArt._water_material(&"village")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Japanese headwear for villagers (head-bone space of a custom FaceKit head).
# ---------------------------------------------------------------------------

## kasa (straw cone), hachimaki / tenugui (headbands), eboshi (court hat),
## ribbon (a big bow) or "" for none.
static func hat(kind: String, color := Color.WHITE) -> Node3D:
	var b := Batch.new()
	match kind:
		"kasa":
			b.cone(Vector3(0, 1.12, 0), 0.95, 0.55, Color("d8bc78"))
			b.cyl(Vector3(0, 0.9, 0), 0.5, 0.06, Color("a8884a"), Vector3.ZERO, 10)
		"hachimaki":
			b.cyl(Vector3(0, 0.82, 0), 0.6, 0.16, color, Vector3.ZERO, 12)
			b.box(Vector3(0, 0.78, -0.62), Vector3(0.12, 0.1, 0.2), color)
			b.box(Vector3(0.12, 0.62, -0.68), Vector3(0.1, 0.36, 0.04), color, Vector3(0, 0, 18))
			b.box(Vector3(-0.1, 0.6, -0.66), Vector3(0.1, 0.32, 0.04), color, Vector3(0, 0, -14))
		"tenugui":
			b.ball(Vector3(0, 0.98, -0.02), Vector3(1.16, 0.62, 1.16), color)
			b.box(Vector3(0, 0.92, -0.58), Vector3(0.3, 0.22, 0.12), color.darkened(0.15))
		"eboshi":
			b.box(Vector3(0, 1.35, -0.05), Vector3(0.5, 0.75, 0.62), Color("1e1e24"), Vector3(-12, 0, 0))
			b.cyl(Vector3(0, 0.95, 0), 0.42, 0.12, Color("1e1e24"), Vector3.ZERO, 10)
		"ribbon":
			for x in [-1.0, 1.0]:
				b.ball(Vector3(x * 0.22, 1.12, -0.15), Vector3(0.38, 0.26, 0.14), color)
			b.ball(Vector3(0, 1.1, -0.15), Vector3(0.14, 0.14, 0.14), color.darkened(0.2))
	var root := Node3D.new()
	root.name = "Hat_" + kind
	if not b.is_empty():
		b.commit(root, "Mesh", false)
	return root


# ---------------------------------------------------------------------------
# Lived-in village detail (all in the batch's local frame, front = +z)
# ---------------------------------------------------------------------------

## A wall of sake barrels offered to the shrine (komodaru) on a low stand under a little
## roof: `cols` x `rows` straw-white barrels with coloured labels.
static func sake_barrels(b: Batch, cols := 4, rows := 2) -> void:
	var w := cols * 0.88
	b.box(Vector3(0, 0.15, 0), Vector3(w + 0.4, 0.3, 1.1), WOOD_DARK)
	var labels := [Color("c8352e"), Color("2f4f8a"), Color("3a3a42"), Color("4a8f5c"), Color("b8862e")]
	for r in rows:
		for c in cols:
			var p := Vector3((c - (cols - 1) * 0.5) * 0.88, 0.71 + r * 0.84, 0)
			b.cyl(p, 0.4, 0.82, Color("f4efe4"), Vector3.ZERO, 10)
			for y in [-0.28, 0.28]:
				b.cyl(p + Vector3(0, y, 0), 0.415, 0.06, Color("6a5038"), Vector3.ZERO, 10)
			b.box(p + Vector3(0, 0, 0.39), Vector3(0.44, 0.42, 0.04), labels[(r * cols + c) % labels.size()])
	var top := 0.3 + rows * 0.84 + 0.45
	for x in [-0.5, 0.5]:
		b.box(Vector3(x * (w + 0.3), top * 0.5, -0.45), Vector3(0.14, top, 0.14), WOOD_DARK)
	b.roof(Vector3(0, top, 0), w + 0.9, 1.7, 0.45, TILE_DARK, 0.0)


## A little wayside shrine (hokora) on a stone base with a small red torii in front.
static func hokora(b: Batch) -> void:
	b.box(Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 1.2), STONE)
	b.box(Vector3(0, 1.0, 0), Vector3(0.9, 0.8, 0.8), WOOD)
	b.box(Vector3(0, 0.98, 0.41), Vector3(0.52, 0.52, 0.02), SHOJI)
	b.roof(Vector3(0, 1.4, 0), 1.25, 1.2, 0.4, VERMILION, 0.0)
	for x in [-0.25, 0.25]:
		b.cyl(Vector3(x, 0.68, 0.5), 0.08, 0.16, Color("f4f0e6"), Vector3.ZERO, 6)
	for x in [-0.55, 0.55]:
		b.cyl(Vector3(x, 0.65, 1.35), 0.06, 1.3, VERMILION, Vector3.ZERO, 6)
	b.box(Vector3(0, 1.34, 1.35), Vector3(1.55, 0.1, 0.14), Color("2a2a2e"))
	b.box(Vector3(0, 1.15, 1.35), Vector3(1.2, 0.07, 0.1), VERMILION)


## A wooden hand cart (daihachi) loaded with rice sacks and a barrel, handles to +z.
static func cart(b: Batch, load_colors: Array) -> void:
	b.box(Vector3(0, 0.78, 0), Vector3(1.3, 0.1, 2.2), WOOD)
	for x in [-0.62, 0.62]:
		b.box(Vector3(x, 0.95, 0), Vector3(0.06, 0.3, 2.2), WOOD_DARK)
		b.cyl(Vector3(x * 1.2, 0.55, -0.2), 0.55, 0.1, WOOD_DARK, Vector3(0, 0, 90), 10)
		b.cyl(Vector3(x * 1.2, 0.55, -0.2), 0.12, 0.14, WOOD_LIGHT, Vector3(0, 0, 90), 6)
		b.box(Vector3(x * 0.75, 0.72, 1.65), Vector3(0.08, 0.08, 1.3), WOOD_DARK)
	b.box(Vector3(0, 0.72, 2.25), Vector3(1.3, 0.08, 0.08), WOOD_DARK)
	for i in load_colors.size():
		var at := Vector3((i % 2 - 0.5) * 0.6, 1.08 + (i / 2) * 0.32, -0.6 + (i % 3) * 0.55)
		b.box(at, Vector3(0.55, 0.32, 0.5), load_colors[i], Vector3(0, i * 23.0, 0))
	b.cyl(Vector3(0.1, 1.15, 0.75), 0.3, 0.6, Color("8a6a40"), Vector3.ZERO, 8)


## A raised stone-edged garden bed `w` x `d` of moss, shrubs and bright blooms.
static func garden_bed(b: Batch, w: float, d: float) -> void:
	for s in [-1.0, 1.0]:
		b.box(Vector3(0, 0.18, s * d * 0.5), Vector3(w + 0.3, 0.36, 0.3), STONE)
		b.box(Vector3(s * w * 0.5, 0.18, 0), Vector3(0.3, 0.36, d), STONE)
	b.box(Vector3(0, 0.2, 0), Vector3(w - 0.1, 0.3, d - 0.1), Color("5f8a46"))
	var blooms := [Color("f08aa8"), Color("f6d35a"), Color("f4f0e6"), Color("e8463a"), Color("c89ae8"), Color("f0a050")]
	var nx := maxi(1, int(w / 0.75))
	var nz := maxi(1, int(d / 0.75))
	for i in nx:
		for k in nz:
			var p := Vector3((i + 0.5) * w / nx - w * 0.5, 0.5, (k + 0.5) * d / nz - d * 0.5)
			if (i + k) % 3 == 0:
				b.ball(p, Vector3(0.6, 0.45, 0.6), Color("4f7e3c").lerp(Color("7aa85a"), float((i * 7 + k * 3) % 5) / 4.0))
			else:
				b.box(p, Vector3(0.3, 0.18, 0.3), Color("6f9a52"), Vector3(0, (i * 31 + k * 17) % 90, 0))
				b.ball(p + Vector3(0, 0.16, 0), Vector3(0.24, 0.18, 0.24), blooms[(i * 3 + k) % blooms.size()])


## A stone trough planter `w` wide topped with flowers.
static func planter(b: Batch, w: float) -> void:
	b.box(Vector3(0, 0.25, 0), Vector3(w, 0.5, 0.65), STONE_DARK)
	flower_box(b, Vector3(0, 0.6, 0), w - 0.1, 0.0)


## A laundry line `length` long along local x between two posts: yukata, towels and
## cloths airing in the sun.
static func laundry_line(b: Batch, length: float) -> void:
	for x in [-0.5, 0.5]:
		b.cyl(Vector3(x * length, 1.1, 0), 0.07, 2.2, WOOD_DARK, Vector3.ZERO, 6)
	b.box(Vector3(0, 2.05, 0), Vector3(length, 0.03, 0.03), Color("3a3028"))
	var cloth := [Color("2f4f8a"), Color("f4f0e6"), Color("e87aa0"), Color("f6d35a"), Color("4a8f5c"), Color("f4f0e6")]
	var n := int(length / 0.85)
	for i in n:
		var x := -length * 0.5 + (i + 0.6) * length / (n + 0.2)
		var h := 0.8 if i % 3 == 0 else 0.55
		b.box(Vector3(x, 2.02 - h * 0.5, 0), Vector3(0.6, h, 0.03), cloth[i % cloth.size()], Vector3(0, 0, (i % 2) * 4.0 - 2.0))


## A koi channel `length` long along local z: stone kerbs, clear water, koi, lily pads.
static func koi_channel(b: Batch, length: float, width := 1.3) -> void:
	b.box(Vector3(0, 0.08, 0), Vector3(width, 0.12, length), Color("2f5f7a"))
	b.box(Vector3(0, 0.17, 0), Vector3(width, 0.04, length), Color("5aaed0"))
	for s in [-1.0, 1.0]:
		b.box(Vector3(s * (width * 0.5 + 0.2), 0.2, 0), Vector3(0.4, 0.4, length + 0.4), STONE)
	var n := int(length / 2.2)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		var x := (float((i * 37) % 7) / 6.0 - 0.5) * width * 0.6
		if i % 3 == 1:
			b.cyl(Vector3(x, 0.2, z), 0.22, 0.02, Color("4f8a3c"), Vector3.ZERO, 8)
		else:
			b.box(Vector3(x, 0.19, z), Vector3(0.14, 0.04, 0.42), [Color("f08a3a"), Color("f4f0e6"), Color("e8463a")][i % 3], Vector3(0, (i * 41) % 60 - 30, 0))


## A prayer rack at a shrine: ema plaques (wood) or omikuji fortunes (white paper knots).
static func prayer_rack(b: Batch, plaque: Color) -> void:
	for x in [-1.1, 1.1]:
		b.box(Vector3(x, 0.95, 0), Vector3(0.14, 1.9, 0.14), WOOD_DARK)
	b.roof(Vector3(0, 1.95, 0), 2.7, 0.8, 0.3, TILE_DARK, 0.0)
	for row in 3:
		var y := 0.85 + row * 0.38
		b.box(Vector3(0, y + 0.1, 0), Vector3(2.2, 0.04, 0.04), WOOD)
		for i in 9:
			b.box(Vector3(-0.96 + i * 0.24, y, 0.03 * ((i + row) % 2)), Vector3(0.18, 0.14, 0.02), plaque.darkened(0.05 * ((i + row) % 3)))


## A big festival drum (taiko) on its wooden stand.
static func taiko(b: Batch) -> void:
	for x in [-0.45, 0.45]:
		b.box(Vector3(x, 0.55, 0), Vector3(0.1, 1.1, 0.9), WOOD_DARK)
	b.cyl(Vector3(0, 1.2, 0), 0.62, 0.75, Color("8a3a2a"), Vector3(90, 0, 0), 12)
	for z in [-0.38, 0.38]:
		b.cyl(Vector3(0, 1.2, z), 0.6, 0.02, Color("f0e6d0"), Vector3(90, 0, 0), 12)
	b.box(Vector3(0, 1.84, 0), Vector3(0.9, 0.08, 0.08), GOLD)


## Stacked firewood under a little lean-to roof, a barrel either side.
static func woodpile(b: Batch, w: float) -> void:
	for row in 3:
		for i in int(w / 0.3):
			b.cyl(Vector3(-w * 0.5 + 0.15 + i * 0.3 + (row % 2) * 0.12, 0.15 + row * 0.27, 0), 0.14, 0.9, Color("9a7048") if (i + row) % 2 else Color("b0864f"), Vector3(90, 0, 0), 6)
	b.box(Vector3(0, 1.05, 0), Vector3(w + 0.3, 0.08, 1.2), TILE_DARK, Vector3(-12, 0, 0))
	for x in [-0.5, 0.5]:
		b.cyl(Vector3(x * (w + 1.4), 0.45, 0.2), 0.36, 0.9, Color("7a5a38"), Vector3.ZERO, 8)
		b.cyl(Vector3(x * (w + 1.4), 0.62, 0.2), 0.37, 0.06, Color("3a3028"), Vector3.ZERO, 8)
