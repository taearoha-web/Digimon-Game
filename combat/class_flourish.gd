class_name ClassFlourish
extends RefCounted
## The grand finishing layer for every active skill of every line, star
## skills included. It adds light, energy and real elements over the authored
## silhouettes, in each line's own language:
##   warrior / vagabond  layered energy crescents, crosses and ground breaks
##   lancer              a thrust of light down the spear line, spiral wakes
##   archer              bow flare, bursting arrivals, glowing arrow storms
##   priest              heaven-sent columns, halos and sanctified circles
##   summoner            summoning seals, spirit vortices, bursts of growth
##   mage                arcane seals, prism shards, elemental bursts
## Size grows with the skill's level; Lv.100 skills get an extra beat.
## Cosmetic only: it never selects victims, deals damage or changes timing,
## and an area skill's impact waits for the same landing beat as its damage.
## Every piece goes through the shared VfxBudget, keeping a reserve for the
## authored layers and the hits that follow.

const RESERVE := 12
const CONTACT_GAP_MS := 70
## Longest piece: a rain landing (0.55 s) plus its motes and seals.
const HOLD_SECONDS := 3.0
const ELEMENT_COLORS := {
	"fire": [Color("ff7a2a"), Color("fff0b0")], "holy": [Color("ffd86a"), Color("fffbe6")],
	"thunder": [Color("8fb6ff"), Color("fffbd0")], "wind": [Color("4fe6c0"), Color("efffff")],
	"ice": [Color("6fd8ff"), Color("f2feff")], "leaf": [Color("7ee060"), Color("f4ffd0")],
	"heal": [Color("6dffa8"), Color("f0fff4")], "earth": [Color("d8a060"), Color("fff0c8")],
	"arcane": [Color("a070ff"), Color("f4e8ff")],
}
## Skills whose dedicated sequence already owns a column of light.
const OWN_COLUMN := ["judgment_ray"]

static var _last_contact: Dictionary = {}


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and not skill.has("star")


## 0 at Lv.1, 1 at Lv.100.
static func power(skill: Dictionary) -> float:
	return clampf(float(skill.get("level", 1)) / 100.0, 0.0, 1.0)


## Size multiplier: early skills already read clearly, Lv.100 fills the screen.
static func scale_of(skill: Dictionary) -> float:
	return 1.2 + power(skill) * 0.8 + (0.25 if int(skill.get("level", 1)) >= 100 else 0.0)


static func _room(cost := 1) -> bool:
	return VfxBudget.can_decorate(cost + RESERVE)


## Every piece of one cast or hit lives under one self-freeing holder, so a
## scene keeps a single, named, short-lived node per flourish.
static func _holder(parent: Node3D, label: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ClassFlourish_" + label
	parent.add_child(holder)
	holder.create_tween().tween_interval(HOLD_SECONDS).finished.connect(holder.queue_free, CONNECT_ONE_SHOT)
	return holder


static func _alive(parent: Node3D) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


## Primary / bright core colours: the skill's element, tinted by its own colour.
static func colors(skill: Dictionary) -> Array:
	if skill.has("star") and StarSkillArt.handles(skill):
		var look := StarSkillArt.look(skill)
		return [look.primary, look.accent, look.shade]
	var style := SkillShow.style_of(skill)
	var own: Color = skill.get("color", Color.WHITE)
	var pair: Array = ELEMENT_COLORS.get(style, [own, own.lerp(Color.WHITE, 0.7)])
	var primary: Color = (pair[0] as Color).lerp(own, 0.45)
	if style in ["phys", "buff"]:
		primary = own.lerp(Color("fff4d8"), 0.08)
	return [primary, (pair[1] as Color)]


## Delay before an area skill's art may show (its damage lands on that beat).
static func landing(skill: Dictionary) -> float:
	return 0.55 if String(skill.get("special", "")) in ["meteor", "rain"] else 0.0


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Wind-up: power gathers under the caster while the cast animation plays.
static func charge(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float) -> void:
	if not handles(skill) or duration < 0.18 or not _room(3) or not _alive(parent):
		return
	parent = _holder(parent, String(skill.id) + "_charge")
	var c := colors(skill)
	var s := scale_of(skill)
	var family := SkillShow.family_of(skill)
	VfxArt.rune_circle(parent, origin, c[0], 1.1 * s, duration + 0.15, 1.5)
	VfxArt.motes(parent, origin, c[1], "light", int(8 + 10 * power(skill)), 0.9 * s, 0.2, duration + 0.35)
	if family in ["warrior", "vagabond", "lancer"] and power(skill) >= 0.3:
		VfxKit.impact_ring(parent, origin + Vector3.UP * 0.2, c[0], 1.2 * s, duration)


## Release: called once per cast by SkillShow.play (hero, companions, rivals).
static func cast(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, crowd := 0) -> void:
	if not handles(skill) or not _alive(parent):
		return
	parent = _holder(parent, String(skill.id))
	var c := colors(skill)
	var s := scale_of(skill)
	if crowd >= 4:
		# A busy field keeps one clear accent per cast.
		VfxArt.star_flash(parent, (center if String(skill.shape) in ["single", "blast"] else origin) + Vector3.UP, c[1], 2.0 * s)
		return
	var flat := Vector3(center.x - origin.x, 0.0, center.z - origin.z)
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.01 else 0.0
	var family := SkillShow.family_of(skill)
	match String(skill.shape):
		"self":
			_ascend(parent, skill, c, origin, s)
		"summon":
			_summoning(parent, skill, c, origin, s)
		"single":
			if bool(skill.get("projectile", false)):
				_release(parent, skill, c, origin, yaw, s)
			elif skill.has("pierce") or family == "lancer":
				_thrust(parent, skill, c, origin, center, yaw, s)
			else:
				_strike(parent, skill, c, center, yaw, s)
		"burst":
			_whirl(parent, skill, c, origin, float(skill.get("radius", 4.5)), s)
		"blast":
			var wait := landing(skill)
			var radius := float(skill.get("radius", 4.5))
			if wait > 0.0:
				_release(parent, skill, c, origin, yaw, s)
				parent.create_tween().tween_interval(wait).finished.connect(func():
					if _alive(parent):
						_barrage(parent, skill, c, center, radius, s), CONNECT_ONE_SHOT)
			else:
				_barrage(parent, skill, c, center, radius, s)
		"fan":
			_volley(parent, skill, c, origin, yaw, s)
		"chain":
			_release(parent, skill, c, origin, yaw, s)


## Every hit a skill lands (SkillTableau.contact): a burst sized to the skill.
## Simultaneous hits of one cast share one burst.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not handles(skill) or not _alive(parent) or not _room(3):
		return
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < CONTACT_GAP_MS:
		return
	_last_contact[id] = now
	parent = _holder(parent, id + "_hit")
	var c := colors(skill)
	var p := power(skill)
	var s := 1.0 + p * 0.8
	var style := SkillShow.style_of(skill)
	var family := SkillShow.family_of(skill)
	VfxKit.star_burst(parent, at, c[0], 1.6 * s)
	VfxKit.flash(parent, at, c[1], 2.4 * s, 0.3)
	VfxArt.star_flash(parent, at, c[1], 2.6 * s, 0.45)
	var ground := Vector3(at.x, 0.06, at.z)
	VfxKit.shockwave(parent, ground + Vector3.UP * 0.05, c[0], 1.3 * s)
	match style:
		"holy", "heal":
			if _room(4) and not String(skill.get("id", "")) in OWN_COLUMN:
				VfxArt.sky_strike(parent, ground, c[0], 0.5 + p * 0.6, 7.0 + p * 5.0, 0.42)
		"arcane":
			VfxArt.motes(parent, at, c[1], "diamond", int(10 + 10 * p), 0.7 * s, 0.4, 0.9)
			VfxArt.rune_circle(parent, ground, c[0], 1.2 * s, 0.6, 2.0)
		"thunder":
			if _room(3):
				VfxArt.painted_lightning(parent, at + Vector3(0.6, 7.0, -0.4), at, c[1])
		"fire":
			VfxArt.motes(parent, at, Color("ffb050"), "ember", int(10 + 10 * p), 0.6 * s, 0.4, 0.9)
		"wind":
			VfxArt.motes(parent, at, c[1], "leaf", int(8 + 8 * p), 0.7 * s, 0.3, 0.8)
		"leaf":
			VfxArt.bloom(parent, ground, c[0], "leaf", 0.9 * s, 6, 0.7, randf() * TAU)
	if family in ["warrior", "vagabond", "lancer"] and _room(2):
		# A crossing pair of energy cuts stamped on the victim.
		_crescent(parent, at, randf() * TAU, 1.1, c[0], c[1], 1.3 * s, 0.0, 0.6)
		_crescent(parent, at, randf() * TAU, -1.1, c[0], c[1], 1.1 * s, 0.05, -0.6)


## Star skills (non-mage): every contact beat of StarSkillSequence gets the
## line's finish in the skill's own signature colour (StarSkillArt.COLORS),
## with columns of that colour instead of a generic white light. Beats sharing
## a frame (a chain of victims) share one flourish. The 200-star skills open
## with an apex: a sky seal, a crown of columns and a double wave.
static func star_beat(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if skill.is_empty() or not skill.has("star"):
		return
	if not _alive(parent) or not _room(4):
		return
	var key := "%s_beat%d" % [String(skill.id), index]
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(key, -100000)) < CONTACT_GAP_MS:
		return
	_last_contact[key] = now
	parent = _holder(parent, key)
	var look := StarSkillArt.look(skill)
	var c: Array = [look.primary, look.accent, look.shade]
	var family := SkillShow.family_of(skill)
	var star := int(skill.get("star", 50))
	var apex := star >= 200
	var s := 1.5 + float(star) / 200.0 * 0.6 + 0.12 * float(mini(index, 3))
	var ground := Vector3(point.x, 0.0, point.z)
	var feet := Vector3(source.x, 0.0, source.z)
	var flat := ground - feet
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.01 else 0.0
	var radius := clampf(float(skill.get("radius", 3.0)), 2.0, 8.0)
	match String(skill.shape):
		"self", "summon":
			if index == 0:
				var at := ground if String(skill.shape) == "self" else feet
				_star_ascend(parent, c, at, s, family, apex)
			return
	if apex and index == 0:
		_apex(parent, c, ground, radius, family)
	VfxKit.flash(parent, ground + Vector3.UP, c[1], 2.2 * s, 0.32)
	VfxArt.star_flash(parent, ground + Vector3.UP, c[0], 2.4 * s, 0.45)
	VfxKit.shockwave(parent, ground + Vector3.UP * 0.08, c[0], radius * 0.85)
	_colour_column(parent, ground, c, 0.9 * s, 10.0 + 4.0 * float(star) / 200.0)
	match family:
		"warrior":
			_crescent(parent, ground + Vector3.UP, yaw + PI * 0.5, -0.9, c[0], c[1], 2.4 * s, 0.0, 1.3)
			_crescent(parent, ground + Vector3.UP, yaw + PI * 0.5, 0.9, c[2].lerp(c[0], 0.5), c[1], 2.2 * s, 0.06, -1.3)
			VfxKit.slam(parent, ground, c[0], radius * 0.7)
		"lancer":
			if flat.length() > 1.0 and _room(4):
				VfxArt.beam(parent, feet + Vector3.UP * 1.1, ground + Vector3.UP, c[0], 0.75, 0.3)
				VfxArt.beam(parent, feet + Vector3.UP * 1.1, ground + Vector3.UP, c[1], 0.22, 0.22)
			_crescent(parent, ground + Vector3.UP, yaw, 0.2, c[0], c[1], 2.0 * s, 0.0, 2.0)
		"archer":
			_arrow_storm(parent, skill, c, ground, radius * 0.7, 4 + index)
			if _room(3):
				VfxArt.beam(parent, feet + Vector3.UP * 1.3, ground + Vector3.UP, c[0], 0.32, 0.24)
		"priest":
			VfxArt.rune_circle(parent, ground, c[0], radius * 0.7, 0.9, 1.0)
			VfxArt.motes(parent, ground, c[1], "petal", 18, radius * 0.5, 0.6, 1.2)
		"summoner":
			VfxKit.vortex(parent, ground, c[0], 3.5, 0.8)
			VfxArt.motes(parent, ground, c[1], "leaf", 22, radius * 0.5, 0.4, 1.2)
		"mage":
			VfxArt.rune_circle(parent, ground, c[0], radius * 0.75, 1.0, -1.5)
			VfxArt.motes(parent, ground, c[1], "diamond", 24, radius * 0.5, 0.6, 1.2)
			if _room(3):
				VfxArt.ribbon_spiral(parent, ground, c[0], 4.0, 2.5, 0.8, 1.1 * s)
	VfxArt.motes(parent, ground, c[0], "light", 14, radius * 0.5, 0.4, 1.0)


## A column of the skill's own colour: a wide tinted shaft around a bright core.
static func _colour_column(parent: Node3D, at: Vector3, c: Array, width: float, height: float) -> void:
	if not _room(2):
		return
	VfxKit.pillar(parent, at, c[0], height, width * 1.6, 0.6)
	VfxKit.pillar(parent, at, c[1], height * 1.1, width * 0.5, 0.45)


## Star buffs and pacts: a seal, a shaft and a spiral in the skill's colours.
static func _star_ascend(parent: Node3D, c: Array, at: Vector3, s: float, family: String, apex: bool) -> void:
	VfxArt.rune_circle(parent, at, c[0], 2.0 * s, 1.3, 1.0)
	VfxArt.crest(parent, at, c[0], family, 1.7 * s, 1.1, randf() * TAU)
	_colour_column(parent, at, c, 1.1 * s, 9.0)
	VfxArt.ribbon_spiral(parent, at, c[1], 4.0, 3.0, 1.1, 1.0 * s)
	VfxKit.impact_ring(parent, at + Vector3.UP * 0.2, c[0], 2.6 * s, 0.7)
	VfxArt.motes(parent, at, c[1], "light", 26, 1.2 * s, 0.3, 1.5)
	if apex:
		_apex(parent, c, at, 6.0, family)


## The 200-star opening: a seal in the sky, a crown of eight columns, a double
## wave across the whole area and the line's crest burning on the ground.
static func _apex(parent: Node3D, c: Array, at: Vector3, radius: float, family: String) -> void:
	var r := clampf(radius, 5.0, 9.0)
	VfxArt.rune_circle(parent, at, c[0], r, 1.6, -1.0)
	VfxArt.crest(parent, at, c[1], family, r * 0.8, 1.4, randf() * TAU)
	if _room(2):
		var sky := Node3D.new()
		parent.add_child(sky)
		sky.global_position = at + Vector3.UP * 7.0
		VfxArt.rune_circle(sky, at + Vector3.UP * 7.0, c[1], r * 0.7, 1.4, 1.5)
	VfxKit.flash(parent, at + Vector3.UP * 1.5, c[1], 7.0, 0.45)
	VfxKit.shockwave(parent, at + Vector3.UP * 0.1, c[0], r * 1.1)
	VfxKit.get_ring_delay(parent, at, c[1], r * 0.8, 0.18)
	var phase := randf() * TAU
	for i in 8:
		var angle := phase + TAU * float(i) / 8.0
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * r * 0.85
		parent.create_tween().tween_interval(0.05 * i).finished.connect(func():
			if _alive(parent):
				_colour_column(parent, spot, c, 0.6, 12.0), CONNECT_ONE_SHOT)
	VfxArt.motes(parent, at, c[1], "light", 40, r * 0.6, 0.5, 1.8)


## A glowing core and a spark trail riding a projectile (arrows, holy bolts,
## thorns). The carrier owns flight and arrival; this only rides along.
static func flight_glow(root: Node3D, skill: Dictionary, size := 1.0) -> void:
	if not handles(skill) or not is_instance_valid(root) or not _room(1):
		return
	var c := colors(skill)
	var s := scale_of(skill) * size
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 1.25 * s
	var mat := VfxKit._glow(c[0], 0.8)
	mat.albedo_texture = VfxArt.texture("flare")
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var core := MeshInstance3D.new()
	core.name = "FlourishFlightGlow"
	core.mesh = quad
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	VfxBudget.track_decoration(core)
	var trail := VfxKit._particles(root, root.global_position, c[1], int(14 + 12 * power(skill)), 0.32, false)
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.gravity = Vector3.ZERO
	trail.initial_velocity_min = 0.0
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 1.0 * s
	trail.scale_amount_max = 2.0 * s


# ---------------------------------------------------------------------------
# Shapes
# ---------------------------------------------------------------------------

## Melee single target: layered energy crescents through the foe, a cross for
## the heavy cuts, a ground break for stuns and the strongest blows.
static func _strike(parent: Node3D, skill: Dictionary, c: Array, center: Vector3, yaw: float, s: float) -> void:
	var p := power(skill)
	var at := center + Vector3.UP * 1.0
	var recipe := String(SkillArtDirection.RECIPES.get(String(skill.id), ["cut"])[0])
	var layers := 2 + int(p * 3.0)
	for i in layers:
		var tilt: float = [-0.95, 0.95, -0.25, 0.55, -1.35][i % 5]
		_crescent(parent, at, yaw + PI * 0.5 + randf_range(-0.3, 0.3), tilt, c[0], c[1], (2.2 + 0.25 * i) * s, i * 0.06, 1.2 if i % 2 == 0 else -1.2)
	if recipe in ["crosscut", "guard"] or p >= 0.6:
		VfxArt.cross_slash(parent, at, yaw + PI * 0.5, c[1], 2.6 * s)
	VfxKit.flash(parent, at, c[1], 3.2 * s, 0.3)
	_element(parent, skill, c, Vector3(center.x, 0.0, center.z), 1.6 * s)
	if skill.get("fx", {}).has("stun") or recipe in ["quake", "guard"] or p >= 0.5:
		VfxKit.slam(parent, Vector3(center.x, 0.0, center.z), c[0], 2.2 * s)
	if p >= 0.8 and _room(4):
		VfxArt.sky_strike(parent, Vector3(center.x, 0.0, center.z), c[1], 0.9 * s, 12.0, 0.5)


## Lancer thrust: a lance of light down the spear line, rings racing along it,
## a spiral wake and a burst where it exits.
static func _thrust(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, center: Vector3, yaw: float, s: float) -> void:
	var p := power(skill)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var length := float(skill.get("pierce", {}).get("len", 4.0)) + 1.5
	var start := origin + Vector3.UP * 1.1 + forward * 0.6
	var tip := start + forward * length
	if _room(4):
		VfxArt.beam(parent, start, tip, c[0], (0.45 + p * 0.55) * s * 0.8, 0.32)
		VfxArt.beam(parent, start, tip, c[1], 0.16 * s, 0.22)
	var rings := 2 + int(p * 3.0)
	for i in rings:
		var at := start + forward * length * (0.25 + 0.7 * float(i) / float(maxi(rings - 1, 1)))
		parent.create_tween().tween_interval(0.035 * i).finished.connect(func():
			if _alive(parent) and _room(1):
				_spear_ring(parent, at, forward, c[0], (0.9 + 0.25 * i) * s), CONNECT_ONE_SHOT)
	VfxKit.flash(parent, center + Vector3.UP, c[1], 3.0 * s, 0.28)
	VfxKit.star_burst(parent, tip, c[0], 1.8 * s)
	_element(parent, skill, c, Vector3(center.x, 0.0, center.z), 1.5 * s)
	if skill.get("fx", {}).has("stun"):
		VfxKit.slam(parent, Vector3(center.x, 0.0, center.z), c[0], 2.0 * s)
	if p >= 0.7 and _room(4):
		var mid := (start + tip) * 0.5
		var spiral := Node3D.new()
		parent.add_child(spiral)
		spiral.global_position = start - Vector3.UP * 0.0
		spiral.look_at(tip, Vector3.UP)
		spiral.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		VfxArt.ribbon_spiral(spiral, spiral.global_position, c[1], length, 3.0, 0.5, 0.55 * s)
		spiral.create_tween().tween_interval(0.7).finished.connect(spiral.queue_free, CONNECT_ONE_SHOT)
		VfxKit.shockwave(parent, Vector3(mid.x, 0.08, mid.z), c[0], 1.8 * s)


## Spin / roar around the caster: a full ring of energy crescents, a wave over
## the whole radius, a vortex for wind, a column of light for holy skills.
static func _whirl(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, radius: float, s: float) -> void:
	var p := power(skill)
	var style := SkillShow.style_of(skill)
	var family := SkillShow.family_of(skill)
	var r := minf(radius, 9.0)
	var at := origin + Vector3.UP * 0.9
	if family in ["warrior", "vagabond", "lancer"] or String(skill.get("special", "")) == "spin":
		var count := 3 + int(p * 3.0)
		for i in count:
			_crescent(parent, at + Vector3.UP * (0.15 * (i % 2)), TAU * float(i) / float(count), 0.15 * (1 if i % 2 == 0 else -1), c[0], c[1], r * 0.62, i * 0.04, 2.2)
	VfxKit.shockwave(parent, origin + Vector3.UP * 0.1, c[0], r)
	if _room(2):
		VfxKit.get_ring_delay(parent, origin, c[1], r * 0.7, 0.14)
	VfxKit.flash(parent, at, c[1], 3.0 * s, 0.3)
	match style:
		"wind":
			VfxKit.vortex(parent, origin, c[0], 3.5 * s, 0.8)
			VfxArt.motes(parent, origin, c[1], "leaf", int(14 + 12 * p), r * 0.6, 0.4, 1.1)
		"holy", "heal":
			if _room(4):
				VfxArt.sky_strike(parent, origin, c[0], 1.0 * s, 14.0, 0.6)
			VfxArt.rune_circle(parent, origin, c[0], r * 0.6, 1.0, 1.0)
			_column_ring(parent, origin, c, r * 0.75, 4 + int(p * 4.0), 0.06)
		"leaf":
			VfxArt.motes(parent, origin, c[0], "leaf", int(14 + 12 * p), r * 0.6, 0.4, 1.1)
		"fire":
			if EliteSkillArt.handles(skill):
				ElementFx.fire_field(parent, origin, r, 3, true)
		"thunder":
			_bolt_ring(parent, origin, c, r * 0.7, 3 + int(p * 3.0))
		"arcane":
			VfxArt.rune_circle(parent, origin, c[0], r * 0.7, 1.1, -1.5)
			VfxArt.motes(parent, origin, c[1], "diamond", int(16 + 14 * p), r * 0.6, 0.6, 1.2)
			VfxKit.vortex(parent, origin, c[0], 3.0 * s, 0.8)
		"ice":
			VfxArt.motes(parent, origin, c[1], "snow", int(16 + 14 * p), r * 0.6, 0.0, 1.4)
	if skill.get("fx", {}).has("stun") or style == "earth":
		VfxKit.slam(parent, origin, c[0], r * 0.85)
	if p >= 0.75:
		VfxArt.crest(parent, origin, c[0], family, r * 0.75, 0.9, randf() * TAU)


## Area at the target: a seal on the ground, then the element arrives in force
## (arrow storms, columns of light, bolts, growth), all on the damage beat.
static func _barrage(parent: Node3D, skill: Dictionary, c: Array, center: Vector3, radius: float, s: float) -> void:
	var p := power(skill)
	var style := SkillShow.style_of(skill)
	var r := minf(radius, 10.0)
	var ground := Vector3(center.x, 0.0, center.z)
	VfxArt.rune_circle(parent, ground, c[0], r * 0.75, 1.1, -1.0)
	VfxKit.shockwave(parent, ground + Vector3.UP * 0.1, c[0], r)
	VfxKit.flash(parent, ground + Vector3.UP * 1.0, c[1], 3.4 * s, 0.32)
	if String(skill.get("special", "")) == "rain":
		_arrow_storm(parent, skill, c, ground, r, 6 + int(p * 10.0))
	match style:
		"holy", "heal":
			if _room(4):
				VfxArt.sky_strike(parent, ground, c[0], 1.2 * s, 16.0, 0.6)
			_column_ring(parent, ground, c, r * 0.65, 4 + int(p * 6.0), 0.08)
		"thunder":
			_bolt_ring(parent, ground, c, r * 0.6, 3 + int(p * 4.0))
		"fire":
			if EliteSkillArt.handles(skill):
				ElementFx.fire_field(parent, ground, r, 3)
			VfxArt.motes(parent, ground, Color("ffb050"), "ember", int(16 + 14 * p), r * 0.6, 0.5, 1.3)
		"leaf", "wind":
			VfxArt.motes(parent, ground, c[0], "leaf", int(16 + 14 * p), r * 0.6, 0.6, 1.3)
		"ice":
			VfxArt.motes(parent, ground, c[1], "snow", int(16 + 14 * p), r * 0.6, 0.0, 1.4)
		"arcane":
			VfxArt.motes(parent, ground, c[1], "diamond", int(16 + 14 * p), r * 0.6, 0.6, 1.3)
			_column_ring(parent, ground, c, r * 0.6, 3 + int(p * 4.0), 0.07)
	if skill.get("fx", {}).has("stun") or style == "earth":
		VfxKit.slam(parent, ground, c[0], r * 0.8)
	if p >= 0.75:
		VfxArt.crest(parent, ground, c[0], SkillShow.family_of(skill), r * 0.85, 1.0, randf() * TAU)


## Fan: a flare at the bow / hand and a spread of streaks along every lane.
static func _volley(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, yaw: float, s: float) -> void:
	_release(parent, skill, c, origin, yaw, s)
	var hits := clampi(int(skill.get("hits", 3)), 3, 10)
	var reach := minf(float(skill.get("range", 10.0)) * 0.55, 7.0)
	var start := origin + Vector3.UP * 1.2
	for i in hits:
		if not _room(2):
			break
		var angle := yaw + (float(i) - float(hits - 1) * 0.5) * (0.9 / float(hits))
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		VfxArt.beam(parent, start + dir * 0.6, start + dir * reach, c[0], 0.16 + power(skill) * 0.14, 0.22)


## Projectile release: a flare and a ring of force at the bow, wand or lantern.
static func _release(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, yaw: float, s: float) -> void:
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var at := origin + Vector3.UP * 1.25 + forward * 0.7
	VfxKit.flash(parent, at, c[1], 2.2 * s, 0.24)
	VfxArt.star_flash(parent, at, c[0], 2.4 * s, 0.32)
	if _room(1):
		_spear_ring(parent, at, forward, c[0], 0.9 * s)
	if power(skill) >= 0.4:
		VfxKit.sparks(parent, at, c[1], int(10 + 14 * power(skill)), 4.0 * s, 0.4)


## Buffs and heals: a seal blazes under the caster, a column of light rises,
## silk spirals climb it and the line's crest turns at its foot.
static func _ascend(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, s: float) -> void:
	var p := power(skill)
	var family := SkillShow.family_of(skill)
	var heal: bool = skill.get("fx", {}).has("heal")
	VfxArt.rune_circle(parent, origin, c[0], 1.8 * s, 1.2, 1.0)
	VfxArt.crest(parent, origin, c[0], family, 1.5 * s, 1.0, randf() * TAU)
	VfxKit.pillar(parent, origin, c[0], 5.0 + 4.0 * p, 1.4 * s, 0.9)
	VfxArt.ribbon_spiral(parent, origin, c[1], 3.0 + 1.5 * p, 2.5, 1.0, 0.9 * s)
	VfxArt.star_flash(parent, origin + Vector3.UP * (2.4 + p), c[1], 2.6 * s, 0.5)
	VfxArt.motes(parent, origin, c[1], "heart" if heal else "light", int(12 + 14 * p), 1.0 * s, 0.3, 1.4)
	if p >= 0.5:
		VfxKit.impact_ring(parent, origin + Vector3.UP * 0.2, c[0], 2.4 * s, 0.6)
	if p >= 0.8 and _room(4):
		VfxArt.sky_strike(parent, origin, c[1], 1.0 * s, 14.0, 0.7)


## Summons: a summoning seal and a gate of light where each creature arrives.
static func _summoning(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, s: float) -> void:
	var p := power(skill)
	var family := SkillShow.family_of(skill)
	VfxArt.rune_circle(parent, origin, c[0], 2.4 * s, 1.3, -1.0)
	VfxArt.crest(parent, origin, c[0], family, 2.0 * s, 1.1, randf() * TAU)
	VfxKit.vortex(parent, origin, c[1], 3.0 + 2.0 * p, 0.9)
	var count := mini(int(skill.get("summon", {}).get("count", 1)), 3)
	var phase := randf() * TAU
	for i in count:
		var angle := phase + TAU * float(i) / float(count)
		var gate := origin + Vector3(cos(angle), 0.0, sin(angle)) * 1.6
		VfxKit.pillar(parent, gate, c[0], 4.0 + 3.0 * p, 0.9 * s, 0.8)
		VfxArt.star_flash(parent, gate + Vector3.UP * 0.8, c[1], 2.0 * s, 0.4)
	VfxArt.motes(parent, origin, c[1], "leaf" if family in ["summoner", "archer"] else "light", int(12 + 14 * p), 1.4 * s, 0.3, 1.3)
	if p >= 0.8 and _room(4):
		VfxArt.sky_strike(parent, origin, c[0], 1.2 * s, 15.0, 0.7)


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------

## A sweeping crescent of flowing energy plus a soft additive bloom behind it.
static func _crescent(parent: Node3D, at: Vector3, yaw: float, tilt: float, color: Color, core: Color, size: float, delay := 0.0, sweep := 1.0) -> void:
	if delay > 0.0:
		parent.create_tween().tween_interval(delay).finished.connect(func():
			if _alive(parent):
				_crescent(parent, at, yaw, tilt, color, core, size, 0.0, sweep), CONNECT_ONE_SHOT)
		return
	if not _room(2):
		return
	var mat := VfxKit.energy(color, 1, {"noise_scale": 3.0, "flow": 3.0})
	mat.set_shader_parameter("core", core)
	var blade := VfxKit._instance(parent, VfxKit._crescent_mesh(), mat, at)
	VfxBudget.track_decoration(blade)
	blade.rotation = Vector3(0, yaw - sweep * 0.5, tilt)
	blade.scale = Vector3.ONE * size * 0.55
	var glow_mat := VfxKit._glow(color.lerp(core, 0.3), 0.32)
	var glow := VfxKit._instance(blade, VfxKit._crescent_mesh(), glow_mat, at)
	VfxBudget.track_decoration(glow)
	glow.scale = Vector3(1.08, 1.0, 1.08)
	var tween := blade.create_tween().set_parallel(true)
	tween.tween_property(blade, "scale", Vector3.ONE * size, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(blade, "rotation:y", yaw + sweep * 0.5, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.34)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.2).set_delay(0.16)
	tween.tween_property(glow_mat, "albedo_color:a", 0.0, 0.28).set_delay(0.08)
	tween.chain().tween_callback(blade.queue_free)


## A ring of force standing across [param forward] (bow release, spear wake).
static func _spear_ring(parent: Node3D, at: Vector3, forward: Vector3, color: Color, size: float) -> void:
	if not _room(1):
		return
	var mat := VfxKit.energy(color, 0, {"ring_radius": 0.62, "ring_width": 0.14, "fill": 0.0, "flow": 3.0})
	var ring := VfxKit._instance(parent, VfxKit.ground_quad(), mat, at)
	VfxBudget.track_decoration(ring)
	# The ground quad faces up; turn its normal down the travel direction.
	ring.look_at(at + forward, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * size * 0.3
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * size * 1.2, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, 0.3)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, 0.3)
	tween.chain().tween_callback(ring.queue_free)


## Columns of light falling in a ring, one after another.
static func _column_ring(parent: Node3D, center: Vector3, c: Array, radius: float, count: int, step: float) -> void:
	var phase := randf() * TAU
	for i in count:
		var angle := phase + TAU * float(i) / float(count)
		var at := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		parent.create_tween().tween_interval(step * i).finished.connect(func():
			if _alive(parent) and _room(2):
				VfxKit.pillar(parent, at, c[1], 9.0, 0.5, 0.45)
				VfxArt.star_flash(parent, at + Vector3.UP * 0.3, c[0], 1.6, 0.3), CONNECT_ONE_SHOT)


## Lightning bolts striking around a point.
static func _bolt_ring(parent: Node3D, center: Vector3, c: Array, radius: float, count: int) -> void:
	var phase := randf() * TAU
	for i in count:
		var angle := phase + TAU * float(i) / float(count)
		var at := center + Vector3(cos(angle), 0.0, sin(angle)) * radius * randf_range(0.5, 1.0)
		parent.create_tween().tween_interval(0.05 * i).finished.connect(func():
			if _alive(parent) and _room(3):
				VfxArt.painted_lightning(parent, at + Vector3(randf_range(-1, 1), 8.0, randf_range(-1, 1)), at + Vector3.UP * 0.1, c[1])
				VfxKit.impact_ring(parent, at + Vector3.UP * 0.15, c[0], 1.4, 0.3), CONNECT_ONE_SHOT)


## Extra glowing arrows of the skill's element over the landing area.
static func _arrow_storm(parent: Node3D, skill: Dictionary, c: Array, center: Vector3, radius: float, count: int) -> void:
	var holy := SkillShow.style_of(skill) in ["holy", "heal"]
	for i in count:
		var angle := randf() * TAU
		var spot := center + Vector3(cos(angle), 0.0, sin(angle)) * sqrt(randf()) * radius * 0.9
		parent.create_tween().tween_interval(0.03 * i).finished.connect(func():
			if not _alive(parent) or not _room(2):
				return
			if holy:
				VfxKit.pillar(parent, spot, c[1], 8.0, 0.3, 0.3)
			else:
				VfxArt.beam(parent, spot + Vector3(0.8, 7.0, 0.3), spot + Vector3.UP * 0.1, c[0], 0.18, 0.2)
			VfxKit.impact_ring(parent, spot + Vector3.UP * 0.12, c[0], 0.9, 0.28), CONNECT_ONE_SHOT)


## The element made physical at a hit point (fire flames, holy light, frost).
static func _element(parent: Node3D, skill: Dictionary, c: Array, ground: Vector3, size: float) -> void:
	match SkillShow.style_of(skill):
		"fire":
			ElementFx.fire_field(parent, ground, size, 2, true)
		"holy", "heal":
			if _room(4):
				VfxArt.sky_strike(parent, ground, c[0], 0.7 * size * 0.6, 10.0, 0.45)
		"thunder":
			if _room(3):
				VfxArt.painted_lightning(parent, ground + Vector3(0.5, 8.0, 0.2), ground + Vector3.UP, c[1])
		"wind":
			VfxKit.vortex(parent, ground, c[0], 2.6, 0.6)
		"ice":
			ElementFx.shatter(parent, ground + Vector3.UP, size * 0.6, 5)
		"arcane":
			VfxArt.rune_circle(parent, ground, c[0], size, 0.8, 2.0)
			VfxArt.motes(parent, ground + Vector3.UP, c[1], "diamond", 14, size * 0.5, 0.3, 0.9)
