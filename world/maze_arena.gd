class_name MazeArena
extends RefCounted
## The look of เขาวงกตหนึ่งในใต้หล้า (MazeLayout's maze): an ancient overgrown stone maze
## at dusk. Each quadrant has its own stone, moss and lantern glow (MazeLayout.QUADRANTS)
## and a landmark in its plaza (the moss guardian, the red obelisk, the frost spire, the
## golden sun disk), the throne plaza in the middle holds the crown monument; arches mark
## every plaza's gates, stone lanterns and glowing runes light the corridors, the ten
## shrines (ที่หลบภัย) glow in a ring of pillars round their circle.
## Phones first: every piece is merged into one mesh per chunk of the maze (CHUNKS x CHUNKS,
## culled by distance and by the camera like any mesh), the glow is an unshaded surface (no
## lights), the walls' colliders are one body per quadrant.

## The maze is drawn in CHUNKS x CHUNKS pieces.
const CHUNKS := 4
const CAP_COLOR := Color("cfc6b2")
const POST_COLOR := Color("7d776c")
const RUNE_COLOR := Color("9fe8ff")
const SAFE_COLOR := Color("8ff7ff")
const SAFE_GOLD := Color("ffe9a0")
const CROWN_GOLD := Color("f2c84b")
## A lantern every this many metres of wall, on the wall's top.
const LANTERN_EVERY := 15.0
## The walls are drawn in panels of about this length (each its own tone and height).
const PANEL := 3.0
const NAME_META := "maze_built"


static func build(zone: Node3D) -> void:
	MazeLayout.ensure()
	Scenery.environment(zone, Color("3a3f78"), Color("7b8bb0"), Color(0.75, 0.8, 1.0), Color(1.0, 0.86, 0.7))
	Scenery.ground(zone, MazeLayout.HALF + 40.0, Color("4f6b45"), Color("5d7a4c"), 77, Color("6f6a58"), [], 3.0, [], &"meadow")
	var root := Node3D.new()
	root.name = "Maze"
	zone.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = MazeLayout.SEED + 7
	var batches: Array[JapanKit.Batch] = []
	for k in CHUNKS * CHUNKS:
		batches.append(JapanKit.Batch.new())
	_floors(batches, rng)
	_walls(batches, rng)
	_plazas(batches, rng)
	_shrines(batches, root)
	_runes(batches, rng)
	for k in batches.size():
		if batches[k].is_empty():
			continue
		var mi := batches[k].commit(root, "MazeChunk%d" % k, false)
		mi.visibility_range_end = 130.0 * GameSettings.view_scale()
	_colliders(root)
	_signs(root)
	root.set_meta(NAME_META, true)


## The batch of the chunk point p lies in.
static func _chunk(batches: Array[JapanKit.Batch], p: Vector3) -> JapanKit.Batch:
	var size := MazeLayout.HALF * 2.0 / float(CHUNKS)
	var x := clampi(int(floor((p.x + MazeLayout.HALF) / size)), 0, CHUNKS - 1)
	var z := clampi(int(floor((p.z + MazeLayout.HALF) / size)), 0, CHUNKS - 1)
	return batches[z * CHUNKS + x]


static func _look(p: Vector3) -> Dictionary:
	return MazeLayout.QUADRANTS[MazeLayout.quadrant(p)]


# --- The floor ----------------------------------------------------------------------

## Flagstones: four to a cell, each its own tone of the quadrant's floor; the plazas
## paler and laid in rings.
static func _floors(batches: Array[JapanKit.Batch], rng: RandomNumberGenerator) -> void:
	var tile := MazeLayout.CELL * 0.5
	for c in MazeLayout.cell_count():
		var at := MazeLayout.center(c)
		var look := _look(at)
		var base: Color = look.floor
		var plaza := MazeLayout.plaza_of[c]
		if plaza >= 0:
			base = base.lightened(0.18 if plaza > 0 else 0.26)
		var b := _chunk(batches, at)
		for q in 4:
			var off := Vector3((-0.5 if q % 2 == 0 else 0.5) * tile, 0.0, (-0.5 if q < 2 else 0.5) * tile)
			var tone := base.darkened(rng.randf() * 0.12).lerp(Color("8a8f7a"), rng.randf() * 0.1)
			b.box(at + off + Vector3(0, 0.03, 0), Vector3(tile - 0.18, 0.06, tile - 0.18), tone)


# --- The walls ----------------------------------------------------------------------

## Every wall run in panels (each its own tone and a little height of its own), a capstone
## course on top, moss over the top and down the faces, posts at the ends, and a stone
## lantern every LANTERN_EVERY metres.
static func _walls(batches: Array[JapanKit.Batch], rng: RandomNumberGenerator) -> void:
	var posts := {}
	var since := 0.0
	for s in MazeLayout.segments():
		var a: Vector3 = s[0]
		var e: Vector3 = s[1]
		var look: Dictionary = MazeLayout.QUADRANTS[int(s[2])]
		var length := a.distance_to(e)
		var dir := (e - a) / maxf(length, 0.001)
		var along_x := absf(dir.x) > 0.5
		var panels := maxi(1, int(round(length / PANEL)))
		var step := length / float(panels)
		for k in panels:
			var mid := a + dir * (step * (float(k) + 0.5))
			var b := _chunk(batches, mid)
			var h := MazeLayout.WALL_H + rng.randf_range(-0.25, 0.15)
			var stone: Color = (look.stone as Color).darkened(rng.randf() * 0.16).lerp(Color("a49f94"), rng.randf() * 0.12)
			var size := Vector3(step + 0.02, h, MazeLayout.WALL_T) if along_x else Vector3(MazeLayout.WALL_T, h, step + 0.02)
			b.box(mid + Vector3(0, h * 0.5, 0), size, stone)
			# The capstone, a little wider, paler.
			var cap := Vector3(step - 0.1, 0.28, MazeLayout.WALL_T + 0.3) if along_x else Vector3(MazeLayout.WALL_T + 0.3, 0.28, step - 0.1)
			b.box(mid + Vector3(0, h + 0.1, 0), cap, CAP_COLOR.lerp(stone, 0.4))
			# Moss and ivy over the top and down a face.
			if rng.randf() < 0.55:
				var moss: Color = (look.moss as Color).darkened(rng.randf() * 0.2)
				b.ball(mid + Vector3(rng.randf_range(-step, step) * 0.35, h + 0.25, 0), Vector3(rng.randf_range(1.2, 2.4), 0.6, MazeLayout.WALL_T + 0.6) if along_x else Vector3(MazeLayout.WALL_T + 0.6, 0.6, rng.randf_range(1.2, 2.4)), moss)
				if rng.randf() < 0.5:
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					var face := Vector3(0, 0, side) if along_x else Vector3(side, 0, 0)
					b.box(mid + face * (MazeLayout.WALL_T * 0.5 + 0.04) + Vector3(0, h * 0.6, 0), Vector3(rng.randf_range(0.6, 1.4), h * 0.7, 0.1) if along_x else Vector3(0.1, h * 0.7, rng.randf_range(0.6, 1.4)), moss.darkened(0.12))
			since += step
			if since >= LANTERN_EVERY:
				since = 0.0
				_lantern(b, mid + Vector3(0, h + 0.24, 0), look.glow)
		for p in [a, e]:
			var key := Vector2i(int(round(p.x * 10.0)), int(round(p.z * 10.0)))
			if posts.has(key):
				continue
			posts[key] = true
			var b := _chunk(batches, p)
			b.box(p + Vector3(0, (MazeLayout.WALL_H + 0.5) * 0.5, 0), Vector3(MazeLayout.WALL_T + 0.4, MazeLayout.WALL_H + 0.5, MazeLayout.WALL_T + 0.4), POST_COLOR.lerp(look.stone, 0.5))
			b.box(p + Vector3(0, MazeLayout.WALL_H + 0.6, 0), Vector3(MazeLayout.WALL_T + 0.7, 0.22, MazeLayout.WALL_T + 0.7), CAP_COLOR)


## A small stone lantern on a wall's top: base, glowing light box and a little roof.
static func _lantern(b: JapanKit.Batch, at: Vector3, glow: Color) -> void:
	b.box(at + Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.5), POST_COLOR)
	b.box(at + Vector3(0, 0.5, 0), Vector3(0.34, 0.42, 0.34), glow, Vector3.ZERO, true)
	b.box(at + Vector3(0, 0.8, 0), Vector3(0.62, 0.14, 0.62), Color("5a5048"))


# --- Plazas and landmarks -----------------------------------------------------------

static func _plazas(batches: Array[JapanKit.Batch], rng: RandomNumberGenerator) -> void:
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var b := _chunk(batches, at)
		var size := float(MazeLayout.PLAZAS[k][2]) * MazeLayout.CELL
		var look := _look(at + Vector3(0.1, 0, 0.1))
		var glow: Color = CROWN_GOLD if k == 0 else look.glow
		# A ring of runes round the plaza's middle.
		for n in 16:
			var ang := TAU * float(n) / 16.0
			var p := at + Vector3(cos(ang), 0, sin(ang)) * (size * 0.36)
			b.box(p + Vector3(0, 0.08, 0), Vector3(0.9, 0.04, 0.24), glow, Vector3(0, -ang, 0), true)
		match k:
			0: _crown_monument(b, at)
			1: _moss_guardian(b, at, look)
			2: _red_obelisk(b, at, look)
			3: _frost_spire(b, at, look)
			4: _sun_disk(b, at, look)
		# The gates of the plaza: an arch over the middle of each side.
		# (MazeLayout.build opens the middle cell of each side: size / 2.)
		var half := size * 0.5
		var mid := int(MazeLayout.PLAZAS[k][2]) / 2
		var gate := -MazeLayout.HALF + MazeLayout.CELL * (float(int(MazeLayout.PLAZAS[k][0]) + mid) + 0.5)
		var gate_z := -MazeLayout.HALF + MazeLayout.CELL * (float(int(MazeLayout.PLAZAS[k][1]) + mid) + 0.5)
		for g in [Vector3(gate, 0, at.z - half), Vector3(gate, 0, at.z + half), Vector3(at.x - half, 0, gate_z), Vector3(at.x + half, 0, gate_z)]:
			if not MazeLayout.inside((g as Vector3) * 0.999):
				continue
			_arch(_chunk(batches, g), g, absf((g as Vector3).z - at.z) > 0.1, look, glow)


## An arch over a plaza's gate: two pillars on the wall line and a lintel well over head.
static func _arch(b: JapanKit.Batch, at: Vector3, along_x: bool, look: Dictionary, glow: Color) -> void:
	var w := MazeLayout.CELL * 0.5
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var stone: Color = (look.stone as Color).lightened(0.08)
	for s in [-1.0, 1.0]:
		var p: Vector3 = at + across * (w * s)
		b.box(p + Vector3(0, 2.9, 0), Vector3(1.3, 5.8, 1.3), stone)
		b.box(p + Vector3(0, 5.9, 0), Vector3(1.6, 0.3, 1.6), CAP_COLOR)
	var lintel := Vector3(w * 2.0 + 1.6, 0.8, 1.2) if along_x else Vector3(1.2, 0.8, w * 2.0 + 1.6)
	b.box(at + Vector3(0, 6.4, 0), lintel, stone.darkened(0.1))
	b.box(at + Vector3(0, 6.95, 0), Vector3(lintel.x * 0.4 if along_x else 1.0, 0.5, 1.0 if along_x else lintel.z * 0.4), glow, Vector3.ZERO, true)
	b.ball(at + Vector3(0, 6.85, 0), Vector3(2.4, 0.7, 2.4), (look.moss as Color).darkened(0.1))


## The throne plaza: stepped dais, the throne, a tall pedestal under a great gold crown,
## four obelisks with glowing tops.
static func _crown_monument(b: JapanKit.Batch, at: Vector3) -> void:
	b.box(at + Vector3(0, 0.1, 0), Vector3(18.0, 0.12, 18.0), Color("b8ae98"))
	b.box(at + Vector3(0, 0.2, 0), Vector3(12.0, 0.12, 12.0), Color("cdc2aa"))
	b.cyl(at + Vector3(0, 1.6, 0), 1.9, 3.0, Color("d8cdb5"), Vector3.ZERO, 12)
	b.cyl(at + Vector3(0, 3.2, 0), 2.3, 0.3, CAP_COLOR, Vector3.ZERO, 12)
	# The crown: a gold band and its points, a jewel on each.
	b.cyl(at + Vector3(0, 4.0, 0), 1.8, 1.0, CROWN_GOLD, Vector3.ZERO, 12)
	for n in 8:
		var ang := TAU * float(n) / 8.0
		var p := at + Vector3(cos(ang) * 1.6, 5.0, sin(ang) * 1.6)
		b.cone(p, 0.42, 1.2, CROWN_GOLD)
		b.ball(p + Vector3(0, 0.75, 0), Vector3(0.32, 0.32, 0.32), Color("ff5a7a") if n % 2 == 0 else Color("7ad8ff"), true)
	b.ball(at + Vector3(0, 4.9, 0), Vector3(1.3, 1.3, 1.3), Color("fff0a0"), true)
	for n in 4:
		var ang := TAU * float(n) / 4.0 + PI * 0.25
		var p := at + Vector3(cos(ang), 0, sin(ang)) * 9.0
		b.box(p + Vector3(0, 2.6, 0), Vector3(1.2, 5.2, 1.2), Color("9c9584"))
		b.cone(p + Vector3(0, 5.7, 0), 0.9, 1.0, Color("8a8374"))
		b.ball(p + Vector3(0, 6.5, 0), Vector3(0.7, 0.7, 0.7), CROWN_GOLD, true)


## North-west: a giant moss-grown guardian kneeling with its sword.
static func _moss_guardian(b: JapanKit.Batch, at: Vector3, look: Dictionary) -> void:
	var stone: Color = look.stone
	var moss: Color = look.moss
	b.box(at + Vector3(0, 0.6, 0), Vector3(6.0, 1.2, 6.0), stone.darkened(0.15))
	b.box(at + Vector3(0, 3.0, 0), Vector3(3.2, 3.6, 2.2), stone)
	b.ball(at + Vector3(0, 5.4, 0), Vector3(2.0, 2.0, 2.0), stone.lightened(0.05))
	b.box(at + Vector3(-2.0, 3.4, 0), Vector3(1.0, 2.8, 1.0), stone.darkened(0.05), Vector3(0, 0, 0.3))
	b.box(at + Vector3(2.0, 3.4, 0), Vector3(1.0, 2.8, 1.0), stone.darkened(0.05), Vector3(0, 0, -0.3))
	b.box(at + Vector3(0, 3.2, 1.6), Vector3(0.4, 6.4, 0.3), Color("b9c4c8"))
	b.box(at + Vector3(0, 4.6, 1.6), Vector3(1.6, 0.3, 0.4), Color("8a7a52"))
	b.ball(at + Vector3(0, 5.45, 0.92), Vector3(0.9, 0.3, 0.2), look.glow, true)
	for n in 7:
		var ang := TAU * float(n) / 7.0
		b.ball(at + Vector3(cos(ang) * 1.8, 1.4 + float(n % 3) * 1.2, sin(ang) * 1.2), Vector3(1.6, 0.9, 1.6), moss.darkened(float(n % 2) * 0.15))


## North-east: a red stone obelisk with a fire bowl.
static func _red_obelisk(b: JapanKit.Batch, at: Vector3, look: Dictionary) -> void:
	var stone: Color = look.stone
	b.box(at + Vector3(0, 0.5, 0), Vector3(5.0, 1.0, 5.0), stone.darkened(0.2))
	b.box(at + Vector3(0, 4.2, 0), Vector3(1.8, 6.6, 1.8), stone.darkened(0.05))
	b.cone(at + Vector3(0, 8.1, 0), 1.3, 1.4, stone.lightened(0.1))
	b.cyl(at + Vector3(0, 9.0, 0), 1.0, 0.5, Color("4a3a32"), Vector3.ZERO, 10)
	b.ball(at + Vector3(0, 9.5, 0), Vector3(1.4, 1.2, 1.4), Color("ff8a3a"), true)
	b.ball(at + Vector3(0, 10.1, 0), Vector3(0.7, 0.9, 0.7), Color("ffe07a"), true)
	for n in 4:
		var side := Vector3(1, 0, 0).rotated(Vector3.UP, TAU * float(n) / 4.0)
		b.box(at + side * 0.92 + Vector3(0, 4.4, 0), Vector3(0.5, 3.2, 0.06) if absf(side.z) > 0.5 else Vector3(0.06, 3.2, 0.5), look.glow, Vector3.ZERO, true)


## South-west: a frost spire of blue crystals.
static func _frost_spire(b: JapanKit.Batch, at: Vector3, look: Dictionary) -> void:
	b.cyl(at + Vector3(0, 0.4, 0), 3.0, 0.8, (look.stone as Color).darkened(0.2), Vector3.ZERO, 10)
	b.cone(at + Vector3(0, 4.6, 0), 1.3, 8.0, Color("bfeaff"))
	for n in 6:
		var ang := TAU * float(n) / 6.0
		var p := at + Vector3(cos(ang) * 1.7, 0, sin(ang) * 1.7)
		b.cone(p + Vector3(0, 2.0, 0), 0.6, 3.6 - float(n % 3) * 0.6, look.glow, Vector3(sin(ang) * 0.25, 0, -cos(ang) * 0.25))
	b.ball(at + Vector3(0, 8.8, 0), Vector3(0.9, 0.9, 0.9), Color("e8fbff"), true)


## South-east: a golden sun disk on its pedestal.
static func _sun_disk(b: JapanKit.Batch, at: Vector3, look: Dictionary) -> void:
	b.box(at + Vector3(0, 0.6, 0), Vector3(4.6, 1.2, 4.6), (look.stone as Color).darkened(0.1))
	b.box(at + Vector3(0, 2.4, 0), Vector3(1.2, 2.4, 1.2), look.stone)
	b.cyl(at + Vector3(0, 6.0, 0), 2.6, 0.4, CROWN_GOLD, Vector3(PI * 0.5, 0, 0), 16)
	b.cyl(at + Vector3(0, 6.0, 0.05), 1.6, 0.42, Color("fff3b0"), Vector3(PI * 0.5, 0, 0), 16)
	b.ball(at + Vector3(0, 6.0, 0.25), Vector3(1.1, 1.1, 0.3), look.glow, true)
	for n in 12:
		var ang := TAU * float(n) / 12.0
		b.box(at + Vector3(cos(ang) * 3.2, 6.0 + sin(ang) * 3.2, 0), Vector3(0.9, 0.3, 0.3), CROWN_GOLD, Vector3(0, 0, ang))


# --- The shrines --------------------------------------------------------------------

## Each shrine: a pale ring of the circle on the floor, eight short pillars round it with
## glowing caps, a little roofed altar with a floating crystal in the middle.
static func _shrines(batches: Array[JapanKit.Batch], root: Node3D) -> void:
	for k in MazeLayout.safe_count():
		var at := MazeLayout.safe_center(k)
		var b := _chunk(batches, at)
		var r := MazeLayout.SAFE_RADIUS
		b.cyl(at + Vector3(0, 0.07, 0), r + 0.25, 0.04, SAFE_COLOR, Vector3.ZERO, 24)
		b.cyl(at + Vector3(0, 0.09, 0), r - 0.2, 0.04, Color("d8f4f0"), Vector3.ZERO, 24)
		for n in 12:
			var ang := TAU * float(n) / 12.0
			b.box(at + Vector3(cos(ang), 0, sin(ang)) * (r - 0.6) + Vector3(0, 0.13, 0), Vector3(1.0, 0.03, 0.18), SAFE_GOLD, Vector3(0, -ang, 0), true)
		for n in 8:
			var ang := TAU * float(n) / 8.0 + PI / 8.0
			var p := at + Vector3(cos(ang), 0, sin(ang)) * (r + 0.4)
			b.box(p + Vector3(0, 0.75, 0), Vector3(0.5, 1.5, 0.5), Color("e6e1d4"))
			b.ball(p + Vector3(0, 1.65, 0), Vector3(0.42, 0.42, 0.42), SAFE_COLOR, true)
		b.box(at + Vector3(0, 0.35, 0), Vector3(1.6, 0.7, 1.6), Color("d8d0bc"))
		b.ball(at + Vector3(0, 1.7, 0), Vector3(0.6, 1.0, 0.6), SAFE_COLOR, true)
		for s in [Vector3(-0.7, 0, -0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, 0.7)]:
			b.box(at + s + Vector3(0, 1.4, 0), Vector3(0.18, 2.1, 0.18), Color("8a3a2a"))
		b.roof(at + Vector3(0, 2.75, 0), 2.6, 2.6, 0.8, Color("3a4a6a"))
		var tag := Label3D.new()
		tag.name = "ShrineTag%d" % k
		tag.text = "ที่หลบภัย"
		tag.font_size = 44
		tag.outline_size = 10
		tag.modulate = SAFE_COLOR.lerp(Color.WHITE, 0.4)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = false
		tag.position = at + Vector3(0, 4.0, 0)
		tag.visibility_range_end = 46.0
		root.add_child(tag)


# --- Runes and signs ----------------------------------------------------------------

## Glowing runes on the floor at scattered crossings (the way-marks of the old maze).
static func _runes(batches: Array[JapanKit.Batch], rng: RandomNumberGenerator) -> void:
	for c in MazeLayout.cell_count():
		if MazeLayout.plaza_of[c] >= 0 or MazeLayout.is_safe_cell(c) or MazeLayout.exits(c).size() < 3 or rng.randf() > 0.45:
			continue
		var at := MazeLayout.center(c)
		var glow: Color = _look(at).glow
		var b := _chunk(batches, at)
		var spin := rng.randf() * TAU
		for n in 3:
			var ang := spin + TAU * float(n) / 3.0
			b.box(at + Vector3(cos(ang), 0, sin(ang)) * 1.1 + Vector3(0, 0.08, 0), Vector3(1.0, 0.03, 0.2), glow, Vector3(0, -ang + PI * 0.5, 0), true)
		b.cyl(at + Vector3(0, 0.075, 0), 0.4, 0.03, glow.lerp(Color.WHITE, 0.3), Vector3.ZERO, 8)


## The quadrants' and the throne plaza's names over their plazas.
static func _signs(root: Node3D) -> void:
	for k in MazeLayout.PLAZAS.size():
		var at := MazeLayout.plaza_center(k)
		var tag := Label3D.new()
		tag.name = "PlazaName%d" % k
		tag.text = MazeLayout.CENTER_NAME if k == 0 else String(MazeLayout.QUADRANTS[MazeLayout.quadrant(at + Vector3(0.1, 0, 0.1))].name)
		tag.font_size = 64
		tag.outline_size = 14
		tag.modulate = CROWN_GOLD if k == 0 else (MazeLayout.QUADRANTS[MazeLayout.quadrant(at + Vector3(0.1, 0, 0.1))].glow as Color).lerp(Color.WHITE, 0.45)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = at + Vector3(0, 11.5 if k == 0 else 10.5, 0)
		tag.visibility_range_end = 90.0
		root.add_child(tag)


## The walls' colliders: one static body per quadrant, a box per run.
static func _colliders(root: Node3D) -> void:
	var bodies: Array[StaticBody3D] = []
	for q in 4:
		var body := StaticBody3D.new()
		body.name = "MazeWalls%d" % q
		body.collision_layer = 1
		root.add_child(body)
		bodies.append(body)
	for s in MazeLayout.segments():
		var a: Vector3 = s[0]
		var e: Vector3 = s[1]
		var along_x := absf(e.x - a.x) > absf(e.z - a.z)
		var length := a.distance_to(e) + MazeLayout.WALL_T
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, MazeLayout.WALL_H + 1.0, MazeLayout.WALL_T) if along_x else Vector3(MazeLayout.WALL_T, MazeLayout.WALL_H + 1.0, length)
		shape.shape = box
		shape.position = (a + e) * 0.5 + Vector3(0, (MazeLayout.WALL_H + 1.0) * 0.5, 0)
		bodies[int(s[2])].add_child(shape)
