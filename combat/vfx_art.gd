class_name VfxArt
extends RefCounted
## The "pretty" layer of skill effects: procedural textures (rune circle,
## sparkle, leaf, snowflake), floating motes (embers, snow, leaves, light),
## sky strikes, beams, spirals and X-slashes. Built on [VfxKit]'s helpers.

static var _tex: Dictionary = {}
const SPIRAL_CACHE_LIMIT := 32
static var _spiral_meshes: Dictionary = {}


## Generate every texture once (call while a zone loads so the first cast never hitches).
## With a `slicer` (the SceneTree) the work yields a frame every few items, so the first
## zone of a session does not stall the page in one go.
static func warm_up(slicer: SceneTree = null) -> void:
	for kind in ["rune", "star", "leaf", "snow", "diamond", "heart", "petal", "flame", "spark", "smoke", "flare", "crest_vagabond", "crest_warrior", "crest_archer", "crest_mage", "crest_priest", "crest_summoner", "crest_lancer", "crest_defender"]:
		texture(kind)
		await FrameSlicer.pace(slicer)
	for recipe in SkillArtDirection.RECIPES.values():
		_signature_mesh(String(recipe[0]), VfxBudget.count(int(recipe[2]), 1), float(recipe[3]))
		await FrameSlicer.pace(slicer)


static func texture(kind: String) -> Texture2D:
	# Original CC0 textures retain their fine painted / smoky edges. Procedural
	# icons below still provide class-specific leaves, snow and rune insignias.
	if kind in ["smoke", "spark", "flare", "flame"]:
		return SpectacleAssets.tex(kind)
	if _tex.has(kind):
		return _tex[kind]
	var size := 160 if kind == "rune" else (192 if kind.begins_with("crest_") else 64)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2((x + 0.5) / size * 2.0 - 1.0, (y + 0.5) / size * 2.0 - 1.0)
			var a := 0.0
			match kind:
				"rune": a = _rune_alpha(p)
				"star", "spark": a = _star_alpha(p)
				"flare":
					var r := p.length()
					a = pow(maxf(1.0 - r, 0.0), 2.3) * 0.65 + _star_alpha(p) * 0.35
				"smoke":
					var edge := p.length() + 0.085 * sin(p.x * 18.0) * sin(p.y * 13.0)
					a = smoothstep(0.98, 0.15, edge) * (0.64 + sin(p.x * 7.0 + p.y * 5.0) * 0.14)
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
## Strokes are drawn 5-7 px wide at the texture's 192 px, so every one of the
## eight seals still reads once mipmapped on a phone.
static func _crest_alpha(p: Vector2, family: String) -> float:
	var r := p.length()
	var a := maxf(_band(r, 0.92, 0.03), _band(r, 0.80, 0.02) * 0.7)
	var angle := atan2(p.y, p.x)
	var line := 0.06
	var fine := 0.05
	match family:
		"warrior":
			var vertices := [Vector2(-0.39, -0.42), Vector2(0.39, -0.42), Vector2(0.34, 0.15), Vector2(0, 0.56), Vector2(-0.34, 0.15)]
			for i in vertices.size():
				a = maxf(a, smoothstep(line, line * 0.4, _seg_dist(p, vertices[i], vertices[(i + 1) % vertices.size()])))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(0, -0.25), Vector2(0, 0.35))))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(-0.16, -0.05), Vector2(0.16, -0.05))))
		"archer":
			a = maxf(a, _band(r, 0.55, 0.035) if absf(p.x) > 0.22 else 0.0)
			for k in 8:
				var c := ang_point(0.57, 35.0 + float(k) * 45.0)
				a = maxf(a, smoothstep(0.11, 0.07, p.distance_to(c)))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(0, 0.38), Vector2(0, -0.4))))
			for sign_x in [-1.0, 1.0]:
				a = maxf(a, smoothstep(line, line * 0.4, _seg_dist(p, Vector2(0, -0.4), Vector2(sign_x * 0.2, -0.12))))
		"mage":
			a = maxf(a, _band(r, 0.52, 0.035))
			for k in 5:
				a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, ang_point(0.51, k * 72.0 - 90.0), ang_point(0.51, (k + 2) * 72.0 - 90.0))))
		"priest":
			a = maxf(a, _band(r, 0.22, 0.035))
			var petal_edge := 0.43 + 0.13 * cos(angle * 6.0)
			a = maxf(a, _band(r, petal_edge, 0.04))
		"lancer":
			# A spearhead pointing up over a crossing shaft.
			var tip_pts := [Vector2(0, -0.58), Vector2(0.2, -0.12), Vector2(0, 0.02), Vector2(-0.2, -0.12)]
			for i in tip_pts.size():
				a = maxf(a, smoothstep(line, line * 0.4, _seg_dist(p, tip_pts[i], tip_pts[(i + 1) % tip_pts.size()])))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(0, 0.0), Vector2(0, 0.58))))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(-0.22, 0.1), Vector2(0.22, 0.1))))
		"defender":
			# A heater shield with a boss in the middle and a cross on its face.
			var rim := [Vector2(-0.42, -0.5), Vector2(0.42, -0.5), Vector2(0.4, 0.05), Vector2(0, 0.58), Vector2(-0.4, 0.05)]
			for i in rim.size():
				a = maxf(a, smoothstep(line, line * 0.4, _seg_dist(p, rim[i], rim[(i + 1) % rim.size()])))
			a = maxf(a, smoothstep(0.17, 0.12, p.distance_to(Vector2(0, -0.08))))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(0, -0.38), Vector2(0, 0.42))))
			a = maxf(a, smoothstep(fine, fine * 0.4, _seg_dist(p, Vector2(-0.28, -0.08), Vector2(0.28, -0.08))))
		"summoner":
			# A paw: one pad and four toes.
			a = maxf(a, smoothstep(0.30, 0.25, p.distance_to(Vector2(0, 0.18))) * 0.9)
			for toe in [Vector2(-0.36, -0.12), Vector2(-0.14, -0.38), Vector2(0.14, -0.38), Vector2(0.36, -0.12)]:
				a = maxf(a, smoothstep(0.14, 0.09, p.distance_to(toe)))
		_:
			# Traveller: a compass diamond with a smaller one turning inside.
			a = maxf(a, _band(absf(p.x) + absf(p.y), 0.48, 0.04))
			a = maxf(a, _band(maxf(absf(p.x), absf(p.y)), 0.22, 0.035))
	for k in 4:
		a = maxf(a, smoothstep(0.06, 0.03, p.distance_to(ang_point(0.72, k * 90.0))))
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
	if reserved:
		p.create_tween().tween_interval(lifetime + 0.4).finished.connect(p.queue_free, CONNECT_ONE_SHOT)
	else:
		p.queue_free()  # budget spent: never shown, and a disabled node's tween would never free it


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
	if dir.length() < 0.05 or not VfxBudget.can_decorate(2):
		return
	var mid := (from + to) * 0.5
	var outer_mat := VfxKit._glow(color, 0.6)
	var outer := VfxKit._instance(parent, MeshKit.box(), outer_mat, mid)
	VfxBudget.track_decoration(outer)
	outer.scale = Vector3(width, width, dir.length())
	outer.look_at_from_position(mid, to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
	var core_mat := VfxKit._glow(Color(1, 1, 1), 1.0)
	var core := VfxKit._instance(parent, MeshKit.box(), core_mat, mid)
	VfxBudget.track_decoration(core)
	core.scale = Vector3(width * 0.35, width * 0.35, dir.length())
	core.look_at_from_position(mid, to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
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
	if not VfxBudget.can_decorate():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mat := VfxKit._glow(color.lerp(Color("fff3d5"), 0.24), 0.82, false)
	mat.albedo_texture = texture("star")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mi := VfxKit._instance(parent, quad, mat, pos)
	VfxBudget.track_decoration(mi)
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
		var steps := 24 if VfxBudget.quality() == 0 else 48
		var mat := VfxKit._glow(color.lerp(Color.WHITE, 0.15), 0.75, false)
		var ribbon := VfxKit._instance(parent, _spiral_mesh(height, turns, radius, strand, steps), mat, pos)
		VfxBudget.track_decoration(ribbon)
		ribbon.scale = Vector3(0.6, 0.25, 0.6)
		var tween := ribbon.create_tween().set_parallel(true)
		tween.tween_property(ribbon, "scale", Vector3.ONE, duration * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ribbon, "rotation:y", PI * 0.8, duration)
		tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.65).set_delay(duration * 0.35)
		tween.chain().tween_callback(ribbon.queue_free)


static func _spiral_mesh(height: float, turns: float, radius: float, strand: int, steps: int) -> ArrayMesh:
	# Exact parameter keys retain the shape even for future dynamic-height
	# callers. A small FIFO bounds memory instead of caching every random value.
	var key := var_to_bytes([height, turns, radius, strand, steps]).hex_encode()
	if _spiral_meshes.has(key):
		return _spiral_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
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
	var mesh := st.commit()
	if _spiral_meshes.size() >= SPIRAL_CACHE_LIMIT:
		_spiral_meshes.erase(_spiral_meshes.keys()[0])
	_spiral_meshes[key] = mesh
	return mesh


## A fine class seal, with no opaque centre or screen-filling glow.
static func crest(parent: Node3D, pos: Vector3, color: Color, family: String, radius := 1.8, duration := 0.65, phase := 0.0) -> void:
	if not VfxBudget.can_decorate():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 2.0
	var mat := VfxKit._glow(color, 0.92, false)
	mat.albedo_texture = texture("crest_" + family)
	var seal := VfxKit._instance(parent, quad, mat, pos + Vector3(0, 0.085, 0))
	VfxBudget.track_decoration(seal)
	seal.rotation = Vector3(-PI * 0.5, 0, phase)
	seal.scale = Vector3.ONE * radius * 0.55
	var tween := seal.create_tween().set_parallel(true)
	tween.tween_property(seal, "scale", Vector3.ONE * radius, minf(duration * 0.35, 0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(seal, "rotation:z", phase + 0.45, duration)
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


# ---------------------------------------------------------------------------
# Art-directed brushwork. One shared mesh and one material per signature.
# Every line has a tapered body and a pearl seam, with no solid centre fill.
# ---------------------------------------------------------------------------
const ART_BRUSH := preload("res://shaders/skill_art_brush.gdshader")
static var _art_meshes: Dictionary = {}


static func _art_material(look: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ART_BRUSH
	mat.set_shader_parameter("ink", look.primary)
	mat.set_shader_parameter("pearl", look.accent)
	mat.set_shader_parameter("shade", look.shade)
	return mat


## One visible, authored silhouette for a skill. The shared recipe cache changes
## only with art parameters, never caster position or random seeds.
static func signature(parent: Node3D, skill: Dictionary, look: Dictionary, at: Vector3, origin: Vector3, tier: int) -> void:
	if not VfxBudget.can_decorate():
		return
	var count := clampi(VfxBudget.count(int(look.strokes), 1), 1, 8)
	var recipe := String(look.recipe)
	var shape := String(skill.shape)
	var direction := at - origin
	var yaw := atan2(direction.x, direction.z) if direction.length_squared() > 0.01 else float(look.phase)
	var duration := float(look.tempo)
	var mat := _art_material(look)
	var mesh := _signature_mesh(recipe, count, float(look.curvature))
	var pos := at + Vector3(0, 0.12, 0)
	var radius := minf(float(skill.get("radius", 2.0)) * 0.76, 7.0)
	var size := Vector3(radius, 1.7, radius)
	if shape in ["self", "summon"]:
		pos = origin + Vector3(0, 0.12, 0)
		size = Vector3(1.8, 1.9, 1.8)
	elif shape in ["single", "fan", "chain"]:
		# Launch ornaments never promise a hit before the gameplay projectile.
		pos = origin + Vector3(0, 1.0, 0)
		size = Vector3(1.3, 1.3, 1.8)
		if recipe == "lance" and not bool(skill.get("projectile", false)):
			var pierce: Dictionary = skill.get("pierce", {})
			var reach := float(pierce.get("len", minf(direction.length() + 0.7, 4.2)))
			size = Vector3(0.68 + float(tier) * 0.06, 0.8, reach)
		elif not bool(skill.get("projectile", false)) and shape == "single":
			pos = origin + direction.normalized() * minf(direction.length(), 1.7) + Vector3(0, 0.75, 0)
			size = Vector3(1.8, 1.35, 1.8)
		elif recipe in ["arrow", "bolt"]:
			size = Vector3(1.0, 1.0, 2.25)
	var art := VfxKit._instance(parent, mesh, mat, pos)
	VfxBudget.track_decoration(art)
	art.rotation.y = yaw if shape in ["single", "fan", "chain"] else float(look.phase)
	var start_scale := Vector3(0.80, 0.70, 0.80)
	art.scale = size * start_scale
	var tween := art.create_tween().set_parallel(true)
	tween.tween_property(art, "scale", size, duration * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.05, 1.0, duration * 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.90, 0.0, duration * 0.56).set_delay(duration * 0.44)
	if recipe in ["gale", "sweep", "tide", "sigil", "summon"]:
		tween.tween_property(art, "rotation:y", art.rotation.y + float(look.curvature) * 0.75, duration)
	elif shape in ["self", "summon"]:
		tween.tween_property(art, "position:y", art.position.y + 0.35, duration).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(art.queue_free)


## Used by melee's base presentation too: replaces four overlapping crescents
## with one coloured brushstroke, retaining the exact caller position/duration.
static func painted_slash(parent: Node3D, pos: Vector3, yaw: float, color: Color, size: float, tilt: float) -> void:
	if not VfxBudget.can_decorate():
		return
	var look := {"primary": color.lerp(Color("e9b8a0"), 0.16), "accent": color.lerp(Color("fff2cd"), 0.64), "shade": color.darkened(0.30)}
	var mat := _art_material(look)
	var slash := VfxKit._instance(parent, _signature_mesh("cut", 1, -0.55), mat, pos)
	VfxBudget.track_decoration(slash)
	slash.rotation = Vector3(0, yaw, tilt)
	slash.scale = Vector3.ONE * size * 0.74
	var tween := slash.create_tween().set_parallel(true)
	tween.tween_property(slash, "scale", Vector3.ONE * size * 1.12, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.16)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.95, 0.0, 0.24).set_delay(0.08)
	tween.chain().tween_callback(slash.queue_free)


static func _signature_mesh(recipe: String, count: int, curve: float) -> ArrayMesh:
	var key := "%s:%d:%.2f" % [recipe, count, curve]
	if _art_meshes.has(key):
		return _art_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in count:
		var paths: Array = []
		var path: Array[Vector3] = []
		var angle := TAU * float(k) / float(count)
		var radial := Vector3(cos(angle), 0, sin(angle))
		var tangent := Vector3(-sin(angle), 0, cos(angle))
		var lane := float(k) - float(count - 1) * 0.5
		var width := 0.095
		for i in 25:
			var t := float(i) / 24.0
			var point := Vector3.ZERO
			match recipe:
				"cut", "crosscut", "sweep":
					var arc := lerpf(-1.30, 1.30, t) + (angle if recipe == "sweep" else float(k) * 0.32)
					var r := 0.70 + float(k) * 0.07
					point = Vector3(sin(arc) * r, 0.08 + sin(t * PI) * 0.18, cos(arc) * r)
					if recipe == "crosscut":
						point.y += point.x * (0.55 if k % 2 == 0 else -0.55)
					else:
						point.y += point.x * curve * 0.28
					width = 0.16 if recipe != "sweep" else 0.11
				"lance", "arrow":
					point = Vector3(lane * 0.16 + sin(t * PI) * curve * (0.22 + absf(lane) * 0.18), sin(t * PI) * curve * 0.10, t)
					width = 0.11 if k == count / 2 else 0.065
				"wings":
					var side := -1.0 if k % 2 == 0 else 1.0
					var feather := float(k / 2)
					point = Vector3(side * (0.13 + t * (1.25 - feather * 0.12)), sin(t * PI * 0.75) * (0.72 - feather * 0.10) + 0.25, -sin(t * PI) * 0.32 + feather * 0.16 + curve * t * 0.18)
					width = 0.15 - feather * 0.012
				"bloom":
					# Open lotus petals, rising only at the outside to frame the hero.
					var petal_r := 0.20 + sin(t * PI) * 0.78
					point = radial * petal_r + tangent * sin(t * TAU) * 0.19 + Vector3.UP * (sin(t * PI) * (0.45 + curve * 0.20))
					width = 0.12
				"guard":
					var perimeter := [Vector2(-0.19, 0.54), Vector2(0.19, 0.54), Vector2(0.16, 0.20), Vector2(0, 0.04), Vector2(-0.16, 0.20), Vector2(-0.19, 0.54)]
					var section := minf(t * 5.0, 4.999)
					var p: Vector2 = perimeter[int(section)].lerp(perimeter[int(section) + 1], fposmod(section, 1.0))
					point = radial * 0.63 + tangent * p.x + Vector3.UP * (p.y + 0.10)
					width = 0.060
				"crown":
					point = radial * (0.52 + sin(t * PI) * 0.18) + tangent * sin(t * TAU) * 0.12 + Vector3.UP * (0.25 + sin(t * PI) * 0.70)
					width = 0.090
				"gale", "tide", "summon":
					var a := angle + t * PI * (1.15 + absf(curve))
					var r := 0.36 + t * 0.60
					point = Vector3(cos(a) * r, 0.05 + t * (0.66 if recipe == "tide" else 0.38), sin(a) * r)
					width = 0.11 if recipe != "summon" else 0.075
				"ember", "meteor":
					point = radial * (0.30 + t * 0.62) + tangent * (sin(t * TAU) * 0.10 + t * curve * 0.28) + Vector3.UP * sin(t * PI) * (0.70 if recipe == "ember" else 0.95)
					width = 0.15
				"ice":
					var diamond := [Vector2(0.25, 0.05), Vector2(0.58, 0.90), Vector2(0.77, 0.22), Vector2(0.25, 0.05)]
					var section := minf(t * 3.0, 2.999)
					var p: Vector2 = diamond[int(section)].lerp(diamond[int(section) + 1], fposmod(section, 1.0))
					point = radial * p.x + Vector3.UP * p.y + tangent * curve * 0.12
					width = 0.085
				"sigil":
					var a := angle + t * PI * 1.35
					point = Vector3(cos(a) * (0.50 + float(k % 2) * 0.28), sin(t * PI) * 0.25, sin(a) * (0.50 + float(k % 2) * 0.28))
					point.y += sin(a * 2.0) * curve * 0.25
					width = 0.075
				"bolt":
					var jag := sin(floor(t * 8.0) * 2.4 + float(k)) * 0.12 * sin(t * PI)
					point = Vector3(lane * 0.22 + jag, sin(t * PI) * curve * 0.15, t)
					width = 0.070
				"sun", "rain":
					point = radial * (0.45 + t * 0.40) + tangent * sin(t * PI) * curve * 0.18 + Vector3.UP * (1.25 - t * 1.15)
					width = 0.070 if recipe == "rain" else 0.11
				"vines":
					point = radial * (0.18 + t * 0.78) + tangent * sin(t * TAU * 1.35) * 0.14 + Vector3.UP * (sin(t * PI) * 0.42 + sin(t * TAU) * curve * 0.12)
					width = 0.095
				"quake":
					point = radial * (0.24 + t * 0.72) + tangent * sin(floor(t * 6.0) * 2.8) * 0.08 + Vector3.UP * sin(t * PI) * 0.08
					width = 0.11
				"roar":
					var arc := angle + lerpf(-0.65, 0.65, t)
					point = Vector3(cos(arc), 0.15 + sin(t * PI) * 0.25, sin(arc)) * (0.65 + float(k % 2) * 0.22)
					width = 0.12
				_:
					point = radial * t + Vector3.UP * sin(t * PI) * 0.25
			path.append(point)
		paths.append(path)
		if recipe in ["arrow", "lance"]:
			# A long barb reads as a spear/arrow even with particles disabled.
			var tip: Vector3 = path.back()
			for side in [-1.0, 1.0]:
				var barb: Array[Vector3] = [tip + Vector3(side * 0.18, 0, -0.20), tip + Vector3(side * 0.08, 0.015, -0.06), tip]
				paths.append(barb)
		for line in paths:
			_append_brush(st, line, width)
	var result := st.commit()
	_art_meshes[key] = result
	return result


static func _append_brush(st: SurfaceTool, path: Array, width: float) -> void:
	for i in path.size() - 1:
		var vertices: Array[Vector3] = []
		for j in 2:
			var index := i + j
			var t := float(index) / float(path.size() - 1)
			var direction: Vector3 = path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]
			var normal := direction.cross(Vector3.UP).normalized()
			if normal.length_squared() < 0.01:
				normal = Vector3.RIGHT
			# A raised seam makes the stroke visible at both low and high camera angles.
			normal = (normal + Vector3.UP * 0.38).normalized()
			var half := width * pow(maxf(sin(t * PI), 0.02), 0.60)
			vertices.append(path[index] - normal * half)
			vertices.append(path[index] + normal * half)
		for corner in [0, 1, 2, 2, 1, 3]:
			st.set_uv(Vector2(float(i + corner / 2) / float(path.size() - 1), float(corner % 2)))
			st.add_vertex(vertices[corner])


## Each branched bolt uses a narrow luminous core over a wider colored corona.
## The branching paths are batched, so its silhouette costs two draw calls.
static func painted_lightning(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	if not VfxBudget.can_decorate() or from.distance_squared_to(to) < 0.001:
		return
	var delta := to - from
	var side := delta.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var points: Array[Vector3] = [Vector3.ZERO]
	var segments := VfxBudget.count(12, 6)
	for i in range(1, segments):
		var t := float(i) / float(segments)
		points.append(delta * t + side * randf_range(-0.46, 0.46) * sin(t * PI) + Vector3.UP * randf_range(-0.18, 0.18))
	points.append(delta)
	var paths: Array = [points]
	if VfxBudget.quality() > 0:
		for i in [segments / 3, segments * 2 / 3]:
			var origin: Vector3 = points[i]
			var direction := side * (-1.0 if i % 2 == 0 else 1.0)
			var fork: Array[Vector3] = [origin, origin + delta.normalized() * 0.3 + direction * 0.65, origin + delta.normalized() * 0.85 + direction * 1.1 + Vector3.UP * 0.28]
			paths.append(fork)
	# The core goes first so reduced quality always preserves the bright bolt.
	for layer in 2:
		if not VfxBudget.can_decorate():
			break
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in paths.size():
			_append_brush(st, paths[i], (0.075 if layer == 0 else 0.22) * (1.0 if i == 0 else 0.45))
		var mat := VfxKit._glow(color.lerp(Color("edf7ff"), 0.82) if layer == 0 else color, 0.96 if layer == 0 else 0.4, layer == 0)
		var bolt := VfxKit._instance(parent, st.commit(), mat, from)
		VfxBudget.track_decoration(bolt)
		var tween := bolt.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.18 if layer == 0 else 0.10, 0.07)
		tween.tween_property(mat, "albedo_color:a", 0.95 if layer == 0 else 0.38, 0.035)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.20)
		tween.tween_callback(bolt.queue_free)
