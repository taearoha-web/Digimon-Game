class_name SkillLayers
extends RefCounted
## The shared layer stack every active skill wears on top of its own art (the
## class art files keep their silhouettes; this adds depth around them):
##   1 anticipation  motes and runes spiral into the hand, light rises at the feet
##                   and a ring of light gathers in, over the existing wind-up
##   2 core          the skill's own shape (SpellSpectacle / class art), drawn by
##                   spectacle_body with a white-hot core, a darker rim, soft edges
##                   and a slight overshoot
##   3 secondary     element particles with gravity, drag and random lifetimes,
##                   trailing wisps, an eased shockwave ring that thins as it fades
##   4 environment   dust and debris kicked off the ground, a brief light that lights
##                   the ground and the fighters, heat haze (high quality only)
##   5 afterglow     smoke or mist that drifts and dissolves, lingering embers,
##                   motes or petals (the ground mark comes from SkillFeel)
## The flavour follows the recipe palette (SkillArtDirection): flame embers and
## smoke, frost shards, snow and mist, storm arcs, grove leaves, bloom petals, tide
## droplets and foam rings, shadow wisps, grace light shafts and motes, earth chips
## and dust, music notes and sound rings. The geometry follows the silhouette family.
##
## Cosmetic only: it never schedules damage, never changes timing and never waits
## the release. Every node comes from SkillLayerPool (fixed size, budget-aware).
## Low quality keeps core + anticipation; memory pressure 1 drops 4-5 and halves
## the particles; pressure 2 keeps only the core and one secondary emitter.

const LAYERS: Array[String] = ["anticipation", "core", "secondary", "environment", "afterglow"]
const CARD_GLOW := preload("res://shaders/skill_layer_glow.gdshader")
const CARD_SMOKE := preload("res://shaders/skill_layer_smoke.gdshader")

## Recipe silhouette -> how the layers are laid out.
const FAMILIES := {
	"quake": "ground", "meteor": "ground", "rain": "ground", "ice": "ground", "vines": "ground",
	"ember": "burst", "roar": "burst",
	"cut": "slash", "sweep": "slash", "crosscut": "slash",
	"gale": "swirl", "tide": "swirl",
	"bolt": "strike", "sun": "strike",
	"arrow": "shot", "lance": "shot",
	"guard": "aura", "crown": "aura", "wings": "aura", "bloom": "aura", "sigil": "aura", "summon": "aura",
}
## Recipe palette -> element flavour.
const PALETTE_ELEMENT := {
	"flame": "flame", "copper": "spark", "gold": "light", "grace": "light", "royal": "light",
	"gale": "wind", "frost": "frost", "tide": "tide", "arcane": "arcane", "storm": "storm",
	"steel": "steel", "bloom": "petal", "fairy": "petal", "grove": "leaf", "earth": "earth",
	"shadow": "shadow", "darkforce": "shadow", "nightblood": "shadow", "venom": "shadow",
	"melody": "music", "dissonance": "music", "lament": "music",
}
## Element -> the particle kinds of each layer (secondary: main, trailing).
const ELEMENTS := {
	"flame": {"gather": "ember", "secondary": ["fire", "ember"], "extra": "spark", "after": ["smoke", "ember"], "haze": true},
	"frost": {"gather": "mote", "secondary": ["shard", "snow"], "extra": "mist", "after": ["mist", "snow"]},
	"storm": {"gather": "arc", "secondary": ["arc", "spark"], "extra": "mote", "after": ["mote", "arc"]},
	"steel": {"gather": "spark", "secondary": ["spark", "arc"], "after": ["mist", "spark"]},
	"spark": {"gather": "ember", "secondary": ["spark", "ember"], "after": ["dust", "ember"]},
	"wind": {"gather": "mote", "secondary": ["wisp", "leaf"], "after": ["mist", "leaf"]},
	"leaf": {"gather": "mote", "secondary": ["leaf", "mote"], "after": ["leaf", "mote"]},
	"petal": {"gather": "mote", "secondary": ["petal", "mote"], "after": ["mote", "petal"]},
	"tide": {"gather": "droplet", "secondary": ["droplet", "mist"], "after": ["mist", "droplet"], "ripples": 1.0},
	"shadow": {"gather": "wisp", "secondary": ["wisp", "spark"], "extra": "ember", "after": ["smoke", "spark"]},
	"light": {"gather": "mote", "secondary": ["ray", "mote"], "extra": "spark", "after": ["mote", "ray"]},
	"arcane": {"gather": "mote", "secondary": ["mote", "spark"], "after": ["mote", "spark"]},
	"earth": {"gather": "mote", "secondary": ["debris", "dust"], "after": ["dust", "debris"]},
	"music": {"gather": "note", "secondary": ["note", "mote"], "after": ["note", "mote"], "ripples": 1.0},
}
## Particle kinds: card texture, blend, size, motion defaults and colour ramp.
const KINDS := {
	"charge": {"tex": "dot", "glow": true, "size": 0.75, "hot": 0.9, "gravity": Vector3(0, 0.01, 0), "damping": 0.0, "life": 0.5, "curve": "rise", "ramp": "charge"},
	"flash": {"tex": "dot", "glow": true, "size": 1.0, "hot": 1.0, "gravity": Vector3(0, 0.05, 0), "damping": 0.0, "life": 0.3, "curve": "pop", "ramp": "soft_glow"},
	"fire": {"tex": "fire", "glow": true, "size": 0.85, "hot": 0.35, "gravity": Vector3(0, 2.6, 0), "damping": 1.4, "life": 0.62, "curve": "grow", "ramp": "hot"},
	"ember": {"tex": "dot", "glow": true, "size": 0.4, "hot": 0.75, "gravity": Vector3(0, 1.5, 0), "damping": 1.3, "life": 1.1, "curve": "shrink", "ramp": "hot"},
	"spark": {"tex": "dot", "glow": true, "size": 0.12, "stretch": 5.0, "hot": 0.9, "gravity": Vector3(0, -7.0, 0), "damping": 2.2, "life": 0.5, "curve": "shrink", "ramp": "hot", "align": true},
	"arc": {"tex": "dot", "glow": true, "size": 0.12, "stretch": 7.0, "hot": 1.0, "gravity": Vector3(0, -0.05, 0), "damping": 9.0, "life": 0.26, "curve": "pop", "ramp": "hot", "align": true},
	"mote": {"tex": "twinkle", "glow": true, "size": 0.5, "hot": 0.4, "gravity": Vector3(0, 0.55, 0), "damping": 1.6, "life": 1.4, "curve": "flat", "ramp": "hot"},
	"ray": {"tex": "dot", "glow": true, "size": 0.3, "stretch": 8.0, "hot": 0.45, "gravity": Vector3(0, 0.4, 0), "damping": 1.0, "life": 1.0, "curve": "pop", "ramp": "soft_glow", "align": true},
	"smoke": {"tex": "smoke", "glow": false, "size": 0.8, "dissolve": 0.85, "gain": 2.4, "gravity": Vector3(0, 0.45, 0), "damping": 1.6, "life": 1.9, "curve": "grow", "ramp": "smoke"},
	"mist": {"tex": "smoke_soft", "glow": false, "size": 1.6, "dissolve": 0.8, "gain": 2.0, "gravity": Vector3(0, 0.12, 0), "damping": 1.3, "life": 2.0, "curve": "grow", "ramp": "mist"},
	"dust": {"tex": "smoke", "glow": false, "size": 1.1, "dissolve": 0.6, "gain": 1.8, "gravity": Vector3(0, -0.35, 0), "damping": 2.8, "life": 1.25, "curve": "grow", "ramp": "dust"},
	"debris": {"tex": "diamond", "glow": false, "size": 0.2, "gravity": Vector3(0, -15.0, 0), "damping": 0.3, "life": 0.85, "curve": "flat", "ramp": "debris"},
	"snow": {"tex": "snow", "glow": false, "size": 0.24, "gravity": Vector3(0, -1.0, 0), "damping": 1.5, "life": 1.6, "curve": "shrink", "ramp": "pale"},
	"shard": {"tex": "diamond", "glow": true, "size": 0.26, "stretch": 1.7, "hot": 0.55, "gravity": Vector3(0, -9.0, 0), "damping": 0.7, "life": 0.7, "curve": "shrink", "ramp": "hot", "align": true},
	"leaf": {"tex": "leaf", "glow": false, "size": 0.3, "gravity": Vector3(0, -0.9, 0), "damping": 1.9, "life": 1.8, "curve": "flat", "ramp": "solid"},
	"petal": {"tex": "petal", "glow": false, "size": 0.24, "gravity": Vector3(0, -0.6, 0), "damping": 1.9, "life": 1.8, "curve": "flat", "ramp": "solid"},
	"droplet": {"tex": "dot", "glow": true, "size": 0.14, "stretch": 2.6, "hot": 0.5, "gravity": Vector3(0, -11.0, 0), "damping": 0.4, "life": 0.75, "curve": "shrink", "ramp": "hot", "align": true},
	"note": {"tex": "note", "glow": true, "size": 0.42, "gravity": Vector3(0, 0.9, 0), "damping": 1.5, "life": 1.4, "curve": "pop", "ramp": "soft_glow"},
	"wisp": {"tex": "smoke_soft", "glow": false, "size": 0.62, "stretch": 2.4, "dissolve": 0.7, "gain": 1.7, "gravity": Vector3(0, 0.9, 0), "damping": 1.6, "life": 1.15, "curve": "grow", "ramp": "dark", "align": true},
}
## Star skills (no recipe row): their class's element, with a few authored exceptions.
const STAR_CLASS_ELEMENT := {
	"warrior": "light", "archer": "wind", "lancer": "steel", "mage": "arcane", "priest": "light",
	"summoner": "leaf", "defender": "light", "assassin": "shadow", "darklord": "shadow", "bard": "music",
}
const STAR_ELEMENT := {
	"lionfang_cleave": "flame", "divine_edict": "flame", "chaos_inferno": "flame", "crystal_prison": "frost",
	"leviathan_surge": "tide", "eclipse_sovereign": "tide", "heavenrend_spear": "storm",
	"imperial_cataclysm": "storm", "worldsplitter": "earth", "sunfall_volley": "flame", "genesis_nova": "flame",
}
## Particle cards are sized for the chibi scale seen from the follow camera.
const SIZE_GAIN := 1.6
const MELEE := ["warrior", "lancer", "defender", "assassin", "darklord", "vagabond"]
## Light peak energy per family (the flash that lights the ground and fighters).
const FLASH := {"ground": 3.0, "burst": 3.2, "strike": 3.6, "slash": 1.7, "swirl": 1.9, "shot": 1.3, "aura": 1.5}

static var enabled := true
static var _cards: Dictionary = {}
static var _dot: Texture2D
static var _ramps: Dictionary = {}
static var _curves: Dictionary = {}
static var _recent := PackedInt64Array([0, 0, 0, 0, 0, 0, 0, 0])
static var _recent_next := 0
static var _contacts: Dictionary = {}
static var _scale := 1.0
## Set while a ClassFlourish.TINTED skill releases: its impact light and bloom
## are tinted, shorter and fainter, so its own mist / portal stays readable.
static var _soft := false
## What the last call put on screen (tests, probes): layer names and node counts.
static var last := {"layers": [], "emitters": 0, "rings": 0, "lights": 0, "hazes": 0, "particles": 0}


# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------

## The layers shown right now, from the quality setting, MemoryGuard pressure and
## how many skills went off in the last second ([param crowd]).
static func layers_now(crowd := 0) -> Array[String]:
	if not enabled:
		return []
	var quality := VfxBudget.quality()
	var pressure := MemoryGuard.pressure
	if pressure >= 2 or crowd >= 6:
		return ["core", "secondary"]
	if quality == 0:
		return ["anticipation", "core"]
	if pressure == 1 or crowd >= 3:
		return ["anticipation", "core", "secondary"]
	return LAYERS.duplicate()


## Silhouette family, element, colours and size of a skill's layers.
static func look_of(skill: Dictionary) -> Dictionary:
	var id := String(skill.get("id", ""))
	if skill.has("star"):
		var colors := StarSkillArt.look(skill)
		var cls := String(skill.get("class", ""))
		var shape := String(skill.get("shape", "single"))
		var family := "aura"
		if shape in ["blast", "burst"]:
			family = "ground"
		elif shape == "single" or shape == "chain":
			family = "slash" if cls in MELEE else "shot"
		var god := StarSkillData.is_god(skill)
		return {"key": id, "family": family, "element": STAR_ELEMENT.get(id, STAR_CLASS_ELEMENT.get(cls, "arcane")),
			"hot": colors.accent, "mid": colors.primary, "dark": colors.shade, "scale": 1.5 if god else 1.3, "star": true}
	var recipe: Array = SkillArtDirection.RECIPES.get(id, ["sigil", "arcane", 3, 0.35, 0.70])
	var palette: Array = SkillArtDirection.PALETTES[recipe[1]]
	var level := clampi(int(skill.get("level", 1)), 1, 100)
	return {"key": String(recipe[1]), "family": FAMILIES.get(String(recipe[0]), "aura"),
		"element": PALETTE_ELEMENT.get(String(recipe[1]), "arcane"), "hot": palette[1], "mid": palette[0],
		"dark": palette[2], "scale": 0.75 + float(level) / 100.0 * 0.55, "star": false}


## The full description used by the tests and the gallery: the look plus the
## layers and per-layer kinds a cast of [param skill] shows right now.
static func plan(skill: Dictionary, crowd := 0) -> Dictionary:
	var look := look_of(skill)
	var element: Dictionary = ELEMENTS[look.element]
	return {"family": look.family, "element": look.element, "layers": layers_now(crowd),
		"secondary": element.secondary, "afterglow": element.after, "scale": _particle_scale(look, crowd)}


static func _particle_scale(look: Dictionary, crowd: int) -> float:
	var s := float([0.35, 0.65, 1.0][VfxBudget.quality()]) * float([1.0, 0.5, 0.35][clampi(MemoryGuard.pressure, 0, 2)])
	if crowd >= 2:
		s *= 0.7
	return s * float(look.scale)


## Forgets the recent casts (tests measure single casts).
static func reset_crowd() -> void:
	_recent.fill(0)
	_contacts.clear()


static func _crowd() -> int:
	var now := Time.get_ticks_msec()
	var n := 0
	for t in _recent:
		if t > 0 and now - t < 1000:
			n += 1
	_recent[_recent_next] = now
	_recent_next = (_recent_next + 1) % _recent.size()
	return n


static func _reset_stats(layers: Array[String]) -> void:
	last.layers = layers
	last.emitters = 0
	last.rings = 0
	last.lights = 0
	last.hazes = 0
	last.particles = 0


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

## Layer 1, over the existing wind-up ([param duration]); never delays the cast.
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim := Vector3.ZERO, visual: HeroVisual = null) -> void:
	if not enabled or skill.is_empty():
		return
	var layers := layers_now(_crowd())
	_reset_stats(layers)
	if not "anticipation" in layers:
		return
	var pool := SkillLayerPool.of(parent)
	if pool == null:
		return
	var look := look_of(skill)
	_scale = _particle_scale(look, 0)
	var owner := parent.get_instance_id()
	var hand := visual.skill_emission_position() if is_instance_valid(visual) and visual.is_inside_tree() else origin + Vector3(0, 1.2, 0)
	var time := clampf(duration, 0.12, 2.5)
	var element: Dictionary = ELEMENTS[look.element]
	var gather := String(element.gather)
	# Motes spiral into the hand; none arrive after the release.
	var life := minf(0.5, time)
	var stream := maxf(0.0, time - life)
	_emit(pool, owner, gather, hand, look, 26, {"shape": "sphere", "radius": 1.7, "dir": Vector3.UP, "spread": 180.0,
		"v": Vector2(0.1, 0.5), "radial": Vector2(-13.0, -9.0), "tangential": Vector2(5.0, 8.0),
		"gravity": Vector3(0, 0.08, 0), "damping": 0.6, "life": life, "size": 1.0}, 0.0, stream)
	var quiet := VfxBudget.quality() == 0
	# Light gathers in the hand and swells up to the release.
	_emit(pool, owner, "charge", hand, look, 1, {"shape": "sphere", "radius": 0.01, "v": Vector2.ZERO, "life": time, "min": 1,
		"size": 1.0 + float(look.scale) * 0.3}, 0.0)
	if not quiet:
		# Light rises from the ground round the caster.
		_emit(pool, owner, "mote" if gather != "note" else "note", origin + Vector3(0, 0.08, 0), look, 10, {"shape": "ring", "radius": 0.85,
			"dir": Vector3.UP, "spread": 8.0, "v": Vector2(1.1, 2.3), "gravity": Vector3(0, 0.9, 0), "damping": 0.5,
			"tangential": Vector2(1.0, 2.0), "life": minf(0.8, time + 0.2), "size": 0.75}, 0.0, maxf(0.0, time - 0.5))
	if pool.ring(owner, origin, 1.9, time, look.mid, look.hot, 0.0, 0.12, 0.65, 0.0, true):
		last.rings += 1
	if not quiet and pool.light(owner, hand, (look.mid as Color).lerp(look.hot, 0.4), 1.3, 3.5, time, 0.0, true):
		last.lights += 1


## Layers 3-5 when a non-star skill releases (SkillShow.play). [param wait] holds
## an area's layers for a meteor / arrow-rain landing, like its own art.
static func release(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, wait := 0.0) -> void:
	if not enabled or skill.is_empty():
		return
	var look := look_of(skill)
	var shape := String(skill.get("shape", "single"))
	var family := String(look.family)
	var at := center
	if shape in ["self", "summon", "burst"]:
		at = origin
	if shape in ["self", "summon"] and family in ["shot", "slash", "strike", "ground"]:
		# A buff or a summon gathers round the caster, whatever its weapon motif.
		family = "aura"
	elif bool(skill.get("projectile", false)) or shape in ["fan", "chain"]:
		# The flight and its contact own the far end; the release is a muzzle burst.
		family = "shot"
	elif shape == "single" and family in ["aura", "swirl", "shot"]:
		family = "slash"
	var radius := clampf(float(skill.get("radius", 2.2)), 1.2, 5.5) if shape in ["burst", "blast"] else 1.6
	var tint := ClassFlourish.tinted(skill)
	if not tint.is_empty():
		# No white-hot core: the skill's own mid and core colours carry the light.
		look = look.duplicate()
		look.key = "tint_" + String(skill.get("id", ""))
		look.mid = tint[0]
		look.hot = (tint[1] as Color).lerp(tint[0], 0.25)
		_soft = true
	_play(parent, look, family, at, origin, center, radius, maxf(0.0, wait), 1.0, _crowd())
	_soft = false


## Each hit a skill lands (SkillTableau.contact): projectiles, chains and fans get
## their impact here; the bespoke sequences (Judgment Ray, Thunder Storm and
## Armageddon) too. Area and melee hits were already covered by the release.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit := false) -> void:
	if not enabled or skill.is_empty():
		return
	var id := String(skill.get("id", ""))
	var shape := String(skill.get("shape", "single"))
	var bespoke := id in ["judgment_ray", "thunder_storm", "armageddon"]
	if not bespoke and not bool(skill.get("projectile", false)) and not shape in ["fan", "chain"]:
		return
	var now := Time.get_ticks_msec()
	if now - int(_contacts.get(id, -100000)) < (160 if bespoke else 110):
		return
	if _contacts.size() > 512:
		_contacts.clear()
	_contacts[id] = now
	var look := look_of(skill)
	var family := String(look.family)
	if bespoke:
		family = "ground" if id == "armageddon" else "strike"
	elif family in ["shot", "aura", "slash", "swirl"]:
		family = "burst"
	var ground := Vector3(at.x, at.y - 0.9 if at.y > 0.9 else 0.0, at.z)
	_play(parent, look, family, ground, ground, ground, 1.4 if not bespoke else 2.4, 0.0, 0.85 if crit else 0.6, _crowd())


## A star skill's beat (StarSkillSequence): the first beat and a god finale get
## the full stack, the waves between a lighter one.
static func star_beat(parent: Node3D, skill: Dictionary, at: Vector3, index: int, count: int, origin: Vector3) -> void:
	if not enabled or skill.is_empty():
		return
	var look := look_of(skill)
	var finale := StarSkillData.is_god(skill) and index == count - 1 and count > 1
	var full := index == 0 or finale
	var shape := String(skill.get("shape", "single"))
	var place := origin if shape in ["self", "summon"] else at
	var radius := clampf(float(skill.get("radius", 3.0)), 1.4, 6.0)
	_play(parent, look, String(look.family), place, origin, at, radius, 0.0, 1.0 if full else 0.45, _crowd() + (0 if full else 3))


# ---------------------------------------------------------------------------
# Layers
# ---------------------------------------------------------------------------

static func _play(parent: Node3D, look: Dictionary, family: String, at: Vector3, origin: Vector3, center: Vector3,
		radius: float, wait: float, weight: float, crowd: int) -> void:
	var layers := layers_now(crowd)
	_reset_stats(layers)
	if not "secondary" in layers:
		return
	var pool := SkillLayerPool.of(parent)
	if pool == null:
		return
	_scale = _particle_scale(look, crowd) * weight
	var owner := parent.get_instance_id()
	var forward := center - origin
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD
	var minimal := layers.size() <= 2
	_secondary(pool, owner, look, family, at, origin, forward, radius, wait, minimal, weight)
	if "environment" in layers:
		_environment(pool, owner, look, family, at, radius, wait, weight)
	if "afterglow" in layers:
		_afterglow(pool, owner, look, family, at, radius, wait)


static func _secondary(pool: SkillLayerPool, owner: int, look: Dictionary, family: String, at: Vector3, origin: Vector3,
		forward: Vector3, r: float, wait: float, minimal: bool, weight: float) -> void:
	var element: Dictionary = ELEMENTS[look.element]
	var main := String(element.secondary[0])
	var trail := String(element.secondary[1])
	var ripples := float(element.get("ripples", 0.0))
	var up := Vector3.UP
	if not minimal and family in ["ground", "burst", "strike", "slash"]:
		# The impact's own light: a soft white-hot bloom that pops and is gone.
		_emit(pool, owner, "flash", at + up * (0.9 if family == "slash" else 0.6), look, 1 if _soft else 2, {"shape": "sphere", "radius": 0.1, "v": Vector2.ZERO,
			"size": clampf(r * 0.9, 1.6, 4.2) * weight * (0.45 if _soft else 1.0), "min": 1 if _soft else 2, "life_mul": 0.6 if _soft else 1.0}, wait)
	if not minimal and element.has("extra") and VfxBudget.quality() == 2:
		_emit(pool, owner, String(element.extra), at + up * 0.6, look, 14, {"shape": "sphere", "radius": r * 0.2, "dir": up, "spread": 80.0,
			"v": Vector2(2.5, 6.0)}, wait + 0.02)
	match family:
		"ground", "burst":
			_emit(pool, owner, main, at + up * 0.35, look, 34, {"shape": "sphere", "radius": r * 0.22, "dir": up, "spread": 68.0,
				"v": Vector2(3.0, 7.5) * clampf(r / 2.5, 0.8, 1.5)}, wait)
			if minimal:
				return
			_emit(pool, owner, trail, at + up * 0.2, look, 14, {"shape": "ring", "radius": r * 0.5, "dir": up, "spread": 40.0,
				"v": Vector2(1.4, 3.8), "radial": Vector2(2.0, 5.0)}, wait + 0.04)
			_ring(pool, owner, at, r * 1.3, 0.62, look.mid, look.hot, wait, 0.15, 0.85 * weight, ripples)
			if VfxBudget.quality() == 2 and weight >= 1.0:
				_ring(pool, owner, at, r * 0.75, 0.48, look.hot, look.hot, wait + 0.1, 0.07, 0.55, 0.0)
		"slash":
			_emit(pool, owner, main, at + up * 0.95, look, 28, {"shape": "ring", "radius": 1.3, "dir": up, "spread": 35.0,
				"v": Vector2(1.5, 4.0), "tangential": Vector2(10.0, 16.0)}, wait)
			if minimal:
				return
			# Wisps lag behind the cut: slower, longer lived, turning the same way.
			_emit(pool, owner, trail, at + up * 0.9, look, 12, {"shape": "ring", "radius": 1.1, "dir": up, "spread": 25.0,
				"v": Vector2(0.4, 1.4), "tangential": Vector2(4.0, 7.0), "life_mul": 1.5}, wait + 0.05)
			_ring(pool, owner, at, 1.9, 0.45, look.mid, look.hot, wait, 0.08, 0.7 * weight, ripples)
		"swirl":
			_emit(pool, owner, main, at + up * 0.1, look, 30, {"shape": "ring", "radius": r * 0.55, "dir": up, "spread": 14.0,
				"v": Vector2(2.0, 4.5), "tangential": Vector2(8.0, 14.0), "radial": Vector2(-1.5, 0.5)}, wait, 0.35)
			if minimal:
				return
			_emit(pool, owner, trail, at + up * 0.5, look, 12, {"shape": "sphere", "radius": r * 0.35, "dir": up, "spread": 60.0,
				"v": Vector2(0.8, 2.2), "tangential": Vector2(3.0, 6.0)}, wait + 0.08)
			_ring(pool, owner, at, r * 1.15, 0.7, look.mid, look.hot, wait, 0.12, 0.75 * weight, ripples)
		"strike":
			_emit(pool, owner, main, at + up * 5.5, look, 18, {"shape": "box", "extents": Vector3(r * 0.45, 0.6, r * 0.45),
				"dir": Vector3.DOWN, "spread": 6.0, "v": Vector2(10.0, 15.0), "life": 0.42, "gravity": Vector3(0, -6.0, 0)}, wait)
			if minimal:
				return
			_emit(pool, owner, trail, at + up * 0.3, look, 14, {"shape": "sphere", "radius": r * 0.25, "dir": up, "spread": 75.0,
				"v": Vector2(2.0, 5.0)}, wait + 0.06)
			_ring(pool, owner, at, r * 1.2, 0.52, look.mid, look.hot, wait + 0.04, 0.11, 0.85 * weight, ripples)
		"shot":
			var muzzle := origin + up * 1.15 + forward * 0.8
			_emit(pool, owner, main, muzzle, look, 14, {"shape": "sphere", "radius": 0.15, "dir": forward, "spread": 16.0,
				"v": Vector2(5.0, 10.0), "damping": 3.5, "life": 0.38, "gravity": Vector3(0, -1.0, 0)}, wait)
			if minimal:
				return
			_emit(pool, owner, trail, muzzle, look, 8, {"shape": "sphere", "radius": 0.3, "dir": forward, "spread": 50.0,
				"v": Vector2(0.4, 1.6), "life_mul": 0.8}, wait + 0.02)
		_:
			# Aura: a rising column round the caster, motes about the body.
			_emit(pool, owner, main, at + up * 0.08, look, 26, {"shape": "ring", "radius": 1.0, "dir": up, "spread": 10.0,
				"v": Vector2(1.0, 2.5), "tangential": Vector2(1.0, 3.0), "damping": 0.8, "life_mul": 1.1}, wait, 0.5)
			if minimal:
				return
			_emit(pool, owner, trail, at + up * 1.0, look, 12, {"shape": "sphere", "radius": 0.9, "dir": up, "spread": 180.0,
				"v": Vector2(0.3, 1.0)}, wait + 0.08)
			_ring(pool, owner, at, 1.9, 0.85, look.mid, look.hot, wait, 0.12, 0.6 * weight, ripples)


static func _environment(pool: SkillLayerPool, owner: int, look: Dictionary, family: String, at: Vector3, r: float, wait: float, weight: float) -> void:
	var up := Vector3.UP
	if family in ["ground", "burst", "strike", "slash", "swirl"]:
		var spread := clampf(r / 2.5, 0.75, 1.6)
		_emit(pool, owner, "dust", at + up * 0.2, look, 16, {"shape": "box", "extents": Vector3(r * 0.35, 0.05, r * 0.35), "dir": up, "spread": 80.0,
			"v": Vector2(0.6, 2.0), "radial": Vector2(3.5, 7.0), "size": spread * 0.75}, wait + 0.03)
		if family != "slash" and family != "swirl" and String(look.element) != "earth":
			_emit(pool, owner, "debris", at + up * 0.2, look, 10, {"shape": "sphere", "radius": r * 0.3, "dir": up, "spread": 50.0,
				"v": Vector2(4.0, 8.0) * clampf(r / 2.5, 0.8, 1.3)}, wait + 0.01)
	var hot: Color = look.hot
	if pool.light(owner, at + up * 1.3, (look.mid as Color).lerp(hot, 0.35), float(FLASH.get(family, 1.5)) * 1.6 * weight * (0.4 if _soft else 1.0), r * 2.2 + 3.0,
			(0.7 if family == "aura" else 0.48) * (0.6 if _soft else 1.0), wait):
		last.lights += 1
	var hazy := bool(ELEMENTS[look.element].get("haze", false)) or (family in ["ground", "burst"] and String(look.element) == "earth")
	if hazy and VfxBudget.quality() == 2 and MemoryGuard.pressure == 0 and pool.haze(owner, at + up * 0.9, r * 0.9 + 0.9, 0.95, (look.mid as Color).lerp(look.hot, 0.5), wait + 0.05):
		last.hazes += 1


static func _afterglow(pool: SkillLayerPool, owner: int, look: Dictionary, family: String, at: Vector3, r: float, wait: float) -> void:
	var after: Array = ELEMENTS[look.element].after
	var up := Vector3.UP
	var reach := r * (0.55 if family != "aura" else 0.5)
	_emit(pool, owner, String(after[0]), at + up * 0.35, look, 22, {"shape": "box", "extents": Vector3(maxf(0.6, reach), 0.2, maxf(0.6, reach)),
		"dir": up, "spread": 35.0, "v": Vector2(0.2, 0.9), "life_mul": 1.15}, wait + 0.22, 0.6)
	if after.size() > 1:
		_emit(pool, owner, String(after[1]), at + up * 0.7, look, 20, {"shape": "sphere", "radius": maxf(0.5, reach * 0.8), "dir": up, "spread": 70.0,
			"v": Vector2(0.3, 1.2), "life_mul": 1.3}, wait + 0.3, 0.7)


static func _ring(pool: SkillLayerPool, owner: int, at: Vector3, radius: float, length: float, mid: Color, hot: Color, delay: float,
		width: float, intensity: float, ripples: float) -> void:
	if pool.ring(owner, at, radius, length * (0.7 if _soft else 1.0), mid, hot, delay, width, intensity * (0.4 if _soft else 1.0), ripples):
		last.rings += 1


# ---------------------------------------------------------------------------
# Emitters
# ---------------------------------------------------------------------------

static func _emit(pool: SkillLayerPool, owner: int, kind: String, at: Vector3, look: Dictionary, base: int, motion: Dictionary,
		delay := 0.0, stream := 0.0) -> void:
	var spec: Dictionary = KINDS[kind]
	var amount := maxi(2, int(ceil(float(base) * _scale)))
	if motion.has("min"):
		amount = int(motion.min)
	var life := float(motion.get("life", float(spec.life) * float(motion.get("life_mul", 1.0))))
	var p := pool.emitter(owner, amount, life, delay, stream)
	if p == null:
		return
	last.emitters += 1
	last.particles += p.amount
	p.mesh = _card(kind)
	p.global_position = at
	p.explosiveness = 0.0 if stream > 0.0 else 0.9
	p.randomness = 0.35
	p.lifetime_randomness = 0.45
	match String(motion.get("shape", "sphere")):
		"ring":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			p.emission_ring_axis = Vector3.UP
			p.emission_ring_radius = float(motion.radius)
			p.emission_ring_inner_radius = float(motion.radius) * 0.7
			p.emission_ring_height = 0.15
		"box":
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			p.emission_box_extents = motion.extents
		_:
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = maxf(0.02, float(motion.get("radius", 0.3)))
	p.direction = motion.get("dir", Vector3.UP)
	p.spread = float(motion.get("spread", 45.0))
	p.flatness = 0.0
	var v: Vector2 = motion.get("v", Vector2(1.0, 3.0))
	p.initial_velocity_min = v.x
	p.initial_velocity_max = v.y
	var gravity: Vector3 = motion.get("gravity", spec.gravity)
	# Tangential acceleration turns about the gravity axis: keep one.
	if gravity.length_squared() < 0.0001:
		gravity = Vector3(0, 0.01, 0)
	p.gravity = gravity
	var damping := float(motion.get("damping", spec.damping))
	p.damping_min = damping * 0.7
	p.damping_max = damping * 1.3
	var radial: Vector2 = motion.get("radial", Vector2.ZERO)
	p.radial_accel_min = radial.x
	p.radial_accel_max = radial.y
	var tangential: Vector2 = motion.get("tangential", Vector2.ZERO)
	p.tangential_accel_min = tangential.x
	p.tangential_accel_max = tangential.y
	var size := float(spec.size) * float(motion.get("size", 1.0)) * (SIZE_GAIN if not motion.has("min") else 1.0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	p.scale_amount_curve = _curve(String(spec.curve))
	p.particle_flag_align_y = bool(spec.get("align", false))
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.color = Color.WHITE
	p.color_ramp = _ramp(String(spec.ramp), look)


## One card per kind (shared mesh + material; colour comes from the ramp).
static func _card(kind: String) -> QuadMesh:
	if _cards.has(kind):
		return _cards[kind]
	var spec: Dictionary = KINDS[kind]
	var mat := ShaderMaterial.new()
	mat.shader = CARD_GLOW if bool(spec.glow) else CARD_SMOKE
	var tex := String(spec.tex)
	var texture: Texture2D
	if tex == "dot":
		texture = _dot_texture()
	elif tex == "twinkle":
		texture = VfxArt.texture("star")
	elif tex in ["diamond", "snow", "leaf", "petal", "note"]:
		texture = VfxArt.texture(tex)
	else:
		texture = SpectacleAssets.tex(tex)
	mat.set_shader_parameter("tex", texture)
	mat.set_shader_parameter("stretch", float(spec.get("stretch", 0.0)))
	mat.set_shader_parameter("dissolve", float(spec.get("dissolve", 0.0)))
	mat.set_shader_parameter("hot", float(spec.get("hot", 0.0)))
	mat.set_shader_parameter("energy", 1.0)
	mat.set_shader_parameter("alpha_gain", float(spec.get("gain", 1.0)))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = mat
	_cards[kind] = quad
	return quad


## A small hot dot (bright core, soft falloff) for embers, sparks, arcs and drops:
## the CC0 glow cards are too faint at particle size.
static func _dot_texture() -> Texture2D:
	if _dot != null:
		return _dot
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var r := Vector2((x + 0.5) / size * 2.0 - 1.0, (y + 0.5) / size * 2.0 - 1.0).length()
			var a := pow(clampf(1.0 - r, 0.0, 1.0), 2.2) * 0.75 + (1.0 - smoothstep(0.0, 0.32, r)) * 0.25
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_dot = ImageTexture.create_from_image(img)
	return _dot


static func _curve(kind: String) -> Curve:
	if _curves.has(kind):
		return _curves[kind]
	var c := Curve.new()
	c.max_value = 2.0
	match kind:
		"shrink":
			c.add_point(Vector2(0.0, 1.0))
			c.add_point(Vector2(1.0, 0.1))
		"rise":
			c.add_point(Vector2(0.0, 0.15))
			c.add_point(Vector2(0.8, 0.85))
			c.add_point(Vector2(1.0, 1.15))
		"pop":
			c.add_point(Vector2(0.0, 0.2))
			c.add_point(Vector2(0.14, 1.0))
			c.add_point(Vector2(1.0, 0.0))
		"grow":
			c.add_point(Vector2(0.0, 0.45))
			c.add_point(Vector2(0.4, 1.1))
			c.add_point(Vector2(1.0, 1.6))
		_:
			c.add_point(Vector2(0.0, 0.7))
			c.add_point(Vector2(0.1, 1.0))
			c.add_point(Vector2(0.85, 1.0))
			c.add_point(Vector2(1.0, 0.3))
	_curves[kind] = c
	return c


## The colour hierarchy of each kind: white-hot core -> palette mid -> dark rim.
static func _ramp(kind: String, look: Dictionary) -> Gradient:
	var key := kind + ":" + String(look.key)
	if _ramps.has(key):
		return _ramps[key]
	if _ramps.size() > 256:
		_ramps.clear()
	var hot: Color = look.hot
	var mid: Color = look.mid
	var dark: Color = look.dark
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	match kind:
		"hot":
			offsets = PackedFloat32Array([0.0, 0.06, 0.35, 1.0])
			colors = PackedColorArray([Color(hot, 0.0), Color(hot, 1.0), Color(mid, 0.85), Color(dark, 0.0)])
		"charge":
			offsets = PackedFloat32Array([0.0, 0.5, 0.92, 1.0])
			colors = PackedColorArray([Color(mid, 0.0), Color(mid, 0.45), Color(hot, 0.85), Color(hot, 0.0)])
		"soft_glow":
			offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
			colors = PackedColorArray([Color(mid, 0.0), Color(hot, 0.8), Color(mid, 0.55), Color(mid, 0.0)])
		"smoke":
			var base := Color(0.5, 0.47, 0.46).lerp(dark, 0.25)
			offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
			colors = PackedColorArray([Color(mid.lerp(base, 0.4), 0.0), Color(mid.lerp(base, 0.7), 0.5), Color(base, 0.32), Color(base, 0.0)])
		"mist":
			var pale := mid.lerp(Color.WHITE, 0.6)
			offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
			colors = PackedColorArray([Color(pale, 0.0), Color(pale, 0.34), Color(pale, 0.2), Color(pale, 0.0)])
		"dust":
			var soil := Color("a8957a").lerp(dark, 0.18)
			offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
			colors = PackedColorArray([Color(soil, 0.0), Color(soil, 0.42), Color(soil.darkened(0.1), 0.24), Color(soil, 0.0)])
		"debris":
			var rock := Color("5e5048").lerp(dark, 0.3)
			offsets = PackedFloat32Array([0.0, 0.8, 1.0])
			colors = PackedColorArray([Color(rock, 1.0), Color(rock, 1.0), Color(rock, 0.0)])
		"pale":
			offsets = PackedFloat32Array([0.0, 0.1, 0.75, 1.0])
			colors = PackedColorArray([Color(hot, 0.0), Color(hot, 0.95), Color(mid.lerp(Color.WHITE, 0.5), 0.8), Color(mid, 0.0)])
		"solid":
			offsets = PackedFloat32Array([0.0, 0.08, 0.7, 1.0])
			colors = PackedColorArray([Color(mid, 0.0), Color(mid, 1.0), Color(mid.lerp(dark, 0.3), 0.9), Color(dark, 0.0)])
		_:
			# "dark": shadow wisps and tendrils.
			var deep := dark.lerp(mid, 0.25)
			offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
			colors = PackedColorArray([Color(deep, 0.0), Color(deep, 0.72), Color(dark, 0.45), Color(dark, 0.0)])
	g.offsets = offsets
	g.colors = colors
	_ramps[key] = g
	return g


## Builds the cards, curves and shaders during loading (no hitch on a first cast).
static func warm_up() -> void:
	for kind in KINDS:
		_card(String(kind))
	for kind in ["shrink", "pop", "grow", "flat", "rise"]:
		_curve(kind)


## A zone change: everything stops now and the ramp cache goes.
static func release_cache(tree: SceneTree = null) -> void:
	var pool := SkillLayerPool.existing(tree)
	if pool:
		pool.stop_all()
	_ramps.clear()
	_contacts.clear()


# ---------------------------------------------------------------------------
# The Mage's three ultimates (Armageddon, Thunder Storm, Judgment Ray)
# ---------------------------------------------------------------------------

## Rain is drawn pale steel-blue, not in the storm's violet.
const RAIN_LOOK := {"key": "storm_rain", "family": "strike", "element": "storm", "hot": Color("eef6ff"),
	"mid": Color("9ab4d8"), "dark": Color("2a3446"), "scale": 1.0, "star": false}


## The authored particle layers of one beat of a Mage ultimate, from the shared pool
## (cosmetic only, called by MageUltimateArt at a beat its sequence already owns).
## [param part]: meteor_sky, meteor_impact, meteor_fragment, storm_rain, storm_strike,
## judgment_gather, judgment_land. [param owner]: the node whose exit ends them.
static func ultimate(owner: Node3D, skill_id: String, part: String, at: Vector3, r: float, seconds := 1.0) -> void:
	if not enabled or not MageUltimateArt.enabled or not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	var layers := layers_now(_crowd_peek())
	if not "secondary" in layers:
		return
	var pool := SkillLayerPool.of(owner)
	if pool == null:
		return
	var look := look_of(ClassData.find_skill(&"mage", skill_id))
	_scale = _particle_scale(look, 0)
	var id := owner.get_instance_id()
	var env := "environment" in layers
	var after := "afterglow" in layers
	var up := Vector3.UP
	var hot: Color = look.hot
	var mid: Color = look.mid
	match part:
		"meteor_sky":
			# The sky reddens: a charge light swells over the area and ash glows down.
			if env and pool.light(id, at + up * 5.0, Color(1.0, 0.3, 0.08), 2.4, r * 2.6 + 4.0, seconds, 0.0, true):
				last.lights += 1
			if after:
				_emit(pool, id, "ember", at + up * 7.0, look, 26, {"shape": "box", "extents": Vector3(r * 0.8, 1.5, r * 0.8), "dir": Vector3.DOWN,
					"spread": 30.0, "v": Vector2(0.4, 1.4), "gravity": Vector3(0.4, -1.2, 0.2), "damping": 0.5, "life": 1.3, "size": 0.8}, 0.0, maxf(0.0, seconds - 1.0))
		"meteor_impact":
			_emit(pool, id, "flash", at + up * 1.0, look, 2, {"shape": "sphere", "radius": 0.1, "v": Vector2.ZERO, "size": clampf(r * 0.8, 3.0, 6.0), "min": 2})
			_emit(pool, id, "fire", at + up * 0.4, look, 40, {"shape": "sphere", "radius": r * 0.25, "dir": up, "spread": 55.0, "v": Vector2(4.0, 10.0)})
			_ring(pool, id, at, r * 1.45, 0.75, mid, hot, 0.0, 0.2, 1.0, 0.0)
			_ring(pool, id, at, r * 0.95, 0.6, Color("c88a58"), hot, 0.14, 0.1, 0.7, 0.0)
			if env:
				# Shockwave dust rolls out along the ground; rock chips fly.
				_emit(pool, id, "dust", at + up * 0.25, look, 26, {"shape": "ring", "radius": r * 0.35, "dir": up, "spread": 70.0,
					"v": Vector2(0.5, 1.8), "radial": Vector2(7.0, 12.0), "size": clampf(r / 2.5, 1.0, 2.0), "life": 1.5}, 0.04)
				_emit(pool, id, "debris", at + up * 0.3, look, 16, {"shape": "sphere", "radius": r * 0.3, "dir": up, "spread": 45.0, "v": Vector2(6.0, 12.0)}, 0.01)
				if pool.light(id, at + up * 1.6, Color(1.0, 0.45, 0.12), 6.0, r * 3.0 + 4.0, 0.9):
					last.lights += 1
				if VfxBudget.quality() == 2 and MemoryGuard.pressure == 0 and pool.haze(id, at + up * 1.2, r * 1.1 + 1.0, 1.6, Color(1.0, 0.55, 0.2), 0.05):
					last.hazes += 1
			if after:
				# A smoke column climbs out of the crater; embers keep rising from the cracks.
				_emit(pool, id, "smoke", at + up * 1.2, look, 22, {"shape": "sphere", "radius": r * 0.22, "dir": up, "spread": 14.0,
					"v": Vector2(3.0, 5.5), "gravity": Vector3(0.3, 0.6, 0.1), "damping": 0.9, "size": clampf(r / 2.0, 1.6, 3.2), "life": 2.2}, 0.12, 0.9)
				_emit(pool, id, "ember", at + up * 0.3, look, 30, {"shape": "box", "extents": Vector3(r * 0.55, 0.2, r * 0.55), "dir": up, "spread": 25.0,
					"v": Vector2(1.5, 4.0), "life": 1.4}, 0.2, 1.6)
		"meteor_fragment":
			_emit(pool, id, "fire", at + up * 0.3, look, 12, {"shape": "sphere", "radius": r * 0.2, "dir": up, "spread": 60.0, "v": Vector2(2.5, 6.0)})
			if env:
				_emit(pool, id, "dust", at + up * 0.2, look, 10, {"shape": "ring", "radius": r * 0.3, "dir": up, "spread": 70.0,
					"v": Vector2(0.4, 1.2), "radial": Vector2(4.0, 7.0), "life": 1.1}, 0.02)
			_ring(pool, id, at, r * 1.1, 0.5, mid, hot, 0.0, 0.12, 0.7, 0.0)
		"storm_rain":
			# Slanting sheets of rain under the cloud deck, mist where they land.
			_emit(pool, id, "droplet", at + up * 7.5, RAIN_LOOK, 60, {"shape": "box", "extents": Vector3(r * 0.85, 0.6, r * 0.85),
				"dir": Vector3(0.18, -1.0, 0.08).normalized(), "spread": 3.0, "v": Vector2(14.0, 18.0), "gravity": Vector3(0, -6.0, 0),
				"damping": 0.0, "life": 0.5, "size": 1.25}, 0.1, maxf(0.2, seconds - 0.5))
			if env:
				_emit(pool, id, "mist", at + up * 0.25, RAIN_LOOK, 14, {"shape": "box", "extents": Vector3(r * 0.7, 0.1, r * 0.7), "dir": up,
					"spread": 60.0, "v": Vector2(0.2, 0.6), "size": 1.4, "life": 1.4}, 0.4, maxf(0.2, seconds - 1.2))
		"storm_strike":
			_emit(pool, id, "spark", at + up * 0.25, look, 18, {"shape": "sphere", "radius": 0.2, "dir": up, "spread": 70.0, "v": Vector2(4.0, 9.0)})
			_emit(pool, id, "arc", at + up * 0.4, look, 8, {"shape": "sphere", "radius": 0.5, "dir": up, "spread": 90.0, "v": Vector2(3.0, 6.0)})
			_ring(pool, id, at, 2.2, 0.45, mid, hot, 0.0, 0.1, 0.8, 0.0)
			if env and pool.light(id, at + up * 2.5, Color(0.7, 0.8, 1.0), 5.0, 9.0, 0.3):
				last.lights += 1
		"judgment_gather":
			# Light is drawn in from all round the target and spirals up into the halo.
			var life := minf(0.7, seconds)
			_emit(pool, id, "charge", at + up * 0.6, look, 30, {"shape": "ring", "radius": 3.0, "dir": up, "spread": 20.0,
				"v": Vector2(0.4, 1.2), "radial": Vector2(-7.0, -4.0), "tangential": Vector2(4.0, 7.0), "gravity": Vector3(0, 1.4, 0),
				"damping": 0.4, "life": life, "size": 0.45}, 0.0, maxf(0.0, seconds - life))
			if env and pool.light(id, at + up * 3.0, mid.lerp(hot, 0.5), 2.2, 7.0, seconds, 0.0, true):
				last.lights += 1
		"judgment_land":
			_emit(pool, id, "flash", at + up * 0.8, look, 2, {"shape": "sphere", "radius": 0.1, "v": Vector2.ZERO, "size": 4.0, "min": 2})
			# Spiral motes climb the beam; light keeps rising from the molten ring.
			_emit(pool, id, "mote", at + up * 0.3, look, 30, {"shape": "ring", "radius": 1.3, "dir": up, "spread": 8.0,
				"v": Vector2(3.0, 6.0), "tangential": Vector2(7.0, 11.0), "gravity": Vector3(0, 1.0, 0), "damping": 0.3, "life": 1.0, "size": 0.7}, 0.0, 0.5)
			_ring(pool, id, at, 3.4, 0.7, mid, hot, 0.0, 0.18, 0.95, 0.0)
			_ring(pool, id, at, 2.2, 0.9, hot, hot, 0.12, 0.08, 0.6, 0.0)
			if env:
				_emit(pool, id, "dust", at + up * 0.2, look, 14, {"shape": "ring", "radius": 1.2, "dir": up, "spread": 70.0,
					"v": Vector2(0.4, 1.2), "radial": Vector2(4.0, 7.0), "life": 1.0}, 0.03)
				if pool.light(id, at + up * 2.0, mid.lerp(hot, 0.6), 6.0, 9.0, 0.7):
					last.lights += 1
			if after:
				_emit(pool, id, "ray", at + up * 0.2, look, 14, {"shape": "ring", "radius": 2.0, "dir": up, "spread": 6.0,
					"v": Vector2(1.5, 3.5), "life": 1.0}, 0.15, 1.0)


## The crowd without counting this call as a cast (an ultimate's beats are one cast).
static func _crowd_peek() -> int:
	var now := Time.get_ticks_msec()
	var n := 0
	for t in _recent:
		if t > 0 and now - t < 1000:
			n += 1
	return n
