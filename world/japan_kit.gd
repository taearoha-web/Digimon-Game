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
	## Applied to everything added (a building's position and turn).
	var xform := Transform3D.IDENTITY

	func add(mesh_arrays: Array, local: Transform3D, color: Color, glow := false) -> void:
		var t := xform * local
		var verts: PackedVector3Array = t * (mesh_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		var nb := Transform3D(t.basis.inverse().transposed(), Vector3.ZERO)
		var normals: PackedVector3Array = nb * (mesh_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		var src_idx: PackedInt32Array = mesh_arrays[Mesh.ARRAY_INDEX]
		var flip := t.basis.determinant() < 0.0
		var dv := _glow_verts if glow else _verts
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
		if glow:
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

	## A hipped roof: a four-sided frustum over [param w] x [param d] (its ridge
	## length set by [param ridge], 0..1 of the width), turned by [param yaw].
	func roof(pos: Vector3, w: float, d: float, h: float, color: Color, ridge := 0.35, yaw := 0.0) -> void:
		var key := "roof%d" % int(ridge * 100.0)
		add(JapanKit.arrays(key), JapanKit.place(pos, Vector3(w, h, d), Vector3(0, yaw, 0)), color)

	func is_empty() -> bool:
		return _verts.is_empty() and _glow_verts.is_empty()

	## Adds the mesh to [param parent] (cast shadows unless [param shadows] is false).
	func commit(parent: Node3D, node_name: String, shadows := true) -> MeshInstance3D:
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
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 95.0 * GameSettings.view_scale()
		parent.add_child(mi)
		return mi


static var _arrays: Dictionary = {}
static var _solid: StandardMaterial3D
static var _glow: StandardMaterial3D


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
static func shop(b: Batch, w: float, d: float, noren: Color, sign_color := WOOD_DARK, floors := 2) -> void:
	house(b, w, d, 2.8, TILE, floors)
	var front := d * 0.5 + 0.06
	# Open counter with goods.
	b.box(Vector3(-w * 0.22, 1.25, front + 0.02), Vector3(w * 0.4, 1.4, 0.06), WOOD_DARK)
	b.box(Vector3(-w * 0.22, 1.0, front + 0.45), Vector3(w * 0.42, 0.14, 0.8), WOOD_LIGHT)
	for i in 4:
		b.ball(Vector3(-w * 0.36 + i * w * 0.09, 1.18, front + 0.45), Vector3(0.32, 0.26, 0.32), [Color("e8a040"), Color("c8d070"), Color("e86a5a"), Color("f0e0b0")][i])
	# Noren: split cloth strips over the doorway with a white crest.
	for i in 4:
		b.box(Vector3(w * 0.2 + (i - 1.5) * 0.42, 2.45, front + 0.12), Vector3(0.38, 1.0, 0.04), noren)
	b.ball(Vector3(w * 0.2, 2.55, front + 0.16), Vector3(0.45, 0.45, 0.04), Color("fff6e8"))
	b.box(Vector3(w * 0.2, 2.98, front + 0.12), Vector3(1.8, 0.07, 0.07), WOOD_DARK)
	# Sign board on the eave.
	b.box(Vector3(0, 3.55, front + 0.3), Vector3(w * 0.5, 0.6, 0.12), sign_color)
	b.box(Vector3(0, 3.55, front + 0.37), Vector3(w * 0.42, 0.42, 0.02), GOLD.darkened(0.15))


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
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			b.box(pos + Vector3(x * 0.24, 1.58, z * 0.24) * s, Vector3(0.08, 0.52, 0.08) * s, STONE)
	b.roof(pos + Vector3(0, 2.05, 0) * s, 1.1 * s, 1.1 * s, 0.45 * s, STONE, 0.0)
	b.ball(pos + Vector3(0, 2.36, 0) * s, Vector3(0.2, 0.26, 0.2) * s, STONE)


## A paper lantern (chochin) hanging at [param pos].
static func chochin(b: Batch, pos: Vector3, color := Color("e8463a"), size := 1.0) -> void:
	b.ball(pos, Vector3(0.42, 0.58, 0.42) * size, color.lightened(0.15), true)
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
	b.box(pos + Vector3(0.38, 2.6, 0), Vector3(0.7, 2.8, 0.03), color)
	b.box(pos + Vector3(0.38, 4.0, 0), Vector3(0.8, 0.05, 0.05), WOOD_DARK)
	b.box(pos + Vector3(0.38, 2.6, 0.02), Vector3(0.22, 2.2, 0.01), Color("fff6e0"))


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


static func water(parent: Node3D, pos: Vector3, radius: Vector2) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.05
	disc.radial_segments = 28
	mi.mesh = disc
	mi.scale = Vector3(radius.x, 1.0, radius.y)
	mi.position = pos + Vector3(0, 0.06, 0)
	mi.material_override = MeshKit.toon(Color(0.42, 0.66, 0.78, 0.82), {"alpha": 0.82})
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
