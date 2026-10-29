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
## [method life] then adds what moves: wandering villagers, animals, smoke.

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
## Where world players keep their stalls (WorldPresence): round the plaza between its
## lanterns and flower beds, and along the main street; each faces the street.
const STALLS: Array[Vector3] = [
	Vector3(9.4, 0, 3.4), Vector3(3.4, 0, 9.4), Vector3(-3.4, 0, 9.4), Vector3(-9.4, 0, 3.4),
	Vector3(-9.4, 0, -3.4), Vector3(-3.4, 0, -9.4), Vector3(3.4, 0, -9.4), Vector3(9.4, 0, -3.4),
	Vector3(-15.0, 0, 3.4), Vector3(-15.0, 0, -3.4), Vector3(-21.0, 0, 3.4), Vector3(-34.0, 0, -3.4),
	Vector3(14.0, 0, 3.4), Vector3(14.0, 0, -3.4), Vector3(26.5, 0, 3.4), Vector3(-34.0, 0, 3.4),
	Vector3(3.4, 0, 16.0), Vector3(-3.4, 0, 16.0), Vector3(3.4, 0, -16.0), Vector3(-3.4, 0, -16.0),
]


## The way a stall at `spot` faces: the plaza's centre, or across the street.
static func stall_face(spot: Vector3) -> Vector3:
	if Vector2(spot.x, spot.z).length() < PLAZA_RADIUS:
		return -Vector3(spot.x, 0, spot.z).normalized()
	if absf(spot.z) < absf(spot.x):
		return Vector3(0, 0, -signf(spot.z))
	return Vector3(-signf(spot.x), 0, 0)

## Main streets (for the ground paths).
static func paths() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(0, GATE.z + 6.0), Vector2(0, SHRINE.z + 6.0)]),
		PackedVector2Array([Vector2(-44, 0), Vector2(46, 0)]),
		PackedVector2Array([Vector2(36, 0), Vector2(RING.x, RING.z)]),
		PackedVector2Array([Vector2(0, 26), Vector2(-24, 28)]),
		PackedVector2Array([Vector2(6, -36), Vector2(PAGODA.x, PAGODA.z + 5.0)]),
	]


## Lantern flames collected from every piece while building (for the halos).
static var _halos: Array = []


static func build(zone: Node3D, rng: RandomNumberGenerator) -> Array[Vector3]:
	var clear: Array[Vector3] = []
	var root := Node3D.new()
	root.name = "Village"
	zone.add_child(root)
	_halos = []
	_plaza(root, clear)
	_shrine_quarter(root, clear)
	_market(root, clear)
	_west(root, clear)
	_south(root, clear, rng)
	_streets_clear(clear)
	_hedge(root, clear)
	_orchards(root, rng)
	_mountain(root)
	_lantern_halos(root)
	return clear


static func _piece(root: Node3D, node_name: String, pos: Vector3, yaw: float, build: Callable, collider_size := Vector3.ZERO, collider_offset := Vector3.ZERO) -> void:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis(Vector3.UP, yaw), pos)
	build.call(b)
	b.commit(root, node_name)
	_halos.append_array(b.lights)
	if collider_size != Vector3.ZERO:
		JapanKit.collider(root, pos + Basis(Vector3.UP, yaw) * (collider_offset + Vector3(0, collider_size.y * 0.5, 0)), collider_size, yaw)


## One additive MultiMesh of soft warm dots over every lantern flame: the glow
## of the town at a single draw call, no lights.
static func _lantern_halos(root: Node3D) -> void:
	if _halos.is_empty():
		return
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for entry in _halos:
		transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.7), entry[0]))
		colors.append(Color(entry[1], 0.42))
		transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.7), entry[0]))
		colors.append(Color((entry[1] as Color).lightened(0.3), 0.55))
	var halos := Scenery._billboards(root, "LanternHalos", transforms, colors, true)
	halos.visibility_range_end = 70.0 * GameSettings.view_scale()


static func _plaza(root: Node3D, clear: Array[Vector3]) -> void:
	var plaza := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS
	disc.bottom_radius = PLAZA_RADIUS
	disc.height = 0.06
	disc.radial_segments = 40
	plaza.mesh = disc
	# Flagstones: the shader lays slabs in world metres over the plain disc.
	var flags := ShaderMaterial.new()
	flags.shader = load("res://shaders/stone_flags.gdshader")
	flags.set_shader_parameter("stone_color", Color("d2c4ab"))
	flags.set_shader_parameter("mortar_color", Color("8e8372"))
	plaza.material_override = flags
	plaza.position = Vector3(0, 0.02, 0)
	root.add_child(plaza)
	# The great sakura on a round stone planter, ringed by stone lanterns and
	# four flower beds at the plaza's edge.
	_piece(root, "SakuraPlanter", Vector3.ZERO, 0.0, func(b: JapanKit.Batch):
		b.cyl(Vector3(0, 0.35, 0), 2.6, 0.7, JapanKit.STONE, Vector3.ZERO, 16)
		b.cyl(Vector3(0, 0.71, 0), 2.3, 0.04, Color("6a5a40"), Vector3.ZERO, 16)
		for i in 4:
			var a := TAU * i / 4.0 + PI * 0.25
			JapanKit.toro(b, Vector3(cos(a), 0, sin(a)) * 7.6, 0.9)
		for i in 4:
			var a := TAU * i / 4.0 + PI * 0.25
			var c := Vector3(cos(a), 0, sin(a)) * (PLAZA_RADIUS - 1.6)
			b.cyl(c + Vector3(0, 0.18, 0), 1.5, 0.36, JapanKit.STONE_DARK, Vector3.ZERO, 12)
			b.cyl(c + Vector3(0, 0.37, 0), 1.3, 0.04, Color("5a4a36"), Vector3.ZERO, 12)
			for j in 7:
				var fa := TAU * j / 7.0 + i
				var fp := c + Vector3(cos(fa) * 0.8, 0.5, sin(fa) * 0.8)
				b.ball(fp, Vector3(0.42, 0.34, 0.42), Color("6f9a52"))
				b.ball(fp + Vector3(0, 0.2, 0), Vector3(0.22, 0.2, 0.22), [Color("f08aa8"), Color("f6d35a"), Color("f4f0e6"), Color("c89ae8")][(i + j) % 4])
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
	_piece(root, "GeneralStore", SHOP, 0.0, func(b): JapanKit.shop(b, 9.0, 6.5, Color("2f4f8a"), JapanKit.WOOD_DARK, 2, "coin"), Vector3(9.2, 6.0, 6.6))
	_piece(root, "Forge", FORGE, 0.0, func(b: JapanKit.Batch):
		JapanKit.shop(b, 8.0, 6.5, Color("8a2f2a"), JapanKit.WOOD_DARK, 1, "hammer")
		# Chimney, anvil and a glowing hearth.
		b.box(Vector3(2.6, 5.0, -1.6), Vector3(1.0, 4.0, 1.0), JapanKit.STONE_DARK)
		b.box(Vector3(-3.6, 0.55, 4.4), Vector3(0.9, 0.5, 0.45), Color("3a3a42"))
		b.box(Vector3(-3.6, 0.2, 4.4), Vector3(0.45, 0.4, 0.4), Color("2a2a30"))
		b.box(Vector3(3.1, 0.9, 3.95), Vector3(1.2, 0.8, 0.6), Color("ff8a3a"), Vector3.ZERO, true)
		, Vector3(8.2, 6.0, 6.6))
	_piece(root, "Storehouse", KURA, PI, func(b): JapanKit.kura(b, 7.0, 5.5, 4.2), Vector3(7.4, 6.0, 5.9))
	_piece(root, "Izakaya", IZAKAYA, PI, func(b: JapanKit.Batch):
		JapanKit.shop(b, 8.0, 6.5, Color("b8352e"), Color("b8352e"), 1, "cup")
		for x in [-3.0, 3.0]:
			JapanKit.chochin(b, Vector3(x, 2.6, 3.9), Color("e8463a"), 1.4)
		# Kitchen chimney at the back.
		b.box(Vector3(-2.4, 4.6, -1.8), Vector3(0.8, 2.6, 0.8), JapanKit.STONE_DARK)
		, Vector3(8.2, 6.0, 6.6))
	for p in [SHOP, FORGE, KURA, IZAKAYA]:
		clear.append(Vector3(p.x, p.z, 6.5))
	# Two market stalls on the street between the shops.
	for spec in [[Vector3(26.5, 0, -3.0), 0.0, Color("e8c050"), [Color("e8a040"), Color("c8d070"), Color("e86a5a")]],
			[Vector3(26.5, 0, 3.0), PI, Color("2f4f8a"), [Color("f0e0b0"), Color("8ac8e8"), Color("e8a040")]]]:
		var pos: Vector3 = spec[0]
		_piece(root, "Stall", pos, spec[1], func(b: JapanKit.Batch): JapanKit.stall(b, 3.4, 1.8, spec[2], spec[3]), Vector3(3.6, 2.0, 1.4), Vector3(0, 0, 0.3))
		clear.append(Vector3(pos.x, pos.z, 2.8))
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


## A clipped hedge ring around the village, open at the gate and both ends of
## the main street, and skipping anything already standing there (one mesh).
static func _hedge(root: Node3D, clear: Array[Vector3]) -> void:
	var b := JapanKit.Batch.new()
	var r := 52.5
	var count := int(TAU * r / 3.3)
	for i in count:
		var a := TAU * i / count
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		# Gaps: the south gate (+z), the east and west street ends.
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.17 or absf(wrapf(a, -PI, PI)) < 0.1 or absf(wrapf(a - PI, -PI, PI)) < 0.1:
			continue
		var blocked := false
		for c in clear:
			if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.y)) < c.z + 1.0:
				blocked = true
		if blocked:
			continue
		var yaw := -rad_to_deg(a) + 90.0
		b.box(p + Vector3(0, 0.55, 0), Vector3(3.1, 1.1, 1.0), Color("4f7a44") if i % 3 != 0 else Color("5c8a4c"), Vector3(0, yaw, 0))
		b.box(p + Vector3(0, 1.12, 0), Vector3(2.9, 0.16, 0.8), Color("6a9a58"), Vector3(0, yaw, 0))
	if not b.is_empty():
		var mi := b.commit(root, "Hedge", false)
		mi.visibility_range_end = 0.0


## Sakura orchards in tidy rows outside the hedge, south-east and south-west.
static func _orchards(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trees: Array[Transform3D] = []
	for corner in [Vector2(46, 44), Vector2(-50, 40)]:
		for i in 4:
			for j in 3:
				var p: Vector2 = corner + Vector2(i * 5.2 * signf(corner.x), j * 5.4) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
				if p.length() < RADIUS + 2.0:
					continue
				trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.95, 1.15)), Vector3(p.x, 0, p.y)))
	NatureKit.place(root, "Orchards", "MapleTree_4", &"village", trees, [], false, 110.0)


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


## Snow-capped peaks far behind the shrine and along the eastern and western
## horizons (one mesh).
static func _mountain(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	for spec in [[Vector3(-20, -2.0, -150), 70.0, 56.0, Color("7f93ad")], [Vector3(-110, -2.0, -110), 52.0, 40.0, Color("8a9cb4")],
			[Vector3(70, -2.0, -150), 46.0, 34.0, Color("8ea0b8")], [Vector3(150, -2.0, -40), 56.0, 38.0, Color("98a8be")],
			[Vector3(-160, -2.0, 30), 60.0, 36.0, Color("9aaabf")]]:
		var pos: Vector3 = spec[0]
		var r: float = spec[1]
		var h: float = spec[2]
		b.cone(pos + Vector3(0, h * 0.46, 0), r, h, spec[3])
		b.cone(pos + Vector3(0, h * 0.83, 0), r * 0.38, h * 0.27, Color("f4f6fa"))
	var mi := b.commit(root, "Mountain", false)
	mi.visibility_range_end = 0.0


## What moves in the village: chimney and incense smoke, villagers walking
## their rounds between the plaza, market and shrine, a chicken and a cat.
## None of it joins Zone.npcs (the Talk button and the role count are unchanged).
static func life(zone: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "VillageLife"
	zone.add_child(root)
	_smoke(root, FORGE + Vector3(2.6, 7.2, -1.6), 14, Color(0.75, 0.75, 0.78, 0.5), 1.0)
	_smoke(root, IZAKAYA + Vector3(2.4, 6.0, 1.8), 10, Color(0.85, 0.85, 0.88, 0.45), 0.8)
	for spec in [[Vector3(28, 0, 40), -0.4], [Vector3(-40, 0, 24), 0.9]]:
		var pos: Vector3 = spec[0]
		_smoke(root, pos + Basis(Vector3.UP, spec[1]) * Vector3(1.5, 6.4, -1.0), 8, Color(0.8, 0.8, 0.82, 0.4), 0.7)
	_smoke(root, SHRINE + Vector3(0, 2.3, 3.2), 6, Color(0.9, 0.9, 0.95, 0.35), 0.35)
	var loops := [
		[Vector2(3, 6), Vector2(10, 1), Vector2(20, 0.5), Vector2(30, 0), Vector2(38, 2), Vector2(40, 14), Vector2(30, 0.5), Vector2(14, -1)],
		[Vector2(-3, 8), Vector2(-1, -4), Vector2(0.5, -16), Vector2(-0.5, -28), Vector2(1, -36), Vector2(8, -36), Vector2(-1, -30), Vector2(-2, -12)],
		[Vector2(-5, 1), Vector2(-14, 0.5), Vector2(-24, -0.5), Vector2(-36, 0), Vector2(-42, 1), Vector2(-30, 0.5), Vector2(-18, -1)],
		[Vector2(1, 14), Vector2(0, 22), Vector2(-2, 27), Vector2(-12, 27.5), Vector2(-22, 28), Vector2(-10, 27), Vector2(1, 30), Vector2(0, 40), Vector2(-1, 24)],
	]
	var outfits := [["Rogue", Color(0.9, 0.8, 0.6), ""], ["Mage", Color(0.7, 0.85, 0.75), ""], ["Ranger", Color(1.3, 0.8, 0.7), ""], ["Knight", Color(0.75, 0.75, 0.95), ""]]
	var hats := [["kasa", Color.WHITE], ["tenugui", Color("5a7ad8")], ["hachimaki", Color("f4f0e8")], ["ribbon", Color("e8463a")]]
	for i in mini(loops.size(), Villager.MAX_WALKERS):
		var walker := Villager.new()
		root.add_child(walker)
		walker.setup_person(FaceKit.random_look(rng), outfits[i], hats[i], loops[i], rng)
	var hen := Villager.new()
	root.add_child(hen)
	hen.setup_animal("blob/Chicken", 0.55, Vector2(20, 44), 3.0, 0.9, rng)
	var cat := Villager.new()
	root.add_child(cat)
	cat.setup_animal("blob/Cat", 0.5, Vector2(36.5, 16.5), 3.0, 1.3, rng)


## Untracked chimney / incense smoke (never charged to the combat VFX budget).
static func _smoke(parent: Node3D, pos: Vector3, amount: int, color: Color, size: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = maxi(2, int(amount * GameSettings.particle_scale()))
	p.lifetime = 3.2
	p.lifetime_randomness = 0.3
	p.preprocess = 3.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5) * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = VfxKit.soft_dot()
	quad.material = mat
	p.mesh = quad
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0.25, 0.15, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.position = pos
	parent.add_child(p)
