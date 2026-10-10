class_name ChibiGear
extends RefCounted
## Armour pieces sized for the rigged chibi heroes. Every function builds into a
## node whose axes are the model's (x side, y up, z front) in chibi skeleton units
## (the whole hero is ~1 unit tall there), centred on the bone it hangs from.

## Outfit dye per gear tier (same family as the KayKit leathers and metals).
const CLOTH := [Color("8a6440"), Color("6f5236"), Color("7d8ba3"), Color("2f7a55"), Color("b8352a"),
	Color("5b3fa8"), Color("2e3a8f"), Color("e9dfc4"), Color("8f2a16"), Color("fff0b8")]


static func cloth(tier: int) -> Color:
	return CLOTH[clampi(tier, 0, CLOTH.size() - 1)]


static func _metal(tier: int) -> Color:
	return GearKit.TIERS_METAL[clampi(tier, 0, GearKit.MAX_TIER)]


static func _gem(tier: int) -> Color:
	return GearKit.GEMS[clampi(tier, 0, GearKit.MAX_TIER)]


static func _glow(tier: int) -> float:
	return 0.0 if tier < 6 else 0.3 + 0.15 * float(tier - 6)


static func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	return GearKit._p(parent, mesh, color, pos, size, rot, glow)


## Shoulder guard on the upper-arm bone (the shoulder joint). side: +1 left, -1 right.
static func pauldron(root: Node3D, tier: int, side: float) -> void:
	var color := cloth(tier) if tier < 2 else _metal(tier)
	var glow := _glow(tier)
	var grow := 1.0 + 0.06 * float(tier)
	_p(root, MeshKit.hemisphere(), color, Vector3(side * 0.012, 0.012, 0.0), Vector3(0.1, 0.07, 0.1) * grow, Vector3(0, 0, side * -18.0), glow)
	_p(root, MeshKit.torus(), color.darkened(0.25), Vector3(side * 0.012, 0.01, 0.0), Vector3(0.1, 0.04, 0.1) * grow, Vector3(0, 0, side * -18.0), glow)
	if tier >= 3:
		_p(root, MeshKit.sphere_low(), _gem(tier), Vector3(side * 0.03, 0.045, 0.03), Vector3.ONE * 0.022, Vector3.ZERO, 1.0 + glow)
	if tier >= 5:
		_p(root, MeshKit.cone(), color.lightened(0.15), Vector3(side * 0.05, 0.06, 0.0), Vector3(0.022, 0.06, 0.022), Vector3(0, 0, side * -45.0), glow)
	if tier >= 8:
		_p(root, MeshKit.prism(), Color("fff4d0"), Vector3(side * 0.06, 0.07, -0.02), Vector3(0.03, 0.09, 0.008), Vector3(0, 0, side * -60.0), 0.8)


## Chest bone: a collar strap and emblem in front, a cape on the back from tier 4.
static func chest(root: Node3D, tier: int) -> void:
	var metal := _metal(tier)
	var glow := _glow(tier)
	if tier >= 1:
		_p(root, MeshKit.torus(), cloth(tier).darkened(0.2), Vector3(0, 0.085, 0.0), Vector3(0.24, 0.05, 0.22), Vector3(12, 0, 0), glow * 0.5)
	if tier >= 2:
		_p(root, MeshKit.cylinder(), metal, Vector3(0, 0.035, 0.088), Vector3(0.05, 0.012, 0.05), Vector3(80, 0, 0), glow)
		_p(root, MeshKit.sphere_low(), _gem(tier), Vector3(0, 0.035, 0.095), Vector3(0.026, 0.026, 0.016), Vector3.ZERO, 1.0 + glow)
	if tier >= 4:
		var cape := cloth(tier).darkened(0.1)
		_p(root, MeshKit.box(), cape, Vector3(0, -0.06, -0.085), Vector3(0.2, 0.26, 0.012), Vector3(-10, 0, 0), glow * 0.4)
		_p(root, MeshKit.box(), metal, Vector3(0, 0.07, -0.075), Vector3(0.21, 0.02, 0.02), Vector3.ZERO, glow)
	if tier >= 6:
		for k in 2 + mini(tier - 6, 2):
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.prism(), Color("ffffff") if tier >= 7 else metal.lightened(0.2),
					Vector3(side * (0.06 + k * 0.025), 0.07 + k * 0.025, -0.1), Vector3(0.035, 0.13 + k * 0.02, 0.008),
					Vector3(0, 0, side * (-25.0 - k * 18.0)), 0.8 + glow)
	if tier >= 9:
		_p(root, MeshKit.torus(), Color("fff6a0"), Vector3(0, -0.02, 0), Vector3(0.36, 0.03, 0.34), Vector3.ZERO, 2.0)


## Hips bone: a belt with a buckle plate.
static func belt(root: Node3D, tier: int) -> void:
	var metal := _metal(tier)
	_p(root, MeshKit.torus(), cloth(tier).darkened(0.3), Vector3(0, 0.09, -0.005), Vector3(0.29, 0.05, 0.26), Vector3.ZERO, _glow(tier) * 0.4)
	_p(root, MeshKit.box(), metal, Vector3(0, 0.09, 0.122), Vector3(0.05, 0.04, 0.012), Vector3.ZERO, _glow(tier))


## Head bone: headband (tiers 0-1), circlet (2-3), winged circlet (4-5), crown (6-7),
## grand crown with a floating ring (8-9). Rides on the hair, never hides it.
static func headpiece(root: Node3D, tier: int) -> void:
	var metal := _metal(tier)
	var glow := _glow(tier)
	var band_y := 0.2
	if tier < 2:
		_p(root, MeshKit.torus(), cloth(tier).lightened(0.1), Vector3(0, band_y, 0.01), Vector3(0.4, 0.06, 0.38), Vector3(-8, 0, 0))
		return
	_p(root, MeshKit.torus(), metal, Vector3(0, band_y, 0.01), Vector3(0.4, 0.05, 0.38), Vector3(-8, 0, 0), glow)
	_p(root, MeshKit.sphere_low(), _gem(tier), Vector3(0, band_y + 0.02, 0.2), Vector3(0.035, 0.035, 0.02), Vector3.ZERO, 1.2 + glow)
	if tier >= 4 and tier < 6:
		for side in [-1.0, 1.0]:
			for k in 2:
				_p(root, MeshKit.prism(), Color("fff4d0"), Vector3(side * (0.2 + k * 0.012), band_y + 0.04 + k * 0.03, -0.02),
					Vector3(0.025, 0.08 - k * 0.015, 0.008), Vector3(0, 0, side * (-60.0 + k * 20.0)), 0.4)
	if tier >= 6:
		var top := band_y + 0.12
		_p(root, MeshKit.cylinder(), metal, Vector3(0, top, -0.01), Vector3(0.2, 0.035, 0.19), Vector3.ZERO, glow)
		for i in 6:
			var a := i * TAU / 6.0
			_p(root, MeshKit.cone(), metal.lightened(0.1), Vector3(cos(a) * 0.09, top + 0.035, sin(a) * 0.085 - 0.01), Vector3(0.028, 0.06 + 0.02 * (i % 2), 0.028), Vector3.ZERO, glow)
			_p(root, MeshKit.sphere_low(), GearKit.GEMS[(i + tier) % GearKit.GEMS.size()], Vector3(cos(a) * 0.1, top, sin(a) * 0.095 - 0.01), Vector3.ONE * 0.016, Vector3.ZERO, 1.0)
	if tier >= 8:
		_p(root, MeshKit.torus(), Color("ffe9a0"), Vector3(0, band_y + 0.26, -0.01), Vector3(0.18, 0.015, 0.18), Vector3.ZERO, 1.6)


## Lower-leg bone (the knee): a cuff around the top of the boot.
static func boot_cuff(root: Node3D, tier: int) -> void:
	var metal := _metal(tier)
	_p(root, MeshKit.torus(), cloth(tier).darkened(0.15), Vector3(0, -0.035, 0.0), Vector3(0.13, 0.05, 0.13), Vector3.ZERO, _glow(tier) * 0.4)
	if tier >= 2:
		_p(root, MeshKit.sphere_low(), _gem(tier), Vector3(0, -0.035, 0.065), Vector3(0.02, 0.02, 0.012), Vector3.ZERO, 1.0)
	if tier >= 5:
		for side in [-1.0, 1.0]:
			_p(root, MeshKit.prism(), metal, Vector3(side * 0.06, -0.03, -0.01), Vector3(0.012, 0.05, 0.03), Vector3(0, 0, side * -70.0), _glow(tier))


## Chest bone: a pendant hanging on the chest.
static func pendant(root: Node3D, tier: int) -> void:
	_p(root, MeshKit.torus(), _metal(tier), Vector3(0, 0.08, 0.06), Vector3(0.12, 0.02, 0.1), Vector3(35, 0, 0))
	_p(root, MeshKit.sphere_low(), _gem(tier), Vector3(0, 0.035, 0.1), Vector3.ONE * 0.025, Vector3.ZERO, 1.2)
