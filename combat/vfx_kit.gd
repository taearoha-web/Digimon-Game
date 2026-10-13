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
static var _fade_gradient: Gradient
static var _flight_meshes: Dictionary = {}


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
	return MaterialKeeper.keep(m) as StandardMaterial3D


const ENERGY_SHADER := preload("res://shaders/vfx_energy.gdshader")
static var _ground_quad: PlaneMesh


## Flowing-noise material (shaders/vfx_energy.gdshader). mode 0 ring, 1 band.
static func energy(color: Color, mode: int, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ENERGY_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("core", color.lerp(Color.WHITE, 0.55))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("seed", randf() * 50.0)
	for key in params:
		m.set_shader_parameter(key, params[key])
	return m


## A 2x2 quad lying on the ground (UV 0..1) for energy rings.
static func ground_quad() -> PlaneMesh:
	if _ground_quad == null:
		_ground_quad = PlaneMesh.new()
		_ground_quad.size = Vector2(2, 2)
	return _ground_quad


## Draws both energy modes once, invisibly, so the first real cast does not
## stall while the browser compiles the shader.
static func warm_shaders(parent: Node3D, pos: Vector3) -> void:
	MeteorArt.warm_shaders(parent, pos)
	ThunderStormArt.warm_up(parent, pos)
	JudgmentRayArt.warm_up(parent, pos)
	# Six immutable unit-size trail templates cover every runtime projectile.
	for strand in 2:
		_flight_ribbon_mesh(2.7, false, strand)
		_flight_ribbon_mesh(2.7, true, strand)
		_flight_ribbon_mesh(4.5, false, strand)
	for mode in 2:
		var mat := energy(Color(1, 1, 1, 0.01), mode, {"fade": 0.01})
		var mi := _instance(parent, ground_quad() if mode == 0 else _crescent_mesh(), mat, pos + Vector3(0, 0.05, 0))
		mi.scale = Vector3.ONE * 0.2
		mi.get_tree().create_timer(0.4).timeout.connect(mi.queue_free)
	var recipe := SkillArtDirection.recipe_for({"id": "power_strike"})
	var brush := VfxArt._art_material(recipe)
	brush.set_shader_parameter("fade", 0.001)
	brush.set_shader_parameter("progress", 1.0)
	var sample := _instance(parent, VfxArt._signature_mesh("cut", 1, -0.55), brush, pos + Vector3(0, 0.05, 0))
	sample.scale = Vector3.ONE * 0.1
	sample.create_tween().tween_interval(0.4).finished.connect(sample.queue_free)
	SpellSpectacle.warm_up(parent, pos)
	BuffAura.warm_up(parent, pos)


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
			var u0 := float(i) / steps
			var u1 := float(i + 1) / steps
			# U runs along the arc, V from the sharp outer edge (0) to the inner edge (1).
			for corner in [[o0, u0, 0.0], [i0, u0, 1.0], [o1, u1, 0.0], [o1, u1, 0.0], [i0, u0, 1.0], [i1, u1, 1.0]]:
				st.set_uv(Vector2(corner[1], corner[2]))
				st.add_vertex(corner[0])
		_crescent = st.commit()
	return _crescent


static func _particles(parent: Node3D, pos: Vector3, color: Color, amount: int, lifetime: float, one_shot := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# Every hit uses the same immutable quad. Independent emitter overrides
	# preserve colour/billboarding while avoiding a new GPU mesh on every burst.
	if _soft_particle == null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.4, 0.4)
		_soft_particle = quad
	var mat := _glow(color, 1.0)
	mat.albedo_texture = soft_dot()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p.mesh = _soft_particle
	p.material_override = mat
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
		# Node-bound: an emitter freed with its scene leaves no pending timer.
		p.create_tween().tween_interval(lifetime + 0.3).finished.connect(p.queue_free, CONNECT_ONE_SHOT)
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
	# Emitters only read this white-to-transparent ramp; their colours are in
	# independent materials. Avoid allocating it again for every hit or trail.
	if _fade_gradient == null:
		_fade_gradient = Gradient.new()
		_fade_gradient.set_color(0, Color(1, 1, 1, 1))
		_fade_gradient.set_color(1, Color(1, 1, 1, 0))
	return _fade_gradient


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
	if not VfxBudget.can_decorate(2):
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var core_mat := _glow(color.lerp(Color("fff2d5"), 0.50), 0.70, false)
	core_mat.albedo_texture = soft_dot()
	core_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var mat := _glow(color, 0.65)
	mat.albedo_texture = soft_dot()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var halo := _instance(parent, quad, mat, pos)
	VfxBudget.track_decoration(halo)
	halo.scale = Vector3.ONE * size * 0.4
	var core := _instance(parent, quad, core_mat, pos)
	VfxBudget.track_decoration(core)
	core.scale = Vector3.ONE * size * 0.16
	var tween := halo.create_tween().set_parallel(true)
	tween.tween_property(halo, "scale", Vector3.ONE * size * 0.90, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(core, "scale", Vector3.ONE * size * 0.42, duration * 0.8)
	tween.tween_property(core_mat, "albedo_color:a", 0.0, duration * 0.8)
	tween.chain().tween_callback(func():
		halo.queue_free()
		core.queue_free())


## Contact-only feedback. Called by damage delivery and completed projectile flights.
## Concentrated colored cores stay readable against both snow and grass.
static func impact(parent: Node3D, pos: Vector3, color: Color, scale := 1.0) -> void:
	flash(parent, pos, color, 1.8 * scale, 0.23)
	impact_fan(parent, pos, color, scale, "spark")
	sparks(parent, pos, color, int(12 * scale), 5.2 * scale, 0.48)


## Public elemental impact: visual only, never applies or schedules damage.
## The originating projectile calls this on arrival, never on launch.
static func element_impact(parent: Node3D, pos: Vector3, color: Color, style: String, scale := 1.0) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	impact(parent, pos, color, scale)
	match style:
		"flame", "fire":
			ElementFx.flame_hit(parent, pos)
			impact_smoke(parent, pos, Color("bd694d"), scale * 1.5)
			impact_fan(parent, pos, Color("ffd477"), scale * 1.2, "flame")
		"shard", "ice":
			ElementFx.shatter(parent, pos, scale * 0.9, 5)
			impact_fan(parent, pos, Color("adefff"), scale * 1.15, "diamond")
		"leaf", "vine", "plant":
			impact_fan(parent, pos, Color("b7f39b"), scale * 1.35, "leaf")
			VfxArt.motes(parent, pos, Color("e5f3ad"), "petal", 8, 0.3 * scale, 0.0, 0.75)
		"spark", "light", "thunder":
			impact_ring(parent, pos, color, 1.3 * scale, 0.38)
			impact_fan(parent, pos, color.lerp(Color("fff0ba"), 0.35), scale * 1.2, "diamond")
		"arrow":
			impact_ring(parent, pos, color, 0.9 * scale, 0.25)
		_:
			impact_ring(parent, pos, color, scale, 0.3)


## A real 3D pressure ring: the oblique silhouette survives low game cameras.
static func impact_ring(parent: Node3D, pos: Vector3, color: Color, radius: float, duration := 0.4) -> void:
	if not VfxBudget.can_decorate():
		return
	var mat := energy(color, 0, {"ring_radius": 0.64, "ring_width": 0.12, "fill": 0.0, "flow": 2.8})
	var ring := _instance(parent, ground_quad(), mat, pos)
	VfxBudget.track_decoration(ring)
	ring.rotation = Vector3(0.48, randf() * TAU, 0.25)
	ring.scale = Vector3.ONE * radius * 0.16
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * radius * 1.65, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.9, 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


## Directional petal / spark cards separate the hit into a sharp initial burst
## and long colored streaks. Each card has its own tracked, short-lived carrier.
static func impact_fan(parent: Node3D, pos: Vector3, color: Color, scale: float, kind := "spark") -> void:
	var count := VfxBudget.count(7, 3)
	for i in count:
		if not VfxBudget.can_decorate():
			break
		var angle := TAU * float(i) / float(count) + 0.23
		var direction := Vector3(cos(angle), sin(angle) * 0.65 + 0.25, sin(angle * 1.7) * 0.5).normalized()
		var mat := _glow(color, 0.88, false)
		mat.albedo_texture = VfxArt.texture(kind)
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.95) * scale
		var ray := _instance(parent, quad, mat, pos)
		VfxBudget.track_decoration(ray)
		var camera := parent.get_viewport().get_camera_3d()
		if camera != null:
			ray.global_basis = camera.global_basis
		ray.rotate_object_local(Vector3.FORWARD, angle - PI * 0.5)
		ray.scale = Vector3.ONE * 0.25
		var life := 0.3 + float(i % 3) * 0.055
		var tween := ray.create_tween().set_parallel(true)
		tween.tween_property(ray, "global_position", pos + direction * scale * 1.65, life).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "scale", Vector3.ONE, life * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(mat, "albedo_color:a", 0.0, life * 0.65).set_delay(life * 0.35)
		tween.chain().tween_callback(ray.queue_free)


## A restrained puff with a textured edge gives impacts weight without hiding
## damage text or enemy warnings. Both particle amount and lifetime are bounded.
static func impact_smoke(parent: Node3D, pos: Vector3, color: Color, size := 1.0) -> void:
	var smoke := _particles(parent, pos, color, 8, 0.65)
	var mat := _glow(color, 0.34, false)
	mat.albedo_texture = VfxArt.texture("smoke")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.95 * size
	quad.material = mat
	smoke.mesh = quad
	smoke.direction = Vector3.UP
	smoke.spread = 110.0
	smoke.initial_velocity_min = 0.8 * size
	smoke.initial_velocity_max = 2.4 * size
	smoke.gravity = Vector3(0, 0.45, 0)
	smoke.scale_amount_min = 0.55
	smoke.scale_amount_max = 1.05
	var expansion := Curve.new()
	expansion.add_point(Vector2(0, 0.15))
	expansion.add_point(Vector2(0.4, 0.8))
	expansion.add_point(Vector2(1, 1.2))
	smoke.scale_amount_curve = expansion


# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

## Glowing orb with a particle trail. Flight and cleanup belong to its carrier.
static func variant_for(vfx: StringName) -> String:
	return {&"fireball": "flame", &"frost": "shard", &"light": "spark", &"thunder": "spark", &"leaf": "leaf"}.get(vfx, "orb")


static func projectile(parent: Node3D, color: Color, from: Vector3, to: Vector3, duration: float, size := 0.5, variant := "orb") -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = from
	if from.distance_to(to) > 0.05:
		var up := Vector3.RIGHT if absf((to - from).normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		holder.look_at(to, up)
	# This single essential silhouette is never budget-gated. Decorative trails
	# may vanish during crowds; projectile timing and visibility never do.
	var pearl := color.lerp(Color("fff0cf"), 0.38)
	match variant:
		"shard": ElementFx.ice_lance(holder, size * 1.15)
		"leaf": ElementFx.leaf_swirl(holder, size * 1.15)
		_:
			var core := _instance(holder, MeshKit.sphere_low(), _glow(pearl, 0.94, false), from)
			core.scale = Vector3(size * 0.6, size * 0.6, size * 1.1)
			if variant == "flame":
				core.material_override = _glow(Color("ffc365"), 0.97, false)
	if VfxBudget.can_decorate():
		var glow_quad := QuadMesh.new()
		glow_quad.size = Vector2.ONE * size * 4.2
		var glow_mat := _glow(color, 0.33, false)
		glow_mat.albedo_texture = VfxArt.texture("flare")
		glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var glow := _instance(holder, glow_quad, glow_mat, from)
		VfxBudget.track_decoration(glow)
	flight_ribbons(holder, color, size, 2.7, variant == "flame")
	var trail := _particles(holder, from, color, 24, 0.42, false)
	trail.direction = Vector3.ZERO
	trail.spread = 35.0
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.8
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.45
	trail.scale_amount_max = 0.95
	match variant:
		"flame": trail.mesh = _textured_quad(VfxArt.texture("flame"), Color("ff9449"), 0.85)
		"shard": trail.mesh = _textured_quad(VfxArt.texture("snow"), color, 0.48)
		"leaf": trail.mesh = _textured_quad(VfxArt.texture("leaf"), Color("a8eb91"), 0.55)
		_: trail.mesh = _textured_quad(VfxArt.texture("spark"), pearl, 0.54)
	if VfxBudget.can_light():
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.5
		light.omni_range = 3.1
		holder.add_child(light)
		VfxBudget.track_light(light)
	var mid := (from + to) * 0.5 + Vector3(0, minf(0.6, from.distance_to(to) * 0.08), 0)
	var tween := holder.create_tween()
	var puffs := {"next": 0.0}
	tween.tween_method(func(t: float):
		holder.global_position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		if variant == "flame" and t >= float(puffs.next) and VfxBudget.can_decorate():
			puffs["next"] = t + 0.24
			ElementFx.flame_puff(parent, holder.global_position, size * 1.2), 0.0, 1.0, maxf(duration, 0.05))
	# Bound to the flight carrier: unloading a zone cancels arrival and releases
	# all resources immediately, without a suspended coroutine retaining them.
	tween.tween_callback(func():
		if is_instance_valid(parent) and parent.is_inside_tree():
			element_impact(parent, to, color, variant, 0.7 + size * 0.65)
		holder.queue_free())


## Two dimensional ribbons coil around a volumetric head and trail behind it.
## Each whole helix is one draw call, rather than dozens of orbiting meshes.
static func flight_ribbons(holder: Node3D, color: Color, size: float, length: float, flame := false) -> void:
	for strand in (1 if VfxBudget.quality() == 0 else 2):
		if not VfxBudget.can_decorate():
			break
		var ribbon_color := color.lerp(Color("fff0c8"), float(strand) * 0.32)
		var mat := energy(ribbon_color, 1, {"flow": 3.0, "noise_scale": 2.8, "progress": 0.0})
		var ribbon := _instance(holder, _flight_ribbon_mesh(length, flame, strand), mat, holder.global_position)
		ribbon.scale = Vector3.ONE * size
		VfxBudget.track_decoration(ribbon)
		# _instance sets world position only, leaving the carrier rotation intact.
		var spin := ribbon.create_tween().set_loops()
		spin.tween_property(ribbon, "rotation:z", TAU, 0.42 + strand * 0.07).as_relative()


static func _flight_ribbon_mesh(length: float, flame: bool, strand: int) -> ArrayMesh:
	var key := var_to_bytes([length, flame, strand]).hex_encode()
	if _flight_meshes.has(key):
		return _flight_meshes[key]
	# All coordinates and brush widths were multiplied by projectile size.
	# A unit template plus instance scale therefore retains the authored art.
	var path: Array[Vector3] = []
	for i in 25:
		var t := float(i) / 24.0
		var angle := t * TAU * 1.3 + float(strand) * PI
		var r := 0.32 + t * 0.7
		path.append(Vector3(cos(angle) * r, sin(angle) * r, t * length))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	VfxArt._append_brush(st, path, 0.3 if flame else 0.17)
	var mesh := st.commit()
	# Runtime uses only lengths 2.7 and 4.5; bound future callers as well.
	if _flight_meshes.size() >= 16:
		_flight_meshes.erase(_flight_meshes.keys()[0])
	_flight_meshes[key] = mesh
	return mesh


## A feathered arrow with a tapered shaft and two defined barbs.
static func arrow(parent: Node3D, color: Color, from: Vector3, to: Vector3, duration: float) -> void:
	var dir := (to - from)
	if dir.length() < 0.01:
		return
	# A tapered shaft and two barbs read as an arrow, including with particles
	# disabled. This mesh is the flight carrier, so it is never budget-gated.
	var look := {"primary": color.lerp(Color("a9d8bd"), 0.16), "accent": color.lerp(Color("fff2cf"), 0.62), "shade": color.darkened(0.26)}
	var mat := VfxArt._art_material(look)
	mat.set_shader_parameter("progress", 1.0)
	var carrier := Node3D.new()
	parent.add_child(carrier)
	carrier.global_position = from
	carrier.look_at(to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
	var arrow_mesh := _instance(carrier, VfxArt._signature_mesh("arrow", 1, 0.0), mat, from)
	arrow_mesh.rotation.y = PI
	arrow_mesh.scale = Vector3(0.78, 0.78, 1.65)
	arrow_mesh.position.z = 1.35
	flight_ribbons(carrier, color, 0.45, 4.5)
	var trail := _particles(carrier, from, color, 14, 0.25, false)
	trail.mesh = _textured_quad(VfxArt.texture("spark"), color, 0.32)
	trail.direction = Vector3.ZERO
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_max = 0.18
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 0.8
	var tween := carrier.create_tween()
	tween.tween_property(carrier, "global_position", to, maxf(duration, 0.05))
	tween.tween_callback(func():
		if is_instance_valid(parent) and parent.is_inside_tree():
			element_impact(parent, to, color, "arrow", 0.72)
		carrier.queue_free())


## A jagged lightning bolt between two points that flashes and fades.
static func lightning(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	VfxArt.painted_lightning(parent, from, to, color)
	element_impact(parent, to, color, "thunder", 0.8)


# ---------------------------------------------------------------------------
# Melee, rings and area effects
# ---------------------------------------------------------------------------

## Crescent sword slash in front of a hero facing [param yaw].
static func slash_arc(parent: Node3D, pos: Vector3, yaw: float, color: Color, size := 2.0, tilt := 0.0) -> void:
	VfxArt.painted_slash(parent, pos, yaw, color, size, tilt)


static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	if not VfxBudget.can_decorate(2):
		return
	# A wave of flowing energy that rushes out over the ground and burns away.
	var wave_mat := energy(color, 0, {"ring_radius": 0.82, "ring_width": 0.2, "flow": 2.4, "fill": 0.18})
	var wave := _instance(parent, ground_quad(), wave_mat, pos + Vector3(0, 0.06, 0))
	VfxBudget.track_decoration(wave)
	wave.scale = Vector3(0.25, 1, 0.25)
	var ring_mat := _glow(color.lerp(Color.WHITE, 0.5), 0.6, false)
	var ring := _instance(parent, MeshKit.torus(), ring_mat, pos)
	VfxBudget.track_decoration(ring)
	ring.scale = Vector3(0.3, 0.3, 0.3)
	var tween := wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3(radius * 1.15, 1, radius * 1.15), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): wave_mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.5)
	tween.tween_method(func(v: float): wave_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3).set_delay(0.2)
	tween.tween_property(ring, "scale", Vector3(radius, radius * 0.05, radius), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(func():
		wave.queue_free()
		ring.queue_free())
	sparks(parent, pos + Vector3(0, 0.3, 0), color, 28, radius * 1.4, 0.6)


## A rune circle on the ground (two spinning rings + soft fill) for area casts.
static func ground_circle(parent: Node3D, pos: Vector3, color: Color, radius: float, duration: float) -> void:
	var outer_mat := _glow(color, 0.9, false)
	var outer := _instance(parent, MeshKit.torus(), outer_mat, pos + Vector3(0, 0.06, 0))
	outer.scale = Vector3(radius, radius * 0.16, radius)
	var inner_mat := _glow(color, 0.6, false)
	var inner := _instance(parent, MeshKit.torus(), inner_mat, pos + Vector3(0, 0.07, 0))
	inner.scale = Vector3(radius * 0.6, radius * 0.12, radius * 0.6)
	# A swirling energy ring fills the area while the spell gathers.
	var fill_mat := energy(color, 0, {"ring_radius": 0.86, "ring_width": 0.1, "flow": 1.2, "swirl": 1.0, "fill": 0.22, "noise_scale": 6.0})
	var fill := _instance(parent, ground_quad(), fill_mat, pos + Vector3(0, 0.04, 0))
	fill.scale = Vector3(radius * 1.05, 1, radius * 1.05)
	var tween := outer.create_tween().set_parallel(true)
	tween.tween_property(outer, "rotation:y", TAU, duration)
	tween.tween_property(inner, "rotation:y", -TAU, duration)
	tween.tween_property(outer_mat, "albedo_color:a", 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
	tween.tween_property(inner_mat, "albedo_color:a", 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
	tween.tween_method(func(v: float): fill_mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.25).set_delay(maxf(duration - 0.25, 0.0))
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
static func meteor(parent: Node3D, pos: Vector3, color: Color, fall_time: float, radius: float, on_hit: Callable, sculpted := false) -> void:
	if sculpted:
		# Same gameplay callback and fall time; the elite art replaces the old cylinder.
		var carrier := Node3D.new()
		carrier.name = "SculptedMeteorCarrier"
		parent.add_child(carrier)
		MeteorArt.descent(carrier, pos, radius, fall_time)
		var clock := carrier.create_tween()
		clock.tween_interval(fall_time)
		clock.tween_callback(func():
			on_hit.call()
			carrier.queue_free())
		return
	var start := pos + Vector3(-5.0, 18.0, -3.0)
	var rock := _instance(parent, MeshKit.sphere_low(), _glow(Color(1.0, 0.9, 0.6), 1.0), start)
	rock.scale = Vector3.ONE * 1.8
	if VfxBudget.can_decorate(2):
		var halo := _instance(rock, MeshKit.sphere(), _glow(color, 0.52, false), start)
		VfxBudget.track_decoration(halo)
		halo.scale = Vector3.ONE * 1.22
		var glow_quad := QuadMesh.new()
		glow_quad.size = Vector2.ONE * 5.0
		var glow_mat := _glow(color, 0.45, false)
		glow_mat.albedo_texture = VfxArt.texture("flare")
		glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var glow := _instance(rock, glow_quad, glow_mat, start)
		VfxBudget.track_decoration(glow)
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
		if not VfxBudget.can_decorate():
			break
		var mat := _glow(color, 0.9, false)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		VfxBudget.track_decoration(ring)
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
		if not VfxBudget.can_decorate():
			break
		var mat := _glow(color, 0.95, false)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		VfxBudget.track_decoration(ring)
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
		if not VfxBudget.can_decorate():
			break
		var mat := _glow(Color("fff2a0"), 0.9)
		var ring := _instance(parent, MeshKit.torus(), mat, pos + Vector3(0, 0.1, 0))
		VfxBudget.track_decoration(ring)
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
		if not VfxBudget.can_decorate():
			break
		var angle := i * TAU / 6.0 + randf() * 0.3
		var mat := _glow(Color(0.28, 0.18, 0.1), 0.6, false)
		var crack := _instance(parent, MeshKit.box(), mat, pos + Vector3(0, 0.05, 0))
		VfxBudget.track_decoration(crack)
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
	VfxArt.ribbon_spiral(parent, pos, color, height, 2.8, duration, 1.25)
	impact_ring(parent, pos + Vector3.UP * 0.25, color, 1.5, duration)


## Radial textured rays: a crisp critical-hit burst with separated colored tips.
static func star_burst(parent: Node3D, pos: Vector3, color: Color, size := 2.2) -> void:
	flash(parent, pos, color.lerp(Color("fff1ce"), 0.35), size * 1.1, 0.28)
	impact_fan(parent, pos, color, size * 0.8, "spark")
	impact_ring(parent, pos, color, size * 0.7, 0.35)


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
