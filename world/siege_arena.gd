class_name SiegeArena
extends RefCounted
## The guild war's battlefield: a castle siege in the grand style of the great Japanese
## castles. Up to four guilds camp round a wide field behind their own war curtains (CAMPS:
## west, east, south-west and south-east, each CAMP_DIST from the castle's approach, so no
## guild is nearer than another), meet on the plaza and cross the wide stone bridge over the
## moat to the castle: a curtain of dressed-stone walls (ishigaki: courses of blocks
## leaning back as they rise) under white plastered parapets with loopholes and tiled caps,
## turrets along the walls and over every gate (each tier's gatehouse grander than the one
## before), and behind it all the great seven-storey keep on its stepped stone base, joined
## by roofed galleries to two lesser keeps, with the castle town, its pagodas, outer wall
## and the mountains beyond (decoration only, outside the field).
## Three tiers of gates stand one behind the other in the castle's long hall (GATE_Z): the
## first two tiers have TWO gates each, a left and a right one (LANE_X), and either of them
## broken lets everyone through to the next tier; the third tier is one gate, the throne
## room's. Past it a grand staircase climbs to the raised throne court (COURT_H, floor_y),
## where stands, against its
## back wall, the altar a guild must hold to take the castle. The field and the yards are flat:
## the moat and the walls are colliders, and fighters find their way along the sections
## (route): the field, the bridge, the two yards and the throne room, joined at the bridge
## foot and the gates (lane_open says which of a doubled tier's gates are already broken,
## the match keeps it). The castle's banners take the colour of the guild that holds it
## (the match recolours the BANNER_META material).

## Play radius (the boundary walls).
const RADIUS := 124.0
## The castle's approach: the middle of the bridge foot, where every camp's way meets.
const APPROACH := Vector3(0, 0, -4.0)
## The four camps (team 0 west, 1 east, 2 south-west, 3 south-east), each CAMP_DIST from
## APPROACH on a fan 48 degrees apart (162, 18, 114 and 66 degrees, z to the south). A war
## of two uses the first two (west and east).
const CAMP_DIST := 88.0
const CAMPS: Array[Vector3] = [Vector3(-83.7, 0, 23.2), Vector3(83.7, 0, 23.2), Vector3(-35.8, 0, 76.4), Vector3(35.8, 0, 76.4)]
## The first two camps (kept for older callers: ours at (-BASE_X, BASE_Z), theirs at (BASE_X, BASE_Z)).
const BASE_X := 83.7
const BASE_Z := 23.2
## Inside this far from its camp a guild is safe from being chased (it heals there).
const CAMP_RADIUS := 16.0
## The castle holder's camp inside the castle, in the second yard before the throne room's
## gate: a guild that holds the castle lines up and comes back there (facing the way in,
## rows of KEEP_ROW), and its own gates let it through (GuildWarMatch._gate_pass); from
## there it is some forty-five metres to the altar at the back of the throne room (across
## the hall), so its fallen are not back on it at once.
## Safe from being chased only this close.
const KEEP_CAMP := Vector3(0, 0, -82.0)
const KEEP_ROW := 10
const KEEP_SAFE := 6.0
## The plaza where the guilds meet, south of the bridge.
const PLAZA := Vector3(0, 0, 8.0)
## The moat runs east-west between these z; the bridge crosses it at |x| < BRIDGE_HALF.
const MOAT_SOUTH := -6.0
const MOAT_NORTH := -14.0
const BRIDGE_HALF := 21.0
## The castle hall (the two yards) is 2 * HALL_HALF wide; each gate opening 2 * GATE_HALF
## wide, GATE_H high, the tiers GATE_GAP apart. The first two tiers' gates stand at
## x = -LANE_X and +LANE_X; the third tier's in the middle. Past the third the throne room
## opens out to 2 * THRONE_HALF wide and runs THRONE_DEPTH deep to the back wall.
const HALL_HALF := 27.0
const GATE_HALF := 5.0
const GATE_H := 8.0
const GATE_GAP := 36.0
const LANE_X := 12.0
const GATE_Z: Array[float] = [-18.0, -18.0 - GATE_GAP, -18.0 - GATE_GAP * 2.0]
## Gates of each tier: two lanes on the first two, one on the third.
const TIER_LANES: Array[int] = [2, 2, 1]
const THRONE_HALF := 38.0
const THRONE_DEPTH := 48.0
const BACK_Z := -18.0 - GATE_GAP * 2.0 - THRONE_DEPTH
## The stone base of the walls, then the plastered parapet on it.
const STONE_H := 7.0
const PARAPET_H := 2.4
const WALL_H := STONE_H + PARAPET_H
## The altar against the throne room's back wall (in the middle, ALTAR_BACK m off the
## wall: room to stand all round it) and how close one must stand to take it. From the
## holder's camp (KEEP_CAMP) it is some forty-five metres.
const ALTAR_BACK := 9.0
const ALTAR := Vector3(0, 0, -18.0 - GATE_GAP * 2.0 - THRONE_DEPTH + ALTAR_BACK)
const ALTAR_RADIUS := 2.8
## The throne court stands COURT_H above the yards: past the third gate a grand staircase
## as wide as the court climbs to it in two flights with a landing between (its foot
## STAIR_Z0 just inside the gatehouse, its head STAIR_RUN further in), so the altar and everything on
## the court are that much higher than the field (floor_y: the floor's height at a point).
## ALTAR and every route point stay flat (y = 0): the fighters' brains work on the
## map (x, z) and gravity keeps their feet on the stairs' ramp and the court's floor.
const COURT_H := 4.0
const STAIR_Z0 := -18.0 - GATE_GAP * 2.0 - 3.0
const STAIR_RUN := 8.0
const STAIR_Z1 := STAIR_Z0 - STAIR_RUN
## Two flights of STAIR_FLIGHT (half the height each) with a level landing STAIR_LANDING
## deep between them (STAIR_RUN = 2 flights + the landing), STAIR_STEPS steps in all.
const STAIR_FLIGHT := 3.25
const STAIR_LANDING := 1.5
const STAIR_STEPS := 16
## The ramps under the steps run through the middle of each tread (half a tread south of
## the steps' own line), so feet neither sink into a step nor float over it.
const STAIR_LEAD := 0.2
const LANE_NAMES: Array[String] = ["ซ้าย", "ขวา"]
## Where the sections join, each a list of openings: the bridge foot (one per lane), the
## first two tiers' two gates, the third tier's one.
const CONNECTORS: Array = [
	[Vector3(-LANE_X, 0, -4.0), Vector3(LANE_X, 0, -4.0)],
	[Vector3(-LANE_X, 0, -18.0), Vector3(LANE_X, 0, -18.0)],
	[Vector3(-LANE_X, 0, -18.0 - GATE_GAP), Vector3(LANE_X, 0, -18.0 - GATE_GAP)],
	[Vector3(0, 0, -18.0 - GATE_GAP * 2.0)],
]
## Zone meta holding the castle banners' shared material (recoloured for the castle's holder).
const BANNER_META := "siege_banner_material"
## Which of a doubled tier's gates are open (broken), [tier 0, tier 1] x [left, right]:
## the way through goes by an open one. Set by GuildWarMatch (all shut when a war starts).
static var lane_open: Array = [[false, false], [false, false]]

const STONES: Array[Color] = [Color("a39f94"), Color("8f8b81"), Color("b3ada0"), Color("7d7a72"), Color("9c958a"), Color("c0b9aa")]
const STONE := Color("a7a39a")
const STONE_CORE := Color("77736b")
const PLASTER := Color("f4efe4")
const TILE := Color("39414f")
const TILE_EDGE := Color("2a303b")
const WOOD := Color("4a2f20")
const PAVING := Color("bdb6a4")
const GOLD := Color("e8c050")
## Deeper golds that SurfaceKit still reads as metal (a darkened GOLD would be drawn as wood).
const GOLD_DEEP := Color("d9aa38")
const GOLD_DARK := Color("cc9a2c")
## The great keep's roofs: weathered copper over the grey tiles of the walls.
const KEEP_ROOF := Color("3d7468")
const LOOPHOLE := Color("2b2622")


## Where team `team`'s camp is (CAMPS; teams past the fourth wrap round).
static func camp(team: int) -> Vector3:
	return CAMPS[posmod(team, CAMPS.size())]


## The way from a camp towards the castle's approach (flat, unit).
static func camp_forward(team: int) -> Vector3:
	var to := APPROACH - camp(team)
	to.y = 0.0
	return to.normalized()


## The x of gate `lane` of tier `tier` (0 for the single gate of the third tier).
static func gate_x(tier: int, lane: int) -> float:
	if TIER_LANES[tier] < 2:
		return 0.0
	return -LANE_X if lane == 0 else LANE_X


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


## The opening of join `j` (CONNECTORS) to take from `from` on the way to `to`: of the ones
## that are open (a broken gate; the bridge foot always), the shortest way through; when
## none is open (the tier's gates all stand), the shortest of all.
static func opening(j: int, from: Vector3, to: Vector3) -> Vector3:
	var list: Array = CONNECTORS[j]
	if list.size() == 1:
		return list[0]
	var best: Vector3 = list[0]
	var best_d := INF
	for pass_open in [true, false]:
		for lane in list.size():
			if pass_open and not is_open(j, lane):
				continue
			var c: Vector3 = list[lane]
			var d := Vector2(from.x - c.x, from.z - c.z).length() + Vector2(to.x - c.x, to.z - c.z).length()
			if d < best_d:
				best_d = d
				best = c
		if best_d < INF:
			return best
	return best


## Whether opening `lane` of join `j` lets anyone through now (the bridge foot always; a
## gate once broken).
static func is_open(j: int, lane: int) -> bool:
	if j == 0:
		return true
	var tier := j - 1
	if tier >= lane_open.size():
		return true
	var row: Array = lane_open[tier]
	return lane < row.size() and bool(row[lane])


## The next point to walk to from `from` on the way to `to`: `to` itself within a section,
## otherwise the opening towards it (and a step through once there).
static func route(from: Vector3, to: Vector3) -> Vector3:
	var a := section(from)
	var b := section(to)
	if a == b:
		return to
	if b > a:
		var c := opening(a, from, to)
		if Vector2(from.x - c.x, from.z - c.z).length() < 2.4:
			return c + Vector3(0, 0, -3.5)
		return _square_on(from, c)
	var back := opening(a - 1, from, to)
	if Vector2(from.x - back.x, from.z - back.z).length() < 2.4:
		return back + Vector3(0, 0, 3.5)
	return _square_on(from, back)


## Whether `p` is inside the moat (off the bridge, between its banks: the moat's collider).
static func in_moat(p: Vector3) -> bool:
	return p.z < MOAT_SOUTH - 0.2 and p.z > MOAT_NORTH + 0.2 and absf(p.x) > BRIDGE_HALF + 0.3


## The nearer bank to `p` in the moat (just off its edge, on the ground).
static func out_of_moat(p: Vector3) -> Vector3:
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	return Vector3(p.x, 0.3, MOAT_SOUTH + 1.0 if p.z >= mid else MOAT_NORTH - 1.0)


## Close along a wall from an opening `c` (within APPROACH_DEPTH of its line, more than
## GATE_HALF - 2 to its side: by the gatehouse's posts) the way runs first to a point in
## front of it, square on, instead of along the wall's face into the gatehouse's corner
## (where a fighter could stand pressed for minutes: guild_war_sim's stuck measure);
## otherwise to the opening.
const APPROACH_DEPTH := 6.0


static func _square_on(from: Vector3, c: Vector3) -> Vector3:
	var dz := from.z - c.z
	if absf(dz) < APPROACH_DEPTH and absf(from.x - c.x) > GATE_HALF - 2.0:
		return Vector3(c.x, c.y, c.z + signf(dz if dz != 0.0 else 1.0) * APPROACH_DEPTH)
	return c


## Front of gate `lane` of tier k (the side the guilds come from).
static func gate_front(k: int, lane := 0) -> Vector3:
	return Vector3(gate_x(k, lane), 0, GATE_Z[k] + 3.0)

## The castle's floor (x, z) past the moat, where the hero may stand beyond the field's
## round edge (Hero.field_hall): the yards and the wider throne room.
static func hall_rect() -> Rect2:
	return Rect2(-THRONE_HALF, BACK_Z, THRONE_HALF * 2.0, MOAT_SOUTH - BACK_Z)


## How high the floor is at `p` (x, z): 0 on the field and in the yards, rising up the grand
## staircase past the third gate, COURT_H on the throne court.
static func floor_y(p: Vector3) -> float:
	if p.z > STAIR_Z0 + STAIR_LEAD or p.z < BACK_Z - 1.7 or absf(p.x) > THRONE_HALF - 1.7:
		return 0.0
	var t := STAIR_Z0 + STAIR_LEAD - p.z
	var half := COURT_H * 0.5
	if t <= STAIR_FLIGHT:
		return half * clampf(t / STAIR_FLIGHT, 0.0, 1.0)
	if t <= STAIR_FLIGHT + STAIR_LANDING:
		return half
	return half + half * clampf((t - STAIR_FLIGHT - STAIR_LANDING) / STAIR_FLIGHT, 0.0, 1.0)


## `p` put on the floor there (`above` metres over it).
static func on_floor(p: Vector3, above := 0.0) -> Vector3:
	return Vector3(p.x, floor_y(p) + above, p.z)


## The altar's place on the raised court (ALTAR itself is the flat map point).
static func altar_top() -> Vector3:
	return ALTAR + Vector3(0, COURT_H, 0)


static func on_altar(p: Vector3) -> bool:
	return Vector2(p.x - ALTAR.x, p.z - ALTAR.z).length() <= ALTAR_RADIUS


## Builds the field, a camp per guild colour in `colors` (CAMPS order: team 0 first), the
## moat and the wide bridge, the castle with its walls, turrets, gatehouses, the grand
## staircase and the raised throne court, the keeps and the kingdom beyond, and their colliders.
static func build(zone: Node3D, rng: RandomNumberGenerator, colors: Array) -> void:
	# The clear air of a high country (the kingdom and its mountains stand far off).
	Scenery.environment(zone, Color("5f8fd8"), Color("d6e4f2"), Color(0.9, 0.92, 1.0), Color(1.0, 0.95, 0.85), {"theme": &"sky"})
	var paths: Array[PackedVector2Array] = [PackedVector2Array([Vector2(PLAZA.x, PLAZA.z), Vector2(0.0, MOAT_SOUTH)])]
	var clearings: Array[Vector3] = [Vector3(PLAZA.x, PLAZA.z, 16.0)]
	var count := clampi(colors.size(), 2, CAMPS.size())
	for team in count:
		var c := camp(team)
		# Each camp's own road to the bridge foot of its nearer lane, past the plaza's rim.
		var lane_x := -LANE_X if c.x < 0.0 else LANE_X
		paths.append(PackedVector2Array([Vector2(c.x, c.z), Vector2(c.x * 0.45 + lane_x * 0.55, c.z * 0.35 + PLAZA.z * 0.65), Vector2(lane_x, MOAT_SOUTH)]))
		clearings.append(Vector3(c.x, c.z, 14.0))
	# The pilgrims' way under the torii from the south (AVENUE) to the plaza.
	paths.append(PackedVector2Array([Vector2(0.0, AVENUE_Z1 + 8.0), Vector2(PLAZA.x, PLAZA.z)]))
	Scenery.ground(zone, 215.0, Color("6fae54"), Color("86c063"), 41, Color("cdb88a"), paths, 7.0, clearings, &"meadow")
	var root := Node3D.new()
	root.name = "Siege"
	zone.add_child(root)
	var masonry := Masonry.new(rng)
	# Its own copy (the cached toon material is shared), recoloured by the match. Every
	# banner of the castle is one mesh in it: white cloth takes the holder's colour whole,
	# the hems and crests (grey in the mesh) a deeper shade of it.
	var banner := (MeshKit.toon(Color("fff1b8"), {"emission": 0.15}) as StandardMaterial3D).duplicate() as StandardMaterial3D
	banner.vertex_color_use_as_albedo = true
	zone.set_meta(BANNER_META, banner)
	_flags = JapanKit.Batch.new()
	_trim = JapanKit.Batch.new()
	_banner = banner
	# The new scenery's own stream of numbers (the zone's is left to the stone and the pines).
	var art := RandomNumberGenerator.new()
	art.seed = 90417
	_moat(root, masonry)
	_bridge(root, masonry)
	_castle(root, masonry)
	_keeps(root, masonry)
	for team in count:
		_camp(root, team, colors[team] if colors[team] is Color else Color.WHITE)
	_plaza(root)
	_pines(root, rng, count)
	_kingdom(root, art)
	_horizon(root, rng, art)
	masonry.commit(root)
	_commit_flags(root, banner)
	_commit(_trim, root, "CastleTrim", false)
	_trim = null
	_banner = null
	_altar_beam(root)
	_court_floor(root)
	_flags = null
	# Grass, flowers, bushes, torches, weapon racks and the guilds' banners (visual only).
	PropDressing.siege(root, colors, count)
	# Effects drawn for flat ground are lifted onto the stairs and the court (SiegeLift).
	SiegeLift.attach(zone)


## The torii avenue south of the plaza (decoration: no colliders), from z0 to z1.
const AVENUE_Z0 := 40.0
const AVENUE_Z1 := 72.0
## Every castle banner goes into this one batch while the castle is built (_flag).
static var _flags: JapanKit.Batch
## The castle's flat floor work (paving, bands, carpets, inlays) and small wall detail
## (loopholes): one mesh that casts no shadow, so the shadow pass does not draw it again.
static var _trim: JapanKit.Batch
## The holder's banner material while the castle is built.
static var _banner: StandardMaterial3D


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
	func face(a: Vector3, b: Vector3, normal: Vector3, y0: float, y1: float, out: float, lean := 0.08, course := 0.62, wide := 1.0) -> void:
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
				var w := rng.randf_range(0.9, 1.7) * wide
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
	func block(center: Vector3, size: Vector3, lean := 0.1, faces := [0, 1, 2, 3], course := 0.62, wide := 1.0) -> void:
		var hx := size.x * 0.5
		var hz := size.z * 0.5
		var c := Vector3(center.x, 0, center.z)
		for f in faces:
			match int(f):
				0: face(c + Vector3(-hx, 0, hz), c + Vector3(hx, 0, hz), Vector3(0, 0, 1), center.y, center.y + size.y, 0.0, lean, course, wide)
				1: face(c + Vector3(hx, 0, -hz), c + Vector3(-hx, 0, -hz), Vector3(0, 0, -1), center.y, center.y + size.y, 0.0, lean, course, wide)
				2: face(c + Vector3(hx, 0, hz), c + Vector3(hx, 0, -hz), Vector3(1, 0, 0), center.y, center.y + size.y, 0.0, lean, course, wide)
				3: face(c + Vector3(-hx, 0, -hz), c + Vector3(-hx, 0, hz), Vector3(-1, 0, 0), center.y, center.y + size.y, 0.0, lean, course, wide)

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
		# Shared with every castle: toon stone with a weathered grain (SurfaceKit).
		inst.material_override = SurfaceKit.vertex_material(false, false, SurfaceKit.KIND_MASONRY)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)


## A batch drawn at any distance: the castle is the landmark of the whole field (a batch
## elsewhere fades out past 95 m, which would leave only the stone faces standing).
static func _commit(b: JapanKit.Batch, root: Node3D, node_name: String, shadows := true) -> void:
	var mi := b.commit(root, node_name, shadows)
	mi.visibility_range_end = 0.0


static func _vertex_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


# ---------------------------------------------------------------------------
# Banners, lamps and braziers
# ---------------------------------------------------------------------------

## A banner cloth in the holder's colour (one box of the shared banner mesh), with a deeper
## hem along its top and, `crest` wide, a round crest in its middle (on the +z face when the
## cloth is thin in z, on both x faces when thin in x).
static func _flag(pos: Vector3, size: Vector3, crest := 0.0) -> void:
	if _flags == null:
		return
	var box := JapanKit.arrays("box")
	_flags.add(box, JapanKit.place(pos, size, Vector3.ZERO), Color.WHITE, false, Callable(), SurfaceKit.KIND_NONE)
	var thin_x := size.x < size.z
	var grow := Vector3(0.03, 0.0, 0.0) if thin_x else Vector3(0.0, 0.0, 0.03)
	var hem := Vector3(size.x, size.y * 0.09, size.z) + grow * 2.0 + (Vector3(0, 0, 0.12) if thin_x else Vector3(0.12, 0, 0))
	_flags.add(box, JapanKit.place(pos + Vector3(0, size.y * 0.455, 0), hem, Vector3.ZERO), Color(0.62, 0.62, 0.62), false, Callable(), SurfaceKit.KIND_NONE)
	if crest > 0.0:
		var disc := JapanKit.arrays("cyl12")
		var turn := Vector3(0, 0, 90) if thin_x else Vector3(90, 0, 0)
		var deep := (size.x if thin_x else size.z) + 0.05
		_flags.add(disc, JapanKit.place(pos + Vector3(0, size.y * 0.12, 0), Vector3(crest, deep, crest), turn), Color(0.5, 0.5, 0.5), false, Callable(), SurfaceKit.KIND_NONE)
		_flags.add(disc, JapanKit.place(pos + Vector3(0, size.y * 0.12, 0), Vector3(crest * 0.55, deep + 0.03, crest * 0.55), turn), Color(1.0, 1.0, 1.0), false, Callable(), SurfaceKit.KIND_NONE)


## A tall nobori on a wall top or by a road: a pole `h` high at `base` with a long banner
## hung beside it (`along_x`: the cloth faces north-south, else east-west).
static func _nobori(b: JapanKit.Batch, base: Vector3, h: float, along_x := true) -> void:
	b.cyl(base + Vector3(0, h * 0.5, 0), 0.07, h, WOOD, Vector3.ZERO, 6)
	var w := h * 0.2
	var off := Vector3(w * 0.5 + 0.08, 0, 0) if along_x else Vector3(0, 0, w * 0.5 + 0.08)
	b.box(base + off + Vector3(0, h - 0.06, 0), Vector3(w + 0.2, 0.07, 0.07) if along_x else Vector3(0.07, 0.07, w + 0.2), WOOD)
	_flag(base + off + Vector3(0, h * 0.64, 0), Vector3(w, h * 0.68, 0.05) if along_x else Vector3(0.05, h * 0.68, w))


## All the castle's banners as one mesh in the holder's colour.
static func _commit_flags(root: Node3D, banner: StandardMaterial3D) -> void:
	if _flags == null or _flags.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.name = "Banners"
	mi.mesh = _flags.mesh()
	mi.material_override = banner
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A fire bowl on an iron stand: the flame glows (no light).
static func _brazier(b: JapanKit.Batch, pos: Vector3, s := 1.0) -> void:
	var iron := Color("26221f")
	b.cyl(pos + Vector3(0, 0.1, 0) * s, 0.42 * s, 0.2 * s, iron, Vector3.ZERO, 6)
	b.cyl(pos + Vector3(0, 0.75, 0) * s, 0.1 * s, 1.3 * s, iron, Vector3.ZERO, 6)
	b.cyl(pos + Vector3(0, 1.5, 0) * s, 0.55 * s, 0.34 * s, GOLD_DARK, Vector3.ZERO, 8)
	b.cyl(pos + Vector3(0, 1.69, 0) * s, 0.6 * s, 0.08 * s, GOLD, Vector3.ZERO, 8)
	# The flame: a hot heart under two leaning tongues.
	b.add(JapanKit.arrays("cyl6"), JapanKit.place(pos + Vector3(0, 1.82, 0) * s, Vector3(0.78, 0.26, 0.78) * s, Vector3.ZERO), Color("ffd070"), true)
	b.add(JapanKit.arrays("cone"), JapanKit.place(pos + Vector3(-0.1, 2.3, 0.06) * s, Vector3(0.62, 0.95, 0.62) * s, Vector3(6, 0, 10)), Color("ff8a2a"), true)
	b.add(JapanKit.arrays("cone"), JapanKit.place(pos + Vector3(0.14, 2.2, -0.08) * s, Vector3(0.42, 0.75, 0.42) * s, Vector3(-8, 0, -14)), Color("ffc24a"), true)
	b.add(JapanKit.arrays("cone"), JapanKit.place(pos + Vector3(0, 2.1, 0) * s, Vector3(0.3, 0.5, 0.3) * s, Vector3.ZERO), Color("fff2b8"), true)


## A lamp post: a wooden post with an arm and a glowing paper lantern.
static func _lamp(b: JapanKit.Batch, pos: Vector3, h := 3.4, arm := Vector3(0.5, 0, 0)) -> void:
	b.cyl(pos + Vector3(0, h * 0.5, 0), 0.08, h, WOOD, Vector3.ZERO, 6)
	b.box(pos + arm * 0.5 + Vector3(0, h - 0.1, 0), Vector3(absf(arm.x) + 0.14, 0.08, absf(arm.z) + 0.14), WOOD)
	JapanKit.chochin(b, pos + arm + Vector3(0, h - 0.55, 0), Color("e8463a"), 1.25)


## Upturned eave tips at a roof's four corners (the sweep of a castle roof), gilded.
static func _eaves(b: JapanKit.Batch, center: Vector3, w: float, d: float, s := 1.0) -> void:
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var at: Vector3 = center + Vector3(float(x) * w * 0.5, 0, float(z) * d * 0.5)
			b.box(at, Vector3(0.9, 0.2, 0.9) * s, TILE_EDGE, Vector3(float(z) * 16.0, 0, -float(x) * 16.0))
			b.box(at + Vector3(float(x) * 0.34, 0.2, float(z) * 0.34) * s, Vector3(0.3, 0.3, 0.3) * s, GOLD)


## The golden ridge-fish (shachihoko) at both ends of a ridge `span` long along x (or z).
static func _shachi(b: JapanKit.Batch, at: Vector3, span: float, s := 1.0, along_x := true) -> void:
	for e in [-1.0, 1.0]:
		var off := Vector3(float(e) * span * 0.5, 0, 0) if along_x else Vector3(0, 0, float(e) * span * 0.5)
		var fish: Vector3 = at + off
		b.box(fish + Vector3(0, 0.5, 0) * s, Vector3(0.6, 1.0, 0.44) * s if along_x else Vector3(0.44, 1.0, 0.6) * s, GOLD, Vector3(0, 0, -float(e) * 12.0) if along_x else Vector3(float(e) * 12.0, 0, 0))
		b.cone(fish + Vector3(0, 1.4, 0) * s - off.normalized() * 0.25 * s, 0.3 * s, 0.9 * s, GOLD, Vector3(0, 0, float(e) * 28.0) if along_x else Vector3(-float(e) * 28.0, 0, 0))


# ---------------------------------------------------------------------------
# Walls
# ---------------------------------------------------------------------------

## A stretch of castle wall along x (from x0 to x1 at depth z): a stone core `top` high
## dressed on the given faces (+1 south, -1 north; `y0s`: where each face's courses start,
## the floor on that side), a white parapet with loopholes and a tiled cap on top, and its collider.
static func _wall_x(b: JapanKit.Batch, m: Masonry, root: Node3D, x0: float, x1: float, z: float, faces := [1, -1], top := STONE_H, y0s := []) -> void:
	var w := absf(x1 - x0)
	var cx := (x0 + x1) * 0.5
	b.box(Vector3(cx, top * 0.5, z), Vector3(w, top, 3.4), STONE_CORE)
	for i in faces.size():
		var side: float = float(faces[i])
		var from_y: float = float(y0s[i]) if i < y0s.size() else 0.0
		var n := Vector3(0, 0, side)
		var a := Vector3(minf(x0, x1), 0, z) if side > 0.0 else Vector3(maxf(x0, x1), 0, z)
		var e := Vector3(maxf(x0, x1), 0, z) if side > 0.0 else Vector3(minf(x0, x1), 0, z)
		m.face(a, e, n, from_y, top, 2.0, minf(0.08, 0.56 / maxf(top - from_y, 1.0)), 0.62 if top <= STONE_H else 0.8, 1.0 if top <= STONE_H else 1.45)
	_parapet(b, Vector3(x0, top, z), Vector3(x1, top, z))
	JapanKit.collider(root, Vector3(cx, (top + PARAPET_H) * 0.5, z), Vector3(w, top + PARAPET_H, 3.4))


static func _wall_z(b: JapanKit.Batch, m: Masonry, root: Node3D, x: float, z0: float, z1: float, faces := [1, -1], top := STONE_H, y0s := []) -> void:
	var d := absf(z1 - z0)
	var cz := (z0 + z1) * 0.5
	b.box(Vector3(x, top * 0.5, cz), Vector3(3.4, top, d), STONE_CORE)
	for i in faces.size():
		var side: float = float(faces[i])
		var from_y: float = float(y0s[i]) if i < y0s.size() else 0.0
		var n := Vector3(side, 0, 0)
		var a := Vector3(x, 0, maxf(z0, z1)) if side > 0.0 else Vector3(x, 0, minf(z0, z1))
		var e := Vector3(x, 0, minf(z0, z1)) if side > 0.0 else Vector3(x, 0, maxf(z0, z1))
		m.face(a, e, n, from_y, top, 2.0, minf(0.08, 0.56 / maxf(top - from_y, 1.0)), 0.62 if top <= STONE_H else 0.8, 1.0 if top <= STONE_H else 1.45)
	_parapet(b, Vector3(x, top, z0), Vector3(x, top, z1))
	JapanKit.collider(root, Vector3(x, (top + PARAPET_H) * 0.5, cz), Vector3(3.4, top + PARAPET_H, d))


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
			var t := _trim if _trim != null else b
			if i % 2 == 0:
				t.box(at, Vector3(0.36, 0.36, 0.06), LOOPHOLE, Vector3(0, yaw + 90.0, 45.0))
			else:
				t.box(at, Vector3(0.3, 0.42, 0.06), LOOPHOLE, Vector3(0, yaw + 90.0, 0))


## A turret (yagura) of `tiers` storeys on a dressed stone base at `at`, flying the
## holder's banner; three storeys carry the golden ridge-fish.
static func _yagura(b: JapanKit.Batch, m: Masonry, at: Vector3, size: float, base_h := STONE_H + 0.6, tiers := 2) -> void:
	b.box(at + Vector3(0, base_h * 0.5, 0), Vector3(size, base_h, size), STONE_CORE)
	m.block(at, Vector3(size + 0.6, base_h, size + 0.6), minf(0.1, 0.8 / base_h), [0, 2, 3])
	var y := base_h
	var s := size
	for tier in tiers:
		s = size - float(tier) * 1.5
		var h := 3.0 - float(tier) * 0.3
		b.box(at + Vector3(0, y + 0.15, 0), Vector3(s + 0.3, 0.3, s + 0.3), WOOD)
		b.box(at + Vector3(0, y + h * 0.5 + 0.3, 0), Vector3(s, h, s), PLASTER)
		for k in 3:
			var x := (float(k) - 1.0) * s * 0.3
			b.box(at + Vector3(x, y + h * 0.55 + 0.3, s * 0.5 + 0.03), Vector3(0.6, 0.7, 0.06), Color("3a2c22"))
		y += h + 0.3
		b.roof(at + Vector3(0, y + 0.45, 0), s + 2.4, s + 2.4, 1.1, TILE, 0.3)
		b.box(at + Vector3(0, y + 0.35, s * 0.5 + 1.0), Vector3(s * 0.45, 0.9, 0.5), TILE_EDGE, Vector3(-30, 0, 0))
		if tiers >= 3:
			_eaves(b, at + Vector3(0, y + 0.02, 0), s + 2.3, s + 2.3, 0.8)
		y += 0.9
	b.box(at + Vector3(0, y + 0.22, 0), Vector3(s * 0.4 + 0.6, 0.3, 0.34), TILE_EDGE)
	if tiers >= 3:
		_shachi(b, at + Vector3(0, y + 0.3, 0), s * 0.4 + 0.3, 0.7)
	else:
		b.box(at + Vector3(0, y + 0.45, 0), Vector3(1.4, 0.3, 0.3), GOLD)
	b.cyl(at + Vector3(size * 0.35, y + 1.6, -0.9), 0.07, 3.6, WOOD)
	_flag(at + Vector3(size * 0.35, y + 2.2, 0), Vector3(0.12, 2.4, 1.6))


## The gatehouse over gate k: massive dressed-stone jambs, a lintel beam, and a long
## turret spanning the opening (watari-yagura) with the castle's golden crest and two long
## banners. Each tier's is grander than the one before: the second's stands higher under a
## second storey, the third's (the throne court's) rises with the court's wall behind it, a
## crested wall over its lintel, a second storey and the golden ridge-fish. The door itself
## is the CastleGate the guilds break (its opening is the same on every tier).
static func _gatehouse(b: JapanKit.Batch, m: Masonry, k: int, root: Node3D, gx := 0.0) -> void:
	var z := GATE_Z[k]
	var lift: float = [0.0, 1.5, COURT_H][k]
	var jamb := GATE_H + 1.0 + lift
	for side in [-1.0, 1.0]:
		var x: float = gx + float(side) * (GATE_HALF + 1.6)
		b.box(Vector3(x, jamb * 0.5, z), Vector3(3.2, jamb, 4.4), STONE_CORE)
		m.block(Vector3(x, 0, z), Vector3(3.4, jamb, 4.6), 0.0, [0, 1, 2 if float(side) > 0.0 else 3])
		# The jambs close the wall up to the door (the CastleGate blocks the opening).
		JapanKit.collider(root, Vector3(x, jamb * 0.5, z), Vector3(3.2, jamb, 4.4))
	# The works over the door are their own mesh: it fades out while it stands between the
	# camera and the hero (ThirdPersonCamera.FADE_GROUP), so a fight in the gateway or on
	# the stairs behind it is never hidden by the gatehouse.
	var g := JapanKit.Batch.new()
	if k >= 2:
		# The tall jambs of the throne court's gate: a tiled ledge round each over a
		# plastered band, a lantern and the holder's banner on the face to the stairs.
		for side in [-1.0, 1.0]:
			var jx: float = gx + float(side) * (GATE_HALF + 1.6)
			b.box(Vector3(jx, GATE_H + 0.3, z), Vector3(3.7, 1.2, 4.9), PLASTER)
			b.box(Vector3(jx, GATE_H - 0.4, z), Vector3(3.8, 0.3, 5.0), WOOD)
			b.box(Vector3(jx, GATE_H + 1.05, z), Vector3(4.5, 0.3, 5.7), TILE)
			b.box(Vector3(jx, GATE_H + 1.25, z), Vector3(3.9, 0.2, 5.1), TILE_EDGE)
			_flag(Vector3(jx, 4.4, z - 2.45), Vector3(1.6, 5.2, 0.08), 1.0)
			JapanKit.chochin(b, Vector3(jx - float(side) * 1.2, 6.6, z - 2.7), Color("e8463a"), 1.4)
	g.box(Vector3(gx, GATE_H + 0.5, z), Vector3(GATE_HALF * 2.0 + 0.6, 1.0, 3.6), WOOD)
	if lift > 0.0:
		# The wall over the lintel: plaster between timber bands, the crest on it.
		g.box(Vector3(gx, GATE_H + 1.0 + lift * 0.5, z), Vector3(GATE_HALF * 2.0 + 0.2, lift, 3.2), PLASTER)
		for s in [-1.0, 1.0]:
			g.box(Vector3(gx, GATE_H + 1.0 + lift - 0.2, z + float(s) * 1.62), Vector3(GATE_HALF * 2.0 + 0.2, 0.36, 0.1), WOOD)
	var top := jamb
	var span := GATE_HALF * 2.0 + 7.0 + float(k)
	var depth := 4.6 + float(k) * 0.5
	g.box(Vector3(gx, top + 0.15, z), Vector3(span + 0.4, 0.3, depth + 0.4), WOOD)
	g.box(Vector3(gx, top + 1.8, z), Vector3(span, 3.2, depth), PLASTER)
	for i in 5:
		var x := gx + (float(i) - 2.0) * span * 0.19
		for s in [-1.0, 1.0]:
			g.box(Vector3(x, top + 1.9, z + float(s) * (depth * 0.5 + 0.03)), Vector3(0.8, 1.0, 0.06), Color("3a2c22"))
	g.roof(Vector3(gx, top + 4.0, z), span + 3.0, depth + 2.8, 1.6, TILE, 0.55)
	_eaves(g, Vector3(gx, top + 3.3, z), span + 2.9, depth + 2.7, 1.0 + float(k) * 0.15)
	var ridge_y := top + 4.9
	var ridge := span * 0.6
	if k >= 1:
		# A second storey under its own roof.
		var s2 := span * 0.56
		var d2 := depth * 0.72
		g.box(Vector3(gx, top + 5.3, z), Vector3(s2, 2.4, d2), PLASTER)
		g.box(Vector3(gx, top + 4.3, z), Vector3(s2 + 0.3, 0.3, d2 + 0.3), WOOD)
		for i in 3:
			var x := gx + (float(i) - 1.0) * s2 * 0.3
			for s in [-1.0, 1.0]:
				g.box(Vector3(x, top + 5.5, z + float(s) * (d2 * 0.5 + 0.03)), Vector3(0.8, 0.9, 0.06), Color("3a2c22"))
		g.roof(Vector3(gx, top + 7.1, z), s2 + 2.8, d2 + 2.8, 1.5, TILE, 0.5)
		_eaves(g, Vector3(gx, top + 6.45, z), s2 + 2.7, d2 + 2.7, 0.9)
		ridge_y = top + 7.9
		ridge = s2 * 0.5
	g.box(Vector3(gx, ridge_y, z), Vector3(ridge + 0.8, 0.35, 0.5), TILE_EDGE)
	if k >= 2:
		_shachi(g, Vector3(gx, ridge_y + 0.1, z), ridge + 0.4, 1.0)
	else:
		for side in [-1.0, 1.0]:
			g.box(Vector3(gx + float(side) * ridge * 0.5, ridge_y + 0.3, z), Vector3(0.5, 0.8, 0.5), GOLD)
	# The crest: a golden disc with a red heart on the turret's front (on the wall over the
	# lintel too at the throne court's gate).
	var crest := 1.0 + float(k) * 0.15
	g.cyl(Vector3(gx, top + 2.0, z + depth * 0.5 + 0.2), crest, 0.12, GOLD, Vector3(90, 0, 0), 16)
	g.cyl(Vector3(gx, top + 2.0, z + depth * 0.5 + 0.26), crest * 0.6, 0.12, Color("c0392b"), Vector3(90, 0, 0), 16)
	if k >= 2:
		g.cyl(Vector3(gx, GATE_H + 1.0 + lift * 0.5, z + 1.7), 1.5, 0.12, GOLD, Vector3(90, 0, 0), 16)
		g.cyl(Vector3(gx, GATE_H + 1.0 + lift * 0.5, z + 1.76), 0.9, 0.12, Color("c0392b"), Vector3(90, 0, 0), 16)
	# Paper lanterns under the eaves at both ends, and the holder's long banners on the jambs.
	for side in [-1.0, 1.0]:
		JapanKit.chochin(b, Vector3(gx + float(side) * (span * 0.5 + 0.7), top + 2.4, z + depth * 0.5 + 0.9), Color("e8463a"), 1.5)
		var fh := 4.2 + float(k) * 1.2
		_flag(Vector3(gx + float(side) * (GATE_HALF + 1.6), jamb - 0.3 - fh * 0.5, z + 2.45), Vector3(1.4 + float(k) * 0.3, fh, 0.08), 0.9 + float(k) * 0.15)
	var mi := g.commit(root, "GateTop%d_%d" % [k, 0 if gx <= 0.0 else 1])
	mi.visibility_range_end = 0.0
	mi.add_to_group(ThirdPersonCamera.FADE_GROUP)


static func _castle(root: Node3D, m: Masonry) -> void:
	var b := JapanKit.Batch.new()
	# The great front wall across the whole moat (dressed on its outer face; inside the
	# hall on both), the first gate in the middle.
	var reach := RADIUS + 34.0
	var lane_in := LANE_X - GATE_HALF - 3.2
	var lane_out := LANE_X + GATE_HALF + 3.2
	_wall_x(b, m, root, -reach, -HALL_HALF, GATE_Z[0], [1])
	_wall_x(b, m, root, HALL_HALF, reach, GATE_Z[0], [1])
	# The first two tiers: a wall with a left and a right gate (LANE_X), a pier between them.
	for k in 2:
		var faces := [1, -1]
		_wall_x(b, m, root, -HALL_HALF, -lane_out, GATE_Z[k], faces)
		_wall_x(b, m, root, -lane_in, lane_in, GATE_Z[k], faces)
		_wall_x(b, m, root, lane_out, HALL_HALF, GATE_Z[k], faces)
	# The yards' long side walls (dressed inside) to the third gate. The throne court's walls
	# stand COURT_H taller (the court's floor is that much higher): the wider wall with the
	# third gate (the court's front), the side walls past the staircase and the back wall,
	# dressed inside from the floor they stand over.
	var court_top := STONE_H + COURT_H
	var head := STAIR_Z1 + STAIR_LEAD
	_wall_z(b, m, root, -HALL_HALF, GATE_Z[0], GATE_Z[2], [1])
	_wall_z(b, m, root, HALL_HALF, GATE_Z[0], GATE_Z[2], [-1])
	_wall_x(b, m, root, -THRONE_HALF, -GATE_HALF - 3.2, GATE_Z[2], [1, -1], court_top)
	_wall_x(b, m, root, GATE_HALF + 3.2, THRONE_HALF, GATE_Z[2], [1, -1], court_top)
	for s in [-1.0, 1.0]:
		_wall_z(b, m, root, float(s) * THRONE_HALF, GATE_Z[2], head, [-s], court_top)
		_wall_z(b, m, root, float(s) * THRONE_HALF, head, BACK_Z, [-s], court_top, [COURT_H])
	_wall_x(b, m, root, -THRONE_HALF, THRONE_HALF, BACK_Z, [1], court_top, [COURT_H])
	for k in 3:
		for lane in TIER_LANES[k]:
			_gatehouse(b, m, k, root, gate_x(k, lane))
	# Turrets: three storeys on the hall's and the throne court's corners, two along the front wall.
	for x in [-HALL_HALF, HALL_HALF]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[0]), 7.0, STONE_H + 1.2, 3)
	for x in [-THRONE_HALF, THRONE_HALF]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[2]), 7.0, court_top + 1.2, 3)
		_yagura(b, m, Vector3(x, 0, BACK_Z), 7.0, court_top + 1.2, 3)
	for x in [-104.0, -78.0, -52.0, 52.0, 78.0, 104.0]:
		_yagura(b, m, Vector3(x, 0, GATE_Z[0]), 6.0)
	# The holder's nobori along the wall tops: the front wall (between its turrets), the
	# yards' side walls and the throne court's.
	var wall_top := STONE_H + PARAPET_H - 0.2
	for x in [34.0, 40.0, 46.0, 60.0, 66.0, 72.0, 86.0, 92.0, 98.0, 112.0, 118.0]:
		for s in [-1.0, 1.0]:
			_nobori(b, Vector3(float(s) * float(x), wall_top, GATE_Z[0]), 4.6)
	for z in [-27.0, -36.0, -45.0, -63.0, -72.0, -81.0]:
		for s in [-1.0, 1.0]:
			_nobori(b, Vector3(float(s) * HALL_HALF, wall_top, z), 4.2, false)
	for z in [-108.0, -118.0, -128.0]:
		for s in [-1.0, 1.0]:
			_nobori(b, Vector3(float(s) * THRONE_HALF, wall_top + COURT_H, z), 4.6, false)
	for x in [-30.0, -20.0, 20.0, 30.0]:
		_nobori(b, Vector3(x, wall_top + COURT_H, BACK_Z), 4.6)
	# Paving in the yards, and the landing in front of the first gate.
	_trim.box(Vector3(0, 0.03, (GATE_Z[0] + STAIR_Z0) * 0.5), Vector3(HALL_HALF * 2.0, 0.06, GATE_Z[0] - STAIR_Z0), PAVING)
	_trim.box(Vector3(0, 0.02, (GATE_Z[2] + STAIR_Z0) * 0.5), Vector3(THRONE_HALF * 2.0, 0.04, GATE_Z[2] - STAIR_Z0), PAVING)
	_trim.box(Vector3(0, 0.04, (MOAT_NORTH + GATE_Z[0]) * 0.5), Vector3(BRIDGE_HALF * 2.0 + 4.0, 0.06, MOAT_NORTH - GATE_Z[0] + 1.0), PAVING)
	for k in 2:
		for f in [0.3, 0.5, 0.7]:
			_trim.box(Vector3(0, 0.08, GATE_Z[k] - GATE_GAP * f), Vector3(HALL_HALF * 2.0 - 3.6, 0.04, 0.12), Color("9e9787"))
		# A darker border round each yard and a paved band down each lane to the next gate.
		for s in [-1.0, 1.0]:
			_trim.box(Vector3(float(s) * (HALL_HALF - 5.2), 0.075, GATE_Z[k] - GATE_GAP * 0.5), Vector3(0.5, 0.04, GATE_GAP - 8.0), Color("8d8676"))
			_trim.box(Vector3(float(s) * LANE_X, 0.07, GATE_Z[k] - GATE_GAP * 0.5), Vector3(6.0, 0.03, GATE_GAP - 5.0), PAVING.lightened(0.14))
			for e in [-1.0, 1.0]:
				_trim.box(Vector3(float(s) * LANE_X + float(e) * 3.2, 0.075, GATE_Z[k] - GATE_GAP * 0.5), Vector3(0.3, 0.03, GATE_GAP - 5.0), Color("8d8676"))
			for i in 5:
				_trim.box(Vector3(float(s) * LANE_X, 0.09, GATE_Z[k] - 6.0 - float(i) * 6.0), Vector3(1.5, 0.03, 1.5), GOLD_DARK if i % 2 == 0 else Color("b5483a"), Vector3(0, 45, 0))
		# The yard's medallion between the lanes.
		var heart := Vector3(0, 0, GATE_Z[k] - GATE_GAP * 0.5)
		_trim.cyl(heart + Vector3(0, 0.07, 0), 4.6, 0.06, Color("8d8676"), Vector3.ZERO, 24)
		_trim.cyl(heart + Vector3(0, 0.08, 0), 4.2, 0.08, PAVING.lightened(0.16), Vector3.ZERO, 24)
		_trim.cyl(heart + Vector3(0, 0.09, 0), 2.6, 0.1, GOLD_DEEP, Vector3.ZERO, 24)
		_trim.cyl(heart + Vector3(0, 0.1, 0), 2.0, 0.12, Color("c0392b"), Vector3.ZERO, 24)
		_trim.cyl(heart + Vector3(0, 0.11, 0), 0.9, 0.14, GOLD, Vector3.ZERO, 12)
	# The yards: tall stone lanterns along the walls.
	for k in 2:
		for f in [0.15, 0.38, 0.62, 0.85]:
			for x in [-HALL_HALF + 3.0, HALL_HALF - 3.0]:
				JapanKit.toro(b, Vector3(x, 0, GATE_Z[k] - GATE_GAP * f), 1.3)
	_stairs(b)
	_court(b, root)
	_commit(b, root, "Castle")


## The grand staircase from the third gate up to the throne court: STAIR_STEPS stone steps
## as wide as the court in two flights with a landing between (the ramps fighters walk are
## _court_floor's), the red carpet up its middle, stone cheeks and great lanterns by the
## walls, guardian lions, lamp posts and the holder's banners on the landing.
static func _stairs(b: JapanKit.Batch) -> void:
	var width := THRONE_HALF * 2.0 - 3.4
	var per := STAIR_STEPS / 2
	var rise := COURT_H / float(STAIR_STEPS)
	var tread := STAIR_FLIGHT / float(per)
	var half := COURT_H * 0.5
	var land_z := STAIR_Z0 - STAIR_FLIGHT - STAIR_LANDING * 0.5
	var slope := rad_to_deg(atan2(half, STAIR_FLIGHT))
	var length := sqrt(half * half + STAIR_FLIGHT * STAIR_FLIGHT)
	for flight in 2:
		var z_from := STAIR_Z0 - float(flight) * (STAIR_FLIGHT + STAIR_LANDING)
		var y_from := float(flight) * half
		for i in per:
			var zc := z_from - (float(i) + 0.5) * tread
			var h := y_from + float(i + 1) * rise
			b.box(Vector3(0, h * 0.5, zc), Vector3(width, h, tread), STONE if i % 2 == 0 else STONE.lightened(0.06))
			_trim.box(Vector3(0, h - 0.025, zc + tread * 0.5 - 0.05), Vector3(width, 0.07, 0.14), PAVING.lightened(0.16))
			_trim.box(Vector3(0, h - rise * 0.5 - 0.04, zc + tread * 0.5 + 0.01), Vector3(width, rise - 0.08, 0.03), STONE_CORE)
		# The carpet laid over this flight's edges, gold along its sides.
		var mid := Vector3(0, y_from + half * 0.5 + rise, z_from - STAIR_FLIGHT * 0.5)
		_trim.box(mid + Vector3(0, 0.03, 0), Vector3(5.0, 0.05, length + 0.2), Color("a8322a"), Vector3(slope, 0, 0))
		for s in [-1.0, 1.0]:
			_trim.box(mid + Vector3(float(s) * 2.6, 0.05, 0), Vector3(0.26, 0.06, length + 0.2), GOLD_DEEP, Vector3(slope, 0, 0))
			# The stone cheek along the wall, capped.
			var x: float = float(s) * (width * 0.5 - 1.0)
			b.box(Vector3(x, y_from + half * 0.5 + 0.6, z_from - STAIR_FLIGHT * 0.5), Vector3(1.8, 1.5, length), STONE_CORE, Vector3(slope, 0, 0))
			b.box(Vector3(x, y_from + half * 0.5 + 1.42, z_from - STAIR_FLIGHT * 0.5 - 0.2), Vector3(2.1, 0.22, length), STONE.lightened(0.12), Vector3(slope, 0, 0))
	# The landing between the flights: a paved band of its own, the carpet across it,
	# inlaid diamonds, and at its ends and beside the carpet what makes a stair grand:
	# gilded guardian lions on pedestals, lamp posts and the holder's tall banners (all
	# thin or by the walls: nothing to walk round).
	b.box(Vector3(0, half * 0.5, land_z), Vector3(width, half, STAIR_LANDING), STONE.lightened(0.1))
	_trim.box(Vector3(0, half + 0.02, land_z), Vector3(width, 0.05, STAIR_LANDING - 0.1), PAVING.lightened(0.2))
	_trim.box(Vector3(0, half + 0.05, land_z), Vector3(5.0, 0.05, STAIR_LANDING + 0.3), Color("a8322a"))
	for s in [-1.0, 1.0]:
		_trim.box(Vector3(float(s) * 2.6, half + 0.06, land_z), Vector3(0.26, 0.05, STAIR_LANDING + 0.3), GOLD_DEEP)
		for i in 6:
			_trim.box(Vector3(float(s) * (6.0 + float(i) * 5.2), half + 0.06, land_z), Vector3(0.8, 0.03, 0.8), GOLD_DARK if i % 2 == 0 else Color("b5483a"), Vector3(0, 45, 0))
		var x: float = float(s) * (width * 0.5 - 1.0)
		# By the wall: a pedestal with a great lantern at the foot, on the landing and at the head.
		for spot in [Vector3(x, 0.0, STAIR_Z0 + 1.1), Vector3(x, half, land_z), Vector3(x, COURT_H, STAIR_Z1 - 1.3)]:
			b.box(spot + Vector3(0, 0.9, 0), Vector3(2.4, 1.8, 2.0), STONE_CORE)
			b.box(spot + Vector3(0, 1.9, 0), Vector3(2.7, 0.24, 2.3), STONE.lightened(0.12))
			JapanKit.toro(b, spot + Vector3(0, 2.0, 0), 1.7)
		# Guardian lions on the landing either side of the carpet, and at the stair's head.
		for lion in [Vector3(float(s) * 9.0, half, land_z), Vector3(float(s) * 30.0, COURT_H, STAIR_Z1 - 1.3)]:
			b.box(lion + Vector3(0, 0.55, 0), Vector3(1.5, 1.1, 1.4), STONE_CORE)
			b.box(lion + Vector3(0, 1.16, 0), Vector3(1.8, 0.16, 1.7), STONE.lightened(0.12))
			_lion(b, lion + Vector3(0, 1.22, 0), -float(s))
		# Lamp posts beside the carpet at the foot, the landing and the head; tall banners
		# in the holder's colour up both flights.
		_lamp(b, Vector3(float(s) * 6.6, 0.0, STAIR_Z0 + 0.4), 3.6, Vector3(-float(s) * 0.6, 0, 0))
		_lamp(b, Vector3(float(s) * 4.2, half, land_z), 3.6, Vector3(float(s) * 0.6, 0, 0))
		_lamp(b, Vector3(float(s) * 4.2, COURT_H, STAIR_Z1 - 0.6), 3.6, Vector3(float(s) * 0.6, 0, 0))
		for bx in [15.0, 21.5]:
			_nobori(b, Vector3(float(s) * float(bx), half, land_z), 6.4)
		_brazier(b, Vector3(float(s) * (width * 0.5 - 4.2), COURT_H, STAIR_Z1 - 1.3), 1.5)


## A guardian lion-dog (komainu) in gilded stone sitting at `at`, looking south and a little
## towards `turn` (-1 west, 1 east).
static func _lion(b: JapanKit.Batch, at: Vector3, turn: float) -> void:
	var gold := GOLD_DEEP
	b.box(at + Vector3(0, 0.55, -0.25), Vector3(0.9, 1.1, 1.3), gold, Vector3(-18, 0, 0))
	b.ball(at + Vector3(turn * 0.12, 1.45, 0.42), Vector3(1.0, 0.95, 0.95), gold)
	b.ball(at + Vector3(turn * 0.12, 1.55, 0.2), Vector3(1.35, 1.2, 0.9), GOLD_DARK)
	b.box(at + Vector3(turn * 0.16, 1.3, 0.92), Vector3(0.5, 0.36, 0.4), gold)
	for s in [-1.0, 1.0]:
		b.box(at + Vector3(float(s) * 0.3, 0.45, 0.5), Vector3(0.26, 0.9, 0.3), gold)
	b.ball(at + Vector3(0, 0.75, -1.0), Vector3(0.5, 0.9, 0.5), GOLD_DARK)


## The raised throne court: its paving, the carpet between two rows of vermilion pillars
## (open to the sky, so the camera above sees the fight), the altar's inlaid dais, and
## against the back wall the canopied throne screen between the holder's great banners.
static func _court(b: JapanKit.Batch, root: Node3D) -> void:
	var up := Vector3(0, COURT_H, 0)
	var head := STAIR_Z1 + STAIR_LEAD
	_trim.box(Vector3(0, COURT_H - 0.02, (STAIR_Z1 + BACK_Z) * 0.5), Vector3(THRONE_HALF * 2.0, 0.1, STAIR_Z1 - BACK_Z), PAVING)
	for i in 4:
		_trim.box(Vector3(0, COURT_H + 0.05, head - 5.0 - float(i) * 8.4), Vector3(THRONE_HALF * 2.0 - 3.6, 0.04, 0.12), Color("9e9787"))
	for s in [-1.0, 1.0]:
		_trim.box(Vector3(float(s) * (THRONE_HALF * 0.62 - 2.4), COURT_H + 0.05, (head + BACK_Z) * 0.5), Vector3(0.5, 0.04, head - BACK_Z - 6.0), Color("8d8676"))
	for i in 4:
		for s in [-1.0, 1.0]:
			_trim.box(Vector3(float(s) * 5.4, COURT_H + 0.06, head - 3.0 - float(i) * 6.4), Vector3(1.3, 0.03, 1.3), GOLD_DARK if i % 2 == 0 else Color("b5483a"), Vector3(0, 45, 0))
	# The carpet from the staircase's head to the altar, gold along its sides.
	_trim.box(Vector3(0, COURT_H + 0.06, (head + ALTAR.z) * 0.5), Vector3(5.0, 0.05, head - ALTAR.z), Color("a8322a"))
	for s in [-1.0, 1.0]:
		_trim.box(Vector3(float(s) * 2.6, COURT_H + 0.07, (head + ALTAR.z) * 0.5), Vector3(0.26, 0.05, head - ALTAR.z), GOLD_DEEP)
	for i in 7:
		var z := GATE_Z[2] - 5.0 - float(i) * (THRONE_DEPTH - 9.0) / 6.0
		for x in [-THRONE_HALF * 0.62, THRONE_HALF * 0.62]:
			var foot := Vector3(x, floor_y(Vector3(x, 0, z)), z)
			b.cyl(foot + Vector3(0, 0.4, 0), 1.0, 0.8, STONE)
			b.cyl(foot + Vector3(0, 3.4, 0), 0.6, 6.0, JapanKit.VERMILION, Vector3.ZERO, 12)
			b.cyl(foot + Vector3(0, 1.0, 0), 0.66, 0.3, GOLD, Vector3.ZERO, 12)
			b.cyl(foot + Vector3(0, 6.1, 0), 0.66, 0.3, GOLD, Vector3.ZERO, 12)
			b.box(foot + Vector3(0, 6.55, 0), Vector3(1.6, 0.3, 1.6), WOOD)
			b.box(foot + Vector3(0, 6.9, 0), Vector3(1.0, 0.4, 1.0), GOLD)
	# The altar: rings of stone and gold let into the floor (flat: fighters stand on it),
	# eight golden lotus points round it.
	var altar := ALTAR + up
	_trim.cyl(altar + Vector3(0, 0.04, 0), ALTAR_RADIUS + 3.4, 0.08, STONE_CORE.lightened(0.12), Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.05, 0), ALTAR_RADIUS + 3.0, 0.1, PAVING.lightened(0.16), Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.06, 0), ALTAR_RADIUS + 1.2, 0.12, STONE, Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.07, 0), ALTAR_RADIUS + 0.5, 0.14, STONE.lightened(0.15), Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.08, 0), ALTAR_RADIUS, 0.16, GOLD_DEEP, Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.09, 0), ALTAR_RADIUS - 0.6, 0.18, Color("fff1c8"), Vector3.ZERO, 32)
	_trim.cyl(altar + Vector3(0, 0.1, 0), ALTAR_RADIUS * 0.4, 0.2, GOLD, Vector3.ZERO, 16)
	for i in 8:
		var angle := TAU * (float(i) + 0.5) / 8.0
		var at := altar + Vector3(cos(angle) * (ALTAR_RADIUS + 2.1), 0, sin(angle) * (ALTAR_RADIUS + 2.1))
		_trim.box(at + Vector3(0, 0.12, 0), Vector3(0.9, 0.08, 0.9), GOLD, Vector3(0, -rad_to_deg(angle) + 45.0, 0))
		_trim.box(at + Vector3(0, 0.14, 0), Vector3(0.5, 0.1, 0.5), Color("c0392b"), Vector3(0, -rad_to_deg(angle) + 45.0, 0))
	# Against the back wall behind the altar: a stepped dais, a tall gilded folding screen
	# (byobu) of six panels, a tiled canopy on vermilion posts with the golden crest under
	# it, the holder's two great banners either side, and great fire bowls.
	var wall := BACK_Z + 2.4
	# All of it is one mesh of its own that fades out while the camera is at it or behind it
	# (ThirdPersonCamera.FADE_GROUP): a view from the back wall is never filled by the screen.
	var t := JapanKit.Batch.new()
	var castle_flags := _flags
	_flags = JapanKit.Batch.new()
	t.box(up + Vector3(0, 0.2, wall + 1.2), Vector3(20.0, 0.4, 2.6), WOOD)
	t.box(up + Vector3(0, 0.55, wall + 0.9), Vector3(16.0, 0.3, 1.8), JapanKit.VERMILION.darkened(0.15))
	for i in 6:
		var px := (float(i) - 2.5) * 2.3
		var tilt := 8.0 if i % 2 == 0 else -8.0
		t.box(up + Vector3(px, 3.4, wall + 0.5), Vector3(2.3, 5.4, 0.16), GOLD_DEEP, Vector3(0, tilt, 0))
		t.box(up + Vector3(px, 6.15, wall + 0.5), Vector3(2.4, 0.16, 0.24), WOOD, Vector3(0, tilt, 0))
		t.box(up + Vector3(px, 3.4, wall + 0.6), Vector3(1.5, 3.6, 0.1), Color("fff1c8"), Vector3(0, tilt, 0))
	for s in [-1.0, 1.0]:
		t.cyl(up + Vector3(float(s) * 9.0, 4.0, wall + 2.0), 0.4, 8.0, JapanKit.VERMILION, Vector3.ZERO, 10)
		t.cyl(up + Vector3(float(s) * 9.0, 0.5, wall + 2.0), 0.55, 0.5, GOLD, Vector3.ZERO, 10)
		t.cyl(up + Vector3(float(s) * 9.0, 7.7, wall + 2.0), 0.5, 0.4, GOLD, Vector3.ZERO, 10)
		_flag(up + Vector3(float(s) * 13.6, 5.2, wall + 0.2), Vector3(3.2, 8.4, 0.1), 2.0)
		t.box(up + Vector3(float(s) * 13.6, 9.5, wall + 0.2), Vector3(3.8, 0.2, 0.2), WOOD)
		_brazier(b, up + Vector3(float(s) * (ALTAR_RADIUS + 5.5), 0, ALTAR.z - 1.0), 1.7)
		_brazier(b, up + Vector3(float(s) * 17.5, 0, wall + 1.6), 1.5)
	t.box(up + Vector3(0, 8.1, wall + 1.2), Vector3(19.4, 0.4, 2.6), WOOD)
	t.roof(up + Vector3(0, 9.0, wall + 1.0), 22.0, 4.6, 1.5, TILE, 0.7)
	_eaves(t, up + Vector3(0, 8.4, wall + 1.0), 21.8, 4.4, 1.0)
	t.box(up + Vector3(0, 9.85, wall + 1.0), Vector3(15.0, 0.3, 0.5), TILE_EDGE)
	_shachi(t, up + Vector3(0, 9.9, wall + 1.0), 14.6, 0.9)
	t.cyl(up + Vector3(0, 6.9, wall + 0.75), 1.5, 0.14, GOLD, Vector3(90, 0, 0), 20)
	t.cyl(up + Vector3(0, 6.9, wall + 0.83), 0.9, 0.14, Color("c0392b"), Vector3(90, 0, 0), 20)
	var screen := t.mesh()
	if not _flags.is_empty() and _banner != null:
		screen.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _flags.mesh().surface_get_arrays(0))
		screen.surface_set_material(screen.get_surface_count() - 1, _banner)
	_flags = castle_flags
	var mi := MeshInstance3D.new()
	mi.name = "ThroneScreen"
	mi.mesh = screen
	root.add_child(mi)
	mi.add_to_group(ThirdPersonCamera.FADE_GROUP)
	# Great hanging banners in the holder's colour along the throne court (over the stairs
	# too, each over its own floor).
	for f in [0.15, 0.4, 0.65, 0.9]:
		var z: float = GATE_Z[2] - THRONE_DEPTH * float(f)
		for x in [-THRONE_HALF + 2.2, THRONE_HALF - 2.2]:
			_flag(Vector3(x, floor_y(Vector3(x, 0, z)) + 5.6, z), Vector3(0.08, 6.0, 2.2), 1.4)


## What fighters stand on past the third gate: the staircase's ramp (smooth, under the
## steps, through the middle of each tread) and the court's floor, as wide as the court.
static func _court_floor(root: Node3D) -> void:
	var z0 := STAIR_Z0 + STAIR_LEAD
	var z1 := STAIR_Z1 + STAIR_LEAD
	var half := COURT_H * 0.5
	JapanKit.collider(root, Vector3(0, (COURT_H - 1.0) * 0.5, (z1 + BACK_Z) * 0.5), Vector3(THRONE_HALF * 2.0, COURT_H + 1.0, z1 - BACK_Z))
	# The landing between the flights (level), and a ramp under each flight.
	JapanKit.collider(root, Vector3(0, (half - 1.0) * 0.5, z0 - STAIR_FLIGHT - STAIR_LANDING * 0.5), Vector3(THRONE_HALF * 2.0, half + 1.0, STAIR_LANDING))
	_ramp(root, "StairRamp", z0, 0.0)
	_ramp(root, "StairRampUpper", z0 - STAIR_FLIGHT - STAIR_LANDING, half)


## One flight's ramp: from (z, y) rising half the court's height over STAIR_FLIGHT northwards.
static func _ramp(root: Node3D, node_name: String, z: float, y: float) -> void:
	var half := COURT_H * 0.5
	var angle := atan2(half, STAIR_FLIGHT)
	var length := sqrt(half * half + STAIR_FLIGHT * STAIR_FLIGHT)
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.position = Vector3(0, y + half * 0.5, z - STAIR_FLIGHT * 0.5) - Vector3(0, cos(angle), sin(angle)) * 0.5
	body.rotation.x = angle
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(THRONE_HALF * 2.0, 1.0, length)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)


## A soft shaft of light standing over the altar, seen from the whole field (one see-through
## additive column: no light, no particles).
static func _altar_beam(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.9, 0.6, 0.1)
	var beam := MeshKit.part(root, MeshKit.cylinder(), mat, ALTAR + Vector3(0, COURT_H + 30.0, 0), Vector3(2.4, 60.0, 2.4), Vector3.ZERO, "AltarBeam")
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A tiered keep (tenshu): white storeys under dark tiled roofs with sweeping gilded eaves
## and gables on alternate sides, lit windows, a balcony round the top storey and the
## golden ridge-fish (shachihoko) on top. Returns the height of its ridge above `at`.
static func _tenshu(b: JapanKit.Batch, at: Vector3, tiers: int, width: float, storey: float, shrink := 0.15, roof := TILE) -> float:
	var y := 0.0
	var s := width
	for i in tiers:
		s = width * (1.0 - float(i) * shrink)
		var h := storey * (1.0 - float(i) * 0.03)
		b.box(at + Vector3(0, y + 0.2, 0), Vector3(s + 0.4, 0.4, s + 0.4), WOOD)
		b.box(at + Vector3(0, y + 0.4 + h * 0.5, 0), Vector3(s, h, s), PLASTER)
		for k in 4:
			var x := (float(k) - 1.5) * s * 0.22
			for zs in [-1.0, 1.0]:
				var lit := (k + i) % 2 == 0
				b.box(at + Vector3(x, y + 0.4 + h * 0.55, float(zs) * (s * 0.5 + 0.03)), Vector3(s * 0.08, h * 0.3, 0.06), Color("ffe3a0") if lit else Color("3a2c22"), Vector3.ZERO, lit)
				if tiers >= 6:
					b.box(at + Vector3(float(zs) * (s * 0.5 + 0.03), y + 0.4 + h * 0.55, x), Vector3(0.06, h * 0.3, s * 0.08), Color("3a2c22"))
		if i == tiers - 1 and tiers >= 4:
			# The balcony round the top storey, railed in vermilion.
			b.box(at + Vector3(0, y + 0.5, 0), Vector3(s + 1.8, 0.16, s + 1.8), WOOD)
			for e in [-1.0, 1.0]:
				b.box(at + Vector3(0, y + 1.2, float(e) * (s * 0.5 + 0.85)), Vector3(s + 1.8, 0.12, 0.12), JapanKit.VERMILION)
				b.box(at + Vector3(float(e) * (s * 0.5 + 0.85), y + 1.2, 0), Vector3(0.12, 0.12, s + 1.8), JapanKit.VERMILION)
		y += h + 0.4
		var over := 3.4 + width * 0.06
		b.roof(at + Vector3(0, y + 0.55, 0), s + over, s + over, 1.5, roof, 0.25)
		_eaves(b, at + Vector3(0, y - 0.1, 0), s + over - 0.1, s + over - 0.1, 0.7 + width * 0.03)
		if i < tiers - 1:
			# A gable on two sides, turning with each roof.
			for e in [-1.0, 1.0]:
				var out: float = float(e) * (s * 0.5 + 0.8)
				if i % 2 == 0:
					b.box(at + Vector3(0, y + 1.2, out), Vector3(s * 0.4, 1.4, 0.5), PLASTER)
					b.roof(at + Vector3(0, y + 2.1, out), s * 0.5, 1.6, 0.9, roof, 0.6)
					b.box(at + Vector3(0, y + 1.3, out + float(e) * 0.28), Vector3(0.5, 0.5, 0.06), GOLD, Vector3(0, 0, 45))
				else:
					b.box(at + Vector3(out, y + 1.2, 0), Vector3(0.5, 1.4, s * 0.4), PLASTER)
					b.roof(at + Vector3(out, y + 2.1, 0), s * 0.5, 1.6, 0.9, roof, 0.6, 90.0)
					b.box(at + Vector3(out + float(e) * 0.28, y + 1.3, 0), Vector3(0.06, 0.5, 0.5), GOLD, Vector3(45, 0, 0))
		y += 1.2
	b.box(at + Vector3(0, y + 0.3, 0), Vector3(s * 0.45 + 0.6, 0.5, 0.6), TILE_EDGE)
	_shachi(b, at + Vector3(0, y + 0.5, 0), s * 0.45, 0.8 + width * 0.03)
	return y + 0.55


## The great keep behind the throne court on its stepped stone base (megalithic courses),
## joined by roofed galleries to a lesser keep either side; two more lesser keeps beside
## the hall with terraced walls stepping up to them. The great keep flies the holder's banners.
static func _keeps(root: Node3D, m: Masonry) -> void:
	var b := JapanKit.Batch.new()
	var main := Vector3(0, 0, BACK_Z - 19.0)
	b.box(main + Vector3(0, 6.5, 0), Vector3(38.0, 13.0, 30.0), STONE_CORE)
	m.block(main, Vector3(39.0, 13.0, 31.0), 0.1, [0, 2, 3], 1.15, 2.1)
	b.box(main + Vector3(0, 17.5, 0), Vector3(30.0, 9.0, 24.0), STONE_CORE)
	m.block(main + Vector3(0, 13.0, 0), Vector3(31.0, 9.0, 25.0), 0.12, [0, 2, 3], 1.15, 2.1)
	# A plastered parapet round the lower terrace's rim.
	for e in [-1.0, 1.0]:
		_parapet(b, main + Vector3(float(e) * 18.0, 13.0, 14.0), main + Vector3(float(e) * 18.0, 13.0, -14.0))
	_parapet(b, main + Vector3(-18.0, 13.0, 14.0), main + Vector3(18.0, 13.0, 14.0))
	var keep_top := 22.0 + _tenshu(b, main + Vector3(0, 22.0, 0), 7, 24.0, 4.8, 0.115, KEEP_ROOF)
	# The holder's great banners down the upper base, seen over the court's back wall.
	for e in [-1.0, 1.0]:
		_flag(main + Vector3(float(e) * 9.0, 18.6, 12.8), Vector3(4.0, 10.0, 0.1), 2.6)
		_brazier(b, main + Vector3(float(e) * 16.0, 13.0, 12.6), 2.4)
	# The lesser keeps on their own bases, and the roofed galleries (watari-yagura) to them.
	for e in [-1.0, 1.0]:
		var x := float(e)
		var wing := main + Vector3(x * 32.0, 0, 5.0)
		b.box(wing + Vector3(0, 7.0, 0), Vector3(15.0, 14.0, 15.0), STONE_CORE)
		_tenshu(b, wing + Vector3(0, 14.0, 0), 4, 11.5, 3.6)
		var gx := x * 19.5
		b.box(main + Vector3(gx, 14.6, 6.0), Vector3(11.0, 3.2, 5.0), PLASTER)
		b.box(main + Vector3(gx, 13.15, 6.0), Vector3(11.2, 0.3, 5.3), WOOD)
		for k in 4:
			b.box(main + Vector3(gx + (float(k) - 1.5) * 2.4, 14.8, 8.53), Vector3(0.9, 1.0, 0.06), Color("ffe3a0"), Vector3.ZERO, true)
		b.roof(main + Vector3(gx, 16.9, 6.0), 12.4, 7.6, 1.6, TILE, 0.7)
		b.box(main + Vector3(gx, 17.75, 6.0), Vector3(8.0, 0.3, 0.5), TILE_EDGE)
	for xs in [-1.0, 1.0]:
		var x := float(xs)
		var side := Vector3(x * 46.0, 0, -62.0)
		b.box(side + Vector3(0, 4.5, 0), Vector3(13.0, 9.0, 13.0), STONE_CORE)
		m.block(side, Vector3(13.6, 9.0, 13.6), 0.1, [0, 2 if x > 0.0 else 3])
		_tenshu(b, side + Vector3(0, 9.0, 0), 4, 9.6, 3.0)
		# A terraced wall stepping up from the front wall towards the lesser keep.
		b.box(Vector3(x * 46.0, 2.5, -38.0), Vector3(20.0, 5.0, 2.6), STONE_CORE)
		m.face(Vector3(minf(x * 36.0, x * 56.0), 0, -36.7), Vector3(maxf(x * 36.0, x * 56.0), 0, -36.7), Vector3(0, 0, 1), 0.0, 5.0, 0.0, 0.06)
		_parapet(b, Vector3(x * 36.0, 5.0, -38.0), Vector3(x * 56.0, 5.0, -38.0))
	# A tall golden spire light on the great keep's ridge (glowing: the kingdom's beacon).
	b.cyl(main + Vector3(0, keep_top + 2.0, 0), 0.14, 3.0, GOLD, Vector3.ZERO, 6)
	b.ball(main + Vector3(0, keep_top + 3.8, 0), Vector3(1.1, 1.1, 1.1), Color("fff1b8"), true)
	_commit(b, root, "Keeps")


# ---------------------------------------------------------------------------
# Moat, bridge, camps, plaza, trees
# ---------------------------------------------------------------------------

static func _moat(root: Node3D, m: Masonry) -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2((RADIUS + 34.0) * 2.0, MOAT_SOUTH - MOAT_NORTH)
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


## A stone bridge: a paved deck on piers with a lighter band down each lane, a balustrade
## of capped posts under a vermilion rail, lamp posts and the holder's nobori along both
## sides, and great stone lanterns at both ends.
static func _bridge(root: Node3D, m: Masonry) -> void:
	var b := JapanKit.Batch.new()
	var length := MOAT_SOUTH - MOAT_NORTH + 4.0
	var mid := (MOAT_SOUTH + MOAT_NORTH) * 0.5
	b.box(Vector3(0, 0.15, mid), Vector3(BRIDGE_HALF * 2.0, 0.3, length), PAVING)
	for z in [mid - 2.2, mid + 2.2]:
		b.box(Vector3(0, 0.0, z), Vector3(BRIDGE_HALF * 2.0 - 0.6, 0.6, 1.4), STONE_CORE)
	for s in [-1.0, 1.0]:
		b.box(Vector3(float(s) * LANE_X, 0.31, mid), Vector3(7.0, 0.03, length), PAVING.lightened(0.12))
	b.box(Vector3(0, 0.315, mid), Vector3(1.2, 0.03, length), Color("8d8676"))
	for xs in [-1.0, 1.0]:
		var x: float = float(xs) * (BRIDGE_HALF - 0.3)
		b.box(Vector3(x, 0.55, mid), Vector3(0.5, 0.5, length), STONE)
		b.box(Vector3(x, 1.25, mid), Vector3(0.36, 0.2, length), JapanKit.VERMILION)
		var posts := 7
		for i in posts:
			var z := MOAT_SOUTH + 2.0 - float(i) * (length - 0.5) / float(posts - 1)
			b.box(Vector3(x, 0.9, z), Vector3(0.55, 1.1, 0.55), STONE_CORE.lightened(0.05))
			b.ball(Vector3(x, 1.6, z), Vector3(0.5, 0.45, 0.5), GOLD_DEEP)
			if i % 2 == 1:
				_lamp(b, Vector3(x + float(xs) * 0.5, 0.3, z), 4.0, Vector3(-float(xs) * 0.7, 0, 0))
			else:
				_nobori(b, Vector3(x + float(xs) * 0.5, 0.3, z), 5.6)
		var start := Vector3(x + float(xs) * 0.25, 0, MOAT_SOUTH + 2.0)
		var end := Vector3(x + float(xs) * 0.25, 0, MOAT_NORTH - 2.0)
		m.face(start if float(xs) > 0.0 else end, end if float(xs) > 0.0 else start, Vector3(float(xs), 0, 0), 0.0, 0.8, 0.02, 0.0, 0.4)
		for z in [MOAT_SOUTH + 2.6, MOAT_NORTH - 2.6]:
			JapanKit.toro(b, Vector3(float(xs) * (BRIDGE_HALF + 1.4), 0, z), 1.9)
	_commit(b, root, "Bridge")


## A guild's war camp out on the field (CAMPS[team]): a ring of war curtains (maku) in its
## colour with white bands and crest, tents, tall banners and a glowing circle where the
## fallen come back. The curtain opens towards the castle's approach.
static func _camp(root: Node3D, team: int, color: Color) -> void:
	var b := JapanKit.Batch.new()
	var center := camp(team)
	var fwd := camp_forward(team)
	var side := Vector3(-fwd.z, 0, fwd.x)
	var opening := Vector2(fwd.x, fwd.z)
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
	# Tents along the camp's two flanks, clear of the rows and the camera behind them.
	for i in 6:
		var at := center + fwd * (2.0 - float(i % 3) * 6.0) + side * (14.0 if i < 3 else -14.0)
		var yaw := rad_to_deg(atan2(fwd.x, fwd.z))
		b.box(at + Vector3(0, 0.9, 0), Vector3(3.6, 1.8, 3.2), color.lerp(Color.WHITE, 0.6), Vector3(0, yaw, 0))
		b.roof(at + Vector3(0, 2.4, 0), 4.4, 3.8, 1.3, color.darkened(0.2), 0.5)
	for i in 10:
		var angle := TAU * (float(i) + 0.5) / 10.0
		if Vector2(cos(angle), sin(angle)).dot(opening) > 0.8:
			continue
		JapanKit.banner(b, center + Vector3(cos(angle) * 17.5, 0, sin(angle) * 17.5), color)
	_commit(b, root, "Camp%d" % team)
	var ring := MeshInstance3D.new()
	ring.name = "CampRing%d" % team
	ring.mesh = MeshKit.cylinder()
	ring.material_override = VfxKit._glow(color, 0.5)
	ring.scale = Vector3(14.0, 0.02, 14.0)
	ring.position = center + Vector3(0, 0.06, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)


## The plaza where the guilds meet: a paved circle of ringed bands and eight spokes round a
## golden crest, ringed by tall stone lanterns (open towards the bridge); south of it the
## pilgrims' avenue of great torii and lanterns (all flat or thin: nothing to walk into).
static func _plaza(root: Node3D) -> void:
	var b := JapanKit.Batch.new()
	b.cyl(Vector3(PLAZA.x, 0.03, PLAZA.z), 14.6, 0.06, STONE_CORE.lightened(0.1), Vector3.ZERO, 36)
	b.cyl(Vector3(PLAZA.x, 0.04, PLAZA.z), 14.0, 0.08, PAVING, Vector3.ZERO, 36)
	b.cyl(Vector3(PLAZA.x, 0.05, PLAZA.z), 10.6, 0.1, Color("8d8676"), Vector3.ZERO, 36)
	b.cyl(Vector3(PLAZA.x, 0.055, PLAZA.z), 10.2, 0.11, PAVING.lightened(0.1), Vector3.ZERO, 36)
	b.cyl(Vector3(PLAZA.x, 0.06, PLAZA.z), 7.0, 0.12, STONE.lightened(0.1), Vector3.ZERO, 36)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		b.box(PLAZA + Vector3(cos(angle) * 10.4, 0.105, sin(angle) * 10.4), Vector3(0.5, 0.03, 7.0), Color("8d8676"), Vector3(0, 90.0 - rad_to_deg(angle), 0))
		b.box(PLAZA + Vector3(cos(angle + TAU / 16.0) * 5.0, 0.125, sin(angle + TAU / 16.0) * 5.0), Vector3(1.3, 0.03, 1.3), GOLD_DARK, Vector3(0, 45.0 - rad_to_deg(angle + TAU / 16.0), 0))
	b.cyl(Vector3(PLAZA.x, 0.07, PLAZA.z), 3.2, 0.14, GOLD_DEEP, Vector3.ZERO, 24)
	b.cyl(Vector3(PLAZA.x, 0.08, PLAZA.z), 2.5, 0.16, Color("c0392b"), Vector3.ZERO, 24)
	b.cyl(Vector3(PLAZA.x, 0.09, PLAZA.z), 1.2, 0.18, GOLD, Vector3.ZERO, 16)
	for i in 12:
		var angle := TAU * (float(i) + 0.5) / 12.0
		if absf(angle - PI * 1.5) < 0.6:
			continue
		JapanKit.toro(b, PLAZA + Vector3(cos(angle) * 15.0, 0, sin(angle) * 15.0), 1.2)
	# The avenue: great vermilion torii over the way from the south, lanterns between them.
	# Each torii is its own mesh that fades out while it stands between the camera and the
	# hero (ThirdPersonCamera.FADE_GROUP): its beams never cover a fight under it.
	var gates := 3
	for i in gates:
		var z := lerpf(AVENUE_Z0, AVENUE_Z1, float(i) / float(gates - 1))
		var gate := JapanKit.Batch.new()
		gate.xform = Transform3D(Basis(), Vector3(0, 0, z))
		JapanKit.torii(gate, 11.0, 8.6 + (1.4 if i == 0 else 0.0))
		var mi := gate.commit(root, "Torii%d" % i)
		mi.visibility_range_end = 0.0
		mi.add_to_group(ThirdPersonCamera.FADE_GROUP)
		if i == 0:
			for s in [-1.0, 1.0]:
				JapanKit.toro(b, Vector3(float(s) * 7.0, 0, z + (AVENUE_Z1 - AVENUE_Z0) / float(gates - 1) * 0.5), 1.5)
	_commit(b, root, "Plaza")


## The segment distance from p to the line a-b (flat).
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Black pines framing the field (clear of the camps, their roads, the plaza and the torii
## avenue), and cherry trees in bloom along the moat's bank and the avenue.
static func _pines(root: Node3D, rng: RandomNumberGenerator, camps := 2) -> void:
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_colors: Array[Color] = []
	var placed := 0
	var tries := 0
	# Every camp's road is kept clear, whichever camps are pitched.
	camps = CAMPS.size()
	while placed < 110 and tries < 1800:
		tries += 1
		var angle := rng.randf() * TAU
		var r := rng.randf_range(30.0, RADIUS + 22.0)
		var p := Vector3(cos(angle) * r, 0, sin(angle) * r)
		if p.z < MOAT_SOUTH + 3.0:
			continue
		var flat := Vector2(p.x, p.z)
		var clear := true
		for team in camps:
			var c := camp(team)
			if flat.distance_to(Vector2(c.x, c.z)) < 26.0 or _seg_dist(flat, Vector2(c.x, c.z), Vector2(APPROACH.x, APPROACH.z)) < 10.0:
				clear = false
				break
		if not clear:
			continue
		if flat.distance_to(Vector2(PLAZA.x, PLAZA.z)) < 22.0 or (absf(p.z - MOAT_SOUTH) < 10.0 and absf(p.x) < BRIDGE_HALF + 14.0):
			continue
		if absf(p.x) < 12.0 and p.z > AVENUE_Z0 - 8.0 and p.z < AVENUE_Z1 + 12.0:
			continue
		var h := rng.randf_range(5.0, 9.0)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.6, h * 0.5, 0.6)), p + Vector3(0, h * 0.25, 0)))
		trunk_colors.append(Color("5a3d2b"))
		for k in 3:
			var s := (1.0 - float(k) * 0.26) * rng.randf_range(3.2, 4.4)
			crowns.append(Transform3D(Basis().scaled(Vector3(s, s * 0.55, s)), p + Vector3(0, h * 0.45 + float(k) * h * 0.18, 0)))
			crown_colors.append(Color("2f5a3a").lerp(Color("3f7346"), rng.randf()))
		placed += 1
	# Cherry trees: along the moat's south bank beyond the bridge, and down the avenue.
	var blooms: Array[Transform3D] = []
	var bloom_colors: Array[Color] = []
	var art := RandomNumberGenerator.new()
	art.seed = 5113
	var spots: Array[Vector3] = []
	for i in 7:
		for s in [-1.0, 1.0]:
			spots.append(Vector3(float(s) * (BRIDGE_HALF + 17.0 + float(i) * 14.0), 0, MOAT_SOUTH + 4.6))
	for i in 4:
		for s in [-1.0, 1.0]:
			spots.append(Vector3(float(s) * 11.5, 0, AVENUE_Z0 - 4.0 + float(i) * 11.0))
	for p in spots:
		var clear := true
		for team in camps:
			var c := camp(team)
			if Vector2(p.x - c.x, p.z - c.z).length() < 22.0:
				clear = false
		if not clear:
			continue
		var h := art.randf_range(3.6, 4.8)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.5, h, 0.5)), p + Vector3(0, h * 0.5, 0)))
		trunk_colors.append(Color("4a3226"))
		for k in (2 if p.z > 0.0 else 1):
			var s := art.randf_range(5.2, 6.4) * (1.0 - float(k) * 0.3)
			var off := Vector3(art.randf_range(-0.8, 0.8), h + 0.6 + float(k) * 1.5, art.randf_range(-0.8, 0.8))
			blooms.append(Transform3D(Basis().scaled(Vector3(s, s * 0.7, s)), p + off))
			bloom_colors.append(Color("f7b4cc").lerp(Color("ffe3ee"), art.randf()))
	_batch(root, "PineTrunks", MeshKit.cylinder(), trunks, trunk_colors)
	_batch(root, "PineCrowns", MeshKit.cone(), crowns, crown_colors)
	_batch(root, "Blossoms", MeshKit.sphere_low(), blooms, bloom_colors)


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


# ---------------------------------------------------------------------------
# The kingdom beyond the walls (decoration only: outside the field, no colliders)
# ---------------------------------------------------------------------------

## A town house seen from afar: a plastered body under a hipped roof (two boxes' worth).
static func _town_house(b: JapanKit.Batch, at: Vector3, w: float, d: float, h: float, roof: Color, lit := false) -> void:
	b.box(at + Vector3(0, h * 0.5, 0), Vector3(w, h, d), PLASTER)
	b.roof(at + Vector3(0, h + 0.95, 0), w + 2.0, d + 2.0, 1.9, roof, 0.5)
	if lit:
		b.box(at + Vector3(0, h * 0.68, d * 0.5 + 0.06), Vector3(w * 0.5, h * 0.28, 0.06), Color("ffd98a"), Vector3.ZERO, true)


## A wall tower of the outer wall: a stone foot, a white storey and two roofs.
static func _town_tower(b: JapanKit.Batch, at: Vector3, s: float) -> void:
	b.box(at + Vector3(0, 4.0, 0), Vector3(s, 8.0, s), STONE_CORE)
	b.box(at + Vector3(0, 9.6, 0), Vector3(s - 0.6, 3.2, s - 0.6), PLASTER)
	b.roof(at + Vector3(0, 11.9, 0), s + 2.6, s + 2.6, 1.6, TILE, 0.3)
	b.box(at + Vector3(0, 13.6, 0), Vector3(s - 2.4, 2.4, s - 2.4), PLASTER)
	b.roof(at + Vector3(0, 15.5, 0), s + 0.4, s + 0.4, 1.5, TILE, 0.3)
	b.box(at + Vector3(0, 16.4, 0), Vector3(1.6, 0.4, 0.4), GOLD)


## The castle town on the terraces either side of the castle and behind it: rows of roofed
## houses with lit windows, pagodas, shrine gates, the outer wall with its towers. All of it
## stands beyond the castle's own walls (nobody walks there); one mesh, no shadows.
static func _kingdom(root: Node3D, art: RandomNumberGenerator) -> void:
	var b := JapanKit.Batch.new()
	var roofs: Array[Color] = [TILE, TILE.lightened(0.08), JapanKit.TILE, Color("4a5c57"), Color("5a4a44"), TILE]
	# The terraces: each a stone-faced step up towards the keep, a white wall along its rim.
	# [x0, x1 (west side; mirrored east), z south, z north, height].
	var terraces: Array = [
		[60.0, 178.0, -30.0, -84.0, 3.5],
		[60.0, 178.0, -84.0, -140.0, 8.0],
		[46.0, 178.0, -140.0, -182.0, 8.0],
		[20.0, 178.0, -182.0, -236.0, 13.0],
	]
	for t in terraces:
		var x0: float = t[0]
		var x1: float = t[1]
		var zs: float = t[2]
		var zn: float = t[3]
		var h: float = t[4]
		for e in [-1.0, 1.0]:
			var cx: float = float(e) * (x0 + x1) * 0.5
			b.box(Vector3(cx, h * 0.5, (zs + zn) * 0.5), Vector3(x1 - x0, h, zs - zn), STONE.darkened(0.06))
			b.box(Vector3(cx, h + 0.02, (zs + zn) * 0.5), Vector3(x1 - x0 - 0.4, 0.06, zs - zn - 0.4), Color("b7ad94"))
			b.box(Vector3(cx, h + 0.7, zs - 0.5), Vector3(x1 - x0, 1.4, 0.7), PLASTER)
			b.box(Vector3(cx, h + 1.5, zs - 0.5), Vector3(x1 - x0 + 0.3, 0.3, 1.3), TILE)
			# Two or three rows of houses along the terrace.
			var rows := int((zs - zn - 10.0) / 15.0)
			for r in maxi(rows, 1):
				var z := zs - 9.0 - float(r) * 15.0
				var x := x0 + 6.0 + art.randf_range(0.0, 4.0)
				while x < x1 - 6.0:
					var w := art.randf_range(6.0, 9.5)
					var d := art.randf_range(5.5, 7.5)
					var tall := art.randf_range(3.0, 4.2) * (1.5 if art.randf() < 0.18 else 1.0)
					_town_house(b, Vector3(float(e) * (x + w * 0.5), h, z + art.randf_range(-1.2, 1.2)), w, d, tall, roofs[art.randi() % roofs.size()], art.randf() < 0.45)
					x += w + art.randf_range(3.0, 6.5)
	# The middle of the north terrace behind the great keep.
	b.box(Vector3(0, 6.5, -209.0), Vector3(40.0, 13.0, 54.0), STONE.darkened(0.06))
	# Pagodas over the roofs: two on the second terraces, two great ones on the north terrace.
	for e in [-1.0, 1.0]:
		b.xform = Transform3D(Basis.from_scale(Vector3.ONE * 2.0), Vector3(float(e) * 104.0, 8.0, -112.0))
		JapanKit.pagoda(b, 4)
		b.xform = Transform3D(Basis.from_scale(Vector3.ONE * 2.5), Vector3(float(e) * 78.0, 13.0, -214.0))
		JapanKit.pagoda(b, 5)
		# A shrine gate at the head of each first terrace, and a temple hall on the third.
		b.xform = Transform3D(Basis(), Vector3(float(e) * 140.0, 3.5, -34.0))
		JapanKit.torii(b, 9.0, 8.0)
		b.xform = Transform3D.IDENTITY
		var hall := Vector3(float(e) * 150.0, 8.0, -160.0)
		b.box(hall + Vector3(0, 1.0, 0), Vector3(26.0, 2.0, 18.0), STONE)
		b.box(hall + Vector3(0, 4.6, 0), Vector3(21.0, 5.2, 13.0), PLASTER)
		for k in 5:
			b.cyl(hall + Vector3((float(k) - 2.0) * 5.0, 4.6, 6.7), 0.5, 5.2, JapanKit.VERMILION)
		b.roof(hall + Vector3(0, 9.2, 0), 28.0, 20.0, 4.0, TILE, 0.55)
		b.box(hall + Vector3(0, 11.3, 0), Vector3(16.0, 0.5, 0.8), GOLD_DEEP)
	b.xform = Transform3D.IDENTITY
	# The outer wall round the town: along the north and down both sides, a tower every so far.
	var north := -238.0
	var east := 180.0
	b.box(Vector3(0, 9.0, north), Vector3(east * 2.0, 18.0, 4.0), STONE_CORE)
	b.box(Vector3(0, 19.0, north), Vector3(east * 2.0, 2.0, 1.4), PLASTER)
	b.box(Vector3(0, 20.2, north), Vector3(east * 2.0 + 0.6, 0.5, 2.4), TILE)
	for e in [-1.0, 1.0]:
		b.box(Vector3(float(e) * east, 6.0, (north - 20.0) * 0.5), Vector3(4.0, 12.0, -20.0 - north), STONE_CORE)
		b.box(Vector3(float(e) * east, 13.0, (north - 20.0) * 0.5), Vector3(1.4, 2.0, -20.0 - north), PLASTER)
		b.box(Vector3(float(e) * east, 14.2, (north - 20.0) * 0.5), Vector3(2.4, 0.5, -20.0 - north + 0.6), TILE)
		for z in [-60.0, -110.0, -160.0, -210.0]:
			b.xform = Transform3D(Basis(), Vector3(float(e) * east, 6.0, z))
			_town_tower(b, Vector3.ZERO, 9.0)
		b.xform = Transform3D(Basis(), Vector3(float(e) * east, 12.0, north))
		_town_tower(b, Vector3.ZERO, 11.0)
	for x in [-120.0, -60.0, 0.0, 60.0, 120.0]:
		b.xform = Transform3D(Basis(), Vector3(x, 12.0, north))
		_town_tower(b, Vector3.ZERO, 10.0)
	b.xform = Transform3D.IDENTITY
	_commit(b, root, "Kingdom", false)


## The land round the kingdom: the green hills ringing the field, terraced fields beyond
## the pines, and the great blue mountains with snow on their heads behind the castle.
## One mesh, no shadows.
static func _horizon(root: Node3D, rng: RandomNumberGenerator, art: RandomNumberGenerator) -> void:
	var b := JapanKit.Batch.new()
	# The land out to the mountains' feet (the field's own ground ends at 215 m).
	b.cyl(Vector3(0, -0.6, -60.0), 520.0, 0.4, Color("6d9c5a"), Vector3.ZERO, 24)
	for i in 18:
		var angle := TAU * float(i) / 18.0 + rng.randf() * 0.2
		var dist := rng.randf_range(235.0, 270.0)
		var height := rng.randf_range(26.0, 52.0)
		var width := height * rng.randf_range(1.6, 2.2)
		var tint := Color("5d7f63").lerp(Color("8fa6b8"), rng.randf())
		var at := Vector3(cos(angle) * dist, height * 0.5 - 1.0, sin(angle) * dist)
		# North of the castle the town stands where the hills were: those move out behind it.
		if at.z < -100.0:
			at = Vector3(at.x * 1.25, at.y, at.z - 70.0)
		b.cone(at, width * 0.5, height, tint)
	# The great range behind the castle, in two ranks, snow on the far heads.
	for i in 11:
		var x := (float(i) - 5.0) * 78.0 + art.randf_range(-20.0, 20.0)
		var far := i % 2 == 0
		var height := art.randf_range(150.0, 215.0) if far else art.randf_range(90.0, 130.0)
		var z := (-440.0 if far else -360.0) + art.randf_range(-18.0, 18.0) + absf(x) * 0.12
		var width := height * art.randf_range(1.5, 1.9)
		var rock := Color("4f6a96").lerp(Color("6f88b0"), art.randf()) if far else Color("4c7078").lerp(Color("5c8268"), art.randf())
		b.cone(Vector3(x, height * 0.5 - 2.0, z), width * 0.5, height, rock)
		if far:
			b.cone(Vector3(x, height * 0.86 - 2.0, z), width * 0.5 * 0.3, height * 0.29, Color("f4f7fb"))
	# Terraced fields south of the pines: a patchwork of paddies, some under water.
	var crops: Array[Color] = [Color("9fc56a"), Color("c9cf74"), Color("7fb37a"), Color("8fc2c9"), Color("b5c98a")]
	for e in [-1.0, 1.0]:
		for r in 3:
			for k in 5:
				var x := float(e) * (70.0 + float(k) * 27.0)
				var z := 150.0 + float(r) * 21.0 - float(k) * 14.0
				b.box(Vector3(x, 0.09, z), Vector3(24.0, 0.1, 18.0), crops[art.randi() % crops.size()], Vector3(0, float(e) * 14.0, 0))
	_commit(b, root, "Horizon", false)
