class_name MageUltimateArt
extends CasterArt
## The natural, layered dressing of the Mage's three ultimates, over their own
## sequence art (MeteorArt, ThunderStormArt, JudgmentRayArt). Cosmetic only: each
## entry point is called at a beat its sequence already owns, after or beside the
## hit, and never picks victims, deals damage or moves a timer.
##   Armageddon: the sky reddens under slanting red light while ash glows down, the
##     meteor drags a heat trail that leaves a smoke contrail; the landing opens a
##     molten crater with magma cracks that cool to scorch, smoke columns climb out,
##     shockwave dust rings roll over the ground, embers keep rising.
##   Thunder Storm: a rolling deck of dark cloud turns under the sky ring, sheets of
##     rain fall through it; every strike is a forked channel with a long afterglow,
##     a scorch on the ground and thrown sparks.
##   Judgment Ray: a halo and rune circles gather over and under the target while light
##     spirals in; the ray lands as a layered beam (white core, soft glow, spiral
##     motes), melts a ring of light into the ground and leaves light rising.
## Meshes come from CasterArt's shared kinds (one node per layer, budgeted); the
## particles, rings and lights come from SkillLayers' shared pool.

## Dark storm cloud: slate body, a pale lit top, a near-black rim.
const STORM_CLOUD := [Color("4c5672"), Color("aab6d0"), Color("161a26")]
## Thick crater smoke: brown-grey with an ember-lit inlay.
const ASH := [Color("5a4c48"), Color("c8784a"), Color("1c1210")]
## Molten cracks: deep red glow to a yellow-white core.
const MAGMA := [Color("ff3a0a"), Color("ffa040"), Color("2a0602")]
## The ray's gold with a white-hot core.
const RAY_GOLD := [Color("ffbe3a"), Color("fffdf0"), Color("4a2a08")]
## The red sky light: no white core, so it stays red over a bright field.
const SKY_RED := [Color("ff2a0c"), Color("ff8a3a"), Color("3a0604")]

## Off: the three ultimates draw only their sequence art (before / after renders).
static var enabled := true


static func _art(parent: Node3D, at: Vector3, label: String, full: int, cost := 3) -> MageUltimateArt:
	if not enabled or not _alive(parent) or not VfxBudget.can_decorate(cost + RESERVE):
		return null
	var art := MageUltimateArt.new()
	art.name = label
	art.cap = maxi(2, int(float(full) * [0.3, 0.6, 1.0][VfxBudget.quality()] * MemoryGuard.effect_scale()))
	parent.add_child(art)
	art.global_position = at
	return art


# ---------------------------------------------------------------------------
# Armageddon
# ---------------------------------------------------------------------------

## Over the descent: a red sky, a heat trail along the meteor's real path ([param from]
## to [param to], root space, eased in like MeteorArt's fall) and a reddening ground.
static func armageddon_descent(parent: Node3D, center: Vector3, radius: float, duration: float, from: Vector3, to: Vector3, size: float) -> void:
	var art := _art(parent, center, "MageUltimate_ArmageddonSky", 22)
	if art == null:
		return
	# Red light slanting down from the sky onto the area.
	art._rays(SKY_RED, Vector3.ZERO, radius * 0.9, 4, 0.0, duration + 0.3, 14.0)
	# A dull red heat shimmer over the area, thickening until the landing.
	art.layer("haze", true, SKY_RED, Vector3.ZERO, Vector3(radius * 0.8, 6.0, radius * 0.8), Vector3.ZERO, 0.0, duration + 0.1,
		{"initial": 0.6, "grow": 1.0, "spin": 0.4, "fade_in": 0.6, "decay": 0.92, "opacity": 0.12, "tier": TIER_MID})
	# Heat trail: at each point of the path, a hot glow that flares as the meteor
	# passes and a smoke puff left hanging behind it, drifting and dissolving.
	var n := count(7)
	for k in n:
		var f := 0.12 + 0.72 * float(k) / float(maxi(n - 1, 1))
		var spot := from.lerp(to, f)
		var when := duration * sqrt(f)
		var puff := size * (0.9 + 0.5 * f)
		art.layer("smoke", false, ASH, spot, Vector3.ONE * puff * 1.4, Vector3(0, 0, float(k)), when, 1.3,
			{"initial": 0.35, "grow": 2.0, "travel": Vector3(0.6, 0.9, 0.2), "sway": 0.25, "sway_rate": 0.5, "phase": float(k), "roll": 0.35,
			"face_camera": true, "fade_in": 0.05, "decay": 0.45, "opacity": 0.62, "tier": TIER_CORE if k % 2 == 0 else TIER_MID})
		art.layer("flame", true, FIRE, spot, Vector3(puff, puff * 1.6, puff), Vector3(0, 0, 2.6), when, 0.32,
			{"initial": 0.8, "grow": 6.0, "face_camera": true, "fade_in": 0.02, "decay": 0.3, "opacity": 0.55, "tier": TIER_MID})
	SkillLayers.ultimate(parent, "armageddon", "meteor_sky", center, radius, duration)


## The landing: a molten crater and magma cracks cooling to scorch, smoke columns,
## rolling shockwave dust and rising embers. [param giant]: the main meteor.
static func armageddon_impact(parent: Node3D, center: Vector3, radius: float, giant: bool) -> void:
	SkillLayers.ultimate(parent, "armageddon", "meteor_impact" if giant else "meteor_fragment", center, radius)
	var art := _art(parent, center, "MageUltimate_ArmageddonImpact" if giant else "MageUltimate_FragmentImpact", 26 if giant else 6)
	if art == null:
		return
	if not giant:
		art.layer("frost", true, MAGMA, Vector3.UP * 0.06, Vector3.ONE * radius * 0.75, Vector3(0, randf() * TAU, 0), 0.0, 1.2,
			{"initial": 0.3, "grow": 6.0, "fade_in": 0.02, "decay": 0.45, "opacity": 0.85})
		art.layer("scorch", false, SCORCH, Vector3.UP * 0.04, Vector3.ONE * radius * 0.8, Vector3(0, randf() * TAU, 0), 0.0, 2.0,
			{"initial": 0.6, "grow": 7.0, "decay": 0.6, "opacity": 0.7, "tier": TIER_MID})
		art.layer("smoke", false, ASH, Vector3.UP * 0.9, Vector3.ONE * radius * 0.9, Vector3.ZERO, 0.08, 1.3,
			{"initial": 0.4, "grow": 1.6, "travel": Vector3(0.3, 2.0, 0.1), "face_camera": true, "fade_in": 0.1, "decay": 0.45, "opacity": 0.5, "tier": TIER_MID})
		return
	# Core: the molten crater, its magma cracks and the scorch they cool to.
	art._crater(Vector3.ZERO, radius * 0.55, 0.0, 3.2)
	# Magma cracks glowing through the ground, then cooling with the scorch.
	art.layer("frost", true, MAGMA, Vector3.UP * 0.06, Vector3.ONE * radius * 0.95, Vector3(0, 0.6, 0), 0.0, 2.8,
		{"initial": 0.15, "grow": 3.5, "fade_in": 0.02, "decay": 0.55, "opacity": 0.8})
	# A shockwave of dust rolling out over the ground (the pool adds the dust cloud).
	art.layer("dust", false, DUST, Vector3.ZERO, Vector3(radius * 0.95, 0.75, radius * 0.95), Vector3.ZERO, 0.04, 1.2,
		{"initial": 0.25, "grow": 2.6, "travel": Vector3(0, 0.25, 0), "spin": 0.3, "fade_in": 0.04, "decay": 0.4, "opacity": 0.45, "tier": TIER_MID})
	# Flame tongues licking out of the crater.
	art._flames(Vector3.ZERO, radius * 0.45, 6, 0.05, 1.3, 1.3)
	# Smoke columns: puffs stacked up out of the crater and climbing as they spread.
	for k in count(6):
		var a := float(k) * 2.39996 + 0.4
		var spot := Vector3(sin(a), 0, cos(a)) * radius * 0.22 * float(k % 3) + Vector3.UP * (1.4 + 1.1 * float(k))
		art.layer("smoke", false, ASH, spot, Vector3.ONE * (radius * 0.55 + 0.4 * float(k)), Vector3(0, 0, a), 0.15 + 0.08 * float(k), 2.2,
			{"initial": 0.3, "grow": 1.3, "travel": Vector3(0.7, 3.2 + 0.4 * float(k), 0.2), "sway": 0.3, "sway_rate": 0.4, "phase": a, "roll": 0.25,
			"face_camera": true, "fade_in": 0.15, "decay": 0.5, "opacity": 0.66, "tier": TIER_CORE if k < 2 else TIER_MID})
	art._sparks(EMBER, Vector3.UP * 0.6, 8, radius * 0.3, 0.02, 4.0)


# ---------------------------------------------------------------------------
# Thunder Storm
# ---------------------------------------------------------------------------

## The cloud deck rolling under the sky ring and the rain falling through it, for
## the storm's [param seconds] (root at the storm centre, [param height]: the ring).
static func storm_sky(parent: Node3D, radius: float, height: float, seconds: float) -> void:
	var art := _art(parent, parent.global_position, "MageUltimate_StormDeck", 18)
	if art == null:
		return
	var n := count(12)
	for k in n:
		var a := TAU * float(k) / float(n)
		var ring := radius * (0.55 + 0.25 * fmod(float(k) * 0.618, 1.0))
		var puff := 3.8 + 1.6 * fmod(float(k) * 0.37, 1.0)
		var y := height - 0.6 - 0.5 * fmod(float(k) * 0.53, 1.0)
		# Dark rolling bodies with paler lit tops, turning slowly round the storm.
		art.layer("smoke", false, STORM_CLOUD, Vector3(0, y, 0), Vector3(puff * 1.3, puff, puff), Vector3(0, 0, a), 0.05 * float(k), seconds,
			{"initial": 0.7, "grow": 1.2, "orbit": ring, "orbit_speed": 0.35, "phase": a, "sway": 0.3, "sway_rate": 0.3, "roll": 0.05,
			"face_camera": true, "fade_in": 0.25, "decay": 0.85, "opacity": 0.8, "tier": TIER_CORE if k % 3 == 0 else (TIER_MID if k % 3 == 1 else TIER_DEBRIS)})
	# A faint glow inside the deck, as if lit from within.
	art.layer("bloom", true, THUNDER, Vector3(0, height - 0.8, 0), Vector3.ONE * radius * 0.8, Vector3(PI, 0, 0), 0.1, seconds,
		{"initial": 0.5, "grow": 1.5, "spin": 0.4, "pulse": 9.0, "fade_in": 0.25, "decay": 0.8, "opacity": 0.22, "tier": TIER_MID})
	SkillLayers.ultimate(parent, "thunder_storm", "storm_rain", parent.global_position, radius, seconds)


## One strike landing at [param at] (global): a forked channel from the cloud with a
## long afterglow, a scorch on the ground, sparks thrown off.
static func storm_strike(field: Node3D, at: Vector3, height: float) -> void:
	SkillLayers.ultimate(field, "thunder_storm", "storm_strike", at, 2.0)
	var art := _art(field, Vector3(at.x, 0.0, at.z), "MageUltimate_StormStrike", 6)
	if art == null:
		return
	art._bolt(THUNDER, Vector3.ZERO, height, 0.0, 1.8)
	# A second, thinner fork beside the main channel.
	art.layer("bolt%d" % (randi() % 3), true, THUNDER, Vector3(0.35, 0, 0.2), Vector3(0.9, height * 0.8, 1.0), Vector3(0, 0, randf_range(-0.2, 0.2)), 0.04, 0.5,
		{"initial": 1.0, "face_camera": true, "fade_in": 0.01, "decay": 0.25, "opacity": 0.6, "tier": TIER_MID})
	art.layer("bloom", true, THUNDER, Vector3.UP * 0.05, Vector3.ONE * 1.6, Vector3.ZERO, 0.0, 0.5,
		{"initial": 0.3, "grow": 7.0, "decay": 0.4, "opacity": 0.6, "tier": TIER_MID})
	art.layer("scorch", false, SCORCH, Vector3.UP * 0.035, Vector3.ONE * 1.25, Vector3(0, randf() * TAU, 0), 0.0, 1.7,
		{"initial": 0.5, "grow": 8.0, "decay": 0.6, "opacity": 0.6})


# ---------------------------------------------------------------------------
# Judgment Ray
# ---------------------------------------------------------------------------

## The gathering over the target for [param seconds] (until the ray lands): rune circles
## under it, a halo high above, motes spiralling up into the halo.
static func judgment_gather(art_parent: Node3D, height: float, seconds: float) -> void:
	var art := _art(art_parent, art_parent.global_position, "MageUltimate_JudgmentGather", 14)
	if art == null:
		return
	var time := maxf(seconds, 0.2)
	art._rune(HOLY, Vector3.ZERO, 2.6, 0.0, time + 0.15)
	art.layer("rune_ring", true, HOLY, Vector3(0, height - 0.3, 0), Vector3.ONE * 3.0, Vector3.ZERO, 0.0, time + 0.2,
		{"initial": 0.2, "grow": 1.4, "overshoot": true, "spin": -0.9, "fade_in": 0.3, "decay": 0.85, "opacity": 0.8})
	art.layer("bloom", true, RAY_GOLD, Vector3(0, height - 0.35, 0), Vector3.ONE * 2.4, Vector3(PI, 0, 0), time * 0.3, time * 0.7 + 0.2,
		{"initial": 0.2, "grow": 1.5, "spin": 0.6, "pulse": 7.0, "fade_in": 0.3, "decay": 0.85, "opacity": 0.6, "tier": TIER_MID})
	for k in count(6):
		var a := TAU * float(k) / 6.0
		art.layer("mote", true, RAY_GOLD, Vector3.UP * 0.4, Vector3.ONE * 0.36, Vector3.ZERO, 0.04 * float(k), time,
			{"initial": 0.4, "orbit": 2.2 - 0.15 * float(k), "orbit_speed": 3.6, "phase": a, "travel": Vector3(0, height * 0.55, 0), "accelerate": true,
			"face_camera": true, "fade_in": 0.15, "decay": 0.8, "tier": TIER_MID if k < 3 else TIER_DEBRIS})
	SkillLayers.ultimate(art_parent, "judgment_ray", "judgment_gather", art_parent.global_position, 3.0, time)


## The ray lands at [param at] (global, ground): a layered beam (white-hot core, soft
## wide glow, spiral motes), a ring melted into the ground, light rising after it.
static func judgment_land(field: Node3D, at: Vector3, height: float) -> void:
	SkillLayers.ultimate(field, "judgment_ray", "judgment_land", at, 2.5)
	var art := _art(field, at, "MageUltimate_JudgmentBeam", 26)
	if art == null:
		return
	# Core first: the white-hot inner beam, then its soft wide glow.
	art.layer("pillar", true, RAY_GOLD, Vector3.ZERO, Vector3(0.9, height, 0.9), Vector3.ZERO, 0.0, 0.85,
		{"initial": 0.2, "grow": 9.0, "overshoot": true, "spin": 2.0, "fade_in": 0.02, "decay": 0.5, "opacity": 0.75})
	art.layer("pillar", true, HOLY, Vector3.ZERO, Vector3(2.6, height, 2.6), Vector3.ZERO, 0.0, 1.0,
		{"initial": 0.5, "grow": 5.0, "spin": -0.8, "fade_in": 0.03, "decay": 0.45, "opacity": 0.2, "tier": TIER_MID})
	# The ground melts in a ring of light that cools to a gold-rimmed scorch.
	art.layer("crater", true, RAY_GOLD, Vector3.UP * 0.05, Vector3.ONE * 2.3, Vector3(0, randf() * TAU, 0), 0.0, 1.9,
		{"initial": 0.4, "grow": 6.0, "fade_in": 0.02, "decay": 0.45, "opacity": 0.85})
	art.layer("scorch", false, [Color("6a4a1c"), Color("ffcc5a"), Color("1a1006")], Vector3.UP * 0.035, Vector3.ONE * 2.8, Vector3(0, randf() * TAU, 0), 0.0, 2.6,
		{"initial": 0.6, "grow": 6.0, "decay": 0.6, "opacity": 0.6, "tier": TIER_MID})
	art.layer("bloom", true, HOLY, Vector3.UP * 0.06, Vector3.ONE * 3.6, Vector3.ZERO, 0.0, 0.7,
		{"initial": 0.3, "grow": 5.0, "spin": 0.5, "decay": 0.4, "opacity": 0.55, "tier": TIER_MID})
	# Motes spiralling up the beam, then light rising off the molten ring.
	for k in count(6):
		var a := TAU * float(k) / 6.0
		art.layer("mote", true, RAY_GOLD, Vector3.UP * 0.3, Vector3.ONE * 0.4, Vector3.ZERO, 0.03 * float(k), 1.0,
			{"initial": 0.5, "orbit": 0.9 + 0.12 * float(k % 2), "orbit_speed": 6.5, "phase": a, "travel": Vector3(0, 5.5, 0),
			"face_camera": true, "fade_in": 0.05, "decay": 0.6, "tier": TIER_MID if k < 3 else TIER_DEBRIS})
	for k in count(6):
		var a := float(k) * 2.39996
		art.layer("ray", true, SUN, Vector3(sin(a), 0, cos(a)) * 1.6, Vector3(0.5, 2.4, 0.5), Vector3.ZERO, 0.25 + 0.12 * float(k), 1.3,
			{"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 1.6, 0), "fade_in": 0.2, "decay": 0.5, "opacity": 0.4, "tier": TIER_MID if k < 2 else TIER_DEBRIS})
	art._heal(RAY_GOLD, Vector3.ZERO, 2.2, 6, 0.45, 1.6)
