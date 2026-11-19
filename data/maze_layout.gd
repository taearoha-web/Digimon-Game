class_name MazeLayout
extends RefCounted
## The labyrinth of เขาวงกตหนึ่งในใต้หล้า (MazeWar), worked out from one fixed seed so
## every device, the zone host and the tests build the very same maze: a square of
## CELLS x CELLS cells CELL metres wide (216 m across, the guild-war castle field's size),
## centred on the zone's origin (north is -z).
##
## How it is made (build):
## 1. a perfect maze: a seeded depth-first carve over every cell (one way between any two);
## 2. the five plazas opened up whole: the throne plaza in the middle (4 x 4 cells) and a
##    3 x 3 plaza in each quadrant, each the quadrant's landmark (its statue);
## 3. loops: a share (LOOP) of the inner walls left are knocked through, so a chase has
##    ways round and there are corners to wait at (a perfect maze is all dead ends);
## 4. the ten shrines (ที่หลบภัย, SAFE_CELLS): a courtyard cell open on every side (no
##    single door to camp), two in each quadrant and two between them.
## The walls stand on the cell borders (links: which borders are open), so a cell's
## centre always has a clear line to the centre of a linked neighbour: the AI walks the
## maze from cell centre to cell centre (route: a breadth-first distance field to the
## goal's cell, kept per goal).

const CELLS := 18
const CELL := 12.0
const HALF := CELLS * CELL * 0.5
## The walls: thickness and height (low enough that the field camera sees over the
## near ones; the hero is never hidden in the middle of a corridor).
const WALL_T := 1.4
const WALL_H := 3.2
const SEED := 20261119
## The share of the inner walls left after the carve that are knocked through.
const LOOP := 0.16
## The plazas: [first cell x, first cell z, size] (0 the throne plaza, 1-4 the quadrants'
## in QUADRANT order).
const PLAZAS: Array = [[7, 7, 4], [2, 2, 3], [13, 2, 3], [2, 13, 3], [13, 13, 3]]
## The ten shrines, by cell (spread two to a quadrant and two in the middle band).
const SAFE_CELLS: Array[Vector2i] = [Vector2i(6, 1), Vector2i(1, 7), Vector2i(11, 1), Vector2i(16, 6),
	Vector2i(1, 11), Vector2i(6, 16), Vector2i(16, 11), Vector2i(11, 16), Vector2i(8, 4), Vector2i(9, 13)]
## A shrine's protecting circle (metres from the cell centre).
const SAFE_RADIUS := 4.6
## The quadrants: names (Thai), the stone and the moss / glow colours of each.
const QUADRANTS: Array[Dictionary] = [
	{"name": "สวนมรกตรกร้าง", "stone": Color("8f9a86"), "moss": Color("4f8a3c"), "glow": Color("7dffb0"), "floor": Color("6f7a5e")},
	{"name": "ลานศิลาโลหิต", "stone": Color("a8857a"), "moss": Color("8a5a2c"), "glow": Color("ffb36b"), "floor": Color("8a6c5e")},
	{"name": "ธารศิลาคราม", "stone": Color("8a98a8"), "moss": Color("3f7a86"), "glow": Color("7dd8ff"), "floor": Color("66788a")},
	{"name": "ทุ่งศิลาทอง", "stone": Color("b0a07a"), "moss": Color("7a8a2c"), "glow": Color("ffe07a"), "floor": Color("8e8262")},
]
const CENTER_NAME := "ลานบัลลังก์หนึ่งในใต้หล้า"

const EAST := 1
const SOUTH := 2

## links[cz * CELLS + cx]: EAST (open to cx + 1) | SOUTH (open to cz + 1).
static var links := PackedByteArray()
## plaza_of[cell]: -1, or the plaza (PLAZAS index) the cell is part of.
static var plaza_of := PackedInt32Array()
static var _safe_index := {}
static var _fields := {}
static var _segments: Array = []


static func ensure() -> void:
	if links.is_empty():
		build()


## Builds the maze from SEED (always the same).
static func build() -> void:
	var n := CELLS * CELLS
	links = PackedByteArray()
	links.resize(n)
	links.fill(0)
	plaza_of = PackedInt32Array()
	plaza_of.resize(n)
	plaza_of.fill(-1)
	_fields.clear()
	_segments.clear()
	_safe_index.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# 1. The carve (an explicit stack: no recursion depth on a phone).
	var seen := PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var stack: Array[int] = [0]
	seen[0] = 1
	while not stack.is_empty():
		var c: int = stack[-1]
		var options: Array[int] = []
		for nb in _neighbours(c):
			if seen[nb] == 0:
				options.append(nb)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: int = options[rng.randi() % options.size()]
		_open(c, next)
		seen[next] = 1
		stack.append(next)
	# 2. The plazas.
	for p in PLAZAS.size():
		var px := int(PLAZAS[p][0])
		var pz := int(PLAZAS[p][1])
		var size := int(PLAZAS[p][2])
		for z in range(pz, pz + size):
			for x in range(px, px + size):
				plaza_of[z * CELLS + x] = p
				if x < px + size - 1:
					_open(z * CELLS + x, z * CELLS + x + 1)
				if z < pz + size - 1:
					_open(z * CELLS + x, (z + 1) * CELLS + x)
		# Each plaza has a way in on every side (a gate in the middle of each edge).
		var mid := size / 2
		for side in [[px + mid, pz - 1, px + mid, pz], [px + mid, pz + size, px + mid, pz + size - 1], [px - 1, pz + mid, px, pz + mid], [px + size, pz + mid, px + size - 1, pz + mid]]:
			if _inside(int(side[0]), int(side[1])):
				_open(int(side[1]) * CELLS + int(side[0]), int(side[3]) * CELLS + int(side[2]))
	# 3. The loops.
	for c in n:
		var x := c % CELLS
		var z := c / CELLS
		if x < CELLS - 1 and not is_open(c, c + 1) and rng.randf() < LOOP:
			_open(c, c + 1)
		if z < CELLS - 1 and not is_open(c, c + CELLS) and rng.randf() < LOOP:
			_open(c, c + CELLS)
	# 4. The shrines: open on every side.
	for k in SAFE_CELLS.size():
		var sc: Vector2i = SAFE_CELLS[k]
		var c := sc.y * CELLS + sc.x
		_safe_index[c] = k
		for nb in _neighbours(c):
			_open(c, nb)


static func _inside(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < CELLS and z < CELLS


static func _neighbours(c: int) -> Array[int]:
	var x := c % CELLS
	var z := c / CELLS
	var out: Array[int] = []
	if x > 0:
		out.append(c - 1)
	if x < CELLS - 1:
		out.append(c + 1)
	if z > 0:
		out.append(c - CELLS)
	if z < CELLS - 1:
		out.append(c + CELLS)
	return out


static func _open(a: int, b: int) -> void:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	if hi == lo + 1:
		links[lo] = links[lo] | EAST
	elif hi == lo + CELLS:
		links[lo] = links[lo] | SOUTH


## Whether neighbouring cells a and b have no wall between them.
static func is_open(a: int, b: int) -> bool:
	ensure()
	var lo := mini(a, b)
	var hi := maxi(a, b)
	if hi == lo + 1 and lo / CELLS == hi / CELLS:
		return links[lo] & EAST != 0
	if hi == lo + CELLS:
		return links[lo] & SOUTH != 0
	return false


## The open neighbours of cell c.
static func exits(c: int) -> Array[int]:
	var out: Array[int] = []
	for nb in _neighbours(c):
		if is_open(c, nb):
			out.append(nb)
	return out


# --- Cells and points ---------------------------------------------------------------

static func cell_count() -> int:
	return CELLS * CELLS


## The cell a point stands in (clamped to the maze).
static func cell_at(p: Vector3) -> int:
	var x := clampi(int(floor((p.x + HALF) / CELL)), 0, CELLS - 1)
	var z := clampi(int(floor((p.z + HALF) / CELL)), 0, CELLS - 1)
	return z * CELLS + x


static func center(c: int) -> Vector3:
	return Vector3(-HALF + CELL * (float(c % CELLS) + 0.5), 0.0, -HALF + CELL * (float(c / CELLS) + 0.5))


static func cell_xy(c: int) -> Vector2i:
	return Vector2i(c % CELLS, c / CELLS)


## Whether a point is on the maze's floor (inside the outer wall).
static func inside(p: Vector3) -> bool:
	var edge := HALF - WALL_T * 0.5
	return absf(p.x) < edge and absf(p.z) < edge


## The quadrant (QUADRANTS index) of a point or cell: 0 north-west, 1 north-east,
## 2 south-west, 3 south-east.
static func quadrant(p: Vector3) -> int:
	return (1 if p.x >= 0.0 else 0) + (2 if p.z >= 0.0 else 0)


static func quadrant_of_cell(c: int) -> int:
	return quadrant(center(c))


## What a point is near, for the HUD and the chat: the plaza's or the quadrant's name.
static func place_name(p: Vector3) -> String:
	ensure()
	var c := cell_at(p)
	if plaza_of[c] == 0:
		return CENTER_NAME
	return String(QUADRANTS[quadrant(p)].name)


## Every plaza's centre (PLAZAS order).
static func plaza_center(k: int) -> Vector3:
	var px := float(PLAZAS[k][0])
	var pz := float(PLAZAS[k][1])
	var size := float(PLAZAS[k][2])
	return Vector3(-HALF + CELL * (px + size * 0.5), 0.0, -HALF + CELL * (pz + size * 0.5))


# --- The shrines ----------------------------------------------------------------------

static func safe_count() -> int:
	return SAFE_CELLS.size()


static func safe_center(k: int) -> Vector3:
	var sc: Vector2i = SAFE_CELLS[k]
	return center(sc.y * CELLS + sc.x)


## The shrine (0-9) whose circle holds point p, or -1.
static func safe_at(p: Vector3) -> int:
	ensure()
	var c := cell_at(p)
	if not _safe_index.has(c):
		return -1
	var k := int(_safe_index[c])
	var at := safe_center(k)
	return k if Vector2(p.x - at.x, p.z - at.z).length() <= SAFE_RADIUS else -1


static func is_safe_cell(c: int) -> bool:
	ensure()
	return _safe_index.has(c)


## The shrine nearest point p by the maze's own ways (cells walked), -1 for none.
static func nearest_safe(p: Vector3) -> int:
	var from := cell_at(p)
	var best := -1
	var best_d := 1 << 30
	for k in SAFE_CELLS.size():
		var d := steps(from, SAFE_CELLS[k].y * CELLS + SAFE_CELLS[k].x)
		if d < best_d:
			best_d = d
			best = k
	return best


# --- Walking the maze ----------------------------------------------------------------

## The breadth-first distance (in cells) from every cell to cell `goal` (kept per goal).
static func field_to(goal: int) -> PackedInt32Array:
	ensure()
	var hit: Variant = _fields.get(goal)
	if hit != null:
		return hit
	var n := cell_count()
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	dist[goal] = 0
	var queue: Array[int] = [goal]
	var head := 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		for nb in exits(c):
			if dist[nb] < 0:
				dist[nb] = dist[c] + 1
				queue.append(nb)
	if _fields.size() > 360:
		_fields.clear()
	_fields[goal] = dist
	return dist


## Cells walked from a to b (-1 never: the maze is one piece).
static func steps(a: int, b: int) -> int:
	return field_to(b)[a]


## The next cell on the way from cell a to cell b (b itself next door, a when there).
static func next_cell(a: int, b: int) -> int:
	if a == b:
		return a
	var dist := field_to(b)
	var best := a
	var best_d := dist[a]
	for nb in exits(a):
		if dist[nb] >= 0 and dist[nb] < best_d:
			best_d = dist[nb]
			best = nb
	return best


## Whether one can walk straight from p to q: the same cell, a linked neighbour, or both
## in the same plaza.
static func direct(p: Vector3, q: Vector3) -> bool:
	ensure()
	var a := cell_at(p)
	var b := cell_at(q)
	if a == b:
		return true
	if plaza_of[a] >= 0 and plaza_of[a] == plaza_of[b]:
		return true
	return is_open(a, b)


## The next point to walk to from `from` on the way to `to`: `to` itself when straight on
## (direct), else the centre of the next cell of the way (the middle of its doorway first
## when the walker stands off the line through it, so it never grinds a corner).
static func route(from: Vector3, to: Vector3) -> Vector3:
	if direct(from, to):
		return to
	var a := cell_at(from)
	var next := next_cell(a, cell_at(to))
	if next == a:
		return to
	var door := (center(a) + center(next)) * 0.5
	var c := center(a)
	# Off the doorway's line: to the doorway first.
	var off := Vector2(from.x - c.x, from.z - c.z)
	var along := Vector2(door.x - c.x, door.z - c.z).normalized()
	var side := absf(off.x * along.y - off.y * along.x)
	if side > CELL * 0.22 and Vector2(from.x - door.x, from.z - door.z).length() > 1.5:
		return door
	return center(next)


## Every cell reachable from cell 0 (tests: the maze is one piece).
static func reachable_from(c: int) -> int:
	var dist := field_to(c)
	var n := 0
	for d in dist:
		if d >= 0:
			n += 1
	return n


# --- Spawning -----------------------------------------------------------------------

## A random spot to come back at: not in a shrine's cell, not in the throne plaza, at
## least `clear` metres from every point of `foes` (the others standing), picked by rng;
## after 48 tries the spot farthest from them.
static func spawn_point(rng: RandomNumberGenerator, foes: Array, clear := 18.0) -> Vector3:
	ensure()
	var best := Vector3.ZERO
	var best_d := -1.0
	for attempt in 48:
		var c := rng.randi() % cell_count()
		if is_safe_cell(c) or plaza_of[c] == 0:
			continue
		var p := center(c) + Vector3(rng.randf_range(-2.5, 2.5), 0.0, rng.randf_range(-2.5, 2.5))
		var near := INF
		for f in foes:
			var q: Vector3 = f
			near = minf(near, Vector2(p.x - q.x, p.z - q.z).length())
		if near >= clear:
			return p
		if near > best_d:
			best_d = near
			best = p
	return best


# --- The walls ----------------------------------------------------------------------

## The walls as merged straight runs: [[a: Vector3, b: Vector3, quadrant]] along the cell
## borders (the outer wall included), each a run of neighbouring closed borders.
static func segments() -> Array:
	ensure()
	if not _segments.is_empty():
		return _segments
	var out: Array = []
	# Borders along x (a wall between cz - 1 and cz, the lines z = j).
	for j in CELLS + 1:
		var run := -1
		for x in CELLS + 1:
			var closed := false
			if x < CELLS:
				if j == 0 or j == CELLS:
					closed = true
				else:
					closed = not is_open((j - 1) * CELLS + x, j * CELLS + x)
			if closed and run < 0:
				run = x
			elif not closed and run >= 0:
				_add_runs(out, Vector3(-HALF + CELL * run, 0, -HALF + CELL * j), Vector3(-HALF + CELL * x, 0, -HALF + CELL * j))
				run = -1
	# Borders along z (the lines x = i).
	for i in CELLS + 1:
		var run := -1
		for z in CELLS + 1:
			var closed := false
			if z < CELLS:
				if i == 0 or i == CELLS:
					closed = true
				else:
					closed = not is_open(z * CELLS + i - 1, z * CELLS + i)
			if closed and run < 0:
				run = z
			elif not closed and run >= 0:
				_add_runs(out, Vector3(-HALF + CELL * i, 0, -HALF + CELL * run), Vector3(-HALF + CELL * i, 0, -HALF + CELL * z))
				run = -1
	_segments = out
	return out


## A run cut at the quadrant lines (each quadrant's walls are drawn and culled apart).
static func _add_runs(out: Array, a: Vector3, b: Vector3) -> void:
	var cuts: Array[Vector3] = [a]
	if absf(a.z - b.z) < 0.01 and a.x < 0.0 and b.x > 0.0:
		cuts.append(Vector3(0.0, 0.0, a.z))
	if absf(a.x - b.x) < 0.01 and a.z < 0.0 and b.z > 0.0:
		cuts.append(Vector3(a.x, 0.0, 0.0))
	cuts.append(b)
	for k in cuts.size() - 1:
		var p: Vector3 = cuts[k]
		var q: Vector3 = cuts[k + 1]
		out.append([p, q, quadrant((p + q) * 0.5 + Vector3(0.01, 0, 0.01) * signf(0.5))])


## Whether point p is inside a wall (tests, spawn checks).
static func in_wall(p: Vector3, margin := 0.3) -> bool:
	for s in segments():
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var lo := Vector2(minf(a.x, b.x) - WALL_T * 0.5 - margin, minf(a.z, b.z) - WALL_T * 0.5 - margin)
		var hi := Vector2(maxf(a.x, b.x) + WALL_T * 0.5 + margin, maxf(a.z, b.z) + WALL_T * 0.5 + margin)
		if p.x > lo.x and p.x < hi.x and p.z > lo.y and p.z < hi.y:
			return true
	return false
