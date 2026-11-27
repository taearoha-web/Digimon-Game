class_name HandWraps
extends RefCounted
## The Muay Thai fighter's knuckle dusters (สนับมือ): worn on both fists (HeroVisual holds
## the same look in each hand). The weapon kind stays "wraps" inside the game (saved
## items, looks, icons) though the art is a pair of knuckle dusters now: a metal knuckle
## bar across the striking face with four finger rings behind it, a palm grip joined to
## the ends of the bar, rising in grandeur by tier: plain iron and steel with a grip
## bound in the tier's colour (Lv.1-30), studded steel (Lv.31-60), gold with set gems
## (Lv.61-100), and for the top weapons (Lv.91-100, star 150+, set, divine) glowing inlays down the
## bar, a crest of blades at its top end and a line of mantra script (ประเจียด) along it.
## Every look kind is handled here so the weapon reads the same whoever draws it:
##   wraps_<0-9>                the ten gear tiers (ItemData)
##   star_wraps_<50..200>       star gear (StarGearData)
##   set_wraps_muaythai         the 250-star class set (SetGearData)
##   divine_wraps_muaythai_200  the divine weapon (DivineGearData)
##   dragon_wraps_muaythai      the Dragon God weapon (DragonGearData), built by
##                              DragonGearArt (jade-and-gold dusters from pieces, the
##                              dragon rearing its head over the knuckles) in this layout
## Model convention: the grip (the hand slot, where a held handle would pass through the
## closed fingers) at the origin, as a RIGHT fist sits in the grip space every rig shares
## (HeroVisual's slot fix lines the chibi slots up with KayKit's): the forearm runs to
## -X (the wrist at about (-0.063, 0, 0.038) on the original chibi boy), the fingers'
## striking face looks +X, the knuckles stack along Y and the back of the hand faces +Z.
## The finger rings stand along that knuckle line (one per finger, the finger through
## each along Z) and the bar rides in front of them. HeroVisual mirrors the piece for the
## left fist and sizes it to each body's hand (fit).

const KIND := "wraps"
## [metal, accent (the grip binding, trims), gem / stud] of the ten tiers: iron, steel
## and blued steel; studded steel (fire, onyx, ice); gold with gems (shadow, holy,
## lightning, the god of boxing).
const TIERS := [
	[Color("7d8187"), Color("8a6a40"), Color("9a9ea4")],
	[Color("a3abb4"), Color("c0392b"), Color("c9ced4")],
	[Color("7f97b0"), Color("2b5ea8"), Color("cfdbe8")],
	[Color("b8bfc7"), Color("d35400"), Color("f0c050")],
	[Color("3b3b42"), Color("e74c3c"), Color("f0c050")],
	[Color("d6eaf6"), Color("4aa8e8"), Color("8fe0ff")],
	[Color("c9a44a"), Color("2a1f3a"), Color("9a5dff")],
	[Color("f0c040"), Color("fff6dc"), Color("f4fbff")],
	[Color("ffd84a"), Color("1e2a4a"), Color("8fd8ff")],
	[Color("ffcf3a"), Color("a8300f"), Color("ff3a2a")],
]

## The hand's middle in the grip space (the fist's centre line), its half-height (across
## the knuckles, Y) and half-thickness (palm to back, Z) on the reference hand, and the
## wrist's radius. fit centres the hand here; the tests measure the fit from it.
const HAND_CENTRE := Vector3(-0.062, -0.018, 0.028)
const HAND_RY := 0.088
const HAND_RZ := 0.058
const WRIST_R := 0.05
## The middle of the knuckle bar on the striking face.
const KNUCKLES := Vector3(-0.014, -0.016, -0.008)
## The four finger rings' spacing along the knuckle line (Y) and their centre behind
## the bar (X; the ring's front edge runs inside the bar).
const RING_STEP := 0.045
const RING_X := KNUCKLES.x - 0.024
## The palm grip's middle (in the palm, behind the curled fingers).
const GRIP := KNUCKLES + Vector3(-0.052, 0.0, -0.03)
## The reference hand: the distance from the grip to the hand bone's root (the chibi
## boy's RightHand) that the pieces are authored for.
const REF_HAND := 0.0735
## Where the fist's centre sits from the hand bone's root (reference hand units).
const CHIBI_FIST := Vector3(0.0, -0.018, -0.01)
const KAYKIT_FIST := Vector3(0.05, 0.0, -0.01)
## KayKit's round mitt is bigger than a chibi fist: the dusters grow to cover it.
const KAYKIT_SIZE := 1.25
## The icon's turn: the bar on top, the four rings in a row facing out, the grip below,
## turned a little to show the bar's depth (every icon path: tier, star, set, divine,
## dragon).
const ICON_ROTATION := Vector3(0, 28, 90)

static var _ring: TorusMesh
static var _bump: CylinderMesh
static var _plate: BoxMesh
static var _grip: CapsuleMesh
static var _stud: CylinderMesh
static var _gem: SphereMesh
static var _blade: CylinderMesh
static var _mats := {}


static func is_look(look: String) -> bool:
	return StarGearData.kind_from_look(look) == KIND


## [metal, accent, gem, glow (0 none)] for a look.
static func palette(look: String) -> Array:
	if look.begins_with("star_"):
		var stars := StarGearData.stars_from_look(look)
		var p := StarGearData.palette(stars, "muaythai")
		return [p.metal, p.cloth, p.gem, 0.6 + float(stars) / 200.0]
	if look.begins_with("divine_"):
		return [Color("ffd24a"), Color("fff8e8"), Color("ff7a1a"), 1.6]
	if look.begins_with("set_"):
		var s: Dictionary = SetGearData.PALETTES.get("muaythai", SetGearData.PALETTES.warrior)
		return [s.metal, s.cloth, s.glow, 1.2]
	if look.begins_with("dragon_"):
		return [DragonGearData.GOLD, DragonGearData.JADE_DEEP, DragonGearData.GLOW, 1.3]
	# The ★500 set's (Star500Gear): celestial gold over pearl, in the class's fire.
	if look.begins_with("heaven_"):
		return [Star500Gear.GOLD, Star500Gear.PEARL, Color("ffb04a"), 1.5]
	var tier := clampi(int(look.rsplit("_", true, 1)[-1]), 0, TIERS.size() - 1)
	var row: Array = TIERS[tier]
	return [row[0], row[1], row[2], 0.0 if tier < 8 else 0.8 + 0.4 * float(tier - 8)]


## How grand a look is (0 plain .. 3 the top weapons): more pieces as it rises.
static func grade(look: String) -> int:
	if look.begins_with("divine_") or look.begins_with("dragon_") or look.begins_with("set_") or look.begins_with("heaven_"):
		return 3
	if look.begins_with("star_"):
		return 2 if StarGearData.stars_from_look(look) < 150 else 3
	var tier := int(look.rsplit("_", true, 1)[-1])
	# The god of boxing's (Lv.91-100) already carries the top weapons' inlays and crest.
	return 0 if tier < 3 else (1 if tier < 6 else (2 if tier < 9 else 3))


static func _material(color: Color, glow := 0.0, metal := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(), glow, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.38 if metal else 0.8
		m.metallic = 0.45 if metal else 0.0
		m.metallic_specular = 0.7 if metal else 0.5
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _meshes() -> void:
	if _ring != null:
		return
	_ring = TorusMesh.new()
	_ring.inner_radius = 0.013
	_ring.outer_radius = 0.022
	_ring.rings = 12
	_ring.ring_segments = 5
	_bump = CylinderMesh.new()
	_bump.top_radius = 0.0165
	_bump.bottom_radius = 0.0165
	_bump.height = 0.05
	_bump.radial_segments = 8
	_bump.rings = 1
	_plate = BoxMesh.new()
	_plate.size = Vector3.ONE
	_grip = CapsuleMesh.new()
	_grip.radius = 0.011
	_grip.height = 0.15
	_grip.radial_segments = 6
	_grip.rings = 1
	_stud = CylinderMesh.new()
	_stud.top_radius = 0.0
	_stud.bottom_radius = 0.009
	_stud.height = 0.02
	_stud.radial_segments = 4
	_stud.rings = 0
	_gem = SphereMesh.new()
	_gem.radius = 0.5
	_gem.height = 1.0
	_gem.radial_segments = 6
	_gem.rings = 3
	_blade = CylinderMesh.new()
	_blade.top_radius = 0.0
	_blade.bottom_radius = 0.5
	_blade.height = 1.0
	_blade.radial_segments = 3
	_blade.rings = 0


## A transform laying a mesh's own Y axis along [param axis] at [param at], scaled by
## [param size] (x, y along the axis, z).
static func _along(at: Vector3, axis: Vector3, size: Vector3) -> Transform3D:
	var y := axis.normalized()
	var x := y.cross(Vector3.BACK if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x * size.x, y * size.y, z * size.z), at)


## The y of finger ring [param k] (0 the little finger's .. 3 the index's).
static func ring_y(k: int) -> float:
	return KNUCKLES.y + (float(k) - 1.5) * RING_STEP


## Every piece of the dusters as [mesh, role, transform]; role is "metal", "accent",
## "gem" or "glow" (lit). [param level] is grade's 0..3; [param studs] puts studs
## (tiers 3-5) instead of set gems on the bar.
static func pieces(level: int, studs: bool) -> Array:
	_meshes()
	var out: Array = []
	var top := ring_y(3) + RING_STEP * 0.5
	var bottom := ring_y(0) - RING_STEP * 0.5
	for k in 4:
		var y := ring_y(k)
		# The finger ring (axis Z: the finger passes through it), a flat band of metal.
		out.append([_ring, "metal", Transform3D(Basis(Vector3.RIGHT, Vector3.BACK * 2.6, Vector3.DOWN), Vector3(RING_X, y, KNUCKLES.z))])
		# Its bump on the knuckle bar (a flattened cylinder): the bar's scalloped face.
		out.append([_bump, "metal", Transform3D(Basis(Vector3.RIGHT * 0.52, Vector3.BACK, Vector3.DOWN * 1.27), Vector3(KNUCKLES.x, y, KNUCKLES.z))])
	# The web joining the rings to the bar, along the whole knuckle line.
	out.append([_plate, "metal", Transform3D(Basis.from_scale(Vector3(0.012, top - bottom - 0.006, 0.04)), Vector3(KNUCKLES.x - 0.007, KNUCKLES.y, KNUCKLES.z))])
	# The palm grip (in the palm, behind the curled fingers), bound in the accent colour,
	# and the two ends of the frame joining it to the bar.
	var grip_at := GRIP
	out.append([_grip, "accent", Transform3D(Basis.from_scale(Vector3(1.0, 1.05, 1.0)), grip_at)])
	for y in [top - 0.004, bottom + 0.004]:
		var from := Vector3(KNUCKLES.x - 0.01, y, KNUCKLES.z - 0.004)
		var to := Vector3(grip_at.x, y, grip_at.z)
		out.append([_plate, "metal", _along((from + to) * 0.5, to - from, Vector3(0.016, from.distance_to(to) + 0.012, 0.03))])
		# The grip's metal caps.
		out.append([_gem, "metal", Transform3D(Basis.from_scale(Vector3.ONE * 0.026), Vector3(grip_at.x, y, grip_at.z))])
	if level >= 1 and studs:
		# Studded steel: a pyramid stud on every knuckle.
		for k in 4:
			out.append([_stud, "gem", _along(Vector3(KNUCKLES.x + 0.019, ring_y(k), KNUCKLES.z), Vector3.RIGHT, Vector3.ONE)])
	if level >= 2 or (level >= 1 and not studs):
		# Gold with set gems: a cut stone in an accent bezel on every knuckle.
		for k in 4:
			out.append([_ring, "accent", Transform3D(Basis(Vector3.BACK * 0.72, Vector3.RIGHT * 0.5, Vector3.UP * 0.72), Vector3(KNUCKLES.x + 0.01, ring_y(k), KNUCKLES.z))])
			out.append([_gem, "gem", Transform3D(Basis.from_scale(Vector3(0.012, 0.019, 0.019)), Vector3(KNUCKLES.x + 0.011, ring_y(k), KNUCKLES.z))])
	if level >= 3:
		# Glowing inlays down the bar between the stones and on the frame's ends.
		for k in 3:
			var y := (ring_y(k) + ring_y(k + 1)) * 0.5
			out.append([_gem, "glow", Transform3D(Basis.from_scale(Vector3(0.008, 0.012, 0.036)), Vector3(KNUCKLES.x + 0.004, y, KNUCKLES.z))])
		# A crest of three blades over the bar's top end, swept toward the punch.
		for i in 3:
			var at := Vector3(KNUCKLES.x - 0.012 * i, top + 0.006, KNUCKLES.z + 0.012 * (i - 1))
			out.append([_blade, "metal", _along(at + Vector3(0.008, 0.012, 0), Vector3(0.7, 1.0, 0.1 * (i - 1)), Vector3(0.014, 0.034 - 0.006 * i, 0.007))])
		# The mantra script (ประเจียด): a line of glyph strokes of light along the top of
		# the bar (toward the back of the hand).
		for i in 9:
			var y := bottom + 0.012 + (top - bottom - 0.024) * float(i) / 8.0
			var tilt := Basis.from_euler(Vector3(0, 0, 0.55 if i % 2 == 0 else -0.35))
			out.append([_plate, "glow", Transform3D(tilt * Basis.from_scale(Vector3(0.0045, 0.012, 0.004)), Vector3(KNUCKLES.x - 0.001, y, KNUCKLES.z + 0.026))])
	return out


## Fits a built dusters [param root] (build / DragonGearArt) to a hand: [param hand] is
## the hand bone's root in the grip space as for a right hand (HeroVisual._hand_in_grip),
## [param left] mirrors it. The piece is sized to the hand (its distance from the grip
## against REF_HAND) and the fist centred on the hand's root, where every chibi body's
## fist sits (a little toward the palm); KayKit's round mitt sits further out (kaykit).
static func fit(root: Node3D, hand: Vector3, left: bool, kaykit := false) -> void:
	var k := clampf(hand.length() / REF_HAND, 0.5, 3.0) if hand != Vector3.ZERO else 1.0
	if kaykit:
		k *= KAYKIT_SIZE
	var at := Vector3.ZERO
	if hand != Vector3.ZERO:
		var want := hand + (KAYKIT_FIST if kaykit else CHIBI_FIST) * k
		at = want - HAND_CENTRE * k
	var flip := Vector3(-1, 1, 1) if left else Vector3.ONE
	root.transform = Transform3D(Basis.from_scale(Vector3.ONE * k * flip), at * flip)


## Each look's dusters baked into ONE mesh (a surface per material), cached: a fist is
## then a single MeshInstance3D, so a crowd of fighters stays inside the phone's node
## budget (phone_budget_test).
static var _baked := {}


static func _bake(look: String) -> ArrayMesh:
	if _baked.has(look):
		return _baked[look]
	var colors := palette(look)
	var level := grade(look)
	var glow := float(colors[3])
	var tier := int(look.rsplit("_", true, 1)[-1]) if look.begins_with(KIND + "_") else -1
	var roles := {
		"metal": _material(colors[0], glow * 0.15, true),
		"accent": _material(colors[1], glow * 0.3, level >= 2),
		"gem": _material(colors[2], maxf(glow, 0.35 if level >= 2 else 0.0), level == 1),
		"glow": _material(colors[2], maxf(glow, 1.2)),
	}
	# One surface per material: pieces sharing a material share a surface.
	var tools := {}
	var order: Array = []
	for part in pieces(level, tier >= 3 and tier <= 5):
		var mat: Material = roles[part[1]]
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
			order.append(mat)
		(tools[mat] as SurfaceTool).append_from(part[0], 0, part[2])
	var mesh := ArrayMesh.new()
	for mat in order:
		(tools[mat] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	_baked[look] = mesh
	return mesh


## The dusters of [param look]: a root (named after the look) holding one model node
## (a single baked mesh, see _bake).
static func build(look: String) -> Node3D:
	# The Dragon God's dusters are a dragon weapon (DragonGearArt: two surfaces, the
	# dragon over the knuckles, its pulse of light and breath), laid out in this grip space.
	if look.begins_with("dragon_"):
		return DragonGearArt.build(look)
	var root := Node3D.new()
	root.name = look
	var model := MeshInstance3D.new()
	model.name = "Knuckles"
	model.mesh = _bake(look)
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(model)
	return root
