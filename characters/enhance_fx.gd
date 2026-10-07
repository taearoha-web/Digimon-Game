class_name EnhanceFx
extends RefCounted
## How enhanced (+N) gear looks. Five visual grades so +1 and +10 are easy to
## tell apart:
##   +1..+3  pale-blue shimmer on the weapon
##   +4..+6  bright cyan glow, sparkles and a rune ring at the feet
##   +7..+9  golden blaze: halo, orbiting sparks, body aura, double rune ring
##   +10     crimson-white inferno: flames, four orbs, light pillar, flame ring

const COLORS: Array[Color] = [Color(0, 0, 0, 0), Color("a8dcff"), Color("46f0d0"), Color("ffc93c"), Color("ff4a28")]
const NAMES: Array[String] = ["", "ประกายจาง", "เรืองแสง", "ลุกโชน", "ขีดสุด"]


static func grade(plus: int) -> int:
	if plus <= 0:
		return 0
	if plus <= 3:
		return 1
	if plus <= 6:
		return 2
	if plus <= 9:
		return 3
	return 4


static func color_of(plus: int) -> Color:
	return COLORS[grade(plus)]


## The highest + among the worn items.
static func best_plus(equip: Dictionary) -> int:
	var best := 0
	for slot in equip:
		best = maxi(best, int(equip[slot].get("plus", 0)))
	return best


static func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


static func _sparkles(parent: Node3D, pos: Vector3, color: Color, amount: int, radius: float, size: float, rise: float, lifetime := 1.1) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.gravity = Vector3.ZERO
	p.local_coords = false
	p.color_ramp = VfxKit._fade_ramp()
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


static func _flames(parent: Node3D, pos: Vector3, radius: float, amount: int) -> void:
	var p := _sparkles(parent, pos, Color.WHITE, amount, radius, 0.34, 1.4, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 0.9))
	ramp.add_point(0.35, Color(1.0, 0.55, 0.15, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.8, 0.1, 0.05, 0.0))
	p.color_ramp = ramp
	p.gravity = Vector3(0, 1.6, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9


static func _bounds_center(root: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for m in MeshKit.collect_meshes(root):
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != null and n != root:
			if n is Node3D:
				t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else Vector3(0, 0.5, 0)


## Glow and sparkles on a held weapon (or shield).
static func on_item(item: Node3D, plus: int) -> void:
	var g := grade(plus)
	if g == 0:
		return
	var color := COLORS[g]
	var rich := GameSettings.quality > 0
	var overlay := _glow_material(color, [0.0, 0.07, 0.11, 0.15, 0.2][g])
	for m in MeshKit.collect_meshes(item):
		m.material_overlay = overlay
	var pulse := item.create_tween().set_loops()
	var base_a: float = overlay.albedo_color.a
	var speed: float = [0.0, 1.6, 1.1, 0.8, 0.45][g]
	pulse.tween_property(overlay, "albedo_color:a", base_a * 1.7, speed).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(overlay, "albedo_color:a", base_a * 0.5, speed).set_trans(Tween.TRANS_SINE)
	if not rich:
		return
	var center := _bounds_center(item)
	_sparkles(item, center, color, [0, 4, 9, 14, 18][g], 0.2 + 0.03 * g, 0.12 + 0.02 * g, 0.5 + 0.1 * g)
	if g >= 3:
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (1.0 if g == 3 else 1.3)
		var hmat := _glow_material(color, 0.5)
		hmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hmat.albedo_texture = VfxKit.soft_dot()
		quad.material = hmat
		halo.mesh = quad
		halo.position = center
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.add_child(halo)
		var breathe := halo.create_tween().set_loops()
		breathe.tween_property(halo, "scale", Vector3.ONE * 1.25, 0.7).set_trans(Tween.TRANS_SINE)
		breathe.tween_property(halo, "scale", Vector3.ONE * 0.85, 0.7).set_trans(Tween.TRANS_SINE)
		# Orbiting sparks around the weapon.
		var orbit := Node3D.new()
		orbit.position = center
		item.add_child(orbit)
		var count := 2 if g == 3 else 4
		for i in count:
			var a := TAU * float(i) / float(count)
			var orb := MeshInstance3D.new()
			orb.mesh = MeshKit.sphere_low()
			orb.material_override = _glow_material(color.lightened(0.3), 0.95)
			orb.scale = Vector3.ONE * 0.09
			orb.position = Vector3(cos(a) * 0.38, sin(a * 2.0) * 0.12, sin(a) * 0.38)
			orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			orbit.add_child(orb)
		var spin := orbit.create_tween().set_loops()
		spin.tween_property(orbit, "rotation:y", TAU, 1.6 if g == 3 else 0.9).from(0.0)
	if g == 4:
		_flames(item, center, 0.1, 12)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.9
		light.omni_range = 4.5
		light.position = center
		item.add_child(light)


## A rune ring at the feet and (for +7 and up) a body aura, sized by the best + worn.
static func on_body(visual: Node3D, plus: int) -> Array[Node]:
	var made: Array[Node] = []
	var g := grade(plus)
	if g < 2:
		return made
	var color := COLORS[g]
	var ring_count := 1 if g < 3 else 2
	for i in ring_count:
		var ring := MeshInstance3D.new()
		ring.mesh = MeshKit.torus()
		ring.material_override = _glow_material(color, 0.75 if i == 0 else 0.45)
		var s := (1.15 if g < 4 else 1.45) + 0.4 * float(i)
		ring.scale = Vector3(s, s * 0.35, s)
		ring.position = Vector3(0, 0.06 + 0.03 * i, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.add_child(ring)
		made.append(ring)
		var spin := ring.create_tween().set_loops()
		spin.tween_property(ring, "rotation:y", TAU * (1.0 if i == 0 else -1.0), 4.0 - 0.6 * float(g)).from(0.0)
	var disc := MeshInstance3D.new()
	disc.mesh = MeshKit.cylinder()
	disc.material_override = _glow_material(color, 0.12)
	disc.scale = Vector3(2.0 + 0.3 * g, 0.01, 2.0 + 0.3 * g)
	disc.position = Vector3(0, 0.04, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(disc)
	made.append(disc)
	if GameSettings.quality > 0:
		made.append(_sparkles(visual, Vector3(0, 0.15, 0), color, 8 + 5 * g, 0.7 + 0.1 * g, 0.12, 0.9 + 0.2 * g, 1.3))
		if g == 4:
			var beam := VfxKit.loot_beam(visual, color, 4.0)
			beam.scale = Vector3(0.12, 4.0, 0.12)
			made.append(beam)
			var fire := Node3D.new()
			visual.add_child(fire)
			_flames(fire, Vector3(0, 0.15, 0), 0.8, 16)
			made.append(fire)
	return made


## Slots that cannot be enhanced (they stay as they are).
const FIXED_SLOTS: Array[String] = ["ring", "amulet"]


static func can_enhance(item: Dictionary) -> bool:
	return item.get("kind", "") == "equip" and not (String(item.get("slot", "")) in FIXED_SLOTS)


## Every enhanced piece glows by itself: an additive overlay on its own meshes
## (stronger and faster-pulsing with the grade) plus a little sparkle at its spot.
## spot = where on the body the sparkles rise (visual space).
static func glow_piece(owner: Node3D, nodes: Array, plus: int, spot: Vector3, spread := 0.3) -> void:
	var g := grade(plus)
	if g == 0:
		return
	var color := COLORS[g]
	var overlay := _glow_material(color, [0.0, 0.05, 0.08, 0.11, 0.15][g])
	var found := false
	for node in nodes:
		if not is_instance_valid(node):
			continue
		for m in MeshKit.collect_meshes(node):
			m.material_overlay = overlay
			found = true
	if not found:
		return
	var base_a: float = overlay.albedo_color.a
	var speed: float = [0.0, 1.8, 1.3, 0.9, 0.5][g]
	var pulse := owner.create_tween().set_loops()
	pulse.tween_property(overlay, "albedo_color:a", base_a * 1.8, speed).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(overlay, "albedo_color:a", base_a * 0.45, speed).set_trans(Tween.TRANS_SINE)
	if GameSettings.quality > 0 and g >= 2:
		var p := _sparkles(owner, spot, color, [0, 0, 5, 8, 12][g], spread, 0.1, 0.5 + 0.1 * g, 0.9)
		p.name = "PieceSparkles"
		if g == 4:
			_flames(owner, spot, spread * 0.8, 6)
