class_name SkillWeight
extends RefCounted
## How heavy a skill feels (0..1), worked out from its data so every class's skills
## get it without a table: the level it unlocks at, its shape, its gesture, its
## multiplier and its star tier. A small OVERRIDES table tunes the special ones.
## The weight drives only presentation (SkillFeel): hit-stop, camera, shake,
## enemy launch, ground marks. It never changes damage, timing or targets.

## Tiers: light, medium, heavy, ultimate.
enum { LIGHT, MEDIUM, HEAVY, ULTIMATE }
const TIER_LINES := [0.3, 0.55, 0.86]
## Star tier weights (★50 .. ★300); a 200-star skill and a god skill are ultimates.
const STAR_WEIGHT := {50: 0.62, 100: 0.68, 150: 0.58, 200: 0.88, 300: 1.0}
## Non-star skills stay under the ultimates.
const CLASS_SKILL_CAP := 0.84
## Gestures that carry the whole body into the hit.
const HEAVY_GESTURES := ["ground_slam", "execution", "sky_spear", "storm_spin", "channel", "crescendo", "verdict", "spear_throw"]
## Gestures that hit the ground (the camera kicks down with them).
const SLAM_GESTURES := ["ground_slam", "execution", "sky_spear"]
## Special skills whose derived weight would read wrong (many small strikes,
## one huge beam, a meteor).
const OVERRIDES := {
	"judgment_ray": 0.84, "armageddon": 0.84, "hell_meteor": 0.8, "meteo": 0.68,
	"thunder_storm": 0.58, "last_judgement": 0.84, "gladiator": 0.8, "world_bastion": 0.82,
	"piercing": 0.42, "divine_piercing": 0.5, "eternal_echo": 0.42, "celestial_swordfall": 0.9,
}

## Element look of a hit: flash colour (and how long it holds).
const FLASH := {
	"fire": Color("ff8a2a"), "ice": Color("7fd4ff"), "thunder": Color("fff27a"),
	"dark": Color("a35cff"), "holy": Color("ffd23f"), "earth": Color("d9a466"),
	"nature": Color("8be070"), "arcane": Color("c68cff"), "wind": Color("c8fff0"),
}
## Star skills all use the "light" preset: their element comes from the class.
const STAR_ELEMENT := {
	&"warrior": "holy", &"archer": "holy", &"lancer": "thunder", &"mage": "arcane", &"priest": "holy",
	&"summoner": "ice", &"defender": "holy", &"assassin": "dark", &"darklord": "dark", &"bard": "arcane",
}

static var _cache: Dictionary = {}


static func weight(skill: Dictionary) -> float:
	if skill.is_empty():
		return 0.0
	var id := String(skill.get("id", ""))
	var key := "%s|%d" % [id, int(skill.get("star", 0))]
	if _cache.has(key):
		return _cache[key]
	var w := _derive(skill)
	_cache[key] = w
	return w


static func _derive(skill: Dictionary) -> float:
	var id := String(skill.get("id", ""))
	var star := int(skill.get("star", 0))
	if star > 0:
		return float(STAR_WEIGHT.get(star, 0.6 + minf(star, 300) / 750.0))
	if OVERRIDES.has(id):
		return float(OVERRIDES[id])
	var shape := String(skill.get("shape", "single"))
	var level := clampf(float(skill.get("level", 1)) / 100.0, 0.0, 1.0)
	if shape in ["self", "summon"]:
		return 0.12 + 0.2 * level
	var w := 0.12 + 0.38 * level
	if shape == "burst":
		w += 0.08
	elif shape == "blast":
		w += 0.1
	var gesture := String(SkillChoreography.cue_for(skill).get("gesture", ""))
	if gesture in HEAVY_GESTURES:
		w += 0.08
	# Area skills carry a low per-target multiplier for the same effort.
	var m := float(skill.get("mult", 1.0)) * (3.0 if shape in ["burst", "blast"] else 1.0)
	w += 0.12 * clampf(log(maxf(m, 1.0)) / log(60.0), 0.0, 1.0)
	if int(skill.get("level", 1)) >= 100:
		w += 0.1
	return clampf(w, 0.05, CLASS_SKILL_CAP)


static func tier(w: float) -> int:
	if w >= TIER_LINES[2]:
		return ULTIMATE
	if w >= TIER_LINES[1]:
		return HEAVY
	if w >= TIER_LINES[0]:
		return MEDIUM
	return LIGHT


static func tier_of(skill: Dictionary) -> int:
	return tier(weight(skill)) if not skill.is_empty() else LIGHT


## The 200-star skills and the god skills (300 stars): the ones with a cut-in.
static func is_ultimate(skill: Dictionary) -> bool:
	return int(skill.get("star", 0)) >= 200


## Hit-stop frames (at 60 fps) for a tier: light 2 ... heavy 8, ultimate 11.
static func stop_frames(t: int) -> int:
	return [2, 4, 8, 11][clampi(t, 0, 3)]


static func stop_seconds(t: int) -> float:
	return float(stop_frames(t)) / 60.0


## Camera shake amplitude (metres of camera offset) per tier; capped by the camera.
static func shake_amp(t: int) -> float:
	return [0.0, 0.035, 0.075, 0.115][clampi(t, 0, 3)]


static func is_slam(skill: Dictionary) -> bool:
	return String(SkillChoreography.cue_for(skill).get("gesture", "")) in SLAM_GESTURES


## The feel element: fire, ice, thunder, dark, holy, earth, nature, arcane, wind or phys.
static func element(skill: Dictionary) -> String:
	if skill.is_empty():
		return "phys"
	if skill.has("star"):
		return String(STAR_ELEMENT.get(StringName(String(skill.get("class", ""))), "holy"))
	var family := SkillShow.family_of(skill)
	var vfx := String(skill.get("vfx", ""))
	var e := ElementFx.element_of(skill)
	match e:
		"leaf", "plant", "vine":
			e = "nature"
		"water":
			e = "ice"
		"heal":
			e = "holy"
		"buff":
			e = "phys"
	if vfx in ["poison", "debuff"]:
		e = "dark"
	if family in ["assassin", "darklord"] and e in ["phys", "arcane"]:
		e = "dark"
	return e


static func flash_color(e: String) -> Color:
	return FLASH.get(e, Color.WHITE)


## The name the cut-in shows, in Thai: a god skill's own name, a star skill's Thai
## title (the first part of its description), else the skill's name.
static func thai_name(skill: Dictionary) -> String:
	var name := String(skill.get("name", ""))
	if _has_thai(name):
		return name
	var desc := String(skill.get("desc", ""))
	var head := desc.split("•")[0].strip_edges() if desc != "" else ""
	if head != "" and head.length() <= 28 and _has_thai(head):
		return head
	return name


static func _has_thai(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 0x0E00 and c <= 0x0E7F:
			return true
	return false
