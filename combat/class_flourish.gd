class_name ClassFlourish
extends RefCounted
## The grand finishing layer for every active skill of every line, star
## skills included. It adds light, energy and real elements over the authored
## silhouettes, in each line's own language:
##   warrior / vagabond  layered energy crescents, crosses and ground breaks
##   lancer              a thrust of light down the spear line, spiral wakes
##   defender            shield slams, quake rings, walls of light
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
## Skills whose dedicated sequence already owns a column of light.
const OWN_COLUMN := ["judgment_ray"]
## Debris cards per element at a hit (ShaderBurst textures).
const DEBRIS := {"fire": "flame", "ice": "diamond", "arcane": "diamond", "thunder": "star", "holy": "star", "heal": "petal", "leaf": "leaf", "wind": "leaf"}

static var _last_contact: Dictionary = {}
## Caster position of the latest cast per skill: hits spray away from it.
static var _last_origin: Dictionary = {}
## Off switch for performance comparisons (tests/tools/skill_perf_probe).
static var enabled := true


static func handles(skill: Dictionary) -> bool:
	return enabled and not skill.is_empty() and not skill.has("star")


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
static func _holder(parent: Node3D, label: String, seconds := HOLD_SECONDS) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ClassFlourish_" + label
	parent.add_child(holder)
	holder.create_tween().tween_interval(seconds).finished.connect(holder.queue_free, CONNECT_ONE_SHOT)
	return holder


static func _alive(parent: Node3D) -> bool:
	return is_instance_valid(parent) and parent.is_inside_tree() and not parent.is_queued_for_deletion()


## A short-lived EliteSkillArt root inside the holder, facing [param yaw]: the
## elite mesh library (feathers, lanes, spears, branches, the martial bow and
## sweep) at every level, in the flourish palette. Freed with the holder.
static func _relief(parent: Node3D, at: Vector3, yaw: float, seconds: float, label: String) -> EliteSkillArt:
	var art := EliteSkillArt._root(parent, at, seconds, "Relief_" + label)
	art.rotation.y = yaw
	return art


static func _look(c: Array) -> Dictionary:
	return {"primary": c[0], "accent": c[1], "shade": c[2]}


## The authored palette triple [primary, accent, shade] (SkillArtDirection,
## BuffArt for lasting buffs, StarSkillArt for star skills): saturated body,
## bright core, dark edge. Nothing here drifts towards cream.
static func colors(skill: Dictionary) -> Array:
	if skill.has("star") and StarSkillArt.handles(skill):
		var look := StarSkillArt.look(skill)
		return [look.primary, look.accent, look.shade]
	var look := SkillShow.profile_for(skill)
	return [look.primary, look.accent, look.shade]


## Delay before an area skill's art may show (its damage lands on that beat).
static func landing(skill: Dictionary) -> float:
	return 0.55 if String(skill.get("special", "")) in ["meteor", "rain"] else 0.0


# ---------------------------------------------------------------------------
# GPU-only primitives. CPU particles are updated on the CPU every frame,
# which on a phone's web build is the dearest part of an effect, so the
# flourish never creates a CPUParticles3D: motes, sparks, dust and embers
# are ShaderBurst cards, flames are shader quads, waves are energy rings.
# ---------------------------------------------------------------------------

static func _rich() -> bool:
	return VfxBudget.quality() >= 2


## Motes and sparks are GPU bursts (ShaderBurst): one draw call and no CPU
## simulation, so they stay at every quality level.
static func _motes(parent: Node3D, pos: Vector3, color: Color, kind: String, count := 24, radius := 2.0, height := 0.0, lifetime := 1.4) -> void:
	var at := pos + Vector3.UP * height
	match kind:
		"snow":
			ShaderBurst.emit(parent, at, color, "snow", count, "fall", 4.5, radius, lifetime, 0.45)
		"leaf", "petal":
			ShaderBurst.emit(parent, at, color, kind, count, "burst", 3.5, radius, lifetime, 0.5, 1.6)
		"ember":
			ShaderBurst.emit(parent, at, color, "star", count, "rise", 3.0, radius, lifetime, 0.3)
		_:
			ShaderBurst.emit(parent, at, color, "star" if kind == "light" else kind, count, "rise", 2.2, radius, lifetime, 0.38)


static func _sparks(parent: Node3D, pos: Vector3, color: Color, amount := 22, speed := 4.0, lifetime := 0.55) -> void:
	ShaderBurst.emit(parent, pos, color, "star", amount, "burst", speed, 0.2, lifetime, 0.32, 5.0)


## A pressure wave over the ground with a GPU spark spray; High quality adds
## a second, wider ring.
static func _wave(parent: Node3D, pos: Vector3, color: Color, radius: float, core := Color.WHITE, shade := Color.TRANSPARENT) -> void:
	VfxKit.impact_ring(parent, pos + Vector3.UP * 0.05, color, radius * 0.75, 0.42, core, shade)
	_sparks(parent, pos + Vector3.UP * 0.3, core if shade.a > 0.0 else color, 18, radius * 1.4, 0.6)
	if _rich():
		VfxKit.impact_ring(parent, pos + Vector3.UP * 0.08, color.lerp(core, 0.4), radius, 0.55, core, shade)


static func _late_wave(parent: Node3D, pos: Vector3, color: Color, radius: float, delay: float, core := Color.WHITE, shade := Color.TRANSPARENT) -> void:
	parent.create_tween().tween_interval(delay).finished.connect(func():
		if _alive(parent):
			_wave(parent, pos + Vector3.UP * 0.1, color, radius, core, shade), CONNECT_ONE_SHOT)


## Ground break: a heavy wave, a second wave and a puff of GPU dust.
static func _slam(parent: Node3D, pos: Vector3, color: Color, radius: float, core := Color.WHITE, shade := Color.TRANSPARENT) -> void:
	_wave(parent, pos + Vector3.UP * 0.1, color, radius, core, shade)
	_late_wave(parent, pos, color, radius * 0.6, 0.12, core, shade)
	ShaderBurst.emit(parent, pos + Vector3.UP * 0.2, Color("d8c0a0"), "smoke", 14, "burst", radius * 0.6, 0.5, 0.8, 0.9, 2.5)


## A shaft of light striking down onto [param pos]: a wide soft shaft and a
## narrow hot core in the [param core] colour.
static func _sky(parent: Node3D, pos: Vector3, color: Color, width := 1.4, height := 14.0, duration := 0.5, core := Color.WHITE) -> void:
	if not _room(3):
		return
	VfxKit.pillar(parent, pos, color, height, width, duration, core)
	VfxKit.pillar(parent, pos, core, height * 1.05, width * 0.35, duration * 0.8, Color.WHITE)
	VfxArt.star_flash(parent, pos + Vector3.UP * 0.6, core, width * 3.0)
	_wave(parent, pos + Vector3.UP * 0.1, color, width * 2.4, core)


## A ring of shader flames (no smoke or ember emitters) with GPU embers.
static func _fire(parent: Node3D, center: Vector3, radius: float, tier := 1, ring := false) -> void:
	var count := (5 if not ring else 6) + (3 if _rich() else 0) + mini(tier, 3)
	var r := minf(radius, 6.0)
	if not ring:
		ElementFx.flame(parent, center, 1.8, 2.8, 1.0)
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := r * (randf_range(0.6, 0.9) if ring else sqrt(randf_range(0.05, 0.8)))
		ElementFx.flame(parent, center + Vector3(cos(angle), 0, sin(angle)) * dist, randf_range(1.0, 1.5), randf_range(1.5, 2.5), 0.9, randf_range(0.0, 0.15))
	VfxKit.impact_ring(parent, center + Vector3.UP * 0.1, Color("ff8a3a"), r * 0.8, 0.5)
	_motes(parent, center, Color("ffb050"), "ember", 16 + tier * 3, r * 0.6, 0.3, 1.1)


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
	VfxArt.crest(parent, origin, c[0], family, 1.1 * s, duration + 0.15, randf() * TAU)
	_motes(parent, origin, c[1], "light", int(8 + 10 * power(skill)), 0.9 * s, 0.2, duration + 0.35)
	if family in ["warrior", "vagabond", "lancer", "defender"] and power(skill) >= 0.3:
		VfxKit.impact_ring(parent, origin + Vector3.UP * 0.2, c[0], 1.2 * s, duration, c[1], c[2])


## Release: called once per cast by SkillShow.play (hero, companions, rivals).
static func cast(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, crowd := 0) -> void:
	if not handles(skill) or not _alive(parent):
		return
	parent = _holder(parent, String(skill.id))
	var c := colors(skill)
	var s := scale_of(skill)
	_last_origin[String(skill.id)] = origin
	# The wind-up's weapon light lets go: a short pop at the hand on release.
	VfxKit.flash(parent, origin + Vector3.UP * 1.25, c[1], 1.5, 0.16)
	if crowd >= 4:
		# A busy field keeps one clear accent per cast.
		VfxArt.star_flash(parent, (center if String(skill.shape) in ["single", "blast"] else origin) + Vector3.UP, c[1], 2.0 * s)
		return
	var flat := Vector3(center.x - origin.x, 0.0, center.z - origin.z)
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.01 else 0.0
	var family := SkillShow.family_of(skill)
	if family == "archer":
		_bow_flash(parent, origin, yaw, c, s)
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


## Every hit a skill lands (SkillTableau.contact): a burst sized to the skill,
## the line's mark stamped on the ground (SkillArtDirection impact_weight),
## debris thrown on along the attack, a fan of light on a critical hit and a
## hold that follows the recipe's linger. Simultaneous hits of one cast share
## one burst.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit := false) -> void:
	if not handles(skill) or not _alive(parent) or not _room(3):
		return
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < CONTACT_GAP_MS:
		return
	_last_contact[id] = now
	var look := SkillShow.profile_for(skill)
	var weight := clampf(float(look.impact_weight), 0.5, 2.4)
	var linger := clampf(float(look.linger), 0.6, 1.6)
	parent = _holder(parent, id + "_hit", 1.4 + linger)
	var c := colors(skill)
	var p := power(skill)
	var s := 1.0 + p * 0.8
	var style := SkillShow.style_of(skill)
	var family := SkillShow.family_of(skill)
	var origin: Vector3 = _last_origin.get(id, at)
	var flat := Vector3(at.x - origin.x, 0.0, at.z - origin.z)
	var forward := flat.normalized() if flat.length_squared() > 0.01 else Vector3.FORWARD
	VfxKit.star_burst(parent, at, c[0], 1.6 * s)
	VfxKit.flash(parent, at, c[1], 2.4 * s, 0.3)
	VfxArt.star_flash(parent, at, c[1], 2.6 * s, 0.45)
	var ground := Vector3(at.x, 0.06, at.z)
	_wave(parent, ground + Vector3.UP * 0.05, c[0], 1.3 * s, c[1], c[2])
	if _room(2):
		SkillInk.mark(parent, look, ground + Vector3.UP * 0.02, 0.9 * weight, 0.5 * linger, 1)
	ShaderBurst.emit(parent, at + Vector3.UP * 0.2, c[2].lerp(c[0], 0.35), DEBRIS.get(style, "smoke"), int(8 + 8 * weight), "burst", 3.0 * s, 0.25, 0.5 * linger, 0.16 + 0.07 * weight, 4.5, forward * 2.2 * s)
	if crit:
		VfxKit.impact_fan(parent, at, c[1], 0.9 * weight, DEBRIS.get(style, "spark"))
	match style:
		"holy", "heal":
			if _room(4) and not String(skill.get("id", "")) in OWN_COLUMN:
				_sky(parent, ground, c[0], 0.5 + p * 0.6, 7.0 + p * 5.0, 0.42 * linger, c[1])
		"arcane":
			_motes(parent, at, c[1], "diamond", int(10 + 10 * p), 0.7 * s, 0.4, 0.9)
			VfxArt.rune_circle(parent, ground, c[0], 1.2 * s, 0.6, 2.0)
		"thunder":
			if _room(3):
				VfxArt.painted_lightning(parent, at + Vector3(0.6, 7.0, -0.4), at, c[1])
		"fire":
			_motes(parent, at, Color("ffb050"), "ember", int(10 + 10 * p), 0.6 * s, 0.4, 0.9)
		"wind":
			_motes(parent, at, c[1], "leaf", int(8 + 8 * p), 0.7 * s, 0.3, 0.8)
		"leaf":
			VfxArt.bloom(parent, ground, c[0], "leaf", 0.9 * s, 6, 0.7, randf() * TAU)
	if family in ["warrior", "vagabond", "lancer", "defender"] and _room(2):
		# A crossing pair of energy cuts stamped on the victim, across the blow.
		var yaw := atan2(forward.x, forward.z) + PI * 0.5
		_crescent(parent, at, yaw, 1.1, c[0], c[1], 1.3 * s * weight, 0.0, 0.6, c[2])
		_crescent(parent, at, yaw + 0.4, -1.1, c[0], c[1], 1.1 * s * weight, 0.05, -0.6, c[2])


## Star skills (non-mage): every contact beat of StarSkillSequence gets the
## line's finish in the skill's own signature colour (StarSkillArt.COLORS),
## with columns of that colour instead of a generic white light. Beats sharing
## a frame (a chain of victims) share one flourish. The 200-star skills open
## with an apex: a sky seal, a crown of columns and a double wave.
static func star_beat(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not enabled or skill.is_empty() or not skill.has("star"):
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
				_legend_arrival(parent, skill, at, s)
			return
	if apex and index == 0:
		_apex(parent, c, ground, radius, family)
	VfxKit.flash(parent, ground + Vector3.UP, c[1], 2.2 * s, 0.32)
	VfxArt.star_flash(parent, ground + Vector3.UP, c[0], 2.4 * s, 0.45)
	_wave(parent, ground + Vector3.UP * 0.08, c[0], radius * 0.85, c[1], c[2])
	_colour_column(parent, ground, c, 0.9 * s, 10.0 + 4.0 * float(star) / 200.0)
	match family:
		"warrior":
			_crescent(parent, ground + Vector3.UP, yaw + PI * 0.5, -0.9, c[0], c[1], 2.4 * s, 0.0, 1.3, c[2])
			_crescent(parent, ground + Vector3.UP, yaw + PI * 0.5, 0.9, c[2].lerp(c[0], 0.5), c[1], 2.2 * s, 0.06, -1.3, c[2])
			_slam(parent, ground, c[0], radius * 0.7, c[1], c[2])
		"defender":
			# The great shield comes down: a heavy slam and a wall of light ringing it.
			_slam(parent, ground, c[0], radius * 0.8, c[1], c[2])
			VfxArt.rune_circle(parent, ground, c[1], radius * 0.6, 0.8, 0.6)
		"lancer":
			if flat.length() > 1.0 and _room(4):
				_lance_streak(parent, feet + Vector3.UP * 1.1, ground + Vector3.UP, c[0], c[1], 1.5, 0.4)
			_crescent(parent, ground + Vector3.UP, yaw, 0.2, c[0], c[1], 2.0 * s, 0.0, 2.0, c[2])
		"archer":
			_arrow_storm(parent, skill, c, ground, radius * 0.7, 4 + index)
			if _room(3):
				_lance_streak(parent, feet + Vector3.UP * 1.3, ground + Vector3.UP, c[0], c[1], 0.8, 0.34)
		"priest":
			VfxArt.rune_circle(parent, ground, c[0], radius * 0.7, 0.9, 1.0)
			_motes(parent, ground, c[1], "petal", 18, radius * 0.5, 0.6, 1.2)
		"summoner":
			VfxKit.vortex(parent, ground, c[0], 3.5, 0.8)
			_motes(parent, ground, c[1], "leaf", 22, radius * 0.5, 0.4, 1.2)
		"mage":
			VfxArt.rune_circle(parent, ground, c[0], radius * 0.75, 1.0, -1.5)
			_motes(parent, ground, c[1], "diamond", 24, radius * 0.5, 0.6, 1.2)
			if _room(3):
				VfxArt.ribbon_spiral(parent, ground, c[0], 4.0, 2.5, 0.8, 1.1 * s)
	_motes(parent, ground, c[0], "light", 14, radius * 0.5, 0.4, 1.0)


## A column of the skill's own colour: a wide tinted shaft around a bright core.
static func _colour_column(parent: Node3D, at: Vector3, c: Array, width: float, height: float) -> void:
	if not _room(2):
		return
	VfxKit.pillar(parent, at, c[0], height, width * 1.6, 0.6, c[1])
	VfxKit.pillar(parent, at, c[1], height * 1.1, width * 0.5, 0.45, Color.WHITE)


## Star buffs and pacts: a seal, a shaft and a spiral in the skill's colours.
static func _star_ascend(parent: Node3D, c: Array, at: Vector3, s: float, family: String, apex: bool) -> void:
	VfxArt.rune_circle(parent, at, c[0], 2.0 * s, 1.3, 1.0)
	VfxArt.crest(parent, at, c[0], family, 1.7 * s, 1.1, randf() * TAU)
	_colour_column(parent, at, c, 1.1 * s, 9.0)
	VfxArt.ribbon_spiral(parent, at, c[1], 4.0, 3.0, 1.1, 1.0 * s)
	VfxKit.impact_ring(parent, at + Vector3.UP * 0.2, c[0], 2.6 * s, 0.7, c[1], c[2])
	_motes(parent, at, c[1], "light", 26, 1.2 * s, 0.3, 1.5)
	if apex:
		_apex(parent, c, at, 6.0, family)


## The legends arrive in their own element, bigger with the star count: Poseidon
## rises on pillars of tide inside rings of waves and spray; the Wind Monkey
## King lands inside a gale that tears the leaves off the ground.
static func _legend_arrival(parent: Node3D, skill: Dictionary, at: Vector3, s: float) -> void:
	match String(skill.id):
		"eclipse_sovereign":
			var tide: Array = SkillArtDirection.PALETTES.tide
			var phase := randf() * TAU
			for i in 6:
				var angle := phase + TAU * float(i) / 6.0
				var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * 2.6 * s
				parent.create_tween().tween_interval(0.06 * i).finished.connect(func():
					if _alive(parent):
						_colour_column(parent, spot, tide, 0.75 * s, 9.0 + 3.0 * s)
						VfxArt.star_flash(parent, spot + Vector3.UP * 0.5, tide[1], 1.8, 0.35), CONNECT_ONE_SHOT)
			_wave(parent, at + Vector3.UP * 0.1, tide[0], 4.5 * s, tide[1], tide[2])
			_late_wave(parent, at, tide[1], 3.4 * s, 0.2, Color.WHITE, tide[2])
			_late_wave(parent, at, tide[0], 5.2 * s, 0.42, tide[1], tide[2])
			_motes(parent, at, tide[1], "snow", 32, 2.6 * s, 0.0, 1.9)
			ShaderBurst.emit(parent, at + Vector3.UP * 0.3, tide[1], "diamond", 30, "rise", 5.5, 2.0 * s, 1.3, 0.3)
		"moonwolf_pact":
			var gale: Array = SkillArtDirection.PALETTES.gale
			var leaf: Color = SkillArtDirection.PALETTES.grove[0]
			VfxKit.vortex(parent, at, gale[0], 5.0 + 1.5 * s, 1.1)
			if _room(2):
				VfxArt.ribbon_spiral(parent, at, leaf, 5.0, 3.0, 1.0, 1.6 * s)
			_wave(parent, at + Vector3.UP * 0.1, gale[0], 3.6 * s, gale[1], gale[2])
			_motes(parent, at, leaf, "leaf", 44, 2.4 * s, 0.5, 1.7)
			_motes(parent, at, gale[1], "leaf", 28, 1.4 * s, 1.8, 1.4)
			ShaderBurst.emit(parent, at + Vector3.UP * 0.4, leaf, "leaf", 36, "rise", 5.0, 1.8 * s, 1.7, 0.6, 1.5)
			ShaderBurst.emit(parent, at + Vector3.UP * 2.5, SkillArtDirection.PALETTES.grove[1], "leaf", 24, "burst", 4.0, 1.0 * s, 1.4, 0.5, 1.0)


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
	_wave(parent, at + Vector3.UP * 0.1, c[0], r * 1.1, c[1], c[2])
	_late_wave(parent, at, c[1], r * 0.8, 0.18, Color.WHITE, c[2])
	var phase := randf() * TAU
	for i in 8:
		var angle := phase + TAU * float(i) / 8.0
		var spot := at + Vector3(cos(angle), 0.0, sin(angle)) * r * 0.85
		parent.create_tween().tween_interval(0.05 * i).finished.connect(func():
			if _alive(parent):
				_colour_column(parent, spot, c, 0.6, 12.0), CONNECT_ONE_SHOT)
	_motes(parent, at, c[1], "light", 40, r * 0.6, 0.5, 1.8)


## A glowing core riding a projectile (arrows, holy bolts,
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



# ---------------------------------------------------------------------------
# Shapes
# ---------------------------------------------------------------------------

## Melee single target: grounded cuts. Energy crescents anchored on the foe
## along the blow, a cross for the heavy cuts, the line's stamp, dust and a
## ring at the feet; from Lv.40 the martial sweep and cut of the elite look,
## a ground break for stuns and the strongest blows.
static func _strike(parent: Node3D, skill: Dictionary, c: Array, center: Vector3, yaw: float, s: float) -> void:
	var p := power(skill)
	var id := String(skill.id)
	var ground := Vector3(center.x, 0.0, center.z)
	var at := center + Vector3.UP * 0.6
	var recipe := String(SkillArtDirection.RECIPES.get(id, ["cut"])[0])
	var cross := recipe in ["crosscut", "guard"] or p >= 0.6
	var elite := EliteSkillArt.handles(skill)
	var layers := 2 + int(p * 2.0)
	for i in layers:
		var tilt: float = [-0.7, 0.8, -0.2, 0.45][i % 4]
		_crescent(parent, at + Vector3.UP * 0.12 * i, yaw + randf_range(-0.2, 0.2), tilt, c[0] if i % 2 == 0 else c[2].lerp(c[0], 0.4), c[1], (1.25 + 0.15 * i) * s, i * 0.05, 1.2 if i % 2 == 0 else -1.2, c[2])
	if cross:
		VfxArt.cross_slash(parent, at, yaw, c[1], 1.5 * s)
	VfxKit.flash(parent, at, c[1], 2.4 * s, 0.26)
	# The cut lands: the line's stamp, a puff of dust and a ring at the feet.
	if _room(2):
		SkillInk.mark(parent, SkillShow.profile_for(skill), ground + Vector3.UP * 0.03, 1.0 * s, 0.55, 1)
	ShaderBurst.emit(parent, ground + Vector3.UP * 0.15, Color("d8c0a0"), "smoke", 12, "burst", 2.0 * s, 0.4, 0.7, 0.7, 2.5)
	VfxKit.impact_ring(parent, ground + Vector3.UP * 0.05, c[0], 1.4 * s, 0.4, c[1], c[2])
	# Elite cuts already carry their own sculpted sword and fractures.
	if p >= 0.4 and not elite and _room(3):
		var art := _relief(parent, ground, yaw, 0.8, id)
		var look := _look(c)
		art.layer("martial/sweep", look, Vector3(0, 0.9, 0.3), Vector3.ONE * 1.1 * s, Vector3(0.12, 0, 0.1), 0.0, 0.6, Vector3.ZERO, 3.2, 0.55, false, {"martial": true, "opacity": 0.9, "decay": 0.4})
		art.layer("cut", look, Vector3(0, 1.0, 0.3), Vector3.ONE * 1.5 * s, Vector3(0, 0, 0.7 if cross else -0.3), 0.04, 0.6, Vector3(0, 0, 0.5), 0.0, 0.6)
		if cross:
			art.layer("martial/cross", look, Vector3(0, 0.12, 0), Vector3.ONE * 1.3 * s, Vector3.ZERO, 0.0, 0.8, Vector3.ZERO, 0.0, 0.2, false, {"martial": true})
		art._draw()
	_element(parent, skill, c, ground, 1.6 * s)
	if skill.get("fx", {}).has("stun") or recipe in ["quake", "guard"] or p >= 0.5:
		_slam(parent, ground, c[0], 2.2 * s, c[1], c[2])
	if p >= 0.8 and not elite and _room(4):
		_sky(parent, ground, c[0], 0.9 * s, 12.0, 0.5, c[1])


## Lancer thrust: a lance of light down the spear line, rings racing along it,
## a spiral wake and a burst where it exits.
static func _thrust(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, center: Vector3, yaw: float, s: float) -> void:
	var p := power(skill)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var length := float(skill.get("pierce", {}).get("len", 4.0)) + 1.5
	var start := origin + Vector3.UP * 1.1 + forward * 0.6
	var tip := start + forward * length
	if _room(4):
		_lance_streak(parent, start, tip, c[0], c[1], (0.6 + p * 0.5) * s, 0.4)
	var rings := 2 + int(p * 3.0)
	for i in rings:
		var at := start + forward * length * (0.25 + 0.7 * float(i) / float(maxi(rings - 1, 1)))
		parent.create_tween().tween_interval(0.035 * i).finished.connect(func():
			if _alive(parent) and _room(1):
				_spear_ring(parent, at, forward, c[0], (0.9 + 0.25 * i) * s), CONNECT_ONE_SHOT)
	VfxKit.flash(parent, center + Vector3.UP, c[1], 3.0 * s, 0.28)
	VfxKit.star_burst(parent, tip, c[0], 1.8 * s)
	if not EliteSkillArt.handles(skill) and _room(3):
		# The elite lane fractures under the thrust and a spear of light rides it to the tip.
		var art := _relief(parent, Vector3(origin.x, 0.0, origin.z), yaw, 1.0, String(skill.id))
		var look := _look(c)
		art.layer("lane", look, Vector3(0, 0.08, 0), Vector3(0.9 + 0.5 * p, length / 10.0, length / 10.0), Vector3.ZERO, 0.0, 0.9, Vector3.ZERO, 0.0, 0.4)
		art.layer("spear", look, Vector3(0, 1.1, 0.6), Vector3(0.7 + 0.5 * p, 2.2 + 1.2 * p, 0.7 + 0.5 * p) * s * 0.6, Vector3(PI * 0.5, 0, 0), 0.0, 0.45, Vector3(0, 0, length), 0.0, 0.8, false, {"decay": 0.5})
		art._draw()
	_element(parent, skill, c, Vector3(center.x, 0.0, center.z), 1.5 * s)
	if skill.get("fx", {}).has("stun"):
		_slam(parent, Vector3(center.x, 0.0, center.z), c[0], 2.0 * s, c[1], c[2])
	if p >= 0.3 and _room(4):
		var mid := (start + tip) * 0.5
		var spiral := Node3D.new()
		parent.add_child(spiral)
		spiral.global_position = start - Vector3.UP * 0.0
		spiral.look_at(tip, Vector3.UP)
		spiral.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
		VfxArt.ribbon_spiral(spiral, spiral.global_position, c[1], length, 3.0, 0.5, 0.55 * s)
		spiral.create_tween().tween_interval(0.7).finished.connect(spiral.queue_free, CONNECT_ONE_SHOT)
		_wave(parent, Vector3(mid.x, 0.08, mid.z), c[0], 1.8 * s, c[1], c[2])


## Spin / roar around the caster: a full ring of energy crescents, a wave over
## the whole radius, a vortex for wind, a column of light for holy skills.
static func _whirl(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, radius: float, s: float) -> void:
	var p := power(skill)
	var style := SkillShow.style_of(skill)
	var family := SkillShow.family_of(skill)
	var r := minf(radius, 9.0)
	var at := origin + Vector3.UP * 0.9
	if family in ["warrior", "vagabond", "lancer", "defender"] or String(skill.get("special", "")) == "spin":
		var count := 3 + int(p * 3.0)
		for i in count:
			_crescent(parent, at + Vector3.UP * (0.15 * (i % 2)), TAU * float(i) / float(count), 0.15 * (1 if i % 2 == 0 else -1), c[0] if i % 2 == 0 else c[2].lerp(c[0], 0.4), c[1], r * 0.62, i * 0.04, 2.2, c[2])
	_wave(parent, origin + Vector3.UP * 0.1, c[0], r, c[1], c[2])
	if _room(2):
		_late_wave(parent, origin, c[1], r * 0.7, 0.14, Color.WHITE, c[2])
	VfxKit.flash(parent, at, c[1], 3.0 * s, 0.3)
	# The line's own emblem under every spin; the great seal rings it at high power.
	VfxArt.crest(parent, origin, c[0], family, r * (0.55 if p >= 0.75 else 0.7), 0.9, randf() * TAU)
	match style:
		"wind":
			VfxKit.vortex(parent, origin, c[0], 3.5 * s, 0.8)
			_motes(parent, origin, c[1], "leaf", int(14 + 12 * p), r * 0.6, 0.4, 1.1)
		"holy", "heal":
			if _room(4):
				_sky(parent, origin, c[0], 1.0 * s, 14.0, 0.6, c[1])
			_column_ring(parent, origin, c, r * 0.75, 4 + int(p * 4.0), 0.06)
		"leaf":
			_motes(parent, origin, c[0], "leaf", int(14 + 12 * p), r * 0.6, 0.4, 1.1)
		"fire":
			if EliteSkillArt.handles(skill):
				_fire(parent, origin, r, 3, true)
		"thunder":
			_bolt_ring(parent, origin, c, r * 0.7, 3 + int(p * 3.0))
		"arcane":
			_motes(parent, origin, c[1], "diamond", int(16 + 14 * p), r * 0.6, 0.6, 1.2)
			VfxKit.vortex(parent, origin, c[0], 3.0 * s, 0.8)
		"ice":
			_motes(parent, origin, c[1], "snow", int(16 + 14 * p), r * 0.6, 0.0, 1.4)
	if skill.get("fx", {}).has("stun") or style == "earth":
		_slam(parent, origin, c[0], r * 0.85, c[1], c[2])
	if p >= 0.75:
		VfxArt.rune_circle(parent, origin, c[2].lerp(c[0], 0.5), r * 0.8, 1.1, 1.0)


## Area at the target: a seal on the ground, then the element arrives in force
## (arrow storms, columns of light, bolts, growth), all on the damage beat.
static func _barrage(parent: Node3D, skill: Dictionary, c: Array, center: Vector3, radius: float, s: float) -> void:
	var p := power(skill)
	var style := SkillShow.style_of(skill)
	var r := minf(radius, 10.0)
	var ground := Vector3(center.x, 0.0, center.z)
	var family := SkillShow.family_of(skill)
	VfxArt.crest(parent, ground, c[0], family, r * (0.6 if p >= 0.75 else 0.8), 1.0, randf() * TAU)
	if p >= 0.75:
		VfxArt.rune_circle(parent, ground, c[2].lerp(c[0], 0.5), r * 0.85, 1.1, -1.0)
	_wave(parent, ground + Vector3.UP * 0.1, c[0], r, c[1], c[2])
	VfxKit.flash(parent, ground + Vector3.UP * 1.0, c[1], 3.4 * s, 0.32)
	if String(skill.get("special", "")) == "rain":
		_arrow_storm(parent, skill, c, ground, r, 6 + int(p * 10.0))
	match style:
		"holy", "heal":
			if _room(4):
				_sky(parent, ground, c[0], 1.2 * s, 16.0, 0.6, c[1])
			_column_ring(parent, ground, c, r * 0.65, 4 + int(p * 6.0), 0.08)
		"thunder":
			_bolt_ring(parent, ground, c, r * 0.6, 3 + int(p * 4.0))
		"fire":
			if EliteSkillArt.handles(skill):
				_fire(parent, ground, r, 3)
			_motes(parent, ground, Color("ffb050"), "ember", int(16 + 14 * p), r * 0.6, 0.5, 1.3)
		"leaf", "wind":
			_motes(parent, ground, c[0], "leaf", int(16 + 14 * p), r * 0.6, 0.6, 1.3)
		"ice":
			_motes(parent, ground, c[1], "snow", int(16 + 14 * p), r * 0.6, 0.0, 1.4)
		"arcane":
			_motes(parent, ground, c[1], "diamond", int(16 + 14 * p), r * 0.6, 0.6, 1.3)
			_column_ring(parent, ground, c, r * 0.6, 3 + int(p * 4.0), 0.07)
	if skill.get("fx", {}).has("stun") or style == "earth":
		_slam(parent, ground, c[0], r * 0.8, c[1], c[2])


## Fan: a flare at the bow / hand and a spread of streaks along every lane
## (the archer's lanes in gale and gold, every other line in its own palette).
static func _volley(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, yaw: float, s: float) -> void:
	_release(parent, skill, c, origin, yaw, s)
	var hits := clampi(int(skill.get("hits", 3)), 3, 10)
	var reach := minf(float(skill.get("range", 10.0)) * 0.55, 7.0)
	var start := origin + Vector3.UP * 1.2
	var archer := SkillShow.family_of(skill) == "archer"
	var lane: Color = SkillArtDirection.PALETTES.gale[0] if archer else c[0]
	var tip: Color = SkillArtDirection.PALETTES.gold[1] if archer else c[1]
	for i in hits:
		if not _room(2):
			break
		var angle := yaw + (float(i) - float(hits - 1) * 0.5) * (0.9 / float(hits))
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		_lance_streak(parent, start + dir * 0.6, start + dir * reach, lane, tip, 0.22 + power(skill) * 0.18, 0.28)


## Projectile release: a flare and a ring of force at the bow, wand or lantern,
## growing with the level. Mages add a burst of shards and a second ring; the
## archer's arrow leaves a gale-and-gold lane.
static func _release(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, yaw: float, s: float) -> void:
	var p := power(skill)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var at := origin + Vector3.UP * 1.25 + forward * 0.7
	VfxKit.flash(parent, at, c[1], (1.6 + 1.4 * p) * s, 0.24)
	VfxArt.star_flash(parent, at, c[0], (1.8 + 1.4 * p) * s, 0.32)
	if _room(1):
		_spear_ring(parent, at, forward, c[0], (0.7 + 0.6 * p) * s)
	if p >= 0.4:
		_sparks(parent, at, c[1], int(10 + 14 * p), 4.0 * s, 0.4)
	match SkillShow.family_of(skill):
		"mage":
			_motes(parent, at, c[1], "diamond", int(6 + 12 * p), 0.5 * s, 0.0, 0.7)
			if p >= 0.3 and _room(2):
				parent.create_tween().tween_interval(0.08).finished.connect(func():
					if _alive(parent):
						_spear_ring(parent, at + forward * 0.4, forward, c[2].lerp(c[0], 0.5), (1.0 + 1.0 * p) * s), CONNECT_ONE_SHOT)
		"archer":
			if String(skill.shape) == "single" and _room(2):
				var reach := minf(float(skill.get("range", 10.0)) * 0.5, 6.0)
				_lance_streak(parent, at, at + forward * reach, SkillArtDirection.PALETTES.gale[0], SkillArtDirection.PALETTES.gold[1], 0.3 + 0.2 * p, 0.3)


## The bow blazes at the hand on every archer release: the martial bow of the
## elite look, briefly, and a sparkle at the grip.
static func _bow_flash(parent: Node3D, origin: Vector3, yaw: float, c: Array, s: float) -> void:
	if not _room(2):
		return
	var hand := origin + Vector3.UP * 1.3
	var art := _relief(parent, hand, yaw, 0.5, "bow")
	art.layer("martial/bow", _look(c), Vector3(0, 0, 0.55), Vector3.ONE * (0.7 + 0.15 * s), Vector3(0, 0, PI * 0.5), 0.0, 0.45, Vector3.ZERO, 0.0, 0.75, false, {"martial": true, "opacity": 0.9, "decay": 0.3})
	art._draw()
	VfxArt.star_flash(parent, hand + Vector3(sin(yaw), 0.0, cos(yaw)) * 0.55, c[1], 1.4 * s, 0.3)


## Buffs and heals: the line's crest blazes under the caster and a column of
## light rises; each line climbs it in its own way (energy rings for the
## fighters, a halo for mages, petals for priests, leaves for the wild lines,
## silk for the traveller) and the great seal rings it at high power.
static func _ascend(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, s: float) -> void:
	var p := power(skill)
	var family := SkillShow.family_of(skill)
	var heal: bool = skill.get("fx", {}).has("heal")
	VfxArt.crest(parent, origin, c[0], family, 1.7 * s, 1.0, randf() * TAU)
	if p >= 0.75:
		VfxArt.rune_circle(parent, origin, c[2].lerp(c[0], 0.5), 2.1 * s, 1.2, 1.0)
	VfxKit.pillar(parent, origin, c[0], 5.0 + 4.0 * p, 1.4 * s, 0.9, c[1])
	match family:
		"warrior", "lancer", "defender":
			for i in 3:
				_crescent(parent, origin + Vector3.UP * (0.5 + 0.55 * i), TAU * float(i) / 3.0, 0.2, c[0] if i % 2 == 0 else c[2].lerp(c[0], 0.4), c[1], (1.5 - 0.15 * i) * s, 0.05 * i, 2.4, c[2])
		"mage":
			var halo := Node3D.new()
			parent.add_child(halo)
			halo.global_position = origin + Vector3.UP * (2.1 + 0.4 * s)
			VfxArt.rune_circle(halo, halo.global_position, c[0], 1.1 * s, 1.0, -2.0)
			VfxArt.ribbon_spiral(parent, origin, c[1], 3.0 + 1.5 * p, 2.5, 1.0, 0.9 * s)
		"priest":
			VfxArt.bloom(parent, origin, c[0], "petal", 1.1 * s, 6, 0.9, randf() * TAU)
			VfxArt.ribbon_spiral(parent, origin, c[1], 3.0 + 1.5 * p, 1.5, 1.0, 0.7 * s)
		"summoner", "archer":
			VfxArt.bloom(parent, origin, c[0], "leaf", 1.2 * s, 7, 0.9, randf() * TAU)
			VfxArt.ribbon_spiral(parent, origin, c[2].lerp(c[0], 0.5), 2.6 + 1.5 * p, 3.5, 1.0, 1.0 * s)
		_:
			VfxArt.ribbon_spiral(parent, origin, c[1], 3.0 + 1.5 * p, 2.5, 1.0, 0.9 * s)
	VfxArt.star_flash(parent, origin + Vector3.UP * (2.4 + p), c[1], 2.6 * s, 0.5)
	_motes(parent, origin, c[1], "heart" if heal else "light", int(12 + 14 * p), 1.0 * s, 0.3, 1.4)
	if p >= 0.5:
		VfxKit.impact_ring(parent, origin + Vector3.UP * 0.2, c[0], 2.4 * s, 0.6, c[1], c[2])
	if heal or family == "priest":
		_grace(parent, skill, c, origin, s, p)
	# Elite buffs already raise their own relief; a second sky shaft only whites them out.
	if p >= 0.8 and not EliteSkillArt.handles(skill) and _room(4):
		_sky(parent, origin, c[0], 1.0 * s, 14.0, 0.7, c[1])


## Heals and holy buffs: a lotus of petals opens at the feet (unless the
## authored silhouette is already one) and feathers of light drift down around
## the column, the elite relief in the grace palette for the priest.
static func _grace(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, s: float, p: float) -> void:
	if not _room(4):
		return
	var look := SkillShow.profile_for(skill)
	if String(look.signature) != "lotus":
		var lotus := SpellSpectacle._root(parent, origin, "FlourishLotus")
		var mat := SpellSpectacle._material(look, 0.85)
		var core_look := look.duplicate()
		core_look.primary = c[1]
		core_look.shade = c[0]
		var shade_look := look.duplicate()
		shade_look.primary = c[2]
		shade_look.accent = c[0]
		SkillTableau._lotus(lotus, mat, SpellSpectacle._material(core_look), SpellSpectacle._material(shade_look), 1 + int(p * 3.0), false)
		lotus.scale = Vector3.ONE * (0.8 + 0.5 * p)
		SpellSpectacle._finish(lotus, mat, 0.9 + 0.4 * p)
	var feathers: Array = SkillArtDirection.PALETTES.grace if SkillShow.family_of(skill) == "priest" else c
	var art := _relief(parent, origin, randf() * TAU, 1.5, "feathers")
	art.layer("feathers", _look(feathers), Vector3(0, 0.5, 0), Vector3(2.0 + 0.8 * p, 2.4, 2.0 + 0.8 * p) * s * 0.7, Vector3.ZERO, 0.0, 1.4, Vector3.UP * (1.8 + p), 0.3, 0.8, true)
	art._draw()


## Summons: a summoning seal and a gate of light where each creature arrives.
## The summoner's gate is alive: sprouts under it, branches crawling out and
## leaves rising on a grove vortex. The archer's hawks rise as a bird of light;
## the legends arrive in their own way (_legend_gate).
static func _summoning(parent: Node3D, skill: Dictionary, c: Array, origin: Vector3, s: float) -> void:
	var p := power(skill)
	var family := SkillShow.family_of(skill)
	var id := String(skill.id)
	VfxArt.crest(parent, origin, c[0], family, 2.2 * s, 1.1, randf() * TAU)
	if p >= 0.75:
		VfxArt.rune_circle(parent, origin, c[2].lerp(c[0], 0.5), 2.7 * s, 1.3, -1.0)
	VfxKit.vortex(parent, origin, SkillArtDirection.PALETTES.grove[0] if family == "summoner" else c[1], 3.0 + 2.0 * p, 0.9)
	var count := mini(int(skill.get("summon", {}).get("count", 1)), 3)
	var phase := randf() * TAU
	for i in count:
		var angle := phase + TAU * float(i) / float(count)
		var gate := origin + Vector3(cos(angle), 0.0, sin(angle)) * 1.6
		VfxKit.pillar(parent, gate, c[0], 4.0 + 3.0 * p, 0.9 * s, 0.8, c[1])
		VfxArt.star_flash(parent, gate + Vector3.UP * 0.8, c[1], 2.0 * s, 0.4)
	if family == "summoner":
		ElementFx.plant_field(parent, origin, minf((1.4 + 1.0 * p) * s, 3.2), "sprouts", 1 + int(p * 3.0), true)
		if _room(3):
			# Branches crawl out around the gate and leaves lift off them; both stay
			# low and open so the creature's own silhouette is what reads.
			var art := _relief(parent, origin, randf() * TAU, 1.6, id)
			var look := _look(c)
			art.layer("branches", look, Vector3(0, 0.07, 0), Vector3.ONE * (1.5 + 0.8 * p), Vector3.ZERO, 0.0, 1.3, Vector3.ZERO, 0.0, 0.15)
			art.layer("leaves", look, Vector3(0, 0.3, 0), Vector3(1.0, 1.5, 1.0) * (1.0 + 0.5 * p), Vector3.ZERO, 0.05, 1.5, Vector3.UP * (1.2 + p), 0.4, 0.5)
			art._draw()
	elif family == "archer" and _room(2):
		var art := _relief(parent, origin, randf() * TAU, 1.3, id)
		art.layer("phoenix", _look(c), Vector3(0, 1.4, 0.6), Vector3.ONE * (1.1 + 0.5 * p) * s, Vector3.ZERO, 0.0, 1.1, Vector3.UP * (1.2 + p), 0.0, 0.5, false, {"flap": 0.12})
		art._draw()
	_legend_gate(parent, id, c, origin, s, p)
	_motes(parent, origin, c[1], "leaf" if family in ["summoner", "archer"] else "light", int(12 + 14 * p), 1.4 * s, 0.3, 1.3)
	# Elite summons raise their own gate and relief; a sky shaft only whites them out.
	if p >= 0.8 and not EliteSkillArt.handles(skill) and _room(4):
		_sky(parent, origin, c[0], 1.2 * s, 15.0, 0.7, c[1])


## The elite summons arrive as the legends they are: the Fairy Spirit under a
## shower of pink petals and sparkles, the Elder Dragon between gold columns
## and a double wave (its gate, dragon and crown are the elite relief).
static func _legend_gate(parent: Node3D, id: String, c: Array, origin: Vector3, s: float, p: float) -> void:
	match id:
		"fairy_spirit":
			ShaderBurst.emit(parent, origin + Vector3.UP * 3.6, c[0], "petal", 28, "fall", 3.5, 2.0 * s, 1.8, 0.45)
			ShaderBurst.emit(parent, origin + Vector3.UP * 3.0, c[1], "star", 22, "fall", 2.5, 1.6 * s, 1.6, 0.3)
			ShaderBurst.emit(parent, origin + Vector3.UP * 0.4, c[0].lerp(c[1], 0.4), "heart", 14, "rise", 2.2, 1.0 * s, 1.4, 0.35)
			VfxKit.impact_ring(parent, origin + Vector3.UP * 0.1, c[0], 2.2 * s, 0.7, c[1], c[2])
		"elder_dragon":
			_column_ring(parent, origin, c, 2.8 * s, 6, 0.06)
			_wave(parent, origin + Vector3.UP * 0.1, c[0], 4.0 * s, c[1], c[2])
			_late_wave(parent, origin, c[1], 3.0 * s, 0.22, Color.WHITE, c[2])
			_motes(parent, origin, c[1], "light", int(20 + 12 * p), 2.0 * s, 0.5, 1.6)


# ---------------------------------------------------------------------------
# Pieces
# ---------------------------------------------------------------------------

## A sweeping crescent of flowing energy plus a soft additive bloom behind it:
## [param core] burns along the hot centre, [param shade] darkens the outer edge.
static func _crescent(parent: Node3D, at: Vector3, yaw: float, tilt: float, color: Color, core: Color, size: float, delay := 0.0, sweep := 1.0, shade := Color.TRANSPARENT) -> void:
	if delay > 0.0:
		parent.create_tween().tween_interval(delay).finished.connect(func():
			if _alive(parent):
				_crescent(parent, at, yaw, tilt, color, core, size, 0.0, sweep, shade), CONNECT_ONE_SHOT)
		return
	if not _room(2):
		return
	var mat := VfxKit.energy(color, core, 1, {"noise_scale": 3.0, "flow": 3.0, "shade": shade})
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


## A lance of flowing energy from [param from] to [param to] in the skill's
## colour: it shoots out from the caster, tapers to a point and burns away.
## Alpha-mixed (not additive), so overlapping layers keep their hue instead of
## burning to a white slab.
static func _lance_streak(parent: Node3D, from: Vector3, to: Vector3, color: Color, core: Color, width: float, duration: float) -> void:
	var dir := to - from
	if dir.length() < 0.2 or not _room(1):
		return
	var mat := VfxKit.energy(color, color.lerp(core, 0.55), 1, {"noise_scale": 2.2, "flow": 4.0})
	var lance := VfxKit._instance(parent, _streak_mesh(), mat, from)
	VfxBudget.track_decoration(lance)
	lance.look_at(to, Vector3.RIGHT if absf(dir.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
	lance.scale = Vector3(width, width, dir.length() * 0.25)
	var tween := lance.create_tween().set_parallel(true)
	tween.tween_property(lance, "scale:z", dir.length(), duration * 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(v: float): mat.set_shader_parameter("progress", v), 0.0, 1.0, duration)
	tween.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, duration * 0.6).set_delay(duration * 0.4)
	tween.chain().tween_callback(lance.queue_free)


static var _streak: ArrayMesh

## Two crossed tapering blades along -Z (length 1, width 1): U runs along the
## lance, V from the bright centre line (0) to the soft edge (1).
static func _streak_mesh() -> ArrayMesh:
	if _streak != null:
		return _streak
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	for axis in [Vector3.RIGHT, Vector3.UP]:
		for i in steps:
			var t0 := float(i) / steps
			var t1 := float(i + 1) / steps
			# Full width near the caster, a sharp point at the tip.
			var w0 := 0.5 * (1.0 - pow(t0, 1.6)) * minf(1.0, t0 * 6.0 + 0.35)
			var w1 := 0.5 * (1.0 - pow(t1, 1.6)) * minf(1.0, t1 * 6.0 + 0.35)
			var c0 := Vector3(0, 0, -t0)
			var c1 := Vector3(0, 0, -t1)
			for side in [-1.0, 1.0]:
				var e0: Vector3 = c0 + axis * w0 * side
				var e1: Vector3 = c1 + axis * w1 * side
				for corner in [[c0, t0, 0.0], [e0, t0, 1.0], [c1, t1, 0.0], [c1, t1, 0.0], [e0, t0, 1.0], [e1, t1, 1.0]]:
					st.set_uv(Vector2(corner[1], corner[2]))
					st.add_vertex(corner[0])
	_streak = st.commit()
	return _streak


## A ring of force standing across [param forward] (bow release, spear wake).
static func _spear_ring(parent: Node3D, at: Vector3, forward: Vector3, color: Color, size: float) -> void:
	if not _room(1):
		return
	var mat := VfxKit.energy(color, color.lerp(Color.WHITE, 0.55), 0, {"ring_radius": 0.62, "ring_width": 0.14, "fill": 0.0, "flow": 3.0})
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
				VfxKit.pillar(parent, at, c[0], 9.0, 0.5, 0.45, c[1])
				VfxArt.star_flash(parent, at + Vector3.UP * 0.3, c[1], 1.6, 0.3), CONNECT_ONE_SHOT)


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
				VfxKit.pillar(parent, spot, c[0], 8.0, 0.3, 0.3, c[1])
			else:
				_lance_streak(parent, spot + Vector3(0.8, 7.0, 0.3), spot + Vector3.UP * 0.1, c[0], c[1], 0.3, 0.24)
			VfxKit.impact_ring(parent, spot + Vector3.UP * 0.12, c[0], 0.9, 0.28), CONNECT_ONE_SHOT)


## The element made physical at a hit point (fire flames, holy light, frost).
static func _element(parent: Node3D, skill: Dictionary, c: Array, ground: Vector3, size: float) -> void:
	match SkillShow.style_of(skill):
		"fire":
			_fire(parent, ground, size, 2, true)
		"holy", "heal":
			if _room(4):
				_sky(parent, ground, c[0], 0.7 * size * 0.6, 10.0, 0.45, c[1])
		"thunder":
			if _room(3):
				VfxArt.painted_lightning(parent, ground + Vector3(0.5, 8.0, 0.2), ground + Vector3.UP, c[1])
		"wind":
			VfxKit.vortex(parent, ground, c[0], 2.6, 0.6)
		"ice":
			ElementFx.shatter(parent, ground + Vector3.UP, size * 0.6, 5)
		"arcane":
			VfxArt.rune_circle(parent, ground, c[0], size, 0.8, 2.0)
			_motes(parent, ground + Vector3.UP, c[1], "diamond", 14, size * 0.5, 0.3, 0.9)
