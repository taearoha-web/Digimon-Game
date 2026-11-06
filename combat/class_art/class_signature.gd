class_name ClassSignature
extends RefCounted
## The class signature layers of the Archer (ArcherArt), the Assassin
## (AssassinSignature) and the Dark Lord (LordSignature), over the shared
## skill presentation: every skill of the three lines (Lv.10-100) and their
## star skills (50-300 stars) gets its class's own touch at each beat:
##   anticipate  the wind-up (bow-draw glow, gathering shadows, scepter sigil)
##   play        the release (shock ring, arrow rain, smoke, eclipse, portal)
##   flight      riding each projectile (fletching trails, dagger streaks, dark flame)
##   contact     every hit (feather puffs, the critical's red X, branching bolts)
##   star_beat   each contact beat of a star skill (StarSkillSequence)
## Built on SignatureKit (pooled sheets and particles, one clock per cast,
## VfxBudget / MemoryGuard / quality aware). Cosmetic only: it never selects
## victims, deals damage or changes timing.

const CONTACT_GAP_MS := 70
static var _last_contact: Dictionary = {}
## The latest contact of each skill (chain lightning links to it).
static var _chain: Dictionary = {}


static func family(skill: Dictionary) -> String:
	if skill.is_empty():
		return ""
	var f := SkillShow.family_of(skill)
	return f if f in ["archer", "assassin", "darklord"] else ""


static func handles(skill: Dictionary) -> bool:
	return family(skill) != ""


static func _ctx(skill: Dictionary, origin: Vector3, center: Vector3, delay := 0.0) -> Dictionary:
	return {"id": String(skill.get("id", "")), "level": int(skill.get("level", 100)), "shape": String(skill.get("shape", "single")),
		"radius": clampf(float(skill.get("radius", 3.0)), 1.5, 9.0), "delay": maxf(delay, 0.0), "origin": origin, "center": center,
		"star": int(skill.get("star", 0)), "god": StarSkillData.is_god(skill) if skill.has("star") else false,
		"reach": Vector2(center.x - origin.x, center.z - origin.z).length(), "skill": skill}


## Wind-up, bound to the caster's skill generation (a cancel drops it).
static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, aim: Vector3, duration: float, visual: HeroVisual = null) -> void:
	var f := family(skill)
	if f == "" or duration < 0.1:
		return
	var kit := SignatureKit.begin(parent, origin, aim, "Signature_Windup_" + String(skill.get("id", "")), visual)
	if kit == null:
		return
	var ctx := _ctx(skill, origin, aim)
	ctx["time"] = maxf(duration, 0.15)
	match f:
		"archer": ArcherArt.anticipate(kit, ctx)
		"assassin": AssassinSignature.anticipate(kit, ctx)
		"darklord": LordSignature.anticipate(kit, ctx)


## Release, at the same beat as the damage ([param delay] for landings).
static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, delay := 0.0) -> void:
	var f := family(skill)
	if f == "" or skill.has("star"):
		return
	var ctx := _ctx(skill, origin, center, delay)
	var at := center if String(ctx.shape) == "blast" else origin
	var kit := SignatureKit.begin(parent, Vector3(at.x, origin.y, at.z), center if at == origin else center + (center - origin), "Signature_" + String(ctx.id))
	if kit == null:
		return
	if at != origin and Vector2(center.x - origin.x, center.z - origin.z).length_squared() > 0.001:
		kit.rotation.y = atan2(center.x - origin.x, center.z - origin.z)
	match f:
		"archer": ArcherArt.play(kit, ctx)
		"assassin": AssassinSignature.play(kit, ctx)
		"darklord": LordSignature.play(kit, ctx)


## Rides one projectile from -> to over its flight seconds.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, size := 1.0) -> void:
	var f := family(skill)
	if f == "" or from.distance_squared_to(to) < 0.04:
		return
	var kit := SignatureKit.begin(parent, from, to, "Signature_Flight_" + String(skill.get("id", "")))
	if kit == null:
		return
	kit.ride(from, to, seconds)
	var ctx := _ctx(skill, from, to)
	ctx["seconds"] = maxf(seconds, 0.08)
	ctx["size"] = size
	ctx["length"] = from.distance_to(to)
	match f:
		"archer": ArcherArt.flight(kit, ctx)
		"assassin": AssassinSignature.flight(kit, ctx)
		"darklord": LordSignature.flight(kit, ctx)


## Every hit of a skill ([param crit] from the combat roll, cosmetic only).
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, crit := false) -> void:
	var f := family(skill)
	if f == "":
		return
	var id := String(skill.get("id", ""))
	var now := Time.get_ticks_msec()
	var last: Dictionary = _chain.get(id, {})
	_chain[id] = {"at": at, "ms": now}
	if now - int(_last_contact.get(id, -100000)) < CONTACT_GAP_MS and not crit:
		return
	_last_contact[id] = now
	var kit := SignatureKit.begin(parent, at, at + Vector3(0, 0, 1), "Signature_Hit_" + id)
	if kit == null:
		return
	var ctx := _ctx(skill, at, at)
	ctx["crit"] = crit
	ctx["previous"] = last.at if not last.is_empty() and now - int(last.ms) < 260 and (last.at as Vector3).distance_to(at) < 12.0 else null
	match f:
		"archer": ArcherArt.contact(kit, ctx)
		"assassin": AssassinSignature.contact(kit, ctx)
		"darklord": LordSignature.contact(kit, ctx)


## One contact beat of a star skill (index 0 is the first; the god skills' last beat is the finale).
static func star_beat(parent: Node3D, skill: Dictionary, point: Vector3, index: int, source: Vector3) -> void:
	var f := family(skill)
	if f == "":
		return
	var ground := Vector3(point.x, source.y if absf(point.y - source.y) < 3.0 else point.y, point.z)
	var kit := SignatureKit.begin(parent, ground, ground + (ground - source), "Signature_Star_%s_%d" % [String(skill.get("id", "")), index])
	if kit == null:
		return
	var ctx := _ctx(skill, source, ground)
	ctx["index"] = index
	ctx["point"] = point
	match f:
		"archer": ArcherArt.star_beat(kit, ctx)
		"assassin": AssassinSignature.star_beat(kit, ctx)
		"darklord": LordSignature.star_beat(kit, ctx)


## The raven's strike (LordSkillArt.raven_peck): feathers torn loose, swirling down.
static func raven_feathers(parent: Node3D, at: Vector3, c: Array, pack: bool) -> void:
	var kit := SignatureKit.begin(parent, at, at + Vector3.FORWARD, "Signature_Raven")
	if kit == null:
		return
	kit.burst("feathers", [c[0], c[1], Color("0b0614")], Vector3(0, 0.6, 0), 0.0, {"amount": 12 if pack else 7, "radius": 0.5, "speed": 1.2, "spread": 80.0, "swirl": 3.0, "life": 0.75})
	kit.sheet(SignatureKit.RING, c, Vector3(0, 0.08, 0), 0.0, 0.35, {"ground": true, "size": Vector2.ONE * 0.5, "grow": Vector2.ONE * (3.2 if pack else 1.6), "level": SignatureKit.MAIN, "opacity": 0.6})


# ---------------------------------------------------------------------------
# Shared pieces
# ---------------------------------------------------------------------------

## A flat basis whose Y axis points along [param dir] (for axial streaks).
static func along(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length_squared() > 0.000001 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## Afterimage clones of the caster along a path (kit-local points), each a
## shadow silhouette that lingers and dissolves after the body has passed.
static func afterimages(parent: Node3D, from: Vector3, to: Vector3, c: Array, count: int, start := 0.0, life := 0.5) -> void:
	if SignatureKit.detail() == 0 or not SignatureKit.alive(parent) or from.distance_to(to) < 0.4:
		return
	var n := mini(count, 2 if SignatureKit.detail() == 1 else count)
	var art := ShadowSkillArt._root(parent, from, "Signature_Afterimages")
	art.rotation.y = SculptureArt._yaw(from, to)
	art.cap = n
	var local_to := art.to_local(to)
	for i in n:
		var t := float(i + 1) / float(n + 1)
		art.layer("phantom", false, c, Vector3.ZERO.lerp(local_to, t) - Vector3(0, 0, 0.2), Vector3.ONE * 1.02, Vector3.ZERO, start + t * 0.12, life,
			{"initial": 1.0, "grow": 6.0, "fade_in": 0.02, "decay": 0.25, "opacity": 0.62 - 0.25 * (1.0 - t), "travel": Vector3(0, 0.05, -0.25)})


## Allies of the caster within [param reach] (the hero, companions and party
## players), nearest first, at most [param limit]: their positions only.
static func allies(parent: Node3D, origin: Vector3, reach := 14.0, limit := 4) -> Array:
	var out: Array = []
	if not SignatureKit.alive(parent):
		return out
	var tree := parent.get_tree()
	for group in ["hero", "companions"]:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			if body and body.is_inside_tree() and body.global_position.distance_to(origin) <= reach:
				out.append(body.global_position)
	out.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	return out.slice(0, limit)
