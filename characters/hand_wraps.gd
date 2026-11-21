class_name HandWraps
extends RefCounted
## The Muay Thai fighter's hand wraps (ผ้าพันมือ / นวมประเจียด): worn on both fists
## (HeroVisual holds the same look in each hand). Built in code from a few shared
## low-poly meshes, cheap on a phone: a wrapped fist (a capsule round the hand slot),
## two cloth bands, and from the higher tiers a gold knuckle guard, a mantra band at
## the wrist and (Lv.90+, star, set, divine, dragon) a soft glow. Every look kind is
## handled here so the weapon reads the same whoever draws it:
##   wraps_<0-9>                the ten gear tiers (ItemData)
##   star_wraps_<50..200>       star gear (StarGearData)
##   set_wraps_muaythai         the 250-star class set (SetGearData)
##   divine_wraps_muaythai_200  the divine weapon (DivineGearData)
##   dragon_wraps_muaythai      the Dragon God weapon (DragonGearData)
## Model convention: the grip (the hand slot, where a held handle would pass through the
## closed fingers) at the origin, as a RIGHT fist sits in the grip space every rig shares
## (HeroVisual's slot fix lines the chibi slots up with KayKit's): the forearm runs to
## -X (the wrist at about (-0.063, 0, 0.038) on the original chibi boy), the fingers'
## striking face looks +X, the knuckles stack along Y and the back of the hand faces +Z.
## The tape circles the hand's own axis (X), so it wraps hand and wrist. HeroVisual
## mirrors it for the left fist and sizes it to each body's hand (fit).

const KIND := "wraps"
## Cloth / band / accent colours of the ten tiers (plain cotton to god-gold fire).
const TIERS := [
	[Color("efe6d2"), Color("b8a27a"), Color("8a6a40")],
	[Color("f4ecd8"), Color("c0392b"), Color("8a6a40")],
	[Color("e8d6b0"), Color("2b5ea8"), Color("c9a44a")],
	[Color("f2e2c0"), Color("d35400"), Color("d6b25a")],
	[Color("3a2a22"), Color("e74c3c"), Color("f0c050")],
	[Color("d8f0ff"), Color("4aa8e8"), Color("e0e8f0")],
	[Color("2a1f3a"), Color("8a4dff"), Color("d0b0ff")],
	[Color("fff6dc"), Color("f0c040"), Color("fff0a0")],
	[Color("1e2a4a"), Color("ffd84a"), Color("8fd8ff")],
	[Color("fff0c8"), Color("ff8a2a"), Color("ffd84a")],
]

## The hand's middle in the grip space (the tape's centre line), its half-height (across
## the knuckles, Y) and half-thickness (palm to back, Z) on the reference hand, and the
## wrist's radius.
const HAND_CENTRE := Vector3(-0.062, -0.018, 0.028)
const HAND_RY := 0.088
const HAND_RZ := 0.058
const WRIST_R := 0.05
## The knuckle guard over the striking face of the fingers.
const KNUCKLES := Vector3(-0.004, -0.018, 0.02)
## The reference hand: the distance from the grip to the hand bone's root (the chibi
## boy's RightHand) that the pieces are authored for.
const REF_HAND := 0.0735
## Where the tape's centre sits from the hand bone's root (reference hand units).
const CHIBI_FIST := Vector3(0.0, -0.018, -0.01)
const KAYKIT_FIST := Vector3(0.03, 0.0, -0.02)

static var _fist: CapsuleMesh
static var _band: TorusMesh
static var _plate: BoxMesh
static var _mats := {}


static func is_look(look: String) -> bool:
	return StarGearData.kind_from_look(look) == KIND


## [cloth, band, accent, glow (0 none)] for a look.
static func palette(look: String) -> Array:
	if look.begins_with("star_"):
		var stars := StarGearData.stars_from_look(look)
		var p := StarGearData.palette(stars, "muaythai")
		return [p.cloth, p.metal, p.gem, 0.6 + float(stars) / 200.0]
	if look.begins_with("divine_"):
		return [Color("fff8e8"), Color("ffc24a"), Color("ff7a1a"), 1.6]
	if look.begins_with("set_"):
		var s: Dictionary = SetGearData.PALETTES.get("muaythai", SetGearData.PALETTES.warrior)
		return [s.cloth, s.metal, s.glow, 1.2]
	if look.begins_with("dragon_"):
		return [Color("0f3a30"), Color("2fd8a0"), Color("ffd84a"), 1.3]
	var tier := clampi(int(look.rsplit("_", true, 1)[-1]), 0, TIERS.size() - 1)
	var row: Array = TIERS[tier]
	return [row[0], row[1], row[2], 0.0 if tier < 8 else 0.8 + 0.4 * float(tier - 8)]


## How grand a look is (0 plain .. 3 the top weapons): more pieces as it rises.
static func grade(look: String) -> int:
	if look.begins_with("divine_") or look.begins_with("dragon_") or look.begins_with("set_"):
		return 3
	if look.begins_with("star_"):
		return 2 if StarGearData.stars_from_look(look) < 150 else 3
	var tier := int(look.rsplit("_", true, 1)[-1])
	return 0 if tier < 3 else (1 if tier < 6 else 2)


static func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _meshes() -> void:
	if _fist != null:
		return
	_fist = CapsuleMesh.new()
	_fist.radius = 0.062
	_fist.height = 0.17
	_fist.radial_segments = 8
	_fist.rings = 2
	_band = TorusMesh.new()
	_band.inner_radius = 0.058
	_band.outer_radius = 0.072
	_band.rings = 16
	_band.ring_segments = 4
	_plate = BoxMesh.new()
	_plate.size = Vector3(0.05, 0.15, 0.035)


## One turn of tape at [param x] along the hand: the band mesh (a ring round Y, radius
## about 0.065) laid round X, stretched to the half-sizes [param ry] x [param rz], its
## tape [param thick] times the mesh's width.
static func _turn(x: float, ry: float, rz: float, thick: float, centre := HAND_CENTRE) -> Transform3D:
	var r := 0.065
	# Ring X -> -Y, ring axis Y -> X, ring Z -> Z (a proper turn, no mirror).
	var basis := Basis(Vector3(0, -ry / r, 0), Vector3(thick, 0, 0), Vector3(0, 0, rz / r))
	return Transform3D(basis, Vector3(x, centre.y, centre.z))


## Fits a built wraps [param root] (build / DragonGearArt) to a hand: [param hand] is the
## hand bone's root in the grip space as for a right hand (HeroVisual._hand_in_grip),
## [param left] mirrors it. The tape is sized to the hand (its distance from the grip
## against REF_HAND) and centred on the hand's root, where every chibi body's fist sits
## (a little toward the palm); KayKit's round mitt sits further out (kaykit).
static func fit(root: Node3D, hand: Vector3, left: bool, kaykit := false) -> void:
	var k := clampf(hand.length() / REF_HAND, 0.5, 3.0) if hand != Vector3.ZERO else 1.0
	var at := Vector3.ZERO
	if hand != Vector3.ZERO:
		var want := hand + (KAYKIT_FIST if kaykit else CHIBI_FIST) * k
		at = want - HAND_CENTRE * k
	var flip := Vector3(-1, 1, 1) if left else Vector3.ONE
	root.transform = Transform3D(Basis.from_scale(Vector3.ONE * k * flip), at * flip)


## Each look's wrapped fist baked into ONE mesh (a surface per material), cached: a fist
## is then a single MeshInstance3D, so a crowd of fighters stays inside the phone's node
## budget (phone_budget_test).
static var _baked := {}


static func _bake(look: String) -> ArrayMesh:
	if _baked.has(look):
		return _baked[look]
	_meshes()
	var colors := palette(look)
	var level := grade(look)
	var glow := float(colors[3])
	# [mesh, material, transform] of every piece, as the look stacks them.
	var parts: Array = []
	# The tape wound round the hand: three cloth turns from the wrist to the knuckles and
	# two coloured bands between them, each circling the hand's own axis (X).
	for x in [-0.092, -0.062, -0.032]:
		parts.append([_band, _material(colors[0]), _turn(x, HAND_RY, HAND_RZ, 2.2)])
	for x in [-0.077, -0.047]:
		parts.append([_band, _material(colors[1], glow * 0.5), _turn(x, HAND_RY * 1.04, HAND_RZ * 1.06, 1.1)])
	# Two turns round the wrist, where the tape starts.
	parts.append([_band, _material(colors[0]), _turn(-0.122, WRIST_R, WRIST_R, 2.2, Vector3(0, 0, 0.034))])
	parts.append([_band, _material(colors[0]), _turn(-0.147, WRIST_R * 0.96, WRIST_R * 0.96, 2.2, Vector3(0, 0, 0.034))])
	if level >= 1:
		# The knuckle guard over the fist's striking face.
		parts.append([_plate, _material(colors[2], glow * 0.6), Transform3D(Basis.from_scale(Vector3(0.5, 1.07, 2.0)), KNUCKLES)])
	if level >= 2:
		# The mantra band (ประเจียด) round the wrist.
		parts.append([_band, _material(colors[2], maxf(glow, 0.5)), _turn(-0.135, WRIST_R * 1.12, WRIST_R * 1.12, 1.4, Vector3(0, 0, 0.034))])
	if level >= 3:
		# A ring of light round the knuckles (the top weapons).
		parts.append([_band, _material(colors[1], maxf(glow, 1.2)), _turn(-0.014, HAND_RY * 1.18, HAND_RZ * 1.25, 0.7)])
	# One surface per material: pieces sharing a material share a surface.
	var tools := {}
	var order: Array = []
	for part in parts:
		var mat: Material = part[1]
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


## The wrapped fist of [param look]: a root (named after the look) holding one model node
## (a single baked mesh, see _bake).
static func build(look: String) -> Node3D:
	var root := Node3D.new()
	root.name = look
	var model := MeshInstance3D.new()
	model.name = "Wraps"
	model.mesh = _bake(look)
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(model)
	return root
