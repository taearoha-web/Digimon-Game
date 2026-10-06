class_name GearKit
extends RefCounted
## Procedural hats (worn on the head bone) and small trinket models used for
## icons: boots, rings, amulets. Units match the KayKit rig (head ≈ 1.1 wide,
## top of the head ≈ 1.05 above the head bone).

const HEAD_TOP := 1.0
const TIERS_METAL := [Color("b06a3a"), Color("c0c8d4"), Color("ffc93c"), Color("ff6f9a"), Color("6fe3b0"), Color("c46bff")]
const GEMS := [Color("e8e0d0"), Color("5ab8ff"), Color("ff4a5a"), Color("6fe07a"), Color("ffd23c"), Color("c46bff")]


static func _p(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var opts := {}
	if glow > 0.0:
		opts["emission"] = glow
	var mi := MeshKit.part(parent, mesh, MeshKit.toon(color, opts), pos, size, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A hat in head-bone space. proc: cap | bandana | iron | horned | crown.
static func hat(proc: String, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Hat_" + proc
	match proc:
		"cap":
			_p(root, MeshKit.hemisphere(), tint, Vector3(0, 0.66, 0), Vector3(1.28, 1.35, 1.24))
			_p(root, MeshKit.cylinder(), tint.darkened(0.2), Vector3(0, 0.7, 0.5), Vector3(0.9, 0.05, 0.55), Vector3(-8, 0, 0))
			_p(root, MeshKit.sphere_low(), tint.lightened(0.3), Vector3(0, 1.34, 0), Vector3(0.14, 0.14, 0.14))
		"bandana":
			_p(root, MeshKit.torus(), tint, Vector3(0, 0.78, 0), Vector3(1.26, 0.9, 1.2))
			_p(root, MeshKit.sphere_low(), tint, Vector3(0, 0.74, -0.6), Vector3(0.2, 0.2, 0.2))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.prism(), tint.darkened(0.15), Vector3(side * 0.08, 0.5, -0.66), Vector3(0.14, 0.34, 0.04), Vector3(0, 0, 180 + side * 12))
		"iron":
			_p(root, MeshKit.hemisphere(), tint, Vector3(0, 0.64, 0), Vector3(1.3, 1.4, 1.26))
			_p(root, MeshKit.box(), tint.darkened(0.12), Vector3(0, 0.96, 0.58), Vector3(0.1, 0.5, 0.06))
			_p(root, MeshKit.cone(), tint.lightened(0.2), Vector3(0, 1.4, 0), Vector3(0.12, 0.3, 0.12))
			_p(root, MeshKit.torus(), tint.darkened(0.2), Vector3(0, 0.66, 0), Vector3(1.28, 1.0, 1.24))
		"horned":
			_p(root, MeshKit.hemisphere(), tint, Vector3(0, 0.64, 0), Vector3(1.3, 1.36, 1.26))
			_p(root, MeshKit.box(), tint.darkened(0.15), Vector3(0, 0.96, 0.58), Vector3(0.1, 0.5, 0.06))
			for side in [-1.0, 1.0]:
				_p(root, MeshKit.cone(), Color("f2e8c8"), Vector3(side * 0.7, 1.0, 0), Vector3(0.22, 0.62, 0.22), Vector3(0, 0, side * -48.0))
				_p(root, MeshKit.sphere_low(), tint.lightened(0.2), Vector3(side * 0.6, 0.78, 0), Vector3(0.2, 0.2, 0.2))
		"crown":
			_p(root, MeshKit.cylinder(), tint, Vector3(0, 0.98, 0), Vector3(1.05, 0.2, 1.0))
			for i in 7:
				var a := i * TAU / 7.0
				_p(root, MeshKit.cone(), tint.lightened(0.15), Vector3(cos(a) * 0.48, 1.2, sin(a) * 0.46), Vector3(0.18, 0.36, 0.18))
				_p(root, MeshKit.sphere_low(), GEMS[i % GEMS.size()], Vector3(cos(a) * 0.5, 0.98, sin(a) * 0.48), Vector3(0.1, 0.1, 0.1), Vector3.ZERO, 1.0)
	return root


## Icon-only models.
static func trinket(kind: String, tier: int) -> Node3D:
	var root := Node3D.new()
	var metal: Color = TIERS_METAL[clampi(tier, 0, 5)]
	var gem: Color = GEMS[clampi(tier, 0, 5)]
	match kind:
		"boots":
			var leather: Color = [Color("9a6b42"), Color("7a5a3a"), Color("8a95a8"), Color("3e7a5a"), Color("c0392b"), Color("6a4ab0")][clampi(tier, 0, 5)]
			_p(root, MeshKit.box(), leather, Vector3(0, 0.34, 0), Vector3(0.34, 0.62, 0.34))
			_p(root, MeshKit.box(), leather.darkened(0.15), Vector3(0, 0.02, 0.14), Vector3(0.36, 0.2, 0.62))
			_p(root, MeshKit.box(), leather.lightened(0.25), Vector3(0, 0.62, 0), Vector3(0.42, 0.12, 0.42))
			_p(root, MeshKit.sphere_low(), metal, Vector3(0, 0.34, 0.18), Vector3(0.12, 0.12, 0.06), Vector3.ZERO, 0.4)
			if tier >= 3:
				for side in [-1.0, 1.0]:
					_p(root, MeshKit.prism(), Color("ffffff"), Vector3(side * 0.28, 0.4, -0.04), Vector3(0.18, 0.4, 0.04), Vector3(0, 0, side * -70))
		"ring":
			_p(root, MeshKit.torus(), metal, Vector3.ZERO, Vector3(0.9, 0.9, 0.9), Vector3(90, 0, 0), 0.3)
			_p(root, MeshKit.sphere(), gem, Vector3(0, 0.44, 0), Vector3(0.28, 0.28, 0.28), Vector3.ZERO, 1.0)
			_p(root, MeshKit.torus(), metal, Vector3(0, 0.44, 0), Vector3(0.36, 0.36, 0.36), Vector3(90, 0, 0))
		"amulet":
			var chain := _arc_ring(root, metal)
			chain.position = Vector3(0, 0.0, 0)
			_p(root, MeshKit.sphere(), gem, Vector3(0, -0.56, 0), Vector3(0.34, 0.4, 0.2), Vector3.ZERO, 1.1)
			_p(root, MeshKit.torus(), metal, Vector3(0, -0.56, 0), Vector3(0.46, 0.5, 0.46), Vector3(90, 0, 0))
	return root


static func _arc_ring(parent: Node3D, color: Color) -> Node3D:
	var pts: Array[Vector3] = []
	for i in 21:
		var x := lerpf(-0.5, 0.5, i / 20.0)
		pts.append(Vector3(x, 0.5 - (1.0 - pow(x / 0.5, 2.0)) * 1.0, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = WeaponKit.tube(pts, Vector3(0, 0, 1), 0.035)
	mi.material_override = MeshKit.toon(color)
	parent.add_child(mi)
	return mi


## Ankle cuff for the lower-leg bone (bone Y runs down the leg). side: +1 left, -1 right.
static func boot_cuff(tier: int, side: float) -> Node3D:
	var root := Node3D.new()
	root.name = "BootCuff"
	var leather: Color = [Color("9a6b42"), Color("7a5a3a"), Color("8a95a8"), Color("3e7a5a"), Color("c0392b"), Color("6a4ab0")][clampi(tier, 0, 5)]
	var metal: Color = TIERS_METAL[clampi(tier, 0, 5)]
	_p(root, MeshKit.cylinder(), leather, Vector3(0, 0.1, 0), Vector3(0.34, 0.26, 0.34))
	_p(root, MeshKit.torus(), metal, Vector3(0, -0.03, 0), Vector3(0.36, 0.5, 0.36))
	if tier >= 2:
		_p(root, MeshKit.sphere_low(), GEMS[clampi(tier, 0, 5)], Vector3(0, 0.08, 0.17), Vector3(0.09, 0.09, 0.06), Vector3.ZERO, 0.8)
	if tier >= 3:
		_p(root, MeshKit.prism(), Color("ffffff"), Vector3(side * 0.16, 0.05, -0.02), Vector3(0.2, 0.3, 0.03), Vector3(0, 0, side * -75.0))
	return root


## Necklace on the chest bone: a chain draped over the chest with a gem pendant.
static func necklace(tier: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Necklace"
	var metal: Color = TIERS_METAL[clampi(tier, 0, 5)]
	var gem: Color = GEMS[clampi(tier, 0, 5)]
	var pts: Array[Vector3] = []
	for i in 17:
		var x := lerpf(-0.24, 0.24, i / 16.0)
		pts.append(Vector3(x, 0.3 - (1.0 - pow(x / 0.24, 2.0)) * 0.3, 0.37 - absf(x) * 0.5))
	var mi := MeshInstance3D.new()
	mi.mesh = WeaponKit.tube(pts, Vector3(0, 0, 1), 0.03)
	mi.material_override = MeshKit.toon(metal)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_p(root, MeshKit.sphere(), gem, Vector3(0, 0.0, 0.4), Vector3(0.17, 0.2, 0.12), Vector3.ZERO, 1.0)
	_p(root, MeshKit.torus(), metal, Vector3(0, 0.0, 0.4), Vector3(0.24, 0.24, 0.24), Vector3(90, 0, 0))
	return root


## A cut gem for icons: two cones back to back with a bright highlight.
static func gem(gem_id: String) -> Node3D:
	var root := Node3D.new()
	var color: Color = ItemData.GEMS[gem_id].color
	_p(root, MeshKit.cone(), color, Vector3(0, 0.22, 0), Vector3(0.62, 0.42, 0.62), Vector3.ZERO, 0.9)
	_p(root, MeshKit.cone(), color.darkened(0.2), Vector3(0, -0.1, 0), Vector3(0.62, 0.55, 0.62), Vector3(180, 0, 0), 0.9)
	_p(root, MeshKit.sphere_low(), Color(1, 1, 1), Vector3(-0.1, 0.25, 0.22), Vector3(0.12, 0.08, 0.08), Vector3.ZERO, 1.5)
	return root


## A band for the wrist (ring slot): a thin torus with a gem.
static func ring_band(tier: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RingBand"
	var metal: Color = TIERS_METAL[clampi(tier, 0, 5)]
	_p(root, MeshKit.torus(), metal, Vector3.ZERO, Vector3(0.34, 0.5, 0.34), Vector3(0, 0, 90), 0.3)
	_p(root, MeshKit.sphere_low(), GEMS[clampi(tier, 0, 5)], Vector3(0, 0.0, 0.1), Vector3(0.1, 0.1, 0.1), Vector3.ZERO, 1.0)
	return root
