class_name SiegeArena
extends RefCounted
## The guild war's battlefield: a castle siege. Each guild camps at one end of a wide field
## (the hero's guild on the left, x < 0), the two meet on the plaza in the middle, and north
## of it a stone bridge crosses the moat to the castle. Three gates stand one behind the
## other in the castle's long hall (GATE_Z); behind the third is the throne room with the
## altar a guild must hold for a minute to take the castle. The ground is flat: the moat and
## the walls are colliders, and fighters find their way along the sections (route): the
## field, the bridge, the two yards and the throne room, joined at the bridge foot and the
## three gates.

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
const BRIDGE_HALF := 5.0
## The castle hall is 2 * HALL_HALF wide; each gate opening 2 * GATE_HALF.
const HALL_HALF := 13.0
const GATE_HALF := 4.5
const GATE_Z: Array[float] = [-18.0, -30.0, -42.0]
const BACK_Z := -58.0
const WALL_H := 6.5
## The altar in the throne room and how close one must stand to take it.
const ALTAR := Vector3(0, 0, -51.0)
const ALTAR_RADIUS := 2.8
## Where the sections join: the bridge foot, then the three gates.
const CONNECTORS: Array[Vector3] = [Vector3(0, 0, -4.0), Vector3(0, 0, -18.0), Vector3(0, 0, -30.0), Vector3(0, 0, -42.0)]

const STONE := Color("9a978c")
const STONE_DARK := Color("6f6c64")
const PLASTER := Color("f1ebdd")
const TILE := Color("3f4756")
const WOOD := Color("5a3a26")
const PAVING := Color("b9b2a0")


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


static func on_altar(p: Vector3) -> bool:
	return Vector2(p.x - ALTAR.x, p.z - ALTAR.z).length() <= ALTAR_RADIUS


## Builds the field, the camps (in the two guild colours), the moat and bridge, the castle
## walls and gatehouses, the throne room and the keep, with their colliders.
static func build(zone: Node3D, rng: RandomNumberGenerator, left_color: Color, right_color: Color) -> void:
	Scenery.environment(zone, Color("5f8fd8"), Color("cfe0f0"), Color(0.9, 0.92, 1.0), Color(1.0, 0.95, 0.85))
	var paths: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-BASE_X, BASE_Z), Vector2(-20.0, 9.0), Vector2(PLAZA.x, PLAZA.z), Vector2(20.0, 9.0), Vector2(BASE_X, BASE_Z)]),
		PackedVector2Array([Vector2(PLAZA.x, PLAZA.z), Vector2(0.0, MOAT_SOUTH)]),
	]
	Scenery.ground(zone, 120.0, Color("6fae54"), Color("86c063"), 41, Color("cdb88a"), paths, 6.0, [Vector3(PLAZA.x, PLAZA.z, 14.0), Vector3(-BASE_X, BASE_Z, 12.0), Vector3(BASE_X, BASE_Z, 12.0)], &"meadow")
	var root := Node3D.new()
	root.name = "Siege"
	zone.add_child(root)
	_moat(root)
	_bridge(root)
	_castle(root)
	_keep(root)
	_camp(root, -1.0, left_color)
	_camp(root, 1.0, right_color)
	_plaza(root)
	_hills(root, rng)


static func _moat(root: Node3D) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, MOAT_SOUTH - MOAT_NORTH)
	water.mesh = plane
	water.position = Vector3(0, -0.35, (MOAT_SOUTH + MOAT_NORTH) * 0.5)
	water.material_override = RegionArt._water_material(&"village")
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	var b := JapanKit.Batch.new()
	# Stone banks on both sides, and the moat walls nobody can cross but on the bridge.
	for z in [MOAT_SOUTH, MOAT_NORTH]:
		b.box(Vector3(0, -0.2, z), Vector3(220.0, 0.7, 0.9), STONE_DARK)
	b.commit(root, "MoatBanks", false)
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	var depth := MOAT_SOUTH - MOAT_NORTH
	for side in [-1.0, 1.0]:
		var half: float = (RADIUS + 30.0 - BRIDGE_HALF) * 0.5
		JapanKit.collider(root, Vector3(side * (BRIDGE_HALF + half), 2.0, mid), Vector3(half * 2.0, 4.0, depth))


static func _bridge(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	var length := MOAT_SOUTH - MOAT_NORTH + 3.0
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	b.box(Vector3(0, 0.02, mid), Vector3(BRIDGE_HALF * 2.0, 0.3, length), PAVING)
	for x in [-1.0, 1.0]:
		b.box(Vector3(x * (BRIDGE_HALF - 0.2), 0.6, mid), Vector3(0.45, 0.9, length), STONE)
		for z in [MOAT_SOUTH + 1.0, mid, MOAT_NORTH - 1.0]:
			b.box(Vector3(x * (BRIDGE_HALF - 0.2), 1.3, z), Vector3(0.7, 0.6, 0.7), STONE_DARK)
			JapanKit.toro(b, Vector3(x * (BRIDGE_HALF + 0.9), 0, z), 0.8)
	b.commit(root, "Bridge")


## A stretch of castle wall from x0 to x1 at depth z (stone base, plaster, tiled cap) and its collider.
static func _wall_x(b: JapanKit.Batch, root: Node3D, x0: float, x1: float, z: float) -> void:
	var w := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	b.box(Vector3(cx, 1.6, z), Vector3(w, 3.2, 2.4), STONE)
	b.box(Vector3(cx, 4.4, z), Vector3(w, 2.4, 1.6), PLASTER)
	b.box(Vector3(cx, WALL_H - 0.4, z), Vector3(w + 0.6, 0.5, 2.4), TILE)
	JapanKit.collider(root, Vector3(cx, 3.0, z), Vector3(w, 6.0, 2.4))


static func _wall_z(b: JapanKit.Batch, root: Node3D, x: float, z0: float, z1: float) -> void:
	var d := absf(z1 - z0)
	var cz := (z0 + z1) * 0.5
	b.box(Vector3(x, 1.6, cz), Vector3(2.4, 3.2, d), STONE)
	b.box(Vector3(x, 4.4, cz), Vector3(1.6, 2.4, d), PLASTER)
	b.box(Vector3(x, WALL_H - 0.4, cz), Vector3(2.4, 0.5, d + 0.6), TILE)
	JapanKit.collider(root, Vector3(x, 3.0, cz), Vector3(2.4, 6.0, d))


## A gatehouse over gate k: two towers and a tiled roof over the opening (the door itself
## is the CastleGate the guilds break).
static func _gatehouse(b: JapanKit.Batch, k: int) -> void:
	var z := GATE_Z[k]
	for side in [-1.0, 1.0]:
		var x: float = side * (GATE_HALF + 1.4)
		b.box(Vector3(x, 3.6, z), Vector3(2.8, 7.2, 3.2), STONE)
		b.box(Vector3(x, 8.0, z), Vector3(2.4, 1.6, 2.8), PLASTER)
		b.roof(Vector3(x, 9.2, z), 3.6, 4.0, 1.0, TILE, 0.2)
	b.box(Vector3(0, 7.4, z), Vector3(GATE_HALF * 2.0 + 1.0, 1.2, 2.6), PLASTER)
	b.roof(Vector3(0, 8.6, z), GATE_HALF * 2.0 + 4.0, 4.4, 1.3, TILE, 0.3)
	b.box(Vector3(0, 6.7, z + 1.35), Vector3(2.6, 0.9, 0.12), JapanKit.GOLD.darkened(0.15))


static func _castle(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	# The front wall across the whole moat, the gate in the middle.
	_wall_x(b, root, -RADIUS - 30.0, -GATE_HALF, GATE_Z[0])
	_wall_x(b, root, GATE_HALF, RADIUS + 30.0, GATE_Z[0])
	# The hall's long side walls and the bridge landing's sides.
	for side in [-1.0, 1.0]:
		_wall_z(b, root, side * HALL_HALF, GATE_Z[0] - 1.2, BACK_Z)
	# Inner walls with the second and third gates, and the back wall.
	for k in [1, 2]:
		_wall_x(b, root, -HALL_HALF, -GATE_HALF, GATE_Z[k])
		_wall_x(b, root, GATE_HALF, HALL_HALF, GATE_Z[k])
	_wall_x(b, root, -HALL_HALF - 1.2, HALL_HALF + 1.2, BACK_Z)
	for k in 3:
		_gatehouse(b, k)
	# Corner towers.
	for x in [-HALL_HALF, HALL_HALF]:
		for z in [GATE_Z[0], BACK_Z]:
			b.box(Vector3(x, 4.5, z), Vector3(4.0, 9.0, 4.0), STONE)
			b.roof(Vector3(x, 9.6, z), 5.4, 5.4, 1.6, TILE, 0.15)
	# Paving in the yards and the throne room.
	b.box(Vector3(0, 0.03, (GATE_Z[0] + BACK_Z) * 0.5), Vector3(HALL_HALF * 2.0, 0.06, GATE_Z[0] - BACK_Z), PAVING)
	b.box(Vector3(0, 0.04, (MOAT_NORTH + GATE_Z[0]) * 0.5), Vector3(BRIDGE_HALF * 2.0 + 4.0, 0.06, MOAT_NORTH - GATE_Z[0] + 1.0), PAVING)
	# The throne room: a red carpet, pillars and a raised dais round the altar.
	b.box(Vector3(0, 0.07, (GATE_Z[2] + ALTAR.z) * 0.5), Vector3(3.0, 0.04, ALTAR.z - GATE_Z[2]), Color("a8322a"))
	for z in [-46.0, -50.0, -54.0]:
		for x in [-8.5, 8.5]:
			b.cyl(Vector3(x, 3.0, z), 0.55, 6.0, JapanKit.VERMILION, Vector3.ZERO, 10)
			b.box(Vector3(x, 6.1, z), Vector3(1.6, 0.3, 1.6), TILE)
	b.cyl(Vector3(ALTAR.x, 0.18, ALTAR.z), ALTAR_RADIUS + 0.6, 0.36, STONE, Vector3.ZERO, 24)
	b.cyl(Vector3(ALTAR.x, 0.4, ALTAR.z), ALTAR_RADIUS, 0.12, JapanKit.GOLD.darkened(0.2), Vector3.ZERO, 24)
	# Banners along the hall.
	for z in [-24.0, -36.0]:
		for x in [-HALL_HALF + 1.6, HALL_HALF - 1.6]:
			JapanKit.banner(b, Vector3(x, 0, z), Color("e8c050"))
	b.commit(root, "Castle")


## The keep behind the throne room: a tall tiered tower seen from everywhere on the field.
static func _keep(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis.from_scale(Vector3.ONE * 2.1), Vector3(0, 0, BACK_Z - 9.0))
	b.box(Vector3(0, 1.4, 0), Vector3(9.0, 2.8, 9.0), STONE)
	b.xform = Transform3D(Basis.from_scale(Vector3.ONE * 2.1), Vector3(0, 5.6, BACK_Z - 9.0))
	JapanKit.pagoda(b, 4)
	b.commit(root, "Keep", false)


## A guild's camp at one end of the field: tents, banners and a glowing circle where the
## fallen come back.
static func _camp(root: Node3D, side: float, color: Color) -> void:
	var b := JapanKit.Batch.new()
	var center := Vector3(side * BASE_X, 0, BASE_Z)
	for i in 4:
		var offset := Vector3(side * (8.0 + float(i % 2) * 5.0), 0, -10.0 + float(i) * 6.5)
		var at := center + offset
		b.box(at + Vector3(0, 0.9, 0), Vector3(3.6, 1.8, 3.2), color.lerp(Color.WHITE, 0.55))
		b.cone(at + Vector3(0, 2.6, 0), 2.6, 1.8, color.darkened(0.15))
	for i in 6:
		var angle := TAU * float(i) / 6.0
		JapanKit.banner(b, center + Vector3(cos(angle) * 9.5, 0, sin(angle) * 9.5), color)
	b.commit(root, "Camp%s" % ("Left" if side < 0.0 else "Right"))
	var ring := MeshInstance3D.new()
	ring.mesh = MeshKit.cylinder()
	ring.material_override = VfxKit._glow(color, 0.5)
	ring.scale = Vector3(14.0, 0.02, 14.0)
	ring.position = center + Vector3(0, 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)


## The plaza where the guilds meet: lanterns round a stone circle.
static func _plaza(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	b.cyl(Vector3(PLAZA.x, 0.04, PLAZA.z), 11.0, 0.08, PAVING, Vector3.ZERO, 32)
	for i in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		if absf(angle - PI * 1.5) < 0.5:
			continue
		JapanKit.toro(b, PLAZA + Vector3(cos(angle) * 12.0, 0, sin(angle) * 12.0), 1.0)
	b.commit(root, "Plaza")


static func _hills(root: Node3D, rng: RandomNumberGenerator) -> void:
	for i in 16:
		var angle := TAU * float(i) / 16.0 + rng.randf() * 0.2
		var dist := rng.randf_range(110.0, 130.0)
		var height := rng.randf_range(24.0, 46.0)
		var width := height * rng.randf_range(1.6, 2.2)
		var tint := Color("5d7f63").lerp(Color("8fa6b8"), rng.randf())
		var hill := MeshKit.part(root, MeshKit.cone(), MeshKit.toon(tint), Vector3(cos(angle) * dist, height * 0.5 - 1.0, sin(angle) * dist), Vector3(width, height, width))
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
