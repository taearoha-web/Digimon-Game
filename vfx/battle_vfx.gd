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
## Fade ramps keyed by colour: emitters only read them, so bursts of the same
## colour share one instead of allocating a Gradient per hit (cleared at 128).
static var _ramps: Dictionary = {}


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
	MaterialKeeper.keep(mat)
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
const FLOATING_FONT_SIZE := 72


## World-space size of floating texts and name tags: the field camera is far away.
static var text_scale := 1.0


## Damage numbers: what the hero's side deals is yellow-orange, what the hero
## takes is blood red. Both use the same thick black outline.
const DAMAGE_DEALT := Color("ffae1a")
const DAMAGE_TAKEN := Color("d3121f")
const DAMAGE_OUTLINE := Color(0, 0, 0)
const DAMAGE_OUTLINE_WIDTH := 34


static var _damage_font: FontVariation

## Set by party members and world players around their own hits (Companion._deal), so
## the numbers they cause are drawn as someone else's: smaller, dimmer and capped.
static var dealing_other := false
## Others' numbers drawn at once at most; a new one drops the oldest. The hero's own
## numbers are never dropped.
const OTHERS_CAP := 8
## Others' numbers next to the hero's: this much smaller, and this see-through.
const OTHERS_SIZE := 0.7
const OTHERS_ALPHA := 0.72
## Damage numbers are drawn a little smaller than other floating texts (phones).
const NUMBER_SIZE := 0.86
## The hero's own critical hits: gold-yellow and a little bigger still.
const CRIT_COLOR := Color("ffe23a")
## Texts that spawn within STAGGER_RADIUS metres of one spawned less than STAGGER_TIME
## seconds ago fan out (sideways and up), so a burst of hits stays readable.
const STAGGER_RADIUS := 1.1
const STAGGER_TIME := 0.85
const STAGGER_SIDE := 0.7
const STAGGER_UP := 0.4
const _RECENT_MAX := 24
## [base position, spawn seconds] of the latest texts (a small ring of recent spawns).
static var _recent: Array = []
## Others' numbers still on screen, oldest first.
static var _others: Array = []
## Seconds for the stagger window (tests set it; below 0 the engine clock).
static var clock_override := -1.0


static func damage_number(parent: Node3D, pos: Vector3, text: String, taken: bool, size := 1.0, other := false) -> Label3D:
	if _damage_font == null:
		# The heading face drawn heavier, so the colour still reads inside the black edge.
		_damage_font = FontVariation.new()
		_damage_font.base_font = load("res://ui/theme/fonts/heading_font.tres")
		_damage_font.variation_embolden = 1.1
	other = other or dealing_other
	# Small ticks (a burn) still give way when the screen is full; real hits never do.
	if not other and size < 0.75 and _floating_active > 26:
		return null
	var color := DAMAGE_TAKEN if taken else DAMAGE_DEALT
	size *= NUMBER_SIZE
	if other:
		size *= OTHERS_SIZE
		color = color.lerp(Color(0.75, 0.72, 0.68), 0.25)
		color.a = OTHERS_ALPHA
	elif not taken and text.ends_with("!"):
		color = CRIT_COLOR
		size *= 1.12
	return _spawn_text(parent, pos, text, color, size, DAMAGE_OUTLINE, DAMAGE_OUTLINE_WIDTH, _damage_font, 2 if other else 1)


## A party member's own number (the damage it takes) in its own colour: drawn as others'.
static func other_number(parent: Node3D, pos: Vector3, text: String, color: Color, size := 1.0) -> Label3D:
	color.a = OTHERS_ALPHA
	return _spawn_text(parent, pos, text, color, size * NUMBER_SIZE * OTHERS_SIZE, Color(0.03, 0.05, 0.14), 22, null, 2)


static func floating_text(parent: Node3D, pos: Vector3, text: String, color: Color, size := 1.0,
		outline := Color(0.03, 0.05, 0.14), outline_width := 22, font: Font = null) -> Label3D:
	return _spawn_text(parent, pos, text, color, size, outline, outline_width, font, 0)


static func _clock() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_ticks_msec() * 0.001


## Where a text spawned at [param pos] goes: the k-th text near recent ones fans out
## right, left, further right... and a step higher each time (seen from the camera).
static func stagger(parent: Node3D, pos: Vector3) -> Vector3:
	var now := _clock()
	var near := 0
	var kept: Array = []
	for r in _recent:
		if now - float(r[1]) > STAGGER_TIME:
			continue
		kept.append(r)
		var d: Vector3 = r[0] - pos
		d.y *= 0.5
		if d.length() < STAGGER_RADIUS:
			near += 1
	_recent = kept
	_recent.append([pos, now])
	while _recent.size() > _RECENT_MAX:
		_recent.pop_front()
	if near == 0:
		return pos
	var k := (near - 1) % 6 + 1
	var side := Vector3.RIGHT
	var cam: Camera3D = parent.get_viewport().get_camera_3d() if parent and parent.is_inside_tree() else null
	if cam:
		side = cam.global_transform.basis.x
		side.y = 0.0
		side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var lane := float(ceili(k / 2.0))
	var dir_sign := 1.0 if k % 2 == 1 else -1.0
	var unit := text_scale * 0.6
	return pos + side * (dir_sign * lane * STAGGER_SIDE * unit) + Vector3(0, k * STAGGER_UP * unit, 0)


## Kind: 0 a text, 1 the hero's own number (never dropped), 2 someone else's number.
static func _spawn_text(parent: Node3D, pos: Vector3, text: String, color: Color, size: float,
		outline: Color, outline_width: int, font: Font, kind: int) -> Label3D:
	if parent == null or not is_instance_valid(parent):
		return null
	# Many hits at once would pile up unreadably: cap the count and spread them out.
	if kind == 0 and _floating_active > 26 and size < 1.2:
		return null
	if kind == 2:
		_others = _others.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
		while _others.size() >= OTHERS_CAP:
			var oldest: Label3D = _others.pop_front()
			oldest.queue_free()
	pos = stagger(parent, pos) + Vector3(randf_range(-0.08, 0.08), randf_range(0.0, 0.08), randf_range(-0.08, 0.08))
	_floating_active += 1
	var label := Label3D.new()
	label.text = L10n.t(text)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font = font if font else load("res://ui/theme/fonts/heading_font.tres")
	# One glyph-atlas size per font: every distinct (font size, outline) pair builds its own
	# 1024px atlas pages, so the text is drawn at a fixed size and scaled in the world instead.
	label.font_size = FLOATING_FONT_SIZE
	label.outline_size = int(outline_width * FLOATING_FONT_SIZE / 96.0)
	label.pixel_size = 0.0042 * text_scale * size * 96.0 / FLOATING_FONT_SIZE
	label.modulate = color
	if kind == 2:
		outline.a *= OTHERS_ALPHA
	label.outline_modulate = outline
	# The hero's own numbers draw over others' when they cross.
	label.render_priority = 3 if kind == 1 else (1 if kind == 2 else 2)
	if kind == 2:
		label.set_meta(&"other", true)
		_others.append(label)
	parent.add_child(label)
	# Released when the label leaves the tree, whether its tween freed it or the
	# zone was unloaded under it; a callback alone left the count stuck high and
	# small numbers stopped appearing for good in long sessions.
	label.tree_exited.connect(func(): _floating_active = maxi(0, _floating_active - 1), CONNECT_ONE_SHOT)
	label.global_position = pos
	label.scale = Vector3.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", pos + Vector3(0, 0.9, 0), 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
	return label


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
	var reserved := VfxBudget.track_particles(p, amount)
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.color_ramp = _fade_ramp(color)
	parent.add_child(p)
	p.position = pos if parent is Node3D and not one_shot else Vector3.ZERO
	if one_shot:
		p.global_position = pos
		p.emitting = reserved
		p.finished.connect(p.queue_free)
		if not reserved:
			p.queue_free()
	return p


static func _fade_ramp(color: Color) -> Gradient:
	var key := color.to_rgba32()
	if _ramps.has(key):
		return _ramps[key]
	if _ramps.size() >= 128:
		_ramps.clear()
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.3))
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	_ramps[key] = gradient
	return gradient


static func _flash_light(parent: Node3D, pos: Vector3, color: Color, energy := 2.0) -> void:
	if not VfxBudget.can_light():
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = minf(energy, 0.8)
	light.omni_range = 4.0
	parent.add_child(light)
	VfxBudget.track_light(light)
	light.global_position = pos
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)
