class_name StarterZoneBuilder
extends Node3D
## Builds the Starter Zone's static scenery procedurally and deterministically
## (same seed = same world), keeping the .tscn small and editable:
##   terrain (hills, carved river, flattened paths/plazas) + trimesh collision,
##   river surface and bank walls, bridge, forests, rocks, grass & flowers
##   (MultiMesh = few draw calls), digital landmarks, floating islands and
##   map boundary walls.
## Gameplay objects (NPCs, spawners, portal, pickups…) live in the .tscn.
## Everything with collision is added under this node so a parent
## NavigationRegion3D can bake a navmesh from it.

signal built()

const SIZE := 200.0
const CELL := 2.0
const PLAY_RADIUS := 72.0
const RIVER_HALF_WIDTH := 4.2
const RIVER_DEPTH := 1.8
const WATER_Y := -0.6
const BRIDGE_HALF_WIDTH := 2.6

const PLAZA := Vector2(-38, 10)
const PLAZA_RADIUS := 10.0
const TRAINING := Vector2(24, -22)
const TRAINING_RADIUS := 10.5
const MEADOW := Vector2(28, 28)
const MEADOW_EXTENTS := Vector2(16, 12)
const GATEWAY := Vector2(48, -48)
const HILLS := [[Vector2(-26, -38), 15.0, 4.5], [Vector2(-54, 42), 11.0, 3.0], [Vector2(56, 6), 9.0, 2.2]]
const FLAT_ZONES := [[Vector2(-38, 10), 11.0, 0.05], [Vector2(24, -22), 11.5, 0.0], [Vector2(48, -48), 7.0, 0.1]]
const FOREST_ZONES := [[Vector2(-55, -30), 22.0], [Vector2(-52, 30), 18.0], [Vector2(-10, -55), 16.0],
	[Vector2(58, 40), 14.0], [Vector2(20, 55), 14.0], [Vector2(60, -18), 12.0]]

@export var seed_value := 20250925

var paths: Array[PackedVector2Array] = []
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _occupied: Array[Vector3] = [] # x, z, radius of placed props
var _ground_material: StandardMaterial3D


func _init() -> void:
	_noise.seed = 7
	_noise.frequency = 0.035
	_noise.fractal_octaves = 3
	_detail.seed = 11
	_detail.frequency = 0.12
	_define_paths()


func _define_paths() -> void:
	paths = [
		PackedVector2Array([Vector2(-38, 10), Vector2(-26, 6), Vector2(-14, 2), Vector2(-5, 0)]),
		PackedVector2Array([Vector2(9, 0), Vector2(16, 0)]),
		PackedVector2Array([Vector2(16, 0), Vector2(20, -8), Vector2(24, -14)]),
		PackedVector2Array([Vector2(16, 0), Vector2(22, 10), Vector2(27, 17)]),
		PackedVector2Array([Vector2(29, -29), Vector2(38, -38), Vector2(46, -45)]),
		PackedVector2Array([Vector2(-38, 1), Vector2(-33, -14), Vector2(-28, -26)]),
		PackedVector2Array([Vector2(-47, 10), Vector2(-60, 12)]),
	]


static func river_x(z: float) -> float:
	return 2.0 + 5.0 * sin(z * 0.045)


func build() -> void:
	_rng.seed = seed_value
	add_to_group("quality_listeners")
	# Keep gameplay objects (NPCs, pickups, signs…) clear of trees and rocks.
	for node in get_tree().get_nodes_in_group("keep_clear"):
		if node is Node3D:
			var p := (node as Node3D).global_position
			_occupy(Vector2(p.x, p.z), float(node.get_meta("clear_radius", 2.5)))
	_ground_material = StandardMaterial3D.new()
	_ground_material.vertex_color_use_as_albedo = true
	# Vertex colours are authored in sRGB like every other colour in the project.
	_ground_material.vertex_color_is_srgb = true
	_ground_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_ground_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_ground_material.roughness = 1.0
	_build_terrain()
	_build_river()
	_build_bridge()
	_build_plaza()
	_build_training_grounds()
	_build_gateway_area()
	_build_trees()
	_build_rocks()
	_build_grass_and_flowers()
	_build_data_cubes()
	_build_sky_islands()
	_build_boundary()
	apply_quality(Settings.graphics_quality)
	built.emit()


## Low quality hides purely decorative foliage to save fill-rate.
func apply_quality(level: int) -> void:
	for node_name in ["Grass", "Flowers"]:
		var node := get_node_or_null(node_name) as Node3D
		if node:
			node.visible = level != Settings.Quality.LOW


# ---------------------------------------------------------------------------
# Height field
# ---------------------------------------------------------------------------

func get_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _noise.get_noise_2d(x, z) * 0.6 + _detail.get_noise_2d(x, z) * 0.12
	var r := p.length()
	h += smoothstep(PLAY_RADIUS - 6.0, PLAY_RADIUS + 20.0, r) * (15.0 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 6.0)
	for hill in HILLS:
		var d := p.distance_to(hill[0])
		if d < hill[1]:
			h += hill[2] * smoothstep(hill[1], 0.0, d)
	for zone in FLAT_ZONES:
		var d := p.distance_to(zone[0])
		if d < zone[1] + 4.0:
			h = lerpf(h, zone[2], 1.0 - smoothstep(zone[1], zone[1] + 4.0, d))
	var path_d := distance_to_paths(p)
	if path_d < 5.0:
		h = lerpf(h, minf(h, 0.05) * 0.3, 1.0 - smoothstep(2.5, 5.0, path_d))
	var rd := absf(x - river_x(z))
	var channel := 1.0 - smoothstep(RIVER_HALF_WIDTH - 0.8, RIVER_HALF_WIDTH + 1.6, rd)
	h = lerpf(h, -RIVER_DEPTH, channel)
	return h


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


func _ground_color(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var n := _noise.get_noise_2d(x * 1.7 + 40.0, z * 1.7)
	var grass := Color("5fbf57").lerp(Color("86d46a"), clampf(n * 0.9 + 0.5, 0.0, 1.0))
	var meadow_d := _box_distance(p, MEADOW, MEADOW_EXTENTS)
	if meadow_d < 3.0:
		grass = grass.lerp(Color("4aa851"), 1.0 - smoothstep(0.0, 3.0, meadow_d))
	var c := grass
	# Mountains: darker then rocky.
	c = c.lerp(Color("4c8f4f"), smoothstep(2.0, 6.0, h))
	c = c.lerp(Color("8792ad"), smoothstep(7.0, 13.0, h))
	var path_d := distance_to_paths(p)
	c = c.lerp(Color("e3c68d"), 1.0 - smoothstep(1.8, 3.2, path_d))
	if p.distance_to(TRAINING) < TRAINING_RADIUS + 1.0:
		c = c.lerp(Color("e8d29a"), 1.0 - smoothstep(TRAINING_RADIUS - 1.0, TRAINING_RADIUS + 1.0, p.distance_to(TRAINING)))
	if p.distance_to(PLAZA) < PLAZA_RADIUS + 2.0:
		c = c.lerp(Color("c7cde0"), 1.0 - smoothstep(PLAZA_RADIUS - 1.0, PLAZA_RADIUS + 2.0, p.distance_to(PLAZA)))
	var rd := absf(x - river_x(z))
	if rd < RIVER_HALF_WIDTH + 2.4:
		c = c.lerp(Color("dcc690"), 1.0 - smoothstep(RIVER_HALF_WIDTH + 0.8, RIVER_HALF_WIDTH + 2.4, rd))
	if h < -0.8:
		c = c.lerp(Color("2f7c8c"), smoothstep(-0.8, -1.6, h))
	return c


func _box_distance(p: Vector2, center: Vector2, extents: Vector2) -> float:
	var d := (p - center).abs() - extents
	return maxf(d.x, d.y)


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func _build_terrain() -> void:
	var count := int(SIZE / CELL) + 1
	var half := SIZE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in count:
		for ix in count:
			var x := -half + ix * CELL
			var z := -half + iz * CELL
			var h := get_height(x, z)
			st.set_color(_ground_color(x, z, h))
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, h, z))
	for iz in count - 1:
		for ix in count - 1:
			var i := iz * count + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + count)
			st.add_index(i + 1)
			st.add_index(i + count + 1)
			st.add_index(i + count)
	st.generate_normals()
	var mesh := st.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainMesh"
	terrain.mesh = mesh
	terrain.material_override = _ground_material
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


# ---------------------------------------------------------------------------
# River + bridge
# ---------------------------------------------------------------------------

func _build_river() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := RIVER_HALF_WIDTH + 0.9
	var z0 := -100.0
	var steps := 100
	for i in steps + 1:
		var z := z0 + i * 2.0
		var cx := river_x(z)
		var v := float(i) / steps
		st.set_uv(Vector2(0.0, v * 20.0))
		st.add_vertex(Vector3(cx - width, WATER_Y, z))
		st.set_uv(Vector2(1.0, v * 20.0))
		st.add_vertex(Vector3(cx + width, WATER_Y, z))
	for i in steps:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 3)
	st.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "River"
	water.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	# Invisible walls along both banks (open where the bridge crosses).
	var walls := StaticBody3D.new()
	walls.name = "RiverWalls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var z := -98.0
	while z < 98.0:
		if absf(z + 2.0) > BRIDGE_HALF_WIDTH + 0.3 and Vector2(river_x(z + 2.0), z + 2.0).length() < PLAY_RADIUS + 6.0:
			for side in [-1.0, 1.0]:
				var zc := z + 2.0
				var tangent := Vector2(river_x(zc + 0.1) - river_x(zc - 0.1), 0.2).normalized()
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.5, 4.0, 4.4)
				shape.shape = box
				shape.position = Vector3(river_x(zc) + side * (RIVER_HALF_WIDTH + 0.3), 0.6, zc)
				shape.rotation.y = atan2(tangent.x, tangent.y)
				walls.add_child(shape)
		z += 4.0


func _build_bridge() -> void:
	var cx := river_x(0.0)
	var length := (RIVER_HALF_WIDTH + 3.0) * 2.0
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	bridge.position = Vector3(cx, 0.0, 0.0)
	add_child(bridge)
	var plank_a := MeshKit.toon(Color("b07a4a"))
	var plank_b := MeshKit.toon(Color("9a6a40"))
	var rail := MeshKit.toon(Color("7a5030"))
	var count := int(length / 0.8)
	for i in count:
		var x := -length * 0.5 + (i + 0.5) * (length / count)
		MeshKit.part(bridge, MeshKit.box(), plank_a if i % 2 == 0 else plank_b, Vector3(x, 0.12, 0), Vector3(length / count - 0.05, 0.22, BRIDGE_HALF_WIDTH * 2.0))
	for side in [-1.0, 1.0]:
		for i in 7:
			var x := -length * 0.5 + i * (length / 6.0)
			MeshKit.part(bridge, MeshKit.cylinder(), rail, Vector3(x, 0.6, side * (BRIDGE_HALF_WIDTH - 0.1)), Vector3(0.18, 1.0, 0.18))
		MeshKit.part(bridge, MeshKit.box(), rail, Vector3(0, 1.05, side * (BRIDGE_HALF_WIDTH - 0.1)), Vector3(length, 0.12, 0.14))
	var body := StaticBody3D.new()
	body.name = "BridgeBody"
	body.collision_layer = 1
	bridge.add_child(body)
	_add_box_shape(body, Vector3(0, 0.05, 0), Vector3(length + 1.0, 0.4, BRIDGE_HALF_WIDTH * 2.0))
	for side in [-1.0, 1.0]:
		_add_box_shape(body, Vector3(0, 0.8, side * (BRIDGE_HALF_WIDTH + 0.05)), Vector3(length - 1.0, 1.6, 0.3))


# ---------------------------------------------------------------------------
# Landmarks
# ---------------------------------------------------------------------------

func _build_plaza() -> void:
	var plaza := Node3D.new()
	plaza.name = "StartPlaza"
	plaza.position = Vector3(PLAZA.x, get_height(PLAZA.x, PLAZA.y), PLAZA.y)
	add_child(plaza)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = PLAZA_RADIUS - 1.0
	floor_mesh.bottom_radius = PLAZA_RADIUS - 0.8
	floor_mesh.height = 0.2
	floor_mesh.radial_segments = 48
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	var grid := ShaderMaterial.new()
	grid.shader = load("res://shaders/grid_floor.gdshader")
	floor_mi.material_override = grid
	floor_mi.position = Vector3(0, 0.08, 0)
	plaza.add_child(floor_mi)
	# Central monument: an original "data egg" crystal on a pedestal.
	MeshKit.part(plaza, MeshKit.cylinder(), MeshKit.toon(Color("dfe5f5")), Vector3(0, 0.45, 0), Vector3(2.2, 0.7, 2.2))
	MeshKit.part(plaza, MeshKit.cylinder(), MeshKit.toon(Color("9aa6cf")), Vector3(0, 0.9, 0), Vector3(1.6, 0.2, 1.6))
	var egg := MeshKit.part(plaza, MeshKit.sphere(), MeshKit.toon(Color("ffd166"), {"emission": 0.9}), Vector3(0, 2.1, 0), Vector3(1.3, 1.8, 1.3))
	egg.name = "DataEgg"
	for i in 3:
		var ang := i * TAU / 3.0
		MeshKit.part(plaza, MeshKit.torus(), MeshKit.toon(UIPalette.CYAN, {"emission": 1.2}), Vector3(0, 1.4 + i * 0.6, 0), Vector3(2.2 - i * 0.4, 0.3, 2.2 - i * 0.4), Vector3(8 * cos(ang), 0, 8 * sin(ang)))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	plaza.add_child(body)
	_add_cylinder_shape(body, Vector3(0, 1.5, 0), 1.2, 3.0)
	_occupy(PLAZA, 2.0)
	# Lamps and benches around the ring.
	for i in 6:
		var ang := i * TAU / 6.0 + 0.3
		var pos := Vector3(cos(ang), 0, sin(ang)) * (PLAZA_RADIUS - 1.8)
		if i % 2 == 0:
			_lamp(plaza, pos)
		else:
			_bench(plaza, pos, -ang)
	# Holographic data pillars.
	for p in [Vector2(-48, 4), Vector2(-48, 16), Vector2(-28, 18)]:
		_data_pillar(Vector3(p.x, get_height(p.x, p.y), p.y), 9.0)


func _build_training_grounds() -> void:
	var tg := Node3D.new()
	tg.name = "TrainingGrounds"
	tg.position = Vector3(TRAINING.x, get_height(TRAINING.x, TRAINING.y), TRAINING.y)
	add_child(tg)
	var wood := MeshKit.toon(Color("a36e42"))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	tg.add_child(body)
	var posts := 28
	for i in posts:
		var ang := i * TAU / posts
		# Leave openings toward the west path and the north-east path.
		var dir := Vector2(cos(ang), sin(ang))
		if dir.dot(Vector2(-0.6, 0.8).normalized()) > 0.9 or dir.dot(Vector2(0.7, -0.7).normalized()) > 0.9:
			continue
		var pos := Vector3(dir.x, 0, dir.y) * TRAINING_RADIUS
		MeshKit.part(tg, MeshKit.cylinder(), wood, pos + Vector3(0, 0.6, 0), Vector3(0.22, 1.2, 0.22))
		var next_ang := (i + 1) * TAU / posts
		var next := Vector3(cos(next_ang), 0, sin(next_ang)) * TRAINING_RADIUS
		var next_dir := Vector2(cos(next_ang), sin(next_ang))
		if not (next_dir.dot(Vector2(-0.6, 0.8).normalized()) > 0.9 or next_dir.dot(Vector2(0.7, -0.7).normalized()) > 0.9):
			var mid := (pos + next) * 0.5
			var rail := MeshKit.part(tg, MeshKit.box(), wood, mid + Vector3(0, 0.85, 0), Vector3(pos.distance_to(next), 0.1, 0.1))
			rail.rotation.y = -atan2(next.z - pos.z, next.x - pos.x)
			var shape := _add_box_shape(body, mid + Vector3(0, 0.6, 0), Vector3(pos.distance_to(next), 1.2, 0.3))
			shape.rotation.y = rail.rotation.y
	# Training dummies.
	for p in [Vector3(-4, 0, -3), Vector3(3, 0, -5), Vector3(5, 0, 3)]:
		MeshKit.part(tg, MeshKit.cylinder(), wood, p + Vector3(0, 0.7, 0), Vector3(0.35, 1.4, 0.35))
		MeshKit.part(tg, MeshKit.cylinder(), MeshKit.toon(Color("e0564f")), p + Vector3(0, 1.2, 0.18), Vector3(0.4, 0.05, 0.4), Vector3(90, 0, 0))
		MeshKit.part(tg, MeshKit.cylinder(), MeshKit.toon(Color("ffffff")), p + Vector3(0, 1.2, 0.2), Vector3(0.24, 0.05, 0.24), Vector3(90, 0, 0))
		_add_cylinder_shape(body, p + Vector3(0, 0.7, 0), 0.25, 1.4)
	# Flags
	for p in [Vector3(-2, 0, 9.5), Vector3(8, 0, -6)]:
		MeshKit.part(tg, MeshKit.cylinder(), MeshKit.toon(Color("dddddd")), p + Vector3(0, 1.8, 0), Vector3(0.1, 3.6, 0.1))
		MeshKit.part(tg, MeshKit.box(), MeshKit.toon(UIPalette.ORANGE), p + Vector3(0.45, 3.2, 0), Vector3(0.9, 0.55, 0.04))
	_occupy(TRAINING, TRAINING_RADIUS + 2.0)


func _build_gateway_area() -> void:
	for p in [Vector2(42, -52), Vector2(54, -42)]:
		_data_pillar(Vector3(p.x, get_height(p.x, p.y), p.y), 12.0)
	_occupy(GATEWAY, 7.0)


func _lamp(parent: Node3D, pos: Vector3) -> void:
	MeshKit.part(parent, MeshKit.cylinder(), MeshKit.toon(Color("4b5a99")), pos + Vector3(0, 1.2, 0), Vector3(0.14, 2.4, 0.14))
	MeshKit.part(parent, MeshKit.sphere(), MeshKit.toon(UIPalette.CYAN, {"emission": 1.6}), pos + Vector3(0, 2.5, 0), Vector3(0.45, 0.45, 0.45))


func _bench(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var bench := Node3D.new()
	bench.position = pos
	bench.rotation.y = yaw
	parent.add_child(bench)
	var wood := MeshKit.toon(Color("b07a4a"))
	MeshKit.part(bench, MeshKit.box(), wood, Vector3(0, 0.45, 0), Vector3(1.6, 0.12, 0.5))
	MeshKit.part(bench, MeshKit.box(), wood, Vector3(0, 0.75, -0.22), Vector3(1.6, 0.4, 0.08))
	for x in [-0.65, 0.65]:
		MeshKit.part(bench, MeshKit.box(), MeshKit.toon(Color("4b5a99")), Vector3(x, 0.22, 0), Vector3(0.1, 0.44, 0.45))


func _data_pillar(pos: Vector3, height: float) -> void:
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
	holo.material_override = mat
	holo.position = Vector3(0, height * 0.5 + 0.5, 0)
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.add_child(holo)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	pillar.add_child(body)
	_add_cylinder_shape(body, Vector3(0, 1.5, 0), 0.9, 3.0)
	_occupy(Vector2(pos.x, pos.z), 2.0)


# ---------------------------------------------------------------------------
# Scatter (MultiMesh)
# ---------------------------------------------------------------------------

func _is_clear(p: Vector2, radius: float, path_margin := 4.0) -> bool:
	if p.length() > PLAY_RADIUS + 14.0:
		return false
	if absf(p.x - river_x(p.y)) < RIVER_HALF_WIDTH + 2.5 + radius:
		return false
	if distance_to_paths(p) < path_margin + radius:
		return false
	if p.distance_to(PLAZA) < PLAZA_RADIUS + 3.0 + radius:
		return false
	for o in _occupied:
		if p.distance_to(Vector2(o.x, o.y)) < o.z + radius:
			return false
	return true


func _occupy(p: Vector2, radius: float) -> void:
	_occupied.append(Vector3(p.x, p.y, radius))


func _forest_density(p: Vector2) -> float:
	var density := 0.1
	for zone in FOREST_ZONES:
		var d := p.distance_to(zone[0])
		if d < zone[1]:
			density = maxf(density, 0.85 * smoothstep(zone[1], zone[1] * 0.3, d))
	if p.length() > PLAY_RADIUS - 4.0:
		density = maxf(density, 0.55)
	if _box_distance(p, MEADOW, MEADOW_EXTENTS) < 2.0:
		density = 0.0
	return density


func _build_trees() -> void:
	var round_trees: Array[Transform3D] = []
	var round_colors: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_colors: Array[Color] = []
	var trunks: Array[Transform3D] = []
	var body := StaticBody3D.new()
	body.name = "TreeColliders"
	body.collision_layer = 1
	add_child(body)
	var step := 5.0
	var x := -90.0
	while x <= 90.0:
		var z := -90.0
		while z <= 90.0:
			var p := Vector2(x + _rng.randf_range(-2.2, 2.2), z + _rng.randf_range(-2.2, 2.2))
			z += step
			if _rng.randf() > _forest_density(p):
				continue
			if not _is_clear(p, 1.6, 3.5):
				continue
			var h := get_height(p.x, p.y)
			var s := _rng.randf_range(0.8, 1.35)
			var yaw := _rng.randf() * TAU
			trunks.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.45 * s, 1.8 * s, 0.45 * s)), Vector3(p.x, h + 0.9 * s, p.y)))
			if _rng.randf() < 0.35:
				pines.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(2.6, 3.4, 2.6) * s), Vector3(p.x, h + 3.1 * s, p.y)))
				pine_colors.append(Color("3e8f5a").lerp(Color("56a86a"), _rng.randf()))
			else:
				round_trees.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(2.8, 2.4, 2.8) * s), Vector3(p.x, h + 2.8 * s, p.y)))
				round_colors.append(Color("5db85a").lerp(Color("9ad96b"), _rng.randf()))
			if p.length() < PLAY_RADIUS + 4.0:
				_add_cylinder_shape(body, Vector3(p.x, h + 1.5, p.y), 0.45 * s, 3.0)
			_occupy(p, 1.6 * s)
		x += step
	_multimesh("Trunks", MeshKit.cylinder(), trunks, [], MeshKit.toon(Color("8a5a36")))
	_multimesh("TreeCanopies", MeshKit.sphere_low(), round_trees, round_colors, _vertex_color_material())
	_multimesh("PineCanopies", MeshKit.cone(), pines, pine_colors, _vertex_color_material())


func _build_rocks() -> void:
	var rocks: Array[Transform3D] = []
	var colors: Array[Color] = []
	var body := StaticBody3D.new()
	body.name = "RockColliders"
	body.collision_layer = 1
	add_child(body)
	var placed := 0
	var attempts := 0
	while placed < 70 and attempts < 700:
		attempts += 1
		var p := Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-80, 80))
		if not _is_clear(p, 1.0, 3.0):
			continue
		var h := get_height(p.x, p.y)
		var big := _rng.randf() < 0.3
		var s := _rng.randf_range(1.2, 2.4) if big else _rng.randf_range(0.35, 0.8)
		var basis := Basis.from_euler(Vector3(_rng.randf() * 0.6, _rng.randf() * TAU, _rng.randf() * 0.6)).scaled(Vector3(s * 1.2, s * 0.8, s))
		rocks.append(Transform3D(basis, Vector3(p.x, h + s * 0.2, p.y)))
		colors.append(Color("9aa3b8").lerp(Color("c4cad8"), _rng.randf()))
		if big and p.length() < PLAY_RADIUS + 4.0:
			var shape := CollisionShape3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = s * 0.55
			shape.shape = sphere
			shape.position = Vector3(p.x, h + s * 0.2, p.y)
			body.add_child(shape)
		_occupy(p, s * 0.6)
		placed += 1
	_multimesh("Rocks", MeshKit.sphere_low(), rocks, colors, _vertex_color_material())


func _build_grass_and_flowers() -> void:
	var tuft := _make_tuft_mesh()
	var grass: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var tall: Array[Transform3D] = []
	var tall_colors: Array[Color] = []
	for i in 1200:
		var p := Vector2(_rng.randf_range(-70, 70), _rng.randf_range(-70, 70))
		if not _is_clear(p, 0.2, 2.2) or p.distance_to(TRAINING) < TRAINING_RADIUS:
			continue
		var s := _rng.randf_range(0.5, 1.0)
		grass.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, get_height(p.x, p.y), p.y)))
		grass_colors.append(Color("3f9a44").lerp(Color("5cb85a"), _rng.randf()))
	for i in 900:
		var p := MEADOW + Vector2(_rng.randf_range(-MEADOW_EXTENTS.x, MEADOW_EXTENTS.x), _rng.randf_range(-MEADOW_EXTENTS.y, MEADOW_EXTENTS.y))
		if distance_to_paths(p) < 1.5 or absf(p.x - river_x(p.y)) < RIVER_HALF_WIDTH + 2.0:
			continue
		var s := _rng.randf_range(1.1, 1.8)
		tall.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s * 0.9, s, s * 0.9)), Vector3(p.x, get_height(p.x, p.y), p.y)))
		tall_colors.append(Color("2f8a3f").lerp(Color("47a34d"), _rng.randf()))
	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass_sway.gdshader")
	_multimesh("Grass", tuft, grass, grass_colors, grass_mat, false)
	var tall_mat := ShaderMaterial.new()
	tall_mat.shader = load("res://shaders/grass_sway.gdshader")
	tall_mat.set_shader_parameter("tip_color", Color("7ccf5a"))
	tall_mat.set_shader_parameter("sway", 0.2)
	_multimesh("TallGrass", tuft, tall, tall_colors, tall_mat, false)

	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var palette := [Color("ff8fb1"), Color("ffd166"), Color("ffffff"), Color("b28dff"), Color("ff7a45")]
	for i in 420:
		var p := Vector2(_rng.randf_range(-68, 68), _rng.randf_range(-68, 68))
		if not _is_clear(p, 0.2, 2.0):
			continue
		var s := _rng.randf_range(0.14, 0.24)
		flowers.append(Transform3D(Basis().scaled(Vector3(s, s * 0.7, s)), Vector3(p.x, get_height(p.x, p.y) + 0.18, p.y)))
		flower_colors.append(palette[_rng.randi() % palette.size()])
	_multimesh("Flowers", MeshKit.sphere_low(), flowers, flower_colors, _vertex_color_material(), false)


func _build_data_cubes() -> void:
	var cubes: Array[Transform3D] = []
	var colors: Array[Color] = []
	var clusters := [PLAZA, GATEWAY, TRAINING, Vector2(-26, -38), Vector2(0, 40), Vector2(-60, -10), Vector2(40, 50)]
	for c in clusters:
		for i in 9:
			var p: Vector2 = c + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12))
			var s := _rng.randf_range(0.25, 0.55)
			var y := get_height(p.x, p.y) + _rng.randf_range(2.2, 5.0)
			cubes.append(Transform3D(Basis().scaled(Vector3.ONE * s), Vector3(p.x, y, p.y)))
			colors.append([Color(0.3, 0.95, 1.0), Color(1.0, 0.6, 0.35), Color(0.7, 0.55, 1.0)][_rng.randi() % 3])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/data_cube.gdshader")
	_multimesh("DataCubes", MeshKit.box(), cubes, colors, mat, false)


func _build_sky_islands() -> void:
	var islands := Node3D.new()
	islands.name = "SkyIslands"
	add_child(islands)
	for i in 5:
		var ang := i * TAU / 5.0 + 0.4
		var dist := _rng.randf_range(115.0, 135.0)
		var island := Node3D.new()
		island.position = Vector3(cos(ang) * dist, _rng.randf_range(32.0, 52.0), sin(ang) * dist)
		islands.add_child(island)
		var s := _rng.randf_range(6.0, 11.0)
		MeshKit.part(island, MeshKit.cone(), MeshKit.toon(Color("8a6a4e")), Vector3(0, -s * 0.6, 0), Vector3(s * 1.6, s * 1.4, s * 1.6), Vector3(180, 0, 0))
		MeshKit.part(island, MeshKit.sphere_low(), MeshKit.toon(Color("6cc463")), Vector3(0, 0, 0), Vector3(s * 1.7, s * 0.35, s * 1.7))
		for t in 3:
			var off := Vector3(_rng.randf_range(-s * 0.5, s * 0.5), s * 0.4, _rng.randf_range(-s * 0.5, s * 0.5))
			MeshKit.part(island, MeshKit.sphere_low(), MeshKit.toon(Color("4fae5a")), off + Vector3(0, s * 0.3, 0), Vector3.ONE * s * 0.5)
		for child in island.get_children():
			(child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_boundary() -> void:
	var body := StaticBody3D.new()
	body.name = "Boundary"
	body.collision_layer = 1
	add_child(body)
	var segments := 64
	var radius := PLAY_RADIUS + 3.0
	for i in segments:
		var ang := (i + 0.5) * TAU / segments
		var pos := Vector3(cos(ang), 0, sin(ang)) * radius
		var shape := _add_box_shape(body, pos + Vector3(0, get_height(pos.x, pos.z) + 4.0, 0), Vector3(1.0, 16.0, TAU * radius / segments + 1.0))
		shape.rotation.y = -ang


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
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
