class_name GuildHall
extends RefCounted
## The guild hall's room (GuildHallData): one long timber hall built from code, the same
## layout for every guild, dressed in the guild's colour (the carpet, the banners along the
## columns, the roof beams and the crest on the far wall). Everything static is one
## JapanKit batch (three draws: solid, glow and cloth) plus a shadowless ceiling, so the
## room costs a phone less than a street of the village; what moves (the guild mates,
## the dummy, the villager-like props) comes on top.
## Layout (x across, z deep, the entrance at +z, the crest at -z):
##   the dais and crest on the north wall, the steward before it; the trophy wall on the
##   west wall and the roster board on the east; the rest area (tatami, cushions, a
##   brazier) in the south-west, the training ring in the south-east; the notice board,
##   the warp stone and the way out by the entrance.

const HALF_W := 18.0
const HALF_D := 24.0
const WALL_H := 7.0
## The hero may walk the whole room (Hero.field_hall) and no farther than this circle.
const RADIUS := 31.0
const START := Vector3(0, 0, 17.0)
const EXIT := Vector3(0, 0, 21.6)
const WARP := Vector3(-7.0, 0, 19.0)
const NOTICE := Vector3(7.5, 0, 17.0)
const STEWARD := Vector3(-4.2, 0, -16.5)
const DAIS := Vector3(0, 0, -21.4)
const REST := Vector3(-11.5, 0, 12.0)
const DUMMY := Vector3(11.5, 0, 10.0)
const TROPHY_X := -HALF_W + 0.35
const BOARD_X := HALF_W - 0.35
## The stroll spots of the guild mates (HallMate): around the room, off the hero's way in.
const SPOTS: Array[Vector3] = [
	Vector3(-6.0, 0, -12.0), Vector3(6.0, 0, -12.0), Vector3(-13.0, 0, -6.0), Vector3(13.0, 0, -6.0),
	Vector3(-6.5, 0, 1.0), Vector3(6.5, 0, 1.0), Vector3(-13.0, 0, 4.0), Vector3(13.0, 0, 2.0),
	Vector3(-9.0, 0, 13.5), Vector3(-14.0, 0, 15.5), Vector3(8.5, 0, 6.0), Vector3(-2.0, 0, 8.0),
	Vector3(2.5, 0, -5.0), Vector3(-10.0, 0, -17.0), Vector3(9.5, 0, -17.0), Vector3(14.0, 0, 16.0),
]
const WALL := Color("f1e8d6")
const FLOOR := Color("b48a5c")
const FLOOR_DARK := Color("8f6a44")


static func rect() -> Rect2:
	return Rect2(-HALF_W + 0.9, -HALF_D + 0.9, (HALF_W - 0.9) * 2.0, (HALF_D - 0.9) * 2.0)


## Builds the room into `zone` for guild g (paced by `tree` when staged). The castle
## king's hall also gets the castle banners and the golden throne on its dais.
static func build(zone: Node3D, g: int, tree: SceneTree = null) -> void:
	var color: Color = WorldPlayers.GUILD_COLORS.get(g, Color.WHITE)
	var root := Node3D.new()
	root.name = "GuildHall"
	zone.add_child(root)
	var t := WorldPresence.clock()
	var crowned := GuildLeague.champion_now(t) == g
	var b := JapanKit.Batch.new()
	_room(b, color)
	await FrameSlicer.pace(tree)
	_columns(b, color)
	_crest(b, g, color)
	_trophies(b, g, t)
	_board(b)
	_rest(b)
	_ring(b)
	if crowned:
		_castle_banners(b)
		_throne(b)
	await FrameSlicer.pace(tree)
	b.commit(root, "Hall")
	var ceiling := JapanKit.Batch.new()
	_ceiling(ceiling, color)
	var mi := ceiling.commit(root, "Ceiling", false)
	mi.visibility_range_end = 0.0
	_colliders(root)
	_labels(root, g, color, t, crowned)
	await FrameSlicer.pace(tree)


# --- The room ------------------------------------------------------------------------------

static func _room(b: JapanKit.Batch, color: Color) -> void:
	var w := HALF_W * 2.0 + 0.8
	var d := HALF_D * 2.0 + 0.8
	# Floor boards, a darker border and the guild's carpet down the middle to the dais.
	b.box(Vector3(0, -0.2, 0), Vector3(w, 0.4, d), FLOOR)
	b.box(Vector3(0, 0.005, 0), Vector3(w - 3.0, 0.01, d - 3.0), FLOOR_DARK)
	b.box(Vector3(0, 0.02, 0), Vector3(w - 3.6, 0.01, d - 3.6), FLOOR)
	b.box(Vector3(0, 0.035, -1.5), Vector3(5.2, 0.03, HALF_D * 2.0 - 5.0), color.darkened(0.25))
	b.box(Vector3(0, 0.05, -1.5), Vector3(4.4, 0.03, HALF_D * 2.0 - 5.8), color.darkened(0.45))
	# Plaster walls on a wood dado, posts every six metres, a frieze in the guild colour.
	var walls := [
		[Vector3(0, WALL_H * 0.5, -HALF_D), Vector3(w, WALL_H, 0.6)],
		[Vector3(-HALF_W, WALL_H * 0.5, 0), Vector3(0.6, WALL_H, d)],
		[Vector3(HALF_W, WALL_H * 0.5, 0), Vector3(0.6, WALL_H, d)],
		[Vector3(-(HALF_W + 3.4) * 0.5, WALL_H * 0.5, HALF_D), Vector3(HALF_W - 3.4 + 0.4, WALL_H, 0.6)],
		[Vector3((HALF_W + 3.4) * 0.5, WALL_H * 0.5, HALF_D), Vector3(HALF_W - 3.4 + 0.4, WALL_H, 0.6)],
		# The lintel over the doorway.
		[Vector3(0, WALL_H - 1.0, HALF_D), Vector3(7.2, 2.0, 0.6)],
	]
	for spec in walls:
		var pos: Vector3 = spec[0]
		var size: Vector3 = spec[1]
		b.box(pos, size, WALL)
		var inward := Vector3(0, 0, 0.36) if pos.z < -1.0 else (Vector3(0, 0, -0.36) if pos.z > 1.0 else (Vector3(0.36, 0, 0) if pos.x < 0.0 else Vector3(-0.36, 0, 0)))
		if size.y > 3.0:
			b.box(Vector3(pos.x, 0.55, pos.z) + inward, Vector3(size.x if size.z < 1.0 else 0.12, 1.1, size.z if size.x < 1.0 else 0.12), JapanKit.WOOD_DARK)
			b.box(Vector3(pos.x, WALL_H - 0.5, pos.z) + inward, Vector3(size.x if size.z < 1.0 else 0.1, 0.5, size.z if size.x < 1.0 else 0.1), color.darkened(0.2))
	for z in [-18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0]:
		for x in [-1.0, 1.0]:
			b.box(Vector3(x * (HALF_W - 0.5), WALL_H * 0.5, z), Vector3(0.4, WALL_H, 0.4), JapanKit.WOOD_DARK)
	for x in [-12.0, -6.0, 6.0, 12.0]:
		for z in [-1.0, 1.0]:
			b.box(Vector3(x, WALL_H * 0.5, z * (HALF_D - 0.5)), Vector3(0.4, WALL_H, 0.4), JapanKit.WOOD_DARK)
	# Door posts and a gold plaque frame over the way out.
	for x in [-3.6, 3.6]:
		b.box(Vector3(x, 2.6, HALF_D - 0.3), Vector3(0.5, 5.2, 0.5), JapanKit.WOOD_DARK)
	b.box(Vector3(0, 5.5, HALF_D - 0.42), Vector3(4.0, 0.9, 0.08), JapanKit.WOOD_DARK)
	# Shoji windows high on the long walls, lit from outside.
	for z in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
		for x in [-1.0, 1.0]:
			b.box(Vector3(x * (HALF_W - 0.35), 5.2, z), Vector3(0.08, 1.6, 2.4), JapanKit.SHOJI, Vector3.ZERO, true)
			b.box(Vector3(x * (HALF_W - 0.33), 5.2, z), Vector3(0.06, 1.7, 0.08), JapanKit.WOOD_DARK)
			b.box(Vector3(x * (HALF_W - 0.33), 5.2, z), Vector3(0.06, 0.08, 2.5), JapanKit.WOOD_DARK)
	# The dais under the crest.
	b.box(DAIS + Vector3(0, 0.25, 0), Vector3(11.0, 0.5, 4.4), JapanKit.STONE)
	b.box(DAIS + Vector3(0, 0.52, 0), Vector3(10.4, 0.06, 3.8), color.darkened(0.3))
	b.box(DAIS + Vector3(0, 0.15, 2.5), Vector3(5.0, 0.3, 0.8), JapanKit.STONE_DARK)


static func _ceiling(b: JapanKit.Batch, color: Color) -> void:
	b.box(Vector3(0, WALL_H + 0.45, 0), Vector3(HALF_W * 2.0 + 0.8, 0.3, HALF_D * 2.0 + 0.8), JapanKit.TILE_DARK)
	for z in [-18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0]:
		b.box(Vector3(0, WALL_H + 0.1, z), Vector3(HALF_W * 2.0, 0.5, 0.45), color.darkened(0.55))
	for x in [-9.0, 0.0, 9.0]:
		b.box(Vector3(x, WALL_H - 0.1, 0), Vector3(0.4, 0.4, HALF_D * 2.0), JapanKit.WOOD_DARK)


static func _columns(b: JapanKit.Batch, color: Color) -> void:
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		for x in [-9.0, 9.0]:
			b.cyl(Vector3(x, 0.2, z), 0.7, 0.4, JapanKit.STONE_DARK, Vector3.ZERO, 8)
			b.cyl(Vector3(x, WALL_H * 0.5, z), 0.42, WALL_H, JapanKit.WOOD, Vector3.ZERO, 8)
			b.cyl(Vector3(x, WALL_H - 0.3, z), 0.6, 0.3, JapanKit.WOOD_DARK, Vector3.ZERO, 8)
			# The guild banner on the aisle side of each column, a lantern above it.
			var side := -signf(x)
			JapanKit.banner(b, Vector3(x + side * 0.9, 0, z + 0.9), color)
			JapanKit.chochin(b, Vector3(x + side * 0.9, 5.0, z), Color("f6d58a"), 1.1)
			b.light(Vector3(x + side * 0.9, 5.0, z), Color("f6d58a"))


## The guild's crest on the north wall: a gold-rimmed disc in the guild colour with the
## guild's own emblem.
static func _crest(b: JapanKit.Batch, g: int, color: Color) -> void:
	var at := Vector3(0, 4.4, -HALF_D + 0.3)
	b.cyl(at, 2.4, 0.12, JapanKit.GOLD, Vector3(90, 0, 0), 24)
	b.cyl(at + Vector3(0, 0, 0.08), 2.05, 0.1, color, Vector3(90, 0, 0), 24)
	b.cyl(at + Vector3(0, 0, 0.14), 1.75, 0.06, color.darkened(0.35), Vector3(90, 0, 0), 24)
	var ink := Color("fff6e0")
	var z := at.z + 0.24
	match g:
		WorldPlayers.ALPHA:
			# An "A": two slanted bars and a crossbar.
			b.box(Vector3(-0.55, 4.3, z), Vector3(0.3, 2.4, 0.08), ink, Vector3(0, 0, -20.0))
			b.box(Vector3(0.55, 4.3, z), Vector3(0.3, 2.4, 0.08), ink, Vector3(0, 0, 20.0))
			b.box(Vector3(0, 3.95, z), Vector3(1.3, 0.26, 0.08), ink)
		WorldPlayers.NEVERDIE:
			# Crossed swords over a heart that will not die.
			b.box(Vector3(0, 4.4, z), Vector3(0.22, 2.6, 0.08), ink, Vector3(0, 0, 45.0))
			b.box(Vector3(0, 4.4, z), Vector3(0.22, 2.6, 0.08), ink, Vector3(0, 0, -45.0))
			b.ball(Vector3(-0.32, 4.72, z), Vector3(0.62, 0.62, 0.14), Color("ff6f8e").lightened(0.2))
			b.ball(Vector3(0.32, 4.72, z), Vector3(0.62, 0.62, 0.14), Color("ff6f8e").lightened(0.2))
			b.box(Vector3(0, 4.25, z), Vector3(0.78, 0.78, 0.12), Color("ff6f8e").lightened(0.2), Vector3(0, 0, 45.0))
		WorldPlayers.TITAN:
			# A mountain under a hammer's head.
			b.cone(Vector3(0, 4.05, z), 1.25, 1.7, ink)
			b.box(Vector3(0, 5.25, z), Vector3(1.5, 0.5, 0.1), JapanKit.GOLD)
			b.box(Vector3(0, 4.7, z), Vector3(0.24, 0.8, 0.1), JapanKit.WOOD_DARK)
		_:
			# 3DLnw: three stacked cubes.
			b.box(Vector3(-0.55, 3.75, z), Vector3(0.85, 0.85, 0.12), ink, Vector3(0, 0, 10.0))
			b.box(Vector3(0.55, 3.75, z), Vector3(0.85, 0.85, 0.12), ink, Vector3(0, 0, -10.0))
			b.box(Vector3(0, 4.75, z), Vector3(0.85, 0.85, 0.12), JapanKit.GOLD, Vector3(0, 0, 45.0))
	# Ribbons of the guild colour hanging either side of the crest.
	for x in [-3.2, 3.2]:
		var weight := JapanKit.hanging_weight(6.6, 3.2)
		b.cloth(Vector3(x, 5.0, -HALF_D + 0.36), Vector3(0.9, 3.2, 0.03), color, weight)
		b.box(Vector3(x, 6.65, -HALF_D + 0.36), Vector3(1.0, 0.06, 0.06), JapanKit.WOOD_DARK)


## The trophy wall: three shelves (League Champion, Castle King, Emperor), a gold cup for
## every week the guild held the title (the latest twelve on view).
static func _trophies(b: JapanKit.Batch, g: int, t: float) -> void:
	var tr := GuildHallData.trophies(g, t)
	var x := TROPHY_X
	b.box(Vector3(x + 0.1, 3.3, -8.0), Vector3(0.1, 5.4, 13.0), JapanKit.WOOD_DARK)
	var shelves := [["emperor", 4.9, JapanKit.GOLD], ["castle", 3.6, Color("e8c050")], ["league", 2.3, Color("d8d8e8")]]
	for k in shelves.size():
		var spec: Array = shelves[k]
		var y: float = spec[1]
		b.box(Vector3(x + 0.35, y, -8.0), Vector3(0.7, 0.08, 12.0), JapanKit.WOOD_LIGHT)
		b.box(Vector3(x + 0.35, y - 0.25, -8.0), Vector3(0.1, 0.4, 12.0), JapanKit.WOOD)
		var weeks: Array = tr[spec[0]]
		var shown := mini(weeks.size(), 12)
		for i in shown:
			var z := -13.5 + 11.0 * (float(i) + 0.5) / float(maxi(shown, 6))
			var metal: Color = spec[2]
			b.cyl(Vector3(x + 0.35, y + 0.1, z), 0.2, 0.12, metal, Vector3.ZERO, 8)
			b.cyl(Vector3(x + 0.35, y + 0.3, z), 0.06, 0.3, metal, Vector3.ZERO, 6)
			b.ball(Vector3(x + 0.35, y + 0.6, z), Vector3(0.4, 0.42, 0.4), metal)
			if spec[0] == "emperor":
				b.cone(Vector3(x + 0.35, y + 0.92, z), 0.16, 0.24, metal)
	# Lanterns at both ends of the wall.
	for z in [-14.5, -1.5]:
		JapanKit.chochin(b, Vector3(x + 0.6, 5.8, z), Color("ffd8a0"), 0.9)
		b.light(Vector3(x + 0.6, 5.8, z), Color("ffd8a0"))


## The roster board on the east wall (its text is a label: _labels).
static func _board(b: JapanKit.Batch) -> void:
	var x := BOARD_X
	b.box(Vector3(x - 0.15, 3.4, -8.0), Vector3(0.2, 5.6, 13.0), JapanKit.WOOD_DARK)
	b.box(Vector3(x - 0.28, 3.4, -8.0), Vector3(0.06, 5.0, 12.2), Color("3a3028"))
	b.box(Vector3(x - 0.32, 5.75, -8.0), Vector3(0.06, 0.3, 12.4), JapanKit.GOLD)
	for z in [-14.5, -1.5]:
		JapanKit.chochin(b, Vector3(x - 0.6, 5.8, z), Color("ffd8a0"), 0.9)
		b.light(Vector3(x - 0.6, 5.8, z), Color("ffd8a0"))


## The rest area: tatami, cushions round a low table, a brazier and a tea set.
static func _rest(b: JapanKit.Batch) -> void:
	var c := REST
	b.box(c + Vector3(0, 0.06, 0), Vector3(7.5, 0.12, 6.5), Color("b9ad74"))
	for k in 3:
		b.box(c + Vector3(-2.5 + k * 2.5, 0.125, 0), Vector3(0.05, 0.02, 6.5), Color("5a5236"))
	b.box(c + Vector3(0, 0.45, 0), Vector3(2.4, 0.12, 1.4), JapanKit.WOOD_DARK)
	for x in [-0.9, 0.9]:
		b.box(c + Vector3(x, 0.2, 0), Vector3(0.14, 0.4, 1.2), JapanKit.WOOD_DARK)
	var cushions := [Vector3(-1.7, 0, -0.1), Vector3(1.7, 0, 0.1), Vector3(0, 0, 1.4), Vector3(0, 0, -1.4), Vector3(-2.6, 0, 2.2), Vector3(2.6, 0, -2.3)]
	for k in cushions.size():
		b.ball(c + cushions[k] + Vector3(0, 0.14, 0), Vector3(0.9, 0.3, 0.9), [Color("c84a4a"), Color("4a6ac8"), Color("e0b040")][k % 3])
	# Tea on the table.
	b.cyl(c + Vector3(-0.3, 0.6, 0.1), 0.18, 0.2, Color("4a3a30"), Vector3.ZERO, 8)
	for k in 3:
		b.cyl(c + Vector3(0.3 + k * 0.3, 0.56, -0.3 + k * 0.25), 0.07, 0.1, Color("e8e0d0"), Vector3.ZERO, 6)
	# A brazier with glowing coals.
	b.cyl(c + Vector3(2.9, 0.3, 2.3), 0.55, 0.6, Color("3a3a40"), Vector3.ZERO, 10)
	b.ball(c + Vector3(2.9, 0.62, 2.3), Vector3(0.8, 0.22, 0.8), Color("ff7a30"), true)
	b.light(c + Vector3(2.9, 0.9, 2.3), Color("ff9a50"))
	# A folding screen behind the mats.
	for k in 3:
		b.box(c + Vector3(-3.2 + k * 1.1, 1.0, -3.3 + (k % 2) * 0.25), Vector3(1.1, 2.0, 0.06), Color("f6eedc"), Vector3(0, (k - 1) * 18.0, 0))
		b.box(c + Vector3(-3.2 + k * 1.1, 1.0, -3.3 + (k % 2) * 0.25), Vector3(1.14, 2.04, 0.04), JapanKit.WOOD_DARK, Vector3(0, (k - 1) * 18.0, 0))


## The training ring: a clay circle for the dummy, a weapon rack at its side.
static func _ring(b: JapanKit.Batch) -> void:
	var c := DUMMY
	b.cyl(c + Vector3(0, 0.1, 0), 3.4, 0.2, Color("c8a878"), Vector3.ZERO, 20)
	b.cyl(c + Vector3(0, 0.21, 0), 3.1, 0.04, Color("d8bc8c"), Vector3.ZERO, 20)
	for i in 14:
		var a := TAU * i / 14.0
		b.box(c + Vector3(cos(a) * 3.2, 0.25, sin(a) * 3.2), Vector3(0.9, 0.12, 0.2), Color("d8c88a"), Vector3(0, -rad_to_deg(a) + 90.0, 0))
	# The rack by the wall.
	var r := Vector3(HALF_W - 1.0, 0, 15.0)
	b.box(r + Vector3(0, 0.9, 0), Vector3(0.3, 1.8, 2.6), JapanKit.WOOD)
	for k in 4:
		var zk := -0.9 + k * 0.6
		b.box(r + Vector3(-0.3, 1.0, zk), Vector3(0.08, 1.6, 0.08), JapanKit.WOOD_DARK, Vector3(0, 0, 8.0))
		b.box(r + Vector3(-0.3, 1.75, zk), Vector3(0.1, 0.4, 0.25), Color("c8ccd8"), Vector3(0, 0, 8.0))


## The castle king's hall: two castle banners flank the crest.
static func _castle_banners(b: JapanKit.Batch) -> void:
	for x in [-7.0, 7.0]:
		var weight := JapanKit.hanging_weight(6.7, 4.2)
		b.cloth(Vector3(x, 4.6, -HALF_D + 0.38), Vector3(2.0, 4.2, 0.03), GuildLeague.CROWN_COLOR.darkened(0.15), weight)
		b.box(Vector3(x, 6.75, -HALF_D + 0.38), Vector3(2.2, 0.08, 0.08), JapanKit.WOOD_DARK)
		# A castle in gold on the banner: a wall with battlements and a keep.
		var z := -HALF_D + 0.42
		b.box(Vector3(x, 4.0, z), Vector3(1.3, 0.6, 0.02), JapanKit.GOLD)
		for k in 3:
			b.box(Vector3(x - 0.45 + k * 0.45, 4.42, z), Vector3(0.25, 0.25, 0.02), JapanKit.GOLD)
		b.box(Vector3(x, 4.95, z), Vector3(0.5, 0.9, 0.02), JapanKit.GOLD)
		b.cone(Vector3(x, 5.6, z), 0.32, 0.4, JapanKit.GOLD)
		b.box(Vector3(x, 3.2, z), Vector3(1.4, 0.06, 0.02), Color("fff6e0"))


## The golden throne on the dais.
static func _throne(b: JapanKit.Batch) -> void:
	var c := DAIS + Vector3(0, 0.55, -0.6)
	b.box(c + Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 1.3), JapanKit.GOLD)
	b.box(c + Vector3(0, 0.66, 0.05), Vector3(1.3, 0.14, 1.0), Color("b02838"))
	b.box(c + Vector3(0, 1.6, -0.6), Vector3(1.6, 2.0, 0.22), JapanKit.GOLD)
	b.box(c + Vector3(0, 1.5, -0.46), Vector3(1.1, 1.4, 0.06), Color("b02838"))
	for x in [-0.8, 0.8]:
		b.box(c + Vector3(x, 0.95, 0.1), Vector3(0.18, 0.7, 1.1), JapanKit.GOLD)
		b.ball(c + Vector3(x, 1.35, 0.6), Vector3(0.26, 0.26, 0.26), JapanKit.GOLD)
		b.ball(c + Vector3(x, 2.75, -0.6), Vector3(0.3, 0.3, 0.3), JapanKit.GOLD)
	b.cone(c + Vector3(0, 2.95, -0.6), 0.3, 0.6, JapanKit.GOLD)
	b.ball(c + Vector3(0, 3.3, -0.6), Vector3(0.22, 0.22, 0.22), Color("ff6f8e"), true)


## Walls the body and the camera meet; the floor the hero stands on. No ceiling collider
## (the camera's arm would hit it).
static func _colliders(root: Node3D) -> void:
	var w := HALF_W * 2.0 + 2.0
	var d := HALF_D * 2.0 + 2.0
	JapanKit.collider(root, Vector3(0, -0.5, 0), Vector3(w + 4.0, 1.0, d + 4.0))
	JapanKit.collider(root, Vector3(0, WALL_H * 0.5, -HALF_D), Vector3(w, WALL_H, 0.8))
	JapanKit.collider(root, Vector3(-HALF_W, WALL_H * 0.5, 0), Vector3(0.8, WALL_H, d))
	JapanKit.collider(root, Vector3(HALF_W, WALL_H * 0.5, 0), Vector3(0.8, WALL_H, d))
	for s in [-1.0, 1.0]:
		JapanKit.collider(root, Vector3(s * (HALF_W + 3.4) * 0.5, WALL_H * 0.5, HALF_D), Vector3(HALF_W - 3.4 + 0.4, WALL_H, 0.8))
	# The doorway's back: the way out is the portal before it.
	JapanKit.collider(root, Vector3(0, WALL_H * 0.5, HALF_D + 1.2), Vector3(8.0, WALL_H, 0.8))
	JapanKit.collider(root, DAIS + Vector3(0, 0.25, -0.4), Vector3(11.0, 0.5, 3.6))
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		for x in [-9.0, 9.0]:
			JapanKit.collider(root, Vector3(x, WALL_H * 0.5, z), Vector3(1.0, WALL_H, 1.0))
	JapanKit.collider(root, Vector3(HALF_W - 1.0, 0.9, 15.0), Vector3(0.8, 1.8, 2.6))


## The lettering: the guild's name under the crest, the trophy wall's record, the roster
## board's twenty names, the rest area's and ring's signs.
static func _labels(root: Node3D, g: int, color: Color, t: float, crowned: bool) -> void:
	var name := WorldPlayers.guild_name(g)
	_label(root, "กิลด์ %s" % name, Vector3(0, 1.95, -HALF_D + 0.5), 0.0, 72, color.lightened(0.2), 48.0)
	if crowned:
		_label(root, "%s %s สัปดาห์นี้" % [GuildLeague.CROWN, GuildLeague.CASTLE_TITLE], Vector3(0, 1.3, -HALF_D + 0.5), 0.0, 40, GuildLeague.CROWN_COLOR, 36.0)
	# The trophy wall reads from the room (facing +x).
	_label(root, "ผนังเกียรติยศ กิลด์ %s" % name, Vector3(TROPHY_X + 0.75, 5.75, -8.0), PI * 0.5, 44, JapanKit.GOLD, 30.0)
	var lines := GuildHallData.trophy_lines(g, t)
	var wall := _label(root, "\n".join(lines), Vector3(TROPHY_X + 0.75, 1.3, -8.0), PI * 0.5, 30, Color("fff2c0"), 22.0)
	wall.name = "TrophyText"
	wall.width = 1900.0
	wall.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The roster board reads from the room (facing -x).
	_label(root, "ตัวจริงสงครามกิลด์ · %d คนที่แกร่งที่สุด" % GuildWarData.GUILD_SIDE, Vector3(BOARD_X - 0.75, 5.75, -8.0), -PI * 0.5, 40, JapanKit.GOLD, 30.0)
	var rows := GuildHallData.roster(g, t)
	# Two columns of ten (an Array of Strings each: a PackedStringArray in an Array is copied on read).
	var cols: Array = [[], []]
	for k in rows.size():
		var r: Dictionary = rows[k]
		(cols[mini(k / 10, 1)] as Array).append("%2d. %s%s  %s  พลัง %s" % [k + 1, "★ " if bool(r.hero) else "", String(r.name), String(r.tag), GuildHallData.power_text(float(r.power))])
	if rows.is_empty():
		(cols[0] as Array).append("ยังไม่มีสมาชิกถึงเลเวล %d" % Game.GUILD_LEVEL)
	for k in 2:
		var text := "\n".join(PackedStringArray(cols[k]))
		if text == "":
			continue
		var board := _label(root, text, Vector3(BOARD_X - 0.75, 3.4, -8.0 + (3.0 if k == 0 else -3.0)), -PI * 0.5, 26, Color("fff2c0"), 22.0)
		board.name = "RosterText%d" % k
		board.width = 1150.0
		board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(root, "ลานพักกิลด์ · นั่งพักรับ%s" % GuildHallData.BUFF_NAME, REST + Vector3(0, 2.9, -3.6), 0.0, 34, Color("c8f0c8"), 24.0)
	_label(root, "ลานฝึกซ้อม · ตีหุ่นวัดดาเมจ", DUMMY + Vector3(0, 3.4, -3.4), 0.0, 34, Color("ffd8a0"), 24.0)


## A flat sign, readable from one side: `yaw` turns its face (0 faces +z).
static func _label(root: Node3D, text: String, pos: Vector3, yaw: float, size: int, color: Color, seen_from: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0075
	label.outline_size = 6
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	label.position = pos
	label.rotation.y = yaw
	label.visibility_range_end = seen_from
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(label)
	return label


## The roster board and trophy wall drawn again (the hero's own rank changes, a trophy came).
static func refresh_text(zone: Node3D, g: int) -> void:
	var root := zone.get_node_or_null("GuildHall")
	if root == null:
		return
	var t := WorldPresence.clock()
	var wall := root.get_node_or_null("TrophyText") as Label3D
	if wall != null:
		wall.text = "\n".join(GuildHallData.trophy_lines(g, t))
