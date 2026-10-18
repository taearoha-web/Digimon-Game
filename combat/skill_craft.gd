class_name SkillCraft
extends RefCounted
## Finite, shared geometry for elemental fracture, portals and finishing beats.
## No gameplay or camera ownership. Every optional mesh uses the common cap.
static var _snow: ArrayMesh
static var _petal: ArrayMesh
static var _ice: ArrayMesh

static func warm_geometry() -> void:
	snow_mesh()
	petal_mesh()
	ice_mesh()

static func snow_mesh() -> ArrayMesh:
	if _snow == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for arm in 6:
			var a := float(arm) * TAU / 6.0
			var d := Vector3(sin(a), 0, cos(a))
			var side := Vector3(cos(a), 0, -sin(a))
			for branch in 3:
				var start := Vector3.ZERO if branch == 0 else d * 0.48
				var end := d if branch == 0 else d * 0.72 + side * (0.24 if branch == 1 else -0.24)
				var w := side * 0.011
				SpellSpectacle._tri(st, start - w, end - w, start + w)
				SpellSpectacle._tri(st, start + w, end - w, end + w)
		st.generate_normals()
		_snow = st.commit()
	return _snow

static func petal_mesh() -> ArrayMesh:
	if _petal == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			SpellSpectacle._tri(st, Vector3.ZERO, Vector3(side * 0.38, 0.45, 0.12), Vector3(0, 1, 0.3))
			SpellSpectacle._tri(st, Vector3.ZERO, Vector3(0, 0.55, -0.12), Vector3(side * 0.38, 0.45, 0.12))
			SpellSpectacle._tri(st, Vector3(side * 0.38, 0.45, 0.12), Vector3(0, 0.55, -0.12), Vector3(0, 1, 0.3))
		st.generate_normals()
		_petal = st.commit()
	return _petal

static func ice_mesh() -> ArrayMesh:
	if _ice == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 6:
			var a := TAU * i / 6.0
			var b := TAU * (i + 1) / 6.0
			var p := Vector3(cos(a), 0.02, sin(a))
			var q := Vector3(cos(b), 0.02, sin(b))
			var top_p := Vector3(cos(a) * 0.86, 0.72, sin(a) * 0.86)
			var top_q := Vector3(cos(b) * 0.86, 0.72, sin(b) * 0.86)
			SpellSpectacle._tri(st, p, top_p, q)
			SpellSpectacle._tri(st, q, top_p, top_q)
			SpellSpectacle._tri(st, top_p, Vector3(0.12, 1.15, -0.12), top_q)
		st.generate_normals()
		_ice = st.commit()
	return _ice

static func frost(root: Node3D, look: Dictionary, mat: Material, core: Material, tier: int, radius: float) -> void:
	# A six-spoke ground fracture, staggered crystal growth and outward chips.
	# Keep the inner 45% empty so enemies and red warnings remain visible.
	var crack := SpellSpectacle._mesh(root, snow_mesh(), mat, Vector3(0, 0.065, 0))
	if crack:
		crack.scale = Vector3.ONE * radius
	var count := VfxBudget.count(6 + tier, 3)
	for i in count:
		var a := float(i) * TAU / count + float(look.phase)
		var d := Vector3(sin(a), 0, cos(a))
		var crystal := SpellSpectacle._mesh(root, ice_mesh(), mat, d * radius * 0.62)
		if crystal:
			crystal.name = "GrowingIceFacet"
			crystal.rotation = Vector3(0.28, a, -0.15)
			crystal.scale = Vector3(0.32, 0.025, 0.32)
			var height := 1.15 + (i % 3) * 0.46 + tier * 0.1
			var tw := crystal.create_tween()
			tw.tween_interval((i % 3) * 0.035)
			tw.tween_property(crystal, "scale:y", height, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.28)
			tw.tween_property(crystal, "scale", Vector3(0.08, 0.12, 0.08), 0.38)
		if tier >= 2:
			var chip := SpellSpectacle._mesh(root, SpellSpectacle._crystal_mesh(), core, d * radius * 0.5 + Vector3.UP * 0.7)
			if chip:
				chip.scale = Vector3(0.1, 0.26, 0.1)
				var start := chip.position
				var end := d * radius * 0.95 + Vector3.UP * 0.1
				var tw := chip.create_tween()
				tw.tween_interval(0.25)
				tw.tween_method(func(t: float):
					chip.position = start.lerp(end, t) + Vector3.UP * sin(t * PI) * 0.75
					chip.rotation.z = t * 3.0, 0.0, 1.0, 0.45)

static func portal(root: Node3D, look: Dictionary, core: Material, radius: float, duration: float) -> Node3D:
	var gate := Node3D.new()
	gate.name = "SummoningGate"
	root.add_child(gate)
	gate.position = Vector3(0, 1.4, -0.65)
	var ring := SpellSpectacle._mesh(gate, SpellSpectacle._halo_mesh(), core)
	if ring:
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3.ONE * radius
	# The portal has no filled disc; creatures emerge into an unobscured centre.
	for side in [-1, 1]:
		var rune := SpellSpectacle._mesh(gate, SpellSpectacle._crystal_mesh(), core, Vector3(side * radius, 0, 0))
		if rune:
			rune.scale = Vector3(0.12, 0.26, 0.12)
	gate.scale = Vector3(0.01, 0.7, 1)
	var tw := gate.create_tween()
	tw.tween_property(gate, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.05, duration - 0.42))
	tw.tween_property(gate, "scale", Vector3(0.01, 1.15, 1), 0.24)
	return gate

## Sized by the recipe's impact_weight, held for its linger; a critical hit
## adds a fan of the element's cards. Cosmetic: the hit was already decided.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit := false) -> void:
	if not VfxBudget.can_decorate():
		return
	var look := SkillShow.profile_for(skill)
	var weight := clampf(float(look.impact_weight), 0.5, 2.4)
	var linger := clampf(float(look.linger), 0.6, 1.6)
	var root := SpellSpectacle._root(parent, at, "SkillContact_" + String(skill.id))
	var mat := SpellSpectacle._material(look, 0.78)
	var style := String(look.style)
	var melee := String(look.signature) in ["cleave", "cross", "blade", "lance", "world_spear", "cyclone", "sword_court"]
	if melee:
		SkillInk.ribbon(root, look, Vector3.ZERO, (0.58 + float(look.tier) * 0.045) * weight, 0, Vector3(PI * 0.5, 0, float(look.curvature)), 0.24 * linger)
	else:
		SkillInk.mark(root, look, Vector3.ZERO, (0.48 + float(look.tier) * 0.065) * weight, 0.28 * linger, 1, true)
	if crit:
		VfxKit.impact_fan(parent, at, look.accent, 0.7 * weight, "petal" if style in ["holy", "heal", "leaf", "wind"] else ("flame" if style == "fire" else "diamond"))
	# Only a few physical fragments per victim; no emitter explosion for every
	# target of an AoE. A single bloom/snow/fire fragment still tells the element.
	var count := mini(VfxBudget.count(3, 1), maxi(1, (VfxBudget.decoration_limit() - int(VfxBudget.counters().decorations)) / 8))
	for i in count:
		var mesh: Mesh = petal_mesh() if style in ["holy", "heal", "leaf", "wind"] else SpellSpectacle._crystal_mesh()
		var chip := SpellSpectacle._mesh(root, mesh, mat)
		if chip:
			chip.scale = Vector3(0.10, 0.32 if style == "ice" else 0.20, 0.10)
			var angle := float(look.phase) + i * TAU / count
			var end := Vector3(sin(angle) * 0.6, 0.2 if style == "fire" else -0.35, cos(angle) * 0.6)
			chip.rotation = Vector3(angle, 0, angle * 0.3)
			chip.create_tween().tween_method(func(t: float): chip.position = end * t + Vector3.UP * sin(t * PI) * 0.3, 0.0, 1.0, 0.4 * linger)
	SpellSpectacle._finish(root, mat, 0.42 * linger)
