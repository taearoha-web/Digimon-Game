class_name RamakienArt
extends MuayThaiArt
## The Muay Thai fighter's two star skills from the รามเกียรติ์, staged like a temple mural
## come alive: a colossal spirit-giant rises out of gold-edged cloud far behind the
## fighter, upper body only, leaning over the field, while the world dims to a warm dusk
## so its light reads.
##   ★200 หนุมานแผลงฤทธิ์ (heaven_ring_cataclysm): หนุมาน, jade-white in a khon jacket of
##        gold ลาย under a ชฎายอด, rises on the fighter's far side raising the ตรีเพชร,
##        and yawns: a luminous crescent and star glints pour from his mouth into the sky
##        over the target (หาวเป็นดาวเป็นเดือน). From each star a gold trident falls and
##        stakes the ground on its beat, a ยันต์ seal, a shockwave, dust and gold cracks
##        round it; the fifth falls from the moon at the centre.
##   ★300 สิบเศียรสิบกรสะท้านสามภพ (three_realms_fist): ทศกัณฐ์, deep emerald, ten heads as
##        the khon mask stacks them, rises behind the fighter and unfurls eighteen more
##        arms in a radiant halo, armed and armleted in gold. Translucent spirit fists
##        with trails of light rain round the fighter in four waves (GOD_BEATS), each
##        denser and faster; then the last wave's fists fly up and fuse into one god
##        fist that slams down before the fighter, and gold light cracks the ground into
##        a temple-glass mosaic (กระจกสี) that spreads and fades; the struck burn.
## The giants and the tridents and fists are real sculptures (RamakienSculpt, lit by the
## RamakienSpirit shader: soft key light, gold fresnel rim, ลาย line work and the khon
## masks drawn on their surfaces); the moon, stars, embers, shafts, cloud and the glass
## are RamakienLight; the dusk is RamakienVeil. Same engine as MuayThaiArt: shared meshes
## built once (while a Muay Thai fighter's zone loads), pooled materials, the layer cap
## and the core / mid / debris tiers. Every root is tied to its cast (cast_ref): a hero
## dying or leaving mid-cast fades the set out at once. Cosmetic only: StarSkillSequence
## owns every contact, target and timing; the beats a piece lands on are the sequence's
## own (StarSkillSequence beats, GOD_BEATS).

const SPIRIT := preload("res://shaders/ramakien_spirit.gdshader")
const LIGHT := preload("res://shaders/ramakien_light.gdshader")
const VEIL := preload("res://shaders/ramakien_veil.gdshader")
const HANUMAN_ID := "heaven_ring_cataclysm"
const THOTSAKAN_ID := "three_realms_fist"
const HANUMAN_BEATS := [0.0, 0.32, 0.64, 0.96, 1.36]
## The sculptures and cards this art builds itself (RamakienSculpt), cheapest first.
const OWN := ["quad", "shaft", "trail", "bank", "disc", "embers", "veil", "trident", "spirit_fist", "hanuman", "thotsakan", "thotsakan_arms"]
## The model height of a giant's chest line, which is set on the screen (the bust above it).
const CHEST := 0.25
## Painted ramps (MuayPaint) for the seals and script: gold leaf, red.
const LEAF := [Color("e39a12"), Color("fff0a4"), Color("5a2104")]
const RED := [Color("d1222c"), Color("ff9468"), Color("3a0410")]
const MOON := [Color("ffd66a"), Color("fffbea"), Color("6a3a08")]
## The spirits (RamakienSpirit): หนุมาน jade-white, ทศกัณฐ์ deep emerald, both in gold.
const HANUMAN_LOOK := {"skin": Color("e2f4ea"), "skin_dark": Color("4f8c98"), "rim": Color("ffcf72"), "gold": Color("f4c158"), "gold_dark": Color("6a3a0c"), "red": Color("c81e2e"), "ink": Color("1a2a46"), "lines": Color("ffd57c")}
const YAK_LOOK := {"skin": Color("1f9a63"), "skin_dark": Color("06352b"), "rim": Color("ffcd68"), "gold": Color("f2b84a"), "gold_dark": Color("5a2a06"), "red": Color("c4182a"), "ink": Color("07140e"), "lines": Color("ffcf6a")}
const FIST_LOOK := {"skin": Color("2cc489"), "skin_dark": Color("0a5a44"), "rim": Color("ffe08a"), "gold": Color("f6c055"), "gold_dark": Color("5a2a06"), "red": Color("c4182a"), "ink": Color("07140e"), "lines": Color("ffd27a")}
const TRIDENT_LOOK := {"skin": Color("ffd36a"), "skin_dark": Color("8a4a0c"), "rim": Color("fff0b0"), "gold": Color("ffc44e"), "gold_dark": Color("7a3c06"), "red": Color("d0202c"), "ink": Color("3a1a04"), "lines": Color("fff0b0")}
## Light (RamakienLight).
const L_GOLD := Color("ffaa30")
const L_WHITE := Color("fff1cc")
const L_JADE := Color("1fc28a")
const L_MOON := Color("ffcf6a")
const L_EMBER := Color("ff5a16")
const L_FLAME := Color("ffd25a")
## Draw order among the translucent pieces: the dusk first, then the aureole behind a
## giant, the giant, its arms; everything else after.
const PRI_VEIL := -100
const PRI_HALO := -4
const PRI_BODY := -3
const PRI_ARMS := -2
## Fist rain of the god skill: how many fists per wave at each depth (core / mid / debris).
const WAVE_FISTS := [[2, 2, 3, 3], [3, 4, 5, 6], [4, 5, 7, 9]]
## How long each wave's fists fall (the waves grow faster).
const WAVE_FALL := [0.3, 0.24, 0.19, 0.15]
static var _own_meshes: Dictionary = {}
## The set of the cast running now, per skill id (where the giant stands, its height,
## the sky height, the cast's frame), so the beats find it again.
static var _sets: Dictionary = {}


func _sculpture(kind: String) -> ArrayMesh:
	return figure(kind) if kind in OWN else MuayThaiArt.mesh(kind)


static func _open(parent: Node3D, at: Vector3, label: String, id: String) -> RamakienArt:
	var art := RamakienArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	_tie(art, id)
	return art


## Ties [param root] to the running cast of [param id] (MuayThaiArt.cast_ref).
static func _tie(root: Node, id: String) -> void:
	var ref: WeakRef = GodSkillArt._casts.get(id)
	var left := StarSignature._left(id) - GodSkillArt.CAST_MARGIN
	if ref == null or left <= 0.0:
		return
	if root is MuayThaiArt:
		(root as MuayThaiArt).cast_ref = ref
		(root as MuayThaiArt).cast_until = left
	elif root is StarSkillArt and (root as StarSkillArt).cast_ref == null:
		(root as StarSkillArt).cast_ref = ref
		(root as StarSkillArt).cast_until = (root as StarSkillArt).age + left


# ---------------------------------------------------------------------------
# Layers in the Ramakien shaders (every uniform given: pooled materials keep old values)
# ---------------------------------------------------------------------------

static func _spirit(look: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var p := {"detail": 1.0 if VfxBudget.quality() > 0 else 0.0, "manifest": 0.0, "mist_lo": -10.0, "mist_hi": -9.0, "yawn_at": -10.0, "yawn_len": 1.0, "front_world": Vector3.ZERO, "front_push": 0.0, "lai_scale": 46.0, "rim_power": 1.0, "skin_alpha": 1.0}
	p.merge(look, true)
	p.merge(extra, true)
	return p


## A sculpture (RamakienSculpt) lit as a spirit.
func _sculpt(kind: String, look: Dictionary, at: Vector3, size: Vector3, angles: Vector3, start: float, seconds: float, style: Dictionary, extra: Dictionary = {}) -> void:
	layer(kind, false, LEAF, at, size, angles, start, seconds, style.merged({"shader": SPIRIT, "params": _spirit(look, extra)}, true))


## A piece of light (RamakienLight [param mode]) on the card [param kind].
func _light(kind: String, mode: int, a: Color, b: Color, at: Vector3, size: Vector3, start: float, seconds: float, style: Dictionary, extra: Dictionary = {}, angles := Vector3.ZERO) -> void:
	var params := {"color_a": a, "color_b": b, "color_c": L_JADE, "mode": mode, "spread": 0.5, "seed": randf() * 10.0, "front_world": Vector3.ZERO, "front_push": 0.0}
	params.merge(extra, true)
	layer(kind, false, LEAF, at, size, angles, start, seconds, style.merged({"shader": LIGHT, "params": params}, true))


## The dusk while a giant is manifest: the field dims and warms, restored as it fades.
func _veil(seconds: float, strength := 0.55) -> void:
	layer("veil", false, LEAF, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, 0.0, seconds, {"shader": VEIL, "params": {"tint": Color(0.13, 0.065, 0.02), "strength": strength}, "fade_in": 0.12, "decay": 0.84, "priority": PRI_VEIL})


## A light card on a StarSkillArt contact root (its own clock and cap), pooled material.
static func _paint_light(art: StarSkillArt, kind: String, mode: int, a: Color, b: Color, at: Vector3, size: Vector3, seconds: float, style: Dictionary, priority := 0, extra: Dictionary = {}) -> void:
	if art == null:
		return
	var before := art.layers.size()
	art.add_mesh(figure(kind), "Ramakien_" + kind, {"primary": a, "accent": b, "shade": a}, at, size, Vector3.ZERO, seconds, style)
	if art.layers.size() == before:
		return
	var node: MeshInstance3D = art.layers[before].node
	var mat := _take(LIGHT)
	mat.render_priority = priority
	var params := {"color_a": a, "color_b": b, "color_c": L_JADE, "mode": mode, "spread": 0.5, "seed": randf() * 10.0, "front_world": Vector3.ZERO, "front_push": 0.0, "opacity": float(style.get("opacity", 1.0)), "fade": 0.0, "age": 0.0}
	params.merge(extra, true)
	for key: String in params:
		mat.set_shader_parameter(key, params[key])
	node.material_override = mat
	node.tree_exiting.connect(_give.bind([mat]), CONNECT_ONE_SHOT)


## A painted layer on a StarSkillArt root (the contact root a star beat opens): the
## root's own clock and cap, a pooled MuayPaint material swapped in.
static func _paint(art: StarSkillArt, kind: String, c: Array, at: Vector3, size: Vector3, seconds: float, style: Dictionary, glow: bool, priority := 0) -> void:
	if art == null:
		return
	var before := art.layers.size()
	art.add_mesh(MuayThaiArt.mesh(kind), "Ramakien_" + kind, {"primary": c[0], "accent": c[1], "shade": c[2]}, at, size, Vector3.ZERO, seconds, style)
	if art.layers.size() == before:
		return
	var node: MeshInstance3D = art.layers[before].node
	var mat := _take(PAINT)
	mat.render_priority = priority
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.95)))
	mat.set_shader_parameter("glow", 1.0 if glow else 0.0)
	mat.set_shader_parameter("fade", 0.0)
	mat.set_shader_parameter("age", 0.0)
	node.material_override = mat
	node.tree_exiting.connect(_give.bind([mat]), CONNECT_ONE_SHOT)


# ---------------------------------------------------------------------------
# The view: where "behind the fighter" is for the camera now showing the field.
# ---------------------------------------------------------------------------

static func _camera(node: Node) -> Camera3D:
	var view := node.get_viewport() if is_instance_valid(node) and node.is_inside_tree() else null
	var camera := view.get_camera_3d() if view else null
	return camera if camera and camera.projection == Camera3D.PROJECTION_PERSPECTIVE else null


## [away, right]: the flat direction from the camera through [param at] and its screen
## right; with no camera the cast's own forward ([param fallback]).
static func _view(node: Node, at: Vector3, fallback: Vector3) -> Array:
	var camera := _camera(node)
	var away := fallback * Vector3(1, 0, 1)
	if camera:
		var d := (at - camera.global_position) * Vector3(1, 0, 1)
		if d.length_squared() > 0.01:
			away = d
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.BACK
	return [away, away.cross(Vector3.UP).normalized()]


## The tallest a piece standing at [param base] may be (up to [param design]) with its
## top still inside the view; never under design * least.
static func fit_height(node: Node, base: Vector3, design: float, least := 0.5, margin := 0.05) -> float:
	var camera := _camera(node)
	if camera == null:
		return design
	var view := base - camera.global_position
	if view.length_squared() < 0.01:
		return design
	view = view.normalized()
	var up := (Vector3.UP - view * view.y).normalized()
	var top := camera.get_viewport().get_visible_rect().size.y * margin
	var ok := func(h: float) -> bool:
		var p := base + up * h
		return not camera.is_position_behind(p) and camera.unproject_position(p).y >= top
	if ok.call(design):
		return design
	var lo := 0.0
	var hi := design
	for i in 14:
		var mid := (lo + hi) * 0.5
		if ok.call(mid):
			lo = mid
		else:
			hi = mid
	return maxf(lo, design * least)


## Where a giant stands for the camera showing the field: [param behind] metres beyond the
## fighter (from the camera), upright to the view (whatever the camera's tilt, its crown
## meets the top of the screen and its chest line, model y CHEST, sits [param chest] of
## the way down; -1: just under the fighter's head), [param across] of the screen's width
## off the fighter's column, leaning [param lean] towards the field. A 3/4 camera and the
## steep behind camera (little sky) both see the bust whole, 12-18 m tall when far enough;
## the gameplay camera close behind the fighter sees it grander (up to 30 m: the crown past
## the top of the screen, the chest lower, leaning further, a shaft of light through it).
## {base (model origin), basis, h (model scale), grand (0..1: how close the camera is)}.
static func _stage(node: Node, origin: Vector3, away: Vector3, behind: float, chest: float, across: float, lean: float, side := 1.0) -> Dictionary:
	var camera := _camera(node)
	var up := Vector3.UP
	var fwd := -away
	var h := 14.0
	var base := origin + away * behind
	var grand := 0.0
	if camera:
		var rect := camera.get_viewport().get_visible_rect().size
		var look := -camera.global_basis.z
		var fighter := origin + Vector3.UP
		var depth := maxf((fighter - camera.global_position).dot(look), 2.0) + behind
		var col := 0.5
		var head := 0.42
		if not camera.is_position_behind(fighter):
			col = camera.unproject_position(fighter).x / rect.x
			head = camera.unproject_position(origin + Vector3.UP * 1.9).y / rect.y
		# The gameplay camera close behind the fighter (6 m back) sees the giant small for
		# its 16 m: there it stands grander, its crown past the top of the screen and its
		# chest low, dissolving into the cloud beside the fighter (the ground never cuts it:
		# RamakienSpirit draws it over the ground), leaning further over the field.
		grand = clampf((9.0 - (depth - behind)) / 2.5, 0.0, 1.0)
		var low_y := chest + 0.16 * grand
		var x_at := col + across
		if chest < 0.0:
			# Just under the fighter's head, above its column; if that leaves the bust too
			# little of the screen (a steep camera close behind the fighter), the giant
			# steps to the side and stands taller beside it, its face clear of the fighter.
			low_y = clampf(head + 0.01, 0.34, 0.56)
			if head < 0.42:
				low_y = 0.5 + 0.16 * grand
				x_at = 0.5 - (0.27 + 0.03 * grand) * signf(side) if side != 0.0 else 0.23 - 0.03 * grand
		elif across != 0.0:
			x_at = 0.5 + across + 0.05 * grand * signf(across)
		var x := clampf(x_at, 0.12, 0.88) * rect.x
		var top := camera.project_position(Vector2(x, rect.y * lerpf(0.03, -0.06, grand)), depth)
		var low := camera.project_position(Vector2(x, rect.y * low_y), depth)
		var span := top - low
		if span.length() > 0.5:
			up = span.normalized()
			h = clampf(span.length() / (1.0 - CHEST), 7.0, lerpf(22.0, 30.0, grand))
			base = top - up * h
			fwd = camera.global_position - base
	fwd = fwd - up * fwd.dot(up)
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else -away
	var right := up.cross(fwd).normalized()
	var basis := Basis(right, lean + 0.08 * grand) * Basis(right, up, fwd)
	return {"base": base, "basis": basis, "h": h, "grand": grand}


## The cast's frame: [forward, right] from [param source] to [param point].
static func _frame(art: Node3D, id: String, source: Vector3, point: Vector3) -> Array:
	var f := (point - source) * Vector3(1, 0, 1)
	if f.length_squared() < 0.04:
		f = StarSignature.forward(art, id) * Vector3(1, 0, 1)
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.BACK
	return [f, f.cross(Vector3.UP).normalized()]


## A giant rising out of its cloud on [param root] (standing at the model origin
## [param stage].base): the dusk, the aureole, the body, its cloud bank, embers and
## shafts of light. Returns the model-to-root mapping for placing pieces on it.
func _manifest(kind: String, look: Dictionary, stage: Dictionary, mirror: bool, seconds: float, front: Vector3, halo: Vector3, halo_size: float, extra: Dictionary = {}) -> void:
	var basis: Basis = stage.basis
	var h := float(stage.h)
	var size := Vector3(-h if mirror else h, h, h)
	var euler := basis.get_euler()
	var near := {"front_world": front, "front_push": 1.1}
	var far := {"front_world": front, "front_push": 1.8}
	_veil(seconds)
	_sculpt(kind, look, -basis.y * h * 0.035, size, euler, 0.0, seconds, {"initial": 1.0, "travel": basis.y * h * 0.05, "fade_in": 0.02, "decay": 0.9, "opacity": 0.95, "priority": PRI_BODY}, {"manifest": 0.8, "mist_lo": 0.2, "mist_hi": 0.36, "front_world": front, "front_push": 1.4}.merged(extra, true))
	# The cloud it rises from, across the chest; the aureole behind the heads.
	_light("bank", 9, L_GOLD, Color("fff3dc"), model(stage, Vector3(0, 0.21, 0.12), mirror), Vector3(h * 0.55, h * 0.2, 1.0), 0.0, seconds, {"initial": 0.7, "grow": 2.0, "billboard": true, "fade_in": 0.08, "decay": 0.88, "opacity": 0.95, "priority": 1}, near)
	_light("quad", 1, L_GOLD, L_WHITE, model(stage, halo, mirror), Vector3.ONE * h * halo_size, 0.3, seconds - 0.3, {"initial": 0.4, "grow": 1.6, "billboard": true, "fade_in": 0.14, "decay": 0.88, "opacity": 1.0, "priority": PRI_HALO, "tier": TIER_MID}, far)
	_light("embers", 5, L_GOLD, L_WHITE, model(stage, Vector3(0, 0.1, 0.1), mirror), Vector3(h * 0.55, h * 0.8, h * 0.3), 0.2, seconds - 0.2, {"initial": 1.0, "fade_in": 0.1, "decay": 0.85, "priority": 2, "tier": TIER_MID}, near)
	var grand := float(stage.get("grand", 0.0))
	for k in 2:
		var x := -0.3 if k == 0 else 0.34
		_light("shaft", 4, L_GOLD, L_WHITE, model(stage, Vector3(x, 0.05, -0.1), mirror), Vector3(h * (0.2 + 0.06 * grand), h * 1.2, 1.0), 0.15 + 0.12 * float(k), seconds - 0.4, {"initial": 0.7, "grow": 2.0, "face_camera": true, "fade_in": 0.2, "decay": 0.8, "opacity": 0.6, "priority": PRI_HALO - 1, "tier": TIER_DEBRIS}, far)
	if grand > 0.5:
		# Close behind the fighter: a broad shaft of heaven's light falls through the crown
		# from past the top of the screen.
		_light("shaft", 4, L_GOLD, L_WHITE, model(stage, Vector3(0.0, 0.22, -0.16), mirror), Vector3(h * 0.42, h * 1.3, 1.0), 0.05, seconds - 0.3, {"initial": 0.5, "grow": 3.0, "face_camera": true, "fade_in": 0.25, "decay": 0.82, "opacity": 0.5, "priority": PRI_HALO - 1, "tier": TIER_MID}, far)


## A model point of the giant staged as [param stage], relative to its root.
static func model(stage: Dictionary, p: Vector3, mirror := false) -> Vector3:
	var basis: Basis = stage.basis
	return basis * (Vector3(-p.x if mirror else p.x, p.y, p.z) * float(stage.h))


# ===========================================================================
# ★200 หนุมานแผลงฤทธิ์
# ===========================================================================

## Where the trident of beat [param index] stakes the ground (world, flat).
static func trident_spot(center: Vector3, forward: Vector3, right: Vector3, radius: float, index: int) -> Vector3:
	var r := clampf(radius, 4.0, 8.0) * 0.44
	var spots := [Vector2(-0.62, 0.05), Vector2(0.58, 0.3), Vector2(-0.2, 0.62), Vector2(0.36, -0.5), Vector2.ZERO]
	var s: Vector2 = spots[clampi(index, 0, 4)]
	return Vector3(center.x, 0, center.z) + right * s.x * r + forward * s.y * r


static func hanuman_telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if art else null
	if not _alive(parent) or not is_instance_valid(caster):
		return false
	var id := HANUMAN_ID
	var origin := caster.global_position * Vector3(1, 0, 1)
	var center := Vector3(point.x, 0, point.z)
	var frame := _frame(art, id, origin, center)
	var radius := float(skill.get("radius", 7.5))
	var stay := time + float(HANUMAN_BEATS.back()) + 0.7
	var view := _view(parent, origin, frame[0])
	var away: Vector3 = view[0]
	var right: Vector3 = view[1]
	# Hanuman rises on the side away from the target, so the yawn plays over the field.
	var side := -1.0 if (center - origin).dot(right) >= -0.5 else 1.0
	# The sky over the target: the stars and the moon hang there, under the top of the view.
	var sky := clampf(fit_height(parent, center, 7.0, 0.4, 0.12) * 0.8, 3.0, 6.0)
	_sets[id] = {"sky": sky, "moon": center + Vector3.UP * (sky + 0.1) + frame[0] * 0.8, "radius": radius}
	var ground := _open(parent, origin, "RamakienSeal_" + id, id)
	# The fighter's take-off: a ยันต์ seal under its feet and mantra script rising.
	ground.layer("yant", false, _lace(LEAF), Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, time + 0.3, {"initial": 0.3, "grow": 2.0, "spin": 0.8, "fade_in": 0.2, "decay": 0.8, "opacity": 0.9})
	ground.layer("script", true, LEAF, Vector3.UP * 0.2, Vector3(1.0, 1.1, 1.0), Vector3.ZERO, 0.05, time, {"initial": 0.5, "grow": 2.0, "spin": 2.4, "travel": Vector3(0, 2.4, 0), "fade_in": 0.2, "decay": 0.7, "opacity": 0.75, "tier": TIER_MID})
	# The first trident falls on the release from the first star.
	_trident_fall(ground, origin, center, frame, radius, 0, time, sky)
	if MemoryGuard.pressure < 2:
		var stage := _stage(parent, origin, away, 9.0, 0.6, side * 0.29, 0.14)
		var base: Vector3 = stage.base
		# (A layer's scale stays positive: the sculpture itself carries his pose.)
		var mirror := false
		var giant := _open(parent, base, "RamakienHanuman_" + id, id)
		# The yawn: the mouth opens as the moon and the stars pour out.
		var yawn := time * 0.5
		giant._manifest("hanuman", HANUMAN_LOOK, stage, mirror, stay, origin + Vector3.UP, Vector3(0, 0.56, -0.08), 0.62, {"yawn_at": yawn - 0.05, "yawn_len": 1.0})
		var mouth := model(stage, Vector3(0, 0.44, 0.1), mirror)
		var moon: Vector3 = _sets[id].moon
		var moon_at := moon - base
		var pour := {"initial": 0.12, "grow": 3.0, "travel": moon_at - mouth, "snap": 0.6, "pop": 0.0, "billboard": true, "fade_in": 0.05, "decay": 0.9, "priority": 3}
		var sky_depth := {"front_world": origin + Vector3.UP, "front_push": 1.0}
		# A breath of gold light from the open mouth.
		giant._light("quad", 0, L_GOLD, L_WHITE, mouth, Vector3.ONE * float(stage.h) * 0.16, yawn, 0.7, {"initial": 0.3, "grow": 4.0, "billboard": true, "decay": 0.5, "opacity": 0.9, "priority": 3, "tier": TIER_MID}, sky_depth)
		# The crescent and its halo rise from the mouth to the sky over the target.
		giant._light("quad", 2, L_MOON, L_WHITE, mouth, Vector3.ONE * 3.4, yawn + 0.05, stay - yawn - 0.05, pour, sky_depth)
		giant._light("quad", 0, L_GOLD, L_MOON, mouth, Vector3.ONE * 6.0, yawn + 0.08, stay - yawn - 0.1, pour.merged({"opacity": 0.22, "priority": 2, "tier": TIER_MID}, true), sky_depth)
		# The stars: one over each trident's spot (the trident falls from it), more round them.
		for k in 4:
			var star := _star_spot(center, frame, radius, k, sky) - base
			var t0 := yawn + 0.1 + 0.05 * float(k)
			giant._light("quad", 3, L_GOLD, L_WHITE, mouth, Vector3.ONE * 1.5, t0, _star_life(time, k) - t0, {"initial": 0.15, "grow": 4.0, "travel": star - mouth, "snap": 0.45, "pop": 0.0, "billboard": true, "roll": 0.6, "fade_in": 0.04, "decay": 0.88, "priority": 3, "tier": TIER_CORE if k < 3 else TIER_MID}, sky_depth)
		for k in count(6):
			var a := float(k) * 2.39996 + 0.4
			var spot: Vector3 = center + frame[1] * sin(a) * radius * 0.7 + frame[0] * cos(a) * radius * 0.45 + Vector3.UP * (sky + 0.5 + 0.6 * fmod(float(k) * 0.618, 1.0))
			var t0 := yawn + 0.12 + 0.04 * float(k)
			giant._light("quad", 3, L_MOON, L_WHITE, mouth, Vector3.ONE * (0.7 + 0.2 * float(k % 3)), t0, stay - t0 - 0.2, {"initial": 0.2, "grow": 4.0, "travel": spot - base - mouth, "snap": 0.55, "pop": 0.0, "billboard": true, "roll": 0.4, "fade_in": 0.04, "decay": 0.86, "opacity": 0.85, "priority": 3, "tier": TIER_DEBRIS}, sky_depth)
	return true


## The sky spot of the star a trident falls from (the fifth is the moon).
static func _star_spot(center: Vector3, frame: Array, radius: float, index: int, sky: float) -> Vector3:
	var at := trident_spot(center, frame[0], frame[1], radius, index)
	return at + Vector3.UP * (sky - (0.2 if index < 4 else -0.1)) + frame[0] * (0.0 if index < 4 else 0.8)


## A star burns until its trident leaves it.
static func _star_life(time: float, index: int) -> float:
	return time + float(HANUMAN_BEATS[index]) - 0.14


## The trident of beat [param index] falls from its star to stake the ground at
## [param land] seconds on [param root]'s clock, a trail of light behind it.
static func _trident_fall(root: RamakienArt, root_at: Vector3, center: Vector3, frame: Array, radius: float, index: int, land: float, sky: float) -> void:
	var spot := trident_spot(center, frame[0], frame[1], radius, index)
	var final := index >= 4
	var length := 5.4 if final else 4.0
	var fall := 0.22 if final else 0.16
	var tip := spot + Vector3.UP * (length * 0.5 - 0.4)
	var from := _star_spot(center, frame, radius, index, sky) + Vector3.UP * length * 0.5
	var local := from - root_at
	var hold := 1.25 if final else 0.95
	var drop := {"initial": 1.0, "travel": tip - from, "snap": fall, "snap_in": true, "accelerate": true, "pop": 0.0, "point": Vector3.DOWN}
	root._sculpt("trident", TRIDENT_LOOK, local, Vector3.ONE * length * 0.5, Vector3.ZERO, land - fall, fall + hold, drop.merged({"fade_in": 0.03, "decay": 0.82, "opacity": 1.0, "priority": 2}, true), {"rim_power": 1.3})
	root._light("trail", 7, L_GOLD, L_WHITE, local, Vector3(length * 1.4, length * 0.3, 1.0), land - fall, fall + 0.14, drop.merged({"decay": 0.45, "opacity": 0.9, "tier": TIER_MID}, true))


static func hanuman_strike(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> bool:
	if not _alive(parent):
		return false
	var id := HANUMAN_ID
	var center := Vector3(point.x, 0, point.z)
	var frame := _frame(art, id, source, center)
	var radius := float(skill.get("radius", 7.5))
	var set: Dictionary = _sets.get(id, {})
	var sky := float(set.get("sky", 4.5))
	var spot := trident_spot(center, frame[0], frame[1], radius, index)
	var final := index >= 4
	var fx: Dictionary = skill.get("fx", {})
	# The ยันต์ seal the trident detonates: on the contact root (StarContact), so the beat's
	# own root carries its mark.
	var seal := (radius * 0.62 if final else 2.5)
	_paint(art, "yant", _lace(LEAF), art.to_local(spot + Vector3.UP * 0.05), Vector3.ONE * seal, 1.4 if final else 1.1, {"initial": 0.55, "grow_time": 0.07, "spin": 0.5, "decay": 0.72, "fade_in": 0.01, "opacity": 0.8 if final else 0.9}, false, -1)
	var hit := _open(parent, spot, "RamakienYant_%s_%d" % [id, index], id)
	# The next trident falls from its star (the fifth from the moon) on the next beat.
	if index < 4:
		var gap := float(HANUMAN_BEATS[index + 1]) - float(HANUMAN_BEATS[index])
		_trident_fall(hit, spot, center, frame, radius, index + 1, gap, sky)
	# The blow: a flash with rays, a shockwave rolling out, dust thrown up, gold cracks.
	hit._light("quad", 10, L_GOLD, L_WHITE, Vector3.UP * 0.7, Vector3.ONE * (4.2 if final else 2.6), 0.0, 0.34, {"initial": 0.4, "grow": 9.0, "billboard": true, "decay": 0.4, "priority": 4})
	hit.layer("shock", true, SUN, Vector3.UP * 0.06, Vector3.ONE * (radius * 0.8 if final else 2.8), Vector3.ZERO, 0.0, 0.55, {"initial": 0.12, "grow": 4.5, "decay": 0.5})
	hit.layer("crack", true, SUN, Vector3.UP * 0.045, Vector3.ONE * (seal * 0.75), Vector3(0, randf() * TAU, 0), 0.0, 1.1, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.9, "tier": TIER_MID})
	# อักขระ: the seal's script rises round the trident; debris and glints are thrown off.
	hit.layer("script", true, LEAF, Vector3.UP * 0.1, Vector3(seal * 0.5, 1.2, seal * 0.5), Vector3.ZERO, 0.0, 0.9, {"initial": 0.6, "grow": 5.0, "spin": 2.6, "travel": Vector3(0, 1.6, 0), "decay": 0.6, "opacity": 0.75, "tier": TIER_DEBRIS})
	hit._sparks(MOON, Vector3.UP * 0.45, 5, 0.0, 1.3 if final else 0.9)
	hit.layer("smoke", true, DUST, Vector3.UP * 0.1, Vector3.ONE * (2.8 if final else 1.6), Vector3.ZERO, 0.04, 1.0, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 1.2, 0), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": TIER_DEBRIS})
	if final:
		# The moon's trident: a second ring, a column of light, the pack is stunned.
		hit.layer("shock", true, GOLD, Vector3.UP * 0.07, Vector3.ONE * radius * 1.05, Vector3.ZERO, 0.08, 0.6, {"initial": 0.12, "grow": 4.0, "decay": 0.5, "opacity": 0.35, "tier": TIER_MID})
		hit._light("shaft", 4, L_GOLD, L_WHITE, Vector3.ZERO, Vector3(2.6, 9.0, 1.0), 0.0, 0.9, {"initial": 0.5, "grow": 6.0, "face_camera": true, "decay": 0.5, "opacity": 0.8, "tier": TIER_MID})
		hit._stun_stars(Vector3.UP * 0.6, 0.05, float(fx.get("stun", 1.5)), 3)
	return true


# ===========================================================================
# ★300 สิบเศียรสิบกรสะท้านสามภพ
# ===========================================================================

## The fists of wave [param wave] (0-3) for the current depth.
static func wave_fists(wave: int) -> int:
	return int(WAVE_FISTS[depth()][clampi(wave, 0, 3)])


## Where fist [param k] of wave [param wave] lands (world, flat): round the fighter,
## spread over the side away from the camera so none lands between it and the fighter.
static func fist_spot(center: Vector3, away: Vector3, radius: float, wave: int, k: int, n: int) -> Vector3:
	var base := atan2(away.x, away.z)
	var a := base + lerpf(-1.6, 1.6, (float(k) + 0.5) / float(maxi(n, 1))) + 0.19 * float(wave) * (1.0 if k % 2 == 0 else -1.0)
	var r := clampf(radius, 5.0, 9.0) * (0.3 + 0.3 * fmod(float(k) * 0.618 + float(wave) * 0.29, 1.0))
	return Vector3(center.x, 0, center.z) + Vector3(sin(a), 0, cos(a)) * r


static func thotsakan_telegraph(art: StarSkillArt, caster: Node3D, skill: Dictionary, point: Vector3, time: float) -> bool:
	var parent := art.get_parent() as Node3D if art else null
	if not _alive(parent) or not is_instance_valid(caster):
		return false
	var id := THOTSAKAN_ID
	var origin := caster.global_position * Vector3(1, 0, 1)
	var frame := _frame(art, id, origin, Vector3(point.x, 0, point.z))
	var radius := float(skill.get("radius", 9.0))
	var beats: Array = StarSkillData.GOD_BEATS
	var stay := time + float(beats.back()) + 0.7
	var view := _view(parent, origin, frame[0])
	var away: Vector3 = view[0]
	var sky := clampf(fit_height(parent, origin, 7.0, 0.4, 0.06) * 0.95, 3.2, 6.5)
	_sets[id] = {"away": away, "sky": sky, "radius": radius, "origin": origin}
	# The ground (always): a jade-and-gold ยันต์ seal turning under the fighter, mantra
	# script rising, and the first wave of fists falling on the release.
	var ground := _open(parent, origin, "StarGodGround_" + id, id)
	ground.layer("yant", false, _lace(JADE), Vector3.UP * 0.04, Vector3.ONE * 3.0, Vector3.ZERO, 0.0, time + 0.35, {"initial": 0.3, "grow": 2.0, "spin": 0.7, "fade_in": 0.2, "decay": 0.82, "opacity": 0.92})
	ground.layer("script", true, LEAF, Vector3.UP * 0.2, Vector3(1.2, 1.2, 1.2), Vector3.ZERO, 0.05, time, {"initial": 0.5, "grow": 2.0, "spin": -2.2, "travel": Vector3(0, 1.8, 0), "fade_in": 0.2, "decay": 0.7, "opacity": 0.75, "tier": TIER_MID})
	ground.layer("yant", false, _lace(LEAF), Vector3.UP * 0.045, Vector3.ONE * 4.4, Vector3.ZERO, 0.15, time + 0.2, {"initial": 0.4, "grow": 2.0, "spin": -0.35, "fade_in": 0.25, "decay": 0.8, "opacity": 0.4, "tier": TIER_MID})
	_fist_wave(ground, origin, 0, time)
	# The sky (no memory pressure): ทศกัณฐ์ itself.
	if GodSkillArt.extra_roots(1) >= 1:
		var stage := _stage(parent, origin, away, 11.0, -1.0, 0.0, 0.12)
		var base: Vector3 = stage.base
		_sets[id].merge({"base": base, "stage": stage}, true)
		var giant := _open(parent, base, "StarGodSky_" + id, id)
		giant._manifest("thotsakan", YAK_LOOK, stage, false, stay, origin + Vector3.UP, Vector3(0, 0.6, -0.1), 1.05)
		# Eighteen more arms unfurl round the shoulders once it has risen.
		var h := float(stage.h)
		var basis: Basis = stage.basis
		var rise := 0.55
		giant._sculpt("thotsakan_arms", YAK_LOOK, model(stage, RamakienSculpt.ARM_PIVOT) - basis.y * h * 0.035, Vector3.ONE * h, basis.get_euler(), rise, stay - rise, {"initial": 0.3, "grow": 2.6, "overshoot": true, "travel": basis.y * h * 0.05, "fade_in": 0.04, "decay": 0.9, "opacity": 0.95, "priority": PRI_ARMS}, {"mist_lo": -0.1, "mist_hi": 0.02, "front_world": origin + Vector3.UP, "front_push": 1.5, "skin_alpha": 0.72, "rim_power": 1.5})
	return true


## Wave [param wave]'s fists on [param root] (standing at [param root_at]): they fall
## from the giant's side of the sky and land at [param land] on the root's clock.
static func _fist_wave(root: RamakienArt, root_at: Vector3, wave: int, land: float) -> void:
	var set: Dictionary = _sets.get(THOTSAKAN_ID, {})
	var away: Vector3 = set.get("away", Vector3.BACK)
	var center: Vector3 = root_at if wave == 0 else set.get("origin", root_at)
	var radius := float(set.get("radius", 9.0))
	var sky := float(set.get("sky", 5.0))
	var n := wave_fists(wave)
	var fall := float(WAVE_FALL[wave])
	for k in n:
		var spot := fist_spot(center, away, radius, wave, k, n)
		var size := 1.45 - 0.06 * float(wave)
		# Knuckles land on the ground: the mesh's knuckles sit 0.62 of its size ahead.
		var to := spot + Vector3.UP * (0.5 * size + 0.1)
		var side := away.cross(Vector3.UP) * (1.1 if k % 2 == 0 else -1.1)
		var from := to + Vector3.UP * sky + away * 2.8 + side
		var dir := (to - from).normalized()
		var lag := 0.025 * float(k % 3)
		root._spirit_fist(from - root_at, to - root_at, land - fall + lag, fall, size, 0.24, TIER_CORE, dir)


## A spirit fist of ทศกัณฐ์ snapping from [param from] to [param to], a trail of light
## streaming behind it.
func _spirit_fist(from: Vector3, to: Vector3, start: float, snap: float, size: float, hold: float, tier: int, dir: Vector3) -> void:
	var blow := {"initial": 0.85, "grow": 14.0, "travel": to - from, "snap": snap, "snap_in": true, "accelerate": true, "point": dir}
	_light("trail", 7, L_JADE, L_WHITE, from, Vector3(size * 4.0, size * 1.4, 1.0), start, snap + hold * 0.4, blow.merged({"pop": 0.0, "fade_in": 0.02, "decay": 0.35, "opacity": 1.0, "tier": mini(tier + 1, TIER_DEBRIS)}, true))
	_sculpt("spirit_fist", FIST_LOOK, from, Vector3.ONE * size, Vector3.ZERO, start, snap + hold, blow.merged({"fade_in": 0.02, "decay": 0.7, "opacity": 0.92, "tier": tier, "priority": 1}, true), {"rim_power": 2.2, "skin_alpha": 0.8})


static func thotsakan_wave(art: StarSkillArt, parent: Node3D, skill: Dictionary, index: int, point: Vector3, source: Vector3) -> bool:
	if not _alive(parent):
		return false
	var id := THOTSAKAN_ID
	var set: Dictionary = _sets.get(id, {})
	var origin := Vector3(source.x, 0, source.z)
	set["origin"] = origin
	_sets[id] = set
	var away: Vector3 = set.get("away", _frame(art, id, source, point)[0])
	var radius := float(skill.get("radius", 9.0))
	var beats: Array = StarSkillData.GOD_BEATS
	var n := wave_fists(index)
	# The beat's quake under the fighter (on the contact root).
	_paint_light(art, "disc", 0, L_GOLD, L_WHITE, art.to_local(origin + Vector3.UP * 0.06), Vector3.ONE * radius * (0.32 + 0.06 * float(index)), 0.5, {"initial": 0.4, "grow_time": 0.3, "decay": 0.45, "opacity": 0.55}, -1)
	# What comes next first, on its own root (its own cap): the next wave's fists, or
	# after the fourth the fists fusing into the god fist.
	var next := _open(parent, origin, "RamakienFists_%s_%d" % [id, index + 1], id)
	if index < 3:
		_fist_wave(next, origin, index + 1, float(beats[index + 1]) - float(beats[index]))
	else:
		_merge(next, origin, float(beats[4]) - float(beats[3]))
	# This wave's landings: a flash, a shockwave, dust and gold cracks under each fist
	# (the flashes first, so a tight cap keeps one per fist).
	var hit := _open(parent, origin, "RamakienWave_%s_%d" % [id, index], id)
	var spots: Array = []
	for k in n:
		spots.append(fist_spot(origin, away, radius, index, k, n) - origin)
	for k in n:
		hit._light("quad", 10, L_GOLD if k % 2 == 0 else L_JADE, L_WHITE, spots[k] + Vector3.UP * 0.5, Vector3.ONE * 2.2, 0.0, 0.3, {"initial": 0.4, "grow": 9.0, "billboard": true, "decay": 0.4, "priority": 4, "tier": TIER_CORE if k < 3 else TIER_MID})
	for k in n:
		hit.layer("shock", true, GOLD, spots[k] + Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, 0.45, {"initial": 0.15, "grow": 5.0, "decay": 0.45, "opacity": 0.4, "tier": TIER_MID if k < 4 else TIER_DEBRIS})
	for k in n:
		hit.layer("crack", true, SUN, spots[k] + Vector3.UP * 0.04, Vector3.ONE * 1.3, Vector3(0, randf() * TAU, 0), 0.0, 0.8, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.9, "tier": TIER_MID if k < 3 else TIER_DEBRIS})
		hit.layer("smoke", true, DUST, spots[k] + Vector3.UP * 0.2, Vector3.ONE * 1.3, Vector3.ZERO, 0.03, 0.8, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 0.8, 0), "face_camera": true, "decay": 0.5, "opacity": 0.4, "tier": TIER_DEBRIS})
	return true


## Where the god fist lands, from the fighter: past it and to the side, so the fist
## hanging before it never hides the giant's ten heads.
static func slam_offset(away: Vector3) -> Vector3:
	return away * 1.4 + away.cross(Vector3.UP).normalized() * 2.0


## The last wave's fists fly up and fuse over the slam point into one enormous fist that
## hammers down at [param land] (the finale beat, on [param root]'s clock).
static func _merge(root: RamakienArt, origin: Vector3, land: float) -> void:
	var set: Dictionary = _sets.get(THOTSAKAN_ID, {})
	var away: Vector3 = set.get("away", Vector3.BACK)
	var radius := float(set.get("radius", 9.0))
	var slam := slam_offset(away)
	var size := 3.0
	# The god fist comes down on a slant from the giant's side, knuckles first.
	var side := away.cross(Vector3.UP).normalized()
	var aim := (Vector3.DOWN - side * 0.42).normalized()
	var knuckles := slam + Vector3.UP * (0.5 * size + 0.15)
	var room := fit_height(root, origin + slam, 10.0, 0.3, 0.04)
	var lift := clampf(room - 1.6 * size, 1.2, 4.0)
	var apex := knuckles - aim * lift
	var gather := 0.03
	var fly := 0.17
	var fused := gather + fly
	var hang := land - 0.11
	# The god fist first (the root's cap keeps the first layers): it hangs a breath over
	# the slam point, then hammers down on the finale beat.
	root._sculpt("spirit_fist", FIST_LOOK, apex, Vector3.ONE * size, Vector3.ZERO, fused, hang - fused + 0.02, {"initial": 0.3, "grow": 4.0, "overshoot": true, "travel": -aim * 0.35, "point": aim, "fade_in": 0.03, "decay": 0.99, "opacity": 0.92, "priority": 1}, {"rim_power": 2.0, "skin_alpha": 0.85})
	var top := apex - aim * 0.35
	var slam_style := {"initial": 1.0, "travel": knuckles - top, "snap": 0.11, "snap_in": true, "accelerate": true, "point": aim}
	root._sculpt("spirit_fist", FIST_LOOK, top, Vector3.ONE * size, Vector3.ZERO, hang, 0.11 + 0.5, slam_style.merged({"decay": 0.75, "opacity": 0.92, "priority": 1}, true), {"rim_power": 2.0, "skin_alpha": 0.85})
	# The flash where the fists fuse, the trail of the slam, its halo.
	root._light("quad", 10, L_JADE, L_WHITE, apex, Vector3.ONE * 4.0, fused - 0.03, 0.2, {"initial": 0.2, "grow": 10.0, "billboard": true, "decay": 0.4, "priority": 3})
	root._light("trail", 7, L_JADE, L_WHITE, top, Vector3(size * 3.0, size * 1.2, 1.0), hang, 0.24, slam_style.merged({"pop": 0.0, "decay": 0.4, "opacity": 0.9, "tier": TIER_MID}, true))
	root._light("quad", 0, L_JADE, L_WHITE, apex, Vector3.ONE * size * 2.6, fused, hang - fused, {"initial": 0.3, "grow": 4.0, "travel": -aim * 0.35, "billboard": true, "fade_in": 0.1, "decay": 0.9, "opacity": 0.5, "priority": 0, "tier": TIER_MID})
	# The last wave's fists fly up from where they landed and fuse.
	var n := wave_fists(3)
	for k in mini(n, 6):
		var spot := fist_spot(origin, away, radius, 3, k, n) - origin + Vector3.UP * 0.8
		var dir := (apex - spot).normalized()
		root._sculpt("spirit_fist", FIST_LOOK, spot, Vector3.ONE * 0.7, Vector3.ZERO, gather, fly, {"initial": 1.6, "grow": 1.0, "travel": apex - spot, "accelerate": true, "point": dir, "fade_in": 0.05, "decay": 0.8, "opacity": 0.85, "priority": 1, "tier": TIER_CORE if k < 2 else TIER_MID})


static func thotsakan_finale(art: StarSkillArt, parent: Node3D, skill: Dictionary, point: Vector3, source: Vector3) -> bool:
	if not _alive(parent):
		return false
	var id := THOTSAKAN_ID
	var set: Dictionary = _sets.get(id, {})
	var origin := Vector3(source.x, 0, source.z)
	var away: Vector3 = set.get("away", _frame(art, id, source, point)[0])
	var radius := float(skill.get("radius", 9.0))
	var fx: Dictionary = skill.get("fx", {})
	var slam := origin + slam_offset(away)
	# กระจกสี: gold light cracks the ground into temple glass that spreads and fades
	# (the contact root).
	_paint_light(art, "disc", 6, L_GOLD, L_WHITE, art.to_local(slam + Vector3.UP * 0.05), Vector3.ONE * radius * 0.8, 1.9, {"initial": 1.0, "grow_time": 0.01, "decay": 0.66, "fade_in": 0.01, "opacity": 1.0}, 0, {"spread": 0.55})
	_paint(art, "shock", GOLD, art.to_local(slam + Vector3.UP * 0.07), Vector3.ONE * radius * 0.75, 0.6, {"initial": 0.12, "grow_time": 0.4, "decay": 0.5, "opacity": 0.4}, true, 1)
	var hit := _open(parent, slam, "RamakienSlam_" + id, id)
	hit._light("quad", 10, L_GOLD, L_WHITE, Vector3(0, 0.8, 0), Vector3.ONE * 6.0, 0.0, 0.36, {"initial": 0.3, "grow": 9.0, "billboard": true, "decay": 0.45, "priority": 4})
	hit.layer("shock", true, SUN, Vector3.UP * 0.08, Vector3.ONE * radius * 1.0, Vector3.ZERO, 0.05, 0.6, {"initial": 0.1, "grow": 4.0, "decay": 0.5, "opacity": 0.32})
	hit._stun_stars(Vector3.UP * 0.3, 0.05, float(fx.get("stun", 1.5)), 3)
	for k in count(4):
		var a := float(k) * 1.7 + 0.4
		hit.layer("smoke", true, DUST, Vector3(sin(a), 0.1, cos(a)) * 1.8, Vector3.ONE * 2.0, Vector3.ZERO, 0.03 + 0.03 * float(k), 1.1, {"initial": 0.3, "grow": 3.0, "travel": Vector3(sin(a) * 1.4, 1.2, cos(a) * 1.4), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": TIER_MID if k == 0 else TIER_DEBRIS})
	hit._sparks(SUN, Vector3(0, 0.6, 0), 8, 0.02, 1.8)
	# The struck burn: orange flame wisps on each foe in reach (not a yellow overlay).
	if fx.has("burn"):
		_burn_wisps(parent, origin, radius, id)
	# The avatar (no memory pressure): the three realms quake in rings of heaven (gold),
	# earth (jade) and the underworld (red); the ten heads' eyes flash.
	if GodSkillArt.extra_roots(1) >= 1:
		var avatar := _open(parent, origin, "StarGodAvatar_" + id, id)
		var realms := [[GOLD, 0.09, 0.55], [JADE, 0.1, 0.8], [CLOTH, 0.11, 1.05]]
		for k in 3:
			var c: Array = realms[k][0]
			avatar.layer("shock", true, c, slam_offset(away) + Vector3.UP * float(realms[k][1]), Vector3.ONE * radius * float(realms[k][2]), Vector3.ZERO, 0.04 + 0.07 * float(k), 0.6, {"initial": 0.2, "grow": 4.5, "decay": 0.45, "opacity": 0.22, "tier": TIER_CORE if k < 2 else TIER_MID})
		if set.has("stage"):
			var stage: Dictionary = set.stage
			var base: Vector3 = set.base
			for side in [-1.0, 1.0]:
				avatar._light("quad", 3, L_GOLD, L_WHITE, base - origin + model(stage, Vector3(side * 0.023, 0.503, 0.08)), Vector3.ONE * float(stage.h) * 0.07, 0.0, 0.5, {"initial": 0.3, "grow": 6.0, "billboard": true, "decay": 0.5, "priority": 3, "tier": TIER_MID})
	# The temple (high quality only): shafts of gold light rise from the glass.
	if GodSkillArt.extra_roots(2) >= 2:
		var temple := _open(parent, slam, "StarGodTemple_" + id, id)
		for k in count(5):
			var a := float(k) * 2.39996 + 0.3
			temple._light("shaft", 4, L_GOLD, L_WHITE, Vector3(sin(a), 0, cos(a)) * radius * (0.18 + 0.08 * float(k)), Vector3(1.4, 6.5, 1.0), 0.06 + 0.05 * float(k), 1.1, {"initial": 0.4, "grow": 4.0, "face_camera": true, "fade_in": 0.12, "decay": 0.6, "opacity": 0.7})
	return true


## Orange flame wisps flickering on each foe within [param radius] of [param center].
static func _burn_wisps(parent: Node3D, center: Vector3, radius: float, id: String) -> void:
	var foes: Array = []
	for node in parent.get_children():
		if node is Mob and not (node as Mob).is_dead() and ((node as Node3D).global_position * Vector3(1, 0, 1)).distance_to(center) <= radius:
			foes.append(node)
	if foes.is_empty():
		return
	var root := _open(parent, center, "RamakienBurn_" + id, id)
	for k in mini(foes.size(), count(6)):
		var at := (foes[k] as Node3D).global_position - center
		for j in 2:
			var x := -0.22 if j == 0 else 0.2
			root._light("quad", 8, L_EMBER, L_FLAME, at + Vector3(x, 0.75 + 0.15 * float(j), 0.0), Vector3(0.75, 1.15, 1.0) * (1.0 - 0.2 * float(j)), 0.05 + 0.08 * float(k % 3) + 0.1 * float(j), 1.4, {"initial": 0.3, "grow": 5.0, "billboard": true, "travel": Vector3(0, 0.25, 0), "fade_in": 0.08, "decay": 0.6, "opacity": 0.9, "priority": 4, "tier": TIER_CORE if j == 0 else TIER_MID})


# ===========================================================================
# The figures (RamakienSculpt; shared, built while a Muay Thai fighter's zone loads)
# ===========================================================================

## Builds the figures while a zone loads (SpellSpectacle.warm_geometry), spread over
## frames by [param slicer], for a Muay Thai fighter only: nobody else casts them, and
## the giants are the costliest meshes of the class.
static func warm_figures(slicer: SceneTree = null) -> void:
	if not Game.has_profile or Game.class_id() != &"muaythai":
		return
	for kind in OWN:
		figure(String(kind))
		await FrameSlicer.pace(slicer)


static func release_figures() -> void:
	_own_meshes.clear()


static func figure(kind: String) -> ArrayMesh:
	if _own_meshes.has(kind):
		return _own_meshes[kind]
	var mesh := RamakienSculpt.build(kind)
	_own_meshes[kind] = mesh
	return mesh
