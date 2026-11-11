extends RefCounted
## Summoner Lv.76: Sylvan Ray (รังสีแห่งป่า). A lotus of forest light opens at the
## Summoner's hand and a green star gathers in its heart; on the release the flower flares
## and a ray of green-gold light reaches out to the target with a spinning blossom at its
## head (the real projectile's flight: SkillTableau.flight hands it over), and where it
## lands a flower blooms on the target, petals and leaves burst out and a ring of light runs
## round its feet. Cosmetic only.
const K := preload("res://combat/god_art/_kit_arcane.gd")
const S := preload("res://combat/star_art/_kit_star_arcane.gd")
const M := preload("res://combat/skill_art/_mystic.gd")
const LEAF := Color("8ae86a")
const LEAF_HI := Color("e0ffb0")
const GOLD := Color("ffe070")
const DEEP := Color("2f8a4a")
const PETALS := [Color("b8ffa0"), Color("fff0a0"), Color("7ad85a"), Color("e8ffd0")]


static func anticipate(parent: Node3D, skill: Dictionary, origin: Vector3, duration: float, aim: Vector3, visual: HeroVisual) -> bool:
	var c := M.windup(parent, skill, origin, aim, visual)
	var t := maxf(duration, 0.15) + 0.1
	var art := c.open(origin, t, "Windup", c.caster)
	if art:
		var hand := c.local(art, c.hand())
		K.put(art, K.SOLID, M.lotus("sylvan_hand", LEAF, LEAF_HI, GOLD, 9, 2), "SylvanLotus", hand + Vector3(0, 0.1, 0.25), Vector3.ONE * 0.55, Vector3(PI / 2, 0, 0), t, {"initial": 0.15, "grow_time": 0.85, "fade_in": 0.1, "spin": 0.0, "decay": 0.95}, M.LEAF_LOOK)
		K.put(art, K.VEIL, S.twinkle("sylvan_core", Color(LEAF, 0.95), GOLD), "SylvanStar", hand + Vector3(0, 0.1, 0.35), Vector3.ONE * 0.7, Vector3.ZERO, t, {"initial": 0.1, "grow_time": 0.9, "fade_in": 0.1, "decay": 0.95, "pulse": true}, {"billboard": true})
		K.put(art, K.VEIL, S.spiral("sylvan_in", Color(0.6, 1.0, 0.5, 0.7), Color(1.0, 1.0, 0.7, 0.0), 3, 1.3, 0.3), "SylvanGather", Vector3.UP * 0.1, Vector3(1.4, 2.2, 1.4), Vector3.ZERO, t, {"initial": 1.5, "grow_time": 1.0, "fade_in": 0.2, "spin": -6.0, "decay": 0.9})
		M.show(art)
	return true


static func play(parent: Node3D, skill: Dictionary, center: Vector3, origin: Vector3, _impact_delay: float) -> bool:
	var c := M.release(parent, skill, center, origin)
	var art := c.open(origin, 0.7, "Flare", c.caster)
	if art:
		var hand := c.local(art, c.hand())
		K.put(art, K.SOLID, M.lotus("sylvan_hand", LEAF, LEAF_HI, GOLD, 9, 2), "SylvanLotusOpen", hand + Vector3(0, 0.1, 0.3), Vector3.ONE * 0.75, Vector3(PI / 2, 0, 0), 0.5, {"initial": 0.7, "grow_time": 0.3, "fade_in": 0.01, "decay": 0.5}, M.LEAF_LOOK)
		K.put(art, K.VEIL, K.shock(LEAF_HI, GOLD, LEAF), "SylvanFlare", hand + Vector3(0, 0, 0.3), Vector3.ONE * 1.1, Vector3(PI / 2, 0, 0), 0.4, {"initial": 0.2, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
		K.put(art, K.SOLID, S.leaves("sylvan_puff", PETALS, 14, 3.5, 1.5), "SylvanPuff", hand + Vector3(0, 0, 0.3), Vector3.ONE * 0.6, Vector3.ZERO, 0.7, {"cull": 4.0, "decay": 0.7}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 2.0, "drag": 2.5, "life": 0.7}))
		M.show(art)
	return true


## The ray itself: the real projectile's flight from [param from] to [param to].
static func flight(parent: Node3D, skill: Dictionary, from: Vector3, to: Vector3, seconds: float, _size: float) -> Node3D:
	var c := M.beat(parent, skill, from)
	var life := seconds + 0.3
	var art := c.open(from, life, "Ray", null)
	if not art:
		return null
	art.rotation.y = 0.0
	var dir := to - from
	M.span(art, K.VEIL, M.beam("sylvan_ray", Color(0.7, 1.0, 0.5, 0.95), Color(1.0, 0.92, 0.5, 0.7), 0.55), "SylvanBeam", from, to, 0.75, life, {"initial": 0.04, "grow_time": seconds / life, "fade_in": 0.01, "decay": 0.7}, {"noise_amt": 0.4, "noise_scale": Vector2(2.0, 8.0), "flow": Vector2(0.0, -6.0), "bias": 0.45, "taper": 0.0})
	var turn := M.toward(dir)
	K.put(art, K.SOLID, M.lotus("sylvan_head", LEAF_HI, LEAF, GOLD, 8, 2), "SylvanHead", Vector3.ZERO, Vector3.ONE * 0.45, Vector3(turn.x + PI / 2, turn.y, 0), seconds, {"initial": 1.0, "travel": dir, "fade_in": 0.01, "decay": 0.97, "front": true, "spin": 0.0}, M.LEAF_LOOK)
	K.put(art, K.VEIL, S.twinkle("sylvan_core", Color(LEAF, 0.95), GOLD), "SylvanHeadGlow", Vector3.ZERO, Vector3.ONE * 0.9, Vector3.ZERO, seconds, {"initial": 1.0, "travel": dir, "fade_in": 0.01, "decay": 0.97}, {"billboard": true})
	M.show(art)
	return art


## Where the ray lands: a flower blooms on the target.
static func contact(parent: Node3D, skill: Dictionary, at: Vector3, _crit: bool) -> void:
	if not M.contact_ok(String(skill.id), 60):
		return
	var c := M.beat(parent, skill, at)
	var art := c.open(Vector3(at.x, 0.0, at.z), 1.3, "Bloom", null)
	if not art:
		return
	var h := at.y
	K.put(art, K.SOLID, M.lotus("sylvan_bloom", LEAF, LEAF_HI, GOLD, 10, 2), "SylvanBloom", Vector3.UP * 0.06, Vector3.ONE * 1.5, Vector3.ZERO, 1.2, {"initial": 0.15, "grow_time": 0.25, "fade_in": 0.01, "decay": 0.6, "spin": 0.8}, M.LEAF_LOOK)
	K.put(art, K.VEIL, S.twinkle("sylvan_hit", Color(LEAF, 0.95), GOLD), "SylvanHitStar", Vector3.UP * h, Vector3.ONE * 1.5, Vector3.ZERO, 0.35, {"initial": 0.3, "grow_time": 0.4, "fade_in": 0.01, "decay": 0.4, "front": true}, {"billboard": true})
	K.put(art, K.SOLID, S.leaves("sylvan_burst", PETALS, 18, 5.0, 3.0), "SylvanPetals", Vector3.UP * h * 0.8, Vector3.ONE * 0.8, Vector3.ZERO, 1.1, {"cull": 8.0, "decay": 0.8}, M.LEAF_LOOK.merged({"burst": 1.0, "gravity": 3.0, "drag": 1.6, "life": 1.1}))
	K.put(art, K.VEIL, K.shock(LEAF_HI, GOLD, DEEP), "SylvanRing", Vector3.UP * 0.08, Vector3.ONE * 2.0, Vector3.ZERO, 0.5, {"initial": 0.15, "grow_time": 0.9, "fade_in": 0.01, "decay": 0.35}, {"opacity": 0.8})
	M.show(art)
