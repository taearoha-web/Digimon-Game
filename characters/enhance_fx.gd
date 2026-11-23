class_name EnhanceFx
extends RefCounted
## How enhanced (+N, up to ItemData.MAX_PLUS = 15) gear looks. Nothing shows below +7.
## Every outfit piece (armour, helm, boots) glows by its own + in its OWN colour (the
## armour: its outfit's cloth colour; the others sampled from their meshes, piece_color):
##   +7 / +8   เรืองแสงจาง   a faint glow (a soft rim and veil over the piece, breathing)
##   +9        เรืองแสง      the glow clearer
##   +10 up    เรืองแสงชัด   clearer still
## The body effects come only from the whole set: the lowest + among the weapon, armour,
## helm and boots (set_plus; wings are not counted), in the armour's colour:
##   +10 ดวงวิญญาณ   three soft orbs drifting slowly round the body, head to feet
##   +11 อัสนีจาง     the orbs and a few thin lightning sparks
##   +12 อัสนีพันสาย  many sparks, clearer
##   +13 อัสนีคู่สี    the sparks in the outfit's colour and its complementary colour
##   +14 อัสนีขีดสุด   brighter, denser, forking
##   +15 ออร่าเทพ     all that, and light in the outfit's colour shining out of the hero, in
##                   one of three looks (GOD_STYLE, GOD_STYLE_NAMES): A the body radiating
##                   god-light, B a column of heaven's light, C an anime flame aura
## The weapon's own look (+7 glow up to the +15 ring round the hand) is EnhanceWeaponFx's.
## Everything here is a shared mesh with a pooled shader material animated from TIME
## (shaders/enhance_*.gdshader): no particles, tweens or per-frame scripts.

const GLOW_SHADER := preload("res://shaders/enhance_glow.gdshader")
const BOLT_SHADER := preload("res://shaders/enhance_bolt.gdshader")
const ORB_SHADER := preload("res://shaders/enhance_orb.gdshader")
## The +15 looks (GOD_STYLE 0, 1, 2).
const GOD_SHADERS: Array[Shader] = [preload("res://shaders/enhance_god_light.gdshader"),
	preload("res://shaders/enhance_god_pillar.gdshader"), preload("res://shaders/enhance_god_flame.gdshader")]
const GOD_STYLE_NAMES: Array[String] = ["แสงเทพเจิดจ้า", "เสาแสงสวรรค์", "เปลวออร่าพลัง"]
## Which +15 look every hero wears: 0 A แสงเทพเจิดจ้า (the body radiates: a white-hot
## glow hugging the outline, rays streaming out past it, twinkling stars, a fresnel rim),
## 1 B เสาแสงสวรรค์ (a column of light from the ground into the sky, a ring at the feet,
## motes and petals spiralling up), 2 C เปลวออร่าพลัง (a big crisp toon flame aura, sparks
## shooting up, a glow on the ground).
static var GOD_STYLE := 0

## The + of each look step (step 1 = +7 ... step 8 = +15); +8 looks like +7.
const AURA_STEPS: Array[int] = [7, 9, 10, 11, 12, 13, 14, 15]
## The set's look at each step (index = aura_step).
const AURA_NAMES: Array[String] = ["", "เรืองแสงจาง", "เรืองแสง", "ดวงวิญญาณ", "อัสนีจาง", "อัสนีพันสาย", "อัสนีคู่สี", "อัสนีขีดสุด", "ออร่าเทพ"]
## A weapon's own look at each step (EnhanceWeaponFx draws it).
const WEAPON_NAMES: Array[String] = ["", "เรืองแสงจาง", "เรืองแสง", "ประกายไฟฟ้า", "ไฟฟ้าแล่น", "สายฟ้าถี่", "สายฟ้าพันคม", "สายฟ้าขีดสุด", "วงอัสนีรอบหัตถ์"]
## An outfit piece's own look (armour, helm, boots): its glow, steps 1-3 and up.
const PIECE_NAMES: Array[String] = ["", "เรืองแสงจาง", "เรืองแสง", "เรืองแสงชัด"]
## Accent colours of the steps (UI: the forge flash, stall badges).
const AURA_COLORS: Array[Color] = [Color("9fb4c8"), Color("bfe4ff"), Color("8fd8ff"), Color("ffd36a"), Color("9ad0ff"),
	Color("7fe8ff"), Color("c79bff"), Color("e8c4ff"), Color("ffe08a")]
## The first + that glows, and the set's first + with body effects.
const GLOW_FROM := 7
const BODY_FROM := 10
## The pieces whose lowest + gives the body effects.
const SET_SLOTS: Array[String] = ["weapon", "armor", "helm", "boots"]
## The wing flair's colours at +10 .. +15 (unchanged from before the outfit looks).
const WING_COLORS: Array[Color] = [Color("ff4a28"), Color("a855ff"), Color("fff0c0"), Color("8a7dff"), Color("2affa0"), Color("ffe08a")]


## How far up the look steps a + is: 0 below +7, then 1 (+7) .. 8 (+15).
static func grade(plus: int) -> int:
	return aura_step(plus)


## The look step of a +: 0 below +7, then 1 (+7, +8), 2 (+9), 3 (+10) .. 8 (+15).
static func aura_step(plus: int) -> int:
	var step := 0
	for k in AURA_STEPS.size():
		if plus >= AURA_STEPS[k]:
			step = k + 1
	return step


## The step's accent colour (UI); transparent at +0.
static func color_of(plus: int) -> Color:
	return AURA_COLORS[aura_step(plus)] if plus > 0 else Color(0, 0, 0, 0)


## The look's name at +plus: a weapon's, an outfit piece's or wings' own look by [param slot],
## the whole set's look with no slot. "" below +7.
static func look_name(plus: int, slot := "") -> String:
	var step := aura_step(plus)
	if step == 0:
		return ""
	match slot:
		"":
			return AURA_NAMES[step]
		"weapon":
			return WEAPON_NAMES[step]
		"wings":
			return "ปีกแสงขนนกร่วง" if plus >= 10 else PIECE_NAMES[step]
	return PIECE_NAMES[mini(step, PIECE_NAMES.size() - 1)]


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


# --- Colours --------------------------------------------------------------------------

## A colour made to glow: its hue, saturated enough to read, at full brightness.
static func glow_tone(c: Color) -> Color:
	if c.s < 0.12:
		# Grey, white or silver: a cool silver light.
		return Color(0.8, 0.9, 1.0)
	return Color.from_hsv(c.h, clampf(c.s * 1.1, 0.45, 0.88), 1.0)


## The complementary glow of [param c] (the +13 sparks' second colour).
static func contrast_of(c: Color) -> Color:
	var g := glow_tone(c)
	if g.s < 0.3:
		return Color("ffc860")
	return Color.from_hsv(fmod(g.h + 0.5, 1.0), maxf(g.s, 0.6), 1.0)


static var _hist_cache := {}
static var _tex_cache := {}
const _BINS := 12


## The main colour of a worn piece, read from its own meshes (material colours, vertex
## colours, emission), made to glow (glow_tone). The weights favour saturated colour and
## a piece's glowing trims over plain dark or grey parts; a grey piece glows silver.
static func piece_color(nodes: Array) -> Color:
	var bins: Array = []
	for b in _BINS + 1:
		bins.append(Vector4.ZERO)
	for node in nodes:
		if not (node is Node) or not is_instance_valid(node):
			continue
		for m in MeshKit.collect_meshes(node):
			if m.mesh == null or m.has_meta("enhance_fx"):
				continue
			for i in m.mesh.get_surface_count():
				_add_surface(bins, m, i)
	var best := -1
	var best_w := 0.0
	for b in _BINS:
		var w: float = bins[b].w + 0.5 * (bins[(b + 1) % _BINS].w + bins[(b + _BINS - 1) % _BINS].w)
		if w > best_w:
			best_w = w
			best = b
	if best < 0 or best_w < bins[_BINS].w * 0.5:
		return Color(0.8, 0.9, 1.0)
	var sum := Vector4.ZERO
	for b in [(best + _BINS - 1) % _BINS, best, (best + 1) % _BINS]:
		sum += bins[b] * (1.0 if b == best else 0.5)
	return glow_tone(Color(sum.x / sum.w, sum.y / sum.w, sum.z / sum.w))


static func _add_color(bins: Array, c: Color, weight: float) -> void:
	if c.v < 0.12 or weight <= 0.0:
		return
	var w := weight * (0.2 + c.s * c.v)
	var b := _BINS if c.s < 0.18 else int(c.h * _BINS) % _BINS
	bins[b] += Vector4(c.r * w, c.g * w, c.b * w, w)


static func _add_surface(bins: Array, m: MeshInstance3D, i: int) -> void:
	var mat := m.get_active_material(i)
	# Weight: the piece's size (its box's area, as scaled), shared among its surfaces by
	# their vertex counts.
	var box := m.mesh.get_aabb()
	var sc := m.transform.basis.get_scale()
	var size := box.size * sc
	var area := 2.0 * (size.x * size.y + size.y * size.z + size.x * size.z)
	var share := 1.0 / float(m.mesh.get_surface_count())
	if m.mesh is ArrayMesh and m.mesh.get_surface_count() > 1:
		var total := 0
		for k in m.mesh.get_surface_count():
			total += (m.mesh as ArrayMesh).surface_get_array_len(k)
		share = float((m.mesh as ArrayMesh).surface_get_array_len(i)) / float(maxi(total, 1))
	var weight := sqrt(maxf(area, 0.0001)) * share
	if mat is StandardMaterial3D:
		var std := mat as StandardMaterial3D
		if std.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
			return
		var base := std.albedo_color
		if std.albedo_texture != null:
			var avg := _texture_color(std.albedo_texture)
			base = Color(base.r * avg.r, base.g * avg.g, base.b * avg.b)
		if std.vertex_color_use_as_albedo:
			_add_vertex_colors(bins, m.mesh, i, base, weight)
		else:
			_add_color(bins, base, weight)
		if std.emission_enabled:
			_add_color(bins, std.emission, weight * 1.5)
	elif mat is ShaderMaterial:
		for key in ["outfit_color", "albedo", "albedo_color", "color", "base_color", "tint", "body"]:
			var v: Variant = (mat as ShaderMaterial).get_shader_parameter(key)
			if v is Color:
				_add_color(bins, v, weight)
				return


## Vertex colours of one surface, as a small hue histogram cached per mesh.
static func _add_vertex_colors(bins: Array, mesh: Mesh, i: int, tint: Color, weight: float) -> void:
	var key := "%d:%d" % [mesh.get_instance_id(), i]
	var local: Array = _hist_cache.get(key, [])
	if local.is_empty():
		for b in _BINS + 1:
			local.append(Vector4.ZERO)
		var colors: PackedColorArray = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR] if mesh is ArrayMesh or mesh is PrimitiveMesh else PackedColorArray()
		if colors.is_empty():
			_add_color(local, Color.WHITE, 1.0)
		else:
			var stride := maxi(1, colors.size() / 300)
			var n := 0
			for k in range(0, colors.size(), stride):
				n += 1
			for k in range(0, colors.size(), stride):
				_add_color(local, colors[k], 1.0 / float(n))
		if _hist_cache.size() > 512:
			_hist_cache.clear()
		_hist_cache[key] = local
	for b in local.size():
		var v: Vector4 = local[b]
		bins[b] += Vector4(v.x * tint.r, v.y * tint.g, v.z * tint.b, v.w) * weight


## The average colour of a texture (once per texture).
static func _texture_color(tex: Texture2D) -> Color:
	var key := tex.get_instance_id()
	if _tex_cache.has(key):
		return _tex_cache[key]
	var c := Color.WHITE
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		if not img.is_compressed():
			img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
			var sum := Color(0, 0, 0)
			for y in 8:
				for x in 8:
					sum += img.get_pixel(x, y)
			c = Color(sum.r / 64.0, sum.g / 64.0, sum.b / 64.0)
	_tex_cache[key] = c
	return c


# --- Pooled materials -----------------------------------------------------------------

static var _pool := {}
const POOL_LIMIT := 256


static func _quant(c: Color) -> Color:
	return Color(roundf(c.r * 15.0) / 15.0, roundf(c.g * 15.0) / 15.0, roundf(c.b * 15.0) / 15.0)


## A pooled shader material: one per shader and parameter set, shared by every hero
## wearing that look (they only differ by TIME, so nothing per hero is needed).
static func _shared(shader: Shader, params: Dictionary) -> ShaderMaterial:
	var key := "%s|%s" % [shader.resource_path.get_file(), str(params)]
	var mat: ShaderMaterial = _pool.get(key)
	if mat != null:
		return mat
	if _pool.size() >= POOL_LIMIT:
		# Materials still worn stay alive with their meshes; the pool just forgets them.
		_pool.clear()
	mat = ShaderMaterial.new()
	mat.shader = shader
	for p in params:
		mat.set_shader_parameter(p, params[p])
	_pool[key] = mat
	return mat


## How strongly a piece glows at +plus: 0 below +7, +7/+8 faint, +9 clearer, +10 and up
## clearer still (a little more each step to +15).
static func glow_strength(plus: int) -> float:
	if plus < GLOW_FROM:
		return 0.0
	if plus < 9:
		return 0.4
	if plus < 10:
		return 0.7
	if plus >= 15:
		return 1.1
	return minf(0.8 + 0.025 * float(plus - 10), 0.95)


## The overlay glow of a piece in [param color] at +plus (pooled, shared by every piece of
## that colour and step): shaders/enhance_glow.gdshader.
static func glow_material(color: Color, plus: int) -> ShaderMaterial:
	var c := _quant(glow_tone(color))
	var s := glow_strength(plus)
	return _shared(GLOW_SHADER, {"color": c, "strength": s, "phase": fmod(c.h * 17.0, TAU)})


# --- The weapon -------------------------------------------------------------------------

## The look of a held weapon (or shield) at +plus: EnhanceWeaponFx (nothing below +7,
## a glow in the weapon's own colour at +7/+9, electric arcs from +10, a ring of arcs
## round the hand at +15). [param light] is the crowd's cheap dressing (HeroVisual.decor_light).
static func on_item(item: Node3D, plus: int, light := false) -> void:
	EnhanceWeaponFx.apply(item, plus, light)


# --- The outfit pieces -----------------------------------------------------------------

## Slots that cannot be enhanced (they stay as they are).
const FIXED_SLOTS: Array[String] = ["ring", "amulet"]


static func can_enhance(item: Dictionary) -> bool:
	return item.get("kind", "") == "equip" and not (String(item.get("slot", "")) in FIXED_SLOTS)


## An enhanced piece glows by its own + from +7 in its own colour: an overlay on its own
## meshes (glow_material). [param color]: the piece's colour (the armour passes its
## cloth); transparent = read from its meshes (piece_color). Returns the colour used, or
## a transparent colour when nothing glows. The overlays go with the meshes (a re-dress
## frees them); nothing else is made. [param light] (the crowd) wears the same glow:
## one more draw of the piece, no particles.
static func glow_piece(_owner: Node3D, nodes: Array, plus: int, _spot := Vector3.ZERO, _spread := 0.3, _light := false, color := Color(0, 0, 0, 0)) -> Color:
	if plus < GLOW_FROM:
		return Color(0, 0, 0, 0)
	var live: Array = nodes.filter(func(n): return n is Node and is_instance_valid(n))
	if live.is_empty():
		return Color(0, 0, 0, 0)
	var tone := glow_tone(color) if color.a > 0.0 else piece_color(live)
	var overlay := glow_material(tone, plus)
	var found := false
	for node in live:
		for m in MeshKit.collect_meshes(node):
			if m.has_meta("enhance_fx"):
				continue
			m.material_overlay = overlay
			found = true
	return tone if found else Color(0, 0, 0, 0)


## The armour's glow over the chibi's dyed outfit (shaders/chibi_outfit.gdshader).
static func glow_outfit(mat: ShaderMaterial, color: Color, plus: int) -> void:
	mat.set_shader_parameter("enhance_color", glow_tone(color))
	mat.set_shader_parameter("enhance_glow", glow_strength(plus))


# --- The body effects (the whole set) --------------------------------------------------

## The set's body effects at +plus (set_plus) in [param color] (the armour's colour):
## nothing below +10, then the orbs, the sparks from +11 and the aura at +15 (see the
## header). [param light] (the other players around) or memory pressure: the orbs
## without trails, a few sparks without forks; the +15 look stays (one draw, without its
## motes, stars or front flames).
static func on_body(visual: Node3D, plus: int, light := false, color := Color(0, 0, 0, 0)) -> Array[Node]:
	var made: Array[Node] = []
	if plus < BODY_FROM:
		return made
	var root := Node3D.new()
	root.name = "SetAura"
	visual.add_child(root)
	made.append(root)
	var head := 1.85 if bool(visual.get("chibi")) else 2.2
	var rich := not light and MemoryGuard.pressure < 2
	var tone := glow_tone(color) if color.a > 0.0 else Color(0.8, 0.9, 1.0)
	_orbs(root, tone, head, rich)
	if plus >= 11:
		_body_bolts(root, tone, plus, head, rich, visual.get_instance_id())
	if plus >= 15:
		_god(root, tone, head, rich)
	return made


static func _fx_mesh(root: Node3D, node_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Effect meshes: never polished, flashed, outlined or given a shadow (HeroVisual).
	mi.set_meta("enhance_fx", true)
	mi.set_meta("no_shadow_lod", true)
	root.add_child(mi)
	return mi


## +10: three orbs drifting round the body (shaders/enhance_orb.gdshader).
static func _orbs(root: Node3D, color: Color, head: float, trail: bool) -> MeshInstance3D:
	var mat := _shared(ORB_SHADER, {"color": _quant(color), "head": head, "trail": 1.0 if trail else 0.0})
	return _fx_mesh(root, "Orbs", _orb_mesh(head, trail), mat)


## +11 to +15: lightning round the body (shaders/enhance_bolt.gdshader). More bolts,
## brighter and wider each step; +13 and up half of them in the complementary colour,
## +14 up forking.
static func _body_bolts(root: Node3D, color: Color, plus: int, head: float, rich: bool, who: int) -> MeshInstance3D:
	var k := clampi(plus, 11, 14) - 11
	var density: float = [0.45, 0.72, 0.82, 1.0][k]
	var forks: float = [0.5, 1.0, 1.0, 1.0][k]
	if not rich:
		density = minf(density, 0.25)
		forks = 0.0
	var other := _quant(contrast_of(color)) if plus >= 13 else _quant(color)
	var mat := _shared(BOLT_SHADER, {"color_a": _quant(color), "color_b": other, "density": density, "forks": forks,
		"rate": [5.0, 6.0, 6.5, 7.5][k], "duty": [0.72, 0.78, 0.8, 0.86][k], "amp": [0.04, 0.05, 0.05, 0.06][k],
		"width": [0.02, 0.026, 0.028, 0.034][k], "energy": [1.35, 1.65, 1.75, 2.15][k], "segs": float(BODY_SEGS),
		"spin": 1.0, "slide": 0.25, "seed": float(who % 4) * 0.37})
	var mi := _fx_mesh(root, "Lightning", _body_bolt_mesh(), mat)
	mi.scale = Vector3(1, head / 1.85, 1)
	return mi


## +15: light shining out of the hero in GOD_STYLE's look (shaders/enhance_god_*.gdshader):
## one shared mesh and one pooled material, one draw. [param rich] false: the cheap dress
## (no motes, petals, stars or front flames).
static func _god(root: Node3D, color: Color, head: float, rich: bool) -> MeshInstance3D:
	var style := clampi(GOD_STYLE, 0, GOD_SHADERS.size() - 1)
	var mat := _shared(GOD_SHADERS[style], {"color": _quant(color), "rich": 1.0 if rich else 0.0})
	var mesh: ArrayMesh = [_god_light_mesh, _god_pillar_mesh, _god_flame_mesh][style].call()
	var mi := _fx_mesh(root, "GodAura", mesh, mat)
	mi.scale = Vector3.ONE * (head / 1.85)
	return mi


# --- Shared meshes ----------------------------------------------------------------------

const BODY_SEGS := 10
static var _meshes := {}
static var _thin: TorusMesh


## A thin torus (radius 0.485, tube 0.03) shared by rings elsewhere (PetForm).
static func _thin_torus() -> TorusMesh:
	if _thin == null:
		_thin = TorusMesh.new()
		_thin.inner_radius = 0.47
		_thin.outer_radius = 0.5
		_thin.rings = 40
		_thin.ring_segments = 6
	return _thin


## A mesh of lightning strips for shaders/enhance_bolt.gdshader. Each strip:
## {path: PackedVector3Array (segs + 1 points), seed, bolt, pick, tier, root (-1 or t)}.
static func _strip_mesh(strips: Array, segs: int, box: AABB) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for st in strips:
		var path: PackedVector3Array = st.path
		var length := 0.0
		for k in segs:
			length += path[k].distance_to(path[k + 1])
		var first := verts.size()
		for k in segs + 1:
			var dir := (path[mini(k + 1, segs)] - path[maxi(k - 1, 0)]).normalized()
			for side in 2:
				verts.append(path[k])
				normals.append(dir)
				uvs.append(Vector2(side, float(k) / float(segs)))
				uv2s.append(Vector2(length, float(st.root)))
				colors.append(Color(st.seed, st.bolt, st.pick, st.tier))
		for k in segs:
			var a := first + k * 2
			index.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = box
	return mesh


## Thirty-two bolts hugging the body (for a chibi 1.85 tall; scaled for others), each with a
## fork, their tiers spread so the first few are spread round the body too.
static func _body_bolt_mesh() -> ArrayMesh:
	if _meshes.has("body_bolts"):
		return _meshes.body_bolts
	var rng := RandomNumberGenerator.new()
	rng.seed = 1511
	var strips := []
	var count := 32
	var segs := BODY_SEGS
	for m in count:
		var tier := (float(m) + 0.5) / float(count)
		var seed := (float(m) * 2.0 + 1.0) / 64.0
		var angle := float(m) * 2.39996
		var y0 := rng.randf_range(0.12, 1.45)
		var y1 := minf(y0 + rng.randf_range(0.35, 0.75), 1.95)
		var r := rng.randf_range(0.4, 0.55)
		var sweep := rng.randf_range(-0.9, 0.9)
		var path := PackedVector3Array()
		for k in segs + 1:
			var t := float(k) / float(segs)
			var a := angle + sweep * t
			var rr := r + 0.07 * sin(PI * t)
			path.append(Vector3(cos(a) * rr, lerpf(y0, y1, t), sin(a) * rr))
		strips.append({"path": path, "seed": seed, "bolt": seed, "pick": float(m % 2), "tier": tier, "root": -1.0})
		# Its fork: from a point on it, out and away.
		var at := rng.randi_range(3, 7)
		var start := path[at]
		var out := Vector3(start.x, 0, start.z).normalized()
		var end := start + out * rng.randf_range(0.18, 0.3) + Vector3(0, rng.randf_range(-0.25, 0.25), 0)
		var fork := PackedVector3Array()
		for k in segs + 1:
			fork.append(start.lerp(end, float(k) / float(segs)))
		strips.append({"path": fork, "seed": seed + 1.0 / 64.0, "bolt": seed, "pick": float(m % 2), "tier": tier, "root": float(at) / float(segs)})
	var mesh := _strip_mesh(strips, segs, AABB(Vector3(-1.1, -0.3, -1.1), Vector3(2.2, 2.7, 2.2)))
	_meshes["body_bolts"] = mesh
	return mesh


const ORB_TRAIL := 6


## Three orbs, each a halo, a heart and ORB_TRAIL trail motes (or none): camera-facing
## quads placed by shaders/enhance_orb.gdshader.
static func _orb_mesh(head: float, trail: bool) -> ArrayMesh:
	var key := "orbs_%d_%s" % [int(head * 100.0), trail]
	if _meshes.has(key):
		return _meshes[key]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for k in 3:
		var parts := [[0.0, 0.0], [0.5, 0.0]]
		if trail:
			for j in ORB_TRAIL:
				parts.append([1.0, float(j + 1) / float(ORB_TRAIL)])
		# Trail first, then the halo and the heart on top (drawn in mesh order).
		parts.reverse()
		for part in parts:
			var first := verts.size()
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				verts.append(Vector3.ZERO)
				uvs.append(corner)
				colors.append(Color(float(k) / 2.0, part[1], part[0], 1.0))
			index.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1.2, -0.2, -1.2), Vector3(2.4, head + 0.8, 2.4))
	_meshes[key] = mesh
	return mesh


# The +15 looks' meshes: parts tagged by kind in COLOR.r (kind / 8), a seed in COLOR.g
# and an index (0..1) in COLOR.b; a card is four corners at its centre (UV the corner,
# UV2 its size in metres) that the shader turns to the camera (shaders/enhance_god.gdshaderinc).

static func _parts() -> Dictionary:
	return {"v": [], "n": [], "uv": [], "uv2": [], "c": [], "i": []}


static func _part_card(a: Dictionary, centre: Vector3, size: Vector2, kind: int, seed := 0.0, index := 0.0) -> void:
	var first: int = a.v.size()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		a.v.append(centre)
		a.n.append(Vector3.BACK)
		a.uv.append(corner)
		a.uv2.append(size)
		a.c.append(Color(float(kind) / 8.0, seed, index, 1.0))
	a.i.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


## A flat square on the ground (UV across it, UV2 its size).
static func _part_ground(a: Dictionary, size: float, kind: int) -> void:
	var first: int = a.v.size()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		a.v.append(Vector3((corner.x - 0.5) * size, 0.03, (corner.y - 0.5) * size))
		a.n.append(Vector3.UP)
		a.uv.append(corner)
		a.uv2.append(Vector2(size, size))
		a.c.append(Color(float(kind) / 8.0, 0, 0, 1.0))
	a.i.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


## A surface of revolution: profile [[height, radius], ...], UV.x round it, UV.y up it (0..1).
static func _part_revolution(a: Dictionary, profile: Array, around: int, kind: int) -> void:
	var first: int = a.v.size()
	var rows := profile.size()
	var top: float = profile[rows - 1][0]
	for j in rows:
		var y: float = profile[j][0]
		var r: float = profile[j][1]
		var prev: Array = profile[maxi(j - 1, 0)]
		var next: Array = profile[mini(j + 1, rows - 1)]
		var flat := Vector2(next[0] - prev[0], -(next[1] - prev[1])).normalized()
		for i in around + 1:
			var ang := TAU * float(i) / float(around)
			var radial := Vector3(cos(ang), 0, sin(ang))
			a.v.append(radial * r + Vector3(0, y, 0))
			a.n.append((radial * flat.x + Vector3(0, flat.y, 0)).normalized())
			a.uv.append(Vector2(float(i) / float(around), y / top))
			a.uv2.append(Vector2.ZERO)
			a.c.append(Color(float(kind) / 8.0, 0, 0, 1.0))
	for j in rows - 1:
		for i in around:
			var p := first + j * (around + 1) + i
			var q := p + around + 1
			a.i.append_array([p, p + 1, q, p + 1, q + 1, q])


static func _parts_mesh(a: Dictionary, box: AABB) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(a.v)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(a.n)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(a.uv)
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(a.uv2)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(a.c)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(a.i)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = box
	return mesh


## A · แสงเทพเจิดจ้า: the ground pool, the light card behind the body, the rim shell
## (drawn in that order).
static func _god_light_mesh() -> ArrayMesh:
	if _meshes.has("god_light"):
		return _meshes.god_light
	var a := _parts()
	_part_ground(a, 2.4, 2)
	_part_card(a, Vector3(0, 1.05, 0), Vector2(4.6, 4.3), 0)
	_part_revolution(a, [[0.04, 0.36], [0.4, 0.39], [0.8, 0.43], [1.0, 0.5], [1.18, 0.6], [1.42, 0.65],
		[1.68, 0.6], [1.88, 0.45], [2.0, 0.25], [2.06, 0.04]], 28, 1)
	var mesh := _parts_mesh(a, AABB(Vector3(-2.6, -0.4, -2.6), Vector3(5.2, 3.8, 5.2)))
	_meshes["god_light"] = mesh
	return mesh


const PILLAR_HEIGHT := 6.5


## B · เสาแสงสวรรค์: the ring at the feet, the column, then 18 motes and 10 petals.
static func _god_pillar_mesh() -> ArrayMesh:
	if _meshes.has("god_pillar"):
		return _meshes.god_pillar
	var a := _parts()
	_part_ground(a, 2.5, 1)
	_part_revolution(a, [[0.0, 0.74], [0.6, 0.74], [1.6, 0.74], [3.2, 0.74], [PILLAR_HEIGHT, 0.74]], 32, 0)
	for k in 18:
		_part_card(a, Vector3.ZERO, Vector2.ONE * 0.22, 2, (float(k) + 0.5) / 18.0, float(k % 2) * 0.75)
	for k in 10:
		_part_card(a, Vector3.ZERO, Vector2(0.17, 0.28), 3, (float(k) + 0.31) / 10.0, float(k) / 9.0)
	var mesh := _parts_mesh(a, AABB(Vector3(-1.4, -0.2, -1.4), Vector3(2.8, PILLAR_HEIGHT + 0.5, 2.8)))
	_meshes["god_pillar"] = mesh
	return mesh


## C · เปลวออร่าพลัง: the ground glow, the flame behind the body, 15 sparks, the tongues
## in front.
static func _god_flame_mesh() -> ArrayMesh:
	if _meshes.has("god_flame"):
		return _meshes.god_flame
	var a := _parts()
	_part_ground(a, 2.4, 3)
	_part_card(a, Vector3(0, 1.45, 0), Vector2(2.8, 3.3), 0)
	for k in 15:
		_part_card(a, Vector3.ZERO, Vector2(0.07, 0.42), 2, (float(k) + 0.5) / 15.0, float(k % 3) * 0.5)
	_part_card(a, Vector3(0, 1.45, 0), Vector2(2.8, 3.3), 1)
	var mesh := _parts_mesh(a, AABB(Vector3(-2.0, -0.4, -2.0), Vector3(4.0, 3.9, 4.0)))
	_meshes["god_flame"] = mesh
	return mesh


# --- Wings ------------------------------------------------------------------------------

## Wings at +10 and up get their own flair, in their step's colour (WING_COLORS): a soft
## glow spread behind them and light feathers drifting down (+15: every colour of the
## rainbow). Returns the holder (the caller frees it with the outfit), or null below +10.
static func wing_flair(owner: Node3D, plus: int, spot: Vector3, light := false) -> Node3D:
	if plus < 10:
		return null
	var color := WING_COLORS[clampi(plus, 10, 15) - 10]
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
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


# --- Gems -------------------------------------------------------------------------------

## The colour of the first ตำนาน (size ItemData.GEM_MAX_SIZE) gem socketed in a worn
## piece, or a transparent colour when it has none.
static func legend_gem_color(item: Variant) -> Color:
	if not item is Dictionary:
		return Color(0, 0, 0, 0)
	for g in (item as Dictionary).get("gems", []):
		var id := String(g)
		if not ItemData.GEMS.has(id.get_slice("_", 0)):
			continue
		var info := ItemData.gem_info({"id": id})
		if int(info.size) >= ItemData.GEM_MAX_SIZE:
			return info.color
	return Color(0, 0, 0, 0)


## A soft sparkle of a legendary gem (a few small motes in its colour) at [param pos].
## Null at the lowest quality, under memory pressure or for [param light] visuals.
static func gem_sparkle(parent: Node3D, pos: Vector3, color: Color, light := false) -> CPUParticles3D:
	if light or GameSettings.quality == 0 or MemoryGuard.pressure >= 2:
		return null
	var p := _sparkles(parent, pos, color.lightened(0.25), 6, 0.22, 0.09, 0.3, 1.3)
	p.name = "GemSparkle"
	return p
