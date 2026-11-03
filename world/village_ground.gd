class_name VillageGround
extends RefCounted
## The town's floor: warm dark-gray Japanese stone paving (shaders/japan_paving.gdshader).
## Streets are running-bond setts along the street with a warm granite kerb on each side,
## the rest of the town square stone plates, the plaza a fan pattern of small granite setts
## (扇張り) inside a granite ring, and a muted yellow tactile guide strip (点字ブロック)
## runs along the main street. Gardens stay grass behind a granite kerb, and outside the
## village the paving gives way to the meadow grass of [method Scenery.ground].
## One mesh, one material, no textures: the stones are drawn per pixel from world
## position, their joints fading with distance so far paving never shimmers.
## The physics floor is the same flat world boundary as Scenery.ground's.

## Grass left inside the village edge for the hedge (metres).
const VERGE := 5.5
## Half the paved width of a street (its kerb lies just outside).
const STREET_HALF := 2.3
## Grid spacing inside the village and in the meadow around it (metres).
const FINE_STEP := 1.25
const COARSE_STEP := 8.0

static var _shader: Shader


## Lays the ground over [-half_size, half_size]² and the flat floor body.
## `village_radius`: the village's radius (paving stops VERGE inside it). `green`: (x, z,
## radius) circles that stay grass (gardens, ponds, fields, groves). `streets`: the street
## centre lines (JapanVillage.paths()); the first one carries the tactile guide strip.
## `plaza`: (x, z, radius) of the fan-paved plaza (radius 0: none).
static func build(parent: Node3D, half_size: float, village_radius: float, green: Array[Vector3],
		streets: Array[PackedVector2Array], plaza := Vector3.ZERO) -> MeshInstance3D:
	var inner := minf(village_radius + 4.0, half_size)
	var xs := _axis(half_size, inner)
	var n := xs.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	uvs.resize(n * n)
	uv2s.resize(n * n)
	colors.resize(n * n)
	for ix in n:
		for iz in n:
			var p := Vector2(xs[ix], xs[iz])
			var k := ix * n + iz
			var street := _street(p, streets)
			verts[k] = Vector3(p.x, 0, p.y)
			normals[k] = Vector3.UP
			uvs[k] = p
			uv2s[k] = Vector2(street.x, paved(p, village_radius, green, streets))
			# The nearest street's direction (its bricks run along it).
			colors[k] = Color(absf(street.y) * 0.5 + 0.5, absf(street.z) * 0.5 + 0.5, 0.0, 1.0)
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var w := 0
	for ix in n - 1:
		for iz in n - 1:
			var a := ix * n + iz
			var b := a + n
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = a + 1
			indices[w + 3] = b
			indices[w + 4] = b + 1
			indices[w + 5] = a + 1
			w += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = material(streets, plaza)
	parent.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	parent.add_child(body)
	return mi


static func material(streets: Array[PackedVector2Array], plaza := Vector3.ZERO) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/japan_paving.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("street_half", STREET_HALF)
	mat.set_shader_parameter("plaza", plaza)
	# The gardens and the meadow beyond keep Scenery.ground's village grass.
	mat.set_shader_parameter("grass_shadow", Color("7e9568").lerp(Color("5c794d"), 0.30))
	mat.set_shader_parameter("grass_sun", Color("a1b586").darkened(0.025))
	mat.set_shader_parameter("accent_color", Scenery.ACCENTS[&"village"][0])
	mat.set_shader_parameter("accent_amount", Scenery.ACCENTS[&"village"][1])
	var guide := Vector4.ZERO
	if not streets.is_empty() and streets[0].size() >= 2:
		var a: Vector2 = streets[0][0]
		var b: Vector2 = streets[0][1]
		guide = Vector4(a.x, a.y, b.x, b.y)
	mat.set_shader_parameter("guide_line", guide)
	GameSettings.load_settings()
	# Low quality and the safe picture keep the stones and joints but skip the wear,
	# the grain, the tactile ridges and the meadow's flower specks.
	mat.set_shader_parameter("detail", 0.0 if GameSettings.quality == 0 or GameSettings.safe_picture else 1.0)
	return mat


## Signed distance to the paving's edge in metres: > 0 on stone, < 0 on grass.
static func paved(p: Vector2, village_radius: float, green: Array[Vector3], streets: Array[PackedVector2Array]) -> float:
	var d := village_radius - VERGE - p.length()
	for g in green:
		d = minf(d, p.distance_to(Vector2(g.x, g.y)) - g.z)
	# Streets stay paved through gardens and out to their ends.
	return maxf(d, STREET_HALF + 0.35 - _street(p, streets).x)


## Whether scenery (grass tufts, flowers, bushes, rocks, trees) may grow at `p`: not on
## the paving and its kerb (for Scenery.populate's `bare` filter).
static func grows(p: Vector2, village_radius: float, green: Array[Vector3], streets: Array[PackedVector2Array]) -> bool:
	return paved(p, village_radius, green, streets) < -0.6


## Grid line positions: FINE_STEP within ±inner, COARSE_STEP out to ±half_size.
static func _axis(half_size: float, inner: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var outer_cells := maxi(1, ceili((half_size - inner) / COARSE_STEP)) if half_size > inner else 0
	var inner_cells := ceili(inner * 2.0 / FINE_STEP)
	for i in outer_cells:
		out.append(-half_size + (half_size - inner) * i / outer_cells)
	for i in inner_cells + 1:
		out.append(-inner + inner * 2.0 * i / inner_cells)
	for i in outer_cells:
		out.append(inner + (half_size - inner) * (i + 1) / outer_cells)
	return out


## (distance to the nearest street centre line, that street's direction x, z).
static func _street(p: Vector2, streets: Array[PackedVector2Array]) -> Vector3:
	var best := Vector3(9999.0, 1.0, 0.0)
	for line in streets:
		for i in line.size() - 1:
			var a := line[i]
			var ab := line[i + 1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < best.x:
				var dir := ab.normalized()
				best = Vector3(d, dir.x, dir.y)
	return best
