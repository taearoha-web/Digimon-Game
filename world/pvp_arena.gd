class_name PvpArena
extends RefCounted
## The ranked-duel coliseum: a wide sand floor with a gold-inlaid emblem, a
## ring of stone stands packed with a cheering crowd, torch pillars, two grand
## gates, hanging banners and drifting golden dust, all under a dusk sky.

const RADIUS := 34.0
const WALL_R := 37.5
const SPAWN_X := 17.0

const STONE_LIGHT := Color("b3a590")
const STONE_DARK := Color("85786a")
const SAND := Color("c4a468")
const GOLD := Color("d4a22e")
const TEAM_COLORS: Array[Color] = [Color("d6453d"), Color("3d6fd6"), Color("f0c24a"), Color("8a4fd0")]


static func build(zone: Node3D, rng: RandomNumberGenerator) -> void:
	Scenery.environment(zone, Color("4d63c8"), Color("f4b896"), Color(1.0, 0.84, 0.76), Color(1.0, 0.82, 0.58))
	for sun in zone.get_tree().get_nodes_in_group("sun"):
		(sun as Node3D).rotation_degrees = Vector3(-34, -58, 0)
		(sun as DirectionalLight3D).light_energy = 0.52
	Scenery.ground(zone, 130.0, Color("b49a6a"), Color("c8ae7c"), 31, Color("c8ae7c"), [], 2.0)
	_floor(zone)
	_stands(zone, rng)
	_crowd(zone, rng)
	_pillars(zone)
	_gates(zone)
	_banners(zone)
	_mountains(zone, rng)
	_dust(zone)


# ---------------------------------------------------------------------------
# Floor
# ---------------------------------------------------------------------------

static func _disc(parent: Node3D, radius: float, top: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var opts := {"emission": emission} if emission > 0.0 else {}
	var mi := MeshKit.part(parent, MeshKit.cylinder(), MeshKit.toon(color, opts), Vector3(0, top * 0.5, 0), Vector3(radius * 2.0, top, radius * 2.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _floor(zone: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "ArenaFloor"
	zone.add_child(holder)
	_disc(holder, 37.0, 0.05, Color("8f7446"))
	_disc(holder, 34.2, 0.065, GOLD, 0.1)
	_disc(holder, 33.9, 0.08, Color("b8995c"))
	_disc(holder, 31.0, 0.09, SAND)
	# Tile pattern: radial seams and two inlaid rings.
	for i in 24:
		var angle := TAU * i / 24.0
		var seam := MeshKit.part(holder, MeshKit.box(), MeshKit.toon(Color("a98c56")), Vector3(cos(angle) * 22.0, 0.1, sin(angle) * 22.0),
				Vector3(18.0, 0.02, 0.18), Vector3(0, -rad_to_deg(angle), 0))
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc(holder, 24.4, 0.1, GOLD, 0.1)
	_disc(holder, 24.1, 0.11, Color("d2b87c"))
	_disc(holder, 13.2, 0.12, GOLD, 0.1)
	_disc(holder, 12.9, 0.13, Color("3f4f86"))
	_disc(holder, 12.0, 0.14, Color("6678b4"))
	_disc(holder, 8.0, 0.15, Color("3f4f86"))
	_disc(holder, 7.7, 0.16, Color("d2b87c"))
	# Sun emblem: eight golden rays and a core.
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8.0
		var ray := MeshKit.part(holder, MeshKit.box(), MeshKit.toon(GOLD, {"emission": 0.15}), Vector3(cos(angle) * 4.6, 0.17, sin(angle) * 4.6),
				Vector3(6.2, 0.02, 0.9), Vector3(0, -rad_to_deg(angle), 0))
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc(holder, 2.0, 0.18, GOLD, 0.2)
	_disc(holder, 1.2, 0.19, Color("f0d890"), 0.3)
	# Starting circles for the two fighters.
	for side in [-1.0, 1.0]:
		var color := Color("4a8cff") if side < 0.0 else Color("ff5a4a")
		var spot := Node3D.new()
		spot.position = Vector3(side * SPAWN_X, 0.0, 0.0)
		holder.add_child(spot)
		_disc(spot, 2.4, 0.17, color.darkened(0.45))
		var glow := MeshInstance3D.new()
		glow.mesh = MeshKit.cylinder()
		glow.material_override = VfxKit._glow(color, 0.6)
		glow.scale = Vector3(4.2, 0.02, 4.2)
		glow.position = Vector3(0, 0.2, 0)
		spot.add_child(glow)
		var beam := VfxKit.loot_beam(spot, color, 4.0)
		beam.scale = Vector3(0.14, 4.0, 0.14)


# ---------------------------------------------------------------------------
# Stands, wall, gates
# ---------------------------------------------------------------------------

static func _multimesh(parent: Node3D, mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color], shadows := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


static func _vertex_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


static func _stands(zone: Node3D, _rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Stands"
	zone.add_child(holder)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	# Front wall (with the two gates left open), then three rising tiers.
	var rings := [
		{"r": WALL_R, "h": 4.2, "d": 1.6, "n": 56, "band": false},
		{"r": 41.0, "h": 5.4, "d": 4.2, "n": 64, "band": true},
		{"r": 45.0, "h": 7.4, "d": 4.2, "n": 68, "band": true},
		{"r": 49.0, "h": 9.4, "d": 4.2, "n": 72, "band": true},
		{"r": 54.5, "h": 15.0, "d": 6.0, "n": 76, "band": false},
	]
	for ring in rings:
		var n: int = ring.n
		var r: float = ring.r
		var width := TAU * r / float(n) * 1.03
		for i in n:
			var angle := TAU * (float(i) + 0.5) / float(n)
			if bool(ring.band) == false and r == WALL_R and (absf(sin(angle)) < 0.13 and absf(cos(angle)) > 0.9):
				continue
			var basis := Basis(Vector3.UP, -angle + PI * 0.5).scaled(Vector3(width, ring.h, ring.d))
			transforms.append(Transform3D(basis, Vector3(cos(angle) * r, float(ring.h) * 0.5, sin(angle) * r)))
			var base := STONE_LIGHT if i % 2 == 0 else STONE_DARK
			if bool(ring.band) and i % 8 == 3:
				base = TEAM_COLORS[(i / 8) % TEAM_COLORS.size()].lerp(STONE_LIGHT, 0.35)
			if r > 50.0:
				base = base.darkened(0.25)
			colors.append(base)
	_multimesh(holder, MeshKit.box(), _vertex_material(), transforms, colors, true)
	# Crenellations along the wall top.
	var cren: Array[Transform3D] = []
	var cren_colors: Array[Color] = []
	for i in 56:
		var angle := TAU * (float(i) + 0.5) / 56.0
		if absf(sin(angle)) < 0.13 and absf(cos(angle)) > 0.9:
			continue
		if i % 2 == 0:
			var basis := Basis(Vector3.UP, -angle + PI * 0.5).scaled(Vector3(2.2, 0.9, 1.6))
			cren.append(Transform3D(basis, Vector3(cos(angle) * WALL_R, 4.2 + 0.45, sin(angle) * WALL_R)))
			cren_colors.append(STONE_LIGHT.lightened(0.05))
	_multimesh(holder, MeshKit.box(), _vertex_material(), cren, cren_colors)


## Spectators on every tier: bodies and heads as two multimeshes, bobbing in a
## crowd wave.
static func _crowd(zone: Node3D, rng: RandomNumberGenerator) -> void:
	var tiers := [{"r": 40.9, "y": 5.4, "n": 70}, {"r": 44.9, "y": 7.4, "n": 76}, {"r": 48.9, "y": 9.4, "n": 82}]
	var body_t: Array[Transform3D] = []
	var body_c: Array[Color] = []
	var head_t: Array[Transform3D] = []
	var head_c: Array[Color] = []
	var data: Array[Dictionary] = []
	var shirts: Array[Color] = [Color("e8574f"), Color("4f8be8"), Color("f0c24a"), Color("5fcf7a"), Color("b86be8"), Color("f08a4a"), Color("f2f2f2"), Color("4fd0d0")]
	var skins: Array[Color] = [Color("f2c9a0"), Color("e0a878"), Color("c58a5c"), Color("8a5a3a"), Color("fbd8b8")]
	for tier in tiers:
		var n: int = tier.n
		for i in n:
			var angle := TAU * (float(i) + rng.randf() * 0.7) / float(n)
			var r: float = float(tier.r) + rng.randf_range(-0.9, 0.9)
			var base := Vector3(cos(angle) * r, float(tier.y), sin(angle) * r)
			var scale := rng.randf_range(0.85, 1.1)
			data.append({"base": base, "angle": angle, "scale": scale, "phase": rng.randf() * TAU, "cheer": rng.randf_range(0.6, 1.4)})
			body_t.append(Transform3D(Basis().scaled(Vector3(0.55, 0.7, 0.55) * scale), base + Vector3(0, 0.55 * scale, 0)))
			body_c.append(shirts[rng.randi() % shirts.size()])
			head_t.append(Transform3D(Basis().scaled(Vector3.ONE * 0.4 * scale), base + Vector3(0, 1.3 * scale, 0)))
			head_c.append(skins[rng.randi() % skins.size()])
	var holder := Node3D.new()
	holder.name = "Crowd"
	zone.add_child(holder)
	var bodies := _multimesh(holder, MeshKit.capsule(), _vertex_material(), body_t, body_c)
	var heads := _multimesh(holder, MeshKit.sphere_low(), _vertex_material(), head_t, head_c)
	var animator := CrowdAnimator.new()
	animator.bodies = bodies.multimesh
	animator.heads = heads.multimesh
	animator.data = data
	holder.add_child(animator)


## Torch pillars in front of the wall, a few with real light.
static func _pillars(zone: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Pillars"
	zone.add_child(holder)
	var count := 16
	for i in count:
		var angle := TAU * (float(i) + 0.5) / float(count)
		if absf(sin(angle)) < 0.2 and absf(cos(angle)) > 0.9:
			continue
		var pos := Vector3(cos(angle) * 35.6, 0, sin(angle) * 35.6)
		var pillar := Node3D.new()
		pillar.position = pos
		holder.add_child(pillar)
		MeshKit.part(pillar, MeshKit.cylinder(), MeshKit.toon(STONE_LIGHT), Vector3(0, 0.4, 0), Vector3(1.9, 0.8, 1.9))
		MeshKit.part(pillar, MeshKit.cylinder(), MeshKit.toon(STONE_LIGHT.lightened(0.05)), Vector3(0, 3.6, 0), Vector3(1.2, 6.4, 1.2))
		MeshKit.part(pillar, MeshKit.cylinder(), MeshKit.toon(GOLD, {"emission": 0.3}), Vector3(0, 6.9, 0), Vector3(1.7, 0.45, 1.7))
		MeshKit.part(pillar, MeshKit.cylinder(), MeshKit.toon(Color("3a3340")), Vector3(0, 7.4, 0), Vector3(1.5, 0.5, 1.5))
		var flame := MeshKit.part(pillar, MeshKit.sphere_low(), MeshKit.toon(Color("ff9a3a"), {"emission": 3.0}), Vector3(0, 8.0, 0), Vector3(0.9, 1.3, 0.9))
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fire := VfxKit._particles(pillar, pos + Vector3(0, 7.9, 0), Color("ffb04a"), 14, 0.9, false)
		fire.position = Vector3(0, 7.9, 0)
		fire.direction = Vector3.UP
		fire.spread = 12.0
		fire.initial_velocity_min = 0.8
		fire.initial_velocity_max = 1.6
		fire.gravity = Vector3(0, 1.0, 0)
		if i % 4 == 1:
			var light := OmniLight3D.new()
			light.light_color = Color("ffae5a")
			light.light_energy = 1.1
			light.omni_range = 16.0
			light.position = Vector3(0, 8.0, 0)
			pillar.add_child(light)


## The two great gates the fighters walk out of.
static func _gates(zone: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var gate := Node3D.new()
		gate.name = "Gate"
		gate.position = Vector3(side * WALL_R, 0, 0)
		gate.rotation.y = 0.0 if side > 0.0 else PI
		zone.add_child(gate)
		var accent := Color("ff5a4a") if side > 0.0 else Color("4a8cff")
		for z in [-4.6, 4.6]:
			MeshKit.part(gate, MeshKit.box(), MeshKit.toon(STONE_LIGHT), Vector3(-0.4, 4.5, z), Vector3(2.6, 9.0, 2.2))
			MeshKit.part(gate, MeshKit.box(), MeshKit.toon(GOLD, {"emission": 0.3}), Vector3(-0.4, 9.15, z), Vector3(3.0, 0.4, 2.6))
			MeshKit.part(gate, MeshKit.box(), MeshKit.toon(accent, {"emission": 0.6}), Vector3(-1.75, 5.5, z), Vector3(0.12, 3.2, 1.2))
		MeshKit.part(gate, MeshKit.box(), MeshKit.toon(STONE_DARK), Vector3(-0.4, 9.9, 0), Vector3(2.6, 2.2, 12.4))
		MeshKit.part(gate, MeshKit.box(), MeshKit.toon(GOLD, {"emission": 0.3}), Vector3(-1.75, 10.1, 0), Vector3(0.2, 0.5, 11.0))
		MeshKit.part(gate, MeshKit.box(), MeshKit.toon(accent, {"emission": 0.5}), Vector3(-1.8, 9.9, 0), Vector3(0.12, 1.2, 4.0))
		# The dark passage behind the gate, with portcullis bars.
		MeshKit.part(gate, MeshKit.box(), MeshKit.toon(Color("1c1a24")), Vector3(2.4, 3.5, 0), Vector3(1.0, 7.0, 7.4))
		for k in 6:
			MeshKit.part(gate, MeshKit.box(), MeshKit.toon(Color("55505e")), Vector3(1.7, 4.0, -3.0 + k * 1.2), Vector3(0.16, 8.0, 0.16))


static func _banners(zone: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Banners"
	zone.add_child(holder)
	var count := 20
	for i in count:
		var angle := TAU * (float(i) + 0.5) / float(count)
		if absf(sin(angle)) < 0.2 and absf(cos(angle)) > 0.9:
			continue
		var color: Color = TEAM_COLORS[i % TEAM_COLORS.size()]
		var banner := Node3D.new()
		banner.position = Vector3(cos(angle) * 36.6, 6.6, sin(angle) * 36.6)
		banner.rotation.y = -angle - PI * 0.5
		holder.add_child(banner)
		var cloth := MeshKit.part(banner, MeshKit.box(), MeshKit.toon(color), Vector3(0, 0, 0), Vector3(2.4, 5.2, 0.08))
		cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		MeshKit.part(banner, MeshKit.box(), MeshKit.toon(GOLD, {"emission": 0.4}), Vector3(0, 2.7, 0.0), Vector3(2.7, 0.22, 0.2))
		MeshKit.part(banner, MeshKit.box(), MeshKit.toon(GOLD, {"emission": 0.35}), Vector3(0, 0.2, 0.06), Vector3(0.7, 1.7, 0.05), Vector3(0, 0, 45))
		MeshKit.part(banner, MeshKit.box(), MeshKit.toon(color.darkened(0.2)), Vector3(0, -2.9, 0), Vector3(0.9, 0.6, 0.08), Vector3(0, 0, 45))
		var tween := banner.create_tween().set_loops()
		var sway := 2.2 + float(i % 3)
		tween.tween_property(banner, "rotation_degrees:x", sway, 1.6 + float(i % 4) * 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(banner, "rotation_degrees:x", -sway, 1.6 + float(i % 4) * 0.2).set_trans(Tween.TRANS_SINE)


## Far hills so the sky has something to sit on.
static func _mountains(zone: Node3D, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.name = "Hills"
	zone.add_child(holder)
	for i in 18:
		var angle := TAU * float(i) / 18.0 + rng.randf() * 0.2
		var dist := rng.randf_range(95.0, 118.0)
		var height := rng.randf_range(22.0, 44.0)
		var width := height * rng.randf_range(1.6, 2.2)
		var tint := Color("6a5a98").lerp(Color("c88a9a"), rng.randf())
		var hill := MeshKit.part(holder, MeshKit.cone(), MeshKit.toon(tint), Vector3(cos(angle) * dist, height * 0.5 - 1.0, sin(angle) * dist), Vector3(width, height, width))
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Golden motes drifting down over the sand.
static func _dust(zone: Node3D) -> void:
	for color in [Color("ffe08a"), Color("ffc0d8")]:
		var p := VfxKit._particles(zone, Vector3(0, 12.0, 0), color, 70, 11.0, false)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(32.0, 0.5, 32.0)
		p.direction = Vector3.DOWN
		p.spread = 20.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.8
		p.gravity = Vector3(0.12, -0.7, 0.05)
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.8
		p.local_coords = true


## Makes the crowd bob and do a slow wave around the stands.
class CrowdAnimator extends Node:
	var bodies: MultiMesh
	var heads: MultiMesh
	var data: Array[Dictionary] = []
	var _t := 0.0
	var _frame := 0

	func _process(delta: float) -> void:
		_t += delta
		_frame += 1
		# Half the crowd per frame keeps this light on phones.
		for i in range(_frame % 2, data.size(), 2):
			var d: Dictionary = data[i]
			var angle: float = d.angle
			var wave := maxf(0.0, sin(angle * 4.0 - _t * 1.6))
			var hop := (absf(sin(_t * 4.2 * float(d.cheer) + float(d.phase))) * 0.16 + wave * 0.5) * float(d.cheer)
			var s: float = d.scale
			var base: Vector3 = d.base
			bodies.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.55, 0.7, 0.55) * s), base + Vector3(0, 0.55 * s + hop, 0)))
			heads.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.4 * s), base + Vector3(0, 1.3 * s + hop, 0)))
