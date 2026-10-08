class_name VfxArt
extends RefCounted
## The "pretty" layer of skill effects: procedural textures (rune circle,
## sparkle, leaf, snowflake), floating motes (embers, snow, leaves, light),
## sky strikes, beams, spirals and X-slashes. Built on [VfxKit]'s helpers.

static var _tex: Dictionary = {}


## Generate every texture once (call while a zone loads so the first cast never hitches).
static func warm_up() -> void:
	for kind in ["rune", "star", "leaf", "snow", "diamond", "heart", "petal", "flame", "crest_vagabond", "crest_warrior", "crest_archer", "crest_mage", "crest_priest", "crest_summoner"]:
		texture(kind)


static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var size := 160 if kind == "rune" or kind.begins_with("crest_") else 64
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
				"heart":
					var q := Vector2(p.x, -p.y + 0.2)
					var h := pow(q.x * q.x + q.y * q.y - 0.42, 3.0) - q.x * q.x * q.y * q.y * q.y
					a = smoothstep(0.02, -0.02, h)
				"petal": a = smoothstep(1.0, 0.8, pow(p.x * 1.5, 2.0) + pow(p.y * 0.95, 2.0))
				"flame":
					var width := maxf(0.02, (1.0 - p.y) * (p.y + 1.0) * 0.56)
					a = smoothstep(width, width * 0.68, absf(p.x + sin(p.y * 3.0) * 0.1)) * smoothstep(-1.0, -0.75, p.y)
				_:
					if kind.begins_with("crest_"):
						a = _crest_alpha(p, kind.trim_prefix("crest_"))
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


## Class emblems use generous negative space, so enemy telegraphs stay legible.
static func _crest_alpha(p: Vector2, family: String) -> float:
	var r := p.length()
	var a := maxf(_band(r, 0.92, 0.018), _band(r, 0.82, 0.012) * 0.65)
	var angle := atan2(p.y, p.x)
	match family:
		"warrior":
			var vertices := [Vector2(-0.39, -0.42), Vector2(0.39, -0.42), Vector2(0.34, 0.15), Vector2(0, 0.56), Vector2(-0.34, 0.15)]
			for i in vertices.size():
				a = maxf(a, smoothstep(0.035, 0.012, _seg_dist(p, vertices[i], vertices[(i + 1) % vertices.size()])))
			a = maxf(a, smoothstep(0.028, 0.01, _seg_dist(p, Vector2(0, -0.25), Vector2(0, 0.35))))
		"archer":
			a = maxf(a, _band(r, 0.55, 0.024) if absf(p.x) > 0.22 else 0.0)
			for k in 8:
				var c := ang_point(0.57, 35.0 + float(k) * 45.0)
				a = maxf(a, smoothstep(0.10, 0.065, p.distance_to(c)))
			a = maxf(a, smoothstep(0.032, 0.01, _seg_dist(p, Vector2(0, 0.38), Vector2(0, -0.4))))
			for sign_x in [-1.0, 1.0]:
				a = maxf(a, smoothstep(0.035, 0.012, _seg_dist(p, Vector2(0, -0.4), Vector2(sign_x * 0.2, -0.12))))
		"mage":
			a = maxf(a, _band(r, 0.52, 0.024))
			for k in 5:
				a = maxf(a, smoothstep(0.03, 0.01, _seg_dist(p, ang_point(0.51, k * 72.0 - 90.0), ang_point(0.51, (k + 2) * 72.0 - 90.0))))
		"priest":
			a = maxf(a, _band(r, 0.23, 0.024))
			var petal_edge := 0.43 + 0.13 * cos(angle * 6.0)
			a = maxf(a, _band(r, petal_edge, 0.028))
		"summoner":
			# A paw: one pad and four toes.
			a = maxf(a, smoothstep(0.30, 0.26, p.distance_to(Vector2(0, 0.18))) * 0.9)
			for toe in [Vector2(-0.36, -0.12), Vector2(-0.14, -0.38), Vector2(0.14, -0.38), Vector2(0.36, -0.12)]:
				a = maxf(a, smoothstep(0.13, 0.09, p.distance_to(toe)))
		_:
			a = maxf(a, _band(absf(p.x) + absf(p.y), 0.48, 0.028))
	for k in 4:
		a = maxf(a, smoothstep(0.048, 0.022, p.distance_to(ang_point(0.72, k * 90.0))))
	return a


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

## A glowing rune circle lying on the ground that spins, swells and fades.
static func rune_circle(parent: Node3D, pos: Vector3, color: Color, radius: float, duration := 0.9, spin := 1.0) -> void:
	if not VfxBudget.can_decorate(2):
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	# Alpha-blended (not additive) so the lines keep their colour on bright grass.
	var mat := VfxKit._glow(color.darkened(0.12), 0.95, false)
	mat.albedo_texture = texture("rune")
	var mi := VfxKit._instance(parent, quad, mat, pos + Vector3(0, 0.07, 0))
	VfxBudget.track_decoration(mi)
	mi.rotation_degrees = Vector3(-90, 0, 0)
	mi.scale = Vector3.ONE * radius * 0.2
	var halo_mat := VfxKit._glow(color, 0.10)
	halo_mat.albedo_texture = VfxKit.soft_dot()
	var halo := VfxKit._instance(parent, quad, halo_mat, pos + Vector3(0, 0.05, 0))
	VfxBudget.track_decoration(halo)
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
		"leaf", "petal", "heart", "flame", "diamond": mat.albedo_texture = texture(kind)
		_: mat.albedo_texture = texture("star")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if kind != "leaf" else BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.mesh = quad
	var reserved := VfxBudget.track_particles(p, count)
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
		"leaf", "petal", "heart":
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
	p.emitting = reserved
	parent.get_tree().create_timer(lifetime + 0.4).timeout.connect(p.queue_free)


## A thick light column that slams down, with a flare and a ring at its foot.
static func sky_strike(parent: Node3D, pos: Vector3, color: Color, width := 1.4, height := 14.0, duration := 0.5) -> void:
	if not VfxBudget.can_decorate(2):
		return
	var outer_mat := VfxKit._glow(color, 0.3, false)
	var outer := VfxKit._instance(parent, MeshKit.cylinder(), outer_mat, pos + Vector3(0, height * 0.5, 0))
	VfxBudget.track_decoration(outer)
	outer.scale = Vector3(width * 0.4, height, width * 0.4)
	var core_mat := VfxKit._glow(Color(1, 1, 1), 0.95)
	var core := VfxKit._instance(parent, MeshKit.cylinder(), core_mat, pos + Vector3(0, height * 0.5, 0))
	VfxBudget.track_decoration(core)
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


## Continuous silk ribbons: two draw calls instead of 28 separately tweened beads.
static func ribbon_spiral(parent: Node3D, pos: Vector3, color: Color, height := 3.2, turns := 2.5, duration := 0.9, radius := 0.9) -> void:
	for strand in (1 if VfxBudget.quality() == 0 else 2):
		if not VfxBudget.can_decorate():
			break
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 24 if VfxBudget.quality() == 0 else 48
		for i in steps:
			var points: Array[Vector3] = []
			for j in 2:
				var t := float(i + j) / float(steps)
				var angle := t * TAU * turns + float(strand) * PI
				var center := Vector3(cos(angle) * radius, t * height + 0.1, sin(angle) * radius)
				var half := 0.065 * sin(PI * t)
				points.append(center - Vector3.UP * half)
				points.append(center + Vector3.UP * half)
			for k in [0, 1, 2, 2, 1, 3]:
				st.add_vertex(points[k])
		var mat := VfxKit._glow(color.lerp(Color.WHITE, 0.15), 0.75, false)
		var ribbon := VfxKit._instance(parent, st.commit(), mat, pos)
		VfxBudget.track_decoration(ribbon)
		ribbon.scale = Vector3(0.6, 0.25, 0.6)
		var tween := ribbon.create_tween().set_parallel(true)
		tween.tween_property(ribbon, "scale", Vector3.ONE, duration * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ribbon, "rotation:y", PI * 0.8, duration)
		tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.65).set_delay(duration * 0.35)
		tween.chain().tween_callback(ribbon.queue_free)


## A fine class seal, with no opaque centre or screen-filling glow.
static func crest(parent: Node3D, pos: Vector3, color: Color, family: String, radius := 1.8, duration := 0.65, phase := 0.0) -> void:
	if not VfxBudget.can_decorate():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	var mat := VfxKit._glow(color, 0.8, false)
	mat.albedo_texture = texture("crest_" + family)
	var seal := VfxKit._instance(parent, quad, mat, pos + Vector3(0, 0.085, 0))
	VfxBudget.track_decoration(seal)
	seal.rotation = Vector3(-PI * 0.5, 0, phase)
	seal.scale = Vector3.ONE * radius * 0.55
	var tween := seal.create_tween().set_parallel(true)
	tween.tween_property(seal, "scale", Vector3.ONE * radius, minf(duration * 0.35, 0.22)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "rotation:z", phase + 0.25, duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tween.chain().tween_callback(seal.queue_free)


## Floating petals / leaves / shield gems grow outwards, leaving the face visible.
static func bloom(parent: Node3D, pos: Vector3, color: Color, kind: String, radius := 1.1, count := 6, duration := 0.7, phase := 0.0) -> void:
	var visible_count := VfxBudget.count(count, 3)
	for i in visible_count:
		if not VfxBudget.can_decorate():
			break
		var angle := TAU * float(i) / float(visible_count) + phase
		var direction := Vector3(cos(angle), 0, sin(angle))
		var quad := QuadMesh.new()
		quad.size = Vector2(0.45, 0.75)
		var mat := VfxKit._glow(color, 0.8, false)
		mat.albedo_texture = texture(kind)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var petal := VfxKit._instance(parent, quad, mat, pos + direction * radius * 0.4 + Vector3(0, 0.5, 0))
		VfxBudget.track_decoration(petal)
		petal.scale = Vector3.ONE * 0.15
		var tween := petal.create_tween().set_parallel(true)
		tween.tween_property(petal, "global_position", pos + direction * radius + Vector3(0, 1.7, 0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(petal, "scale", Vector3.ONE, duration * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
		tween.chain().tween_callback(petal.queue_free)


## Two crossing crescents: the warrior's signature finishing cut.
static func cross_slash(parent: Node3D, pos: Vector3, yaw: float, color: Color, size := 3.0) -> void:
	VfxKit.slash_arc(parent, pos, yaw, color, size, -0.7)
	parent.create_tween().tween_interval(0.07).finished.connect(func():
		if is_instance_valid(parent):
			VfxKit.slash_arc(parent, pos, yaw, color, size, 0.7)
			star_flash(parent, pos, color, size * 0.9))
