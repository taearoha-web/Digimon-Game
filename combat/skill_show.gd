class_name SkillShow
extends RefCounted
## Class identity, elemental silhouette and a restrained finishing beat for every
## active skill. This layer is cosmetic: it never schedules damage or alters time.

const FAMILY_COLORS := {
	"vagabond": Color("f3cc8d"), "warrior": Color("ffac8f"),
	"archer": Color("98e6c4"), "mage": Color("c4adff"), "priest": Color("ffe8a8"), "summoner": Color("b4f08c"),
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
	if id in ["agony", "distortion", "vague", "magic_overdrive", "silraphim", "spirit_elemental", "dancing_sword"]:
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
	return {"family": family, "style": style, "primary": primary,
		"accent": FAMILY_COLORS[family].lerp(Color.WHITE, 0.28),
		"motif": motif, "phase": float(posmod(id.hash(), 360)) * PI / 180.0,
		"tier": clampi(int(skill.get("level", 1)) / 20, 0, 5),
		"mapped": _families.has(id)}


## Called with the existing wind-up duration. It does not delay resolution.
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float) -> void:
	var look := profile_for(skill)
	VfxArt.crest(parent, origin, look.accent, look.family, 1.25, maxf(duration, 0.18), look.phase)
	if String(look.family) in ["mage", "priest", "summoner"]:
		VfxArt.star_flash(parent, origin + Vector3(0, 1.35, 0), look.primary, 0.65, maxf(duration, 0.18))


## center: target/area; origin: caster's feet. Hero and companions share this path.
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, camera: ThirdPersonCamera = null) -> void:
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
	# Companion bursts cannot blanket the field; each still keeps its core shape.
	if crowd >= 5:
		VfxArt.star_flash(parent, at + Vector3(0, 0.9, 0), look.primary, 1.1, 0.22)
		return
	match shape:
		"self", "summon": _self_cast(parent, skill, look, origin, tier)
		"burst", "blast": _area(parent, skill, look, at, radius, tier)
		"single": _single(parent, skill, look, center, origin, tier)
		"fan", "chain": _multi(parent, skill, look, origin, center, tier)
	if tier >= 3 and VfxBudget.can_decorate():
		# A small second beat instead of another enormous white explosion.
		var finish_radius := minf(radius * 0.65, 3.2)
		parent.create_tween().tween_interval(0.2).finished.connect(func():
			if is_instance_valid(parent) and parent.is_inside_tree():
				VfxArt.bloom(parent, at, look.accent, _mote_kind(look.style), finish_radius, 4 + tier, 0.55, look.phase), CONNECT_ONE_SHOT)
	if camera and tier >= 4 and crowd == 0:
		camera.punch(2.0 + float(tier - 4) * 0.8)


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
	VfxArt.motes(parent, at + Vector3(0, 0.25, 0), look.primary, kind, count, minf(radius, 3.0), 0.15, 0.75)


static func _self_cast(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, tier: int) -> void:
	VfxArt.crest(parent, origin, look.primary, look.family, 1.9 + float(tier) * 0.16, 0.85, look.phase)
	VfxArt.ribbon_spiral(parent, origin, look.accent, 2.0, 1.0, 0.65, 0.85)
	var kind := _mote_kind(look.style)
	if look.motif == "shield":
		kind = "diamond"
	elif look.family == "archer":
		kind = "leaf"
	elif look.motif == "heal":
		kind = "heart"
	VfxArt.bloom(parent, origin, look.primary, kind, 1.2, 6, 0.8, look.phase)
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
	VfxArt.crest(parent, at, color, look.family, radius, 0.72, look.phase)
	match style:
		"fire":
			VfxKit.fire_ring(parent, at, color, radius * 0.8, 8 + tier, 0.5)
		"ice":
			VfxKit.spikes(parent, at, radius * 0.8, color, 8 + tier, 1.6, 0.18)
			VfxArt.bloom(parent, at, look.accent, "snow", minf(radius * 0.7, 3.5), 5, 0.7, look.phase)
		"holy", "heal":
			VfxArt.bloom(parent, at, color, "petal", radius * 0.75, 8, 0.85, look.phase)
			VfxKit.column_rain(parent, at, radius * 0.7, look.accent, 4 + tier, 0.4, 4.5)
		"wind", "leaf":
			VfxArt.ribbon_spiral(parent, at, color, 1.8, 1.2, 0.65, radius * 0.65)
			VfxArt.bloom(parent, at, color, "leaf", radius * 0.7, 7, 0.7, look.phase)
		"thunder":
			for i in VfxBudget.count(3 + tier, 2):
				var angle := float(look.phase) + float(i) * 2.4
				var point := at + Vector3(cos(angle), 0, sin(angle)) * radius * 0.6
				VfxArt.sky_strike(parent, point, color, 0.3, 5.0, 0.3)
		"arcane":
			VfxArt.ribbon_spiral(parent, at, color, 2.0, 1.4, 0.7, radius * 0.65)
			VfxArt.bloom(parent, at, look.accent, "diamond", radius * 0.75, 7, 0.8, look.phase)
		"earth":
			VfxKit.spikes(parent, at, radius * 0.75, color, 7, 1.2, 0.12)
		_:
			if look.motif == "roar":
				VfxArt.ribbon_spiral(parent, at, color, 1.0, 1.1, 0.5, radius * 0.65)
			else:
				for i in VfxBudget.count(3, 2):
					VfxKit.slash_arc(parent, at + Vector3(0, 0.7 + float(i) * 0.12, 0), look.phase + float(i) * 2.1, color, minf(radius * 0.8, 4.0), 0.12)
	_finish(parent, look, at, radius * 0.6, 12 + tier * 2)


static func _single(parent: Node3D, skill: Dictionary, look: Dictionary, center: Vector3, origin: Vector3, tier: int) -> void:
	var direction := center - origin
	var yaw := atan2(direction.x, direction.z) if direction.length() > 0.1 else 0.0
	var color: Color = look.primary
	if bool(skill.get("projectile", false)):
		# Arrival flashes are owned by the projectile; launch art stays at caster.
		var launch := origin + direction.normalized() * 0.6 + Vector3(0, 1.25, 0)
		VfxArt.star_flash(parent, launch, color, 1.0 + float(tier) * 0.08)
		if look.family == "archer":
			VfxArt.bloom(parent, origin, look.accent, "leaf", 0.9, 4, 0.45, yaw)
		else:
			VfxArt.crest(parent, origin, color, look.family, 1.4, 0.55, look.phase)
		return
	var hit := center + Vector3(0, 0.95, 0)
	var cut := origin + direction.normalized() * minf(direction.length(), 1.3) + Vector3(0, 0.95, 0)
	if String(skill.id) in ["raving", "triple_impact", "avenging_crash"]:
		VfxArt.cross_slash(parent, cut, yaw, color, 2.5)
	else:
		VfxKit.slash_arc(parent, cut, yaw, color, 2.5 + float(tier) * 0.14, -0.65)
	VfxArt.star_flash(parent, hit, look.accent, 1.7, 0.22)
	if look.motif == "shield":
		VfxArt.bloom(parent, center, color, "diamond", 0.65, 4, 0.45, look.phase)
	_finish(parent, look, center, 0.65, 8)


static func _multi(parent: Node3D, skill: Dictionary, look: Dictionary, origin: Vector3, center: Vector3, tier: int) -> void:
	VfxArt.crest(parent, origin, look.accent, look.family, 1.6, 0.55, look.phase)
	var kind := "leaf" if look.family in ["archer", "summoner"] else ("petal" if look.family == "priest" else "diamond")
	VfxArt.bloom(parent, origin, look.primary, kind, 1.2, mini(int(skill.get("hits", 3)), 8), 0.5, look.phase)
	if String(skill.shape) == "chain":
		VfxArt.star_flash(parent, center + Vector3(0, 1.0, 0), look.accent, 1.3 + float(tier) * 0.08, 0.2)
