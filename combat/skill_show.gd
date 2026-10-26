class_name SkillShow
extends RefCounted
## Class identity, layered volumetric silhouette and a finishing beat for every
## active skill. This layer is cosmetic: it never schedules damage or alters time.

const FAMILY_COLORS := {
	"vagabond": Color("f3cc8d"), "warrior": Color("ffac8f"),
	"archer": Color("98e6c4"), "mage": Color("c4adff"), "priest": Color("ffe8a8"), "summoner": Color("b4f08c"), "lancer": Color("9ad8ff"), "defender": Color("a8c8f0"), "assassin": Color("c4a8ff"), "darklord": Color("f0cc80"),
}
const ELEMENT_COLORS := {
	"fire": Color("ffab79"), "ice": Color("a8e5ff"), "holy": Color("ffe7ac"),
	"heal": Color("a4edc5"), "thunder": Color("d8ceff"), "wind": Color("bcf0e3"),
	"leaf": Color("9ee5bc"), "arcane": Color("c6aeff"), "earth": Color("e8c79f"),
}
static var _families: Dictionary = {}
static var _recent_shows: Array[int] = []


static func family_of(skill: Dictionary) -> String:
	if _families.is_empty():
		for family in FAMILY_COLORS:
			for entry in ClassData.pool(StringName(family)):
				_families[String(entry.id)] = family
	return _families.get(String(skill.get("id", "")), "vagabond")


static func style_of(skill: Dictionary) -> String:
	var id := String(skill.get("id", ""))
	if id in ["diastrophism", "bone_crash", "destroyer"]:
		return "earth"
	if id in ["agony", "distortion", "vague", "magic_overdrive", "silraphim", "spirit_elemental", "dancing_sword", "spirit_burst"]:
		return "arcane"
	if id == "fire_elemental":
		return "fire"
	match String(skill.get("vfx", &"impact")):
		"fireball": return "fire"
		"frost": return "ice"
		"light": return "holy"
		"heal": return "heal"
		"thunder": return "thunder"
		"wind": return "wind"
		"leaf": return "leaf"
		"aura": return "buff"
	var family := family_of(skill)
	return "arcane" if family == "mage" else ("holy" if family == "priest" else "phys")


## Public description also used by the all-skill visual audit.
static func profile_for(skill: Dictionary) -> Dictionary:
	var family := family_of(skill)
	var style := style_of(skill)
	var primary: Color = ELEMENT_COLORS.get(style, FAMILY_COLORS[family])
	var source: Color = skill.get("color", primary)
	primary = primary.lerp(source, 0.16)
	var id := String(skill.get("id", ""))
	var motif := String(skill.get("icon", "star"))
	if skill.get("fx", {}).has("heal") and String(skill.shape) == "self":
		motif = "heal"
	elif String(skill.shape) == "summon":
		motif = String(skill.get("summon", {}).get("kind", "spirit"))
	var profile := {"family": family, "style": style, "primary": primary,
		"accent": FAMILY_COLORS[family].lerp(Color.WHITE, 0.28),
		"motif": motif, "phase": float(posmod(id.hash(), 360)) * PI / 180.0,
		"tier": clampi(int(skill.get("level", 1)) / 20, 0, 5),
		"mapped": _families.has(id)}
	profile.merge(SkillArtDirection.recipe_for(skill), true)
	profile.merge(SkillChoreography.cue_for(skill), true)
	if skill.get("fx", {}).has("buff"):
		var buff_look := BuffArt.profile(skill)
		profile.primary = buff_look.primary
		profile.accent = buff_look.accent
	return profile


## Called with the existing wind-up duration. It does not delay resolution.
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim := Vector3.ZERO, visual: HeroVisual = null) -> void:
	var look := profile_for(skill)
	if StarSkillArt.handles(skill):
		if is_instance_valid(visual): StarSkillArt.telegraph(visual,skill,aim,duration)
		return
	if String(skill.id) == "judgment_ray":
		if visual:
			SkillCharge.launch(parent, visual, look, duration)
		return
	ClassFlourish.charge(parent, skill, origin, duration)
	SkillTableau.anticipate(parent, skill, look, origin, duration, aim, visual)
	EliteSkillArt.anticipate(parent, skill, origin, aim, duration, visual)
	ShadowSkillArt.anticipate(parent, skill, origin, aim, duration, visual)
	LordSkillArt.anticipate(parent, skill, origin, aim, duration, visual)


## center: target/area; origin: caster's feet. Hero and companions share this path.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, impact_delay := -1.0) -> void:
	if StarSkillArt.handles(skill):
		StarSkillArt.strike(parent,skill,center,0,origin)
		return
	# Armageddon owns its landing plus ten real secondary hits in its sequence.
	# A second cosmetic explosion here would imply damage before the landing.
	if String(skill.get("id", "")) in ["armageddon", "thunder_storm", "judgment_ray"]:
		return
	if EliteSkillArt.handles(skill):
		var wait := impact_delay if impact_delay >= 0.0 else (0.55 if String(skill.get("special", "")) in ["meteor", "rain"] else 0.0)
		EliteSkillArt.play(parent, skill, center, origin, wait)
		ShadowSkillArt.play(parent, skill, center, origin, wait)
		LordSkillArt.play(parent, skill, center, origin, wait)
		var now_ms := Time.get_ticks_msec()
		ClassFlourish.cast(parent, skill, center, origin, _recent_shows.filter(func(t: int): return now_ms - t < 1000).size())
		return
	var look := profile_for(skill)
	var shape := String(skill.shape)
	var now := Time.get_ticks_msec()
	_recent_shows = _recent_shows.filter(func(t: int): return now - t < 1000)
	var crowd := _recent_shows.size()
	_recent_shows.append(now)
	var tier := budget_step(int(look.tier), crowd)
	tier = mini(tier, [1, 3, 5][VfxBudget.quality()])
	var radius := float(skill.get("radius", 2.0))
	var at := origin if shape in ["self", "summon", "burst"] else center
	# Every crowd level keeps a class silhouette; only secondary layers shrink.
	# Meteor/rain art waits for the existing landing beat. Projectiles create
	# their release silhouette here; SkillTableau owns flight and contact art.
	var wait := impact_delay if impact_delay >= 0.0 else (0.55 if String(skill.get("special", "")) in ["meteor", "rain"] else 0.0)
	if wait > 0.0:
		parent.create_tween().tween_interval(wait).finished.connect(func():
			if is_instance_valid(parent) and parent.is_inside_tree():
				SpellSpectacle.cast(parent, skill, look, center, origin, tier, crowd), CONNECT_ONE_SHOT)
	else:
		SpellSpectacle.cast(parent, skill, look, center, origin, tier, crowd)
	match shape:
		"self", "summon": _self_cast(parent, skill, look, origin, tier)
		"burst", "blast":
			if wait > 0.0:
				parent.create_tween().tween_interval(wait).finished.connect(func():
					if is_instance_valid(parent) and parent.is_inside_tree():
						_area(parent, skill, look, at, radius, tier), CONNECT_ONE_SHOT)
			else:
				_area(parent, skill, look, at, radius, tier)
		"single": _single(parent, skill, look, center, origin, tier)
		"fan", "chain": _multi(parent, skill, look, origin, center, tier)
	# The Assassin's shadow sculptures and the Dark Lord's royal ones, then the
	# grand finish on top.
	ShadowSkillArt.play(parent, skill, center, origin, wait)
	LordSkillArt.play(parent, skill, center, origin, wait)
	ClassFlourish.cast(parent, skill, center, origin, crowd)


## Preserve the public crowd limiter used by the integration suite.
static func budget_step(step: int, crowd: int) -> int:
	if crowd >= 4:
		return mini(step, 1)
	if crowd >= 2:
		return mini(step, 2)
	return step


static func _mote_kind(style: String) -> String:
	match style:
		"ice": return "snow"
		"heal": return "heart"
		"leaf", "wind": return "leaf"
		"fire": return "flame"
		"holy": return "petal"
		"earth": return "diamond"
		_: return "star"


static func _finish(parent: Node3D, look: Dictionary, at: Vector3, radius: float, count := 12) -> void:
	var kind := _mote_kind(look.style)
	VfxArt.motes(parent, at + Vector3(0, 0.25, 0), look.primary, kind, mini(count, 7), minf(radius, 3.0), 0.15, 0.65)


static func _self_cast(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, tier: int) -> void:
	if String(skill.shape) == "summon":
		var summons: Dictionary = skill.get("summon", {})
		var count := mini(int(summons.get("count", 1)), 3)
		for i in count:
			var angle := float(look.phase) + float(i) * TAU / float(count)
			var point := origin + Vector3(cos(angle), 0, sin(angle)) * 1.6
			VfxArt.crest(parent, point, look.primary, look.family, 0.65, 0.9, angle)
			VfxArt.star_flash(parent, point + Vector3(0, 0.6, 0), look.accent, 1.3)
	_finish(parent, look, origin, 1.0, 10)


static func _area(parent: Node3D, skill: Dictionary, look: Dictionary, at: Vector3, radius: float, tier: int) -> void:
	var color: Color = look.primary
	var style := String(look.style)
	# Outline follows the real attack radius; vertical accents stay below 5m.
	# The art signature keeps the centre open; ElementFx supplies real flame,
	# crystal, roots and plants beneath its calligraphic silhouette.
	# Fire, ice and nature are drawn as the real thing (ElementFx). A meteor's
	# fire waits for the rock to land; a burst rings the caster instead of
	# covering them.
	var element := ElementFx.element_of(skill)
	var ring := String(skill.shape) == "burst"
	if element in ["fire", "ice", "vine", "plant"]:
		var show := func():
			if not is_instance_valid(parent) or not parent.is_inside_tree():
				return
			match element:
				"fire": ElementFx.fire_field(parent, at, radius, tier, ring)
				"ice": pass # SkillCraft owns the crystal growth, fracture and chips.
				"vine": ElementFx.vine_field(parent, at, radius, tier, ring)
				"plant": ElementFx.plant_field(parent, at, radius, String(ElementFx.PLANT_SKILLS.get(String(skill.id), "sprouts")), tier, ring)
		show.call()
		_finish(parent, look, at, radius * 0.6, 8 + tier)
		return
	match style:
		"fire":
			VfxKit.fire_ring(parent, at, color, radius * 0.75, 4 + tier, 0.5)
		"ice":
			VfxKit.spikes(parent, at, radius * 0.7, color, 4 + tier, 1.2, 0.18)
		"holy", "heal":
			VfxArt.bloom(parent, at, look.accent, "petal", radius * 0.55, 4, 0.80, look.phase)
		"thunder":
			for i in VfxBudget.count(2 + tier, 1):
				var angle := float(look.phase) + float(i) * 2.4
				var point := at + Vector3(cos(angle), 0, sin(angle)) * radius * 0.6
				VfxArt.sky_strike(parent, point, color, 0.18, 3.8, 0.3)
		"earth":
			VfxKit.spikes(parent, at, radius * 0.7, look.shade, 4, 0.65, 0.12)
	_finish(parent, look, at, radius * 0.6, 12 + tier * 2)


static func _single(parent: Node3D, skill: Dictionary, look: Dictionary, center: Vector3, origin: Vector3, tier: int) -> void:
	# The signature owns the weapon / spell silhouette. Arrival flashes remain
	# owned by the projectile; this layer cannot imply damage before it lands.
	if bool(skill.get("projectile", false)):
		return
	_finish(parent, look, center, 0.65, 5)


static func _multi(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, center: Vector3, tier: int) -> void:
	# Actual arrows and chain links own their contact accents.
	_finish(parent, look, origin, 0.8, 4)
