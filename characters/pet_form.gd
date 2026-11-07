class_name PetForm
extends RefCounted
## The look of a pet's form (PetData.stage_for): from the full-grown form on, the hero's
## own pet wears layers of light that build on each other, in its element's colours:
##   full-grown (Lv.80)  PetAura: a wider element ring under its feet.
##   ★100 awakened       Glow (a soft element aura behind the body), Ring2 (a turning thin
##                       ring), Motes (slow orbiting element motes) and a rim of element
##                       light on the model itself (Rim, shaders/pet_form_rim.gdshader).
##   ★200 holy           Crown on its head (fire: a crown of flames, water: an ice
##                       crown, earth: antlers of light), Wings (fire: ember wings,
##                       water: crystal wings, earth: a mantle of leaves), a turning rune
##                       Sigil on the ground and Drift (embers rise, snow and leaves fall).
##   ★300 god            Radiance (a golden sunburst behind it), GodHalo (a gold halo
##                       behind the head), gold-tipped wings, OrbitRings, floating Runes,
##                       a Pillar of light that pulses, the element's own Relics (fire:
##                       a spiral of embers, water: ice shards and mist, earth: floating
##                       stones), a Trail of light where it walks and, at high quality
##                       only, one small Light.
## On a phone budget: every mesh is shared (baked once per element and reused by every
## rebuild: one draw per crown, per wing, per ring of runes), the materials are shared,
## the motes are shader cards (SummonAura's shader, one draw, nothing on the CPU), the
## trail is the one particle emitter and asks VfxBudget, the light asks VfxBudget too.
## tier() trims the layers at low quality and under memory pressure (the pet re-dresses
## when it changes). Everyone else's pet (PetFollower, a lite Pet) wears dress_lite only:
## the rings, the rim tint and, in the god form, a small gold halo.

const RIM_SHADER := preload("res://shaders/pet_form_rim.gdshader")
## Gold of the god form.
const DIVINE := Color("ffe39a")

## Each element: its deep and hot colours, its gold, the motes' texture, the drift
## (texture, SummonAura mode: 1 rise, 3 fall).
const LOOK := {
	"fire": {"deep": Color("ff5a1f"), "hot": Color("ffc04a"), "gold": Color("ffd970"), "mote": "spark", "drift": "flame", "drift_mode": 1},
	"water": {"deep": Color("1f62d8"), "hot": Color("4fa8ee"), "gold": Color("ffd98a"), "mote": "snow", "drift": "snow", "drift_mode": 3},
	"earth": {"deep": Color("5fae3a"), "hot": Color("d8f59a"), "gold": Color("ffe38a"), "mote": "leaf", "drift": "leaf", "drift_mode": 3},
}

## Where the crown sits on each pet: the head's top from the head bone (in the pet's
## heights, the model's rest pose; +z is the pet's front) and the crown's radius.
const HEAD := {
	"fire": {"top": Vector3(0.0, 0.30, 0.10), "size": 0.17},
	"water": {"top": Vector3(0.0, 0.24, 0.02), "size": 0.17},
	"earth": {"top": Vector3(0.0, 0.34, 0.02), "size": 0.15},
}

## How much of its additive light each element's grown pet wears (1 = all). The ice golem
## is pale itself, so every additive layer on it adds up towards white: it wears less,
## and its shape and deep blues read through the light.
const LIGHT := {"fire": 1.0, "water": 0.6, "earth": 1.0}

## Layer names (tests and tools read them).
const AWAKENED_LAYERS := ["Glow", "Ring2", "Motes"]
const HOLY_LAYERS := ["Crown", "Wings", "Sigil", "Drift"]
const GOD_LAYERS := ["Radiance", "GodHalo", "OrbitRings", "Runes", "Pillar", "Relics", "Trail"]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _quad: QuadMesh


## How much a hero's pet wears now: 2 everything (high quality), 1 no light and fewer
## motes (medium quality, or memory a little tight), 0 only the still pieces (low quality
## or memory tight): rings, aura, rim, sigil, crown, halo and sunburst.
static func tier() -> int:
	var q := VfxBudget.quality()
	if q == 0 or MemoryGuard.pressure >= 2:
		return 0
	if q == 1 or MemoryGuard.pressure == 1:
		return 1
	return 2


# ---------------------------------------------------------------------------
# The hero's pet
# ---------------------------------------------------------------------------

## Dresses [param pet] (a Pet: its MonsterVisual is [param visual], [param height] its
## model height) for form [param stage] at [param p_tier]. Returns the node holding the
## layers (child "PetForm" of the pet, scaled with the form by the caller) or null for
## the young and grown forms. The crown and halo ride the head bone: they are kept in
## the returned node's meta "head" and freed with it (see clear).
static func build(pet: Node3D, visual: MonsterVisual, id: String, stage: int, height: float, p_tier: int) -> Node3D:
	set_rim(visual, id, stage)
	if stage < 2:
		return null
	var look: Dictionary = LOOK.get(id, LOOK.fire)
	var h := height
	var root := Node3D.new()
	root.name = "PetForm"
	pet.add_child(root)
	var aura := Pet.ring_for(id)
	aura.name = "PetAura"
	aura.scale = Vector3(1.6, 0.1, 1.6)
	root.add_child(aura)
	if stage < PetData.STAR_STAGE:
		return root
	var hot: Color = look.hot
	var deep: Color = look.deep
	var gold: Color = look.gold
	var god := stage >= PetData.GOD_STAGE
	var lit := float(LIGHT.get(id, 1.0))
	# ★100: the aura, a second ring, orbiting motes.
	var glow := _mi(root, "Glow", _unit_quad(), _mat("glow", hot.lerp(deep, 0.45), (0.2 if god else 0.17) * lit, VfxKit.soft_dot(), true), Vector3(0, h * 0.5, -h * 0.08), Vector3(h * 1.3, h * 1.45, 1.0))
	_breathe(glow, 1.08, 0.94, 1.3)
	var ring2 := _mi(root, "Ring2", EnhanceFx._thin_torus(), _mat("ring", gold if stage >= 4 else hot, 0.8), Vector3(0, 0.06, 0), Vector3(h * 1.55, 0.6, h * 1.55))
	_spin(ring2, 6.0)
	if p_tier >= 1:
		_motes(root, "Motes", 0, String(look.mote), hot, 12 if p_tier >= 2 else 7, 0.24, 0.55, h, h * 0.55)
	if stage < 4:
		return root
	# ★200: crown, wings, sigil, drifting element.
	var head := head_anchor(visual, id, h)
	root.set_meta("head", head)
	var size := float((HEAD.get(id, HEAD.fire) as Dictionary).size) * h
	var crown := _mi(head, "Crown", _crown_mesh(id), _mat("crown", Color.WHITE, 1.0, null, false, true), Vector3.ZERO, Vector3.ONE * size)
	_spin(crown, 14.0)
	if id == "fire":
		var flame := _mi(crown, "CrownFlame", _unit_quad(), _mat("flame", hot, 0.9, VfxArt.texture("flame"), true), Vector3(0, 1.25, 0), Vector3(1.6, 2.4, 1.0))
		_breathe(flame, 1.12, 0.9, 0.35)
	var sigil := _mi(root, "Sigil", _unit_quad(), _mat("sigil", deep.lerp(gold, 0.35 if god else 0.0), 0.62, VfxArt.texture("rune"), false, false, true), Vector3(0, 0.04, 0), Vector3.ONE * h * 2.3)
	sigil.rotation.x = -PI / 2.0
	_spin_holder(root, sigil, -16.0)
	if p_tier >= 1:
		var wings := Node3D.new()
		wings.name = "Wings"
		root.add_child(wings)
		for side in [-1.0, 1.0]:
			var wing := _mi(wings, "Wing", _wing_mesh(id, side, god), _mat("wing", Color.WHITE, (0.6 if god else 0.8) * lit, VfxKit.soft_dot(), false, true), Vector3(0.12 * side * h, h * 0.66, -h * 0.2), Vector3.ONE * h * (1.05 if god else 0.85))
			var flap := wing.create_tween().set_loops()
			flap.tween_property(wing, "rotation:y", 0.22 * side, 1.5).set_trans(Tween.TRANS_SINE)
			flap.tween_property(wing, "rotation:y", -0.12 * side, 1.5).set_trans(Tween.TRANS_SINE)
		_motes(root, "Drift", int(look.drift_mode), String(look.drift), hot.lerp(gold, 0.3), 12 if p_tier >= 2 else 8, 0.3, 0.8, h * 1.1, h * 0.7)
	if not god:
		return root
	# ★300: the god form.
	var radiance := Node3D.new()
	radiance.name = "Radiance"
	radiance.position = Vector3(0, h * 0.62, -h * 0.32)
	root.add_child(radiance)
	var rays := _mi(radiance, "Rays", _unit_quad(), _mat("rays", DIVINE, 0.15 * lit, VfxArt.texture("rays"), true), Vector3.ZERO, Vector3.ONE * h * 2.6)
	_breathe(rays, 1.06, 0.95, 1.8)
	if p_tier >= 2:
		var flare := _mi(radiance, "Flare", _unit_quad(), _mat("flare", gold, 0.3 * lit, VfxArt.texture("flare"), true), Vector3(0, 0, 0.02), Vector3.ONE * h * 1.7)
		_breathe(flare, 1.1, 0.9, 1.1)
	var halo := _mi(head, "GodHalo", EnhanceFx._thin_torus(), _mat("halo", DIVINE, 0.95), Vector3(0, 0.05 * h, -size * 1.6), Vector3(size * 4.2, 2.2, size * 4.2))
	halo.rotation.x = PI / 2.0
	_breathe(halo, 1.06, 0.97, 1.2)
	if p_tier < 1:
		return root
	var orbit := Node3D.new()
	orbit.name = "OrbitRings"
	orbit.position = Vector3(0, h * 0.5, 0)
	root.add_child(orbit)
	for k in 2:
		var pivot := Node3D.new()
		pivot.rotation = Vector3(0.5 if k == 0 else -0.45, 0.0, 0.3 if k == 0 else -0.25)
		orbit.add_child(pivot)
		var band := _mi(pivot, "Band", _orbit_mesh(), _mat("orbit", Color.WHITE if lit >= 1.0 else hot.lerp(deep, 0.3), 0.55 * lit, null, false, true), Vector3.ZERO, Vector3.ONE * h * (0.78 + 0.1 * k))
		_spin(band, 4.0 if k == 0 else -5.5)
	var runes := _mi(root, "Runes", _runes_mesh(), _mat("runes", DIVINE, 0.95, VfxArt.texture("rune"), false, true), Vector3(0, h * 0.3, 0), Vector3.ONE * h)
	_spin(runes, 9.0)
	var bob := runes.create_tween().set_loops()
	bob.tween_property(runes, "position:y", h * 0.42, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(runes, "position:y", h * 0.3, 1.6).set_trans(Tween.TRANS_SINE)
	var column := VfxKit.column_material(hot if lit >= 1.0 else deep, hot.lerp(DIVINE, 0.5 * lit), 0.2 * lit)
	var pillar := _mi(root, "Pillar", VfxKit._column_mesh(), column, Vector3.ZERO, Vector3(h * 0.65, h * 4.5, h * 0.65))
	var beat := pillar.create_tween().set_loops()
	beat.tween_method(func(v: float): column.set_shader_parameter("fade", v * lit), 0.06, 0.24, 0.35).set_trans(Tween.TRANS_SINE)
	beat.tween_method(func(v: float): column.set_shader_parameter("fade", v * lit), 0.24, 0.06, 1.4).set_trans(Tween.TRANS_SINE)
	beat.tween_interval(1.2)
	_relics(root, id, look, h, p_tier)
	_trail(root, hot.lerp(DIVINE, 0.4 * lit), h)
	if p_tier >= 2 and VfxBudget.can_light():
		var light := OmniLight3D.new()
		light.name = "Light"
		light.light_color = hot.lerp(DIVINE, 0.5)
		light.light_energy = 0.7 * lit
		light.omni_range = h * 3.0
		light.position = Vector3(0, h * 0.8, 0)
		root.add_child(light)
		VfxBudget.track_light(light)
	return root


## Frees what build made (the layers and the crown riding the head bone).
static func clear(root: Node3D) -> void:
	if root == null or not is_instance_valid(root):
		return
	var head: Variant = root.get_meta("head") if root.has_meta("head") else null
	if head != null and is_instance_valid(head):
		var anchor := (head as Node).get_parent()
		var gone: Node = anchor if anchor is BoneAttachment3D else head
		if gone.get_parent():
			gone.get_parent().remove_child(gone)
		gone.queue_free()
	if root.get_parent():
		root.get_parent().remove_child(root)
	root.queue_free()


## The names of the layers on [param root] (and its head anchor), for tests.
static func layers(root: Node3D) -> Array[String]:
	var out: Array[String] = []
	if root == null or not is_instance_valid(root):
		return out
	for child in root.get_children():
		out.append(String(child.name))
	var head: Variant = root.get_meta("head") if root.has_meta("head") else null
	if head != null and is_instance_valid(head):
		for child in (head as Node).get_children():
			out.append(String(child.name))
	return out


## A point riding the pet's head bone at the top of its head (in the visual's own
## units, upright in the rest pose): a BoneAttachment3D on the "head" bone, else a node
## on the visual at the model's height.
static func head_anchor(visual: MonsterVisual, id: String, h: float) -> Node3D:
	var spot := Node3D.new()
	spot.name = "PetFormHead"
	var top: Vector3 = (HEAD.get(id, HEAD.fire) as Dictionary).top * h
	var skeleton: Skeleton3D = null
	if visual.model:
		var found := visual.model.find_children("*", "Skeleton3D", true, false)
		if not found.is_empty():
			skeleton = found[0]
	var bone := skeleton.find_bone("head") if skeleton else -1
	if bone < 0:
		spot.position = Vector3(0, h + top.y * 0.3, 0)
		visual.add_child(spot)
		return spot
	# The hit flash lists the model's meshes once: list them before the crown is on.
	visual._flash_targets()
	var attach := BoneAttachment3D.new()
	attach.name = "PetFormHeadBone"
	attach.bone_name = "head"
	skeleton.add_child(attach)
	attach.add_child(spot)
	# Skeleton space -> the visual's space, without the pet's own (tweened) scale.
	var to_visual := _relative(visual, skeleton)
	var rest := skeleton.get_bone_global_rest(bone)
	var basis := to_visual.basis * rest.basis
	var inv := basis.inverse()
	spot.transform = Transform3D(inv, inv * top)
	return spot


## [param node]'s transform in [param visual]'s space (through the parents, not the
## globals: the pet may be mid spawn-tween).
static func _relative(visual: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != visual:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## The element's god relics (★300, medium quality and up).
static func _relics(root: Node3D, id: String, look: Dictionary, h: float, p_tier: int) -> void:
	var relics := Node3D.new()
	relics.name = "Relics"
	root.add_child(relics)
	match id:
		"fire":
			_motes(relics, "Embers", 2, "spark", DIVINE, 14 if p_tier >= 2 else 9, 0.22, 0.9, h * 1.2, h * 0.6)
		"water":
			var mist := _mi(relics, "Mist", _unit_quad(), _mat("mist", look.hot, 0.2, VfxArt.texture("smoke"), false, false, true), Vector3(0, 0.12, 0), Vector3.ONE * h * 2.2)
			mist.rotation.x = -PI / 2.0
			_spin_holder(relics, mist, 20.0)
			var shards := _mi(relics, "Shards", _shards_mesh(), _mat("shards", Color.WHITE, 0.42, null, false, true), Vector3(0, h * 0.55, 0), Vector3.ONE * h)
			_spin(shards, -7.0)
		_:
			var stones := _mi(relics, "Stones", _stones_mesh(), _stone_mat(), Vector3(0, h * 0.2, 0), Vector3.ONE * h)
			_spin(stones, 10.0)
			var lift := stones.create_tween().set_loops()
			lift.tween_property(stones, "position:y", h * 0.32, 1.9).set_trans(Tween.TRANS_SINE)
			lift.tween_property(stones, "position:y", h * 0.2, 1.9).set_trans(Tween.TRANS_SINE)
			_motes(relics, "Leaves", 2, "leaf", DIVINE.lerp(look.hot, 0.5), 10 if p_tier >= 2 else 7, 0.3, 0.7, h * 1.2, h * 0.65)


## Light shed where the god-form pet walks (world-space particles: a trail), the one
## emitter it has, asking VfxBudget.
static func _trail(root: Node3D, color: Color, h: float) -> void:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22) * h
	quad.material = _mat("trail", Color.WHITE, 1.0, VfxKit.soft_dot(), true, false, false, true)
	p.mesh = quad
	p.lifetime = 1.1
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = h * 0.35
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.15, Color(color, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(color.lerp(Color.WHITE, 0.4), 0.0))
	p.color_ramp = ramp
	p.position = Vector3(0, h * 0.4, 0)
	root.add_child(p)
	VfxBudget.track_particles(p, 16)


# ---------------------------------------------------------------------------
# Everyone else's pets
# ---------------------------------------------------------------------------

## The cheap form look of another player's pet (PetFollower, a lite Pet): the wider
## ring from the full-grown form, a gold ring from ★200, a small gold halo over the god
## form, and the rim tint from ★100. Shared meshes and materials only, no motion.
## Returns the holder (child "PetFormLite" of [param holder]) or null.
static func dress_lite(holder: Node3D, visual: MonsterVisual, id: String, stage: int, height: float, hide_past := 0.0) -> Node3D:
	set_rim(visual, id, stage)
	if stage < 2:
		return null
	var root := Node3D.new()
	root.name = "PetFormLite"
	holder.add_child(root)
	var aura := Pet.ring_for(id)
	aura.name = "PetAura"
	# Sized to the body (a walking follower is smaller than a fighting pet).
	var fit := clampf(height / 1.5, 0.6, 1.2)
	aura.scale = Vector3(1.4 * fit, 0.1, 1.4 * fit)
	root.add_child(aura)
	var look: Dictionary = LOOK.get(id, LOOK.fire)
	if stage >= 4:
		_mi(root, "Ring2", EnhanceFx._thin_torus(), _mat("ring", look.gold, 0.8), Vector3(0, 0.06, 0), Vector3(height * 1.2, 0.6, height * 1.2))
	if stage >= PetData.GOD_STAGE:
		var halo := _mi(root, "GodHalo", VfxKit.torus_mesh(0.34, 0.42, 16, 6), _mat("halo", DIVINE, 0.95), Vector3(0, height * 1.12, 0), Vector3.ONE * fit)
		halo.rotation.x = deg_to_rad(18.0)
	if hide_past > 0.0:
		for mi in root.find_children("*", "GeometryInstance3D", true, false):
			(mi as GeometryInstance3D).visibility_range_end = hide_past
	return root


# ---------------------------------------------------------------------------
# The rim of light on the model
# ---------------------------------------------------------------------------

## Puts the form's rim light on [param visual]'s model (from ★100; one shared material
## per element and form), or takes it off below.
static func set_rim(visual: MonsterVisual, id: String, stage: int) -> void:
	if visual == null or visual.model == null:
		return
	var mat: Material = rim_material(id, stage) if stage >= PetData.STAR_STAGE else null
	for mi in visual._flash_targets():
		if not is_instance_valid(mi):
			continue
		var m := mi as MeshInstance3D
		if mat != null or (m.material_overlay is ShaderMaterial and (m.material_overlay as ShaderMaterial).shader == RIM_SHADER):
			m.material_overlay = mat


static func rim_material(id: String, stage: int) -> ShaderMaterial:
	var key := "rim|%s|%d" % [id, stage]
	if _mats.has(key):
		return _mats[key]
	var look: Dictionary = LOOK.get(id, LOOK.fire)
	var step := clampi(stage - PetData.STAR_STAGE, 0, 2)
	var m := ShaderMaterial.new()
	m.shader = RIM_SHADER
	var lit := float(LIGHT.get(id, 1.0))
	m.set_shader_parameter("color", look.deep if id == "water" else look.hot)
	m.set_shader_parameter("gold", Color(DIVINE, [0.0, 0.2, 0.45][step] * lit))
	m.set_shader_parameter("rim", [0.6, 0.75, 0.9][step] * lit)
	m.set_shader_parameter("base", [0.03, 0.04, 0.06][step] * lit)
	m.set_shader_parameter("pulse", 0.25)
	_mats[key] = m
	return m


# ---------------------------------------------------------------------------
# Growing into a form while playing
# ---------------------------------------------------------------------------

## The burst when [param pet] grows into [param stage] in front of its hero: a flash
## and a ring for the level forms; for the star forms a pillar of light, two rings, a
## burst of stars and a flash of the screen, grander each form. Says the Thai line.
static func announce(pet: Node3D, id: String, stage: int, top: float) -> void:
	var parent := pet.get_parent() as Node3D
	if parent == null:
		return
	var data := PetData.get_pet(id)
	var glow: Color = data.get("glow", Color.WHITE)
	var at := pet.global_position
	var k := top / maxf(float(data.get("height", 1.5)), 0.1)
	VfxKit.flash(parent, at + Vector3.UP * top * 0.5, glow, 2.2 * k, 0.45)
	VfxKit.shockwave(parent, at + Vector3(0, 0.15, 0), glow, 3.0 * k)
	if stage >= PetData.STAR_STAGE:
		var step := stage - PetData.STAR_STAGE
		var look: Dictionary = LOOK.get(id, LOOK.fire)
		VfxKit.pillar(parent, at, glow, 9.0 + 2.5 * step, 1.3 + 0.35 * step, 1.3, Color.WHITE)
		VfxKit.shockwave(parent, at + Vector3(0, 0.2, 0), look.gold, 4.5 + 1.5 * step)
		VfxKit.star_burst(parent, at + Vector3.UP * top * 0.6, look.hot, 2.4 + 0.6 * step)
		VfxArt.motes(parent, at + Vector3(0, top * 0.5, 0), (look.gold as Color), "star", 14 + 6 * step, 1.4, 2.2, 1.3)
		if stage >= PetData.GOD_STAGE:
			VfxKit.level_up(parent, at)
		Game.screen_flash.emit((glow as Color).lerp(DIVINE, 0.4), 0.22 + 0.08 * float(step))
	Game.say(PetData.growth_line(id, stage), &"success")


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------

static func _unit_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


## A shared additive material: [param billboard] faces the camera (keeping its node's
## scale), [param vertex] tints by the mesh's vertex colours, [param flat] draws both sides.
static func _mat(key: String, color: Color, alpha: float, tex: Texture2D = null, billboard := false, vertex := false, flat := false, particles := false) -> StandardMaterial3D:
	var k := "%s|%s|%.2f|%s" % [key, color.to_html(), alpha, str(tex.get_instance_id()) if tex else ""]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.disable_fog = true
	if tex:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if particles else BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	if vertex or particles:
		m.vertex_color_use_as_albedo = true
	if vertex or flat:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	MaterialKeeper.keep(m)
	_mats[k] = m
	return m


static func _stone_mat() -> StandardMaterial3D:
	if not _mats.has("stone"):
		var m := MeshKit.toon(Color.WHITE, {"rim": true}).duplicate() as StandardMaterial3D
		m.vertex_color_use_as_albedo = true
		_mats["stone"] = m
	return _mats["stone"]


static func _mi(parent: Node3D, mi_name: String, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mi_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _spin(node: Node3D, period: float) -> void:
	var start := node.rotation.y
	var spin := node.create_tween().set_loops()
	spin.tween_property(node, "rotation:y", start + TAU * signf(period), absf(period)).from(start)


## Turns a flat (x-tilted) piece about the world up axis through a holder.
static func _spin_holder(parent: Node3D, piece: Node3D, period: float) -> void:
	var holder := Node3D.new()
	holder.name = String(piece.name)
	holder.position = piece.position
	piece.name = "Disc"
	piece.position = Vector3.ZERO
	parent.remove_child(piece)
	parent.add_child(holder)
	holder.add_child(piece)
	_spin(holder, period)


static func _breathe(node: Node3D, up: float, down: float, period: float) -> void:
	var base := node.scale
	var tween := node.create_tween().set_loops()
	tween.tween_property(node, "scale", base * up, period).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "scale", base * down, period).set_trans(Tween.TRANS_SINE)


## Shader motes (SummonAura's: one mesh, one draw, looped on the GPU) of [param count]
## cards around a body [param body] tall and [param radius] wide.
static func _motes(root: Node3D, mi_name: String, mode: int, texture: String, color: Color, count: int, size: float, speed: float, body: float, radius: float) -> void:
	var n := clampi(VfxBudget.count(count, 4), 4, 24)
	var key := "motes|%s|%d|%s|%s|%.2f|%.2f|%.2f|%.2f" % [mi_name, mode, texture, color.to_html(), size, speed, body, radius]
	var mat: ShaderMaterial = _mats.get(key)
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SummonAura.SHADER
		mat.set_shader_parameter("color", Color(color.r, color.g, color.b, 0.95))
		mat.set_shader_parameter("tex", VfxArt.texture(texture))
		mat.set_shader_parameter("mode", mode)
		mat.set_shader_parameter("body_height", body)
		mat.set_shader_parameter("body_radius", radius)
		mat.set_shader_parameter("base_height", 0.0)
		mat.set_shader_parameter("size", size)
		mat.set_shader_parameter("speed", speed)
		_mats[key] = mat
	var mi := MeshInstance3D.new()
	mi.name = mi_name
	mi.mesh = ShaderBurst._mesh(n)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := body * 1.6 + radius * 2.0 + 1.0
	mi.custom_aabb = AABB(Vector3(-reach, -1.0, -reach), Vector3(reach * 2.0, reach * 2.0 + body, reach * 2.0))
	root.add_child(mi)


# ---------------------------------------------------------------------------
# Baked meshes (built once per element, shared by every pet and rebuild)
# ---------------------------------------------------------------------------

static func _cone_part(segments := 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = segments
	m.rings = 1
	m.cap_bottom = false
	return m


static func _sphere_part() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	return m


## Appends [param mesh] (surface 0) into [param st] at [param xf], painted [param color].
static func _append(st: SurfaceTool, mesh: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var order: PackedInt32Array = index
	if order.is_empty():
		order = PackedInt32Array(range(verts.size()))
	for i in order:
		st.set_color(color)
		if i < normals.size():
			st.set_normal((xf.basis * normals[i]).normalized())
		if i < uvs.size():
			st.set_uv(uvs[i])
		st.add_vertex(xf * verts[i])


static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## A crown of radius 1 (scaled to the pet by its node), sitting on y = 0.
static func _crown_mesh(id: String) -> Mesh:
	var key := "crown|" + id
	if _meshes.has(key):
		return _meshes[key]
	var look: Dictionary = LOOK.get(id, LOOK.fire)
	var st := _begin()
	var cone := _cone_part()
	var band := TorusMesh.new()
	band.inner_radius = 0.9
	band.outer_radius = 1.0
	band.rings = 24
	band.ring_segments = 4
	match id:
		"water":
			# An ice crown: a band and six crystal spikes, tall and short.
			_append(st, band, Transform3D(Basis.from_scale(Vector3(1, 0.8, 1)), Vector3.ZERO), look.hot)
			for k in 6:
				var a := TAU * float(k) / 6.0
				var tall := 1.5 if k % 2 == 0 else 0.95
				var at := Vector3(cos(a), 0.0, sin(a)) * 0.92
				var lean := Basis(Vector3(-sin(a), 0, cos(a)), -0.18)
				_append(st, cone, Transform3D(lean * Basis.from_scale(Vector3(0.36, tall, 0.36)), at + Vector3(0, tall * 0.5, 0)), Color("6cc0f4"))
				_append(st, cone, Transform3D(lean * Basis.from_scale(Vector3(0.36, -0.3, 0.36)), at - Vector3(0, 0.12, 0)), look.deep)
		"earth":
			# The druid wears antlers of its own: a wreath of light leaves between them, a
			# gold band with gold points standing up among the leaves.
			_append(st, band, Transform3D(Basis.from_scale(Vector3(1, 0.7, 1)), Vector3.ZERO), look.gold)
			var leaf := _sphere_part()
			for k in 9:
				var a := TAU * float(k) / 9.0
				var at := Vector3(cos(a), 0.0, sin(a)) * 0.95
				var out := Basis(Vector3(-sin(a), 0, cos(a)), -0.35)
				_append(st, leaf, Transform3D(out * Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(0.18, 1.0, 0.42)), at + out * Vector3(0, 0.45, 0)), (look.deep as Color).lerp(look.hot, 0.35 + 0.3 * float(k % 2)))
				_append(st, cone, Transform3D(out * Basis.from_scale(Vector3(0.18, 1.3, 0.18)), at * 1.04 + out * Vector3(0, 0.6, 0)), look.gold)
		_:
			# A crown of flames: a gold band and seven flame points, tall and short.
			_append(st, band, Transform3D(Basis.from_scale(Vector3(1, 0.8, 1)), Vector3.ZERO), look.gold)
			for k in 7:
				var a := TAU * float(k) / 7.0
				var tall := 1.4 if k % 2 == 0 else 0.85
				var at := Vector3(cos(a), 0.0, sin(a)) * 0.95
				var lean := Basis(Vector3(-sin(a), 0, cos(a)), -0.2)
				_append(st, cone, Transform3D(lean * Basis.from_scale(Vector3(0.4, tall, 0.4)), at + Vector3(0, tall * 0.5, 0)), look.gold if k % 2 == 0 else look.deep)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## One wing (side -1 left, +1 right) of feathers fanned from its root, 1 unit long: the
## element's texture on each feather; the god form adds an inner fan of gold feathers.
## Earth's is a mantle of leaves draping down the back instead.
static func _wing_mesh(id: String, side: float, god: bool) -> Mesh:
	var key := "wing|%s|%d|%s" % [id, int(side), str(god)]
	if _meshes.has(key):
		return _meshes[key]
	var look: Dictionary = LOOK.get(id, LOOK.fire)
	var st := _begin()
	var mantle := id == "earth"
	var feathers := 7
	for layer in (2 if god else 1):
		var inner := layer == 1
		for k in feathers:
			var t := float(k) / float(feathers - 1)
			var ang := deg_to_rad(lerpf(10.0, 105.0, t) if mantle else lerpf(-58.0, 30.0, t))
			var length := (1.0 - 0.07 * float(k)) * (0.62 if inner else 1.0)
			var width := (0.32 if mantle else 0.24) * (0.8 if inner else 1.0)
			var dir := Vector3(cos(ang) * side * (0.55 if mantle else 1.0), -sin(ang), -0.3 if mantle else -0.22).normalized()
			var across := dir.cross(Vector3(0, 0, 1)).normalized() * width * 0.5
			var color: Color
			if inner:
				color = DIVINE.darkened(0.2)
			else:
				color = (look.deep as Color).lerp(look.hot, 0.15 + 0.45 * sin(t * PI)) if not mantle else (look.deep as Color).lerp(look.gold, t * 0.6)
			var base := dir * 0.04 + Vector3(0, 0, 0.01 if inner else 0.0)
			var tip := dir * length
			var quad := [base - across, base + across, tip + across, tip - across]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(color)
				st.set_normal(Vector3(0, 0, -1))
				st.set_uv(uv[i])
				st.add_vertex(quad[i])
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Two thin gold rings of radius 1 crossing, with a gem riding each (the god form's
## orbit rings; the node turns them).
static func _orbit_mesh() -> Mesh:
	if _meshes.has("orbit"):
		return _meshes["orbit"]
	var st := _begin()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.0
	ring.rings = 40
	ring.ring_segments = 4
	_append(st, ring, Transform3D.IDENTITY, DIVINE)
	var gem := _sphere_part()
	_append(st, gem, Transform3D(Basis.from_scale(Vector3.ONE * 0.09), Vector3(0.985, 0, 0)), Color.WHITE)
	_append(st, gem, Transform3D(Basis.from_scale(Vector3.ONE * 0.06), Vector3(-0.985, 0, 0)), DIVINE)
	var mesh := st.commit()
	_meshes["orbit"] = mesh
	return mesh


## Six rune cards standing in a ring of radius 0.75 (the rune texture on both faces).
static func _runes_mesh() -> Mesh:
	if _meshes.has("runes"):
		return _meshes["runes"]
	var st := _begin()
	for k in 6:
		var a := TAU * float(k) / 6.0
		var at := Vector3(cos(a), 0.0, sin(a)) * 0.78
		var across := Vector3(-sin(a), 0.0, cos(a)) * 0.11
		var up := Vector3(0, 0.22, 0)
		var quad := [at - across - up * 0.5, at + across - up * 0.5, at + across + up * 0.5, at - across + up * 0.5]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3(cos(a), 0, sin(a)))
			st.set_uv(uv[i])
			st.add_vertex(quad[i])
	var mesh := st.commit()
	_meshes["runes"] = mesh
	return mesh


## Five ice crystals floating in a ring of radius 0.7 (water's god relics).
static func _shards_mesh() -> Mesh:
	if _meshes.has("shards"):
		return _meshes["shards"]
	var st := _begin()
	var cone := _cone_part(4)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var at := Vector3(cos(a) * 0.72, 0.12 * sin(a * 3.0), sin(a) * 0.72)
		var tilt := Basis(Vector3(cos(a), 0, sin(a)), 0.3)
		var s := 0.16 + 0.04 * float(k % 2)
		_append(st, cone, Transform3D(tilt * Basis.from_scale(Vector3(s * 0.8, s * 1.8, s * 0.8)), at + tilt * Vector3(0, s * 0.9, 0)), Color("5cb0f0"))
		_append(st, cone, Transform3D(tilt * Basis.from_scale(Vector3(s * 0.8, -s * 1.0, s * 0.8)), at - tilt * Vector3(0, s * 0.5, 0)), Color("2f7fe0"))
	var mesh := st.commit()
	_meshes["shards"] = mesh
	return mesh


## Six floating stones with gold veins in a ring of radius 0.8 (earth's god relics).
static func _stones_mesh() -> Mesh:
	if _meshes.has("stones"):
		return _meshes["stones"]
	var st := _begin()
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.2
		var s := 0.07 + 0.03 * float(k % 3)
		var at := Vector3(cos(a) * 0.82, 0.18 * sin(a * 2.0), sin(a) * 0.82)
		var shape := Basis(Vector3(1, 1, 0).normalized(), 0.6 * float(k)) * Basis.from_scale(Vector3(s * 1.2, s * 0.85, s))
		_append(st, rock, Transform3D(shape, at), Color("9a8466") if k % 2 == 0 else Color("b8a070"))
	var mesh := st.commit()
	_meshes["stones"] = mesh
	return mesh
