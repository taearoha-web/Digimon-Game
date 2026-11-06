class_name SignatureKit
extends Node3D
## The layer kit under the class signatures of the Archer (ArcherArt), the
## Assassin (AssassinSignature) and the Dark Lord (LordSignature). One driver
## per cast (this node) runs its layers on one clock:
##   sheets: pooled quads drawn by signature_glow / signature_ink (soft glow,
##           shock ring, torn crescent, crit X, streak, rune ring, dark disc,
##           flame tongue, bolt strand, feather vane) that move with easing and
##           overshoot, turn, flicker and dissolve;
##   bursts: pooled CPUParticles3D (feathers and sparks under gravity, embers
##           and vapour rising with a swirl, billowing smoke, ground dust, drips)
##           fired at their beat in world space, so they lag behind movers.
## A driver can ride a flight (from -> to over the projectile's seconds).
##
## Every layer has a detail level: CORE (always), MAIN (dropped when only the
## core may draw: low quality or memory pressure 2) and DEBRIS (also dropped at
## medium quality or memory pressure 1, with the lights; particle counts halve).
## Drivers, sheets and emitters return to static pools when done, so casting
## does not grow the scene; VfxBudget accounts every live sheet and particle.
## Cosmetic only: never selects victims, deals damage or changes timing.

const GLOW := preload("res://shaders/signature_glow.gdshader")
const INK := preload("res://shaders/signature_ink.gdshader")
enum { SOFT, RING, TEAR, CROSS, STREAK, RUNES, DARK, FLAME, BOLT, FEATHER }
enum { CORE, MAIN, DEBRIS }
enum { LINEAR, OUT, BACK, IN }
## Decorations left free for hits and other casters (SculptureArt.RESERVE).
const RESERVE := 6
## The core layers draw while the shared budget has these few left.
const CORE_RESERVE := 2
const SHEET_POOL := 64
const DRIVER_POOL := 24
const EMITTER_POOL := 8
const BOLT_VARIANTS := 6

static var _sheets: Array = [[], []]
static var _drivers: Array = []
static var _emitters: Dictionary = {}
static var _quad: QuadMesh
static var _bolts: Array = []
static var _ramps: Dictionary = {}
static var _materials: Dictionary = {}
static var _curves: Dictionary = {}
static var _feather_tex: Texture2D
## Pooled nodes wait, hidden and paused, under one holder at the tree root
## (freed with the tree at exit, and by release_pool).
static var _holder: Node
## Sheets drawing right now (all casts).
static var _live := 0
## Built casts (for the tests): drivers started and layers they built.
static var casts := 0
static var layers_built := 0

var age := 0.0
var lifetime := 0.0
var sheets: Array = []
var bursts: Array = []
var owner_ref: WeakRef
var generation := -1
var riding := false
var ride_from := Vector3.ZERO
var ride_to := Vector3.ZERO
var ride_seconds := 0.3
var light: OmniLight3D


# ---------------------------------------------------------------------------
# Budget
# ---------------------------------------------------------------------------

## 2 full, 1 reduced (medium quality or memory pressure 1), 0 core only (low
## quality or memory pressure 2).
static func detail() -> int:
	var quality := VfxBudget.quality()
	if quality == 0 or MemoryGuard.pressure >= 2:
		return 0
	if quality == 1 or MemoryGuard.pressure == 1:
		return 1
	return 2


## The signature's own cap on live sheets of every cast together (quality and
## memory pressure scale it), inside the shared decoration budget: CORE layers
## draw while it has CORE_RESERVE left, MAIN and DEBRIS layers leave RESERVE.
static func sheet_limit() -> int:
	return int([12, 28, 44][VfxBudget.quality()] * MemoryGuard.effect_scale())


static func alive(parent: Node) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


# ---------------------------------------------------------------------------
# Drivers
# ---------------------------------------------------------------------------

## A driver at [param at] facing [param aim] (flat), or null when the budget is full.
static func begin(parent: Node3D, at: Vector3, aim: Vector3, label: String, visual: HeroVisual = null) -> SignatureKit:
	if not alive(parent) or _live >= sheet_limit() or not VfxBudget.can_decorate(1 + CORE_RESERVE):
		return null
	if _bolts.is_empty():
		warm()
	var kit: SignatureKit = null
	while not _drivers.is_empty() and kit == null:
		var pooled = _drivers.pop_back()
		if is_instance_valid(pooled):
			_unpark(pooled)
			kit = pooled
	if kit == null:
		kit = SignatureKit.new()
	kit.name = label
	kit.age = 0.0
	kit.lifetime = 0.05
	kit.riding = false
	kit.owner_ref = weakref(visual) if visual else null
	kit.generation = visual.skill_generation if visual else -1
	kit.rotation = Vector3.ZERO
	parent.add_child(kit)
	kit.global_position = at
	var d := aim - at
	if Vector2(d.x, d.z).length_squared() > 0.0001:
		kit.rotation.y = atan2(d.x, d.z)
	kit.process_mode = Node.PROCESS_MODE_INHERIT
	casts += 1
	return kit


## The driver flies from -> to over seconds (a projectile's flight); its layers ride along.
func ride(from: Vector3, to: Vector3, seconds: float) -> void:
	riding = true
	ride_from = from
	ride_to = to
	ride_seconds = maxf(seconds, 0.05)
	global_position = from
	var d := to - from
	if d.length_squared() > 0.0001:
		look_at(to, Vector3.RIGHT if absf(d.normalized().y) > 0.98 else Vector3.UP, true)


## One sheet. style: to (end position), ease, size, grow (end size), angles,
## ground (lie flat), billboard (0 none, 1 face, 2 axial), basis, spin (rad/s
## round the sheet's normal), roll and roll_speed (billboards), fade_in, decay,
## flicker, opacity, count (rune cells), seed, level (CORE/MAIN/DEBRIS), glow.
func sheet(shape: int, c: Array, at: Vector3, start: float, seconds: float, style := {}) -> void:
	var level := int(style.get("level", MAIN))
	if level > detail() or _live >= sheet_limit() or not VfxBudget.can_decorate(1 + (CORE_RESERVE if level == CORE else RESERVE)):
		return
	var glow := bool(style.get("glow", shape != DARK))
	var node := _take_sheet(glow)
	var mat := node.material_override as ShaderMaterial
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("billboard", int(style.get("billboard", 0)))
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.85)))
	mat.set_shader_parameter("seed", float(style.get("seed", randf() * 10.0)))
	mat.set_shader_parameter("count", float(style.get("count", 12.0)))
	mat.set_shader_parameter("fade", 0.0)
	mat.set_shader_parameter("roll", float(style.get("roll", 0.0)))
	node.visible = false
	add_child(node)
	VfxBudget.track_decoration(node)
	_live += 1
	node.tree_exited.connect(_sheet_gone, CONNECT_ONE_SHOT)
	var basis := Basis.IDENTITY
	if style.has("basis"):
		basis = style.basis
	elif bool(style.get("ground", false)):
		basis = Basis(Vector3.RIGHT, -PI * 0.5)
	elif style.has("angles"):
		basis = Basis.from_euler(style.angles)
	var size: Vector2 = style.get("size", Vector2.ONE)
	sheets.append({"node": node, "mat": mat, "at": at, "to": style.get("to", at), "ease": int(style.get("ease", OUT)),
		"size": size, "grow": style.get("grow", size), "basis": basis, "spin": float(style.get("spin", 0.0)),
		"roll": float(style.get("roll", 0.0)), "roll_speed": float(style.get("roll_speed", 0.0)),
		"start": start, "seconds": maxf(seconds, 0.04), "fade_in": float(style.get("fade_in", 0.08)),
		"decay": float(style.get("decay", 0.55)), "flicker": float(style.get("flicker", 0.0)),
		"gravity": float(style.get("gravity", 0.0)), "bolt": shape == BOLT, "crackle": bool(style.get("crackle", false)),
		"flap": float(style.get("flap", 0.0)), "flap_speed": float(style.get("flap_speed", 14.0)), "phase": float(style.get("phase", 0.0))})
	if shape == BOLT:
		node.mesh = _bolts[randi() % _bolts.size()]
	lifetime = maxf(lifetime, start + seconds + 0.02)
	layers_built += 1


## A bolt of lightning from -> to (local to the driver): jagged, branching,
## flickering between shapes, then an afterglow.
func bolt(c: Array, from: Vector3, to: Vector3, start: float, seconds := 0.32, width := 1.0, level := CORE, crackle := false) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.05:
		return
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var basis := Basis(x, y, z)
	var w := length * 0.9 * width
	sheet(BOLT, c, from, start, seconds, {"basis": basis, "size": Vector2(w, length), "billboard": 2, "flicker": 0.55,
		"decay": 0.8 if crackle else 0.35, "fade_in": 0.01, "ease": LINEAR, "level": level, "opacity": 0.95, "crackle": crackle})


## One particle burst at its beat. preset: motes, gather, embers, sparks,
## feathers, fire_feathers, smoke, vapour, drips, dust, blood, wake.
## style: amount, radius, speed, dir (local), spread, scale, swirl, level,
## stream (seconds of continuous emission, for wakes).
func burst(preset: String, c: Array, at: Vector3, start: float, style := {}) -> void:
	var level := int(style.get("level", DEBRIS if preset in ["sparks", "feathers", "fire_feathers", "drips", "dust", "blood"] else MAIN))
	if level > detail():
		return
	var amount := int(style.get("amount", 12))
	if detail() == 1:
		amount = maxi(2, amount / 2)
	bursts.append({"preset": preset, "c": c, "at": at, "start": start, "style": style, "amount": amount, "fired": false, "emitter": null})
	var stream := float(style.get("stream", 0.0))
	lifetime = maxf(lifetime, start + stream + _life(preset) * 1.15 + 0.05)
	layers_built += 1


## A short light (high quality, no memory pressure, within the light budget).
func lamp(color: Color, at: Vector3, energy := 1.2, reach := 5.0) -> void:
	if detail() < 2 or not VfxBudget.can_light() or light != null:
		return
	light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = at
	add_child(light)
	VfxBudget.track_light(light)


func _process(delta: float) -> void:
	if owner_ref:
		var visual := owner_ref.get_ref() as HeroVisual
		if not is_instance_valid(visual) or visual.skill_generation != generation:
			_finish()
			return
	age += delta
	if riding:
		global_position = ride_from.lerp(ride_to, clampf(age / ride_seconds, 0.0, 1.0))
	_draw()
	for b in bursts:
		if not b.fired and age >= float(b.start):
			b.fired = true
			b.emitter = _fire(b)
	if light:
		light.light_energy *= maxf(0.0, 1.0 - delta * 4.0)
	if age >= lifetime:
		_finish()


func _draw() -> void:
	for s in sheets:
		var node: MeshInstance3D = s.node
		var local := age - float(s.start)
		var t := clampf(local / float(s.seconds), 0.0, 1.0)
		var on := local >= 0.0 and t < 1.0
		node.visible = on
		if not on:
			continue
		var k := t
		match int(s.ease):
			OUT: k = 1.0 - pow(1.0 - t, 3.0)
			BACK:
				var b := t - 1.0
				k = 1.0 + 2.70158 * b * b * b + 1.70158 * b * b
			IN: k = t * t
		var at: Vector3 = (s.at as Vector3).lerp(s.to, k)
		if float(s.gravity) != 0.0:
			at.y -= 0.5 * float(s.gravity) * local * local
		var size: Vector2 = (s.size as Vector2).lerp(s.grow, k)
		var basis: Basis = s.basis
		if float(s.spin) != 0.0:
			basis = basis * Basis(Vector3.BACK, float(s.spin) * local)
		if float(s.flap) != 0.0:
			var turn := Basis(Vector3.BACK, sin(local * float(s.flap_speed) + float(s.phase)) * float(s.flap))
			at = turn * at
			basis = turn * basis
		node.transform = Transform3D(basis * Basis.from_scale(Vector3(maxf(size.x, 0.002), maxf(size.y, 0.002), 1.0)), at)
		var fade := smoothstep(0.0, maxf(float(s.fade_in), 0.001), t) * (1.0 - smoothstep(minf(float(s.decay), 0.98), 1.0, t))
		if float(s.flicker) > 0.0:
			var beat := int(local * 22.0)
			fade *= 1.0 - float(s.flicker) * float(beat % 3 == 1)
			if bool(s.bolt) and beat != int(s.get("last_beat", -1)) and (t < 0.5 or bool(s.crackle)):
				s["last_beat"] = beat
				node.mesh = _bolts[(beat * 7 + node.get_instance_id()) % _bolts.size()]
		var mat: ShaderMaterial = s.mat
		mat.set_shader_parameter(&"fade", fade)
		mat.set_shader_parameter(&"progress", t)
		if float(s.roll_speed) != 0.0:
			mat.set_shader_parameter(&"roll", float(s.roll) + float(s.roll_speed) * local)


func _finish() -> void:
	for s in sheets:
		var node: MeshInstance3D = s.node
		if is_instance_valid(node):
			_give_sheet(node)
	sheets.clear()
	for b in bursts:
		var e = b.emitter
		if e != null and is_instance_valid(e):
			_give_emitter(e, String(b.preset))
	bursts.clear()
	if light:
		light.queue_free()
		light = null
	owner_ref = null
	if _drivers.size() < DRIVER_POOL:
		_park(self)
		_drivers.append(self)
	else:
		queue_free()


# ---------------------------------------------------------------------------
# Pools
# ---------------------------------------------------------------------------

static func _sheet_gone() -> void:
	_live = maxi(0, _live - 1)


static func _park(node: Node) -> void:
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	if not is_instance_valid(_holder):
		_holder = Node.new()
		_holder.name = "SignaturePool"
		_holder.process_mode = Node.PROCESS_MODE_DISABLED
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.add_child.call_deferred(_holder)
	_holder.add_child(node)


static func _unpark(node: Node) -> void:
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)


static func _take_sheet(glow: bool) -> MeshInstance3D:
	var pool: Array = _sheets[0 if glow else 1]
	while not pool.is_empty():
		var node = pool.pop_back()
		if is_instance_valid(node):
			_unpark(node)
			(node as MeshInstance3D).mesh = _unit_quad()
			return node
	var made := MeshInstance3D.new()
	made.mesh = _unit_quad()
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = GLOW if glow else INK
	# Drawn after the other skill art so the signature reads through its glow.
	mat.render_priority = 2
	made.material_override = mat
	made.set_meta("glow", glow)
	return made


static func _give_sheet(node: MeshInstance3D) -> void:
	var pool: Array = _sheets[0 if bool(node.get_meta("glow", true)) else 1]
	if pool.size() < SHEET_POOL:
		node.visible = false
		_park(node)
		pool.append(node)
	else:
		node.queue_free()


static func _give_emitter(e: CPUParticles3D, preset: String) -> void:
	e.emitting = false
	var pool: Array = _emitters.get(preset, [])
	_emitters[preset] = pool
	if pool.size() < EMITTER_POOL:
		e.visible = false
		_park(e)
		pool.append(e)
	else:
		e.queue_free()


## Frees the pooled nodes and cached resources (zone change, MemoryGuard, exit).
static func release_pool() -> void:
	for pool in _sheets:
		for node in pool:
			if is_instance_valid(node):
				node.queue_free()
		pool.clear()
	for node in _drivers:
		if is_instance_valid(node):
			node.queue_free()
	_drivers.clear()
	for preset in _emitters:
		for node in _emitters[preset]:
			if is_instance_valid(node):
				node.queue_free()
	_emitters.clear()
	_ramps.clear()
	if is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null


static func pooled() -> int:
	var n := _drivers.size()
	for pool in _sheets:
		n += pool.size()
	for preset in _emitters:
		n += (_emitters[preset] as Array).size()
	return n


# ---------------------------------------------------------------------------
# Shared resources
# ---------------------------------------------------------------------------

static func _unit_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## Precomputes the jagged branching bolt shapes (unit length along +Y).
static func warm() -> void:
	_unit_quad()
	if _bolts.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 4417
		for v in BOLT_VARIANTS:
			_bolts.append(_bolt_mesh(rng))
	_feather_texture()
	for preset in ["motes", "embers", "smoke", "feathers"]:
		_material(preset)


static func _bolt_mesh(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array = []
	var steps := 12
	var x := 0.0
	for i in steps + 1:
		var y := float(i) / float(steps)
		if i > 0 and i < steps:
			x = clampf(x + rng.randf_range(-0.07, 0.07), -0.12, 0.12) * (1.0 - absf(y - 0.5) * 0.6)
		else:
			x = 0.0
		points.append(Vector2(x, y))
	_bolt_strip(st, points, 0.035)
	for b in 3:
		var from: Vector2 = points[rng.randi_range(3, steps - 3)]
		var branch: Array = [from]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := from
		for k in 4:
			p += Vector2(side * rng.randf_range(0.02, 0.06), rng.randf_range(0.03, 0.07))
			branch.append(p)
		_bolt_strip(st, branch, 0.018)
	return st.commit()


static func _bolt_strip(st: SurfaceTool, points: Array, half: float) -> void:
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var ha := half * (1.0 - 0.5 * float(i) / float(points.size()))
		var hb := half * (1.0 - 0.5 * float(i + 1) / float(points.size()))
		var quad := [Vector3(a.x - ha, a.y, 0), Vector3(b.x - hb, b.y, 0), Vector3(b.x + hb, b.y, 0), Vector3(a.x + ha, a.y, 0)]
		var uvs := [Vector2(0, a.y), Vector2(0, b.y), Vector2(1, b.y), Vector2(1, a.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[k])
			st.set_normal(Vector3.BACK)
			st.add_vertex(quad[k])


static func _feather_texture() -> Texture2D:
	if _feather_tex == null:
		var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
		for py in 64:
			for px in 32:
				var u := (float(px) + 0.5) / 32.0 * 2.0 - 1.0
				var v := (float(py) + 0.5) / 64.0 * 2.0 - 1.0
				var width := 0.85 * sqrt(maxf(0.0, 1.0 - v * v)) * (1.0 - 0.25 * v)
				var vane := clampf((width - absf(u)) * 6.0, 0.0, 1.0)
				var barbs := 0.75 + 0.25 * sin((v + absf(u) * 0.7) * 38.0)
				var shaft := clampf(1.0 - absf(u) / 0.08, 0.0, 1.0) * float(absf(v) < 0.98)
				var a := clampf(vane * barbs + shaft, 0.0, 1.0)
				var light := 0.65 + 0.35 * (1.0 - absf(u))
				img.set_pixel(px, py, Color(light, light, light, a))
		_feather_tex = ImageTexture.create_from_image(img)
	return _feather_tex


static func _life(preset: String) -> float:
	match preset:
		"smoke": return 2.3
		"vapour": return 1.8
		"feathers", "fire_feathers": return 1.5
		"embers": return 1.1
		"dust": return 0.9
		"gather": return 0.45
		"wake": return 0.4
		"drips", "blood", "sparks": return 0.6
	return 0.7


static func _material(preset: String) -> StandardMaterial3D:
	if _materials.has(preset):
		return _materials[preset]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var additive := preset in ["motes", "gather", "embers", "sparks", "fire_feathers", "wake", "drips"]
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	match preset:
		"smoke", "vapour", "dust": mat.albedo_texture = VfxArt.texture("smoke")
		"feathers", "fire_feathers": mat.albedo_texture = _feather_texture()
		"embers", "sparks": mat.albedo_texture = VfxArt.texture("spark")
		_: mat.albedo_texture = VfxKit.soft_dot()
	_materials[preset] = mat
	return mat


static func _curve(kind: String) -> Curve:
	if _curves.has(kind):
		return _curves[kind]
	var curve := Curve.new()
	match kind:
		"grow":
			curve.add_point(Vector2(0, 0.35))
			curve.add_point(Vector2(0.35, 0.8))
			curve.add_point(Vector2(1, 1.0))
		"shrink":
			curve.add_point(Vector2(0, 1.0))
			curve.add_point(Vector2(1, 0.0))
		_:
			curve.add_point(Vector2(0, 0.2))
			curve.add_point(Vector2(0.15, 1.0))
			curve.add_point(Vector2(1, 0.6))
	_curves[kind] = curve
	return curve


## Colour over life: core -> palette -> dark rim, fading in and dissolving out.
static func _ramp(preset: String, c: Array) -> Gradient:
	var key := preset + String(c[0].to_html()) + String(c[1].to_html())
	if _ramps.has(key):
		return _ramps[key]
	var g := Gradient.new()
	var core: Color = c[1]
	var mid: Color = c[0]
	var rim: Color = c[2]
	match preset:
		"vapour":
			g.set_color(0, Color(core, 0.0))
			g.set_color(1, Color(rim, 0.0))
			g.add_point(0.1, Color(core.lerp(mid, 0.6), 0.55))
			g.add_point(0.45, Color(mid, 0.5))
			g.add_point(0.8, Color(rim.lerp(mid, 0.3), 0.3))
		"smoke", "dust":
			var body: Color = mid
			g.set_color(0, Color(body.r, body.g, body.b, 0.0))
			g.set_color(1, Color(rim.r, rim.g, rim.b, 0.0))
			g.add_point(0.08, Color(body.r, body.g, body.b, 0.82))
			g.add_point(0.6, Color(body.lerp(rim, 0.5).r, body.lerp(rim, 0.5).g, body.lerp(rim, 0.5).b, 0.45))
		"feathers":
			g.set_color(0, Color(rim.lerp(mid, 0.35), 0.0))
			g.set_color(1, Color(rim, 0.0))
			g.add_point(0.08, Color(rim.lerp(mid, 0.35), 0.95))
			g.add_point(0.75, Color(rim.lerp(mid, 0.2), 0.8))
		_:
			g.set_color(0, Color(core, 0.0))
			g.set_color(1, Color(rim, 0.0))
			g.add_point(0.06, Color(core.lerp(mid, 0.25), 0.75))
			g.add_point(0.3, Color(mid, 0.6))
			g.add_point(0.75, Color(mid.lerp(rim, 0.6), 0.25))
	_ramps[key] = g
	return g


func _take_emitter(preset: String) -> CPUParticles3D:
	var pool: Array = _emitters.get(preset, [])
	while not pool.is_empty():
		var e = pool.pop_back()
		if is_instance_valid(e):
			_unpark(e)
			return e
	var made := CPUParticles3D.new()
	made.name = "Signature_" + preset
	made.mesh = _unit_quad()
	made.material_override = _material(preset)
	made.one_shot = true
	made.local_coords = false
	made.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	made.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return made


func _fire(b: Dictionary) -> CPUParticles3D:
	if not is_inside_tree():
		return null
	var preset := String(b.preset)
	var style: Dictionary = b.style
	var e := _take_emitter(preset)
	e.visible = true
	e.process_mode = Node.PROCESS_MODE_INHERIT
	e.emitting = false
	add_child(e)
	if not VfxBudget.track_particles(e, int(b.amount)):
		return e
	e.position = b.at
	var scale := float(style.get("scale", 1.0))
	var speed := float(style.get("speed", 1.0))
	var stream := float(style.get("stream", 0.0))
	var swirl := float(style.get("swirl", 0.0))
	e.one_shot = stream <= 0.0
	e.lifetime = _life(preset) * float(style.get("life", 1.0))
	e.explosiveness = 0.0 if stream > 0.0 else 0.85
	e.randomness = 0.4
	e.emission_sphere_radius = float(style.get("radius", 0.3))
	e.direction = style.get("dir", Vector3.UP)
	e.spread = float(style.get("spread", 60.0))
	e.flatness = 0.0
	e.gravity = Vector3.ZERO
	e.damping_min = 0.0
	e.damping_max = 0.0
	e.radial_accel_min = 0.0
	e.radial_accel_max = 0.0
	e.tangential_accel_min = swirl * 0.7
	e.tangential_accel_max = swirl * 1.3
	e.angular_velocity_min = 0.0
	e.angular_velocity_max = 0.0
	e.angle_min = -180.0
	e.angle_max = 180.0
	e.particle_flag_align_y = false
	e.scale_amount_curve = null
	e.color_ramp = _ramp(preset, b.c)
	e.color = Color.WHITE
	match preset:
		"gather":
			e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
			e.emission_sphere_radius = float(style.get("radius", 1.1))
			e.initial_velocity_min = 0.0
			e.initial_velocity_max = 0.2
			e.radial_accel_min = -10.0 * speed
			e.radial_accel_max = -7.0 * speed
			e.scale_amount_min = 0.12 * scale
			e.scale_amount_max = 0.24 * scale
			e.scale_amount_curve = _curve("pop")
		"motes", "wake":
			e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			e.initial_velocity_min = 0.4 * speed
			e.initial_velocity_max = 1.6 * speed
			e.damping_min = 2.0
			e.damping_max = 3.5
			e.gravity = Vector3(0, 0.5, 0)
			e.scale_amount_min = 0.1 * scale
			e.scale_amount_max = 0.26 * scale
			e.scale_amount_curve = _curve("shrink")
		"embers":
			e.initial_velocity_min = 0.8 * speed
			e.initial_velocity_max = 2.4 * speed
			e.damping_min = 0.6
			e.damping_max = 1.2
			e.gravity = Vector3(0, 1.8, 0)
			e.scale_amount_min = 0.1 * scale
			e.scale_amount_max = 0.22 * scale
			e.scale_amount_curve = _curve("shrink")
			e.angular_velocity_min = -90.0
			e.angular_velocity_max = 90.0
		"sparks":
			e.initial_velocity_min = 3.0 * speed
			e.initial_velocity_max = 6.5 * speed
			e.damping_min = 0.5
			e.damping_max = 1.0
			e.gravity = Vector3(0, -9.0, 0)
			e.scale_amount_min = 0.08 * scale
			e.scale_amount_max = 0.16 * scale
			e.scale_amount_curve = _curve("shrink")
		"feathers", "fire_feathers":
			e.initial_velocity_min = 1.4 * speed
			e.initial_velocity_max = 3.2 * speed
			e.damping_min = 1.6
			e.damping_max = 2.6
			e.gravity = Vector3(0, -1.3, 0)
			e.angular_velocity_min = -220.0
			e.angular_velocity_max = 220.0
			e.scale_amount_min = 0.22 * scale
			e.scale_amount_max = 0.42 * scale
			e.scale_amount_curve = _curve("pop")
		"smoke":
			e.initial_velocity_min = 0.5 * speed
			e.initial_velocity_max = 1.8 * speed
			e.damping_min = 1.0
			e.damping_max = 1.8
			e.gravity = Vector3(0, 0.45, 0)
			e.angular_velocity_min = -35.0
			e.angular_velocity_max = 35.0
			e.scale_amount_min = 1.3 * scale
			e.scale_amount_max = 2.2 * scale
			e.scale_amount_curve = _curve("grow")
			e.explosiveness = 0.0 if stream > 0.0 else 0.8
		"vapour":
			e.initial_velocity_min = 0.2 * speed
			e.initial_velocity_max = 0.8 * speed
			e.damping_min = 0.6
			e.damping_max = 1.2
			e.gravity = Vector3(0, 0.9, 0)
			e.angular_velocity_min = -40.0
			e.angular_velocity_max = 40.0
			e.scale_amount_min = 0.9 * scale
			e.scale_amount_max = 1.6 * scale
			e.scale_amount_curve = _curve("grow")
			e.explosiveness = 0.0 if stream > 0.0 else 0.5
		"drips", "blood":
			e.initial_velocity_min = 0.6 * speed if preset == "drips" else 2.0 * speed
			e.initial_velocity_max = 1.4 * speed if preset == "drips" else 4.2 * speed
			e.gravity = Vector3(0, -9.0, 0)
			e.scale_amount_min = 0.06 * scale
			e.scale_amount_max = 0.13 * scale
			e.explosiveness = 0.3 if preset == "drips" else 0.9
		"dust":
			e.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			e.emission_ring_axis = Vector3.UP
			e.emission_ring_radius = float(style.get("radius", 0.6))
			e.emission_ring_inner_radius = e.emission_ring_radius * 0.6
			e.emission_ring_height = 0.05
			e.direction = Vector3(0, 0.25, 0)
			e.spread = 180.0
			e.flatness = 0.85
			e.initial_velocity_min = 1.2 * speed
			e.initial_velocity_max = 2.8 * speed
			e.damping_min = 3.0
			e.damping_max = 4.5
			e.gravity = Vector3(0, 0.3, 0)
			e.scale_amount_min = 0.6 * scale
			e.scale_amount_max = 1.1 * scale
			e.scale_amount_curve = _curve("grow")
	if preset != "dust" and preset != "gather":
		e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	if stream > 0.0:
		e.emitting = true
		var stop := get_tree().create_timer(stream)
		stop.timeout.connect(_stop_stream.bind(weakref(e)), CONNECT_ONE_SHOT)
	else:
		e.restart()
	return e


static func _stop_stream(ref: WeakRef) -> void:
	var e := ref.get_ref() as CPUParticles3D
	if is_instance_valid(e):
		e.emitting = false
