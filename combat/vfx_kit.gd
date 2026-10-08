class_name VfxKit
extends RefCounted
## Skill and combat effects: glowing projectiles with trails, crescent slashes,
## shockwaves, rune circles, light pillars, meteors, lightning, level-up and
## heal bursts. Everything is built from unshaded additive meshes and CPU
## particles (cheap on phones) and frees itself.

static var _crescent: ArrayMesh
static var _disc: CylinderMesh
static var _soft_particle: Mesh


static var _soft_texture: Texture2D


## Unshaded translucent material. [param additive] glows over dark backgrounds;
## solid blending keeps rings and discs visible on bright grass.
static func _glow(color: Color, alpha := 1.0, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.disable_fog = true
	return m


## Round, soft-edged dot used for every particle and orb halo.
static func soft_dot() -> Texture2D:
	if _soft_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.set_offset(0, 0.0)
		gradient.set_offset(1, 1.0)
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_soft_texture = tex
	return _soft_texture


static func _instance(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	return mi


static func _disc_mesh() -> CylinderMesh:
	if _disc == null:
		_disc = CylinderMesh.new()
		_disc.top_radius = 1.0
		_disc.bottom_radius = 1.0
		_disc.height = 0.02
		_disc.radial_segments = 40
		_disc.rings = 1
	return _disc


## A flat crescent (arc of a ring) lying in the XZ plane, opening towards +Z.
static func _crescent_mesh() -> ArrayMesh:
	if _crescent == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var steps := 18
		var span := deg_to_rad(150.0)
		for i in steps:
			var a0 := -span * 0.5 + span * float(i) / steps
			var a1 := -span * 0.5 + span * float(i + 1) / steps
			var thickness0 := 0.18 * sin(PI * float(i) / steps)
			var thickness1 := 0.18 * sin(PI * float(i + 1) / steps)
			var o0 := Vector3(sin(a0), 0, cos(a0)) * 1.0
			var o1 := Vector3(sin(a1), 0, cos(a1)) * 1.0
			var i0 := o0 * (1.0 - thickness0 * 2.2)
			var i1 := o1 * (1.0 - thickness1 * 2.2)
			for v in [o0, i0, o1, o1, i0, i1]:
				st.add_vertex(v)
		_crescent = st.commit()
	return _crescent


static func _particles(parent: Node3D, pos: Vector3, color: Color, amount: int, lifetime: float, one_shot := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := _glow(color, 1.0)
	mat.albedo_texture = soft_dot()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	p.mesh = quad
	var reserved := VfxBudget.track_particles(p, amount)
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.emitting = reserved
	p.local_coords = false
	p.color_ramp = _fade_ramp()
	parent.add_child(p)
	p.global_position = pos
	if one_shot:
		parent.get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)
	return p


static func _textured_quad(tex: Texture2D, color: Color, size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := _glow(color, 1.0)
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	return quad


static func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


## Spark burst: [param amount] glowing bits flying out from [param pos].
static func sparks(parent: Node3D, pos: Vector3, color: Color, amount := 22, speed := 4.0, lifetime := 0.55) -> void:
	var p := _particles(parent, pos, color, amount, lifetime)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2


## A quick bright blob (billboard) that swells and fades: the "pop" of every hit.
static func flash(parent: Node3D, pos: Vector3, color: Color, size := 2.2, duration := 0.28) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var core_mat := _glow(Color(1, 1, 1), 1.0)
	core_mat.albedo_texture = soft_dot()
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mat := _glow(color, 1.0)
	mat.albedo_texture = soft_dot()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo := _instance(parent, quad, mat, pos)
	halo.scale = Vector3.ONE * size * 0.4
	var core := _instance(parent, quad, core_mat, pos)
	core.scale = Vector3.ONE * size * 0.25
	var tween := halo.create_tween().set_parallel(true)
	tween.tween_property(halo, "scale", Vector3.ONE * size * 1.3, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(core, "scale", Vector3.ONE * size * 0.7, duration * 0.8)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, duration * 0.8)
	tween.chain().tween_callback(func():
		halo.queue_free()
		core.queue_free())


## Standard hit: flash + sparks + a small ring.
static func impact(parent: Node3D, pos: Vector3, color: Color, scale := 1.0) -> void:
	flash(parent, pos, color, 2.0 * scale)
	VfxArt.star_flash(parent, pos, color, 2.4 * scale, 0.3)
	sparks(parent, pos, color, int(18 * scale), 5.0 * scale, 0.5)
	sparks(parent, pos, Color.WHITE, int(8 * scale), 3.0 * scale, 0.35)
	var mat := _glow(color, 0.9, false)
	var ring := _instance(parent, MeshKit.torus(), mat, pos)
	ring.scale = Vector3.ONE * 0.2
	ring.rotation = Vector3(randf() * 0.8, randf() * TAU, randf() * 0.8)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.5 * scale, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(ring.queue_free)


# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

## Glowing orb with a particle trail. Travels in a slight arc; awaitable.
static func variant_for(vfx: StringName) -> String:
	return {&"fireball": "flame", &"frost": "shard", &"light": "spark", &"thunder": "spark", &"leaf": "spark"}.get(vfx, "orb")


static func projectile(parent: Node3D, color: Color, from: Vector3, to: Vector3, duration: float, size := 0.5, variant := "orb") -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = from
	if from.distance_to(to) > 0.05:
		holder.look_at_from_position(from, to, Vector3.UP)
	var core := _instance(holder, MeshKit.sphere(), _glow(Color(1, 1, 1), 1.0), from)
	core.scale = Vector3.ONE * size * 0.6
	var halo := _instance(holder, MeshKit.sphere(), _glow(color, 0.9, false), from)
	halo.scale = Vector3.ONE * size * 1.1
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2.ONE * size * 4.5
	var glow_mat := _glow(color, 0.8)
	glow_mat.albedo_texture = soft_dot()
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_instance(holder, glow_quad, glow_mat, from)
	var trail := _particles(holder, from, color, 36, 0.4, false)
	trail.direction = Vector3.ZERO
	trail.spread = 25.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.5
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.6
	trail.scale_amount_max = 1.2
	match variant:
		"flame":
			trail.mesh = _textured_quad(VfxArt.texture("star"), color, 0.5)
			for i in 3:
				var flame := _instance(holder, MeshKit.cone(), _glow(Color("ff8a2a"), 0.8), from)
				flame.scale = Vector3(size * 0.7, size * (2.2 - i * 0.5), size * 0.7)
				flame.rotation_degrees = Vector3(90, 0, 0)
				flame.position = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), size * (0.9 + i * 0.35))
		"shard":
			trail.mesh = _textured_quad(VfxArt.texture("snow"), color, 0.45)
			core.visible = false
			halo.visible = false
			var shard := _instance(holder, MeshKit.cone(), _glow(color.lerp(Color.WHITE, 0.5), 0.95, false), from)
			shard.scale = Vector3(size * 0.45, size * 2.4, size * 0.45)
			shard.rotation_degrees = Vector3(-90, 0, 0)
			var tail := _instance(holder, MeshKit.cone(), _glow(color, 0.8, false), from)
			tail.scale = Vector3(size * 0.45, size * 1.2, size * 0.45)
			tail.rotation_degrees = Vector3(90, 0, 0)
			tail.position = Vector3(0, 0, size * 1.2)
		"spark":
			trail.mesh = _textured_quad(VfxArt.texture("star"), color, 0.5)
			var star_quad := QuadMesh.new()
			star_quad.size = Vector2.ONE * size * 3.2
			var star_mat := _glow(color.lerp(Color.WHITE, 0.4), 1.0)
			star_mat.albedo_texture = VfxArt.texture("star")
			star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			_instance(holder, star_quad, star_mat, from)
	if VfxBudget.can_light():
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.65
		light.omni_range = 2.8
		holder.add_child(light)
		VfxBudget.track_light(light)
	var mid := (from + to) * 0.5 + Vector3(0, minf(0.6, from.distance_to(to) * 0.08), 0)
	var tween := holder.create_tween()
	tween.tween_method(func(t: float):
		holder.global_position = from.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, maxf(duration, 0.05))
	await tween.finished
	flash(parent, to, color, 1.8 + size * 2.0)
	sparks(parent, to, color, 16, 3.5, 0.45)
	holder.queue_free()


## A streaking bolt (arrows): stretched glowing capsule pointed along its path.
static func arrow(parent: Node3D, color: Color, from: Vector3, to: Vector3, duration: float) -> void:
	var dir := (to - from)
	if dir.length() < 0.01:
		return
	var mi := _instance(parent, MeshKit.box(), _glow(color.lerp(Color.WHITE, 0.4), 1.0), from)
	mi.scale = Vector3(0.07, 0.07, 1.5)
	var trail := _instance(mi, MeshKit.box(), _glow(color, 0.35), from)
	trail.scale = Vector3(2.6, 2.6, 3.0)
	trail.position = Vector3(0, 0, -1.3)
	mi.look_at_from_position(from, to, Vector3.UP)
	var tween := mi.create_tween()
	tween.tween_property(mi, "global_position", to, maxf(duration, 0.05))
	await tween.finished
	flash(parent, to, color, 1.6, 0.22)
	sparks(parent, to, color, 12, 3.5, 0.35)
	mi.queue_free()


## A jagged lightning bolt between two points that flashes and fades.
static func lightning(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var points: Array[Vector3] = [from]
	var segments := VfxBudget.count(7, 3)
	var up := Vector3.UP
	var side := (to - from).cross(up).normalized()
	for i in range(1, segments):
		var t := float(i) / segments
		var jitter := side * randf_range(-0.45, 0.45) + up * randf_range(-0.3, 0.3)
		points.append(from.lerp(to, t) + jitter)
	points.append(to)
	var holder := Node3D.new()
	parent.add_child(holder)
	var mats: Array[StandardMaterial3D] = []
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var mat := _glow(color.lerp(Color.WHITE, 0.5), 1.0)
		mats.append(mat)
		var mi := _instance(holder, MeshKit.box(), mat, (a + b) * 0.5)
		mi.scale = Vector3(0.14, 0.14, a.distance_to(b) + 0.1)
		mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
		var glow_mat := _glow(color, 0.5)
		mats.append(glow_mat)
		var glow := _instance(holder, MeshKit.box(), glow_mat, (a + b) * 0.5)
		glow.scale = Vector3(0.5, 0.5, a.distance_to(b) + 0.1)
		glow.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	flash(parent, to, color, 2.4)
	sparks(parent, to, color, 14, 3.5, 0.4)
	var tween := holder.create_tween()
	tween.tween_interval(0.12)
	tween.tween_method(func(a: float):
		for m in mats:
			m.albedo_color.a = minf(m.albedo_color.a, a), 1.0, 0.0, 0.3)
	tween.tween_callback(holder.queue_free)


# ---------------------------------------------------------------------------
# Melee, rings and area effects
# ---------------------------------------------------------------------------

## Crescent sword slash in front of a hero facing [param yaw].
static func slash_arc(parent: Node3D, pos: Vector3, yaw: float, color: Color, size := 2.0, tilt := 0.0) -> void:
	var mat := _glow(color, 0.95, false)
	var core_mat := _glow(Color(1, 1, 1), 1.0)
	var mi := _instance(parent, _crescent_mesh(), mat, pos)
	mi.rotation = Vector3(0, yaw, tilt)
	mi.scale = Vector3.ONE * size * 0.6
	var core := _instance(parent, _crescent_mesh(), core_mat, pos + Vector3(0, 0.03, 0))
	core.rotation = mi.rotation
	core.scale = mi.scale * 0.8
	var glow_mat := _glow(color, 0.5)
	var glow := _instance(parent, _crescent_mesh(), glow_mat, pos + Vector3(0, -0.03, 0))
	glow.rotation = mi.rotation
	glow.scale = mi.scale * 1.25
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * size * 1.15, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "scale", Vector3.ONE * size * 0.95, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "scale", Vector3.ONE * size * 1.45, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25).set_delay(0.08)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, 0.2).set_delay(0.05)
	tween.tween_property(glow_mat, "albedo_color:a", 0.0, 0.25).set_delay(0.05)
	tween.chain().tween_callback(func():
		mi.queue_free()
		core.queue_free()
		glow.queue_free())


static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	var ring_mat := _glow(color, 0.75, false)
	var ring := _instance(parent, MeshKit.torus(), ring_mat, pos)
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var disc_mat := _glow(color, 0.10, false)
	var disc := _instance(parent, _disc_mesh(), disc_mat, pos + Vector3(0, 0.03, 0))
	disc.scale = Vector3(0.3, 1, 0.3)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, radius * 0.06, radius), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(disc, "scale", Vector3(radius, 1, radius), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(disc_mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(func():
		ring.queue_free()
		disc.queue_free())
	sparks(parent, pos + Vector3(0, 0.3, 0), color, 28, radius * 1.4, 0.6)


## A rune circle on the ground (two spinning rings + soft fill) for area casts.
static func ground_circle(parent: Node3D, pos: Vector3, color: Color, radius: float, duration: float) -> void:
	var outer_mat := _glow(color, 0.9, false)
	var outer := _instance(parent, MeshKit.torus(), outer_mat, pos + Vector3(0, 0.06, 0))
	outer.scale = Vector3(radius, radius * 0.16, radius)
	var inner_mat := _glow(color, 0.6, false)
	var inner := _instance(parent, MeshKit.torus(), inner_mat, pos + Vector3(0, 0.07, 0))
	inner.scale = Vector3(radius * 0.6, radius * 0.12, radius * 0.6)
	var fill_mat := _glow(color, 0.08, false)
	var fill := _instance(parent, _disc_mesh(), fill_mat, pos + Vector3(0, 0.04, 0))
	fill.scale = Vector3(radius, 1, radius)
	var tween := outer.create_tween().set_parallel(true)
	tween.tween_property(outer, "rotation:y", TAU, duration)
	tween.tween_property(inner, "rotation:y", -TAU, duration)
	tween.tween_property(outer_mat, "albedo_color:a", 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
	tween.tween_property(inner_mat, "albedo_color:a", 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
	tween.tween_property(fill_mat, "albedo_color:a", 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
	tween.chain().tween_callback(func():
		outer.queue_free()
		inner.queue_free()
		fill.queue_free())


## Red warning disc that fills up before a boss attack lands.
static func danger_circle(parent: Node3D, pos: Vector3, radius: float, duration: float) -> void:
	var edge_mat := _glow(Color("ff3a3a"), 0.9, false)
	var edge := _instance(parent, MeshKit.torus(), edge_mat, pos + Vector3(0, 0.06, 0))
	edge.scale = Vector3(radius, radius * 0.06, radius)
	var fill_mat := _glow(Color("ff2a2a"), 0.28, false)
	var fill := _instance(parent, _disc_mesh(), fill_mat, pos + Vector3(0, 0.05, 0))
	fill.scale = Vector3(0.1, 1, 0.1)
	var tween := fill.create_tween().set_parallel(true)
	tween.tween_property(fill, "scale", Vector3(radius, 1, radius), duration)
	tween.tween_property(fill_mat, "albedo_color:a", 0.55, duration)
	tween.chain().tween_callback(func():
		edge.queue_free()
		fill.queue_free())


static func pillar(parent: Node3D, pos: Vector3, color: Color, height := 6.0, width := 0.9, duration := 0.6) -> void:
	if not VfxBudget.can_decorate():
		return
	var mat := _glow(color, 0.28, false)
	var mi := _instance(parent, MeshKit.cylinder(), mat, pos + Vector3(0, height * 0.5, 0))
	VfxBudget.track_decoration(mi)
	mi.scale = Vector3(width, height, width)
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(width * 0.15, height, width * 0.15), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(mi.queue_free)


## Falls from the sky onto [param pos]; [param on_hit] is called at impact.
static func meteor(parent: Node3D, pos: Vector3, color: Color, fall_time: float, radius: float, on_hit: Callable) -> void:
	var start := pos + Vector3(-5.0, 18.0, -3.0)
	var rock := _instance(parent, MeshKit.sphere_low(), _glow(Color(1.0, 0.9, 0.6), 1.0), start)
	rock.scale = Vector3.ONE * 1.8
	var halo := _instance(rock, MeshKit.sphere(), _glow(color, 0.85, false), start)
	halo.scale = Vector3.ONE * 1.35
	var glow_quad := QuadMesh.new()
	glow_quad.size = Vector2.ONE * 7.0
	var glow_mat := _glow(color, 0.9)
	glow_mat.albedo_texture = soft_dot()
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_instance(rock, glow_quad, glow_mat, start)
	var trail := _particles(rock, start, color, 70, 0.8, false)
	trail.gravity = Vector3(0, 2.0, 0)
	trail.spread = 30.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 1.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 4.0
	var tween := rock.create_tween()
	tween.tween_property(rock, "global_position", pos + Vector3(0, 0.8, 0), fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		shockwave(parent, pos + Vector3(0, 0.1, 0), color, radius)
		flash(parent, pos + Vector3(0, 1.0, 0), color, radius * 1.6, 0.4)
		pillar(parent, pos, color, 8.0, radius * 0.45, 0.55)
		sparks(parent, pos + Vector3(0, 0.6, 0), Color(1.0, 0.8, 0.4), 60, 9.0, 0.9)
		on_hit.call()
		rock.queue_free())


# ---------------------------------------------------------------------------
# Buffs, healing, level up, loot
# ---------------------------------------------------------------------------

static func heal(parent: Node3D, pos: Vector3, color := Color("6dff9a")) -> void:
	flash(parent, pos + Vector3(0, 1.0, 0), color, 3.2, 0.5)
	pillar(parent, pos, color, 4.5, 1.6, 0.7)
	for i in VfxBudget.count(4):
		var mat := _glow(color, 0.9, false)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		ring.scale = Vector3(1.1, 0.3, 1.1)
		var tween := ring.create_tween().set_parallel(true)
		tween.tween_property(ring, "global_position:y", pos.y + 2.4, 0.9).set_delay(i * 0.14)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_delay(i * 0.14)
		tween.chain().tween_callback(ring.queue_free)
	var p := _particles(parent, pos + Vector3(0, 0.4, 0), color, 40, 1.2)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.8
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6


## A buff aura: bursts of rings and light when cast.
static func aura(parent: Node3D, pos: Vector3, color: Color) -> void:
	flash(parent, pos + Vector3(0, 1.0, 0), color, 4.0, 0.55)
	pillar(parent, pos, color, 6.0, 2.2, 0.9)
	for i in VfxBudget.count(5):
		var mat := _glow(color, 0.95, false)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		ring.scale = Vector3(1.0, 0.28, 1.0)
		var tween := ring.create_tween().set_parallel(true)
		tween.tween_property(ring, "global_position:y", pos.y + 2.6, 0.9).set_delay(i * 0.12)
		tween.tween_property(ring, "scale", Vector3(1.7, 0.3, 1.7), 0.9).set_delay(i * 0.12)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_delay(i * 0.12)
		tween.chain().tween_callback(ring.queue_free)
	sparks(parent, pos + Vector3(0, 0.6, 0), color, 36, 4.0, 1.0)


## Looping glow at the hero's feet while a buff lasts; returns the emitter.
static func buff_emitter(hero: Node3D, color: Color) -> CPUParticles3D:
	var p := _particles(hero, hero.global_position, color, 22, 1.0, false)
	p.local_coords = true
	p.position = Vector3(0, 0.1, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 0.9
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.emitting = false
	return p


static func level_up(parent: Node3D, pos: Vector3) -> void:
	pillar(parent, pos, Color("ffe27a"), 9.0, 1.4, 1.0)
	for i in 4:
		var mat := _glow(Color("fff2a0"), 0.9)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		ring.scale = Vector3(1.0, 0.2, 1.0)
		var tween := ring.create_tween().set_parallel(true)
		tween.tween_property(ring, "global_position:y", pos.y + 3.2, 1.0).set_delay(i * 0.15)
		tween.tween_property(ring, "scale", Vector3(2.2, 0.3, 2.2), 1.0).set_delay(i * 0.15)
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.0).set_delay(i * 0.15)
		tween.chain().tween_callback(ring.queue_free)
	var p := _particles(parent, pos + Vector3(0, 0.5, 0), Color("ffe27a"), 60, 1.4)
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -1.5, 0)


## Light beam over loot so rare drops stand out from far away.
static func loot_beam(parent: Node3D, color: Color, height := 3.0) -> MeshInstance3D:
	var mat := _glow(color, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.cylinder()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.18, height, 0.18)
	mi.position = Vector3(0, height * 0.5, 0)
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------
# Big-skill spectacle
# ---------------------------------------------------------------------------

## Cones that burst out of the ground inside [param radius] (ice, rock, thorns).
static func spikes(parent: Node3D, center: Vector3, radius: float, color: Color, count := 14, height := 2.2, delay_spread := 0.25) -> void:
	for i in VfxBudget.count(count):
		if not VfxBudget.can_decorate():
			break
		var angle := randf() * TAU
		var dist := sqrt(randf()) * radius
		var pos := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var h := height * randf_range(0.6, 1.2)
		var mat := _glow(color, 0.9, false)
		var cone := _instance(parent, MeshKit.cone(), mat, pos)
		VfxBudget.track_decoration(cone)
		cone.scale = Vector3(0.35, 0.01, 0.35)
		cone.rotation = Vector3(randf_range(-0.2, 0.2), randf() * TAU, randf_range(-0.2, 0.2))
		var tween := cone.create_tween()
		tween.tween_interval(randf() * delay_spread)
		tween.tween_property(cone, "scale", Vector3(0.5, h, 0.5), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cone, "position:y", pos.y + h * 0.5, 0.12)
		tween.tween_interval(0.35)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_callback(cone.queue_free)


## A heavy ground slam: cracks racing outwards, dust and a double shockwave.
static func slam(parent: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	shockwave(parent, pos + Vector3(0, 0.12, 0), color, radius)
	for i in 6:
		var angle := i * TAU / 6.0 + randf() * 0.3
		var mat := _glow(Color(0.28, 0.18, 0.1), 0.6, false)
		var crack := _instance(parent, MeshKit.box(), mat, pos + Vector3(0, 0.05, 0))
		crack.rotation.y = -angle
		crack.scale = Vector3(0.1, 0.02, 0.05)
		var length := radius * randf_range(0.7, 1.0)
		var tween := crack.create_tween().set_parallel(true)
		tween.tween_property(crack, "scale", Vector3(length, 0.02, 0.07), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(crack, "position", pos + Vector3(cos(angle), 0.05, sin(angle)) * length * 0.5, 0.22)
		tween.chain().tween_property(mat, "albedo_color:a", 0.0, 0.6).set_delay(0.5)
		tween.chain().tween_callback(crack.queue_free)
	var dust := _particles(parent, pos + Vector3(0, 0.2, 0), Color(0.8, 0.7, 0.55), 30, 0.8)
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = radius * 0.3
	dust.initial_velocity_max = radius * 0.9
	dust.gravity = Vector3(0, -3.0, 0)
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.4
	get_ring_delay(parent, pos, color, radius * 0.6, 0.12)


static func get_ring_delay(parent: Node3D, pos: Vector3, color: Color, radius: float, delay: float) -> void:
	parent.create_tween().tween_interval(delay).finished.connect(func():
		if is_instance_valid(parent):
			shockwave(parent, pos + Vector3(0, 0.1, 0), color, radius))


## Many light columns (or arrows of light) falling over an area, staggered.
static func column_rain(parent: Node3D, center: Vector3, radius: float, color: Color, count := 12, duration := 0.9, height := 9.0) -> void:
	for i in VfxBudget.count(count):
		var angle := randf() * TAU
		var dist := sqrt(randf()) * radius
		var pos := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		parent.create_tween().tween_interval(randf() * duration).finished.connect(func():
			if is_instance_valid(parent) and VfxBudget.can_decorate():
				pillar(parent, pos, color, height, 0.24, 0.3)
				sparks(parent, pos + Vector3(0, 0.3, 0), color, 8, 2.5, 0.4))


## Stacked spinning rings that rise around [param pos]: a whirlwind / power-up column.
static func vortex(parent: Node3D, pos: Vector3, color: Color, height := 3.0, duration := 0.7) -> void:
	for i in VfxBudget.count(4):
		var mat := _glow(color, 0.8, false)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.2, 0))
		var r := 0.9 + i * 0.25
		ring.scale = Vector3(r, r * 0.25, r)
		var tween := ring.create_tween().set_parallel(true)
		tween.tween_property(ring, "position:y", pos.y + height * (0.4 + 0.2 * i), duration).set_delay(i * 0.05)
		tween.tween_property(ring, "rotation:y", TAU * (2.0 if i % 2 == 0 else -2.0), duration)
		tween.tween_property(ring, "scale", Vector3(r * 1.6, r * 0.2, r * 1.6), duration)
		tween.tween_property(mat, "albedo_color:a", 0.0, duration * 0.8).set_delay(duration * 0.25)
		tween.chain().tween_callback(ring.queue_free)


## Radial rays and a flash: a crisp "critical" burst for single-target skills.
static func star_burst(parent: Node3D, pos: Vector3, color: Color, size := 2.2) -> void:
	flash(parent, pos, Color(1, 1, 1), size * 1.4, 0.3)
	for i in 8:
		var angle := i * TAU / 8.0
		var mat := _glow(color, 0.9, false)
		var ray := _instance(parent, MeshKit.box(), mat, pos)
		ray.rotation = Vector3(0, 0, angle)
		ray.scale = Vector3(0.05, 0.05, 0.05)
		ray.look_at_from_position(pos, pos + Vector3(cos(angle), sin(angle) * 0.6, 0.4), Vector3.UP)
		var tween := ray.create_tween().set_parallel(true)
		tween.tween_property(ray, "scale", Vector3(0.05, 0.05, size * 0.9), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "position", pos + Vector3(cos(angle), sin(angle) * 0.6, 0.4).normalized() * size * 0.7, 0.16)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.26)
		tween.chain().tween_callback(ray.queue_free)


## A ring of upright flames around [param center] (fire fields).
static func fire_ring(parent: Node3D, center: Vector3, color: Color, radius: float, count := 18, lifetime := 1.2) -> void:
	var visible_count := VfxBudget.count(count)
	for i in visible_count:
		if not VfxBudget.can_decorate():
			break
		var angle := i * TAU / visible_count + randf() * 0.12
		var pos := center + Vector3(cos(angle), 0.0, sin(angle)) * radius * randf_range(0.6, 1.0)
		var mat := _glow(color, 0.85, false)
		var flame := _instance(parent, MeshKit.cone(), mat, pos)
		VfxBudget.track_decoration(flame)
		flame.scale = Vector3(0.2, 0.01, 0.2)
		var h := randf_range(1.2, 2.4)
		var tween := flame.create_tween()
		tween.tween_interval(randf() * 0.25)
		tween.tween_property(flame, "scale", Vector3(0.55, h, 0.55), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(flame, "position:y", pos.y + h * 0.5, 0.18)
		tween.tween_property(flame, "scale", Vector3(0.3, h * 1.3, 0.3), lifetime * 0.6)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, lifetime * 0.7)
		tween.tween_callback(flame.queue_free)
		sparks(parent, pos + Vector3(0, 0.4, 0), color, 4, 2.0, 0.6)
