class_name VfxArt
extends RefCounted
## The "pretty" layer of skill effects: procedural textures (rune circle,
## sparkle, leaf, snowflake), floating motes (embers, snow, leaves, light),
## sky strikes, beams, spirals and X-slashes. Built on [VfxKit]'s helpers.

static var _tex: Dictionary = {}


## Generate every texture once (call while a zone loads so the first cast never hitches).
static func warm_up() -> void:
	for kind in ["rune", "star", "leaf", "snow", "diamond"]:
		texture(kind)


static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var size := 160 if kind == "rune" else 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size * 2.0 - 1.0, (y + 0.5) / size * 2.0 - 1.0)
			var a := 0.0
			match kind:
				"rune": a = _rune_alpha(p)
				"star": a = _star_alpha(p)
				"leaf": a = _leaf_alpha(p)
				"snow": a = _snow_alpha(p)
				"diamond": a = _diamond_alpha(p)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex[kind] = tex
	return tex


static func _band(r: float, center: float, half_width: float) -> float:
	return smoothstep(half_width, half_width * 0.35, absf(r - center))


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _rune_alpha(p: Vector2) -> float:
	var r := p.length()
	if r > 1.0:
		return 0.0
	var a := _band(r, 0.95, 0.045)
	a = maxf(a, _band(r, 0.88, 0.022))
	a = maxf(a, _band(r, 0.6, 0.032))
	a = maxf(a, _band(r, 0.22, 0.03) * 0.9)
	# Radial ticks between the outer rings.
	var ang := atan2(p.y, p.x)
	if r > 0.64 and r < 0.86:
		var step := TAU / 16.0
		var delta := absf(fposmod(ang + step * 0.5, step) - step * 0.5)
		a = maxf(a, smoothstep(0.045, 0.016, r * sin(delta)) * 0.85)
	# Two triangles make a hexagram.
	for t in 2:
		for k in 3:
			var a0 := ang_point(0.58, (t * 60.0 + k * 120.0))
			var a1 := ang_point(0.58, (t * 60.0 + (k + 1) * 120.0))
			a = maxf(a, smoothstep(0.034, 0.012, _seg_dist(p, a0, a1)) * 0.95)
	# Dots on the middle ring.
	for k in 6:
		var d := p.distance_to(ang_point(0.74, k * 60.0 + 30.0))
		a = maxf(a, smoothstep(0.05, 0.02, d))
	return a


static func ang_point(radius: float, degrees: float) -> Vector2:
	var r := deg_to_rad(degrees)
	return Vector2(cos(r), sin(r)) * radius


static func _star_alpha(p: Vector2) -> float:
	var r := p.length()
	var core := pow(clampf(1.0 - r * 1.4, 0.0, 1.0), 2.0)
	var cross := clampf(1.0 - r, 0.0, 1.0) * (1.0 / (1.0 + 70.0 * absf(p.x) * absf(p.y)))
	var diag := Vector2((p.x + p.y) * 0.707, (p.x - p.y) * 0.707)
	var cross2 := clampf(1.0 - r, 0.0, 1.0) * (1.0 / (1.0 + 140.0 * absf(diag.x) * absf(diag.y))) * 0.5
	return core + cross + cross2


static func _leaf_alpha(p: Vector2) -> float:
	# A pointed leaf along x with a soft edge.
	var u := p.x * 0.9
	if absf(u) > 0.95:
		return 0.0
	var half := 0.5 * pow(1.0 - absf(u) / 0.95, 0.8) * (1.0 - 0.25 * (u + 1.0) * 0.5)
	var edge := smoothstep(half, half * 0.6, absf(p.y))
	var vein := 1.0 - 0.35 * smoothstep(0.03, 0.0, absf(p.y))
	return edge * vein


static func _snow_alpha(p: Vector2) -> float:
	var r := p.length()
	if r > 0.95:
		return 0.0
	var a := 0.0
	for k in 3:
		var dir := ang_point(0.9, k * 60.0)
		a = maxf(a, smoothstep(0.07, 0.02, _seg_dist(p, -dir, dir)))
		# little side barbs on each arm
		for s in [-1.0, 1.0]:
			var base: Vector2 = dir.normalized() * 0.55 * s
			var barb: Vector2 = base + Vector2(-dir.y, dir.x).normalized() * 0.2
			var barb2: Vector2 = base - Vector2(-dir.y, dir.x).normalized() * 0.2
			a = maxf(a, smoothstep(0.05, 0.015, _seg_dist(p, base, barb)))
			a = maxf(a, smoothstep(0.05, 0.015, _seg_dist(p, base, barb2)))
	return maxf(a, smoothstep(0.14, 0.05, r))


static func _diamond_alpha(p: Vector2) -> float:
	var d := absf(p.x) * 1.0 + absf(p.y) * 0.55
	return smoothstep(0.9, 0.7, d) * (0.65 + 0.35 * (1.0 - absf(p.x)))


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

## A glowing rune circle lying on the ground that spins, swells and fades.
static func rune_circle(parent: Node3D, pos: Vector3, color: Color, radius: float, duration := 0.9, spin := 1.0) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	# Alpha-blended (not additive) so the lines keep their colour on bright grass.
	var mat := VfxKit._glow(color.darkened(0.12), 0.95, false)
	mat.albedo_texture = texture("rune")
	var mi := VfxKit._instance(parent, quad, mat, pos + Vector3(0, 0.07, 0))
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.scale = Vector3.ONE * radius * 0.2
	var halo_mat := VfxKit._glow(color, 0.35)
	halo_mat.albedo_texture = VfxKit.soft_dot()
	var halo := VfxKit._instance(parent, quad, halo_mat, pos + Vector3(0, 0.05, 0))
	halo.rotation_degrees = Vector3(-90, 0, 0)
	halo.scale = Vector3.ONE * radius * 1.15
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * radius, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mi, "rotation:z", TAU * 0.35 * spin, duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.tween_property(halo_mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(func():
		mi.queue_free()
		halo.queue_free())


## Floating particles that suit the element: ember, snow, leaf, petal, light.
static func motes(parent: Node3D, pos: Vector3, color: Color, kind: String, count := 24, radius := 2.0, height := 0.0, lifetime := 1.4) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.38, 0.38)
	var mat := VfxKit._glow(color, 1.0, kind in ["ember", "light"])
	match kind:
		"snow": mat.albedo_texture = texture("snow")
		"leaf", "petal": mat.albedo_texture = texture("leaf")
		_: mat.albedo_texture = texture("star")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if kind != "leaf" else BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.mesh = quad
	p.amount = maxi(4, int(count * GameSettings.particle_scale()))
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.55
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE if kind in ["ember", "light"] else CPUParticles3D.EMISSION_SHAPE_BOX
	if p.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE:
		p.emission_sphere_radius = radius
	else:
		p.emission_box_extents = Vector3(radius, 0.3, radius)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.color_ramp = VfxKit._fade_ramp()
	match kind:
		"ember":
			p.direction = Vector3.UP
			p.spread = 35.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, 1.0, 0)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 0.8
		"snow":
			p.direction = Vector3.DOWN
			p.spread = 20.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.4
			p.gravity = Vector3(0.3, -0.8, 0)
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.3
			height += 4.5
		"leaf", "petal":
			p.direction = Vector3.UP
			p.spread = 90.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.5
			p.gravity = Vector3(0.6, -1.2, 0.3)
			p.angular_velocity_min = -260.0
			p.angular_velocity_max = 260.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
		_:
			p.direction = Vector3.UP
			p.spread = 25.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.4
			p.gravity = Vector3(0, 0.6, 0)
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
	parent.add_child(p)
	p.global_position = pos + Vector3(0, height, 0)
	p.emitting = true
	parent.get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)


## A thick light column that slams down, with a flare and a ring at its foot.
static func sky_strike(parent: Node3D, pos: Vector3, color: Color, width := 1.4, height := 14.0, duration := 0.5) -> void:
	var outer_mat := VfxKit._glow(color, 0.55, false)
	var outer := VfxKit._instance(parent, MeshKit.cylinder(), outer_mat, pos + Vector3(0, height * 0.5, 0))
	outer.scale = Vector3(width * 0.4, height, width * 0.4)
	var core_mat := VfxKit._glow(Color(1, 1, 1), 0.95)
	var core := VfxKit._instance(parent, MeshKit.cylinder(), core_mat, pos + Vector3(0, height * 0.5, 0))
	core.scale = Vector3(width * 0.16, height, width * 0.16)
	var tween := outer.create_tween().set_parallel(true)
	tween.tween_property(outer, "scale", Vector3(width, height, width), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "scale", Vector3(width * 0.35, height, width * 0.35), 0.1)
	tween.tween_property(outer, "scale", Vector3(0.05, height, 0.05), duration * 0.6).set_delay(duration * 0.4)
	tween.tween_property(core, "scale", Vector3(0.02, height, 0.02), duration * 0.6).set_delay(duration * 0.4)
	tween.tween_property(outer_mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(func():
		outer.queue_free()
		core.queue_free())
	star_flash(parent, pos + Vector3(0, 0.6, 0), color, width * 3.2)
	VfxKit.shockwave(parent, pos + Vector3(0, 0.1, 0), color, width * 2.4)
	VfxKit.sparks(parent, pos + Vector3(0, 0.4, 0), color, 18, 5.0, 0.6)


## A straight beam between two points (arrows of light, ice lances) that thins and fades.
static func beam(parent: Node3D, from: Vector3, to: Vector3, color: Color, width := 0.35, duration := 0.28) -> void:
	var dir := to - from
	if dir.length() < 0.05:
		return
	var mid := (from + to) * 0.5
	var outer_mat := VfxKit._glow(color, 0.6)
	var outer := VfxKit._instance(parent, MeshKit.box(), outer_mat, mid)
	outer.scale = Vector3(width, width, dir.length())
	outer.look_at_from_position(mid, to, Vector3.UP)
	var core_mat := VfxKit._glow(Color(1, 1, 1), 1.0)
	var core := VfxKit._instance(parent, MeshKit.box(), core_mat, mid)
	core.scale = Vector3(width * 0.35, width * 0.35, dir.length())
	core.look_at_from_position(mid, to, Vector3.UP)
	var tween := outer.create_tween().set_parallel(true)
	tween.tween_property(outer, "scale", Vector3(0.02, 0.02, dir.length()), duration).set_ease(Tween.EASE_IN)
	tween.tween_property(core, "scale", Vector3(0.01, 0.01, dir.length()), duration).set_ease(Tween.EASE_IN)
	tween.tween_property(outer_mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(func():
		outer.queue_free()
		core.queue_free())
	star_flash(parent, to, color, width * 5.0)


## A sparkle (4-point star) that pops and fades.
static func star_flash(parent: Node3D, pos: Vector3, color: Color, size := 2.0, duration := 0.35) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := VfxKit._glow(color.lerp(Color.WHITE, 0.45), 1.0)
	mat.albedo_texture = texture("star")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mi := VfxKit._instance(parent, quad, mat, pos)
	mi.scale = Vector3.ONE * size * 0.3
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * size, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
	tween.chain().tween_callback(mi.queue_free)


## Glowing beads that spiral upwards around [param pos] (buffs, heals, speed-ups).
static func ribbon_spiral(parent: Node3D, pos: Vector3, color: Color, height := 3.2, turns := 2.5, duration := 0.9, radius := 0.9) -> void:
	for strand in 2:
		for i in 14:
			var mat := VfxKit._glow(color.lerp(Color.WHITE, 0.3), 1.0)
			var bead := VfxKit._instance(parent, MeshKit.sphere_low(), mat, pos)
			bead.scale = Vector3.ONE * 0.16 * (1.0 - float(i) / 20.0)
			var delay := float(i) * 0.03
			var phase := float(strand) * PI
			var tween := bead.create_tween()
			tween.tween_interval(delay)
			tween.tween_method(func(t: float):
				var angle := phase + t * TAU * turns
				var rr := radius * (1.0 - 0.25 * t)
				bead.global_position = pos + Vector3(cos(angle) * rr, 0.1 + t * height, sin(angle) * rr)
				mat.albedo_color.a = 1.0 - t * t, 0.0, 1.0, duration)
			tween.tween_callback(bead.queue_free)


## Two crossing crescents: the warrior's signature finishing cut.
static func cross_slash(parent: Node3D, pos: Vector3, yaw: float, color: Color, size := 3.0) -> void:
	VfxKit.slash_arc(parent, pos, yaw, color, size, -0.7)
	parent.get_tree().create_timer(0.07).timeout.connect(func():
		if is_instance_valid(parent):
			VfxKit.slash_arc(parent, pos, yaw, color, size, 0.7)
			star_flash(parent, pos, color, size * 0.9))
