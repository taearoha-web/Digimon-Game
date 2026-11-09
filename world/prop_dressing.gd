class_name PropDressing
extends RefCounted
## Visual-only props that make a place look lived in: ruins and standing stones in the
## hunting fields, toadstools at tree feet, lily pads and reeds along the brook, potted
## plants and lantern posts along the village streets, lily pads on the village pond,
## torches, weapon racks and guild-coloured banners round the guild war's castle,
## fallen petals, lily pads and wayside shrines in the Lotus Sanctum, and shells,
## starfish and sea grass in the Drowned Abyss.
##
## Nothing here has a collider. Every prop kind is one small vertex-coloured mesh built
## from primitives (JapanKit.Batch: one solid surface, plus a glow surface for flames
## and a cloth surface for banners), drawn as one MultiMesh per kind per NatureKit
## chunk with a distance fade, so a kind costs a draw per visible chunk. The star
## fields reuse StarRegionArt's shared batches instead (no new chunks there).
## Counts follow [method lush] (quality 0 minimal, 1 the phone default, 2 lush), and
## every placement keeps off the exclusion circles it is given (paths, camps, gates,
## villagers, stalls, the switch circle and the altar).

## Group of every MultiMeshInstance3D made here (tests read their instances).
const GROUP := "prop_dressing"
## Density of the dressing per quality level: minimal, phone default, lush.
const LUSH := [0.3, 1.0, 1.6]
## Grass tufts per quality (relative to the old 620 patches), bushes and flowers.
const GRASS := [0.3, 1.2, 1.9]
const BUSHES := [0.45, 0.95, 1.3]
const FLOWERS := [0.45, 1.25, 1.9]

static var _meshes: Dictionary = {}


static func _q() -> int:
	return clampi(GameSettings.quality, 0, 2)


static func lush() -> float:
	return LUSH[_q()]


static func grass_scale() -> float:
	return GRASS[_q()]


static func bush_scale() -> float:
	return BUSHES[_q()]


static func flower_scale() -> float:
	return FLOWERS[_q()]


## How many of a thing at this quality (at least `minimum`).
static func count(base: float, minimum := 0) -> int:
	return maxi(minimum, int(round(base * lush())))


## True when the flat point `p` keeps `radius` off every (x, z, r) circle in `blocked`.
static func is_free(p: Vector2, radius: float, blocked: Array) -> bool:
	for o in blocked:
		var c: Vector3 = o
		if p.distance_to(Vector2(c.x, c.y)) < c.z + radius:
			return false
	return true


## Distance from p to the nearest of the polylines.
static func path_distance(p: Vector2, paths: Array) -> float:
	var best := INF
	for path in paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var ab: Vector2 = path[i + 1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


# ---------------------------------------------------------------------------
# Batching
# ---------------------------------------------------------------------------

## Adds the chunked MultiMeshes of prop `kind` at `transforms` (tints multiply the
## mesh's own colours; white when not given) under `parent`. Visual only.
static func place(parent: Node3D, kind: String, transforms: Array[Transform3D], tints: Array[Color] = [],
		view := 60.0, shadows := false) -> void:
	if transforms.is_empty():
		return
	var mesh := mesh_for(kind)
	var chunks: Dictionary = {}
	for i in transforms.size():
		var o := transforms[i].origin
		var cell := Vector2i(floori(o.x / NatureKit.CHUNK), floori(o.z / NatureKit.CHUNK))
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(i)
	for cell in chunks:
		var indices: Array = chunks[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = indices.size()
		for j in indices.size():
			mm.set_instance_transform(j, transforms[indices[j]])
			mm.set_instance_color(j, tints[indices[j]] if indices[j] < tints.size() else Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [kind, cell.x, cell.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (shadows and GameSettings.world_shadows()) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = view * GameSettings.view_scale()
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if GameSettings.quality >= 2 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		var centre := Vector3((cell.x + 0.5) * NatureKit.CHUNK, 1.0, (cell.y + 0.5) * NatureKit.CHUNK)
		mmi.custom_aabb = NatureKit.chunk_bounds(mesh, transforms, indices, centre)
		mmi.set_meta("prop_kind", kind)
		# Where each instance stands (x, z): a headless server keeps no MultiMesh data,
		# and the placement tests read these.
		var spots := PackedVector2Array()
		for j in indices.size():
			var o: Vector3 = transforms[indices[j]].origin
			spots.append(Vector2(o.x, o.z))
		mmi.set_meta("spots", spots)
		mmi.add_to_group(GROUP)
		parent.add_child(mmi)


## A holder node for one place's dressing.
static func holder(parent: Node3D, node_name := "PropDressing") -> Node3D:
	var h := parent.get_node_or_null(node_name) as Node3D
	if h == null:
		h = Node3D.new()
		h.name = node_name
		parent.add_child(h)
	return h


static func _yaw(rng: RandomNumberGenerator, s: Vector3, at: Vector3, tilt := 0.0) -> Transform3D:
	var basis := Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt)))
	return Transform3D(basis.scaled(s), at)


# ---------------------------------------------------------------------------
# Meshes (unit props, origin on the ground, front = +z)
# ---------------------------------------------------------------------------

static func mesh_for(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var b := JapanKit.Batch.new()
	var stone := Color("b9b6aa")
	var stone_dark := Color("8f8c82")
	var moss := Color("7d9a5a")
	match kind:
		"ruin_column":
			b.box(Vector3(0, 0.15, 0), Vector3(1.15, 0.3, 1.15), stone_dark)
			b.cyl(Vector3(0, 1.05, 0), 0.36, 1.6, stone, Vector3.ZERO, 8)
			b.cyl(Vector3(0.05, 1.95, 0.02), 0.34, 0.3, stone, Vector3(8, 0, -10), 8)
			b.box(Vector3(0.2, 0.34, 0.45), Vector3(0.5, 0.12, 0.3), moss, Vector3(0, 20, 0))
			b.ball(Vector3(-0.3, 0.32, -0.35), Vector3(0.45, 0.22, 0.4), moss)
		"ruin_drum":
			b.cyl(Vector3(0, 0.3, 0), 0.36, 0.6, stone, Vector3(0, 0, 90), 8)
			b.ball(Vector3(0.1, 0.55, 0), Vector3(0.4, 0.14, 0.36), moss)
		"ruin_wall":
			for row in 3:
				var n := 4 - row
				for i in n:
					var w := 0.62 + float((i * 7 + row * 3) % 3) * 0.08
					var x := -1.1 + float(i) * 0.7 + float(row) * 0.33
					b.box(Vector3(x, 0.22 + row * 0.42, 0), Vector3(w, 0.4, 0.55), stone if (i + row) % 2 == 0 else stone_dark, Vector3(0, (i - 1) * 3.0, 0))
			b.box(Vector3(1.3, 0.12, 0.5), Vector3(0.45, 0.24, 0.35), stone_dark, Vector3(0, 30, 12))
			b.ball(Vector3(-0.6, 1.08, 0), Vector3(0.6, 0.18, 0.5), moss)
			b.ball(Vector3(0.6, 0.1, 0.35), Vector3(0.6, 0.18, 0.4), moss)
		"standing_stone":
			b.box(Vector3(0, 1.0, 0), Vector3(0.75, 2.0, 0.45), stone_dark, Vector3(3, 0, 4))
			b.box(Vector3(0.02, 2.02, 0), Vector3(0.62, 0.18, 0.4), stone, Vector3(3, 0, 12))
			b.ball(Vector3(0, 0.08, 0), Vector3(1.0, 0.2, 0.8), moss)
			b.box(Vector3(0, 1.25, 0.24), Vector3(0.22, 0.22, 0.02), Color("6fb8b0"), Vector3(3, 0, 49))
		"pebbles":
			for i in 5:
				var a := float(i) * 2.4
				var r := 0.15 + float(i % 3) * 0.17
				b.ball(Vector3(cos(a) * r, 0.04, sin(a) * r), Vector3(0.24, 0.12, 0.2) * (1.0 - float(i) * 0.12), stone if i % 2 == 0 else stone_dark)
		"log":
			b.cyl(Vector3(0, 0.26, 0), 0.26, 2.0, Color("7a5a40"), Vector3(0, 0, 90), 8)
			for x in [-1.0, 1.0]:
				b.cyl(Vector3(x * 1.0, 0.26, 0), 0.22, 0.03, Color("d8bf90"), Vector3(0, 0, 90), 8)
			b.ball(Vector3(0.3, 0.48, 0), Vector3(0.7, 0.14, 0.32), moss)
			b.cyl(Vector3(-0.4, 0.55, 0.05), 0.05, 0.12, Color("f2ead6"), Vector3.ZERO, 5)
			b.cyl(Vector3(-0.4, 0.62, 0.05), 0.11, 0.05, Color("e2604a"), Vector3.ZERO, 6)
		"toadstools":
			var caps := [Color("e8604a"), Color("f0b84a"), Color("e8604a")]
			for i in 3:
				var a := float(i) * 2.1
				var h := 0.22 - float(i) * 0.05
				var at := Vector3(cos(a) * 0.18 * float(i), 0, sin(a) * 0.18 * float(i))
				b.cyl(at + Vector3(0, h * 0.5, 0), 0.04, h, Color("f2ead6"), Vector3.ZERO, 5)
				b.ball(at + Vector3(0, h, 0), Vector3(0.22, 0.12, 0.22) * (1.0 - float(i) * 0.18), caps[i])
				b.ball(at + Vector3(0.04, h + 0.05, 0.02), Vector3(0.04, 0.02, 0.04), Color("fff6e8"))
		"lily":
			b.cyl(Vector3(0, 0.01, 0), 0.5, 0.02, Color("6f9a5a"), Vector3.ZERO, 10)
			b.box(Vector3(0.28, 0.012, 0), Vector3(0.45, 0.025, 0.08), Color("4f7a44"), Vector3(0, 0, 0))
			b.cyl(Vector3(-0.32, 0.01, 0.35), 0.28, 0.02, Color("7fa868"), Vector3.ZERO, 8)
		"lily_bloom":
			b.cyl(Vector3(0, 0.01, 0), 0.5, 0.02, Color("6f9a5a"), Vector3.ZERO, 10)
			for i in 6:
				var a := float(i) * TAU / 6.0
				b.cone(Vector3(cos(a) * 0.1, 0.12, sin(a) * 0.1), 0.07, 0.24, Color("f6c6d6"), Vector3(rad_to_deg(sin(a)) * 0.5, 0, -rad_to_deg(cos(a)) * 0.5))
			b.ball(Vector3(0, 0.12, 0), Vector3(0.1, 0.08, 0.1), Color("f0d060"))
		"reeds":
			for i in 7:
				var a := float(i) * 2.3
				var r := 0.08 + float(i % 3) * 0.12
				var h := 0.9 + float((i * 5) % 4) * 0.18
				b.cone(Vector3(cos(a) * r, h * 0.5, sin(a) * r), 0.035, h, Color("6f8a48"), Vector3(sin(a) * 6.0, 0, cos(a) * 6.0))
				if i % 3 == 0:
					b.cyl(Vector3(cos(a) * r, h * 0.82, sin(a) * r), 0.05, 0.24, Color("7a5434"), Vector3.ZERO, 5)
		"potted_plant":
			b.cyl(Vector3(0, 0.22, 0), 0.3, 0.44, Color("b8643c"), Vector3.ZERO, 8)
			b.cyl(Vector3(0, 0.45, 0), 0.33, 0.06, Color("9a4e2e"), Vector3.ZERO, 8)
			b.cyl(Vector3(0, 0.15, 0), 0.31, 0.05, Color("d8885a"), Vector3.ZERO, 8)
			for i in 5:
				var a := float(i) * TAU / 5.0
				b.ball(Vector3(cos(a) * 0.2, 0.7 + float(i % 2) * 0.1, sin(a) * 0.2), Vector3(0.42, 0.36, 0.42), Color("4f7f42") if i % 2 == 0 else Color("6f9f52"))
			b.ball(Vector3(0, 0.95, 0), Vector3(0.44, 0.4, 0.44), Color("78a85a"))
			for i in 5:
				var a := float(i) * TAU / 5.0 + 0.6
				b.ball(Vector3(cos(a) * 0.3, 0.86 + float(i % 2) * 0.12, sin(a) * 0.3), Vector3(0.09, 0.07, 0.09), Color("f6a8c0") if i % 2 == 0 else Color("fff4f0"))
		"bonsai_pot":
			b.box(Vector3(0, 0.16, 0), Vector3(0.8, 0.32, 0.5), Color("3f4a5a"))
			b.box(Vector3(0, 0.33, 0), Vector3(0.84, 0.04, 0.54), Color("2f3846"))
			b.cyl(Vector3(0.05, 0.6, 0), 0.06, 0.55, Color("5a3e34"), Vector3(0, 0, -18), 5)
			b.ball(Vector3(-0.08, 0.92, 0), Vector3(0.6, 0.26, 0.42), Color("3f6a42"))
			b.ball(Vector3(0.22, 0.76, 0.04), Vector3(0.36, 0.18, 0.3), Color("4f7a4c"))
		"crates":
			b.box(Vector3(0, 0.3, 0), Vector3(0.62, 0.6, 0.62), Color("b08a58"))
			b.box(Vector3(0, 0.3, 0.315), Vector3(0.66, 0.1, 0.02), Color("7a5a38"), Vector3(0, 0, 45))
			b.box(Vector3(0.62, 0.24, 0.05), Vector3(0.5, 0.48, 0.5), Color("a07a48"), Vector3(0, 18, 0))
			b.box(Vector3(0.1, 0.84, 0.0), Vector3(0.46, 0.48, 0.46), Color("c09a68"), Vector3(0, -14, 0))
			b.cyl(Vector3(-0.62, 0.36, 0.1), 0.26, 0.72, Color("8a5a34"), Vector3.ZERO, 8)
			for y in [0.12, 0.6]:
				b.cyl(Vector3(-0.62, y, 0.1), 0.27, 0.05, Color("3a3a40"), Vector3.ZERO, 8)
			b.ball(Vector3(0.62, 0.52, 0.05), Vector3(0.3, 0.12, 0.3), Color("e8a040"))
		"lantern_post":
			b.box(Vector3(0, 0.08, 0), Vector3(0.5, 0.16, 0.5), Color("5a5650"))
			b.cyl(Vector3(0, 1.05, 0), 0.07, 1.9, JapanKit.WOOD_DARK, Vector3.ZERO, 6)
			b.box(Vector3(0, 1.75, 0), Vector3(0.42, 0.5, 0.42), Color("ffe7b0"), Vector3.ZERO, true)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					b.box(Vector3(x * 0.2, 1.75, z * 0.2), Vector3(0.05, 0.52, 0.05), JapanKit.WOOD_DARK)
			b.roof(Vector3(0, 2.12, 0), 0.7, 0.7, 0.24, JapanKit.TILE_DARK, 0.0)
		"signpost":
			b.cyl(Vector3(0, 0.9, 0), 0.07, 1.8, JapanKit.WOOD, Vector3.ZERO, 6)
			b.box(Vector3(0.32, 1.45, 0), Vector3(0.7, 0.22, 0.05), JapanKit.WOOD_LIGHT, Vector3(0, 0, 4))
			b.cone(Vector3(0.72, 1.45, 0), 0.13, 0.16, JapanKit.WOOD_LIGHT, Vector3(0, 0, -90))
			b.box(Vector3(-0.3, 1.12, 0), Vector3(0.62, 0.2, 0.05), JapanKit.WOOD_LIGHT, Vector3(0, 30, -3))
			b.cone(Vector3(-0.66, 1.12, -0.2), 0.12, 0.15, JapanKit.WOOD_LIGHT, Vector3(0, 30, 90))
			b.ball(Vector3(0, 1.84, 0), Vector3(0.14, 0.1, 0.14), JapanKit.WOOD_DARK)
		"torch":
			b.cyl(Vector3(0, 0.9, 0), 0.07, 1.8, JapanKit.WOOD_DARK, Vector3.ZERO, 6)
			b.cyl(Vector3(0, 1.85, 0), 0.2, 0.18, Color("3a3a40"), Vector3.ZERO, 8)
			b.cyl(Vector3(0, 1.75, 0), 0.12, 0.08, Color("2a2a30"), Vector3.ZERO, 8)
			b.cone(Vector3(0, 2.12, 0), 0.17, 0.42, Color("ff9a3a"), Vector3.ZERO)
			b.ball(Vector3(0, 2.0, 0), Vector3(0.3, 0.2, 0.3), Color("ffd070"), true)
			b.cone(Vector3(0, 2.2, 0), 0.08, 0.3, Color("fff0b0"), Vector3.ZERO)
		"weapon_rack":
			for x in [-0.7, 0.7]:
				b.box(Vector3(x, 0.6, 0), Vector3(0.12, 1.2, 0.12), JapanKit.WOOD)
			for y in [0.35, 1.05]:
				b.box(Vector3(0, y, 0), Vector3(1.6, 0.08, 0.14), JapanKit.WOOD_DARK)
			# Spears and a naginata leaning on it, a shield at its foot.
			for i in 3:
				var x := -0.45 + float(i) * 0.45
				b.cyl(Vector3(x, 1.0, 0.1), 0.025, 2.0, Color("5a3e2c"), Vector3(-6, 0, 0), 5)
				b.cone(Vector3(x, 2.06, 0.21), 0.05, 0.24, Color("d8dce4"), Vector3(-6, 0, 0))
			b.cyl(Vector3(0.95, 0.35, 0.3), 0.3, 0.06, Color("8a2f2a"), Vector3(80, 0, 0), 10)
			b.cyl(Vector3(0.95, 0.35, 0.34), 0.08, 0.04, JapanKit.GOLD, Vector3(80, 0, 0), 6)
		"war_banner":
			# White cloth: the instance tint gives it the guild's colour.
			b.cyl(Vector3(0, 2.4, 0), 0.06, 4.8, JapanKit.WOOD_DARK, Vector3.ZERO, 6)
			var weight := JapanKit.banner_weight(0.03, 4.3, 0.9, 3.0)
			b.cloth(Vector3(0.48, 2.85, 0), Vector3(0.9, 3.0, 0.03), Color.WHITE, weight)
			b.box(Vector3(0.48, 4.32, 0), Vector3(1.0, 0.06, 0.06), JapanKit.WOOD_DARK)
			b.cloth(Vector3(0.48, 3.7, 0.025), Vector3(0.9, 0.24, 0.01), Color("f4f0e6"), weight)
			b.ball(Vector3(0, 4.86, 0), Vector3(0.14, 0.18, 0.14), JapanKit.GOLD)
		"wildflowers":
			# Pale blossoms on short stems; the instance tint colours the petals.
			for i in 6:
				var a := float(i) * 2.4
				var r := 0.06 + float(i % 3) * 0.13
				var h := 0.22 + float((i * 3) % 4) * 0.05
				var at := Vector3(cos(a) * r, 0, sin(a) * r)
				b.cyl(at + Vector3(0, h * 0.5, 0), 0.012, h, Color("8fb070"), Vector3.ZERO, 4)
				b.cyl(at + Vector3(0, h, 0), 0.075, 0.02, Color.WHITE, Vector3(10, 0, 8), 6)
				b.ball(at + Vector3(0, h + 0.015, 0), Vector3(0.04, 0.03, 0.04), Color("f6d35a"))
			for i in 3:
				var a := float(i) * 2.1 + 1.0
				b.cone(Vector3(cos(a) * 0.12, 0.07, sin(a) * 0.12), 0.05, 0.14, Color("8fb070"), Vector3(sin(a) * 20.0, 0, cos(a) * 20.0))
		"bush_ball":
			b.ball(Vector3(0, 0.32, 0), Vector3(1.0, 0.7, 0.9), Color("5f8f4a"))
			b.ball(Vector3(0.32, 0.26, 0.12), Vector3(0.6, 0.48, 0.55), Color("6f9f52"))
			b.ball(Vector3(-0.3, 0.22, -0.1), Vector3(0.55, 0.42, 0.5), Color("4f7f42"))
	var mesh := b.mesh()
	_meshes[kind] = mesh
	return mesh


# ---------------------------------------------------------------------------
# Hunting fields
# ---------------------------------------------------------------------------

## Stone tints per field theme (instance tint over the pale stone of the ruins).
const RUIN_TINT := {
	&"meadow": Color("ffffff"), &"digital": Color("c8c0e8"), &"desert": Color("f0d4a8"), &"snow": Color("e8f2ff"),
	&"volcano": Color("8a7470"), &"graveyard": Color("9a9cb0"), &"swamp": Color("b8c8a8"), &"storm": Color("a8b4c4"),
	&"sky": Color("fff6e0"), &"abyss": Color("a08890"), &"void": Color("9890c0"),
}


## The field's ruins and stones, logs, pebbles and toadstools at the feet of the
## inner trees (`trees`: their x, z, size). `occupied` is the populate's list (paths,
## camps, portals, the boss spot and everything already placed) and grows with these.
static func field(parent: Node3D, theme: StringName, rng: RandomNumberGenerator, radius: float,
		occupied: Array[Vector3], trees: Array[Vector3]) -> void:
	var h := holder(parent)
	var tint: Color = RUIN_TINT.get(theme, Color.WHITE)
	var columns: Array[Transform3D] = []
	var drums: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var pebbles: Array[Transform3D] = []
	var logs: Array[Transform3D] = []
	var shrooms: Array[Transform3D] = []
	# Ruin sites: a broken colonnade round a little court, a fallen drum and a wall.
	var sites: int = [1, 3, 4][_q()]
	var tries := 0
	while sites > 0 and tries < 200:
		tries += 1
		var c := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius)) * 0.85
		if c.length() > radius - 8.0 or not _site_free(c, 6.0, occupied):
			continue
		sites -= 1
		var turn := rng.randf() * TAU
		var n := rng.randi_range(4, 6)
		for i in n:
			var a := turn + TAU * float(i) / float(n)
			var p := c + Vector2(cos(a), sin(a)) * 3.6
			if i % 3 == 2:
				drums.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.9, 1.2), Vector3(p.x, 0, p.y)))
			else:
				var s := rng.randf_range(0.85, 1.25)
				columns.append(_yaw(rng, Vector3(s, s * rng.randf_range(0.7, 1.4), s), Vector3(p.x, 0, p.y), 0.05))
		var w := c + Vector2(cos(turn + 0.5), sin(turn + 0.5)) * 5.2
		walls.append(Transform3D(Basis(Vector3.UP, -turn).scaled(Vector3.ONE * rng.randf_range(0.9, 1.2)), Vector3(w.x, 0, w.y)))
		occupied.append(Vector3(c.x, c.y, 6.0))
	# A ring of standing stones (q1 up).
	var rings: int = [0, 1, 1][_q()]
	tries = 0
	while rings > 0 and tries < 120:
		tries += 1
		var c := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius)) * 0.85
		if c.length() > radius - 7.0 or not _site_free(c, 5.0, occupied):
			continue
		rings -= 1
		var n := 7
		for i in n:
			var a := TAU * float(i) / float(n)
			var p := c + Vector2(cos(a), sin(a)) * 3.8
			var s := rng.randf_range(0.8, 1.15)
			var xf := Transform3D(Basis(Vector3.UP, -a + PI * 0.5).scaled(Vector3(s, s * rng.randf_range(0.75, 1.2), s)), Vector3(p.x, 0, p.y))
			stones.append(xf)
		occupied.append(Vector3(c.x, c.y, 5.0))
	# Lone standing stones, logs and pebble clusters.
	_scatter(rng, radius, occupied, count(10.0, 2), 0.9, func(p: Vector2) -> void:
		stones.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.6, 1.0), Vector3(p.x, 0, p.y), 0.08)))
	_scatter(rng, radius, occupied, count(9.0, 1), 1.3, func(p: Vector2) -> void:
		logs.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.8, 1.2), Vector3(p.x, 0, p.y))))
	_scatter(rng, radius, occupied, count(50.0, 10), 0.4, func(p: Vector2) -> void:
		pebbles.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.7, 1.5), Vector3(p.x, 0, p.y))))
	# Wildflower clumps in drifts of one colour.
	if theme in [&"meadow", &"sky", &"digital", &"swamp"]:
		flower_drifts(h, rng, radius, occupied, count(40.0, 10))
	# Toadstools at the feet of the inner trees (inside their own footprint).
	var mush_tints := {&"meadow": Color.WHITE, &"village": Color.WHITE, &"swamp": Color("e0c8ff"), &"digital": Color("a8e8ff")}
	for t in trees:
		if rng.randf() > 0.45 * lush():
			continue
		var a := rng.randf() * TAU
		var p := Vector2(t.x, t.y) + Vector2(cos(a), sin(a)) * t.z * rng.randf_range(0.55, 0.85)
		shrooms.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.9, 1.4), Vector3(p.x, 0, p.y)))
	var stone_tints: Array[Color] = []
	for i in maxi(columns.size(), maxi(stones.size(), maxi(walls.size(), maxi(drums.size(), pebbles.size())))):
		stone_tints.append(tint.darkened(rng.randf() * 0.12))
	place(h, "ruin_column", columns, stone_tints, 80.0)
	place(h, "ruin_drum", drums, stone_tints, 70.0)
	place(h, "ruin_wall", walls, stone_tints, 80.0)
	place(h, "standing_stone", stones, stone_tints, 80.0)
	place(h, "pebbles", pebbles, stone_tints, 40.0)
	place(h, "log", logs, [], 60.0)
	if mush_tints.has(theme) or theme == &"storm":
		var mt: Array[Color] = []
		mt.resize(shrooms.size())
		mt.fill(mush_tints.get(theme, Color.WHITE))
		place(h, "toadstools", shrooms, mt, 40.0)


## `n` drifts of 4-9 wildflower clumps of one colour each, off `occupied`.
static func flower_drifts(h: Node3D, rng: RandomNumberGenerator, radius: float, occupied: Array[Vector3], n: int) -> void:
	var flowers: Array[Transform3D] = []
	var flower_tints: Array[Color] = []
	var palette := [Color("f6b6c8"), Color("fff4d8"), Color("f8d870"), Color("c8b0f0"), Color("a8d0f8")]
	for d in n:
		var c := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		var col: Color = palette[rng.randi() % palette.size()]
		for k in rng.randi_range(4, 9):
			var p := c + Vector2(rng.randf_range(-2.2, 2.2), rng.randf_range(-2.2, 2.2))
			if p.length() > radius - 1.0 or not _site_free(p, 0.3, occupied):
				continue
			flowers.append(_yaw(rng, Vector3.ONE * rng.randf_range(1.3, 1.9), Vector3(p.x, 0, p.y)))
			flower_tints.append(col.lerp(Color.WHITE, rng.randf() * 0.25))
	place(h, "wildflowers", flowers, flower_tints, 40.0)


static func _site_free(c: Vector2, r: float, occupied: Array[Vector3]) -> bool:
	if Scenery._grows.is_valid() and not Scenery._grows.call(c):
		return false
	return is_free(c, r, occupied)


## Calls `put(p)` for up to `n` free points, each then occupying `r`.
static func _scatter(rng: RandomNumberGenerator, radius: float, occupied: Array[Vector3], n: int, r: float, put: Callable) -> void:
	var tries := 0
	while n > 0 and tries < n * 12 + 40:
		tries += 1
		var p := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if p.length() > radius - 1.5 or not _site_free(p, r, occupied):
			continue
		put.call(p)
		occupied.append(Vector3(p.x, p.y, r))
		n -= 1


## Lily pads, flowering pads and reed clumps along the brook (RegionArt.STREAM), off
## the `clear` circles (the trail and the camps).
static func stream_bank(parent: Node3D, theme: StringName, clear: Array[Vector3], seed_value: int) -> void:
	if not theme in [&"meadow", &"digital", &"swamp", &"sky", &"storm", &"snow"]:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + 4111
	var h := holder(parent)
	var pads: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	var reeds: Array[Transform3D] = []
	var shrooms: Array[Transform3D] = []
	var points: Array = RegionArt.STREAM
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var along := (b - a).normalized()
		var side := Vector2(-along.y, along.x)
		var steps := int(a.distance_to(b) / 2.6) + 1
		for k in steps:
			var p := a.lerp(b, (float(k) + rng.randf()) / float(steps))
			if not is_free(p, 1.4, clear):
				continue
			var roll := rng.randf()
			if roll < 0.32 * lush():
				var q := p + side * rng.randf_range(-0.3, 0.3)
				var s := rng.randf_range(0.45, 0.7)
				if rng.randf() < 0.3:
					blooms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s)), Vector3(q.x, 0.05, q.y)))
				else:
					pads.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, 1.0, s)), Vector3(q.x, 0.05, q.y)))
			elif roll < 0.62 * lush():
				var q := p + side * (1.5 + rng.randf() * 0.6) * (1.0 if rng.randf() < 0.5 else -1.0)
				if is_free(q, 0.6, clear):
					reeds.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.7, 1.1), Vector3(q.x, 0, q.y), 0.05))
			elif roll < 0.75 * lush():
				var q := p + side * (2.0 + rng.randf()) * (1.0 if rng.randf() < 0.5 else -1.0)
				if is_free(q, 0.5, clear):
					shrooms.append(_yaw(rng, Vector3.ONE * rng.randf_range(0.8, 1.2), Vector3(q.x, 0, q.y)))
	var pad_tint := Color.WHITE if theme != &"digital" else Color("b8e0d8")
	var pt: Array[Color] = []
	pt.resize(maxi(pads.size(), blooms.size()))
	pt.fill(pad_tint)
	place(h, "lily", pads, pt, 45.0)
	place(h, "lily_bloom", blooms, pt, 45.0)
	place(h, "reeds", reeds, [], 45.0)
	place(h, "toadstools", shrooms, [], 40.0)


# ---------------------------------------------------------------------------
# The village
# ---------------------------------------------------------------------------

## Potted plants, bonsai, crate stacks, lantern posts and signposts along the edges of
## the village streets, and lily pads on the pond. Each spot keeps 1.2 m off every
## collider under the village (buildings, walls, booths, props), 5.5 m off the
## villagers' and stalls' `yards` circles (where the hero walks up to talk) and off the
## street middles. Visual only.
static func village(zone: Node3D, yards: Array[Vector3]) -> void:
	var village_root := zone.get_node_or_null("Village") as Node3D
	var h := holder(zone)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90517
	var boxes := _collider_boxes(village_root) if village_root else []
	var blocked: Array[Vector3] = []
	for y in yards:
		blocked.append(Vector3(y.x, y.y, y.z + 2.5))
	# The plaza, the gate, the warp crystal and notice board, the pond (its own pads).
	blocked.append(Vector3(0, 0, JapanVillage.PLAZA_RADIUS + 2.0))
	blocked.append(Vector3(JapanVillage.GATE.x, JapanVillage.GATE.z, 9.0))
	blocked.append(Vector3(JapanVillage.WARP.x, JapanVillage.WARP.z, 3.0))
	blocked.append(Vector3(JapanVillage.NOTICE.x, JapanVillage.NOTICE.z, 3.0))
	blocked.append(Vector3(JapanVillage.POND.x, JapanVillage.POND.z, 10.0))
	blocked.append(Vector3(JapanVillage.START.x, JapanVillage.START.z, 4.0))
	var streets := JapanVillage.paths()
	var kinds := ["potted_plant", "lantern_post", "bonsai_pot", "potted_plant", "crates", "lantern_post"]
	var by_kind: Dictionary = {}
	for k in kinds:
		by_kind[k] = [] as Array[Transform3D]
	by_kind["signpost"] = [] as Array[Transform3D]
	var spacing: float = [14.0, 7.0, 5.5][_q()]
	var placed: Array[Vector3] = []
	var n := 0
	for line in streets:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var length := a.distance_to(b)
			var along := (b - a) / maxf(length, 0.01)
			var side := Vector2(-along.y, along.x)
			var t := 3.0
			while t < length - 3.0:
				for s in [-1.0, 1.0]:
					# Just past the kerb (VillageGround.STREET_HALF), as close as it fits.
					var p := Vector2.INF
					for off in [3.8, 4.8, 5.8, 6.8]:
						var q: Vector2 = a + along * t + side * s * off
						var d := JapanVillage.district_at(Vector3(q.x, 0, q.y))
						if d.is_empty() or String(d.id) in ["farm", "grove", "plaza"]:
							continue
						if q.length() > JapanVillage.RADIUS - 5.0 or path_distance(q, streets) < 3.5:
							continue
						if is_free(q, 1.2, blocked) and clear_of_boxes(q, 0.9, boxes) and is_free(q, spacing * 0.6, placed):
							p = q
							break
					if p == Vector2.INF:
						continue
					var d := JapanVillage.district_at(Vector3(p.x, 0, p.y))
					var kind: String = kinds[n % kinds.size()]
					if String(d.id) != "market" and kind == "crates":
						kind = "potted_plant"
					n += 1
					var face := atan2(-side.x * s, -side.y * s)
					by_kind[kind].append(Transform3D(Basis(Vector3.UP, face + rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.1)), Vector3(p.x, 0, p.y)))
					placed.append(Vector3(p.x, p.y, 0.0))
				t += spacing
	# Signposts at the crossings of the main streets (just off the corner).
	for at in [Vector2(5.4, 45.4), Vector2(-5.4, -5.4 - JapanVillage.PLAZA_RADIUS), Vector2(-JapanVillage.POND.x * -1.0 + 5.4, JapanVillage.CROSS_Z + 5.4)]:
		if is_free(at, 1.0, blocked) and clear_of_boxes(at, 1.0, boxes) and path_distance(at, streets) >= 3.5:
			by_kind["signpost"].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(at.x, 0, at.y)))
	for k in by_kind:
		place(h, k, by_kind[k], [], 55.0)
	# Lily pads and blooms on the pond (JapanVillage._south: water 7.8 x 5.8 m).
	var pads: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	for i in count(12.0, 4):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.82
		var p := Vector3(JapanVillage.POND.x + cos(a) * r * 7.0, 0.09, JapanVillage.POND.z + sin(a) * r * 5.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, 1, 1) * rng.randf_range(0.5, 0.8)), p)
		(blooms if i % 3 == 0 else pads).append(xf)
	place(h, "lily", pads, [], 45.0)
	place(h, "lily_bloom", blooms, [], 45.0)


## Every collider under `root` as a flat footprint: [inverse transform, half size
## (x, z)] (cylinders and spheres as their square).
static func _collider_boxes(root: Node3D) -> Array:
	var out: Array = []
	for node in root.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		var xf := Transform3D.IDENTITY
		var n: Node = cs
		while n != null and n != root.get_parent():
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var half := Vector2(0.6, 0.6)
		if cs.shape is BoxShape3D:
			var size := (cs.shape as BoxShape3D).size
			half = Vector2(size.x, size.z) * 0.5
		elif cs.shape is CylinderShape3D:
			half = Vector2.ONE * (cs.shape as CylinderShape3D).radius
		elif cs.shape is SphereShape3D:
			half = Vector2.ONE * (cs.shape as SphereShape3D).radius
		out.append([xf.affine_inverse(), half])
	return out


## True when the flat point keeps `margin` off every footprint of [method _collider_boxes].
static func clear_of_boxes(p: Vector2, margin: float, boxes: Array) -> bool:
	for box in boxes:
		var local: Vector3 = (box[0] as Transform3D) * Vector3(p.x, 0.5, p.y)
		var half: Vector2 = box[1]
		if absf(local.x) < half.x + margin and absf(local.z) < half.y + margin:
			return false
	return true


# ---------------------------------------------------------------------------
# The guild war's castle
# ---------------------------------------------------------------------------

## Grass, flowers and bushes over the siege field; torches, weapon racks and banners in
## each guild's colour along its camp road and round its curtain; torches along the
## castle yards' walls and the throne room. Off the camps, roads, the plaza, the moat,
## the bridge, the gates' approaches, the switch circle and the altar.
static func siege(root: Node3D, colors: Array, camps: int) -> void:
	var S := SiegeArena
	# Its own stream of numbers: the match's rng is left as it was.
	var rng := RandomNumberGenerator.new()
	rng.seed = 41017
	var h := holder(root)
	var blocked := siege_exclusions(camps)
	# Foliage on the open field (south of the moat only).
	var habitat := FastNoiseLite.new()
	habitat.seed = 41
	habitat.frequency = 0.05
	Scenery._grows = func(p: Vector2) -> bool: return p.y > S.MOAT_SOUTH + 4.0
	var occupied: Array[Vector3] = blocked.duplicate()
	# Grass tufts only (one shared mesh per chunk; the field is twice a hunting field's
	# size, so a second pass at quality 2), the one-mesh wildflowers and round shrubs:
	# the multi-model Quaternius bushes and plants would cost a draw per model per chunk.
	for i in (2 if _q() >= 2 else 1):
		Scenery._grass(h, &"meadow", rng, S.RADIUS - 4.0, occupied, habitat, false)
	flower_drifts(h, rng, S.RADIUS - 4.0, occupied, count(60.0, 12))
	var shrubs: Array[Transform3D] = []
	var shrub_tints: Array[Color] = []
	_scatter(rng, S.RADIUS - 6.0, occupied, count(45.0, 10), 1.0, func(p: Vector2) -> void:
		shrubs.append(_yaw(rng, Vector3(1, 0.9, 1) * rng.randf_range(0.8, 1.5), Vector3(p.x, 0, p.y)))
		shrub_tints.append(Color.WHITE.lerp(Color("c8e0a0"), rng.randf())))
	place(h, "bush_ball", shrubs, shrub_tints, 60.0)
	Scenery._grows = Callable()
	var torches: Array[Transform3D] = []
	var racks: Array[Transform3D] = []
	var banners: Array[Transform3D] = []
	var banner_tints: Array[Color] = []
	for team in camps:
		var c := S.camp(team)
		var fwd := S.camp_forward(team)
		var side := Vector3(-fwd.z, 0, fwd.x)
		var color: Color = colors[team] if team < colors.size() and colors[team] is Color else Color.WHITE
		# Torches either side of the curtain's opening, racks behind the curtain.
		for s in [-1.0, 1.0]:
			torches.append(Transform3D(Basis(), c + fwd * 21.0 + side * s * 9.0))
			for k in 2:
				var at: Vector3 = c - fwd * 21.5 + side * s * (4.0 + float(k) * 6.0)
				racks.append(Transform3D(Basis(Vector3.UP, atan2(-fwd.x, -fwd.z) + PI), at))
		# Banners in the guild's colour lining its road to the bridge.
		var road_end := Vector3(-S.LANE_X if c.x < 0.0 else S.LANE_X, 0, S.MOAT_SOUTH)
		var mid := Vector3(c.x * 0.45 + road_end.x * 0.55, 0, c.z * 0.35 + S.PLAZA.z * 0.65)
		for seg in [[c, mid], [mid, road_end]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var length := a.distance_to(b)
			var dir := (b - a) / maxf(length, 0.01)
			var across := Vector3(-dir.z, 0, dir.x)
			var spacing: float = [28.0, 16.0, 12.0][_q()]
			var t := 26.0 if seg[0] == c else 6.0
			while t < length - 6.0:
				for s in [-1.0, 1.0]:
					var at: Vector3 = a + dir * t + across * s * 6.5
					var flat := Vector2(at.x, at.z)
					if is_free(flat, 0.5, blocked) and at.z > S.MOAT_SOUTH + 4.0:
						banners.append(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z) + PI * 0.5), at))
						banner_tints.append(color)
				t += spacing
	# Torches along the castle yards' side walls, between the tall stone lanterns
	# (SiegeArena._castle puts those at 0.15, 0.38, 0.62 and 0.85 of each yard).
	var yard_marks: Array = [[0.5], [0.265, 0.735], [0.265, 0.5, 0.735]][_q()]
	for k in 2:
		for f in yard_marks:
			var z: float = S.GATE_Z[k] - S.GATE_GAP * float(f)
			for s in [-1.0, 1.0]:
				torches.append(Transform3D(Basis(), Vector3(s * (S.HALL_HALF - 1.2), 0, z)))
		if k == 1:
			for s in [-1.0, 1.0]:
				racks.append(Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * (S.HALL_HALF - 1.4), 0, S.GATE_Z[k] - S.GATE_GAP * 0.62 + 2.6)))
	# The throne room: torches between the pillar rows' pillars (x = 0.62 THRONE_HALF).
	for i in 6:
		if _q() == 0 and i % 2 == 1:
			continue
		var z: float = S.GATE_Z[2] - 5.0 - (float(i) + 0.5) * (S.THRONE_DEPTH - 9.0) / 6.0
		for s in [-1.0, 1.0]:
			torches.append(Transform3D(Basis(), Vector3(s * S.THRONE_HALF * 0.62, 0, z)))
	for s in [-1.0, 1.0]:
		racks.append(Transform3D(Basis(Vector3.UP, -s * PI * 0.5), Vector3(s * (S.THRONE_HALF - 1.6), 0, S.BACK_Z + 8.0)))
	# Drop anything that landed in an exclusion circle (the gates' approaches, the switch,
	# the altar, the keep camp).
	torches = _keep_free(torches, blocked, 0.4)
	for i in torches.size():
		torches[i] = Transform3D(Basis().scaled(Vector3.ONE * 1.35), torches[i].origin)
	racks = _keep_free(racks, blocked, 1.0)
	place(h, "torch", torches, [], 90.0)
	place(h, "weapon_rack", racks, [], 60.0)
	place(h, "war_banner", banners, banner_tints, 90.0)


static func _keep_free(list: Array[Transform3D], blocked: Array[Vector3], r: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for xf in list:
		if is_free(Vector2(xf.origin.x, xf.origin.z), r, blocked):
			out.append(xf)
	return out


## The guild war's no-prop circles (x, z, r): every camp and its road, the plaza, the
## bridge foot, the gates' approaches (both sides), the keep camp, the switch circle
## and the altar.
static func siege_exclusions(camps: int) -> Array[Vector3]:
	var S := SiegeArena
	var out: Array[Vector3] = []
	out.append(Vector3(S.PLAZA.x, S.PLAZA.z, 18.0))
	out.append(Vector3(S.APPROACH.x, S.APPROACH.z, S.BRIDGE_HALF + 4.0))
	for team in maxi(camps, S.CAMPS.size()):
		var c := S.camp(team)
		out.append(Vector3(c.x, c.z, 20.0))
		var lane_x := -S.LANE_X if c.x < 0.0 else S.LANE_X
		var pts := [Vector2(c.x, c.z), Vector2(c.x * 0.45 + lane_x * 0.55, c.z * 0.35 + S.PLAZA.z * 0.65), Vector2(lane_x, S.MOAT_SOUTH)]
		for i in 2:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := int(a.distance_to(b) / 3.0) + 1
			for k in steps + 1:
				var p := a.lerp(b, float(k) / float(steps))
				out.append(Vector3(p.x, p.y, 5.0))
	for tier in S.GATE_Z.size():
		for lane in S.TIER_LANES[tier]:
			var x := S.gate_x(tier, lane)
			for dz in [-5.0, 0.0, 5.0]:
				out.append(Vector3(x, S.GATE_Z[tier] + dz, S.GATE_HALF + 3.0))
	out.append(Vector3(S.KEEP_CAMP.x, S.KEEP_CAMP.z, 10.0))
	out.append(Vector3(S.SWITCH.x, S.SWITCH.z, S.SWITCH_RADIUS + 3.0))
	out.append(Vector3(S.ALTAR.x, S.ALTAR.z, S.ALTAR_RADIUS + 5.0))
	return out


# ---------------------------------------------------------------------------
# Star fields (into StarRegionArt's shared batches)
# ---------------------------------------------------------------------------

## Lotus Sanctum: fallen petals over the garden, lily pads and buds on the mirror
## pools, small wayside shrines and stone lanterns beside the paths. `c` is the build
## context of DivineRegionArt; placements keep off its paths, camps and spawn/boss.
static func lotus(c: Dictionary) -> void:
	var D := DivineRegionArt
	var rng := RandomNumberGenerator.new()
	rng.seed = 51733
	for i in count(260.0, 60):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 52.0
		var p := Vector3(cos(a) * r, 0.03, sin(a) * r)
		if not D._clear(p, -2.0):
			continue
		var s := rng.randf_range(0.16, 0.28)
		var col := D.ROSE.lerp(Color("fff0f4"), rng.randf() * 0.7)
		StarRegionArt._queue(c, "divine_petal", Transform3D(Basis.from_euler(Vector3(PI * 0.5 + rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0)) * Basis.from_scale(Vector3(s, s * 1.6, s)), p), col, "solid")
	for pool in [Vector3(-34, 0, 1), Vector3(35, 0, 3), Vector3(-17, 0, -37), Vector3(18, 0, -37)]:
		for i in count(6.0, 2):
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * 0.75
			var p: Vector3 = pool + Vector3(cos(a) * r * 5.2, 0.05, sin(a) * r * 3.3)
			var s := rng.randf_range(0.7, 1.1)
			StarRegionArt._put(c, "disc", p, Vector3(s, 1.0, s * 0.9), Color("6f9a7a"), Vector3(0, a, 0))
			if i % 3 == 0:
				D._lotus(c, p + Vector3(0, 0.02, 0), 0.35, D.ROSE.lerp(D.IVORY, rng.randf() * 0.5))
	# Wayside shrines and stone lanterns, a short way off the paths.
	var info := D.layout()
	var placed := 0
	var want := count(14.0, 4)
	var tries := 0
	while placed < want and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 48.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var xz := Vector2(p.x, p.z)
		var d := StarRegionArt._path_distance(xz, info.paths)
		if d < 5.2 or d > 7.5 or not D._clear(p, 1.0):
			continue
		placed += 1
		if placed % 2 == 0:
			_lotus_lantern(c, p)
		else:
			_lotus_hokora(c, p, a)


static func _lotus_lantern(c: Dictionary, p: Vector3) -> void:
	var D := DivineRegionArt
	StarRegionArt._put(c, "box", p + Vector3(0, 0.12, 0), Vector3(0.7, 0.24, 0.7), D.IVORY.darkened(0.08))
	StarRegionArt._put(c, "pillar", p + Vector3(0, 0.6, 0), Vector3(0.22, 0.8, 0.22), D.IVORY)
	StarRegionArt._put(c, "box", p + Vector3(0, 1.05, 0), Vector3(0.6, 0.1, 0.6), D.GOLD)
	StarRegionArt._put(c, "crystal", p + Vector3(0, 1.32, 0), Vector3(0.3, 0.45, 0.3), Color("ffe9c0"), Vector3.ZERO, "glow")
	StarRegionArt._put(c, "roof", p + Vector3(0, 1.7, 0), Vector3(0.8, 0.32, 0.8), D.JADE.darkened(0.15))


static func _lotus_hokora(c: Dictionary, p: Vector3, yaw: float) -> void:
	var D := DivineRegionArt
	StarRegionArt._put(c, "box", p + Vector3(0, 0.15, 0), Vector3(1.3, 0.3, 1.0), D.IVORY.darkened(0.1), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "box", p + Vector3(0, 0.75, 0), Vector3(0.8, 0.9, 0.6), D.ROSE.darkened(0.25), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "roof", p + Vector3(0, 1.4, 0), Vector3(1.2, 0.45, 0.95), D.JADE.darkened(0.2), Vector3(0, yaw, 0))
	StarRegionArt._put(c, "crystal", p + Vector3(0, 1.78, 0), Vector3(0.14, 0.26, 0.14), D.GOLD, Vector3.ZERO, "glow")
	D._lotus(c, p + Vector3(0, 0.3, 0) + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.55), 0.28, D.ROSE)


## Drowned Abyss: scattered shells, starfish, small glowing coral and sea-grass tufts
## between the camps and paths (DrownedAbyssArt._clear).
static func abyss(c: Dictionary) -> void:
	var A := DrownedAbyssArt
	_register_sea_shapes()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var shell_cols := [Color("f2d8c8"), Color("e8b8a8"), Color("f4ecd8"), Color("d8c0e8")]
	var star_cols := [Color("ff8a6a"), Color("f0b050"), Color("e85a7a"), Color("b08aff")]
	for i in count(150.0, 40):
		var a := rng.randf() * TAU
		var r := 6.0 + sqrt(rng.randf()) * 47.0
		var p := Vector3(cos(a) * r, 0.02, sin(a) * r)
		if not A._clear(p, 0.4):
			continue
		match i % 5:
			0, 1:
				var s := rng.randf_range(0.4, 0.75)
				StarRegionArt._queue(c, "sea_shell", Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0)) * Basis.from_scale(Vector3.ONE * s), p), shell_cols[i % shell_cols.size()], "solid")
			2:
				var s := rng.randf_range(0.5, 0.85)
				StarRegionArt._queue(c, "starfish", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s), p), star_cols[i % star_cols.size()], "solid")
			3:
				# A tuft of sea grass (the kelp's frond, small).
				for k in 3:
					var off := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
					var hgt := rng.randf_range(0.6, 1.2)
					StarRegionArt._put(c, "willow_frond", p + off + Vector3(0, hgt * 0.5, 0), Vector3(0.14, hgt * 0.5, 0.14), A.KELP.lerp(Color("6fd8a0"), rng.randf() * 0.4),
						Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25)), "foliage")
			4:
				# A little glowing coral sprig.
				var col: Color = A.CORAL.lerp(A.VIOLET, rng.randf())
				for k in 3:
					var ang := rng.randf() * TAU
					var tip := p + Vector3(cos(ang) * 0.2, rng.randf_range(0.35, 0.6), sin(ang) * 0.2)
					StarRegionArt._segment(c, p, tip, 0.04, col.darkened(0.2))
					StarRegionArt._put(c, "crystal", tip, Vector3(0.1, 0.18, 0.1), col.lightened(0.25), Vector3(0, ang, 0), "glow")


## Registers the shell and starfish meshes in StarRegionArt's shared shape cache.
static func _register_sea_shapes() -> void:
	if not StarRegionArt._meshes.has("sea_shell"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# A scallop: a fan of ridged wedges, raised at the middle, a hinge at the back.
		var ribs := 9
		for i in ribs:
			var a0 := lerpf(-1.1, 1.1, float(i) / float(ribs))
			var a1 := lerpf(-1.1, 1.1, float(i + 1) / float(ribs))
			var hinge := Vector3(0, 0.05, -0.45)
			var p0 := Vector3(sin(a0) * 0.55, 0.12 + cos(a0) * 0.1, -0.45 + cos(a0) * 0.9)
			var p1 := Vector3(sin(a1) * 0.55, 0.12 + cos(a1) * 0.1, -0.45 + cos(a1) * 0.9)
			var ridge := (p0 + p1) * 0.5 + Vector3(0, 0.08, 0)
			var light := Color.WHITE if i % 2 == 0 else Color(0.88, 0.85, 0.85)
			StarRegionArt._triangle(st, hinge, ridge, p0, light, light, light)
			StarRegionArt._triangle(st, hinge, p1, ridge, light, light, light)
			StarRegionArt._triangle(st, Vector3(p0.x, 0, p0.z), p0, ridge)
			StarRegionArt._triangle(st, Vector3(p1.x, 0, p1.z), ridge, p1)
		StarRegionArt._triangle(st, Vector3(-0.14, 0.02, -0.5), Vector3(0.14, 0.02, -0.5), Vector3(0, 0.08, -0.4), Color(0.8, 0.78, 0.78), Color(0.8, 0.78, 0.78), Color(0.8, 0.78, 0.78))
		st.generate_normals()
		st.index()
		StarRegionArt._meshes["sea_shell"] = st.commit()
	if not StarRegionArt._meshes.has("starfish"):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := Vector3(0, 0.16, 0)
		for i in 5:
			var a := float(i) * TAU / 5.0
			var tip := Vector3(cos(a) * 0.55, 0.03, sin(a) * 0.55)
			var l := Vector3(cos(a - 0.62) * 0.18, 0.05, sin(a - 0.62) * 0.18)
			var r := Vector3(cos(a + 0.62) * 0.18, 0.05, sin(a + 0.62) * 0.18)
			var spot := Color(1.0, 0.92, 0.85)
			StarRegionArt._triangle(st, top, r, tip, Color.WHITE, Color.WHITE, spot)
			StarRegionArt._triangle(st, top, tip, l, Color.WHITE, spot, Color.WHITE)
		st.generate_normals()
		st.index()
		StarRegionArt._meshes["starfish"] = st.commit()
