class_name CasterArt
extends NaturalArt
## Class-signature art of the three spell-casting lines (cosmetic only: it never picks
## victims, deals damage, changes timing or touches a summon's behaviour):
##   Mage (นักเวทย์): elemental mastery. A rune circle assembles under the caster (and
##     under the target of a big spell) before the release; fire rolls up in licking
##     tongues under dark smoke and a heat-haze column, ice creeps over the ground as
##     frost and grows crystals that overshoot and settle, lightning forks naturally and
##     leaves an afterglow, a landing meteor leaves a crater that glows and then cools
##     to scorched ground.
##   Priest (นักบวช): holy light. God rays slant down from the sky, feathers drift on
##     the air, a heal is light motes rising from a soft bloom ring at the feet, a
##     judgement is a pillar of light with a dust halo, a shield is a glass dome of light
##     with a refraction shimmer.
##   Summoner (ผู้เรียกอสูร): nature and spirits. Summons arrive through a blooming
##     flower portal with pollen, vines grow and curl, spirits rise as soft ghostly
##     wisps, buffs swirl leaves round the party, the legends (Wind Monkey King,
##     Poseidon) enter through a wind or water vortex.
## The Bard's own art (music made visible) is BardSkillArt, which shares the motion
## engine (NaturalArt) and some pieces (motes, glass shards) from here.
##
## Every composition lists its layers core first; NaturalArt drops the secondary and
## debris tiers on low quality / memory pressure, and the per-cast cap keeps the
## first ones in a crowd. One node per cast, one MeshInstance3D per layer, shared
## meshes (built once, released on travel with the other effect caches).

const KINDS := "rune_circle rune_ring flame smoke haze crystal frost bolt0 bolt1 bolt2 crater scorch ray feather mote bloom dome pillar dust flower leaf vine wisp funnel glass"
const FAMILIES := ["mage", "priest", "summoner"]
## [primary, accent (white-hot core), shade]: saturated primaries so additive light
## keeps its hue on a sunny field; the shade is the dark rim of the ink pieces.
const FIRE := [Color("ff6a1f"), Color("fff0b8"), Color("3a0c04")]
const EMBER := [Color("ff4a14"), Color("ffd27a"), Color("2a0804")]
## Flames are drawn opaque (ink): a yellow-white core (inlay), an orange body, a deep red rim,
## so they keep their colour over a bright field where additive light turns yellow.
const FLAME := [Color("ff6a10"), Color("ffb432"), Color("c8300a")]
const SMOKE := [Color("a89c92"), Color("d8ccc0"), Color("5e5450")]
const SCORCH := [Color("5a2a14"), Color("ff7a2a"), Color("140806")]
const ICE := [Color("36b8ff"), Color("effcff"), Color("0a2448")]
const FROST := [Color("7ad8ff"), Color("ffffff"), Color("0c2a4a")]
const THUNDER := [Color("7a6aff"), Color("ffffff"), Color("14103a")]
const ARCANE := [Color("9a5cff"), Color("f6ecff"), Color("1c0c3a")]
const EARTH := [Color("c08040"), Color("fff0c8"), Color("2a1808")]
const WATER := [Color("1a9cff"), Color("e6fbff"), Color("041c40")]
const HOLY := [Color("ffb21f"), Color("fffbe6"), Color("4a2a08")]
## God rays: a warm, low-saturation sunbeam (additive gold over a meadow reads lime).
const HOLY_BOLT := [Color("ffa83a"), Color("ffffff"), Color("4a2a08")]
const SUN := [Color("ff9a3a"), Color("fff4dc"), Color("4a2a08")]
const HEAL := [Color("3fe08a"), Color("f0fff4"), Color("06301e")]
const DUST := [Color("e0c8a0"), Color("fff0d0"), Color("8a7458")]
const NATURE := [Color("5ad04a"), Color("f4ffd0"), Color("0e3410")]
const LEAF := [Color("5cc84a"), Color("e0ffa0"), Color("1c4a18")]
const BLOSSOM := [Color("ff7ab8"), Color("fff0f6"), Color("3a0a22")]
const POLLEN := [Color("ffc81f"), Color("fffbe0"), Color("3a2a06")]
const SPIRIT := [Color("38dcc8"), Color("f0fffc"), Color("06302e")]
const WIND := [Color("58e8a8"), Color("f0fff8"), Color("0a3424")]
const CONTACT_GAP_MS := 110
## Decorations a god skill's beat leaves free for GodSkillArt's avatar and temple.
const GOD_ROOM := 30
## Where a spell leaves the caster's hands (hero-local, facing +Z).
const HAND := Vector3(0.0, 1.25, 0.45)

static var _meshes: Dictionary = {}
static var _last_contact: Dictionary = {}


static func family(skill: Dictionary) -> String:
	return SkillShow.family_of(skill)


static func handles(skill: Dictionary) -> bool:
	return not skill.is_empty() and family(skill) in FAMILIES


## The element a skill is drawn in (by id first, then by its vfx / shape).
static func element(skill: Dictionary) -> String:
	var id := String(skill.get("id", ""))
	match id:
		"fire_bolt", "fire_ball", "flame_wave", "meteo", "hell_meteor", "fire_elemental", "armageddon": return "fire"
		"diastrophism", "earth_shatter": return "earth"
		"watornado": return "water"
		"ice_storm", "glacial_spike", "crystal_prison", "summon_muspell": return "ice"
		"dead_ray", "thunder_storm", "multi_spark", "divine_lightning", "chain_lightning": return "thunder"
		"energy_shield", "holy_reflection", "seraph_aegis": return "dome"
		"spore_burst": return "pollen"
		"moonwolf_pact", "celestial_dragon_emperor": return "wind"
		"leviathan_surge", "eclipse_sovereign": return "water"
	var fam := family(skill)
	var fx: Dictionary = skill.get("fx", {})
	var shape := String(skill.get("shape", "single"))
	if shape == "summon":
		return "portal"
	if fam == "priest":
		if fx.has("heal") and shape == "self":
			return "heal"
		return "holy"
	if fam == "summoner":
		if fx.has("heal") and shape == "self":
			return "bloom"
		if shape == "self":
			return "leaves"
		return "nature"
	return "arcane"


static func palette(skill: Dictionary) -> Array:
	match element(skill):
		"fire": return FIRE
		"earth": return EARTH
		"water": return WATER
		"ice": return ICE
		"thunder": return THUNDER if family(skill) == "mage" else HOLY_BOLT
		"dome": return ARCANE if family(skill) == "mage" else HOLY
		"heal": return HEAL
		"holy": return HOLY
		"bloom": return BLOSSOM
		"pollen": return POLLEN
		"wind": return WIND
		"nature", "leaves": return NATURE
		"portal":
			match family(skill):
				"priest": return ICE
				"summoner": return NATURE
			return FIRE if String(skill.get("id", "")) == "fire_elemental" else ARCANE
	return ARCANE


static func layer_cap() -> int:
	return int([6, 12, 20][VfxBudget.quality()] * MemoryGuard.effect_scale())


func _sculpture(kind: String) -> ArrayMesh:
	return mesh(kind)


static func _root(parent: Node3D, at: Vector3, label: String, yaw := 0.0) -> CasterArt:
	var art := CasterArt.new()
	art.name = label
	art.cap = layer_cap()
	parent.add_child(art)
	art.global_position = at
	art.rotation.y = yaw
	return art


func _bind(visual: HeroVisual) -> void:
	if visual:
		owner_ref = weakref(visual)
		generation = visual.skill_generation


static func _crowded() -> bool:
	var now := Time.get_ticks_msec()
	return SkillShow._recent_shows.filter(func(t: int): return now - t < 1000).size() >= 3


static func warm_geometry() -> void:
	for kind in KINDS.split(" "):
		mesh(String(kind))


## Draws both materials once, invisibly, so the first cast does not stall on a phone.
static func warm_up(parent: Node3D, at: Vector3) -> void:
	warm_geometry()
	var art := _root(parent, at, "CasterArt_Warm")
	art.cap = 2
	art.layer("flame", true, FIRE, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})
	art.layer("smoke", false, SMOKE, Vector3.UP, Vector3.ONE * 0.01, Vector3.ZERO, 0.0, 0.3, {"opacity": 0.001})


static func release_mesh_cache() -> void:
	_meshes.clear()


# ---------------------------------------------------------------------------
# Entry points (hooked from BardSkillArt, StarSkillArt, the Mage's sequences and Summon)
# ---------------------------------------------------------------------------

## Wind-up, bound to the caster's skill generation (a cancelled cast drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or duration < 0.12 or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	if id in ["armageddon", "thunder_storm", "judgment_ray"]:
		return
	var time := maxf(duration, 0.15)
	var art := _root(parent, origin, "CasterArt_Windup_" + id, _yaw(origin, aim))
	art._bind(visual)
	if _crowded():
		art.cap = mini(art.cap, 4)
	art._windup(skill, art.to_local(Vector3(aim.x, origin.y, aim.z)), time)


## Release, at the beat of the skill's damage ([param delay]: a meteor's landing).
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	if id in ["armageddon", "thunder_storm", "judgment_ray"]:
		return
	var shape := String(skill.get("shape", "single"))
	var at := origin if shape in ["self", "summon", "burst"] else center
	var art := _root(parent, Vector3(at.x, origin.y, at.z), "CasterArt_" + id, _yaw(origin, center))
	if _crowded():
		art.cap = mini(art.cap, 6)
	art._release(skill, art.to_local(Vector3(origin.x, origin.y, origin.z)), minf(float(skill.get("radius", 3.0)), 10.0), maxf(delay, 0.0))


## Every real hit: a small elemental mark on the struck foe (throttled per skill).
static func contact(parent: Node3D, skill: Dictionary, at: Vector3) -> void:
	if not handles(skill) or skill.has("star") or not _alive(parent) or not VfxBudget.can_decorate(2 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var q := VfxBudget.quality()
	var now := Time.get_ticks_msec()
	if now - int(_last_contact.get(id, -100000)) < int(CONTACT_GAP_MS * [2.2, 1.5, 1.0][q]):
		return
	_last_contact[id] = now
	var art := _root(parent, at, "CasterArt_Hit_" + id)
	art.cap = mini(art.cap, [2, 3, 4][q])
	art._mark(element(skill), palette(skill))


## Star skills (★50-★300): a wind-up and one composition per contact beat.
static func star_telegraph(parent: Node3D, skill: Dictionary, origin: Vector3, point: Vector3, duration: float, visual: HeroVisual = null) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(4 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var art := _root(parent, origin, "CasterArt_StarWindup_" + id, _yaw(origin, point))
	art._bind(visual)
	art._star_windup(id, skill, art.to_local(Vector3(point.x, origin.y, point.z)), maxf(duration, 0.15))


static func star(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var god := StarSkillData.is_god(skill)
	# A god skill's own avatar and temple (GodSkillArt) come first: these layers only
	# accompany it while the budget leaves the god sculpture its room.
	if god and not VfxBudget.can_decorate(3 + RESERVE + GOD_ROOM):
		return
	var shape := String(skill.get("shape", ""))
	var at := source if shape in ["self", "summon"] else Vector3(point.x, source.y, point.z)
	var art := _root(parent, at, "CasterArt_Star_%s_%d" % [id, index], _yaw(source, point))
	if god:
		art.cap = mini(art.cap, 6)
	art._star_beat(id, skill, index, clampf(float(skill.get("radius", 6.0)), 3.0, 10.0), art.to_local(source))


## A summoned creature arrives: a flower / leaf portal opens under it with pollen; a
## legend (Wind Monkey King, Poseidon) arrives in a wind or water vortex. Called by
## Summon when the creature enters the field (its behaviour is untouched).
static func summon_arrival(parent: Node3D, skill: Dictionary, at: Vector3, size := 1.0) -> void:
	if not handles(skill) or not _alive(parent) or not VfxBudget.can_decorate(3 + RESERVE):
		return
	var id := String(skill.get("id", ""))
	var art := _root(parent, at, "CasterArt_Arrive_" + id)
	var kind := String(skill.get("summon", {}).get("kind", ""))
	var s := clampf(size, 0.6, 2.0)
	if kind == "wind_king" or id == "moonwolf_pact":
		art._vortex(WIND, Vector3.ZERO, 1.5 * s, 4.2 * s, 0.0, 1.5, "leaf")
		art._portal(NATURE, Vector3.ZERO, 1.4 * s, 0.05)
	elif kind == "poseidon" or id == "eclipse_sovereign":
		art._vortex(WATER, Vector3.ZERO, 1.6 * s, 4.6 * s, 0.0, 1.6, "mote")
		art._portal(WATER, Vector3.ZERO, 1.5 * s, 0.05)
	else:
		art._portal(palette(skill), Vector3.ZERO, 0.95 * s, 0.0)
		if family(skill) == "summoner":
			art._wisps(SPIRIT, Vector3.ZERO, 0.6 * s, 3, 0.15, 1.3)


# ---------------------------------------------------------------------------
# Motifs: each a few layers, core first.
# ---------------------------------------------------------------------------

## A rune circle that assembles: the outer ring grows in and overshoots, the inner
## hexagram closes in from outside turning the other way, glyph sparks lift off.
func _rune(c: Array, at: Vector3, r: float, start: float, seconds: float, glyphs := true) -> void:
	layer("rune_circle", true, c, at + Vector3.UP * 0.04, Vector3.ONE * r, Vector3.ZERO, start, seconds, {"initial": 0.12, "grow": 1.8, "overshoot": true, "spin": 0.7, "fade_in": 0.25, "decay": 0.8, "opacity": 0.68})
	layer("rune_ring", true, c, at + Vector3.UP * 0.06, Vector3.ONE * r * 0.64, Vector3.ZERO, start + 0.06, maxf(seconds - 0.06, 0.1), {"initial": 1.6, "grow": 2.2, "spin": -1.3, "fade_in": 0.3, "decay": 0.8, "opacity": 0.75, "tier": TIER_MID})
	if glyphs:
		for k in count(4):
			var a := float(k) * TAU / 4.0 + 0.4
			layer("mote", true, c, at + Vector3(sin(a), 0.1, cos(a)) * r * 0.82, Vector3.ONE * 0.26, Vector3.ZERO, start + seconds * 0.3 + 0.05 * float(k), seconds * 0.7, {"initial": 0.3, "travel": Vector3(0, 0.9, 0), "sway": 0.06, "phase": a, "face_camera": true, "decay": 0.6, "tier": TIER_DEBRIS})


## Rolling fire: flame tongues licking up at golden-angle spots, dark smoke rolling
## off their tops on the wind, a heat-haze column and embers thrown up.
func _flames(at: Vector3, r: float, n: int, start: float, seconds: float, height := 1.4, ring := false) -> void:
	var total := count(n)
	for k in total:
		var a := float(k) * 2.39996 + 0.3
		var d := r * (0.9 if ring else sqrt(float(k + 1) / float(total + 1)) * 0.85)
		var spot := at + Vector3(sin(a), 0.02, cos(a)) * d
		var h := height * 1.35 * (0.75 + 0.5 * fmod(float(k) * 0.618, 1.0))
		var life := seconds * (0.8 + 0.3 * fmod(float(k) * 0.37, 1.0))
		var lick := {"initial": 0.15, "grow": 3.2, "overshoot": true, "travel": Vector3(0, h * 0.25, 0), "sway": 0.05 * h, "sway_rate": 2.6, "phase": a, "flutter": 0.12, "face_camera": true, "fade_in": 0.05, "decay": 0.55, "opacity": 0.92, "tier": TIER_CORE if k < 3 else TIER_MID}
		layer("flame", false, FLAME, spot, Vector3(h, h, h), Vector3.ZERO, start + 0.035 * float(k), life, lick)
		layer("flame", true, FIRE if k % 3 else EMBER, spot + Vector3(0, 0.02, 0), Vector3(h * 1.15, h * 1.1, h * 1.15), Vector3.ZERO, start + 0.035 * float(k), life, lick.merged({"opacity": 0.35, "tier": TIER_MID}, true))
	for k in count(maxi(2, n / 2)):
		var a := float(k) * 2.39996 + 1.1
		var spot := at + Vector3(sin(a), 0, cos(a)) * r * 0.5 + Vector3.UP * height * 0.9
		layer("smoke", false, SMOKE, spot, Vector3.ONE * (1.9 + 0.45 * float(k % 3)) * clampf(height, 0.8, 2.2), Vector3(0, 0, a), start + 0.18 + 0.06 * float(k), seconds + 0.6, {"initial": 0.35, "grow": 1.1, "travel": Vector3(0.5, 1.8, 0.2), "sway": 0.18, "sway_rate": 0.6, "phase": a, "roll": 0.4, "face_camera": true, "fade_in": 0.25, "decay": 0.45, "opacity": 0.5, "tier": TIER_MID})
	# Heat haze: a barely-there shimmer column above the flames (the glow shader's light streams ripple it).
	layer("haze", true, FIRE, at + Vector3.UP * height * 0.5, Vector3(maxf(r * 0.6, 0.6), height * 1.6, maxf(r * 0.6, 0.6)), Vector3.ZERO, start + 0.1, seconds, {"initial": 0.8, "grow": 2.0, "spin": 0.6, "travel": Vector3(0, 0.6, 0), "fade_in": 0.3, "decay": 0.5, "opacity": 0.035, "tier": TIER_DEBRIS})
	_sparks(EMBER, at + Vector3.UP * 0.4, 5, maxf(r * 0.35, 0.4), start + 0.08, 2.6)


## Embers / sparks / chips thrown up and falling back under gravity (debris tier).
func _sparks(c: Array, at: Vector3, n: int, spread: float, start: float, up := 2.4, kind := "mote", size := 0.16, glow := true) -> void:
	for k in count(n):
		var a := float(k) * 2.39996 + randf() * 0.5
		var v := Vector3(sin(a) * spread * 1.6, up * (0.7 + 0.5 * randf()), cos(a) * spread * 1.6)
		layer(kind, glow, c, at, Vector3.ONE * size, Vector3(0, 0, randf() * TAU), start + 0.02 * float(k), 0.9, {"initial": 1.0, "toss": v, "gravity": 6.5, "drag": 0.6, "floor": 0.05, "roll": 5.0 * (1.0 if k % 2 else -1.0), "face_camera": kind == "mote", "decay": 0.55, "tier": TIER_DEBRIS})


## Frost creeps over the ground and crystals grow from it, overshooting and settling;
## chips break off as it thaws.
func _ice(c: Array, at: Vector3, r: float, n: int, start: float, height := 1.2, seconds := 1.6) -> void:
	layer("frost", true, FROST, at + Vector3.UP * 0.03, Vector3.ONE * r, Vector3(0, randf() * TAU, 0), start, seconds + 0.4, {"initial": 0.04, "grow": 1.3, "fade_in": 0.08, "decay": 0.75, "opacity": 0.75})
	var total := count(n)
	for k in total:
		var a := float(k) * 2.39996 + 0.7
		var d := r * 0.8 * sqrt(float(k + 1) / float(total + 1))
		var spot := at + Vector3(sin(a), 0, cos(a)) * d
		var h := height * (0.6 + 0.6 * fmod(float(k) * 0.618 + 0.2, 1.0))
		var tilt := Vector3(cos(a) * 0.35, 0, -sin(a) * 0.35)
		var t := TIER_CORE if k < 3 else TIER_MID
		layer("crystal", false, c, spot, Vector3(h * 0.7, h, h * 0.7), tilt + Vector3(0, a, 0), start + 0.12 + 0.04 * float(k), seconds, {"initial": 0.04, "grow": 4.5, "overshoot": true, "fade_in": 0.04, "decay": 0.78, "opacity": 0.92, "tier": t})
		layer("crystal", true, c, spot, Vector3(h * 0.72, h * 1.02, h * 0.72), tilt + Vector3(0, a, 0), start + 0.12 + 0.04 * float(k), seconds, {"initial": 0.04, "grow": 4.5, "overshoot": true, "fade_in": 0.04, "decay": 0.7, "opacity": 0.45, "tier": TIER_MID})
	_sparks(c, at + Vector3.UP * 0.5, 5, maxf(r * 0.3, 0.4), start + seconds * 0.72, 2.0, "crystal", 0.22, false)


## A lightning strike from the sky with natural forks, a flash, then a long afterglow
## of the same channel and a scorch where it grounded.
func _bolt(c: Array, at: Vector3, height: float, start: float, width := 1.4) -> void:
	var kind := "bolt%d" % (randi() % 3)
	var lean := Vector3(0, 0, randf_range(-0.12, 0.12))
	layer(kind, true, c, at, Vector3(width, height, 1.0), lean, start, 0.2, {"initial": 1.0, "face_camera": true, "fade_in": 0.01, "decay": 0.35, "opacity": 1.0})
	layer(kind, true, c, at, Vector3(width * 1.15, height, 1.0), lean, start + 0.06, 0.85, {"initial": 1.0, "face_camera": true, "fade_in": 0.02, "decay": 0.15, "opacity": 0.32, "tier": TIER_MID})
	layer("scorch", false, SCORCH, at + Vector3.UP * 0.03, Vector3.ONE * 0.9, Vector3(0, randf() * TAU, 0), start, 1.4, {"initial": 0.5, "grow": 8.0, "decay": 0.6, "opacity": 0.55, "tier": TIER_MID})
	_sparks(c, at + Vector3.UP * 0.2, 4, 0.5, start + 0.02, 2.2)


## A crater that glows hot, then cools to scorched ground; dust rolls out of it.
func _crater(at: Vector3, r: float, start: float, cool := 2.4) -> void:
	layer("crater", true, FIRE, at + Vector3.UP * 0.05, Vector3.ONE * r, Vector3(0, randf() * TAU, 0), start, 1.1, {"initial": 0.5, "grow": 7.0, "fade_in": 0.03, "decay": 0.35, "opacity": 0.9})
	layer("scorch", false, SCORCH, at + Vector3.UP * 0.035, Vector3.ONE * r * 1.15, Vector3(0, randf() * TAU, 0), start, cool, {"initial": 0.7, "grow": 6.0, "fade_in": 0.04, "decay": 0.62, "opacity": 0.75, "tier": TIER_MID})
	layer("dust", false, DUST, at, Vector3(r * 1.05, 0.9, r * 1.05), Vector3.ZERO, start + 0.03, 1.3, {"initial": 0.45, "grow": 2.6, "travel": Vector3(0, 0.3, 0), "spin": 0.25, "fade_in": 0.05, "decay": 0.45, "opacity": 0.6, "tier": TIER_DEBRIS})


## God rays slanting down from the sky.
func _rays(c: Array, at: Vector3, r: float, n: int, start: float, seconds: float, height := 9.0) -> void:
	for k in count(n):
		var a := float(k) * 2.39996 + 0.9
		var spot := at + Vector3(sin(a), 0, cos(a)) * r * 0.55 * sqrt(float(k) / float(maxi(n, 1)))
		var w := 2.2 + 0.8 * fmod(float(k) * 0.618, 1.0)
		layer("ray", true, SUN if c == HOLY else c, spot, Vector3(w, height, w), Vector3(0.06, a, 0.04), start + 0.07 * float(k), seconds, {"initial": 0.5, "grow": 1.6, "fade_in": 0.35, "decay": 0.6, "opacity": 0.2, "tier": TIER_CORE if k == 0 else TIER_MID})


## Feathers drifting down on the air: a slow fall, a lazy sway and a rocking flutter.
func _feathers(c: Array, at: Vector3, r: float, n: int, start: float, high := 3.4) -> void:
	for k in count(n):
		var a := float(k) * 2.39996 + 0.2
		var spot := at + Vector3(sin(a), 0, cos(a)) * r * 0.8 * sqrt(float(k + 1) / float(n + 1)) + Vector3.UP * (high + 0.5 * fmod(float(k) * 0.618, 1.0))
		layer("feather", true, c, spot, Vector3.ONE * 0.5, Vector3(0, 0, randf_range(-0.8, 0.8)), start + 0.08 * float(k), 2.2, {"initial": 0.7, "grow": 6.0, "toss": Vector3(0.25, -1.05, 0.0), "sway": 0.32, "sway_rate": 0.55, "phase": a, "flutter": 0.55, "face_camera": true, "fade_in": 0.12, "decay": 0.72, "opacity": 0.85, "tier": TIER_MID if k < 3 else TIER_DEBRIS})


## A heal: a soft bloom ring at the feet and light motes rising from it.
func _heal(c: Array, at: Vector3, r: float, n: int, start: float, seconds := 1.4) -> void:
	layer("bloom", true, c, at + Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, start, seconds, {"initial": 0.25, "grow": 2.6, "overshoot": true, "spin": 0.35, "fade_in": 0.08, "decay": 0.6, "opacity": 0.75})
	for k in count(n):
		var a := float(k) * 2.39996
		var spot := at + Vector3(sin(a), 0, cos(a)) * r * 0.75 * sqrt(float(k + 1) / float(n + 1)) + Vector3.UP * 0.15
		layer("mote", true, c, spot, Vector3.ONE * (0.5 + 0.12 * float(k % 3)), Vector3.ZERO, start + 0.05 + 0.045 * float(k), seconds, {"initial": 0.4, "travel": Vector3(0, 1.8 + 0.8 * fmod(float(k) * 0.618, 1.0), 0), "sway": 0.12, "sway_rate": 0.9, "phase": a, "face_camera": true, "roll": 1.2, "fade_in": 0.15, "decay": 0.55, "tier": TIER_CORE if k < 2 else TIER_MID})


## A pillar of judgement light with a dust halo blown out at its foot.
func _pillar(c: Array, at: Vector3, r: float, start: float, seconds := 0.9, height := 8.0) -> void:
	layer("pillar", true, c, at, Vector3(r, height, r), Vector3.ZERO, start, seconds, {"initial": 0.15, "grow": 6.0, "overshoot": true, "spin": 1.2, "fade_in": 0.02, "decay": 0.45, "opacity": 0.32})
	layer("dust", false, DUST, at, Vector3(r * 1.7, 0.8, r * 1.7), Vector3.ZERO, start + 0.03, 1.2, {"initial": 0.4, "grow": 3.0, "travel": Vector3(0, 0.25, 0), "spin": 0.3, "fade_in": 0.04, "decay": 0.45, "opacity": 0.65, "tier": TIER_MID})
	layer("bloom", true, c, at + Vector3.UP * 0.04, Vector3.ONE * r * 1.6, Vector3.ZERO, start, 0.7, {"initial": 0.3, "grow": 5.0, "decay": 0.45, "opacity": 0.6, "tier": TIER_DEBRIS})


## A glass dome of light with a refraction shimmer, settling with a little overshoot.
func _dome(c: Array, at: Vector3, r: float, start: float, seconds: float) -> void:
	layer("dome", true, c, at, Vector3.ONE * r, Vector3.ZERO, start, seconds, {"initial": 0.25, "grow": 3.0, "overshoot": true, "spin": 0.3, "pulse": 4.0, "fade_in": 0.06, "decay": 0.72, "opacity": 0.32})
	layer("bloom", true, c, at + Vector3.UP * 0.03, Vector3.ONE * r * 1.05, Vector3.ZERO, start, seconds * 0.8, {"initial": 0.3, "grow": 3.0, "spin": -0.4, "decay": 0.6, "opacity": 0.4, "tier": TIER_MID})


## A flower portal: petals open with an overshoot, pollen lifts off on a breeze,
## a few leaves are thrown out.
func _portal(c: Array, at: Vector3, size: float, start: float, seconds := 1.5) -> void:
	layer("flower", false, LEAF if c != BLOSSOM else BLOSSOM, at + Vector3.UP * 0.03, Vector3.ONE * size * 1.1, Vector3(0, 0.4, 0), start, seconds, {"initial": 0.04, "grow": 2.0, "overshoot": true, "spin": 0.35, "fade_in": 0.05, "decay": 0.7, "opacity": 0.8, "tier": TIER_MID})
	layer("flower", true, c, at + Vector3.UP * 0.06, Vector3.ONE * size, Vector3.ZERO, start, seconds, {"initial": 0.04, "grow": 2.2, "overshoot": true, "spin": 0.5, "fade_in": 0.05, "decay": 0.7, "opacity": 0.8})
	for k in count(6):
		var a := float(k) * 2.39996
		layer("mote", true, POLLEN, at + Vector3(sin(a), 0.2, cos(a)) * size * 0.5, Vector3.ONE * 0.18, Vector3.ZERO, start + 0.15 + 0.05 * float(k), 1.4, {"initial": 0.5, "travel": Vector3(0.3, 1.6 + 0.4 * float(k % 3), 0.1), "sway": 0.18, "sway_rate": 0.8, "phase": a, "face_camera": true, "decay": 0.6, "tier": TIER_MID if k < 3 else TIER_DEBRIS})
	_sparks(LEAF, at + Vector3.UP * 0.3, 4, size * 0.5, start + 0.1, 2.0, "leaf", 0.3, false)


## Vines growing and curling out of the ground at golden-angle spots.
func _vines(at: Vector3, r: float, n: int, start: float, seconds := 1.5, height := 1.4) -> void:
	var total := count(n)
	for k in total:
		var a := float(k) * 2.39996 + 0.5
		var spot := at + Vector3(sin(a), 0, cos(a)) * r * 0.85 * sqrt(float(k + 1) / float(total + 1))
		var h := height * (0.7 + 0.5 * fmod(float(k) * 0.618, 1.0))
		layer("vine", false, LEAF, spot, Vector3(h * 0.8, h, h * 0.8), Vector3(0, a, 0), start + 0.05 * float(k), seconds, {"initial": 0.04, "grow": 2.6, "overshoot": true, "spin": 0.25, "fade_in": 0.04, "decay": 0.78, "opacity": 0.95, "tier": TIER_CORE if k < 3 else TIER_MID})


## Leaves swirling round [param at], rising as they turn.
func _leaf_swirl(c: Array, at: Vector3, r: float, n: int, start: float, seconds: float, rise := 1.4, glow := false) -> void:
	for k in count(n):
		var y := 0.3 + 0.9 * fmod(float(k) * 0.618, 1.0)
		layer("leaf", glow, c, at + Vector3(0, y, 0), Vector3.ONE * (0.44 + 0.08 * float(k % 3)), Vector3.ZERO, start + 0.03 * float(k), seconds, {"initial": 0.4, "orbit": r * (0.85 + 0.25 * fmod(float(k) * 0.37, 1.0)), "orbit_speed": 3.2, "phase": TAU * float(k) / float(n), "travel": Vector3(0, rise, 0), "flutter": 0.7, "face_camera": true, "fade_in": 0.12, "decay": 0.7, "tier": TIER_CORE if k < 2 else (TIER_MID if k < 5 else TIER_DEBRIS)})


## Ghostly spirit wisps rising and circling, their tails lagging below them.
func _wisps(c: Array, at: Vector3, r: float, n: int, start: float, seconds: float) -> void:
	for k in count(n):
		layer("wisp", true, c, at + Vector3.UP * (0.4 + 0.3 * float(k % 2)), Vector3.ONE * 0.62, Vector3.ZERO, start + 0.07 * float(k), seconds, {"initial": 0.4, "orbit": r, "orbit_speed": 2.3, "phase": TAU * float(k) / float(maxi(n, 1)), "travel": Vector3(0, 1.4, 0), "bob": 0.12, "face_camera": true, "fade_in": 0.15, "decay": 0.6, "opacity": 0.7, "tier": TIER_MID if k < 2 else TIER_DEBRIS})


## A wind or water vortex: a turning funnel, a counter-turning inner one and debris
## (leaves or droplets) carried round it.
func _vortex(c: Array, at: Vector3, r: float, h: float, start: float, seconds: float, debris := "leaf") -> void:
	layer("funnel", true, c, at, Vector3(r, h, r), Vector3.ZERO, start, seconds, {"initial": 0.2, "grow": 2.2, "overshoot": true, "spin": 5.0, "fade_in": 0.08, "decay": 0.7, "opacity": 0.6})
	layer("funnel", true, c, at, Vector3(r * 0.6, h * 0.85, r * 0.6), Vector3(0, 1.0, 0), start + 0.08, seconds * 0.9, {"initial": 0.3, "grow": 2.5, "spin": -7.0, "fade_in": 0.08, "decay": 0.7, "opacity": 0.45, "tier": TIER_MID})
	for k in count(7):
		layer(debris, debris != "leaf", c if debris != "leaf" else LEAF, at + Vector3.UP * (0.3 + 0.35 * float(k)), Vector3.ONE * 0.28, Vector3.ZERO, start + 0.05 * float(k), seconds, {"initial": 0.5, "orbit": r * (0.5 + 0.12 * float(k)), "orbit_speed": 6.0 - 0.3 * float(k), "phase": float(k) * 2.4, "travel": Vector3(0, 1.0, 0), "flutter": 0.6, "face_camera": true, "decay": 0.7, "tier": TIER_DEBRIS})


## The per-hit mark of an element on a struck foe ([param at]: the body point).
func _mark(el: String, c: Array) -> void:
	var feet := Vector3(0, -0.9, 0)
	match el:
		"fire":
			for k in count(2):
				layer("flame", false, FLAME, feet + Vector3(0.25 * (float(k) - 0.5), 0.02, 0.1), Vector3(0.5, 0.8, 0.5), Vector3.ZERO, 0.02 * float(k), 0.6, {"initial": 0.2, "grow": 5.0, "overshoot": true, "sway": 0.04, "sway_rate": 3.0, "face_camera": true, "decay": 0.5})
			layer("smoke", false, SMOKE, Vector3(0, 0.2, 0), Vector3.ONE * 0.6, Vector3.ZERO, 0.1, 0.9, {"initial": 0.4, "travel": Vector3(0.2, 1.0, 0), "face_camera": true, "decay": 0.5, "opacity": 0.45, "tier": TIER_MID})
		"ice":
			layer("frost", true, FROST, feet + Vector3.UP * 0.03, Vector3.ONE * 0.9, Vector3(0, randf() * TAU, 0), 0.0, 0.9, {"initial": 0.1, "grow": 3.0, "decay": 0.6, "opacity": 0.7})
			for k in count(3):
				var a := float(k) * TAU / 3.0 + randf()
				layer("crystal", false, c, feet + Vector3(sin(a), 0, cos(a)) * 0.45, Vector3(0.3, 0.55, 0.3), Vector3(cos(a) * 0.4, a, -sin(a) * 0.4), 0.03 * float(k), 0.8, {"initial": 0.05, "grow": 6.0, "overshoot": true, "decay": 0.7, "tier": TIER_MID})
		"thunder":
			var kind := "bolt%d" % (randi() % 3)
			layer(kind, true, c, feet, Vector3(0.6, 2.4, 1.0), Vector3.ZERO, 0.0, 0.5, {"initial": 1.0, "face_camera": true, "fade_in": 0.01, "decay": 0.2, "opacity": 0.8})
			_sparks(c, Vector3.ZERO, 3, 0.3, 0.0, 1.6)
		"earth":
			layer("dust", false, DUST, feet, Vector3(0.9, 0.6, 0.9), Vector3.ZERO, 0.0, 0.8, {"initial": 0.4, "grow": 4.0, "decay": 0.5, "opacity": 0.6})
			_sparks(EARTH, Vector3.ZERO, 3, 0.4, 0.0, 2.0, "crystal", 0.16, false)
		"holy", "heal", "dome":
			layer("pillar", true, c, feet, Vector3(0.45, 2.6, 0.45), Vector3.ZERO, 0.0, 0.45, {"initial": 0.2, "grow": 8.0, "decay": 0.4, "opacity": 0.6})
			layer("mote", true, c, Vector3(0, 0.3, 0), Vector3.ONE * 0.4, Vector3.ZERO, 0.0, 0.5, {"initial": 0.3, "grow": 6.0, "travel": Vector3(0, 0.6, 0), "face_camera": true, "roll": 2.0, "decay": 0.5, "tier": TIER_MID})
		"nature", "leaves", "bloom", "pollen", "wind":
			layer("vine", false, LEAF, feet, Vector3(0.6, 0.9, 0.6), Vector3(0, randf() * TAU, 0), 0.0, 0.9, {"initial": 0.05, "grow": 4.0, "overshoot": true, "decay": 0.7})
			_sparks(LEAF, Vector3.ZERO, 3, 0.35, 0.0, 1.6, "leaf", 0.26, false)
		"water":
			layer("funnel", true, WATER, feet, Vector3(0.6, 1.4, 0.6), Vector3.ZERO, 0.0, 0.6, {"initial": 0.3, "grow": 5.0, "spin": 7.0, "decay": 0.5, "opacity": 0.5})
			_sparks(WATER, Vector3.ZERO, 3, 0.4, 0.0, 2.0)
		_:
			layer("rune_ring", true, c, feet + Vector3.UP * 0.04, Vector3.ONE * 0.7, Vector3.ZERO, 0.0, 0.6, {"initial": 1.5, "grow": 5.0, "spin": 3.0, "decay": 0.6, "opacity": 0.7})
			_sparks(c, Vector3.ZERO, 3, 0.3, 0.0, 1.8)


# ---------------------------------------------------------------------------
# Compositions
# ---------------------------------------------------------------------------

## Wind-up (root at the caster facing the aim; [param target]: the aim in root space).
func _windup(skill: Dictionary, target: Vector3, time: float) -> void:
	var fam := family(skill)
	var el := element(skill)
	var c := palette(skill)
	var level := int(skill.get("level", 1))
	var shape := String(skill.get("shape", "single"))
	var r := minf(float(skill.get("radius", 3.0)), 10.0)
	var big := level >= 40 and shape in ["blast", "burst"]
	match fam:
		"mage":
			# The rune circle assembles under the caster; a big spell draws a second one at its target.
			_rune(c, Vector3.ZERO, 1.1 + 0.08 * float(mini(level / 20, 5)), 0.0, time + 0.1)
			if big:
				var spot := target if shape == "blast" else Vector3.ZERO
				_rune(c, spot, r * 0.8, time * 0.15, time * 0.85 + 0.15, false)
			match el:
				"fire":
					layer("flame", true, FIRE, HAND + Vector3(0, -0.2, 0), Vector3(0.35, 0.55, 0.35), Vector3.ZERO, time * 0.2, time * 0.8 + 0.05, {"initial": 0.2, "grow": 2.0, "sway": 0.03, "sway_rate": 3.0, "face_camera": true, "fade_in": 0.2, "decay": 0.9, "tier": TIER_MID})
				"ice", "water":
					layer("frost", true, FROST, Vector3.UP * 0.035, Vector3.ONE * 1.3, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.1, "grow": 1.2, "fade_in": 0.2, "decay": 0.85, "opacity": 0.6, "tier": TIER_MID})
				"thunder":
					for k in count(2):
						layer("bolt%d" % k, true, c, HAND + Vector3(0.2 * (float(k) - 0.5), -0.3, 0), Vector3(0.25, 0.6, 1.0), Vector3(0, 0, 0.6 * (float(k) - 0.5)), time * 0.5 + 0.08 * float(k), 0.15, {"initial": 1.0, "face_camera": true, "fade_in": 0.01, "decay": 0.3, "tier": TIER_MID})
		"priest":
			# A soft god ray finds the priest, a halo ring at the feet; a judgement marks its target.
			_rays(HOLY, Vector3.ZERO, 0.6, 1, 0.0, time + 0.2, 7.0)
			layer("bloom", true, HOLY if el != "heal" else HEAL, Vector3.UP * 0.03, Vector3.ONE * 1.2, Vector3.ZERO, 0.0, time + 0.1, {"initial": 0.2, "grow": 1.4, "spin": 0.5, "fade_in": 0.25, "decay": 0.85, "opacity": 0.6, "tier": TIER_MID})
			if level >= 40:
				_feathers(HOLY, Vector3.ZERO, 1.2, 3, 0.0, 2.6)
			if big or (shape == "single" and level >= 60):
				var spot := target if shape != "burst" else Vector3.ZERO
				_rays(HOLY, spot, maxf(r * 0.6, 1.0), 2, time * 0.2, time * 0.8 + 0.2, 8.0)
		"summoner":
			# Leaves gather and swirl up round the summoner over a bud of light.
			_leaf_swirl(LEAF, Vector3.ZERO, 0.9, 6, 0.0, time + 0.1, 0.8)
			layer("flower", true, c if c != NATURE else POLLEN, Vector3.UP * 0.04, Vector3.ONE * 0.9, Vector3.ZERO, 0.0, time + 0.15, {"initial": 0.05, "grow": 1.3, "spin": 0.6, "fade_in": 0.2, "decay": 0.85, "opacity": 0.55, "tier": TIER_MID})
			if big:
				_vines(target if shape == "blast" else Vector3.ZERO, r * 0.7, 3, time * 0.4, time * 0.6 + 0.2, 0.6)


## Release (root at the area / target, or at the caster for self, burst and summon).
func _release(skill: Dictionary, caster: Vector3, r: float, d: float) -> void:
	var id := String(skill.get("id", ""))
	var fam := family(skill)
	var el := element(skill)
	var c := palette(skill)
	var level := int(skill.get("level", 1))
	var shape := String(skill.get("shape", "single"))
	var tier := clampi(level / 20, 0, 5)
	var hits := int(skill.get("hits", 1))
	var body := Vector3(0, 1.0, 0)
	match id:
		# --- Mage, by hand -----------------------------------------------------------
		"meteo", "hell_meteor":
			_crater(Vector3.ZERO, r * 0.55, d, 2.8)
			_flames(Vector3.ZERO, r * 0.7, 6 + tier, d + 0.02, 1.3, 1.6, true)
			_rune(FIRE, Vector3.ZERO, r * 0.9, d, 0.9, false)
			return
		"diastrophism":
			_crater(Vector3.ZERO, r * 0.5, d, 2.2)
			layer("dust", false, DUST, Vector3.ZERO, Vector3(r * 0.9, 1.4, r * 0.9), Vector3.ZERO, d + 0.05, 1.6, {"initial": 0.4, "grow": 2.0, "travel": Vector3(0, 0.6, 0), "spin": 0.2, "decay": 0.5, "opacity": 0.55})
			_sparks(EARTH, Vector3.UP * 0.4, 7, r * 0.25, d, 3.2, "crystal", 0.3, false)
			return
		"watornado":
			_vortex(WATER, Vector3.ZERO, r * 0.4, 4.0, d, 1.4, "mote")
			layer("bloom", true, WATER, Vector3.UP * 0.03, Vector3.ONE * r * 0.7, Vector3.ZERO, d, 1.2, {"initial": 0.3, "grow": 3.0, "spin": 1.5, "decay": 0.6, "opacity": 0.6, "tier": TIER_MID})
			return
		"spirit_burst", "distortion":
			_rune(ARCANE, Vector3.ZERO, r * 0.75, d, 1.1, true)
			layer("dome", true, ARCANE, Vector3.ZERO, Vector3(r * 0.7, r * 0.35, r * 0.7), Vector3.ZERO, d, 0.7, {"initial": 0.2, "grow": 6.0, "decay": 0.4, "opacity": 0.4, "tier": TIER_MID})
			_wisps(ARCANE, Vector3.ZERO, r * 0.4, 4, d + 0.05, 1.2)
			return
		"slow_speed":
			_rune(ARCANE, Vector3.ZERO, r * 0.8, d, 1.6, true)
			_ice(FROST, Vector3.ZERO, r * 0.5, 3, d, 0.6, 1.4)
			return
	match el:
		"fire":
			if shape == "single":
				_flames(Vector3.ZERO, 0.6, 3, d, 0.9, 1.1)
			else:
				_flames(Vector3.ZERO, r * 0.8, 5 + tier, d, 1.2, 1.3 + 0.08 * float(tier), shape == "burst")
				if level >= 40:
					_rune(FIRE, Vector3.ZERO, r * 0.9, d, 0.8, false)
		"earth":
			_crater(Vector3.ZERO, r * 0.5, d, 1.8)
			_sparks(EARTH, Vector3.UP * 0.3, 6, r * 0.25, d, 3.0, "crystal", 0.28, false)
		"ice":
			_ice(c, Vector3.ZERO, maxf(r * 0.8, 1.2), 5 + tier, d, 1.0 + 0.1 * float(tier), 1.5)
		"water":
			_vortex(WATER, Vector3.ZERO, maxf(r * 0.4, 1.0), 3.6, d, 1.3, "mote")
		"thunder":
			if shape in ["chain", "fan"]:
				# The struck foes carry their own bolts (contact); one fork grounds at the first.
				_bolt(c, Vector3.ZERO, 7.0, d, 1.6)
			else:
				_bolt(c, Vector3.ZERO, 8.0, d, 1.8)
				if level >= 60:
					_bolt(c, Vector3(0.9, 0, 0.4), 6.5, d + 0.09, 1.2)
		"dome":
			_dome(c, Vector3.ZERO, 1.6 + 0.1 * float(tier), d, 1.6)
			if fam == "priest":
				_feathers(HOLY, Vector3.ZERO, 1.4, 4, d + 0.1, 2.8)
			else:
				_rune(c, Vector3.ZERO, 1.6, d, 1.2, false)
		"heal":
			var big := float(skill.get("fx", {}).get("heal", 0.3)) >= 0.6 or level >= 60
			_heal(HEAL, Vector3.ZERO, 1.4 + 0.1 * float(tier), 6 + tier, d, 1.5)
			_rays(HOLY, Vector3.ZERO, 0.8, 1 + int(big) * 2, d, 1.5, 8.0)
			if level >= 40:
				_feathers(HOLY, Vector3.ZERO, 1.6, 3 + tier, d + 0.1, 3.0)
			if big:
				layer("dome", true, HEAL, Vector3.ZERO, Vector3(1.8, 1.2, 1.8), Vector3.ZERO, d + 0.05, 1.0, {"initial": 0.3, "grow": 4.0, "overshoot": true, "decay": 0.5, "opacity": 0.35, "tier": TIER_DEBRIS})
		"holy":
			match shape:
				"self":
					# A blessing: rays and feathers round the priest, a golden bloom underfoot.
					_rays(HOLY, Vector3.ZERO, 1.0, 2 + tier / 2, d, 1.6, 8.0)
					layer("bloom", true, HOLY, Vector3.UP * 0.03, Vector3.ONE * 1.8, Vector3.ZERO, d, 1.4, {"initial": 0.3, "grow": 2.5, "overshoot": true, "spin": 0.5, "decay": 0.6, "opacity": 0.7})
					_feathers(HOLY, Vector3.ZERO, 1.8, 4 + tier, d + 0.05, 3.2)
				"single":
					_pillar(HOLY, Vector3.ZERO, 0.7 + 0.08 * float(tier), d, 0.8, 7.0 + float(tier))
					if level >= 60:
						_rays(HOLY, Vector3.ZERO, 1.2, 2, d, 1.1, 9.0)
						_feathers(HOLY, Vector3.ZERO, 1.2, 3, d + 0.1, 3.0)
				"fan", "chain":
					_feathers(HOLY, Vector3.ZERO, 1.2, 2 + mini(hits, 6) / 2, d, 2.6)
				_:
					# Area judgements: pillars round the area under god rays, feathers drifting after.
					var n := count(2 + tier / 2)
					for k in n:
						var a := float(k) * 2.39996
						var spot := Vector3(sin(a), 0, cos(a)) * r * 0.55 * sqrt(float(k) / float(maxi(n, 1)))
						_pillar(HOLY, spot, 0.8 + 0.1 * float(tier), d + 0.08 * float(k), 0.8, 7.0)
					_rays(HOLY, Vector3.ZERO, r, 2, d, 1.3, 9.0)
					_feathers(HOLY, Vector3.ZERO, r * 0.8, 3 + tier, d + 0.2, 3.4)
		"bloom":
			# Summoner heals: a flower opens at the feet, pollen and light motes rise.
			_portal(BLOSSOM, Vector3.ZERO, 1.5 + 0.1 * float(tier), d, 1.6)
			_heal(HEAL, Vector3.ZERO, 1.3, 4 + tier, d + 0.08, 1.4)
			_leaf_swirl(LEAF, Vector3.ZERO, 1.2, 5, d, 1.5, 1.2)
		"leaves":
			# Buffs: leaves swirl up round the party, spirit wisps rise with them.
			_leaf_swirl(LEAF, Vector3.ZERO, 1.25, 8 + tier, d, 1.7, 1.6)
			_leaf_swirl(NATURE, Vector3.ZERO, 0.9, 3, d + 0.1, 1.4, 2.0, true)
			_wisps(SPIRIT, Vector3.ZERO, 1.0, 2 + tier / 2, d + 0.1, 1.5)
			layer("flower", true, NATURE, Vector3.UP * 0.04, Vector3.ONE * 1.4, Vector3.ZERO, d, 1.4, {"initial": 0.1, "grow": 2.2, "overshoot": true, "spin": 0.5, "decay": 0.65, "opacity": 0.6, "tier": TIER_MID})
		"pollen":
			layer("smoke", false, [Color("b8c040"), Color("f0f0a0"), Color("2a2a08")], Vector3.UP * 0.8, Vector3.ONE * r * 0.55, Vector3.ZERO, d, 1.4, {"initial": 0.3, "grow": 3.0, "travel": Vector3(0, 0.5, 0), "face_camera": true, "decay": 0.5, "opacity": 0.4})
			_sparks(POLLEN, Vector3.UP * 0.5, 9, r * 0.35, d, 2.2)
			_heal(POLLEN, Vector3.ZERO, r * 0.7, 5, d, 1.2)
		"nature":
			match shape:
				"single":
					layer("leaf", false, LEAF, body, Vector3.ONE * 0.5, Vector3.ZERO, d, 0.5, {"initial": 0.3, "grow": 6.0, "face_camera": true, "roll": 4.0, "decay": 0.5})
					_wisps(SPIRIT, Vector3.ZERO, 0.45, 2, d, 1.0)
					_sparks(LEAF, body, 4, 0.4, d, 2.0, "leaf", 0.3, false)
				"fan", "chain":
					_vines(Vector3.ZERO, 1.0, 2, d, 1.1, 1.0)
				_:
					if id in ["thorn_storm"]:
						# Thorns and leaves rain down on the area.
						for k in count(8):
							var a := float(k) * 2.39996
							var spot := Vector3(sin(a), 0, cos(a)) * r * 0.75 * sqrt(float(k + 1) / 9.0)
							layer("leaf", false, LEAF, spot + Vector3.UP * 0.3, Vector3.ONE * 0.4, Vector3(0, 0, a), 0.04 * float(k), d + 0.4, {"initial": 1.0, "drop": 4.0, "land": 0.6, "flutter": 0.8, "phase": a, "face_camera": true, "decay": 0.8, "tier": TIER_CORE if k < 3 else TIER_MID})
					_vines(Vector3.ZERO, r * 0.8, 4 + tier, d, 1.6, 1.2 + 0.1 * float(tier))
					_leaf_swirl(LEAF, Vector3.ZERO, r * 0.45, 6, d + 0.05, 1.4, 1.6)
					if level >= 60:
						_portal(NATURE, Vector3.ZERO, r * 0.45, d, 1.4)
		"portal":
			# The creature's own arrival portal comes from Summon; the caster's circle here.
			var size := 1.1 + 0.1 * float(tier)
			_portal(c, Vector3.ZERO, size, d, 1.4)
			if fam == "mage":
				_rune(c, Vector3.ZERO, size * 1.1, d, 1.2, false)
			elif fam == "summoner":
				_wisps(SPIRIT, Vector3.ZERO, 0.8, 3, d + 0.1, 1.4)
		_:
			# Arcane (mage): a rune at the spell's target / under the caster for buffs, motes.
			if shape == "self":
				_rune(c, Vector3.ZERO, 1.6 + 0.1 * float(tier), d, 1.4, true)
				_wisps(c, Vector3.ZERO, 1.0, 3 + tier / 2, d + 0.05, 1.4)
				if level >= 60:
					_rays(c, Vector3.ZERO, 0.8, 1, d, 1.3, 7.0)
			else:
				_rune(c, Vector3.ZERO, maxf(r * 0.6, 1.0), d, 0.9, false)
				_sparks(c, body, 5, 0.5, d, 2.2)


# --- star skills -------------------------------------------------------------

func _star_windup(id: String, skill: Dictionary, target: Vector3, time: float) -> void:
	var fam := family(skill)
	var r := clampf(float(skill.get("radius", 6.0)), 3.0, 10.0)
	var shape := String(skill.get("shape", ""))
	var spot := target if shape in ["blast", "single"] else Vector3.ZERO
	match fam:
		"mage":
			_rune(ARCANE, Vector3.ZERO, 1.6, 0.0, time + 0.1)
			if shape != "single":
				_rune(ARCANE if id != "crystal_prison" else ICE, spot, r * 0.85, time * 0.1, time * 0.9 + 0.2, true)
			if id == "crystal_prison":
				layer("frost", true, FROST, spot + Vector3.UP * 0.03, Vector3.ONE * r * 0.9, Vector3.ZERO, time * 0.2, time * 0.8 + 0.3, {"initial": 0.05, "grow": 1.0, "fade_in": 0.2, "decay": 0.9, "opacity": 0.7, "tier": TIER_MID})
		"priest":
			_rays(HOLY, Vector3.ZERO, 0.8, 2, 0.0, time + 0.3, 8.0)
			_feathers(HOLY, Vector3.ZERO, 1.4, 4, 0.0, 2.8)
			if spot != Vector3.ZERO:
				_rays(HOLY, spot, r * 0.6, 2, time * 0.3, time * 0.7 + 0.3, 9.0)
		"summoner":
			_leaf_swirl(LEAF, Vector3.ZERO, 1.1, 8, 0.0, time + 0.2, 1.4)
			layer("flower", true, POLLEN, Vector3.UP * 0.04, Vector3.ONE * 1.6, Vector3.ZERO, 0.0, time + 0.2, {"initial": 0.05, "grow": 1.2, "spin": 0.8, "fade_in": 0.2, "decay": 0.85, "opacity": 0.6})
			if id in ["leviathan_surge", "eclipse_sovereign"]:
				_vortex(WATER, Vector3.ZERO, 1.2, 3.0, time * 0.3, time * 0.7 + 0.2, "mote")
			elif id in ["moonwolf_pact", "celestial_dragon_emperor"]:
				_vortex(WIND, Vector3.ZERO, 1.2, 3.0, time * 0.3, time * 0.7 + 0.2, "leaf")


## One contact beat of a star skill (root at the beat point, or the caster for self /
## summon; [param caster] in root space).
func _star_beat(id: String, skill: Dictionary, index: int, r: float, caster: Vector3) -> void:
	var god := StarSkillData.is_god(skill)
	var last := index >= 4 if god else false
	match id:
		"arcane_prism":
			# Four elements in turn on the one foe: fire, ice, lightning, arcane.
			_mark(["fire", "ice", "thunder", "arcane"][index % 4], [FIRE, ICE, THUNDER, ARCANE][index % 4])
			if index % 4 == 2:
				_bolt(THUNDER, Vector3.ZERO, 7.0, 0.0, 1.4)
			elif index % 4 == 0:
				_flames(Vector3.ZERO, 0.8, 3, 0.0, 0.9, 1.2)
			elif index % 4 == 1:
				_ice(ICE, Vector3.ZERO, 1.0, 4, 0.0, 1.0, 1.0)
		"crystal_prison":
			if index == 0:
				_ice(ICE, Vector3.ZERO, r * 0.8, 9, 0.0, 1.8, 1.8)
			else:
				# The prison shatters: chips fly, the frost lingers a moment.
				_sparks(ICE, Vector3.UP * 0.8, 10, r * 0.25, 0.0, 3.4, "crystal", 0.35, false)
				layer("frost", true, FROST, Vector3.UP * 0.03, Vector3.ONE * r, Vector3.ZERO, 0.0, 1.2, {"initial": 1.0, "decay": 0.4, "opacity": 0.6})
				layer("bloom", true, ICE, Vector3.UP * 0.05, Vector3.ONE * r * 0.9, Vector3.ZERO, 0.0, 0.6, {"initial": 0.3, "grow": 6.0, "decay": 0.4, "opacity": 0.7})
		"astral_convergence":
			_rune(ARCANE, Vector3.ZERO, r * (0.9 - 0.15 * float(index)), 0.0, 0.9, false)
			_wisps(ARCANE, Vector3.ZERO, r * 0.4, 4, 0.0, 1.0)
			if index >= 2:
				_crater(Vector3.ZERO, r * 0.4, 0.0, 2.0)
		"genesis_nova":
			var els := [FIRE, ICE, THUNDER, ARCANE]
			var c: Array = els[index % 4]
			_rune(c, Vector3.ZERO, r * 0.85, 0.0, 1.0, false)
			match index % 4:
				0: _flames(Vector3.ZERO, r * 0.7, 6, 0.0, 1.0, 1.6, true)
				1: _ice(ICE, Vector3.ZERO, r * 0.7, 6, 0.0, 1.4, 1.2)
				2:
					for k in count(3):
						var a := float(k) * TAU / 3.0
						_bolt(THUNDER, Vector3(sin(a), 0, cos(a)) * r * 0.45, 8.0, 0.05 * float(k), 1.5)
				_:
					_crater(Vector3.ZERO, r * 0.5, 0.0, 2.6)
					_wisps(ARCANE, Vector3.ZERO, r * 0.4, 4, 0.0, 1.2)
		"astral_apocalypse":
			# God tier: meteors land in waves, each leaving a crater that glows and cools.
			var spot := Vector3(sin(float(index) * 2.4), 0, cos(float(index) * 2.4)) * r * 0.35 * float(index % 4) / 3.0
			_crater(spot, r * (0.35 if not last else 0.6), 0.0, 2.6)
			_flames(spot, r * 0.3, 4, 0.0, 1.0, 1.4, true)
			if index == 0 or last:
				_rune(ARCANE, Vector3.ZERO, r * 0.95, 0.0, 1.3, true)
		"sanctified_chain":
			_pillar(HOLY, Vector3.ZERO, 0.7, 0.0, 0.7, 7.0)
			_heal(HEAL, caster, 1.2, 3, 0.0, 1.0)
		"seraph_aegis":
			_dome(HOLY, Vector3.ZERO, 2.6, 0.0, 2.0)
			_feathers(HOLY, Vector3.ZERO, 2.0, 7, 0.05, 3.6)
			_rays(HOLY, Vector3.ZERO, 1.2, 2, 0.0, 1.6, 9.0)
		"sacred_sanctuary":
			_heal(HEAL, Vector3.ZERO, r * 0.7, 5, 0.0, 1.4)
			if index == 0:
				_rays(HOLY, Vector3.ZERO, r, 3, 0.0, 2.0, 9.0)
				_feathers(HOLY, Vector3.ZERO, r * 0.6, 6, 0.1, 3.4)
		"dawn_salvation":
			_rays(HOLY, Vector3.ZERO, r, 3 + index, 0.0, 1.5, 10.0)
			_feathers(HOLY, Vector3.ZERO, r * 0.7, 5, 0.1, 3.6)
			_heal(HEAL, caster, 1.4, 4, 0.0, 1.2)
		"seraphic_judgment":
			# God tier: pillars of judgement walk the field, the finale under a ring of rays.
			var n := 1 if not last else 4
			for k in count(n):
				var a := float(index * 3 + k) * 2.39996
				_pillar(HOLY, Vector3(sin(a), 0, cos(a)) * r * (0.45 if n > 1 else 0.3 * float(index % 3)), 1.0 + 0.4 * float(last), 0.06 * float(k), 0.9, 9.0)
			_feathers(HOLY, Vector3.ZERO, r * 0.7, 3 + 3 * int(last), 0.1, 3.8)
			if index == 0 or last:
				_rays(HOLY, Vector3.ZERO, r, 3, 0.0, 1.8, 10.0)
		"moonwolf_pact", "eclipse_sovereign":
			# The legend's grand entrance (its own arrival adds the portal under the creature).
			if index == 0:
				var water := id == "eclipse_sovereign"
				_vortex(WATER if water else WIND, Vector3.ZERO, 2.2, 6.0, 0.0, 1.8, "mote" if water else "leaf")
				_portal(WATER if water else NATURE, Vector3.ZERO, 2.4, 0.05, 1.8)
		"leviathan_surge":
			_vortex(WATER, Vector3.ZERO, r * 0.3, 3.5, 0.0, 1.0, "mote")
			_sparks(WATER, Vector3.UP * 0.3, 8, r * 0.3, 0.0, 3.0)
		"spirit_court":
			_portal(NATURE, Vector3.ZERO, 2.4, 0.0, 1.8)
			_leaf_swirl(LEAF, Vector3.ZERO, 1.8, 12, 0.0, 2.0, 2.0)
			_wisps(SPIRIT, Vector3.ZERO, 1.4, 5, 0.1, 1.8)
		"celestial_dragon_emperor":
			# God tier: the dragon's wind sweeps the field; the finale is a towering vortex.
			_vortex(WIND, Vector3.ZERO, r * (0.25 if not last else 0.45), 4.0 + 3.0 * float(last), 0.0, 1.3, "leaf")
			_wisps(SPIRIT, Vector3.ZERO, r * 0.35, 3, 0.0, 1.2)
			if last:
				_portal(NATURE, Vector3.ZERO, r * 0.5, 0.0, 1.6)


# ---------------------------------------------------------------------------
# Geometry. Vertex colour: r = core heat (accent), g = opacity mask (SculptureArt).
# Flat pieces lie in XY facing +Z, ground pieces in XZ, upright pieces stand on y = 0.
# ---------------------------------------------------------------------------

static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"rune_circle": _rune_circle(st)
		"rune_ring": _rune_ring(st)
		"flame": _flame(st)
		"smoke": _puff(st)
		"haze": _band(st, 1.0, 0.0, 1.0, _c(0.15, 0.45), _c(0.0, 0.0), 24)
		"crystal": _crystal(st)
		"frost": _frost(st)
		"bolt0", "bolt1", "bolt2": _bolt_mesh(st, int(kind.substr(4)))
		"crater": _crater_mesh(st)
		"scorch": _scorch(st)
		"ray": _ray(st)
		"feather": _feather(st)
		"mote": _mote(st)
		"bloom": _bloom(st)
		"dome": _dome_mesh(st)
		"pillar": _pillar_mesh(st)
		"dust": _dust(st)
		"flower": _flower(st)
		"leaf": _leaf(st)
		"vine": _vine(st)
		"wisp": _wisp(st)
		"funnel": _funnel(st)
		"glass": _glass(st)
		_: _mote(st)
	var result := st.commit()
	_meshes[kind] = result
	return result


static func _c(core: float, mask: float) -> Color:
	return Color(core, mask, 0.0, 1.0)


## A triangle fan from [param centre] to a closed outline.
static func _fan(st: SurfaceTool, centre: Vector3, outline: Array, mid: Color, edge: Color) -> void:
	var n := outline.size()
	for i in n:
		_tri(st, centre, outline[i], outline[(i + 1) % n], mid, edge, edge)


## A fan with a solid body: centre → a ring at [param body] of the way out → the outline.
static func _fan2(st: SurfaceTool, centre: Vector3, outline: Array, body: float, c_centre: Color, c_body: Color, c_edge: Color) -> void:
	var n := outline.size()
	for i in n:
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % n]
		var ma := centre.lerp(a, body)
		var mb := centre.lerp(b, body)
		_tri(st, centre, ma, mb, c_centre, c_body, c_body)
		_quad(st, ma, a, b, mb, c_body, c_edge, c_edge, c_body)


## An annulus in the XZ plane at height y.
static func _ring(st: SurfaceTool, inner: float, outer: float, y: float, c_in: Color, c_out: Color, seg := 48) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(sin(a0), 0, cos(a0))
		var d1 := Vector3(sin(a1), 0, cos(a1))
		_quad(st, d0 * inner + Vector3.UP * y, d0 * outer + Vector3.UP * y, d1 * outer + Vector3.UP * y, d1 * inner + Vector3.UP * y, c_in, c_out, c_out, c_in)


## An open upright band of radius r from y0 to y1.
static func _band(st: SurfaceTool, r: float, y0: float, y1: float, c0: Color, c1: Color, seg := 32) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var d0 := Vector3(sin(a0), 0, cos(a0)) * r
		var d1 := Vector3(sin(a1), 0, cos(a1)) * r
		_quad(st, d0 + Vector3.UP * y0, d1 + Vector3.UP * y0, d1 + Vector3.UP * y1, d0 + Vector3.UP * y1, c0, c0, c1, c1)


static func _rune_circle(st: SurfaceTool) -> void:
	# Two rings with a soft glow between them, glyph ticks and diamonds round the band.
	_ring(st, 0.9, 0.95, 0.0, _c(0.1, 0.0), _c(0.5, 1.0), 64)
	_ring(st, 0.95, 1.0, 0.0, _c(0.5, 1.0), _c(0.05, 0.0), 64)
	_ring(st, 0.7, 0.73, 0.0, _c(0.35, 0.9), _c(0.35, 0.9), 64)
	_ring(st, 0.73, 0.9, 0.0, _c(0.0, 0.14), _c(0.0, 0.14), 64)
	for k in 16:
		var a := TAU * float(k) / 16.0
		var d := Vector3(sin(a), 0.002, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		if k % 2 == 0:
			# A diamond glyph.
			var m := d * 0.815
			_quad(st, m - d * 0.06, m + side * 0.035, m + d * 0.06, m - side * 0.035, _c(0.6, 1.0), _c(0.3, 0.9), _c(0.6, 1.0), _c(0.3, 0.9))
		else:
			# A rune stroke: a bar with a crossing tick.
			_strip(st, d * 0.75, d * 0.88, 0.02, Vector3.UP, _c(0.45, 0.95), _c(0.45, 0.95))
			_strip(st, d * 0.8 - side * 0.035, d * 0.84 + side * 0.035, 0.016, Vector3.UP, _c(0.45, 0.9), _c(0.45, 0.9))


static func _rune_ring(st: SurfaceTool) -> void:
	# A hexagram inside a thin ring, with a hot centre seal.
	_ring(st, 0.95, 1.0, 0.0, _c(0.4, 0.9), _c(0.4, 0.9), 48)
	for tri in 2:
		for k in 3:
			var a0 := TAU * float(k) / 3.0 + PI * float(tri)
			var a1 := TAU * float(k + 1) / 3.0 + PI * float(tri)
			_strip(st, Vector3(sin(a0), 0.003, cos(a0)) * 0.96, Vector3(sin(a1), 0.003, cos(a1)) * 0.96, 0.035, Vector3.UP, _c(0.5, 1.0), _c(0.5, 1.0))
	_ring(st, 0.0, 0.22, 0.004, _c(0.7, 0.5), _c(0.2, 0.0), 24)


static func _flame(st: SurfaceTool) -> void:
	# A licking tongue: wide low, leaning in an S to a sharp tip; a hot inner core.
	var outline: Array = []
	var n := 14
	for i in n + 1:
		var y := float(i) / float(n)
		outline.append(Vector3(0.3 * sin(PI * pow(y, 0.62)) * (1.0 - 0.3 * y) + 0.07 * sin(y * PI * 1.6), y, 0))
	for i in range(n - 1, 0, -1):
		var y := float(i) / float(n)
		outline.append(Vector3(-0.28 * sin(PI * pow(y, 0.62)) * (1.0 - 0.3 * y) + 0.07 * sin(y * PI * 1.6), y, 0))
	_fan2(st, Vector3(0.02, 0.26, 0), outline, 0.62, _c(1.0, 1.0), _c(0.5, 1.0), _c(0.0, 0.25))


static func _puff(st: SurfaceTool) -> void:
	# A lumpy soft puff (smoke, pollen haze).
	var outline: Array = []
	for i in 18:
		var a := TAU * float(i) / 18.0
		var r := 0.5 * (1.0 + 0.16 * sin(3.0 * a + 0.4) + 0.09 * sin(5.0 * a + 1.3))
		outline.append(Vector3(cos(a) * r, sin(a) * r, 0))
	_fan2(st, Vector3.ZERO, outline, 0.6, _c(0.0, 0.9), _c(0.0, 0.7), _c(0.0, 0.0))
	var inner: Array = []
	for p in outline:
		inner.append((p as Vector3) * 0.55 + Vector3(-0.08, 0.1, 0.005))
	_fan(st, Vector3(-0.08, 0.1, 0.005), inner, _c(0.12, 0.5), _c(0.0, 0.0))


static func _crystal(st: SurfaceTool) -> void:
	# A hexagonal ice prism with a pointed tip; the edges and tip carry the light.
	var r := 0.16
	var shaft := 0.68
	for k in 6:
		var a0 := TAU * float(k) / 6.0
		var a1 := TAU * float(k + 1) / 6.0
		var p0 := Vector3(sin(a0), 0, cos(a0)) * r
		var p1 := Vector3(sin(a1), 0, cos(a1)) * r
		var edge := _c(0.55 if k % 2 == 0 else 0.25, 1.0)
		_quad(st, p0, p1, p1 + Vector3.UP * shaft, p0 + Vector3.UP * shaft, _c(0.05, 0.9), _c(0.05, 0.9), edge, _c(0.4, 1.0))
		_tri(st, p0 + Vector3.UP * shaft, p1 + Vector3.UP * shaft, Vector3.UP, _c(0.5, 1.0), _c(0.35, 1.0), _c(1.0, 1.0))


static func _frost(st: SurfaceTool) -> void:
	# Six fern-like frost arms with side branches over a faint patch.
	var patch: Array = []
	for i in 20:
		var a := TAU * float(i) / 20.0
		var r := 0.7 * (1.0 + 0.2 * sin(4.0 * a + 0.7))
		patch.append(Vector3(sin(a) * r, 0, cos(a) * r))
	_fan(st, Vector3.ZERO, patch, _c(0.35, 0.4), _c(0.0, 0.0))
	for arm in 6:
		var a := TAU * float(arm) / 6.0 + 0.2 * sin(float(arm) * 2.1)
		var d := Vector3(sin(a), 0.004, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		_strip(st, d * 0.05, d * 1.0, 0.05, Vector3.UP, _c(0.95, 1.0), _c(0.3, 0.2), 0.008)
		for b in 4:
			var at := 0.25 + 0.18 * float(b)
			var length := 0.3 * (1.0 - at * 0.7)
			for s: float in [-1.0, 1.0]:
				var tip := d * (at + length * 0.7) + side * s * length
				_strip(st, d * at, tip, 0.03, Vector3.UP, _c(0.8, 0.9), _c(0.2, 0.15), 0.006)


static func _bolt_mesh(st: SurfaceTool, variant: int) -> void:
	# A forked channel from the sky (y 1) to the ground (y 0): a thin white-hot core
	# inside a wider soft halo, and two smaller forks peeling off.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7103 + variant * 911
	var pts: Array = []
	var x := 0.0
	var n := 10
	for i in n + 1:
		var y := 1.0 - float(i) / float(n)
		pts.append(Vector3(x, y, 0))
		x = clampf(x * 0.55 + rng.randf_range(-0.16, 0.16), -0.3, 0.3)
	pts[n] = Vector3(0, 0, 0)
	_channel(st, pts, 0.035, 0.18)
	for fork in 2:
		var from := 2 + fork * 3 + rng.randi() % 2
		var p: Vector3 = pts[from]
		var branch: Array = [p]
		var dir := -1.0 if rng.randf() < 0.5 else 1.0
		for j in 3:
			p += Vector3(dir * rng.randf_range(0.06, 0.13), -rng.randf_range(0.06, 0.1), 0)
			branch.append(p)
		_channel(st, branch, 0.018, 0.09)


static func _channel(st: SurfaceTool, pts: Array, core: float, halo: float) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var side := Vector3(b.y - a.y, a.x - b.x, 0).normalized() * -1.0
		# The halo: transparent at its edges, soft in the middle.
		_quad(st, a - side * halo, b - side * halo, b, a, _c(0.0, 0.0), _c(0.0, 0.0), _c(0.3, 0.45), _c(0.3, 0.45))
		_quad(st, a, b, b + side * halo, a + side * halo, _c(0.3, 0.45), _c(0.3, 0.45), _c(0.0, 0.0), _c(0.0, 0.0))
		_quad(st, a - side * core, b - side * core, b + side * core, a + side * core, _c(1.0, 1.0), _c(1.0, 1.0), _c(1.0, 1.0), _c(1.0, 1.0))


static func _crater_mesh(st: SurfaceTool) -> void:
	# A molten centre, jagged radial cracks and a glowing lip.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	_ring(st, 0.0, 0.32, 0.0, _c(1.0, 0.95), _c(0.4, 0.0), 24)
	for k in 11:
		var a := TAU * float(k) / 11.0 + rng.randf_range(-0.15, 0.15)
		var p := Vector3(sin(a), 0.003, cos(a)) * 0.18
		var length := rng.randf_range(0.65, 1.0)
		for j in 4:
			var b := p + Vector3(sin(a + rng.randf_range(-0.5, 0.5)), 0, cos(a + rng.randf_range(-0.5, 0.5))) * length * 0.22
			b.y = 0.003
			_strip(st, p, b, 0.06 * (1.0 - 0.2 * float(j)), Vector3.UP, _c(0.95 - 0.2 * float(j), 1.0), _c(0.75 - 0.2 * float(j), 0.8), 0.05 * (1.0 - 0.2 * float(j + 1)))
			p = b
	_ring(st, 0.82, 0.9, 0.002, _c(0.2, 0.0), _c(0.5, 0.7), 40)
	_ring(st, 0.9, 1.0, 0.002, _c(0.5, 0.7), _c(0.1, 0.0), 40)


static func _scorch(st: SurfaceTool) -> void:
	var outline: Array = []
	for i in 22:
		var a := TAU * float(i) / 22.0
		var r := 1.0 + 0.14 * sin(5.0 * a + 0.3) + 0.08 * sin(9.0 * a)
		outline.append(Vector3(sin(a) * r, 0, cos(a) * r))
	_fan(st, Vector3.ZERO, outline, _c(0.08, 0.95), _c(0.0, 0.0))


static func _ray(st: SurfaceTool) -> void:
	# Two crossed tapered planes, widest at the ground, soft at both ends and edges.
	for plane in 2:
		var side := Vector3(1, 0, 0) if plane == 0 else Vector3(0, 0, 1)
		var rows := [[0.0, 0.5, 0.0], [0.12, 0.47, 0.55], [0.5, 0.36, 0.5], [0.85, 0.24, 0.22], [1.0, 0.2, 0.0]]
		for i in rows.size() - 1:
			var r0: Array = rows[i]
			var r1: Array = rows[i + 1]
			var y0 := float(r0[0])
			var y1 := float(r1[0])
			var c0 := _c(0.6, float(r0[2]))
			var c1 := _c(0.6, float(r1[2]))
			var m0 := _c(0.3, float(r0[2]) * 0.75)
			var m1 := _c(0.3, float(r1[2]) * 0.75)
			var e := _c(0.0, 0.0)
			for s: float in [-1.0, 1.0]:
				var w0 := side * s * float(r0[1])
				var w1 := side * s * float(r1[1])
				var y0v := Vector3.UP * y0
				var y1v := Vector3.UP * y1
				_quad(st, y0v, y0v + w0 * 0.6, y1v + w1 * 0.6, y1v, c0, m0, m1, c1)
				_quad(st, y0v + w0 * 0.6, y0v + w0, y1v + w1, y1v + w1 * 0.6, m0, e, e, m1)


static func _feather(st: SurfaceTool) -> void:
	var left: Array = []
	var right: Array = []
	for i in 9:
		var y := 0.1 + 0.9 * float(i) / 8.0
		var w := sin(PI * pow((y - 0.1) / 0.9, 0.75))
		right.append(Vector3(0.17 * w + 0.03 * y, y, 0))
		left.append(Vector3(-0.13 * w + 0.03 * y, y, 0))
	var outline: Array = [Vector3(0.0, 0.1, 0)]
	outline.append_array(right)
	left.reverse()
	outline.append_array(left)
	_fan2(st, Vector3(0.02, 0.5, 0), outline, 0.7, _c(0.6, 1.0), _c(0.35, 0.85), _c(0.1, 0.3))
	_strip(st, Vector3(0, 0, 0.005), Vector3(0.04, 1.0, 0.005), 0.025, Vector3.BACK, _c(0.9, 1.0), _c(0.7, 0.8), 0.01)


static func _mote(st: SurfaceTool) -> void:
	# A four-point sparkle over a soft glow.
	var halo: Array = []
	for i in 12:
		var a := TAU * float(i) / 12.0
		halo.append(Vector3(cos(a), sin(a), 0) * 0.32)
	_fan2(st, Vector3.ZERO, halo, 0.5, _c(0.6, 0.7), _c(0.3, 0.4), _c(0.0, 0.0))
	var star: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		var r := 0.5 if i % 2 == 0 else 0.1
		star.append(Vector3(cos(a), sin(a), 0.004) * r)
	_fan(st, Vector3(0, 0, 0.004), star, _c(1.0, 1.0), _c(0.3, 0.0))


static func _bloom(st: SurfaceTool) -> void:
	# A soft ring of light with scalloped petals round its bright band.
	_ring(st, 0.5, 0.82, 0.0, _c(0.0, 0.0), _c(0.8, 0.9), 56)
	_ring(st, 0.82, 1.0, 0.0, _c(0.8, 0.9), _c(0.0, 0.0), 56)
	for k in 12:
		var a := TAU * float(k) / 12.0
		var d := Vector3(sin(a), 0.003, cos(a))
		var side := Vector3(cos(a), 0, -sin(a))
		_fan(st, d * 0.72, [d * 0.6, d * 0.7 + side * 0.08, d * 0.86, d * 0.7 - side * 0.08], _c(0.7, 0.7), _c(0.2, 0.0))


static func _dome_mesh(st: SurfaceTool) -> void:
	# A glass dome: a faint body, brighter towards its rim (a fresnel of sorts), a lattice
	# of light along meridians and parallels, a bright foot.
	var rings := 8
	var seg := 28
	for r in rings:
		for s in seg:
			var pts: Array = []
			for k in [[r, s], [r + 1, s], [r + 1, s + 1], [r, s + 1]]:
				var phi := PI * 0.5 * float(k[0]) / float(rings)
				var th := TAU * float(k[1]) / float(seg)
				var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				pts.append(d)
			var cols: Array = []
			for p in pts:
				var e := 1.0 - (p as Vector3).y
				cols.append(_c(0.15 + 0.25 * e * e, 0.08 + 0.42 * e * e))
			_quad(st, pts[0], pts[1], pts[2], pts[3], cols[0], cols[1], cols[2], cols[3])
	for m in 8:
		var th := TAU * float(m) / 8.0
		var arc: Array = []
		for i in 9:
			var phi := PI * 0.5 * float(i) / 8.0
			arc.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * 1.006)
		for i in 8:
			var a: Vector3 = arc[i]
			var b: Vector3 = arc[i + 1]
			_strip(st, a, b, 0.025, a.normalized(), _c(0.7, 0.7), _c(0.7, 0.7))
	for level in [0.35, 0.7]:
		var y := sin(PI * 0.5 * level)
		_band(st, cos(PI * 0.5 * level) * 1.006, y - 0.012, y + 0.012, _c(0.7, 0.65), _c(0.7, 0.65), seg)
	_band(st, 1.006, 0.0, 0.08, _c(1.0, 1.0), _c(0.5, 0.0), seg)


static func _pillar_mesh(st: SurfaceTool) -> void:
	# A soft outer column and a hot inner core, both fading towards the sky.
	_band(st, 1.0, 0.0, 0.06, _c(0.3, 0.0), _c(0.3, 0.5), 28)
	_band(st, 1.0, 0.06, 1.0, _c(0.3, 0.5), _c(0.1, 0.0), 28)
	_band(st, 0.36, 0.0, 0.05, _c(0.75, 0.2), _c(0.75, 0.8), 20)
	_band(st, 0.36, 0.05, 1.0, _c(0.75, 0.8), _c(0.4, 0.0), 20)


static func _dust(st: SurfaceTool) -> void:
	# A halo of dust puffs rolling round the foot of something (ink).
	for k in 11:
		var a := TAU * float(k) / 11.0 + 0.3 * sin(float(k) * 1.7)
		var r := 0.85 + 0.15 * sin(float(k) * 2.3)
		var size := 0.3 + 0.08 * sin(float(k) * 3.1)
		_sphere(st, Vector3(sin(a), size * 0.6, cos(a)) * Vector3(r, 1, r), Vector3(size * 1.3, size, size * 1.3), _c(0.0, 0.65), 5, 9)


static func _flower(st: SurfaceTool) -> void:
	# Eight cupped petals with eight smaller ones between them, a hot centre.
	for layer_i in 2:
		var petals := 8
		var length := 1.0 if layer_i == 0 else 0.62
		var width := 0.3 if layer_i == 0 else 0.22
		var turn := 0.0 if layer_i == 0 else PI / 8.0
		for k in petals:
			var a := TAU * float(k) / float(petals) + turn
			var d := Vector3(sin(a), 0, cos(a))
			var side := Vector3(cos(a), 0, -sin(a))
			var outline: Array = []
			for i in 7:
				var t := float(i) / 6.0
				var r := lerpf(0.1, length, t)
				outline.append(d * r + side * width * sin(PI * pow(t, 0.8)) + Vector3.UP * (0.28 * t * t * length + 0.01 * float(layer_i)))
			for i in range(5, 0, -1):
				var t := float(i) / 6.0
				var r := lerpf(0.1, length, t)
				outline.append(d * r - side * width * sin(PI * pow(t, 0.8)) + Vector3.UP * (0.28 * t * t * length + 0.01 * float(layer_i)))
			var mid := d * lerpf(0.1, length, 0.4) + Vector3.UP * (0.05 * length + 0.01 * float(layer_i))
			_fan(st, mid, outline, _c(0.55 + 0.25 * float(layer_i), 0.95), _c(0.15, 0.4))
	_ring(st, 0.0, 0.16, 0.03, _c(1.0, 1.0), _c(0.6, 0.6), 16)


static func _leaf(st: SurfaceTool) -> void:
	var outline: Array = []
	for i in 9:
		var y := float(i) / 8.0
		outline.append(Vector3(0.2 * sin(PI * pow(y, 0.85)) + 0.04 * sin(y * PI), y, 0))
	for i in range(7, 0, -1):
		var y := float(i) / 8.0
		outline.append(Vector3(-0.18 * sin(PI * pow(y, 0.85)) + 0.04 * sin(y * PI), y, 0))
	_fan2(st, Vector3(0.02, 0.45, 0), outline, 0.7, _c(0.35, 1.0), _c(0.2, 1.0), _c(0.05, 0.85))
	_strip(st, Vector3(0, 0, 0.005), Vector3(0.04, 0.95, 0.005), 0.025, Vector3.BACK, _c(0.85, 1.0), _c(0.5, 0.9), 0.008)


static func _vine(st: SurfaceTool) -> void:
	# A tapering stem that rises and curls over at the top into a tendril, with leaves.
	var pts: Array = []
	var radii: Array = []
	var cols: Array = []
	var n := 18
	for i in n + 1:
		var t := float(i) / float(n)
		var curl := t * TAU * 1.15
		var rad := 0.08 + 0.22 * t * t
		pts.append(Vector3(sin(curl) * rad + 0.25 * t, t * 0.95 + 0.06 * sin(t * PI), cos(curl) * rad - 0.08))
		radii.append(lerpf(0.06, 0.012, t))
		cols.append(_c(lerpf(0.05, 0.7, t * t), 1.0))
	_tube(st, pts, radii, cols, 6)
	for k in 3:
		var p: Vector3 = pts[4 + k * 4]
		var dir := 1.0 if k % 2 == 0 else -1.0
		var tip := p + Vector3(0.22 * dir, 0.1, 0.06)
		var side := Vector3(0, 0.07, 0)
		_fan(st, (p + tip) * 0.5, [p, (p + tip) * 0.5 + side, tip, (p + tip) * 0.5 - side], _c(0.4, 1.0), _c(0.1, 0.9))


static func _wisp(st: SurfaceTool) -> void:
	# A soft round head and a tail lagging below it in a gentle S.
	var head: Array = []
	for i in 14:
		var a := TAU * float(i) / 14.0
		head.append(Vector3(cos(a) * 0.17, 0.8 + sin(a) * 0.17, 0.004))
	_fan(st, Vector3(0, 0.8, 0.004), head, _c(1.0, 1.0), _c(0.4, 0.0))
	var halo: Array = []
	for i in 14:
		var a := TAU * float(i) / 14.0
		halo.append(Vector3(cos(a) * 0.32, 0.8 + sin(a) * 0.32, 0))
	_fan(st, Vector3(0, 0.8, 0), halo, _c(0.5, 0.45), _c(0.0, 0.0))
	var prev_l := Vector3(-0.15, 0.78, 0)
	var prev_r := Vector3(0.15, 0.78, 0)
	for i in 6:
		var t := float(i + 1) / 6.0
		var x := 0.08 * sin(t * PI * 1.5)
		var w := 0.15 * (1.0 - t)
		var y := 0.78 - 0.78 * t
		var l := Vector3(x - w, y, 0)
		var r := Vector3(x + w, y, 0)
		var c0 := _c(0.6 * (1.0 - t + 1.0 / 6.0), 0.75 * (1.0 - t + 1.0 / 6.0))
		var c1 := _c(0.6 * (1.0 - t), 0.75 * (1.0 - t))
		_quad(st, prev_l, prev_r, r, l, c0, c0, c1, c1)
		prev_l = l
		prev_r = r


static func _funnel(st: SurfaceTool) -> void:
	# Four ribbons spiralling up and out (a wind or water vortex).
	for ribbon in 4:
		var base := TAU * float(ribbon) / 4.0
		var n := 16
		for i in n:
			var t0 := float(i) / float(n)
			var t1 := float(i + 1) / float(n)
			var a0 := base + t0 * TAU * 1.4
			var a1 := base + t1 * TAU * 1.4
			var r0 := lerpf(0.25, 1.0, t0)
			var r1 := lerpf(0.25, 1.0, t1)
			var h0 := 0.05 + 0.12 * t0
			var h1 := 0.05 + 0.12 * t1
			var p0 := Vector3(sin(a0) * r0, t0, cos(a0) * r0)
			var p1 := Vector3(sin(a1) * r1, t1, cos(a1) * r1)
			var m0 := 0.85 * sin(PI * t0)
			var m1 := 0.85 * sin(PI * t1)
			_quad(st, p0, p1, p1 + Vector3.UP * h1, p0 + Vector3.UP * h0, _c(0.6, m0), _c(0.6, m1), _c(0.15, m1 * 0.2), _c(0.15, m0 * 0.2))
			_quad(st, p0 - Vector3.UP * h0 * 0.5, p1 - Vector3.UP * h1 * 0.5, p1, p0, _c(0.15, 0.0), _c(0.15, 0.0), _c(0.6, m1), _c(0.6, m0))


static func _glass(st: SurfaceTool) -> void:
	# Cracked glass of sound: angular shards round a broken centre, bright edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var n := 9
	for k in n:
		var a0 := TAU * float(k) / float(n) + rng.randf_range(0.04, 0.1)
		var a1 := TAU * float(k + 1) / float(n) - rng.randf_range(0.04, 0.1)
		var r0 := rng.randf_range(0.12, 0.22)
		var r1 := rng.randf_range(0.75, 1.0)
		var r2 := rng.randf_range(0.6, 0.95)
		var p0 := Vector3(cos(a0), sin(a0), 0) * r0
		var p1 := Vector3(cos(a0), sin(a0), 0) * r1
		var p2 := Vector3(cos(a1), sin(a1), 0) * r2
		var p3 := Vector3(cos(a1), sin(a1), 0) * r0 * 1.1
		var mid := (p0 + p1 + p2 + p3) * 0.25 + Vector3(0, 0, 0.002)
		_fan(st, mid, [p0, p1, p2, p3], _c(0.15, 0.3), _c(0.95, 0.95))
