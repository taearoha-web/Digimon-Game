class_name JapanVillage
extends RefCounted
## Builds Mistwood village as a Japanese town of separate districts (see [JapanKit] for
## the pieces), each behind low tile-capped walls with its own gate, plaque and colours:
##   centre  the sakura plaza: the great sakura on a stone terrace ringed by lanterns
##           and benches, the notice board and the warp crystal
##   north   the shrine district behind a grand vermilion torii: a torii tunnel and
##           lanterns up to the shrine, the five-storey pagoda, a sakura grove
##   east    the market street: shop, forge, storehouse, izakaya, tea house and sweet
##           shop, and every world player's stall in two rows under paper lanterns
##   west    the training district: the dojo (job and skill masters), the village
##           head's house, a practice yard with targets
##   SE      the arena and guild district: the sparring ring and the guild keep
##   south   the gate avenue to the great gate (to the meadow), lined with homes
##   SW      homes and gardens round a koi pond with a red bridge and a pavilion
##   NE / NW rice fields with farmhouses; a bamboo grove with a tea pavilion
## [method build] returns the [x, z, radius] circles kept free of random trees and rocks;
## [method life] then adds what moves: wandering villagers, animals, smoke.

const RADIUS := 80.0
## Where things stand, shared with the zone (NPC spots sit in front of these).
const START := Vector3(0, 0, 19)
const GATE := Vector3(0, 0, 70)
const PLAZA_RADIUS := 14.0
const SHRINE := Vector3(0, 0, -64)
## The shrine hall is built a third larger than the kit's: the end of the grand axis.
const SHRINE_SCALE := 1.35
const PAGODA := Vector3(17, 0, -50)
const DOJO := Vector3(-32, 0, -12)
const ELDER_HOUSE := Vector3(-32, 0, 12)
const SHOP := Vector3(26, 0, -14)
const FORGE := Vector3(40, 0, -14)
const KURA := Vector3(26, 0, 14)
const IZAKAYA := Vector3(40, 0, 14)
const TEA_HOUSE := Vector3(55, 0, -14)
const SWEETS := Vector3(55, 0, 14)
## The market's stall rows stand this far either side of the street's middle: a 10 m
## walkway between the keepers, booths behind them, then room to reach the shop doors.
const STALL_ROW := 5.0
const GUILD_HALL := Vector3(40, 0, 29)
const RING := Vector3(40, 0, 53)
const POND := Vector3(-30, 0, 54)
## The warp crystal and the daily notice board, either side of the plaza's south entry.
const WARP := Vector3(-7.5, 0, 7.5)
const NOTICE := Vector3(7.5, 0, 7.5)
## The street across the south half (the arena and the homes open onto it).
const CROSS_Z := 40.0
## District gates are this wide either side of their street.
const GATE_HALF := 6.3
## The districts: name, colour, and the area (a circle for the plaza, else a rect in
## x / z). The minimap outlines them, the signs carry the names.
const DISTRICTS := [
	{"id": "plaza", "name": "ลานซากุระ", "center": Vector2(0, 0), "radius": 14.0, "color": Color("f08aa8")},
	{"id": "shrine", "name": "ย่านศาลเจ้า", "center": Vector2(0, -46), "rect": Rect2(-24, -76, 48, 54), "color": Color("e8553a")},
	{"id": "market", "name": "ถนนตลาด", "center": Vector2(42, 0), "rect": Rect2(18, -19, 50, 38), "color": Color("f0b040")},
	{"id": "training", "name": "ย่านฝึกยุทธ์", "center": Vector2(-42, 0), "rect": Rect2(-66, -19, 48, 38), "color": Color("4a6ad0")},
	{"id": "arena", "name": "ลานประลองและหอกิลด์", "center": Vector2(40, 42), "rect": Rect2(18, 19, 46, 46), "color": Color("d84a6a")},
	{"id": "avenue", "name": "ถนนประตูเมือง", "center": Vector2(0, 44), "rect": Rect2(-18, 14, 36, 58), "color": Color("f6d35a")},
	{"id": "homes", "name": "ย่านบ้านพักและสวน", "center": Vector2(-40, 42), "rect": Rect2(-64, 19, 46, 46), "color": Color("7ac05a")},
	{"id": "farm", "name": "ทุ่งนา", "center": Vector2(45, -42), "rect": Rect2(24, -66, 42, 47), "color": Color("c8d070")},
	{"id": "grove", "name": "สวนไผ่", "center": Vector2(-45, -42), "rect": Rect2(-66, -66, 42, 47), "color": Color("5aa86a")},
]
## Where world players keep their stalls (WorldPresence): only on the market street, two
## rows facing the walkway, each in front of its own booth, clear of the shop doors.
const STALLS: Array[Vector3] = [
	Vector3(20.5, 0, -STALL_ROW), Vector3(31.6, 0, -STALL_ROW), Vector3(34.4, 0, -STALL_ROW), Vector3(45.6, 0, -STALL_ROW), Vector3(48.4, 0, -STALL_ROW),
	Vector3(51.2, 0, -STALL_ROW), Vector3(54.0, 0, -STALL_ROW), Vector3(56.8, 0, -STALL_ROW), Vector3(59.6, 0, -STALL_ROW), Vector3(62.4, 0, -STALL_ROW),
	Vector3(29.0, 0, STALL_ROW), Vector3(31.8, 0, STALL_ROW), Vector3(34.6, 0, STALL_ROW), Vector3(43.4, 0, STALL_ROW), Vector3(46.2, 0, STALL_ROW),
	Vector3(49.0, 0, STALL_ROW), Vector3(51.8, 0, STALL_ROW), Vector3(54.6, 0, STALL_ROW), Vector3(57.4, 0, STALL_ROW), Vector3(60.2, 0, STALL_ROW),
]


## The way a stall at `spot` faces: across the market street, onto the walkway.
static func stall_face(spot: Vector3) -> Vector3:
	return Vector3(0, 0, -signf(spot.z) if spot.z != 0.0 else 1.0)


## The district `spot` stands in (its DISTRICTS entry), or {} between them.
static func district_at(spot: Vector3) -> Dictionary:
	var p := Vector2(spot.x, spot.z)
	for d in DISTRICTS:
		if d.has("radius"):
			if p.distance_to(d.center) <= float(d.radius):
				return d
		elif (d.rect as Rect2).has_point(p):
			return d
	return {}


## Main streets (for the ground paths and the minimap).
static func paths() -> Array[PackedVector2Array]:
	return [
		PackedVector2Array([Vector2(0, GATE.z + 6.0), Vector2(0, SHRINE.z + 7.0)]),
		PackedVector2Array([Vector2(-70, 0), Vector2(70, 0)]),
		PackedVector2Array([Vector2(-56, CROSS_Z), Vector2(56, CROSS_Z)]),
		PackedVector2Array([Vector2(4, -42), Vector2(PAGODA.x - 3.0, PAGODA.z + 4.0)]),
		PackedVector2Array([Vector2(-24, -34), Vector2(-40, -40)]),
		PackedVector2Array([Vector2(24, -34), Vector2(34, -36)]),
		PackedVector2Array([Vector2(POND.x, CROSS_Z), Vector2(POND.x, POND.z - 6.0)]),
	]


## The parts that stay grass or soil, as (x, z, radius) circles: the shrine's sakura
## grove, the bamboo grove, the rice fields and farmyards, the pond garden, the
## practice yard and the avenue's tree pits. Everything else inside the hedge is paved.
static func green_areas() -> Array[Vector3]:
	var out: Array[Vector3] = [
		Vector3(-15, -34, 8.0), Vector3(-15, -50, 8.0), Vector3(-14, -64, 6.0), Vector3(13, -31, 6.0), Vector3(12, -64, 5.0),
		Vector3(-44, -42, 17.0),
		Vector3(45, -40, 15.0), Vector3(58, -28, 6.0), Vector3(34, -57, 6.0),
		Vector3(POND.x, POND.z, 11.0), Vector3(-40, 46, 4.5),
		Vector3(-54, -7, 8.0),
	]
	for t in _avenue_trees() + LANE_SAKURA:
		out.append(Vector3(t.x, t.y, 1.6))
	return out


## Lantern flames collected from every piece while building (for the halos).
static var _halos: Array = []
## One merged batch of small things per district (walls, gates, lanterns, benches...).
static var _decor: Dictionary = {}
## Overhead pieces the follow camera can come under or behind (market booths, lantern
## lines across a street): each its own small mesh in ThirdPersonCamera.FADE_GROUP, so
## the camera fades out just the piece in its way.
static var _overheads: Array = []


static func build(zone: Node3D, rng: RandomNumberGenerator) -> Array[Vector3]:
	var clear: Array[Vector3] = []
	var root := Node3D.new()
	root.name = "Village"
	zone.add_child(root)
	_halos = []
	_decor = {}
	_overheads = []
	_plaza(root, clear)
	_shrine_quarter(root, clear)
	_market(root, clear)
	_west(root, clear, rng)
	_arena(root, clear)
	_south(root, clear, rng)
	_farm(root, clear)
	_grove(root, rng)
	_lived_in(root)
	_walls(root, clear)
	_commit_decor(root)
	_streets_clear(clear)
	_hedge(root, clear)
	_districts_clear(clear)
	_orchards(root, rng)
	_mountain(root)
	_lantern_halos(root)
	return clear


## One building (or group) as one merged mesh; `scale` grows the whole piece (and its collider).
static func _piece(root: Node3D, node_name: String, pos: Vector3, yaw: float, build: Callable, collider_size := Vector3.ZERO, collider_offset := Vector3.ZERO, scale := 1.0) -> MeshInstance3D:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), pos)
	build.call(b)
	var mi := b.commit(root, node_name)
	_halos.append_array(b.lights)
	if collider_size != Vector3.ZERO:
		var size := collider_size * scale
		JapanKit.collider(root, pos + Basis(Vector3.UP, yaw) * (collider_offset * scale + Vector3(0, size.y * 0.5, 0)), size, yaw)
	return mi


## The district's shared batch of small pieces (world coordinates unless its xform is set).
static func _d(id: String) -> JapanKit.Batch:
	if not _decor.has(id):
		_decor[id] = JapanKit.Batch.new()
	var b: JapanKit.Batch = _decor[id]
	b.xform = Transform3D.IDENTITY
	return b


## Adds into a district batch with a local frame at `pos` turned by `yaw`.
static func _at(id: String, pos: Vector3, yaw: float) -> JapanKit.Batch:
	var b := _d(id)
	b.xform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return b


static func _commit_decor(root: Node3D) -> void:
	for id in _decor:
		var b: JapanKit.Batch = _decor[id]
		if b.is_empty():
			continue
		b.commit(root, "Decor_" + String(id))
		_halos.append_array(b.lights)
	_decor = {}
	for i in _overheads.size():
		var ob: JapanKit.Batch = _overheads[i]
		# Small street detail: drawn to a shorter distance than the buildings, and no
		# shadow passes of their own (one per piece and split would undo the merging).
		var line: bool = ob.get_meta("line", false)
		var mi := ob.commit(root, "Overhead_%d" % i, false)
		mi.visibility_range_end = (45.0 if line else 60.0) * GameSettings.view_scale()
		# No additive halo: it would float on where the piece fades out.
		mi.add_to_group(ThirdPersonCamera.FADE_GROUP)
	_overheads = []


## A new overhead piece's batch, its local frame at `pos` turned by `yaw`.
static func _overhead(pos := Vector3.ZERO, yaw := 0.0) -> JapanKit.Batch:
	var b := JapanKit.Batch.new()
	b.xform = Transform3D(Basis(Vector3.UP, yaw), pos)
	_overheads.append(b)
	return b


## A line of paper lanterns across a street (world coordinates), as an overhead piece.
static func _overhead_line(from: Vector3, to: Vector3, count: int, colors: Array) -> void:
	var b := _overhead()
	b.set_meta("line", true)
	JapanKit.lantern_line(b, from, to, count, colors)


## A district gate across a street at `pos`, its plaque facing `face` (the side people
## come from), with the district's name on it.
static func _district_gate(root: Node3D, id: String, pos: Vector3, face: Vector3, accent: Color, title: String) -> void:
	var yaw := atan2(face.x, face.z)
	JapanKit.district_gate(_at(id, pos, yaw), GATE_HALF * 2.0, accent)
	var across := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	for s in [-1.0, 1.0]:
		JapanKit.collider(root, pos + across * s * GATE_HALF + Vector3(0, 2.4, 0), Vector3(0.8, 4.8, 0.8), yaw)
	_sign(root, title, pos + Vector3(0, 4.55, 0) + face.normalized() * 0.47, yaw)


## A name painted on a plaque: readable from the front only, gone at a distance.
static func _sign(root: Node3D, text: String, pos: Vector3, yaw: float, size := 1.0) -> void:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0075 * size
	label.outline_size = 10
	label.modulate = Color("fff6e0")
	label.outline_modulate = Color("3a2418")
	label.double_sided = false
	label.position = pos
	label.rotation.y = yaw
	label.visibility_range_end = 42.0
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(label)


## The warm glow of the town: additive soft dots over every lantern flame, no lights.
## Split into 48 m squares so each is only drawn near the camera (a few draw calls).
static func _lantern_halos(root: Node3D) -> void:
	if _halos.is_empty() or GameSettings.safe_picture:
		return
	var cells: Dictionary = {}
	for entry in _halos:
		var p: Vector3 = entry[0]
		var cell := Vector2i(floori(p.x / 48.0), floori(p.z / 48.0))
		if not cells.has(cell):
			var fresh_t: Array[Transform3D] = []
			var fresh_c: Array[Color] = []
			cells[cell] = [fresh_t, fresh_c]
		var t: Array[Transform3D] = cells[cell][0]
		var c: Array[Color] = cells[cell][1]
		t.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.7), p))
		c.append(Color(entry[1], 0.42))
		t.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.7), p))
		c.append(Color((entry[1] as Color).lightened(0.3), 0.55))
	for cell in cells:
		var halos := Scenery._billboards(root, "LanternHalos_%d_%d" % [cell.x, cell.y], cells[cell][0], cells[cell][1], true)
		halos.visibility_range_end = 70.0 * GameSettings.view_scale()


# ---------------------------------------------------------------------------
# The plaza
# ---------------------------------------------------------------------------

static func _plaza(root: Node3D, clear: Array[Vector3]) -> void:
	var plaza := MeshInstance3D.new()
	plaza.name = "PlazaStones"
	var disc := CylinderMesh.new()
	disc.top_radius = PLAZA_RADIUS
	disc.bottom_radius = PLAZA_RADIUS
	disc.height = 0.06
	disc.radial_segments = 48
	plaza.mesh = disc
	# Flagstones: the shader lays slabs in world metres over the plain disc.
	var flags := ShaderMaterial.new()
	flags.shader = load("res://shaders/stone_flags.gdshader")
	flags.set_shader_parameter("stone_color", Color("d2c4ab"))
	flags.set_shader_parameter("mortar_color", Color("8e8372"))
	plaza.material_override = flags
	plaza.position = Vector3(0, 0.02, 0)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(plaza)
	# The great sakura on a two-tier stone terrace with a vermilion and gold rail, a
	# ring of eight stone lanterns, benches facing the tree and two flower beds.
	_piece(root, "SakuraPlanter", Vector3.ZERO, 0.0, func(b: JapanKit.Batch):
		b.cyl(Vector3(0, 0.25, 0), 4.4, 0.5, JapanKit.STONE_DARK, Vector3.ZERO, 20)
		b.cyl(Vector3(0, 0.51, 0), 4.2, 0.04, JapanKit.STONE, Vector3.ZERO, 20)
		b.cyl(Vector3(0, 0.75, 0), 3.3, 0.5, JapanKit.STONE, Vector3.ZERO, 18)
		b.cyl(Vector3(0, 1.01, 0), 3.05, 0.04, Color("6a5a40"), Vector3.ZERO, 18)
		for i in 16:
			var a := TAU * i / 16.0
			b.box(Vector3(cos(a) * 3.2, 1.25, sin(a) * 3.2), Vector3(0.14, 0.5, 0.14), JapanKit.VERMILION)
			b.box(Vector3(cos(a) * 3.2, 1.52, sin(a) * 3.2), Vector3(0.22, 0.06, 1.3), JapanKit.GOLD.darkened(0.1), Vector3(0, -rad_to_deg(a), 0))
		for i in 4:
			var a := TAU * i / 4.0
			b.box(Vector3(cos(a), 0, sin(a)) * 4.65 + Vector3(0, 0.12, 0), Vector3(0.6, 0.24, 1.8), JapanKit.STONE, Vector3(0, -rad_to_deg(a), 0))
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			JapanKit.toro(b, Vector3(cos(a), 0, sin(a)) * 7.0, 1.0)
			JapanKit.bench(b, Vector3(cos(a), 0, sin(a)) * 9.7, -rad_to_deg(a) - 90.0, 2.2)
		for a in [-PI * 0.75, -PI * 0.25]:
			var c := Vector3(cos(a), 0, sin(a)) * 11.0
			b.cyl(c + Vector3(0, 0.2, 0), 1.6, 0.4, JapanKit.STONE_DARK, Vector3.ZERO, 12)
			b.cyl(c + Vector3(0, 0.41, 0), 1.4, 0.04, Color("5a4a36"), Vector3.ZERO, 12)
			for j in 8:
				var fa: float = TAU * j / 8.0 + a
				var fp := c + Vector3(cos(fa) * 0.85, 0.55, sin(fa) * 0.85)
				b.box(fp, Vector3(0.4, 0.3, 0.4), Color("6f9a52"), Vector3(0, j * 33.0, 0))
				b.box(fp + Vector3(0, 0.2, 0), Vector3(0.26, 0.18, 0.26), [Color("f08aa8"), Color("f6d35a"), Color("f4f0e6"), Color("c89ae8")][j % 4], Vector3(0, j * 47.0, 0))
		# A kerb of dressed stone round the plaza, open to the four streets, with tall
		# lanterns at each opening and a line of paper lanterns across it.
		for i in 40:
			var a := TAU * (i + 0.5) / 40.0
			var p := Vector3(cos(a), 0, sin(a)) * (PLAZA_RADIUS + 0.3)
			if absf(p.x) < 7.0 or absf(p.z) < 7.0:
				continue
			b.box(p + Vector3(0, 0.2, 0), Vector3(0.6, 0.4, 2.3), JapanKit.STONE, Vector3(0, -rad_to_deg(a), 0))
		for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			var across := Vector3(dir.z, 0, -dir.x)
			for s in [-1.0, 1.0]:
				JapanKit.toro(b, dir * (PLAZA_RADIUS + 0.8) + across * s * 7.8, 1.35)
			_overhead_line(dir * (PLAZA_RADIUS + 1.2) - across * 6.6, dir * (PLAZA_RADIUS + 1.2) + across * 6.6, 6,
				[Color("e8463a"), Color("f6efe0"), Color("f0b040")])
		, Vector3(7.0, 2.0, 7.0))
	NatureKit.place(root, "GreatSakura", "MapleTree_1", &"village", [Transform3D(Basis.from_scale(Vector3.ONE * 2.9), Vector3(0, 0.95, 0))], [], true, 140.0)
	clear.append(Vector3(0, 0, PLAZA_RADIUS + 1.5))


# ---------------------------------------------------------------------------
# The shrine district (north)
# ---------------------------------------------------------------------------

static func _shrine_quarter(root: Node3D, clear: Array[Vector3]) -> void:
	_piece(root, "Shrine", SHRINE, 0.0, func(b): JapanKit.shrine(b), Vector3(11.0, 6.0, 9.0), Vector3.ZERO, SHRINE_SCALE)
	clear.append(Vector3(SHRINE.x, SHRINE.z, 11.0))
	# The grand torii is the district's gate; two more make a tunnel up the approach.
	_piece(root, "GrandTorii", Vector3(0, 0, -22), 0.0, func(b: JapanKit.Batch):
		JapanKit.torii(b, 7.0, 8.6)
		b.box(Vector3(0, 7.55, 0.2), Vector3(1.9, 1.2, 0.12), Color("2a2a2a"))
		b.box(Vector3(0, 7.55, 0.27), Vector3(1.6, 0.95, 0.04), JapanKit.GOLD.darkened(0.1))
		for x in [-1.0, 1.0]:
			JapanKit.chochin(b, Vector3(x * 2.4, 5.6, 0.3), Color("e8463a"), 1.5)
		)
	for x in [-1.0, 1.0]:
		JapanKit.collider(root, Vector3(x * 3.5, 2.5, -22), Vector3(0.8, 5.0, 0.8))
	_sign(root, "ศาลเจ้า", Vector3(0, 7.55, -21.71), 0.0, 0.8)
	var b := _d("shrine")
	for z in [-34.0, -46.0]:
		b.xform = Transform3D(Basis(), Vector3(0, 0, z))
		JapanKit.torii(b, 5.0, 6.0)
		for x in [-1.0, 1.0]:
			JapanKit.chochin(b, Vector3(x * 1.5, 4.0, 0.25), Color("f6efe0"), 1.0)
		for x in [-1.0, 1.0]:
			JapanKit.collider(root, Vector3(x * 2.5, 2.5, z), Vector3(0.6, 5.0, 0.6))
	b = _d("shrine")
	for z in [-27.0, -31.0, -39.0, -43.0, -51.0, -55.0]:
		for x in [-1.0, 1.0]:
			JapanKit.toro(b, Vector3(x * 4.4, 0, z), 1.0)
	# Shrine fence, the purification basin and white banners.
	JapanKit.fence(b, SHRINE + Vector3(-9.5, 0, 7.5), SHRINE + Vector3(-9.5, 0, -7.0))
	JapanKit.fence(b, SHRINE + Vector3(9.5, 0, 7.5), SHRINE + Vector3(9.5, 0, -7.0))
	b.box(SHRINE + Vector3(-6.0, 0.45, 9.0), Vector3(1.8, 0.9, 1.1), JapanKit.STONE_DARK)
	b.box(SHRINE + Vector3(-6.0, 0.92, 9.0), Vector3(1.5, 0.04, 0.8), Color("4a7a9a"))
	b.roof(SHRINE + Vector3(-6.0, 2.6, 9.0), 2.6, 2.0, 0.7, JapanKit.COPPER, 0.8)
	for x in [-1.0, 1.0]:
		b.box(SHRINE + Vector3(-6.0 + x * 1.0, 1.15, 9.0), Vector3(0.14, 2.3, 0.14), JapanKit.VERMILION)
	for x in [-1.0, 1.0]:
		JapanKit.banner(b, SHRINE + Vector3(x * 7.4, 0, 8.4), Color("e8e0d0"))
		JapanKit.banner(b, Vector3(x * 5.6, 0, -24.5), Color("e8e0d0"))
	_piece(root, "Pagoda", PAGODA, 0.3, func(pb): JapanKit.pagoda(pb), Vector3(7.0, 12.0, 7.0), Vector3.ZERO, 1.25)
	clear.append(Vector3(PAGODA.x, PAGODA.z, 8.0))
	clear.append(Vector3(0, -40, 7.0))
	var trees: Array[Transform3D] = []
	for spot in [Vector3(-13, 0, -30), Vector3(-17, 0, -40), Vector3(-15, 0, -50), Vector3(-13, 0, -62), Vector3(12, 0, -30), Vector3(10, 0, -64), Vector3(-19, 0, -58)]:
		trees.append(Transform3D(Basis(Vector3.UP, spot.x).scaled(Vector3.ONE * 1.5), spot))
		JapanKit.collider(root, spot + Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0))
		clear.append(Vector3(spot.x, spot.z, 3.0))
	NatureKit.place(root, "ShrineSakura", "MapleTree_4", &"village", trees)


# ---------------------------------------------------------------------------
# The market street (east): every world player's stall is here
# ---------------------------------------------------------------------------

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
	_piece(root, "TeaHouse", TEA_HOUSE, 0.0, func(b: JapanKit.Batch):
		JapanKit.shop(b, 9.0, 6.5, Color("4a8f5c"), JapanKit.WOOD_DARK, 2, "cup")
		for x in [-1.0, 1.0]:
			JapanKit.chochin(b, Vector3(x * 3.6, 2.7, 3.9), Color("f0b040"), 1.3)
		, Vector3(9.2, 6.0, 6.6))
	_piece(root, "SweetShop", SWEETS, PI, func(b: JapanKit.Batch):
		JapanKit.shop(b, 9.0, 6.5, Color("e87aa0"), Color("8a4a5a"), 1, "scroll")
		for x in [-1.0, 1.0]:
			JapanKit.chochin(b, Vector3(x * 3.6, 2.7, 3.9), Color("f08aa8"), 1.3)
		, Vector3(9.2, 6.0, 6.6))
	for p in [SHOP, FORGE, KURA, IZAKAYA, TEA_HOUSE, SWEETS]:
		clear.append(Vector3(p.x, p.z, 6.5))
	# A booth behind every stall spot, its awning in one of the market's colours and a
	# paper lantern on the post; the keeper stands in front of it facing the walkway.
	var awnings := [Color("e8463a"), Color("2f4f8a"), Color("f0b040"), Color("4a8f5c"), Color("e87aa0"), Color("f6efe0")]
	var goods := [[Color("e8a040"), Color("c8d070"), Color("e86a5a")], [Color("f0e0b0"), Color("8ac8e8"), Color("e8a040")],
		[Color("c89ae8"), Color("f4f0e6"), Color("6ab04a")]]
	var bb: JapanKit.Batch = null
	for i in STALLS.size():
		var spot: Vector3 = STALLS[i]
		var front := stall_face(spot)
		var at := spot - front * 2.1
		# Two neighbouring booths share one overhead mesh (one draw, faded together).
		var near := i > 0 and bb != null and absf(STALLS[i - 1].x - spot.x) < 3.0 and signf(STALLS[i - 1].z) == signf(spot.z)
		if near and bb.get_meta("pair", false):
			bb = _overhead(at, atan2(front.x, front.z))
		elif near:
			bb.set_meta("pair", true)
			bb.xform = Transform3D(Basis(Vector3.UP, atan2(front.x, front.z)), at)
		else:
			bb = _overhead(at, atan2(front.x, front.z))
		JapanKit.market_booth(bb, 2.4, 1.3, awnings[i % awnings.size()], goods[i % goods.size()])
		JapanKit.chochin(bb, Vector3(-1.2, 2.0, 0.75), [Color("e8463a"), Color("f6efe0"), Color("f0b040")][i % 3], 0.75)
		JapanKit.collider(root, at + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 1.1), atan2(front.x, front.z))
		clear.append(Vector3(at.x, at.z, 2.0))
	var b := _d("market")
	for x in [24.0, 41.5, 65.5]:
		_overhead_line(Vector3(x, 0, -STALL_ROW - 0.6), Vector3(x, 0, STALL_ROW + 0.6), 6, [Color("e8463a"), Color("f6efe0"), Color("f0b040")])
	JapanKit.banner(b, SHOP + Vector3(-5.2, 0, 4.2), Color("2f4f8a"))
	JapanKit.banner(b, FORGE + Vector3(-4.7, 0, 4.2), Color("8a2f2a"))
	JapanKit.banner(b, IZAKAYA + Vector3(4.7, 0, -4.2), Color("d8452e"))
	JapanKit.banner(b, TEA_HOUSE + Vector3(5.2, 0, 4.2), Color("4a8f5c"))
	JapanKit.banner(b, SWEETS + Vector3(-5.2, 0, -4.2), Color("e87aa0"))
	# Crates, barrels and a parasol over a bench at the street's end.
	for spec in [[Vector3(31.2, 0, -9.4), 10.0], [Vector3(45.0, 0, -9.4), -12.0], [Vector3(31.2, 0, 9.4), 25.0], [Vector3(45.0, 0, 9.4), 5.0]]:
		var p: Vector3 = spec[0]
		b.box(p + Vector3(0, 0.3, 0), Vector3(0.7, 0.6, 0.7), Color("a07a48"), Vector3(0, spec[1], 0))
		b.box(p + Vector3(0.2, 0.85, 0.1), Vector3(0.5, 0.5, 0.5), Color("8a6a40"), Vector3(0, spec[1] + 30.0, 0))
		b.cyl(p + Vector3(-0.9, 0.45, 0), 0.38, 0.9, Color("7a5a38"), Vector3.ZERO, 8)
	JapanKit.parasol(b, Vector3(64.5, 0, -10.0), Color("d8452e"))
	JapanKit.bench(b, Vector3(64.5, 0, -8.6), 0.0, 2.0)
	JapanKit.parasol(b, Vector3(64.0, 0, 10.0), Color("e87aa0"))
	JapanKit.bench(b, Vector3(64.0, 0, 8.6), 180.0, 2.0)
	_district_gate(root, "market", Vector3(18, 0, 0), Vector3.LEFT, Color("c8352e"), "ถนนตลาด")


# ---------------------------------------------------------------------------
# The training district (west)
# ---------------------------------------------------------------------------

static func _west(root: Node3D, clear: Array[Vector3], rng: RandomNumberGenerator) -> void:
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
	_piece(root, "ElderHouse", ELDER_HOUSE, PI, func(b: JapanKit.Batch):
		JapanKit.house(b, 9.0, 7.0, 3.2, JapanKit.TILE_DARK, 2)
		JapanKit.fence(b, Vector3(-6.0, 0, 6.0), Vector3(-1.6, 0, 6.0))
		JapanKit.fence(b, Vector3(1.6, 0, 6.0), Vector3(6.0, 0, 6.0))
		JapanKit.flower_box(b, Vector3(-2.97, 1.0, 3.75), 2.0, 0.0)
		JapanKit.flower_box(b, Vector3(2.97, 1.0, 3.75), 2.0, 0.0)
		for x in [-1.0, 1.0]:
			JapanKit.chochin(b, Vector3(x * 2.2, 2.9, 4.2), Color("f6efe0"), 1.0)
		, Vector3(9.4, 6.0, 7.4))
	clear.append(Vector3(ELDER_HOUSE.x, ELDER_HOUSE.z, 8.0))
	# The practice yard: posts, a row of archery targets, a weapon rack and benches.
	var b := _at("training", Vector3(-53, 0, -7), PI * 0.5)
	for z in [-4.0, 0.0, 4.0]:
		JapanKit.target(b, Vector3(z, 0, -7.0))
	for i in 4:
		b.cyl(Vector3(-5.0 + i * 3.3, 0.9, 2.0), 0.2, 1.8, JapanKit.WOOD_LIGHT, Vector3.ZERO, 8)
		b.box(Vector3(-5.0 + i * 3.3, 1.25, 2.0), Vector3(0.8, 0.12, 0.12), JapanKit.WOOD)
	b.box(Vector3(0, 0.9, 6.0), Vector3(3.2, 0.12, 0.3), JapanKit.WOOD_DARK)
	b.box(Vector3(0, 1.6, 6.0), Vector3(3.2, 0.12, 0.3), JapanKit.WOOD_DARK)
	for i in 6:
		b.cyl(Vector3(-1.3 + i * 0.52, 1.25, 6.05), 0.04, 2.2, JapanKit.WOOD_LIGHT if i % 2 else Color("8a8a92"), Vector3(-8, 0, 0), 5)
	JapanKit.bench(b, Vector3(6.5, 0, 4.0), -90.0, 2.4)
	clear.append(Vector3(-53, -7, 8.0))
	b = _d("training")
	JapanKit.well(_at("training", Vector3(-48, 0, 9), 0.0))
	JapanKit.collider(root, Vector3(-48, 1.0, 9), Vector3(2.0, 2.0, 2.0))
	clear.append(Vector3(-48, 9, 2.5))
	b = _d("training")
	for spec in [[Vector3(-22.5, 0, -5.6), Color("1e2a4a")], [Vector3(-41.5, 0, -5.6), Color("1e2a4a")], [Vector3(-22.5, 0, 5.6), Color("f4ead0")], [Vector3(-41.5, 0, 5.6), Color("f4ead0")]]:
		JapanKit.banner(b, spec[0], spec[1])
	for x in [-26.0, -44.0, -58.0]:
		_overhead_line(Vector3(x, 0, -4.7), Vector3(x, 0, 4.7), 4, [Color("f6efe0"), Color("4a6ad0")])
	# A pine or two for the dojo's garden.
	NatureKit.place(root, "DojoPines", "PineTree_2", &"village", [Transform3D(Basis(Vector3.UP, 1.0).scaled(Vector3.ONE * 1.2), Vector3(-44, 0, -14)),
		Transform3D(Basis(Vector3.UP, 2.0).scaled(Vector3.ONE * 1.1), Vector3(-20.5, 0, 14))])
	for p in [Vector3(-44, 0, -14), Vector3(-20.5, 0, 14)]:
		JapanKit.collider(root, p + Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0))
		clear.append(Vector3(p.x, p.z, 2.5))
	_district_gate(root, "training", Vector3(-18, 0, 0), Vector3.RIGHT, Color("2f4f8a"), "ย่านฝึกยุทธ์")


# ---------------------------------------------------------------------------
# The arena and guild district (south-east)
# ---------------------------------------------------------------------------

static func _arena(root: Node3D, clear: Array[Vector3]) -> void:
	_piece(root, "SparringRing", RING, 0.0, func(b: JapanKit.Batch):
		JapanKit.ring(b, 6.5)
		for i in 8:
			var a := TAU * i / 8.0
			JapanKit.banner(b, Vector3(cos(a) * 8.2, 0, sin(a) * 8.2), [Color("c83a3a"), Color("2f4f8a"), Color("e8c050")][i % 3])
		# Spectator steps east and west, a judge's drum at the south side.
		for x in [-1.0, 1.0]:
			for k in 3:
				b.box(Vector3(x * (10.0 + k * 0.8), 0.2 + k * 0.2, 0), Vector3(0.8, 0.4 + k * 0.4, 7.0), JapanKit.WOOD_LIGHT if k % 2 == 0 else JapanKit.WOOD)
		b.cyl(Vector3(0, 1.2, 9.2), 0.7, 1.0, Color("b8352e"), Vector3(90, 0, 0), 12)
		for x in [-0.6, 0.6]:
			b.box(Vector3(x, 0.6, 9.2), Vector3(0.12, 1.2, 0.12), JapanKit.WOOD_DARK)
		)
	clear.append(Vector3(RING.x, RING.z, 10.0))
	_piece(root, "GuildKeep", GUILD_HALL, 0.0, func(b: JapanKit.Batch):
		JapanKit.castle_keep(b)
		for x in [-1.0, 1.0]:
			JapanKit.banner(b, Vector3(x * 5.2, 0, 5.4), Color("c83a3a") if x < 0 else Color("2f4f8a"))
			JapanKit.chochin(b, Vector3(x * 1.6, 3.4, 4.0), Color("f0b040"), 1.2)
		, Vector3(12.0, 15.0, 10.2))
	clear.append(Vector3(GUILD_HALL.x, GUILD_HALL.z, 8.0))
	var b := _d("arena")
	for x in [26.0, 54.0]:
		_overhead_line(Vector3(x, 0, CROSS_Z - 4.7), Vector3(x, 0, CROSS_Z + 4.7), 5, [Color("c83a3a"), Color("f6efe0"), Color("2f4f8a")])
	for x in [24.0, 56.0]:
		JapanKit.toro(b, Vector3(x, 0, CROSS_Z - 6.0), 1.2)
	_district_gate(root, "arena", Vector3(18, 0, CROSS_Z), Vector3.LEFT, Color("a83a5a"), "ลานประลอง · หอกิลด์")


# ---------------------------------------------------------------------------
# The gate avenue and the homes with their gardens (south)
# ---------------------------------------------------------------------------

## The sakura along the gate avenue (x, z).
static func _avenue_trees() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z in [24.0, 33.0, 49.0, 60.0]:
		for x in [-5.6, 5.6]:
			out.append(Vector2(x, z))
	return out


static func _south(root: Node3D, clear: Array[Vector3], rng: RandomNumberGenerator) -> void:
	# Homes along the avenue, two on each side, with flower boxes under their windows.
	for spec in [[Vector3(-11, 0, 26), PI * 0.5, 1], [Vector3(-11, 0, 54), PI * 0.5, 2], [Vector3(11, 0, 26), -PI * 0.5, 2], [Vector3(11, 0, 54), -PI * 0.5, 1]]:
		var pos: Vector3 = spec[0]
		_piece(root, "Home", pos, spec[1], func(hb: JapanKit.Batch):
			JapanKit.house(hb, 7.5, 6.0, 3.0, JapanKit.TILE if spec[2] == 1 else JapanKit.TILE_DARK, spec[2])
			JapanKit.flower_box(hb, Vector3(-2.47, 1.05, 3.25), 1.6, 0.0)
			JapanKit.flower_box(hb, Vector3(2.47, 1.05, 3.25), 1.6, 0.0)
			JapanKit.chochin(hb, Vector3(0, 2.75, 3.95), Color("f6efe0"), 0.9)
			, Vector3(7.9, 6.0, 6.4))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	# The great gate (the road to the meadow passes through it) and its wing walls.
	_piece(root, "VillageGate", GATE, 0.0, func(gb: JapanKit.Batch): JapanKit.grand_gate(gb, 8.0))
	for x in [-7.0, -4.0, 4.0, 7.0]:
		JapanKit.collider(root, GATE + Vector3(x, 2.7, 0), Vector3(0.9, 5.4, 3.6))
	_sign(root, "หมู่บ้านมิสต์วูด", GATE + Vector3(0, 5.15, 1.81), 0.0, 0.85)
	clear.append(Vector3(GATE.x, GATE.z, 9.0))
	var b := _d("avenue")
	for z in [22.0, 30.0, 45.5, 56.0, 64.0]:
		_overhead_line(Vector3(-4.3, 0, z), Vector3(4.3, 0, z), 5, [Color("e8463a"), Color("f6efe0"), Color("f0b040")])
	for z in [37.0, 43.0]:
		for x in [-1.0, 1.0]:
			JapanKit.toro(b, Vector3(x * 5.2, 0, z), 1.1)
	for x in [-1.0, 1.0]:
		JapanKit.toro(b, GATE + Vector3(x * 6.0, 0, -4.5), 1.3)
		JapanKit.banner(b, GATE + Vector3(x * 9.0, 0, 2.6), Color("d8452e"))
	var trees: Array[Transform3D] = []
	for t in _avenue_trees():
		var s := rng.randf_range(1.05, 1.3)
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(t.x, 0, t.y)))
		JapanKit.collider(root, Vector3(t.x, 1.5, t.y), Vector3(0.9, 3.0, 0.9))
		clear.append(Vector3(t.x, t.y, 2.5))
		for k in 4:
			var side := Vector3(0, 0, 0.8).rotated(Vector3.UP, k * PI * 0.5)
			b.box(Vector3(t.x, 0.1, t.y) + side, Vector3(1.8, 0.2, 0.22), JapanKit.STONE, Vector3(0, k * 90.0, 0))
	NatureKit.place(root, "StreetSakura", "NormalTree_5", &"village", trees)
	# The homes district behind its gate: houses, a koi pond with a red bridge and a
	# pavilion, red maples and benches.
	for spec in [[Vector3(-28, 0, 28), 0.0, JapanKit.TILE], [Vector3(-46, 0, 28), 0.0, Color("6a5a48")], [Vector3(-48, 0, 50), PI, JapanKit.TILE]]:
		var pos: Vector3 = spec[0]
		_piece(root, "House", pos, spec[1], func(hb: JapanKit.Batch):
			JapanKit.house(hb, 7.0, 5.5, 3.0, spec[2], 1)
			JapanKit.fence(hb, Vector3(-5.0, 0, 4.6), Vector3(-1.4, 0, 4.6))
			JapanKit.fence(hb, Vector3(1.4, 0, 4.6), Vector3(5.0, 0, 4.6))
			JapanKit.flower_box(hb, Vector3(-2.3, 1.0, 3.0), 1.4, 0.0)
			JapanKit.chochin(hb, Vector3(0, 2.7, 3.7), Color("f0b040"), 0.9)
			, Vector3(7.4, 6.0, 5.9))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	var pond := Node3D.new()
	pond.name = "KoiPond"
	pond.position = POND
	root.add_child(pond)
	var pb := JapanKit.Batch.new()
	JapanKit.pond_rim(pb, Vector2(8.0, 6.0), rng)
	JapanKit.bridge(pb, 9.5)
	for i in 6:
		var a := rng.randf() * TAU
		pb.ball(Vector3(cos(a) * rng.randf_range(1.5, 5.5), 0.1, sin(a) * rng.randf_range(1.0, 4.0)), Vector3(0.5, 0.12, 0.22), [Color("f08a3a"), Color("f6f0e8"), Color("e8463a")][i % 3])
	JapanKit.toro(pb, Vector3(7.2, 0, -5.5), 0.9)
	JapanKit.toro(pb, Vector3(-7.4, 0, 4.8), 0.9)
	pb.commit(pond, "PondRim")
	_halos.append_array(pb.lights)
	JapanKit.water(pond, Vector3.ZERO, Vector2(7.8, 5.8))
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.8
	cyl.height = 2.0
	shape.shape = cyl
	shape.scale = Vector3(1.0, 1.0, 0.8)
	shape.position = Vector3(0, 1.0, 0)
	body.add_child(shape)
	pond.add_child(body)
	clear.append(Vector3(POND.x, POND.z, 9.5))
	JapanKit.pavilion(_at("homes", Vector3(-40, 0, 46), PI))
	JapanKit.collider(root, Vector3(-40, 1.5, 46), Vector3(3.8, 3.0, 3.8))
	clear.append(Vector3(-40, 46, 3.5))
	b = _d("homes")
	for p in [Vector3(-21, 0, 46), Vector3(-21, 0, 61)]:
		JapanKit.bench(b, p, 90.0, 2.0)
	JapanKit.parasol(b, Vector3(-21.5, 0, 49), Color("d8452e"), 0.9)
	for x in [-26.0, -42.0, -54.0]:
		_overhead_line(Vector3(x, 0, CROSS_Z - 4.7), Vector3(x, 0, CROSS_Z + 4.7), 4, [Color("f0b040"), Color("f6efe0")])
	var maples: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot in [Vector3(-19, 0, 55), Vector3(-41, 0, 57), Vector3(-36, 0, 33), Vector3(-56, 0, 38)]:
		maples.append(Transform3D(Basis(Vector3.UP, spot.z).scaled(Vector3.ONE * 1.25), spot))
		tints.append(Color("ff4a3a"))
		JapanKit.collider(root, spot + Vector3(0, 1.5, 0), Vector3(0.9, 3.0, 0.9))
		clear.append(Vector3(spot.x, spot.z, 2.5))
	NatureKit.place(root, "RedMaples", "MapleTree_4", &"village", maples, tints)
	_district_gate(root, "homes", Vector3(-18, 0, CROSS_Z), Vector3.RIGHT, Color("4a8f5c"), "ย่านบ้านพัก · สวนปลาคาร์ป")


# ---------------------------------------------------------------------------
# The rice fields (north-east) and the bamboo grove (north-west)
# ---------------------------------------------------------------------------

const FARMHOUSES := [[Vector3(58, 0, -28), -0.6], [Vector3(34, 0, -57), 0.4]]


static func _farm(root: Node3D, clear: Array[Vector3]) -> void:
	for spec in FARMHOUSES:
		var pos: Vector3 = spec[0]
		_piece(root, "Farmhouse", pos, spec[1], func(b): JapanKit.house(b, 7.0, 5.5, 2.8, JapanKit.THATCH, 1), Vector3(7.4, 6.0, 5.9))
		clear.append(Vector3(pos.x, pos.z, 6.5))
	_piece(root, "RiceFields", Vector3(45, 0, -40), 0.0, func(b: JapanKit.Batch):
		for i in 3:
			for j in 2:
				var c := Vector3(-8.0 + i * 8.0, 0, -3.25 + j * 6.5)
				b.box(c + Vector3(0, 0.1, 0), Vector3(7.4, 0.2, 6.0), Color("8a7a5a"))
				b.box(c + Vector3(0, 0.21, 0), Vector3(6.8, 0.02, 5.4), Color("7aa8a0"))
				for r in 6:
					for k in 5:
						b.cyl(c + Vector3(-3.0 + r * 1.2, 0.45, -2.2 + k * 1.1), 0.12, 0.5, Color("6ab04a"), Vector3.ZERO, 4)
		JapanKit.scarecrow(b, Vector3(-4.0, 0, 0))
		JapanKit.scarecrow(b, Vector3(4.0, 0, 0.2))
		)
	clear.append(Vector3(45, -40, 13.0))


static func _grove(root: Node3D, rng: RandomNumberGenerator) -> void:
	var b := _d("grove")
	var centre := Vector3(-44, 0, -42)
	for i in 14:
		var a := TAU * (i + rng.randf() * 0.4) / 14.0
		var p := centre + Vector3(cos(a), 0, sin(a)) * rng.randf_range(9.0, 14.0)
		if Vector2(p.x, p.z).length() > RADIUS - 8.0:
			continue
		JapanKit.bamboo(b, p, rng, 6)
	JapanKit.pavilion(_at("grove", centre, 0.6))
	b = _d("grove")
	JapanKit.toro(b, centre + Vector3(3.5, 0, 3.0), 1.0)
	JapanKit.toro(b, centre + Vector3(-3.6, 0, -2.6), 1.0)
	JapanKit.bench(b, centre + Vector3(0, 0, 4.6), 0.0, 2.0)
	JapanKit.collider(root, centre + Vector3(0, 1.5, 0), Vector3(3.8, 3.0, 3.8), 0.6)
	var maples: Array[Transform3D] = []
	var tints: Array[Color] = []
	for spot in [centre + Vector3(6, 0, -5), centre + Vector3(-7, 0, 5)]:
		maples.append(Transform3D(Basis(Vector3.UP, spot.x).scaled(Vector3.ONE * 1.2), spot))
		tints.append(Color("ff4a3a"))
		JapanKit.collider(root, spot + Vector3(0, 1.5, 0), Vector3(0.9, 3.0, 0.9))
	NatureKit.place(root, "GroveMaples", "MapleTree_4", &"village", maples, tints)


# ---------------------------------------------------------------------------
# Lived-in detail in the districts' open lots
# ---------------------------------------------------------------------------

## Sakura over a bench in the districts' lots (their pits stay green).
const LANE_SAKURA: Array[Vector2] = [Vector2(-44, 16.5), Vector2(60.5, 24), Vector2(-36.5, 29.5), Vector2(-22.5, 57)]


## A prop in district `id` at `pos` facing `face` (its front = local +z), with a
## collider `size` (none for ZERO).
static func _prop(root: Node3D, id: String, pos: Vector3, face: Vector3, size := Vector3.ZERO) -> JapanKit.Batch:
	var yaw := atan2(face.x, face.z)
	if size != Vector3.ZERO:
		JapanKit.collider(root, pos + Vector3(0, size.y * 0.5, 0), size, yaw)
	return _at(id, pos, yaw)


## The warm, lived-in clutter of a Japanese town filling each district's open lots
## (found with a probe for cells with nothing within 3.5 m), every piece at least 2 m
## inside the hedge: offering sake barrels,
## prayer racks, wayside shrines and koi channels at the shrine; carts, firewood,
## laundry and vegetable beds in the homes and the training quarter; a festival corner
## with a drum by the ring; planters and gardens at the avenue's ends. All of it merges
## into the districts' batches; the streets stay clear.
static func _lived_in(root: Node3D) -> void:
	var E := Vector3.RIGHT
	var W := Vector3.LEFT
	var S := Vector3.BACK
	var N := Vector3.FORWARD
	var sacks := [Color("e8dcc0"), Color("d8c8a0"), Color("c8b088"), Color("e8dcc0"), Color("b8905a")]
	# Shrine: sake-barrel offerings and prayer racks either side of the approach,
	# wayside shrines with a lantern in the back corners, koi channels along the walls,
	# garden beds and benches under the sakura.
	JapanKit.sake_barrels(_prop(root, "shrine", Vector3(-8.5, 0, -50), E, Vector3(4.2, 2.6, 1.4)), 4, 2)
	JapanKit.sake_barrels(_prop(root, "shrine", Vector3(8.5, 0, -50), W, Vector3(4.2, 2.6, 1.4)), 4, 2)
	JapanKit.prayer_rack(_prop(root, "shrine", Vector3(-8.5, 0, -38), E, Vector3(2.5, 2.0, 0.5)), Color("d8b07a"))
	JapanKit.prayer_rack(_prop(root, "shrine", Vector3(8.5, 0, -38), W, Vector3(2.5, 2.0, 0.5)), Color("f4f0e6"))
	for spec in [[Vector3(-16, 0, -71), S], [Vector3(14, 0, -70), S]]:
		JapanKit.hokora(_prop(root, "shrine", spec[0], spec[1], Vector3(1.5, 1.8, 1.4)))
		JapanKit.toro(_d("shrine"), spec[0] + Vector3(1.9, 0, 0.6), 0.9)
	JapanKit.koi_channel(_prop(root, "shrine", Vector3(-19.5, 0, -63), S, Vector3(2.1, 0.5, 16.4)), 16.0)
	JapanKit.koi_channel(_prop(root, "shrine", Vector3(19.5, 0, -65), S, Vector3(2.1, 0.5, 12.4)), 12.0)
	JapanKit.garden_bed(_prop(root, "shrine", Vector3(-13, 0, -56), S, Vector3(5.2, 0.6, 3.2)), 5.0, 3.0)
	JapanKit.garden_bed(_prop(root, "shrine", Vector3(-14, 0, -44), S, Vector3(4.2, 0.6, 3.2)), 4.0, 3.0)
	JapanKit.garden_bed(_prop(root, "shrine", Vector3(14, 0, -61), S, Vector3(4.2, 0.6, 3.2)), 4.0, 3.0)
	# Paper-lantern strings over the approach between the torii, more beds and lanterns
	# in the front gardens.
	for z in [-28.0, -40.0, -52.0]:
		_overhead_line(Vector3(-5.6, 0, z), Vector3(5.6, 0, z), 6, [Color("f6efe0"), Color("e8463a")])
	for x in [-1.0, 1.0]:
		JapanKit.garden_bed(_prop(root, "shrine", Vector3(x * 15, 0, -26.5), S, Vector3(5.2, 0.6, 2.7)), 5.0, 2.5)
		JapanKit.planter(_prop(root, "shrine", Vector3(x * 7.2, 0, -31), E if x < 0 else W, Vector3(3.0, 0.9, 0.7)), 3.0)
		for z in [-26.0, -42.0, -58.0]:
			JapanKit.toro(_d("shrine"), Vector3(x * 21.5, 0, z), 1.0)
	var b := _d("shrine")
	JapanKit.bench(b, Vector3(-10, 0, -30), 90.0, 2.2)
	JapanKit.bench(b, Vector3(10, 0, -31), -90.0, 2.2)
	JapanKit.bench(b, Vector3(13, 0, -36), 180.0, 2.2)
	# Training quarter: a woodpile in the corner, a vegetable bed, laundry and a cart
	# behind the well, a bench under a sakura before the dojo street.
	JapanKit.woodpile(_prop(root, "training", Vector3(-63.0, 0, -12), E, Vector3(4.2, 1.2, 1.4)), 2.4)
	JapanKit.garden_bed(_prop(root, "training", Vector3(-60, 0, 11), S, Vector3(4.2, 0.6, 2.7)), 4.0, 2.5)
	JapanKit.laundry_line(_prop(root, "training", Vector3(-58.5, 0, 15.5), S), 7.0)
	JapanKit.cart(_prop(root, "training", Vector3(-52, 0, 14.5), W, Vector3(1.8, 1.4, 3.0)), sacks)
	JapanKit.bench(_d("training"), Vector3(-44, 0, 13.6), 180.0, 2.2)
	# Arena and guild: a festival corner west of the guild keep (a loaded cart, a
	# parasol over a bench, a garden bed), a garden with a wayside shrine east of it,
	# festival drums and offering barrels either side of the ring.
	JapanKit.cart(_prop(root, "arena", Vector3(24.5, 0, 28), E, Vector3(1.8, 1.4, 3.0)), sacks)
	b = _d("arena")
	JapanKit.parasol(b, Vector3(28.5, 0, 32.5), Color("d8452e"))
	JapanKit.bench(b, Vector3(28.5, 0, 31.2), 0.0, 2.0)
	JapanKit.garden_bed(_prop(root, "arena", Vector3(26, 0, 23.5), S, Vector3(5.2, 0.6, 2.7)), 5.0, 2.5)
	JapanKit.garden_bed(_prop(root, "arena", Vector3(56, 0, 30), S, Vector3(5.2, 0.6, 4.2)), 5.0, 4.0)
	JapanKit.hokora(_prop(root, "arena", Vector3(61, 0, 31), W, Vector3(1.5, 1.8, 1.4)))
	for z in [25.5, 34.5]:
		JapanKit.toro(_d("arena"), Vector3(52.5, 0, z), 0.9)
	JapanKit.bench(_d("arena"), Vector3(60.5, 0, 26.6), 180.0, 2.0)
	JapanKit.taiko(_prop(root, "arena", Vector3(24.5, 0, 52), E, Vector3(1.4, 1.9, 1.2)))
	JapanKit.sake_barrels(_prop(root, "arena", Vector3(24.5, 0, 58.5), E, Vector3(3.4, 2.6, 1.4)), 3, 2)
	# A festival canopy: lantern strings crossing over the ring from four corner posts,
	# and two food yatai facing the cross street.
	_overhead_line(Vector3(29.5, 0, 46.5), Vector3(50.5, 0, 60.5), 10, [Color("e8463a"), Color("f6efe0"), Color("f0b040")])
	_overhead_line(Vector3(50.5, 0, 46.5), Vector3(29.5, 0, 60.5), 10, [Color("f0b040"), Color("f6efe0"), Color("e8463a")])
	for spec in [[Vector3(24.5, 0, 47.5), Color("e8463a")], [Vector3(52.5, 0, 46.5), Color("2f4f8a")]]:
		JapanKit.stall(_prop(root, "arena", spec[0], N, Vector3(2.6, 2.4, 1.6)), 2.4, 1.4, spec[1], [Color("e8a040"), Color("f4f0e6"), Color("e86a5a")])
	# The avenue's two ends: flower planters by the plaza, gardens by the village gate.
	for x in [-10.0, 10.0]:
		JapanKit.planter(_prop(root, "avenue", Vector3(x, 0, 16.5), S, Vector3(3.0, 0.9, 0.7)), 3.0)
		JapanKit.garden_bed(_prop(root, "avenue", Vector3(x, 0, 63.5), S, Vector3(4.2, 0.6, 3.2)), 4.0, 3.0)
	# Homes: vegetable beds and laundry in the back yards, a cart, a garden and benches.
	JapanKit.garden_bed(_prop(root, "homes", Vector3(-59, 0, 25.5), S, Vector3(5.2, 0.6, 3.2)), 5.0, 3.0)
	JapanKit.laundry_line(_prop(root, "homes", Vector3(-58, 0, 31.5), S), 7.0)
	JapanKit.woodpile(_prop(root, "homes", Vector3(-63, 0, 21.5), S, Vector3(4.2, 1.2, 1.4)), 2.4)
	JapanKit.garden_bed(_prop(root, "homes", Vector3(-44, 0, 56), S, Vector3(5.2, 0.6, 3.2)), 5.0, 3.0)
	JapanKit.planter(_prop(root, "homes", Vector3(-38, 0, 24), S, Vector3(3.0, 0.9, 0.7)), 3.0)
	JapanKit.planter(_prop(root, "homes", Vector3(-22, 0, 61.5), E, Vector3(3.0, 0.9, 0.7)), 3.0)
	b = _d("homes")
	JapanKit.bench(b, Vector3(-41.5, 0, 60.5), 180.0, 2.0)
	JapanKit.bench(b, Vector3(-36.5, 0, 27.2), 0.0, 2.0)
	JapanKit.bench(b, Vector3(-22.5, 0, 54.6), 0.0, 2.0)
	# Market's east end: the izakaya's barrels and a woodpile.
	JapanKit.sake_barrels(_prop(root, "market", Vector3(64.5, 0, 13), W, Vector3(3.4, 2.6, 1.4)), 3, 2)
	JapanKit.woodpile(_prop(root, "market", Vector3(64.5, 0, -14), W, Vector3(4.2, 1.2, 1.4)), 2.4)
	var trees: Array[Transform3D] = []
	for i in LANE_SAKURA.size():
		var t: Vector2 = LANE_SAKURA[i]
		trees.append(Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3.ONE * 1.05), Vector3(t.x, 0, t.y)))
		JapanKit.collider(root, Vector3(t.x, 1.5, t.y), Vector3(0.9, 3.0, 0.9))
	NatureKit.place(root, "LaneSakura", "MapleTree_4", &"village", trees)


# ---------------------------------------------------------------------------
# District walls, the hedge, orchards and mountains
# ---------------------------------------------------------------------------

## The low walls between the districts, as [from, to] runs (gaps at every gate).
static func wall_runs() -> Array:
	var g := GATE_HALF + 0.6
	return [
		# Shrine district: the front either side of the grand torii, the sides with a
		# small gate to the grove and the rice fields.
		[Vector2(-24, -22), Vector2(-6.6, -22)], [Vector2(6.6, -22), Vector2(24, -22)],
		[Vector2(-24, -22), Vector2(-24, -31.5)], [Vector2(-24, -36.5), Vector2(-24, -70)],
		[Vector2(24, -22), Vector2(24, -31.5)], [Vector2(24, -36.5), Vector2(24, -70)],
		# Market street.
		[Vector2(18, -19), Vector2(18, -g)], [Vector2(18, g), Vector2(18, 19)],
		[Vector2(18, -19), Vector2(66, -19)], [Vector2(18, 19), Vector2(64, 19)],
		# Training district.
		[Vector2(-18, -19), Vector2(-18, -g)], [Vector2(-18, g), Vector2(-18, 19)],
		[Vector2(-18, -19), Vector2(-66, -19)], [Vector2(-18, 19), Vector2(-64, 19)],
		# The avenue's sides (the arena's and the homes' fronts), open at the cross street.
		[Vector2(18, 19), Vector2(18, CROSS_Z - g)], [Vector2(18, CROSS_Z + g), Vector2(18, 70)],
		[Vector2(-18, 19), Vector2(-18, CROSS_Z - g)], [Vector2(-18, CROSS_Z + g), Vector2(-18, 70)],
		# The great gate's wings.
		[Vector2(-18, GATE.z), Vector2(-9.0, GATE.z)], [Vector2(9.0, GATE.z), Vector2(18, GATE.z)],
	]


static func _walls(root: Node3D, clear: Array[Vector3]) -> void:
	var b := JapanKit.Batch.new()
	var body := StaticBody3D.new()
	body.name = "DistrictWalls"
	body.collision_layer = 1
	root.add_child(body)
	for run in wall_runs():
		var a: Vector2 = run[0]
		var c: Vector2 = run[1]
		var from := Vector3(a.x, 0, a.y)
		var to := Vector3(c.x, 0, c.y)
		JapanKit.low_wall(b, from, to)
		var length := from.distance_to(to)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 1.8, length)
		shape.shape = box
		shape.position = (from + to) * 0.5 + Vector3(0, 0.9, 0)
		shape.rotation.y = atan2(to.x - from.x, to.z - from.z)
		body.add_child(shape)
		var steps := int(length / 5.0) + 1
		for k in steps + 1:
			var p := a.lerp(c, float(k) / float(steps))
			clear.append(Vector3(p.x, p.y, 1.6))
	var mi := b.commit(root, "Walls")
	# One mesh round the whole town: never culled by distance (its centre is the plaza).
	mi.visibility_range_end = 0.0


## A clipped hedge ring around the village, open at the gate and both ends of
## the main street, and skipping anything already standing there (one mesh).
static func _hedge(root: Node3D, clear: Array[Vector3]) -> void:
	var b := JapanKit.Batch.new()
	var r := RADIUS - 3.5
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
				break
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
	for corner in [Vector2(62, 58), Vector2(-66, 52)]:
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
			var steps := int(a.distance_to(c) / 4.0) + 1
			for k in steps + 1:
				var p := a.lerp(c, float(k) / float(steps))
				clear.append(Vector3(p.x, p.y, 5.0))


## The paved districts' ground stays clear too (after the hedge, which these would gap).
static func _districts_clear(clear: Array[Vector3]) -> void:
	for d in DISTRICTS:
		if not d.has("rect") or String(d.id) in ["farm", "grove"]:
			continue
		var r: Rect2 = d.rect
		var x := r.position.x + 6.0
		while x < r.end.x:
			var z := r.position.y + 6.0
			while z < r.end.y:
				if Vector2(x, z).length() < RADIUS - 6.0:
					clear.append(Vector3(x, z, 6.5))
				z += 10.0
			x += 10.0


## Snow-capped peaks far behind the shrine and along the eastern and western
## horizons (one mesh).
static func _mountain(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	for spec in [[Vector3(-25, -2.0, -195), 84.0, 70.0, Color("7f93ad")], [Vector3(-140, -2.0, -140), 62.0, 48.0, Color("8a9cb4")],
			[Vector3(90, -2.0, -190), 56.0, 42.0, Color("8ea0b8")], [Vector3(190, -2.0, -50), 66.0, 46.0, Color("98a8be")],
			[Vector3(-200, -2.0, 40), 70.0, 44.0, Color("9aaabf")]]:
		var pos: Vector3 = spec[0]
		var r: float = spec[1]
		var h: float = spec[2]
		b.cone(pos + Vector3(0, h * 0.46, 0), r, h, spec[3])
		b.cone(pos + Vector3(0, h * 0.83, 0), r * 0.38, h * 0.27, Color("f4f6fa"))
	var mi := b.commit(root, "Mountain", false)
	mi.visibility_range_end = 0.0


## What moves in the village: chimney and incense smoke, villagers walking
## their rounds along the market street, the shrine approach and the dojo street, a
## chicken in the farmyard and a cat by the pond.
## None of it joins Zone.npcs (the Talk button and the role count are unchanged).
## `tree` paces the walkers over frames (FrameSlicer); null builds them in one go.
static func life(zone: Node3D, rng: RandomNumberGenerator, tree: SceneTree = null) -> void:
	var root := Node3D.new()
	root.name = "VillageLife"
	zone.add_child(root)
	_smoke(root, FORGE + Vector3(2.6, 7.2, -1.6), 14, Color(0.75, 0.75, 0.78, 0.5), 1.0)
	_smoke(root, IZAKAYA + Vector3(2.4, 6.0, 1.8), 10, Color(0.85, 0.85, 0.88, 0.45), 0.8)
	for spec in FARMHOUSES:
		var pos: Vector3 = spec[0]
		_smoke(root, pos + Basis(Vector3.UP, spec[1]) * Vector3(1.5, 6.4, -1.0), 8, Color(0.8, 0.8, 0.82, 0.4), 0.7)
	_smoke(root, SHRINE + Vector3(0, 2.3, 3.2), 6, Color(0.9, 0.9, 0.95, 0.35), 0.35)
	var loops := [
		[Vector2(4, 5), Vector2(14, 1), Vector2(24, 1), Vector2(38, 0.5), Vector2(50, 1), Vector2(62, 0.5), Vector2(67, 0), Vector2(56, -1), Vector2(40, -1), Vector2(26, -0.5), Vector2(14, -1)],
		[Vector2(-2, -12), Vector2(-1, -20), Vector2(0.5, -30), Vector2(-0.5, -42), Vector2(0, -54), Vector2(6, -51), Vector2(1, -40), Vector2(-1, -28), Vector2(-3, -15)],
		[Vector2(-5, 1), Vector2(-16, 0.5), Vector2(-28, 1), Vector2(-44, 0), Vector2(-56, 1), Vector2(-40, 0.5), Vector2(-22, -1)],
		[Vector2(1, 16), Vector2(0, 30), Vector2(-1, CROSS_Z), Vector2(-14, CROSS_Z), Vector2(-30, CROSS_Z + 0.5), Vector2(-12, CROSS_Z - 0.5), Vector2(1, 50), Vector2(0, 62), Vector2(-1, 26)],
	]
	var outfits := [["Rogue", Color(0.9, 0.8, 0.6), ""], ["Mage", Color(0.7, 0.85, 0.75), ""], ["Ranger", Color(1.3, 0.8, 0.7), ""], ["Knight", Color(0.75, 0.75, 0.95), ""]]
	var hats := [["kasa", Color.WHITE], ["tenugui", Color("5a7ad8")], ["hachimaki", Color("f4f0e8")], ["ribbon", Color("e8463a")]]
	for i in mini(loops.size(), Villager.MAX_WALKERS):
		var walker := Villager.new()
		root.add_child(walker)
		walker.setup_person(FaceKit.random_look(rng), outfits[i], hats[i], loops[i], rng)
		await FrameSlicer.pace(tree)
	var hen := Villager.new()
	root.add_child(hen)
	hen.setup_animal("blob/Chicken", 0.55, Vector2(54, -24), 3.0, 0.9, rng)
	var cat := Villager.new()
	root.add_child(cat)
	cat.setup_animal("blob/Cat", 0.5, Vector2(-36, 44), 3.0, 1.3, rng)


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
