class_name SpecialStageArt
extends RefCounted
## Architecture and ground treatments for the special combat stages. Every
## raised vertex is outside the playable radius (52 m); no colliders, scripts,
## lights or particle emitters are added. Geometry is batched into 2–4 meshes.

const FLOOR_SHADER := preload("res://shaders/special_stage_floor.gdshader")
const FLOOR_RADIUS := 54.5
const STONE := Color("aaa798")
const SHADOW_STONE := Color("777c74")
static var _vertex_material: StandardMaterial3D


static func build(parent: Node3D, stage: StringName) -> void:
	if stage not in [&"tower", &"arena"]:
		return
	if parent.has_node("SpecialStageArt"):
		return
	GameSettings.load_settings()
	var root := Node3D.new()
	root.name = "SpecialStageArt"
	root.set_meta("stage", String(stage))
	root.set_meta("visual_only", true)
	parent.add_child(root)
	_floor(root, stage)
	if stage == &"tower":
		_tower(root)
	else:
		_garden_arena(root)


static func _floor(parent: Node3D, stage: StringName) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 128:
		var a := TAU * float(i) / 128.0
		var b := TAU * float(i + 1) / 128.0
		st.set_normal(Vector3.UP)
		for p in [Vector3.ZERO, Vector3(cos(b), 0, sin(b)) * FLOOR_RADIUS, Vector3(cos(a), 0, sin(a)) * FLOOR_RADIUS]:
			st.add_vertex(p)
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	var tower := stage == &"tower"
	mat.set_shader_parameter("surface_kind", 0 if tower else 1)
	mat.set_shader_parameter("base_color", Color("746b88") if tower else Color("bda47b"))
	mat.set_shader_parameter("accent_color", Color("b6a2c9") if tower else Color("718865"))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "WornInlaidFloor" if tower else "WeatheredGardenSand"
	floor_mesh.mesh = st.commit()
	floor_mesh.material_override = mat
	floor_mesh.position.y = 0.014
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor_mesh)


static func _tower(parent: Node3D) -> void:
	var st := _surface()
	var stone := Color("6b667e")
	var light_stone := Color("9990a9")
	var trim := Color("b7a5c5")
	# Unequal, partially collapsed vaults make a tower courtyard silhouette.
	# East/west gateways remain open. The nearest geometry is beyond 55 m.
	var angles := [-2.63, -2.06, -1.52, -0.97, -0.44, 0.49, 1.04, 1.67, 2.28, 2.73]
	var count := 6 if GameSettings.quality == 0 else angles.size()
	for i in count:
		var angle: float = angles[i * angles.size() / count]
		var at := Vector3(cos(angle), 0, sin(angle)) * (59.0 + float(i % 3) * 1.4)
		var basis := Basis(Vector3.UP, PI * 0.5 - angle)
		var frame := Transform3D(basis, at)
		var height := 9.0 + float((i * 3) % 5) * 1.25
		_box(st, frame, Vector3(0, 0.30, 0), Vector3(8.6, 0.6, 3.0), stone.darkened(0.10))
		for side in [-1.0, 1.0]:
			var x: float = side * 3.1
			_box(st, frame, Vector3(x, 0.88, 0), Vector3(2.2, 0.56, 2.2), light_stone)
			_column(st, frame, Vector3(x, 1.16, 0), 0.80, height - 1.2, stone, 6)
			_box(st, frame, Vector3(x, height - 0.22, 0), Vector3(2.0, 0.40, 2.0), trim)
			_box(st, frame, Vector3(x, 3.35, -0.84), Vector3(0.13, 3.4, 0.08), trim.darkened(0.13))
		# Every third vault is broken; gaps are deliberate rather than copies.
		for j in 9:
			if i % 3 == 1 and j in [3, 4, 5]:
				continue
			var a := PI * float(j) / 8.0
			var point := Vector3(cos(a) * 3.1, height + sin(a) * 3.1, 0)
			var arch_frame := frame * Transform3D(Basis(Vector3.FORWARD, a - PI * 0.5), point)
			_box(st, arch_frame, Vector3.ZERO, Vector3(1.27, 1.35, 1.55), light_stone if j % 3 else trim)
		# Short external ribs and fallen masonry add scale beneath the vault.
		_box(st, frame, Vector3(-4.5, 1.7, 1.0), Vector3(1.6, 3.4 + float(i % 2), 2.4), stone)
		_box(st, frame, Vector3(4.2, 0.42, 1.5), Vector3(2.0, 0.84, 1.6), light_stone.darkened(0.18))
	_commit(parent, st, "BrokenVaults", true)
	# A second, taller silhouette gives the stage a sense of enclosed height.
	var backdrop := _surface()
	for i in 7:
		var angle := -2.86 + float(i) * 0.40
		var frame := Transform3D(Basis(Vector3.UP, -angle), Vector3(cos(angle), 0, sin(angle)) * 76.0)
		_column(backdrop, frame, Vector3.ZERO, 2.7, 18.0 + float(i % 4) * 3.0, Color("665f7a"), 7)
		_box(backdrop, frame, Vector3(0, 1.0, 0), Vector3(7, 2, 6), Color("777086"))
	_commit(parent, backdrop, "DistantTowerButtresses", false)


static func _garden_arena(parent: Node3D) -> void:
	var masonry := _surface()
	var planting := _surface()
	var art_rng := RandomNumberGenerator.new()
	art_rng.seed = 86412
	var groups := 8 if GameSettings.quality == 0 else 12
	for i in groups:
		var angle := (float(i) + 0.5) / float(groups) * TAU
		# Three shallow tiers of ruin, with open approaches on the X axis.
		if absf(sin(angle)) < 0.25:
			continue
		var at := Vector3(cos(angle), 0, sin(angle)) * 60.0
		var frame := Transform3D(Basis(Vector3.UP, PI * 0.5 - angle), at)
		for tier in 3:
			var tint := SHADOW_STONE.lerp(STONE, float(tier) * 0.24)
			for block in 3:
				if tier == 2 and (block + i) % 4 == 0:
					continue
				_box(masonry, frame, Vector3((block - 1) * 3.2, 0.5 + tier * 0.62, 1.2 + tier * 1.8), Vector3(3.05, 1.0 + tier * 1.24, 1.72), tint)
		# Weathered stone planters are embedded into the inner terrace edge.
		_box(masonry, frame, Vector3(0, 0.65, -0.55), Vector3(4.8, 1.3, 1.55), STONE)
		_box(masonry, frame, Vector3(0, 1.30, -0.55), Vector3(4.9, 0.18, 1.7), STONE.lightened(0.09))
		_box(masonry, frame, Vector3(0, 1.41, -0.55), Vector3(4.2, 0.04, 1.14), Color("5e6351"))
		for plant in (3 if GameSettings.quality == 0 else 5):
			var p := Vector3(art_rng.randf_range(-1.95, 1.95), 1.34, art_rng.randf_range(-1.05, -0.05))
			_bush(planting, frame, p, art_rng.randf_range(0.72, 1.15), Color("64805a"), art_rng)
			if plant % 2 == 0:
				_blossom(planting, frame, p + Vector3(0, 0.72, 0), Color("d4a0b1") if i % 2 == 0 else Color("e5c894"))
		# Occasional vine-covered broken posts break the horizontal silhouette.
		if i % 2 == 0:
			_column(masonry, frame, Vector3(-5.0, 0, 3.4), 0.82, 4.1 + i % 3, STONE.darkened(0.03), 7)
			_box(masonry, frame, Vector3(-5.0, 4.1 + i % 3, 3.4), Vector3(2.3, 0.35, 2.2), STONE.lightened(0.08))
			_bush(planting, frame, Vector3(-5.1, 0.0, 2.9), 1.6, Color("63805c"), art_rng)
		# Groundcover islands make the transition from arena to wild vegetation.
		for patch in 2:
			_bush(planting, frame, Vector3(art_rng.randf_range(-5.1, 5.1), -0.15, art_rng.randf_range(-2.7, -1.6)), 0.85, Color("7c9167"), art_rng)
	_commit(parent, masonry, "GardenAmphitheaterMasonry", true)
	_commit(parent, planting, "PlantedTerraces", false)


## Keep the existing coliseum, inlaid emblem, spawn marks and crowd. Its opaque
## floor surfaces receive subtle colour wear without an extra overlay/draw call.
static func decorate_pvp(parent: Node3D) -> void:
	var floor_root := parent.get_node_or_null("ArenaFloor")
	if floor_root == null:
		return
	var materials: Dictionary = {}
	for child in floor_root.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var previous := mesh.material_override as StandardMaterial3D
		if previous == null or previous.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if mesh.scale.y > 0.25:
			continue
		var key := previous.albedo_color.to_html()
		if not materials.has(key):
			var mat := ShaderMaterial.new()
			mat.shader = FLOOR_SHADER
			mat.set_shader_parameter("surface_kind", 2)
			mat.set_shader_parameter("base_color", previous.albedo_color)
			materials[key] = mat
		mesh.material_override = materials[key]


static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal((b - a).cross(c - a).normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


static func _box(st: SurfaceTool, frame: Transform3D, at: Vector3, size: Vector3, color: Color) -> void:
	var points: Array[Vector3] = []
	for i in 8:
		points.append(frame * (at + Vector3(1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0) * size * 0.5))
	for face in [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]:
		_triangle(st, points[face[0]], points[face[1]], points[face[2]], color)
		_triangle(st, points[face[0]], points[face[2]], points[face[3]], color)


static func _column(st: SurfaceTool, frame: Transform3D, at: Vector3, radius: float, height: float, color: Color, sides: int) -> void:
	for i in sides:
		var a := TAU * float(i) / sides
		var b := TAU * float(i + 1) / sides
		var bottom_a := at + Vector3(cos(a) * radius, 0, sin(a) * radius)
		var bottom_b := at + Vector3(cos(b) * radius, 0, sin(b) * radius)
		var top_a := at + Vector3(cos(a) * radius * 0.82, height, sin(a) * radius * 0.82)
		var top_b := at + Vector3(cos(b) * radius * 0.82, height, sin(b) * radius * 0.82)
		var tint := color.lightened(float(i % 3) * 0.028)
		_triangle(st, frame * bottom_a, frame * top_a, frame * top_b, tint)
		_triangle(st, frame * bottom_a, frame * top_b, frame * bottom_b, tint)
		_triangle(st, frame * (at + Vector3.UP * height), frame * top_b, frame * top_a, color.lightened(0.05))


static func _bush(st: SurfaceTool, frame: Transform3D, at: Vector3, size: float, color: Color, art_rng: RandomNumberGenerator) -> void:
	# Three overlapping low lobes, all in one opaque mesh, anchor planters.
	for lobe in 3:
		var center := at + Vector3((lobe - 1) * size * 0.42, size * 0.30, art_rng.randf_range(-0.12, 0.12))
		var height := size * art_rng.randf_range(0.45, 0.7)
		var tint := color.lightened(float(lobe) * 0.055)
		for i in 7:
			var a := TAU * float(i) / 7.0
			var b := TAU * float(i + 1) / 7.0
			var pa := center + Vector3(cos(a) * size * 0.6, 0, sin(a) * size * 0.55)
			var pb := center + Vector3(cos(b) * size * 0.6, 0, sin(b) * size * 0.55)
			_triangle(st, frame * pa, frame * (center + Vector3.UP * height), frame * pb, tint)
			_triangle(st, frame * pb, frame * (center - Vector3.UP * height * 0.65), frame * pa, color.darkened(0.06))


static func _blossom(st: SurfaceTool, frame: Transform3D, at: Vector3, color: Color) -> void:
	for i in 5:
		var a := TAU * float(i) / 5.0
		var pa := at + Vector3(cos(a), 0.06, sin(a)) * 0.25
		var pb := at + Vector3(cos(a + 0.7), -0.04, sin(a + 0.7)) * 0.21
		_triangle(st, frame * at, frame * pa, frame * pb, color)


static func _commit(parent: Node3D, st: SurfaceTool, title: String, shadows: bool) -> void:
	if _vertex_material == null:
		_vertex_material = StandardMaterial3D.new()
		_vertex_material.vertex_color_use_as_albedo = true
		_vertex_material.vertex_color_is_srgb = true
		_vertex_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_vertex_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_vertex_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_vertex_material.roughness = 1.0
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = st.commit()
	instance.material_override = _vertex_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and GameSettings.quality > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
