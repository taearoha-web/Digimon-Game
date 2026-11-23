class_name MuayThaiArt
extends NaturalArt
## The Muay Thai fighter's (นักมวยประเจียด) art: each of its 22 skills gets its own
## composition of Thai boxing made visible, one hero shape per skill with its supporting
## layers under it, growing with the line's stage (base < Lv.60 < Lv.90/100):
##   fists       a painted knuckle-duster fist (outlined, cel-shaded, wrapped wrist,
##               กนก flame trail) snaps to the foe and squashes on the blow; a กนก burst,
##               a rising sun of flame petals behind the giant fist of หมัดสุริยัน
##   elbows      a whirling crescent; ศอกฟ้าผ่า's outlined gold thunderbolts and a
##               ยันต์ seal flashing under the foe, glowing cracks
##   rings       ประเจียด rings of red cloth bound in gold fly out with cloth ribbons,
##               mantra glyphs, a ยันต์ seal turning underfoot
##   kicks       shockwave cones, rolling shock rings, a seal stamped into the earth
##   spins       crescent sweeps, a wall of fire, กนก flame tongues, a fire dragon
##   rituals     ไหว้ครู: a seal, rising script, a lotus, the มงคล headband descending
##   guard       a dome of hex and กนก-petal facets, iron for ประเจียดเหล็ก
##   ultimates   หมัดพันวง: the rings bind a giant fist; ราชันมวยไทย: every ring and a
##               gold-and-jade dragon fall from the sky, the king's fist crashes down
## Painted, not additive: MuayPaint (shaders/muay_paint.gdshader) keeps the class's gold,
## ember, deep red and jade on a sunny field ("ink" pieces are a three-tone cel ramp
## with a dark outline, "light" pieces luminous paint); only a few small hot sparks add
## light. Shared meshes built once per kind (procedural, no textures); the layer
## materials come from a static pool and go back to it when the cast ends (no material
## per layer per cast); every layer is budgeted (VfxBudget), capped by quality and
## memory pressure (layer_cap) and tiered (core / mid / debris, NaturalArt.depth).
## A few pieces are borrowed (LordSkillArt pillar, CasterArt smoke / dust / crater /
## scorch / ray). Cosmetic only: it never selects victims, deals damage or
## changes timing.

const PAINT := preload("res://shaders/muay_paint.gdshader")
const KINDS := "shock fist_hero burst sun zap kanok streak star4 punch_ring crack prajiad ribbon yant script glyph cone fire_wall sweep dragon lotus dome headband band halo"
const LORD_KINDS := ["pillar"]
const CASTER_KINDS := ["smoke", "dust", "crater", "scorch", "ray"]
## [primary, accent, shade]. Ink pieces run shade (outline) -> primary (body) -> accent
## (highlight); light pieces primary -> accent. Rich and saturated: no white.
const GOLD := [Color("f2a114"), Color("ffe9a0"), Color("6a2a04")]
const EMBER := [Color("f0521a"), Color("ffcf6a"), Color("5a0e06")]
const SUN := [Color("ffb424"), Color("fff4c4"), Color("b8420c")]
const BOLT := [Color("ffbf1c"), Color("fff8d6"), Color("6a3204")]
const JADE := [Color("17b583"), Color("d4ffee"), Color("053a2a")]
## The painted fist: ember-orange flesh of fire, a gold knuckle-duster, a maroon outline.
const FIST := [Color("f2501a"), Color("ffd96e"), Color("3a0603")]
## ประเจียด cloth: deep red bound in gold.
const CLOTH := [Color("d4241a"), Color("ffcf48"), Color("3e0604")]
const IRON := [Color("7c899b"), Color("fff0c8"), Color("1c222c")]
const FLAME := [Color("ff5a12"), Color("ffd24c"), Color("5a0a04")]
## The king's dragon: gold scales, jade in its shadows and rim.
const DRAGON_GOLD := [Color("eaa216"), Color("fff2b4"), Color("0b5a42")]
const LOTUS := [Color("ffad3a"), Color("fff0c8"), Color("8a2208")]
const DUST := [Color("c9b08a"), Color("f2e4c8"), Color("6a5a44")]
const SCORCH := [Color("3a1a0c"), Color("ff6a1e"), Color("140806")]
const CONTACT_GAP_MS := 90
## The fighter's leading fist (hero-local, facing +Z) and a struck body's height.
const HAND := Vector3(0.22, 1.05, 0.42)
const HIT := Vector3(0, 1.0, 0)
## Where หมัดพันวง's rings close into a circle over the fighter's lead shoulder (hero-local)
## and its giant fist leaves from.
const RING_GATHER := Vector3(1.0, 2.4, 0.5)
## Stage of each skill in its line's growth: 0 base, 1 the Lv.60 evolution, 2 the top.
const TIER := {
	"jab_cross": 0, "flame_hook": 1, "sun_fist": 2, "back_elbow": 0, "flying_knee": 1, "thunder_elbow": 2,
	"ring_throw": 0, "twin_rings": 1, "mantra_storm": 2, "push_kick": 0, "body_throw": 1, "earth_kick": 2,
	"sweep_kick": 0, "flame_ring_spin": 1, "fire_dragon_circle": 2, "wai_khru": 0, "ram_muay": 1,
	"sacred_mongkhon": 2, "ring_guard": 0, "iron_prajiad": 1, "thousand_ring_fist": 1, "muay_king": 2}
## How hot each light piece runs (a scale on COLOR.r): the bodies keep their palette
## colour and only the cores reach the accent. Ink pieces are authored in tones.
const TONE := {"star4": 0.8, "punch_ring": 0.65, "crack": 0.8,
	"script": 0.7, "glyph": 0.75, "cone": 0.5, "fire_wall": 0.8, "sweep": 0.6, "streak": 0.8,
	"band": 0.6, "halo": 0.5, "shock": 0.6}
## Materials kept for reuse per shader (MuayPaint, the additive spark light).
const POOL_MAX := 96
static var _meshes: Dictionary = {}
static var _pool: Dictionary = {}
static var _last_contact: Dictionary = {}
## What the last composition asked for and drew (tests, probes).
static var last := {"id": "", "asked": 0, "drawn": 0}
var _away := Vector3(0, 0, -1)
var _asked := 0


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and not skill.has("star") and SkillShow.family_of(skill) == "muaythai"


## The fighter's art owns the core of its skills' show (SkillShow.play, SkillTableau.contact
## and ClassFlourish.contact skip the generic silhouette, finish, cuts and fragments);
## off for side-by-side reviews.
static var enabled := true


static func owns(skill: Dictionary) -> bool:
	return enabled and handles(skill)


static func tier_of(skill: Dictionary) -> int:
	return int(TIER.get(String(skill.get("id", "")), 0))


static func layer_cap() -> int:
	return maxi(4, int([6, 12, 20][VfxBudget.quality()] * MemoryGuard.effect_scale()))


func _sculpture(kind: String) -> ArrayMesh:
	return mesh(kind)


## One layer (SculptureArt.layer's contract: a shared sculpture, its own clock, budgeted
## and capped, tiered by NaturalArt.depth) in a pooled MuayPaint material: [param glow]
## picks the luminous paint over the cel ink. Extra style keys:
##   add: additive light instead of paint (small hot sparks only);
##   snap (s): the travel lands in that time (a blow's snap) and holds, with a squash pop;
##   point (Vector3): a billboard turned so its +X runs along that direction on screen
##     (a fist's knuckles lead its flight from any camera);
##   billboard: faces the camera fully (pitch too), rolled by angles.z / roll.
func layer(kind: String, glow: bool, c: Array, at: Vector3, size: Vector3, angles := Vector3.ZERO, start := 0.0, seconds := 1.0, style := {}) -> void:
	_asked += 1
	if int(style.get("tier", TIER_CORE)) > depth():
		return
	if layers.size() >= cap or not VfxBudget.can_decorate(1 + RESERVE):
		return
	if kind == "shock" and not style.has("opacity"):
		style = style.merged({"opacity": 0.6})
	var add := bool(style.get("add", false))
	var node := MeshInstance3D.new()
	node.name = kind.capitalize()
	node.mesh = _sculpture(kind)
	var mat := _take(GLOW if add else PAINT)
	# Draw order among the translucent pieces (RamakienArt's giants: arms, body, mouth,
	# clouds); pooled materials are reset every time.
	mat.render_priority = int(style.get("priority", 0))
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", float(style.get("opacity", 0.9 if glow else 0.95)))
	mat.set_shader_parameter("fade", 0.0)
	mat.set_shader_parameter("age", 0.0)
	if not add:
		mat.set_shader_parameter("glow", 1.0 if glow else 0.0)
		if style.has("ramps"):
			# A figure's second and third colour ramps (COLOR.b, MuayPaint).
			_ramps(mat, style.ramps)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	VfxBudget.track_decoration(node)
	layers.append({"node": node, "mat": mat, "at": at, "size": size, "angles": angles, "start": start, "seconds": maxf(seconds, 0.05), "style": style})
	lifetime = maxf(lifetime, start + seconds + 0.02)


## Sets the second and third ramps ([param ramps]: [[primary, accent, shade] x2]).
static func _ramps(mat: ShaderMaterial, ramps: Array) -> void:
	for k in mini(ramps.size(), 2):
		var r: Array = ramps[k]
		var suffix := "_b" if k == 0 else "_c"
		mat.set_shader_parameter("primary" + suffix, r[0])
		mat.set_shader_parameter("accent" + suffix, r[1])
		mat.set_shader_parameter("shade" + suffix, r[2])


static func _take(shader: Shader) -> ShaderMaterial:
	var free: Array = _pool.get(shader, [])
	if not free.is_empty():
		return free.pop_back()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## A root tied to a running star cast (RamakienArt): when that StarSkillSequence ends
## before [member cast_until] (the hero died or left mid-cast), the whole root fades out
## within CLOSE seconds instead of playing on over nobody's fight.
const CLOSE := 0.3
var cast_ref: WeakRef
var cast_until := 0.0
var _closing := -1.0


func _process(delta: float) -> void:
	if cast_ref != null and _closing < 0.0 and age < cast_until and not is_instance_valid(cast_ref.get_ref()):
		_closing = age
		lifetime = minf(lifetime, age + CLOSE)
	super._process(delta)


## The cast is over: its materials go back to the pool for the next one.
func _exit_tree() -> void:
	var mats: Array = []
	for data in layers:
		mats.append(data.mat)
	_give(mats)
	layers.clear()


func _draw() -> void:
	super._draw()
	if _closing >= 0.0:
		var k := clampf(1.0 - (age - _closing) / CLOSE, 0.0, 1.0)
		for data in layers:
			var mat: ShaderMaterial = data.mat
			mat.set_shader_parameter("fade", float(mat.get_shader_parameter("fade")) * k)
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	for data in layers:
		var node: MeshInstance3D = data.node
		if not node.visible:
			continue
		var style: Dictionary = data.style
		var local := age - float(data.start)
		if style.has("snap"):
			# The travel lands in [snap] seconds (ease-out cubic) and holds; then the
			# blow's squash pop.
			var t := clampf(local / float(data.seconds), 0.0, 1.0)
			var was := t * t if bool(style.get("accelerate", false)) else 1.0 - pow(1.0 - t, 2.0)
			var snap := maxf(float(style.snap), 0.01)
			var k := clampf(local / snap, 0.0, 1.0)
			# snap_in: the travel accelerates into the landing (a fall, a slam).
			var eased := k * k * k if bool(style.get("snap_in", false)) else 1.0 - pow(1.0 - k, 3.0)
			node.position += (style.get("travel", Vector3.ZERO) as Vector3) * (eased - was)
			if local > snap:
				node.scale *= 1.0 + 0.2 * exp(-16.0 * (local - snap)) * sin(minf((local - snap) * 22.0, PI))
		if camera == null or not (style.has("point") or style.has("billboard")):
			continue
		var eye := global_basis.inverse() * (camera.global_position - node.global_position)
		if eye.length_squared() < 0.0001:
			continue
		var z := eye.normalized()
		var x: Vector3
		if style.has("point"):
			var aim: Vector3 = style.point
			x = aim - z * aim.dot(z)
			if x.length_squared() < 0.02 * aim.length_squared():
				x = Vector3.UP - z * z.y
		else:
			x = Vector3.UP.cross(z)
		if x.length_squared() < 0.000001:
			continue
		x = x.normalized()
		var y := z.cross(x).normalized()
		var roll := node.rotation.z if style.has("billboard") else 0.0
		if roll != 0.0:
			var xr := x * cos(roll) + y * sin(roll)
			y = y * cos(roll) - x * sin(roll)
			x = xr
		var s := node.scale
		node.basis = Basis(x * s.x, y * s.y, z * s.z)


static func _root(parent: Node3D, at: Vector3, label: String, yaw := 0.0) -> MuayThaiArt:
	var art := MuayThaiArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	art.rotation.y = yaw
	var camera := parent.get_viewport().get_camera_3d()
	if camera:
		var to_camera := camera.global_position - at
		to_camera.y = 0.0
		if to_camera.length_squared() > 0.01:
			var away := art.global_basis.inverse() * -to_camera.normalized()
			away.y = 0.0
			if away.length_squared() > 0.0001:
				art._away = away.normalized()
	return art


func _bind(visual: HeroVisual) -> void:
	if visual:
		owner_ref = weakref(visual)
		generation = visual.skill_generation


func _done(id: String) -> void:
	last = {"id": id, "asked": _asked, "drawn": layers.size()}


## The ground lace of a palette (a seal's line work: the palette's colour over its dark
## shade, saturated so it keeps its hue on a sunny field).
static func _lace(c: Array) -> Array:
	var p: Color = c[0]
	return [Color.from_hsv(p.h, clampf(p.s * 1.1 + 0.1, 0.0, 1.0), minf(p.v * 1.02, 1.0)), c[1], c[2]]


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Wind-up: the fighter readies. A soft halo at the feet and a glint on the fist; from the
## Lv.60 stage mantra script turns round the waist, at the top stage a ยันต์ seal turns
## underfoot and a small sun of flame petals gathers at the fist. ราชันมวยไทย's rings and
## gold dragon start their fall from the sky over the target, landing on the release;
## หมัดพันวง's rings gather into a circle before the fist. Bound to the caster's skill
## generation (a cancelled cast drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not owns(skill) or not _alive(parent) or duration < 0.12 or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var tier := tier_of(skill)
	var time := maxf(duration, 0.15)
	var c := palette(id)
	var art := _root(parent, origin, "MuayArt_Windup_" + id, _yaw(origin, aim))
	art._bind(visual)
	art.cap = mini(art.cap, [3, 5, 7][VfxBudget.quality()])
	if id == "thousand_ring_fist":
		# The rings leave the orbit and close into a circle before the fist.
		for k in count(6):
			var a := TAU * float(k) / 6.0
			art.layer("prajiad", false, CLOTH, RING_GATHER + Vector3(cos(a) * 1.4, sin(a) * 0.9, 0), Vector3.ONE * 0.34, Vector3(0.6, 0, 0.4), time * 0.1, time * 0.9 + 0.04, {"initial": 0.2, "grow": 3.0, "spin": 12.0, "travel": Vector3(-cos(a) * 0.9, -sin(a) * 0.6, 0), "fade_in": 0.2, "decay": 0.94, "tier": TIER_CORE if k < 2 else TIER_MID})
	elif tier >= 2 and id != "muay_king":
		art.layer("sun", false, SUN, HAND + Vector3(0, 0.35, 0.1), Vector3.ONE * 0.42, Vector3.ZERO, time * 0.05, time * 0.95 + 0.06, {"initial": 0.15, "grow": 1.4, "roll": 2.2, "billboard": true, "fade_in": 0.25, "decay": 0.9})
	art.layer("halo", true, c, Vector3(0, 0.03, 0), Vector3.ONE * (0.85 + 0.2 * float(tier)), Vector3.ZERO, 0.0, time + 0.08, {"initial": 1.6, "grow": 2.0, "fade_in": 0.3, "decay": 0.85, "opacity": 0.55})
	art.layer("star4", true, c, HAND, Vector3.ONE * (0.3 + 0.08 * float(tier)), Vector3.ZERO, time * 0.35, time * 0.65 + 0.05, {"initial": 0.1, "grow": 1.6, "roll": 3.0, "billboard": true, "fade_in": 0.2, "decay": 0.8, "opacity": 0.8})
	if tier >= 2:
		art.layer("yant", false, _lace(CLOTH), Vector3(0, 0.03, 0), Vector3.ONE * 1.35, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.3, "grow": 1.8, "spin": 0.9, "fade_in": 0.3, "decay": 0.85, "opacity": 0.85})
	if tier >= 1:
		art.layer("script", true, c, Vector3(0, 0.55, 0), Vector3(0.8, 0.85, 0.8), Vector3.ZERO, 0.0, time + 0.08, {"initial": 0.5, "grow": 1.6, "spin": 2.0, "fade_in": 0.3, "decay": 0.85, "opacity": 0.7, "tier": TIER_MID})
	if id == "muay_king":
		var spot := Vector3(aim.x, origin.y, aim.z)
		var sky := _root(parent, spot, "MuayArt_Sky_" + id, _yaw(origin, aim))
		sky._bind(visual)
		sky._sky_drop(minf(float(skill.get("radius", 5.5)), 8.0), time)


## Release: the skill's own composition, at the same beat as its damage.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not owns(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var shape := String(skill.get("shape", "single"))
	var at := center if shape == "blast" else origin
	var art := _root(parent, Vector3(at.x, origin.y, at.z), "MuayArt_" + id, _yaw(origin, center))
	# A crowd of casters (a guild war) keeps each composition to its first six layers.
	var now := Time.get_ticks_msec()
	if SkillShow._recent_shows.filter(func(t: int): return now - t < 1000).size() >= 3:
		art.cap = mini(art.cap, 6)
	var reach := maxf(Vector2(center.x - origin.x, center.z - origin.z).length(), 1.2)
	art._compose(id, skill, reach, minf(float(skill.get("radius", 3.0)), 8.0), maxf(delay, 0.0))
	art._done(id)


## Every hit: a กนก burst and a punch ring on the struck foe, fire for a burn, stars for a
## stun, a dust puff for a kick.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not owns(skill) or not _alive(parent) or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var q := VfxBudget.quality()
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < int(CONTACT_GAP_MS * [2.2, 1.5, 1.0][q]):
		return
	_last_contact[id] = now
	var c := palette(id)
	var fx: Dictionary = skill.get("fx", {})
	var art := _root(parent, at, "MuayArt_Hit_" + id)
	art.cap = mini(art.cap, [2, 3, 4][q])
	art.layer("burst", false, c, Vector3.ZERO, Vector3.ONE * 0.55, Vector3(0, 0, randf() * TAU), 0.0, 0.26, {"initial": 0.3, "grow": 9.0, "roll": 2.0, "billboard": true, "decay": 0.45})
	art.layer("punch_ring", true, c, Vector3.ZERO, Vector3.ONE * 0.55, Vector3.ZERO, 0.0, 0.3, {"initial": 0.2, "grow": 7.0, "billboard": true, "decay": 0.4, "opacity": 0.75})
	if fx.has("burn"):
		art.layer("kanok", false, FLAME, Vector3(0, -0.55, 0), Vector3.ONE * 0.5, Vector3.ZERO, 0.03, 0.5, {"initial": 0.2, "grow": 5.0, "overshoot": true, "travel": Vector3(0, 0.25, 0), "sway": 0.04, "sway_rate": 2.4, "face_camera": true, "decay": 0.55})
	elif fx.has("kick"):
		art.layer("dust", true, DUST, Vector3(0, -0.95, 0), Vector3(0.9, 0.6, 0.9), Vector3.ZERO, 0.02, 0.5, {"initial": 0.4, "grow": 4.0, "decay": 0.5, "opacity": 0.6})
	elif fx.has("stun"):
		art._stun_stars(Vector3(0, 0.8, 0), 0.03, 0.8, 2)


## A chain's link (SkillTableau.link): a ประเจียด ring snaps along it trailing its cloth
## ribbon (optional, budgeted); the hit itself is drawn by contact.
static func link(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3) -> void:
	if not owns(skill) or not _alive(parent) or from.distance_squared_to(to) < 0.01 or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var art := _root(parent, from, "MuayArt_Link_" + String(skill.get("id", "")))
	art.cap = mini(art.cap, [1, 2, 2][VfxBudget.quality()])
	var span := art.global_basis.inverse() * (to - from)
	art.layer("prajiad", false, CLOTH, Vector3.ZERO, Vector3.ONE * 0.36, Vector3(0.45, 0, 0.3), 0.0, 0.18, {"initial": 0.7, "travel": span, "snap": 0.12, "spin": 18.0, "decay": 0.8})
	art.layer("ribbon", false, palette(String(skill.get("id", ""))), Vector3.ZERO, Vector3(minf(span.length(), 2.2), 0.5, 1.0), Vector3.ZERO, 0.0, 0.22, {"initial": 0.3, "grow": 8.0, "travel": span, "snap": 0.12, "point": span.normalized(), "decay": 0.5, "tier": TIER_MID})


## A ring skill's projectile (SkillTableau.flight, mantra_storm's fan): the essential body
## is a ประเจียด ring of red cloth bound in gold, spinning to the foe (drawn even when the
## optional budget is full), its cloth ribbon streaming behind when there is room.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "MuayFlight_" + String(skill.get("id", ""))
	parent.add_child(root)
	root.global_position = from
	var mats: Array = []
	var body := MeshInstance3D.new()
	body.name = "EssentialSkillProjectile"
	body.mesh = mesh("prajiad")
	body.material_override = _flight_paint(CLOTH, mats)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.scale = Vector3.ONE * 0.42 * size
	body.rotation = Vector3(0.45, 0.0, 0.3)
	root.add_child(body)
	var dir := to - from
	if dir.length_squared() > 0.0001 and VfxBudget.can_decorate(1 + RESERVE):
		var ribbon := MeshInstance3D.new()
		ribbon.name = "Ribbon"
		ribbon.mesh = mesh("ribbon")
		ribbon.material_override = _flight_paint(palette(String(skill.get("id", ""))), mats)
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ribbon)
		VfxBudget.track_decoration(ribbon)
		var camera := parent.get_viewport().get_camera_3d()
		var z := (camera.global_position - from).normalized() if camera else Vector3.UP
		var x := dir - z * dir.dot(z)
		x = x.normalized() if x.length_squared() > 0.0001 else dir.normalized()
		var y := z.cross(x).normalized()
		ribbon.global_basis = Basis(x * minf(dir.length(), 2.0), y * 0.6 * size, z)
	var tween := root.create_tween()
	tween.set_parallel()
	tween.tween_property(root, "global_position", to, maxf(seconds, 0.02))
	tween.tween_property(body, "rotation:y", 16.0 * maxf(seconds, 0.02), maxf(seconds, 0.02))
	tween.chain().tween_callback(root.queue_free)
	root.tree_exiting.connect(_give.bind(mats), CONNECT_ONE_SHOT)
	return root


static func _flight_paint(c: Array, mats: Array) -> ShaderMaterial:
	var mat := _take(PAINT)
	mat.set_shader_parameter("primary", c[0])
	mat.set_shader_parameter("accent", c[1])
	mat.set_shader_parameter("shade", c[2])
	mat.set_shader_parameter("opacity", 0.95)
	mat.set_shader_parameter("fade", 1.0)
	mat.set_shader_parameter("age", 0.0)
	mat.set_shader_parameter("glow", 0.0)
	mats.append(mat)
	return mat


## Materials back to the pool (a flight that landed, a cast that ended).
static func _give(mats: Array) -> void:
	for mat: ShaderMaterial in mats:
		var free: Array = _pool.get(mat.shader, [])
		if free.size() < POOL_MAX:
			free.append(mat)
			_pool[mat.shader] = free


static func palette(id: String) -> Array:
	match id:
		"jab_cross", "back_elbow", "ring_throw", "push_kick", "sweep_kick", "wai_khru", "ring_guard": return GOLD
		"sun_fist", "mantra_storm", "sacred_mongkhon", "muay_king": return SUN
		"thunder_elbow": return BOLT
		"iron_prajiad": return IRON
	return EMBER


# ---------------------------------------------------------------------------
# Shared pieces of the compositions
# ---------------------------------------------------------------------------

## A painted fist snapping from [param from] to [param to] in [param snap] seconds, its
## knuckles leading the flight on screen, a speed streak behind it; it squashes on the
## blow and lingers for [param hold] seconds before it dissolves.
func _fist_blow(c: Array, from: Vector3, to: Vector3, start: float, snap: float, size: float, hold: float, tier := TIER_CORE, streak := true) -> void:
	var seconds := snap + hold
	var dir := (to - from).normalized() if (to - from).length_squared() > 0.0001 else Vector3.BACK
	layer("fist_hero", false, c, from, Vector3.ONE * size, Vector3.ZERO, start, seconds, {"initial": 0.75, "grow": 14.0, "travel": to - from, "snap": snap, "point": dir, "fade_in": 0.02, "decay": 0.7, "tier": tier})
	if streak:
		layer("streak", true, c, from, Vector3(size * 1.25, size * 0.75, 1.0), Vector3.ZERO, start, snap + hold * 0.45, {"initial": 0.5, "grow": 10.0, "travel": to - from, "snap": snap, "point": dir, "fade_in": 0.02, "decay": 0.35, "opacity": 0.8, "tier": mini(tier + 1, TIER_DEBRIS)})


## The blow lands: a กนก burst facing the camera, a punch ring, a second ring.
func _impact(c: Array, at: Vector3, size: float, start: float, rings := 2) -> void:
	layer("burst", false, c, at, Vector3.ONE * size, Vector3(0, 0, randf() * TAU), start, 0.36, {"initial": 0.25, "grow": 9.0, "roll": 1.2, "billboard": true, "decay": 0.5})
	layer("punch_ring", true, c, at, Vector3.ONE * size * 0.9, Vector3.ZERO, start, 0.34, {"initial": 0.15, "grow": 6.5, "billboard": true, "decay": 0.45, "opacity": 0.7, "tier": TIER_MID})
	for k in rings - 1:
		layer("punch_ring", true, c, at, Vector3.ONE * size * (1.35 + 0.35 * float(k)), Vector3.ZERO, start + 0.07 * float(k + 1), 0.4, {"initial": 0.2, "grow": 5.0, "billboard": true, "decay": 0.4, "opacity": 0.5, "tier": TIER_DEBRIS})


## Sparks thrown off [param at] (small additive four-point glints, ballistic).
func _sparks(c: Array, at: Vector3, n: int, start: float, spread := 1.0) -> void:
	for k in count(n):
		var a := float(k) * TAU / float(maxi(n, 1)) + 0.4
		layer("star4", true, c, at, Vector3.ONE * 0.2, Vector3.ZERO, start + 0.015 * float(k), 0.5, {"initial": 1.0, "toss": Vector3(sin(a) * 2.6 * spread, 2.8 + 1.2 * float(k % 2), cos(a) * 2.6 * spread), "gravity": 9.0, "drag": 1.0, "roll": 8.0, "billboard": true, "decay": 0.55, "opacity": 0.95, "tier": TIER_DEBRIS})


## Gold stars circling a stunned head for the stun's length.
func _stun_stars(at: Vector3, start: float, secs: float, n := 3) -> void:
	for k in n:
		layer("star4", true, GOLD, at + Vector3(0, 0.9, 0), Vector3.ONE * 0.2, Vector3.ZERO, start + 0.03 * float(k), clampf(secs, 0.5, 2.2), {"initial": 0.3, "grow": 6.0, "orbit": 0.42, "orbit_speed": 6.0, "phase": TAU * float(k) / float(n), "roll": 4.0, "billboard": true, "decay": 0.85, "tier": TIER_CORE if k == 0 else TIER_MID})


## กนก flame tongues licking up round [param at] (painted, outlined).
func _flames(at: Vector3, r: float, n: int, start: float, height := 1.0, seconds := 0.7, c := FLAME) -> void:
	for k in count(n):
		var a := float(k) * 2.39996 + 0.5
		var spot := at + Vector3(sin(a), 0.02, cos(a)) * r * (0.55 + 0.45 * fmod(float(k) * 0.618, 1.0))
		var h := height * (0.75 + 0.5 * fmod(float(k) * 0.37, 1.0))
		layer("kanok", false, c, spot, Vector3.ONE * h, Vector3.ZERO, start + 0.04 * float(k), seconds, {"initial": 0.15, "grow": 3.5, "overshoot": true, "travel": Vector3(0, h * 0.2, 0), "sway": 0.05, "sway_rate": 2.6, "phase": a, "face_camera": true, "decay": 0.55, "tier": TIER_MID if k < 2 else TIER_DEBRIS})


## Mantra glyphs (ยันต์ marks) circling at [param y] and rising.
func _glyphs(c: Array, at: Vector3, n: int, radius: float, y: float, start: float, seconds: float, size := 0.4) -> void:
	for k in count(n):
		layer("glyph", true, c, at + Vector3(0, y, 0), Vector3.ONE * size, Vector3.ZERO, start + 0.05 * float(k), seconds, {"initial": 0.2, "overshoot": true, "orbit": radius, "orbit_speed": 2.6, "phase": TAU * float(k) / float(n), "travel": Vector3(0, 0.6, 0), "bob": 0.08, "face_camera": true, "fade_in": 0.15, "decay": 0.75, "tier": TIER_MID if k < 2 else TIER_DEBRIS})


## Mantra glyphs thrown up and out of [param at].
func _glyph_burst(c: Array, at: Vector3, n: int, start: float) -> void:
	for k in count(n):
		var a := float(k) * TAU / float(n) + 0.3
		layer("glyph", true, c, at, Vector3.ONE * 0.36, Vector3.ZERO, start + 0.02 * float(k), 0.65, {"initial": 0.4, "overshoot": true, "toss": Vector3(sin(a) * 1.8, 2.6, cos(a) * 1.8), "gravity": 4.0, "drag": 1.4, "roll": 3.0 if k % 2 else -3.0, "face_camera": true, "decay": 0.6, "tier": TIER_MID if k == 0 else TIER_DEBRIS})


## ประเจียด rings orbiting [param at] at [param y].
func _orbit_rings(c: Array, at: Vector3, n: int, radius: float, y: float, start: float, seconds: float, size := 0.34, speed := 3.6) -> void:
	for k in n:
		layer("prajiad", false, c, at + Vector3(0, y, 0), Vector3.ONE * size, Vector3(0.35, 0, 0.25), start + 0.03 * float(k), seconds, {"initial": 0.2, "overshoot": true, "orbit": radius, "orbit_speed": speed, "phase": TAU * float(k) / float(n), "spin": 9.0, "bob": 0.08, "fade_in": 0.12, "decay": 0.8, "tier": TIER_CORE if k < 2 else TIER_MID})


## A ring and its cloth ribbon flying from [param from] to [param to] (and back when [param back]).
func _ring_flight(c: Array, from: Vector3, to: Vector3, start: float, flight: float, size := 0.42, back := true, tier := TIER_CORE) -> void:
	var dir := (to - from).normalized() if (to - from).length_squared() > 0.0001 else Vector3.BACK
	layer("prajiad", false, CLOTH, from, Vector3.ONE * size, Vector3(0.45, 0, 0.3), start, flight + 0.04, {"initial": 0.5, "travel": to - from, "spin": 16.0, "decay": 0.92, "tier": tier})
	layer("ribbon", false, c, from, Vector3(size * 4.0, size * 1.6, 1.0), Vector3.ZERO, start + 0.02, flight + 0.08, {"initial": 0.2, "grow": 5.0, "travel": to - from, "point": dir, "decay": 0.6, "opacity": 0.9, "tier": mini(tier + 1, TIER_DEBRIS)})
	if back:
		layer("prajiad", false, CLOTH, to, Vector3.ONE * size, Vector3(0.45, 0, -0.3), start + flight, flight * 1.2 + 0.04, {"initial": 1.0, "travel": from - to, "spin": -16.0, "decay": 0.8, "tier": mini(tier + 1, TIER_DEBRIS)})


## A ground blow at [param at]: a shockwave, glowing cracks, a scorch.
func _ground(c: Array, at: Vector3, r: float, start: float, cracks := true) -> void:
	layer("shock", true, c, at + Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, start, 0.55, {"initial": 0.15, "grow": 4.5, "decay": 0.5, "tier": TIER_MID})
	if cracks:
		layer("crack", true, EMBER, at + Vector3.UP * 0.04, Vector3.ONE * r * 0.7, Vector3(0, randf() * TAU, 0), start, 1.2, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "opacity": 0.95, "tier": TIER_MID})
	layer("scorch", true, SCORCH, at + Vector3.UP * 0.03, Vector3.ONE * r * 0.5, Vector3(0, randf() * TAU, 0), start, 1.4, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.6, "tier": TIER_DEBRIS})


## Cones of force rolling out from [param at] round the compass (a stamp, a crash).
func _radial_cones(c: Array, at: Vector3, n: int, reach: float, start: float, y := 0.45) -> void:
	for k in count(n):
		var a := TAU * float(k) / float(n) + 0.2
		layer("cone", true, c, at + Vector3(sin(a), 0, cos(a)) * 0.4 + Vector3.UP * y, Vector3(0.6, 0.6, reach), Vector3(0, a, 0), start + 0.015 * float(k), 0.42, {"initial": 0.1, "grow": 5.0, "decay": 0.45, "opacity": 0.5, "tier": TIER_MID if k % 2 == 0 else TIER_DEBRIS})


## ราชันมวยไทย's sky: a gold-and-jade dragon spirals down through a light pillar, every
## ring falls from the sky round the target, a seal kindles under the pack; all land at
## [param land].
func _sky_drop(r: float, land: float) -> void:
	layer("dragon", false, DRAGON_GOLD, Vector3(0, 5.5, 0), Vector3(1.9, 1.9, 1.9), Vector3.ZERO, 0.0, land + 0.06, {"initial": 0.4, "grow": 2.5, "travel": Vector3(0, -5.2, 0), "accelerate": true, "spin": 6.0, "fade_in": 0.15, "decay": 0.92})
	layer("yant", false, _lace(CLOTH), Vector3.UP * 0.04, Vector3.ONE * r * 0.85, Vector3.ZERO, 0.0, land + 0.12, {"initial": 0.2, "grow": 1.4, "spin": 0.7, "fade_in": 0.4, "decay": 0.9, "opacity": 0.85})
	for k in count(6):
		var a := TAU * float(k) / 6.0 + 0.3
		var spot := Vector3(sin(a), 0, cos(a)) * r * 0.6
		layer("prajiad", false, CLOTH, spot + Vector3.UP * 6.5, Vector3.ONE * 0.5, Vector3(0.2, 0, 0.15), land * 0.08 * float(k % 3), land * (1.0 - 0.08 * float(k % 3)) + 0.03, {"initial": 0.6, "travel": -spot * 0.75 + Vector3(0, -6.2, 0), "accelerate": true, "spin": 14.0, "fade_in": 0.1, "decay": 0.95, "tier": TIER_CORE if k < 3 else TIER_MID})
	layer("pillar", true, GOLD, Vector3.ZERO, Vector3(1.2, 9.0, 1.2), Vector3.ZERO, 0.0, land + 0.2, {"initial": 0.3, "grow": 1.6, "fade_in": 0.4, "decay": 0.85, "opacity": 0.22, "tier": TIER_MID})
	# A jade aura round the gold dragon.
	layer("dragon", true, JADE, Vector3(0, 5.5, 0), Vector3(1.97, 1.97, 1.97), Vector3.ZERO, 0.0, land + 0.06, {"initial": 0.4, "grow": 2.5, "travel": Vector3(0, -5.2, 0), "accelerate": true, "spin": 6.0, "fade_in": 0.15, "decay": 0.92, "opacity": 0.3, "tier": TIER_DEBRIS})


# ---------------------------------------------------------------------------
# Compositions. Every arm lists its layers most important first (the hero shape,
# then what supports it): the cap ([6, 12, 20] by quality) keeps the first ones,
# so a phone still sees the blow. [param d] is the damage beat.
# ---------------------------------------------------------------------------

func _compose(id: String, skill: Dictionary, reach: float, r: float, d: float) -> void:
	var target := Vector3(0, 0, reach)
	var th := target + HIT
	var fx: Dictionary = skill.get("fx", {})
	var i := d + 0.04
	var c := palette(id)
	match id:
		"jab_cross":
			# One-two: a jab and a cross snap in from the hands, a กนก burst on each.
			_fist_blow(FIST, HAND + Vector3(-0.3, 0.15, 0), th + Vector3(0.12, 0.25, -0.35), d, 0.06, 0.62, 0.22)
			_fist_blow(FIST, HAND + Vector3(0.15, 0.1, 0), th + Vector3(-0.1, 0.1, -0.3), d + 0.09, 0.06, 0.7, 0.24, TIER_MID)
			_impact(c, th + Vector3(0, 0.15, -0.25), 0.75, d + 0.05, 2)
			_sparks(c, th - Vector3(0, 0, 0.3), 3, d + 0.05)
		"flame_hook":
			# A burning hook: the fist swings in on a crescent of fire, fire takes the foe.
			_fist_blow(FIST, th + Vector3(1.4, 0.35, -0.9), th + Vector3(0.05, 0.2, -0.3), d - 0.02, 0.08, 0.85, 0.28)
			layer("sweep", true, EMBER, th - Vector3(0, 0.05, 0.4), Vector3.ONE * 1.0, Vector3(0, -PI * 0.5, 0), d - 0.02, 0.3, {"initial": 0.5, "grow": 6.0, "spin": 11.0, "decay": 0.5, "opacity": 0.85})
			_impact(EMBER, th + Vector3(0, 0.1, -0.25), 0.95, i, 2)
			_flames(target, 0.6, 3, i, 0.9)
			_ground(EMBER, target, 1.4, i, false)
			_sparks(SUN, th - Vector3(0, 0, 0.3), 5, i)
		"sun_fist":
			# The sun's fist: a giant painted fist snaps onto the foe out of a rising sun of
			# flame petals, squashes on the blow and holds; a กนก burst at the knuckles,
			# the ground cracks and burns round the foe.
			# It comes down out of the sky on the fighter's off side and lands over the foe's
			# head, clear of the fighter's own body from the camera behind.
			var land := th + Vector3(-1.0, 1.15, -0.2)
			var from := land + Vector3(-1.3, 1.7, -1.1)
			var knuckles := land + (land - from).normalized() * 0.85
			_fist_blow(FIST, from, land, d - 0.03, 0.09, 1.55, 0.62)
			layer("sun", false, SUN, land + Vector3(0.15, 0.05, 1.0), Vector3.ONE * 1.85, Vector3.ZERO, d - 0.03, 0.85, {"initial": 0.35, "grow": 6.0, "overshoot": true, "roll": 0.5, "billboard": true, "decay": 0.62, "opacity": 0.95})
			layer("burst", false, SUN, knuckles + Vector3(0, 0, 0.1), Vector3.ONE * 1.1, Vector3(0, 0, 0.3), i, 0.4, {"initial": 0.3, "grow": 9.0, "roll": 1.0, "billboard": true, "decay": 0.5})
			layer("shock", true, SUN, target + Vector3.UP * 0.05, Vector3.ONE * 2.8, Vector3.ZERO, i, 0.6, {"initial": 0.15, "grow": 4.5, "decay": 0.5})
			layer("crack", true, EMBER, target + Vector3.UP * 0.04, Vector3.ONE * 1.9, Vector3(0, randf() * TAU, 0), i, 1.3, {"initial": 0.3, "grow": 9.0, "decay": 0.62, "opacity": 0.95})
			_flames(target, 1.1, 5, i + 0.03, 1.05, 0.85)
			layer("punch_ring", true, SUN, knuckles, Vector3.ONE * 1.4, Vector3.ZERO, i, 0.38, {"initial": 0.2, "grow": 6.0, "billboard": true, "decay": 0.45, "opacity": 0.7, "tier": TIER_MID})
			layer("star4", true, SUN, knuckles, Vector3.ONE * 1.0, Vector3.ZERO, i, 0.18, {"initial": 0.4, "grow": 10.0, "roll": 3.0, "billboard": true, "decay": 0.3, "opacity": 0.7, "tier": TIER_MID})
			layer("scorch", true, SCORCH, target + Vector3.UP * 0.03, Vector3.ONE * 1.5, Vector3(0, randf() * TAU, 0), i, 1.5, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.6, "tier": TIER_MID})
			_sparks(SUN, knuckles, 6, i, 1.3)
		"back_elbow":
			# The spinning back elbow: a gold crescent whirls round the fighter, a burst on the foe.
			layer("sweep", true, c, Vector3(0, 1.0, 0), Vector3.ONE * 1.25, Vector3.ZERO, d - 0.04, 0.34, {"initial": 0.5, "grow": 6.0, "spin": 12.0, "decay": 0.5, "opacity": 0.9})
			_impact(c, th - Vector3(0, -0.1, 0.3), 0.85, i, 2)
			_stun_stars(target + Vector3.UP * 1.0, i, float(fx.get("stun", 1.0)), 3)
			_sparks(c, th - Vector3(0, 0, 0.3), 3, i)
		"flying_knee":
			# The leap: a cloth-red trail arcs up to the foe, a burst at knee height, dust below.
			layer("ribbon", false, CLOTH, th - Vector3(0, 0.1, 0.3), Vector3(maxf(reach - 0.4, 1.0), 1.2, 1.0), Vector3.ZERO, d - 0.04, 0.45, {"initial": 0.3, "grow": 6.0, "point": Vector3(0, 0.35, 1), "decay": 0.5, "opacity": 0.9})
			_impact(EMBER, th - Vector3(0, -0.1, 0.3), 1.15, i, 2)
			_stun_stars(target + Vector3.UP * 1.0, i, float(fx.get("stun", 1.0)), 3)
			layer("dust", true, DUST, target + Vector3.UP * 0.02, Vector3(1.1, 0.7, 1.1), Vector3.ZERO, i, 0.7, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.6, "tier": TIER_MID})
			_ground(EMBER, target, 1.5, i, false)
			_sparks(SUN, th, 5, i)
		"thunder_elbow":
			# Lightning: two outlined gold thunderbolts crash onto the foe, a ยันต์ seal
			# flashes under it, the ground cracks; a burst where the elbow lands, the stunned reel.
			layer("zap", false, BOLT, target + Vector3(0, 0, -0.1), Vector3(2.4, 6.0, 1.0), Vector3.ZERO, d - 0.03, 0.42, {"initial": 0.85, "grow": 12.0, "face_camera": true, "fade_in": 0.02, "decay": 0.55})
			layer("burst", false, BOLT, th + Vector3(0, 0.2, -0.2), Vector3.ONE * 1.35, Vector3(0, 0, 0.5), i, 0.42, {"initial": 0.3, "grow": 9.0, "roll": 1.2, "billboard": true, "decay": 0.5})
			layer("yant", false, _lace(CLOTH), target + Vector3.UP * 0.04, Vector3.ONE * 1.7, Vector3.ZERO, d, 1.1, {"initial": 0.5, "grow": 8.0, "spin": 0.8, "decay": 0.6, "opacity": 0.9})
			layer("zap", false, BOLT, target + Vector3(0.5, 0, 0.25), Vector3(-1.7, 5.2, 1.0), Vector3.ZERO, d + 0.05, 0.3, {"initial": 0.9, "grow": 12.0, "face_camera": true, "fade_in": 0.02, "decay": 0.45, "tier": TIER_MID})
			layer("crack", true, BOLT, target + Vector3.UP * 0.045, Vector3.ONE * 2.4, Vector3(0, randf() * TAU, 0), i, 1.2, {"initial": 0.3, "grow": 9.0, "decay": 0.6})
			layer("shock", true, BOLT, target + Vector3.UP * 0.05, Vector3.ONE * 3.0, Vector3.ZERO, i + 0.03, 0.55, {"initial": 0.15, "grow": 4.0, "decay": 0.5})
			_stun_stars(target + Vector3.UP * 1.0, i, float(fx.get("stun", 1.0)), 3)
			layer("star4", true, BOLT, th + Vector3(0, 0.2, -0.2), Vector3.ONE * 1.1, Vector3.ZERO, i, 0.2, {"initial": 0.4, "grow": 10.0, "roll": 3.0, "billboard": true, "decay": 0.3, "opacity": 0.7, "tier": TIER_MID})
			layer("scorch", true, SCORCH, target + Vector3.UP * 0.03, Vector3.ONE * 1.5, Vector3(0, randf() * TAU, 0), i, 1.4, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.6, "tier": TIER_MID})
			layer("dust", true, DUST, target + Vector3.UP * 0.02, Vector3(1.6, 0.8, 1.6), Vector3.ZERO, i, 0.8, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.55, "tier": TIER_DEBRIS})
			_sparks(BOLT, th, 6, i, 1.3)
		"ring_throw":
			# A ring of red cloth leaves the arm trailing its ribbon; a glyph pops on the foe.
			var fly := 0.32
			_ring_flight(c, HAND, th, d, fly, 0.42, false)
			_impact(c, th - Vector3(0, 0, 0.2), 0.7, d + fly, 1)
			layer("glyph", true, c, th + Vector3.UP * 0.3, Vector3.ONE * 0.5, Vector3.ZERO, d + fly, 0.6, {"initial": 0.2, "overshoot": true, "travel": Vector3(0, 0.7, 0), "face_camera": true, "decay": 0.6})
			layer("halo", true, c, target + Vector3.UP * 0.03, Vector3.ONE * 1.0, Vector3.ZERO, d + fly, 0.5, {"initial": 0.3, "grow": 5.0, "decay": 0.5, "opacity": 0.6, "tier": TIER_MID})
		"twin_rings":
			# Two burning rings with ribbons, out and back; glyphs burst and fire takes the foe.
			var fly := 0.3
			for s: float in [-1.0, 1.0]:
				_ring_flight(EMBER, HAND + Vector3(s * 0.3, 0.1 * s, 0), th + Vector3(s * 0.35, 0.1, -0.2), d + (0.0 if s < 0.0 else 0.06), fly, 0.42, true, TIER_CORE)
			_impact(EMBER, th - Vector3(0, 0, 0.2), 0.9, d + fly, 2)
			_glyph_burst(SUN, th, 3, d + fly)
			_flames(target, 0.7, 3, d + fly, 0.9)
			_ground(EMBER, target, 1.4, d + fly, false)
		"mantra_storm":
			# Every ring bursts out round the compass trailing its ribbon and back; a seal
			# turns under the fighter, mantra script spirals up, glyphs orbit.
			var out := clampf(reach, 4.0, 6.0)
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.04, Vector3.ONE * 2.8, Vector3.ZERO, d - 0.03, 1.3, {"initial": 0.3, "grow": 4.0, "spin": 1.0, "decay": 0.8, "opacity": 0.92})
			for k in 6:
				var a := TAU * float(k) / 6.0
				var dir := Vector3(sin(a), 0, cos(a))
				_ring_flight(SUN, Vector3(0, 1.1, 0) + dir * 0.5, Vector3(0, 1.0, 0) + dir * out, d + 0.02 * float(k % 2), 0.34, 0.46, true, TIER_CORE if k < 3 else TIER_MID)
			layer("script", true, SUN, Vector3(0, 0.15, 0), Vector3(1.15, 1.2, 1.15), Vector3.ZERO, d, 1.0, {"initial": 0.5, "grow": 3.0, "spin": 2.2, "travel": Vector3(0, 1.3, 0), "decay": 0.7, "opacity": 0.75})
			layer("shock", true, SUN, Vector3.UP * 0.05, Vector3.ONE * out * 1.05, Vector3.ZERO, d, 0.6, {"initial": 0.1, "grow": 3.5, "decay": 0.5, "tier": TIER_MID})
			_glyphs(SUN, Vector3.ZERO, 4, 1.5, 2.3, d + 0.05, 1.0)
		"push_kick":
			# The teep: a cone of force from the foot, a burst and a puff of dust on the foe.
			layer("cone", true, c, Vector3(0, 0.75, 0.45), Vector3(0.7, 0.7, maxf(reach - 0.5, 1.0)), Vector3.ZERO, d - 0.03, 0.32, {"initial": 0.1, "grow": 6.0, "decay": 0.45, "opacity": 0.7})
			_impact(c, target + Vector3(0, 0.85, -0.3), 0.85, i, 2)
			layer("dust", true, DUST, target + Vector3.UP * 0.02, Vector3(1.0, 0.6, 1.0), Vector3.ZERO, i, 0.7, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.6})
			layer("shock", true, c, target + Vector3.UP * 0.05, Vector3.ONE * 1.3, Vector3.ZERO, i, 0.45, {"initial": 0.2, "grow": 5.0, "decay": 0.5, "tier": TIER_MID})
		"body_throw":
			# The throw: a burning arc over to the foe, a crash into a crater, a burst and dust.
			layer("sweep", true, EMBER, Vector3(0, 0.2, reach * 0.5), Vector3.ONE * reach * 0.55, Vector3(0, 0, PI * 0.5), d - 0.04, 0.4, {"initial": 0.5, "grow": 5.0, "decay": 0.5, "opacity": 0.85})
			layer("burst", false, EMBER, target + Vector3.UP * 0.55, Vector3.ONE * 1.3, Vector3.ZERO, i + 0.05, 0.4, {"initial": 0.3, "grow": 9.0, "roll": 1.0, "billboard": true, "decay": 0.5})
			layer("crater", true, EMBER, target + Vector3.UP * 0.05, Vector3.ONE * 1.4, Vector3(0, randf() * TAU, 0), i + 0.05, 1.0, {"initial": 0.3, "grow": 8.0, "decay": 0.6})
			_ground(EMBER, target, 2.2, i + 0.05)
			_stun_stars(target + Vector3.UP * 0.8, i + 0.1, float(fx.get("stun", 1.0)), 3)
			layer("dust", true, DUST, target + Vector3.UP * 0.02, Vector3(1.5, 0.8, 1.5), Vector3.ZERO, i + 0.05, 0.8, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.6, "tier": TIER_MID})
			_sparks(SUN, target + Vector3.UP * 0.4, 5, i + 0.05)
		"earth_kick":
			# The stamp: a ยันต์ seal is stamped into the earth round the fighter, it cracks
			# open glowing, shockwaves and cones of force roll out, dust rises.
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.04, Vector3.ONE * r * 0.62, Vector3.ZERO, d - 0.03, 1.2, {"initial": 0.55, "grow": 9.0, "overshoot": true, "spin": 0.5, "decay": 0.66, "opacity": 0.95})
			layer("crack", true, EMBER, Vector3.UP * 0.045, Vector3.ONE * r * 0.8, Vector3(0, randf() * TAU, 0), d, 1.3, {"initial": 0.2, "grow": 7.0, "decay": 0.65})
			layer("burst", false, EMBER, Vector3(0, 0.35, 0.2), Vector3.ONE * 1.3, Vector3.ZERO, d - 0.02, 0.32, {"initial": 0.3, "grow": 9.0, "roll": 1.0, "billboard": true, "decay": 0.5})
			for k in 2:
				layer("shock", true, SUN if k == 0 else EMBER, Vector3.UP * (0.05 + 0.01 * float(k)), Vector3.ONE * r * (0.6 + 0.4 * float(k)), Vector3.ZERO, d + 0.1 * float(k), 0.6, {"initial": 0.1, "grow": 4.0, "decay": 0.5, "tier": TIER_CORE if k == 0 else TIER_MID})
			_radial_cones(GOLD, Vector3.ZERO, 6, r * 0.6, d + 0.02)
			layer("dust", true, DUST, Vector3.UP * 0.02, Vector3(r * 0.8, 0.9, r * 0.8), Vector3.ZERO, d + 0.03, 0.9, {"initial": 0.3, "grow": 3.0, "decay": 0.6, "opacity": 0.6, "tier": TIER_MID})
			layer("scorch", true, SCORCH, Vector3.UP * 0.03, Vector3.ONE * 1.8, Vector3(0, randf() * TAU, 0), d, 1.4, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.6, "tier": TIER_MID})
			for k in count(3):
				var a := float(k) * 2.1 + 0.5
				layer("smoke", true, DUST, Vector3(sin(a), 0.1, cos(a)) * r * 0.55, Vector3.ONE * 1.3, Vector3.ZERO, d + 0.05 * float(k), 1.1, {"initial": 0.3, "grow": 3.0, "travel": Vector3(sin(a) * 0.8, 1.0, cos(a) * 0.8), "face_camera": true, "decay": 0.55, "opacity": 0.45, "tier": TIER_DEBRIS})
			_sparks(SUN, Vector3(0, 0.3, 0), 6, d, 1.6)
		"sweep_kick":
			# The sweep: two crescents whip round at ankle height, a shock ring and dust.
			layer("sweep", true, c, Vector3(0, 0.35, 0), Vector3.ONE * r * 0.8, Vector3.ZERO, d - 0.04, 0.38, {"initial": 0.4, "grow": 6.0, "spin": 13.0, "decay": 0.5, "opacity": 0.9})
			layer("shock", true, c, Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, d + 0.04, 0.45, {"initial": 0.2, "grow": 5.0, "decay": 0.5})
			layer("sweep", true, EMBER, Vector3(0, 0.6, 0), Vector3.ONE * r * 0.55, Vector3(0, PI, 0), d, 0.34, {"initial": 0.4, "grow": 6.0, "spin": 13.0, "decay": 0.5, "opacity": 0.7, "tier": TIER_MID})
			layer("dust", true, DUST, Vector3.UP * 0.02, Vector3(r * 0.75, 0.6, r * 0.75), Vector3.ZERO, d + 0.04, 0.7, {"initial": 0.4, "grow": 4.0, "decay": 0.55, "opacity": 0.55, "tier": TIER_MID})
		"flame_ring_spin":
			# The burning spin: a wall of fire turns round the fighter, rings whirl in it,
			# a fire crescent whips round, กนก flames lick up, the ground scorches.
			layer("fire_wall", true, FLAME, Vector3.UP * 0.02, Vector3(r * 0.72, 1.2, r * 0.72), Vector3.ZERO, d - 0.03, 0.9, {"initial": 0.3, "grow": 5.0, "overshoot": true, "spin": 3.0, "decay": 0.6, "opacity": 0.85})
			layer("sweep", true, EMBER, Vector3(0, 0.55, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d - 0.03, 0.38, {"initial": 0.4, "grow": 6.0, "spin": 11.0, "decay": 0.5})
			_orbit_rings(CLOTH, Vector3.ZERO, 3, r * 0.45, 0.95, d, 0.9, 0.38, 5.0)
			_flames(Vector3.ZERO, r * 0.7, 5, d + 0.05, 1.0, 0.8)
			layer("scorch", true, SCORCH, Vector3.UP * 0.03, Vector3.ONE * r * 0.55, Vector3(0, randf() * TAU, 0), d, 1.4, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.55, "tier": TIER_MID})
			layer("halo", true, EMBER, Vector3.UP * 0.03, Vector3.ONE * r * 0.75, Vector3.ZERO, d, 0.7, {"initial": 0.4, "grow": 4.0, "decay": 0.6, "opacity": 0.5, "tier": TIER_DEBRIS})
		"fire_dragon_circle":
			# The fire dragon coils round the fighter inside a turning wall of fire; a seal
			# burns underfoot, กนก flames lick up round the ring, the ground scorches.
			layer("dragon", false, FLAME, Vector3(0, 0.1, 0), Vector3(2.5, 2.1, 2.5), Vector3.ZERO, d - 0.03, 1.25, {"initial": 0.3, "grow": 3.5, "overshoot": true, "spin": 4.2, "fade_in": 0.08, "decay": 0.75})
			layer("fire_wall", true, FLAME, Vector3.UP * 0.02, Vector3(r * 0.55, 1.0, r * 0.55), Vector3.ZERO, d, 1.0, {"initial": 0.3, "grow": 5.0, "overshoot": true, "spin": -2.4, "decay": 0.6, "opacity": 0.8})
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.035, Vector3.ONE * 2.6, Vector3.ZERO, d - 0.03, 1.2, {"initial": 0.3, "grow": 5.0, "spin": 1.0, "decay": 0.75, "opacity": 0.92})
			layer("sweep", true, EMBER, Vector3(0, 0.5, 0), Vector3.ONE * r * 0.7, Vector3.ZERO, d, 0.4, {"initial": 0.4, "grow": 6.0, "spin": 11.0, "decay": 0.5, "opacity": 0.8, "tier": TIER_MID})
			layer("shock", true, EMBER, Vector3.UP * 0.05, Vector3.ONE * r, Vector3.ZERO, d + 0.05, 0.55, {"initial": 0.2, "grow": 4.0, "decay": 0.5, "tier": TIER_MID})
			_flames(Vector3.ZERO, r * 0.75, 6, d + 0.05, 1.15, 0.9)
			layer("scorch", true, SCORCH, Vector3.UP * 0.03, Vector3.ONE * r * 0.6, Vector3(0, randf() * TAU, 0), d, 1.5, {"initial": 0.4, "grow": 8.0, "decay": 0.65, "opacity": 0.55, "tier": TIER_MID})
			_sparks(SUN, Vector3(0, 1.2, 0), 6, d + 0.1, 1.5)
		"wai_khru":
			# ไหว้ครู: a seal at the feet, mantra script rising round the fighter, the มงคล
			# headband settling in light.
			_ritual(GOLD, d, 0)
		"ram_muay":
			_ritual(EMBER, d, 1)
		"sacred_mongkhon":
			_ritual(SUN, d, 2)
		"ring_guard":
			# The rings close into a shield: a dome of facets, a seal, two rings orbiting.
			layer("dome", true, GOLD, Vector3.ZERO, Vector3(1.7, 1.9, 1.7), Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 4.0, "overshoot": true, "spin": 0.5, "decay": 0.75, "opacity": 0.7})
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.035, Vector3.ONE * 1.6, Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 4.0, "spin": -0.6, "decay": 0.75, "opacity": 0.9})
			_orbit_rings(CLOTH, Vector3.ZERO, 2, 2.0, 0.9, d, 1.1, 0.34, 4.0)
			layer("halo", true, GOLD, Vector3.UP * 0.03, Vector3.ONE * 1.4, Vector3.ZERO, d, 0.8, {"initial": 0.4, "grow": 4.0, "decay": 0.6, "opacity": 0.5, "tier": TIER_MID})
		"iron_prajiad":
			# Iron: an iron dome with gold facets, a metal sheen sweeping up it twice, iron
			# rings orbiting, glints on the steel, the jade light of the heal rising.
			layer("dome", false, IRON, Vector3.ZERO, Vector3(1.8, 2.0, 1.8), Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 4.0, "overshoot": true, "spin": 0.3, "decay": 0.75, "opacity": 0.8})
			layer("dome", true, GOLD, Vector3.ZERO, Vector3(1.83, 2.03, 1.83), Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 4.0, "overshoot": true, "spin": 0.3, "decay": 0.75, "opacity": 0.55})
			for k in 2:
				layer("band", true, [Color("9fb0c4"), Color("ffe9b0"), IRON[2]], Vector3.UP * 0.05, Vector3(1.78 - 0.35 * float(k), 0.3, 1.78 - 0.35 * float(k)), Vector3.ZERO, d + 0.15 + 0.3 * float(k), 0.5, {"initial": 1.0, "travel": Vector3(0, 1.25, 0), "accelerate": false, "decay": 0.6, "opacity": 0.5, "tier": TIER_CORE if k == 0 else TIER_MID})
			_orbit_rings(IRON, Vector3.ZERO, 4, 2.15, 0.9, d, 1.2, 0.36, 3.2)
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.035, Vector3.ONE * 1.8, Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 4.0, "spin": -0.6, "decay": 0.75, "opacity": 0.9, "tier": TIER_MID})
			for k in count(3):
				var a := float(k) * 2.3 + 0.6
				layer("star4", true, IRON, Vector3(sin(a) * 1.45, 0.8 + 0.3 * float(k), cos(a) * 1.45), Vector3.ONE * 0.42, Vector3.ZERO, d + 0.25 + 0.12 * float(k), 0.35, {"initial": 0.2, "grow": 8.0, "roll": 4.0, "billboard": true, "decay": 0.5, "opacity": 0.7, "tier": TIER_MID})
			# The heal: jade mantra glyphs rising round the fighter.
			_glyphs(JADE, Vector3.ZERO, 3, 0.75, 0.5, d + 0.1, 1.1, 0.34)
			layer("shock", true, IRON, Vector3.UP * 0.05, Vector3.ONE * 2.2, Vector3.ZERO, d, 0.5, {"initial": 0.2, "grow": 5.0, "decay": 0.5, "tier": TIER_DEBRIS})
		"thousand_ring_fist":
			# The rings close into one: a giant painted fist bound by three ประเจียด rings
			# snaps from the gathered circle onto the foe; on the blow the rings fly off.
			var gather := RING_GATHER
			var land := th + Vector3(0.65, 0.95, -0.3)
			var snap := 0.1
			_fist_blow(FIST, gather, land, d - 0.04, snap, 1.45, 0.42)
			for k in 3:
				var back := 0.2 + 0.28 * float(k)
				var lag := Vector3(0, 0, -back) * 1.45
				layer("prajiad", false, CLOTH, gather + lag, Vector3.ONE * (0.42 - 0.05 * float(k)), Vector3(PI * 0.5, 0, 0), d - 0.04, snap + 0.06, {"initial": 0.6, "grow": 8.0, "travel": land - gather, "snap": snap, "roll": 8.0, "decay": 0.85, "tier": TIER_CORE if k == 0 else TIER_MID})
			layer("burst", false, EMBER, land + Vector3(0, 0, 0.35), Vector3.ONE * 1.2, Vector3(0, 0, 0.6), d + snap, 0.4, {"initial": 0.3, "grow": 9.0, "roll": 1.0, "billboard": true, "decay": 0.5})
			for k in count(4):
				var a := TAU * float(k) / 4.0 + 0.4
				_ring_flight(EMBER, land + Vector3(cos(a) * 0.3, sin(a) * 0.3, -0.3), land + Vector3(cos(a) * 1.7, sin(a) * 1.3 + 0.2, -0.8), d + snap, 0.32, 0.34, false, TIER_MID)
			layer("shock", true, SUN, target + Vector3.UP * 0.05, Vector3.ONE * 2.4, Vector3.ZERO, d + snap, 0.55, {"initial": 0.15, "grow": 4.5, "decay": 0.5, "tier": TIER_MID})
			layer("crack", true, EMBER, target + Vector3.UP * 0.045, Vector3.ONE * 1.6, Vector3(0, randf() * TAU, 0), d + snap, 1.2, {"initial": 0.3, "grow": 9.0, "decay": 0.6, "tier": TIER_MID})
			layer("star4", true, SUN, land + Vector3(0, 0, 0.3), Vector3.ONE * 0.9, Vector3.ZERO, d + snap, 0.18, {"initial": 0.4, "grow": 10.0, "roll": 3.0, "billboard": true, "decay": 0.3, "opacity": 0.7, "tier": TIER_MID})
			_sparks(SUN, land, 6, d + snap, 1.3)
		"muay_king":
			# The king's landing: the fallen dragon and rings crash into a ยันต์ crater, the
			# king's giant fist hammers down out of the sky, a กนก burst, shockwaves and
			# cones of force roll out, fire and dust.
			_fist_blow(FIST, Vector3(0, 5.0, -0.2), Vector3(0, 1.5, 0), d - 0.04, 0.09, 2.1, 0.55)
			layer("yant", false, _lace(CLOTH), Vector3.UP * 0.045, Vector3.ONE * r * 0.75, Vector3.ZERO, d, 1.4, {"initial": 0.7, "grow": 9.0, "overshoot": true, "spin": 0.4, "decay": 0.68, "opacity": 0.95})
			layer("burst", false, SUN, Vector3(0, 1.1, 0.3), Vector3.ONE * 2.4, Vector3.ZERO, d + 0.05, 0.5, {"initial": 0.3, "grow": 8.0, "roll": 0.8, "billboard": true, "decay": 0.5})
			for k in 2:
				layer("shock", true, SUN if k == 0 else EMBER, Vector3.UP * (0.05 + 0.01 * float(k)), Vector3.ONE * r * (0.75 + 0.45 * float(k)), Vector3.ZERO, d + 0.05 + 0.1 * float(k), 0.6, {"initial": 0.1, "grow": 4.0, "decay": 0.5})
			layer("crack", true, EMBER, Vector3.UP * 0.05, Vector3.ONE * r * 0.75, Vector3(0, randf() * TAU, 0), d + 0.05, 1.3, {"initial": 0.2, "grow": 8.0, "decay": 0.65})
			_radial_cones(GOLD, Vector3.ZERO, 8, r * 0.65, d + 0.07)
			layer("crater", true, FLAME, Vector3.UP * 0.05, Vector3.ONE * r * 0.4, Vector3(0, randf() * TAU, 0), d + 0.05, 1.3, {"initial": 0.3, "grow": 8.0, "decay": 0.65, "tier": TIER_MID})
			_orbit_rings(CLOTH, Vector3.ZERO, 3, r * 0.45, 0.6, d + 0.05, 0.75, 0.45, 6.0)
			_flames(Vector3.ZERO, r * 0.6, 5, d + 0.08, 1.2, 0.9)
			layer("dust", true, DUST, Vector3.UP * 0.02, Vector3(r * 0.9, 1.0, r * 0.9), Vector3.ZERO, d + 0.06, 1.0, {"initial": 0.3, "grow": 3.0, "decay": 0.6, "opacity": 0.55, "tier": TIER_MID})
			_sparks(SUN, Vector3(0, 0.6, 0), 8, d + 0.05, 1.8)


## The rituals (ไหว้ครู, รำมวยบูชาครู, มงคลศักดิ์สิทธิ์), growing with [param tier]: the
## มงคล headband descends onto the fighter's head over a ยันต์ seal and a lotus, mantra
## script rising; at the top stage a second seal turns, glyphs orbit, a sun crowns it.
func _ritual(c: Array, d: float, tier: int) -> void:
	var big := 1.0 + 0.3 * float(tier)
	layer("headband", false, CLOTH, Vector3(0, 2.6 + 0.4 * float(tier), 0), Vector3.ONE * (0.4 + 0.1 * float(tier)), Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 3.0, "overshoot": true, "travel": Vector3(0, -(1.2 + 0.4 * float(tier)), 0), "spin": 2.0, "decay": 0.78})
	layer("yant", false, _lace(CLOTH), Vector3.UP * 0.035, Vector3.ONE * 1.5 * big, Vector3.ZERO, d, 1.5, {"initial": 0.3, "grow": 3.0, "spin": 0.6, "decay": 0.8, "opacity": 0.92})
	layer("script", true, c, Vector3(0, 0.1, 0), Vector3(0.95, 1.0, 0.95) * big, Vector3.ZERO, d, 1.3, {"initial": 0.5, "grow": 3.0, "spin": 1.4, "travel": Vector3(0, 1.4, 0), "decay": 0.7, "opacity": 0.65})
	if tier >= 1:
		layer("lotus", false, LOTUS, Vector3.UP * 0.05, Vector3.ONE * (0.95 + 0.3 * float(tier)), Vector3.ZERO, d, 1.3, {"initial": 0.2, "grow": 3.0, "overshoot": true, "spin": 0.5, "decay": 0.75, "opacity": 0.92})
		_glyphs(c, Vector3.ZERO, 3 + 2 * tier, 1.15 + 0.2 * float(tier), 2.4, d + 0.1, 1.2)
		_orbit_rings(CLOTH, Vector3.ZERO, 2, 1.0, 0.8, d, 1.2, 0.3, 3.4)
	if tier >= 2:
		layer("sun", false, SUN, _away * 0.9 + Vector3.UP * 3.9, Vector3.ONE * 1.05, Vector3.ZERO, d, 1.3, {"initial": 0.3, "grow": 3.0, "overshoot": true, "roll": 0.5, "billboard": true, "decay": 0.75, "opacity": 0.92})
		layer("yant", false, _lace(EMBER), Vector3.UP * 0.045, Vector3.ONE * 3.0, Vector3.ZERO, d + 0.05, 1.3, {"initial": 0.3, "grow": 3.0, "spin": -0.5, "decay": 0.8, "opacity": 0.75, "tier": TIER_MID})
		for k in count(3):
			var a := float(k) * 2.09 + 0.4
			layer("ray", true, GOLD, Vector3(sin(a), 0, cos(a)) * 1.5, Vector3(0.9, 5.0, 0.9), Vector3.ZERO, d + 0.1 * float(k), 1.0, {"initial": 0.3, "grow": 3.0, "fade_in": 0.2, "decay": 0.7, "opacity": 0.3, "tier": TIER_DEBRIS})
		layer("shock", true, SUN, Vector3.UP * 0.05, Vector3.ONE * 3.2, Vector3.ZERO, d, 0.6, {"initial": 0.2, "grow": 4.0, "decay": 0.5, "tier": TIER_DEBRIS})
	layer("halo", true, c, Vector3.UP * 0.03, Vector3.ONE * 1.2 * big, Vector3.ZERO, d, 0.9, {"initial": 0.4, "grow": 4.0, "decay": 0.6, "opacity": 0.5, "tier": TIER_MID})
	for k in count(2 + tier):
		var a := float(k) * 2.39996
		layer("star4", true, c, Vector3(sin(a) * 0.7, 0.4, cos(a) * 0.7), Vector3.ONE * 0.22, Vector3.ZERO, d + 0.08 * float(k), 1.0, {"initial": 0.3, "grow": 4.0, "travel": Vector3(0, 1.5, 0), "roll": 3.0, "billboard": true, "decay": 0.6, "tier": TIER_DEBRIS})


# ---------------------------------------------------------------------------
# Warm-up and the mesh library
# ---------------------------------------------------------------------------

static func warm_geometry() -> void:
	for kind in KINDS.split(" "):
		mesh(String(kind))


## Draws the paint and the spark light once, invisibly, so the first cast does not stall
## on a phone.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	if not _alive(parent):
		return
	var art := _root(parent, at, "MuayArt_Warm")
	art.cap = 2
	art.layer("fist_hero", false, FIST, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})
	art.layer("star4", true, EMBER, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001, "add": true})


static func mesh(kind: String) -> ArrayMesh:
	if kind in CASTER_KINDS:
		return CasterArt.mesh(kind)
	if kind in LORD_KINDS:
		return LordSkillArt.mesh(kind)
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"fist_hero": _fist_hero(st)
		"burst": _burst(st)
		"sun": _sun(st)
		"zap": _zap(st)
		"kanok": _kanok(st)
		"streak": _streak(st)
		"star4": _star4(st)
		"punch_ring": _punch_ring(st)
		"crack": _crack(st)
		"prajiad": _prajiad(st)
		"ribbon": _ribbon(st)
		"yant": _yant(st)
		"script": _script(st)
		"glyph": _glyph(st)
		"cone": _cone(st)
		"fire_wall": _fire_wall(st)
		"sweep": _sweep(st)
		"dragon": _dragon(st)
		"lotus": _lotus(st)
		"dome": _dome(st)
		"headband": _headband(st)
		"band": _band_mesh(st)
		"shock": _shock(st)
		_: _halo(st)
	var arrays := st.commit_to_arrays()
	var tone := float(TONE.get(kind, 1.0))
	if tone != 1.0:
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for k in colors.size():
			colors[k].r *= tone
		arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[kind] = result
	return result


## Drops the cached effect meshes and the idle materials (on travel). Live effects keep their own.
static func release_mesh_cache() -> void:
	_meshes.clear()
	_pool.clear()
	RamakienArt.release_figures()


static func _c(heat: float, mask := 1.0) -> Color:
	return Color(heat, mask, 0)


## A ring in the XY plane (facing +Z) from [param inner] to [param outer].
static func _xy_ring(st: SurfaceTool, inner: float, outer: float, c_in: Color, c_out: Color, seg := 48, z := 0.0) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(cos(a0), sin(a0), 0)
		var d1 := Vector3(cos(a1), sin(a1), 0)
		var off := Vector3(0, 0, z)
		_quad(st, d0 * inner + off, d1 * inner + off, d1 * outer + off, d0 * outer + off, c_in, c_in, c_out, c_out)


## A polyline of flat strips on the ground (XZ).
static func _ground_line(st: SurfaceTool, points: Array, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var n := points.size() - 1
	for k in n:
		var t0 := float(k) / float(n)
		var t1 := float(k + 1) / float(n)
		_strip(st, points[k], points[k + 1], lerpf(w0, w1, t0), Vector3.UP, c0.lerp(c1, t0), c0.lerp(c1, t1), lerpf(w0, w1, t1))


## A four-point glint (XY, radius 1) with four short diagonals.
static func _star4(st: SurfaceTool) -> void:
	for k in 8:
		var a := TAU * float(k) / 8.0 + PI * 0.5
		var long := k % 2 == 0
		var reach := 1.0 if long else 0.42
		var hw := 0.1 if long else 0.06
		var dir := Vector3(cos(a), sin(a), 0)
		var perp := Vector3(-sin(a), cos(a), 0)
		_tri(st, perp * hw, dir * reach, -perp * hw, _c(1.0), _c(0.4, 0.15), _c(1.0))
	BardSkillArt._oval(st, Vector2.ZERO, Vector2(0.14, 0.14), 0.0, _c(1.0), _c(0.9), 2.3, 0.01, 16)


## A punch's shock ring (XY, radius 1): a bright front, a soft wash inside, speed ticks out.
static func _punch_ring(st: SurfaceTool) -> void:
	_xy_ring(st, 0.9, 1.0, _c(0.75), _c(1.0), 56)
	_xy_ring(st, 1.0, 1.07, _c(1.0), _c(0.2, 0.0), 56)
	_xy_ring(st, 0.55, 0.9, _c(0.0, 0.0), _c(0.35, 0.5), 56)
	for k in 16:
		var a := TAU * float(k) / 16.0 + 0.1
		var dir := Vector3(cos(a), sin(a), 0)
		_strip(st, dir * 1.12, dir * (1.38 + 0.16 * float(k % 2)), 0.04, Vector3.BACK, _c(0.9), _c(0.3, 0.0), 0.006)


## Glowing cracks splitting the ground (XZ, radius 1) from a white-hot heart.
static func _crack(st: SurfaceTool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	for b in 8:
		var a := TAU * float(b) / 8.0 + rng.randf_range(-0.2, 0.2)
		var length := rng.randf_range(0.72, 1.0)
		var pts: Array = [Vector3(sin(a), 0, cos(a)) * 0.06 + Vector3.UP * 0.003]
		for s in 6:
			var t := float(s + 1) / 6.0
			var aa := a + rng.randf_range(-0.22, 0.22)
			pts.append(Vector3(sin(aa), 0, cos(aa)) * length * t + Vector3.UP * 0.003)
		_ground_line(st, pts, 0.075, 0.012, _c(1.0), _c(0.6, 0.85))
		for k in pts.size() - 1:
			var p: Vector3 = pts[k]
			var q: Vector3 = pts[k + 1]
			_strip(st, p - Vector3.UP * 0.002, q - Vector3.UP * 0.002, 0.2 * (1.0 - float(k) / 6.0) + 0.04, Vector3.UP, _c(0.35, 0.4), _c(0.1, 0.1))
		var fork: Vector3 = pts[3]
		var fa := a + (0.5 if b % 2 == 0 else -0.5)
		_ground_line(st, [fork, fork + Vector3(sin(fa), 0, cos(fa)) * 0.18, fork + Vector3(sin(fa + 0.2), 0, cos(fa + 0.2)) * 0.32], 0.035, 0.008, _c(0.9), _c(0.5, 0.7))
	BardSkillArt._ground_star(st, Vector3.UP * 0.004, 0.2, 0.08, _c(1.0), 8)


## A ประเจียด ring (XZ, radius 1): a tube of red cloth bound in gold, a knot at the back
## and its two tails streaming out behind.
static func _prajiad(st: SurfaceTool) -> void:
	var pts: Array = []
	var radii: Array = []
	var cols: Array = []
	for k in 49:
		var a := TAU * float(k) / 48.0
		pts.append(Vector3(sin(a), 0, cos(a)))
		radii.append(0.09)
		cols.append(_c(0.95) if k % 12 in [0, 1, 2] else _c(0.52))
	_tube(st, pts, radii, cols, 6)
	_sphere(st, Vector3(0, 0, -1), Vector3(0.15, 0.13, 0.13), _c(0.9), 4, 8)
	for s: float in [-1.0, 1.0]:
		var prev := Vector3(0, 0, -1.05)
		for k in 10:
			var t := float(k + 1) / 10.0
			var p := Vector3(s * (0.1 + 0.28 * t) + 0.07 * sin(t * 7.0) * s, -0.15 * t, -1.05 - 0.9 * t)
			_strip(st, prev, p, lerpf(0.16, 0.05, t - 0.1), Vector3.UP, _c(0.5 if k < 8 else 0.95), _c(0.48 if k < 8 else 0.95), lerpf(0.16, 0.05, t))
			prev = p


## A ประเจียด cloth ribbon (XY, from x 0 back along -X to -1, about 0.3 wide): two
## waving tails of red cloth with a gold hem, fading out at the end.
static func _ribbon(st: SurfaceTool) -> void:
	for twin in 2:
		var phase := float(twin) * 1.9
		var side_sign := 1.0 if twin == 0 else -0.8
		var prev := Vector3.ZERO
		var prev_w := 0.0
		for k in 20:
			var t := float(k + 1) / 20.0
			var p := Vector3(-t, 0.11 * sin(t * TAU * 1.3 + phase) * side_sign * t + 0.02 * float(twin), 0.0)
			var w := lerpf(0.17, 0.04, t) * (1.0 if twin == 0 else 0.7)
			var m0 := lerpf(1.0, 0.0, pow(float(k) / 20.0, 1.6))
			var m1 := lerpf(1.0, 0.0, pow(t, 1.6))
			_strip(st, prev + Vector3(0, 0, -0.002 * float(twin)), p + Vector3(0, 0, -0.002 * float(twin)), maxf(prev_w, 0.06) + 0.03, Vector3.BACK, _c(0.0, m0), _c(0.0, m1), w + 0.03)
			_strip(st, prev, p, maxf(prev_w, 0.06), Vector3.BACK, _c(0.52, m0), _c(0.46, m1), w)
			_strip(st, prev + Vector3(0, maxf(prev_w, 0.06) * 0.38, 0.002), p + Vector3(0, w * 0.38, 0.002), 0.025, Vector3.BACK, _c(0.95, m0), _c(0.95, m1), 0.018)
			prev = p
			prev_w = w


## A ยันต์ seal on the ground (XZ, radius 1): rings and a bead circle, two crossed
## squares, eight lotus petals, curling glyph marks and an unalome at the heart.
static func _yant(st: SurfaceTool) -> void:
	# A soft dark wash under the seal and a dark underlay under each line, so the line
	# work reads on a bright field.
	BardSkillArt._ground_ring(st, 0.0, 1.03, -0.002, _c(0.0, 0.16), _c(0.0, 0.1), 48)
	BardSkillArt._ground_ring(st, 0.95, 1.015, -0.001, _c(0.0), _c(0.0), 64)
	BardSkillArt._ground_ring(st, 0.87, 0.91, -0.001, _c(0.0), _c(0.0), 64)
	BardSkillArt._ground_ring(st, 0.965, 1.0, 0.0, _c(0.85), _c(0.85), 64)
	BardSkillArt._ground_ring(st, 0.88, 0.9, 0.0, _c(0.6), _c(0.6), 64)
	for k in 24:
		var a := TAU * float(k) / 24.0
		BardSkillArt._ground_star(st, Vector3(sin(a), 0.001, cos(a)) * 0.933, 0.025, 0.012, _c(1.0), 4, a)
	for turn: float in [0.0, PI * 0.25]:
		var corners: Array = []
		for k in 5:
			var a := turn + PI * 0.5 * float(k) + PI * 0.25
			corners.append(Vector3(sin(a), 0.001, cos(a)) * 0.86)
		_ground_line(st, _lowered(corners), 0.05, 0.05, _c(0.0), _c(0.0))
		_ground_line(st, corners, 0.024, 0.024, _c(0.7), _c(0.7))
	BardSkillArt._ground_ring(st, 0.37, 0.415, -0.001, _c(0.0), _c(0.0), 48)
	BardSkillArt._ground_ring(st, 0.38, 0.405, 0.0, _c(0.85), _c(0.85), 48)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var petal: Array = []
		for j in 9:
			var t := float(j) / 8.0
			petal.append(Vector3(sin(a), 0, cos(a)) * lerpf(0.42, 0.72, t) + Vector3(cos(a), 0, -sin(a)) * sin(PI * t) * 0.13 + Vector3.UP * 0.002)
		for j in range(8, -1, -1):
			var t := float(j) / 8.0
			petal.append(Vector3(sin(a), 0, cos(a)) * lerpf(0.42, 0.72, t) - Vector3(cos(a), 0, -sin(a)) * sin(PI * t) * 0.13 + Vector3.UP * 0.002)
		_ground_line(st, _lowered(petal), 0.042, 0.042, _c(0.0), _c(0.0))
		_ground_line(st, petal, 0.02, 0.02, _c(0.92), _c(0.92))
		# A curling mark between the petals, out by the squares.
		var b := a + PI / 8.0
		var curl: Array = []
		for j in 9:
			var t := float(j) / 8.0
			var ang := b + 0.5 * sin(t * PI * 1.5)
			curl.append(Vector3(sin(ang), 0.002, cos(ang)) * (0.79 - 0.06 * t) + Vector3(cos(b), 0, -sin(b)) * 0.03 * cos(t * 9.0))
		_ground_line(st, _lowered(curl), 0.036, 0.026, _c(0.0), _c(0.0))
		_ground_line(st, curl, 0.016, 0.008, _c(0.95), _c(0.7))
	var spiral: Array = []
	for j in 16:
		var t := float(j) / 15.0
		var ang := t * PI * 3.0
		spiral.append(Vector3(sin(ang), 0, cos(ang)) * (0.13 * (1.0 - t) + 0.02) + Vector3(0, 0.003, -0.08))
	spiral.append(Vector3(0, 0.003, 0.05))
	spiral.append(Vector3(0.05, 0.003, 0.12))
	spiral.append(Vector3(-0.04, 0.003, 0.19))
	spiral.append(Vector3(0, 0.003, 0.27))
	_ground_line(st, _lowered(spiral), 0.046, 0.04, _c(0.0), _c(0.0))
	_ground_line(st, spiral, 0.022, 0.016, _c(1.0), _c(1.0))
	for k in 3:
		BardSkillArt._ground_star(st, Vector3(0, 0.003, 0.31 + 0.035 * float(k)), 0.018, 0.012, _c(1.0), 4)


## The points dropped a hair (the dark underlay of a seal's line).
static func _lowered(points: Array) -> Array:
	var out: Array = []
	for p in points:
		out.append((p as Vector3) - Vector3.UP * 0.0015)
	return out


## Mantra script round an upright band (radius 1, y 0-0.35): loops with tails, lines
## above and below, like a ring of written ยันต์.
static func _script(st: SurfaceTool) -> void:
	for y: float in [0.0, 0.35]:
		BardSkillArt._band(st, 1.0, y - 0.01, y + 0.01, _c(0.8), _c(0.8), 48)
	BardSkillArt._band(st, 1.0, 0.0, 0.35, _c(0.15, 0.2), _c(0.15, 0.2), 48)
	for k in 18:
		var base := TAU * float(k) / 18.0
		var strokes: Array = []
		# A loop low in the line, then a tail rising and hooking over.
		for j in 9:
			var t := float(j) / 8.0
			strokes.append(Vector2(0.035 * cos(t * TAU) + 0.0, 0.08 + 0.035 * sin(t * TAU)))
		var shape := k % 3
		for j in 7:
			var t := float(j) / 6.0
			match shape:
				0: strokes.append(Vector2(0.035 + 0.03 * t, 0.08 + 0.2 * t))
				1: strokes.append(Vector2(0.035 + 0.05 * sin(t * PI), 0.08 + 0.18 * t))
				_: strokes.append(Vector2(0.035 + 0.07 * t, 0.08 + 0.15 * sin(t * PI * 0.8)))
		var prev := Vector3.ZERO
		for j in strokes.size():
			var uv: Vector2 = strokes[j]
			var ang := base + uv.x
			var p := Vector3(sin(ang), 0, cos(ang)) * 1.003 + Vector3.UP * uv.y
			if j > 0 and j != 9:
				_strip(st, prev, p, 0.016, Vector3(sin(ang), 0, cos(ang)), _c(1.0), _c(1.0))
			prev = p


## One mantra glyph (XY, y 0-1.3): an unalome, a spiral rising into a wavering line
## and three dots of light, over a soft glow.
static func _glyph(st: SurfaceTool) -> void:
	var pts: Array = []
	for j in 18:
		var t := float(j) / 17.0
		var ang := t * PI * 3.2
		pts.append(Vector2(sin(ang), -cos(ang)) * (0.2 * (1.0 - t) + 0.02) + Vector2(0, 0.22))
	for p in [Vector2(0, 0.36), Vector2(0.09, 0.46), Vector2(-0.07, 0.56), Vector2(0.06, 0.66), Vector2(-0.03, 0.76), Vector2(0, 0.95)]:
		pts.append(p)
	BardSkillArt._polyline(st, pts, 0.06, 0.04, _c(1.0), _c(0.9))
	BardSkillArt._polyline(st, pts, 0.2, 0.14, _c(0.3, 0.35), _c(0.2, 0.2), -0.004)
	for k in 3:
		BardSkillArt._oval(st, Vector2(0, 1.05 + 0.11 * float(k)), Vector2(0.04, 0.04), 0.0, _c(1.0), _c(0.8), 1.8, 0.0, 10)


## A cone of force (apex at the origin, along +Z, length 1, mouth radius 0.55): a soft
## shell, streaks and a bright mouth ring.
static func _cone(st: SurfaceTool) -> void:
	var seg := 24
	for k in seg:
		var a0 := TAU * float(k) / float(seg)
		var a1 := TAU * float(k + 1) / float(seg)
		var m0 := Vector3(cos(a0) * 0.55, sin(a0) * 0.55, 1.0)
		var m1 := Vector3(cos(a1) * 0.55, sin(a1) * 0.55, 1.0)
		_tri(st, Vector3.ZERO, m0, m1, _c(0.0, 0.0), _c(0.55, 0.6), _c(0.55, 0.6))
		_quad(st, m0, m1, m1 * Vector3(1.14, 1.14, 1.0), m0 * Vector3(1.14, 1.14, 1.0), _c(1.0), _c(1.0), _c(0.3, 0.0), _c(0.3, 0.0))
		if k % 3 == 0:
			_strip(st, m0 * 0.25, m0, 0.03, Vector3(cos(a0), sin(a0), 0), _c(0.2, 0.0), _c(0.95), 0.045)


## A wall of fire (upright, radius 1, height ~1): a bright foot, ragged tongues.
static func _fire_wall(st: SurfaceTool) -> void:
	var seg := 48
	for k in seg:
		var a0 := TAU * float(k) / float(seg)
		var a1 := TAU * float(k + 1) / float(seg)
		var h0 := 0.45 + 0.25 * absf(sin(a0 * 5.0 + 0.7)) + 0.1 * sin(a0 * 13.0)
		var h1 := 0.45 + 0.25 * absf(sin(a1 * 5.0 + 0.7)) + 0.1 * sin(a1 * 13.0)
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0, d1, d1 + Vector3.UP * h1, d0 + Vector3.UP * h0, _c(0.85), _c(0.85), _c(0.1, 0.0), _c(0.1, 0.0))
		if k % 2 == 0:
			var mid := (d0 + d1) * 0.5
			var tip := mid * 1.02 + Vector3.UP * (h0 + 0.35 + 0.25 * absf(sin(a0 * 3.0)))
			_tri(st, d0 + Vector3.UP * 0.05, tip, d1 + Vector3.UP * 0.05, _c(0.6), _c(0.0, 0.2), _c(0.6))


## A crescent sweep on the ground plane (XZ, radius 1, 300°): thin tail, a heavy
## bright head at the end (positive spin leads with the head).
static func _sweep(st: SurfaceTool) -> void:
	var seg := 44
	var span := deg_to_rad(300.0)
	for k in seg:
		var t0 := float(k) / float(seg)
		var t1 := float(k + 1) / float(seg)
		var a0 := span * t0
		var a1 := span * t1
		var w0 := lerpf(0.02, 0.3, t0 * t0)
		var w1 := lerpf(0.02, 0.3, t1 * t1)
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0 * (1.0 - w0), d1 * (1.0 - w1), d1, d0, _c(t0 * 0.4, t0), _c(t1 * 0.4, t1), _c(t1, t1), _c(t0, t0))
		_quad(st, d0, d1, d1 * 1.04, d0 * 1.04, _c(t0, t0), _c(t1, t1), _c(0.2, 0.0), _c(0.2, 0.0))
	for k in 3:
		var r := 1.1 + 0.08 * float(k)
		var from := span * (0.55 + 0.1 * float(k))
		var pts: Array = []
		for j in 7:
			var a := lerpf(from, span, float(j) / 6.0)
			pts.append(Vector3(sin(a), 0, cos(a)) * r)
		_ground_line(st, pts, 0.01, 0.03, _c(0.2, 0.0), _c(0.9, 0.9))


## A dragon coiling round a ring (radius ~1, y 0.2-0.75): a scaled body thickening to
## the head, dorsal fins and fire licks, a horned head with whiskers leading the coil.
static func _dragon(st: SurfaceTool) -> void:
	var n := 52
	var pts: Array = []
	var radii: Array = []
	var cols: Array = []
	for k in n:
		var t := float(k) / float(n - 1)
		var a := t * PI * 2.6
		var rr := 1.0 + 0.1 * sin(t * 3.0 * TAU)
		pts.append(Vector3(sin(a) * rr, 0.15 + 0.85 * t + 0.16 * sin(t * 3.5 * TAU), cos(a) * rr))
		radii.append(0.02 + 0.15 * pow(t, 0.55))
		cols.append(_c(0.5 + 0.12 * sin(t * 90.0) + 0.1 * t))
	_tube(st, pts, radii, cols, 6)
	for k in range(4, n - 2):
		var p: Vector3 = pts[k]
		var tangent := ((pts[k + 1] as Vector3) - (pts[k - 1] as Vector3)).normalized()
		var r := float(radii[k])
		if k % 2 == 0:
			_tri(st, p - tangent * r * 0.6 + Vector3.UP * r * 0.6, p - tangent * r * 1.4 + Vector3.UP * r * 1.9, p + tangent * r * 0.6 + Vector3.UP * r * 0.6, _c(0.9), _c(0.2), _c(0.9))
		if k % 3 == 0:
			var out := Vector3(p.x, 0, p.z).normalized()
			_tri(st, p - tangent * r + out * r * 0.5, p + out * r * 2.4 - tangent * r * 1.5 - Vector3.UP * r * 0.5, p + tangent * r * 0.3 + out * r * 0.5, _c(0.75), _c(0.15, 0.8), _c(0.75))
	var head: Vector3 = pts[n - 1]
	var fwd := (head - (pts[n - 3] as Vector3)).normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var up := side.cross(fwd).normalized()
	_sphere(st, head + fwd * 0.05 + up * 0.03, Vector3.ONE * 0.15, _c(0.6), 4, 8)
	_tube(st, [head + fwd * 0.08 + up * 0.05, head + fwd * 0.36 + up * 0.03], [0.11, 0.06], [_c(0.6), _c(0.7)], 6)
	_tube(st, [head + fwd * 0.06 - up * 0.05, head + fwd * 0.3 - up * 0.14], [0.07, 0.03], [_c(0.3), _c(0.35)], 5)
	for s: float in [-1.0, 1.0]:
		_sphere(st, head + fwd * 0.13 + up * 0.11 + side * s * 0.08, Vector3.ONE * 0.04, _c(0.0), 3, 6)
		_tube(st, [head + up * 0.1 + side * s * 0.06, head + up * 0.3 - fwd * 0.16 + side * s * 0.12, head + up * 0.38 - fwd * 0.34 + side * s * 0.1], [0.035, 0.02, 0.005], [_c(1.0), _c(1.0), _c(1.0)], 4)
		_tube(st, [head + fwd * 0.33 + side * s * 0.05, head + fwd * 0.26 + side * s * 0.25 - up * 0.05, head + fwd * 0.05 + side * s * 0.42 + up * 0.05, head - fwd * 0.22 + side * s * 0.46 + up * 0.16], [0.02, 0.014, 0.008, 0.003], [_c(1.0), _c(1.0), _c(0.9), _c(0.6)], 4)
	for k in 5:
		var spread := (float(k) - 2.0) * 0.07
		_tri(st, head - fwd * 0.02 + up * 0.08 + side * spread, head - fwd * 0.42 + up * (0.12 + 0.05 * float(k % 2)) + side * spread * 2.4, head - fwd * 0.1 + up * 0.02 + side * spread, _c(0.85), _c(0.2, 0.8), _c(0.85))


## A lotus in bloom (upright, base at y 0, radius ~1): eight outer petals leaning
## out, eight inner ones nearly upright, a glowing heart.
static func _lotus(st: SurfaceTool) -> void:
	for row in 2:
		var lean := 0.95 if row == 0 else 0.45
		var length := 0.85 if row == 0 else 0.62
		var width := 0.3 if row == 0 else 0.22
		for k in 8:
			var a := TAU * float(k) / 8.0 + (PI / 8.0 if row == 1 else 0.0)
			var out := Vector3(sin(a), 0, cos(a))
			var across := Vector3(cos(a), 0, -sin(a))
			var axis := (out * sin(lean) + Vector3.UP * cos(lean)).normalized()
			var base := out * 0.12
			var prev_l := base
			var prev_r := base
			for j in 8:
				var t := float(j + 1) / 8.0
				var w := sin(PI * minf(t * 0.95, 1.0)) * width * (1.0 - 0.25 * t)
				var mid := base + axis * length * t + out * 0.08 * t * t
				var l := mid - across * w
				var r := mid + across * w
				var heat := 0.42 + 0.5 * t
				var edge := heat - 0.3
				_quad(st, prev_l, base + axis * length * (t - 0.125), mid, l, _c(edge), _c(heat), _c(heat), _c(edge))
				_quad(st, base + axis * length * (t - 0.125), prev_r, r, mid, _c(heat), _c(edge), _c(edge), _c(heat))
				prev_l = l
				prev_r = r
	_sphere(st, Vector3.UP * 0.12, Vector3(0.16, 0.12, 0.16), _c(0.95), 4, 10)


## A shield dome (hemisphere, radius 1): a faint shell, a hex-like lattice of offset
## facets, a band of pointed กนก flame petals round its foot and a bud at the crown.
static func _dome(st: SurfaceTool) -> void:
	var rows := 7
	var seg := 24
	for j in rows:
		var p0 := PI * 0.5 * float(j) / float(rows)
		var p1 := PI * 0.5 * float(j + 1) / float(rows)
		for k in seg:
			var a0 := TAU * float(k) / float(seg)
			var a1 := TAU * float(k + 1) / float(seg)
			var v00 := _dome_point(p0, a0)
			var v01 := _dome_point(p0, a1)
			var v11 := _dome_point(p1, a1)
			var v10 := _dome_point(p1, a0)
			_quad(st, v00, v01, v11, v10, _c(0.42, 0.3 - 0.025 * float(j)), _c(0.42, 0.3 - 0.025 * float(j)), _c(0.42, 0.275 - 0.025 * float(j)), _c(0.42, 0.275 - 0.025 * float(j)))
	for j in range(1, rows - 1):
		var phi := PI * 0.5 * float(j) / float(rows)
		var ring: Array = []
		for k in seg + 1:
			ring.append(_dome_point(phi, TAU * float(k) / float(seg)))
		for k in seg:
			_strip(st, ring[k], ring[k + 1], 0.032, (ring[k] as Vector3).normalized(), _c(0.9), _c(0.9))
		var phi1 := PI * 0.5 * float(j + 1) / float(rows)
		var cells := 12 if j < 4 else 6
		for k in cells:
			var a := TAU * (float(k) + 0.5 * float(j % 2)) / float(cells)
			var lo := _dome_point(phi, a)
			var hi := _dome_point(phi1, a)
			_strip(st, lo, hi, 0.032, lo.normalized(), _c(0.9), _c(0.9))
	for k in 12:
		var a0 := TAU * float(k) / 12.0
		var a1 := TAU * float(k + 1) / 12.0
		var am := (a0 + a1) * 0.5
		var arch: Array = [_dome_point(0.0, a0), _dome_point(0.12, lerpf(a0, am, 0.45)), _dome_point(0.26, am - 0.05), _dome_point(0.36, am), _dome_point(0.26, am + 0.05), _dome_point(0.12, lerpf(a1, am, 0.45)), _dome_point(0.0, a1)]
		for i in arch.size() - 1:
			_strip(st, arch[i], arch[i + 1], 0.03, (arch[i] as Vector3).normalized(), _c(1.0), _c(1.0))
		_strip(st, _dome_point(0.02, am), _dome_point(0.2, am), 0.024, _dome_point(0.1, am).normalized(), _c(0.9), _c(0.6))
	_sphere(st, Vector3.UP * 1.0, Vector3(0.07, 0.11, 0.07), _c(1.0), 4, 8)
	BardSkillArt._ground_ring(st, 0.98, 1.04, 0.01, _c(1.0), _c(0.3, 0.0), 48)


static func _dome_point(phi: float, a: float) -> Vector3:
	return Vector3(sin(a) * cos(phi), sin(phi), cos(a) * cos(phi))


## The มงคล headband (XZ, radius 1): a twisted two-strand rope of light, a knot at the
## back and its tail curling down behind.
static func _headband(st: SurfaceTool) -> void:
	for strand in 2:
		var pts: Array = []
		var radii: Array = []
		var cols: Array = []
		for k in 61:
			var a := TAU * float(k) / 60.0
			var radial := Vector3(sin(a), 0, cos(a))
			var twist := a * 9.0 + PI * float(strand)
			pts.append(radial + (radial * cos(twist) + Vector3.UP * sin(twist)) * 0.06)
			radii.append(0.045)
			cols.append(_c(0.97 if strand == 0 else 0.52))
		_tube(st, pts, radii, cols, 5)
	_sphere(st, Vector3(0, 0, -1.02), Vector3(0.13, 0.12, 0.12), _c(0.95), 4, 8)
	# Gold beads where the strands are bound, round the crown.
	for k in 6:
		var a := TAU * (float(k) + 0.5) / 6.0
		_sphere(st, Vector3(sin(a), 0, cos(a)), Vector3.ONE * 0.075, _c(0.9), 3, 6)
	var tail: Array = []
	var tr: Array = []
	var tc: Array = []
	for k in 9:
		var t := float(k) / 8.0
		tail.append(Vector3(0.12 * sin(t * 4.0), -0.8 * t, -1.05 - 0.35 * t - 0.15 * sin(t * PI)))
		tr.append(lerpf(0.06, 0.015, t))
		tc.append(_c(0.52 if k < 7 else 0.95))
	_tube(st, tail, tr, tc, 5)


## An upright glowing belt (radius 1, y 0-1, hot in the middle): a sheen sweeping up.
static func _band_mesh(st: SurfaceTool) -> void:
	BardSkillArt._band(st, 1.0, 0.0, 0.5, _c(0.0, 0.0), _c(1.0), 48)
	BardSkillArt._band(st, 1.0, 0.5, 1.0, _c(1.0), _c(0.0, 0.0), 48)


## A shockwave on the ground (XZ, radius 1): a crisp bright front, a wash trailing
## inwards, a faint outer echo and grit thrown off the front.
static func _shock(st: SurfaceTool) -> void:
	BardSkillArt._ground_ring(st, 0.55, 0.93, 0.0, _c(0.0, 0.0), _c(0.45, 0.45), 56)
	BardSkillArt._ground_ring(st, 0.93, 1.0, 0.0, _c(0.8), _c(1.0), 56)
	BardSkillArt._ground_ring(st, 1.0, 1.035, 0.0, _c(1.0), _c(0.2, 0.0), 56)
	BardSkillArt._ground_ring(st, 0.8, 0.82, 0.001, _c(0.6, 0.6), _c(0.6, 0.6), 56)
	for k in 24:
		var a := TAU * (float(k) + 0.3 * sin(float(k) * 2.1)) / 24.0
		var dir := Vector3(sin(a), 0.002, cos(a))
		_strip(st, dir * 1.04, dir * (1.1 + 0.05 * float(k % 3)), 0.03, Vector3.UP, _c(0.9), _c(0.3, 0.0), 0.005)


## A soft halo on the ground (XZ, radius 1).
static func _halo(st: SurfaceTool) -> void:
	BardSkillArt._ground_ring(st, 0.72, 0.97, 0.0, _c(0.0, 0.0), _c(0.7, 0.75), 48)
	BardSkillArt._ground_ring(st, 0.97, 1.0, 0.0, _c(0.7, 0.75), _c(1.0), 48)
	BardSkillArt._ground_ring(st, 1.0, 1.22, 0.0, _c(1.0), _c(0.0, 0.0), 48)
## A rounded box / ellipse outline (superellipse of [param power]) round [param centre],
## grown by [param grow] (an outline pass), turned by [param tilt].
static func _rounded(centre: Vector2, radii: Vector2, power: float, n: int, grow := 0.0, tilt := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var cs := cos(a)
		var sn := sin(a)
		var p := Vector2(signf(cs) * pow(absf(cs), 2.0 / power) * (radii.x + grow), signf(sn) * pow(absf(sn), 2.0 / power) * (radii.y + grow))
		out.append(centre + p.rotated(tilt))
	return out


## A filled polygon (a fan from [param centre]) in the XY plane at depth [param z]; the
## rim colour may run from [param top] (high y) to [param bottom] (low y).
static func _fill(st: SurfaceTool, pts: PackedVector2Array, centre: Vector2, cc: Color, top: Color, bottom := Color(-1, 0, 0), z := 0.0) -> void:
	var n := pts.size()
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var span := maxf(hi - lo, 0.0001)
	for k in n:
		var a := pts[k]
		var b := pts[(k + 1) % n]
		var ca := top if bottom.r < 0.0 else bottom.lerp(top, (a.y - lo) / span)
		var cb := top if bottom.r < 0.0 else bottom.lerp(top, (b.y - lo) / span)
		_tri(st, Vector3(centre.x, centre.y, z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), cc, ca, cb)


## A stroke along [param pts] (XY) of width [param w], tones from c0 to c1.
static func _stroke(st: SurfaceTool, pts: Array, w0: float, w1: float, c0: Color, c1: Color, z := 0.0) -> void:
	var n := pts.size() - 1
	for k in n:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		_strip(st, Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), lerpf(w0, w1, float(k) / float(n)), Vector3.BACK, c0.lerp(c1, float(k) / float(n)), c0.lerp(c1, float(k + 1) / float(n)), lerpf(w0, w1, float(k + 1) / float(n)))


## A disc (XY) with a dark outline ring under it.
static func _dot(st: SurfaceTool, at: Vector2, radius: float, tone: float, outline: float, z := 0.0, seg := 14) -> void:
	if outline > 0.0:
		_fill(st, _rounded(at, Vector2.ONE * radius, 2.0, seg, outline), at, _c(0.0), _c(0.0), Color(-1, 0, 0), z)
	_fill(st, _rounded(at, Vector2.ONE * radius, 2.0, seg), at, _c(minf(tone + 0.08, 1.0)), _c(tone), Color(-1, 0, 0), z + 0.002)


## กนก flame petals: each spec [base, tip, width, curl] a tongue that swells from its base
## and hooks over at the tip ([param curl], signed). Drawn pass by pass over all of them
## so the outlines sit under every body: a dark outline, the body, a hot inner tongue.
## [param tones]: [outline, body base, body tip, inner].
static func _tongues(st: SurfaceTool, specs: Array, z: float, tones: Array, outline := 0.045, tip_mask := 1.0) -> void:
	for pass_i in 3:
		for spec in specs:
			var base: Vector2 = spec[0]
			var tip: Vector2 = spec[1]
			var width: float = spec[2]
			var curl: float = spec[3]
			var dir := (tip - base)
			var length := dir.length()
			dir = dir / maxf(length, 0.0001)
			var perp := Vector2(-dir.y, dir.x)
			var reach := 1.0 if pass_i < 2 else 0.68
			var grow := outline if pass_i == 0 else 0.0
			var wscale := 1.0 if pass_i < 2 else 0.42
			var seg := 12
			var prev_l := Vector2.ZERO
			var prev_r := Vector2.ZERO
			var prev_c := Color()
			for j in seg + 1:
				var t := float(j) / float(seg) * reach
				var bend := curl * length * (0.14 * sin(PI * t) + 0.3 * pow(maxf(t - 0.55, 0.0) / 0.45, 2.0))
				var centre := base + dir * length * t + perp * bend
				var t2 := minf(t + 0.02, 1.0)
				var ahead := base + dir * length * t2 + perp * curl * length * (0.14 * sin(PI * t2) + 0.3 * pow(maxf(t2 - 0.55, 0.0) / 0.45, 2.0))
				var along := (ahead - centre).normalized() if j < seg else dir
				var side := Vector2(-along.y, along.x)
				var w := width * wscale * pow(sin(PI * (0.1 + 0.9 * minf(t / reach, 1.0))), 0.75) * pow(1.0 - minf(t / reach, 1.0), 0.3) + grow
				if pass_i == 0:
					centre -= dir * grow * (1.0 - t)
				var l := centre + side * w
				var r := centre - side * w
				var tone: float
				match pass_i:
					0: tone = float(tones[0])
					1: tone = lerpf(float(tones[1]), float(tones[2]), t)
					_: tone = float(tones[3])
				var col := _c(tone, lerpf(1.0, tip_mask, t) if pass_i > 0 else lerpf(1.0, tip_mask, t * t))
				if j > 0:
					_quad(st, Vector3(prev_l.x, prev_l.y, z), Vector3(l.x, l.y, z), Vector3(r.x, r.y, z), Vector3(prev_r.x, prev_r.y, z), prev_c, col, col, prev_c)
				prev_l = l
				prev_r = r
				prev_c = col
		z += 0.003


## The hero fist (XY, side view, knuckles leading along +X, about 2.3 long): a short
## กนก flame trail off the forearm, a heavy dark outline, a cel-shaded clenched hand,
## four folded fingers stacked at its front (each outlined), the thumb locked across
## them, a gold knuckle-duster with four studs over the knuckles, a wrapped cuff of
## ประเจียด cloth at the wrist and a small ยันต์ mark on the back of the hand.
static func _fist_hero(st: SurfaceTool) -> void:
	# The flame trail, behind everything.
	_tongues(st, [[Vector2(-0.62, 0.15), Vector2(-1.25, 0.4), 0.16, -0.6], [Vector2(-0.68, 0.0), Vector2(-1.45, 0.02), 0.2, 0.4], [Vector2(-0.62, -0.15), Vector2(-1.18, -0.36), 0.15, 0.6]], -0.03, [0.0, 0.6, 0.4, 0.9], 0.05, 0.55)
	var hand := Vector2(-0.02, 0.0)
	var cuff := Vector2(-0.6, -0.01)
	var fingers: Array = []
	for k in 4:
		# Index finger on top, a little longer; the little finger shortest.
		fingers.append([Vector2(0.3 - 0.025 * float(k), 0.27 - 0.165 * float(k)), Vector2(0.25 - 0.015 * float(k), 0.088)])
	var thumb := Vector2(0.08, -0.25)
	# The outline: everything grown together in the shade.
	_fill(st, _rounded(cuff, Vector2(0.2, 0.27), 4.0, 24, 0.07), cuff, _c(0.0), _c(0.0))
	_fill(st, _rounded(hand, Vector2(0.46, 0.42), 3.2, 36, 0.075), hand, _c(0.0), _c(0.0))
	for f in fingers:
		_fill(st, _rounded(f[0], f[1], 3.0, 20, 0.07), f[0], _c(0.0), _c(0.0))
	_fill(st, _rounded(Vector2(0.55, 0.02), Vector2(0.07, 0.4), 4.0, 24, 0.07), Vector2(0.55, 0.02), _c(0.0), _c(0.0))
	# The cuff: cream cloth turns bound over the wrist, a dark seam each side.
	_fill(st, _rounded(cuff, Vector2(0.2, 0.27), 4.0, 24), cuff, _c(0.86), _c(0.95), _c(0.7), 0.004)
	for k in 2:
		var x := -0.74 + 0.16 * float(k)
		_quad(st, Vector3(x, -0.25, 0.006), Vector3(x + 0.05, -0.25, 0.006), Vector3(x + 0.12, 0.25, 0.006), Vector3(x + 0.07, 0.25, 0.006), _c(0.45), _c(0.45), _c(0.5), _c(0.5))
	# The back of the hand: lit from above.
	_fill(st, _rounded(hand, Vector2(0.46, 0.42), 3.2, 36), hand, _c(0.58), _c(0.72), _c(0.34), 0.01)
	_stroke(st, [Vector2(-0.36, 0.3), Vector2(-0.15, 0.37), Vector2(0.06, 0.37)], 0.055, 0.03, _c(0.92), _c(0.96), 0.012)
	# The folded fingers, each outlined by the gap to the next, a light top edge.
	var z := 0.014
	for f in fingers:
		var at: Vector2 = f[0]
		var radii: Vector2 = f[1]
		_fill(st, _rounded(at, radii + Vector2(0.025, 0.02), 3.0, 20), at, _c(0.05), _c(0.05), Color(-1, 0, 0), z)
		_fill(st, _rounded(at, radii, 3.0, 20), at + Vector2(0, 0.02), _c(0.64), _c(0.78), _c(0.44), z + 0.002)
		_stroke(st, [at + Vector2(-radii.x * 0.7, radii.y * 0.55), at + Vector2(radii.x * 0.55, radii.y * 0.6)], 0.022, 0.016, _c(0.95), _c(0.95), z + 0.004)
		z += 0.006
	# The thumb locked across the lower fingers: outlined, a nail at its tip.
	_fill(st, _rounded(thumb, Vector2(0.27, 0.1), 2.6, 24, 0.05, 0.12), thumb, _c(0.0), _c(0.0), Color(-1, 0, 0), 0.05)
	_fill(st, _rounded(thumb, Vector2(0.27, 0.1), 2.6, 24, 0.0, 0.12), thumb + Vector2(0, 0.02), _c(0.66), _c(0.8), _c(0.46), 0.052)
	_fill(st, _rounded(thumb + Vector2(0.2, 0.03), Vector2(0.065, 0.05), 2.0, 12, 0.0, 0.12), thumb + Vector2(0.2, 0.03), _c(0.96), _c(0.86), Color(-1, 0, 0), 0.054)
	# The gold knuckle-duster over the knuckles: the bar, its shine, four studs.
	_fill(st, _rounded(Vector2(0.55, 0.02), Vector2(0.07, 0.4), 4.0, 24), Vector2(0.55, 0.02), _c(0.9), _c(0.98), _c(0.76), 0.06)
	_strip(st, Vector3(0.53, -0.3, 0.062), Vector3(0.53, 0.36, 0.062), 0.022, Vector3.BACK, _c(1.0), _c(1.0))
	for k in 4:
		var y := 0.29 - 0.18 * float(k)
		_fill(st, _rounded(Vector2(0.65, y), Vector2(0.065, 0.065), 2.0, 14, 0.04), Vector2(0.65, y), _c(0.0), _c(0.0), Color(-1, 0, 0), 0.064)
		_fill(st, _rounded(Vector2(0.65, y), Vector2(0.065, 0.065), 2.0, 14), Vector2(0.64, y + 0.02), _c(1.0), _c(0.88), _c(0.72), 0.066)
	# A ยันต์ mark on the back of the hand: an unalome curl rising into a line, three dots.
	var mark: Array = []
	for j in 10:
		var t := float(j) / 9.0
		var ang := t * PI * 2.6
		mark.append(Vector2(-0.22, 0.02) + Vector2(sin(ang), -cos(ang)) * 0.06 * (1.0 - t) + Vector2(0.0, 0.03 * t))
	mark.append(Vector2(-0.2, 0.09))
	mark.append(Vector2(-0.24, 0.14))
	mark.append(Vector2(-0.2, 0.19))
	_stroke(st, mark, 0.024, 0.018, _c(0.1), _c(0.1), 0.07)
	for k in 3:
		var p := Vector2(-0.3 + 0.07 * float(k), 0.25 + 0.012 * float(k % 2))
		_fill(st, _rounded(p, Vector2.ONE * 0.018, 2.0, 8), p, _c(0.1), _c(0.1), Color(-1, 0, 0), 0.07)


## A กนก impact burst (XY, radius 1): ten flame-petal spikes turning one way round a hot
## heart, each outlined; a ring of gold between them.
static func _burst(st: SurfaceTool) -> void:
	var specs: Array = []
	for k in 10:
		var a := TAU * float(k) / 10.0
		var long := k % 2 == 0
		var dir := Vector2(cos(a), sin(a))
		specs.append([dir * 0.2, dir * (1.0 if long else 0.66), 0.2 if long else 0.15, 0.45])
	_tongues(st, specs, 0.0, [0.0, 0.62, 0.48, 0.95], 0.05)
	_fill(st, _rounded(Vector2.ZERO, Vector2.ONE * 0.36, 2.0, 28, 0.05), Vector2.ZERO, _c(0.0), _c(0.0), Color(-1, 0, 0), 0.012)
	_fill(st, _rounded(Vector2.ZERO, Vector2.ONE * 0.36, 2.0, 28), Vector2.ZERO, _c(1.0), _c(0.75), Color(-1, 0, 0), 0.014)
	_xy_ring(st, 0.25, 0.28, _c(0.5), _c(0.5), 32, 0.016)
	for k in 8:
		var a := TAU * (float(k) + 0.5) / 8.0
		var dir := Vector2(cos(a), sin(a))
		_fill(st, _rounded(dir * 0.13, Vector2(0.045, 0.045), 2.0, 8), dir * 0.13, _c(0.62), _c(0.62), Color(-1, 0, 0), 0.018)


## The rising sun (XY, radius 1): sixteen กนก flame petals round a disc of light, a
## dark rim, a ring and an eight-petal lotus seal at its heart.
static func _sun(st: SurfaceTool) -> void:
	var specs: Array = []
	for k in 16:
		var a := TAU * float(k) / 16.0
		var dir := Vector2(cos(a), sin(a))
		var long := k % 2 == 0
		specs.append([dir * 0.42, dir * (1.0 if long else 0.78), 0.2 if long else 0.15, 0.5 if long else -0.4])
	_tongues(st, specs, 0.0, [0.0, 0.55, 0.62, 0.9], 0.04)
	_fill(st, _rounded(Vector2.ZERO, Vector2.ONE * 0.52, 2.0, 40, 0.05), Vector2.ZERO, _c(0.0), _c(0.0), Color(-1, 0, 0), 0.012)
	_fill(st, _rounded(Vector2.ZERO, Vector2.ONE * 0.52, 2.0, 40), Vector2.ZERO, _c(0.98), _c(0.66), Color(-1, 0, 0), 0.014)
	_xy_ring(st, 0.4, 0.425, _c(0.35), _c(0.35), 48, 0.016)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var petal: Array = []
		for j in 7:
			var t := float(j) / 6.0
			petal.append(dir * lerpf(0.1, 0.33, t) + side * sin(PI * t) * 0.07)
		for j in range(5, 0, -1):
			var t := float(j) / 6.0
			petal.append(dir * lerpf(0.1, 0.33, t) - side * sin(PI * t) * 0.07)
		_stroke(st, petal, 0.018, 0.018, _c(0.5), _c(0.5), 0.018)
	_fill(st, _rounded(Vector2.ZERO, Vector2.ONE * 0.07, 2.0, 12), Vector2.ZERO, _c(1.0), _c(0.8), Color(-1, 0, 0), 0.02)


## A thunderbolt (XY, y 0 at the struck ground to 1 in the sky, about 0.3 wide): an
## outlined gold zigzag with a pale core and two forks.
static func _zap(st: SurfaceTool) -> void:
	var main: Array = [Vector2(0.06, 1.0), Vector2(-0.08, 0.78), Vector2(0.07, 0.7), Vector2(-0.1, 0.46), Vector2(0.06, 0.4), Vector2(-0.06, 0.16), Vector2(0.03, 0.1), Vector2(0.0, 0.0)]
	var forks: Array = [[Vector2(0.07, 0.7), Vector2(0.2, 0.6), Vector2(0.17, 0.5), Vector2(0.28, 0.4)], [Vector2(-0.1, 0.46), Vector2(-0.2, 0.36), Vector2(-0.16, 0.3), Vector2(-0.26, 0.2)]]
	for pass_i in 3:
		var grow: float = [0.04, 0.0, 0.0][pass_i]
		var w: float = [1.0, 1.0, 0.36][pass_i]
		var tone: float = [0.0, 0.62, 1.0][pass_i]
		_stroke(st, main, 0.13 * w + grow, 0.05 * w + grow, _c(tone), _c(tone), 0.003 * float(pass_i))
		for fork in forks:
			_stroke(st, fork, 0.06 * w + grow, 0.015 * w + grow, _c(tone), _c(tone, 0.8), 0.003 * float(pass_i) - 0.001)
	_fill(st, _rounded(Vector2(0, 0.02), Vector2(0.2, 0.05), 2.0, 16), Vector2(0, 0.02), _c(1.0), _c(0.6, 0.0), Color(-1, 0, 0), 0.01)


## A single กนก flame (XY, upright, base at y 0, about 1 tall): a big tongue hooking over
## with two small ones at its sides, outlined, a hot heart.
static func _kanok(st: SurfaceTool) -> void:
	_tongues(st, [[Vector2(0.0, 0.0), Vector2(0.06, 1.0), 0.27, 0.45], [Vector2(-0.12, 0.02), Vector2(-0.34, 0.56), 0.13, -0.6], [Vector2(0.13, 0.02), Vector2(0.32, 0.62), 0.13, 0.6]], 0.0, [0.0, 0.62, 0.52, 0.95], 0.04)


## A speed streak (XY, from x 0 back along -X to -1): tapered bands, hot at the head.
static func _streak(st: SurfaceTool) -> void:
	for k in 7:
		var y := (float(k) - 3.0) * 0.13
		var length := 0.55 + 0.45 * absf(sin(float(k) * 1.9 + 0.4))
		var w := 0.07 * (1.0 - absf(float(k) - 3.0) / 4.5)
		_strip(st, Vector3(-0.05, y * 0.9, 0), Vector3(-length, y, 0), w, Vector3.BACK, _c(0.85, 0.95), _c(0.25, 0.0), w * 0.3)
