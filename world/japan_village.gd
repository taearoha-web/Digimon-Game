class_name JapanVillage
extends RefCounted
## Builds Mistwood village as a Japanese town (see [JapanKit] for the pieces):
##   north   the shrine on its terrace, three torii over a lantern-lined
##           approach and a five-storey pagoda
##   centre  a paved plaza around a great sakura tree
##   east    the market street (shop, forge, storehouse, izakaya) under paper
##           lanterns, ending at the sparring ring
##   west    the dojo and the village head's house
##   south   homes, a koi pond with a red bridge, rice fields and the village gate
## Returns the [x, z, radius] circles kept free of random trees and rocks.

const RADIUS := 56.0
## Where things stand, shared with the zone (NPC spots sit in front of these).
const START := Vector3(0, 0, 30)
const GATE := Vector3(0, 0, 47)
const PLAZA_RADIUS := 11.0
const SHRINE := Vector3(0, 0, -44)
const PAGODA := Vector3(17, 0, -40)
const DOJO := Vector3(-27, 0, -12)
const SHOP := Vector3(20, 0, -10)
const FORGE := Vector3(33, 0, -10)
const KURA := Vector3(20, 0, 10)
const IZAKAYA := Vector3(33, 0, 10)
const RING := Vector3(40, 0, 25)
const ELDER_HOUSE := Vector3(-17, 0, -26)
const POND := Vector3(-30, 0, 30)

## Main streets (for the ground paths).
static func paths() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(0, GATE.z + 6.0), Vector2(0, SHRINE.z + 6.0)]),
		PackedVector2Array([Vector2(-44, 0), Vector2(46, 0)]),
		PackedVector2Array([Vector2(36, 0), Vector2(RING.x, RING.z)]),
		PackedVector2Array([Vector2(0, 26), Vector2(-24, 28)]),
		PackedVector2Array([Vector2(6, -36), Vector2(PAGODA.x, PAGODA.z + 5.0)]),
	]


static func build(zone: Node3D, rng: RandomNumberGenerator) -> Array[Vector3]:
	var clear: Array[Vector3] = []
	var root := Node3D.new()
	root.name = "Village"
	zone.add_child(root)
	_plaza(root, clear)
	_shrine_quarter(root, clear)
	_market(root, clear)
	_west(root, clear)
	_south(root, clear, rng)
	_streets_clear(clear)
	_mountain(root)
	return clear


static func _piece(root: Node3D, node_name: String, pos: Vector3, yaw: float, build: Callable, collider_size := Vector3.ZERO, collider_offset := Vector3.ZERO) -> void:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis(Vector3.UP, yaw), pos)
	build.call(b)
	b.commit(root, node_name)
	if collider_size != Vector3.ZERO:
		JapanKit.collider(root, pos + Basis(Vector3.UP, yaw) * (collider_offset + Vector3(0, collider_size.y * 0.5, 0)), collider_size, yaw)


static func _plaza(root: Node3D, clear: Array[Vector3]) -> void:
	var plaza := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS
	disc.bottom_radius = PLAZA_RADIUS
	disc.height = 0.06
	disc.radial_segments = 40
	plaza.mesh = disc
	plaza.material_override = MeshKit.toon(Color("cdbfa8"))
	plaza.position = Vector3(0, 0.02, 0)
	root.add_child(plaza)
	# The great sakura on a round stone planter, ringed by stone lanterns.
	_piece(root, "SakuraPlanter", Vector3.ZERO, 0.0, func(b: JapanKit.Batch):
		b.cyl(Vector3(0, 0.35, 0), 2.6, 0.7, JapanKit.STONE, Vector3.ZERO, 16)
		b.cyl(Vector3(0, 0.71, 0), 2.3, 0.04, Color("6a5a40"), Vector3.ZERO, 16)
		for i in 4:
			var a := TAU * i / 4.0 + PI * 0.25
			JapanKit.toro(b, Vector3(cos(a), 0, sin(a)) * 7.6, 0.9)
		, Vector3(5.0, 2.0, 5.0))
	NatureKit.place(root, "GreatSakura", "MapleTree_1", &"village", [Transform3D(Basis.from_scale(Vector3.ONE * 2.4), Vector3(0, 0.6, 0))], [], true, 120.0)
	clear.append(Vector3(0, 0, PLAZA_RADIUS + 1.0))


static func _shrine_quarter(root: Node3D, clear: Array[Vector3]) -> void:
	_piece(root, "Shrine", SHRINE, 0.0, func(b): JapanKit.shrine(b), Vector3(11.0, 6.0, 9.0))
	clear.append(Vector3(SHRINE.x, SHRINE.z, 9.0))
	for z in [-15.0, -23.0, -31.0]:
		var big: bool = z == -15.0
		_piece(root, "Torii", Vector3(0, 0, z), 0.0, func(b): JapanKit.torii(b, 5.4 if big else 4.6, 6.2 if big else 5.4))
		for x in [-1.0, 1.0]:
			JapanKit.collider(root, Vector3(x * (2.7 if big else 2.3), 2.5, z), Vector3(0.6, 5.0, 0.6))
	_piece(root, "ApproachLanterns", Vector3.ZERO, 0.0, func(b: JapanKit.Batch):
		for z in [-12.0, -19.0, -27.0, -35.0]:
			for x in [-1.0, 1.0]:
				JapanKit.toro(b, Vector3(x * 4.2, 0, z), 1.0)
		# Shrine fence and the purification basin.
		JapanKit.fence(b, SHRINE + Vector3(-8.5, 0, 6.5), SHRINE + Vector3(-8.5, 0, -6.0))
		JapanKit.fence(b, SHRINE + Vector3(8.5, 0, 6.5), SHRINE + Vector3(8.5, 0, -6.0))
		b.box(SHRINE + Vector3(-6.0, 0.45, 9.0), Vector3(1.8, 0.9, 1.1), JapanKit.STONE_DARK)
		b.box(SHRINE + Vector3(-6.0, 0.92, 9.0), Vector3(1.5, 0.04, 0.8), Color("4a7a9a"))
		b.roof(SHRINE + Vector3(-6.0, 2.6, 9.0), 2.6, 2.0, 0.7, JapanKit.COPPER, 0.8)
		for x in [-1.0, 1.0]:
			b.box(SHRINE + Vector3(-6.0 + x * 1.0, 1.15, 9.0), Vector3(0.14, 2.3, 0.14), JapanKit.VERMILION)
		for x in [-1.0, 1.0]:
			JapanKit.banner(b, SHRINE + Vector3(x * 6.0, 0, 7.0), Color("e8e0d0"))
		)
	_piece(root, "Pagoda", PAGODA, 0.3, func(b): JapanKit.pagoda(b), Vector3(7.0, 12.0, 7.0))
	clear.append(Vector3(PAGODA.x, PAGODA.z, 7.0))
	_piece(root, "ElderHouse", ELDER_HOUSE, PI * 0.5, func(b: JapanKit.Batch):
		JapanKit.house(b, 9.0, 7.0, 3.2, JapanKit.TILE_DARK, 2)
		JapanKit.fence(b, Vector3(-6.0, 0, 6.0), Vector3(6.0, 0, 6.0))
		, Vector3(9.4, 6.0, 7.4))
	clear.append(Vector3(ELDER_HOUSE.x, ELDER_HOUSE.z, 8.0))
	for spot in [Vector3(-10.0, 0, -40.0), Vector3(10.0, 0, -48.0), Vector3(-14.0, 0, -48.0)]:
		NatureKit.place(root, "ShrineSakura", "MapleTree_4", &"village", [Transform3D(Basis(Vector3.UP, spot.x).scaled(Vector3.ONE * 1.5), spot)])
		JapanKit.collider(root, spot + Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0))
		clear.append(Vector3(spot.x, spot.z, 3.0))


static func _market(root: Node3D, clear: Array[Vector3]) -> void:
	_piece(root, "GeneralStore", SHOP, 0.0, func(b): JapanKit.shop(b, 9.0, 6.5, Color("2f4f8a")), Vector3(9.2, 6.0, 6.6))
	_piece(root, "Forge", FORGE, 0.0, func(b: JapanKit.Batch):
		JapanKit.shop(b, 8.0, 6.5, Color("8a2f2a"), JapanKit.WOOD_DARK, 1)
		# Chimney, anvil and a glowing hearth.
		b.box(Vector3(2.6, 5.0, -1.6), Vector3(1.0, 4.0, 1.0), JapanKit.STONE_DARK)
		b.box(Vector3(-3.6, 0.55, 4.4), Vector3(0.9, 0.5, 0.45), Color("3a3a42"))
		b.box(Vector3(-3.6, 0.2, 4.4), Vector3(0.45, 0.4, 0.4), Color("2a2a30"))
		b.box(Vector3(3.1, 0.9, 3.95), Vector3(1.2, 0.8, 0.6), Color("ff8a3a"), Vector3.ZERO, true)
		, Vector3(8.2, 6.0, 6.6))
	var smoke := VfxKit._particles(root, FORGE + Vector3(2.6, 7.2, -1.6), Color(0.75, 0.75, 0.78, 0.5), 14, 3.0, false)
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.1
	smoke.gravity = Vector3(0.25, 0.15, 0.0)
	_piece(root, "Storehouse", KURA, PI, func(b): JapanKit.kura(b, 7.0, 5.5, 4.2), Vector3(7.4, 6.0, 5.9))
	_piece(root, "Izakaya", IZAKAYA, PI, func(b: JapanKit.Batch):
		JapanKit.shop(b, 8.0, 6.5, Color("b8352e"), Color("b8352e"), 1)
		for x in [-3.0, 3.0]:
			JapanKit.chochin(b, Vector3(x, 2.6, 3.9), Color("e8463a"), 1.4)
		, Vector3(8.2, 6.0, 6.6))
	for p in [SHOP, FORGE, KURA, IZAKAYA]:
		clear.append(Vector3(p.x, p.z, 6.5))
	_piece(root, "MarketLanterns", Vector3.ZERO, 0.0, func(b: JapanKit.Batch):
		for x in [14.0, 26.5, 39.0]:
			JapanKit.lantern_line(b, Vector3(x, 0, -4.6), Vector3(x, 0, 4.6), 5, [Color("e8463a"), Color("f6efe0"), Color("f0b040")])
		for x in [-14.0, -34.0]:
			JapanKit.lantern_line(b, Vector3(x, 0, -4.6), Vector3(x, 0, 4.6), 4, [Color("f6efe0"), Color("e8463a")])
		JapanKit.banner(b, SHOP + Vector3(-5.2, 0, 4.2), Color("2f4f8a"))
		JapanKit.banner(b, FORGE + Vector3(-4.7, 0, 4.2), Color("8a2f2a"))
		JapanKit.banner(b, IZAKAYA + Vector3(4.7, 0, -4.2), Color("d8452e"))
		)
	_piece(root, "SparringRing", RING, 0.0, func(b: JapanKit.Batch):
		JapanKit.ring(b, 6.0)
		for i in 6:
			var a := TAU * i / 6.0
			JapanKit.banner(b, Vector3(cos(a) * 7.6, 0, sin(a) * 7.6), [Color("c83a3a"), Color("2f4f8a"), Color("e8c050")][i % 3])
		)
	clear.append(Vector3(RING.x, RING.z, 9.0))


static func _west(root: Node3D, clear: Array[Vector3]) -> void:
	_piece(root, "Dojo", DOJO, 0.0, func(b: JapanKit.Batch):
		JapanKit.dojo(b, 13.0, 7.5)
		for x in [-8.6, 8.6]:
			JapanKit.banner(b, Vector3(x, 0, 5.4), Color("1e2a4a"))
		# Training posts in the yard.
		for x in [-5.0, 5.0]:
			b.cyl(Vector3(x, 0.9, 7.6), 0.22, 1.8, JapanKit.WOOD_LIGHT, Vector3.ZERO, 8)
			b.box(Vector3(x, 1.2, 7.6), Vector3(0.9, 0.12, 0.12), JapanKit.WOOD)
		, Vector3(14.6, 7.0, 9.2))
	clear.append(Vector3(DOJO.x, DOJO.z, 10.0))
	for spec in [[Vector3(-22, 0, 12), PI, JapanKit.TILE], [Vector3(-36, 0, 11), PI, Color("6a5a48")], [Vector3(-40, 0, -10), PI * 0.5, JapanKit.TILE]]:
		var pos: Vector3 = spec[0]
		_piece(root, "House", pos, spec[1], func(b: JapanKit.Batch):
			JapanKit.house(b, 7.0, 5.5, 3.0, spec[2], 1)
			JapanKit.fence(b, Vector3(-5.0, 0, 4.6), Vector3(-1.4, 0, 4.6))
			JapanKit.fence(b, Vector3(1.4, 0, 4.6), Vector3(5.0, 0, 4.6))
			, Vector3(7.4, 6.0, 5.9))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	_piece(root, "Well", Vector3(-12, 0, -8), 0.0, func(b): JapanKit.well(b), Vector3(2.0, 2.0, 2.0))
	clear.append(Vector3(-12, -8, 2.5))


static func _south(root: Node3D, clear: Array[Vector3], rng: RandomNumberGenerator) -> void:
	for spec in [[Vector3(-12, 0, 21), PI * 0.5, 1], [Vector3(-12, 0, 35), PI * 0.5, 2], [Vector3(12, 0, 21), -PI * 0.5, 2], [Vector3(12, 0, 35), -PI * 0.5, 1]]:
		var pos: Vector3 = spec[0]
		_piece(root, "Home", pos, spec[1], func(b: JapanKit.Batch):
			JapanKit.house(b, 7.5, 6.0, 3.0, JapanKit.TILE if spec[2] == 1 else JapanKit.TILE_DARK, spec[2])
			, Vector3(7.9, 6.0, 6.4))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	# Farmhouses with thatched roofs by the rice fields.
	for spec in [[Vector3(28, 0, 40), -0.4], [Vector3(-40, 0, 24), 0.9]]:
		var pos: Vector3 = spec[0]
		_piece(root, "Farmhouse", pos, spec[1], func(b): JapanKit.house(b, 7.0, 5.5, 2.8, JapanKit.THATCH, 1), Vector3(7.4, 6.0, 5.9))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	_piece(root, "RiceFields", Vector3(26, 0, 26), 0.0, func(b: JapanKit.Batch):
		for i in 2:
			for j in 2:
				var c := Vector3(-4.0 + i * 8.0, 0, -3.0 + j * 6.5)
				b.box(c + Vector3(0, 0.1, 0), Vector3(7.4, 0.2, 6.0), Color("8a7a5a"))
				b.box(c + Vector3(0, 0.21, 0), Vector3(6.8, 0.02, 5.4), Color("7aa8a0"))
				for r in 6:
					for k in 5:
						b.cyl(c + Vector3(-3.0 + r * 1.2, 0.45, -2.2 + k * 1.1), 0.12, 0.5, Color("6ab04a"), Vector3.ZERO, 4)
		)
	clear.append(Vector3(26, 26, 9.0))
	# Koi pond with a red bridge (both look only; the pond is fenced off by stones).
	var pond := Node3D.new()
	pond.position = POND
	root.add_child(pond)
	var b := JapanKit.Batch.new()
	JapanKit.pond_rim(b, Vector2(7.5, 5.5), rng)
	JapanKit.bridge(b, 9.0)
	for i in 5:
		var a := rng.randf() * TAU
		b.ball(Vector3(cos(a) * rng.randf_range(1.5, 5.0), 0.1, sin(a) * rng.randf_range(1.0, 3.5)), Vector3(0.5, 0.12, 0.22), [Color("f08a3a"), Color("f6f0e8"), Color("e8463a")][i % 3])
	b.commit(pond, "PondRim")
	JapanKit.water(pond, Vector3.ZERO, Vector2(7.3, 5.3))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.4
	cyl.height = 2.0
	shape.shape = cyl
	shape.scale = Vector3(1.0, 1.0, 0.8)
	shape.position = Vector3(0, 1.0, 0)
	body.add_child(shape)
	pond.add_child(body)
	clear.append(Vector3(POND.x, POND.z, 9.0))
	# The village gate (the road to the meadow passes through it).
	_piece(root, "VillageGate", GATE, 0.0, func(gb: JapanKit.Batch):
		JapanKit.village_gate(gb, 7.0)
		for x in [-1.0, 1.0]:
			JapanKit.fence(gb, Vector3(x * 4.2, 0, 0), Vector3(x * 13.0, 0, -1.5))
			JapanKit.toro(gb, Vector3(x * 5.2, 0, -3.0), 1.0)
		)
	for x in [-1.0, 1.0]:
		JapanKit.collider(root, GATE + Vector3(x * 3.5, 2.4, 0), Vector3(0.8, 4.8, 0.8))
	clear.append(Vector3(GATE.x, GATE.z, 8.0))
	# Sakura along the south street.
	var trees: Array[Transform3D] = []
	for z in [14.0, 27.0, 41.0]:
		for x in [-6.5, 6.5]:
			var s := rng.randf_range(1.05, 1.3)
			trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, 0, z)))
			JapanKit.collider(root, Vector3(x, 1.5, z), Vector3(0.9, 3.0, 0.9))
			clear.append(Vector3(x, z, 2.5))
	NatureKit.place(root, "StreetSakura", "NormalTree_5", &"village", trees)


## Keeps the streets free of random trees and rocks.
static func _streets_clear(clear: Array[Vector3]) -> void:
	for line in paths():
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var c: Vector2 = line[i + 1]
			var steps := int(a.distance_to(c) / 3.0) + 1
			for k in steps + 1:
				var p := a.lerp(c, float(k) / float(steps))
				clear.append(Vector3(p.x, p.y, 4.5))


## A snow-capped peak far behind the shrine.
static func _mountain(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis.IDENTITY, Vector3(-20, -2.0, -150))
	b.cone(Vector3(0, 26, 0), 70.0, 56.0, Color("7f93ad"))
	b.cone(Vector3(0, 46.5, 0), 26.4, 15.0, Color("f4f6fa"))
	var mi := b.commit(root, "Mountain", false)
	mi.visibility_range_end = 0.0
