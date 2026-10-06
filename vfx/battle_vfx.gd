class_name BattleVfx
extends RefCounted
## Reusable, data-driven battle effects. Skills reference a VFX preset id
## (SkillData.vfx); this class maps ids to colours/shapes so no skill needs a
## bespoke effect script. All effects free themselves.

const PRESETS := {
	&"impact": {"color": Color(1.0, 0.95, 0.85), "shape": &"burst"},
	&"slash": {"color": Color(0.95, 0.98, 1.0), "shape": &"slash"},
	&"fireball": {"color": Color(1.0, 0.5, 0.18), "shape": &"burst"},
	&"frost": {"color": Color(0.5, 0.88, 1.0), "shape": &"burst"},
	&"wind": {"color": Color(0.7, 1.0, 0.85), "shape": &"swirl"},
	&"thunder": {"color": Color(1.0, 0.92, 0.3), "shape": &"bolt"},
	&"leaf": {"color": Color(0.45, 0.9, 0.35), "shape": &"burst"},
	&"rock": {"color": Color(0.75, 0.58, 0.38), "shape": &"burst"},
	&"light": {"color": Color(1.0, 0.95, 0.6), "shape": &"burst"},
	&"poison": {"color": Color(0.7, 0.4, 0.95), "shape": &"cloud"},
	&"bubbles": {"color": Color(0.55, 0.85, 1.0), "shape": &"cloud"},
	&"heal": {"color": Color(0.4, 1.0, 0.55), "shape": &"sparkle"},
	&"aura": {"color": Color(1.0, 0.8, 0.3), "shape": &"ring"},
	&"debuff": {"color": Color(0.6, 0.35, 0.9), "shape": &"ring"},
}

static var _particle_mesh: Mesh
static var _particle_material: StandardMaterial3D


static func preset_color(vfx_id: StringName) -> Color:
	return PRESETS.get(vfx_id, PRESETS[&"impact"]).color


## Plays the impact part of a preset at [param pos].
static func play_impact(parent: Node3D, vfx_id: StringName, pos: Vector3, scale := 1.0) -> void:
	var preset: Dictionary = PRESETS.get(vfx_id, PRESETS[&"impact"])
	var color: Color = preset.color
	match preset.shape:
		&"slash":
			slash(parent, pos, color)
			burst(parent, pos, color, 14, scale)
		&"swirl":
			burst(parent, pos, color, 22, scale, 2.2)
			ring(parent, pos, color, 1.4 * scale)
		&"bolt":
			bolt(parent, pos, color)
			burst(parent, pos, color, 18, scale)
		&"cloud":
			cloud(parent, pos, color)
		&"sparkle":
			sparkles(parent, pos, color)
		&"ring":
			ring(parent, pos, color, 1.6 * scale)
			sparkles(parent, pos, color)
		_:
			burst(parent, pos, color, 24, scale)


static func burst(parent: Node3D, pos: Vector3, color: Color, amount := 24, scale := 1.0, speed := 3.5) -> void:
	var p := _make_particles(parent, pos, color, amount, 0.55)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5 * scale
	p.initial_velocity_max = speed * scale
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = 0.08 * scale
	p.scale_amount_max = 0.2 * scale
	_flash_light(parent, pos, color)


static func sparkles(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := _make_particles(parent, pos, color, 30, 1.0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14


static func cloud(parent: Node3D, pos: Vector3, color: Color) -> void:
	var p := _make_particles(parent, pos, Color(color.r, color.g, color.b, 0.8), 26, 1.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.38


static func ring(parent: Node3D, pos: Vector3, color: Color, size := 1.5) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.torus()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(size, size * 0.4, size), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(mi.queue_free)


static func slash(parent: Node3D, pos: Vector3, color: Color) -> void:
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.box()
		mi.material_override = MeshKit.toon(color, {"unshaded": true})
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = pos + Vector3(0, (i - 1) * 0.25, 0)
		mi.rotation_degrees = Vector3(0, 0, 35 + i * 10)
		mi.scale = Vector3(0.05, 0.05, 0.05)
		var tween := mi.create_tween()
		tween.tween_property(mi, "scale", Vector3(1.6, 0.06, 0.06), 0.1)
		tween.tween_property(mi, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
		tween.tween_callback(mi.queue_free)


static func bolt(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cylinder()
	mi.material_override = MeshKit.toon(color, {"unshaded": true})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, 2.0, 0)
	mi.scale = Vector3(0.12, 4.0, 0.12)
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(0.3, 4.0, 0.3), 0.06)
	tween.tween_property(mi, "scale", Vector3(0.01, 4.0, 0.01), 0.18)
	tween.tween_callback(mi.queue_free)
	_flash_light(parent, pos, color, 3.0)


## Travels from [param from] to [param to]; awaitable.
static func projectile(parent: Node3D, vfx_id: StringName, from: Vector3, to: Vector3, duration := 0.35) -> void:
	var color := preset_color(vfx_id)
	var orb := MeshInstance3D.new()
	orb.mesh = MeshKit.sphere()
	orb.material_override = MeshKit.toon(color, {"unshaded": true})
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.scale = Vector3.ONE * 0.45
	parent.add_child(orb)
	orb.global_position = from
	var trail := _make_particles(orb, Vector3.ZERO, color, 30, 0.35, false)
	trail.local_coords = false
	trail.one_shot = false
	trail.emitting = true
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.3
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.12
	trail.scale_amount_max = 0.25
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 3.0
	orb.add_child(light)
	var tween := orb.create_tween()
	var mid := (from + to) * 0.5 + Vector3(0, 0.8, 0)
	tween.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		orb.global_position = a.lerp(b, t), 0.0, 1.0, duration)
	await tween.finished
	orb.queue_free()


## Floating number / text above a combatant.
static var _floating_active := 0


static func floating_text(parent: Node3D, pos: Vector3, text: String, color: Color, size := 1.0) -> void:
	# Many hits at once would pile up unreadably: cap the count and spread them out.
	if _floating_active > 26 and size < 1.2:
		return
	pos += Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.25), randf_range(-0.35, 0.35))
	_floating_active += 1
	var label := Label3D.new()
	label.text = L10n.t(text)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = load("res://ui/theme/fonts/heading_font.tres")
	label.font_size = int(96 * size)
	label.outline_size = int(22 * size)
	label.pixel_size = 0.0042
	label.modulate = color
	label.outline_modulate = Color(0.03, 0.05, 0.14)
	parent.add_child(label)
	label.global_position = pos
	label.scale = Vector3.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", pos + Vector3(0, 0.9, 0), 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		_floating_active = maxi(0, _floating_active - 1)
		label.queue_free())


static func stat_arrows(parent: Node3D, pos: Vector3, up: bool) -> void:
	var color := Color(1.0, 0.75, 0.25) if up else Color(0.55, 0.45, 1.0)
	for i in 4:
		var arrow := MeshInstance3D.new()
		arrow.mesh = MeshKit.cone()
		arrow.material_override = MeshKit.toon(color, {"unshaded": true})
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.scale = Vector3(0.18, 0.3, 0.18)
		arrow.rotation_degrees = Vector3(0, 0, 0 if up else 180)
		parent.add_child(arrow)
		var offset := Vector3(cos(i * PI * 0.5) * 0.55, 0.3 if up else 1.5, sin(i * PI * 0.5) * 0.55)
		arrow.global_position = pos + offset
		var tween := arrow.create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_property(arrow, "global_position", pos + offset + Vector3(0, 1.0 if up else -1.0, 0), 0.5)
		tween.tween_callback(arrow.queue_free)


static func _make_particles(parent: Node3D, pos: Vector3, color: Color, amount: int, lifetime: float, one_shot := true) -> CPUParticles3D:
	if _particle_mesh == null:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 3
		_particle_mesh = m
		_particle_material = StandardMaterial3D.new()
		_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_particle_material.vertex_color_use_as_albedo = true
		_particle_material.vertex_color_is_srgb = true
		_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var p := CPUParticles3D.new()
	p.mesh = _particle_mesh
	p.material_override = _particle_material
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.3))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = gradient
	parent.add_child(p)
	p.position = pos if parent is Node3D and not one_shot else Vector3.ZERO
	if one_shot:
		p.global_position = pos
		p.emitting = true
		p.finished.connect(p.queue_free)
	return p


static func _flash_light(parent: Node3D, pos: Vector3, color: Color, energy := 2.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 4.0
	parent.add_child(light)
	light.global_position = pos
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)
