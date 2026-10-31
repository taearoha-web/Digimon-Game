class_name SiegeArena
extends RefCounted
## The guild war's battlefield: a castle siege in the grand style of the great Japanese
## castles. Each guild camps at one end of a wide field behind its own war curtains (the
## hero's guild on the left, x < 0), the two meet on the plaza in the middle, and north of
## it a stone bridge crosses the moat to the castle: a curtain of dressed-stone walls
## (ishigaki: courses of blocks leaning back as they rise) under white plastered parapets
## with loopholes and tiled caps, turrets along the walls and over every gate, and behind
## it all the five-storey keep on its own great stone base, flanked by two lesser keeps.
## Three gates stand one behind the other in the castle's long hall (GATE_Z); behind the
## third is the throne room with the altar a guild must hold for a minute to take the
## castle. The ground is flat: the moat and the walls are colliders, and fighters find
## their way along the sections (route): the field, the bridge, the two yards and the
## throne room, joined at the bridge foot and the three gates. The castle's banners take
## the colour of the guild that holds it (the match recolours the BANNER_META material).

## Play radius (the boundary walls).
const RADIUS := 78.0
## The two camps: ours at (-BASE_X, BASE_Z), theirs at (BASE_X, BASE_Z).
const BASE_X := 56.0
const BASE_Z := 16.0
## Inside this far from its camp a guild is safe from being chased (it heals there).
const CAMP_RADIUS := 16.0
## The plaza where the two guilds meet, south of the bridge.
const PLAZA := Vector3(0, 0, 6.0)
## The moat runs east-west between these z; the bridge crosses it at |x| < BRIDGE_HALF.
const MOAT_SOUTH := -6.0
const MOAT_NORTH := -14.0
const BRIDGE_HALF := 5.5
## The castle hall (the two yards) is 2 * HALL_HALF wide; each gate opening 2 * GATE_HALF
## wide, GATE_H high, the gates GATE_GAP apart. Past the third gate the throne room opens
## out to 2 * THRONE_HALF wide and runs THRONE_DEPTH deep to the back wall.
const HALL_HALF := 17.0
const GATE_HALF := 5.0
const GATE_H := 8.0
const GATE_GAP := 32.0
const GATE_Z: Array[float] = [-18.0, -18.0 - GATE_GAP, -18.0 - GATE_GAP * 2.0]
const THRONE_HALF := 34.0
const THRONE_DEPTH := 44.0
const BACK_Z := -18.0 - GATE_GAP * 2.0 - THRONE_DEPTH
## The stone base of the walls, then the plastered parapet on it.
const STONE_H := 7.0
const PARAPET_H := 2.4
const WALL_H := STONE_H + PARAPET_H
## The altar in the throne room and how close one must stand to take it.
const ALTAR := Vector3(0, 0, -18.0 - GATE_GAP * 2.0 - THRONE_DEPTH * 0.5)
const ALTAR_RADIUS := 2.8
## Where the sections join: the bridge foot, then the three gates.
const CONNECTORS: Array[Vector3] = [Vector3(0, 0, -4.0), Vector3(0, 0, -18.0), Vector3(0, 0, -18.0 - GATE_GAP), Vector3(0, 0, -18.0 - GATE_GAP * 2.0)]
## Zone meta holding the castle banners' shared material (recoloured for the castle's holder).
const BANNER_META := "siege_banner_material"

const STONES: Array[Color] = [Color("a39f94"), Color("8f8b81"), Color("b3ada0"), Color("7d7a72"), Color("9c958a"), Color("c0b9aa")]
const STONE := Color("a7a39a")
const STONE_CORE := Color("77736b")
const PLASTER := Color("f4efe4")
const TILE := Color("39414f")
const TILE_EDGE := Color("2a303b")
const WOOD := Color("4a2f20")
const PAVING := Color("bdb6a4")
const GOLD := Color("e8c050")
const LOOPHOLE := Color("2b2622")


## Which part of the battlefield a point is in: 0 field, 1 bridge, 2 first yard, 3 second
## yard, 4 throne room.
static func section(p: Vector3) -> int:
	if p.z > MOAT_SOUTH:
		return 0
	if p.z > GATE_Z[0]:
		return 1
	if p.z > GATE_Z[1]:
		return 2
	if p.z > GATE_Z[2]:
		return 3
	return 4


## The next point to walk to from `from` on the way to `to`: `to` itself within a section,
## otherwise the connector towards it (and a step through once there).
static func route(from: Vector3, to: Vector3) -> Vector3:
	var a := section(from)
	var b := section(to)
	if a == b:
		return to
	if b > a:
		var c: Vector3 = CONNECTORS[a]
		if Vector2(from.x - c.x, from.z - c.z).length() < 2.4:
			return c + Vector3(0, 0, -3.5)
		return c
	var back: Vector3 = CONNECTORS[a - 1]
	if Vector2(from.x - back.x, from.z - back.z).length() < 2.4:
		return back + Vector3(0, 0, 3.5)
	return back


## Front of gate k (the side the guilds come from).
static func gate_front(k: int) -> Vector3:
	return Vector3(0, 0, GATE_Z[k] + 3.0)


## The castle's floor (x, z) past the moat, where the hero may stand beyond the field's
## round edge (Hero.field_hall): the yards and the wider throne room.
static func hall_rect() -> Rect2:
	return Rect2(-THRONE_HALF, BACK_Z, THRONE_HALF * 2.0, MOAT_SOUTH - BACK_Z)


static func on_altar(p: Vector3) -> bool:
	return Vector2(p.x - ALTAR.x, p.z - ALTAR.z).length() <= ALTAR_RADIUS


## Builds the field, the camps (in the two guild colours), the moat and bridge, the castle
## with its walls, turrets, gatehouses, throne room and keeps, and their colliders.
static func build(zone: Node3D, rng: RandomNumberGenerator, left_color: Color, right_color: Color) -> void:
	Scenery.environment(zone, Color("5f8fd8"), Color("d6e4f2"), Color(0.9, 0.92, 1.0), Color(1.0, 0.95, 0.85))
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-BASE_X, BASE_Z), Vector2(-20.0, 9.0), Vector2(PLAZA.x, PLAZA.z), Vector2(20.0, 9.0), Vector2(BASE_X, BASE_Z)]),
		PackedVector2Array([Vector2(PLAZA.x, PLAZA.z), Vector2(0.0, MOAT_SOUTH)]),
	]
	Scenery.ground(zone, 165.0, Color("6fae54"), Color("86c063"), 41, Color("cdb88a"), paths, 6.5, [Vector3(PLAZA.x, PLAZA.z, 14.0), Vector3(-BASE_X, BASE_Z, 13.0), Vector3(BASE_X, BASE_Z, 13.0)], &"meadow")
	var root := Node3D.new()
	root.name = "Siege"
	zone.add_child(root)
	var masonry := Masonry.new(rng)
	# Its own copy (the cached toon material is shared), recoloured by the match.
	var banner := (MeshKit.toon(Color("fff1b8"), {"emission": 0.15}) as StandardMaterial3D).duplicate() as StandardMaterial3D
	zone.set_meta(BANNER_META, banner)
	_moat(root, masonry)
	_bridge(root, masonry)
	_castle(root, masonry, banner)
	_keeps(root, masonry, banner)
	_camp(root, -1.0, left_color)
	_camp(root, 1.0, right_color)
	_plaza(root)
	_pines(root, rng)
	_hills(root, rng)
	masonry.commit(root)


# ---------------------------------------------------------------------------
# Dressed stone: one MultiMesh of blocks over every stone face
# ---------------------------------------------------------------------------

## Collects stone blocks (courses with running joints, each block its own size and grey,
## the face leaning back as it rises) and draws them all at once.
class Masonry:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var rng: RandomNumberGenerator

	func _init(p_rng: RandomNumberGenerator) -> void:
		rng = p_rng

	## Courses on the face of a wall running from a to b (on the ground), whose face points
	## along `normal`, from y0 up to y1; the face starts `out` metres out from the line and
	## leans back by `lean` metres per metre of height.
	func face(a: Vector3, b: Vector3, normal: Vector3, y0: float, y1: float, out: float, lean := 0.08, course := 0.62) -> void:
		var along := b - a
		along.y = 0.0
		var length := along.length()
		if length < 0.1:
			return
		var dir := along / length
		var yaw := atan2(dir.x, dir.z) + PI * 0.5
		var row := 0
		var y := y0
		while y < y1 - 0.05:
			var h := minf(course * rng.randf_range(0.88, 1.08), y1 - y)
			var s := (0.0 if row % 2 == 0 else -0.6) + rng.randf_range(-0.2, 0.0)
			while s < length:
				var w := rng.randf_range(0.9, 1.7)
				var from := maxf(s, 0.0)
				var to := minf(s + w, length)
				if to - from > 0.12:
					var mid := a + dir * ((from + to) * 0.5)
					var inset := out - lean * (y + h * 0.5 - y0) + rng.randf_range(-0.04, 0.05)
					var center := mid + normal * inset + Vector3(0, y + h * 0.5, 0)
					var basis := Basis(Vector3.UP, yaw).scaled(Vector3(to - from - 0.07, h - 0.06, 0.5))
					transforms.append(Transform3D(basis, center))
					var tone: Color = STONES[rng.randi() % STONES.size()]
					colors.append(tone.lerp(Color("c9b89a"), rng.randf() * 0.18).darkened(rng.randf() * 0.12))
				s += w
			y += h
			row += 1

	## Courses round the given sides of a block (0 south, 1 north, 2 east, 3 west).
	func block(center: Vector3, size: Vector3, lean := 0.1, faces := [0, 1, 2, 3]) -> void:
		var hx := size.x * 0.5
		var hz := size.z * 0.5
		var c := Vector3(center.x, 0, center.z)
		for f in faces:
			match int(f):
				0: face(c + Vector3(-hx, 0, hz), c + Vector3(hx, 0, hz), Vector3(0, 0, 1), center.y, center.y + size.y, 0.0, lean)
				1: face(c + Vector3(hx, 0, -hz), c + Vector3(-hx, 0, -hz), Vector3(0, 0, -1), center.y, center.y + size.y, 0.0, lean)
				2: face(c + Vector3(hx, 0, hz), c + Vector3(hx, 0, -hz), Vector3(1, 0, 0), center.y, center.y + size.y, 0.0, lean)
				3: face(c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), Vector3(-1, 0, 0), center.y, center.y + size.y, 0.0, lean)

	func commit(root: Node3D) -> void:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = MeshKit.box()
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
			mm.set_instance_color(i, colors[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Masonry"
		inst.multimesh = mm
		inst.material_override = SiegeArena._vertex_material()
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)


## A batch drawn at any distance: the castle is the landmark of the whole field (a batch
## elsewhere fades out past 95 m, which would leave only the stone faces standing).
static func _commit(b: JapanKit.Batch, root: Node3D, node_name: String) -> void:
	var mi := b.commit(root, node_name)
	mi.visibility_range_end = 0.0


static func _vertex_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------

## A stretch of castle wall along x (from x0 to x1 at depth z): a stone core dressed on the
## given faces (+1 south, -1 north), a white parapet with loopholes and a tiled cap on top,
## and its collider.
static func _wall_x(b: JapanKit.Batch, m: Masonry, root: Node3D, x0: float, x1: float, z: float, faces := [1, -1]) -> void:
	var w := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	b.box(Vector3(cx, STONE_H * 0.5, z), Vector3(w, STONE_H, 3.4), STONE_CORE)
	for side in faces:
		var n := Vector3(0, 0, float(side))
		var a := Vector3(minf(x0, x1), 0, z) if float(side) > 0.0 else Vector3(maxf(x0, x1), 0, z)
		var e := Vector3(maxf(x0, x1), 0, z) if float(side) > 0.0 else Vector3(minf(x0, x1), 0, z)
		m.face(a, e, n, 0.0, STONE_H, 2.0, 0.08)
	_parapet(b, Vector3(x0, STONE_H, z), Vector3(x1, STONE_H, z))
	JapanKit.collider(root, Vector3(cx, WALL_H * 0.5, z), Vector3(w, WALL_H, 3.4))


static func _wall_z(b: JapanKit.Batch, m: Masonry, root: Node3D, x: float, z0: float, z1: float, faces := [1, -1]) -> void:
	var d := absf(z1 - z0)
	var cz := (z0 + z1) * 0.5
	b.box(Vector3(x, STONE_H * 0.5, cz), Vector3(3.4, STONE_H, d), STONE_CORE)
	for side in faces:
		var n := Vector3(float(side), 0, 0)
		var a := Vector3(x, 0, maxf(z0, z1)) if float(side) > 0.0 else Vector3(x, 0, minf(z0, z1))
		var e := Vector3(x, 0, minf(z0, z1)) if float(side) > 0.0 else Vector3(x, 0, maxf(z0, z1))
		m.face(a, e, n, 0.0, STONE_H, 2.0, 0.08)
	_parapet(b, Vector3(x, STONE_H, z0), Vector3(x, STONE_H, z1))
	JapanKit.collider(root, Vector3(x, WALL_H * 0.5, cz), Vector3(3.4, WALL_H, d))


## The plastered parapet on a wall top from a to b: a dark wooden sill, white plaster with
## a row of loopholes (triangle and square in turn) on both sides, and a tiled cap.
static func _parapet(b: JapanKit.Batch, a: Vector3, e: Vector3) -> void:
	var along := e - a
	var length := along.length()
	if length < 0.1:
		return
	var dir := along / length
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	var mid := (a + e) * 0.5
	b.box(mid + Vector3(0, 0.18, 0), Vector3(1.4, 0.36, length), WOOD, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, 0.36 + (PARAPET_H - 0.9) * 0.5, 0), Vector3(1.0, PARAPET_H - 0.9, length), PLASTER, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, PARAPET_H - 0.5, 0), Vector3(1.9, 0.22, length + 0.6), TILE_EDGE, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, PARAPET_H - 0.3, 0), Vector3(1.4, 0.3, length + 0.4), TILE, Vector3(0, yaw, 0))
	b.box(mid + Vector3(0, PARAPET_H - 0.1, 0), Vector3(0.5, 0.22, length + 0.2), TILE_EDGE, Vector3(0, yaw, 0))
	var side := Vector3(dir.z, 0, -dir.x)
	var count := int(length / 2.6)
	for i in count:
		var p := a + dir * (1.3 + float(i) * 2.6)
		for s in [-1.0, 1.0]:
			var at: Vector3 = p + side * (0.51 * float(s)) + Vector3(0, 1.2, 0)
			if i % 2 == 0:
				b.box(at, Vector3(0.36, 0.36, 0.06), LOOPHOLE, Vector3(0, yaw + 90.0, 45.0))
			else:
				b.box(at, Vector3(0.3, 0.42, 0.06), LOOPHOLE, Vector3(0, yaw + 90.0, 0))


## A two-storey turret (yagura) on a dressed stone base at `at`, flying the holder's banner.
static func _yagura(b: JapanKit.Batch, m: Masonry, at: Vector3, size: float, banner: StandardMaterial3D, root: Node3D, base_h := STONE_H + 0.6) -> void:
	b.box(at + Vector3(0, base_h * 0.5, 0), Vector3(size, base_h, size), STONE_CORE)
	m.block(at, Vector3(size + 0.6, base_h, size + 0.6), 0.1, [0, 2, 3])
	var y := base_h
	for tier in 2:
		var s := size - float(tier) * 1.6
		var h := 3.0 - float(tier) * 0.4
		b.box(at + Vector3(0, y + 0.15, 0), Vector3(s + 0.3, 0.3, s + 0.3), WOOD)
		b.box(at + Vector3(0, y + h * 0.5 + 0.3, 0), Vector3(s, h, s), PLASTER)
		for k in 3:
			var x := (float(k) - 1.0) * s * 0.3
			b.box(at + Vector3(x, y + h * 0.55 + 0.3, s * 0.5 + 0.03), Vector3(0.6, 0.7, 0.06), Color("3a2c22"))
		y += h + 0.3
		b.roof(at + Vector3(0, y + 0.45, 0), s + 2.4, s + 2.4, 1.1, TILE, 0.3)
		b.box(at + Vector3(0, y + 0.35, s * 0.5 + 1.0), Vector3(s * 0.45, 0.9, 0.5), TILE_EDGE, Vector3(-30, 0, 0))
		y += 0.9
	b.box(at + Vector3(0, y + 0.25, 0), Vector3(1.4, 0.3, 0.3), GOLD)
	b.cyl(at + Vector3(size * 0.35, y + 1.6, -0.9), 0.07, 3.6, WOOD)
	var flag := MeshKit.part(root, MeshKit.box(), banner, at + Vector3(size * 0.35, y + 2.2, 0), Vector3(0.12, 2.4, 1.6))
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The gatehouse over gate k: massive dressed-stone jambs, a lintel beam, and a long
## turret spanning the opening (watari-yagura) with the castle's golden crest and two long
## banners. The door itself is the CastleGate the guilds break.
static func _gatehouse(b: JapanKit.Batch, m: Masonry, k: int, banner: StandardMaterial3D, root: Node3D) -> void:
	var z := GATE_Z[k]
	for side in [-1.0, 1.0]:
		var x: float = float(side) * (GATE_HALF + 1.6)
		b.box(Vector3(x, (GATE_H + 1.0) * 0.5, z), Vector3(3.2, GATE_H + 1.0, 4.4), STONE_CORE)
		m.block(Vector3(x, 0, z), Vector3(3.4, GATE_H + 1.0, 4.6), 0.0, [0, 1, 2 if float(side) > 0.0 else 3])
		# The jambs close the wall up to the door (the CastleGate blocks the opening).
		JapanKit.collider(root, Vector3(x, (GATE_H + 1.0) * 0.5, z), Vector3(3.2, GATE_H + 1.0, 4.4))
	b.box(Vector3(0, GATE_H + 0.5, z), Vector3(GATE_HALF * 2.0 + 0.6, 1.0, 3.6), WOOD)
	var top := GATE_H + 1.0
	var span := GATE_HALF * 2.0 + 7.0
	b.box(Vector3(0, top + 0.15, z), Vector3(span + 0.4, 0.3, 5.0), WOOD)
	b.box(Vector3(0, top + 1.8, z), Vector3(span, 3.2, 4.6), PLASTER)
	for i in 5:
		var x := (float(i) - 2.0) * span * 0.19
		b.box(Vector3(x, top + 1.9, z + 2.33), Vector3(0.8, 1.0, 0.06), Color("3a2c22"))
		b.box(Vector3(x, top + 1.9, z - 2.33), Vector3(0.8, 1.0, 0.06), Color("3a2c22"))
	b.roof(Vector3(0, top + 4.0, z), span + 3.0, 7.4, 1.6, TILE, 0.55)
	b.box(Vector3(0, top + 4.9, z), Vector3(span * 0.6, 0.35, 0.5), TILE_EDGE)
	for side in [-1.0, 1.0]:
		b.box(Vector3(float(side) * span * 0.3, top + 5.2, z), Vector3(0.5, 0.8, 0.5), GOLD)
	b.cyl(Vector3(0, top + 2.0, z + 2.5), 1.0, 0.12, GOLD, Vector3(90, 0, 0), 16)
	b.cyl(Vector3(0, top + 2.0, z + 2.56), 0.6, 0.12, Color("c0392b"), Vector3(90, 0, 0), 16)
	for side in [-1.0, 1.0]:
		var flag := MeshKit.part(root, MeshKit.box(), banner, Vector3(float(side) * (GATE_HALF + 1.6), top - 2.2, z + 2.45), Vector3(1.4, 4.2, 0.08))
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _castle(root: Node3D, m: Masonry, banner: StandardMaterial3D) -> void:
	var b := JapanKit.Batch.new()
	# The great front wall across the whole moat (dressed on its outer face; inside the
	# hall on both), the first gate in the middle.
	var reach := RADIUS + 34.0
	_wall_x(b, m, root, -reach, -HALL_HALF, GATE_Z[0], [1])
	_wall_x(b, m, root, HALL_HALF, reach, GATE_Z[0], [1])
	_wall_x(b, m, root, -HALL_HALF, -GATE_HALF - 3.2, GATE_Z[0], [1, -1])
	_wall_x(b, m, root, GATE_HALF + 3.2, HALL_HALF, GATE_Z[0], [1, -1])
	# The yards' long side walls (dressed inside) to the third gate, the inner wall with the
	# second gate, the wider wall with the third gate (the throne room's front), the throne
	# room's side walls and the back wall.
	_wall_z(b, m, root, -HALL_HALF, GATE_Z[0], GATE_Z[2], [1])
	_wall_z(b, m, root, HALL_HALF, GATE_Z[0], GATE_Z[2], [-1])
	_wall_x(b, m, root, -HALL_HALF, -GATE_HALF - 3.2, GATE_Z[1], [1, -1])
	_wall_x(b, m, root, GATE_HALF + 3.2, HALL_HALF, GATE_Z[1], [1, -1])
	_wall_x(b, m, root, -THRONE_HALF, -GATE_HALF - 3.2, GATE_Z[2], [1, -1])
	_wall_x(b, m, root, GATE_HALF + 3.2, THRONE_HALF, GATE_Z[2], [1, -1])
	_wall_z(b, m, root, -THRONE_HALF, GATE_Z[2], BACK_Z, [1])
	_wall_z(b, m, root, THRONE_HALF, GATE_Z[2], BACK_Z, [-1])
	_wall_x(b, m, root, -THRONE_HALF, THRONE_HALF, BACK_Z, [1])
	for k in 3:
		_gatehouse(b, m, k, banner, root)
	# Turrets: on the hall's corners, the throne room's corners, along the front wall.
	for x in [-HALL_HALF, HALL_HALF]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[0]), 7.0, banner, root, STONE_H + 1.2)
	for x in [-THRONE_HALF, THRONE_HALF]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[2]), 7.0, banner, root, STONE_H + 1.2)
		_yagura(b, m, Vector3(x, 0, BACK_Z), 7.0, banner, root, STONE_H + 1.2)
	for x in [-58.0, -38.0, 38.0, 58.0]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[0]), 6.0, banner, root)
	# Paving in the yards and the throne room, and the landing in front of the first gate.
	b.box(Vector3(0, 0.03, (GATE_Z[0] + GATE_Z[2]) * 0.5), Vector3(HALL_HALF * 2.0, 0.06, GATE_Z[0] - GATE_Z[2]), PAVING)
	b.box(Vector3(0, 0.03, (GATE_Z[2] + BACK_Z) * 0.5), Vector3(THRONE_HALF * 2.0, 0.06, GATE_Z[2] - BACK_Z), PAVING)
	b.box(Vector3(0, 0.04, (MOAT_NORTH + GATE_Z[0]) * 0.5), Vector3(BRIDGE_HALF * 2.0 + 6.0, 0.06, MOAT_NORTH - GATE_Z[0] + 1.0), PAVING)
	for k in 2:
		for f in [0.3, 0.5, 0.7]:
			b.box(Vector3(0, 0.08, GATE_Z[k] - GATE_GAP * f), Vector3(HALL_HALF * 2.0 - 3.6, 0.04, 0.12), Color("9e9787"))
	# The yards: tall stone lanterns along the walls.
	for k in 2:
		for f in [0.15, 0.38, 0.62, 0.85]:
			for x in [-HALL_HALF + 3.0, HALL_HALF - 3.0]:
				JapanKit.toro(b, Vector3(x, 0, GATE_Z[k] - GATE_GAP * f), 1.3)
	# The throne room: a red carpet between two rows of vermilion pillars (open to the sky,
	# so the camera above sees the fight), the altar dais.
	b.box(Vector3(0, 0.07, (GATE_Z[2] + ALTAR.z) * 0.5), Vector3(3.6, 0.04, ALTAR.z - GATE_Z[2]), Color("a8322a"))
	for i in 7:
		var z := GATE_Z[2] - 5.0 - float(i) * (THRONE_DEPTH - 9.0) / 6.0
		for x in [-THRONE_HALF * 0.62, THRONE_HALF * 0.62]:
			b.cyl(Vector3(x, 0.4, z), 1.0, 0.8, STONE)
			b.cyl(Vector3(x, 3.4, z), 0.6, 6.0, JapanKit.VERMILION, Vector3.ZERO, 12)
			b.box(Vector3(x, 6.55, z), Vector3(1.6, 0.3, 1.6), WOOD)
			b.box(Vector3(x, 6.9, z), Vector3(1.0, 0.4, 1.0), GOLD)
	b.cyl(Vector3(ALTAR.x, 0.25, ALTAR.z), ALTAR_RADIUS + 1.2, 0.5, STONE, Vector3.ZERO, 32)
	b.cyl(Vector3(ALTAR.x, 0.55, ALTAR.z), ALTAR_RADIUS + 0.5, 0.2, STONE.lightened(0.15), Vector3.ZERO, 32)
	b.cyl(Vector3(ALTAR.x, 0.7, ALTAR.z), ALTAR_RADIUS, 0.12, GOLD.darkened(0.15), Vector3.ZERO, 32)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		b.box(Vector3(ALTAR.x + cos(angle) * (ALTAR_RADIUS + 0.9), 0.95, ALTAR.z + sin(angle) * (ALTAR_RADIUS + 0.9)), Vector3(0.5, 0.5, 0.5), GOLD, Vector3(0, -rad_to_deg(angle), 45))
	for x in [-6.0, 6.0]:
		JapanKit.toro(b, Vector3(x, 0, GATE_Z[2] - 6.0), 1.6)
	# Great hanging banners in the holder's colour along the throne room.
	for f in [0.15, 0.4, 0.65, 0.9]:
		var z: float = GATE_Z[2] - THRONE_DEPTH * float(f)
		for x in [-THRONE_HALF + 2.2, THRONE_HALF - 2.2]:
			var flag := MeshKit.part(root, MeshKit.box(), banner, Vector3(x, 5.6, z), Vector3(0.08, 6.0, 2.2))
			flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_commit(b, root, "Castle")


## A tiered keep (tenshu): white storeys under dark tiled roofs with gables on alternate
## roofs, and golden ridge-fish (shachihoko) on top.
static func _tenshu(b: JapanKit.Batch, at: Vector3, tiers: int, width: float, storey: float) -> void:
	var y := 0.0
	for i in tiers:
		var s := width * (1.0 - float(i) * 0.15)
		b.box(at + Vector3(0, y + 0.2, 0), Vector3(s + 0.4, 0.4, s + 0.4), WOOD)
		b.box(at + Vector3(0, y + 0.4 + storey * 0.5, 0), Vector3(s, storey, s), PLASTER)
		for k in 4:
			var x := (float(k) - 1.5) * s * 0.22
			for zs in [-1.0, 1.0]:
				b.box(at + Vector3(x, y + 0.4 + storey * 0.55, float(zs) * (s * 0.5 + 0.03)), Vector3(s * 0.08, storey * 0.3, 0.06), Color("3a2c22"))
		y += storey + 0.4
		b.roof(at + Vector3(0, y + 0.55, 0), s + 3.4, s + 3.4, 1.5, TILE, 0.25)
		if i % 2 == 0:
			for zs in [-1.0, 1.0]:
				b.box(at + Vector3(0, y + 1.2, float(zs) * (s * 0.5 + 0.8)), Vector3(s * 0.4, 1.4, 0.5), PLASTER)
				b.roof(at + Vector3(0, y + 2.1, float(zs) * (s * 0.5 + 0.8)), s * 0.5, 1.6, 0.9, TILE, 0.6)
		y += 1.2
	b.box(at + Vector3(0, y + 0.3, 0), Vector3(width * 0.3, 0.5, 0.6), TILE_EDGE)
	for xs in [-1.0, 1.0]:
		var fish := at + Vector3(float(xs) * width * 0.16, y + 1.1, 0)
		b.ball(fish, Vector3(0.7, 1.2, 0.5), GOLD)
		b.cone(fish + Vector3(0, 0.9, 0), 0.3, 0.8, GOLD, Vector3(0, 0, float(xs) * 25.0))


## The great keep behind the throne room and two lesser keeps beside the hall, each on a
## dressed-stone base with terraced walls stepping up to them; the keep flies the holder's banners.
static func _keeps(root: Node3D, m: Masonry, banner: StandardMaterial3D) -> void:
	var b := JapanKit.Batch.new()
	var main := Vector3(0, 0, BACK_Z - 13.0)
	b.box(main + Vector3(0, 5.5, 0), Vector3(22.0, 11.0, 20.0), STONE_CORE)
	m.block(main, Vector3(23.0, 11.0, 21.0), 0.16, [0, 2, 3])
	_tenshu(b, main + Vector3(0, 11.0, 0), 5, 15.0, 3.6)
	for xs in [-1.0, 1.0]:
		var x := float(xs)
		var side := Vector3(x * 33.0, 0, -52.0)
		b.box(side + Vector3(0, 4.5, 0), Vector3(13.0, 9.0, 13.0), STONE_CORE)
		m.block(side, Vector3(13.6, 9.0, 13.6), 0.14, [0, 2 if x > 0.0 else 3])
		_tenshu(b, side + Vector3(0, 9.0, 0), 3, 9.0, 3.0)
		# A terraced wall stepping up from the front wall towards the lesser keep.
		b.box(Vector3(x * 33.0, 2.5, -32.0), Vector3(20.0, 5.0, 2.6), STONE_CORE)
		m.face(Vector3(minf(x * 23.0, x * 43.0), 0, -30.7), Vector3(maxf(x * 23.0, x * 43.0), 0, -30.7), Vector3(0, 0, 1), 0.0, 5.0, 0.0, 0.06)
		_parapet(b, Vector3(x * 23.0, 5.0, -32.0), Vector3(x * 43.0, 5.0, -32.0))
	_commit(b, root, "Keeps")
	for xs in [-1.0, 1.0]:
		var flag := MeshKit.part(root, MeshKit.box(), banner, main + Vector3(float(xs) * 9.0, 7.0, 10.62), Vector3(2.6, 7.0, 0.1))
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------
# Moat, bridge, camps, plaza, trees
# ---------------------------------------------------------------------------

static func _moat(root: Node3D, m: Masonry) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240.0, MOAT_SOUTH - MOAT_NORTH)
	water.mesh = plane
	# Just above the field's ground (which runs under it), below the bridge deck.
	water.position = Vector3(0, 0.05, (MOAT_SOUTH + MOAT_NORTH) * 0.5)
	water.material_override = RegionArt._water_material(&"village")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	var b := JapanKit.Batch.new()
	# Stone-lined banks: a low dressed kerb on each side with a capping course.
	for z in [MOAT_SOUTH + 0.4, MOAT_NORTH - 0.4]:
		var n := Vector3(0, 0, 1.0 if float(z) > -10.0 else -1.0)
		for xs in [-1.0, 1.0]:
			var x0: float = float(xs) * BRIDGE_HALF
			var x1: float = float(xs) * (RADIUS + 34.0)
			b.box(Vector3((x0 + x1) * 0.5, 0.45, z), Vector3(absf(x1 - x0), 0.9, 0.9), STONE_CORE)
			b.box(Vector3((x0 + x1) * 0.5, 0.95, z), Vector3(absf(x1 - x0), 0.16, 1.1), STONE.lightened(0.1))
			var a := Vector3(minf(x0, x1), 0, z) if n.z > 0.0 else Vector3(maxf(x0, x1), 0, z)
			var e := Vector3(maxf(x0, x1), 0, z) if n.z > 0.0 else Vector3(minf(x0, x1), 0, z)
			m.face(a, e, n, 0.0, 0.9, 0.46, 0.0, 0.45)
	_commit(b, root, "MoatBanks")
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	var depth := MOAT_SOUTH - MOAT_NORTH
	for side in [-1.0, 1.0]:
		var half: float = (RADIUS + 34.0 - BRIDGE_HALF) * 0.5
		JapanKit.collider(root, Vector3(float(side) * (BRIDGE_HALF + half), 2.0, mid), Vector3(half * 2.0, 4.0, depth))


## A stone bridge: a paved deck on piers, a balustrade of capped posts and rails, and
## great stone lanterns at both ends.
static func _bridge(root: Node3D, m: Masonry) -> void:
	var b := JapanKit.Batch.new()
	var length := MOAT_SOUTH - MOAT_NORTH + 4.0
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	b.box(Vector3(0, 0.15, mid), Vector3(BRIDGE_HALF * 2.0, 0.3, length), PAVING)
	for z in [mid - 2.2, mid + 2.2]:
		b.box(Vector3(0, 0.0, z), Vector3(BRIDGE_HALF * 2.0 - 0.6, 0.6, 1.4), STONE_CORE)
	for xs in [-1.0, 1.0]:
		var x: float = float(xs) * (BRIDGE_HALF - 0.3)
		b.box(Vector3(x, 0.55, mid), Vector3(0.5, 0.5, length), STONE)
		b.box(Vector3(x, 1.25, mid), Vector3(0.36, 0.2, length), STONE.lightened(0.12))
		var posts := 7
		for i in posts:
			var z := MOAT_SOUTH + 2.0 - float(i) * (length - 0.5) / float(posts - 1)
			b.box(Vector3(x, 0.9, z), Vector3(0.55, 1.1, 0.55), STONE_CORE.lightened(0.05))
			b.ball(Vector3(x, 1.6, z), Vector3(0.5, 0.45, 0.5), STONE.lightened(0.05))
		var start := Vector3(x + float(xs) * 0.25, 0, MOAT_SOUTH + 2.0)
		var end := Vector3(x + float(xs) * 0.25, 0, MOAT_NORTH - 2.0)
		m.face(start if float(xs) > 0.0 else end, end if float(xs) > 0.0 else start, Vector3(float(xs), 0, 0), 0.0, 0.8, 0.02, 0.0, 0.4)
		for z in [MOAT_SOUTH + 2.6, MOAT_NORTH - 2.6]:
			JapanKit.toro(b, Vector3(float(xs) * (BRIDGE_HALF + 1.4), 0, z), 1.5)
	_commit(b, root, "Bridge")


## A guild's war camp at one end of the field: a ring of war curtains (maku) in its colour
## with white bands and crest, tents, tall banners and a glowing circle where the fallen
## come back. The curtain opens towards the plaza.
static func _camp(root: Node3D, side: float, color: Color) -> void:
	var b := JapanKit.Batch.new()
	var center := Vector3(side * BASE_X, 0, BASE_Z)
	var opening := Vector2(-side, -0.35).normalized()
	# Wide enough for a whole guild in its rows (GuildWarMatch.spawn_slot).
	var panels := 22
	for i in panels:
		var angle := TAU * (float(i) + 0.5) / float(panels)
		if Vector2(cos(angle), sin(angle)).dot(opening) > 0.75:
			continue
		var out := Vector3(cos(angle), 0, sin(angle))
		var at := center + out * 19.0
		# Turned so the panel runs along the ring (its local z faces out of the camp).
		var yaw := rad_to_deg(atan2(out.x, out.z))
		b.box(at + Vector3(0, 1.3, 0), Vector3(5.4, 2.0, 0.08), color.lerp(Color.WHITE, 0.15), Vector3(0, yaw, 0))
		b.box(at + Vector3(0, 0.75, 0), Vector3(5.45, 0.28, 0.1), Color.WHITE, Vector3(0, yaw, 0))
		b.box(at + Vector3(0, 1.85, 0), Vector3(5.45, 0.28, 0.1), Color.WHITE, Vector3(0, yaw, 0))
		b.cyl(at + Vector3(0, 1.3, 0) + out * 0.06, 0.45, 0.04, Color.WHITE, Vector3(90, yaw, 0), 12)
		b.cyl(at + Vector3(0, 1.3, 0) + Vector3(-out.z, 0, out.x) * 2.7, 0.06, 2.6, WOOD)
	# Tents along the camp's two sides, clear of the rows and the camera behind them.
	for i in 6:
		var at := center + Vector3(side * (-2.0 + float(i % 3) * 6.0), 0, (14.0 if i < 3 else -14.0))
		b.box(at + Vector3(0, 0.9, 0), Vector3(3.6, 1.8, 3.2), color.lerp(Color.WHITE, 0.6))
		b.roof(at + Vector3(0, 2.4, 0), 4.4, 3.8, 1.3, color.darkened(0.2), 0.5)
	for i in 10:
		var angle := TAU * (float(i) + 0.5) / 10.0
		if Vector2(cos(angle), sin(angle)).dot(opening) > 0.8:
			continue
		JapanKit.banner(b, center + Vector3(cos(angle) * 17.5, 0, sin(angle) * 17.5), color)
	_commit(b, root, "Camp%s" % ("Left" if side < 0.0 else "Right"))
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.cylinder()
	ring.material_override = VfxKit._glow(color, 0.5)
	ring.scale = Vector3(14.0, 0.02, 14.0)
	ring.position = center + Vector3(0, 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)


## The plaza where the guilds meet: a paved circle ringed by tall stone lanterns.
static func _plaza(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	b.cyl(Vector3(PLAZA.x, 0.04, PLAZA.z), 12.0, 0.08, PAVING, Vector3.ZERO, 36)
	b.cyl(Vector3(PLAZA.x, 0.06, PLAZA.z), 6.0, 0.08, STONE.lightened(0.1), Vector3.ZERO, 36)
	for i in 10:
		var angle := TAU * (float(i) + 0.5) / 10.0
		if absf(angle - PI * 1.5) < 0.45:
			continue
		JapanKit.toro(b, PLAZA + Vector3(cos(angle) * 13.0, 0, sin(angle) * 13.0), 1.2)
	_commit(b, root, "Plaza")


## Black pines framing the field (clear of the camps, the paths and the plaza).
static func _pines(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 900:
		tries += 1
		var angle := rng.randf() * TAU
		var r := rng.randf_range(30.0, RADIUS + 18.0)
		var p := Vector3(cos(angle) * r, 0, sin(angle) * r)
		if p.z < MOAT_SOUTH + 3.0:
			continue
		if Vector2(p.x - BASE_X, p.z - BASE_Z).length() < 24.0 or Vector2(p.x + BASE_X, p.z - BASE_Z).length() < 24.0:
			continue
		if Vector2(p.x - PLAZA.x, p.z - PLAZA.z).length() < 18.0 or (absf(p.z - 10.0) < 6.0 and absf(p.x) < 50.0):
			continue
		var h := rng.randf_range(5.0, 9.0)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.6, h * 0.5, 0.6)), p + Vector3(0, h * 0.25, 0)))
		trunk_colors.append(Color("5a3d2b"))
		for k in 3:
			var s := (1.0 - float(k) * 0.26) * rng.randf_range(3.2, 4.4)
			crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.55, s)), p + Vector3(0, h * 0.45 + float(k) * h * 0.18, 0)))
			crown_colors.append(Color("2f5a3a").lerp(Color("3f7346"), rng.randf()))
		placed += 1
	_batch(root, "PineTrunks", MeshKit.cylinder(), trunks, trunk_colors)
	_batch(root, "PineCrowns", MeshKit.cone(), crowns, crown_colors)


static func _batch(root: Node3D, node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = _vertex_material()
	root.add_child(inst)


static func _hills(root: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 18:
		var angle := TAU * float(i) / 18.0 + rng.randf() * 0.2
		var dist := rng.randf_range(175.0, 205.0)
		var height := rng.randf_range(26.0, 52.0)
		var width := height * rng.randf_range(1.6, 2.2)
		var tint := Color("5d7f63").lerp(Color("8fa6b8"), rng.randf())
		var hill := MeshKit.part(root, MeshKit.cone(), MeshKit.toon(tint), Vector3(cos(angle) * dist, height * 0.5 - 1.0, sin(angle) * dist), Vector3(width, height, width))
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
