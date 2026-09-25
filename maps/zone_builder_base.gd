class_name ZoneBuilderBase
extends Node3D
## Shared toolkit for procedural zone scenery (template method pattern).
##
## Subclasses implement [method get_height], [method _ground_color] and
## [method _build_scenery]; this base builds the terrain mesh + collision,
## the map boundary, and offers scatter / MultiMesh / collider helpers.
## Everything with collision is added under this node so a parent
## NavigationRegion3D can bake a navmesh from it.

signal built()

@export var seed_value := 1

var terrain_size := 200.0
var terrain_cell := 2.0
var play_radius := 72.0
## Node names hidden on Low graphics quality (purely decorative).
var decorative_nodes: Array[String] = ["Grass", "Flowers"]
## Walkable paths (polylines on the XZ plane) used for flattening/colouring.
var paths: Array[PackedVector2Array] = []

var _rng := RandomNumberGenerator.new()
var _occupied: Array[Vector3] = [] # x, z, radius
var _ground_material: StandardMaterial3D


func build() -> void:
	_rng.seed = seed_value
	add_to_group("quality_listeners")
	# Keep gameplay objects (NPCs, pickups, signs…) clear of trees and rocks.
	for node in get_tree().get_nodes_in_group("keep_clear"):
		if node is Node3D and node.is_inside_tree():
			var p := (node as Node3D).global_position
			_occupy(Vector2(p.x, p.z), float(node.get_meta("clear_radius", 2.5)))
	_ground_material = _vertex_color_material()
	_build_terrain()
	_build_scenery()
	_build_boundary()
	apply_quality(Settings.graphics_quality)
	built.emit()


## Terrain height at (x, z). Override.
func get_height(_x: float, _z: float) -> float:
	return 0.0


## Override: terrain vertex colour.
func _ground_color(_x: float, _z: float, _h: float) -> Color:
	return Color("5fbf57")


## Override: everything except terrain and boundary.
func _build_scenery() -> void:
	pass


func apply_quality(level: int) -> void:
	for node_name in decorative_nodes:
		var node := get_node_or_null(node_name) as Node3D
		if node:
			node.visible = level != Settings.Quality.LOW


# ---------------------------------------------------------------------------
# Terrain & boundary
# ---------------------------------------------------------------------------

func _build_terrain() -> void:
	var count := int(terrain_size / terrain_cell) + 1
	var half := terrain_size * 0.5
	var positions := PackedVector3Array()
	positions.resize(count * count)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in count:
		for ix in count:
			var x := -half + ix * terrain_cell
			var z := -half + iz * terrain_cell
			var h := get_height(x, z)
			var v := Vector3(x, h, z)
			positions[iz * count + ix] = v
			st.set_color(_ground_color(x, z, h))
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(v)
	# Collision faces are built from the same data (not read back from the
	# mesh), so they also work with the headless/dummy renderer.
	var faces := PackedVector3Array()
	faces.resize((count - 1) * (count - 1) * 6)
	var f := 0
	for iz in count - 1:
		for ix in count - 1:
			var i := iz * count + ix
			for idx in [i, i + 1, i + count, i + 1, i + count + 1, i + count]:
				st.add_index(idx)
				faces[f] = positions[idx]
				f += 1
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainMesh"
	terrain.mesh = st.commit()
	terrain.material_override = _ground_material
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	shape.shape = concave
	body.add_child(shape)
	add_child(body)


func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	add_child(body)
	var segments := 64
	var radius := play_radius + 3.0
	for i in segments:
		var ang := (i + 0.5) * TAU / segments
		var pos := Vector3(cos(ang), 0, sin(ang)) * radius
		var shape := _add_box_shape(body, pos + Vector3(0, get_height(pos.x, pos.z) + 4.0, 0), Vector3(1.0, 16.0, TAU * radius / segments + 1.0))
		shape.rotation.y = -ang


# ---------------------------------------------------------------------------
# Geometry queries
# ---------------------------------------------------------------------------

func distance_to_paths(p: Vector2) -> float:
	var best := INF
	for path in paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


func _box_distance(p: Vector2, center: Vector2, extents: Vector2) -> float:
	var d := (p - center).abs() - extents
	return maxf(d.x, d.y)


# ---------------------------------------------------------------------------
# Scatter helpers
# ---------------------------------------------------------------------------

func _occupy(p: Vector2, radius: float) -> void:
	_occupied.append(Vector3(p.x, p.y, radius))


func _is_occupied(p: Vector2, radius: float) -> bool:
	for o in _occupied:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + radius:
			return true
	return false


func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Vertex/instance colours are authored in sRGB like every other colour.
	mat.vertex_color_is_srgb = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], material: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _make_tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var ang := i * PI / 3.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x) * 0.09
		var tip := dir * 0.08 + Vector3(0, 0.55, 0)
		st.set_uv(Vector2(0, 1))
		st.set_normal(Vector3.UP)
		st.add_vertex(-side)
		st.set_uv(Vector2(1, 1))
		st.set_normal(Vector3.UP)
		st.add_vertex(side)
		st.set_uv(Vector2(0.5, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(tip)
	return st.commit()


func _add_box_shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	return shape


func _add_cylinder_shape(body: StaticBody3D, pos: Vector3, radius: float, height: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = pos
	body.add_child(shape)
	return shape


# ---------------------------------------------------------------------------
# Shared "digital world" props
# ---------------------------------------------------------------------------

func _lamp(parent: Node3D, pos: Vector3, glow := UIPalette.CYAN) -> void:
	MeshKit.part(parent, MeshKit.cylinder(), MeshKit.toon(Color("4b5a99")), pos + Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14))
	MeshKit.part(parent, MeshKit.sphere(), MeshKit.toon(glow, {"emission": 1.6}), pos + Vector3(0, 2.5, 0), Vector3(0.45, 0.45, 0.45))


func _data_pillar(pos: Vector3, height: float, tint := Color(0.25, 0.85, 1.0)) -> void:
	var pillar := Node3D.new()
	pillar.name = "DataPillar"
	pillar.position = pos
	add_child(pillar)
	MeshKit.part(pillar, MeshKit.cylinder(), MeshKit.toon(Color("3a4a8c")), Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 1.8))
	var holo := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.8
	mesh.height = height
	mesh.radial_segments = 6
	mesh.cap_top = false
	mesh.cap_bottom = false
	holo.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/data_pillar.gdshader")
	mat.set_shader_parameter("tint", tint)
	holo.material_override = mat
	holo.position = Vector3(0, height * 0.5 + 0.5, 0)
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.add_child(holo)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	pillar.add_child(body)
	_add_cylinder_shape(body, Vector3(0, 1.5, 0), 0.9, 3.0)
	_occupy(Vector2(pos.x, pos.z), 2.0)


func _data_cubes(clusters: Array, per_cluster := 9, palette: Array = [Color(0.3, 0.95, 1.0), Color(1.0, 0.6, 0.35), Color(0.7, 0.55, 1.0)]) -> void:
	var cubes: Array[Transform3D] = []
	var colors: Array[Color] = []
	for c in clusters:
		for i in per_cluster:
			var p: Vector2 = c + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			var s := _rng.randf_range(0.25, 0.55)
			var y := get_height(p.x, p.y) + _rng.randf_range(2.2, 5.0)
			cubes.append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(p.x, y, p.y)))
			colors.append(palette[_rng.randi() % palette.size()])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/data_cube.gdshader")
	_multimesh("DataCubes", MeshKit.box(), cubes, colors, mat, false)


func _sky_islands(count := 5, grass := Color("6cc463"), rock := Color("8a6a4e")) -> void:
	var islands := Node3D.new()
	islands.name = "SkyIslands"
	add_child(islands)
	for i in count:
		var ang := i * TAU / count + 0.4
		var dist := _rng.randf_range(115.0, 135.0)
		var island := Node3D.new()
		island.position = Vector3(cos(ang) * dist, _rng.randf_range(32.0, 52.0), sin(ang) * dist)
		islands.add_child(island)
		var s := _rng.randf_range(6.0, 11.0)
		MeshKit.part(island, MeshKit.cone(), MeshKit.toon(rock), Vector3(0, -s * 0.6, 0), Vector3(s * 1.6, s * 1.4, s * 1.6), Vector3(180, 0, 0))
		MeshKit.part(island, MeshKit.sphere_low(), MeshKit.toon(grass), Vector3.ZERO, Vector3(s * 1.7, s * 0.35, s * 1.7))
		for t in 3:
			var off := Vector3(_rng.randf_range(-s * 0.5, s * 0.5), s * 0.4, _rng.randf_range(-s * 0.5, s * 0.5))
			MeshKit.part(island, MeshKit.sphere_low(), MeshKit.toon(grass.darkened(0.12)), off + Vector3(0, s * 0.3, 0), Vector3.ONE * s * 0.5)
		for child in island.get_children():
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
