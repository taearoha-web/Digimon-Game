extends RefCounted
## Dark Lord Lv.88: Raven Storm (พายุอีกาเงา). A pale violet moon rises behind the Lord
## and a vortex of black feathers whirls up round them. On the release the storm breaks:
## feathers blast out, a shock of violet rolls from the Lord, and each of the eight strikes
## (the real projectiles' flights) is a shadow raven that swoops on its foe, wings beating,
## a trail of feathers behind it; where it strikes, claw scars rake the ground, feathers
## scatter and a ring of violet bursts. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const RS := preload("res://combat/star_art/raven_sovereign.gd")
const VIOLET := Color("8a4dff")
const VIOLET_HI := Color("e0c8ff")
const VIOLET_DK := Color("1e0a3a")
const BLACK := Color("1a1424")
const SHEEN := Color("5a4a7a")
const FEATHERS := [Color("1a1424"), Color("2e2440"), Color("5a4a7a"), Color("3a2a5a")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		K.put(art, K.VEIL, M.moon("raven_storm", Color("e8dcff"), VIOLET), "StormMoon", Vector3(0, 3.2, -1.2), Vector3.ONE * 1.0, Vector3.ZERO, t, {"initial": 0.5, "grow_time": 0.7, "fade_in": 0.3, "decay": 0.92, "face_camera": true}, {"opacity": 0.85, "slide": Vector3(0, -0.8, 0), "slide_time": t, "slide_ease": -2.0})
		K.put(art, K.VEIL, S.spiral("raven_vortex", Color(0.2, 0.12, 0.35, 0.85), Color(0.55, 0.35, 0.9, 0.0), 4, 1.6, 0.5), "StormVortex", Vector3.UP * 0.1, Vector3(1.5, 2.8, 1.5), Vector3.ZERO, t, {"initial": 0.6, "grow_time": 0.7, "fade_in": 0.2, "spin": -8.0, "decay": 0.9})
		K.put(art, K.SOLID, S.feathers("raven_whirl", FEATHERS, 16, 2.0), "StormWhirl", Vector3.UP * 0.4, Vector3.ONE * 0.9, Vector3.ZERO, t, {"cull": 5.0, "decay": 0.85, "spin": -6.0}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": -0.6, "drag": 3.0, "life": t + 0.3}))
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 1.3, "Break", c.caster)
	if art:
		K.put(art, K.SOLID, S.feathers("raven_blast", FEATHERS, 26, 6.0), "StormFeathers", Vector3.UP * 1.0, Vector3.ONE, Vector3.ZERO, 1.3, {"cull": 10.0, "decay": 0.8}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": 1.5, "drag": 1.8, "life": 1.3}))
		K.put(art, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "StormShock", Vector3.UP * 0.08, Vector3.ONE * 3.6, Vector3.ZERO, 0.55, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		K.put(art, K.VEIL, M.moon("raven_storm", Color("e8dcff"), VIOLET), "StormMoonFade", Vector3(0, 2.4, -1.2), Vector3.ONE * 1.0, Vector3.ZERO, 0.7, {"initial": 1.0, "fade_in": 0.001, "decay": 0.3, "face_camera": true}, {"opacity": 0.85})
		M.show(art)
	return true


## One shadow raven swooping on its foe.
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var c := M.beat(parent, skill, from)
	var art := c.open(from, seconds + 0.05, "Raven", null)
	if not art:
		return null
	art.rotation.y = 0.0
	var dir := to - from
	var go := {"initial": 1.0, "travel": dir, "fade_in": 0.03, "decay": 0.97}
	var turn := M.toward(dir)
	K.put(art, K.SOLID, RS.raven_mesh(), "StormRaven", Vector3.ZERO, Vector3.ONE * 0.55, Vector3(turn.x * 0.5, turn.y, 0), seconds, go.merged({"front": true}), M.DARK_LOOK.merged({"flap": 0.35, "flap_rate": 22.0}))
	K.put(art, K.VEIL, S.tail("raven_trail", Color(0.35, 0.2, 0.6, 0.8), Color(0.1, 0.05, 0.2, 0.3)), "StormTrail", Vector3.ZERO, Vector3(0.9, 1.8, 0.9), M.along(-dir), seconds, go)
	M.show(art)
	return art


## Where a raven strikes: claw scars, feathers and a violet ring.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 50, 3 if VfxBudget.for_hero() else 1):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(Vector3(at.x, 0.0, at.z), 1.0, "Claw", null)
	if not art:
		return
	art.rotation.y = randf() * TAU
	K.put(art, K.VEIL, RS.scar_mesh(), "StormScar", Vector3.UP * 0.04, Vector3.ONE * 1.0, Vector3.ZERO, 0.95, {"initial": 0.5, "grow_time": 0.1, "fade_in": 0.01, "decay": 0.6, "priority": -1})
	K.put(art, K.SOLID, S.feathers("raven_hit", FEATHERS, 12, 4.0), "StormHitFeathers", Vector3.UP * at.y * 0.8, Vector3.ONE * 0.7, Vector3.ZERO, 0.9, {"cull": 6.0, "decay": 0.8}, M.DARK_LOOK.merged({"burst": 1.0, "gravity": 2.0, "drag": 2.0, "life": 0.9}))
	K.put(art, K.VEIL, K.shock(VIOLET, VIOLET_HI, VIOLET_DK), "StormHitRing", Vector3.UP * 0.08, Vector3.ONE * 1.6, Vector3.ZERO, 0.4, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
	M.show(art)
