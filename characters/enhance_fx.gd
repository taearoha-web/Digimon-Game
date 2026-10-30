class_name EnhanceFx
extends RefCounted
## How enhanced (+N, up to ItemData.MAX_PLUS = 15) gear looks.
## Every piece glows by its own +: a pulsing overlay in its aura step's colour, stronger
## (grade 1-4) the higher it goes, with sparkles and, at the top, flames on the weapon.
## The body aura comes only from the whole set: the lowest + among the weapon, armour,
## helm and boots (set_plus; wings are not counted). It has nine steps (AURA_STEPS):
##   +5  ประกายฟ้า        pale-blue rim glow, thin ring, rising sparkles
##   +7  ชีพจรคราม        teal aura, a spinning rune ring
##   +9  ทองลุกโชน        golden aura, double ring, halo, three orbiting lights
##   +10 เพลิงแดงขีดสุด    red flames from the ground, a rising ember fountain, four fire orbs
##   +11 อัสนีอเมทิสต์     violet flames, lightning arcs, a charged ring
##   +12 ปีกแสงเทพ        wings of light, a halo, drifting light feathers
##   +13 จักรวาลดารา       nebula wings (violet to pink), twinkling stars, two planet orbits
##   +14 มังกรหยกวิญญาณ    jade wings of light, a jade spirit dragon coiling up the body
##   +15 ตำนานสุริยะรุ้ง     a rainbow sun disc, rainbow wings, a crown of light, petals,
##                        and a spiral of light motes winding up the body

const AURA_STEPS: Array[int] = [5, 7, 9, 10, 11, 12, 13, 14, 15]
const AURA_COLORS: Array[Color] = [Color("a8dcff"), Color("7cc8ff"), Color("36f0d0"), Color("ffc93c"), Color("ff4a28"),
	Color("a855ff"), Color("fff0c0"), Color("8a7dff"), Color("2affa0"), Color("ffe08a")]
const AURA_NAMES: Array[String] = ["ประกายจาง", "ประกายฟ้า", "ชีพจรคราม", "ทองลุกโชน", "เพลิงแดงขีดสุด",
	"อัสนีอเมทิสต์", "ปีกแสงเทพ", "จักรวาลดารา", "มังกรหยกวิญญาณ", "ตำนานสุริยะรุ้ง"]
## The pieces whose lowest + gives the body aura.
const SET_SLOTS: Array[String] = ["weapon", "armor", "helm", "boots"]
## Kept for older callers: the name of a piece's look by grade.
const NAMES: Array[String] = ["", "ประกายจาง", "เรืองแสง", "ลุกโชน", "ขีดสุด"]


## How strongly a piece glows: 0 none, 1 (+1..+4), 2 (+5..+8), 3 (+9..+11), 4 (+12 up).
static func grade(plus: int) -> int:
	if plus <= 0:
		return 0
	if plus <= 4:
		return 1
	if plus <= 8:
		return 2
	if plus <= 11:
		return 3
	return 4


## The aura step of a +: 0 below +5, then 1 (+5) .. 9 (+15).
static func aura_step(plus: int) -> int:
	var step := 0
	for k in AURA_STEPS.size():
		if plus >= AURA_STEPS[k]:
			step = k + 1
	return step


static func color_of(plus: int) -> Color:
	return AURA_COLORS[aura_step(plus)] if plus > 0 else Color(0, 0, 0, 0)


## The look's name for a piece at +plus (item tooltips).
static func look_name(plus: int) -> String:
	return AURA_NAMES[aura_step(plus)] if plus > 0 else ""


## The highest + among the worn items.
static func best_plus(equip: Dictionary) -> int:
	var best := 0
	for slot in equip:
		best = maxi(best, int(equip[slot].get("plus", 0)))
	return best


## The whole set's +: the lowest among SET_SLOTS (a missing piece counts as +0).
static func set_plus(equip: Dictionary) -> int:
	var low := 1 << 20
	for slot in SET_SLOTS:
		var item: Variant = equip.get(slot)
		low = mini(low, int((item as Dictionary).get("plus", 0)) if item is Dictionary else 0)
	return low


static func _glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return MaterialKeeper.keep(m) as StandardMaterial3D


static func _sparkles(parent: Node3D, pos: Vector3, color: Color, amount: int, radius: float, size: float, rise: float, lifetime := 1.1) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	MaterialKeeper.keep(mat)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	# Persistent gear sparkles follow the quality and memory pressure like every
	# other decoration (they do not reserve budget: a worn piece lasts the zone).
	p.amount = VfxBudget.count(amount)
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


static func _flames(parent: Node3D, pos: Vector3, radius: float, amount: int, hot := Color(1.0, 0.95, 0.7), mid := Color(1.0, 0.55, 0.15), tail := Color(0.8, 0.1, 0.05)) -> CPUParticles3D:
	var p := _sparkles(parent, pos, Color.WHITE, amount, radius, 0.34, 1.4, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(hot, 0.9))
	ramp.add_point(0.35, Color(mid, 0.7))
	ramp.set_color(ramp.get_point_count() - 1, Color(tail, 0.0))
	p.color_ramp = ramp
	p.gravity = Vector3(0, 1.6, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.9
	return p


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


## Glow and sparkles on a held weapon (or shield). [param light] is the cheap dressing of
## the other players seen around (HeroVisual.decor_light): the overlay, halo and orbiting
## sparks, but no particle emitters, flames or light, which the phone pays for per frame.
static func on_item(item: Node3D, plus: int, light := false) -> void:
	var g := grade(plus)
	if g == 0:
		return
	var color := color_of(plus)
	var rich := GameSettings.quality > 0 and not light
	var overlay := _glow_material(color, [0.0, 0.07, 0.11, 0.15, 0.2][g])
	for m in MeshKit.collect_meshes(item):
		m.material_overlay = overlay
	var pulse := item.create_tween().set_loops()
	var base_a: float = overlay.albedo_color.a
	var speed: float = [0.0, 1.6, 1.1, 0.8, 0.45][g]
	pulse.tween_property(overlay, "albedo_color:a", base_a * 1.7, speed).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(overlay, "albedo_color:a", base_a * 0.5, speed).set_trans(Tween.TRANS_SINE)
	if GameSettings.quality == 0:
		return
	var center := _bounds_center(item)
	if rich:
		_sparkles(item, center, color, [0, 4, 8, 11, 14][g], 0.2 + 0.03 * g, 0.1 + 0.01 * g, 0.5 + 0.1 * g)
	if g >= 3:
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (0.8 if g == 3 else 1.0)
		var hmat := _glow_material(color, 0.28 if g == 3 else 0.2)
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
	if g == 4 and not light:
		_flames(item, center, 0.08, 7, color.lightened(0.3), color, color.darkened(0.5))
		# One of the three effect lights, high quality only (never one per fighter in a war).
		if VfxBudget.can_light():
			var lamp := OmniLight3D.new()
			lamp.light_color = color
			lamp.light_energy = 0.9
			lamp.omni_range = 4.5
			lamp.position = center
			item.add_child(lamp)
			VfxBudget.track_light(lamp)


## The body aura of the whole set at +plus (set_plus): one of the nine AURA_STEPS.
## [param light] (the other players around): the rings, glow, halo, wings and dragon,
## but no particle emitters, flames or pillar, which the phone pays for per frame.
static func on_body(visual: Node3D, plus: int, light := false) -> Array[Node]:
	var made: Array[Node] = []
	var step := aura_step(plus)
	if step == 0:
		return made
	var root := Node3D.new()
	root.name = "SetAura"
	visual.add_child(root)
	made.append(root)
	var head := 1.85 if bool(visual.get("chibi")) else 2.2
	var rich := GameSettings.quality > 0 and not light and MemoryGuard.pressure < 2
	var color := AURA_COLORS[step]
	match step:
		1:
			_body_glow(root, color, head, 0.16, 1.9)
			_ring(root, color, 0.95, 0.05, 0.6, 5.0)
			if rich:
				_sparkles(root, Vector3(0, head * 0.5, 0), Color("bfe6ff"), 10, 0.55, 0.08, 0.6, 1.4)
		2:
			_body_glow(root, color, head, 0.22, 2.1)
			_ring(root, color, 1.2, 0.05, 0.7, 4.0)
			_runes(root, Color("a8fff0"), 1.2, 10, 3.0)
			if rich:
				_sparkles(root, Vector3(0, 0.3, 0), Color("7dffe6"), 16, 0.8, 0.1, 1.0, 1.5)
		3:
			_body_glow(root, color, head, 0.26, 2.2)
			_ring(root, Color("ffd25a"), 1.28, 0.05, 0.75, 3.5)
			_ring(root, Color("ffb030"), 0.92, 0.07, 0.55, -2.8)
			_runes(root, Color("fff0b0"), 1.28, 12, 3.5)
			_halo(root, Color("ffe27a"), head + 0.2, 0.5)
			_orbs(root, Color("fff2b8"), 3, 1.05, head * 0.55, 2.4, 0.08)
			if rich:
				_sparkles(root, Vector3(0, head * 0.4, 0), Color("ffe08a"), 18, 0.8, 0.1, 0.9, 1.4)
		4:
			_body_glow(root, color, head, 0.28, 2.3)
			_ring(root, Color("ff5a30"), 1.35, 0.05, 0.85, 2.6)
			_orbs(root, Color("ffe0c0"), 4, 1.2, head * 0.5, 1.8, 0.1)
			if rich:
				_embers(root, Color("ffb070"), head)
				_flames(root, Vector3(0, 0.1, 0), 0.9, 22)
				_sparkles(root, Vector3(0, head * 0.4, 0), Color("ffb070"), 14, 0.8, 0.1, 1.2, 1.2)
		5:
			_body_glow(root, color, head, 0.28, 2.3)
			_ring(root, Color("c48bff"), 1.38, 0.05, 0.85, 2.2)
			_lightning(root, Color("e2c8ff"), head, 5)
			if rich:
				_embers(root, Color("d9b8ff"), head)
				_flames(root, Vector3(0, 0.1, 0), 0.85, 20, Color("f2e4ff"), Color("a35cff"), Color("4a12b0"))
				_sparkles(root, Vector3(0, head * 0.4, 0), Color("e2c8ff"), 14, 0.8, 0.1, 1.0, 1.2)
		6:
			_body_glow(root, Color("fff2c8"), head, 0.24, 2.4)
			_wings(root, head, [Color("ffe7a8")], 1.0)
			_halo(root, Color.WHITE, head + 0.22, 0.55)
			_ring(root, Color("ffe6a0"), 1.3, 0.05, 0.7, 3.0)
			if rich:
				_sparkles(root, Vector3(0, head * 0.7, 0), Color("fffbe8"), 12, 1.0, 0.16, -0.25, 3.0)
		7:
			_body_glow(root, Color("5a3dff"), head, 0.3, 2.8)
			_body_glow(root, Color("ff4fb8"), head * 1.2, 0.18, 1.8)
			_wings(root, head, [Color("8a7dff"), Color("c08bff"), Color("ff8fd8"), Color("9fb4ff")], 1.05)
			_orbit_ring(root, Color("9fb4ff"), head * 0.55, 1.6, 0.0, 3.2, Color("bcd0ff"))
			_orbit_ring(root, Color("ff9be0"), head * 0.9, 1.45, 0.35, -2.4, Color("ffb8ee"))
			if rich:
				var stars := _sparkles(root, Vector3(0, head * 0.55, 0), Color.WHITE, 30, 1.3, 0.07, 0.05, 2.5)
				stars.spread = 180.0
		8:
			_body_glow(root, color, head, 0.26, 2.3)
			_ring(root, Color("3dffb0"), 1.4, 0.05, 0.85, 2.4)
			_wings(root, head, [Color("2affa0"), Color("7dffc4"), Color("19d98a")], 1.1)
			_dragon(root, head)
			if rich:
				_sparkles(root, Vector3(0, head * 0.4, 0), Color("9fffd2"), 14, 0.9, 0.1, 0.9, 1.4)
		_:
			_sun_disc(root, head)
			_body_glow(root, Color("fff0c0"), head, 0.22, 2.2)
			var hues: Array = []
			for k in 8:
				hues.append(Color.from_hsv(float(k) / 8.0, 0.55, 1.0))
			_wings(root, head, hues, 1.15)
			_crown(root, Color("fff3b0"), head + 0.12)
			_ring(root, Color.from_hsv(0.1, 0.6, 1.0), 1.45, 0.05, 0.85, 2.0)
			_ring(root, Color.from_hsv(0.6, 0.6, 1.0), 1.12, 0.07, 0.7, -2.6)
			if rich:
				_spiral(root, head)
				_sparkles(root, Vector3(0, head * 0.7, 0), Color("ffd6f0"), 16, 1.1, 0.14, -0.3, 3.0)
				_sparkles(root, Vector3(0, head * 0.4, 0), Color.WHITE, 14, 0.9, 0.08, 0.8, 1.4)
	return made


static var _thin: TorusMesh


## A thin torus (radius 0.485, tube 0.03) shared by every aura ring.
static func _thin_torus() -> TorusMesh:
	if _thin == null:
		_thin = TorusMesh.new()
		_thin.inner_radius = 0.47
		_thin.outer_radius = 0.5
		_thin.rings = 40
		_thin.ring_segments = 6
	return _thin


static func _unshaded(node: GeometryInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A soft billboard glow around the body (reads as a rim aura from any side).
static func _body_glow(root: Node3D, color: Color, head: float, alpha: float, size: float) -> void:
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size * 0.75, size)
	var mat := _glow_material(color, minf(0.9, alpha * 1.8))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	quad.material = mat
	glow.mesh = quad
	glow.position = Vector3(0, head * 0.5, -0.15)
	_unshaded(glow)
	root.add_child(glow)
	var breathe := glow.create_tween().set_loops()
	breathe.tween_property(glow, "scale", Vector3.ONE * 1.08, 1.1).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(glow, "scale", Vector3.ONE * 0.94, 1.1).set_trans(Tween.TRANS_SINE)


## A flat glowing ring at height y, radius r, spinning once in `period` s (negative: back).
static func _ring(root: Node3D, color: Color, r: float, y: float, alpha: float, period: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.mesh = _thin_torus()
	ring.material_override = _glow_material(color, alpha)
	var s := r / 0.485
	ring.scale = Vector3(s, 0.6, s)
	ring.position = Vector3(0, y, 0)
	_unshaded(ring)
	root.add_child(ring)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU * signf(period), absf(period)).from(0.0)
	return ring


## Little rune diamonds on a spinning ring at the feet.
static func _runes(root: Node3D, color: Color, r: float, count: int, period: float) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var mat := _glow_material(color, 0.9)
	for k in count:
		var a := TAU * float(k) / float(count)
		var rune := MeshInstance3D.new()
		rune.mesh = MeshKit.box()
		rune.material_override = mat
		rune.scale = Vector3(0.07, 0.015, 0.07)
		rune.rotation.y = a + PI / 4.0
		rune.position = Vector3(cos(a) * r, 0.07, sin(a) * r)
		_unshaded(rune)
		holder.add_child(rune)
	var spin := holder.create_tween().set_loops()
	spin.tween_property(holder, "rotation:y", -TAU, period).from(0.0)


static func _halo(root: Node3D, color: Color, y: float, r: float) -> void:
	var halo := _ring(root, color, r, y, 0.95, 6.0)
	halo.scale.y = 1.4


## `count` glowing orbs circling at height y, radius r.
static func _orbs(root: Node3D, color: Color, count: int, r: float, y: float, period: float, size: float) -> void:
	var orbit := Node3D.new()
	orbit.position = Vector3(0, y, 0)
	root.add_child(orbit)
	var mat := _glow_material(color, 0.95)
	for k in count:
		var a := TAU * float(k) / float(count)
		var orb := MeshInstance3D.new()
		orb.mesh = MeshKit.sphere_low()
		orb.material_override = mat
		orb.scale = Vector3.ONE * size * 2.0
		orb.position = Vector3(cos(a) * r, sin(a * 2.0) * 0.15, sin(a) * r)
		_unshaded(orb)
		orbit.add_child(orb)
	var spin := orbit.create_tween().set_loops()
	spin.tween_property(orbit, "rotation:y", TAU, period).from(0.0)


## A fountain of embers rising from the feet past the head (no hard beam).
static func _embers(root: Node3D, color: Color, head: float) -> void:
	var p := _sparkles(root, Vector3(0, 0.15, 0), color, 16, 0.5, 0.09, 1.6, 1.5)
	p.spread = 12.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3


## Rainbow light motes winding up around the body (the +15 crown of the aura).
static func _spiral(root: Node3D, head: float) -> void:
	var holder := Node3D.new()
	holder.name = "Spiral"
	root.add_child(holder)
	var count := 14
	for i in count:
		var t := float(i) / float(count)
		var a := t * 2.0 * TAU
		var mote := MeshInstance3D.new()
		mote.mesh = MeshKit.sphere_low()
		mote.material_override = _glow_material(Color.from_hsv(t, 0.55, 1.0), 0.95)
		mote.scale = Vector3.ONE * (0.09 + 0.05 * sin(t * PI))
		mote.position = Vector3(cos(a) * 0.62, 0.15 + t * (head + 0.2), sin(a) * 0.62)
		_unshaded(mote)
		holder.add_child(mote)
	var spin := holder.create_tween().set_loops()
	spin.tween_property(holder, "rotation:y", TAU, 3.5).from(0.0)


## Short lightning arcs around the body that jump to new places a few times a second.
static func _lightning(root: Node3D, color: Color, head: float, count: int) -> void:
	var holder := Node3D.new()
	holder.name = "Lightning"
	root.add_child(holder)
	var mat := _glow_material(color, 0.95)
	var bolts: Array[MeshInstance3D] = []
	for k in count * 3:
		var seg := MeshInstance3D.new()
		seg.mesh = MeshKit.box()
		seg.material_override = mat
		_unshaded(seg)
		holder.add_child(seg)
		bolts.append(seg)
	var jump := func():
		for k in count:
			var a := randf() * TAU
			var p := Vector3(cos(a) * randf_range(0.55, 0.8), randf_range(0.2, head), sin(a) * randf_range(0.55, 0.8))
			for j in 3:
				var q := p + Vector3(randf_range(-0.18, 0.18), -randf_range(0.15, 0.3), randf_range(-0.18, 0.18))
				var seg := bolts[k * 3 + j]
				seg.position = (p + q) * 0.5
				seg.scale = Vector3(0.025, p.distance_to(q), 0.025)
				seg.look_at_from_position(seg.position, q, Vector3.FORWARD if absf((q - p).normalized().y) < 0.99 else Vector3.RIGHT)
				seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				seg.visible = randf() < 0.85
				p = q
	jump.call()
	var t := holder.create_tween().set_loops()
	t.tween_interval(0.14)
	t.tween_callback(jump)


## Two wings of light-feathers behind the shoulders, flapping slowly. One colour per
## feather from `colors` (cycled).
static func _wings(root: Node3D, head: float, colors: Array, span: float) -> void:
	var tex := VfxKit.soft_dot()
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(0.22 * side, head * 0.74, -0.42)
		root.add_child(wing)
		var feathers := 8
		for k in feathers:
			var ang := deg_to_rad(-62.0 + float(k) * 88.0 / float(feathers - 1))
			var length := (2.0 - 0.12 * float(k)) * span
			var feather := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(0.3, length)
			var mat := _glow_material(colors[k % colors.size()], 0.95)
			mat.albedo_texture = tex
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			quad.material = mat
			feather.mesh = quad
			# A feather leans out from the root: its base at the shoulder.
			var dir := Vector3(cos(ang) * side, -sin(ang), -0.25).normalized()
			feather.position = dir * length * 0.5
			# Turn the quad's long (Y) axis along dir.
			feather.rotation = Vector3(0, 0, atan2(-dir.x, dir.y))
			_unshaded(feather)
			wing.add_child(feather)
		var flap := wing.create_tween().set_loops()
		flap.tween_property(wing, "rotation:y", 0.25 * side, 1.4).set_trans(Tween.TRANS_SINE)
		flap.tween_property(wing, "rotation:y", -0.1 * side, 1.4).set_trans(Tween.TRANS_SINE)


## A tilted orbit ring with a planet riding it.
static func _orbit_ring(root: Node3D, color: Color, y: float, r: float, tilt: float, period: float, planet: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, y, 0)
	pivot.rotation = Vector3(tilt, 0, tilt * 0.5)
	root.add_child(pivot)
	_ring(pivot, color, r * 0.5, 0.0, 0.8, period * 2.0)
	var arm := Node3D.new()
	pivot.add_child(arm)
	var ball := MeshInstance3D.new()
	ball.mesh = MeshKit.sphere_low()
	ball.material_override = _glow_material(planet, 0.95)
	ball.scale = Vector3.ONE * 0.16
	ball.position = Vector3(r * 0.5, 0, 0)
	_unshaded(ball)
	arm.add_child(ball)
	var spin := arm.create_tween().set_loops()
	spin.tween_property(arm, "rotation:y", TAU * signf(period), absf(period)).from(0.0)


## A jade spirit dragon: glowing beads along a helix from the feet to above the head,
## turning so it seems to coil, with a horned head on top.
static func _dragon(root: Node3D, head: float) -> void:
	var coil := Node3D.new()
	coil.name = "Dragon"
	root.add_child(coil)
	var body := _glow_material(Color("14b870"), 0.75)
	var belly := _glow_material(Color("7dffc4"), 0.8)
	var beads := 30
	var last := Vector3.ZERO
	for i in beads:
		var t := float(i) / float(beads - 1)
		var a := t * 3.2 * PI
		var r := 0.85 - 0.25 * t
		var p := Vector3(cos(a) * r, 0.1 + t * (head + 0.35), sin(a) * r)
		var bead := MeshInstance3D.new()
		bead.mesh = MeshKit.sphere_low()
		bead.material_override = body if i % 3 != 0 else belly
		bead.scale = Vector3.ONE * (0.3 - 0.13 * t)
		bead.position = p
		_unshaded(bead)
		coil.add_child(bead)
		last = p
	var skull := MeshInstance3D.new()
	skull.mesh = MeshKit.sphere_low()
	skull.material_override = belly
	skull.scale = Vector3(0.3, 0.22, 0.42)
	skull.position = last + Vector3(0, 0.08, 0)
	_unshaded(skull)
	coil.add_child(skull)
	for side in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		horn.mesh = MeshKit.cone()
		horn.material_override = belly
		horn.scale = Vector3(0.05, 0.22, 0.05)
		horn.position = skull.position + Vector3(0.07 * side, 0.14, -0.06)
		horn.rotation = Vector3(-0.5, 0, 0.3 * side)
		_unshaded(horn)
		coil.add_child(horn)
	var spin := coil.create_tween().set_loops()
	spin.tween_property(coil, "rotation:y", -TAU, 5.0).from(0.0)
	var sway := coil.create_tween().set_loops()
	sway.tween_property(coil, "position:y", 0.08, 1.2).set_trans(Tween.TRANS_SINE)
	sway.tween_property(coil, "position:y", -0.04, 1.2).set_trans(Tween.TRANS_SINE)


static var _sun_texture: Texture2D


## The rainbow ring and rays of the +15 sun disc (one shared texture).
static func _sun_tex() -> Texture2D:
	if _sun_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.66, 0.7, 0.74, 0.78, 0.82, 0.86, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 0.95, 0.8, 0.35), Color(1, 0.9, 0.7, 0.05), Color.from_hsv(0.0, 0.7, 1.0, 0.9),
			Color.from_hsv(0.12, 0.7, 1.0, 0.9), Color.from_hsv(0.3, 0.7, 1.0, 0.9), Color.from_hsv(0.5, 0.7, 1.0, 0.9),
			Color.from_hsv(0.65, 0.7, 1.0, 0.9), Color.from_hsv(0.8, 0.7, 1.0, 0.9), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_sun_texture = tex
	return _sun_texture


static func _sun_disc(root: Node3D, head: float) -> void:
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 2.6)
	var mat := _glow_material(Color.WHITE, 0.85)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = _sun_tex()
	quad.material = mat
	disc.mesh = quad
	disc.position = Vector3(0, head * 0.62, -0.35)
	_unshaded(disc)
	root.add_child(disc)
	var turn := disc.create_tween().set_loops()
	turn.tween_property(disc, "scale", Vector3.ONE * 1.06, 1.6).set_trans(Tween.TRANS_SINE)
	turn.tween_property(disc, "scale", Vector3.ONE * 0.96, 1.6).set_trans(Tween.TRANS_SINE)


## A crown of light points floating over the head.
static func _crown(root: Node3D, color: Color, y: float) -> void:
	var crown := Node3D.new()
	crown.position = Vector3(0, y, 0)
	root.add_child(crown)
	var mat := _glow_material(color, 0.95)
	for k in 7:
		var a := TAU * float(k) / 7.0
		var spike := MeshInstance3D.new()
		spike.mesh = MeshKit.cone()
		spike.material_override = mat
		spike.scale = Vector3(0.05, 0.16 if k % 2 == 0 else 0.1, 0.05)
		spike.position = Vector3(cos(a) * 0.24, 0.06, sin(a) * 0.24)
		_unshaded(spike)
		crown.add_child(spike)
	var spin := crown.create_tween().set_loops()
	spin.tween_property(crown, "rotation:y", TAU, 7.0).from(0.0)


## Wings at +10 and up get their own flair, in their aura step's colour: a soft glow
## spread behind them and light feathers drifting down (+15: every colour of the rainbow).
## Returns the holder (the caller frees it with the outfit), or null below +10.
static func wing_flair(owner: Node3D, plus: int, spot: Vector3, light := false) -> Node3D:
	if plus < 10:
		return null
	var color := color_of(plus)
	var holder := Node3D.new()
	holder.name = "WingFlair"
	holder.position = spot
	owner.add_child(holder)
	# The feathers themselves shine in the step's colour, brighter each step.
	var shine := _glow_material(color, 0.24 + 0.05 * float(plus - 10))
	for m in MeshKit.collect_meshes(owner):
		m.material_overlay = shine
	var pulse := holder.create_tween().set_loops()
	pulse.tween_property(shine, "albedo_color:a", shine.albedo_color.a * 1.6, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(shine, "albedo_color:a", shine.albedo_color.a * 0.7, 0.9).set_trans(Tween.TRANS_SINE)
	var glow := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 1.9)
	var mat := _glow_material(color, 0.3 + 0.06 * float(plus - 10))
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = VfxKit.soft_dot()
	quad.material = mat
	glow.mesh = quad
	glow.position = Vector3(0, 0.15, -0.45)
	_unshaded(glow)
	holder.add_child(glow)
	var breathe := glow.create_tween().set_loops()
	breathe.tween_property(glow, "scale", Vector3.ONE * 1.12, 1.3).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(glow, "scale", Vector3.ONE * 0.92, 1.3).set_trans(Tween.TRANS_SINE)
	if GameSettings.quality > 0 and not light and MemoryGuard.pressure < 2:
		var drift := _sparkles(holder, Vector3(0, 0.3, -0.45), color.lightened(0.35), 10 + 3 * (plus - 10), 1.0, 0.16, 0.25, 2.2)
		drift.name = "WingFeathers"
		drift.spread = 60.0
		if plus >= 15:
			var ramp := Gradient.new()
			ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
			ramp.colors = PackedColorArray([Color.from_hsv(0.0, 0.6, 1.0, 0.9), Color.from_hsv(0.16, 0.6, 1.0, 0.9),
				Color.from_hsv(0.45, 0.6, 1.0, 0.8), Color.from_hsv(0.65, 0.6, 1.0, 0.6), Color.from_hsv(0.82, 0.6, 1.0, 0.0)])
			drift.color_ramp = ramp
	return holder


## Slots that cannot be enhanced (they stay as they are).
const FIXED_SLOTS: Array[String] = ["ring", "amulet"]


static func can_enhance(item: Dictionary) -> bool:
	return item.get("kind", "") == "equip" and not (String(item.get("slot", "")) in FIXED_SLOTS)


## Every enhanced piece glows by itself: an additive overlay on its own meshes
## (stronger and faster-pulsing with the grade) plus a little sparkle at its spot.
## spot = where on the body the sparkles rise (visual space).
## Returns the holder of the sparkles and the pulse tween (null when nothing
## glows): the caller keeps it with the outfit so a re-dress frees it; before,
## every equipment refresh stacked another set of emitters and an endless tween
## on the visual for the rest of the zone.
## [param light] (the other players around) keeps the pulsing overlay only.
static func glow_piece(owner: Node3D, nodes: Array, plus: int, spot: Vector3, spread := 0.3, light := false) -> Node3D:
	var g := grade(plus)
	if g == 0:
		return null
	var color := color_of(plus)
	var overlay := _glow_material(color, [0.0, 0.05, 0.08, 0.11, 0.15][g])
	var found := false
	for node in nodes:
		if not is_instance_valid(node):
			continue
		for m in MeshKit.collect_meshes(node):
			m.material_overlay = overlay
			found = true
	if not found:
		return null
	var holder := Node3D.new()
	holder.name = "PieceGlow"
	owner.add_child(holder)
	var base_a: float = overlay.albedo_color.a
	var speed: float = [0.0, 1.8, 1.3, 0.9, 0.5][g]
	var pulse := holder.create_tween().set_loops()
	pulse.tween_property(overlay, "albedo_color:a", base_a * 1.8, speed).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(overlay, "albedo_color:a", base_a * 0.45, speed).set_trans(Tween.TRANS_SINE)
	if GameSettings.quality > 0 and g >= 2 and MemoryGuard.pressure < 2 and not light:
		var p := _sparkles(holder, spot, color, [0, 0, 5, 8, 12][g], spread, 0.1, 0.5 + 0.1 * g, 0.9)
		p.name = "PieceSparkles"
	return holder
