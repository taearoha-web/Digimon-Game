class_name MeteorArt
extends RefCounted
## Armageddon's finite, cosmetic-only 3D choreography. ArmageddonSequence owns
## every hit and its clock; dropping any visual never suppresses damage.

const ROCK_SHADER := preload("res://shaders/meteor_rock.gdshader")
const FLAME_SHADER := preload("res://shaders/meteor_flame.gdshader")
const GROUND_SHADER := preload("res://shaders/meteor_ground.gdshader")
const ASSETS := preload("res://combat/spectacle_assets.gd")
static var _rock_mesh: ArrayMesh
static var _plume_mesh: ArrayMesh
static var _dome_mesh: ArrayMesh
static var _ring_mesh: TorusMesh


## Geometry only: zone loading may call this before the first ultimate.
static func warm_geometry() -> void:
	_stone_mesh()
	_flame_mesh()
	_hemisphere()
	_shock_ring_mesh()


## Preloading shader files does not draw their browser pipelines. Tiny samples
## inside the active camera view warm all three before the first meteor cast.
## These are temporary loading samples, not budget-bypassing combat effects.
static func warm_shaders(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	var root := _root(parent, at + Vector3(0.4, 0.1, 0), "MeteorShaderWarmup")
	var rock := VfxKit._instance(root, _stone_mesh(), _stone_material(1.3), root.global_position)
	rock.scale = Vector3.ONE * 0.003
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = FLAME_SHADER
	flame_mat.set_shader_parameter("fade", 0.001)
	var flame := VfxKit._instance(root, _flame_mesh(), flame_mat, root.global_position)
	flame.scale = Vector3.ONE * 0.01
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("fade", 0.001)
	ground_mat.set_shader_parameter("progress", 1.0)
	var ground := VfxKit._instance(root, VfxKit.ground_quad(), ground_mat, root.global_position)
	ground.scale = Vector3.ONE * 0.01
	_lifetime(root, 0.4)


static func descent(parent: Node3D, center: Vector3, radius: float, duration := 1.25) -> Node3D:
	var root := _root(parent, center, "ArmageddonDescent")
	var look := SkillShow.profile_for(ClassData.find_skill(&"mage", "armageddon"))
	SkillInk.mark(root, look, Vector3(0, 0.11, 0), radius * 0.91, duration)
	var size := clampf(radius * 0.28, 1.8, 3.1)
	var body := Node3D.new()
	root.add_child(body)
	body.position = Vector3(-6.0, 25.0, -4.5)
	# Exactly two essential meshes per cast remain visible when decorations are
	# saturated: the incoming projectile and its complete landing telegraph.
	# Like VfxKit's projectile carriers, these do not consume cosmetic slots.
	var stone := _essential_mesh(body, _stone_mesh(), _stone_material(1.3), "EssentialMeteorBody")
	stone.scale = Vector3.ONE * size
	var crust := stone.material_override as ShaderMaterial
	body.create_tween().tween_method(func(t: float):
		crust.set_shader_parameter("fracture", t)
		crust.set_shader_parameter("heat", 1.1 + t * 0.65), 0.0, 1.0, duration)
	body.create_tween().tween_property(stone, "rotation", Vector3(1.9, 2.6, 0.9), duration)
	var warning := ShaderMaterial.new()
	warning.shader = GROUND_SHADER
	warning.set_shader_parameter("warning", true)
	var ground := _essential_mesh(root, VfxKit.ground_quad(), warning, "EssentialLandingWarning")
	ground.position.y = 0.09
	ground.scale = Vector3(radius, 1, radius)
	root.create_tween().tween_method(func(t: float): warning.set_shader_parameter("progress", t), 0.0, 1.0, duration)
	# The plume has genuine depth and three copper / orange / gold envelopes.
	_plume(body, Vector3(0, size * 0.12, 0), size * 1.14, size * 3.7, 0.0)
	if VfxBudget.quality() > 0:
		_plume(body, Vector3(0.08, size * 0.2, 0), size * 0.73, size * 2.85, 1.0)
		_plume(body, Vector3(0, size * 0.35, 0.08), size * 0.40, size * 2.1, 2.0)
	var embers := _embers(body, Vector3.ZERO, 70, 0.8, size * 0.8, 4.0, false)
	if embers:
		embers.direction = Vector3.UP
		embers.spread = 24.0
		embers.gravity = Vector3(0.5, 2.8, 0.2)
	_light(body, Color(1.0, 0.32, 0.07), size * 4.0, 2.0)
	var fall := body.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(body, "position", Vector3(0, size * 0.72, 0), duration)
	_lifetime(root, duration + 0.025)
	return root


static func impact(parent: Node3D, center: Vector3, radius: float, giant := true) -> Node3D:
	var root := _root(parent, center, "ArmageddonImpact" if giant else "ArmageddonFragmentImpact")
	var look := SkillShow.profile_for(ClassData.find_skill(&"mage", "armageddon"))
	SkillInk.mark(root, look, Vector3(0, 0.13, 0), radius * 0.9, 0.7 if giant else 0.32, 1)
	if giant and VfxBudget.can_decorate():
		var detailing := EliteSkillArt._root(root, center, 1.7, "MeteorFractureCrown")
		detailing.layer("fractures", look, Vector3(0, 0.12, 0), Vector3.ONE * radius * 0.88, Vector3.ZERO, 0.0, 1.7)
		detailing.layer("comet", look, Vector3(0, 0.2, 0), Vector3(radius * 0.23, radius * 0.65, radius * 0.23), Vector3.ZERO, 0.0, 1.2)
	var lifetime := 2.4 if giant else 1.35
	var scale_radius := radius if giant else radius * 0.70
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("progress", 1.0)
	var scar := _mesh(root, VfxKit.ground_quad(), ground_mat)
	if scar:
		scar.position.y = 0.075
		scar.scale = Vector3(scale_radius, 1, scale_radius)
		_fade_shader(root, ground_mat, lifetime * 0.6, lifetime * 0.4)
	# A rising hemispherical pressure front reads as volume from the game camera.
	var blast_mat := _color(Color(1.0, 0.56, 0.12, 0.42))
	var blast := _mesh(root, _hemisphere(), blast_mat)
	if blast:
		blast.position.y = 0.16
		blast.scale = Vector3.ONE * 0.3
		var wave := root.create_tween().set_parallel(true)
		wave.tween_property(blast, "scale", Vector3(scale_radius, scale_radius * 0.37, scale_radius), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		wave.tween_property(blast_mat, "albedo_color:a", 0.0, 0.55)
	# Two warm, separated pressure rings and a center flame fountain, never a
	# full-screen additive white flash. Ridges of actual rock arc through them.
	for index in (2 if giant else 1):
		_shock_ring(root, scale_radius, index * 0.13, giant)
	_plume(root, Vector3(0, 0.1, 0), scale_radius * 0.29, scale_radius * 0.72, 1.0, 0.75)
	var chunks := VfxBudget.count(10 if giant else 4, 3 if giant else 1)
	for i in chunks:
		var angle := float(i) * TAU / float(chunks) + 0.35
		var reach := scale_radius * (0.49 + float(i % 3) * 0.14)
		var target := Vector3(cos(angle) * reach, 0.1, sin(angle) * reach)
		_debris(root, Vector3(0, 0.7, 0), target, (1.0 if giant else 0.55) + float(i % 3) * 0.08, 0.88 if giant else 0.65, scale_radius * 0.44)
	_embers(root, Vector3(0, 0.7, 0), 100 if giant else 30, 1.05 if giant else 0.7, 0.6, scale_radius * 0.95, true)
	_smoke(root, Vector3(0, 0.55, 0), scale_radius, lifetime)
	_light(root, Color(1.0, 0.4, 0.09), scale_radius * 1.3, 2.5 if giant else 0.8)
	_lifetime(root, lifetime)
	return root


static func fragments(parent: Node3D, center: Vector3, targets: Array[Vector3], interval_seconds := 0.5) -> Node3D:
	var root := _root(parent, center, "ArmageddonTenFragments")
	# Fit the first flight and fuse before its hit; use the gameplay cadence
	# so every rock disappears at the same instant as its damage explosion.
	var flight_seconds := minf(0.58, interval_seconds * 0.64)
	var fuse_seconds := minf(0.18, interval_seconds * 0.25)
	var fragments_in_order: Array[Node3D] = []
	for i in mini(targets.size(), 10):
		var fragment := Node3D.new()
		fragment.name = "BurningFragment%d" % (i + 1)
		root.add_child(fragment)
		fragments_in_order.append(fragment)
		var end := targets[i] - center + Vector3(0, 0.4, 0)
		var split_angle := float(i) * TAU / 10.0
		var start := Vector3(sin(split_angle) * 1.1, 1.8 + (i % 3) * 0.35, cos(split_angle) * 1.1)
		var mat := _stone_material(0.85, float(i) * 0.72)
		var stone := _mesh(fragment, _stone_mesh(), mat)
		if stone:
			stone.scale = Vector3(0.43, 0.66, 0.46)
			stone.rotation = Vector3(float(i) * 0.7, float(i) * 1.1, 0.3)
		var flight := fragment.create_tween()
		flight.tween_method(func(t: float): fragment.position = start.lerp(end, t) + Vector3.UP * sin(t * PI) * (1.9 + (i % 4) * 0.45), 0.0, 1.0, flight_seconds)
		# The rock itself glows continuously, so all ten fuses remain readable
		# even when secondary flames have exhausted the decoration budget.
		flight.tween_interval(maxf(0.0, float(i + 1) * interval_seconds - flight_seconds - fuse_seconds))
		flight.tween_method(func(t: float): mat.set_shader_parameter("heat", t), 0.85, 1.9, fuse_seconds)
		flight.tween_callback(fragment.queue_free)
	# Reserve all primary rock silhouettes before spending any slots on flames.
	if VfxBudget.quality() > 0:
		for i in fragments_in_order.size():
			_plume(fragments_in_order[i], Vector3(0, 0.0, 0), 0.44, 1.55, float(i % 2))
	_lifetime(root, float(mini(targets.size(), 10)) * interval_seconds + 0.1)
	return root


static func _root(parent: Node3D, center: Vector3, title: String) -> Node3D:
	var root := Node3D.new()
	root.name = title
	parent.add_child(root)
	root.global_position = center
	return root


static func _mesh(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	if not VfxBudget.can_decorate():
		return null
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	VfxBudget.track_decoration(instance)
	parent.add_child(instance)
	return instance


## Used only for descent's solid projectile and its landing warning. Keeping
## this separate prevents debris, flames, and fragments bypassing the budget.
static func _essential_mesh(parent: Node3D, mesh: Mesh, material: Material, title: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _stone_material(heat := 1.0, seed := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ROCK_SHADER
	mat.set_shader_parameter("heat", heat)
	mat.set_shader_parameter("seed", seed)
	return mat


static func _color(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	return mat


static func _plume(parent: Node3D, pos: Vector3, width: float, height: float, variant: float, duration := 0.0) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	mat.set_shader_parameter("seed", variant * 7.1)
	if variant >= 2.0:
		mat.set_shader_parameter("ember", Color(1.0, 0.35, 0.035))
		mat.set_shader_parameter("gold", Color(1.0, 0.89, 0.39))
	elif variant >= 1.0:
		mat.set_shader_parameter("ember", Color(0.96, 0.20, 0.025))
		mat.set_shader_parameter("gold", Color(1.0, 0.72, 0.17))
	var flame := _mesh(parent, _flame_mesh(), mat)
	if not flame:
		return
	flame.position = pos
	flame.scale = Vector3(width, height, width)
	if duration > 0.0:
		_fade_shader(parent, mat, duration * 0.65, duration * 0.35)
		var animation := parent.create_tween()
		animation.tween_property(flame, "scale", Vector3(width * 1.4, height * 1.3, width * 1.4), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_callback(flame.queue_free)


static func _shock_ring(parent: Node3D, radius: float, delay: float, giant: bool) -> void:
	var mat := _color(Color(1.0, 0.64 if delay == 0.0 else 0.3, 0.08, 0.88))
	var ring := _mesh(parent, _shock_ring_mesh(), mat)
	if not ring:
		return
	ring.position.y = 0.16
	ring.scale = Vector3.ONE * 0.08
	var tween := parent.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.6 if giant else 0.3, radius), 0.64).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.42).set_delay(delay + 0.18)


static func _shock_ring_mesh() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.94
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 48
		_ring_mesh.ring_segments = 5
	return _ring_mesh


static func _debris(parent: Node3D, start: Vector3, end: Vector3, size: float, duration: float, arc_height: float) -> void:
	var stone := _mesh(parent, _stone_mesh(), _stone_material(1.1, start.x + end.z))
	if not stone:
		return
	stone.scale = Vector3(size * 0.46, size * 0.7, size * 0.42)
	var tween := parent.create_tween()
	tween.tween_method(func(t: float):
		stone.position = start.lerp(end, t) + Vector3.UP * sin(t * PI) * arc_height
		stone.rotation = Vector3(t * 4.0, t * 5.1, t * 1.3)
	, 0.0, 1.0, duration)
	tween.tween_property(stone, "scale", Vector3.ONE * 0.001, 0.22)
	tween.tween_callback(stone.queue_free)


static func _embers(parent: Node3D, pos: Vector3, count: int, lifetime: float, spread_radius: float, speed: float, burst: bool) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	if not VfxBudget.track_particles(emitter, count):
		emitter.free()
		return null
	emitter.mesh = VfxKit._textured_quad(ASSETS.tex("spark"), Color(1.0, 0.62, 0.15), 0.36)
	emitter.one_shot = burst
	emitter.explosiveness = 0.95 if burst else 0.0
	emitter.lifetime = lifetime
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = spread_radius
	emitter.direction = Vector3.UP
	emitter.spread = 58.0
	emitter.initial_velocity_min = speed * 0.4
	emitter.initial_velocity_max = speed
	emitter.gravity = Vector3(0, -5.0, 0)
	emitter.scale_amount_min = 0.4
	emitter.scale_amount_max = 1.4
	emitter.color_ramp = VfxKit._fade_ramp()
	parent.add_child(emitter)
	emitter.position = pos
	emitter.emitting = true
	return emitter


static func _smoke(parent: Node3D, pos: Vector3, radius: float, lifetime: float) -> void:
	var emitter := CPUParticles3D.new()
	if not VfxBudget.track_particles(emitter, 24):
		emitter.free()
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 0.4
	var mat := _color(Color(0.19, 0.10, 0.09, 0.20))
	mat.albedo_texture = ASSETS.tex("smoke")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = mat
	emitter.mesh = quad
	emitter.one_shot = true
	emitter.explosiveness = 0.8
	emitter.lifetime = lifetime * 0.85
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = radius * 0.35
	emitter.direction = Vector3.UP
	emitter.spread = 60.0
	emitter.initial_velocity_min = 0.5
	emitter.initial_velocity_max = radius * 0.22
	emitter.gravity = Vector3(0.35, 0.65, 0.1)
	emitter.scale_amount_min = 0.5
	emitter.scale_amount_max = 1.5
	emitter.color_ramp = VfxKit._fade_ramp()
	parent.add_child(emitter)
	emitter.position = pos
	emitter.emitting = true


static func _light(parent: Node3D, color: Color, radius: float, energy: float) -> void:
	if not VfxBudget.can_light():
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.position.y = 1.8
	VfxBudget.track_light(light)
	parent.add_child(light)
	parent.create_tween().tween_property(light, "light_energy", 0.0, 0.7)


static func _fade_shader(parent: Node3D, mat: ShaderMaterial, duration: float, delay: float) -> void:
	parent.create_tween().tween_method(func(t: float): mat.set_shader_parameter("fade", t), 1.0, 0.0, duration).set_delay(delay)


static func _lifetime(node: Node3D, seconds: float) -> void:
	node.create_tween().tween_interval(seconds).finished.connect(node.queue_free)


static func _stone_mesh() -> ArrayMesh:
	if _rock_mesh != null:
		return _rock_mesh
	# Subdivided icosahedron: 80 deliberately irregular triangular rock facets.
	var t := (1.0 + sqrt(5.0)) * 0.5
	var vertices: Array[Vector3] = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
	var faces := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = vertices[face[0]].normalized()
		var b: Vector3 = vertices[face[1]].normalized()
		var c: Vector3 = vertices[face[2]].normalized()
		var ab := (a+b).normalized()
		var bc := (b+c).normalized()
		var ca := (c+a).normalized()
		for triangle in [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]:
			var points: Array[Vector3] = []
			for v: Vector3 in triangle:
				var lump := 0.91 + sin(v.x * 17.0 + v.y * 9.0 + v.z * 23.0) * 0.09
				points.append(v * lump)
			var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()
			# Godot front faces wind clockwise; the source icosahedron winds CCW.
			for j in [0, 2, 1]:
				st.set_normal(normal)
				st.add_vertex(points[j])
	_rock_mesh = st.commit()
	return _rock_mesh


static func _flame_mesh() -> ArrayMesh:
	if _plume_mesh != null:
		return _plume_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 10:
		for x in 18:
			for corner in [[x,y],[x+1,y],[x,y+1],[x+1,y],[x+1,y+1],[x,y+1]]:
				var u := float(corner[0]) / 18.0
				var v := float(corner[1]) / 10.0
				var a := u * TAU
				var width := pow(1.0 - v, 0.76) * (0.81 + sin(v * PI) * 0.26)
				width *= 1.0 + sin(a * 5.0 + v * 8.0) * 0.11
				st.set_uv(Vector2(u,v))
				st.set_normal(Vector3(cos(a), 0.3, sin(a)).normalized())
				st.add_vertex(Vector3(cos(a) * width, v, sin(a) * width))
	_plume_mesh = st.commit()
	return _plume_mesh


static func _hemisphere() -> ArrayMesh:
	if _dome_mesh != null:
		return _dome_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 6:
		for x in 36:
			for corner in [[x,y],[x+1,y],[x,y+1],[x+1,y],[x+1,y+1],[x,y+1]]:
				var a := float(corner[0]) / 36.0 * TAU
				var h := float(corner[1]) / 6.0 * PI * 0.5
				var v := Vector3(cos(a) * cos(h), sin(h), sin(a) * cos(h))
				st.set_normal(v)
				st.add_vertex(v)
	_dome_mesh = st.commit()
	return _dome_mesh
