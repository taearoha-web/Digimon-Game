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
## Model convention (WeaponKit): the grip (the middle of the fist) at the origin, the
## fist's long axis (the line a held handle would take) along +Y.

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
	_band.rings = 10
	_band.ring_segments = 4
	_plate = BoxMesh.new()
	_plate.size = Vector3(0.05, 0.15, 0.035)


static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, rot := Vector3.ZERO, size := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	mi.rotation = rot
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The wrapped fist of [param look]: a root (named after the look) holding one model node.
static func build(look: String) -> Node3D:
	_meshes()
	var colors := palette(look)
	var level := grade(look)
	var glow := float(colors[3])
	var root := Node3D.new()
	root.name = look
	var model := Node3D.new()
	model.name = "Wraps"
	root.add_child(model)
	# The tape wound round the fist: three cloth turns and two coloured bands, round the
	# fist itself (the hand slot's axis), so the hand shows through between them.
	for y in [-0.05, 0.0, 0.05]:
		_part(model, _band, _material(colors[0]), Vector3(0, y, 0), Vector3.ZERO, Vector3(1.0, 1.4, 1.0))
	for y in [-0.025, 0.025]:
		_part(model, _band, _material(colors[1], glow * 0.5), Vector3(0, y, 0), Vector3.ZERO, Vector3(1.04, 0.8, 1.04))
	if level >= 1:
		# The knuckle guard over the front of the fist.
		_part(model, _plate, _material(colors[2], glow * 0.6), Vector3(0, 0, 0.058))
	if level >= 2:
		# The mantra band (ประเจียด) round the wrist, a little below the fist.
		_part(model, _band, _material(colors[2], maxf(glow, 0.5)), Vector3(0, -0.1, 0), Vector3.ZERO, Vector3(1.12, 1.6, 1.12))
	if level >= 3:
		# A ring of light round the knuckles (the top weapons).
		_part(model, _band, _material(colors[1], maxf(glow, 1.2)), Vector3(0, 0.0, 0.0), Vector3(PI * 0.5, 0, 0), Vector3(1.35, 1.0, 1.35))
	return root
