class_name RamakienArt
extends MuayThaiArt
## The Muay Thai fighter's two star skills from the รามเกียรติ์, painted like หนังใหญ่ (the
## great shadow-puppet theatre that plays the Ramakien): flat, outlined, cel-shaded cut-out
## figures in gold leaf, white, jade and red, rising translucent behind the fighter.
##   ★200 หนุมานแผลงฤทธิ์ (heaven_ring_cataclysm): the white monkey warrior rises from
##        gold clouds behind the fighter, his ตรีเพชร in hand, and yawns: stars and a
##        crescent moon pour from his mouth into the sky over the target (หาวเป็นดาวเป็น
##        เดือน). From each star a gold trident falls and stakes the ground on its beat,
##        a ยันต์ seal and อักขระ script bursting round it; the fifth, from the moon, at
##        the centre.
##   ★300 สิบเศียรสิบกรสะท้านสามภพ (three_realms_fist): ทศกัณฐ์ rises behind the fighter,
##        ten heads in tiers, twenty arms unfurling round them like an aureole. Its fists
##        rain round the fighter in four waves (GOD_BEATS), each denser and faster; then
##        the last wave's fists fly up and fuse into one enormous fist that slams down
##        in front of the fighter, gold light cracking the ground into temple glass
##        mosaic (กระจกสี).
## Same engine as MuayThaiArt: the MuayPaint shader (now with a second and third ramp in
## COLOR.b, so a figure wears skin, gold and red in one draw), shared meshes built once,
## pooled materials, the layer cap and the core / mid / debris tiers. Every root is tied
## to its cast (cast_ref): a hero dying or leaving mid-cast fades the set out at once.
## Cosmetic only: StarSkillSequence owns every contact, target and timing; the beats a
## piece lands on are the sequence's own (StarSkillSequence beats, GOD_BEATS).

const HANUMAN_ID := "heaven_ring_cataclysm"
const THOTSAKAN_ID := "three_realms_fist"
const HANUMAN_BEATS := [0.0, 0.32, 0.64, 0.96, 1.36]
## Ramps: [primary, accent, shade].
## หนุมาน's white body (cool shadow, warm white, indigo ink).
const WHITE := [Color("aab6e4"), Color("fffdf2"), Color("1d1848")]
## Gold leaf and the red of gems, cloth and an open mouth.
const LEAF := [Color("e39a12"), Color("fff0a4"), Color("5a2104")]
const RED := [Color("d1222c"), Color("ff9468"), Color("3a0410")]
## ทศกัณฐ์'s jade-green skin.
const GREEN := [Color("1f9c5a"), Color("a4f0b0"), Color("062a1a")]
## Clouds of gold (เมฆ ลายไทย).
const CLOUD := [Color("f0c66a"), Color("fff8e6"), Color("74400e")]
## The moon and stars: pale gold.
const MOON := [Color("ffd66a"), Color("fffbea"), Color("6a3a08")]
## Temple glass: jade, gold seams, red.
const GLASS := [Color("13b08a"), Color("c4fff0"), Color("06302a")]
const HANUMAN_RAMPS := [LEAF, RED]
const THOTSAKAN_RAMPS := [LEAF, RED]
const OWN := ["hanuman", "hanuman_yawn", "thotsakan", "thotsakan_arms", "trident", "moon", "star5", "cloud", "fist_yak", "mosaic"]
## Design height (m) of the giants: they are fitted under the top of the view (fit_height).
const GIANT := 7.4
const TITAN := 7.0
## Fist rain of the god skill: how many fists per wave at each depth (core / mid / debris).
const WAVE_FISTS := [[2, 2, 3, 3], [3, 4, 5, 6], [4, 5, 7, 9]]
## How long each wave's fists fall (the waves grow faster).
const WAVE_FALL := [0.3, 0.24, 0.19, 0.15]
static var _own_meshes: Dictionary = {}
## The set of the cast running now, per skill id (where the giant stands, its height,
## the sky height, the cast's frame), so the beats find it again.
static var _sets: Dictionary = {}
## Figure masks: geometry below _mask_hi fades out down to _mask_lo (the giant's waist).
static var _mask_lo := 0.0
static var _mask_hi := 0.0


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
# The view: where "behind the fighter" is for the camera now showing the field, and how
# tall a giant may stand there before it leaves the top of the screen.
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


## The tallest a camera-facing piece standing at [param base] may be (up to
## [param design]) with its top still inside the view; never under design * least.
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


## Whether a camera-facing figure [param h] tall and [param half] of that wide either
## side, standing at [param base], stays inside the view left and right.
static func _on_screen(node: Node, base: Vector3, h: float, half: float) -> bool:
	var camera := _camera(node)
	if camera == null:
		return true
	var width := camera.get_viewport().get_visible_rect().size.x
	var view := (base - camera.global_position) * Vector3(1, 0, 1)
	var right := view.normalized().cross(Vector3.UP) if view.length_squared() > 0.01 else Vector3.RIGHT
	for p in [base + right * h * half + Vector3.UP * h * 0.5, base - right * h * half + Vector3.UP * h * 0.5]:
		if camera.is_position_behind(p):
			return false
		var x := camera.unproject_position(p).x
		if x < width * 0.02 or x > width * 0.98:
			return false
	return true


## A camera-facing piece's up (perpendicular to the view, in the vertical plane).
static func _up(node: Node, at: Vector3) -> Vector3:
	var camera := _camera(node)
	if camera == null:
		return Vector3.UP
	var view := (at - camera.global_position).normalized()
	var up := Vector3.UP - view * view.y
	return up.normalized() if up.length_squared() > 0.0001 else Vector3.UP


## The cast's frame: [forward, right] from [param source] to [param point].
static func _frame(art: Node3D, id: String, source: Vector3, point: Vector3) -> Array:
	var f := (point - source) * Vector3(1, 0, 1)
	if f.length_squared() < 0.04:
		f = StarSignature.forward(art, id) * Vector3(1, 0, 1)
	f = f.normalized() if f.length_squared() > 0.0001 else Vector3.BACK
	return [f, f.cross(Vector3.UP).normalized()]


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
	var stay := time + float(HANUMAN_BEATS.back()) + 0.6
	# Where the fighter stands from the camera: Hanuman rises behind it, on the side
	# away from the target so the yawn plays over the battlefield, not on top of it.
	var view := _view(parent, origin, frame[0])
	var away: Vector3 = view[0]
	var right: Vector3 = view[1]
	var side := -1.0 if (center - origin).dot(right) >= -0.5 else 1.0
	var base := origin + away * 2.6 + right * side * 4.0
	var h := fit_height(parent, base, GIANT, 0.48)
	for lateral in [3.4, 2.8, 2.2, 1.6]:
		if _on_screen(parent, base, h, 0.62):
			break
		base = origin + away * 2.6 + right * side * float(lateral)
		h = fit_height(parent, base, GIANT, 0.48)
	var up := _up(parent, base)
	var mouth := base + up * h * 0.435
	# The sky over the target: the stars and the moon hang there, under the top of the view.
	var sky := clampf(fit_height(parent, center, 7.0, 0.4, 0.1) * 0.82, 3.0, 6.2)
	_sets[id] = {"sky": sky, "moon": center + Vector3.UP * (sky + 0.1) + frame[0] * 0.8, "radius": radius}
	var ground := _open(parent, origin, "RamakienSeal_" + id, id)
	# The fighter's take-off: a ยันต์ seal under its feet and mantra script rising.
	ground.layer("yant", false, _lace(LEAF), Vector3.UP * 0.04, Vector3.ONE * 2.2, Vector3.ZERO, 0.0, time + 0.3, {"initial": 0.3, "grow": 2.0, "spin": 0.8, "fade_in": 0.2, "decay": 0.8, "opacity": 0.9})
	ground.layer("script", true, LEAF, Vector3.UP * 0.2, Vector3(1.0, 1.1, 1.0), Vector3.ZERO, 0.05, time, {"initial": 0.5, "grow": 2.0, "spin": 2.4, "travel": Vector3(0, 2.4, 0), "fade_in": 0.2, "decay": 0.7, "opacity": 0.75, "tier": TIER_MID})
	# The first trident falls on the release from the first star.
	_trident_fall(ground, origin, center, frame, radius, 0, time, sky)
	if MemoryGuard.pressure < 2:
		var giant := _open(parent, base, "RamakienHanuman_" + id, id)
		var rise := 0.55
		var g := {"initial": 1.0, "billboard": true, "fade_in": 0.06, "decay": 0.9, "opacity": 0.93, "ramps": HANUMAN_RAMPS}
		var sink := Vector3.DOWN * h * 0.42
		giant.layer("hanuman", false, WHITE, sink, Vector3.ONE * h, Vector3.ZERO, 0.0, stay, g.merged({"travel": -sink, "snap": rise}, true))
		# The yawn: the mouth opens as the stars and the moon pour out.
		var yawn := time * 0.5
		giant.layer("hanuman_yawn", false, WHITE, Vector3.ZERO, Vector3.ONE * h, Vector3.ZERO, yawn, time - yawn + 0.3, g.merged({"fade_in": 0.03, "decay": 0.8, "priority": 1}, true))
		giant.layer("cloud", false, CLOUD, Vector3.UP * h * 0.02 - up * 0.1, Vector3(h * 0.55, h * 0.4, 1.0), Vector3.ZERO, 0.0, stay, {"initial": 0.4, "grow": 3.0, "overshoot": true, "billboard": true, "fade_in": 0.1, "decay": 0.88, "opacity": 0.95, "priority": 2, "ramps": [LEAF, RED]})
		var local_mouth := mouth - base
		var moon: Vector3 = _sets[id].moon
		# The crescent moon rises from the mouth to the sky over the target.
		giant.layer("moon", false, MOON, local_mouth, Vector3.ONE * 1.25, Vector3.ZERO, yawn + 0.05, stay - yawn - 0.05, {"initial": 0.12, "grow": 3.0, "travel": moon - mouth, "snap": 0.55, "billboard": true, "fade_in": 0.05, "decay": 0.9, "opacity": 0.96, "priority": 1, "ramps": [LEAF, RED]})
		giant.layer("sun", false, MOON, local_mouth, Vector3.ONE * 1.6, Vector3.ZERO, yawn + 0.05, stay - yawn - 0.05, {"initial": 0.1, "grow": 3.0, "travel": moon - mouth + Vector3.DOWN * 0.02 + (moon - mouth).normalized() * 0.3, "snap": 0.55, "roll": 0.4, "billboard": true, "fade_in": 0.05, "decay": 0.9, "opacity": 0.45, "tier": TIER_MID})
		# The stars: one over each trident's spot (the trident falls from it), more round them.
		for k in 4:
			var star := _star_spot(center, frame, radius, k, sky)
			giant.layer("star5", false, MOON, local_mouth, Vector3.ONE * (0.42 if k < 4 else 0.5), Vector3.ZERO, yawn + 0.08 + 0.05 * float(k), _star_life(time, k) - yawn - 0.08 - 0.05 * float(k), {"initial": 0.15, "grow": 4.0, "travel": star - mouth, "snap": 0.42, "roll": 1.5, "billboard": true, "fade_in": 0.04, "decay": 0.86, "priority": 1, "tier": TIER_CORE if k < 3 else TIER_MID, "ramps": [LEAF, RED]})
		for k in count(6):
			var a := float(k) * 2.39996 + 0.4
			var spot: Vector3 = center + frame[1] * sin(a) * radius * 0.7 + frame[0] * cos(a) * radius * 0.45 + Vector3.UP * (sky + 0.4 + 0.5 * fmod(float(k) * 0.618, 1.0))
			giant.layer("star4", true, MOON, local_mouth, Vector3.ONE * (0.3 + 0.08 * float(k % 3)), Vector3.ZERO, yawn + 0.1 + 0.04 * float(k), stay - yawn - 0.3, {"initial": 0.2, "grow": 4.0, "travel": spot - mouth, "snap": 0.5, "roll": 2.0, "billboard": true, "fade_in": 0.04, "decay": 0.85, "opacity": 0.9, "priority": 1, "tier": TIER_DEBRIS})
		# A breath of gold mist from the yawn.
		giant.layer("burst", false, MOON, local_mouth + Vector3.UP * 0.1, Vector3.ONE * h * 0.09, Vector3.ZERO, yawn, 0.45, {"initial": 0.3, "grow": 6.0, "roll": 1.0, "billboard": true, "decay": 0.5, "opacity": 0.85, "priority": 2, "tier": TIER_MID})
	return true


## The sky spot of the star a trident falls from (the fifth is the moon).
static func _star_spot(center: Vector3, frame: Array, radius: float, index: int, sky: float) -> Vector3:
	var at := trident_spot(center, frame[0], frame[1], radius, index)
	return at + Vector3.UP * (sky - (0.2 if index < 4 else -0.1)) + frame[0] * (0.0 if index < 4 else 0.8)


## A star burns until its trident leaves it.
static func _star_life(time: float, index: int) -> float:
	return time + float(HANUMAN_BEATS[index]) - 0.14


## The trident of beat [param index] falls from its star to stake the ground at
## [param land] seconds on [param root]'s clock.
static func _trident_fall(root: MuayThaiArt, root_at: Vector3, center: Vector3, frame: Array, radius: float, index: int, land: float, sky: float) -> void:
	var spot := trident_spot(center, frame[0], frame[1], radius, index)
	var final := index >= 4
	var length := 5.2 if final else 3.8
	var fall := 0.22 if final else 0.16
	var tip := spot + Vector3.UP * (length * 0.5 - 0.35)
	var from := _star_spot(center, frame, radius, index, sky) + Vector3.UP * length * 0.5
	var local := from - root_at
	var hold := 1.25 if final else 0.95
	root.layer("trident", false, LEAF, local, Vector3.ONE * length * 0.5, Vector3.ZERO, land - fall, fall + hold, {"initial": 1.0, "travel": tip - from, "snap": fall, "snap_in": true, "accelerate": true, "point": Vector3.DOWN, "fade_in": 0.03, "decay": 0.82, "priority": 2, "ramps": [LEAF, RED]})
	root.layer("streak", true, MOON, local, Vector3(length * 0.7, length * 0.22, 1.0), Vector3.ZERO, land - fall, fall + 0.1, {"initial": 0.5, "grow": 8.0, "travel": tip - from, "snap": fall, "snap_in": true, "accelerate": true, "point": Vector3.DOWN, "decay": 0.4, "opacity": 0.7, "tier": TIER_MID})


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
	_paint(art, "yant", _lace(RED if final else LEAF), art.to_local(spot + Vector3.UP * 0.05), Vector3.ONE * seal, 1.4 if final else 1.1, {"initial": 0.55, "grow_time": 0.07, "spin": 0.5, "decay": 0.72, "fade_in": 0.01}, false, -1)
	var hit := _open(parent, spot, "RamakienYant_%s_%d" % [id, index], id)
	# The next trident falls from its star (the fifth from the moon) on the next beat.
	if index < 4:
		var gap := float(HANUMAN_BEATS[index + 1]) - float(HANUMAN_BEATS[index])
		_trident_fall(hit, spot, center, frame, radius, index + 1, gap, sky)
	var tip := Vector3.UP * 0.45
	hit.layer("burst", false, SUN, tip + Vector3.UP * 0.3, Vector3.ONE * (2.2 if final else 1.3), Vector3(0, 0, randf() * TAU), 0.0, 0.42, {"initial": 0.3, "grow": 9.0, "roll": 1.2, "billboard": true, "decay": 0.5})
	# อักขระ: the seal's script rises round the trident and glyphs are thrown off.
	hit.layer("script", true, LEAF, Vector3.UP * 0.1, Vector3(seal * 0.55, 1.2, seal * 0.55), Vector3.ZERO, 0.0, 0.9, {"initial": 0.6, "grow": 5.0, "spin": 2.6, "travel": Vector3(0, 1.6, 0), "decay": 0.6, "opacity": 0.85})
	hit.layer("shock", true, SUN, Vector3.UP * 0.06, Vector3.ONE * (radius * 0.75 if final else 2.6), Vector3.ZERO, 0.0, 0.55, {"initial": 0.12, "grow": 4.5, "decay": 0.5})
	if fx.has("kick"):
		hit.layer("dust", true, DUST, Vector3.UP * 0.02, Vector3(1.6, 0.8, 1.6) * (1.6 if final else 1.0), Vector3.ZERO, 0.02, 0.8, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.6, "tier": TIER_MID})
	hit.layer("crack", true, SUN, Vector3.UP * 0.045, Vector3.ONE * (seal * 0.7), Vector3(0, randf() * TAU, 0), 0.0, 1.1, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.9, "tier": TIER_MID})
	hit._glyph_burst(LEAF, Vector3.UP * 0.6, 4 if not final else 6, 0.0)
	hit._sparks(MOON, tip, 5, 0.0, 1.2 if final else 0.9)
	if final:
		# The moon's trident: the seal flares, rings and cones roll out, the pack is stunned.
		hit.layer("yant", false, _lace(LEAF), Vector3.UP * 0.055, Vector3.ONE * seal * 1.25, Vector3.ZERO, 0.04, 1.2, {"initial": 0.5, "grow": 6.0, "overshoot": true, "spin": -0.4, "decay": 0.66, "opacity": 0.8, "tier": TIER_MID})
		hit.layer("shock", true, EMBER, Vector3.UP * 0.07, Vector3.ONE * radius * 1.05, Vector3.ZERO, 0.1, 0.6, {"initial": 0.12, "grow": 4.0, "decay": 0.5, "tier": TIER_MID})
		hit._radial_cones(GOLD, Vector3.ZERO, 8, radius * 0.5, 0.03)
		hit._stun_stars(Vector3.UP * 0.6, 0.05, float(fx.get("stun", 1.5)), 3)
		hit.layer("smoke", true, DUST, Vector3.UP * 0.1, Vector3.ONE * 2.6, Vector3.ZERO, 0.05, 1.2, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 1.4, 0), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": TIER_DEBRIS})
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
	var stay := time + float(beats.back()) + 0.6
	var view := _view(parent, origin, frame[0])
	var away: Vector3 = view[0]
	var base := origin + away * 3.2
	var h := fit_height(parent, base, TITAN, 0.5)
	var up := _up(parent, base)
	var sky := clampf(fit_height(parent, origin, 7.0, 0.4, 0.06) * 0.95, 3.2, 6.5)
	_sets[id] = {"away": away, "base": base, "h": h, "up": up, "sky": sky, "radius": radius}
	# The ground (always): a jade-and-gold ยันต์ seal turning under the fighter, mantra
	# script rising, and the first wave of fists falling on the release.
	var ground := _open(parent, origin, "StarGodGround_" + id, id)
	ground.layer("yant", false, _lace(GREEN), Vector3.UP * 0.04, Vector3.ONE * 3.0, Vector3.ZERO, 0.0, time + 0.35, {"initial": 0.3, "grow": 2.0, "spin": 0.7, "fade_in": 0.2, "decay": 0.82, "opacity": 0.92})
	ground.layer("script", true, LEAF, Vector3.UP * 0.2, Vector3(1.2, 1.2, 1.2), Vector3.ZERO, 0.05, time, {"initial": 0.5, "grow": 2.0, "spin": -2.2, "travel": Vector3(0, 1.8, 0), "fade_in": 0.2, "decay": 0.7, "opacity": 0.75, "tier": TIER_MID})
	ground.layer("yant", false, _lace(LEAF), Vector3.UP * 0.045, Vector3.ONE * 4.4, Vector3.ZERO, 0.15, time + 0.2, {"initial": 0.4, "grow": 2.0, "spin": -0.35, "fade_in": 0.25, "decay": 0.8, "opacity": 0.4, "tier": TIER_MID})
	_fist_wave(ground, origin, 0, time)
	# The sky (no memory pressure): ทศกัณฐ์ itself.
	if GodSkillArt.extra_roots(1) >= 1:
		var giant := _open(parent, base, "StarGodSky_" + id, id)
		var rise := 0.6
		var sink := Vector3.DOWN * h * 0.45
		var g := {"initial": 1.0, "billboard": true, "fade_in": 0.06, "decay": 0.9, "opacity": 0.93, "ramps": THOTSAKAN_RAMPS}
		giant.layer("thotsakan", false, GREEN, sink, Vector3.ONE * h, Vector3.ZERO, 0.0, stay, g.merged({"travel": -sink, "snap": rise}, true))
		# Twenty arms unfurl round the ten heads once it has risen.
		var shoulder := up * h * 0.33
		giant.layer("thotsakan_arms", false, GREEN, shoulder, Vector3.ONE * h, Vector3.ZERO, rise * 0.85, stay - rise * 0.85, g.merged({"initial": 0.25, "grow": 3.2, "overshoot": true, "fade_in": 0.08, "priority": -1}, true))
		giant.layer("cloud", false, CLOUD, -up * 0.1 + Vector3.UP * 0.1, Vector3(h * 0.62, h * 0.4, 1.0), Vector3.ZERO, 0.0, stay, {"initial": 0.4, "grow": 3.0, "overshoot": true, "billboard": true, "fade_in": 0.1, "decay": 0.88, "opacity": 0.95, "priority": 2, "ramps": [LEAF, RED]})
		# A halo of กนก flame behind the heads.
		giant.layer("sun", false, SUN, up * h * 0.72 - away * 0.3, Vector3.ONE * h * 0.3, Vector3.ZERO, rise, stay - rise, {"initial": 0.2, "grow": 2.5, "overshoot": true, "roll": 0.25, "billboard": true, "fade_in": 0.15, "decay": 0.88, "opacity": 0.5, "priority": -2, "tier": TIER_MID})
	return true


## Wave [param wave]'s fists on [param root] (standing at [param root_at]): they fall
## from the giant's side of the sky and land at [param land] on the root's clock.
static func _fist_wave(root: MuayThaiArt, root_at: Vector3, wave: int, land: float) -> void:
	var set: Dictionary = _sets.get(THOTSAKAN_ID, {})
	var away: Vector3 = set.get("away", Vector3.BACK)
	var center: Vector3 = root_at if wave == 0 else set.get("origin", root_at)
	var radius := float(set.get("radius", 9.0))
	var sky := float(set.get("sky", 5.0))
	var n := wave_fists(wave)
	var fall := float(WAVE_FALL[wave])
	for k in n:
		var spot := fist_spot(center, away, radius, wave, k, n)
		var size := 1.12 - 0.05 * float(wave)
		# Knuckles land on the ground: the mesh's knuckles sit 0.72 of its size ahead.
		var to := spot + Vector3.UP * (0.62 * size + 0.1)
		var side := away.cross(Vector3.UP) * (0.9 if k % 2 == 0 else -0.9)
		var from := to + Vector3.UP * sky + away * 2.6 + side
		var dir := (to - from).normalized()
		var lag := 0.025 * float(k % 3)
		root._fist_blow_yak(from - root_at, to - root_at, land - fall + lag, fall, size, 0.22, TIER_CORE, dir)


## A ทศกัณฐ์ fist (jade skin, gold armlet) snapping from [param from] to [param to].
func _fist_blow_yak(from: Vector3, to: Vector3, start: float, snap: float, size: float, hold: float, tier: int, dir: Vector3) -> void:
	layer("fist_yak", false, GREEN, from, Vector3.ONE * size, Vector3.ZERO, start, snap + hold, {"initial": 0.8, "grow": 14.0, "travel": to - from, "snap": snap, "snap_in": true, "accelerate": true, "point": dir, "fade_in": 0.02, "decay": 0.72, "tier": tier, "priority": 1, "ramps": THOTSAKAN_RAMPS})
	layer("streak", true, SUN, from, Vector3(size * 1.5, size * 0.8, 1.0), Vector3.ZERO, start, snap + hold * 0.4, {"initial": 0.5, "grow": 10.0, "travel": to - from, "snap": snap, "snap_in": true, "accelerate": true, "point": dir, "fade_in": 0.02, "decay": 0.35, "opacity": 0.75, "tier": mini(tier + 1, TIER_DEBRIS)})


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
	_paint(art, "shock", GOLD, art.to_local(origin + Vector3.UP * 0.06), Vector3.ONE * radius * (0.45 + 0.1 * float(index)), 0.5, {"initial": 0.15, "grow_time": 0.5, "decay": 0.5, "opacity": 0.6}, true, -1)
	# What comes next first, on its own root (its own cap): the next wave's fists, or
	# after the fourth the fists fusing into the god fist.
	var next := _open(parent, origin, "RamakienFists_%s_%d" % [id, index + 1], id)
	if index < 3:
		_fist_wave(next, origin, index + 1, float(beats[index + 1]) - float(beats[index]))
	else:
		_merge(next, origin, float(beats[4]) - float(beats[3]))
	# This wave's landings: a กนก burst and a star of gold cracks under each fist.
	var hit := _open(parent, origin, "RamakienWave_%s_%d" % [id, index], id)
	for k in n:
		var spot := fist_spot(origin, away, radius, index, k, n) - origin
		hit.layer("burst", false, EMBER if k % 2 else SUN, spot + Vector3.UP * 0.25, Vector3.ONE * 0.75, Vector3(0, 0, randf() * TAU), 0.0, 0.3, {"initial": 0.3, "grow": 9.0, "roll": 1.2, "billboard": true, "decay": 0.45, "priority": 2, "tier": TIER_CORE if k < 2 else (TIER_MID if k < 5 else TIER_DEBRIS)})
		hit.layer("crack", true, SUN, spot + Vector3.UP * 0.04, Vector3.ONE * 1.1, Vector3(0, randf() * TAU, 0), 0.0, 0.8, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.9, "tier": TIER_MID if k < 4 else TIER_DEBRIS})
	return true


## Where the god fist lands, from the fighter: past it and to the side, so the fist
## hanging before it never hides the giant's ten heads.
static func slam_offset(away: Vector3) -> Vector3:
	return away * 1.4 + away.cross(Vector3.UP).normalized() * 2.0


## The last wave's fists fly up and fuse over the slam point into one enormous fist that
## hammers down at [param land] (the finale beat, on [param root]'s clock).
static func _merge(root: MuayThaiArt, origin: Vector3, land: float) -> void:
	var set: Dictionary = _sets.get(THOTSAKAN_ID, {})
	var away: Vector3 = set.get("away", Vector3.BACK)
	var radius := float(set.get("radius", 9.0))
	var slam := slam_offset(away)
	var size := 1.6
	# The god fist comes down on a slant from the giant's side, knuckles first.
	var side := away.cross(Vector3.UP).normalized()
	var aim := (Vector3.DOWN - side * 0.42).normalized()
	# Knuckles reach 0.62 of the size below the pivot, the flame trail 1.45 above.
	var knuckles := slam + Vector3.UP * (0.62 * size + 0.15)
	var room := fit_height(root, origin + slam, 9.0, 0.3, 0.04)
	var lift := clampf(room - 2.2 * size - 0.7, 1.0, 3.4)
	var apex := knuckles - aim * lift
	var gather := 0.03
	var fly := 0.17
	var fused := gather + fly
	var hang := land - 0.11
	# The god fist first (the root's cap keeps the first layers): it hangs a breath over
	# the slam point, then hammers down on the finale beat.
	var held := {"initial": 0.3, "grow": 4.0, "overshoot": true, "travel": -aim * 0.35, "point": aim, "fade_in": 0.03, "decay": 0.99, "ramps": THOTSAKAN_RAMPS}
	root.layer("fist_yak", false, GREEN, apex, Vector3.ONE * size, Vector3.ZERO, fused, hang - fused + 0.02, held.merged({"priority": 1}, true))
	var top := apex - aim * 0.35
	var slam_style := {"initial": 1.0, "travel": knuckles - top, "snap": 0.11, "snap_in": true, "accelerate": true, "point": aim, "decay": 0.75, "ramps": THOTSAKAN_RAMPS}
	root.layer("fist_yak", false, GREEN, top, Vector3.ONE * size, Vector3.ZERO, hang, 0.11 + 0.5, slam_style.merged({"priority": 1}, true))
	# The flash where the fists fuse.
	root.layer("burst", false, SUN, apex + Vector3.UP * 0.3, Vector3.ONE * 1.8, Vector3.ZERO, fused - 0.03, 0.14, {"initial": 0.2, "grow": 10.0, "roll": 1.5, "billboard": true, "decay": 0.4, "priority": 0})
	# A speed streak on the slam, a glint where the fists fused.
	root.layer("streak", true, SUN, top, Vector3(size * 1.8, size * 0.9, 1.0), Vector3.ZERO, hang, 0.22, {"initial": 0.6, "travel": knuckles - top, "snap": 0.11, "snap_in": true, "accelerate": true, "point": aim, "decay": 0.4, "opacity": 0.8, "tier": TIER_MID})
	root.layer("star4", true, MOON, apex, Vector3.ONE * 1.8, Vector3.ZERO, fused - 0.03, 0.2, {"initial": 0.3, "grow": 10.0, "roll": 3.0, "billboard": true, "decay": 0.4, "opacity": 0.8, "priority": 2, "tier": TIER_MID})
	# The last wave's fists fly up from where they landed and fuse.
	var n := wave_fists(3)
	for k in mini(n, 6):
		var spot := fist_spot(origin, away, radius, 3, k, n) - origin + Vector3.UP * 0.8
		var dir := (apex - spot).normalized()
		root.layer("fist_yak", false, GREEN, spot, Vector3.ONE * 0.35, Vector3.ZERO, gather, fly, {"initial": 3.0, "grow": 1.0, "travel": apex - spot, "accelerate": true, "point": dir, "fade_in": 0.05, "decay": 0.8, "priority": 1, "tier": TIER_CORE if k < 2 else TIER_MID, "ramps": THOTSAKAN_RAMPS})


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
	# กระจกสี: gold light cracks the ground into temple glass mosaic (the contact root).
	_paint(art, "mosaic", GLASS, art.to_local(slam + Vector3.UP * 0.05), Vector3.ONE * radius * 0.78, 1.7, {"initial": 0.12, "grow_time": 0.14, "decay": 0.72, "fade_in": 0.02, "opacity": 0.86}, true, -1, [LEAF, RED])
	_paint(art, "crack", LEAF, art.to_local(slam + Vector3.UP * 0.06), Vector3.ONE * radius * 0.7, 1.4, {"initial": 0.2, "grow_time": 0.12, "decay": 0.66}, true, 0)
	var hit := _open(parent, slam, "RamakienSlam_" + id, id)
	hit.layer("burst", false, SUN, Vector3(0, 0.5, 0), Vector3.ONE * 1.5, Vector3.ZERO, 0.0, 0.26, {"initial": 0.3, "grow": 9.0, "roll": 0.8, "billboard": true, "decay": 0.45, "priority": 2})
	hit.layer("shock", true, SUN, Vector3.UP * 0.07, Vector3.ONE * radius * 0.7, Vector3.ZERO, 0.0, 0.6, {"initial": 0.1, "grow": 4.0, "decay": 0.5})
	hit._flames(Vector3.ZERO, radius * 0.55, 6, 0.06, 1.3, 1.0)
	hit._stun_stars(Vector3.UP * 0.3, 0.05, float(fx.get("stun", 1.5)), 3)
	for k in count(4):
		var a := float(k) * 1.7 + 0.4
		hit.layer("smoke", true, DUST, Vector3(sin(a), 0.1, cos(a)) * 1.6, Vector3.ONE * 1.6, Vector3.ZERO, 0.03 + 0.03 * float(k), 1.0, {"initial": 0.3, "grow": 3.0, "travel": Vector3(sin(a) * 1.2, 1.2, cos(a) * 1.2), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": TIER_DEBRIS})
	hit._sparks(SUN, Vector3(0, 0.6, 0), 8, 0.02, 1.8)
	# The avatar (no memory pressure): the ten heads roar; the three realms quake in
	# rings of heaven (gold), earth (jade) and the underworld (red).
	if GodSkillArt.extra_roots(1) >= 1:
		var avatar := _open(parent, origin, "StarGodAvatar_" + id, id)
		var realms := [[GOLD, 0.09, 0.55], [JADE, 0.1, 0.8], [CLOTH, 0.11, 1.05]]
		for k in 3:
			var c: Array = realms[k][0]
			avatar.layer("shock", true, c, slam_offset(away) + Vector3.UP * float(realms[k][1]), Vector3.ONE * radius * float(realms[k][2]), Vector3.ZERO, 0.04 + 0.07 * float(k), 0.55, {"initial": 0.2, "grow": 4.5, "decay": 0.45, "opacity": 0.4, "tier": TIER_CORE if k < 2 else TIER_MID})
		# The ten heads' eyes flash: a ring of glyphs bursts from round the giant.
		var base: Vector3 = set.get("base", origin + away * 3.6)
		var h := float(set.get("h", TITAN))
		var up: Vector3 = set.get("up", Vector3.UP)
		avatar._glyph_burst(LEAF, base - origin + up * h * 0.62, 6, 0.0)
	# The temple (high quality only): shafts of gold light rise from the mosaic.
	if GodSkillArt.extra_roots(2) >= 2:
		var temple := _open(parent, slam, "StarGodTemple_" + id, id)
		for k in count(5):
			var a := float(k) * 2.39996 + 0.3
			temple.layer("ray", true, GOLD, Vector3(sin(a), 0, cos(a)) * radius * (0.2 + 0.08 * float(k)), Vector3(0.8, 4.5, 0.8), Vector3.ZERO, 0.04 * float(k), 1.0, {"initial": 0.3, "grow": 4.0, "fade_in": 0.1, "decay": 0.6, "opacity": 0.35})
		temple._glyph_burst(LEAF, Vector3.UP * 0.8, 6, 0.02)
	return true


## A painted layer on a StarSkillArt root (the contact root a star beat opens): the
## root's own clock and cap, a pooled MuayPaint material swapped in.
static func _paint(art: StarSkillArt, kind: String, c: Array, at: Vector3, size: Vector3, seconds: float, style: Dictionary, glow: bool, priority := 0, ramps: Array = []) -> void:
	if art == null:
		return
	var before := art.layers.size()
	art.add_mesh(figure(kind) if kind in OWN else MuayThaiArt.mesh(kind), "Ramakien_" + kind, {"primary": c[0], "accent": c[1], "shade": c[2]}, at, size, Vector3.ZERO, seconds, style)
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
	if not ramps.is_empty():
		_ramps(mat, ramps)
	node.material_override = mat
	node.tree_exiting.connect(_give.bind([mat]), CONNECT_ONE_SHOT)


# ===========================================================================
# The figures (procedural, painted, shared; XY facing +Z unless noted)
# ===========================================================================

## Builds the figures while a zone loads (SpellSpectacle.warm_geometry), spread over
## frames by [param slicer], for a Muay Thai fighter only: nobody else casts them, and
## the giants are the costliest meshes of the class (about 25 ms each on a desktop).
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_mask_lo = 0.0
	_mask_hi = 0.0
	match kind:
		"hanuman":
			_mask_lo = -0.1
			_mask_hi = 0.06
			_hanuman(st)
		"hanuman_yawn": _hanuman_yawn(st)
		"thotsakan":
			_mask_lo = -0.1
			_mask_hi = 0.06
			_thotsakan(st)
		"thotsakan_arms": _thotsakan_arms(st)
		"trident": _trident(st, Vector2(-1.0, 0.0), Vector2(1.0, 0.0), 1.0, RA)
		"moon": _moon(st)
		"star5": _star5(st)
		"cloud":
			_mask_lo = -0.22
			_mask_hi = -0.02
			_cloud(st)
		"fist_yak": _fist_yak(st)
		"mosaic": _mosaic(st)
	_mask_lo = 0.0
	_mask_hi = 0.0
	# The painted parts share their corners: indexed, a figure keeps about a third of
	# its vertices.
	st.index()
	var mesh := st.commit()
	_own_meshes[kind] = mesh
	return mesh


# --- paint helpers ----------------------------------------------------------
## Ramps (COLOR.b): the layer's palette, the second, the third.
const RA := 0.0
const RB := 0.5
const RC := 1.0


static func _mask(p: Vector2) -> float:
	if _mask_hi <= _mask_lo:
		return 1.0
	return clampf((p.y - _mask_lo) / (_mask_hi - _mask_lo), 0.0, 1.0)


## A filled simple polygon, toned from [param bottom] (low y) to [param top] (high y).
static func _fill_poly(st: SurfaceTool, pts: PackedVector2Array, ramp: float, top: float, bottom := -1.0, z := 0.0) -> void:
	if pts.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		return
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var span := maxf(hi - lo, 0.0001)
	for i in idx:
		var p := pts[i]
		var tone := top if bottom < 0.0 else lerpf(bottom, top, (p.y - lo) / span)
		st.set_color(Color(tone, _mask(p), ramp))
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(p.x, p.y, z))


## A painted part: its dark outline, the body, a shadow on the side away from the light
## (upper left) when [param shade] > 0.
static func _ink(st: SurfaceTool, pts: PackedVector2Array, ramp: float, top: float, bottom := -1.0, line := 0.01, shade := 0.0) -> void:
	if line > 0.0:
		for o in Geometry2D.offset_polygon(pts, line, Geometry2D.JOIN_ROUND):
			_fill_poly(st, o, ramp, 0.0)
	_fill_poly(st, pts, ramp, top, bottom)
	if shade > 0.0:
		var shifted := PackedVector2Array()
		for p in pts:
			shifted.append(p + Vector2(-shade * 0.8, shade))
		var dark := maxf((top if bottom < 0.0 else minf(top, bottom)) - 0.2, 0.3)
		for c in Geometry2D.clip_polygons(pts, shifted):
			_fill_poly(st, c, ramp, dark)


## A superellipse round [param c].
static func _oval(c: Vector2, r: Vector2, n := 24, power := 2.0, tilt := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var cs := cos(a)
		var sn := sin(a)
		var p := Vector2(signf(cs) * pow(absf(cs), 2.0 / power) * r.x, signf(sn) * pow(absf(sn), 2.0 / power) * r.y)
		out.append(c + p.rotated(tilt))
	return out


## A tapered limb along [param pts] with half widths [param w], round-ended.
static func _limb(pts: Array, w: Array) -> PackedVector2Array:
	var n := pts.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, n - 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		left.append((pts[i] as Vector2) + nrm * float(w[i]))
		right.append((pts[i] as Vector2) - nrm * float(w[i]))
	var out := PackedVector2Array(left)
	var t1 := ((pts[n - 1] as Vector2) - (pts[n - 2] as Vector2)).normalized()
	var n1 := Vector2(-t1.y, t1.x)
	for k in range(1, 4):
		var a := PI * float(k) / 4.0
		out.append((pts[n - 1] as Vector2) + (n1 * cos(a) + t1 * sin(a)) * float(w[n - 1]))
	for i in range(n - 1, -1, -1):
		out.append(right[i])
	var t0 := ((pts[1] as Vector2) - (pts[0] as Vector2)).normalized()
	var n0 := Vector2(-t0.y, t0.x)
	for k in range(1, 4):
		var a := PI * float(k) / 4.0
		out.append((pts[0] as Vector2) + (-n0 * cos(a) - t0 * sin(a)) * float(w[0]))
	return out


## A smooth curve through [param pts] (Catmull-Rom), [param per] points per span.
static func _curve(pts: Array, per := 6) -> Array:
	var out: Array = []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / float(per)
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


## A limb along a smooth curve, its half width running [param w0] -> [param w1].
static func _swoop(pts: Array, w0: float, w1: float, per := 6) -> PackedVector2Array:
	var line := _curve(pts, per)
	var w: Array = []
	for i in line.size():
		w.append(lerpf(w0, w1, float(i) / float(maxi(line.size() - 1, 1))))
	return _limb(line, w)


## A กนก leaf / flame tongue from [param base] to [param tip]: swelling, hooked over by
## [param curl] (signed).
static func _leaf(base: Vector2, tip: Vector2, width: float, curl: float, n := 12) -> PackedVector2Array:
	var dir := tip - base
	var length := dir.length()
	dir /= maxf(length, 0.0001)
	var perp := Vector2(-dir.y, dir.x)
	var line: Array = []
	var w: Array = []
	for j in n + 1:
		var t := float(j) / float(n)
		var bend := curl * length * (0.14 * sin(PI * t) + 0.3 * pow(maxf(t - 0.55, 0.0) / 0.45, 2.0))
		line.append(base + dir * length * t + perp * bend)
		w.append(maxf(width * pow(sin(PI * (0.12 + 0.88 * t)), 0.8) * pow(1.0 - t, 0.55), width * 0.04))
	return _limb(line, w)


## A thin painted line (no outline) along [param pts].
static func _line(st: SurfaceTool, pts: Array, w: float, ramp: float, tone: float) -> void:
	var ws: Array = []
	for p in pts:
		ws.append(w)
	_fill_poly(st, _limb(pts, ws), ramp, tone)


static func _mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out


static func _mirror_pts(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		out.append(Vector2(-(p as Vector2).x, (p as Vector2).y))
	return out


## A gem: a gold bezel and a red stone with a glint.
static func _gem(st: SurfaceTool, c: Vector2, r: float) -> void:
	_ink(st, _oval(c, Vector2(r * 1.45, r * 1.45), 12), RB, 0.85, -1.0, r * 0.35)
	_fill_poly(st, _oval(c, Vector2(r, r), 12), RC, 0.62, 0.42)
	_fill_poly(st, _oval(c + Vector2(-r * 0.35, r * 0.35), Vector2(r * 0.3, r * 0.3), 8), RC, 1.0)


## A spiral (a Thai scroll's curl) round [param c].
static func _spiral(c: Vector2, r: float, turns: float, start: float, n := 18, sign := 1.0) -> Array:
	var out: Array = []
	for j in n:
		var t := float(j) / float(n - 1)
		var a := start + sign * t * TAU * turns
		out.append(c + Vector2(cos(a), sin(a)) * r * (1.0 - 0.78 * t))
	return out


# --- หนุมาน -----------------------------------------------------------------
## The white monkey warrior, waist (y 0) to the tip of his crown (y 1), facing the
## viewer in a khon pose: his right hand raised open, his left holding his ตรีเพชร
## upright, the tail curling out low on his right; white with an indigo ink line, a
## ชฎา-pointed crown, ear flames (กรรเจียก), collar, sash, armlets and belt in gold leaf
## and red gems.
static func _hanuman(st: SurfaceTool) -> void:
	# The tail, behind everything: out low on the raised-arm side, curling up.
	var tail := _swoop([Vector2(0.08, 0.05), Vector2(0.26, 0.04), Vector2(0.44, 0.12), Vector2(0.53, 0.28), Vector2(0.53, 0.44), Vector2(0.47, 0.53), Vector2(0.42, 0.5), Vector2(0.43, 0.45)], 0.032, 0.012)
	_ink(st, tail, RA, 0.92, 0.7, 0.011, 0.012)
	_ink(st, _oval(Vector2(0.53, 0.3), Vector2(0.04, 0.013), 12, 3.0, 1.2), RB, 0.9, -1.0, 0.005)
	# The trident he holds, behind his fist.
	_trident(st, Vector2(0.37, -0.12), Vector2(0.37, 0.9), 1.0, RB)
	# The arms behind the torso.
	var raised_upper := _swoop([Vector2(-0.17, 0.34), Vector2(-0.27, 0.39), Vector2(-0.355, 0.43)], 0.05, 0.04)
	var raised_fore := _swoop([Vector2(-0.355, 0.42), Vector2(-0.37, 0.5), Vector2(-0.37, 0.585)], 0.038, 0.03)
	_ink(st, raised_upper, RA, 0.92, 0.72, 0.011, 0.012)
	_ink(st, raised_fore, RA, 0.95, 0.75, 0.011, 0.01)
	var hold_upper := _swoop([Vector2(0.17, 0.34), Vector2(0.27, 0.27), Vector2(0.32, 0.18)], 0.05, 0.04)
	var hold_fore := _swoop([Vector2(0.32, 0.18), Vector2(0.35, 0.24), Vector2(0.37, 0.3)], 0.039, 0.032)
	_ink(st, hold_upper, RA, 0.92, 0.72, 0.011, 0.012)
	_ink(st, hold_fore, RA, 0.95, 0.75, 0.011, 0.01)
	# Armlets and bracelets.
	for s: Array in [[Vector2(-0.275, 0.39), 0.42], [Vector2(-0.37, 0.565), 1.5], [Vector2(0.265, 0.275), -0.65], [Vector2(0.36, 0.27), 1.2]]:
		_ink(st, _oval(s[0], Vector2(0.046, 0.017), 14, 3.0, float(s[1])), RB, 0.85, 0.55, 0.007)
		_gem(st, s[0], 0.008)
	# The open raised hand: palm out, fingers up and curling back (khon).
	_ink(st, _oval(Vector2(-0.372, 0.625), Vector2(0.037, 0.042), 16, 2.3), RA, 0.98, 0.8, 0.01)
	for k in 4:
		var x := -0.395 + 0.016 * float(k)
		var f := _swoop([Vector2(x, 0.645), Vector2(x - 0.004, 0.69), Vector2(x - 0.014 - 0.004 * float(k), 0.715)], 0.0085, 0.006, 4)
		_ink(st, f, RA, 0.97, 0.85, 0.006)
	_ink(st, _swoop([Vector2(-0.345, 0.615), Vector2(-0.325, 0.64), Vector2(-0.318, 0.665)], 0.009, 0.006, 4), RA, 0.97, -1.0, 0.006)
	# The fist round the trident's shaft.
	_ink(st, _oval(Vector2(0.37, 0.32), Vector2(0.04, 0.036), 16, 2.6), RA, 0.97, 0.75, 0.01, 0.008)
	for k in 3:
		_line(st, [Vector2(0.347, 0.338 - 0.016 * float(k)), Vector2(0.392, 0.338 - 0.016 * float(k))], 0.0035, RA, 0.2)
	# The torso: broad shoulders tapering to the waist; under it a red cloth.
	_ink(st, PackedVector2Array([Vector2(-0.14, -0.16), Vector2(0.14, -0.16), Vector2(0.15, 0.0), Vector2(-0.15, 0.0)]), RC, 0.55, 0.4, 0.01)
	var torso := PackedVector2Array([Vector2(-0.135, -0.02), Vector2(0.135, -0.02), Vector2(0.15, 0.1), Vector2(0.19, 0.24), Vector2(0.225, 0.325), Vector2(0.16, 0.38), Vector2(0.06, 0.395), Vector2(-0.06, 0.395), Vector2(-0.16, 0.38), Vector2(-0.225, 0.325), Vector2(-0.19, 0.24), Vector2(-0.15, 0.1)])
	_ink(st, torso, RA, 0.96, 0.78, 0.012, 0.022)
	# Chest and belly lines.
	for s: float in [-1.0, 1.0]:
		_line(st, _curve([Vector2(s * 0.015, 0.31), Vector2(s * 0.08, 0.27), Vector2(s * 0.14, 0.285)], 4), 0.004, RA, 0.45)
	_line(st, [Vector2(0.0, 0.2), Vector2(0.0, 0.08)], 0.003, RA, 0.55)
	# The sash (สังวาล): two gold chains crossing over the chest to a rosette.
	for s: float in [-1.0, 1.0]:
		_ink(st, _limb([Vector2(s * 0.17, 0.36), Vector2(s * 0.06, 0.21), Vector2(-s * 0.1, 0.03)], [0.011, 0.011, 0.011]), RB, 0.9, 0.7, 0.006)
	_ink(st, _star_pts(Vector2(0, 0.205), 0.032, 0.02, 8, 0.0), RB, 0.95, 0.7, 0.007)
	_gem(st, Vector2(0, 0.205), 0.012)
	# The belt: a gold band, its buckle a gem.
	_ink(st, PackedVector2Array([Vector2(-0.15, -0.025), Vector2(0.15, -0.025), Vector2(0.148, 0.03), Vector2(-0.148, 0.03)]), RB, 0.92, 0.6, 0.008)
	for k in 7:
		_gem(st, Vector2(-0.12 + 0.04 * float(k), 0.002), 0.006 if k != 3 else 0.012)
	# The collar (กรองคอ): a scalloped crescent of gold under the chin with red points.
	var collar := PackedVector2Array()
	for k in 25:
		var t := float(k) / 24.0
		var x := lerpf(-0.19, 0.19, t)
		var scallop := 0.012 * absf(sin(t * PI * 9.0))
		collar.append(Vector2(x, 0.37 - 0.085 * sin(PI * t) - scallop))
	for k in 13:
		var t := float(k) / 12.0
		collar.append(Vector2(lerpf(0.085, -0.085, t), 0.405 - 0.035 * sin(PI * t)))
	_ink(st, collar, RB, 0.95, 0.65, 0.01, 0.008)
	for k in 5:
		var t := (float(k) + 0.5) / 5.0
		_gem(st, Vector2(lerpf(-0.14, 0.14, t), 0.36 - 0.07 * sin(PI * t)), 0.007)
	# Shoulder flames (อินทรธนู).
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.16, 0.37), Vector2(s * 0.27, 0.45), 0.028, -s * 0.8, 10), RB, 0.95, 0.65, 0.007)
	_head_hanuman(st)


static func _head_hanuman(st: SurfaceTool) -> void:
	var c := Vector2(0, 0.5)
	# Ear flames (กรรเจียก) behind the head.
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.085, 0.53), Vector2(s * 0.215, 0.66), 0.032, -s * 0.9, 12), RB, 0.96, 0.62, 0.008)
		_ink(st, _leaf(Vector2(s * 0.09, 0.48), Vector2(s * 0.18, 0.43), 0.02, s * 0.8, 10), RB, 0.92, 0.6, 0.007)
		# The monkey's round ear.
		_ink(st, _oval(Vector2(s * 0.108, 0.5), Vector2(0.026, 0.032), 14), RA, 0.9, 0.7, 0.008)
	# The face.
	_ink(st, _oval(c, Vector2(0.104, 0.112), 32, 2.3), RA, 0.97, 0.8, 0.012, 0.016)
	# The muzzle.
	_ink(st, _oval(Vector2(0, 0.452), Vector2(0.068, 0.047), 24, 2.1), RA, 1.0, 0.86, 0.006)
	# Gold mask lines: a crown of curls across the brow, flames on the cheeks.
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.012, 0.545), Vector2(s * 0.088, 0.566), 0.011, s * 0.9, 10), RB, 0.95, 0.65, 0.005)
		_ink(st, _leaf(Vector2(s * 0.06, 0.478), Vector2(s * 0.095, 0.53), 0.01, -s * 0.7, 8), RB, 0.9, 0.6, 0.004)
		# The eye: gold, outlined, a dark pupil and a glint.
		var e := Vector2(s * 0.042, 0.515)
		_ink(st, _oval(e, Vector2(0.026, 0.023), 18), RB, 0.85, 0.65, 0.008)
		_fill_poly(st, _oval(e + Vector2(s * 0.003, -0.002), Vector2(0.011, 0.012), 12), RA, 0.0)
		_fill_poly(st, _oval(e + Vector2(-0.005, 0.006), Vector2(0.004, 0.004), 8), RA, 1.0)
	# The third-eye flame on the brow.
	_ink(st, _leaf(Vector2(0, 0.548), Vector2(0, 0.592), 0.011, 0.5, 8), RC, 0.65, 0.45, 0.005)
	# Nostrils and the closed mouth with its two little fangs.
	for s: float in [-1.0, 1.0]:
		_fill_poly(st, _oval(Vector2(s * 0.012, 0.47), Vector2(0.006, 0.004), 8), RA, 0.05)
		_ink(st, PackedVector2Array([Vector2(s * 0.03, 0.432), Vector2(s * 0.02, 0.432), Vector2(s * 0.025, 0.452)]), RA, 1.0, -1.0, 0.004)
	_line(st, _curve([Vector2(-0.052, 0.442), Vector2(0, 0.428), Vector2(0.052, 0.442)], 6), 0.0045, RA, 0.04)
	_crown(st, Vector2(0, 0.6), 0.105, 0.4, true)


## A ชฎา (a tall pointed crown): a band with a gem and a pointed front over the brow, then
## tiers narrowing up to a spire. [param base] is the band's lower centre.
static func _crown(st: SurfaceTool, base: Vector2, half: float, tall: float, front := true) -> void:
	var tower := PackedVector2Array()
	var steps := 16
	for k in steps + 1:
		var t := float(k) / float(steps)
		tower.append(Vector2(-half * (1.0 - t) * (1.0 - 0.18 * sin(PI * t)) - 0.006, base.y + tall * pow(t, 0.92)))
	for k in range(steps, -1, -1):
		var t := float(k) / float(steps)
		tower.append(Vector2(half * (1.0 - t) * (1.0 - 0.18 * sin(PI * t)) + 0.006, base.y + tall * pow(t, 0.92)))
	_ink(st, tower, RB, 0.95, 0.62, 0.011, 0.012)
	# Tiers (rings bulging out of the tower), each with a gem.
	var rings := 6
	for k in rings:
		var t := 0.12 + 0.6 * float(k) / float(rings - 1)
		var y := base.y + tall * pow(t, 0.92)
		var w := half * (1.0 - t) * (1.0 - 0.18 * sin(PI * t)) + 0.012
		_ink(st, _oval(Vector2(0, y), Vector2(w, 0.012 * (1.0 - 0.4 * t) + 0.004), 18, 3.0), RB, 1.0, 0.6, 0.005)
		if k % 2 == 0:
			_gem(st, Vector2(0, y + 0.002), 0.006 * (1.0 - 0.5 * t))
	# The spire's flame tip.
	_ink(st, _leaf(Vector2(0, base.y + tall * 0.9), Vector2(0.004, base.y + tall * 1.08), 0.012, 0.6, 8), RB, 1.0, 0.7, 0.005)
	# The band round the brow and its pointed front.
	_ink(st, _oval(base + Vector2(0, 0.004), Vector2(half + 0.012, 0.02), 24, 4.0), RB, 0.95, 0.6, 0.008)
	if front:
		_ink(st, PackedVector2Array([base + Vector2(-0.04, -0.012), base + Vector2(0.04, -0.012), base + Vector2(0.0, 0.07)]), RB, 1.0, 0.7, 0.007)
		_gem(st, base + Vector2(0, 0.018), 0.011)
	for s: float in [-1.0, 1.0]:
		_gem(st, base + Vector2(s * half * 0.62, 0.004), 0.007)


## The yawn: his mouth open wide over the muzzle, fangs top and bottom, a red tongue.
static func _hanuman_yawn(st: SurfaceTool) -> void:
	var m := Vector2(0, 0.438)
	_ink(st, _oval(Vector2(0, 0.45), Vector2(0.07, 0.042), 24, 2.1), RA, 1.0, 0.86, 0.006)
	_ink(st, _oval(m, Vector2(0.05, 0.036), 24, 2.2), RC, 0.16, 0.06, 0.008)
	_fill_poly(st, _oval(m + Vector2(0, -0.018), Vector2(0.03, 0.014), 16), RC, 0.55, 0.45)
	for s: float in [-1.0, 1.0]:
		_ink(st, PackedVector2Array([Vector2(s * 0.036, 0.468), Vector2(s * 0.018, 0.468), Vector2(s * 0.027, 0.438)]), RA, 1.0, -1.0, 0.004)
		_ink(st, PackedVector2Array([Vector2(s * 0.034, 0.406), Vector2(s * 0.02, 0.406), Vector2(s * 0.027, 0.428)]), RA, 1.0, -1.0, 0.004)


# --- ทศกัณฐ์ ----------------------------------------------------------------
## The ten-headed king of Lanka, waist (y 0) to the tip of his crown (y 1): a jade-green
## body in a gold breastplate, the main face with its bulging red-rimmed eyes and curled
## fangs, and above it the other nine heads in tiers (four, four and one), each crowned,
## up to a gold spire. The twenty arms are their own piece (thotsakan_arms).
static func _thotsakan(st: SurfaceTool) -> void:
	# Cloth under the belt.
	_ink(st, PackedVector2Array([Vector2(-0.16, -0.16), Vector2(0.16, -0.16), Vector2(0.17, 0.0), Vector2(-0.17, 0.0)]), RC, 0.55, 0.4, 0.01)
	var torso := PackedVector2Array([Vector2(-0.15, -0.02), Vector2(0.15, -0.02), Vector2(0.17, 0.1), Vector2(0.21, 0.24), Vector2(0.24, 0.31), Vector2(0.17, 0.36), Vector2(0.06, 0.375), Vector2(-0.06, 0.375), Vector2(-0.17, 0.36), Vector2(-0.24, 0.31), Vector2(-0.21, 0.24), Vector2(-0.17, 0.1)])
	_ink(st, torso, RA, 0.7, 0.5, 0.012, 0.02)
	# The gold breastplate with rows of scales.
	var plate := PackedVector2Array([Vector2(-0.12, 0.04), Vector2(0.12, 0.04), Vector2(0.16, 0.16), Vector2(0.17, 0.3), Vector2(0.0, 0.33), Vector2(-0.17, 0.3), Vector2(-0.16, 0.16)])
	_ink(st, plate, RB, 0.9, 0.55, 0.009, 0.014)
	for row in 5:
		var y := 0.08 + 0.045 * float(row)
		var n := 5 + row % 2
		for k in n:
			var x := lerpf(-0.11, 0.11, (float(k) + 0.5 * float(row % 2)) / float(n))
			_line(st, _curve([Vector2(x - 0.018, y + 0.012), Vector2(x, y - 0.004), Vector2(x + 0.018, y + 0.012)], 3), 0.0035, RB, 0.35)
	_gem(st, Vector2(0, 0.2), 0.016)
	# Belt.
	_ink(st, PackedVector2Array([Vector2(-0.17, -0.025), Vector2(0.17, -0.025), Vector2(0.168, 0.035), Vector2(-0.168, 0.035)]), RB, 0.92, 0.6, 0.008)
	for k in 7:
		_gem(st, Vector2(-0.135 + 0.045 * float(k), 0.005), 0.007 if k != 3 else 0.013)
	# Collar.
	var collar := PackedVector2Array()
	for k in 25:
		var t := float(k) / 24.0
		collar.append(Vector2(lerpf(-0.2, 0.2, t), 0.355 - 0.075 * sin(PI * t) - 0.012 * absf(sin(t * PI * 9.0))))
	for k in 13:
		var t := float(k) / 12.0
		collar.append(Vector2(lerpf(0.085, -0.085, t), 0.39 - 0.03 * sin(PI * t)))
	_ink(st, collar, RB, 0.95, 0.65, 0.01, 0.008)
	for k in 5:
		var t := (float(k) + 0.5) / 5.0
		_gem(st, Vector2(lerpf(-0.15, 0.15, t), 0.345 - 0.062 * sin(PI * t)), 0.007)
	# Shoulder flames (อินทรธนู), over the roots of the twenty arms.
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.13, 0.35), Vector2(s * 0.3, 0.42), 0.045, -s * 0.8, 12), RB, 0.95, 0.62, 0.008, 0.008)
		_ink(st, _leaf(Vector2(s * 0.15, 0.32), Vector2(s * 0.29, 0.31), 0.03, s * 0.6, 10), RB, 0.9, 0.6, 0.007)
	# The nine heads in tiers, back to front, then the main face over them.
	_crown(st, Vector2(0, 0.8), 0.05, 0.19, false)
	_small_face(st, Vector2(0, 0.79), 0.035)
	for k in [0, 3, 1, 2]:
		_small_face(st, Vector2(-0.081 + 0.054 * float(k), 0.72), 0.034)
	_ink(st, _oval(Vector2(0, 0.69), Vector2(0.11, 0.014), 24, 4.0), RB, 0.95, 0.6, 0.007)
	for k in [0, 3, 1, 2]:
		_small_face(st, Vector2(-0.102 + 0.068 * float(k), 0.637), 0.038)
	_ink(st, _oval(Vector2(0, 0.6), Vector2(0.125, 0.016), 24, 4.0), RB, 0.95, 0.6, 0.008)
	for k in 5:
		_gem(st, Vector2(-0.09 + 0.045 * float(k), 0.6), 0.006)
	_main_face(st)


static func _main_face(st: SurfaceTool) -> void:
	var c := Vector2(0, 0.48)
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.085, 0.52), Vector2(s * 0.2, 0.6), 0.03, -s * 0.9, 12), RB, 0.96, 0.62, 0.008)
		_ink(st, _leaf(Vector2(s * 0.09, 0.46), Vector2(s * 0.17, 0.4), 0.022, s * 0.8, 10), RB, 0.92, 0.6, 0.007)
	_ink(st, _oval(c, Vector2(0.1, 0.11), 32, 2.6), RA, 0.68, 0.5, 0.012, 0.016)
	# Gold brow band of curls.
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(Vector2(s * 0.01, 0.53), Vector2(s * 0.095, 0.56), 0.013, s * 0.9, 10), RB, 0.95, 0.65, 0.005)
		# Bulging eye: a red rim, pale ball, dark pupil, glint; a heavy angry brow.
		var e := Vector2(s * 0.044, 0.497)
		_ink(st, _oval(e, Vector2(0.03, 0.027), 18), RC, 0.55, 0.4, 0.007)
		_fill_poly(st, _oval(e, Vector2(0.022, 0.02), 16), RB, 1.0)
		_fill_poly(st, _oval(e + Vector2(s * 0.002, 0.0), Vector2(0.009, 0.01), 12), RA, 0.0)
		_fill_poly(st, _oval(e + Vector2(-0.004, 0.005), Vector2(0.0035, 0.0035), 8), RB, 1.0)
		_fill_poly(st, _limb([Vector2(s * 0.012, 0.515), Vector2(s * 0.045, 0.53), Vector2(s * 0.078, 0.522)], [0.006, 0.01, 0.005]), RA, 0.05)
		# Curled fangs (เขี้ยวแก้ว) rising from the corners of the mouth.
		_ink(st, _leaf(Vector2(s * 0.05, 0.43), Vector2(s * 0.085, 0.475), 0.012, -s * 0.9, 8), RB, 1.0, 0.85, 0.005)
	# Nose and the wide snarling mouth: a dark red band with a row of teeth.
	_ink(st, _oval(Vector2(0, 0.465), Vector2(0.022, 0.014), 14), RA, 0.8, 0.6, 0.005)
	var mouth := _oval(Vector2(0, 0.43), Vector2(0.06, 0.018), 24, 3.0)
	_ink(st, mouth, RC, 0.25, 0.1, 0.007)
	for k in 6:
		var x := -0.045 + 0.018 * float(k)
		_fill_poly(st, PackedVector2Array([Vector2(x - 0.007, 0.444), Vector2(x + 0.007, 0.444), Vector2(x, 0.432)]), RB, 1.0)
	_ink(st, _oval(Vector2(0, 0.4), Vector2(0.03, 0.01), 12), RA, 0.6, -1.0, 0.004)


## One of the nine smaller heads: a jade face, a gold crown band, two eyes and fangs.
static func _small_face(st: SurfaceTool, c: Vector2, r: float) -> void:
	_ink(st, _oval(c, Vector2(r, r * 1.08), 20, 2.4), RA, 0.66, 0.5, r * 0.22, r * 0.18)
	_ink(st, _oval(c + Vector2(0, r * 0.88), Vector2(r * 0.95, r * 0.26), 16, 3.0), RB, 0.95, 0.65, r * 0.12)
	_ink(st, PackedVector2Array([c + Vector2(-r * 0.45, r * 1.02), c + Vector2(r * 0.45, r * 1.02), c + Vector2(0, r * 1.55)]), RB, 1.0, 0.7, r * 0.12)
	for s: float in [-1.0, 1.0]:
		var e := c + Vector2(s * r * 0.42, r * 0.15)
		_fill_poly(st, _oval(e, Vector2(r * 0.27, r * 0.24), 12), RC, 0.5)
		_fill_poly(st, _oval(e, Vector2(r * 0.2, r * 0.17), 12), RB, 1.0)
		_fill_poly(st, _oval(e, Vector2(r * 0.09, r * 0.1), 8), RA, 0.0)
		_fill_poly(st, _limb([c + Vector2(s * r * 0.15, r * 0.45), c + Vector2(s * r * 0.7, r * 0.38)], [r * 0.09, r * 0.06]), RA, 0.05)
		_fill_poly(st, _leaf(c + Vector2(s * r * 0.45, -r * 0.48), c + Vector2(s * r * 0.75, -r * 0.1), r * 0.14, -s * 0.8, 6), RB, 1.0)
	_fill_poly(st, _oval(c + Vector2(0, -r * 0.48), Vector2(r * 0.55, r * 0.18), 14, 3.0), RC, 0.2)


## The twenty arms (ten a side) fanned out round the heads like an aureole, pivoting at
## the shoulders (y 0 here: the piece stands at the giant's shoulder height); each arm
## jade with gold armlet and bracelet, ending in a fist.
static func _thotsakan_arms(st: SurfaceTool) -> void:
	for k in range(9, -1, -1):
		for s: float in [-1.0, 1.0]:
			var t := float(k) / 9.0
			var a := lerpf(-0.22, 1.3, t)
			var sh := Vector2(s * 0.15, 0.0)
			var elbow := sh + Vector2(s * cos(a - 0.22), sin(a - 0.22)) * 0.235
			var wrist := elbow + Vector2(s * cos(a + 0.16), sin(a + 0.16)) * 0.225
			# Alternate arms a shade apart, so the fan reads arm by arm.
			var tone := (0.62 if k % 2 == 0 else 0.5) - 0.06 * t
			_ink(st, _swoop([sh, sh.lerp(elbow, 0.5), elbow], 0.027, 0.022, 3), RA, tone, tone - 0.14, 0.008)
			_ink(st, _swoop([elbow, elbow.lerp(wrist, 0.5), wrist], 0.021, 0.016, 3), RA, tone + 0.05, tone - 0.1, 0.008)
			var fore := (wrist - elbow).normalized()
			var across := fore.orthogonal() * s
			_ink(st, _oval(elbow.lerp(sh, 0.3), Vector2(0.028, 0.011), 12, 3.0, (elbow - sh).angle() + PI * 0.5), RB, 0.9, -1.0, 0.005)
			# A gold bracelet, then the fist: a squared block of folded fingers with four
			# outlined knuckles along its front and the thumb across.
			_ink(st, _oval(wrist, Vector2(0.026, 0.011), 12, 3.0, fore.angle() + PI * 0.5), RB, 0.95, 0.7, 0.005)
			var f := wrist + fore * 0.035
			_ink(st, _oval(f, Vector2(0.036, 0.034), 18, 3.4, fore.angle()), RA, tone + 0.14, tone, 0.008, 0.006)
			for j in 4:
				var kn := f + fore * 0.026 + across * (0.026 - 0.0175 * float(j))
				_ink(st, _oval(kn, Vector2(0.011, 0.0095), 10, 2.2, fore.angle()), RA, tone + 0.24, tone + 0.1, 0.004)
			_ink(st, _limb([f - across * 0.03 - fore * 0.012, f - across * 0.012 + fore * 0.012], [0.009, 0.008]), RA, tone + 0.2, -1.0, 0.004)


# --- ตรีเพชร, moon, star, clouds, fist, glass ---------------------------------
## The ตรีเพชร (Hanuman's trident) from [param from] (the pommel) to [param to] (the
## tip of the centre blade): a gold shaft with knots, an ornate collar with a red
## tassel, a leaf blade and two flame-hooked side prongs. [param scale] widens it.
static func _trident(st: SurfaceTool, from: Vector2, to: Vector2, scale: float, ramp: float) -> void:
	var axis := (to - from)
	var length := axis.length()
	axis /= length
	var side := Vector2(-axis.y, axis.x)
	var at := func(t: float, s := 0.0) -> Vector2: return from + axis * length * t + side * s * length
	var w := 0.021 * length * scale
	# The shaft.
	_ink(st, _limb([at.call(0.02), at.call(0.64)], [w * 0.9, w]), ramp, 0.85, 0.6, w * 0.6)
	for t in [0.18, 0.36, 0.52]:
		_ink(st, _oval(at.call(t), Vector2(w * 1.8, w * 0.9), 12, 3.0, axis.angle() + PI * 0.5), ramp, 0.95, -1.0, w * 0.4)
	# Pommel.
	_ink(st, _star_pts(at.call(0.015), w * 2.2, w * 1.2, 6, axis.angle()), ramp, 0.95, 0.7, w * 0.5)
	# The red tassel hanging off the collar.
	for s: float in [-1.0, 1.0]:
		_ink(st, _leaf(at.call(0.645, s * 0.012), at.call(0.5, s * 0.075), w * 1.3, s * 0.5, 8), RC, 0.6, 0.4, w * 0.4)
	# The side prongs: curved blades flaring out from the collar, their tips flicked
	# outward like กนก flames.
	for s: float in [-1.0, 1.0]:
		var prong := _swoop([at.call(0.66, s * 0.015), at.call(0.7, s * 0.07), at.call(0.77, s * 0.1), at.call(0.86, s * 0.105), at.call(0.92, s * 0.135)], w * 1.5, w * 0.15, 4)
		_ink(st, prong, ramp, 0.95, 0.65, w * 0.6, w * 0.4)
	# The centre blade: a long leaf.
	_ink(st, _leaf(at.call(0.64), at.call(1.0), w * 2.7, 0.0, 12), ramp, 1.0, 0.7, w * 0.6, w * 0.5)
	_line(st, [at.call(0.69), at.call(0.96)], w * 0.28, ramp, 0.45)
	# The collar: a lotus-bud knot with a gem.
	_ink(st, _oval(at.call(0.655), Vector2(w * 2.6, w * 1.7), 16, 2.2, axis.angle()), ramp, 1.0, 0.7, w * 0.55)
	_gem(st, at.call(0.655), w * 0.85)


## A five-point star (XY, radius 1): outlined pale gold, a glint.
static func _star5(st: SurfaceTool) -> void:
	_ink(st, _star_pts(Vector2.ZERO, 1.0, 0.46, 5, PI * 0.5), RA, 0.95, 0.62, 0.11, 0.08)
	_fill_poly(st, _star_pts(Vector2(-0.05, 0.06), 0.42, 0.2, 5, PI * 0.5), RA, 1.0)


static func _star_pts(c: Vector2, outer: float, inner: float, n: int, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n * 2:
		var a := rot + PI * float(k) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * (outer if k % 2 == 0 else inner))
	return out


## A crescent moon (XY, radius 1), opening to the upper right, outlined, a soft halo.
static func _moon(st: SurfaceTool) -> void:
	var disc := _oval(Vector2.ZERO, Vector2(1.0, 1.0), 48)
	var bite := _oval(Vector2(0.42, 0.3), Vector2(0.86, 0.86), 48)
	for c in Geometry2D.clip_polygons(disc, bite):
		_ink(st, c, RA, 1.0, 0.72, 0.08, 0.1)


## Gold clouds (เมฆ ลายไทย) in a band (x -1..1, y about -0.2..0.3): round lobes each
## with a scroll curl, outlined, fading out at their foot.
static func _cloud(st: SurfaceTool) -> void:
	var lobes := [[-0.82, 0.02, 0.17], [0.84, 0.03, 0.16], [-0.58, 0.07, 0.21], [0.6, 0.08, 0.2], [-0.3, 0.1, 0.22], [0.32, 0.1, 0.22], [0.0, 0.12, 0.24]]
	for lobe in lobes:
		var c := Vector2(float(lobe[0]), float(lobe[1]))
		var r := float(lobe[2])
		var shape := _oval(c, Vector2(r, r * 0.82), 28)
		_ink(st, shape, RA, 0.95, 0.6, 0.02, 0.03)
		var sign := 1.0 if c.x <= 0.0 else -1.0
		var curl := _spiral(c + Vector2(0, r * 0.05), r * 0.62, 1.3, PI * 0.9, 20, sign)
		_line(st, curl, r * 0.06, RB, 0.75)
	_fill_poly(st, PackedVector2Array([Vector2(-1.0, -0.22), Vector2(1.0, -0.22), Vector2(1.0, 0.0), Vector2(-1.0, 0.0)]), RA, 0.8)


## The ทศกัณฐ์ fist: MuayThaiArt's painted fist with jade skin and gold metal (its
## brightest tones move to the second ramp).
static func _fist_yak(st: SurfaceTool) -> void:
	var tmp := SurfaceTool.new()
	tmp.begin(Mesh.PRIMITIVE_TRIANGLES)
	_fist_hero(tmp)
	var arrays := tmp.commit_to_arrays()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for k in verts.size():
		var c := colors[k]
		# The flame trail (behind the wrist) turns gold; the duster and cuff too.
		if c.r >= 0.84 or verts[k].x < -0.8:
			c.b = RB
		st.set_color(c)
		st.set_normal(normals[k])
		st.add_vertex(verts[k])


## Temple glass mosaic (กระจกสี) on the ground (XZ, radius 1): rings of jade, red and
## gold glass pieces set in glowing gold seams, cracks of light running out from the
## heart, fading at the rim.
static func _mosaic(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var rings := [0.0, 0.14, 0.3, 0.48, 0.66, 0.84, 1.0]
	var counts := [5, 9, 14, 19, 24, 28]
	var ground := func(p: Vector2, y: float, c: Color) -> void:
		st.set_color(c)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, y, p.y))
	var fade := func(r: float) -> float: return 1.0 - smoothstep(0.7, 1.0, r)
	# The gold bed (the seams).
	for k in 48:
		var a0 := TAU * float(k) / 48.0
		var a1 := TAU * float(k + 1) / 48.0
		ground.call(Vector2.ZERO, 0.0, Color(1.0, 1.0, RB))
		ground.call(Vector2(sin(a1), cos(a1)), 0.0, Color(0.8, 0.0, RB))
		ground.call(Vector2(sin(a0), cos(a0)), 0.0, Color(0.8, 0.0, RB))
	for j in counts.size():
		var r0 := float(rings[j])
		var r1 := float(rings[j + 1])
		var n := int(counts[j])
		var turn := rng.randf() * TAU
		for k in n:
			var a0 := turn + TAU * float(k) / float(n)
			var a1 := turn + TAU * float(k + 1) / float(n)
			var corners := [Vector2(sin(a0), cos(a0)) * r0, Vector2(sin(a0), cos(a0)) * r1, Vector2(sin(a1), cos(a1)) * r1, Vector2(sin(a1), cos(a1)) * r0]
			var mid := Vector2.ZERO
			for p in corners:
				mid += p
			mid /= 4.0
			var gap := 0.011
			var cell: Array = []
			for p in corners:
				var q: Vector2 = p
				q = q + (mid - q).normalized() * gap
				cell.append(q + Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.01, 0.01)))
			var pick := rng.randf()
			var ramp := RA if pick < 0.5 else (RC if pick < 0.78 else RB)
			var tone := rng.randf_range(0.45, 0.75)
			var m := fade.call(mid.length()) as float
			var y := 0.003
			var c0 := Color(tone + 0.2, m, ramp)
			var c1 := Color(tone, m, ramp)
			if j == 0:
				ground.call(cell[1], y, c1)
				ground.call(cell[2], y, c1)
				ground.call(mid * 0.4, y, c0)
				continue
			ground.call(cell[0], y, c0)
			ground.call(cell[2], y, c1)
			ground.call(cell[1], y, c1)
			ground.call(cell[0], y, c0)
			ground.call(cell[3], y, c0)
			ground.call(cell[2], y, c1)
			# A glint across the glass.
			var g0: Vector2 = (cell[0] as Vector2).lerp(cell[2], 0.3)
			var g1: Vector2 = (cell[0] as Vector2).lerp(cell[2], 0.42)
			var g2: Vector2 = (cell[3] as Vector2).lerp(cell[1], 0.5)
			ground.call(g0, y + 0.001, Color(1.0, m * 0.8, ramp))
			ground.call(g2, y + 0.001, Color(1.0, m * 0.8, ramp))
			ground.call(g1, y + 0.001, Color(1.0, m * 0.8, ramp))
	# Cracks of light running out from the heart.
	for b in 9:
		var a := TAU * float(b) / 9.0 + rng.randf_range(-0.2, 0.2)
		var prev := Vector2.ZERO
		for s in 6:
			var t := float(s + 1) / 6.0
			var aa := a + rng.randf_range(-0.18, 0.18)
			var p := Vector2(sin(aa), cos(aa)) * t * rng.randf_range(0.85, 1.0)
			var dir := (p - prev).normalized()
			var side := Vector2(-dir.y, dir.x) * lerpf(0.03, 0.006, t)
			var m := fade.call(p.length()) as float
			ground.call(prev - side, 0.006, Color(1.0, 1.0, RB))
			ground.call(p + side, 0.006, Color(1.0, m, RB))
			ground.call(p - side, 0.006, Color(1.0, m, RB))
			ground.call(prev - side, 0.006, Color(1.0, 1.0, RB))
			ground.call(prev + side, 0.006, Color(1.0, 1.0, RB))
			ground.call(p + side, 0.006, Color(1.0, m, RB))
			prev = p
